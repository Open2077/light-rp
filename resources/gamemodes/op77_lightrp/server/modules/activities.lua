-- Activities: the core every activity provider plugs into (op77_arena, op77_race,
-- op77_chase, op77_fireworks...). A provider runs its own instances; Light RP
-- owns the player while they play: it captures where they came from, puts the RP
-- weapons aside, freezes the needs, refuses RP items / vehicles / housing / work
-- orders per the activity's caps, skips its own death handling, never saves the
-- activity's position, and brings the player back when it ends. Results become
-- stats and leaderboards (never cash, never items); PvE results also reputation.
--
-- Contract: server exports of op77_lightrp, synchronous, never yield, no DB write.
--   activityRegister(def)                    -> true | false, reason
--       def = { id = "arena.ffa", resource, label, kind = "pvp"|"race"|"chase"|"event",
--               description, minPlayers, maxPlayers,
--               caps = { rpWeapons, rpItems, needs, vehicles },   -- every cap false by default
--               pve = true|false,                                 -- optional: players vs bots
--               difficulties = { "standard", "hard", "critical" } } -- optional, PvE only
--   activityCheck(playerId, activityId, opts)-> true | false, reason   (eligibility only;
--                                               opts.difficulty: the reputation tier too,
--                                               the crew leader's for a crew member)
--   activityEnter(playerId, activityId, opts)-> true | false, reason   (opts.difficulty, else
--                                               the one picked in the panel)
--   activityLeave(playerId, activityId, opts)-> true | false, reason   (opts.returnPlayer, default true)
--   activityOwner(playerId)                  -> activityId ("missions" in a mission) | nil
--   activityPlayer(playerId)                 -> { name, identifier, characterKey } | nil
-- PvE and reputation (docs/pve-progression.md): only an activity with `pve = true`
-- (or listed in server/config/activities.lua `pve.activities`) grants reputation;
-- every other result records stats at 0 reputation, whatever it asks. A PvE
-- activity's `difficulties` are offered by the panel; the core refuses one above
-- the player's reputation tier and hands options.difficulty + options.scaling to
-- the provider. A PvE result earns the difficulty's reward x the activity's weight:
-- the full reward for `won = true` without `reputation`, else min(reputation, it).
-- Its difficulty is the entry's (else result.difficulty), lowered to the highest
-- one the player's tier allows. A crew member is never refused for the difficulty
-- their leader picked (owner decision 2026-11-03): below its tier they play it in
-- full and their result counts at the highest difficulty their tier opens; only the
-- leader's own tier gates the pick (and a solo player's).
-- Events, TriggerEvent / AddEventHandler only (never network events):
--   provider -> core  op77_lightrp:activity:result  (playerId, activityId, result)
--   provider -> core  op77_lightrp:activity:status  (activityId, status)
--   core -> provider  op77_lightrp:activity:join    (playerId, activityId, options)
--   core -> provider  op77_lightrp:activity:leaveRequest (playerId, activityId)
--   core -> provider  op77_lightrp:activity:dropped (playerId, activityId, reason)
--   core -> provider  op77_lightrp:activity:ready   ()  Light RP (re)started: register again
--   core -> provider  op77_lightrp:activity:bots    (enabled)  staff bot mode toggled
--
-- Lobby (server/config/activities.lua `lobby`): the join's options also carry
--   options.ranked  always: true = the result counts (stats, leaderboards, Hall of Fame,
--                   reputation, pay); false = a friendly crew match, any bot fill in PvP,
--                   staff bot mode. PvE stays ranked with allied bots. A provider writes
--                   none of its own ranked data (rating, ELO, records) when false.
--   options.fill    nil | { allies, enemies }: bots the provider adds, a target for the
--                   group's instance (the same on every member's join, applied once).
--   options.match   nil | { id, friendly, format, players, teams, side, bots }: a match
--                   formed by the core (a friendly, a bot match chosen up front, a bot
--                   fill accepted after the ranked wait). Every player of it gets a join
--                   with the same id in one tick; the provider puts exactly `players` in
--                   one instance of their own, on `teams[side]`, with `bots[side]` bots.
--   A ranked search (a PvP join without bots) goes to the provider's own queue as
--   before; after `lobby.fillAfterMs` its leader is offered a bot fill (unranked).
--   A.isRanked(entry | match | playerId), export activityRanked(playerId): the flag.
--   A.result decides once per result: unranked (the entry's flag, staff bot mode,
--   result.test / result.unranked, a PvP result with stats.bots or stats.vsAi) sets
--   result.unranked = true and records nothing -- no stats (so no Hall of Fame row),
--   no reputation, no pay (activity_pay.lua refuses result.unranked too).
--
-- Bot mode (/lightrp.bots on|off, staff, never persisted): providers let ONE player start
-- what normally needs several and fill the missing players with bots (activityBots() is
-- the current value: read it after every successful activityRegister). While it is on
-- the core records no result: no stats, no leaderboard, no reputation.
--
-- Inside Light RP (one-line hooks in the other modules):
--   LightRP.activities.owns(id)               a provider (missions included) owns the player
--   LightRP.activities.owner(id)              its activity id ("missions"), or nil
--   LightRP.activities.allows(id, cap)        true when not owned, else the owner's cap
--   LightRP.activities.savedPosition(id, p)   the return point while owned, else p
--   module hook onActivityChanged(id, activityId, { pve, kind, difficulty })  entered
--               onActivityChanged(id, nil, { left = activityId, reason })     released
local C = LightRpActivities
local Db = LightRP.db
local A = LightRP.module("activities", { operations = {}, extensions = {} })

local EV = {
    result = "op77_lightrp:activity:result",
    status = "op77_lightrp:activity:status",
    join = "op77_lightrp:activity:join",
    leaveRequest = "op77_lightrp:activity:leaveRequest",
    dropped = "op77_lightrp:activity:dropped",
    ready = "op77_lightrp:activity:ready",
    bots = "op77_lightrp:activity:bots",
}
A.events = EV

local SELF = type(GetCurrentResourceName) == "function" and GetCurrentResourceName() or "op77_lightrp"
local KINDS = { pvp = true, race = true, chase = true, event = true }
local CAPS = { "rpWeapons", "rpItems", "needs", "vehicles" }
local PHASES = { idle = true, lobby = true, running = true }
local RESULT_INTERVAL_MS = 15000 -- a provider posting results in a loop is refused in between
local PENDING_MS = 15 * 60000    -- a join request nobody turned into an entry (op77_chase's queue lasts 900 s)

local registry = {}   -- activityId -> activity (validated definition + status)
local order = {}      -- activity ids, registration order
local internal = {}   -- providerId -> { label, owns(id), caps(id), savedPosition(id) }
local owned = {}      -- playerId -> entry { token, activity, resource, generation, caps, returnPoint, identity, character }
local returning = {}  -- playerId -> entry, while the way back runs (still owned for death and saves)
local recent = {}     -- playerId -> { [activityId] = entry } after the leave: a late result
local pending = {}    -- playerId -> { activity, at }: join asked, not entered yet
local leaving = {}    -- playerId -> { token, at }: leave asked of the provider
local damagedAt = {}  -- playerId -> ms of the last damage taken outside an activity
local watchers = {}   -- playerId -> ms until which the panel gets live pushes
local mine = {}       -- playerId -> { key, stats = { [activityId] = row }, day, today }
local tops = {}       -- activityId -> { list, at }
local starting = {}   -- resource -> generation when its incoming VM started
local generation, tokenSeq = 0, 0
-- Without a database: the session's rows.
local memStats, memDaily = {}, {}
local matches = {}    -- matchId -> { id, activity, friendly, ranked = false, players, teams, bots, enemies, format, at }
local friendlies = {} -- leaderId -> { activity, mode, teams, bench, players, bots, at }: a friendly being set up
local matchSeq = 0

A.registry, A.owned = registry, owned
A.matches, A.friendlies = matches, friendlies
-- Copies of the session rows (no database) for the Hall of Fame, read only
-- (server/modules/halloffame.lua). key = identifier|characterKey|activityId|board.
function A.memoryRows()
    local list = {}
    for key, row in pairs(memStats) do
        local copy = { key = key }
        for k, v in pairs(row) do copy[k] = v end
        list[#list + 1] = copy
    end
    return list
end

-- ---------------------------------------------------------------------------
-- Small helpers

local function now() return LightRP.nowMs() end
local function pid(value)
    value = tonumber(value)
    if value and value >= 1 and value % 1 == 0 then return math.floor(value) end
    return nil
end
local function int(value, lo, hi)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge or value == -math.huge then return nil end
    value = math.floor(value)
    if value < lo then value = lo elseif value > hi then value = hi end
    return value
end
local function num(value, lo, hi)
    value = tonumber(value)
    if value == nil or value ~= value or value == math.huge or value == -math.huge then return nil end
    return math.max(lo, math.min(hi, value))
end
-- A short single-line text, cut on a UTF-8 boundary.
local function clean(value, max)
    if type(value) ~= "string" then return nil end
    value = value:gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #value == 0 then return nil end
    if #value > max then
        local cut = max
        while cut > 0 do
            local b = value:byte(cut + 1)
            if not b or b < 0x80 or b >= 0xC0 then break end
            cut = cut - 1
        end
        value = value:sub(1, cut)
    end
    return value
end
local function caller()
    local name = type(GetInvokingResource) == "function" and GetInvokingResource() or nil
    if type(name) ~= "string" or name == "" or name == SELF then return nil end
    return name
end
-- A provider acts on its own activities only (when the host names the caller).
local function foreign(resource)
    local by = caller()
    return by ~= nil and by ~= resource
end
local function running(resource)
    if type(GetResourceState) ~= "function" then return true end
    local state = GetResourceState(resource)
    return state == "running" or state == "starting"
end
local function bucketOf(id)
    if type(GetPlayerRoutingBucket) == "function" then return tonumber(GetPlayerRoutingBucket(id)) or 0 end
    local p = Open77.players.position(id)
    return p and tonumber(p.bucket) or 0
end
local function identity(id)
    local c = LightRP.characters and LightRP.characters.get(id)
    if not c or c.status ~= "active" or not c.identifier or not c.key then return nil end
    return { name = LightRP.characters.displayName(id), identifier = c.identifier, characterKey = c.key }, c
end
-- activityPlayer: the identity plus the character's gang and job, read from the
-- jobs module (the same view as the `gang` / `job` state bags). gang is nil
-- without an affiliation; job.onDuty stays nil: Light RP has no duty toggle.
function A.player(id)
    local who = identity(id)
    if not who then return nil end
    local J = LightRP.jobs
    if J and type(J.gang) == "function" then
        local ok, g = pcall(J.gang, id)
        if ok and type(g) == "table" and g.name and g.name ~= "none" then
            who.gang = { id = g.name, label = g.label, grade = g.grade, gradeLabel = g.gradeLabel, tag = g.tag, color = g.color }
        end
    end
    if J and type(J.get) == "function" then
        local ok, j = pcall(J.get, id)
        if ok and type(j) == "table" and j.name then
            who.job = { id = j.name, label = j.label, grade = j.grade, gradeLabel = j.gradeLabel, tag = j.tag }
        end
    end
    return who
end
local function emit(name, ...)
    local ok, err = pcall(TriggerEvent, name, ...)
    if not ok then LightRP.log("activities: %s failed: %s", name, tostring(err)) end
    return ok
end
local function labelOf(activityId)
    local a = registry[activityId]
    if a then return a.label end
    local p = internal[activityId]
    return p and p.label or tostring(activityId)
end

-- ---------------------------------------------------------------------------
-- PvE: difficulties and the reputation tiers that open them (server/modules/
-- missions.lua owns the tiers). docs/pve-progression.md.

local PVE = type(C.pve) == "table" and C.pve or {}
local DIFFS, DIFF_INDEX = {}, {}
for i, d in ipairs(PVE.difficulties or {}) do
    if type(d) == "table" and type(d.id) == "string" then DIFFS[d.id], DIFF_INDEX[d.id] = d, i end
end
local function tierOf(id)
    local M = LightRP.missions
    if M and type(M.tier) == "function" then
        local ok, tier = pcall(M.tier, id)
        if ok and tonumber(tier) then return math.floor(tier) end
    end
    return 1
end
local function tierLabel(tier)
    local M = LightRP.missions
    if M and type(M.tierLabel) == "function" then
        local ok, text = pcall(M.tierLabel, tier)
        if ok and type(text) == "string" then return text end
    end
    return tostring(tier)
end
local function minTierOf(diffId)
    local d = DIFFS[diffId]
    return d and math.max(1, math.floor(tonumber(d.minTier) or 1)) or 1
end
-- The difficulties an activity offers (ids, in the config's order). A PvE activity
-- that declares none plays one: the config's first (Standard).
local function offered(a)
    if a and a.difficulties then return a.difficulties end
    local first = PVE.difficulties and PVE.difficulties[1]
    return first and { first.id } or {}
end
local function offers(list, diffId)
    for _, d in ipairs(list) do if d == diffId then return true end end
    return false
end
-- May this player pick this difficulty of this activity? true | false, reason
local function difficultyAllowed(id, a, diffId)
    if not a or not a.pve then return true end
    if not offers(offered(a), diffId) then return false, "Choose a difficulty: " .. table.concat(offered(a), ", ") .. "." end
    local need = minTierOf(diffId)
    if tierOf(id) < need then
        return false, string.format("%s needs reputation tier %s: PvE missions, raids, gigs and PvE activities earn it.",
            DIFFS[diffId] and DIFFS[diffId].label or diffId, tierLabel(need))
    end
    return true
end
function A.difficultyAllowed(id, activityId, diffId) return difficultyAllowed(pid(id) or id, registry[activityId], diffId) end
-- The player's crew (server/modules/parties.lua), guarded: tests stub parties.
local function crewOf(id)
    local P = LightRP.parties
    return P and type(P.of) == "function" and P.of(id) or nil
end
-- The leader of the crew this player is a member of (not its leader), else nil.
local function crewLeaderOf(id)
    local party = crewOf(id)
    if party and #(party.members or {}) > 1 and party.leader ~= id then return party.leader end
    return nil
end
-- May this player play this difficulty? A crew member is never refused for their own
-- tier: the leader picks, so the leader's tier counts, and a member below it plays at
-- full difficulty for the reward of their own tier (effectiveDifficulty). The leader
-- and a solo player are gated (difficultyAllowed). true[, nil, carried] | false, reason
local function difficultyFor(id, a, diffId)
    local allowed, why = difficultyAllowed(id, a, diffId)
    if allowed then return true end
    local leader = crewLeaderOf(id)
    if leader and offers(offered(a), diffId) and difficultyAllowed(leader, a, diffId) then return true, nil, true end
    return false, why
end
A.difficultyFor = function(id, activityId, diffId) return difficultyFor(pid(id) or id, registry[activityId], diffId) end
-- The difficulty a result counts at: the wanted one (the lowest offered when it is
-- not offered), lowered to the highest offered one the player's tier allows.
local function effectiveDifficulty(id, list, wanted)
    local cap = DIFF_INDEX[offers(list, wanted) and wanted or list[1]] or 0
    local tier, best = tierOf(id), nil
    for _, d in ipairs(list) do
        if (DIFF_INDEX[d] or math.huge) <= cap and minTierOf(d) <= tier then best = d end
    end
    return best
end
local function diffLabel(diffId) return DIFFS[diffId] and DIFFS[diffId].label or tostring(diffId) end
-- What a crew member carried above their tier is told, once: they play it, for less.
local function carriedLine(id, a, diffId)
    local basis = effectiveDifficulty(id, offered(a), diffId)
    if not basis then return string.format("%s is above your street cred: you play it, it earns you no reputation.", diffLabel(diffId)) end
    return string.format("%s is above your street cred: you play it, you earn the %s reward.", diffLabel(diffId), diffLabel(basis))
end
local function rewardOf(diffId, weight)
    local d = DIFFS[diffId]
    return d and math.max(0, math.floor((tonumber(d.reputation) or 0) * (weight or 1) + 0.5)) or 0
end
local function scalingOf(diffId)
    local out = {}
    for k, v in pairs(DIFFS[diffId] and DIFFS[diffId].scaling or {}) do out[k] = v end
    return out
end
-- What a result asks for before the daily cap, and the difficulty it counts at:
-- nothing outside PvE (unless `pvpGrants`), else the difficulty's reward x the
-- activity's weight -- in full for a win that names no amount, never more.
local function reputationAsk(id, e, r)
    if not e.pve then
        if C.reputation.pvpGrants == true then return math.min(r.reputation or 0, C.reputation.maxPerResult), nil end
        return 0, nil
    end
    local diff = effectiveDifficulty(id, e.difficulties or offered(nil), e.difficulty or r.difficulty)
    if not diff then return 0, nil end
    local full = rewardOf(diff, e.weight)
    if r.reputation == nil then return r.won and full or 0, diff end
    return math.min(r.reputation, full), diff
end
A.reputationAsk = reputationAsk

-- ---------------------------------------------------------------------------
-- Internal providers: Light RP's own instances. Missions own their operators
-- (death, kit), return them to the mission point and keep their RP items.

function A.registerInternal(id, provider) internal[id] = provider end
A.labelOf = labelOf

A.registerInternal("missions", {
    label = "Mission",
    owns = function(id)
        local M = LightRP.missions
        return M ~= nil and type(M.handlesDeath) == "function" and M.handlesDeath(id) == true
    end,
    caps = function(id)
        local M = LightRP.missions
        local kit = M and type(M.handlesLoadout) == "function" and M.handlesLoadout(id)
        return { rpWeapons = not kit, rpItems = true, needs = false, vehicles = true }
    end,
    -- where the mission sends its operators home: the board's point (sendHome)
    savedPosition = function(id)
        local M = LightRP.missions
        local inst = M and type(M.instanceOf) == "function" and M.instanceOf(id)
        local point = inst and type(M.point) == "function" and M.point(inst.point)
        return point and point.position or nil
    end,
})

local function internalOwner(id)
    for name, provider in pairs(internal) do
        local ok, yes = pcall(provider.owns, id)
        if ok and yes then return name, provider end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Internal API (hooks)

function A.current(id) return owned[pid(id) or id] end
function A.owner(id)
    id = pid(id) or id
    local e = owned[id] or returning[id]
    if e then return e.activity end
    return (internalOwner(id))
end
function A.owns(id) return A.owner(id) ~= nil end
function A.allows(id, cap)
    id = pid(id) or id
    local e = owned[id] or returning[id]
    if e then
        local a = registry[e.activity]
        local caps = (a and a.generation == e.generation and a.caps) or e.caps
        return caps ~= nil and caps[cap] == true
    end
    local _, provider = internalOwner(id)
    if not provider then return true end
    local ok, caps = pcall(provider.caps, id)
    return ok and type(caps) == "table" and caps[cap] == true
end
-- A routing bucket of the activity providers' ranges (their own vehicles live there).
function A.ownsBucket(bucket)
    bucket = tonumber(bucket)
    if not bucket then return false end
    for _, range in ipairs(C.buckets or {}) do
        if bucket >= range[1] and bucket <= range[2] then return true end
    end
    return false
end
-- What the character saves as its position: never an activity's or a mission's
-- coordinates. nil (the owner has no point) keeps the previous sample.
function A.savedPosition(id, fallback)
    id = pid(id) or id
    local e = owned[id] or returning[id]
    if e then return e.returnPoint end
    local _, provider = internalOwner(id)
    if provider then
        if not provider.savedPosition then return nil end
        local ok, at = pcall(provider.savedPosition, id)
        return ok and type(at) == "table" and type(at.x) == "number" and at or nil
    end
    return fallback
end

-- ---------------------------------------------------------------------------
-- Eligibility, in the contract's order; `activityId` nil: any activity.

local function check(id, activityId)
    local who = identity(id)
    if not who or (LightRP.characters.switching or {})[id] then return false, "You need an active character first." end
    local life = Open77.players.getLifeState(id)
    if not life or life.phase ~= "alive" then return false, "You must be alive and on your feet." end
    if LightRP.medical and type(LightRP.medical.isDowned) == "function" and LightRP.medical.isDowned(id) then
        return false, "You are down. Get treated first."
    end
    local e = owned[id]
    if e then return false, "You are already in " .. labelOf(e.activity) .. "." end
    if returning[id] then return false, "You are still on your way back." end
    local other = internalOwner(id)
    if other == "missions" then return false, "You are on a mission. Finish or leave it first."
    elseif other then return false, "You are busy with " .. labelOf(other) .. "." end
    if LightRP.tutorial and type(LightRP.tutorial.isActive) == "function" and LightRP.tutorial.isActive(id) then
        return false, "Finish or skip your first day guide first."
    end
    if LightRP.housing and type(LightRP.housing.sessions) == "table" and LightRP.housing.sessions[id] then
        return false, "Leave your dwelling first."
    end
    if Open77.vehicles and type(Open77.vehicles.getPlayerSeat) == "function" and Open77.vehicles.getPlayerSeat(id) then
        return false, "Step out of the vehicle first."
    end
    local hurt = damagedAt[id]
    if hurt and now() - hurt < C.damageCooldownMs then
        return false, string.format("You were hurt less than a minute ago. Wait %d s.", math.ceil((C.damageCooldownMs - (now() - hurt)) / 1000))
    end
    -- the return point is in the shared city: the saved position carries no bucket
    if bucketOf(id) ~= 0 then return false, "Return to the shared city first." end
    return true
end
A.check = check

-- ---------------------------------------------------------------------------
-- State pushes

local pushQueued = false
local function audience()
    local set, t = {}, now()
    for id, untilMs in pairs(watchers) do if untilMs > t then set[id] = true else watchers[id] = nil end end
    for id in pairs(owned) do set[id] = true end
    for id in pairs(pending) do set[id] = true end
    for id in pairs(returning) do set[id] = true end
    return set
end
local function pushAll()
    pushQueued = false
    for id in pairs(audience()) do LightRP.state(id, "activities") end
end
-- Coalesced: a provider may send a status every tick.
local function dirty()
    if pushQueued then return end
    pushQueued = true
    SetTimeout(C.statusPushMs, pushAll)
end
A.dirty = dirty
local function touch(id) LightRP.state(id, "activities") end
function A.watch(id) watchers[id] = now() + C.watchMs end

-- ---------------------------------------------------------------------------
-- Registry

local function validate(def)
    if type(def) ~= "table" then return nil, "The definition must be a table." end
    local id = def.id
    if type(id) ~= "string" or #id > 48 or not id:match("^%l[%l%d_]*%.[%l%d_%-]+$") then
        return nil, "The id must be namespaced, like arena.ffa."
    end
    local resource = def.resource
    if type(resource) ~= "string" or resource == "" or #resource > 64 then return nil, "The resource name is missing." end
    if foreign(resource) then return nil, "The resource must be the calling resource." end
    local label = clean(def.label, 48)
    if not label then return nil, "The label is missing." end
    if not KINDS[def.kind] then return nil, "The kind must be pvp, race, chase or event." end
    if def.description ~= nil and type(def.description) ~= "string" then return nil, "The description must be a string." end
    local minPlayers = int(def.minPlayers == nil and 1 or def.minPlayers, 1, 128)
    local maxPlayers = int(def.maxPlayers == nil and math.max(minPlayers or 1, 16) or def.maxPlayers, 1, 128)
    if not minPlayers or not maxPlayers or maxPlayers < minPlayers then return nil, "minPlayers and maxPlayers are invalid." end
    if def.caps ~= nil and type(def.caps) ~= "table" then return nil, "caps must be a table." end
    local caps = {}
    for _, key in ipairs(CAPS) do caps[key] = type(def.caps) == "table" and def.caps[key] == true end
    -- optional (an addition to the contract): the choices offered by the panel
    -- when joining, handed back as options[modeKey] (default options.mode), e.g.
    -- modes = { { id = "car", label = "By car" } } or modeKey = "course" with one
    -- mode per course. A provider that declares none may get them from
    -- server/config/activities.lua `joinChoices` (op77_chase's car / foot).
    local preset = type(def.modes) ~= "table" and (C.joinChoices or {})[id] or nil
    local source = type(def.modes) == "table" and def.modes or type(preset) == "table" and preset.modes or nil
    local modes
    if type(source) == "table" then
        modes = {}
        for _, m in ipairs(source) do
            if #modes >= 8 then break end
            if type(m) == "table" and type(m.id) == "string" and #m.id <= 48 and m.id:match("^[%w_%-%.]+$") then
                -- botFill = false: this mode cannot be filled with bots (the activity's botFill aside)
                modes[#modes + 1] = { id = m.id, label = clean(m.label, 32) or m.id, botFill = m.botFill == false and false or nil }
            end
        end
        if #modes == 0 then modes = nil end
    end
    local modeKey = def.modeKey
    if modeKey == nil and type(preset) == "table" then modeKey = preset.key end
    if modeKey == nil then modeKey = "mode"
    elseif type(modeKey) ~= "string" or #modeKey > 24 or not modeKey:match("^%a[%w_]*$") or modeKey == "from" or modeKey == "squad" then
        return nil, "modeKey must be a short identifier (not from or squad)."
    end
    -- optional (an addition to the contract): PvE, and the difficulties it plays.
    -- Without `pve`, the config's `pve.activities` list may mark it.
    local listed = type(PVE.activities) == "table" and PVE.activities[id] or nil
    local pve = def.pve
    if pve == nil then pve = listed ~= nil and listed ~= false end
    if type(pve) ~= "boolean" then return nil, "pve must be true or false." end
    if def.difficulties ~= nil and type(def.difficulties) ~= "table" then return nil, "difficulties must be a list of ids." end
    local difficulties
    if pve and type(def.difficulties) == "table" then
        local seen = {}
        for _, d in ipairs(def.difficulties) do if type(d) == "string" and DIFFS[d] then seen[d] = true end end
        difficulties = {}
        for _, d in ipairs(PVE.difficulties or {}) do if seen[d.id] then difficulties[#difficulties + 1] = d.id end end
        if #difficulties == 0 then difficulties = nil end
    end
    if difficulties and (modeKey == "difficulty" or modeKey == "scaling") then
        return nil, "modeKey cannot be difficulty or scaling on a PvE activity with difficulties."
    end
    local weight = pve and (type(listed) == "table" and num(listed.weight, 0, 5) or 1) or nil
    -- optional (the lobby): the provider fills with bots when asked (options.fill /
    -- options.match.bots): allied bots for PvE, opponents (and team mates) for PvP.
    -- Without it the panel offers no bots for the activity, whatever the config says.
    if def.botFill ~= nil and type(def.botFill) ~= "boolean" then return nil, "botFill must be true or false." end
    return { id = id, resource = resource, label = label, kind = def.kind, description = clean(def.description, 280) or "",
        minPlayers = minPlayers, maxPlayers = maxPlayers, caps = caps, modes = modes, modeKey = modeKey,
        pve = pve, difficulties = difficulties, weight = weight, botFill = def.botFill == true }
end

local refreshTop -- defined with the stats below

function A.register(def)
    local a, why = validate(def)
    if not a then return false, why end
    local old = registry[a.id]
    if old and old.resource ~= a.resource and running(old.resource) then
        return false, "The id " .. a.id .. " belongs to " .. old.resource .. "."
    end
    generation = generation + 1
    a.generation = generation
    a.status = (old and old.resource == a.resource and old.status)
        or { phase = "idle", players = 0, queued = 0, joinable = true, detail = "" }
    if not old then order[#order + 1] = a.id end
    registry[a.id] = a
    if not tops[a.id] then CreateThread(function() refreshTop(a.id) end) end
    dirty()
    LightRP.log("activities: %s registered by %s (%s, caps %s)", a.id, a.resource, a.kind,
        table.concat((function() local t = {}; for _, k in ipairs(CAPS) do if a.caps[k] then t[#t + 1] = k end end; return t end)(), ",") )
    return true
end

-- ---------------------------------------------------------------------------
-- Ownership

local function here(id)
    local read = type(Open77.players.get) == "function" and Open77.players.get(id) or nil
    local p = type(read) == "table" and read.position or Open77.players.position(id)
    if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" or type(p.z) ~= "number" then return nil end
    local heading = type(read) == "table" and tonumber(read.heading or read.yaw) or 0
    return { x = p.x, y = p.y, z = p.z, heading = heading, bucket = bucketOf(id) }
end

-- The difficulty a PvE entry plays: the provider's (opts.difficulty), else the
-- one queued from the panel (the leader's, for a crew member), else the first
-- offered; refused above the tier, except for a crew member (difficultyFor), who
-- comes back `carried`.
local function entryDifficulty(id, a, opts)
    if not a.pve then return nil end
    local q = pending[id]
    local wanted = a.difficulties and type(opts) == "table" and type(opts.difficulty) == "string" and opts.difficulty or nil
    if wanted == nil and q and q.activity == a.id then wanted = q.difficulty end
    if wanted == nil then wanted = offered(a)[1] end
    local allowed, why, carried = difficultyFor(id, a, wanted)
    if not allowed then return nil, why end
    return wanted, nil, carried
end

function A.enter(playerId, activityId, opts)
    local id = pid(playerId)
    if not id then return false, "Invalid player." end
    local a = type(activityId) == "string" and registry[activityId] or nil
    if not a then return false, "That activity is not available." end
    if foreign(a.resource) then return false, "That activity belongs to another resource." end
    local e = owned[id]
    if e and e.activity == activityId then return true end
    local ok, why = check(id, activityId)
    if not ok then return false, why end
    local difficulty, refused, carried = entryDifficulty(id, a, opts)
    if refused then return false, refused end
    local point = here(id)
    if not point then return false, "Your position is not available yet." end
    local who, c = identity(id)
    tokenSeq = tokenSeq + 1
    -- ranked unless the panel's join said otherwise (a friendly, a bot match) or staff
    -- bot mode is on; a provider's own entry (/duel, its commands) is ranked
    local q = pending[id]
    local asked = q and q.activity == a.id and q or nil
    e = { token = tokenSeq, activity = a.id, resource = a.resource, generation = a.generation, caps = a.caps,
        returnPoint = point, identity = who, character = c, enteredAt = now(),
        pve = a.pve, difficulty = difficulty, difficulties = a.pve and offered(a) or nil, weight = a.weight, carried = carried,
        ranked = A.botsEnabled ~= true and not (asked and asked.ranked == false),
        match = asked and asked.match or nil, friendly = asked and asked.friendly or nil, fill = asked and asked.fill or nil }
    owned[id] = e
    -- queued elsewhere (a provider's own command entered them): that queue lets go
    pending[id], leaving[id] = nil, nil
    if q and q.activity ~= a.id then emit(EV.leaveRequest, id, q.activity) end
    -- a crew member below the leader's difficulty, not told yet by the crew queue
    if carried and not (q and q.activity == a.id and q.told == difficulty) then
        LightRP.notice(id, { kind = "info", title = "STREET CRED", durationMs = 9000, body = carriedLine(id, a, difficulty) })
    end
    -- never saved inside: the character keeps the return point from now on
    c.lastKnown = { x = point.x, y = point.y, z = point.z }
    if LightRP.missions and type(LightRP.missions.untag) == "function" then
        pcall(LightRP.missions.untag, id, "You joined " .. a.label .. ".")
    end
    if LightRP.inventory and type(LightRP.inventory.close) == "function" then pcall(LightRP.inventory.close, id) end
    -- the armament stands aside (armament.standsAside): its client stops projecting
    if not a.caps.rpWeapons and LightRP.armament and type(LightRP.armament.push) == "function" then
        pcall(LightRP.armament.push, id)
    end
    touch(id)
    LightRP.log("activities: %s (%d) entered %s%s%s, return point %.1f %.1f %.1f bucket %d",
        who.name, id, a.id, difficulty and (" (" .. difficulty .. ")") or "", e.ranked and "" or (e.friendly and " friendly" or " unranked"),
        point.x, point.y, point.z, point.bucket)
    -- modules that depend on the kind of play (cyberware in PvP) hear about it
    LightRP.eachModule("onActivityChanged", id, a.id, { pve = a.pve, kind = a.kind, difficulty = difficulty, ranked = e.ranked })
    return true
end

local function heal(id)
    if type(Open77.players.heal) ~= "function" then return end
    for _ = 1, 40 do
        local life = Open77.players.getLifeState(id)
        if not life then return end
        if life.phase == "alive" then
            local ok, applied, why = pcall(Open77.players.heal, id, 10000)
            if not ok or applied == false then LightRP.log("activities: %d not healed (%s)", id, tostring(ok and why or applied)) end
            return
        end
        Wait(250)
    end
end

-- RP weapons back once the activity's own are gone: the armament pushes at once
-- (it stops standing aside) and projects again a moment later, like a mission's end.
local function restoreArms(id, e)
    if e.caps and e.caps.rpWeapons then return end
    if LightRP.armament and type(LightRP.armament.push) == "function" then pcall(LightRP.armament.push, id) end
    -- 2026-11-03: the synchronization the push starts could still be running at 3 s
    -- ("Weapon synchronization is already in progress."), and the one try gave up.
    -- Wait for it and ask again, a few times, before calling it a failure.
    local tries = 0
    local function synchronize()
        if A.owns(id) or not LightRP.armament or type(LightRP.armament.synchronize) ~= "function" then return end
        tries = tries + 1
        local ok, done, why = pcall(LightRP.armament.synchronize, id)
        if ok and done ~= false then return end
        local reason = tostring(ok and why or done)
        if tries < 4 and reason:lower():find("in progress", 1, true) then SetTimeout(2000, synchronize); return end
        LightRP.log("activities: weapons of %d not restored after %d tries (%s)", id, tries, reason)
    end
    SetTimeout(3000, synchronize)
end

-- The way back: the captured point, bucket included. A dead player respawns
-- there; a living one is moved with a fade. Waits run on this resource's thread.
local function goBack(id, e)
    local point = e.returnPoint
    returning[id] = e
    CreateThread(function()
        local target = { x = point.x, y = point.y, z = point.z }
        local cover = LightRP.zoneLoading and LightRP.zoneLoading.cover(id, { title = point.bucket == 0 and "Night City" or "Returning",
            subtitle = "Back from " .. labelOf(e.activity), zone = point.bucket == 0 and "Shared city" or nil, target = target })
        local placed, why
        for attempt = 1, 60 do
            if returning[id] ~= e or owned[id] then why = "superseded"; break end
            local life = Open77.players.getLifeState(id)
            if not life then why = "player_gone"; break end
            -- dead, or still between two states after 15 s: respawned at the point, never left dead there
            if life.phase == "dead" or (attempt == 60 and life.phase ~= "alive") then
                placed, why = Open77.players.respawn(id, { position = target, heading = point.heading or 0, bucket = point.bucket,
                    health = LightRpConfig.spawn.health, graceMs = LightRpConfig.spawn.graceMs })
                break
            elseif life.phase == "alive" then
                local promise
                promise, why = Open77.players.teleport(id, target, { heading = point.heading or 0, bucket = point.bucket,
                    fade = true, dismount = true, timeoutMs = 30000 })
                if promise then placed, why = promise:await() end
                break
            end
            Wait(250)
        end
        if LightRP.zoneLoading and cover then LightRP.zoneLoading.release(id, cover) end
        if returning[id] ~= e then return end
        if not placed or placed == false then
            if type(SetPlayerRoutingBucket) == "function" and why ~= "player_gone" then pcall(SetPlayerRoutingBucket, id, point.bucket) end
            LightRP.log("activities: %d could not be brought back from %s (%s)", id, e.activity, tostring(why))
        end
        heal(id)
        if returning[id] == e then returning[id] = nil end
        restoreArms(id, e)
        touch(id)
    end)
end

-- Ownership ends. `back`: return the player; `reason`: tell the provider (dropped).
local function release(id, e, back, reason)
    if owned[id] ~= e then return end
    owned[id], leaving[id] = nil, nil
    e.leftAt = now()
    recent[id] = recent[id] or {}
    recent[id][e.activity] = e
    if back then goBack(id, e) elseif reason ~= "disconnect" then restoreArms(id, e) end
    if reason ~= "disconnect" then touch(id) end
    dirty()
    LightRP.log("activities: %d left %s (%s)", id, e.activity, reason or (back and "returned" or "kept in place"))
    if reason then emit(EV.dropped, id, e.activity, reason) end
    LightRP.eachModule("onActivityChanged", id, nil, { left = e.activity, reason = reason })
end
A.release = release

function A.leave(playerId, activityId, opts)
    local id = pid(playerId)
    if not id then return false, "Invalid player." end
    local e = owned[id]
    if not e or e.activity ~= activityId then
        local q = pending[id]
        if q and q.activity == activityId then
            local a = registry[activityId]
            if a and foreign(a.resource) then return false, "That activity belongs to another resource." end
            pending[id] = nil
            touch(id)
            return true
        end
        return false, "That player is not in this activity."
    end
    if foreign(e.resource) then return false, "That activity belongs to another resource." end
    release(id, e, not (type(opts) == "table" and opts.returnPlayer == false), nil)
    return true
end

-- A provider stops: its activities are forgotten and its players come back.
-- On a reload or restart the incoming VM may already have registered again (it
-- starts before the outgoing VM's stop reaches us): only what the outgoing VM
-- registered goes.
local function forget(resource, since, reason)
    for id, e in pairs(owned) do
        if e.resource == resource and e.generation <= since then release(id, e, true, "provider_stopped") end
    end
    for id, q in pairs(pending) do
        local a = registry[q.activity]
        if a and a.resource == resource and a.generation <= since then pending[id] = nil end
    end
    local kept = {}
    for _, aid in ipairs(order) do
        local a = registry[aid]
        if a and a.resource == resource and a.generation <= since then
            registry[aid], tops[aid] = nil, nil
            LightRP.log("activities: %s forgotten (%s %s)", aid, resource, tostring(reason))
        elseif a then kept[#kept + 1] = aid end
    end
    order = kept
    dirty()
end

AddEventHandler("onResourceStarting", function(name)
    if type(name) == "string" then starting[name] = generation end
end)
AddEventHandler("onResourceStop", function(name, reason)
    if type(name) ~= "string" then return end
    if name == SELF then
        -- Light RP goes: the providers clean their side; the return points go with this VM.
        for id, e in pairs(owned) do
            local p = e.returnPoint
            if type(SetPlayerRoutingBucket) == "function" then pcall(SetPlayerRoutingBucket, id, p.bucket) end
            pcall(Open77.players.teleport, id, { x = p.x, y = p.y, z = p.z }, { heading = p.heading or 0, bucket = p.bucket, dismount = true })
            emit(EV.dropped, id, e.activity, "core_stopped")
        end
        return
    end
    local back = running(name) and starting[name] ~= nil
    forget(name, back and starting[name] or math.huge, reason)
end)

-- ---------------------------------------------------------------------------
-- Requests from the player (panel, Neural-Link app, commands)

local function copy(list) local t = {}; for i, v in ipairs(list or {}) do t[i] = v end; return t end
-- What the page adds to a join (options.mode...): passed through, flat and short.
local function extraOptions(value)
    local out = {}
    if type(value) ~= "table" then return out end
    local n = 0
    for key, v in pairs(value) do
        if type(key) == "string" and #key <= 24 and key:match("^[%a][%w_]*$") and key ~= "from" and key ~= "squad" and n < 8 then
            if type(v) == "string" then out[key] = clean(v, 48); n = n + 1
            elseif type(v) == "boolean" or (type(v) == "number" and v == v and math.abs(v) < 1e9) then out[key] = v; n = n + 1 end
        end
    end
    return out
end

local function squadOf(party)
    return party and { id = party.id, leader = party.leader, members = copy(party.members) } or nil
end
local function lowerFirst(text) return (tostring(text):gsub("^%u", string.lower)) end
local function displayName(id) return LightRP.characters.displayName(id) end
local function letter(i) return string.char(64 + i) end
local function flatten(teams) local out = {}; for _, team in ipairs(teams) do for _, p in ipairs(team) do out[#out + 1] = p end end; return out end
local function removeFrom(list, p) for i, v in ipairs(list) do if v == p then table.remove(list, i) return i end end end

-- ---------------------------------------------------------------------------
-- Lobby: bots chosen in the panel, the ranked search's fill offer, the matches the
-- core forms (a bot match, a friendly) and the friendly set-up. Config: `lobby`.

local function lobbyCfg() return type(C.lobby) == "table" and C.lobby or {} end
local function lobbyOf(a)
    local list = lobbyCfg().activities
    local l = a and type(list) == "table" and list[a.id] or nil
    return type(l) == "table" and l or {}
end
A.lobbyOf = function(activityId) return lobbyOf(registry[activityId]) end
-- Bots need both: the config's lobby entry and the provider's own botFill declaration.
local function offersAllies(a) return a ~= nil and a.pve == true and a.botFill == true and lobbyOf(a).allies == true end
local function offersBots(a) return a ~= nil and not a.pve and a.botFill == true and lobbyOf(a).bots == true end
-- A mode may opt out (modes[i].botFill = false).
local function modeTakesBots(a, mode)
    if mode == nil then return true end
    for _, m in ipairs(a.modes or {}) do if m.id == mode then return m.botFill ~= false end end
    return true
end
local function offersFriendly(a) return a ~= nil and not a.pve and lobbyOf(a).friendly == true and a.maxPlayers >= 2 end
local function fillAfterMs() return math.max(0, math.floor(tonumber(lobbyCfg().fillAfterMs) or 120000)) end
-- "teams": sides of a fixed size (one size per mode allowed); "split": two halves of
-- any size (turf war); "ffa": everyone for themselves (races, Combat Zone, Most Wanted).
local function shapeOf(l)
    local n = tonumber(l.teams)
    if n and n >= 2 then return l.teamSize ~= nil and "teams" or "split", math.floor(n) end
    return "ffa", 1
end
local function teamSizeOf(l, mode)
    if type(l.teamSize) == "table" then return mode ~= nil and tonumber(l.teamSize[mode]) or nil end
    return tonumber(l.teamSize)
end
-- A per-mode shape's modes, smallest side first: { { mode, size } }.
local function sizedModes(a, l)
    local out = {}
    if type(l.teamSize) ~= "table" then return out end
    local seen = {}
    for _, m in ipairs(a.modes or {}) do
        local size = tonumber(l.teamSize[m.id])
        if size then out[#out + 1] = { mode = m.id, size = size }; seen[m.id] = true end
    end
    for mode, size in pairs(l.teamSize) do
        if not seen[mode] and tonumber(size) then out[#out + 1] = { mode = mode, size = tonumber(size) } end
    end
    table.sort(out, function(x, y) if x.size ~= y.size then return x.size < y.size end return tostring(x.mode) < tostring(y.mode) end)
    return out
end
-- One side of a fixed shape for a group of `count`: the chosen mode, else the
-- smallest that holds them (else the largest). mode, size (nil: not a fixed shape)
local function sideSize(a, l, mode, count)
    local size = teamSizeOf(l, mode)
    if size then return mode, size end
    if type(l.teamSize) ~= "table" then return mode, nil end
    local all = sizedModes(a, l)
    for _, m in ipairs(all) do if count <= m.size then return m.mode, m.size end end
    local last = all[#all]
    return last and last.mode or mode, last and last.size or nil
end
local function bodiesOf(a, l)
    local target = math.floor(tonumber(l.fillTo) or a.maxPlayers)
    return math.max(a.minPlayers, math.min(a.maxPlayers, target))
end
local function tooBig(a, mode, count, size)
    return string.format("Your crew is %d: %s%s takes %d per side. Start a friendly match to play it inside the crew.",
        count, a.label, mode and (" " .. mode) or "", size)
end
-- A group alone against bots: on side 1 of a team shape (bots complete it and make
-- the other sides), or with AI opponents up to `fillTo` bodies. teams, bots, enemies, mode
local function botPlan(a, l, mode, players)
    local shape, n = shapeOf(l)
    if shape == "ffa" then return nil, nil, math.max(0, bodiesOf(a, l) - #players), mode end
    local size
    if shape == "teams" then mode, size = sideSize(a, l, mode, #players)
    else size = math.max(math.ceil(bodiesOf(a, l) / n), #players) end
    size = size or #players
    local teams, bots = { copy(players) }, { math.max(0, size - #players) }
    for i = 2, n do teams[i], bots[i] = {}, size end
    return teams, bots, nil, mode
end

-- A match the core forms: every player gets a join with the same options.match, in
-- this tick, and is pending for it. Ranked only from the ranked queue (humans only);
-- a friendly or a bot match never is. true, match | false
local function startMatch(a, players, plan)
    matchSeq = matchSeq + 1
    local ranked = plan.ranked == true and plan.friendly ~= true and A.botsEnabled ~= true
    local m = { id = "match:" .. matchSeq, activity = a.id, friendly = plan.friendly == true, ranked = ranked,
        players = copy(players), teams = plan.teams, bots = plan.bots, enemies = plan.enemies, format = plan.mode,
        lead = plan.lead, at = now() }
    matches[m.id] = m
    local sides, total = {}, 0
    for i, team in ipairs(m.teams or {}) do for _, p in ipairs(team) do sides[p] = i end end
    for _, n in ipairs(m.bots or {}) do total = total + n end
    local sent = 0
    for _, p in ipairs(players) do
        local o = {}
        for k, v in pairs(plan.optionsOf and plan.optionsOf[p] or plan.options or {}) do o[k] = v end
        if plan.mode ~= nil and a.modes then o[a.modeKey] = plan.mode end
        local party = crewOf(p)
        o.from, o.squad, o.ranked = plan.from or "panel", squadOf(party), ranked
        local teams
        if m.teams then teams = {}; for i, team in ipairs(m.teams) do teams[i] = copy(team) end end
        local side = sides[p]
        o.match = { id = m.id, ranked = ranked, friendly = m.friendly, format = m.format, players = copy(players), teams = teams,
            side = side, bots = m.bots and copy(m.bots) or nil }
        if m.teams and total > 0 then
            local allies = side and m.bots[side] or 0
            o.fill = { allies = allies, enemies = total - allies }
        elseif (m.enemies or 0) > 0 then
            o.fill = { allies = 0, enemies = m.enemies }
        end
        pending[p] = { activity = a.id, at = now(), ranked = ranked, match = m.id, friendly = m.friendly or nil, fill = o.fill,
            mode = plan.mode, lead = plan.leads and plan.leads[p] or plan.lead, crew = party and party.id or nil }
        if emit(EV.join, p, a.id, o) then sent = sent + 1 else pending[p] = nil end
        touch(p)
    end
    LightRP.log("activities: %s %s for %d player(s)%s (%s)", ranked and "ranked match" or (m.friendly and "friendly" or "bot match"),
        a.id, #players, m.format and (" " .. m.format) or "", m.id)
    if sent == 0 then matches[m.id] = nil; return false end
    return true, m
end
A.startMatch = startMatch

-- ---------------------------------------------------------------------------
-- The ranked queue (`queue = true`): the core holds the search (a ticket: a solo
-- player, or a crew whole) and forms the match itself -- by team size, and by the
-- cyberware bracket widening with the oldest searcher's wait -- then dispatches it
-- like any core match, ranked. The provider hears nothing until then.

local tickets = {}    -- ticketId -> { id, activity, mode, lead, members, at, options, from }
local ticketSeq = 0
local ffaReady = {}   -- activityId -> ms since enough searchers fit (free-for-all gather)
A.tickets = tickets

local function mmCfg() return type(lobbyCfg().matchmaking) == "table" and lobbyCfg().matchmaking or {} end

-- A held search ends for one player (`p` left, went elsewhere, could not play): its
-- leader ending it ends it for the whole crew.
local function dropFromTicket(p, why)
    local q = pending[p]
    local tk = q and q.held and tickets[q.held]
    pending[p] = nil
    if not tk then return end
    removeFrom(tk.members, p)
    touch(p)
    if p == tk.lead or #tk.members == 0 then
        tickets[tk.id] = nil
        for _, other in ipairs(tk.members) do
            if pending[other] and pending[other].held == tk.id then
                pending[other] = nil
                touch(other)
                LightRP.notice(other, { kind = "info", title = "MATCHMAKING", durationMs = 6000,
                    body = why or ("Your crew leader left the search for " .. labelOf(tk.activity) .. ".") })
            end
        end
    elseif tk.lead then
        touch(tk.lead)
        LightRP.notice(tk.lead, { kind = "info", title = "MATCHMAKING", durationMs = 6000,
            body = displayName(p) .. " left the search. Your crew keeps searching." })
    end
end
A.dropFromTicket = dropFromTicket

-- Whatever these players were queued for lets go (a new match replaces it).
local function withdraw(players)
    for _, p in ipairs(players) do
        local q = pending[p]
        if q and q.held then dropFromTicket(p)
        elseif q then pending[p] = nil; emit(EV.leaveRequest, p, q.activity) end
    end
end

-- The bracket of a player: the highest cyberware rank their reputation tier opens
-- (server/config/cyberware.lua gating.byRank), grouped by `matchmaking.brackets`.
local function bracketOf(p)
    local tier = tierOf(p)
    local cw = type(LightRpCyberwareConfig) == "table" and LightRpCyberwareConfig.gating or nil
    local rank = tier
    if type(cw) == "table" and cw.enabled ~= false and type(cw.byRank) == "table" then
        rank = 0
        for r, need in pairs(cw.byRank) do
            if tonumber(r) and tonumber(need) and tonumber(need) <= tier and tonumber(r) > rank then rank = math.floor(tonumber(r)) end
        end
        if rank == 0 then rank = 1 end
    end
    local groups = mmCfg().brackets
    return math.floor(tonumber(type(groups) == "table" and groups[rank] or nil) or rank)
end
A.bracketOf = bracketOf
local function ticketBracket(tk)
    local best = 1
    for _, p in ipairs(tk.members) do best = math.max(best, bracketOf(p)) end
    return best
end
-- How far apart the brackets of a match anchored by a search this old may be
-- (math.huge: everyone), and when the next widening comes (nil: none left).
local function spreadFor(a, waitedMs)
    if lobbyOf(a).brackets == false then return math.huge, nil end
    local spread, nextAt = 1, nil
    local steps = mmCfg().widen
    if type(steps) ~= "table" or #steps == 0 then return math.huge, nil end
    for _, step in ipairs(steps) do
        local after = tonumber(step.afterMs) or 0
        if waitedMs >= after then
            spread = step.spread == "all" and math.huge or (tonumber(step.spread) or spread)
        elseif nextAt == nil or after < nextAt then
            nextAt = after
        end
    end
    return spread, nextAt and (nextAt - waitedMs) or nil
end
A.spreadFor = function(activityId, waitedMs) return spreadFor(registry[activityId], waitedMs) end

-- Tickets onto `n` sides of exactly `size`, the anchor (cands[1]) always in, crews
-- whole, the oldest first. sides { { tickets } } | nil
local function packTeams(cands, n, size)
    local sides, counts, total, need, steps = {}, {}, 0, n * size, 0
    for i = 1, n do sides[i], counts[i] = {}, 0 end
    local function dfs(k)
        steps = steps + 1
        if total == need then return true end
        if k > #cands or steps > 4000 then return false end
        local tk, size_k = cands[k], #cands[k].members
        for i = 1, n do
            if counts[i] + size_k <= size then
                local wasEmpty = counts[i] == 0
                counts[i], total = counts[i] + size_k, total + size_k
                sides[i][#sides[i] + 1] = tk
                if dfs(k + 1) then return true end
                table.remove(sides[i])
                counts[i], total = counts[i] - size_k, total - size_k
                if wasEmpty then break end -- empty sides are alike: one try is enough
            end
        end
        if k == 1 then return false end
        return dfs(k + 1)
    end
    if dfs(1) then return sides end
    return nil
end

-- The modes a match anchored by `anchor` may play: its own, else every sized mode
-- (per-mode team sizes), else "any" (false) and each mode another searcher chose.
local function modeChoices(a, l, anchor, cands)
    if anchor.mode ~= nil then return { anchor.mode } end
    local out, seen = {}, {}
    if type(l.teamSize) == "table" then
        for _, m in ipairs(sizedModes(a, l)) do out[#out + 1] = m.mode end
        return out
    end
    out[1] = false
    for _, tk in ipairs(cands) do
        if tk.mode ~= nil and not seen[tk.mode] then seen[tk.mode] = true; out[#out + 1] = tk.mode end
    end
    return out
end

-- One match for this anchor among these candidates (anchor first). plan | nil
local function planFor(a, l, anchor, cands, t)
    local shape, n = shapeOf(l)
    for _, mode in ipairs(modeChoices(a, l, anchor, cands)) do
        local pool = {}
        for _, tk in ipairs(cands) do
            if tk.mode == nil or (mode ~= false and tk.mode == mode) then pool[#pool + 1] = tk end
        end
        if pool[1] == anchor then
            local resolved = mode ~= false and mode or nil
            if shape == "teams" then
                local size = teamSizeOf(l, resolved)
                if size then
                    local fit = {}
                    for _, tk in ipairs(pool) do if #tk.members <= size then fit[#fit + 1] = tk end end
                    local sides = fit[1] == anchor and packTeams(fit, n, size) or nil
                    if sides then return { mode = resolved, sides = sides } end
                end
            else
                -- free-for-all / split: the oldest first, crews whole, up to the maximum
                local chosen, count = {}, 0
                for _, tk in ipairs(pool) do
                    if count + #tk.members <= a.maxPlayers then chosen[#chosen + 1] = tk; count = count + #tk.members end
                end
                if chosen[1] == anchor and count >= math.max(2, a.minPlayers) then
                    return { mode = resolved, tickets = chosen, count = count }
                end
            end
        end
    end
    return nil
end

-- Every member still free? Those who are not drop out of the search (the leader:
-- the whole ticket), told why. true when all can play.
local function confirm(list)
    local fine = true
    for _, tk in ipairs(list) do
        for i = #tk.members, 1, -1 do
            local p = tk.members[i]
            local ok, why = check(p, tk.activity)
            if not ok then
                fine = false
                LightRP.notice(p, { kind = "warning", title = "MATCHMAKING", durationMs = 7000,
                    body = "A match was found for " .. labelOf(tk.activity) .. ", but you left the search: " .. lowerFirst(why) })
                dropFromTicket(p, displayName(p) .. " could not play (" .. lowerFirst(why) .. "): the search ended.")
            end
        end
    end
    return fine
end

local function dispatch(a, plan)
    local list = plan.tickets or flatten(plan.sides)
    if not confirm(list) then return true end -- tickets changed: plan again
    local players, optionsOf, leads, teams = {}, {}, {}, nil
    local function take(tk)
        tickets[tk.id] = nil
        for _, p in ipairs(tk.members) do
            players[#players + 1] = p
            optionsOf[p], leads[p] = tk.options, tk.lead
            pending[p] = nil
        end
    end
    if plan.sides then
        teams = {}
        for i, side in ipairs(plan.sides) do
            teams[i] = {}
            for _, tk in ipairs(side) do
                take(tk)
                for _, p in ipairs(tk.members) do teams[i][#teams[i] + 1] = p end
            end
        end
    else
        for _, tk in ipairs(list) do take(tk) end
    end
    ffaReady[a.id] = nil
    startMatch(a, players, { ranked = true, teams = teams, mode = plan.mode, optionsOf = optionsOf, leads = leads, from = "queue" })
    for _, p in ipairs(players) do
        LightRP.notice(p, { kind = "success", title = "MATCH FOUND", durationMs = 6000,
            body = "Ranked " .. a.label .. (plan.mode and (" " .. plan.mode) or "") .. ": joining now." })
    end
    return true
end

-- Forms what can be formed for one activity. true when something changed.
local function formOne(a, list, t)
    local l = lobbyOf(a)
    local shape = shapeOf(l)
    local lowest, highest = math.huge, -math.huge
    local brackets = {}
    for _, tk in ipairs(list) do
        brackets[tk] = ticketBracket(tk)
        lowest, highest = math.min(lowest, brackets[tk]), math.max(highest, brackets[tk])
    end
    local fits = false
    for _, anchor in ipairs(list) do
        local spread = spreadFor(a, t - anchor.at)
        local b = brackets[anchor]
        -- windows [lo, lo + spread] holding the anchor's bracket: one bracket or two
        -- adjacent ones at first, every bracket at the end
        local from = spread == math.huge and lowest or math.max(lowest, b - spread)
        for lo = from, b do
            local hi = spread == math.huge and highest or lo + spread
            local cands = { anchor }
            for _, tk in ipairs(list) do
                if tk ~= anchor and brackets[tk] >= lo and brackets[tk] <= hi then cands[#cands + 1] = tk end
            end
            local plan = planFor(a, l, anchor, cands, t)
            if plan then
                if plan.tickets and plan.count < a.maxPlayers then
                    -- a free-for-all waits a moment for more, unless full
                    fits = true
                    ffaReady[a.id] = ffaReady[a.id] or t
                    if t - ffaReady[a.id] >= (tonumber(mmCfg().gatherMs) or 15000) then return dispatch(a, plan) end
                else
                    return dispatch(a, plan)
                end
            end
            if spread == math.huge then break end
        end
    end
    if shape ~= "teams" and not fits then ffaReady[a.id] = nil end
    return false
end

-- Runs every second (and right after a new search): every queue activity's tickets,
-- oldest first.
function A.matchmake()
    local t = now()
    local by = {}
    for _, tk in pairs(tickets) do
        local a = registry[tk.activity]
        if a then
            by[tk.activity] = by[tk.activity] or {}
            local list = by[tk.activity]
            list[#list + 1] = tk
        end
    end
    for aid, list in pairs(by) do
        local a = registry[aid]
        local guard = 0
        repeat
            table.sort(list, function(x, y) if x.at ~= y.at then return x.at < y.at end return x.id < y.id end)
            local changed = formOne(a, list, t)
            if changed then
                local kept = {}
                for _, tk in ipairs(list) do if tickets[tk.id] == tk and #tk.members > 0 then kept[#kept + 1] = tk end end
                list = kept
            end
            guard = guard + 1
        until not changed or #list == 0 or guard > 32
    end
end

-- A new ranked search: the player and their eligible crew members, held here.
local function queueTicket(id, a, options, from, crew, chosen)
    local members, out = { id }, {}
    for _, member in ipairs(crew and crew.members or {}) do
        if member ~= id then
            local ok, why = check(member, a.id)
            if ok then members[#members + 1] = member
            else
                out[#out + 1] = displayName(member) .. " stays out: " .. lowerFirst(why)
                LightRP.notice(member, { kind = "warning", title = "CREW", durationMs = 7000,
                    body = displayName(id) .. " queued the crew for ranked " .. a.label .. ". You stay out: " .. lowerFirst(why) })
            end
        end
    end
    withdraw(members)
    friendlies[id] = nil
    ticketSeq = ticketSeq + 1
    local tk = { id = ticketSeq, activity = a.id, mode = chosen, lead = id, members = members, at = now(),
        options = options, from = clean(from, 24) or "panel" }
    tickets[tk.id] = tk
    for _, p in ipairs(members) do
        pending[p] = { activity = a.id, at = tk.at, ranked = true, held = tk.id, mode = chosen, lead = id,
            crew = crew and crew.id or nil, options = p == id and options or nil }
        touch(p)
        if p ~= id then
            LightRP.notice(p, { kind = "contract", title = "CREW", durationMs = 6000,
                body = displayName(id) .. " queued the crew for ranked " .. a.label .. ". /leave drops you out." })
        end
    end
    local text = "Searching for a ranked " .. a.label .. (chosen and (" " .. chosen) or "") .. " match"
    if #members > 1 then text = text .. string.format(" with %d crew member%s", #members - 1, #members == 2 and "" or "s") end
    text = text .. "."
    if #out > 0 then text = text .. " " .. table.concat(out, ". ") .. "." end
    A.matchmake()
    return true, text
end

-- What a held search shows: searchers that fit with it now, the players a match
-- needs, near your rank or all ranks, and the next widening.
local function searchView(id, q, a)
    local tk = tickets[q.held]
    if not tk then return {} end
    local l = lobbyOf(a)
    local shape, n = shapeOf(l)
    local t = now()
    local spread, widenIn = spreadFor(a, t - tk.at)
    local b = ticketBracket(tk)
    local found = 0
    for _, other in pairs(tickets) do
        if other.activity == tk.activity and (other.mode == nil or tk.mode == nil or other.mode == tk.mode)
            and (spread == math.huge or math.abs(ticketBracket(other) - b) <= spread) then
            found = found + #other.members
        end
    end
    local needed = math.max(2, a.minPlayers)
    if shape == "teams" then
        local _, size = sideSize(a, l, tk.mode, #tk.members)
        if size then needed = size * n end
    end
    return { found = math.min(found, math.max(needed, found)), needed = needed,
        scope = spread == math.huge and "all" or "near", widenInMs = widenIn, bracket = lobbyOf(a).brackets ~= false and b or nil }
end

-- "Play with bots" chosen in the panel (PvP): the player and their eligible crew
-- members, alone against bots, unranked.
local function botMatch(id, a, l, options, from, crew, chosen)
    local players, out = { id }, {}
    for _, member in ipairs(crew and crew.members or {}) do
        if member ~= id then
            local ok, why = check(member, a.id)
            if ok then players[#players + 1] = member
            else
                out[#out + 1] = displayName(member) .. " stays out: " .. lowerFirst(why)
                LightRP.notice(member, { kind = "warning", title = "CREW", durationMs = 7000,
                    body = displayName(id) .. " started " .. a.label .. " with bots. You stay out: " .. lowerFirst(why) })
            end
        end
    end
    withdraw(players)
    friendlies[id] = nil
    local teams, bots, enemies, mode = botPlan(a, l, chosen, players)
    if not startMatch(a, players, { teams = teams, bots = bots, enemies = enemies, mode = mode, options = options, from = from, lead = id }) then
        return false, a.label .. " did not answer. Try again in a moment."
    end
    for i = 2, #players do
        LightRP.notice(players[i], { kind = "contract", title = "CREW", durationMs = 6000,
            body = displayName(id) .. " started " .. a.label .. " with bots: unranked, nothing is recorded." })
    end
    local text = "Starting " .. a.label .. " with bots · unranked."
    if #players > 1 then text = text .. string.format(" %d crew member%s with you.", #players - 1, #players == 2 and "" or "s") end
    if #out > 0 then text = text .. " " .. table.concat(out, ". ") .. "." end
    return true, text
end

-- The fill offer of a ranked search, accepted by its leader: the group leaves the
-- provider's queue and plays at once against bots, unranked.
function A.fillSearch(id)
    local q = pending[id]
    if not q then return false, "You are not searching for a match." end
    if q.match then return false, "Your match is already on its way." end
    local a = registry[q.activity]
    if not offersBots(a) then return false, (a and a.label or "This activity") .. " cannot be filled with bots." end
    if q.lead ~= nil and q.lead ~= id then return false, "Your crew leader decides on bots." end
    if a.status.joinable == false then return false, a.label .. " is not taking players right now." end
    local players = { id }
    local party = crewOf(id)
    for _, member in ipairs(party and party.leader == id and party.members or {}) do
        local theirs = pending[member]
        if member ~= id and theirs and theirs.activity == a.id and not theirs.match and theirs.lead == id then players[#players + 1] = member end
    end
    withdraw(players)
    local teams, bots, enemies, mode = botPlan(a, lobbyOf(a), q.mode, players)
    if not startMatch(a, players, { teams = teams, bots = bots, enemies = enemies, mode = mode, options = q.options, from = "panel", lead = id }) then
        return false, a.label .. " did not answer. Try again in a moment."
    end
    for i = 2, #players do
        LightRP.notice(players[i], { kind = "contract", title = "CREW", durationMs = 6000,
            body = displayName(id) .. " filled the match with bots: unranked, nothing is recorded." })
    end
    return true, "Bots fill the empty places: " .. a.label .. " starts, unranked."
end

-- ---------------------------------------------------------------------------
-- Friendly crew matches: the leader splits the crew (auto-balanced by street cred,
-- then moved by hand), optionally with bots in the empty places; always unranked.

-- teams (nil for a free-for-all), bench, players (free-for-all), mode
local function balance(a, l, mode, members)
    local shape, n = shapeOf(l)
    local sorted = copy(members)
    local tiers = {}
    for _, p in ipairs(sorted) do tiers[p] = tierOf(p) end
    table.sort(sorted, function(x, y) if tiers[x] ~= tiers[y] then return tiers[x] > tiers[y] end return x < y end)
    if shape == "ffa" then
        local players, bench = {}, {}
        for _, p in ipairs(sorted) do if #players < a.maxPlayers then players[#players + 1] = p else bench[#bench + 1] = p end end
        return nil, bench, players, mode
    end
    local size
    if shape == "teams" then
        size = teamSizeOf(l, mode)
        if not size and type(l.teamSize) == "table" then
            -- the largest mode the crew fills, else the smallest
            local all = sizedModes(a, l)
            if all[1] then mode, size = all[1].mode, all[1].size end
            for _, m in ipairs(all) do if m.size * n <= #members then mode, size = m.mode, m.size end end
        end
        size = size or 1
    else
        size = math.max(1, math.ceil(#members / n))
    end
    local teams, bench = {}, {}
    for i = 1, n do teams[i] = {} end
    -- snake order: the strongest on alternate sides (A B B A A B ...)
    for k, p in ipairs(sorted) do
        local round, pos = (k - 1) // n, (k - 1) % n
        local want = round % 2 == 0 and pos + 1 or n - pos
        local placed = false
        for step = 0, n - 1 do
            local i = (want - 1 + step) % n + 1
            if #teams[i] < size then teams[i][#teams[i] + 1] = p; placed = true; break end
        end
        if not placed then bench[#bench + 1] = p end
    end
    return teams, bench, nil, mode
end

-- The bots of a friendly: per team (team shapes) or AI opponents (free-for-all).
local function friendlyBots(a, l, f)
    local shape, n = shapeOf(l)
    if not f.teams then return nil, f.bots and math.max(0, bodiesOf(a, l) - #f.players) or 0 end
    local size = teamSizeOf(l, f.mode)
    if shape == "split" then
        size = math.ceil(bodiesOf(a, l) / n)
        for _, team in ipairs(f.teams) do size = math.max(size, #team) end
    end
    local bots = {}
    for i, team in ipairs(f.teams) do bots[i] = f.bots and math.max(0, (size or #team) - #team) or 0 end
    return bots, nil
end

-- Why a friendly cannot start yet (nil: it can).
local function friendlyIssue(a, l, f)
    local shape = shapeOf(l)
    if not f.teams then
        if #f.players == 0 then return "Nobody plays: move a player in." end
        if #f.players < a.minPlayers and not f.bots then
            return string.format("%s needs %d players: turn bots on for the empty places.", a.label, a.minPlayers)
        end
        if #f.players < 2 and not f.bots then return "A friendly needs two players, or bots." end
        return nil
    end
    local humans = #flatten(f.teams)
    if humans == 0 then return "Nobody plays: move a player onto a team." end
    if not f.bots then
        if humans < 2 then return "A friendly needs two players, or bots for the rest." end
        local size = shape == "teams" and teamSizeOf(l, f.mode) or nil
        for i, team in ipairs(f.teams) do
            if size and #team < size then
                return string.format("Team %s has %d of %d players: move one or turn bots on.", letter(i), #team, size)
            elseif #team == 0 then
                return string.format("Team %s is empty: move a player or turn bots on.", letter(i))
            end
        end
        if humans < a.minPlayers then return string.format("%s needs %d players: turn bots on for the empty places.", a.label, a.minPlayers) end
    end
    return nil
end

-- The set-up follows the crew: a member who left is dropped, a new one waits on the
-- bench; a leader who lost the lead (or a crew of one) loses the set-up.
local function syncFriendly(leader)
    local f = friendlies[leader]
    if not f then return nil end
    local a = registry[f.activity]
    local party = crewOf(leader)
    if not a or not party or party.leader ~= leader or #(party.members or {}) < 2 then friendlies[leader] = nil; return nil end
    local member, placed = {}, {}
    for _, p in ipairs(party.members) do member[p] = true end
    local function keep(list)
        local out = {}
        for _, p in ipairs(list or {}) do if member[p] and not placed[p] then placed[p] = true; out[#out + 1] = p end end
        return out
    end
    if f.teams then for i, team in ipairs(f.teams) do f.teams[i] = keep(team) end else f.players = keep(f.players) end
    f.bench = keep(f.bench)
    for _, p in ipairs(party.members) do
        if not placed[p] then
            if not f.teams and #f.players < a.maxPlayers then f.players[#f.players + 1] = p else f.bench[#f.bench + 1] = p end
        end
    end
    return f
end
A.syncFriendly = syncFriendly

local function touchCrew(leader)
    local party = crewOf(leader)
    for _, p in ipairs(party and party.members or { leader }) do touch(p) end
end

function A.friendlyOpen(id, activityId, mode, bots)
    local a = type(activityId) == "string" and registry[activityId] or nil
    if not a then return false, "That activity is not available." end
    if not offersFriendly(a) then return false, a.label .. " has no friendly match." end
    local party = crewOf(id)
    if not party or #(party.members or {}) < 2 then return false, "A friendly needs a crew: invite players in the Crew tab first." end
    if party.leader ~= id then return false, "Your crew leader sets up friendly matches." end
    if mode ~= nil then
        local known = false
        for _, m in ipairs(a.modes or {}) do if m.id == mode then known = true end end
        if not known then mode = nil end
    end
    local ok, why = check(id, activityId)
    if not ok then return false, why end
    local l = lobbyOf(a)
    local old = friendlies[id]
    local teams, bench, players, chosen = balance(a, l, mode, party.members)
    friendlies[id] = { activity = a.id, mode = chosen, teams = teams, bench = bench, players = players,
        bots = bots == true or (bots == nil and old ~= nil and old.activity == a.id and old.bots == true), at = now() }
    touchCrew(id)
    return true, "Friendly " .. a.label .. (chosen and (" " .. chosen) or "") .. ": set the teams, then start. Unranked."
end

local function ownFriendly(id)
    local f = syncFriendly(id)
    if f then return f end
    local party = crewOf(id)
    if party and party.leader ~= id and friendlies[party.leader] then return nil, "Your crew leader sets up the friendly." end
    return nil, "No friendly match is being set up."
end

-- team 1 -> team 2 -> ... -> bench -> team 1. A full team (fixed size) swaps: its
-- last player takes the moved player's place. Free-for-all: in <-> bench.
function A.friendlyMove(id, target)
    local f, why = ownFriendly(id)
    if not f then return false, why end
    target = pid(target)
    local a, l = registry[f.activity], lobbyOf(registry[f.activity])
    if not f.teams then
        local at = target and removeFrom(f.players, target)
        if at then f.bench[#f.bench + 1] = target
        elseif target and removeFrom(f.bench, target) then
            if #f.players >= a.maxPlayers then f.bench[#f.bench + 1] = table.remove(f.players) end
            f.players[#f.players + 1] = target
        else return false, "That player is not in the set-up." end
        touchCrew(id)
        return true
    end
    local from, index
    for i, team in ipairs(f.teams) do for k, p in ipairs(team) do if p == target then from, index = i, k end end end
    if not from then
        for k, p in ipairs(f.bench) do if p == target then from, index = 0, k end end
    end
    if not from then return false, "That player is not in the set-up." end
    local n = #f.teams
    local to = from == 0 and 1 or (from < n and from + 1 or 0)
    local size = shapeOf(l) == "teams" and teamSizeOf(l, f.mode) or nil
    local source = from == 0 and f.bench or f.teams[from]
    table.remove(source, index)
    if to == 0 then
        f.bench[#f.bench + 1] = target
    else
        local dest = f.teams[to]
        if size and #dest >= size then table.insert(source, index, table.remove(dest)) end
        dest[#dest + 1] = target
    end
    touchCrew(id)
    return true
end

function A.friendlyBalance(id)
    local f, why = ownFriendly(id)
    if not f then return false, why end
    local a = registry[f.activity]
    local teams, bench, players = balance(a, lobbyOf(a), f.mode, crewOf(id).members)
    f.teams, f.bench, f.players = teams, bench, players
    touchCrew(id)
    return true, "Teams balanced by street cred."
end

function A.friendlyBots(id, on)
    local f, why = ownFriendly(id)
    if not f then return false, why end
    f.bots = on == true
    touchCrew(id)
    return true, f.bots and "Bots take the empty places." or "No bots: every place needs a player."
end

function A.friendlyCancel(id)
    local f = friendlies[id]
    if not f then return false, "No friendly match is being set up." end
    friendlies[id] = nil
    touchCrew(id)
    return true, "Friendly cancelled."
end

function A.friendlyStart(id)
    local f, why = ownFriendly(id)
    if not f then return false, why end
    local a = registry[f.activity]
    local l = lobbyOf(a)
    local issue = friendlyIssue(a, l, f)
    if issue then return false, issue end
    if a.status.joinable == false then return false, a.label .. " is not taking players right now." end
    local players = f.teams and flatten(f.teams) or copy(f.players)
    for _, p in ipairs(players) do
        local ok, reason = check(p, a.id)
        if not ok then
            return false, (p == id and "You cannot play: " or (displayName(p) .. " cannot play: ")) .. lowerFirst(reason)
                .. (p == id and "" or " Bench them or wait.")
        end
    end
    withdraw(players)
    local bots, enemies = friendlyBots(a, l, f)
    local teams
    if f.teams then teams = {}; for i, team in ipairs(f.teams) do teams[i] = copy(team) end end
    if not startMatch(a, players, { friendly = true, teams = teams, bots = bots, enemies = enemies, mode = f.mode,
            options = {}, from = "friendly", lead = id }) then
        return false, a.label .. " did not answer. Try again in a moment."
    end
    friendlies[id] = nil
    for _, p in ipairs(players) do
        if p ~= id then
            local side
            for i, team in ipairs(teams or {}) do for _, q in ipairs(team) do if q == p then side = i end end end
            LightRP.notice(p, { kind = "contract", title = "FRIENDLY MATCH", durationMs = 6000,
                body = string.format("%s started a friendly %s%s. Unranked: nothing is recorded.", displayName(id), a.label,
                    side and (": you are on team " .. letter(side)) or "") })
        end
    end
    for _, p in ipairs(f.bench) do
        LightRP.notice(p, { kind = "info", title = "FRIENDLY MATCH", durationMs = 6000,
            body = displayName(id) .. " started a friendly " .. a.label .. ". You sit this one out." })
    end
    touchCrew(id)
    return true, "Friendly " .. a.label .. " starting · unranked."
end

-- The set-up as the crew's panels show it (leader: editable; members: read only).
local function friendlyView(id)
    local party = crewOf(id)
    if not party or #(party.members or {}) < 2 then return false end
    local f = syncFriendly(party.leader)
    if not f then return false end
    local a = registry[f.activity]
    local l = lobbyOf(a)
    local shape = shapeOf(l)
    local function people(list)
        local out = {}
        for _, p in ipairs(list or {}) do out[#out + 1] = { id = p, name = displayName(p), tier = tierOf(p) } end
        return out
    end
    local bots, enemies = friendlyBots(a, l, f)
    local v = { id = a.id, label = a.label, mode = f.mode, bots = f.bots, shape = shape, size = teamSizeOf(l, f.mode) or 0,
        leader = displayName(party.leader), mine = party.leader == id, bench = people(f.bench), issue = friendlyIssue(a, l, f) }
    if f.teams then
        v.teams, v.teamBots = {}, bots
        for i, team in ipairs(f.teams) do v.teams[i] = people(team) end
    else
        v.players, v.enemies = people(f.players), enemies
    end
    return v
end

-- The rest of the crew follows its leader into the queue: each member is
-- checked like a join of their own and gets the leader's options (the same
-- `squad`, the same difficulty); a member who cannot go is told why and stays out.
-- A member below the leader's PvE difficulty is never refused: they are told, once,
-- that they play it for the reward of their own tier (`reduced` for the leader).
local function queueCrew(leader, a, options, party, difficulty)
    local followed, out, reduced = 0, {}, {}
    local leaderName = LightRP.characters.displayName(leader)
    for _, member in ipairs(party.members) do
        if member ~= leader then
            local e, q = owned[member], pending[member]
            if e and e.activity == a.id then
                followed = followed + 1
            elseif q and q.activity == a.id then
                followed = followed + 1
            else
                local ok, why = check(member, a.id)
                if ok then
                    if q then emit(EV.leaveRequest, member, q.activity) end
                    local theirs = {}
                    for key, value in pairs(options) do theirs[key] = value end
                    theirs.target = nil -- a challenge stays the leader's
                    theirs.squad = squadOf(party)
                    local below = difficulty ~= nil and not difficultyAllowed(member, a, difficulty)
                    pending[member] = { activity = a.id, at = now(), crew = party.id, difficulty = difficulty,
                        told = below and difficulty or nil }
                    if emit(EV.join, member, a.id, theirs) then
                        followed = followed + 1
                        touch(member)
                        local body = leaderName .. " queued the crew for " .. a.label .. ". /leave drops you out."
                        if below then
                            body = body .. " " .. carriedLine(member, a, difficulty)
                            local basis = effectiveDifficulty(member, offered(a), difficulty)
                            reduced[#reduced + 1] = string.format("%s (%s)", LightRP.characters.displayName(member), basis and diffLabel(basis) or "none")
                        end
                        LightRP.notice(member, { kind = "contract", title = "CREW", durationMs = below and 9000 or 6000, body = body })
                    else
                        pending[member] = nil
                    end
                else
                    out[#out + 1] = LightRP.characters.displayName(member) .. " stays out: " .. lowerFirst(why)
                    LightRP.notice(member, { kind = "warning", title = "CREW", durationMs = 7000,
                        body = leaderName .. " queued the crew for " .. a.label .. ". You stay out: " .. lowerFirst(why) })
                end
            end
        end
    end
    return followed, out, reduced
end

function A.requestJoin(id, activityId, from, extra)
    local a = type(activityId) == "string" and registry[activityId] or nil
    if not a then return false, "That activity is not available." end
    -- in a crew, its leader starts the activities and the crew follows
    local party = crewOf(id)
    local crew = party and #party.members > 1 and party or nil
    if crew and crew.leader ~= id then return false, "Your crew leader starts activities. Leave the crew to go solo." end
    local q = pending[id]
    if q and q.activity == activityId then return false, "You are already queued for " .. a.label .. "." end
    local ok, why = check(id, activityId)
    if not ok then return false, why end
    if a.status.joinable == false then return false, a.label .. " is not taking players right now." end
    local options = extraOptions(extra)
    local chosen = options[a.modeKey]
    if a.modes and chosen ~= nil then
        local known, ids = false, {}
        for _, m in ipairs(a.modes) do ids[#ids + 1] = m.id; if m.id == chosen then known = true end end
        if not known then return false, "Choose " .. a.modeKey .. ": " .. table.concat(ids, ", ") .. "." end
    end
    -- PvE: the difficulty (the first offered by default), within the player's tier
    local difficulty
    if a.pve then
        -- without declared difficulties, options.difficulty stays the provider's own
        if a.difficulties then difficulty = options.difficulty end
        if difficulty == nil then difficulty = offered(a)[1] end
        local allowed, refused = difficultyAllowed(id, a, difficulty)
        if not allowed then return false, refused end
        if a.difficulties then options.difficulty, options.scaling = difficulty, scalingOf(difficulty) end
    end
    if q then emit(EV.leaveRequest, id, q.activity) end
    pending[id] = { activity = a.id, at = now(), difficulty = difficulty }
    options.from, options.squad = clean(from, 24) or "panel", squadOf(party)
    if not emit(EV.join, id, a.id, options) then
        pending[id] = nil
        return false, a.label .. " did not answer. Try again in a moment."
    end
    touch(id)
    local followed, out, reduced = 0, {}, {}
    if crew then followed, out, reduced = queueCrew(id, a, options, crew, difficulty) end
    local text = (owned[id] and "Joining " or "Request sent to ") .. a.label
    if followed > 0 then text = text .. string.format(" with %d crew member%s", followed, followed == 1 and "" or "s") end
    text = text .. "."
    if #reduced > 0 then text = text .. string.format(" Below %s, reduced reward: %s.", diffLabel(difficulty), table.concat(reduced, ", ")) end
    if #out > 0 then text = text .. " " .. table.concat(out, ". ") .. "." end
    return true, text
end

function A.requestLeave(id)
    local e = owned[id]
    if e then
        local label = labelOf(e.activity)
        if leaving[id] and leaving[id].token == e.token then return true, "Leaving " .. label .. "..." end
        leaving[id] = { token = e.token, at = now() }
        LightRP.log("activities: %d asked to leave %s", id, e.activity)
        emit(EV.leaveRequest, id, e.activity)
        if owned[id] == e then
            -- the provider did not hand the player back: the core does, and says so
            SetTimeout(C.leaveTimeoutMs, function()
                if owned[id] == e then
                    LightRP.log("activities: %s did not release %d in time, returning them", e.activity, id)
                    release(id, e, true, "timeout")
                end
            end)
        end
        touch(id)
        return true, "Leaving " .. label .. "."
    end
    local q = pending[id]
    if q then
        pending[id] = nil
        emit(EV.leaveRequest, id, q.activity)
        touch(id)
        -- a crew leader leaving the queue takes the crew they queued out of it
        local party = crewOf(id)
        if party and party.leader == id then
            for _, member in ipairs(party.members) do
                local theirs = pending[member]
                if member ~= id and theirs and theirs.crew == party.id and theirs.activity == q.activity then
                    pending[member] = nil
                    emit(EV.leaveRequest, member, q.activity)
                    touch(member)
                    LightRP.notice(member, { kind = "info", title = "CREW", body = "Your crew leader left the queue for " .. labelOf(q.activity) .. "." })
                end
            end
        end
        return true, "You left the queue for " .. labelOf(q.activity) .. "."
    end
    if returning[id] then return false, "You are already on your way back." end
    if internalOwner(id) == "missions" then return false, "You are on a mission: /mission leave abandons it." end
    return false, "You are not in an activity."
end

-- ---------------------------------------------------------------------------
-- Stats, leaderboards, reputation

Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_activity_stats (
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL, activity_id VARCHAR(64) NOT NULL,
    board VARCHAR(80) NOT NULL DEFAULT '',
    character_name VARCHAR(64) NOT NULL DEFAULT '',
    played INT NOT NULL DEFAULT 0, wins INT NOT NULL DEFAULT 0, kills INT NOT NULL DEFAULT 0, deaths INT NOT NULL DEFAULT 0,
    best_score DOUBLE NULL, best_time_ms INT NULL, best_placement INT NULL, reputation INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, character_key, activity_id, board),
    KEY lightrp_activity_stats_wins (activity_id, board, wins),
    KEY lightrp_activity_stats_time (activity_id, board, best_time_ms)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
-- `board` is '' for a character's totals in an activity, or "<courseId>@<revision>"
-- for a course's own board (a result carrying stats.courseId): best times are
-- compared per course and revision, never across courses.
-- Reputation granted per account (every character of it) and UTC day: the daily cap.
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_activity_rep_daily (
    identifier VARCHAR(128) NOT NULL, day_index INT NOT NULL, granted INT NOT NULL DEFAULT 0,
    PRIMARY KEY (identifier, day_index)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local function dayIndex()
    local unix = (Open77.time and type(Open77.time.unix) == "function" and Open77.time.unix())
        or (type(GetUnixTime) == "function" and GetUnixTime()) or os.time()
    return math.floor(unix / 86400)
end

function A.normalizeResult(r)
    local stats = type(r.stats) == "table" and r.stats or {}
    local function positive(value, hi) return (tonumber(value) or 0) >= 1 and int(value, 1, hi) or nil end
    return {
        placement = positive(r.placement, 1000),
        score = num(r.score, -1e9, 1e9),
        won = r.won == true,
        kills = int(stats.kills, 0, 10000) or 0,
        deaths = int(stats.deaths, 0, 10000) or 0,
        -- a finished run only: no time, no best time
        timeMs = positive(stats.timeMs, 86400000),
        -- what the provider asks (nil: none named); A.result turns it into the ask
        reputation = int(r.reputation, 0, 100000),
        difficulty = type(r.difficulty) == "string" and DIFFS[r.difficulty] and r.difficulty or nil,
        board = A.boardOf(stats),
    }
end

-- A course board: stats.courseId (+ stats.courseRevision, 0 when absent).
function A.boardOf(stats)
    local course = type(stats) == "table" and stats.courseId
    if type(course) ~= "string" or #course > 48 or not course:match("^[%w][%w_%-%.:]*$") then return "" end
    return course .. "@" .. (int(stats.courseRevision, 0, 1000000) or 0)
end
local function boardView(board)
    if type(board) ~= "string" or board == "" then return nil end
    local course, revision = board:match("^(.*)@(%d+)$")
    return { id = board, course = course or board, revision = tonumber(revision) or 0 }
end

local function rowView(row)
    return { played = tonumber(row.played) or 0, wins = tonumber(row.wins) or 0, kills = tonumber(row.kills) or 0,
        deaths = tonumber(row.deaths) or 0, bestScore = tonumber(row.best_score), bestTimeMs = tonumber(row.best_time_ms),
        bestPlacement = tonumber(row.best_placement), reputation = tonumber(row.reputation) or 0 }
end
local function merge(row, r, granted, name)
    row.character_name = name
    row.played = (row.played or 0) + 1
    row.wins = (row.wins or 0) + (r.won and 1 or 0)
    row.kills = (row.kills or 0) + r.kills
    row.deaths = (row.deaths or 0) + r.deaths
    if r.score and (row.best_score == nil or r.score > row.best_score) then row.best_score = r.score end
    if r.timeMs and (row.best_time_ms == nil or r.timeMs < row.best_time_ms) then row.best_time_ms = r.timeMs end
    if r.placement and (row.best_placement == nil or r.placement < row.best_placement) then row.best_placement = r.placement end
    row.reputation = (row.reputation or 0) + granted
    return row
end

-- One writer per account at a time: the daily cap is read then written.
local locks = {}
local function lock(key)
    while locks[key] do Wait(50) end
    locks[key] = true
end
local function unlock(key) locks[key] = nil end

local function dailyUsed(identifier, day)
    if not Db.ready then
        local d = memDaily[identifier]
        return d and d.day == day and d.granted or 0
    end
    local ok, rows = Db.read("SELECT granted FROM lightrp_activity_rep_daily WHERE identifier = ? AND day_index = ?", { identifier, day })
    if not ok then return nil end
    return rows[1] and tonumber(rows[1].granted) or 0
end
local function addDaily(identifier, day, granted)
    if not Db.ready then
        local d = memDaily[identifier]
        if not d or d.day ~= day then d = { day = day, granted = 0 }; memDaily[identifier] = d end
        d.granted = d.granted + granted
        return true
    end
    return Db.run([[INSERT INTO lightrp_activity_rep_daily (identifier, day_index, granted) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE granted = granted + VALUES(granted)]], { identifier, day, granted })
end

-- A NULL is written as a literal: a nil inside a parameter list is a hole.
local function placeholder(value, params)
    if value == nil then return "NULL" end
    params[#params + 1] = value
    return "?"
end
local function saveRow(who, activityId, board, r, granted)
    local memKey = who.identifier .. "|" .. who.characterKey .. "|" .. activityId .. "|" .. board
    if not Db.ready then
        memStats[memKey] = merge(memStats[memKey] or { activity_id = activityId, board = board }, r, granted, who.name)
        return true
    end
    local params = { who.identifier, who.characterKey, activityId, board, who.name, r.won and 1 or 0, r.kills, r.deaths }
    local values = table.concat({ "?, ?, ?, ?, ?, 1, ?, ?, ?", placeholder(r.score, params), placeholder(r.timeMs, params),
        placeholder(r.placement, params), placeholder(granted, params) }, ", ")
    return Db.run([[INSERT INTO lightrp_activity_stats (identifier, character_key, activity_id, board, character_name, played, wins, kills, deaths,
            best_score, best_time_ms, best_placement, reputation) VALUES (]] .. values .. [[)
        ON DUPLICATE KEY UPDATE character_name = VALUES(character_name), played = played + 1, wins = wins + VALUES(wins),
            kills = kills + VALUES(kills), deaths = deaths + VALUES(deaths),
            best_score = CASE WHEN VALUES(best_score) IS NULL THEN best_score
                WHEN best_score IS NULL OR VALUES(best_score) > best_score THEN VALUES(best_score) ELSE best_score END,
            best_time_ms = CASE WHEN VALUES(best_time_ms) IS NULL THEN best_time_ms
                WHEN best_time_ms IS NULL OR VALUES(best_time_ms) < best_time_ms THEN VALUES(best_time_ms) ELSE best_time_ms END,
            best_placement = CASE WHEN VALUES(best_placement) IS NULL THEN best_placement
                WHEN best_placement IS NULL OR VALUES(best_placement) < best_placement THEN VALUES(best_placement) ELSE best_placement END,
            reputation = reputation + VALUES(reputation)]], params)
end
-- The totals row always; a course result also its course board row (the time
-- counts there only: best times of different courses never compare).
local function saveStats(who, activityId, r, granted)
    if r.board == "" then return saveRow(who, activityId, "", r, granted) end
    local totals = { placement = r.placement, score = r.score, won = r.won, kills = r.kills, deaths = r.deaths }
    if not saveRow(who, activityId, "", totals, granted) then return false end
    if not saveRow(who, activityId, r.board, r, 0) then
        LightRP.log("activities: course board %s of %s not recorded", r.board, activityId)
    end
    return true
end

-- The player's own rows (panel: "your best") and today's reputation.
local function loadMine(id)
    local who = identity(id)
    if not who then mine[id] = nil; return end
    local view = { key = who.identifier .. "|" .. who.characterKey, stats = {}, boards = {}, day = dayIndex(), today = 0 }
    local function keep(row)
        local board = row.board or ""
        if board == "" then view.stats[row.activity_id] = rowView(row)
        else view.boards[row.activity_id .. "|" .. board] = rowView(row) end
    end
    if Db.ready then
        local ok, rows = Db.read([[SELECT activity_id, board, played, wins, kills, deaths, best_score, best_time_ms, best_placement, reputation
            FROM lightrp_activity_stats WHERE identifier = ? AND character_key = ?]], { who.identifier, who.characterKey })
        if ok then for _, row in ipairs(rows) do keep(row) end end
    else
        local prefix = view.key .. "|"
        for key, row in pairs(memStats) do
            if key:sub(1, #prefix) == prefix then keep(row) end
        end
    end
    view.today = dailyUsed(who.identifier, view.day) or 0
    -- the character may have changed while the database answered
    local still = identity(id)
    if still and still.identifier == who.identifier and still.characterKey == who.characterKey then mine[id] = view end
end
A.loadMine = loadMine

-- The board the panel shows per activity: the course of the latest result (a
-- course activity), else the totals.
local shownBoard = {}
local refreshing = {}
refreshTop = function(activityId)
    local a = registry[activityId]
    if not a or refreshing[activityId] then return end
    refreshing[activityId] = true
    local byTime = C.leaderboard.byTime[a.kind] == true
    local size = math.max(1, math.min(20, math.floor(tonumber(C.leaderboard.size) or 5)))
    local list = {}
    local board = shownBoard[activityId]
    local ok, err = pcall(function()
        local rows
        if board == nil and Db.ready then
            local read, latest = Db.read([[SELECT board FROM lightrp_activity_stats WHERE activity_id = ? AND board <> ''
                ORDER BY updated_at DESC LIMIT 1]], { activityId })
            if read then board = latest[1] and tostring(latest[1].board) or ""; shownBoard[activityId] = board end
        end
        board = board or ""
        if Db.ready then
            local sql = byTime
                and [[SELECT character_name, wins, played, best_time_ms, best_score FROM lightrp_activity_stats
                    WHERE activity_id = ? AND board = ? AND best_time_ms IS NOT NULL ORDER BY best_time_ms ASC, updated_at ASC LIMIT ]] .. size
                or [[SELECT character_name, wins, played, best_time_ms, best_score FROM lightrp_activity_stats
                    WHERE activity_id = ? AND board = ? AND played > 0 ORDER BY wins DESC, best_score DESC, played ASC LIMIT ]] .. size
            local read
            read, rows = Db.read(sql, { activityId, board })
            if not read then rows = nil end
        else
            rows = {}
            for _, row in pairs(memStats) do
                if row.activity_id == activityId and (row.board or "") == board and (not byTime or row.best_time_ms) then rows[#rows + 1] = row end
            end
            table.sort(rows, function(x, y)
                if byTime then return x.best_time_ms < y.best_time_ms end
                if (x.wins or 0) ~= (y.wins or 0) then return (x.wins or 0) > (y.wins or 0) end
                return (x.best_score or -math.huge) > (y.best_score or -math.huge)
            end)
        end
        if not rows then return end
        for i = 1, math.min(size, #rows) do
            local row = rows[i]
            list[#list + 1] = { rank = i, name = tostring(row.character_name or "?"), wins = tonumber(row.wins) or 0,
                played = tonumber(row.played) or 0, bestTimeMs = tonumber(row.best_time_ms), bestScore = tonumber(row.best_score) }
        end
        if registry[activityId] then tops[activityId] = { list = list, at = now(), byTime = byTime, board = board } end
    end)
    refreshing[activityId] = nil
    if not ok then LightRP.log("activities: leaderboard %s failed: %s", activityId, tostring(err)) end
    dirty()
end
A.refreshTop = function(activityId) refreshTop(activityId) end

local function sameCharacter(id, who)
    local now = identity(id)
    return now ~= nil and now.identifier == who.identifier and now.characterKey == who.characterKey
end

-- Runs on Light RP's thread (the event handler only validates).
local function record(id, e, r)
    local who = e.identity
    if not who then return end
    lock(who.identifier)
    local ok, err = pcall(function()
        local day = dayIndex()
        local used = dailyUsed(who.identifier, day)
        local cap = math.max(0, math.floor(tonumber(C.reputation.dailyCap) or 0))
        -- an unreadable daily row grants nothing: the cap must hold
        local granted = used and math.max(0, math.min(r.reputation, cap - used)) or 0
        local saved = saveStats(who, e.activity, r, granted)
        if not saved then granted = 0 end
        if granted > 0 and not addDaily(who.identifier, day, granted) then
            LightRP.log("activities: daily reputation of %s not recorded", who.identifier)
        end
        local here = sameCharacter(id, who)
        if granted > 0 and here and C.reputation.grantTo == "missions" and LightRP.missions
            and type(LightRP.missions.addReputation) == "function" then
            LightRP.missions.addReputation(id, granted)
        end
        if here then
            loadMine(id)
            local parts = { labelOf(e.activity) }
            local shown = r.played and DIFFS[r.played] and r.played or r.difficulty
            if shown and DIFFS[shown] then
                parts[#parts + 1] = DIFFS[shown].label
                    .. (r.difficulty and r.difficulty ~= shown and DIFFS[r.difficulty] and (" (" .. DIFFS[r.difficulty].label .. " reward)") or "")
            end
            if r.placement then parts[#parts + 1] = r.won and "won" or ("#" .. r.placement) elseif r.won then parts[#parts + 1] = "won" end
            local body = table.concat(parts, " · ")
            if granted > 0 then body = body .. string.format(" · +%d reputation", granted)
            elseif r.reputation > 0 then body = body .. " · daily reputation cap reached" end
            LightRP.notice(id, { kind = r.won and "success" or "info", title = "ACTIVITY RESULT", body = body, durationMs = 7000 })
        end
        LightRP.log("activities: result %s for %s: placement %s, won %s, +%d rep (asked %d)", e.activity, who.name,
            tostring(r.placement), tostring(r.won), granted, r.reputation)
    end)
    unlock(who.identifier)
    if not ok then LightRP.log("activities: result of %s not recorded: %s", tostring(who.identifier), tostring(err)) end
    if r.board ~= "" then shownBoard[e.activity] = r.board end
    refreshTop(e.activity)
    if registry[e.activity] then touch(id) end
end

function A.result(playerId, activityId, result)
    local id = pid(playerId)
    if not id or type(activityId) ~= "string" or type(result) ~= "table" then return false, "invalid" end
    local e = owned[id]
    if not e or e.activity ~= activityId then e = recent[id] and recent[id][activityId] or nil end
    if not e then return false, "not_in_activity" end
    if foreign(e.resource) then return false, "foreign" end
    local t = now()
    if e.leftAt and t - e.leftAt > C.resultGraceMs then return false, "late" end
    if e.lastResultAt and t - e.lastResultAt < RESULT_INTERVAL_MS then return false, "too_soon" end
    -- after the leave, one result closes the entry
    if e.leftAt and e.resultAfterLeave then return false, "duplicate" end
    e.lastResultAt = t
    if e.leftAt then e.resultAfterLeave = true end
    local r = A.normalizeResult(result)
    -- PvE only, at the difficulty the player's tier allows (docs/pve-progression.md);
    -- the notice names the difficulty played and, below it, the one that paid
    r.played = e.pve and (e.difficulty or r.difficulty) or nil
    r.reputation, r.difficulty = reputationAsk(id, e, r)
    if A.botsEnabled or result.test == true then
        -- staff testing with bots: nothing earned, nothing ranked
        LightRP.log("activities: test result %s for %d not recorded (placement %s, won %s)", e.activity, id,
            tostring(r.placement), tostring(r.won))
        return true
    end
    if LightRP.activityPay then pcall(LightRP.activityPay.onResult, id, e, r, result) end -- eddies: activity_pay.lua
    CreateThread(function() record(id, e, r) end)
    return true
end

AddEventHandler(EV.result, function(playerId, activityId, result)
    local ok, err = pcall(A.result, playerId, activityId, result)
    if not ok then LightRP.log("activities: result handler failed: %s", tostring(err)) end
end)

function A.status(activityId, status)
    local a = type(activityId) == "string" and registry[activityId] or nil
    if not a or type(status) ~= "table" then return false end
    if foreign(a.resource) then return false end
    a.status = { phase = PHASES[status.phase] and status.phase or "idle", players = int(status.players, 0, 10000) or 0,
        queued = int(status.queued, 0, 10000) or 0, joinable = status.joinable ~= false, detail = clean(status.detail, 120) or "" }
    dirty()
    return true
end
AddEventHandler(EV.status, function(activityId, status)
    local ok, err = pcall(A.status, activityId, status)
    if not ok then LightRP.log("activities: status handler failed: %s", tostring(err)) end
end)

-- Damage taken outside an activity: the eligibility's 60 s of calm.
AddEventHandler("open77:playerDamaged", function(victim, _, amount, _, weapon)
    local id = pid(victim)
    if not id or (tonumber(amount) or 0) <= 0 or A.owns(id) then return end
    if type(weapon) == "string" and weapon:sub(1, 8) == "lightrp:" then return end -- hunger, a placement
    damagedAt[id] = now()
end)

-- ---------------------------------------------------------------------------
-- Exports (the contract)

local function exported(name, fn)
    exports(name, function(...)
        local result = table.pack(pcall(fn, ...))
        if not result[1] then
            LightRP.log("activities: %s failed: %s", name, tostring(result[2]))
            return false, "Light RP could not process the request."
        end
        return table.unpack(result, 2, result.n)
    end)
end
exported("activityRegister", A.register)
exported("activityBots", function() return A.botsEnabled == true end)
exported("activityCheck", function(playerId, activityId, opts)
    local id = pid(playerId)
    if not id then return false, "Invalid player." end
    if activityId ~= nil and (type(activityId) ~= "string" or not registry[activityId]) then return false, "That activity is not available." end
    local ok, why = check(id, activityId)
    if not ok then return false, why end
    -- opts.difficulty: may this player play it (a PvE activity's tier gate; a crew
    -- member below it is let in when their leader may pick it, for a lower reward)
    local a = activityId and registry[activityId]
    if a and a.pve and type(opts) == "table" and opts.difficulty ~= nil then
        local allowed, refused = difficultyFor(id, a, opts.difficulty)
        if not allowed then return false, refused end
    end
    return true
end)
exported("activityEnter", A.enter)
exported("activityLeave", A.leave)
exports("activityOwner", function(playerId)
    local id = pid(playerId)
    if not id then return nil end
    local e = owned[id]
    if e then return e.activity end
    local ok, name = pcall(internalOwner, id)
    return ok and name or nil
end)
exports("activityPlayer", function(playerId)
    local id = pid(playerId)
    if not id then return nil end
    local ok, who = pcall(A.player, id)
    return ok and who or nil
end)

-- ---------------------------------------------------------------------------
-- Player lifecycle

function A.onConnected(id)
    recent[id], damagedAt[id], watchers[id], mine[id] = nil, nil, nil, nil
end
function A.onDisconnected(id)
    local e = owned[id]
    -- the saved position is already the return point (characters.samplePosition)
    if e then release(id, e, false, "disconnect") end
    local q = pending[id]
    pending[id] = nil
    if q then emit(EV.leaveRequest, id, q.activity) end
    returning[id], leaving[id], damagedAt[id], watchers[id], mine[id] = nil, nil, nil, nil, nil
end
-- Another character (or the selector): the activity lets go, Light RP places the new one.
local function characterChanged(id, c)
    local e = owned[id]
    if e and e.character ~= c then release(id, e, false, "character") end
    local back = returning[id]
    if back and back.character ~= c then returning[id] = nil end
    local q = pending[id]
    if q then pending[id] = nil; emit(EV.leaveRequest, id, q.activity) end
    mine[id] = nil
end
function A.onCharacterLoaded(id, c)
    characterChanged(id, c)
    CreateThread(function() loadMine(id) end)
end
function A.onCharacterSwitched(id, c) characterChanged(id, c) end
function A.onCharacterActivated(id) CreateThread(function() loadMine(id) end) end
function A.onDatabaseReady()
    Db.run("DELETE FROM lightrp_activity_rep_daily WHERE day_index < ?", { dayIndex() - 7 })
    for _, aid in ipairs(order) do refreshTop(aid) end
    for _, raw in ipairs(GetPlayers()) do local id = pid(raw); if id then loadMine(id) end end
end

-- ---------------------------------------------------------------------------
-- The `activities` state key

local function nearby(id)
    local me = Open77.players.position(id)
    local list = {}
    if not me then return list end
    local squad = crewOf(id)
    local range = (tonumber(C.nearbyRange) or 15) ^ 2
    for _, raw in ipairs(GetPlayers()) do
        local other = pid(raw)
        if other and other ~= id and LightRP.characters.isRegistered(other) then
            local p = Open77.players.position(other)
            if p and (p.bucket or 0) == (me.bucket or 0) then
                local d2 = (p.x - me.x) ^ 2 + (p.y - me.y) ^ 2 + (p.z - me.z) ^ 2
                if d2 <= range then
                    local theirs = crewOf(other)
                    list[#list + 1] = { id = other, name = LightRP.characters.displayName(other), distance = math.floor(math.sqrt(d2) + 0.5),
                        inSquad = theirs ~= nil, mine = squad ~= nil and theirs == squad,
                        invited = squad ~= nil and squad.invites ~= nil and squad.invites[other] ~= nil }
                end
            end
        end
    end
    table.sort(list, function(x, y) return x.distance < y.distance end)
    while #list > (C.nearbyMax or 8) do table.remove(list) end
    return list
end

-- A PvE activity's difficulties for the panel: locked above the player's tier.
local function difficultiesView(tier, a)
    local M, out = LightRP.missions, {}
    for _, diffId in ipairs(offered(a)) do
        local d, need = DIFFS[diffId], minTierOf(diffId)
        local name = M and type(M.tierName) == "function" and M.tierName(need) or nil
        out[#out + 1] = { id = diffId, label = d and d.label or diffId, minTier = need, tierName = name,
            locked = tier < need, reputation = rewardOf(diffId, a.weight) }
    end
    return out
end
local function reputationView(id, today)
    local M = LightRP.missions
    local rep = { today = today, dailyCap = C.reputation.dailyCap, maxPerResult = C.reputation.maxPerResult,
        pvpGrants = C.reputation.pvpGrants == true }
    if M and type(M.tierInfo) == "function" then
        local ok, info = pcall(M.tierInfo, id)
        if ok and type(info) == "table" then
            rep.tier, rep.tierName, rep.points, rep.next, rep.nextName = info.tier, info.name, info.points, info.next, info.nextName
        end
    end
    return rep
end

function A.view(id)
    local ok, why = check(id)
    local view = mine[id]
    local tier = tierOf(id)
    local list = {}
    for _, aid in ipairs(order) do
        local a = registry[aid]
        if a then
            local s, top = a.status, tops[aid]
            list[#list + 1] = {
                id = a.id, label = a.label, kind = a.kind, description = a.description,
                minPlayers = a.minPlayers, maxPlayers = a.maxPlayers,
                phase = s.phase, players = s.players, queued = s.queued, joinable = s.joinable, detail = s.detail,
                byTime = C.leaderboard.byTime[a.kind] == true,
                modes = a.modes or {}, modeKey = a.modeKey,
                pve = a.pve == true, difficulties = a.pve and difficultiesView(tier, a) or nil,
                top = top and top.list or {},
                board = top and boardView(top.board) or nil,
                mine = view and view.stats[aid] or nil,
                mineBoard = view and top and top.board ~= "" and view.boards[aid .. "|" .. top.board] or nil,
            }
        end
    end
    local e, q = owned[id] or returning[id], pending[id]
    local today = view and view.day == dayIndex() and view.today or 0
    local state = {
        enabled = C.enabled ~= false,
        hub = { name = C.hub.name },
        list = list,
        current = e and { id = e.activity, label = labelOf(e.activity), sinceMs = now() - e.enteredAt,
            leaving = leaving[id] ~= nil, returning = returning[id] == e, difficulty = e.difficulty } or false,
        queued = q and { id = q.activity, label = labelOf(q.activity), sinceMs = now() - q.at, difficulty = q.difficulty } or false,
        mission = internalOwner(id) == "missions",
        eligible = ok == true, reason = why,
        reputation = reputationView(id, today),
        bots = A.botsEnabled == true,
        nearby = (watchers[id] or 0) > now() and nearby(id) or {},
    }
    -- a crew member waits for the leader: the panel says so instead of a join button
    local party = crewOf(id)
    if party and #party.members > 1 and party.leader ~= id then
        state.crewLeader = LightRP.characters.displayName(party.leader)
    end
    for _, extend in ipairs(A.extensions) do
        local done, err = pcall(extend, id, state)
        if not done then LightRP.log("activities: state extension failed: %s", tostring(err)) end
    end
    return state
end
LightRP.stateProvider("activities", A.view)

-- ---------------------------------------------------------------------------
-- The page's control path (the tutorial/framework style) and commands

LightRP.action("activities.control", function(id, payload)
    local op = payload.operation
    if op == "open" or op == "refresh" then
        A.watch(id)
        touch(id)
        if op == "open" then
            local tab = payload.tab == "contracts" and "contracts"
                or ((payload.tab == "crew" or payload.tab == "squad") and "crew") or "activities"
            LightRP.dialog(id, "activities", { tab = tab })
        end
        return
    end
    if op == "close" then watchers[id] = nil; return end
    local ok, text
    if op == "join" then ok, text = A.requestJoin(id, payload.id, payload.from, payload.options)
    elseif op == "leave" then ok, text = A.requestLeave(id)
    elseif type(op) == "string" and type(A.operations[op]) == "function" then ok, text = A.operations[op](id, payload)
    else ok, text = false, "Unknown activities operation." end
    LightRP.result(id, ok, text, "activities.control")
    A.watch(id)
    touch(id)
end)

LightRP.command("leave", { usage = "/leave (leave the activity you are in, or its queue)" }, function(source)
    if not source or source <= 0 then return false, "Players only." end
    return A.requestLeave(source)
end)

LightRP.command("activity", { usage = "/activity [list · join <id> · leave]" }, function(source, args)
    if not source or source <= 0 then return false, "Players only." end
    local verb = args[1]
    if verb == "leave" then return A.requestLeave(source) end
    if verb == "join" then
        if not args[2] then return false, "usage: /activity join <id> [mode|difficulty] (see /activity list)" end
        local a = registry[args[2]]
        -- a PvE activity's difficulty by its id (standard, hard, critical), else the mode
        local key = a and a.difficulties and args[3] and DIFFS[args[3]] and "difficulty" or (a and a.modeKey or "mode")
        return A.requestJoin(source, args[2], "command", args[3] and { [key] = args[3] } or nil)
    end
    if verb == "list" then
        local lines = {}
        for _, aid in ipairs(order) do
            local a = registry[aid]
            if a then lines[#lines + 1] = string.format("%s (%s): %s, %d playing", a.label, a.id, a.status.phase, a.status.players) end
        end
        return true, #lines > 0 and table.concat(lines, " · ") or "No activity is running."
    end
    if verb ~= nil then return false end
    local e, q = owned[source], pending[source]
    if e then return true, "In " .. labelOf(e.activity) .. ". /leave to come back." end
    if q then return true, "Queued for " .. labelOf(q.activity) .. ". /leave to drop out." end
    local ok, why = check(source)
    return true, ok and "Free for an activity: The Crossing, or the Neural-Link app Gigs & Arena." or why
end)

-- Staff bot mode: one player can start every activity, the providers fill the rest with
-- bots, and no result is recorded. Off at every start; never leave it on with players.
A.botsEnabled = false
function A.setBots(on, by)
    on = on == true
    if A.botsEnabled == on then return false end
    A.botsEnabled = on
    LightRP.log("activities: bot mode %s (%s)", on and "ON" or "off", tostring(by or "console"))
    emit(EV.bots, on)
    dirty()
    return true
end

LightRP.command("lightrp.bots", { restricted = true, usage = "/lightrp.bots [on|off]" }, function(source, args)
    local value = tostring(args and args[1] or ""):lower()
    if value == "on" or value == "off" then A.setBots(value == "on", source) end
    if value ~= "" and value ~= "on" and value ~= "off" then return false, "usage: /lightrp.bots [on|off]" end
    return true, A.botsEnabled
        and "Bot mode ON: every activity starts with you alone and bots fill the other places. Results are not recorded. /lightrp.bots off when done."
        or "Bot mode off: activities need their real players again."
end)

LightRP.command("lightrp.activities", { restricted = true, usage = "/lightrp.activities" }, function()
    local lines = {}
    for _, aid in ipairs(order) do
        local a = registry[aid]
        if a then
            local names = {}
            for id, e in pairs(owned) do if e.activity == aid then names[#names + 1] = string.format("%s (%d)", e.identity.name, id) end end
            for id, q in pairs(pending) do if q.activity == aid then names[#names + 1] = string.format("%d queued", id) end end
            lines[#lines + 1] = string.format("%s [%s] %s %d/%d: %s", aid, a.resource, a.status.phase, a.status.players, a.maxPlayers,
                #names > 0 and table.concat(names, ", ") or "nobody")
        end
    end
    local missions = 0
    for _, raw in ipairs(GetPlayers()) do local id = pid(raw); if id and internalOwner(id) == "missions" then missions = missions + 1 end end
    lines[#lines + 1] = string.format("missions (internal): %d operator(s)", missions)
    return true, table.concat(lines, " | ")
end)

-- ---------------------------------------------------------------------------
-- Upkeep: watchers, late results, stale requests, leaderboards.

CreateThread(function()
    local sinceTops = 0
    while true do
        Wait(5000)
        local t = now()
        for id, entries in pairs(recent) do
            for aid, e in pairs(entries) do if t - (e.leftAt or t) > C.resultGraceMs then entries[aid] = nil end end
            if next(entries) == nil then recent[id] = nil end
        end
        for id, q in pairs(pending) do
            if t - q.at > PENDING_MS then pending[id] = nil; emit(EV.leaveRequest, id, q.activity); touch(id) end
        end
        sinceTops = sinceTops + 5000
        if sinceTops >= (C.leaderboard.refreshMs or 60000) then
            sinceTops = 0
            for _, aid in ipairs(order) do refreshTop(aid) end
        end
    end
end)

-- Providers started before Light RP (or kept running across its restart) register again.
CreateThread(function()
    Wait(500)
    emit(EV.ready)
end)
