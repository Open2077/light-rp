-- The contract adapter: registration, pcall wrapping of the synchronous exports,
-- sentences, status sent on change only, result events.
local H = dofile("tests/harness.lua")
H.load({ "shared/config.lua", "shared/race.lua", "server/activity.lua" })
local A = RaceActivity

H.test("registration matches the contract", function()
    H.ok(A.register(), "all three accepted")
    H.ok(A.registered)
    local def = H.core.registered["race.trial"]
    H.eq(def.resource, "op77_race")
    H.eq(def.kind, "race")
    H.eq(def.minPlayers, 1); H.eq(def.maxPlayers, 1)
    H.eq(def.caps.rpWeapons, false); H.eq(def.caps.rpItems, false); H.eq(def.caps.needs, false); H.eq(def.caps.vehicles, false)
    H.eq(H.core.registered["race.grid"].maxPlayers, 8)
    H.eq(def.modeKey, "course", "a trial is joined with a course")
    H.eq(H.core.registered["race.grid"].modeKey, nil); H.eq(H.core.registered["race.grid"].modes, nil)
    H.eq(H.core.registered["race.foot"].minPlayers, 2)
    -- the race vs AI is PvE and plays Light RP's difficulties; the course stays the choice
    local pve = H.core.registered["race.pve"]
    H.eq(pve.pve, true); H.eq(pve.modeKey, "course")
    H.eq(table.concat(pve.difficulties, ","), "standard,hard,critical")
    H.eq(H.core.registered["race.grid"].pve, nil); H.eq(H.core.registered["race.grid"].difficulties, nil)
    -- no AI racer code loaded here: no bot fill offered anywhere
    for _, id in ipairs({ "race.trial", "race.grid", "race.foot", "race.pve" }) do
        H.eq(H.core.registered[id].botFill, nil, id .. " offers no bot fill")
    end
end)

H.test("a refused registration is retried later", function()
    H.core.refuseRegister = true
    H.ok(not A.register())
    H.ok(not A.registered)
    H.core.refuseRegister = false
    H.ok(A.register())
end)

H.test("an export that raises becomes false, reason", function()
    local saved = exports.op77_lightrp
    exports.op77_lightrp = setmetatable({}, { __index = function() error("export_yielded") end })
    local ok, why = A.check(1, "race.trial")
    H.eq(ok, false)
    H.eq(why, "Light RP is not ready yet. Try again in a moment.")
    exports.op77_lightrp = nil
    H.eq(select(2, A.call("activityOwner", 1)):match("^core_error") ~= nil, true, "missing core")
    H.eq(A.owner(1), nil)
    H.eq(A.player(1), nil)
    exports.op77_lightrp = saved
end)

H.test("the core's sentence reaches the player", function()
    H.addPlayer(3, "Cat")
    H.core.eligible[3] = "You are in a vehicle."
    local ok, why = A.check(3, "race.trial")
    H.eq(ok, false); H.eq(why, "You are in a vehicle.")
    H.core.eligible[3] = nil
    H.ok(A.check(3, "race.trial"))
    H.ok(A.enter(3, "race.trial"))
    H.eq(A.owner(3), "race.trial")
    H.ok(A.leave(3, "race.trial"))
    local leave = H.coreCalls("activityLeave", 3)[1]
    H.eq(leave.args[3].returnPlayer, true, "returnPlayer defaults to true")
end)

H.test("character key", function()
    H.eq(A.characterKey({ identifier = "license:1", characterKey = 2 }), "license:1/2")
    H.eq(A.characterKey({ identifier = "license:1" }), "license:1/default")
    H.eq(A.characterKey(nil), nil)
end)

H.test("status is sent on change only", function()
    local before = #H.eventsNamed("op77_lightrp:activity:status")
    local status = { phase = "idle", players = 0, queued = 0, joinable = true, detail = "3 courses" }
    H.ok(A.status("race.trial", status))
    H.ok(not A.status("race.trial", status), "unchanged")
    H.ok(A.status("race.trial", { phase = "running", players = 1, queued = 0, joinable = true, detail = "1 on the clock" }))
    H.ok(A.status("race.trial", status, true), "forced")
    H.ok(not A.status("race.other", status), "not ours")
    local sent = H.eventsNamed("op77_lightrp:activity:status")
    H.eq(#sent - before, 3)
    H.eq(sent[#sent].args[1], "race.trial")
end)

H.test("results go through the host bus, only for our activities", function()
    H.ok(A.result(3, "race.trial", { placement = 1, score = 1, won = true, stats = { timeMs = 1 }, reputation = 5 }))
    H.ok(not A.result(3, "arena.duel", {}))
    local sent = H.eventsNamed("op77_lightrp:activity:result")
    H.eq(#sent, 1)
    H.eq(sent[1].args[1], 3); H.eq(sent[1].args[2], "race.trial")
end)

H.done("activity_test")
