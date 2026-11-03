-- Time-trial best times, one board per course revision, in data/records.json (Open77.io,
-- this resource's own data directory). A character keeps one entry per course: its
-- personal best. Editing a course (new revision) starts a fresh board. Only finished
-- time-trial runs reach the course boards; grid starts are not comparable and stay out.
-- Races vs AI keep a separate personal best per course under "vsai:<courseId>"; a street
-- or rooftop race the staff switch filled with bots writes nothing at all.
-- Light RP still receives every result through the contract and keeps its own stats.
local Config = RaceConfig

RaceRecords = {}
local R = RaceRecords

local FILE = "records.json"
local SCHEMA = 1
local MAX_ENTRIES = 500
local boards = {}        -- courseId -> { revision, entries = { { key, name, timeMs, vehicle } } } fastest first
local available = false

local function log(text) print("[race:records] " .. tostring(text)) end

local function persist()
    if not available then return false end
    local ok, reason = Open77.io.writeJson(FILE, { schemaVersion = SCHEMA, courses = boards })
    if not ok then log("write failed: " .. tostring(reason)) end
    return ok == true
end

function R.load()
    boards = {}
    local stored, reason = Open77.io.readJson(FILE)
    available = true
    if stored == nil then
        if reason ~= nil and reason ~= "not_found" then log("unreadable, starting empty: " .. tostring(reason)) end
        return 0
    end
    if type(stored) ~= "table" or stored.schemaVersion ~= SCHEMA or type(stored.courses) ~= "table" then
        log("unsupported records file, starting empty")
        return 0
    end
    local count = 0
    for courseId, board in pairs(stored.courses) do
        if type(courseId) == "string" and type(board) == "table" and type(board.entries) == "table" then
            local entries = {}
            for _, entry in ipairs(board.entries) do
                local timeMs = tonumber(entry.timeMs)
                if type(entry.key) == "string" and timeMs and timeMs > 0 then
                    entries[#entries + 1] = { key = entry.key, name = tostring(entry.name or "?"):sub(1, 64),
                        timeMs = math.floor(timeMs), vehicle = entry.vehicle }
                end
            end
            table.sort(entries, function(a, b) return a.timeMs < b.timeMs end)
            boards[courseId] = { revision = tonumber(board.revision) or 1, entries = entries }
            count = count + #entries
        end
    end
    return count
end

local function board(courseId, revision)
    local current = boards[courseId]
    if current == nil or current.revision ~= revision then
        current = { revision = revision, entries = {} }
        boards[courseId] = current
    end
    return current
end

local function find(entries, key)
    for index, entry in ipairs(entries) do
        if entry.key == key then return index, entry end
    end
    return nil
end

-- Records a finished run. Returns what it meant: a personal best, a course record,
-- the previous best/record and the rank on the board.
function R.submit(courseId, revision, key, name, timeMs, vehicle)
    timeMs = math.floor(tonumber(timeMs) or 0)
    if type(courseId) ~= "string" or type(key) ~= "string" or timeMs <= 0 then return nil, "invalid_record" end
    local b = board(courseId, revision or 1)
    local previousRecord = b.entries[1] and b.entries[1].timeMs or nil
    local index, mine = find(b.entries, key)
    local previousBest = mine and mine.timeMs or nil
    local outcome = {
        personalBest = previousBest == nil or timeMs < previousBest,
        previousBestMs = previousBest,
        courseRecord = previousRecord == nil or timeMs < previousRecord,
        previousRecordMs = previousRecord,
    }
    if mine then mine.name = tostring(name or mine.name):sub(1, 64) end
    if outcome.personalBest then
        if index then table.remove(b.entries, index) end
        local entry = { key = key, name = tostring(name or "?"):sub(1, 64), timeMs = timeMs, vehicle = vehicle }
        local at = #b.entries + 1
        for i, other in ipairs(b.entries) do
            if timeMs < other.timeMs then at = i; break end
        end
        table.insert(b.entries, at, entry)
        while #b.entries > MAX_ENTRIES do table.remove(b.entries) end
        persist()
    end
    outcome.rank = find(b.entries, key)
    return outcome
end

-- The board of a course's best times against AI (race.pve): kept apart from the time
-- trial's, so no time set against bots ever ranks among the players' times.
function R.vsAiBoard(courseId) return "vsai:" .. tostring(courseId) end

function R.best(courseId, revision, key)
    local b = boards[courseId]
    if b == nil or b.revision ~= revision then return nil end
    local _, entry = find(b.entries, key)
    return entry
end

function R.record(courseId, revision)
    local b = boards[courseId]
    if b == nil or b.revision ~= revision then return nil end
    return b.entries[1]
end

-- The first n entries as display rows (no account keys leave the server).
function R.top(courseId, revision, n)
    local b = boards[courseId]
    local rows = {}
    if b == nil or b.revision ~= revision then return rows end
    for index = 1, math.min(n or Config.records.show, #b.entries) do
        local entry = b.entries[index]
        rows[#rows + 1] = { rank = index, name = entry.name, timeMs = entry.timeMs }
    end
    return rows
end

function R.rank(courseId, revision, key)
    local b = boards[courseId]
    if b == nil or b.revision ~= revision then return nil end
    return (find(b.entries, key))
end
