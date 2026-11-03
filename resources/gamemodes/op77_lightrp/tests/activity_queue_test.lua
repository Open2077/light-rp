-- The queue panel (server/modules/activity_queue.lua): one queue state per player fed by
-- the core's joins (ranked search, match on its way, provider join), the providers' own
-- queues (status.queue v1, and the fallback without it), the mission boards; pushed on
-- change only; cleared on entry, leave, drop, character change and disconnect; the
-- leave action (cancel key, F1) for every kind of queue, never a running activity; the
-- roster limits and the payload's size. No game, no DB.
dofile("shared/config.lua")
dofile("server/config/activities.lua")
dofile("server/config/cyberware.lua")
local noop = function() end
local t = 1000
local providers, actions, commands, handlers, exported = {}, {}, {}, {}, {}
local events, notices, logs, results, pushes = {}, {}, {}, {}, {}
LightRP = {
    db = { ready = false, schema = noop, run = noop, read = function() return false end, single = noop, query = function() return {} end },
    module = function(name, value) value.name = name; LightRP[name] = value; return value end,
    stateProvider = function(key, fn) providers[key] = fn end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    state = function(id, keys) pushes[#pushes + 1] = { id = id, keys = keys } end,
    eachModule = noop, broadcastState = noop, dialog = noop,
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
AddEventHandler = function(name, fn) handlers[name] = fn end
TriggerEvent = function(name, ...) events[#events + 1] = { name = name, args = table.pack(...) } end
exports = function(name, fn) exported[name] = fn end
local invoking
GetInvokingResource = function() return invoking end
GetCurrentResourceName = function() return "op77_lightrp" end
local resourceStates = { op77_arena = "running", op77_race = "running", op77_turf = "running", op77_chase = "running" }
GetResourceState = function(name) return resourceStates[name] or "missing" end
GetPlayers = function() local list = {}; for id in pairs(chars) do list[#list + 1] = id end; table.sort(list); return list end
local buckets, positions = {}, {}
GetPlayerRoutingBucket = function(id) return buckets[id] or 0 end
SetPlayerRoutingBucket = function(id, b) buckets[id] = b end
Open77 = {
    players = {
        position = function(id) local p = positions[id]; return p and { x = p.x, y = p.y, z = p.z, bucket = buckets[id] or 0 } end,
        get = function(id) local p = positions[id]; if not p then return nil, "unknown" end
            return { position = { x = p.x, y = p.y, z = p.z }, heading = 0, bucket = buckets[id] or 0 } end,
        getLifeState = function() return { phase = "alive" } end,
        teleport = function(id, pos, opts)
            return { await = function() buckets[id] = opts.bucket; positions[id] = { x = pos.x, y = pos.y, z = pos.z }; return true end }
        end,
        respawn = function(id, opts) buckets[id] = opts.bucket; return true end,
        heal = function() return true end,
    },
    vehicles = { getPlayerSeat = function() return nil end },
    time = { unix = function() return 1800000000 + math.floor(t / 1000) end },
}
LightRP.armament = { push = noop, synchronize = function() return true end }
-- the mission boards: a tagged board per player, untag takes them off
local boards, untagged = {}, {}
LightRP.missions = {
    handlesDeath = function() return false end, handlesLoadout = function() return false end,
    instanceOf = function() return nil end, addReputation = noop, tier = function() return 1 end,
    untag = function(id) untagged[#untagged + 1] = id; boards[id] = nil end,
    queueEntry = function(id) return boards[id] end,
    queuedPlayers = function() local list = {}; for id in pairs(boards) do list[#list + 1] = id end; return list end,
}
LightRP.medical = { isDowned = function() return false end }
LightRP.tutorial = { isActive = function() return false end }
LightRP.housing = { sessions = {} }
local crews = {}
LightRP.parties = { of = function(id) return crews[id] end }

dofile("server/modules/activities.lua")
dofile("server/modules/activity_queue.lua")
local A, Q = LightRP.activities, LightRP.activityQueue
loaded = true

local JOIN, LEAVE = "op77_lightrp:activity:join", "op77_lightrp:activity:leaveRequest"
local function player(id)
    chars[id] = { identifier = "acct-" .. id, key = "default", status = "active", firstName = "Runner" .. id }
    positions[id] = { x = -756.5, y = 777.2, z = 22.4 }; buckets[id] = 0
end
local function mark() return #events end
local function after(m, name)
    local out = {}
    for i = m + 1, #events do if events[i].name == name then out[#out + 1] = events[i] end end
    return out
end
local function pushed(since, id)
    local n = 0
    for i = since + 1, #pushes do if pushes[i].id == id and pushes[i].keys == "queue" then n = n + 1 end end
    return n
end
local function view(id) return providers.queue(id) end
local function values(x) if type(x) ~= "table" then return 1 end local n = 1; for k, v in pairs(x) do n = n + 1 + values(v) end; return n end
local function status(aid, res, s) invoking = res; A.status(aid, s); invoking = nil end
local function enter(id, aid, res) invoking = res; local ok, why = exported.activityEnter(id, aid); invoking = nil; return ok, why end
local function leave(id, aid, res) invoking = res; exported.activityLeave(id, aid, { returnPlayer = false }); invoking = nil end
local function base(s) s.phase = s.phase or "lobby"; s.players = s.players or 0; s.queued = s.queued or 0; s.joinable = true; s.detail = s.detail or ""; return s end

invoking = "op77_chase"
assert(exported.activityRegister({ id = "chase.1v1", resource = "op77_chase", label = "NCPD Chase", kind = "chase", minPlayers = 2, maxPlayers = 2 }))
assert(exported.activityRegister({ id = "chase.wanted", resource = "op77_chase", label = "Most Wanted", kind = "chase", minPlayers = 3, maxPlayers = 8 }))
invoking = "op77_arena"
assert(exported.activityRegister({ id = "arena.duel", resource = "op77_arena", label = "Duel", kind = "pvp", minPlayers = 2, maxPlayers = 2 }))
invoking = "op77_turf"
assert(exported.activityRegister({ id = "turf.war", resource = "op77_turf", label = "Turf War", kind = "pvp", minPlayers = 4, maxPlayers = 24 }))
invoking = nil
run()
for id = 1, 9 do player(id) end
assert(view(1) == false and actions["queue.leave"], "nobody queued: no panel; the leave action exists")

-- ---------------------------------------------------------------------------
-- A provider queue without the shape (an older provider): the activity's numbers
local p0, m = #pushes, mark()
assert(A.requestJoin(1, "chase.wanted", "panel", {}))
assert(#after(m, JOIN) == 1)
local v = view(1)
assert(v and v.v == 1 and v.id == "chase.wanted" and v.label == "Most Wanted" and v.source == "provider" and v.state == "waiting", "a join shows at once")
assert(v.count == 1 and v.need == 3 and v.max == 8 and v.sinceMs == 0 and v.startsInMs == nil, "fallback: minPlayers / maxPlayers")
assert(pushed(p0, 1) == 1, "pushed once on the join")
t = t + 4000
assert(view(1).sinceMs == 4000)
p0 = #pushes
Q.tick()
assert(pushed(p0, 1) == 0, "the wait is the page's to count: no push every second")
status("chase.wanted", "op77_chase", base({ queued = 2 }))
assert(view(1).count == 2 and pushed(p0, 1) == 1, "the status' queued count moves the fallback")

-- ...then the provider sends its queue: the lobby's numbers and its countdown
local tick0 = #timers
p0 = #pushes
status("chase.wanted", "op77_chase", base({ queued = 2, queue = { v = 1, lobbies = { { players = { 1, 2, 3 }, need = 3, max = 8, startsInMs = 20000, mode = "car or foot" } } } }))
assert(#timers == tick0, "a queue that moved does not push every open Activities panel")
v = view(1)
assert(v.count == 3 and v.need == 3 and v.max == 8 and v.state == "starting" and v.startsInMs == 20000 and v.mode == "car or foot")
assert(v.sinceMs == 4000, "the wait counts from the join, not from the roster")
assert(pushed(p0, 1) == 1 and pushed(p0, 2) == 1 and pushed(p0, 3) == 1, "every listed player hears of it")
local two = view(2)
assert(two.id == "chase.wanted" and two.source == "provider" and two.sinceMs == 0, "queued by the provider's own command: shown too")
-- the same countdown re-sent a moment later: nothing; a moved start: pushed
t = t + 1000
p0 = #pushes
status("chase.wanted", "op77_chase", base({ queued = 2, queue = { v = 1, lobbies = { { players = { 1, 2, 3 }, need = 3, max = 8, startsInMs = 19100, mode = "car or foot" } } } }))
assert(pushed(p0, 1) == 0 and view(1).startsInMs == 19000, "the same start: no push")
status("chase.wanted", "op77_chase", base({ queued = 2, queue = { v = 1, lobbies = { { players = { 1, 2, 3 }, need = 3, max = 8, startsInMs = 5000, mode = "car or foot" } } } }))
assert(pushed(p0, 1) == 1 and view(1).startsInMs == 5000, "a full lobby shortens the start: pushed")
-- a player who left the provider's queue: their panel goes; an unknown version is no roster
p0 = #pushes
status("chase.wanted", "op77_chase", base({ queued = 2, queue = { v = 1, lobbies = { { players = { 1, 3 }, need = 3, max = 8 } } } }))
assert(view(2) == false and pushed(p0, 2) == 1 and view(1).count == 2 and view(1).state == "waiting")
status("chase.wanted", "op77_chase", base({ queued = 2, queue = { v = 2, lobbies = { { players = { 1, 3 }, need = 9 } } } }))
assert(view(1).need == 3 and view(1).count == 2 and view(3) == false, "v2: ignored, the fallback again")
-- a foreign resource cannot write another provider's queue
status("chase.wanted", "op77_arena", base({ queue = { v = 1, lobbies = { { players = { 7 }, need = 3 } } } }))
assert(view(7) == false, "op77_arena cannot list players in a chase lobby")

-- ---------------------------------------------------------------------------
-- Leaving: a provider join (the core's way: the provider hears leaveRequest)
m, p0 = mark(), #pushes
assert(Q.leave(1))
local left = after(m, LEAVE)
assert(#left == 1 and left[1].args[1] == 1 and left[1].args[2] == "chase.wanted")
assert(A.pending[1] == nil and view(1) == false and pushed(p0, 1) >= 1, "the panel goes at once")
assert(not Q.leave(1), "nothing left to leave")

-- a provider queue joined by the provider's own command (no core join): asked directly
status("chase.1v1", "op77_chase", base({ queued = 1, queue = { v = 1, lobbies = { { players = { 4 }, need = 2 } } } }))
v = view(4)
assert(v.id == "chase.1v1" and v.count == 1 and v.need == 2 and v.max == nil and v.label == "NCPD Chase")
m, p0 = mark(), #pushes
actions["queue.leave"](4, { type = "queue.leave", from = "key" })
left = after(m, LEAVE)
assert(#left == 1 and left[1].args[1] == 4 and left[1].args[2] == "chase.1v1", "the provider is asked")
assert(results[#results].ok and results[#results].kind == "queue.leave" and results[#results].text:find("NCPD Chase"))
assert(view(4) == false and pushed(p0, 4) == 1, "and the panel goes before its next status")

-- ---------------------------------------------------------------------------
-- The core's ranked search: searchers / needed, then the match, then the entry
p0 = #pushes
assert(A.requestJoin(5, "arena.duel", "panel", {}))
v = view(5)
assert(v.source == "core" and v.id == "arena.duel" and v.count == 1 and v.need == 2 and v.state == "waiting")
assert(pushed(p0, 5) == 1)
t = t + 3000
m = mark()
assert(A.requestJoin(6, "arena.duel", "panel", {}))
local joins = after(m, JOIN)
assert(#joins == 2, "two searchers: a match at once")
v = view(5)
assert(v.state == "joining" and v.count == 2 and v.need == 2 and v.sinceMs == 3000, "match found: the wait goes on from the search")
assert(enter(5, "arena.duel", "op77_arena"))
assert(view(5) == false, "in play: no panel")
-- never a running activity: the leave key does nothing to it
m = mark()
local ok, why = Q.leave(5)
assert(not ok and why:find("not in a queue") and #after(m, LEAVE) == 0, "the key never leaves a match")
leave(5, "arena.duel", "op77_arena")
-- a held search left by the key: the ticket goes
assert(A.requestLeave(6))
assert(A.requestJoin(6, "arena.duel", "panel", {}))
assert(view(6).source == "core")
assert(Q.leave(6) and A.pending[6] == nil and view(6) == false)
local tickets = 0
for _ in pairs(A.tickets) do tickets = tickets + 1 end
assert(tickets == 0, "the search ended")

-- ---------------------------------------------------------------------------
-- A crew member queued by their leader: `crew`, and leaving takes only them out
crews[7] = { id = "crew-7", leader = 7, members = { 7, 8 } }
crews[8] = crews[7]
m = mark()
assert(A.requestJoin(7, "turf.war", "panel", {}))
assert(#after(m, JOIN) == 2, "the crew follows")
assert(view(8).crew == true and view(7).crew == nil)
m = mark()
assert(Q.leave(8))
assert(#after(m, LEAVE) == 1 and A.pending[7] ~= nil and A.pending[8] == nil, "a member leaves alone")
assert(Q.leave(7) and A.pending[7] == nil)
crews[7], crews[8] = nil, nil

-- ---------------------------------------------------------------------------
-- Mission boards: count / need-max, the launch countdown, untag
boards[9] = { key = "lobby:1", label = "Data Heist", mode = "Hard", count = 2, need = 2, max = 4 }
p0 = #pushes
Q.refresh(9)
v = view(9)
assert(v.id == "missions" and v.label == "Data Heist" and v.mode == "Hard" and v.count == 2 and v.need == 2 and v.max == 4 and v.source == "mission")
assert(pushed(p0, 9) == 1)
boards[9] = { key = "lobby:1", label = "Data Heist", mode = "Hard", count = 3, need = 2, max = 4, startsAt = t + 15000 }
Q.tick()
assert(view(9).state == "starting" and view(9).startsInMs == 15000 and pushed(p0, 9) == 2, "the tick sees the countdown")
assert(Q.leave(9) and untagged[#untagged] == 9 and view(9) == false)
-- an activity queue comes first; the board shows again once it is left
boards[9] = { key = "lobby:2", label = "Data Heist", mode = "Hard", count = 1, need = 2, max = 4 }
assert(A.requestJoin(9, "chase.1v1", "panel", {}))
assert(view(9).id == "chase.1v1")
assert(Q.leave(9) and view(9).id == "missions" and boards[9] ~= nil, "one leave, one queue")
boards[9] = nil
Q.tick()
assert(view(9) == false)

-- ---------------------------------------------------------------------------
-- Lifecycle: character change and disconnect clear; a provider that stops too
status("turf.war", "op77_turf", base({ queued = 2, queue = { v = 1, lobbies = { { players = { 2, 3 }, need = 4, max = 24 } } } }))
assert(view(2).id == "turf.war" and view(3).id == "turf.war")
m, p0 = mark(), #pushes
Q.onCharacterSwitched(2, "other")
left = after(m, LEAVE)
assert(#left == 1 and left[1].args[1] == 2 and left[1].args[2] == "turf.war", "the provider hears of the change")
assert(view(2) == false and pushed(p0, 2) == 1)
m, p0 = mark(), #pushes
Q.onDisconnected(3)
assert(#after(m, LEAVE) == 0 and pushed(p0, 3) == 0 and view(3) == false, "gone: no push, no event")
status("turf.war", "op77_turf", base({ queued = 1, queue = { v = 1, lobbies = { { players = { 1 }, need = 4 } } } }))
assert(view(1).id == "turf.war")
handlers.onResourceStop("op77_turf", "stopped")
assert(view(1) == false and Q.rosters["turf.war"] == nil, "the provider stopped: its queue went with it")

-- a core join cleared by the core (disconnect) leaves no panel behind
assert(A.requestJoin(4, "chase.1v1", "panel", {}))
p0 = #pushes
A.onDisconnected(4); Q.onDisconnected(4)
assert(view(4) == false)

-- ---------------------------------------------------------------------------
-- Limits and size: 32 lobbies, 64 per lobby, 256 in all, a player once; the panel stays tiny
local lobbies = {}
for l = 1, 40 do
    local list = {}
    for i = 1, 70 do list[i] = 1000 + (l - 1) * 70 + i end
    lobbies[l] = { players = list, need = 8, max = 8, mode = string.rep("x", 80) }
end
lobbies[1].players[1] = 2000 -- also listed in lobby 15
lobbies[2].players[2] = -3; lobbies[2].players[3] = 1.5; lobbies[2].players[4] = "nope"
local r = Q.parse({ v = 1, lobbies = lobbies }, t)
local listedCount = 0
for _ in pairs(r.of) do listedCount = listedCount + 1 end
assert(#r.lobbies <= 32 and #r.lobbies[1].players == 64 and listedCount == 256, "capped")
assert(#r.lobbies[1].mode == 32, "labels are cut")
for _, lobby in ipairs(r.lobbies) do assert(lobby.max == nil, "max == need: not shown twice") end
assert(Q.parse({ v = 1, lobbies = { { players = {} } } }, t).lobbies[1] == nil, "an empty lobby is no lobby")
assert(Q.parse("x", t) == nil and Q.parse({ v = 1 }, t) == nil)
invoking = "op77_chase"
A.status("chase.1v1", base({ queued = 2000, queue = { v = 1, lobbies = lobbies } }))
invoking = nil
v = view(1002)
assert(v and v.count == 64 and v.need == 8, "the player's own lobby")
assert(view(2000).count == 64 and Q.rosters["chase.1v1"].of[2000] == Q.rosters["chase.1v1"].lobbies[1], "listed twice: the first lobby")
local size = values(v)
assert(size <= 30, "the panel is " .. size .. " values whatever the roster")

print(string.format("PASS: provider fallback (minPlayers/maxPlayers, queued), status.queue v1 (lobby count/need/max, countdown, "
    .. "start slack, roster-only players, unknown version, foreign resource), no push per second, queue-only status skips the panels' push, "
    .. "leave (provider join, provider command, ranked search, match never, crew member alone, mission board, one at a time), "
    .. "ranked search -> match -> entry, mission countdown, character change / disconnect / provider stop, limits, panel %d values", size))
