-- The activity lobby (server/modules/activities.lua "Lobby", config `lobby`): bots
-- chosen in the panel (PvP bot match, PvE allied fill), the botFill declaration,
-- the ranked flag and the unranked gate of A.result, the core's ranked queue (team
-- sizes, cyberware brackets widening with the wait, a lone player never starves,
-- the bot fill offer), friendly crew matches, staff bot mode, the panel's state.
-- No game, no DB.
dofile("shared/config.lua")
dofile("server/config/activities.lua")
dofile("server/config/cyberware.lua")
local noop = function() end
local t = 1000
local providers, actions, commands, handlers, exported = {}, {}, {}, {}, {}
local events, notices, logs, results = {}, {}, {}, {}
LightRP = {
    db = { ready = false, schema = noop, run = noop, read = function() return false end, single = noop, query = function() return {} end },
    module = function(name, value) value.name = name; LightRP[name] = value; return value end,
    stateProvider = function(key, fn) providers[key] = fn end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    state = noop, eachModule = noop, broadcastState = noop, dialog = noop,
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
TriggerEvent = function(name, ...) events[#events + 1] = { name = name, args = table.pack(...) } end
exports = function(name, fn) exported[name] = fn end
local invoking
GetInvokingResource = function() return invoking end
GetCurrentResourceName = function() return "op77_lightrp" end
local resourceStates = { op77_arena = "running", op77_race = "running", op77_turf = "running" }
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
local A = LightRP.activities
loaded = true

local JOIN, LEAVE = "op77_lightrp:activity:join", "op77_lightrp:activity:leaveRequest"
local function player(id, tier)
    chars[id] = { identifier = "acct-" .. id, key = "default", status = "active", firstName = "Runner" .. id }
    positions[id] = { x = -756.5, y = 777.2, z = 22.4 }; buckets[id] = 0; life[id] = "alive"
    tiers[id] = tier
end
local function crew(leader, ...)
    local c = { id = "crew-" .. leader, leader = leader, members = { leader, ... } }
    for _, p in ipairs(c.members) do crews[p] = c end
    return c
end
local function mark() return #events end
local function after(m, name)
    local out = {}
    for i = m + 1, #events do if events[i].name == name then out[#out + 1] = events[i] end end
    return out
end
local function of(list, id) for _, e in ipairs(list) do if e.args[1] == id then return e end end end
local function noticed(id, text)
    for i = #notices, 1, -1 do
        local n = notices[i]
        if n.id == id and tostring(n.def.body or ""):find(text, 1, true) then return n end
    end
end
local function enter(id, aid, res) invoking = res; local ok, why = exported.activityEnter(id, aid); invoking = nil; return ok, why end
local function leave(id, aid, res) invoking = res; exported.activityLeave(id, aid, { returnPlayer = false }); invoking = nil end
local function entry(v, id) for _, x in ipairs(v.list) do if x.id == id then return x end end end
local function rows() return #A.memoryRows() end
local function ticketsOf(aid) local n = 0; for _, tk in pairs(A.tickets) do if tk.activity == aid then n = n + 1 end end; return n end
local function values(x) if type(x) ~= "table" then return 1 end local n = 1; for _, v in pairs(x) do n = n + values(v) end; return n end

-- ---------------------------------------------------------------------------
-- Registration: botFill must be a boolean; a mode may opt out
invoking = "op77_arena"
local ok, why = exported.activityRegister({ id = "arena.duel", resource = "op77_arena", label = "Duel", kind = "pvp",
    minPlayers = 2, maxPlayers = 2, botFill = "yes" })
assert(not ok and why:find("botFill"), "botFill must be true or false")
assert(exported.activityRegister({ id = "arena.duel", resource = "op77_arena", label = "Duel", kind = "pvp",
    minPlayers = 2, maxPlayers = 2, botFill = true }))
assert(exported.activityRegister({ id = "arena.teams", resource = "op77_arena", label = "Team Arena", kind = "pvp",
    minPlayers = 4, maxPlayers = 6, botFill = true,
    modes = { { id = "2v2", label = "2v2" }, { id = "3v3", label = "3v3", botFill = false } } }))
assert(exported.activityRegister({ id = "arena.ffa", resource = "op77_arena", label = "Combat Zone", kind = "pvp", maxPlayers = 8 }))
assert(exported.activityRegister({ id = "arena.pve", resource = "op77_arena", label = "Combat Zone PvE", kind = "pvp", pve = true,
    maxPlayers = 6, difficulties = { "standard", "hard", "critical" }, botFill = true }))
invoking = "op77_turf"
assert(exported.activityRegister({ id = "turf.pve", resource = "op77_turf", label = "Gang Sweep", kind = "pvp", pve = true, maxPlayers = 8 }))
assert(exported.activityRegister({ id = "turf.war", resource = "op77_turf", label = "Turf War", kind = "pvp",
    minPlayers = 2, maxPlayers = 20, botFill = true }))
invoking = "op77_race"
assert(exported.activityRegister({ id = "race.grid", resource = "op77_race", label = "Street Race", kind = "race",
    minPlayers = 2, maxPlayers = 8, modeKey = "course", botFill = true,
    modes = { { id = "loop", label = "Loop" }, { id = "dash", label = "Dash" } } }))
invoking = nil
run()
assert(A.registry["arena.duel"].botFill == true and A.registry["arena.ffa"].botFill == false)
assert(A.registry["arena.teams"].modes[1].botFill == nil and A.registry["arena.teams"].modes[2].botFill == false)

-- The panel's entries: what each one offers (botFill AND the config's lobby entry)
player(1, 1)
local v = providers.activities(1)
local duel = entry(v, "arena.duel").lobby
assert(duel.bots and duel.friendly and duel.queue and duel.brackets and not duel.allies)
assert(entry(v, "arena.ffa").lobby.bots == nil and entry(v, "arena.ffa").lobby.friendly, "no botFill: no bot toggle")
assert(entry(v, "arena.pve").lobby.allies and entry(v, "arena.pve").lobby.seats == 6)
assert(entry(v, "turf.pve").lobby == nil, "a PvE provider without botFill: no allied bots")
assert(entry(v, "race.grid").lobby.queue and entry(v, "race.grid").lobby.brackets == nil, "races ignore the brackets")
assert(entry(v, "turf.war").lobby.queue == nil and entry(v, "turf.war").lobby.bots, "turf war keeps its own queue")
assert(v.lobby.fillAfterMs == 120000 and v.friendly == false and v.queued == false)
for _, x in ipairs(v.list) do assert(values(x.lobby) <= 8, "a lobby entry stays small") end

-- ---------------------------------------------------------------------------
-- "Play with bots" (PvP): a match the core forms, unranked, nothing recorded
local m = mark()
ok, why = A.requestJoin(1, "arena.duel", "panel", { bots = true })
assert(ok and why:find("with bots") and why:find("unranked"), why)
local joins = after(m, JOIN)
assert(#joins == 1)
local o = joins[1].args[3]
assert(o.ranked == false and o.bots == nil, "the panel's bots key stays the core's")
assert(o.match and o.match.friendly == false and o.match.ranked == false and #o.match.players == 1 and o.match.side == 1)
assert(o.match.teams[1][1] == 1 and #o.match.teams[2] == 0 and o.match.bots[1] == 0 and o.match.bots[2] == 1)
assert(o.fill.allies == 0 and o.fill.enemies == 1)
assert(exported.activityRanked(1) == false and A.isRanked(A.matches[o.match.id]) == false)
v = providers.activities(1)
assert(v.queued.match and v.queued.ranked == false and v.queued.fillInMs == nil)
assert(enter(1, "arena.duel", "op77_arena"))
assert(A.owned[1].ranked == false and A.owned[1].match == o.match.id and exported.activityRanked(1) == false)
local raw = { placement = 1, won = true, stats = { kills = 3 } }
assert(A.result(1, "arena.duel", raw))
run()
assert(raw.unranked == true and raw.ranked == false and rows() == 0, "a bot match records nothing: no stats, no Hall of Fame row")
leave(1, "arena.duel", "op77_arena")
advance(3100)

-- botFill gating: no declaration, a mode opting out, a PvE provider without it
ok, why = A.requestJoin(1, "arena.ffa", "panel", { bots = true })
assert(not ok and why:find("cannot be played with bots"), why)
ok, why = A.requestJoin(1, "arena.teams", "panel", { mode = "3v3", bots = true })
assert(not ok and why:find("3v3") and why:find("bots"), why)
ok, why = A.requestJoin(1, "turf.pve", "panel", { bots = true })
assert(not ok and why:find("no allied bots"), why)
assert(#after(m, JOIN) == 1, "nothing refused reached a provider")
-- 2v2 alone: one bot beside you, two against
m = mark()
assert(A.requestJoin(1, "arena.teams", "panel", { mode = "2v2", bots = true }))
o = after(m, JOIN)[1].args[3]
assert(o.mode == "2v2" and o.match.format == "2v2" and o.match.bots[1] == 1 and o.match.bots[2] == 2)
assert(o.fill.allies == 1 and o.fill.enemies == 2)
assert(A.requestLeave(1))
assert(after(m, LEAVE)[1].args[2] == "arena.teams", "leaving a match on its way tells the provider")

-- ---------------------------------------------------------------------------
-- PvE "Fill empty slots with bots": 6 seats, crew of 4 -> 2 allied bots, still ranked
for id = 2, 4 do player(id, 1) end
crew(1, 2, 3, 4)
m = mark()
ok, why = A.requestJoin(1, "arena.pve", "panel", { bots = true })
assert(ok and why:find("2 allied bots"), why)
joins = after(m, JOIN)
assert(#joins == 4)
for _, j in ipairs(joins) do
    o = j.args[3]
    assert(o.ranked == true and o.match == nil and o.fill.allies == 2 and o.fill.enemies == 0, "the same fill on every member's join")
    assert(o.difficulty == "standard" and o.scaling and o.scaling.enemies == 1)
end
assert(providers.activities(2).queued.allies == 2 and providers.activities(2).queued.lead == false)
for id = 1, 4 do assert(enter(id, "arena.pve", "op77_arena")); assert(exported.activityRanked(id) == true) end
raw = { placement = 1, won = true, stats = { bots = 2 } }
assert(A.result(1, "arena.pve", raw))
run()
assert(raw.ranked == true and raw.unranked == nil and rows() == 1, "PvE with allied bots counts (stats, reputation, pay)")
for id = 1, 4 do leave(id, "arena.pve", "op77_arena") end
advance(3100)
-- a crew of 2: 4 allies; solo: 5; without the toggle: none
crew(1, 2); crews[3], crews[4] = nil, nil
m = mark()
assert(A.requestJoin(1, "arena.pve", "panel", { bots = true }))
assert(after(m, JOIN)[1].args[3].fill.allies == 4)
assert(A.requestLeave(1))
crews[1], crews[2] = nil, nil
m = mark()
assert(A.requestJoin(1, "arena.pve", "panel", { bots = "true" }))
assert(after(m, JOIN)[1].args[3].fill.allies == 5)
assert(A.requestLeave(1))
m = mark()
assert(A.requestJoin(1, "arena.pve", "panel"))
assert(after(m, JOIN)[1].args[3].fill == nil and after(m, JOIN)[1].args[3].ranked == true)
assert(A.requestLeave(1))

-- ---------------------------------------------------------------------------
-- The unranked gate on a ranked drop-in (arena.ffa): PvP bots, vsAi, the provider's flag
player(5, 1)
m = mark()
assert(A.requestJoin(5, "arena.ffa", "panel"))
o = after(m, JOIN)[1].args[3]
assert(o.ranked == true and o.match == nil, "a plain PvP join: ranked, the provider's own path")
assert(enter(5, "arena.ffa", "op77_arena"))
local before = rows()
for _, r in ipairs({ { placement = 2, stats = { bots = 3 } }, { placement = 2, stats = { bots = true } },
        { placement = 2, stats = { vsAi = true } }, { placement = 2, unranked = true }, { placement = 2, test = true } }) do
    assert(A.result(5, "arena.ffa", r))
    run()
    assert(r.unranked == true and rows() == before, "unranked: nothing recorded")
    advance(16000)
end
raw = { placement = 1, won = true, stats = { kills = 2 } }
assert(A.result(5, "arena.ffa", raw))
run()
assert(raw.ranked == true and rows() == before + 1, "humans only: recorded")
leave(5, "arena.ffa", "op77_arena")
advance(3100)

-- ---------------------------------------------------------------------------
-- The ranked queue (arena.duel): cyberware brackets, same or adjacent first
player(11, 1); player(12, 5); player(13, 2); player(14, 3)
assert(A.bracketOf(11) == 1 and A.bracketOf(13) == 2 and A.bracketOf(14) == 3 and A.bracketOf(12) == 5,
    "tier -> highest cyberware rank it opens -> bracket")
m = mark()
ok, why = A.requestJoin(11, "arena.duel", "panel")
assert(ok and why:find("Searching for a ranked Duel"), why)
assert(#after(m, JOIN) == 0, "the provider hears nothing while the core searches")
v = providers.activities(11)
assert(v.queued.search.found == 1 and v.queued.search.needed == 2 and v.queued.search.scope == "near" and v.queued.search.bracket == 1)
assert(v.queued.ranked == true and v.queued.lead == true and v.queued.fillInMs == 120000)
assert(exported.activityRanked(11) == true)
advance(1000)
assert(A.requestJoin(12, "arena.duel", "panel"))
assert(#after(m, JOIN) == 0, "brackets 1 and 5 do not meet at first")
advance(1000)
assert(A.requestJoin(13, "arena.duel", "panel"))
joins = after(m, JOIN)
assert(#joins == 2 and of(joins, 11) and of(joins, 13), "adjacent brackets match at once")
o = of(joins, 11).args[3]
assert(o.ranked == true and o.match.ranked == true and o.match.friendly == false and o.fill == nil and o.match.bots == nil)
assert(o.match.teams[1][1] == 11 and o.match.teams[2][1] == 13 and o.match.side == 1 and o.from == "queue")
assert(of(joins, 13).args[3].match.side == 2 and of(joins, 13).args[3].match.id == o.match.id)
assert(noticed(11, "Ranked Duel") and noticed(13, "Ranked Duel"))
assert(ticketsOf("arena.duel") == 1, "the tier V searcher still waits")
assert(enter(11, "arena.duel", "op77_arena") and A.owned[11].ranked == true and A.owned[11].match == o.match.id)
raw = { placement = 1, won = true }
assert(A.result(11, "arena.duel", raw))
run()
assert(raw.ranked == true, "a ranked match from the core's queue counts")
leave(11, "arena.duel", "op77_arena")

-- widening over time: 5 vs 3 waits until the oldest searcher's 60 s
m = mark()
advance(9000) -- tier V has waited 10 s
assert(A.requestJoin(14, "arena.duel", "panel"))
assert(#after(m, JOIN) == 0)
v = providers.activities(12)
assert(v.queued.search.scope == "near" and v.queued.search.found == 1 and v.queued.search.widenInMs == 50000)
advance(48000) -- 58 s
A.lobbyTick()
assert(#after(m, JOIN) == 0, "near your rank until the first widening")
advance(2000) -- 60 s: two brackets apart
A.lobbyTick()
joins = after(m, JOIN)
assert(#joins == 2 and of(joins, 12) and of(joins, 14), "the search widens with the oldest searcher's wait")
assert(ticketsOf("arena.duel") == 0)
for _, id in ipairs({ 12, 13, 14 }) do A.requestLeave(id) end

-- a lone player never starves: everyone mixes, then the bot fill offer
player(15, 1); player(16, 5); player(17, 1)
m = mark()
assert(A.requestJoin(15, "arena.duel", "panel"))
advance(90000)
A.lobbyTick()
assert(A.requestJoin(16, "arena.duel", "panel"))
assert(#after(m, JOIN) == 0, "at 90 s brackets 1 and 5 are still too far apart")
advance(10000)
A.lobbyTick()
assert(#after(m, JOIN) == 2, "at 100 s every bracket mixes")
A.requestLeave(15); A.requestLeave(16)
m = mark()
assert(A.requestJoin(17, "arena.duel", "panel"))
advance(100000)
A.lobbyTick()
v = providers.activities(17)
assert(v.queued.search.scope == "all" and v.queued.search.widenInMs == nil and v.queued.fillInMs == 20000)
assert(not noticed(17, "Fill the empty places"))
advance(20000)
A.lobbyTick()
assert(noticed(17, "Fill the empty places with bots"), "the leader hears of the bot fill once")
local count = #notices
A.lobbyTick()
assert(#notices == count, "once")
assert(providers.activities(17).queued.fillInMs == 0)
ok, why = A.fillSearch(17)
assert(ok and why:find("unranked"), why)
joins = after(m, JOIN)
assert(#joins == 1)
o = joins[1].args[3]
assert(o.ranked == false and o.match.ranked == false and o.match.bots[2] == 1 and o.fill.enemies == 1)
assert(ticketsOf("arena.duel") == 0 and providers.activities(17).queued.match)
A.requestLeave(17)

-- crews: the highest member's tier counts; team sizes decide the sides
player(21, 1); player(22, 5); player(23, 1); player(24, 1); player(25, 4); player(26, 4)
crew(21, 22); crew(23, 24); crew(25, 26)
m = mark()
assert(A.requestJoin(21, "arena.teams", "panel", { mode = "2v2" }))
assert(A.requestJoin(23, "arena.teams", "panel", { mode = "2v2" }))
assert(#after(m, JOIN) == 0, "a crew of tier I + V counts V: not against tier I at first")
v = providers.activities(22)
assert(v.queued.search.bracket == 5 and v.queued.lead == false and v.queued.search.needed == 4)
assert(noticed(22, "queued the crew for ranked Team Arena"))
assert(A.requestJoin(25, "arena.teams", "panel", { mode = "2v2" }))
joins = after(m, JOIN)
assert(#joins == 4 and of(joins, 21) and of(joins, 22) and of(joins, 25) and of(joins, 26), "bracket 5 + bracket 4")
o = of(joins, 22).args[3]
assert(o.mode == "2v2" and o.match.format == "2v2" and o.match.side == 1 and #o.match.teams[1] == 2 and o.squad.leader == 21)
assert(of(joins, 26).args[3].match.side == 2)
-- a crew of 2 and two solos (any format) make a 2v2
player(27, 1); player(28, 1)
m = mark()
assert(A.requestJoin(27, "arena.teams", "panel"))
assert(#after(m, JOIN) == 0)
assert(A.requestJoin(28, "arena.teams", "panel"))
joins = after(m, JOIN)
assert(#joins == 4)
o = of(joins, 27).args[3]
assert(o.match.format == "2v2" and o.mode == "2v2")
local sideOf = {}
for i, team in ipairs(o.match.teams) do for _, p in ipairs(team) do sideOf[p] = i end end
assert(sideOf[23] == sideOf[24] and sideOf[27] == sideOf[28] and sideOf[23] ~= sideOf[27], "the crew stays whole, on one side")
for _, id in ipairs({ 21, 22, 23, 24, 25, 26, 27, 28 }) do A.requestLeave(id) end
-- a crew too big for one side is told to play a friendly
player(29, 1); player(30, 1); crew(29, 30)
ok, why = A.requestJoin(29, "arena.duel", "panel")
assert(not ok and why:find("friendly"), why)
crews[29], crews[30] = nil, nil

-- leaving a held search: a member (the crew keeps searching), then the leader (all out)
player(31, 1); player(32, 1); player(33, 1); crew(31, 32, 33)
m = mark()
assert(A.requestJoin(31, "arena.teams", "panel", { mode = "3v3" }))
assert(A.isRanked(32) == true)
ok, why = A.requestLeave(33)
assert(ok and noticed(31, "left the search") and providers.activities(33).queued == false)
assert(providers.activities(32).queued.search.found == 2)
assert(A.requestLeave(31))
assert(providers.activities(32).queued == false and noticed(32, "Your crew leader left the search"))
assert(ticketsOf("arena.teams") == 0 and #after(m, LEAVE) == 0, "the provider never heard of the search")
-- a member who disconnects or leaves the crew leaves the search
assert(A.requestJoin(31, "arena.teams", "panel", { mode = "3v3" }))
A.onDisconnected(33)
crews[33] = nil
crew(31, 32)
A.onCrewLeft(32)
local held
for _, tk in pairs(A.tickets) do if tk.activity == "arena.teams" then held = tk end end
assert(held and #held.members == 1 and held.members[1] == 31)
assert(A.requestLeave(31))
crews[31], crews[32] = nil, nil
player(33, 1)

-- races: a free-for-all gathers a moment for more, the course comes from the oldest
player(41, 1); player(42, 5)
m = mark()
assert(A.requestJoin(41, "race.grid", "panel", { course = "loop" }))
assert(A.requestJoin(42, "race.grid", "panel"))
assert(#after(m, JOIN) == 0, "two of eight: the race waits for more")
advance(15000)
A.lobbyTick()
joins = after(m, JOIN)
assert(#joins == 2, "brackets = false: tiers I and V race together")
assert(of(joins, 42).args[3].course == "loop" and of(joins, 42).args[3].match.teams == nil and of(joins, 42).args[3].ranked == true)
A.requestLeave(41); A.requestLeave(42)

-- the provider's own queue (turf war): ranked, then the bot fill offer after the wait
player(51, 1)
m = mark()
assert(A.requestJoin(51, "turf.war", "panel"))
o = after(m, JOIN)[1].args[3]
assert(o.ranked == true and o.match == nil, "turf war: its own queue, as before")
v = providers.activities(51)
assert(v.queued.search == nil and v.queued.fillInMs == 120000)
advance(120000)
A.lobbyTick()
assert(noticed(51, "Fill the empty places with bots"))
m = mark()
assert(A.fillSearch(51))
assert(after(m, LEAVE)[1].args[1] == 51 and after(m, LEAVE)[1].args[2] == "turf.war", "the provider's queue lets go first")
o = after(m, JOIN)[1].args[3]
assert(o.ranked == false and o.match and o.match.teams[1][1] == 51 and o.match.bots[1] == 2 and o.match.bots[2] == 3,
    "a split shape: two halves of fillTo")
A.requestLeave(51)

-- ---------------------------------------------------------------------------
-- Friendly crew match: balanced by street cred, moved by hand, unranked
player(61, 5); player(62, 1); crew(61, 62)
ok, why = A.friendlyOpen(62, "arena.duel")
assert(not ok and why:find("leader"), why)
ok, why = A.friendlyOpen(61, "arena.pve")
assert(not ok, "no friendly in PvE")
ok, why = A.friendlyOpen(61, "arena.duel")
assert(ok and why:find("Unranked"), why)
v = providers.activities(62)
assert(v.friendly and v.friendly.mine == false and v.friendly.leader == "Runner61")
assert(v.friendly.teams[1][1].id == 61 and v.friendly.teams[2][1].id == 62 and v.friendly.issue == nil and v.friendly.canBots == true)
assert(providers.activities(61).friendly.mine == true)
ok, why = A.friendlyMove(62, 61)
assert(not ok, "only the leader moves players")
assert(A.friendlyMove(61, 62, 0))
v = providers.activities(61)
assert(#v.friendly.teams[2] == 0 and v.friendly.bench[1].id == 62 and v.friendly.issue:find("Team B"))
assert(A.friendlyMove(61, 61, 2))
v = providers.activities(61)
assert(v.friendly.teams[2][1].id == 61 and #v.friendly.teams[1] == 0)
assert(A.friendlyMove(61, 62, 2), "a full team swaps")
v = providers.activities(61)
assert(v.friendly.teams[2][1].id == 62 and v.friendly.bench[1].id == 61)
assert(A.friendlyBalance(61))
v = providers.activities(61)
assert(v.friendly.teams[1][1].id == 61 and v.friendly.teams[2][1].id == 62)
m = mark()
ok, why = A.friendlyStart(61)
assert(ok and why:find("unranked"), why)
joins = after(m, JOIN)
assert(#joins == 2)
o = of(joins, 62).args[3]
assert(o.ranked == false and o.match.friendly == true and o.match.ranked == false and o.match.side == 2 and o.fill == nil and o.from == "friendly")
assert(noticed(62, "friendly") and providers.activities(61).friendly == false)
assert(enter(61, "arena.duel", "op77_arena") and enter(62, "arena.duel", "op77_arena"))
assert(A.owned[62].friendly == true and exported.activityRanked(62) == false)
before = rows()
raw = { placement = 1, won = true }
assert(A.result(61, "arena.duel", raw))
run()
assert(raw.unranked == true and rows() == before, "friendly: no rank points, no Hall of Fame, no payout, no reputation")
assert(logs[#logs]:find("friendly"))
leave(61, "arena.duel", "op77_arena"); leave(62, "arena.duel", "op77_arena")
advance(3100)

-- a crew of 3 in 2v2: one short, bots complete; 3v3 opts out of bots
player(63, 3); crews[61], crews[62] = nil, nil
crew(61, 62, 63) -- tiers 5, 1, 3
assert(A.friendlyOpen(61, "arena.teams", "2v2"))
v = providers.activities(61)
assert(v.friendly.mode == "2v2" and #v.friendly.teams[1] == 1 and #v.friendly.teams[2] == 2, "snake order: 61 | 63 62")
assert(v.friendly.teams[1][1].id == 61 and v.friendly.issue:find("turn bots on"), v.friendly.issue)
assert(A.friendlyBots(61, true))
v = providers.activities(61)
assert(v.friendly.bots == true and v.friendly.issue == nil and v.friendly.teamBots[1] == 1 and v.friendly.teamBots[2] == 0)
m = mark()
assert(A.friendlyStart(61))
joins = after(m, JOIN)
assert(#joins == 3)
assert(of(joins, 61).args[3].fill.allies == 1 and of(joins, 61).args[3].fill.enemies == 0)
assert(of(joins, 62).args[3].fill.allies == 0 and of(joins, 62).args[3].fill.enemies == 1)
assert(of(joins, 62).args[3].match.bots[1] == 1 and of(joins, 62).args[3].mode == "2v2")
for _, id in ipairs({ 61, 62, 63 }) do A.requestLeave(id) end
assert(A.friendlyOpen(61, "arena.teams", "3v3"))
v = providers.activities(61)
assert(v.friendly.canBots == false and not v.friendly.issue:find("bots"), v.friendly.issue)
ok, why = A.friendlyBots(61, true)
assert(not ok and why:find("bots"), why)
assert(A.friendlyCancel(61) and providers.activities(62).friendly == false)
-- Combat Zone (no botFill): a free-for-all friendly, the bench for the rest
assert(A.friendlyOpen(61, "arena.ffa"))
v = providers.activities(61)
assert(v.friendly.shape == "ffa" and #v.friendly.players == 3 and v.friendly.canBots == false and v.friendly.issue == nil)
-- the crew changes: a member who left is dropped from the set-up
crews[63] = nil
crew(61, 62)
A.onPartyChanged("crew-61", { 61, 62, 63 })
assert(#providers.activities(61).friendly.players == 2)
-- the page's action type
results = {}
actions["activities.lobby"](61, { type = "activities.lobby", operation = "cancel" })
assert(results[1].ok and results[1].kind == "activities.lobby" and providers.activities(61).friendly == false)
actions["activities.lobby"](61, { type = "activities.lobby", operation = "friendly", id = "arena.duel", bots = true })
assert(results[2].ok and A.friendlies[61].bots == true)
actions["activities.lobby"](61, { type = "activities.lobby", operation = "move", target = 62, team = 0 })
assert(#A.friendlies[61].teams[2] == 0 and A.friendlies[61].bench[1] == 62)
actions["activities.lobby"](61, { type = "activities.lobby", operation = "nope" })
assert(results[#results].ok == false)
A.friendlyCancel(61)
crews[61], crews[62] = nil, nil

-- ---------------------------------------------------------------------------
-- Staff bot mode stays: the provider's own fill, every entry unranked
player(71, 1)
A.setBots(true)
m = mark()
assert(A.requestJoin(71, "arena.duel", "panel"))
o = after(m, JOIN)[1].args[3]
assert(o.match == nil and o.ranked == false, "bot mode: no core queue, the provider fills a lone player")
assert(exported.activityRanked(71) == false and providers.activities(71).queued.fillInMs == nil)
assert(enter(71, "arena.duel", "op77_arena") and A.owned[71].ranked == false)
leave(71, "arena.duel", "op77_arena")
A.setBots(false)
advance(3100)
assert(exported.activityRanked(71) == nil, "no entry, no join: nil")

-- ---------------------------------------------------------------------------
-- A provider's own entry ends a held search; stale searches and matches expire
player(81, 1)
assert(A.requestJoin(81, "arena.duel", "panel"))
assert(enter(81, "arena.ffa", "op77_arena"))
assert(ticketsOf("arena.duel") == 0 and A.owned[81].ranked == true)
leave(81, "arena.ffa", "op77_arena")
advance(3100)
assert(A.requestJoin(81, "arena.duel", "panel"))
advance(15 * 60000 + 6000)
-- the upkeep thread's body (threads started at load time are not run by this test)
for _, tk in pairs(A.tickets) do
    if t - tk.at > 15 * 60000 then A.dropFromTicket(tk.lead, "expired", tk) end
end
assert(ticketsOf("arena.duel") == 0 and providers.activities(81).queued == false)

-- the whole panel state stays far below the client's 1024 values with everything open
player(91, 5); player(92, 1); player(93, 2); crew(91, 92, 93)
assert(A.requestJoin(91, "arena.teams", "panel", { mode = "3v3" }))
A.watch(91)
local size = values(providers.activities(91))
assert(size < 600, "activities state: " .. size .. " values")
A.requestLeave(91)
assert(A.friendlyOpen(91, "arena.teams", "3v3"))
size = values(providers.activities(92))
assert(size < 600, "activities state with a friendly: " .. size .. " values")

print(string.format("PASS: botFill gating, PvP bot match unranked, PvE allied fill (crew of 4 -> 2) ranked, unranked gate (bots, vsAi, provider flag, test), "
    .. "ranked queue (same/adjacent bracket first, widening at 60 s, everyone at 100 s, lone player fill offer at 120 s, crew = highest tier, "
    .. "team sizes with crews whole, crew too big), held search leave/disconnect/crew left, race gather, provider queue fill, "
    .. "friendly (balance, moves, swap, bots, mode opt-out, ffa, crew change, action), staff bot mode, expiry, state %d values", size))
