-- Parkour, client side (server/modules/parkour.lua, docs/parkour.md): what the player sees
-- of the courses. Purely visual: the server alone decides every crossing.
--
--   * Start orbs: the published courses' starts within sight (the nearest few) are a
--     glowing orb with a light beam (Open77.markers). The E prompt and the map blip are the
--     server's interaction points.
--   * A run: the next checkpoint is a gold orb (its trigger sphere drawn around it) with a
--     beam, the one after it a small dim orb, the finish a green orb and beam; a crossing
--     plays the game's UI sounds and a burst. The page draws the clock, the splits, the
--     countdown and the result card (ui/src/features/parkour/ParkourHud.tsx) and plays the
--     course music at 5 %.
--   * Keys (rebindable): HOME restart, END back to the last checkpoint.
local E, Ui = LightRpEvents, LightRpUi
local P = LightRpParkour
local C = P.config
local Parkour = { courses = {}, run = nil }
LightRpParkourClient = Parkour

local LIFT = C.orbLift
local COLORS = { start = { r = 0, g = 240, b = 255 }, next = { r = 255, g = 204, b = 0 }, later = { r = 230, g = 236, b = 242 },
    finish = { r = 61, g = 220, b = 132 } }
local START_VIEW, START_ORBS = 160, 4

local function log(...) Ui.log(...) end
local function page(payload) Ui.send(E.page.parkour, payload) end
local function color(c, a) return { r = c.r, g = c.g, b = c.b, a = a } end
local function markersOk() return type(Open77.markers) == "table" and type(Open77.markers.create) == "function" end

local function sound(event)
    if Open77.sfx and type(Open77.sfx.play2d) == "function" then pcall(Open77.sfx.play2d, event) end
end
local function burst(p, effect)
    if type(Open77.vfx) ~= "table" or type(Open77.vfx.play) ~= "function" or not p then return end
    pcall(Open77.vfx.play, effect or "neon.loot_drop", { position = { x = p.x, y = p.y, z = p.z + LIFT }, duration = 1.5 })
end

-- Creating a native marker costs (the client's markers module peaked at 16-24 ms in one frame
-- when a run's orbs were all created at once, LightRP Testing 2026-11-06 00:03): the markers
-- are created one per frame from a queue. A handle list dropped before its turn is skipped.
local queue, draining = {}, false
local function drain()
    if draining then return end
    draining = true
    CreateThread(function()
        while #queue > 0 do
            local job = table.remove(queue, 1)
            if not job.handles.cancelled then
                local ok, handle = pcall(Open77.markers.create, job.def)
                if ok and handle then
                    if job.handles.cancelled then pcall(Open77.markers.remove, handle)
                    else job.handles[#job.handles + 1] = handle end
                end
                Wait(0)
            end
        end
        draining = false
    end)
end

-- One orb: a solid core, the trigger sphere (translucent, the size the server tests) and a
-- light beam up into the sky. Returns the list its marker handles fill in (queued).
local function orb(p, opts)
    if not markersOk() then return {} end
    local handles = {}
    local function add(def) queue[#queue + 1] = { handles = handles, def = def } end
    local cz = p.z + LIFT
    local core = opts.core or 0.45
    add({ position = { x = p.x, y = p.y, z = cz - core }, shape = "sphere", radius = core, height = core * 2,
        color = color(opts.color, opts.coreAlpha or 235), maxDistance = opts.view or 250 })
    if opts.trigger and p.radius then
        local r = p.radius
        add({ position = { x = p.x, y = p.y, z = cz - r }, shape = "sphere", radius = r, height = r * 2,
            color = color(opts.color, opts.triggerAlpha or 38), maxDistance = math.min(opts.view or 250, 140) })
    end
    if opts.beam then
        add({ position = { x = p.x, y = p.y, z = p.z }, shape = "cylinder", radius = opts.beamRadius or 0.22, height = opts.beamHeight or 70,
            color = color(opts.color, opts.beamAlpha or 70), maxDistance = opts.view or 400 })
    end
    if opts.ring then
        add({ position = { x = p.x, y = p.y, z = p.z + 0.06 }, shape = "ring", radius = math.max(0.8, (p.radius or 2) * 0.9), height = 1,
            color = color(opts.color, 200), maxDistance = 120 })
    end
    drain()
    return handles
end
local function drop(handles)
    if not handles then return end
    handles.cancelled = true
    for _, h in ipairs(handles) do pcall(Open77.markers.remove, h) end
end

-- ---------------------------------------------------------------------------
-- Start orbs (no run going)

local startOrbs = {} -- course id -> handles
local function clearStarts()
    for id, handles in pairs(startOrbs) do drop(handles); startOrbs[id] = nil end
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
    for i = 1, math.min(START_ORBS, #near) do keep[near[i].c.id] = near[i].c end
    for id, handles in pairs(startOrbs) do if not keep[id] then drop(handles); startOrbs[id] = nil end end
    for id, c in pairs(keep) do
        if not startOrbs[id] then
            startOrbs[id] = orb(c.start, { color = COLORS.start, core = 0.55, beam = true, beamHeight = 60, beamAlpha = 60, ring = true, view = START_VIEW + 40 })
        end
    end
end

-- ---------------------------------------------------------------------------
-- The run

local runMarkers = { next = nil, later = nil, finish = nil }
local function clearRunMarkers()
    for k, handles in pairs(runMarkers) do drop(handles); runMarkers[k] = nil end
end
local function target(run, index)
    local cps = run.course.checkpoints
    if index <= #cps then return cps[index], false end
    if index == #cps + 1 then return run.course.finish, true end
    return nil
end
local function syncRunMarkers()
    clearRunMarkers()
    local run = Parkour.run
    if not run or run.phase == "ended" then return end
    local t, isFinish = target(run, run.next)
    if run.phase == "finished" or not t then return end
    if isFinish then
        runMarkers.next = orb(t, { color = COLORS.finish, core = 0.7, trigger = true, beam = true, beamRadius = 0.45, beamAlpha = 90, ring = true, view = 500 })
        return
    end
    runMarkers.next = orb(t, { color = COLORS.next, core = 0.5, trigger = true, beam = true, beamAlpha = 80, view = 400 })
    local after, afterFinish = target(run, run.next + 1)
    if after and not afterFinish then
        runMarkers.later = orb(after, { color = COLORS.later, core = 0.3, coreAlpha = 150, view = 300 })
    end
    -- the finish always shows where it ends
    runMarkers.finish = orb(run.course.finish, { color = COLORS.finish, core = 0.6, coreAlpha = 170, beam = true, beamRadius = 0.4, beamAlpha = 55, view = 600 })
end

local function stopRun()
    Parkour.run = nil
    clearRunMarkers()
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
        Parkour.run = { course = p.course, phase = p.phase or "loading", next = (tonumber(p.checkpoint) or 0) + 1, attempt = p.attempt }
        clearStarts()
        Ui.send(E.page.dialogClose, { kind = "parkour" })
        syncRunMarkers()
        page(p)
        return
    end
    local run = Parkour.run
    if kind == "ended" then
        if run then stopRun() end
        return
    end
    if not run then return end
    if kind == "countdown" then
        run.phase, run.next = "countdown", 1
        syncRunMarkers()
        sound("sq024_race_countdown_start")
    elseif kind == "go" then
        run.phase = "running"
        sound("ui_jingle_quest_new")
    elseif kind == "cp" then
        local passed = run.course.checkpoints[p.index]
        run.next = (tonumber(p.index) or 0) + 1
        syncRunMarkers()
        sound("ui_menu_onpress")
        sound("ui_jingle_quest_update")
        burst(passed)
    elseif kind == "finish" then
        run.phase = "finished"
        syncRunMarkers()
        sound("ui_jingle_quest_success")
        burst(run.course.finish, "sparks.burst.small")
    elseif kind == "dnf" then
        run.phase = "finished"
        syncRunMarkers()
        sound("ui_menu_item_crafting_fail")
    elseif kind == "respawn" then
        sound("ui_menu_onpress")
    end
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
    CreateThread(function()
        while true do
            Wait(1000)
            local ok, err = pcall(syncStarts)
            if not ok then log("parkour: start orbs failed: %s", tostring(err)) end
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
    clearStarts(); clearRunMarkers()
end)
