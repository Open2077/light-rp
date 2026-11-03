-- op77_chase police: the wanted levels NCPD Escape puts on its runners, and the promise
-- that every one of them comes back down.
--
-- Open77.players.setWanted / setMaxWanted are per player: the server pushes the value to
-- that player's own game (open77_prevention applies it), whose police are local to it.
-- The server keeps the value for as long as the player is connected, across bucket
-- changes. So a level this resource raised stays raised until this resource lowers it:
--
--   ChasePolice.raise(id, stars, ceiling, bucket, now)  ceiling first, then the level
--   ChasePolice.reassert(id, now)        the same level again every wanted.reassertSeconds
--                                        (the engine drops its heat when it loses him)
--   ChasePolice.clear(id, why)           level 0, ceiling 5, forgotten (always tries)
--   ChasePolice.clearAll(why)
--   ChasePolice.bucketChanged(id, bucket) out of the instance it was raised in = clear
--   ChasePolice.sweep()                  at start: clears what a previous run left raised
--   ChasePolice.report(id, report, now)  what the client's game did with it
--   ChasePolice.blocked(id, now)         that game keeps refusing the raise
--
-- A ledger in this resource's KVP (escape.wanted.<playerId> = his identifier) survives a
-- restart or reload of the resource, so the next start clears a level the previous run
-- could not. A plain stop cannot: while a resource stops, the runtime refuses every
-- prevention call (resource_stopping), and Light RP takes the players home with their
-- stars. That is a platform gap (README "NCPD Escape and the wanted level").
ChasePolice = { raised = {}, reports = {}, warned = {} }
local Pol = ChasePolice

local PREFIX = "escape.wanted."
local DEFAULT_CEILING = 5
-- Refusals that mean "this player is not there any more".
local GONE = { player_unavailable = true, invalid_player = true, not_a_player = true }

local function W() return ChaseWorld end
local function cfg() return ChaseConfig.pve end
local function log(fmt, ...) print(("[op77_chase] escape police " .. fmt):format(...)) end

local function valid(id) return type(id) == "number" and id > 0 and id % 1 == 0 end

-- Log a refusal once per player and reason (a refused call repeats every reassert).
local function refused(id, what, why)
    local key = ("%s|%s|%s"):format(tostring(id), what, tostring(why))
    if Pol.warned[key] then return end
    Pol.warned[key] = true
    log("%s for %d refused: %s", what, id, tostring(why))
end

local function remember(id)
    local who = W().identifier(id) or "?"
    local ok, why = W().kvpSet(PREFIX .. tostring(id), who)
    if not ok then refused(id, "ledger write", why) end
end

local function forget(id)
    W().kvpDelete(PREFIX .. tostring(id))
end

function Pol.raise(id, stars, ceiling, bucket, now)
    if not valid(id) then return false, "not_a_player" end
    stars = math.max(0, math.min(5, math.floor(stars or 0)))
    ceiling = math.max(stars, math.min(5, math.floor(ceiling or stars)))
    local r = Pol.raised[id]
    if r == nil then
        r = { stars = -1, ceiling = -1, bucket = bucket, sinceMs = now }
        Pol.raised[id] = r
        remember(id)
    end
    r.bucket = bucket or r.bucket
    if r.ceiling ~= ceiling then
        local ok, why = W().setMaxWanted(id, ceiling)
        if ok then r.ceiling = ceiling else refused(id, ("setMaxWanted(%d)"):format(ceiling), why) end
    end
    local ok, why = W().setWanted(id, stars)
    r.sentAtMs = now
    if not ok then
        refused(id, ("setWanted(%d)"):format(stars), why)
        return false, why
    end
    if r.stars ~= stars then
        if stars > (r.stars or 0) then r.raisedAtMs = now end
        r.stars = stars
    end
    return true
end

function Pol.reassert(id, now)
    local r = Pol.raised[id]
    if r == nil or (r.stars or 0) <= 0 then return false end
    if now - (r.sentAtMs or 0) < math.floor(((cfg().wanted or {}).reassertSeconds or 15) * 1000) then return false end
    local ok, why = W().setWanted(id, r.stars)
    r.sentAtMs = now
    if not ok then refused(id, ("setWanted(%d) again"):format(r.stars), why) end
    return ok == true
end

function Pol.stars(id)
    local r = Pol.raised[id]
    return r and math.max(0, r.stars or 0) or 0
end

function Pol.isRaised(id) return Pol.raised[id] ~= nil end

-- Level 0, ceiling 5, out of the ledger. Tried even when this run never raised him (the
-- ledger of a previous run): clearing a level nobody set changes nothing.
function Pol.clear(id, why)
    if not valid(id) then return false end
    local had = Pol.raised[id] ~= nil
    Pol.raised[id], Pol.reports[id] = nil, nil
    local ok1, why1 = W().setWanted(id, 0)
    local ok2, why2 = W().setMaxWanted(id, DEFAULT_CEILING)
    -- Out of the ledger only once it is really down, or he is gone (the server forgot his
    -- level with him). A refusal (resource_stopping) keeps the entry for the next start.
    if (ok1 or GONE[tostring(why1)]) and (ok2 or GONE[tostring(why2)]) then forget(id) end
    for key in pairs(Pol.warned) do
        if key:sub(1, #tostring(id) + 1) == tostring(id) .. "|" then Pol.warned[key] = nil end
    end
    if not ok1 or not ok2 then
        -- player_unavailable / invalid_player: he is gone, and the server forgot him with him.
        log("clear for %d (%s): setWanted %s, setMaxWanted %s", id, tostring(why), ok1 and "ok" or tostring(why1),
            ok2 and "ok" or tostring(why2))
    elseif had then
        log("cleared %d (%s)", id, tostring(why))
    end
    return ok1 == true and ok2 == true
end

function Pol.clearAll(why)
    local ids = {}
    for id in pairs(Pol.raised) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do Pol.clear(id, why) end
    return #ids
end

-- A raised player who changed bucket away from the instance he was raised in (home,
-- a staff teleport...): his level comes down now. Bucket 0's dispatch is never touched.
function Pol.bucketChanged(id, bucket)
    local r = Pol.raised[id]
    if r == nil then return false end
    if r.bucket ~= nil and bucket == r.bucket then return false end
    Pol.clear(id, ("bucket %s"):format(tostring(bucket)))
    return true
end

-- At start: the levels a previous run of this resource left raised (a restart or a reload
-- while an escape was on). Only for the same player (same identifier) still connected; the
-- entry goes either way (a gone player took his level with him).
function Pol.sweep()
    local rows = W().kvpFind(PREFIX, 256)
    local cleared = 0
    for _, row in ipairs(type(rows) == "table" and rows or {}) do
        local key = type(row) == "table" and row.key or row
        local id = tonumber(tostring(key):sub(#PREFIX + 1))
        if id and valid(id) and not Pol.raised[id] then
            local stored = type(row) == "table" and row.value or nil
            local current = W().connected(id) and W().identifier(id) or nil
            if W().connected(id) and (stored == nil or stored == "?" or current == nil or tostring(stored) == tostring(current)) then
                Pol.clear(id, "left raised by a previous run")
                cleared = cleared + 1
            else
                W().kvpDelete(tostring(key))
            end
        elseif not id then
            W().kvpDelete(tostring(key))
        end
    end
    if cleared > 0 then log("cleared %d wanted level(s) left by a previous run", cleared) end
    return cleared
end

-- What the client's game did with the level (op77_chase:police): { expected, requested,
-- suppressed, acknowledged, attached }. "Refused" = the server raised him, his client
-- knows it (expected > 0), and the game holds less (population suppression, a refused
-- raise). Refused continuously for wanted.blockedAfterSeconds = blocked.
function Pol.report(id, report, now)
    local r = Pol.raised[id]
    if r == nil or type(report) ~= "table" then return false end
    local expected = tonumber(report.expected) or 0
    local requested = tonumber(report.requested) or 0
    local bad = expected > 0 and (report.suppressed == true or requested < expected)
    local rec = Pol.reports[id] or {}
    Pol.reports[id] = rec
    rec.atMs, rec.suppressed, rec.requested, rec.expected = now, report.suppressed == true, requested, expected
    rec.acknowledged, rec.attached = report.acknowledged == true, report.attached ~= false
    if bad then rec.badSinceMs = rec.badSinceMs or now else rec.badSinceMs = nil end
    return true
end

function Pol.blocked(id, now)
    local rec = Pol.reports[id]
    if rec == nil or rec.badSinceMs == nil then return false end
    return now - rec.badSinceMs >= math.floor(((cfg().wanted or {}).blockedAfterSeconds or 6) * 1000), rec
end
