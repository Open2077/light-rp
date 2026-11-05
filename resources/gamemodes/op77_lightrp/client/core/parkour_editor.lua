-- Staff parkour editor, client half (server/modules/parkour.lua, page
-- ui/src/features/parkour/ParkourEditor.tsx). The page owns the draft; this file relays
-- its requests to the server, measures (at my feet / where I aim) and draws the draft in
-- the world for its author only (debug lines: every orb's trigger sphere, the route, the
-- fall line).
--
-- Menu mode: the RageMenu has the keyboard, the author keeps walking.
--   F9 build mode / back to the menu · F10 place where I aim · F11 place at my feet
-- Build mode (F9): the crosshair traces the world 20 times a second.
--   LEFT CLICK  place with the tool (checkpoint: appended; start / finish: moved)
--   RIGHT CLICK open the aimed orb in the menu · DELETE remove the aimed checkpoint
--   UP / DOWN   tool · LEFT / RIGHT turn the start's facing
-- Shooting, melee and grenades are blocked while building.
local E, Ui = LightRpEvents, LightRpUi
local P = LightRpParkour
local NET, PAGE = E.net.parkourEditor, E.page.parkourEditor
local Editor = { active = false, mode = "closed", draft = nil, focus = nil, tool = nil, hover = nil }
LightRpParkourEditor = Editor
local DRAW, GHOST = "lightrp:parkour:draft", "lightrp:parkour:ghost"
local AIM_DISTANCE, HOVER_PAD = 200, 1.0
local AIM_GROUPS = { "Static", "Terrain" }
local BLOCKED = { "Attack", "Melee", "Grenade" }
local LIFT = P.config.orbLift
local function send(value) Ui.send(PAGE, value) end
local reported = {}
local function report(key, fmt, ...)
    if reported[key] then return end
    reported[key] = true
    Ui.log("parkour editor: " .. fmt, ...)
end

-- Requests to the server, at most one every 180 ms.
local sequence, outgoing, draining, lastSent = 0, {}, false, -1000
local function forward(payload)
    if type(payload.request) ~= "string" then
        sequence = sequence + 1
        payload.request = "client:" .. tostring(GetGameTimer()) .. ":" .. tostring(sequence)
    end
    if #outgoing >= 16 then
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
            lastSent = GetGameTimer()
            TriggerServerEvent(NET, table.remove(outgoing, 1))
        end
        draining = false
    end)
end

local function clear(key) if Open77.debugDraw and Open77.debugDraw.clear then pcall(Open77.debugDraw.clear, key) end end
local claimed = false
local function claimWeapons(on)
    if claimed == on then return end
    claimed = on
    for _, action in ipairs(BLOCKED) do
        if LightRpControlClaims then pcall(LightRpControlClaims.set, "parkoureditor", action, on)
        elseif Open77.input and Open77.input.setActionBlocked then pcall(Open77.input.setActionBlocked, action, on) end
    end
end
local function input(mode)
    if mode ~= "menu" and mode ~= "typing" and mode ~= "world" then mode = "closed" end
    Editor.mode = mode
    claimWeapons(mode == "world")
    if mode ~= "world" then clear(GHOST); Editor.hover = nil end
    if mode == "world" or mode == "closed" then Ui.setSupportInput("closed")
    elseif mode == "typing" then
        Ui.setSupportInput("form")
        if Ui.page then Ui.page:setConsumedKeys({}); Ui.page:setFocus(true, false) end
    else Ui.setSupportInput("menu") end
end
local function cleanup(notify)
    Editor.active, Editor.draft, Editor.focus, Editor.tool = false, nil, nil, nil
    input("closed")
    clear(DRAW); clear(GHOST)
    if notify then send({ kind = "invalidate", error = notify }) end
end

-- Big answers (the course list) reach the page as JSON text in parts.
local PAGE_VALUES, PART_BYTES = 900, 48 * 1024
local function countValues(value, depth)
    if type(value) ~= "table" then return 1 end
    if (depth or 0) > 16 then return 1 end
    local n = 1
    for _, item in pairs(value) do n = n + 1 + countValues(item, (depth or 0) + 1) end
    return n
end
local partSeq = 0
local function sendParts(value)
    local encode = LightRpMissionEditor and LightRpMissionEditor.encodeJson
    if type(encode) ~= "function" then send({ kind = "response", request = value.request, ok = false, error = "Answer too large." }); return end
    local ok, text = pcall(encode, value)
    if not ok or type(text) ~= "string" then send({ kind = "response", request = value.request, ok = false, error = "Answer unreadable." }); return end
    partSeq = partSeq + 1
    local id, parts, at = "pk" .. partSeq, {}, 1
    while at <= #text do
        local stop = math.min(#text, at + PART_BYTES - 1)
        while stop < #text and stop > at do
            local b = text:byte(stop + 1)
            if b < 0x80 or b >= 0xC0 then break end
            stop = stop - 1
        end
        parts[#parts + 1] = text:sub(at, stop)
        at = stop + 1
    end
    for i, part in ipairs(parts) do send({ kind = "parts", id = id, part = i, parts = #parts, text = part }) end
end

RegisterNetEvent(NET, function(value)
    if type(value) ~= "table" then return end
    if value.kind == "open" then
        if not Ui.characterReady or Ui.creationActive or Ui.actionFocus or (LightRpMissionEditor and LightRpMissionEditor.active) then
            return send({ kind = "invalidate", error = "Finish what you are doing before editing courses." })
        end
        Ui.setMenuOpen(false)
        if LightRpAnimations then LightRpAnimations.close() end
        Editor.active = true
        input("menu")
    end
    if countValues(value) > PAGE_VALUES then return sendParts(value) end
    send(value)
end)

-- ---------------------------------------------------------------------------
-- Measuring

local function round(n) return math.floor(n * 100 + 0.5) / 100 end
local function trace()
    if not Open77.camera or type(Open77.camera.aimRay) ~= "function" then return nil, "Aiming needs a newer client." end
    local ok, ray, why = pcall(Open77.camera.aimRay, AIM_DISTANCE, { groups = AIM_GROUPS })
    if not ok or ray == nil then ok, ray, why = pcall(Open77.camera.aimRay, AIM_DISTANCE, { dynamic = false }) end
    if not ok or ray == nil then
        report("aim:" .. tostring(ok and why or ray), "aim trace unavailable: %s", tostring(ok and why or ray))
        return nil, "Aiming unavailable."
    end
    if not ray.hit then return nil, "Nothing under the crosshair within " .. AIM_DISTANCE .. " m." end
    return { x = round(ray.position.x), y = round(ray.position.y), z = round(ray.position.z) }
end
local function capture(kind)
    local state = Open77.character.state()
    if not state or not state.position then return nil, "Your position is unavailable." end
    local own = round((tonumber(state.yaw) or 0) % 360)
    if kind == "aim" then
        local p, why = trace()
        if not p then return nil, why end
        return { position = p, heading = own }
    end
    return { position = { x = round(state.position.x), y = round(state.position.y), z = round(state.position.z) }, heading = own }
end

-- The orb under the crosshair (within its trigger radius + a pad).
local function finite(n) return type(n) == "number" and n == n end
local function hovered(course, p)
    if type(course) ~= "table" or not p then return nil end
    local best, bestD
    local function consider(ref, q)
        if type(q) == "table" and finite(q.x) and finite(q.y) and finite(q.z) then
            local d = math.sqrt((p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 + (p.z - q.z) ^ 2)
            if d <= (tonumber(q.radius) or 3) + HOVER_PAD and (not bestD or d < bestD) then best, bestD = ref, d end
        end
    end
    consider({ type = "start" }, course.start)
    for i, c in ipairs(course.checkpoints or {}) do consider({ type = "checkpoint", index = i }, c) end
    consider({ type = "finish" }, course.finish)
    return best
end
local function same(a, b) return a == b or (a and b and a.type == b.type and a.index == b.index) end

-- ---------------------------------------------------------------------------
-- Drawing

local COLORS = { start = "#00f0ffff", checkpoint = "#ffcc00ff", finish = "#3ddc84ff", route = "#ffffff90", focus = "#ffffffff",
    floor = "#ff4d4dc0", hover = "#ffffffff" }
local function circle(batch, c, radius, z, color, segments)
    segments = segments or 24
    for i = 0, segments - 1 do
        local a, b = i * 2 * math.pi / segments, (i + 1) * 2 * math.pi / segments
        batch.lines[#batch.lines + 1] = { a = { x = c.x + math.cos(a) * radius, y = c.y + math.sin(a) * radius, z = z },
            b = { x = c.x + math.cos(b) * radius, y = c.y + math.sin(b) * radius, z = z }, color = color }
    end
end
local function line(batch, a, b, color) batch.lines[#batch.lines + 1] = { a = a, b = b, color = color } end
-- A sphere as its equator and two meridians (about 45 lines: a 50-checkpoint course stays
-- a few thousand lines, built a few orbs per resume).
local function sphere(batch, p, r, color)
    local cz = p.z + LIFT
    circle(batch, p, r, cz, color, 20)
    for k = 0, 1 do
        local seg = 12
        for i = 0, seg - 1 do
            local a, b = i * 2 * math.pi / seg, (i + 1) * 2 * math.pi / seg
            local ox, oy = k == 0 and 1 or 0, k == 0 and 0 or 1
            line(batch, { x = p.x + math.cos(a) * r * ox, y = p.y + math.cos(a) * r * oy, z = cz + math.sin(a) * r },
                { x = p.x + math.cos(b) * r * ox, y = p.y + math.cos(b) * r * oy, z = cz + math.sin(b) * r }, color)
        end
    end
    line(batch, { x = p.x, y = p.y, z = p.z }, { x = p.x, y = p.y, z = cz + r + 2 }, color)
end
local function arrow(batch, p, heading, color)
    local a = math.rad(heading or 0)
    local dx, dy = -math.sin(a), math.cos(a)
    local tip = { x = p.x + dx * 2.2, y = p.y + dy * 2.2, z = p.z + 0.15 }
    line(batch, { x = p.x, y = p.y, z = p.z + 0.15 }, tip, color)
    line(batch, tip, { x = tip.x - dx * 0.6 + dy * 0.4, y = tip.y - dy * 0.6 - dx * 0.4, z = tip.z }, color)
    line(batch, tip, { x = tip.x - dx * 0.6 - dy * 0.4, y = tip.y - dy * 0.6 + dx * 0.4, z = tip.z }, color)
end

function Editor.geometry(course, focus, yield)
    local batch = { lines = {}, triangles = {}, ttl = 2.5, maxDistance = 600 }
    if type(course) ~= "table" then return batch end
    local route = {}
    local function point(q) return type(q) == "table" and finite(q.x) and finite(q.y) and finite(q.z) end
    if point(course.start) then
        sphere(batch, course.start, tonumber(course.start.radius) or 3, focus == "start" and COLORS.focus or COLORS.start)
        arrow(batch, course.start, course.start.heading, COLORS.start)
        route[#route + 1] = course.start
    end
    for i, c in ipairs(course.checkpoints or {}) do
        if point(c) then
            sphere(batch, c, tonumber(c.radius) or 3, focus == ("checkpoint:" .. i) and COLORS.focus or COLORS.checkpoint)
            route[#route + 1] = c
        end
        if yield and i % 4 == 0 then yield() end
    end
    if point(course.finish) then
        sphere(batch, course.finish, tonumber(course.finish.radius) or 3, focus == "finish" and COLORS.focus or COLORS.finish)
        route[#route + 1] = course.finish
    end
    for i = 2, #route do
        line(batch, { x = route[i - 1].x, y = route[i - 1].y, z = route[i - 1].z + LIFT }, { x = route[i].x, y = route[i].y, z = route[i].z + LIFT }, COLORS.route)
    end
    local fz = tonumber(course.floorZ)
    if fz and #route > 0 then
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        for _, q in ipairs(route) do minX, minY, maxX, maxY = math.min(minX, q.x), math.min(minY, q.y), math.max(maxX, q.x), math.max(maxY, q.y) end
        minX, minY, maxX, maxY = minX - 15, minY - 15, maxX + 15, maxY + 15
        local corners = { { minX, minY }, { maxX, minY }, { maxX, maxY }, { minX, maxY } }
        for i = 1, 4 do
            local a, b = corners[i], corners[i % 4 + 1]
            line(batch, { x = a[1], y = a[2], z = fz }, { x = b[1], y = b[2], z = fz }, COLORS.floor)
        end
        local step = math.max(5, (maxX - minX) / 12)
        local x = minX + step
        while x < maxX do line(batch, { x = x, y = minY, z = fz }, { x = x, y = maxY, z = fz }, COLORS.floor); x = x + step end
    end
    return batch
end

local TOOL_COLORS = { checkpoint = COLORS.checkpoint, start = COLORS.start, finish = COLORS.finish, move = "#ffffffff" }
local function ghost(p, h)
    local batch = { lines = {}, triangles = {}, ttl = 0.25, maxDistance = 400 }
    if p then
        local tool = Editor.tool or {}
        local color = TOOL_COLORS[tool.name] or "#ffffffff"
        sphere(batch, p, tonumber(tool.radius) or 3, color)
    end
    if h and h.position then circle(batch, h.position, (tonumber(h.radius) or 3) + 0.4, h.position.z + LIFT, COLORS.hover, 28) end
    return batch
end

-- ---------------------------------------------------------------------------
-- Build mode keys (polled while in world mode) and the page

local function buildAction(action, extra)
    if not Editor.active or Editor.mode ~= "world" or not Editor.draft then return end
    local payload = { kind = "build", action = action, hovered = Editor.hover }
    for k, v in pairs(extra or {}) do payload[k] = v end
    if action == "place" then
        local value, why = capture("aim")
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
            Editor.draft = type(p.course) == "table" and p.course or nil
            Editor.focus = type(p.focus) == "string" and p.focus or nil
            Editor.tool = type(p.tool) == "table" and p.tool or nil
            Editor.version = (Editor.version or 0) + 1
            if not Editor.draft then clear(DRAW) end
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

local started = false
local function start()
    if started then return end
    started = true
    RegisterKeyMapping("lightrp.parkour.editor.build", "Parkour editor: build mode / menu", "F9", function()
        if not Editor.active or Editor.mode == "typing" or not Editor.draft then return end
        local mode = Editor.mode == "world" and "menu" or "world"
        input(mode); send({ kind = "editor", mode = mode })
    end)
    RegisterKeyMapping("lightrp.parkour.editor.aim", "Parkour editor: place where I aim", "F10", function()
        if Editor.active and Editor.draft and Editor.mode == "menu" then send({ kind = "captureKey", mode = "aim" }) end
    end)
    RegisterKeyMapping("lightrp.parkour.editor.feet", "Parkour editor: place at my feet", "F11", function()
        if Editor.active and Editor.draft and Editor.mode == "menu" then send({ kind = "captureKey", mode = "feet" }) end
    end)
    CreateThread(function()
        local cache, sentAt = { key = nil, batch = nil }, -1e9
        local keys = { place = "MOUSE1", select = "MOUSE2", remove = "DELETE", up = "UP", down = "DOWN", left = "LEFT", right = "RIGHT" }
        local down = {}
        while true do
            Wait(50)
            if Editor.active then
                local state = Open77.character.state()
                if not state or not state.alive or not state.attached then
                    cleanup("Parkour editor closed: your character is unavailable.")
                elseif Editor.draft then
                    if Editor.mode == "world" then
                        local typing = Open77.input.isCaptured and Open77.input.isCaptured() == true
                        for name, key in pairs(keys) do
                            local isDown = not typing and Open77.input.isDown(key) == true
                            if isDown and not down[name] then
                                if name == "place" then buildAction("place")
                                elseif name == "select" then buildAction("select")
                                elseif name == "remove" then buildAction("delete")
                                elseif name == "up" then buildAction("tool", { delta = -1 })
                                elseif name == "down" then buildAction("tool", { delta = 1 })
                                elseif name == "left" then buildAction("rotate", { delta = 15 })
                                elseif name == "right" then buildAction("rotate", { delta = -15 }) end
                            end
                            down[name] = isDown
                        end
                        local p = trace()
                        local h = hovered(Editor.draft, p)
                        if h then
                            local q = h.type == "checkpoint" and Editor.draft.checkpoints[h.index] or Editor.draft[h.type]
                            if q then h.position, h.radius = { x = q.x, y = q.y, z = q.z }, q.radius end
                        end
                        if not same(h, Editor.hover) then
                            Editor.hover = h
                            send({ kind = "hover", hovered = h })
                        end
                        Wait(0)
                        if Open77.debugDraw then pcall(Open77.debugDraw.set, GHOST, ghost(p, h)) end
                        Wait(0)
                    else
                        down = {}
                    end
                    local key = tostring(Editor.version) .. "|" .. tostring(Editor.focus)
                    local now = GetGameTimer()
                    if key ~= cache.key then
                        cache.key = key
                        cache.batch = Editor.geometry(Editor.draft, Editor.focus, function() Wait(0) end)
                        sentAt = -1e9
                        Wait(0)
                    end
                    if cache.batch and now - sentAt >= 1500 and Editor.active and Editor.draft and Open77.debugDraw and Open77.debugDraw.set then
                        sentAt = now
                        local ok, result, why = pcall(Open77.debugDraw.set, DRAW, cache.batch)
                        if not ok or result == false or result == nil then report("draw:" .. tostring(ok and why or result), "draft draw refused: %s %s", tostring(result), tostring(why))
                        else report("draw:ok", "draft drawn (%d lines)", #cache.batch.lines) end
                    end
                end
            else
                cache.key, cache.batch = nil, nil
            end
        end
    end)
end
Editor.start = start
CreateThread(start)

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then cleanup() end
end)
