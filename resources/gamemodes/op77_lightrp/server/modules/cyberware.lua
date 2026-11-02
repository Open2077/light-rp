-- Cyberware: what each character has under the skin, bought and installed at a ripperdoc
-- (op77_ripperdoc, opened from a ripperdoc chair by server/modules/ripperdoc.lua).
--
-- The catalogue is server/config/cyberware.lua (only implants the platform really applies).
-- Ownership is durable per character (lightrp_cyberware); effects are projected again on every
-- load, switch and respawn:
--   legs / arms -> Open77.cyberware durable implants (the platform's own record and receipts;
--                  the price is taken first and given back if the surgery fails)
--   blades      -> Mantis Blades on the arm slot, drawn with their own key (armament steps aside)
--   dash / slam / overdrive -> session grants (Open77.dash / abilities / reflex)
--   passive     -> health/stamina maxima and regeneration, armor, fall damage
--
--   LightRP.cyberware.installed(playerId)  -> { [id] = true }
--   LightRP.cyberware.view(playerId)       -> the clinic payload (catalogue, installed, bank balance)
--   LightRP.cyberware.operate(playerId, op, itemId, done) -- op "install" | "remove"; done(ok, message)
--   LightRP.cyberware.handlesLoadout(playerId) -> true while the Mantis Blades are drawn
local C = LightRpCyberwareConfig
local Db = LightRP.db
local Cyber = LightRP.module("cyberware", {})

local items, byId = C.items, {}
for _, item in ipairs(items) do byId[item.id] = item end

Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_cyberware (
        identifier    VARCHAR(64) NOT NULL,
        character_key VARCHAR(32) NOT NULL,
        item          VARCHAR(48) NOT NULL,
        installed_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (identifier, character_key, item)
    )
]])

local state = {}        -- playerId -> { identifier, key, installed = {id=true}, busy, drawn, baseline }
local definitions = {}  -- "dash:basic" / "overdrive:street" / "slam" / "legs" / "arms" -> registered definition id

local function log(fmt, ...) LightRP.log("cyberware: " .. fmt, ...) end
local function now() return math.floor(Open77.time.monotonic() * 1000) end

local function notice(playerId, kind, title, body)
    LightRP.notice(playerId, { kind = kind, title = title, body = body, source = "RIPPERDOC" })
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
    return list
end

local function familyOf(st, family)
    for _, item in ipairs(installedList(st)) do if item.family == family then return item end end
end

function Cyber.installed(playerId)
    local st = state[playerId]
    local out = {}
    for id in pairs(st and st.installed or {}) do out[id] = true end
    return out
end

local function bankOf(playerId)
    local w = LightRP.money and LightRP.money.get(playerId)
    return w and (C.payFrom == "cash" and w.cash or w.bank) or 0
end

--- The clinic payload: everything the page needs to show and price the stock.
function Cyber.view(playerId)
    local st = state[playerId]
    local catalogue, installed = {}, {}
    for _, item in ipairs(items) do
        local stats = {}
        for i, pair in ipairs(item.stats or {}) do stats[i] = { label = pair[1], value = pair[2] } end
        catalogue[#catalogue + 1] = { id = item.id, name = item.name, section = item.section, icon = item.icon,
            rarity = item.rarity, tier = item.tier, price = item.price, family = item.family, maker = item.maker, effect = item.effect, lore = item.lore, stats = stats }
    end
    for _, item in ipairs(installedList(st)) do
        installed[item.section] = installed[item.section] or {}
        table.insert(installed[item.section], item.id)
    end
    return { live = true, catalogue = catalogue, installed = installed, wallet = bankOf(playerId),
        removalFee = C.removalFee, busy = st ~= nil and st.busy ~= nil }
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

local function applyPassives(playerId)
    local st = state[playerId]
    local base = baseline(playerId)
    if not st or not base then return false end
    local bonus = { healthMax = 0, healthRegen = 0, staminaMax = 0, staminaRegen = 0, armor = 0, noFallDamage = false }
    for _, item in ipairs(installedList(st)) do
        local p = item.passive
        if p then
            for k, v in pairs(p) do
                if type(v) == "number" then bonus[k] = (bonus[k] or 0) + v elseif v == true then bonus[k] = true end
            end
        end
    end
    local S = Open77.stats
    pcall(S.setMax, playerId, "health", base.healthMax + bonus.healthMax)
    pcall(S.setMax, playerId, "stamina", base.staminaMax + bonus.staminaMax)
    local healthRate = base.healthRegen + bonus.healthRegen
    pcall(S.setRegenRate, playerId, "health", healthRate)
    pcall(S.setRegenEnabled, playerId, "health", base.healthRegenEnabled or bonus.healthRegen > 0)
    pcall(S.setRegenRate, playerId, "stamina", base.staminaRegen + bonus.staminaRegen)
    if type(Open77.players.setArmor) == "function" then pcall(Open77.players.setArmor, playerId, base.armor + bonus.armor) end
    if type(Open77.players.setFallDamage) == "function" then pcall(Open77.players.setFallDamage, playerId, not bonus.noFallDamage) end
    return true
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
                local ok, reason = grantFamily(playerId, kind, familyOf(st, kind))
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

local function applyAll(playerId)
    if not state[playerId] or not alive(playerId) then return end
    applyPassives(playerId)
    applyGrants(playerId)
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
-- Operations at the clinic

local function refuse(done, text) done(false, text) return false end

local function chargeOrFail(playerId, item)
    local remove = C.payFrom == "cash" and LightRP.money.removeCash or LightRP.money.removeBank
    local paid, why = remove(playerId, item.price, "cyberware", "Cyberware: " .. item.name)
    if not paid then return false, why == "insufficient_funds" and "Not enough eurodollars in your bank account." or "Payment failed." end
    return true
end

-- A failed surgery: the money back.
local function refund(playerId, item)
    local add = C.payFrom == "cash" and LightRP.money.addCash or LightRP.money.addBank
    add(playerId, item.price, "refund", "Cyberware refund: " .. item.name)
end

local function store(st, add, remove)
    if remove then
        Db.run("DELETE FROM lightrp_cyberware WHERE identifier = ? AND character_key = ? AND item = ?", { st.identifier, st.key, remove })
        st.installed[remove] = nil
    end
    if add then
        Db.run("INSERT IGNORE INTO lightrp_cyberware (identifier, character_key, item) VALUES (?, ?, ?)", { st.identifier, st.key, add })
        st.installed[add] = true
    end
end

local function seated(playerId)
    if not C.seatedOnly then return true end
    return LightRP.ripperdoc and LightRP.ripperdoc.isSeated and LightRP.ripperdoc.isSeated(playerId) or false
end

--- op: "install" | "remove". done(ok, message) is called once, possibly much later (surgery).
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
        local paid = LightRP.money.removeBank(playerId, C.removalFee, "cyberware", "Implant removal: " .. item.name)
        if not paid then return refuse(done, "The removal costs " .. LightRP.money.format(C.removalFee) .. ".") end
        st.busy = op
        CreateThread(function()
            if item.kind == "blades" then sheathe(playerId) end
            local ok, why = true, nil
            if item.kind == "legs" or item.kind == "arms" then ok, why = platform(playerId, "remove", item) end
            if state[playerId] ~= st then return end
            st.busy = nil
            if not ok then
                LightRP.money.addBank(playerId, C.removalFee, "refund", "Implant removal refund")
                log("removal of %s for %d failed: %s", item.id, playerId, tostring(why))
                return done(false, "The extraction failed (" .. tostring(why) .. "). You were refunded.")
            end
            store(st, nil, item.id)
            applyAll(playerId)
            log("%d removed %s", playerId, item.id)
            done(true, item.name .. " removed.")
        end)
        return true
    end

    if op ~= "install" then return refuse(done, "Unknown operation.") end
    if st.installed[item.id] then return refuse(done, "Already installed.") end
    -- No limit: anything can be fitted. A family is one native slot (the arm slot, the legs, the
    -- dash, the overdrive...): another model of it simply replaces the one installed.
    local replaced = familyOf(st, item.family)
    local charged, why = chargeOrFail(playerId, item)
    if not charged then return refuse(done, why) end
    st.busy = op
    CreateThread(function()
        local ok, reason = true, nil
        -- Leaving the arm slot: Gorilla Arms out before the blades, blades sheathed before Gorilla Arms.
        if replaced and replaced.kind == "blades" then sheathe(playerId, false) end
        if replaced and replaced.kind == "arms" and item.kind ~= "arms" then ok, reason = platform(playerId, "remove", replaced) end
        if ok and (item.kind == "legs" or item.kind == "arms") then ok, reason = platform(playerId, "install", item) end
        if state[playerId] ~= st then return end
        st.busy = nil
        if not ok then
            refund(playerId, item)
            log("install of %s for %d failed: %s", item.id, playerId, tostring(reason))
            return done(false, "The surgery failed (" .. tostring(reason) .. "). You were refunded.")
        end
        store(st, item.id, replaced and replaced.id or nil)
        applyAll(playerId)
        log("%d installed %s%s", playerId, item.id, replaced and (" over " .. replaced.id) or "")
        done(true, item.name .. " installed.")
    end)
    return true
end

-- ---------------------------------------------------------------------------
-- Lifecycle

local function load(playerId, c)
    local previous = state[playerId]
    if previous and previous.drawn then sheathe(playerId, false) end
    if not c or not c.identifier then state[playerId] = nil return end
    local st = { identifier = c.identifier, key = c.key, installed = {}, baseline = previous and previous.baseline }
    if Db.ready then
        for _, row in ipairs(Db.query("SELECT item FROM lightrp_cyberware WHERE identifier = ? AND character_key = ?",
            { c.identifier, c.key }) or {}) do
            if byId[row.item] then st.installed[row.item] = true end
        end
    end
    state[playerId] = st
    CreateThread(function()
        Wait(1500)
        if state[playerId] ~= st then return end
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
        return
    end
    CreateThread(function() Wait(1500) applyAll(playerId) end)
end

function Cyber.onDisconnected(playerId) state[playerId] = nil end

-- Body, bucket and session changes invalidate session grants on the platform side: every 10 s
-- whatever an implant should grant and is missing is granted again.
CreateThread(function()
    while true do
        Wait(10000)
        for playerId, st in pairs(state) do
            if not st.granting and alive(playerId) then
                for _, kind in ipairs({ "dash", "overdrive", "slam" }) do
                    local item = familyOf(st, kind)
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
        for _, kind in ipairs({ "dash", "overdrive", "slam" }) do pcall(grantFamily, playerId, kind, nil) end
    end
end)

-- Staff: lightrp.cyberware <playerId> [list|status|blades|give <item>|take <item>]
RegisterCommand("lightrp.cyberware", function(src, args)
    local target = tonumber(args[1])
    local st = target and state[target]
    local function reply(text) if tonumber(src) and tonumber(src) > 0 then LightRP.result(tonumber(src), true, text) else print(text) end end
    if not st then return reply("usage: lightrp.cyberware <playerId> [list|status|give <item>|take <item>] (player must be loaded)") end
    local verb, itemId = args[2] or "list", args[3]
    if verb == "list" then
        local names = {}
        for _, item in ipairs(installedList(st)) do names[#names + 1] = item.id end
        return reply(("cyberware of %d: %s"):format(target, #names > 0 and table.concat(names, ", ") or "none"))
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
            if item.kind == "legs" or item.kind == "arms" then
                local ok, why = platform(target, "install", item)
                if not ok then return reply("platform refused: " .. tostring(why)) end
            elseif replaced and replaced.kind == "arms" then platform(target, "remove", replaced) end
            store(st, item.id, replaced and replaced.id ~= item.id and replaced.id or nil)
        elseif verb == "take" then
            if item.kind == "legs" or item.kind == "arms" then platform(target, "remove", item) end
            if item.kind == "blades" then sheathe(target) end
            store(st, nil, item.id)
        end
        applyAll(target)
        reply(("cyberware %s %s for %d"):format(verb, item.id, target))
    end)
end, true)
