-- PvE progression in the activities core (server/modules/activities.lua,
-- docs/pve-progression.md): which activities are PvE, the difficulty gate on join
-- and enter, PvE reputation by difficulty and weight (lowered to the player's tier),
-- PvP results without reputation, the legacy switch, the onActivityChanged hook.
-- No game, no database.
dofile("shared/config.lua")
dofile("server/config/activities.lua")
local noop = function() end
local t = 1000
local providers, actions, commands, handlers, exported = {}, {}, {}, {}, {}
local events, notices, hooks = {}, {}, {}
LightRP = {
    db = { ready = false, schema = noop, run = noop, read = function() return false end, single = noop, query = function() return {} end },
    module = function(name, value) value.name = name; LightRP[name] = value; return value end,
    stateProvider = function(key, fn) providers[key] = fn end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    state = noop, result = noop, log = noop, broadcastState = noop, dialog = noop,
    notice = function(id, def) notices[#notices + 1] = { id = id, def = def } end,
    eachModule = function(hook, ...) hooks[#hooks + 1] = { hook = hook, args = table.pack(...) } end,
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
local function character(id, identifier)
    chars[id] = { identifier = identifier or ("acct-" .. id), key = "default", status = "active", firstName = "Runner" .. id }
    return chars[id]
end

local threads, timers, loaded = {}, {}, false
CreateThread = function(fn) if loaded then threads[#threads + 1] = fn end end
SetTimeout = function(ms, fn) timers[#timers + 1] = { at = t + ms, fn = fn } end
Wait = noop
local function run() while #threads > 0 do table.remove(threads, 1)() end end
local function advance(ms)
    t = t + ms
    for i = #timers, 1, -1 do if timers[i].at <= t then table.remove(timers, i).fn() end end
    run()
end
AddEventHandler = function(name, fn) handlers[name] = fn end
TriggerEvent = function(name, ...) events[#events + 1] = { name = name, args = table.pack(...) } end
exports = function(name, fn) exported[name] = fn end
local invoking = "op77_arena"
GetInvokingResource = function() return invoking end
GetCurrentResourceName = function() return "op77_lightrp" end
local resourceStates = { op77_arena = "running", op77_race = "running", op77_turf = "running" }
GetResourceState = function(name) return resourceStates[name] or "missing" end
GetPlayers = function() local list = {}; for id in pairs(chars) do list[#list + 1] = id end; return list end
local buckets = {}
GetPlayerRoutingBucket = function(id) return buckets[id] or 0 end
SetPlayerRoutingBucket = function(id, b) buckets[id] = b end
local positions = {}
Open77 = {
    players = {
        position = function(id) local p = positions[id]; return p and { x = p.x, y = p.y, z = p.z } end,
        get = function(id) local p = positions[id]; return p and { position = p, heading = 0, bucket = buckets[id] or 0 } end,
        getLifeState = function() return { phase = "alive" } end,
        teleport = function(id, pos, opts)
            return { await = function() buckets[id] = opts.bucket; positions[id] = { x = pos.x, y = pos.y, z = pos.z }; return true end }
        end,
        respawn = function() return true end,
        heal = function() return true end,
    },
    vehicles = { getPlayerSeat = function() return nil end },
    time = { unix = function() return 1800000000 + math.floor(t / 1000) end },
}
-- the street reputation (server/modules/missions.lua), with its tiers
local TIERS, NAMES = { 0, 500, 1500, 4000, 10000 }, { "Street", "Merc", "Operator", "Edgerunner", "Legend" }
local ROMAN = { "I", "II", "III", "IV", "V" }
local rep, granted = {}, {}
local M = {}
function M.reputation(id) return rep[id] or 0 end
function M.tier(id) local n = 1; for i, v in ipairs(TIERS) do if M.reputation(id) >= v then n = i end end; return n end
function M.tierName(tier) return NAMES[tier] end
function M.tierLabel(tier) return ROMAN[tier] .. " (" .. NAMES[tier] .. ")" end
function M.tierInfo(id)
    local tier = M.tier(id)
    return { tier = tier, name = NAMES[tier], points = M.reputation(id), max = 5, next = TIERS[tier + 1], nextName = NAMES[tier + 1] }
end
function M.addReputation(id, amount) granted[#granted + 1] = { id = id, amount = amount }; rep[id] = (rep[id] or 0) + amount end
M.handlesDeath, M.handlesLoadout, M.instanceOf, M.point, M.untag = noop, noop, noop, noop, noop
LightRP.missions = M

dofile("server/modules/activities.lua")
local A = LightRP.activities
loaded = true
local function lastEvent(name) for i = #events, 1, -1 do if events[i].name == name then return events[i] end end end
local function lastHook() for i = #hooks, 1, -1 do if hooks[i].hook == "onActivityChanged" then return hooks[i].args end end end
local function entry(view, id) for _, a in ipairs(view.list) do if a.id == id then return a end end end
local function result(id, activityId, r)
    advance(16000)
    local before = #granted
    assert(A.result(id, activityId, r))
    run()
    return #granted > before and granted[#granted].amount or 0
end

-- ---------------------------------------------------------------------------
-- Registry: which activities are PvE
assert(exported.activityRegister({ id = "arena.pve", resource = "op77_arena", label = "Combat Zone · PvE", kind = "pvp",
    difficulties = { "critical", "standard", "bogus", "hard" } }))
local pveDef = A.registry["arena.pve"]
assert(pveDef.pve == true and pveDef.weight == 1.0, "listed in the config: PvE, its weight")
assert(#pveDef.difficulties == 3 and pveDef.difficulties[1] == "standard" and pveDef.difficulties[3] == "critical",
    "known difficulties only, in the config's order")
assert(exported.activityRegister({ id = "arena.ffa", resource = "op77_arena", label = "Arena FFA", kind = "pvp" }))
assert(A.registry["arena.ffa"].pve == false and A.registry["arena.ffa"].difficulties == nil, "PvP by default")
invoking = "op77_race"
assert(exported.activityRegister({ id = "race.pve", resource = "op77_race", label = "Street Race vs AI", kind = "race", pve = false }))
assert(A.registry["race.pve"].pve == false, "pve = false wins over the config's list")
local ok, why = exported.activityRegister({ id = "race.ai", resource = "op77_race", label = "AI", kind = "race", pve = "yes" })
assert(not ok and why:find("pve"), "pve is a boolean")
ok, why = exported.activityRegister({ id = "race.ai", resource = "op77_race", label = "AI", kind = "race", pve = true,
    difficulties = { "hard" }, modeKey = "difficulty" })
assert(not ok and why:find("modeKey"), "the difficulty key is the core's")
invoking = "op77_turf"
assert(exported.activityRegister({ id = "turf.pve", resource = "op77_turf", label = "Gang Sweep", kind = "event", pve = true }))
assert(A.registry["turf.pve"].pve and A.registry["turf.pve"].difficulties == nil and A.registry["turf.pve"].weight == 1.2,
    "PvE without declared difficulties: it plays Standard")
invoking = "op77_arena"
run()

-- ---------------------------------------------------------------------------
-- The panel: difficulties locked above the tier, the tier in the footer
local P = 1
character(P); positions[P] = { x = -756.5, y = 777.2, z = 22.4 }
local view = providers.activities(P)
local zone = entry(view, "arena.pve")
assert(zone.pve and #zone.difficulties == 3)
assert(not zone.difficulties[1].locked and zone.difficulties[2].locked and zone.difficulties[3].locked, "Street: Standard only")
assert(zone.difficulties[2].minTier == 2 and zone.difficulties[2].tierName == "Merc" and zone.difficulties[3].reputation == 100)
assert(entry(view, "arena.ffa").pve == false and entry(view, "arena.ffa").difficulties == nil)
assert(entry(view, "turf.pve").difficulties[1].id == "standard" and entry(view, "turf.pve").difficulties[1].reputation == 36,
    "30 x weight 1.2")
assert(view.reputation.tier == 1 and view.reputation.tierName == "Street" and view.reputation.next == 500
    and view.reputation.nextName == "Merc" and view.reputation.pvpGrants == false)

-- ---------------------------------------------------------------------------
-- Join: the difficulty is checked against the tier and handed to the provider
ok, why = A.requestJoin(P, "arena.pve", "panel", { difficulty = "hard" })
assert(not ok and why:find("Hard needs reputation tier II %(Merc%)"), "above the tier: refused")
ok, why = A.requestJoin(P, "arena.pve", "panel", { difficulty = "nightmare" })
assert(not ok and why:find("Choose a difficulty"), "an unknown difficulty")
assert(lastEvent("op77_lightrp:activity:join") == nil, "nothing reached the provider")
assert(A.requestJoin(P, "arena.pve", "panel", {}))
local join = lastEvent("op77_lightrp:activity:join").args[3]
assert(join.difficulty == "standard" and join.scaling.enemies == 1 and join.scaling.ai == "standard", "the first offered by default")
assert(providers.activities(P).queued.difficulty == "standard")
-- the provider's own check
ok, why = exported.activityCheck(P, "arena.pve", { difficulty = "critical" })
assert(not ok and why:find("Operator"), "activityCheck opts.difficulty")
assert(exported.activityCheck(P, "arena.pve", { difficulty = "standard" }) and exported.activityCheck(P, "arena.ffa", { difficulty = "critical" }),
    "PvP has no difficulty gate")

-- ---------------------------------------------------------------------------
-- Enter: the queued difficulty, the hook
assert(exported.activityEnter(P, "arena.pve"))
local e = A.current(P)
assert(e.pve and e.difficulty == "standard" and e.weight == 1.0)
local h = lastHook()
assert(h[1] == P and h[2] == "arena.pve" and h[3].pve == true and h[3].kind == "pvp" and h[3].difficulty == "standard",
    "modules hear about it (cyberware in PvP)")

-- ---------------------------------------------------------------------------
-- PvE results: the difficulty's reward x the weight, never more
assert(result(P, "arena.pve", { won = true }) == 30, "a win that names no amount: the full reward")
assert(notices[#notices].def.body:find("Standard", 1, true) and notices[#notices].def.body:find("+30 reputation", 1, true))
assert(result(P, "arena.pve", { won = true, reputation = 1000 }) == 30, "never more than the reward")
assert(result(P, "arena.pve", { won = false, reputation = 12 }) == 12, "a partial amount is taken as asked")
assert(result(P, "arena.pve", { won = false }) == 0, "a loss that names nothing earns nothing")
assert(result(P, "arena.pve", { won = true, difficulty = "critical" }) == 30, "the entry's difficulty, not the result's")
assert(exported.activityLeave(P, "arena.pve", { returnPlayer = false }))
h = lastHook()
assert(h[1] == P and h[2] == nil and h[3].left == "arena.pve", "released: the hook again, no activity")
advance(3100)

-- tier III: Critical opens; the provider enters at it
rep[P] = 1500
ok, why = exported.activityEnter(P, "arena.pve", { difficulty = "nightmare" })
assert(not ok and why:find("Choose a difficulty"))
assert(exported.activityEnter(P, "arena.pve", { difficulty = "critical" }))
assert(A.current(P).difficulty == "critical")
assert(result(P, "arena.pve", { won = true }) == 100, "Critical: 100")
-- the tier drops mid-run (staff /missions.rep): lowered to what it allows
rep[P] = 600
assert(result(P, "arena.pve", { won = true }) == 60, "lowered to Hard")
rep[P] = 0
assert(result(P, "arena.pve", { won = true }) == 30, "lowered to Standard")
assert(exported.activityLeave(P, "arena.pve", { returnPlayer = false }))
advance(3100)
ok, why = exported.activityEnter(P, "arena.pve", { difficulty = "critical" })
assert(not ok and why:find("Critical needs reputation tier III"), "a provider cannot enter a player above their tier")

-- weight: Gang Sweep 1.2
invoking = "op77_turf"
assert(exported.activityEnter(P, "turf.pve"))
assert(A.current(P).difficulty == "standard")
assert(result(P, "turf.pve", { won = true }) == 36)
assert(exported.activityLeave(P, "turf.pve", { returnPlayer = false }))
advance(3100)
invoking = "op77_arena"

-- ---------------------------------------------------------------------------
-- PvP: stats and leaderboards, never reputation
assert(exported.activityEnter(P, "arena.ffa"))
assert(A.current(P).pve == false and A.current(P).difficulty == nil)
assert(result(P, "arena.ffa", { placement = 1, won = true, reputation = 50, stats = { kills = 7 } }) == 0, "PvP grants nothing")
assert(not notices[#notices].def.body:find("reputation", 1, true), "and does not talk about it")
local ffa = entry(providers.activities(P), "arena.ffa")
assert(ffa.mine.played == 1 and ffa.mine.wins == 1 and ffa.mine.kills == 7 and ffa.mine.reputation == 0, "the win is recorded")
assert(ffa.top[1] and ffa.top[1].wins == 1, "and ranked")
-- the legacy switch: every kind granted, clamped to maxPerResult
LightRpActivities.reputation.pvpGrants = true
assert(result(P, "arena.ffa", { placement = 1, won = true, reputation = 500 }) == LightRpActivities.reputation.maxPerResult)
LightRpActivities.reputation.pvpGrants = false
assert(exported.activityLeave(P, "arena.ffa", { returnPlayer = false }))
advance(3100)

-- ---------------------------------------------------------------------------
-- The daily cap still holds for PvE
local today = providers.activities(P).reputation.today
LightRpActivities.reputation.dailyCap = today + 10
rep[P] = 1500
assert(exported.activityEnter(P, "arena.pve", { difficulty = "critical" }))
assert(result(P, "arena.pve", { won = true }) == 10, "the rest of the day's cap")
assert(result(P, "arena.pve", { won = true }) == 0 and notices[#notices].def.body:find("cap reached"))
LightRpActivities.reputation.dailyCap = 500
assert(exported.activityLeave(P, "arena.pve", { returnPlayer = false }))
advance(3100)

-- bot mode: nothing earned
assert(commands["lightrp.bots"](0, { "on" }))
assert(exported.activityEnter(P, "arena.pve"))
assert(result(P, "arena.pve", { won = true }) == 0, "no reputation in bot mode")
assert(commands["lightrp.bots"](0, { "off" }))
assert(exported.activityLeave(P, "arena.pve", { returnPlayer = false }))
advance(3100)

-- ---------------------------------------------------------------------------
-- Crews (owner decision 2026-11-03): a member below the leader's difficulty is never
-- refused; they play it in full and earn the reward of the highest difficulty their
-- tier opens. The leader, and a player alone, are gated.
local L, MEM = 2, 3
character(L); positions[L] = { x = -756.0, y = 777.0, z = 22.4 }
character(MEM); positions[MEM] = { x = -757.0, y = 778.0, z = 22.4 }
local crew = { id = "crew:1", leader = L, members = { L, MEM }, invites = {} }
local crews = { [L] = crew, [MEM] = crew }
LightRP.parties = { of = function(id) return crews[id] end }
rep[L], rep[MEM] = 0, 0
-- the leader's own gate still applies
ok, why = A.requestJoin(L, "arena.pve", "panel", { difficulty = "critical" })
assert(not ok and why:find("Critical needs reputation tier III"), "leader gate: " .. tostring(why))
ok, why = exported.activityCheck(MEM, "arena.pve", { difficulty = "critical" })
assert(not ok and why:find("Critical needs reputation tier III"), "nor can a member go where their leader cannot")
ok, why = A.requestJoin(MEM, "arena.pve", "panel", { difficulty = "standard" })
assert(not ok and why:find("crew leader"), "the leader starts activities")
-- the Operator leader picks Critical: the Street member is queued with the crew, told once
rep[L] = 1500
local before = #notices
ok, why = A.requestJoin(L, "arena.pve", "panel", { difficulty = "critical" })
assert(ok and why:find("with 1 crew member", 1, true) and why:find("reduced reward: Runner3 (Standard)", 1, true), why)
local memberJoin = lastEvent("op77_lightrp:activity:join")
assert(memberJoin.args[1] == MEM and memberJoin.args[3].difficulty == "critical" and memberJoin.args[3].scaling.health == 2.25,
    "the member plays the leader's difficulty, at its full scaling")
local toMember
for i = before + 1, #notices do if notices[i].id == MEM then toMember = notices[i] end end
assert(toMember and toMember.def.body:find("Critical is above your street cred: you play it, you earn the Standard reward.", 1, true),
    toMember and toMember.def.body)
assert(providers.activities(MEM).queued.difficulty == "critical", "the member's queue shows Critical")
-- the provider checks and enters them at Critical
assert(exported.activityCheck(MEM, "arena.pve", { difficulty = "critical" }), "activityCheck lets a carried member in")
local afterQueue = #notices
assert(exported.activityEnter(L, "arena.pve"))
assert(exported.activityEnter(MEM, "arena.pve", { difficulty = "critical" }))
assert(A.current(MEM).difficulty == "critical" and A.current(MEM).carried and not A.current(L).carried)
for i = afterQueue + 1, #notices do assert(notices[i].def.title ~= "STREET CRED", "told once: the queue said it already") end
-- the results: both played Critical, the member earns the Standard reward
assert(result(L, "arena.pve", { won = true }) == 100, "the leader: Critical")
assert(result(MEM, "arena.pve", { won = true }) == 30, "the member: the reward of their tier")
assert(notices[#notices].def.body:find("Critical (Standard reward)", 1, true) and notices[#notices].def.body:find("+30 reputation", 1, true),
    notices[#notices].def.body)
assert(result(MEM, "arena.pve", { won = false, reputation = 80 }) == 30, "a partial amount is capped at their reward too")
-- bot mode still records nothing, carried or not
assert(commands["lightrp.bots"](0, { "on" }))
assert(result(MEM, "arena.pve", { won = true }) == 0 and result(L, "arena.pve", { won = true }) == 0, "bot mode: no PvE result recorded")
assert(commands["lightrp.bots"](0, { "off" }))
assert(exported.activityLeave(L, "arena.pve", { returnPlayer = false }) and exported.activityLeave(MEM, "arena.pve", { returnPlayer = false }))
advance(3100)
-- a provider entering a member itself (no panel queue): let in, told at the entry
before = #notices
assert(exported.activityEnter(MEM, "arena.pve", { difficulty = "hard" }))
assert(A.current(MEM).difficulty == "hard" and A.current(MEM).carried)
assert(notices[#notices].id == MEM and notices[#notices].def.title == "STREET CRED"
    and notices[#notices].def.body:find("Hard is above your street cred", 1, true), "told once, at the entry")
assert(result(MEM, "arena.pve", { won = true }) == 30)
assert(exported.activityLeave(MEM, "arena.pve", { returnPlayer = false }))
advance(3100)
-- alone again, the same player is gated
crews = {}
ok, why = exported.activityCheck(MEM, "arena.pve", { difficulty = "critical" })
assert(not ok and why:find("Critical needs reputation tier III"), "solo gate: activityCheck")
ok, why = exported.activityEnter(MEM, "arena.pve", { difficulty = "hard" })
assert(not ok and why:find("Hard needs reputation tier II"), "solo gate: activityEnter")
ok, why = A.requestJoin(MEM, "arena.pve", "panel", { difficulty = "hard" })
assert(not ok and why:find("Hard needs reputation tier II"), "solo gate: the panel")
LightRP.parties = nil

-- the command: /activity join <id> <difficulty>
rep[P] = 0
ok, why = commands.activity(P, { "join", "arena.pve", "hard" })
assert(not ok and why:find("Hard needs"), "the command passes the difficulty")
rep[P] = 500
assert(commands.activity(P, { "join", "arena.pve", "hard" }))
assert(lastEvent("op77_lightrp:activity:join").args[3].difficulty == "hard"
    and lastEvent("op77_lightrp:activity:join").args[3].scaling.health == 1.5)
print("PASS: PvE flag and difficulties, tier-gated join/check/enter, PvE reputation by difficulty x weight and tier, PvP without reputation, legacy switch, daily cap, bot mode, crew members below the leader's difficulty play it for their own reward (leader and solo gated), onActivityChanged")
