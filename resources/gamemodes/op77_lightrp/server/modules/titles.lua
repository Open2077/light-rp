-- Prestige titles: a closed catalogue (server/config/titles.lua), earned from
-- sources the server already trusts (reputation, mission clears, raid reports,
-- world bosses, paid activity results, contracts, the Hall of Fame), stored per
-- CHARACTER like the reputation and the Hall of Fame rows. One is shown next to
-- the name. No free text, no money. Rules: docs/dailies-titles.md §6.
--
-- Public (LightRP.titles):
--   shown(playerId)               -> { id, label, rarity } or nil (what others see)
--   forKey("identifier#charKey")  -> label or nil (Hall of Fame rows, offline too)
--   award(playerIdOrKey, titleId) -> true when newly earned (catalogue feats)
--   grant(playerIdOrKey, titleId, { suffix, expiresAt }) -> ok, why (staff)
--   crownDogtown()                -> the weekly King of Dogtown (Dogtown's own stats)
--   revoke(playerIdOrKey, titleId), select(playerId, titleId | "none")
local C, Db = LightRpTitles, LightRP.db
local T = LightRP.module("titles", {})

local defs, order = {}, {}
for _, def in ipairs(C.catalogue) do defs[def.id] = def; order[#order + 1] = def.id end
T.defs = defs

local owned = {}    -- key -> { [titleId] = { suffix, expiresAt } } (online characters)
local chosen = {}   -- key -> { id, suffix, expiresAt } (every character that picked one)
local counters = {} -- key -> { [counter] = n }
local loaded = {}   -- key -> true once read from the database
local keys = {}     -- playerId -> key of the character loaded

Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_titles (
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL, title_id VARCHAR(32) NOT NULL,
    suffix VARCHAR(24) NULL, expires_at BIGINT NULL,
    earned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, character_key, title_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_title_choice (
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL, title_id VARCHAR(32) NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, character_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_title_progress (
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL, counter VARCHAR(32) NOT NULL,
    value INT NOT NULL DEFAULT 0,
    PRIMARY KEY (identifier, character_key, counter)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local function unix()
    local fn = (Open77 and Open77.time and Open77.time.unix) or GetUnixTime
    if type(fn) == "function" then
        local ok, v = pcall(fn)
        if ok and tonumber(v) then return math.floor(tonumber(v)) end
    end
    return 0
end
local function keyOf(id)
    local c = LightRP.characters and LightRP.characters.get(id)
    if c and c.status == "active" and c.identifier and c.key then return c.identifier .. "#" .. c.key, c end
end
local function split(key)
    local identifier, characterKey = tostring(key):match("^(.*)#([^#]+)$")
    return identifier, characterKey
end
-- A player id online, or a stored key: { key, playerId? }.
local function resolve(target)
    if type(target) == "number" then
        local key = keyOf(target)
        return key, key and target or nil
    end
    if type(target) == "string" and split(target) then
        for _, raw in ipairs(GetPlayers()) do
            local id = tonumber(raw)
            if id and keyOf(id) == target then return target, id end
        end
        return target, nil
    end
end
local function ownedOf(key) local o = owned[key]; if not o then o = {}; owned[key] = o end; return o end

-- ---------------------------------------------------------------------------
-- Sources

local function holders(boardKey)
    local HoF = LightRP.hallOfFame
    local cache = HoF and type(HoF.cache) == "function" and HoF.cache()
    local board = cache and cache.boards and cache.boards[boardKey]
    if not board then return nil end
    local set = {}
    for _, row in ipairs(board.rows or {}) do
        if row.rank == 1 and row.key then set[row.key] = true elseif (row.rank or 2) > 1 then break end
    end
    return set
end
T.holders = holders
local function requirementMet(req)
    if not req then return true end
    if req == "worldboss" then
        local W = LightRP.worldBosses
        local ok, list = pcall(function() return W and W.catalogue() end)
        return ok and type(list) == "table" and #list > 0
    end
    if req == "dogtown" then return LightRP.dogtown ~= nil end
    if req:find(".", 1, true) then
        local A = LightRP.activities
        return A ~= nil and type(A.registry) == "table" and A.registry[req] ~= nil
    end
    local M = LightRP.missions
    return M ~= nil and type(M.point) == "function" and M.point(req) ~= nil
end
local function visible(def, earned)
    if earned then return true end
    if def.board then
        local HoF = LightRP.hallOfFame
        local cache = HoF and type(HoF.cache) == "function" and HoF.cache()
        if cache and cache.at and not (cache.boards or {})[def.board] then return false end
    end
    return requirementMet(def.requires)
end

local function labelOf(def, entry)
    local suffix = entry and entry.suffix
    return (suffix and suffix ~= "") and (def.label .. " · " .. suffix) or def.label
end
local function expired(entry) return entry and entry.expiresAt and entry.expiresAt <= unix() end

-- ---------------------------------------------------------------------------
-- Display

local function displayFor(key)
    local ch = key and chosen[key]
    local def = ch and defs[ch.id]
    if not def or C.enabled == false then return nil end
    if def.board then
        local set = holders(def.board)
        if not set or not set[key] then return nil end
    elseif expired(ch) then return nil end
    return def, ch
end
function T.forKey(key)
    local def, ch = displayFor(key)
    return def and labelOf(def, ch) or nil
end
function T.shown(id)
    local key = keyOf(id)
    local def, ch = displayFor(key)
    if not def then return nil end
    return { id = def.id, label = labelOf(def, ch), rarity = def.rarity }
end
-- "Kaito Mori · Legend" for the RP chat.
function T.chatName(id, name)
    local badge = T.shown(id)
    return badge and (name .. " · " .. badge.label) or name
end

-- ---------------------------------------------------------------------------
-- Earning

local function refreshViews(playerId)
    if not playerId then return end
    LightRP.state(playerId, { "titles" })
    local P = LightRP.parties
    if P and type(P.of) == "function" and type(P.refresh) == "function" then
        local p = P.of(playerId)
        if p then pcall(P.refresh, p) end
    end
end
T.push = function(playerId) LightRP.state(playerId, { "titles" }) end

local function store(key, titleId, entry)
    local identifier, characterKey = split(key)
    if not identifier or not Db.ready then return true end
    local ok = Db.run([[INSERT INTO lightrp_titles (identifier, character_key, title_id, suffix, expires_at) VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE suffix = VALUES(suffix), expires_at = VALUES(expires_at)]],
        { identifier, characterKey, titleId, entry.suffix, entry.expiresAt })
    return ok == true
end

local function give(target, titleId, opts, quiet)
    local def = defs[titleId]
    if not def or def.board then return false, "unknown_title" end
    local key, playerId = resolve(target)
    if not key then return false, "unknown_character" end
    local mine = ownedOf(key)
    local had = mine[titleId]
    if had and not expired(had) and not (opts and (opts.suffix or opts.expiresAt)) then return false, "already_earned" end
    local fresh = not had or expired(had) or (opts and opts.suffix and tostring(opts.suffix):sub(1, 24) ~= had.suffix)
    local entry = { suffix = opts and opts.suffix and tostring(opts.suffix):sub(1, 24) or nil,
        expiresAt = opts and tonumber(opts.expiresAt) and math.floor(opts.expiresAt) or nil }
    mine[titleId] = entry
    store(key, titleId, entry)
    if chosen[key] and chosen[key].id == titleId then chosen[key].suffix, chosen[key].expiresAt = entry.suffix, entry.expiresAt end
    if playerId and not quiet and fresh then
        LightRP.notice(playerId, { kind = "success", title = "TITLE UNLOCKED", durationMs = 9000,
            body = string.format("%s (%s). Show it: F1 > Identity > Title.", labelOf(def, entry), (C.rarities[def.rarity] or {}).label or def.rarity) })
    end
    if playerId then refreshViews(playerId) end
    LightRP.log("titles: %s earned %s", key, titleId)
    return true
end
-- Catalogue feats (raid reports, world bosses, contracts): never grantOnly titles.
function T.award(target, titleId, quiet)
    local def = defs[titleId]
    if not def or def.grantOnly then return false, "not_awardable" end
    return give(target, titleId, nil, quiet) == true
end
-- Dogtown and staff: any title but a live one; a suffix and an expiry (unix seconds).
function T.grant(target, titleId, opts) return give(target, titleId, type(opts) == "table" and opts or nil) end
function T.revoke(target, titleId)
    local key, playerId = resolve(target)
    if not key or not defs[titleId] then return false, "unknown" end
    ownedOf(key)[titleId] = nil
    local identifier, characterKey = split(key)
    if Db.ready then Db.run("DELETE FROM lightrp_titles WHERE identifier = ? AND character_key = ? AND title_id = ?", { identifier, characterKey, titleId }) end
    if chosen[key] and chosen[key].id == titleId then
        chosen[key] = nil
        if Db.ready then Db.run("DELETE FROM lightrp_title_choice WHERE identifier = ? AND character_key = ?", { identifier, characterKey }) end
    end
    refreshViews(playerId)
    return true
end

-- Dogtown's lifetime counters of this character (dogtown.lua statsFor), or nil.
local function dogtownTotal(id, key)
    local DT = LightRP.dogtown
    local s = DT and type(DT.statsFor) == "function" and DT.statsFor(id)
    return type(s) == "table" and s.key == key and type(s.total) == "table" and s.total or nil
end

-- Reputation tiers and mission clears (missions.lua), Dogtown stats (dogtown.lua).
function T.sync(id, quiet)
    local M, key = LightRP.missions, keyOf(id)
    if not key then return end
    local tier = M and type(M.tier) == "function" and M.tier(id) or 1
    local dog = dogtownTotal(id, key)
    for _, titleId in ipairs(order) do
        local def = defs[titleId]
        local have = ownedOf(key)[titleId]
        if not have then
            if def.tier and M and tier >= def.tier then give(id, titleId, nil, quiet)
            elseif def.clear and M and type(M.cleared) == "function" and (M.cleared(id, def.clear.point, def.clear.difficulty) or 0) > 0 then
                give(id, titleId, nil, quiet)
            elseif def.dogtown and dog and (tonumber(dog[def.dogtown]) or 0) >= def.count then
                give(id, titleId, nil, quiet)
            end
        end
    end
end

local function bump(key, playerId, counter, delta)
    if not key or not delta or delta <= 0 then return end
    local mine = counters[key] or {}
    counters[key] = mine
    mine[counter] = (mine[counter] or 0) + delta
    local identifier, characterKey = split(key)
    if identifier and Db.ready then
        Db.run([[INSERT INTO lightrp_title_progress (identifier, character_key, counter, value) VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE value = value + VALUES(value)]], { identifier, characterKey, counter, delta })
    end
    for _, titleId in ipairs(order) do
        local def = defs[titleId]
        if def.counter == counter and mine[counter] >= def.count and not ownedOf(key)[titleId] then give(playerId or key, titleId) end
    end
end
T.counter = function(key, counter) return (counters[key] or {})[counter] or 0 end

-- ---------------------------------------------------------------------------
-- Hooks

local function load(id)
    local key = keyOf(id)
    if not key then return end
    if keys[id] and keys[id] ~= key then local old = keys[id]; owned[old], counters[old], loaded[old] = nil, nil, nil end
    keys[id] = key
    if loaded[key] then return end
    loaded[key] = true
    local identifier, characterKey = split(key)
    if Db.ready then
        local ok, rows = Db.read("SELECT title_id, suffix, expires_at FROM lightrp_titles WHERE identifier = ? AND character_key = ?", { identifier, characterKey })
        if ok then
            local mine = ownedOf(key)
            for _, row in ipairs(rows) do
                if defs[row.title_id] then mine[row.title_id] = { suffix = row.suffix, expiresAt = tonumber(row.expires_at) } end
            end
        end
        local okP, prog = Db.read("SELECT counter, value FROM lightrp_title_progress WHERE identifier = ? AND character_key = ?", { identifier, characterKey })
        if okP then
            local mine = counters[key] or {}
            counters[key] = mine
            for _, row in ipairs(prog) do mine[row.counter] = math.max(mine[row.counter] or 0, tonumber(row.value) or 0) end
        end
        local okC, pick = Db.read("SELECT title_id FROM lightrp_title_choice WHERE identifier = ? AND character_key = ?", { identifier, characterKey })
        if okC and pick[1] and defs[pick[1].title_id] then
            local e = ownedOf(key)[pick[1].title_id]
            chosen[key] = { id = pick[1].title_id, suffix = e and e.suffix, expiresAt = e and e.expiresAt }
        end
    end
    T.sync(id, true)
    refreshViews(id)
end
function T.onCharacterLoaded(id) CreateThread(function() load(id) end) end
T.onCharacterActivated = T.onCharacterLoaded
function T.onDatabaseReady()
    local ok, rows = Db.read([[SELECT c.identifier, c.character_key, c.title_id, t.title_id AS owned_id, t.suffix, t.expires_at
        FROM lightrp_title_choice c LEFT JOIN lightrp_titles t
        ON t.identifier = c.identifier AND t.character_key = c.character_key AND t.title_id = c.title_id]])
    if ok then
        for _, row in ipairs(rows) do
            local def = defs[row.title_id]
            -- a live title has no row of its own; any other one must still be owned
            if def and (def.board or row.owned_id ~= nil) then
                local key = row.identifier .. "#" .. row.character_key
                if not chosen[key] then chosen[key] = { id = row.title_id, suffix = row.suffix, expiresAt = tonumber(row.expires_at) } end
            end
        end
    end
    for _, raw in ipairs(GetPlayers()) do local id = tonumber(raw); if id then T.onCharacterLoaded(id) end end
end
function T.onDisconnected(id)
    local key = keys[id]
    keys[id] = nil
    if key then owned[key], counters[key], loaded[key] = nil, nil, nil end
end

-- missions.lua finish(): raid feats from the Chimera's report, then tiers and clears.
function T.onMissionFinished(inst, point, d, success)
    if type(inst) ~= "table" then return end
    local report = type(inst.report) == "table" and inst.report or nil
    if success and not inst.test and point and point.id == "chimera_raid" and d and report then
        local hard = d.id == "hard" or d.id == "critical"
        for _, id in ipairs(inst.members or {}) do
            if hard and report.enraged == false then T.award(id, "overclock_denied") end
            if hard and #(inst.members or {}) == 2 then T.award(id, "two_man_army") end
            if d.id == "critical" and (tonumber(report.downs) or 0) == 0 then T.award(id, "flawless") end
        end
    end
    for _, id in ipairs(inst.members or {}) do T.sync(id) end
end
-- world_bosses.lua finish(): the killing blow and the top share of a boss that went down.
function T.onWorldEventEnded(ev, success)
    if not success or type(ev) ~= "table" then return end
    if ev.lastHit and GetPlayerName(ev.lastHit) then T.award(ev.lastHit, "boss_killer") end
    local top, best = nil, -1
    for id, c in pairs(ev.contrib or {}) do
        if c.eligible and (tonumber(c.score) or 0) > best then top, best = id, tonumber(c.score) or 0 end
    end
    if top and GetPlayerName(top) then T.award(top, "lions_share") end
    for id in pairs(ev.contrib or {}) do if GetPlayerName(id) then T.sync(id) end end
end
-- activity_pay.lua: only paid-eligible results count (no bots, no crew farm, no forfeit).
function T.onActivityResult(id, entry, r, raw, verdict)
    if type(entry) ~= "table" or type(verdict) ~= "table" or verdict.amount == nil then return end
    if entry.ranked == false or (type(raw) == "table" and (raw.unranked == true or raw.test == true)) or (type(r) == "table" and r.unranked == true) then return end
    raw = type(raw) == "table" and raw or {}
    local s = type(raw.stats) == "table" and raw.stats or {}
    local who = entry.identity
    local key = (who and who.identifier and who.characterKey) and (who.identifier .. "#" .. who.characterKey) or keyOf(id)
    local won = (r and r.won) or raw.won
    local placement = (r and r.placement) or raw.placement
    if entry.activity == "arena.duel" and won then
        bump(key, id, "duel_wins", 1)
        local w, l = tonumber(s.roundsWon) or 0, tonumber(s.roundsLost) or 0
        if l >= 1 and l == w - 1 then bump(key, id, "duel_deciders", 1) end
    elseif entry.activity == "race.grid" and placement == 1 and type(verdict.detail) == "table" and (tonumber(verdict.detail.players) or 0) >= 3 then
        bump(key, id, "grid_wins", 1)
    elseif entry.activity == "chase.wanted" then
        bump(key, id, "wanted_extractions", tonumber(s.extractions) or 0)
        bump(key, id, "wanted_arrests", tonumber(s.arrests) or 0)
    elseif entry.activity == "chase.pve" and s.police == "ncpd" and not s.policeBlocked and s.outcome == "escaped"
        and s.how == "extraction" and (tonumber(s.stars) or 0) >= ((defs.ghost or {}).minStars or 3) then
        -- the game's own NCPD only (dailies.lua realNcpd): the extraction with the heat up
        bump(key, id, "pve_hot_extractions", 1)
    end
end
-- dogtown.lua onKill: a credited kill (another account, not a crewmate, past the
-- pair cooldown). bountyStreak > 0: it ended someone's bounty.
function T.onDogtownKill(killer, _, info)
    if type(info) ~= "table" then return end
    local key = keyOf(killer)
    if key and (tonumber(info.bountyStreak) or 0) > 0 then bump(key, killer, "dogtown_bounties", 1) end
    if key then T.sync(killer) end
end

-- ISO 8601 week label ("W45") of a Monday-based week index (dogtown.lua weekIndex).
local function isoWeek(week)
    local thursday = week * 7 -- days since the epoch: the week's Monday (week * 7 - 3), plus 3
    -- civil date of that day (H. Hinnant's days_from_civil, inverted)
    local z = thursday + 719468
    local era = (z >= 0 and z or z - 146096) // 146097
    local doe = z - era * 146097
    local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    local mp = (5 * doy + 2) // 153
    local month = mp < 10 and mp + 3 or mp - 9
    local year = yoe + era * 400 + (month <= 2 and 1 or 0)
    -- days since the epoch of 1 January of that year
    local y = year - 1
    local era1 = (y >= 0 and y or y - 399) // 400
    local yoe1 = y - era1 * 400
    local jan1 = era1 * 146097 + yoe1 * 365 + yoe1 // 4 - yoe1 // 100 + 306 - 719468
    return string.format("W%02d", (thursday - jan1) // 7 + 1)
end
T.isoWeek = isoWeek

-- The weekly crown (a title with `crown = "dogtown.week"`): last week's top credited
-- killer in Dogtown (lightrp_dogtown_stats, the zone's own weekly rows, Hall of Fame
-- exclusions applied) holds it until the end of the current week. Once per week;
-- after a restart the same holder is crowned again quietly. Needs the database.
local crownedWeek = nil
function T.crownDogtown()
    local DT = LightRP.dogtown
    if C.enabled == false or not Db.ready or not DT or type(DT.weekIndex) ~= "function" then return nil end
    local week = DT.weekIndex()
    if crownedWeek == week then return nil end
    local crown
    for _, titleId in ipairs(order) do if defs[titleId].crown == "dogtown.week" then crown = titleId end end
    if not crown then crownedWeek = week; return nil end
    local ok, rows = Db.read([[SELECT identifier, character_key, kills FROM lightrp_dogtown_stats
        WHERE week_index = ? AND kills > 0 ORDER BY kills DESC, looted DESC, deaths ASC LIMIT 10]], { week - 1 })
    if not ok then return nil end
    crownedWeek = week
    local HoF = LightRP.hallOfFame
    for _, row in ipairs(rows) do
        local key = tostring(row.identifier) .. "#" .. tostring(row.character_key)
        if not (HoF and type(HoF.excludedBy) == "function" and HoF.excludedBy(key)) then
            give(key, crown, { suffix = isoWeek(week - 1), expiresAt = (week + 1) * 604800 - 259200 })
            LightRP.log("titles: %s crowned for Dogtown week %d (%d kills)", key, week - 1, tonumber(row.kills) or 0)
            return key
        end
    end
    return nil
end

-- Reputation also comes from activities and world bosses: a light periodic check.
CreateThread(function()
    while true do
        Wait(60000)
        pcall(T.crownDogtown)
        for _, raw in ipairs(GetPlayers()) do
            local id = tonumber(raw)
            if id and keyOf(id) and loaded[keyOf(id)] then pcall(T.sync, id) end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Choosing, and the page state ("titles": about 300 values)

function T.select(id, titleId)
    local key = keyOf(id)
    if not key then return false, "Load your character first." end
    local identifier, characterKey = split(key)
    if titleId == nil or titleId == "" or titleId == "none" then
        chosen[key] = nil
        if Db.ready then Db.run("DELETE FROM lightrp_title_choice WHERE identifier = ? AND character_key = ?", { identifier, characterKey }) end
        refreshViews(id)
        return true, "Title hidden."
    end
    local def = defs[titleId]
    if not def then return false, "Unknown title." end
    local entry = ownedOf(key)[titleId]
    if def.board then
        local set = holders(def.board)
        if not set or not set[key] then return false, "You need to hold rank 1 of that board first." end
    elseif not entry or expired(entry) then
        return false, "You have not earned this title."
    end
    if Db.ready then
        local ok = Db.run([[INSERT INTO lightrp_title_choice (identifier, character_key, title_id) VALUES (?, ?, ?)
            ON DUPLICATE KEY UPDATE title_id = VALUES(title_id)]], { identifier, characterKey, titleId })
        if not ok then return false, "Your title could not be saved. Please try again." end
    end
    chosen[key] = { id = titleId, suffix = entry and entry.suffix, expiresAt = entry and entry.expiresAt }
    refreshViews(id)
    return true, "Title shown: " .. labelOf(def, entry) .. "."
end

function T.view(id)
    if C.enabled == false then return { enabled = false } end
    local key = keyOf(id)
    if not key then return { enabled = true, list = {} } end
    local mine, list, t = ownedOf(key), {}, unix()
    local shownDef = displayFor(key)
    local dog = dogtownTotal(id, key)
    local function progressOf(def)
        if def.counter then return math.min(def.count, (counters[key] or {})[def.counter] or 0) end
        if def.dogtown then return math.min(def.count, dog and tonumber(dog[def.dogtown]) or 0) end
    end
    for _, titleId in ipairs(order) do
        local def = defs[titleId]
        local entry = mine[titleId]
        local earned = entry ~= nil and not expired(entry)
        local held
        if def.board then
            local set = holders(def.board)
            held = set ~= nil and set[key] == true
            earned = held
        end
        if visible(def, earned) then
            list[#list + 1] = { id = def.id, label = labelOf(def, entry), rarity = def.rarity, group = def.group, how = def.how,
                earned = earned or nil, live = def.board and true or nil,
                value = progressOf(def), count = (def.counter or def.dogtown) and def.count or nil,
                expiresInMs = earned and entry and entry.expiresAt and math.max(0, (entry.expiresAt - t) * 1000) or nil }
        end
    end
    local groups = {}
    for _, g in ipairs(C.groups) do groups[#groups + 1] = { id = g.id, label = g.label } end
    return { enabled = true, shown = shownDef and shownDef.id or nil, chosen = chosen[key] and chosen[key].id or nil,
        groups = groups, list = list }
end
LightRP.stateProvider("titles", T.view)

LightRP.action("titles.select", function(id, payload)
    local ok, text = T.select(id, type(payload) == "table" and payload.id and tostring(payload.id) or "none")
    LightRP.result(id, ok, text, "titles.select")
end)

-- Staff: /lightrp.titles grant|revoke <playerId> <titleId> [suffix] [days]
LightRP.command("lightrp.titles", { restricted = true, usage = "/lightrp.titles grant|revoke <playerId> <titleId> [suffix] [days]" }, function(_, args)
    local verb, target, titleId = args[1], tonumber(args[2]), args[3]
    if (verb ~= "grant" and verb ~= "revoke") or not target or not defs[titleId or ""] then return false end
    if verb == "revoke" then
        local ok, why = T.revoke(target, titleId)
        return ok, ok and ("Revoked " .. titleId .. ".") or tostring(why)
    end
    local days = tonumber(args[5])
    local ok, why = T.grant(target, titleId, { suffix = args[4] ~= "-" and args[4] or nil, expiresAt = days and (unix() + math.floor(days * 86400)) or nil })
    return ok == true, ok and ("Granted " .. titleId .. ".") or tostring(why)
end)
