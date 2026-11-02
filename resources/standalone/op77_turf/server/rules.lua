-- op77_turf rules: pure functions, no natives, no globals but TurfConfig (passed in
-- where it matters). Everything a war decides lives here and is unit-tested in
-- tests/rules_test.lua: gang keys, the two sides and the mercenaries, late joiners,
-- the capture step, the score step, respawn points, bounds, rewards, influence.
TurfRules = {}
local R = TurfRules

-- ---------------------------------------------------------------- gangs

local NO_GANG = { [""] = true, none = true, unaffiliated = true, ["-"] = true }

-- A gang key from whatever Light RP hands over: a string, or a gang view
-- ({ id = ... } from activityPlayer, { name = ... } from the `gang` state bag).
-- nil = unaffiliated.
function R.gangKey(value)
    if type(value) == "table" then value = value.id or value.name end
    if type(value) ~= "string" then return nil end
    value = value:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if NO_GANG[value] or #value > 32 or not value:match("^[%w_%-]+$") then return nil end
    return value
end

-- Label + colour of a gang key, from the view when it carries them, else the config.
function R.gangInfo(key, view, gangs)
    if key == nil then return nil end
    local known = gangs and gangs[key] or {}
    local label = type(view) == "table" and type(view.label) == "string" and view.label ~= "" and view.label or known.label
    local color = type(view) == "table" and type(view.color) == "string" and view.color:match("^#%x%x%x%x%x%x$") and view.color or known.color
    if not label then label = (key:gsub("_", " "):gsub("^%l", string.upper)) end
    return { key = key, label = label, color = color or "#C9CED6" }
end

-- ---------------------------------------------------------------- sides

local function byQueue(a, b)
    if a.at ~= b.at then return a.at < b.at end
    return a.id < b.id
end

-- The two gangs a war is fought between: the most represented in `entries`, ties
-- broken by who queued first, then by key. Returns g1, g2 (either may be nil).
function R.topGangs(entries)
    local count, first = {}, {}
    for _, e in ipairs(entries) do
        if e.gang then
            count[e.gang] = (count[e.gang] or 0) + 1
            if first[e.gang] == nil or e.at < first[e.gang] then first[e.gang] = e.at end
        end
    end
    local keys = {}
    for key in pairs(count) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        if count[a] ~= count[b] then return count[a] > count[b] end
        if first[a] ~= first[b] then return first[a] < first[b] end
        return a < b
    end)
    return keys[1], keys[2]
end

-- Forms the two sides of a war from the queue.
--   entries: { { id, gang = key|nil, at }, ... }
--   opts:    { maxPlayers, maxImbalance, allowTurncoats }
-- Gang 1's members take side 1, gang 2's side 2; everyone else (other gangs, no gang)
-- signs on as a MERCENARY with whichever side is smaller. Sides never differ by more
-- than maxImbalance; a gang's surplus is benched (stays queued) unless turncoats are
-- allowed. Returns { gangs = { g1, g2 }, sides = { {ids}, {ids} }, merc = { [id] = true }, bench = { ids } }.
function R.formSides(entries, opts)
    opts = opts or {}
    local max = opts.maxPlayers or 24
    local imbalance = math.max(0, opts.maxImbalance or 1)
    local list = {}
    for _, e in ipairs(entries) do list[#list + 1] = e end
    table.sort(list, byQueue)
    local g1, g2 = R.topGangs(list)
    local core, others = { {}, {} }, {}
    for _, e in ipairs(list) do
        if g1 ~= nil and e.gang == g1 then core[1][#core[1] + 1] = e
        elseif g2 ~= nil and e.gang == g2 then core[2][#core[2] + 1] = e
        else others[#others + 1] = e end
    end
    local sides, merc, used = { {}, {} }, {}, {}
    local nextCore, nextOther = { 1, 1 }, 1
    local function take(side, fromCore, asMerc)
        local e
        if fromCore then
            e = core[fromCore][nextCore[fromCore]]
            nextCore[fromCore] = nextCore[fromCore] + 1
        else
            e = others[nextOther]
            nextOther = nextOther + 1
        end
        sides[side][#sides[side] + 1] = e.id
        used[e.id] = true
        if asMerc then merc[e.id] = true end
    end
    local function hasCore(s) return core[s][nextCore[s]] ~= nil end
    local function hasOther() return others[nextOther] ~= nil end
    while #sides[1] + #sides[2] < max do
        local a, b = #sides[1], #sides[2]
        -- The smaller side first; level: the side that still has its own people.
        local s
        if a < b then s = 1 elseif b < a then s = 2
        elseif hasCore(1) or not hasCore(2) then s = 1 else s = 2 end
        local o = s == 1 and 2 or 1
        if hasCore(s) then take(s, s, false)
        elseif hasOther() then take(s, nil, true)
        elseif hasCore(o) and (#sides[o] + 1 - #sides[s]) <= imbalance then take(o, o, false)
        elseif hasCore(o) and opts.allowTurncoats then take(s, o, true)
        else break end
    end
    local bench = {}
    for _, e in ipairs(list) do if not used[e.id] then bench[#bench + 1] = e.id end end
    return { gangs = { g1, g2 }, sides = sides, merc = merc, bench = bench }
end

-- Where a late joiner goes during a running war, or nil (benched for now).
--   counts = { n1, n2 } fighters per side, gangs = { g1, g2 }, total cap = opts.maxPlayers.
-- Returns side, isMercenary.
function R.placeLate(counts, gangs, gang, opts)
    opts = opts or {}
    local max = opts.maxPlayers or 24
    local imbalance = math.max(0, opts.maxImbalance or 1)
    if counts[1] + counts[2] >= max then return nil end
    for s = 1, 2 do
        if gang ~= nil and gangs[s] == gang then
            local o = s == 1 and 2 or 1
            if counts[s] + 1 - counts[o] <= imbalance then return s, false end
            if opts.allowTurncoats then return o, true end
            return nil
        end
    end
    -- A mercenary: the smaller side, side 1 when level.
    if counts[2] < counts[1] then return 2, true end
    return 1, true
end

-- ---------------------------------------------------------------- zones

-- Fresh runtime state of a site's zones.
function R.newZones(site)
    local zones = {}
    for i, def in ipairs(site.zones) do
        zones[i] = { def = def, index = i, owner = nil, capturing = nil, progress = 0.0, contested = false,
            counts = { 0, 0 } }
    end
    return zones
end

-- Is a position inside a zone (horizontal radius, vertical band)?
function R.inZone(def, p, height)
    if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" then return false end
    local dx, dy = p.x - def.x, p.y - def.y
    if dx * dx + dy * dy > def.radius * def.radius then return false end
    if type(p.z) == "number" and type(def.z) == "number" and math.abs(p.z - def.z) > (height or 3.5) then return false end
    return true
end

-- Capture speed (progress per second) of n attackers.
function R.captureRate(n, cap)
    if n <= 0 then return 0 end
    local extra = math.min(n, cap.maxAttackers or 3) - 1
    return (1 + extra * (cap.perExtraAttacker or 0)) / math.max(0.1, cap.seconds or 15)
end

-- One step of one zone. counts = { side1, side2 } living fighters inside.
-- Rules: both sides inside = contested, frozen. One side inside: an enemy's partial
-- capture is wound back first, then its own capture grows; at 100% the zone flips to
-- it (owner changes directly, no neutral stop). Nobody inside: a partial capture fades.
-- Returns an event { kind = "captured", side, previous } or nil.
function R.stepZone(zone, counts, dt, cap)
    zone.counts = { counts[1] or 0, counts[2] or 0 }
    local a, b = zone.counts[1], zone.counts[2]
    zone.contested = a > 0 and b > 0
    if zone.contested then return nil end
    if a == 0 and b == 0 then
        if zone.progress > 0 then
            zone.progress = math.max(0, zone.progress - (cap.decayPerSecond or 0) * dt)
            if zone.progress == 0 then zone.capturing = nil end
        end
        return nil
    end
    local s = a > 0 and 1 or 2
    local rate = R.captureRate(s == 1 and a or b, cap) * dt
    if zone.owner == s then
        -- Holding it: an enemy's half-capture is cleared.
        if zone.progress > 0 then
            zone.progress = math.max(0, zone.progress - rate)
            if zone.progress == 0 then zone.capturing = nil end
        end
        return nil
    end
    if zone.capturing ~= nil and zone.capturing ~= s and zone.progress > 0 then
        zone.progress = zone.progress - rate
        if zone.progress > 0 then return nil end
        rate = -zone.progress
        zone.progress = 0
    end
    zone.capturing = s
    zone.progress = zone.progress + rate
    if zone.progress >= 1.0 then
        local previous = zone.owner
        zone.owner, zone.capturing, zone.progress = s, nil, 0.0
        return { kind = "captured", side = s, previous = previous, zone = zone.def.id }
    end
    return nil
end

-- Zones a side may respawn at: held, not contested, no enemy capture running.
function R.safeZone(zone, side)
    if zone.owner ~= side or zone.contested then return false end
    if zone.def.spawnable == false then return false end
    if zone.capturing ~= nil and zone.capturing ~= side and zone.progress > 0 then return false end
    return true
end

-- ---------------------------------------------------------------- score

-- Points of one step: held zones x rate x dt, accumulated with a fractional carry so
-- a 1 s cadence and a jittery one score the same. Returns the winner side or nil.
function R.stepScore(war, dt, scoring, target)
    for s = 1, 2 do
        local held = 0
        for _, zone in ipairs(war.zones) do if zone.owner == s then held = held + 1 end end
        war.carry = war.carry or { 0, 0 }
        local gain = held * (scoring.pointsPerZonePerSecond or 1) * dt + war.carry[s]
        local whole = math.floor(gain)
        war.carry[s] = gain - whole
        war.sides[s].score = war.sides[s].score + whole
    end
    return R.leader(war, target)
end

-- The side at or past the target (the higher one if both), else nil.
function R.leader(war, target)
    local a, b = war.sides[1].score, war.sides[2].score
    if a >= target or b >= target then
        if a > b then return 1 elseif b > a then return 2 end
        return 0 -- both at once, level: a draw
    end
    return nil
end

-- At the buzzer: the higher score; level = more zones held; still level = draw (0).
function R.timeWinner(war)
    local a, b = war.sides[1].score, war.sides[2].score
    if a ~= b then return a > b and 1 or 2 end
    local za, zb = 0, 0
    for _, zone in ipairs(war.zones) do
        if zone.owner == 1 then za = za + 1 elseif zone.owner == 2 then zb = zb + 1 end
    end
    if za ~= zb then return za > zb and 1 or 2 end
    return 0
end

-- ---------------------------------------------------------------- places

-- Heading from a point towards another (engine yaw: 0 faces +Y).
function R.headingTo(from, to)
    return math.deg(math.atan(-(to.x - from.x), to.y - from.y)) % 360
end

-- The side's spawn point for a slot (round robin over the configured points).
function R.sideSpawn(site, side, slot)
    local points = site.spawns[side].points
    local p = points[((slot or 1) - 1) % #points + 1]
    return { x = p.x, y = p.y, z = p.z, heading = p.heading or 0 }
end

-- Where a fallen fighter comes back: the safe held zone nearest to where he fell
-- (offset on a small ring so bodies do not stack), else his side's spawn.
function R.respawnPoint(war, site, side, slot, deathPos, life)
    if life and life.respawnAtZones and type(deathPos) == "table" then
        local best, bestD
        for _, zone in ipairs(war.zones) do
            if R.safeZone(zone, side) then
                local dx, dy = zone.def.x - deathPos.x, zone.def.y - deathPos.y
                local d = dx * dx + dy * dy
                if bestD == nil or d < bestD then best, bestD = zone, d end
            end
        end
        if best then
            local r = life.zoneSpawnOffset or 1.5
            local angle = ((slot or 1) * 137.5) % 360
            local rad = math.rad(angle)
            local base = R.sideSpawn(site, side == 1 and 2 or 1, 1)
            local p = { x = best.def.x + math.cos(rad) * r, y = best.def.y + math.sin(rad) * r, z = best.def.z }
            p.heading = R.headingTo(p, base)
            return p, best.def.id
        end
    end
    return R.sideSpawn(site, side, slot), nil
end

function R.inBounds(bounds, p)
    if type(p) ~= "table" or type(p.x) ~= "number" then return true end -- unknown: never punish
    local dx, dy = p.x - bounds.center.x, p.y - bounds.center.y
    return dx * dx + dy * dy <= bounds.radius * bounds.radius
end

-- ---------------------------------------------------------------- rewards

-- Did the war count (long enough, enough distinct accounts on both sides)?
function R.counted(war, rewards, minAccounts)
    if war.void then return false end
    if (war.playedMs or 0) < (rewards.minWarSeconds or 0) * 1000 then return false end
    local accounts, perSide = {}, { {}, {} }
    for _, m in pairs(war.members) do
        if m.identifier and m.side then
            accounts[m.identifier] = true
            perSide[m.side][m.identifier] = true
        end
    end
    local n = 0
    for _ in pairs(accounts) do n = n + 1 end
    if n < (minAccounts or rewards.minAccounts or 0) then return false end
    for s = 1, 2 do if next(perSide[s]) == nil then return false end end
    return true
end

-- Personal score shown on the board: captures, kills and time on the zones.
function R.personalScore(m, scoring)
    return (m.captures or 0) * (scoring.captureBonus or 0) + (m.kills or 0) * (scoring.killPoints or 0)
        + math.floor((m.holdSeconds or 0) / 5)
end

-- Proposed reputation for one fighter at the end (0 for leavers, late joiners who
-- barely played, and wars that did not count).
function R.reputation(m, war, winner, rewards, counted)
    if not counted or m.left then return rewards.leaver or 0 end
    if (m.playedMs or 0) < (rewards.minPlaySeconds or 0) * 1000 then return 0 end
    local base
    if winner == 0 then base = rewards.draw elseif winner == m.side then base = rewards.win else base = rewards.loss end
    local bonus = (m.captures or 0) * (rewards.perCapture or 0) + (m.kills or 0) * (rewards.perKill or 0)
    return (base or 0) + math.min(bonus, rewards.bonusCap or bonus)
end

-- Influence earned by the two gangs of a counted war: { [gang] = { points, wars, wins, captures } }.
-- Captures count only for the gang's own members (never mercenaries).
function R.influence(war, winner, cfg)
    local out = {}
    for s = 1, 2 do
        local gang = war.sides[s].gang
        if gang then
            local captures = 0
            for _, m in pairs(war.members) do
                if m.side == s and not m.merc and m.gang == gang then captures = captures + (m.captures or 0) end
            end
            local base
            if winner == 0 then base = cfg.draw elseif winner == s then base = cfg.win else base = cfg.loss end
            local bonus = math.min(captures * (cfg.perCapture or 0), cfg.captureCap or captures)
            local row = out[gang] or { points = 0, wars = 0, wins = 0, captures = 0 }
            row.points = row.points + (base or 0) + bonus
            row.wars = row.wars + 1
            row.wins = row.wins + ((winner == s) and 1 or 0)
            row.captures = row.captures + captures
            out[gang] = row
        end
    end
    return out
end

-- Weeks start Monday 00:00 UTC (the epoch was a Thursday: Monday 1970-01-05 = 345600).
function R.weekIndex(unix)
    return math.floor(((tonumber(unix) or 0) - 345600) / 604800)
end

function R.weekStart(week)
    return week * 604800 + 345600
end

-- "m:ss"
function R.clock(ms)
    local s = math.max(0, math.floor((ms or 0) / 1000 + 0.5))
    return ("%d:%02d"):format(s // 60, s % 60)
end
