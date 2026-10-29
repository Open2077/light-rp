-- The Chimera raid (server/modules/mission_chimera.lua) on top of the mission
-- module, with the host and the open77_chimera provider stubbed: ready check,
-- launch countdown, boss placement (probe, then the fallback), passive intro,
-- the fight with its scaling, reinforcement waves, phase announcements, target
-- lock, respawns from the team pool, enrage, victory with payout, the wipe and
-- critical's no-respawn rule.
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
local sent, paid, respawned, netHandlers = {}, {}, {}, {}
_G.GetPlayers = function() local t = {} for id in pairs(positions) do t[#t + 1] = tostring(id) end table.sort(t) return t end
_G.GetPlayerRoutingBucket = function(id) return buckets[id] or 0 end
_G.SetPlayerRoutingBucket = function(id, b) buckets[id] = b return true end
_G.TriggerClientEvent = function(name, target, payload) sent[#sent + 1] = { name = name, target = target, payload = payload } end
_G.RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
local eventHandlers = {}
_G.AddEventHandler = function(name, fn) eventHandlers[name] = fn end
-- native weapons: every request completes at once
local weaponOps, explosions, requestSeq = {}, {}, 0
mockReserve = nil
held = {}
failWeapons = 0
failAssign = 0
healedPlayers = {}
emptyGun = {}
local played, loops, loopSeq = {}, {}, 0
local function playedName(name) for _, e in ipairs(played) do if e.name == name then return e end end end
local function loopsOf(effect) local n = 0 for _, d in pairs(loops) do if d.effect == effect then n = n + 1 end end return n end
local weaponsApi = {}
for _, m in ipairs({ "clear", "assign", "setAmmo", "requestSnapshot", "setActive" }) do
    weaponsApi[m] = function(player, ...)
        if failWeapons > 0 then failWeapons = failWeapons - 1; return nil, "queue_full" end
        if m == "assign" and failAssign > 0 then failAssign = failAssign - 1; return nil, "queue_full" end
        requestSeq = requestSeq + 1
        weaponOps[#weaponOps + 1] = { player = player, method = m, args = { ... } }
        held[player] = held[player] or {}
        if m == "clear" then held[player] = {} elseif m == "assign" then held[player][select(2, ...)] = select(1, ...) end
        local rounds = held[player][1] and (emptyGun[player] and 0 or 30) or 0
        local result = m == "requestSnapshot" and { slots = { { slot = 1, record = held[player][1], ammo = { capacity = 30, reserve = mockReserve, total = rounds } },
            { slot = 2, record = held[player][2], ammo = { capacity = 12, reserve = mockReserve } } } } or true
        eventHandlers["open77:weapons:completed"](player, requestSeq, m, true, nil, result)
        return requestSeq
    end
end

-- the provider
local bosses, calls, npcs, npcSeq = {}, {}, {}, 100
local probe = "ok"
local function bossState(b) return { id = b.id, alive = b.health > 0, health = b.health, healthPercent = b.health, phase = b.phase, position = b.position, bucket = b.bucket,
    aiEnabled = b.setAIEnabled ~= false, combatEnabled = b.setCombatEnabled ~= false, maxHealth = 100, repairing = b.repairing == true } end
local provider = {
    spawn = function(player, options)
        local p = positions[player]
        if probe ~= "ok" then return 1 end
        local b = { id = "boss1", health = 100, phase = "armored", position = { x = p.x + 18, y = p.y, z = p.z }, bucket = buckets[player], log = {} }
        bosses[b.id] = b
        return 1
    end,
    result = function() if probe ~= "ok" then return { status = "failed", reason = probe } end return { status = "created", id = "boss1" } end,
    create = function(options)
        local b = { id = "boss2", health = 100, phase = "armored", position = options.position, bucket = options.bucket, log = {} }
        bosses[b.id] = b
        return bossState(b)
    end,
    get = function(id) local b = bosses[id]; return b and bossState(b) end,
    list = function() return {} end,
    remove = function(id) bosses[id] = nil; return true end,
    setHealth = function(id, h) local b = bosses[id]; b.log[#b.log + 1] = { "setHealth", h }; b.health = h; return bossState(b) end,
    applyDamage = function(id, amount) local b = bosses[id]; b.log[#b.log + 1] = { "applyDamage", amount }; return bossState(b) end,
}
for _, m in ipairs({ "setDifficulty", "setDamagePolicy", "setAIEnabled", "setCombatEnabled", "setTarget" }) do
    provider[m] = function(id, value) local b = bosses[id]; if not b then return nil, "boss_not_found" end; b.log[#b.log + 1] = { m, value }; b[m] = value; return bossState(b) end
end
_G.Open77 = {
    weapons = weaponsApi,
    effects = { explosion = function(position, opts) explosions[#explosions + 1] = { position = position, opts = opts }; return { players = {}, vehicles = {} } end,
        play = function(name, opts) played[#played + 1] = { name = name, opts = opts }; return true end,
        create = function(def) loopSeq = loopSeq + 1; loops[tostring(loopSeq)] = def; return tostring(loopSeq) end,
        update = function(id, patch) for k, v in pairs(patch) do loops[id][k] = v end; return true end,
        remove = function(id) loops[id] = nil; return true end },
    exports = { callSync = function(res, method, ...) assert(res == "open77_chimera"); calls[#calls + 1] = method; return provider[method](...) end },
    npcs = { ai = { native = 2 }, damage = { mortal = 0, immortal = 1, invulnerable = 2 },
        create = function(def) npcSeq = npcSeq + 1; npcs[npcSeq] = { def = def, health = 100 }; return npcSeq end,
        get = function(id) return npcs[id] end, remove = function(id) npcs[id] = nil; return true end,
        tasks = { attack = function() return true end } },
    players = {
        position = function(id) local p = positions[id]; return p and { x = p.x, y = p.y, z = p.z, bucket = buckets[id] or 0 } end,
        get = function(id) return { position = positions[id], health = 100, maxHealth = 100, armor = 0, lifePhase = life[id] or "alive" } end,
        getLifeState = function(id) return { phase = life[id] or "alive" } end,
        teleport = function(id, spot, opts)
            return { await = function() buckets[id] = opts.bucket; positions[id] = { x = spot.x, y = spot.y, z = spot.z }; return true end }
        end,
        heal = function(id, amount) healedPlayers[id] = amount; return true, amount end,
        respawn = function(id, opts) respawned[#respawned + 1] = { id = id, bucket = opts.bucket }; life[id] = "alive"; buckets[id] = opts.bucket
            positions[id] = { x = opts.position.x, y = opts.position.y, z = opts.position.z }
            LightRP.eachModule("onLifeState", id, "alive") -- the platform announces the new life
            return true end,
    },
}
_G.LightRpEvents = { net = { mission = "op77_lightrp:mission" } }
_G.LightRpConfig = { keys = { raidReady = { key = "Y" } }, spawn = { health = 100 } }

local modules, actions, commands, providers = {}, {}, {}, {}
local chars = {}
_G.LightRP = {
    nowMs = function() return clock end, log = function() end,
    module = function(name, def) def.name = name; modules[#modules + 1] = def; LightRP[name] = LightRP[name] or def; return def end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if m[hook] then m[hook](...) end end end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    stateProvider = function(key, fn) providers[key] = fn end,
    state = function() end, notice = function() end, result = function() end,
    dialog = function(id, kind, payload) payload.kind = kind end,
    interaction = function() end,
    characters = {
        isRegistered = function(id) return chars[id] ~= nil end,
        displayName = function(id) return chars[id] or ("P" .. id) end,
        get = function(id) return chars[id] and { status = "active", identifier = "id-" .. id, key = "default" } end,
    },
    money = { addBank = function(id, amount) paid[id] = (paid[id] or 0) + amount; return true end, format = function(n) return "$" .. n end },
    db = { ready = false, schema = function() end, single = function() end, run = function() end },
}

dofile("server/config/missions.lua")
dofile("server/modules/parties.lua")
dofile("server/modules/missions.lua")
dofile("server/modules/mission_chimera.lua")
local Missions = LightRP.missions
local point = Missions.point("chimera_raid")
assert(point and point.arena, "the raid point is configured")

local function last(id)
    for i = #sent, 1, -1 do if sent[i].name == "op77_lightrp:raid" and sent[i].target == id then return sent[i].payload end end
end
local function any(id, key)
    for i = #sent, 1, -1 do local p = sent[i].payload; if sent[i].name == "op77_lightrp:raid" and sent[i].target == id and type(p) == "table" and p[key] then return p[key] end end
end
-- ── standard, two operators ──
local session = {}
LightRP.dialog = function(id, kind, payload) payload.kind = kind; session[id] = payload.session end
for i, id in ipairs({ 1, 2 }) do
    chars[id] = "Op" .. id
    positions[id] = { x = point.position.x + i * 0.5, y = point.position.y, z = point.position.z }; buckets[id] = 0
    Missions.onCharacterLoaded(id)
    assert(Missions.open(id, "chimera_raid"))
    clock = clock + 2000
    actions["mission.tag"](id, { session = session[id], difficulty = "standard" })
end
assert(commands["missions.launch"](0, { "1" }))
local inst = Missions.instanceOf(1)
assert(inst and #inst.members == 2 and buckets[1] == inst.bucket, "launched into the arena")
local p = last(1)
assert(p and p.phase == "ready" and p.readyEndsInMs > 0 and #p.operators == 2, "ready check")
-- death before the fight: free respawn
assert(Missions.handlesDeath(1), "a death in the raid is the raid's")
life[1] = "dead"; LightRP.eachModule("onLifeState", 1, "dead")
seconds(4)
assert(#respawned == 1 and respawned[1].bucket == inst.bucket and life[1] == "alive", "respawned in the arena before the fight")
-- ready
-- the ready check lists the kits; player 1 picks the breacher and readies from the page
assert(last(1).loadouts and #last(1).loadouts == #LightRpRaid.loadouts and last(1).loadout == "assault")
actions["raid.loadout"](1, { id = "breacher" })
assert(last(1).loadout == "breacher")
-- nobody is ready before their arena finished loading
assert(last(1).loaded == false and last(1).arena)
local ops0 = #weaponOps
actions["raid.ready"](1)
assert(not last(1).operators[1].ready and #weaponOps == ops0, "ready refused while loading, no weapon request")
-- a report from far away is not believed; one from the arena is
local real = positions[1]; positions[1] = { x = real.x + 500, y = real.y, z = real.z }
_G.source = 1; netHandlers["op77_lightrp:raid:loaded"]()
assert(last(1).loaded == false, "loaded report away from the arena ignored")
positions[1] = real
_G.source = 1; netHandlers["op77_lightrp:raid:loaded"]()
assert(last(1).loaded == true and last(1).operators[1].loaded)
-- the ready check waits for operator 2, who is still loading
clock = clock + (LightRpRaid.readySeconds + 5) * 1000
seconds(1)
assert(last(1).phase == "ready", "the ready check waits for a loading operator")
_G.source = 2; netHandlers["op77_lightrp:raid:loaded"]()
actions["raid.ready"](1)
seconds(2) -- the kit follows once the page let the mouse go
local assigned = {}
for _, op in ipairs(weaponOps) do if op.player == 1 and op.method == "assign" then assigned[#assigned + 1] = op.args[1] end end
assert(assigned[#assigned - 1] == "Items.Preset_Carnage_Default" and assigned[#assigned] == "Items.Preset_Unity_Default", "breacher kit handed out")
assert(Missions.handlesLoadout(1), "the raid owns the weapons")
assert(last(2).operators[1].ready)
_G.source = 2; netHandlers["op77_lightrp:raid:ready"]()
assert(last(1).phase == "launch", "everyone ready (or the timer ran out): launch countdown")
seconds(LightRpRaid.launchSeconds + 1)
seconds(2)
local p2 = {}
for _, op in ipairs(weaponOps) do if op.player == 2 and op.method == "assign" then p2[#p2 + 1] = op.args[1] end end
assert(p2[1] == "Items.Preset_Ajax_Default", "default kit for operator 2")
local intro = any(1, "intro")
assert(intro and intro.boss and intro.durationMs == LightRpRaid.introSeconds * 1000 and intro.entry, "intro sent with the boss position")
assert(last(1).phase == "intro" and last(1).music and last(1).music.file:find("raid_ost"), "the music starts with the intro")
local b = bosses.boss2
assert(b and b.position.x == point.boss.x and b.position.y == point.boss.y, "placed on its stand")
assert(b.setDamagePolicy == 2 and b.setCombatEnabled == false and b.setAIEnabled == nil, "passive and invulnerable during the intro, AI untouched")
seconds(LightRpRaid.introSeconds + 1)
assert(last(1).phase == "fight", "fight")
local s = LightRpRaid.scaling.standard
assert(b.setDifficulty.healthMultiplier == s.health + s.healthPerOperator and b.setDifficulty.damageMultiplier == s.damage, "scaled to 2 operators")
assert(b.setDamagePolicy == 0 and b.setCombatEnabled == true)
-- strikes: the first barrage telegraphs, then explodes on the operators
seconds(7)
local telegraphed = any(1, "strikes")
assert(telegraphed and #telegraphed >= 2 and telegraphed[1].radius == LightRpRaid.barrage.radius, "barrage telegraphed")
seconds(3)
local barrage, purge = 0, 0
for _, e in ipairs(explosions) do
    assert(e.opts.bucket == inst.bucket, "in the arena bucket")
    if e.opts.damage == LightRpRaid.barrage.damage.standard then barrage = barrage + 1; assert(e.opts.vfx == LightRpRaid.barrage.vfx) end
    if e.opts.damage == LightRpRaid.purge.damage.standard then purge = purge + 1; assert(e.opts.vfx == LightRpRaid.purge.vfx) end
end
assert(barrage >= 2, "barrage exploded on both operators")
assert(purge >= 1, "the operators next to the machine got the purge")
assert(last(1).music and last(1).music.file:find("raid_ost"), "fight music")
-- a boss that lost its AI during the fight gets it back
b.setAIEnabled = false
seconds(1)
assert(b.setAIEnabled == true, "watchdog re-enabled the AI")
-- the reserve runs low: topped back up at the next resupply
local function reserveSets(player)
    local n = 0
    for _, op in ipairs(weaponOps) do if op.player == player and op.method == "setAmmo" and op.args[2].reserve and op.args[2].magazine == nil then n = n + 1 end end
    return n
end
local before = reserveSets(1)
mockReserve = 5
seconds(LightRpRaid.resupply.every + 1)
assert(reserveSets(1) >= before + 2, "low reserve topped up")
local topped
for _, op in ipairs(weaponOps) do if op.player == 1 and op.method == "setAmmo" and op.args[1] == 1 then topped = op.args[2].reserve end end
assert(topped == LightRpRaid.loadouts[2].reserve[1], "back to the breacher's full reserve")
mockReserve = 1000
before = reserveSets(1)
seconds(LightRpRaid.resupply.every + 1)
assert(reserveSets(1) == before, "a full reserve is left alone")
-- weapons lost in the fight (a client that was still loading refused them all):
-- the resupply check sees no kit in hand and issues it again, retrying past refusals
held[1] = {}
failWeapons = 1          -- the first check itself is refused: nothing is concluded from it
seconds(LightRpRaid.resupply.every + 1)
assert(held[1][1] == nil)
failAssign = 2           -- the reissue's first attempt is refused, the retry lands
seconds(LightRpRaid.resupply.every)
assert(failAssign == 0)
seconds(5)
assert(held[1][1] == LightRpRaid.loadouts[2].primary, "kit issued again: " .. tostring(held[1][1]))

-- body hits: priced by the raid within the operator's budget, applied once per tick
local function damageCalls() local n, sum = 0, 0 for _, e in ipairs(b.log) do if e[1] == "applyDamage" then n = n + 1; sum = sum + e[2] end end return n, sum end
local n0, sum0 = damageCalls()
_G.source = 1
for _ = 1, 50 do netHandlers["op77_lightrp:raid:hit"](last(1).bossId) end
netHandlers["op77_lightrp:raid:hit"]("someone-else")
seconds(1)
local n1, sum1 = damageCalls()
local B, H = LightRpRaid.bodyHits, s.health + s.healthPerOperator
local cap = 100 * B.perSecond / 100 / H * (b.phase == "armored" and B.armored or 1)
assert(n1 == n0 + 1 and sum1 - sum0 > 0 and sum1 - sum0 <= cap + 1e-6, ("one batched hit, within the budget: %s <= %s"):format(sum1 - sum0, cap))
-- out of range: nothing
local home = positions[1]; positions[1] = { x = home.x + 500, y = home.y, z = home.z }
clock = clock + 2000
netHandlers["op77_lightrp:raid:hit"](last(1).bossId); seconds(1)
assert(select(1, damageCalls()) == n1, "a hit from out of range is not priced")
positions[1] = home
-- the repair cycle: announced, cut to the raid's length, then "shield down"
b.repairing = true
seconds(1)
assert(any(1, "announce").title == "REPAIR CYCLE" and last(1).boss.repairing and last(1).boss.repairInMs > 0, "repair announced")
local healthSets = 0 for _, e in ipairs(b.log) do if e[1] == "setHealth" then healthSets = healthSets + 1 end end
seconds(LightRpRaid.repairSeconds.standard + 1)
local after = 0 for _, e in ipairs(b.log) do if e[1] == "setHealth" then after = after + 1 end end
assert(after == healthSets + 1, "the repair is cut short through setHealth")
b.repairing = false
seconds(1)
assert(any(1, "announce").title == "SHIELD DOWN" and not last(1).boss.repairing)
-- a gun with no rounds (a refused draw) is not "armed": the check issues the kit again
emptyGun[1] = true
local reissued = 0 for _, op in ipairs(weaponOps) do if op.player == 1 and op.method == "clear" then reissued = reissued + 1 end end
seconds(LightRpRaid.resupply.every + 1)
local after = 0 for _, op in ipairs(weaponOps) do if op.player == 1 and op.method == "clear" then after = after + 1 end end
assert(after > reissued, "an empty kit weapon is issued again")
emptyGun[1] = nil
seconds(10)
-- a wave at 75%: the drop tops every reserve up, even one above the periodic threshold
mockReserve = LightRpRaid.loadouts[2].reserve[1] - 1
before = reserveSets(1)
b.health = 74; b.phase = "exposed"
seconds(1)
assert(reserveSets(1) > before, "the wave came with a full resupply")
mockReserve = nil
local adds = 0 for _ in pairs(npcs) do adds = adds + 1 end
assert(adds == s.adds + s.addsPerOperator, "wave of " .. adds)
assert(loopsOf(LightRpRaid.fx.drop) == adds, "a flare where every reinforcement drops")
assert(playedName(LightRpRaid.fx.phase[1]) and playedName(LightRpRaid.fx.phase[1]).opts.bucket == inst.bucket, "the phase change flashes on the machine")
assert(any(1, "announce").title == "REINFORCEMENTS" or any(1, "announce").title == "ARMOR BREACHED")
assert(last(1).boss.healthPercent == 74 and last(1).adds == adds)
-- a death in the fight: respawn after respawnSeconds
local before = #respawned
-- everyone down at once with respawns pending is not a wipe
life[1] = "dead"; LightRP.eachModule("onLifeState", 1, "dead")
life[2] = "dead"; LightRP.eachModule("onLifeState", 2, "dead")
seconds(1)
assert(last(1).phase == "fight", "respawns pending: still fighting")
seconds(s.respawnSeconds + 1)
LightRP.eachModule("onLifeState", 1, "alive")
LightRP.eachModule("onLifeState", 2, "alive")
before = #respawned
life[2] = "dead"; LightRP.eachModule("onLifeState", 2, "dead")
assert(last(2).respawnInMs and last(2).respawnInMs > 0)
local ops = #weaponOps
seconds(s.respawnSeconds + 1)
assert(#respawned == before + 1 and life[2] == "alive", "respawned after the timer")
seconds(2)
assert(#weaponOps > ops, "loadout handed out again after the respawn")
LightRP.eachModule("onLifeState", 2, "alive")
-- target lock (two operators)
seconds(40)
local locked = false for _, entry in ipairs(b.log) do if entry[1] == "setTarget" and entry[2] then locked = true end end
assert(locked, "the boss locked on an operator")
-- enrage
clock = clock + s.enrageMinutes * 60000
seconds(1)
assert(last(1).boss.enraged and b.setDifficulty.damageMultiplier > s.damage, "enraged")
assert(loopsOf(LightRpRaid.fx.enraged) == 1, "the overclock aura")
b.position = { x = b.position.x + 3, y = b.position.y, z = b.position.z }
seconds(1)
for _, d in pairs(loops) do if d.effect == LightRpRaid.fx.enraged then assert(d.position.x == b.position.x, "the aura follows the machine") end end
-- victory
b.health = 0
seconds(1)
assert(last(1).phase == "victory")
for _ in pairs(npcs) do error("reinforcements left after the kill") end
assert(loopsOf(LightRpRaid.fx.enraged) == 0 and loopsOf(LightRpRaid.fx.wreck[1]) == 1 and playedName(LightRpRaid.fx.death[1]), "it dies in a blast and burns")
seconds(LightRpRaid.victorySeconds + 1)
assert(not Missions.instanceOf(1) and paid[1] == point.difficulties[1].payout and paid[2] == paid[1], "paid")
assert(bosses.boss2 == nil, "boss removed")
assert(next(loops) == nil, "no effect left in the arena")
assert(last(1).phase == "ended" and buckets[1] == 0, "home")
assert(not Missions.handlesLoadout(1), "weapons back to the character")

-- ── critical alone: the stand is refused, the probe fails, the fallback places it; no respawn, wipe ──
probe = "boss_spawn_timeout"
local create = provider.create
local refusedOnce = false
provider.create = function(options)
    if not refusedOnce then refusedOnce = true; return nil, "boss_position_invalid" end
    return create(options)
end
paid = {}
commands["missions.rep"](0, { "3", "5000" })
chars[3] = "Op3"; positions[3] = { x = point.position.x, y = point.position.y, z = point.position.z }; buckets[3] = 0
Missions.onCharacterLoaded(3)
commands["missions.unlock"](0, { "3", "chimera_raid", "standard" }); commands["missions.unlock"](0, { "3", "chimera_raid", "hard" })
assert(Missions.open(3, "chimera_raid")); clock = clock + 2000
actions["mission.tag"](3, { session = session[3], difficulty = "critical" })
assert(commands["missions.launch"](0, { "3" }))
local inst2 = Missions.instanceOf(3)
assert(inst2 and inst2.difficulty == "critical")
assert(commands["raid.skip"](0, { "3" }))
seconds(LightRpRaid.launchSeconds + 1)
seconds(2)
assert(bosses.boss2, "fallback boss placed after a failed probe")
seconds(LightRpRaid.introSeconds + 1)
assert(last(3).phase == "fight" and last(3).lives == 0)
local n = #respawned
life[3] = "dead"; LightRP.eachModule("onLifeState", 3, "dead")
assert(last(3).out or any(3, "announce").title == "OPERATOR LOST")
seconds(2)
assert(last(3).phase == "wipe", "wiped")
seconds(8)
assert(not Missions.instanceOf(3) and not paid[3] and bosses.boss2 == nil, "failed, nothing paid, boss gone")
assert(#respawned == n + 1 and respawned[#respawned].bucket == 0, "the dead operator comes back alive at the point")
seconds(1)
assert(healedPlayers[3], "and healed")
assert(healedPlayers[1] and healedPlayers[2], "the victors are healed on the way home")
print("PASS: Chimera raid: ready check (free respawn before the fight), launch, placement probe + fallback, passive intro, scaling by operators, waves, phase/announcements, respawn pool, target lock, enrage, victory payout + cleanup, critical no-respawn wipe")
