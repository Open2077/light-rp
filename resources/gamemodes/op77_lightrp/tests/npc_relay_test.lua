-- NPC hits on a victim-path platform with clients of mixed versions. Harness from world_boss_test.lua.
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
    npcs = { ai = { native = 2 }, damage = { mortal = 0 }, victimHits = true,
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

local timers = {}
_G.SetTimeout = function(ms, fn) timers[#timers + 1] = { ms = ms, fn = fn } end
local function flushTimers() local due = timers; timers = {}; for _, t in ipairs(due) do t.fn() end end
dofile("shared/safezones.lua")
dofile("shared/mission_defs.lua")
dofile("server/config/missions.lua")
dofile("server/modules/parties.lua")
dofile("server/modules/missions.lua")
dofile("server/modules/mission_engine.lua")

-- ── NPC hits with clients of mixed versions (server/modules/mission_engine.lua) ──
-- On a platform with Open77.npcs.victimHits a current client reports its own hits on the victim
-- path (onNpcPlayerHit); a client from before it only relays open77:npcPlayerHit. Its relay must
-- still land, and a current client's relay must never count on top of its own victim report.
local Engine = LightRP.missionEngine
assert(Engine.platformVictimHits == true, "the platform flag is read at load")
local calls = {}
Engine.npcHit = function(reporter, victimId, npcId, epoch, amount, platform)
    calls[#calls + 1] = { reporter = reporter, victim = tonumber(victimId), platform = platform == true }
    return true
end
local relay = netHandlers["op77_lightrp:missionrun:npcHit"]
assert(relay, "the relay handler is registered")
local function relayFrom(id, victim) _G.source = id; relay(tostring(victim), "101", "4", "12") end

-- an older client (player 5): its relay is held, then applied
relayFrom(5, 5)
assert(#calls == 0 and #timers == 1 and timers[1].ms == 600, "held for the victim report window")
flushTimers()
assert(#calls == 1 and calls[1].reporter == 5 and not calls[1].platform, "an older client's relay lands")

-- a current client (player 6): its victim report arrives within the hold, so the relay is dropped
relayFrom(6, 6)
fire("onNpcPlayerHit", "101", "6", "12", "firearm", "4", "6")
flushTimers()
assert(#calls == 2 and calls[2].reporter == 6 and calls[2].platform, "only the victim report counts")
relayFrom(6, 6)
assert(#timers == 0 and #calls == 2, "a known current client's relay is ignored at once")

-- a blast report names the victim but may come from the NPC's authority: it proves nothing of player 7
fire("onNpcPlayerHit", "101", "7", "30", "explosion", "4", "6")
relayFrom(7, 7)
flushTimers()
assert(#calls == 4 and calls[4].reporter == 7 and not calls[4].platform, "player 7 is still treated as an older client")

-- a player who leaves is forgotten (the next player with that id may run another client)
_G.source = 6; fire("playerDropped")
relayFrom(6, 6)
flushTimers()
assert(#calls == 5 and calls[5].reporter == 6 and not calls[5].platform, "dropped: the relay lands again")
print("PASS: NPC hits with mixed client versions (older relay held then applied, current client counted once, blasts prove nothing, drop forgets)")
