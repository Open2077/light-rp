-- op77_arena: player-versus-player inside the arena, the Light RP way. Loaded last.
--
-- WHY THIS FILE EXISTS. The Deathmatch engine was written for Freeroam, whose
-- combat.lua switches friendly fire ON for the whole host (`setFriendlyFire(true)`;
-- even with Freeroam PvP disabled it stays on while Deathmatch runs). The engine's
-- own `applyCombatPolicy` was never called here, so hosted on Light RP -- where
-- global PvP is OFF by design (the platform default) and must stay off -- the
-- platform refused every player-to-player hit in Combat Zone, Blade Night, Team
-- Arena, duels and Arena Night with `friendly_fire_disabled`, before main.lua's
-- arbiter ever saw it. The PvE Combat Zone never needed PvP: its bots are NPCs.
--
-- THE FIX IS A COMBAT SCOPE PER PVP INSTANCE (`Open77.combat.createScope`,
-- permission `combat.scope.control`), exactly as op77_turf does for a war: the
-- explicit roster of PEOPLE fighting in one arena bucket may hurt each other, and
-- nobody else gains anything. Never `setFriendlyFire(true)`: that would open PvP
-- in every street of the city. The platform keeps all its other rules for scoped
-- hits -- teams (`Open77.combat.setTeam`: Team Arena sides, duel corners), life,
-- god mode, and every Lua arbiter: main.lua's instance damage gate still vetoes a
-- cross-instance hit, the round state, the weapon and the spawn shield.
--
-- Platform rules (api.json `Open77.combat.createScope`, and the server's
-- DamageAuthorityService.CombatScopes):
--   * 2..32 unique player ids, each combat-capable (alive or recovering) in the
--     bucket at creation; a player is in one scope at most (`player_scoped`);
--   * 64 scopes on the host, 8 per resource (`scope_limit`);
--   * a bucket change or a disconnect drops a participant, and the scope goes by
--     itself under two; a resource stop releases all of its scopes;
--   * there is no "add a player": a roster change is removeScope + createScope.
--   A death in the same bucket does NOT drop a participant, so a scope survives
--   the respawns of a free-for-all and the eliminations of a team round.
--
-- LIFECYCLE (one scope per open PvP instance, bots never in it: they are NPCs):
--   sync    every 500 ms, per open PvP instance. Present = the humans attached to
--           the instance whose life record is in its bucket; wanted = those already
--           in the scope (dead or not) plus those combat-capable now. Wanted ~= the
--           scope's roster (a join, a departure, a respawn after a rebuild, a bucket
--           change) or the kernel attached/detached someone -> rebuild with the
--           combat-capable ones. Under two people -> no scope. Every `refreshMs` a
--           rebuild anyway (only while everyone present can be in it), to heal a
--           removal this file could not see.
--   close   `Deathmatch.onInstanceClosed` (chained) and the tick: removeScope.
--   stop    onResourceStop: removeScope for each (the platform releases them too).
--   budget  the platform's 8 per resource. Every open Combat Zone / Blade Night
--           instance holds a slot (people drop in at any time), and so does every
--           match with two people or more. A PvP instance beyond the budget is NOT
--           opened: `Deathmatch.instances.open` answers nil, "pvp_scope_limit"
--           (logged once per streak), the joiner is told the arena is full, a team
--           queue keeps waiting, a duel "could not start". PvE is never counted.
--   refusal a creation the platform refuses (another resource took the last host
--           slots, a player mid-transition...) is logged once per instance and
--           reason, retried every `retryMs`, and told to the instance's players if
--           it lasts `tellAfterMs`: never a silent match nobody can win.
--
-- TIME TO KILL. The engine's host-global multipliers (`Config.combat`, damage 0.55,
-- headshot 2.0) are Freeroam's and are NOT applied: they would change PvP damage
-- server-wide (Dogtown, turf). `LightRpArena.pvp.damageMultiplier` /
-- `.headshotMultiplier` scale person-on-person hits inside PvP instances only, by
-- returning the new amount from a damage arbiter (applied after the platform's own
-- multipliers). Both are 1.0: Light RP fighters keep their armor and implants in the
-- arena, unlike Freeroam's, so Freeroam's 0.55 would roughly double the time to kill.

local DM = Deathmatch
local L = LightRpArena
local H = ArenaHost

ArenaPvp = {}
local P = ArenaPvp

local PLATFORM_PER_RESOURCE = 8   -- DamageAuthorityService.MaximumCombatScopesPerOwner
local PLATFORM_MAX_PLAYERS = 32   -- DamageAuthorityService.MaximumCombatScopePlayers

P.scopes = {}   -- instance id -> { id, instance, bucket, players = { [id] = true }, list, atMs }
P.books = {}    -- instance id -> { dirty, announced, rebuilds, refusal, retryAtMs, logged = {}, told }
P.stopped = false
P.openRefusal = nil -- the open refused for the budget, said once per streak

local function now() return DM.nowMs() end
local function log(text) DM.log("pvp: " .. tostring(text)) end
local function cfg() return L.pvp or {} end
local function cfgNumber(key, default)
    local value = tonumber(cfg()[key])
    if value == nil or value ~= value then return default end
    return value
end

--- Scope slots this resource may hold: the configured number, never above the
--- platform's 8 (beyond it the platform refuses with `scope_limit` anyway).
function P.budget()
    return math.max(0, math.min(PLATFORM_PER_RESOURCE, math.floor(cfgNumber("scopesPerResource", PLATFORM_PER_RESOURCE))))
end

function P.maxPlayers()
    return math.max(2, math.min(PLATFORM_MAX_PLAYERS, math.floor(cfgNumber("maxScopePlayers", PLATFORM_MAX_PLAYERS))))
end

--- PvP = every arena ruleset but the PvE Combat Zone (players against NPC bots).
function P.isPvpSpec(format, ruleset)
    return (ruleset or "standard") ~= "pve"
end

function P.isPvp(instance)
    return type(instance) == "table" and not instance.closed
        and instance.ruleset ~= "pve" and instance.kind ~= "pve"
end

local function bookOf(instance)
    local book = P.books[instance.id]
    if book == nil then
        book = { logged = {}, rebuilds = 0 }
        P.books[instance.id] = book
    end
    return book
end

-- ------------------------------------------------------------------ budget --

--- Does this open instance hold one of the resource's scope slots? A drop-in
--- free-for-all always does (a second person can walk in at any moment); a match
--- does once it has two people; any instance does while it holds a scope.
function P.holdsSlot(instance)
    if not P.isPvp(instance) then return false end
    if P.scopes[instance.id] ~= nil then return true end
    if instance.format == "ffa" then return true end
    return #DM.instances.humans(instance) >= 2
end

function P.slotsInUse()
    local used = 0
    for _, instance in pairs(DM.instances.registry) do
        if P.holdsSlot(instance) then used = used + 1 end
    end
    return used
end

-- --------------------------------------------------------------- platform --

local function removeQuietly(scopeId)
    if scopeId == nil or type(Open77.combat) ~= "table" or type(Open77.combat.removeScope) ~= "function" then
        return false
    end
    -- `scope_unavailable`: the platform already dropped it (fewer than two left
    -- after a disconnect or a bucket change). Nothing to undo either way.
    local ok, done = pcall(Open77.combat.removeScope, scopeId)
    return ok and done == true
end

local function create(bucket, list)
    if type(Open77.combat) ~= "table" or type(Open77.combat.createScope) ~= "function" then
        return nil, "scope_api_unavailable"
    end
    local ok, scope, why = pcall(Open77.combat.createScope, { bucket = bucket, players = list })
    if not ok then return nil, tostring(scope) end
    if type(scope) ~= "string" or scope == "" then return nil, tostring(why or "refused") end
    return scope
end

-- ------------------------------------------------------------------ roster --

local function phaseOf(life)
    return (tostring(life.phase or ""):gsub("_", ""))
end

--- The people who count for this instance's scope right now. `present`: attached
--- and standing in its bucket (set); `capable`: those of them alive or recovering,
--- in arrival order -- the only ones a creation accepts.
function P.roster(instance)
    local present, capable = {}, {}
    for _, id in ipairs(DM.instances.humans(instance)) do
        local ok, life = pcall(Open77.players.getLifeState, id)
        if ok and type(life) == "table" then
            local bucket = tonumber(life.bucket)
            if bucket == nil or bucket == instance.bucket then
                present[id] = true
                local phase = phaseOf(life)
                if phase == "alive" or phase == "recovering" then capable[#capable + 1] = id end
            end
        end
    end
    return present, capable
end

local function sameSet(a, b)
    for id in pairs(a) do if not b[id] then return false end end
    for id in pairs(b) do if not a[id] then return false end end
    return true
end

local function count(set)
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
end

local function rosterKey(list)
    local sorted = {}
    for index, id in ipairs(list) do sorted[index] = id end
    table.sort(sorted)
    return table.concat(sorted, ",")
end

-- --------------------------------------------------------------- refusals --

local function tellInstance(instance, book)
    if book.told then return end
    book.told = true
    for _, id in ipairs(DM.instances.humans(instance)) do
        DM.notice(id, "warning", "pvpUnavailable")
    end
end

local function refused(instance, book, why, key, t)
    local streak = book.refusal
    if streak == nil or streak.reason ~= why then
        book.refusal = { reason = why, key = key, sinceMs = (streak and streak.sinceMs) or t }
    else
        streak.key = key
    end
    book.retryAtMs = t + math.max(250, cfgNumber("retryMs", 2000))
    if not book.logged[why] then
        book.logged[why] = true
        log(("instance %d (%s) bucket %d: PvP scope refused (%s) for players %s -- no player damage until it is created"):format(
            instance.id, tostring(instance.format), instance.bucket, tostring(why), key))
    end
    if t - book.refusal.sinceMs >= math.max(0, cfgNumber("tellAfterMs", 10000)) then tellInstance(instance, book) end
end

-- -------------------------------------------------------------- lifecycle --

--- Drops the instance's scope, if any. `final`: the instance is gone (closed,
--- resource stop): its bookkeeping goes too.
function P.release(instance, reason, final)
    local id = type(instance) == "table" and instance.id or instance
    if id == nil then return false end
    local held = P.scopes[id]
    P.scopes[id] = nil
    if held ~= nil then removeQuietly(held.id) end
    local book = P.books[id]
    if final then
        if book ~= nil and book.announced then
            log(("instance %d: PvP scope closed (%s) after %d build(s)"):format(id, tostring(reason), book.rebuilds or 0))
        end
        P.books[id] = nil
    end
    return held ~= nil
end

--- Replaces the instance's scope with one over `capable` (the platform has no
--- "add a player"). Under two people, the instance simply has no scope.
function P.rebuild(instance, capable, t, book)
    local held = P.scopes[instance.id]
    P.scopes[instance.id] = nil
    if held ~= nil then removeQuietly(held.id) end
    book.dirty = nil

    local max = P.maxPlayers()
    local list = {}
    for index = 1, math.min(#capable, max) do list[index] = capable[index] end
    if #capable > max and not book.logged.too_many then
        book.logged.too_many = true
        log(("instance %d: %d people, the scope takes the first %d (platform limit)"):format(instance.id, #capable, max))
    end
    if #list < 2 then
        book.refusal, book.told = nil, nil
        return nil
    end

    local key = rosterKey(list)
    local scope, why = create(instance.bucket, list)
    if scope == nil then
        refused(instance, book, why, key, t)
        return nil
    end
    local set = {}
    for _, id in ipairs(list) do set[id] = true end
    P.scopes[instance.id] = { id = scope, instance = instance, bucket = instance.bucket, players = set, list = list, atMs = t }
    book.rebuilds = (book.rebuilds or 0) + 1
    if not book.announced then
        book.announced = true
        log(("instance %d (%s) bucket %d: PvP scope opened for %d players (%s)"):format(
            instance.id, tostring(instance.format), instance.bucket, #list, key))
    elseif book.refusal ~= nil then
        log(("instance %d: PvP scope restored after %s (%s)"):format(instance.id, tostring(book.refusal.reason), key))
    end
    book.refusal, book.told = nil, nil
    return scope
end

--- Brings one instance's scope in line with who is fighting in it.
function P.sync(instance, t, force)
    if type(instance) ~= "table" then return nil end
    t = t or now()
    if not P.isPvp(instance) then
        P.release(instance, "not_pvp", instance.closed == true)
        return nil
    end
    local book = bookOf(instance)
    local present, capable = P.roster(instance)
    local held = P.scopes[instance.id]

    -- Wanted: who the scope should hold -- those already in it who are still here
    -- (a death keeps them in it), plus everyone who can fight now.
    local wanted = {}
    if held ~= nil then
        for id in pairs(held.players) do if present[id] then wanted[id] = true end end
    end
    for _, id in ipairs(capable) do wanted[id] = true end

    if held == nil and #capable < 2 then
        book.dirty, book.refusal, book.told = nil, nil, nil
        return nil
    end
    if held ~= nil and not force and not book.dirty and sameSet(wanted, held.players) then
        -- The periodic heal, only while everyone present can be in the new scope:
        -- rebuilding over a dead fighter would drop him until he stands again.
        local refreshMs = math.max(1000, cfgNumber("refreshMs", 15000))
        if t - held.atMs < refreshMs or #capable < count(wanted) then return held.id end
    end
    if held == nil and not force and not book.dirty and book.refusal ~= nil
        and book.refusal.key == rosterKey(capable) and t < (book.retryAtMs or 0) then
        return nil
    end
    return P.rebuild(instance, capable, t, book)
end

function P.tick(t)
    if P.stopped then return end
    t = t or now()
    -- Scopes whose instance is gone (the close hook is the fast path).
    for id, held in pairs(P.scopes) do
        local instance = held.instance
        if instance.closed or DM.instances.registry[id] ~= instance then P.release(instance, "instance_closed", true) end
    end
    for id in pairs(P.books) do
        local instance = DM.instances.registry[id]
        if instance == nil or instance.closed then P.books[id] = nil end
    end
    for _, instance in pairs(DM.instances.registry) do
        if P.isPvp(instance) then P.sync(instance, t) end
    end
end

function P.shutdown(reason)
    P.stopped = true
    for id, held in pairs(P.scopes) do
        P.scopes[id] = nil
        removeQuietly(held.id)
    end
    P.books = {}
    log(("all PvP scopes released (%s)"):format(tostring(reason)))
end

--- One line per scope, for `deathmatch.status` / `/dm.instances`.
function P.describe()
    local parts = {}
    for id, held in pairs(P.scopes) do
        parts[#parts + 1] = ("#%d b=%d [%s]"):format(id, held.bucket, rosterKey(held.list))
    end
    table.sort(parts)
    for id, book in pairs(P.books) do
        if P.scopes[id] == nil and book.refusal ~= nil then
            parts[#parts + 1] = ("#%d refused:%s"):format(id, tostring(book.refusal.reason))
        end
    end
    return ("%d/%d slot(s) used, %s"):format(P.slotsInUse(), P.budget(),
        #parts > 0 and table.concat(parts, " ") or "no scope")
end

-- ------------------------------------------------------------- the seams --

-- The budget gate: a PvP instance the resource could not give a scope is never
-- opened. Wraps whatever `Deathmatch.instances.open` is now (server/lightrp.lua's
-- Arena Night wrapper); `Instances.openArena` and `Instances.assignFFA` reach it
-- through the table, so every way in is gated.
local open = DM.instances.open
DM.instances.open = function(format, ruleset, ...)
    if P.isPvpSpec(format, ruleset) then
        local used, max = P.slotsInUse(), P.budget()
        if used >= max then
            local key = tostring(format) .. "/" .. tostring(ruleset or "standard")
            if P.openRefusal ~= key then
                P.openRefusal = key
                log(("%s refused: %d/%d PvP scope slots in use (8 per resource on the platform)"):format(key, used, max))
            end
            return nil, "pvp_scope_limit"
        end
    end
    local instance, reason = open(format, ruleset, ...)
    if instance ~= nil and P.isPvp(instance) then
        P.openRefusal = nil
        -- One scope holds 32 people at most: a PvP instance never takes more.
        local cap = tonumber(instance.capacity) or 0
        if cap <= 0 or cap > P.maxPlayers() then instance.capacity = P.maxPlayers() end
    end
    return instance, reason
end

-- A person attached to or detached from an instance: rebuild at the next sync even
-- if the roster looks the same (they may have left and come back between two).
local attach, detach = DM.instances.attach, DM.instances.detach
DM.instances.attach = function(instance, playerId)
    local done = attach(instance, playerId)
    if done and type(instance) == "table" and not instance.closed then bookOf(instance).dirty = true end
    return done
end
DM.instances.detach = function(playerId, reason)
    local instance = detach(playerId, reason)
    if type(instance) == "table" and not instance.closed then bookOf(instance).dirty = true end
    return instance
end

-- Chained, never replaced: whatever registered before still runs.
local closed = DM.onInstanceClosed
DM.onInstanceClosed = function(instance, reason)
    P.release(instance, reason, true)
    if closed ~= nil then return closed(instance, reason) end
end

local describe = DM.instances.describe
if type(describe) == "function" then
    DM.instances.describe = function(...)
        return tostring(describe(...)) .. " | pvp scopes: " .. P.describe()
    end
end

-- ------------------------------------------------------------ time to kill --

--- The scaled amount of a person-on-person hit inside a PvP instance, or nil to
--- leave it alone. Bots, the city, PvE and self-damage are never touched.
function P.scaleDamage(event)
    if type(event) ~= "table" then return nil end
    local damage = cfgNumber("damageMultiplier", 1.0)
    local headshot = cfgNumber("headshotMultiplier", 1.0)
    local factor = damage
    if event.bodyPart == "head" then factor = factor * headshot end
    if factor == 1.0 or factor < 0 then return nil end
    local victim, attacker = DM.playerId(event.victim), DM.playerId(event.attacker)
    if victim == nil or attacker == nil or victim <= 0 or attacker <= 0 or victim == attacker then return nil end
    local instance = DM.instances.of(victim)
    if not P.isPvp(instance) or DM.instances.of(attacker) ~= instance then return nil end
    local amount = tonumber(event.amount)
    if amount == nil then return nil end
    return amount * factor
end

-- Registered only when a multiplier is not 1.0: the arbiter runs for every damage
-- candidate on the host, so an arbiter with nothing to do is not installed.
if cfgNumber("damageMultiplier", 1.0) ~= 1.0 or cfgNumber("headshotMultiplier", 1.0) ~= 1.0 then
    Open77.combat.onDamage(function(event)
        local ok, amount = pcall(P.scaleDamage, event)
        if ok then return amount end
        return nil
    end)
end

-- ------------------------------------------------------------------- life --

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    P.shutdown("resource_stop")
end)

CreateThread(function()
    while not P.stopped and not (H and H.stopped) do
        Wait(500)
        local ok, err = pcall(P.tick)
        if not ok then log("tick failed: " .. tostring(err)) end
    end
end)
