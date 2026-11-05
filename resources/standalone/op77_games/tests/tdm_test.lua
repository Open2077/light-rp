-- Team Deathmatch: rules lifted from the source mode, on the engine.
-- Run: lua tests/tdm_test.lua
local H = dofile("tests/harness.lua")
H.loadServer()
H.advance(200)
local E, T = GamesEngine, GamesTdm
local AJAX = H.hash("Items.Preset_Ajax_Default")

local nextId = 0
local function players(n)
    local ids = {}
    for _ = 1, n do
        nextId = nextId + 1
        H.addPlayer(nextId)
        ids[#ids + 1] = nextId
    end
    return ids
end

-- Two even teams, running. teams[1] are a's, teams[2] are b's.
local function live(n, map)
    local ids = players(n)
    local teams = { {}, {} }
    for index, id in ipairs(ids) do table.insert(teams[index % 2 == 1 and 1 or 2], id) end
    H.matchJoin("games.tdm", ids, { teams = teams, map = map })
    return H.untilPhase(ids[1], "running"), teams[1], teams[2]
end

local function kill(match, victim, killer)
    H.eq(H.hit(killer, victim, AJAX), true, "the shot lands")
    H.die(victim, killer)
    H.settle(50)
    return match
end

local function revive(id)
    H.settle(4600)
    H.ok(H.players[id].life == "alive", "back")
    H.settle(2100) -- past the protection
end

local function lastResults()
    local byId = {}
    for _, e in ipairs(H.eventsNamed("op77_lightrp:activity:result")) do byId[e.args[1]] = e.args[3] end
    return byId
end

H.test("the limit scales with the room", function()
    H.eq(T.limitFor(2), 30)
    H.eq(T.limitFor(6), 30)
    H.eq(T.limitFor(7), 35)
    H.eq(T.limitFor(10), 50)
    H.eq(T.limitFor(16), 50, "capped")
end)

H.test("the spawns split in two sides, the farthest pair apart, on both maps", function()
    for _, map in ipairs(GamesMaps.tdm) do
        local sides = T.sides(map.spawns)
        H.ok(#sides[1] > 0 and #sides[2] > 0, map.id .. ": two sides")
        H.eq(#sides[1] + #sides[2], #map.spawns, "every spawn on one side")
    end
    local a = { x = 0, y = 0, z = 0 }
    local b = { x = 100, y = 0, z = 0 }
    local c = { x = 90, y = 0, z = 0 }
    local sides = T.sides({ a, c, b })
    H.eq(sides[1][1], a)
    H.eq(#sides[2], 2, "c joins the nearer anchor")
end)

H.test("each team starts on its own side; the loadout is the mode's", function()
    local match, a, b = live(4, "grand-imperial-mall")
    local sides = T.sides(match.map.spawns)
    local function near(list, id)
        local p = H.players[id]
        for _, spawn in ipairs(list) do
            if E.flat(p, spawn) <= 2.01 then return true end
        end
        return false
    end
    for _, id in ipairs(a) do H.ok(near(sides[1], id), "team A on its side") end
    for _, id in ipairs(b) do H.ok(near(sides[2], id), "team B on its side") end
    H.eq(H.weapons[a[1]][1], "Items.Preset_Ajax_Default", "slot 1 in hand")
    H.eq(H.weapons[a[1]][2], "Items.Preset_Lexington_Default", "slot 2")
    local reserve
    for _, entry in ipairs(H.weaponLog) do
        if entry.operation == "setAmmo" and entry.playerId == a[1] and entry.slot == 1 then reserve = entry.amounts end
    end
    H.eq(reserve.reserve, 240, "reserve")
    H.eq(reserve.magazine, nil, "never a magazine")
    H.eq(H.core.registered["games.tdm"].caps.rpWeapons, false, "RP weapons aside")
    E.cancel(match)
    H.settle(500)
end)

H.test("a kill scores one for the killer's team, the HUD shows it", function()
    local match, a, b = live(2)
    kill(match, b[1], a[1])
    H.eq(match.tdm.score[1], 1)
    H.eq(match.tdm.score[2], 0)
    H.settle(300)
    local view = H.lastClient("op77_games:hud", a[1]).args[1]
    H.eq(view.phase, "running")
    H.eq(view.teams[1].score, 1)
    H.eq(view.teams[1].self, true)
    H.eq(view.teams[2].self, false)
    H.ok(view.timer.remainingMs > 0, "the clock")
    H.eq(view.objective, "First team to 30 kills")
    E.cancel(match)
    H.settle(500)
end)

H.test("a death with no killer scores nothing", function()
    local match, a = live(2)
    H.die(a[1])
    H.eq(match.tdm.score[1] + match.tdm.score[2], 0)
    E.cancel(match)
    H.settle(500)
end)

H.test("first to the limit wins; a later kill never takes it", function()
    local match, a, b = live(2)
    match.tdm.limit = 2
    kill(match, b[1], a[1])
    revive(b[1])
    kill(match, b[1], a[1])
    H.eq(match.phase, "ended", "the limit")
    H.eq(match.reason, "limit")
    H.die(a[1], b[1])
    H.eq(match.tdm.score[2], 0, "decided")
    local results = lastResults()
    H.eq(results[a[1]].won, true)
    H.eq(results[a[1]].placement, 1)
    H.eq(results[b[1]].won, false)
    H.eq(results[b[1]].placement, 2)
    H.eq(results[a[1]].score, 2)
    local recap = results[a[1]].recap
    H.eq(recap.winnerSide, 1)
    H.eq(recap.sides[1].score, 2)
    H.eq(recap.sides[2].label, "Team B")
    H.eq(recap.rows[1].id, a[1], "the winner on top")
    H.eq(recap.rows[1].kills, 2)
    H.eq(recap.rows[2].deaths, 2)
    H.eq(recap.rows[1].outcome, "won")
    H.eq(recap.mvp, a[1])
    H.eq(recap.lines[1].value, "Team A")
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("the bell: the most kills win, a tie is a draw", function()
    local match, a, b = live(2)
    kill(match, b[1], a[1])
    E.finish(match, "time")
    H.eq(lastResults()[a[1]].won, true)
    H.settle(7000)
    match, a, b = live(2)
    E.finish(match, "time")
    local results = lastResults()
    H.eq(results[a[1]].won, false, "nobody won")
    H.eq(results[b[1]].won, false)
    H.eq(results[a[1]].recap.winnerSide, nil, "a draw")
    H.eq(results[a[1]].recap.lines[1].value, "Draw")
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("after a respawn: 2 s nobody hurts you and you hurt nobody", function()
    local match, a, b = live(2)
    kill(match, b[1], a[1])
    H.settle(4600)
    H.eq(H.hit(a[1], b[1], AJAX), false, "protected")
    H.eq(H.hit(b[1], a[1], AJAX), false, "protected both ways")
    H.settle(2100)
    H.eq(H.hit(a[1], b[1], AJAX), true, "over")
    E.cancel(match)
    H.settle(500)
end)

H.test("a respawn lands away from the enemy", function()
    local match, a, b = live(2, "grand-imperial-mall")
    local enemy = H.players[a[1]]
    local map = match.map
    H.move(a[1], map.spawns[1].x, map.spawns[1].y, map.spawns[1].z)
    H.settle(300)
    kill(match, b[1], a[1])
    H.settle(4600)
    local back = H.players[b[1]]
    local nearest = 1e9
    for _, spawn in ipairs(map.spawns) do nearest = math.min(nearest, E.distance(spawn, enemy)) end
    H.ok(E.distance(back, enemy) > nearest + 20, "not next to them")
    E.cancel(match)
    H.settle(500)
end)

H.test("a forfeit: the side left wins whatever the score", function()
    local match, a, b = live(2)
    kill(match, a[1], b[1])
    H.settle(100)
    H.fire("op77_lightrp:activity:leaveRequest", b[1], "games.tdm")
    H.eq(match.reason, "forfeit")
    H.eq(lastResults()[a[1]].won, true, "the one left")
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("the recap: every column it names has a value in every row", function()
    local match, a, b = live(2)
    E.finish(match, "time")
    local recap = lastResults()[a[1]].recap
    H.ok(#recap.columns >= 2, "kills and deaths at least")
    for _, column in ipairs(recap.columns) do
        for _, row in ipairs(recap.rows) do H.ok(row[column] ~= nil, "blank column " .. column) end
    end
    H.settle(7000)
    H.ok(b[1], "two sides")
    H.noneInBuckets()
end)

H.test("every map: spawns inside the play area, each with a heading", function()
    H.eq(#GamesMaps.tdm, 2)
    for _, map in ipairs(GamesMaps.tdm) do
        H.ok(map.id:match("^[a-z0-9%-]+$"), "a slug")
        H.ok(#map.spawns >= 2, "spawns")
        for _, spawn in ipairs(map.spawns) do
            H.ok(E.distance(spawn, map.centre) + 2 <= map.radius, map.id .. ": a spawn out of bounds")
            H.ok(type(spawn.heading) == "number", "heading")
        end
    end
end)

H.done("tdm_test")
