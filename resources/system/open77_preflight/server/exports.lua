-- The door list for other resources: Warden's bans and whitelist, from Lua.
--
--   local door = exports.open77_preflight
--   door:ban(userId, "Griefing", 86400, "Judy")      -- 24 h; 0 or nil = permanent
--   if door:isBanned(userId) then ... end
--   door:whitelistAdd(userId, "V")
--   for _, request in ipairs(door:requests("pending")) do door:approve(request.userId) end
--   door:kick(playerId, "AFK for too long")
--
-- Every edit goes through Open77.access, so Warden, the console and access.json show
-- the same state at once, and a player who is on the launcher's server check reacts
-- at once too. The actor Warden records is
-- "resource:open77_preflight/<calling resource>[:<actor you pass>]".
--
-- The calling resource does not need players.access itself, which is why the exports
-- that list or change anything only answer the resources named in config.lua
-- (api.trusted). They return nil, "caller_denied" to anybody else. The yes/no
-- questions (isBanned, isWhitelisted, whitelistEnabled, maintenance) are open.
--
-- Account ids are the Master account GUID: session.player.userId in preflight,
-- player.userId in onPlayerConnecting, Open77.players.identity(playerId).userId in game.

local access = Open77.access

local trusted, trustAll = {}, false
do
    local api = type(PreflightConfig) == "table" and type(PreflightConfig.api) == "table" and PreflightConfig.api or {}
    for _, name in ipairs(type(api.trusted) == "table" and api.trusted or {}) do
        if name == "*" then trustAll = true
        elseif type(name) == "string" then trusted[name] = true end
    end
end

local function caller()
    return GetInvokingResource() or GetCurrentResourceName()
end

local function allowed()
    local name = GetInvokingResource()
    -- No invoking resource: this resource calling its own functions.
    return name == nil or trustAll or trusted[name] == true
end

-- "<calling resource>" or "<calling resource>:<actor>": whom Warden shows after this resource's name.
local function behalf(actor)
    local name = caller()
    if type(actor) == "string" and actor ~= "" then return name .. ":" .. actor end
    return name
end

-- An Open77.access answer as an export answer: the value, or nil and the reason.
local function answer(value, reason)
    if value == false and reason ~= nil then return nil, reason end
    return value
end

local function guarded(fn)
    return function(...)
        if not allowed() then return nil, "caller_denied" end
        return fn(...)
    end
end

-- ---- yes/no, open to every resource ----

exports("isBanned", function(userId) return answer(access.isBanned(userId)) end)
exports("isWhitelisted", function(userId) return answer(access.isAllowed(userId)) end)
exports("whitelistEnabled", function()
    local state, reason = access.status()
    if type(state) ~= "table" then return nil, reason end
    return state.whitelistEnabled == true
end)
-- enabled, message
exports("maintenance", function() return Preflight.maintenance() end)
exports("hasAcceptedRules", function(userId) return PreflightStore.accepted(userId) end)

-- ---- bans ----

-- ban(userId, reason?, seconds?, actor?) -> true | nil, reason. seconds nil or 0: permanent.
-- The player is disconnected if in game, and refused on the launcher's screen at once.
exports("ban", guarded(function(userId, reason, seconds, actor)
    local name = nil
    for _, playerId in ipairs(Open77.players.all() or {}) do
        local identity = Open77.players.identity(playerId)
        if type(identity) == "table" and tostring(identity.userId):lower() == tostring(userId):lower() then name = identity.name end
    end
    seconds = tonumber(seconds)
    return answer(access.ban(userId, reason, seconds and seconds > 0 and math.floor(seconds) or nil, name, behalf(actor)))
end))
-- unban(userId, actor?) -> true when a ban was lifted, false when there was none.
exports("unban", guarded(function(userId, actor) return answer(access.unban(userId, behalf(actor))) end))
-- getBan(userId) -> { userId, name, reason, bannedBy, bannedAt, bannedAtUnix, expiresAt, expiresAtUnix, permanent } | nil
exports("getBan", guarded(function(userId) return answer(access.getBan(userId)) end))
-- bans() -> array of the same records
exports("bans", guarded(function()
    local state, reason = access.status()
    if type(state) ~= "table" then return nil, reason end
    return state.bans
end))

-- ---- whitelist ----

exports("whitelistAdd", guarded(function(userId, label, actor) return answer(access.allow(userId, label, behalf(actor))) end))
exports("whitelistRemove", guarded(function(userId, actor) return answer(access.disallow(userId, behalf(actor))) end))
exports("setWhitelist", guarded(function(enabled, actor) return answer(access.setWhitelist(enabled == true, behalf(actor))) end))
-- whitelist() -> array of { userId, label, addedAt, addedBy }
exports("whitelist", guarded(function()
    local state, reason = access.status()
    if type(state) ~= "table" then return nil, reason end
    return state.whitelist
end))

-- ---- whitelist requests (the application form of the launcher's server check) ----

-- requests("pending"?) -> array of { userId, name, message, status, requestedAt, requestedAtUnix, note, decidedBy }
exports("requests", guarded(function(filter) return answer(access.requests(filter)) end))
exports("getRequest", guarded(function(userId) return answer(access.getRequest(userId)) end))
-- approve(userId, label?, actor?): whitelists the player; one who is waiting on the launcher's screen goes on at once.
exports("approve", guarded(function(userId, label, actor) return answer(access.approve(userId, label, behalf(actor))) end))
-- deny(userId, note?, actor?): the note is shown to the player.
exports("deny", guarded(function(userId, note, actor) return answer(access.deny(userId, note, behalf(actor))) end))

-- ---- kick, refusals, sessions, maintenance ----

-- kick(target, message?) -> userId | nil, reason. target: a player id (number) or an account
-- id (string). Removes the player from the game and from the launcher's server check, and
-- shows them `message` if they try to join again within config kickSeconds.
exports("kick", guarded(function(target, message) return Preflight.kick(target, message) end))
-- refusals() -> the server's recent refused connections, newest first: { userId, name, code, message, at, atUnix }
exports("refusals", guarded(function() return answer(access.refusals()) end))
-- sessions() -> who is on the launcher's server check now: { id, userId, name, phase, discord }
exports("sessions", guarded(function()
    local list = {}
    local sessions = Open77.preflight.sessions()
    if type(sessions) ~= "table" then return list end
    for _, session in ipairs(sessions) do
        list[#list + 1] = {
            id = session.id, userId = session.player.userId, name = session.player.name, phase = session.phase,
            discord = session.player.discord, door = session.door and session.door.code or nil,
        }
    end
    return list
end))
-- setMaintenance(true | false | "default", message?) -> enabled, message
exports("setMaintenance", guarded(function(mode, message)
    if mode ~= "default" then mode = mode == true end
    return Preflight.setMaintenance(mode, message)
end))
-- resetRules(userId?) -> how many acceptances were forgotten (everybody's when userId is nil)
exports("resetRules", guarded(function(userId) return PreflightStore.reset(userId) end))
