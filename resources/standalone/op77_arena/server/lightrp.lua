-- op77_arena: the Light RP adapter. Loaded after server/main.lua and server/core.lua.
--
-- The Deathmatch engine (instances.lua ... main.lua) stays as upstream shipped it in
-- Freeroam; this file plugs it into Light RP's activity contract through the seams
-- the engine resolves at call time (`Deathmatch.place`, `.sendToLobby`, `.leave`,
-- `.round.join`, `.round.begin`, `.round.finish`, `.arena.enqueue`, `.arena.sideOf`,
-- `.setTeam`, `.ranked.recordRound`, `.notice`, `.playerName`, `.loadout.strip`,
-- `.instances.open`) plus the hooks added to the engine (main.lua `moveBody`,
-- `wantsState`, `Config.placeOnJoin`; arena.lua `Arena.planRoster`; bots.lua
-- `dropPending`; the `pve` ruleset in instances.lua):
--
--   admission  activityCheck before any join or queue; activityEnter at the first
--              placement into an instance (still in the city, bucket 0)
--   movement   teleport the living, respawn the dead -- never kill -> respawn as a
--              way in or a way home
--   way home   strip the arena weapons, stand a downed player up, activityLeave:
--              Light RP brings them back (bucket, health, RP weapons)
--   results    one result per FFA round and per arena match; reputation, no cash
--   duels      /duel <id> challenges, a random duel queue, best of three
--   Arena Night  a staff-run special Combat Zone round, announced through Light RP
--   bot mode   staff `/lightrp.bots on` (op77_lightrp): the engine's own bots fill
--              Combat Zone, Blade Night and Team Arena, `/duel bot`; nothing is
--              recorded (results go out as `test`, no career, round or rating row)
--   crews      options.squad: one crew, one instance, one side (`Arena.planRoster`)
--   PvE        arena.pve: the players, one side, against engine bots; recorded with
--              lower reputation and a minimum round length, never rated

local Config = DeathmatchConfig
local DM = Deathmatch
local L = LightRpArena
local Core = ArenaCore
local ACT = L.activities

ArenaHost = {}
local H = ArenaHost

H.entered = {}     -- playerId -> { activity, atMs, instanceId, landed, totals }
H.returning = {}   -- playerId -> true while the way home runs
H.released = {}    -- playerId -> true: Light RP already let go (dropped)
H.recent = {}      -- playerId -> ms until which engine states are still pushed
H.throttle = {}    -- playerId -> ms of the last join attempt
H.checks = {}      -- playerId -> { activity, ok, why, atMs }
H.names = {}       -- playerId -> character name (activityPlayer)
H.identities = {}  -- playerId -> account identifier (activityPlayer)
H.duelQueue = {}   -- { { playerId, atMs } }, the random duel queue
H.invites = {}     -- target playerId -> { from, atMs }
H.evicting = {}    -- playerId -> true while an entry the core refused is undone
H.lastQueued = {}  -- playerId -> engine queue format, last tick
H.duelPairs = {}   -- "idA|idB|day" -> rewarded duels
H.reported = setmetatable({}, { __mode = "k" }) -- arena match -> true
H.snaps = setmetatable({}, { __mode = "k" })    -- arena instance -> last round sample
H.night = nil      -- { untilMs, minutes, by }
H.formingDuel = false
H.stopped = false
H.quietQueue = false -- true while the adapter queues someone on their behalf
H.botMode = false    -- staff bot mode (op77_lightrp /lightrp.bots), off at every start
H.botFill = setmetatable({}, { __mode = "k" })   -- instance -> { base, queued, atMs }: paced spawns on their way
H.botRounds = setmetatable({}, { __mode = "k" }) -- FFA round / arena match -> true: it had bots
H.squads = {}        -- playerId -> { id, leader, members, atMs } (options.squad of their last join)
H.teamQueuedAt = {}  -- playerId -> ms they entered a team queue
H.teamUpgraded = {}  -- playerId -> true: their team queue entry accepts bots

local engine = {
    place = DM.place,
    sendToLobby = DM.sendToLobby,
    leave = DM.leave,
    join = DM.round.join,
    finish = DM.round.finish,
    enqueue = DM.arena.enqueue,
    notice = DM.notice,
    playerName = DM.playerName,
    strip = DM.loadout.strip,
    open = DM.instances.open,
    begin = DM.round.begin,
    setTeam = DM.setTeam,
    sideOf = DM.arena.sideOf,
}
H.engine = engine

local function now() return DM.nowMs() end
local function pid(value) return DM.playerId(value) end
local function log(text) DM.log("lightrp: " .. tostring(text)) end

local function keyOf(activityId)
    for key, def in pairs(ACT) do
        if def.id == activityId then return key end
    end
    return nil
end
H.keyOf = keyOf

local function labelOf(activityId)
    local key = keyOf(activityId)
    return key and ACT[key].label or "the arena"
end

local function activityOfInstance(instance)
    if instance == nil then return nil end
    if instance.format == "ffa" then
        if instance.ruleset == "blade" then return ACT.blade.id end
        if instance.ruleset == "pve" then return ACT.pve.id end
        return ACT.ffa.id
    end
    if instance.format == "1v1" then return ACT.duel.id end
    return ACT.teams.id
end
H.activityOfInstance = activityOfInstance

local function connected(id)
    return id ~= nil and Open77.players.name(id) ~= nil
end

-- ---------------------------------------------------------------------------
-- Talking to players

local NOTICE_KINDS = { info = true, success = true, warning = true, error = true }

-- A Light RP notice (outside a match, where no activity HUD is up).
function H.tell(playerId, kind, title, body, durationMs)
    if type(playerId) ~= "number" or playerId <= 0 then return end
    TriggerClientEvent("op77_lightrp:notice", playerId, {
        kind = NOTICE_KINDS[kind] and kind or "info",
        title = tostring(title or L.source),
        body = tostring(body or ""),
        source = L.source,
        durationMs = durationMs or 5000,
    })
end

local function reply(source, raw, ok, text)
    if source == nil or source <= 0 then print(text) return end
    TriggerClientEvent("open77:command:result", source, raw or "", ok == true, text)
end

-- In a match, the client turns engine notices into HUD banners (client/hud.lua);
-- out of one, they become Light RP notices. Spawn-shield and resupply cards are
-- dropped: the HUD shows the shield, and a resupply every respawn is noise.
local SILENT = { protectionOn = true, resupplied = true }
local EVICT_SILENT = { joined = true, leftMatch = true, placementFailed = true, roundWeapon = true, roundStart = true }

function H.inMatch(playerId)
    return DM.instances.of(playerId) ~= nil or H.entered[playerId] ~= nil
end

DM.notice = function(playerId, kind, key, ...)
    if type(playerId) ~= "number" or playerId <= 0 then return end
    if SILENT[key] then return end
    if (H.formingDuel or H.quietQueue) and (key == "queued" or key == "queueLeft") then return end
    if H.evicting[playerId] and EVICT_SILENT[key] then return end
    if H.inMatch(playerId) then return engine.notice(playerId, kind, key, ...) end
    local entry = Config.strings.notice[key]
    if entry == nil then return engine.notice(playerId, kind, key, ...) end
    local body = entry.body
    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, body, ...)
        body = ok and formatted or entry.body
    end
    H.tell(playerId, kind, entry.title, body)
end

-- Character names on the scoreboard and the feed, not account names.
DM.playerName = function(playerId)
    local id = tonumber(playerId)
    if id ~= nil and id > 0 then
        local name = H.names[math.floor(id)]
        if name ~= nil then return name end
    end
    return engine.playerName(playerId)
end

local function nameOf(id)
    local name = H.names[id]
    if name then return name end
    local player = Core.player(id)
    if player and type(player.name) == "string" and player.name ~= "" then return player.name end
    return Open77.players.name(id) or ("#" .. tostring(id))
end
H.nameOf = nameOf

-- Engine state pushes go to the people the arena concerns, not to the whole city.
DM.wantsState = function(playerId)
    if H.entered[playerId] ~= nil or DM.instances.of(playerId) ~= nil then return true end
    if DM.arena.queuePosition(playerId) ~= nil then return true end
    if H.duelQueued(playerId) or H.invites[playerId] ~= nil then return true end
    local recent = H.recent[playerId]
    return recent ~= nil and recent > now()
end

-- ---------------------------------------------------------------------------
-- Admission

-- Light RP's eligibility, kept a moment so a queue revalidated every engine tick
-- (`FreeroamPvp.entryFailure`) does not call the core four times a second.
function H.check(playerId, activityId, fresh)
    local cached = H.checks[playerId]
    local t = now()
    if not fresh and cached and cached.activity == activityId and t - cached.atMs < L.checkCacheMs then
        return cached.ok, cached.why
    end
    local ok, why = Core.check(playerId, activityId)
    H.checks[playerId] = { activity = activityId, ok = ok, why = why, atMs = t }
    return ok, why
end

function H.admit(playerId, activityId)
    local t = now()
    local last = H.throttle[playerId]
    if last and t - last < L.joinThrottleMs then return false, "One moment." end
    H.throttle[playerId] = t
    if H.returning[playerId] or H.entered[playerId] then return false, "You are still on your way back." end
    return H.check(playerId, activityId, true)
end

-- Clears a join the core panel left pending, once we know it will not happen.
-- Never for an entered player: activityLeave would release them.
function H.clearPending(playerId, activityId)
    if H.entered[playerId] ~= nil then return end
    Core.leave(playerId, activityId, { returnPlayer = false })
end

function H.refuse(playerId, activityId, why)
    H.tell(playerId, "warning", labelOf(activityId), why or "You cannot join right now.")
    H.clearPending(playerId, activityId)
end

-- The engine revalidates queued players with this before it allocates a match.
FreeroamPvp = FreeroamPvp or {}
FreeroamPvp.entryFailure = function(playerId)
    local id = pid(playerId)
    if id == nil then return "Invalid player." end
    if H.returning[id] then return "You are still on your way back." end
    local _, format = DM.arena.queuePosition(id)
    local activityId = format == "1v1" and ACT.duel.id or ACT.teams.id
    local ok, why = H.check(id, activityId)
    if ok then return nil end
    SetTimeout(0, function() H.clearPending(id, activityId) end)
    return why or "You cannot join right now."
end

-- ---------------------------------------------------------------------------
-- Entry, movement, the way home

function H.track(playerId, activityId, instance)
    local player = Core.player(playerId)
    if player then
        if type(player.name) == "string" and player.name ~= "" then H.names[playerId] = player.name end
        if type(player.identifier) == "string" then H.identities[playerId] = player.identifier end
    end
    local entry = {
        activity = activityId,
        atMs = now(),
        instanceId = instance and instance.id or nil,
        landed = false,
        totals = { kills = 0, deaths = 0 },
    }
    H.entered[playerId] = entry
    H.released[playerId] = nil
    H.recent[playerId] = nil
    TriggerClientEvent("op77_arena:entered", playerId, { activity = activityId, label = labelOf(activityId) })
    log(("%d entered %s (instance %s)"):format(playerId, activityId, tostring(entry.instanceId)))
    return entry
end

-- Undoes an engine assignment the core refused, outside the engine's own loop.
function H.evict(playerId)
    H.evicting[playerId] = true
    SetTimeout(0, function()
        if DM.instances.of(playerId) ~= nil and H.entered[playerId] == nil then
            engine.leave(playerId, "auto")
        end
        H.evicting[playerId] = nil
    end)
end

DM.place = function(playerId, instance, reason, graceMs, mark)
    local id = pid(playerId)
    if id == nil or id <= 0 or instance == nil then
        return engine.place(playerId, instance, reason, graceMs, mark)
    end
    if H.returning[id] or H.stopped then return false, "returning" end
    local entry = H.entered[id]
    if entry == nil then
        local activityId = activityOfInstance(instance)
        local ok, why = Core.enter(id, activityId)
        if not ok then
            H.tell(id, "warning", labelOf(activityId), why)
            H.clearPending(id, activityId)
            H.evict(id)
            return false, "activity_refused"
        end
        entry = H.track(id, activityId, instance)
    end
    entry.instanceId = instance.id
    local match = instance.match
    if match ~= nil and match.sides ~= nil and match.sides[id] ~= nil then entry.side = match.sides[id] end
    return engine.place(id, instance, reason, graceMs, mark)
end

local function fullHealth(playerId)
    local health = Open77.players.getHealth(playerId)
    if type(health) == "table" and tonumber(health.maxHealth) then
        Open77.players.setHealth(playerId, health.maxHealth)
    end
end

-- main.lua's placeAt hands the body move to us (op77_arena patch).
DM.moveBody = function(playerId, position, heading, bucket, reason, graceMs, life)
    local phase = type(life) == "table" and life.phase or nil
    local target = { x = position.x, y = position.y, z = position.z }
    if phase == "dead" then
        local ok, why = Open77.players.respawn(playerId, {
            position = target, heading = heading or 0.0, bucket = bucket, health = 1.0, graceMs = graceMs,
        })
        if not ok then return false, "respawn:" .. tostring(why) end
        local entry = H.entered[playerId]
        if entry then entry.landed = true end
        return true
    end
    if phase == "alive" then
        local promise, why = Open77.players.teleport(playerId, target, {
            heading = heading or 0.0, bucket = bucket, fade = true, dismount = true, timeoutMs = 20000,
        })
        if not promise then return false, "teleport:" .. tostring(why) end
        fullHealth(playerId)
        local entry = H.entered[playerId]
        local settled = false
        CreateThread(function()
            local placed, failure = promise:await()
            settled = true
            if placed then
                if entry then entry.landed = true end
                return
            end
            log(("%d move failed (%s): %s"):format(playerId, tostring(reason), tostring(failure)))
            -- A newer placement took over; it owns the outcome.
            if tostring(failure):find("superseded", 1, true) then return end
            -- The first move in failed: never leave someone half in the arena.
            if entry and H.entered[playerId] == entry and not entry.landed then DM.leave(playerId, "auto") end
        end)
        -- The bounds backstop must not judge a body still in flight.
        CreateThread(function()
            for _ = 1, 20 do
                if settled then return end
                DM.bounds.hold(playerId, 3000)
                Wait(1000)
            end
        end)
        return true
    end
    if phase == "recovering" then
        -- Inside the arena only (never as a way in): the engine's own primitive.
        local here = Open77.players.position(playerId)
        local entry = H.entered[playerId]
        if entry and entry.landed and type(here) == "table" and tonumber(here.bucket) == bucket then
            local killed, killReason = Open77.players.kill(playerId, { cause = "script", weapon = "deathmatch:" .. tostring(reason or "place") })
            if not killed then return false, "kill:" .. tostring(killReason) end
            local ok, why = Open77.players.respawn(playerId, {
                position = target, heading = heading or 0.0, bucket = bucket, health = 1.0, graceMs = graceMs,
            })
            if not ok then return false, "respawn:" .. tostring(why) end
            return true
        end
    end
    return false, "transition_in_progress:" .. tostring(phase)
end

-- The arena never strips someone it never armed: that would take their RP weapons.
DM.loadout.strip = function(playerId, instance)
    local id = tonumber(playerId)
    if id ~= nil and id > 0 and H.entered[math.floor(id)] == nil then return false end
    return engine.strip(playerId, instance)
end

function H.forget(playerId)
    H.entered[playerId] = nil
    H.returning[playerId] = nil
    H.released[playerId] = nil
end

-- A downed player is stood up where they lie before Light RP takes them home.
function H.standUp(playerId)
    local life = Open77.players.getLifeState(playerId)
    if type(life) ~= "table" then return end
    if life.phase == "dead" then
        local here = Open77.players.position(playerId)
        if type(here) == "table" then
            local ok, why = Open77.players.respawn(playerId, {
                position = { x = here.x, y = here.y, z = here.z }, heading = 0.0,
                bucket = tonumber(here.bucket) or 0, health = 1.0, graceMs = 3000,
            })
            if not ok then log(("%d could not be stood up: %s"):format(playerId, tostring(why))) end
        end
    end
    for _ = 1, math.max(1, math.floor(L.returnTimeoutMs / 250)) do
        life = Open77.players.getLifeState(playerId)
        if type(life) ~= "table" or life.phase == "alive" then return end
        Wait(250)
    end
end

local function inArenaBucket(bucket)
    bucket = tonumber(bucket)
    return bucket ~= nil and bucket >= 4100000 and bucket <= 4199999
end

-- Replaces the engine's lobby placement: the way home is Light RP's.
function H.returnHome(playerId, reason)
    local id = pid(playerId)
    if id == nil then return false, "bad_player_id" end
    DM.loadout.strip(id)
    TriggerClientEvent("deathmatch:boundsClear", id)
    local entry = H.entered[id]
    if entry == nil then return true end
    if H.released[id] then H.forget(id) return true end
    if H.returning[id] then return true end
    H.returning[id] = true
    CreateThread(function()
        if connected(id) then H.standUp(id) end
        local ok, why = Core.leave(id, entry.activity, { returnPlayer = true })
        if not ok then
            log(("%d: activityLeave refused (%s)"):format(id, tostring(why)))
            -- Last resort: nobody stays stranded in an arena bucket.
            local here = Open77.players.position(id)
            if type(here) == "table" and inArenaBucket(here.bucket) then
                local lobby = Config.lobby.center
                Open77.players.teleport(id, { x = lobby.x, y = lobby.y, z = lobby.z },
                    { heading = Config.lobby.heading, bucket = 0, fade = true, dismount = true })
            end
        end
        if H.entered[id] == entry then H.forget(id) end
        H.returning[id] = nil
        H.recent[id] = now() + L.recentStateMs
        TriggerClientEvent("op77_arena:returned", id, { activity = entry.activity, reason = tostring(reason or "") })
    end)
    return true
end
DM.sendToLobby = H.returnHome

-- ---------------------------------------------------------------------------
-- Bots: staff bot mode (PvP) and the PvE Combat Zone
--
-- The bodies are the engine's own (server/bots.lua: Cyberpunk's native combat AI,
-- paced spawns, bucket-bound). This only says how many go where, and takes them
-- away again; nothing here moves a bot or picks its target.

local PVE_PLAYERS, PVE_BOTS = 1, 2 -- the two sides of a PvE round

local warned = {}
local function warnOnce(key, text)
    if warned[key] then return end
    warned[key] = true
    log(text)
end

-- DeathmatchBots.<name>(...), guarded: nil, reason when bots.lua or the function is
-- missing or raises (logged once per function), never an error.
local function botsCall(name, ...)
    local module = DeathmatchBots
    local fn = type(module) == "table" and module[name] or nil
    if type(fn) ~= "function" then
        warnOnce("missing:" .. name, ("bots: DeathmatchBots.%s is unavailable; skipped"):format(name))
        return nil, "bots_unavailable"
    end
    local packed = table.pack(pcall(fn, ...))
    if not packed[1] then
        warnOnce("raised:" .. name, ("bots: DeathmatchBots.%s raised: %s"):format(name, tostring(packed[2])))
        return nil, "bots_raised"
    end
    return table.unpack(packed, 2, packed.n)
end
H.botsCall = botsCall

-- Bots of an instance, dead ones waiting to respawn included.
function H.botCount(instance)
    if instance == nil then return 0 end
    local module = DeathmatchBots
    if type(module) == "table" and type(module.count) == "function" then
        local ok, count = pcall(module.count, instance.id)
        if ok and tonumber(count) then return math.floor(count) end
    end
    local fn = DM.instances.botCount
    if type(fn) == "function" then
        local ok, count = pcall(fn, instance)
        if ok and tonumber(count) then return math.floor(count) end
    end
    return 0
end

-- Is staff bot mode filling this activity (ffa, blade, teams, duel)?
local function botsFor(key)
    return H.botMode == true and not H.stopped and L.bots[key] ~= false
end
H.botsFor = botsFor

local function isPve(instance)
    return instance ~= nil and instance.format == "ffa" and instance.ruleset == "pve"
end
H.isPve = isPve

local function ffaKey(instance)
    if instance.ruleset == "blade" then return "blade" end
    if instance.ruleset == "pve" then return "pve" end
    return "ffa"
end

-- Paced spawns still on their way: bots.lua parks what its spacing refuses and
-- spends one per tick, so a fill is not complete when `add` returns.
local function inFlight(instance)
    local fill = instance ~= nil and H.botFill[instance] or nil
    if fill == nil then return 0 end
    if now() - fill.atMs >= L.bots.inFlightMs then H.botFill[instance] = nil return 0 end
    local left = fill.queued - math.max(0, H.botCount(instance) - fill.base)
    if left <= 0 then H.botFill[instance] = nil return 0 end
    return left
end
H.inFlight = inFlight

-- The round (FFA) or match (arena) had bots: sticky, read by every result.
local function markBots(instance)
    local key = instance ~= nil and (instance.match or instance.round) or nil
    if key ~= nil then H.botRounds[key] = true end
end
H.markBots = markBots

function H.hadBots(instance)
    if instance == nil then return false end
    local key = instance.match or instance.round
    if key ~= nil and H.botRounds[key] then return true end
    if H.botCount(instance) > 0 or inFlight(instance) > 0 then return true end
    if instance.match ~= nil and instance.match.botFill ~= nil then return true end
    -- A bot that took part this round, even if removed since (its row stays).
    for _, row in ipairs(DM.scoring.rows(instance) or {}) do
        if row.bot or (tonumber(row.id) or 0) < 0 then
            if row.active ~= false or (tonumber(row.kills) or 0) > 0 or (tonumber(row.deaths) or 0) > 0 then return true end
        end
    end
    return false
end

-- How many bots an FFA instance should hold now: PvE scales with the players;
-- bot mode completes Combat Zone / Blade Night to `L.bots.fillTarget` bodies.
function H.botTarget(instance)
    if instance == nil or instance.closed or instance.format ~= "ffa" then return 0 end
    local humans = #DM.instances.humans(instance)
    if humans == 0 then return 0 end
    local target
    if isPve(instance) then
        local P = L.pve
        target = math.min(P.botsMax, P.botsFirst + P.botsPerPlayer * (humans - 1))
    elseif botsFor(ffaKey(instance)) then
        target = L.bots.fillTarget - humans
    else
        return 0
    end
    local capacity = tonumber(instance.capacity) or 0
    if capacity > 0 then target = math.min(target, capacity - humans) end
    return math.max(0, math.floor(target))
end

function H.clearBots(instance, reason)
    if instance == nil then return 0 end
    botsCall("dropPending", instance.id)
    H.botFill[instance] = nil
    local removed = tonumber((botsCall("clear", instance.id, reason or "lightrp"))) or 0
    if removed > 0 then
        log(("instance %s: %d bot(s) removed (%s)"):format(tostring(instance.id), removed, tostring(reason)))
    end
    return removed
end

-- Tops an FFA instance up to its target. Returns the bots asked for.
function H.fillBots(instance)
    local target = H.botTarget(instance)
    if target <= 0 then return 0 end
    local pending = inFlight(instance)
    local missing = target - H.botCount(instance) - pending
    if missing <= 0 then return 0 end
    local profile = isPve(instance) and L.pve.profile or L.bots.profile
    local added, why, queued = botsCall("add", instance.id, missing, profile)
    if added == nil then return 0 end
    added, queued = tonumber(added) or 0, tonumber(queued) or 0
    if added + queued > 0 then
        H.botFill[instance] = { base = H.botCount(instance), queued = queued + pending, atMs = now() }
        markBots(instance)
    end
    if added + queued < missing then
        log(("instance %s: %d of %d bot(s) requested (%s)"):format(tostring(instance.id), added + queued, missing, tostring(why)))
    end
    return added + queued
end

-- The last player is gone: the bots go too, even while bot mode is on.
function H.afterDeparture(instance)
    if instance == nil or instance.closed or instance.format ~= "ffa" then return end
    if #DM.instances.humans(instance) > 0 then return end
    if H.botCount(instance) > 0 or inFlight(instance) > 0 then H.clearBots(instance, "no_players") end
end

-- The switch (op77_lightrp `/lightrp.bots`). Nothing is removed at once: a running
-- round keeps its bots until it ends, and nothing new starts filled.
function H.setBotMode(on, why)
    on = on == true
    if H.botMode == on then return false end
    H.botMode = on
    log(("bot mode %s (%s)"):format(on and "ON" or "off", tostring(why)))
    for _, instance in pairs(DM.instances.registry) do
        if not instance.closed and instance.format == "ffa" and not isPve(instance) then
            if on then
                H.fillBots(instance)
            else
                botsCall("dropPending", instance.id)
                H.botFill[instance] = nil
            end
        end
    end
    if on then H.upgradeTeamQueues(true) end
    H.pushStatuses()
    return true
end

-- PvE: the players are one side and the bots the other. The engine reads sides
-- through these two seams (the friendly-fire gates in main.lua and bots.lua), and
-- Open77.combat.setTeam keeps two players on one nonzero team from hurting each other.
if type(engine.setTeam) == "function" then
    DM.setTeam = function(playerId, team, instance)
        if isPve(instance) and (tonumber(team) or 0) == 0 then
            team = (tonumber(playerId) or 0) > 0 and PVE_PLAYERS or PVE_BOTS
        end
        return engine.setTeam(playerId, team, instance)
    end
end

if type(engine.sideOf) == "function" then
    DM.arena.sideOf = function(participantId)
        local id = tonumber(participantId)
        if id ~= nil then
            local instance
            if id > 0 then
                instance = DM.instances.of(id)
            elseif type(DeathmatchBots) == "table" and type(DeathmatchBots.get) == "function" then
                local ok, bot = pcall(DeathmatchBots.get, math.floor(id))
                local instanceId = ok and type(bot) == "table" and tonumber(bot.instanceId) or nil
                instance = instanceId and DM.instances.registry[instanceId] or nil
            end
            if isPve(instance) and not instance.closed then
                return id > 0 and PVE_PLAYERS or PVE_BOTS
            end
        end
        return engine.sideOf(participantId)
    end
end

-- No rating, round or career row for PvE, for a round with bots, or while bot mode is on.
if type(DM.ranked) == "table" and type(DM.ranked.recordRound) == "function" then
    engine.recordRound = DM.ranked.recordRound
    DM.ranked.recordRound = function(instance, opts)
        if instance ~= nil then
            if isPve(instance) then return false, "unranked_ruleset" end
            if H.hadBots(instance) then return false, "bots" end
            if H.botMode then return false, "bot_mode" end
        end
        return engine.recordRound(instance, opts)
    end
end

-- ---------------------------------------------------------------------------
-- Crews (options.squad from Light RP)

function H.noteSquad(playerId, squad)
    H.squads[playerId] = nil
    if type(squad) ~= "table" or squad.id == nil or type(squad.members) ~= "table" then return nil end
    local members, seen, mine = {}, {}, false
    for _, value in ipairs(squad.members) do
        local member = pid(value)
        if member ~= nil and member > 0 and not seen[member] and #members < 16 then
            seen[member] = true
            members[#members + 1] = member
            if member == playerId then mine = true end
        end
    end
    if not mine or #members < 2 then return nil end
    local record = { id = tostring(squad.id), leader = pid(squad.leader), members = members, atMs = now() }
    H.squads[playerId] = record
    return record
end

local function sameCrew(a, b)
    local sa, sb = H.squads[a], H.squads[b]
    return sa ~= nil and sb ~= nil and sa.id == sb.id
end
H.sameCrew = sameCrew

-- Crew members (this player included) not yet in the instance and still in the city.
function H.crewArriving(playerId, instance)
    local squad = H.squads[playerId]
    if squad == nil then return 1 end
    local count = 0
    for _, member in ipairs(squad.members) do
        local inside = instance ~= nil and instance.members[member]
        if not inside and (member == playerId or connected(member)) then count = count + 1 end
    end
    return math.max(1, count)
end

-- A crew never splits across sides, so it must fit on one.
function H.crewFitsFormat(playerId, format)
    local squad = H.squads[playerId]
    local spec = Config.formats[format]
    if squad == nil or spec == nil then return true end
    local perSide = tonumber(spec.teamSize) or math.floor((tonumber(spec.capacity) or 2) / 2)
    local size = #squad.members
    if size <= perSide then return true end
    if format == "2v2" and size <= 3 then
        return false, ("Your crew is %d: Team Arena 2v2 takes 2 per side. Queue 3v3 together."):format(size)
    end
    return false, ("Your crew is %d: Team Arena takes 3 per side at most. Play the Combat Zone or PvE together."):format(size)
end

-- A crew still arriving in a team queue: some member is in the city, not queued,
-- not in a match, and the crew joined less than `L.crews.gatherMs` ago.
local function crewGathering(group, t)
    local squad = group.squad
    if squad == nil then return false end
    local since = math.huge
    for _, id in ipairs(group.ids) do
        local record = H.squads[id]
        if record ~= nil and record.atMs < since then since = record.atMs end
    end
    if t - since >= L.crews.gatherMs then return false end
    local queued = {}
    for _, id in ipairs(group.ids) do queued[id] = true end
    for _, member in ipairs(squad.members) do
        if not queued[member] and connected(member) and DM.instances.of(member) == nil
            and H.entered[member] == nil and not H.returning[member] then
            return true
        end
    end
    return false
end

-- Arena.planRoster (server/arena.lua): who plays a team match and on which side.
-- Crews stay whole and on one side; the rest keep the queue order. Outside bot
-- mode only a full roster forms; in bot mode the engine completes each side.
function H.planRoster(format, queue, capacity)
    if format ~= "2v2" and format ~= "3v3" then return nil end
    local teamSize = math.floor(capacity / 2)
    local t = now()
    local groups, byKey = {}, {}
    for _, entry in ipairs(queue) do
        local id = entry.playerId
        local squad = H.squads[id]
        local key = squad ~= nil and ("crew:" .. squad.id) or ("solo:" .. tostring(id))
        local group = byKey[key]
        if group == nil then
            group = { squad = squad, ids = {} }
            byKey[key] = group
            groups[#groups + 1] = group
        end
        group.ids[#group.ids + 1] = id
    end
    local roster, sides, count = {}, {}, { 0, 0 }
    for _, group in ipairs(groups) do
        local size = #group.ids
        if size <= teamSize and not crewGathering(group, t) then
            local side = count[1] <= count[2] and 1 or 2
            if count[side] + size > teamSize then side = side == 1 and 2 or 1 end
            if count[side] + size <= teamSize then
                for _, id in ipairs(group.ids) do
                    roster[#roster + 1] = id
                    sides[id] = side
                end
                count[side] = count[side] + size
            end
        end
        if #roster >= capacity then break end
    end
    if #roster < capacity and not botsFor("teams") then return { roster = {}, sides = {} } end
    return { roster = roster, sides = sides }
end
DM.arena.planRoster = H.planRoster

-- Bot mode: team queue entries accept bots (at once, or after `teamWaitMs`).
function H.upgradeTeamQueues(force)
    if not botsFor("teams") then return 0 end
    local t = now()
    local upgraded = 0
    for _, raw in ipairs(GetPlayers() or {}) do
        local id = pid(raw)
        local format = id and select(2, DM.arena.queuePosition(id)) or nil
        if (format == "2v2" or format == "3v3") and not H.teamUpgraded[id] then
            local since = H.teamQueuedAt[id] or t
            if (force and L.bots.teamWaitMs <= 0) or t - since >= L.bots.teamWaitMs then
                H.teamUpgraded[id] = true
                H.quietQueue = true
                local ok, err = pcall(engine.enqueue, id, format, true)
                H.quietQueue = false
                if not ok then log(("bot upgrade of %d failed: %s"):format(id, tostring(err))) end
                upgraded = upgraded + 1
            end
        end
    end
    return upgraded
end

-- ---------------------------------------------------------------------------
-- Results and reputation

local function rowOf(rows, id)
    for _, row in ipairs(rows or {}) do
        if row.id == id then return row end
    end
    return nil
end

local function capRep(value)
    return math.max(0, math.min(math.floor(value + 0.5), L.reputation.maxPerResult))
end

local function ffaRep(key, rank)
    local rep = L.reputation[key]
    if rank == 1 then return rep.first elseif rank == 2 then return rep.second
    elseif rank == 3 then return rep.third end
    return rep.other
end

-- One result per FFA round, at Round.finish.
function H.reportRound(instance, reason, winnerId)
    local round = instance.round
    if round == nil then return 0 end
    if isPve(instance) then return H.reportPve(instance, reason) end
    local key = instance.ruleset == "blade" and "blade" or "ffa"
    local rules = L.reputation[key]
    local humans = #DM.instances.humans(instance)
    local night = H.night ~= nil and key == "ffa"
    -- Bot practice: nothing earned, nothing recorded (Light RP skips `test` results).
    local practice = H.botMode or H.hadBots(instance)
    local t = now()
    local sent = 0
    for _, row in ipairs(DM.scoring.rows(instance)) do
        local entry = row.id > 0 and not row.bot and H.entered[row.id] or nil
        if entry and entry.instanceId == instance.id and instance.members[row.id] then
            local inRound = t - math.max(entry.atMs, round.startedAtMs or entry.atMs)
            local reputation = 0
            if not practice and reason ~= "arena_night" and humans >= rules.minHumans and inRound >= rules.minRoundMs then
                reputation = ffaRep(key, row.rank)
                if night then reputation = reputation * L.reputation.nightMultiplier end
            end
            Core.result(row.id, entry.activity, {
                placement = row.rank,
                score = row.score,
                won = winnerId ~= nil and winnerId == row.id,
                stats = { kills = row.kills, deaths = row.deaths, assists = row.assists,
                    bestStreak = row.bestStreak, durationMs = inRound, round = round.number },
                reputation = capRep(reputation),
                test = practice or nil,
            })
            sent = sent + 1
        end
    end
    return sent
end

-- PvE: one result per player per round. The players won when they killed more
-- bots than the bots killed players; reputation only after `minRoundMs` in the round.
function H.pveTally(instance)
    local players, bots = 0, 0
    for _, row in ipairs(DM.scoring.rows(instance) or {}) do
        local kills = tonumber(row.kills) or 0
        if row.bot or (tonumber(row.id) or 0) < 0 then bots = bots + kills else players = players + kills end
    end
    return players, bots
end

function H.reportPve(instance, reason)
    local round = instance.round
    if round == nil then return 0 end
    local rules = L.reputation.pve
    local playerKills, botKills = H.pveTally(instance)
    local won = playerKills > botKills
    local humans = #DM.instances.humans(instance)
    local bots = H.botCount(instance)
    local t = now()
    local sent = 0
    for _, row in ipairs(DM.scoring.rows(instance)) do
        local entry = row.id > 0 and not row.bot and H.entered[row.id] or nil
        if entry and entry.instanceId == instance.id and instance.members[row.id] then
            local inRound = t - math.max(entry.atMs, round.startedAtMs or entry.atMs)
            local reputation = 0
            if inRound >= rules.minRoundMs then reputation = won and rules.win or rules.loss end
            Core.result(row.id, entry.activity, {
                placement = won and 1 or 2,
                score = row.score,
                won = won,
                stats = { kills = row.kills, deaths = row.deaths, assists = row.assists,
                    bestStreak = row.bestStreak, durationMs = inRound, round = round.number,
                    teamKills = playerKills, botKills = botKills, players = humans, bots = bots },
                reputation = capRep(reputation),
            })
            sent = sent + 1
        end
    end
    return sent
end

local function sideOf(match, id)
    local side = match.sides and match.sides[id] or nil
    if side == nil and H.entered[id] then side = H.entered[id].side end
    return side
end

-- Arena kills and deaths over the whole match: the board clears every round.
function H.sample(instance)
    local round = instance.round
    if round == nil or round.id == nil then return end
    local snap = H.snaps[instance]
    if snap == nil or snap.roundId ~= round.id then
        if snap ~= nil then
            for id, row in pairs(snap.rows) do
                local entry = H.entered[id]
                if entry and entry.instanceId == instance.id then
                    entry.totals.kills = entry.totals.kills + row.kills
                    entry.totals.deaths = entry.totals.deaths + row.deaths
                end
            end
        end
        snap = { roundId = round.id, rows = {} }
        H.snaps[instance] = snap
    end
    for _, row in ipairs(DM.scoring.rows(instance)) do
        if row.id > 0 then snap.rows[row.id] = { kills = row.kills or 0, deaths = row.deaths or 0 } end
    end
end

local function totalsOf(instance, entry, id)
    local kills, deaths = entry.totals.kills, entry.totals.deaths
    local row = rowOf(DM.scoring.rows(instance), id)
    if row then kills, deaths = kills + (row.kills or 0), deaths + (row.deaths or 0) end
    return kills, deaths
end

local function dayIndex()
    local unix = Open77.time and type(Open77.time.unix) == "function" and Open77.time.unix() or nil
    return math.floor((tonumber(unix) or 0) / 86400)
end

-- Same two accounts, same day: reputation only for the first few duels.
function H.duelRewardAllowed(a, b)
    local ia, ib = H.identities[a] or tostring(a), H.identities[b] or tostring(b)
    if ia > ib then ia, ib = ib, ia end
    local key = ("%s|%s|%d"):format(ia, ib, dayIndex())
    local count = H.duelPairs[key] or 0
    if count >= L.duel.repeatRewardsPerDay then return false end
    H.duelPairs[key] = count + 1
    return true
end

function H.reportMatch(instance)
    local match = instance.match
    if match == nil or match.result == nil or H.reported[match] then return 0 end
    H.reported[match] = true
    local result = match.result
    local duel = instance.format == "1v1"
    local rules = duel and L.reputation.duel or L.reputation.teams
    local practice = H.botMode or H.hadBots(instance)
    local normal = result.reason == "best_of" and not practice
    local winner = tonumber(result.winnerSide) or 0
    local humans = DM.instances.humans(instance)
    local rewardDuel = true
    if duel and normal and #humans == 2 then rewardDuel = H.duelRewardAllowed(humans[1], humans[2]) end
    local sent = 0
    for _, id in ipairs(humans) do
        local entry = H.entered[id]
        local side = sideOf(match, id)
        if entry and entry.instanceId == instance.id and side then
            local won = winner ~= 0 and side == winner
            local kills, deaths = totalsOf(instance, entry, id)
            local reputation = 0
            if normal and rewardDuel then reputation = won and rules.win or rules.loss end
            local wins = result.wins or {}
            Core.result(id, entry.activity, {
                placement = winner == 0 and nil or (won and 1 or 2),
                score = tonumber(wins[side]) or 0,
                won = won,
                stats = { kills = kills, deaths = deaths, roundsWon = tonumber(wins[side]) or 0,
                    roundsLost = tonumber(wins[side == 1 and 2 or 1]) or 0, format = instance.format,
                    durationMs = now() - entry.atMs },
                reputation = capRep(reputation),
                test = practice or nil,
            })
            sent = sent + 1
        end
    end
    return sent
end

-- A player who walks out of a live match: a loss (arena) or the round so far (FFA).
function H.noteQuit(playerId)
    local entry = H.entered[playerId]
    if entry == nil then return false end
    -- On a disconnect the engine may already have detached them: the entry knows where.
    local instance = DM.instances.of(playerId) or DM.instances.registry[entry.instanceId]
    if instance == nil or instance.closed or entry.instanceId ~= instance.id then return false end
    if instance.format == "ffa" then
        local round = instance.round
        if round == nil or round.state ~= "active" then return false end
        local row = rowOf(DM.scoring.rows(instance), playerId)
        if row == nil then return false end
        local pve = isPve(instance)
        Core.result(playerId, entry.activity, {
            placement = pve and 2 or row.rank, score = row.score, won = false,
            stats = { kills = row.kills, deaths = row.deaths, assists = row.assists, quit = true,
                durationMs = now() - math.max(entry.atMs, round.startedAtMs or entry.atMs) },
            reputation = 0,
            test = (not pve and (H.botMode or H.hadBots(instance))) or nil,
        })
        return true
    end
    local match = instance.match
    if match == nil then return false end
    if match.state == "resolved" then return H.reportMatch(instance) > 0 end
    if match.state ~= "playing" then return false end
    local side = sideOf(match, playerId)
    local kills, deaths = totalsOf(instance, entry, playerId)
    local wins = match.wins or {}
    Core.result(playerId, entry.activity, {
        placement = 2, score = side and tonumber(wins[side]) or 0, won = false,
        stats = { kills = kills, deaths = deaths, quit = true, format = instance.format,
            durationMs = now() - entry.atMs },
        reputation = 0,
        test = (H.botMode or H.hadBots(instance)) or nil,
    })
    return true
end

-- ---------------------------------------------------------------------------
-- Engine seams: joins, queues, leaving, rounds

local RULESET_KEY = { standard = "ffa", blade = "blade", pve = "pve" }

-- Room in a free-for-all for this player and the crew coming with them.
function H.ffaRoom(playerId, ruleset)
    local instance = H.ffaInstance(ruleset)
    local humans = instance and #DM.instances.humans(instance) or 0
    local cap
    if ruleset == "pve" then cap = L.pve.maxPlayers
    else cap = instance and tonumber(instance.capacity) or Config.instances.ffaCapacity end
    cap = tonumber(cap) or 0
    if cap <= 0 then return true end
    local free = cap - humans
    local label = ACT[RULESET_KEY[ruleset] or "ffa"].label
    if free <= 0 then return false, ("%s is full (%d players)."):format(label, cap) end
    local needed = H.crewArriving(playerId, instance)
    if needed > free then
        return false, ("Not enough room in %s for your whole crew: %d place%s left for %d."):format(
            label, free, free == 1 and "" or "s", needed)
    end
    return true
end

DM.round.join = function(playerId, ruleset)
    local id = pid(playerId)
    if id == nil then return nil, "bad_player_id" end
    ruleset = RULESET_KEY[ruleset] and ruleset or "standard"
    local activityId = ACT[RULESET_KEY[ruleset]].id
    local current = DM.instances.of(id)
    if current ~= nil then
        if activityOfInstance(current) == activityId then return current, "already_assigned" end
        H.refuse(id, activityId, "Leave your current match first: /arena.leave")
        return nil, "busy"
    end
    local _, queued = DM.arena.queuePosition(id)
    if queued ~= nil or H.duelQueued(id) then
        H.refuse(id, activityId, "You are in a queue. /arena.leave first.")
        return nil, "queued"
    end
    local ok, why = H.admit(id, activityId)
    if not ok then
        H.refuse(id, activityId, why)
        return nil, "refused"
    end
    local room, roomWhy = H.ffaRoom(id, ruleset)
    if not room then
        H.refuse(id, activityId, roomWhy)
        return nil, "full"
    end
    H.dropInvites(id)
    local instance, reason = engine.join(id, ruleset)
    if instance == nil then
        H.clearPending(id, activityId)
    elseif H.entered[id] == nil and not H.evicting[id] then
        H.evict(id)
    elseif H.entered[id] ~= nil then
        H.fillBots(instance) -- PvE scales with the players; bot mode completes the round
    end
    return instance, reason
end

DM.arena.enqueue = function(playerId, format, wantsBots)
    local id = pid(playerId)
    if id == nil then return nil, "bad_player_id" end
    format = tostring(format or "")
    if format == "1v1" then
        H.tell(id, "info", ACT.duel.label, "Challenge someone near you with /duel <id>, or /duel random.")
        return nil, "duel_by_invite"
    end
    if format ~= "2v2" and format ~= "3v3" then return nil, "unknown_format" end
    if DM.instances.of(id) ~= nil then
        H.tell(id, "warning", ACT.teams.label, "Leave your current match first: /arena.leave")
        return nil, "already_in_instance"
    end
    if H.duelQueued(id) then H.withdrawDuel(id, true) end
    local _, current = DM.arena.queuePosition(id)
    if current ~= format then
        local ok, why = H.admit(id, ACT.teams.id)
        if not ok then
            H.refuse(id, ACT.teams.id, why)
            return nil, "refused"
        end
        local fits, fitWhy = H.crewFitsFormat(id, format)
        if not fits then
            H.refuse(id, ACT.teams.id, fitWhy)
            return nil, "crew_too_big"
        end
        H.teamQueuedAt[id] = now()
        H.teamUpgraded[id] = nil
    end
    H.dropInvites(id)
    -- Bot mode: the entry accepts bots now, or the tick upgrades it after teamWaitMs.
    local bots = (L.allowBots == true and wantsBots == true) or (botsFor("teams") and L.bots.teamWaitMs <= 0)
    if bots then H.teamUpgraded[id] = true end
    return engine.enqueue(id, format, bots)
end

DM.leave = function(playerId, scope)
    local id = pid(playerId)
    if id == nil then return false end
    local before = DM.instances.of(id)
    if tostring(scope or "auto") ~= "queue" then H.noteQuit(id) end
    local done = engine.leave(id, scope)
    -- Someone the engine let go of while we still owe Light RP a release.
    if H.entered[id] ~= nil and DM.instances.of(id) == nil and not H.returning[id] then
        H.returnHome(id, "left")
    end
    if before ~= nil then H.afterDeparture(before) end
    return done
end

DM.round.finish = function(instance, reason, winnerId)
    local done = engine.finish(instance, reason, winnerId)
    if done and instance ~= nil and instance.format == "ffa" then
        local result = instance.round and instance.round.result
        H.reportRound(instance, reason, result and result.winnerId or winnerId)
        -- Bot mode went off (or the last player left): this round's bots go with it.
        if not instance.closed and H.botTarget(instance) == 0
            and (H.botCount(instance) > 0 or inFlight(instance) > 0) then
            H.clearBots(instance, "round_over")
        end
    end
    return done
end

-- Every new FFA round: more bots than it should hold (bot mode off, players left)
-- are removed BEFORE it starts, so the round is clean; the missing ones are asked
-- for after, once the players are placed.
if type(engine.begin) == "function" then
    DM.round.begin = function(instance, reason)
        if instance ~= nil and not instance.closed and instance.format == "ffa" then
            local bots = H.botCount(instance) + inFlight(instance)
            if bots > 0 and bots > H.botTarget(instance) then H.clearBots(instance, "round_reset") end
        end
        local round = engine.begin(instance, reason)
        if round ~= nil and instance ~= nil and not instance.closed then H.fillBots(instance) end
        return round
    end
end

-- Arena Night rules ride on the instance's tunable capture, as every round reads it.
function H.applyNight(instance)
    if instance == nil or instance.nightBase ~= nil then return end
    local base = instance.tune
    instance.nightBase = base or false
    local override = { roundSeconds = L.night.roundSeconds, killLimit = L.night.killLimit }
    instance.tune = setmetatable(override, { __index = function(_, k)
        if type(base) == "table" or type(base) == "userdata" then return base[k] end
        return nil
    end })
end

function H.clearNight(instance)
    if instance == nil or instance.nightBase == nil then return end
    instance.tune = instance.nightBase or nil
    instance.nightBase = nil
end

DM.instances.open = function(format, ruleset)
    local instance, reason = engine.open(format, ruleset)
    if instance ~= nil and H.night ~= nil and format == "ffa" and (ruleset or "standard") == "standard" then
        H.applyNight(instance)
    end
    return instance, reason
end

-- ---------------------------------------------------------------------------
-- Activities as the player starts them (core panel and commands)

function H.ffaInstance(ruleset)
    for _, instance in pairs(DM.instances.registry) do
        if not instance.closed and instance.format == "ffa" and (instance.ruleset or "standard") == ruleset then
            return instance
        end
    end
    return nil
end

function H.joinFfa(playerId, ruleset)
    local instance = DM.round.join(playerId, ruleset)
    DM.broadcastState()
    return instance ~= nil
end

function H.queueTeams(playerId, format)
    format = (format == "3v3") and "3v3" or ((format == "2v2") and "2v2" or L.teams.defaultFormat)
    local position = DM.arena.enqueue(playerId, format, false)
    DM.broadcastState()
    return position ~= nil
end

-- The random duel queue and challenges. The engine's own 1v1 queue only ever holds
-- the two players of a duel being formed, so a stranger can never take the slot.
function H.duelQueued(playerId)
    for _, item in ipairs(H.duelQueue) do
        if item.playerId == playerId then return true end
    end
    return false
end

function H.withdrawDuel(playerId, silent)
    for index = #H.duelQueue, 1, -1 do
        if H.duelQueue[index].playerId == playerId then
            table.remove(H.duelQueue, index)
            if not silent then H.tell(playerId, "info", ACT.duel.label, "You left the duel queue.") end
            H.clearPending(playerId, ACT.duel.id)
        end
    end
    H.dropInvites(playerId)
end

-- Invites to and from a player, gone (they joined something else or left).
function H.dropInvites(playerId)
    local invite = H.invites[playerId]
    if invite then
        H.invites[playerId] = nil
        H.tell(invite.from, "info", ACT.duel.label, ("%s is busy. Challenge dropped."):format(nameOf(playerId)))
    end
    for target, item in pairs(H.invites) do
        if item.from == playerId then
            H.invites[target] = nil
            H.tell(target, "info", ACT.duel.label, ("%s withdrew the challenge."):format(nameOf(playerId)))
        end
    end
end

function H.formDuel(a, b)
    H.formingDuel = true
    engine.leave(a, "queue")
    engine.leave(b, "queue")
    for index = #H.duelQueue, 1, -1 do
        local item = H.duelQueue[index]
        if item.playerId == a or item.playerId == b then table.remove(H.duelQueue, index) end
    end
    H.check(a, ACT.duel.id, true)
    H.check(b, ACT.duel.id, true)
    engine.enqueue(a, "1v1", false)
    engine.enqueue(b, "1v1", false)
    H.formingDuel = false
    local ia, ib = DM.instances.of(a), DM.instances.of(b)
    if ia ~= nil and ia == ib then
        DM.broadcastState()
        return true
    end
    -- Not formed: nobody stays in the engine's 1v1 queue.
    H.formingDuel = true
    if ia == nil then engine.leave(a, "queue") end
    if ib == nil then engine.leave(b, "queue") end
    H.formingDuel = false
    for _, id in ipairs({ a, b }) do
        if DM.instances.of(id) == nil then
            H.tell(id, "warning", ACT.duel.label, "The duel could not start. Try again in a moment.")
            H.clearPending(id, ACT.duel.id)
        end
    end
    DM.broadcastState()
    return false
end

local function busy(playerId)
    if DM.instances.of(playerId) ~= nil then return "is already in a match" end
    if DM.arena.queuePosition(playerId) ~= nil then return "is in a queue" end
    if H.duelQueued(playerId) then return "is waiting for a duel" end
    if H.returning[playerId] or H.entered[playerId] then return "is on the way back" end
    return nil
end

function H.queueDuel(playerId)
    local activityId = ACT.duel.id
    if busy(playerId) then
        if H.duelQueued(playerId) then return true end
        H.refuse(playerId, activityId, "Leave your current match or queue first: /arena.leave")
        return false
    end
    local ok, why = H.admit(playerId, activityId)
    if not ok then H.refuse(playerId, activityId, why) return false end
    H.dropInvites(playerId)
    for index, item in ipairs(H.duelQueue) do
        -- Matchmaking never sets two players of one crew against each other.
        if item.playerId ~= playerId and connected(item.playerId) and not sameCrew(item.playerId, playerId) then
            local other = item.playerId
            local okOther = H.check(other, activityId, true)
            if okOther then
                table.remove(H.duelQueue, index)
                return H.formDuel(other, playerId)
            end
        end
    end
    -- Bot mode: nobody waiting, so a bot takes the other corner (now, or after duelWaitMs).
    if botsFor("duel") and L.bots.duelWaitMs <= 0 then
        local started, text = H.startBotDuel(playerId)
        H.tell(playerId, started and "success" or "warning", ACT.duel.label, text)
        return started
    end
    H.duelQueue[#H.duelQueue + 1] = { playerId = playerId, atMs = now() }
    H.tell(playerId, "success", ACT.duel.label, "Looking for an opponent. /arena.leave to stop.")
    DM.broadcastState()
    return true
end

-- A best-of-three duel against one engine bot (bot mode). The player stands alone
-- in the engine's 1v1 queue, consenting to a bot, and the engine forms the match
-- and adds the bot (Arena.tryForm -> DeathmatchBots.addToArena).
function H.startBotDuel(playerId)
    local activityId = ACT.duel.id
    for index = #H.duelQueue, 1, -1 do
        if H.duelQueue[index].playerId == playerId then table.remove(H.duelQueue, index) end
    end
    H.quietQueue = true
    local okCall, position = pcall(engine.enqueue, playerId, "1v1", true)
    H.quietQueue = false
    if not okCall then log(("bot duel for %d raised: %s"):format(playerId, tostring(position))) end
    local instance = DM.instances.of(playerId)
    if instance ~= nil and instance.format == "1v1" then
        markBots(instance)
        DM.broadcastState()
        return true, "Duel against a bot. Best of three. Practice: not recorded."
    end
    if okCall and position ~= nil then
        H.quietQueue = true
        engine.leave(playerId, "queue")
        H.quietQueue = false
    end
    H.clearPending(playerId, activityId)
    DM.broadcastState()
    return false, "The bot duel could not start. Try again in a moment."
end

-- `/duel bot`
function H.duelBot(playerId)
    if not botsFor("duel") then return false, "Duels against a bot need staff bot mode (/lightrp.bots on)." end
    if busy(playerId) then return false, "Leave your current match or queue first: /arena.leave" end
    local ok, why = H.admit(playerId, ACT.duel.id)
    if not ok then return false, why end
    H.dropInvites(playerId)
    return H.startBotDuel(playerId)
end

local function distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- `/duel <id>`: both standing in the city, close to each other.
function H.challenge(from, target)
    local activityId = ACT.duel.id
    if target == nil or target == from then return false, "Choose another player: /duel <id>" end
    if not connected(target) then return false, "No player with that id." end
    local mine, theirs = busy(from), busy(target)
    if mine then return false, "Leave your current match or queue first: /arena.leave" end
    if theirs then return false, ("%s %s."):format(nameOf(target), theirs) end
    local a, b = Open77.players.position(from), Open77.players.position(target)
    if type(a) ~= "table" or type(b) ~= "table" or tonumber(a.bucket) ~= tonumber(b.bucket)
        or distance(a, b) > L.duel.maxDistance then
        return false, ("Get within %d m of %s first."):format(math.floor(L.duel.maxDistance), nameOf(target))
    end
    local ok, why = H.admit(from, activityId)
    if not ok then return false, why end
    local okTarget = H.check(target, activityId, true)
    if not okTarget then return false, ("%s cannot duel right now."):format(nameOf(target)) end
    for other, item in pairs(H.invites) do
        if item.from == from then H.invites[other] = nil end
    end
    H.invites[target] = { from = from, atMs = now() }
    H.tell(target, "info", "DUEL CHALLENGE",
        ("%s challenges you. /duel accept or /duel decline (%d s)."):format(nameOf(from), L.duel.inviteSeconds), 10000)
    return true, ("Challenge sent to %s."):format(nameOf(target))
end

function H.accept(target)
    local invite = H.invites[target]
    if invite == nil then return false, "Nobody challenged you." end
    H.invites[target] = nil
    local from = invite.from
    if not connected(from) then return false, "That challenge is gone." end
    if busy(from) then return false, ("%s is busy now."):format(nameOf(from)) end
    if busy(target) then return false, "Leave your current match or queue first: /arena.leave" end
    local ok, why = H.admit(target, ACT.duel.id)
    if not ok then return false, why end
    local okFrom, whyFrom = H.check(from, ACT.duel.id, true)
    if not okFrom then
        H.tell(from, "warning", ACT.duel.label, whyFrom)
        return false, ("%s cannot duel right now."):format(nameOf(from))
    end
    H.tell(from, "success", ACT.duel.label, ("%s accepted."):format(nameOf(target)))
    if H.formDuel(from, target) then return true, "Duel on. Best of three." end
    return false, "The duel could not start. Try again in a moment."
end

function H.decline(target)
    local invite = H.invites[target]
    if invite == nil then return false, "Nobody challenged you." end
    H.invites[target] = nil
    H.tell(invite.from, "info", ACT.duel.label, ("%s declined."):format(nameOf(target)))
    return true, "Challenge declined."
end

-- `/arena.leave`, F1 or the panel: out of whatever the arena holds.
function H.leaveAll(playerId)
    local left = false
    if H.duelQueued(playerId) then H.withdrawDuel(playerId); left = true end
    H.dropInvites(playerId)
    if DM.instances.of(playerId) ~= nil then
        DM.leave(playerId, "auto")
        left = true
    elseif DM.arena.queuePosition(playerId) ~= nil then
        DM.leave(playerId, "queue")
        left = true
    elseif H.entered[playerId] ~= nil and not H.returning[playerId] then
        H.returnHome(playerId, "leave")
        left = true
    end
    DM.broadcastState()
    return left
end

-- ---------------------------------------------------------------------------
-- Statuses for the Activities panel

local PRACTICE = " \u{b7} bot practice, not recorded"

local function statusOf(key)
    local function ffaStatus(ruleset, def)
        local instance = H.ffaInstance(ruleset)
        local players = instance and #DM.instances.humans(instance) or 0
        local capacity = instance and tonumber(instance.capacity) or Config.instances.ffaCapacity
        if ruleset == "pve" then capacity = L.pve.maxPlayers end
        local detail
        if ruleset == "pve" then
            local bots = instance and H.botCount(instance) or 0
            detail = players > 0 and ("%d player%s vs %d bot%s"):format(players, players == 1 and "" or "s",
                bots, bots == 1 and "" or "s") or "Open: you and your crew against gang bots"
        elseif ruleset == "standard" and H.night then detail = "Arena Night"
        elseif players > 0 then detail = ("%d fighting"):format(players)
        else detail = "Open" end
        if ruleset ~= "pve" and botsFor(key) then detail = detail .. PRACTICE end
        return { phase = players > 0 and "running" or "idle", players = players, queued = 0,
            joinable = capacity == 0 or players < capacity, detail = detail }
    end
    if key == "ffa" then return ffaStatus("standard", ACT.ffa) end
    if key == "blade" then return ffaStatus("blade", ACT.blade) end
    if key == "pve" then return ffaStatus("pve", ACT.pve) end
    local formats = key == "duel" and { ["1v1"] = true } or { ["2v2"] = true, ["3v3"] = true }
    local matches, players = 0, 0
    for _, instance in pairs(DM.instances.registry) do
        if not instance.closed and formats[instance.format] then
            matches = matches + 1
            players = players + #DM.instances.humans(instance)
        end
    end
    local counts = DM.arena.queueCounts()
    local queued, detail
    if key == "duel" then
        queued = #H.duelQueue
        detail = matches > 0 and ("%d duel%s on"):format(matches, matches == 1 and "" or "s")
            or (queued > 0 and "1 waiting" or "Challenge with /duel <id>")
    else
        queued = (counts["2v2"] or 0) + (counts["3v3"] or 0)
        detail = ("2v2: %d waiting, 3v3: %d waiting"):format(counts["2v2"] or 0, counts["3v3"] or 0)
        if matches > 0 then detail = ("%d match%s on, "):format(matches, matches == 1 and "" or "es") .. detail end
    end
    if botsFor(key) then detail = detail .. PRACTICE end
    local phase = matches > 0 and "running" or (queued > 0 and "lobby" or "idle")
    return { phase = phase, players = players, queued = queued, joinable = true, detail = detail }
end
H.statusOf = statusOf

function H.pushStatuses(force)
    for key, def in pairs(ACT) do
        Core.status(def.id, statusOf(key), force)
    end
end

-- ---------------------------------------------------------------------------
-- Arena Night

function H.announce(text, title)
    local mode = L.night.announce
    local coreUp = GetResourceState(L.core) == "running"
    if (mode == "core" or mode == "both") and coreUp then
        TriggerEvent("op77_lightrp:announce", text, { title = title, durationMs = 10000 })
    end
    if mode == "own" or mode == "both" or not coreUp then
        TriggerClientEvent("op77_lightrp:notice", -1, {
            kind = "info", title = title, body = text, source = L.source, durationMs = 10000,
        })
    end
end

function H.nightStart(by, minutes)
    minutes = math.max(5, math.min(240, math.floor(tonumber(minutes) or L.night.minutes)))
    local fresh = H.night == nil
    H.night = { untilMs = now() + minutes * 60000, minutes = minutes, by = by }
    local instance = H.ffaInstance("standard")
    if instance ~= nil then
        H.applyNight(instance)
        -- The round running now ends; the next one plays the night rules.
        if instance.round ~= nil and instance.round.state == "active" then
            DM.round.finish(instance, "arena_night")
        end
    end
    if fresh then H.announce(L.night.text, L.night.title) end
    H.pushStatuses()
    log(("Arena Night on for %d min (by %s)"):format(minutes, tostring(by)))
    return true, ("Arena Night on for %d minutes."):format(minutes)
end

function H.nightStop(reason)
    if H.night == nil then return false, "Arena Night is not on." end
    H.night = nil
    for _, instance in pairs(DM.instances.registry) do H.clearNight(instance) end
    H.announce(L.night.endText, L.night.title)
    H.pushStatuses()
    log("Arena Night off (" .. tostring(reason) .. ")")
    return true, "Arena Night is over."
end

-- ---------------------------------------------------------------------------
-- The tick: results, statuses, queue bookkeeping

function H.tick(t)
    t = t or now()
    if H.night ~= nil and t >= H.night.untilMs then H.nightStop("expired") end

    for _, instance in pairs(DM.instances.registry) do
        if not instance.closed and instance.match ~= nil then
            H.sample(instance)
            local state = instance.match.state
            if (state == "resolved" or state == "closing") and instance.match.result ~= nil then
                H.reportMatch(instance)
            end
        end
    end

    -- Entered, out of every instance, nobody bringing them home: bring them home.
    for id, entry in pairs(H.entered) do
        if DM.instances.of(id) == nil and not H.returning[id] then H.returnHome(id, "orphan") end
    end

    -- Queue entries the engine dropped (stale, revalidation): the panel lets go too.
    for id, format in pairs(H.lastQueued) do
        local _, now_ = DM.arena.queuePosition(id)
        if now_ == nil and DM.instances.of(id) == nil and H.entered[id] == nil then
            H.clearPending(id, format == "1v1" and ACT.duel.id or ACT.teams.id)
        end
    end
    local current = {}
    for _, id in ipairs(GetPlayers() or {}) do
        local n = pid(id)
        if n then
            local _, format = DM.arena.queuePosition(n)
            if format then current[n] = format end
        end
    end
    H.lastQueued = current
    for id in pairs(H.teamUpgraded) do
        if current[id] == nil then H.teamUpgraded[id], H.teamQueuedAt[id] = nil, nil end
    end
    if botsFor("teams") then H.upgradeTeamQueues(false) end

    -- Bots never outlive the players of their instance; a round with bots is marked.
    for _, instance in pairs(DM.instances.registry) do
        if not instance.closed and instance.format == "ffa" then
            if #DM.instances.humans(instance) == 0 then
                if H.botCount(instance) > 0 or inFlight(instance) > 0 then H.clearBots(instance, "no_players") end
            elseif H.botCount(instance) > 0 then
                markBots(instance)
            end
        end
    end

    local inviteMs = L.duel.inviteSeconds * 1000
    for target, invite in pairs(H.invites) do
        if t - invite.atMs >= inviteMs or not connected(invite.from) or not connected(target) then
            H.invites[target] = nil
            if connected(invite.from) then H.tell(invite.from, "info", ACT.duel.label, "Challenge expired.") end
        end
    end
    local waitMs = L.duel.waitMinutes * 60000
    for index = #H.duelQueue, 1, -1 do
        local item = H.duelQueue[index]
        if not connected(item.playerId) then
            table.remove(H.duelQueue, index)
        elseif botsFor("duel") and t - item.atMs >= L.bots.duelWaitMs then
            local started, text = H.startBotDuel(item.playerId)
            H.tell(item.playerId, started and "success" or "warning", ACT.duel.label, text)
        elseif t - item.atMs >= waitMs then
            table.remove(H.duelQueue, index)
            H.tell(item.playerId, "info", ACT.duel.label, "No opponent found. Try again later.")
            H.clearPending(item.playerId, ACT.duel.id)
        end
    end

    for id, until_ in pairs(H.recent) do
        if until_ <= t then H.recent[id] = nil end
    end
    H.pushStatuses()
end

-- ---------------------------------------------------------------------------
-- Light RP: registration and the core's requests

function H.register()
    local registered = 0
    for _, def in pairs(ACT) do
        local ok, why = Core.register({
            id = def.id, resource = GetCurrentResourceName(), label = def.label, kind = def.kind,
            description = def.description, minPlayers = def.minPlayers, maxPlayers = def.maxPlayers,
            caps = { rpWeapons = false, rpItems = false, needs = false, vehicles = false },
            modes = def.modes,
        })
        if ok then registered = registered + 1
        else log(("%s not registered: %s"):format(def.id, tostring(why))) end
    end
    -- The switch as Light RP holds it now: the event alone misses a switch flipped
    -- while either resource was restarting.
    if registered > 0 then H.setBotMode(Core.bots(), "register") end
    Core.forgetStatuses()
    H.pushStatuses(true)
    return registered
end

-- Staff bot mode, from op77_lightrp. A host-wide event only: never a net event.
AddEventHandler(Core.events.bots, function(enabled)
    if H.stopped then return end
    H.setBotMode(enabled == true, "lightrp")
end)

AddEventHandler("op77_lightrp:activity:join", function(playerId, activityId, options)
    local id = pid(playerId)
    local key = keyOf(activityId)
    if id == nil or key == nil or H.stopped then return end
    options = type(options) == "table" and options or {}
    H.noteSquad(id, options.squad)
    if key == "ffa" then H.joinFfa(id, "standard")
    elseif key == "blade" then H.joinFfa(id, "blade")
    elseif key == "pve" then H.joinFfa(id, "pve")
    elseif key == "teams" then H.queueTeams(id, options.mode)
    elseif key == "duel" then
        local target = pid(options.target)
        if target ~= nil then
            local ok, text = H.challenge(id, target)
            H.tell(id, ok and "success" or "warning", ACT.duel.label, text)
            if not ok then H.clearPending(id, ACT.duel.id) end
        else
            H.queueDuel(id)
        end
    end
end)

AddEventHandler("op77_lightrp:activity:leaveRequest", function(playerId, activityId)
    local id = pid(playerId)
    local key = keyOf(activityId)
    if id == nil or key == nil then return end
    if key == "duel" then
        H.withdrawDuel(id, true)
    end
    local instance = DM.instances.of(id)
    local entry = H.entered[id]
    if instance ~= nil and activityOfInstance(instance) == activityId then
        DM.leave(id, "auto")
    elseif entry ~= nil and entry.activity == activityId then
        if not H.returning[id] then H.returnHome(id, "leave_request") end
    else
        local _, format = DM.arena.queuePosition(id)
        if format ~= nil and ((key == "teams" and format ~= "1v1") or (key == "duel" and format == "1v1")) then
            DM.leave(id, "queue")
        end
    end
    DM.broadcastState()
end)

-- Light RP already released the player: clean up, never call activityLeave.
AddEventHandler("op77_lightrp:activity:dropped", function(playerId, activityId, reason)
    local id = pid(playerId)
    local key = keyOf(activityId)
    if id == nil or key == nil then return end
    local entry = H.entered[id]
    if entry == nil or entry.activity ~= activityId then return end
    H.released[id] = true
    H.withdrawDuel(id, true)
    if reason ~= "disconnect" and DM.instances.of(id) ~= nil then
        DM.leave(id, "auto")
    end
    H.forget(id)
    DM.broadcastState()
end)

AddEventHandler("op77_lightrp:activity:ready", function()
    if not H.stopped then H.register() end
end)

AddEventHandler("onResourceStart", function(name)
    if name == L.core then
        SetTimeout(1000, function() if not H.stopped then H.register() end end)
    elseif name == GetCurrentResourceName() then
        H.register()
    end
end)

AddEventHandler("onPlayerDisconnected", function(playerIdStr)
    local id = pid(playerIdStr)
    if id == nil then return end
    H.noteQuit(id)
    H.withdrawDuel(id, true)
    H.forget(id)
    H.throttle[id], H.checks[id], H.names[id], H.identities[id] = nil, nil, nil, nil
    H.recent[id], H.lastQueued[id], H.evicting[id] = nil, nil, nil
    H.squads[id], H.teamQueuedAt[id], H.teamUpgraded[id] = nil, nil, nil
end)

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    H.stopped = true
    -- Light RP returns everyone it held for us (provider_stopped); the arena
    -- weapons go first so they never outlive the arena.
    for id in pairs(H.entered) do
        pcall(engine.strip, id)
        TriggerClientEvent("op77_arena:returned", id, { reason = "stopped" })
    end
    -- No bot outlives the resource: parked spawns first, then every body.
    botsCall("dropPending", nil)
    botsCall("clear", nil, "resource_stop")
end)

CreateThread(function()
    while not H.stopped do
        Wait(500)
        local ok, err = pcall(H.tick)
        if not ok then log("tick failed: " .. tostring(err)) end
    end
end)

-- ---------------------------------------------------------------------------
-- Commands (none bound to a key)

local function isBladeKey(key)
    for _, weapon in ipairs(DM.loadout.bladeList()) do
        if weapon.key == key then return true end
    end
    return false
end

local function weaponCommand(source, args, raw)
    local instance = DM.instances.of(source)
    local wanted = args[1] and tostring(args[1]):lower() or nil
    local Loadout = DM.loadout
    local blade = instance ~= nil and instance.ruleset == "blade"
    if instance == nil and wanted ~= nil and isBladeKey(wanted) then blade = true end
    if blade then
        if wanted == nil or wanted == "list" then
            local keys = {}
            for _, weapon in ipairs(Loadout.bladeList()) do keys[#keys + 1] = weapon.key end
            return reply(source, raw, true, "Blade Night: /arena.weapon <key>. " .. table.concat(keys, ", "))
        end
        local ok, why = Loadout.chooseBlade(source, wanted)
        return reply(source, raw, ok, ok and "Blade saved." or tostring(why))
    end
    if instance ~= nil and instance.format ~= "ffa" then
        return reply(source, raw, false, "Team matches use kits: /arena.kit")
    end
    if wanted == nil or wanted == "list" then
        local keys = {}
        for _, entry in ipairs(Loadout.primaryList()) do keys[#keys + 1] = entry.key end
        local mine = Loadout.chosenPrimary(source)
        return reply(source, raw, true, ("Combat Zone: /arena.weapon <key>. Yours: %s. %s"):format(
            tostring(mine and mine.key or "none"), table.concat(keys, ", ")))
    end
    local ok, key = Loadout.chooseWeapons(source, wanted)
    if not ok then return reply(source, raw, false, ("No weapon called \"%s\". /arena.weapon list"):format(wanted)) end
    return reply(source, raw, true, ("Weapon saved: %s."):format(tostring(key)))
end

local function kitCommand(source, args, raw)
    local Loadout = DM.loadout
    local wanted = args[1] and tostring(args[1]):lower() or nil
    if wanted == nil or wanted == "list" then
        local keys = {}
        for _, kit in ipairs(Loadout.kitList()) do keys[#keys + 1] = kit.key end
        return reply(source, raw, true, "Kits (pick during the buy window): " .. table.concat(keys, ", "))
    end
    local ok = DM.arena.pickKit(source, wanted)
    return reply(source, raw, ok == true, ok and ("Kit: %s."):format(wanted) or "Kits are picked during the buy window of a team match or duel.")
end

local function statusLine()
    local parts = {}
    for _, key in ipairs({ "ffa", "blade", "pve", "duel", "teams" }) do
        local status = statusOf(key)
        parts[#parts + 1] = ("%s: %s"):format(ACT[key].label, status.detail)
    end
    return table.concat(parts, " | ")
end

local HELP = "/arena.ffa Combat Zone, /arena.blade Blade Night, /arena.pve PvE, /arena.queue 2v2|3v3, "
    .. "/duel <id>, /duel random, /duel bot (bot mode), /arena.weapon, /arena.kit, /arena.leave."

local function playerOnly(source, raw)
    if source == nil or source <= 0 then
        reply(source, raw, false, "In-game only.")
        return false
    end
    return true
end

RegisterCommand("arena", function(source, args, raw)
    reply(source, raw, true, statusLine())
    if source and source > 0 then reply(source, raw, true, HELP) end
end, false)

-- A command is one person's request: no crew rides on it (the panel passes the crew).
RegisterCommand("arena.ffa", function(source, args, raw)
    if not playerOnly(source, raw) then return end
    H.squads[source] = nil
    reply(source, raw, H.joinFfa(source, "standard"), "Combat Zone requested.")
end, false)

RegisterCommand("arena.blade", function(source, args, raw)
    if not playerOnly(source, raw) then return end
    H.squads[source] = nil
    reply(source, raw, H.joinFfa(source, "blade"), "Blade Night requested.")
end, false)

RegisterCommand("arena.pve", function(source, args, raw)
    if not playerOnly(source, raw) then return end
    H.squads[source] = nil
    reply(source, raw, H.joinFfa(source, "pve"), "PvE Combat Zone requested.")
end, false)

RegisterCommand("arena.queue", function(source, args, raw)
    if not playerOnly(source, raw) then return end
    H.squads[source] = nil
    local format = args[1] and tostring(args[1]):lower() or L.teams.defaultFormat
    if format ~= "2v2" and format ~= "3v3" then return reply(source, raw, false, "Usage: /arena.queue 2v2|3v3") end
    reply(source, raw, H.queueTeams(source, format), ("Team Arena %s requested."):format(format))
end, false)

RegisterCommand("arena.leave", function(source, args, raw)
    if not playerOnly(source, raw) then return end
    local left = H.leaveAll(source)
    reply(source, raw, left, left and "Leaving the arena." or "You are not in the arena.")
end, false)

RegisterCommand("arena.weapon", function(source, args, raw)
    if not playerOnly(source, raw) then return end
    weaponCommand(source, args, raw)
end, false)

RegisterCommand("arena.kit", function(source, args, raw)
    if not playerOnly(source, raw) then return end
    kitCommand(source, args, raw)
end, false)

RegisterCommand("duel", function(source, args, raw)
    if not playerOnly(source, raw) then return end
    local verb = args[1] and tostring(args[1]):lower() or nil
    local ok, text
    if verb == nil then
        ok, text = false, "Usage: /duel <id> | accept | decline | cancel | random | bot"
    elseif verb == "accept" then ok, text = H.accept(source)
    elseif verb == "decline" then ok, text = H.decline(source)
    elseif verb == "cancel" then
        H.withdrawDuel(source, true)
        ok, text = true, "Duel requests cancelled."
    elseif verb == "random" then
        ok = H.queueDuel(source)
        text = ok and "Looking for an opponent." or "Could not queue."
    elseif verb == "bot" then
        ok, text = H.duelBot(source)
    else
        ok, text = H.challenge(source, pid(verb))
    end
    reply(source, raw, ok, text)
end, false)

RegisterCommand("arena.night", function(source, args, raw)
    local verb = args[1] and tostring(args[1]):lower() or "status"
    local ok, text
    if verb == "start" then ok, text = H.nightStart(source, args[2])
    elseif verb == "stop" then ok, text = H.nightStop("staff")
    else
        ok = true
        text = H.night and ("Arena Night on, %d min left."):format(math.ceil((H.night.untilMs - now()) / 60000))
            or "Arena Night is off. /arena.night start [minutes] | stop"
    end
    reply(source, raw, ok, text)
end, true)

-- Chat completions, when open77_chat is up.
RegisterNetEvent("chat:ready", function()
    local id = pid(source)
    if id == nil then return end
    TriggerClientEvent("chat:addSuggestions", id, {
        { command = "/arena", help = "Arena activities and how to join them." },
        { command = "/arena.leave", help = "Leave the arena, a queue or a duel request." },
        { command = "/duel", help = "Challenge a player near you to a best-of-three duel.",
          parameters = { { name = "id", help = "player id, or accept / decline / cancel / random / bot" } } },
        { command = "/arena.pve", help = "PvE Combat Zone: you and your crew against gang bots." },
    })
end)
