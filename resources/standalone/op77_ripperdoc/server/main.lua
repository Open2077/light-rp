-- Server side of the ripperdoc interface: who has it open, and the exports the clinic's owner
-- (on LightRP: op77_lightrp/server/modules/ripperdoc.lua) calls. `payload` (PROTOCOL.md) is
-- passed through as is; the page's install / removal requests come back as the host event
-- "op77_ripperdoc:action" (playerId, { op, item, replace }) and are answered with result/update.

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

--- result(playerId, { ok, message, op, item }) -> true: the answer to one page action.
exports("result", function(pid, result)
    pid = playerId(pid)
    if not pid or not open[pid] then return nil, "not_open" end
    TriggerClientEvent("op77_ripperdoc:result", pid, type(result) == "table" and result or {})
    return true
end)

--- update(playerId, payload) -> true: fresh state for an open interface (same shape as open).
exports("update", function(pid, payload)
    pid = playerId(pid)
    if not pid or not open[pid] then return nil, "not_open" end
    TriggerClientEvent("op77_ripperdoc:update", pid, type(payload) == "table" and payload or {})
    return true
end)

-- The page asked for an install / removal: the clinic's owner decides (host event).
local lastAction = {}
RegisterNetEvent("op77_ripperdoc:action", function(p)
    local pid = playerId(source)
    if not pid or not open[pid] or type(p) ~= "table" then return end
    local t = Open77.time.monotonic()
    if lastAction[pid] and t - lastAction[pid] < 0.5 then return end
    lastAction[pid] = t
    local op, item = p.op, p.item
    if (op ~= "install" and op ~= "remove") or type(item) ~= "string" or #item > 64 or not item:match("^[%w_]+$") then return end
    TriggerEvent("op77_ripperdoc:action", pid, { op = op, item = item, replace = type(p.replace) == "string" and p.replace or nil })
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
    if pid then open[pid] = nil; lastAction[pid] = nil end
end)

-- Console preview without a chair: ripperdoc.open <playerId> [male|female]
RegisterCommand("ripperdoc.open", function(_, args)
    local pid = playerId(args[1])
    if not pid then print("[ripperdoc] usage: ripperdoc.open <playerId> [male|female]") return end
    open[pid] = true
    TriggerClientEvent("op77_ripperdoc:open", pid, { body = args[2] == "female" and "female" or "male" })
    print(("[ripperdoc] opened for %d"):format(pid))
end, true)

-- Staff / support: the same request the page sends (install / remove), answered like one.
RegisterCommand("ripperdoc.action", function(_, args)
    local pid, op, item = playerId(args[1]), args[2], args[3]
    if not pid or (op ~= "install" and op ~= "remove") or type(item) ~= "string" then
        print("[ripperdoc] usage: ripperdoc.action <playerId> <install|remove> <item>") return
    end
    print(("[ripperdoc] console action %s %s for %d"):format(op, item, pid))
    TriggerEvent("op77_ripperdoc:action", pid, { op = op, item = item })
end, true)

RegisterCommand("ripperdoc.close", function(_, args)
    local pid = playerId(args[1])
    if pid and open[pid] then open[pid] = nil TriggerClientEvent("op77_ripperdoc:close", pid) end
end, true)

print("[ripperdoc] op77_ripperdoc ready")
