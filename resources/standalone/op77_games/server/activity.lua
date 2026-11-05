-- The Light RP activity contract, seen from a provider. Everything that crosses into
-- op77_lightrp goes through this file:
--   exports (synchronous, may raise): activityRegister / activityCheck / activityEnter /
--     activityLeave / activityOwner / activityPlayer / notice
--   events we raise:   op77_lightrp:activity:result / :status / :recap
--   events we receive: op77_lightrp:activity:join / :leaveRequest / :dropped / :ready (main.lua)
-- A synchronous export raises instead of returning nil, reason (core stopped, export
-- missing...): every call is wrapped and turned into nil, reason.
local Config = GamesConfig

GamesActivity = { registered = false, list = {} }
local A = GamesActivity

local byId = {}
local lastStatus = {}

local function log(text) print("[games:activity] " .. tostring(text)) end

local function call(name, ...)
    if exports == nil then return nil, "core_unavailable" end
    local ok, first, second = pcall(function(...)
        local proxy = exports[Config.core]
        return proxy[name](proxy, ...)
    end, ...)
    if not ok then return nil, "core_error:" .. tostring(first) end
    return first, second
end
A.call = call

-- A mode file declares its activity through GamesEngine.mode.
function A.add(def)
    if byId[def.id] == nil then A.list[#A.list + 1] = def end
    byId[def.id] = def
end
function A.definition(activityId) return byId[activityId] end
function A.mine(activityId) return type(activityId) == "string" and byId[activityId] ~= nil end

-- Each map is a join choice in the panel (at most 8), handed back as options.map. No
-- botFill: these games have no bots.
function A.registration(def)
    local modes = {}
    for _, map in ipairs(def.maps) do
        if #modes >= 8 then break end
        modes[#modes + 1] = { id = map.id, label = map.name }
    end
    return {
        id = def.id, resource = GetCurrentResourceName(), label = def.label, kind = def.kind,
        description = def.description, minPlayers = def.minPlayers, maxPlayers = def.maxPlayers,
        modes = modes, modeKey = "map",
        caps = {
            rpWeapons = Config.caps.rpWeapons == true, rpItems = Config.caps.rpItems == true,
            needs = Config.caps.needs == true, vehicles = Config.caps.vehicles == true,
        },
    }
end

-- Registers (or re-registers: the core replaces) every activity. True only when all
-- were accepted; the caller retries otherwise.
function A.register()
    local all = true
    for _, def in ipairs(A.list) do
        local ok, reason = call("activityRegister", A.registration(def))
        if ok ~= true then
            all = false
            log(("register %s refused: %s"):format(def.id, tostring(reason)))
        end
    end
    if all and not A.registered then log("activities registered with " .. Config.core) end
    A.registered = all
    if all then lastStatus = {} end
    return all
end

local function sentence(reason, fallback)
    if type(reason) == "string" and reason ~= "" and not reason:match("^core_") then return reason end
    if type(reason) == "string" and reason:match("^core_") then return "Light RP is not ready yet. Try again in a moment." end
    return fallback
end

-- Eligibility only. Returns true, or false and a sentence.
function A.check(playerId, activityId)
    local ok, reason = call("activityCheck", playerId, activityId)
    if ok == true then return true end
    return false, sentence(reason, "You cannot join this activity right now.")
end

-- The core re-checks, captures the return point and puts the RP weapons aside. Always
-- before the move into our bucket.
function A.enter(playerId, activityId)
    local ok, reason = call("activityEnter", playerId, activityId)
    if ok == true then return true end
    return false, sentence(reason, "You cannot join this activity right now.")
end

-- Releases ownership; with returnPlayer (default) the core sends the player back.
function A.leave(playerId, activityId, opts)
    local ok, reason = call("activityLeave", playerId, activityId, opts or { returnPlayer = true })
    if ok == true then return true end
    return false, reason
end

function A.owner(playerId)
    local owner = call("activityOwner", playerId)
    if type(owner) == "string" then return owner end
    return nil
end

-- { name, identifier, characterKey } or nil.
function A.player(playerId)
    local info = call("activityPlayer", playerId)
    if type(info) == "table" then return info end
    return nil
end

-- One player-facing line in Light RP's own notice. False when the core cannot show it.
function A.notice(playerId, kind, title, text, durationMs)
    return call("notice", playerId, { kind = kind or "info", title = title, body = text or "", durationMs = durationMs or 4000 }) == true
end

function A.result(playerId, activityId, result)
    if not A.mine(activityId) then return false end
    local ok, reason = TriggerEvent("op77_lightrp:activity:result", playerId, activityId, result)
    if ok == false then log("result event refused: " .. tostring(reason)) end
    return ok ~= false
end

function A.recap(activityId, recap)
    if not A.mine(activityId) or type(recap) ~= "table" then return false end
    TriggerEvent("op77_lightrp:activity:recap", activityId, recap)
    return true
end

-- status.queue v1 in the digest: a countdown running down is no change (its deadline,
-- to the second, is); a player or a number that moved is.
function A.queueDigest(queue, nowMs)
    if type(queue) ~= "table" or type(queue.lobbies) ~= "table" then return "-" end
    local parts = {}
    for _, l in ipairs(queue.lobbies) do
        parts[#parts + 1] = table.concat({ tostring(l.need), tostring(l.max), tostring(l.mode), tostring(l.joining),
            l.startsInMs and tostring(math.floor(((nowMs or 0) + l.startsInMs) / 1000)) or "", table.concat(l.players or {}, ",") }, "/")
    end
    return table.concat(parts, ";")
end

local function digest(status, nowMs)
    return table.concat({ tostring(status.phase), tostring(status.players), tostring(status.queued),
        tostring(status.joinable), tostring(status.detail), A.queueDigest(status.queue, nowMs) }, "|")
end

-- Sent on change only. `nowMs` dates a queue countdown.
function A.status(activityId, status, force, nowMs)
    if not A.mine(activityId) or type(status) ~= "table" then return false end
    local key = digest(status, nowMs)
    if not force and lastStatus[activityId] == key then return false end
    lastStatus[activityId] = key
    TriggerEvent("op77_lightrp:activity:status", activityId, status)
    return true
end

function A.forgetStatus() lastStatus = {} end
