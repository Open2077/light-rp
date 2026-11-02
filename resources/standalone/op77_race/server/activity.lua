-- The Light RP activity contract, seen from a provider. Everything that crosses into
-- op77_lightrp goes through this file:
--   exports (synchronous, may raise): activityRegister / activityCheck / activityEnter /
--     activityLeave / activityOwner / activityPlayer
--   events we raise:   op77_lightrp:activity:result, op77_lightrp:activity:status
--   events we receive: op77_lightrp:activity:join / :leaveRequest / :dropped (main.lua)
-- A synchronous export raises instead of returning nil, reason (core stopped, export
-- missing, export_yielded...): every call is wrapped and turned into false, reason.
local Config = RaceConfig

RaceActivity = { registered = false }
local A = RaceActivity

local byId, byKey = {}, {}
for _, def in ipairs(Config.activities) do
    byId[def.id] = def
    byKey[def.key] = def
end
A.byId, A.byKey = byId, byKey

local lastStatus = {}

local function log(text) print("[race:activity] " .. tostring(text)) end

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

function A.definition(activityId) return byId[activityId] end
function A.mine(activityId) return type(activityId) == "string" and byId[activityId] ~= nil end

function A.registration(def)
    return {
        id = def.id,
        resource = GetCurrentResourceName(),
        label = def.label,
        kind = def.kind,
        description = def.description,
        minPlayers = def.minPlayers,
        maxPlayers = def.maxPlayers,
        caps = {
            rpWeapons = Config.caps.rpWeapons == true,
            rpItems = Config.caps.rpItems == true,
            needs = Config.caps.needs == true,
            vehicles = Config.caps.vehicles == true,
        },
    }
end

-- Registers (or re-registers: the core replaces) every activity. True only when all
-- were accepted; the caller retries otherwise.
function A.register()
    local all = true
    for _, def in ipairs(Config.activities) do
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

-- Eligibility only (the core's rules). Returns true, or false and a sentence.
function A.check(playerId, activityId)
    local ok, reason = call("activityCheck", playerId, activityId)
    if ok == true then return true end
    return false, sentence(reason, "You cannot join this activity right now.")
end

-- The core re-checks, captures the return point and puts the RP weapons aside.
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

-- A stable key for this character across sessions (best times), or nil.
function A.characterKey(info)
    if type(info) ~= "table" or info.identifier == nil then return nil end
    return tostring(info.identifier) .. "/" .. tostring(info.characterKey or "default")
end

-- Results never pay cash or items: placement, score, stats and proposed reputation.
function A.result(playerId, activityId, result)
    if not A.mine(activityId) then return false end
    local ok, reason = TriggerEvent("op77_lightrp:activity:result", playerId, activityId, result)
    if ok == false then log("result event refused: " .. tostring(reason)) end
    return ok ~= false
end

local function digest(status)
    return table.concat({ tostring(status.phase), tostring(status.players), tostring(status.queued),
        tostring(status.joinable), tostring(status.detail) }, "|")
end

-- Sent on change only.
function A.status(activityId, status, force)
    if not A.mine(activityId) or type(status) ~= "table" then return false end
    local key = digest(status)
    if not force and lastStatus[activityId] == key then return false end
    lastStatus[activityId] = key
    TriggerEvent("op77_lightrp:activity:status", activityId, status)
    return true
end

function A.forgetStatus() lastStatus = {} end
