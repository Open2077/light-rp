local G, C = LightRP.garage, LightRpVehicleCustomization
local Custom = LightRP.module("vehicleCustomization", {})
local NET = LightRpEvents.net.customization
local sessions, sequence = {}, 0
local price = assert(LightRP.money.validAmount(LightRpCustomizationPricing.paint), "Invalid paint price")
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
local categories = {
    paint = function(p)
        if p.stock == true then return { applied = false } end
        local primary, secondary = color(p.primary), color(p.secondary)
        if not primary or not secondary then return nil, "Choose valid six-digit RGB colors." end
        return { applied = true, primary = primary, secondary = secondary }
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
    local s = { id = token, nextRequest = 1, vehicle = state.vehicleId, expires = LightRP.nowMs() + C.sessionMs, price = price }
    sessions[id] = s
    G.closeVisit(id)
    TriggerClientEvent(NET, id, { kind = "open", session = token, nextRequest = 1, vehicle = state,
        categories = C.categories, price = s.price, money = wallet(id) })
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
    local validate = categories[p.category]
    local paint, error
    if validate then paint, error = validate(p) else error = "Unknown customization category." end
    local now = LightRP.nowMs()
    if p.operation == "preview" and now - (s.lastAt or -1000) < C.previewIntervalMs then error = "Please wait before changing the finish again."; paint = nil end
    s.lastAt, s.nextRequest, s.busy = now, s.nextRequest + 1, true
    local ok = false
    if p.operation == "save" and p.pay ~= "cash" and p.pay ~= "bank" then paint, error = nil, "Choose cash or bank." end
    if paint then ok, error = G.customizePaint(id, s.id, paint, p.operation == "save", { method = p.pay, amount = s.price }) end
    s.busy = nil
    s.last = { kind = "response", request = p.request, operation = p.operation, ok = ok, money = wallet(id), paint = G.customizationPaint(id, s.id),
        text = ok and (p.operation == "save" and "Paint purchased and saved to your vehicle." or "Preview applied.") or error }
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
            description = "Personal vehicle paint customization" } or nil })
end
LightRP.log("vehicle customization ready: %d workshop points, %d category", #C.workshops, #C.categories)
