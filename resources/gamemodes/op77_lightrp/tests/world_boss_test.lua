-- World bosses (server/modules/world_bosses.lua) with the host stubbed: the editor tag,
-- the open-world spawn through the mission engine, the zone HUD, credit from the
-- server's validated damage/kill events, reinforcements, shares and the end.
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
_G.TriggerLatentClientEvent = function(name, target, _, payload) sent[#sent + 1] = { name = name, target = target, payload = payload, latent = true }; return #sent end
_G.RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
local events = {}
_G.AddEventHandler = function(name, fn) events[name] = events[name] or {}; table.insert(events[name], fn) end
local function fire(name, ...) for _, fn in ipairs(events[name] or {}) do fn(...) end end

local npcs, npcSeq, attacks = {}, 100, 0
local npcCalls = {}
local function called(kind, npcId) for _, c in ipairs(npcCalls) do if c[1] == kind and (not npcId or c[2] == npcId) then return c end end end
_G.Open77 = {
    time = { monotonic = function() return clock / 1000 end },
    acl = { isAllowed = function(id, perm) return id == 1 and perm == "command.lightrp.missions" end },
    npcs = { ai = { native = 2 }, damage = { mortal = 0 },
        create = function(def) npcSeq = npcSeq + 1; local hp = 100 * ((def.difficulty or {}).healthMultiplier or 1); npcs[npcSeq] = { def = def, health = hp, maxHealth = hp, position = def.position }; return npcSeq end,
        get = function(id) local n = npcs[id]; return n and { health = n.health, maxHealth = n.maxHealth, alive = n.health > 0, position = n.position,
            bucket = n.def.bucket, authorityPlayerId = n.owner or 1, authorityEpoch = n.epoch or 4 } end,
        remove = function(id) npcs[id] = nil; return true end,
        setCombatEnabled = function(id, on) npcCalls[#npcCalls + 1] = { "combat", id, on }; return true end,
        setPerceptionEnabled = function(id, on) npcCalls[#npcCalls + 1] = { "perception", id, on }; return true end,
        setTransform = function(id, d) npcCalls[#npcCalls + 1] = { "transform", id, d.position }; if npcs[id] then npcs[id].position = d.position end; return true end,
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
dofile("server/config/economy.lua") -- worldBosses: the pool rule (docs/economy-balance.md §15)
dofile("server/config/world_bosses.lua")
dofile("server/modules/world_bosses.lua")
local D, Missions = LightRpMissionDefs, LightRP.missions
local WB, Engine = LightRP.worldBosses, LightRP.missionEngine
local C = LightRpWorldBosses
_G.exports = setmetatable({}, { __index = function() return setmetatable({}, { __index = function() return function() return "blip-1" end end }) end })

-- ── the "World boss" tag on a definition ──
local O = { x = 500, y = 500, z = 10 }
local function def(extra)
    local d = { title = "Burn Notice", description = "", location = "Kabuki", type = "eliminate", enabled = true,
        point = { x = 500, y = 500, z = 10 },
        perimeter = { shape = "circle", center = O, radius = 40, minZ = 0, maxZ = 40 },
        starts = { { x = 500, y = 500, z = 10, heading = 0 } },
        spawns = {
            { id = "boss", label = "Juggernaut", position = { x = 505, y = 500, z = 10 }, enemy = "militech", count = 1, trigger = "start" },
            { id = "guards", position = { x = 510, y = 500, z = 10 }, enemy = "militech", count = 2, trigger = "start" },
            -- reinforcements need no checkpoint on a world boss
            { id = "late1", position = { x = 515, y = 500, z = 10 }, enemy = "valentinos", count = 2, trigger = "checkpoint" },
            { id = "late2", position = { x = 520, y = 500, z = 10 }, enemy = "valentinos", count = 1, trigger = "checkpoint" },
        },
        worldBoss = { enabled = true, boss = "boss", health = 50, reward = 30000, minShare = 5, minutes = 10 } }
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end
local d, why = D.validate(def())
assert(d, tostring(why))
assert(d.worldBoss.enabled and d.worldBoss.boss == "boss" and d.worldBoss.health == 50)
local bad = def(); bad.worldBoss.boss = "nope"
assert(not D.validate(bad), "the boss must be a spawn point")
bad = def(); bad.worldBoss.boss = "late1"
assert(not D.validate(bad), "the boss spawns at the start")
bad = def(); bad.fixer = { enabled = true }
assert(not D.validate(bad), "a gig or a boss, not both")
local plain = def(); plain.worldBoss = nil
assert(not D.validate(plain), "a plain mission still needs its checkpoints for non-start spawns")

-- ── published: in the catalogue, no board ──
d.id = "wb-1"
Engine.publish(d)
assert(#WB.catalogue() == 1 and Missions.point("wb-1") == nil, "a world boss has no board")
local ok, listed = commands["worldboss.list"](0, {})
assert(ok and listed:find("Burn Notice"))

-- ── players: three in the zone, one far away ──
for id, p in pairs({ [1] = { x = 495, y = 500, z = 10 }, [2] = { x = 530, y = 520, z = 30 }, [3] = { x = 560, y = 500, z = 10 }, [4] = { x = 2000, y = 0, z = 10 } }) do
    chars[id] = "Fighter " .. id; positions[id] = p; buckets[id] = 0
end
ok = commands["worldboss.start"](0, { "burn" })
assert(ok, "staff start")
assert(not select(1, commands["worldboss.start"](0, { "burn" })), "one at a time")
local announced = 0
for _, n in ipairs(notices) do if n.title == "WORLD BOSS" then announced = announced + 1 end end
assert(announced == 4, "the whole city is told")
-- the most the pool can reach: the 4 players online all paid (3,000 x 4 ^ 0.7), not the editor's 30,000
local announceBody
for _, n in ipairs(notices) do if n.title == "WORLD BOSS" then announceBody = n.body end end
assert(announceBody and announceBody:find("up to $7917", 1, true), tostring(announceBody))
seconds(4)
local ev = WB.current()
local bossId, guards = nil, {}
for key, npcId in pairs(ev.bossNpcs) do bossId = npcId end
for key, npcId in pairs(ev.npcs) do if npcId ~= bossId then guards[#guards + 1] = npcId end end
assert(bossId and #guards == 2, "the boss and its guards are out")
assert(npcs[bossId].def.bucket == 0 and npcs[bossId].maxHealth == 5000, "in the city, boss health x50")
local hud = providers.worldBoss(1)
assert(hud and hud.inZone and hud.boss == "Juggernaut" and hud.bossHealth == 1 and hud.share == 0 and hud.minShare == 5, "the zone HUD")
assert(providers.worldBoss(2).inZone, "the height does not matter")
assert(providers.worldBoss(3).inZone, "within the margin past the perimeter")
assert(providers.worldBoss(4) == false, "far away: nothing")

-- ── the zone only: a fighter who steps out loses the HUD ──
positions[2] = { x = 700, y = 500, z = 10 }
seconds(2)
assert(providers.worldBoss(2) == false, "out of the zone: no HUD")
positions[2] = { x = 530, y = 520, z = 30 }
seconds(2)
assert(providers.worldBoss(2).inZone, "back in the zone: the HUD again")

-- ── the leash: an enemy far past the zone runs back to its post ──
local runaway = guards[2]
local before = #npcCalls
npcs[runaway].position = { x = 700, y = 500, z = 10 }
seconds(2)
local leashed
for i = before + 1, #npcCalls do if npcCalls[i][1] == "guard" and npcCalls[i][2] == runaway then leashed = true end end
assert(leashed, "a runaway enemy is sent back")
local function lastCall(kind, id, from)
    for i = #npcCalls, from + 1, -1 do if npcCalls[i][1] == kind and npcCalls[i][2] == id then return npcCalls[i] end end
end
assert(lastCall("combat", runaway, before)[3] == false and lastCall("perception", runaway, before)[3] == false,
    "leashed: it stops fighting and chasing on the way back")
assert(WB.current().run.enemies[runaway].leashed)
-- just past the perimeter (40 m) but within the leash (20 m): it keeps fighting
local guardOne = guards[1]
local b1 = #npcCalls
npcs[guardOne].position = { x = 555, y = 500, z = 10 }
seconds(2)
assert(not lastCall("combat", guardOne, b1), "within the leash: no change")
-- back inside the perimeter: it fights again
local b2 = #npcCalls
npcs[runaway].position = { x = 510, y = 500, z = 10 }
seconds(2)
assert(lastCall("combat", runaway, b2)[3] == true and not WB.current().run.enemies[runaway].leashed, "home: it fights again")
-- dragged away and stuck: put back on its post after leashTeleportSeconds
npcs[runaway].position = { x = 900, y = 500, z = 10 }
seconds(2)
local b3 = #npcCalls
seconds(C.leashTeleportSeconds + 1)
assert(lastCall("transform", runaway, b3), "stuck outside: put back on its post")
seconds(2)
assert(not WB.current().run.enemies[runaway].leashed, "back home after the teleport")
npcs[guardOne].position = { x = 510, y = 500, z = 10 }
npcs[runaway].position = { x = 510, y = 500, z = 10 }

-- ── the enemies' hits on the fighters: they opt into authoritativePlayerHits, so a hit
--    only lands through the relay (client/core/mission_run.lua -> Engine.npcHit), which
--    must find the world boss though the fighters run no mission ──
local hitsBefore = #damaged
local landed, hitWhy = Engine.npcHit(1, 2, tostring(guards[1]), 4, 12)
assert(landed, "a guard's hit on a fighter lands: " .. tostring(hitWhy))
assert(#damaged == hitsBefore + 1 and damaged[#damaged].id == 2 and damaged[#damaged].amount == 12 and damaged[#damaged].attacker == guards[1])
assert(Engine.npcHit(1, 1, tostring(bossId), 4, 500) and damaged[#damaged].amount == 40, "the boss too, capped per hit")
assert(select(2, Engine.npcHit(1, 4, tostring(guards[1]), 4, 10)) == "not_in_mission", "far from the zone: not a fighter")
assert(select(2, Engine.npcHit(2, 1, tostring(guards[1]), 4, 10)) == "not_owner", "only the NPC's owner reports")
assert(select(2, Engine.npcHit(1, 2, "424242", 4, 10)) == "no_run", "not an enemy of the event")
assert(#damaged == hitsBefore + 2)

-- ── credit: server-validated damage and kills ──
npcs[bossId].health = 5000 - 3000
fire("onNpcDamaged", tostring(bossId), "player:1", "3000", "2000", "player_hit")
fire("onNpcDamaged", tostring(bossId), "npc:77", "500", "1500", "crossfire")      -- not a player: no credit
fire("onNpcDamaged", "999999", "player:1", "500", "0", "player_hit")              -- not ours: no credit
fire("onNpcDamaged", tostring(guards[1]), "player:2", "100", "0", "player_hit")
npcs[guards[1]].health, npcs[guards[2]].health = 0, 0
fire("onNpcDied", tostring(guards[1]), "player:2", "player_hit")
fire("onNpcDied", tostring(guards[2]), "player:2", "player_hit")
seconds(2)
assert(math.abs(WB.shareOf(1) - 3000 / 3125 * 100) < 0.01 and math.abs(WB.shareOf(2) - 125 / 3125 * 100) < 0.01, "shares: damage + kills earned by damage")
-- 60 % of the boss: the first reinforcements
assert(ev.reinforced[1], "reinforcements at 66 %")
local reinforcements = 0
for _, n in ipairs(notices) do if n.title == "REINFORCEMENTS" then reinforcements = reinforcements + 1 end end
assert(reinforcements >= 1, "the zone is told")
npcs[bossId].health = 1500
fire("onNpcDamaged", tostring(bossId), "player:1", "500", "1500", "player_hit")
fire("onNpcDamaged", tostring(bossId), "player:2", "300", "1500", "player_hit")
seconds(2)
assert(ev.reinforced[2], "and at 33 %")

-- ── the end: a latecomer's last shot is not a share ──
fire("onNpcDamaged", tostring(bossId), "player:3", "1500", "0", "player_hit")
fire("onNpcDied", tostring(bossId), "player:3", "player_hit")
npcs[bossId].health = 0
-- player 3 dealt 1500 there: make it a real latecomer instead (last shot only)
local late = ev.contrib[3]
late.damage, late.bossDamage, late.on[tostring(bossId)] = 10, 10, 10
late.score = 10 + C.killShare * 5000 * (10 / (C.killAssist * 5000))
seconds(2)
assert(ev.phase == "cleanup", "boss down")
assert(paid[1] and paid[2] and not paid[3] and not paid[4], "the latecomer and the far player get nothing")
-- two paid: the pool is 3,000 x 2 ^ 0.7 = 4,874, and one share stops at 250 x 10 min
assert(ev.pool == 4874 and paid[1] + paid[2] <= ev.pool and paid[1] > paid[2], "the pool shared by score among the eligible")
assert(paid[1] == 2500, "the top fighter's share stops at 250 per minute of the event: " .. paid[1])
assert(ev.results[3].share < 5 and not ev.results[3].eligible)
local told
for _, n in ipairs(notices) do if n.id == 3 and n.title == "WORLD BOSS DOWN" then told = n.body end end
assert(told and told:find("no reward"), "the latecomer is told why")
assert(providers.worldBoss(1).result.pay == paid[1], "the result on the HUD")
seconds(C.resultSeconds + 1)
assert(providers.worldBoss(1) == false, "the HUD goes after a few seconds, before the bodies")
assert(WB.current() ~= nil, "the enemies' cleanup still runs")
seconds(C.cleanupSeconds + 3)
assert(WB.current() == nil, "closed after the cleanup")
local left = 0
for _ in pairs(npcs) do left = left + 1 end
assert(left == 0, "every enemy removed")

-- ── a boss that gets away pays nobody ──
paid = {}
assert(commands["worldboss.start"](0, {}))
seconds(3)
ev = WB.current()
for _, npcId in pairs(ev.bossNpcs) do fire("onNpcDamaged", tostring(npcId), "player:1", "100", "4900", "player_hit") end
notices = {}
seconds(10 * 60 + 2)
assert(next(paid) == nil, "escaped: nobody paid")
left = 0
for _ in pairs(npcs) do left = left + 1 end
assert(left == 0, "the escaped boss and guards removed at once")
local esc = providers.worldBoss(2)
assert(esc and esc.result and esc.result.success == false and esc.result.pay == 0, "a bystander in the zone sees it got away")
assert(providers.worldBoss(1).result.success == false, "the fighter too")
local toldBystander
for _, n in ipairs(notices) do if n.id == 2 and n.title == "WORLD BOSS ESCAPED" then toldBystander = true end end
assert(toldBystander, "the zone is told it escaped")
seconds(10)
assert(WB.current() == nil, "closed a few seconds later")
assert(providers.worldBoss(2) == false, "HUD gone")
left = 0
for _ in pairs(npcs) do left = left + 1 end
assert(left == 0, "the escaped boss and guards removed")

-- ── a crowd: 40 players, 30 fighting, 3 watching, 3 arriving for the last shot, 4 away ──
paid, notices = {}, {}
for id = 1, 40 do
    chars[id] = "Crowd " .. id; buckets[id] = 0
    if id <= 36 then positions[id] = { x = 480 + (id % 6) * 8, y = 480 + math.floor(id / 6) * 6, z = 10 }
    else positions[id] = { x = 2000 + id, y = 0, z = 10 } end
end
assert(commands["worldboss.start"](0, {}))
seconds(3)
ev = WB.current()
local boss
for _, n in pairs(ev.bossNpcs) do boss = n end
for id = 1, 36 do assert(providers.worldBoss(id) and providers.worldBoss(id).inZone, "in the zone: " .. id) end
for id = 37, 40 do assert(providers.worldBoss(id) == false, "away: no HUD " .. id) end
assert(ev.fighters == 36, "36 in the zone")
local hp = npcs[boss].health
local t0, ticks = os.clock(), 0
for round = 1, 6 do
    for id = 1, 30 do
        local dmg = 10 + id
        hp = hp - dmg; npcs[boss].health = math.max(1, hp)
        fire("onNpcDamaged", tostring(boss), "player:" .. id, tostring(dmg), tostring(math.max(1, hp)), "player_hit")
    end
    seconds(1); ticks = ticks + 2
end
local perTick = (os.clock() - t0) / ticks * 1000
-- three latecomers: one small hit each, one takes the kill
for id = 34, 36 do fire("onNpcDamaged", tostring(boss), "player:" .. id, "10", tostring(math.max(1, hp - 10)), "player_hit") end
npcs[boss].health = 0
fire("onNpcDied", tostring(boss), "player:34", "player_hit")
seconds(2)
assert(ev.phase == "cleanup", "boss down")
local payees, total = 0, 0
for id = 1, 30 do assert(paid[id] and paid[id] > 0, "every real fighter is paid, even with an average share under 5 %: " .. id); payees = payees + 1; total = total + paid[id] end
for id = 31, 40 do assert(not paid[id], "watchers, latecomers and the away get nothing: " .. id) end
assert(ev.pool == 30000, "30 paid: 3,000 x 30 ^ 0.7 = 32,435, the editor's 30,000 is the most")
assert(total <= 30000 and total > 29900, "the whole pool shared: " .. total)
assert(paid[30] > paid[1], "more damage, more pay")
assert(ev.need < 5 and ev.need > 0.5, "the paying share follows the crowd: " .. ev.need)
local told34
for _, n in ipairs(notices) do if n.id == 34 and n.title == "WORLD BOSS DOWN" then told34 = n.body end end
assert(told34 and told34:find("no reward"), "the last shot is told why")
seconds(C.cleanupSeconds + 3)
assert(WB.current() == nil)
print(string.format("crowd: 30 paid of 40, need %.2f %%, %.3f ms per tick with 36 in the zone", ev.need, perTick))

-- ── the pool rule (server/config/economy.lua worldBosses), and the old rule without it ──
assert(WB.pool(30000, 1) == 3000 and WB.pool(30000, 3) == 6473 and WB.pool(30000, 10) == 15036, "3,000 x fighters ^ 0.7")
assert(WB.pool(10000, 8) == 10000 and WB.pool(0, 5) == 0, "never above the editor's reward")
assert(WB.headCap(20) == 5000, "250 per minute of the event")
local saved = LightRpEconomy.worldBosses
LightRpEconomy.worldBosses = nil
assert(WB.pool(30000, 2) == 30000 and WB.headCap(20) == math.huge, "no worldBosses table: the editor's reward, no cap")
LightRpEconomy.worldBosses = saved

-- ── the daily cap (owner decision 2026-11-04): 3 paid world bosses per character and UTC day ──
assert(C.dailyPaid == 3, "three a day")
local unixNow = 20500 * 86400 + 3600 -- 01:00 UTC on a day no event above was paid
Open77.time.unix = function() return unixNow end
for id = 5, 40 do positions[id], chars[id] = nil, nil end
for id = 1, 3 do chars[id] = "Fighter " .. id; positions[id] = { x = 495 + id, y = 500, z = 10 }; buckets[id] = 0 end
positions[4] = { x = 2000, y = 0, z = 10 }; buckets[4] = 0; chars[4] = "Away 4"
-- one event: `hits` (player id -> damage) on the boss, then it falls
local function fight(hits)
    paid, notices = {}, {}
    assert(commands["worldboss.start"](0, {}))
    seconds(3)
    local fightEv = WB.current()
    local boss
    for _, n in pairs(fightEv.bossNpcs) do boss = n end
    for id, amount in pairs(hits) do fire("onNpcDamaged", tostring(boss), "player:" .. id, tostring(amount), "1", "player_hit") end
    npcs[boss].health = 0
    fire("onNpcDied", tostring(boss), "player:1", "player_hit")
    seconds(2)
    assert(fightEv.phase == "cleanup", "boss down")
    return fightEv
end
local function close() seconds(C.cleanupSeconds + 3); assert(WB.current() == nil) end
local function noticeOf(id, title) for i = #notices, 1, -1 do if notices[i].id == id and notices[i].title == title then return notices[i].body end end end
for n = 1, 3 do
    fight({ [1] = 1000, [2] = 1000 })
    assert(paid[1] and paid[1] > 0 and paid[2] and paid[2] > 0, "paid world boss " .. n .. " of 3")
    close()
end
assert(select(2, WB.dailyCapped(1)) == 3 and WB.dailyCapped(1) and WB.dailyCapped(2) and not WB.dailyCapped(3), "two fighters at the cap")
local repBefore1, repBefore2 = Missions.reputation(1), Missions.reputation(2)
local fourth = fight({ [1] = 1000, [2] = 1000, [3] = 1000 })
-- the zone told them as they came in; the HUD stops promising a share
local zone1 = noticeOf(1, "WORLD BOSS ZONE")
assert(zone1 and zone1:find("Daily world boss pay reached: you were paid for 3 world bosses today", 1, true), tostring(zone1))
assert(noticeOf(3, "WORLD BOSS ZONE"):find("Your share of", 1, true), "an uncapped fighter is promised a share")
assert(providers.worldBoss(1).dailyCapped == true and providers.worldBoss(1).eligible == false, "the HUD: no share to earn")
-- the fight counted, the pay did not: no money, no reputation, told why
assert(not paid[1] and not paid[2], "past the cap: no money")
assert(Missions.reputation(1) == repBefore1 and Missions.reputation(2) == repBefore2, "past the cap: no reputation")
assert(fourth.contrib[1].score > 0 and fourth.results[1].dailyCapped and fourth.results[1].pay == 0, "their score still counts in the fight")
assert(fourth.results[1].eligible, "their share still qualifies (contracts, titles, iconic rolls): only money and reputation stop")
local down1 = noticeOf(1, "WORLD BOSS DOWN")
assert(down1 and down1:find("Your share: ", 1, true) and down1:find("no pay or reputation from world bosses until 00:00 UTC", 1, true), tostring(down1))
-- the capped do not count as paid fighters: the pool is the one of fighter 3 alone
assert(fourth.pool == WB.pool(30000, 1) and paid[3] == math.min(WB.headCap(10), fourth.pool), "pool for one paid fighter: " .. tostring(paid[3]))
assert(select(2, WB.dailyCapped(1)) == 3, "an unpaid event does not count")
close()
-- a new UTC day: paid again
unixNow = (math.floor(unixNow / 86400) + 1) * 86400 + 60
assert(not WB.dailyCapped(1), "the count starts over at 00:00 UTC")
fight({ [1] = 1000, [2] = 1000 })
assert(paid[1] and paid[1] > 0 and Missions.reputation(1) == repBefore1 + C.reputation, "paid again, reputation again")
close()
-- read back from SQL (a restart), and written through
local wrote, savedDb = {}, { ready = LightRP.db.ready, single = LightRP.db.single, run = LightRP.db.run }
LightRP.db.ready = true
LightRP.db.single = function(sql, p) if sql:find("FROM lightrp_worldboss_daily", 1, true) and p[1] == "id-3" then return { paid_events = 3 } end end
LightRP.db.run = function(sql, p) if sql:find("INSERT INTO lightrp_worldboss_daily", 1, true) then wrote[#wrote + 1] = p end; return true, 1 end
assert(WB.dailyCapped(3), "the day's count is read back from SQL")
chars[6] = "Fresh 6"
assert(not WB.dailyCapped(6), "another character: nothing paid today")
assert(select(2, WB.dailyCapped(1)) == 1, "a character already read keeps its count")
LightRP.db.ready, LightRP.db.single, LightRP.db.run = savedDb.ready, savedDb.single, savedDb.run
chars[6] = nil
C.dailyPaid = 0
assert(not WB.dailyCapped(3), "0: no cap")
C.dailyPaid = 3

-- ── withdrawn: out of the catalogue ──
Engine.withdraw("wb-1")
assert(#WB.catalogue() == 0)

print("PASS: world bosses (editor tag + validation, no board, staff start, city notice (pool up to), pool 3,000 x n^0.7 and 250/min a share, zone HUD + margin + height, boss health x, credit from validated damage/kills only, reinforcements 66/33, shares, latecomer and far player unpaid, cleanup, escape pays nobody, daily cap of 3 paid events (money + reputation, told, pool without them, UTC reset, SQL), withdraw)")
