-- Street Race vs AI played at Light RP's PvE difficulty (options.difficulty + options.scaling):
-- `enemies` scales the AI drivers' share of the grid, `damage` their top speed, `ai` their
-- driving profile (cornering line, checkpoint margin). One difficulty per race: a crew's
-- first join sets it. No pick: the race plays as configured.
local H = dofile("tests/harness.lua")
H.installBotNatives()
local LOBBY = { x = -756.581, y = 777.257, z = 22.454, bucket = 0 }
for id = 1, 6 do H.addPlayer(id, "P" .. id, { x = LOBBY.x + id * 3, y = LOBBY.y, z = LOBBY.z, bucket = 0 }) end
math.randomseed(43)
H.load(H.SERVER)
local E, Config = RaceEngine, RaceConfig
local pve = RaceActivity.byKey.pve
Config.bots.stuckSeconds = 600

-- What op77_lightrp hands with each pick (server/config/activities.lua pve.difficulties).
local SCALING = {
    standard = { enemies = 1, health = 1, damage = 1, ai = "standard" },
    hard = { enemies = 1.5, health = 1.5, damage = 1.25, ai = "veteran" },
    critical = { enemies = 2, health = 2.25, damage = 1.6, ai = "veteran" },
}
local function pick(id, squad)
    local scaling = {}
    for key, value in pairs(SCALING[id]) do scaling[key] = value end
    return { course = "shion-sprint", difficulty = id, scaling = scaling, ranked = true, squad = squad }
end
local function racer(id) return E.racers[id] end
local function instance(id) return E.instanceOf(id) end
local function join(id, options) H.fire("op77_lightrp:activity:join", id, "race.pve", options) end
local function near(a, b) return math.abs(a - b) < 1e-6 end
local function clear()
    for id = 1, 6 do
        if racer(id) then H.fire("op77_lightrp:activity:leaveRequest", id, "race.pve") end
    end
    local guard = 0
    while (H.count(E.racers) > 0 or H.count(E.instances) > 0) and guard < 200 do H.advance(250); guard = guard + 1 end
    H.eq(H.count(E.instances), 0, "closed")
    H.eq(H.count(H.npcs), 0); H.eq(H.count(H.vehicles), 0)
    H.advance(400)
end
-- One race for these players at this pick: what its AI drivers were given, read at GO.
local function measure(options, players)
    players = players or { 1 }
    for _, id in ipairs(players) do join(id, options(id)) end
    local inst = instance(players[1])
    H.ok(inst and inst.mode == "pve", "started")
    for _, id in ipairs(players) do H.eq(instance(id), inst, "together") end
    H.advance(Config.engine.loadSeconds.pve * 1000 + Config.engine.countdownSeconds * 1000 + 1000)
    H.eq(inst.phase, "active")
    local m = { bots = #inst.bots, difficulty = inst.difficulty, bonus = RaceBots.radiusBonus(inst) }
    for index, bot in ipairs(inst.bots) do
        local ai = H.ai[bot.vehicleId]
        H.ok(ai and ai.route, "driving")
        if index == 1 then
            m.speed, m.behavior, m.routeSpeed, m.arrival = ai.speed, ai.behavior, ai.route.speed, ai.route.arrivalRadius
        else
            H.ok(near(ai.speed, m.speed) and near(ai.route.arrivalRadius, m.arrival), "every AI driver alike")
        end
    end
    m.state = H.lastClient("op77_race:state", players[1]).args[1]
    clear()
    return m
end

local capacity
H.test("the race vs AI declares PvE and its three difficulties; the course stays the join choice", function()
    local def = H.core.registered["race.pve"]
    H.eq(def.pve, true)
    H.eq(table.concat(def.difficulties, ","), "standard,hard,critical")
    H.eq(def.modeKey, "course")
    H.eq(def.botFill, nil)
    capacity = RaceCourses.capacity(RaceCourses.get("shion-sprint"), pve.maxPlayers)
    H.eq(capacity, 8, "an eight-slot grid")
end)

local solo = {}
H.test("solo: each difficulty puts more or faster AI drivers on the grid", function()
    for _, id in ipairs({ "standard", "hard", "critical" }) do
        solo[id] = measure(function() return pick(id) end)
        H.eq(solo[id].difficulty, id)
    end
    local s, h, c = solo.standard, solo.hard, solo.critical
    -- enemies: (fillTo 6 - 1 player) x 1 / 1.5 / 2, within the 8-slot grid
    H.eq(s.bots, 5); H.eq(h.bots, 7); H.eq(c.bots, 7)
    -- damage: top speed 30 x (1 + (damage - 1) x 0.8)
    H.ok(near(s.speed, 30.0), "standard pace " .. tostring(s.speed))
    H.ok(near(h.speed, 36.0), "hard pace " .. tostring(h.speed))
    H.ok(near(c.speed, 44.4), "critical pace " .. tostring(c.speed))
    for _, m in ipairs({ s, h, c }) do H.ok(near(m.routeSpeed, m.speed), "the route asks the same ceiling") end
    H.ok(s.speed < h.speed and h.speed < c.speed, "strictly faster")
    -- ai: standard line and margin, veteran wider
    H.ok(near(s.arrival, 8.0) and near(h.arrival, 12.0) and near(c.arrival, 12.0), "cornering line")
    H.ok(near(s.bonus, 0.0) and near(h.bonus, 1.5) and near(c.bonus, 1.5), "checkpoint margin")
    H.eq(s.behavior, "aggressive"); H.eq(c.behavior, "aggressive")
    -- said on the grid notice and in the HUD
    H.ok(H.noticeFor(1, "Hard: 7 AI drivers on the grid"))
    H.ok(H.noticeFor(1, "Critical: 7 AI drivers on the grid"))
    H.eq(c.state.difficulty, "critical")
end)

H.test("no pick plays as configured, the same as Standard", function()
    local m = measure(function() return { course = "shion-sprint" } end)
    H.eq(m.difficulty, nil)
    H.eq(m.bots, solo.standard.bots)
    H.ok(near(m.speed, Config.bots.car.speed) and near(m.arrival, Config.bots.car.arrivalRadius))
    H.ok(near(m.bonus, Config.bots.checkpointRadiusBonus))
end)

H.test("a crew of four: the AI share scales with enemies (2 / 3 / 4)", function()
    local counts = {}
    for _, id in ipairs({ "standard", "hard", "critical" }) do
        local squad = { id = "crew-" .. id, leader = 1, members = { 1, 2, 3, 4 } }
        counts[id] = measure(function() return pick(id, squad) end, { 1, 2, 3, 4 }).bots
    end
    H.eq(counts.standard, 2); H.eq(counts.hard, 3); H.eq(counts.critical, 4)
end)

H.test("one difficulty per race: a crew plays the first pick its joins carry, never a mix", function()
    local squad = { id = "crew-mixed", leader = 2, members = { 1, 2 } }
    local m = measure(function(id) return pick(id == 1 and "hard" or "critical", squad) end, { 1, 2 })
    H.eq(m.difficulty, "hard", "the first join's")
    H.ok(near(m.speed, 36.0), "every AI driver at the hard pace")
    -- (fillTo 6 - 2 players) x 1.5 = 6 AI drivers
    H.eq(m.bots, 6)
end)

H.test("the difficulty changes nothing in the result: a real PvE result", function()
    join(5, pick("critical"))
    local inst = instance(5)
    H.advance(Config.engine.loadSeconds.pve * 1000 + Config.engine.countdownSeconds * 1000 + 1000)
    H.fire("op77_lightrp:activity:leaveRequest", 5, "race.pve")
    local result
    for _, event in ipairs(H.eventsNamed("op77_lightrp:activity:result")) do
        if event.args[1] == 5 then result = event.args[3] end
    end
    H.ok(result and inst.difficulty == "critical", "a result at the forfeit")
    H.eq(result.test, nil); H.eq(result.unranked, nil); H.eq(result.stats.vsAi, true)
    clear()
end)

H.done("pve_difficulty_test")
