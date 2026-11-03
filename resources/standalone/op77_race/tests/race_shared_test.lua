-- Checkpoint geometry, grid slots, time format and the live ranking order.
local H = dofile("tests/harness.lua")
H.load({ "shared/config.lua", "shared/race.lua" })
local S = RaceShared

H.test("crossed: standing inside the cylinder counts", function()
    local target = { x = 10, y = 10, z = 5 }
    H.ok(S.crossed(nil, { x = 12, y = 11, z = 6, bucket = 1 }, target, 7, 4, 80))
end)

H.test("crossed: a fast pass between two samples counts", function()
    local target = { x = 0, y = 0, z = 0 }
    local before = { x = -30, y = 1, z = 0, bucket = 1 }
    local after = { x = 30, y = 1, z = 0, bucket = 1 }
    H.ok(S.crossed(before, after, target, 7, 4, 80), "swept segment through the ring")
end)

H.test("crossed: a road on another level does not count", function()
    local target = { x = 0, y = 0, z = 0 }
    H.ok(not S.crossed(nil, { x = 1, y = 1, z = 9, bucket = 1 }, target, 7, 4, 80), "endpoint above the tolerance")
    H.ok(not S.crossed({ x = -30, y = 0, z = 10, bucket = 1 }, { x = 30, y = 0, z = 10, bucket = 1 }, target, 7, 4, 80),
        "swept pass on a bridge above")
end)

H.test("crossed: a teleport or bucket change is not a pass", function()
    local target = { x = 0, y = 0, z = 0 }
    H.ok(not S.crossed({ x = -30, y = 0, z = 0, bucket = 2 }, { x = 30, y = 0, z = 0, bucket = 1 }, target, 7, 4, 80))
    H.ok(not S.crossed({ x = -100, y = 0, z = 0, bucket = 1 }, { x = 100, y = 0, z = 0, bucket = 1 }, target, 7, 4, 80),
        "segment longer than maxSegment")
end)

H.test("crossed: a pass that misses the ring does not count", function()
    local target = { x = 0, y = 0, z = 0 }
    H.ok(not S.crossed({ x = -30, y = 9, z = 0, bucket = 1 }, { x = 30, y = 9, z = 0, bucket = 1 }, target, 7, 4, 80))
end)

H.test("formatTime", function()
    H.eq(S.formatTime(83456), "1:23.456")
    H.eq(S.formatTime(0), "0:00.000")
    H.eq(S.formatTime(3723004), "1:02:03.004")
    H.eq(S.formatTime(-5), "0:00.000")
end)

H.test("grid slots: authored first, lanes behind the start otherwise", function()
    local course = { vehicle = "archer_hella", start = { position = { x = 0, y = 0, z = 0 }, heading = 0 },
        grid = { { position = { x = 5, y = 5, z = 1 }, heading = 90 } } }
    local first = S.gridSlot(course, 1, 2, RaceConfig.engine.startGrid)
    H.eq(first.position.x, 5); H.eq(first.heading, 90)
    local second = S.gridSlot(course, 2, 2, RaceConfig.engine.startGrid)
    H.ok(second.position.x ~= 5, "fallback lane")
    -- heading 0 faces +Y: the second row is behind (lower y).
    local third = S.gridSlot({ vehicle = "archer_hella", start = course.start, grid = {} }, 3, 4, RaceConfig.engine.startGrid)
    H.ok(third.position.y < 0, "row behind the start")
end)

H.test("foot slots line up behind the start", function()
    local course = { vehicle = "on_foot", start = { position = { x = 0, y = 0, z = 0 }, heading = 0 } }
    local a = S.gridSlot(course, 1, 3, nil, 2)
    local b = S.gridSlot(course, 3, 3, nil, 2)
    H.eq(a.position.y, 0)
    H.ok(math.abs(b.position.y + 4) < 1e-9, "4 m behind for the third runner")
end)

H.test("ranking: finished by place, then progress, then distance, out last", function()
    local rows = S.rankRows({
        { id = 1, state = "racing", progress = 5, distance = 30, grid = 1 },
        { id = 2, state = "finished", finishPlace = 2, grid = 2 },
        { id = 3, state = "dnf", grid = 3 },
        { id = 4, state = "racing", progress = 5, distance = 10, grid = 4 },
        { id = 5, state = "finished", finishPlace = 1, grid = 5 },
        { id = 6, state = "racing", progress = 7, grid = 6 },
    })
    local order = {}
    for _, row in ipairs(rows) do order[#order + 1] = row.id end
    H.eq(table.concat(order, ","), "5,2,6,4,1,3")
    H.eq(rows[1].rank, 1)
end)

H.test("route length", function()
    local course = { start = { position = { x = 0, y = 0, z = 0 } },
        checkpoints = { { position = { x = 3, y = 4, z = 0 } }, { position = { x = 3, y = 14, z = 0 } } } }
    H.eq(S.routeMetres(course), 15)
end)

H.done("race_shared_test")
