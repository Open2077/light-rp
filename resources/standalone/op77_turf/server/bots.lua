-- op77_turf bots: NPC fighters for staff bot mode (a turf war one human can start) and
-- the NPC gang of a Gang Sweep (turf.pve).
--
-- They fight with the ENGINE's combat AI: aiMode native, a relationship group per side
-- (the two hostile), and per-player attitude rows (friendly to their own side's humans,
-- hostile to the others). The server never scripts movement over a fight: it only sets
-- objectives through movement-channel tasks (guard a zone, moveTo a zone), one new
-- destination per `tasks.retaskMs`, and only once no hit has named the bot for
-- `tasks.combatQuietMs`.
--
-- The server counts them like fighters: zone presence from their canonical positions
-- (Open77.npcs.presence, else get), kills and deaths on the scoreboard, respawn after the
-- war's respawn delay. A respawn is a REBUILD: the corpse is removed after
-- `corpseLingerMs` and a fresh body is created at the deadline (setTransform cannot move a
-- body and a revive leaves a corpse), never in the same tick. Bodies are created one at a
-- time, `spawnSpacingMs` apart, never in the first `spawnSettleMs` of this VM, never while
-- the resource stops.
--
-- Hits: a managed NPC's engine damage is never applied by the platform. Clients report
-- (client/main.lua forwards the engine's open77:npcHit / npcAttackedMe / npcCrossfire)
-- and the server checks (war running, opposite sides, both up, distance, spawn
-- protection), clamps, rate-bounds and applies: Open77.npcs.applyDamage on a bot,
-- Open77.players.damage on a fighter.
--
-- Every Open77.npcs native is looked up and called through B.call (pcall, logged once,
-- degraded when missing: the reference wiki documents a newer build).
--
-- NEVER hand a bot id (negative) to a player native: players.position / name /
-- identifier raise on a non-positive id, through pcall, and stop the resource.
TurfBots = { byNpc = {}, lastHit = {}, created = 0, removed = 0, stopping = false, loadedAt = nil, lastSpawnAt = nil,
    noLoadout = false, noBehavior = false }
local B = TurfBots
local R = TurfRules

local function cfg() return TurfConfig end
local function bc() return TurfConfig.bots end
local function W() return TurfWorld end
local function log(fmt, ...) print(("[op77_turf] " .. fmt):format(...)) end

local warned = {}
local function once(key, fmt, ...)
    if warned[key] then return end
    warned[key] = true
    log(fmt, ...)
end

-- ---------------------------------------------------------------- natives (guarded)

-- Open77.npcs.<path> without raising (constant tables raise on an unknown key).
local function lookup(path)
    if type(Open77) ~= "table" then return nil end
    local ok, t = pcall(function() return Open77.npcs end)
    if not ok or type(t) ~= "table" then return nil end
    for part in path:gmatch("[^%.]+") do
        local fine, v = pcall(function() return t[part] end)
        if not fine or v == nil then return nil end
        t = v
    end
    return t
end

function B.has(path) return type(lookup(path)) == "function" end

-- An Open77.npcs native: its results, or nil plus a reason (missing, raised).
function B.call(path, ...)
    local fn = lookup(path)
    if type(fn) ~= "function" then
        once("missing:" .. path, "bots: Open77.npcs.%s is not on this build (degraded)", path)
        return nil, "unavailable"
    end
    local packed = table.pack(pcall(fn, ...))
    if not packed[1] then
        once("raise:" .. path, "bots: Open77.npcs.%s raised: %s", path, tostring(packed[2]))
        return nil, tostring(packed[2])
    end
    return table.unpack(packed, 2, packed.n)
end

local function constant(group, name, fallback)
    local v = lookup(group .. "." .. name)
    if v == nil then return fallback end
    return v
end

-- Bots are possible at all (world.npcs granted, create/remove on this build).
function B.available() return B.has("create") and B.has("remove") end

-- Teammate bots need a per-player friendly row: without setAttitude, none.
function B.alliesSupported() return B.has("setAttitude") end

-- 64-bit NPC ids are opaque: keyed by their text, never through tonumber.
local function keyOf(npcId)
    if npcId == nil then return nil end
    return tostring(npcId)
end

-- ---------------------------------------------------------------- lifecycle

function B.start(now) B.loadedAt = now end

-- Bodies left by a previous run of this resource (a hot reload empties this VM's tables
-- while the bodies live on): removed once, before the first war. `all()` answers this
-- resource's own NPCs on the running build; `owned` / `resource` are honoured when present.
function B.sweep()
    if not B.has("all") then return 0 end
    local list = B.call("all")
    if type(list) ~= "table" then return 0 end
    local me = GetCurrentResourceName()
    local n = 0
    for _, s in ipairs(list) do
        if type(s) == "table" and s.id ~= nil and B.byNpc[keyOf(s.id)] == nil then
            local mine = s.owned == true or s.resource == me or (s.owned == nil and s.resource == nil)
            if mine then
                B.call("remove", s.id)
                n = n + 1
            end
        end
    end
    if n > 0 then log("bots: removed %d body(ies) left by a previous run", n) end
    return n
end

-- This resource stops: no new body, every body goes.
function B.shutdown(wars)
    B.stopping = true
    for _, war in ipairs(wars or {}) do B.removeAll(war, "resource_stop") end
end

-- ---------------------------------------------------------------- roster

local function ensure(war)
    if war.bots then return war.bots end
    war.bots = {}
    war.nextBotId = -1
    war.botNames = 0
    local tag = tostring(math.tointeger(war.id) or war.id)
    war.botGroups = { "op77_turf_" .. tag .. "_1", "op77_turf_" .. tag .. "_2" }
    return war.bots
end
B.ensure = ensure

local function nextName(war)
    local names = bc().names or {}
    war.botNames = (war.botNames or 0) + 1
    local i = war.botNames
    if #names == 0 then return "Bot " .. i end
    local base = names[(i - 1) % #names + 1]
    local lap = (i - 1) // #names
    return lap > 0 and (base .. " " .. (lap + 1)) or base
end

-- The records a bot of this gang tries, in order: the gang's own, then the fallbacks.
function B.recordsFor(gang)
    local list = {}
    for _, r in ipairs(gang and bc().records[gang] or {}) do list[#list + 1] = r end
    for _, r in ipairs(bc().fallback or {}) do list[#list + 1] = r end
    return list
end

-- A bot on a side, without a body yet (B.tick creates bodies, paced).
--   opts.acquire: it may acquire players on its own (a side with no humans).
--   opts.atZone: its first body stands in its home zone (a Gang Sweep's holders).
function B.add(war, side, now, opts)
    local bots = ensure(war)
    opts = opts or {}
    local id = war.nextBotId
    war.nextBotId = id - 1
    local k = 1
    for _, b in ipairs(bots) do if b.side == side then k = k + 1 end end
    local share = war.kind == "pve" and (cfg().pve.pushShare or 0.34) or (bc().tasks.pushShare or 0.5)
    local every = share > 0 and math.max(1, math.floor(1 / share + 0.5)) or math.huge
    local callsign = nextName(war)
    local bot = { id = id, warId = war.id, side = side, slot = k, callsign = callsign,
        name = (bc().prefix or "[BOT] ") .. callsign, role = (k % every == 0) and "push" or "guard",
        home = ((k - 1) % #war.zones) + 1, records = B.recordsFor(war.sides[side].gang), recordIndex = 1,
        acquire = opts.acquire == true, atZone = opts.atZone == true, state = "pending", nextBodyAt = now,
        kills = 0, deaths = 0, captures = 0, holdSeconds = 0, playedMs = 0, task = {} }
    bots[#bots + 1] = bot
    war.boardDirty = true
    return bot
end

-- The bots a war starts with: staff bot mode fills the sides (R.botFill); a Gang Sweep's
-- NPC gang scales with its humans (R.pveBots). Returns { side1, side2 }.
function B.plan(war, now)
    ensure(war)
    local n = Turf.counts(war)
    local want
    if war.kind == "pve" then
        want = { 0, R.pveBots(n[1] + n[2], cfg().pve) }
    else
        want = R.botFill(n, { perSide = bc().perSide, allies = bc().allies == true and B.alliesSupported(),
            maxPerSide = bc().maxPerSide, maxBots = bc().maxBots })
    end
    for s = 1, 2 do
        for _ = 1, want[s] do B.add(war, s, now, { acquire = n[s] == 0, atZone = war.kind == "pve" and s == 2 }) end
    end
    log("bots: war %d (%s) planned %d + %d bot(s), %s vs %s", war.id, tostring(war.kind), want[1], want[2],
        tostring(war.sides[1].gang), tostring(war.sides[2].gang))
    return want
end

-- A Gang Sweep grew (a crew member came in late): more gangers.
function B.scale(war, now)
    if war.kind ~= "pve" then return 0 end
    local n = Turf.counts(war)
    local want = R.pveBots(n[1] + n[2], cfg().pve)
    local added = 0
    while B.count(war, 2) < want do
        B.add(war, 2, now, { acquire = true })
        added = added + 1
    end
    return added
end

-- Bots of a side still in the war (with or without a body).
function B.count(war, side)
    local n = 0
    for _, b in ipairs(war.bots or {}) do
        if b.state ~= "gone" and (side == nil or b.side == side) then n = n + 1 end
    end
    return n
end

function B.get(war, botId)
    for _, b in ipairs(war.bots or {}) do if b.id == botId then return b end end
    return nil
end

-- The bot (and its war) of an NPC id, or nil.
function B.ofNpc(npcId)
    local bot = npcId ~= nil and B.byNpc[keyOf(npcId)] or nil
    if not bot then return nil end
    local war = Turf.warById(bot.warId)
    if not war then return nil end
    return bot, war
end

-- Scoreboard rows (negative ids: never a player's).
function B.rows(war, scoring)
    local rows = {}
    for _, b in ipairs(war.bots or {}) do
        if not b.failed and not b.retired then
            rows[#rows + 1] = { id = b.id, name = b.name, side = b.side, bot = true, kills = b.kills, deaths = b.deaths,
                captures = b.captures, score = R.personalScore(b, scoring) }
        end
    end
    return rows
end

-- ---------------------------------------------------------------- bodies

-- UNBIND BEFORE REMOVING: remove raises onNpcRemoved, which must not see our own removals.
local function releaseBody(bot, reason)
    local npcId = bot.npcId
    if npcId == nil then return false end
    if bot.npcKey then B.byNpc[bot.npcKey] = nil end
    bot.npcId, bot.npcKey = nil, nil
    B.call("tasks.clear", npcId, nil, reason or "released")
    B.call("remove", npcId)
    B.removed = B.removed + 1
    return true
end

local function spawnPoint(war, bot)
    local p
    if bot.respawning then
        p = R.respawnPoint(war, war.site, bot.side, bot.slot, bot.deathPos, cfg().life)
    elseif bot.atZone and war.zones[bot.home] then
        local def = war.zones[bot.home].def
        p = { x = def.x, y = def.y, z = def.z, heading = 0 }
    else
        p = R.sideSpawn(war.site, bot.side, bot.slot)
    end
    -- On a ring around the point, so bodies (and fighters) never stack.
    local r = bc().spawnRing or 2.5
    local angle = math.rad((bot.slot * 137.5 + 45) % 360)
    return { x = p.x + math.cos(angle) * r, y = p.y + math.sin(angle) * r, z = p.z + (bc().spawnLiftMetres or 0.35),
        heading = p.heading or 0 }
end

local function createBody(war, bot, point)
    local name = bot.records[bot.recordIndex]
    if name == nil then return nil, "no_record" end
    local health = bc().health or 100
    local def = {
        position = { x = point.x, y = point.y, z = point.z }, yaw = point.heading or 0, bucket = war.bucket,
        -- Integers (a string raises in CreateNpc): native combat, mortal.
        aiMode = constant("ai", "native", 2), damagePolicy = constant("damage", "mortal", 0),
        health = health, maxHealth = health,
        streamingRadius = bc().streamingRadius, streamingHysteresis = bc().streamingHysteresis,
        despawnWhenUnobserved = false, persistent = false,
    }
    if tostring(name):find("^Character%.") then def.record = name else def.template = name end
    if not B.noLoadout then
        -- Same group = friendly; acquirePlayers lets a side without humans go for them.
        def.loadout = { combat = { group = war.botGroups[bot.side], acquirePlayers = bot.acquire == true } }
    end
    if not B.noBehavior then
        -- Hits are priced here (onPlayerHit / onCrossfire), never by the platform as well.
        def.behavior = { hitPricing = "resource" }
    end
    local npcId, why = B.call("create", def)
    if (npcId == nil or npcId == false) and def.behavior and tostring(why):lower():find("behavio") then
        B.noBehavior = true
        once("nobehavior", "bots: create refused behavior.hitPricing (%s): the build's default pricing applies", tostring(why))
        def.behavior = nil
        npcId, why = B.call("create", def)
    end
    if (npcId == nil or npcId == false) and def.loadout and tostring(why):lower():find("loadout") then
        B.noLoadout = true
        once("noloadout", "bots: create refused the combat loadout (%s): bodies without a relationship group", tostring(why))
        def.loadout = nil
        npcId, why = B.call("create", def)
    end
    if npcId == nil or npcId == false then return nil, tostring(why) end
    B.created = B.created + 1
    return npcId
end

local function canSpawn(now)
    if B.stopping then return false end
    if B.loadedAt and now - B.loadedAt < (bc().spawnSettleMs or 5000) then return false end
    if B.lastSpawnAt and now - B.lastSpawnAt < (bc().spawnSpacingMs or 400) then return false end
    return true
end

-- Attitude rows towards one fighter: friendly to its own side's humans, hostile otherwise.
local function attitudeTowards(bot, m)
    if bot.npcId == nil or not B.has("setAttitude") then return end
    local ok, why = B.call("setAttitude", bot.npcId, m.side == bot.side and "friendly" or "hostile", { towards = m.id })
    if ok ~= true then once("attitude:" .. tostring(why), "bots: setAttitude refused (%s)", tostring(why)) end
end

-- The war's two groups regard each other as hostile (once per war, per resource).
local function relate(war)
    if war.botRelated then return end
    war.botRelated = true
    if not B.has("setRelationship") then return end
    local ok, why = B.call("setRelationship", war.botGroups[1], war.botGroups[2], "hostile")
    if ok ~= true then once("relationship", "bots: setRelationship refused (%s)", tostring(why)) end
end

function B.hostility(war, bot)
    relate(war)
    for _, id in ipairs(war.order) do
        local m = war.members[id]
        if Turf.present(m) then attitudeTowards(bot, m) end
    end
end

-- A fighter joined the war (late, or back): every living bot's row towards him.
function B.welcome(war, m)
    for _, bot in ipairs(war.bots or {}) do
        if bot.state == "alive" then attitudeTowards(bot, m) end
    end
end

local function spawn(war, bot, now)
    B.lastSpawnAt = now
    local point = spawnPoint(war, bot)
    local npcId, why
    while true do
        npcId, why = createBody(war, bot, point)
        if npcId ~= nil or bot.recordIndex >= #bot.records or why == "unavailable" then break end
        bot.recordIndex = bot.recordIndex + 1
    end
    if npcId == nil then
        bot.state, bot.failed = "gone", true
        log("bots: war %d %s has no body (%s): left out", war.id, bot.name, tostring(why))
        war.boardDirty = true
        return false
    end
    bot.npcId, bot.npcKey = npcId, keyOf(npcId)
    B.byNpc[bot.npcKey] = bot
    bot.state = "alive"
    bot.bornAt, bot.health = now, bc().health or 100
    bot.lastPos = { x = point.x, y = point.y, z = point.z, bucket = war.bucket }
    bot.task, bot.lastCombatAt, bot.lastAttacker, bot.outSince, bot.outMoved, bot.noAuthSince = {}, nil, nil, nil, nil, nil
    bot.respawning = nil
    B.hostility(war, bot)
    war.boardDirty = true
    if war.state == "running" then B.order(war, bot, now) end
    return true
end

-- Body gone or wrong: removed now, rebuilt (paced) at its side's spawn or a held zone.
local function rebuild(war, bot, now, reason, nextRecord)
    log("bots: war %d %s rebuilt (%s)", war.id, bot.name, tostring(reason))
    releaseBody(bot, reason)
    if nextRecord and bot.recordIndex < #bot.records then bot.recordIndex = bot.recordIndex + 1 end
    bot.state, bot.respawning = "pending", true
    bot.deathPos = nextRecord and bot.lastPos or nil
    bot.nextBodyAt = now + (bc().corpseLingerMs or 1200)
end

-- A late human took a bot's place on a side (staff bot mode keeps the numbers).
function B.retire(war, side, now)
    local pick
    for i = #(war.bots or {}), 1, -1 do
        local b = war.bots[i]
        if b.side == side and b.state ~= "gone" then
            if b.state ~= "alive" then pick = b break end
            pick = pick or b
        end
    end
    if not pick then return nil end
    releaseBody(pick, "retired")
    pick.state, pick.retired = "gone", true
    war.boardDirty = true
    log("bots: war %d %s retired (a fighter took its place)", war.id, pick.name)
    return pick
end

-- Every body of a war goes (war over, last human gone, resource or core stopped).
function B.removeAll(war, reason)
    if not war.bots then return 0 end
    local n = 0
    for _, bot in ipairs(war.bots) do
        if releaseBody(bot, reason) then n = n + 1 end
        bot.state = "gone"
    end
    for victim, hit in pairs(B.lastHit) do if hit.warId == war.id then B.lastHit[victim] = nil end end
    B.forgetWindows(war)
    if n > 0 then log("bots: war %d removed %d body(ies) (%s)", war.id, n, tostring(reason)) end
    return n
end

-- ---------------------------------------------------------------- positions

-- { x, y, z, bucket, alive, authority } from the canonical place, or nil plus "gone"
-- when the platform no longer knows the body.
function B.read(bot)
    if bot.npcId == nil then return nil end
    if B.has("presence") then
        local p, why = B.call("presence", bot.npcId)
        if type(p) == "table" and tonumber(p.x) then
            return { x = tonumber(p.x), y = tonumber(p.y), z = tonumber(p.z), bucket = tonumber(p.bucket),
                alive = p.alive ~= false, authority = tonumber(p.authorityPlayerId) }
        end
        if why == "npc_not_found" then return nil, "gone" end
    end
    if not B.has("get") then return nil end
    local s = B.call("get", bot.npcId)
    if type(s) ~= "table" then return nil, "gone" end
    local pos = type(s.position) == "table" and s.position or s
    local x, y, z = tonumber(pos.x), tonumber(pos.y), tonumber(pos.z)
    if not x then return nil end
    local health = tonumber(s.health)
    return { x = x, y = y, z = z, bucket = tonumber(s.bucket), alive = s.alive ~= false and (health == nil or health > 0),
        authority = tonumber(s.authorityPlayerId), health = health }
end

-- ---------------------------------------------------------------- objectives

local function movementChannel() return constant("channels", "movement", nil) end

local function issueMove(bot, def)
    local t = bc().tasks
    B.call("tasks.clear", bot.npcId, movementChannel(), "retask")
    B.call("tasks.moveTo", bot.npcId, { x = def.x, y = def.y, z = def.z },
        { speed = t.speed or "run", acceptanceRadius = 2.0, timeoutMs = t.moveTimeoutMs or 30000 })
end

local function issueGuard(bot, def)
    local t = bc().tasks
    local radius = math.max(2, math.min(100, (def.radius or 6) + (t.guardRadius or 3)))
    B.call("tasks.clear", bot.npcId, movementChannel(), "retask")
    B.call("tasks.guard", bot.npcId, { x = def.x, y = def.y, z = def.z }, radius, { speed = t.speed or "run" })
end

-- The zone a bot should be at. Guards: their home zone. Pushers: the nearest zone their
-- side does not hold (the enemy's before a neutral one), else one the enemy is taking,
-- else home.
function B.objective(war, bot)
    if bot.role == "push" then
        local enemy = bot.side == 1 and 2 or 1
        local p = bot.lastPos
        local best, bestScore
        for i, zone in ipairs(war.zones) do
            if zone.owner ~= bot.side then
                local d = p and ((zone.def.x - p.x) ^ 2 + (zone.def.y - p.y) ^ 2) or i
                local score = (zone.owner == enemy and 0 or 1e12) + d
                if bestScore == nil or score < bestScore then best, bestScore = i, score end
            end
        end
        if best then return best end
        for i, zone in ipairs(war.zones) do
            if zone.capturing == enemy and (zone.progress or 0) > 0 then return i end
        end
    end
    return bot.home
end

-- Gives a bot its objective when it changed (the zone picture moved, it arrived, or a
-- move ran out). Far from the zone: moveTo first; there: a guard leash. Gated: one new
-- destination per retaskMs, never while a hit named it in the last combatQuietMs.
function B.order(war, bot, now)
    if bot.state ~= "alive" or bot.npcId == nil then return false end
    local t = bc().tasks
    local zi = B.objective(war, bot)
    local zone = war.zones[zi]
    if not zone then return false end
    local def = zone.def
    local p = bot.lastPos
    local reach = (def.radius or 6) + (t.arriveMetres or 8)
    local far = p ~= nil and ((def.x - p.x) ^ 2 + (def.y - p.y) ^ 2) > reach * reach
    local kind = far and "move" or "guard"
    local task = bot.task or {}
    local expired = task.kind == "move" and now - (task.at or 0) >= (t.moveTimeoutMs or 30000)
    if task.zone == zi and task.kind == kind and not expired then return false end
    if task.at and now - task.at < (t.retaskMs or 6000) then return false end
    if bot.lastCombatAt and now - bot.lastCombatAt < (t.combatQuietMs or 5000) then return false end
    if kind == "move" then issueMove(bot, def) else issueGuard(bot, def) end
    bot.task = { zone = zi, kind = kind, at = now }
    return true
end

function B.retask(war, now)
    for _, bot in ipairs(war.bots or {}) do B.order(war, bot, now) end
end

-- ---------------------------------------------------------------- the war's clock

-- 4 Hz, every state: corpses go, the dead come back at their deadline, one body per
-- spacing is created.
function B.tick(war, now)
    if not war.bots then return end
    local live = war.state == "running" or war.state == "countdown"
    for _, bot in ipairs(war.bots) do
        if bot.state == "down" then
            if bot.npcId == nil then
                if live and now >= (bot.respawnAt or now) then
                    bot.state, bot.respawning, bot.nextBodyAt = "pending", true, now
                end
            elseif now >= (bot.corpseAt or now) then
                releaseBody(bot, "corpse")
            end
        end
    end
    if war.state ~= "placing" and not live then return end
    if not canSpawn(now) then return end
    for _, bot in ipairs(war.bots) do
        if bot.state == "pending" and bot.npcId == nil and now >= (bot.nextBodyAt or 0) then
            spawn(war, bot, now)
            return
        end
    end
end

local function bounds(war, bot, p, now)
    if R.inBounds(war.site.bounds, p) then bot.outSince, bot.outMoved = nil, nil return end
    bot.outSince = bot.outSince or now
    local out = now - bot.outSince
    if out >= (bc().rebuildAfterSeconds or 16) * 1000 then
        rebuild(war, bot, now, "out_of_bounds", false)
    elseif out >= (bc().outOfBoundsSeconds or 8) * 1000 and not bot.outMoved then
        -- A soft move back towards its objective (inside the site), whatever the gates.
        bot.outMoved = true
        local zi = B.objective(war, bot)
        issueMove(bot, war.zones[zi].def)
        bot.task = { zone = zi, kind = "move", at = now }
    end
end

-- 1 Hz, running: positions into the zone counts (counts[i][side]), a health backstop
-- for a missed death, bounds, and the authority watchdog (a record the clients cannot
-- build leaves a body nobody simulates: rebuilt with the next record).
function B.step(war, now, counts, dt)
    if not war.bots then return end
    local cap = cfg().capture
    local placed = false
    for _, id in ipairs(war.order) do
        local m = war.members[id]
        if Turf.present(m) and m.placed then placed = true break end
    end
    for _, bot in ipairs(war.bots) do
        bot.zoneIndex = nil
        if bot.state == "alive" then
            bot.playedMs = (bot.playedMs or 0) + dt * 1000
            local r, gone = B.read(bot)
            if gone == "gone" then
                rebuild(war, bot, now, "vanished", false)
            elseif r and r.alive == false then
                Turf.botDied(war, bot, B.killerOf(bot, nil, now), now)
            elseif r then
                bot.lastPos = r
                if r.bucket == nil or r.bucket == war.bucket then
                    for i, zone in ipairs(war.zones) do
                        if R.inZone(zone.def, r, cap.height) then
                            bot.zoneIndex = i
                            counts[i][bot.side] = counts[i][bot.side] + 1
                            break
                        end
                    end
                end
                if r.authority ~= nil and placed then
                    if r.authority == 0 then
                        bot.noAuthSince = bot.noAuthSince or now
                        if now - bot.noAuthSince >= (bc().authorityTimeoutMs or 30000) then
                            rebuild(war, bot, now, "no client simulates it (record " .. tostring(bot.records[bot.recordIndex]) .. ")", true)
                        end
                    else
                        bot.noAuthSince = nil
                    end
                end
                if bot.state == "alive" then bounds(war, bot, r, now) end
            end
        end
    end
end

-- Time on a zone its side holds or is taking.
function B.hold(war, dt)
    for _, bot in ipairs(war.bots or {}) do
        local zone = bot.state == "alive" and bot.zoneIndex and war.zones[bot.zoneIndex]
        if zone and (zone.owner == bot.side or zone.capturing == bot.side) then
            bot.holdSeconds = (bot.holdSeconds or 0) + dt
        end
    end
end

-- The bots standing in a zone their side just captured: a capture each. Returns names.
function B.creditCapture(war, zoneIndex, side)
    local names = {}
    for _, bot in ipairs(war.bots or {}) do
        if bot.state == "alive" and bot.side == side and bot.zoneIndex == zoneIndex then
            bot.captures = bot.captures + 1
            names[#names + 1] = bot.name
        end
    end
    return names
end

-- Down: the corpse lingers, the respawn deadline is set. `counted` = a death on the board.
function B.markDown(war, bot, now, counted)
    if bot.state ~= "alive" then return false end
    bot.state = "down"
    bot.downAt, bot.deathPos, bot.zoneIndex = now, bot.lastPos, nil
    bot.corpseAt = now + (bc().corpseLingerMs or 1200)
    bot.respawnAt = now + (cfg().life.respawnSeconds or 6) * 1000
    if counted then bot.deaths = bot.deaths + 1 end
    return true
end

-- ---------------------------------------------------------------- hits

local windows, lastPair = {}, {}

local function bounded(window, pair, amount, ceiling, interval, now)
    local last = lastPair[pair]
    if last and now - last < interval then return false end
    local w = windows[window]
    if not w or now - w.at >= 1000 then
        w = { at = now, amount = 0 }
        windows[window] = w
    end
    if w.amount + amount > ceiling then return false end
    w.amount = w.amount + amount
    lastPair[pair] = now
    return true
end

function B.forgetWindows(war)
    local prefix = "w" .. tostring(war.id) .. ":"
    for k in pairs(windows) do if k:sub(1, #prefix) == prefix then windows[k] = nil end end
    for k in pairs(lastPair) do if k:sub(1, #prefix) == prefix then lastPair[k] = nil end end
end

local function amountOf(damage)
    local d = bc().damage
    local n = tonumber(damage)
    if n == nil or n ~= n or n <= 0 then n = d.fallback or 18 end
    return math.min(n, d.maxPerHit or 34)
end

-- Unknown positions never refuse a hit.
local function near(a, b, max)
    if type(a) ~= "table" or type(b) ~= "table" or type(a.x) ~= "number" or type(b.x) ~= "number" then return true end
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return dx * dx + dy * dy + dz * dz <= max * max
end

-- A fighter's client says he hit a bot (open77:npcHit).
function B.onPlayerHit(playerId, npcId, damage, now)
    local bot, war = B.ofNpc(npcId)
    if not bot then return false, "unknown_npc" end
    local m = war.members[playerId]
    if not Turf.present(m) then return false, "not_in_war" end
    if war.state ~= "running" then return false, "not_running" end
    if m.down or not m.placed then return false, "shooter_down" end
    if bot.state ~= "alive" then return false, "bot_down" end
    if bot.side == m.side then return false, "same_side" end
    local d = bc().damage
    if not near(W().position(playerId), bot.lastPos, d.maxDistance or 150) then return false, "too_far" end
    local amount = amountOf(damage)
    local w = "w" .. tostring(war.id) .. ":"
    if not bounded(w .. "bot" .. bot.id, w .. "p" .. playerId .. ">" .. bot.id, amount, d.perSecond or 90,
        d.pairIntervalMs or 90, now) then
        return false, "rate"
    end
    m.protectedUntil = nil -- firing breaks spawn protection
    local applied = B.call("applyDamage", bot.npcId, amount, "player:" .. tostring(playerId), "firearm")
    if applied ~= true then return false, "refused" end
    bot.lastAttacker = { kind = "player", id = playerId, at = now }
    bot.lastCombatAt = now
    return true, amount
end

-- A fighter's client says a bot hit him (open77:npcAttackedMe).
function B.onBotHit(playerId, npcId, damage, now)
    local bot, war = B.ofNpc(npcId)
    if not bot then return false, "unknown_npc" end
    local m = war.members[playerId]
    if not Turf.present(m) then return false, "not_in_war" end
    if war.state ~= "running" then return false, "not_running" end
    if m.down or not m.placed then return false, "victim_down" end
    if bot.state ~= "alive" then return false, "bot_down" end
    if bot.side == m.side then return false, "same_side" end
    if (m.protectedUntil or 0) > now then return false, "protected" end
    local d = bc().damage
    if not near(W().position(playerId), bot.lastPos, d.maxDistance or 150) then return false, "too_far" end
    local amount = amountOf(damage)
    local w = "w" .. tostring(war.id) .. ":"
    if not bounded(w .. "p" .. playerId, w .. "b" .. bot.id .. ">" .. playerId, amount, d.perSecond or 90,
        d.pairIntervalMs or 90, now) then
        return false, "rate"
    end
    local ok, why = W().damagePlayer(playerId, amount, bot.npcId)
    if not ok then
        once("hurt:" .. tostring(why), "bots: a bot's hit on a fighter was refused (%s)", tostring(why))
        return false, why
    end
    B.lastHit[playerId] = { warId = war.id, botId = bot.id, at = now }
    bot.lastCombatAt = now
    return true, amount
end

-- Bot against bot, reported by the client simulating the victim (open77:npcCrossfire).
function B.onCrossfire(reporterId, victimNpc, attackerNpc, damage, now)
    local victim, war = B.ofNpc(victimNpc)
    local attacker, other = B.ofNpc(attackerNpc)
    if not victim or not attacker or war ~= other then return false, "unknown_npc" end
    if not Turf.present(war.members[reporterId]) then return false, "not_in_war" end
    if war.state ~= "running" then return false, "not_running" end
    if victim.state ~= "alive" or attacker.state ~= "alive" then return false, "down" end
    if victim.side == attacker.side then return false, "same_side" end
    if B.has("presence") then
        local p = B.call("presence", victim.npcId)
        local holder = type(p) == "table" and tonumber(p.authorityPlayerId) or nil
        if holder and holder > 0 and holder ~= reporterId then return false, "not_lease_holder" end
    end
    local d = bc().damage
    local amount = amountOf(damage)
    local w = "w" .. tostring(war.id) .. ":"
    if not bounded(w .. "bot" .. victim.id, w .. "x" .. attacker.id .. ">" .. victim.id, amount, d.perSecond or 90,
        d.pairIntervalMs or 90, now) then
        return false, "rate"
    end
    local tag = "bot:" .. tostring(attacker.id)
    local applied
    if B.has("applyCrossfireDamage") then
        applied = B.call("applyCrossfireDamage", victim.npcId, attacker.npcId, amount, tag, "firearm")
    else
        applied = B.call("applyDamage", victim.npcId, amount, tag, "firearm")
    end
    if applied ~= true then return false, "refused" end
    victim.lastAttacker = { kind = "bot", id = attacker.id, at = now }
    victim.lastCombatAt, attacker.lastCombatAt = now, now
    return true, amount
end

-- ---------------------------------------------------------------- platform events

local function tagged(tag)
    local s = tostring(tag or "")
    local player = s:match("^player:(%d+)$")
    if player then return { kind = "player", id = math.tointeger(tonumber(player)) } end
    local other = s:match("^bot:(%-%d+)$")
    if other then return { kind = "bot", id = math.tointeger(tonumber(other)) } end
    return nil
end

-- Who killed a bot: the death's source tag, else its last attacker within the window.
function B.killerOf(bot, tag, now)
    local k = tagged(tag)
    if k then return k end
    local last = bot.lastAttacker
    if last and now - (last.at or 0) <= (bc().creditWindowMs or 10000) then return last end
    return nil
end

function B.onNpcDied(npcId, tag, cause, now)
    local bot, war = B.ofNpc(npcId)
    if not bot then return false end
    return Turf.botDied(war, bot, B.killerOf(bot, tag, now), now)
end

function B.onNpcDamaged(npcId, tag, amount, health, now)
    local bot = B.ofNpc(npcId)
    if not bot then return false end
    bot.health = tonumber(health) or bot.health
    bot.lastCombatAt = now
    local k = tagged(tag)
    if k then k.at = now; bot.lastAttacker = k end
    return true
end

-- The platform removed a body we did not (our own removals unbind first): rebuilt.
function B.onNpcRemoved(npcId, reason, now)
    local bot, war = B.ofNpc(npcId)
    if not bot then
        B.byNpc[keyOf(npcId) or ""] = nil
        return false
    end
    B.byNpc[bot.npcKey] = nil
    bot.npcId, bot.npcKey = nil, nil
    log("bots: war %d %s lost its body (%s)", war.id, bot.name, tostring(reason))
    if bot.state == "alive" then
        bot.state, bot.respawning, bot.deathPos = "pending", true, bot.lastPos
        bot.nextBodyAt = now + (bc().corpseLingerMs or 1200)
    end
    return true
end

-- The bot that last hit this fighter, within the credit window (his killer when the
-- death event names nobody of the war).
function B.lastHitOn(war, playerId, now)
    local hit = B.lastHit[playerId]
    if not hit or hit.warId ~= war.id or now - hit.at > (bc().creditWindowMs or 10000) then return nil end
    return B.get(war, hit.botId)
end

-- ---------------------------------------------------------------- staff readout

function B.describe(war)
    local lines = {}
    for _, b in ipairs(war.bots or {}) do
        lines[#lines + 1] = ("    %d %s side=%d %s %s %d/%d/%d record=%s npc=%s"):format(b.id, b.name, b.side, b.role, b.state,
            b.kills, b.deaths, b.captures, tostring(b.records[b.recordIndex]), tostring(b.npcKey))
    end
    return lines
end
