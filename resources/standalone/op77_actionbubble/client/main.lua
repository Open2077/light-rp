-- The bubbles on this client: their anchors, lifetimes and the page that draws
-- them. Every bubble gets one `Open77.anchors` anchor fed to the page: the
-- plugin projects it on every game frame (an entity anchor follows the body)
-- and pushes the screen position to the page, which only animates. The local
-- player's own body has no entity id an anchor accepts, so a bubble on it is a
-- position anchor this script moves every frame.
--
-- API (client exports, any resource) -- README.md has the whole reference:
--   local id = exports.op77_actionbubble:show({ text = "Opens the trunk", vehicle = vehId, duration = 4, network = true })
--   exports.op77_actionbubble:update(id, { text = "Closes the trunk" })
--   exports.op77_actionbubble:hide(id)
--   exports.op77_actionbubble:me("Unlocks the vehicle", { duration = 3 })   -- on yourself, replicated
local C = ActionBubbleConfig
local AB = ActionBubble

local page, pageReady = nil, false
local bubbles = {}        -- id -> bubble
local order = {}          -- ids, oldest first
local localCount, relayCount = 0, 0
local anchorsOk = type(Open77.anchors) == "table" and type(Open77.anchors.create) == "function"
local warned = {}

local function now() return Open77.time.monotonic() end
local function warn(key, text)
    if warned[key] then return end
    warned[key] = true
    print("[actionbubble] " .. text)
end

local function localPlayer()
    if type(Open77.players.localId) == "function" then
        local ok, id = pcall(Open77.players.localId)
        if ok and tonumber(id) then return tonumber(id) end
    end
    local state = type(Open77.network) == "table" and Open77.network.status and Open77.network.status()
    return state and tonumber(state.playerId)
end

local function send(name, payload)
    if page and pageReady then page:send(name, payload) end
end

-- ---------------------------------------------------------------------------
-- Anchors

-- Your own body's position: `nearby` centred on yourself, with yourself in it.
local SELF = { includeSelf = true, limit = 1 }
local function localPosition()
    local ok, list = pcall(Open77.players.nearby, 0.5, SELF)
    if not ok or type(list) ~= "table" then return nil end
    for _, entry in ipairs(list) do
        if entry.isLocal and type(entry.position) == "table" then return entry.position end
    end
end

-- What the anchor of a bubble resolves to here: an entity id, a point, or nil
-- (the body or the vehicle is not streamed on this client right now).
local function resolve(b)
    local a = b.def.anchor
    if a.type == "position" then
        return nil, { x = a.position.x + a.offset.x, y = a.position.y + a.offset.y, z = a.position.z + a.offset.z }
    end
    if a.type == "entity" then return tostring(a.entity) end
    if a.type == "player" then
        if a.player == localPlayer() then
            local p = localPosition()
            return nil, p and { x = p.x + a.offset.x, y = p.y + a.offset.y, z = p.z + a.offset.z }, true
        end
        local ok, entity = pcall(Open77.players.entity, a.player)
        if ok and entity and tostring(entity) ~= "0" then return tostring(entity) end
        return nil
    end
    if a.type == "vehicle" then
        local ok, v = pcall(Open77.vehicles.get, a.vehicle)
        if ok and type(v) == "table" and v.entity and tostring(v.entity) ~= "0" then return tostring(v.entity) end
    end
    return nil
end

local function dropAnchor(b)
    if b.anchor then pcall(Open77.anchors.remove, b.anchor) end
    b.anchor, b.entity, b.follow = nil, nil, false
end

-- Creates, retargets or moves the anchor of a bubble. Returns true when it has one.
local function syncAnchor(b)
    if not anchorsOk or not page then return false end
    local entity, point, follow = resolve(b)
    if entity == nil and point == nil then
        if b.anchor then dropAnchor(b); send("ab:anchor", { id = b.id, anchor = false }) end
        return false
    end
    local kind = entity and "entity" or "position"
    if b.anchor and b.kind ~= kind then dropAnchor(b) end
    if b.anchor then
        if entity and entity ~= b.entity then
            local ok, res = pcall(Open77.anchors.update, b.anchor, { entity = entity })
            if not ok or res == false then dropAnchor(b) else b.entity = entity end
        elseif point and (follow or b.moved) then
            pcall(Open77.anchors.update, b.anchor, { position = point })
            b.moved = false
        end
        if b.anchor then return true end
    end
    local options = { page = page, tag = "actionbubble", maxDistance = b.def.maxDistance, minDistance = 0.0 }
    if entity then options.entity = entity; options.offset = b.def.anchor.offset else options.position = point end
    local id, why = Open77.anchors.create(options)
    if not id then
        if why == "anchors_backend_unavailable" then anchorsOk = false end
        warn("anchor:" .. tostring(why), "anchor refused: " .. tostring(why))
        return false
    end
    b.anchor, b.kind, b.entity, b.follow = id, kind, entity, follow == true
    send("ab:anchor", { id = b.id, anchor = tostring(id) })
    return true
end

-- ---------------------------------------------------------------------------
-- Bubbles

local function groupKey(a)
    if a.type == "position" then return string.format("position:%.1f:%.1f:%.1f", a.position.x, a.position.y, a.position.z) end
    return a.type .. ":" .. tostring(a[a.type])
end

local function pageDef(b)
    local d = b.def
    local kind = C.kinds[d.kind] or C.kinds.action
    return {
        id = b.id, text = d.text, kind = d.kind, label = kind.label, accent = d.accent or kind.accent,
        icon = d.icon, author = d.author, asterisks = d.asterisks, side = d.side,
        duration = d.duration, remaining = b.ends == math.huge and 0 or math.max(0, b.ends - now()),
        maxDistance = d.maxDistance, anchor = b.anchor and tostring(b.anchor) or false,
        -- bubbles on the same target stack instead of overlapping
        group = groupKey(d.anchor),
    }
end

local function forget(id)
    bubbles[id] = nil
    for i, other in ipairs(order) do if other == id then table.remove(order, i) break end end
end

-- Ends a bubble: the page plays its exit, the anchor stays a moment for it.
local function leave(b, instant)
    if b.leaving then return end
    b.leaving = now() + (instant and 0 or 0.75)
    send("ab:remove", { id = b.id, instant = instant == true })
end

local function finishNow(b)
    dropAnchor(b)
    forget(b.id)
end

local function add(id, def, owner, relayed)
    local old = bubbles[id]
    if old then finishNow(old); send("ab:remove", { id = id, instant = true }) end
    while #order >= C.maxBubbles do
        local oldest = bubbles[order[1]]
        if not oldest then table.remove(order, 1) else finishNow(oldest); send("ab:remove", { id = oldest.id, instant = true }) end
    end
    if def.anchor.self then def.anchor.self = nil; def.anchor.player = localPlayer() or 0 end
    -- at most `perTarget` bubbles stacked on one target: the oldest goes
    local key = groupKey(def.anchor)
    local same = {}
    for _, other in ipairs(order) do
        local o = bubbles[other]
        if o and not o.leaving and groupKey(o.def.anchor) == key then same[#same + 1] = o end
    end
    for i = 1, #same - C.perTarget + 1 do leave(same[i]) end
    local b = { id = id, def = def, owner = owner, relayed = relayed, ends = def.duration > 0 and now() + def.duration or math.huge }
    bubbles[id] = b
    order[#order + 1] = id
    syncAnchor(b)
    send("ab:add", pageDef(b))
    return b
end

local function patchBubble(b, patch)
    for k, v in pairs(patch) do
        if k == "offset" then b.def.anchor.offset = v; dropAnchor(b)
        elseif k == "position" then
            if b.def.anchor.type == "position" then b.def.anchor.position = v; b.moved = true end
        elseif v == false then b.def[k] = nil
        else b.def[k] = v end
    end
    if patch.duration ~= nil then b.ends = patch.duration > 0 and now() + patch.duration or math.huge end
    syncAnchor(b)
    send("ab:update", pageDef(b))
end

-- Lifetimes and anchors: every frame while a bubble is on the local body (its
-- anchor is a point this script moves), else ten times a second.
CreateThread(function()
    while true do
        local t, fast = now(), false
        for _, id in ipairs({ table.unpack(order) }) do
            local b = bubbles[id]
            if b then
                if b.leaving then
                    if t >= b.leaving then finishNow(b) end
                    if b.follow then syncAnchor(b); fast = true end
                elseif t >= b.ends then
                    leave(b)
                else
                    b.nextSync = b.nextSync or 0
                    if b.follow or t >= b.nextSync then
                        syncAnchor(b)
                        b.nextSync = t + 0.1
                    end
                    if b.follow then fast = true end
                end
            end
        end
        Wait(fast and 0 or 100)
    end
end)

-- ---------------------------------------------------------------------------
-- The page

local function createPage()
    local created, why
    for _ = 1, 120 do
        created, why = WebUI.create({
            entry = "web/index.html", layer = "hud", width = 1920, height = 1080,
            fps = 60, zIndex = 640, transparent = true, visible = true,
        })
        if created or why ~= "resource_preparing" then break end
        Wait(250)
    end
    if not created then print("[actionbubble] no WebUI surface: " .. tostring(why)) return end
    page = created
    page:on("ab:ready", function()
        pageReady = true
        send("ab:config", { kinds = C.kinds })
        for _, id in ipairs(order) do
            local b = bubbles[id]
            if b and not b.leaving then send("ab:add", pageDef(b)) end
        end
    end)
    if not anchorsOk then warn("anchors", "Open77.anchors unavailable on this client: bubbles cannot be placed") end
end

AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    CreateThread(createPage)
end)

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then
        if anchorsOk then pcall(Open77.anchors.clear) end
        return
    end
    for _, b in pairs(bubbles) do
        if b.owner == name then leave(b, true) end
    end
end)

-- ---------------------------------------------------------------------------
-- From the relay

RegisterNetEvent("op77_actionbubble:show", function(id, def)
    if type(id) ~= "string" then return end
    local clean = AB.clean(def)
    if clean then add(id, clean, "net", false) end
end)
RegisterNetEvent("op77_actionbubble:update", function(id, patch)
    local b = type(id) == "string" and bubbles[id]
    local clean = b and AB.patch(patch)
    if clean then patchBubble(b, clean) end
end)
RegisterNetEvent("op77_actionbubble:hide", function(id)
    local b = type(id) == "string" and bubbles[id]
    if b then leave(b) end
end)

-- ---------------------------------------------------------------------------
-- Exports

local function caller() return GetInvokingResource() or GetCurrentResourceName() end

local function show(def, who)
    local clean, why = AB.clean(def)
    if not clean then return nil, why end
    local network = type(def) == "table" and AB.network(def.network)
    if network then
        if clean.anchor.type == "entity" then return nil, "entity_anchor_is_local_only" end
        local me = localPlayer()
        if not me then return nil, "no_session" end
        if clean.anchor.self then clean.anchor.self = nil; clean.anchor.player = me end
        if clean.duration == 0 then clean.duration = C.maxDuration end
        relayCount = relayCount + 1
        local id = "c" .. me .. ":" .. relayCount
        TriggerServerEvent("op77_actionbubble:relay", "show", relayCount, { def = clean, network = { range = network.range } })
        add(id, clean, who, relayCount)
        return id
    end
    localCount = localCount + 1
    local id = "l:" .. localCount
    add(id, clean, who, false)
    return id
end

local function owned(id)
    local b = type(id) == "string" and bubbles[id]
    if not b or b.leaving then return nil, "not_found" end
    if b.owner ~= caller() then return nil, "owned_by_another_resource" end
    return b
end

exports("show", function(def) return show(def, caller()) end)

--- On yourself, replicated to the players around: me(text, { duration, kind, icon, range, network = false }).
exports("me", function(text, opts)
    opts = type(opts) == "table" and opts or {}
    local def = {}
    for k, v in pairs(opts) do def[k] = v end
    def.text = text
    def.anchor = { type = "player", self = true, offset = opts.offset }
    if opts.network == nil then def.network = { range = opts.range } end
    return show(def, caller())
end)

exports("update", function(id, patch)
    local b, why = owned(id)
    if not b then return false, why end
    local clean, bad = AB.patch(patch)
    if not clean then return false, bad end
    if b.relayed then
        if clean.duration == 0 then clean.duration = C.maxDuration end
        clean.position = nil
        TriggerServerEvent("op77_actionbubble:relay", "update", b.relayed, clean)
    end
    patchBubble(b, clean)
    return true
end)

exports("hide", function(id)
    local b, why = owned(id)
    if not b then return false, why end
    if b.relayed then TriggerServerEvent("op77_actionbubble:relay", "hide", b.relayed) end
    leave(b)
    return true
end)

exports("clear", function()
    local who, n = caller(), 0
    for _, b in pairs(bubbles) do
        if b.owner == who and not b.leaving then
            if b.relayed then TriggerServerEvent("op77_actionbubble:relay", "hide", b.relayed) end
            leave(b); n = n + 1
        end
    end
    return n
end)

exports("exists", function(id) return type(id) == "string" and bubbles[id] ~= nil and not bubbles[id].leaving end)

exports("list", function()
    local out = {}
    for _, id in ipairs(order) do
        local b = bubbles[id]
        if b and not b.leaving then
            out[#out + 1] = { id = id, owner = b.owner, text = b.def.text, anchor = b.def.anchor.type, placed = b.anchor ~= nil,
                remaining = b.ends == math.huge and 0 or math.max(0, b.ends - now()) }
        end
    end
    return out
end)
