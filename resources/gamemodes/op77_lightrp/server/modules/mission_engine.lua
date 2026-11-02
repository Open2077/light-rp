-- The runtime of the missions authored in game (shared/mission_defs.lua). One
-- generic script per published definition, run by the board system
-- (server/modules/missions.lua) inside the mission's own routing bucket:
--
--   spawns      every enemy of a spawn point is created around it, a few per
--               second (MAX_ALIVE at once); the native AI fights, and each
--               enemy is sent at the nearest operator standing within reach
--   checkpoints an operator entering one wakes its spawn points (once)
--   waves       (Survival) a wave starts after its delay, the next one once it
--               is cleared; done when the last falls
--   perimeter   out of it: warning + countdown on the HUD, dead at zero
--   deaths      a team pool of respawns at the start positions; nobody standing
--               and nobody coming back = squad wiped (failure)
--
-- The state of a run lives on the instance (`inst.run`) with its own copy of
-- the definition, so a definition republished mid-run never changes a mission
-- already being played.
local D = LightRpMissionDefs
local G = LightRpSafezoneGeometry
local Missions = LightRP.missions
local Engine = LightRP.module("missionEngine", {})
local NET = "op77_lightrp:missionrun"
local COMBAT_GROUP = "lightrp_mission"
local START_DELAY_MS = 6000      -- the arena streams in before the first enemies
local BRIEFING_MS = 30000        -- the loadout pick: the fight starts once all are ready, or after this
local SPAWNS_PER_TICK = 4
local RETARGET_MS = 6000
local ENGAGE_RANGE = 90
local CORPSE_MS = 8000

local function now() return LightRP.nowMs() end
local function name(id) return Missions.name(id) end
local function distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
local function positionOf(id)
    local p = Open77.players.position(id)
    if p then return p end
    local ok, read = pcall(Open77.players.get, id)
    if ok and type(read) == "table" and type(read.position) == "table" then return read.position end
end
local function alive(id)
    local life = Open77.players.getLifeState(id)
    return not life or life.phase == "alive"
end
-- Only these phases are a fall. A teleport or a streaming hand-off passes through other
-- phases while the operator stays on their feet: they never cost a life.
local DEATH_PHASES = { dead = true, dying = true, respawnpending = true, revivepending = true }
local function fallen(id)
    local life = Open77.players.getLifeState(id)
    return life ~= nil and DEATH_PHASES[life.phase] == true
end
local function npcAlive(npcId)
    local ok, npc = pcall(Open77.npcs.get, npcId)
    return ok and type(npc) == "table" and npc.alive ~= false and (tonumber(npc.health) or 1) > 0
end
local function announce(inst, title, body, kind)
    for _, id in ipairs(inst.members) do LightRP.notice(id, { kind = kind or "contract", title = title, body = body, durationMs = 6000 }) end
end
local function push(inst) Missions.pushSquad(inst) end

-- What the clients draw while the mission runs: the checkpoints. The perimeter is not
-- drawn for the players (user request 2026-11-02: "on s'en fout"); leaving it still
-- starts the out-of-zone countdown on the page.
local function visuals(run)
    local cps = {}
    for i, c in ipairs(run.def.checkpoints) do
        cps[i] = { id = c.id, label = c.label, position = c.position, radius = c.radius, required = c.required, reached = run.reached[c.id] == true }
    end
    return { kind = "state", instance = run.instance, type = run.def.type, title = run.def.title,
        graceSeconds = run.def.outOfBounds.graceSeconds, checkpoints = cps }
end
local function sendVisuals(inst, only)
    local payload = visuals(inst.run)
    if only then TriggerClientEvent(NET, only, payload) return end
    for _, id in ipairs(inst.members) do TriggerClientEvent(NET, id, payload) end
end

-- ---------------------------------------------------------------------------
-- Enemies

local function enqueue(run, spawnId)
    local s = run.spawns[spawnId]
    if not s then return 0 end
    local count = D.count(s, run.difficulty)
    for i = 1, count do run.queue[#run.queue + 1] = { spawn = s, slot = i, wave = run.waveIndex } end
    run.total = run.total + count
    return count
end

local function create(inst, entry)
    local run, s = inst.run, entry.spawn
    local enemy = D.ENEMY[s.enemy] or D.ENEMIES[1]
    -- the squad of a spawn point stands in a loose sunflower around it, `spread` metres wide
    local angle = (entry.slot - 1) * 2.399963
    local spread = s.spread or 2
    local radius = entry.slot == 1 and 0 or spread * math.sqrt((entry.slot - 1) / math.max(1, D.count(s, run.difficulty) - 1))
    local p = { x = s.position.x + math.cos(angle) * radius, y = s.position.y + math.sin(angle) * radius, z = s.position.z }
    local def = { position = p, yaw = s.heading, bucket = inst.bucket,
        aiMode = Open77.npcs.ai.native, damagePolicy = Open77.npcs.damage.mortal,
        streamingRadius = 200, persistent = false, despawnWhenUnobserved = false,
        -- a spawn point may be tougher than its difficulty (a world boss: s.healthMultiplier)
        difficulty = { healthMultiplier = run.difficulty.enemyHealth * (s.healthMultiplier or 1), damageMultiplier = run.difficulty.enemyDamage },
        loadout = { combat = { group = COMBAT_GROUP, acquirePlayers = true, authoritativePlayerHits = true } },
        behavior = { hitPricing = "platform", aiEnabled = true, combatEnabled = true } }
    if enemy.record then def.record = enemy.record else def.template = enemy.template end
    local ok, npcId, why = pcall(Open77.npcs.create, def)
    if not ok or not npcId then
        run.failedSpawns = run.failedSpawns + 1
        LightRP.log("mission %s: enemy %s at %s refused (%s)", inst.id, s.enemy, s.id, tostring(ok and why or npcId))
        return false
    end
    run.enemies[npcId] = { spawn = s, wave = entry.wave, taskAt = 0, group = s.id .. "#" .. (entry.wave or 0), health = nil }
    run.alive = run.alive + 1
    if s.behavior == "ambush" then
        -- silent and blind until alerted (the alert turns both back on)
        pcall(Open77.npcs.setCombatEnabled, npcId, false)
        pcall(Open77.npcs.setPerceptionEnabled, npcId, false)
    end
    if run.onCreated then pcall(run.onCreated, npcId, s) end
    return npcId
end

local alert, behave
local function nearestTarget(inst, p)
    local best, bestDistance
    for _, id in ipairs(inst.members) do
        if alive(id) and not inst.run.respawns[id] then
            local q = positionOf(id)
            local d = q and distance(p, q)
            if d and d <= ENGAGE_RANGE and (not bestDistance or d < bestDistance) then best, bestDistance = id, d end
        end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- Behaviours (shared/mission_defs.lua M.BEHAVIORS)

alert = function(npcId, e)
    e.alerted, e.taskAt, e.idle = true, 0, nil
    if e.spawn.behavior == "ambush" then
        pcall(Open77.npcs.setCombatEnabled, npcId, true)
        pcall(Open77.npcs.setPerceptionEnabled, npcId, true)
    end
end

-- Until it is alerted a squad keeps its behaviour; then it fights like an assault.
behave = function(inst, npcId, e, t)
    local run, s = inst.run, e.spawn
    local ok, npc = pcall(Open77.npcs.get, npcId)
    npc = ok and type(npc) == "table" and npc or {}
    local p = npc.position or s.position
    if not e.alerted then
        local hurt = e.health and npc.health and npc.health < e.health
        e.health = e.health or npc.health
        local near = false
        for _, id in ipairs(inst.members) do
            local q = alive(id) and not run.respawns[id] and positionOf(id)
            if q and (distance(q, p) <= s.alertRange or distance(q, s.position) <= s.alertRange) then near = true break end
        end
        if s.behavior == "assault" or hurt or near then
            alert(npcId, e)
            run.alerting[e.group] = true
        elseif not e.idle then
            -- the behaviour's task, issued once; the platform keeps it running
            e.idle = true
            if s.behavior == "defend" then
                pcall(Open77.npcs.tasks.guard, npcId, s.position, s.radius, { speed = "run" })
            elseif s.behavior == "patrol" then
                local route = { { x = s.position.x, y = s.position.y, z = s.position.z, waitMs = 1500 } }
                for _, q in ipairs(s.route) do route[#route + 1] = { x = q.x, y = q.y, z = q.z, waitMs = 1500 } end
                pcall(Open77.npcs.tasks.patrol, npcId, route, { speed = "walk", loop = true })
            elseif s.behavior == "wander" then
                pcall(Open77.npcs.tasks.wander, npcId, { x = s.position.x, y = s.position.y, z = s.position.z, radius = s.radius, speed = "walk" })
            else
                pcall(Open77.npcs.tasks.guard, npcId, p, 1)
            end
        end
        return
    end
    if t < e.taskAt then return end
    e.taskAt = t + RETARGET_MS
    local target = nearestTarget(inst, p)
    if s.behavior == "defend" then
        -- defenders fight from their area: only operators inside it (plus a margin) are chased
        local q = target and positionOf(target)
        if q and distance(q, s.position) <= s.radius + 15 then
            pcall(Open77.npcs.tasks.attack, npcId, { playerId = target }, { reacquireMs = 4000 })
        else
            pcall(Open77.npcs.tasks.guard, npcId, s.position, s.radius, { speed = "run" })
        end
    elseif target then
        pcall(Open77.npcs.tasks.attack, npcId, { playerId = target }, { reacquireMs = 4000 })
    elseif run.def.type == "eliminate" then
        pcall(Open77.npcs.tasks.guard, npcId, s.position, math.max(6, s.radius or 12))
    end
end

local function enemiesTick(inst)
    local run, t = inst.run, now()
    -- creations, a few per tick under the alive cap
    local made = 0
    while #run.queue > 0 and made < SPAWNS_PER_TICK and run.alive < D.MAX_ALIVE do
        local entry = table.remove(run.queue, 1)
        if create(inst, entry) then made = made + 1 end
    end
    -- the dead are counted, then their bodies go after a short while
    for npcId, e in pairs(run.enemies) do
        if e.deadAt then
            if t - e.deadAt >= CORPSE_MS then
                pcall(Open77.npcs.remove, npcId)
                run.enemies[npcId] = nil
            end
        elseif not npcAlive(npcId) then
            e.deadAt = t
            run.alive = math.max(0, run.alive - 1)
            run.kills = run.kills + 1
            run.dirty = true
        else
            behave(inst, npcId, e, t)
        end
    end
    -- an alert spreads to the whole squad of the spawn point
    for group in pairs(run.alerting) do
        for npcId, e in pairs(run.enemies) do
            if e.group == group and not e.alerted and not e.deadAt then alert(npcId, e) end
        end
        run.alerting[group] = nil
    end
end

local function clearEnemies(run)
    for npcId in pairs(run.enemies) do pcall(Open77.npcs.remove, npcId) end
    run.enemies, run.queue, run.alive = {}, {}, 0
end
-- The same enemies in the open world (server/modules/world_bosses.lua): an "instance"
-- of bucket 0 whose members are whoever stands in the zone.
Engine.world = { enqueue = enqueue, enemiesTick = enemiesTick, clearEnemies = clearEnemies, create = create }

-- ---------------------------------------------------------------------------
-- Checkpoints, waves, victory

local function checkpointsTick(inst)
    local run = inst.run
    for _, c in ipairs(run.def.checkpoints) do
        if not run.reached[c.id] then
            for _, id in ipairs(inst.members) do
                local p = alive(id) and not run.respawns[id] and positionOf(id)
                if p and distance(p, c.position) <= c.radius + 1 then
                    run.reached[c.id] = true
                    local woken = 0
                    for _, spawnId in ipairs(c.spawns) do woken = woken + enqueue(run, spawnId) end
                    announce(inst, "CHECKPOINT", string.format("%s reached %s.%s", name(id), c.label,
                        woken > 0 and string.format(" %d hostile%s inbound.", woken, woken == 1 and "" or "s") or ""), woken > 0 and "warning" or "contract")
                    run.dirty = true
                    sendVisuals(inst)
                    break
                end
            end
        end
    end
end

local function requiredLeft(run)
    local left = 0
    for _, c in ipairs(run.def.checkpoints) do if c.required and not run.reached[c.id] then left = left + 1 end end
    return left
end

local function wavesTick(inst)
    local run, t = inst.run, now()
    local waves = run.def.waves
    if run.phase == "intermission" and t >= run.nextWaveAt then
        run.waveIndex = run.waveIndex + 1
        local w = waves[run.waveIndex]
        local count = 0
        for _, spawnId in ipairs(w.spawns) do count = count + enqueue(run, spawnId) end
        run.phase, run.dirty = "wave", true
        announce(inst, string.format("WAVE %d / %d", run.waveIndex, #waves), string.format("%d hostile%s incoming. Hold the zone.", count, count == 1 and "" or "s"), "warning")
    elseif run.phase == "wave" and #run.queue == 0 and run.alive == 0 then
        if run.waveIndex >= #waves then
            run.phase = "done"
            announce(inst, "ZONE HELD", "The last wave is down.", "success")
            Missions.complete(inst.id)
            return
        end
        local delay = waves[run.waveIndex + 1].delaySeconds
        run.phase, run.nextWaveAt, run.dirty = "intermission", t + delay * 1000, true
        announce(inst, "WAVE CLEARED", string.format("Wave %d is down. Next in %d s: reload, regroup.", run.waveIndex, delay), "success")
    end
end

local function eliminateTick(inst)
    local run = inst.run
    if run.phase == "fight" and #run.queue == 0 and run.alive == 0 and requiredLeft(run) == 0 then
        run.phase = "done"
        announce(inst, "ZONE CLEARED", "No hostile left standing.", "success")
        Missions.complete(inst.id)
    end
end

-- ---------------------------------------------------------------------------
-- Perimeter

local function insidePerimeter(inst, id)
    local run = inst.run
    local p = positionOf(id)
    if run.prepared and type(Open77.zones) == "table" and type(Open77.zones.containsPlayer) == "function" then
        local options = { bucket = inst.bucket, maxAgeMs = 2000, grace = 0 }
        if p then options.origin = G.origin({ fullHeight = run.def.perimeter.fullHeight, shape = run.def.perimeter.shape, center = run.def.perimeter.center }, p) end
        local ok, inside = pcall(Open77.zones.containsPlayer, id, run.prepared, options)
        if ok and inside ~= nil then return inside == true end
    end
    if not p then return nil end
    return D.inside(run.def.perimeter, p)
end

local function perimeterTick(inst)
    local run, t = inst.run, now()
    local grace = run.def.outOfBounds.graceSeconds * 1000
    for _, id in ipairs(inst.members) do
        if not alive(id) or run.respawns[id] or run.out[id] then
            if run.outside[id] then run.outside[id] = nil; LightRP.state(id, "missionQueue") end
        else
            local inside = insidePerimeter(inst, id)
            if inside == false then
                if not run.outside[id] then
                    run.outside[id] = t
                    LightRP.notice(id, { kind = "error", title = "LEAVING THE ZONE", durationMs = 5000,
                        body = string.format("Get back inside the perimeter within %d seconds.", run.def.outOfBounds.graceSeconds) })
                    LightRP.state(id, "missionQueue")
                elseif t - run.outside[id] >= grace then
                    run.outside[id] = nil
                    LightRP.log("mission %s: %s killed out of the perimeter", inst.id, name(id))
                    local ok, killed, why = pcall(Open77.players.kill, id)
                    if not ok or killed == false then
                        pcall(Open77.players.setHealth, id, 0)
                        LightRP.log("mission %s: kill of %s refused (%s), health set to 0", inst.id, name(id), tostring(ok and why or killed))
                    end
                    LightRP.notice(id, { kind = "error", title = "OUT OF THE ZONE", body = "You stayed out of the perimeter too long." })
                end
            elseif inside == true and run.outside[id] then
                run.outside[id] = nil
                LightRP.state(id, "missionQueue")
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Deaths, respawns, wipe

-- One fall: a team respawn if any is left, else the operator is out.
local function fall(inst, id)
    local run = inst.run
    if run.down[id] or run.respawns[id] or run.out[id] then return end
    run.down[id] = true
    run.outside[id] = nil
    if run.phase == "staging" then
        run.respawns[id] = now() + 3000   -- before the first enemy a fall costs nothing
    elseif run.lives > 0 then
        run.lives = run.lives - 1
        run.respawns[id] = now() + run.def.respawn.seconds * 1000
        announce(inst, "OPERATOR DOWN", string.format("%s is down. Back in %d s (%d team respawn%s left).", name(id), run.def.respawn.seconds,
            run.lives, run.lives == 1 and "" or "s"), "warning")
    else
        run.out[id] = true
        announce(inst, "OPERATOR LOST", name(id) .. " is out: no team respawn left.", "error")
    end
    run.dirty = true
end

local function respawnTick(inst)
    local run, t = inst.run, now()
    for id, at in pairs(run.respawns) do
        if t >= at then
            run.respawns[id] = nil
            local slot = 1
            for i, m in ipairs(inst.members) do if m == id then slot = i end end
            local spot = run.def.starts[((slot - 1) % #run.def.starts) + 1]
            local ok, why = Open77.players.respawn(id, { position = { x = spot.x, y = spot.y, z = spot.z }, heading = spot.heading or 0,
                bucket = inst.bucket, health = LightRpConfig.spawn and LightRpConfig.spawn.health or nil })
            if ok then
                -- the platform takes a moment (respawnpending, recovering): the operator counts
                -- as standing until the new life arrives, or this deadline passes
                run.reviving[id] = t + 15000
            elseif not fallen(id) then
                -- already on their feet (the fall was not one): nothing to bring back
                run.down[id], run.retries[id] = nil, nil
                LightRP.log("mission %s: %s is already alive, respawn skipped", inst.id, name(id))
            else
                run.retries[id] = (run.retries[id] or 0) + 1
                LightRP.log("mission %s: respawn of %s refused (%s), attempt %d", inst.id, name(id), tostring(why), run.retries[id])
                if run.retries[id] <= 5 then run.respawns[id] = t + 2000 end
            end
            run.dirty = true
        end
    end
    local standing = 0
    for _, id in ipairs(inst.members) do
        if run.reviving[id] and t >= run.reviving[id] then run.reviving[id] = nil end
        local down = fallen(id)
        -- a death its event has not reported yet (a perimeter kill lands within the tick)
        if down and not run.down[id] and not run.out[id] and not run.respawns[id] and not run.reviving[id] then fall(inst, id) end
        if (not down and not run.out[id] and not run.down[id]) or run.respawns[id] or run.reviving[id] then standing = standing + 1 end
    end
    if standing == 0 and #inst.members > 0 then
        run.phase = "done"
        Missions.fail(inst.id, "squad wiped")
    end
end

-- ---------------------------------------------------------------------------
-- The mission kit: native weapons for the run (LightRP's armament stands aside while
-- Missions.handlesLoadout says so and gives the character's own weapons back after).
-- `loadout` on the definition picks a kit of LightRpRaid.loadouts ("none": the
-- operators bring their own); without it the first kit (assault) is handed out.

local function kitList() return type(LightRpRaid) == "table" and LightRpRaid.loadouts or {} end
local function kitById(id)
    for _, kit in ipairs(kitList()) do if kit.id == id then return kit end end
end
-- The kit preselected for a mission (its `loadout`, else the first); nil: no kits at all.
local function kitFor(def)
    local wanted = def.loadout or "assault"
    if wanted == "none" then return nil end
    return kitById(wanted) or kitList()[1]
end
Engine.kitFor = kitFor
-- What the briefing lists (id, label, blurb), like the raid's ready check.
local KIT_VIEW
local function kitView()
    if KIT_VIEW then return KIT_VIEW end
    KIT_VIEW = {}
    for _, kit in ipairs(kitList()) do KIT_VIEW[#KIT_VIEW + 1] = { id = kit.id, label = kit.label, blurb = kit.blurb } end
    return KIT_VIEW
end

local waitingWeapons = {}
AddEventHandler("open77:weapons:completed", function(player, request, _, accepted, reason, result)
    waitingWeapons[tostring(player) .. ":" .. tostring(request)] = { accepted = accepted, reason = reason, result = result }
end)
local function weapons(player, method, ...)
    if type(Open77.weapons) ~= "table" or type(Open77.weapons[method]) ~= "function" then return nil, "weapons_api_unavailable" end
    local ok, request, why = pcall(Open77.weapons[method], player, ...)
    if not ok or not request then return nil, ok and why or request end
    local key = tostring(player) .. ":" .. tostring(request)
    local deadline = now() + 10000
    while not waitingWeapons[key] and now() < deadline do Wait(50) end
    local done = waitingWeapons[key]
    waitingWeapons[key] = nil
    if not done then return nil, "request_timeout" end
    if not done.accepted then return nil, done.reason end
    return done.result or true
end
local function slotsOf(snapshot) return type(snapshot) == "table" and (snapshot.slots or snapshot) or {} end
local function capacityOf(snapshot, slot)
    for _, row in ipairs(slotsOf(snapshot)) do
        if type(row) == "table" and tonumber(row.slot) == slot and type(row.ammo) == "table" then return tonumber(row.ammo.capacity) end
    end
end
-- In hand: slot 1 holds the kit's primary with rounds in it.
local function armed(snapshot, kit)
    for _, row in ipairs(slotsOf(snapshot)) do
        if type(row) == "table" and tonumber(row.slot) == 1 then
            local a = type(row.ammo) == "table" and row.ammo or {}
            local rounds = tonumber(a.total) or ((tonumber(a.reserve) or 0) + (tonumber(a.magazine) or 0))
            return row.record == kit.primary and rounds > 0
        end
    end
    return false
end

local function equip(inst, id)
    local run = inst.run
    if not run or not run.kit then return end
    run.equipping = run.equipping or {}
    if run.equipping[id] then return end
    run.equipping[id] = true
    local kit = kitById(run.choice and run.choice[id]) or run.kit
    CreateThread(function()
        Wait(1500) -- the operator lands in the arena first
        for attempt = 1, 6 do
            if inst.run ~= run or run.phase == "done" or not alive(id) then break end
            local function step(method, ...)
                local result, why = weapons(id, method, ...)
                if not result and why ~= "weapon_slot_empty" then
                    LightRP.log("mission %s: kit %s for %s: %s refused (%s)", inst.id, kit.id, name(id), method, tostring(why))
                end
                return result
            end
            step("clear")
            step("assign", kit.primary, 1, { active = true, addToInventory = true })
            step("assign", kit.secondary, 2, { active = false, addToInventory = true })
            for slot = 1, 2 do
                step("setAmmo", slot, { reserve = kit.reserve[slot], activate = slot == 1 })
                local capacity = capacityOf(step("requestSnapshot"), slot)
                if capacity then step("setAmmo", slot, { magazine = capacity, activate = slot == 1 }) end
            end
            step("setActive", 1)
            if armed(weapons(id, "requestSnapshot"), kit) then
                LightRP.log("mission %s: kit %s handed to %s", inst.id, kit.id, name(id))
                break
            end
            LightRP.log("mission %s: kit %s for %s not in hand (attempt %d), retrying", inst.id, kit.id, name(id), attempt)
            Wait(3000)
        end
        run.equipping[id] = nil
    end)
end
Engine.equip = equip
Engine.weapons = weapons

-- The briefing (staging), like the raid's ready check: each operator picks a kit (page
-- action mission.loadout, keys 1-5) and says ready (mission.ready, Enter); the kit is
-- handed out on ready, and to whoever is not ready when the fight starts. A downed
-- operator may pick another one: it comes with the next life.
local function canChoose(run, id)
    return run.kit ~= nil and (run.phase == "staging" or run.respawns[id] ~= nil or run.down[id] ~= nil or run.reviving[id] ~= nil)
end
local function allReady(inst)
    local run = inst.run
    for _, id in ipairs(inst.members) do if not run.ready[id] then return false end end
    return #inst.members > 0
end
LightRP.action("mission.loadout", function(id, payload)
    local inst = Missions.instanceOf(id)
    local run = inst and inst.run
    local kit = type(payload) == "table" and kitById(payload.id)
    if not run or not kit or not canChoose(run, id) then return end
    run.choice[id] = kit.id
    -- already ready in the briefing: the new kit at once
    if run.phase == "staging" and run.ready[id] then equip(inst, id) end
    run.dirty = true
    push(inst)
end)
LightRP.action("mission.ready", function(id)
    local inst = Missions.instanceOf(id)
    local run = inst and inst.run
    if not run or run.phase ~= "staging" or run.ready[id] then return end
    run.ready[id] = true
    equip(inst, id)
    run.dirty = true
    push(inst)
end)

-- ---------------------------------------------------------------------------
-- NPC hits on the operators. The mission's NPCs opt into authoritativePlayerHits: the
-- engine no longer lets their shots drain the native health, the client that owns the
-- NPC reports each hit (client/core/mission_run.lua relays open77:npcPlayerHit) and the
-- server applies it to the canonical health the HUD shows. Without this the HUD stayed
-- at 100 while the native body died (2026-11-02, "The House").

local INCOMING = { maxPerHit = 40, maxPerSecond = 120, range = 150 }
local incomingWindow = {}
local function bucketOf(id)
    local ok, life = pcall(Open77.players.getLifeState, id)
    return ok and type(life) == "table" and life.bucket or nil, ok and type(life) == "table" and life.phase or nil
end
local function isMember(inst, id)
    for _, m in ipairs(inst.members) do if m == id then return true end end
    return false
end
-- One reported hit of `key` (an NPC the caller already tied to `inst`) on `victim`.
-- Also used by the raid's reinforcements (server/modules/mission_chimera.lua).
function Engine.applyNpcHit(inst, reporter, victim, key, reportedEpoch, damage)
    if not isMember(inst, reporter) or not isMember(inst, victim) then return false, "not_in_mission" end
    local ok, npc = pcall(Open77.npcs.get, key)
    if not ok or type(npc) ~= "table" or (tonumber(npc.health) or 0) <= 0 then return false, "npc_gone" end
    -- only the client that owns the NPC's simulation reports its hits, for its current lease
    if tostring(npc.authorityPlayerId) ~= tostring(reporter) or tonumber(npc.authorityEpoch) ~= reportedEpoch then return false, "not_owner" end
    local victimBucket, phase = bucketOf(victim)
    if victimBucket ~= inst.bucket or (phase ~= "alive" and phase ~= "recovering") then return false, "victim_not_here" end
    local p, n = positionOf(victim), npc.position
    if p and type(n) == "table" and distance(p, n) > INCOMING.range then return false, "too_far" end
    damage = math.min(damage, INCOMING.maxPerHit)
    local t, w = now(), incomingWindow[victim]
    if not w or t - w.since >= 1000 then w = { since = t, total = 0 }; incomingWindow[victim] = w end
    if w.total + damage > INCOMING.maxPerSecond then return false, "rate" end
    w.total = w.total + damage
    local applied, why = Open77.players.damage(victim, damage, { attacker = key, cause = "firearm" })
    if applied == false then LightRP.log("mission %s: hit on %s refused (%s)", inst.id, name(victim), tostring(why)) end
    return applied ~= false, why
end
function Engine.npcHit(reporter, victimId, npcId, epoch, amount)
    local victim, damage, reportedEpoch = tonumber(victimId), tonumber(amount), tonumber(epoch)
    if not victim or not damage or damage ~= damage or damage <= 0 or not reportedEpoch then return false, "invalid" end
    local inst = Missions.instanceOf(victim)
    local run = inst and inst.run
    if not run or run.phase == "done" then return false, "no_run" end
    local key
    for id in pairs(run.enemies) do if tostring(id) == tostring(npcId) then key = id end end
    if key == nil then return false, "not_this_mission" end
    return Engine.applyNpcHit(inst, reporter, victim, key, reportedEpoch, damage)
end
RegisterNetEvent(NET .. ":npcHit", function(victimId, npcId, epoch, amount)
    local reporter = tonumber(source)
    if reporter and reporter > 0 then Engine.npcHit(reporter, victimId, npcId, epoch, amount) end
end)

-- ---------------------------------------------------------------------------
-- The script

local function view(inst, viewer)
    local run = inst.run
    if not run then return nil end
    local t = now()
    local v = { kind = run.def.type, phase = run.phase, enemiesLeft = run.alive + #run.queue, kills = run.kills, lives = run.lives }
    if run.phase == "staging" then v.startsInMs = math.max(0, run.startAt - t) end
    if run.def.type == "waves" then
        v.wave, v.waves = run.waveIndex, #run.def.waves
        if run.phase == "intermission" then v.nextWaveInMs = math.max(0, run.nextWaveAt - t) end
    end
    if #run.def.checkpoints > 0 then
        v.checkpoints = {}
        for i, c in ipairs(run.def.checkpoints) do v.checkpoints[i] = { label = c.label, reached = run.reached[c.id] == true, required = c.required } end
    end
    if viewer and run.outside[viewer] then
        v.outOfBoundsMs = math.max(0, run.def.outOfBounds.graceSeconds * 1000 - (t - run.outside[viewer]))
    end
    if viewer and run.respawns[viewer] then v.respawnInMs = math.max(0, run.respawns[viewer] - t) end
    if viewer and run.out[viewer] then v.spectating = true end
    if run.kit and viewer then
        v.loadout, v.canChoose = run.choice[viewer], canChoose(run, viewer)
        if v.canChoose then v.loadouts = kitView() end
        if run.phase == "staging" then
            local n = 0
            for _, id in ipairs(inst.members) do if run.ready[id] then n = n + 1 end end
            v.ready, v.readyCount, v.squadSize = run.ready[viewer] == true, n, #inst.members
        end
    end
    return v
end

local function script(def)
    return {
        view = view,
        -- the weapon wheel lists the kit and draws it back (Missions.kitOf / drawKit)
        kitOf = function(inst, id)
            local run = inst.run
            return run and run.kit and (kitById(run.choice and run.choice[id]) or run.kit) or nil
        end,
        reissueKit = function(inst, id) equip(inst, id) end,
        onStart = function(inst)
            local d = Missions.difficulty(inst)
            local run = { def = D.clone(def), instance = inst.id, difficulty = d, phase = "staging", startAt = now() + START_DELAY_MS,
                spawns = {}, queue = {}, enemies = {}, alive = 0, total = 0, kills = 0, failedSpawns = 0,
                reached = {}, waveIndex = 0, outside = {}, out = {}, respawns = {}, down = {}, alerting = {}, reviving = {}, retries = {}, lives = def.respawn.lives }
            for _, s in ipairs(run.def.spawns) do run.spawns[s.id] = s end
            local zones = type(Open77.zones) == "table" and Open77.zones or {}
            local ok, prepared = pcall(zones.normalize, G.definition({ shape = def.perimeter.shape, center = def.perimeter.center,
                radius = def.perimeter.radius, length = def.perimeter.length, width = def.perimeter.width, heading = def.perimeter.heading,
                points = def.perimeter.points, minZ = def.perimeter.minZ, maxZ = def.perimeter.maxZ, fullHeight = def.perimeter.fullHeight }))
            run.prepared = ok and prepared or nil
            run.kit = kitFor(def)
            -- the armament stands aside for the whole run (Missions.handlesLoadout)
            inst.loadout = run.kit ~= nil
            run.choice, run.ready = {}, {}
            for _, id in ipairs(inst.members) do run.choice[id] = run.kit and run.kit.id or nil end
            -- the briefing: the arena streams in (START_DELAY_MS at least), the kits are picked
            run.minStartAt = run.startAt
            if run.kit then run.startAt = now() + BRIEFING_MS end
            if not run.prepared then LightRP.log("mission %s: perimeter not prepared by the zone service, local maths used", inst.id) end
            inst.run = run
            sendVisuals(inst)
            if inst.loadout and LightRP.armament and type(LightRP.armament.push) == "function" then
                for _, id in ipairs(inst.members) do pcall(LightRP.armament.push, id) end
            end
        end,
        onTick = function(inst)
            local run = inst.run
            if not run or run.phase == "done" then return end
            if run.phase == "staging" then
                local t = now()
                if t < run.minStartAt or (t < run.startAt and not allReady(inst)) then return end
                -- whoever did not say ready gets the kit they had picked
                for _, id in ipairs(inst.members) do if run.kit and not run.ready[id] then run.ready[id] = true; equip(inst, id) end end
                if run.def.type == "waves" then
                    run.phase, run.nextWaveAt = "intermission", now() + (run.def.waves[1].delaySeconds or 0) * 1000
                    announce(inst, "HOLD THE ZONE", string.format("%d waves. The first one lands in %d s.", #run.def.waves, run.def.waves[1].delaySeconds), "contract")
                else
                    run.phase = "fight"
                    for _, s in ipairs(run.def.spawns) do if s.trigger == "start" then enqueue(run, s.id) end end
                    announce(inst, "CLEAR THE ZONE", string.format("%d hostile%s on site%s.", run.total, run.total == 1 and "" or "s",
                        requiredLeft(run) > 0 and string.format(", %d checkpoint%s to reach", requiredLeft(run), requiredLeft(run) == 1 and "" or "s") or ""), "contract")
                end
                run.dirty = true
            end
            enemiesTick(inst)
            checkpointsTick(inst)
            if run.def.type == "waves" then wavesTick(inst) else eliminateTick(inst) end
            if run.phase == "done" then return end
            perimeterTick(inst)
            respawnTick(inst)
            if run.dirty then run.dirty = false; push(inst) end
        end,
        onLifeState = function(inst, id, phase)
            local run = inst.run
            if not run or run.phase == "done" then return end
            if phase == "alive" or phase == "recovering" then
                if phase == "alive" then
                    run.down[id], run.reviving[id], run.retries[id] = nil, nil, nil
                    -- a new life: the kit again (a respawn leaves the hands empty)
                    equip(inst, id)
                end
                run.outside[id] = nil
                LightRP.state(id, "missionQueue")
                return
            end
            -- only a real fall costs a life: a teleport or a streaming hand-off passes through
            -- other phases while the operator stays on their feet
            if not DEATH_PHASES[phase] then
                LightRP.log("mission %s: %s life phase %s ignored", inst.id, name(id), tostring(phase))
                return
            end
            -- one death per fall: respawnpending/revivepending after it are the same one
            fall(inst, id)
        end,
        onLeave = function(inst, id)
            local run = inst.run
            if run then run.outside[id], run.respawns[id], run.out[id], run.down[id], run.reviving[id] = nil, nil, nil, nil, nil end
            TriggerClientEvent(NET, id, { kind = "end", instance = inst.id })
        end,
        onEnd = function(inst)
            local run = inst.run
            if run then run.phase = "done"; clearEnemies(run) end
            for _, id in ipairs(inst.members) do TriggerClientEvent(NET, id, { kind = "end", instance = inst.id }) end
        end,
    }
end

-- ---------------------------------------------------------------------------
-- Published definitions -> board points

local published = {}   -- id -> definition
function Engine.publish(def)
    published[def.id] = def
    Missions.register(def.id, script(def))
    local boss = def.worldBoss and def.worldBoss.enabled
    -- a world boss has no board: it goes to the world boss catalogue instead
    if def.enabled and not boss then Missions.addPoint(D.point(def)) else Missions.removePoint(def.id) end
    if LightRP.worldBosses then
        if def.enabled and boss then LightRP.worldBosses.publish(def) else LightRP.worldBosses.withdraw(def.id) end
    end
end
function Engine.withdraw(id)
    published[id] = nil
    Missions.removePoint(id)
    if LightRP.worldBosses then LightRP.worldBosses.withdraw(id) end
    -- the script stays registered: a run in progress keeps its own state and ends normally
end
function Engine.published(id) return published[id] end

-- A client that reconnects to a running mission (resource restart) gets the visuals again.
RegisterNetEvent(NET, function(payload)
    local id = tonumber(source)
    if not id or type(payload) ~= "table" or payload.kind ~= "hello" then return end
    local inst = Missions.instanceOf(id)
    if inst and inst.run then sendVisuals(inst, id) end
end)
