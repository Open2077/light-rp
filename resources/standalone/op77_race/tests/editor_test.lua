-- Staff course editor: the restricted command opens the session, the keys only work
-- with one, points come from the server's positions, saved courses join the catalogue.
local H = dofile("tests/harness.lua")
H.addPlayer(1, "Staff", { x = 0, y = 0, z = 10, bucket = 0 })
H.addPlayer(2, "Player", { x = 0, y = 0, z = 10, bucket = 0 })
H.load(H.SERVER)
local Ed = RaceEditor

H.test("the editor command is restricted (ACL command.race.editor)", function()
    H.eq(H.commands["race.editor"].restricted, true)
    H.eq(H.commands["race.force"].restricted, true)
    H.eq(H.commands["race"].restricted, false)
    H.eq(H.commands["timetrial"].restricted, false)
end)

H.test("editor keys do nothing without a session", function()
    H.fireNet("op77_race:editorAction", 2, { action = "checkpoint", heading = 0 })
    H.eq(Ed.sessions[2], nil)
    H.eq(H.lastClient("op77_race:editor", 2), nil)
end)

H.test("capture start, grid and checkpoints from the server's position", function()
    H.command("race.editor", 1, { "open" })
    H.ok(Ed.sessions[1], "session open")
    H.fireNet("op77_race:editorAction", 1, { action = "start", heading = 370, x = 999 })
    local draft = Ed.sessions[1].draft
    H.eq(draft.start.position.x, 0, "client coordinates ignored")
    H.eq(draft.start.heading, 10, "heading wrapped")
    H.advance(300)
    H.fireNet("op77_race:editorAction", 1, { action = "grid", heading = 0 })
    H.advance(300)
    H.move(1, 0, -5, 10)
    H.fireNet("op77_race:editorAction", 1, { action = "grid", heading = 0 })
    H.eq(#draft.grid, 2)
    for i = 1, 3 do
        H.move(1, i * 40, 0, 10)
        H.advance(300)
        H.fireNet("op77_race:editorAction", 1, { action = "checkpoint", heading = 90 })
    end
    H.eq(#draft.checkpoints, 3)
    H.command("race.editor", 1, { "undo" })
    H.eq(#draft.checkpoints, 2)
    H.ok(H.lastClient("op77_race:editor", 1).args[1].draft, "preview pushed")
end)

H.test("captures refuse an instance bucket", function()
    H.players[1].bucket = 4200001
    local ok, reason = Ed.action(1, "checkpoint")
    H.eq(ok, false); H.eq(reason, "editor_world_required")
    H.players[1].bucket = 0
end)

H.test("name, laps, save; the course joins the catalogue", function()
    H.command("race.editor", 1, { "name", "Harbour", "Loop" }, "race.editor name Harbour Loop")
    H.command("race.editor", 1, { "laps", "2" })
    local registrations = #H.coreCalls("activityRegister")
    H.command("race.editor", 1, { "save" })
    H.eq(#H.coreCalls("activityRegister"), registrations + 3, "a saved course registers again (trial choices)")
    local draft = Ed.sessions[1].draft
    H.ok(draft.id, "saved with an id")
    H.eq(draft.name, "Harbour Loop")
    H.eq(draft.laps, 2)
    local course = RaceCourses.get(draft.id)
    H.ok(course and RaceCourses.eligible(course, "grid"), "a street race course now")
    H.ok(H.files["courses/" .. draft.id .. ".json"])
    H.command("race.editor", 1, { "close" })
    H.eq(Ed.sessions[1], nil)
    H.eq(H.lastClient("op77_race:editor", 1).args[1], false, "preview cleared")
end)

H.test("a racer cannot open the editor", function()
    H.fire("op77_lightrp:activity:join", 2, "race.trial", {})
    H.command("race.editor", 2, { "open" })
    H.eq(Ed.sessions[2], nil)
end)

H.done("editor_test")
