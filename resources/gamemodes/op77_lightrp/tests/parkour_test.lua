-- Parkour (shared/parkour.lua + server/modules/parkour.lua) with the host stubbed and no
-- database: the staff editor saves a course, players run it (start, countdown, crossings
-- interpolated between samples, finish), the board ranks the bests, a changed route starts
-- a new board, a staff test is never recorded, too fast / time / fall line are handled.
local nowMs = 0
local threads = {}
local function resume(co)
    local ok, err = coroutine.resume(co)
    if not ok then error(err, 0) end
end
_G.CreateThread = function(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; resume(co) end
_G.Wait = function(ms) local wake = nowMs + (ms or 0); repeat coroutine.yield() until nowMs >= wake end
local timers = {}
_G.SetTimeout = function(ms, fn) timers[#timers + 1] = { at = nowMs + ms, fn = fn } end
local function step(ms)
    nowMs = nowMs + (ms or 50)
    for i = #timers, 1, -1 do if timers[i].at <= nowMs then local t = table.remove(timers, i); t.fn() end end
    for i = #threads, 1, -1 do
        local co = threads[i]
        if coroutine.status(co) == "dead" then table.remove(threads, i) else resume(co) end
    end
end

local positions, sent, handlers, events, commands, actions, interactions, notices, results = {}, {}, {}, {}, {}, {}, {}, {}, {}
local frozen, god, life = {}, {}, {}
_G.GetPlayers = function() local t = {} for id in pairs(positions) do t[#t + 1] = tostring(id) end table.sort(t) return t end
_G.GetPlayerName = function(id) return "P" .. id end
_G.GetPlayerIdentifier = function(id) return "acc" .. id end
_G.GetCurrentResourceName = function() return "op77_lightrp" end
_G.TriggerClientEvent = function(name, id, payload) sent[#sent + 1] = { name = name, id = id, payload = payload } end
_G.TriggerLatentClientEvent = nil
_G.RegisterNetEvent = function(name, fn) handlers[name] = fn end
_G.AddEventHandler = function(name, fn) events[name] = fn end
_G.TriggerEvent = function() end

local teleports = {}
_G.Open77 = {
    time = { unix = function() return 1793800000 + math.floor(nowMs / 1000) end, monotonic = function() return nowMs / 1000 end },
    acl = { isAllowed = function(id, perm) return id == 1 and perm == "command.lightrp.parkour" end },
    players = {
        position = function(id) local p = positions[id]; return p and { x = p.x, y = p.y, z = p.z, heading = 0 } end,
        teleport = function(id, at, opts)
            teleports[#teleports + 1] = { id = id, at = at, heading = opts and opts.heading }
            positions[id] = { x = at.x, y = at.y, z = at.z }
            -- like the runtime: resolves with the position reached
            return { await = function() return { x = at.x, y = at.y, z = at.z } end }
        end,
        setFrozen = function(id, on) frozen[id] = on; return true end,
        setGodMode = function(id, on) god[id] = on; return true end,
        getHealth = function(id) return { godMode = god[id] == true } end,
        getLifeState = function(id) return { phase = life[id] or "alive" } end,
        respawn = function(id, opts) life[id] = "alive"; positions[id] = { x = opts.position.x, y = opts.position.y, z = opts.position.z }; return true end,
    },
}
_G.LightRpEvents = {
    net = { parkour = "op77_lightrp:parkour", parkourKey = "op77_lightrp:parkour:key", parkourEditor = "op77_lightrp:parkour:editor", dialog = "op77_lightrp:dialog" },
    page = {},
}
local owned, registered, entered, left = {}, nil, {}, {}
_G.LightRP = {
    log = function(fmt, ...) if os.getenv("PARKOUR_TEST_LOG") then print(string.format(fmt, ...)) end end,
    module = function(name, def) LightRP[name] = def; return def end,
    command = function(name, _, fn) commands[name] = fn end,
    action = function(name, fn) actions[name] = fn end,
    result = function(id, ok, text, action) notices[#notices + 1] = { id = id, ok = ok, text = text, action = action } end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, body = n.body } end,
    nowMs = function() return nowMs end,
    db = { ready = false, schema = function() end },
    interaction = function(id, def) interactions[id] = def end,
    removeInteraction = function(id) interactions[id] = nil end,
    batchInteractions = function(fn) return fn() end,
    staff = { moveTo = function(id, at, h, cb) positions[id] = at; cb(true) end },
    characters = {
        get = function(id) return positions[id] and { status = "active", identifier = "acc" .. id, key = "c1" } end,
        displayName = function(id) return "Runner " .. id end,
    },
    activities = {
        register = function(def) registered = def; return true end,
        owner = function(id) return owned[id] end,
        enter = function(id, act) owned[id] = act; entered[#entered + 1] = id; return true end,
        leave = function(id, act, opts) owned[id] = nil; left[#left + 1] = { id = id, back = opts and opts.returnPlayer }; return true end,
        result = function(id, act, r) results[#results + 1] = { id = id, r = r }; return true end,
    },
}

dofile("shared/parkour.lua")
dofile("server/modules/parkour.lua")
local M, P = LightRP.parkour, LightRpParkour

local function check(cond, label) if not cond then error("FAILED: " .. label, 2) end end
local function lastTo(id, kind)
    for i = #sent, 1, -1 do
        local s = sent[i]
        if s.id == id and type(s.payload) == "table" and s.payload.kind == kind then return s.payload end
    end
end
local function editor(id, op, payload)
    payload = payload or {}
    payload.operation, payload.request = op, "r" .. tostring(#sent) .. op
    nowMs = nowMs + 200
    handlers["op77_lightrp:parkour:editor"](payload)
    local reply = lastTo(id, "response")
    return reply
end

-- ---------------------------------------------------------------------------
-- Shared: validation and geometry
do
    local ok, why = P.validate({ name = "ab", start = { x = 0, y = 0, z = 0 }, finish = { x = 30, y = 0, z = 0 } })
    check(ok == nil and why:find("name"), "short name refused")
    ok, why = P.validate({ name = "Short", start = { x = 0, y = 0, z = 0 }, finish = { x = 5, y = 0, z = 0 } })
    check(ok == nil and why:find("15 m"), "too short route refused: " .. tostring(why))
    ok, why = P.validate({ name = "Gap", start = { x = 0, y = 0, z = 0 }, checkpoints = { { x = 1, y = 0, z = 0 } }, finish = { x = 40, y = 0, z = 0 } })
    check(ok == nil and why:find("closer"), "orbs on top of each other refused")
    ok = P.validate({ name = "Fine", start = { x = 0, y = 0, z = 0, heading = 90 }, checkpoints = {}, finish = { x = 40, y = 0, z = 0, radius = 2 } })
    check(ok and ok.length == 40 and ok.start.radius == 3 and ok.finish.radius == 2, "valid course, default radius, length")
    ok, why = P.validate({ name = "Floor", start = { x = 0, y = 0, z = 10 }, finish = { x = 40, y = 0, z = 10 }, floorZ = 12 })
    check(ok == nil and why:find("fall line"), "fall line above the start refused")
    -- the segment enters the sphere at the right fraction
    local t = P.segmentEnters({ x = 0, y = 0, z = 0 }, { x = 10, y = 0, z = 0 }, { x = 8, y = 0, z = 0 }, 3)
    check(t and math.abs(t - 0.5) < 1e-9, "segment enters at 0.5")
    check(P.segmentEnters({ x = 0, y = 0, z = 0 }, { x = 10, y = 0, z = 0 }, { x = 8, y = 5, z = 0 }, 3) == nil, "segment misses")
    check(P.segmentEnters({ x = 7, y = 0, z = 0 }, { x = 10, y = 0, z = 0 }, { x = 8, y = 0, z = 0 }, 3) == 0, "already inside: 0")
    check(P.formatTime(62345) == "1:02.345" and P.formatTime(9007) == "9.007", "time format")
    check(P.encodeSplits({ 1, 22, 333 }) == "1,22,333" and #P.decodeSplits("1,22,333") == 3, "splits round trip")
end

-- ---------------------------------------------------------------------------
-- The staff saves a course
positions[1] = { x = -50, y = 0, z = 10 }
positions[2] = { x = 100, y = 100, z = 10 }
positions[3] = { x = 100, y = 120, z = 10 }
check(registered and registered.id == "parkour.run" and registered.kind == "race", "activity registered")
local course = { name = "Rooftop Dash", description = "Test", difficulty = "hard",
    start = { x = 0, y = 0, z = 10, radius = 2, heading = 270 },
    checkpoints = { { x = 20, y = 0, z = 10, radius = 3 }, { x = 40, y = 0, z = 10, radius = 3 } },
    finish = { x = 60, y = 0, z = 10, radius = 3 } }
local denied = (function() _G.source = 2; return editor(2, "save", { course = course, mutation = "mutation-0001" }) end)()
check(denied and denied.ok == false and denied.error:find("permission"), "a player cannot save")
_G.source = 1
local saved = editor(1, "save", { course = course, mutation = "mutation-0002" })
check(saved and saved.ok, "staff saves: " .. tostring(saved and saved.error))
local id = saved.data.course.id
check(type(id) == "string" and saved.data.course.revision == 1 and saved.data.course.status == "published", "published revision 1")
check(interactions["parkour." .. id] and interactions["parkour." .. id].streamGroup == "parkour", "start orb interaction registered")
check(registered.modes and registered.modes[1].id == id, "the course is a join choice of the Activities panel")
-- the same mutation twice answers the same (no duplicate course)
local again = editor(1, "save", { course = course, mutation = "mutation-0002" })
check(again.ok and again.data.course.id == id, "idempotent save")
local n = 0
for _ in pairs(M.courses()) do n = n + 1 end
check(n == 1, "one course")

-- ---------------------------------------------------------------------------
-- A run: player 2 starts from the card (far away: teleported onto the start)
local function runTo(player, x, speed, opts)
    -- walk along +x at `speed` m/s until x reached or the run left "running"
    local runs = M.runs()
    opts = opts or {}
    while runs[player] and runs[player].phase == "running" and positions[player].x < x do
        local p = positions[player]
        positions[player] = { x = math.min(x, p.x + speed * 0.05), y = p.y, z = opts.z or p.z }
        step(50)
    end
end
local function startRun(player)
    _G.source = player
    actions["parkour.start"](player, { course = id })
    local runs = M.runs()
    check(runs[player] and runs[player].phase == "countdown", "countdown after the teleport")
    check(frozen[player] == true and god[player] == true, "held and god mode during the countdown")
    local cd = lastTo(player, "countdown")
    check(cd and cd.goInMs == 3000, "countdown event")
    for _ = 1, 61 do step(50); if runs[player].phase == "running" then break end end
    check(runs[player].phase == "running" and frozen[player] == false, "GO: released")
    check(lastTo(player, "go"), "go event")
end
startRun(2)
check(positions[2].x == 0 and positions[2].y == 0, "teleported onto the start")
check(entered[1] == 2 and owned[2] == "parkour.run", "the activity core owns the runner")
local run = M.runs()[2]
local goAt = run.startedAt
-- 8 m/s: the body enters checkpoint 1 (radius 3 at x=20) at x=17: 2125 ms after GO
runTo(2, 70, 8)
local cp1
for _, s in ipairs(sent) do if s.id == 2 and s.payload.kind == "cp" and s.payload.index == 1 then cp1 = s.payload end end
check(cp1 and math.abs(cp1.elapsedMs - 2125) <= 1, "checkpoint 1 split interpolated: " .. tostring(cp1 and cp1.elapsedMs))
local fin = lastTo(2, "finish")
check(fin and math.abs(fin.timeMs - (57 / 8 * 1000)) <= 1, "finish time interpolated: " .. tostring(fin and fin.timeMs))
step(50); step(50)
local res = lastTo(2, "result")
check(res and res.rank == 1 and res.total == 1 and res.improved and res.recordBroken, "first finish: record, rank 1")
check(results[1] and results[1].r.stats.courseId == id and results[1].r.stats.timeMs == fin.timeMs, "result reported to the core")
check(goAt and run.splits[2] and run.splits[1] < run.splits[2], "splits in order")

-- player 3 runs slower: rank 2; the record notice reached player 3 earlier
startRun(3)
check(M.runs()[3].best == nil and M.runs()[3].record and M.runs()[3].record.timeMs == fin.timeMs, "the run knows the record")
runTo(3, 70, 6)
step(50); step(50)
local res3 = lastTo(3, "result")
check(res3 and res3.rank == 2 and res3.total == 2 and not res3.recordBroken and res3.top[1].name == "Runner 2", "slower: rank 2, top shows the record holder")
local cpRec
for _, s in ipairs(sent) do if s.id == 3 and s.payload.kind == "cp" and s.payload.index == 1 then cpRec = s.payload end end
check(cpRec and cpRec.recordMs == cp1.elapsedMs, "checkpoint delta against the record")

-- restart (HOME) during the result: same run, attempt 2, player 3 now faster -> rank 1
_G.source = 3
nowMs = nowMs + 2000
handlers["op77_lightrp:parkour:key"]({ op = "restart" })
for _ = 1, 80 do step(50); if M.runs()[3].phase == "running" then break end end
check(M.runs()[3].attempt == 2 and M.runs()[3].phase == "running", "restart: attempt 2 running")
check(M.runs()[3].best and M.runs()[3].best.timeMs == res3.timeMs, "the run knows the personal best")
runTo(3, 70, 10)
step(50); step(50)
local res3b = lastTo(3, "result")
check(res3b and res3b.attempt == 2 and res3b.rank == 1 and res3b.improved and res3b.recordBroken and res3b.previous.timeMs == res3.timeMs, "faster: new record, previous best known")
local board = M.boardOf(id)
check(#board.rows == 2 and board.rows[1].name == "Runner 3" and board.rows[1].runs == 2, "board: 2 runners, the faster first, finishes counted")

-- the result card holds, then the runner is sent back through the core
for _ = 1, 520 do step(50); if not M.runs()[3] then break end end
check(M.runs()[3] == nil and left[#left].id == 3 and left[#left].back == true, "after the result hold: back through the core")

-- ---------------------------------------------------------------------------
-- Leaving with F1 (the core's leaveRequest), too fast, the fall line
startRun(2)
events["op77_lightrp:activity:leaveRequest"](2, "parkour.run")
check(M.runs()[2] == nil and lastTo(2, "ended"), "leave request ends the run")
check(god[2] == false, "god mode restored")
startRun(2)
positions[2] = { x = 0, y = 0, z = 10 }
step(50)
nowMs = nowMs + 1000
positions[2] = { x = 3, y = 0, z = 10 }; step(50)
positions[2] = { x = 10, y = 0, z = 10 }; step(50)  -- 7 m in 50 ms = 140 m/s
local dnf = lastTo(2, "dnf")
check(dnf and dnf.reason == "too_fast", "too fast: DNF")
events["op77_lightrp:activity:leaveRequest"](2, "parkour.run")

-- ---------------------------------------------------------------------------
-- The staff moves an orb: new revision, fresh board; renaming keeps it
local moved = { id = id, name = "Rooftop Dash", description = "Test", difficulty = "hard", start = course.start,
    checkpoints = { { x = 20, y = 2, z = 10, radius = 3 }, course.checkpoints[2] }, finish = course.finish, floorZ = 4 }
_G.source = 1
local r2 = editor(1, "save", { course = moved, baseRevision = 1, mutation = "mutation-0003" })
check(r2.ok and r2.data.course.revision == 2 and r2.data.reset, "a moved orb: revision 2, new board")
check(#M.boardOf(id).rows == 0, "fresh board")
moved.name = "Rooftop Dash II"
local r3 = editor(1, "save", { course = moved, baseRevision = 2, mutation = "mutation-0004" })
check(r3.ok and r3.data.course.revision == 2 and not r3.data.reset, "renaming keeps the board")
local stale = editor(1, "save", { course = moved, baseRevision = 1, mutation = "mutation-0005" })
check(stale.ok == false and stale.error:find("meanwhile"), "a stale base revision is refused")

-- the fall line: below z=4 the runner goes back to the last checkpoint, clock running
startRun(2)
runTo(2, 25, 8)
check(M.runs()[2].last == 1, "past checkpoint 1")
local before = #teleports
positions[2] = { x = positions[2].x, y = 0, z = 3 }
step(50); step(50)
check(#teleports == before + 1 and teleports[#teleports].at.x == 20 and teleports[#teleports].at.y == 2, "fell: back on checkpoint 1")
check(lastTo(2, "respawn").reason == "fell" and M.runs()[2].phase == "running", "the clock keeps running")
events["op77_lightrp:activity:leaveRequest"](2, "parkour.run")

-- ---------------------------------------------------------------------------
-- A staff test of a draft: not recorded, not on any board
_G.source = 1
local draft = { name = "Draft run", start = { x = 0, y = 50, z = 10 }, checkpoints = {}, finish = { x = 30, y = 50, z = 10 } }
local tr = editor(1, "test", { course = draft })
check(tr.ok and M.runs()[1] and M.runs()[1].test, "staff test starts")
for _ = 1, 80 do step(50); if M.runs()[1].phase == "running" then break end end
local resultsBefore = #results
runTo(1, 40, 8)
step(50); step(50)
local tres = lastTo(1, "result")
check(tres and tres.test and tres.rank == nil and #results == resultsBefore, "test result: not recorded, not reported")

-- ---------------------------------------------------------------------------
-- Unpublish and delete
local un = editor(1, "status", { id = id, status = "draft", mutation = "mutation-0006" })
check(un.ok and interactions["parkour." .. id] == nil, "unpublished: start orb gone")
_G.source = 2
actions["parkour.start"](2, { course = id })
check(M.runs()[2] == nil, "a draft cannot be run by players")
_G.source = 1
local del = editor(1, "delete", { id = id, mutation = "mutation-0007" })
check(del.ok and M.courses()[id] == nil, "deleted")

print("parkour_test: ok")
