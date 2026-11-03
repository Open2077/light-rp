-- The edges of the activity contract (server/modules/activities.lua) that the
-- main test leaves out: activityPlayer's gang and job, the panel's join choices
-- (joinChoices preset, modeKey, an unknown mode refused), a provider's own entry
-- withdrawing a request queued elsewhere, junk input on every export and event,
-- the notice export (shared/notice.lua: a provider's message in Light RP's notice),
-- the op77_lightrp:announce event (server/modules/staff.lua) in both shapes, and
-- hunger / thirst frozen while owned (server/modules/needs.lua). No game, no DB.
dofile("shared/config.lua")
dofile("server/config/activities.lua")
-- race.grid joins its provider's own queue here (the core's ranked queue: activities_lobby_test.lua)
LightRpActivities.lobby.activities["race.grid"] = nil
local noop = function() end
local t = 1000
local providers, actions, commands, handlers, exported = {}, {}, {}, {}, {}
local events, notices, logs = {}, {}, {}
LightRP = {
    db = { ready = false, schema = noop, run = noop, read = function() return false end, single = noop, query = function() return {} end },
    module = function(name, value) value.name = name; LightRP[name] = value; return value end,
    stateProvider = function(key, fn) providers[key] = fn end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    state = noop, result = noop, eachModule = noop, broadcastState = noop, dialog = noop,
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
local function character(id, identifier, key)
    chars[id] = { identifier = identifier or ("acct-" .. id), key = key or "default", status = "active", firstName = "Runner" .. id }
    return chars[id]
end

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
TriggerEvent = function(name, ...) events[#events + 1] = { name = name, args = table.pack(...) } end
exports = function(name, fn) exported[name] = fn end
local invoking
GetInvokingResource = function() return invoking end
GetCurrentResourceName = function() return "op77_lightrp" end
local resourceStates = { op77_arena = "running", op77_race = "running", op77_chase = "running" }
GetResourceState = function(name) return resourceStates[name] or "missing" end
GetPlayers = function() local list = {}; for id in pairs(chars) do list[#list + 1] = id end; table.sort(list); return list end
local buckets = {}
GetPlayerRoutingBucket = function(id) return buckets[id] or 0 end
SetPlayerRoutingBucket = function(id, b) buckets[id] = b end
local positions, life, damaged = {}, {}, {}
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
        damage = function(id, amount) damaged[#damaged + 1] = { id = id, amount = amount }; return true end,
    },
    vehicles = { getPlayerSeat = function() return nil end },
    time = { unix = function() return 1800000000 + math.floor(t / 1000) end },
}
LightRP.armament = { push = noop, synchronize = function() return true end }
local mission = {}
LightRP.missions = {
    handlesDeath = function(id) return mission[id] ~= nil end,
    handlesLoadout = function() return false end,
    instanceOf = function(id) return mission[id] and { point = "board_a" } or nil end,
    point = function() return { id = "board_a", position = { x = 50, y = 60, z = 7 } } end,
    untag = noop, addReputation = noop,
}
LightRP.medical = { isDowned = function() return false end }
LightRP.tutorial = { isActive = function() return false end }
LightRP.housing = { sessions = {} }

dofile("server/modules/activities.lua")
local A = LightRP.activities
loaded = true
local function lastEvent(name)
    for i = #events, 1, -1 do if events[i].name == name then return events[i] end end
end
local function count(name) local n = 0; for _, e in ipairs(events) do if e.name == name then n = n + 1 end end; return n end
local function place(id) positions[id] = { x = -756.5, y = 777.2, z = 22.4 }; buckets[id] = 0; life[id] = "alive" end

invoking = "op77_arena"
assert(exported.activityRegister({ id = "arena.ffa", resource = "op77_arena", label = "Arena FFA", kind = "pvp" }))
invoking = "op77_race"
assert(exported.activityRegister({ id = "race.trial", resource = "op77_race", label = "Time Trial", kind = "race" }))
run()

-- ---------------------------------------------------------------------------
-- activityPlayer: identity + gang and job from the jobs module, synchronous
local P = 1
character(P); place(P)
local gangOf, jobOf = {}, {}
LightRP.jobs = {
    gang = function(id) return gangOf[id] or { name = "none", label = "None", tag = "", grade = 0, gradeLabel = "" } end,
    get = function(id)
        if jobOf[id] == "boom" then error("jobs exploded") end
        return jobOf[id] or { name = "unemployed", label = "Unemployed", tag = "", grade = 0, gradeLabel = "Unemployed", salary = 0 }
    end,
}
local who = exported.activityPlayer(P)
assert(who.name == "Runner1" and who.identifier == "acct-1" and who.characterKey == "default")
assert(who.gang == nil, "no affiliation: gang is nil")
assert(who.job.id == "unemployed" and who.job.grade == 0 and who.job.onDuty == nil, "the job, as the jobs module reports it; no duty toggle")
gangOf[P] = { name = "valentinos", label = "Valentinos", tag = "VAL", color = "#d4a017", grade = 2, gradeLabel = "Soldado" }
jobOf[P] = { name = "police", label = "NCPD", tag = "NCPD", grade = 3, gradeLabel = "Sergeant", salary = 900 }
who = exported.activityPlayer(tostring(P))
assert(who.gang.id == "valentinos" and who.gang.label == "Valentinos" and who.gang.grade == 2 and who.gang.tag == "VAL")
assert(who.job.id == "police" and who.job.label == "NCPD" and who.job.grade == 3 and who.job.salary == nil, "no salary in the view")
jobOf[P] = "boom"
who = exported.activityPlayer(P)
assert(who and who.job == nil and who.gang.id == "valentinos", "a failing jobs module leaves the identity intact")
local saved = LightRP.jobs
LightRP.jobs = nil
who = exported.activityPlayer(P)
assert(who and who.gang == nil and who.job == nil, "without the jobs module: identity only")
LightRP.jobs = saved
jobOf[P] = nil
for _, bad in ipairs({ 0, -1, 1.5, "abc", {}, true }) do
    assert(exported.activityPlayer(bad) == nil, "an invalid id: nil")
end
assert(exported.activityPlayer(nil) == nil and exported.activityPlayer(42) == nil, "no character: nil")
chars[42] = { identifier = "acct-42", key = "default", status = "creating" }
assert(exported.activityPlayer(42) == nil, "a character still in the creator: nil")
chars[42] = nil

-- ---------------------------------------------------------------------------
-- Join choices: op77_chase's car / foot from the config, a provider's own modes
invoking = "op77_chase"
assert(exported.activityRegister({ id = "chase.1v1", resource = "op77_chase", label = "Chase 1v1", kind = "chase", minPlayers = 2, maxPlayers = 2 }))
local chase = A.registry["chase.1v1"]
assert(chase.modeKey == "mode" and #chase.modes == 2 and chase.modes[1].id == "vehicle" and chase.modes[2].id == "foot",
    "no modes declared: the joinChoices preset")
assert(exported.activityRegister({ id = "chase.1v1", resource = "op77_chase", label = "Chase 1v1", kind = "chase", minPlayers = 2, maxPlayers = 2,
    modes = { { id = "foot", label = "On foot" } } }))
assert(#A.registry["chase.1v1"].modes == 1, "declared modes win over the preset")
local ok, why = exported.activityRegister({ id = "chase.duo", resource = "op77_chase", label = "Duo", kind = "chase", modeKey = "squad" })
assert(not ok and why:find("modeKey"), "modeKey cannot shadow the core's own options")
ok, why = exported.activityRegister({ id = "chase.duo", resource = "op77_chase", label = "Duo", kind = "chase", modeKey = "bad key" })
assert(not ok and why:find("modeKey"))
assert(exported.activityRegister({ id = "chase.1v1", resource = "op77_chase", label = "Chase 1v1", kind = "chase", minPlayers = 2, maxPlayers = 2 }))
invoking = "op77_race"
assert(exported.activityRegister({ id = "race.grid", resource = "op77_race", label = "Grid", kind = "race", modeKey = "course",
    modes = { { id = "watson_loop", label = "Watson loop" }, { id = "badlands", label = "Badlands" } } }))
invoking = nil -- the panel and the commands run inside Light RP
ok, why = A.requestJoin(P, "chase.1v1", "panel", { mode = "boat" })
assert(not ok and why == "Choose mode: vehicle, foot.", "an unknown mode never reaches the provider")
assert(count("op77_lightrp:activity:join") == 0)
ok = commands.activity(P, { "join", "chase.1v1", "foot" })
assert(ok, "/activity join <id> <mode>")
local join = lastEvent("op77_lightrp:activity:join")
assert(join.args[2] == "chase.1v1" and join.args[3].mode == "foot" and join.args[3].from == "command")
ok, why = commands.activity(P, { "join", "race.grid", "nowhere" })
assert(not ok and why:find("Choose course: watson_loop, badlands"), why)
ok, why = A.requestJoin(P, "race.grid", "panel", { course = "badlands" })
assert(ok, why)
join = lastEvent("op77_lightrp:activity:join")
assert(join.args[3].course == "badlands" and join.args[3].mode == nil, "the choice lands in options[modeKey]")
assert(lastEvent("op77_lightrp:activity:leaveRequest").args[2] == "chase.1v1", "a new request withdraws the previous one")
ok, why = commands.activity(P, { "join", "race.grid", "watson_loop" })
assert(not ok and why:find("already queued for Grid"), why)
assert(providers.activities(P).queued.id == "race.grid")

-- ---------------------------------------------------------------------------
-- A provider enters a player queued elsewhere: that queue lets go
local leaves = count("op77_lightrp:activity:leaveRequest")
invoking = "op77_arena"
assert(exported.activityEnter(P, "arena.ffa"))
local withdrawn = lastEvent("op77_lightrp:activity:leaveRequest")
assert(count("op77_lightrp:activity:leaveRequest") == leaves + 1 and withdrawn.args[1] == P and withdrawn.args[2] == "race.grid",
    "the race is told the player went elsewhere")
assert(providers.activities(P).queued == false and providers.activities(P).current.id == "arena.ffa")
assert(exported.activityLeave(P, "arena.ffa", { returnPlayer = false }))
advance(3100)
-- entering the activity it queued for: nobody is told to let go
invoking = nil
assert(A.requestJoin(P, "arena.ffa", "panel"))
leaves = count("op77_lightrp:activity:leaveRequest")
invoking = "op77_arena"
assert(exported.activityEnter(P, "arena.ffa"))
assert(count("op77_lightrp:activity:leaveRequest") == leaves and providers.activities(P).queued == false)
assert(exported.activityLeave(P, "arena.ffa", { returnPlayer = false }))
advance(3100)
-- a provider releases a queued player itself (activityLeave on a request)
invoking = nil
assert(A.requestJoin(P, "arena.ffa", "panel"))
invoking = "op77_race"
ok, why = exported.activityLeave(P, "arena.ffa")
assert(not ok and why:find("another resource"), "only the activity's provider drops its queue")
invoking = "op77_arena"
assert(exported.activityLeave(P, "arena.ffa") and providers.activities(P).queued == false)

-- ---------------------------------------------------------------------------
-- Junk on every export and event: a reason, never an error thrown at the caller
local junk = { nil, false, 0, -3, 2.5, "x", "1e999", {}, function() end, math.huge, 0 / 0 }
for i = 1, 11 do
    local v = junk[i]
    ok, why = exported.activityRegister(v)
    assert(ok == false and type(why) == "string", "register(" .. tostring(v) .. ")")
    ok, why = exported.activityCheck(v, "arena.ffa")
    assert(ok == false and type(why) == "string", "check(" .. tostring(v) .. ")")
    ok, why = exported.activityCheck(P, v)
    if v == nil then assert(ok == true, "no activity id: the general eligibility")
    else assert(ok == false and type(why) == "string", "check(P, " .. tostring(v) .. ")") end
    ok, why = exported.activityEnter(v, "arena.ffa")
    assert(ok == false and type(why) == "string", "enter(" .. tostring(v) .. ")")
    ok, why = exported.activityEnter(P, v)
    assert(ok == false and type(why) == "string", "enter(P, " .. tostring(v) .. ")")
    ok, why = exported.activityLeave(v, "arena.ffa")
    assert(ok == false and type(why) == "string", "leave(" .. tostring(v) .. ")")
    ok, why = exported.activityLeave(P, v, v)
    assert(ok == false and type(why) == "string", "leave(P, " .. tostring(v) .. ")")
    assert(exported.activityOwner(v) == nil)
    handlers["op77_lightrp:activity:result"](v, "arena.ffa", v)
    handlers["op77_lightrp:activity:result"](P, v, { won = true })
    handlers["op77_lightrp:activity:status"](v, v)
    handlers["op77_lightrp:activity:status"]("arena.ffa", v)
end
ok, why = exported.activityRegister({ id = "arena.big", resource = "op77_arena", label = "Big", kind = "pvp", minPlayers = 8, maxPlayers = 2 })
assert(not ok and why:find("minPlayers"))
ok, why = exported.activityRegister({ id = "arena.big", resource = "op77_arena", label = "Big", kind = "pvp", caps = "all" })
assert(not ok and why:find("caps"))
ok, why = exported.activityRegister({ id = "arena.big", resource = "op77_arena", label = "   ", kind = "pvp" })
assert(not ok and why:find("label"))
ok, why = exported.activityRegister({ id = "arena." .. string.rep("x", 60), resource = "op77_arena", label = "Long", kind = "pvp" })
assert(not ok and why:find("namespaced"))
-- the leave options: anything but a table means "bring them back"
assert(exported.activityEnter(P, "arena.ffa"))
assert(exported.activityLeave(P, "arena.ffa", "nope"))
run(); advance(3100)
assert(not A.owns(P) and buckets[P] == 0)
-- a status for another resource's activity is ignored
invoking = "op77_race"
handlers["op77_lightrp:activity:status"]("arena.ffa", { phase = "running", players = 5 })
assert(A.registry["arena.ffa"].status.players ~= 5, "a status is posted by the activity's own resource")
-- unknown phase falls back to idle; a non-table result is refused
invoking = "op77_arena"
handlers["op77_lightrp:activity:status"]("arena.ffa", { phase = "exploding", players = "3" })
assert(A.registry["arena.ffa"].status.phase == "idle" and A.registry["arena.ffa"].status.players == 3)
assert(not A.result(P, "arena.ffa", "won"), "a result is a table")
character(9); place(9)
assert(not A.result(9, "arena.ffa", { won = true }), "no result for a player who never entered")
chars[9] = nil
-- the panel's action with junk payloads
for _, payload in ipairs({ {}, { operation = 7 }, { operation = "join" }, { operation = "join", id = {} }, { operation = "gps", id = 5 },
        { operation = "join", id = "arena.ffa", options = "x" }, { operation = "open", tab = "<script>" } }) do
    payload.type = "activities.control"
    actions["activities.control"](P, payload)
end
assert(commands.activity(P, { "dance" }) == false and commands.activity(0, {}) == false)
assert(commands.leave(0, {}) == false)
local before = #logs
handlers["op77_lightrp:activity:result"](P, "arena.ffa", setmetatable({}, { __index = function() error("hostile table") end }))
assert(#logs > before and logs[#logs]:find("result"), "a hostile table is logged, not thrown")

-- ---------------------------------------------------------------------------
-- notice (shared/notice.lua): a provider's message in Light RP's own notice, cleaned
dofile("shared/notice.lua")
notices = {}
invoking = "op77_turf"
assert(exported.notice(P, { kind = "info", title = "Turf War", body = "Turf War starts in 45 s.", durationMs = 6000 }) == true)
local n = notices[#notices]
assert(n.id == P and n.def.kind == "info" and n.def.title == "Turf War" and n.def.body == "Turf War starts in 45 s."
    and n.def.durationMs == 6000, "kind, title, body and duration kept")
assert(exported.notice(P, { kind = "danger", message = "  GO.\nLose them.  ", durationMs = 999999 }) == true)
n = notices[#notices].def
assert(n.kind == "warning" and n.body == "GO. Lose them." and n.durationMs == 20000 and n.title == nil,
    "danger reads as warning, message accepted, control characters spaced, 20 s at most")
assert(exported.notice(P, { kind = "<script>", text = string.rep("é", 200), title = string.rep("T", 90), durationMs = 0 / 0 }) == true)
n = notices[#notices].def
assert(n.kind == "info" and #n.body <= 280 and #n.body % 2 == 0 and #n.title == 48 and n.durationMs == 6000,
    "unknown kind -> info, body 280 bytes on a character boundary, title 48, NaN -> 6 s")
assert(exported.notice(P, { body = "short", durationMs = 10 }) and notices[#notices].def.durationMs == 2000, "2 s at least")
local count = #notices
local ok, why = exported.notice(-1, { body = "everyone?" })
assert(ok == false and why == "Invalid player.", "never -1 (everyone)")
assert(exported.notice(0, { body = "x" }) == false and exported.notice("abc", { body = "x" }) == false and exported.notice(1.5, { body = "x" }) == false)
ok, why = exported.notice(P, { title = "Only a title" })
assert(ok == false and why == "empty_notice", "a notice without text is refused")
assert(exported.notice(P, "text") == false and exported.notice(P, nil) == false, "a non-table is refused")
assert(exported.notice(P, setmetatable({}, { __index = function() error("hostile table") end })) == false, "a hostile table never throws")
assert(#notices == count, "nothing sent for a refused notice")
invoking = nil

-- ---------------------------------------------------------------------------
-- op77_lightrp:announce (staff.lua): the text and table shapes, cleaned, clamped, rate-limited
local broadcasts, staffNotices = {}, {}
LightRP.chat = { broadcast = function(title, text, color) broadcasts[#broadcasts + 1] = { title = title, text = text, color = color } end }
LightRP.broadcastNotice = function(def) staffNotices[#staffNotices + 1] = def end
LightRP.needs = { refill = noop }
GetPlayerName = function() return nil end
TriggerClientEvent = noop
dofile("server/modules/staff.lua")
local announce = handlers["op77_lightrp:announce"]
assert(announce, "the announce event is handled")
announce("Opening night at The Crossing.", { title = "Fireworks", durationMs = 10000 })
assert(broadcasts[1].title == "FIREWORKS" and broadcasts[1].text == "Opening night at The Crossing.")
assert(staffNotices[1].title == "Fireworks" and staffNotices[1].durationMs == 10000 and staffNotices[1].kind == "staff")
announce("Second one too soon.")
assert(#broadcasts == 1, "one per second")
t = t + 1000
announce({ body = "  The show\nstarts\tnow  ", title = string.rep("T", 60), durationMs = 999999, kind = "event" })
assert(broadcasts[2].text == "The show starts now", "control characters become spaces, trimmed")
assert(#staffNotices[2].title == 40 and staffNotices[2].durationMs == 30000, "title 40, duration at most 30 s")
t = t + 1000
announce("x")
announce(nil)
announce(42)
announce({ title = "No body" })
assert(#broadcasts == 2, "too short, missing or not a string: dropped")
announce(string.rep("é", 150), { durationMs = 10 })
assert(#broadcasts[3].text <= 200 and broadcasts[3].text:match("^[\128-\255]*$") and #broadcasts[3].text % 2 == 0,
    "cut at 200 bytes on a character boundary")
assert(staffNotices[3].durationMs == 3000 and staffNotices[3].title == "Staff announcement" and broadcasts[3].title == "STAFF",
    "at least 3 s; no title: the staff announcement")
t = t + 1000
announce("Bad duration.", { durationMs = 0 / 0 })
assert(staffNotices[4].durationMs == 12000, "NaN: the default 12 s")

-- ---------------------------------------------------------------------------
-- Hunger and thirst (needs.lua): frozen while a mission or an activity owns the player
loaded = true
threads = {}
dofile("server/modules/needs.lua")
local needsLoop = table.remove(threads, 1)
local starveLoop = table.remove(threads, 1)
assert(needsLoop and starveLoop and #threads == 0, "needs.lua starts its tick and starve threads")
-- run exactly one tick: Wait raises once the first tick is done
local ticks = 0
Wait = function() ticks = ticks + 1; if ticks > 1 then error("stop") end end
local function tick() ticks = 0; pcall(needsLoop); ticks = 0; pcall(starveLoop) end
local Q, R, S = 2, 3, 4
for _, id in ipairs({ Q, R, S }) do character(id); place(id) end
chars[P].food, chars[P].drink = 80, 80
for _, id in ipairs({ Q, R, S }) do chars[id].food, chars[id].drink = 80, 80 end
assert(exported.activityEnter(Q, "arena.ffa"))                       -- needs frozen (caps.needs false)
invoking = "op77_race"
assert(exported.activityRegister({ id = "race.marathon", resource = "op77_race", label = "Marathon", kind = "race", caps = { needs = true } }))
assert(exported.activityEnter(R, "race.marathon"))                   -- this one keeps them
invoking = "op77_arena"
mission[S] = "plain"                                                 -- a mission operator
tick()
local per = LightRpConfig.needs.foodPerTick
assert(chars[P].food == 80 - per, "a free player gets hungry")
assert(chars[Q].food == 80 and chars[Q].drink == 80, "frozen in an activity")
assert(chars[R].food == 80 - per, "unless the activity's caps keep needs")
assert(chars[S].food == 80 and chars[S].drink == 80, "frozen on a mission")
-- starving players take damage only outside
chars[P].food, chars[Q].food = 0, 0
damaged = {}
tick()
assert(#damaged == 1 and damaged[1].id == P, "no starvation damage while owned")
mission[S] = nil
assert(exported.activityLeave(Q, "arena.ffa", { returnPlayer = false }))
advance(3100)
tick()
assert(chars[Q].drink == 80 - LightRpConfig.needs.drinkPerTick, "the clock runs again once released")

print("PASS: activityPlayer gang/job, join choices and modeKey, queue withdrawal on entry, junk input, the notice export (cleaned, capped, never everyone), announce event (both shapes), needs frozen while owned")
