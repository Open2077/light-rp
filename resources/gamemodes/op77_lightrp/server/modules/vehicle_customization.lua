local G, C = LightRP.garage, LightRpVehicleCustomization
local Custom = LightRP.module("vehicleCustomization", {})
local NET = LightRpEvents.net.customization
local P, KIT = LightRpCustomizationPricing, LightRpVehicleKit
local sessions, sequence, stageAt = {}, 0, {}
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
local SAVED = {
    paint = "Paint purchased and saved to your vehicle.",
    lights = "Light tint purchased and saved to your vehicle.",
    trim = "Trim purchased and saved to your vehicle.",
    livery = "Livery purchased and saved to your vehicle.",
    rims = "Rims purchased and saved to your vehicle.",
    body = "Body kit purchased and saved to your vehicle.",
    neon = "Neon purchased and saved to your vehicle.",
    plate = "Plate registered to your vehicle.",
    performance = "Stage fitted and saved to your vehicle.",
}
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for k, v in pairs(value) do out[k] = copy(v) end; return out
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
-- The kit entry with its trims: per-appearance rim overrides, or (perAppearance false)
-- the rims' trim hide names merged into the record fit.
local function withTrims(section, id, entry, perAppearance)
    for record, fit in pairs(entry.fit or {}) do
        local trims = section == "rims" and type(TRIMS.rims) == "table" and TRIMS.rims[record]
        local extra = section == "body" and type(TRIMS.body) == "table" and type(TRIMS.body[id]) == "table" and TRIMS.body[id][record]
        if type(trims) == "table" then
            if perAppearance then fit.appearances = copy(trims) else mergeHides(fit, trims, "hide") end
        end
        if type(extra) == "table" then mergeHides(fit, extra) end
    end
    return entry
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
            local ok, why = Open77.vehicles.registerParts({ [id] = withTrims(section, id, copy(source), appearanceFits) })
            if not ok and appearanceFits and tostring(why):find("fit.appearances", 1, true) then
                appearanceFits = false
                LightRP.log("auto studio: no per-appearance fits on this server build (%s); trims wear the default rim fit, their stock rims hidden", tostring(why))
                ok, why = Open77.vehicles.registerParts({ [id] = withTrims(section, id, copy(source), false) })
            end
            if not ok and section == "rims" and tostring(why):find("wheels", 1, true) then
                ok, why = Open77.vehicles.registerParts({ [id] = legacyRim(withTrims(section, id, copy(source), false)) })
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
-- nil when `plate` (already upper case) may be registered to the owned vehicle `rowId`.
local function plateProblem(plate, rowId)
    local p = C.plate
    if #plate < p.minLength or #plate > p.maxLength or not plate:match(p.pattern) then return plateFormat() end
    local read = reading(plate)
    for _, word in ipairs(words) do
        if plate:find(word.raw, 1, true) or (word.leet and read:find(word.raw, 1, true)) then
            return word.kind == "reserved" and "This plate is reserved for city services." or "This plate is not allowed."
        end
    end
    if G.plateTaken(plate, rowId) then return "This plate is already registered to another vehicle." end
end
Custom.plateProblem = plateProblem

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
        entry.options = { minLength = C.plate.minLength, maxLength = C.plate.maxLength, charset = C.plate.charset }
        return entry
    end,
    performance = function(entry, state)
        local list = (P.performance or {})[state.model]
        if not native("respawnAs") then return entry, C.unsupported.native end
        if type(list) ~= "table" then return entry, C.unsupported.performance end
        if not running(C.stages.resource) then return entry, C.unsupported.stagesPack end
        entry.options = { current = stageOf(state), removal = removal, stages = {} }
        local any = false
        for stage = 0, C.stages.max do
            local record = stageRecord(state.record, stage)
            any = any or (stage > 0 and record ~= nil)
            entry.options.stages[stage + 1] = { stage = stage, label = C.stages.labels[stage], price = list[stage],
                record = record, available = record ~= nil }
        end
        if not any then return entry, C.unsupported.performance end
        return entry
    end,
}
local function offer(state)
    local list = {}
    local support = type(C.support) == "table" and C.support[state.model] or nil
    for _, category in ipairs(C.categories) do
        local entry = { id = category.id, label = category.label, description = category.description, icon = category.icon,
            price = prices[category.id], available = true, soon = category.soon }
        local reason
        if category.soon then reason = C.unsupported[category.id] or "Coming soon."
        elseif type(support) == "table" and support[category.id] == false then
            reason = (C.unsupported or {})[category.id] or "Not available for this model."
            if category.id == "trim" and #trimsOf(state.model) == 0 then entry = nil end
        elseif OFFER[category.id] then entry, reason = OFFER[category.id](entry, state) end
        if entry then
            if reason then entry.available, entry.reason = false, reason end
            list[#list + 1] = entry
        end
    end
    return list
end
-- The confirmed look as the page reads it (plus the phase-1 paint/lights/trim fields).
local function view(state)
    if not state then return nil end
    local visual = type(state.visual) == "table" and state.visual or {}
    local out = { paint = copy(state.paint), lightsHue = state.lightsHue, appearance = state.appearance,
        profile = visual.profile or "", plate = type(state.lightrp) == "table" and state.lightrp.plate or "",
        stage = stageOf(state), body = {} }
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
    neon = function(p)
        if p.stock == true then return { category = "neon", neon = false } end
        local value = color(p.color)
        if not value then return nil, "Choose a valid six-digit RGB color." end
        if brightness(value) < (C.neon.minBrightness or 0) then return nil, "This color is too dark to light anything." end
        local step = option(C.neon.intensities, p.intensity)
        if not step then return nil, "Choose a brightness." end
        return { category = "neon", neon = { color = value, intensity = step.value, radius = C.neon.radius } }
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
        local last = stageAt[s.owned]
        if last and LightRP.nowMs() - last < C.stages.cooldownMs then
            return nil, string.format("This vehicle was tuned recently. Come back in %d min.",
                math.ceil((C.stages.cooldownMs - (LightRP.nowMs() - last)) / 60000))
        end
        return { category = "performance", stage = stage, record = entry.record }
    end,
}
-- The server quote of a validated change against the confirmed look.
local function quote(change, s, confirmed)
    if change.category == "body" then
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
        local current, list = stageOf(confirmed), P.performance[s.model]
        if change.stage <= current then return removal end
        local sum = 0
        for stage = current + 1, change.stage do sum = sum + list[stage] end
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
    local s = { id = token, nextRequest = 1, vehicle = state.vehicleId, model = state.model, owned = state.id,
        expires = LightRP.nowMs() + C.sessionMs, categories = {} }
    for _, entry in ipairs(categories) do s.categories[entry.id] = entry end
    sessions[id] = s
    G.closeVisit(id)
    local confirmed = view(state)
    state.visual, state.lightrp = nil, nil
    -- The category tree nests deeper than the client's net event reader accepts (8 levels;
    -- body options > groups > parts > variants reach 10), and the client drops a too-deep
    -- event whole: it travels as JSON text, which the client decodes for the page.
    TriggerClientEvent(NET, id, { kind = "open", session = token, nextRequest = 1, vehicle = state,
        categoriesJson = json.encode(categories), price = prices.paint, prices = prices, money = wallet(id),
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
    s.lastAt, s.nextRequest, s.busy = now, s.nextRequest + 1, true
    local ok = false
    if p.operation == "save" and p.pay ~= "cash" and p.pay ~= "bank" then change, error = nil, "Choose cash or bank." end
    if change then
        local amount = p.operation == "save" and quote(change, s, G.customizationState(id, s.id) or {}) or nil
        ok, error = G.customize(id, s.id, change, p.operation == "save", { method = p.pay, amount = amount })
        if ok and p.operation == "save" and change.category == "performance" then stageAt[s.owned] = LightRP.nowMs() end
    end
    s.busy = nil
    local text = ok and (p.operation == "save" and SAVED[p.category] or (p.category == "plate" and "This plate is available." or "Preview applied.")) or error
    s.last = { kind = "response", request = p.request, operation = p.operation, category = p.category, ok = ok, money = wallet(id),
        paint = G.customizationPaint(id, s.id), confirmed = view(G.customizationState(id, s.id)), text = text }
    reply(id, s, s.last)
end)
function Custom.onDisconnected(id) close(id) end
function Custom.onCharacterLoaded(id) close(id) end
function Custom.onLifeState(id, phase) if phase ~= "alive" then close(id) end end
CreateThread(function()
    while true do
        Wait(1000)
        for id, s in pairs(sessions) do
            if LightRP.nowMs() > s.expires or not G.customizationValid(id, s.id) then close(id) end
        end
    end
end)

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
            description = "Personal vehicle paint, livery, rims, body kit, neon, plate and performance" } or nil })
end
LightRP.log("vehicle customization ready: %d workshop points, %d categories", #C.workshops, #C.categories)
