-- The relay. A replicated bubble is shown by the server to the players around
-- its anchor (or a target list, or everyone); a client asks for one over
-- `op77_actionbubble:relay` and gets the same, within the rules below. Each
-- live replicated bubble is remembered until it ends, so its updates and its
-- end reach the same players, and a player who walks into range of a long one
-- still sees it.
local C = ActionBubbleConfig
local AB = ActionBubble

local live = {}      -- id -> { id, owner = resource|playerId, sender, def, net, recipients = set, ends }
local rate = {}      -- playerId -> { times }
local counter = 0

local function now() return Open77.time.monotonic() end

-- A player's last known position. `position` answers nil once the last
-- snapshot is two seconds old (a player standing still); `get` dates it instead.
local function playerPosition(id)
    local p = Open77.players.position(id)
    if p then return p end
    if type(Open77.players.get) ~= "function" then return nil end
    local ok, read = pcall(Open77.players.get, id)
    if not ok or type(read) ~= "table" or type(read.position) ~= "table" then return nil end
    if read.ageMs and read.ageMs > 120000 then return nil end
    local q = read.position
    return { x = q.x, y = q.y, z = q.z, bucket = q.bucket or read.bucket }
end

local function players()
    local out = {}
    for _, id in ipairs(GetPlayers()) do out[#out + 1] = tonumber(id) end
    return out
end

-- Every player's position, read once per pass (one `positions` call for the
-- fresh ones, a dated read only for those standing still), reused by every
-- bubble of the pass.
local snapshot, snapshotAt = nil, -1
local function positions()
    local t = now()
    if snapshot and t - snapshotAt < 0.25 then return snapshot end
    snapshot, snapshotAt = {}, t
    local fresh = type(Open77.players.positions) == "function" and Open77.players.positions() or {}
    for _, id in ipairs(players()) do
        snapshot[id] = fresh[id] or fresh[tostring(id)] or playerPosition(id)
    end
    return snapshot
end

-- Where the anchor is, on the server (for ranges and the client reach rule).
local function anchorPosition(anchor)
    if anchor.type == "position" then return anchor.position, nil end
    if anchor.type == "player" then
        local p = playerPosition(anchor.player)
        return p, p and p.bucket
    end
    if anchor.type == "vehicle" then
        local v = Open77.vehicles.get(anchor.vehicle)
        local p = v and (v.position or (type(Open77.vehicles.getPosition) == "function" and Open77.vehicles.getPosition(anchor.vehicle)))
        return p, v and v.bucket
    end
    return nil
end

local function distance2(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return dx * dx + dy * dy + dz * dz
end
local function distance(a, b) return math.sqrt(distance2(a, b)) end

-- Who should see the bubble now: its targets, or everyone in range of the anchor.
local function audience(record)
    local net = record.net
    if net.targets == "all" then return players() end
    if type(net.targets) == "table" then return net.targets end
    local at, bucket = anchorPosition(record.def.anchor)
    if not at then return {} end
    local out, r2 = {}, net.range * net.range
    for id, p in pairs(positions()) do
        if (bucket == nil or p.bucket == nil or p.bucket == bucket) and distance2(p, at) <= r2 then out[#out + 1] = id end
    end
    return out
end

local function send(record, ids)
    for _, id in ipairs(ids) do
        if id ~= record.sender and not record.recipients[id] then
            record.recipients[id] = true
            local def = record.def
            if def.duration > 0 then
                -- what is left of it for a late arrival
                def = {}
                for k, v in pairs(record.def) do def[k] = v end
                def.duration = math.max(0.5, record.ends - now())
            end
            TriggerClientEvent("op77_actionbubble:show", id, record.id, def)
        end
    end
end

local function finish(record)
    live[record.id] = nil
    for id in pairs(record.recipients) do TriggerClientEvent("op77_actionbubble:hide", id, record.id) end
end

local function start(id, owner, sender, def, net)
    local record = { id = id, owner = owner, sender = sender, def = def, net = net, recipients = {}, started = now(),
        ends = def.duration > 0 and now() + def.duration or math.huge }
    live[id] = record
    send(record, audience(record))
    return record
end

local function applyPatch(record, patch)
    for k, v in pairs(patch) do
        if k == "offset" then record.def.anchor.offset = v
        elseif k == "position" then if record.def.anchor.type == "position" then record.def.anchor.position = v end
        elseif v == false then record.def[k] = nil
        else record.def[k] = v end
    end
    if patch.duration ~= nil then record.ends = patch.duration > 0 and now() + patch.duration or math.huge end
    for id in pairs(record.recipients) do TriggerClientEvent("op77_actionbubble:update", id, record.id, patch) end
end

-- Late arrivals and the end of each bubble, once a second.
CreateThread(function()
    while true do
        Wait(1000)
        local t = now()
        for _, record in pairs(live) do
            if t >= record.ends then finish(record)
            -- late arrivals: only for a bubble worth catching (more than a second left)
            elseif record.net.targets == nil and record.ends - t > 1.0 then send(record, audience(record)) end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- From clients

local function allowed(playerId)
    local list = rate[playerId] or {}
    local t, kept = now(), {}
    for _, at in ipairs(list) do if t - at < C.rate.window then kept[#kept + 1] = at end end
    if #kept >= C.rate.count then rate[playerId] = kept return false end
    kept[#kept + 1] = t
    rate[playerId] = kept
    return true
end

-- A client may only speak for itself: its own character, or a vehicle or a
-- point within reach of it. Entity ids are local to each client: never relayed.
local function reachable(playerId, anchor)
    if anchor.type == "player" then return anchor.player == playerId end
    if anchor.type == "entity" then return false end
    local me = playerPosition(playerId)
    local at, bucket = anchorPosition(anchor)
    if not me or not at then return false end
    if bucket ~= nil and me.bucket ~= nil and bucket ~= me.bucket then return false end
    return distance(me, at) <= C.clientReach
end

RegisterNetEvent("op77_actionbubble:relay", function(op, localId, payload)
    local playerId = tonumber(source)
    if not playerId or type(localId) ~= "number" or localId < 1 or localId ~= math.floor(localId) then return end
    local id = "c" .. playerId .. ":" .. localId
    if op == "show" then
        if not C.allowClientNetwork or not allowed(playerId) or live[id] then return end
        local def = AB.clean(type(payload) == "table" and payload.def)
        if not def then return end
        if def.anchor.self then def.anchor.self = nil; def.anchor.player = playerId end
        if not reachable(playerId, def.anchor) then return end
        if def.duration == 0 then def.duration = C.maxDuration end -- a relayed bubble always ends
        local net = AB.network(type(payload) == "table" and payload.network or true) or { range = C.range }
        net.targets = nil -- a client cannot pick who hears it: the players around do
        -- at most `perSender` bubbles of one player at a time: the oldest ends
        local mine = {}
        for _, record in pairs(live) do if record.sender == playerId then mine[#mine + 1] = record end end
        table.sort(mine, function(a, b) return a.started < b.started end)
        for i = 1, #mine - C.perSender + 1 do finish(mine[i]) end
        start(id, playerId, playerId, def, net)
    elseif op == "update" then
        local record = live[id]
        if not record or record.sender ~= playerId or not allowed(playerId) then return end
        local patch = AB.patch(payload)
        if not patch then return end
        if patch.duration == 0 then patch.duration = C.maxDuration end
        patch.position = nil -- a relayed bubble does not move to another point
        applyPatch(record, patch)
    elseif op == "hide" then
        local record = live[id]
        if record and record.sender == playerId then finish(record) end
    end
end)

AddEventHandler("onPlayerDisconnected", function(playerIdStr)
    local playerId = tonumber(playerIdStr)
    if not playerId then return end
    rate[playerId] = nil
    for _, record in pairs(live) do
        if record.sender == playerId or (record.def.anchor.type == "player" and record.def.anchor.player == playerId) then
            finish(record)
        else
            record.recipients[playerId] = nil
        end
    end
end)

AddEventHandler("onResourceStop", function(name)
    for _, record in pairs(live) do
        if record.owner == name then finish(record) end
    end
end)

-- ---------------------------------------------------------------------------
-- Exports for server resources
--
--   local id = exports.op77_actionbubble:show({
--       text = "Opens the trunk", player = 12,          -- or vehicle = id, position = {x,y,z}
--       duration = 4, kind = "action", icon = "trunk",
--       network = { range = 20 },                        -- or { targets = {12, 15} } / { targets = "all" }
--   })
--   exports.op77_actionbubble:update(id, { text = "Closes the trunk" })
--   exports.op77_actionbubble:hide(id)

local function owner() return GetInvokingResource() or GetCurrentResourceName() end

local function serverShow(def, who)
    local clean, why = AB.clean(def)
    if not clean then return nil, why end
    if clean.anchor.self then return nil, "anchor_required" end
    if clean.anchor.type == "entity" then return nil, "entity_anchor_is_client_only" end
    counter = counter + 1
    local id = "s:" .. counter
    start(id, who, nil, clean, AB.network(type(def) == "table" and def.network or true) or { range = C.range })
    return id
end
exports("show", function(def) return serverShow(def, owner()) end)

exports("update", function(id, patch)
    local record = live[id]
    if not record or record.sender ~= nil then return false, "not_found" end
    if record.owner ~= owner() then return false, "owned_by_another_resource" end
    local clean, why = AB.patch(patch)
    if not clean then return false, why end
    applyPatch(record, clean)
    return true
end)

exports("hide", function(id)
    local record = live[id]
    if not record or record.sender ~= nil then return false, "not_found" end
    if record.owner ~= owner() then return false, "owned_by_another_resource" end
    finish(record)
    return true
end)

exports("clear", function()
    local who, n = owner(), 0
    for _, record in pairs(live) do
        if record.owner == who and record.sender == nil then finish(record); n = n + 1 end
    end
    return n
end)

exports("exists", function(id) return live[id] ~= nil end)

exports("list", function()
    local out = {}
    for id, record in pairs(live) do
        local n = 0
        for _ in pairs(record.recipients) do n = n + 1 end
        out[#out + 1] = { id = id, owner = record.owner, text = record.def.text, anchor = record.def.anchor.type, recipients = n,
            remaining = record.ends == math.huge and 0 or math.max(0, record.ends - now()) }
    end
    return out
end)

-- Console / ACL test: actionbubble.test <playerId> <text...>
--   shows the text on that player's character, replicated to the players around.
RegisterCommand("actionbubble.test", function(source, args)
    local target = tonumber(args[1])
    local text = table.concat(args, " ", 2)
    local id, why = nil, "usage: actionbubble.test <playerId> <text>"
    if target and text ~= "" then
        id, why = serverShow({ text = text, player = target, duration = 6, icon = "hand", network = { range = 40 } }, GetCurrentResourceName())
    end
    local result = id and ("bubble " .. id .. " on player " .. target) or ("failed: " .. tostring(why))
    print("[actionbubble] " .. result)
    if source and source > 0 then TriggerClientEvent("open77:command:result", source, "actionbubble.test", id ~= nil, result) end
end, true)

-- Console / ACL test: actionbubble.vehicle <playerId> [text...]
--   a bubble on the vehicle closest to that player (60 m), shown to that player only.
RegisterCommand("actionbubble.vehicle", function(source, args)
    local target = tonumber(args[1])
    local text = table.concat(args, " ", 2)
    local ok, v, why = pcall(Open77.vehicles.closest, target, { radius = 60 })
    local id = ok and type(v) == "table" and (v.id or v.vehicleId)
    if not id then
        local seat = Open77.vehicles.getPlayerSeat(target)
        id = type(seat) == "table" and seat.vehicleId
    end
    if not id then print("[actionbubble] no vehicle within 60 m of player " .. tostring(target) .. " (" .. tostring(ok and (why or v) or v) .. ")") return end
    local bubble, why = serverShow({ text = text ~= "" and text or "Unlocks the vehicle", vehicle = id, icon = "unlock", author = "Test",
        duration = 8, network = { targets = { target } } }, GetCurrentResourceName())
    print("[actionbubble] " .. (bubble and ("bubble " .. bubble .. " on vehicle " .. tostring(id)) or ("failed: " .. tostring(why))))
end, true)

-- Console / ACL test: actionbubble.cartest <playerId> [range]
--   a temporary car 7 m in front of that player with a bubble on it (that player only, or `range`: the
--   players within 20 m of the car, as the lock and trunk bubbles), removed after 12 s.
RegisterCommand("actionbubble.cartest", function(source, args)
    local target = tonumber(args[1])
    local p = target and playerPosition(target)
    if not p then print("[actionbubble] usage: actionbubble.cartest <playerId>") return end
    -- 7 m in front of them (yaw 0 faces +Y, counter-clockwise), across their view
    local read = type(Open77.players.get) == "function" and Open77.players.get(target) or {}
    local yaw = math.rad(tonumber(read.heading or read.yaw) or 0)
    local fx, fy = -math.sin(yaw), math.cos(yaw)
    local car, why = Open77.vehicles.create({ record = "Vehicle.v_standard2_archer_hella_player",
        position = { x = p.x + fx * 7, y = p.y + fy * 7, z = p.z + 0.3 }, yaw = math.deg(yaw) + 90, bucket = p.bucket or 0 })
    if not car then print("[actionbubble] cartest: vehicle refused: " .. tostring(why)) return end
    CreateThread(function()
        Wait(1500) -- let it stream in
        local bubble, err = serverShow({ text = "Unlocks the vehicle", vehicle = car, icon = "unlock", duration = 8,
            network = args[2] == "range" and { range = 20 } or { targets = { target } } }, GetCurrentResourceName())
        print("[actionbubble] cartest: car " .. tostring(car) .. ", bubble " .. tostring(bubble or err))
        Wait(10500)
        pcall(Open77.vehicles.remove, car)
        print("[actionbubble] cartest: car " .. tostring(car) .. " removed")
    end)
end, true)

-- Console / ACL test: actionbubble.around <playerId> [text...]
--   four position bubbles 5 m around that player (north, east, south, west), one kind each.
RegisterCommand("actionbubble.around", function(source, args)
    local target = tonumber(args[1])
    local p = target and playerPosition(target)
    local text = table.concat(args, " ", 2)
    if not p then print("[actionbubble] usage: actionbubble.around <playerId> [text]") return end
    local spots = { { 0, 5, "action", "trunk", "Opens the trunk" }, { 5, 0, "state", "lock", "The door is locked." },
        { 0, -5, "alert", "alert", "Smells of smoke" }, { -5, 0, "speech", "chat", "Whispers something" } }
    for _, s in ipairs(spots) do
        serverShow({ text = text ~= "" and text or s[5], kind = s[3], icon = s[4], author = "Test", duration = 10,
            position = { x = p.x + s[1], y = p.y + s[2], z = p.z + 1.4 }, network = { targets = { target } } }, GetCurrentResourceName())
    end
    print("[actionbubble] 4 bubbles around player " .. target)
end, true)
