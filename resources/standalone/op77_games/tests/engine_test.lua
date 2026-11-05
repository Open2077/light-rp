-- The engine: every way out of a match, the scope budget, weapons, deaths and respawns,
-- bounds, joining in progress, the mode contract, a hostile client.
-- Run: lua tests/engine_test.lua
local H = dofile("tests/harness.lua")

-- A test mode: what a mode that opted in looks like, and a pvp mode without teams.
H.loadServer()
local A, E, C, L = GamesActivity, GamesEngine, GamesCombat, GamesLobby
local core = H.core
local AJAX = H.hash("Items.Preset_Ajax_Default")

local declareTestModes
declareTestModes = function()
E.mode({
    id = "games.testopen", key = "testopen", label = "Open Game", kind = "pvp", minPlayers = 2, maxPlayers = 4,
    maps = H.seedOf("tdm"), pvp = true, teams = 2, seconds = 300, respawnMs = 1000, joinInProgress = true,
})
E.mode({
    id = "games.testffa", key = "testffa", label = "FFA", kind = "pvp", minPlayers = 2, maxPlayers = 8,
    maps = H.seedOf("tdm"), pvp = true, seconds = 300, respawnMs = 1000,
    kit = true,
})
E.mode({
    id = "games.testbroken", key = "testbroken", label = "Broken", kind = "event", minPlayers = 1, maxPlayers = 8,
    maps = H.seedOf("redlight"), seconds = 5, bounds = false,
    tick = function() error("a bug in a mode") end, results = function() error("another") end,
})
end
declareTestModes()
H.advance(200)

-- This VM stopped: a new one loads, as the runtime does.
local function restart()
    H.reload()
    A, E, C, L = GamesActivity, GamesEngine, GamesCombat, GamesLobby
    declareTestModes()
end

local nextId = 100
local function players(n)
    local ids = {}
    for _ = 1, n do
        nextId = nextId + 1
        H.addPlayer(nextId)
        ids[#ids + 1] = nextId
    end
    return ids
end

local function live(activityId, n, options)
    local ids = players(n or 2)
    H.matchJoin(activityId, ids, options or {})
    return H.untilPhase(ids[1], "running"), ids
end

local function gone(ids)
    for _, id in ipairs(ids) do
        H.eq(E.matchOf(id), nil, "out of the engine")
        H.eq(core.owner[id], nil, "released by the core")
        H.ok(not H.inGamesBucket(id), "out of the bucket")
        H.eq(H.teams[id] or 0, 0, "team off")
        H.eq(H.weaponCount(id), 0, "our weapons gone")
    end
end

local function closed(match)
    H.eq(match.closed, true, "match closed")
    H.eq(E.matches[match.id], nil, "forgotten")
    H.eq(C.scopes[match.id], nil, "scope released")
end

local function resultsOf(id)
    local found = {}
    for _, e in ipairs(H.eventsNamed("op77_lightrp:activity:result")) do
        if e.args[1] == id then found[#found + 1] = e.args[3] end
    end
    return found
end

-- ---------------------------------------------------------------- the way in --

H.test("the match: placed in its bucket, frozen, armed, scoped, then GO", function()
    local ids = players(2)
    H.matchJoin("games.tdm", ids, { teams = { { ids[1] }, { ids[2] } } })
    local match = H.untilPhase(ids[1], "countdown")
    H.ok(match.bucket >= 4500000 and match.bucket <= 4599999, "bucket in range")
    H.eq(H.population[1], match.bucket)
    H.eq(H.population[2], false, "no pedestrians")
    H.eq(H.players[ids[1]].bucket, match.bucket)
    H.eq(H.players[ids[1]].frozen, true, "held until GO")
    H.eq(H.teams[ids[1]], 1)
    H.eq(H.teams[ids[2]], 2)
    H.settle(1000)
    H.eq(H.weapons[ids[1]][1], "Items.Preset_Ajax_Default")
    H.eq(H.weapons[ids[1]][2], "Items.Preset_Lexington_Default")
    H.ok(C.scopes[match.id], "a scope over the match")
    H.eq(H.scopes[C.scopes[match.id].id].bucket, match.bucket)
    H.untilPhase(ids[1], "running")
    H.eq(H.players[ids[1]].frozen, false, "released")
    H.fire("op77_lightrp:activity:leaveRequest", ids[1], "games.tdm")
    H.settle(8000)
    gone(ids)
    closed(match)
end)

H.test("two matches get two buckets, and a closed bucket is reused", function()
    local a, ids = live("games.tdm")
    local b, others = live("games.tdm")
    H.ok(a.bucket ~= b.bucket, "two buckets")
    E.cancel(a)
    E.cancel(b)
    H.settle(500)
    gone(ids)
    gone(others)
    local c = live("games.tdm")
    H.eq(c.bucket, math.min(a.bucket, b.bucket), "free again")
    E.cancel(c)
    H.settle(500)
end)

H.test("an arrival that cannot land is sent back; the others are not held forever", function()
    local ids = players(3)
    H.teleportRefused = true
    H.matchJoin("games.tdm", ids, {})
    H.advance(300)
    local match = H.ok(E.matchOf(ids[1]), "opened")
    H.teleportRefused = false
    H.settle(2500)
    H.ok(match.phase == "countdown", "the retry landed them")
    E.cancel(match)
    H.settle(500)

    ids = players(2)
    H.teleportFails = true
    H.matchJoin("games.tdm", ids, {})
    H.settle(27000)
    H.teleportFails = false
    H.settle(1000)
    H.eq(E.matchOf(ids[1]), nil, "gave up")
    H.ok(H.noticeFor(ids[1], "could not be brought"), "told")
    gone(ids)
end)

H.test("activityEnter refused: that player only; below the minimum nobody moves", function()
    local ids = players(3)
    core.enterRefused[ids[3]] = "Not now."
    H.matchJoin("games.tdm", ids, {})
    H.advance(300)
    local match = H.ok(E.matchOf(ids[1]), "two still play")
    H.eq(match.players[ids[3]], nil)
    H.ok(H.noticeFor(ids[3], "Not now"), "told")
    H.eq(core.pending[ids[3]], nil, "released")
    E.cancel(match)
    H.settle(500)

    ids = players(2)
    core.enterRefused[ids[2]] = "Not now."
    local moves = #H.teleports
    H.matchJoin("games.tdm", ids, {})
    H.advance(300)
    H.eq(E.matchOf(ids[1]), nil, "no match")
    H.eq(core.owner[ids[1]], nil, "the entered one is released")
    H.eq(#H.teleports, moves, "nobody moved")
    local leave = H.coreCalls("activityLeave", ids[1])[1]
    H.eq(leave.args[3].returnPlayer, false, "kept in place: they never left")
end)

-- ---------------------------------------------------------------- the budget --

H.test("no free scope: the ninth match is refused cleanly, nothing half done", function()
    local matches = {}
    for _ = 1, 8 do matches[#matches + 1] = live("games.tdm") end
    H.eq(C.free(), 0, "the budget is spent")
    H.eq(H.scopeCount(), 8, "eight scopes")
    local ids = players(2)
    local enters, moves = #H.coreCalls("activityEnter"), #H.teleports
    H.matchJoin("games.tdm", ids, {})
    H.advance(300)
    H.eq(E.matchOf(ids[1]), nil, "refused")
    H.eq(#H.coreCalls("activityEnter"), enters, "nobody entered")
    H.eq(#H.teleports, moves, "nobody moved")
    H.eq(core.pending[ids[1]], nil, "released")
    H.ok(H.noticeFor(ids[1], "slot"), "told")
    H.eq(L.statusOf(A.definition("games.tdm"), E.now()).joinable, false, "the panel says so")
    -- an event game needs no scope
    local solo = players(1)
    H.panelJoin(solo[1], "games.redlight")
    H.untilPhase(solo[1], "placing")
    E.cancel(E.matchOf(solo[1]))
    for _, match in ipairs(matches) do E.cancel(match) end
    H.settle(500)
    H.eq(C.free(), 8, "the slots came back")
    H.eq(H.scopeCount(), 0)
end)

H.test("the platform refuses a scope: retried, told, then the match is cancelled", function()
    H.scopeRefusal = "scope_limit"
    local ids = players(2)
    H.matchJoin("games.tdm", ids, {})
    local match = H.untilPhase(ids[1], "countdown")
    H.settle(7000)
    H.ok(H.lastClient("op77_games:push", ids[1]), "told on the HUD")
    H.ok(#H.scopesCreated > 2, "retried")
    H.eq(match.closed, nil, "not given up yet")
    H.settle(11000)
    closed(match)
    gone(ids)
    H.eq(#resultsOf(ids[1]), 0, "no result for a match nobody could fight")
    H.ok(H.noticeFor(ids[1], "could not be opened"), "told")
    H.scopeRefusal = nil
end)

H.test("a roster change rebuilds the scope; a death keeps a fighter in it", function()
    local match, ids = live("games.tdm", 4, {})
    local scope = H.ok(C.scopes[match.id], "scope")
    H.eq(#scope.list, 4)
    H.die(ids[1])
    H.settle(600)
    H.eq(C.scopes[match.id].id, scope.id, "a death does not rebuild")
    H.fire("op77_lightrp:activity:leaveRequest", ids[2], "games.tdm")
    H.settle(1200)
    H.ok(C.scopes[match.id].id ~= scope.id, "a departure does")
    E.cancel(match)
    H.settle(500)
end)

H.test("the periodic rebuild heals a scope the platform dropped", function()
    local match = live("games.tdm", 2)
    local id = C.scopes[match.id].id
    H.scopes[id] = nil -- removed behind our back
    H.settle(16000)
    H.ok(H.scopeCount() >= 1, "back")
    E.cancel(match)
    H.settle(500)
end)

-- ---------------------------------------------------------------- exits --

H.test("exit: every player leaves", function()
    local match, ids = live("games.redlight", 3)
    for _, id in ipairs(ids) do H.fire("op77_lightrp:activity:leaveRequest", id, "games.redlight") end
    H.advance(300)
    gone(ids)
    closed(match)
    H.eq(#resultsOf(ids[1]), 1, "the leavers get their board")
end)

H.test("exit: a leave is answered at once, inside the 15 s", function()
    local match, ids = live("games.tdm", 4)
    local before = #H.coreCalls("activityLeave", ids[1])
    H.fire("op77_lightrp:activity:leaveRequest", ids[1], "games.tdm")
    H.eq(#H.coreCalls("activityLeave", ids[1]), before + 1, "activityLeave in the same tick")
    H.eq(H.coreCalls("activityLeave", ids[1])[before + 1].args[3].returnPlayer, true)
    H.eq(core.owner[ids[1]], nil)
    H.ok(match.phase == "running", "the match goes on")
    E.cancel(match)
    H.settle(500)
end)

H.test("exit: the last opponent leaves: the one left wins, sees the recap, goes home", function()
    local match, ids = live("games.tdm", 2)
    H.fire("op77_lightrp:activity:leaveRequest", ids[2], "games.tdm")
    H.eq(match.phase, "ended", "forfeit")
    H.eq(match.reason, "forfeit")
    H.eq(resultsOf(ids[1])[1].won, true, "the one left wins")
    H.eq(resultsOf(ids[2])[1].won, false)
    H.eq(resultsOf(ids[2])[1].stats.quit, true)
    H.ok(H.inGamesBucket(ids[1]), "still there for the result card")
    H.settle(7000)
    gone(ids)
    closed(match)
end)

H.test("exit: free for all, one left", function()
    local match, ids = live("games.testffa", 3)
    H.fire("op77_lightrp:activity:leaveRequest", ids[1], "games.testffa")
    H.eq(match.phase, "running", "two still fight")
    H.fire("op77_lightrp:activity:leaveRequest", ids[2], "games.testffa")
    H.eq(match.phase, "ended", "one left")
    H.settle(7000)
    gone(ids)
    closed(match)
end)

H.test("exit: disconnects", function()
    local match, ids = live("games.tdm", 2)
    H.removePlayer(ids[1])
    core.owner[ids[1]] = nil
    H.fire("op77_lightrp:activity:dropped", ids[1], "games.tdm", "disconnect")
    H.fire("onPlayerDisconnected", tostring(ids[1]))
    H.eq(match.phase, "ended")
    H.eq(#H.coreCalls("activityLeave", ids[1]), 0, "never activityLeave for a released player")
    H.settle(7000)
    gone({ ids[2] })
    closed(match)
end)

H.test("exit: the clock", function()
    local match, ids = live("games.tdm", 2)
    H.settle(607000)
    H.eq(match.reason, "time")
    gone(ids)
    closed(match)
    H.eq(resultsOf(ids[1])[1].won, false, "0-0 is a draw")
end)

H.test("exit: the core gives up on a leave (timeout), a character change", function()
    local match, ids = live("games.tdm", 3)
    core.owner[ids[1]] = nil
    H.coreReturn(ids[1])
    H.fire("op77_lightrp:activity:dropped", ids[1], "games.tdm", "timeout")
    H.eq(E.matchOf(ids[1]), nil)
    H.eq(#H.coreCalls("activityLeave", ids[1]), 0, "the core already released them")
    -- a character change releases in place: nobody takes them back but us
    core.owner[ids[2]] = nil
    H.fire("op77_lightrp:activity:dropped", ids[2], "games.tdm", "character")
    H.ok(H.inGamesBucket(ids[2]), "still in the bucket")
    H.settle(30000)
    H.ok(not H.inGamesBucket(ids[2]), "the sweep took them out")
    H.eq(H.players[ids[2]].bucket, GamesConfig.fallback.bucket)
    closed(match)
    H.noneInBuckets()
end)

H.test("exit: activityLeave refused: the fallback teleport, and if that fails the bucket", function()
    local match, ids = live("games.tdm", 4)
    core.leaveFails = true
    H.fire("op77_lightrp:activity:leaveRequest", ids[1], "games.tdm")
    H.settle(500)
    H.eq(H.players[ids[1]].x, GamesConfig.fallback.x, "the fallback point")
    H.eq(H.players[ids[1]].bucket, 0)
    H.teleportFails = true
    H.fire("op77_lightrp:activity:leaveRequest", ids[2], "games.tdm")
    H.settle(500)
    H.eq(H.players[ids[2]].bucket, 0, "the bucket came back without the teleport")
    H.teleportFails = false
    core.leaveFails = false
    core.owner[ids[1]], core.owner[ids[2]] = nil, nil
    E.cancel(match)
    H.settle(500)
end)

H.test("exit: a dead player at the end is left to the core, a dead one on the fallback respawns", function()
    local match, ids = live("games.tdm", 3)
    H.die(ids[1])
    H.fire("op77_lightrp:activity:leaveRequest", ids[1], "games.tdm")
    H.eq(H.players[ids[1]].life, "alive", "the core stood them up")
    core.leaveFails = true
    H.die(ids[2])
    H.fire("op77_lightrp:activity:leaveRequest", ids[2], "games.tdm")
    H.settle(300)
    H.eq(H.players[ids[2]].life, "alive", "respawned out")
    H.eq(H.players[ids[2]].bucket, 0, "in the city")
    core.leaveFails = false
    core.owner[ids[2]] = nil
    H.settle(7000)
    H.noneInBuckets()
    closed(match)
end)

H.test("exit: the provider stops mid-match", function()
    H.settle(100)
    local a, ids = live("games.tdm", 2)
    local b, others = live("games.redlight", 1)
    H.providerStop()
    H.advance(500)
    H.noneInBuckets()
    for _, id in ipairs(ids) do
        H.eq(H.weaponCount(id), 0, "our weapons first")
        H.eq(H.teams[id], 0, "team off")
        H.ok(H.lastClient("op77_games:clear", id), "HUD cleared")
    end
    H.eq(H.scopeCount(), 0, "scopes released")
    H.eq(core.owner[ids[1]], nil)
    H.ok(a and b and others, "both ran")
    restart()
    H.advance(300)
    H.eq(A.registered, true, "the new VM registers")
end)

H.test("exit: the provider stops with the core gone too: the fallback", function()
    local _, ids = live("games.tdm", 2)
    H.coreCrash()
    H.fire("onResourceStop", "op77_games")
    H.advance(500)
    H.noneInBuckets()
    H.eq(H.players[ids[1]].x, GamesConfig.fallback.x)
    H.eq(H.players[ids[1]].bucket, 0)
    restart()
    H.coreStart()
    H.advance(1000)
end)

H.test("exit: the core stops mid-match, and comes back", function()
    local match, ids = live("games.tdm", 2)
    H.coreStop()
    H.settle(300)
    gone(ids)
    closed(match)
    H.eq(A.registered, false, "it forgot us")
    H.coreStart()
    H.advance(1000)
    H.eq(A.registered, true, "registered again")
    H.ok(core.registered["games.tdm"], "in the new core")
    local again = live("games.tdm", 2)
    H.ok(again.phase == "running", "matches work again")
    E.cancel(again)
    H.settle(500)
end)

H.test("exit: the core's stop reaches us first, its teleports fail: the fallback still comes", function()
    local match, ids = live("games.tdm", 2)
    local owners = core.owner
    core.owner = {}
    H.fire("onResourceStop", "op77_lightrp")
    H.eq(E.matchOf(ids[1]), nil, "the match is over")
    H.ok(H.inGamesBucket(ids[1]), "not back yet")
    H.ok(owners[ids[1]], "the core had them")
    exports.op77_lightrp = H.coreGone
    H.settle(2500)
    H.noneInBuckets()
    closed(match)
    H.coreStart()
    H.advance(1000)
end)

H.test("exit: the core crashes without a word, players stranded: the fallback", function()
    local match, ids = live("games.tdm", 2)
    local before = #H.teleports
    H.coreCrash()
    H.settle(6000)
    H.noneInBuckets()
    H.eq(H.players[ids[1]].x, GamesConfig.fallback.x, "the fallback point")
    H.ok(#H.teleports > before, "moved")
    closed(match)
    H.fire("onResourceStop", "op77_lightrp")
    H.coreStart()
    H.advance(1000)
    H.eq(A.registered, true)
end)

H.test("exit: a mode that throws never traps anyone: the clock still ends it", function()
    local ids = players(1)
    H.matchJoin("games.testbroken", ids, {})
    local match = H.untilPhase(ids[1], "running")
    H.settle(5500)
    H.eq(match.phase, "ended", "the clock ends a broken mode")
    H.eq(resultsOf(ids[1])[1].placement, 1, "a default board")
    H.settle(7000)
    gone(ids)
    closed(match)
    H.ok(H.logged("tick hook of games.testbroken failed"), "logged")
end)

H.test("a stray in our buckets (a reload that lost its match) is taken out", function()
    local ids = players(2)
    H.players[ids[1]].bucket = 4500123
    H.players[ids[2]].bucket = 4500123
    core.owner[ids[2]] = "games.tdm"
    core.returns[ids[2]] = { x = 1, y = 2, z = 3, bucket = 0 }
    H.settle(27000)
    H.noneInBuckets()
    H.eq(H.players[ids[1]].x, GamesConfig.fallback.x, "nobody owns them: the fallback")
    H.eq(H.players[ids[2]].x, 1, "the core owns them: its way back")
    H.eq(core.owner[ids[2]], nil)
end)

-- ---------------------------------------------------------------- deaths --

H.test("a respawn lands in the match's bucket, on a spawn, armed, protected", function()
    local match, ids = live("games.tdm", 2)
    local before = #H.respawns
    H.die(ids[1])
    H.eq(match.players[ids[1]].alive, false)
    H.settle(3000)
    H.eq(#H.respawns, before, "not yet")
    H.settle(1500)
    H.eq(#H.respawns, before + 1, "back after 4 s")
    local respawn = H.respawns[#H.respawns]
    H.eq(respawn.opts.bucket, match.bucket, "the bucket, or the runtime's default 0 ejects them")
    H.eq(H.players[ids[1]].bucket, match.bucket)
    H.ok(match.players[ids[1]].alive, "alive")
    H.ok(match.players[ids[1]].protectedUntil > E.now(), "protected")
    H.eq(#H.coreCalls("activityKit", ids[1]), 2, "the kit again at the respawn")
    E.cancel(match)
    H.settle(500)
end)

H.test("a slow respawn: nothing verified until the body stands, then the kit counts", function()
    local match, ids = live("games.tdm", 2)
    H.die(ids[1])
    H.respawnDelayMs = 3000
    H.settle(4500)
    H.eq(H.players[ids[1]].life, "respawnpending", "respawn() answered, the body is not up")
    H.eq(#H.coreCalls("activityKit", ids[1]), 2, "the kit asked for")
    H.eq(H.hit(ids[1], ids[2], AJAX), false, "nothing verified yet")
    H.settle(3500)
    H.respawnDelayMs = nil
    H.eq(H.players[ids[1]].life, "alive")
    H.eq(H.hit(ids[1], ids[2], AJAX), true, "armed once it stood")
    E.cancel(match)
    H.settle(500)
end)

H.test("a body that never stands: the core's failure reaches the player", function()
    local match, ids = live("games.tdm", 2)
    H.die(ids[1])
    H.respawnDelayMs = 1000000
    H.settle(4500)
    H.eq(H.players[ids[1]].life, "respawnpending")
    H.eq(H.noticeFor(ids[1], "could not be equipped"), nil, "nothing to tell yet")
    H.kitReport(ids[1], H.kits[ids[1]], "failed")
    H.ok(H.noticeFor(ids[1], "could not be equipped"), "told")
    H.eq(H.hit(ids[1], ids[2], AJAX), false, "still nothing verified")
    H.respawnDelayMs = nil
    H.players[ids[1]].life = "alive"
    E.cancel(match)
    H.settle(500)
end)

H.test("one death reported twice counts once, in either order, killer credited", function()
    local match, ids = live("games.tdm", 2)
    H.eq(H.hit(ids[2], ids[1], AJAX), true, "a hit")
    H.players[ids[1]].life = "dead"
    H.fire("open77:playerDied", ids[1], "{}")
    H.fire("open77:playerKilled", ids[1], ids[2])
    H.eq(match.players[ids[1]].deaths, 1, "one death")
    H.eq(match.players[ids[2]].kills, 1, "credited from the last hit")
    H.eq(match.tdm.score[match.players[ids[2]].side], 1)
    H.settle(4600)
    H.players[ids[2]].life = "dead"
    H.fire("open77:playerKilled", ids[2], ids[1])
    H.fire("open77:playerDied", ids[2], '{"killer":' .. ids[1] .. "}")
    H.eq(match.players[ids[2]].deaths, 1, "one death")
    H.eq(match.players[ids[1]].kills, 1, "credited")
    E.cancel(match)
    H.settle(500)
end)

H.test("a suicide, a stranger's report, a friend's kill score nothing", function()
    local match, ids = live("games.tdm", 4, { })
    local p = match.players
    local friend
    for _, id in ipairs(ids) do if id ~= ids[1] and p[id].side == p[ids[1]].side then friend = id end end
    H.die(ids[1], ids[1])
    H.eq(p[ids[1]].kills, 0, "a suicide")
    H.settle(4600)
    H.die(ids[1], 999)
    H.settle(4600)
    H.die(ids[1], friend)
    H.eq(p[friend].kills, 0, "a friend")
    H.eq(match.tdm.score[1] + match.tdm.score[2], 0, "no score")
    E.cancel(match)
    H.settle(500)
end)

H.test("a respawn that cannot happen gives up: out, not dead in a bucket", function()
    local match, ids = live("games.tdm", 3)
    H.players[ids[1]].life = "dead"
    H.fire("open77:playerDied", ids[1], "{}")
    H.players[ids[1]].life = "respawnpending"
    H.settle(7500)
    H.eq(E.matchOf(ids[1]), nil, "taken out")
    H.ok(H.noticeFor(ids[1], "could not be brought back"), "told")
    H.players[ids[1]].life = "alive"
    E.cancel(match)
    H.settle(500)
    H.noneInBuckets()
end)

-- ---------------------------------------------------------------- bounds --

H.test("out of bounds: warned, back in clears it, past the grace is a death", function()
    local match, ids = live("games.tdm", 2)
    local id, map = ids[1], match.map
    local function outside() H.move(id, map.centre.x + map.radius + 5, map.centre.y, map.centre.z) end
    outside()
    H.settle(1000)
    H.eq(H.lastClient("op77_games:push", id).args[2].title, "OUT OF BOUNDS")
    H.move(id, map.centre.x, map.centre.y, map.centre.z)
    H.settle(1000)
    H.eq(H.lastClient("op77_games:push", id).args[2].title, "BACK IN BOUNDS")
    outside()
    H.settle(4000)
    H.eq(#H.kills, 0, "inside the grace")
    H.settle(1500)
    H.eq(H.players[id].life, "dead", "out past the grace")
    H.fire("open77:playerDied", id, "{}")
    H.eq(match.players[id].deaths, 1)
    E.cancel(match)
    H.settle(500)
end)

H.test("out of bounds: an unreadable position convicts nobody, a mode may opt out", function()
    local kills = #H.kills
    local match, ids = live("games.tdm", 2)
    H.move(ids[1], match.map.centre.x + 500)
    H.players[ids[1]].fresh = false
    H.settle(8000)
    H.eq(#H.kills, kills, "cannot tell is not outside")
    H.players[ids[1]].fresh = true
    H.move(ids[1], match.map.centre.x)
    E.cancel(match)
    H.settle(500)
    local rl, others = live("games.redlight", 1)
    H.move(others[1], rl.map.centre.x - 500)
    H.settle(8000)
    H.eq(#H.kills, kills, "no play area")
    E.cancel(rl)
    H.settle(500)
end)

-- ---------------------------------------------------------------- damage --

H.test("the arbiter: strangers untouched, nothing crosses a match, only the fight hurts", function()
    local stranger, other = players(2)[1], nil
    other = nextId
    H.eq(H.hit(stranger, other, "0x1"), true, "the city is not ours")
    local ids = players(2)
    H.matchJoin("games.tdm", ids, { teams = { { ids[1] }, { ids[2] } } })
    local match = H.untilPhase(ids[1], "countdown")
    H.settle(1000)
    H.eq(H.hit(ids[1], ids[2], AJAX), false, "not before GO")
    H.eq(H.hit(0, ids[1], nil), false, "not even the environment")
    H.untilPhase(ids[1], "running")
    H.eq(H.hit(ids[1], ids[2], AJAX), true, "a verified weapon, an enemy")
    H.eq(H.hit(ids[1], ids[2], "0x00" .. AJAX:sub(3):upper()), true, "the same id, spelled otherwise")
    H.eq(H.hit(stranger, ids[1], AJAX), false, "nobody reaches into a match")
    H.eq(H.hit(ids[1], stranger, AJAX), false, "nobody shoots out of one")
    H.eq(H.hit("18446744073709551000", ids[1], AJAX), false, "an NPC either")
    H.eq(H.hit(ids[1], ids[1], nil), true, "a fall is the match's own")
    H.eq(H.hit(0, ids[1], nil), true, "the environment too")
    local rival = live("games.tdm", 2)
    local foreign = next(rival.players)
    H.eq(H.hit(foreign, ids[1], AJAX), false, "another instance never")
    E.cancel(rival)
    E.finish(match, "time")
    H.eq(H.hit(ids[1], ids[2], AJAX), false, "not after the end")
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("the arbiter: forged weapons, friendly fire, spawn protection both ways", function()
    local ids = players(4)
    local a, b, c, d = ids[1], ids[2], ids[3], ids[4]
    H.matchJoin("games.tdm", ids, { teams = { { a, b }, { c, d } } })
    local match = H.untilPhase(a, "running")
    H.eq(H.hit(a, c, "0xdeadbeef"), false, "a weapon we never gave")
    H.eq(H.hit(a, c, 12345), false, "not even a string")
    H.eq(H.hit(a, c, nil), false, "no weapon")
    H.eq(H.hit(a, b, AJAX), false, "friendly fire")
    match.players[c].protectedUntil = E.now() + 1000
    H.eq(H.hit(a, c, AJAX), false, "nobody hurts you")
    H.eq(H.hit(c, a, AJAX), false, "you hurt nobody")
    H.settle(1100)
    H.eq(H.hit(a, c, AJAX), true, "after it")
    H.die(c)
    H.eq(H.hit(a, c, AJAX), false, "a body")
    E.cancel(match)
    H.settle(500)
end)

H.test("a weapon that never verified lands nothing; a report of an older hand is dropped", function()
    H.autoWeapons = false
    local ids = players(2)
    H.matchJoin("games.tdm", ids, {})
    local match = H.untilPhase(ids[1], "running")
    local a, b = ids[1], ids[2]
    H.eq(H.hit(a, b, AJAX), false, "unverified")
    local old = H.kits[a]
    C.arm(match, match.players[a], false) -- a new hand
    H.ok(H.kits[a].hand ~= old.hand, "replaced")
    H.kitReport(a, old, "armed")
    H.eq(H.hit(a, b, AJAX), false, "the old hand's word is worth nothing")
    H.kitReport(a, old, "failed")
    H.eq(H.noticeFor(a, "could not be equipped"), nil, "nor its failure")
    H.fire("op77_lightrp:activity:kit", 999, "games.tdm", { hand = H.kits[a].hand, state = "armed", weapons = {} })
    H.fire("op77_lightrp:activity:kit", a, "games.redlight", { hand = H.kits[a].hand, state = "armed", weapons = { { slot = 1, tweakDbId = AJAX } } })
    H.eq(H.hit(a, b, AJAX), false, "a stranger's report, another game's")
    H.kitReport(a, H.kits[a], "assigned")
    H.eq(H.hit(a, b, AJAX), true, "verified on its way to the hand")
    H.autoWeapons = true
    E.cancel(match)
    H.settle(500)
    gone(ids)
end)

H.test("a kit that never came is told; the game's own requests are gone; a body never armed keeps its slots", function()
    local ids = players(2)
    H.kitFails[ids[1]] = true
    local requests = #H.weaponLog
    H.matchJoin("games.tdm", ids, {})
    local match = H.untilPhase(ids[1], "running")
    H.ok(H.noticeFor(ids[1], "could not be equipped"), "told, as the arena does")
    H.eq(H.noticeFor(ids[2], "could not be equipped"), nil)
    H.eq(H.hit(ids[1], ids[2], AJAX), false, "nothing verified")
    H.kitFails[ids[1]] = nil
    H.die(ids[1])
    H.settle(7000) -- the respawn and its protection
    H.eq(H.hit(ids[1], ids[2], AJAX), true, "the respawn's kit made it")
    E.cancel(match)
    H.settle(500)
    gone(ids)
    for index = requests + 1, #H.weaponLog do
        H.ok(H.weaponLog[index].operation == "holster", "no assign, setAmmo or remove of ours: " .. H.weaponLog[index].operation)
    end

    local rl = players(1)
    H.weapons[rl[1]] = { [1] = "Items.RP_Weapon" }
    H.matchJoin("games.redlight", rl, {})
    local red = H.untilPhase(rl[1], "running")
    H.eq(#H.coreCalls("activityKit", rl[1]), 0, "red light hands nothing")
    H.fire("op77_lightrp:activity:leaveRequest", rl[1], "games.redlight")
    H.eq(H.weapons[rl[1]][1], "Items.RP_Weapon", "never strip someone we never armed")
    H.eq(#H.coreCalls("activityKitTake", rl[1]), 0, "nothing to take")
    H.ok(red.closed, "closed")
end)

H.test("the kit of a game: the core's default, a configured id, an id the core refuses", function()
    local match, ids = live("games.tdm", 2)
    local call = H.coreCalls("activityKit", ids[1])[1]
    H.eq(call.args[3], nil, "default: the core picks what missions preselect")
    H.eq(H.weapons[ids[1]][1], LightRpRaid.loadouts[1].primary)
    E.cancel(match)
    H.settle(500)
    GamesConfig.kits.tdm = "breacher"
    match, ids = live("games.tdm", 2)
    H.eq(H.coreCalls("activityKit", ids[1])[1].args[3], "breacher", "by id")
    H.eq(H.weapons[ids[1]][1], "Items.Preset_Carnage_Default")
    E.cancel(match)
    H.settle(500)
    GamesConfig.kits.tdm = "no-such-kit"
    match, ids = live("games.tdm", 2)
    H.ok(H.noticeFor(ids[1], "could not be equipped"), "refused and told")
    E.cancel(match)
    H.settle(500)
    GamesConfig.kits.tdm = false
end)

H.test("every way out: the kit is taken back, a body dead at the end too, and a stranger is not asked", function()
    local match, ids = live("games.tdm", 2)
    local a, b = ids[1], ids[2]
    H.ok(H.kits[a] and H.kits[b], "both hold one")
    H.players[a].life = "dead"
    H.fire("op77_lightrp:activity:leaveRequest", b, "games.tdm")
    H.eq(H.kits[b], nil, "a leave")
    H.settle(GamesConfig.match.endMs + 500)
    H.eq(H.kits[a], nil, "the body dead at the end")
    H.eq(#H.coreCalls("activityKitTake", a), 1, "asked with its hand")
    H.eq(H.coreCalls("activityKitTake", a)[1].args[3].hand ~= nil, true)
    gone({ b })

    match, ids = live("games.tdm", 2)
    a, b = ids[1], ids[2]
    H.fire("onPlayerDisconnected", a)
    H.removePlayer(a)
    H.kits[a] = nil
    H.settle(GamesConfig.match.endMs + 500)
    H.eq(H.kits[b], nil, "the one left behind, at the forfeit")
end)

-- ---------------------------------------------------------------- the contract --

H.test("the mode table: a typo fails at load, pvp over 32 fails at load", function()
    H.ok(not pcall(E.mode, { id = "x", key = "x", label = "x", kind = "pvp", maps = H.seedOf("tdm"), onKilled = function() end }), "unknown hook")
    H.ok(not pcall(E.mode, { id = "x", key = "x", label = "x", kind = "pvp", maps = H.seedOf("tdm"), pvp = true, maxPlayers = 33 }), "33")
    H.ok(not pcall(E.mode, { id = "x", key = "x", label = "x", kind = "ffa", maps = H.seedOf("tdm") }), "kind")
    H.ok(pcall(E.mode, { id = "games.nomaps", key = "nomaps", label = "x", kind = "pvp", maps = {} }), "no map is no error")
    H.eq(select(2, E.open(A.definition("games.nomaps"), {}, {})), "no_map", "and nothing opens")
    for _, def in ipairs(A.list) do H.eq(def.botFill, nil, def.id .. " declares no botFill") end
end)

H.test("join in progress: refused by default, entered when a mode opts in", function()
    local match, ids = live("games.tdm", 2)
    local late = players(1)[1]
    H.panelJoin(late, "games.tdm")
    H.settle(1000)
    H.eq(match.players[late], nil, "a running TDM is never joined")
    H.fire("op77_lightrp:activity:leaveRequest", late, "games.tdm")
    E.cancel(match)
    H.settle(500)
    gone(ids)

    local open1, ids2 = live("games.testopen", 2)
    H.eq(open1.matchId ~= nil, true)
    E.cancel(open1)
    H.settle(500)
    gone(ids2)
    local panel = players(3)
    H.panelJoin(panel[1], "games.testopen")
    H.panelJoin(panel[2], "games.testopen")
    local running = H.untilPhase(panel[1], "running")
    H.panelJoin(panel[3], "games.testopen")
    H.settle(600)
    H.ok(running.players[panel[3]], "the mode opted in")
    H.eq(H.players[panel[3]].bucket, running.bucket, "placed")
    H.ok(running.players[panel[3]].side, "on a side")
    H.eq(core.owner[panel[3]], "games.testopen", "entered first")
    E.cancel(running)
    H.settle(500)
    gone(panel)
end)

-- ---------------------------------------------------------------- hostile client --

H.test("a hostile client: the contract is not a net event, ready gives nothing away", function()
    for _, name in ipairs({ "op77_lightrp:activity:join", "op77_lightrp:activity:leaveRequest", "op77_lightrp:activity:dropped",
        "op77_lightrp:activity:ready", "op77_lightrp:activity:kit", "open77:playerDied", "open77:playerKilled" }) do
        H.eq(H.netHandlers[name], nil, name .. " must never be a net event")
    end
    local names = {}
    for name in pairs(H.netHandlers) do if name:find("^op77_games:") then names[#names + 1] = name end end
    H.eq(#names >= 1 and names[1] ~= nil, true)
    local match, ids = live("games.tdm", 2)
    local stranger = players(1)[1]
    local sent = #H.clientNamed("op77_games:hud")
    H.fireNet("op77_games:ready", stranger)
    H.fireNet("op77_games:ready", stranger, "junk", { 1 }, -1)
    H.fireNet("op77_games:ready", nil)
    H.fireNet("op77_games:ready", -4)
    H.fireNet("op77_games:ready", 1.5)
    H.fireNet("op77_games:ready", "drop table")
    H.eq(#H.clientNamed("op77_games:hud"), sent, "a stranger gets nothing")
    H.fireNet("op77_games:ready", ids[1])
    H.eq(#H.clientNamed("op77_games:hud"), sent + 1, "a member gets their own")
    H.eq(H.lastClient("op77_games:hud").target, ids[1])
    for _ = 1, 50 do H.fireNet("op77_games:ready", ids[1]) end
    H.eq(#H.clientNamed("op77_games:hud"), sent + 1, "a flood gets nothing more")
    H.eq(match.phase, "running", "and changes nothing")
    E.cancel(match)
    H.settle(500)
end)

H.test("junk from the outside raises nothing", function()
    H.fire("op77_lightrp:activity:join", -1, "games.tdm", {})
    H.fire("op77_lightrp:activity:join", "x", "games.tdm", {})
    H.fire("op77_lightrp:activity:join", 1, "games.none", {})
    H.fire("op77_lightrp:activity:leaveRequest", 0, "games.tdm")
    H.fire("op77_lightrp:activity:dropped", 1.5, "games.tdm", "x")
    H.fire("open77:playerDied", -3, "{}")
    H.fire("open77:playerKilled", "x", -2)
    H.fire("onPlayerDisconnected", "nope")
    local ids = players(1)
    core.pending[ids[1]] = "games.tdm"
    H.fire("op77_lightrp:activity:join", ids[1], "games.tdm", { match = { id = "junk", players = { "a", -1, 2.5, false }, teams = "no" } })
    H.settle(500)
    H.eq(E.matchOf(ids[1]), nil, "no match out of junk")
    H.settle(9000)
    H.eq(core.pending[ids[1]], nil, "released")
end)

H.done("engine_test")
