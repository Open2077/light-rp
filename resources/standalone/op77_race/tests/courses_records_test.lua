-- Course catalogue (built-ins, validation, saved files) and the time-trial board.
local H = dofile("tests/harness.lua")
H.load({ "shared/config.lua", "shared/race.lua", "server/builtin_courses.lua", "server/courses.lua", "server/records.lua" })
local C, R = RaceCourses, RaceRecords

H.test("built-in courses load and validate", function()
    H.eq(C.load(), 3, "three courses")
    local street = C.get("street-circuit")
    H.ok(street, "street circuit")
    H.eq(#street.grid, 8, "eight surveyed slots")
    H.eq(#street.checkpoints, 44)
    H.eq(street.checkpoints[1].id, "cp_001")
    H.ok(street.builtin)
    local roof = C.get("rooftop-run")
    H.ok(RaceShared.onFoot(roof), "on foot")
    H.eq(#roof.grid, 0)
end)

H.test("eligibility per activity", function()
    H.eq(#C.ids("trial"), 3, "the trial runs every course")
    H.eq(#C.ids("grid"), 2, "street races: vehicle courses")
    H.eq(#C.ids("foot"), 1, "rooftop races: on-foot courses")
    H.eq(C.capacity(C.get("street-circuit"), 8), 8)
    H.eq(C.capacity(C.get("rooftop-run"), 8), 8)
end)

H.test("get returns a copy", function()
    local a = C.get("shion-sprint")
    a.name = "changed"
    H.eq(C.get("shion-sprint").name ~= "changed", true)
end)

local function draft(overrides)
    local d = {
        name = "Test loop", type = "circuit", laps = 2, vehicle = "archer_hella",
        start = { position = { x = 0, y = 0, z = 0 }, heading = 0 },
        grid = { { position = { x = 0, y = 0, z = 0 }, heading = 0 }, { position = { x = 4, y = 0, z = 0 }, heading = 0 } },
        checkpoints = { { position = { x = 0, y = 50, z = 0 } }, { position = { x = 50, y = 50, z = 0 } } },
    }
    for k, v in pairs(overrides or {}) do d[k] = v end
    return d
end

H.test("validation rejects broken courses", function()
    H.eq(select(2, C.normalize(draft({ start = false }))), "start_missing")
    H.eq(select(2, C.normalize(draft({ grid = {} }))), "not_enough_grid_slots")
    H.eq(select(2, C.normalize(draft({ checkpoints = { { position = { x = 1, y = 1, z = 1 } } } }))), "not_enough_checkpoints")
    H.eq(select(2, C.normalize(draft({ vehicle = "tank" }))), "invalid_vehicle")
    H.eq(select(2, C.normalize(draft({ name = "x" }))), "name_too_short")
    H.eq(select(2, C.normalize(draft({ grid = { { position = { x = 0, y = 0, z = 0 } }, { position = { x = 1, y = 0, z = 0 } } } }))),
        "grid_slots_overlap")
    H.eq(select(2, C.normalize(draft({ checkpoints = { { position = { x = 0 / 0, y = 0, z = 0 } }, { position = { x = 1, y = 1, z = 1 } } } }))),
        "invalid_checkpoint_position")
    local sprint = C.normalize(draft({ type = "sprint", laps = 5, checkpoints = { { position = { x = 1, y = 1, z = 1 } } } }))
    H.eq(sprint.laps, 1, "a sprint is one lap")
end)

H.test("saving: new course, revision, built-ins read-only", function()
    local saved = assert(C.save(7, draft(), "Staff", nil))
    H.ok(H.files["courses/" .. saved.id .. ".json"], "written to data/courses")
    H.eq(saved.revision, 1)
    saved.laps = 3
    local again = assert(C.save(7, saved, "Staff", nil))
    H.eq(again.id, saved.id); H.eq(again.revision, 2)
    local copy = C.get("street-circuit")
    copy.name = "My street"
    local fromBuiltin = assert(C.save(7, copy, "Staff", nil))
    H.ok(fromBuiltin.id ~= "street-circuit", "a built-in is saved as a copy")
    H.eq(C.get("street-circuit").name, "Street Circuit", "built-in untouched")
    H.eq(select(2, C.remove("street-circuit")), "builtin_readonly")
    H.ok(C.remove(fromBuiltin.id))
    H.eq(H.files["courses/" .. fromBuiltin.id .. ".json"], nil)
end)

H.test("loading saved files; a file cannot shadow a built-in", function()
    local d = draft({ name = "Shadow" })
    d.schemaVersion = 2
    H.files["courses/street-circuit.json"] = d
    H.files["courses/bad.json"] = { schemaVersion = 1 }
    local count = C.load()
    H.eq(C.get("street-circuit").name, "Street Circuit")
    H.ok(count >= 4, "built-ins plus the saved test loop")
end)

H.test("records: personal best, course record, rank", function()
    R.load()
    local first = R.submit("street-circuit", 3, "a", "Ann", 90000, "rayfield_caliburn")
    H.ok(first.personalBest and first.courseRecord)
    H.eq(first.rank, 1)
    local second = R.submit("street-circuit", 3, "b", "Bob", 95000)
    H.ok(second.personalBest and not second.courseRecord)
    H.eq(second.rank, 2)
    local slower = R.submit("street-circuit", 3, "a", "Ann", 99000)
    H.ok(not slower.personalBest, "slower is not a PB")
    H.eq(slower.previousBestMs, 90000)
    H.eq(R.best("street-circuit", 3, "a").timeMs, 90000, "the best stays")
    local record = R.submit("street-circuit", 3, "b", "Bob", 80000)
    H.ok(record.courseRecord and record.personalBest)
    H.eq(record.previousRecordMs, 90000)
    H.eq(R.record("street-circuit", 3).name, "Bob")
    local top = R.top("street-circuit", 3, 5)
    H.eq(#top, 2); H.eq(top[1].name, "Bob"); H.eq(top[1].key, nil, "no account keys in display rows")
end)

H.test("records persist and a new revision starts a fresh board", function()
    local stored = H.files["records.json"]
    H.ok(stored and stored.schemaVersion == 1, "written")
    R.load()
    H.eq(R.best("street-circuit", 3, "b").timeMs, 80000, "reloaded")
    H.eq(R.record("street-circuit", 4), nil, "revision 4 has no record")
    local fresh = R.submit("street-circuit", 4, "a", "Ann", 99999)
    H.ok(fresh.courseRecord, "first time on the new revision")
    H.eq(R.submit("street-circuit", 4, "a", "Ann", -1), nil, "invalid time refused")
end)

H.done("courses_records_test")
