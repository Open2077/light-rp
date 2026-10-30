-- Server side of the ripperdoc interface: who has it open, and the two exports other resources
-- call. The page is UI only for now: `payload` (PROTOCOL.md) is passed through as is.

local open = {} -- playerId -> true

local function playerId(value)
    local n = math.tointeger(tonumber(value))
    if n and n > 0 then return n end
    return nil
end

--- open(playerId, payload?) -> true | nil, reason
exports("open", function(pid, payload)
    pid = playerId(pid)
    if not pid then return nil, "invalid_player" end
    open[pid] = true
    TriggerClientEvent("op77_ripperdoc:open", pid, type(payload) == "table" and payload or {})
    return true
end)

--- close(playerId) -> true. Closes without asking the client to report back.
exports("close", function(pid)
    pid = playerId(pid)
    if not pid then return nil, "invalid_player" end
    if open[pid] then
        open[pid] = nil
        TriggerClientEvent("op77_ripperdoc:close", pid)
    end
    return true
end)

exports("isOpen", function(pid)
    pid = playerId(pid)
    return pid ~= nil and open[pid] == true
end)

-- The patient closed the interface himself: tell the host (the gamemode stands him up).
RegisterNetEvent("op77_ripperdoc:closed", function()
    local pid = playerId(source)
    if not pid or not open[pid] then return end
    open[pid] = nil
    TriggerEvent("op77_ripperdoc:closed", pid)
end)

AddEventHandler("onPlayerDisconnected", function(pid)
    pid = playerId(pid)
    if pid then open[pid] = nil end
end)

-- Console preview without a chair: ripperdoc.open <playerId> [male|female]
RegisterCommand("ripperdoc.open", function(_, args)
    local pid = playerId(args[1])
    if not pid then print("[ripperdoc] usage: ripperdoc.open <playerId> [male|female]") return end
    open[pid] = true
    TriggerClientEvent("op77_ripperdoc:open", pid, { body = args[2] == "female" and "female" or "male" })
    print(("[ripperdoc] opened for %d"):format(pid))
end, true)

RegisterCommand("ripperdoc.close", function(_, args)
    local pid = playerId(args[1])
    if pid and open[pid] then open[pid] = nil TriggerClientEvent("op77_ripperdoc:close", pid) end
end, true)

print("[ripperdoc] op77_ripperdoc ready")
