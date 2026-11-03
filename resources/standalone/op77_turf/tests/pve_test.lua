-- op77_turf Gang Sweep (turf.pve) and crews, end to end through the real wiring against
-- a fake Light RP, a fake world and a fake Open77.npcs (tests/bot_host.lua):
--   turf.pve registration; a solo sweep (the holders' gang on every zone, 3 gangers at
--   their zones, GANG SWEEP HUD, a kill and a capture, the holders' zone rate); results
--   on turf.pve with scaled reputation, never flagged test, no influence; a sweep too
--   short to count; a crew of 3 (one sweep, 7 gangers, waits for every member); a late
--   crew member (joins his crew's sweep, more gangers); "needs action" reputation;
--   maxSweeps queueing and the line-up view; a leaver; Light RP stopping; a PvP crew
--   never split (formed sides and late join).
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test pve_test.lua
local T = dofile("tests/bot_host.lua")
local host, core, npc = T.host, T.core, T.npc
local CFG, R, B, H = T.CFG, T.R, T.B, T.H
local P = CFG.pve
local fire, net, command, advance, flush = T.fire, T.net, T.command, T.advance, T.flush

local function sweepOf(id)
    for _, w in ipairs(Turf.sweeps) do if w.members[id] then return w end end
end
local function lineOf(card, label)
    for _, l in ipairs(card.payload.lines) do if l.label == label then return l.value end end
end
local function squad(id, leader, members) return { squad = { id = id, leader = leader, members = members } } end

local function main()
    -- ============================================================ registration
    host.threads[1]()
    local def = core.registered["turf.pve"]
    assert(def and def.kind == "event" and def.label == "Gang Sweep" and def.minPlayers == 1 and def.maxPlayers == 8)
    assert(def.caps.rpWeapons == false and def.modeKey == "site", "the site choice too")
    assert(T.statusOf("turf.pve").phase == "idle" and Turf.bots == false, "no staff switch needed")

    -- ============================================================ a solo sweep
    T.addPlayer(1, "valentinos")
    fire("op77_lightrp:activity:join", nil, 1, "turf.pve", { site = "kabuki" })
    assert(Turf.sweepEntry(1) and #Turf.queue == 0, "lined up for a sweep, not the war queue")
    advance(250)
    assert(#Turf.sweeps == 0, "a solo line-up waits a moment")
    advance(1000)
    local war = Turf.sweeps[1]
    assert(war and Turf.war == nil, "a sweep, beside the war slot")
    assert(war.kind == "pve" and war.activity == "turf.pve" and war.squadKey == "solo:1" and war.site.id == "kabuki")
    assert(core.owned[1] == "turf.pve" and war.members[1].side == 1 and war.members[1].merc == false)
    assert(war.sides[1].gang == "valentinos" and war.sides[2].gang == P.holders.kabuki, "the district's holders")
    for _, zone in ipairs(war.zones) do assert(zone.owner == 2, "the holders start with every zone") end
    assert(B.count(war, 2) == P.baseBots and B.count(war, 1) == 0, "1 human: " .. P.baseBots .. " gangers")
    assert(war.target == P.targetScore and war.timeLimitMs == P.timeLimitSeconds * 1000 and war.zoneRate[2] == P.holderZoneRate)
    advance(1000)
    assert(T.statusOf("turf.pve").phase == "running" and T.statusOf("turf.war").phase == "idle")
    assert(#T.bodiesOf(war) == 0, "no body in the first seconds of the VM")
    advance(4000)
    assert(#T.bodiesOf(war) == P.baseBots)
    for _, b in ipairs(war.bots) do
        local body = T.body(b.npcId)
        assert(R.inZone(war.zones[b.home].def, body.pos, CFG.capture.height), "a holder stands in its zone")
        assert(body.def.record == CFG.bots.records.tyger_claws[1] and body.def.loadout.combat.acquirePlayers == true)
    end
    flush(); advance(250)
    assert(war.state == "countdown")
    assert(T.noted(1, "Tyger Claws hold every zone"), "the countdown says what to do")
    advance(CFG.match.countdownSeconds * 1000)
    assert(war.state == "running")
    local hud = H.war(Turf.sharedView(war, T.now()), Turf.personalView(war, war.members[1], T.now()), Turf.boardRows(war), {})
    assert(hud.title == "GANG SWEEP" and hud.activity == "turf.pve" and hud.objective:find("Take the zones from Tyger Claws"))
    assert(T.sites[1].mode == "pve")

    -- kill the holder of A, then take A
    local guard = war.bots[1]
    assert(guard.home == 1)
    local base = T.now()
    for i = 0, 2 do T.setClock(base + i * 100); net("op77_turf:npcHit", 1, tostring(guard.npcId), 30) end
    T.setClock(base + 1200); net("op77_turf:npcHit", 1, tostring(guard.npcId), 30)
    advance(250)
    assert(guard.state == "down" and war.members[1].kills == 1)
    local A = war.site.zones[1]
    T.at(1, A.x, A.y, A.z, war.bucket)
    advance(16000)
    assert(war.zones[1].owner == 1 and war.members[1].captures == 1, "the fighter took zone A back")
    assert(guard.state == "alive" and not R.inZone(A, T.body(guard.npcId).pos, CFG.capture.height),
        "the holder came back at a zone it still holds")
    -- the holders' zones score at their rate: 2 zones x 0.5 = 1 point a second
    local s2 = war.sides[2].score
    advance(10000)
    assert(war.sides[2].score - s2 >= 9 and war.sides[2].score - s2 <= 11, "holder rate: " .. (war.sides[2].score - s2))

    -- long enough, then the win
    advance(P.rewards.minWarSeconds * 1000)
    assert(war.state == "running", "no winner yet")
    local resultsFrom, pushFrom, inf0 = #core.results + 1, #T.pushes + 1, T.influenceRecords
    war.sides[1].score = P.targetScore
    advance(1000)
    assert(war.state == "resolved" and war.winner == 1 and war.counted == true)
    local r = T.resultOf(1, resultsFrom)
    local rw = R.scaledRewards(CFG.rewards, P.reputationScale, P.rewards)
    assert(rw.win == math.floor(CFG.rewards.win * P.reputationScale + 0.5) and rw.win < CFG.rewards.win, "lower than the war")
    assert(r and r.activity == "turf.pve" and r.result.test == nil, "recorded by the core as usual")
    assert(r.result.reputation == rw.win + math.min(rw.perCapture + rw.perKill, rw.bonusCap), "scaled: " .. r.result.reputation)
    assert(r.result.stats.mode == "pve" and r.result.won == true)
    assert(r.result.recap and r.result.recap.detail == "Gang Sweep" and r.result.recap.matchId:match("^turf:pve:"))
    assert(T.influenceRecords == inf0, "no weekly influence for a sweep")
    local card = T.pushed(1, "result", "VICTORY", pushFrom)
    assert(lineOf(card, "Reputation") == "+" .. r.result.reputation and lineOf(card, "Who holds the city") == nil)
    assert(T.liveBodies() == 0, "the gang goes with the sweep")
    advance(CFG.match.scoreboardSeconds * 1000 + 500)
    assert(#Turf.sweeps == 0 and core.owned[1] == nil)
    local home = core.leaves[#core.leaves]
    assert(home.id == 1 and home.activity == "turf.pve" and home.opts.returnPlayer == true)

    -- ============================================================ too short to count
    T.addPlayer(2, "maelstrom")
    command("turf", 2, { "sweep", "badlands" })
    assert(T.lastReply.ok and Turf.sweepEntry(2))
    advance(1250)
    war = sweepOf(2)
    assert(war and war.site.id == "badlands" and war.sides[2].gang == P.holders.badlands)
    flush(); advance(250); advance(CFG.match.countdownSeconds * 1000)
    war.members[2].captures = 1
    resultsFrom, pushFrom = #core.results + 1, #T.pushes + 1
    war.sides[1].score = P.targetScore
    advance(1000)
    assert(war.state == "resolved" and war.counted == false)
    r = T.resultOf(2, resultsFrom)
    assert(r and r.activity == "turf.pve" and r.result.reputation == 0 and r.result.test == nil, "too short: nothing to farm")
    assert(lineOf(T.pushed(2, "result", nil, pushFrom), "Reputation") == "not counted (too short)")
    advance(CFG.match.scoreboardSeconds * 1000 + 500)
    assert(#Turf.sweeps == 0)

    -- ============================================================ a crew of three
    T.addPlayer(11, "valentinos"); T.addPlayer(12, "valentinos"); T.addPlayer(13, nil)
    local crew = squad(77, 11, { 11, 12, 13 })
    fire("op77_lightrp:activity:join", nil, 11, "turf.pve", crew)
    fire("op77_lightrp:activity:join", nil, 12, "turf.pve", crew)
    advance(2000)
    assert(#Turf.sweeps == 0, "the crew waits for its third member")
    assert(T.states[11].personal.mode == "pve" and T.states[11].personal.total == 2 and T.states[11].personal.min == 3)
    local lobby = H.lobby(T.states[11].personal, {})
    assert(lobby.title == "GANG SWEEP" and lobby.objective:find("gathering 2/3"))
    fire("op77_lightrp:activity:join", nil, 13, "turf.pve", crew)
    advance(250)
    local crewWar = sweepOf(11)
    assert(crewWar and #Turf.sweeps == 1 and sweepOf(12) == crewWar and sweepOf(13) == crewWar, "one sweep for the crew")
    assert(crewWar.squadKey == "squad:77" and crewWar.members[13].merc == true and crewWar.members[11].merc == false)
    assert(B.count(crewWar, 2) == R.pveBots(3, P) and R.pveBots(3, P) == 7, "3 humans: 7 gangers")
    flush(); advance(250)

    -- ============================================================ a late crew member
    T.addPlayer(21, nil); T.addPlayer(22, nil); T.addPlayer(23, nil)
    local late = squad(88, 21, { 21, 22, 23 })
    fire("op77_lightrp:activity:join", nil, 21, "turf.pve", late)
    fire("op77_lightrp:activity:join", nil, 22, "turf.pve", late)
    advance(1000)
    -- Light RP's queue panel: two of three, going at readyAt (published once, not every second)
    local sq = T.statusOf("turf.pve").queue
    assert(sq.v == 1 and #sq.lobbies == 1 and #sq.lobbies[1].players == 2 and sq.lobbies[1].need == 3
        and sq.lobbies[1].startsInMs and sq.lobbies[1].mode == nil, "the crew's line-up reaches the panel")
    local group = Turf.sweepEntry(21)
    assert(Turf.sweepQueueView(T.now()).lobbies[1].startsInMs == group.readyAt - T.now(), "it starts at readyAt")
    advance(P.gatherSeconds * 1000 - 500)
    local lateWar = sweepOf(21)
    assert(lateWar and #Turf.sweeps == 2 and B.count(lateWar, 2) == R.pveBots(2, P), "gathered long enough: in with two")
    flush(); advance(250); advance(CFG.match.countdownSeconds * 1000)
    assert(lateWar.state == "running")
    fire("op77_lightrp:activity:join", nil, 23, "turf.pve", late)
    assert(lateWar.members[23] and lateWar.members[23].side == 1 and core.owned[23] == "turf.pve", "straight into his crew's sweep")
    assert(B.count(lateWar, 2) == R.pveBots(3, P), "and more gangers")
    assert(#Turf.sweeps == 2)
    flush()

    -- ============================================================ maxSweeps: the next one waits
    T.addPlayer(31, "animals")
    fire("op77_lightrp:activity:join", nil, 31, "turf.pve", {})
    advance(3000)
    assert(#Turf.sweeps == P.maxSweeps and sweepOf(31) == nil and Turf.sweepEntry(31), "every slot taken: waits")
    assert(T.states[31].personal.waiting == true)
    assert(H.lobby(T.states[31].personal, {}).objective:find("slot"))
    assert(T.statusOf("turf.pve").queued == 1)
    local wq = T.statusOf("turf.pve").queue.lobbies[1]
    assert(wq.players[1] == 31 and wq.need == 1 and wq.mode == "Waiting for a free sweep" and wq.startsInMs == nil,
        "every slot taken: no countdown, it waits for a free sweep")

    -- the crew's sweep runs long enough; the member who did nothing earns nothing
    advance(P.rewards.minWarSeconds * 1000)
    crewWar.members[11].captures = 1
    resultsFrom = #core.results + 1
    crewWar.sides[1].score = P.targetScore
    advance(1000)
    assert(crewWar.state == "resolved" and crewWar.counted == true)
    local r11, r12 = T.resultOf(11, resultsFrom), T.resultOf(12, resultsFrom)
    assert(r11.result.reputation > 0, "captured: rewarded")
    assert(r12 and r12.result.reputation == 0, "no capture, no kill: nothing")
    advance(CFG.match.scoreboardSeconds * 1000 + 500)
    assert(sweepOf(31), "a slot freed: the next line-up goes in")

    -- ============================================================ a leaver, then Light RP stops
    resultsFrom = #core.results + 1
    fire("op77_lightrp:activity:leaveRequest", nil, 22, "turf.pve")
    local r22 = T.resultOf(22, resultsFrom)
    assert(r22 and r22.activity == "turf.pve" and r22.result.stats.forfeit == true and core.owned[22] == nil)
    assert(lateWar.state == "running", "his crew plays on")
    fire("op77_lightrp:activity:leaveRequest", nil, 31, "turf.war")
    assert(sweepOf(31), "another activity's leave is not this one")
    T.addPlayer(32, nil)
    fire("op77_lightrp:activity:join", nil, 32, "turf.pve", {})
    assert(Turf.sweepEntry(32))
    for id in pairs(core.owned) do core.owned[id] = nil end -- the stopping core returned them
    core.registered = {}                                    -- and forgot its providers
    fire("onResourceStop", nil, "op77_lightrp")
    assert(#Turf.sweeps == 0 and #Turf.sweepQueue == 0 and T.liveBodies() == 0, "every sweep void, every body gone")
    assert(lateWar.void and lateWar.state == "closed")
    local statuses = #core.statuses
    fire("op77_lightrp:activity:leaveRequest", nil, 999, "turf.war") -- anything that publishes
    assert(#core.statuses > statuses, "the war's status is published")
    for i = statuses + 1, #core.statuses do assert(core.statuses[i].activity ~= "turf.pve", "unregistered: no status") end
    fire("op77_lightrp:activity:ready", nil)
    host.threads[#host.threads]()
    assert(core.registered["turf.pve"] and T.statusOf("turf.pve").phase == "idle", "registered again")

    -- ============================================================ a PvP crew is never split
    command("turf.testing", 0, { "on" })
    T.addPlayer(41, "valentinos"); T.addPlayer(42, "maelstrom"); T.addPlayer(43, "maelstrom"); T.addPlayer(44, "valentinos")
    local five = squad(5, 41, { 41, 42, 45 })
    for _, id in ipairs({ 41, 42, 43, 44 }) do
        T.setClock(T.now() + 10)
        fire("op77_lightrp:activity:join", nil, id, "turf.war", (id == 41 or id == 42) and five or {})
    end
    command("turf.start", 0, { "kabuki" })
    war = Turf.war
    assert(war and war.members[41] and war.members[42] and war.members[41].side == war.members[42].side,
        "the crew fights on one side, whatever its gangs")
    assert(war.members[42].merc == true and war.members[43].side ~= war.members[41].side)
    assert(war.members[44] == nil and Turf.position(44), "the balance benches the solo, never a crew member")
    flush(); advance(250); advance(CFG.match.countdownSeconds * 1000)
    assert(war.state == "running")
    T.addPlayer(45, nil)
    fire("op77_lightrp:activity:join", nil, 45, "turf.war", five)
    advance(1000)
    assert(war.members[45] and war.members[45].side == war.members[41].side, "a late crew member joins his crew's side")
    assert(war.members[44] == nil, "the solo still waits for room")
end

T.run("pve_test", main, "turf.pve registration, solo sweep (holders on every zone, gangers at zones, HUD, kill + capture, "
    .. "holder zone rate), scaled results on turf.pve (no test flag, no influence), too short = 0, crew of 3 (one sweep, "
    .. "7 gangers, waits for all), late crew member + scaling, needs-action reputation, maxSweeps queueing + line-up view, "
    .. "leaver, Light RP stop, PvP crew never split (formed + late)")
