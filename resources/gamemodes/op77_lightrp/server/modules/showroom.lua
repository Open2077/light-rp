-- Dealership demonstration cars (LightRpDealerships.displays): server-owned
-- vehicles parked on their podium, locked for everyone, frozen in place and
-- indestructible. Nobody holds their keys, so nobody can open or drive them. A
-- car that disappears (an admin command, a crash of the host) is put back by the
-- watch below; stopping the resource removes them.
local C = LightRpDealerships
local Showroom = LightRP.module("showroom", {})

local live = {} -- display id -> vehicle id
Showroom.live = live

local function call(name, ...)
    local fn = Open77.vehicles[name]
    if type(fn) ~= "function" then return false, "unsupported" end
    local ok, result, reason = pcall(fn, ...)
    if not ok then return false, result end
    return result, reason
end

local function place(display)
    local entry = LightRP.vehicles and LightRP.vehicles.byKey[string.lower(display.key or "")]
    if not entry then LightRP.log("showroom: %s names an unknown model %s", display.id, tostring(display.key)); return nil end
    local id, reason = Open77.vehicles.create({ record = entry.record, position = display.position, yaw = display.yaw or 0,
        bucket = display.bucket or 0, persistent = true, despawnWhenUnobserved = false })
    if not id then LightRP.log("showroom: %s could not be placed (%s)", display.id, tostring(reason)); return nil end
    local frozen, why = call("setFrozen", id, true)
    local guarded, failure = call("setProperties", id, { engineOn = false, invulnerable = true, immortal = true })
    local locked = LightRP.keys and LightRP.keys.lock(id, true) or call("setLockedForAll", id, true)
    if not (frozen and guarded and locked) then
        LightRP.log("showroom: %s placed with frozen=%s (%s) protected=%s (%s) locked=%s", display.id,
            tostring(frozen), tostring(why), tostring(guarded), tostring(failure), tostring(locked))
    end
    live[display.id] = id
    LightRP.log("showroom: %s placed (%s, vehicle %s)", display.id, entry.label or display.key, tostring(id))
    return id
end

function Showroom.refresh()
    for _, display in ipairs(C.displays or {}) do
        local id = live[display.id]
        if not id or not Open77.vehicles.get(id) then place(display) end
    end
end

CreateThread(function()
    Wait(1000)
    while true do
        Showroom.refresh()
        Wait(15000)
    end
end)

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    for key, id in pairs(live) do
        if Open77.vehicles.get(id) then Open77.vehicles.remove(id) end
        live[key] = nil
    end
end)
