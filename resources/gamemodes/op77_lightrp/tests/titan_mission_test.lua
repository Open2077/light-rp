-- Titan Assault (server/modules/mission_titan.lua) on top of the mission module, with the host and the Titan
-- service (exports.op77_lightrp_titans) stubbed: the point on the board only while the service runs, arrival
-- (the client's report, position and bucket checked) and the spawn of a held Titan with retries, the class picker
-- (timeout default), the class and the release, the waves (sizes for 2 and 4 pilots, the alive cap, the ground
-- probe and its fallback), the pilots' own blows as the service reports them (onTitanNpcHit: admission refusals, pricing
-- by the server's record of the class weapon and the kind of blow, the applied source), core credit only from onNpcDied
-- (a pilot's lethal damage, or a native death after a recent admitted blow on that NPC), a pilot's respawn with the same
-- class, the wipe, the victory with its payout, the staff test start, a pilot sent home, and the service stopping under a run.
math.randomseed(7)
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
_G.json = { encode = function(v)
    local function enc(x)
        if type(x) == "table" then local parts = {} for k, y in pairs(x) do parts[#parts + 1] = tostring(k) .. "=" .. enc(y) end table.sort(parts) return "{" .. table.concat(parts, ",") .. "}" end
        return tostring(x)
    end
    return enc(v)
end }

local positions, buckets, life = {}, {}, {}
local sent, paid, respawned, notices = {}, {}, {}, {}
local netHandlers, eventHandlers = {}, {}
_G.GetPlayers = function() local t = {} for id in pairs(positions) do t[#t + 1] = tostring(id) end table.sort(t) return t end
_G.GetPlayerRoutingBucket = function(id) return buckets[id] or 0 end
_G.SetPlayerRoutingBucket = function(id, b) buckets[id] = b return true end
_G.TriggerClientEvent = function(name, target, payload) sent[#sent + 1] = { name = name, target = target, payload = payload, at = clock } end
_G.RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
_G.AddEventHandler = function(name, fn) eventHandlers[name] = eventHandlers[name] or {}; table.insert(eventHandlers[name], fn) end
local function fire(name, ...) for _, fn in ipairs(eventHandlers[name] or {}) do fn(...) end end
local resourceState = "running" -- the service is already up when the gamemode loads
_G.GetResourceState = function(name) assert(name == "op77_lightrp_titans", name); return resourceState end

-- ── the Titan service ──
local calls, refuse, titanOf, heldOf, classOf, modeOf, poseOf, titanSeq = {}, {}, {}, {}, {}, {}, {}, 0
local function refused(method, player)
    local r = refuse[method]
    if r and (r[player] or 0) > 0 then r[player] = r[player] - 1; return true end
end
local service = {
    spawn = function(_, player, overrides, options)
        calls[#calls + 1] = { "spawn", player, overrides, options }
        if refused("spawn", player) then return nil, "bridge_unavailable" end
        if titanOf[player] then return nil, "titan_exists" end
        titanSeq = titanSeq + 1
        local id = "T" .. titanSeq
        titanOf[player], heldOf[player], classOf[player] = id, options and options.hold or false, nil
        fire("onTitanCreated", player, id, 1)
        return id
    end,
    setHold = function(_, player, held)
        calls[#calls + 1] = { "setHold", player, held }
        if refused("setHold", player) then return false, "bridge_unavailable" end
        if not titanOf[player] then return false, "no_titan" end
        heldOf[player] = held
        return true
    end,
    setClass = function(_, player, spec)
        calls[#calls + 1] = { "setClass", player, spec }
        if refused("setClass", player) then return false, "bridge_unavailable" end
        if not titanOf[player] then return false, "no_titan" end
        classOf[player] = spec
        return true
    end,
    creditKill = function(_, player, rank)
        calls[#calls + 1] = { "creditKill", player, rank }
        if not titanOf[player] then return false, "no_titan" end
        return true
    end,
    getState = function(_, player)
        if not titanOf[player] then return nil, "no_titan" end
        return { id = titanOf[player], owner = player, mode = modeOf[player], position = poseOf[player] }
    end,
    remove = function(_, player)
        calls[#calls + 1] = { "remove", player }
        local id = titanOf[player]
        if not id then return nil, "no_titan" end
        titanOf[player], heldOf[player], classOf[player] = nil, nil, nil
        fire("onTitanRemoved", player, id, "owner_removed")
        return true
    end,
}
_G.exports = { op77_lightrp_titans = service }
local function callsOf(method, player)
    local list = {}
    for _, c in ipairs(calls) do if c[1] == method and (player == nil or c[2] == player) then list[#list + 1] = c end end
    return list
end
-- the Titan ends under the pilot (the service's own reasons: owner_dead, a destroyed hull)
local function loseTitan(player, reason)
    local id = titanOf[player]
    titanOf[player], heldOf[player], classOf[player] = nil, nil, nil
    if id then fire("onTitanRemoved", player, id, reason) end
end

-- ── NPCs, players ──
local npcs, npcSeq, damageLog, attacks, refuseNpc, npcMax, transforms = {}, 100, {}, {}, {}, 100, {}
_G.Open77 = {
    npcs = { ai = { native = 2 }, damage = { mortal = 0, immortal = 1, invulnerable = 2 },
        create = function(def)
            if refuseNpc[def.record or def.template] then return nil, "npc_refused" end
            npcSeq = npcSeq + 1
            npcs[npcSeq] = { id = npcSeq, def = def, x = def.position.x, y = def.position.y, z = def.position.z, bucket = def.bucket,
                health = npcMax, maxHealth = npcMax }
            return npcSeq
        end,
        get = function(id) return npcs[id] end,
        remove = function(id) npcs[id] = nil; return true end,
        setTransform = function(id, t)
            transforms[#transforms + 1] = { id = id, t = t }
            if npcs[id] and t and t.position then npcs[id].x, npcs[id].y, npcs[id].z = t.position.x, t.position.y, t.position.z end
            return true
        end,
        applyDamage = function(id, amount, source, cause)
            local n = npcs[id]
            if not n then return false end
            n.health = math.max(0, n.health - amount)
            damageLog[#damageLog + 1] = { id = id, amount = amount, source = source, cause = cause }
            return true
        end,
        tasks = { attack = function(id, target, opts) attacks[#attacks + 1] = { id = id, target = target, opts = opts }; return true end } },
    players = {
        position = function(id) local p = positions[id]; return p and { x = p.x, y = p.y, z = p.z, bucket = buckets[id] or 0 } end,
        getLifeState = function(id) return { phase = life[id] or "alive" } end,
        teleport = function(id, spot, opts)
            return { await = function()
                -- into the mission the body takes its time (the test lands it); home it is at once
                if opts.bucket ~= 0 then while not _G.travelled[id] do coroutine.yield() end end
                buckets[id] = opts.bucket; positions[id] = { x = spot.x, y = spot.y, z = spot.z }
                return true
            end }
        end,
        heal = function() return true end,
        respawn = function(id, opts)
            respawned[#respawned + 1] = { id = id, bucket = opts.bucket, position = opts.position }
            life[id] = "alive"; buckets[id] = opts.bucket
            positions[id] = { x = opts.position.x, y = opts.position.y, z = opts.position.z }
            LightRP.eachModule("onLifeState", id, "alive") -- the platform announces the new life
            return true
        end,
    },
}
_G.travelled = {}
_G.LightRpEvents = { net = { mission = "op77_lightrp:mission" } }
_G.LightRpConfig = { keys = {}, spawn = { health = 100 } }

local modules, actions, commands, providers = {}, {}, {}, {}
local chars = {}
_G.LightRP = {
    nowMs = function() return clock end, log = function() end,
    module = function(name, def) def.name = name; modules[#modules + 1] = def; LightRP[name] = LightRP[name] or def; return def end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if m[hook] then m[hook](...) end end end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    stateProvider = function(key, fn) providers[key] = fn end,
    state = function() end, result = function() end,
    notice = function(id, n) notices[#notices + 1] = { id = id, notice = n } end,
    dialog = function(id, kind, payload) payload.kind = kind end,
    interaction = function() end, removeInteraction = function() end,
    characters = {
        isRegistered = function(id) return chars[id] ~= nil end,
        displayName = function(id) return chars[id] or ("P" .. id) end,
        get = function(id) return chars[id] and { status = "active", identifier = "id-" .. id, key = "default" } end,
    },
    money = { addBank = function(id, amount) paid[id] = (paid[id] or 0) + amount; return true end, format = function(n) return "$" .. n end },
    db = { ready = false, schema = function() end, single = function() end, run = function() end },
}

dofile("server/config/economy.lua")
dofile("server/modules/mission_pay.lua")
dofile("server/config/missions.lua")
dofile("server/modules/parties.lua")
dofile("server/modules/missions.lua")
dofile("server/modules/mission_titan.lua")
local Missions, Parties = LightRP.missions, LightRP.parties
local C = LightRpTitanAssault
local POINT = "titan_assault"
local NET = "op77_lightrp:titan"

-- ── the point and its Hall of Fame board follow the Titan service ──
assert(Missions.point(POINT), "the service runs at load: the point is on the board")
local boardsRegistered = {}
LightRP.hallOfFame = { -- loads after this script: the board waits for the first tick
    registerBoard = function(key, def) boardsRegistered[key] = def; return true end,
    unregisterBoard = function(key) local had = boardsRegistered[key] ~= nil; boardsRegistered[key] = nil; return had end,
    clearsProvider = function(types) return function() return types end end,
}
assert(boardsRegistered["missions.assaults"] == nil)
run(500)
local board = boardsRegistered["missions.assaults"]
assert(board and board.tab == "missions" and board.title == "TITAN ASSAULT" and board.unit == "clears" and board.provider().ASSAULT, "the Hall of Fame board of the ASSAULT clears")
resourceState = "stopped"
fire("onResourceStop", "someone_else")
assert(Missions.point(POINT), "another resource stopping changes nothing")
fire("onResourceStop", "op77_lightrp_titans", "manual")
assert(Missions.point(POINT) == nil and boardsRegistered["missions.assaults"] == nil, "the service is not running: no Titan Assault on the board, no board in the Hall of Fame")
assert(select(2, commands["titan.assault"](0, { "1" })):find("not running"), "the staff test start says why")
resourceState = "running"
fire("onResourceStart", "someone_else")
assert(Missions.point(POINT) == nil, "another resource starting changes nothing")
fire("onResourceStart", "op77_lightrp_titans")
assert(boardsRegistered["missions.assaults"], "the board is back")
local point = Missions.point(POINT)
assert(point and point.type == "ASSAULT" and point.arena.x == -1121.0 and point.arena.y == -5450.0 and #point.start == 4, "the point is on the board")
local d = point.difficulties[1]
assert(#point.difficulties == 2 and d.id == "standard" and d.min == 2 and d.max == 4 and d.minutes == 25 and d.tier == 1 and d.payout == 3000, "standard, 2-4 pilots, 25 minutes, 3000")
local hard = point.difficulties[2]
assert(hard.id == "hard" and hard.label == "HARD" and hard.min == 2 and hard.max == 4 and hard.minutes == 25 and hard.tier == 2 and hard.payout == 4500, "hard: the same crew and clock, tier 2, 4500")
assert(C.enemyScale.standard == 5 and C.enemyScale.hard == 10, "five times the hostiles on standard, ten on hard")
-- The scenarios below count the base formula: scale 1. The difficulties' own scales have their scenario at the end.
local SCALES = C.enemyScale
C.enemyScale = { standard = 1, hard = 1 }
assert(point.start[1].x == -1108.0 and point.start[2].y == -5436.0 and point.start[3].x == -1134.0 and point.start[4].y == -5463.0, "the four measured spots in the Rattlesnake Creek desert")
local sector = Missions.point("sector04_blackout")
assert(math.abs(point.position.x - sector.position.x) < 8 and math.abs(point.position.y - sector.position.y) < 8, "the board stands next to the Sector 04 board")

-- ── helpers ──
local function last(id)
    for i = #sent, 1, -1 do if sent[i].name == NET and sent[i].target == id then return sent[i].payload end end
end
local function anyOf(id, key)
    for i = #sent, 1, -1 do local p = sent[i].payload; if sent[i].name == NET and sent[i].target == id and type(p) == "table" and p[key] then return p[key] end end
end
-- the spawn probes (the ground under candidate points), and the checks of the ground under living hostiles (kind "check")
local function probes()
    local list = {}
    for _, e in ipairs(sent) do if e.name == "op77_lightrp:titan:probe" and e.payload.kind ~= "check" then list[#list + 1] = e end end
    return list
end
local function checks()
    local list = {}
    for _, e in ipairs(sent) do if e.name == "op77_lightrp:titan:probe" and e.payload.kind == "check" then list[#list + 1] = e end end
    return list
end
local answered = {}
-- the client's answer to the newest unanswered probe: `height(i, point)` is the ground height, or nil for no level ground
local function answer(height)
    local list = probes()
    local probe = list[#list]
    if not probe or answered[probe] then return nil end
    answered[probe] = true
    local indices, heights = {}, {}
    for i, p in ipairs(probe.payload.points) do
        local z = height and height(i, p) or (not height and p.z + 1.5)
        if z then indices[#indices + 1], heights[#heights + 1] = i, z end
    end
    _G.source = probe.target
    netHandlers["op77_lightrp:titan:ground"](probe.payload.id, indices, heights)
    return probe
end
local function live()
    local list = {}
    for id, n in pairs(npcs) do if n.health > 0 then list[#list + 1] = id end end
    table.sort(list)
    return list
end
local function die(id, by) npcs[id].health = 0; fire("onNpcDied", id, by, "titan") end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function reportArrived(id) _G.source = id; netHandlers["op77_lightrp:titan:arrived"]() end
local function welcome(id, x, y)
    chars[id] = "Op" .. id
    positions[id] = { x = x or point.position.x + id * 0.5, y = y or point.position.y, z = point.position.z }; buckets[id] = 0
    Missions.onCharacterLoaded(id)
end
local session = {}
LightRP.dialog = function(id, kind, payload) payload.kind = kind; session[id] = payload.session end
local function wipeStage()
    for id in pairs(positions) do if Parties.of(id) then Parties.leave(id) end end
    for id in pairs(positions) do positions[id], buckets[id], life[id], chars[id], titanOf[id] = nil, nil, nil, nil, nil end
    _G.travelled, paid = {}, {}
end
-- a crew of n at the board, launched (by the host: the crew minimum is waived), everyone still on the way
local function board(ids, difficulty)
    for _, id in ipairs(ids) do welcome(id); assert(Missions.open(id, POINT)) end
    for i = 2, #ids do assert(Parties.invite(ids[1], ids[i]) and Parties.accept(ids[i]), "a crew") end
    clock = clock + 2000
    actions["mission.tag"](ids[1], { session = session[ids[1]], difficulty = difficulty or "standard" })
    assert(commands["missions.launch"](0, { tostring(ids[1]) }))
    return Missions.instanceOf(ids[1])
end
local function land(ids) for _, id in ipairs(ids) do _G.travelled[id] = true end run(500) end
local function phaseOf(id) return last(id) and last(id).phase end
-- the whole way to the first wave: arrival, spawn, pick, ready, class, countdown (classes by pilot id)
local function toWaves(inst, ids, picks)
    land(ids)
    for _, id in ipairs(ids) do reportArrived(id) end
    assert(phaseOf(ids[1]) == "pick", "everyone has a Titan: the picker opens, got " .. tostring(phaseOf(ids[1])))
    for _, id in ipairs(ids) do
        actions["titan.class"](id, { id = picks[id] }); actions["titan.ready"](id)
    end
    assert(phaseOf(ids[1]) == "countdown", "all ready: the countdown, got " .. tostring(phaseOf(ids[1])))
    seconds(C.countdownSeconds + 1)
    assert(phaseOf(ids[1]) == "wave" and last(ids[1]).wave == 1)
end
-- one wave dead: the ground probe is answered, everything dies to `by`, until the phase moves on
local function clearWave(by, afterSpawn)
    for _ = 1, 60 do
        seconds(1)
        answer()
        if afterSpawn then afterSpawn() end
        for _, id in ipairs(live()) do die(id, "player:" .. by) end
        if phaseOf(by) ~= "wave" then return end
    end
    error("the wave never ended")
end
local function waveOf(n, p) return 4 + 2 * (n - 1) + math.max(0, p - 2) * (1 + n // 3) end

-- ═══════════════════════ run A: two pilots from the board ═══════════════════════
-- the formula (the owner's: 4 + 2(n-1) + (p-2)(1 + floor(n/3)), the extra term 0 below two pilots)
for p = 1, 4 do for n = 1, 10 do assert(LightRP.titanAssault.waveSize(n, p) == waveOf(n, p), ("wave %d, %d pilots"):format(n, p)) end end
assert(LightRP.titanAssault.waveSize(1, 2) == 4 and LightRP.titanAssault.waveSize(10, 2) == 22 and LightRP.titanAssault.waveSize(10, 4) == 30 and LightRP.titanAssault.waveSize(1, 1) == 4)

local inst = board({ 1, 2 })
local launchedAt = clock
assert(inst and #inst.members == 2 and not inst.test and inst.bucket == 3000000 + 1)
assert(inst.loadout == true, "the Titans' weapons are not the character's: the armament stands aside")
local p1 = last(1)
assert(p1 and p1.phase == "arrive" and p1.arrived == false and p1.arena.x == -1121.0 and #p1.operators == 2, "arrive: the clients are asked to report")
assert(#calls == 0, "no Titan before anyone arrived")
-- the teleports are still in flight: a report from the city is not believed
reportArrived(1)
assert(#calls == 0 and last(1).arrived == false, "a report from outside the bucket is ignored")
_G.travelled[1] = true; run(500)
local home = positions[1]
positions[1] = { x = home.x + 500, y = home.y, z = home.z }
reportArrived(1)
assert(#calls == 0, "a report from far away is ignored")
positions[1] = home
-- ... and a report from the arena spawns the Titan: piloted and held, the fists only
reportArrived(1)
local spawn1 = callsOf("spawn", 1)
assert(#spawn1 == 1 and spawn1[1][4].piloted == true and spawn1[1][4].hold == true and count(spawn1[1][4]) == 2, "spawn(1, fists, { piloted, hold })")
local o = spawn1[1][3]
assert(o.xo16 == 0 and o.railgun == 0 and o.predator == 0 and o.sword == 0 and o.fist == 1 and count(o) == 5, "the fists only")
assert(last(1).arrived == true and last(1).operators[1].titan == true and phaseOf(1) == "arrive", "the crew is not complete")
reportArrived(1)
assert(#callsOf("spawn", 1) == 1, "a second report spawns nothing")
-- operator 2: the service refuses twice (the bridge is not up), the script tries again
refuse.spawn = { [2] = 2 }
_G.travelled[2] = true; run(500)
reportArrived(2)
assert(#callsOf("spawn", 2) == 1 and not titanOf[2] and phaseOf(1) == "arrive", "a refused spawn: no Titan yet")
seconds(1)
assert(#callsOf("spawn", 2) == 1, "tried again after the retry delay, not at once")
seconds(2)
assert(#callsOf("spawn", 2) == 2 and not titanOf[2])
seconds(2)
assert(#callsOf("spawn", 2) == 3 and titanOf[2] and phaseOf(1) == "pick", "the third try lands: the picker opens")

-- pick: held, no hostile, five classes
local pick = last(1)
assert(#pick.classes == 5 and pick.pickEndsInMs > 0 and #pick.operators == 2, "the class picker")
local ids = {}
for i, c in ipairs(pick.classes) do ids[i] = c.id end
assert(table.concat(ids, ",") == "vanguard,ronin,northstar,legion,brawler")
assert(pick.classes[4].weapon == "Predator Cannon" and pick.classes[4].core == "Burst Core" and table.concat(pick.classes[4].abilities, ",") == "vortex,smoke,sentry,core", "a card: weapon, core and the abilities it keeps")
assert(pick.classes[5].labels.vortex == "Arc Field" and pick.classes[3].labels.designator == "Barrage" and pick.classes[1].labels == nil, "a card's ability labels")
for i, c in ipairs(C.classes) do
    assert(type(c.ultimate) == "string" and c.ultimate ~= "" and pick.classes[i].ultimate == c.ultimate, "the card of " .. c.id .. " carries its ultimate line")
end
assert(pick.classes[1].ultimate:find("BURST CORE", 1, true) and pick.classes[2].ultimate:find("SWORD CORE", 1, true) and pick.classes[3].ultimate:find("FLIGHT STRIKE", 1, true)
    and pick.classes[4].ultimate:find("Predator", 1, true) and pick.classes[5].ultimate:find("BERSERKER CORE", 1, true), "each ultimate names its core")
assert(next(npcs) == nil, "no hostile while the crew picks")
assert(heldOf[1] and heldOf[2], "held")
-- a fresh Titan stands by on the fists with every ability locked (its own default weapon is the XO-16)
local function picked(id)
    local out = {}
    for _, c in ipairs(callsOf("setClass", id)) do if c[3].id ~= "standby" then out[#out + 1] = c end end
    return out
end
for _, id in ipairs({ 1, 2 }) do
    local standby = callsOf("setClass", id)
    assert(#standby == 1 and standby[1][3].id == "standby" and standby[1][3].weapon == "fist" and standby[1][3].speed == 1.0, "stand-by class of " .. id)
    for key, on in pairs(standby[1][3].abilities) do assert(on == false, "stand-by ability " .. key) end
    assert(count(standby[1][3].abilities) == 9, "every ability named")
end
-- bad picks do nothing; ready needs a pick
actions["titan.class"](1, { id = "nobody" }); actions["titan.class"](1, {}); actions["titan.class"](1)
assert(last(1).class == nil)
actions["titan.ready"](1)
assert(not last(1).ready and notices[#notices].notice.body:find("Pick a class"), "READY before a class is refused")
actions["titan.class"](1, { id = "ronin" }); actions["titan.class"](1, { id = "legion" })
assert(last(1).class == "legion" and last(2).operators[1].class == "Legion", "the pick can change, the crew sees it")
actions["titan.ready"](1)
assert(last(1).ready and last(2).operators[1].ready and phaseOf(1) == "pick", "one ready: the other still picks")
actions["titan.class"](1, { id = "ronin" })
assert(last(1).class == "legion", "a ready pilot cannot change class")
assert(#picked(1) == 0 and #picked(2) == 0, "no class before everyone is ready")
-- the 60 s run out: operator 2 never picked, gets the default class
seconds(C.pickSeconds - 1)
assert(phaseOf(1) == "pick" and #picked(1) == 0 and #picked(2) == 0)
seconds(1)
local set1, set2 = picked(1), picked(2)
assert(#set1 == 1 and #set2 == 1, "both Titans got a class")
assert(set2[1][3].id == "vanguard" and set2[1][3].weapon == "xo16" and set2[1][3].label == "Vanguard" and set2[1][3].speed == 1.0, "the un-picked get Vanguard")
local legion = set1[1][3]
assert(legion.id == "legion" and legion.weapon == "pred" and legion.speed == 0.85 and legion.perks.hull == 3 and legion.perks.preddamage == 2 and count(legion.perks) == 7, "the Legion spec")
assert(legion.harm == C.incoming.standard and set2[1][3].harm == C.incoming.standard, "the run's damage multiple rides with each class")
assert(legion.regen == C.shieldRegen.standard and set2[1][3].regen == C.shieldRegen.standard, "and its shield's regeneration multiple")
assert(C.incoming.hard > C.incoming.standard and C.shieldRegen.hard >= C.shieldRegen.standard, "hard hurts more and heals slower")
for _, key in ipairs({ "missiles", "vortex", "smoke", "dash", "jets", "sentry", "flight", "designator", "core" }) do
    local want = key == "vortex" or key == "smoke" or key == "sentry" or key == "core"
    assert(legion.abilities[key] == want, "ability " .. key)
end
assert(set2[1][3].abilities.missiles and set2[1][3].abilities.jets and not set2[1][3].abilities.dash and not set2[1][3].abilities.sentry)
assert(not heldOf[1] and not heldOf[2], "released")
local order = {}
for _, c in ipairs(calls) do
    if (c[1] == "setClass" and c[3].id ~= "standby" or c[1] == "setHold") and c[2] == 1 then order[#order + 1] = c[1] end
end
assert(table.concat(order, ",") == "setClass,setHold", "the class first, then the release")
assert(phaseOf(1) == "countdown" and last(1).startsInMs > 0 and last(1).startsInMs <= C.countdownSeconds * 1000, "the countdown to wave 1")
assert(anyOf(1, "announce").title == "WAVE 1")
assert(next(npcs) == nil, "still no hostile")

-- the waves
seconds(C.countdownSeconds - 1)
assert(phaseOf(1) == "countdown")
seconds(1)
assert(phaseOf(1) == "wave" and last(1).wave == 1 and last(1).waves == 10 and last(1).waveSize == 4, "wave 1")
assert(anyOf(1, "announce").title == "WAVE 1")
seconds(1)
local list = probes()
assert(#list == 1 and #list[1].payload.points == 4 * C.probe.perHostile, "a ground probe: candidate points for the wave")
local probe = list[1]
assert(probe.target == 1 or probe.target == 2)
-- the probe's points: on the ring around the pilots' centroid, and clear of every pilot
local function clearOfPilots(p, ids)
    for _, id in ipairs(ids) do
        if math.sqrt((p.x - positions[id].x) ^ 2 + (p.y - positions[id].y) ^ 2) < C.ring.clear - 0.2 then return false end
    end
    return true
end
local cx, cy = (positions[1].x + positions[2].x) / 2, (positions[1].y + positions[2].y) / 2
for _, p in ipairs(probe.payload.points) do
    local r = math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2)
    assert(r >= C.ring.min - 0.2 and r <= C.ring.max + 0.2, "on the ring: " .. r)
    assert(clearOfPilots(p, { 1, 2 }), "clear of both pilots")
end
-- only the prober, for the request in flight, is answered
_G.source = probe.target == 1 and 2 or 1
netHandlers["op77_lightrp:titan:ground"](probe.payload.id, { 1, 2, 3, 4 }, { 180, 180, 180, 180 })
assert(next(npcs) == nil, "an answer from another pilot is ignored")
_G.source = probe.target
netHandlers["op77_lightrp:titan:ground"](probe.payload.id + 1, { 1, 2, 3, 4 }, { 180, 180, 180, 180 })
assert(next(npcs) == nil, "an answer to another request is ignored")
-- heights the pilots' ground cannot be near are not taken; a repeated index counts once
local z0 = probe.payload.points[1].z
netHandlers["op77_lightrp:titan:ground"](probe.payload.id, { 1, 1, 2, 3, 4, 99 }, { z0 + 1, z0 + 2, z0 + 500, z0 + 2, z0 - 1, z0 })
local made = live()
assert(#made == 3, "the first index once, the absurd height refused, the unknown index ignored: " .. #made)
for _, id in ipairs(made) do
    local n = npcs[id]
    local def = n.def
    assert(def.bucket == inst.bucket and n.bucket == inst.bucket, "in the run's bucket")
    assert(def.damagePolicy == 0 and def.aiMode == 2, "mortal, native AI")
    assert(def.behavior.hitPricing == "resource" and def.behavior.aiEnabled and def.behavior.combatEnabled, "the server prices the hits")
    assert(def.loadout.combat.group == C.group and def.loadout.combat.acquirePlayers == true and def.loadout.combat.authoritativePlayerHits == true, "own combat group, acquires pilots")
    assert(def.record or def.template, "created from a pool record")
end
assert(#attacks == 3 and (attacks[1].target.playerId == 1 or attacks[1].target.playerId == 2), "sent at a pilot")
assert(math.abs(npcs[made[1]].z - (z0 + 1 + C.spawnLift)) < 1e-6, "dropped on the probed ground")
assert(last(1).enemies == 4 and #last(1).enemyIds == 3, "the page counts 4, the clients are told 3 ids")
seconds(1)
local second = answer()
assert(second and #live() == 4, "the fourth hostile on the next probe")
assert(last(1).enemies == 4 and #last(1).enemyIds == 4)
assert(not answer(), "nothing left to probe")

-- hit admission and pricing: the pilot's own Titan reports a blow (the Titan service's onTitanNpcHit, which carries the kind of
-- blow and the Titan's own pose); the server's record of the pilot's class weapon and the kind decide the damage, never the report
local npc = live()[1]
local damages = #damageLog
local function near(a, b) return math.abs(a - b) < 1e-9 end
-- what the service publishes: the record, the kind, where the controller says it landed and the Titan's latest accepted pose
-- (`extra` overrides; false removes a key)
-- A report's record by the kind of blow a test means (the server prices the record, never the report's kind).
-- A round is the pilot's own class weapon's (the class its page shows); the rest are one record each.
local RECORD_OF = { blast = "Attacks.BT7274_Missile", melee = "Attacks.BT7274_Punch", blade = "Attacks.BT7274_Sword",
    other = "Attacks.BT7274_Vortex" }
local ROUND_OF = { xo16 = "Attacks.BT7274_XO16_Hit", pred = "Attacks.BT7274_Pred_Hit", rail = "Attacks.BT7274_Rail_1" }
local function roundRecord(id)
    local view = last(id)
    for _, c in ipairs(C.classes) do
        if view and c.id == view.class then return ROUND_OF[c.weapon] or "Attacks.BT7274_XO16_Hit" end
    end
    return "Attacks.BT7274_XO16_Hit"
end
local function info(id, kind, extra)
    local p = positions[id]
    kind = kind or "round"
    local i = { record = kind == "round" and roundRecord(id) or RECORD_OF[kind], kind = kind, point = { x = 1, y = 2, z = 3 },
        titan = p and { x = p.x, y = p.y, z = p.z } or nil, at = 1 }
    for k, v in pairs(extra or {}) do i[k] = v end
    for k, v in pairs(i) do if v == false then i[k] = nil end end
    return i
end
local function hit(id, target, kind, extra) return LightRP.titanAssault.hit(id, titanOf[id], target, info(id, kind, extra)) end
local function refusal(id, target, kind, extra) local ok, why = hit(id, target, kind, extra); assert(not ok, "admitted"); return why end
assert(netHandlers["op77_lightrp:titan:hit"] == nil, "no client relays a shot any more: the Titan reports its own blows")
assert(refusal(5, npc) == "not_member", "not a member")
assert(refusal(1, 99999) == "not_enemy" and refusal(1, nil) == "not_enemy", "not one of the run's hostiles")
for _, junk in ipairs({ "", "abc", "0", "-5", "1.5", "0101", tostring(npc) .. ".0", tostring(npc) .. " ", 0, -5, npc + 0.5, math.huge, 0 / 0, {}, true }) do
    assert(refusal(1, junk) == "not_enemy", "a malformed NPC id: " .. tostring(junk))
end
local stray = Open77.npcs.create({ position = { x = 0, y = 0, z = 0 }, bucket = inst.bucket })
assert(refusal(1, stray) == "not_enemy", "another resource's NPC in the same bucket")
local dead = live()[2]
npcs[dead].health = 0
assert(refusal(1, dead) == "not_alive", "a dead hostile")
npcs[dead].health = npcMax
npcs[npc].bucket = 12
assert(refusal(1, npc) == "wrong_bucket", "a hostile in another bucket")
npcs[npc].bucket = inst.bucket
assert(select(2, LightRP.titanAssault.hit(1, "T999", npc, info(1))) == "wrong_titan", "a Titan that is not this pilot's current one")
assert(select(2, LightRP.titanAssault.hit(1, nil, npc, info(1))) == "wrong_titan", "a report that names no Titan")
assert(select(2, LightRP.titanAssault.hit(1, titanOf[1], npc, nil)) == "invalid", "no report")
assert(select(2, LightRP.titanAssault.hit(1, titanOf[1], npc, {})) == "no_price"
    and select(2, LightRP.titanAssault.hit(1, titanOf[1], npc, { record = 5 })) == "no_price", "no record, a record that is not text")
assert(refusal(1, npc, "round", { record = "Attacks.Laser" }) == "no_price" and refusal(1, npc, "round", { record = "Attacks.ExplosionSmall" }) == "no_price"
    and refusal(1, npc, "round", { record = "Attacks.BT7274_Eject" }) == "no_price", "a record the Titan's weapons do not fire, the fallback and the eject price nothing")
assert(refusal(1, npc, "blast", { kind = "round", record = "Attacks.BT7274_XO16_Hit" }) == "wrong_weapon", "another class's weapon: Legion fires no XO-16")
local pos1, bucket1 = positions[1], buckets[1]
local far = { x = pos1.x + 400, y = pos1.y, z = pos1.z }
assert(refusal(1, npc, "round", { titan = far }) == "too_far", "out of range of the pilot's Titan")
-- no usable pose with the report: the pilot's own fresh position, in the run's bucket
positions[1] = far
assert(refusal(1, npc, "round", { titan = false }) == "too_far", "no pose: out of range of the pilot's position")
assert(refusal(1, npc, "round", { titan = { x = 0 / 0, y = pos1.y, z = pos1.z } }) == "too_far", "a pose that is not a point is no pose")
assert(refusal(1, npc, "round", { titan = { x = pos1.x } }) == "too_far", "nor is half of one")
positions[1] = nil
assert(refusal(1, npc, "round", { titan = false }) == "no_position", "no pose and no fresh position")
positions[1] = pos1
buckets[1] = 12
assert(refusal(1, npc, "round", { titan = false }) == "no_position", "no pose and the pilot's position in another bucket")
buckets[1] = bucket1
assert(#damageLog == damages, "nothing was applied by any refusal")
-- priced by the server's record of the class weapon and the kind of blow, in percent of the hostile's maximum health: Legion's
-- Predator round 6, Vanguard's XO-16 round 4, a blast 25, a fist 45, a blade 60, the rest 4 (measured on a pool deep enough
-- never to die, so that the damage is a share of the maximum)
local big = live()[3]
npcs[big].maxHealth, npcs[big].health = 1000000, 1000000000
local function percent(id, kind, extra)
    clock = clock + 1000 -- the budget has refilled
    local okHit, amount = hit(id, big, kind, extra)
    assert(okHit, "admitted: " .. tostring(amount))
    return amount / npcs[big].maxHealth * 100
end
assert(near(percent(1, "round"), 6) and damageLog[#damageLog].source == "player:1" and damageLog[#damageLog].cause == "titan" and damageLog[#damageLog].id == big, "Legion's cannon: 6 of 100, applied as the pilot")
assert(near(percent(2, "round"), 4) and damageLog[#damageLog].source == "player:2", "Vanguard's XO-16: 4 of 100")
assert(near(percent(2, "blast"), 25), "Vanguard's missile: a blast")
assert(near(percent(1, "round", { kind = "blast" }), 6), "the report's own kind changes nothing: a cannon round labelled a blast is a round")
assert(refusal(1, big, "blast") == "locked", "Legion has no missiles: a missile record from Legion is refused")
assert(near(percent(2, "melee"), 45) and near(percent(1, "melee"), 45), "a punch is a punch whoever throws it")
assert(refusal(2, big, "blade") == "wrong_weapon" and refusal(1, big, "blade") == "wrong_weapon", "a blade only for the sword's class")
assert(near(percent(1, "other"), 4) and near(percent(2, "other"), 4), "the vortex shield's throw-back is small")
assert(refusal(2, big, "other", { record = "Attacks.BT7274_Smoke" }) == "locked", "Vanguard has no smoke")
assert(near(percent(1, "round", { titan = { x = pos1.x, y = pos1.y, z = pos1.z }, point = { x = 9e5, y = 0, z = 0 } }), 6), "where the controller says it landed prices nothing")
positions[1] = far
assert(near(percent(1, "round", { titan = { x = pos1.x, y = pos1.y, z = pos1.z } }), 6), "the Titan's pose rules over where the pilot's body is")
positions[1] = pos1
-- tuning: a grunt in 1.5 to 2.5 s of sustained XO-16 fire (12 rounds a second, 16.8 at full spin)
local roundsToKill = math.ceil(100 / C.hits.perHit.xo16)
assert(roundsToKill / 16.8 >= 1.4 and roundsToKill / 12 <= 2.5, "an XO-16 grunt in about two seconds: " .. roundsToKill .. " rounds")
-- the service's host event is what the script listens to, and the NPC id may be text
clock = clock + 1000
local fired = #damageLog
fire("onTitanNpcHit", 2, titanOf[2], tostring(big), info(2, "round"))
assert(#damageLog == fired + 1 and damageLog[#damageLog].source == "player:2" and damageLog[#damageLog].cause == "titan" and damageLog[#damageLog].id == big, "onTitanNpcHit is wired")
fire("onTitanNpcHit", 2, titanOf[2], tostring(big), info(2, "round", { record = false }))
fire("onTitanNpcHit", 2, titanOf[2], "424242", info(2, "round"))
fire("onTitanNpcHit", 2, "T999", tostring(big), info(2, "round"))
assert(#damageLog == fired + 1, "a malformed report, an unknown NPC and another Titan's id change nothing")
-- the budget: 240 percent per second per pilot, the burst never above it (a blast is 25)
clock = clock + 5000
local budgetRefused, before = 0, npcs[big].health
for _ = 1, 40 do
    local okHit, why = hit(2, big, "blast")
    if not okHit then assert(why == "budget", why); budgetRefused = budgetRefused + 1 end
end
local appliedPercent = (before - npcs[big].health) / 1000000 * 100
assert(near(appliedPercent, C.hits.perSecond) and budgetRefused > 10, "a burst stays in the budget: " .. appliedPercent)
clock = clock + 1000
assert(hit(2, big, "round"), "the budget refills")
npcs[big].maxHealth, npcs[big].health = npcMax, npcMax
clock = clock + 5000

-- kills and core: only onNpcDied, only the server's own killer label
local calls0 = #callsOf("creditKill")
npcs[npc].health = 1
clock = clock + 1000
assert(hit(1, npc))
assert(npcs[npc].health == 0 and #callsOf("creditKill") == calls0, "a lethal hit credits nothing by itself")
fire("onNpcDied", npc, "player:1", "titan")
local credits = callsOf("creditKill")
assert(#credits == calls0 + 1 and credits[#credits][2] == 1, "credited on the death event")
for record, rank in pairs(C.ranks) do assert(rank == "grunt", "every hostile is a grunt, so a charge takes 15 kills: " .. record) end
assert(credits[#credits][3] == "grunt", "the kill credits a grunt, whatever its record: " .. tostring(npcs[npc].def.record or npcs[npc].def.template))
fire("onNpcDied", npc, "player:1", "titan")
assert(#callsOf("creditKill") == calls0 + 1, "a death counts once")
local other = live()[1]
npcs[other].health = 0
fire("onNpcDied", other, "script", "titan")
assert(#callsOf("creditKill") == calls0 + 1, "no credit for a death by another hand")
local other2 = live()[1]
npcs[other2].health = 0
fire("onNpcDied", other2, "player:5", "titan")
assert(#callsOf("creditKill") == calls0 + 1, "no credit for a player outside the run")
fire("onNpcDied", stray, "player:1", "titan")
assert(#callsOf("creditKill") == calls0 + 1, "nor for an NPC that is not the run's")
seconds(1)
assert(last(1).kills == 1 and last(1).killsTotal == 1, "the kill counts for its pilot")
-- a hit from a pilot who is down, or whose Titan is gone
local alive3 = live()[1]
local d2 = #damageLog
life[2] = "dead"; LightRP.eachModule("onLifeState", 2, "dead")
assert(refusal(2, alive3) == "down", "a pilot who is down deals nothing, whatever Titan the run still tracks")
loseTitan(2, "owner_dead")
assert(refusal(2, alive3) == "no_titan", "no Titan, no hits")
assert(#damageLog == d2)
-- the page's death-by-hostile path reaches the pilots through the engine's checks
local engineCalls = {}
LightRP.missionEngine = { applyNpcHit = function(i, reporter, victim, key, epoch, damage, platform, cause)
    engineCalls[#engineCalls + 1] = { inst = i, reporter = reporter, victim = victim, key = key, epoch = epoch, damage = damage, platform = platform, cause = cause }; return true end }
-- aboard, the blow is BT's (its controller takes it into the hull): the pilot's health is not touched
modeOf[1] = "pilot"
local aboard, why = LightRP.titanEnemyHit(1, "1", tostring(alive3), "4", "12.5", true, "firearm")
assert(not aboard and why == "aboard" and #engineCalls == 0, "a pilot aboard takes no player damage")
modeOf[1] = "wait" -- V on foot, BT waiting
assert(LightRP.titanEnemyHit(1, "1", tostring(alive3), "4", "12.5", true, "firearm"))
assert(#engineCalls == 1 and engineCalls[1].key == alive3 and engineCalls[1].victim == 1 and engineCalls[1].damage == 12.5 and engineCalls[1].cause == "firearm" and engineCalls[1].inst == inst, "a hostile's hit goes through the engine's checks")
assert(not LightRP.titanEnemyHit(1, "1", "424242", "4", "12.5") and not LightRP.titanEnemyHit(1, "1", tostring(alive3), "4", "-3") and #engineCalls == 1, "not a hostile of the run / a negative amount")
_G.source = 1; netHandlers["op77_lightrp:titan:npcHit"]("1", tostring(alive3), "4", "5")
assert(#engineCalls == 2, "the legacy relay too")

-- down: operator 2 is back in a new Titan with the same class after 12 s
assert(last(1).operators[2].down and last(2).down and last(2).respawnInMs > 0, "the page shows the respawn")
assert(anyOf(1, "announce").title == "PILOT DOWN" and phaseOf(1) == "wave", "one down is not a wipe")
local nSpawns, nRespawns = #callsOf("spawn", 2), #respawned
seconds(C.respawnSeconds - 2)
assert(#respawned == nRespawns, "not before the delay")
seconds(3)
assert(#respawned == nRespawns + 1 and respawned[#respawned].id == 2 and respawned[#respawned].bucket == inst.bucket, "respawned in the bucket")
local spotOk
for _, s in ipairs(point.start) do if s.x == respawned[#respawned].position.x and s.y == respawned[#respawned].position.y then spotOk = true end end
assert(spotOk, "at a start spot")
seconds(1)
local respawnSpawn = callsOf("spawn", 2)
assert(#respawnSpawn == nSpawns + 1 and respawnSpawn[#respawnSpawn][4].piloted == true and respawnSpawn[#respawnSpawn][4].hold == nil, "a new Titan, piloted, not held")
assert(classOf[2] and classOf[2].id == "vanguard" and not heldOf[2], "with the same class")
assert(not last(2).down and not last(1).operators[2].down)
assert(titanOf[2] and hit(2, live()[1]), "and it hits again")

-- clear the waves one after the other: 8 s between them, the size grows, the cap holds
local seen = { [1] = 4 }
for n = 1, 10 do
    local size = last(1).waveSize
    assert(size == waveOf(n, 2), ("wave %d of 2 pilots is %d, got %s"):format(n, waveOf(n, 2), tostring(size)))
    clearWave(1, function() assert(#live() <= C.maxAlive, "at most 16 alive at once") end)
    if n < 10 then
        assert(phaseOf(1) == "intermission" and last(1).nextWaveInMs > 0 and last(1).nextWaveInMs <= C.intermissionSeconds * 1000, "intermission after wave " .. n)
        if n == 1 then assert(select(2, LightRP.titanAssault.hit(1, titanOf[1], 101, info(1))) == "phase", "no blow counts between waves") end
        assert(anyOf(1, "announce").title == "WAVE " .. (n + 1), "the next wave's banner")
        seconds(C.intermissionSeconds - 2)
        assert(phaseOf(1) == "intermission")
        seconds(3)
        assert(phaseOf(1) == "wave" and last(1).wave == n + 1, "the next wave starts after the intermission")
    end
end
assert(phaseOf(1) == "victory" and anyOf(1, "announce").title == "ASSAULT REPELLED", "wave 10 dead: victory")
assert(Missions.instanceOf(1), "a few seconds in the arena first")
seconds(C.victorySeconds + 1)
assert(not Missions.instanceOf(1), "complete")
local share = LightRP.missionPay.share(d.payout, 2, d.min)
assert(paid[1] == share and paid[2] == share and share == 3000, "paid per head")
assert(buckets[1] == 0 and last(1).phase == "ended" and last(1).result == "victory", "home")
local report = inst.report
assert(report.waves == 10 and report.kills > 100 and report.downs == 1 and report.operators == 2 and report.killsBy[1] > 0, "the report: waves, kills, downs, operators")
assert(#live() == 0, "no hostile left")
assert(#callsOf("remove", 1) >= 1 and #callsOf("remove", 2) >= 1 and not titanOf[1] and not titanOf[2], "Titans removed")
-- the trace of this run, as the first pilot's page saw it: every change of phase or wave, with its time since the launch
local trace, seen = {}, nil
for _, e in ipairs(sent) do
    local p = e.payload
    if e.name == NET and e.target == 1 and type(p) == "table" and p.phase and e.at >= launchedAt then
        local key = p.phase .. "/" .. tostring(p.wave or 0)
        if key ~= seen then
            seen = key
            trace[#trace + 1] = ("  +%6.1fs  %-12s wave %-2s hostiles %-3s kills %s"):format((e.at - launchedAt) / 1000, p.phase, tostring(p.wave or "-"), tostring(p.enemies or "-"), tostring(p.killsTotal or "-"))
        end
    end
end
print("TRACE of run A (2 pilots, board launch), pilot 1's page:\n" .. table.concat(trace, "\n"))
assert(#callsOf("setHold", 1) >= 2 and callsOf("setHold", 1)[#callsOf("setHold", 1)][3] == false, "holds released")

-- ═══════════════════════ run B: two pilots, a wipe ═══════════════════════
wipeStage(); calls, notices, respawned = {}, {}, {}
for id in pairs(npcs) do npcs[id] = nil end
for id in pairs(titanOf) do titanOf[id] = nil end
inst = board({ 1, 2 })
toWaves(inst, { 1, 2 }, { [1] = "ronin", [2] = "brawler" })
assert(classOf[1].weapon == "sword" and classOf[1].speed == 1.2 and classOf[1].abilities.dash and not classOf[1].abilities.jets, "Ronin")
assert(classOf[2].weapon == "fist" and classOf[2].abilities.vortex and classOf[2].abilities.dash and not classOf[2].abilities.smoke, "Brawler")
seconds(1); answer()
local liveB = live()
-- pricing by the class weapon: Ronin's sword 60, Brawler's fists 45
clock = clock + 1000
local sword = select(2, hit(1, liveB[1], "blade"))
local fist = select(2, hit(2, liveB[2], "melee"))
assert(sword == 60 and fist == 45, "sword 60, fists 45")
assert(refusal(1, liveB[3], "blast") == "locked", "the Ronin fires no missiles")
assert(select(2, hit(2, liveB[3], "blast", { record = "Attacks.BT7274_Fist_Blast" })) == 25, "the Brawler's fist blast is a blast")
-- a record's `times` multiplies its price: the Berserker Core's punch pays three punches, then the per-second budget caps it
assert(C.hits.records["Attacks.BT7274_Fist_Core"].times == 3 and C.hits.records["Attacks.BT7274_Fist"].times == nil, "only the core's punch has a multiple")
local coreBlow = select(2, hit(2, liveB[3], "melee", { record = "Attacks.BT7274_Fist_Core" }))
assert(coreBlow == fist * 3 and coreBlow == 135, "a Berserker Core punch is priced three fist blows: " .. tostring(coreBlow))
local cappedBlow = select(2, hit(2, liveB[4], "melee", { record = "Attacks.BT7274_Fist_Core" }))
assert(near(cappedBlow, C.hits.perSecond - fist - 25 - coreBlow), "the budget still caps it: " .. tostring(cappedBlow))
assert(refusal(1, liveB[4], "round") == "wrong_weapon" and refusal(2, liveB[4], "round") == "wrong_weapon", "a class whose weapon fires no rounds: a round from it is refused")
-- both down at once is a wipe, one is not
life[1] = "dead"; loseTitan(1, "owner_dead"); LightRP.eachModule("onLifeState", 1, "dead")
assert(phaseOf(1) == "wave", "one down")
life[2] = "dead"; loseTitan(2, "owner_dead"); LightRP.eachModule("onLifeState", 2, "dead")
assert(phaseOf(2) == "wipe" and anyOf(2, "announce").title == "CREW WIPED", "everyone down at once: wipe")
assert(#live() == 0, "the hostiles are cleared")
seconds(C.wipeSeconds - 1)
assert(Missions.instanceOf(1))
seconds(2)
assert(not Missions.instanceOf(1) and not paid[1] and not paid[2], "failed, nothing paid")
assert(last(2).result == "failed" and inst.report.waves == 0 and inst.report.downs == 2, "failed: no pay for the wave 1 run")

-- ═══════════════════════ a native death: a missile's area attack ═══════════════════════
-- The platform reports a death the simulating client resolved itself as "native" and names no attacker. The script credits it
-- only to the pilot whose admitted Titan blow landed on that same hostile in the last 5 s, and to nobody else.
wipeStage(); calls, notices, respawned = {}, {}, {}
for id in pairs(npcs) do npcs[id] = nil end
inst = board({ 1, 2 })
toWaves(inst, { 1, 2 }, { [1] = "vanguard", [2] = "legion" })
seconds(1); answer()
local foes = live()
assert(#foes == 4, "wave 1: four hostiles")
local function creditList() return callsOf("creditKill") end
local function nativeDeath(id) npcs[id].health = 0; fire("onNpcDied", id, "native", "native") end
local c0 = #creditList()
-- a recent blow on ANOTHER hostile does not make this death anybody's
clock = clock + 1000
assert(hit(1, foes[2], "round"))
nativeDeath(foes[1])
assert(#creditList() == c0 and last(1).kills == 0, "no blow on that hostile: credited to nobody, never the simulator")
-- the latest admitted blow names the pilot: 1 hit it, then 2 did
clock = clock + 100
assert(hit(2, foes[2], "melee"))
nativeDeath(foes[2])
assert(#creditList() == c0 + 1 and creditList()[c0 + 1][2] == 2 and creditList()[c0 + 1][3] == "grunt",
    "credited to the pilot whose blow landed last, with the hostile's rank")
fire("onNpcDied", foes[2], "native", "native")
assert(#creditList() == c0 + 1, "a death counts once")
-- the window is 5 s from the blow: a blow 5.001 s old no longer counts, and a recent blow does not make a death by another hand a native one
clock = clock + 1000
assert(hit(1, foes[3], "round"))
clock = clock + 4000
assert(hit(1, foes[4], "round"))
clock = clock + 1001
nativeDeath(foes[3])
assert(#creditList() == c0 + 1, "a native death 5.001 s after the blow credits nobody")
npcs[foes[4]].health = 0
fire("onNpcDied", foes[4], "script", "titan")
fire("onNpcDied", 424242, "native", "native")
assert(#creditList() == c0 + 1, "a death by another hand, and an NPC that is not the run's, credit nobody")
seconds(1)
assert(last(1).kills == 0 and last(2).kills == 1 and last(1).killsTotal == 1, "the native kill counts for the pilot it was credited to")
-- exactly 5 s after the blow is still inside the window
assert(phaseOf(1) == "intermission", "wave 1 is dead")
seconds(C.intermissionSeconds + 1)
assert(phaseOf(1) == "wave" and last(1).wave == 2)
seconds(1); answer()
local second = live()
assert(#second >= 2, "wave 2: hostiles")
clock = clock + 1000
assert(hit(1, second[1], "round"))
clock = clock + C.hits.nativeCreditSeconds * 1000
nativeDeath(second[1])
assert(#creditList() == c0 + 2 and creditList()[c0 + 2][2] == 1, "5 s after the blow is still inside the window")
seconds(1)
assert(last(1).kills == 1 and last(2).kills == 1 and last(1).killsTotal == 2, "both native kills are counted")
-- a missile's own explosion can kill on the simulator before the blast's report reaches the server: the death waits
-- `nativeGraceSeconds` for the first validated blow of a pilot of the run on that hostile, then credits nobody
assert(#second >= 3, "wave 2 has a third hostile")
local before = #creditList()
nativeDeath(second[2])
assert(#creditList() == before, "a native death with no blow yet credits nobody at once")
clock = clock + C.hits.nativeGraceSeconds * 1000 - 100
local away = { x = positions[1].x + 400, y = positions[1].y, z = positions[1].z }
assert(refusal(1, second[2], "blast", { titan = away }) == "too_far", "the late report passes the range check like any blow")
assert(refusal(1, second[2], "round", { record = "Attacks.Nope" }) == "no_price", "and the price check")
assert(refusal(2, second[2], "blast") == "locked" and #creditList() == before, "and the class check (Legion fires no missiles): nobody credited yet")
assert(hit(1, second[2], "blast"), "the blast's report inside the grace is admitted")
assert(#creditList() == before + 1 and creditList()[before + 1][2] == 1, "and takes the kill for its pilot")
assert(refusal(2, second[2], "melee") == "not_enemy", "only once")
nativeDeath(second[3])
clock = clock + C.hits.nativeGraceSeconds * 1000 + 1
assert(refusal(1, second[3], "blast") == "not_enemy" and #creditList() == before + 1, "a report after the grace credits nobody")
seconds(1)
assert(last(1).kills == 2, "the late blast's kill is counted")
Missions.fail(inst.id, "next")

-- ═══════════════════════ run C: four pilots ═══════════════════════
wipeStage(); calls, notices, respawned = {}, {}, {}
for id in pairs(npcs) do npcs[id] = nil end
paid = {}
inst = board({ 1, 2, 3, 4 })
land({ 1, 2, 3, 4 })
-- operator 4 loads slowly: the others wait in the arrival phase, then the road moves on without 4
for _, id in ipairs({ 1, 2, 3 }) do reportArrived(id) end
assert(phaseOf(1) == "arrive" and #inst.members == 4, "waiting for the fourth")
seconds(C.arriveSeconds - 3)
assert(#inst.members == 4)
seconds(4)
assert(#inst.members == 3 and Missions.instanceOf(4) == nil and buckets[4] == 0 and phaseOf(1) == "pick", "the fourth never came: told, sent home, the run goes on")
local told
for _, n in ipairs(notices) do if n.id == 4 and n.notice.body:find("Titan") then told = true end end
assert(told, "and told")
assert(last(4).phase == "ended", "the fourth's page is closed")
assert(#callsOf("spawn", 4) == 0)
-- the three go on, the cap lowered to 3: wave 1 of three pilots is 5, the others come in as hostiles die
for _, id in ipairs({ 1, 2, 3 }) do actions["titan.class"](id, { id = ({ "northstar", "legion", "vanguard" })[id] }); actions["titan.ready"](id) end
assert(phaseOf(1) == "countdown")
C.maxAlive = 3
seconds(C.countdownSeconds + 1)
assert(last(1).waveSize == waveOf(1, 3) and last(1).waveSize == 5, "wave 1 of 3 pilots")
seconds(1)
assert(answer(), "the ground probe") -- asked for what the cap lets in, not for the whole wave
assert(#live() == 3 and last(1).enemies == 5, "the cap holds the wave at three alive")
seconds(2)
assert(#live() == 3 and not answer(), "nothing more while three are alive")
-- Northstar's rail: 100 percent. The hostile dies without a death event: it leaves the count after a moment.
clock = clock + 2000
local rail = select(2, hit(1, live()[1], "round"))
assert(rail == 100 and #live() == 2, "the railgun")
seconds(4)
assert(answer() and #live() == 3, "a probe for the next one once the dead one left the count")
C.maxAlive = 16
clearWave(1)
assert(phaseOf(1) == "intermission" and last(1).wave == 1)
Missions.complete(inst.id)

-- the same through a four-pilot wave 10: 30 hostiles, never more than 16 at once
wipeStage(); calls, notices, respawned = {}, {}, {}
for id in pairs(npcs) do npcs[id] = nil end
inst = board({ 1, 2, 3, 4 })
toWaves(inst, { 1, 2, 3, 4 }, { [1] = "vanguard", [2] = "ronin", [3] = "northstar", [4] = "legion" })
assert(last(1).waveSize == 4 + 2 * 0 + 2 * (1 + 0) and last(1).waveSize == 6, "wave 1 of 4 pilots")
local biggest = 0
for n = 1, 10 do
    assert(last(1).waveSize == waveOf(n, 4), ("wave %d of 4 pilots"):format(n))
    clearWave(1, function() biggest = math.max(biggest, #live()); assert(#live() <= 16) end)
    if n < 10 then seconds(C.intermissionSeconds + 1) end
end
assert(biggest == 16, "wave 10 of four: 30 hostiles, 16 at a time, the rest as others die")
seconds(C.victorySeconds + 1)
assert(not Missions.instanceOf(1) and inst.report.waves == 10)

-- ═══════════════════════ the ground probe fails ═══════════════════════
wipeStage(); calls, notices, respawned = {}, {}, {}
for id in pairs(npcs) do npcs[id] = nil end
inst = board({ 1, 2 })
toWaves(inst, { 1, 2 }, { [1] = "vanguard", [2] = "vanguard" })
seconds(1)
local first = probes()[#probes()]
assert(first and not answered[first], "the first probe is out")
-- a client that never answers: the probe times out, the other pilot is asked
local asked = #probes()
seconds(math.ceil(C.probe.timeoutMs / 1000) + 1)
assert(#probes() > asked and probes()[#probes()].target ~= first.target, "timed out: the other pilot is asked")
assert(#live() == 0)
-- the late answer of the first one is not a request in flight any more
_G.source = first.target
netHandlers["op77_lightrp:titan:ground"](first.payload.id, { 1, 2 }, { first.payload.points[1].z, first.payload.points[2].z })
assert(#live() == 0, "a late answer is ignored")
-- no level ground in the answers either: three failures in a row drop the wave at the pilots' height
answer(function() return nil end)
seconds(1)
answer(function() return nil end)
seconds(1)
assert(#live() == 4, "the wave arrived after the probes failed: " .. #live())
local cz = (positions[1].z + positions[2].z) / 2
local cx, cy = (positions[1].x + positions[2].x) / 2, (positions[1].y + positions[2].y) / 2
for _, id in ipairs(live()) do
    local n = npcs[id]
    assert(math.abs(n.z - (cz + C.spawnLift)) < 0.06, "dropped at the pilots' height")
    local r = math.sqrt((n.x - cx) ^ 2 + (n.y - cy) ^ 2)
    assert(r >= C.ring.min - 0.2 and r <= C.ring.max + 0.2, "still on the ring")
    assert(clearOfPilots(n, { 1, 2 }), "and clear of both pilots")
end
Missions.fail(inst.id, "end of the probe test")

-- ═══════════════════════ hostiles keep clear of every Titan ═══════════════════════
-- two pilots 100 m apart: the ring around their centroid runs through each one's 80 m, so the draws skip those arcs
wipeStage(); calls, notices, respawned = {}, {}, {}
for id in pairs(npcs) do npcs[id] = nil end
inst = board({ 1, 2 })
toWaves(inst, { 1, 2 }, { [1] = "vanguard", [2] = "vanguard" })
positions[1].x, positions[2].x = positions[1].x - 50, positions[2].x + 50
-- and pilot 1's Titan left standing on the ring, north of the pair: its accepted pose is kept clear of too
local pcx, pcy = (positions[1].x + positions[2].x) / 2, (positions[1].y + positions[2].y) / 2
poseOf[1] = { x = pcx, y = pcy + 115, z = positions[1].z }
answer(function() return nil end) -- the probe drawn before they moved finds nothing: the next one is drawn around them now
seconds(1)
local wide = probes()[#probes()]
assert(not answered[wide], "a new probe")
assert(wide and #wide.payload.points > 0, "a probe")
for _, p in ipairs(wide.payload.points) do
    assert(clearOfPilots(p, { 1, 2 }), "every point clear of both pilots")
    assert(math.sqrt((p.x - poseOf[1].x) ^ 2 + (p.y - poseOf[1].y) ^ 2) >= C.ring.clear - 0.2, "and of the standing Titan")
end
-- a pilot walks up to a point while the client looks: that point is not used, the others are
local target = wide.payload.points[1]
positions[1].x, positions[1].y = target.x + 10, target.y
answer()
for _, id in ipairs(live()) do
    assert(clearOfPilots(npcs[id], { 1, 2 }), "no hostile within 80 m of a pilot where they stand now")
    assert(not (npcs[id].x == target.x and npcs[id].y == target.y), "not the point the pilot came near")
end
assert(#live() > 0, "the other points are used")
poseOf[1] = nil
Missions.fail(inst.id, "end of the clearance test")

-- ═══════════════════════ hostiles that cannot be created ═══════════════════════
wipeStage(); calls, notices, respawned = {}, {}, {}
for id in pairs(npcs) do npcs[id] = nil end
inst = board({ 1, 2 })
refuseNpc["Character.max_border_guards"] = true
toWaves(inst, { 1, 2 }, { [1] = "vanguard", [2] = "vanguard" })
seconds(1); answer()
assert(#live() == 4, "a refused record: the others are used")
for _, id in ipairs(live()) do assert(npcs[id].def.record ~= "Character.max_border_guards") end
Missions.fail(inst.id, "next")

wipeStage(); calls, notices, respawned = {}, {}, {}
for id in pairs(npcs) do npcs[id] = nil end
inst = board({ 1, 2 })
for _, record in ipairs({ "Character.max_border_guards", "Character.max_border_guards_shotgun", "gang_valentinos_ranged_01", "hostile_female_ranged_lab" }) do refuseNpc[record] = true end
toWaves(inst, { 1, 2 }, { [1] = "vanguard", [2] = "vanguard" })
for _ = 1, C.spawnFailures + 3 do
    seconds(1); answer()
    if not Missions.instanceOf(1) then break end
end
assert(not Missions.instanceOf(1) and last(1).result == "failed" and #live() == 0, "every record refused: the run is called off, not waited on")
for record in pairs(refuseNpc) do refuseNpc[record] = nil end

-- ═══════════════════════ the staff test start ═══════════════════════
wipeStage(); calls, notices, respawned = {}, {}, {}
for id in pairs(npcs) do npcs[id] = nil end
paid = {}
welcome(5); welcome(6)
local okc, textc = commands["titan.assault"](0, {})
assert(not okc, "the console needs a player")
okc, textc = commands["titan.assault"](5, {})
assert(okc and Missions.instanceOf(5), "a solo pilot launches a run: the crew minimum is waived")
inst = Missions.instanceOf(5)
assert(inst.test == true and #inst.members == 1 and inst.point == POINT, "marked as a test")
-- a solo wave: the size has no extra term
toWaves(inst, { 5 }, { [5] = "northstar" })
assert(last(5).waveSize == 4, "a solo run: wave 1 is 4")
Missions.complete(inst.id)
assert(not paid[5], "a test run pays nothing")
assert(not Missions.instanceOf(5))
okc = commands["titan.assault"](0, { "5" })
assert(okc and Missions.instanceOf(5) and Missions.instanceOf(5).test, "the target by id")
Missions.fail(Missions.instanceOf(5).id, "again")
-- a crew: the caller and the crew come along; five do not fit
assert(Parties.invite(5, 6) and Parties.accept(6))
okc = commands["titan.assault"](5, {})
assert(okc and Missions.instanceOf(5) and Missions.instanceOf(6) == Missions.instanceOf(5) and #Missions.instanceOf(5).members == 2, "the crew comes along")
Missions.fail(Missions.instanceOf(5).id, "again")
for id = 7, 10 do welcome(id); assert(Parties.invite(5, id) and Parties.accept(id)) end
okc, textc = commands["titan.assault"](5, {})
assert(not okc and textc:find("At most 4"), "a crew past the maximum is refused: " .. tostring(textc))

-- ═══════════════════════ a hostile under the ground is put back on it ═══════════════════════
wipeStage(); calls, notices, respawned = {}, {}, {}
for id in pairs(npcs) do npcs[id] = nil end
inst = board({ 1, 2 })
toWaves(inst, { 1, 2 }, { [1] = "vanguard", [2] = "vanguard" })
seconds(1); answer()
assert(#live() == 4, "the wave is in")
seconds(math.ceil(C.sink.everyMs / 1000) + 1)
local check = checks()[#checks()]
assert(check and #check.payload.points == 4 and (check.target == 1 or check.target == 2), "a pilot's client is asked for the ground under the four")
local sunk, shallow = live()[1], live()[2]
local p1 = check.payload.points
transforms = {}
local indexOf = {}
for i, p in ipairs(p1) do for _, id in ipairs(live()) do if npcs[id].x == p.x and npcs[id].y == p.y then indexOf[id] = i end end end
local ground = {}
for _, id in ipairs(live()) do ground[id] = npcs[id].z end
ground[sunk] = npcs[sunk].z + 1.5     -- 1.5 m under its ground
ground[shallow] = npcs[shallow].z + 0.5 -- half a metre: a slope, a step, nothing to fix
local indices, heights = {}, {}
for _, id in ipairs(live()) do indices[#indices + 1], heights[#heights + 1] = indexOf[id], ground[id] end
-- another pilot, or another request, is not believed
_G.source = check.target == 1 and 2 or 1
netHandlers["op77_lightrp:titan:ground"](check.payload.id, indices, heights)
assert(#transforms == 0, "only the pilot asked")
_G.source = check.target
netHandlers["op77_lightrp:titan:ground"](check.payload.id, indices, heights)
assert(#transforms == 1 and transforms[1].id == sunk, "the one under the ground is moved, the other is left")
assert(math.abs(transforms[1].t.position.z - (ground[sunk] + C.spawnLift)) < 1e-9, "put back on its ground")
netHandlers["op77_lightrp:titan:ground"](check.payload.id, indices, heights)
assert(#transforms == 1, "an answer counts once")
assert(check.payload.reach == C.sink.reach, "a check looks as far as the configuration says")
-- hanging in the air: one hostile 50 m over its ground at the same place in two checks is put down; one 30 m over it that moved
-- between them (in flight) is left
local hung, flying = live()[3], live()[4]
local function answerCheck(over)
    local c = checks()[#checks()]
    local idx, hs = {}, {}
    for i, p in ipairs(c.payload.points) do
        for _, id in ipairs(live()) do
            if npcs[id].x == p.x and npcs[id].y == p.y then idx[#idx + 1], hs[#hs + 1] = i, npcs[id].z - (over[id] or 0) end
        end
    end
    _G.source = c.target
    netHandlers["op77_lightrp:titan:ground"](c.payload.id, idx, hs)
    return c
end
transforms = {}
npcs[hung].z, npcs[flying].z = npcs[hung].z + 50, npcs[flying].z + 30 -- thrown up since the last check
seconds(math.ceil(C.sink.everyMs / 1000) + 1)
local second = answerCheck({ [hung] = 50, [flying] = 30 })
assert(second ~= check and #transforms == 0, "once over the ground is not enough: it may be in flight")
npcs[flying].x = npcs[flying].x + 20
seconds(math.ceil(C.sink.everyMs / 1000) + 1)
local hungGround = npcs[hung].z - 50
answerCheck({ [hung] = 50, [flying] = 30 })
assert(#transforms == 1 and transforms[1].id == hung, "still over its ground where the last check found it: put down; the moving one is left")
assert(math.abs(transforms[1].t.position.z - (hungGround + C.spawnLift)) < 1e-9, "put down on its ground")
-- more living hostiles than a check takes: the checks go round all of them
local max0, covered, count = C.sink.max, {}, 0
C.sink.max = 3
for _ = 1, 2 do
    seconds(math.ceil(C.sink.everyMs / 1000) + 1)
    local c = answerCheck({})
    for _, p in ipairs(c.payload.points) do
        for _, id in ipairs(live()) do if npcs[id].x == p.x and npcs[id].y == p.y then covered[id] = true end end
    end
end
C.sink.max = max0
for _ in pairs(covered) do count = count + 1 end
assert(count == #live() and count == 4, "two checks of three cover the four")
Missions.fail(inst.id, "end of the ground check")

-- ═══════════════════════ the last hostiles are marked ═══════════════════════
local function marksTo(id)
    local list = {}
    for _, e in ipairs(sent) do if e.name == "op77_lightrp:titan:marks" and e.target == id then list[#list + 1] = e.payload end end
    return list
end
-- twelve in wave 1 (scale 3): nothing marked while ten or more are left
wipeStage(); calls, notices, respawned = {}, {}, {}
for id in pairs(npcs) do npcs[id] = nil end
C.enemyScale = { standard = 3, hard = 3 }
sent = {}
inst = board({ 1, 2 })
toWaves(inst, { 1, 2 }, { [1] = "vanguard", [2] = "vanguard" })
assert(#marksTo(1) == 0, "nothing marked before the wave")
assert(last(1).waveSize == 12)
for _ = 1, 4 do seconds(1); answer() end
assert(#live() == 12 and #marksTo(1) == 0, "twelve left: no marks")
-- three die: nine left, every pilot is sent where each living one is, sorted by id
local dead = live()
for i = 1, 3 do die(dead[i], "player:1") end
seconds(1)
local m1, m2 = marksTo(1), marksTo(2)
assert(#m1 > 0 and #m2 > 0, "both pilots are sent the marks")
local list = m1[#m1]
assert(#list == 9, "the nine living ones: " .. #list)
local alive = live()
for i, mark in ipairs(list) do
    assert(mark.id == tostring(alive[i]), "by id, as text")
    local n = npcs[alive[i]]
    assert(mark.x == n.x and mark.y == n.y and mark.z == n.z, "where the server sees it")
end
-- they move: the next list follows
local mover = npcs[alive[1]]
mover.x = mover.x + 5
seconds(1)
list = marksTo(1)[#marksTo(1)]
assert(list[1].x == mover.x, "the marks follow the server's positions")
-- a dead one leaves the list at once, before the wave forgets it
npcs[alive[2]].health = 0
seconds(1)
list = marksTo(1)[#marksTo(1)]
assert(#list == 8, "a dead hostile is not marked")
-- the wave cleared: one empty list, then nothing more
clearWave(1)
local after = marksTo(1)
assert(#after[#after] == 0, "the marks are taken down")
local n = #after
seconds(3)
assert(#marksTo(1) == n, "and not sent again")
Missions.fail(inst.id, "end of the marks test")
C.enemyScale = { standard = 1, hard = 1 }

-- ═══════════════════════ the difficulties' scales ═══════════════════════
C.enemyScale = SCALES
-- standard: five times each wave
wipeStage(); calls, notices, respawned = {}, {}, {}
for id in pairs(npcs) do npcs[id] = nil end
inst = board({ 1, 2 })
toWaves(inst, { 1, 2 }, { [1] = "vanguard", [2] = "vanguard" })
assert(last(1).waveSize == 5 * waveOf(1, 2) and last(1).waveSize == 20, "standard: wave 1 of two pilots is 5 x 4")
assert(anyOf(1, "announce").body:find("20 hostiles"), "and the banner says so")
Missions.fail(inst.id, "next")
-- hard (a reputation tier the test characters do not have: launched by the staff command, which takes a difficulty)
wipeStage(); calls, notices, respawned = {}, {}, {}
for id in pairs(npcs) do npcs[id] = nil end
welcome(5)
okc, textc = commands["titan.assault"](5, { "5", "insane" })
assert(not okc and textc:find("Unknown difficulty"), "an unknown difficulty is refused: " .. tostring(textc))
okc, textc = commands["titan.assault"](5, { "5", "HARD" })
assert(okc and textc:find("HARD") and Missions.difficulty(Missions.instanceOf(5)).id == "hard", "hard by name: " .. tostring(textc))
inst = Missions.instanceOf(5)
toWaves(inst, { 5 }, { [5] = "northstar" })
assert(last(5).waveSize == 40, "a solo hard run: wave 1 is 10 x 4")
local hardClass = callsOf("setClass", 5)
assert(hardClass[#hardClass][3].harm == C.incoming.hard and hardClass[#hardClass][3].regen == C.shieldRegen.hard, "a hard run's Titans take the hard multiples")
-- the cap is scaled too: 3 alive at once on scale 1 is 30 here
C.maxAlive = 3
for _ = 1, 6 do seconds(1); answer() end
assert(#live() == 30 and last(5).enemies == 40, "ten times the cap of three: 30 alive of the 40")
C.maxAlive = 16
Missions.fail(inst.id, "next")
C.enemyScale = { standard = 1, hard = 1 }

-- ═══════════════════════ a pilot who cannot get a Titan ═══════════════════════
wipeStage(); calls, notices, respawned = {}, {}, {}
for id in pairs(npcs) do npcs[id] = nil end
inst = board({ 1, 2 })
land({ 1, 2 })
refuse.spawn = { [2] = 100 }
reportArrived(1); reportArrived(2)
assert(phaseOf(1) == "arrive")
for _ = 1, C.spawnRetries + 1 do seconds(C.retryMs / 1000 + 1) end
assert(Missions.instanceOf(2) == nil and #inst.members == 1, "five refusals: pilot 2 is told and sent home")
assert(phaseOf(1) == "pick", "the run goes on with the one who has a Titan")
refuse.spawn = {}
Missions.fail(inst.id, "next")

-- nobody gets one: the last pilot out fails the run
wipeStage(); calls, notices, respawned = {}, {}, {}
inst = board({ 1, 2 })
land({ 1, 2 })
refuse.spawn = { [1] = 100, [2] = 100 }
reportArrived(1); reportArrived(2)
seconds(C.arriveSeconds + 1)
assert(not Missions.instanceOf(1) and not Missions.instanceOf(2) and last(2).result == "failed", "nobody has a Titan: the run fails")
refuse.spawn = {}

-- a class the service refuses is tried again, the pilot stays held meanwhile
wipeStage(); calls, notices, respawned = {}, {}, {}
inst = board({ 1, 2 })
land({ 1, 2 })
reportArrived(1); reportArrived(2)
seconds(1)
assert(#callsOf("setClass", 1) == 1 and callsOf("setClass", 1)[1][3].id == "standby", "standing by on the fists")
refuse.setClass = { [1] = 2 }
for _, id in ipairs({ 1, 2 }) do actions["titan.class"](id, { id = "brawler" }); actions["titan.ready"](id) end
assert(phaseOf(1) == "pick" or phaseOf(1) == "starting", "the class is refused: not started")
assert(heldOf[1] and not heldOf[2] and #picked(1) == 1, "pilot 1 stays held, 2 is already free")
seconds(C.retryMs / 1000 + 1)
assert(heldOf[1] and #picked(1) == 2)
seconds(C.retryMs / 1000 + 1)
assert(not heldOf[1] and classOf[1] and #picked(1) == 3, "the third try lands")
seconds(1)
assert(phaseOf(1) == "countdown", "the countdown starts once everyone has their class")
Missions.fail(inst.id, "next")

-- a pilot who leaves: Titan removed, the run goes on; a Titan lost while alive is a down, not a wipe
wipeStage(); calls, notices, respawned = {}, {}, {}
inst = board({ 1, 2 })
toWaves(inst, { 1, 2 }, { [1] = "vanguard", [2] = "legion" })
local removes = #callsOf("remove", 2)
Missions.dismiss(2, "test")
assert(#callsOf("remove", 2) == removes + 1 and not titanOf[2] and #inst.members == 1 and last(2).phase == "ended", "a pilot who leaves loses their Titan")
assert(phaseOf(1) == "wave", "the run goes on")
loseTitan(1, "destroyed")
assert(phaseOf(1) == "wipe", "the only pilot down is a wipe")
Missions.fail(inst.id, "next")

-- ═══════════════════════ a death before the waves ═══════════════════════
-- sooner than in a wave, free (no down counted, no wipe), and the new Titan is held like the others until the class
wipeStage(); calls, notices, respawned = {}, {}, {}
inst = board({ 1, 2 })
land({ 1, 2 })
reportArrived(1); reportArrived(2)
assert(phaseOf(1) == "pick")
life[2] = "dead"; loseTitan(2, "owner_dead"); LightRP.eachModule("onLifeState", 2, "dead")
seconds(1)
assert(last(1).operators[2].down and not titanOf[2] and phaseOf(1) == "pick", "down in the picker: no wipe there")
seconds(1)
assert(#respawned == 0, "not at once")
seconds(2)
assert(#respawned == 1 and respawned[1].id == 2 and respawned[1].bucket == inst.bucket, "back after the short delay")
seconds(2)
local again = callsOf("spawn", 2)
assert(#again == 2 and again[2][4].piloted == true and again[2][4].hold == true and titanOf[2] and heldOf[2], "a new Titan, held until the class")
assert(#picked(2) == 0 and not last(1).operators[2].down, "the new Titan stands by on the fists, no class yet")
for _, id in ipairs({ 1, 2 }) do actions["titan.class"](id, { id = "ronin" }); actions["titan.ready"](id) end
assert(phaseOf(1) == "countdown" and #picked(2) == 1 and not heldOf[2], "then the class and the release as for everyone")
Missions.fail(inst.id, "next")
assert(inst.report.downs == 0, "a death before the waves is not counted")

-- ═══════════════════════ the service stops under a run ═══════════════════════
wipeStage(); calls, notices, respawned = {}, {}, {}
inst = board({ 1, 2 })
toWaves(inst, { 1, 2 }, { [1] = "vanguard", [2] = "vanguard" })
seconds(1); answer()
assert(#live() > 0)
resourceState = "stopped"
fire("onResourceStop", "op77_lightrp_titans", "manual")
assert(not Missions.instanceOf(1) and last(1).result == "failed", "the run fails when the Titan service goes down")
assert(#live() == 0, "the hostiles are gone")
assert(Missions.point(POINT) == nil, "and the point leaves the board")
resourceState = "running"
fire("onResourceStart", "op77_lightrp_titans")
assert(Missions.point(POINT) and not Missions.point(POINT).retired, "back on the board with the service")

print("PASS: Titan Assault: board only while the service runs, arrival handshake and held spawn with retries, class picker (timeout default), class + release, waves for 2/3/4 pilots with the alive cap, ground probe and fallback, Titan-reported hits (admission, pricing by class weapon and kind, applied as the pilot), kills and core from onNpcDied (player:<id>; native only after a recent admitted blow on that NPC), respawn with the class, wipe, victory payout, staff test start, dropped pilot, service stop")
