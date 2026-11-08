-- Dailies fed by the mission flow (server/modules/dailies.lua K.clean_invoice,
-- K.one_man_army, K.two_vs_machine), driven through the REAL Chimera raid:
-- server/modules/missions.lua (board, crew tag, lobby countdown or staff launch,
-- abandon, time-out, finish -> onMissionFinished) and server/modules/mission_chimera.lua
-- (ready check or /raid.skip, launch, boss on its stand, intro, the fight with
-- raid.operators taken at the first shot, downs counted from onLifeState, victory,
-- onEnd -> inst.report). Nothing in inst.report is hand-built. Only the host is
-- stubbed: natives, the open77_chimera provider (a boss whose health the test sets
-- to 0 = the provider reporting the kill), and the LightRP core shims.
-- Progress is read from the page state (providers.dailies(id).list).
local clock = 0
local threads = {}
local function run(ms)
    clock = clock + (ms or 500)
    for i = #threads, 1, -1 do
        local co = threads[i]
        if coroutine.status(co) == "dead" then table.remove(threads, i)
        else local ok, err = coroutine.resume(co); if not ok then error(err) end end
    end
end
local function seconds(n) for _ = 1, n * 2 do run(500) end end
_G.CreateThread = function(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; local ok, err = coroutine.resume(co); if not ok then error(err) end end
_G.Wait = function() coroutine.yield() end
_G.json = {
    encode = function(v)
        local function enc(x)
            if type(x) == "table" then local parts = {} for k, y in pairs(x) do parts[#parts + 1] = tostring(k) .. "=" .. enc(y) end table.sort(parts) return "{" .. table.concat(parts, ",") .. "}" end
            return tostring(x)
        end
        return enc(v)
    end,
    decode = function() return nil end,
}

-- ── the host ──
local unixNow = 20395 * 86400 + 3600 -- Monday 2025-11-03, 01:00 UTC
local positions, buckets, life = {}, {}, {}
local sent, paid, respawned, netHandlers, eventHandlers = {}, {}, {}, {}, {}
_G.GetPlayers = function() local t = {} for id in pairs(positions) do t[#t + 1] = tostring(id) end table.sort(t) return t end
_G.GetPlayerRoutingBucket = function(id) return buckets[id] or 0 end
_G.SetPlayerRoutingBucket = function(id, b) buckets[id] = b return true end
_G.GetPlayerName = function(id) return positions[id] and ("Op" .. id) or nil end
_G.TriggerClientEvent = function(name, target, payload) sent[#sent + 1] = { name = name, target = target, payload = payload } end
_G.RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
_G.AddEventHandler = function(name, fn) eventHandlers[name] = fn end
-- native weapons: every request completes at once with the kit in hand
local requestSeq, held = 0, {}
local weaponsApi = {}
for _, m in ipairs({ "clear", "assign", "setAmmo", "requestSnapshot", "setActive" }) do
    weaponsApi[m] = function(player, ...)
        requestSeq = requestSeq + 1
        held[player] = held[player] or {}
        if m == "clear" then held[player] = {} elseif m == "assign" then held[player][select(2, ...)] = select(1, ...) end
        local result = m == "requestSnapshot" and { slots = {
            { slot = 1, record = held[player][1], ammo = { capacity = 30, reserve = 1000, total = held[player][1] and 30 or 0 } },
            { slot = 2, record = held[player][2], ammo = { capacity = 12, reserve = 1000 } } } } or true
        eventHandlers["open77:weapons:completed"](player, requestSeq, m, true, nil, result)
        return requestSeq
    end
end
-- the open77_chimera provider: the boss goes on its stand; its health is the provider's
local bosses, bossSeq, npcs, npcSeq, loops, loopSeq = {}, 0, {}, 100, {}, 0
local function bossState(b) return { id = b.id, alive = b.health > 0, health = b.health, healthPercent = b.health, phase = b.phase, position = b.position,
    bucket = b.bucket, aiEnabled = b.setAIEnabled ~= false, combatEnabled = b.setCombatEnabled ~= false, maxHealth = 100, repairing = false } end
local provider = {
    spawn = function() return 1 end,
    result = function() return { status = "failed", reason = "unused" } end,
    create = function(options)
        bossSeq = bossSeq + 1
        local b = { id = "boss" .. bossSeq, health = 100, phase = "armored", position = options.position, bucket = options.bucket }
        bosses[b.id] = b
        return bossState(b)
    end,
    get = function(id) local b = bosses[id]; return b and bossState(b) end,
    list = function() return {} end,
    remove = function(id) bosses[id] = nil; return true end,
    setHealth = function(id, h) local b = bosses[id]; b.health = h; return bossState(b) end,
    applyDamage = function(id) return bossState(bosses[id]) end,
}
for _, m in ipairs({ "setDifficulty", "setDamagePolicy", "setAIEnabled", "setCombatEnabled", "setTarget" }) do
    provider[m] = function(id, value) local b = bosses[id]; if not b then return nil, "boss_not_found" end; b[m] = value; return bossState(b) end
end
_G.Open77 = {
    time = { unix = function() return unixNow end },
    weapons = weaponsApi,
    effects = { explosion = function() return { players = {}, vehicles = {} } end, play = function() return true end,
        create = function(def) loopSeq = loopSeq + 1; loops[tostring(loopSeq)] = def; return tostring(loopSeq) end,
        update = function(id, patch) if loops[id] then for k, v in pairs(patch) do loops[id][k] = v end end; return true end,
        remove = function(id) loops[id] = nil; return true end },
    exports = { callSync = function(res, method, ...) assert(res == "open77_chimera"); return provider[method](...) end },
    npcs = { ai = { native = 2 }, damage = { mortal = 0, immortal = 1, invulnerable = 2 },
        create = function(def) npcSeq = npcSeq + 1; npcs[npcSeq] = { def = def, health = 100 }; return npcSeq end,
        get = function(id) return npcs[id] end, remove = function(id) npcs[id] = nil; return true end,
        tasks = { attack = function() return true end } },
    players = {
        position = function(id) local p = positions[id]; return p and { x = p.x, y = p.y, z = p.z, bucket = buckets[id] or 0 } end,
        positions = function() local out = {} for id, p in pairs(positions) do out[id] = { x = p.x, y = p.y, z = p.z, bucket = buckets[id] or 0 } end return out end,
        get = function(id) return { position = positions[id], health = 100, maxHealth = 100, armor = 0, lifePhase = life[id] or "alive" } end,
        getLifeState = function(id) return { phase = life[id] or "alive" } end,
        teleport = function(id, spot, opts)
            return { await = function() buckets[id] = opts.bucket; positions[id] = { x = spot.x, y = spot.y, z = spot.z }; return true end }
        end,
        heal = function(_, amount) return true, amount end,
        respawn = function(id, opts) respawned[#respawned + 1] = { id = id, bucket = opts.bucket }; life[id] = "alive"; buckets[id] = opts.bucket
            positions[id] = { x = opts.position.x, y = opts.position.y, z = opts.position.z }
            LightRP.eachModule("onLifeState", id, "alive") -- the platform announces the new life
            return true end,
    },
    vehicles = { getPlayerSeat = function() return nil end },
    animations = { current = function() return nil end },
}
_G.LightRpEvents = { net = { mission = "op77_lightrp:mission" } }
_G.LightRpConfig = { keys = { raidReady = { key = "Y" } }, spawn = { health = 100 } }

-- ── the LightRP core shims ──
local modules, actions, commands, providers = {}, {}, {}, {}
local chars, accounts, notices, results, session = {}, {}, {}, {}, {}
_G.LightRP = {
    nowMs = function() return clock end, log = function() end,
    module = function(name, def)
        def.name = name
        for i = #modules, 1, -1 do if modules[i].name == name then table.remove(modules, i) end end
        modules[#modules + 1] = def; LightRP[name] = def; return def
    end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if type(m[hook]) == "function" then m[hook](...) end end end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    stateProvider = function(key, fn) providers[key] = fn end,
    state = function() end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, body = n.body } end,
    result = function(id, ok, text, action) results[#results + 1] = { id = id, ok = ok, text = text, action = action } end,
    dialog = function(id, kind, payload) if kind == "mission" then session[id] = payload.session end end,
    interaction = function() end, removeInteraction = function() end,
    characters = {
        isRegistered = function(id) return chars[id] ~= nil end,
        displayName = function(id) return chars[id] or ("P" .. id) end,
        get = function(id) return chars[id] and positions[id] and { status = "active", identifier = accounts[id], key = "default" } or nil end,
    },
    jobs = { get = function() return { name = "unemployed", grade = 0 } end },
    money = { addBank = function(id, amount) paid[id] = (paid[id] or 0) + amount; return true end, format = function(n) return "$" .. n end },
    db = { ready = false, schema = function() end, single = function() end, run = function() end, read = function() return true, {} end },
}

-- the producers, then the dailies module that listens to them
dofile("server/config/economy.lua")
dofile("server/modules/mission_pay.lua")
dofile("server/config/missions.lua")
dofile("server/modules/parties.lua")
-- open77_chimera runs: the raid board refuses to tag in without it
local chimeraState = "running"
GetResourceState = function(name) return name == "open77_chimera" and chimeraState or "missing" end
dofile("server/modules/missions.lua")
dofile("server/modules/mission_chimera.lua")
dofile("server/config/dailies.lua")
dofile("server/modules/dailies.lua")
local Missions, Party, D = LightRP.missions, LightRP.parties, LightRP.dailies
local R, M = LightRpRaid, LightRpMissions
local point = Missions.point("chimera_raid")
assert(point and point.boss, "the raid point is configured with its stand")
for _, hook in ipairs({ "onCharacterLoaded", "onLifeState", "onDisconnected" }) do
    assert(type(Missions[hook]) == "function", "missions listens to " .. hook)
end
assert(type(D.onMissionFinished) == "function", "dailies listens to onMissionFinished")

-- ── helpers ──
local function card(id, contractId)
    for _, c in ipairs(providers.dailies(id).list or {}) do if c.id == contractId then return c end end
end
local function isDone(id, contractId) local c = card(id, contractId); return c ~= nil and c.done == true end
local function give(id, contractId)
    local ok, text = commands["lightrp.dailies"](0, { "give", tostring(id), contractId })
    assert(ok, text)
    local c = card(id, contractId)
    assert(c and not c.done and (c.value or 0) == 0, "given from zero: " .. contractId)
end
local function noticed(id, title)
    for i = #notices, 1, -1 do if notices[i].id == id and notices[i].title == title then return true end end
    return false
end
local function join(id)
    chars[id], accounts[id] = "Op" .. id, accounts[id] or ("acc" .. id)
    positions[id] = { x = point.position.x + id * 0.5, y = point.position.y, z = point.position.z }
    buckets[id], life[id] = 0, nil
    LightRP.eachModule("onCharacterLoaded", id)
end
local function home(ids)
    for i, id in ipairs(ids) do
        positions[id] = { x = point.position.x + i * 0.5, y = point.position.y, z = point.position.z }
        buckets[id], life[id] = 0, nil
    end
end
local function crew(leader, ...)
    local all = { leader, ... }
    for _, id in ipairs(all) do if Party.of(id) then Party.leave(id) end end
    home(all)
    for _, m in ipairs({ ... }) do
        local ok, why = Party.invite(leader, m); assert(ok, why)
        ok, why = Party.accept(m); assert(ok, why)
    end
end
local function staff(name, ...) local ok, text = commands[name](0, { ... }); assert(ok, text); return text end
-- The leader opens the board and tags the crew in; a crew with the difficulty's
-- minimum launches on the lobby countdown, otherwise staff launches it
-- (/missions.launch, the command raid_test.lua uses for an undersized crew).
local function launch(leader, diffId, force)
    assert(Missions.open(leader, "chimera_raid"))
    clock = clock + 2000
    if force then assert(Party.setMatchmaking(leader, true)) end
    actions["mission.tag"](leader, { session = session[leader], difficulty = diffId })
    local r = results[#results]
    assert(r and r.ok, "tagged in: " .. tostring(r and r.text))
    if force then staff("missions.launch", tostring(leader)); Party.setMatchmaking(leader, false)
    else seconds(M.countdown + 1) end
    local inst = Missions.instanceOf(leader)
    assert(inst and inst.difficulty == diffId and buckets[leader] == inst.bucket, "launched into the arena")
    return inst
end
local function phase(id)
    local ok, text = commands["raid.state"](0, { tostring(id) })
    return ok and text:match("phase=(%a+)") or nil
end
-- Ready check (every operator reports the arena loaded and readies, the page
-- action) or /raid.skip, then the launch countdown, the boss on its stand, the
-- intro, and the first shot. `beforeFight` runs during the launch countdown.
local function toFight(inst, opts)
    opts = opts or {}
    local members = { table.unpack(inst.members) }
    if opts.ready then
        for _, id in ipairs(members) do _G.source = id; netHandlers["op77_lightrp:raid:loaded"]() end
        for _, id in ipairs(members) do actions["raid.ready"](id) end
    else
        staff("raid.skip", tostring(members[1]))
    end
    assert(phase(members[1]) == "launch", "launch countdown")
    if opts.beforeFight then opts.beforeFight(inst) end
    seconds(R.launchSeconds + 2)
    assert(phase(inst.members[1]) == "intro", "boss placed, intro")
    seconds(R.introSeconds + 1)
    assert(phase(inst.members[1]) == "fight", "the fight is on")
end
local function bossOf(inst)
    local ok, text = commands["raid.state"](0, { tostring(inst.members[1]) })
    local id = ok and text:match("boss=(%S+)")
    return id and bosses[id]
end
-- The provider reports the Chimera dead; the raid holds the arena, then completes.
local function kill(inst)
    local b = bossOf(inst)
    assert(b, "a boss in the arena")
    b.health = 0
    seconds(1)
    assert(phase(inst.members[1]) == "victory", "Chimera down")
    seconds(R.victorySeconds + 2)
    assert(not Missions.instanceOf(inst.members[1]) and inst.state == "complete", "the raid completed")
    assert(type(inst.report) == "table", "mission_chimera.lua wrote the report")
end
local function down(id) life[id] = "dead"; LightRP.eachModule("onLifeState", id, "dead") end

join(1); join(2); join(3); join(4)
-- the leaders' street cred for the harder difficulties (staff tools, as raid_test.lua)
for _, id in ipairs({ 1, 3 }) do
    staff("missions.rep", tostring(id), "5000")
    staff("missions.unlock", tostring(id), "chimera_raid", "standard")
    staff("missions.unlock", tostring(id), "chimera_raid", "hard")
end

-- ════════════════════════════════════════════════════════════════════════
-- clean_invoice: a Chimera kill with nobody on the team down in the fight
-- ════════════════════════════════════════════════════════════════════════
-- success: a crew of two on Standard, the real ready check; a death BEFORE the fight
-- is free (raid_test.lua) and does not count as a down
give(1, "clean_invoice"); give(2, "clean_invoice")
crew(1, 2)
local inst = launch(1, "standard")
assert(#inst.members == 2)
toFight(inst, { ready = true, beforeFight = function() down(2) end })
assert(#respawned >= 1 and life[2] == "alive", "the pre-fight death respawned for free")
seconds(2)
kill(inst)
assert(inst.report.downs == 0 and inst.report.operators == 2, "report: no down in the fight, two operators")
assert(isDone(1, "clean_invoice") and isDone(2, "clean_invoice"), "a clean kill completes it for the whole team")
assert(noticed(1, "DAILY COMPLETE") and noticed(2, "DAILY COMPLETE"))

-- failure: an operator goes down in the fight (respawned from the pool, the raid is still won)
give(1, "clean_invoice"); give(2, "clean_invoice")
crew(1, 2)
inst = launch(1, "standard")
toFight(inst)
down(2)
seconds(R.scaling.standard.respawnSeconds + 2)
assert(life[2] == "alive" and phase(1) == "fight", "respawned, still fighting")
kill(inst)
assert(inst.report.downs == 1, "report: one down")
assert(not isDone(1, "clean_invoice") and not isDone(2, "clean_invoice"), "a down in the fight voids the clean invoice")
assert(card(1, "clean_invoice").value == 0)

-- failure: the raid is lost (the clock runs out, nobody down)
give(1, "clean_invoice")
crew(1)
inst = launch(1, "standard")
toFight(inst)
clock = clock + point.difficulties[1].minutes * 60000
seconds(1)
assert(inst.state == "failed" and not Missions.instanceOf(1), "time ran out")
assert(inst.report and inst.report.downs == 0, "report written on a failure too")
assert(not isDone(1, "clean_invoice"), "a lost raid is no invoice")

-- failure: an editor test run (Missions.launchNow, the mission editor's entry) is excluded
give(1, "clean_invoice")
home({ 1 })
local okTest = Missions.launchNow("chimera_raid", "standard", { 1 })
inst = Missions.instanceOf(1)
assert(okTest and inst and inst.test == true, "test run launched")
toFight(inst)
kill(inst)
assert(inst.report.downs == 0, "a clean kill...")
assert(not isDone(1, "clean_invoice"), "...in a test run does not count")
assert(noticed(1, "TEST RUN COMPLETE"))

-- and the clean kill still counts once the test is over (same day, a real run)
give(1, "clean_invoice")
home({ 1 })
inst = launch(1, "standard")
toFight(inst)
kill(inst)
assert(isDone(1, "clean_invoice"), "solo clean kill")

-- ════════════════════════════════════════════════════════════════════════
-- one_man_army (weekly): one operator from the first shot to the kill
-- ════════════════════════════════════════════════════════════════════════
give(3, "one_man_army")
crew(3)
inst = launch(3, "standard")
toFight(inst, { ready = true })
kill(inst)
assert(inst.report.operators == 1 and #inst.members == 1)
assert(isDone(3, "one_man_army"), "a solo kill")

-- failure: two at the first shot, the partner abandons before the kill
-- (members 1 at the end, operators 2 at the start)
give(3, "one_man_army"); give(4, "one_man_army")
crew(3, 4)
inst = launch(3, "standard")
toFight(inst)
assert(commands["mission"](4, { "leave" }))
assert(#inst.members == 1 and inst.members[1] == 3, "the partner left the raid")
seconds(1)
kill(inst)
assert(inst.report.operators == 2, "operators counted at the first shot")
assert(not isDone(3, "one_man_army"), "a partner who left before the kill was still help")
assert(not isDone(4, "one_man_army"), "the leaver is not in the finish")

-- failure: a duo kill
give(3, "one_man_army"); give(4, "one_man_army")
crew(3, 4)
inst = launch(3, "standard")
toFight(inst)
kill(inst)
assert(not isDone(3, "one_man_army") and not isDone(4, "one_man_army"), "two operators")

-- a partner who leaves BEFORE the first shot: alone from start to finish, it counts
give(3, "one_man_army")
crew(3, 4)
inst = launch(3, "standard")
toFight(inst, { beforeFight = function() assert(commands["mission"](4, { "leave" })) end })
kill(inst)
assert(inst.report.operators == 1, "one operator at the first shot")
assert(isDone(3, "one_man_army"), "left during the launch countdown: still a one-man army")

-- ════════════════════════════════════════════════════════════════════════
-- two_vs_machine (weekly, social): Hard, exactly two from the first shot to the kill
-- ════════════════════════════════════════════════════════════════════════
-- success: a crew of two on Hard (its minimum: the lobby countdown launches it)
give(1, "two_vs_machine"); give(2, "two_vs_machine")
crew(1, 2)
inst = launch(1, "hard")
toFight(inst, { ready = true })
kill(inst)
assert(inst.report.operators == 2 and #inst.members == 2)
assert(isDone(1, "two_vs_machine") and isDone(2, "two_vs_machine"), "two against the machine on Hard")

-- failure: Standard
give(3, "two_vs_machine"); give(4, "two_vs_machine")
crew(3, 4)
inst = launch(3, "standard")
toFight(inst)
kill(inst)
assert(not isDone(3, "two_vs_machine") and not isDone(4, "two_vs_machine"), "Standard is not Hard")

-- failure: Critical (min 4: only a staff launch puts two in; the check wants Hard)
give(3, "two_vs_machine"); give(4, "two_vs_machine")
crew(3, 4)
inst = launch(3, "critical", true)
assert(#inst.members == 2)
toFight(inst)
kill(inst)
assert(inst.report.operators == 2)
assert(not isDone(3, "two_vs_machine") and not isDone(4, "two_vs_machine"), "Critical is not Hard")

-- failure: three at the first shot, one abandons before the kill (members 2 at the
-- end, operators 3 at the start). The real flow records operators in beginFight.
give(3, "two_vs_machine"); give(4, "two_vs_machine")
crew(3, 4, 1)
inst = launch(3, "hard")
assert(#inst.members == 3)
toFight(inst)
assert(commands["mission"](1, { "leave" }))
assert(#inst.members == 2, "two left in the arena")
seconds(1)
kill(inst)
assert(inst.report.operators == 3 and #inst.members == 2, "report: three at the first shot")
assert(not isDone(3, "two_vs_machine") and not isDone(4, "two_vs_machine"), "a third operator for part of the fight")

-- the same with a disconnect instead of /mission leave
give(3, "two_vs_machine"); give(4, "two_vs_machine")
crew(3, 4, 2)
inst = launch(3, "hard")
toFight(inst)
positions[2] = nil -- gone from the server
LightRP.eachModule("onDisconnected", 2)
assert(#inst.members == 2, "the disconnect took them out of the raid")
seconds(1)
kill(inst)
assert(inst.report.operators == 3)
assert(not isDone(3, "two_vs_machine") and not isDone(4, "two_vs_machine"), "a third who disconnected mid-fight")
join(2)

-- success: a third who leaves BEFORE the first shot leaves exactly two
give(3, "two_vs_machine"); give(4, "two_vs_machine")
crew(3, 4, 1)
inst = launch(3, "hard")
toFight(inst, { beforeFight = function() assert(commands["mission"](1, { "leave" })) end })
kill(inst)
assert(inst.report.operators == 2)
assert(isDone(3, "two_vs_machine") and isDone(4, "two_vs_machine"), "two from the first shot to the kill")

-- failure: a test run on Hard with two
give(1, "two_vs_machine"); give(2, "two_vs_machine")
crew(1, 2)
assert(Missions.launchNow("chimera_raid", "hard", { 1, 2 }))
inst = Missions.instanceOf(1)
assert(inst and inst.test)
toFight(inst)
kill(inst)
assert(not isDone(1, "two_vs_machine") and not isDone(2, "two_vs_machine"), "a test run does not count")

-- the partner rule (social contracts: the same other account once per ISO week;
-- K.two_vs_machine passes the other member's account to finish). A weekly is done
-- once per account and week, so only a staff give reopens it within the week.
local week0 = D.week()
-- notices of one player since a mark, matching a title and (optionally) a text
local function toldSince(mark, id, title, text)
    for i = mark + 1, #notices do
        local n = notices[i]
        if n.id == id and n.title == title and (not text or tostring(n.body):find(text, 1, true)) then return true end
    end
    return false
end
local function relog(id, account)
    positions[id] = nil -- gone from the server
    LightRP.eachModule("onDisconnected", id)
    accounts[id] = account
    join(id)
end

-- failure: players 1 (acc1) and 2 (acc2) finished it together this week (above);
-- the same pair again the same week does not count, and each is told why
give(1, "two_vs_machine"); give(2, "two_vs_machine")
crew(1, 2)
local mark = #notices
inst = launch(1, "hard")
toFight(inst)
kill(inst)
assert(inst.report.operators == 2 and #inst.members == 2 and inst.report.downs == 0, "otherwise a clean Hard duo")
assert(not isDone(1, "two_vs_machine") and not isDone(2, "two_vs_machine"), "the same pair twice in a week: no")
for _, id in ipairs({ 1, 2 }) do
    assert(toldSince(mark, id, "DAILIES", "It takes somebody new."), "player " .. id .. " told it takes somebody new")
    assert(not toldSince(mark, id, "DAILY COMPLETE"), "no completion for player " .. id)
end

-- failure: two characters of one account are one person. Player 4 comes back as a
-- second character of acc1. acc1 has never done it with acc4, so only the
-- same-account check can stop it (a stale acc4 would be a fresh partner and finish).
give(1, "two_vs_machine")
relog(4, "acc1")
crew(1, 4)
inst = launch(1, "hard")
toFight(inst)
kill(inst)
assert(inst.report.operators == 2 and #inst.members == 2)
assert(not isDone(1, "two_vs_machine") and not isDone(4, "two_vs_machine"), "two characters of one account")

-- success, the control: the same week with somebody new. Player 4 back on acc4
-- (it did it with acc3 this week, never with acc1): both count.
relog(4, "acc4")
give(1, "two_vs_machine"); give(4, "two_vs_machine")
crew(1, 4)
inst = launch(1, "hard")
toFight(inst)
kill(inst)
assert(D.week() == week0)
assert(isDone(1, "two_vs_machine") and isDone(4, "two_vs_machine"), "a new partner the same week counts")

-- success: the following ISO week the same pair counts again
unixNow = unixNow + 7 * 86400 -- Monday 2025-11-10
assert(D.week() == week0 + 1, "the next ISO week")
give(1, "two_vs_machine"); give(2, "two_vs_machine")
crew(1, 2)
inst = launch(1, "hard")
toFight(inst)
kill(inst)
assert(isDone(1, "two_vs_machine") and isDone(2, "two_vs_machine"), "the same pair the following week")

-- ── no stray state: every raid ended, nobody left in an arena ──
assert(#Missions.instances() == 0, "no raid left running")
for id = 1, 4 do assert(buckets[id] == 0, "player " .. id .. " back in the city") end

print("dailies_flow_missions_test: ok")
