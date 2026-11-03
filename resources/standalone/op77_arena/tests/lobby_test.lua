-- server/lightrp.lua: Light RP lobby join options v2 (options.ranked, options.fill,
-- options.match) and the PvE difficulty, on the real engine (the manifest's server
-- side) with stubbed natives and recorded bots. Covers the registration (botFill,
-- pve, difficulties), PvE allies (side, count, enemy scaling), the three
-- difficulties (enemy count, health, damage, AI; allies unscaled; one difficulty
-- per instance), a friendly duel and a bot duel isolated in their own instance, a
-- crew's friendly 3v3 completed by bots, a solo practice Combat Zone in a private
-- instance, nothing ranked written when ranked == false, a ranked core match
-- recorded like the arena's own queue, the gather timeout, and staff bot mode.
-- Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test lobby_test.lua
local say = print
_G.print = function() end

local T = 7000000
local online = {}
for id = 3, 60 do online[id] = true end
local calls, events, client, handlers = {}, {}, {}, {}
local answers = { activityCheck = true, activityEnter = true, activityLeave = true, activityRegister = true, activityBots = false }
answers.activityPlayer = function(id) return { name = "Char" .. tostring(id), identifier = "license:" .. tostring(id) } end

local function stub(path)
    return setmetatable({}, {
        __index = function(t, k) local child = stub(path .. "." .. tostring(k)); rawset(t, k, child); return child end,
        __call = function() return nil end,
    })
end
_G.Open77 = stub("Open77")
Open77.time.unix = function() return 1700000000 end
Open77.time.nowMs = function() return T end
Open77.time.monotonic = function() return T end
Open77.ready.isReady = function(id) return online[tonumber(id)] == true end
Open77.players.name = function(id) return online[tonumber(id)] and ("acct" .. tostring(id)) or nil end
Open77.players.getLifeState = function() return { phase = "alive" } end
Open77.players.teleport = function() return { await = function() return true end } end
Open77.exports.callSync = function(resource, name, ...)
    calls[#calls + 1] = { name = name, args = table.pack(...) }
    local answer = answers[name]
    if type(answer) == "function" then return answer(...) end
    return answer
end
_G.json = { encode = function() return "{}" end, decode = function() return {} end }
_G.RegisterCommand = function() end
_G.AddEventHandler = function(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
_G.RegisterNetEvent = function() end
_G.TriggerEvent = function(name, ...) events[#events + 1] = { name = name, args = table.pack(...) } end
_G.TriggerClientEvent = function(name, target, ...) client[#client + 1] = { name = name, target = target, args = table.pack(...) } end
_G.CreateThread = function() end
_G.SetTimeout = function() end
_G.Wait = function() end
_G.GetCurrentResourceName = function() return "op77_arena" end
_G.GetResourceState = function() return "running" end
_G.GetPlayers = function() local out = {} for id in pairs(online) do out[#out + 1] = tostring(id) end return out end
_G.GetPlayerName = function() return nil end
_G.GetPlayerIdentifiers = function() return {} end
_G.SetPlayerRoutingBucket = function() return true end
_G.GetPlayerRoutingBucket = function() return 0 end
_G.IsPlayerAceAllowed = function() return false end
_G.SetRoutingBucketPopulationEnabled = function() end
_G.SetRoutingBucketEntityLockdownMode = function() end
_G.exports = setmetatable({}, { __index = function() return stub("exports") end, __call = function() end })

local manifest = io.open("open77.lua"):read("a")
for kind, path in manifest:gmatch('(%w+_script) "([^"]+)"') do
    if kind ~= "client_script" then
        local ok, err = pcall(dofile, path)
        assert(ok, path .. ": " .. tostring(err))
    end
end

local DM, H, L = Deathmatch, ArenaHost, LightRpArena
local Config = DeathmatchConfig
local ACT = L.activities
DM.nowMs = function() return T end
DM.tune = DM.tune or {}

-- Bots are recorded, not spawned. Free-for-all bots (add) keep their options as
-- bots.lua does (tag, team, health, damage, profile); arena bots (addToArena) are
-- handed to the arena exactly as bots.lua does (onCreated -> Arena.adoptBot).
local adds, live, nextBot = {}, {}, -1000
local arenaBots = {}
DeathmatchBots.add = function(instanceId, count, profile, options)
    adds[#adds + 1] = { instanceId = instanceId, count = count, profile = profile, options = options }
    local instance = DM.instances.registry[instanceId]
    local o = type(options) == "table" and options or {}
    for _ = 1, count do
        local id = nextBot
        nextBot = nextBot - 1
        live[id] = { participantId = id, instanceId = instanceId, tag = o.tag, team = o.team, profile = profile,
            maxHealth = 100 * (o.healthScale or 1), damageScale = o.damageScale or 1 }
        if instance then instance.actors[id] = true end
    end
    return count, nil, 0
end
DeathmatchBots.count = function(instanceId)
    local n = 0
    for _, bot in pairs(live) do if tostring(bot.instanceId) == tostring(instanceId) then n = n + 1 end end
    return n
end
DeathmatchBots.get = function(id) return live[id] end
DeathmatchBots.clear = function(instanceId)
    local removed = 0
    for id, bot in pairs(live) do
        if instanceId == nil or tostring(bot.instanceId) == tostring(instanceId) then
            live[id] = nil
            local instance = DM.instances.registry[bot.instanceId]
            if instance then instance.actors[id] = nil end
            removed = removed + 1
        end
    end
    return removed
end
DeathmatchBots.dropPending = function() return 0 end
DeathmatchBots.addToArena = function(instanceId, side, count, marks, profile, onCreated)
    arenaBots[#arenaBots + 1] = { instanceId = instanceId, side = side, count = count }
    for _ = 1, count do
        local id = nextBot
        nextBot = nextBot - 1
        if type(onCreated) == "function" then onCreated(id, side) end
    end
    return count, nil, 0
end

-- The engine's ladder write (career, round and rating rows), counted.
local rows = 0
H.engine.recordRound = function() rows = rows + 1; return true end

local function fire(name, ...) for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
local function setMode(on) fire("op77_lightrp:activity:bots", on); assert(H.botMode == on) end
local function join(id, activity, options) fire("op77_lightrp:activity:join", id, activity, options or {}); return DM.instances.of(id) end
local function results(id)
    local out = {}
    for _, e in ipairs(events) do
        if e.name == "op77_lightrp:activity:result" and e.args[1] == id then out[#out + 1] = e.args[3] end
    end
    return out
end
local function lastResult(id) local r = results(id); return r[#r] end
local function noticesTo(id)
    local out = {}
    for _, e in ipairs(client) do if e.name == "op77_lightrp:notice" and e.target == id then out[#out + 1] = e.args[1] end end
    return out
end
local function noticed(id, pattern)
    for _, notice in ipairs(noticesTo(id)) do
        if (notice.title or ""):find(pattern) or (notice.body or ""):find(pattern) then return true end
    end
    return false
end
local function enteredPayload(id)
    local payload
    for _, e in ipairs(client) do if e.name == "op77_arena:entered" and e.target == id then payload = e.args[1] end end
    return payload
end
local function addsFor(instance, filter)
    local out = {}
    for _, a in ipairs(adds) do
        if a.instanceId == instance.id and (filter == nil or filter(a)) then out[#out + 1] = a end
    end
    return out
end
local function total(list) local n = 0 for _, a in ipairs(list) do n = n + a.count end return n end
local function enemies(instance) return H.botCount(instance) - H.allyCount(instance) end
local function leaveAll(ids)
    for _, id in ipairs(ids) do T = T + 1000; DM.leave(id, "auto") end
end
local function matchJoin(ids, activity, spec, extra)
    for _, id in ipairs(ids) do
        local options = { ranked = spec.ranked ~= false and spec.friendly ~= true, match = {} }
        for k, v in pairs(spec) do options.match[k] = v end
        for _, side in ipairs({ 1, 2 }) do
            for _, member in ipairs(spec.teams and spec.teams[side] or {}) do
                if member == id then options.match.side = side end
            end
        end
        for k, v in pairs(extra or {}) do options[k] = v end
        fire("op77_lightrp:activity:join", id, activity, options)
    end
end
local SCALING = {
    standard = { enemies = 1, health = 1, damage = 1, ai = "standard" },
    hard = { enemies = 1.5, health = 1.5, damage = 1.25, ai = "veteran" },
    critical = { enemies = 2, health = 2.25, damage = 1.6, ai = "veteran" },
}
local function pveOptions(difficulty, extra)
    local options = { ranked = true, difficulty = difficulty, scaling = SCALING[difficulty] }
    for k, v in pairs(extra or {}) do options[k] = v end
    return options
end

-- ── registration: botFill on all five, PvE declares its difficulties ──
do
    calls = {}
    assert(H.register() == 5)
    local defs = {}
    for _, call in ipairs(calls) do
        if call.name == "activityRegister" then defs[call.args[1].id] = call.args[1] end
    end
    for _, key in ipairs({ "ffa", "blade", "duel", "teams", "pve" }) do
        assert(defs[ACT[key].id] and defs[ACT[key].id].botFill == true, key .. " declares botFill")
    end
    local pve = defs[ACT.pve.id]
    assert(pve.pve == true and pve.difficulties[1] == "standard" and pve.difficulties[2] == "hard"
        and pve.difficulties[3] == "critical" and #pve.difficulties == 3)
    assert(defs[ACT.ffa.id].pve == nil and defs[ACT.ffa.id].difficulties == nil, "PvP declares no difficulty")
    say("PASS registration (botFill, pve, difficulties)")
end

-- ── PvE allies: a crew of 4 in a 6-seat PvE gets 2 allied bots on its side ──
local pve
do
    local crew = { id = "pc1", leader = 3, members = { 3, 4, 5, 6 } }
    for _, id in ipairs(crew.members) do
        T = T + 1000
        pve = join(id, ACT.pve.id, pveOptions("standard", { squad = crew, fill = { allies = 2, enemies = 0 } }))
    end
    assert(pve and pve.ruleset == "pve" and #DM.instances.humans(pve) == 4)
    assert(H.allyCount(pve) == 2, "2 allies: the free player seats the crew asked for, once")
    local allyAdds = addsFor(pve, function(a) return a.options and a.options.tag == "ally" end)
    assert(total(allyAdds) == 2, "allies asked for once per instance, never per player")
    for _, a in ipairs(allyAdds) do
        assert(a.options.team == 1 and a.options.healthScale == nil and a.options.damageScale == nil, "allies unscaled, team 1")
        assert(a.profile == L.pve.allyProfile)
    end
    -- Sides: the crew and its allies one side, the gang bots the other.
    local ally, enemy
    for id in pairs(pve.actors) do
        if live[id] and live[id].tag == "ally" then ally = id elseif live[id] then enemy = id end
    end
    assert(DM.arena.sideOf(3) == 1 and DM.arena.sideOf(ally) == 1 and DM.arena.sideOf(enemy) == 2)
    -- Enemies scale on people + allies: 6 players -> botsMax (10), capped by the 16 bodies.
    local P = L.pve
    assert(enemies(pve) == math.min(P.botsMax, P.botsFirst + P.botsPerPlayer * 5), "enemy scaling counts the allies")
    assert(H.botCount(pve) + #DM.instances.humans(pve) <= pve.capacity)
    -- A PvE result with allies stays a normal (ranked) PvE result.
    events = {}
    H.reportPve(pve, "time_limit")
    local r = lastResult(3)
    assert(r and r.unranked == nil and r.test == nil and r.stats.allies == 2 and r.stats.bots == enemies(pve))
    leaveAll(crew.members)
    assert(H.botCount(pve) == 0, "the bots go with the last player")
    -- Solo: with one ally the enemies face 2 players, without allies 1.
    T = T + 1000
    join(40, ACT.pve.id, pveOptions("standard", { fill = { allies = 1, enemies = 0 } }))
    assert(H.allyCount(pve) == 1 and enemies(pve) == P.botsFirst + P.botsPerPlayer)
    leaveAll({ 40 })
    say("PASS PvE allies (crew of 4 -> 2 allies on the players' side, enemy count on people + allies)")
end

-- ── PvE difficulty: the enemy bots scale, the allies do not, one per instance ──
do
    local expect = {
        standard = { enemies = 3, health = 1, damage = 1, profile = "standard" },
        hard = { enemies = 5, health = 1.5, damage = 1.25, profile = "veteran" },
        critical = { enemies = 6, health = 2.25, damage = 1.6, profile = "veteran" },
    }
    local nextId = 7
    for _, difficulty in ipairs({ "standard", "hard", "critical" }) do
        local id = nextId
        nextId = nextId + 1
        local before = #adds
        calls = {}
        T = T + 1000
        local instance = join(id, ACT.pve.id, pveOptions(difficulty))
        assert(instance == pve and instance.pveLevel.id == difficulty)
        local e = expect[difficulty]
        assert(enemies(instance) == e.enemies, difficulty .. ": enemy count " .. tostring(enemies(instance)))
        for index = before + 1, #adds do
            local a = adds[index]
            assert(a.options.healthScale == e.health and a.options.damageScale == e.damage and a.profile == e.profile, difficulty)
            assert(a.options.team == 2 and a.options.tag == nil)
        end
        for botId in pairs(instance.actors) do
            if live[botId] then assert(live[botId].maxHealth == 100 * e.health) end
        end
        local entered
        for _, call in ipairs(calls) do if call.name == "activityEnter" then entered = call.args[3] end end
        assert(entered and entered.difficulty == difficulty, "activityEnter hears the difficulty played")
        leaveAll({ id })
    end
    -- Allies at Hard: plain and standard; the enemies scale on 2 players.
    T = T + 1000
    local before = #adds
    join(10, ACT.pve.id, pveOptions("hard", { fill = { allies = 1, enemies = 0 } }))
    assert(H.allyCount(pve) == 1 and enemies(pve) == math.floor((L.pve.botsFirst + L.pve.botsPerPlayer) * 1.5 + 0.5))
    for index = before + 1, #adds do
        local a = adds[index]
        if a.options.tag == "ally" then
            assert(a.options.healthScale == nil and a.options.damageScale == nil and a.profile == L.pve.allyProfile, "ally unscaled")
        else
            assert(a.options.healthScale == 1.5 and a.profile == "veteran")
        end
    end
    -- One difficulty per instance: a Standard player cannot join a Hard round.
    T = T + 1000
    assert(join(11, ACT.pve.id, pveOptions("standard")) == nil, "refused: another difficulty is running")
    assert(noticed(11, "Hard"), "told which difficulty runs")
    T = T + 1000
    assert(join(11, ACT.pve.id, pveOptions("hard")) == pve, "the same difficulty joins")
    leaveAll({ 10, 11 })
    -- Empty again: the next player's difficulty is the instance's.
    T = T + 1000
    join(12, ACT.pve.id, pveOptions("critical"))
    assert(pve.pveLevel.id == "critical")
    leaveAll({ 12 })
    say("PASS PvE difficulty (standard 3 / hard 5 / critical 6 enemies, health x1/x1.5/x2.25, damage x1/x1.25/x1.6, AI standard/veteran/veteran, allies unscaled)")
end

-- ── a friendly duel: its own instance, its sides, nobody else, nothing ranked ──
local duelStranger = 13
do
    T = T + 1000
    assert(H.queueDuel(duelStranger) == true and #H.duelQueue == 1, "a stranger waits in the duel queue")
    client, events = {}, {}
    local before = #arenaBots
    T = T + 1000
    matchJoin({ 14, 15 }, ACT.duel.id, { id = "match:d1", friendly = true, ranked = false, players = { 14, 15 },
        teams = { { 14 }, { 15 } } })
    local instance = DM.instances.of(14)
    assert(instance and instance == DM.instances.of(15) and instance.format == "1v1", "one instance for the two")
    assert(instance.match.sides[14] == 1 and instance.match.sides[15] == 2, "on their sides")
    assert(DM.instances.of(duelStranger) == nil and H.duelQueued(duelStranger), "the stranger is untouched")
    assert(#arenaBots == before, "no bot")
    assert(instance.lobby and instance.lobby.unranked == true and instance.lobby.friendly == true)
    local payload = enteredPayload(14)
    assert(payload and payload.unranked == true and payload.friendly == true, "the HUD hears FRIENDLY")
    assert(noticed(14, "FRIENDLY MATCH"))
    -- Nothing ranked: no ladder rows, no reputation, no duel repeat-reward count.
    local written, why = DM.ranked.recordRound(instance, {})
    assert(written == false and why == "unranked" and rows == 0)
    instance.match.state = "resolved"
    instance.match.result = { reason = "best_of", winnerSide = 1, wins = { 2, 0 } }
    assert(H.reportMatch(instance) == 2)
    local r14, r15 = lastResult(14), lastResult(15)
    assert(r14.unranked == true and r14.reputation == 0 and r14.won == true and r14.test == nil)
    assert(r15.unranked == true and r15.reputation == 0)
    assert(next(H.duelPairs) == nil, "no repeat-reward bookkeeping for a friendly")
    say("PASS friendly duel (isolated, sides, unranked, no rows)")
end

-- ── a solo duel against a bot: { { a }, {} }, bots { 0, 1 } ──
do
    arenaBots = {}
    T = T + 1000
    matchJoin({ 16 }, ACT.duel.id, { id = "match:d2", friendly = false, ranked = false, players = { 16 },
        teams = { { 16 }, {} }, bots = { 0, 1 } }, { fill = { allies = 0, enemies = 1 } })
    local instance = DM.instances.of(16)
    assert(instance and instance.format == "1v1" and instance.match.sides[16] == 1)
    assert(#arenaBots == 1 and arenaBots[1].side == 2 and arenaBots[1].count == 1, "one bot on the other side")
    assert(H.hadBots(instance) and H.unrankedInstance(instance))
    local written, why = DM.ranked.recordRound(instance, {})
    assert(written == false and why == "bots" and rows == 0)
    say("PASS bot duel (one bot, side 2, unranked)")
end

-- ── a crew of 2, friendly 3v3 split { { a }, { b } }, bots { 2, 2 } ──
do
    arenaBots = {}
    T = T + 1000
    matchJoin({ 17, 18 }, ACT.teams.id, { id = "match:t1", friendly = true, ranked = false, format = "3v3",
        players = { 17, 18 }, teams = { { 17 }, { 18 } }, bots = { 2, 2 } }, { mode = "3v3" })
    local instance = DM.instances.of(17)
    assert(instance and instance == DM.instances.of(18) and instance.format == "3v3")
    assert(instance.match.sides[17] == 1 and instance.match.sides[18] == 2)
    local bySide = {}
    for _, call in ipairs(arenaBots) do bySide[call.side] = (bySide[call.side] or 0) + call.count end
    assert(bySide[1] == 2 and bySide[2] == 2, "two bots each side")
    assert(#instance.match.roster[1] == 3 and #instance.match.roster[2] == 3)
    assert(H.unrankedInstance(instance))
    say("PASS friendly 3v3 with bots (sides and bot counts)")
end

-- ── solo practice Combat Zone: a private instance, never the public one ──
local public, private
do
    local before = #adds
    T = T + 1000
    public = join(19, ACT.ffa.id, { ranked = true })
    assert(public and public.private == nil and #adds == before, "a stranger in the public Combat Zone, no bots")
    T = T + 1000
    private = join(20, ACT.ffa.id, { ranked = false, fill = { allies = 0, enemies = 5 },
        match = { id = "match:f1", friendly = false, ranked = false, players = { 20 } } })
    assert(private and private ~= public and private.private == "match:f1", "a private instance")
    assert(private.bucket ~= public.bucket)
    assert(H.botCount(private) == 5 and total(addsFor(private)) == 5, "5 AI opponents")
    assert(#addsFor(public) == 0, "the public instance gets none")
    T = T + 1000
    assert(join(21, ACT.ffa.id, { ranked = true }) == public, "the next stranger goes to the public one")
    assert(#DM.instances.humans(private) == 1)
    assert(H.statusOf("ffa").players == 2, "the panel counts the public Combat Zone")
    -- Nothing ranked for the practice.
    local written, why = DM.ranked.recordRound(private, {})
    assert(written == false and rows == 0, tostring(why))
    events = {}
    H.reportRound(private, "time_limit")
    local r = lastResult(20)
    assert(r and r.unranked == true and r.test == true and r.reputation == 0)
    -- A bot practice asked without a match (options.fill alone): private too.
    T = T + 1000
    local blade = join(22, ACT.blade.id, { ranked = false, fill = { allies = 0, enemies = 3 } })
    assert(blade and blade.private ~= nil and blade.ruleset == "blade" and H.botCount(blade) == 3)
    -- Staff bot mode is unchanged: the public one fills, the private ones keep what was asked.
    setMode(true)
    assert(H.botCount(public) == L.bots.fillTarget - 2, "bot mode fills the public Combat Zone as before")
    assert(H.botCount(private) == 5 and H.botCount(blade) == 3, "bot mode leaves the private instances alone")
    setMode(false)
    say("PASS solo practice Combat Zone (private instance, 5 bots, public untouched, unranked; bot mode unchanged)")
end

-- ── a ranked core match: isolated, its sides, recorded like the arena's own queue ──
do
    T = T + 1000
    assert(DM.arena.enqueue(23, "2v2") ~= nil, "a stranger waits in the 2v2 queue")
    arenaBots = {}
    rows = 0
    events, client = {}, {}
    T = T + 1000
    matchJoin({ 24, 25, 26, 27 }, ACT.teams.id, { id = "match:r1", friendly = false, ranked = true, format = "2v2",
        players = { 24, 25, 26, 27 }, teams = { { 24, 25 }, { 26, 27 } } }, { mode = "2v2" })
    local instance = DM.instances.of(24)
    assert(instance and instance.format == "2v2", "formed")
    for _, id in ipairs({ 25, 26, 27 }) do assert(DM.instances.of(id) == instance) end
    assert(instance.match.sides[24] == 1 and instance.match.sides[25] == 1 and instance.match.sides[26] == 2 and instance.match.sides[27] == 2)
    assert(DM.instances.of(23) == nil and DM.arena.queuePosition(23) ~= nil, "the stranger still waits")
    assert(#arenaBots == 0 and not H.hadBots(instance))
    assert(instance.lobby.unranked == false and not H.unrankedInstance(instance))
    assert(enteredPayload(24).unranked == nil and not noticed(24, "UNRANKED"))
    assert(DM.ranked.recordRound(instance, {}) == true and rows == 1, "career, round and rating rows written")
    instance.match.state = "resolved"
    instance.match.result = { reason = "best_of", winnerSide = 2, wins = { 0, 2 } }
    H.reportMatch(instance)
    assert(lastResult(26).won == true and lastResult(26).reputation == L.reputation.teams.win and lastResult(26).unranked == nil)
    assert(lastResult(24).won == false and lastResult(24).reputation == L.reputation.teams.loss and lastResult(24).test == nil)
    -- A ranked duel: the repeat-reward bookkeeping runs as for /duel.
    T = T + 1000
    matchJoin({ 28, 29 }, ACT.duel.id, { id = "match:r2", friendly = false, ranked = true, players = { 28, 29 },
        teams = { { 28 }, { 29 } } })
    local duel = DM.instances.of(28)
    assert(duel and duel == DM.instances.of(29) and duel.format == "1v1")
    duel.match.state = "resolved"
    duel.match.result = { reason = "best_of", winnerSide = 1, wins = { 2, 1 } }
    H.reportMatch(duel)
    assert(lastResult(28).reputation == L.reputation.duel.win and lastResult(28).unranked == nil)
    local pairs_ = 0
    for _ in pairs(H.duelPairs) do pairs_ = pairs_ + 1 end
    assert(pairs_ == 1, "counted toward the daily repeat rewards")
    say("PASS ranked core match (isolated, sides, rows written, reputation)")
end

-- ── gather: who came plays after gatherMs, a bot takes the missing seat ──
do
    arenaBots = {}
    T = T + 1000
    matchJoin({ 30, 31, 32 }, ACT.teams.id, { id = "match:g1", friendly = false, ranked = true, format = "2v2",
        players = { 30, 31, 32, 33 }, teams = { { 30, 31 }, { 32, 33 } } }, { mode = "2v2" })
    assert(DM.instances.of(30) == nil and DM.arena.queuePosition(30) == nil, "gathering, in no queue")
    assert(noticed(30, "Waiting"))
    T = T + L.lobby.gatherMs
    H.tick(T)
    local instance = DM.instances.of(30)
    assert(instance and instance.format == "2v2" and DM.instances.of(32) == instance)
    assert(#arenaBots == 1 and arenaBots[1].side == 2 and arenaBots[1].count == 1, "a bot in the missing seat")
    assert(H.unrankedInstance(instance), "completed with a bot: unranked")
    T = T + 1000
    matchJoin({ 33 }, ACT.teams.id, { id = "match:g1", friendly = false, ranked = true, format = "2v2",
        players = { 30, 31, 32, 33 }, teams = { { 30, 31 }, { 32, 33 } } }, { mode = "2v2" })
    assert(DM.instances.of(33) == nil and noticed(33, "already started"), "late: refused")
    -- Not one of the match: refused.
    T = T + 1000
    matchJoin({ 34 }, ACT.teams.id, { id = "match:g1", players = { 30, 31, 32, 33 }, teams = { { 30, 31 }, { 32, 33 } } })
    assert(DM.instances.of(34) == nil)
    say("PASS gather timeout (missing seat -> bot, late join refused)")
end

-- ── the arena's own queues keep working for joins without options.match ──
do
    -- Every PvP instance holds one of the resource's 8 combat scopes (server/pvp.lua):
    -- the private instances and the matches above use them all. Two matches end.
    assert(ArenaPvp.slotsInUse() == ArenaPvp.budget(), "the scope budget is the real limit")
    T = T + 1000
    assert(join(36, ACT.ffa.id, { ranked = false, fill = { enemies = 2 },
        match = { id = "match:f2", friendly = false, ranked = false, players = { 36 } } }) == nil, "no private instance beyond it")
    assert(noticed(36, "No private arena"))
    leaveAll({ 14, 15, 17, 18 })
    T = T + 1000
    assert(H.queueDuel(35) == true)
    local instance = DM.instances.of(35)
    assert(instance and instance == DM.instances.of(duelStranger) and instance.lobby == nil, "the random duel queue pairs as before")
    local written = DM.ranked.recordRound(instance, {})
    assert(written == true, "a normal duel is recorded")
    say("PASS own queues unchanged")
end

say("PASS: op77_arena lobby (registration, PvE allies, PvE difficulty, friendly duel, bot duel, friendly 3v3, private practice, unranked, ranked core match, gather, bot mode, own queues)")
