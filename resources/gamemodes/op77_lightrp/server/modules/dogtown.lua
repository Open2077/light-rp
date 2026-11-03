-- Dogtown: the open PvP zone of Light RP (server/config/dogtown.lua).
--
-- Global friendly fire stays off (the platform default: player damage between two
-- players is refused before any Lua arbiter runs). Every sweep, the players who
-- qualify get a combat scope (Open77.combat.createScope) in the city bucket:
--
--   qualifies = character active, in the city bucket, not owned by an activity or a
--               mission, alive or recovering, zone switched on, AND (inside the
--               polygon OR combat-tagged)
--
-- A hit between two scoped players tags both for `combatTagMs`; a tagged player who
-- steps out keeps the scope until the tag runs out. The damage arbiter below refuses
-- a hit between two scoped players when one no longer qualifies (the next sweep
-- would drop them; the arbiter closes the gap). It never allows anything: safe zones,
-- downed attackers, activities keep refusing as before (the first refusal wins).
--
-- A kill between two scoped players drops part of the victim's pocket cash as a
-- sealed bag (inventory.lua, Inv.dropCash) or moves it to the killer, through the
-- money ledger. Stats: kills, deaths, eddies looted per character, per week and in
-- total. No reputation.
--
--   LightRP.dogtown.contains({ x, y })      the polygon test
--   LightRP.dogtown.qualifies(playerId)     the roster rule (above)
--   LightRP.dogtown.lootAmount(cash)        the share, cap and threshold
--   LightRP.dogtown.verdict(killer, victim) nil (credited) or a reason
local Config = LightRpDogtown
local Db = LightRP.db
local D = LightRP.module("dogtown", {})
local NET, REPORT = "op77_lightrp:dogtown", "op77_lightrp:dogtown:report"

local enabled = Config.enabled ~= false
local polygon, bbox, polygonSource = nil, nil, "config"
local presence = {}   -- playerId -> true/false: inside the polygon (last fresh read)
local positions = {}  -- playerId -> last position read (sorting the roster)
local tags = {}       -- playerId -> tag end (ms)
local hits = {}       -- victim -> { [attacker] = ms }
local roster = {}     -- playerId -> group index: PvP granted at the last sweep
local scopes = {}     -- scope ids this module holds
local rosterKey, rebuildAt, dirty = "", 0, true
local held = {}       -- playerId -> ms: left out after a refused grant
local pushed = {}     -- playerId -> last presence key sent to the page
local tagPushedAt = {}
local entered = {}    -- playerId -> was inside (eligible) at the last sweep
local entryChatAt = {}
local cooldowns = {}  -- "killer>victim" character keys -> ms of the last credited kill
local stats = {}      -- playerId -> { key, name, week, weekStats, total }
local memory = {}     -- characterKey -> { name, weeks = { [week] = stats }, total } (no database)
local board = { week = 0, rows = {}, at = -math.huge }
local probes, probeSeq = {}, 0
local surveys = {}    -- staff playerId -> { points = { { x, y, district } } }
local lastError, lastMismatch = -math.huge, {}

local function now() return LightRP.nowMs() end
local function pid(value) local n = tonumber(value); if n and n > 0 then return math.tointeger(n) or n end end
local function money(n) return LightRP.money and LightRP.money.format(n) or ("€$ " .. tostring(n)) end
local function name(player) return LightRP.characters.displayName(player) end
local function L() return Config.loot or {} end

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

function D.qualifies(player)
    return D.eligible(player) and (presence[player] == true or D.tagged(player))
end

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
-- The page: presence, tag, rules, stats

local function presenceKey(player)
    return table.concat({ tostring(enabled), tostring(D.inside(player)), tostring(D.tagged(player)), tostring(roster[player] ~= nil) }, ":")
end

function D.push(player, force)
    local key = presenceKey(player)
    if not force and pushed[player] == key then return end
    pushed[player] = key
    LightRP.state(player, "dogtown")
end

local function emptyStats() return { kills = 0, deaths = 0, looted = 0 } end
local function copyStats(s) return { kills = s.kills or 0, deaths = s.deaths or 0, looted = s.looted or 0 } end

function D.weekIndex()
    local unix = Open77.time and Open77.time.unix and Open77.time.unix() or os.time()
    -- The Unix epoch is a Thursday: +3 days puts week boundaries on Monday 00:00 UTC.
    return math.floor((unix + 259200) / 604800)
end

local function statsOf(player)
    local s = stats[player]
    if not s then return nil end
    local week = D.weekIndex()
    if s.week ~= week then s.week, s.weekStats = week, emptyStats() end
    return s
end

LightRP.stateProvider("dogtown", function(player)
    local loot = L()
    local s = statsOf(player)
    local tag = D.tagRemainingMs(player)
    return {
        enabled = enabled, label = Config.label or "Dogtown",
        inside = D.inside(player), tagged = enabled and tag > 0, tagEndsInMs = enabled and tag or 0,
        armed = roster[player] ~= nil,
        rules = { mode = loot.mode or "bag", share = loot.share or 0, max = loot.max or 0, minCash = loot.minCash or 0,
            tagSeconds = math.floor((Config.combatTagMs or 20000) / 1000), pairCooldownMinutes = math.floor((loot.pairCooldownMs or 0) / 60000) },
        mine = s and { week = copyStats(s.weekStats), total = copyStats(s.total) } or { week = emptyStats(), total = emptyStats() },
        top = board.rows, week = board.week,
    }
end)

-- ---------------------------------------------------------------------------
-- Sweep: presence, tags, grants, page

function D.sweep(force)
    local t = now()
    local list = {}
    for _, raw in ipairs(GetPlayers()) do
        local player = pid(raw)
        if player then
            D.locate(player)
            if tags[player] and tags[player] <= t then tags[player] = nil end
            if held[player] and held[player] <= t then held[player] = nil end
            if D.qualifies(player) and capable(player) and not held[player] then list[#list + 1] = player end
            local inside = D.inside(player)
            if inside and not entered[player] then D.entered(player) end
            entered[player] = inside
        end
    end
    local rebuild = force or dirty or t >= rebuildAt
    dirty = false
    if rebuild then rebuildAt = t + (Config.refreshScopesMs or 10000) end
    D.applyRoster(list, rebuild)
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
    local cash = LightRP.money and LightRP.money.get and LightRP.money.get(player)
    local line = "DOGTOWN: no law past the walls, anyone can kill you."
    if type(cash) == "table" and tonumber(cash.cash) then line = line .. " You carry " .. money(cash.cash) .. " in cash." end
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
        updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (identifier, character_key, week_index),
        KEY ix_dogtown_week (week_index, kills)
    )
]])

local UPSERT = [[INSERT INTO lightrp_dogtown_stats (identifier, character_key, week_index, character_name, kills, deaths, looted)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE kills = kills + VALUES(kills), deaths = deaths + VALUES(deaths), looted = looted + VALUES(looted),
        character_name = VALUES(character_name)]]

local function characterKey(c) return tostring(c.identifier) .. "#" .. tostring(c.key or "default") end

local function memoryOf(key, label)
    local m = memory[key]
    if not m then m = { name = label, weeks = {}, total = emptyStats() }; memory[key] = m end
    if label then m.name = label end
    return m
end

-- Loads a character's counters (database, or this session's memory).
function D.loadStats(player)
    local c = LightRP.characters.get(player)
    if not c or c.status ~= "active" or not c.identifier then stats[player] = nil; return end
    local key, week = characterKey(c), D.weekIndex()
    local entry = { key = key, name = name(player), week = week, weekStats = emptyStats(), total = emptyStats() }
    if Db.ready then
        local read, rows = Db.read("SELECT week_index, kills, deaths, looted FROM lightrp_dogtown_stats WHERE identifier = ? AND character_key = ? AND week_index IN (0, ?)",
            { c.identifier, c.key or "default", week })
        if read then
            for _, row in ipairs(rows) do
                local s = { kills = tonumber(row.kills) or 0, deaths = tonumber(row.deaths) or 0, looted = tonumber(row.looted) or 0 }
                if tonumber(row.week_index) == 0 then entry.total = s else entry.weekStats = s end
            end
        end
    else
        local m = memoryOf(key, entry.name)
        entry.total = copyStats(m.total)
        entry.weekStats = copyStats(m.weeks[week] or emptyStats())
    end
    if LightRP.characters.get(player) == c then stats[player] = entry; LightRP.state(player, "dogtown") end
end

function D.statsFor(player) return statsOf(player) end

-- Adds to a character's counters: { kills, deaths, looted }.
function D.record(player, delta)
    local c = LightRP.characters.get(player)
    if not c or not c.identifier then return end
    local key, week, label = characterKey(c), D.weekIndex(), name(player)
    local s = statsOf(player)
    if not s or s.key ~= key then
        s = { key = key, name = label, week = week, weekStats = emptyStats(), total = emptyStats() }
        stats[player] = s
    end
    local k, d, l = delta.kills or 0, delta.deaths or 0, delta.looted or 0
    for _, bucket in ipairs({ s.weekStats, s.total }) do
        bucket.kills, bucket.deaths, bucket.looted = bucket.kills + k, bucket.deaths + d, bucket.looted + l
    end
    local m = memoryOf(key, label)
    m.weeks[week] = m.weeks[week] or emptyStats()
    for _, bucket in ipairs({ m.weeks[week], m.total }) do
        bucket.kills, bucket.deaths, bucket.looted = bucket.kills + k, bucket.deaths + d, bucket.looted + l
    end
    if Db.ready then
        CreateThread(function()
            Db.run(UPSERT, { c.identifier, c.key or "default", 0, label, k, d, l })
            Db.run(UPSERT, { c.identifier, c.key or "default", week, label, k, d, l })
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
            return a.deaths < b.deaths
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

-- ---------------------------------------------------------------------------
-- Kills and loot

local function crewmates(a, b)
    local P = LightRP.parties
    if not P or type(P.of) ~= "function" then return false end
    local pa = P.of(a)
    return pa ~= nil and pa == P.of(b)
end

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

function D.lootAmount(cash)
    local loot = L()
    cash = math.floor(tonumber(cash) or 0)
    if cash <= 0 or cash < (loot.minCash or 0) then return 0 end
    local amount = math.floor(cash * (tonumber(loot.share) or 0))
    if tonumber(loot.max) and loot.max > 0 then amount = math.min(amount, math.floor(loot.max)) end
    return math.max(0, math.min(amount, cash))
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

local function retry(fn)
    local loot = L()
    local okay, result
    for _ = 0, math.max(0, math.tointeger(loot.retries) or 10) do
        okay, result = fn()
        if okay or result ~= "busy" then return okay, result end
        Wait(loot.retryMs or 300)
    end
    return okay, result
end

local NO_LOOT = {
    same_account = "Same account: no cash taken, no kill scored.",
    crewmate = "Crewmate: no cash taken, no kill scored.",
    cooldown = "You already took them down in the last %d minutes: no cash, no kill scored.",
}

function D.onKill(victim, killer, context)
    local loot = L()
    local killerName, victimName = name(killer), name(victim)
    D.record(victim, { deaths = 1 })
    local reason, pair = D.verdict(killer, victim)
    if reason then
        local text = NO_LOOT[reason]
        if text then
            LightRP.notice(killer, { kind = "warning", title = "Dogtown", body = string.format(text, math.floor((loot.pairCooldownMs or 0) / 60000)), durationMs = 7000 })
        end
        LightRP.notice(victim, { kind = "warning", title = "Killed in Dogtown", body = "Killed by " .. killerName .. ". You kept your cash.", durationMs = 8000 })
        return reason
    end
    cooldowns[pair] = now()
    D.record(killer, { kills = 1 })
    local inv = LightRP.inventory and LightRP.inventory.player(victim)
    local cash = inv and LightRP.inventory.cashOf(inv) or 0
    local amount = D.lootAmount(cash)
    if amount <= 0 then
        LightRP.notice(killer, { kind = "info", title = "Dogtown kill", body = victimName .. " carried less than " .. money(loot.minCash or 0) .. ": nothing to take.", durationMs = 7000 })
        LightRP.notice(victim, { kind = "warning", title = "Killed in Dogtown", body = "Killed by " .. killerName .. ". You kept your cash.", durationMs = 8000 })
        return "too_little"
    end
    local Inv = LightRP.inventory
    local placed, result
    if (loot.mode or "bag") == "bag" then
        local p = type(context) == "table" and context.position or nil
        if type(p) ~= "table" or not tonumber(p.x) or not tonumber(p.y) or not tonumber(p.z) then p = Open77.players.position(victim) end
        if type(p) == "table" then
            local position = { x = tonumber(p.x), y = tonumber(p.y), z = tonumber(p.z), bucket = Config.bucket or 0 }
            placed, result = retry(function()
                return Inv.dropCash(victim, amount, position, {
                    label = (loot.bagLabel or "Cash bag") .. " · " .. money(amount), prompt = "Pick up", marker = loot.bagMarker,
                    ledger = { kind = "dogtown_loot", note = "Cash bag picked up in Dogtown", counterparty = victimName, direction = "in", skip = inv.id },
                    ownerLedger = { kind = "dogtown_loss", note = "Cash dropped on death in Dogtown", counterparty = killerName, direction = "out" },
                })
            end)
            if placed then
                LightRP.notice(killer, { kind = "money", title = "Dogtown kill", body = victimName .. " dropped " .. money(amount) .. " in cash where they fell. Grab the bag before someone else does.", durationMs = 9000 })
                LightRP.notice(victim, { kind = "warning", title = "Killed in Dogtown", body = "Killed by " .. killerName .. ". You dropped " .. money(amount) .. " in cash where you fell. Your bank is safe.", durationMs = 9000 })
                LightRP.log("dogtown: %s killed %s, cash bag %d at (%.1f, %.1f, %.1f)", killerName, victimName, amount, position.x, position.y, position.z)
                return "bag", amount
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
        LightRP.notice(killer, { kind = "money", title = "Dogtown kill", body = "You took " .. money(amount) .. " from " .. victimName .. ".", durationMs = 9000 })
        LightRP.notice(victim, { kind = "warning", title = "Killed in Dogtown", body = killerName .. " took " .. money(amount) .. " from your pocket. Your bank is safe.", durationMs = 9000 })
        LightRP.log("dogtown: %s killed %s, took %d", killerName, victimName, amount)
        return "transfer", amount
    end
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
    local inside, tagged, scoped = 0, 0, 0
    for _, raw in ipairs(GetPlayers()) do
        local player = pid(raw)
        if player then
            if D.inside(player) then inside = inside + 1 end
            if D.tagged(player) then tagged = tagged + 1 end
            if roster[player] then scoped = scoped + 1 end
        end
    end
    local loot = L()
    return string.format("Dogtown %s · %d inside · %d tagged · %d scope(s), %d player(s) armed · polygon %d points (%s) · loot %s %d%% max %s from %s",
        enabled and "ON" or "OFF", inside, tagged, #scopes, scoped, polygon and #polygon or 0, polygonSource,
        loot.mode or "bag", math.floor((loot.share or 0) * 100 + 0.5), money(loot.max or 0), money(loot.minCash or 0))
end

function D.setEnabled(value, by)
    enabled = value == true and polygon ~= nil
    if not enabled then release(); rosterKey = ""; tags = {} end
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
    if action == "add" or action == "test" or action == "passage" then
        local p, heading = positionOf(source)
        if type(p) ~= "table" then return false, "Your position is unknown." end
        if action == "passage" then
            local line = string.format("{ x = %.2f, y = %.2f, z = %.2f, heading = %.1f }", p.x, p.y, p.z, heading or 0)
            LightRP.log("dogtown passage end: %s", line)
            return true, "Passage end: " .. line .. " (also in the server log)."
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
    return false, "usage: /lightrp.dogtown survey add|undo|clear|list|apply|reset|test|passage"
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
-- Lifecycle

function D.onMoneyChanged(player, wallet, delta, _, kind)
    if wallet == "cash" and kind == "dogtown_loot" and (tonumber(delta) or 0) > 0 then D.record(player, { looted = delta }) end
end

function D.onLifeState() dirty = true end

local function forget(player)
    presence[player], positions[player], tags[player], hits[player] = nil, nil, nil, nil
    pushed[player], tagPushedAt[player], entered[player], held[player] = nil, nil, nil, nil
    stats[player], surveys[player], lastMismatch[player], roster[player] = nil, nil, nil, nil
    for _, list in pairs(hits) do list[player] = nil end
    dirty = true
end

function D.onDisconnected(player) forget(player); entryChatAt[player] = nil end

local function characterChanged(player)
    tags[player], hits[player], entered[player] = nil, nil, nil
    dirty = true
    CreateThread(function() D.loadStats(player) end)
end
D.onCharacterLoaded = characterChanged
D.onCharacterActivated = characterChanged
D.onCharacterSwitched = characterChanged

function D.onUiReady(player) pushed[player] = nil; D.sendConfig(player); D.push(player, true) end
function D.onGameplayReady(player) D.sendConfig(player) end

function D.onDatabaseReady()
    for _, raw in ipairs(GetPlayers()) do
        local player = pid(raw)
        if player then D.loadStats(player) end
    end
    D.refreshBoard(true)
end

CreateThread(function()
    Wait(1000)
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
        if t - board.at >= ((Config.stats or {}).refreshMs or 60000) then pcall(D.refreshBoard) end
        Wait(Config.sweepMs or 500)
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end
    release()
    if arbiter and Open77.combat and Open77.combat.offDamage then pcall(Open77.combat.offDamage, arbiter) end
end)

LightRP.log("dogtown: PvP zone %s, polygon of %d points (%s)", enabled and "ON" or "OFF", polygon and #polygon or 0, polygonSource)
