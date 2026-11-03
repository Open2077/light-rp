-- op77_turf <-> Light RP: the activity contract, in one place.
--
-- Exports of op77_lightrp, called synchronously (they never yield and never write the
-- database). A synchronous export RAISES when the call fails (core stopped, export
-- missing, export_yielded...), so every call is wrapped and turned into nil|false, reason.
--
-- This resource registers two activities: the war (TurfConfig.activity, "turf.war") and
-- the Gang Sweep (TurfConfig.pve.activity, "turf.pve"). Every call below takes the
-- activity id last; omitted, it is the war's.
--
--   TurfCore.register(def)                      activityRegister
--   TurfCore.bots()                             activityBots    -> true while staff bot mode is on
--   TurfCore.check(playerId, activity)          activityCheck   -> true | false, sentence
--   TurfCore.enter(playerId, activity)          activityEnter   -> true | false, sentence
--   TurfCore.leave(playerId, opts, activity)    activityLeave   -> true | false, reason
--   TurfCore.owner(playerId)                    activityOwner   -> activityId | nil
--   TurfCore.player(playerId)                   activityPlayer  -> { name, identifier, characterKey, gang?, job? } | nil
--   TurfCore.result(playerId, result, activity) "op77_lightrp:activity:result" (host-wide TriggerEvent)
--   TurfCore.status(status, force, activity)    "op77_lightrp:activity:status", only when it changed
--   TurfCore.announce(text, opts)               "op77_lightrp:announce"
TurfCore = { lastStatus = nil, lastStatuses = {} }
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
-- kind "pve": the Gang Sweep's definition.
function C.definition(kind)
    local a = kind == "pve" and cfg().pve.activity or cfg().activity
    local modes = {}
    for _, site in ipairs(cfg().sites) do
        if site.enabled ~= false then modes[#modes + 1] = { id = site.id, label = site.label } end
    end
    local caps = a.caps or {}
    local def = { id = a.id, resource = GetCurrentResourceName(), label = a.label, kind = a.kind,
        description = a.description, minPlayers = a.minPlayers, maxPlayers = a.maxPlayers,
        caps = { rpWeapons = caps.rpWeapons == true, rpItems = caps.rpItems == true,
            needs = caps.needs == true, vehicles = caps.vehicles == true },
        modes = #modes > 1 and modes or nil, modeKey = #modes > 1 and "site" or nil }
    -- Bot fill (the panel's bots toggle / bot-fill offer) only when bots really work on
    -- this build: the war's bot-filled and friendly matches need NPC create/remove; the
    -- sweep's allies fight beside players, so they also need per-player attitudes.
    local bots = TurfBots
    local canBots = type(bots) == "table" and bots.available() == true
    if kind == "pve" then
        -- Players against an NPC gang: the core offers these difficulties (within the
        -- player's reputation tier) and sends options.difficulty + options.scaling.
        def.pve = true
        local list = {}
        for _, d in ipairs(cfg().pve.difficulties or {}) do list[#list + 1] = d end
        def.difficulties = #list > 0 and list or nil
        def.botFill = (canBots and bots.alliesSupported() == true) or nil
    else
        def.botFill = canBots or nil
    end
    return def
end

function C.register(def)
    def = def or C.definition()
    local ok, why = C.call("activityRegister", def)
    if ok ~= true then return false, why or "refused" end
    if def.id == activityId() then C.lastStatus = nil else C.lastStatuses[def.id] = nil end
    return true
end

-- Staff bot mode (/lightrp.bots): the core's current value. Read after every successful
-- registration; an older core without the export (or no answer) reads as off.
function C.bots()
    return C.call("activityBots") == true
end

-- The contract's reasons are player-facing sentences; a transport failure is not, so it
-- becomes a generic sentence (and the log keeps the real reason).
local function verdict(name, playerId, activity)
    local ok, why = C.call(name, playerId, activity or activityId())
    if ok == true then return true end
    if ok == nil then
        log("%s(%s) failed: %s", name, tostring(playerId), tostring(why))
        return false, "Light RP did not answer. Try again in a moment."
    end
    return false, why or "You cannot join a turf war right now."
end

function C.check(playerId, activity) return verdict("activityCheck", playerId, activity) end
function C.enter(playerId, activity) return verdict("activityEnter", playerId, activity) end

function C.leave(playerId, opts, activity)
    local ok, why = C.call("activityLeave", playerId, activity or activityId(), opts or { returnPlayer = true })
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
function C.unqueue(playerId, activity)
    if C.owner(playerId) ~= nil then return false end
    return C.call("activityLeave", playerId, activity or activityId(), { returnPlayer = false }) == true
end

function C.owned(playerId, activity) return C.owner(playerId) == (activity or activityId()) end

function C.player(playerId)
    local info = C.call("activityPlayer", playerId)
    if type(info) ~= "table" then return nil end
    return info
end

function C.result(playerId, result, activity)
    TriggerEvent("op77_lightrp:activity:result", playerId, activity or activityId(), result)
end

-- Light RP's queue panel (status.queue, v1) in the change digest: a countdown running
-- down is no change (its deadline, to the second, is), a player or a number that moved is.
function C.queueDigest(queue, nowMs)
    if type(queue) ~= "table" or type(queue.lobbies) ~= "table" then return "-" end
    local parts = {}
    for _, l in ipairs(queue.lobbies) do
        parts[#parts + 1] = table.concat({ tostring(l.need), tostring(l.max), tostring(l.count), tostring(l.mode), tostring(l.joining),
            l.startsInMs and tostring(math.floor(((nowMs or 0) + l.startsInMs) / 1000)) or "", table.concat(l.players or {}, ",") }, "/")
    end
    return table.concat(parts, ";")
end

-- Sent on change only. `status` = { phase, players, queued, joinable, detail, queue };
-- `nowMs` dates a queue countdown.
function C.status(status, force, activity, nowMs)
    activity = activity or activityId()
    local key = ("%s|%d|%d|%s|%s|%s"):format(tostring(status.phase), status.players or 0, status.queued or 0,
        tostring(status.joinable), tostring(status.detail), C.queueDigest(status.queue, nowMs))
    local last
    if activity == activityId() then last = C.lastStatus else last = C.lastStatuses[activity] end
    if not force and key == last then return false end
    if activity == activityId() then C.lastStatus = key else C.lastStatuses[activity] = key end
    TriggerEvent("op77_lightrp:activity:status", activity, status)
    return true
end

-- Light RP forgot us (it stopped): every status is sent again once registered.
function C.forgetStatus()
    C.lastStatus, C.lastStatuses = nil, {}
end

function C.announce(text, opts)
    TriggerEvent("op77_lightrp:announce", text, opts or { title = "TURF WAR", durationMs = 10000 })
end
