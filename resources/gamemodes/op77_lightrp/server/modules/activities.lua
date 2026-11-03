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
--                                               opts.difficulty: the reputation tier too)
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
-- one the player's tier allows.
-- Events, TriggerEvent / AddEventHandler only (never network events):
--   provider -> core  op77_lightrp:activity:result  (playerId, activityId, result)
--   provider -> core  op77_lightrp:activity:status  (activityId, status)
--   core -> provider  op77_lightrp:activity:join    (playerId, activityId, options)
--   core -> provider  op77_lightrp:activity:leaveRequest (playerId, activityId)
--   core -> provider  op77_lightrp:activity:dropped (playerId, activityId, reason)
--   core -> provider  op77_lightrp:activity:ready   ()  Light RP (re)started: register again
--   core -> provider  op77_lightrp:activity:bots    (enabled)  staff bot mode toggled
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

A.registry, A.owned = registry, owned

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
                modes[#modes + 1] = { id = m.id, label = clean(m.label, 32) or m.id }
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
    return { id = id, resource = resource, label = label, kind = def.kind, description = clean(def.description, 280) or "",
        minPlayers = minPlayers, maxPlayers = maxPlayers, caps = caps, modes = modes, modeKey = modeKey,
        pve = pve, difficulties = difficulties, weight = weight }
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
-- one queued from the panel, else the first offered; refused above the tier.
local function entryDifficulty(id, a, opts)
    if not a.pve then return nil end
    local q = pending[id]
    local wanted = a.difficulties and type(opts) == "table" and type(opts.difficulty) == "string" and opts.difficulty or nil
    if wanted == nil and q and q.activity == a.id then wanted = q.difficulty end
    if wanted == nil then wanted = offered(a)[1] end
    local allowed, why = difficultyAllowed(id, a, wanted)
    if not allowed then return nil, why end
    return wanted
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
    local difficulty, refused = entryDifficulty(id, a, opts)
    if refused then return false, refused end
    local point = here(id)
    if not point then return false, "Your position is not available yet." end
    local who, c = identity(id)
    tokenSeq = tokenSeq + 1
    e = { token = tokenSeq, activity = a.id, resource = a.resource, generation = a.generation, caps = a.caps,
        returnPoint = point, identity = who, character = c, enteredAt = now(),
        pve = a.pve, difficulty = difficulty, difficulties = a.pve and offered(a) or nil, weight = a.weight }
    owned[id] = e
    -- queued elsewhere (a provider's own command entered them): that queue lets go
    local q = pending[id]
    pending[id], leaving[id] = nil, nil
    if q and q.activity ~= a.id then emit(EV.leaveRequest, id, q.activity) end
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
    LightRP.log("activities: %s (%d) entered %s%s, return point %.1f %.1f %.1f bucket %d",
        who.name, id, a.id, difficulty and (" (" .. difficulty .. ")") or "", point.x, point.y, point.z, point.bucket)
    -- modules that depend on the kind of play (cyberware in PvP) hear about it
    LightRP.eachModule("onActivityChanged", id, a.id, { pve = a.pve, kind = a.kind, difficulty = difficulty })
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
    SetTimeout(3000, function()
        if A.owns(id) or not LightRP.armament or type(LightRP.armament.synchronize) ~= "function" then return end
        local ok, done, why = pcall(LightRP.armament.synchronize, id)
        if not ok or done == false then LightRP.log("activities: weapons of %d not restored (%s)", id, tostring(ok and why or done)) end
    end)
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

function A.requestJoin(id, activityId, from, extra)
    local a = type(activityId) == "string" and registry[activityId] or nil
    if not a then return false, "That activity is not available." end
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
    local squad
    local P = LightRP.parties
    local party = P and type(P.of) == "function" and P.of(id)
    if party then squad = { id = party.id, leader = party.leader, members = copy(party.members) } end
    pending[id] = { activity = a.id, at = now(), difficulty = difficulty }
    options.from, options.squad = clean(from, 24) or "panel", squad
    if not emit(EV.join, id, a.id, options) then
        pending[id] = nil
        return false, a.label .. " did not answer. Try again in a moment."
    end
    touch(id)
    if owned[id] then return true, "Joining " .. a.label .. "." end
    return true, "Request sent to " .. a.label .. "."
end

function A.requestLeave(id)
    local e = owned[id]
    if e then
        local label = labelOf(e.activity)
        if leaving[id] and leaving[id].token == e.token then return true, "Leaving " .. label .. "..." end
        leaving[id] = { token = e.token, at = now() }
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
            if r.difficulty and DIFFS[r.difficulty] then parts[#parts + 1] = DIFFS[r.difficulty].label end
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
    -- PvE only, at the difficulty the player's tier allows (docs/pve-progression.md)
    r.reputation, r.difficulty = reputationAsk(id, e, r)
    if A.botsEnabled or result.test == true then
        -- staff testing with bots: nothing earned, nothing ranked
        LightRP.log("activities: test result %s for %d not recorded (placement %s, won %s)", e.activity, id,
            tostring(r.placement), tostring(r.won))
        return true
    end
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
    -- opts.difficulty: may this player play it (a PvE activity's tier gate)?
    local a = activityId and registry[activityId]
    if a and a.pve and type(opts) == "table" and opts.difficulty ~= nil then
        return difficultyAllowed(id, a, opts.difficulty)
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
    local P = LightRP.parties
    local squad = P and type(P.of) == "function" and P.of(id) or nil
    local range = (tonumber(C.nearbyRange) or 15) ^ 2
    for _, raw in ipairs(GetPlayers()) do
        local other = pid(raw)
        if other and other ~= id and LightRP.characters.isRegistered(other) then
            local p = Open77.players.position(other)
            if p and (p.bucket or 0) == (me.bucket or 0) then
                local d2 = (p.x - me.x) ^ 2 + (p.y - me.y) ^ 2 + (p.z - me.z) ^ 2
                if d2 <= range then
                    local theirs = P and P.of(other) or nil
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
            local tab = (payload.tab == "contracts" or payload.tab == "squad") and payload.tab or "activities"
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
