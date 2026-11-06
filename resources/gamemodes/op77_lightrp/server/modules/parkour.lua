-- Parkour: courses authored by the staff (start orb, checkpoints, finish orb), run against
-- the clock, one leaderboard per course (docs/parkour.md).
--
--   * Storage: lightrp_parkour_courses (the course, its revision, published or draft) and
--     lightrp_parkour_times (each character's best time and splits per course revision).
--     A change of the route (an orb moved, added, removed, a radius, the fall line) is a new
--     revision: a fresh leaderboard. Renaming keeps it.
--   * Start points: every published course is an interaction point (E prompt + map blip,
--     the nearest `streamLimit` per player); E opens the course card (leaderboard + START).
--     Starting from the card (or the Activities panel) from anywhere is fine: the activity
--     core captures where the player stood and brings them back there at the end.
--   * A run: the activity core owns the player (RP weapons aside, needs frozen, return
--     point), god mode on, teleport onto the start, held 3 s, GO. The server alone decides
--     every crossing, from its own position feed (every tickMs): the segment between two
--     samples is tested against the next orb's sphere and the crossing time is interpolated
--     along it, so the times do not depend on the sample rate. Checkpoints in order.
--   * Keys (client/core/parkour.lua): restart (HOME), back to the last checkpoint (END),
--     leave (F1 > Leave activity, or /parkour.leave).
--   * Staff editor: /lightrp.parkour (ACL command.lightrp.parkour), request/response on
--     op77_lightrp:parkour:editor, page ui/src/features/parkour/ParkourEditor.tsx.
local P, C = LightRpParkour, LightRpParkour.config
local E, Db = LightRpEvents, LightRP.db
-- The activity core (server/modules/activities.lua, loaded before this file); read at each
-- use so a reload order change never leaves it nil.
local A = setmetatable({}, { __index = function(_, key) local core = LightRP.activities; return core and core[key] end })
local M = LightRP.module("parkour", {})
local NET, NET_KEY, NET_EDIT = E.net.parkour, E.net.parkourKey, E.net.parkourEditor
local ACT = C.activityId
local LIFT = C.orbLift

Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_parkour_courses (
    id VARCHAR(24) NOT NULL PRIMARY KEY,
    name VARCHAR(64) NOT NULL, data MEDIUMTEXT NOT NULL, revision INT NOT NULL DEFAULT 1,
    status VARCHAR(12) NOT NULL DEFAULT 'draft', author_id VARCHAR(128) NOT NULL DEFAULT '', author_name VARCHAR(64) NOT NULL DEFAULT '',
    attempts INT NOT NULL DEFAULT 0, finishes INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL DEFAULT NULL, KEY parkour_live (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_parkour_times (
    course_id VARCHAR(24) NOT NULL, revision INT NOT NULL,
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL, name VARCHAR(64) NOT NULL DEFAULT '',
    time_ms INT NOT NULL, splits TEXT NOT NULL, runs INT NOT NULL DEFAULT 1,
    achieved_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (course_id, revision, identifier, character_key), KEY parkour_board (course_id, revision, time_ms)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local courses, order = {}, {}   -- id -> course (validated + id, revision, status, author, stats); ids by name
local loaded = false
local boards = {}               -- id -> { revision, rows = { { key, name, timeMs, splits, runs, at } } sorted, byKey, total }
local runs = {}                 -- playerId -> run
local editors = {}              -- playerId -> true while the editor is open
local lastKey, lastEdit = {}, {}
local done = {}                 -- editor idempotency: actor -> mutation -> result
local sequence = 0

local function log(...) LightRP.log(...) end
local function now() return LightRP.nowMs() end
local function unix()
    local ok, v = pcall(function() return Open77.time.unix() end)
    return ok and math.floor(tonumber(v) or 0) or 0
end
local function copy(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = copy(x) end
    return t
end
local function keyOf(player)
    local c = LightRP.characters and LightRP.characters.get(player)
    if c and c.status == "active" and c.identifier and c.key then return c.identifier .. "#" .. c.key, c end
end
local function nameOf(player)
    local n = LightRP.characters and LightRP.characters.displayName and LightRP.characters.displayName(player)
    return tostring(n or GetPlayerName(player) or ("Player " .. tostring(player))):sub(1, 64)
end
local function positionOf(player)
    local p = Open77.players.position(player)
    if type(p) ~= "table" or type(p.x) ~= "number" then return nil end
    return { x = p.x, y = p.y, z = p.z, heading = tonumber(p.heading) or 0 }
end
local function emitStatus() end -- defined below

-- A plain net event stops at 1024 values / ~48 KiB (and says nothing): past that, latent.
local LATENT_VALUES, LATENT_BYTES, LATENT_RATE = 900, 40 * 1024, 512 * 1024
local function countValues(value, depth)
    if type(value) ~= "table" then return 1 end
    if (depth or 0) > 16 then return 1 end
    local n = 1
    for _, item in pairs(value) do n = n + 1 + countValues(item, (depth or 0) + 1) end
    return n
end
M.countValues = countValues
local function deliver(player, name, payload)
    local big = countValues(payload) > LATENT_VALUES
    if not big and type(json) == "table" and type(json.encode) == "function" then
        local ok, text = pcall(json.encode, payload)
        big = ok and type(text) == "string" and #text > LATENT_BYTES
    end
    if big and type(TriggerLatentClientEvent) == "function" then
        local id = TriggerLatentClientEvent(name, player, LATENT_RATE, payload)
        if id then return true end
    end
    TriggerClientEvent(name, player, payload)
    return true
end
local function send(player, payload) return deliver(player, NET, payload) end

-- ---------------------------------------------------------------------------
-- Courses

local function sortOrder()
    order = {}
    for id in pairs(courses) do order[#order + 1] = id end
    table.sort(order, function(a, b)
        local x, y = courses[a], courses[b]
        if x.name:lower() ~= y.name:lower() then return x.name:lower() < y.name:lower() end
        return a < b
    end)
end

local function published(course) return course and course.status == "published" end
local function stored(course)
    -- what the data column holds: the route and the rules (identity columns aside)
    return { name = course.name, description = course.description, difficulty = course.difficulty, start = course.start,
        checkpoints = course.checkpoints, finish = course.finish, timeLimit = course.timeLimit, floorZ = course.floorZ }
end

local DIFF_LABEL = { easy = "Easy", medium = "Medium", hard = "Hard", extreme = "Extreme" }
local function startPoint(course)
    local id = "parkour." .. course.id
    if not published(course) then LightRP.removeInteraction(id); return end
    LightRP.interaction(id, {
        position = { x = course.start.x, y = course.start.y, z = course.start.z }, radius = C.startPromptRadius,
        label = "Parkour", prompt = "Parkour · " .. course.name, ring = false, promptHeight = 1.6,
        streamGroup = "parkour", streamLimit = C.streamLimit,
        blip = { title = "Parkour · " .. course.name, icon = "footprints", color = "#00F0FF", mapCategory = "parkour", routable = true,
            description = ("%s · %d checkpoint%s · %.0f m"):format(DIFF_LABEL[course.difficulty] or "Medium", #course.checkpoints,
                #course.checkpoints == 1 and "" or "s", course.length or 0) },
    })
end

-- Every client keeps the published courses' summaries (start orbs within sight).
local function summaries()
    local list = {}
    for _, id in ipairs(order) do
        local c = courses[id]
        if published(c) then list[#list + 1] = P.summary(c) end
    end
    return list
end
local function pushCourses(player)
    local payload = { kind = "courses", courses = summaries() }
    if player then send(player, payload); return end
    for _, raw in ipairs(GetPlayers()) do local id = tonumber(raw); if id then send(id, payload) end end
end

local function registerActivity()
    if type(A.register) ~= "function" then return end
    -- the Activities panel offers up to 8 courses: the most finished first
    local list = {}
    for _, id in ipairs(order) do if published(courses[id]) then list[#list + 1] = courses[id] end end
    table.sort(list, function(a, b) if (a.finishes or 0) ~= (b.finishes or 0) then return (a.finishes or 0) > (b.finishes or 0) end return a.name < b.name end)
    local modes = {}
    for i = 1, math.min(8, #list) do modes[i] = { id = list[i].id, label = list[i].name:sub(1, 32) } end
    local ok, why = A.register({
        id = ACT, resource = GetCurrentResourceName(), label = "Parkour", kind = "race",
        description = "Rooftops and back alleys against the clock: from the start orb to the finish through every checkpoint. One leaderboard per course. F1 > Parkour lists them all.",
        minPlayers = 1, maxPlayers = 1, modes = #modes > 0 and modes or nil, modeKey = "course",
        caps = { rpWeapons = false, rpItems = false, needs = false, vehicles = false },
    })
    if not ok then log("parkour: activity registration refused: %s", tostring(why)) end
end
M.registerActivity = registerActivity

local function changed()
    sortOrder()
    LightRP.batchInteractions(function()
        for _, id in ipairs(order) do startPoint(courses[id]) end
    end)
    pushCourses()
    registerActivity()
end

local function addCourse(row)
    local okData, data = pcall(json.decode, row.data or "")
    if not okData or type(data) ~= "table" then log("parkour: course %s unreadable, skipped", tostring(row.id)); return end
    data.id, data.revision, data.status = row.id, tonumber(row.revision) or 1, row.status == "published" and "published" or "draft"
    local course, why = P.validate(data)
    if not course then log("parkour: course %s invalid (%s), skipped", tostring(row.id), tostring(why)); return end
    course.id, course.revision, course.status = data.id, data.revision, data.status
    course.author, course.authorName = row.author_id or "", row.author_name or ""
    course.attempts, course.finishes = tonumber(row.attempts) or 0, tonumber(row.finishes) or 0
    course.createdAt, course.updatedAt = (tonumber(row.created) or 0) * 1000, (tonumber(row.updated) or 0) * 1000
    courses[course.id] = course
end

-- ---------------------------------------------------------------------------
-- Leaderboards

local function sortRows(rows)
    table.sort(rows, function(a, b) if a.timeMs ~= b.timeMs then return a.timeMs < b.timeMs end return (a.at or 0) < (b.at or 0) end)
end
local function boardOf(id)
    local course = courses[id]
    if not course then return nil end
    local b = boards[id]
    if b and b.revision == course.revision then return b end
    b = { revision = course.revision, rows = {}, byKey = {}, total = 0 }
    if Db.ready then
        local ok, rows = Db.read([[SELECT identifier, character_key, name, time_ms, splits, runs, UNIX_TIMESTAMP(achieved_at) AS at
            FROM lightrp_parkour_times WHERE course_id = ? AND revision = ? ORDER BY time_ms, achieved_at LIMIT ]] .. math.floor(C.boardCache), { id, course.revision })
        if not ok then return nil end
        for _, r in ipairs(rows) do
            local row = { key = r.identifier .. "#" .. r.character_key, name = r.name, timeMs = tonumber(r.time_ms) or 0,
                splits = P.decodeSplits(r.splits), runs = tonumber(r.runs) or 1, at = (tonumber(r.at) or 0) * 1000 }
            b.rows[#b.rows + 1] = row
            b.byKey[row.key] = row
        end
        local okCount, count = Db.read("SELECT COUNT(*) AS n FROM lightrp_parkour_times WHERE course_id = ? AND revision = ?", { id, course.revision })
        b.total = okCount and count[1] and tonumber(count[1].n) or #b.rows
    end
    boards[id] = b
    return b
end
M.boardOf = boardOf

-- This character's best on a course: { timeMs, splits, rank, runs } | nil.
local function personalBest(id, key)
    local b = boardOf(id)
    if not b or not key then return nil end
    local row = b.byKey[key]
    if row then
        for i, r in ipairs(b.rows) do if r == row then return { timeMs = row.timeMs, splits = row.splits, rank = i, runs = row.runs } end end
    end
    if not Db.ready or #b.rows < C.boardCache then return nil end
    -- beyond the cached top: read it
    local identifier, ck = key:match("^(.*)#([^#]+)$")
    local ok, rows = Db.read("SELECT time_ms, splits, runs FROM lightrp_parkour_times WHERE course_id = ? AND revision = ? AND identifier = ? AND character_key = ?",
        { id, courses[id].revision, identifier, ck })
    if not ok or not rows[1] then return nil end
    local t = tonumber(rows[1].time_ms) or 0
    local okRank, rank = Db.read("SELECT COUNT(*) AS n FROM lightrp_parkour_times WHERE course_id = ? AND revision = ? AND time_ms < ?", { id, courses[id].revision, t })
    return { timeMs = t, splits = P.decodeSplits(rows[1].splits), runs = tonumber(rows[1].runs) or 1, rank = okRank and rank[1] and (tonumber(rank[1].n) or 0) + 1 or nil }
end
M.personalBest = personalBest

local function recordOf(id)
    local b = boardOf(id)
    local r = b and b.rows[1]
    return r and { timeMs = r.timeMs, splits = r.splits, name = r.name } or nil
end

-- Writes a finished time: { improved, previous, rank, total } (rank of the best, after).
local function saveTime(run, player, timeMs)
    local id, course = run.course.id, courses[run.course.id]
    local key = run.key
    local b = boardOf(id)
    if not course or not b or course.revision ~= run.course.revision then return nil end
    local previous = b.byKey[key] and { timeMs = b.byKey[key].timeMs, splits = b.byKey[key].splits } or personalBest(id, key)
    local improved = not previous or timeMs < previous.timeMs
    local splits = P.encodeSplits(run.splits)
    if Db.ready then
        local identifier, ck = key:match("^(.*)#([^#]+)$")
        -- splits and the date first: MySQL applies the assignments left to right
        local ok = Db.run([[INSERT INTO lightrp_parkour_times (course_id, revision, identifier, character_key, name, time_ms, splits, runs)
            VALUES (?, ?, ?, ?, ?, ?, ?, 1)
            ON DUPLICATE KEY UPDATE runs = runs + 1, name = VALUES(name),
                splits = IF(VALUES(time_ms) < time_ms, VALUES(splits), splits),
                achieved_at = IF(VALUES(time_ms) < time_ms, CURRENT_TIMESTAMP, achieved_at),
                time_ms = LEAST(time_ms, VALUES(time_ms))]],
            { id, course.revision, identifier, ck, run.name, timeMs, splits })
        if not ok then return nil, "The time could not be saved." end
        Db.run("UPDATE lightrp_parkour_courses SET finishes = finishes + 1 WHERE id = ?", { id })
    end
    course.finishes = (course.finishes or 0) + 1
    local row = b.byKey[key]
    if row then
        row.runs, row.name = (row.runs or 1) + 1, run.name
        if improved then row.timeMs, row.splits, row.at = timeMs, copy(run.splits), unix() * 1000 end
    elseif improved then
        row = { key = key, name = run.name, timeMs = timeMs, splits = copy(run.splits), runs = (previous and 1 or 0) + 1, at = unix() * 1000 }
        b.rows[#b.rows + 1] = row
        b.byKey[key] = row
        if not previous then b.total = (b.total or 0) + 1 end
    end
    sortRows(b.rows)
    while #b.rows > C.boardCache do local gone = table.remove(b.rows); b.byKey[gone.key] = nil end
    local best = personalBest(id, key)
    return { improved = improved, previous = previous, rank = best and best.rank, total = math.max(b.total or 0, #b.rows), best = best }
end

local function boardRows(id, page, key)
    local b = boardOf(id)
    if not b then return nil end
    local size = C.boardPage
    local pages = math.max(1, math.ceil(#b.rows / size))
    page = math.min(pages, math.max(1, math.floor(tonumber(page) or 1)))
    local rows = {}
    for i = (page - 1) * size + 1, math.min(#b.rows, page * size) do
        local r = b.rows[i]
        rows[#rows + 1] = { rank = i, name = r.name, timeMs = r.timeMs, splits = P.encodeSplits(r.splits), runs = r.runs, at = r.at, me = r.key == key or nil }
    end
    return { rows = rows, page = page, pages = pages, total = math.max(b.total or 0, #b.rows), shown = #b.rows }
end

-- ---------------------------------------------------------------------------
-- The course card / browser (F1 > Parkour, the start orb's E, /parkour)

local function nearCourse(player)
    local at = positionOf(player)
    if not at then return nil end
    local best, bestD
    for _, id in ipairs(order) do
        local c = courses[id]
        if published(c) then
            local d = P.distance(at, c.start)
            if d <= C.startPromptRadius + 3 and (not bestD or d < bestD) then best, bestD = id, d end
        end
    end
    return best
end

local function cardOf(course, key, at)
    local best = personalBest(course.id, key)
    local record = recordOf(course.id)
    local b = boards[course.id]
    return { id = course.id, name = course.name, description = course.description, difficulty = course.difficulty,
        checkpoints = #course.checkpoints, length = course.length, timeLimit = course.timeLimit, fallLine = course.floorZ ~= nil or nil,
        author = course.authorName, finishes = course.finishes or 0, attempts = course.attempts or 0, runners = b and math.max(b.total or 0, #b.rows) or 0,
        record = record and { timeMs = record.timeMs, name = record.name } or nil,
        best = best and { timeMs = best.timeMs, rank = best.rank, runs = best.runs } or nil,
        distance = at and math.floor(P.distance(at, course.start)) or nil,
        start = { x = course.start.x, y = course.start.y, z = course.start.z } }
end

function M.browser(player, selected)
    local key = keyOf(player)
    if not key then return nil, "Your character is not loaded yet." end
    if not loaded and Db.ready then return nil, "The courses are loading. Try again in a moment." end
    local at = positionOf(player)
    local list = {}
    for _, id in ipairs(order) do
        local c = courses[id]
        if published(c) then list[#list + 1] = cardOf(c, key, at) end
    end
    local here = nearCourse(player)
    if selected and not (courses[selected] and published(courses[selected])) then selected = nil end
    selected = selected or here or (list[1] and list[1].id)
    local run = runs[player]
    return { kind = "parkour", courses = list, selected = selected, here = here,
        running = run and run.course.id or nil, staff = M.allowed(player) or nil,
        keys = { restart = "HOME", checkpoint = "END" } }
end

function M.openBrowser(player, selected)
    local payload, why = M.browser(player, selected)
    if not payload then LightRP.result(player, false, why, "parkour.open"); return end
    deliver(player, E.net.dialog, payload)
    if payload.selected then M.sendBoard(player, payload.selected, 1) end
end

function M.sendBoard(player, id, page)
    local course = courses[id]
    if not course or not published(course) then return end
    local key = keyOf(player)
    local rows = boardRows(id, page, key)
    if not rows then send(player, { kind = "board", course = id, error = "The leaderboard is unavailable right now." }); return end
    local best = personalBest(id, key)
    local record = recordOf(id)
    send(player, { kind = "board", course = id, revision = course.revision, page = rows.page, pages = rows.pages, total = rows.total, shown = rows.shown,
        rows = rows.rows, checkpoints = #course.checkpoints,
        best = best and { timeMs = best.timeMs, rank = best.rank, runs = best.runs, splits = P.encodeSplits(best.splits) } or nil,
        record = record and { timeMs = record.timeMs, name = record.name, splits = P.encodeSplits(record.splits) } or nil })
end

LightRP.action("parkour.open", function(player, p) M.openBrowser(player, type(p.course) == "string" and p.course or nil) end)
LightRP.action("parkour.board", function(player, p)
    if type(p.course) ~= "string" then return end
    M.sendBoard(player, p.course, p.page)
end)
LightRP.action("parkour.start", function(player, p)
    if type(p.course) ~= "string" then return end
    local ok, why = M.start(player, p.course, {})
    if not ok then LightRP.result(player, false, why, "parkour.start")
    else send(player, { kind = "close" }) end
end)

-- The start orb's E prompt opens the card on that course.
function M.onInteract(player, id)
    local course = type(id) == "string" and id:match("^parkour%.(.+)$")
    if not course then return end
    if runs[player] then return end
    M.openBrowser(player, course)
end

-- ---------------------------------------------------------------------------
-- Runs

local function targetsOf(course)
    local t = {}
    for _, c in ipairs(course.checkpoints) do t[#t + 1] = c end
    t[#t + 1] = course.finish
    return t
end

local function runPayload(run)
    local c = run.course
    local cps = {}
    for i, p in ipairs(c.checkpoints) do cps[i] = { x = p.x, y = p.y, z = p.z, radius = p.radius } end
    return { id = c.id, name = c.name, difficulty = c.difficulty, revision = c.revision, test = run.test or nil,
        start = { x = c.start.x, y = c.start.y, z = c.start.z, radius = c.start.radius, heading = c.start.heading },
        checkpoints = cps, finish = { x = c.finish.x, y = c.finish.y, z = c.finish.z, radius = c.finish.radius },
        timeLimit = c.timeLimit, floorZ = c.floorZ, length = c.length }
end

local function protect(player, run)
    if type(Open77.players.setGodMode) ~= "function" then return end
    if run.previousGodMode == nil then
        local ok, health = pcall(Open77.players.getHealth, player)
        run.previousGodMode = ok and type(health) == "table" and health.godMode == true or false
    end
    pcall(Open77.players.setGodMode, player, true)
end
local function unprotect(player, run)
    if run.frozen then pcall(Open77.players.setFrozen, player, false); run.frozen = false end
    if run.previousGodMode ~= nil and type(Open77.players.setGodMode) == "function" then
        pcall(Open77.players.setGodMode, player, run.previousGodMode)
        run.previousGodMode = nil
    end
end

local function teleport(player, run, point, heading)
    run.teleporting = true
    run.prev = nil
    local promise, why = Open77.players.teleport(player, { x = point.x, y = point.y, z = point.z },
        { heading = heading or 0, fade = true, fadeOutMs = 150, fadeInMs = 200, dismount = true, timeoutMs = 8000 })
    -- the promise resolves with the position reached (a table), and rejects with a reason
    local result
    if promise then result, why = promise:await() end
    local placed = result ~= nil and result ~= false
    if runs[player] ~= run then return false end
    run.teleporting = false
    run.prev, run.graceUntil = nil, now() + 800
    if not placed then log("parkour: teleport of %d failed: %s", player, tostring(why)) end
    return placed
end

local function statusPhase()
    local n = 0
    for _ in pairs(runs) do n = n + 1 end
    return n
end
emitStatus = function()
    local n = statusPhase()
    TriggerEvent("op77_lightrp:activity:status", ACT, { phase = n > 0 and "running" or "idle", players = n, queued = 0, joinable = true,
        detail = n > 0 and (n .. " running") or "" })
end

-- The run is over for this player: the HUD goes, the core lets go (and returns them).
local function endRun(player, reason, opts)
    local run = runs[player]
    if not run then return end
    opts = opts or {}
    runs[player] = nil
    run.over = true
    unprotect(player, run)
    send(player, { kind = "ended", reason = reason })
    if run.entered and opts.release ~= false and type(A.leave) == "function" then
        local ok, why = A.leave(player, ACT, { returnPlayer = opts.returnPlayer ~= false })
        if not ok then log("parkour: activity leave of %d refused: %s", player, tostring(why)) end
    end
    log("parkour: %s left %s (%s)", run.name, run.course.name, tostring(reason))
    emitStatus()
end
M.endRun = endRun

-- Teleport onto the start, held, 3-2-1, GO.
local function begin(player, run)
    run.phase, run.next, run.last, run.splits = "loading", 1, 0, {}
    run.attempt = (run.attempt or 0) + 1
    run.startedAt, run.dnf, run.result = nil, nil, nil
    local token = {}
    run.token = token
    send(player, { kind = "run", phase = "loading", course = runPayload(run), attempt = run.attempt,
        best = run.best and { timeMs = run.best.timeMs, splits = P.encodeSplits(run.best.splits) } or nil,
        record = run.record and { timeMs = run.record.timeMs, name = run.record.name, splits = P.encodeSplits(run.record.splits) } or nil,
        music = C.music })
    local s = run.course.start
    local placed = teleport(player, run, s, s.heading)
    if runs[player] ~= run or run.token ~= token then return end
    if not placed then
        LightRP.notice(player, { kind = "warning", title = "PARKOUR", body = "You could not be placed on the start. Try again." })
        endRun(player, "start_failed")
        return
    end
    -- Landed first: the client reports once no loading screen covers it (client/core/parkour.lua,
    -- op "landed"); held on the start meanwhile.
    run.phase = "landing"
    send(player, { kind = "landing", attempt = run.attempt })
    local landBy, heldReported = now() + (C.landTimeoutMs or 15000), false
    while run.landed ~= run.attempt and now() < landBy do
        if runs[player] ~= run or run.token ~= token then return end
        if type(Open77.players.setFrozen) == "function" then
            local called, ok = pcall(Open77.players.setFrozen, player, true)
            if called and ok == true then run.frozen = true elseif not heldReported then heldReported = true end
        end
        Wait(100)
    end
    if runs[player] ~= run or run.token ~= token then return end
    if run.landed ~= run.attempt then log("parkour: %d never reported landing on %s, counting down anyway", player, run.course.name) end
    run.phase = "countdown"
    send(player, { kind = "countdown", goInMs = C.countdownMs, attempt = run.attempt })
    -- Held on the line until GO. One freeze right after the teleport did not hold (LightRP
    -- Testing 2026-11-06: the runner walked during the 3-2-1): like op77_race's holdRunner, it
    -- is applied again every 200 ms, and a runner who still leaves the start orb is put back.
    local goAt, reported, putBack = now() + C.countdownMs, false, 0
    while now() < goAt do
        if runs[player] ~= run or run.token ~= token then return end
        if type(Open77.players.setFrozen) == "function" then
            local called, ok, why = pcall(Open77.players.setFrozen, player, true)
            if called and ok == true then run.frozen = true
            elseif not reported then reported = true; log("parkour: freeze of %d refused: %s", player, tostring(called and why or ok)) end
        end
        local at = positionOf(player)
        if at and P.distance(at, s) > math.max(1.5, (s.radius or 3) * 0.5) and putBack < 3 and not run.teleporting then
            putBack = putBack + 1
            teleport(player, run, s, s.heading)
            if runs[player] ~= run or run.token ~= token then return end
        end
        Wait(200)
    end
    if runs[player] ~= run or run.token ~= token then return end
    if type(Open77.players.setFrozen) == "function" then pcall(Open77.players.setFrozen, player, false) end
    run.frozen = false
    run.phase, run.startedAt = "running", now()
    run.prev, run.graceUntil = nil, now() + 500
    send(player, { kind = "go", attempt = run.attempt })
end

-- Start (or restart) a run. `courseId` a published course; opts.draft: a staff test of an
-- unsaved course (not recorded, never on a board).
function M.start(player, courseId, opts)
    opts = opts or {}
    local key = keyOf(player)
    if not key then return false, "Your character is not loaded yet." end
    local course
    if opts.draft then course = opts.draft
    else
        course = courses[courseId]
        if not course or not published(course) then return false, "That course is not available." end
    end
    local existing = runs[player]
    if existing and existing.course.id == course.id and not opts.draft and existing.phase ~= "loading" and existing.phase ~= "landing" then
        return M.restart(player)
    end
    local life = Open77.players.getLifeState and Open77.players.getLifeState(player)
    if life and life.phase ~= "alive" then return false, "You cannot start a run now." end
    if existing then endRun(player, "switched", { release = false }) end
    local entered = existing and existing.entered or false
    if not entered then
        local owner = type(A.owner) == "function" and A.owner(player) or nil
        if owner and owner ~= ACT then return false, "Leave your current activity first." end
        if owner ~= ACT and type(A.enter) == "function" then
            local ok, why = A.enter(player, ACT, {})
            if not ok then return false, why or "You cannot start a run right now." end
        end
        entered = true
    end
    local run = { player = player, key = key, name = nameOf(player), course = copy(course), test = opts.draft ~= nil or nil,
        entered = entered, attempt = 0 }
    run.targets = targetsOf(run.course)
    if not run.test then
        run.best = personalBest(course.id, key)
        run.record = recordOf(course.id)
        if Db.ready then CreateThread(function() Db.run("UPDATE lightrp_parkour_courses SET attempts = attempts + 1 WHERE id = ?", { course.id }) end) end
        local stored = courses[course.id]
        if stored then stored.attempts = (stored.attempts or 0) + 1 end
    end
    runs[player] = run
    protect(player, run)
    log("parkour: %s starts %s%s", run.name, course.name, run.test and " (staff test)" or "")
    emitStatus()
    CreateThread(function()
        local ok, err = pcall(begin, player, run)
        if not ok then log("parkour: start of %d failed: %s", player, tostring(err)); endRun(player, "error") end
    end)
    return true
end

function M.restart(player)
    local run = runs[player]
    if not run then return false, "You are not running a course." end
    local t = now()
    if run.phase == "loading" or run.phase == "landing" or t - (run.restartedAt or -1e9) < C.restartCooldownMs then return false, "pending" end
    run.restartedAt = t
    CreateThread(function()
        local ok, err = pcall(begin, player, run)
        if not ok then log("parkour: restart of %d failed: %s", player, tostring(err)); endRun(player, "error") end
    end)
    return true
end

-- Back on the last checkpoint passed (the start before the first), clock running.
function M.toCheckpoint(player, why)
    local run = runs[player]
    if not run or run.phase ~= "running" or run.teleporting then return false end
    local t = now()
    if t - (run.returnedAt or -1e9) < 1000 then return false end
    run.returnedAt = t
    local point = run.last > 0 and run.course.checkpoints[run.last] or run.course.start
    local heading = run.course.start.heading
    local target = run.targets[run.next]
    if target then heading = math.deg(math.atan(-(target.x - point.x), target.y - point.y)) % 360 end
    send(player, { kind = "respawn", reason = why or "key", checkpoint = run.last })
    CreateThread(function() teleport(player, run, point, heading) end)
    return true
end

local function coreResult(player, run, timeMs, saved)
    if type(A.result) ~= "function" or run.test then return end
    pcall(A.result, player, ACT, { placement = saved and saved.rank or nil, won = saved and saved.rank == 1 or false,
        stats = { courseId = run.course.id, courseRevision = run.course.revision, timeMs = timeMs, finished = true,
            checkpoints = #run.course.checkpoints, personalBest = saved and saved.improved or false } })
end

local function finish(player, run, elapsed)
    run.phase, run.timeMs, run.finishedAt = "finished", elapsed, now()
    send(player, { kind = "finish", timeMs = elapsed, splits = P.encodeSplits(run.splits), attempt = run.attempt })
    CreateThread(function()
        local result = { kind = "result", timeMs = elapsed, splits = P.encodeSplits(run.splits), attempt = run.attempt, test = run.test,
            checkpoints = #run.course.checkpoints, course = run.course.id, name = run.course.name }
        if not run.test then
            local saved, why = saveTime(run, player, elapsed)
            if saved then
                result.improved, result.rank, result.total = saved.improved or nil, saved.rank, saved.total
                result.previous = saved.previous and { timeMs = saved.previous.timeMs } or nil
                local record = recordOf(run.course.id)
                result.record = record and { timeMs = record.timeMs, name = record.name } or nil
                result.recordBroken = saved.rank == 1 and saved.improved or nil
                local top = boardRows(run.course.id, 1, run.key)
                result.top = {}
                for i = 1, math.min(5, #(top and top.rows or {})) do
                    local r = top.rows[i]
                    result.top[i] = { rank = r.rank, name = r.name, timeMs = r.timeMs, me = r.me }
                end
                if saved.improved then
                    run.best = { timeMs = elapsed, splits = copy(run.splits) }
                    run.record = recordOf(run.course.id)
                end
                coreResult(player, run, elapsed, saved)
                log("parkour: %s finished %s in %s (rank %s/%s%s)", run.name, run.course.name, P.formatTime(elapsed),
                    tostring(saved.rank), tostring(saved.total), saved.improved and ", personal best" or "")
                if result.recordBroken and run.record then
                    -- the city hears about a new course record
                    for _, raw in ipairs(GetPlayers()) do
                        local id = tonumber(raw)
                        if id and id ~= player then
                            LightRP.notice(id, { kind = "info", title = "PARKOUR RECORD", durationMs = 6000,
                                body = ("%s set the record of %s: %s"):format(run.name, run.course.name, P.formatTime(elapsed)) })
                        end
                    end
                end
            else
                result.error = why or "The time could not be saved."
            end
        end
        if runs[player] == run and run.phase == "finished" and run.timeMs == elapsed then
            run.result = result
            send(player, result)
        end
    end)
end

local function dnf(player, run, reason, text)
    run.phase, run.dnf, run.finishedAt = "finished", reason, now()
    send(player, { kind = "dnf", reason = reason, text = text, attempt = run.attempt, checkpoint = run.last, checkpoints = #run.course.checkpoints })
    log("parkour: %s did not finish %s (%s)", run.name, run.course.name, reason)
end

local function checkpoint(player, run, elapsed)
    local i = run.next
    run.splits[i], run.last, run.next = elapsed, i, i + 1
    local pb = run.best and run.best.splits[i]
    local rec = run.record and run.record.splits[i]
    send(player, { kind = "cp", index = i, total = #run.course.checkpoints, elapsedMs = elapsed, bestMs = pb, recordMs = rec, attempt = run.attempt })
end

local function sample(player, run, t)
    local p = positionOf(player)
    if not p then return end
    local life = Open77.players.getLifeState and Open77.players.getLifeState(player)
    if life and life.phase ~= "alive" then
        if life.phase == "dead" and not run.recovering then
            run.recovering = true
            local point = run.last > 0 and run.course.checkpoints[run.last] or run.course.start
            SetTimeout(400, function()
                run.recovering = false
                if runs[player] ~= run then return end
                local ok, why = Open77.players.respawn(player, { position = { x = point.x, y = point.y, z = point.z },
                    heading = run.course.start.heading or 0, health = 1.0, graceMs = 2000 })
                if ok then
                    run.prev, run.graceUntil = nil, now() + 1500
                    protect(player, run)
                    send(player, { kind = "respawn", reason = "died", checkpoint = run.last })
                else log("parkour: respawn of %d failed: %s", player, tostring(why)) end
            end)
        end
        run.prev = nil
        return
    end
    local limit = (run.course.timeLimit or 0) > 0 and run.course.timeLimit * 60000 or C.maxRunMinutes * 60000
    if t - run.startedAt > limit then dnf(player, run, "time", "Time limit reached."); return end
    if run.prev then
        local prev, dt = run.prev, t - run.prevT
        if t > (run.graceUntil or 0) then
            local step = P.distance(prev, p)
            local h = math.sqrt((p.x - prev.x) ^ 2 + (p.y - prev.y) ^ 2)
            if step > C.maxStepM then dnf(player, run, "teleported", "You left the course (moved too far at once)."); return end
            if dt > 0 and h > 6 and h / (dt / 1000) > C.maxSpeed then dnf(player, run, "too_fast", "Too fast for a runner (a vehicle?)."); return end
        end
        local a = { x = prev.x, y = prev.y, z = prev.z + LIFT }
        local b = { x = p.x, y = p.y, z = p.z + LIFT }
        local tA = run.prevT
        while run.phase == "running" do
            local target = run.targets[run.next]
            if not target then break end
            local f = P.segmentEnters(a, b, { x = target.x, y = target.y, z = target.z + LIFT }, target.radius)
            if not f then break end
            local at = tA + f * (t - tA)
            local elapsed = math.max(0, math.floor(at - run.startedAt + 0.5))
            a = { x = a.x + (b.x - a.x) * f, y = a.y + (b.y - a.y) * f, z = a.z + (b.z - a.z) * f }
            tA = at
            if run.next >= #run.targets then finish(player, run, elapsed); return end
            checkpoint(player, run, elapsed)
        end
    end
    if run.course.floorZ and p.z < run.course.floorZ and t > (run.graceUntil or 0) then
        run.prev = nil
        M.toCheckpoint(player, "fell")
        return
    end
    run.prev, run.prevT = p, t
end

CreateThread(function()
    while true do
        Wait(C.tickMs)
        local t = now()
        for player, run in pairs(runs) do
            if run.phase == "running" and not run.teleporting and run.startedAt then
                local ok, err = pcall(sample, player, run, t)
                if not ok then log("parkour: sample of %d failed: %s", player, tostring(err)) end
            elseif run.phase == "finished" and t - (run.finishedAt or t) > C.resultHoldMs then
                endRun(player, run.dnf and "dnf" or "finished")
            end
        end
    end
end)

-- The run keys (client/core/parkour.lua).
RegisterNetEvent(NET_KEY, function(p)
    local player = tonumber(source)
    if not player or type(p) ~= "table" then return end
    -- landed on the start (no loading screen any more): the countdown may begin. Not a key: no throttle.
    if p.op == "landed" then
        local run = runs[player]
        if run and run.phase == "landing" and tonumber(p.attempt) == run.attempt then run.landed = run.attempt end
        return
    end
    local t = now()
    if t - (lastKey[player] or -1e9) < 250 then return end
    lastKey[player] = t
    if p.op == "restart" then M.restart(player)
    elseif p.op == "checkpoint" then M.toCheckpoint(player, "key")
    elseif p.op == "leave" then endRun(player, "left")
    end
end)

-- The activity core: a join from the Activities panel, a leave from F1, a drop.
AddEventHandler("op77_lightrp:activity:join", function(player, activityId, options)
    if activityId ~= ACT then return end
    player = tonumber(player)
    if not player then return end
    local course = type(options) == "table" and options.course or nil
    if type(course) ~= "string" or not published(courses[course]) then
        course = nearCourse(player)
        for _, id in ipairs(order) do if not course and published(courses[id]) then course = id end end
    end
    if not course then LightRP.notice(player, { kind = "warning", title = "PARKOUR", body = "No course is open yet." }); return end
    local ok, why = M.start(player, course, {})
    if not ok then LightRP.notice(player, { kind = "warning", title = "PARKOUR", body = tostring(why) }) end
end)
AddEventHandler("op77_lightrp:activity:leaveRequest", function(player, activityId)
    if activityId ~= ACT then return end
    endRun(tonumber(player), "left")
end)
AddEventHandler("op77_lightrp:activity:dropped", function(player, activityId)
    if activityId ~= ACT then return end
    player = tonumber(player)
    local run = player and runs[player]
    if run then runs[player] = nil; unprotect(player, run); send(player, { kind = "ended", reason = "dropped" }); emitStatus() end
end)

function M.onDisconnected(player)
    local run = runs[player]
    runs[player], editors[player], lastKey[player], lastEdit[player] = nil, nil, nil, nil
    if run then emitStatus() end
end
function M.onCharacterActivated(player) pushCourses(player) end
-- The page is up again (reconnect, a reload): the courses, and the run going on if any.
function M.onUiReady(player)
    pushCourses(player)
    local run = runs[player]
    if run then
        send(player, { kind = "run", phase = run.phase, course = runPayload(run), attempt = run.attempt, resume = true,
            elapsedMs = run.startedAt and (now() - run.startedAt) or nil, checkpoint = run.last, music = C.music,
            best = run.best and { timeMs = run.best.timeMs, splits = P.encodeSplits(run.best.splits) } or nil,
            record = run.record and { timeMs = run.record.timeMs, name = run.record.name, splits = P.encodeSplits(run.record.splits) } or nil })
    end
end

-- ---------------------------------------------------------------------------
-- Staff editor (request / response, like the mission editor)

function M.allowed(player)
    if not player or player <= 0 or type(Open77.acl) ~= "table" or type(Open77.acl.isAllowed) ~= "function" then return false end
    local ok, value = pcall(Open77.acl.isAllowed, player, C.permission)
    return ok and value == true
end

local function editorView(course)
    local b = boards[course.id]
    return { id = course.id, revision = course.revision, status = course.status, name = course.name, description = course.description,
        difficulty = course.difficulty, start = course.start, checkpoints = course.checkpoints, finish = course.finish,
        timeLimit = course.timeLimit, floorZ = course.floorZ, length = course.length, authorName = course.authorName,
        attempts = course.attempts or 0, finishes = course.finishes or 0, runners = b and math.max(b.total or 0, #b.rows) or nil,
        record = (function() local r = recordOf(course.id); return r and { timeMs = r.timeMs, name = r.name } or nil end)() }
end

local function newId()
    sequence = sequence + 1
    return ("pk%x%03x%02x"):format(unix(), math.random(0, 0xfff), sequence % 256)
end

local function save(player, p)
    local course, why = P.validate(p.course)
    if not course then return nil, why end
    local id = type(p.course.id) == "string" and p.course.id ~= "" and p.course.id or nil
    local old = id and courses[id]
    if id and not old then return nil, "This course no longer exists. Reopen the list." end
    if old and tonumber(p.baseRevision) and tonumber(p.baseRevision) ~= old.revision then
        return nil, "Someone else saved this course meanwhile. Reopen it to see their version."
    end
    local status = p.status == "draft" and "draft" or p.status == "published" and "published" or (old and old.status) or "published"
    local revision = old and old.revision or 1
    local reset = old and P.routeKey(old) ~= P.routeKey(course)
    if reset then revision = revision + 1 end
    course.id = id or newId()
    course.revision, course.status = revision, status
    course.author = old and old.author or (GetPlayerIdentifier and GetPlayerIdentifier(player) or "")
    course.authorName = old and old.authorName or nameOf(player)
    course.attempts, course.finishes = old and old.attempts or 0, old and old.finishes or 0
    if Db.ready then
        local data = json.encode(stored(course))
        local ok
        if old then
            ok = Db.run("UPDATE lightrp_parkour_courses SET name = ?, data = ?, revision = ?, status = ? WHERE id = ? AND deleted_at IS NULL",
                { course.name, data, revision, status, course.id })
        else
            ok = Db.run([[INSERT INTO lightrp_parkour_courses (id, name, data, revision, status, author_id, author_name) VALUES (?, ?, ?, ?, ?, ?, ?)]],
                { course.id, course.name, data, revision, status, tostring(course.author or ""):sub(1, 128), course.authorName })
        end
        if not ok then return nil, "The course could not be saved." end
    end
    courses[course.id] = course
    if reset then boards[course.id] = nil end
    changed()
    log("parkour: %s %s course %s \"%s\" (revision %d, %s%s)", nameOf(player), old and "saved" or "created", course.id, course.name,
        revision, status, reset and ", new leaderboard" or "")
    return { course = editorView(course), reset = reset or nil }
end

local function setStatus(player, p)
    local course = type(p.id) == "string" and courses[p.id]
    if not course then return nil, "This course no longer exists." end
    local status = p.status == "published" and "published" or "draft"
    if Db.ready and not Db.run("UPDATE lightrp_parkour_courses SET status = ? WHERE id = ?", { status, course.id }) then
        return nil, "The change could not be saved."
    end
    course.status = status
    changed()
    log("parkour: %s set course %s to %s", nameOf(player), course.id, status)
    return { course = editorView(course) }
end

local function remove(player, p)
    local course = type(p.id) == "string" and courses[p.id]
    if not course then return nil, "This course no longer exists." end
    if Db.ready and not Db.run("UPDATE lightrp_parkour_courses SET deleted_at = CURRENT_TIMESTAMP WHERE id = ?", { course.id }) then
        return nil, "The deletion could not be saved."
    end
    courses[course.id], boards[course.id] = nil, nil
    LightRP.removeInteraction("parkour." .. course.id)
    changed()
    log("parkour: %s deleted course %s \"%s\"", nameOf(player), course.id, course.name)
    return { deleted = course.id }
end

local function resetBoard(player, p)
    local course = type(p.id) == "string" and courses[p.id]
    if not course then return nil, "This course no longer exists." end
    local revision = course.revision + 1
    if Db.ready and not Db.run("UPDATE lightrp_parkour_courses SET revision = ? WHERE id = ?", { revision, course.id }) then
        return nil, "The reset could not be saved."
    end
    course.revision = revision
    boards[course.id] = nil
    changed()
    log("parkour: %s reset the leaderboard of %s (revision %d)", nameOf(player), course.id, revision)
    return { course = editorView(course) }
end

local function test(player, p)
    local course, why = P.validate(p.course)
    if not course then return nil, why end
    course.id = type(p.course.id) == "string" and p.course.id ~= "" and p.course.id or "draft"
    course.revision, course.status = 0, "draft"
    local ok, err = M.start(player, nil, { draft = course })
    if not ok then return nil, err end
    editors[player] = nil
    return { started = true }
end

local function dispatch(player, p)
    if not M.allowed(player) then return nil, "Parkour editor permission required." end
    local op = p.operation
    if op == "list" then
        editors[player] = true
        local list = {}
        for _, id in ipairs(order) do list[#list + 1] = editorView(courses[id]) end
        return { ready = loaded or not Db.ready, courses = list }
    elseif op == "save" or op == "status" or op == "delete" or op == "reset" then
        local actor = GetPlayerIdentifier and GetPlayerIdentifier(player) or tostring(player)
        local key = type(p.mutation) == "string" and #p.mutation >= 8 and #p.mutation <= 96 and p.mutation or nil
        if not key then return nil, "Invalid request." end
        done[actor] = done[actor] or {}
        if done[actor][key] then return done[actor][key] end
        local result, why
        if op == "save" then result, why = save(player, p)
        elseif op == "status" then result, why = setStatus(player, p)
        elseif op == "delete" then result, why = remove(player, p)
        else result, why = resetBoard(player, p) end
        if result then done[actor][key] = result end
        return result, why
    elseif op == "test" then return test(player, p)
    elseif op == "goto" then
        local course = type(p.id) == "string" and courses[p.id]
        if not course then return nil, "This course no longer exists." end
        local finished, ok, why = false, false, nil
        LightRP.staff.moveTo(player, { x = course.start.x, y = course.start.y, z = course.start.z }, course.start.heading or 0,
            function(success, failure) ok, why, finished = success, failure, true end)
        local waited = 0
        while not finished and waited < 15000 do Wait(20); waited = waited + 20 end
        if not ok then return nil, "Teleport refused: " .. tostring(why or "timeout") end
        return { moved = true }
    end
    return nil, "Unknown parkour editor operation."
end

RegisterNetEvent(NET_EDIT, function(p)
    local player = tonumber(source)
    if not player or player <= 0 or type(p) ~= "table" or type(p.request) ~= "string" or #p.request > 96 or type(p.operation) ~= "string" then return end
    local t = now()
    if t - (lastEdit[player] or -1e9) < 150 then
        TriggerClientEvent(NET_EDIT, player, { kind = "response", request = p.request, ok = false, error = "Please wait before the next request." })
        return
    end
    lastEdit[player] = t
    local ok, data, err = pcall(dispatch, player, p)
    if not ok then log("parkour editor request failed: %s", tostring(data)); data, err = nil, "The server could not complete this request." end
    deliver(player, NET_EDIT, { kind = "response", request = p.request, ok = data ~= nil, data = data, error = err })
end)

-- ---------------------------------------------------------------------------
-- Commands

LightRP.command("parkour", { restricted = false, usage = "/parkour (the courses and their leaderboards)" }, function(player)
    if not player or player <= 0 then return false, "Only in game." end
    M.openBrowser(player)
    return nil
end)
LightRP.command("parkour.leave", { restricted = false, usage = "/parkour.leave" }, function(player)
    if not runs[player] then return false, "You are not running a course." end
    endRun(player, "left")
    return true, "You left the course."
end)
LightRP.command("lightrp.parkour", { restricted = true, usage = "/lightrp.parkour (the parkour editor)" }, function(player)
    if not M.allowed(player) then return false, "Parkour editor permission required." end
    if runs[player] then return false, "Leave your run first (/parkour.leave)." end
    TriggerClientEvent(NET_EDIT, player, { kind = "open" })
    return true, "Parkour editor opened."
end)

-- ---------------------------------------------------------------------------
-- Loading

function M.onDatabaseReady()
    local ok, rows = Db.read([[SELECT id, name, data, revision, status, author_id, author_name, attempts, finishes,
        UNIX_TIMESTAMP(created_at) AS created, UNIX_TIMESTAMP(updated_at) AS updated
        FROM lightrp_parkour_courses WHERE deleted_at IS NULL]], {})
    if not ok then log("parkour: courses could not be read; parkour is off until a restart"); return end
    courses, boards = {}, {}
    for _, r in ipairs(rows) do addCourse(r) end
    loaded = true
    changed()
    local n = 0
    for _ in pairs(courses) do n = n + 1 end
    log("parkour: %d course(s) loaded", n)
end

M.courses, M.runs = function() return courses end, function() return runs end

CreateThread(function()
    registerActivity()
    Wait(5000)
    if not Db.ready and not loaded and not (Db.available and Db.available()) then
        loaded = true
        log("parkour: no database, courses made now last this session only")
    end
end)

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    for player, run in pairs(runs) do unprotect(player, run) end
end)
