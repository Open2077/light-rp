-- Ripperdoc: a player lying on a ripperdoc chair (op77_scenes, scene "ripperdoc") gets the
-- clinic interface (op77_ripperdoc) once the sit-down has played; leaving the interface stands
-- him up, and a scene that ends another way closes it.
--
-- The clinic sells what server/modules/cyberware.lua knows: the page gets that catalogue, the
-- character's installed implants, bank balance and salvaged parts, and every install / removal
-- it asks for goes through LightRP.cyberware.operate (payment, parts, surgery, persistence).
local Ripperdoc = LightRP.module("ripperdoc", {})

local C = {
    scene = "ripperdoc",
    -- the sit-down (v01__v_sits_down_on_operating_chair, 6800 ms) before the interface opens
    openDelayMs = 6600,
    clinic = { name = "Street Clinic", doctor = "Ripperdoc on duty", tagline = "Night City // licensed surgery" },
}

local seated = {} -- playerId -> spot id of the chair the interface was opened for

local function call(resource, name, ...)
    local args = table.pack(...)
    local ok, a, b = pcall(function() return exports[resource][name](exports[resource], table.unpack(args, 1, args.n)) end)
    if not ok then return nil, tostring(a) end
    return a, b
end

local function payloadFor(playerId)
    local c = LightRP.characters and LightRP.characters.get(playerId)
    local wallet = LightRP.money and LightRP.money.get(playerId)
    local payload = LightRP.cyberware and LightRP.cyberware.view(playerId) or {}
    payload.body = c and c.bodyFamily == "female" and "female" or "male"
    payload.clinic = C.clinic
    payload.patient = { name = LightRP.characters and LightRP.characters.displayName(playerId) or GetPlayerName(playerId),
        id = wallet and wallet.number or nil }
    return payload
end

function Ripperdoc.isSeated(playerId) return seated[playerId] ~= nil end

-- An install / removal asked by the page (relayed by op77_ripperdoc): the answer, then the
-- fresh state (installed list, balance, parts) once the surgery is over.
AddEventHandler("op77_ripperdoc:action", function(playerId, p)
    playerId = tonumber(playerId)
    if not playerId or type(p) ~= "table" or not LightRP.cyberware then return end
    local op, item = tostring(p.op or ""), tostring(p.item or "")
    LightRP.cyberware.operate(playerId, op, item, function(ok, message)
        LightRP.log("ripperdoc: %s %s for %d -> %s (%s)", op, item, playerId, ok and "ok" or "refused", tostring(message))
        call("op77_ripperdoc", "result", playerId, { ok = ok == true, message = message, op = op, item = item })
        call("op77_ripperdoc", "update", playerId, payloadFor(playerId))
    end)
end)

AddEventHandler("op77_scenes:started", function(p)
    if type(p) ~= "table" or p.scene ~= C.scene then return end
    local playerId, spot = tonumber(p.playerId), p.spot
    if not playerId then return end
    seated[playerId] = spot
    CreateThread(function()
        Wait(C.openDelayMs)
        if seated[playerId] ~= spot then return end -- got up (or another chair) during the sit-down
        local current = call("op77_scenes", "current", playerId)
        if type(current) ~= "table" or current.spot ~= spot then seated[playerId] = nil return end
        local ok, why = call("op77_ripperdoc", "open", playerId, payloadFor(playerId))
        if not ok then print(("[lightrp] ripperdoc interface refused for %d: %s"):format(playerId, tostring(why))) end
    end)
end)

AddEventHandler("op77_scenes:ended", function(p)
    if type(p) ~= "table" or p.scene ~= C.scene then return end
    local playerId = tonumber(p.playerId)
    if not playerId or seated[playerId] == nil then return end
    seated[playerId] = nil
    call("op77_ripperdoc", "close", playerId)
end)

-- The patient closed the interface: he gets up.
AddEventHandler("op77_ripperdoc:closed", function(playerId)
    playerId = tonumber(playerId)
    if not playerId or seated[playerId] == nil then return end
    seated[playerId] = nil
    call("op77_scenes", "stand", playerId)
end)

function Ripperdoc.onDisconnected(playerId) seated[playerId] = nil end
