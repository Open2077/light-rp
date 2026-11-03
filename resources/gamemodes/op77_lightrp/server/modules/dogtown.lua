-- Dogtown: the open PvP zone of Light RP (server/config/dogtown.lua; the owner's
-- rules of 2026-11-03).
--
-- Global friendly fire stays off (the platform default: player damage between two
-- players is refused before any Lua arbiter runs). Every sweep, the players who
-- qualify get a combat scope (Open77.combat.createScope) in the city bucket:
--
--   qualifies = character active, in the city bucket, not owned by an activity or a
--               mission, alive or recovering, zone switched on, carrying the stake
--               (stake.minCash in pocket cash), AND (inside the polygon OR tagged)
--
-- Crewmates share a combat team (Open77.combat.setTeam): they never hurt each other.
-- A hit between two scoped players tags both for `combatTagMs`; a tagged player who
-- steps out keeps the scope until the tag runs out. The damage arbiter below refuses
-- a hit between two scoped players when one no longer qualifies, or between
-- crewmates (the next sweep would fix it; the arbiter closes the gap). It never
-- allows anything: safe zones, downed attackers, activities keep refusing as before.
--
-- Entering (or connecting inside) starts `entryProtection.ms` of safety: the player is
-- left out of the grant until it runs out (nobody camps the gates). It re-arms after
-- `entryProtection.rearmMs` out of the zone or a death, never while tagged.
--
-- The doors of `openDoors` (areas and ids) are claimed through open77_doors and held
-- open, unlocked and unsealed in the city bucket.
--
-- A player inside without the stake is warned (amount missing), and after
-- `stake.graceMs` still inside and short, sent to the nearest exit outside.
--
-- A credited kill (not the same account, not crewmates, not the same pair within
-- `pairCooldownMs`) drops the victim's loss (share, min, max of their pocket cash,
-- halved under anti-gank) plus a server bonus (minted, capped per killer account
-- and UTC day) as a sealed bag reserved to the killer's crew (inventory.lua,
-- Inv.dropCash), through the money ledger. Five credited kills without dying put a
-- bounty on the killer: a pin following them on everyone's 3D map (op77_map3d) and a
-- cash reward for whoever takes them down. A tagged player who disconnects drops the
-- bag of a death (no bonus). Stats: credited kills, deaths, best streak, eddies looted
-- per character, per week and in total; the Hall of Fame gets two boards. No reputation.
--
--   LightRP.dogtown.contains({ x, y })      the polygon test
--   LightRP.dogtown.qualifies(playerId)     the roster rule (above)
--   LightRP.dogtown.lossAmount(cash)        the share, minimum and cap
--   LightRP.dogtown.verdict(killer, victim) nil (credited) or a reason
--   LightRP.dogtown.waivesHospital(playerId) the hospital bill waiver (economy_sinks.lua)
local Config = LightRpDogtown
local Db = LightRP.db
local D = LightRP.module("dogtown", {})
local NET, REPORT = "op77_lightrp:dogtown", "op77_lightrp:dogtown:report"
local RESOURCE = type(GetCurrentResourceName) == "function" and GetCurrentResourceName() or "op77_lightrp"
local BOUNTY_PREFIX = "dogtown.bounty."

local enabled = Config.enabled ~= false
local polygon, bbox, polygonSource = nil, nil, "config"
local presence = {}   -- playerId -> true/false: inside the polygon (last fresh read)
local positions = {}  -- playerId -> last position read (sorting the roster, combat-log bags)
local tags = {}       -- playerId -> tag end (ms)
local hits = {}       -- victim -> { [attacker] = ms }
local roster = {}     -- playerId -> group index: PvP granted at the last sweep
local scopes = {}     -- scope ids this module holds
local teams = {}      -- playerId -> combat team this module set (0 = none)
local rosterKey, rebuildAt, dirty = "", 0, true
local held = {}       -- playerId -> ms: left out after a refused grant
local pushed = {}     -- playerId -> last presence key sent to the page
local tagPushedAt = {}
local entered = {}    -- playerId -> was inside (eligible) at the last sweep
local entryChatAt = {}
local short = {}      -- playerId -> { evictAt, evicting }: inside without the stake
local streaks = {}    -- playerId -> credited kills since the last death / leaving the zone
local bounties = {}   -- playerId -> { blip, streak, position }
local bags = {}       -- pile id -> pile (cleaned on stop)
local bonusDaily = {} -- identifier -> { day, minted, synced }: the killer's daily bonus
local deathMark = {}  -- playerId -> { at, clearAt }: died in a Dogtown fight (hospital waiver)
local lastDeathAt = {}
local cooldowns = {}  -- "killer>victim" character keys -> ms of the last credited kill
local stats = {}      -- playerId -> { key, name, week, weekStats, total }
local memory = {}     -- characterKey -> { identifier, characterKey, name, weeks = { [week] = stats }, total } (no database)
local board = { week = 0, rows = {}, at = -math.huge }
local probes, probeSeq = {}, 0
local surveys = {}    -- staff playerId -> { points = { { x, y, district } } }
local lastError, lastMismatch, lastTeamError = -math.huge, {}, -math.huge
local bountyRefreshAt = 0
local protectedUntil = {}  -- playerId -> ms: entry protection ends
local protectionSpent = {} -- playerId -> true: had one, re-arms after rearmMs out or a death
local outsideSince = {}    -- playerId -> ms: out of the zone (outside, untagged) since
local diedSince = {}       -- playerId -> true: died since the last protection

local function now() return LightRP.nowMs() end
local function pid(value) local n = tonumber(value); if n and n > 0 then return math.tointeger(n) or n end end
local function money(n) return LightRP.money and LightRP.money.format(n) or ("€$ " .. tostring(n)) end
local function name(player) return LightRP.characters.displayName(player) end
local function L() return Config.loot or {} end
local function S() return Config.stake or {} end
local function G() return Config.antiGank or {} end
local function B() return Config.bounty or {} end
local function P() return Config.entryProtection or {} end
local function int(v, d) local n = tonumber(v); if not n or n ~= n then return d end; return math.floor(n) end
local function unix()
    if Open77.time and type(Open77.time.unix) == "function" then return math.floor(Open77.time.unix()) end
    return os.time()
end

-- ---------------------------------------------------------------------------
-- The zone

local function validPolygon(points)
    if type(points) ~= "table" or #points < 3 or #points > 512 then return nil, "A polygon needs 3 to 512 points." end
    local list, box = {}, { minX = math.huge, minY = math.huge, maxX = -math.huge, maxY = -math.huge }
    for i, p in ipairs(points) do
        local x, y = tonumber(type(p) == "table" and (p.x or p[1])), tonumber(type(p) == "table" and (p.y or p[2]))
        if not x or not y or x ~= x or y ~= y then return nil, "Point " .. i .. " is not a position." end
        list[i] = { x = x, y = y }
        box.minX, box.maxX = math.min(box.minX, x), math.max(box.maxX, x)
        box.minY, box.maxY = math.min(box.minY, y), math.max(box.maxY, y)
    end
    return list, box
end

-- The outline op77_map3d draws (client/core/dogtown.lua -> exports.op77_map3d:addArea):
-- flat { x1, y1, x2, y2, ... } rounded to 0.1 m and at most OUTLINE_POINTS points (the map
-- takes 160 and an export argument holds 1024 values). A longer surveyed polygon loses its
-- least significant vertices first: the smallest triangle with its neighbours.
local OUTLINE_POINTS = 150
local outline = nil

local function simplify(list, max)
    local pts = {}
    for i, p in ipairs(list) do pts[i] = p end
    while #pts > max do
        local n, best, least = #pts, 1, math.huge
        for i = 1, n do
            local a, b, c = pts[(i - 2) % n + 1], pts[i], pts[i % n + 1]
            local w = math.abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y))
            if w < least then best, least = i, w end
        end
        table.remove(pts, best)
    end
    return pts
end

local function flatOutline(list)
    local out = {}
    for _, p in ipairs(simplify(list, OUTLINE_POINTS)) do
        out[#out + 1] = math.floor(p.x * 10 + 0.5) / 10
        out[#out + 1] = math.floor(p.y * 10 + 0.5) / 10
    end
    return out
end

function D.setPolygon(points, source)
    local list, box = validPolygon(points)
    if not list then return false, box end
    polygon, bbox, polygonSource = list, box, source or "config"
    outline = flatOutline(list)
    dirty = true
    return true
end

-- Planar, even-odd: full height (rooftops, the stadium bowl, the tunnels below).
function D.contains(point)
    if not polygon or type(point) ~= "table" then return false end
    local x, y = tonumber(point.x), tonumber(point.y)
    if not x or not y then return false end
    if x < bbox.minX or x > bbox.maxX or y < bbox.minY or y > bbox.maxY then return false end
    local inside, n = false, #polygon
    local j = n
    for i = 1, n do
        local a, b = polygon[i], polygon[j]
        if (a.y > y) ~= (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x then inside = not inside end
        j = i
    end
    return inside
end

function D.polygon() return polygon, polygonSource end
function D.outline() return outline end

local ok, why = D.setPolygon(Config.polygon, "config")
if not ok then LightRP.log("dogtown: invalid polygon in server/config/dogtown.lua (%s); the zone is off", tostring(why)); enabled = false end

-- Exits: the configured points outside the polygon, else the hospital.
function D.exits()
    local list = {}
    for i, e in ipairs(Config.exits or {}) do
        local x, y, z = tonumber(e.x), tonumber(e.y), tonumber(e.z)
        if x and y and z and not D.contains({ x = x, y = y }) then
            list[#list + 1] = { id = tostring(e.id or ("exit" .. i)), label = tostring(e.label or e.id or "Dogtown exit"), x = x, y = y, z = z, heading = tonumber(e.heading) or 0 }
        end
    end
    return list
end

function D.nearestExit(p)
    local best, bestD
    for _, e in ipairs(D.exits()) do
        local d = type(p) == "table" and tonumber(p.x) and tonumber(p.y) and ((e.x - p.x) ^ 2 + (e.y - p.y) ^ 2) or 0
        if not bestD or d < bestD then best, bestD = e, d end
    end
    if best then return best end
    local h = LightRpConfig and LightRpConfig.spawn and LightRpConfig.spawn.hospital
    if h and h.position then
        return { id = "hospital", label = h.label or "Hospital", x = h.position.x, y = h.position.y, z = h.position.z, heading = h.heading or 0 }
    end
    return nil
end

for i, e in ipairs(Config.exits or {}) do
    if tonumber(e.x) and tonumber(e.y) and D.contains({ x = tonumber(e.x), y = tonumber(e.y) }) then
        LightRP.log("dogtown: exit %s is inside the polygon: ignored (survey it again outside the walls)", tostring(e.id or i))
    end
end

-- ---------------------------------------------------------------------------
-- Who qualifies

local function bucketOf(player)
    if Open77.routingBuckets and Open77.routingBuckets.getPlayer then return Open77.routingBuckets.getPlayer(player) end
    return GetPlayerRoutingBucket(player)
end

local function capable(player)
    local life = Open77.players.getLifeState and Open77.players.getLifeState(player)
    local phase = type(life) == "table" and life.phase or nil
    return phase == "alive" or phase == "recovering"
end

local function downed(player)
    local M = LightRP.medical
    return M ~= nil and type(M.isDowned) == "function" and M.isDowned(player) == true
end

-- Pocket cash (the inventory's cash item), or nil before the inventory is loaded.
local function cashOf(player)
    local Inv = LightRP.inventory
    local inv = Inv and Inv.player and Inv.player(player)
    if not inv then return nil end
    return Inv.cashOf(inv)
end
D.cashOf = cashOf

-- Inside the polygon from a fresh server read; a stale or missing read keeps the
-- last answer (no flicker on a late snapshot).
function D.locate(player)
    local read = type(Open77.players.get) == "function" and Open77.players.get(player) or nil
    local p = type(read) == "table" and read.position or nil
    local age = type(read) == "table" and tonumber(read.ageMs) or nil
    if type(p) == "table" and (age == nil or age <= (Config.positionMaxAgeMs or 2500)) then
        positions[player] = p
        presence[player] = D.contains(p)
    end
    return presence[player] == true
end

function D.tagged(player)
    local t = tags[player]
    return t ~= nil and t > now()
end

function D.tagRemainingMs(player)
    local t = tags[player]
    return t and math.max(0, t - now()) or 0
end

-- In the city, playing (character active), not in an activity or a mission.
function D.eligible(player)
    if not enabled or not polygon then return false end
    if not LightRP.characters.isRegistered(player) then return false end
    if bucketOf(player) ~= (Config.bucket or 0) then return false end
    if LightRP.activities and LightRP.activities.owns and LightRP.activities.owns(player) then return false end
    return true
end

function D.inside(player) return D.eligible(player) and presence[player] == true end

-- In the fight: inside, or tagged outside (the anti-gank count, the streak).
function D.inZone(player) return D.eligible(player) and (presence[player] == true or D.tagged(player)) end

-- Carrying the stake in pocket cash (the bank never counts).
function D.staked(player)
    local cash = cashOf(player)
    return cash ~= nil and cash >= int(S().minCash, 0)
end

function D.qualifies(player)
    return D.inZone(player) and D.staked(player)
end

-- ---------------------------------------------------------------------------
-- Crews: teams in the scope, anti-gank counts

local function crewmates(a, b)
    local P = LightRP.parties
    if not P or type(P.of) ~= "function" then return false end
    local pa = P.of(a)
    return pa ~= nil and pa == P.of(b)
end
D.crewmates = crewmates

local function crewMembers(player)
    local P = LightRP.parties
    if P and type(P.members) == "function" then return P.members(player) end
    return { player }
end

-- Members of the player's crew in the zone, the player always counted.
function D.crewInZone(player)
    local n = 0
    for _, m in ipairs(crewMembers(player)) do
        if m == player or D.inZone(m) then n = n + 1 end
    end
    return math.max(1, n)
end

-- The combat team of a player: their crew's (teamBase + the crew's number), 0 alone.
function D.teamOf(player)
    local P = LightRP.parties
    local p = P and type(P.of) == "function" and P.of(player) or nil
    if not p or type(p.members) ~= "table" or #p.members < 2 then return 0 end
    local n = tonumber(tostring(p.id):match("(%d+)$"))
    if not n then return 0 end
    return int(Config.teamBase, 7700000) + n
end

local function setTeam(player, team)
    if type(Open77.combat) ~= "table" or type(Open77.combat.setTeam) ~= "function" then return false, "unavailable" end
    local called, result, reason = pcall(Open77.combat.setTeam, player, team)
    if not called then return false, result end
    if result == false then return false, reason end
    return true
end

-- Every rostered player on their crew's team; a player leaving the roster goes back
-- to no team (unless another system took them: another bucket, an activity).
function D.applyTeams()
    for player in pairs(roster) do
        local want = D.teamOf(player)
        if teams[player] ~= want then
            local done, reason = setTeam(player, want)
            if done then teams[player] = want
            elseif now() - lastTeamError > 10000 then
                lastTeamError = now()
                LightRP.log("dogtown: combat team %d refused for %s: %s", want, tostring(player), tostring(reason))
            end
        end
    end
    for player, team in pairs(teams) do
        if not roster[player] then
            if team ~= 0 and bucketOf(player) == (Config.bucket or 0)
                and not (LightRP.activities and LightRP.activities.owns and LightRP.activities.owns(player)) then
                setTeam(player, 0)
            end
            teams[player] = nil
        end
    end
end
function D.teams() return teams end

-- ---------------------------------------------------------------------------
-- Combat scopes: the PvP grant

local function release()
    for _, id in ipairs(scopes) do pcall(Open77.combat.removeScope, id) end
    scopes, roster = {}, {}
end

-- One scope; on a refused player (another resource's scope, a stale life state),
-- leave one out at a time and hold that player back for a few seconds.
local function grant(group)
    local id, reason = Open77.combat.createScope({ bucket = Config.bucket or 0, players = group })
    if id then return id, group end
    if (reason == "player_unavailable" or reason == "player_scoped") and #group > 2 then
        for i = 1, #group do
            local rest = {}
            for j, p in ipairs(group) do if j ~= i then rest[#rest + 1] = p end end
            local retry = Open77.combat.createScope({ bucket = Config.bucket or 0, players = rest })
            if retry then held[group[i]] = now() + 3000; return retry, rest end
        end
    end
    if reason == "player_unavailable" or reason == "player_scoped" then
        for _, p in ipairs(group) do held[p] = now() + 1500 end
    end
    return nil, reason
end

-- Splits the roster into groups of at most 32, west to east, as even as possible.
function D.groups(list)
    local maxGroups = math.max(1, math.min(8, math.tointeger(Config.maxScopes) or 8))
    table.sort(list, function(a, b)
        local pa, pb = positions[a], positions[b]
        local xa, xb = pa and pa.x or 0, pb and pb.x or 0
        if xa ~= xb then return xa < xb end
        return a < b
    end)
    local cap = 32 * maxGroups
    while #list > cap do table.remove(list) end
    local count = math.ceil(#list / 32)
    local groups = {}
    if #list < 2 then return groups end
    local size = math.ceil(#list / count)
    for i = 1, #list, size do
        local group = {}
        for j = i, math.min(i + size - 1, #list) do group[#group + 1] = list[j] end
        groups[#groups + 1] = group
    end
    -- An odd tail of one would be a scope of one: merge it into the previous group.
    if #groups > 1 and #groups[#groups] < 2 then
        local tail = table.remove(groups)
        for _, p in ipairs(tail) do table.insert(groups[#groups], p) end
    end
    return groups
end

function D.applyRoster(list, force)
    local groups = D.groups(list)
    local parts = {}
    for i, group in ipairs(groups) do
        local sorted = {}
        for j, p in ipairs(group) do sorted[j] = p end
        table.sort(sorted)
        parts[i] = table.concat(sorted, ",")
    end
    local key = table.concat(parts, "|")
    if key == rosterKey and not force then return end
    release()
    rosterKey = key
    if type(Open77.combat) ~= "table" or type(Open77.combat.createScope) ~= "function" then return end
    for index, group in ipairs(groups) do
        local id, members = grant(group)
        if id then
            scopes[#scopes + 1] = id
            for _, p in ipairs(members) do roster[p] = index end
            if #members < #group then rosterKey = "" end -- someone was held back: rebuild without them
        else
            local t = now()
            if t - lastError > 10000 then
                lastError = t
                LightRP.log("dogtown: PvP grant refused for %d player(s): %s", #group, tostring(members))
            end
            rosterKey = "" -- try again next sweep
        end
    end
end

function D.roster() return roster end

-- ---------------------------------------------------------------------------
-- The daily bonus of a killer's account (kill bonuses and bounties), per UTC day:
-- a write-through cache read once from SQL (as activity_pay.lua's daily cap).

Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_dogtown_bonus_daily (
    identifier VARCHAR(128) NOT NULL, day_index INT NOT NULL, minted INT NOT NULL DEFAULT 0,
    PRIMARY KEY (identifier, day_index)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local function today() return math.floor(unix() / 86400) end

-- Yields on the first read of the day (call from a thread).
local function dailyOf(identifier)
    local day = today()
    local d = bonusDaily[identifier]
    if not d or d.day ~= day then d = { day = day, minted = 0, synced = false }; bonusDaily[identifier] = d end
    if not d.synced and Db.ready then
        d.synced = true
        local row = Db.single("SELECT minted FROM lightrp_dogtown_bonus_daily WHERE identifier = ? AND day_index = ?", { identifier, day })
        d.minted = math.max(d.minted, row and tonumber(row.minted) or 0)
    end
    return d
end

local function saveDaily(identifier, d)
    if Db.ready then
        Db.run("INSERT INTO lightrp_dogtown_bonus_daily (identifier, day_index, minted) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE minted = GREATEST(minted, VALUES(minted))",
            { identifier, d.day, d.minted })
    end
end

-- What the account may still earn today.
function D.bonusLeft(identifier)
    local cap = int(L().bonusDailyCap, 0)
    if cap <= 0 then return math.huge end
    return math.max(0, cap - dailyOf(identifier).minted)
end

-- Reserves up to `amount` of today's cap; returns what was reserved and a commit
-- function (true = keep and save, false = give back).
local function reserveBonus(identifier, amount)
    amount = math.max(0, math.floor(amount or 0))
    if amount == 0 or not identifier then return 0, function() end end
    amount = math.min(amount, D.bonusLeft(identifier))
    if amount <= 0 then return 0, function() end end
    local d = dailyOf(identifier)
    d.minted = d.minted + amount
    return amount, function(keep)
        if keep then saveDaily(identifier, d) elseif bonusDaily[identifier] == d then d.minted = math.max(0, d.minted - amount) end
    end
end

-- Today's bonus without touching the database (the page).
local function mintedToday(identifier)
    local d = identifier and bonusDaily[identifier]
    return d and d.day == today() and d.minted or 0
end

-- ---------------------------------------------------------------------------
-- The page: presence, tag, stake, streak, rules, stats

local function presenceKey(player)
    return table.concat({ tostring(enabled), tostring(D.inside(player)), tostring(D.tagged(player)), tostring(roster[player] ~= nil),
        tostring(short[player] ~= nil), tostring(streaks[player] or 0), tostring(bounties[player] ~= nil), tostring(D.protected(player)) }, ":")
end

function D.push(player, force)
    local key = presenceKey(player)
    if not force and pushed[player] == key then return end
    pushed[player] = key
    LightRP.state(player, "dogtown")
end

local function emptyStats() return { kills = 0, deaths = 0, looted = 0, bestStreak = 0 } end
local function copyStats(s) return { kills = s.kills or 0, deaths = s.deaths or 0, looted = s.looted or 0, bestStreak = s.bestStreak or 0 } end

function D.weekIndex()
    -- The Unix epoch is a Thursday: +3 days puts week boundaries on Monday 00:00 UTC.
    return math.floor((unix() + 259200) / 604800)
end

local function statsOf(player)
    local s = stats[player]
    if not s then return nil end
    local week = D.weekIndex()
    if s.week ~= week then s.week, s.weekStats = week, emptyStats() end
    return s
end

-- What killing this player now would pay in bounty (0 = no bounty on them).
function D.bountyReward(player)
    local b = B()
    local streak = streaks[player] or 0
    if streak < int(b.streak, 5) then return 0 end
    local reward = int(b.perKill, 0) * streak
    if int(b.max, 0) > 0 then reward = math.min(reward, int(b.max, 0)) end
    return math.max(0, reward)
end

function D.rules()
    local loot, s, g, b = L(), S(), G(), B()
    return { mode = loot.mode or "bag", share = loot.share or 0, min = loot.min or 0, max = loot.max or 0,
        bonus = loot.bonus or 0, bonusDailyCap = loot.bonusDailyCap or 0, reserveSeconds = math.floor((loot.reserveMs or 0) / 1000),
        tagSeconds = math.floor((Config.combatTagMs or 20000) / 1000), pairCooldownMinutes = math.floor((loot.pairCooldownMs or 0) / 60000),
        stake = s.minCash or 0, graceSeconds = math.floor((s.graceMs or 0) / 1000),
        gankCrew = g.crewSize or 0, gankFactor = g.lossFactor or 1, underdogBonus = g.underdogBonus or 0,
        bountyStreak = b.streak or 0, bountyPerKill = b.perKill or 0, bountyMax = b.max or 0,
        protectionSeconds = math.floor(int(P().ms, 0) / 1000) }
end

LightRP.stateProvider("dogtown", function(player)
    local s = statsOf(player)
    local tag = D.tagRemainingMs(player)
    local c = LightRP.characters.get(player)
    local cash = cashOf(player) or 0
    local required = int(S().minCash, 0)
    local sh = short[player]
    local count = 0
    for _ in pairs(bounties) do count = count + 1 end
    return {
        enabled = enabled, label = Config.label or "Dogtown",
        inside = D.inside(player), tagged = enabled and tag > 0, tagEndsInMs = enabled and tag or 0,
        armed = roster[player] ~= nil,
        protected = D.protected(player), protectedInMs = D.protectedMs(player),
        stake = { required = required, cash = cash, missing = math.max(0, required - cash), short = sh ~= nil,
            evictInMs = sh and math.max(0, sh.evictAt - now()) or 0 },
        streak = streaks[player] or 0, bounty = bounties[player] ~= nil, bountyReward = D.bountyReward(player), bounties = count,
        bonusToday = mintedToday(c and c.identifier),
        rules = D.rules(),
        mine = s and { week = copyStats(s.weekStats), total = copyStats(s.total) } or { week = emptyStats(), total = emptyStats() },
        top = board.rows, week = board.week,
    }
end)

-- ---------------------------------------------------------------------------
-- Bounties: a pin following the target on everyone's 3D map (op77_map3d server
-- exports), moved every bounty.refreshMs.

local function mapCall(method, ...)
    if exports == nil then return false, "no_exports" end
    local args = table.pack(...)
    return pcall(function() return exports.op77_map3d[method](exports.op77_map3d, table.unpack(args, 1, args.n)) end)
end

local function bountyDef(player, b, position)
    local cfg = B().blip or {}
    return { id = BOUNTY_PREFIX .. tostring(player), position = { x = position.x, y = position.y, z = position.z or 0 },
        icon = cfg.icon or "crosshair", color = cfg.color or "#FF2E3C", scale = cfg.scale, pulse = cfg.pulse ~= false, edge = cfg.edge ~= false,
        label = "BOUNTY · " .. name(player),
        description = string.format("%d kills in a row in Dogtown. Take them down for %s.", b.streak, money(D.bountyReward(player))),
        category = "mission", priority = 2, routable = true }
end

local function notifyZone(except, notice)
    for _, raw in ipairs(GetPlayers()) do
        local other = pid(raw)
        if other and other ~= except and D.inZone(other) then LightRP.notice(other, notice) end
    end
end

-- Puts (or refreshes) the bounty on a player whose streak reached the threshold.
function D.markBounty(player)
    local streak = streaks[player] or 0
    if streak < int(B().streak, 5) then return end
    local b = bounties[player]
    local fresh = b == nil
    if fresh then b = { streak = streak }; bounties[player] = b end
    b.streak = streak
    local p = positions[player] or Open77.players.position(player)
    if type(p) == "table" then
        b.position = { x = p.x, y = p.y, z = p.z }
        local called, id, reason = mapCall("addBlip", -1, bountyDef(player, b, p))
        if called and id then b.blip = id
        elseif fresh then LightRP.log("dogtown: bounty pin refused for %s: %s", name(player), tostring(called and reason or id)) end
    end
    local reward = money(D.bountyReward(player))
    if fresh then
        LightRP.notice(player, { kind = "warning", title = "BOUNTY ON YOU", durationMs = 9000,
            body = string.format("%d kills in a row: everyone sees you on the map until you die or leave Dogtown. Your killer gets %s.", streak, reward) })
        notifyZone(player, { kind = "warning", title = "DOGTOWN BOUNTY", durationMs = 8000,
            body = string.format("%s is on a %d-kill streak: %s to whoever takes them down. They are on your map.", name(player), streak, reward) })
        LightRP.log("dogtown: bounty on %s (%d-kill streak, worth %s)", name(player), streak, reward)
    end
    D.push(player, true)
end

-- Ends a player's streak and lifts their bounty (death, leaving, disconnect, off).
function D.endStreak(player, reason)
    local b = bounties[player]
    streaks[player], bounties[player] = nil, nil
    if b then
        mapCall("removeBlip", b.blip or ("srv:" .. RESOURCE .. ":" .. BOUNTY_PREFIX .. tostring(player)))
        if reason == "left" then
            LightRP.notice(player, { kind = "info", title = "Bounty lifted", durationMs = 6000, body = "You left Dogtown: your streak is over and you are off the map." })
        end
        LightRP.log("dogtown: bounty on %s lifted (%s)", tostring(player), tostring(reason))
    end
    if reason ~= "disconnect" then D.push(player, true) end
end

function D.bounties() return bounties end
function D.streak(player) return streaks[player] or 0 end

local function refreshBounties()
    for player, b in pairs(bounties) do
        local p = positions[player]
        if type(p) == "table" and b.blip and (not b.position or (p.x - b.position.x) ^ 2 + (p.y - b.position.y) ^ 2 > 4) then
            b.position = { x = p.x, y = p.y, z = p.z }
            mapCall("updateBlip", b.blip, { position = b.position })
        end
    end
end

-- ---------------------------------------------------------------------------
-- The stake: warned, a grace, then sent to the nearest exit

local function seatOf(player)
    if type(Open77.players.getVehicleSeat) ~= "function" then return nil end
    local called, seat = pcall(Open77.players.getVehicleSeat, player)
    if called and type(seat) == "table" and seat.vehicleId then return seat end
    return nil
end

-- The car a player drives alone (it goes out with them), else nil.
function D.soloCar(player)
    local seat = seatOf(player)
    if not seat or (seat.seat ~= "seat_front_left" and seat.seat ~= "driver") then return nil end
    local V = Open77.vehicles
    if type(V) ~= "table" or type(V.occupantInSeat) ~= "function" or type(V.seats) ~= "function" then return nil end
    local called, list = pcall(V.seats)
    if not called or type(list) ~= "table" then return nil end
    for _, s in ipairs(list) do
        local okSeat, occupant = pcall(V.occupantInSeat, seat.vehicleId, s)
        if not okSeat then return nil end
        if occupant ~= nil and pid(occupant) ~= player then return nil end
    end
    return seat.vehicleId
end

-- Teleports a player under the stake to the nearest exit: on foot (dismounted, the
-- vehicle stays with its other occupants), or with the car they drive alone, parked
-- beside them. true, or false and a reason.
function D.evict(player)
    if not D.inside(player) then return true end
    local p = positions[player] or Open77.players.position(player)
    local exit = D.nearestExit(p)
    if not exit then return false, "no_exit" end
    local car = D.soloCar(player)
    local promise, failure = Open77.players.teleport(player, { x = exit.x, y = exit.y, z = exit.z },
        { heading = exit.heading, bucket = Config.bucket or 0, fade = true, dismount = true, timeoutMs = 15000 })
    if not promise then
        LightRP.log("dogtown: escorting %s out refused: %s", name(player), tostring(failure))
        return false, failure
    end
    local landed, rejected = promise:await()
    if not landed then
        LightRP.log("dogtown: escorting %s out failed: %s", name(player), tostring(rejected))
        return false, rejected
    end
    if car and type(Open77.vehicles.setTransform) == "function" then
        local h = math.rad(exit.heading)
        local placed = pcall(Open77.vehicles.setTransform, car, { position = { x = exit.x + math.cos(h) * 4, y = exit.y + math.sin(h) * 4, z = exit.z }, yaw = exit.heading })
        if not placed then LightRP.log("dogtown: %s's car could not follow them out", name(player)) end
    end
    presence[player] = false -- outside now; the next fresh read confirms
    LightRP.notice(player, { kind = "warning", title = "Escorted out of Dogtown", durationMs = 9000,
        body = string.format("You need %s in cash on you to be in Dogtown. You are at %s%s.", money(int(S().minCash, 0)), exit.label,
            car and ", with your car" or "") })
    LightRP.log("dogtown: %s escorted out to %s (under the %s stake)%s", name(player), exit.id, money(int(S().minCash, 0)), car and " with their car" or "")
    return true
end

function D.checkStake(player, t)
    local s = short[player]
    local cash = cashOf(player)
    local under = enabled and cash ~= nil and D.inside(player) and capable(player) and not downed(player) and cash < int(S().minCash, 0)
    if not under then
        if s and not s.evicting then short[player] = nil; D.push(player, true) end
        return
    end
    if not s then
        local grace = int(S().graceMs, 10000)
        s = { evictAt = t + grace }
        short[player] = s
        local required = int(S().minCash, 0)
        LightRP.notice(player, { kind = "warning", title = "DOGTOWN · NO STAKE", durationMs = math.max(4000, grace),
            body = string.format("You need %s in cash to fight in Dogtown: %s missing. You can't shoot or be shot here. Leave within %d s or you will be escorted out.",
                money(required), money(required - cash), math.ceil(grace / 1000)) })
        D.push(player, true)
    elseif not s.evicting and t >= s.evictAt then
        s.evicting = true
        CreateThread(function()
            local called, done, reason = pcall(D.evict, player)
            if short[player] ~= s then return end
            if called and done then short[player] = nil; D.push(player, true)
            else
                s.evicting, s.evictAt = false, now() + 3000
                if not called then LightRP.log("dogtown: escort failed: %s", tostring(done)) else LightRP.log("dogtown: escort of %s will retry (%s)", tostring(player), tostring(reason)) end
            end
        end)
    end
end

function D.short(player) return short[player] end

-- ---------------------------------------------------------------------------
-- Entry protection

function D.protectedMs(player)
    local untilMs = protectedUntil[player]
    if not untilMs or not enabled then return 0 end
    return math.max(0, untilMs - now())
end
function D.protected(player) return D.protectedMs(player) > 0 end

local function span(ms)
    local s = math.floor(ms / 1000)
    if s % 60 == 0 and s >= 60 then return string.format("%d minute%s", s // 60, s == 60 and "" or "s") end
    return string.format("%d seconds", s)
end

-- Starts the protection when this entry earns one: switched on, not tagged, not already
-- running, and either the first one, or after a death, or after rearmMs out of the zone.
function D.protect(player, t)
    local ms = int(P().ms, 0)
    if ms <= 0 or D.tagged(player) or D.protected(player) then return false end
    local away = outsideSince[player] and t - outsideSince[player] or 0
    if protectionSpent[player] and not diedSince[player] and away < int(P().rearmMs, 60000) then return false end
    protectedUntil[player], protectionSpent[player], diedSince[player] = t + ms, true, nil
    dirty = true
    LightRP.notice(player, { kind = "success", title = "DOGTOWN · ENTRY PROTECTION", durationMs = 8000,
        body = "For " .. span(ms) .. " nobody can hurt you and you cannot hurt anyone. Get clear of the gate before it runs out." })
    return true
end

-- Ends a protection that ran out (once), with a warning while still in the zone.
local function protectionOver(player, t)
    local untilMs = protectedUntil[player]
    if not untilMs or untilMs > t then return end
    protectedUntil[player] = nil
    dirty = true
    if D.inside(player) then
        LightRP.notice(player, { kind = "warning", title = "DOGTOWN · PROTECTION OVER", durationMs = 7000,
            body = "You are fair game now: anyone can kill you, and you can fight back." })
    end
    D.push(player, true)
end

-- ---------------------------------------------------------------------------
-- Sweep: presence, tags, stake, streaks, grants, teams, page

function D.sweep(force)
    local t = now()
    local list = {}
    for _, raw in ipairs(GetPlayers()) do
        local player = pid(raw)
        if player then
            D.locate(player)
            if tags[player] and tags[player] <= t then tags[player] = nil end
            if held[player] and held[player] <= t then held[player] = nil end
            -- A streak lives in the zone: leaving (outside and no longer tagged) ends it.
            if (streaks[player] or bounties[player]) and not D.inZone(player) then D.endStreak(player, "left") end
            D.checkStake(player, t)
            local inside = D.inside(player)
            if inside and not entered[player] then D.protect(player, t); D.entered(player) end
            entered[player] = inside
            if D.inZone(player) then outsideSince[player] = nil else outsideSince[player] = outsideSince[player] or t end
            protectionOver(player, t)
            if D.qualifies(player) and capable(player) and not held[player] and not D.protected(player) then list[#list + 1] = player end
        end
    end
    local rebuild = force or dirty or t >= rebuildAt
    dirty = false
    if rebuild then rebuildAt = t + (Config.refreshScopesMs or 10000) end
    D.applyRoster(list, rebuild)
    D.applyTeams()
    if t >= bountyRefreshAt then
        bountyRefreshAt = t + int(B().refreshMs, 3000)
        refreshBounties()
    end
    for _, raw in ipairs(GetPlayers()) do
        local player = pid(raw)
        if player then D.push(player) end
    end
end

-- Entering (or connecting inside): the page shows the banner; a chat line keeps a
-- trace, at most once per `entryChatMs`.
function D.entered(player)
    local t = now()
    if entryChatAt[player] and t - entryChatAt[player] < (Config.entryChatMs or 120000) then return end
    entryChatAt[player] = t
    local cash = cashOf(player)
    local line = string.format("DOGTOWN: no law past the walls, anyone can kill you. The stake is %s in cash.", money(int(S().minCash, 0)))
    if cash then line = line .. " You carry " .. money(cash) .. "." end
    if D.protected(player) then line = line .. string.format(" Entry protection: %d s.", math.ceil(D.protectedMs(player) / 1000)) end
    if LightRP.chat and LightRP.chat.system then pcall(LightRP.chat.system, player, line) end
end

-- ---------------------------------------------------------------------------
-- The damage arbiter: closes the gap between two sweeps. Refuses only between two
-- players this module scoped; never allows.

function D.arbitrate(event)
    if type(event) ~= "table" then return nil end
    local victim, attacker = pid(event.victim), pid(event.attacker)
    if not victim or not attacker or victim == attacker then return nil end
    if not roster[victim] or not roster[attacker] then return nil end
    if not enabled then return false end
    if crewmates(victim, attacker) then return false end
    if D.protected(victim) or D.protected(attacker) then return false end
    D.locate(victim); D.locate(attacker)
    if not D.qualifies(victim) or not D.qualifies(attacker) then return false end
    return nil
end

local arbiter
local function guarded(event)
    local called, verdict = pcall(D.arbitrate, event)
    if called then return verdict end
    local t = now()
    if t - lastError > 10000 then lastError = t; LightRP.log("dogtown arbiter failed; hit refused: %s", tostring(verdict)) end
    return false
end
if type(Open77.combat) == "table" and type(Open77.combat.onDamage) == "function" then
    local called, handle = pcall(Open77.combat.onDamage, guarded)
    if called and handle then arbiter = handle else LightRP.log("dogtown: damage arbiter unavailable: %s", tostring(handle)) end
end

-- ---------------------------------------------------------------------------
-- Tags

function D.tag(victim, attacker)
    local t = now()
    local untilMs = t + (Config.combatTagMs or 20000)
    hits[victim] = hits[victim] or {}
    hits[victim][attacker] = t
    for _, player in ipairs({ victim, attacker }) do
        local was = D.tagged(player)
        tags[player] = untilMs
        if not was or t - (tagPushedAt[player] or -math.huge) >= 1000 then
            tagPushedAt[player] = t
            D.push(player, true)
        end
    end
end

AddEventHandler("open77:playerDamaged", function(victim, attacker, amount)
    victim, attacker = pid(victim), pid(attacker)
    if not victim or not attacker or victim == attacker or (tonumber(amount) or 0) <= 0 then return end
    if not roster[victim] or roster[victim] ~= roster[attacker] then return end
    D.tag(victim, attacker)
end)

-- The player who hit this one last, within the tag window.
local function lastAttacker(player)
    local best, at = nil, -math.huge
    for attacker, t in pairs(hits[player] or {}) do
        if t > at and now() - t <= (Config.combatTagMs or 20000) then best, at = attacker, t end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- Stats

Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_dogtown_stats (
        identifier     VARCHAR(96)  NOT NULL,
        character_key  VARCHAR(64)  NOT NULL DEFAULT 'default',
        week_index     INT          NOT NULL,
        character_name VARCHAR(96)  NOT NULL DEFAULT '',
        kills          INT          NOT NULL DEFAULT 0,
        deaths         INT          NOT NULL DEFAULT 0,
        looted         BIGINT       NOT NULL DEFAULT 0,
        best_streak    INT          NOT NULL DEFAULT 0,
        updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (identifier, character_key, week_index),
        KEY ix_dogtown_week (week_index, kills)
    )
]])

local UPSERT = [[INSERT INTO lightrp_dogtown_stats (identifier, character_key, week_index, character_name, kills, deaths, looted, best_streak)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE kills = kills + VALUES(kills), deaths = deaths + VALUES(deaths), looted = looted + VALUES(looted),
        best_streak = GREATEST(best_streak, VALUES(best_streak)), character_name = VALUES(character_name)]]

-- A table created before best_streak existed (the first Dogtown build) gets it.
local function migrate()
    local present = Db.single([[SELECT COUNT(*) AS n FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'lightrp_dogtown_stats' AND COLUMN_NAME = 'best_streak']])
    if present and tonumber(present.n) == 0 then
        Db.run("ALTER TABLE lightrp_dogtown_stats ADD COLUMN best_streak INT NOT NULL DEFAULT 0")
        LightRP.log("migrated: lightrp_dogtown_stats.best_streak added")
    end
end

local function characterKey(c) return tostring(c.identifier) .. "#" .. tostring(c.key or "default") end

local function memoryOf(key, label, c)
    local m = memory[key]
    if not m then m = { name = label, weeks = {}, total = emptyStats() }; memory[key] = m end
    if label then m.name = label end
    if c then m.identifier, m.characterKey = c.identifier, c.key or "default" end
    return m
end

-- Loads a character's counters (database, or this session's memory).
function D.loadStats(player)
    local c = LightRP.characters.get(player)
    if not c or c.status ~= "active" or not c.identifier then stats[player] = nil; return end
    local key, week = characterKey(c), D.weekIndex()
    local entry = { key = key, name = name(player), week = week, weekStats = emptyStats(), total = emptyStats() }
    if Db.ready then
        local read, rows = Db.read("SELECT week_index, kills, deaths, looted, best_streak FROM lightrp_dogtown_stats WHERE identifier = ? AND character_key = ? AND week_index IN (0, ?)",
            { c.identifier, c.key or "default", week })
        if read then
            for _, row in ipairs(rows) do
                local s = { kills = tonumber(row.kills) or 0, deaths = tonumber(row.deaths) or 0, looted = tonumber(row.looted) or 0,
                    bestStreak = tonumber(row.best_streak) or 0 }
                if tonumber(row.week_index) == 0 then entry.total = s else entry.weekStats = s end
            end
        end
    else
        local m = memoryOf(key, entry.name, c)
        entry.total = copyStats(m.total)
        entry.weekStats = copyStats(m.weeks[week] or emptyStats())
    end
    if LightRP.characters.get(player) == c then stats[player] = entry; LightRP.state(player, "dogtown") end
end

function D.statsFor(player) return statsOf(player) end

-- Adds to a character's counters: { kills, deaths, looted, streak } (streak: the
-- current streak, kept when it beats the best).
function D.record(player, delta)
    local c = LightRP.characters.get(player)
    if not c or not c.identifier then return end
    local key, week, label = characterKey(c), D.weekIndex(), name(player)
    local s = statsOf(player)
    if not s or s.key ~= key then
        s = { key = key, name = label, week = week, weekStats = emptyStats(), total = emptyStats() }
        stats[player] = s
    end
    local k, d, l, streak = delta.kills or 0, delta.deaths or 0, delta.looted or 0, delta.streak or 0
    local function add(bucket)
        bucket.kills, bucket.deaths, bucket.looted = bucket.kills + k, bucket.deaths + d, bucket.looted + l
        bucket.bestStreak = math.max(bucket.bestStreak or 0, streak)
    end
    add(s.weekStats); add(s.total)
    local m = memoryOf(key, label, c)
    m.weeks[week] = m.weeks[week] or emptyStats()
    add(m.weeks[week]); add(m.total)
    if Db.ready then
        CreateThread(function()
            Db.run(UPSERT, { c.identifier, c.key or "default", 0, label, k, d, l, streak })
            Db.run(UPSERT, { c.identifier, c.key or "default", week, label, k, d, l, streak })
            if k > 0 then D.refreshBoard(true) end
        end)
    elseif k > 0 then D.refreshBoard(true) end
    LightRP.state(player, "dogtown")
end

-- This week's top killers.
function D.refreshBoard(force)
    local t, week = now(), D.weekIndex()
    if not force and week == board.week and t - board.at < ((Config.stats or {}).refreshMs or 60000) then return board end
    local size = math.max(1, math.min(20, math.tointeger((Config.stats or {}).leaderboardSize) or 5))
    local rows = {}
    if Db.ready then
        local read, result = Db.read(string.format([[SELECT character_name, kills, deaths, looted FROM lightrp_dogtown_stats
            WHERE week_index = ? AND kills > 0 ORDER BY kills DESC, looted DESC, deaths ASC LIMIT %d]], size), { week })
        if not read then board.at = t; return board end
        for i, row in ipairs(result) do
            rows[i] = { rank = i, name = tostring(row.character_name or "?"), kills = tonumber(row.kills) or 0,
                deaths = tonumber(row.deaths) or 0, looted = tonumber(row.looted) or 0 }
        end
    else
        for _, m in pairs(memory) do
            local s = m.weeks[week]
            if s and s.kills > 0 then rows[#rows + 1] = { name = m.name or "?", kills = s.kills, deaths = s.deaths, looted = s.looted } end
        end
        table.sort(rows, function(a, b)
            if a.kills ~= b.kills then return a.kills > b.kills end
            if a.looted ~= b.looted then return a.looted > b.looted end
            if a.deaths ~= b.deaths then return a.deaths < b.deaths end
            return a.name < b.name
        end)
        while #rows > size do table.remove(rows) end
        for i, row in ipairs(rows) do row.rank = i end
    end
    local same = week == board.week and #rows == #board.rows
    for i, row in ipairs(rows) do
        local old = board.rows[i]
        if not same or not old or old.name ~= row.name or old.kills ~= row.kills or old.deaths ~= row.deaths or old.looted ~= row.looted then same = false; break end
    end
    board = { week = week, rows = rows, at = t }
    if not same then LightRP.broadcastState("dogtown") end
    return board
end

function D.board() return board end

-- Lifetime rows without a database (the Hall of Fame's no-DB mode).
function D.memoryRows()
    local rows = {}
    for key, m in pairs(memory) do
        if m.identifier then
            rows[#rows + 1] = { key = key, identifier = m.identifier, characterKey = m.characterKey, name = m.name,
                kills = m.total.kills, deaths = m.total.deaths, bestStreak = m.total.bestStreak or 0 }
        end
    end
    return rows
end

-- ---------------------------------------------------------------------------
-- The Hall of Fame (server/modules/halloffame.lua): two lifetime boards in its PvP
-- tab, credited kills only.

local function hofSource(ctx)
    if ctx.dogtownRows then return ctx.dogtownRows end
    local rows = {}
    if ctx.db then
        local read, result = ctx.read([[SELECT identifier, character_key, character_name, kills, deaths, best_streak
            FROM lightrp_dogtown_stats WHERE week_index = 0 AND (kills > 0 OR best_streak > 0)]])
        if read then
            for _, r in ipairs(result) do
                rows[#rows + 1] = { key = ctx.keyOf(r.identifier, r.character_key), name = r.character_name, kills = tonumber(r.kills) or 0,
                    deaths = tonumber(r.deaths) or 0, bestStreak = tonumber(r.best_streak) or 0 }
            end
        end
    else
        for _, r in ipairs(D.memoryRows()) do
            rows[#rows + 1] = { key = ctx.keyOf(r.identifier, r.characterKey), name = r.name, kills = r.kills, deaths = r.deaths, bestStreak = r.bestStreak }
        end
    end
    ctx.dogtownRows = rows
    return rows
end
local function kd(r) return r.kills / math.max(1, r.deaths) end

function D.hallOfFameKills(ctx)
    local out = {}
    for _, r in ipairs(hofSource(ctx)) do
        if r.kills > 0 then
            out[#out + 1] = { key = r.key, name = r.name, value = r.kills, sort = { r.kills, -r.deaths, r.bestStreak },
                detail = string.format("K/D %.2f · best streak %d", kd(r), r.bestStreak) }
        end
    end
    return out
end

function D.hallOfFameStreaks(ctx)
    local out = {}
    for _, r in ipairs(hofSource(ctx)) do
        if r.bestStreak > 0 then
            out[#out + 1] = { key = r.key, name = r.name, value = r.bestStreak, sort = { r.bestStreak, r.kills, -r.deaths },
                detail = string.format("%d kill%s · K/D %.2f", r.kills, r.kills == 1 and "" or "s", kd(r)) }
        end
    end
    return out
end

local function registerHallOfFame()
    local H = LightRP.hallOfFame
    if Config.hallOfFame == false or type(H) ~= "table" or type(H.registerBoard) ~= "function" then return false end
    H.registerBoard("dogtown.kills", { tab = "pvp", title = "DOGTOWN KILLS", subtitle = "Credited kills in the Dogtown PvP zone", unit = "kills",
        provider = D.hallOfFameKills })
    H.registerBoard("dogtown.streak", { tab = "pvp", title = "DOGTOWN STREAK", subtitle = "Most Dogtown kills in a row without dying", unit = "kills",
        overview = false, provider = D.hallOfFameStreaks })
    return true
end
D.registerHallOfFame = registerHallOfFame
registerHallOfFame()

-- ---------------------------------------------------------------------------
-- Kills and loot

-- nil, pair (credited) or a reason: no_character, same_account, crewmate, cooldown.
function D.verdict(killer, victim)
    local loot = L()
    local kc, vc = LightRP.characters.get(killer), LightRP.characters.get(victim)
    if not kc or not vc or not kc.identifier or not vc.identifier then return "no_character" end
    if loot.lootSameAccount ~= true and kc.identifier == vc.identifier then return "same_account" end
    if loot.lootCrewmates ~= true and crewmates(killer, victim) then return "crewmate" end
    local pair = characterKey(kc) .. ">" .. characterKey(vc)
    local last = cooldowns[pair]
    if last and now() - last < (loot.pairCooldownMs or 0) then return "cooldown", pair end
    return nil, pair
end

-- The loss of a death: `share` of the pocket cash, at least `min`, at most `max`,
-- never more than carried.
function D.lossAmount(cash)
    local loot = L()
    cash = math.floor(tonumber(cash) or 0)
    if cash <= 0 then return 0 end
    local amount = math.floor(cash * (tonumber(loot.share) or 0))
    if int(loot.min, 0) > 0 then amount = math.max(amount, int(loot.min, 0)) end
    if int(loot.max, 0) > 0 then amount = math.min(amount, int(loot.max, 0)) end
    return math.max(0, math.min(amount, cash))
end

-- The terms of a credited kill: loss (anti-gank applied), bonus before the daily cap.
function D.killTerms(killer, victim, cash)
    local g = G()
    local terms = { killerCrew = D.crewInZone(killer), victimCrew = D.crewInZone(victim) }
    terms.loss = D.lossAmount(cash)
    terms.gank = int(g.crewSize, 0) > 0 and terms.killerCrew >= int(g.crewSize, 0)
    if terms.gank then terms.loss = math.floor(terms.loss * (tonumber(g.lossFactor) or 1)) end
    terms.underdog = terms.victimCrew > terms.killerCrew
    local share = tonumber(L().bonus) or 0
    if terms.underdog then share = share * (1 + (tonumber(g.underdogBonus) or 0)) end
    terms.bonus = math.max(0, math.floor(terms.loss * share + 1e-9))
    return terms
end

-- Was this kill a Dogtown kill? Both scoped together (now), or the victim took a
-- Dogtown hit from the killer within the tag window.
function D.isDogtownKill(victim, killer)
    if not enabled or not victim or not killer or victim == killer then return false end
    local A = LightRP.activities
    if A and A.owns and (A.owns(victim) or A.owns(killer)) then return false end
    if bucketOf(victim) ~= (Config.bucket or 0) then return false end
    if roster[victim] and roster[victim] == roster[killer] then return true end
    local at = hits[victim] and hits[victim][killer]
    return at ~= nil and now() - at <= (Config.combatTagMs or 20000)
end

local function retry(fn, attempts)
    local loot = L()
    local okay, result, extra
    for _ = 0, math.max(0, attempts or math.tointeger(loot.retries) or 10) do
        okay, result, extra = fn()
        if okay or result ~= "busy" then return okay, result, extra end
        Wait(loot.retryMs or 300)
    end
    return okay, result, extra
end

-- A death in a Dogtown fight (credited or not): the streak ends, the hospital bill
-- is waived, a combat log right after does not drop a second bag.
function D.died(player)
    D.endStreak(player, "death")
    lastDeathAt[player] = now()
    if Config.waiveHospitalBill ~= false then deathMark[player] = { at = now() } end
end

-- economy_sinks.lua: no hospital bill after a death in a Dogtown fight (until the
-- player has been back on their feet for a few seconds).
function D.waivesHospital(player)
    if Config.waiveHospitalBill == false then return false end
    local m = deathMark[player]
    if not m then return false end
    local t = now()
    if t - m.at > 30 * 60000 or (m.clearAt and t >= m.clearAt) then deathMark[player] = nil; return false end
    return true
end

local function crewAllows(owner)
    return function(player) return player == owner or crewmates(owner, player) end
end

local NO_CREDIT = {
    same_account = "Same account: no kill, nothing dropped, no bonus.",
    crewmate = "Crewmate: no kill, nothing dropped, no bonus.",
    cooldown = "You already took them down in the last %d minutes: no kill, nothing dropped, no bonus.",
}

-- Pays a server bonus (bounty) in pocket cash, within the daily cap. Returns the amount.
local function payBounty(killer, kc, amount, note, counterparty)
    local reserved, commit = reserveBonus(kc.identifier, amount)
    if reserved <= 0 then return 0 end
    local paid = retry(function() return LightRP.money.addCash(killer, reserved, "dogtown_bounty", note, counterparty) end)
    commit(paid == true)
    if paid ~= true then LightRP.log("dogtown bounty: %d for %s not credited", reserved, tostring(kc.identifier)); return 0 end
    LightRP.log("dogtown bounty: +%d to %s (%s)", reserved, tostring(kc.identifier), note)
    return reserved
end

function D.onKill(victim, killer, context)
    local loot = L()
    local killerName, victimName = name(killer), name(victim)
    local wantedStreak = streaks[victim] or 0
    local bountyWorth = D.bountyReward(victim)
    D.died(victim)
    local reason, pair = D.verdict(killer, victim)
    if reason then
        local text = NO_CREDIT[reason]
        if text then
            LightRP.notice(killer, { kind = "warning", title = "Dogtown", body = string.format(text, math.floor((loot.pairCooldownMs or 0) / 60000)), durationMs = 7000 })
        end
        LightRP.notice(victim, { kind = "warning", title = "Killed in Dogtown", body = "Killed by " .. killerName .. ". It does not count: you kept your cash.", durationMs = 8000 })
        LightRP.log("dogtown: %s killed %s, not credited (%s)", killerName, victimName, reason)
        return reason
    end
    cooldowns[pair] = now()
    local kc = LightRP.characters.get(killer)
    -- the killer's run: one more kill in a row
    local streak = (streaks[killer] or 0) + 1
    streaks[killer] = streak
    D.record(killer, { kills = 1, streak = streak })
    D.record(victim, { deaths = 1 })
    D.markBounty(killer)
    D.push(killer, true)
    -- titles.lua: credited kills only; bountyStreak > 0 = this kill ended a bounty
    if LightRP.eachModule then LightRP.eachModule("onDogtownKill", killer, victim, { streak = streak, bountyStreak = bountyWorth > 0 and wantedStreak or 0 }) end

    -- a bounty on the victim: the reward, in pocket cash, inside the daily cap
    local bountyPaid = 0
    if bountyWorth > 0 then
        bountyPaid = payBounty(killer, kc, bountyWorth, string.format("Bounty on %s (%d-kill streak) in Dogtown", victimName, wantedStreak), victimName)
        if bountyPaid > 0 then
            LightRP.notice(killer, { kind = "money", title = "BOUNTY CLAIMED", durationMs = 9000,
                body = string.format("You ended %s's %d-kill streak: +%s in cash.", victimName, wantedStreak, money(bountyPaid)) })
        elseif bountyWorth > 0 then
            LightRP.notice(killer, { kind = "info", title = "BOUNTY", durationMs = 8000,
                body = string.format("You ended %s's streak, but your daily Dogtown bonus (%s) is used up: no reward.", victimName, money(int(loot.bonusDailyCap, 0))) })
        end
    end

    local Inv = LightRP.inventory
    local inv = Inv and Inv.player(victim)
    local cash = inv and Inv.cashOf(inv) or 0
    local terms = D.killTerms(killer, victim, cash)
    local amount = terms.loss
    if amount <= 0 then
        LightRP.notice(killer, { kind = "info", title = "Dogtown kill", body = victimName .. " carried no cash: nothing to take.", durationMs = 7000 })
        LightRP.notice(victim, { kind = "warning", title = "Killed in Dogtown", body = "Killed by " .. killerName .. ". You had no cash on you.", durationMs = 8000 })
        return "nothing", 0
    end
    local bonus, commit = reserveBonus(kc.identifier, terms.bonus)
    local capped = bonus < terms.bonus
    local notes = {}
    if terms.gank then notes[#notes + 1] = string.format("halved: your crew has %d in the zone", terms.killerCrew) end
    if terms.underdog and bonus > 0 then notes[#notes + 1] = string.format("+%d%% bonus: you took on a bigger crew", math.floor((tonumber(G().underdogBonus) or 0) * 100 + 0.5)) end
    if capped then notes[#notes + 1] = string.format("daily bonus limit (%s) reached", money(int(loot.bonusDailyCap, 0))) end
    local extra = #notes > 0 and (" (" .. table.concat(notes, "; ") .. ")") or ""
    local victimExtra = terms.gank and " Their crew outnumbered you: you lost half." or ""

    local placed, result
    if (loot.mode or "bag") == "bag" then
        local p = type(context) == "table" and context.position or nil
        if type(p) ~= "table" or not tonumber(p.x) or not tonumber(p.y) or not tonumber(p.z) then p = Open77.players.position(victim) end
        if type(p) == "table" then
            local position = { x = tonumber(p.x), y = tonumber(p.y), z = tonumber(p.z), bucket = Config.bucket or 0 }
            local reserveMs = int(loot.reserveMs, 0)
            placed, result = retry(function()
                return Inv.dropCash(victim, amount, position, {
                    mint = bonus,
                    label = (loot.bagLabel or "Cash bag") .. " · " .. money(amount + bonus), prompt = "Pick up", marker = loot.bagMarker,
                    reserve = reserveMs > 0 and { untilMs = now() + reserveMs, allows = crewAllows(killer) } or nil,
                    ledger = { kind = "dogtown_loot", counterparty = victimName, direction = "in", skip = inv.id,
                        note = bonus > 0 and string.format("Cash bag picked up in Dogtown (incl. %s server bonus)", money(bonus)) or "Cash bag picked up in Dogtown" },
                    ownerLedger = { kind = "dogtown_loss", note = "Cash dropped on death in Dogtown", counterparty = killerName, direction = "out" },
                })
            end)
            if placed then
                commit(true)
                bags[result.id] = result
                if bonus > 0 then
                    LightRP.log("dogtown bonus: +%d minted into a cash bag for %s (killer %s, victim %s)%s", bonus, tostring(kc.identifier), killerName, victimName, extra)
                end
                local reserveText = reserveMs > 0 and string.format(" It is yours and your crew's for %d s.", math.floor(reserveMs / 1000)) or ""
                LightRP.notice(killer, { kind = "money", title = "Dogtown kill", durationMs = 9000,
                    body = string.format("%s dropped %s%s where they fell.%s%s", victimName, money(amount), bonus > 0 and (" + " .. money(bonus) .. " bonus") or "", reserveText, extra) })
                LightRP.notice(victim, { kind = "warning", title = "Killed in Dogtown", durationMs = 9000,
                    body = "Killed by " .. killerName .. ". You dropped " .. money(amount) .. " in cash where you fell. Your bank is safe." .. victimExtra })
                LightRP.log("dogtown: %s killed %s, cash bag %d + bonus %d at (%.1f, %.1f, %.1f)%s", killerName, victimName, amount, bonus, position.x, position.y, position.z, extra)
                return "bag", amount, bonus
            end
            LightRP.log("dogtown: cash bag refused (%s), falling back to a transfer", tostring(result))
        end
    end
    placed, result = retry(function()
        return Inv.transferCash(victim, killer, amount, {
            from = { kind = "dogtown_loss", note = "Taken on death in Dogtown", counterparty = killerName, direction = "out" },
            to = { kind = "dogtown_loot", note = "Taken from a kill in Dogtown", counterparty = victimName, direction = "in" },
        })
    end)
    if placed then
        local paidBonus = 0
        if bonus > 0 then
            local note = "Dogtown kill bonus on " .. victimName
            local credited = retry(function() return LightRP.money.addCash(killer, bonus, "dogtown_bonus", note, victimName) end)
            if credited == true then
                paidBonus = bonus
                LightRP.log("dogtown bonus: +%d to %s (%s)%s", bonus, tostring(kc.identifier), note, extra)
            end
        end
        commit(paidBonus > 0)
        LightRP.notice(killer, { kind = "money", title = "Dogtown kill", durationMs = 9000,
            body = string.format("You took %s from %s%s.%s", money(amount), victimName, paidBonus > 0 and (" + " .. money(paidBonus) .. " bonus") or "", extra) })
        LightRP.notice(victim, { kind = "warning", title = "Killed in Dogtown", durationMs = 9000,
            body = killerName .. " took " .. money(amount) .. " from your pocket. Your bank is safe." .. victimExtra })
        LightRP.log("dogtown: %s killed %s, took %d + bonus %d", killerName, victimName, amount, paidBonus)
        return "transfer", amount, paidBonus
    end
    commit(false)
    LightRP.log("dogtown: loot of %d from %s refused: %s", amount, victimName, tostring(result))
    LightRP.notice(killer, { kind = "warning", title = "Dogtown kill", body = "Their cash could not be taken (" .. tostring(Inv.explain and Inv.explain(result) or result) .. ").", durationMs = 7000 })
    return "failed", result
end

AddEventHandler("open77:playerKilled", function(victim, killer, context)
    victim, killer = pid(victim), pid(killer)
    if not D.isDogtownKill(victim, killer) then return end
    local decoded = nil
    if type(context) == "string" then
        local parsed, value = pcall(json.decode, context)
        if parsed and type(value) == "table" then decoded = value end
    elseif type(context) == "table" then decoded = context end
    CreateThread(function()
        local called, err = pcall(D.onKill, victim, killer, decoded)
        if not called then LightRP.log("dogtown kill handling failed: %s", tostring(err)) end
    end)
end)

-- ---------------------------------------------------------------------------
-- Combat log: a tagged player who disconnects drops the bag of a death (no bonus),
-- reserved to their last attacker's crew. Runs from onDisconnecting, while the
-- inventory and the wallet are still loaded (the handler awaits the transaction).

function D.combatLog(player)
    if Config.combatLog == false or not enabled or not D.tagged(player) or not D.eligible(player) then return nil end
    if not capable(player) or downed(player) then return nil end -- dying: the kill already counted
    if lastDeathAt[player] and now() - lastDeathAt[player] < (Config.combatTagMs or 20000) then return nil end
    local who, left = name(player), math.ceil(D.tagRemainingMs(player) / 1000)
    local Inv = LightRP.inventory
    local inv = Inv and Inv.player(player)
    local amount = D.lossAmount(inv and Inv.cashOf(inv) or 0)
    if amount <= 0 then
        LightRP.log("dogtown: combat log by %s (tag %d s left): no cash on them", who, left)
        return "nothing"
    end
    local p = positions[player] or Open77.players.position(player)
    if type(p) ~= "table" or not tonumber(p.x) then LightRP.log("dogtown: combat log by %s: position unknown, no bag", who); return "no_position" end
    local attacker = lastAttacker(player)
    local position = { x = tonumber(p.x), y = tonumber(p.y), z = tonumber(p.z) or 0, bucket = Config.bucket or 0 }
    local loot = L()
    local reserveMs = int(loot.reserveMs, 0)
    local placed, result = retry(function()
        return Inv.dropCash(player, amount, position, {
            label = (loot.bagLabel or "Cash bag") .. " · " .. money(amount), prompt = "Pick up", marker = loot.bagMarker,
            reserve = attacker and reserveMs > 0 and { untilMs = now() + reserveMs, allows = crewAllows(attacker) } or nil,
            ledger = { kind = "dogtown_loot", note = "Combat-log bag picked up in Dogtown", counterparty = who, direction = "in", skip = inv.id },
            ownerLedger = { kind = "dogtown_loss", note = "Dropped on leaving mid-fight in Dogtown", counterparty = attacker and name(attacker) or nil, direction = "out" },
        })
    end, 3)
    if not placed then
        LightRP.log("dogtown: combat log by %s: bag of %d refused (%s)", who, amount, tostring(result))
        return "failed"
    end
    bags[result.id] = result
    LightRP.log("dogtown: combat log by %s (tag %d s left): bag %d at (%.1f, %.1f, %.1f)%s", who, left, amount, position.x, position.y, position.z,
        attacker and (", reserved to " .. name(attacker) .. "'s crew") or "")
    if attacker then
        LightRP.notice(attacker, { kind = "money", title = "Dogtown", durationMs = 8000,
            body = string.format("%s logged out mid-fight and dropped %s where they stood.", who, money(amount)) })
    end
    return "bag", amount
end

function D.onDisconnecting(player)
    local called, err = pcall(D.combatLog, player)
    if not called then LightRP.log("dogtown: combat log handling failed: %s", tostring(err)) end
end

-- ---------------------------------------------------------------------------
-- Passages through the gates (when the gates stay shut on a client's save)

local passages = {}
local function registerPassages()
    for _, p in ipairs(Config.passages or {}) do
        if type(p.id) == "string" and type(p.outside) == "table" and type(p.inside) == "table" then
            local label = p.label or "Dogtown"
            passages["dogtown.in." .. p.id] = { to = p.inside, entering = true, label = label }
            passages["dogtown.out." .. p.id] = { to = p.outside, entering = false, label = label }
            LightRP.interaction("dogtown.in." .. p.id, { position = p.outside, radius = Config.passageRadius or 2.0, bucket = Config.bucket or 0,
                label = label, prompt = "Enter Dogtown (PvP zone)", key = "E", marker = Config.passageMarker, ring = false })
            LightRP.interaction("dogtown.out." .. p.id, { position = p.inside, radius = Config.passageRadius or 2.0, bucket = Config.bucket or 0,
                label = label, prompt = "Leave Dogtown", key = "E", marker = Config.passageMarker, ring = false })
        end
    end
end
if LightRP.batchInteractions then LightRP.batchInteractions(registerPassages) else registerPassages() end

function D.onInteract(player, id)
    local p = passages[id]
    if not p then return end
    if not p.entering and D.tagged(player) then
        LightRP.notice(player, { kind = "warning", title = "Dogtown", body = string.format("You are in a fight: wait %d s before leaving through the gate.", math.ceil(D.tagRemainingMs(player) / 1000)) })
        return
    end
    if p.entering and not D.staked(player) then
        LightRP.notice(player, { kind = "warning", title = "Dogtown", body = string.format("The stake is %s in cash on you: come back with it.", money(int(S().minCash, 0))) })
        return
    end
    if bucketOf(player) ~= (Config.bucket or 0) then return end
    CreateThread(function()
        local promise, failure = Open77.players.teleport(player, p.to, { heading = p.to.heading or 0, bucket = Config.bucket or 0, fade = true, dismount = true, timeoutMs = 30000 })
        if promise then promise:await() else LightRP.log("dogtown passage refused for %d: %s", player, tostring(failure)) end
    end)
end

-- ---------------------------------------------------------------------------
-- Client: map pins, district probes (survey)

-- How op77_map3d draws the zone (Config.area); its label point only while it is inside.
local function areaConfig()
    local a = Config.area
    if type(a) ~= "table" or not outline then return nil end
    local lp = a.labelPosition
    return { label = a.label, labelPosition = type(lp) == "table" and D.contains(lp) and { x = lp.x, y = lp.y } or nil,
        fill = a.fill, fillOpacity = a.fillOpacity, stroke = a.stroke, strokeWidth = a.strokeWidth, pattern = a.pattern,
        map = a.map ~= false, minimap = a.minimap ~= false, pulse = a.pulse == true }
end

local function clientConfig()
    local b = Config.blip or {}
    local area = areaConfig()
    return { kind = "config", enabled = enabled, label = Config.label or "Dogtown", blip = b.position and {
        position = b.position, title = b.title, description = b.description, sprite = b.sprite, fallbackSprite = b.fallbackSprite, color = b.color } or nil,
        area = area, outline = area and outline or nil }
end

function D.sendConfig(player) TriggerClientEvent(NET, player or -1, clientConfig()) end

-- Asks a client which district the engine says it stands in; `callback(place)`.
local function probe(player, callback)
    probeSeq = probeSeq + 1
    probes[probeSeq] = { player = player, callback = callback, expires = now() + 5000 }
    TriggerClientEvent(NET, player, { kind = "probe", token = probeSeq })
    return probeSeq
end

local function isDogtown(place)
    if type(place) ~= "table" then return nil end
    local d, s = tostring(place.district or ""), tostring(place.subDistrict or "")
    if d == "" and s == "" then return nil end
    return (d .. " " .. s):lower():find("dogtown", 1, true) ~= nil
end

RegisterNetEvent(REPORT, function(message)
    local player = pid(source)
    if not player or type(message) ~= "table" then return end
    if message.kind == "hello" then D.sendConfig(player); return end
    local place = { district = type(message.district) == "string" and message.district:sub(1, 64) or "",
        subDistrict = type(message.subDistrict) == "string" and message.subDistrict:sub(1, 64) or "" }
    if message.kind == "probe" then
        local p = probes[tonumber(message.token) or -1]
        if not p or p.player ~= player then return end
        probes[tonumber(message.token)] = nil
        pcall(p.callback, place)
    elseif message.kind == "district" and Config.logDistrictMismatch ~= false then
        -- A survey aid, never a grant: the engine's district volume against the polygon.
        local engine = isDogtown(place)
        if engine == nil then return end
        local inside = D.locate(player)
        if engine ~= inside and now() - (lastMismatch[player] or -math.huge) > 5000 then
            lastMismatch[player] = now()
            local p = positions[player]
            LightRP.log("dogtown survey: engine says %s, polygon says %s at (%.1f, %.1f)", engine and "Dogtown" or place.district,
                inside and "inside" or "outside", p and p.x or 0, p and p.y or 0)
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Staff: /lightrp.dogtown status|on|off|survey ...

local function positionOf(player)
    local read = type(Open77.players.get) == "function" and Open77.players.get(player) or nil
    local p = type(read) == "table" and read.position or Open77.players.position(player)
    local heading = type(read) == "table" and tonumber(read.heading or read.yaw) or 0
    return p, heading
end

function D.status()
    local inside, tagged, scoped, shortCount, wanted = 0, 0, 0, 0, 0
    for _, raw in ipairs(GetPlayers()) do
        local player = pid(raw)
        if player then
            if D.inside(player) then inside = inside + 1 end
            if D.tagged(player) then tagged = tagged + 1 end
            if roster[player] then scoped = scoped + 1 end
            if short[player] then shortCount = shortCount + 1 end
        end
    end
    for _ in pairs(bounties) do wanted = wanted + 1 end
    local loot = L()
    return string.format("Dogtown %s · %d inside (%d under the stake) · %d tagged · %d scope(s), %d player(s) armed · %d bounty · polygon %d points (%s) · %d exit(s) · stake %s · loss %d%% (%s to %s), bonus %d%% capped %s/day, reserve %d s",
        enabled and "ON" or "OFF", inside, shortCount, tagged, #scopes, scoped, wanted, polygon and #polygon or 0, polygonSource, #D.exits(),
        money(int(S().minCash, 0)), math.floor((loot.share or 0) * 100 + 0.5), money(loot.min or 0), money(loot.max or 0),
        math.floor((loot.bonus or 0) * 100 + 0.5), money(loot.bonusDailyCap or 0), math.floor((loot.reserveMs or 0) / 1000))
end

-- Lifts every bounty and stake warning (zone off, resource stop).
local function clearRuns(reason)
    for player in pairs(bounties) do D.endStreak(player, reason) end
    streaks, short = {}, {}
end

function D.setEnabled(value, by)
    enabled = value == true and polygon ~= nil
    if not enabled then release(); rosterKey = ""; tags = {}; D.applyTeams(); clearRuns("off") end
    dirty = true
    LightRP.log("dogtown: zone %s by %s", enabled and "ON" or "OFF", tostring(by))
    D.sendConfig()
    LightRP.broadcastState("dogtown")
    return enabled
end

function D.isEnabled() return enabled end

local function surveyCommand(source, args, raw)
    local action = tostring(args[2] or "list"):lower()
    if source == nil or source <= 0 then return false, "The survey needs a player in game." end
    local draft = surveys[source] or { points = {} }
    surveys[source] = draft
    if action == "add" or action == "test" or action == "passage" or action == "exit" then
        local p, heading = positionOf(source)
        if type(p) ~= "table" then return false, "Your position is unknown." end
        if action == "passage" then
            local line = string.format("{ x = %.2f, y = %.2f, z = %.2f, heading = %.1f }", p.x, p.y, p.z, heading or 0)
            LightRP.log("dogtown passage end: %s", line)
            return true, "Passage end: " .. line .. " (also in the server log)."
        end
        if action == "exit" then
            local label = LightRP.joinArgs(args, 3)
            local line = string.format('{ id = "exit_%d", label = "%s", x = %.1f, y = %.1f, z = %.2f, heading = %.1f }, -- surveyed',
                #(Config.exits or {}) + 1, (label ~= "" and label or "Dogtown exit"):gsub('"', "'"), p.x, p.y, p.z, heading or 0)
            if D.contains(p) then return false, "You are inside the polygon: an exit must stand outside the walls." end
            LightRP.log("dogtown exit for server/config/dogtown.lua `exits`: %s", line)
            return true, "Exit: " .. line .. " (also in the server log)."
        end
        local point = { x = p.x, y = p.y }
        if action == "add" then draft.points[#draft.points + 1] = point end
        probe(source, function(place)
            point.district = place.district
            local inPolygon = D.contains(point)
            local text = string.format("%s (%.1f, %.1f): polygon %s, engine district %s", action == "add" and ("Point #" .. #draft.points) or "Here",
                p.x, p.y, inPolygon and "INSIDE" or "outside", place.district ~= "" and place.district or "unknown")
            LightRP.reply(source, raw, true, text)
        end)
        return nil
    elseif action == "undo" then
        table.remove(draft.points)
        return true, #draft.points .. " point(s) in your draft."
    elseif action == "clear" then
        draft.points = {}
        return true, "Draft cleared."
    elseif action == "list" then
        local lines = {}
        for i, p in ipairs(draft.points) do
            lines[i] = string.format("        { x = %.1f, y = %.1f }, -- surveyed%s", p.x, p.y, p.district and p.district ~= "" and (" (" .. p.district .. ")") or "")
        end
        LightRP.log("dogtown survey draft by %s (%d points), paste into server/config/dogtown.lua polygon:\n%s", name(source), #lines, table.concat(lines, "\n"))
        return true, #lines .. " point(s); the polygon lines are in the server log."
    elseif action == "apply" then
        local applied, reason = D.setPolygon(draft.points, "survey by " .. name(source))
        if not applied then return false, reason end
        LightRP.log("dogtown: polygon replaced for this session by %s (%d points)", name(source), #draft.points)
        D.sendConfig() -- the area on everyone's map follows
        return true, "Your " .. #draft.points .. " points are the zone until the next restart. Paste them in the config to keep them (/lightrp.dogtown survey list)."
    elseif action == "reset" then
        local applied, reason = D.setPolygon(Config.polygon, "config")
        if not applied then return false, reason end
        D.sendConfig()
        return true, "Back to the configured polygon."
    end
    return false, "usage: /lightrp.dogtown survey add|undo|clear|list|apply|reset|test|passage|exit [label]"
end

LightRP.command("lightrp.dogtown", { restricted = true, usage = "/lightrp.dogtown status|on|off|survey ..." }, function(source, args, raw)
    local action = tostring(args[1] or "status"):lower()
    if action == "status" then return true, D.status() end
    if action == "on" or action == "off" then
        local by = source and source > 0 and name(source) or "console"
        if action == "on" and not polygon then return false, "No valid polygon: the zone cannot be switched on." end
        D.setEnabled(action == "on", by)
        return true, "Dogtown PvP zone " .. (enabled and "ON" or "OFF") .. " (until the next restart: the config sets the default)."
    end
    if action == "survey" then return surveyCommand(source, args, raw) end
    return false
end)

-- ---------------------------------------------------------------------------
-- Doors held open (open77_doors server exports): claimed, then kept open, unlocked,
-- unsealed and never auto-closing. A stopped resource gives its doors back on its own
-- (open77_doors drops a stopped owner's claims).

local function O() return Config.openDoors or {} end
local doorsLogged = {}  -- door id -> true: claim logged once
local doorsRefused = {} -- door id -> ms of the last logged refusal
local doorsErrorAt = -math.huge
local HELD = { open = true, locked = false, sealed = false, automatic = false, autoClose = false }

local function doorsCall(method, ...)
    if exports == nil then return false, "no_exports" end
    local args = table.pack(...)
    return pcall(function() return exports.open77_doors[method](exports.open77_doors, table.unpack(args, 1, args.n)) end)
end

-- Whether the config wants this door held open: listed by id, or inside an area.
function D.wantsDoor(door)
    if type(door) ~= "table" or door.lift == true or type(door.id) ~= "string" then return false end
    if (door.bucket or 0) ~= (Config.bucket or 0) then return false end
    local cfg = O()
    local id = door.id:upper()
    for _, want in ipairs(cfg.ids or {}) do
        if type(want) == "string" and want:upper() == id then return true end
    end
    local p = door.position
    if type(p) ~= "table" or type(p.x) ~= "number" or type(p.y) ~= "number" then return false end
    for _, a in ipairs(cfg.areas or {}) do
        local r = tonumber(a.radius) or 0
        if r > 0 and (p.x - a.x) ^ 2 + (p.y - a.y) ^ 2 <= r * r then return true end
    end
    return false
end

local function refused(id, what, reason)
    local t = now()
    if t - (doorsRefused[id] or -math.huge) < 60000 then return end
    doorsRefused[id] = t
    LightRP.log("dogtown: door %s not held open (%s: %s)", tostring(id), what, tostring(reason))
end

local function holdDoor(door)
    local settled = door.owner == RESOURCE
    for field, value in pairs(HELD) do
        if door[field] ~= value then settled = false end
    end
    if settled then return true end
    if door.owner ~= RESOURCE then
        local called, claimed, reason = doorsCall("register", { id = door.id, bucket = door.bucket or 0, position = door.position })
        if not called or type(claimed) ~= "table" then refused(door.id, "claim", called and reason or claimed); return false end
        door = claimed
    end
    local called, done, reason = doorsCall("configure", door.id, door.bucket or 0, HELD)
    if not called or done ~= true then refused(door.id, "open", called and reason or done); return false end
    if not doorsLogged[door.id] then
        doorsLogged[door.id] = true
        local p = door.position or {}
        LightRP.log("dogtown: door %s held open at (%.1f, %.1f, %.1f)", door.id, tonumber(p.x) or 0, tonumber(p.y) or 0, tonumber(p.z) or 0)
    end
    return true
end

-- One pass over the doors open77_doors knows in the city bucket. Returns how many
-- wanted doors are held, and how many it looked at.
function D.holdDoors()
    local cfg = O()
    if #(cfg.areas or {}) == 0 and #(cfg.ids or {}) == 0 then return 0, 0 end
    local bucket = Config.bucket or 0
    local offset, pages, held, seen = 0, 0, 0, 0
    repeat
        local called, page = doorsCall("list", bucket, offset, 16)
        if not called or type(page) ~= "table" then
            local t = now()
            if t - doorsErrorAt > 60000 then doorsErrorAt = t; LightRP.log("dogtown: open77_doors unavailable, doors not held open: %s", tostring(page)) end
            return held, seen
        end
        for _, door in ipairs(page.doors or {}) do
            seen = seen + 1
            if D.wantsDoor(door) and holdDoor(door) then held = held + 1 end
        end
        offset, pages = page.nextOffset, pages + 1
    until type(offset) ~= "number" or pages >= 256
    return held, seen
end

CreateThread(function()
    Wait(2000)
    while true do
        local called, err = pcall(D.holdDoors)
        if not called then
            local t = now()
            if t - doorsErrorAt > 60000 then doorsErrorAt = t; LightRP.log("dogtown: holding doors failed: %s", tostring(err)) end
        end
        Wait(math.max(500, int(O().checkMs, 3000)))
    end
end)

-- ---------------------------------------------------------------------------
-- Lifecycle

-- Eddies looted: cash bags picked up (bonus included) and, in transfer mode, the cash
-- taken and the bonus paid beside it. A bounty reward is not loot.
function D.onMoneyChanged(player, wallet, delta, _, kind)
    if wallet == "cash" and (kind == "dogtown_loot" or kind == "dogtown_bonus") and (tonumber(delta) or 0) > 0 then D.record(player, { looted = delta }) end
end

function D.onLifeState(player, phase)
    dirty = true
    if phase == "alive" or phase == "recovering" then
        local m = deathMark[player]
        if m and not m.clearAt then m.clearAt = now() + 15000 end
    elseif phase ~= nil then
        diedSince[player], protectedUntil[player] = true, nil
        -- any death ends a run, in a fight or not (a fall, an NPC)
        if streaks[player] or bounties[player] then D.endStreak(player, "death") end
    end
end

-- Crews changed: their teams follow at once.
function D.onPartyChanged()
    dirty = true
    local called, err = pcall(D.applyTeams)
    if not called then LightRP.log("dogtown: teams update failed: %s", tostring(err)) end
end

local function forget(player)
    if bounties[player] or streaks[player] then D.endStreak(player, "disconnect") end
    presence[player], positions[player], tags[player], hits[player] = nil, nil, nil, nil
    pushed[player], tagPushedAt[player], entered[player], held[player] = nil, nil, nil, nil
    stats[player], surveys[player], lastMismatch[player], roster[player] = nil, nil, nil, nil
    short[player], teams[player], deathMark[player], lastDeathAt[player] = nil, nil, nil, nil
    protectedUntil[player], protectionSpent[player], outsideSince[player], diedSince[player] = nil, nil, nil, nil
    for _, list in pairs(hits) do list[player] = nil end
    dirty = true
end

function D.onDisconnected(player) forget(player); entryChatAt[player] = nil end

local function characterChanged(player)
    if bounties[player] or streaks[player] then D.endStreak(player, "character") end
    tags[player], hits[player], entered[player], short[player] = nil, nil, nil, nil
    dirty = true
    CreateThread(function() D.loadStats(player) end)
end
D.onCharacterLoaded = characterChanged
D.onCharacterActivated = characterChanged
D.onCharacterSwitched = characterChanged

function D.onUiReady(player) pushed[player] = nil; D.sendConfig(player); D.push(player, true) end
function D.onGameplayReady(player) D.sendConfig(player) end

function D.onDatabaseReady()
    local called, err = pcall(migrate)
    if not called then LightRP.log("dogtown: stats migration failed: %s", tostring(err)) end
    for _, raw in ipairs(GetPlayers()) do
        local player = pid(raw)
        if player then D.loadStats(player) end
    end
    D.refreshBoard(true)
end

CreateThread(function()
    Wait(1000)
    -- A previous generation's bounty pins (a reload without a clean stop) go first.
    for _, raw in ipairs(GetPlayers()) do
        local player = pid(raw)
        if player then mapCall("removeBlip", "srv:" .. RESOURCE .. ":" .. BOUNTY_PREFIX .. tostring(player)) end
    end
    D.refreshBoard(true)
    while true do
        local called, err = pcall(D.sweep)
        if not called then
            local t = now()
            if t - lastError > 10000 then lastError = t; LightRP.log("dogtown sweep failed: %s", tostring(err)) end
        end
        local t = now()
        for token, p in pairs(probes) do if p.expires < t then probes[token] = nil end end
        for victim, list in pairs(hits) do
            for attacker, at in pairs(list) do if t - at > (Config.combatTagMs or 20000) * 2 then list[attacker] = nil end end
            if next(list) == nil then hits[victim] = nil end
        end
        local Inv = LightRP.inventory
        for id in pairs(bags) do if not (Inv and Inv.get and Inv.get(id)) then bags[id] = nil end end
        if t - board.at >= ((Config.stats or {}).refreshMs or 60000) then pcall(D.refreshBoard) end
        Wait(Config.sweepMs or 500)
    end
end)

-- Everything this module put in the world goes with it: scopes, teams, bounty pins, bags.
function D.shutdown()
    release()
    pcall(D.applyTeams)
    for player, b in pairs(bounties) do mapCall("removeBlip", b.blip or ("srv:" .. RESOURCE .. ":" .. BOUNTY_PREFIX .. tostring(player))) end
    bounties, streaks, short = {}, {}, {}
    local Inv = LightRP.inventory
    for id, pile in pairs(bags) do
        if Inv and Inv.get and Inv.get(id) == pile then pcall(Inv.removeDrop, pile) end
        bags[id] = nil
    end
end

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    D.shutdown()
    if arbiter and Open77.combat and Open77.combat.offDamage then pcall(Open77.combat.offDamage, arbiter) end
end)

LightRP.log("dogtown: PvP zone %s, polygon of %d points (%s), stake %s, %d exit(s)", enabled and "ON" or "OFF", polygon and #polygon or 0, polygonSource,
    money(int(S().minCash, 0)), #D.exits())
