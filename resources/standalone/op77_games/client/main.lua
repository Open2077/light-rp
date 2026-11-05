-- op77_games client: draws what the server says, in Light RP's activity HUD (client exports
-- ActivityHudShow / Push / Clear) and with Light RP's sounds. It decides nothing and sends
-- nothing but "ready": a game's rules read bodies server side. No page of its own.
local Config = GamesConfig

local shown = false

-- The core's exports are synchronous and raise when op77_lightrp is down.
local function core(name, ...)
    local ok, first, second = pcall(function(...)
        local proxy = exports[Config.core]
        return proxy[name](proxy, ...)
    end, ...)
    if not ok then return false, "core_unavailable" end
    return first, second
end

local function warn(what, why)
    if Open77.log and Open77.log.warn then Open77.log.warn(("[games] %s: %s"):format(what, tostring(why))) end
end

RegisterNetEvent("op77_games:hud", function(view)
    if type(view) ~= "table" then return end
    GamesObjectives.sync(view.world)
    view.world = nil
    GamesProphuntClient.keys(view)
    local ok, why = core("ActivityHudShow", view)
    if ok == true then shown = true else warn("ActivityHudShow", why) end
end)

RegisterNetEvent("op77_games:push", function(kind, payload)
    if type(kind) ~= "string" or type(payload) ~= "table" then return end
    local ok, why = core("ActivityHudPush", kind, payload)
    if ok ~= true then warn("ActivityHudPush " .. kind, why) end
end)

RegisterNetEvent("op77_games:clear", function()
    GamesObjectives.sync(nil)
    if shown then core("ActivityHudClear") end
    shown = false
end)

-- One handle per sound, destroyed when done.
local playing = {}
RegisterNetEvent("op77_games:cue", function(name)
    local sound = type(name) == "string" and Config.sounds[name] or nil
    if sound == nil or type(Open77.audio) ~= "table" then return end
    if playing[name] then pcall(Open77.audio.destroy, playing[name]); playing[name] = nil end
    local ok, handle, why = pcall(Open77.audio.play2D, sound.file, { volume = sound.volume })
    if not ok or not handle then return warn("sound " .. name, ok and why or handle) end
    playing[name] = handle
    SetTimeout(sound.ms + 300, function()
        if playing[name] == handle then pcall(Open77.audio.destroy, handle); playing[name] = nil end
    end)
end)

AddEventHandler("onClientResourceStart", function(name)
    if name == GetCurrentResourceName() then TriggerServerEvent("op77_games:ready") end
end)

AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, handle in pairs(playing) do pcall(Open77.audio.destroy, handle) end
end)
