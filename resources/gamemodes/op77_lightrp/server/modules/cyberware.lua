-- Cyberware: what each character has under the skin, bought and installed at a ripperdoc
-- (op77_ripperdoc, opened from a ripperdoc chair by server/modules/ripperdoc.lua).
--
-- The catalogue is server/config/cyberware.lua (only implants the platform really applies),
-- plus its iconic implants (never sold: server/modules/cyberware_iconics.lua drops them).
-- Ownership is durable per character: what is fitted (lightrp_cyberware) and what waits in the
-- character's implant storage (lightrp_cyberware_stock). Effects are projected again on every
-- load, switch and respawn:
--   legs / arms -> Open77.cyberware durable implants (the platform's own record and receipts;
--                  the price is taken first and given back if the surgery fails)
--   blades      -> Mantis Blades on the arm slot, drawn with their own key (armament steps aside)
--   dash / slam / overdrive -> session grants (Open77.dash / abilities / reflex)
--   passive     -> health/stamina maxima and regeneration, armor, fall damage
--   berserk / pain / second_heart / optics -> server/modules/cyberware_active.lua
--
-- Capacity: every implant costs `capacity` points, the body holds C.capacity.byTier[street
-- cred tier]. The server refuses a fitting past it; a character already over it keeps what is
-- fitted and can only swap for something lighter until under it.
--
--   LightRP.cyberware.installed(playerId)  -> { [id] = true }   (fitted)
--   LightRP.cyberware.stored(playerId)     -> { [id] = true }   (in storage)
--   LightRP.cyberware.fitted(playerId, kind) -> the fitted item of that kind, nil while suspended
--   LightRP.cyberware.capacity(playerId)   -> { used, total (nil: no limit), over }
--   LightRP.cyberware.view(playerId)       -> the clinic payload (catalogue, installed, storage, capacity)
--   LightRP.cyberware.operate(playerId, op, itemId, done) -- op "install" | "remove"; done(ok, message)
--   LightRP.cyberware.store(playerId, itemId, source) -> true | false, reason (an implant into storage)
--   LightRP.cyberware.boost(playerId, name, healthRegen|nil) -- a timed regeneration layer
--   LightRP.cyberware.handlesLoadout(playerId) -> true while the Mantis Blades are drawn
--   hook onCyberwareChanged(playerId) after a load, a surgery, a suspension or its end
--
-- Street cred (docs/pve-progression.md): an implant's rank needs a reputation tier
-- (C.gating, tiers from server/modules/missions.lua) to be bought; the clinic shows it locked
-- below it. An implant already owned (in storage) needs only the capacity. With
-- C.activeInPvp = false, the session grants and passive stats stand down while the player is in
-- a non-PvE activity (hook onActivityChanged).
local C = LightRpCyberwareConfig
local Db = LightRP.db
local Cyber = LightRP.module("cyberware", {})

local ICONIC = type(C.iconics) == "table" and C.iconics or { items = {} }
local items, byId, catalogue = C.items, {}, {}
for _, item in ipairs(items) do byId[item.id] = item; catalogue[#catalogue + 1] = item end
for _, item in ipairs(ICONIC.items or {}) do item.iconic = true; byId[item.id] = item; catalogue[#catalogue + 1] = item end

Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_cyberware (
        identifier    VARCHAR(64) NOT NULL,
        character_key VARCHAR(32) NOT NULL,
        item          VARCHAR(48) NOT NULL,
        installed_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (identifier, character_key, item)
    )
]])
-- The implant storage: owned, not fitted (taken out at a clinic, replaced by a family mate,
-- an iconic drop). `source`: clinic | iconic:<source> | staff.
Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_cyberware_stock (
        identifier    VARCHAR(64) NOT NULL,
        character_key VARCHAR(32) NOT NULL,
        item          VARCHAR(48) NOT NULL,
        source        VARCHAR(48) NOT NULL DEFAULT 'clinic',
        acquired_at   TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (identifier, character_key, item)
    )
]])

-- The clinic guide (the ripperdoc page's walkthrough of capacity, street cred, storage and keys):
-- a row once the character finished or skipped it, so it opens by itself only on a first visit.
Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_cyberware_guide (
        identifier    VARCHAR(64) NOT NULL,
        character_key VARCHAR(32) NOT NULL,
        seen_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (identifier, character_key)
    )
]])

-- playerId -> { identifier, key, installed = {id=true}, stock = {id=true}, busy, drawn, baseline,
-- suspended, boosts = { name = healthRegen } }
local state = {}
local definitions = {}  -- "dash:basic" / "overdrive:street" / "slam" / "legs" / "arms" -> registered definition id
local GRANTS = { "dash", "overdrive", "slam" }

local function log(fmt, ...) LightRP.log("cyberware: " .. fmt, ...) end
local function now() return math.floor(Open77.time.monotonic() * 1000) end

local function notice(playerId, kind, title, body)
    LightRP.notice(playerId, { kind = kind, title = title, body = body, source = "RIPPERDOC" })
end

local function changed(playerId) LightRP.eachModule("onCyberwareChanged", playerId) end

function Cyber.item(id) return byId[id] end

-- ---------------------------------------------------------------------------
-- Street cred: the reputation tier a rank needs

local GATE = type(C.gating) == "table" and C.gating or { enabled = false }
function Cyber.requiredTier(item)
    if GATE.enabled == false or type(item) ~= "table" then return 1 end
    local need = tonumber(item.repTier) or (GATE.byRank or {})[item.tier] or 1
    need = math.floor(need)
    return need >= 1 and need or 1
end
local function missions(fn, ...)
    local M = LightRP.missions
    if not M or type(M[fn]) ~= "function" then return nil end
    local ok, value = pcall(M[fn], ...)
    if ok then return value end
    return nil
end
-- nil when there is no reputation to read: the gate stays open
local function tierOf(playerId) return tonumber(missions("tier", playerId)) end
local function tierLabel(tier) return missions("tierLabel", tier) or tostring(tier) end
local function lockedFor(playerId, item)
    local tier = tierOf(playerId)
    return tier ~= nil and tier < Cyber.requiredTier(item)
end

-- ---------------------------------------------------------------------------
-- Platform definitions (once per resource generation)

CreateThread(function()
    Wait(500)
    if type(Open77.cyberware) == "table" then
        local ok, why = Open77.cyberware.define(C.legsDefinition)
        if ok then definitions.legs = C.legsDefinition.id else log("legs definition refused: %s", tostring(why)) end
        ok, why = Open77.cyberware.define(C.armsDefinition)
        if ok then definitions.arms = C.armsDefinition.id else log("arms definition refused: %s", tostring(why)) end
    end
    if type(Open77.dash) == "table" then
        for preset, values in pairs(C.dashPresets) do
            local settings = { inputKey = C.dashKey, presentation = "native", movementProfile = "native",
                allowGround = true, allowAir = true, requireDoubleJump = false,
                landingRearmMs = 150, maxAirborneMs = 10000, maxFallSpeed = 30 }
            for k, v in pairs(values) do settings[k] = v end
            local id = "lightrp.dash." .. preset
            local result, why = Open77.dash.define({ id = id, version = 1, profile = "dash", config = settings })
            if result and result.ok then definitions["dash:" .. preset] = id else log("dash %s refused: %s", preset, tostring(why)) end
        end
    end
    if type(Open77.reflex) == "table" then
        for preset, values in pairs(C.overdrivePresets) do
            local settings = { inputKey = C.overdriveKey, presentation = "native" }
            for k, v in pairs(values) do settings[k] = v end
            local id = "lightrp.overdrive." .. preset
            -- version 2: the default key moved from Z (AZERTY forward) to X
            local result, why = Open77.reflex.define({ id = id, version = 2, profile = "reflex_overdrive", config = settings })
            if result and result.ok then definitions["overdrive:" .. preset] = id else log("overdrive %s refused: %s", preset, tostring(why)) end
        end
    end
    if type(Open77.abilities) == "table" then
        local s = C.slam
        local result, why = Open77.abilities.define({ id = "lightrp.ground_slam", version = 1, profile = "ground_slam", config = {
            inputKey = C.slamKey, allowGround = true, allowAir = true, requiredArms = false, requiredLegs = false,
            cosmetic = false, nonlethal = true, damage = s.damage, knockbackMeters = s.knockbackMeters,
            staminaCost = s.staminaCost, cooldownMs = s.cooldownMs, radius = s.radius, innerRadius = 1, edgeMultiplier = 0.25,
            heightBonusPerMeter = 0, maxHeight = 10, maxActivationMs = 5000, geometryDeadlineMs = 750, maxFloorDelta = 0.75,
            impactEffect = "impact.ground_slam", effectOnOwner = true, impactSound = "w_cyb_strongarms_hit_back", soundOnOwner = false } })
        if result and result.ok then definitions.slam = "lightrp.ground_slam" else log("ground slam refused: %s", tostring(why)) end
    end
    log("definitions ready: legs=%s arms=%s dash=%s overdrive=%s slam=%s", tostring(definitions.legs), tostring(definitions.arms),
        tostring(definitions["dash:basic"]), tostring(definitions["overdrive:street"]), tostring(definitions.slam))
end)

-- ---------------------------------------------------------------------------
-- Reads

local function installedList(st)
    local list = {}
    for id in pairs(st and st.installed or {}) do if byId[id] then list[#list + 1] = byId[id] end end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- The fitted implant of a family (one native slot) -- arms, legs, dash, os...
local function familyOf(st, family)
    for _, item in ipairs(installedList(st)) do if item.family == family then return item end end
end

-- The fitted implant of a kind (what it does) -- dash, overdrive, slam, berserk, optics...
local function kindOf(st, kind)
    for _, item in ipairs(installedList(st)) do if item.kind == kind then return item end end
end

function Cyber.installed(playerId)
    local st = state[playerId]
    local out = {}
    for id in pairs(st and st.installed or {}) do out[id] = true end
    return out
end

function Cyber.stored(playerId)
    local st = state[playerId]
    local out = {}
    for id in pairs(st and st.stock or {}) do out[id] = true end
    return out
end

--- The fitted item of `kind` that is in effect: nil when none, or while the implants are
--- suspended (a PvP activity with activeInPvp = false).
function Cyber.fitted(playerId, kind)
    local st = state[playerId]
    if not st or st.suspended then return nil end
    return kindOf(st, kind)
end

--- The character the implants belong to: identifier, key (nil before a character is loaded).
function Cyber.owner(playerId)
    local st = state[playerId]
    if st then return st.identifier, st.key end
end

local function bankOf(playerId)
    local w = LightRP.money and LightRP.money.get(playerId)
    return w and (C.payFrom == "cash" and w.cash or w.bank) or 0
end

-- ---------------------------------------------------------------------------
-- Capacity

local CAP = type(C.capacity) == "table" and C.capacity or { enabled = false }
local function cost(item) return math.max(0, math.floor(tonumber(type(item) == "table" and item.capacity or 0) or 0)) end
Cyber.cost = cost

local function usedBy(st)
    local n = 0
    for _, item in ipairs(installedList(st)) do n = n + cost(item) end
    return n
end

--- The points this character's body holds, nil without a limit.
function Cyber.capacityTotal(playerId)
    if CAP.enabled == false then return nil end
    local by = type(CAP.byTier) == "table" and CAP.byTier or {}
    local tier = tierOf(playerId)
    if tier == nil or #by == 0 then return tonumber(CAP.fallback) or tonumber(by[#by]) end
    tier = math.max(1, math.min(#by, math.floor(tier)))
    return tonumber(by[tier]) or tonumber(CAP.fallback)
end

function Cyber.capacity(playerId)
    local st = state[playerId]
    local used, total = usedBy(st), Cyber.capacityTotal(playerId)
    return { used = used, total = total, over = total ~= nil and used > total or false }
end

-- true, or false + the refusal: `replaced` leaves the body in the same surgery.
local function fits(playerId, st, item, replaced)
    local total = Cyber.capacityTotal(playerId)
    if not total then return true end
    local used = usedBy(st)
    local after = used - (replaced and cost(replaced) or 0) + cost(item)
    if after <= total then return true end
    -- over capacity already (an older character, a lower limit): a swap that does not make it
    -- worse is allowed, anything more is not
    if replaced and after <= used then return true end
    if used > total then
        return false, string.format("Your body is over capacity (%d / %d points): you keep what is fitted, but only a lighter swap fits until you are under it.",
            used, total)
    end
    return false, string.format("Not enough capacity: %s takes %d points, %d of your %d are free. Take an implant out (it goes to your storage) or earn the next street cred tier.",
        item.name, cost(item), math.max(0, total - used + (replaced and cost(replaced) or 0)), total)
end

-- ---------------------------------------------------------------------------
-- The clinic guide

local DIFFICULTY_LABEL = { standard = "Standard", hard = "Hard", critical = "Critical" }

--- What the ripperdoc page's guide explains, read from the live configuration (so it never lies when
--- a number changes): the street cred ladder (points, capacity and the highest implant rank of each
--- tier), what a finished mission pays in street cred per difficulty and the tier it needs, where else
--- street cred comes from, the iconic drops, the surgery fee and the keys of the active implants.
--- `auto`: the character has never finished or skipped it (the page opens it by itself).
function Cyber.guide(playerId)
    local st = state[playerId]
    local M = type(LightRpMissions) == "table" and LightRpMissions or {}
    local rep = type(M.reputation) == "table" and M.reputation or {}
    local thresholds, names = rep.tiers or {}, rep.names or {}
    local byTier = type(CAP.byTier) == "table" and CAP.byTier or {}
    local byRank = type(C.gating) == "table" and C.gating.byRank or {}
    local tiers = {}
    for t = 1, #thresholds do
        local rank = 0
        for r, need in pairs(byRank) do
            if tonumber(need) and tonumber(need) <= t and tonumber(r) > rank then rank = tonumber(r) end
        end
        tiers[#tiers + 1] = { tier = t, name = names[t] or ("Tier " .. t), points = thresholds[t],
            capacity = CAP.enabled ~= false and tonumber(byTier[t]) or nil, rank = rank }
    end
    local gains = {}
    for _, id in ipairs({ "standard", "hard", "critical" }) do
        local points = type(M.reputationGain) == "table" and tonumber(M.reputationGain[id])
        if points then
            local needs = type(rep.difficultyTiers) == "table" and tonumber(rep.difficultyTiers[id]) or 1
            gains[#gains + 1] = { label = DIFFICULTY_LABEL[id] or id, points = points, tier = needs,
                tierName = names[needs] }
        end
    end
    local drops = {}
    for _, source in pairs(ICONIC.sources or {}) do
        if type(source.label) == "string" then drops[#drops + 1] = source.label end
    end
    table.sort(drops)
    local key = function(k) return type(k) == "string" and k:upper() or nil end
    local keys = {
        { label = "Dash / Air Dash", key = key(C.dashKey) },
        { label = "Ground Slam", key = key(C.slamKey) },
        { label = "Sandevistan", key = key(C.overdriveKey) },
        { label = "Berserk", key = key(C.keys and C.keys.berserk and C.keys.berserk.key) },
        { label = "Mantis Blades (draw / sheathe)", key = key(C.keys and C.keys.blades and C.keys.blades.key) },
        { label = "Kiroshi scan", key = "ALT + CLICK" },
    }
    return {
        auto = st ~= nil and st.guideSeen ~= true,
        tiers = tiers,
        gains = gains,
        pvpGivesNone = true,
        drops = drops,
        fittingFee = C.fittingFee or C.removalFee,
        payFrom = C.payFrom == "cash" and "cash" or "bank",
        keys = keys,
    }
end

--- The character finished or skipped the guide: it no longer opens by itself (the GUIDE button still
--- opens it). Persisted per character.
function Cyber.markGuideSeen(playerId)
    local st = state[playerId]
    if not st or st.guideSeen then return false end
    st.guideSeen = true
    if Db.ready then
        Db.run("INSERT IGNORE INTO lightrp_cyberware_guide (identifier, character_key) VALUES (?, ?)", { st.identifier, st.key })
    end
    log("guide seen by %d", playerId)
    return true
end

-- ---------------------------------------------------------------------------
-- The clinic payload

--- Everything the page needs to show and price the stock.
function Cyber.view(playerId)
    local st = state[playerId]
    local cards, installed, stock = {}, {}, {}
    local tier = tierOf(playerId)
    for _, item in ipairs(catalogue) do
        local stats = {}
        for i, pair in ipairs(item.stats or {}) do stats[i] = { label = pair[1], value = pair[2] } end
        local need = Cyber.requiredTier(item)
        local fitted = st ~= nil and st.installed[item.id] == true
        local owned = st ~= nil and st.stock[item.id] == true
        local card = { id = item.id, name = item.name, section = item.section, icon = item.icon,
            rarity = item.rarity, tier = item.tier, price = item.price, family = item.family, maker = item.maker, effect = item.effect, lore = item.lore, stats = stats,
            capacity = cost(item),
            -- street cred: the reputation tier this rank needs to be bought; locked below it (an
            -- implant fitted or in storage never shows locked)
            repTier = need, repName = missions("tierName", need),
            locked = not item.iconic and tier ~= nil and tier < need and not fitted and not owned or false }
        if owned then card.stored = true end
        if item.iconic then
            card.iconic = true
            card.dropOnly = not fitted and not owned
            card.source = Cyber.iconicSource(item.id)
        end
        cards[#cards + 1] = card
    end
    for _, item in ipairs(installedList(st)) do
        installed[item.section] = installed[item.section] or {}
        table.insert(installed[item.section], item.id)
    end
    for id in pairs(st and st.stock or {}) do if byId[id] then stock[#stock + 1] = id end end
    table.sort(stock)
    local info = missions("tierInfo", playerId)
    local cap = Cyber.capacity(playerId)
    return { live = true, catalogue = cards, installed = installed, stock = stock, wallet = bankOf(playerId),
        fittingFee = C.fittingFee or C.removalFee, removalFee = C.fittingFee or C.removalFee,
        capacity = cap.total and { used = cap.used, total = cap.total, over = cap.over } or nil,
        busy = st ~= nil and st.busy ~= nil,
        reputation = type(info) == "table" and { tier = info.tier, name = info.name, points = info.points,
            next = info.next, nextName = info.nextName } or nil,
        guide = Cyber.guide(playerId) }
end

-- The label of the source an iconic drops from ("Chimera raid (Critical)").
function Cyber.iconicSource(itemId)
    for _, source in pairs(ICONIC.sources or {}) do
        for _, id in ipairs(source.items or {}) do if id == itemId then return source.label end end
    end
end

-- ---------------------------------------------------------------------------
-- Effects

local function bag(playerId)
    if type(Open77.state) ~= "table" or type(Open77.state.player) ~= "function" then return nil end
    local ok, b = pcall(Open77.state.player, playerId)
    return ok and b or nil
end

-- The body's own values before any implant, read once per connection and kept in the player's
-- state bag so a resource reload does not stack bonuses on bonuses.
local function baseline(playerId)
    local st = state[playerId]
    if st and st.baseline then return st.baseline end
    local b = bag(playerId)
    local saved = b and b:get("lrp_cw_base")
    if type(saved) == "table" and saved.healthMax then
        if st then st.baseline = saved end
        return saved
    end
    local stats = type(Open77.stats) == "table" and Open77.stats.get(playerId) or nil
    if type(stats) ~= "table" or type(stats.health) ~= "table" or type(stats.stamina) ~= "table" then return nil end
    local base = {
        healthMax = tonumber(stats.health.maximum) or 100, healthRegen = tonumber(stats.health.regenPerSecond) or 0,
        healthRegenEnabled = stats.health.regenEnabled == true,
        staminaMax = tonumber(stats.stamina.maximum) or 100, staminaRegen = tonumber(stats.stamina.regenPerSecond) or 0,
        armor = tonumber(stats.armor) or 0,
    }
    if b then pcall(function() b:set("lrp_cw_base", base) end) end
    if st then st.baseline = base end
    return base
end
Cyber.baseline = baseline

local function passiveBonus(st)
    local bonus = { healthMax = 0, healthRegen = 0, staminaMax = 0, staminaRegen = 0, armor = 0, noFallDamage = false }
    -- suspended (a PvP activity with activeInPvp = false): the body's own values
    for _, item in ipairs(st.suspended and {} or installedList(st)) do
        local p = item.passive
        if p then
            for k, v in pairs(p) do
                if type(v) == "number" then bonus[k] = (bonus[k] or 0) + v elseif v == true then bonus[k] = true end
            end
        end
    end
    return bonus
end

-- Health regeneration: the body's own, the passives and the timed layers (Berserk, Pain Editor).
local function applyRegen(playerId, bonus)
    local st = state[playerId]
    local base = baseline(playerId)
    if not st or not base then return false end
    bonus = bonus or passiveBonus(st)
    local extra = 0
    for _, rate in pairs(st.boosts) do extra = extra + rate end
    local S = Open77.stats
    pcall(S.setRegenRate, playerId, "health", base.healthRegen + bonus.healthRegen + extra)
    -- starving (needs.lua): no health regen until the character eats or drinks
    local N = LightRP.needs
    local starve = type(LightRpConfig) == "table" and type(LightRpConfig.needs) == "table" and LightRpConfig.needs.starve or {}
    local starving = starve.noRegen ~= false and type(N) == "table" and type(N.starving) == "function"
        and N.starving(playerId) ~= nil
    pcall(S.setRegenEnabled, playerId, "health", (not starving) and (base.healthRegenEnabled or bonus.healthRegen + extra > 0))
    return true
end
--- Re-applies health regen (needs.lua calls it when starving starts or ends); false when this
--- player has no cyberware state yet (the caller then sets the flag itself).
function Cyber.refreshRegen(playerId) return applyRegen(playerId) end

local function applyPassives(playerId)
    local st = state[playerId]
    local base = baseline(playerId)
    if not st or not base then return false end
    local bonus = passiveBonus(st)
    local S = Open77.stats
    pcall(S.setMax, playerId, "health", base.healthMax + bonus.healthMax)
    pcall(S.setMax, playerId, "stamina", base.staminaMax + bonus.staminaMax)
    applyRegen(playerId, bonus)
    pcall(S.setRegenRate, playerId, "stamina", base.staminaRegen + bonus.staminaRegen)
    if type(Open77.players.setArmor) == "function" then pcall(Open77.players.setArmor, playerId, base.armor + bonus.armor) end
    if type(Open77.players.setFallDamage) == "function" then pcall(Open77.players.setFallDamage, playerId, not bonus.noFallDamage) end
    return true
end

--- A timed layer of health regeneration on top of the passives (`name` is the effect's own,
--- a later call replaces it; nil or 0 removes it).
function Cyber.boost(playerId, name, rate)
    local st = state[playerId]
    if not st or type(name) ~= "string" then return false end
    rate = tonumber(rate)
    st.boosts[name] = rate and rate > 0 and rate or nil
    return applyRegen(playerId)
end

-- -> true when the grant is in place (or rightly absent), false + reason to retry later.
local function grantFamily(playerId, kind, item)
    local api = kind == "dash" and Open77.dash or kind == "overdrive" and Open77.reflex or kind == "slam" and Open77.abilities or nil
    if type(api) ~= "table" then return true end
    local current = api.current(playerId)
    local mine = current == nil or current.ownedByCaller ~= false
    if item == nil then
        if current and mine then pcall(api.revoke, playerId) end
        return true
    end
    local definition = kind == "slam" and definitions.slam or definitions[kind .. ":" .. tostring(item.preset)]
    if not definition then return false, "definition_unavailable" end
    if not mine then log("%s of player %d is owned by another resource: not granted", kind, playerId) return true end
    if current and current.status ~= "removed" then
        local held = type(current.definition) == "table" and current.definition.id or current.definition or current.definitionId
        if held == definition then return true end -- already this grant (a regrant is idempotent anyway)
    end
    local result, why = api.grant(playerId, definition)
    if result and result.ok then return true end
    return false, tostring(why or (result and result.error))
end

-- What a session grant should be now: the fitted implant of that kind, nothing while suspended.
-- (By kind, not family: the operating system holds a Sandevistan OR a Berserk.)
local function wanted(st, kind)
    if st.suspended then return nil end
    return kindOf(st, kind)
end

-- The body may not be there yet (loading, respawn): retried every 2 s for a minute.
local function applyGrants(playerId)
    local st = state[playerId]
    if not st or st.granting then return end
    st.granting = true
    CreateThread(function()
        local pending = { dash = true, overdrive = true, slam = true }
        for attempt = 1, 30 do
            if state[playerId] ~= st then return end
            local why
            for kind in pairs(pending) do
                local ok, reason = grantFamily(playerId, kind, wanted(st, kind))
                if ok then pending[kind] = nil else why = reason end
            end
            if next(pending) == nil then break end
            if attempt == 30 then log("grants of %d still refused after a minute: %s", playerId, tostring(why)) end
            Wait(2000)
        end
        st.granting = nil
    end)
end

local function alive(playerId)
    local life = Open77.players.getLifeState and Open77.players.getLifeState(playerId)
    return life and life.phase == "alive"
end
Cyber.alive = alive

local function applyAll(playerId)
    if not state[playerId] then return end
    if alive(playerId) then
        applyPassives(playerId)
        applyGrants(playerId)
    end
    changed(playerId)
end

-- ---------------------------------------------------------------------------
-- Durable implants (legs / arms) through the platform's transactions

local completions = {} -- ticket -> result
AddEventHandler("onCyberwareOperationCompleted", function(player, ticket, encoded)
    local ok, result = pcall(json.decode, encoded or "{}")
    completions[tostring(ticket)] = ok and result or { ok = false, error = "decode_failed" }
end)

local function current(playerId)
    if type(Open77.cyberware) ~= "table" then return nil, "cyberware_unavailable" end
    for _ = 1, 40 do
        local record = Open77.cyberware.current(playerId)
        if record then return record end
        Wait(250)
    end
    return nil, "cyberware_record_unavailable"
end

-- Runs one durable install/remove and waits for its completion (up to 25 s).
local function platform(playerId, op, item)
    local record, why = current(playerId)
    if not record then return false, why end
    local operationId = Open77.cyberware.newOperationId()
    local pending
    if op == "install" then
        local definition = item.kind == "legs" and definitions.legs or definitions.arms
        if not definition then return false, "definition_unavailable" end
        pending, why = Open77.cyberware.install(playerId, definition, item.grade, { expectedRevision = record.revision, operationId = operationId })
    else
        pending, why = Open77.cyberware.remove(playerId, { slot = item.kind == "legs" and "legs" or "arms",
            expectedRevision = record.revision, operationId = operationId })
    end
    if not pending then return false, why end
    if pending.ticket == nil then return true end -- already the committed state
    local ticket, deadline = tostring(pending.ticket), now() + 25000
    while completions[ticket] == nil and now() < deadline do Wait(100) end
    local result = completions[ticket]
    completions[ticket] = nil
    if not result then return false, "operation_timeout" end
    if result.ok ~= true then return false, tostring(result.error or result.reason or "operation_failed") end
    return true
end

-- Brings the platform's record in line with what LightRP sold this character (a durable implant
-- lost elsewhere is put back for free; one LightRP did not sell is left alone).
local function reconcile(playerId)
    local st = state[playerId]
    if not st or type(Open77.cyberware) ~= "table" then return end
    local record = current(playerId)
    if not record or state[playerId] ~= st then return end
    for _, kind in ipairs({ "legs", "arms" }) do
        local family = kind == "legs" and "legs_tendons" or "arms"
        local item = familyOf(st, family)
        if item and item.kind == kind then
            local have = record[kind]
            local grade = have and (type(have.grade) == "table" and have.grade.id or have.grade)
            if not have or (have.definition ~= nil and have.definition ~= definitions[kind]) or grade ~= item.grade then
                local ok, why = platform(playerId, "install", item)
                log("reconcile %s of %d (%s): %s", kind, playerId, item.id, ok and "restored" or tostring(why))
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Mantis Blades: the arm weapon, drawn and sheathed with its own key

local weaponResults = {}
AddEventHandler("open77:weapons:completed", function(player, request, _, accepted, reason)
    weaponResults[tostring(player) .. ":" .. tostring(request)] = { accepted = accepted, reason = reason }
end)

local function weapons(playerId, method, ...)
    if type(Open77.weapons) ~= "table" or type(Open77.weapons[method]) ~= "function" then return nil, "weapons_api_unavailable" end
    local ok, request, why = pcall(Open77.weapons[method], playerId, ...)
    if not ok or not request then return nil, ok and why or request end
    local key, deadline = tostring(playerId) .. ":" .. tostring(request), now() + 10000
    while not weaponResults[key] and now() < deadline do Wait(50) end
    local done = weaponResults[key]
    weaponResults[key] = nil
    if not done then return nil, "request_timeout" end
    if not done.accepted then return nil, done.reason end
    return true
end

function Cyber.handlesLoadout(playerId)
    local st = state[playerId]
    return st ~= nil and st.drawn == true
end

local function sheathe(playerId, resync)
    local st = state[playerId]
    if not st or not st.drawn then return end
    st.drawn = false
    CreateThread(function()
        weapons(playerId, "remove", 1)
        if resync ~= false and LightRP.armament and type(LightRP.armament.synchronize) == "function" then
            pcall(LightRP.armament.synchronize, playerId)
        end
    end)
end

local function draw(playerId)
    local st = state[playerId]
    local blades = st and familyOf(st, "arms")
    if not blades or blades.kind ~= "blades" then
        notice(playerId, "warning", "MANTIS BLADES", "No Mantis Blades installed. A ripperdoc can fit them.")
        return
    end
    if st.drawing then return end
    if st.drawn then sheathe(playerId) return end
    if not alive(playerId) then return end
    if LightRP.missions and LightRP.missions.handlesLoadout and LightRP.missions.handlesLoadout(playerId) then
        notice(playerId, "warning", "MANTIS BLADES", "Not during this mission.")
        return
    end
    if LightRP.activities and not LightRP.activities.allows(playerId, "rpWeapons") then
        notice(playerId, "warning", "MANTIS BLADES", "Not during this activity.")
        return
    end
    -- Safe zones take weapons away (clinics are in one): say so instead of failing silently.
    local zones = LightRP.safezones
    if zones and type(zones.protected) == "function" then
        local ok, zone = pcall(zones.protected, playerId)
        if ok and zone then
            notice(playerId, "warning", "MANTIS BLADES", "Safe zone: your blades stay sheathed here.")
            return
        end
    end
    st.drawing, st.drawn = true, true -- the armament stands aside from now on
    CreateThread(function()
        pcall(Open77.weapons.holster, playerId)
        weapons(playerId, "remove", 1)
        weapons(playerId, "remove", 4)
        Wait(250)
        local ok, why = weapons(playerId, "assign", blades.record, 1, { active = true, addToInventory = true })
        st.drawing = nil
        if not ok then
            log("blades of %d refused: %s", playerId, tostring(why))
            notice(playerId, "error", "MANTIS BLADES", why == "native_arm_slot_owned"
                and "Your arms are busy with another implant." or "The blades did not deploy. Try again.")
            sheathe(playerId)
        end
    end)
end

-- Sheathes drawn blades; false when there were none (the armament's holster asks first).
function Cyber.sheatheBlades(playerId)
    local st = state[playerId]
    if not st or not st.drawn then return false end
    sheathe(playerId)
    return true
end

-- Something in the hands (a weapon, the fists): the server's weapon report first, the
-- armament's own state when the report is missing.
local function handsBusy(playerId)
    local ok, weapons = pcall(Open77.weapons.get, playerId)
    if ok and type(weapons) == "table" and weapons.drawn ~= nil then return weapons.drawn == true end
    local W = LightRP.armament
    local view = W and type(W.view) == "function" and W.view(playerId)
    return type(view) == "table" and (view.right ~= nil or view.left ~= nil) and view.holstered ~= true
end

-- B, the vanilla holster key: puts away whatever is in the hands (blades, a gun, the
-- fists); with empty hands it draws the Mantis Blades of a player who has them, and
-- does nothing otherwise (no "no blades installed" notice on every B).
RegisterNetEvent("op77_lightrp:cyberware:blades", function()
    local playerId = tonumber(source)
    if not playerId then return end
    local st = state[playerId]
    if st and st.drawn then sheathe(playerId) return end
    if handsBusy(playerId) then
        local W = LightRP.armament
        if W and type(W.holster) == "function" then W.holster(playerId) end
        return
    end
    local blades = st and familyOf(st, "arms")
    if blades and blades.kind == "blades" then draw(playerId) end
end)

-- ---------------------------------------------------------------------------
-- Storage moves: the body (lightrp_cyberware) and the storage (lightrp_cyberware_stock) change
-- in one transaction. moves = { fit, unfit, stash, unstash, source }

local function commit(st, moves)
    local who, q = { st.identifier, st.key }, {}
    local function add(sql, item, extra)
        local values = { who[1], who[2], item }
        if extra then values[4] = extra end
        q[#q + 1] = { query = sql, values = values }
    end
    if moves.unfit then add("DELETE FROM lightrp_cyberware WHERE identifier = ? AND character_key = ? AND item = ?", moves.unfit) end
    if moves.unstash then add("DELETE FROM lightrp_cyberware_stock WHERE identifier = ? AND character_key = ? AND item = ?", moves.unstash) end
    if moves.fit then add("INSERT IGNORE INTO lightrp_cyberware (identifier, character_key, item) VALUES (?, ?, ?)", moves.fit) end
    if moves.stash then
        add("INSERT IGNORE INTO lightrp_cyberware_stock (identifier, character_key, item, source) VALUES (?, ?, ?, ?)", moves.stash,
            moves.source or "clinic")
    end
    -- without a database the framework keeps everything for the session only
    if Db.ready and #q > 0 then
        local ok, why = Db.transaction(q)
        if not ok then return false, why end
    end
    if moves.unfit then st.installed[moves.unfit] = nil end
    if moves.unstash then st.stock[moves.unstash] = nil end
    if moves.fit then st.installed[moves.fit] = true end
    if moves.stash then st.stock[moves.stash] = true end
    return true
end

--- An implant into the character's storage (an iconic drop, a staff grant): true, or false +
--- reason ("not_loaded", "unknown_item", "owned", "database_error").
function Cyber.store(playerId, itemId, source)
    local st, item = state[playerId], byId[itemId]
    if not st then return false, "not_loaded" end
    if not item then return false, "unknown_item" end
    if st.installed[item.id] or st.stock[item.id] then return false, "owned" end
    local ok, why = commit(st, { stash = item.id, source = source or "staff" })
    if not ok then return false, why end
    log("%d received %s in storage (%s)", playerId, item.id, tostring(source or "staff"))
    return true
end

--- "fitted", "stored" or nil.
function Cyber.owns(playerId, itemId)
    local st = state[playerId]
    if not st then return nil end
    if st.installed[itemId] then return "fitted" end
    if st.stock[itemId] then return "stored" end
    return nil
end

-- ---------------------------------------------------------------------------
-- Operations at the clinic

local function refuse(done, text) done(false, text) return false end
local function fee() return math.max(0, math.floor(tonumber(C.fittingFee or C.removalFee) or 0)) end

local function charge(playerId, amount, label)
    if amount <= 0 then return true end
    local remove = C.payFrom == "cash" and LightRP.money.removeCash or LightRP.money.removeBank
    local paid, why = remove(playerId, amount, "cyberware", label)
    if not paid then
        return false, why == "insufficient_funds" and ("Not enough eurodollars in your bank account (" .. LightRP.money.format(amount) .. ").") or "Payment failed."
    end
    return true
end

-- A failed surgery: the money back.
local function refund(playerId, amount, label)
    if amount <= 0 then return end
    local add = C.payFrom == "cash" and LightRP.money.addCash or LightRP.money.addBank
    add(playerId, amount, "refund", label)
end

local function seated(playerId)
    if not C.seatedOnly then return true end
    return LightRP.ripperdoc and LightRP.ripperdoc.isSeated and LightRP.ripperdoc.isSeated(playerId) or false
end

--- op: "install" | "remove". done(ok, message) is called once, possibly much later (surgery).
--- install: from storage when the character owns it (fittingFee), else a purchase (the price,
--- fitting included; never an iconic). remove: to storage (fittingFee).
function Cyber.operate(playerId, op, itemId, done)
    done = done or function() end
    local st, item = state[playerId], byId[itemId]
    if not C.enabled then return refuse(done, "The clinic is closed.") end
    if not st then return refuse(done, "Your character is not ready.") end
    if not item then return refuse(done, "Unknown implant.") end
    if st.busy then return refuse(done, "An operation is already in progress.") end
    if not seated(playerId) then return refuse(done, "Lie down on the operating chair first.") end
    if not alive(playerId) then return refuse(done, "Not now.") end

    if op == "remove" then
        if not st.installed[item.id] then return refuse(done, "This implant is not installed.") end
        local amount = fee()
        local paid = charge(playerId, amount, "Implant removal: " .. item.name)
        if not paid then return refuse(done, "Taking it out costs " .. LightRP.money.format(amount) .. ".") end
        st.busy = op
        CreateThread(function()
            if item.kind == "blades" then sheathe(playerId) end
            local ok, why = true, nil
            if item.kind == "legs" or item.kind == "arms" then ok, why = platform(playerId, "remove", item) end
            if state[playerId] ~= st then return end
            if ok then ok, why = commit(st, { unfit = item.id, stash = item.id, source = "clinic" }) end
            st.busy = nil
            if not ok then
                refund(playerId, amount, "Implant removal refund")
                log("removal of %s for %d failed: %s", item.id, playerId, tostring(why))
                if item.kind == "legs" or item.kind == "arms" then reconcile(playerId) end
                return done(false, "The extraction failed (" .. tostring(why) .. "). You were refunded.")
            end
            applyAll(playerId)
            log("%d took out %s (to storage)", playerId, item.id)
            done(true, item.name .. " taken out. It waits in your implant storage.")
        end)
        return true
    end

    if op ~= "install" then return refuse(done, "Unknown operation.") end
    if st.installed[item.id] then return refuse(done, "Already installed.") end
    local fromStock = st.stock[item.id] == true
    if not fromStock then
        if item.iconic then
            local source = Cyber.iconicSource(item.id)
            return refuse(done, "Iconic implants are not for sale" .. (source and (": " .. source .. " drops it.") or "."))
        end
        -- street cred, before any money moves (an implant already owned needs none)
        if lockedFor(playerId, item) then
            return refuse(done, string.format("Street cred too low: %s needs reputation tier %s. PvE missions, raids, gigs and PvE activities earn it.",
                item.name, tierLabel(Cyber.requiredTier(item))))
        end
    end
    -- A family is one native slot (the arm slot, the legs, the dash, the operating system...):
    -- another model of it replaces the one installed, which goes to storage.
    local replaced = familyOf(st, item.family)
    local room, why = fits(playerId, st, item, replaced)
    if not room then
        if not st.overLogged and usedBy(st) > (Cyber.capacityTotal(playerId) or math.huge) then
            st.overLogged = true
            log("%d (%s/%s) is over capacity: %d / %s, fitting %s refused", playerId, st.identifier, st.key, usedBy(st),
                tostring(Cyber.capacityTotal(playerId)), item.id)
        end
        return refuse(done, why)
    end
    local amount = fromStock and fee() or math.max(0, math.floor(tonumber(item.price) or 0))
    local charged, reason = charge(playerId, amount, (fromStock and "Implant fitting: " or "Cyberware: ") .. item.name)
    if not charged then return refuse(done, reason) end
    st.busy = op
    CreateThread(function()
        local ok, failure = true, nil
        -- Leaving the arm slot: Gorilla Arms out before the blades, blades sheathed before Gorilla Arms.
        if replaced and replaced.kind == "blades" then sheathe(playerId, false) end
        if replaced and replaced.kind == "arms" and item.kind ~= "arms" then ok, failure = platform(playerId, "remove", replaced) end
        if ok and (item.kind == "legs" or item.kind == "arms") then ok, failure = platform(playerId, "install", item) end
        if state[playerId] ~= st then return end
        if ok then
            ok, failure = commit(st, { fit = item.id, unstash = fromStock and item.id or nil,
                unfit = replaced and replaced.id or nil, stash = replaced and replaced.id or nil, source = "clinic" })
        end
        st.busy = nil
        if not ok then
            refund(playerId, amount, "Cyberware refund: " .. item.name)
            log("install of %s for %d failed: %s", item.id, playerId, tostring(failure))
            reconcile(playerId)
            return done(false, "The surgery failed (" .. tostring(failure) .. "). You were refunded.")
        end
        applyAll(playerId)
        log("%d fitted %s%s%s", playerId, item.id, fromStock and " from storage" or " (bought)",
            replaced and (", " .. replaced.id .. " to storage") or "")
        done(true, item.name .. " installed." .. (replaced and (" " .. replaced.name .. " went to your storage.") or ""))
    end)
    return true
end

-- ---------------------------------------------------------------------------
-- Lifecycle

local function load(playerId, c)
    local previous = state[playerId]
    if previous and previous.drawn then sheathe(playerId, false) end
    if not c or not c.identifier then
        state[playerId] = nil
        if previous then changed(playerId) end
        return
    end
    local st = { identifier = c.identifier, key = c.key, installed = {}, stock = {}, boosts = {}, baseline = previous and previous.baseline }
    if Db.ready then
        for _, row in ipairs(Db.query("SELECT item FROM lightrp_cyberware WHERE identifier = ? AND character_key = ?",
            { c.identifier, c.key }) or {}) do
            if byId[row.item] then st.installed[row.item] = true end
        end
        for _, row in ipairs(Db.query("SELECT item FROM lightrp_cyberware_stock WHERE identifier = ? AND character_key = ?",
            { c.identifier, c.key }) or {}) do
            if byId[row.item] and not st.installed[row.item] then st.stock[row.item] = true end
        end
        st.guideSeen = #(Db.query("SELECT 1 AS seen FROM lightrp_cyberware_guide WHERE identifier = ? AND character_key = ?",
            { c.identifier, c.key }) or {}) > 0
    end
    state[playerId] = st
    CreateThread(function()
        Wait(1500)
        if state[playerId] ~= st then return end
        -- Characters fitted before the capacity existed keep everything; they fit nothing
        -- more until under it.
        local cap = Cyber.capacity(playerId)
        if cap.over then
            st.overLogged = true
            log("%d (%s/%s) loaded over capacity: %d / %d points; kept, nothing more fits until under it",
                playerId, st.identifier, st.key, cap.used, cap.total)
        end
        applyAll(playerId)
        reconcile(playerId)
    end)
end

function Cyber.onCharacterLoaded(playerId, c) load(playerId, c) end
function Cyber.onCharacterSwitched(playerId, c) load(playerId, c) end
function Cyber.onGameplayReady(playerId) if state[playerId] then CreateThread(function() Wait(1000) applyAll(playerId) end) end end

function Cyber.onLifeState(playerId, phase)
    local st = state[playerId]
    if not st then return end
    if phase ~= "alive" then
        if st.drawn then st.drawn = false end -- the body lost its weapons anyway
        st.boosts = {}                        -- timed layers end with the body
        return
    end
    CreateThread(function() Wait(1500) applyAll(playerId) end)
end

function Cyber.onDisconnected(playerId) state[playerId] = nil end

-- An activity starts or ends (server/modules/activities.lua). With activeInPvp = false, a
-- non-PvE activity suspends the session grants and the passive stats; its end restores them.
-- Durable legs / arms stay (platform implants; the arm weapons follow the activity's caps).
function Cyber.onActivityChanged(playerId, activityId, info)
    local st = state[playerId]
    if not st then return end
    local suspend = C.activeInPvp == false and activityId ~= nil and not (type(info) == "table" and info.pve == true)
    if (st.suspended == true) == suspend then return end
    st.suspended = suspend or nil
    log("implants of %d %s (%s)", playerId, suspend and "suspended" or "restored", tostring(activityId or (type(info) == "table" and info.left)))
    if suspend then st.boosts = {} end
    applyPassives(playerId)
    if suspend then
        for _, kind in ipairs(GRANTS) do pcall(grantFamily, playerId, kind, nil) end
    else
        applyGrants(playerId)
    end
    changed(playerId)
end

-- Body, bucket and session changes invalidate session grants on the platform side: every 10 s
-- whatever an implant should grant and is missing is granted again.
CreateThread(function()
    while true do
        Wait(10000)
        for playerId, st in pairs(state) do
            if not st.granting and not st.suspended and alive(playerId) then
                for _, kind in ipairs(GRANTS) do
                    local item = kindOf(st, kind)
                    local api = kind == "dash" and Open77.dash or kind == "overdrive" and Open77.reflex or Open77.abilities
                    if item and type(api) == "table" then
                        local current = api.current(playerId)
                        if current == nil or current.status == "removed" then
                            local ok, why = grantFamily(playerId, kind, item)
                            log("%s of %d was missing: %s", kind, playerId, ok and "granted again" or tostring(why))
                        end
                    end
                end
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    for playerId in pairs(state) do
        for _, kind in ipairs(GRANTS) do pcall(grantFamily, playerId, kind, nil) end
    end
end)

-- Staff: lightrp.cyberware <playerId> [list|status|blades|give <item>|take <item>|store <item>|unstore <item>]
--   give    fits it now (ignores price, street cred and capacity; a family mate goes to storage)
--   take    takes it off the body AND out of storage (a correction, nothing goes to storage)
--   store   puts it in storage (an iconic by hand, a refund in kind)
--   unstore deletes it from storage
RegisterCommand("lightrp.cyberware", function(src, args)
    local target = tonumber(args[1])
    local st = target and state[target]
    local function reply(text) if tonumber(src) and tonumber(src) > 0 then LightRP.result(tonumber(src), true, text) else print(text) end end
    if not st then return reply("usage: lightrp.cyberware <playerId> [list|status|give <item>|take <item>|store <item>|unstore <item>] (player must be loaded)") end
    local verb, itemId = args[2] or "list", args[3]
    if verb == "list" then
        local names, stored = {}, {}
        for _, item in ipairs(installedList(st)) do names[#names + 1] = item.id end
        for id in pairs(st.stock) do stored[#stored + 1] = id end
        table.sort(stored)
        local cap = Cyber.capacity(target)
        return reply(("cyberware of %d: %s | storage: %s | capacity %d/%s%s"):format(target,
            #names > 0 and table.concat(names, ", ") or "none", #stored > 0 and table.concat(stored, ", ") or "empty",
            cap.used, tostring(cap.total or "-"), cap.over and " (over)" or ""))
    end
    if verb == "blades" then draw(target) return reply(("cyberware blades toggled for %d"):format(target)) end
    if verb == "status" then
        -- What the platform says, not what LightRP sold: durable record, grant projections, stats.
        local record = type(Open77.cyberware) == "table" and Open77.cyberware.current(target)
        local function slot(s)
            if not record then return "loading" end
            local v = record[s]
            if not v then return "none" end
            return tostring(v.definition) .. "/" .. tostring(type(v.grade) == "table" and v.grade.id or v.grade)
        end
        local function grant(api)
            local v = type(api) == "table" and api.current(target)
            if not v then return "none" end
            local projection = type(v.projection) == "table" and v.projection.status or v.status or "?"
            local d = type(v.definition) == "table" and v.definition.id or v.definition or v.definitionId
            return tostring(d or "granted") .. ":" .. tostring(projection)
        end
        local stats = type(Open77.stats) == "table" and Open77.stats.get(target) or {}
        return reply(("cyberware status %d: arms=%s legs=%s dash=%s overdrive=%s slam=%s health=%s/%s regen=%s stamina=%s armor=%s drawn=%s"):format(
            target, slot("arms"), slot("legs"), grant(Open77.dash), grant(Open77.reflex), grant(Open77.abilities),
            tostring(stats.health and stats.health.value), tostring(stats.health and stats.health.maximum),
            tostring(stats.health and stats.health.regenPerSecond), tostring(stats.stamina and stats.stamina.maximum),
            tostring(stats.armor), tostring(st.drawn == true)))
    end
    local item = byId[itemId or ""]
    if not item then return reply("unknown item: " .. tostring(itemId)) end
    CreateThread(function()
        if verb == "give" then
            local replaced = familyOf(st, item.family)
            if replaced and replaced.id == item.id then replaced = nil end
            if item.kind == "legs" or item.kind == "arms" then
                local ok, why = platform(target, "install", item)
                if not ok then return reply("platform refused: " .. tostring(why)) end
            elseif replaced and replaced.kind == "arms" then platform(target, "remove", replaced) end
            if replaced and replaced.kind == "blades" then sheathe(target, false) end
            local ok, why = commit(st, { fit = item.id, unstash = st.stock[item.id] and item.id or nil,
                unfit = replaced and replaced.id or nil, stash = replaced and replaced.id or nil, source = "staff" })
            if not ok then return reply("storage refused: " .. tostring(why)) end
        elseif verb == "take" then
            if st.installed[item.id] then
                if item.kind == "legs" or item.kind == "arms" then platform(target, "remove", item) end
                if item.kind == "blades" then sheathe(target) end
            end
            commit(st, { unfit = st.installed[item.id] and item.id or nil, unstash = st.stock[item.id] and item.id or nil })
        elseif verb == "store" then
            local ok, why = Cyber.store(target, item.id, "staff")
            if not ok then return reply("cyberware store refused: " .. tostring(why)) end
        elseif verb == "unstore" then
            commit(st, { unstash = st.stock[item.id] and item.id or nil })
        else
            return reply("unknown verb: " .. tostring(verb))
        end
        applyAll(target)
        reply(("cyberware %s %s for %d"):format(verb, item.id, target))
    end)
end, true)
