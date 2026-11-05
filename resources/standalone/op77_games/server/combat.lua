-- PvP for the games: one combat scope per pvp match (never setFriendlyFire: that would open
-- PvP in every street), the damage arbiter, the weapon sets.
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
local versions = {} -- playerId -> issue version: a verdict for an older issue is dropped
local pending = {}  -- tostring(request id) -> { playerId, p, version, step, spec, slot, retries, atMs }
local PENDING_TTL_MS = 15000 -- no answer at all (the relay itself times out at 10 s): a timeout
-- The source's retry (core/server/weapons.lua): about 20 s of backoff while the owner is busy.
local MAX_RETRIES = 6
local BACKOFF_MS = { 750, 1500, 3000, 5000, 5000, 5000 }
local DRAW_RETRY_MS = 750
local BUSY = { request_timeout = true, queue_full = true, player_unavailable = true, script_bridge_unavailable = true,
    network_unavailable = true, clear_in_progress = true }
local DRAW = { weapon_not_drawn = true, weapon_slot_empty = true, activation_rejected = true } -- slot 1 on its way to the hand

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

local function bump(id)
    versions[id] = (versions[id] or 0) + 1
    return versions[id]
end

local function ammoOptions(spec, activate)
    local reserve = tonumber(spec.reserve)
    if reserve == nil or reserve <= 0 then return nil end
    -- Reserve only, never a magazine: setAmmo fails as a whole when one exceeds capacity.
    return { reserve = math.floor(reserve), activate = activate == true }
end

local function track(requestId, info)
    if requestId == nil then return end
    info.atMs = E.now()
    pending[tostring(requestId)] = info
end

-- Still worth asking: the same issue, and a weapon of a match only while its player is in it.
-- A removal outlives the match: it belongs to the way back.
local function current(info)
    if versions[info.playerId] ~= info.version then return false end
    if info.step == "remove" then return true end
    local match = E.matchOf(info.playerId)
    return match ~= nil and match.players[info.playerId] == info.p
end

local function transient(info, reason)
    if info.step == "remove" then return reason ~= "weapon_slot_empty" end -- empty is done
    return BUSY[reason] == true or (info.slot == 1 and DRAW[reason] == true)
end

local send = {} -- step -> sends this request

-- A refused request, answered or not: asked again, a bounded number of times, then final.
-- The primary that never came is told, as the arena does: until then it is a silent match.
local function failed(info, reason)
    local retries = info.retries or 0
    if transient(info, reason) and retries < MAX_RETRIES then
        info.retries = retries + 1
        local busy = BUSY[reason] or info.step == "remove"
        SetTimeout(busy and BACKOFF_MS[info.retries] or DRAW_RETRY_MS, function()
            if current(info) then send[info.step](info) end
        end)
        return
    end
    E.log(("%s failed for %d slot %s: %s"):format(info.step, info.playerId, tostring(info.slot), tostring(reason)))
    local match = E.matchOf(info.playerId)
    if match and info.step == "assign" and info.slot == 1 then
        GamesActivity.notice(info.playerId, "error", match.def.label, "Your weapon could not be equipped.")
    end
end

function send.setAmmo(info)
    local requestId, why = Open77.weapons.setAmmo(info.playerId, info.slot, ammoOptions(info.spec, info.activate))
    if requestId == nil then return failed(info, why) end
    track(requestId, info)
end

function send.assign(info)
    local spec = info.spec
    local requestId, why = Open77.weapons.assign(info.playerId, spec.record, spec.slot, { active = spec.slot == 1, addToInventory = true })
    if requestId == nil then return failed(info, why) end
    track(requestId, info)
end

-- Does this slot still hold what we gave? The way back hands the RP weapons to these same
-- slots, so a late removal touches only our record. nil: the cache cannot tell.
local function slotHoldsOurs(info)
    local ok, read = pcall(Open77.weapons.get, info.playerId)
    if not ok or type(read) ~= "table" or type(read.slots) ~= "table" then return nil end
    for _, row in ipairs(read.slots) do
        if type(row) == "table" and row.slot == info.slot then return row.record == info.record end
    end
    return false
end

function send.remove(info)
    if (info.retries or 0) > 0 then
        if GamesActivity.owner(info.playerId) ~= nil then return end -- another activity owns these slots now
        local ours = slotHoldsOurs(info)
        if ours == false then return end
        if ours == nil then return failed(info, "weapons_unreported") end
    end
    local ok, requestId, why = pcall(Open77.weapons.remove, info.playerId, info.slot)
    if not ok or requestId == nil then return failed(info, ok and why or tostring(requestId)) end
    track(requestId, info)
end

local function requestAmmo(p, version, spec, activate)
    if ammoOptions(spec, activate) == nil then return end
    send.setAmmo({ playerId = p.id, p = p, version = version, step = "setAmmo", slot = spec.slot, spec = spec, activate = activate })
end

local function requestAssign(p, version, spec)
    send.assign({ playerId = p.id, p = p, version = version, step = "assign", slot = spec.slot, spec = spec })
end

-- Holster, clear the slots, 250 ms (the removals are asynchronous: assigning into a slot
-- being torn down loses the weapon silently), then the set, slot 1 last so it ends in hand.
-- A verified id comes back on open77:weapons:completed; until then this player's shots
-- are refused: a weapon that never verified cannot land damage.
function C.arm(match, p, weapons)
    local version = bump(p.id)
    p.armed, p.plan, p.verified = true, weapons, {}
    Open77.weapons.holster(p.id)
    for slot = 1, 3 do Open77.weapons.remove(p.id, slot) end
    SetTimeout(250, function()
        if E.matchOf(p.id) ~= match or versions[p.id] ~= version then return end
        for index = #weapons, 1, -1 do requestAssign(p, version, weapons[index]) end
    end)
end

-- Ammunition back after a respawn: reserve only, nothing drawn, the weapons stay.
function C.resupply(p)
    if not p.armed or type(p.plan) ~= "table" then return end
    for _, spec in ipairs(p.plan) do requestAmmo(p, versions[p.id] or 0, spec, false) end
end

-- Takes back what we gave: never touches someone we never armed (their RP weapons), and
-- the team comes off. Safe on every way out. A dead body may refuse the removal of a weapon
-- of ours: that one is asked again through the player's return, see send.remove.
function C.disarm(p)
    if p.teamed then
        p.teamed = nil
        if type(Open77.combat) == "table" and type(Open77.combat.setTeam) == "function" then pcall(Open77.combat.setTeam, p.id, 0) end
    end
    if not p.armed then return end
    local given = {}
    for _, spec in ipairs(type(p.plan) == "table" and p.plan or {}) do given[spec.slot] = spec.record end
    p.armed, p.plan, p.verified = nil, nil, nil
    local version = bump(p.id)
    pcall(Open77.weapons.holster, p.id)
    for slot = 1, 3 do
        if given[slot] then send.remove({ playerId = p.id, version = version, step = "remove", slot = slot, record = given[slot] })
        else pcall(Open77.weapons.remove, p.id, slot) end
    end
end

function C.forget(id) versions[id] = nil end

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

AddEventHandler("open77:weapons:completed", function(playerId, requestId, operation, accepted, reason, result)
    local key = tostring(requestId)
    local info = pending[key]
    if info == nil then return end -- another resource's request, or one we do not track
    pending[key] = nil
    if E.playerId(playerId) ~= info.playerId or info.step ~= operation then return end
    if not current(info) then return end
    if accepted ~= true then return failed(info, reason) end
    if operation ~= "assign" then return end
    local verified = normalize(type(result) == "table" and result.tweakDbId or nil)
    local p = info.p
    if verified ~= "" and type(p.verified) == "table" then p.verified[info.slot] = verified end
    requestAmmo(p, info.version, info.spec, info.slot == 1)
    -- Slot 1 is the last assign issued: the set has landed, the primary goes in hand.
    if info.slot == 1 and Open77.weapons.setActive ~= nil then Open77.weapons.setActive(info.playerId, 1) end
end)

function C.sweep(t)
    for key, info in pairs(pending) do
        if t - (info.atMs or t) > PENDING_TTL_MS then
            pending[key] = nil
            if current(info) then failed(info, "request_timeout") end
        end
    end
end

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
