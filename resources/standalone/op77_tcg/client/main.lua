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
    -- The sealed pack in the right hand.
    o.pack = createProp(def.pack, { x = a.x, y = a.y, z = a.z + 1.2 }, a.yaw, C.scale.pack)
    if o.pack then attachToHand(o.pack, opener, { x = 0.0, y = 0.05, z = 0.02 }, { x = 75.0, y = 0.0, z = 180.0 }) end
    if opener == me() then
        send("tcg:opening", { seq = p.seq, product = p.product, cards = cards, fresh = p.fresh or "", table = a.surface ~= nil })
        isOpen = true
        pcall(function() page:show() end)
        pcall(function() page:setFocus(true, true) end)
    end
end)

RegisterNetEvent(NET .. "reveal", function(p)
    if type(p) ~= "table" then return end
    local o = openings[tonumber(p.opener)]
    if not o or o.seq ~= p.seq then return end
    if p.stage == "tear" then
        sound3D("booster_open.wav", { x = o.anchor.x, y = o.anchor.y, z = o.anchor.z + 1.2 }, 15)
        remove(o.pack)
        o.pack = nil
        return
    end
    -- Late joiners and skipped reveals: deal everything up to this card.
    remove(o.pack); o.pack = nil
    for k = 1, math.min(tonumber(p.index) or 0, #o.cards) do deal(o, k) end
    if p.finished then
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
    notify(("%s offers you a card - open your binder (%s)"):format(p.name or "Someone", C.keys.binder))
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
    isOpen = true
    pcall(function() page:show() end)
    send("tcg:open", { tab = tab or "binder", shop = nearShopId, nearby = nearbyCollectors() })
    pcall(function() page:setFocus(true, true) end)
    TriggerServerEvent(NET .. "state")
end

local function closeBinder()
    isOpen = false
    send("tcg:close", {})
    pcall(function() page:setFocus(false, false) end)
end

local function openPack(product)
    local at = here()
    if not at then return end
    at.surface = surfaceAhead(at)
    closeBinder()
    TriggerServerEvent(NET .. "open", product, at)
end

local function placeCard(edition)
    local at = here()
    if not at then return end
    local surface = surfaceAhead(at)
    if not surface then return notify("Stand at a table or a counter to lay a card down.") end
    local fx, fy = forward(at.yaw)
    TriggerServerEvent(NET .. "place", edition, { x = at.x + fx * C.opening.tableReach, y = at.y + fy * C.opening.tableReach, z = surface + 0.002 }, at.yaw)
end

local PAGE_ACTIONS = {
    ["tcg:close"] = function() closeBinder() end,
    ["tcg:openPack"] = function(d) openPack(d.product) end,
    ["tcg:revealed"] = function(d) TriggerServerEvent(NET .. "reveal", { seq = d.seq, stage = d.stage, index = d.index }) end,
    ["tcg:openingDone"] = function() closeBinder() end,
    ["tcg:recycle"] = function(d) TriggerServerEvent(NET .. "recycle", d.id, d.count) end,
    ["tcg:print"] = function(d) TriggerServerEvent(NET .. "print", d.id) end,
    ["tcg:buy"] = function(d) TriggerServerEvent(NET .. "buy", d.product) end,
    ["tcg:unbox"] = function(d) TriggerServerEvent(NET .. "unbox", d.product) end,
    ["tcg:show"] = function(d) closeBinder(); TriggerServerEvent(NET .. "show", d.id) end,
    ["tcg:place"] = function(d) closeBinder(); placeCard(d.id) end,
    ["tcg:offer"] = function(d) TriggerServerEvent(NET .. "offer", d.target, d.id) end,
    ["tcg:answer"] = function(d) TriggerServerEvent(NET .. "answer", d.id, d.accept == true) end,
    ["tcg:sfx"] = function(d)
        local names = { tear = "booster_open.wav" }
        if names[d.name] then pcall(Open77.audio.play2D, "sounds/" .. names[d.name], { volume = 0.8 }) end
    end,
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
        if state then send("tcg:state", state) end
    end)
    for name, fn in pairs(PAGE_ACTIONS) do
        page:on(name, function(d) local ok, err = pcall(fn, type(d) == "table" and d or {}); if not ok then log("%s: %s", name, tostring(err)) end end)
    end
end)

RegisterKeyMapping("op77_tcg_binder", "Cyberpunk TCG: binder", C.keys.binder, function()
    if isOpen then closeBinder() else openBinder(nearShopId and "shop" or "binder") end
end)

RegisterCommand("binder", function() openBinder("binder") end, false)
RegisterCommand("tcg", function() openBinder("binder") end, false)

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
                    text = found.label or "Cyberpunk TCG", sublabel = ("[%s] Boosters - Recycler - Card printer"):format(C.keys.binder),
                    maxDistance = 8, accent = "#FCEE09" })
                if ok then prompt = handle end
            end
            send("tcg:shop", { shop = nearShopId })
        end
    end
end)

AddEventHandler("onResourceStop", function(name)
    if name ~= RES then return end
    for opener in pairs(openings) do clearOpening(opener) end
end)
