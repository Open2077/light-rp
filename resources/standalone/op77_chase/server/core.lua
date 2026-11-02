-- op77_chase <-> Light RP: the activity contract, in one place.
--
-- Exports of op77_lightrp, called synchronously (they never yield and never write the
-- database). A synchronous export RAISES when the call fails (missing resource, missing
-- export, callee error), so every call is wrapped and turned into `nil|false, reason`.
--
--   ChaseCore.register(def)            activityRegister
--   ChaseCore.check(playerId)          activityCheck   -> true | false, reason (player-facing)
--   ChaseCore.enter(playerId)          activityEnter   -> true | false, reason
--   ChaseCore.leave(playerId, opts)    activityLeave   -> true | false, reason
--   ChaseCore.owner(playerId)          activityOwner   -> activityId | nil
--   ChaseCore.player(playerId)         activityPlayer  -> { name, identifier, characterKey } | nil
--   ChaseCore.result(playerId, result) "op77_lightrp:activity:result" (host-wide TriggerEvent)
--   ChaseCore.status(status)           "op77_lightrp:activity:status", only when it changed
ChaseCore = { resource = "op77_lightrp", lastStatus = nil }
local C = ChaseCore

local function activityId() return ChaseConfig.activity.id end

local function log(fmt, ...)
    print(("[op77_chase] " .. fmt):format(...))
end

-- Synchronous export call: the values, or nil plus a reason. Never raises.
function C.call(name, ...)
    if type(Open77) ~= "table" or type(Open77.exports) ~= "table" or type(Open77.exports.callSync) ~= "function" then
        return nil, "exports_unavailable"
    end
    local packed = table.pack(pcall(Open77.exports.callSync, C.resource, name, ...))
    if not packed[1] then return nil, tostring(packed[2]) end
    return table.unpack(packed, 2, packed.n)
end

function C.register(def)
    local ok, why = C.call("activityRegister", def)
    if ok ~= true then return false, why or "refused" end
    return true
end

-- The contract's reasons are player-facing sentences; a transport failure is not, so it
-- becomes a generic sentence (and the log keeps the real reason).
local function verdict(name, playerId, ...)
    local ok, why = C.call(name, playerId, activityId(), ...)
    if ok == true then return true end
    if ok == nil then
        log("%s(%s) failed: %s", name, tostring(playerId), tostring(why))
        return false, "Light RP did not answer. Try again in a moment."
    end
    return false, why or "You cannot join a chase right now."
end

function C.check(playerId) return verdict("activityCheck", playerId) end
function C.enter(playerId) return verdict("activityEnter", playerId) end

function C.leave(playerId, opts)
    local ok, why = C.call("activityLeave", playerId, activityId(), opts or { returnPlayer = true })
    if ok ~= true then
        log("activityLeave(%s) refused: %s", tostring(playerId), tostring(why))
        return false, why
    end
    return true
end

function C.owner(playerId)
    local owner = C.call("activityOwner", playerId)
    return type(owner) == "string" and owner or nil
end

function C.owned(playerId) return C.owner(playerId) == activityId() end

function C.player(playerId)
    local info = C.call("activityPlayer", playerId)
    if type(info) ~= "table" then return nil end
    return info
end

function C.result(playerId, result)
    TriggerEvent("op77_lightrp:activity:result", playerId, activityId(), result)
end

-- Sent on change only. `status` = { phase, players, queued, joinable, detail }.
function C.status(status, force)
    local key = ("%s|%d|%d|%s|%s"):format(tostring(status.phase), status.players or 0, status.queued or 0,
        tostring(status.joinable), tostring(status.detail))
    if not force and key == C.lastStatus then return false end
    C.lastStatus = key
    TriggerEvent("op77_lightrp:activity:status", activityId(), status)
    return true
end
