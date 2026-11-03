-- op77_turf and Light RP's activity lobby (join options v2), end to end through the real
-- wiring against a fake Light RP, a fake world and a fake Open77.npcs (tests/bot_host.lua):
--   registration (botFill only when bots work, pve + difficulties on turf.pve);
--   turf.pve difficulties (gang size, health, damage, objective profile, HUD tag);
--   turf.pve + options.fill.allies (count, side, never hostile to the crew or each other,
--   largest asked applied once, capped by seats and by the body budget, a late crew
--   member takes a seat back, normal ranked result); a friendly crew match (teams ->
--   sides, humans only, strangers stay in the queue, unranked, no influence); a bot-filled
--   match (bots per side, rival gang, unranked); a missing player's seat (gather timeout,
--   completed by a bot, the late player takes it back); refusal while the war slot is
--   busy (queue/lobby, running public war, staff schedule) without touching the public
--   war; staff bot mode unchanged; options.ranked = false on a public war and a sweep;
--   a ranked core match without bots counts like a public war.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test lobby_test.lua
local T = dofile("tests/bot_host.lua")
local host, core, npc = T.host, T.core, T.npc
local CFG, R, B, H = T.CFG, T.R, T.B, T.H
local P = CFG.pve
local fire, net, command, advance, flush = T.fire, T.net, T.command, T.advance, T.flush

-- op77_lightrp server/config/activities.lua pve.difficulties[].scaling
local SCALING = {
    standard = { enemies = 1, health = 1, damage = 1, ai = "standard" },
    hard = { enemies = 1.5, health = 1.5, damage = 1.25, ai = "veteran" },
    critical = { enemies = 2, health = 2.25, damage = 1.6, ai = "veteran" },
}

local function join(id, activity, opts) fire("op77_lightrp:activity:join", nil, id, activity, opts) end
local function pveJoin(id, difficulty, extra)
    local o = { ranked = true, difficulty = difficulty, scaling = SCALING[difficulty], site = "kabuki" }
    for k, v in pairs(extra or {}) do o[k] = v end
    join(id, "turf.pve", o)
end
local function sweepOf(id)
    for _, w in ipairs(Turf.sweeps) do if w.members[id] then return w end end
end
local function squad(id, leader, members) return { id = id, leader = leader, members = members } end
local function attitude(bot, towards)
    local row
    for _, a in ipairs(npc.attitudes) do if a.id == bot.npcId and a.towards == towards then row = a.attitude end end
    return row
end
local function lineOf(card, label)
    for _, l in ipairs(card.payload.lines) do if l.label == label then return l.value end end
end
local function toRunning(war)
    flush()
    advance(250)
    assert(war.state == "countdown", "countdown, not " .. tostring(war.state))
    advance(CFG.match.countdownSeconds * 1000)
    assert(war.state == "running")
end
local function closeAll()
    command("turf.stop", 0, { "all" })
    flush() -- (placements in flight land first)
    advance(CFG.match.scoreboardSeconds * 1000 + 1000)
    assert(Turf.war == nil and #Turf.sweeps == 0, "everything closed")
end
local function hudOf(war, id)
    return H.war(Turf.sharedView(war, T.now()), Turf.personalView(war, war.members[id], T.now()), Turf.boardRows(war), {})
end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

local function main()
    -- ============================================================ registration
    host.threads[1]()
    local warDef, pveDef = core.registered["turf.war"], core.registered["turf.pve"]
    assert(warDef.botFill == true, "turf.war declares bot fill (bots work on this build)")
    assert(pveDef.botFill == true, "turf.pve declares bot fill (allies need setAttitude: present)")
    assert(pveDef.pve == true and #pveDef.difficulties == 3 and pveDef.difficulties[1] == "standard"
        and pveDef.difficulties[2] == "hard" and pveDef.difficulties[3] == "critical", "the difficulties it plays")
    assert(warDef.pve == nil and warDef.difficulties == nil, "the war is no PvE")
    local setAttitude = Open77.npcs.setAttitude
    Open77.npcs.setAttitude = nil
    assert(TurfCore.definition("pve").botFill == nil and TurfCore.definition().botFill == true,
        "no per-player attitude: no allies, so no bot fill offered for the sweep")
    Open77.npcs.setAttitude = setAttitude
    local create = Open77.npcs.create
    Open77.npcs.create = nil
    assert(TurfCore.definition().botFill == nil, "no NPC API: no bot fill at all")
    Open77.npcs.create = create
    advance(6000) -- past the VM's body settle time

    -- ============================================================ difficulties (solo sweeps)
    local gangOf = { standard = 3, hard = 5, critical = 6 }        -- 3 x enemies, rounded
    local healthOf = { standard = 100, hard = 150, critical = 225 } -- bots.health x health
    local hitOf = { standard = 20, hard = 25, critical = 32 }      -- a 20-damage hit x damage
    local shotsOf = { standard = 3, hard = 5, critical = 7 }       -- 34-damage shots to drop one
    local pushOf = { standard = 1, hard = 2, critical = 3 }        -- pushShare 0.34 / 0.5 (veteran)
    local retaskOf = { standard = 6000, hard = 4000, critical = 4000 }
    local pid = 100
    for _, d in ipairs({ "standard", "hard", "critical" }) do
        pid = pid + 1
        T.addPlayer(pid, "valentinos")
        pveJoin(pid, d)
        advance(1250)
        local war = sweepOf(pid)
        assert(war and war.difficulty.id == d, d .. ": a sweep at its difficulty")
        assert(B.count(war, 2) == gangOf[d] and B.count(war, 1) == 0, d .. ": gang " .. B.count(war, 2))
        local push = 0
        for _, b in ipairs(war.bots) do
            assert(b.maxHealth == healthOf[d], d .. ": health " .. tostring(b.maxHealth))
            assert(b.ai and b.ai.retaskMs == retaskOf[d], d .. ": objective profile")
            if b.role == "push" then push = push + 1 end
        end
        assert(push == pushOf[d], d .. ": pushers " .. push)
        toRunning(war)
        assert(T.noted(pid, d == "standard" and "^Gang Sweep at" or ("^" .. d:upper() .. ": Gang Sweep at")), d .. ": the notice says it")
        advance(4000)
        assert(#T.bodiesOf(war, 2) == gangOf[d])
        for _, b in ipairs(war.bots) do
            local def = T.body(b.npcId).def
            assert(def.health == healthOf[d] and def.maxHealth == healthOf[d], d .. ": bodies built at the scaled health")
        end
        local hud = hudOf(war, pid)
        assert(hud.title == (d == "standard" and "GANG SWEEP" or ("GANG SWEEP · " .. d:upper())), hud.title)
        -- a ganger's hit costs more
        local g = war.bots[1]
        local hurt = #T.playerDamage
        T.setClock(T.now() + 1000)
        net("op77_turf:npcHurtMe", pid, tostring(g.npcId), 20)
        assert(#T.playerDamage == hurt + 1 and math.abs(T.playerDamage[#T.playerDamage].amount - hitOf[d]) < 0.01,
            d .. ": hit " .. tostring(T.playerDamage[#T.playerDamage].amount))
        -- and takes more shots to drop
        local shots = 0
        while T.body(g.npcId).alive and shots < 12 do
            T.setClock(T.now() + 1100)
            net("op77_turf:npcHit", pid, tostring(g.npcId), 34)
            shots = shots + 1
        end
        assert(shots == shotsOf[d], d .. ": shots " .. shots)
        closeAll()
    end

    -- ============================================================ allied bots (options.fill.allies)
    T.addPlayer(201, "valentinos")
    pveJoin(201, "hard", { fill = { allies = 3 } })
    advance(1250)
    local war = sweepOf(201)
    assert(war and B.count(war, 1) == 3 and B.count(war, 2) == gangOf.hard, "3 allies with the crew, the gang at its difficulty")
    for _, b in ipairs(war.bots) do
        if b.side == 1 then
            assert(b.role == "push" and not b.acquire, "allies take the zones, never acquire players")
            assert(b.maxHealth == CFG.bots.health and b.damageScale == nil and b.ai == nil, "allies get no enemy multiplier")
        else
            assert(b.maxHealth == healthOf.hard and b.damageScale == SCALING.hard.damage)
        end
    end
    toRunning(war)
    advance(5000)
    assert(#T.bodiesOf(war) == 3 + gangOf.hard)
    local allies, gang = T.bodiesOf(war, 1), T.bodiesOf(war, 2)
    for _, b in ipairs(allies) do
        local def = T.body(b.npcId).def
        assert(def.loadout.combat.group == war.botGroups[1] and def.loadout.combat.acquirePlayers == false)
        assert(def.record == CFG.bots.records.valentinos[1], "the crew's gang colours")
        assert(attitude(b, 201) == "friendly", "an ally is friendly to the crew")
    end
    for _, b in ipairs(gang) do
        assert(attitude(b, 201) == "hostile" and T.body(b.npcId).def.loadout.combat.group == war.botGroups[2])
    end
    local related = false
    for _, r in ipairs(npc.relations) do
        if r.a == war.botGroups[1] and r.b == war.botGroups[2] and r.attitude == "hostile" then related = true end
    end
    assert(related, "allies (one group: friendly to each other) and the gang are hostile")
    local hurt, applied = #T.playerDamage, #npc.applied
    T.setClock(T.now() + 1000)
    net("op77_turf:npcHurtMe", 201, tostring(allies[1].npcId), 30)
    net("op77_turf:npcHit", 201, tostring(allies[1].npcId), 30)
    net("op77_turf:npcCrossfire", 201, tostring(allies[1].npcId), tostring(allies[2].npcId), 20)
    assert(#T.playerDamage == hurt and #npc.applied == applied, "never hostile to the crew, nor to each other")
    assert(host.damage({ victim = 201, attacker = tostring(allies[1].npcId), amount = 10 }) == false, "the arbiter agrees")
    T.body(gang[1].npcId).authority = 201 -- (the reporter simulates the victim)
    net("op77_turf:npcCrossfire", 201, tostring(gang[1].npcId), tostring(allies[1].npcId), 20)
    assert(#npc.applied == applied + 1, "an ally's shot lands on the gang")
    -- PvE with allies keeps its normal ranked result
    advance(P.rewards.minWarSeconds * 1000)
    war.members[201].captures = 1
    local resultsFrom, inf0 = #core.results + 1, T.influenceRecords
    war.sides[1].score = P.targetScore
    advance(1000)
    assert(war.state == "resolved" and war.counted == true)
    local r = T.resultOf(201, resultsFrom)
    assert(r and r.result.unranked == nil and r.result.test == nil and r.result.reputation > 0, "ranked as usual")
    assert(T.influenceRecords == inf0)
    advance(CFG.match.scoreboardSeconds * 1000 + 1000)
    assert(#Turf.sweeps == 0 and T.liveBodies() == 0)

    -- the largest asked, applied once per sweep; a late crew member takes a seat back
    T.addPlayer(401, "valentinos"); T.addPlayer(402, "valentinos"); T.addPlayer(403, nil)
    local crew = squad(40, 401, { 401, 402, 403 })
    pveJoin(401, "standard", { squad = crew, fill = { allies = 2 } })
    pveJoin(402, "standard", { squad = crew, fill = { allies = 6 } })
    advance(P.gatherSeconds * 1000 + 500)
    war = sweepOf(401)
    assert(war and sweepOf(402) == war and war.members[403] == nil, "in with two after the gather")
    assert(B.count(war, 1) == 6, "largest asked (6), not the sum, capped to the 6 free seats: " .. B.count(war, 1))
    assert(B.count(war, 2) == R.sweepGang(2, P, R.difficulty("standard", SCALING.standard)))
    toRunning(war)
    pveJoin(403, "critical", { squad = crew, fill = { allies = 6 } })
    assert(war.members[403] and war.members[403].side == 1, "the third member joins his crew")
    assert(war.difficulty.id == "standard", "one difficulty per sweep: the first join's")
    assert(B.count(war, 2) == 7 and B.count(war, 1) == 5, "3 humans: 7 gangers, an ally gave its seat back (8 seats)")
    closeAll()

    -- the body budget: a critical crew of three
    T.addPlayer(301, nil); T.addPlayer(302, nil); T.addPlayer(303, nil)
    local trio = squad(30, 301, { 301, 302, 303 })
    for _, id in ipairs({ 301, 302, 303 }) do pveJoin(id, "critical", { squad = trio, fill = { allies = 5 } }) end
    advance(250)
    war = sweepOf(301)
    assert(war and B.count(war, 2) == P.maxBots, "critical x2 = 14, capped to the gang budget " .. P.maxBots)
    assert(B.count(war, 1) == P.maxBodies - P.maxBots, "5 asked, 5 seats, the body budget leaves " .. (P.maxBodies - P.maxBots))
    closeAll()

    -- ============================================================ a friendly crew match
    local four = { 501, 502, 503, 504 }
    for _, id in ipairs(four) do T.addPlayer(id, "valentinos") end
    local crewF = squad(50, 501, four)
    local teams = { { 501, 502 }, { 503, 504 } }
    for _, id in ipairs(four) do
        join(id, "turf.war", { ranked = false, squad = crewF, site = "badlands",
            match = { id = "match:1", friendly = true, format = "2v2", players = four, teams = teams, side = id <= 502 and 1 or 2 } })
    end
    war = Turf.war
    assert(war and war.match and war.match.id == "match:1" and war.match.friendly == true and war.unranked == true,
        "every player in, the friendly war starts")
    assert(war.site.id == "badlands" and Turf.matchGather == nil and #Turf.queue == 0)
    for _, id in ipairs(four) do
        assert(war.members[id].side == (id <= 502 and 1 or 2) and core.owned[id] == "turf.war", "teams -> sides")
    end
    assert(war.bots == nil and not war.botWar, "humans only")
    assert(war.sides[1].gang == "valentinos" and war.sides[2].gang == nil and war.members[503].merc == true,
        "a split inside one gang: side 2 plays colourless")
    T.addPlayer(509, "maelstrom")
    join(509, "turf.war", { ranked = true })
    assert(Turf.position(509) and war.members[509] == nil and T.noted(509, "private match"), "a stranger queues, never joins")
    toRunning(war)
    assert(T.noted(501, "^FRIENDLY MATCH"))
    assert(Turf.sharedView(war, T.now()).tag == "FRIENDLY" and hudOf(war, 501).title == "TURF WAR · FRIENDLY")
    assert(T.statusOf("turf.war").detail:find("Friendly match"))
    advance(5000)
    assert(war.members[509] == nil, "never joined by strangers")
    resultsFrom, inf0 = #core.results + 1, T.influenceRecords
    local pushFrom = #T.pushes + 1
    war.sides[1].score = CFG.match.targetScore
    advance(1000)
    assert(war.state == "resolved" and war.counted == false)
    for _, id in ipairs(four) do
        r = T.resultOf(id, resultsFrom)
        assert(r and r.activity == "turf.war" and r.result.unranked == true and r.result.test == nil and r.result.reputation == 0,
            "unranked, nothing earned")
    end
    assert(T.influenceRecords == inf0, "no gang influence, not even a history row")
    local card = T.pushed(501, "result", "VICTORY", pushFrom)
    assert(lineOf(card, "Reputation") == "not counted (friendly match)" and lineOf(card, "Who holds the city") == nil)
    advance(CFG.match.scoreboardSeconds * 1000 + 1000)
    assert(Turf.war == nil and core.owned[501] == nil)
    assert(Turf.position(509) and Turf.lobby == nil, "the stranger still waits for a public war")
    fire("op77_lightrp:activity:leaveRequest", nil, 509, "turf.war")
    assert(#Turf.queue == 0)

    -- ============================================================ a bot-filled match
    T.addPlayer(601, "tyger_claws"); T.addPlayer(602, nil)
    local duo = squad(60, 601, { 601, 602 })
    for _, id in ipairs({ 601, 602 }) do
        join(id, "turf.war", { ranked = false, squad = duo, fill = { allies = 2, enemies = 4 },
            match = { id = "match:2", friendly = false, format = "4v4", players = { 601, 602 }, teams = { { 601, 602 }, {} },
                side = 1, bots = { 2, 4 } } })
    end
    war = Turf.war
    assert(war and war.match and war.matchBots[1] == 2 and war.matchBots[2] == 4 and war.unranked and not war.botWar)
    assert(B.count(war, 1) == 2 and B.count(war, 2) == 4, "match.bots per side")
    assert(war.sides[1].gang == "tyger_claws" and war.sides[2].gang == R.rivalGang(CFG.bots.gangOrder, "tyger_claws", CFG.gangs),
        "the bot side wears a rival gang's colours")
    toRunning(war)
    advance(4000)
    assert(#T.bodiesOf(war) == 6)
    for _, b in ipairs(war.bots) do
        local def = T.body(b.npcId).def
        assert(def.loadout.combat.acquirePlayers == (b.side == 2))
        for _, id in ipairs({ 601, 602 }) do
            assert(attitude(b, id) == (b.side == 1 and "friendly" or "hostile"), "teammates friendly, the other side hostile")
        end
    end
    assert(hudOf(war, 601).title == "TURF WAR · UNRANKED")
    resultsFrom, inf0 = #core.results + 1, T.influenceRecords
    pushFrom = #T.pushes + 1
    war.sides[2].score = CFG.match.targetScore
    advance(1000)
    r = T.resultOf(601, resultsFrom)
    assert(r and r.result.unranked == true and r.result.test == nil and r.result.stats.bots == 6 and r.result.won == false)
    assert(T.influenceRecords == inf0)
    assert(lineOf(T.pushed(601, "result", "DEFEAT", pushFrom), "Reputation") == "not counted (unranked)")
    advance(CFG.match.scoreboardSeconds * 1000 + 1000)
    assert(Turf.war == nil and T.liveBodies() == 0)
    local capped = R.capBots({ 2, 0 }, { 9, 9 }, CFG.bots.maxPerSide, CFG.bots.maxBots)
    assert(capped[1] == 4 and capped[2] == 6, "bots capped per side and in total, teammates first")

    -- a missing player: the gather times out, a bot takes his seat, he takes it back
    T.addPlayer(701, nil); T.addPlayer(702, nil)
    local m3 = { id = "match:3", friendly = false, players = { 701, 702 }, teams = { { 701 }, { 702 } }, bots = { 1, 1 } }
    join(701, "turf.war", { ranked = false, match = m3 })
    assert(Turf.matchGather and Turf.war == nil, "waits for 702")
    advance(1000)
    assert(T.statusOf("turf.war").detail:find("private match"), "the hub shows the slot taken")
    advance(CFG.match.gatherSeconds * 1000)
    war = Turf.war
    assert(war and war.match.id == "match:3" and war.members[702] == nil)
    assert(B.count(war, 1) == 1 and B.count(war, 2) == 2, "side 2: its bot + one for 702's seat")
    toRunning(war)
    join(702, "turf.war", { ranked = false, match = m3 })
    assert(war.members[702] and war.members[702].side == 2 and core.owned[702] == "turf.war", "late, on his team's side")
    assert(B.count(war, 2) == 1, "the bot that held his seat makes room")
    closeAll()

    -- ============================================================ the war slot is busy: refused
    command("turf.testing", 0, { "on" })
    T.addPlayer(801, "valentinos"); T.addPlayer(802, "maelstrom")
    join(801, "turf.war", { ranked = true }); join(802, "turf.war", { ranked = true })
    advance(250)
    assert(Turf.lobby, "the public lobby opened")
    T.addPlayer(811, nil); T.addPlayer(812, nil)
    local busy = { id = "match:4", friendly = true, players = { 811, 812 }, teams = { { 811 }, { 812 } } }
    join(811, "turf.war", { ranked = false, match = busy })
    join(812, "turf.war", { ranked = false, match = busy })
    assert(Turf.matchGather == nil and core.owned[811] == nil and core.owned[812] == nil)
    assert(T.noted(811, "Turf War is busy") and T.noted(812, "Turf War is busy"), "each match player is told")
    assert(#Turf.queue == 2 and Turf.lobby, "the public lobby is untouched")
    advance(CFG.lobby.seconds * 1000)
    local pub = Turf.war
    assert(pub and not pub.match and pub.members[801] and pub.members[802])
    T.addPlayer(813, nil); T.addPlayer(814, nil)
    local busy2 = { id = "match:5", friendly = false, players = { 813, 814 }, teams = { { 813, 814 }, {} }, bots = { 0, 2 } }
    join(813, "turf.war", { ranked = false, match = busy2 })
    join(814, "turf.war", { ranked = false, match = busy2 })
    assert(Turf.war == pub and pub.match == nil and count(pub.members) == 2 and Turf.matchGather == nil, "the public war is untouched")
    assert(T.noted(813, "a public turf war is on") and T.noted(814, "Turf War is busy") and core.owned[813] == nil)
    closeAll()
    command("turf.schedule", 0, { "kabuki", "10" })
    assert(Turf.schedule)
    T.addPlayer(815, nil)
    join(815, "turf.war", { ranked = false, match = { id = "match:6", friendly = false, players = { 815 }, teams = { { 815 }, {} },
        bots = { 0, 3 } } })
    assert(Turf.matchGather == nil and Turf.war == nil and T.noted(815, "staff scheduled"), "a staff war holds the slot")
    command("turf.schedule", 0, { "cancel" })
    T.addPlayer(816, nil)
    join(816, "turf.war", { ranked = true })
    T.addPlayer(817, nil)
    join(817, "turf.war", { ranked = false, match = { id = "match:7", friendly = false, players = { 817 }, teams = { { 817 }, {} },
        bots = { 0, 3 } } })
    assert(Turf.war == nil and T.noted(817, "queued for the public turf war"), "a public queue holds the slot too")
    fire("op77_lightrp:activity:leaveRequest", nil, 816, "turf.war")
    command("turf.testing", 0, { "off" })

    -- ============================================================ staff bot mode, unchanged
    fire("op77_lightrp:activity:bots", nil, true)
    T.addPlayer(901, "valentinos")
    join(901, "turf.war", { ranked = false, site = "kabuki" }) -- the core marks every bot-mode entry unranked
    advance(250)
    assert(Turf.lobby, "one fighter opens the lobby")
    advance(CFG.lobby.seconds * 1000)
    war = Turf.war
    assert(war and war.botWar and war.match == nil and B.count(war, 1) == 2 and B.count(war, 2) == 3, "fill as before")
    assert(Turf.sharedView(war, T.now()).tag == nil and hudOf(war, 901).title == "TURF WAR", "no new wording")
    toRunning(war)
    resultsFrom, inf0 = #core.results + 1, T.influenceRecords
    pushFrom = #T.pushes + 1
    war.sides[1].score = CFG.match.targetScore
    advance(1000)
    r = T.resultOf(901, resultsFrom)
    assert(r and r.result.test == true and r.result.unranked == nil, "flagged test, as before")
    assert(lineOf(T.pushed(901, "result", "VICTORY", pushFrom), "Reputation") == "not counted (bot war)")
    assert(T.influenceRecords == inf0)
    advance(CFG.match.scoreboardSeconds * 1000 + 1000)
    fire("op77_lightrp:activity:bots", nil, false)

    -- ============================================================ options.ranked = false elsewhere
    -- a public war with an unranked entry: nothing counts for anyone
    command("turf.testing", 0, { "on" })
    T.addPlayer(1001, "valentinos"); T.addPlayer(1002, "maelstrom")
    join(1001, "turf.war", { ranked = true }); join(1002, "turf.war", { ranked = false })
    advance(250); advance(CFG.lobby.seconds * 1000)
    war = Turf.war
    assert(war and war.unranked and not war.match and Turf.sharedView(war, T.now()).tag == "UNRANKED")
    toRunning(war)
    advance(CFG.rewards.minWarSeconds * 1000)
    resultsFrom, inf0 = #core.results + 1, T.influenceRecords
    war.sides[1].score = CFG.match.targetScore
    advance(1000)
    assert(war.counted == false and T.influenceRecords == inf0, "no influence")
    assert(T.resultOf(1001, resultsFrom).result.unranked == true and T.resultOf(1001, resultsFrom).result.reputation == 0)
    advance(CFG.match.scoreboardSeconds * 1000 + 1000)
    command("turf.testing", 0, { "off" })
    -- a sweep entry Light RP marked unranked
    T.addPlayer(1101, nil)
    pveJoin(1101, "standard", { ranked = false })
    advance(1250)
    war = sweepOf(1101)
    assert(war and war.unranked)
    toRunning(war)
    resultsFrom = #core.results + 1
    war.sides[1].score = P.targetScore
    advance(1000)
    r = T.resultOf(1101, resultsFrom)
    assert(r and r.activity == "turf.pve" and r.result.unranked == true and r.result.reputation == 0)
    advance(CFG.match.scoreboardSeconds * 1000 + 1000)

    -- a ranked core match without bots counts like a public war (influence written)
    T.addPlayer(1201, "valentinos"); T.addPlayer(1202, "maelstrom")
    local ranked = { id = "match:8", ranked = true, friendly = false, players = { 1201, 1202 }, teams = { { 1201 }, { 1202 } } }
    join(1201, "turf.war", { ranked = true, match = ranked }); join(1202, "turf.war", { ranked = true, match = ranked })
    war = Turf.war
    assert(war and war.match and not war.unranked and war.bots == nil and Turf.sharedView(war, T.now()).tag == "PRIVATE")
    assert(war.sides[1].gang == "valentinos" and war.sides[2].gang == "maelstrom")
    toRunning(war)
    resultsFrom, inf0 = #core.results + 1, T.influenceRecords
    war.sides[1].score = CFG.match.targetScore
    advance(1000)
    assert(T.influenceRecords == inf0 + 1 and T.resultOf(1201, resultsFrom).result.unranked == nil, "ranked: the war's own bookkeeping")
    advance(CFG.match.scoreboardSeconds * 1000 + 1000)
    assert(Turf.war == nil)
end

T.run("lobby_test", main, "registration (botFill gated on the NPC API, pve + difficulties), difficulties (gang 3/5/6, "
    .. "health 100/150/225, hit x1/1.25/1.6, shots 3/5/7, pushers + retask, HUD tag), allied bots (side 1, friendly, "
    .. "unscaled, largest asked once, seats + body budget caps, late member takes a seat back, ranked result), friendly "
    .. "match (teams -> sides, humans only, strangers queue, unranked, no influence), bot-filled match (bots per side, "
    .. "rival gang, unranked), missing seat (gather timeout, bot, late join), busy slot refusals (lobby, running war, "
    .. "schedule, queue) without touching the public war, staff bot mode unchanged, ranked=false war + sweep, ranked match")
