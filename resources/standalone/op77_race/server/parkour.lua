-- What the parkour race lends: double jump and dash, for the race only. Every other race
-- never reaches this file (RaceEngine calls it for an instance with `abilities` only).
--
-- The platform (guides "dash" and "cyberware"):
--   Dash         a session capability of this resource: Open77.dash.grant / revoke. Revoke
--                removes this resource's grant only; another resource's grant (Light RP's
--                Neofiber) and every implant stay. `grant_owned`: the player already has one.
--   Double jump  the `legs` slot, lent with Open77.cyberware.lease: `current` keeps the paid
--                record, `effective` shows the lease. Death, a bucket change, expiry (5 min at
--                most), a disconnect and this resource stopping all end a lease; restoration
--                is the backend's job, even after we stopped.
--
-- The rules here:
--   * Nothing owned is ever touched. The manifest has no players.cyberware.manage, so this
--     resource cannot install or remove an implant. A runner with their own legs gets no
--     lease and a runner with another resource's dash no grant: their implant does the
--     work and there is nothing of ours to take back afterwards.
--   * What a racer has follows their state, one function (P.sync): called on every change
--     of it by the engine and every syncMs for everyone concerned, so an exit nobody thought
--     of still ends here. The legs come once the runner stands on the line, in the race's
--     bucket (entering it would end the lease). The dash comes at GO, never during the hold:
--     a freeze is only documented against locomotion input, and a dash off the line before GO
--     would be a false start the engine reads as "not on the grid". Both go at the finish,
--     on a DNF, and first thing in any release.
--   * A take-back is only over when the platform says so (no grant, no lease): a refused
--     revoke or release is asked again every syncMs. A release that never gets through
--     ends with the lease itself.
--   * What the platform ended while the race still wants it (death, expiry, a bucket
--     change) is lent again, once the body is alive.
local Config = RaceConfig
local Settings = Config.parkour
local E = RaceEngine

RaceParkour = {}
local P = RaceParkour

-- playerId -> { dash = true (our grant is out), lease = id (ours, until the platform has
-- none), ownDash, ownLegs, said = { reason = true }, since, checked, told }
local held = {}
P.held = held

local defined = { dash = false, legs = false }
local nextDefineAt = 0
local nextSyncAt = 0

local function log(text) print("[race:parkour] " .. tostring(text)) end

local function call(fn, ...)
    if type(fn) ~= "function" then return nil, "unavailable" end
    local ok, result, why = pcall(fn, ...)
    if not ok then return nil, tostring(result) end
    return result, why
end

local function dashApi() return type(Open77.dash) == "table" and Open77.dash or {} end
local function cyberApi() return type(Open77.cyberware) == "table" and Open77.cyberware or {} end

-- One line per player and reason: a refusal repeats every syncMs.
local function note(playerId, h, what, why)
    local key = what .. ":" .. tostring(why)
    if h.said[key] then return end
    h.said[key] = true
    log(("%s of player %d: %s"):format(what, playerId, tostring(why)))
end

local function alive(playerId)
    local life = Open77.players.getLifeState(playerId)
    return life ~= nil and life.phase == "alive"
end

local function projection(state)
    return type(state) == "table" and type(state.projection) == "table" and state.projection.status or nil
end

-- ---------------------------------------------------------------- definitions --

function P.define()
    if not defined.dash then
        local result, why = call(dashApi().define, Settings.dash)
        defined.dash = result ~= nil and result ~= false
        if defined.dash then log("dash defined") else log("dash unavailable: " .. tostring(why)) end
    end
    if not defined.legs then
        local result, why = call(cyberApi().define, Settings.legs)
        defined.legs = result ~= nil and result ~= false
        if defined.legs then log("double jump defined") else log("double jump unavailable: " .. tostring(why)) end
    end
end

-- Without both the race is not what it says: no join (RaceLobby.join, the status).
function P.available() return defined.dash and defined.legs end

-- ---------------------------------------------------------------- dash --

local function giveDash(playerId, h)
    if not defined.dash then return end
    local state = call(dashApi().current, playerId)
    if state ~= nil and state.ownedByCaller == false then
        h.ownDash = true
        return
    end
    h.ownDash = nil
    if state ~= nil and projection(state) ~= "removed" then
        h.dash = true
        return
    end
    local result, why = call(dashApi().grant, playerId, Settings.dash.id)
    if result then
        h.dash = true
    elseif why == "grant_owned" then
        h.ownDash = true
    else
        h.dash = nil
        if why == "definition_unavailable" then defined.dash = false end
        note(playerId, h, "dash", why)
    end
end

-- Only ever our own grant (revoke cannot reach another resource's); a player whose implant
-- lost its grant to ours gets it back from Light RP's own check.
local function takeDash(playerId, h)
    h.ownDash = nil
    if not h.dash then return end
    call(dashApi().revoke, playerId)
    local state = call(dashApi().current, playerId)
    if state == nil or state.ownedByCaller == false or projection(state) == "removed" then
        h.dash = nil
    else
        note(playerId, h, "dash take-back", "still held, asked again")
    end
end

-- ---------------------------------------------------------------- legs --

local function giveLegs(playerId, h)
    if not defined.legs then return end
    local state, why = call(cyberApi().leaseState, playerId)
    if state == nil and why ~= nil then return note(playerId, h, "double jump", why) end
    -- ours ended (death, expiry, a body or bucket change): lent again below
    local failed = state ~= nil and state.phase == "failed"
    if h.lease and (state == nil or failed or state.id ~= h.lease) then h.lease = nil end
    -- ours is in place or still being restored, or another lease runs: the platform allows
    -- one, and asks for no lease and a ready record before the next. A failed one holds
    -- nothing: the ask below is the retry, and the platform answers it.
    if state ~= nil and not failed then return end
    local record, reason = call(cyberApi().current, playerId)
    if record == nil then
        if reason ~= nil then note(playerId, h, "double jump", reason) end
        return
    end
    if record.legs ~= nil then
        h.ownLegs = true
        return
    end
    h.ownLegs = nil
    local result, refused = call(cyberApi().lease, playerId, Settings.legs.id, Settings.grade, { durationMs = Settings.leaseMs })
    if result and result.lease then
        h.lease = result.lease
    else
        if refused == "invalid_definition" then defined.legs = false end
        note(playerId, h, "double jump", refused)
    end
end

local function takeLegs(playerId, h)
    h.ownLegs = nil
    if h.lease == nil then return end
    local state, why = call(cyberApi().leaseState, playerId)
    if (state == nil and why == nil) or (state ~= nil and state.id ~= h.lease) then
        h.lease = nil
        return
    end
    if state ~= nil and state.phase == "failed" then
        h.lease = nil -- nothing to release: releaseLease works on pending and active only
        return
    end
    if state ~= nil and state.phase == "restoring" then return end
    local result, refused = call(cyberApi().releaseLease, playerId, h.lease)
    if not result then note(playerId, h, "double jump take-back", refused) end
end

-- ---------------------------------------------------------------- state --

-- What the race says this player should have now: legs (on the line of a running race),
-- dash (from GO). A finisher, a DNF, a racer on the way out have neither.
local function wanted(playerId)
    local racer = E.racers[playerId]
    local inst = racer and E.instances[racer.instanceId]
    if inst == nil or not inst.abilities or racer.releasing or not racer.placed then return false, false end
    local state = racer.state
    if state == "racing" then return true, true end
    return state == "loading" or state == "countdown", false
end

local function connected(playerId) return Open77.players.name(playerId) ~= nil end

function P.sync(playerId)
    local legs, dash = wanted(playerId)
    local h = held[playerId]
    if h == nil then
        if not legs then return end
        h = { said = {} }
        held[playerId] = h
    end
    if not connected(playerId) then
        held[playerId] = nil
        return
    end
    local body = alive(playerId)
    if not dash then takeDash(playerId, h) elseif body then giveDash(playerId, h) end
    if not legs then takeLegs(playerId, h) elseif body then giveLegs(playerId, h) end
    if dash and not h.told then
        h.told, h.since = true, E.nowMs()
        E.hooks.notice(playerId, "info", "Parkour Race",
            ("Double jump and dash for this race. Dash: %s, in the air too."):format(Settings.dashKeyLabel))
    end
    if not legs and not h.dash and h.lease == nil then held[playerId] = nil end
end

-- Dash in place: the projection answered, or the player's own. Legs: the lease is active
-- (the native body has them), or the player's own.
local function hasDash(playerId, h)
    if h.ownDash then return true end
    return h.dash == true and projection(call(dashApi().current, playerId)) == "ready"
end
local function hasLegs(playerId, h)
    if h.ownLegs then return true end
    local state = h.lease and call(cyberApi().leaseState, playerId) or nil
    return state ~= nil and state.id == h.lease and state.phase == "active"
end

-- The start waits for the slowest legs, readyWaitSeconds at most past the loading window.
function P.readyForCountdown(inst, now)
    if now >= inst.loadEndsAt + math.floor((tonumber(Settings.readyWaitSeconds) or 8) * 1000) then return true end
    if not defined.legs then return true end
    for _, playerId in ipairs(inst.members) do
        local racer = inst.racers[playerId]
        if E.racers[playerId] == racer and racer.state == "loading" then
            local h = held[playerId]
            if h == nil or not hasLegs(playerId, h) then return false end
        end
    end
    return true
end

-- A runner still short of an ability some time after GO is told, once: they race on.
local function check(playerId, h, now)
    if h.checked or h.since == nil or now - h.since < (Settings.checkAfterMs or 5000) or not alive(playerId) then return end
    h.checked = true
    if hasDash(playerId, h) and hasLegs(playerId, h) then return end
    log(("player %d is racing without its abilities (dash %s, legs %s)"):format(playerId,
        tostring(hasDash(playerId, h)), tostring(hasLegs(playerId, h))))
    E.hooks.notice(playerId, "warning", "Parkour Race", "Your double jump or dash did not come through. The race goes on.")
end

function P.tick(now)
    now = now or E.nowMs()
    if not P.available() and now >= nextDefineAt then
        nextDefineAt = now + (Settings.defineRetryMs or 10000)
        P.define()
    end
    if now < nextSyncAt then return end
    nextSyncAt = now + (Settings.syncMs or 1000)
    local seen = {}
    for playerId, racer in pairs(E.racers) do
        local inst = E.instances[racer.instanceId]
        if inst and inst.abilities then
            seen[playerId] = true
            P.sync(playerId)
        end
    end
    -- the exits the engine did not call us for, and the take-backs still open
    for playerId, h in pairs(held) do
        if not seen[playerId] then P.sync(playerId) end
        if held[playerId] == h then check(playerId, h, now) end
    end
end

-- Gone: the platform ended the grant and the lease with the session.
function P.forget(playerId) held[playerId] = nil end

-- Our resource stops: no thread survives, nothing can be retried. Asked once, then it is
-- the platform's (stopping a resource removes its grants and ends its leases).
function P.shutdown()
    for playerId, h in pairs(held) do
        if h.dash then call(dashApi().revoke, playerId) end
        if h.lease then call(cyberApi().releaseLease, playerId, h.lease) end
        held[playerId] = nil
    end
end
