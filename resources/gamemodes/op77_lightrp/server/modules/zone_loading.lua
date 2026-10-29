-- Zone loading screens: the LightRP loading cover over a zone change (an interior,
-- a mission instance, the arrival hall <-> the city, a service lift).
-- The cover is drawn by the standalone resource op77_loadscreen
-- (resources/standalone/op77_loadscreen). It is reached through its client events
-- only, so LightRP keeps working when that resource is not loaded: the events are
-- then simply not handled and the platform fade stays the only transition.
--
--   local cover = LightRP.zoneLoading.cover(player, { title = "Kabuki Studio",
--       subtitle = "Private residence", zone = "Watson", target = position })
--   ... teleport / respawn ...
--   LightRP.zoneLoading.release(player, cover)
--
-- `target` lets the client lift the cover by itself once the body stands on it
-- (moves that are not awaited, such as a respawn); `release` lifts it at once
-- when the caller knows the move ended (an awaited teleport, success or not).
-- The client also gives up after `timeoutMs` (30 s by default).
local Z = LightRP.module("zoneLoading", {})
local seq = 0

local function position(p)
    if type(p) ~= "table" then return nil end
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    if x and y and z then return { x = x, y = y, z = z } end
end

function Z.cover(player, screen)
    if type(player) ~= "number" or player <= 0 then return nil end
    screen = type(screen) == "table" and screen or {}
    seq = seq + 1
    local id = "lightrp:" .. seq
    TriggerClientEvent("op77_loadscreen:cover", player, {
        id = id,
        title = screen.title, subtitle = screen.subtitle, zone = screen.zone,
        target = position(screen.target), timeoutMs = screen.timeoutMs, expectedMs = screen.expectedMs,
    })
    return id
end

function Z.release(player, id)
    if type(player) ~= "number" or player <= 0 or id == nil then return end
    TriggerClientEvent("op77_loadscreen:release", player, { id = id })
end
