-- The Chimera raid (mission point "chimera_raid"): a Militech Chimera war
-- machine (open77_chimera) in the Dogtown arena, run inside the mission's own
-- routing bucket. The mission module (missions.lua) gathers the squad and moves
-- it in; this script runs the raid:
--
--   ready    every operator presses the ready key (or the check times out)
--   launch   "ENGAGING IN 5"
--   intro    the boss is placed and stays passive while the clients play the
--            cinematic (client/core/raid.lua)
--   fight    the boss fights; health thresholds call Militech reinforcements,
--            the core overclocks after a while (enrage), the boss locks on to
--            one operator at a time; dead operators respawn from a team pool
--   victory  the boss is down: a few seconds in the arena, then payout
--   wipe     every operator down at once (or no respawns left): failure
--
-- Everything scales with the difficulty and the number of operators
-- (LightRpRaid.scaling). The clients get the raid state on op77_lightrp:raid.
local C = LightRpRaid
local Missions = LightRP.missions
local POINT = "chimera_raid"
local NET = "op77_lightrp:raid"
local PROVIDER = "open77_chimera"
local ADD_GROUP = "open77_chimera" -- the boss's own combat group: reinforcements fight beside it

local raids = {}            -- instance id -> raid
local LOADOUTS = {}         -- what the ready check lists
local kits = {}
for _, kit in ipairs(C.loadouts) do
    kits[kit.id] = kit
    LOADOUTS[#LOADOUTS + 1] = { id = kit.id, label = kit.label, blurb = kit.blurb }
end
local function now() return LightRP.nowMs() end
local function name(id) return Missions.name(id) end

local function boss(method, ...)
    local ok, value, why = pcall(Open77.exports.callSync, PROVIDER, method, ...)
    if not ok then why, value = tostring(value), nil end
    if value == nil and method ~= "get" and method ~= "result" then LightRP.log("raid: chimera %s refused (%s)", method, tostring(why)) end
    return value, why
end

local function alive(id)
    local life = Open77.players.getLifeState(id)
    return life == nil or life.phase == "alive" or life.phase == "recovering"
end

local function scaling(inst)
    local s = C.scaling[inst.difficulty] or C.scaling.standard
    local extra = math.max(0, #inst.members - 1)
    return s, s.health + s.healthPerOperator * extra, s.damage
end

-- ---------------------------------------------------------------------------
-- What the clients see

local function view(inst, raid, playerId)
    local d = Missions.difficulty(inst)
    local s = scaling(inst)
    local t = now()
    local operators = {}
    for _, id in ipairs(inst.members) do
        operators[#operators + 1] = { id = id, name = name(id), ready = raid.ready[id] == true, down = raid.down[id] == true,
            loaded = raid.loaded[id] == true }
    end
    local b = raid.state
    return {
        instance = inst.id, phase = raid.phase, title = Missions.point(POINT).title, difficulty = d.label, difficultyId = d.id,
        operators = operators,
        readyEndsInMs = raid.phase == "ready" and math.max(0, raid.readyEnds - t) or nil,
        launchInMs = raid.phase == "launch" and math.max(0, raid.launchAt - t) or nil,
        readyKey = LightRpConfig.keys.raidReady.key,
        bossId = raid.bossId and tostring(raid.bossId) or nil,
        boss = b and { healthPercent = math.max(0, math.min(100, tonumber(b.healthPercent) or 0)), phase = b.phase, label = "CHIMERA",
            enraged = raid.enraged == true, target = raid.lockOn and raid.lockOn.player or nil,
            repairing = b.repairing == true or nil,
            repairInMs = b.repairing and raid.repairEnds and math.max(0, raid.repairEnds - t) or nil,
            targetName = raid.lockOn and name(raid.lockOn.player) or nil } or nil,
        adds = raid.addCount or 0,
        lives = s.respawnSeconds and (s.lives >= 99 and -1 or raid.lives) or 0,
        respawnInMs = raid.respawns[playerId] and math.max(0, raid.respawns[playerId] - t) or nil,
        out = raid.out[playerId] == true,
        fightSeconds = raid.fightStarted and math.floor((t - raid.fightStarted) / 1000) or 0,
        enrageInMs = raid.fightStarted and not raid.enraged and math.max(0, raid.fightStarted + s.enrageMinutes * 60000 - t) or nil,
        loadouts = raid.phase == "ready" and LOADOUTS or nil,
        loadout = raid.loadouts[playerId],
        loaded = raid.loaded[playerId] == true,
        arena = Missions.point(POINT).arena,
        kit = (function()
            local k = kits[raid.loadouts[playerId] or ""]
            if not k then return nil end
            return { [k.primary] = k.names and k.names[1] or k.label, [k.secondary] = k.names and k.names[2] or k.label }
        end)(),
        music = (raid.phase == "intro" or raid.phase == "fight" or raid.phase == "victory") and C.music or nil,
    }
end

local function push(inst, raid, extra)
    for _, id in ipairs(inst.members) do
        local payload = view(inst, raid, id)
        if extra then for k, v in pairs(extra) do payload[k] = v end end
        TriggerClientEvent(NET, id, payload)
    end
end

local function announce(inst, raid, title, body, tone, sound)
    push(inst, raid, { announce = { title = title, body = body, tone = tone or "info", at = now() }, sound = sound })
end

-- Game effects in the arena, for everyone in the instance: one-shots, or loops
-- with a lifetime (ttlMs) that the raid removes when it ends.
local function fx(inst, names, position, lift)
    if type(names) ~= "table" then names = { names } end
    local p = { x = position.x, y = position.y, z = position.z + (lift or 0) }
    for _, effect in ipairs(names) do
        local ok, why = pcall(Open77.effects.play, effect, { position = p, bucket = inst.bucket, range = 250 })
        if not ok or why == false then LightRP.log("raid %s: effect %s refused (%s)", inst.id, effect, tostring(why)) end
    end
end
local function loop(inst, raid, effect, position, ttlMs)
    local ok, id = pcall(Open77.effects.create, { effect = effect, position = position, bucket = inst.bucket,
        streamingRadius = 250, ttlMs = ttlMs or 0 })
    if ok and id then raid.loops[id] = true; return id end
    LightRP.log("raid %s: effect %s refused (%s)", inst.id, effect, tostring(id))
end
local function clearLoops(raid)
    for id in pairs(raid.loops) do pcall(Open77.effects.remove, id) end
    raid.loops = {}
end

-- ---------------------------------------------------------------------------
-- Reinforcements

local function addAlive(id)
    local npc = Open77.npcs.get(id)
    return npc and (tonumber(npc.health) or 0) > 0
end

local function spawnAdd(inst, raid, center)
    local angle = math.random() * math.pi * 2
    local r = C.addRing.min + math.random() * (C.addRing.max - C.addRing.min)
    local position = { x = center.x + math.cos(angle) * r, y = center.y + math.sin(angle) * r, z = center.z + 0.4 }
    local yaw = math.deg(math.atan(center.y - position.y, center.x - position.x)) - 90
    for i, candidate in ipairs(C.addPool) do
        if not raid.badAdds[i] then
            local definition = {
                position = position, yaw = yaw, bucket = inst.bucket,
                aiMode = Open77.npcs.ai.native, damagePolicy = Open77.npcs.damage.mortal,
                streamingRadius = 200, persistent = false, despawnWhenUnobserved = false,
                -- their hits on the operators are server-owned: reported by the client that
                -- owns them (client/core/raid.lua) and applied below, like an authored mission's
                loadout = { combat = { group = ADD_GROUP, acquirePlayers = true, authoritativePlayerHits = true } },
                behavior = { hitPricing = "platform", aiEnabled = true, combatEnabled = true },
            }
            if candidate.record then definition.record = candidate.record else definition.template = candidate.template end
            local ok, id = pcall(Open77.npcs.create, definition)
            if ok and id then
                raid.adds[id] = true
                loop(inst, raid, C.fx.drop, { x = position.x, y = position.y, z = position.z - 0.4 }, C.fx.dropSeconds * 1000)
                -- straight at an operator: they arrive shooting
                local targets = {}
                for _, member in ipairs(inst.members) do if alive(member) then targets[#targets + 1] = member end end
                if #targets > 0 and type(Open77.npcs.tasks) == "table" and type(Open77.npcs.tasks.attack) == "function" then
                    pcall(Open77.npcs.tasks.attack, id, { playerId = targets[math.random(#targets)] }, { reacquireMs = 4000 })
                end
                return id
            end
            raid.badAdds[i] = true
            LightRP.log("raid %s: reinforcement %s refused (%s)", inst.id, tostring(candidate.record or candidate.template), tostring(id))
        end
    end
end

local function wave(inst, raid, threshold)
    local s = scaling(inst)
    local count = s.adds + s.addsPerOperator * math.max(0, #inst.members - 1)
    local center = raid.state and raid.state.position or Missions.point(POINT).arena
    local spawned = 0
    for _ = 1, count do
        local live = 0
        for id in pairs(raid.adds) do if addAlive(id) then live = live + 1 end end
        if live >= C.maxAdds then break end
        if spawnAdd(inst, raid, center) then spawned = spawned + 1 end
    end
    raid.waves = raid.waves + 1
    -- the count the announcement pushes includes this drop
    local live = 0
    for id in pairs(raid.adds) do if addAlive(id) then live = live + 1 end end
    raid.addCount = live
    raid.resupplyNow = true -- every operator topped up with the drop (fightTick)
    announce(inst, raid, "REINFORCEMENTS", string.format("Militech drops %d operators into the arena (%d%% core integrity).", spawned, threshold), "warning", "raid_wave")
end

local function clearAdds(raid)
    for id in pairs(raid.adds) do pcall(Open77.npcs.remove, id) end
    raid.adds = {}
end

-- ---------------------------------------------------------------------------
-- The loadout: native weapons for the raid only (LightRP's armament stands
-- aside while Missions.handlesLoadout says so, and projects the character's
-- own weapons again when the mission is over).

local waiting = {} -- "player:request" -> result
AddEventHandler("open77:weapons:completed", function(player, request, _, accepted, reason, result)
    waiting[tostring(player) .. ":" .. tostring(request)] = { accepted = accepted, reason = reason, result = result }
end)
local function weapons(player, method, ...)
    if type(Open77.weapons) ~= "table" or type(Open77.weapons[method]) ~= "function" then return nil, "weapons_api_unavailable" end
    local ok, request, why = pcall(Open77.weapons[method], player, ...)
    if not ok or not request then return nil, ok and why or request end
    local key = tostring(player) .. ":" .. tostring(request)
    local deadline = now() + 10000
    while not waiting[key] and now() < deadline do Wait(50) end
    local done = waiting[key]
    waiting[key] = nil
    if not done then return nil, "request_timeout" end
    if not done.accepted then return nil, done.reason end
    return done.result or true
end
local function recordOf(snapshot, slot)
    for _, row in ipairs(type(snapshot) == "table" and (snapshot.slots or snapshot) or {}) do
        if type(row) == "table" and tonumber(row.slot) == slot then return row.record end
    end
end
-- The kit is in hand when slot 1 holds its primary with rounds in it (a record
-- without ammunition is what a refused draw leaves behind).
local function armed(snapshot, kit)
    for _, row in ipairs(type(snapshot) == "table" and (snapshot.slots or snapshot) or {}) do
        if type(row) == "table" and tonumber(row.slot) == 1 then
            local a = type(row.ammo) == "table" and row.ammo or {}
            local rounds = tonumber(a.total) or ((tonumber(a.reserve) or 0) + (tonumber(a.magazine) or 0))
            return row.record == kit.primary and rounds > 0
        end
    end
    return false
end
local function capacityOf(snapshot, slot)
    for _, row in ipairs(type(snapshot) == "table" and (snapshot.slots or snapshot) or {}) do
        if type(row) == "table" and tonumber(row.slot) == slot and type(row.ammo) == "table" then return tonumber(row.ammo.capacity) end
    end
end

-- The kit's reserve back to full on the weapons that ran low (all of them when forced).
local function resupply(inst, raid, id, force)
    local kit = kits[raid.loadouts[id]] or C.loadouts[1]
    raid.equipping = raid.equipping or {}
    if raid.equipping[id] then return end
    raid.equipping[id] = true
    CreateThread(function()
        local snapshot = weapons(id, "requestSnapshot")
        if type(snapshot) == "table" and not armed(snapshot, kit) then
            raid.equipping[id] = nil
            LightRP.log("raid %s: %s has no kit weapon in hand, issuing it again", inst.id, name(id))
            return raid.reissue(id)
        end
        local topped = false
        for _, row in ipairs(type(snapshot) == "table" and (snapshot.slots or snapshot) or {}) do
            local slot = type(row) == "table" and tonumber(row.slot)
            local full = slot and kit.reserve[slot]
            local reserve = full and type(row.ammo) == "table" and tonumber(row.ammo.reserve)
            if reserve and reserve < full * (force and 1 or C.resupply.below) then
                local ok, why = weapons(id, "setAmmo", slot, { reserve = full })
                -- the magazine moved under the write (the player was firing): once more
                if not ok and why == "ammo_update_rejected" then Wait(1500); ok, why = weapons(id, "setAmmo", slot, { reserve = full }) end
                if ok then topped = true
                else LightRP.log("raid %s: resupply for %s slot %d refused (%s)", inst.id, name(id), slot, tostring(why)) end
            end
        end
        raid.equipping[id] = nil
        if topped and raids[inst.id] == raid then
            LightRP.notice(id, { kind = "info", title = "Resupply", body = "Fresh ammunition from the Militech drop." })
        end
    end)
end
local equip
local function resupplyAll(inst, raid, force)
    for _, id in ipairs(inst.members) do
        if alive(id) and not raid.out[id] then resupply(inst, raid, id, force) end
    end
end

function equip(inst, raid, id)
    raid.equipping = raid.equipping or {}
    raid.again = raid.again or {}
    -- one sequence at a time per operator; a request during one runs again after it
    if raid.equipping[id] then raid.again[id] = true; return end
    raid.equipping[id] = true
    raid.again[id] = nil
    local kit = kits[raid.loadouts[id]] or C.loadouts[1]
    CreateThread(function()
        local function step(method, ...)
            local result, why = weapons(id, method, ...)
            if not result and why ~= "weapon_slot_empty" then LightRP.log("raid %s: loadout %s for %s: %s refused (%s)", inst.id, kit.id, name(id), method, tostring(why)) end
            return result
        end
        -- A client still loading answers nothing (request_timeout) and then refuses
        -- (queue_full): the sequence is retried until the snapshot shows the kit.
        -- the ready button hands the mouse back to the game: let it settle before drawing
        Wait(1500)
        for attempt = 1, 6 do
            if raids[inst.id] ~= raid or not alive(id) then break end
            step("clear")
            step("assign", kit.primary, 1, { active = true, addToInventory = true })
            step("assign", kit.secondary, 2, { active = false, addToInventory = true })
            for slot = 1, 2 do
                step("setAmmo", slot, { reserve = kit.reserve[slot], activate = slot == 1 })
                local snapshot = step("requestSnapshot")
                local capacity = capacityOf(snapshot, slot)
                if capacity then step("setAmmo", slot, { magazine = capacity, activate = slot == 1 }) end
            end
            step("setActive", 1)
            local check = weapons(id, "requestSnapshot")
            if armed(check, kit) then break end
            if raid.again[id] then break end
            LightRP.log("raid %s: loadout %s for %s not in hand (attempt %d), retrying", inst.id, kit.id, name(id), attempt)
            Wait(3000)
        end
        raid.equipping[id] = nil
        if raid.again[id] and raids[inst.id] == raid then equip(inst, raid, id) end
    end)
end

-- Scripted strikes: telegraphed on the ground (client/core/raid.lua: 3D markers
-- and the game's indicator), then a replicated blast that hurts whoever is still in it.
local function strike(inst, raid, spots, radius, damage, telegraphMs, kind)
    local list = {}
    for _, p in ipairs(spots) do list[#list + 1] = { x = p.x, y = p.y, z = p.z, radius = radius, delayMs = telegraphMs, kind = kind } end
    push(inst, raid, { strikes = list, sound = kind == "purge" and "raid_phase" or "raid_wave" })
    local fight = raid.fightStarted
    CreateThread(function()
        Wait(telegraphMs)
        if raids[inst.id] ~= raid or raid.phase ~= "fight" or raid.fightStarted ~= fight then return end
        for _, p in ipairs(list) do
            local ok, why = pcall(Open77.effects.explosion, { x = p.x, y = p.y, z = p.z }, { radius = radius, damage = damage, force = 1.5,
                vfx = (kind == "purge" and C.purge.vfx or C.barrage.vfx) or "explosion.frag", bucket = inst.bucket })
            if not ok then LightRP.log("raid %s: %s strike failed (%s)", inst.id, kind, tostring(why)) end
        end
    end)
end

local function pace(raid)
    local p = C.pace[raid.state and raid.state.phase or "armored"] or 1
    if raid.enraged then p = p * C.pace.enraged end
    return p
end

local function attacks(inst, raid)
    local t, b, d = now(), raid.state, inst.difficulty
    local center = b and b.position
    if not center then return end
    local positions = {}
    for _, id in ipairs(inst.members) do
        local p = alive(id) and not raid.out[id] and Open77.players.position(id)
        if p then positions[#positions + 1] = p end
    end
    if #positions == 0 then return end
    -- purge: someone is hugging the machine
    if t >= (raid.nextPurge or 0) then
        for _, p in ipairs(positions) do
            if (p.x - center.x) ^ 2 + (p.y - center.y) ^ 2 <= C.purge.trigger ^ 2 then
                strike(inst, raid, { center }, C.purge.radius, C.purge.damage[d] or 30, C.purge.telegraphMs, "purge")
                raid.nextPurge = t + C.purge.every * 1000 * pace(raid)
                break
            end
        end
    end
    -- barrage on every standing operator, and a few spots around them
    if t >= (raid.nextBarrage or 0) then
        local spots = {}
        for _, p in ipairs(positions) do spots[#spots + 1] = p end
        for _ = 1, C.barrage.extra[d] or 0 do
            local p = positions[math.random(#positions)]
            local a, r = math.random() * math.pi * 2, math.random() * C.barrage.scatter
            spots[#spots + 1] = { x = p.x + math.cos(a) * r, y = p.y + math.sin(a) * r, z = p.z }
        end
        strike(inst, raid, spots, C.barrage.radius, C.barrage.damage[d] or 25, C.barrage.telegraphMs, "barrage")
        raid.nextBarrage = t + (C.barrage.every[d] or 12) * 1000 * pace(raid)
    end
end

-- ---------------------------------------------------------------------------
-- The phases

local function beginFight(inst, raid)
    local _, health, damage = scaling(inst)
    boss("setDifficulty", raid.bossId, { healthMultiplier = health, damageMultiplier = damage })
    boss("setDamagePolicy", raid.bossId, Open77.npcs.damage.mortal)
    boss("setAIEnabled", raid.bossId, true)
    boss("setCombatEnabled", raid.bossId, true)
    local state = boss("get", raid.bossId)
    if state then LightRP.log("raid %s: boss %s ai=%s combat=%s policy=%s at %.1f %.1f %.1f", inst.id, tostring(state.id),
        tostring(state.aiEnabled), tostring(state.combatEnabled), tostring(state.damagePolicy),
        state.position.x, state.position.y, state.position.z) end
    raid.phase, raid.fightStarted = "fight", now()
    raid.nextLockOn = now() + 25000
    raid.nextBarrage, raid.nextPurge = now() + 6000, now() + 4000
    raid.nextResupply = now() + C.resupply.every * 1000
    LightRP.log("raid %s: fight (health x%.2f, damage x%.2f, %d operator(s))", inst.id, health, damage, #inst.members)
    announce(inst, raid, "ENGAGE", "Strip its armor, then go for the core.", "danger", "raid_reveal")
end

-- The boss is in the arena: freeze it for the cinematic, then fight.
local function bossPlaced(inst, raid, state)
    raid.bossId, raid.state = state.id, state
    -- passive for the cinematic: combat off and invulnerable. The native AI stays
    -- on (switching it off and on again left the machine standing still).
    boss("setCombatEnabled", raid.bossId, false)
    boss("setDamagePolicy", raid.bossId, Open77.npcs.damage.invulnerable)
    raid.phase, raid.introEnds = "intro", now() + C.introSeconds * 1000
    local d = Missions.difficulty(inst)
    push(inst, raid, { intro = { boss = state.position, arena = Missions.point(POINT).arena, entry = Missions.point(POINT).position,
        durationMs = C.introSeconds * 1000,
        difficulty = d.label, operators = #inst.members }, sound = "raid_alarm" })
end

local function placeBoss(inst, raid)
    raid.phase = "placing"
    for _, id in ipairs(inst.members) do if not raid.ready[id] and raid.loaded[id] then equip(inst, raid, id) end end
    push(inst, raid)
    local point = Missions.point(POINT)
    if point.boss then
        -- its stand in the arena, facing the operators' spawn
        local b, a = point.boss, point.arena
        local yaw = math.deg(math.atan(a.y - b.y, a.x - b.x)) - 90
        local state, err = boss("create", { profile = "chimera", position = { x = b.x, y = b.y, z = b.z }, yaw = yaw,
            bucket = inst.bucket, maxHealth = 100 })
        if state then return bossPlaced(inst, raid, state) end
        LightRP.log("raid %s: boss refused at its stand (%s), trying the placement probe", inst.id, tostring(err))
    end
    -- the provider's placement probe: a level, unobstructed spot ~18 m from the host
    local host
    for _, id in ipairs(inst.members) do if alive(id) then host = id break end end
    local request = host and boss("spawn", host, { profile = "chimera", maxHealth = 100 })
    raid.spawnRequest, raid.spawnSince = request, now()
    if not request then raid.spawnRequest = false end
end

local function fallbackBoss(inst, raid, why)
    local arena = Missions.point(POINT).arena
    LightRP.log("raid %s: placement probe failed (%s), boss placed 16 m from the arena centre", inst.id, tostring(why))
    local state, err = boss("create", { profile = "chimera", position = { x = arena.x, y = arena.y + 16, z = arena.z },
        yaw = 180, bucket = inst.bucket, maxHealth = 100 })
    if state then bossPlaced(inst, raid, state)
    else Missions.fail(inst.id, "The Chimera could not be deployed (" .. tostring(err) .. ").") end
end

local function lockOn(inst, raid)
    local candidates = {}
    for _, id in ipairs(inst.members) do if alive(id) then candidates[#candidates + 1] = id end end
    if #candidates < 2 then raid.nextLockOn = now() + 30000; return end -- alone: it is always after you anyway
    local target = candidates[math.random(#candidates)]
    local ok = boss("setTarget", raid.bossId, target)
    if ok then
        raid.lockOn = { player = target, ends = now() + 9000 }
        announce(inst, raid, "TARGET LOCK", "The Chimera locks on " .. name(target) .. ". Break line of sight.", "danger", "raid_phase")
    end
    raid.nextLockOn = now() + 22000 + math.random(0, 10000)
end

local PHASE_TEXT = {
    exposed = { "ARMOR BREACHED", "Its plating is gone. Hit the exposed parts." },
    gas = { "COOLANT VENTING", "The core vents toxic gas. Keep moving." },
    core = { "CORE EXPOSED", "Pour everything into the core." },
}

local function fightTick(inst, raid)
    local s = scaling(inst)
    local state = boss("get", raid.bossId)
    if not state then
        -- the provider recreates the boss on some transitions: find ours again
        local list = boss("list", { bucket = inst.bucket })
        state = type(list) == "table" and list[1] or nil
        if state then raid.bossId = state.id end
    end
    if not state then return Missions.fail(inst.id, "The Chimera left the arena.") end
    raid.state = state
    if state.alive ~= false and (state.aiEnabled == false or state.combatEnabled == false) then
        LightRP.log("raid %s: boss ai=%s combat=%s during the fight, switching them on", inst.id, tostring(state.aiEnabled), tostring(state.combatEnabled))
        boss("setAIEnabled", raid.bossId, true)
        boss("setCombatEnabled", raid.bossId, true)
    end
    if state.alive == false or (tonumber(state.health) or 1) <= 0 then
        raid.phase, raid.victoryAt = "victory", now() + C.victorySeconds * 1000
        clearAdds(raid)
        clearLoops(raid)
        fx(inst, C.fx.death, state.position, 1.5)
        for _, effect in ipairs(C.fx.wreck) do loop(inst, raid, effect, state.position, (C.victorySeconds + 2) * 1000) end
        LightRP.log("raid %s: Chimera down after %ds", inst.id, math.floor((now() - raid.fightStarted) / 1000))
        return announce(inst, raid, "CHIMERA DOWN", "The war machine is scrap. Payment incoming.", "success", "raid_victory")
    end
    -- the repair cycle: no damage gets through. Said on screen, and cut to the raid's length.
    if state.repairing and not raid.repairEnds then
        local seconds = C.repairSeconds[inst.difficulty] or 20
        raid.repairEnds = now() + seconds * 1000
        LightRP.log("raid %s: repair cycle (%ds)", inst.id, seconds)
        announce(inst, raid, "REPAIR CYCLE", string.format("The Chimera is shielded while it repairs (%ds). Deal with the reinforcements.", seconds), "warning", "raid_phase")
    elseif state.repairing and now() >= raid.repairEnds and not raid.repairCut then
        -- setting its health (unchanged) ends the provider's repair and restores the damage policy
        raid.repairCut = true
        local _, why = boss("setHealth", raid.bossId, state.health)
        if why then LightRP.log("raid %s: ending the repair refused (%s)", inst.id, tostring(why)) end
    elseif not state.repairing and raid.repairEnds then
        raid.repairEnds, raid.repairCut = nil, nil
        announce(inst, raid, "SHIELD DOWN", "The repair is over: open fire.", "danger", "raid_reveal")
    end
    -- phases and reinforcements
    if state.phase ~= raid.lastPhase then
        local text = PHASE_TEXT[state.phase]
        if text and raid.lastPhase then
            announce(inst, raid, text[1], text[2], "warning", "raid_phase")
            fx(inst, C.fx.phase, state.position, 2.2)
        end
        raid.lastPhase = state.phase
    end
    local percent = tonumber(state.healthPercent) or 100
    local thresholds = s.waves or {}
    while raid.waves < #thresholds and percent <= thresholds[raid.waves + 1] do wave(inst, raid, thresholds[raid.waves + 1]) end
    -- enrage
    if not raid.enraged and now() - raid.fightStarted >= s.enrageMinutes * 60000 then
        raid.enraged = true
        local _, health, damage = scaling(inst)
        boss("setDifficulty", raid.bossId, { healthMultiplier = health, damageMultiplier = damage * s.enrageDamage })
        announce(inst, raid, "CORE OVERCLOCK", "The Chimera is enraged: its damage surges. Finish it.", "danger", "raid_enrage")
        fx(inst, C.fx.phase, state.position, 2.2)
        raid.aura = loop(inst, raid, C.fx.enraged, { x = state.position.x, y = state.position.y, z = state.position.z + 1.8 })
    elseif raid.aura then
        pcall(Open77.effects.update, raid.aura, { position = { x = state.position.x, y = state.position.y, z = state.position.z + 1.8 } })
    end
    attacks(inst, raid)
    if (raid.bodyDamage or 0) > 0 then
        local amount = raid.bodyDamage
        raid.bodyDamage = 0
        if not state.repairing then
            local _, why = boss("applyDamage", raid.bossId, amount)
            if why then LightRP.log("raid %s: body damage refused (%s)", inst.id, tostring(why)) end
        end
    end
    if raid.resupplyNow or now() >= (raid.nextResupply or math.huge) then
        raid.nextResupply = now() + C.resupply.every * 1000
        resupplyAll(inst, raid, raid.resupplyNow == true)
        raid.resupplyNow = nil
    end
    -- target lock
    if raid.lockOn and now() >= raid.lockOn.ends then
        boss("setTarget", raid.bossId, nil)
        raid.lockOn = nil
    elseif not raid.lockOn and raid.nextLockOn and now() >= raid.nextLockOn then
        lockOn(inst, raid)
    end
    -- reinforcements alive
    local live = 0
    for id in pairs(raid.adds) do if addAlive(id) then live = live + 1 else raid.adds[id] = nil; pcall(Open77.npcs.remove, id) end end
    raid.addCount = live
end

-- Respawns from the team pool, and the wipe.
local function lifeTick(inst, raid)
    local t, start = now(), Missions.point(POINT).start
    for id, at in pairs(raid.respawns) do
        if t >= at then
            raid.respawns[id] = nil
            local spot = start[math.random(#start)]
            local ok, why = Open77.players.respawn(id, { position = { x = spot.x, y = spot.y, z = spot.z }, heading = spot.heading or 0,
                bucket = inst.bucket, health = LightRpConfig.spawn and LightRpConfig.spawn.health or nil })
            if not ok then LightRP.log("raid %s: respawn of %s refused (%s)", inst.id, name(id), tostring(why)) end
        end
    end
    if raid.phase ~= "fight" then return end
    -- a wipe: nobody standing and nobody coming back (a pending respawn keeps the raid alive)
    local standing = 0
    for _, id in ipairs(inst.members) do if (alive(id) and not raid.out[id]) or raid.respawns[id] then standing = standing + 1 end end
    if standing == 0 and #inst.members > 0 then
        raid.phase, raid.wipeAt = "wipe", now() + 7000
        clearAdds(raid)
        boss("setCombatEnabled", raid.bossId, false)
        announce(inst, raid, "SQUAD WIPED", "Every operator is down. The Chimera holds the arena.", "danger", "raid_wipe")
    end
end

-- ---------------------------------------------------------------------------
-- The mission script

Missions.register(POINT, {
    onStart = function(inst)
        local s = scaling(inst)
        local raid = { phase = "ready", ready = {}, down = {}, out = {}, respawns = {}, adds = {}, badAdds = {}, loops = {},
            waves = 0, lives = s.lives, readyEnds = now() + C.readySeconds * 1000, loadouts = {}, loaded = {}, equipping = {},
            loadDeadline = now() + C.loadWaitSeconds * 1000 }
        raid.reissue = function(id) equip(inst, raid, id) end
        raids[inst.id] = raid
        inst.loadout = true
        for _, id in ipairs(inst.members) do raid.loadouts[id] = C.loadouts[1].id end
        -- the armament stands aside: its client stops gating the attack (armament.lua standAside)
        if LightRP.armament and type(LightRP.armament.push) == "function" then for _, id in ipairs(inst.members) do pcall(LightRP.armament.push, id) end end
        LightRP.log("raid %s: ready check for %d operator(s), %s", inst.id, #inst.members, inst.difficulty)
        push(inst, raid, { sound = "raid_title" })
    end,
    onTick = function(inst)
        local raid = raids[inst.id]
        if not raid then return end
        local t = now()
        if raid.phase == "ready" then
            local loading = false
            for _, id in ipairs(inst.members) do if not raid.loaded[id] then loading = true end end
            if loading and t >= raid.readyEnds and t < raid.loadDeadline then raid.readyEnds = t + 1000 end
            if t >= raid.readyEnds then
                raid.phase, raid.launchAt = "launch", t + C.launchSeconds * 1000
                push(inst, raid, { sound = "raid_tick" })
            else push(inst, raid) end
        elseif raid.phase == "launch" then
            if t >= raid.launchAt then placeBoss(inst, raid) else push(inst, raid, { sound = "raid_tick" }) end
        elseif raid.phase == "placing" then
            if raid.spawnRequest == false then return fallbackBoss(inst, raid, "no host") end
            local result = boss("result", raid.spawnRequest)
            if result and result.status == "created" then
                local state = boss("get", result.id)
                if state then bossPlaced(inst, raid, state) else fallbackBoss(inst, raid, "created but unreadable") end
            elseif (result and result.status == "failed") or t - raid.spawnSince > 7000 then
                fallbackBoss(inst, raid, result and result.reason or "timeout")
            end
        elseif raid.phase == "intro" then
            if t >= raid.introEnds then beginFight(inst, raid) end
            push(inst, raid)
        elseif raid.phase == "fight" then
            fightTick(inst, raid)
            if raid.phase == "fight" then push(inst, raid) end
        elseif raid.phase == "victory" then
            if t >= raid.victoryAt then Missions.complete(inst.id) else push(inst, raid) end
        elseif raid.phase == "wipe" then
            if t >= raid.wipeAt then Missions.fail(inst.id, "The squad was wiped out by the Chimera.") end
        end
        if raids[inst.id] then lifeTick(inst, raid) end
    end,
    onLifeState = function(inst, id, phase)
        local raid = raids[inst.id]
        if not raid then return end
        if phase == "alive" or phase == "recovering" then
            if raid.down[id] and phase == "alive" then
                -- back from a respawn: the loadout again, once the body is settled
                CreateThread(function() Wait(1500); if raids[inst.id] == raid then equip(inst, raid, id) end end)
            end
            raid.down[id] = nil
            return
        end
        if raid.down[id] then return end
        raid.down[id] = true
        local s = scaling(inst)
        if raid.phase ~= "fight" then
            -- before the fight a death costs nothing
            raid.respawns[id] = now() + 3000
        elseif s.respawnSeconds and raid.lives > 0 then
            if s.lives < 99 then raid.lives = raid.lives - 1 end
            raid.respawns[id] = now() + s.respawnSeconds * 1000
            announce(inst, raid, "OPERATOR DOWN", string.format("%s is down. Back in %d s%s.", name(id), s.respawnSeconds,
                s.lives < 99 and string.format(" (%d respawn%s left)", raid.lives, raid.lives == 1 and "" or "s") or ""), "warning")
        else
            raid.out[id] = true
            announce(inst, raid, "OPERATOR LOST", name(id) .. " is out of the fight.", "danger")
        end
        Missions.pushSquad(inst)
    end,
    onLeave = function(inst, id)
        local raid = raids[inst.id]
        if not raid then return end
        raid.ready[id], raid.down[id], raid.out[id], raid.respawns[id] = nil, nil, nil, nil
        TriggerClientEvent(NET, id, { instance = inst.id, phase = "ended" })
        if raid.lockOn and raid.lockOn.player == id then boss("setTarget", raid.bossId, nil); raid.lockOn = nil end
    end,
    onEnd = function(inst, success)
        local raid = raids[inst.id]
        raids[inst.id] = nil
        if not raid then return end
        clearAdds(raid)
        clearLoops(raid)
        if raid.bossId then boss("remove", raid.bossId) end
        for _, id in ipairs(inst.members) do
            TriggerClientEvent(NET, id, { instance = inst.id, phase = "ended", result = success and "victory" or "failed" })
        end
    end,
})

-- Ready: the key (client/core/raid.lua) or the page's READY button; a kit
-- picked in the ready check (page action raid.loadout) is handed out at once.
local function ready(id)
    local inst = id and Missions.instanceOf(id)
    local raid = inst and raids[inst.id]
    if not raid or raid.phase ~= "ready" or raid.ready[id] then return end
    if not raid.loaded[id] then
        LightRP.notice(id, { kind = "error", title = "Raid", body = "The arena is still loading on your side." })
        return
    end
    raid.ready[id] = true
    equip(inst, raid, id)
    local all = true
    for _, member in ipairs(inst.members) do if not raid.ready[member] then all = false end end
    if all then raid.phase, raid.launchAt = "launch", now() + C.launchSeconds * 1000 end
    push(inst, raid, { sound = all and "raid_tick" or "raid_ready" })
end
RegisterNetEvent("op77_lightrp:raid:ready", function() ready(tonumber(source)) end)
LightRP.action("raid.ready", function(id) ready(id) end)
LightRP.action("raid.loadout", function(id, payload)
    local inst = Missions.instanceOf(id)
    local raid = inst and raids[inst.id]
    local kit = type(payload) == "table" and kits[payload.id]
    if not raid or raid.phase ~= "ready" or not kit then return end
    raid.loadouts[id] = kit.id
    if raid.ready[id] then equip(inst, raid, id) end
    TriggerClientEvent(NET, id, view(inst, raid, id))
end)

-- The client reports once its loading screen is gone and its body stands in the
-- arena (client/core/raid.lua); the server checks the position itself.
RegisterNetEvent("op77_lightrp:raid:loaded", function()
    local id = tonumber(source)
    local inst = id and Missions.instanceOf(id)
    local raid = inst and raids[inst.id]
    if not raid or raid.loaded[id] then return end
    local p, a = Open77.players.position(id), Missions.point(POINT).arena
    if not p or (p.x - a.x) ^ 2 + (p.y - a.y) ^ 2 > C.loadRadius ^ 2 then return end
    raid.loaded[id] = true
    LightRP.log("raid %s: %s loaded the arena", inst.id, name(id))
    -- past the ready check: the kit is handed out on arrival
    if raid.phase ~= "ready" and not raid.equipping[id] then equip(inst, raid, id) end
    push(inst, raid)
end)

-- A shot of the local player hit the Chimera (open77:npcHit on the shooter's client,
-- client/core/raid.lua). The engine prices its body near zero; the raid prices it
-- (LightRpRaid.bodyHits), within a per-operator budget, and applies it in fightTick.
RegisterNetEvent("op77_lightrp:raid:hit", function(npcId)
    local id = tonumber(source)
    local inst = id and Missions.instanceOf(id)
    local raid = inst and raids[inst.id]
    if not raid or raid.phase ~= "fight" or not raid.bossId or tostring(npcId) ~= tostring(raid.bossId) then return end
    local state = raid.state
    if not state or state.repairing or not alive(id) or raid.out[id] then return end
    local B = C.bodyHits
    local p, b = Open77.players.position(id), state.position
    if not p or not b or (p.x - b.x) ^ 2 + (p.y - b.y) ^ 2 > B.range ^ 2 then return end
    raid.hitBudget = raid.hitBudget or {}
    local t = now()
    local budget = raid.hitBudget[id] or { tokens = B.perSecond, at = t }
    budget.tokens = math.min(B.perSecond, budget.tokens + (t - budget.at) / 1000 * B.perSecond)
    budget.at = t
    raid.hitBudget[id] = budget
    local pct = math.min(B.perHit[raid.loadouts[id] or ""] or B.perHit.assault, budget.tokens)
    if pct <= 0 then return end
    budget.tokens = budget.tokens - pct
    local _, health = scaling(inst)
    if state.phase == "armored" then pct = pct * B.armored end
    raid.bodyDamage = (raid.bodyDamage or 0) + (tonumber(state.maxHealth) or 100) * pct / 100 / health
end)

-- A late arrival (reconnect into the page, a resource restart) asks for the state.
-- A reinforcement hit an operator (the boss's own hits are applied by open77_chimera).
-- Same checks and caps as an authored mission (Engine.applyNpcHit): the HUD health is
-- the server's, and nothing else moved it.
local function reinforcementHit(reporter, victimId, npcId, epoch, amount)
    local victim, damage, reportedEpoch = tonumber(victimId), tonumber(amount), tonumber(epoch)
    if not victim or not damage or damage ~= damage or damage <= 0 or not reportedEpoch then return false, "invalid" end
    local inst = Missions.instanceOf(victim)
    local raid = inst and raids[inst.id]
    if not raid or raid.phase ~= "fight" then return false, "no_raid" end
    local key
    for id in pairs(raid.adds) do if tostring(id) == tostring(npcId) then key = id end end
    if key == nil then return false, "not_a_reinforcement" end
    local engine = LightRP.missionEngine
    if not engine or type(engine.applyNpcHit) ~= "function" then return false, "engine_missing" end
    return engine.applyNpcHit(inst, reporter, victim, key, reportedEpoch, damage)
end
LightRP.raidReinforcementHit = reinforcementHit
RegisterNetEvent("op77_lightrp:raid:npcHit", function(victimId, npcId, epoch, amount)
    local reporter = tonumber(source)
    if reporter and reporter > 0 then reinforcementHit(reporter, victimId, npcId, epoch, amount) end
end)

RegisterNetEvent("op77_lightrp:raid:hello", function()
    local id = tonumber(source)
    local inst = id and Missions.instanceOf(id)
    local raid = inst and raids[inst.id]
    if raid then TriggerClientEvent(NET, id, view(inst, raid, id)) end
end)

-- Staff tests: /raid.skip <playerId> jumps the ready check, /raid.boss <playerId> <percent> sets the boss health.
LightRP.command("raid.skip", { restricted = true, usage = "/raid.skip <playerId>" }, function(_, args)
    local inst = Missions.instanceOf(tonumber(args[1]) or -1)
    local raid = inst and raids[inst.id]
    if not raid or raid.phase ~= "ready" then return false, "No raid in its ready check for that player." end
    raid.phase, raid.launchAt = "launch", now() + C.launchSeconds * 1000
    return true, "Launching."
end)
LightRP.command("raid.state", { restricted = true, usage = "/raid.state <playerId>" }, function(_, args)
    local inst = Missions.instanceOf(tonumber(args[1]) or -1)
    local raid = inst and raids[inst.id]
    if not raid then return false, "No raid for that player." end
    local s = raid.bossId and boss("get", raid.bossId)
    if not s then return true, string.format("%s phase=%s, no boss", inst.id, raid.phase) end
    return true, string.format("%s phase=%s boss=%s hp=%.1f%% %s ai=%s combat=%s policy=%s target=%s/%s authority=%s at %.1f %.1f %.1f",
        inst.id, raid.phase, s.id, s.healthPercent or -1, tostring(s.phase), tostring(s.aiEnabled), tostring(s.combatEnabled),
        tostring(s.damagePolicy), tostring(s.target and s.target.mode), tostring(s.target and s.target.actualPlayerId),
        tostring(s.authority and s.authority.playerId), s.position.x, s.position.y, s.position.z)
end)
LightRP.command("raid.boss", { restricted = true, usage = "/raid.boss <playerId> <percent>" }, function(_, args)
    local inst = Missions.instanceOf(tonumber(args[1]) or -1)
    local raid = inst and raids[inst.id]
    local percent = tonumber(args[2])
    if not raid or not raid.bossId or not percent then return false, "usage: /raid.boss <playerId> <percent>" end
    local state = boss("setHealth", raid.bossId, math.max(0, math.min(100, percent)))
    return state ~= nil, state and string.format("Chimera at %d%%.", percent) or "refused"
end)
