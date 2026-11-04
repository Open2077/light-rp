-- Titan Assault (mission point "titan_assault"): two to four pilots in BT-7274 Titans (the op77_lightrp_titans
-- resource) against ten waves on a Badlands road, run inside the mission's own routing bucket. The mission module
-- (missions.lua) gathers the crew and moves it in; this script runs the assault:
--
--   arrive     the teleports are still in flight when onStart runs: each client reports that its body stands in the
--              arena (op77_lightrp:titan:arrived, position and bucket checked) and its Titan is spawned piloted and
--              held, the fists only. A pilot whose Titan never comes is told and sent home.
--   pick       everyone held, no hostile: the page's class picker. 60 s, then the un-picked get the default class.
--   starting   each Titan gets its class (the weapon, the perks, the ability lock, the speed) and its hold released.
--   countdown  "WAVE 1" in 5 s
--   wave       ten waves of hostiles from the Chimera pool, dropped in on a ring around the pilots on ground a
--              pilot's client probed; each wave starts 8 s after the previous one is dead
--   victory    wave ten is dead: a few seconds, then payout
--   wipe       every pilot down at once: failure
--
-- Hits and kills are the server's: the hostiles are created with hitPricing "resource", each pilot's own Titan reports the
-- blows its weapons land on them (op77_lightrp_titans: onTitanNpcHit, authenticated against the pilot's live Titan), and this
-- script admits one only for this run's live hostile within range of that Titan, prices it by ITS record of the pilot's class
-- weapon and the kind of blow, and applies it as the pilot (LightRpTitanAssault.hits). Core charge comes from onNpcDied: the
-- pilot the server applied the lethal damage as, or, for a death the platform reports as "native" (a missile's area attack
-- the simulating client resolved), the pilot whose validated blow landed on that hostile in the last few seconds.
-- The point is on the board only while the Titan resource runs (reconcile): prod has no Titan service yet.
local C = LightRpTitanAssault
local Missions = LightRP.missions
local POINT = C.point
local NET = "op77_lightrp:titan"
local NET_PROBE, NET_GROUND = "op77_lightrp:titan:probe", "op77_lightrp:titan:ground"
local NET_MARKS = "op77_lightrp:titan:marks"

local runs = {}       -- instance id -> run
local enemyOwner = {} -- tostring(npc id) -> run (the hostiles of every running assault)

local function now() return LightRP.nowMs() end
local function name(id) return Missions.name(id) end
local function log(fmt, ...) LightRP.log("titan " .. fmt, ...) end
local function round1(v) return math.floor(v * 10 + 0.5) / 10 end

local classes = {}
for _, c in ipairs(C.classes) do classes[c.id] = c end
assert(classes[C.defaultClass], "LightRpTitanAssault.defaultClass is not a class")

-- Every difficulty of the point multiplies the hostiles (each wave and the cap on those alive at once) by its `enemyScale`, the
-- damage the Titans take by its `incoming` (the class's `harm`, which the Titan service bounds to 0.1 .. 50) and the time their
-- shield takes to come back by its `shieldRegen` (the class's `regen`, 0.25 .. 10).
for _, point in ipairs(LightRpMissions.points) do
    if point.id == C.point then
        for _, d in ipairs(point.difficulties) do
            local scale, harm, regen = C.enemyScale[d.id], C.incoming[d.id], C.shieldRegen[d.id]
            assert(type(scale) == "number" and scale >= 1, "LightRpTitanAssault.enemyScale has no scale for " .. d.id)
            assert(type(harm) == "number" and harm >= 0.1 and harm <= 50, "LightRpTitanAssault.incoming has no multiple for " .. d.id)
            assert(type(regen) == "number" and regen >= 0.25 and regen <= 10, "LightRpTitanAssault.shieldRegen has no multiple for " .. d.id)
        end
    end
end

-- A hit record's `times` is its price multiple.
for record, spec in pairs(C.hits.records) do
    assert(spec.times == nil or (type(spec.times) == "number" and spec.times >= 1 and spec.times <= 10),
        "LightRpTitanAssault.hits.records[" .. record .. "].times is not a number from 1 to 10")
end

-- The abilities the engine can lock, in the order the picker lists them.
local ABILITIES = { "missiles", "vortex", "smoke", "dash", "jets", "sentry", "flight", "designator", "core" }

-- What setClass takes: the class without the picker's fields, every ability named, and the run's damage and shield multiples.
local function specOf(c, run)
    local abilities, perks = {}, {}
    for _, key in ipairs(ABILITIES) do abilities[key] = c.abilities[key] == true end
    for key, level in pairs(c.perks or {}) do perks[key] = level end
    return { id = c.id, label = c.label, weapon = c.weapon, perks = perks, abilities = abilities, speed = c.speed, harm = run.harm,
        regen = run.regen }
end

-- The class of a Titan before its pilot picked one: the fists, nothing else.
local STANDBY = { id = "standby", label = "BT-7274", weapon = "fist", perks = {}, abilities = {}, speed = 1.0 }
for _, key in ipairs(ABILITIES) do STANDBY.abilities[key] = false end

local CLASS_VIEW = {}
for _, c in ipairs(C.classes) do
    local allowed = {}
    for _, key in ipairs(ABILITIES) do if c.abilities[key] then allowed[#allowed + 1] = key end end
    CLASS_VIEW[#CLASS_VIEW + 1] = { id = c.id, label = c.label, weapon = c.weaponLabel or c.weapon, core = c.core, labels = c.labels,
        ultimate = c.ultimate, abilities = allowed, speed = c.speed }
end

-- ---------------------------------------------------------------------------
-- The Titan service (exports.op77_lightrp_titans): every answer is a value, or nil / false and a reason.

local function titan(method, ...)
    local args = table.pack(...)
    local ok, a, b = pcall(function()
        local service = exports[C.resource]
        return service[method](service, table.unpack(args, 1, args.n))
    end)
    if not ok then return nil, tostring(a) end
    return a, b
end

local function running()
    if type(GetResourceState) ~= "function" then return false end
    local ok, state = pcall(GetResourceState, C.resource)
    return ok and (state == "running" or state == "starting")
end

-- ---------------------------------------------------------------------------
-- Small reads

local function members(inst)
    local list = {}
    for i, id in ipairs(inst.members) do list[i] = id end
    return list
end

local function alive(id)
    local life = Open77.players.getLifeState(id)
    return life == nil or life.phase == "alive" or life.phase == "recovering"
end

local function flat(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end
local function space(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end

local function npcOf(id)
    local ok, npc = pcall(Open77.npcs.get, id)
    if ok and type(npc) == "table" then return npc end
end
local function npcPosition(npc)
    if type(npc.position) == "table" then return npc.position end
    if npc.x ~= nil then return npc end
end
local function npcAlive(npc) return npc ~= nil and (tonumber(npc.health) or 0) > 0 end

-- Titans exist from the class on: the three phases around the waves.
local function inWaves(run) return run.phase == "countdown" or run.phase == "wave" or run.phase == "intermission" end

-- ---------------------------------------------------------------------------
-- What the clients see (client/core/titan_mission.lua, ui/src/features/missions/TitanMissionHud.tsx)

local function view(inst, run, id)
    local t = now()
    local d = Missions.difficulty(inst)
    local operators = {}
    for _, m in ipairs(inst.members) do
        local cls = classes[run.class[m] or run.choice[m] or ""]
        operators[#operators + 1] = { id = m, name = name(m), class = cls and cls.label or nil, ready = run.ready[m] == true,
            down = run.down[m] == true, titan = run.titans[m] ~= nil, kills = run.kills[m] or 0 }
    end
    local mine = classes[run.class[id] or run.choice[id] or ""]
    local ids = {}
    for key in pairs(run.enemies) do ids[#ids + 1] = key end
    table.sort(ids)
    return {
        instance = inst.id, phase = run.phase, title = Missions.point(POINT).title, difficulty = d.label,
        operators = operators, arrived = run.arrived[id] == true,
        arena = not run.arrived[id] and Missions.point(POINT).arena or nil,
        classes = run.phase == "pick" and CLASS_VIEW or nil, class = mine and mine.id or nil, ready = run.ready[id] == true,
        pickEndsInMs = run.phase == "pick" and math.max(0, run.pickEnds - t) or nil,
        startsInMs = run.phase == "countdown" and math.max(0, run.startsAt - t) or nil,
        nextWaveInMs = run.phase == "intermission" and math.max(0, run.nextWaveAt - t) or nil,
        wave = run.wave, waves = C.waves.count, enemies = run.count + run.pending, waveSize = run.waveTotal,
        kills = run.kills[id] or 0, killsTotal = run.killTotal, down = run.down[id] == true,
        respawnInMs = run.down[id] and run.respawnAt[id] and math.max(0, run.respawnAt[id] - t) or nil,
        enemyIds = ids,
    }
end

local function push(inst, run, extra)
    for _, id in ipairs(inst.members) do
        local payload = view(inst, run, id)
        if extra then for k, v in pairs(extra) do payload[k] = v end end
        TriggerClientEvent(NET, id, payload)
    end
end

local function announce(inst, run, title, body, tone)
    push(inst, run, { announce = { title = title, body = body, tone = tone or "info", at = now() } })
end

-- ---------------------------------------------------------------------------
-- The hostiles

local function forget(run, key)
    if run.enemies[key] then run.enemies[key] = nil; run.count = run.count - 1 end
    run.lastHit[key] = nil
    if enemyOwner[key] == run then enemyOwner[key] = nil end
end

local function clearEnemies(run)
    for key, e in pairs(run.enemies) do
        pcall(Open77.npcs.remove, e.id)
        if enemyOwner[key] == run then enemyOwner[key] = nil end
    end
    run.enemies, run.lastHit, run.count, run.pending = {}, {}, 0, 0
end

-- Their own copy of the Chimera's reinforcement settings (mission_chimera.lua spawnAdd) with what differs here:
-- the combat group, hitPricing "resource" (the server prices the hits, below), vehicleContactEnabled and the placement. A
-- shared helper would carry both sets of differences for a dozen lines of table and touch a module whose test passes as it is.
-- vehicleContactEnabled keeps a hostile's ragdoll component under the platform's damage barrier (Open77's
-- NpcLedgerLife::KeepsContactRagdoll: the vehicle-contact opt-in or a carry, nothing else): without it the Titan's own
-- ragdoll and push, BERSERKER CORE's launch, do nothing. A car can knock one down too.
local function createEnemy(inst, run, point, centre)
    local yaw = math.deg(math.atan(centre.y - point.y, centre.x - point.x)) - 90
    local order = {}
    for i = 1, #C.pool do order[i] = i end
    for i = #order, 2, -1 do local j = math.random(i); order[i], order[j] = order[j], order[i] end
    for _, i in ipairs(order) do
        local candidate = C.pool[i]
        local definition = {
            position = { x = point.x, y = point.y, z = point.z + C.spawnLift }, yaw = yaw, bucket = inst.bucket,
            aiMode = Open77.npcs.ai.native, damagePolicy = Open77.npcs.damage.mortal,
            streamingRadius = 200, persistent = false, despawnWhenUnobserved = false,
            loadout = { combat = { group = C.group, acquirePlayers = true, authoritativePlayerHits = true } },
            behavior = { hitPricing = "resource", aiEnabled = true, combatEnabled = true, vehicleContactEnabled = true },
        }
        if candidate.record then definition.record = candidate.record else definition.template = candidate.template end
        local ok, id = pcall(Open77.npcs.create, definition)
        if ok and id then
            local key = tostring(id)
            run.enemies[key] = { id = id, rank = C.ranks[candidate.record or candidate.template] or "grunt",
                record = candidate.record or candidate.template, at = now() }
            run.count = run.count + 1
            enemyOwner[key] = run
            -- straight at the nearest standing pilot: they arrive shooting
            local target, best
            for _, m in ipairs(inst.members) do
                local p = not run.down[m] and Open77.players.position(m)
                if p then local dist = flat(p, point); if not best or dist < best then target, best = m, dist end end
            end
            if target and type(Open77.npcs.tasks) == "table" and type(Open77.npcs.tasks.attack) == "function" then
                pcall(Open77.npcs.tasks.attack, id, { playerId = target }, { reacquireMs = 4000 })
            end
            return id
        end
        if not run.badPool[i] then
            run.badPool[i] = true -- said once; a refusal may be passing, the record is tried again next time
            log("%s: hostile %s refused (%s)", inst.id, tostring(candidate.record or candidate.template), tostring(id))
        end
    end
end

-- Spawn up to what is still to come and what the cap leaves room for, on these ground points.
local function spawnOn(inst, run, points, centre)
    local room = C.maxAlive * run.scale - run.count
    local made = 0
    for _, point in ipairs(points) do
        if run.pending <= 0 or room <= 0 then break end
        if createEnemy(inst, run, point, centre) then
            run.pending, room, made = run.pending - 1, room - 1, made + 1
        end
    end
    if made > 0 then run.noHostile = 0; push(inst, run) end -- the clients' relay filter learns the new ids at once
    -- a wave that cannot be created at all (every record refused, NPC capacity) is called off, not waited on
    if made == 0 and #points > 0 then
        run.noHostile = run.noHostile + 1
        if run.noHostile >= C.spawnFailures then Missions.fail(inst.id, "The hostiles could not be deployed.") end
    end
    return made
end

-- Where the standing pilots are (their bodies ride in their Titans), in the run's bucket.
local function standing(inst, run)
    local list = {}
    for _, id in ipairs(inst.members) do
        if not run.down[id] then
            local p = Open77.players.position(id)
            if p and p.bucket == inst.bucket then list[#list + 1] = p end
        end
    end
    return list
end

local function standingCentre(inst, run)
    local list = standing(inst, run)
    if #list == 0 then return nil end
    local x, y, z = 0, 0, 0
    for _, p in ipairs(list) do x, y, z = x + p.x, y + p.y, z + p.z end
    return { x = x / #list, y = y / #list, z = z / #list }
end

-- What a hostile keeps clear of: every standing pilot's body and every Titan of the run, at its last accepted pose (a Titan
-- carries its pilot, but one left standing while its pilot walks is a Titan all the same).
local function keepClear(inst, run)
    local list = standing(inst, run)
    for _, id in ipairs(inst.members) do
        if run.titans[id] then
            local state = titan("getState", id)
            local p = type(state) == "table" and state.position
            if type(p) == "table" and tonumber(p.x) and tonumber(p.y) then list[#list + 1] = p end
        end
    end
    return list
end

-- Whether a point keeps `ring.clear` metres (on the ground plane) from every one of these pilots and Titans.
local function clearOf(point, pilots)
    local clear = C.ring.clear * C.ring.clear
    for _, p in ipairs(pilots) do
        local dx, dy = point.x - p.x, point.y - p.y
        if dx * dx + dy * dy < clear then return false end
    end
    return true
end

-- A point of the ring around `centre`, clear of every pilot; a few draws, then nil (pilots spread so wide that the ring
-- runs through them).
local function ringPoint(centre, z, pilots)
    for _ = 1, 8 do
        local angle = math.random() * math.pi * 2
        local r = C.ring.min + math.random() * (C.ring.max - C.ring.min)
        local point = { x = round1(centre.x + math.cos(angle) * r), y = round1(centre.y + math.sin(angle) * r), z = round1(z) }
        if clearOf(point, pilots) then return point end
    end
end

-- Up to `count` ring points clear of the standing pilots and the Titans.
local function ringPoints(inst, run, centre, count)
    local pilots, points = keepClear(inst, run), {}
    for _ = 1, count do points[#points + 1] = ringPoint(centre, centre.z, pilots) end
    return points
end

-- The ground under the ring points is a pilot's client to find (the Titan resource's trace): one request in flight,
-- answered through op77_lightrp:titan:ground. Without an answer (a few times in a row) the wave drops on the
-- pilots' own height, the way the Chimera's reinforcements do.
local function probeMore(inst, run, want)
    local centre = standingCentre(inst, run)
    if not centre then return end
    local probers = {}
    for _, id in ipairs(inst.members) do if not run.down[id] then probers[#probers + 1] = id end end
    if #probers == 0 then return end
    local P = C.probe
    if run.probeFailures >= P.failuresBeforeFallback then
        run.probeFailures = P.failuresBeforeFallback - 1 -- one more empty answer and the next batch falls back too
        local points = ringPoints(inst, run, centre, want)
        log("%s: no ground answer from the pilots' clients, %d hostile(s) dropped at the pilots' height", inst.id, want)
        spawnOn(inst, run, points, centre)
        return
    end
    run.proberIndex = (run.proberIndex or 0) % #probers + 1
    local member = probers[run.proberIndex]
    local points = ringPoints(inst, run, centre, math.min(P.max, want * P.perHostile))
    if #points == 0 then return end
    run.probeSeq = run.probeSeq + 1
    run.probe = { id = run.probeSeq, member = member, points = points, centre = centre, at = now() }
    TriggerClientEvent(NET_PROBE, member, { id = run.probe.id, points = points })
end

-- The ground under the living hostiles, asked of one pilot's client (the spawn probe's own request, a request of its own) every
-- `sink.everyMs` of a wave, `sink.max` of them at a time, round all of them; a hostile found more than `sink.depth` under it, or
-- hanging more than `sink.above` over it where the previous check of it found it, is put on it when the answer comes.
local function sinkTick(inst, run)
    local t = now()
    if run.check then
        if t - run.check.at < C.probe.timeoutMs then return end
        run.check = nil
    end
    if t < (run.checkAt or 0) then return end
    run.checkAt = t + C.sink.everyMs
    local probers = {}
    for _, id in ipairs(inst.members) do if not run.down[id] then probers[#probers + 1] = id end end
    if #probers == 0 then return end
    local living = {}
    for key, e in pairs(run.enemies) do
        local npc = npcOf(e.id)
        local p = npcAlive(npc) and npcPosition(npc)
        if p and tonumber(p.x) and tonumber(p.y) and tonumber(p.z) then living[#living + 1] = { key = key, p = p } end
    end
    if #living == 0 then return end
    table.sort(living, function(a, b) return tostring(a.key) < tostring(b.key) end)
    local from = (run.checkFrom or 0) % #living
    local keys, points = {}, {}
    for n = 1, math.min(#living, C.sink.max) do
        local L = living[(from + n - 1) % #living + 1]
        keys[n], points[n] = L.key, { x = round1(L.p.x), y = round1(L.p.y), z = round1(L.p.z) }
    end
    run.checkFrom = from + #points
    run.proberIndex = (run.proberIndex or 0) % #probers + 1
    local member = probers[run.proberIndex]
    run.probeSeq = run.probeSeq + 1
    run.check = { id = run.probeSeq, member = member, keys = keys, at = t }
    TriggerClientEvent(NET_PROBE, member, { id = run.check.id, points = points, kind = "check", reach = C.sink.reach })
end

-- The answer to sinkTick: each hostile still alive and more than `sink.depth` under its ground, or more than `sink.above` over
-- it where its previous check found it, is put on it.
local function sinkAnswer(inst, run, check, indices, heights)
    if type(indices) ~= "table" or type(heights) ~= "table" then return end
    for k = 1, math.min(#indices, #heights) do
        local i, z = math.floor(tonumber(indices[k]) or 0), tonumber(heights[k])
        local key = check.keys[i]
        local e = key and run.enemies[key]
        local npc = e and npcOf(e.id)
        local p = npcAlive(npc) and npcPosition(npc)
        if p and z and z == z and math.abs(z - p.z) <= C.sink.reach then
            run.measured = (run.measured or 0) + 1
            run.deepest, run.highest = math.max(run.deepest or -math.huge, z - p.z), math.max(run.highest or -math.huge, p.z - z)
            local seen = e.checked
            e.checked = { x = p.x, y = p.y, z = p.z }
            local sunk = p.z < z - C.sink.depth
            local hung = p.z > z + C.sink.above and seen ~= nil
                and math.sqrt((p.x - seen.x) ^ 2 + (p.y - seen.y) ^ 2 + (p.z - seen.z) ^ 2) <= C.sink.still
            if sunk or hung then
                local ok, why = pcall(Open77.npcs.setTransform, e.id, { position = { x = p.x, y = p.y, z = z + C.spawnLift } })
                local done = ok and why ~= false
                e.checked = nil
                if sunk then run.lifted = (run.lifted or 0) + 1 else run.lowered = (run.lowered or 0) + 1 end
                log("%s: hostile %s (%s) was %.1f m %s the ground at (%.0f, %.0f), %.0f s after it came: %s", inst.id, key,
                    tostring(e.record), math.abs(z - p.z), sunk and "under" or "over, still,", p.x, p.y, (now() - (e.at or now())) / 1000,
                    done and (sunk and "put back on it" or "put down on it") or ("not moved: " .. tostring(why)))
            end
        end
    end
end

local function spawnTick(inst, run)
    if run.probe then
        if now() - run.probe.at < C.probe.timeoutMs then return end
        log("%s: %s did not answer the ground probe", inst.id, name(run.probe.member))
        run.probe, run.probeFailures = nil, run.probeFailures + 1
    end
    local want = math.min(run.pending, C.maxAlive * run.scale - run.count)
    if want > 0 then probeMore(inst, run, want) end
end

RegisterNetEvent(NET_GROUND, function(requestId, indices, heights)
    local id = tonumber(source)
    local inst = id and Missions.instanceOf(id)
    local run = inst and runs[inst.id]
    local check = run and run.check
    if check and check.member == id and tonumber(requestId) == check.id then
        run.check = nil
        sinkAnswer(inst, run, check, indices, heights)
        return
    end
    local probe = run and run.probe
    if not probe or probe.member ~= id or tonumber(requestId) ~= probe.id then return end
    run.probe = nil
    local good, seen = {}, {}
    if type(indices) == "table" and type(heights) == "table" then
        for k = 1, math.min(#indices, #heights, #probe.points) do
            local i, z = math.floor(tonumber(indices[k]) or 0), tonumber(heights[k])
            local p = probe.points[i]
            -- the client's word for the ground, but within reach of where the pilots stand
            if p and z and z == z and not seen[i] and math.abs(z - p.z) <= C.probe.heightTolerance then
                seen[i] = true
                good[#good + 1] = { x = p.x, y = p.y, z = z }
            end
        end
    end
    if #good == 0 then
        run.probeFailures = run.probeFailures + 1
        log("%s: the ground probe of %s found no level ground", inst.id, name(id))
        return
    end
    run.probeFailures = 0
    -- the pilots and Titans moved while the client looked: a point they came near is dropped (the next probe draws new ones)
    local pilots, clear = keepClear(inst, run), {}
    for _, p in ipairs(good) do if clearOf(p, pilots) then clear[#clear + 1] = p end end
    spawnOn(inst, run, clear, probe.centre)
end)

-- ---------------------------------------------------------------------------
-- The pilots and their Titans

local function dropPilot(inst, run, id, why)
    LightRP.notice(id, { kind = "error", title = "TITAN ASSAULT", body = why })
    log("%s: %s dropped (%s)", inst.id, name(id), why)
    -- the last pilot out ends the run: nobody to fly
    if #inst.members <= 1 then Missions.fail(inst.id, "No Titan could be deployed.") else Missions.dismiss(id, "no_titan") end
end

-- One step on the way from "this body stands in the arena" to "a Titan wearing its class, free to move": spawn it
-- (held before the waves), set the class once it is chosen, release the hold. A refused call is tried again every
-- `retryMs`; too many refusals in a row and the pilot is sent home.
local function settle(inst, run, id)
    if run.down[id] or not run.arrived[id] or not alive(id) then return end
    local t = now()
    if (run.retryAt[id] or 0) > t then return end
    local function refused(kind, why)
        run.tries[id] = (run.tries[id] or 0) + 1
        run.retryAt[id] = t + C.retryMs
        log("%s: %s for %s refused (%s), try %d", inst.id, kind, name(id), tostring(why), run.tries[id])
        if run.tries[id] >= (kind == "spawn" and C.spawnRetries or C.applyRetries) then
            dropPilot(inst, run, id, "Your Titan could not be deployed.")
        end
    end
    if not run.titans[id] then
        local held = run.phase == "arrive" or run.phase == "pick"
        local titanId, why = titan("spawn", id, C.fistsOnly, held and { piloted = true, hold = true } or { piloted = true })
        if not titanId then return refused("spawn", why) end
        run.titans[id], run.held[id], run.applied[id], run.standby[id], run.tries[id] = tostring(titanId), held or nil, nil, nil, nil
    end
    local choice = run.class[id]
    -- Before its class a Titan holds the fists with every ability locked (the Titan's own default weapon is the XO-16,
    -- whatever the loadout says): the stand-by class, set once.
    if not choice and run.held[id] and not run.standby[id] then
        local ok, why = titan("setClass", id, STANDBY)
        if ok ~= true then return refused("standby", why) end
        run.standby[id], run.tries[id] = true, nil
    end
    if choice and not run.applied[id] then
        local ok, why = titan("setClass", id, specOf(classes[choice], run))
        if ok ~= true then return refused("class", why) end
        run.applied[id], run.tries[id] = true, nil
    end
    if run.held[id] and run.applied[id] then
        local ok, why = titan("setHold", id, false)
        if ok ~= true then return refused("release", why) end
        run.held[id], run.tries[id] = nil, nil
    end
end

local function settleAll(inst, run)
    for _, id in ipairs(members(inst)) do
        if runs[inst.id] ~= run then return end -- the run ended under us (the last pilot was dropped)
        if Missions.instanceOf(id) == inst then settle(inst, run, id) end
    end
end

local function checkWipe(inst, run)
    if not inWaves(run) then return end
    local pilots, standing = 0, 0
    for _, id in ipairs(inst.members) do
        pilots = pilots + 1
        if not run.down[id] then standing = standing + 1 end
    end
    if pilots > 0 and standing == 0 then
        run.phase, run.endsAt = "wipe", now() + C.wipeSeconds * 1000
        clearEnemies(run)
        announce(inst, run, "CREW WIPED", "Every Titan is down. The road is theirs.", "danger")
    end
end

-- A pilot is down once their body died or their Titan was lost; they come back after a delay in a new Titan with
-- the same class (before the waves: sooner, and it costs nothing). Everyone down at once is a wipe.
local function markDown(inst, run, id, why)
    if run.down[id] then return end
    local waves = inWaves(run)
    run.down[id] = true
    run.respawnAt[id] = now() + (waves and C.respawnSeconds or C.respawnEarlySeconds) * 1000
    if waves then
        run.downs = run.downs + 1
        announce(inst, run, "PILOT DOWN", string.format("%s is down. A new Titan in %d s.", name(id), C.respawnSeconds), "warning")
    end
    log("%s: %s down (%s)", inst.id, name(id), tostring(why))
    Missions.pushSquad(inst)
    checkWipe(inst, run)
end

-- Where a pilot comes back: the start spot farthest from the other standing pilots.
local function respawnSpot(inst, run, id)
    local best, farthest
    for _, spot in ipairs(Missions.point(POINT).start) do
        local nearest = math.huge
        for _, m in ipairs(inst.members) do
            local p = m ~= id and not run.down[m] and Open77.players.position(m)
            if p then nearest = math.min(nearest, flat(p, spot)) end
        end
        if not farthest or nearest > farthest then best, farthest = spot, nearest end
    end
    return best
end

local function respawnTick(inst, run)
    local t = now()
    for _, id in ipairs(members(inst)) do
        if run.down[id] and t >= (run.respawnAt[id] or 0) then
            if alive(id) then
                -- on its feet again (respawned, or never dead: only the Titan was lost): a clean slate, then a new Titan
                run.removing[id] = true
                titan("remove", id)
                run.removing[id] = nil
                run.titans[id], run.applied[id], run.held[id], run.standby[id], run.tries[id] = nil, nil, nil, nil, nil
                run.down[id], run.respawnAt[id], run.respawning[id] = nil, nil, nil
                settle(inst, run, id)
            elseif not run.respawning[id] or t - run.respawning[id] > 5000 then
                run.respawning[id] = t
                local spot = respawnSpot(inst, run, id)
                local ok, why = Open77.players.respawn(id, { position = { x = spot.x, y = spot.y, z = spot.z }, heading = spot.heading or 0,
                    bucket = inst.bucket, health = LightRpConfig.spawn and LightRpConfig.spawn.health or nil })
                if not ok then log("%s: respawn of %s refused (%s)", inst.id, name(id), tostring(why)) end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- The phases

local function waveSize(n, pilots)
    local W = C.waves
    return W.base + W.perWave * (n - 1) + math.max(0, pilots - 2) * (W.perExtraPilot + math.floor(n / W.extraEvery))
end

local function beginWave(inst, run, n)
    local size = waveSize(n, #inst.members) * run.scale
    run.phase, run.wave, run.pending, run.waveTotal = "wave", n, size, size
    run.probeFailures = 0
    announce(inst, run, "WAVE " .. n, string.format("%d hostiles on the road.", size), "danger")
    log("%s: wave %d, %d hostiles for %d pilot(s)", inst.id, n, size, #inst.members)
end

local function waveCleared(inst, run)
    run.cleared = run.wave
    if (run.measured or 0) > 0 then
        log("%s: wave %d, the ground under %d hostile(s) measured, the deepest %.2f m under it, the highest %.2f m over it, %d put back up, %d put down",
            inst.id, run.wave, run.measured, run.deepest, run.highest, run.lifted or 0, run.lowered or 0)
    end
    run.measured, run.deepest, run.highest, run.lifted, run.lowered = 0, nil, nil, 0, 0
    if run.wave >= C.waves.count then
        run.phase, run.endsAt = "victory", now() + C.victorySeconds * 1000
        announce(inst, run, "ASSAULT REPELLED", "Ten waves down. The road is yours.", "success")
        return
    end
    run.phase, run.nextWaveAt = "intermission", now() + C.intermissionSeconds * 1000
    announce(inst, run, "WAVE " .. (run.wave + 1), string.format("Hostiles inbound in %d s.", C.intermissionSeconds), "warning")
end

local function waveTick(inst, run)
    local t = now()
    -- one that vanished (removed, or dead by a hand that is not a pilot's) leaves the count; a dead one gets a
    -- moment first, its onNpcDied may still be on its way to credit the kill
    for key, e in pairs(run.enemies) do
        local npc = npcOf(e.id)
        if not npc then forget(run, key)
        elseif not npcAlive(npc) then
            e.deadAt = e.deadAt or t
            if t - e.deadAt >= 2000 then forget(run, key) end
        end
    end
    spawnTick(inst, run)
    sinkTick(inst, run)
    if run.pending == 0 and next(run.enemies) == nil then waveCleared(inst, run) end
end

local function beginCountdown(inst, run)
    run.phase, run.startsAt = "countdown", now() + C.countdownSeconds * 1000
    run.operators = #inst.members
    announce(inst, run, "WAVE 1", string.format("Hostiles inbound in %d s.", C.countdownSeconds), "warning")
end

local function allSettled(inst, run)
    local standing = 0
    for _, id in ipairs(inst.members) do
        if not run.down[id] then
            if not (run.titans[id] and run.applied[id] and not run.held[id]) then return false end
            standing = standing + 1
        end
    end
    return standing > 0
end

-- Everyone is ready (or the 60 s are up): every Titan gets its class and is released, then the countdown.
local function beginStart(inst, run)
    run.phase = "starting"
    for _, id in ipairs(inst.members) do run.class[id] = run.choice[id] or C.defaultClass end
    settleAll(inst, run)
    if runs[inst.id] == run and allSettled(inst, run) then beginCountdown(inst, run) else push(inst, run) end
end

local function beginPick(inst, run)
    run.phase, run.pickEnds = "pick", now() + C.pickSeconds * 1000
    announce(inst, run, "CHOOSE YOUR CLASS", "Your Titan is held until the whole crew is ready.", "info")
end

local function allReady(inst, run)
    for _, id in ipairs(inst.members) do if not run.ready[id] then return false end end
    return #inst.members > 0
end

local function arriveTick(inst, run)
    local all = #inst.members > 0
    for _, id in ipairs(inst.members) do if not run.titans[id] then all = false end end
    if all then return beginPick(inst, run) end
    if now() < run.arriveDeadline then return end
    -- the road is waiting: whoever has no Titan yet is sent home, the others go on
    for _, id in ipairs(members(inst)) do
        if runs[inst.id] ~= run then return end
        if not run.titans[id] then dropPilot(inst, run, id, "Your Titan did not arrive in time.") end
    end
    if runs[inst.id] == run and #inst.members > 0 then beginPick(inst, run) end
end

local function tick(inst, run)
    local t = now()
    local phase = run.phase
    if phase == "wipe" then
        if t >= run.endsAt then Missions.fail(inst.id, "Every pilot went down.") end
        return
    elseif phase == "victory" then
        if t >= run.endsAt then Missions.complete(inst.id) end
        return
    end
    respawnTick(inst, run)
    if runs[inst.id] ~= run then return end
    settleAll(inst, run)
    if runs[inst.id] ~= run then return end
    phase = run.phase
    if phase == "arrive" then arriveTick(inst, run)
    elseif phase == "pick" then
        if allReady(inst, run) or t >= run.pickEnds then beginStart(inst, run) end
    elseif phase == "starting" then
        if allSettled(inst, run) then beginCountdown(inst, run) end
    elseif phase == "countdown" then
        if t >= run.startsAt then beginWave(inst, run, 1) end
    elseif phase == "intermission" then
        if t >= run.nextWaveAt then beginWave(inst, run, run.wave + 1) end
    elseif phase == "wave" then
        waveTick(inst, run)
    end
    if runs[inst.id] == run then push(inst, run) end
end

-- ---------------------------------------------------------------------------
-- The mission script

Missions.register(POINT, {
    onStart = function(inst)
        local difficulty = Missions.difficulty(inst).id
        local scale = C.enemyScale[difficulty]
        local run = { phase = "arrive", arriveDeadline = now() + C.arriveSeconds * 1000, scale = scale, harm = C.incoming[difficulty],
            regen = C.shieldRegen[difficulty],
            arrived = {}, titans = {}, held = {}, applied = {}, standby = {}, tries = {}, retryAt = {}, removing = {},
            choice = {}, ready = {}, class = {}, down = {}, respawnAt = {}, respawning = {},
            kills = {}, killTotal = 0, downs = 0, wave = 0, cleared = 0, waveTotal = 0, pending = 0, count = 0,
            enemies = {}, lastHit = {}, pendingNative = {}, badPool = {}, noHostile = 0, budget = {}, probeSeq = 0, probeFailures = 0 }
        runs[inst.id] = run
        -- the pilots fight with the Titans' weapons: the armament stands aside (armament.lua standAside) and the
        -- characters' own weapons come back after the run
        inst.loadout = true
        if LightRP.armament and type(LightRP.armament.push) == "function" then
            for _, id in ipairs(inst.members) do pcall(LightRP.armament.push, id) end
        end
        log("%s: %d pilot(s) on their way", inst.id, #inst.members)
        push(inst, run)
    end,
    onTick = function(inst)
        local run = runs[inst.id]
        if run then tick(inst, run) end
    end,
    onLifeState = function(inst, id, phase)
        local run = runs[inst.id]
        if not run or phase == "alive" or phase == "recovering" then return end
        markDown(inst, run, id, "dead")
    end,
    onLeave = function(inst, id)
        local run = runs[inst.id]
        if not run then return end
        if run.titans[id] then
            run.removing[id] = true
            titan("remove", id)
        end
        for _, map in ipairs({ run.arrived, run.titans, run.held, run.applied, run.standby, run.tries, run.retryAt, run.removing, run.choice, run.ready,
            run.class, run.down, run.respawnAt, run.respawning, run.budget }) do map[id] = nil end
        if run.probe and run.probe.member == id then run.probe = nil end
        if run.check and run.check.member == id then run.check = nil end
        TriggerClientEvent(NET, id, { instance = inst.id, phase = "ended" })
        checkWipe(inst, run)
    end,
    onEnd = function(inst, success)
        local run = runs[inst.id]
        runs[inst.id] = nil
        if not run then return end
        -- contracts, titles and the recap read this
        local by = {}
        for id, n in pairs(run.kills) do by[id] = n end
        inst.report = { waves = run.cleared, kills = run.killTotal, downs = run.downs, operators = run.operators or #inst.members, killsBy = by }
        for _, id in ipairs(inst.members) do
            if run.titans[id] then
                titan("setHold", id, false)
                run.removing[id] = true
                titan("remove", id)
            end
            TriggerClientEvent(NET, id, { instance = inst.id, phase = "ended", result = success and "victory" or "failed" })
        end
        clearEnemies(run)
    end,
})

-- ---------------------------------------------------------------------------
-- Titan events: the service tells every resource when a Titan exists and when it ends.

AddEventHandler("onTitanCreated", function(owner, id)
    owner = tonumber(owner)
    local inst = owner and Missions.instanceOf(owner)
    local run = inst and runs[inst.id]
    -- a Titan the script did not spawn (a staff /titan spawn): the pilot flies it, the run tracks it
    if run and not run.titans[owner] and not run.down[owner] and run.arrived[owner] then run.titans[owner] = tostring(id) end
end)

AddEventHandler("onTitanRemoved", function(owner, id, reason)
    owner = tonumber(owner)
    local inst = owner and Missions.instanceOf(owner)
    local run = inst and runs[inst.id]
    if not run or run.titans[owner] ~= tostring(id) then return end
    run.titans[owner], run.applied[owner], run.held[owner], run.standby[owner] = nil, nil, nil, nil
    if run.removing[owner] or reason == "resource_stopped" then return end
    markDown(inst, run, owner, reason)
end)

-- ---------------------------------------------------------------------------
-- From the pilots

-- The client reports once its loading screen is gone and its body stands in the arena
-- (client/core/titan_mission.lua); the server checks position and bucket itself. The Titan is spawned on the
-- first accepted report.
RegisterNetEvent("op77_lightrp:titan:arrived", function()
    local id = tonumber(source)
    local inst = id and Missions.instanceOf(id)
    local run = inst and runs[inst.id]
    if not run or run.arrived[id] then return end
    local p, a = Open77.players.position(id), Missions.point(POINT).arena
    if not p or p.bucket ~= inst.bucket or flat(p, a) > C.loadRadius then return end
    run.arrived[id] = true
    log("%s: %s is in the arena", inst.id, name(id))
    settle(inst, run, id)
    if runs[inst.id] == run and run.phase == "arrive" then arriveTick(inst, run) end
    if runs[inst.id] == run then push(inst, run) end
end)

RegisterNetEvent("op77_lightrp:titan:hello", function()
    local id = tonumber(source)
    local inst = id and Missions.instanceOf(id)
    local run = inst and runs[inst.id]
    if run then TriggerClientEvent(NET, id, view(inst, run, id)) end
end)

LightRP.action("titan.class", function(id, payload)
    local inst = Missions.instanceOf(id)
    local run = inst and runs[inst.id]
    local choice = type(payload) == "table" and classes[payload.id]
    if not run or run.phase ~= "pick" or run.ready[id] or not choice then return end
    run.choice[id] = choice.id
    push(inst, run)
end)

LightRP.action("titan.ready", function(id)
    local inst = Missions.instanceOf(id)
    local run = inst and runs[inst.id]
    if not run or run.phase ~= "pick" or run.ready[id] then return end
    if not run.choice[id] then
        LightRP.notice(id, { kind = "error", title = "TITAN ASSAULT", body = "Pick a class first." })
        return
    end
    run.ready[id] = true
    if allReady(inst, run) then beginStart(inst, run) else push(inst, run) end
end)

-- A blow of a pilot's Titan landed on an NPC (onTitanNpcHit: the Titan service authenticated the sender, its Titan and epoch
-- and its budget; the NPC and the worth of the blow are this script's to settle). `info` is the service's { record, kind, point,
-- titan, at }: the kind picks the price and `info.titan` is the Titan's own latest accepted pose. The report carries no amount: it
-- comes from the server's own record of the pilot's class weapon. Answers true and the damage dealt, or false and the reason.
local FIRES = { xo16 = true, pred = true, rail = true } -- the weapons whose rounds a "round" can be

-- The NPC id as the platform names it, a whole number as text; nil for anything else.
local function npcKey(value)
    if type(value) == "string" then return value:match("^[1-9]%d*$") end
    if type(value) == "number" and value >= 1 and value < 2 ^ 53 and value == math.floor(value) then return string.format("%d", value) end
end

local function finiteNumber(value) return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge end

-- Percent of a hostile's maximum health one blow is worth, by the pilot's class weapon and the kind of blow: a round is the
-- weapon's own (a pilot whose weapon fires none has no price for one), a fist and a blade are what they are whoever swings
-- them, a blast has a price of its own per class, and the rest (the vortex, smoke and gas, a record the controller fell back
-- on) is small. A kind this script does not know has no price.
local function priceOf(weapon, kind)
    local H = C.hits
    if kind == "round" then return FIRES[weapon] and H.perHit[weapon] or nil end
    if kind == "melee" then return H.perHit.fist end
    if kind == "blade" then return H.perHit.sword end
    if kind == "blast" then return H.blast[weapon] end
    if kind == "other" then return H.other end
end

-- One kill for `killer`: the count, the report and the core charge.
local function credit(inst, run, killer, enemy)
    run.kills[killer] = (run.kills[killer] or 0) + 1
    run.killTotal = run.killTotal + 1
    local ok, why = titan("creditKill", killer, enemy.rank)
    if ok ~= true then log("%s: core credit for %s refused (%s)", inst.id, name(killer), tostring(why)) end
end

local function admitHit(owner, titanId, npcId, info)
    owner = tonumber(owner)
    local inst = owner and Missions.instanceOf(owner)
    local run = inst and runs[inst.id]
    if not run then return false, "not_member" end
    if run.phase ~= "wave" then return false, "phase" end
    if not run.titans[owner] then return false, "no_titan" end
    if run.titans[owner] ~= tostring(titanId) then return false, "wrong_titan" end
    if run.down[owner] then return false, "down" end
    if type(info) ~= "table" then return false, "invalid" end
    -- What a blow is comes from its attack record, never from the report's own `kind`: only the Titan's records are priced,
    -- each for the class weapon or class ability that fires it (LightRpTitanAssault.hits.records).
    local spec = type(info.record) == "string" and C.hits.records[info.record]
    if not spec then return false, "no_price" end
    local key = npcKey(npcId)
    -- A missile's own explosion can kill on the simulating client before the Titan's report of that blast reaches the
    -- server: the death waits `hits.nativeGraceSeconds` (pendingNative, with the hostile's last canonical place) for the
    -- first blow of a pilot of this run that passes every check a blow on a living hostile passes.
    local pending = key and run.pendingNative[key]
    local enemy = key and (pending and pending.enemy or run.enemies[key])
    if not enemy then return false, "not_enemy" end
    local npc, at
    if pending then
        if now() - pending.at > C.hits.nativeGraceSeconds * 1000 then
            run.pendingNative[key] = nil
            return false, "not_enemy"
        end
        at = pending.at3
    else
        npc = npcOf(enemy.id)
        if not npcAlive(npc) then return false, "not_alive" end
        if tonumber(npc.bucket) ~= inst.bucket then return false, "wrong_bucket" end
        at = npcPosition(npc)
    end
    local from = type(info.titan) == "table" and info.titan or nil
    if not (from and finiteNumber(from.x) and finiteNumber(from.y) and finiteNumber(from.z)) then
        -- no pose with the report: the pilot's own fresh position, in the run's bucket
        from = Open77.players.position(owner)
        if not from or from.bucket ~= inst.bucket then from = nil end
    end
    if not from or not at then return false, "no_position" end
    local H = C.hits
    if space(from, at) > H.range then return false, "too_far" end
    local class = run.applied[owner] and classes[run.class[owner]]
    if not class then return false, "no_class" end
    if spec.weapon and spec.weapon ~= class.weapon then return false, "wrong_weapon" end
    if spec.ability and class.abilities[spec.ability] ~= true then return false, "locked" end
    local perHit = priceOf(class.weapon, spec.kind)
    if not perHit or perHit <= 0 then return false, "no_price" end
    perHit = perHit * (spec.times or 1)
    local t = now()
    local budget = run.budget[owner] or { tokens = H.perSecond, at = t }
    budget.tokens = math.min(H.perSecond, budget.tokens + (t - budget.at) / 1000 * H.perSecond)
    budget.at = t
    run.budget[owner] = budget
    local percent = math.min(perHit, budget.tokens)
    if percent <= 0 then return false, "budget" end
    budget.tokens = budget.tokens - percent
    if pending then
        run.pendingNative[key] = nil
        credit(inst, run, owner, enemy)
        return true, 0
    end
    local amount = (tonumber(npc.maxHealth) or 100) * percent / 100
    local ok, applied = pcall(Open77.npcs.applyDamage, enemy.id, amount, "player:" .. owner, "titan")
    if not ok or applied == false then return false, "refused" end
    run.lastHit[key] = { owner = owner, at = t }
    return true, amount
end

AddEventHandler("onTitanNpcHit", function(owner, titanId, npcId, info) admitHit(owner, titanId, npcId, info) end)

-- Core charge and the kill count come from one place: the platform's death event. The killer is the pilot the server itself
-- gave the lethal damage to ("player:<id>"); a death the platform calls "native" (the simulating client's own area attack, a
-- missile's blast: the platform names no attacker, deliberately) counts for the pilot whose validated Titan blow landed on that
-- same hostile within `hits.nativeCreditSeconds`, and never for the simulator; every other death credits nobody.
AddEventHandler("onNpcDied", function(npcId, by)
    local key = tostring(npcId)
    local run = enemyOwner[key]
    if not run then return end
    local enemy, last = run.enemies[key], run.lastHit[key]
    forget(run, key)
    local killer = tonumber(tostring(by):match("^player:(%d+)$"))
    if not killer and by == "native" and last and now() - last.at <= C.hits.nativeCreditSeconds * 1000 then killer = last.owner end
    if not killer and by == "native" and enemy then
        local snapshot = npcOf(enemy.id)
        run.pendingNative[key] = { enemy = enemy, at = now(), at3 = snapshot and npcPosition(snapshot) or nil }
        return
    end
    local inst = killer and Missions.instanceOf(killer)
    if not enemy or not inst or runs[inst.id] ~= run then return end
    credit(inst, run, killer, enemy)
end)

-- A hostile hit a pilot: the mission engine's victim path (mission_engine.lua onNpcPlayerHit) and the legacy relay
-- both land here and go through the same checks and caps as an authored mission's enemies (Engine.applyNpcHit).
-- A pilot aboard their Titan takes nothing here: a blow on V aboard is BT's, which the Titan's controller takes into its
-- own hull (the author's FPF.hitSeen) when the pilot's own client ran the hit; one another client's hostile ran never
-- reaches BT (docs/titan-assault.md, "Known gap"). The pilot's health only answers for V on foot.
function LightRP.titanEnemyHit(reporter, victimId, npcId, epoch, amount, platform, cause)
    local victim, damage, reportedEpoch = tonumber(victimId), tonumber(amount), tonumber(epoch)
    if not victim or not damage or damage ~= damage or damage <= 0 or not reportedEpoch then return false, "invalid" end
    local inst = Missions.instanceOf(victim)
    local run = inst and runs[inst.id]
    if not run or run.phase ~= "wave" then return false, "no_assault" end
    local enemy = run.enemies[tostring(npcId)]
    if not enemy then return false, "not_an_enemy" end
    if run.titans[victim] then
        local state = titan("getState", victim)
        if type(state) == "table" and state.mode == "pilot" then return false, "aboard" end
    end
    local engine = LightRP.missionEngine
    if not engine or type(engine.applyNpcHit) ~= "function" then return false, "engine_missing" end
    return engine.applyNpcHit(inst, reporter, victim, enemy.id, reportedEpoch, damage, platform, cause)
end
RegisterNetEvent("op77_lightrp:titan:npcHit", function(victimId, npcId, epoch, amount)
    local reporter = tonumber(source)
    if not reporter or reporter <= 0 then return end
    local engine = LightRP.missionEngine
    local apply = function() LightRP.titanEnemyHit(reporter, victimId, npcId, epoch, amount) end
    if engine and type(engine.relay) == "function" then engine.relay(reporter, apply) else apply() end
end)

-- ---------------------------------------------------------------------------
-- The point and the Titan service

local configured
for _, point in ipairs(LightRpMissions.points) do if point.id == POINT then configured = point end end
assert(configured, "LightRpMissions has no point " .. POINT)

-- On the board only while the Titan resource runs, with its Hall of Fame board (missions.assaults: the clears of the
-- ASSAULT type); a run in progress fails if the service stops under it. Safe to call again: it only follows the state.
local BOARD = "missions.assaults"
local function hallOfFame(on)
    local H = LightRP.hallOfFame
    if type(H) ~= "table" or type(H.registerBoard) ~= "function" or type(H.clearsProvider) ~= "function" then return end
    if on then
        H.registerBoard(BOARD, { tab = "missions", title = "TITAN ASSAULT", subtitle = "Ranked by the hardest clears", unit = "clears",
            provider = H.clearsProvider({ ASSAULT = true }) })
    else
        H.unregisterBoard(BOARD)
    end
end
local function reconcile()
    local on = running()
    local point = Missions.point(POINT)
    hallOfFame(on)
    if on and (not point or point.retired) then Missions.addPoint(configured)
    elseif not on then
        -- the runs first: a point withdrawn under a running instance only retires and stays listed
        for _, inst in ipairs(Missions.instances()) do
            if inst.point == POINT then Missions.fail(inst.id, "The Titan service stopped.") end
        end
        if point then Missions.removePoint(POINT) end
    end
end
AddEventHandler("onResourceStart", function(resource) if resource == C.resource then reconcile() end end)
AddEventHandler("onResourceStop", function(resource) if resource == C.resource then reconcile() end end)
reconcile()
-- the Hall of Fame loads after this script: its board waits for the first tick
CreateThread(function() Wait(0); reconcile() end)

-- The last hostiles of a wave, marked. Below `marks.below` left (alive and still to come), every pilot's client is sent where
-- each living one is (the server's own NPC position) every `marks.everyMs`; one empty list takes the marks down when the
-- count is back up, the wave is over or the run moves on.
local function marksOf(run)
    if run.phase ~= "wave" or run.count + run.pending >= C.marks.below then return nil end
    local list = {}
    for key, e in pairs(run.enemies) do
        local npc = npcOf(e.id)
        local p = npcAlive(npc) and npcPosition(npc)
        if p and tonumber(p.x) and tonumber(p.y) and tonumber(p.z) then
            list[#list + 1] = { id = key, x = p.x, y = p.y, z = p.z }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function markTick()
    for _, inst in ipairs(Missions.instances()) do
        local run = runs[inst.id]
        if run then
            local list = marksOf(run)
            local any = list ~= nil and #list > 0
            if any or run.marked then
                for _, id in ipairs(inst.members) do TriggerClientEvent(NET_MARKS, id, list or {}) end
                run.marked = any or nil
            end
        end
    end
end
CreateThread(function()
    while true do
        Wait(C.marks.everyMs)
        local ok, err = pcall(markTick)
        if not ok then log("marks failed: %s", tostring(err)) end
    end
end)

-- Staff test start: /titan.assault [playerId] launches the assault for that player (the caller by default) and
-- their crew, without the board: the crew minimum is waived and the run is a test (no pay, nothing unlocked).
LightRP.command("titan.assault", { restricted = true, usage = "/titan.assault [playerId] [difficulty]" }, function(source, args)
    if not running() then return false, C.resource .. " is not running." end
    local target = tonumber(args[1]) or tonumber(source)
    if not target or target <= 0 then return false, "usage: /titan.assault [playerId] [difficulty]" end
    local wanted = args[2] and tostring(args[2]):lower() or C.difficulty
    local d
    for _, candidate in ipairs(Missions.point(POINT) and Missions.point(POINT).difficulties or {}) do
        if candidate.id == wanted then d = candidate end
    end
    if not d then return false, "Unknown difficulty " .. wanted .. "." end
    local crew = LightRP.parties and type(LightRP.parties.members) == "function" and LightRP.parties.members(target) or { target }
    if #crew > d.max then return false, string.format("At most %d pilots (the crew has %d).", d.max, #crew) end
    local ok, why = Missions.launchNow(POINT, d.id, crew)
    if not ok then return false, why end
    return true, string.format("Titan Assault test run, %s: %d pilot(s), no pay.", d.label, #crew)
end)

LightRP.titanAssault = { waveSize = waveSize, point = configured, hit = admitHit }
