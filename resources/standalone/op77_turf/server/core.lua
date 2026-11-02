-- op77_turf <-> Light RP: the activity contract, in one place.
--
-- Exports of op77_lightrp, called synchronously (they never yield and never write the
-- database). A synchronous export RAISES when the call fails (core stopped, export
-- missing, export_yielded...), so every call is wrapped and turned into nil|false, reason.
--
--   TurfCore.register(def)            activityRegister
--   TurfCore.check(playerId)          activityCheck   -> true | false, sentence
--   TurfCore.enter(playerId)          activityEnter   -> true | false, sentence
--   TurfCore.leave(playerId, opts)    activityLeave   -> true | false, reason
--   TurfCore.owner(playerId)          activityOwner   -> activityId | nil
--   TurfCore.player(playerId)         activityPlayer  -> { name, identifier, characterKey, gang?, job? } | nil
--   TurfCore.result(playerId, result) "op77_lightrp:activity:result" (host-wide TriggerEvent)
--   TurfCore.status(status)           "op77_lightrp:activity:status", only when it changed
--   TurfCore.announce(text, opts)     "op77_lightrp:announce"
TurfCore = { lastStatus = nil }
local C = TurfCore

local function cfg() return TurfConfig end
local function activityId() return cfg().activity.id end
local function log(fmt, ...) print(("[op77_turf] " .. fmt):format(...)) end

-- Synchronous export call: the values, or nil plus a reason. Never raises.
function C.call(name, ...)
    if type(Open77) ~= "table" or type(Open77.exports) ~= "table" or type(Open77.exports.callSync) ~= "function" then
        return nil, "exports_unavailable"
    end
    local packed = table.pack(pcall(Open77.exports.callSync, cfg().core, name, ...))
    if not packed[1] then return nil, tostring(packed[2]) end
    return table.unpack(packed, 2, packed.n)
end

-- The registration Light RP gets (and again after every core restart). `modes` /
-- `modeKey` are the core's optional site choice for the panel: options.site.
function C.definition()
    local a = cfg().activity
    local modes = {}
    for _, site in ipairs(cfg().sites) do
        if site.enabled ~= false then modes[#modes + 1] = { id = site.id, label = site.label } end
    end
    return { id = a.id, resource = GetCurrentResourceName(), label = a.label, kind = a.kind,
        description = a.description, minPlayers = a.minPlayers, maxPlayers = a.maxPlayers,
        caps = { rpWeapons = a.caps.rpWeapons == true, rpItems = a.caps.rpItems == true,
            needs = a.caps.needs == true, vehicles = a.caps.vehicles == true },
        modes = #modes > 1 and modes or nil, modeKey = #modes > 1 and "site" or nil }
end

function C.register(def)
    local ok, why = C.call("activityRegister", def or C.definition())
    if ok ~= true then return false, why or "refused" end
    C.lastStatus = nil
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
    return false, why or "You cannot join a turf war right now."
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

function C.announce(text, opts)
    TriggerEvent("op77_lightrp:announce", text, opts or { title = "TURF WAR", durationMs = 10000 })
end
