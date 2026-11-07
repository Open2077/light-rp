local lightrpEvery = LightRP.every or function(ms, fn) while true do Wait(tonumber(ms) or 1000); fn() end end -- framework.lua (tests: the plain loop, in the calling thread)
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
    -- Everyone's population chip moves (coalesced: framework.lua onlineChanged).
    LightRP.onlineChanged()
end

function Ui.onDisconnected()
    LightRP.onlineChanged()
end

LightRP.action("menu.close", function() end) -- the client closes locally; nothing to do here

CreateThread(function()
    lightrpEvery(Config.statePushMs, function()
        
        LightRP.broadcastState({ "server" })
    end, "ui:27")
end)
