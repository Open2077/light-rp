-- The activity providers' contract (server/modules/activities.lua): registry,
-- eligibility order, ownership and return capture, caps, leave / dropped,
-- provider stop and reload, results (clamps, daily cap, stats, leaderboards),
-- the missions internal provider. No game, no database.
dofile("shared/config.lua")
dofile("server/config/activities.lua")
local noop = function() end
local t = 1000
local providers, actions, commands, handlers, exported = {}, {}, {}, {}, {}
local events, notices, dialogs, pushed = {}, {}, {}, {}
LightRP = {
    db = { ready = false, schema = noop, run = noop, read = function() return false end, single = noop, query = function() return {} end },
    module = function(name, value) value.name = name; LightRP[name] = value; return value end,
    stateProvider = function(key, fn) providers[key] = fn end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    state = function(id, key) pushed[#pushed + 1] = { id = id, key = key } end,
    notice = function(id, def) notices[#notices + 1] = { id = id, def = def } end,
    result = noop, log = noop, eachModule = noop, broadcastState = noop,
    dialog = function(id, kind, payload) dialogs[#dialogs + 1] = { id = id, kind = kind, payload = payload } end,
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

-- host
local threads, timers, loaded = {}, {}, false
CreateThread = function(fn) if loaded then threads[#threads + 1] = fn end end
SetTimeout = function(ms, fn) timers[#timers + 1] = { at = t + ms, fn = fn } end
Wait = noop
local function run()
    while #threads > 0 do table.remove(threads, 1)() end
end
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
local resourceStates = { op77_arena = "running", op77_race = "running" }
GetResourceState = function(name) return resourceStates[name] or "missing" end
GetPlayers = function() local list = {}; for id in pairs(chars) do list[#list + 1] = id end; return list end
local buckets = {}
GetPlayerRoutingBucket = function(id) return buckets[id] or 0 end
SetPlayerRoutingBucket = function(id, b) buckets[id] = b end
local positions, life, seats, heals, teleports, respawns, syncs, pushes = {}, {}, {}, {}, {}, {}, {}, {}
Open77 = {
    players = {
        position = function(id) local p = positions[id]; return p and { x = p.x, y = p.y, z = p.z, bucket = buckets[id] or 0 } end,
        get = function(id) local p = positions[id]; if not p then return nil, "unknown" end
            return { position = { x = p.x, y = p.y, z = p.z }, heading = p.heading or 0, bucket = buckets[id] or 0 } end,
        getLifeState = function(id) return { phase = life[id] or "alive" } end,
        teleport = function(id, pos, opts)
            teleports[#teleports + 1] = { id = id, pos = pos, opts = opts }
            return { await = function() buckets[id] = opts.bucket; positions[id] = { x = pos.x, y = pos.y, z = pos.z }; return true end }
        end,
        respawn = function(id, opts) respawns[#respawns + 1] = { id = id, opts = opts }; life[id] = "alive"; buckets[id] = opts.bucket; return true end,
        heal = function(id, amount) heals[#heals + 1] = { id = id, amount = amount }; return true end,
    },
    vehicles = { getPlayerSeat = function(id) return seats[id] end },
    time = { unix = function() return 1800000000 + math.floor(t / 1000) end },
}
LightRP.armament = { push = function(id) pushes[#pushes + 1] = id end, synchronize = function(id) syncs[#syncs + 1] = id; return true end }
local untagged = {}
local mission = {}
local missionPoint = { id = "board_a", title = "Board A", position = { x = 50, y = 60, z = 7 } }
local repGranted = {}
LightRP.missions = {
    handlesDeath = function(id) return mission[id] ~= nil end,
    handlesLoadout = function(id) return mission[id] == "kit" end,
    instanceOf = function(id) return mission[id] and { point = "board_a" } or nil end,
    point = function(id) return id == "board_a" and missionPoint or nil end,
    untag = function(id, why) untagged[#untagged + 1] = { id = id, why = why } end,
    addReputation = function(id, amount) repGranted[#repGranted + 1] = { id = id, amount = amount } end,
}
local downed, tutorial = {}, {}
LightRP.medical = { isDowned = function(id) return downed[id] == true end }
LightRP.tutorial = { isActive = function(id) return tutorial[id] == true end }
LightRP.housing = { sessions = {} }

dofile("server/modules/activities.lua")
local A = LightRP.activities
loaded = true
local function lastEvent(name)
    for i = #events, 1, -1 do if events[i].name == name then return events[i] end end
end
local function count(name) local n = 0; for _, e in ipairs(events) do if e.name == name then n = n + 1 end end; return n end

-- ---------------------------------------------------------------------------
-- Registry
local ok, why = exported.activityRegister({ id = "ffa", resource = "op77_arena", label = "FFA", kind = "pvp" })
assert(not ok and why:find("namespaced"), "an id is namespaced")
ok, why = exported.activityRegister({ id = "arena.ffa", resource = "op77_arena", label = "FFA", kind = "brawl" })
assert(not ok and why:find("kind"), "the kind is one of four")
invoking = "op77_race"
ok, why = exported.activityRegister({ id = "arena.ffa", resource = "op77_arena", label = "FFA", kind = "pvp" })
assert(not ok and why:find("calling resource"), "a resource registers its own activities only")
invoking = "op77_arena"
assert(exported.activityRegister({ id = "arena.ffa", resource = "op77_arena", label = "Arena FFA", kind = "pvp",
    description = "Free for all.", minPlayers = 2, maxPlayers = 12, caps = { rpWeapons = false, needs = "yes" } }))
assert(A.registry["arena.ffa"].caps.needs == false and A.registry["arena.ffa"].caps.vehicles == false, "caps are false unless true")
invoking = "op77_race"
assert(exported.activityRegister({ id = "race.trial", resource = "op77_race", label = "Time Trial", kind = "race", caps = { vehicles = true } }))
ok, why = exported.activityRegister({ id = "arena.ffa", resource = "op77_race", label = "Stolen", kind = "pvp" })
assert(not ok and why:find("belongs to op77_arena"), "a running provider keeps its ids")
invoking = "op77_arena"
assert(exported.activityRegister({ id = "arena.ffa", resource = "op77_arena", label = "Arena FFA", kind = "pvp", minPlayers = 2, maxPlayers = 12,
    modes = { { id = "foot", label = "On foot" }, { id = "bad id!" }, "nope" } }), "re-registering replaces")
assert(#A.registry["arena.ffa"].modes == 1 and A.registry["arena.ffa"].modes[1].id == "foot", "optional join modes, validated")
assert(A.ownsBucket(4100001) and A.ownsBucket(4399999) and not A.ownsBucket(0) and not A.ownsBucket(3000001) and not A.ownsBucket(nil))
run()

-- ---------------------------------------------------------------------------
-- Eligibility, in the contract's order
local P = 1
positions[P] = { x = -756.5, y = 777.2, z = 22.4, heading = 52 }
ok, why = exported.activityCheck(P, "arena.ffa")
assert(not ok and why:find("active character"), "1. an active character")
local c1 = character(P)
life[P] = "dead"
ok, why = exported.activityCheck(P, "arena.ffa"); assert(not ok and why:find("alive"), "2. alive")
life[P] = "alive"; downed[P] = true
ok, why = exported.activityCheck(P, "arena.ffa"); assert(not ok and why:find("down"), "2. not downed")
downed[P] = nil; mission[P] = "plain"
ok, why = exported.activityCheck(P, "arena.ffa"); assert(not ok and why:find("mission"), "3. not on a mission")
mission[P] = nil; tutorial[P] = true
ok, why = exported.activityCheck(P, "arena.ffa"); assert(not ok and why:find("first day"), "4. not in the first day guide")
tutorial[P] = nil; LightRP.housing.sessions[P] = {}
ok, why = exported.activityCheck(P, "arena.ffa"); assert(not ok and why:find("dwelling"), "5. not in a dwelling")
LightRP.housing.sessions[P] = nil; seats[P] = { seat = 0 }
ok, why = exported.activityCheck(P, "arena.ffa"); assert(not ok and why:find("vehicle"), "6. not in a vehicle")
seats[P] = nil
handlers["open77:playerDamaged"](tostring(P), "2", 12, "ranged", "Items.Preset_Pistol")
ok, why = exported.activityCheck(P, "arena.ffa"); assert(not ok and why:find("hurt"), "7. not damaged in the last 60 s")
advance(61000)
handlers["open77:playerDamaged"](P, nil, 3, "script", "lightrp:needs")
assert(exported.activityCheck(P, "arena.ffa"), "hunger is not combat damage")
buckets[P] = 710001
ok, why = exported.activityCheck(P, "arena.ffa"); assert(not ok and why:find("shared city"), "the return point is in the shared city")
buckets[P] = 0
ok, why = exported.activityCheck(P, "arena.nope"); assert(not ok and why:find("not available"), "an unknown activity")

-- ---------------------------------------------------------------------------
-- Enter: ownership, return point, weapons aside, caps
invoking = "op77_race"
ok, why = exported.activityEnter(P, "arena.ffa")
assert(not ok and why:find("another resource"), "a provider enters its own activities only")
invoking = "op77_arena"
assert(exported.activityEnter(P, "arena.ffa"))
assert(exported.activityEnter(P, "arena.ffa"), "entering twice is harmless")
local e = A.current(P)
assert(e.returnPoint.x == -756.5 and e.returnPoint.y == 777.2 and e.returnPoint.z == 22.4 and e.returnPoint.heading == 52 and e.returnPoint.bucket == 0)
assert(c1.lastKnown.x == -756.5 and c1.lastKnown.z == 22.4, "the saved position is the return point from the entry on")
assert(untagged[1] and untagged[1].id == P, "a mission board tag is dropped")
assert(pushes[1] == P, "the armament learns it stands aside")
assert(exported.activityOwner(P) == "arena.ffa" and A.owns(P))
assert(not A.allows(P, "rpWeapons") and not A.allows(P, "rpItems") and not A.allows(P, "needs") and not A.allows(P, "vehicles"))
assert(A.allows(99, "rpItems") and A.allows(99, "needs"), "a free player is allowed everything")
local who = exported.activityPlayer(P)
assert(who.identifier == "acct-1" and who.characterKey == "default" and who.name == "Runner1")
ok, why = exported.activityCheck(P, "race.trial"); assert(not ok and why:find("Arena FFA"), "3. not in another activity")
invoking = "op77_race"
ok, why = exported.activityEnter(P, "race.trial"); assert(not ok and why:find("Arena FFA"), "one activity at a time")
invoking = "op77_arena"
-- in the instance: the position the character samples stays the return point
buckets[P] = 4100001; positions[P] = { x = 9000, y = 9000, z = 90 }
local saved = A.savedPosition(P, { x = 9000, y = 9000, z = 90 })
assert(saved.x == -756.5, "never the instance's coordinates")
assert(A.savedPosition(99, "fallback") == "fallback")
-- damage taken inside does not count afterwards
handlers["open77:playerDamaged"](P, 2, 50, "ranged", "Items.Preset_Pistol")

-- ---------------------------------------------------------------------------
-- Leave: back to the captured point, healed, RP weapons back
assert(exported.activityLeave(P, "arena.ffa"))
assert(exported.activityOwner(P) == nil, "released at once")
assert(A.owns(P), "still Light RP's while the way back runs (deaths, saves)")
run()
local back = teleports[#teleports]
assert(back.id == P and back.pos.x == -756.5 and back.opts.bucket == 0 and back.opts.heading == 52 and back.opts.fade and back.opts.dismount)
assert(buckets[P] == 0 and heals[#heals].id == P, "returned and healed")
assert(not A.owns(P), "the way back is over")
advance(3100)
assert(syncs[#syncs] == P, "the RP weapons are projected again")
assert(exported.activityCheck(P, "arena.ffa"), "the activity's damage does not block the next one")

-- dead at the end: respawned at the return point
assert(exported.activityEnter(P, "arena.ffa"))
buckets[P] = 4100002; life[P] = "dead"
assert(exported.activityLeave(P, "arena.ffa", {}))
run()
assert(respawns[#respawns].opts.position.x == -756.5 and respawns[#respawns].opts.bucket == 0, "a dead player respawns at the return point")
advance(3100)

-- returnPlayer = false: the provider keeps the player where they are
assert(exported.activityEnter(P, "arena.ffa"))
local before = #teleports
assert(exported.activityLeave(P, "arena.ffa", { returnPlayer = false }))
run()
assert(#teleports == before and not A.owns(P))
advance(3100)

-- ---------------------------------------------------------------------------
-- Requests: join (with the squad), leave, the provider that never answers
LightRP.parties = { of = function(id) if id == P then return { id = "squad:1", leader = P, members = { P, 2 } } end end }
ok, why = A.requestJoin(P, "arena.ffa", "panel", { mode = "foot", from = "spoofed", squad = "x", nested = {} })
assert(ok and why:find("Request sent"))
local join = lastEvent("op77_lightrp:activity:join")
assert(join.args[1] == P and join.args[2] == "arena.ffa" and join.args[3].from == "panel" and join.args[3].squad.members[2] == 2)
assert(join.args[3].mode == "foot" and join.args[3].nested == nil, "the page's options pass through, flat")
ok, why = A.requestJoin(P, "arena.ffa"); assert(not ok and why:find("already queued"))
ok, why = A.requestLeave(P); assert(ok and why:find("queue"))
assert(lastEvent("op77_lightrp:activity:leaveRequest").args[2] == "arena.ffa", "a queued player leaves through the provider too")
handlers["op77_lightrp:activity:status"]("arena.ffa", { phase = "running", players = 99999, queued = -4, joinable = false, detail = string.rep("x", 400) })
local st = A.registry["arena.ffa"].status
assert(st.phase == "running" and st.players == 10000 and st.queued == 0 and not st.joinable and #st.detail == 120, "a status is clamped")
ok, why = A.requestJoin(P, "arena.ffa"); assert(not ok and why:find("not taking players"))
handlers["op77_lightrp:activity:status"]("arena.ffa", { phase = "lobby", players = 3, queued = 1, joinable = true })
assert(exported.activityEnter(P, "arena.ffa"))
ok = A.requestLeave(P)
assert(ok and lastEvent("op77_lightrp:activity:leaveRequest").args[1] == P)
assert(A.current(P), "the provider is asked first")
advance(LightRpActivities.leaveTimeoutMs + 10)
local dropped = lastEvent("op77_lightrp:activity:dropped")
assert(dropped and dropped.args[1] == P and dropped.args[3] == "timeout" and not A.current(P), "no answer: the core returns the player")
advance(3100)

-- ---------------------------------------------------------------------------
-- Disconnect and character switch: dropped, ownership already released
assert(exported.activityEnter(P, "arena.ffa"))
A.onDisconnected(P)
dropped = lastEvent("op77_lightrp:activity:dropped")
assert(dropped.args[3] == "disconnect" and exported.activityOwner(P) == nil)
A.onConnected(P)
c1 = character(P)
positions[P] = { x = -756.5, y = 777.2, z = 22.4, heading = 52 }; buckets[P] = 0; life[P] = "alive"
assert(exported.activityEnter(P, "arena.ffa"))
local other = { identifier = "acct-1", key = "slot2", status = "active" }
A.onCharacterSwitched(P, other)
assert(lastEvent("op77_lightrp:activity:dropped").args[3] == "character" and not A.current(P))
chars[P] = c1
advance(3100)

-- ---------------------------------------------------------------------------
-- Results: clamped, capped per account and day, stats and leaderboard
LightRP.missions.addReputation = function(id, amount) repGranted[#repGranted + 1] = { id = id, amount = amount } end
assert(exported.activityEnter(P, "arena.ffa"))
handlers["op77_lightrp:activity:result"](P, "arena.ffa", { placement = 1, won = true, score = 31, reputation = 1e9,
    stats = { kills = 9, deaths = 2, timeMs = 0 } })
run()
local max = LightRpActivities.reputation.maxPerResult
assert(repGranted[#repGranted].amount == max, "reputation is clamped per result")
assert(notices[#notices].def.body:find("+" .. max .. " reputation", 1, true))
local view = providers.activities(P)
local ffa
for _, a in ipairs(view.list) do if a.id == "arena.ffa" then ffa = a end end
assert(ffa.mine.played == 1 and ffa.mine.wins == 1 and ffa.mine.kills == 9 and ffa.mine.bestScore == 31)
assert(ffa.top[1] and ffa.top[1].name == "Runner1" and ffa.top[1].wins == 1, "the leaderboard follows")
assert(view.reputation.today == max and view.current and view.current.id == "arena.ffa")
assert(handlers["op77_lightrp:activity:result"] and not A.result(P, "arena.ffa", { won = true }), "one result per 15 s per entry")
invoking = "op77_race"
assert(not A.result(P, "arena.ffa", { won = true }), "another resource cannot post for this activity")
invoking = "op77_arena"
-- the daily cap holds across the account's characters
local cap = LightRpActivities.reputation.dailyCap
local granted = max
while granted < cap do
    advance(16000)
    assert(A.result(P, "arena.ffa", { placement = 2, reputation = max }))
    run()
    granted = granted + math.min(max, cap - granted)
end
assert(exported.activityLeave(P, "arena.ffa", { returnPlayer = false }))
advance(3100)
local Q = 2
character(Q, "acct-1", "slot2"); positions[Q] = { x = 1, y = 2, z = 3 }
assert(exported.activityEnter(Q, "arena.ffa"))
local grants = #repGranted
assert(A.result(Q, "arena.ffa", { placement = 1, won = true, reputation = 10 }))
run()
assert(#repGranted == grants and notices[#notices].def.body:find("cap reached"), "the cap is per account, every character")
-- a result after the leave is taken once
assert(exported.activityLeave(Q, "arena.ffa", { returnPlayer = false }))
advance(16000)
invoking = "op77_race"
assert(exported.activityRegister({ id = "race.trial", resource = "op77_race", label = "Time Trial", kind = "race" }))
invoking = "op77_race"
character(3); positions[3] = { x = 5, y = 5, z = 5 }
assert(exported.activityEnter(3, "race.trial"))
assert(exported.activityLeave(3, "race.trial", { returnPlayer = false }))
assert(A.result(3, "race.trial", { placement = 1, won = true, stats = { timeMs = 61234 } }), "a result just after the leave")
advance(16000)
assert(not A.result(3, "race.trial", { placement = 1, stats = { timeMs = 50000 } }), "once")
run()
view = providers.activities(3)
local trial
for _, a in ipairs(view.list) do if a.id == "race.trial" then trial = a end end
assert(trial.byTime and trial.top[1].bestTimeMs == 61234, "races rank by best time")
invoking = "op77_arena"

-- ---------------------------------------------------------------------------
-- Missions: Light RP's internal provider
mission[P] = "kit"
assert(A.owns(P) and A.owner(P) == "missions" and exported.activityOwner(P) == "missions")
assert(not A.allows(P, "rpWeapons") and A.allows(P, "rpItems") and not A.allows(P, "needs") and A.allows(P, "vehicles"))
saved = A.savedPosition(P, { x = 7777, y = 7777, z = 7 })
assert(saved.x == 50 and saved.y == 60, "a mission operator is saved at the mission point")
ok, why = A.requestLeave(P); assert(not ok and why:find("/mission leave"))
mission[P] = "plain"
assert(A.allows(P, "rpWeapons"), "a mission without its own kit keeps the RP weapons")
mission[P] = nil

-- ---------------------------------------------------------------------------
-- A provider stops: forgotten, players brought back; a reload keeps what the new VM registered
positions[P] = { x = -756.5, y = 777.2, z = 22.4, heading = 52 }; buckets[P] = 0
assert(exported.activityEnter(P, "arena.ffa"))
handlers.onResourceStarting("op77_arena")
assert(exported.activityRegister({ id = "arena.ffa", resource = "op77_arena", label = "Arena FFA", kind = "pvp" }))
assert(exported.activityRegister({ id = "arena.duel", resource = "op77_arena", label = "Duel", kind = "pvp" }))
handlers.onResourceStop("op77_arena", "reload")
assert(A.registry["arena.ffa"] and A.registry["arena.duel"], "the incoming VM's registrations stay")
dropped = lastEvent("op77_lightrp:activity:dropped")
assert(dropped.args[1] == P and dropped.args[3] == "provider_stopped" and not A.current(P), "the outgoing VM's players are released")
run(); advance(3100)
assert(exported.activityEnter(P, "arena.duel"))
resourceStates.op77_arena = "stopped"
handlers.onResourceStop("op77_arena", "manual")
assert(A.registry["arena.ffa"] == nil and A.registry["arena.duel"] == nil, "a stopped provider is forgotten")
assert(lastEvent("op77_lightrp:activity:dropped").args[3] == "provider_stopped" and not A.current(P))
run()
assert(teleports[#teleports].id == P and teleports[#teleports].opts.bucket == 0, "and its players come back")
advance(3100)
ok, why = exported.activityEnter(P, "arena.ffa"); assert(not ok and why:find("not available"))

-- ---------------------------------------------------------------------------
-- The page: open, join, leave; commands
actions["activities.control"](P, { type = "activities.control", operation = "open", tab = "contracts" })
assert(dialogs[#dialogs].kind == "activities" and dialogs[#dialogs].payload.tab == "contracts")
view = providers.activities(P)
assert(view.eligible and view.reason == nil and view.current == false and #view.list == 1)
local okCmd, text = commands.leave(P, {})
assert(not okCmd and text:find("not in an activity"))
okCmd, text = commands["lightrp.activities"](0, {})
assert(okCmd and text:find("race.trial") and text:find("missions"))
print("PASS: activity registry, eligibility order, ownership and return, caps, leave/dropped/timeout, provider stop and reload, clamped and capped results, stats and leaderboards, missions provider")
