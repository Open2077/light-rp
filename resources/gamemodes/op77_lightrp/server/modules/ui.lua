-- Server-side owner of the page's `server` state key and of the periodic push:
-- name, population, version. Everything else comes from the module that owns it.
local Config = LightRpConfig
local Ui = LightRP.module("ui", {})

LightRP.stateProvider("server", function()
    local players = GetPlayers()
    return {
        name = Config.serverName,
        playersOnline = #players,
        maxPlayers = tonumber(GetConvar and GetConvar("sv_maxclients", "0")) or 0,
        version = GetResourceMetadata and GetResourceMetadata(GetCurrentResourceName(), "version") or nil,
    }
end)

function Ui.onConnected()
    -- Everyone's population chip moves.
    LightRP.broadcastState({ "server", "online" })
end

function Ui.onDisconnected()
    LightRP.broadcastState({ "server", "online" })
end

LightRP.action("menu.close", function() end) -- the client closes locally; nothing to do here

CreateThread(function()
    while true do
        Wait(Config.statePushMs)
        LightRP.broadcastState({ "server" })
    end
end)
