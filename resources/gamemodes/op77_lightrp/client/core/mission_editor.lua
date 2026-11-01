-- Staff mission editor, client half: relays the page's requests to the server
-- (server/modules/mission_editor.lua), runs the BUILD MODE and draws the draft
-- in the world for its author only.
--
-- Build mode (F9 from the menu): the crosshair traces the world 20 times a
-- second; the element of the current tool is drawn where it would land, and the
-- element under the crosshair is highlighted.
--   left click   place / drop (Move tool: pick up, then drop)
--   right click  select the aimed element (the menu opens on its page)
--   Delete       remove the aimed element
--   Up / Down    previous / next tool        Left / Right  turn the facing
--   F10          place at the crosshair      F11           place at my feet
--   F9           back to the menu
-- Shooting, melee and grenades are blocked while building. The page owns the
-- draft and applies every action; this file only measures and draws.
local E, Ui = LightRpEvents, LightRpUi
local NET, PAGE = "op77_lightrp:missioneditor", "lightrp:ui:missioneditor"
local Editor = { active = false, mode = "closed", draft = nil, focus = nil, build = nil, hover = nil, aim = nil }
LightRpMissionEditor = Editor
local drawKey, ghostKey = "lightrp:missions:draft", "lightrp:missions:ghost"
local drawWarning, started = false, false
local AIM_DISTANCE, HOVER_RADIUS = 250, 2.2
local AIM_GROUPS = { "Static", "Terrain" }
local BLOCKED = { "Attack", "Melee", "Grenade" }
local function send(value) Ui.send(PAGE, value) end
-- One line per distinct outcome, so a preview that never shows can be read from the log.
local reported = {}
local function report(key, fmt, ...)
    if reported[key] then return end
    reported[key] = true
    Ui.log("mission editor: " .. fmt, ...)
end

local sequence = 0
local outgoing, draining, lastSent = {}, false, -1000
local function forward(payload)
    if type(payload.request) ~= "string" then
        sequence = sequence + 1
        payload.request = "client:" .. tostring(GetGameTimer()) .. ":" .. tostring(sequence)
    end
    if #outgoing >= 32 then
        send({ kind = "response", request = payload.request, ok = false, error = "Too many pending requests. Your draft is kept." })
        return
    end
    outgoing[#outgoing + 1] = payload
    if draining then return end
    draining = true
    CreateThread(function()
        while #outgoing > 0 do
            local delay = 180 - (GetGameTimer() - lastSent)
            if delay > 0 then Wait(delay) end
            local nextRequest = table.remove(outgoing, 1)
            lastSent = GetGameTimer()
            TriggerServerEvent(NET, nextRequest)
        end
        draining = false
    end)
end

local function clear(key)
    if Open77.debugDraw and Open77.debugDraw.clear then pcall(Open77.debugDraw.clear, key) end
end
local claimed = false
local function claimWeapons(on)
    if claimed == on then return end
    claimed = on
    for _, action in ipairs(BLOCKED) do
        if LightRpControlClaims then pcall(LightRpControlClaims.set, "missioneditor", action, on)
        elseif Open77.input and Open77.input.setActionBlocked then pcall(Open77.input.setActionBlocked, action, on) end
    end
end
local function input(mode)
    if mode ~= "menu" and mode ~= "form" and mode ~= "typing" and mode ~= "world" then mode = "closed" end
    Editor.mode = mode
    claimWeapons(mode == "world")
    if mode ~= "world" then clear(ghostKey); Editor.hover, Editor.aim = nil, nil end
    if mode == "world" or mode == "closed" then Ui.setSupportInput("closed")
    elseif mode == "typing" then
        Ui.setSupportInput("form")
        if Ui.page then Ui.page:setConsumedKeys({}); Ui.page:setFocus(true, false) end
    else Ui.setSupportInput(mode) end
end
local function cleanup(notify)
    Editor.active, Editor.draft, Editor.focus, Editor.build = false, nil, nil, nil
    input("closed")
    clear(drawKey); clear(ghostKey)
    if notify then send({ kind = "invalidate", error = notify }) end
end

RegisterNetEvent(NET, function(value)
    if type(value) ~= "table" then return end
    if value.kind == "open" then
        if not Ui.characterReady or Ui.creationActive or Ui.actionFocus or (LightRpSafezones and LightRpSafezones.active) then
            return send({ kind = "invalidate", error = "Finish your current activity before editing missions." })
        end
        Ui.setMenuOpen(false)
        if LightRpAnimations then LightRpAnimations.close() end
        Editor.active = true
        input("menu")
    end
    send(value)
end)

-- ---------------------------------------------------------------------------
-- Measuring

local function round(n) return math.floor(n * 100 + 0.5) / 100 end
local function facing(from, to)
    local dx, dy = to.x - from.x, to.y - from.y
    if dx * dx + dy * dy < 0.01 then return nil end
    return round(math.deg(math.atan(-dx, dy)) % 360)
end
local function trace()
    if not Open77.camera or type(Open77.camera.aimRay) ~= "function" then report("aim:missing", "camera.aimRay missing"); return nil, "Aiming needs a newer client." end
    -- The ground of the game is two collision groups: the city is `Static`, the open
    -- terrain (Badlands, hills, slopes) is `Terrain`, which the default trace ignores.
    -- Clients older than Stable 157 refuse `groups`: the plain static trace then.
    local ok, ray, why = pcall(Open77.camera.aimRay, AIM_DISTANCE, { groups = AIM_GROUPS })
    if not ok or ray == nil then
        report("aim-groups:" .. tostring(ok and why or ray), "grouped aim trace refused (%s), static only", tostring(ok and why or ray))
        ok, ray, why = pcall(Open77.camera.aimRay, AIM_DISTANCE, { dynamic = false })
    end
    if not ok or ray == nil then
        report("aim:" .. tostring(ok and why or ray), "aim trace unavailable: %s", tostring(ok and why or ray))
        return nil, "Aiming unavailable (" .. tostring(ok and why or ray) .. ")."
    end
    if not ray.hit then return nil, "Nothing under the crosshair within 250 m." end
    report("aim:ok", "aim trace ok (hit %.1f m away)", tonumber(ray.distance) or -1)
    return { x = round(ray.position.x), y = round(ray.position.y), z = round(ray.position.z) }
end
-- Where an element lands and which way it faces. Aimed: facing back at the
-- author unless the page set a facing; at the feet: the author's own facing.
local function capture(kind)
    local state = Open77.character.state()
    if not state or not state.position then return nil, "Your position is unavailable." end
    local feet = { x = round(state.position.x), y = round(state.position.y), z = round(state.position.z) }
    local own = round((tonumber(state.yaw) or 0) % 360)
    local manual = Editor.build and tonumber(Editor.build.heading)
    if kind == "aim" then
        local p, why = trace()
        if not p then return nil, why end
        return { position = p, heading = manual or facing(p, feet) or own }
    end
    return { position = feet, heading = manual or own }
end

-- ---------------------------------------------------------------------------
-- What the crosshair points at

local function finite(n) return type(n) == "number" and n == n and math.abs(n) <= 100000 end
local function point(p) return type(p) == "table" and finite(p.x) and finite(p.y) and finite(p.z) end
local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
local function hovered(m, p)
    if type(m) ~= "table" or not p then return nil end
    local best, bestD
    local function consider(ref, q)
        if point(q) then
            local d = dist(p, q)
            if d <= HOVER_RADIUS and (not bestD or d < bestD) then ref.position = { x = q.x, y = q.y, z = q.z }; best, bestD = ref, d end
        end
    end
    for _, s in ipairs(m.spawns or {}) do
        consider({ type = "spawn", id = s.id, label = s.label }, s.position)
        for j, q in ipairs(s.route or {}) do consider({ type = "route", id = s.id, index = j, label = (s.label or "Spawn") .. " · patrol " .. j }, q) end
    end
    for _, c in ipairs(m.checkpoints or {}) do consider({ type = "checkpoint", id = c.id, label = c.label }, c.position) end
    for i, s in ipairs(m.starts or {}) do consider({ type = "start", index = i, label = "Start " .. i }, s) end
    consider({ type = "board", label = "Mission board" }, m.point)
    local z = m.perimeter or {}
    if z.shape == "poly" then
        for i, q in ipairs(z.points or {}) do consider({ type = "vertex", index = i, label = "Perimeter vertex " .. i }, q) end
    else consider({ type = "centre", label = "Perimeter centre" }, z.center) end
    return best
end
local function same(a, b)
    return a == b or (a and b and a.type == b.type and a.id == b.id and a.index == b.index)
end

-- ---------------------------------------------------------------------------
-- Drawing (debug wireframes, author only)

local COLORS = { perimeter = "#ffcc00ed", perimeterFill = "#ffcc001a", start = "#3ddc84ff", board = "#f2f3f5ff",
    start_spawn = "#ff4d4dff", checkpoint_spawn = "#ff9f1cff", wave_spawn = "#d65bffff", checkpoint = "#22d8e2ff",
    route = "#d65bffb0", focus = "#ffffffff", hover = "#ffffffff" }
local TOOL_COLORS = { spawn = "#ff4d4dff", checkpoint = "#22d8e2ff", start = "#3ddc84ff", perimeter = "#ffcc00ff",
    radius = "#ffcc00ff", patrol = "#d65bffff", move = "#ffffffff", board = "#f2f3f5ff" }

local function circle(batch, c, radius, z, color, segments)
    segments = segments or 24
    for i = 0, segments - 1 do
        local a, b = i * 2 * math.pi / segments, (i + 1) * 2 * math.pi / segments
        batch.lines[#batch.lines + 1] = { a = { x = c.x + math.cos(a) * radius, y = c.y + math.sin(a) * radius, z = z },
            b = { x = c.x + math.cos(b) * radius, y = c.y + math.sin(b) * radius, z = z }, color = color }
    end
end
local function pillar(batch, p, height, color)
    batch.lines[#batch.lines + 1] = { a = { x = p.x, y = p.y, z = p.z }, b = { x = p.x, y = p.y, z = p.z + height }, color = color }
end
local function line(batch, a, b, color) batch.lines[#batch.lines + 1] = { a = a, b = b, color = color } end
local function arrow(batch, p, heading, length, color)
    local a = math.rad(heading or 0)
    local tip = { x = p.x - math.sin(a) * length, y = p.y + math.cos(a) * length, z = p.z + 0.1 }
    line(batch, { x = p.x, y = p.y, z = p.z + 0.1 }, tip, color)
    for _, side in ipairs({ 0.45, -0.45 }) do
        local back = a + math.pi + side
        line(batch, tip, { x = tip.x - math.sin(back) * 0.4, y = tip.y + math.cos(back) * 0.4, z = tip.z }, color)
    end
end
local function cross(batch, p, size, color)
    line(batch, { x = p.x - size, y = p.y, z = p.z + 0.05 }, { x = p.x + size, y = p.y, z = p.z + 0.05 }, color)
    line(batch, { x = p.x, y = p.y - size, z = p.z + 0.05 }, { x = p.x, y = p.y + size, z = p.z + 0.05 }, color)
end

-- Perimeter walls: a floor and a ceiling outline plus some verticals. A circle is 32
-- segments with a vertical every other point; the translucent fill only when the
-- perimeter is the element being edited (inside a zone it tints the whole screen).
local function perimeterWalls(batch, zone, color, fill, yield, fillColor)
    yield = yield or function() end
    if type(zone) ~= "table" or not finite(zone.minZ) or not finite(zone.maxZ) then return end
    local low, high = zone.minZ, zone.maxZ
    if zone.fullHeight then
        local state = Open77.character.state()
        local altitude = state and state.position and state.position.z or zone.center and zone.center.z or 0
        low, high = altitude - 10, altitude + 20
    end
    local pts, every = {}, 1
    if zone.shape == "circle" and point(zone.center) and finite(zone.radius) and zone.radius > 0 then
        for i = 0, 31 do
            local a = i * math.pi / 16
            pts[#pts + 1] = { x = zone.center.x + math.cos(a) * zone.radius, y = zone.center.y + math.sin(a) * zone.radius }
        end
        every = 2
    elseif zone.shape == "box" and point(zone.center) and finite(zone.length) and finite(zone.width) and finite(zone.heading) then
        local a = zone.heading * math.pi / 180
        local c, sn = math.cos(a), math.sin(a)
        for _, k in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
            local x, y = k[1] * zone.length / 2, k[2] * zone.width / 2
            pts[#pts + 1] = { x = zone.center.x + c * x - sn * y, y = zone.center.y + sn * x + c * y }
        end
    elseif zone.shape == "poly" and type(zone.points) == "table" then
        for _, q in ipairs(zone.points) do if point(q) then pts[#pts + 1] = q end end
    end
    local n = #pts
    if n < 2 then return end
    local closed = zone.shape ~= "poly" or n >= 3
    for i, q in ipairs(pts) do
        if i % 12 == 0 then yield() end
        local r = pts[i % n + 1]
        if i % every == 0 or zone.shape ~= "circle" then line(batch, { x = q.x, y = q.y, z = low }, { x = q.x, y = q.y, z = high }, color) end
        if closed or i < n then
            line(batch, { x = q.x, y = q.y, z = low }, { x = r.x, y = r.y, z = low }, color)
            line(batch, { x = q.x, y = q.y, z = high }, { x = r.x, y = r.y, z = high }, color)
            if fill and n >= 3 then
                batch.triangles[#batch.triangles + 1] = { a = { x = q.x, y = q.y, z = low }, b = { x = q.x, y = q.y, z = high }, c = { x = r.x, y = r.y, z = low }, color = fillColor or COLORS.perimeterFill }
                batch.triangles[#batch.triangles + 1] = { a = { x = q.x, y = q.y, z = high }, b = { x = r.x, y = r.y, z = high }, c = { x = r.x, y = r.y, z = low }, color = fillColor or COLORS.perimeterFill }
            end
        end
    end
end

Editor.walls = perimeterWalls

function Editor.geometry(m, focus, hover, yield)
    if type(m) ~= "table" then return nil end
    yield = yield or function() end
    local batch = { lines = {}, triangles = {}, ttl = 1.5, maxDistance = 1000 }
    local function tone(ref, color) return (focus == ref or (hover and hover == ref)) and COLORS.focus or color end
    local zone = m.perimeter
    if type(zone) == "table" then
        local hot = focus == "perimeter"
        perimeterWalls(batch, zone, hot and COLORS.focus or COLORS.perimeter, hot, yield)
        yield()
        if zone.shape == "poly" then
            for i, q in ipairs(zone.points or {}) do if point(q) then pillar(batch, q, 3, tone("vertex:" .. i, COLORS.perimeter)) end end
        elseif point(zone.center) then cross(batch, zone.center, 0.6, tone("centre", COLORS.perimeter)) end
    end
    yield()
    if point(m.point) then
        local color = tone("board", COLORS.board)
        pillar(batch, m.point, 4, color); circle(batch, m.point, 1, m.point.z + 0.05, color, 12)
    end
    for i, s in ipairs(type(m.starts) == "table" and m.starts or {}) do
        if point(s) then
            local color = tone("start:" .. i, COLORS.start)
            pillar(batch, s, 2, color); arrow(batch, s, s.heading, 1.2, color)
        end
    end
    yield()
    for n, s in ipairs(type(m.spawns) == "table" and m.spawns or {}) do
        if n % 6 == 0 then yield() end
        if type(s) == "table" and point(s.position) then
            local color = tone("spawn:" .. tostring(s.id), COLORS[(s.trigger or "start") .. "_spawn"] or COLORS.start_spawn)
            pillar(batch, s.position, 2.5, color)
            circle(batch, s.position, math.max(0.6, tonumber(s.spread) or 2), s.position.z + 0.05, color, 16)
            arrow(batch, s.position, s.heading, 1.2, color)
            if s.behavior == "defend" or s.behavior == "wander" then
                circle(batch, s.position, tonumber(s.radius) or 12, s.position.z + 0.15, color, 32)
            end
            -- the patrol route, closed back to the spawn point
            local previous = s.position
            for j, q in ipairs(type(s.route) == "table" and s.route or {}) do
                if point(q) then
                    local rc = tone("route:" .. tostring(s.id) .. ":" .. j, COLORS.route)
                    line(batch, { x = previous.x, y = previous.y, z = previous.z + 0.3 }, { x = q.x, y = q.y, z = q.z + 0.3 }, COLORS.route)
                    pillar(batch, q, 1.2, rc)
                    previous = q
                end
            end
            if previous ~= s.position then line(batch, { x = previous.x, y = previous.y, z = previous.z + 0.3 }, { x = s.position.x, y = s.position.y, z = s.position.z + 0.3 }, "#d65bff60") end
        end
    end
    yield()
    for n, c in ipairs(type(m.checkpoints) == "table" and m.checkpoints or {}) do
        if n % 6 == 0 then yield() end
        if type(c) == "table" and point(c.position) and finite(c.radius) and c.radius > 0 and c.radius <= 30 then
            local color = tone("checkpoint:" .. tostring(c.id), COLORS.checkpoint)
            circle(batch, c.position, c.radius, c.position.z + 0.1, color, 32)
            circle(batch, c.position, c.radius, c.position.z + 1.6, color, 32)
            pillar(batch, c.position, 3, color)
            for _, id in ipairs(type(c.spawns) == "table" and c.spawns or {}) do
                for _, s in ipairs(m.spawns or {}) do
                    if s.id == id and point(s.position) then
                        line(batch, { x = c.position.x, y = c.position.y, z = c.position.z + 3 }, { x = s.position.x, y = s.position.y, z = s.position.z + 2.5 }, "#ff9f1c80")
                    end
                end
            end
        end
    end
    return batch
end

local function hoverKey(h)
    if not h then return nil end
    if h.type == "spawn" or h.type == "checkpoint" then return h.type .. ":" .. tostring(h.id) end
    if h.type == "route" then return "route:" .. tostring(h.id) .. ":" .. h.index end
    if h.type == "start" or h.type == "vertex" then return h.type .. ":" .. h.index end
    return h.type
end

-- The element the current tool would create, where the crosshair points.
function Editor.ghost(build, p, m)
    if not build or not p then return nil end
    local color = TOOL_COLORS[build.tool] or "#ffffffff"
    local batch = { lines = {}, triangles = {}, ttl = 0.2, maxDistance = 400 }
    local state = Open77.character.state()
    local heading = tonumber(build.heading) or (state and state.position and facing(p, state.position)) or 0
    if build.tool == "spawn" then
        pillar(batch, p, 2.5, color); circle(batch, p, math.max(0.6, tonumber(build.spread) or 2), p.z + 0.05, color, 16)
        arrow(batch, p, heading, 1.6, color)
        for i = 1, math.min(12, tonumber(build.count) or 1) do pillar(batch, { x = p.x + 0.18 * i - 0.18, y = p.y, z = p.z + 2.7 }, 0.25, color) end
    elseif build.tool == "checkpoint" then
        local r = tonumber(build.radius) or 5
        circle(batch, p, r, p.z + 0.1, color, 32); circle(batch, p, r, p.z + 1.6, color, 32); pillar(batch, p, 3, color)
    elseif build.tool == "start" then
        pillar(batch, p, 2, color); arrow(batch, p, heading, 1.4, color)
    elseif build.tool == "perimeter" then
        local z = m and m.perimeter
        pillar(batch, p, 4, color)
        if z and z.shape == "poly" and #(z.points or {}) > 0 then
            local last, first = z.points[#z.points], z.points[1]
            line(batch, { x = last.x, y = last.y, z = p.z + 0.2 }, { x = p.x, y = p.y, z = p.z + 0.2 }, color)
            line(batch, { x = p.x, y = p.y, z = p.z + 0.2 }, { x = first.x, y = first.y, z = p.z + 0.2 }, "#ffcc0060")
        else cross(batch, p, 1, color) end
    elseif build.tool == "radius" then
        local z = m and m.perimeter
        if z and point(z.center) then
            local r = math.sqrt((p.x - z.center.x) ^ 2 + (p.y - z.center.y) ^ 2)
            circle(batch, z.center, r, p.z + 0.2, color, 48)
            line(batch, { x = z.center.x, y = z.center.y, z = p.z + 0.2 }, { x = p.x, y = p.y, z = p.z + 0.2 }, color)
        end
    elseif build.tool == "patrol" then
        pillar(batch, p, 1.2, color)
        local owner
        for _, s in ipairs(m and m.spawns or {}) do if s.id == build.spawn then owner = s end end
        if owner then
            local route = owner.route or {}
            local from = route[#route] or owner.position
            line(batch, { x = from.x, y = from.y, z = from.z + 0.3 }, { x = p.x, y = p.y, z = p.z + 0.3 }, color)
        end
    elseif build.tool == "board" then
        pillar(batch, p, 4, color); circle(batch, p, 1, p.z + 0.05, color, 12)
    else
        circle(batch, p, 0.5, p.z + 0.05, color, 12)
        if build.carrying then pillar(batch, p, 3, color) end
    end
    return batch
end

-- ---------------------------------------------------------------------------
-- Build actions -> page

local function buildAction(action, extra)
    if not Editor.active or Editor.mode ~= "world" or not Editor.draft then return end
    local payload = { kind = "build", action = action, hovered = Editor.hover }
    for k, v in pairs(extra or {}) do payload[k] = v end
    if action == "place" or action == "placeFeet" then
        local value, why = capture(action == "placeFeet" and "feet" or "aim")
        if not value then send({ kind = "build", action = "error", error = why }) return end
        payload.position, payload.heading = value.position, value.heading
    end
    send(payload)
end

function Editor.bind(page)
    page:on(PAGE, function(p)
        if type(p) ~= "table" or type(p.operation) ~= "string" then return end
        if p.operation == "preview" then
            if not Editor.active then return end
            Editor.draft = type(p.mission) == "table" and p.mission or nil
            Editor.focus = type(p.focus) == "string" and p.focus or nil
            Editor.build = type(p.build) == "table" and p.build or nil
            Editor.version = (Editor.version or 0) + 1
            if not Editor.draft then clear(drawKey) end
        elseif p.operation == "input" then
            if Editor.active then input(p.mode) end
        elseif p.operation == "capture" then
            local value, why = capture(p.mode == "aim" and "aim" or "feet")
            send({ kind = "response", request = p.request, ok = value ~= nil, data = value, error = why })
        elseif p.operation == "close" then
            cleanup()
        else forward(p) end
    end)
end

function Editor.start()
    if started then return end
    started = true
    RegisterKeyMapping("lightrp.missions.inspector", "Mission editor: build mode / menu", "F9", function()
        if not Editor.active or Editor.mode == "typing" then return end
        local mode = Editor.mode == "world" and "menu" or "world"
        input(mode); send({ kind = "editor", mode = mode })
    end)
    RegisterKeyMapping("lightrp.missions.place", "Mission editor: place (build mode)", "MOUSE1", function() buildAction("place") end)
    RegisterKeyMapping("lightrp.missions.select", "Mission editor: select the aimed element", "MOUSE2", function() buildAction("select") end)
    RegisterKeyMapping("lightrp.missions.remove", "Mission editor: remove the aimed element", "DELETE", function() buildAction("delete") end)
    RegisterKeyMapping("lightrp.missions.toolPrevious", "Mission editor: previous tool", "UP", function() buildAction("tool", { delta = -1 }) end)
    RegisterKeyMapping("lightrp.missions.toolNext", "Mission editor: next tool", "DOWN", function() buildAction("tool", { delta = 1 }) end)
    RegisterKeyMapping("lightrp.missions.turnLeft", "Mission editor: turn left", "LEFT", function() buildAction("rotate", { delta = 15 }) end)
    RegisterKeyMapping("lightrp.missions.turnRight", "Mission editor: turn right", "RIGHT", function() buildAction("rotate", { delta = -15 }) end)
    RegisterKeyMapping("lightrp.missions.capture", "Mission editor: place where I aim", "F10", function()
        if Editor.active and Editor.draft and Editor.mode ~= "typing" then
            if Editor.mode == "world" then buildAction("place") else send({ kind = "captureKey", mode = "aim" }) end
        end
    end)
    RegisterKeyMapping("lightrp.missions.feet", "Mission editor: place at my feet", "F11", function()
        if Editor.active and Editor.draft and Editor.mode ~= "typing" then
            if Editor.mode == "world" then buildAction("placeFeet") else send({ kind = "captureKey", mode = "feet" }) end
        end
    end)
    -- The crosshair (20 Hz, build mode) and the draft. One resume must stay short (the
    -- runtime retires a loop that overruns its slice), so each pass is its own resume and
    -- the draft's wireframe is rebuilt only when it changed, then re-sent with a long TTL.
    CreateThread(function()
        local cache, sentAt = { key = nil, batch = nil }, -1e9
        while true do
            Wait(50)
            if Editor.active then
                local state = Open77.character.state()
                if not state or not state.alive or not state.attached then
                    cleanup("Mission editor closed because your character is unavailable.")
                elseif Editor.draft then
                    if Editor.mode == "world" then
                        local p = trace()
                        local h = hovered(Editor.draft, p)
                        if not same(h, Editor.hover) then
                            Editor.hover = h
                            send({ kind = "hover", hovered = h })
                        end
                        Editor.aim = p
                        Wait(0)
                        local ghost = Editor.ghost(Editor.build, p, Editor.draft)
                        -- the aimed element, highlighted white on top of the draft
                        if ghost and h and h.position then
                            pillar(ghost, h.position, 3.2, COLORS.hover)
                            circle(ghost, h.position, 0.9, h.position.z + 0.08, COLORS.hover, 12)
                        end
                        if ghost and Open77.debugDraw then
                            local ok, result, why = pcall(Open77.debugDraw.set, ghostKey, ghost)
                            if not ok or result == false or result == nil then report("ghost:" .. tostring(ok and why or result), "ghost draw refused: %s %s", tostring(result), tostring(why))
                            else report("ghost:ok", "ghost drawn (%d lines)", #ghost.lines) end
                        else clear(ghostKey) end
                        Wait(0)
                    end
                    local key = tostring(Editor.version) .. "|" .. tostring(Editor.focus)
                    local now = GetGameTimer()
                    if key ~= cache.key and Editor.draft then
                        cache.key = key
                        cache.batch = Editor.geometry(Editor.draft, Editor.focus, nil, function() Wait(0) end)
                        sentAt = -1e9
                        Wait(0)
                    end
                    if cache.batch and now - sentAt >= 700 and Editor.active and Editor.draft and Open77.debugDraw and Open77.debugDraw.set then
                        sentAt = now
                        local ok, result, why = pcall(Open77.debugDraw.set, drawKey, cache.batch)
                        if not ok or result == false or result == nil then report("draft:" .. tostring(ok and why or result), "draft draw refused: %s %s", tostring(result), tostring(why))
                        else report("draft:ok", "draft drawn (%d lines, %d triangles)", #cache.batch.lines, #cache.batch.triangles) end
                        if (not ok or result == false) and not drawWarning then
                            drawWarning = true
                            Ui.send(E.page.notice, { kind = "error", title = "Mission editor", body = "3D preview unavailable. Update your client and check the world.debug permission." })
                        end
                    end
                end
            else
                cache.key, cache.batch = nil, nil
            end
        end
    end)
end

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then cleanup() end
end)
