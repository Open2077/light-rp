-- Authored missions: the format (shared/mission_defs.lua), the editor's storage
-- and protocol (server/modules/mission_editor.lua) and the runtime
-- (server/modules/mission_engine.lua) on top of the board system, with the host
-- stubbed. Covers: validation errors, publish -> board point, test runs (no
-- payout), Elimination (start spawns, required checkpoint waking its spawn
-- points, victory), the perimeter (warning, death after the delay), team
-- respawns, the wipe, and Survival (waves in order, intermission, victory).
local clock = 0
local damaged = {}
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
local function encode(x)
    if type(x) == "table" then
        local parts = {}
        local n = #x
        if n > 0 then for i = 1, n do parts[i] = encode(x[i]) end return "[" .. table.concat(parts, ",") .. "]" end
        for k, y in pairs(x) do parts[#parts + 1] = string.format("%q:%s", tostring(k), encode(y)) end
        table.sort(parts)
        return "{" .. table.concat(parts, ",") .. "}"
    end
    if type(x) == "string" then return string.format("%q", x) end
    return tostring(x)
end
local stored = {}
_G.json = { encode = function(v) stored[#stored + 1] = v; return "#" .. #stored end, decode = function(s) return stored[tonumber(s:sub(2))] end }

local positions, buckets, life = {}, {}, {}
local sent, paid, killed, notices, netHandlers = {}, {}, {}, {}, {}
_G.GetPlayers = function() local t = {} for id in pairs(positions) do t[#t + 1] = tostring(id) end table.sort(t) return t end
_G.GetPlayerRoutingBucket = function(id) return buckets[id] or 0 end
_G.SetPlayerRoutingBucket = function(id, b) buckets[id] = b return true end
_G.GetPlayerIdentifier = function(id) return "license:" .. id end
_G.GetPlayerName = function(id) return "P" .. id end
_G.TriggerClientEvent = function(name, target, payload) sent[#sent + 1] = { name = name, target = target, payload = payload } end
_G.RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
_G.AddEventHandler = function() end

local npcs, npcSeq, attacks = {}, 100, 0
local npcCalls = {}
local function called(kind, npcId) for _, c in ipairs(npcCalls) do if c[1] == kind and (not npcId or c[2] == npcId) then return c end end end
_G.Open77 = {
    time = { monotonic = function() return clock / 1000 end },
    acl = { isAllowed = function(id, perm) return id == 1 and perm == "command.lightrp.missions" end },
    npcs = { ai = { native = 2 }, damage = { mortal = 0 },
        create = function(def) npcSeq = npcSeq + 1; npcs[npcSeq] = { def = def, health = 100, position = def.position }; return npcSeq end,
        get = function(id) local n = npcs[id]; return n and { health = n.health, alive = n.health > 0, position = n.position,
            bucket = n.def.bucket, authorityPlayerId = n.owner or 1, authorityEpoch = n.epoch or 4 } end,
        remove = function(id) npcs[id] = nil; return true end,
        setCombatEnabled = function(id, on) npcCalls[#npcCalls + 1] = { "combat", id, on }; return true end,
        setPerceptionEnabled = function(id, on) npcCalls[#npcCalls + 1] = { "perception", id, on }; return true end,
        tasks = { attack = function(id) attacks = attacks + 1; npcCalls[#npcCalls + 1] = { "attack", id }; return true end,
            guard = function(id, p, r) npcCalls[#npcCalls + 1] = { "guard", id, r }; return true end,
            patrol = function(id, route) npcCalls[#npcCalls + 1] = { "patrol", id, #route }; return true end,
            wander = function(id, o) npcCalls[#npcCalls + 1] = { "wander", id, o.radius }; return true end } },
    players = {
        position = function(id) local p = positions[id]; return p and { x = p.x, y = p.y, z = p.z } end,
        get = function(id) return { position = positions[id], health = 100, maxHealth = 100, armor = 0, lifePhase = life[id] or "alive" } end,
        getLifeState = function(id) return { phase = life[id] or "alive", bucket = buckets[id] or 0 } end,
        teleport = function(id, spot, opts)
            return { await = function() buckets[id] = opts.bucket; positions[id] = { x = spot.x, y = spot.y, z = spot.z }; return true end }
        end,
        heal = function() return true end,
        -- like the platform: the phase is dead at once, the event arrives on a later tick
        kill = function(id) killed[#killed + 1] = id; life[id] = "dead"
            CreateThread(function() Wait(); LightRP.eachModule("onLifeState", id, "dead") end)
            return true end,
        setHealth = function() return true end,
        damage = function(id, amount, opts) damaged[#damaged + 1] = { id = id, amount = amount, attacker = opts and opts.attacker }; return true end,
        respawn = function(id, opts)
            if life[id] == "alive" then return false, "invalid_state" end
            -- like the platform: respawnpending now, the new life a second later
            life[id] = "respawnpending"; buckets[id] = opts.bucket
            LightRP.eachModule("onLifeState", id, "respawnpending")
            CreateThread(function()
                local at = clock + 1000
                while clock < at do Wait() end
                life[id] = "alive"
                positions[id] = { x = opts.position.x, y = opts.position.y, z = opts.position.z }
                LightRP.eachModule("onLifeState", id, "alive")
            end)
            return true end,
    },
}
_G.LightRpEvents = { net = { mission = "op77_lightrp:mission" } }
_G.LightRpConfig = { spawn = { health = 100 } }

local modules, actions, commands, providers = {}, {}, {}, {}
local chars = {}
local dbRows = {}
_G.LightRP = {
    nowMs = function() return clock end, log = function(fmt, ...) if os.getenv("MISSION_TEST_LOG") then print(string.format(fmt, ...)) end end,
    module = function(name, def) def.name = name; modules[#modules + 1] = def; LightRP[name] = LightRP[name] or def; return def end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if m[hook] then m[hook](...) end end end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    stateProvider = function(key, fn) providers[key] = fn end,
    state = function() end, result = function() end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, body = n.body } end,
    dialog = function(id, kind, payload) payload.kind = kind end,
    interaction = function() end, removeInteraction = function() end,
    characters = {
        isRegistered = function(id) return chars[id] ~= nil end,
        displayName = function(id) return chars[id] or ("P" .. id) end,
        get = function(id) return chars[id] and { status = "active", identifier = "id-" .. id, key = "default" } end,
    },
    money = { addBank = function(id, amount) paid[id] = (paid[id] or 0) + amount; return true end, format = function(n) return "$" .. n end },
    db = { ready = false, schema = function() end, single = function() end,
        read = function(sql, params)
            if sql:find("UUID") then return true, { { id = "uuid-" .. (#dbRows + 1) } } end
            if sql:find("FROM lightrp_mission_defs") then return true, dbRows end
            return true, {}
        end,
        run = function(sql, params)
            if sql:find("^INSERT INTO lightrp_mission_defs") then dbRows[#dbRows + 1] = { id = params[1], definition = params[2], revision = params[3], deleted = 0 } end
            if sql:find("^UPDATE lightrp_mission_defs") then
                for _, r in ipairs(dbRows) do if r.id == params[5] and r.revision == params[6] then r.definition, r.revision, r.deleted = params[1], params[2], params[3]; return true, 1 end end
                return true, 0
            end
            return true, 1
        end },
}

dofile("shared/safezones.lua")
dofile("shared/mission_defs.lua")
dofile("server/config/missions.lua")
dofile("server/modules/parties.lua")
dofile("server/modules/missions.lua")
dofile("server/modules/mission_engine.lua")
dofile("server/modules/mission_editor.lua")
local D, Missions = LightRpMissionDefs, LightRP.missions

local function noticed(title) for i = #notices, 1, -1 do if notices[i].title == title then return notices[i] end end end
local function request(player, operation, payload)
    payload = payload or {}
    payload.request, payload.operation = "r" .. (#sent + 1), operation
    _G.source = player
    netHandlers["op77_lightrp:missioneditor"](payload)
    clock = clock + 200
    local reply = sent[#sent].payload
    assert(reply.kind == "response" and reply.request == payload.request)
    return reply
end

-- ── the format ──────────────────────────────────────────────────────────────
local O = { x = 100, y = 200, z = 10 }
local function base(kind)
    return { title = "Warehouse sweep", description = "", location = "Kabuki", type = kind or "eliminate", enabled = true,
        point = { x = 140, y = 200, z = 10 },
        perimeter = { shape = "circle", center = O, radius = 30, minZ = 0, maxZ = 40 },
        outOfBounds = { graceSeconds = 5 }, respawn = { seconds = 4, lives = 1 },
        starts = { { x = 100, y = 200, z = 10, heading = 90 } },
        spawns = {
            { id = "s1", label = "Bay", position = { x = 110, y = 200, z = 10 }, heading = 0, enemy = "militech", count = 2, trigger = "start" },
            { id = "s2", label = "Office", position = { x = 100, y = 220, z = 10 }, heading = 0, enemy = "maelstrom", count = 1, trigger = "checkpoint" },
        },
        checkpoints = { { id = "c1", label = "Stairs", position = { x = 100, y = 215, z = 10 }, radius = 3, required = true, spawns = { "s2" } } },
        waves = {}, difficulties = {} }
end
local function bad(mutate, expect)
    local m = base(); mutate(m)
    local ok, why = D.validate(m)
    assert(not ok and why:find(expect, 1, true), "expected '" .. expect .. "', got " .. tostring(why))
end
local valid = assert(D.validate(base()))
assert(#valid.difficulties == 3 and valid.difficulties[2].enemyCount == 1.5, "default difficulties filled in")
bad(function(m) m.starts[1] = { x = 200, y = 200, z = 10 } end, "outside the perimeter")
bad(function(m) m.checkpoints = {} end, "woken by no checkpoint")
bad(function(m) m.spawns[1].trigger = "wave" end, "waves only exist in Survival")
bad(function(m) m.type = "waves" end, "at least one wave")
bad(function(m) m.perimeter.radius = 900 end, "Perimeter")
bad(function(m) m.spawns[1].count = 40 end, "1–12 enemies")
bad(function(m) m.checkpoints[1].spawns = { "s1" } end, "is not a checkpoint spawn")
bad(function(m) m.outOfBounds.graceSeconds = 1 end, "Out-of-zone delay")
bad(function(m) m.spawns[1].behavior = "dance" end, "unknown behaviour")
bad(function(m) m.spawns[1].behavior = "patrol" end, "a patrol needs at least one patrol point")
bad(function(m) m.spawns[1].radius = 90 end, "area radius")
bad(function(m) m.spawns[1].alertRange = 1 end, "alert range")
bad(function(m) m.spawns[1].route = { { x = 900, y = 900, z = 0 } } end, "patrol point 1")
assert(valid.spawns[1].behavior == "assault" and valid.spawns[1].radius == 12 and valid.spawns[1].alertRange == 25 and valid.spawns[1].spread == 2, "behaviour defaults")
assert(D.inside(valid.perimeter, { x = 120, y = 200, z = 5 }) and not D.inside(valid.perimeter, { x = 131, y = 200, z = 5 }), "circle containment")
local box = assert(D.validate((function() local m = base(); m.perimeter = { shape = "box", center = O, length = 40, width = 10, heading = 90, minZ = 0, maxZ = 40 }
    m.starts[1] = { x = 100, y = 215, z = 10 }; m.checkpoints[1].position = { x = 100, y = 212, z = 10 }; return m end)()))
assert(D.inside(box.perimeter, { x = 100, y = 218, z = 5 }) and not D.inside(box.perimeter, { x = 118, y = 200, z = 5 }), "rotated box containment")
assert(D.count({ count = 3 }, { enemyCount = 1.5 }) == 5 and D.count({ count = 1 }, { enemyCount = 0.25 }) == 1, "enemy count scaling")

-- ── the editor protocol ─────────────────────────────────────────────────────
chars[1], chars[2] = "Author", "Player"
positions[1] = { x = 100, y = 200, z = 10 }; buckets[1] = 0
positions[2] = { x = 140, y = 201, z = 10 }; buckets[2] = 0
Missions.onCharacterLoaded(1); Missions.onCharacterLoaded(2)
assert(not request(2, "list").ok, "a player without the ACL is refused")
assert(not request(1, "save", { mission = base(), baseRevision = 0, mutation = "mutation-0001" }).ok, "no storage: nothing published")
LightRP.db.ready = true
LightRP.missionEditor.onDatabaseReady()
local saved = request(1, "save", { mission = base(), baseRevision = 0, mutation = "mutation-0002" })
assert(saved.ok and saved.data.mission.id == "uuid-1" and saved.data.mission.revision == 1, "published")
local again = request(1, "save", { mission = base(), baseRevision = 0, mutation = "mutation-0002" })
assert(again.ok and again.data.mission.id == "uuid-1" and #dbRows == 1, "a retried request is idempotent")
local id = saved.data.mission.id
local point = Missions.point(id)
assert(point and point.custom and point.type == "Elimination" and #point.start == 1 and #point.difficulties == 3, "the board point is live")
local edited = D.clone(saved.data.mission); edited.title = "Warehouse sweep II"
assert(not request(1, "save", { mission = edited, baseRevision = 5, mutation = "mutation-0003" }).ok, "stale revision refused")
local r2 = request(1, "save", { mission = edited, baseRevision = 1, mutation = "mutation-0004" })
assert(r2.ok and r2.data.mission.revision == 2 and Missions.point(id).title == "Warehouse sweep II", "republished in place")
-- a reload from storage gives the same mission back
LightRP.missionEditor.records = {}
assert(LightRP.missionEditor.load() and LightRP.missionEditor.records[id].revision == 2, "reloaded from storage")
assert(#request(1, "list").data.missions == 1, "listed")

-- ── Elimination: test run ───────────────────────────────────────────────────
local launched = request(1, "test", { id = id, difficulty = "hard" })
assert(launched.ok, "test run launched at a locked difficulty: " .. tostring(launched.error))
local inst = Missions.instanceOf(1)
assert(inst and inst.test and buckets[1] == inst.bucket and positions[1].x == 100, "the author is in the instance, at the start")
local view = providers.missionQueue(1)
assert(view.objective and view.objective.phase == "staging", "staging first")
-- the briefing: the kits like the raid's ready check, the default one preselected
local o = view.objective
assert(o.loadouts and #o.loadouts == 5 and o.loadout == "assault" and o.canChoose and o.ready == false and o.squadSize == 1, "briefing: kits listed, assault preselected")
actions["mission.loadout"](1, { id = "breacher" })
assert(providers.missionQueue(1).objective.loadout == "breacher", "a kit picked in the briefing")
actions["mission.loadout"](1, { id = "nope" })
assert(providers.missionQueue(1).objective.loadout == "breacher", "an unknown kit is ignored")
seconds(7)
assert(providers.missionQueue(1).objective.phase == "staging", "the fight waits for the squad to be ready")
actions["mission.ready"](1)
assert(providers.missionQueue(1).objective.ready == true, "ready")
seconds(1)
local alive = {}
for npcId, n in pairs(npcs) do if n.def.bucket == inst.bucket then alive[#alive + 1] = npcId end end
assert(#alive == 3, "2 Bay enemies x1.5 (hard) = 3 at start, got " .. #alive)
assert(npcs[alive[1]].def.difficulty.healthMultiplier == 1.5, "hard multipliers applied")
-- the mission's kit: the armament stands aside for the run; its NPCs hit through the server
assert(inst.loadout == true and inst.run.kit and inst.run.kit.id == "assault" and Missions.handlesLoadout(1), "the default kit is handed out")
assert(npcs[alive[1]].def.loadout.combat.authoritativePlayerHits == true, "mission NPCs opt into server-owned player hits")
local hit = netHandlers["op77_lightrp:missionrun:npcHit"]
_G.source = 1
hit("1", tostring(alive[1]), "4", "12.5")
assert(#damaged == 1 and damaged[1].id == 1 and damaged[1].amount == 12.5 and damaged[1].attacker == alive[1], "an owned NPC's hit lands on the canonical health")
hit("1", tostring(alive[1]), "3", "12.5"); assert(#damaged == 1, "a retired lease epoch is refused")
hit("1", "999", "4", "12.5"); assert(#damaged == 1, "an NPC of no mission is refused")
_G.source = 2; hit("1", tostring(alive[1]), "4", "12.5"); assert(#damaged == 1, "only the owner of the NPC reports its hits")
_G.source = 1; hit("1", tostring(alive[1]), "4", "500"); assert(#damaged == 2 and damaged[2].amount == 40, "one hit is capped")
assert(LightRP.missionEngine.kitFor({ loadout = "none" }) == nil and LightRP.missionEngine.kitFor({ loadout = "breacher" }).id == "breacher", "kit choice")
assert(D.validate((function() local m = base(); m.loadout = "bad id!"; return m end)()) == nil, "an invalid loadout is refused")
seconds(1)
assert(attacks > 0, "enemies sent at the operator")
for _, npcId in ipairs(alive) do npcs[npcId].health = 0 end
seconds(2)
assert(Missions.instanceOf(1), "not over: the required checkpoint was not reached")
assert(providers.missionQueue(1).objective.kills == 3, "kills counted")
positions[1] = { x = 100, y = 214, z = 10 }
seconds(2)
assert(noticed("CHECKPOINT"), "checkpoint reached")
local woken = {}
for npcId, n in pairs(npcs) do if n.health > 0 and n.def.bucket == inst.bucket then woken[#woken + 1] = npcId end end
assert(#woken == 2 and npcs[woken[1]].def.template == "hostile_female_ranged_lab", "the checkpoint woke the Office spawn (1 x1.5 = 2 Maelstrom)")
for _, npcId in ipairs(woken) do npcs[npcId].health = 0 end
seconds(2)
assert(not Missions.instanceOf(1) and noticed("TEST RUN COMPLETE") and not paid[1], "cleared: a test run pays nothing")
seconds(1)
assert(buckets[1] == 0, "back in the city")

-- ── perimeter, respawns and the wipe ────────────────────────────────────────
assert(Missions.launchNow(id, "standard", { 1 }))
inst = Missions.instanceOf(1)
-- nobody says ready: the fight starts after the 30 s briefing anyway, with the preselected kit
seconds(29)
assert(providers.missionQueue(1).objective.phase == "staging", "still briefing")
seconds(2)
assert(providers.missionQueue(1).objective.phase ~= "staging" and inst.run.ready[1] == true, "the briefing timed out: the fight is on")
-- an admin teleport passes through a non-death phase: no life spent, no wipe
life[1] = "teleporting"; LightRP.eachModule("onLifeState", 1, "teleporting")
seconds(1)
life[1] = "alive"; LightRP.eachModule("onLifeState", 1, "alive")
seconds(1)
assert(Missions.instanceOf(1) and not noticed("OPERATOR DOWN") and providers.missionQueue(1).objective.lives == 1, "a teleport is not a fall")
positions[1] = { x = 160, y = 200, z = 10 }      -- 60 m out, 30 m beyond the edge
seconds(1)
assert(noticed("LEAVING THE ZONE") and providers.missionQueue(1).objective.outOfBoundsMs > 0, "warned, countdown on the HUD")
positions[1] = { x = 105, y = 200, z = 10 }
seconds(1)
assert(not providers.missionQueue(1).objective.outOfBoundsMs, "back inside: countdown cleared")
positions[1] = { x = 160, y = 200, z = 10 }
seconds(7)
assert(#killed == 1 and killed[1] == 1 and noticed("OPERATOR DOWN"), "killed after the 5 s delay, one team respawn spent")
assert(providers.missionQueue(1).objective.respawnInMs > 0 and providers.missionQueue(1).objective.lives == 0, "respawn countdown")
-- down: another kit may be picked for the next life
local downView = providers.missionQueue(1).objective
assert(downView.canChoose and downView.loadouts and downView.ready == nil, "the kit choice while down")
actions["mission.loadout"](1, { id = "marksman" })
assert(providers.missionQueue(1).objective.loadout == "marksman", "next life's kit picked")
seconds(5)
assert(life[1] == "alive" and positions[1].x == 100 and buckets[1] == inst.bucket, "respawned at the start, in the instance")
positions[1] = { x = 160, y = 200, z = 10 }
seconds(7)
assert(#killed == 2 and noticed("OPERATOR LOST"), "no respawn left")
seconds(1)
assert(not Missions.instanceOf(1) and noticed("MISSION FAILED"), "squad wiped")
for npcId, n in pairs(npcs) do assert(n.def.bucket ~= inst.bucket, "the enemies were removed with the run") end
seconds(1)

-- ── Survival ────────────────────────────────────────────────────────────────
local w = base("waves")
w.title = "Last stand"
w.checkpoints = {}
w.spawns = { { id = "n", label = "North", position = { x = 100, y = 225, z = 10 }, heading = 180, enemy = "valentinos", count = 2, trigger = "wave" },
    { id = "e", label = "East", position = { x = 125, y = 200, z = 10 }, heading = 270, enemy = "tygerclaws", count = 1, trigger = "wave" } }
w.waves = { { delaySeconds = 3, spawns = { "n" } }, { delaySeconds = 4, spawns = { "n", "e" } } }
w.respawn.lives = 5
local sw = request(1, "save", { mission = w, baseRevision = 0, mutation = "mutation-0005" })
assert(sw.ok and Missions.point(sw.data.mission.id).type == "Survival", "survival published")
positions[1] = { x = 100, y = 200, z = 10 }; life[1] = "alive"
assert(request(1, "test", { id = sw.data.mission.id, difficulty = "standard" }).ok)
inst = Missions.instanceOf(1)
actions["mission.ready"](1)
seconds(7)
assert(providers.missionQueue(1).objective.phase == "intermission", "first wave pending")
seconds(4)
local function live() local list = {} for npcId, n in pairs(npcs) do if n.health > 0 and n.def.bucket == inst.bucket then list[#list + 1] = npcId end end return list end
assert(#live() == 2 and noticed("WAVE 1 / 2"), "wave 1: 2 enemies")
for _, npcId in ipairs(live()) do npcs[npcId].health = 0 end
seconds(2)
local o = providers.missionQueue(1).objective
assert(o.phase == "intermission" and o.wave == 1 and o.nextWaveInMs > 0 and noticed("WAVE CLEARED"), "intermission before wave 2")
seconds(5)
assert(#live() == 3 and noticed("WAVE 2 / 2"), "wave 2: 2 + 1 enemies")
for _, npcId in ipairs(live()) do npcs[npcId].health = 0 end
seconds(2)
assert(not Missions.instanceOf(1) and noticed("ZONE HELD"), "the last wave is down: held")

-- ── behaviours ───────────────────────────────────────────────────────────────
local b = base()
b.title = "Quiet warehouse"
b.checkpoints = {}
b.spawns = {
    { id = "amb", label = "Ambush", position = { x = 100, y = 225, z = 10 }, heading = 0, enemy = "valentinos", count = 2, trigger = "start",
        behavior = "ambush", alertRange = 8 },
    { id = "def", label = "Guards", position = { x = 125, y = 200, z = 10 }, heading = 0, enemy = "militech", count = 1, trigger = "start",
        behavior = "defend", radius = 6, alertRange = 10 },
    { id = "pat", label = "Patrol", position = { x = 80, y = 200, z = 10 }, heading = 0, enemy = "tygerclaws", count = 1, trigger = "start",
        behavior = "patrol", alertRange = 5, route = { { x = 80, y = 215, z = 10 }, { x = 90, y = 215, z = 10 } } },
}
b.respawn.lives = 5
local sb = request(1, "save", { mission = b, baseRevision = 0, mutation = "mutation-0007" })
assert(sb.ok, "behaviours published: " .. tostring(sb.error))
positions[1] = { x = 100, y = 200, z = 10 }; life[1] = "alive"
assert(request(1, "test", { id = sb.data.mission.id, difficulty = "standard" }).ok)
inst = Missions.instanceOf(1)
actions["mission.ready"](1)
seconds(8)
local byBehaviour = {}
for npcId, n in pairs(npcs) do
    if n.def.bucket == inst.bucket then
        local behaviour = n.def.template == "gang_valentinos_ranged_01" and "amb" or n.def.record and "def" or "pat"
        byBehaviour[behaviour] = byBehaviour[behaviour] or {}
        table.insert(byBehaviour[behaviour], npcId)
    end
end
local amb1, amb2, guard, patroller = byBehaviour.amb[1], byBehaviour.amb[2], byBehaviour.def[1], byBehaviour.pat[1]
assert(amb1 and amb2 and guard and patroller, "one squad per behaviour")
assert(called("combat", amb1) and called("combat", amb1)[3] == false and called("perception", amb1)[3] == false, "ambushers silent and blind")
assert(not called("attack", amb1) and not called("attack", guard) and not called("attack", patroller), "nobody attacks the operator 25 m away")
assert(called("guard", guard) and called("guard", guard)[3] == 6, "defenders hold their 6 m area")
assert(called("patrol", patroller) and called("patrol", patroller)[3] == 3, "the patrol walks spawn point + 2 patrol points")
-- one ambusher is shot: the whole ambush squad wakes up
npcs[amb1].health = 60
seconds(2)
local woke = 0
for _, c in ipairs(npcCalls) do if c[1] == "combat" and c[3] == true and (c[2] == amb1 or c[2] == amb2) then woke = woke + 1 end end
assert(woke == 2 and called("attack", amb2), "the alert spread to the squad")
assert(not called("attack", guard), "the defenders stay put: the operator is outside their area")
-- the operator walks into the defended area
positions[1] = { x = 120, y = 200, z = 10 }
seconds(8)
assert(called("attack", guard), "defenders engage inside their area")
for npcId in pairs(npcs) do npcs[npcId].health = 0 end
seconds(2)
assert(not Missions.instanceOf(1) and noticed("ZONE CLEARED"), "behaviour mission cleared")

-- ── withdrawal ──────────────────────────────────────────────────────────────
local del = request(1, "delete", { id = id, baseRevision = 2, mutation = "mutation-0006" })
assert(del.ok and not Missions.point(id), "deleted: the board is gone")
assert(#request(1, "list").data.missions == 2, "two missions left")
print("PASS: mission editor (format, storage, protocol, test runs, elimination + checkpoints, perimeter kill, respawns, wipe, survival waves, behaviours, withdrawal)")
