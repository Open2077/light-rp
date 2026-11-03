-- op77_turf staff bot mode, end to end through the real wiring (server/main.lua) against
-- a fake Light RP, a fake world and a fake Open77.npcs (tests/bot_host.lua):
--   registration (turf.war + turf.pve, activityBots read, leftover bodies swept); the
--   switch (the bots event, activityBots at a re-registration); a solo start; fill and
--   balance (records, groups, attitudes, bucket); objectives as tasks, gated by combat;
--   capture by bot positions; player -> bot hits, death, credit, corpse, rebuild;
--   bot -> player hits and kill credit; crossfire; a body the platform removed; the
--   board and HUD rows; results flagged test, no influence; cleanup at the end; bot mode
--   off starts no bot war; the last human leaving; the resource stopping.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test bots_test.lua
local T = dofile("tests/bot_host.lua")
local host, core, npc = T.host, T.core, T.npc
local CFG, B, H = T.CFG, T.B, T.H
local fire, net, command, advance, flush = T.fire, T.net, T.command, T.advance, T.flush

local function taskOf(bot, kind, from)
    for i = from or 1, #npc.tasks do
        local t = npc.tasks[i]
        if t.id == bot.npcId and (kind == nil or t.kind == kind) then return t end
    end
end

local function main()
    -- ============================================================ registration
    -- A body a previous run of this resource left behind (hot reload).
    npc.bodies["77"] = { id = 77, def = {}, pos = { x = 0, y = 0, z = 0 }, alive = true, health = 100, authority = 0 }
    host.threads[1]() -- the registration thread
    assert(T.liveBodies() == 0 and npc.removed[1] == 77, "a previous run's body is removed before the first war")
    local pvp, pve = core.registered["turf.war"], core.registered["turf.pve"]
    assert(pvp and pvp.kind == "pvp" and core.registerCount == 2)
    assert(pve and pve.kind == "event" and pve.label == "Gang Sweep" and pve.minPlayers == 1)
    assert(core.botsCalls == 1 and Turf.bots == false, "activityBots is read after the registration")
    assert(T.statusOf("turf.war").phase == "idle" and T.statusOf("turf.pve").phase == "idle")
    assert(host.net["op77_lightrp:activity:bots"] == nil, "the bots event is never a network event")

    -- ============================================================ the switch
    fire("op77_lightrp:activity:bots", nil, true)
    assert(Turf.bots == true and Turf.botMode() and Turf.minPlayers() == 1 and Turf.minAccounts() == 1)
    assert(T.statusOf("turf.war").detail:find("bot mode"), "the hub says so")
    fire("op77_lightrp:activity:bots", nil, false)
    assert(Turf.bots == false and Turf.minPlayers() > 1)
    core.bots = true
    fire("op77_lightrp:activity:ready", nil)
    host.threads[#host.threads]()
    assert(Turf.bots == true and core.botsCalls == 2, "activityBots at a re-registration")

    -- ============================================================ solo start, fill and balance
    T.addPlayer(1, "valentinos")
    fire("op77_lightrp:activity:join", nil, 1, "turf.war", { site = "kabuki" })
    assert(#Turf.queue == 1)
    advance(250)
    assert(Turf.lobby, "one fighter opens the lobby in bot mode")
    advance(CFG.lobby.seconds * 1000)
    local war = Turf.war
    assert(war and war.botWar and war.state == "placing" and war.site.id == "kabuki")
    assert(core.owned[1] == "turf.war")
    assert(war.sides[1].gang == "valentinos" and war.sides[2].gang == "maelstrom", "the empty side gets a rival gang")
    assert(B.count(war, 1) == 2 and B.count(war, 2) == 3, "1 human: you + 2 teammates vs 3")
    assert(war.botGroups[1] ~= war.botGroups[2])
    local made = #npc.created
    advance(250)
    assert(#npc.created - made <= 1, "one body at a time")
    advance(3000)
    assert(#T.bodiesOf(war) == 5, "every bot has a body")
    for _, c in ipairs(npc.created) do
        assert(c.def.bucket == war.bucket, "bots live in the war bucket only")
        assert(c.def.aiMode == 2 and c.def.damagePolicy == 0, "native combat AI, mortal")
        assert(c.def.behavior and c.def.behavior.hitPricing == "resource", "hits priced by this resource only")
    end
    for _, b in ipairs(war.bots) do
        local def = T.body(b.npcId).def
        assert(def.loadout.combat.group == war.botGroups[b.side], "one relationship group per side")
        assert(def.loadout.combat.acquirePlayers == (b.side == 2), "only a side without humans goes for players")
        assert(def.record == CFG.bots.records[war.sides[b.side].gang][1], "the gang's own record")
        assert(b.name:sub(1, 6) == "[BOT] " and b.id < 0)
        local row
        for _, a in ipairs(npc.attitudes) do if a.id == b.npcId and a.towards == 1 then row = a.attitude end end
        assert(row == (b.side == 1 and "friendly" or "hostile"), "attitude of " .. b.name .. " towards the fighter: " .. tostring(row))
    end
    assert(#npc.relations == 1 and npc.relations[1].attitude == "hostile" and npc.relations[1].a == war.botGroups[1]
        and npc.relations[1].b == war.botGroups[2], "the two groups are hostile")

    -- board, shared view, HUD
    local rows = Turf.boardRows(war)
    local botRows = 0
    for _, r in ipairs(rows) do
        if r.bot then botRows = botRows + 1; assert(r.id < 0 and r.name:find("^%[BOT%] ")) end
    end
    assert(#rows == 6 and botRows == 5)
    local view = Turf.sharedView(war, T.now())
    assert(view.sides[1].count == 3 and view.sides[2].count == 3 and view.sides[2].bots == 3)
    flush()
    advance(250)
    assert(war.state == "countdown")
    advance(CFG.match.countdownSeconds * 1000)
    assert(war.state == "running")
    local t0 = T.now()
    local hud = H.war(Turf.sharedView(war, T.now()), Turf.personalView(war, war.members[1], T.now()), Turf.boardRows(war), {})
    local hudBots = 0
    for _, r in ipairs(hud.scoreboard.rows) do if r.name:find("^%[BOT%] ") then hudBots = hudBots + 1 end end
    assert(hud.title == "TURF WAR" and hud.activity == "turf.war" and hudBots == 5, "the HUD shows the bots")
    local guarded = H.war(view, { id = 1, side = 1 }, { { id = -1, name = "Rook", bot = true, side = 2, kills = 0, deaths = 0,
        captures = 0, score = 0 } }, {})
    assert(guarded.scoreboard.rows[1].name == "[BOT] Rook", "a bot row always carries the prefix")

    -- objectives: movement-channel tasks only, issued at FIGHT
    for _, b in ipairs(war.bots) do assert(taskOf(b, "moveTo") or taskOf(b, "guard"), "an objective for " .. b.name) end
    for _, t in ipairs(npc.tasks) do
        if t.kind == "clear" and t.reason == "retask" then assert(t.channel == 1, "the movement channel only") end
    end

    -- ============================================================ capture by bot positions
    local A = war.site.zones[1]
    local X = war.bots[3] -- side 2's first: a guard of zone A
    assert(X.side == 2 and X.role == "guard" and X.home == 1)
    T.botAt(X, A.x + 1, A.y, A.z)
    advance(5000)
    -- a fight names it: no new destination while it fights
    fire("onNpcDamaged", nil, X.npcId, "player:1", 5, 95)
    local mark = #npc.tasks
    advance(4000)
    assert(taskOf(X, nil, mark + 1) == nil, "no new objective while it fights")
    advance(2000)
    assert(taskOf(X, "guard", mark + 1), "arrived and quiet: a guard leash on its zone")
    assert(war.zones[1].capturing == 2 and war.zones[1].owner == nil)
    local feedMark = #T.pushes
    advance(5000)
    assert(war.zones[1].owner == 2, "the bot took zone A on its own: " .. tostring(T.now() - t0))
    assert(X.captures == 1 and war.sides[2].score >= CFG.scoring.captureBonus)
    assert(T.pushed(1, "banner", "ZONE A LOST", feedMark), "the fighter sees it")

    -- ============================================================ player -> bot hits, death, credit, rebuild
    local Y = war.bots[4]
    assert(Y.side == 2)
    local key = tostring(Y.npcId)
    local applied0 = #npc.applied
    net("op77_turf:npcHit", 1, tostring(war.bots[1].npcId), 30) -- a teammate
    net("op77_turf:npcHit", 1, "123456", 30)                     -- nobody's
    net("op77_turf:npcHit", 1, { evil = true }, 30)              -- junk
    assert(#npc.applied == applied0, "same side, unknown and junk ids are refused")
    local base = T.now()
    net("op77_turf:npcHit", 1, key, 500)
    T.setClock(base + 100); net("op77_turf:npcHit", 1, key, 30)
    T.setClock(base + 200); net("op77_turf:npcHit", 1, key, 26)
    T.setClock(base + 300); net("op77_turf:npcHit", 1, key, 10)
    assert(#npc.applied == applied0 + 3, "the fourth hit of the second is over the rate")
    assert(npc.applied[applied0 + 1].amount == CFG.bots.damage.maxPerHit and npc.applied[applied0 + 1].tag == "player:1",
        "clamped, attributed")
    assert(T.body(Y.npcId).health == 100 - 34 - 30 - 26)
    T.setClock(base + 1300); net("op77_turf:npcHit", 1, key, 30)
    assert(T.body(Y.npcId).alive == false)
    local kills, s1 = war.members[1].kills, war.sides[1].score
    advance(250) -- the platform's onNpcDied
    assert(Y.state == "down" and Y.deaths == 1 and war.members[1].kills == kills + 1, "the shooter gets the kill")
    assert(war.sides[1].score == s1 + CFG.scoring.killPoints)
    assert(T.pushed(1, "feed", "P1 eliminated %[BOT%]"))
    local oldId, downAt = Y.npcId, Y.downAt
    advance(downAt + CFG.bots.corpseLingerMs + 250 - T.now())
    assert(Y.npcId == nil and T.body(oldId) == nil and B.byNpc[key] == nil, "the corpse goes")
    advance(downAt + CFG.life.respawnSeconds * 1000 - 250 - T.now())
    assert(Y.npcId == nil and Y.state == "down", "not before the respawn delay")
    advance(500)
    assert(Y.npcId ~= nil and Y.npcId ~= oldId and Y.state == "alive", "rebuilt: a fresh body")

    -- ============================================================ bot -> player hits and kill credit
    local Z = war.bots[5]
    assert(Z.side == 2 and Z.state == "alive")
    local hurt0 = #T.playerDamage
    net("op77_turf:npcHurtMe", 1, tostring(Z.npcId), 80)
    local hit = T.playerDamage[#T.playerDamage]
    assert(#T.playerDamage == hurt0 + 1 and hit.id == 1 and hit.amount == CFG.bots.damage.maxPerHit and hit.attacker == Z.npcId
        and hit.cause == "firearm", "the server applies the clamped hit, the bot named")
    net("op77_turf:npcHurtMe", 1, tostring(war.bots[1].npcId), 30)
    assert(#T.playerDamage == hurt0 + 1, "a teammate bot never hurts him")
    assert(host.damage({ victim = 1, attacker = tostring(Z.npcId), amount = 10 }) == true, "the arbiter lets the enemy bot through")
    assert(host.damage({ victim = 1, attacker = tostring(war.bots[1].npcId), amount = 10 }) == false, "not a teammate")
    assert(host.damage({ victim = tostring(Z.npcId), attacker = 1, amount = 10 }) == nil, "a bot's pricing is ours")
    T.pl[1].phase = "dead"
    local zk = Z.kills
    fire("open77:playerKilled", nil, 1, nil)
    assert(war.members[1].down and war.members[1].deaths == 1 and Z.kills == zk + 1, "the bot that hit him gets the kill")
    assert(T.pushed(1, "feed", "%[BOT%] .- eliminated P1"))
    advance(CFG.life.respawnSeconds * 1000 + 500)
    assert(not war.members[1].down, "the fighter respawns")

    -- ============================================================ crossfire
    local V, K = Z, war.bots[1]
    local applied1 = #npc.applied
    net("op77_turf:npcCrossfire", 1, tostring(V.npcId), tostring(K.npcId), 20)
    assert(#npc.applied == applied1 + 1 and npc.applied[#npc.applied].tag == "bot:" .. tostring(K.id), "bot against bot")
    T.body(V.npcId).authority = 2
    T.setClock(T.now() + 200)
    net("op77_turf:npcCrossfire", 1, tostring(V.npcId), tostring(K.npcId), 20)
    assert(#npc.applied == applied1 + 1, "only the victim's lease holder reports")
    T.body(V.npcId).authority = 1
    net("op77_turf:npcCrossfire", 1, tostring(war.bots[2].npcId), tostring(K.npcId), 20)
    assert(#npc.applied == applied1 + 1, "same side")

    -- ============================================================ a body the platform removed
    local lost = war.bots[2].npcId
    npc.bodies[tostring(lost)] = nil -- the platform dropped it on its own
    fire("onNpcRemoved", nil, lost, "streaming")
    assert(war.bots[2].npcId == nil and war.bots[2].state == "pending")
    advance(CFG.bots.corpseLingerMs + 500)
    assert(war.bots[2].npcId ~= nil and war.bots[2].npcId ~= lost, "rebuilt")

    -- ============================================================ results: test, no influence
    local resultsFrom, pushFrom, inf0 = #core.results + 1, #T.pushes + 1, T.influenceRecords
    war.sides[1].score = CFG.match.targetScore
    advance(1000)
    assert(war.state == "resolved" and war.winner == 1 and war.counted == false)
    local r = T.resultOf(1, resultsFrom)
    assert(r and r.activity == "turf.war" and r.result.test == true, "a bot war's result is flagged test")
    assert(r.result.stats.bots == 5 and r.result.won == true)
    local bots = 0
    for _, row in ipairs(r.result.recap.rows) do if row.bot then bots = bots + 1; assert(row.id < 0) end end
    assert(bots >= 5, "the bots on the recap board: " .. bots)
    local countedLine
    for _, line in ipairs(r.result.recap.lines) do if line.label == "Counted" then countedLine = line.value end end
    assert(countedLine == "not counted (bot war)")
    assert(T.influenceRecords == inf0, "no influence write for a war with bots")
    local card = T.pushed(1, "result", "VICTORY", pushFrom)
    local line
    for _, l in ipairs(card.payload.lines) do if l.label == "Reputation" then line = l.value end end
    assert(line == "not counted (bot war)", tostring(line))
    assert(T.liveBodies() == 0, "every bot body goes at the end")
    for _, b in ipairs(war.bots) do assert(b.npcId == nil and b.state == "gone") end
    assert(#Turf.boardRows(war) == 6, "the end board keeps their rows")
    advance(CFG.match.scoreboardSeconds * 1000 + 500)
    assert(Turf.war == nil and core.owned[1] == nil)

    -- ============================================================ bot mode off: no bot war
    fire("op77_lightrp:activity:bots", nil, false)
    T.addPlayer(2, "maelstrom")
    fire("op77_lightrp:activity:join", nil, 2, "turf.war", {})
    advance(1000)
    assert(Turf.lobby == nil and Turf.war == nil, "bot mode off: one fighter waits")
    command("turf.start", 0, { "kabuki" })
    assert(Turf.war == nil and T.lastReply.ok == false, "and staff cannot force it")
    fire("op77_lightrp:activity:leaveRequest", nil, 2, "turf.war")
    assert(#Turf.queue == 0)

    -- ============================================================ the last human leaves
    fire("op77_lightrp:activity:bots", nil, true)
    T.addPlayer(3, nil)
    npc.refuse[CFG.bots.records.maelstrom[1]] = "unknown_record"
    fire("op77_lightrp:activity:join", nil, 3, "turf.war", {})
    command("turf.start", 0, { "kabuki" })
    war = Turf.war
    assert(war and war.botWar and war.sides[1].gang == nil and war.sides[2].gang == "maelstrom", T.lastReply.text)
    advance(3000)
    assert(#T.bodiesOf(war) == 5)
    for _, b in ipairs(war.bots) do
        local def = T.body(b.npcId).def
        if b.side == 1 then assert(def.template == CFG.bots.fallback[1], "no gang: the fallback template")
        else assert(def.record == CFG.bots.records.maelstrom[2], "a refused record: the next one") end
    end
    flush(); advance(250); advance(CFG.match.countdownSeconds * 1000)
    assert(war.state == "running")
    resultsFrom = #core.results + 1
    fire("op77_lightrp:activity:leaveRequest", nil, 3, "turf.war")
    assert(war.void and war.state == "resolved", "the last human gone: the war is void")
    local r3 = T.resultOf(3, resultsFrom)
    assert(r3 and r3.result.test == true and r3.result.stats.forfeit == true)
    assert(T.liveBodies() == 0, "and its bots go")
    advance(CFG.match.scoreboardSeconds * 1000 + 500)
    assert(Turf.war == nil)

    -- ============================================================ the resource stops
    T.addPlayer(4, "tyger_claws")
    fire("op77_lightrp:activity:join", nil, 4, "turf.war", {})
    command("turf.start", 0, { "kabuki" })
    war = Turf.war
    advance(3000)
    assert(war and #T.bodiesOf(war) == 5)
    fire("onResourceStop", nil, "op77_turf")
    assert(T.liveBodies() == 0 and B.stopping, "every body goes with the resource")
    local created = #npc.created
    advance(2000)
    assert(#npc.created == created, "no body while the resource stops")
end

T.run("bots_test", main, "registration + activityBots, switch (event + re-registration), solo start, fill/balance "
    .. "(records, groups, attitudes, bucket), tasks gated by combat, capture by bots, player->bot hits/death/credit/"
    .. "corpse/rebuild, bot->player hits + kill credit, crossfire, platform removal, board/HUD [BOT] rows, results "
    .. "test=true + no influence, cleanup, bot mode off, last human leaving, resource stop")
