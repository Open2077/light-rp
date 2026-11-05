-- op77_tcg client: the binder page, the physical pack opening every nearby player sees, the shop counter.
--
-- Opening, for everyone within C.opening.nearRadius: the opener holds the sealed pack (a real 3D booster in the
-- right hand), tears it open (sound), then the twelve real 3D cards are dealt one by one on the surface in front of
-- them -- or fanned in the hand when there is no table -- at the pace the opener reveals them on the page. The
-- premium card arrives last, with a flash of its rarity's colour. The cards lie there for a while, then go back
-- into the opener's binder.
local C, R = TcgConfig, TcgRules
local NET = "op77_tcg:"
local RES = GetCurrentResourceName()

local page, pageReady = nil, false
local isOpen = false
local state = nil          -- last state from the server
local openings = {}        -- opener -> { seq, cards = {ids}, anchor, pack, props = {}, light }
local nearShopId = nil

local function log(fmt, ...) print(("[op77_tcg] " .. fmt):format(...)) end
local function me() local ok, id = pcall(Open77.players.localId); return ok and tonumber(id) or nil end

local function send(name, payload)
    if not page or not pageReady then return end
    pcall(function() page:send(name, payload or {}) end)
end

local function notify(text)
    if Open77.hud and Open77.hud.notify then pcall(Open77.hud.notify, text) end
end

local function uikit()
    local ok, kit = pcall(function() return exports.open77_uikit end)
    return ok and kit or nil
end

local function sound3D(file, at, maxDistance)
    if not at then return end
    pcall(Open77.audio.play3D, "sounds/" .. file, { x = at.x, y = at.y, z = at.z }, { maxDistance = maxDistance or 18, volume = 0.9 })
end

-- ---------------------------------------------------------------------------------------------
-- Geometry. Yaw 0 faces +Y; forward = (-sin, cos).

local function forward(yaw) local r = math.rad(yaw); return -math.sin(r), math.cos(r) end
local function right(yaw) local r = math.rad(yaw); return math.cos(r), math.sin(r) end

local function here()
    local x, y, z = Open77.character.position()
    if type(x) ~= "number" then return nil end
    local ok, yaw = pcall(Open77.character.yaw)
    return { x = x, y = y, z = z, yaw = (ok and tonumber(yaw)) or 0 }
end

-- The surface the hands would lay cards on: a table, a counter, a car bonnet. Nil = nothing at hand height.
local function surfaceAhead(at)
    local fx, fy = forward(at.yaw)
    local px, py = at.x + fx * C.opening.tableReach, at.y + fy * C.opening.tableReach
    local hands = at.z + 1.05
    local ok, hit = pcall(Open77.world.raycast, { x = px, y = py, z = hands + C.opening.tableSearch.up },
        { x = px, y = py, z = hands - C.opening.tableSearch.down })
    if not ok or type(hit) ~= "table" then return nil end
    local z = hit.position and hit.position.z or hit.z
    if hit.hit == false or type(z) ~= "number" then return nil end
    -- The floor under the feet is not a table.
    if z < at.z + 0.45 then return nil end
    return z
end

-- ---------------------------------------------------------------------------------------------
-- Physical props of an opening (local to each client, identical everywhere: same cards, same layout).

local function scaleOf(s) return { x = s, y = s, z = s } end

local function createProp(model, position, yaw, scale)
    local ok, id = pcall(Open77.props.create, { model = model, kind = "prop", position = position, yaw = yaw or 0,
        scale = scaleOf(scale), collision = false })
    return ok and id or nil
end

local function remove(id) if id then pcall(Open77.props.remove, id) end end

local function attachToHand(id, opener, offset, rotation)
    return pcall(Open77.props.attach, id, { parentType = "player", parentId = opener, bone = "RightHand",
        offset = offset, rotation = rotation })
end

-- Card k of 12 on the table: four columns, three rows, the premium alone in front at the centre.
local function tableSpot(o, k)
    local a = o.anchor
    local fx, fy = forward(a.yaw)
    local rx, ry = right(a.yaw)
    local col, row, lift
    if k == 12 then
        col, row, lift = 0, -0.6, 0.004
    else
        col = ((k - 1) % 4) - 1.5
        row = math.floor((k - 1) / 4)
        lift = 0.002 + (k * 0.0002)
    end
    local reach = C.opening.tableReach + 0.05 + row * 0.1
    return { x = a.x + fx * reach + rx * col * 0.074, y = a.y + fy * reach + ry * col * 0.074, z = a.surface + lift }
end

local RARITY_LIGHT = {
    [3] = { x = 0.35, y = 0.75, z = 1.0 },  -- Rare: cyan
    [4] = { x = 0.8, y = 0.35, z = 1.0 },   -- Epic: violet
    [5] = { x = 1.0, y = 0.78, z = 0.2 },   -- Nova / Iconic: gold
    [6] = { x = 1.0, y = 0.2, z = 0.55 },   -- Secret: magenta
}

local function flash(o, at, tier)
    local color = RARITY_LIGHT[tier]
    if not color or tier < 4 then return end
    local def = { kind = "light", model = "light.point", position = { x = at.x, y = at.y, z = at.z + 0.35 },
        light = { color = color, intensity = tier >= 5 and 60 or 30, radius = 2.5, enabled = true } }
    local ok, id = pcall(Open77.props.create, def)
    if not ok or not id then
        -- The documented light model is light.spot; a point light is the same model with spot = false.
        def.model = "light.spot"
        def.light.spot = false
        ok, id = pcall(Open77.props.create, def)
    end
    if not ok or not id then return end
    o.light = id
    SetTimeout(2600, function() remove(id); if o.light == id then o.light = nil end end)
end

local function deal(o, k)
    local e = R.edition(o.cards[k])
    if not e or o.props[k] then return end
    local a = o.anchor
    if a.surface then
        local target = tableSpot(o, k)
        local fx, fy = forward(a.yaw)
        local from = { x = a.x + fx * 0.32, y = a.y + fy * 0.32, z = a.z + 1.15 }
        local yaw = (a.yaw + (k == 12 and 0 or (math.random() - 0.5) * 6)) % 360
        local id = createProp(e.entity, from, yaw, C.scale.card)
        if not id then return end
        o.props[k] = id
        -- The card slides out of the hand onto its spot.
        CreateThread(function()
            local steps = 10
            for i = 1, steps do
                local t = i / steps
                local ease = 1 - (1 - t) * (1 - t)
                local arc = math.sin(t * math.pi) * 0.05
                pcall(Open77.props.setTransform, id, { position = {
                    x = from.x + (target.x - from.x) * ease, y = from.y + (target.y - from.y) * ease,
                    z = from.z + (target.z - from.z) * ease + arc }, yaw = yaw })
                Wait(24)
            end
        end)
        if k == 12 then flash(o, target, e.tier) end
    else
        -- No table: the cards fan out in the right hand.
        local id = createProp(e.entity, { x = a.x, y = a.y, z = a.z + 1.2 }, a.yaw, C.scale.card)
        if not id then return end
        o.props[k] = id
        local spread = (k - 6.5)
        attachToHand(id, o.opener, { x = spread * 0.006, y = 0.06, z = 0.03 + k * 0.0012 },
            { x = 78.0, y = spread * 4.5, z = 180.0 })
        if k == 12 then flash(o, { x = a.x, y = a.y, z = a.z + 1.1 }, e.tier) end
    end
end

-- The opener's own view: an over-the-shoulder camera on the hand (no table) or on the table, so the opener watches
-- the real cards land behind the page's translucent reveal.
local openerCam = nil

local function stopCamera(blendMs)
    if not openerCam then return end
    local cam = openerCam
    openerCam = nil
    pcall(Open77.camera.deactivate, { blendMs = blendMs or 700 })
    SetTimeout((blendMs or 700) + 100, function() pcall(Open77.camera.destroy, cam) end)
end

local function startCamera(o)
    stopCamera(0)
    local a = o.anchor
    local fx, fy = forward(a.yaw)
    local rx, ry = right(a.yaw)
    -- The page reveals on the left third: the camera puts the real cards in the middle of the frame.
    local focus, eye
    if a.surface then
        -- Over the right shoulder, close above the dealt grid.
        local d = C.opening.tableReach + 0.08
        focus = { x = a.x + fx * d, y = a.y + fy * d, z = a.surface }
        eye = { x = a.x - fx * 0.12 + rx * 0.32, y = a.y - fy * 0.12 + ry * 0.32, z = a.surface + 0.62 }
    else
        -- No hold animation: the fan hangs at the right hip. Seen from the front right, looking back at the hand.
        focus = { x = a.x + rx * 0.22 + fx * 0.05, y = a.y + ry * 0.22 + fy * 0.05, z = a.z + 0.88 }
        eye = { x = a.x + fx * 0.62 + rx * 0.5, y = a.y + fy * 0.62 + ry * 0.5, z = a.z + 1.3 }
    end
    -- create / activate report a refusal as (nil|false, reason), not as an error.
    local ok, cam, why = pcall(Open77.camera.create, { position = eye, lookAt = focus, fov = 42, thirdPersonBody = true })
    if not ok or cam == nil then return log("opening camera refused: %s", tostring(ok and why or cam)) end
    local called, activated, reason = pcall(Open77.camera.activate, cam, { blendMs = 700 })
    if not called or activated ~= true then
        pcall(Open77.camera.destroy, cam)
        return log("opening camera not activated: %s", tostring(called and reason or activated))
    end
    log("opening camera on (%s)", a.surface and "table" or "hand")
    openerCam = cam
end

local function clearOpening(opener)
    local o = openings[opener]
    if not o then return end
    remove(o.pack)
    remove(o.light)
    for _, id in pairs(o.props) do remove(id) end
    openings[opener] = nil
end

RegisterNetEvent(NET .. "opening", function(p)
    if type(p) ~= "table" then return end
    local opener = tonumber(p.opener)
    clearOpening(opener)
    local cards = {}
    for id in tostring(p.cards or ""):gmatch("[^,]+") do cards[#cards + 1] = id end
    local def = C.products[p.product] or C.products.wnc
    local a = p.anchor
    local o = { seq = p.seq, opener = opener, cards = cards, anchor = a, props = {} }
    openings[opener] = o
    local physical = C.opening.physical == true
    -- The sealed pack in the right hand.
    if physical then
        o.pack = createProp(def.pack, { x = a.x, y = a.y, z = a.z + 1.2 }, a.yaw, C.scale.pack)
        if o.pack then attachToHand(o.pack, opener, { x = 0.0, y = 0.05, z = 0.02 }, { x = 75.0, y = 0.0, z = 180.0 }) end
    end
    if opener == me() then
        pendingOpen = nil
        if physical then startCamera(o) end
        send("tcg:opening", { seq = p.seq, product = p.product, cards = cards, fresh = p.fresh or "", table = a.surface ~= nil,
                              physical = physical })
        isOpen = true
        pcall(function() page:show() end)
        pcall(function() page:setFocus(true, true) end)
        TriggerEvent("op77_tcg:focus")
    end
end)

RegisterNetEvent(NET .. "reveal", function(p)
    if type(p) ~= "table" then return end
    local o = openings[tonumber(p.opener)]
    if not o or o.seq ~= p.seq then return end
    -- The opener's page follows a reveal the server drove (it ignores its own echoes).
    if o.opener == me() then send("tcg:advance", { seq = p.seq, stage = p.stage, index = p.index }) end
    if p.stage == "tear" then
        -- The opener's page plays the game's booster sound itself; a witness close by hears it too.
        if o.opener ~= me() then
            local at = here()
            local dx, dy = at and at.x - o.anchor.x or 99, at and at.y - o.anchor.y or 99
            if dx * dx + dy * dy < 64 and Open77.sfx and type(Open77.sfx.play2d) == "function" then
                pcall(Open77.sfx.play2d, "ui_menu_item_consumable_booster")
            end
        end
        remove(o.pack)
        o.pack = nil
        return
    end
    if p.finished then o.finished = true end
    -- Late joiners and skipped reveals: deal everything up to this card.
    remove(o.pack); o.pack = nil
    if C.opening.physical then
        for k = 1, math.min(tonumber(p.index) or 0, #o.cards) do deal(o, k) end
    elseif p.finished then
        clearOpening(o.opener)
        return
    end
    if p.finished then
        -- (only if no newer pack was opened meanwhile: "Open another" starts its own camera)
        if o.opener == me() then
            local mine = o.seq
            SetTimeout(4000, function()
                local cur = openings[me()]
                if not cur or cur.seq == mine then stopCamera(900) end
            end)
        end
        local seq = o.seq
        SetTimeout(C.opening.lingerMs, function()
            local cur = openings[o.opener]
            if cur and cur.seq == seq then clearOpening(o.opener) end
        end)
    end
end)

-- ---------------------------------------------------------------------------------------------
-- Shop counter and printer moments

RegisterNetEvent(NET .. "printed", function(p)
    if type(p) ~= "table" or not state then return end
    for _, s in ipairs(state.shops or {}) do
        if tostring(s.id) == tostring(p.shop) then sound3D("printer_work.mp3", s, 20) end
    end
end)

RegisterNetEvent(NET .. "shown", function(p)
    if type(p) ~= "table" then return end
    local e = R.edition(p.edition)
    local kit = uikit()
    local at = type(p.position) == "table" and p.position or nil
    if not e or not kit or not at then return end
    pcall(kit.drawText3D, { position = { x = at.x, y = at.y, z = at.z + 2.05 }, text = e.name, sublabel = e.rarity .. " - " .. e.finish,
        maxDistance = C.show.radius, ttl = p.ms or C.show.durationMs, color = "#F2F6F8", accent = "#FCEE09" })
end)

RegisterNetEvent(NET .. "notice", function(p)
    if type(p) ~= "table" then return end
    notify(p.text)
    send("tcg:notice", p)
end)

RegisterNetEvent(NET .. "offer", function(p)
    if type(p) ~= "table" then return end
    notify(("%s offers you a card - open your binder (/%s)"):format(p.name or "Someone", C.command))
    send("tcg:offer", p)
end)

RegisterNetEvent(NET .. "handed", function(p)
    if type(p) ~= "table" then return end
    if tonumber(p.to) == me() then send("tcg:sfx", { name = "receive" }) end
end)

RegisterNetEvent(NET .. "state", function(p)
    state = p
    send("tcg:state", p)
end)

-- ---------------------------------------------------------------------------------------------
-- The binder page

local function nearbyCollectors()
    local out = {}
    local ok, list = pcall(Open77.players.nearby, C.trade.maxDistance)
    local mine = me()
    if ok and type(list) == "table" then
        for _, entry in ipairs(list) do
            local id = tonumber(entry.playerId or entry.id)
            if id and id ~= mine then out[#out + 1] = { id = id, name = entry.name or ("Player " .. id), distance = entry.distance } end
        end
    end
    return out
end

local function openBinder(tab)
    if not page or not pageReady then return end
    if TcgClient and TcgClient.binderBlocked and TcgClient.binderBlocked() then
        return notify("Not at the duel table: the binder stays in your bag until the duel is over.")
    end
    isOpen = true
    pcall(function() page:show() end)
    send("tcg:open", { tab = tab or "binder", shop = nearShopId, nearby = nearbyCollectors() })
    pcall(function() page:setFocus(true, true) end)
    -- A gamemode closes its own panels over ours (LightRP: the inventory a booster was used from).
    TriggerEvent("op77_tcg:focus")
    TriggerServerEvent(NET .. "state")
end

local function closeBinder()
    isOpen = false
    send("tcg:close", {})
    pcall(function() page:setFocus(false, false) end)
    -- Seated at a duel table, the page keeps the cursor for the game overlay (client/duel.lua).
    if TcgClient and TcgClient.afterClose then TcgClient.afterClose() end
end

local function nowMs() return type(GetGameTimer) == "function" and GetGameTimer() or math.floor(os.clock() * 1000) end

-- A pack asked for and not dealt yet (the server takes the item and writes the pull first, which can take a
-- moment): the page shows "opening..." at once, and nothing else can be opened until it lands or fails.
local pendingOpen = nil
local function packBusy()
    if pendingOpen and nowMs() - pendingOpen.at < 20000 then return true end
    local o = openings[me()]
    return o ~= nil and not o.finished
end

local function openPack(product, again)
    if TcgClient and TcgClient.binderBlocked and TcgClient.binderBlocked() then
        return notify("Not at the duel table: the binder stays in your bag until the duel is over.")
    end
    local waiting = pendingOpen and nowMs() - pendingOpen.at < 20000
    if waiting or (packBusy() and not again) then return notify("Your pack is already opening: finish it first.") end
    local at = here()
    if not at then return end
    at.surface = surfaceAhead(at)
    pendingOpen = { at = nowMs(), product = product }
    -- The page right away: the pack in the hands with "opening...", no focus yet (the opening takes it).
    isOpen = true
    pcall(function() page:show() end)
    send("tcg:packPending", { product = product })
    TriggerServerEvent(NET .. "open", product, at)
    local mine = pendingOpen
    SetTimeout(20000, function()
        if pendingOpen == mine then
            pendingOpen = nil
            send("tcg:packFailed", { reason = "The server did not answer." })
        end
    end)
end

RegisterNetEvent(NET .. "openFailed", function(d)
    pendingOpen = nil
    send("tcg:packFailed", { reason = type(d) == "table" and d.reason or nil })
end)

-- A display used from a gamemode's inventory: the shrink-wrap scene, then the server cuts it (tcg:unbox).
local function openUnbox(product)
    if not page or not pageReady then return end
    if TcgClient and TcgClient.binderBlocked and TcgClient.binderBlocked() then
        return notify("Not at the duel table: the binder stays in your bag until the duel is over.")
    end
    isOpen = true
    pcall(function() page:show() end)
    send("tcg:unboxStart", { product = product })
    pcall(function() page:setFocus(true, true) end)
    TriggerEvent("op77_tcg:focus")
    TriggerServerEvent(NET .. "state")
end

-- exports.op77_tcg:useSealed (a gamemode's inventory item): open the real thing.
RegisterNetEvent(NET .. "use", function(d)
    if type(d) ~= "table" or type(d.product) ~= "string" then return end
    if d.kind == "box" then openUnbox(d.product) else openPack(d.product) end
end)

local function placeCard(edition)
    local at = here()
    if not at then return end
    local surface = surfaceAhead(at)
    if not surface then return notify("Stand at a table or a counter to lay a card down.") end
    local fx, fy = forward(at.yaw)
    TriggerServerEvent(NET .. "place", edition, { x = at.x + fx * C.opening.tableReach, y = at.y + fy * C.opening.tableReach, z = surface + 0.002 }, at.yaw)
end

local sfxAt = {}   -- last time each game sound was posted (a burst of crinkles is one sound)

local PAGE_ACTIONS = {
    ["tcg:close"] = function() closeBinder() end,
    ["tcg:log"] = function(d) log("page: %s", tostring(d.text)) end,
    ["tcg:openPack"] = function(d) openPack(d.product) end,
    ["tcg:revealed"] = function(d) TriggerServerEvent(NET .. "reveal", { seq = d.seq, stage = d.stage, index = d.index }) end,
    -- The opening screen gave way to the binder without closing the page: the camera comes back to the player.
    ["tcg:cameraBack"] = function() stopCamera(500) end,
    ["tcg:openingDone"] = function()
        local o = openings[me()]
        if o then o.finished = true end
        stopCamera(700); closeBinder()
    end,
    -- "Open another": the summary goes straight to the next pack of the same kind (or the one picked).
    ["tcg:openAgain"] = function(d)
        local o = openings[me()]
        if o then o.finished = true end
        openPack(type(d) == "table" and d.product or "wnc", true)
    end,
    -- The game's own interface sounds (Wwise events, 2D): the page names them, a short list is allowed.
    ["tcg:gameSfx"] = function(d)
        local event = type(d) == "table" and d.event
        if type(event) ~= "string" or not event:match("^ui_[%w_]+$") or #event > 64 then return end
        local t = nowMs()
        if sfxAt[event] and t - sfxAt[event] < 45 then return end
        sfxAt[event] = t
        if Open77.sfx and type(Open77.sfx.play2d) == "function" then pcall(Open77.sfx.play2d, event) end
    end,
    ["tcg:recycle"] = function(d) TriggerServerEvent(NET .. "recycle", d.id, d.count) end,
    ["tcg:print"] = function(d) TriggerServerEvent(NET .. "print", d.id) end,
    ["tcg:buy"] = function(d) TriggerServerEvent(NET .. "buy", d.product) end,
    ["tcg:unbox"] = function(d) TriggerServerEvent(NET .. "unbox", d.product) end,
    ["tcg:show"] = function(d) closeBinder(); TriggerServerEvent(NET .. "show", d.id) end,
    ["tcg:place"] = function(d) closeBinder(); placeCard(d.id) end,
    ["tcg:offer"] = function(d) TriggerServerEvent(NET .. "offer", d.target, d.id) end,
    ["tcg:answer"] = function(d) TriggerServerEvent(NET .. "answer", d.id, d.accept == true) end,
    -- (The tear now plays the game's booster sound from the page: tcg:gameSfx.)
    ["tcg:sfx"] = function() end,
}

-- What client/duel.lua shares with this script: the page, its actions, the binder.
TcgClient = {
    log = log, me = me, notify = notify, uikit = uikit, send = send, here = here, forward = forward, right = right,
    isOpen = function() return isOpen end,
    -- A page action (page -> client); registered on the page now if it already exists.
    on = function(name, fn)
        PAGE_ACTIONS[name] = fn
        if page then page:on(name, function(d) local ok, err = pcall(fn, type(d) == "table" and d or {}); if not ok then log("%s: %s", name, tostring(err)) end end) end
    end,
    -- The page over the game: `focus` takes the cursor and the keyboard (a duel at the table, the binder).
    show = function(focus)
        if not page then return end
        pcall(function() page:show() end)
        pcall(function() page:setFocus(focus == true, focus == true) end)
    end,
    release = function() if page then pcall(function() page:setFocus(false, false) end) end end,
    openBinder = function(tab) openBinder(tab) end,
}

CreateThread(function()
    -- The page: always created visible with a transparent body; the binder opens and closes inside it.
    local created, why
    for _ = 1, 120 do
        created, why = Open77.webui.create({ entry = "web/index.html", layer = "menu", zIndex = 44, width = 1920, height = 1080,
            transparent = true, visible = true, fps = 60 })
        if created or why ~= "resource_preparing" then break end
        Wait(250)
    end
    if not created then return log("no WebUI surface: %s", tostring(why)) end
    page = created
    page:on("ui:ready", function()
        pageReady = true
        log("page ready")
        if state then send("tcg:state", state) end
    end)
    for name, fn in pairs(PAGE_ACTIONS) do
        page:on(name, function(d) local ok, err = pcall(fn, type(d) == "table" and d or {}); if not ok then log("%s: %s", name, tostring(err)) end end)
    end
end)

-- /tcgbinder: the binder, or the counter's Shop tab when standing at a TCG shop.
RegisterCommand(C.command, function()
    if isOpen then closeBinder() else openBinder(nearShopId and "shop" or "binder") end
end, false)
-- Other resources (a gamemode menu, a phone app, a shop NPC) open the binder: TriggerEvent("op77_tcg:openBinder", tab).
-- Without a tab: the Shop tab at a TCG counter, the binder elsewhere.
AddEventHandler("op77_tcg:openBinder", function(tab)
    openBinder(type(tab) == "string" and tab or (nearShopId and "shop" or "binder"))
end)
-- /tcg.demo from the server console (ACL-gated there).
RegisterNetEvent(NET .. "demo", function(d)
    local action = type(d) == "table" and d.action or ""
    if action == "open" or action == "table" then
        local at = here()
        if not at then return end
        at.surface = action == "table" and (at.z + 0.9) or surfaceAhead(at)
        TriggerServerEvent(NET .. "open", "wnc", at)
    elseif action == "binder" or action == "sealed" or action == "shop" then
        openBinder(action)
    elseif action == "close" then
        TriggerEvent("op77_tcg:closeBinder")
    end
end)

-- Closes the page, an opening in progress included (it is finished for the others at once).
AddEventHandler("op77_tcg:closeBinder", function()
    isOpen = false
    stopCamera(700)
    send("tcg:close", { force = true })
    pcall(function() page:setFocus(false, false) end)
end)

-- ---------------------------------------------------------------------------------------------
-- Shops: a prompt over the counter while you stand at it.

CreateThread(function()
    while not me() do Wait(500) end
    TriggerServerEvent(NET .. "hello")
    local prompt = nil
    while true do
        Wait(400)
        local found = nil
        local at = here()
        if at and state and state.shops then
            for _, s in ipairs(state.shops) do
                local dx, dy, dz = at.x - s.x, at.y - s.y, at.z - s.z
                if dx * dx + dy * dy + dz * dz <= C.shopRadius * C.shopRadius then found = s break end
            end
        end
        local id = found and found.id or nil
        if id ~= nearShopId then
            nearShopId = id
            local kit = uikit()
            if prompt and kit then pcall(kit.clearText3D, prompt); prompt = nil end
            if found and kit then
                local ok, handle = pcall(kit.drawText3D, { position = { x = found.x, y = found.y, z = found.z + 1.6 },
                    text = found.label or "Cyberpunk TCG", sublabel = ("/%s - Recycler - Card printer"):format(C.command),
                    maxDistance = 8, accent = "#FCEE09" })
                if ok then prompt = handle end
            end
            send("tcg:shop", { shop = nearShopId })
        end
    end
end)

AddEventHandler("onResourceStop", function(name)
    if name ~= RES then return end
    stopCamera(0)
    for opener in pairs(openings) do clearOpening(opener) end
end)
