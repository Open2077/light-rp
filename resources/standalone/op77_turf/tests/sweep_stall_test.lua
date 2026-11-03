-- op77_turf Gang Sweep stall regression (owner, 2026-11-03: "I killed three of the enemy
-- gang's bots, then nobody came any more, they never came back"). End to end through the
-- real wiring against the fake host (tests/bot_host.lua):
--   the gang keeps coming back: three rounds of three kills, every ganger gets a new body;
--   a respawned ganger whose move the client refuses (onNpcTaskState failure path_blocked,
--   the live failure: the zone centre was off the navmesh) aims elsewhere, the zone's edge
--   then the nearest fighter, instead of re-sending the same move every 30 s, and is
--   rebuilt at its side's spawn when every move fails; a stale task's state is ignored;
--   a move that runs without moving the body and without any task state: the stuck
--   watchdog, and a body that does move is left alone;
--   a body that vanishes without any event (presence: npc_not_found) is replaced;
--   a body refused at respawn for a reason that is not its record (npc_limit) is asked
--   again, paced, and never dropped from the sweep.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test sweep_stall_test.lua
local T = dofile("tests/bot_host.lua")
local npc = T.npc
local CFG, B = T.CFG, T.B
local P = CFG.pve
local tasks = CFG.bots.tasks
local fire, net, advance, flush = T.fire, T.net, T.advance, T.flush

local function dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- The last task the platform received for a bot's body (clears skipped).
local function lastTask(bot, kind, from)
    for i = #npc.tasks, from or 1, -1 do
        local t = npc.tasks[i]
        if t.id == bot.npcId and t.kind ~= "clear" and (kind == nil or t.kind == kind) then return t, i end
    end
end

local function gangers(war)
    local list = {}
    for _, b in ipairs(war.bots) do if b.side == 2 then list[#list + 1] = b end end
    return list
end

local function aliveGangers(war)
    local n = 0
    for _, b in ipairs(gangers(war)) do if b.state == "alive" and b.npcId ~= nil and T.body(b.npcId) then n = n + 1 end end
    return n
end

-- Four checked hits (the per-second ceiling allows three): the ganger dies.
local function kill(bot)
    assert(bot.state == "alive", bot.name .. " is not up to be shot")
    local key, base = tostring(bot.npcId), T.now()
    for i = 0, 2 do T.setClock(base + i * 100); net("op77_turf:npcHit", 1, key, 30) end
    T.setClock(base + 1200); net("op77_turf:npcHit", 1, key, 30)
    advance(250) -- the platform's onNpcDied
    assert(bot.state == "down", bot.name .. " should be down, is " .. tostring(bot.state))
end

local function failTask(bot, reason)
    fire("onNpcTaskState", nil, tostring(bot.npcId), bot.task.id, "failure", reason or "path_blocked")
end

local function main()
    local host = T.host
    host.threads[1]()
    T.addPlayer(1, "valentinos")
    fire("op77_lightrp:activity:join", nil, 1, "turf.pve", { site = "kabuki" })
    advance(1250)
    local war = Turf.sweeps[1]
    assert(war and war.kind == "pve" and war.site.id == "kabuki" and B.count(war, 2) == P.baseBots)
    advance(5000)
    assert(aliveGangers(war) == P.baseBots, "the gang has its bodies")
    flush(); advance(250)
    advance(CFG.match.countdownSeconds * 1000)
    assert(war.state == "running")
    local A = war.site.zones[1]
    T.at(1, A.x + 3, A.y - 2, A.z, war.bucket) -- in zone A, off its centre

    -- ============================================================ the gang keeps coming back
    local kills = 0
    for round = 1, 3 do
        local before = {}
        for _, g in ipairs(gangers(war)) do
            before[g.id] = g.npcId
            kill(g)
            kills = kills + 1
        end
        advance(CFG.life.respawnSeconds * 1000 + CFG.bots.corpseLingerMs + 3 * CFG.bots.spawnSpacingMs + 500)
        assert(aliveGangers(war) == P.baseBots, ("round %d: every ganger is back (%d/%d)"):format(round, aliveGangers(war), P.baseBots))
        for _, g in ipairs(gangers(war)) do
            assert(g.npcId ~= before[g.id] and not g.failed, ("round %d: %s has a new body"):format(round, g.name))
        end
    end
    assert(war.members[1].kills == kills and kills == 9, "nine kills, nine respawns")
    assert(war.zones[1].owner == 1, "the fighter took A while its guard was down")

    -- ============================================================ path_blocked: aim elsewhere, then rebuild
    -- The guard of A respawned at a zone its gang holds and was sent back to retake A
    -- (a few seconds ago: inside stuckMs, the watchdog has not spoken yet).
    local G = war.bots[1]
    assert(T.now() - G.task.at < tasks.stuckMs, "a fresh move")
    assert(G.side == 2 and G.home == 1 and G.state == "alive")
    local first = lastTask(G, "moveTo")
    assert(first and G.task.kind == "move" and G.task.zone == 1 and G.task.id ~= nil, "a move to retake A")
    assert(dist(first.point, A) < 0.01, "the first move aims at A's centre")
    local oldId, mark = G.npcId, #npc.tasks
    fire("onNpcTaskState", nil, tostring(G.npcId), "t-stale", "failure", "path_blocked")
    assert((G.moveFails or 0) == 0 and not G.task.failed, "another task's state is ignored")
    failTask(G)
    assert(G.moveFails == 1 and G.task.failed, "the refused move is counted")
    assert(T.logged("cannot reach zone A %(path_blocked%)"), "and said once")
    advance(tasks.retaskMs)
    local second = lastTask(G, "moveTo", mark + 1)
    assert(second, "a new order comes after retaskMs, not after the 30 s move timeout")
    local edge = dist(second.point, A)
    assert(edge > 1 and edge <= A.radius, ("then A's edge (%.1f m from the centre)"):format(edge))
    assert(dist(second.point, T.body(G.npcId).pos) < dist(A, T.body(G.npcId).pos), "on the bot's side")
    mark = #npc.tasks
    failTask(G)
    advance(tasks.retaskMs)
    local third = lastTask(G, "moveTo", mark + 1)
    local fighter = T.pl[1].pos
    assert(third and dist(third.point, fighter) < 0.01, "then the nearest fighter")
    local guard = 0
    while G.npcId == oldId and guard < 8 do
        if G.task and G.task.kind == "move" and not G.task.failed then failTask(G) end
        advance(tasks.retaskMs)
        guard = guard + 1
    end
    assert(G.npcId ~= oldId and G.npcId ~= nil, "every move refused: the body is rebuilt")
    assert(T.body(oldId) == nil, "the stuck body is gone")
    assert(T.logged("rebuilt %(stuck: %d+ moves to zone A got nowhere %(path_blocked%)%)"), "the rebuild says why")
    local north = war.site.spawns[2].points
    local near
    for _, pt in ipairs(north) do
        if dist(T.body(G.npcId).pos, pt) <= CFG.bots.spawnRing + 0.5 then near = true end
    end
    assert(near, "rebuilt at its side's spawn (the North Lanes), not at the zone it could not leave")
    assert(G.moveFails == 0 and G.spawnShift == 1, "a fresh start, from the next spawn point next time")
    local fresh = lastTask(G, "moveTo")
    assert(fresh and dist(fresh.point, A) < 0.01, "and A's centre again")

    -- ============================================================ no task state at all: the stuck watchdog
    mark = #npc.tasks
    advance(tasks.stuckMs + 1500)
    assert(G.moveFails == 1, "a move that never moved the body counts as failed: " .. tostring(G.moveFails))
    assert(T.logged("cannot reach zone A %(no_progress%)"))
    local after = lastTask(G, "moveTo", mark + 1)
    assert(after and dist(after.point, A) > 1, "re-planned at A's edge")
    -- a body that does move is left alone
    local from = T.body(G.npcId).pos
    T.botAt(G, from.x + 4, from.y - 3, from.z)
    mark = #npc.tasks
    advance(tasks.stuckMs + 1500)
    assert(G.moveFails == 1 and lastTask(G, "moveTo", mark + 1) == nil, "moving: no new order before its timeout")

    -- ============================================================ a body that vanishes without any event
    local V = war.bots[2]
    assert(V.side == 2 and V.state == "alive")
    local vanished = V.npcId
    npc.bodies[tostring(vanished)] = nil -- no onNpcRemoved, no onNpcDied
    advance(1000)
    assert(T.logged("rebuilt %(vanished%)"))
    advance(CFG.bots.corpseLingerMs + CFG.bots.spawnSpacingMs + 500)
    assert(V.state == "alive" and V.npcId ~= nil and V.npcId ~= vanished and T.body(V.npcId), "replaced")

    -- ============================================================ refused at respawn (npc_limit): asked again
    local K = war.bots[3]
    -- The pusher may be between bodies (the watchdog rebuilds bots the fake host never moves).
    local wait = 0
    while K.state ~= "alive" and wait < 80 do advance(250); wait = wait + 1 end
    assert(K.side == 2 and K.state == "alive")
    for _, r in ipairs(B.recordsFor(war.sides[2].gang)) do npc.refuse[r] = "npc_limit" end
    local record = K.recordIndex
    kill(K)
    advance(CFG.life.respawnSeconds * 1000 + 1000)
    assert(K.state == "pending" and not K.failed and K.npcId == nil, "refused: still in the sweep, waiting")
    assert(T.logged("body refused %(npc_limit%), asking again"))
    advance(8000)
    assert(K.state == "pending" and not K.failed and K.recordIndex == record, "still waiting, on the record that worked")
    for _, r in ipairs(B.recordsFor(war.sides[2].gang)) do npc.refuse[r] = nil end
    advance(CFG.bots.spawnRetryMaxMs + 1000)
    assert(K.state == "alive" and K.npcId ~= nil and T.body(K.npcId), "the limit lifted: back in the fight")
    assert(T.body(K.npcId).def.record == B.recordsFor(war.sides[2].gang)[record], "with its own record")

    assert(war.state == "running" and aliveGangers(war) == P.baseBots, "the sweep goes on with its whole gang")
end

T.run("sweep_stall_test", main, "gang back after 3x3 kills, path_blocked -> edge -> nearest fighter -> rebuilt at the "
    .. "side spawn (stale task state ignored), stuck watchdog (moving body left alone), vanished body replaced, "
    .. "refused respawn (npc_limit) asked again on its own record")
