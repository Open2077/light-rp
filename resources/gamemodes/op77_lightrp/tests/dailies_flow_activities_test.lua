-- Dailies fed by the activity providers, the world bosses and the medical flow
-- (server/modules/dailies.lua K.lose_them, K.leg_day, K.five_streak, K.support_act,
-- K.nightcap, back_to_back, nobody_left_behind, K.all_the_way, K.both_sides,
-- lions_share, K.on_call, K.good_samaritan), driven through the REAL producers:
--   server/modules/activities.lua    activityRegister / activityEnter / activityLeave through
--                                    Open77.exports.callSync (as op77_chase core.lua calls
--                                    them) and the op77_lightrp:activity:result event: it
--                                    normalizes, drops unranked / test results, keeps
--                                    enteredAt, and hands the rest to activity_pay.lua
--   server/modules/activity_pay.lua  the quote (minSeconds, progress, quit / forfeit, the
--                                    roster it samples, crews, repeats per hour) and the
--                                    onActivityResult hook with its verdict
--   server/modules/inventory.lua +   the inventory.use action, the timed drink (consume
--   server/modules/consumables.lua   ready / finish net events), applyUse -> onItemUsed
--   server/modules/world_bosses.lua  /worldboss.start, onNpcDamaged / onNpcDied, its clock
--                                    thread, finish -> onWorldEventEnded
--   server/modules/medical.lua       onLifeState dead (capture), inventory.use on the trauma
--                                    kit, the treatment net event, its 250 ms thread, the
--                                    revive, confirm -> onPatientStabilized
-- Only the host is stubbed: natives (Open77.*, GetPlayers, CreateThread / Wait, json), the
-- LightRP core shims, a database that accepts every write, the mission engine's enemy
-- spawner (LightRP.missionEngine.world: it creates the NPCs, nothing more), and the
-- activity resources' result payloads, built with the exact shapes op77_chase (server/pve.lua
-- P.resultFor, server/wanted.lua resultFor) and op77_arena (server/lightrp.lua reportPve,
-- reportMatch, noteQuit) send. Progress is read from the page state (providers.dailies).
local clock = 0
local threads, timers = {}, {}
local function resumeAll()
    for i = #threads, 1, -1 do
        local co = threads[i]
        if coroutine.status(co) == "dead" then table.remove(threads, i)
        else local ok, err = coroutine.resume(co); if not ok then error(err, 0) end end
    end
end
_G.CreateThread = function(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; local ok, err = coroutine.resume(co); if not ok then error(err, 0) end end
_G.Wait = function() coroutine.yield() end
_G.SetTimeout = function(ms, fn) timers[#timers + 1] = { at = clock + (tonumber(ms) or 0), fn = fn } end
local function run(ms, every)
    every = every or 250
    local target = clock + (ms or every)
    repeat
        clock = math.min(target, clock + every)
        local due = {}
        for i = #timers, 1, -1 do if timers[i].at <= clock then due[#due + 1] = table.remove(timers, i) end end
        for i = #due, 1, -1 do CreateThread(due[i].fn) end
        resumeAll()
    until clock >= target
end

local function ser(v)
    local t = type(v)
    if t == "table" then
        local parts = {}
        for k, x in pairs(v) do
            local key = type(k) == "number" and ("[" .. k .. "]") or ("[" .. string.format("%q", tostring(k)) .. "]")
            parts[#parts + 1] = key .. "=" .. ser(x)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "string" then return string.format("%q", v) end
    return tostring(v)
end
_G.json = { encode = ser, decode = function(s)
    local f = type(s) == "string" and load("return " .. s)
    if not f then return nil end
    local ok, v = pcall(f)
    return ok and v or nil
end }

local logLines = {}
local function check(cond, msg)
    if not cond then error(tostring(msg) .. "\n  last log lines:\n    " .. table.concat(logLines, "\n    "), 2) end
end

-- ── the host ──
local unixBase = 20395 * 86400 + 3600 -- Monday 2025-11-03, 01:00 UTC
local online, pos, life, buckets, anims = {}, {}, {}, {}, {}
local events, net, tokens, exported = {}, {}, {}, {}
local npcs, npcSeq, playSeq, uuidSeq = {}, 1000, 0, 0
_G.GetPlayers = function()
    local t = {}
    for id in pairs(online) do t[#t + 1] = id end
    table.sort(t)
    for i, id in ipairs(t) do t[i] = tostring(id) end
    return t
end
_G.GetPlayerName = function(id) id = tonumber(id); return id and online[id] and ("Op" .. id) or nil end
_G.GetPlayerRoutingBucket = function(id) return buckets[tonumber(id)] or 0 end
_G.SetPlayerRoutingBucket = function(id, b) buckets[tonumber(id)] = b; return true end
_G.GetCurrentResourceName = function() return "op77_lightrp" end
_G.GetInvokingResource = function() return nil end
_G.GetResourceState = function() return "running" end
_G.AddEventHandler = function(name, fn) events[name] = events[name] or {}; table.insert(events[name], fn) end
_G.TriggerEvent = function(name, ...) for _, fn in ipairs(events[name] or {}) do fn(...) end end
_G.RegisterNetEvent = function(name, fn) net[name] = fn end
-- the client side only answers a "prepare" (consume, treatment) with its token
_G.TriggerClientEvent = function(name, target, payload)
    if type(payload) == "table" and payload.phase == "prepare" and payload.token then
        tokens[name] = tokens[name] or {}
        tokens[name][target] = payload.token
    end
end
local function fromClient(name, player, payload) _G.source = player; net[name](payload); _G.source = nil end
-- exports(name, fn) registers Light RP's exports; exports.<resource>:<method>() is a stub (map blips)
_G.exports = setmetatable({}, {
    __call = function(_, name, fn) exported[name] = fn end,
    __index = function() return setmetatable({}, { __index = function() return function() return "blip-1" end end }) end,
})
local function here(id) local p = pos[id]; return { x = p.x, y = p.y, z = p.z } end
_G.Open77 = {
    time = { unix = function() return unixBase + math.floor(clock / 1000) end },
    exports = { callSync = function(resource, name, ...)
        assert(resource == "op77_lightrp", resource)
        return assert(exported[name], "no export " .. tostring(name))(...)
    end },
    ready = { isReady = function(id) return online[id] == true end },
    combat = { onDamage = function() return 1 end, offDamage = function() end },
    players = {
        position = function(id) local p = online[id] and pos[id]; return p and { x = p.x, y = p.y, z = p.z, bucket = buckets[id] or 0 } or nil end,
        positions = function()
            local out = {}
            for id, p in pairs(pos) do if online[id] then out[id] = { x = p.x, y = p.y, z = p.z, bucket = buckets[id] or 0 } end end
            return out
        end,
        get = function(id)
            if not (online[id] and pos[id]) then return nil end
            return { position = here(id), heading = 0, ageMs = 0, bucket = buckets[id] or 0, health = 100, maxHealth = 100, lifePhase = life[id] or "alive" }
        end,
        getLifeState = function(id) if not online[id] then return nil end return { phase = life[id] or "alive", bucket = buckets[id] or 0 } end,
        teleport = function(id, spot, opts)
            return { await = function() pos[id] = { x = spot.x, y = spot.y, z = spot.z }; buckets[id] = opts and opts.bucket or 0; return true end }
        end,
        respawn = function(id, opts)
            life[id], buckets[id] = "alive", opts.bucket or 0
            pos[id] = { x = opts.position.x, y = opts.position.y, z = opts.position.z }
            return true
        end,
        heal = function() return true, 100 end,
        -- the platform accepts the revive now and announces the new life on a later tick
        revive = function(id)
            if life[id] ~= "dead" then return false, "invalid_state" end
            life[id] = "alive"
            SetTimeout(0, function() LightRP.eachModule("onLifeState", id, "alive") end)
            return true
        end,
    },
    vehicles = { getPlayerSeat = function() return nil end, get = function() return nil end,
        getHealth = function() return nil end, getDriver = function() return nil end },
    animations = {
        current = function(id) return anims[id] end,
        play = function(id, profile)
            playSeq = playSeq + 1
            anims[id] = { playbackId = "pb" .. playSeq, active = true, profile = profile }
            return anims[id]
        end,
        stop = function(id, playbackId) if anims[id] and anims[id].playbackId == playbackId then anims[id] = nil end return true end,
    },
    npcs = { ai = { native = 2 }, damage = { mortal = 0 },
        create = function(def)
            npcSeq = npcSeq + 1
            npcs[npcSeq] = { health = def.maxHealth or 100, maxHealth = def.maxHealth or 100, position = def.position }
            return npcSeq
        end,
        get = function(id) local n = npcs[tonumber(id)]; return n and { health = n.health, maxHealth = n.maxHealth, alive = n.health > 0, position = n.position } or nil end,
        remove = function(id) npcs[tonumber(id)] = nil; return true end,
        tasks = { guard = function() return true end, attack = function() return true end } },
}

-- ── the LightRP core shims ──
local modules, actions, commands, providers = {}, {}, {}, {}
local chars, jobs, crews = {}, {}, {}
local notices, paid, stabilized, hookErrors, ended, verdicts = {}, {}, {}, {}, {}, {}
_G.LightRP = {
    nowMs = function() return clock end,
    log = function(fmt, ...)
        local ok, line = pcall(string.format, fmt, ...)
        logLines[#logLines + 1] = ok and line or tostring(fmt)
        if #logLines > 30 then table.remove(logLines, 1) end
        if os.getenv("DAILIES_FLOW_LOG") then print(logLines[#logLines]) end
    end,
    -- like server/core/framework.lua: appended, the first definition of a name kept
    module = function(name, def) def.name = name; modules[#modules + 1] = def; LightRP[name] = LightRP[name] or def; return def end,
    -- like framework.lua: every module, each in a pcall (the failures are kept and asserted)
    eachModule = function(hook, ...)
        if hook == "onPatientStabilized" then stabilized[#stabilized + 1] = { actor = select(1, ...), patient = select(2, ...) } end
        if hook == "onWorldEventEnded" then ended[#ended + 1] = select(2, ...) end
        -- activity_pay.lua's verdict { amount, kind, detail } (dailies adds `eligible`)
        if hook == "onActivityResult" then verdicts[#verdicts + 1] = { id = select(1, ...), activity = select(2, ...).activity, v = select(5, ...) } end
        for _, m in ipairs(modules) do
            if type(m[hook]) == "function" then
                local ok, err = pcall(m[hook], ...)
                if not ok then hookErrors[#hookErrors + 1] = m.name .. "." .. hook .. ": " .. tostring(err) end
            end
        end
    end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    stateProvider = function(key, fn) providers[key] = fn end,
    state = function() end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, body = n.body } end,
    result = function() end,
    dialog = function() end,
    interaction = function() end, removeInteraction = function() end,
    characters = {
        get = function(id) return online[id] and chars[id] or nil end,
        displayName = function(id) return chars[id] and chars[id].name or ("P" .. tostring(id)) end,
        isRegistered = function(id) return online[id] == true and chars[id] ~= nil end,
        switching = {},
    },
    jobs = { get = function(id) return { name = jobs[id] or "unemployed", label = jobs[id] or "Unemployed", grade = 0 } end },
    parties = { of = function(id) return crews[id] end },
    money = {
        addBank = function(id, amount, kind, note) paid[#paid + 1] = { id = id, amount = amount, kind = kind, note = note }; return true end,
        format = function(n) return "$" .. tostring(n) end,
    },
    -- every write succeeds (medical's escrow refuses to commit without a database)
    db = {
        ready = true, schema = function() end, single = function() return nil end,
        run = function() return true end, transaction = function() return true end,
        read = function(sql)
            if sql:find("UUID()", 1, true) then uuidSeq = uuidSeq + 1; return true, { { id = "uuid-" .. uuidSeq } } end
            return true, {}
        end,
    },
}
-- The mission engine's enemy spawner (mission_engine.lua Engine.world): world_bosses.lua
-- asks it for the spawn points' NPCs; it creates them with the boss's health multiplier
-- and reports each one (run.onCreated). Contributions, eligibility and the end are the
-- real world_bosses.lua.
LightRP.missionEngine = { world = {
    enqueue = function(r, spawnId)
        local s = r.spawns[spawnId]
        if not s then return 0 end
        local n = math.max(1, math.floor(tonumber(s.count) or 1))
        for _ = 1, n do
            local hp = 100 * ((r.difficulty or {}).enemyHealth or 1) * (s.healthMultiplier or 1)
            local npcId = Open77.npcs.create({ position = s.position, bucket = 0, maxHealth = hp })
            r.enemies[npcId] = { spawn = s }
            r.alive, r.total = r.alive + 1, r.total + 1
            if r.onCreated then r.onCreated(npcId, s) end
        end
        return n
    end,
    enemiesTick = function() end,
    clearEnemies = function(r) for npcId in pairs(r.enemies or {}) do npcs[npcId] = nil end; r.enemies, r.alive = {}, 0 end,
} }

-- the producers, in the manifest's order, then the dailies module that listens to them
dofile("shared/events.lua")
dofile("shared/safezones.lua")
dofile("shared/mission_defs.lua")
dofile("shared/config.lua")
dofile("shared/items.lua")
dofile("shared/medical.lua")
dofile("shared/consumables.lua")
dofile("server/modules/inventory.lua")
dofile("server/config/economy.lua")
dofile("server/config/world_bosses.lua")
LightRpWorldBosses.enabled = false -- no random spawn: /worldboss.start brings each boss out
dofile("server/modules/world_bosses.lua")
dofile("server/modules/consumables.lua")
dofile("server/modules/medical_store.lua")
dofile("server/modules/medical.lua")
dofile("server/config/activities.lua")
dofile("server/modules/activities.lua")
dofile("server/modules/activity_pay.lua")
dofile("server/config/dailies.lua")
dofile("server/modules/dailies.lua")
local D = LightRP.dailies
run(1000)

local function noHookErrors() check(#hookErrors == 0, "a module hook failed:\n    " .. table.concat(hookErrors, "\n    ")) end
-- eachModule reaches the producers and the dailies module alike
local hooked = {}
for _, m in ipairs(modules) do hooked[m.name] = m end
for _, pair in ipairs({ { "inventory", "onCharacterLoaded" }, { "medical", "onLifeState" }, { "activities", "onCharacterLoaded" },
    { "worldBosses", "onDisconnected" }, { "consumables", "onCharacterLoaded" }, { "dailies", "onActivityResult" },
    { "dailies", "onItemUsed" }, { "dailies", "onWorldEventEnded" }, { "dailies", "onPatientStabilized" } }) do
    check(hooked[pair[1]] and type(hooked[pair[1]][pair[2]]) == "function", pair[1] .. "." .. pair[2] .. " is dispatched by eachModule")
end
check(type(LightRP.activityPay.onResult) == "function" and LightRP.activities.registry ~= nil, "activities and activity pay loaded")

-- ── players ──
local function join(id, account, opts)
    opts = opts or {}
    chars[id] = { status = "active", identifier = account, key = opts.key or "default", name = opts.name or ("Op" .. id), playtimeMs = 360000000 }
    online[id], life[id], buckets[id] = true, "alive", 0
    pos[id] = opts.at or { x = -3000 - id * 4, y = -3000, z = 0 }
    jobs[id] = opts.job
    LightRP.eachModule("onCharacterLoaded", id, chars[id])
    run(500)
    check(LightRP.inventory.player(id) ~= nil, "inventory.lua built the inventory of " .. id .. " (eachModule reached the producer)")
    check(providers.dailies(id).ready == true, "dailies loaded the account of " .. id .. " (eachModule reached the dailies module)")
end
local function drop(id) online[id] = nil; LightRP.eachModule("onDisconnected", id); run(250) end
local function card(id, contractId)
    for _, c in ipairs(providers.dailies(id).list or {}) do if c.id == contractId then return c end end
end
local function give(id, contractId)
    local okGive, text = commands["lightrp.dailies"](0, { "give", tostring(id), contractId })
    check(okGive, text)
    local c = card(id, contractId)
    check(c and not c.done and c.value == 0, contractId .. " handed to " .. id)
end
local function open(id, contractId, why)
    local c = card(id, contractId)
    check(c ~= nil, contractId .. " is not in the set of " .. id)
    check(not c.done, why .. ": " .. contractId .. " must stay open for " .. id)
    noHookErrors()
end
local function done(id, contractId, why)
    local c = card(id, contractId)
    check(c ~= nil and c.done == true, why .. ": " .. contractId .. " must be done for " .. id)
    noHookErrors()
end
local function paidTo(id, kind)
    local n = 0
    for _, p in ipairs(paid) do if p.id == id and (not kind or p.kind == kind) then n = n + p.amount end end
    return n
end
local function told(id, pattern)
    for i = #notices, 1, -1 do if notices[i].id == id and (notices[i].body or ""):find(pattern, 1, true) then return true end end
    return false
end
-- why a contract stayed open: the check itself (the result was paid-eligible), activity
-- pay's refusal (its reason), or activities.lua dropping the result before any hook
local function verdictOf(id)
    for i = #verdicts, 1, -1 do if verdicts[i].id == id then return verdicts[i].v end end
end
local function paidVerdict(id, why)
    local v = verdictOf(id)
    check(v and v.eligible == true and v.amount ~= nil, why .. ": the result of " .. id .. " must be paid-eligible (got " .. tostring(v and v.kind) .. ")")
end
local function unpaid(id, reason, why)
    local v = verdictOf(id)
    check(v and v.eligible == false and v.amount == nil and v.kind == reason,
        string.format("%s: activity_pay.lua must refuse %d with %s (got %s)", why, id, reason, tostring(v and v.kind)))
end
local function dropped(n, why) check(#verdicts == n, why .. ": activities.lua must drop the result before activity_pay.lua") end

-- ── the activity resources (op77_chase, op77_arena): registration, entries, results ──
local function call(name, ...) return Open77.exports.callSync("op77_lightrp", name, ...) end
local CAPS = { rpWeapons = false, rpItems = false, needs = false, vehicles = false, botFill = false }
check(call("activityRegister", { id = "chase.pve", resource = "op77_chase", label = "NCPD Escape", kind = "chase",
    description = "The NCPD is after you, for real.", minPlayers = 1, maxPlayers = 4, caps = CAPS, botFill = false,
    modes = { { id = "vehicle", label = "By car" }, { id = "foot", label = "On foot" } },
    pve = true, difficulties = { "standard", "hard", "critical" } }) == true, "chase.pve registered")
check(call("activityRegister", { id = "chase.wanted", resource = "op77_chase", label = "Most Wanted", kind = "chase",
    description = "One runner against the NCPD.", minPlayers = 3, maxPlayers = 8, caps = CAPS, botFill = false }) == true, "chase.wanted registered")
check(call("activityRegister", { id = "arena.pve", resource = "op77_arena", label = "Combat Zone · PvE", kind = "pvp",
    description = "Players together against gang bots.", minPlayers = 1, maxPlayers = 6, pve = true,
    difficulties = { "standard", "hard", "critical" }, botFill = true }) == true, "arena.pve registered")
check(call("activityRegister", { id = "arena.duel", resource = "op77_arena", label = "Duel", kind = "pvp",
    description = "One on one, best of three.", minPlayers = 2, maxPlayers = 2, botFill = true }) == true, "arena.duel registered")
check(call("activityRegister", { id = "race.trial", resource = "op77_race", label = "Time Trial", kind = "race",
    description = "Alone against the clock.", minPlayers = 1, maxPlayers = 1, botFill = false }) == true, "race.trial registered")
run(1000)

local bucketSeq = 4100000
local function enterAll(ids, activityId, opts)
    bucketSeq = bucketSeq + 1
    for _, id in ipairs(ids) do
        local entered, why = call("activityEnter", id, activityId, opts)
        check(entered == true, string.format("%d could not enter %s: %s", id, activityId, tostring(why)))
        buckets[id] = bucketSeq -- the provider moves its players into its instance
    end
end
local function leaveAll(ids, activityId)
    for _, id in ipairs(ids) do
        if online[id] then
            local left, why = call("activityLeave", id, activityId, { returnPlayer = true })
            check(left == true, string.format("%d could not leave %s: %s", id, activityId, tostring(why)))
            check(buckets[id] == 0, id .. " brought back to the shared city")
        end
    end
    run(500)
end
local function report(id, activityId, payload) TriggerEvent("op77_lightrp:activity:result", id, activityId, payload) end

-- op77_chase server/pve.lua P.resultFor
local function chaseResult(o)
    local escaped = o.outcome == "escaped"
    return { placement = escaped and 1 or 2, score = escaped and 1 or 0, won = escaped, difficulty = "standard",
        stats = { mode = o.mode or "vehicle", outcome = o.outcome, how = o.how, seconds = o.seconds or 0,
            shakes = o.shakes or 0, cops = 4, runners = o.runners or 1, police = o.police or "ncpd",
            difficulty = "standard", stars = o.stars, policeBlocked = o.policeBlocked or nil,
            crew = o.crew or nil, forfeit = o.outcome == "left" or nil },
        reputation = escaped and 20 or 0 }
end
-- one runner, entered from the panel at Standard; his round ends after `seconds`
local function chaseRun(id, o)
    enterAll({ id }, "chase.pve", { difficulty = "standard" })
    run(((o.seconds or 95) + (o.extra or 5)) * 1000, 1000)
    report(id, "chase.pve", chaseResult(o))
    leaveAll({ id }, "chase.pve")
end
-- op77_arena server/lightrp.lua H.reportPve (one row per human of the instance)
local function arenaPve(row, won, durationMs, unranked)
    return { placement = won and 1 or 2, score = (row.kills or 0) * 100 + (row.assists or 0) * 40, won = won == true,
        stats = { kills = row.kills or 0, deaths = row.deaths or 0, assists = row.assists or 0, bestStreak = row.bestStreak or 0,
            durationMs = durationMs, round = 3, teamKills = 12, botKills = won and 3 or 15, players = row.players or 1, bots = 3 },
        reputation = won and 15 or 5, unranked = unranked or nil }
end
-- op77_arena server/lightrp.lua H.noteQuit (a PvE round left early)
local function arenaQuit(row, durationMs)
    return { placement = 2, score = (row.kills or 0) * 100, won = false,
        stats = { kills = row.kills or 0, deaths = row.deaths or 0, assists = row.assists or 0, quit = true, durationMs = durationMs },
        reputation = 0 }
end
local function arenaRun(ids, rows, won, seconds, unranked)
    enterAll(ids, "arena.pve")
    run(seconds * 1000, 1000)
    for _, id in ipairs(ids) do report(id, "arena.pve", arenaPve(rows[id] or rows, won, seconds * 1000, unranked)) end
    leaveAll(ids, "arena.pve")
end

-- ═══ Action slot: Lose Them (NCPD Escape, extraction with 3+ stars, real NCPD) ═══
join(11, "acc-lose")
give(11, "lose_them")
chaseRun(11, { outcome = "escaped", how = "extraction", stars = 2, seconds = 95 })
open(11, "lose_them", "two stars at the extraction")
paidVerdict(11, "two stars at the extraction")
chaseRun(11, { outcome = "escaped", how = "clock", stars = 3, seconds = 165 })
open(11, "lose_them", "the clock, not the extraction")
paidVerdict(11, "the clock")
chaseRun(11, { outcome = "escaped", how = "extraction", stars = 3, seconds = 95, police = "bots" })
open(11, "lose_them", "the bot police")
paidVerdict(11, "the bot police")
chaseRun(11, { outcome = "escaped", how = "extraction", stars = 3, seconds = 95, policeBlocked = true })
open(11, "lose_them", "the game refused the police (policeBlocked)")
paidVerdict(11, "policeBlocked")
chaseRun(11, { outcome = "busted", how = "arrest", stars = 3, seconds = 50 })
open(11, "lose_them", "busted at 50 s (unpaid)")
unpaid(11, "too_short", "busted at 50 s")
-- Standard's extraction opens at 40 s, 450 m away at the nearest by car: a real
-- extraction can land before activity pay's 60 s floor. Unpaid, it still counts.
local before = paidTo(11, "activity_pve")
chaseRun(11, { outcome = "escaped", how = "extraction", stars = 3, seconds = 55 })
unpaid(11, "too_short", "an extraction at 55 s")
check(paidTo(11, "activity_pve") == before, "activity_pay.lua paid nothing for 55 s")
done(11, "lose_them", "a quick extraction (55 s, under pay's floor) with three stars")
give(11, "lose_them")
chaseRun(11, { outcome = "escaped", how = "extraction", stars = 3, seconds = 95 })
done(11, "lose_them", "a paid extraction with three stars against the real NCPD")
check(paidTo(11, "activity_pve") > before, "activity_pay.lua credited the run (the producer's own hook ran too)")
check(told(11, "Lose Them"), "the player is told")

-- ═══ Action slot: Leg Day (NCPD Escape on foot, escaped) ═══
join(12, "acc-leg")
give(12, "leg_day")
chaseRun(12, { mode = "vehicle", outcome = "escaped", how = "extraction", stars = 3, seconds = 95 })
open(12, "leg_day", "by car")
paidVerdict(12, "by car")
chaseRun(12, { mode = "foot", outcome = "busted", how = "arrest", stars = 2, shakes = 1, seconds = 120 })
open(12, "leg_day", "busted on foot")
paidVerdict(12, "busted on foot (a loss still pays its share)")
chaseRun(12, { mode = "foot", outcome = "escaped", how = "clock", stars = 3, seconds = 165, police = "bots" })
open(12, "leg_day", "on foot against the bot police")
paidVerdict(12, "the bot police")
chaseRun(12, { mode = "foot", outcome = "left", stars = 1, seconds = 50 })
open(12, "leg_day", "on foot, left at 50 s")
chaseRun(12, { mode = "foot", outcome = "escaped", how = "extraction", stars = 3, seconds = 58 })
unpaid(12, "too_short", "an extraction on foot at 58 s")
done(12, "leg_day", "a quick extraction on foot (58 s, under pay's floor)")
give(12, "leg_day")
chaseRun(12, { mode = "foot", outcome = "escaped", how = "clock", stars = 3, seconds = 165 })
done(12, "leg_day", "a paid escape on foot by the clock")

-- ═══ Action slot: Five Without a Dirt Nap (arena PvE, bestStreak >= 5) ═══
join(13, "acc-streak")
give(13, "five_streak")
arenaRun({ 13 }, { kills = 6, bestStreak = 4 }, true, 180)
open(13, "five_streak", "a streak of four")
paidVerdict(13, "a streak of four")
local n = #verdicts
arenaRun({ 13 }, { kills = 6, bestStreak = 5 }, true, 180, true)
open(13, "five_streak", "a friendly (unranked) match: activities.lua records nothing")
dropped(n, "an unranked arena result")
enterAll({ 13 }, "arena.pve")
run(180000, 1000)
report(13, "arena.pve", arenaQuit({ kills = 6 }, 180000))
leaveAll({ 13 }, "arena.pve")
open(13, "five_streak", "a quit: no pay, and the quit carries no streak")
unpaid(13, "left", "a quit")
arenaRun({ 13 }, { kills = 6, bestStreak = 5 }, true, 90)
open(13, "five_streak", "90 s: under the 120 s of a paid PvE arena match")
unpaid(13, "too_short", "90 s of arena")
arenaRun({ 13 }, { kills = 6, bestStreak = 5 }, true, 180)
done(13, "five_streak", "a five-kill streak in a paid PvE arena match")
-- the check asks for a paid match, not a win: a loss pays lossShare and counts
join(14, "acc-streak-2")
give(14, "five_streak")
arenaRun({ 14 }, { kills = 7, bestStreak = 6, deaths = 3 }, false, 180)
done(14, "five_streak", "a five-kill streak in a lost (still paid) PvE match")

-- ═══ Action slot: Support Act (arena PvE won, assists >= 1 and > kills) ═══
join(15, "acc-support")
give(15, "support_act")
arenaRun({ 15 }, { kills = 1, assists = 3 }, false, 180)
open(15, "support_act", "a lost match")
paidVerdict(15, "a lost match")
arenaRun({ 15 }, { kills = 2, assists = 2 }, true, 180)
open(15, "support_act", "as many assists as kills")
paidVerdict(15, "as many assists as kills")
arenaRun({ 15 }, { kills = 0, assists = 0 }, true, 180)
open(15, "support_act", "no assist (and no progress: unpaid)")
unpaid(15, "no_progress", "no kill, no assist")
arenaRun({ 15 }, { kills = 1, assists = 3 }, true, 90)
open(15, "support_act", "90 s: unpaid")
unpaid(15, "too_short", "90 s of arena")
arenaRun({ 15 }, { kills = 1, assists = 3 }, true, 180)
done(15, "support_act", "a paid win with three assists and one kill")

-- ═══ Street slot: Nightcap (a paid win, then a drink at a bar within 10 minutes) ═══
local BAR = { x = -1450.0, y = 1030.10, z = 22.56 }  -- 5.6 m from Afterlife (shared/config.lua bar_963)
local STREET = { x = -1300.0, y = 1030.10, z = 22.56 } -- no bar within 150 m
local function slotOf(id, name)
    local inv = LightRP.inventory.player(id)
    for slot = 1, inv.slots do local item = inv.items[slot]; if item and item.name == name then return slot end end
end
local function countOf(id, name)
    local n = 0
    for _, item in pairs(LightRP.inventory.player(id).items) do if item.name == name then n = n + item.count end end
    return n
end
-- the inventory page's use, the client's ready once the bottle is in hand, its finish
-- after the animation (consumables.lua), then inventory.lua applyUse -> onItemUsed
local function drink(id, at)
    pos[id] = { x = at.x, y = at.y, z = at.z }
    local water = countOf(id, "water")
    tokens[LightRpEvents.net.consume] = tokens[LightRpEvents.net.consume] or {}
    tokens[LightRpEvents.net.consume][id] = nil
    actions["inventory.use"](id, { slot = slotOf(id, "water") })
    local token = tokens[LightRpEvents.net.consume][id]
    check(token, id .. " got a consume ticket")
    fromClient(LightRpEvents.net.consumeReady, id, { token = token })
    run(7000)
    fromClient(LightRpEvents.net.consumeFinish, id, { token = token, status = "success" })
    run(250)
    check(countOf(id, "water") == water - 1, id .. " drank one bottle (the item was consumed)")
end
join(21, "acc-nightcap", { at = { x = STREET.x, y = STREET.y, z = STREET.z } })
check(commands["lightrp.giveitem"](0, { "21", "water", "3" }), "staff gives water")
give(21, "nightcap")
arenaRun({ 21 }, { kills = 3 }, false, 180)
paidVerdict(21, "a lost match")
drink(21, BAR)
open(21, "nightcap", "a lost match, then a drink at a bar")
-- op77_race engine.lua sendResult: a finished trial is won = true, alone on the course
enterAll({ 21 }, "race.trial")
run(120000, 1000)
report(21, "race.trial", { placement = 1, score = 1, won = true,
    stats = { mode = "trial", courseId = "watson-loop", finished = true, timeMs = 118000, checkpoints = 12, racers = 1 } })
leaveAll({ 21 }, "race.trial")
paidVerdict(21, "a finished time trial (paid, alone)")
drink(21, BAR)
open(21, "nightcap", "a solo time trial finished, then a drink at a bar")
arenaRun({ 21 }, { kills = 3 }, true, 90)
unpaid(21, "too_short", "a 90 s win")
drink(21, BAR)
open(21, "nightcap", "an unpaid (90 s) win, then a drink at a bar")
arenaRun({ 21 }, { kills = 3 }, true, 180)
paidVerdict(21, "a paid win")
drink(21, STREET)
open(21, "nightcap", "a paid win, then a drink away from any bar")
run(11 * 60000, 1000)
drink(21, BAR)
open(21, "nightcap", "a paid win, then a drink at a bar 11 minutes later")
arenaRun({ 21 }, { kills = 3 }, true, 180)
drink(21, BAR)
done(21, "nightcap", "a paid win, then a drink at a bar within 10 minutes")

-- ═══ Crew slot: Back to Back (arena PvE won together, a kill each, same run) ═══
local BB = { id = "crew-bb", leader = 31, members = { 31, 32, 33 } }
for _, id in ipairs({ 31, 32, 33 }) do
    join(id, "acc-bb-" .. id)
    crews[id] = BB
    give(id, "back_to_back")
end
arenaRun({ 31, 32 }, { [31] = { kills = 3 }, [32] = { kills = 0, assists = 4 } }, true, 180)
open(31, "back_to_back", "the crewmate made no kill")
open(32, "back_to_back", "no kill of his own")
paidVerdict(32, "assists only (still progress, still paid)")
-- two instances entered 40 s apart: not the same run
enterAll({ 31 }, "arena.pve")
run(40000, 1000)
enterAll({ 32 }, "arena.pve")
run(150000, 1000)
report(31, "arena.pve", arenaPve({ kills = 2 }, true, 190000))
report(32, "arena.pve", arenaPve({ kills = 2 }, true, 150000))
leaveAll({ 31, 32 }, "arena.pve")
open(31, "back_to_back", "entered 40 s apart")
open(32, "back_to_back", "entered 40 s apart")
paidVerdict(31, "entered 40 s apart")
paidVerdict(32, "entered 40 s apart")
-- two instances entered in the same second: two matches, each won by its own player
enterAll({ 31 }, "arena.pve")
enterAll({ 32 }, "arena.pve")
check(buckets[31] ~= buckets[32], "two instances")
run(180000, 1000)
report(31, "arena.pve", arenaPve({ kills = 2 }, true, 180000))
report(32, "arena.pve", arenaPve({ kills = 2 }, true, 180000))
leaveAll({ 31, 32 }, "arena.pve")
open(31, "back_to_back", "two matches side by side")
open(32, "back_to_back", "two matches side by side")
paidVerdict(31, "two matches side by side")
paidVerdict(32, "two matches side by side")
arenaRun({ 31, 32 }, { kills = 2 }, false, 180)
open(31, "back_to_back", "a lost match")
paidVerdict(31, "a lost match")
arenaRun({ 31, 32 }, { [31] = { kills = 2 }, [32] = { kills = 1 } }, true, 180)
done(31, "back_to_back", "a paid win together, a kill each")
done(32, "back_to_back", "a paid win together, a kill each")
-- the same partner again in the same ISO week: no
give(31, "back_to_back")
give(32, "back_to_back")
arenaRun({ 31, 32 }, { kills = 2 }, true, 180)
open(31, "back_to_back", "the same partner twice in one week")
open(32, "back_to_back", "the same partner twice in one week")
paidVerdict(31, "the same partner")
paidVerdict(32, "the same partner")
check(told(31, "already done with this citizen this week"), "the reused partner is told")
arenaRun({ 31, 33 }, { kills = 2 }, true, 180)
done(31, "back_to_back", "a new partner this week")
done(33, "back_to_back", "a new partner this week")
open(32, "back_to_back", "not in that match")

-- ═══ Crew slot: Nobody Left Behind (NCPD Escape as a crew, everyone escapes) ═══
local NL = { id = "crew-nl", leader = 41, members = { 41, 42, 43 } }
for _, id in ipairs({ 41, 42, 43 }) do
    join(id, "acc-nl-" .. id)
    crews[id] = NL
    give(id, "nobody_left_behind")
end
-- crews = "together": one instance, each runner's result when HIS round ends
local function crewChase(ids, ends)
    enterAll(ids, "chase.pve", { difficulty = "standard" })
    local at = 0
    for _, e in ipairs(ends) do
        run((e.at - at) * 1000, 1000)
        at = e.at
        if e.drop then drop(e.id)
        else
            report(e.id, "chase.pve", chaseResult({ outcome = e.outcome, how = e.how, stars = 3, seconds = e.at, shakes = e.shakes,
                runners = #ids, crew = true }))
        end
    end
    leaveAll(ids, "chase.pve")
end
crewChase({ 41, 42, 43 }, {
    { id = 41, at = 70, outcome = "escaped", how = "extraction" },
    { id = 42, at = 80, outcome = "escaped", how = "extraction" },
    { id = 43, at = 100, outcome = "busted", how = "arrest", shakes = 1 },
})
for _, id in ipairs({ 41, 42, 43 }) do open(id, "nobody_left_behind", "only 2 of 3 escaped") end
paidVerdict(41, "an escape of the crew")
paidVerdict(42, "an escape of the crew")
-- a crewmate who dropped sends no result: the two who escaped are not enough
crewChase({ 41, 42, 43 }, {
    { id = 43, at = 30, drop = true },
    { id = 41, at = 70, outcome = "escaped", how = "extraction" },
    { id = 42, at = 80, outcome = "escaped", how = "extraction" },
})
for _, id in ipairs({ 41, 42 }) do open(id, "nobody_left_behind", "the third runner dropped") end
join(43, "acc-nl-43")
open(43, "nobody_left_behind", "dropped")
crewChase({ 41, 42 }, {
    { id = 41, at = 52, outcome = "escaped", how = "extraction" },
    { id = 42, at = 90, outcome = "escaped", how = "clock" },
})
unpaid(41, "too_short", "an extraction at 52 s")
done(41, "nobody_left_behind", "both runners of the crew escaped")
done(42, "nobody_left_behind", "both runners of the crew escaped")
give(41, "nobody_left_behind")
give(42, "nobody_left_behind")
crewChase({ 41, 42 }, {
    { id = 41, at = 70, outcome = "escaped", how = "extraction" },
    { id = 42, at = 75, outcome = "escaped", how = "extraction" },
})
open(41, "nobody_left_behind", "the same partner twice in one week")
open(42, "nobody_left_behind", "the same partner twice in one week")
crewChase({ 41, 42, 43 }, {
    { id = 41, at = 65, outcome = "escaped", how = "extraction" },
    { id = 42, at = 70, outcome = "escaped", how = "extraction" },
    { id = 43, at = 90, outcome = "escaped", how = "clock" },
})
for _, id in ipairs({ 41, 42, 43 }) do done(id, "nobody_left_behind", "all three escaped, a new partner for each") end

-- ═══ Weekly: All the Way (a paid ranked duel won in its deciding round) ═══
for _, id in ipairs({ 51, 52, 53 }) do join(id, "acc-aw-" .. id) end
give(51, "all_the_way")
-- op77_arena server/lightrp.lua H.reportMatch, both players in the same tick
local function duel(a, b, aRounds, bRounds, test)
    enterAll({ a, b }, "arena.duel")
    run(90000, 1000)
    for _, id in ipairs({ a, b }) do
        local mine, theirs = id == a and aRounds or bRounds, id == a and bRounds or aRounds
        report(id, "arena.duel", { placement = mine > theirs and 1 or 2, score = mine, won = mine > theirs,
            stats = { kills = mine, deaths = theirs, roundsWon = mine, roundsLost = theirs, format = "1v1", durationMs = 90000 },
            reputation = 0, test = test or nil })
    end
    leaveAll({ a, b }, "arena.duel")
end
before = paidTo(51, "activity_pvp")
duel(51, 52, 2, 1)
done(51, "all_the_way", "a paid duel won 2-1")
check(paidTo(51, "activity_pvp") > before, "the duel was paid (activity_pay.lua's roster saw both players)")
give(51, "all_the_way")
duel(51, 52, 2, 0)
open(51, "all_the_way", "won 2-0: no deciding round")
paidVerdict(51, "won 2-0")
duel(51, 52, 1, 2)
open(51, "all_the_way", "lost in the deciding round")
paidVerdict(51, "lost 1-2")
n = #verdicts
duel(51, 52, 2, 1, true)
open(51, "all_the_way", "a practice duel (test): activities.lua records nothing")
dropped(n, "a practice duel")
before = paidTo(51, "activity_pvp")
duel(51, 52, 2, 1)
open(51, "all_the_way", "the fourth paid meeting of the same pair this hour (repeatPerHour)")
unpaid(51, "repeat", "the same pair a fourth time this hour")
check(paidTo(51, "activity_pvp") == before, "activity_pay.lua refused the repeat")
duel(51, 53, 2, 1)
done(51, "all_the_way", "a deciding round against a new opponent")

-- ═══ Weekly: Both Sides of the Law (Most Wanted: an arrest and an escape, one paid match) ═══
for _, id in ipairs({ 61, 62, 63 }) do join(id, "acc-bs-" .. id); give(id, "both_sides") end
-- op77_chase server/wanted.lua resultFor, every player at the match's end
local function wanted(rows, test)
    local ids = {}
    for _, r in ipairs(rows) do ids[#ids + 1] = r.id end
    enterAll(ids, "chase.wanted")
    run(300000, 1000)
    for _, r in ipairs(rows) do
        report(r.id, "chase.wanted", { placement = r.placement, score = 4 - r.placement, won = r.placement == 1 and not r.forfeit,
            stats = { mode = "vehicle", rounds = #rows, points = 4 - r.placement, runnerMs = 120000, runnerRounds = 1,
                copRounds = #rows - 1, arrests = r.arrests or 0, assists = 0, takedowns = 0, extractions = r.extractions or 0,
                survivals = r.survivals or 0, shakes = 0, busted = 0, players = #rows, forfeit = r.forfeit or nil, bots = test or nil },
            reputation = 10, test = test or nil })
    end
    leaveAll(ids, "chase.wanted")
end
wanted({ { id = 61, placement = 1, arrests = 1, extractions = 1 }, { id = 62, placement = 2, arrests = 2 },
    { id = 63, placement = 3, survivals = 1 } })
done(61, "both_sides", "an arrest and an extraction in a paid match")
open(62, "both_sides", "arrests only")
open(63, "both_sides", "an escape only")
paidVerdict(62, "arrests only")
paidVerdict(63, "an escape only")
local BS = { id = "crew-bs", leader = 61, members = { 61, 62, 63 } }
for _, id in ipairs({ 61, 62, 63 }) do crews[id] = BS end
wanted({ { id = 62, placement = 1, arrests = 1, survivals = 1 }, { id = 61, placement = 2 }, { id = 63, placement = 3 } })
open(62, "both_sides", "every real player in one crew: unpaid")
unpaid(62, "crew", "one crew")
for _, id in ipairs({ 61, 62, 63 }) do crews[id] = nil end
n = #verdicts
wanted({ { id = 62, placement = 1, arrests = 1, extractions = 1 }, { id = 61, placement = 2 }, { id = 63, placement = 3 } }, true)
open(62, "both_sides", "a match with bots (test): activities.lua records nothing")
dropped(n, "a Most Wanted match with bots")
wanted({ { id = 62, placement = 3, arrests = 1, survivals = 1, forfeit = true }, { id = 61, placement = 1 }, { id = 63, placement = 2 } })
open(62, "both_sides", "a forfeit: unpaid")
unpaid(62, "left", "a forfeit")
wanted({ { id = 62, placement = 1, arrests = 1, survivals = 1 }, { id = 61, placement = 2 }, { id = 63, placement = 3 } })
done(62, "both_sides", "an arrest and a survival in a paid match")

-- ═══ Weekly: Lion's Share (top contributor of a world boss that goes down) ═══
local O = { x = 500, y = 500, z = 10 }
local def, why = LightRpMissionDefs.validate({ title = "Burn Notice", description = "", location = "Kabuki", type = "eliminate", enabled = true,
    point = { x = 500, y = 500, z = 10 }, perimeter = { shape = "circle", center = O, radius = 40, minZ = 0, maxZ = 40 },
    starts = { { x = 500, y = 500, z = 10, heading = 0 } },
    spawns = {
        { id = "boss", label = "Juggernaut", position = { x = 505, y = 500, z = 10 }, enemy = "militech", count = 1, trigger = "start" },
        { id = "guards", position = { x = 510, y = 500, z = 10 }, enemy = "militech", count = 2, trigger = "start" },
        { id = "late1", position = { x = 515, y = 500, z = 10 }, enemy = "valentinos", count = 2, trigger = "checkpoint" },
        { id = "late2", position = { x = 520, y = 500, z = 10 }, enemy = "valentinos", count = 1, trigger = "checkpoint" },
    },
    worldBoss = { enabled = true, boss = "boss", health = 50, reward = 30000, minShare = 5, minutes = 10 } })
check(def, tostring(why))
def.id = "wb-1"
LightRP.worldBosses.publish(def) -- what the mission editor does for a mission tagged "World boss"
for i, id in ipairs({ 71, 72, 73 }) do
    join(id, "acc-ls-" .. id, { at = { x = 490 + i * 3, y = 495, z = 10 } })
    give(id, "lions_share")
end
local function bossOut()
    local started, text = commands["worldboss.start"](0, { "burn" })
    check(started, text)
    run(2000)
    local ev = LightRP.worldBosses.current()
    for _, npcId in pairs(ev.bossNpcs) do return npcId end
end
local function hit(npcId, id, amount)
    local n = npcs[npcId]
    n.health = math.max(0, n.health - amount)
    TriggerEvent("onNpcDamaged", tostring(npcId), "player:" .. id, tostring(amount))
end
local boss = bossOut()
check(boss and npcs[boss].maxHealth == 5000, "the boss is out with 50x health")
hit(boss, 71, 3000)
hit(boss, 72, 500)
run(2000)
-- a latecomer's last shot: 10 damage and the kill
hit(boss, 73, 10)
npcs[boss].health = 0
TriggerEvent("onNpcDied", tostring(boss), "player:73")
run(2000)
check(#ended == 1 and ended[1] == true, "world_bosses.lua ended the event as a win (onWorldEventEnded)")
done(71, "lions_share", "the top contributor of a boss that went down")
open(72, "lions_share", "eligible, not the top contributor")
open(73, "lions_share", "the last shot: under the minimum share, ineligible")
check(paidTo(71, "worldboss") > paidTo(72, "worldboss") and paidTo(72, "worldboss") > 0 and paidTo(73, "worldboss") == 0, "the pool shared among the eligible")
run(50000, 1000) -- the cleanup, then the event closes
check(LightRP.worldBosses.current() == nil, "the event closed")
give(72, "lions_share")
boss = bossOut()
hit(boss, 72, 3000)
run(10 * 60000 + 2000, 1000) -- the clock runs out: the boss gets away
check(#ended == 2 and ended[2] == false, "the boss escaped (onWorldEventEnded with success false)")
open(72, "lions_share", "the top contributor of a boss that got away")
run(15000, 1000)
check(LightRP.worldBosses.current() == nil, "the escaped event closed")
boss = bossOut()
hit(boss, 72, 4900)
npcs[boss].health = 0
TriggerEvent("onNpcDied", tostring(boss), "player:72")
run(2000)
check(#ended == 3 and ended[3] == true, "the third boss went down")
done(72, "lions_share", "the top contributor this time")
run(50000, 1000)

-- ═══ Shift: On Call (trauma) and weekly: Good Samaritan, through medical.lua ═══
local MED, MED2 = { x = 100, y = 100, z = 10 }, { x = 200, y = 100, z = 10 }
join(81, "acc-med", { at = { x = MED.x, y = MED.y, z = MED.z }, job = "trauma" })
join(85, "acc-med", { key = "alt", name = "Alt" })                 -- the medic's own other character
join(87, "acc-med-2", { at = { x = MED2.x, y = MED2.y, z = MED2.z }, job = "taxi" })
for _, id in ipairs({ 82, 83, 84, 86 }) do join(id, "acc-pt-" .. id) end
local MC = { id = "crew-med", leader = 81, members = { 81, 86 } }
crews[81], crews[86] = MC, MC
check(commands["lightrp.giveitem"](0, { "81", "trauma_kit", "8" }), "staff gives trauma kits")
check(commands["lightrp.giveitem"](0, { "87", "trauma_kit", "2" }), "staff gives trauma kits")
give(81, "on_call")
give(87, "on_call")
give(81, "good_samaritan")
local function kits(id) return countOf(id, "trauma_kit") end
local function samaritan() return card(81, "good_samaritan").value end
-- the patient goes down next to the medic (the platform's onLifeState), the medic uses a
-- kit from the inventory page, the client answers the prepare, medical.lua's thread does
-- the rest (commit, revive, confirm)
local function treat(medic, patient, opts)
    opts = opts or {}
    local NET = "op77_lightrp:medical"
    if not opts.alreadyDown then
        local m = pos[medic]
        pos[patient], buckets[patient] = { x = m.x + 1.2, y = m.y, z = m.z }, 0
        life[patient] = "dead"
        LightRP.eachModule("onLifeState", patient, "dead")
        run(250)
    end
    check(LightRP.medical.isDowned(patient), patient .. " is unconscious (medical.lua captured the death)")
    tokens[NET] = tokens[NET] or {}
    tokens[NET][medic] = nil
    actions["inventory.use"](medic, { slot = slotOf(medic, "trauma_kit") })
    local token = tokens[NET][medic]
    check(token, medic .. " started a treatment on " .. patient)
    fromClient(NET, medic, { operation = "ready", token = token })
    if opts.interrupt then
        run(2000)
        pos[medic].x = pos[medic].x + 1.0 -- the medic walks off mid-treatment
        run(1000)
        pos[medic].x = pos[medic].x - 1.0
        return
    end
    local n = #stabilized
    run(11000)
    check(#stabilized == n + 1 and stabilized[n + 1].actor == medic and stabilized[n + 1].patient == patient,
        medic .. " stabilized " .. patient .. " (onPatientStabilized from medical.lua)")
    check(life[patient] == "alive" and not LightRP.medical.isDowned(patient), patient .. " is back on his feet")
end
treat(87, 82)
open(87, "on_call", "a taxi driver is not on a trauma shift")
local k = kits(81)
treat(81, 85)
open(81, "on_call", "the patient is the medic's own other character")
check(samaritan() == 0, "Good Samaritan: never your own account")
check(kits(81) == k - 1, "the kit was used")
k = kits(81)
treat(81, 82, { interrupt = true })
check(kits(81) == k, "an interrupted treatment keeps the kit")
check(LightRP.medical.isDowned(82), "and the patient stays down")
open(81, "on_call", "an interrupted treatment")
treat(81, 82, { alreadyDown = true })
done(81, "on_call", "a trauma medic stabilized another citizen")
check(samaritan() == 1, "Good Samaritan: one stranger")
give(81, "on_call")
treat(81, 82)
open(81, "on_call", "the same patient account twice in one week")
check(told(81, "already done with this citizen this week"), "the medic is told")
check(samaritan() == 1, "Good Samaritan: the same stranger counts once")
treat(81, 86)
open(81, "on_call", "a crewmate is never the patient (owner, 2026-11-03: as for Good Samaritan)")
check(samaritan() == 1, "Good Samaritan: never a crewmate")
treat(81, 83)
done(81, "on_call", "a stranger, new this week")
check(samaritan() == 2, "Good Samaritan: two strangers")
open(81, "good_samaritan", "two of three")
treat(81, 84)
done(81, "good_samaritan", "three different strangers outside the crew")

noHookErrors()
print("dailies_flow_activities_test: ok")
