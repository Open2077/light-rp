-- op77_tcg private rooms (shared/rooms.lua): a host behind NEON DECK's counter opens a room for a group of friends.
-- Each room is one of three styles built under the shop (level -1), instanced in its own routing bucket, with a
-- 5-character code; whoever has the code joins from the host. Players are taken down and back with
-- Open77.players.teleport (bucket switched before the move, fades). A room nobody is in closes after a while.
local S = TcgServer
local R = TcgRooms
local NET = "op77_tcg:"

TcgRoomState = { rooms = {}, byBucket = {}, byPlayer = {} }
local st = TcgRoomState
local busy = {}          -- player -> true while a teleport is in flight
local hostNpc = nil

-- ---------------------------------------------------------------------------------------------
-- Rooms

local function newCode()
    for _ = 1, 50 do
        local c = {}
        for i = 1, R.codeLength do
            local k = math.random(#R.codeChars)
            c[i] = R.codeChars:sub(k, k)
        end
        local code = table.concat(c)
        if not st.rooms[code] then return code end
    end
end

local function newBucket()
    for i = 1, 100000 do
        local b = R.bucketBase + i
        if not st.byBucket[b] then return b end
    end
end

local function count(room) local n = 0; for _ in pairs(room.members) do n = n + 1 end; return n end

local function view(room)
    if not room then return nil end
    local names = {}
    for p in pairs(room.members) do names[#names + 1] = S.name(p) end
    table.sort(names)
    return { code = room.code, style = room.style, label = R.styles[room.style].label, owner = room.ownerName,
             players = names, count = #names, max = R.maxPlayers }
end

local function sendState(player)
    TriggerClientEvent(NET .. "roomState", player, { room = view(st.byPlayer[player]), styles = R.styleList() })
end

local function broadcast(room) for p in pairs(room.members) do sendState(p) end end

local function closeRoom(room, reason)
    st.rooms[room.code] = nil
    st.byBucket[room.bucket] = nil
    S.log("room %s (%s, bucket %d) closed: %s", room.code, room.style, room.bucket, tostring(reason))
end

-- Await an Open77 promise from a thread: true, value | false, reason.
local function await(promise)
    if type(promise) ~= "table" then return false, "no_promise" end
    if type(promise.await) == "function" then
        local ok, res = pcall(promise.await, promise)
        if ok then return true, res end
        return false, res
    end
    return true, promise
end

local function teleport(player, pos, heading, bucket)
    local ok, promise, why = pcall(Open77.players.teleport, player, pos, { heading = heading, bucket = bucket, fade = true })
    if not ok then return false, promise end
    if not promise then return false, why end
    return await(promise)
end

local REASONS = {
    player_in_vehicle = "Get out of your vehicle first.",
    player_not_alive = "You can't go down right now.",
    player_not_ready = "You can't go down right now.",
}

local function nearHost(player)
    local p = S.positionOf(player)
    if not p or (tonumber(p.bucket) or 0) ~= 0 then return false end
    return S.dist(p, R.talkPoint()) <= R.host.talkRadius + 1.5
end

-- Take a player down into a room (the room exists already).
local function enter(player, room)
    if busy[player] then return end
    if count(room) >= R.maxPlayers then return S.notify(player, "This room is full.", "error") end
    busy[player] = true
    local pos, heading = R.arrival(room.style, count(room) + 1)
    local ok, why = teleport(player, pos, heading, room.bucket)
    busy[player] = nil
    if not ok then
        S.notify(player, REASONS[tostring(why)] or ("The way down is blocked (" .. tostring(why) .. ")."), "error")
        if count(room) == 0 and not room.emptySince then room.emptySince = S.now() end
        return
    end
    room.members[player] = true
    room.emptySince = nil
    st.byPlayer[player] = room
    S.log("%s entered room %s (%s)", S.name(player), room.code, room.style)
    broadcast(room)
    TriggerClientEvent(NET .. "roomEntered", player, view(room))
end

-- Out of the room's membership (no move).
local function forget(player)
    local room = st.byPlayer[player]
    st.byPlayer[player] = nil
    if not room then return end
    room.members[player] = nil
    if count(room) == 0 then room.emptySince = S.now() end
    broadcast(room)
end

-- Back up to the shop, in front of the host.
local function backUp(player)
    if busy[player] then return end
    if TcgDuelApi and TcgDuelApi.inMatch(player) then TcgDuelApi.leave(player, "left the room") end
    forget(player)
    busy[player] = true
    local pos, heading = R.backPoint()
    local ok, why = teleport(player, pos, heading, 0)
    busy[player] = nil
    if not ok then S.notify(player, "The way up is blocked (" .. tostring(why) .. "). Try again.", "error") end
    sendState(player)
end

-- ---------------------------------------------------------------------------------------------
-- Requests from the client

S.handler("rooms", function(player)
    sendState(player)
end)

S.handler("roomCreate", function(player, style)
    style = tostring(style or "")
    if not R.styles[style] then return S.notify(player, "Unknown room.", "error") end
    if st.byPlayer[player] then return S.notify(player, "You are already in a private room.", "error") end
    if not nearHost(player) then return S.notify(player, "Talk to the host at the NEON DECK counter.", "error") end
    local n = 0
    for _ in pairs(st.rooms) do n = n + 1 end
    if n >= R.maxRooms then return S.notify(player, "Every private room is taken. Try again in a moment.", "error") end
    local code, bucket = newCode(), newBucket()
    if not code or not bucket then return S.notify(player, "No room available right now.", "error") end
    local s = S.session(player)
    local room = { code = code, style = style, bucket = bucket, owner = s and s.identifier, ownerName = S.name(player),
                   members = {}, created = S.now(), emptySince = S.now() }
    st.rooms[code] = room
    st.byBucket[bucket] = room
    if Open77.routingBuckets then
        pcall(Open77.routingBuckets.setPopulationEnabled, bucket, false)
    end
    S.log("room %s (%s, bucket %d) opened by %s", code, style, bucket, S.name(player))
    enter(player, room)
end)

S.handler("roomJoin", function(player, code)
    code = tostring(code or ""):upper():gsub("[^%w]", "")
    local room = st.rooms[code]
    if not room then return S.notify(player, "No room with the code " .. code .. ".", "error") end
    if st.byPlayer[player] == room then return sendState(player) end
    if st.byPlayer[player] then return S.notify(player, "Leave your room first.", "error") end
    if not nearHost(player) then return S.notify(player, "Talk to the host at the NEON DECK counter.", "error") end
    enter(player, room)
end)

-- The exit door of a room. Also for someone standing in a room without being in one (a reconnect puts a player
-- back where they were, in the public bucket): they are brought up all the same.
S.handler("roomExit", function(player)
    local p = S.positionOf(player)
    if not st.byPlayer[player] and not (p and R.styleAt(p)) then return end
    backUp(player)
end)

AddEventHandler("playerDropped", function()
    local p = source
    busy[p] = nil
    forget(p)
end)

-- ---------------------------------------------------------------------------------------------
-- The host behind the counter

local function spawnHost()
    if type(Open77.npcs) ~= "table" or type(Open77.npcs.create) ~= "function" then
        return S.log("rooms: NPC API unavailable, the host is invisible but the counter still works")
    end
    local pos, heading = R.hostPosition()
    local def = { record = R.host.record, position = pos, yaw = heading, bucket = 0, persistent = false,
                  despawnWhenUnobserved = false, streamingRadius = 120.0,
                  behavior = { combatEnabled = false, perceptionEnabled = false, voiceEnabled = false } }
    if type(Open77.npcs.damage) == "table" then def.damagePolicy = Open77.npcs.damage.invulnerable or Open77.npcs.damage.immortal end
    if type(Open77.npcs.ai) == "table" then def.aiMode = Open77.npcs.ai.tasks end
    local ok, id, why = pcall(Open77.npcs.create, def)
    if not ok or not id then return S.log("rooms: host NPC refused (%s)", tostring(ok and why or id)) end
    pcall(Open77.npcs.setAIEnabled, id, false)
    hostNpc = id
    S.log("rooms: host NPC %s at the counter", tostring(id))
end

CreateThread(function()
    while not S.isReady() do Wait(200) end
    spawnHost()
    while true do
        Wait(30000)
        local t = S.now()
        for _, room in pairs(st.rooms) do
            if count(room) == 0 and room.emptySince and t - room.emptySince > R.emptyCloseMs then closeRoom(room, "empty") end
        end
    end
end)

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    if hostNpc and Open77.npcs and Open77.npcs.remove then pcall(Open77.npcs.remove, hostNpc) end
end)

-- Staff: /tcg.rooms (list).
RegisterCommand("tcg.rooms", function(src)
    local lines = {}
    for code, room in pairs(st.rooms) do
        lines[#lines + 1] = ("%s %s bucket %d, %d player(s)"):format(code, room.style, room.bucket, count(room))
    end
    local text = #lines > 0 and table.concat(lines, " | ") or "no private room open"
    if src and src > 0 then S.notify(src, text, "info") else print("[op77_tcg] " .. text) end
end, true)

exports("roomOf", function(player)
    local room = st.byPlayer[tonumber(player)]
    return room and view(room) or nil
end)
