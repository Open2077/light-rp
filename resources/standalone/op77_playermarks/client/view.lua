-- The plates as a NativeUI document (ui/playermarks.rml): what the former WebUI page's script did, in Lua.
-- Two feeds, as the page had:
--   - V.send("pm:add" | "pm:name" | "pm:remove" | "pm:talk" | "pm:config", payload) from
--     client/main.lua: which anchor carries which player's plate, its name, who is talking;
--   - V.frame(), every game frame: where each anchor is on screen (Open77.anchors.frame(),
--     projected by the plugin). NativeUI anchors only follow <scene3d> points, so the plates
--     are moved here: one ui:batch per frame, only the values that changed, transforms and
--     opacity only (nothing is laid out again). A plate off screen is display:none.
PlayerMarksView = {}
local V = PlayerMarksView

local ui, loaded = nil, false
local plates = {}                   -- player id -> plate
local byAnchor = {}                 -- anchor id -> plate
local cfg = { radius = 35, page = { nearScale = 1.0, farScale = 0.6, fadeFrom = 0.75 } }
-- The screen in dp (1 dp = 1 px of a 1080-line screen): 1920 x 1080 on 16:9.
local screen = { w = 1920, h = 1080, ratio = 1 }
local suppressed, hideUnderMenus = false, true
local stamp, lastFrame, nextBusy, nextScreen = 0, nil, 0, 0
local warned = {}

-- The HUD lab (tools/native-lab): its driver sets Op77UiLab before this script loads. The
-- document then goes on the lab's layer (above the pre-game shell, which holds the cursor)
-- and does not step aside under a captured cursor. Absent in game: nothing changes.
local LAB = type(Op77UiLab) == "table" and Op77UiLab or nil
-- Lab hook: V.anchorSource = function() return { { id, projected, onScreen, x, y, distance }, ... } end
-- answers in place of Open77.anchors.frame() (no world in the lab, so no anchor resolves).

local fmt, floor, abs = string.format, math.floor, math.abs
local function clamp(v, a, b) return math.max(a, math.min(b, v)) end
local function warn(key, text)
    if warned[key] then return end
    warned[key] = true
    print("[playermarks] " .. text)
end

local function now()
    if type(GetGameTimer) == "function" then return GetGameTimer() end
    return Open77.time.monotonic() * 1000
end

-- A string cut inside a UTF-8 sequence: drop the broken tail.
function V.trimUtf8(text)
    local n = #text
    for i = n, math.max(1, n - 3), -1 do
        local b = text:byte(i)
        if b < 0x80 then return text end
        if b >= 0xC0 then
            local need = (b >= 0xF0 and 4) or (b >= 0xE0 and 3) or 2
            if n - i + 1 >= need then return text end
            return text:sub(1, i - 1)
        end
    end
    return text
end

-- .pm__name: text-transform uppercase. ASCII, and the Latin-1 letters (é -> É): RCSS's own
-- text-transform only knows ASCII.
local function upper(text)
    text = V.trimUtf8(tostring(text or "")):upper()
    return (text:gsub("\195([\160-\190])", function(c)
        local b = c:byte()
        if b == 183 then return nil end -- U+00F7, the division sign
        return "\195" .. string.char(b - 32)
    end))
end
V.upper = upper

-- Text from players as RML: markup escaped, and the braces too ("{{" opens a data binding
-- in RmlUi, even in a document without a model, and the whole text is then refused). The
-- host's own ui:text escapes < > & " but not braces, so player text never goes through it.
local ESC = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;", ["{"] = "&#x7B;", ["}"] = "&#x7D;" }
function V.esc(text) return (tostring(text):gsub('[&<>"{}]', ESC)) end
local esc = V.esc

-- The chip's plates: the page's background and 1 px inset line, as chamfer decorators. Their
-- cut (6 px) and line are in physical pixels: scaled like a dp here.
local function plateDecorator(fill, line)
    local r = screen.ratio
    return fmt("fx(chamfer-solid %.2f 0 0 0 %s), fx(chamfer %.2f %.2f 0.001 0 %s)", 6 * r, fill, 6 * r, r, line)
end
local function chipRml()
    return '<div class="pm-bg pm-bg-idle" style="decorator: ' .. plateDecorator("#060608bd", "#ffcc0024") .. ';"></div>'
        .. '<div class="pm-accent"></div>'
end

-- The tip pulse while talking (pm-tip: 0.9 s ease-out, infinite): the diamond grows from
-- the tip to about 7 px around it and fades from 70 %.
local function pulse(p, on)
    if on then
        ui:keyframes(p.pulse, { channel = "scale", duration = 0.9, iterations = -1,
            stops = { { offset = 0, value = 1, easing = "ease-out" }, { offset = 1, value = 3.8 } } })
        ui:keyframes(p.pulse, { channel = "background-color", duration = 0.9, iterations = -1,
            stops = { { offset = 0, value = "#ffcc00b3", easing = "ease-out" }, { offset = 1, value = "#ffcc0000" } } })
    else
        ui:stop(p.pulse)
        ui:style(p.pulse, { transform = "scale(1)", ["background-color"] = "#ffcc0000" })
    end
end

-- One plate's elements. Inside a ui:batch.
local function build(p)
    p.el = ui:create("#marks", { tag = "div", class = p.talking and "pm is-talking" or "pm", style = { display = "none" } })
    p.rig = ui:create(p.el, { tag = "div", class = "pm-rig", rml = '<div class="pm-pin"></div>' })
    local ring = ui:create(p.rig, { tag = "div", class = "pm-pulse" })
    p.pulse = ui:create(ring, { tag = "div", class = "pm-pulse-in" })
    ui:create(p.rig, { tag = "div", class = "pm-tip" })
    local box = ui:create(p.rig, { tag = "div", class = "pm-box" })
    local chip = ui:create(box, { tag = "div", class = "pm-chip", rml = chipRml() })
    p.talkBg = ui:create(chip, { tag = "div", class = "pm-bg pm-bg-talk",
        style = { decorator = plateDecorator("#241b00d1", "#ffcc0073") } })
    local row = ui:create(chip, { tag = "div", class = "pm-row" })
    local voice = ui:create(row, { tag = "div", class = "pm-voice" })
    p.bars = {
        ui:create(voice, { tag = "div", class = "v" }),
        ui:create(voice, { tag = "div", class = "v" }),
        ui:create(voice, { tag = "div", class = "v v-last" }),
    }
    p.label = ui:create(row, { tag = "span", class = "pm-name", rml = esc(upper(p.name)) })
    if p.talking then pulse(p, true) end
    -- nothing written yet: the next frame sends every value
    p.shown, p.display, p.hideAt, p.show = false, false, nil, 0
    p.mix = p.talking and 1 or 0
    p.tr, p.k, p.fade, p.barScale, p.lx, p.op, p.talkOp = nil, nil, 1, {}, nil, nil, nil
end

local function drop(player)
    local p = plates[player]
    if not p then return end
    plates[player] = nil
    if byAnchor[p.anchor] == p then byAnchor[p.anchor] = nil end
    if ui and loaded and p.el then ui:remove(p.el) end
end

local function rebuildAll()
    if not ui or not loaded then return end
    ui:batch(function()
        for _, p in pairs(plates) do
            if p.el then ui:remove(p.el) end
            build(p)
        end
    end)
end

local handlers = {}
handlers["pm:config"] = function(c)
    if type(c) ~= "table" then return end
    if (tonumber(c.radius) or 0) > 0 then cfg.radius = tonumber(c.radius) end
    if type(c.page) == "table" then
        for k, v in pairs(c.page) do if tonumber(v) then cfg.page[k] = tonumber(v) end end
    end
    if c.hideUnderMenus ~= nil then hideUnderMenus = c.hideUnderMenus ~= false end
    -- the next frame scales and fades every plate again, moved or not
    for _, p in pairs(plates) do p.lx = nil end
end
handlers["pm:add"] = function(msg)
    if type(msg) ~= "table" or type(msg.player) ~= "string" or type(msg.anchor) ~= "string" then return end
    drop(msg.player)
    local p = { player = msg.player, anchor = msg.anchor, name = tostring(msg.name or ""), talking = false, level = 0, phase = 0 }
    plates[msg.player] = p
    byAnchor[msg.anchor] = p
    if ui and loaded then ui:batch(function() build(p) end) end
end
handlers["pm:name"] = function(msg)
    local p = type(msg) == "table" and plates[tostring(msg.player)]
    if not p then return end
    p.name = tostring(msg.name or "")
    if ui and loaded and p.label then ui:rml(p.label, esc(upper(p.name))) end
end
handlers["pm:remove"] = function(msg)
    if type(msg) == "table" then drop(tostring(msg.player)) end
end
handlers["pm:talk"] = function(msg)
    local p = type(msg) == "table" and plates[tostring(msg.player)]
    if not p then return end
    local talking = msg.talking == true
    p.level = clamp(tonumber(msg.level) or 0, 0, 1)
    if talking == p.talking then return end
    p.talking = talking
    if not (ui and loaded and p.el) then return end
    ui:batch(function()
        ui:class(p.el, "is-talking", talking)
        pulse(p, talking)
        if not talking then
            -- back to the three ink stubs (the RCSS height)
            for i = 1, 3 do
                if p.barScale[i] then p.barScale[i] = nil; ui:style(p.bars[i], "transform", nil) end
            end
        end
    end)
end

--- The feed from client/main.lua (the page's messages, same names and payloads).
function V.send(_, name, payload)
    local handler = handlers[name]
    if handler then handler(payload) end
end

-- ---------------------------------------------------------------------------------------
-- The frame.
-- ---------------------------------------------------------------------------------------

-- What the plugin projected on its last frame: { id, projected, onScreen, x, y, distance }.
local function readAnchors()
    local read = V.anchorSource
    if type(read) ~= "function" then
        local anchors = Open77.anchors
        read = type(anchors) == "table" and (type(anchors.frame) == "function" and anchors.frame or anchors.list)
    end
    if type(read) ~= "function" then return nil end
    local ok, list = pcall(read)
    if not ok or type(list) ~= "table" then return nil end
    return list
end

-- NativeUI draws over every WebUI page: while another interface holds the cursor (an
-- inventory, a menu, the phone) the plates step aside, as they sat under those pages before.
local function cursorTaken()
    if not hideUnderMenus or (LAB and LAB.ignoreCapture == true) then return false end
    if type(Open77.input) ~= "table" or type(Open77.input.isCaptured) ~= "function" then return false end
    local ok, _, cursor = pcall(Open77.input.isCaptured)
    return ok and cursor == true
end

local function readScreen()
    local ok, state = pcall(ui.state, ui)
    if not ok or type(state) ~= "table" then return end
    local w, h = tonumber(state.width), tonumber(state.height)
    if not w or not h or w < 1 or h < 1 then return end
    local ratio = math.max(0.5, h / 1080)
    local changed = abs(ratio - screen.ratio) > 0.001
    screen.w, screen.h, screen.ratio = w / ratio, h / ratio, ratio
    if changed then rebuildAll() end
end

-- pm-bar: each bar swings between 3 px and 6 + level * 5 px, a half swing lasting
-- 0.62 - level * 0.22 s (ease-in-out, alternate), the second and third 0.21 s and 0.42 s
-- ahead. Written as scaleY of an 11 px bar, only when it moved a quarter pixel.
local BAR_LEAD = { 0, 0.21, 0.42 }
local function bars(p, dt)
    local half = 0.62 - p.level * 0.22
    p.phase = (p.phase + dt / half) % 2
    local top = 6 + p.level * 5
    for i = 1, 3 do
        local u = (p.phase + BAR_LEAD[i] / half) % 2
        if u > 1 then u = 2 - u end
        local e = u * u * (3 - 2 * u)
        local h = floor((3 + (top - 3) * e) * 4 + 0.5) / 4
        if p.barScale[i] ~= h then
            p.barScale[i] = h
            ui:style(p.bars[i], "transform", fmt("scaleY(%.3f)", h / 11))
        end
    end
end

local frameList, frameNow, frameDt

local function place(p, a)
    local d = tonumber(a.distance) or 0
    -- nothing moved since the last frame: nothing to write
    if p.lx == a.x and p.ly == a.y and p.ld == d and p.lw == screen.w then return end
    p.lx, p.ly, p.ld, p.lw = a.x, a.y, d, screen.w
    local t = clamp(d / cfg.radius, 0, 1)
    local page = cfg.page
    local k = page.nearScale + (page.farScale - page.nearScale) * t
    local fade = page.fadeFrom < 1 and 1 - clamp((t - page.fadeFrom) / (1 - page.fadeFrom), 0, 1) or 1
    local tr = fmt("translate(%.1fdp, %.1fdp)", a.x * screen.w, a.y * screen.h)
    if tr ~= p.tr then p.tr = tr; ui:style(p.el, "transform", tr) end
    if not p.k or abs(k - p.k) >= 0.004 then p.k = k; ui:style(p.rig, "transform", fmt("scale(%.3f)", k)) end
    p.fade = fade
end

-- The plate's opacities: the distance fade times the 160 ms show fade (.pm: opacity 160 ms
-- linear) on the rig, and on the talking plate the same times its 160 ms cross-fade. Written
-- when they moved a hundredth (RmlUi does not multiply opacity down the tree).
local function fades(p, dt)
    local want = p.shown and 1 or 0
    if p.show ~= want then
        p.show = want > p.show and math.min(1, p.show + dt / 0.16) or math.max(0, p.show - dt / 0.16)
    end
    local mixWant = p.talking and 1 or 0
    if p.mix ~= mixWant then
        p.mix = mixWant > p.mix and math.min(1, p.mix + dt / 0.16) or math.max(0, p.mix - dt / 0.16)
    end
    local op = floor(p.fade * p.show * 100 + 0.5) / 100
    if op ~= p.op then p.op = op; ui:style(p.rig, "opacity", fmt("%.2f", op)) end
    local talkOp = floor(op * p.mix * 100 + 0.5) / 100
    if talkOp ~= p.talkOp then p.talkOp = talkOp; ui:style(p.talkBg, "opacity", fmt("%.2f", talkOp)) end
end

local function drawFrame()
    stamp = stamp + 1
    for _, a in ipairs(frameList) do
        local p = byAnchor[tostring(a.id)]
        if p and p.el then
            local shown = not suppressed and a.projected ~= false and a.onScreen ~= false
                and (tonumber(a.distance) or 0) <= cfg.radius
            if shown then
                p.stamp = stamp
                place(p, a)
                if p.talking then bars(p, frameDt) end
            end
        end
    end
    for _, p in pairs(plates) do
        if p.el then
            -- an anchor missing from the frame is out of range or not streamed: hidden
            local shown = p.stamp == stamp
            if shown ~= p.shown then
                p.shown = shown
                if shown then
                    p.hideAt = nil
                    if not p.display then p.display = true; ui:style(p.el, "display", "block") end
                else
                    p.hideAt = frameNow + 200 -- .pm: opacity 160 ms, then out of the tree
                end
                ui:class(p.el, "is-shown", shown)
            end
            if p.display then fades(p, frameDt) end
            if p.hideAt and frameNow >= p.hideAt then
                p.hideAt, p.display = nil, false
                ui:style(p.el, "display", "none")
            end
        end
    end
end

--- One frame: reads the anchors, moves the plates. Returns true while there is a plate.
function V.frame()
    if not ui or not loaded then return false end
    if next(plates) == nil then lastFrame = nil; return false end
    local t = now()
    if t >= nextBusy then
        nextBusy = t + 150
        local busy = cursorTaken()
        if busy ~= suppressed then
            suppressed = busy
            ui:class("#marks", "is-off", busy)
        end
    end
    if t >= nextScreen then
        nextScreen = t + 1000
        readScreen()
    end
    frameList = readAnchors() or {}
    frameNow, frameDt = t, clamp(lastFrame and (t - lastFrame) / 1000 or 0, 0, 0.1)
    lastFrame = t
    local ok, err = pcall(ui.batch, ui, drawFrame)
    if not ok then warn("frame", "frame failed: " .. tostring(err)) end
    return true
end

-- ---------------------------------------------------------------------------------------
-- The document.
-- ---------------------------------------------------------------------------------------

--- Creates the document. Returns true, or false and a reason.
function V.start(options)
    if ui then return true end
    if type(options) == "table" and options.hideUnderMenus ~= nil then hideUnderMenus = options.hideUnderMenus ~= false end
    local created, why
    for _ = 1, 2400 do -- up to 10 min: a slow first load keeps the resource preparing for minutes (2026-11-05)
        created, why = Open77.ui.create({ document = "ui/playermarks.rml", layer = LAB and LAB.layer or "hud", zIndex = 10, visible = true })
        if created or why ~= "resource_preparing" then break end
        Wait(250)
    end
    if not created then return false, why end
    ui = created
    ui:onEvent("loaded", function()
        loaded = true
        readScreen()
        rebuildAll()
    end)
    ui:onEvent("reloaded", function()
        suppressed = false
        rebuildAll()
    end)
    ui:onEvent("error", function(name, detail)
        warn("ui:" .. tostring(name), "ui " .. tostring(name) .. ": " .. tostring(type(detail) == "table" and detail.message or detail))
    end)
    return true
end

function V.stop()
    if ui then pcall(ui.destroy, ui) end
    ui, loaded = nil, false
    for key in pairs(plates) do plates[key] = nil end
    for key in pairs(byAnchor) do byAnchor[key] = nil end
end

-- For the offline tests.
V.plates = plates
function V.attach(handle) ui, loaded = handle, true end
function V.screen() return screen end
