-- op77_chase <-> Light RP: the activity contract, in one place.
--
-- Exports of op77_lightrp, called synchronously (they never yield and never write the
-- database). A synchronous export RAISES when the call fails (missing resource, missing
-- export, callee error), so every call is wrapped and turned into `nil|false, reason`.
--
-- This resource provides three activities (chase.1v1, chase.wanted and chase.pve): every
-- call takes the activity id last, and defaults to chase.1v1.
--
--   ChaseCore.register(def)                  activityRegister
--   ChaseCore.check(playerId, aid?)          activityCheck   -> true | false, reason (player-facing)
--   ChaseCore.enter(playerId, aid?)          activityEnter   -> true | false, reason
--   ChaseCore.leave(playerId, opts, aid?)    activityLeave   -> true | false, reason
--   ChaseCore.owner(playerId)                activityOwner   -> activityId | nil
--   ChaseCore.player(playerId)               activityPlayer  -> { name, identifier, characterKey } | nil
--   ChaseCore.result(playerId, result, aid?) "op77_lightrp:activity:result" (host-wide TriggerEvent)
--   ChaseCore.status(status, force, aid?)    "op77_lightrp:activity:status", only when it changed
ChaseCore = { resource = "op77_lightrp", lastStatus = {} }
local C = ChaseCore

local function activityId(aid) return aid or ChaseConfig.activity.id end

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
local function verdict(name, playerId, aid)
    local ok, why = C.call(name, playerId, activityId(aid))
    if ok == true then return true end
    if ok == nil then
        log("%s(%s) failed: %s", name, tostring(playerId), tostring(why))
        return false, "Light RP did not answer. Try again in a moment."
    end
    return false, why or "You cannot join a chase right now."
end

function C.check(playerId, aid) return verdict("activityCheck", playerId, aid) end
function C.enter(playerId, aid) return verdict("activityEnter", playerId, aid) end

function C.leave(playerId, opts, aid)
    local ok, why = C.call("activityLeave", playerId, activityId(aid), opts or { returnPlayer = true })
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

-- The player left our queue through one of our own commands. If he had joined from
-- Light RP's panel, the hub still lists him as queued (and refuses a new join to this
-- activity) until it expires; activityLeave on a queued-only player clears that. Never
-- for an owned player: activityLeave would send him home.
function C.unqueue(playerId, aid)
    if C.owner(playerId) ~= nil then return false end
    return C.call("activityLeave", playerId, activityId(aid), { returnPlayer = false }) == true
end

function C.owned(playerId, aid) return C.owner(playerId) == activityId(aid) end

function C.player(playerId)
    local info = C.call("activityPlayer", playerId)
    if type(info) ~= "table" then return nil end
    return info
end

function C.result(playerId, result, aid)
    TriggerEvent("op77_lightrp:activity:result", playerId, activityId(aid), result)
end

-- Sent on change only, per activity. `status` = { phase, players, queued, joinable, detail }.
function C.status(status, force, aid)
    aid = activityId(aid)
    local key = ("%s|%d|%d|%s|%s"):format(tostring(status.phase), status.players or 0, status.queued or 0,
        tostring(status.joinable), tostring(status.detail))
    if not force and key == C.lastStatus[aid] then return false end
    C.lastStatus[aid] = key
    TriggerEvent("op77_lightrp:activity:status", aid, status)
    return true
end

-- Light RP restarted: it forgot every status; the next one is sent whatever it says.
function C.resetStatus() C.lastStatus = {} end
