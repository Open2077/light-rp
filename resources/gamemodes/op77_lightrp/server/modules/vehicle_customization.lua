local lightrpEvery = LightRP.every or function(ms, fn) while true do Wait(tonumber(ms) or 1000); fn() end end -- framework.lua (tests: the plain loop, in the calling thread)
local expireFlags = LightRP.expireFlags or function() end -- framework.lua
local G, C = LightRP.garage, LightRpVehicleCustomization
local Custom = LightRP.module("vehicleCustomization", {})
local NET = LightRpEvents.net.customization
local P, KIT = LightRpCustomizationPricing, LightRpVehicleKit
local sessions, sequence, stageAt, stageTriedAt = {}, 0, {}, {}
local NS = (type(GetCurrentResourceName) == "function" and GetCurrentResourceName() or "op77_lightrp") .. ":"
-- Server quotes (server/config/vehicle_customization.lua): a flat price per category,
-- per changed group for the body kit, per stage for performance.
local prices = {}
for _, category in ipairs(C.categories) do
    if not category.soon and category.id ~= "performance" then
        prices[category.id] = assert(LightRP.money.validAmount(P[category.id]), "Invalid " .. category.id .. " price")
    end
end
local removal = assert(LightRP.money.validAmount(P.performanceRemoval), "Invalid performance removal price")
for model, list in pairs(P.performance or {}) do
    for stage = 1, C.stages.max do assert(LightRP.money.validAmount(list[stage]), "Invalid stage price: " .. model) end
end
-- Every vanilla player car and bike the stage pack stages, by record
-- (server/config/vehicle_stage_catalogue.lua, generated with the pack): a catalogue key in
-- P.performance keeps its curated prices, any other model is priced by its record.
local STAGED = type(LightRpVehicleStageCatalogue) == "table" and type(LightRpVehicleStageCatalogue.models) == "table"
    and LightRpVehicleStageCatalogue.models or {}
for record, entry in pairs(STAGED) do
    for stage = 1, C.stages.max do
        assert(LightRP.money.validAmount(type(entry.prices) == "table" and entry.prices[stage]), "Invalid generated stage price: " .. record)
    end
end
local function stagePrices(model, record)
    local list = (P.performance or {})[model]
    if type(list) == "table" then return list end
    local entry = STAGED[LightRpConfig.baseRecord(record)]
    return entry and entry.prices or nil
end
local SAVED = {
    paint = "Paint purchased and saved to your vehicle.",
    lights = "Light tint purchased and saved to your vehicle.",
    trim = "Trim purchased and saved to your vehicle.",
    livery = "Livery purchased and saved to your vehicle.",
    rims = "Rims purchased and saved to your vehicle.",
    body = "Body kit purchased and saved to your vehicle.",
    neon = "Neon purchased and saved to your vehicle.",
    plate = "Plate registered to your vehicle.",
    windows = "Window tint purchased and saved to your vehicle.",
    performance = "Stage fitted and saved to your vehicle.",
    neonAnimation = "Neon animation purchased and saved to your vehicle.",
    lightColors = "Lamp colors purchased and saved to your vehicle.",
    engineSound = "Engine sound fitted and saved to your vehicle.",
    stickers = "Stickers purchased and saved to your vehicle.",
    tag = "Tag painted and saved to your vehicle.",
}
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for k, v in pairs(value) do out[k] = copy(v) end; return out
end
-- What the client's json.decode accepts in one text (the net event reader's cap, 1024
-- values, every table and leaf counted); kept with a margin.
local JSON_VALUES = 1000
local function countValues(value)
    if type(value) ~= "table" then return 1 end
    local n = 1; for _, v in pairs(value) do n = n + countValues(v) end; return n
end
local function native(...)
    for _, name in ipairs({ ... }) do if type(Open77.vehicles[name]) ~= "function" then return false end end
    return true
end
local function running(resource)
    local state = type(GetResourceState) == "function" and GetResourceState(resource) or nil
    return state == "running"
end
local function wallet(id)
    local w = LightRP.money.get(id)
    if w then return { cash = w.cash, bank = w.bank, currency = LightRpConfig.economy.currency } end
end
local function close(id)
    local s = sessions[id]; if not s then return end
    sessions[id] = nil
    G.endCustomization(id, s.id)
    -- The studio kept the empty car's engine running so an engine sound could be heard:
    -- stop it (setEngine false also ends the hold) once the confirmed look is back.
    if s.engineHeld and type(Open77.vehicles.setEngine) == "function" then pcall(Open77.vehicles.setEngine, s.vehicle, false) end
    -- The lamps a lamp preview switched on go back off.
    if s.lampsBefore and type(Open77.vehicles.setLights) == "function" then pcall(Open77.vehicles.setLights, s.vehicle, s.lampsBefore) end
    TriggerClientEvent(NET, id, { kind = "closed", session = s.id })
end
local function color(value) return type(value) == "string" and value:match("^#%x%x%x%x%x%x$") and value:upper() or nil end
local function channels(hex) return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16) end
-- HSV saturation (0..1) of "#RRGGBB": the engine keeps a single hue for the lights.
local function saturation(hex)
    local r, g, b = channels(hex)
    local high, low = math.max(r, g, b), math.min(r, g, b)
    return high == 0 and 0 or (high - low) / high
end
local function brightness(hex) local r, g, b = channels(hex); return math.max(r, g, b) / 255 end
local function hexOf(rgb)
    if type(rgb) == "string" then return color(rgb) end
    if type(rgb) == "table" then return string.format("#%02X%02X%02X", rgb.r or rgb[1] or 0, rgb.g or rgb[2] or 0, rgb.b or rgb[3] or 0) end
end
local function trimsOf(model)
    local list = type(C.trims) == "table" and C.trims[model]
    return type(list) == "table" and list or {}
end

-- The vehicle kit (server/config/vehicle_kit.lua) ------------------------------------
-- One registerParts call per part: a call is atomic and the Lua->JSON marshaller caps
-- one call's size. A server whose rim fits predate per-wheel lists refuses `wheels`:
-- such a rim is registered with its fit-level values on the default wheel slots, and a
-- record that needs other slots (Merrimac middle axle, Apollo) loses the rim.
local registered = { rims = {}, body = {} }
local groupOf, partLabel = {}, {}
local DEFAULT_SLOTS = { wheel_front_left = true, wheel_front_right = true, wheel_back_left = true,
    wheel_back_right = true, wheel_front = true, wheel_back = true }
local function legacyRim(entry)
    local out = { kind = entry.kind, label = entry.label, variants = copy(entry.variants), fit = {} }
    for record, fit in pairs(entry.fit) do
        local plain, keep = copy(fit), true
        plain.wheels = nil
        for _, wheel in ipairs(fit.wheels or {}) do if not DEFAULT_SLOTS[wheel.slot] then keep = false end end
        if keep then out.fit[record] = plain end
    end
    return out
end
-- Curated trims (server/config/vehicle_kit_trims.lua): a trim is another entity appearance
-- whose stock rims carry other component names, and often other sizes, than the default
-- appearance the kit was measured on. A rim fit carries them as `appearances` overrides,
-- resolved by the platform from the car's current appearance. A server that predates
-- them refuses the key (`invalid_part:<id>.fit.appearances`): the rims then register with
-- the record fit alone and every trim's hide names merged into it (the client skips a
-- name the current appearance lacks), so the stock rims stay hidden under the default
-- fit. Body parts always merge their trims' extra names into the record fit.
local TRIMS = type(LightRpVehicleKitTrims) == "table" and LightRpVehicleKitTrims or {}
local appearanceFits = true -- false once this server refused fit.appearances
local function mergeHides(fit, byAppearance, field)
    local hide, seen = {}, {}
    local function add(name) if not seen[name] then seen[name] = true; hide[#hide + 1] = name end end
    for _, name in ipairs(fit.hide or {}) do add(name) end
    local appearances = {}
    for appearance in pairs(byAppearance) do appearances[#appearances + 1] = appearance end
    table.sort(appearances)
    for _, appearance in ipairs(appearances) do
        local names = byAppearance[appearance]
        if field then names = names[field] end
        for _, name in ipairs(names or {}) do add(name) end
    end
    fit.hide = hide
end
-- Player vehicles beyond the dealer table (server/config/vehicle_kit_player_rims.lua,
-- generated): every other vanilla Vehicle.*_player* record whose rims were measured,
-- merged into each rim part under the dealer fits (a record both name keeps the dealer
-- fit and its trims). Some carry their own `appearances` entries (a record whose spawned
-- appearance is not fixed); a server without per-appearance fits gets their hide names
-- merged into the record fit instead, as for the trims.
local PLAYER_RIMS = type(LightRpVehicleKitPlayerRims) == "table" and type(LightRpVehicleKitPlayerRims.fit) == "table"
    and LightRpVehicleKitPlayerRims.fit or {}
local function withPlayerRims(section, entry)
    if section ~= "rims" then return entry end
    entry.fit = entry.fit or {}
    for record, fit in pairs(PLAYER_RIMS) do
        if entry.fit[record] == nil then entry.fit[record] = copy(fit) end
    end
    return entry
end
-- The kit entry with its trims: per-appearance rim overrides, or (perAppearance false)
-- the rims' trim hide names merged into the record fit.
local function withTrims(section, id, entry, perAppearance)
    for record, fit in pairs(entry.fit or {}) do
        local trims = section == "rims" and type(TRIMS.rims) == "table" and TRIMS.rims[record]
        local extra = section == "body" and type(TRIMS.body) == "table" and type(TRIMS.body[id]) == "table" and TRIMS.body[id][record]
        if type(trims) == "table" then
            if perAppearance then fit.appearances = copy(trims) else mergeHides(fit, trims, "hide") end
        elseif type(fit.appearances) == "table" and not perAppearance then
            mergeHides(fit, fit.appearances, "hide"); fit.appearances = nil
        end
        if type(extra) == "table" then mergeHides(fit, extra) end
    end
    return entry
end
-- Carried parts (contract section 5): a wing or louvers name the trunk lid's slot as
-- their `carrier`, a scoop or vents the hood's, so they follow the panel when it opens.
-- A server that predates carriers refuses the key (`invalid_part:<id>.carrier`, or
-- `.fit.carrier`): the kit then registers without any carrier, every part on its slot
-- as before (it stays put when the lid opens).
local carriers = true -- false once this server refused `carrier`
local function withoutCarrier(entry)
    entry.carrier = nil
    for _, fit in pairs(entry.fit or {}) do fit.carrier = nil end
    return entry
end
local function kitEntry(section, id, source)
    local entry = withTrims(section, id, withPlayerRims(section, copy(source)), appearanceFits)
    return carriers and entry or withoutCarrier(entry)
end
local function bodyOrder()
    local list = {}
    for _, group in ipairs(KIT.body.groups) do
        for _, id in ipairs(group.parts) do list[#list + 1] = id; groupOf[id] = group.id end
    end
    return list
end
local function registerKit()
    if type(KIT) ~= "table" then return end
    local order = { rims = KIT.rims.order, body = bodyOrder() }
    if not native("registerParts") then LightRP.log("auto studio: no registerParts on this server build; rims and body kit are off"); return end
    local count, degraded = 0, 0
    for _, section in ipairs({ "rims", "body" }) do
        for _, id in ipairs(order[section]) do
            local source = KIT[section].parts[id]
            partLabel[id] = source.label
            local ok, why = Open77.vehicles.registerParts({ [id] = kitEntry(section, id, source) })
            -- Each fallback is taken once for the whole kit, in whichever order the server
            -- reports them (it names the first key it refuses).
            for _ = 1, 2 do
                if ok then break end
                local reason = tostring(why)
                if appearanceFits and reason:find("fit.appearances", 1, true) then
                    appearanceFits = false
                    LightRP.log("auto studio: no per-appearance fits on this server build (%s); trims wear the default rim fit, their stock rims hidden", reason)
                elseif carriers and reason:find("%.carrier$") then
                    carriers = false
                    LightRP.log("auto studio: no carried parts on this server build (%s); wings and hood parts stay on the body when a lid opens", reason)
                else
                    break
                end
                ok, why = Open77.vehicles.registerParts({ [id] = kitEntry(section, id, source) })
            end
            if not ok and section == "rims" and tostring(why):find("wheels", 1, true) then
                ok, why = Open77.vehicles.registerParts({ [id] = legacyRim(withTrims(section, id, withPlayerRims(section, copy(source)), false)) })
                if ok then degraded = degraded + 1 end
            end
            registered[section][id] = ok and true or nil
            if ok then count = count + 1 else LightRP.log("auto studio: part %s not registered (%s)", id, tostring(why)) end
        end
    end
    LightRP.log("auto studio: %d kit parts registered%s", count,
        degraded > 0 and string.format(", %d rims without per-wheel fits (server predates them)", degraded) or "")
end
registerKit()
local function localId(id) return type(id) == "string" and id:sub(1, #NS) == NS and id:sub(#NS + 1) or nil end
local function finishes(variants)
    local list = {}
    for _, finish in ipairs(KIT.finishOrder or {}) do
        if variants[finish] then list[#list + 1] = { id = finish, label = (KIT.finishes or {})[finish] or finish } end
    end
    for finish in pairs(variants) do
        local known = false
        for _, f in ipairs(list) do if f.id == finish then known = true end end
        if not known then list[#list + 1] = { id = finish, label = finish } end
    end
    return list
end
-- The registered kit parts that fit this vehicle, by local id.
local function fitting(vehicleId, kind)
    local out = {}
    if not native("listParts") then return out end
    for _, part in ipairs(Open77.vehicles.listParts(vehicleId) or {}) do
        local id = localId(part.id)
        if id and registered[kind][id] and type(part.variants) == "table" then out[id] = part.variants end
    end
    return out
end

-- Performance stages ----------------------------------------------------------------
-- The record of `stage` for a dealer record, from the stage resource (never from a client).
local function stageRecord(base, stage)
    if stage == 0 then return base end
    if not running(C.stages.resource) or type(Open77.exports) ~= "table" then return nil end
    local ok, record = pcall(Open77.exports.callSync, C.stages.resource, "stageRecord", base, stage)
    return ok and type(record) == "string" and record ~= "" and record or nil
end
G.setStageResolver(stageRecord)
local function stageOf(state) return math.tointeger(tonumber(type(state.lightrp) == "table" and state.lightrp.stage or 0) or 0) or 0 end
-- An engine sound is a record per model and stage, and the pack may lack one (a combination
-- dropped for a TweakDBID collision, STAGES.md of the generator): true when the platform
-- lists `sound` for `record` (a vehicle id or a record), or cannot tell.
local STAGE_SOUND = "Your engine sound has no version for this stage: fit another engine sound first."
local function soundFits(record, sound)
    if type(sound) ~= "string" or sound == "" or record == nil then return true end
    if type(Open77.vehicles.listEngineSounds) ~= "function" then return true end
    local list = Open77.vehicles.listEngineSounds(record)
    if type(list) ~= "table" then return true end -- the platform decides, and refuses by name
    for _, s in ipairs(list) do if type(s) == "table" and s.id == sound then return true end end
    return false
end

-- Registration plates ---------------------------------------------------------------
-- A word is found in the plate as written, or in its "leet" reading (SH1T reads SHIT).
-- A word with digits (1488, SS88) is a deliberate code: matched as written only.
local LEET = { ["0"] = "O", ["1"] = "I", ["3"] = "E", ["4"] = "A", ["5"] = "S", ["7"] = "T", ["8"] = "B", ["9"] = "G" }
local function reading(text) return (text:gsub("%d", LEET)) end
local words = {}
for _, list in ipairs({ { "banned", (LightRpCustomizationPlates or {}).banned }, { "reserved", (LightRpCustomizationPlates or {}).reserved } }) do
    for _, word in ipairs(list[2] or {}) do
        word = tostring(word):upper()
        words[#words + 1] = { kind = list[1], raw = word, leet = not word:find("%d") }
    end
end
local function plateFormat()
    local p = C.plate
    local size = p.minLength == p.maxLength and tostring(p.minLength) or (p.minLength .. " to " .. p.maxLength)
    return "A plate is " .. size .. " characters: capital letters A-Z and digits 0-9."
end
-- "banned" | "reserved" | nil: the first listed word in `text` (upper case, letters and
-- digits only), as written or in its leet reading. Shared by plates and tags.
local function forbiddenWord(text)
    local read = reading(text)
    for _, word in ipairs(words) do
        if text:find(word.raw, 1, true) or (word.leet and read:find(word.raw, 1, true)) then return word.kind end
    end
end
-- nil when `plate` (already upper case) may be registered to the owned vehicle `rowId`.
local function plateProblem(plate, rowId)
    local p = C.plate
    if #plate < p.minLength or #plate > p.maxLength or not plate:match(p.pattern) then return plateFormat() end
    local kind = forbiddenWord(plate)
    if kind then return kind == "reserved" and "This plate is reserved for city services." or "This plate is not allowed." end
    if G.plateTaken(plate, rowId) then return "This plate is already registered to another vehicle." end
end
Custom.plateProblem = plateProblem

-- Wave 2: neon animation, lamp colours, engine sound, stickers, tag ------------------
-- (PLAN-vehicle-custom-wave2.md, shared contract). Each is one getProperties field, read
-- and written by its own natives, all feature-detected. The garage stores them through
-- its category registry (Garage.registerCustomizationCategory): a server whose garage
-- predates it greys them, since an autosave there would keep a preview or lose a purchase.
local EXTRA_ORDER = { "neonAnimation", "lightColors", "stickers", "tag", "engineSound" }
local EMERGENCY = "This color reads as an emergency light: choose another."
local function rgbOf(hex) local r, g, b = channels(hex); return { r = r, g = g, b = b } end
local function hueOf(hex)
    local r, g, b = channels(hex)
    local high, low = math.max(r, g, b), math.min(r, g, b)
    local d = high - low
    if d == 0 then return 0 end
    local h
    if high == r then h = ((g - b) / d) % 6 elseif high == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
    return (h * 60) % 360
end
local function within(h, range)
    if range.from <= range.to then return h >= range.from and h <= range.to end
    return h >= range.from or h <= range.to
end
-- "red" | "blue" | nil for "#RRGGBB": the colours an emergency light alternates.
local function emergencyClass(hex)
    local E = C.emergency
    if type(hex) ~= "string" or saturation(hex) < E.minSaturation then return nil end
    local h = hueOf(hex)
    if within(h, E.red) then return "red" elseif within(h, E.blue) then return "blue" end
end
local function emergencyPair(a, b)
    local x, y = emergencyClass(a), emergencyClass(b)
    return x ~= nil and y ~= nil and x ~= y
end
-- Where getProperties keeps a wave 2 field: in `visual` with the rest of the open77.visual
-- bag, or at the top level (the contract names the keys, not their table). Read either;
-- a copy is written where its source keeps it.
local function field(props, key)
    if type(props) ~= "table" then return nil end
    if type(props.visual) == "table" and props.visual[key] ~= nil then return props.visual[key] end
    return props[key]
end
local function ownField(key)
    return function(to, from)
        local inVisual = type(from) == "table" and type(from.visual) == "table" and from.visual[key] ~= nil
        local value = copy(field(from, key))
        if type(to.visual) == "table" then to.visual[key] = nil end
        to[key] = nil
        if value == nil then return end
        if inVisual then to.visual = type(to.visual) == "table" and to.visual or {}; to.visual[key] = value else to[key] = value end
    end
end
local function modeOf(id)
    for _, mode in ipairs(C.neonAnimation.modes) do if mode.id == id then return mode end end
end
-- Comparison keys: the same choice in the studio's form and in the native's form.
local function colorKey(value) return hexOf(value) or "" end
local KEYS = {
    neonAnimation = function(a)
        if type(a) ~= "table" or a.mode == nil then return "static" end
        local mode = modeOf(a.mode) or {}
        local period = mode.speed and tostring(math.floor((tonumber(a.periodMs) or 0) + 0.5)) or ""
        return tostring(a.mode) .. "@" .. period .. "/" .. (mode.color2 and a.color2 and colorKey(a.color2) or "")
    end,
    lightColors = function(l)
        if type(l) ~= "table" then return "factory" end
        local out = {}
        for _, group in ipairs(C.lightColors.groups) do
            if l[group.id] ~= nil then out[#out + 1] = group.id .. "=" .. colorKey(l[group.id]) end
        end
        return #out > 0 and table.concat(out, ",") or "factory"
    end,
    engineSound = function(id) return type(id) == "string" and id or "" end,
    stickers = function(list)
        local out = {}
        for _, id in ipairs(type(list) == "table" and list or {}) do out[#out + 1] = tostring(id) end
        table.sort(out)
        return table.concat(out, ",")
    end,
    tag = function(t)
        if type(t) ~= "table" then return "" end
        return table.concat({ tostring(t.text), tostring(t.font), colorKey(t.color), tostring(t.spot) }, "|")
    end,
}
-- Native refusals a player can act on. The contract does not name them: these are the names
-- the wave 2 natives branch uses (vc/wave2-natives, 2026-11-06, `emergency_look:<what>` with a
-- suffix), plus earlier guesses. An unknown reason is shown with the category's text and the
-- raw reason.
local DECALS = "Too many decals on this vehicle: remove a sticker or choose a lighter livery."
local NO_SOUND = "This engine sound does not fit this vehicle."
local REFUSED = {
    vehicle_occupied = "Everyone must step out of the vehicle first.",
    decal_budget_exceeded = DECALS, decal_budget = DECALS, decal_limit = DECALS, too_many_decals = DECALS,
    emergency_look = EMERGENCY, emergency_colors = EMERGENCY, emergency_colours = EMERGENCY, emergency_lights = EMERGENCY,
    strobe_too_fast = "This strobe is too fast.",
    unknown_engine_sound = NO_SOUND, engine_sound_not_for_model = NO_SOUND, engine_sound_not_for_class = NO_SOUND,
    unknown_sound = NO_SOUND, sound_not_for_model = NO_SOUND,
    engine_sound_not_for_stage = "This engine sound is not made for this vehicle's performance stage.",
    engine_sound_unregistered = "Engine sounds are not installed on this server right now.",
    unknown_sticker = "This sticker does not fit this vehicle.", sticker_not_for_model = "This sticker does not fit this vehicle.",
    invalid_tag = "This tag cannot be painted.", banned_text = "This tag is not allowed.",
}
local function refusal(why, text)
    local known = REFUSED[why] or (type(why) == "string" and REFUSED[why:match("^([^:]+):")]) or nil
    return known or (text .. " (" .. tostring(why) .. ")")
end
-- `set`/`get`: the natives. `value(change)`: the native's argument for a validated change
-- (nil = factory). `respawns`: applying it rebuilds the car, restored after the stage.
local EXTRA = {
    neonAnimation = { set = "setNeonAnimation", get = "getNeonAnimation",
        receipt = { "vehicle_neon_anim", "Neon animation for vehicle " }, refused = "The neon animation was refused",
        unchanged = "Choose a different animation before purchasing.",
        value = function(change) return change.animation and copy(change.animation) or nil end },
    lightColors = { set = "setLightColors", get = "getLightColors",
        receipt = { "vehicle_lamps", "Lamp colors for vehicle " }, refused = "These lamp colors were refused",
        unchanged = "Choose different lamp colors before purchasing.",
        value = function(change)
            if not change.lamps then return nil end
            local out = {}; for group, hex in pairs(change.lamps) do out[group] = rgbOf(hex) end; return out
        end },
    stickers = { set = "setStickers", get = "getStickers",
        receipt = { "vehicle_stickers", "Stickers for vehicle " }, refused = "These stickers were refused",
        unchanged = "Change at least one sticker before purchasing.",
        value = function(change) return change.stickers and copy(change.stickers) or nil end },
    tag = { set = "setTag", get = "getTag",
        receipt = { "vehicle_tag", "Painted tag for vehicle " }, refused = "The tag was refused",
        unchanged = "This vehicle already wears that tag.",
        value = function(change)
            if not change.tag then return nil end
            return { text = change.tag.text, font = change.tag.font, color = rgbOf(change.tag.color), spot = change.tag.spot }
        end },
    engineSound = { set = "setEngineSound", get = "getEngineSound", respawns = true,
        receipt = { "vehicle_engine_sound", "Engine sound for vehicle " }, refused = "The engine sound could not be fitted",
        unchanged = "This engine sound is already fitted.",
        value = function(change) return change.sound or nil end,
        -- A stored sound the car's record has no version of (the pack dropped that stage and
        -- sound for a TweakDBID collision, or is stopped) stays dormant at delivery.
        fits = function(record, sound) return soundFits(record, sound) end },
}
-- What the car wears now: the native's getter, else its getProperties field.
local function wearing(name, vehicleId)
    local spec, V = EXTRA[name], Open77.vehicles
    if type(V[spec.get]) == "function" then return V[spec.get](vehicleId) end
    return field(type(V.getProperties) == "function" and V.getProperties(vehicleId) or nil, name)
end
local function put(name, vehicleId, value)
    local spec = EXTRA[name]
    local set = Open77.vehicles[spec.set]
    if type(set) ~= "function" then return false, C.unsupported.native end
    -- a restatement would rebuild the car (engine sound) or re-render for nothing
    if KEYS[name](wearing(name, vehicleId)) == KEYS[name](value) then return true end
    local ok, why = set(vehicleId, value)
    if not ok then return false, refusal(why, spec.refused) end
    return true
end
local registry = type(G.registerCustomizationCategory) == "function"
if registry then
    for _, name in ipairs(EXTRA_ORDER) do
        local spec = EXTRA[name]
        G.registerCustomizationCategory(name, {
            owns = ownField(name), receipt = spec.receipt, respawns = spec.respawns == true, fits = spec.fits,
            -- a build without the setter keeps a stored value dormant on the row
            available = function() return type(Open77.vehicles[spec.set]) == "function" end,
            apply = function(vehicleId, change) return put(name, vehicleId, spec.value(change)) end,
            -- Nothing of it can be on a car of a server without its setter: nothing to restore.
            restore = function(vehicleId, state)
                if type(Open77.vehicles[spec.set]) ~= "function" then return true end
                return put(name, vehicleId, copy(field(state, name)))
            end,
            unchanged = function(change, saved) return KEYS[name](spec.value(change)) == KEYS[name](field(saved, name)), spec.unchanged end,
        })
    end
else
    LightRP.log("auto studio: this garage has no category registry; neon animation, lamp colors, engine sound, stickers and tag are greyed")
end
Custom.extraCategoriesStored = registry

-- The decal budget left for stickers: getDecalBudget counts the livery and the stickers the
-- car wears now; `base` is everything but those stickers.
local function stickerBudget(vehicleId, catalogue)
    local V = Open77.vehicles
    if type(V.getDecalBudget) ~= "function" then return nil end
    local used, maximum = V.getDecalBudget(vehicleId)
    if type(used) == "table" then used, maximum = used.used, used.maximum end
    used, maximum = tonumber(used), tonumber(maximum)
    if not used or not maximum then return nil end
    local decals, mine = {}, 0
    for _, sticker in ipairs(catalogue or {}) do decals[sticker.id] = tonumber(sticker.decals) or 1 end
    local held = type(V.getStickers) == "function" and V.getStickers(vehicleId) or nil
    for _, id in ipairs(type(held) == "table" and held or {}) do mine = mine + (decals[id] or 1) end
    return { base = math.max(0, used - mine), maximum = maximum }
end
local function neonColorOf(visual)
    local neon = type(visual) == "table" and visual.neon or nil
    if type(neon) == "table" and neon.enabled ~= false then return hexOf(neon.color) end
end
-- The neon colour the car shows now, and the one its owner bought.
local function shownNeon(s) return native("getVisual") and neonColorOf(Open77.vehicles.getVisual(s.vehicle)) or nil end
local function confirmedState(s) return G.customizationState(s.player, s.id) or {} end
local function boughtNeon(s) return neonColorOf(confirmedState(s).visual) end
-- A neon colour and an animation that together read as an emergency light: a red or blue
-- strobe, a chase alternating red and blue.
local function emergencyAnimation(base, animation)
    if type(animation) ~= "table" or not base then return false end
    if animation.mode == "strobe" then return emergencyClass(base) ~= nil end
    if animation.mode == "chase" and animation.color2 then return emergencyPair(base, hexOf(animation.color2)) end
    return false
end
-- True when the car shows a preview of `name` (or of the livery) instead of what was bought.
local function previewing(s, name)
    if name == "profile" then
        if not native("getVisual") then return false end
        local shown = Open77.vehicles.getVisual(s.vehicle)
        local bought = confirmedState(s).visual
        return (type(shown) == "table" and shown.profile or nil) ~= (type(bought) == "table" and bought.profile or nil)
    end
    if type(Open77.vehicles[EXTRA[name].get]) ~= "function" then return false end
    return KEYS[name](wearing(name, s.vehicle)) ~= KEYS[name](field(confirmedState(s), name))
end
local function stickersSold(s) local c = s.categories.stickers; return c ~= nil and c.available == true end

-- What this vehicle's model offers. An unknown model, or a model/category absent from
-- the support table, keeps paint and lights (no regression); `false` greys a category.
-- Trim only appears for a model with curated entries; every other category is listed,
-- greyed with its reason when this vehicle, this server or its packs cannot do it.
local OFFER = {
    trim = function(entry, state)
        local trims = trimsOf(state.model)
        if #trims == 0 then return nil end
        entry.options = {}
        for i, trim in ipairs(trims) do entry.options[i] = { id = trim.id, label = trim.label } end
        return entry
    end,
    livery = function(entry, state)
        if not native("listPaintProfiles", "setPaintProfile", "getVisual") then return entry, C.unsupported.native end
        entry.options = {}
        -- Factory schemes have no name of their own ("Scheme N", counted among them only);
        -- a livery a resource registered (registerPaintProfiles) carries its label.
        local factory = 0
        for i, profile in ipairs(Open77.vehicles.listPaintProfiles(state.vehicleId) or {}) do
            local label = profile.resource and type(profile.label) == "string" and profile.label ~= "" and profile.label
            if not label then factory = factory + 1; label = "Scheme " .. factory end
            entry.options[i] = { id = profile.id, label = label, main = hexOf(profile.main), secondary = hexOf(profile.sec) }
        end
        if #entry.options == 0 then return entry, C.unsupported.livery end
        return entry
    end,
    rims = function(entry, state)
        if not native("listParts", "setWheels", "getVisual") or type(KIT) ~= "table" then return entry, C.unsupported.native end
        if not running(KIT.rims.pack) then return entry, C.unsupported.rimsPack end
        local fits = fitting(state.vehicleId, "rims")
        entry.pack, entry.options = KIT.rims.pack, {}
        for _, id in ipairs(KIT.rims.order) do
            if fits[id] then entry.options[#entry.options + 1] = { id = id, label = partLabel[id] or id, variants = finishes(fits[id]) } end
        end
        if #entry.options == 0 then return entry, C.unsupported.rims end
        return entry
    end,
    body = function(entry, state)
        if not native("listParts", "setParts", "getVisual") or type(KIT) ~= "table" then return entry, C.unsupported.native end
        if not running(KIT.body.pack) then return entry, C.unsupported.bodyPack end
        local fits = fitting(state.vehicleId, "body")
        entry.pack, entry.options = KIT.body.pack, {}
        for _, group in ipairs(KIT.body.groups) do
            local parts = {}
            for _, id in ipairs(group.parts) do
                if fits[id] then parts[#parts + 1] = { id = id, label = partLabel[id] or id, variants = finishes(fits[id]) } end
            end
            if #parts > 0 then entry.options[#entry.options + 1] = { id = group.id, label = group.label, parts = parts } end
        end
        if #entry.options == 0 then return entry, C.unsupported.body end
        return entry
    end,
    neon = function(entry)
        if not native("setNeon", "clearNeon", "getVisual") then return entry, C.unsupported.native end
        entry.options = { colors = copy(C.neon.colors), intensities = copy(C.neon.intensities) }
        return entry
    end,
    plate = function(entry)
        -- Sold only where `setPlate` draws it on the car: without it the plate was paid for and
        -- never shown (garages.lua renderPlate keeps a stored plate's data side only).
        if not native("setPlate") then return entry, C.unsupported.native end
        entry.options ={ minLength = C.plate.minLength, maxLength = C.plate.maxLength, charset = C.plate.charset }
        return entry
    end,
    windows = function(entry)
        if C.windows.enabled ~= true then return entry, C.unsupported.windowsSoon end
        if not native("setWindowTint", "getVisual") then return entry, C.unsupported.native end
        if not running(C.windows.resource) then return entry, C.unsupported.windowsPack end
        entry.pack, entry.options = C.windows.resource, {}
        for i, level in ipairs(C.windows.levels) do entry.options[i] = { id = level.id, label = level.label, level = level.level } end
        return entry
    end,
    performance = function(entry, state)
        local list = stagePrices(state.model, state.record)
        if not native("respawnAs") then return entry, C.unsupported.native end
        if type(list) ~= "table" then return entry, C.unsupported.performance end
        if not running(C.stages.resource) then return entry, C.unsupported.stagesPack end
        entry.options = { current = stageOf(state), removal = removal, stages = {} }
        -- a stage keeps the car's engine sound: one the pack has no record of at that stage
        -- greys it (the platform would refuse it, engine_sound_not_for_stage)
        local sound = state.vehicleId and wearing("engineSound", state.vehicleId) or nil
        local any = false
        for stage = 0, C.stages.max do
            local record = stageRecord(state.record, stage)
            any = any or (stage > 0 and record ~= nil)
            local fits = record == nil or soundFits(record, sound)
            entry.options.stages[stage + 1] = { stage = stage, label = C.stages.labels[stage], price = list[stage],
                record = record, available = record ~= nil and fits, reason = not fits and STAGE_SOUND or nil }
        end
        if not any then return entry, C.unsupported.performance end
        return entry
    end,
    -- Wave 2 ------------------------------------------------------------------------
    neonAnimation = function(entry)
        if not native("setNeonAnimation", "getVisual") then return entry, C.unsupported.native end
        local A = C.neonAnimation
        entry.options = { modes = copy(A.modes), speeds = {}, colors = copy(C.neon.colors) }
        for i, speed in ipairs(A.speeds) do entry.options.speeds[i] = { id = speed.id, label = speed.label } end
        return entry
    end,
    lightColors = function(entry)
        if not native("setLightColors") then return entry, C.unsupported.native end
        local L = C.lightColors
        entry.options = { groups = {}, presets = copy(L.presets), minBrightness = L.minBrightness }
        for i, group in ipairs(L.groups) do
            entry.options.groups[i] = { id = group.id, label = group.label, refuse = copy(group.refuse), safety = group.safety }
        end
        return entry
    end,
    engineSound = function(entry, state)
        if not native("listEngineSounds", "setEngineSound") then return entry, C.unsupported.native end
        entry.options = { sounds = {}, preview = C.engineSound.preview == true, respawns = true }
        for _, sound in ipairs(Open77.vehicles.listEngineSounds(state.vehicleId) or {}) do
            if type(sound) == "table" and type(sound.id) == "string" and sound.id ~= "" then
                entry.options.sounds[#entry.options.sounds + 1] = { id = sound.id,
                    label = type(sound.label) == "string" and sound.label ~= "" and sound.label or sound.id, class = sound.class }
            end
        end
        if #entry.options.sounds == 0 then return entry, C.unsupported.engineSound end
        return entry
    end,
    stickers = function(entry, state)
        if not native("listStickers", "setStickers", "getStickers", "getDecalBudget") then return entry, C.unsupported.native end
        entry.options = { stickers = {}, maxPerCar = C.stickers.maxPerCar }
        for _, sticker in ipairs(Open77.vehicles.listStickers(state.vehicleId) or {}) do
            if type(sticker) == "table" and type(sticker.id) == "string" and sticker.id ~= "" then
                entry.options.stickers[#entry.options.stickers + 1] = { id = sticker.id,
                    label = type(sticker.label) == "string" and sticker.label ~= "" and sticker.label or sticker.id,
                    group = type(sticker.group) == "string" and sticker.group or "", decals = math.max(1, math.tointeger(tonumber(sticker.decals) or 1) or 1) }
            end
        end
        if #entry.options.stickers == 0 then return entry, C.unsupported.stickers end
        entry.options.budget = stickerBudget(state.vehicleId, entry.options.stickers)
        if not entry.options.budget then return entry, C.unsupported.native end
        return entry
    end,
    tag = function(entry)
        local T = C.tag
        entry.options = { fonts = copy(T.fonts), spots = copy(T.spots), colors = copy(T.colors),
            minLength = T.minLength, maxLength = T.maxLength, charset = T.charset }
        return entry
    end,
}
local function offer(state)
    local list = {}
    local support = type(C.support) == "table" and C.support[state.model] or nil
    for _, category in ipairs(C.categories) do
        local entry = { id = category.id, label = category.label, description = category.description, icon = category.icon,
            price = prices[category.id], available = true, soon = category.soon, parent = category.parent }
        local reason
        if category.capability and not native(category.capability) then entry = nil -- not even greyed
        elseif category.soon then reason = C.unsupported[category.id] or "Coming soon."
        elseif type(support) == "table" and support[category.id] == false then
            reason = (C.unsupported or {})[category.id] or "Not available for this model."
            if category.id == "trim" and #trimsOf(state.model) == 0 then entry = nil end
        elseif OFFER[category.id] then entry, reason = OFFER[category.id](entry, state) end
        -- natives present, but this garage would not keep the choice
        if entry and not reason and EXTRA[category.id] and not registry then reason = C.unsupported.garage end
        if entry then
            if reason then entry.available, entry.reason = false, reason end
            list[#list + 1] = entry
        end
    end
    return list
end
-- The stage the car runs on. A stored stage whose record is offline (the stages resource
-- stopped) spawns the car stock and stays dormant, and a car taken out while it was
-- offline stays stock until it is respawned: the page must not claim either as fitted.
local function fittedStage(state)
    local stage = stageOf(state)
    if stage <= 0 then return 0 end
    local wanted = stageRecord(state.record, stage)
    if not wanted then return 0 end
    local live = state.vehicleId and Open77.vehicles.get(state.vehicleId)
    local record = type(live) == "table" and live.record
    if type(record) == "string" and record ~= wanted then return 0 end
    return stage
end
-- The confirmed look as the page reads it (plus the phase-1 paint/lights/trim fields).
-- `stage` is the stage the car runs on (the header, "fitted"); `storedStage` the one paid
-- for and stored, which every quote and the unchanged check start from: they differ while a
-- stored stage is dormant (records offline at retrieval), and the page prices from it.
local function view(state)
    if not state then return nil end
    local visual = type(state.visual) == "table" and state.visual or {}
    local out = { paint = copy(state.paint), lightsHue = state.lightsHue, appearance = state.appearance,
        profile = visual.profile or "", plate = type(state.lightrp) == "table" and state.lightrp.plate or "",
        stage = fittedStage(state), storedStage = stageOf(state), body = {}, windows = "" }
    for _, level in ipairs(C.windows.levels) do if level.level == visual.tint then out.windows = level.id end end
    local neon = visual.neon
    if type(neon) == "table" and neon.enabled ~= false then
        local step, best = nil, math.huge
        for _, s in ipairs(C.neon.intensities) do
            local d = math.abs(s.value - (tonumber(neon.intensity) or 600))
            if d < best then step, best = s.id, d end
        end
        out.neon = { color = hexOf(neon.color), intensity = step }
    end
    local wheels = visual.wheels
    if type(wheels) == "table" and G.kitKind(wheels.rim) == "rims" then out.rim = { id = localId(wheels.rim), variant = wheels.variant or "" } end
    for id, value in pairs(type(visual.parts) == "table" and visual.parts or {}) do
        local name = localId(id)
        if G.kitKind(id) == "body" and groupOf[name] then out.body[groupOf[name]] = { part = name, variant = value == true and "" or value } end
    end
    -- wave 2, in the page's form (colours as "#RRGGBB", the animation speed as its step id)
    local animation = field(state, "neonAnimation")
    if type(animation) == "table" and modeOf(animation.mode) then
        local mode, step, best = modeOf(animation.mode), nil, math.huge
        if mode.speed then
            for _, speed in ipairs(C.neonAnimation.speeds) do
                local d = math.abs(speed.periodMs - (tonumber(animation.periodMs) or 0))
                if d < best then step, best = speed.id, d end
            end
        end
        out.neonAnimation = { mode = mode.id, speed = step, color2 = mode.color2 and animation.color2 and hexOf(animation.color2) or nil }
    end
    local lamps = field(state, "lightColors")
    if type(lamps) == "table" then
        out.lightColors = {}
        for _, group in ipairs(C.lightColors.groups) do if lamps[group.id] ~= nil then out.lightColors[group.id] = hexOf(lamps[group.id]) end end
    end
    local sound = field(state, "engineSound")
    out.engineSound = type(sound) == "string" and sound or ""
    out.stickers = {}
    for _, id in ipairs(type(field(state, "stickers")) == "table" and field(state, "stickers") or {}) do out.stickers[#out.stickers + 1] = tostring(id) end
    local tag = field(state, "tag")
    if type(tag) == "table" then out.tag = { text = tag.text, font = tag.font, color = hexOf(tag.color), spot = tag.spot } end
    return out
end
-- Strict validators: a request names a category and values, never a native nor a
-- record. The answer is the trusted change handed to the garage lease (Garage.customize).
local function option(list, id)
    for _, entry in ipairs(type(list) == "table" and list or {}) do if entry.id == id then return entry end end
end
local validators = {
    paint = function(p)
        if p.stock == true then return { category = "paint", paint = { applied = false } } end
        local primary, secondary = color(p.primary), color(p.secondary)
        if not primary or not secondary then return nil, "Choose valid six-digit RGB colors." end
        return { category = "paint", paint = { applied = true, primary = primary, secondary = secondary } }
    end,
    lights = function(p)
        if p.stock == true then return { category = "lights" } end
        local value = color(p.color)
        if not value then return nil, "Choose a valid six-digit RGB color." end
        if saturation(value) < (C.lightsMinSaturation or 0) then
            return nil, "Lights take a hue only: choose a more saturated color, or Factory lights."
        end
        return { category = "lights", color = value }
    end,
    trim = function(p, s)
        if p.stock == true then return { category = "trim", appearance = "" } end
        -- Only an id curated for THIS vehicle's model; the applied name comes from the table.
        for _, trim in ipairs(trimsOf(s.model)) do
            if type(p.trim) == "string" and trim.id == p.trim then return { category = "trim", appearance = trim.id } end
        end
        return nil, "This trim is not offered for this vehicle."
    end,
    livery = function(p, s)
        -- A livery and the stickers share the car's decal budget: a purchase stores this
        -- livery with the BOUGHT stickers, so it is checked against those, not a preview.
        if p.operation == "save" and stickersSold(s) and previewing(s, "stickers") then
            return nil, "Apply or undo your sticker preview first: stickers share the livery's decal budget."
        end
        if p.stock == true then return { category = "livery", profile = "" } end
        local scheme = type(p.profile) == "string" and option(s.categories.livery.options, p.profile)
        if not scheme then return nil, "This livery is not offered for this vehicle." end
        return { category = "livery", profile = scheme.id }
    end,
    rims = function(p, s)
        if p.stock == true then return { category = "rims", rim = "" } end
        local rim = type(p.rim) == "string" and option(s.categories.rims.options, p.rim)
        if not rim then return nil, "These rims are not offered for this vehicle." end
        local finish = type(p.variant) == "string" and option(rim.variants, p.variant)
        if not finish then return nil, "Choose a finish for these rims." end
        return { category = "rims", rim = NS .. rim.id, variant = finish.id }
    end,
    -- `parts` = { [group] = { part, variant } } for the groups the car wears; a group left
    -- out goes back to factory. One part per group: the native only keeps rims exclusive.
    body = function(p, s)
        if type(p.parts) ~= "table" then return nil, "Choose your body parts." end
        local groups, parts = s.categories.body.options, {}
        for group in pairs(p.parts) do
            if not option(groups, group) then return nil, "This body part is not offered for this vehicle." end
        end
        for _, group in ipairs(groups) do
            local wanted, chosen = p.parts[group.id], nil
            if type(wanted) == "table" then
                local part = option(group.parts, wanted.part)
                chosen = part and option(part.variants, wanted.variant) and { part = part.id, variant = wanted.variant }
                if not chosen then return nil, "This body part is not offered for this vehicle." end
            elseif wanted ~= nil and wanted ~= false and wanted ~= "" then
                return nil, "This body part is not offered for this vehicle."
            end
            for _, part in ipairs(group.parts) do
                parts[NS .. part.id] = chosen and chosen.part == part.id and chosen.variant or false
            end
        end
        return { category = "body", parts = parts }
    end,
    neon = function(p, s)
        if p.stock == true then return { category = "neon", neon = false } end
        local value = color(p.color)
        if not value then return nil, "Choose a valid six-digit RGB color." end
        if brightness(value) < (C.neon.minBrightness or 0) then return nil, "This color is too dark to light anything." end
        local step = option(C.neon.intensities, p.intensity)
        if not step then return nil, "Choose a brightness." end
        -- The animation the car shows, and the one bought, run on this colour.
        local A = s.categories.neonAnimation
        if A and A.available then
            local shown = wearing("neonAnimation", s.vehicle)
            local bought = field(confirmedState(s), "neonAnimation")
            if emergencyAnimation(value, shown) or (p.operation == "save" and emergencyAnimation(value, bought)) then
                return nil, "With your neon animation this color reads as an emergency light: choose another."
            end
        end
        return { category = "neon", neon = { color = value, intensity = step.value, radius = C.neon.radius } }
    end,
    windows = function(p)
        if p.stock == true then return { category = "windows", tint = false } end
        local level = type(p.tint) == "string" and option(C.windows.levels, p.tint)
        if not level then return nil, "Choose a window tint." end
        return { category = "windows", tint = level.level }
    end,
    plate = function(p, s)
        local plate = type(p.plate) == "string" and p.plate:upper():gsub("%s+", "") or nil
        if not plate or plate == "" then return nil, plateFormat() end
        local problem = plateProblem(plate, s.owned)
        if problem then return nil, problem end
        return { category = "plate", plate = plate }
    end,
    performance = function(p, s)
        if p.operation ~= "save" then return nil, "A stage is fitted on purchase: there is no preview." end
        local stage = math.tointeger(tonumber(p.stage))
        local entry
        for _, candidate in ipairs(s.categories.performance.options.stages) do if candidate.stage == stage then entry = candidate end end
        if not entry or not entry.record then return nil, "This stage is not offered for this vehicle." end
        if not running(C.stages.resource) then return nil, C.unsupported.stagesPack end
        local confirmed = confirmedState(s)
        if stage == stageOf(confirmed) and fittedStage(confirmed) ~= stage then
            return nil, "This stage is already paid for: park the car and take it out again to have it fitted."
        end
        -- the sound the car wears now (bought or previewed) is the one the rebuild keeps
        if not soundFits(entry.record, wearing("engineSound", s.vehicle)) then
            return nil, STAGE_SOUND
        end
        local last = stageAt[s.owned]
        if last and LightRP.nowMs() - last < C.stages.cooldownMs then
            return nil, string.format("This vehicle was tuned recently. Come back in %d min.",
                math.ceil((C.stages.cooldownMs - (LightRP.nowMs() - last)) / 60000))
        end
        local tried = stageTriedAt[s.owned]
        if tried and LightRP.nowMs() - tried < (C.stages.retryMs or 0) then
            return nil, "The car is still being rebuilt: wait a moment before the next stage."
        end
        return { category = "performance", stage = stage, record = entry.record }
    end,
    -- Wave 2 ------------------------------------------------------------------------
    -- `mode` and `speed` ids from the offer; `color2` for a two-colour mode. The cycle comes
    -- from the speed step, never from the client.
    neonAnimation = function(p, s)
        if p.stock == true then return { category = "neonAnimation", animation = false } end
        local mode = type(p.mode) == "string" and modeOf(p.mode)
        if not mode then return nil, "Choose an animation." end
        local A = C.neonAnimation
        local animation = { mode = mode.id, periodMs = A.reactivePeriodMs }
        if mode.speed then
            local speed = option(A.speeds, p.speed)
            if not speed then return nil, "Choose a speed." end
            animation.periodMs = speed.periodMs
            if mode.id == "strobe" then animation.periodMs = math.max(animation.periodMs, A.strobeMinPeriodMs) end
        end
        if mode.color2 then
            local second = color(p.color2)
            if not second then return nil, "Choose a second color." end
            if brightness(second) < (C.neon.minBrightness or 0) then return nil, "This color is too dark to light anything." end
            animation.color2 = rgbOf(second)
        end
        -- It runs on the neon: the one shown for a preview, the one bought for a purchase.
        local shown, bought = shownNeon(s), boughtNeon(s)
        if p.operation == "save" and not bought then return nil, "Buy a neon kit first: the animation runs on it." end
        if not shown and not bought then return nil, "Choose a neon color first: the animation runs on it." end
        if emergencyAnimation(shown, animation) or (p.operation == "save" and emergencyAnimation(bought, animation)) then
            return nil, mode.id == "strobe" and "A red or blue strobe reads as an emergency light: choose another neon color."
                or "Red and blue together read as an emergency light: choose another color."
        end
        return { category = "neonAnimation", animation = animation }
    end,
    -- `lamps` = { [group] = "#RRGGBB" } for the groups to recolour; a group left out stays factory.
    lightColors = function(p)
        if p.stock == true then return { category = "lightColors", lamps = false } end
        if type(p.lamps) ~= "table" then return nil, "Choose your lamp colors." end
        local L, lamps, any = C.lightColors, {}, false
        for group in pairs(p.lamps) do if not option(L.groups, group) then return nil, "This lamp cannot be recolored." end end
        for _, group in ipairs(L.groups) do
            local wanted = p.lamps[group.id]
            if wanted ~= nil and wanted ~= false and wanted ~= "" then
                local hex = color(wanted)
                if not hex then return nil, "Choose valid six-digit RGB colors." end
                if group.safety and brightness(hex) < L.minBrightness then
                    return nil, group.label .. " must stay visible: choose a brighter color."
                end
                local class = emergencyClass(hex)
                for _, refused in ipairs(group.refuse or {}) do
                    if class == refused then return nil, string.format("%s cannot be %s: it reads as an emergency vehicle.", group.label, refused) end
                end
                lamps[group.id], any = hex, true
            end
        end
        if not any then return nil, "Choose at least one lamp color, or Factory lamps." end
        return { category = "lightColors", lamps = lamps }
    end,
    -- One sound id from this model's list. Each change rebuilds the car: one per cooldown.
    engineSound = function(p, s)
        local E = C.engineSound
        if p.operation == "preview" and E.preview ~= true then return nil, "An engine sound is fitted on purchase: there is no preview." end
        if s.soundAt and LightRP.nowMs() - s.soundAt < (E.previewCooldownMs or 0) then
            return nil, "The car is still being rebuilt: wait a moment before the next engine sound."
        end
        if p.stock == true then return { category = "engineSound", sound = false } end
        local sound = type(p.sound) == "string" and option(s.categories.engineSound.options.sounds, p.sound)
        if not sound then return nil, "This engine sound does not fit this vehicle." end
        return { category = "engineSound", sound = sound.id }
    end,
    -- `stickers` = the ids the car should wear (order kept), within the decal budget left by
    -- the livery the car shows; an empty list is factory.
    stickers = function(p, s)
        if p.stock == true then return { category = "stickers", stickers = false } end
        if type(p.stickers) ~= "table" then return nil, "Choose your stickers." end
        local offered, chosen, seen, decals, entries = s.categories.stickers.options, {}, {}, 0, 0
        for _ in pairs(p.stickers) do entries = entries + 1 end
        if entries ~= #p.stickers then return nil, "Choose your stickers." end
        for _, id in ipairs(p.stickers) do
            local sticker = type(id) == "string" and option(offered.stickers, id)
            if not sticker then return nil, "This sticker does not fit this vehicle." end
            if seen[id] then return nil, "Each sticker goes on once." end
            seen[id], chosen[#chosen + 1], decals = true, id, decals + sticker.decals
        end
        if #chosen == 0 then return { category = "stickers", stickers = false } end
        if #chosen > C.stickers.maxPerCar then return nil, string.format("%d stickers at most.", C.stickers.maxPerCar) end
        local budget = stickerBudget(s.vehicle, offered.stickers)
        if not budget then return nil, "The decal budget of this vehicle cannot be read." end
        if budget.base + decals > budget.maximum then
            return nil, string.format("Too many decals: %d of %d with this livery. Remove a sticker.", budget.base + decals, budget.maximum)
        end
        -- A purchase stores these stickers with the BOUGHT livery: the budget read on the car
        -- only holds for it when the car shows that livery.
        if p.operation == "save" and previewing(s, "profile") then
            return nil, "Apply or undo your livery preview first: stickers share its decal budget."
        end
        return { category = "stickers", stickers = chosen }
    end,
    -- Text, font, colour and spot; the text passes the plate's banned and reserved words.
    tag = function(p)
        if p.stock == true then return { category = "tag", tag = false } end
        local T = C.tag
        local text = type(p.text) == "string" and p.text or ""
        text = text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
        if #text < T.minLength or #text > T.maxLength or not text:match(T.pattern) then
            return nil, string.format("A tag is %d to %d characters: %s.", T.minLength, T.maxLength, T.charset)
        end
        local kind = forbiddenWord((text:upper():gsub("[^A-Z0-9]", "")))
        if kind then return nil, kind == "reserved" and "This tag is reserved for city services." or "This tag is not allowed." end
        local font, spot, hex = option(T.fonts, p.font), option(T.spots, p.spot), color(p.color)
        if not font then return nil, "Choose a font." end
        if not spot then return nil, "Choose where to paint it." end
        if not hex then return nil, "Choose a valid six-digit RGB color." end
        return { category = "tag", tag = { text = text, font = font.id, color = hex, spot = spot.id } }
    end,
}
-- The server quote of a validated change against the confirmed look.
local function quote(change, s, confirmed)
    if change.category == "stickers" then
        -- per sticker added; a change that only removes stickers costs one
        local held, added = {}, 0
        local bought = field(confirmed, "stickers")
        for _, id in ipairs(type(bought) == "table" and bought or {}) do held[id] = true end
        for _, id in ipairs(change.stickers or {}) do if not held[id] then added = added + 1 end end
        return prices.stickers * math.max(1, added)
    elseif change.category == "body" then
        local held, changed = type(confirmed.visual) == "table" and confirmed.visual.parts or {}, 0
        for _, group in ipairs(s.categories.body.options) do
            local differs = false
            for _, part in ipairs(group.parts) do
                local want, have = change.parts[NS .. part.id], held[NS .. part.id]
                if want == false then differs = differs or have ~= nil else differs = differs or have ~= want end
            end
            if differs then changed = changed + 1 end
        end
        return prices.body * math.max(1, changed)
    elseif change.category == "performance" then
        -- the stage prices this session offered (curated per catalogue key, else per record)
        local current, offered = stageOf(confirmed), s.categories.performance.options.stages
        if change.stage <= current then return removal end
        local sum = 0
        for stage = current + 1, change.stage do sum = sum + offered[stage + 1].price end
        return sum
    end
    return prices[change.category]
end
local function reply(id, s, payload)
    if sessions[id] ~= s then return end
    payload.session, payload.nextRequest = s.id, s.nextRequest
    TriggerClientEvent(NET, id, payload)
end
function Custom.open(id, vehicle, garage)
    if sessions[id] then return false, "Close your current customization session first." end
    sequence = sequence + 1
    local token = "custom:" .. sequence .. ":" .. LightRP.nowMs()
    if not wallet(id) then return false, "Your wallet is not ready yet." end
    local state, why = G.beginCustomization(id, vehicle, token, garage)
    if not state then return false, why end
    local categories = offer(state)
    local s = { id = token, player = id, nextRequest = 1, vehicle = state.vehicleId, model = state.model, owned = state.id,
        expires = LightRP.nowMs() + C.sessionMs, categories = {} }
    for _, entry in ipairs(categories) do s.categories[entry.id] = entry end
    sessions[id] = s
    G.closeVisit(id)
    local confirmed = view(state)
    state.visual, state.lightrp = nil, nil
    for _, name in ipairs(EXTRA_ORDER) do state[name] = nil end
    -- The category tree nests deeper than the client's net event reader accepts (8 levels;
    -- body options > groups > parts > variants reach 10), and the client drops a too-deep
    -- event whole: it travels as JSON text, which the client decodes for the page. One text
    -- per category: the client's json.decode keeps the event reader's 1024-value cap, and
    -- 18 rims with 30 body parts are over it as one text (15 KB, measured 2026-11-06).
    local texts = {}
    for i, entry in ipairs(categories) do
        texts[i] = json.encode(entry)
        local values = countValues(entry)
        if values > JSON_VALUES then
            LightRP.log("auto studio: category %s is %d JSON values for %s, over the client's %d: it will not open",
                tostring(entry.id), values, tostring(state.model), JSON_VALUES)
        end
    end
    TriggerClientEvent(NET, id, { kind = "open", session = token, nextRequest = 1, vehicle = state,
        categoriesJson = texts, price = prices.paint, prices = prices, money = wallet(id),
        confirmed = confirmed })
    return true
end
LightRP.action("customization.open", function(id, p)
    local ok, why = Custom.open(id, p.vehicle, p.garage)
    if not ok then LightRP.result(id, false, why, "customization.open") end
end)
RegisterNetEvent(NET, function(p)
    local id = tonumber(source)
    local s = id and sessions[id]
    if not s or type(p) ~= "table" or p.session ~= s.id then return end
    if p.operation == "close" then close(id); return end
    if s.busy then return end
    if s.last and p.request == s.last.request then reply(id, s, s.last); return end
    if p.request ~= s.nextRequest then return end
    local valid, why = G.customizationValid(id, s.id)
    if not valid or LightRP.nowMs() > s.expires then close(id); return end
    if p.operation ~= "preview" and p.operation ~= "save" then return end
    -- Advance only accepted sequence numbers. Never accept a client-selected native.
    local validate, offered = validators[p.category], s.categories[p.category]
    local change, error
    if not offered then error = validate and "This customization is not offered for this vehicle." or "Unknown customization category."
    elseif not offered.available then error = offered.reason
    elseif not validate then error = "Unknown customization category."
    else change, error = validate(p, s) end
    local now = LightRP.nowMs()
    if p.operation == "preview" and now - (s.lastAt or -1000) < C.previewIntervalMs then error = "Please wait before changing the finish again."; change = nil end
    -- `sessionMs` is an idle limit, as for a garage session: every request the studio
    -- answers restarts it. Counted from the opening, it closed the studio mid-edit and
    -- dropped the preview after five minutes of use (2026-11-07 lab).
    s.lastAt, s.nextRequest, s.busy, s.expires = now, s.nextRequest + 1, true, now + C.sessionMs
    local ok = false
    if p.operation == "save" and p.pay ~= "cash" and p.pay ~= "bank" then change, error = nil, "Choose cash or bank." end
    -- The studio waits for this answer and never sends again: a Lua error past this
    -- point used to leave `s.busy` set and the studio stuck until it closed. A failed
    -- quote or apply is refused; a failed side effect (engine hold, lamps) is only
    -- logged, so a paid save is never reported as refused.
    if change then
        local applied, failure = pcall(function()
            local amount = p.operation == "save" and quote(change, s, G.customizationState(id, s.id) or {}) or nil
            ok, error = G.customize(id, s.id, change, p.operation == "save", { method = p.pay, amount = amount })
        end)
        if not applied then
            ok, error = false, "The workshop could not apply this change. Try again."
            LightRP.log("auto studio: %s %s failed for %s: %s", tostring(p.operation), tostring(p.category), tostring(id), tostring(failure))
        end
    end
    local effects, failure = pcall(function()
        if not change then return end
        -- every stage purchase past the validators waits before the next one, a refused one too:
        -- it may have rebuilt the car and rebuilt it back (UI-less spam = two rebuilds a try)
        if p.operation == "save" and change.category == "performance" then
            stageTriedAt[s.owned] = LightRP.nowMs()
            if ok then stageAt[s.owned] = LightRP.nowMs() end
        end
        -- The studio may have closed during the payment's SQL write (closed, left, died):
        -- close() already ran and would never undo an engine hold or lamps switched on now.
        if sessions[id] ~= s then return end
        if change.category == "engineSound" then
            -- a change rebuilt the car (or tried to): the next one waits
            s.soundAt = LightRP.nowMs()
            -- Keep the empty car running so its new note is heard; stopped at close.
            if ok and C.engineSound.listen and native("setEngineHold") then
                local held = Open77.vehicles.setEngineHold(s.vehicle, true)
                if held then s.engineHeld = true else LightRP.log("auto studio: engine hold refused on %s", tostring(s.vehicle)) end
            end
        end
        -- A lamp colour only shows with the lamps lit: a parked car's headlights are off by
        -- day, so the first lamp preview switches them on until the studio closes
        -- (2026-11-06: "je vois les phares [seulement de nuit]").
        if ok and (change.category == "lights" or change.category == "lightColors") and C.showLamps ~= false
            and s.lampsBefore == nil and type(Open77.vehicles.setLights) == "function" then
            local v = Open77.vehicles.get(s.vehicle)
            local flags = v and math.tointeger(v.flags or 0) or 0
            if v and (flags & 64) == 0 and (flags & 128) == 0 then
                local lit, why = Open77.vehicles.setLights(s.vehicle, "on")
                if lit then s.lampsBefore = "off" else LightRP.log("auto studio: lamps refused on %s: %s", tostring(s.vehicle), tostring(why)) end
            end
        end
    end)
    if not effects then LightRP.log("auto studio: after %s %s for %s: %s", tostring(p.operation), tostring(p.category), tostring(id), tostring(failure)) end
    s.busy = nil
    local text = ok and (p.operation == "save" and SAVED[p.category] or (p.category == "plate" and "This plate is available." or "Preview applied.")) or error
    local built, last = pcall(function()
        local response = { kind = "response", request = p.request, operation = p.operation, category = p.category, ok = ok, money = wallet(id),
            paint = G.customizationPaint(id, s.id), confirmed = view(G.customizationState(id, s.id)), text = text }
        -- the decal budget left by the livery the car shows now (a livery preview changes it)
        if stickersSold(s) then response.budget = stickerBudget(s.vehicle, s.categories.stickers.options.stickers) end
        return response
    end)
    if not built then LightRP.log("auto studio: answer to %s %s for %s: %s", tostring(p.operation), tostring(p.category), tostring(id), tostring(last)) end
    s.last = built and last or { kind = "response", request = p.request, operation = p.operation, category = p.category, ok = ok, text = text }
    reply(id, s, s.last)
end)
function Custom.onDisconnected(id) close(id) end
function Custom.onCharacterLoaded(id) close(id) end
function Custom.onLifeState(id, phase) if phase ~= "alive" then close(id) end end
CreateThread(function()
    lightrpEvery(1000, function()
        
        for id, s in pairs(sessions) do
            if LightRP.nowMs() > s.expires or not G.customizationValid(id, s.id) then close(id) end
        end
    end, "vehicle_customization:77")
end)
-- Stale flags left by tasks the instruction quota killed (framework.lua expireFlags).
expireFlags("vehicle_customization.busy", sessions, nil, "busy")

function Custom.onInteract(id, point)
    local workshop = type(point) == "string" and point:match("^customization%.(.+)$")
    if not workshop then return end
    local owned, why = G.customizationCandidate(id, workshop)
    if owned then
        local ok; ok, why = Custom.open(id, owned, workshop)
        if ok then return end
    end
    LightRP.result(id, false, why, "customization.open")
end
for index, place in ipairs(C.workshops) do
    G.registerCustomizationLocation(place)
    LightRP.interaction("customization." .. place.id, { position = place.position, bucket = place.bucket,
        radius = place.interactRadius, label = place.name, prompt = "Customize personal vehicle", key = "E",
        marker = LightRpGarages.marker, ring = false,
        blip = index == 1 and { icon = "palette", sprite = "Zzz01_CarForPurchaseVariant", title = "Auto Studio",
            description = "Personal vehicle paint, livery, rims, body kit, neon, plate, window tint and performance" } or nil })
end
LightRP.log("vehicle customization ready: %d workshop points, %d categories", #C.workshops, #C.categories)
