-- op77_speedometer client: reads the car the player sits in and feeds the holographic
-- speedometer (client/ui.lua: a NativeUI document behind the page API the WebUI page had;
-- it shows and hides its own content with its enter / exit animations).
local S = Speedo
local base = S.copy(SpeedoConfig)
local config = S.copy(base)
local pageConfig = S.pageConfig(config)

-- NativeUI draws the display; a client without it gets none at all (and says so once).
local available = type(Open77.ui) == "table" and type(Open77.ui.create) == "function"
local page, pageReady = nil, false
local shown = false          -- the page shows the display
local lastShow = nil         -- the show payload (replayed when the page reloads)
local lastData = nil
local busy = false           -- another interface holds the cursor
local suppress = {}          -- reason -> true (exports hide/show)
local nativeHidden = false
local announced = nil
local warned = {}

local function warn(key, text)
    if warned[key] then return end
    warned[key] = true
    print("[speedometer] " .. text)
end
local function dbg(fmt, ...) if config.debug then print("[speedometer] " .. string.format(fmt, ...)) end end

local function send(name, payload)
    if page and pageReady then pcall(page.send, page, name, payload) end
end

-- ---------------------------------------------------------------------------
-- Gamemode handshake: while this display is on, a gamemode with its own vehicle HUD
-- (LightRP's cluster) stands it down. It asks with op77_speedometer:query.
local function announce()
    local active = available and config.enabled ~= false
    if announced == active then return end
    announced = active
    TriggerEvent("op77_speedometer:state", { active = active })
end
AddEventHandler("op77_speedometer:query", function()
    announced = nil
    announce()
end)

-- The game's own speedometer stays hidden while this display is on.
local function syncNative()
    local want = available and config.enabled ~= false and config.hideNativeSpeedometer ~= false
    if want == nativeHidden then return end
    if type(Open77.hud) ~= "table" or type(Open77.hud.setVisible) ~= "function" then return end
    local ok, accepted = pcall(Open77.hud.setVisible, "speedometer", not want)
    if ok and accepted then nativeHidden = want else warn("native", "cannot claim the native speedometer: " .. tostring(accepted)) end
end

-- ---------------------------------------------------------------------------
-- The document

local function createSurface()
    if page then pcall(page.destroy, page); page, pageReady = nil, false end
    local created, why = SpeedoUi.create({ zIndex = config.zIndex, fps = config.fps })
    if not created then print("[speedometer] no NativeUI document: " .. tostring(why)) return end
    page = created
    dbg("document fps %s z %s", tostring(config.fps), tostring(config.zIndex))
    created:on("speedo:ready", function()
        pageReady = true
        send("speedo:config", pageConfig)
        if shown and lastShow then
            send("speedo:show", { name = lastShow.name, instant = true })
            if lastData then send("speedo:data", lastData) end
        end
    end)
end

local function syncSurface()
    if not available then return end
    if config.enabled == false then
        if page then pcall(page.destroy, page); page, pageReady = nil, false end
        shown = false
        return
    end
    if page == nil then
        shown = false
        createSurface()
    end
end

local function apply(patch)
    if type(patch) ~= "table" then return false end
    if patch.reset then config = S.copy(base) else config = S.merge(config, patch) end
    pageConfig = S.pageConfig(config)
    send("speedo:config", pageConfig)
    syncNative()
    syncSurface()
    announce()
    return true
end

-- ---------------------------------------------------------------------------
-- Sampling

-- op77_loadscreen's zone cover is a WebUI page, below every NativeUI document: step aside
-- while it is up (it sends op77_loadscreen:state; nothing happens without that resource).
local loadCovered = false
if type(AddEventHandler) == "function" then
    AddEventHandler("op77_loadscreen:state", function(active) loadCovered = active == true end)
end
local function captured()
    if loadCovered then return false, true end
    if type(Open77.input) ~= "table" or type(Open77.input.isCaptured) ~= "function" then return false, false end
    local ok, keyboard, cursor = pcall(Open77.input.isCaptured)
    if not ok then return false, false end
    return keyboard == true, cursor == true
end

local function handbrake(keyboardTaken)
    if keyboardTaken or type(Open77.input) ~= "table" or type(Open77.input.isDown) ~= "function" then return false end
    for _, key in ipairs(type(config.handbrakeKeys) == "table" and config.handbrakeKeys or {}) do
        local ok, down = pcall(Open77.input.isDown, key)
        if ok and down == true then return true end
    end
    return false
end

local function fuel(vehicleId)
    local f = config.fuel
    if type(f) ~= "table" or f.enabled == false then return nil end
    if type(Open77.state) ~= "table" or type(Open77.state.entity) ~= "function" then return nil end
    local ok, bag = pcall(Open77.state.entity, "vehicle", vehicleId)
    if not ok or bag == nil then return nil end
    local okL, litres = pcall(function() return bag:get(f.key or "fuel") end)
    if not okL or type(litres) ~= "number" then return nil end
    local okM, capacity = pcall(function() return bag:get(f.maxKey or "fuelMax") end)
    return { litres = litres, capacity = (okM and type(capacity) == "number" and capacity > 0) and capacity or (tonumber(f.defaultMax) or 60) }
end

local function step()
    local seat = nil
    if type(Open77.vehicles) == "table" and type(Open77.vehicles.getPlayerSeat) == "function" then
        local ok, s = pcall(Open77.vehicles.getPlayerSeat)
        if ok and type(s) == "table" and s.vehicleId ~= nil and s.exiting ~= true then seat = s end
    end
    local vehicle = nil
    if seat and type(Open77.vehicles.get) == "function" then
        local ok, v = pcall(Open77.vehicles.get, seat.vehicleId)
        if ok and type(v) == "table" then vehicle = v end
    end
    local keyboardTaken, cursor = captured()
    busy = cursor
    local suppressed = next(suppress) ~= nil
    local want = page ~= nil and S.shouldShow(config, { seated = vehicle ~= nil, driver = S.isDriver(seat), busy = busy, suppressed = suppressed })

    if want then
        local flags = type(Open77.vehicles.flags) == "table" and Open77.vehicles.flags or nil
        lastData = S.sample(vehicle, config, { handbrake = handbrake(keyboardTaken), fuel = fuel(seat.vehicleId), flags = flags })
        if not shown then
            shown = true
            lastShow = { name = config.showVehicleName ~= false and S.vehicleName(vehicle.record, config.vehicleNames) or "" }
            send("speedo:data", lastData)
            send("speedo:show", lastShow)
            dbg("show (%s)", lastShow.name)
        else
            send("speedo:data", lastData)
        end
    elseif shown then
        shown = false
        send("speedo:hide", {})
        dbg("hide")
    end
    return vehicle ~= nil
end

-- ---------------------------------------------------------------------------
-- Start

AddEventHandler("onClientResourceStart", function(name)
    if name ~= GetCurrentResourceName() then return end
    announce()
    if not available then print("[speedometer] NativeUI (Open77.ui) is not available on this client: no speedometer") return end
    syncNative()
    syncSurface()
    if type(TriggerServerEvent) == "function" then TriggerServerEvent("op77_speedometer:hello") end
    CreateThread(function()
        while true do
            local inVehicle = step()
            local rate = math.max(4, math.min(60, tonumber(config.rate) or 20))
            Wait(inVehicle and math.floor(1000 / rate) or 250)
        end
    end)
    -- the native claim can be refused before the HUD exists: retry for a while
    CreateThread(function()
        for _ = 1, 30 do
            if nativeHidden or config.enabled == false or config.hideNativeSpeedometer == false then break end
            Wait(2000)
            syncNative()
        end
    end)
end)

AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() then suppress[name] = nil return end
    TriggerEvent("op77_speedometer:state", { active = false })
end)

RegisterNetEvent("op77_speedometer:config", function(patch) apply(patch) end)

-- ---------------------------------------------------------------------------
-- Exports (any client resource)

exports("setConfig", function(patch) return apply(patch) end)
exports("getConfig", function() return S.copy(config) end)
exports("setEnabled", function(on) return apply({ enabled = on ~= false }) end)
exports("isEnabled", function() return config.enabled ~= false end)
exports("isShown", function() return shown end)
-- A scene that wants a clean screen: hide("my_cutscene") ... show("my_cutscene").
exports("hide", function(reason) suppress[tostring(reason or GetInvokingResource() or "export")] = true; return true end)
exports("show", function(reason) suppress[tostring(reason or GetInvokingResource() or "export")] = nil; return true end)
