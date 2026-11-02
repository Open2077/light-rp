-- op77_arena: the Light RP activity contract, and nothing else.
--
-- Every call into op77_lightrp goes through here: synchronous exports (which raise
-- when the core is stopped or older than the contract) are wrapped so a refusal is
-- always `false, sentence`, never an error. Results and statuses are host-wide
-- events (TriggerEvent); a status is sent only when it changed.

ArenaCore = {}
local C = ArenaCore

C.resource = LightRpArena.core

local EVENTS = {
    result = "op77_lightrp:activity:result",
    status = "op77_lightrp:activity:status",
}
C.events = EVENTS

local NO_ANSWER = "Light RP did not answer. Try again in a moment."

function C.call(name, ...)
    if type(Open77) ~= "table" or type(Open77.exports) ~= "table" or type(Open77.exports.callSync) ~= "function" then
        return nil, "exports_unavailable"
    end
    local packed = table.pack(pcall(Open77.exports.callSync, C.resource, name, ...))
    if not packed[1] then return nil, tostring(packed[2]) end
    return table.unpack(packed, 2, packed.n)
end

local function log(text)
    print(("[op77_arena] %s"):format(text))
end

-- A yes/no export: true, or false plus the sentence shown to the player.
local function verdict(name, fallback, ...)
    local ok, why = C.call(name, ...)
    if ok == true then return true end
    if ok == nil then
        log(("%s failed: %s"):format(name, tostring(why)))
        return false, NO_ANSWER
    end
    if type(why) ~= "string" or why == "" then why = fallback end
    return false, why
end

function C.register(def)
    local ok, why = C.call("activityRegister", def)
    if ok == true then return true end
    return false, why
end

function C.check(playerId, activityId)
    return verdict("activityCheck", "You cannot join right now.", playerId, activityId)
end

function C.enter(playerId, activityId)
    return verdict("activityEnter", "You cannot join right now.", playerId, activityId)
end

function C.leave(playerId, activityId, opts)
    if type(opts) ~= "table" then opts = { returnPlayer = true } end
    if opts.returnPlayer == nil then opts.returnPlayer = true end
    local ok, why = C.call("activityLeave", playerId, activityId, opts)
    if ok == true then return true end
    return false, why
end

function C.owner(playerId)
    local owner = C.call("activityOwner", playerId)
    if type(owner) == "string" then return owner end
    return nil
end

function C.player(playerId)
    local player = C.call("activityPlayer", playerId)
    if type(player) == "table" then return player end
    return nil
end

function C.result(playerId, activityId, result)
    TriggerEvent(EVENTS.result, playerId, activityId, result)
end

-- Sent on change only: Light RP pushes statuses to every open panel.
local lastStatus = {}
function C.status(activityId, status, force)
    if type(status) ~= "table" then return false end
    local key = ("%s|%d|%d|%s|%s"):format(tostring(status.phase), math.floor(tonumber(status.players) or 0),
        math.floor(tonumber(status.queued) or 0), tostring(status.joinable ~= false), tostring(status.detail or ""))
    if not force and lastStatus[activityId] == key then return false end
    lastStatus[activityId] = key
    TriggerEvent(EVENTS.status, activityId, status)
    return true
end

function C.forgetStatuses() lastStatus = {} end
