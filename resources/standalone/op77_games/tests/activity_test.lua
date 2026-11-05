-- The adapter and the wiring of the Light RP contract: registration, statuses, the queue
-- panel, joins with and without options.match. Run: lua tests/activity_test.lua
local H = dofile("tests/harness.lua")
H.loadServer()
local A, E, L = GamesActivity, GamesEngine, GamesLobby
local core = H.core

for id = 1, 24 do H.addPlayer(id) end

H.test("every game registers: map choices, every cap off, no botFill", function()
    H.advance(200)
    H.eq(A.registered, true, "registered")
    for _, id in ipairs({ "games.tdm", "games.redlight" }) do
        local def = H.ok(core.registered[id], id .. " registered")
        H.eq(def.resource, "op77_games")
        H.eq(def.modeKey, "map")
        H.eq(def.botFill, nil, "no botFill")
        H.ok(def.caps.rpWeapons == false and def.caps.rpItems == false and def.caps.needs == false and def.caps.vehicles == false, "caps")
    end
    H.eq(#core.registered["games.tdm"].modes, 2, "two TDM maps")
    H.eq(core.registered["games.tdm"].modes[1].id, "grand-imperial-mall", "by name")
    H.eq(core.registered["games.tdm"].modes[2].id, "watson-docks")
    H.eq(#core.registered["games.redlight"].modes, 1, "one red light map")
    H.eq(core.registered["games.tdm"].kind, "pvp")
    H.eq(core.registered["games.redlight"].kind, "event")
end)

H.test("a statusless idle game goes out once, on change only", function()
    H.settle(3000)
    local before = #H.eventsNamed("op77_lightrp:activity:status")
    H.settle(5000)
    H.eq(#H.eventsNamed("op77_lightrp:activity:status"), before, "no change, no status")
    H.ok(A.status("games.tdm", { phase = "idle" }, true), "forced")
    H.eq(A.status("games.other", { phase = "idle" }), false, "not ours")
end)

H.test("registration retries, and the core's start and :ready register again", function()
    local count = function() return #H.coreCalls("activityRegister") end
    core.refuseRegister = true
    H.fire("op77_lightrp:activity:ready")
    H.advance(500)
    H.eq(A.registered, false, "refused")
    core.refuseRegister = false
    local before = count()
    H.advance(3500)
    H.eq(A.registered, true, "retried")
    H.ok(count() > before, "registered again")
    before = count()
    H.fire("onResourceStart", "op77_lightrp")
    H.advance(1000)
    H.ok(count() > before, "the core's start registers")
end)

H.test("a panel join queues without entering; status.queue shows the lobby; the window launches", function()
    H.panelJoin(1, "games.tdm", { ranked = true, map = "grand-imperial-mall" })
    H.advance(300)
    H.eq(core.owner[1], nil, "queued players stay the core's")
    H.eq(E.matchOf(1), nil)
    local status = L.statusOf(A.definition("games.tdm"), E.now())
    H.eq(status.phase, "lobby")
    H.eq(status.queued, 1)
    H.eq(status.queue.lobbies[1].need, 2)
    H.eq(status.queue.lobbies[1].max, 16)
    H.eq(status.queue.lobbies[1].players[1], 1)
    H.eq(status.queue.lobbies[1].startsInMs, nil, "no countdown under the minimum")
    H.panelJoin(2, "games.tdm", { ranked = true })
    H.advance(300)
    status = L.statusOf(A.definition("games.tdm"), E.now())
    H.ok(status.queue.lobbies[1].startsInMs > 0, "the window counts down")
    H.eq(core.owner[1], nil, "still nobody entered")
    local match = H.untilPhase(1, "running")
    H.eq(match.map.id, "grand-imperial-mall", "the first join's map")
    H.eq(core.owner[1], "games.tdm")
    H.eq(core.owner[2], "games.tdm")
    H.ok(H.inGamesBucket(1), "in the bucket")
    H.ok(match.players[1].side ~= match.players[2].side, "dealt on two sides")
    status = L.statusOf(A.definition("games.tdm"), E.now())
    H.eq(status.phase, "running")
    H.eq(status.players, 2)
    H.fire("op77_lightrp:activity:leaveRequest", 1, "games.tdm")
    H.settle(8000)
    H.noneInBuckets()
end)

H.test("leaving a queue: out, no ownership touched", function()
    H.panelJoin(3, "games.tdm", { ranked = true })
    H.advance(200)
    H.ok(L.queuedIn(3), "queued")
    H.fire("op77_lightrp:activity:leaveRequest", 3, "games.tdm")
    H.eq(L.queuedIn(3), nil, "left")
    H.advance(200)
    H.eq(L.statusOf(A.definition("games.tdm"), E.now()).queued, 0)
end)

H.test("a Light RP match: exact players, sides from teams, map from options, not the queue", function()
    H.panelJoin(9, "games.tdm", { ranked = true })
    H.matchJoin("games.tdm", { 3, 4, 5, 6 }, { map = "watson-docks", teams = { { 3, 4 }, { 5, 6 } } })
    local match = H.untilPhase(3, "countdown")
    H.eq(match.map.id, "watson-docks")
    H.eq(match.friendly, true)
    H.eq(match.players[3].side, 1)
    H.eq(match.players[4].side, 1)
    H.eq(match.players[5].side, 2)
    H.eq(match.players[6].side, 2)
    H.eq(match.players[9], nil, "the queue stays out")
    H.fire("op77_lightrp:activity:leaveRequest", 9, "games.tdm")
    E.cancel(match)
    H.settle(1000)
    H.noneInBuckets()
end)

H.test("a match gathers: the wait ends, whoever came plays; too few are released", function()
    core.pending[7] = "games.tdm"
    H.fire("op77_lightrp:activity:join", 7, "games.tdm", { match = { id = "gather:1", players = { 7, 8, 10 }, teams = { { 7 }, { 8, 10 } } } })
    core.pending[8] = "games.tdm"
    H.fire("op77_lightrp:activity:join", 8, "games.tdm", { match = { id = "gather:1", players = { 7, 8, 10 }, teams = { { 7 }, { 8, 10 } } } })
    H.advance(500)
    H.eq(E.matchOf(7), nil, "still gathering")
    H.advance(9000)
    local match = H.ok(E.matchOf(7), "started without the third")
    H.eq(match.players[10], nil)
    E.cancel(match)
    H.settle(500)

    core.pending[11] = "games.tdm"
    H.fire("op77_lightrp:activity:join", 11, "games.tdm", { match = { id = "gather:2", players = { 11, 12 } } })
    H.advance(9000)
    H.eq(E.matchOf(11), nil, "nobody to play")
    H.eq(core.pending[11], nil, "released")
    H.ok(H.noticeFor(11, "Not enough"), "told")
    H.noneInBuckets()
end)

H.test("a room's start the provider refuses: every member told why, and to host again", function()
    local slots = GamesConfig.scopes.perResource
    GamesConfig.scopes.perResource = 0
    H.matchJoin("games.tdm", { 19, 20 }, { id = "room:1", from = "room" })
    H.advance(300)
    GamesConfig.scopes.perResource = slots
    for _, id in ipairs({ 19, 20 }) do
        H.eq(E.matchOf(id), nil, "no match")
        H.eq(core.pending[id], nil, "released")
        local notice = H.ok(H.noticeFor(id, "fight slot"), "the reason")
        H.ok(notice.def.body:find("host the game again", 1, true), "what to do")
        H.eq(notice.def.durationMs, 8000)
    end
    -- One dropped during the gather: the one left hears it too.
    core.pending[21] = "games.tdm"
    local join = { from = "room", match = { id = "room:2", friendly = true, players = { 21, 22 } } }
    H.fire("op77_lightrp:activity:join", 21, "games.tdm", join)
    H.advance(9000)
    H.eq(E.matchOf(21), nil)
    H.ok(H.noticeFor(21, "Not enough players are ready. The room closed"), "told")
    -- A member the core refuses when the rest cannot play either.
    core.eligible[23] = "You must be alive and on your feet."
    H.matchJoin("games.tdm", { 23, 24 }, { id = "room:3", from = "room" })
    H.advance(300)
    core.eligible[23] = nil
    H.ok(H.noticeFor(23, "on your feet. The room closed"), "the refused one")
    H.ok(H.noticeFor(24, "The room closed"), "the other")
    -- A crew's friendly has no room to name.
    GamesConfig.scopes.perResource = 0
    H.matchJoin("games.tdm", { 21, 22 }, { id = "crew:1" })
    H.advance(300)
    GamesConfig.scopes.perResource = slots
    local notice = H.ok(H.noticeFor(22, "fight slot"), "told")
    H.eq(notice.def.body:find("room", 1, true), nil, "no room in it")
end)

H.test("a late join for a started match is refused, and released", function()
    H.matchJoin("games.tdm", { 13, 14 }, { id = "late:1" })
    local match = H.untilPhase(13, "running")
    core.pending[15] = "games.tdm"
    H.fire("op77_lightrp:activity:join", 15, "games.tdm", { match = { id = "late:1", players = { 13, 14, 15 } } })
    H.eq(E.matchOf(15), nil, "refused")
    H.eq(core.pending[15], nil, "released")
    H.ok(H.noticeFor(15, "already started"), "told")
    E.cancel(match)
    H.settle(500)
end)

H.test("a player the core refuses at the launch is told and left out", function()
    core.eligible[16] = "You must be alive and on your feet."
    H.matchJoin("games.tdm", { 16, 17, 18 }, {})
    H.advance(300)
    local match = H.ok(E.matchOf(17), "the others play")
    H.eq(match.players[16], nil)
    H.ok(H.noticeFor(16, "alive"), "told")
    H.eq(core.pending[16], nil, "released")
    core.eligible[16] = nil
    E.cancel(match)
    H.settle(500)
end)

H.test("activityEnter comes before any move into the bucket", function()
    H.matchJoin("games.tdm", { 19, 20 }, {})
    H.advance(300)
    local enter = H.coreCalls("activityEnter", 19)[1]
    local position
    for index, c in ipairs(H.coreLog) do if c == enter then position = index end end
    local moved
    for _, t in ipairs(H.teleports) do if t.id == 19 then moved = t end end
    H.ok(moved, "teleported")
    H.ok(moved.at >= position, "enter first")
    H.ok(moved.opts.bucket >= 4500000 and moved.opts.bucket <= 4599999, "its own bucket")
    E.cancel(E.matchOf(19))
    H.settle(500)
end)

H.test("results and recap reach the core, unranked, with sides rows lines", function()
    H.matchJoin("games.tdm", { 21, 22 }, {})
    local match = H.untilPhase(21, "running")
    H.events = {}
    E.finish(match, "time")
    local results = H.eventsNamed("op77_lightrp:activity:result")
    H.eq(#results, 2, "one per player")
    local result = results[1].args[3]
    H.eq(result.unranked, true, "nothing recorded")
    H.ok(type(result.recap.rows) == "table" and #result.recap.rows == 2, "rows")
    H.ok(type(result.recap.sides) == "table" and #result.recap.sides == 2, "sides")
    H.ok(type(result.recap.lines) == "table" and #result.recap.lines >= 1, "lines")
    H.eq(result.recap.matchId, match.id)
    H.eq(#H.eventsNamed("op77_lightrp:activity:recap"), 1)
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("the client draws the server's state and survives the core being away", function()
    local shows, pushes, clears, plays, destroys = {}, {}, 0, {}, 0
    local old = exports.op77_lightrp
    exports.op77_lightrp = {
        ActivityHudShow = function(_, view) shows[#shows + 1] = view return true end,
        ActivityHudPush = function(_, kind, payload) pushes[#pushes + 1] = { kind, payload } return true end,
        ActivityHudClear = function() clears = clears + 1 return true end,
    }
    Open77.audio = { play2D = function(file) plays[#plays + 1] = file return 7 end, destroy = function() destroys = destroys + 1 end }
    for _, file in ipairs(H.scripts("client_script")) do dofile(file) end
    H.fireNet("op77_games:hud", nil, { activity = "games.tdm", phase = "running" })
    H.eq(#shows, 1)
    H.fireNet("op77_games:push", nil, "banner", { title = "GO" })
    H.eq(pushes[1][1], "banner")
    H.fireNet("op77_games:cue", nil, "red")
    H.eq(plays[1], "audio/red.wav")
    H.fireNet("op77_games:cue", nil, "../../evil")
    H.eq(#plays, 1, "an unknown cue plays nothing")
    H.fireNet("op77_games:clear", nil)
    H.eq(clears, 1)
    H.fireNet("op77_games:clear", nil)
    H.eq(clears, 1, "nothing shown, nothing cleared")
    exports.op77_lightrp = setmetatable({}, { __index = function() error("down") end })
    H.fireNet("op77_games:hud", nil, { phase = "running" })
    H.fireNet("op77_games:hud", nil, "junk")
    H.fireNet("op77_games:push", nil, 1, 2)
    H.advance(2000)
    H.eq(destroys, 1, "the handle goes")
    exports.op77_lightrp = old
end)

H.done("activity_test")
