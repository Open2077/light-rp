local G, C = LightRP.garage, LightRpVehicleCustomization
local Custom = LightRP.module("vehicleCustomization", {})
local NET = LightRpEvents.net.customization
local sessions, sequence = {}, 0
-- Server quotes, one per registered category (server/config/vehicle_customization.lua).
local prices = {}
for _, category in ipairs(C.categories) do
    prices[category.id] = assert(LightRP.money.validAmount(LightRpCustomizationPricing[category.id]), "Invalid " .. category.id .. " price")
end
local SAVED = {
    paint = "Paint purchased and saved to your vehicle.",
    lights = "Light tint purchased and saved to your vehicle.",
    trim = "Trim purchased and saved to your vehicle.",
}
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
-- HSV saturation (0..1) of "#RRGGBB": the engine keeps a single hue for the lights.
local function saturation(hex)
    local r, g, b = tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
    local high, low = math.max(r, g, b), math.min(r, g, b)
    return high == 0 and 0 or (high - low) / high
end
local function trimsOf(model)
    local list = type(C.trims) == "table" and C.trims[model]
    return type(list) == "table" and list or {}
end
-- What this vehicle's model offers. An unknown model, or a model/category absent from
-- the support table, keeps paint and lights (no regression); `false` greys a category.
-- Trim only appears for a model with curated entries.
local function offer(model)
    local list = {}
    local support = type(C.support) == "table" and C.support[model] or nil
    for _, category in ipairs(C.categories) do
        local entry = { id = category.id, label = category.label, description = category.description, icon = category.icon,
            price = prices[category.id], available = true }
        if type(support) == "table" and support[category.id] == false then
            entry.available, entry.reason = false, (C.unsupported or {})[category.id] or "Not available for this model."
        end
        if category.id == "trim" then
            local trims = trimsOf(model)
            if #trims == 0 then entry = nil
            else
                entry.options = {}
                for i, trim in ipairs(trims) do entry.options[i] = { id = trim.id, label = trim.label } end
            end
        end
        if entry then list[#list + 1] = entry end
    end
    return list
end
-- Strict validators: a request names a category and values, never a native. The
-- answer is the trusted change handed to the garage lease (Garage.customize).
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
}
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
    local categories = offer(state.model)
    local s = { id = token, nextRequest = 1, vehicle = state.vehicleId, model = state.model, expires = LightRP.nowMs() + C.sessionMs,
        categories = {} }
    for _, entry in ipairs(categories) do s.categories[entry.id] = entry end
    sessions[id] = s
    G.closeVisit(id)
    TriggerClientEvent(NET, id, { kind = "open", session = token, nextRequest = 1, vehicle = state,
        categories = categories, price = prices.paint, prices = prices, money = wallet(id) })
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
    if not validate then error = "Unknown customization category."
    elseif not offered then error = "This customization is not offered for this vehicle."
    elseif not offered.available then error = offered.reason
    else change, error = validate(p, s) end
    local now = LightRP.nowMs()
    if p.operation == "preview" and now - (s.lastAt or -1000) < C.previewIntervalMs then error = "Please wait before changing the finish again."; change = nil end
    s.lastAt, s.nextRequest, s.busy = now, s.nextRequest + 1, true
    local ok = false
    if p.operation == "save" and p.pay ~= "cash" and p.pay ~= "bank" then change, error = nil, "Choose cash or bank." end
    if change then ok, error = G.customize(id, s.id, change, p.operation == "save", { method = p.pay, amount = prices[change.category] }) end
    s.busy = nil
    s.last = { kind = "response", request = p.request, operation = p.operation, category = p.category, ok = ok, money = wallet(id),
        paint = G.customizationPaint(id, s.id), confirmed = G.customizationState(id, s.id),
        text = ok and (p.operation == "save" and SAVED[p.category] or "Preview applied.") or error }
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
            description = "Personal vehicle paint, lights and factory trim" } or nil })
end
LightRP.log("vehicle customization ready: %d workshop points, %d categories", #C.workshops, #C.categories)
