-- Parkour, client side (server/modules/parkour.lua, docs/parkour.md): what the player sees
-- of the courses. Purely visual: the server alone decides every crossing.
--
-- The points are kept simple and still (2026-11-06, the user: "un seul marker cercle au sol"):
--   * the checkpoint to reach: a gold ring flat on the ground, the size of its trigger,
--     and a gold light column into the sky, to find it from far away;
--   * the finish: the same in green; a start: the same in cyan, seen only within
--     startView (an activity is there, it does not call from across the city).
-- A marker is never updated after its creation: an update while it is still loading
-- restarts its spawn (client Markers.cpp, stage != Ready), and the earlier animated
-- version (rising gates, turning diamonds, sliding chevrons, 20 updates a second) made
-- the points vanish and come back all the time. A crossed checkpoint simply goes, with a
-- burst and a sound.
--
-- The page draws the clock, the splits, the countdown, GO, the bearing to the next point
-- and the result card (ui/src/features/parkour/ParkourHud.tsx) and plays the course music.
-- Keys (rebindable): HOME restart, END back to the last checkpoint, DELETE leave.
local E, Ui = LightRpEvents, LightRpUi
local P = LightRpParkour
local C = P.config
local Parkour = { courses = {}, run = nil }
LightRpParkourClient = Parkour

local LIFT = C.orbLift
local PALETTE = {
    start = { r = 0, g = 240, b = 255 },
    checkpoint = { r = 255, g = 204, b = 0 },
    finish = { r = 61, g = 220, b = 132 },
}
local START_VIEW, START_GROUPS = C.startView + 20, 3
-- 64 markers per resource, shared with every LightRP point (shops, rentals, missions...):
-- the parkour leaves this many free (the interaction markers stream by distance).
local MARKER_CAP, MARKER_RESERVE = 64, 10
local FRAME_MS = 100

local function log(...) Ui.log(...) end
local function page(payload) Ui.send(E.page.parkour, payload) end
local function now() return GetGameTimer() end
local function rgba(c, a) return { r = c.r, g = c.g, b = c.b, a = a } end
local function markersOk() return type(Open77.markers) == "table" and type(Open77.markers.create) == "function" end
-- game yaw (degrees, counter-clockwise from +Y) of the way from a to b
local function yawTo(a, b)
    local dx, dy = b.x - a.x, b.y - a.y
    if math.abs(dx) + math.abs(dy) < 1e-3 then return 0 end
    return math.deg(math.atan(-dx, dy))
end

local function sound(event)
    if Open77.sfx and type(Open77.sfx.play2d) == "function" then pcall(Open77.sfx.play2d, event) end
end
local function burst(p, effect)
    if type(Open77.vfx) ~= "table" or type(Open77.vfx.play) ~= "function" or not p then return end
    pcall(Open77.vfx.play, effect or "neon.loot_drop", { position = { x = p.x, y = p.y, z = p.z + LIFT }, duration = 1.5 })
end

-- A refusal or a short budget is logged (at most every 30 s per kind): nothing fails
-- silently (2026-11-06: no point drawn at all, nothing in the log).
local warnedAt = {}
local function warn(key, ...)
    local t = now()
    if warnedAt[key] and t - warnedAt[key] < 30000 then return end
    warnedAt[key] = t
    log(...)
end

-- ---------------------------------------------------------------------------
-- Points: a ring and a light column, created once, never updated

-- Creating a native marker costs (the client's markers module peaked at 16-24 ms in one frame
-- when a run's markers were all created at once, LightRP Testing 2026-11-06 00:03): they
-- are created one per frame from a queue.
local queue, draining = {}, false
local function drain()
    if draining then return end
    draining = true
    CreateThread(function()
        while #queue > 0 do
            local job = table.remove(queue, 1)
            local g, def = job.group, job.def
            if not g.cancelled then
                local ok, handle, why = pcall(Open77.markers.create, def)
                if ok and handle then
                    if g.cancelled then pcall(Open77.markers.remove, handle) else g.handles[#g.handles + 1] = handle end
                else
                    warn("create", "parkour: %s %s marker refused: %s", g.kind, tostring(def.shape), tostring(ok and why or handle))
                end
                Wait(0)
            end
        end
        draining = false
    end)
end

local function freeSlots()
    local used = 0
    if type(Open77.markers.list) == "function" then
        local ok, list = pcall(Open77.markers.list)
        if ok and type(list) == "table" then used = #list end
    end
    return MARKER_CAP - MARKER_RESERVE - used - #queue
end

local function drop(g)
    if not g then return end
    g.cancelled = true
    for _, h in ipairs(g.handles) do pcall(Open77.markers.remove, h) end
    g.handles = {}
end

local function radiusOf(p) return tonumber(p.radius) or C.radius.default end

-- One point, as simple as it gets (2026-11-06, the user: "un seul marker cercle au sol ... avec un
-- beam qui part dans le ciel"): a ring flat on the ground, the size of the trigger, and a
-- light column into the sky. Only the "ring" and "cylinder" shapes, every value inside the
-- marker API's ranges (the standing "checkpoint" frame was refused with invalid_argument on
-- LightRP Testing, so nothing showed). A start (an activity's entrance) is the same, seen
-- only from close by (startView): it says "the activity is here", it does not call from afar.
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function point(kind, p, _, color, start)
    local g = { kind = kind, handles = {} }
    if not markersOk() then return g end
    local R = clamp(radiusOf(p), 0.5, 12)
    local ringView = start and C.startView or 300
    local beamView = start and C.startView or 500
    local defs = {
        { position = { x = p.x, y = p.y, z = p.z + 0.05 }, shape = "ring", radius = R, height = 1,
            color = rgba(color, 230), maxDistance = ringView },
        { position = { x = p.x, y = p.y, z = p.z }, shape = "cylinder", radius = start and 0.35 or 0.3, height = start and 40 or 90,
            color = rgba(color, start and 110 or 140), maxDistance = beamView },
    }
    local room = freeSlots()
    if room < #defs then warn("budget", "parkour: %s gets %d of %d markers (marker budget: %d free)", kind, math.max(0, room), #defs, room) end
    for i = 1, math.min(#defs, math.max(0, room)) do queue[#queue + 1] = { group = g, def = defs[i] } end
    drain()
    return g
end

-- ---------------------------------------------------------------------------
-- Uplinks (no run going): the nearest published starts within sight

local starts = {} -- course id -> group
local function clearStarts()
    for id, g in pairs(starts) do drop(g); starts[id] = nil end
end
local function syncStarts()
    if Parkour.run or LightRpParkourEditor and LightRpParkourEditor.active then clearStarts(); return end
    local state = Open77.character.state()
    if not state or not state.position then return end
    local at = state.position
    local near = {}
    for _, c in ipairs(Parkour.courses) do
        local d = P.distance(at, c.start)
        if d <= START_VIEW then near[#near + 1] = { c = c, d = d } end
    end
    table.sort(near, function(a, b) return a.d < b.d end)
    local keep = {}
    for i = 1, math.min(START_GROUPS, #near) do keep[near[i].c.id] = near[i].c end
    for id, g in pairs(starts) do if not keep[id] then drop(g); starts[id] = nil end end
    for id, c in pairs(keep) do
        if not starts[id] then starts[id] = point("start", c.start, tonumber(c.start.heading) or 0, PALETTE.start, true) end
    end
end

-- ---------------------------------------------------------------------------
-- The run: the checkpoint to reach and the finish

local view = {} -- next, nextIndex, finish, finishNext
local function clearRun()
    drop(view.next); drop(view.finish)
    view = {}
end
local function pointAt(run, i)
    local cps = run.course.checkpoints
    if i <= #cps then return cps[i], false end
    if i == #cps + 1 then return run.course.finish, true end
    return nil
end
-- where the runner comes from to reach point i (the ring faces that way)
local function before(run, i)
    if i <= 1 then return run.course.start end
    return run.course.checkpoints[i - 1] or run.course.start
end

local function syncRun()
    local run = Parkour.run
    if not run or run.phase == "finished" then clearRun(); return end
    local cps = run.course.checkpoints
    local n = run.next
    local t, isFinish = pointAt(run, n)
    if view.nextIndex ~= n then
        drop(view.next)
        view.next, view.nextIndex = nil, n
        if t and not isFinish then view.next = point("checkpoint", t, yawTo(before(run, n), t), PALETTE.checkpoint) end
    end
    -- the finish shows from the start (where the run ends); it is only rebuilt for nothing
    if not view.finish then
        view.finish = point("finish", run.course.finish, yawTo(before(run, #cps + 1), run.course.finish), PALETTE.finish)
    end
end

-- ---------------------------------------------------------------------------
-- Held on the start until GO: the server freezes the runner (players.life.freeze), the
-- client holds its own body too, again every 200 ms (one freeze did not hold), released
-- at GO, at the end of the run and when the resource stops.

local held = false
local function syncHold()
    local run = Parkour.run
    local want = run ~= nil and (run.phase == "countdown" or run.phase == "landing")
    if type(Open77.character) ~= "table" or type(Open77.character.setFrozen) ~= "function" then return end
    if want then
        local ok, frozen = pcall(Open77.character.setFrozen, true)
        if ok and frozen ~= false then held = true end
    elseif held then
        pcall(Open77.character.setFrozen, false)
        held = false
    end
end

-- ---------------------------------------------------------------------------
-- The bearing: where the next point lies from the camera, how far and how high (the page's
-- compass under the clock). Sent when it changes, 8 times a second at most.

local lastBearing
local function cameraYaw()
    if type(Open77.camera) ~= "table" or type(Open77.camera.view) ~= "function" then return nil end
    local ok, v = pcall(Open77.camera.view)
    local f = ok and type(v) == "table" and v.forward
    if not f or math.abs(f.x or 0) + math.abs(f.y or 0) < 1e-3 then return nil end
    return math.deg(math.atan(-f.x, f.y))
end
local function syncBearing()
    local run = Parkour.run
    local t, isFinish
    if run and (run.phase == "countdown" or run.phase == "running") then t, isFinish = pointAt(run, run.next) end
    if not t then
        if lastBearing then lastBearing = nil; page({ kind = "bearing", hide = true }) end
        return
    end
    local s = Open77.character.state()
    local at = s and s.position
    if not at then return end
    local rel = ((yawTo(at, t) - (cameraYaw() or tonumber(s.yaw) or 0) + 540) % 360) - 180
    local dist = math.sqrt((t.x - at.x) ^ 2 + (t.y - at.y) ^ 2)
    local rise = (t.z + LIFT) - (at.z + LIFT)
    local label = isFinish and "FINISH" or ("CP " .. run.next)
    local b = lastBearing
    if b and b.label == label and math.abs(b.rel - rel) < 2 and math.abs(b.dist - dist) < 0.5 and math.abs(b.rise - rise) < 0.5 then return end
    lastBearing = { label = label, rel = rel, dist = dist, rise = rise }
    page({ kind = "bearing", label = label, angle = math.floor(rel + 0.5), distance = math.floor(dist + 0.5), rise = math.floor(rise + 0.5) })
end

-- ---------------------------------------------------------------------------
-- The frame loop: the hold and the bearing, the starts.

-- The body stands in the world: no loading screen (the game's or op77_loadscreen's cover), alive.
function Parkour.landed()
    local screen = Open77.screen
    if screen and type(screen.isLoading) == "function" and screen.isLoading() then return false end
    if screen and type(screen.loadingState) == "function" then
        local ok, state = pcall(screen.loadingState)
        if ok and type(state) == "table" and state.active == true then return false end
    end
    if type(GetResourceState) == "function" and GetResourceState("op77_loadscreen") == "running" then
        local ok, covered = pcall(function() return exports.op77_loadscreen:isActive() end)
        if ok and covered == true then return false end
    end
    local c = Open77.character and Open77.character.state and Open77.character.state()
    return c ~= nil and c.alive ~= false
end

local function stopRun()
    Parkour.run = nil
    clearRun()
    syncHold()
    syncBearing()
    page({ kind = "ended" })
end

local function onServer(p)
    local kind = p.kind
    if kind == "courses" then
        Parkour.courses = type(p.courses) == "table" and p.courses or {}
        clearStarts()
        return
    elseif kind == "board" then
        page(p); return
    elseif kind == "close" then
        Ui.send(E.page.dialogClose, { kind = "parkour" }); return
    elseif kind == "run" then
        if type(p.course) ~= "table" then return end
        if type(p.course.checkpoints) ~= "table" then p.course.checkpoints = {} end
        clearRun()
        Parkour.run = { course = p.course, phase = p.phase or "loading", next = (tonumber(p.checkpoint) or 0) + 1, attempt = p.attempt }
        clearStarts()
        Ui.send(E.page.dialogClose, { kind = "parkour" })
        syncRun()
        page(p)
        return
    end
    local run = Parkour.run
    if kind == "ended" then
        if run then stopRun() end
        return
    end
    if not run then return end
    if kind == "landing" then
        run.phase = "landing"
        syncHold()
        -- Tell the server once the start has really loaded (no loading screen, alive, settled): the
        -- 3-2-1 waits for it, so it is never played under the loading screen.
        local attempt = p.attempt
        CreateThread(function()
            local since, deadline = nil, now() + (C.landTimeoutMs or 15000)
            while Parkour.run == run and run.attempt == attempt and now() < deadline do
                if Parkour.landed() then
                    since = since or now()
                    if now() - since >= (C.landSettleMs or 700) then
                        TriggerServerEvent(E.net.parkourKey, { op = "landed", attempt = attempt })
                        return
                    end
                else
                    since = nil
                end
                Wait(100)
            end
        end)
        return
    end
    if kind == "countdown" then
        run.phase, run.next = "countdown", 1
        syncRun()
        syncHold()
        sound("sq024_race_countdown_start")
    elseif kind == "go" then
        run.phase = "running"
        syncHold()
        sound("ui_jingle_quest_new")
    elseif kind == "cp" then
        local passed = run.course.checkpoints[p.index]
        run.next = (tonumber(p.index) or 0) + 1
        syncRun()
        sound("ui_menu_onpress")
        sound("ui_jingle_quest_update")
        burst(passed)
    elseif kind == "finish" then
        run.phase = "finished"
        syncRun()
        syncHold()
        sound("ui_jingle_quest_success")
        burst(run.course.finish, "sparks.burst.small")
    elseif kind == "dnf" then
        run.phase = "finished"
        syncRun()
        syncHold()
        sound("ui_menu_item_crafting_fail")
    elseif kind == "respawn" then
        sound("ui_menu_onpress")
    end
    syncBearing()
    page(p)
end
RegisterNetEvent(E.net.parkour, function(p)
    if type(p) ~= "table" then return end
    local ok, err = pcall(onServer, p)
    if not ok then log("parkour: event %s failed: %s", tostring(p.kind), tostring(err)) end
end)

-- F1 > Parkour > GPS: the route to a course's start (the player's own waypoint).
function Parkour.gps(id)
    for _, c in ipairs(Parkour.courses) do
        if c.id == id then
            if type(Open77.blips) ~= "table" or type(Open77.blips.setWaypoint) ~= "function" then return false, "The GPS is not available." end
            local ok, why = Open77.blips.setWaypoint({ x = c.start.x, y = c.start.y, z = c.start.z })
            if ok == false then return false, tostring(why or "The route could not be set.") end
            return true
        end
    end
    return false, "That course is not open any more."
end

-- ---------------------------------------------------------------------------
-- Keys and the page

local function key(op)
    local run = Parkour.run
    if not run then return end
    if Open77.input and Open77.input.isCaptured and Open77.input.isCaptured() == true then return end
    TriggerServerEvent(E.net.parkourKey, { op = op })
end

local started = false
function Parkour.start()
    if started then return end
    started = true
    RegisterKeyMapping("lightrp.parkour.restart", "Parkour: restart the run", "HOME", function() key("restart") end)
    RegisterKeyMapping("lightrp.parkour.checkpoint", "Parkour: back to the last checkpoint", "END", function() key("checkpoint") end)
    -- F1 is the player menu: leaving a run has its own key (the result card has buttons too).
    RegisterKeyMapping("lightrp.parkour.leave", "Parkour: leave the run", "DELETE", function() key("leave") end)
    CreateThread(function()
        local frame = 0
        while true do
            Wait(FRAME_MS)
            frame = frame + 1
            if frame % 2 == 0 then pcall(syncHold) end
            local ok, err = pcall(syncBearing)
            if not ok then log("parkour: bearing failed: %s", tostring(err)) end
            if frame % 10 == 0 then
                ok, err = pcall(syncStarts)
                if not ok then log("parkour: starts failed: %s", tostring(err)) end
            end
        end
    end)
end

-- The page's buttons on the result card (the server resends the courses and any run on
-- the page's ready, server/modules/parkour.lua onUiReady).
function Parkour.bind(page)
    page:on(E.page.parkour, function(p)
        if type(p) ~= "table" then return end
        if p.op == "leave" then TriggerServerEvent(E.net.parkourKey, { op = "leave" })
        elseif p.op == "restart" then TriggerServerEvent(E.net.parkourKey, { op = "restart" }) end
    end)
end

AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    Parkour.run = nil
    syncHold()
    clearStarts(); clearRun()
end)
