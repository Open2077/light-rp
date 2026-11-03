-- The Hall of Fame at The Crossing (server/config/halloffame.lua): a real board
-- beside the activities terminal. ALT + click on it (client/core/halloffame.lua) or
-- E in front of it opens the `halloffame` dialog of the Light RP page: the best
-- characters in PvP, races, PvE, missions and wealth, with the viewer's own rank.
--
-- Every board is computed here, from what the other modules already store, and
-- cached: every cache.refreshMs, and on a player's REFRESH at most once per
-- cache.playerRefreshMs. Opening the panel or changing its tab reads the cache only.
--
--   PvP / PvE   lightrp_activity_stats totals (server/modules/activities.lua), or its
--               session rows without a database (LightRP.activities.memoryRows)
--   races       lightrp_activity_stats best times on each race's current course
--   missions    lightrp_mission_rep, lightrp_mission_clears (server/modules/missions.lua)
--   wealth      lightrp_wallets.bank + the cash item of lightrp_inventories (economy.lua)
--
-- Only character names leave this file: never an account identifier. The dialog
-- is one plain net event, kept under the client's 1024-value limit per tab.
--
-- Another module adds a board without editing this one:
--   LightRP.hallOfFame.registerBoard("dogtown.kills", { tab = "pvp", title = "DOGTOWN KILLS", unit = "kills",
--       subtitle = "This week in Dogtown", provider = function(ctx)
--           -- runs in a thread at each refresh: ctx.db, ctx.read(sql, params), ctx.keyOf(identifier, characterKey)
--           return { { identifier = "...", characterKey = "default", value = 12, sort = { 12, -3 }, detail = "3 deaths" } }
--       end })
-- Rows rank by `sort` (default { value }), highest first (`ascending = true`: lowest).
--
-- Staff and test characters are on no board (config `exclude`): one filter in
-- HoF.refresh, after every provider, before the ranking (see "Exclusions").
local C = LightRpHallOfFame
local Db = LightRP.db
local E = LightRpEvents
local HoF = LightRP.module("hallOfFame", {})

local SELF = type(GetCurrentResourceName) == "function" and GetCurrentResourceName() or "op77_lightrp"
local POINT = "halloffame.board"
local VALUE_LIMIT = 900 -- the client host drops a plain event over 1024 JSON values (framework.lua)
local TABS = { "overview", "pvp", "races", "pve", "missions", "wealth" }
local TAB_SET = {}
for _, tab in ipairs(TABS) do TAB_SET[tab] = true end
local UNITS = { wins = true, kills = true, time = true, eddies = true, rep = true, count = true, clears = true, points = true }

local boards, order = {}, {}       -- key -> definition, keys in registration order
local cache = { at = nil, boards = {}, database = false }
local refreshing, lastRefreshAt = false, nil
local playerAsked, helloAt = {}, {}
local board = { prop = nil, position = nil, heading = nil }
HoF.board = board

local function now() return LightRP.nowMs() end
local function cfg(path, default) local v = C; for part in path:gmatch("[^.]+") do v = type(v) == "table" and v[part] or nil end; if v == nil then return default end; return v end
local function ownerKey(identifier, characterKey) return tostring(identifier) .. "#" .. tostring(characterKey) end
HoF.keyOf = ownerKey

local function fullName(first, last)
    if type(first) ~= "string" or first == "" then return nil end
    local name = (type(last) == "string" and last ~= "") and (first .. " " .. last) or first
    return name:sub(1, 64)
end
local function cleanName(value)
    if type(value) ~= "string" then return nil end
    value = value:gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" or value == "?" then return nil end
    return value:sub(1, 64)
end

-- ---------------------------------------------------------------------------
-- The board: where it stands, the prop, the E point

local function hub() return type(LightRpActivities) == "table" and LightRpActivities.hub or nil end
function HoF.hubName() local H = hub(); return H and H.name or "The Crossing" end

-- Its surveyed position, or its offset along the hub's heading (as the terminals,
-- activities_hub.lua). Heading: degrees about +Z, counter-clockwise seen from above,
-- 0 facing +Y; without one the screen faces the arrival point.
function HoF.placement()
    local B = C.board or {}
    local H = hub() or { center = { x = 0, y = 0, z = 0 }, heading = 0 }
    local pos
    if type(B.position) == "table" then
        pos = { x = tonumber(B.position.x) or 0, y = tonumber(B.position.y) or 0, z = tonumber(B.position.z) or 0 }
    else
        local o = B.offset or {}
        local h = math.rad(tonumber(H.heading) or 0)
        local forward, right = tonumber(o.forward) or 0, tonumber(o.right) or 0
        pos = { x = H.center.x - math.sin(h) * forward + math.cos(h) * right,
            y = H.center.y + math.cos(h) * forward + math.sin(h) * right, z = H.center.z + (tonumber(o.up) or 0) }
    end
    local heading = tonumber(B.heading)
    if heading == nil then
        local dx, dy = H.center.x - pos.x, H.center.y - pos.y
        heading = (dx * dx + dy * dy < 0.01) and (tonumber(H.heading) or 0) or math.deg(math.atan(-dx, dy))
    end
    return pos, heading % 360
end

-- The E point stands in front of the screen, toward the people reading it.
function HoF.pointOf(pos, heading)
    local d = tonumber(cfg("board.interact.distance", 1.8)) or 1.8
    local h = math.rad(heading)
    return { x = pos.x - math.sin(h) * d, y = pos.y + math.cos(h) * d, z = pos.z }
end

local function registerPoint()
    local I = cfg("board.interact", {})
    LightRP.interaction(POINT, { position = HoF.pointOf(board.position, board.heading), radius = tonumber(I.radius) or 1.6,
        bucket = cfg("board.bucket", 0), label = I.label or "Hall of Fame", prompt = I.prompt or "Open the Hall of Fame",
        key = "E", marker = I.marker, ring = false })
end

local function boardInfo() return { prop = board.prop or false, position = board.position } end
local function sendBoard(target) TriggerClientEvent(E.net.hallOfFameBoard, target, boardInfo()) end
HoF.boardInfo = boardInfo

-- A hot reload may leave the previous generation's board where the new one goes.
local function sweepOrphans(pos)
    if type(Open77.props.all) ~= "function" then return end
    local ok, list = pcall(Open77.props.all, cfg("board.bucket", 0))
    if not ok or type(list) ~= "table" then return end
    for _, s in ipairs(list) do
        local p = type(s) == "table" and (type(s.position) == "table" and s.position or s) or nil
        if p and s.resource == SELF and s.model == C.board.model and tostring(s.id) ~= board.prop
            and type(p.x) == "number" and type(p.y) == "number" and (p.x - pos.x) ^ 2 + (p.y - pos.y) ^ 2 < 25 then
            pcall(Open77.props.remove, tostring(s.id))
        end
    end
end

-- Puts the prop where `board` says: moved when it exists, created otherwise.
local function placeProp()
    if type(Open77.props) ~= "table" then return false, "props_unavailable" end
    local B = C.board
    if board.prop then
        local ok = Open77.props.setTransform(board.prop, { position = board.position, yaw = board.heading })
        if ok then return true end
        board.prop = nil -- gone: make a new one
    end
    sweepOrphans(board.position)
    local id, why = Open77.props.create({ model = B.model, position = { x = board.position.x, y = board.position.y, z = board.position.z },
        yaw = board.heading, scale = B.scale, bucket = B.bucket or 0, physics = B.collision and "static" or "none",
        collision = B.collision == true, streamingRadius = B.streamingRadius })
    if not id then return false, why end
    board.prop = tostring(id)
    return true
end
HoF.placeProp = placeProp

local function setPlacement(pos, heading)
    board.position, board.heading = pos, heading % 360
    registerPoint()
end

-- ---------------------------------------------------------------------------
-- Boards

-- def = { tab, title, subtitle?, unit, ascending?, overview?, provider(ctx) -> rows[, meta] }
function HoF.registerBoard(key, def)
    if type(key) ~= "string" or not key:match("^[%w][%w_%.%-]*$") or #key > 48 then return false, "invalid key" end
    if type(def) ~= "table" or type(def.provider) ~= "function" then return false, "provider required" end
    if not TAB_SET[def.tab] or def.tab == "overview" then return false, "invalid tab" end
    if type(def.title) ~= "string" or def.title == "" then return false, "title required" end
    local copy = {}
    for k, v in pairs(def) do copy[k] = v end
    copy.key = key
    copy.unit = UNITS[def.unit] and def.unit or "count"
    if not boards[key] then order[#order + 1] = key end
    boards[key] = copy
    return true
end
function HoF.unregisterBoard(key)
    if not boards[key] then return false end
    boards[key] = nil
    for i, k in ipairs(order) do if k == key then table.remove(order, i) break end end
    cache.boards[key] = nil
    return true
end

-- Lexicographic over `sort`; nil when equal (a shared rank).
local function compare(a, b, ascending)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then if ascending then return x < y end return x > y end
    end
    return nil
end
-- Competition ranking (1, 1, 3); equal rows by name, then key, so the order is stable.
function HoF.rank(rows, ascending)
    table.sort(rows, function(x, y)
        local c = compare(x.sort, y.sort, ascending)
        if c ~= nil then return c end
        if x.name ~= y.name then return x.name < y.name end
        return x.key < y.key
    end)
    local byKey = {}
    for i, row in ipairs(rows) do
        row.rank = (i > 1 and compare(row.sort, rows[i - 1].sort, ascending) == nil) and rows[i - 1].rank or i
        byKey[row.key] = i
    end
    return rows, byKey
end

-- A provider's rows: a name for each (from the characters, never an identifier),
-- numbers only, one row per character.
local function normalizeRows(ctx, rows)
    local out, seen = {}, {}
    for _, r in ipairs(rows) do
        if type(r) == "table" then
            local key = type(r.key) == "string" and r.key or (r.identifier ~= nil and r.characterKey ~= nil and ownerKey(r.identifier, r.characterKey)) or nil
            local value = tonumber(r.value)
            local name = key and ctx.nameOf(key, r.name)
            if key and name and value and value == value and not seen[key] then
                seen[key] = true
                local sort = {}
                if type(r.sort) == "table" then for i, v in ipairs(r.sort) do sort[i] = tonumber(v) or 0 end end
                if #sort == 0 then sort[1] = value end
                out[#out + 1] = { key = key, name = name, value = value, sort = sort,
                    detail = type(r.detail) == "string" and r.detail ~= "" and r.detail:sub(1, 60) or nil }
            end
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Exclusions: staff and test characters are on no board (C.exclude)
--
-- A row's owner is "<account>#<characterKey>"; the account is the Open77 account id
-- (GetPlayerIdentifier), the same `userId` an acl.jsonc principal names. Staff are
-- Light RP's own test (LightRP.staff.isStaff, the page's Staff tab), which the ACL
-- answers for players online only: a resource cannot read acl.jsonc. So every staff
-- account seen online is remembered in the resource's kvp store (data/, kept over
-- restarts, as the guide's placement) and stays excluded offline; one seen online
-- without the rights any more is forgotten. The test list of the staff command
-- lives in the same store, beside the config's lists.

local KVP_STAFF, KVP_TEST = "halloffame.staff.", "halloffame.exclude."
local saved = { staff = {}, tests = {}, loaded = false } -- account -> label; subject -> label
HoF.saved = saved
local lastNames = {} -- the last rebuild's character names, to label the staff's listing

local function store(fn, ...)
    local K = type(Open77) == "table" and Open77.kvp or nil
    if type(K) ~= "table" or type(K[fn]) ~= "function" then return false, "kvp_unavailable" end
    local ok, result, why = pcall(K[fn], ...)
    if not ok then return false, tostring(result) end
    return result, why
end

-- Read once (again later if the store did not answer); memory wins over a late read.
local function loadSaved()
    if saved.loaded then return end
    local done = true
    for prefix, into in pairs({ [KVP_STAFF] = saved.staff, [KVP_TEST] = saved.tests }) do
        local list = store("find", prefix, 4096)
        if type(list) == "table" then
            for _, e in ipairs(list) do
                local subject = type(e) == "table" and type(e.key) == "string" and e.key:sub(#prefix + 1) or ""
                if subject ~= "" and into[subject] == nil then into[subject] = type(e.value) == "string" and e.value or "" end
            end
        else done = false end
    end
    saved.loaded = done
end

local function accountOf(key) return type(key) == "string" and key:match("^(.*)#[^#]*$") or nil end
HoF.accountOf = accountOf
local function listed(list, value)
    for _, v in ipairs(type(list) == "table" and list or {}) do if tostring(v) == value then return true end end
    return false
end

-- Why `key` (a character "<account>#<characterKey>", or an account) is off the boards:
-- the list that holds it, or nil.
function HoF.excludedBy(key)
    if type(key) ~= "string" or key == "" then return nil end
    loadSaved()
    local X = cfg("exclude", {})
    local account = accountOf(key) or key
    if X.tests ~= false then
        if saved.tests[key] then return "test list" end
        if saved.tests[account] then return "test list (account)" end
        if listed(X.characters, key) or listed(X.accounts, key) or listed(X.characters, account) or listed(X.accounts, account) then
            return "test (server/config/halloffame.lua)"
        end
    end
    if X.staff ~= false then
        if listed(X.staffAccounts, account) then return "staff (exclude.staffAccounts)" end
        if saved.staff[account] then return "staff" end
    end
    return nil
end

-- The filter of one rebuild: sets built once, then key -> "staff" | "test" | nil.
local function exclusions()
    loadSaved()
    local X = cfg("exclude", {})
    local tests, staff = {}, {}
    local function add(set, list) for _, v in ipairs(type(list) == "table" and list or {}) do set[tostring(v)] = true end end
    if X.tests ~= false then
        add(tests, X.characters); add(tests, X.accounts)
        for subject in pairs(saved.tests) do tests[subject] = true end
    end
    if X.staff ~= false then
        add(staff, X.staffAccounts)
        for account in pairs(saved.staff) do staff[account] = true end
    end
    return function(key)
        if type(key) ~= "string" then return nil end
        local account = accountOf(key) or key
        if tests[key] or tests[account] then return "test" end
        if staff[account] then return "staff" end
        return nil
    end
end
HoF.exclusions = exclusions

local function dropExcluded(rows, excluded, dropped)
    local out = {}
    for _, r in ipairs(rows) do
        if excluded(r.key) then dropped[r.key] = true else out[#out + 1] = r end
    end
    return out
end

local function accountOfPlayer(playerId, c)
    if c == nil and LightRP.characters then c = LightRP.characters.get(playerId) end
    local id = type(c) == "table" and c.identifier or nil
    if id == nil and type(GetPlayerIdentifier) == "function" then id = GetPlayerIdentifier(playerId) end
    if id == nil or id == "" then return nil end
    return tostring(id)
end
-- For the staff's listing only (never in a player's payload).
local function labelOf(playerId, c)
    if c == nil and LightRP.characters then c = LightRP.characters.get(playerId) end
    local name = type(c) == "table" and fullName(c.firstName, c.lastName) or nil
    if not name and type(GetPlayerName) == "function" then name = cleanName(GetPlayerName(playerId)) end
    return name or ""
end

-- The ACL's answer for a player online: true, false, or nil when it cannot answer
-- (no ACL, acl.read refused, the player gone): a staff is never forgotten on a nil.
local function staffVerdict(playerId)
    local S, acl = LightRP.staff, type(Open77) == "table" and Open77.acl or nil
    if type(S) ~= "table" or type(S.isStaff) ~= "function" or type(acl) ~= "table" or type(acl.isAllowed) ~= "function" then return nil end
    local ok, yes = pcall(S.isStaff, playerId)
    if not ok then return nil end
    if yes == true then return true end
    if type(GetPlayerName) == "function" and GetPlayerName(playerId) == nil then return nil end
    local perms = type(LightRpConfig) == "table" and LightRpConfig.staffPermissions
    local probe = type(perms) == "table" and perms[1] or "command.admin"
    local answered, allowed, why = pcall(acl.isAllowed, playerId, probe)
    if not answered or (allowed ~= true and why ~= nil) then return nil end
    return false
end

-- The next open or timer tick rebuilds (the 10 s floor still holds).
local function markStale() cache.retryAt = now() end

-- Remembers (or forgets) a player's account as staff. Called for each player online
-- at every rebuild, at character load, at gameplay ready and on opening the panel.
-- Remembered whatever exclude.staff says, so switching it back on needs no visit.
function HoF.observeStaff(playerId, c)
    local account = accountOfPlayer(playerId, c)
    if not account then return nil end
    local verdict = staffVerdict(playerId)
    if verdict == nil then return nil end
    loadSaved()
    if verdict and saved.staff[account] == nil then
        saved.staff[account] = labelOf(playerId, c)
        local ok, why = store("set", KVP_STAFF .. account, saved.staff[account])
        if ok ~= true then LightRP.log("hall of fame: staff account not saved (%s): off the boards for this session only", tostring(why)) end
        if cfg("exclude.staff", true) ~= false then markStale() end
    elseif not verdict and saved.staff[account] ~= nil then
        saved.staff[account] = nil
        store("delete", KVP_STAFF .. account)
        if cfg("exclude.staff", true) ~= false then markStale() end
    end
    return verdict
end

-- ---------------------------------------------------------------------------
-- Sources, read once per refresh (in a thread: the database answers by yielding)

local function inList(list) local set = {}; for _, v in ipairs(list or {}) do set[v] = true end; return set end

-- PvP / PvE / race membership of an activity id.
local function classify(ids)
    local A = cfg("activities", {})
    local pvp, pve, races = inList(A.pvp), inList(A.pve), inList(A.races)
    local registry = LightRP.activities and LightRP.activities.registry or {}
    for id in pairs(ids) do
        if not pvp[id] and not pve[id] and id ~= "missions" then
            local def = registry[id]
            if id:match("%.pve$") then pve[id] = true
            elseif not (def and def.kind == "event") then pvp[id] = true end
        end
    end
    return pvp, pve, races
end

local function cashIn(items)
    if type(items) ~= "string" or items == "" or type(json) ~= "table" then return 0 end
    local ok, list = pcall(json.decode, items)
    if not ok or type(list) ~= "table" then return 0 end
    local total = 0
    for _, item in pairs(list) do
        if type(item) == "table" and item.name == "cash" then total = total + math.max(0, math.floor(tonumber(item.count) or 0)) end
    end
    return total
end
HoF.cashIn = cashIn

local readFailures = 0 -- a failed read (a table not created yet) makes the next refresh come sooner
local function read(sql, params)
    if not Db.ready then return false end
    local ok, rows = Db.read(sql, params)
    if not ok or type(rows) ~= "table" then readFailures = readFailures + 1; return false end
    return true, rows
end

local function gather()
    local ctx = { db = Db.ready == true, names = {}, namesComplete = false, online = {}, totals = {}, times = {},
        rep = {}, clears = {}, wealth = {}, wealthCash = true, ids = {} }
    ctx.read, ctx.keyOf = read, ownerKey
    -- The character's name; without the characters table, the name stored beside
    -- the row, unless it carries the account identifier.
    function ctx.nameOf(key, fallback)
        local name = ctx.names[key]
        if name or ctx.namesComplete then return name end
        name = cleanName(fallback)
        local identifier = key:match("^(.*)#[^#]*$")
        if name and identifier and identifier ~= "" and name:find(identifier, 1, true) then return nil end
        return name
    end

    -- names: the active characters (an archived one leaves the boards)
    if ctx.db then
        local ok, rows = read("SELECT identifier, character_key, first_name, last_name FROM lightrp_characters WHERE status = 'active'")
        if ok then
            ctx.namesComplete = true
            for _, r in ipairs(rows) do ctx.names[ownerKey(r.identifier, r.character_key)] = fullName(r.first_name, r.last_name) end
        end
    end
    for _, raw in ipairs(GetPlayers()) do
        local id = tonumber(raw)
        local c = id and LightRP.characters and LightRP.characters.get(id)
        if id then HoF.observeStaff(id, c or nil) end -- staff online now: off the boards built below
        if c and c.status == "active" and c.identifier and c.key then
            local key = ownerKey(c.identifier, c.key)
            ctx.online[key] = id
            ctx.names[key] = fullName(c.firstName, c.lastName) or ctx.names[key]
        end
    end

    -- activity totals and best times
    local raceIds = {}
    for _, id in ipairs(cfg("activities.races", {})) do raceIds[#raceIds + 1] = id end
    local function total(key, r)
        ctx.ids[r.activity_id] = true
        ctx.totals[#ctx.totals + 1] = { key = key, activity = r.activity_id, name = r.character_name,
            played = tonumber(r.played) or 0, wins = tonumber(r.wins) or 0, kills = tonumber(r.kills) or 0,
            deaths = tonumber(r.deaths) or 0, bestPlacement = tonumber(r.best_placement) }
    end
    local function time(key, r)
        local ms = tonumber(r.best_time_ms)
        if ms and ms > 0 then
            ctx.times[#ctx.times + 1] = { key = key, activity = r.activity_id, board = tostring(r.board or ""), timeMs = ms,
                t = tonumber(r.t) or 0, name = r.character_name }
        end
    end
    if ctx.db then
        local ok, rows = read([[SELECT identifier, character_key, activity_id, character_name, played, wins, kills, deaths, best_placement
            FROM lightrp_activity_stats WHERE board = '' AND played > 0]])
        if ok then for _, r in ipairs(rows) do total(ownerKey(r.identifier, r.character_key), r) end end
        if #raceIds > 0 then
            ok, rows = read([[SELECT identifier, character_key, activity_id, board, character_name, best_time_ms, UNIX_TIMESTAMP(updated_at) AS t
                FROM lightrp_activity_stats WHERE best_time_ms IS NOT NULL AND activity_id IN (]] .. string.rep("?", #raceIds, ", ") .. ")", raceIds)
            if ok then for _, r in ipairs(rows) do time(ownerKey(r.identifier, r.character_key), r) end end
        end
    else
        local A = LightRP.activities
        local races = inList(raceIds)
        for _, r in ipairs(A and type(A.memoryRows) == "function" and A.memoryRows() or {}) do
            -- key = identifier|characterKey|activityId|board
            local suffix = "|" .. tostring(r.activity_id) .. "|" .. tostring(r.board or "")
            local owner = type(r.key) == "string" and r.key:sub(-#suffix) == suffix and r.key:sub(1, #r.key - #suffix) or nil
            local identifier, characterKey = (owner or ""):match("^(.*)|([^|]*)$")
            if identifier then
                local key = ownerKey(identifier, characterKey)
                if (r.board or "") == "" and (tonumber(r.played) or 0) > 0 then total(key, r) end
                if races[r.activity_id] then time(key, r) end
            end
        end
    end

    -- missions: reputation, completions, clears per point and difficulty
    if ctx.db then
        local ok, rows = read("SELECT identifier, character_key, rep, completed FROM lightrp_mission_rep WHERE rep > 0 OR completed > 0")
        if ok then
            for _, r in ipairs(rows) do
                ctx.rep[#ctx.rep + 1] = { key = ownerKey(r.identifier, r.character_key), rep = tonumber(r.rep) or 0, completed = tonumber(r.completed) or 0 }
            end
        end
        ok, rows = read("SELECT identifier, character_key, point_id, difficulty, completed FROM lightrp_mission_clears WHERE completed > 0")
        if ok then
            for _, r in ipairs(rows) do
                ctx.clears[#ctx.clears + 1] = { key = ownerKey(r.identifier, r.character_key), point = tostring(r.point_id),
                    difficulty = tostring(r.difficulty), count = tonumber(r.completed) or 0 }
            end
        end
    else
        local M = LightRP.missions
        for key, id in pairs(ctx.online) do
            local rep = M and type(M.reputation) == "function" and tonumber(M.reputation(id)) or 0
            if rep and rep > 0 then ctx.rep[#ctx.rep + 1] = { key = key, rep = rep } end
        end
    end

    -- wealth: bank + the cash item, richest bank first
    if ctx.db and C.showWealth then
        local limit = math.max(10, math.min(20000, math.floor(tonumber(C.wealthScanLimit) or 2000)))
        local ok, rows = read([[SELECT w.identifier, w.character_key, w.bank, i.items FROM lightrp_wallets w
            LEFT JOIN lightrp_inventories i ON i.id = CONCAT('player:', w.identifier, '#', w.character_key)
            ORDER BY w.bank DESC LIMIT ]] .. limit)
        if not ok then
            ctx.wealthCash = false
            ok, rows = read("SELECT identifier, character_key, bank FROM lightrp_wallets ORDER BY bank DESC LIMIT " .. limit)
        end
        if ok then
            for i, r in ipairs(rows) do
                local bank, cash = math.max(0, math.floor(tonumber(r.bank) or 0)), cashIn(r.items)
                ctx.wealth[#ctx.wealth + 1] = { key = ownerKey(r.identifier, r.character_key), bank = bank, cash = cash }
                if i % 200 == 0 then Wait(0) end
            end
        end
    end
    return ctx
end

-- ---------------------------------------------------------------------------
-- The built-in boards

local function aggregate(ctx, set)
    local by, list = {}, {}
    for _, r in ipairs(ctx.totals) do
        if set[r.activity] then
            local a = by[r.key]
            if not a then a = { key = r.key, name = r.name, played = 0, wins = 0, kills = 0, deaths = 0 }; by[r.key] = a; list[#list + 1] = a end
            a.played, a.wins, a.kills, a.deaths = a.played + r.played, a.wins + r.wins, a.kills + r.kills, a.deaths + r.deaths
            if r.bestPlacement and (a.bestPlacement == nil or r.bestPlacement < a.bestPlacement) then a.bestPlacement = r.bestPlacement end
        end
    end
    return list
end
local function sets(ctx)
    if not ctx.sets then
        local pvp, pve, races = classify(ctx.ids)
        ctx.sets = { pvp = pvp, pve = pve, races = races }
    end
    return ctx.sets
end
local function winsRows(list)
    local rows = {}
    for _, a in ipairs(list) do
        if a.wins > 0 then
            rows[#rows + 1] = { key = a.key, name = a.name, value = a.wins, sort = { a.wins, -a.played },
                detail = string.format("%d played", a.played) }
        end
    end
    return rows
end
local function killsRows(list)
    local rows = {}
    for _, a in ipairs(list) do
        if a.kills > 0 then
            rows[#rows + 1] = { key = a.key, name = a.name, value = a.kills, sort = { a.kills, -a.deaths },
                detail = string.format("K/D %.2f", a.kills / math.max(1, a.deaths)) }
        end
    end
    return rows
end

local function activityLabel(id)
    local registry = LightRP.activities and LightRP.activities.registry or {}
    local def = registry[id]
    return (def and def.label) or cfg("activities.labels", {})[id] or id
end
-- "watson_loop@2" -> "WATSON LOOP · REV 2"
local function courseLabel(boardId)
    if boardId == "" then return "All courses" end
    local course, revision = boardId:match("^(.*)@(%d+)$")
    course = (course or boardId):gsub("[_%-%.:]+", " "):upper()
    return (revision and revision ~= "0") and (course .. " · REV " .. revision) or course
end
HoF.courseLabel = courseLabel

-- A race's board: its current course (the latest result's, as the activities
-- panel), else the totals.
local function raceProvider(activityId)
    return function(ctx)
        local candidates, latest, counts = {}, {}, {}
        for _, r in ipairs(ctx.times) do
            if r.activity == activityId then
                candidates[#candidates + 1] = r
                if r.board ~= "" then
                    latest[r.board] = math.max(latest[r.board] or 0, r.t)
                    counts[r.board] = (counts[r.board] or 0) + 1
                end
            end
        end
        local chosen, best = "", nil
        for id, t in pairs(latest) do
            local score = ctx.db and t or counts[id]
            if best == nil or score > best or (score == best and id > chosen) then chosen, best = id, score end
        end
        local rows = {}
        for _, r in ipairs(candidates) do
            if r.board == chosen then rows[#rows + 1] = { key = r.key, name = r.name, value = r.timeMs, sort = { r.timeMs } } end
        end
        return rows, { title = activityLabel(activityId):upper(), subtitle = "Best time · " .. courseLabel(chosen) }
    end
end

local function tierOf(rep)
    local tiers = type(LightRpMissions) == "table" and type(LightRpMissions.reputation) == "table" and LightRpMissions.reputation.tiers
    if type(tiers) ~= "table" then return nil end
    local index, label
    for i, t in ipairs(tiers) do
        local threshold = type(t) == "number" and t or (type(t) == "table" and tonumber(t.min or t.threshold or t[1])) or nil
        if threshold and rep >= threshold then index, label = i, type(t) == "table" and (t.label or t.name) or nil end
    end
    if not index then return nil end
    return type(label) == "string" and string.format("TIER %d · %s", index, label:upper()) or string.format("TIER %d", index)
end
HoF.tierOf = tierOf

local function pointType(id)
    local M = LightRP.missions
    local p = M and type(M.point) == "function" and M.point(id) or nil
    return (type(p) == "table" and p.type) or cfg("missions.knownTypes", {})[id]
end
local function clearsProvider(types)
    return function(ctx)
        local diffs = cfg("missions.difficulties", {})
        local slot = {}
        for i, d in ipairs(diffs) do slot[d.id] = i end
        local by, list, typeOf = {}, {}, {}
        for _, r in ipairs(ctx.clears) do
            if typeOf[r.point] == nil then typeOf[r.point] = pointType(r.point) or false end
            local t = typeOf[r.point]
            if t and types[t] then
                local a = by[r.key]
                if not a then a = { key = r.key, counts = {}, other = 0, total = 0 }; by[r.key] = a; list[#list + 1] = a end
                local i = slot[r.difficulty]
                if i then a.counts[i] = (a.counts[i] or 0) + r.count else a.other = a.other + r.count end
                a.total = a.total + r.count
            end
        end
        local rows = {}
        for _, a in ipairs(list) do
            local sort, parts = {}, {}
            for i, d in ipairs(diffs) do
                sort[i] = a.counts[i] or 0
                if sort[i] > 0 then parts[#parts + 1] = string.format("%s %d", d.short or d.id:upper(), sort[i]) end
            end
            sort[#sort + 1] = a.other
            rows[#rows + 1] = { key = a.key, value = a.total, sort = sort, detail = table.concat(parts, " · ") }
        end
        return rows
    end
end

local function registerBuiltins()
    HoF.registerBoard("pvp.wins", { tab = "pvp", title = "MOST WINS", subtitle = "Arena, duels, races, chases and turf war", unit = "wins",
        provider = function(ctx) return winsRows(aggregate(ctx, sets(ctx).pvp)) end })
    HoF.registerBoard("pvp.kills", { tab = "pvp", title = "MOST KILLS", subtitle = "Players taken down in PvP activities", unit = "kills",
        provider = function(ctx) return killsRows(aggregate(ctx, sets(ctx).pvp)) end })
    for _, id in ipairs(cfg("activities.races", {})) do
        HoF.registerBoard("races." .. id, { tab = "races", title = (cfg("activities.labels", {})[id] or id):upper(), unit = "time",
            ascending = true, provider = raceProvider(id) })
    end
    HoF.registerBoard("pve.wins", { tab = "pve", title = "PVE WINS", subtitle = "Combat Zone PvE, races vs AI, NCPD Escape, turf PvE", unit = "wins",
        provider = function(ctx) return winsRows(aggregate(ctx, sets(ctx).pve)) end })
    HoF.registerBoard("pve.kills", { tab = "pve", title = "PVE TAKEDOWNS", subtitle = "Gang bots and NCPD taken down", unit = "kills",
        provider = function(ctx) return killsRows(aggregate(ctx, sets(ctx).pve)) end })
    HoF.registerBoard("pve.rep", { tab = "pve", title = "STREET CRED", subtitle = "Reputation from missions and activities", unit = "rep",
        provider = function(ctx)
            local rows = {}
            for _, r in ipairs(ctx.rep) do
                if r.rep > 0 then rows[#rows + 1] = { key = r.key, value = r.rep, sort = { r.rep, r.completed or 0 },
                    detail = C.showTier ~= false and tierOf(r.rep) or nil } end
            end
            return rows
        end })
    HoF.registerBoard("missions.completed", { tab = "missions", title = "CONTRACTS COMPLETED", subtitle = "Mission boards cleared, every difficulty", unit = "count",
        provider = function(ctx)
            local rows = {}
            for _, r in ipairs(ctx.rep) do
                if (r.completed or 0) > 0 then rows[#rows + 1] = { key = r.key, value = r.completed, sort = { r.completed, r.rep },
                    detail = string.format("%d rep", r.rep) } end
            end
            return rows
        end })
    HoF.registerBoard("missions.heists", { tab = "missions", title = "HEISTS", subtitle = "Ranked by the hardest clears", unit = "clears",
        provider = clearsProvider(cfg("missions.heistTypes", { HEIST = true })) })
    HoF.registerBoard("missions.raids", { tab = "missions", title = "CHIMERA RAID", subtitle = "Ranked by the hardest clears", unit = "clears",
        provider = clearsProvider(cfg("missions.raidTypes", { RAID = true })) })
    HoF.registerBoard("wealth.richest", { tab = "wealth", title = "RICHEST", subtitle = "Cash and bank, eddies", unit = "eddies",
        provider = function(ctx)
            local rows = {}
            for _, r in ipairs(ctx.wealth) do
                local sum = r.bank + r.cash
                if sum > 0 then rows[#rows + 1] = { key = r.key, value = sum, sort = { sum },
                    detail = C.showWealthSplit and string.format("bank %d · cash %d", r.bank, r.cash) or nil } end
            end
            return rows
        end })
end
registerBuiltins()

-- ---------------------------------------------------------------------------
-- The cache

-- Rebuilds every board. Callers in a thread; a second caller waits for the first.
function HoF.refresh(reason)
    if refreshing then
        local waited = 0
        while refreshing and waited < 10000 do Wait(50); waited = waited + 50 end
        return cache
    end
    refreshing = true
    local failuresBefore = readFailures
    local ok, err = pcall(function()
        local ctx = gather()
        local built = {}
        -- the one exclusion pass, after every provider (built-in or registered)
        local excluded, dropped, droppedCount = exclusions(), {}, 0
        for _, key in ipairs(order) do
            local def = boards[key]
            if def and (def.tab ~= "wealth" or C.showWealth) then
                local done, rows, meta = pcall(def.provider, ctx)
                if done and type(rows) == "table" then
                    local ranked, byKey = HoF.rank(dropExcluded(normalizeRows(ctx, rows), excluded, dropped), def.ascending == true)
                    built[key] = { def = def, rows = ranked, byKey = byKey, meta = type(meta) == "table" and meta or {} }
                else
                    LightRP.log("hall of fame: board %s failed: %s", key, tostring(rows))
                end
            end
        end
        for _ in pairs(dropped) do droppedCount = droppedCount + 1 end
        lastNames = ctx.names
        cache = { at = now(), boards = built, database = ctx.db, wealthCash = ctx.wealthCash, excluded = droppedCount }
        -- a table that did not answer (not created yet at start): try again soon
        if readFailures > failuresBefore then cache.retryAt = now() + (tonumber(cfg("cache.retryMs", 30000)) or 30000) end
    end)
    refreshing = false
    lastRefreshAt = now()
    if not ok then LightRP.log("hall of fame: refresh (%s) failed: %s", tostring(reason), tostring(err)) end
    return cache
end
function HoF.cache() return cache end

local function stale()
    if cache.at == nil or (cache.retryAt and now() >= cache.retryAt) then return true end
    return now() - cache.at >= (tonumber(cfg("cache.refreshMs", 300000)) or 300000)
end
local function floorPassed()
    return lastRefreshAt == nil or now() - lastRefreshAt >= (tonumber(cfg("cache.floorMs", 10000)) or 10000)
end

-- ---------------------------------------------------------------------------
-- The dialog payload

-- The generous count of framework.lua (every key and every value).
local function countValues(value, n)
    n = (n or 0) + 1
    if type(value) ~= "table" then return n end
    for _, item in pairs(value) do n = countValues(item, n + 1) end
    return n
end
HoF.countValues = countValues

local function viewerKey(playerId)
    local c = LightRP.characters and LightRP.characters.get(playerId)
    if c and c.status == "active" and c.identifier and c.key then return ownerKey(c.identifier, c.key) end
end

local function boardView(entry, size, me)
    local def, rows = entry.def, entry.rows
    local view = { key = def.key, title = entry.meta.title or def.title, subtitle = entry.meta.subtitle or def.subtitle,
        unit = def.unit, total = #rows, rows = {} }
    if def.ascending then view.ascending = true end
    for i = 1, math.min(size, #rows) do
        local r = rows[i]
        view.rows[i] = { rank = r.rank, name = r.name, value = r.value, detail = r.detail, you = (me ~= nil and r.key == me) or nil }
    end
    local at = me and entry.byKey[me]
    if at then local r = rows[at]; view.mine = { rank = r.rank, value = r.value, detail = r.detail } end
    return view
end

function HoF.tabs()
    local list = {}
    for _, tab in ipairs(TABS) do if tab ~= "wealth" or C.showWealth then list[#list + 1] = tab end end
    return list
end

-- Over the limit (extension boards): the longest board loses its last row, then
-- the last boards go. Never more than one plain event.
local function fit(payload)
    local n = countValues(payload)
    while n > VALUE_LIMIT do
        local longest
        for _, b in ipairs(payload.boards) do if #b.rows > 3 and (not longest or #b.rows > #longest.rows) then longest = b end end
        if longest then table.remove(longest.rows)
        elseif #payload.boards > 1 then table.remove(payload.boards)
        else break end
        n = countValues(payload)
    end
    return n
end

function HoF.payload(playerId, tab)
    if not TAB_SET[tab] or (tab == "wealth" and not C.showWealth) then tab = "overview" end
    local me = viewerKey(playerId)
    -- an excluded viewer has no rank: no "YOU #N", no highlighted row (even before the rebuild)
    if me and exclusions()(me) then me = nil end
    local list = {}
    if tab == "overview" then
        local size, max = tonumber(C.overviewSize) or 3, tonumber(C.overviewMax) or 12
        for _, key in ipairs(order) do
            local entry = cache.boards[key]
            if entry and entry.def.overview ~= false and #list < max then list[#list + 1] = boardView(entry, size, me) end
        end
    else
        local size = math.max(1, math.min(10, math.floor(tonumber(C.size) or 10)))
        for _, key in ipairs(order) do
            local entry = cache.boards[key]
            if entry and entry.def.tab == tab then list[#list + 1] = boardView(entry, size, me) end
        end
    end
    local asked = playerAsked[playerId]
    local wait = asked and math.max(0, (tonumber(cfg("cache.playerRefreshMs", 30000)) or 30000) - (now() - asked)) or 0
    local payload = { title = (C.title or "Hall of Fame"):upper(), hub = HoF.hubName(), tab = tab, tabs = HoF.tabs(), boards = list,
        database = cache.database == true, updatedAgoS = cache.at and math.floor((now() - cache.at) / 1000) or nil,
        refreshInS = math.ceil(wait / 1000), wealthBankOnly = (C.showWealth and cache.database and cache.wealthCash == false) or nil }
    fit(payload)
    return payload
end

local function send(playerId, tab) LightRP.dialog(playerId, "halloffame", HoF.payload(playerId, tab)) end

-- Opens (or switches the tab of) the panel: the cache, rebuilt first only when stale.
function HoF.open(playerId, tab)
    CreateThread(function()
        HoF.observeStaff(playerId) -- a staff seen for the first time: the boards are rebuilt without them
        if stale() and floorPassed() then HoF.refresh("open") end
        send(playerId, tab)
    end)
end

-- The REFRESH button: at most once per playerRefreshMs per player, never faster than
-- floorMs for the server. Answered by the panel itself (its "updated" line).
function HoF.requestRefresh(playerId, tab)
    local t = now()
    local last = playerAsked[playerId]
    if (last and t - last < (tonumber(cfg("cache.playerRefreshMs", 30000)) or 30000)) or not floorPassed() then
        CreateThread(function() send(playerId, tab) end)
        return false
    end
    playerAsked[playerId] = t
    CreateThread(function() HoF.refresh("player"); send(playerId, tab) end)
    return true
end

local function nearBoard(playerId)
    if not board.position then return false end
    local p = Open77.players.position(playerId)
    if type(p) ~= "table" or (p.bucket or 0) ~= cfg("board.bucket", 0) then return false end
    local range = tonumber(cfg("board.clickRange", 10)) or 10
    return (p.x - board.position.x) ^ 2 + (p.y - board.position.y) ^ 2 + (p.z - board.position.z) ^ 2 <= range * range
end
HoF.nearBoard = nearBoard

-- ---------------------------------------------------------------------------
-- Page actions, the E point, the board for the clients

LightRP.action("halloffame.open", function(id, payload)
    if C.enabled == false then return LightRP.result(id, false, "The Hall of Fame is closed.", "halloffame.open") end
    if not nearBoard(id) then
        return LightRP.result(id, false, "Walk up to the Hall of Fame board at " .. HoF.hubName() .. ".", "halloffame.open")
    end
    HoF.open(id, payload.tab)
end)
-- The panel is open: switching tabs and refreshing work from wherever the player stands.
LightRP.action("halloffame.tab", function(id, payload) if C.enabled ~= false then HoF.open(id, payload.tab) end end)
LightRP.action("halloffame.refresh", function(id, payload) if C.enabled ~= false then HoF.requestRefresh(id, payload.tab) end end)
LightRP.action("halloffame.close", function() end) -- the page closes locally; nothing to do here

function HoF.onInteract(playerId, pointId)
    if pointId == POINT and C.enabled ~= false then HoF.open(playerId, "overview") end
end
function HoF.onGameplayReady(playerId)
    HoF.observeStaff(playerId)
    if C.enabled ~= false then sendBoard(playerId) end
end
function HoF.onCharacterLoaded(playerId, c) HoF.observeStaff(playerId, c) end
function HoF.onDisconnected(playerId) playerAsked[playerId], helloAt[playerId] = nil, nil end
-- The boards built before the database answered are the session's: mark them stale,
-- and let the other modules create their tables before the next rebuild.
function HoF.onDatabaseReady()
    if C.enabled == false then return end
    cache.retryAt = now()
    CreateThread(function()
        Wait(tonumber(cfg("cache.databaseDelayMs", 5000)) or 5000)
        if stale() then lastRefreshAt = nil; HoF.refresh("database") end
    end)
end

-- A client (re)started its scripts: tell it which prop the board is.
RegisterNetEvent(E.net.hallOfFameHello, function()
    local id = tonumber(source)
    if id == nil or id <= 0 or C.enabled == false then return end
    local t = now()
    if helloAt[id] and t - helloAt[id] < 1000 then return end
    helloAt[id] = t
    sendBoard(id)
end)

-- ---------------------------------------------------------------------------
-- Staff: /lightrp.halloffame place | where | refresh | exclude | include | excluded

local function placementLine(pos, heading)
    return string.format("position = { x = %.3f, y = %.3f, z = %.3f }, heading = %.1f, -- server/config/halloffame.lua `board`, bucket %d",
        pos.x, pos.y, pos.z, heading, cfg("board.bucket", 0))
end
HoF.placementLine = placementLine

-- exclude | include | excluded: the test list (kvp), applied at the rebuild they trigger.
local SUBJECT_USAGE = "usage: /lightrp.halloffame exclude|include <playerId [account] | account#characterKey | account>"

local function rebuild(reason)
    if C.enabled ~= false then CreateThread(function() lastRefreshAt = nil; HoF.refresh(reason) end) end
end
local function describe(subject, label)
    local who = (type(label) == "string" and label ~= "") and (label .. " (" .. subject .. ")") or subject
    return accountOf(subject) and who or (who .. " [every character]")
end
local function actorOf(source)
    if not source or source <= 0 then return "the console" end
    return LightRP.characters and LightRP.characters.displayName(source) or ("player " .. tostring(source))
end
local function clip(text, max)
    if #text <= max then return text end
    local cut = max - 3
    while cut > 0 do local b = text:byte(cut + 1); if not b or b < 0x80 or b >= 0xC0 then break end; cut = cut - 1 end
    return text:sub(1, cut) .. "..."
end

-- "12" a player online (their character; "12 account": their account),
-- "<account>#<characterKey>" a character, "<account>" every character of an account.
-- -> subject, label | nil, reason
local function parseSubject(args)
    local raw = tostring(args[2] or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if raw == "" then return nil, SUBJECT_USAGE end
    local wholeAccount = tostring(args[3] or ""):lower() == "account"
    if raw:match("^%d+$") then
        local id = tonumber(raw)
        local c = LightRP.characters and LightRP.characters.get(id) or nil
        local account = (c or type(GetPlayerName) ~= "function" or GetPlayerName(id) ~= nil) and accountOfPlayer(id, c) or nil
        if not account then return nil, "No player " .. raw .. " online: give account#characterKey or an account id (/lightrp.halloffame excluded lists them)." end
        local label = labelOf(id, c)
        if wholeAccount or type(c) ~= "table" or c.key == nil then return account, label end
        return ownerKey(account, c.key), label
    end
    if #raw > 200 or raw:find("[%c%s]") then return nil, "Invalid id: " .. SUBJECT_USAGE end
    local account = raw:match("^([^#]+)#[^#]+$")
    if account then
        if wholeAccount then return account, "" end
        return raw, lastNames[raw] or ""
    end
    if raw:find("#", 1, true) then return nil, "Invalid character id (account#characterKey): " .. SUBJECT_USAGE end
    return raw, ""
end
HoF.parseSubject = parseSubject

local function excludeVerb(source, args)
    local subject, label = parseSubject(args)
    if not subject then return false, label end
    loadSaved()
    local who = describe(subject, label)
    if saved.tests[subject] ~= nil then return true, "Hall of Fame: " .. who .. " is already on the test list." end
    saved.tests[subject] = label
    local ok, why = store("set", KVP_TEST .. subject, label)
    LightRP.log("hall of fame: %s excluded by %s", subject, actorOf(source))
    rebuild("exclude")
    local note = cfg("exclude.tests", true) == false and " (exclude.tests is off in server/config/halloffame.lua: listed, not applied)" or ""
    return true, "Hall of Fame: " .. who .. " excluded" .. (ok == true and "" or (" for this session only (not saved: " .. tostring(why) .. ")"))
        .. note .. "; rebuilding the boards."
end

local function includeVerb(source, args)
    local subject, label = parseSubject(args)
    if not subject then return false, label end
    loadSaved()
    local who, done = describe(subject, label ~= "" and label or saved.tests[subject] or saved.staff[subject]), {}
    if saved.tests[subject] ~= nil then
        saved.tests[subject] = nil
        store("delete", KVP_TEST .. subject)
        done[#done + 1] = "off the test list"
    end
    if not accountOf(subject) and saved.staff[subject] ~= nil then
        saved.staff[subject] = nil
        store("delete", KVP_STAFF .. subject)
        done[#done + 1] = "forgotten as staff (remembered again if seen online with staff rights)"
    end
    local still = HoF.excludedBy(subject)
    if #done == 0 then
        if still then return false, "Hall of Fame: " .. who .. " stays excluded: " .. still .. "." end
        return false, "Hall of Fame: " .. who .. " is not excluded."
    end
    LightRP.log("hall of fame: %s included by %s", subject, actorOf(source))
    rebuild("include")
    return true, "Hall of Fame: " .. who .. " " .. table.concat(done, ", ")
        .. (still and ("; still excluded: " .. still) or "; back on the boards") .. ". Rebuilding the boards."
end

local function excludedVerb()
    loadSaved()
    local X = cfg("exclude", {})
    local function listOf(map)
        local list = {}
        for subject, label in pairs(map) do list[#list + 1] = describe(subject, label ~= "" and label or lastNames[subject]) end
        table.sort(list)
        return list
    end
    local function count(list) return type(list) == "table" and #list or 0 end
    local staffList, testList = listOf(saved.staff), listOf(saved.tests)
    local text = string.format("Hall of Fame exclusions. Staff (%s): %d seen online%s, %d in config. Tests (%s): %d by command%s, %d in config.%s",
        X.staff ~= false and "on" or "OFF", #staffList, #staffList > 0 and (" [" .. table.concat(staffList, "; ") .. "]") or "",
        count(X.staffAccounts), X.tests ~= false and "on" or "OFF", #testList,
        #testList > 0 and (" [" .. table.concat(testList, "; ") .. "]") or "", count(X.characters) + count(X.accounts),
        cache.excluded and string.format(" Last rebuild: %d character(s) left off the boards.", cache.excluded) or "")
    return true, clip(text, 900)
end

LightRP.command("lightrp.halloffame", { restricted = true, usage = "/lightrp.halloffame [place|where|refresh|exclude|include|excluded]" }, function(source, args)
    local verb = tostring(args and args[1] or "where"):lower()
    -- the lists can be prepared while the Hall of Fame is off
    if verb == "exclude" then return excludeVerb(source, args) end
    if verb == "include" then return includeVerb(source, args) end
    if verb == "excluded" then return excludedVerb() end
    if C.enabled == false then return false, "The Hall of Fame is disabled (server/config/halloffame.lua)." end
    if verb == "refresh" then
        CreateThread(function() lastRefreshAt = nil; HoF.refresh("staff") end)
        return true, "Hall of Fame: rebuilding every board."
    end
    if verb == "where" then
        if not board.position then return false, "The board is not placed yet." end
        return true, placementLine(board.position, board.heading) .. string.format(" · prop %s (%s)", tostring(board.prop or "none"), tostring(C.board.model))
    end
    if verb ~= "place" then return false end
    if not source or source <= 0 then return false, "In game only: stand in front of the spot, facing where the screen should face." end
    local read = type(Open77.players.get) == "function" and Open77.players.get(source) or nil
    local p = type(read) == "table" and read.position or Open77.players.position(source)
    if type(p) ~= "table" or type(p.x) ~= "number" then return false, "Your position is not available yet." end
    local bucket = type(GetPlayerRoutingBucket) == "function" and GetPlayerRoutingBucket(source) or p.bucket or 0
    if (tonumber(bucket) or 0) ~= cfg("board.bucket", 0) then return false, "Stand in the city (routing bucket " .. cfg("board.bucket", 0) .. ")." end
    local heading = (type(read) == "table" and tonumber(read.heading or read.yaw)) or 0
    -- the board goes behind the staff; its screen faces where they look
    local h, back = math.rad(heading), tonumber(cfg("board.staffSetback", 0.8)) or 0.8
    local pos = { x = p.x + math.sin(h) * back, y = p.y - math.cos(h) * back, z = p.z }
    setPlacement(pos, heading)
    local placed, why = placeProp()
    sendBoard(-1)
    local line = placementLine(board.position, board.heading)
    LightRP.log("hall of fame: board placed by %s: %s", LightRP.characters.displayName(source), line)
    if not placed then return true, line .. " (E point moved; the prop failed: " .. tostring(why) .. ")" end
    return true, line
end)

-- ---------------------------------------------------------------------------
-- Start: the E point now, the prop once the world takes it, then the cache timer.

if C.enabled ~= false then
    local pos, heading = HoF.placement()
    if LightRP.batchInteractions then LightRP.batchInteractions(function() setPlacement(pos, heading) end) else setPlacement(pos, heading) end
    CreateThread(function()
        local retries = math.max(1, math.floor(tonumber(cfg("board.spawnRetries", 30)) or 30))
        for attempt = 1, retries do
            local ok, why = placeProp()
            if ok then
                LightRP.log("hall of fame: board %s at %.1f, %.1f (prop %s)", tostring(C.board.model), board.position.x, board.position.y, board.prop)
                sendBoard(-1)
                return
            end
            if attempt == 1 then LightRP.log("hall of fame: board prop not created yet (%s): retrying; the E point works", tostring(why)) end
            Wait(tonumber(cfg("board.spawnRetryMs", 10000)) or 10000)
        end
        LightRP.log("hall of fame: board prop gave up after %d tries; the E point still opens the panel", retries)
    end)
    CreateThread(function()
        Wait(tonumber(cfg("cache.firstRefreshMs", 15000)) or 15000)
        while true do
            if stale() and floorPassed() then HoF.refresh("timer") end
            -- checked every 30 s (a cheap test): a failed read is retried that soon
            Wait(math.min(tonumber(cfg("cache.refreshMs", 300000)) or 300000, tonumber(cfg("cache.retryMs", 30000)) or 30000))
        end
    end)
end
