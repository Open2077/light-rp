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

-- The client host drops a plain net event of more than 1024 JSON values or ~48 KiB, and tells
-- nobody (kMaximumEventValues, scripting/src/ResourceHost.cpp). A full clinic payload (34
-- implants with their stats) is past it: a payload over LATENT_VALUES (counted generously,
-- every key and every value) or LATENT_BYTES goes as a latent event, reassembled by the host and
-- delivered under the same name. A newer payload replaces a stream to the same player still in
-- flight; when that stream was the "open", the newer one is sent as the "open" (same shape).
local LATENT_VALUES, LATENT_BYTES, LATENT_RATE = 900, 40 * 1024, 512 * 1024
local streams = {} -- playerId -> { id, name }
local function countValues(value, depth)
    if type(value) ~= "table" then return 1 end
    if (depth or 0) > 12 then return 1 end
    local n = 1
    for key, item in pairs(value) do n = n + 1 + countValues(item, (depth or 0) + 1); if type(key) == "table" then n = n + 1 end end
    return n
end
local function sizeOf(value)
    if type(json) ~= "table" or type(json.encode) ~= "function" then return 0 end
    local ok, text = pcall(json.encode, value)
    return ok and type(text) == "string" and #text or 0
end
local function cancelStream(pid)
    local s = streams[pid]
    streams[pid] = nil
    if not s or type(Open77.net) ~= "table" or type(Open77.net.cancelLatent) ~= "function" then return nil end
    local ok, cancelled = pcall(Open77.net.cancelLatent, s.id)
    return ok and cancelled == true and s or nil
end
local function deliver(pid, name, payload)
    if (countValues(payload) > LATENT_VALUES or sizeOf(payload) > LATENT_BYTES) and type(TriggerLatentClientEvent) == "function" then
        local previous = cancelStream(pid)
        if previous and previous.name == "op77_ripperdoc:open" then name = "op77_ripperdoc:open" end
        local id, why = TriggerLatentClientEvent(name, pid, LATENT_RATE, payload)
        if id then streams[pid] = { id = id, name = name } return true end
        print(("[ripperdoc] %s for %d not sent: %s"):format(name, pid, tostring(why)))
        return nil, why
    end
    TriggerClientEvent(name, pid, payload)
    return true
end
RipperdocTransport = { countValues = countValues, deliver = deliver, LATENT_VALUES = LATENT_VALUES } -- tests

--- open(playerId, payload?) -> true | nil, reason
exports("open", function(pid, payload)
    pid = playerId(pid)
    if not pid then return nil, "invalid_player" end
    open[pid] = true
    return deliver(pid, "op77_ripperdoc:open", type(payload) == "table" and payload or {})
end)

--- close(playerId) -> true. Closes without asking the client to report back.
exports("close", function(pid)
    pid = playerId(pid)
    if not pid then return nil, "invalid_player" end
    if open[pid] then
        open[pid] = nil
        cancelStream(pid)
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
    return deliver(pid, "op77_ripperdoc:update", type(payload) == "table" and payload or {})
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
    cancelStream(pid)
    TriggerEvent("op77_ripperdoc:closed", pid)
end)

AddEventHandler("onPlayerDisconnected", function(pid)
    pid = playerId(pid)
    if pid then open[pid] = nil; lastAction[pid] = nil; streams[pid] = nil end
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
