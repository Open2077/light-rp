-- op77_loadscreen server: a thin, optional front for the client events.
--   exports.op77_loadscreen:cover(playerId, opts) -> id
--   exports.op77_loadscreen:release(playerId, id?)  (nil id: every open cover)
-- A gamemode that must not depend on this resource sends the same events itself:
--   TriggerClientEvent("op77_loadscreen:cover", playerId, opts)
--   TriggerClientEvent("op77_loadscreen:release", playerId, { id = id })
-- opts are validated on the client (client/cover.lua normalize).
local seq = 0

local function validPlayer(playerId)
    return type(playerId) == "number" and playerId > 0 and math.type(playerId) == "integer"
end

local function cover(playerId, opts)
    if not validPlayer(playerId) then return nil, "invalid_player_id" end
    opts = type(opts) == "table" and opts or {}
    local id = opts.id
    if id == nil then seq = seq + 1; id = "srv:" .. seq end
    local payload = {}
    for k, v in pairs(opts) do payload[k] = v end
    payload.id = tostring(id)
    TriggerClientEvent("op77_loadscreen:cover", playerId, payload)
    return payload.id
end

local function release(playerId, id)
    if not validPlayer(playerId) then return false, "invalid_player_id" end
    TriggerClientEvent("op77_loadscreen:release", playerId, { id = id ~= nil and tostring(id) or nil })
    return true
end

exports("cover", cover)
exports("release", release)

-- Staff check without moving anyone: /loadscreen.test [seconds] [playerId]
-- Restricted (ACL command.loadscreen.test). From the console, give the player id.
RegisterCommand("loadscreen.test", function(source, args)
    local seconds = math.max(1, math.min(30, tonumber(args and args[1]) or 6))
    local target = tonumber(args and args[2]) or source
    target = target and math.tointeger(target)
    if not target or target <= 0 then print("usage: loadscreen.test [seconds] <playerId>"); return end
    local id = cover(target, { title = "Test destination", subtitle = "op77_loadscreen", zone = "Test",
        expectedMs = seconds * 1000, timeoutMs = (seconds + 10) * 1000 })
    SetTimeout(seconds * 1000, function() release(target, id) end)
    print(("[op77_loadscreen] test cover %s on player %d for %d s"):format(tostring(id), target, seconds))
end, true)
