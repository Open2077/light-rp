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

-- Players of one crew (entries sharing `squad`, the Light RP squad id) are a unit:
-- never split, always placed whole. A solo player is a unit of one.
local function unitsOf(list)
    local out, byKey = {}, {}
    for _, e in ipairs(list) do
        local key = e.squad ~= nil and ("squad:" .. tostring(e.squad)) or ("solo:" .. tostring(e.id))
        local u = byKey[key]
        if u == nil then
            u = { key = key, members = {} }
            byKey[key] = u
            out[#out + 1] = u
        end
        u.members[#u.members + 1] = e
    end
    return out
end

-- Forms the two sides of a war from the queue.
--   entries: { { id, gang = key|nil, at, squad = id|nil }, ... }
--   opts:    { maxPlayers, maxImbalance, allowTurncoats }
-- Gang 1's members take side 1, gang 2's side 2; everyone else (other gangs, no gang)
-- signs on as a MERCENARY with whichever side is smaller. Sides never differ by more
-- than maxImbalance; a gang's surplus is benched (stays queued) unless turncoats are
-- allowed. A crew (same `squad`) is never split: it goes whole to the side of the gang
-- most of it belongs to (its other members as mercenaries), and may overshoot the
-- balance by its own size. Returns { gangs = { g1, g2 }, sides = { {ids}, {ids} },
-- merc = { [id] = true }, bench = { ids } }.
function R.formSides(entries, opts)
    opts = opts or {}
    local max = opts.maxPlayers or 24
    local imbalance = math.max(0, opts.maxImbalance or 1)
    local list = {}
    for _, e in ipairs(entries) do list[#list + 1] = e end
    table.sort(list, byQueue)
    local g1, g2 = R.topGangs(list)
    local gangs = { g1, g2 }
    local core, others = { {}, {} }, {}
    for _, u in ipairs(unitsOf(list)) do
        local a, b = 0, 0
        for _, e in ipairs(u.members) do
            if g1 ~= nil and e.gang == g1 then a = a + 1 elseif g2 ~= nil and e.gang == g2 then b = b + 1 end
        end
        if a > 0 or b > 0 then
            local s = a >= b and 1 or 2
            core[s][#core[s] + 1] = u
        else
            others[#others + 1] = u
        end
    end
    local sides, merc, used = { {}, {} }, {}, {}
    local function place(side, u)
        u.used = true
        for _, e in ipairs(u.members) do
            sides[side][#sides[side] + 1] = e.id
            used[e.id] = true
            if not (gangs[side] ~= nil and e.gang == gangs[side]) then merc[e.id] = true end
        end
    end
    -- The first unit of a pool (queue order) that fits the room left (and `fits`).
    local function first(pool, room, fits)
        for _, u in ipairs(pool) do
            if not u.used and #u.members <= room and (fits == nil or fits(u)) then return u end
        end
        return nil
    end
    while true do
        local a, b = #sides[1], #sides[2]
        local room = max - a - b
        if room <= 0 then break end
        -- The smaller side first; level: the side that still has its own people.
        local s
        if a < b then s = 1 elseif b < a then s = 2
        elseif first(core[1], room) or not first(core[2], room) then s = 1 else s = 2 end
        local o = s == 1 and 2 or 1
        local u = first(core[s], room) or first(others, room)
        if u then
            place(s, u)
        else
            u = first(core[o], room, function(x) return #sides[o] + #x.members - #sides[s] <= imbalance end)
            if u then
                place(o, u)
            elseif opts.allowTurncoats then
                u = first(core[o], room)
                if not u then break end
                place(s, u)
            else
                break
            end
        end
    end
    local bench = {}
    for _, e in ipairs(list) do if not used[e.id] then bench[#bench + 1] = e.id end end
    return { gangs = gangs, sides = sides, merc = merc, bench = bench }
end

-- Where a late joiner goes during a running war, or nil (benched for now).
--   counts = { n1, n2 } fighters per side, gangs = { g1, g2 }, total cap = opts.maxPlayers.
--   opts.crewSide: the side his crew already fights on (never split: that side, as long
--   as the war has room, whatever the balance).
-- Returns side, isMercenary.
function R.placeLate(counts, gangs, gang, opts)
    opts = opts or {}
    local max = opts.maxPlayers or 24
    local imbalance = math.max(0, opts.maxImbalance or 1)
    if counts[1] + counts[2] >= max then return nil end
    if opts.crewSide == 1 or opts.crewSide == 2 then
        local s = opts.crewSide
        return s, not (gang ~= nil and gangs[s] == gang)
    end
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

-- ---------------------------------------------------------------- bots

-- Bots per side of a war with bots (staff bot mode): each side is filled up to
-- max(perSide, the larger side's humans). A side without humans is always filled; a
-- side with humans gets bot teammates only when `allies` is on. Capped per side and in
-- total (teammates are trimmed before the enemy).
--   humans = { n1, n2 }; opts = { perSide, allies, maxPerSide, maxBots }. Returns { b1, b2 }.
function R.botFill(humans, opts)
    opts = opts or {}
    local target = math.max(opts.perSide or 3, humans[1] or 0, humans[2] or 0)
    local out = { 0, 0 }
    for s = 1, 2 do
        local n = humans[s] or 0
        if n == 0 or opts.allies then out[s] = math.max(0, target - n) end
        if opts.maxPerSide then out[s] = math.min(out[s], opts.maxPerSide) end
    end
    local cap = opts.maxBots
    while cap and out[1] + out[2] > cap do
        local s
        if (humans[1] or 0) > 0 and out[1] > 0 then s = 1
        elseif (humans[2] or 0) > 0 and out[2] > 0 then s = 2
        else s = out[1] >= out[2] and 1 or 2 end
        out[s] = out[s] - 1
    end
    return out
end

-- The NPC gang of a Gang Sweep: base + perHuman for each human past the first, capped.
function R.pveBots(humans, pve)
    local n = (pve.baseBots or 3) + (pve.botsPerHuman or 2) * math.max(0, (humans or 1) - 1)
    return math.max(0, math.min(pve.maxBots or n, n))
end

-- ---------------------------------------------------------------- lobby options (v2)

local function count(v, max)
    v = tonumber(v)
    if v == nil or v ~= v or v <= 0 then return 0 end
    return math.min(max or 64, math.floor(v))
end
R.count = count

local function clampNum(v, lo, hi, default)
    v = tonumber(v)
    if v == nil or v ~= v then return default end
    return math.max(lo, math.min(hi, v))
end

-- A PvE difficulty from Light RP (options.difficulty + options.scaling), normalised:
-- { id, enemies, health, damage, ai = "standard"|"veteran" }. Missing or junk values
-- read as standard (x1); multipliers are clamped to sane bounds.
function R.difficulty(id, scaling)
    local s = type(scaling) == "table" and scaling or {}
    local ai = s.ai == "veteran" and "veteran" or "standard"
    return { id = type(id) == "string" and #id <= 24 and id or "standard",
        enemies = clampNum(s.enemies, 0.5, 3, 1), health = clampNum(s.health, 0.25, 4, 1),
        damage = clampNum(s.damage, 0.25, 3, 1), ai = ai }
end

-- The NPC gang of a Gang Sweep at a difficulty: the standard size (R.pveBots, uncapped)
-- x enemies, rounded, at least 1, never above pve.maxBots (the gang's NPC budget).
function R.sweepGang(humans, pve, diff)
    local raw = (pve.baseBots or 3) + (pve.botsPerHuman or 2) * math.max(0, (humans or 1) - 1)
    local n = math.floor(raw * ((diff and diff.enemies) or 1) + 0.5)
    return math.max(1, math.min(pve.maxBots or n, n))
end

-- Allied bots of a sweep (options.fill.allies): the largest asked, capped to the free
-- seats (activity.maxPlayers - humans) and to what the body budget leaves after the gang.
function R.sweepAllies(asked, humans, gang, pve)
    local seats = (pve.activity and pve.activity.maxPlayers or 8) - (humans or 0)
    local budget = (pve.maxBodies or 14) - (gang or 0)
    return math.max(0, math.min(count(asked), seats, budget))
end

-- Bots of a core match per side, capped per side and in total (bots on a side with
-- humans are trimmed first, as in staff bot mode). humans = { n1, n2 }, want = { b1, b2 }.
function R.capBots(humans, want, maxPerSide, maxBots)
    local out = { count(want[1]), count(want[2]) }
    for s = 1, 2 do if maxPerSide then out[s] = math.min(out[s], maxPerSide) end end
    while maxBots and out[1] + out[2] > maxBots do
        local s
        if (humans[1] or 0) > 0 and out[1] > 0 then s = 1
        elseif (humans[2] or 0) > 0 and out[2] > 0 then s = 2
        else s = out[1] >= out[2] and 1 or 2 end
        out[s] = out[s] - 1
    end
    return out
end

-- options.fill on a side-based war ({ allies, enemies }): a total, placed where the
-- sides need it (the smaller side first, side 2 when level). Returns { b1, b2 }.
function R.spreadFill(humans, total)
    local out = { 0, 0 }
    local n = { humans[1] or 0, humans[2] or 0 }
    for _ = 1, count(total) do
        local s = (n[1] + out[1] < n[2] + out[2]) and 1 or 2
        out[s] = out[s] + 1
    end
    return out
end

-- A rival gang for a side nobody of a gang holds: the first of `order` that is not `taken`.
function R.rivalGang(order, taken, gangs)
    for _, key in ipairs(order or {}) do
        if key ~= taken and (gangs == nil or gangs[key] ~= nil) then return key end
    end
    return nil
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
    -- (fifteen 1/15 steps sum to 0.9999...: a hair of slack keeps 15 s at 15 s)
    if zone.progress >= 1.0 - 1e-9 then
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
-- a 1 s cadence and a jittery one score the same. `war.zoneRate` (optional, per side)
-- scales a side's zone points (a Gang Sweep's holders). Returns the winner side or nil.
function R.stepScore(war, dt, scoring, target)
    for s = 1, 2 do
        local held = 0
        for _, zone in ipairs(war.zones) do if zone.owner == s then held = held + 1 end end
        war.carry = war.carry or { 0, 0 }
        local rate = (scoring.pointsPerZonePerSecond or 1) * (war.zoneRate and war.zoneRate[s] or 1)
        local gain = held * rate * dt + war.carry[s]
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

-- ---------------------------------------------------------------- zone layout

local function flat(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end
R.flatDistance = flat

-- The site's spacing floor: its own `zoneSpacing`, else the default (config zoneSpacing).
function R.spacingFloor(site, default)
    return tonumber(site.zoneSpacing) or tonumber(default) or 0
end

-- Is a site's zone layout sound: every two centres at least `floor` metres apart
-- (horizontal), every zone (centre + radius) inside the bounds? ok, problems (texts),
-- the closest pair { a, b, metres }.
function R.checkZones(site, floor)
    local problems, closest = {}, nil
    local zones = site.zones or {}
    for i = 1, #zones do
        for j = i + 1, #zones do
            local d = flat(zones[i], zones[j])
            if closest == nil or d < closest.metres then closest = { a = zones[i].id, b = zones[j].id, metres = d } end
            if d < floor then
                problems[#problems + 1] = ("zones %s and %s are %.1f m apart (under %.0f m)"):format(zones[i].id, zones[j].id, d, floor)
            end
        end
    end
    local b = site.bounds
    for _, z in ipairs(zones) do
        if b and flat(z, b.center) + (z.radius or 0) > b.radius then
            problems[#problems + 1] = ("zone %s is not inside the bounds (%.1f m from the centre, radius %.0f m)")
                :format(z.id, flat(z, b.center), b.radius)
        end
    end
    return #problems == 0, problems, closest
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

-- Did a Gang Sweep count (not void, long enough)? No accounts rule: the other side is NPCs.
function R.pveCounted(war, rewards)
    if war.void then return false end
    return (war.playedMs or 0) >= (rewards.minWarSeconds or 0) * 1000
end

-- A copy of `rewards` with the reputation amounts scaled (rounded), then `overrides`.
function R.scaledRewards(rewards, scale, overrides)
    local out = {}
    for k, v in pairs(rewards or {}) do out[k] = v end
    for _, k in ipairs({ "win", "draw", "loss", "perCapture", "perKill", "bonusCap" }) do
        if type(out[k]) == "number" then out[k] = math.floor(out[k] * (scale or 1) + 0.5) end
    end
    for k, v in pairs(overrides or {}) do out[k] = v end
    return out
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
    -- (Gang Sweep) nothing for a fighter who neither captured nor eliminated anyone.
    if rewards.needsAction and (m.captures or 0) + (m.kills or 0) == 0 then return 0 end
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
