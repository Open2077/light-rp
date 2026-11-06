-- Parkour, client side (server/modules/parkour.lua, docs/parkour.md): what the player sees
-- of the courses. Purely visual: the server alone decides every crossing.
--
-- Art direction, "RELAY": a course is a signal the runner carries from an UPLINK (the
-- start) through RELAYS (the checkpoints) to the DOWNLINK (the finish). Every point is
-- drawn with one small vocabulary of native markers (Open77.markers):
--   * GATE   a standing circular frame across the line, the size of the trigger: what you
--            see is what counts, you run through it;
--   * SPINE  a light column fading into the sky, seen from far away;
--   * NODE   a diamond turning above the gate, the head of the spine;
--   * DRIP   two chevrons sliding down from the node into the gate: enter here;
--   * PAD    a ring on the ground.
-- Colours carry the role: uplink cyan, relay gold (the one to reach), ghost white (the one
-- after it, its gate only, to read the line), downlink green (two gates crossed into a
-- turning gyroscope). A relay rises out of the ground when it becomes the target; a
-- crossed one is SENT: it shoots up into the sky and goes. A marker never changes colour
-- or size after creation (a native rebuild): only positions and rotations move, 20 times
-- a second, for the groups near the player.
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
    uplink = { r = 0, g = 240, b = 255 },
    relay = { r = 255, g = 204, b = 0 },
    ghost = { r = 226, g = 232, b = 240 },
    downlink = { r = 61, g = 220, b = 132 },
}
local START_VIEW, START_GROUPS = 160, 3
-- 64 markers per resource, shared with every LightRP point (shops, rentals, missions...):
-- the parkour leaves this many free, and drops its decoration before its gates when short.
local MARKER_CAP, MARKER_RESERVE = 64, 10
local FRAME_MS, ANIM_RANGE = 50, 180
local RISE_MS, SEND_MS, SEND_HEIGHT = 450, 420, 16

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

-- ---------------------------------------------------------------------------
-- Groups of markers

local groups = {} -- every live group: the frame loop animates them

-- Where a part stands at time t: its base, turned (spin), bobbing, dripping, rising out of
-- the ground after its creation, shooting up once sent.
local function pose(g, part, t)
    local b = part.base
    local z, yaw = b.z, part.yaw or 0
    if part.spin then yaw = yaw + part.spin * t / 1000 end
    if part.bob then z = z + math.sin(t / 1000 * 2.2 + (part.seed or 0)) * part.bob end
    if part.drip then
        local f = (t / part.drip.period + part.drip.phase) % 1
        z = part.drip.top - (part.drip.top - part.drip.bottom) * f
    end
    if g.rise and part.born then
        local k = math.min(1, math.max(0, (t - part.born) / RISE_MS))
        z = z - (1 - k) ^ 3 * g.rise
    end
    if g.sentAt then
        local k = math.min(1, math.max(0, (t - g.sentAt) / SEND_MS))
        z = z + k * k * SEND_HEIGHT
    end
    return { x = b.x, y = b.y, z = z }, { x = 0, y = 0, z = yaw % 360 }
end

-- Creating a native marker costs (the client's markers module peaked at 16-24 ms in one frame
-- when a run's markers were all created at once, LightRP Testing 2026-11-06 00:03): they
-- are created one per frame from a queue, each at its pose of that moment.
local queue, draining = {}, false
local function drain()
    if draining then return end
    draining = true
    CreateThread(function()
        while #queue > 0 do
            local job = table.remove(queue, 1)
            local g, part = job.group, job.part
            if not g.cancelled and not g.sentAt then
                part.born = now()
                local def = {}
                for k, v in pairs(part.def) do def[k] = v end
                def.position, def.rotation = pose(g, part, part.born)
                local ok, handle = pcall(Open77.markers.create, def)
                if ok and handle then
                    if g.cancelled or g.sentAt then pcall(Open77.markers.remove, handle) else part.handle = handle end
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

-- `parts` in priority order (the gate first): what does not fit the free slots is left out.
local function group(kind, parts, opts)
    local g = { kind = kind, parts = {}, at = opts.at, rise = opts.rise }
    if not markersOk() then return g end
    local room = freeSlots()
    for _, part in ipairs(parts) do
        if room <= 0 then break end
        room = room - 1
        g.parts[#g.parts + 1] = part
        queue[#queue + 1] = { group = g, part = part }
    end
    groups[g] = true
    drain()
    return g
end

local function drop(g)
    if not g then return end
    g.cancelled = true
    groups[g] = nil
    for _, part in ipairs(g.parts) do
        if part.handle then pcall(Open77.markers.remove, part.handle); part.handle = nil end
    end
end

-- Crossed: the decoration goes at once, the gates shoot up and go (the frame loop).
local function send(g)
    if not g or g.cancelled or g.sentAt then return end
    g.sentAt = now()
    for _, part in ipairs(g.parts) do
        if not part.gate and part.handle then pcall(Open77.markers.remove, part.handle); part.handle = nil end
    end
end

-- The parts
local function gate(center, radius, yaw, color, alpha, view)
    -- the frame's origin is its bottom; its plane faces the way the runner comes
    return { gate = true, yaw = yaw, base = { x = center.x, y = center.y, z = center.z - radius },
        def = { shape = "checkpoint", radius = radius, height = radius * 2, color = rgba(color, alpha), maxDistance = view } }
end
local function spine(p, color, radius, height, alpha)
    return { base = { x = p.x, y = p.y, z = p.z },
        def = { shape = "cylinder", radius = radius, height = height, color = rgba(color, alpha), maxDistance = 500 } }
end
local function node(x, y, z, color, view)
    return { spin = 70, bob = 0.18, seed = (x + y) % 6, base = { x = x, y = y, z = z },
        def = { shape = "diamond", radius = 0.42, height = 1.0, color = rgba(color, 235), maxDistance = view } }
end
local function drips(x, y, top, bottom, yaw, color, out)
    for i = 0, 1 do
        out[#out + 1] = { yaw = yaw, drip = { top = top, bottom = bottom, period = 1100, phase = i * 0.5 }, base = { x = x, y = y, z = top },
            def = { shape = "chevron", radius = 0.42, height = 0.5, color = rgba(color, 220), maxDistance = 140 } }
    end
    return out
end
local function pad(p, radius, color)
    return { base = { x = p.x, y = p.y, z = p.z + 0.06 },
        def = { shape = "ring", radius = radius, height = 1, color = rgba(color, 190), maxDistance = 120 } }
end
local function radiusOf(p) return tonumber(p.radius) or C.radius.default end

-- UPLINK: a portal standing on the ground at the start, facing the course.
local function uplink(s)
    local R = 1.6
    local top = s.z + 2 * R
    return group("uplink", {
        gate({ x = s.x, y = s.y, z = s.z + R }, R, tonumber(s.heading) or 0, PALETTE.uplink, 210, START_VIEW + 40),
        spine(s, PALETTE.uplink, 0.16, 55, 120),
        node(s.x, s.y, top + 0.55, PALETTE.uplink, START_VIEW + 40),
        pad(s, math.max(1.2, radiusOf(s) * 0.9), PALETTE.uplink),
    }, { at = s })
end

-- RELAY: the checkpoint to reach, risen out of the ground.
local function relay(p, from)
    local R = radiusOf(p)
    local yaw = from and yawTo(from, p) or 0
    local center = { x = p.x, y = p.y, z = p.z + LIFT }
    local top = center.z + R
    local parts = { gate(center, R, yaw, PALETTE.relay, 225, 400), spine(p, PALETTE.relay, 0.3, 60, 140),
        node(p.x, p.y, top + 1.5, PALETTE.relay, 300) }
    drips(p.x, p.y, top + 1.2, top + 0.15, yaw, PALETTE.relay, parts)
    return group("relay", parts, { at = p, rise = 2 * R + 1 })
end

-- GHOST: the checkpoint after it, its gate only, faint.
local function ghost(p, from)
    local R = radiusOf(p)
    return group("ghost", { gate({ x = p.x, y = p.y, z = p.z + LIFT }, R, from and yawTo(from, p) or 0, PALETTE.ghost, 110, 220) }, { at = p })
end

-- DOWNLINK: two gates crossed, turning (a gyroscope), and the tallest spine; when it is
-- the target it gets the node, the drip and the pad too, and rises like a relay.
local function downlink(p, from, isNext)
    local R = radiusOf(p)
    local yaw = from and yawTo(from, p) or 0
    local center = { x = p.x, y = p.y, z = p.z + LIFT }
    local a = gate(center, R, yaw, PALETTE.downlink, isNext and 225 or 150, 600)
    local b = gate(center, R, yaw + 90, PALETTE.downlink, isNext and 170 or 110, 600)
    a.spin, b.spin = 24, 24
    local parts = { a, spine(p, PALETTE.downlink, 0.4, 80, isNext and 170 or 120), b }
    if isNext then
        local top = center.z + R
        parts[#parts + 1] = node(p.x, p.y, top + 1.5, PALETTE.downlink, 400)
        drips(p.x, p.y, top + 1.2, top + 0.15, yaw, PALETTE.downlink, parts)
        parts[#parts + 1] = pad(p, math.max(1, R * 0.9), PALETTE.downlink)
    end
    return group("downlink", parts, { at = p, rise = isNext and (2 * R + 1) or nil })
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
        if not starts[id] then starts[id] = uplink(c.start) end
    end
end

-- ---------------------------------------------------------------------------
-- The run: the relay to reach, the ghost after it, the downlink

local view = {} -- next, nextIndex, ghost, ghostIndex, finish, finishNext
local function clearRun()
    drop(view.next); drop(view.ghost); drop(view.finish)
    view = {}
end
local function pointAt(run, i)
    local cps = run.course.checkpoints
    if i <= #cps then return cps[i], false end
    if i == #cps + 1 then return run.course.finish, true end
    return nil
end
-- where the runner comes from to reach point i (the gate faces that way)
local function before(run, i)
    if i <= 1 then return run.course.start end
    return run.course.checkpoints[i - 1] or run.course.start
end

-- `crossed`: the previous target was just passed (sent up, not dropped).
local function syncRun(crossed)
    local run = Parkour.run
    if not run or run.phase == "finished" then clearRun(); return end
    local cps = run.course.checkpoints
    local n = run.next
    local t, isFinish = pointAt(run, n)
    if view.nextIndex ~= n then
        if crossed then send(view.next) else drop(view.next) end
        view.next, view.nextIndex = nil, n
        if t and not isFinish then view.next = relay(t, before(run, n)) end
    end
    local g, gFinish = pointAt(run, n + 1)
    local gi = (g and not gFinish) and n + 1 or nil
    if view.ghostIndex ~= gi then
        drop(view.ghost)
        view.ghost, view.ghostIndex = gi and ghost(g, before(run, gi)) or nil, gi
    end
    local finishNext = isFinish == true
    if not view.finish or view.finishNext ~= finishNext then
        drop(view.finish)
        view.finish = downlink(run.course.finish, before(run, #cps + 1), finishNext)
        view.finishNext = finishNext
    end
end

-- ---------------------------------------------------------------------------
-- Held on the start until GO: the server freezes the runner (players.life.freeze), the
-- client holds its own body too, again every 200 ms (one freeze did not hold), released
-- at GO, at the end of the run and when the resource stops.

local held = false
local function syncHold()
    local run = Parkour.run
    local want = run ~= nil and run.phase == "countdown"
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
-- The frame loop: animations 20 times a second, the hold and the bearing, the uplinks.

local function animate()
    local t = now()
    local s = Open77.character.state()
    local at = s and s.position
    for g in pairs(groups) do
        local near = not at or not g.at or P.distance(at, g.at) <= ANIM_RANGE
        for _, part in ipairs(g.parts) do
            if part.handle then
                local moving = near and (part.spin or part.bob or part.drip)
                local rising = g.rise and part.born and t - part.born <= RISE_MS + FRAME_MS
                if moving or rising or g.sentAt then
                    local position, rotation = pose(g, part, t)
                    pcall(Open77.markers.update, part.handle, { position = position, rotation = rotation })
                end
            end
        end
        if g.sentAt and t - g.sentAt >= SEND_MS then drop(g) end
    end
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
        syncRun(false)
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
        syncRun(false)
        syncHold()
        sound("sq024_race_countdown_start")
    elseif kind == "go" then
        run.phase = "running"
        syncHold()
        sound("ui_jingle_quest_new")
    elseif kind == "cp" then
        local passed = run.course.checkpoints[p.index]
        run.next = (tonumber(p.index) or 0) + 1
        syncRun(true)
        sound("ui_menu_onpress")
        sound("ui_jingle_quest_update")
        burst(passed)
    elseif kind == "finish" then
        run.phase = "finished"
        send(view.finish); view.finish = nil
        syncRun(false)
        syncHold()
        sound("ui_jingle_quest_success")
        burst(run.course.finish, "sparks.burst.small")
    elseif kind == "dnf" then
        run.phase = "finished"
        syncRun(false)
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
            local ok, err = pcall(animate)
            if not ok then log("parkour: animation failed: %s", tostring(err)) end
            if frame % 4 == 0 then pcall(syncHold) end
            if frame % 3 == 0 then
                ok, err = pcall(syncBearing)
                if not ok then log("parkour: bearing failed: %s", tostring(err)) end
            end
            if frame % 20 == 0 then
                ok, err = pcall(syncStarts)
                if not ok then log("parkour: uplinks failed: %s", tostring(err)) end
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
