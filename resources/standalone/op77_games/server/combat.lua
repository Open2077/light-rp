-- PvP for the games: one combat scope per pvp match (never setFriendlyFire: that would open
-- PvP in every street), the damage arbiter, and the mode's kit through Light RP's contract
-- (activityKit, the temporary kit of a mission): the core hands it, verifies it, draws it
-- from the wheel and takes it back at every exit. No weapon request starts here.
--
-- Scope rules (DamageAuthorityService, see op77_arena/server/pvp.lua): 2..32 unique players,
-- alive in the bucket at creation; one scope per player; 8 per resource, 64 on the host; a
-- bucket change or a disconnect drops a participant, under two the scope goes; no "add a
-- player": a roster change is remove + create. A death keeps a participant in it.
-- Every open pvp match holds a slot from E.open on: no slot, no match.
local Config = GamesConfig
local E = GamesEngine

GamesCombat = {}
local C = GamesCombat

C.scopes = {} -- match id -> { id, players = { [id] = true }, list, atMs }
local books = {}    -- match id -> { dirty, refusal = { reason, key, sinceMs }, retryAtMs, told }

-- ---------------------------------------------------------------- budget --

function C.budget() return math.max(0, math.min(8, Config.scopes.perResource)) end

function C.free()
    local used = 0
    for _, match in pairs(E.matches) do
        if match.def.pvp and not match.closed then used = used + 1 end
    end
    return C.budget() - used
end

-- ---------------------------------------------------------------- scopes --

local function removeQuietly(scopeId)
    if scopeId == nil or type(Open77.combat) ~= "table" or type(Open77.combat.removeScope) ~= "function" then return end
    pcall(Open77.combat.removeScope, scopeId) -- scope_unavailable: the platform already dropped it
end

local function create(bucket, list)
    if type(Open77.combat) ~= "table" or type(Open77.combat.createScope) ~= "function" then return nil, "scope_api_unavailable" end
    local ok, scope, why = pcall(Open77.combat.createScope, { bucket = bucket, players = list })
    if not ok then return nil, tostring(scope) end
    if type(scope) ~= "string" or scope == "" then return nil, tostring(why or "refused") end
    return scope
end

local function bookOf(match)
    local book = books[match.id]
    if book == nil then
        book = {}
        books[match.id] = book
    end
    return book
end

-- `present`: landed and in the bucket; `capable`: those of them who can be in a new scope.
local function roster(match)
    local present, capable = {}, {}
    for _, p in ipairs(E.members(match)) do
        local ok, life = pcall(Open77.players.getLifeState, p.id)
        if p.landed and ok and type(life) == "table" then
            local bucket = tonumber(life.bucket)
            if bucket == nil or bucket == match.bucket then
                present[p.id] = true
                local phase = tostring(life.phase or ""):gsub("_", "")
                if phase == "alive" or phase == "recovering" then capable[#capable + 1] = p.id end
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
local function keyOf(list)
    local sorted = table.move(list, 1, #list, 1, {})
    table.sort(sorted)
    return table.concat(sorted, ",")
end

local function refused(match, book, why, key, t)
    local streak = book.refusal
    if streak == nil then
        book.refusal = { reason = why, key = key, sinceMs = t }
        E.log(("%s: PvP scope refused (%s) for %s"):format(match.id, tostring(why), key))
    else
        streak.reason, streak.key = why, key
    end
    book.retryAtMs = t + Config.scopes.retryMs
    local age = t - book.refusal.sinceMs
    if age >= Config.scopes.giveUpMs then
        E.cancel(match, "The fight could not be opened. Nothing was recorded.")
    elseif age >= Config.scopes.tellAfterMs and not book.told then
        book.told = true
        E.banner(match, "NO DAMAGE YET", "The fight is not open yet.", "danger", 4000)
    end
end

local function rebuild(match, capable, t, book)
    local held = C.scopes[match.id]
    C.scopes[match.id] = nil
    if held then removeQuietly(held.id) end
    book.dirty = nil
    if #capable < 2 then
        book.refusal, book.told = nil, nil
        return nil
    end
    local key = keyOf(capable)
    local scope, why = create(match.bucket, capable)
    if scope == nil then return refused(match, book, why, key, t) end
    local set = {}
    for _, id in ipairs(capable) do set[id] = true end
    C.scopes[match.id] = { id = scope, players = set, list = capable, atMs = t }
    book.refusal, book.told = nil, nil
    return scope
end

-- Brings the match's scope in line with who is fighting. Wanted: those in it who are still
-- here (a death keeps them) plus everyone who can fight now.
function C.sync(match, t)
    local book = bookOf(match)
    if t < (book.nextAt or 0) then return end
    book.nextAt = t + Config.scopes.syncMs
    local present, capable = roster(match)
    local held = C.scopes[match.id]
    if held == nil and #capable < 2 then
        book.dirty, book.refusal, book.told = nil, nil, nil
        return
    end
    local wanted = {}
    if held then
        for id in pairs(held.players) do if present[id] then wanted[id] = true end end
    end
    for _, id in ipairs(capable) do wanted[id] = true end
    if held and not book.dirty and sameSet(wanted, held.players) then
        -- The periodic heal, only while everyone present fits a new scope: rebuilding over
        -- a dead fighter would drop him until he stands again.
        if t - held.atMs < Config.scopes.refreshMs or #capable < count(wanted) then return end
    end
    if held == nil and not book.dirty and book.refusal and book.refusal.key == keyOf(capable) and t < (book.retryAtMs or 0) then
        return
    end
    rebuild(match, capable, t, book)
end

-- The scope goes. `final`: the match is gone too.
function C.release(match, final)
    local held = C.scopes[match.id]
    C.scopes[match.id] = nil
    if held then removeQuietly(held.id) end
    if final then books[match.id] = nil end
end

function C.shutdown()
    for id, held in pairs(C.scopes) do
        C.scopes[id] = nil
        removeQuietly(held.id)
    end
end

-- ---------------------------------------------------------------- bodies --

-- A team goes on a body once it landed, and always comes off (C.disarm).
function C.join(match, p)
    if p.side and type(Open77.combat) == "table" and type(Open77.combat.setTeam) == "function" then
        pcall(Open77.combat.setTeam, p.id, p.side)
        p.teamed = true
    end
    if match.def.pvp then bookOf(match).dirty = true end
end

-- What this game hands out by default: its kit id of the config, or false for the kit
-- missions preselect. Light RP answers for an id it does not know.
function C.configured(key) return Config.kits[key] or false end

-- The kit of this body: nil, none; false, id or explicit table: see C.arm.
function C.kitOf(match, p)
    local kit = match.def.kit
    if type(kit) == "function" then return kit(match, p) end
    if kit == true then return C.configured(match.def.key) end
    return nil
end

-- Hands out a kit: a kit id of Light RP, an explicit kit, or false (the kit missions
-- preselect). It replaces the one held. Until the core reports a verified id this player's
-- shots are refused: a weapon that never verified cannot land damage.
function C.arm(match, p, kit, immediate)
    p.armed, p.plan, p.verified, p.hand = true, kit, {}, nil
    local ok, hand = GamesActivity.kit(p.id, match.def.id, kit or nil, immediate and { immediate = true } or nil)
    if ok == true then
        p.hand = hand
        return
    end
    E.log(("%d refused a kit in %s: %s"):format(p.id, match.id, tostring(hand)))
    GamesActivity.notice(p.id, "error", match.def.label, "Your weapon could not be equipped.")
end

-- After a respawn: the kit again, as a mission does. The body's kit stopped at the death.
function C.reissue(match, p)
    if not p.armed then return end
    local kit = C.kitOf(match, p)
    if kit == nil then kit = p.plan end
    C.arm(match, p, kit)
end

-- The team comes off, and the kit if we gave one: a body we never armed keeps its slots.
-- The core takes a kit back by itself at every exit, this is the way out it hears first.
function C.disarm(match, p)
    if p.teamed then
        p.teamed = nil
        if type(Open77.combat) == "table" and type(Open77.combat.setTeam) == "function" then pcall(Open77.combat.setTeam, p.id, 0) end
    end
    if not p.armed then return end
    local hand = p.hand
    p.armed, p.plan, p.verified, p.hand = nil, nil, nil, nil
    if hand == nil then return end
    local ok, why = GamesActivity.kitTake(p.id, match.def.id, { hand = hand })
    -- The core died: nobody else is left to empty these slots until it restarts.
    if not ok and tostring(why):find("^core_") then pcall(Open77.weapons.clear, p.id) end
end

-- TweakDB ids are 64-bit: the canonical form is a lowercase "0x..." string with leading
-- zeroes stripped, or two spellings of one weapon read like a cheat.
local function normalize(value)
    if type(value) ~= "string" then return "" end
    local digits = value:lower():match("^0x([0-9a-f]+)$")
    if digits == nil then return "" end
    digits = digits:gsub("^0+", "")
    if digits == "" then return "" end
    return "0x" .. digits
end

-- The slot of this player's set a reported weapon id is, or nil.
function C.slotOf(p, reported)
    reported = normalize(reported)
    if reported == "" or type(p.verified) ~= "table" then return nil end
    for slot, verified in pairs(p.verified) do
        if verified == reported then return slot end
    end
    return nil
end

function C.accepts(p, reported) return C.slotOf(p, reported) ~= nil end

-- The core's word on a kit (activities.lua): a verified id opens that weapon for the
-- arbiter, a kit that never came is told, as the arena does. An older hand is dropped.
AddEventHandler("op77_lightrp:activity:kit", function(playerId, activityId, report)
    local id = E.playerId(playerId)
    local match = id and E.matchOf(id)
    if match == nil or match.def.id ~= activityId or type(report) ~= "table" then return end
    local p = match.players[id]
    if p == nil or p.hand == nil or report.hand ~= p.hand then return end
    if report.state == "failed" then
        E.log(("kit never reached %d in %s"):format(id, match.id))
        GamesActivity.notice(id, "error", match.def.label, "Your weapon could not be equipped.")
        return
    end
    for _, row in ipairs(type(report.weapons) == "table" and report.weapons or {}) do
        local verified = type(row) == "table" and normalize(row.tweakDbId) or ""
        if verified ~= "" then p.verified[row.slot] = verified end
    end
end)

-- ---------------------------------------------------------------- damage --

-- Host-global: it sees every hit on the server, so a stranger to our matches passes
-- untouched and the instance goes first. false refuses; nil leaves the hit alone.
function C.arbiter(event)
    local victimId, attackerId = E.playerId(event.victim), E.playerId(event.attacker)
    local victimMatch = victimId and E.matchOf(victimId) or nil
    local attackerMatch = attackerId and E.matchOf(attackerId) or nil
    if victimMatch == nil and attackerMatch == nil then return nil end
    -- Nobody reaches into a match, nobody shoots out of one.
    if victimMatch == nil or (attackerId ~= nil and attackerMatch ~= victimMatch) then return false end
    local match = victimMatch
    if match.phase ~= "running" then return false end
    -- The environment and a fall: the match's own rules, no attacker to judge.
    if attackerId == nil or attackerId == victimId then
        if tonumber(event.attacker) ~= nil and tonumber(event.attacker) ~= 0 and attackerId == nil then return false end
        return nil
    end
    if not match.def.pvp then return false end
    local victim, attacker = match.players[victimId], match.players[attackerId]
    if victim.side ~= nil and victim.side == attacker.side then return false end
    if not victim.alive or not attacker.alive then return false end
    if not C.accepts(attacker, event.weaponTdbId) then return false end
    local t = E.now()
    if (victim.protectedUntil or 0) > t or (attacker.protectedUntil or 0) > t then return false end
    if match.def.damage then
        local ok, verdict = pcall(match.def.damage, match, event, attacker, victim)
        if not ok then E.log(("damage hook of %s failed: %s"):format(match.def.id, tostring(verdict))) end
        if not ok or verdict == false then return false end
    end
    victim.lastHitBy, victim.lastHitAt = attackerId, t
    return nil
end

if type(Open77.combat) == "table" and type(Open77.combat.onDamage) == "function" then
    Open77.combat.onDamage(C.arbiter)
end
