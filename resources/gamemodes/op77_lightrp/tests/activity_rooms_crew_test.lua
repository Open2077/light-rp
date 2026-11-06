-- Crews in rooms (server/modules/activity_rooms.lua) on the real crews (parties.lua): the
-- create and join of any member bring the crew, a member who cannot come stays
-- out and says why, a crew that does not fit stays out whole, one team in a team game, the
-- way out of who brought them, a crew changing or ending in the room and in the match, the Activities
-- panel, and a client that cannot name anybody. No game, no DB.
-- dofile("shared/config.lua")
dofile("server/config/activities.lua")
dofile("server/config/cyberware.lua")
local noop = function() end
local t = 1000
local providers, actions, commands, handlers, exported = {}, {}, {}, {}, {}
local events, notices, logs, results = {}, {}, {}, {}
local modules, pushes, dialogs = {}, {}, {}
LightRP = {
    db = { ready = false, schema = noop, run = noop, read = function() return false end, single = noop, query = function() return {} end },
    module = function(name, value) value.name = name; LightRP[name] = value; modules[#modules + 1] = value; return value end,
    stateProvider = function(key, fn) providers[key] = fn end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    broadcastState = noop,
    state = function(id, key) pushes[#pushes + 1] = { id = id, key = key } end,
    dialog = function(id, kind) dialogs[#dialogs + 1] = { id = id, kind = kind } end,
    eachModule = function(hook, ...)
        for _, m in ipairs(modules) do if type(m[hook]) == "function" then m[hook](...) end end
    end,
    result = function(id, ok, text, kind) results[#results + 1] = { id = id, ok = ok, text = text, kind = kind } end,
    notice = function(id, def) notices[#notices + 1] = { id = id, def = def } end,
    log = function(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end,
    nowMs = function() return t end,
    joinArgs = function(args) return table.concat(args, " ") end,
}
local chars = {}
LightRP.characters = {
    switching = {},
    get = function(id) return chars[id] end,
    displayName = function(id) return chars[id] and chars[id].firstName or ("P" .. id) end,
    isRegistered = function(id) return chars[id] ~= nil and chars[id].status == "active" end,
}
local threads, timers, loaded = {}, {}, false
CreateThread = function(fn) if loaded then threads[#threads + 1] = fn end end
SetTimeout = function(ms, fn) timers[#timers + 1] = { at = t + ms, fn = fn } end
Wait = noop
local function run() while #threads > 0 do table.remove(threads, 1)() end end
local function advance(ms)
    t = t + ms
    local due = {}
    for i = #timers, 1, -1 do if timers[i].at <= t then due[#due + 1] = table.remove(timers, i) end end
    for i = #due, 1, -1 do due[i].fn() end
    run()
end
AddEventHandler = function(name, fn) handlers[name] = fn end
local onJoin -- a provider that takes the player in this very tick
TriggerEvent = function(name, ...)
    events[#events + 1] = { name = name, args = table.pack(...) }
    if name == "op77_lightrp:activity:join" and onJoin then onJoin(...) end
end
exports = function(name, fn) exported[name] = fn end
local invoking
GetInvokingResource = function() return invoking end
GetCurrentResourceName = function() return "op77_lightrp" end
local resourceStates = { op77_arena = "running", op77_race = "running", op77_games = "running" }
GetResourceState = function(name) return resourceStates[name] or "missing" end
GetPlayers = function() local list = {}; for id in pairs(chars) do list[#list + 1] = id end; table.sort(list); return list end
local buckets, positions, life = {}, {}, {}
GetPlayerRoutingBucket = function(id) return buckets[id] or 0 end
SetPlayerRoutingBucket = function(id, b) buckets[id] = b end
Open77 = {
    players = {
        position = function(id) local p = positions[id]; return p and { x = p.x, y = p.y, z = p.z, bucket = buckets[id] or 0 } end,
        get = function(id) local p = positions[id]; if not p then return nil, "unknown" end
            return { position = { x = p.x, y = p.y, z = p.z }, heading = 0, bucket = buckets[id] or 0 } end,
        getLifeState = function(id) return { phase = life[id] or "alive" } end,
        teleport = function(id, pos, opts)
            return { await = function() buckets[id] = opts.bucket; positions[id] = { x = pos.x, y = pos.y, z = pos.z }; return true end }
        end,
        respawn = function(id, opts) life[id] = "alive"; buckets[id] = opts.bucket; return true end,
        heal = function() return true end,
    },
    vehicles = { getPlayerSeat = function() return nil end },
    time = { unix = function() return 1800000000 + math.floor(t / 1000) end },
}
LightRP.armament = { push = noop, synchronize = function() return true end }
local tiers = {}
LightRP.missions = {
    handlesDeath = function() return false end, handlesLoadout = function() return false end,
    instanceOf = function() return nil end, untag = noop, addReputation = noop,
    tier = function(id) return tiers[id] or 1 end,
}
LightRP.medical = { isDowned = function() return false end }
LightRP.tutorial = { isActive = function() return false end }
LightRP.housing = { sessions = {} }

dofile("server/config/missions.lua") -- the crew's limits
dofile("server/modules/parties.lua") -- the real crews: membership is read there
dofile("server/modules/activities.lua")
dofile("server/modules/activity_rooms.lua")
local A, R, Crew = LightRP.activities, LightRP.activityRooms, LightRP.parties
loaded = true
local CFG = LightRpActivities.rooms

local JOIN = "op77_lightrp:activity:join"
local function player(id, tier)
    chars[id] = { identifier = "acct-" .. id, key = "default", status = "active", firstName = "Runner" .. id }
    positions[id] = { x = -756.5, y = 777.2, z = 22.4 }; buckets[id] = 0; life[id] = "alive"
    tiers[id] = tier or 1
end
for id = 1, 40 do player(id) end
local function act(id, operation, extra)
    local payload = { type = "activities.rooms", operation = operation }
    for k, v in pairs(extra or {}) do payload[k] = v end
    local before = #results
    actions["activities.rooms"](id, payload)
    local r = results[#results]
    if #results > before then return r.ok, r.text end
    return nil
end
local function view(id) return providers.rooms(id) end
local function mark() return #events end
local function joins(m)
    local out = {}
    for i = m + 1, #events do if events[i].name == JOIN then out[events[i].args[1]] = events[i].args[3] end end
    return out
end
local function noticed(id, text)
    for i = #notices, 1, -1 do
        local n = notices[i]
        if n.id == id and tostring(n.def.body or ""):find(text, 1, true) then return n end
    end
end
local function refused(id, operation, extra, text)
    local ok, why = act(id, operation, extra)
    assert(ok == false, tostring(operation) .. " should be refused: " .. tostring(why))
    if text then assert(tostring(why):find(text, 1, true), tostring(operation) .. ": " .. tostring(why)) end
end
local function register(res, def)
    invoking = res
    def.resource = res
    local ok, why = exported.activityRegister(def)
    invoking = nil
    assert(ok, why)
end
local function values(x)
    if type(x) ~= "table" then return 1 end
    local n = 1
    for _, v in pairs(x) do n = n + 2 + values(v) end
    return n
end
local function register(res, def)
    invoking = res
    def.resource = res
    local ok, why = exported.activityRegister(def)
    invoking = nil
    assert(ok, why)
end
local MAPS = { { id = "map-1", label = "Map 1" }, { id = "map-2", label = "Map 2" } }
register("op77_games", { id = "games.tdm", label = "Team Deathmatch", kind = "pvp", minPlayers = 2, maxPlayers = 12, modes = MAPS, modeKey = "map" })
register("op77_games", { id = "games.gungame", label = "Gun Game", kind = "pvp", minPlayers = 2, maxPlayers = 8, modes = MAPS, modeKey = "map" })
register("op77_race", { id = "race.parkour", label = "Parkour Race", kind = "race", minPlayers = 2, maxPlayers = 8 })

-- A crew led by the first id, formed as players form one.
local function crew(...)
    local ids = { ... }
    for i = 2, #ids do
        assert(Crew.invite(ids[1], ids[i]))
        assert(Crew.accept(ids[i]))
    end
    return Crew.of(ids[1])
end
local function disband(...) for _, id in ipairs({ ... }) do if Crew.of(id) then Crew.leave(id) end end end
local function reset()
    for _, room in pairs(R.rooms) do for i = #room.members, 1, -1 do R.of[room.members[i]] = nil end end
    for id in pairs(R.rooms) do R.rooms[id] = nil end
    for id = 1, 40 do
        if Crew.of(id) then Crew.leave(id) end
        A.pending[id] = nil
        life[id] = "alive"; buckets[id] = 0
    end
    for i = #notices, 1, -1 do notices[i] = nil end
end
local function team(room, p)
    for i, side in ipairs(room.teams) do for _, q in ipairs(side) do if q == p then return i end end end
end

-- ---------------------------------------------------------------------------
-- Who triggers it: the leader, creating a room
do
    crew(1, 2, 3)
    local ok, text = act(1, "create", { id = "games.gungame", mode = "map-2" })
    assert(ok and text == "Room open. 2 crew members with you.", text)
    local room = R.of[1]
    assert(R.of[2] == room and R.of[3] == room and #room.members == 3, "the crew is in, nobody asked")
    assert(room.host == 1, "the leader hosts")
    assert(noticed(2, "opened a Gun Game room: you are in it") and noticed(3, "/leave drops you out"), "each member is told")
    advance(CFG.pushMs + 1)
    assert(view(2).room and view(2).room.mine == false, "a member sees the room")
    reset()
end

-- A private room: the code is the leader's, the crew comes without one.
do
    crew(1, 2)
    local ok, text = act(1, "create", { id = "games.gungame", private = true })
    assert(ok and text:find("^Room open%. Code: %w+%. 1 crew member with you%.$"), text)
    assert(R.of[2] == R.of[1])
    reset()
end

-- The leader joining: the rooms list and the code alike
do
    assert(act(9, "create", { id = "games.gungame" }))
    local id = R.of[9].id
    crew(1, 2, 3)
    local ok, text = act(1, "join", { id = id })
    assert(ok and text == "You joined Runner9's room. 2 crew members with you.", text)
    assert(R.of[1] == R.of[9] and R.of[2] == R.of[9] and R.of[3] == R.of[9])
    assert(noticed(9, "joined your room with 2 crew members"), "the host hears it once")
    assert(noticed(2, "joined Runner9's Gun Game room: you are in it"))
    reset()

    assert(act(9, "create", { id = "games.gungame", private = true }))
    local code = R.of[9].code
    crew(1, 2)
    assert(act(1, "join", { code = code }))
    assert(R.of[2] == R.of[9], "a code brings the crew too")
    reset()
end

-- A member brings the crew too: the leader comes with them, and the one who asked hosts
do
    crew(1, 2, 3)
    assert(act(9, "create", { id = "games.gungame" }))
    local ok, text = act(2, "join", { id = R.of[9].id })
    assert(ok and text:find("2 crew members with you", 1, true), text)
    assert(R.of[1] == R.of[9] and R.of[2] == R.of[9] and R.of[3] == R.of[9], "the whole crew, the leader included")
    assert(noticed(1, "you are in it"), "the leader is told")
    ok, text = act(2, "leave")
    assert(ok and text == "You left the room with your crew.", text)
    assert(R.of[1] == nil and R.of[3] == nil, "who brought them takes them out")
    assert(noticed(1, "left the room, and you with them"), "and says so")
    ok, text = act(3, "create", { id = "games.gungame" })
    assert(ok and text == "Room open. 2 crew members with you.", text)
    assert(R.of[3].host == 3 and R.of[1] == R.of[3] and R.of[2] == R.of[3], "the same when a member creates one")
    assert(Crew.of(3).leader == 1, "and the crew stays as it was")
    reset()
end

-- A member who cannot join stays out and hears why; the others go; the leader hears who
do
    crew(1, 2, 3, 4, 5, 6)
    life[2] = "dead"                                                 -- dead
    A.owned[3] = { activity = "games.tdm", token = "x" }             -- busy in another activity
    LightRP.missions.handlesDeath = function(p) return p == 4 end    -- on a mission
    buckets[5] = 700005                                              -- not in the shared city
    local ok, text = act(1, "create", { id = "games.gungame" })
    assert(ok, text)
    assert(#R.of[1].members == 2 and R.of[6] == R.of[1], "only who can comes: " .. #R.of[1].members)
    assert(R.of[2] == nil and R.of[3] == nil and R.of[4] == nil and R.of[5] == nil, "they stay out")
    assert(text:find("Room open. 1 crew member with you.", 1, true), text)
    assert(text:find("Runner2 stays out: you must be alive and on your feet.", 1, true), text)
    assert(text:find("Runner3 stays out: you are already in Team Deathmatch.", 1, true), text)
    assert(text:find("Runner4 stays out: you are on a mission.", 1, true), text)
    assert(text:find("Runner5 stays out: return to the shared city first.", 1, true), text)
    assert(noticed(2, "opened a Gun Game room. You stay out: you must be alive"), "the member hears it")
    assert(noticed(3, "You stay out: you are already in Team Deathmatch"))
    A.owned[3] = nil
    LightRP.missions.handlesDeath = function() return false end
    reset()
end

-- Too far is no refusal: a room is joined from anywhere (/room), as the panel's queue
do
    crew(1, 2)
    positions[2] = { x = 5000, y = 5000, z = 0 }
    assert(act(1, "create", { id = "games.gungame" }))
    assert(R.of[2] == R.of[1], "a far member comes: the start moves everyone")
    positions[2] = { x = -756.5, y = 777.2, z = 22.4 }
    reset()
end

-- A member out comes after by hand; the crew is whole again on one team
do
    crew(1, 2, 3)
    life[3] = "dead"
    assert(act(1, "create", { id = "games.tdm", size = 3 }))
    assert(R.of[3] == nil)
    life[3] = "alive"
    assert(act(3, "join", { id = R.of[1].id }))
    assert(R.of[3] == R.of[1], "the door stays open for them")
    reset()
end

-- A member in another room stays there, and is told: their own join would be refused
do
    assert(act(9, "create", { id = "games.gungame" }))
    assert(act(2, "join", { id = R.of[9].id }))
    crew(1, 2, 3)
    local other = R.of[9]
    local ok, text = act(1, "create", { id = "games.gungame" })
    assert(ok and text:find("Runner2 stays out: you are already in a room", 1, true), text)
    assert(R.of[2] == other, "not pulled out of it")
    assert(R.of[3] == R.of[1])
    reset()
end

-- A member the host removed stays removed, the crew comes
do
    assert(act(9, "create", { id = "games.gungame" }))
    local room = R.of[9]
    assert(act(2, "join", { id = room.id }))
    assert(act(9, "kick", { target = 2 }))
    crew(1, 2, 3)
    local ok, text = act(1, "join", { id = room.id })
    assert(ok and text:find("Runner2 stays out: the host removed you", 1, true), text)
    assert(R.of[2] == nil and R.of[3] == room)
    reset()
end

-- Too small for the crew: nobody moves, the leader hears why, a smaller crew would fit
do
    crew(1, 2, 3)
    refused(1, "create", { id = "games.gungame", size = 2 }, "Your crew is 3: this room takes 2. Pick a bigger room.")
    refused(1, "create", { id = "games.tdm", size = 2 }, "Your crew is 3: this room takes 2 per side. Pick a bigger room.")
    assert(next(R.rooms) == nil and R.of[1] == nil and R.of[2] == nil, "no room, nobody in")
    assert(act(1, "create", { id = "games.tdm", size = 3 }), "sides of three take it")
    reset()

    crew(1, 2, 3, 4, 5, 6, 7)
    refused(1, "create", { id = "games.tdm" }, "Your crew is 7: this room takes 6 per side. Start a friendly match")
    assert(next(R.rooms) == nil)
    reset()

    -- only who can come counts: the dead member takes no place
    crew(1, 2, 3)
    life[3] = "dead"
    assert(act(1, "create", { id = "games.gungame", size = 2 }))
    assert(R.of[2] == R.of[1] and #R.of[1].members == 2)
    reset()

    -- a room with fewer places left than the crew
    assert(act(9, "create", { id = "games.gungame", size = 3 }))
    local room = R.of[9]
    crew(1, 2, 3)
    refused(1, "join", { id = room.id }, "Your crew is 3: this room has 2 places left.")
    assert(R.of[1] == nil and R.of[2] == nil and R.of[3] == nil and #room.members == 1, "the whole crew stays out")
    reset()

    -- no team with places for all of them, though the room has enough in all
    assert(act(9, "create", { id = "games.tdm", size = 3 }))
    room = R.of[9]
    assert(act(10, "join", { id = room.id }))
    assert(#room.teams[1] == 1 and #room.teams[2] == 1)
    crew(1, 2, 3)
    refused(1, "join", { id = room.id }, "no team of this room has that many places")
    assert(R.of[1] == nil and R.of[2] == nil and R.of[3] == nil, "4 places in all, none for three on one side")
    reset()
end

-- Team games: the crew lands on one team
do
    crew(1, 2, 3)
    assert(act(1, "create", { id = "games.tdm", size = 4 }))
    local room = R.of[1]
    assert(team(room, 1) == 1 and team(room, 2) == 1 and team(room, 3) == 1, "the host's team")
    assert(act(9, "join", { id = room.id }))
    assert(team(room, 9) == 2, "a stranger fills the other side")
    assert(act(10, "join", { id = room.id }))
    assert(team(room, 10) == 2)
    assert(act(11, "join", { id = room.id }))
    assert(team(room, 11) == 2, "the smaller side, as before")
    reset()

    -- joining: the emptiest side with places for all
    assert(act(9, "create", { id = "games.tdm", size = 3 }))
    room = R.of[9]
    crew(1, 2, 3)
    assert(act(1, "join", { id = room.id }))
    assert(team(room, 1) == 2 and team(room, 2) == 2 and team(room, 3) == 2, "side B, whole")
    assert(team(room, 9) == 1)
    reset()

    -- a member who came alone first: the crew gathers on one team
    assert(act(9, "create", { id = "games.tdm", size = 3 }))
    room = R.of[9]
    assert(act(2, "join", { id = room.id }))
    assert(team(room, 2) == 2)
    assert(act(10, "join", { id = room.id }))
    assert(team(room, 10) == 1)
    crew(1, 2)
    local ok, text = act(1, "join", { id = room.id })
    assert(ok, text)
    assert(team(room, 1) == 2 and team(room, 2) == 2, "with the member who was in")
    reset()

    -- the host may still move them: a crew alone in a team game needs an opponent
    crew(1, 2)
    assert(act(1, "create", { id = "games.tdm", size = 2 }))
    room = R.of[1]
    assert(view(1).room.issue:find("Team B"), "the room says why it cannot start")
    assert(act(1, "move", { target = 2, team = 2 }) == nil)
    assert(team(room, 2) == 2 and view(1).room.issue == nil, "the host splits it by hand")
    reset()
end

-- The match: one team in options.match, a crew member who cannot go still stops the start
do
    crew(1, 2)
    assert(act(1, "create", { id = "games.tdm", size = 2 }))
    local room = R.of[1]
    assert(act(9, "join", { id = room.id }))
    assert(act(10, "join", { id = room.id }))
    local m = mark()
    life[2] = "dead"
    refused(1, "start", {}, "Runner2 cannot play")
    life[2] = "alive"
    local ok = act(1, "start")
    assert(ok, "the start")
    local sent = joins(m)
    assert(sent[1] and sent[2] and sent[9] and sent[10], "the four of them")
    local match = sent[1].match
    assert(match.friendly == true and sent[1].ranked == false, "unranked, as any room")
    assert(match.side == sent[2].match.side, "the crew plays on one side")
    assert(sent[9].match.side == sent[10].match.side and sent[9].match.side ~= match.side)
    assert(sent[1].squad and sent[1].squad.id == Crew.of(1).id, "the crew rides along")
    reset()
end

-- The leader leaves: who came with them goes too, who came alone stays
do
    assert(act(9, "create", { id = "games.gungame" }))
    local room = R.of[9]
    assert(act(3, "join", { id = room.id }))
    crew(1, 2, 3, 4)
    assert(act(1, "join", { id = room.id }))
    assert(R.of[2] == room and R.of[4] == room and R.of[3] == room)
    local ok, text = act(1, "leave")
    assert(ok and text == "You left the room with your crew.", text)
    assert(R.of[1] == nil and R.of[2] == nil and R.of[4] == nil, "they came together, they go together")
    assert(noticed(2, "left the room, and you with them"))
    assert(R.of[3] == room and R.of[9] == room, "who came alone stays, the room goes on")
    reset()

    -- a leader hosting: the room passes to who is left, never to who is leaving
    crew(1, 2)
    assert(act(1, "create", { id = "games.gungame" }))
    room = R.of[1]
    assert(act(9, "join", { id = room.id }))
    assert(act(1, "leave"))
    assert(room.host == 9 and not noticed(2, "You now host"), "the stranger takes over")
    assert(R.of[2] == nil)
    reset()

    -- a crew alone: its room closes with it
    crew(1, 2)
    assert(act(1, "create", { id = "games.gungame" }))
    assert(act(1, "leave"))
    assert(next(R.rooms) == nil and next(R.of) == nil)
    reset()

    -- a member leaving leaves alone; /leave goes the same way
    crew(1, 2, 3)
    assert(act(1, "create", { id = "games.gungame" }))
    room = R.of[1]
    assert(act(2, "leave"))
    assert(R.of[1] == room and R.of[3] == room and R.of[2] == nil, "a member takes nobody out")
    local left, said = A.requestLeave(1)
    assert(left and said == "You left the room with your crew." and R.of[3] == nil, said)
    reset()

    -- a kicked leader goes alone: the host's kick is for one player
    assert(act(9, "create", { id = "games.gungame" }))
    room = R.of[9]
    crew(1, 2)
    assert(act(1, "join", { id = room.id }))
    assert(act(9, "kick", { target = 1 }))
    assert(R.of[1] == nil and R.of[2] == room)
    reset()
end

-- A crew changing while in a room, and ending: the room stands, the game starts
do
    crew(1, 2, 3)
    assert(act(1, "create", { id = "games.gungame" }))
    local room = R.of[1]
    assert(Crew.leave(3))
    assert(R.of[3] == room, "out of the crew, still in the room: a room takes anybody")
    assert(Crew.leave(2))
    assert(Crew.of(1) == nil, "the crew dissolved")
    assert(R.of[1] == room and R.of[2] == room and #room.members == 3)
    local ok, text = act(1, "leave")
    assert(ok and text == "You left the room.", text)
    assert(R.of[2] == room and room.host == 2, "no crew left, nobody goes with them")
    reset()

    -- the leader dropping out of the city: the crew ends, the members stay, the room goes on
    crew(1, 2, 3)
    assert(act(1, "create", { id = "games.tdm", size = 3 }))
    room = R.of[1]
    Crew.onDisconnected(1)
    R.onDisconnected(1)
    assert(R.of[2] == room and R.of[3] == room and room.host == 2)
    assert(team(room, 2) == 1 and team(room, 3) == 1)
    reset()

    -- the crew ends between the set-up and the start: the sides stay what the room says
    crew(1, 2)
    assert(act(1, "create", { id = "games.tdm", size = 2 }))
    room = R.of[1]
    assert(act(9, "join", { id = room.id }))
    assert(act(10, "join", { id = room.id }))
    assert(Crew.leave(2))
    local m = mark()
    assert(act(1, "start"))
    local sent = joins(m)
    assert(sent[1].match.side == sent[2].match.side and sent[1].squad == nil, "no crew any more, the same teams")
    reset()

    -- mid-game: the crew is nothing to the match once it runs
    crew(1, 2)
    assert(act(1, "create", { id = "games.gungame" }))
    m = mark()
    assert(act(1, "start"))
    local matchId = joins(m)[1].match.id
    assert(Crew.leave(2) and A.matches[matchId], "the match stands")
    assert(A.pending[1] and A.pending[2], "and both are still on their way into it")
    reset()
end

-- The Activities panel: a member cannot, the leader brings the crew (no options.match)
do
    crew(1, 2, 3)
    life[3] = "dead"
    local ok, why = A.requestJoin(2, "games.tdm", "panel", {})
    assert(not ok and why == "Your crew leader starts activities. Leave the crew to go solo.", why)
    local m = mark()
    ok, why = A.requestJoin(1, "race.parkour", "panel", {})
    assert(ok and why:find("with 1 crew member", 1, true) and why:find("Runner3 stays out: you must be alive", 1, true), why)
    local sent = joins(m)
    assert(sent[1] and sent[2] and not sent[3], "each follower gets their own join")
    assert(sent[1].match == nil and sent[2].match == nil, "the provider's own queue: no match")
    assert(sent[1].squad.id == Crew.of(1).id and sent[2].squad.id == sent[1].squad.id, "with the crew's squad")
    assert(sent[2].squad.leader == 1 and #sent[2].squad.members == 3)
    reset()

    crew(1, 2)
    m = mark()
    assert(A.requestJoin(1, "games.tdm", "panel", { map = "map-2" }))
    local sent2 = joins(m)
    assert(sent2[2].map == "map-2" and sent2[2].squad.id == sent2[1].squad.id, "the leader's map, the same crew")
    reset()
end

-- The server decides: nothing a client sends names a player
do
    crew(1, 2)
    assert(act(5, "create", { id = "games.gungame", members = { 6, 7 }, crew = { 6, 7 }, squad = { id = "x", leader = 5, members = { 5, 6 } }, target = 6, players = { 6 } }))
    assert(#R.of[5].members == 1 and R.of[6] == nil and R.of[7] == nil, "a player with no crew brings nobody, whatever they send")
    local room = R.of[5]
    -- a member brings their real crew, and nobody the request names
    assert(act(2, "join", { id = room.id, members = { 8 }, crew = true, leader = 2, party = Crew.of(1).id }))
    assert(R.of[1] == room and R.of[2] == room and R.of[8] == nil, "only the crew the server knows")
    assert(act(2, "leave"))
    assert(R.of[1] == nil and R.of[2] == nil)
    -- the leader of a real crew pulls that crew only
    assert(act(1, "join", { id = room.id, members = { 8, 9 }, crew = { 8 } }))
    assert(R.of[8] == nil and R.of[9] == nil and R.of[2] == room, "only who the server knows")
    reset()

    -- a stale crew (a member gone from it) is read at the join, not remembered
    crew(1, 2, 3)
    assert(Crew.leave(2))
    assert(act(1, "create", { id = "games.gungame" }))
    assert(R.of[3] == R.of[1] and R.of[2] == nil, "who left stays out")
    reset()
end
print("PASS: rooms with a crew: any member's create and join bring it (list and code), a crew of one brings nobody, a member who cannot join stays out and is told (dead, activity, mission, other room, kicked), too far is no refusal, a crew that does not fit stays out whole (room, side, places left), one team in a team game (host's, emptiest, gathered, moved by hand), one side in the match, the leader's way out, a crew changing or ending in the room and in the match, the panel, nothing a client sends names a player")
