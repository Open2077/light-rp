-- Rooms (server/modules/activity_rooms.lua, the friendly launch of activities.lua): the
-- hosting menu, hostile input, public and private rooms, teams and sizes, every way out
-- of a room, the re-check at the start, the unranked match it starts, a provider that
-- stops, and the state pushes. No game, no DB.
dofile("shared/config.lua")
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
local crews = {}
LightRP.parties = { of = function(id) return crews[id] end }

dofile("server/modules/activities.lua")
dofile("server/modules/activity_rooms.lua")
local A, R = LightRP.activities, LightRP.activityRooms
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
local function reset() for _, room in pairs(R.rooms) do for i = #room.members, 1, -1 do act(room.members[i], "leave") end end end

local MAPS = {}
for i = 1, 8 do MAPS[i] = { id = "map-" .. i, label = "Map " .. i } end
register("op77_games", { id = "games.tdm", label = "Team Deathmatch", kind = "pvp", minPlayers = 2, maxPlayers = 12, modes = MAPS, modeKey = "map" })
register("op77_games", { id = "games.gungame", label = "Gun Game", kind = "pvp", minPlayers = 2, maxPlayers = 8, modes = MAPS, modeKey = "map" })
register("op77_arena", { id = "arena.ffa", label = "Combat Zone", kind = "pvp", maxPlayers = 16, botFill = true })
register("op77_arena", { id = "arena.duel", label = "Duel", kind = "pvp", minPlayers = 2, maxPlayers = 2 })
register("op77_arena", { id = "arena.pve", label = "Combat Zone PvE", kind = "pvp", pve = true, maxPlayers = 6 })
register("op77_race", { id = "race.grid", label = "Street Race", kind = "race", minPlayers = 2, maxPlayers = 8 })

-- ---------------------------------------------------------------------------
-- The menu lists what is registered and offered, nothing else
do
    local names = {}
    for i, g in ipairs(view(1).games) do names[i] = g.id end
    assert(table.concat(names, ",") == "arena.ffa,games.gungame,games.tdm,race.grid",
        "a provider that is missing disappears, a duel or PvE is not hosted: " .. table.concat(names, ","))
    local tdm = view(1).games[3]
    assert(tdm.teams == 2 and tdm.least == 1 and tdm.most == 6, "two sides of at most half the players")
    assert(view(1).games[2].teams == nil and view(1).games[2].least == 2 and view(1).games[2].most == 8, "free-for-all: the whole room")
    assert(view(1).room == false and view(1).eligible == true and view(1).enabled == true and #view(1).list == 0)
end
-- every id of the spec is offered by the config, as the shape it plays
do
    local list = LightRpActivities.lobby.activities
    for _, id in ipairs({ "games.tdm", "games.ctf", "games.control" }) do assert(list[id].friendly and list[id].rooms and list[id].teams == 2, id) end
    for _, id in ipairs({ "games.gungame", "games.redlight", "games.prophunt", "race.parkour", "arena.ffa", "race.grid", "race.foot" }) do
        assert(list[id].friendly and list[id].rooms and list[id].teams == nil, id)
    end
    assert(A.ownsBucket(4500000) and A.ownsBucket(4599999) and not A.ownsBucket(4600000), "op77_games' buckets")
end

-- ---------------------------------------------------------------------------
-- Hostile input: every operation, with junk
refused(1, "create", { id = "games.nothing" }, "cannot be hosted")
refused(1, "create", {}, "cannot be hosted")
refused(1, "create", { id = 7 }, "cannot be hosted")
refused(1, "create", { id = { "games.tdm" } }, "cannot be hosted")
refused(1, "create", { id = "arena.duel" }, "cannot be hosted")
refused(1, "create", { id = "arena.pve" }, "cannot be hosted")
refused(1, "create", { id = "games.tdm", mode = "nowhere" }, "map")
refused(1, "create", { id = "games.tdm", mode = { "map-1" } }, "map")
for _, size in ipairs({ 0, -1, 7, 1.5, 0 / 0, math.huge, "4", {} }) do
    refused(1, "create", { id = "games.tdm", size = size }, "size")
end
refused(1, "create", { id = "games.gungame", size = 1 }, "size") -- a room of one never starts
refused(1, "create", { id = "games.gungame", size = 9 }, "size") -- oversized
refused(1, "nonsense", {}, "Unknown")
refused(1, nil, {}, "Unknown")
refused(1, "__index", {}, "Unknown")
for _, op in ipairs({ "kick", "move", "settings", "start", "leave" }) do refused(1, op, { target = 2, team = 1 }, "not in a room") end
for _, junk in ipairs({ { id = "x" }, { id = 1e308 }, { id = 0 / 0 }, { id = -1 }, { code = {} }, {} }) do
    refused(1, "join", junk, "gone")
end
refused(1, "join", { code = "ZZZZZ" }, "code")
refused(1, "join", { code = ("A"):rep(4000) }, "gone")
assert(next(R.rooms) == nil and next(R.of) == nil, "nothing was created by any of that")

-- ---------------------------------------------------------------------------
-- A public team room: joining fills the smaller side, the host is told
local ok, text = act(1, "create", { id = "games.tdm", mode = "map-3", size = 2 })
assert(ok and text == "Room open.", text)
refused(1, "create", { id = "games.tdm" }, "already in a room")
local v = view(1)
assert(v.room and v.room.mine == true and v.room.private == false and v.room.code == nil and v.room.mode == "map-3" and v.room.modeLabel == "Map 3")
assert(v.room.max == 4 and v.room.count == 1 and v.room.teams[1][1].id == 1 and v.room.teams[1][1].host == true and #v.room.teams[2] == 0)
assert(v.room.issue:find("Team B"), "why it cannot start: " .. tostring(v.room.issue))
assert(#view(9).list == 1 and view(9).list[1].host == "Runner1" and view(9).list[1].teams == 2, "listed for everyone")
local roomId = v.room.id
assert(act(2, "join", { id = roomId }))
assert(noticed(1, "Runner2 joined"), "the host hears of it")
v = view(2)
assert(v.room.mine == false and #v.room.teams[1] == 1 and #v.room.teams[2] == 1 and v.room.teams[2][1].id == 2 and v.room.issue == nil)
assert(act(2, "join", { id = roomId }) == nil, "already in it: nothing happens")
assert(act(3, "join", { id = roomId }))
assert(act(4, "join", { id = roomId }))
refused(5, "join", { id = roomId }, "full")
assert(#view(1).room.teams[1] == 2 and #view(1).room.teams[2] == 2)

-- only the host: a member and a stranger get the same answer on everything
for _, who in ipairs({ 2, 5 }) do
    local why = who == 2 and "Only the host" or "not in a room"
    refused(who, "kick", { target = 3 }, why)
    refused(who, "move", { target = 3, team = 1 }, why)
    refused(who, "settings", { mode = "map-1" }, why)
    refused(who, "start", {}, why)
end
assert(#view(1).room.teams[1] == 2 and view(1).room.mode == "map-3")

-- move: junk, then a full side swaps, sizes hold
refused(1, "move", { target = 5, team = 1 }, "not in your room")
refused(1, "move", { target = "x", team = 1 }, "not in your room")
refused(1, "move", { target = 2, team = 0 }, "No such team")
refused(1, "move", { target = 2, team = 3 }, "No such team")
refused(1, "move", { target = 2, team = "1" }, "No such team")
refused(1, "move", { target = 2 }, "No such team")
assert(act(1, "move", { target = 2, team = 1 }) == nil, "a move answers with the push")
v = view(1)
assert(#v.room.teams[1] == 2 and #v.room.teams[2] == 2, "a full side swaps: sizes hold")
assert(v.room.teams[1][2].id == 2, "moved")

-- settings: junk changes nothing, in one piece
refused(1, "settings", { mode = "nowhere", size = 1, private = true }, "map")
assert(view(1).room.size == 2 and view(1).room.private == false, "a refused change touches nothing")
refused(1, "settings", { size = 1 }, "already in")
refused(1, "settings", { size = 99 }, "size")
assert(act(1, "settings", { mode = "", size = 3 }) == nil)
assert(view(1).room.mode == nil and view(1).room.size == 3 and view(1).room.max == 6, "any map, a bigger room")

-- kick: the host only, out for good, the rest stays
refused(1, "kick", { target = 1 }, "Leave the room")
refused(1, "kick", { target = 5 }, "not in your room")
assert(act(1, "kick", { target = 3 }))
assert(view(3).room == false and noticed(3, "removed you"), "told")
refused(3, "join", { id = roomId }, "removed you")

-- ---------------------------------------------------------------------------
-- A private room: a code, never listed, never joined by id
reset()
assert(next(R.rooms) == nil, "the last one out closes the room")
ok, text = act(1, "create", { id = "games.gungame", private = true })
assert(ok, text)
v = view(1)
local code = v.room.code
assert(type(code) == "string" and #code == CFG.codeLength and code:match("^[A-HJ-NP-Z2-9]+$") and text:find(code, 1, true), "a readable code")
assert(v.room.private == true and #view(9).list == 0, "a private room is not listed")
refused(2, "join", { id = v.room.id }, "gone") -- no difference from a room that does not exist
refused(2, "join", { code = "AAAAA" == code and "BBBBB" or "AAAAA" }, "code")
assert(act(2, "join", { code = " " .. code:lower() .. " " }), "typed loosely")
assert(view(2).room.code == code and view(2).room.players[2].id == 2, "a member sees the code")
refused(1, "move", { target = 2, team = 1 }, "no teams")
-- to public and back: the list follows, the code goes
assert(act(1, "settings", { private = false }) == nil)
assert(view(1).room.code == nil and #view(9).list == 1)
refused(3, "join", { code = code }, "code")
assert(act(1, "settings", { private = true }) == nil)
assert(view(1).room.code and #view(9).list == 0)

-- ---------------------------------------------------------------------------
-- Eligibility: to create, to join, and again at the start for every member
reset()
life[1] = "dead"
refused(1, "create", { id = "games.gungame" }, "alive")
life[1] = "alive"
buckets[3] = 77
refused(3, "create", { id = "games.gungame" }, "shared city")
assert(view(3).eligible == false and view(3).reason:find("shared city"), "the menu says why")
assert(act(1, "create", { id = "games.gungame" }))
refused(3, "join", { id = view(1).room.id }, "shared city")
buckets[3] = 0
refused(1, "start", {}, "needs 2 players")
assert(act(2, "join", { id = view(1).room.id }))
buckets[2] = 77
local m = mark()
refused(1, "start", {}, "Runner2 cannot play")
assert(results[#results].text:find("Kick them or wait", 1, true))
assert(next(joins(m)) == nil and view(1).room, "nothing went out, the room stays")
buckets[2] = 0
life[1] = "dead"
refused(1, "start", {}, "You cannot play")
life[1] = "alive"

-- ---------------------------------------------------------------------------
-- The start: the friendly path, whole. A provider entering in the same tick does not
-- read as "another activity".
reset()
assert(act(1, "create", { id = "games.tdm", mode = "map-2" }))
roomId = view(1).room.id
assert(act(2, "join", { id = roomId }))
assert(act(3, "join", { id = roomId }))
m = mark()
onJoin = function(id, aid)
    invoking = "op77_games"
    local entered, why = exported.activityEnter(id, aid)
    invoking = nil
    assert(entered, why)
end
ok, text = act(1, "start")
onJoin = nil
assert(ok and text:find("unranked", 1, true), text)
local sent = joins(m)
assert(sent[1] and sent[2] and sent[3], "everybody")
local o = sent[2]
assert(o.ranked == false and o.map == "map-2" and o.from == "room", "the map under the provider's modeKey, unranked")
assert(o.match.friendly == true and o.match.ranked == false and #o.match.players == 3 and o.match.format == "map-2", "no crew")
assert(o.match.teams[1][1] == 1 and o.match.teams[2][1] == 2 and o.match.teams[1][2] == 3 and o.match.side == 2, "the room's sides")
assert(o.squad == nil, "no crew in it")
assert(A.isRanked(1) == false and A.current(1).friendly == true, "the entry is unranked")
assert(next(R.rooms) == nil and view(1).room == false and #view(1).list == 0, "the room ends with the start")
assert(noticed(2, "Unranked") , "the members are told")
-- nothing is recorded, the recap still hears it
local recapped
LightRP.recap = { activityResult = function(id) recapped = id end, reward = noop }
invoking = "op77_games"
assert(A.result(1, "games.tdm", { won = true, placement = 1, stats = { kills = 9 } }))
invoking = nil
run()
LightRP.recap = nil
assert(recapped == 1 and #A.memoryRows() == 0, "no stats, the recap shows")
invoking = "op77_games"
for id = 1, 3 do exported.activityLeave(id, "games.tdm", { returnPlayer = false }) end
invoking = nil

-- a provider that takes them later (the usual case): pending for the match, no crew needed
assert(act(1, "create", { id = "arena.ffa" }))
assert(act(2, "join", { id = view(1).room.id }))
m = mark()
assert(act(1, "start"))
sent = joins(m)
assert(sent[1].match.teams == nil and #sent[1].match.players == 2 and sent[1].fill == nil, "free-for-all, no bots")
assert(A.pending[1].friendly == true and A.pending[2].match == A.pending[1].match)
A.pending[1], A.pending[2] = nil, nil

-- a search that was running lets go at the start
assert(act(1, "create", { id = "games.gungame" }))
assert(act(2, "join", { id = view(1).room.id }))
A.pending[2] = { activity = "race.grid", at = t, ranked = true }
m = mark()
assert(act(1, "start"))
local left = false
for i = m + 1, #events do if events[i].name == "op77_lightrp:activity:leaveRequest" and events[i].args[1] == 2 then left = true end end
assert(left and A.pending[2].activity == "games.gungame", "the other queue let go")
A.pending[1], A.pending[2] = nil, nil

-- ---------------------------------------------------------------------------
-- Leaving: the host's seat passes on, the last one closes it
assert(act(1, "create", { id = "games.gungame" }))
roomId = view(1).room.id
assert(act(2, "join", { id = roomId }))
assert(act(3, "join", { id = roomId }))
assert(act(1, "leave"))
assert(view(1).room == false and view(2).room.mine == true and noticed(2, "now host"), "the next member hosts")
-- disconnect
LightRP.eachModule("onDisconnected", 2)
assert(view(3).room.mine == true and view(3).room.count == 1 and R.of[2] == nil, "a disconnect passes it on too")
LightRP.eachModule("onCharacterSwitched", 3, {})
assert(next(R.rooms) == nil and R.of[3] == nil, "another character: out, and the empty room closes")

-- entering another activity takes the player out
assert(act(1, "create", { id = "games.gungame" }))
assert(act(2, "join", { id = view(1).room.id }))
invoking = "op77_race"
assert(exported.activityEnter(2, "race.grid"))
invoking = nil
assert(R.of[2] == nil and view(1).room.count == 1 and noticed(2, "you left the room"), "gone from the room")
refused(2, "join", { id = view(1).room.id }, "already in")
invoking = "op77_race"
exported.activityLeave(2, "race.grid", { returnPlayer = false })
invoking = nil
-- a mission fires no activity event: the upkeep sees it
assert(act(2, "join", { id = view(1).room.id }))
LightRP.missions.handlesDeath = function(id) return id == 2 end
R.tick()
LightRP.missions.handlesDeath = function() return false end
assert(R.of[2] == nil and noticed(2, "busy elsewhere"))
-- /leave reaches the room, /room reopens it
do
    local leftOk, leftText = A.requestLeave(1)
    assert(leftOk and leftText:find("left the room"), leftText)
    assert(select(2, A.requestLeave(1)):find("not in an activity"))
    local before = #dialogs
    commands.room(4)
    assert(dialogs[#dialogs].kind == "rooms" and #dialogs == before + 1 and R.watchers[4] == true)
    assert(pushes[#pushes].key == "rooms" and pushes[#pushes - 1].key == "activities", "both come with the menu")
    -- its own action type: the 250 ms limit per type can never eat it after a click
    assert(actions["activities.rooms.close"], "a type of its own")
    actions["activities.rooms.close"](4, { type = "activities.rooms.close" })
    assert(R.watchers[4] == nil)
end

-- idle: ten minutes untouched, any change restarts them
assert(CFG.idleMs == 600000)
assert(act(1, "create", { id = "games.gungame" }))
roomId = view(1).room.id
t = t + CFG.idleMs - 1000
R.tick()
assert(R.rooms[roomId], "not yet")
assert(act(2, "join", { id = roomId }))
t = t + CFG.idleMs - 1000
R.tick()
assert(R.rooms[roomId], "a join counts")
t = t + 1000
R.tick()
assert(R.rooms[roomId] == nil and R.of[1] == nil and R.of[2] == nil and noticed(2, "closed"), "expired")

-- the limit per server: private rooms count
for id = 1, CFG.maxRooms do assert(act(id, "create", { id = "games.gungame", mode = "map-1", private = id > CFG.maxRooms - 2 })) end
assert(view(40).full == true and #view(40).list == CFG.maxRooms - 2, "private rooms count, unlisted")
refused(40, "create", { id = "games.gungame" }, "Every room")
assert(act(1, "leave"))
assert(view(40).full == false and act(40, "create", { id = "games.gungame", mode = "map-1" }), "a freed slot")
for id = 25, 39 do if id <= 31 then assert(act(id, "join", { id = view(40).room.id })) end end
-- the wire: a full list, the room of the largest game
do
    local bytes = values(view(40))
    assert(bytes < 900, "the state key fits a plain event: " .. bytes)
end
reset()
assert(next(R.rooms) == nil)

-- ---------------------------------------------------------------------------
-- A provider stops: its rooms close; a reload keeps them; the start checks the map again
assert(act(1, "create", { id = "games.tdm", mode = "map-2" }))
assert(act(2, "join", { id = view(1).room.id }))
assert(act(3, "create", { id = "race.grid" }))
assert(act(4, "join", { id = view(3).room.id }))
handlers.onResourceStarting("op77_games")
register("op77_games", { id = "games.tdm", label = "Team Deathmatch", kind = "pvp", minPlayers = 2, maxPlayers = 12, modes = { MAPS[1] }, modeKey = "map" })
handlers.onResourceStop("op77_games", "reload")
assert(R.of[1] and R.of[2], "a reload keeps the room")
m = mark()
refused(1, "start", {}, "map")
assert(next(joins(m)) == nil, "its map went with the reload: refused, not sent")
assert(act(1, "settings", { mode = "map-1" }) == nil)
resourceStates.op77_games = "stopped"
handlers.onResourceStop("op77_games", "manual")
assert(A.registry["games.tdm"] == nil and R.of[1] == nil and R.of[2] == nil, "the provider went: so did its room")
assert(noticed(2, "room closed"), "told")
assert(R.of[3], "another provider's room stays")
for _, g in ipairs(view(9).games) do assert(g.id:sub(1, 6) ~= "games.", "the menu dropped it: " .. g.id) end
refused(1, "create", { id = "games.tdm" }, "cannot be hosted")
-- a room whose provider vanished under it: refused, the room closes
A.registry["race.grid"] = nil
m = mark()
refused(3, "start", {}, "cannot be hosted")
assert(next(joins(m)) == nil and R.of[3] == nil and R.of[4] == nil and noticed(4, "room closed"), "a room with no game closes")
resourceStates.op77_games = "running"
register("op77_games", { id = "games.gungame", label = "Gun Game", kind = "pvp", minPlayers = 2, maxPlayers = 8, modes = MAPS, modeKey = "map" })
register("op77_race", { id = "race.grid", label = "Street Race", kind = "race", minPlayers = 2, maxPlayers = 8 })
-- joining a room whose game went (no forget heard): gone too
assert(act(1, "create", { id = "games.gungame" }))
roomId = view(1).room.id
local saved = A.registry["games.gungame"]
A.registry["games.gungame"] = nil
refused(2, "join", { id = roomId }, "gone")
assert(R.rooms[roomId] == nil and R.of[1] == nil)
A.registry["games.gungame"] = saved

-- ---------------------------------------------------------------------------
-- Pushes: on change only, coalesced; a private room's business stays its own
advance(1000)
local function pushed(fn)
    local before = #pushes
    fn()
    advance(CFG.pushMs + 1)
    local set = {}
    for i = before + 1, #pushes do if pushes[i].key == "rooms" then set[pushes[i].id] = (set[pushes[i].id] or 0) + 1 end end
    return set
end
act(9, "open")
act(10, "open")
advance(1000)
local set = pushed(function() act(1, "create", { id = "games.gungame" }) end)
assert(set[1] == 1 and set[9] == 1 and set[10] == 1, "a public room reaches every open menu, once")
roomId = view(1).room.id
set = pushed(function() act(2, "join", { id = roomId }); act(3, "join", { id = roomId }) end)
assert(set[1] == 1 and set[2] == 1 and set[3] == 1 and set[9] == 1, "two changes, one push each")
set = pushed(function() act(5, "kick", { target = 2 }); act(7, "nonsense"); act(2, "start") end)
assert(next(set) == nil, "a refused request changes nothing, and pushes nothing")
set = pushed(function() assert(act(1, "settings", { private = true }) == nil) end)
assert(set[9] == 1 and set[2] == 1, "going private leaves the list: the menus hear of it")
set = pushed(function() assert(act(1, "settings", { size = 7 }) == nil) end)
assert(set[1] == 1 and set[2] == 1 and set[9] == nil, "a private room stays between its members")
set = pushed(function() assert(act(2, "leave")) end)
assert(set[2] == 1 and set[1] == 1 and set[9] == nil, "whoever left hears of it too")
act(1, "leave")
act(3, "leave")
reset()

-- A hurt player with the menu open: the cooldown ends, the menu hears once; nothing else
-- goes out, and the activities list stays live past watchMs.
do
    local hurt = 12
    local cooldown = LightRpActivities.damageCooldownMs
    R.open(hurt)
    advance(1000)
    assert(view(hurt).eligible == true)
    local until_ = t + cooldown
    handlers["open77:playerDamaged"](hurt, 0, 10)
    set = pushed(function() R.watchTick() end)
    assert(set[hurt] == 1, "the change goes out")
    for _ = 1, 20 do
        set = pushed(function() t = t + 1000; R.watchTick() end)
        assert(set[hurt] == nil, "a countdown running down is no change")
    end
    t = until_ + 1
    set = pushed(function() R.watchTick() end)
    assert(set[hurt] == 1 and view(hurt).eligible == true, "the cooldown ended: the menu hears of it")
    set = pushed(function() R.watchTick() end)
    assert(set[hurt] == nil, "and only once")
    -- the panel's watch would run out; an open menu renews it
    local watch, renewed = A.watch, 0
    A.watch = function(id) if id == hurt then renewed = renewed + 1 end return watch(id) end
    R.watchTick()
    A.watch = watch
    assert(renewed == 1, "renewed while the menu is open")
    actions["activities.rooms.close"](hurt, {})
    assert(R.watchers[hurt] == nil)
    set = pushed(function() R.watchTick() end)
    assert(next(set) == nil, "a closed menu hears nothing")
end
act(9, "close")
actions["activities.rooms.close"](9, {})
actions["activities.rooms.close"](10, {})

-- In and out: the host hears once a minute, and only the first coming counts for the room.
do
    assert(act(1, "create", { id = "games.gungame" }))
    local id = view(1).room.id
    local room = R.rooms[id]
    local function joinedNotices()
        local n = 0
        for _, entry in ipairs(notices) do
            if entry.id == 1 and tostring(entry.def.body):find("Runner2 joined your room", 1, true) then n = n + 1 end
        end
        return n
    end
    local before = joinedNotices()
    assert(act(2, "join", { id = id }))
    local at = room.at
    assert(joinedNotices() == before + 1, "the first coming")
    for _ = 1, 5 do
        t = t + 1000
        assert(act(2, "leave"))
        assert(room.at == at, "a leaver keeps nothing alive")
        assert(act(2, "join", { id = id }))
        assert(room.at == at, "nor does coming back")
    end
    assert(joinedNotices() == before + 1, "no flood")
    t = t + CFG.joinNoticeMs
    assert(act(2, "leave"))
    assert(act(2, "join", { id = id }))
    assert(joinedNotices() == before + 2, "a minute later it is news again")
    assert(room.at == at, "still not a reason to stay open")
    -- the room closes on time however the player keeps at it
    t = at + CFG.idleMs
    R.tick()
    assert(R.rooms[id] == nil, "idle")
    -- the host going hands over, and the new host gets the time to act
    assert(act(1, "create", { id = "games.gungame" }))
    id = view(1).room.id
    room = R.rooms[id]
    assert(act(2, "join", { id = id }))
    t = t + 5000
    assert(act(1, "leave"))
    assert(room.host == 2 and room.at == t, "a handover counts")
    reset()
end

-- A set-up of the host's crew does not outlive the room's start.
do
    local crew = { id = "crew-1", leader = 1, members = { 1, 3 } }
    crews[1], crews[3] = crew, crew
    assert(A.friendlyOpen(1, "games.gungame"))
    assert(A.friendlies[1], "a crew set-up")
    assert(act(1, "create", { id = "games.gungame" }))
    assert(act(2, "join", { id = view(1).room.id }))
    assert(act(1, "start"))
    assert(A.friendlies[1] == nil, "gone with the start")
    crews[1], crews[3] = nil, nil
    A.pending[1], A.pending[2] = nil, nil
end
print("PASS: hosting menu (registered and offered only, spec ids), hostile input on every operation, public and private rooms (code, list, wrong code), team placement and per-side size, kick, move, settings, re-check at the start, the friendly path (no crew, unranked, map, teams, nothing recorded, recap), search withdrawn, host handover, disconnect, character switch, another activity, mission, idle expiry, server limit, wire size, provider stop and reload, pushes on change only")
