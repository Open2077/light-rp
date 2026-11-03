-- The real engine (the manifest's server side) with the adapter on top: the engine
-- hooks this edition adds, driven end to end with stubbed natives and a recorded
-- DeathmatchBots.addToArena. Covers Arena.planRoster in Arena.tryForm (crews on one
-- side, bots completing each side, no bot-filled match without bot mode, a bad plan
-- ignored), a duel against a bot through the engine's 1v1 queue, and the PvE damage
-- gate in main.lua.
-- Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test bots_engine_test.lua
local say = print
_G.print = function() end

local T = 5000000
local online = {}
for id = 3, 20 do online[id] = true end
local answers = { activityCheck = true, activityEnter = true, activityLeave = true, activityRegister = true, activityBots = false }
local onDamage

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
Open77.combat.onDamage = function(fn) onDamage = fn end
Open77.exports.callSync = function(resource, name, ...)
    local answer = answers[name]
    if type(answer) == "function" then return answer(...) end
    return answer
end
_G.json = { encode = function() return "{}" end, decode = function() return {} end }
_G.RegisterCommand = function() end
local handlers = {}
_G.AddEventHandler = function(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
_G.RegisterNetEvent = function() end
_G.TriggerEvent = function() end
_G.TriggerClientEvent = function() end
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
DM.nowMs = function() return T end
DM.tune = DM.tune or {}

-- Bodies are recorded, not spawned: one negative participant per bot, handed to the
-- arena exactly as bots.lua does (onCreated -> Arena.adoptBot).
local arenaBots, nextBot = {}, -100
DeathmatchBots.addToArena = function(instanceId, side, count, marks, profile, onCreated)
    arenaBots[#arenaBots + 1] = { instanceId = instanceId, side = side, count = count }
    for _ = 1, count do
        local id = nextBot
        nextBot = nextBot - 1
        if type(onCreated) == "function" then onCreated(id, side) end
    end
    return count, nil, 0
end

local function setMode(on) for _, fn in ipairs(handlers["op77_lightrp:activity:bots"] or {}) do fn(on) end end
local function enqueue(id, format) T = T + 1000; return DM.arena.enqueue(id, format) end
local function crew(key, list) for _, id in ipairs(list) do H.noteSquad(id, { id = key, leader = list[1], members = list }) end end
local function match(id) local instance = DM.instances.of(id); return instance, instance and instance.match end

-- ── outside bot mode: a full 2v2 forms, the crew on one side ──
do
    setMode(false)
    crew("A", { 3, 4 })
    enqueue(5, "2v2")
    enqueue(3, "2v2")
    assert(DM.instances.of(3) == nil, "the crew is still arriving")
    enqueue(4, "2v2")
    assert(DM.instances.of(3) == nil, "three people do not make a 2v2 without bot mode")
    enqueue(6, "2v2")
    local instance, m = match(3)
    assert(instance and instance.format == "2v2", "four people: formed")
    assert(m.sides[3] == m.sides[4], "the crew shares a side")
    assert(m.sides[5] == m.sides[6] and m.sides[5] ~= m.sides[3], "the others take the other side")
    assert(m.botFill == nil and #arenaBots == 0, "no bot")
    say("PASS full roster, crew together")
end

-- ── bot mode: a crew alone forms on one side, bots complete the other ──
do
    setMode(true)
    crew("B", { 7, 8 })
    enqueue(7, "2v2")
    assert(DM.instances.of(7) == nil, "held for its second member")
    enqueue(8, "2v2")
    local instance, m = match(7)
    assert(instance and m.sides[7] == m.sides[8], "the crew shares a side")
    local crewSide = m.sides[7]
    assert(#arenaBots == 1 and arenaBots[1].side ~= crewSide and arenaBots[1].count == 2, "two bots on the other side")
    assert(#m.roster[3 - crewSide] == 2, "adopted on the roster")
    assert(H.hadBots(instance), "practice")
    -- A solo player in a 3v3: two bots with them, three against.
    arenaBots = {}
    enqueue(9, "3v3")
    instance, m = match(9)
    assert(instance and instance.format == "3v3")
    local bySide = {}
    for _, call in ipairs(arenaBots) do bySide[call.side] = call.count end
    assert(bySide[m.sides[9]] == 2 and bySide[3 - m.sides[9]] == 3, "each side completed to three")
    say("PASS bot mode team fill")
end

-- ── bot mode off: an entry that accepts bots still forms nothing short ──
do
    setMode(false)
    arenaBots = {}
    T = T + 1000
    H.engine.enqueue(10, "2v2", true) -- consent at the engine level, bot mode off
    assert(DM.instances.of(10) == nil and DM.arena.queuePosition(10) ~= nil, "no bot-filled match without bot mode")
    assert(#arenaBots == 0)
    DM.leave(10, "queue")
    say("PASS no bot match without bot mode")
end

-- ── a plan that breaks the rules is ignored (stock arrival order) ──
do
    local plan = DM.arena.planRoster
    DM.arena.planRoster = function(format, queue)
        if format ~= "2v2" then return nil end
        local roster, sides = {}, {}
        for _, entry in ipairs(queue) do roster[#roster + 1] = entry.playerId; sides[entry.playerId] = 1 end
        return { roster = roster, sides = sides } -- everyone on side 1: invalid
    end
    for _, id in ipairs({ 11, 12, 13, 14 }) do enqueue(id, "2v2") end
    local instance, m = match(11)
    assert(instance, "formed by the stock rule")
    local count = { 0, 0 }
    for _, id in ipairs({ 11, 12, 13, 14 }) do count[m.sides[id]] = count[m.sides[id]] + 1 end
    assert(count[1] == 2 and count[2] == 2, "never an overfilled side")
    DM.arena.planRoster = plan
    say("PASS bad plan ignored")
end

-- ── a duel against a bot through the engine's 1v1 queue ──
do
    setMode(true)
    arenaBots = {}
    T = T + 1000
    local ok = H.duelBot(15)
    local instance, m = match(15)
    assert(ok and instance and instance.format == "1v1", "formed by Arena.tryForm")
    assert(#arenaBots == 1 and arenaBots[1].count == 1 and arenaBots[1].side ~= m.sides[15])
    setMode(false)
    say("PASS duel vs bot (engine)")
end

-- ── PvE: the server damage gate refuses player against player ──
do
    assert(type(onDamage) == "function")
    local accepts, reached = DM.loadout.accepts, 0
    DM.loadout.accepts = function(...) reached = reached + 1; return false, "test" end
    local pve = DM.instances.assignFFA(16, "pve")
    DM.instances.assignFFA(17, "pve")
    assert(pve and pve.ruleset == "pve" and DM.instances.of(17) == pve)
    pve.round = { state = "active" }
    assert(DM.arena.sideOf(16) == 1 and DM.arena.sideOf(17) == 1)
    assert(onDamage({ victim = 16, attacker = 17, weaponTdbId = "x" }) == false)
    assert(reached == 0, "refused at the side gate, before the weapon check")
    -- The same shot in the Combat Zone goes on to the weapon check.
    local cz = DM.instances.assignFFA(18, "standard")
    DM.instances.assignFFA(19, "standard")
    cz.round = { state = "active" }
    onDamage({ victim = 18, attacker = 19, weaponTdbId = "x" })
    assert(reached == 1, "free-for-all: no side gate")
    DM.loadout.accepts = accepts
    say("PASS PvE damage gate")
end

say("PASS: op77_arena bots engine (crews in Arena.tryForm, bot fill per side, no bot match when off, bad plan, duel vs bot, PvE gate)")
