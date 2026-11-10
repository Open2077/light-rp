-- The speedometer on NativeUI (ui/speedometer.rml): what the former WebUI page's script did,
-- in Lua. client/main.lua talks to this module as it talked to that page:
--   page:on("speedo:ready", fn)
--   page:send("speedo:config", pageConfig)   the sanitized config (Speedo.pageConfig)
--   page:send("speedo:show", { name, instant? })   the player sat down: enter animation
--   page:send("speedo:hide", {})                   the player left: exit animation
--   page:send("speedo:data", { speed, kph, gear, rpm?, handbrake, abs, tcs, lights, engine,
--                              health, damaged, tires, brokenLights, reversing, fuel? })
--   page:destroy()
-- Presentation only: every decision stays in main.lua. While the display shows, one thread
-- smooths the numbers between the samples (20 Hz) at the configured `fps` and merges into the
-- data model "sp" only the values that changed.
SpeedoUi = {}
local U = SpeedoUi

local DOCUMENT, SHEET = "ui/speedometer.rml", "ui/speedometer.rcss"
local FONT = { "ui/fonts/share-tech-mono-400.ttf", "Share Tech Mono" }
local W = 420
local HOLO_GPS = { width = 780, height = 320, gap = 16 } -- op77_map3d's holo GPS, bottom centre
local RPM_CELLS, GAUGE_CELLS = 30, 10
local ENTER_MS, EXIT_MS, SELFTEST_MS = 640, 380, 520
-- the colours ui/speedometer.rcss is written with (gear: the lines marked "gear")
local THEME = { accent = "#ffcc00", core = "#fff7da", warn = "#ff3b3b", cool = "#7fd8ff" }
local GEAR = "#ffcc00"

local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
local function now() return GetGameTimer() end

-- ── seven-segment digits: 64 x 112, slanted, one path per state ──
local SEG = { ["0"] = "abcdef", ["1"] = "bc", ["2"] = "abged", ["3"] = "abgcd", ["4"] = "fgbc", ["5"] = "afgcd",
    ["6"] = "afgedc", ["7"] = "abc", ["8"] = "abcdefg", ["9"] = "abcdfg", ["-"] = "g", [" "] = "" }
local DW, DH, T, GAP = 64, 112, 11, 2.2
local function hSeg(cy, x0, x1) local h = T / 2; return { { x0, cy }, { x0 + h, cy - h }, { x1 - h, cy - h }, { x1, cy }, { x1 - h, cy + h }, { x0 + h, cy + h } } end
local function vSeg(cx, y0, y1) local h = T / 2; return { { cx, y0 }, { cx + h, y0 + h }, { cx + h, y1 - h }, { cx, y1 }, { cx - h, y1 - h }, { cx - h, y0 + h } } end
local SEGMENTS = {
    a = hSeg(T / 2, T / 2 + GAP, DW - T / 2 - GAP), g = hSeg(DH / 2, T / 2 + GAP, DW - T / 2 - GAP), d = hSeg(DH - T / 2, T / 2 + GAP, DW - T / 2 - GAP),
    f = vSeg(T / 2, T / 2 + GAP, DH / 2 - GAP), b = vSeg(DW - T / 2, T / 2 + GAP, DH / 2 - GAP),
    e = vSeg(T / 2, DH / 2 + GAP, DH - T / 2 - GAP), c = vSeg(DW - T / 2, DH / 2 + GAP, DH - T / 2 - GAP),
}
local SEGMENT_PATH = {}
for name, points in pairs(SEGMENTS) do
    local parts = {}
    for i, p in ipairs(points) do
        -- the slant: x' = x + (DH - y) * 0.09 (the top leans right)
        parts[i] = ("%s%.2f %.2f"):format(i == 1 and "M" or "L", p[1] + (DH - p[2]) * 0.09, p[2])
    end
    SEGMENT_PATH[name] = table.concat(parts, " ") .. " Z"
end
local EMPTY_PATH = "M0 0"
local glyphs = {}
--- The lit and the unlit segments of a character, as two path strings.
function U.glyph(ch)
    local g = glyphs[ch]
    if g then return g.on, g.off end
    local lit, on, off = SEG[ch] or "", {}, {}
    for _, name in ipairs({ "a", "b", "c", "d", "e", "f", "g" }) do
        local list = lit:find(name, 1, true) and on or off
        list[#list + 1] = SEGMENT_PATH[name]
    end
    g = { on = #on > 0 and table.concat(on, " ") or EMPTY_PATH, off = #off > 0 and table.concat(off, " ") or EMPTY_PATH }
    glyphs[ch] = g
    return g.on, g.off
end

--- Three characters and which are leading zeros: test -> 888, else 000..999.
function U.number(n, test)
    if test then return "888", { false, false, false } end
    local s = ("%03d"):format(clamp(math.floor((tonumber(n) or 0) + 0.5), 0, 999))
    local first = s:find("[1-9]")
    return s, { first == nil or 1 < first, first == nil or 2 < first, false }
end

--- The marks under the speed bar: every 20 km/h (10 mph), one in three taller.
function U.ticks(units, speedMax)
    local step = units == "mph" and 10 or 20
    local list = {}
    local v = 0
    while v <= speedMax + 0.01 do
        list[#list + 1] = { x = ("%.2fdp"):format(v / speedMax * W), major = v % (step * 3) == 0 }
        v = v + step
    end
    return list
end

--- The display's scale: the config's, shrunk (down to minScale) on a screen too narrow to
--- keep it clear of op77_map3d's holo GPS. `screenWidth` in dp (px of a 1080-high screen).
function U.scale(layout, screenWidth)
    local right = math.max(0, layout.right - layout.offsetX)
    local bottom = math.max(0, layout.bottom - layout.offsetY)
    local s = layout.scale
    if layout.avoidHoloGps and bottom < HOLO_GPS.height + HOLO_GPS.gap then
        local free = screenWidth - right - (screenWidth / 2 + HOLO_GPS.width / 2 + HOLO_GPS.gap)
        if W * s > free then s = math.max(layout.minScale, math.min(s, free / W)) end
    end
    return s, right, bottom
end

--- High-speed shake at time `seconds`: two incommensurate sines per axis, nothing random.
function U.shake(shake, kph, seconds)
    if not shake.enabled or kph <= shake.fromKph then return 0, 0 end
    local a = math.min(1, (kph - shake.fromKph) / math.max(1, shake.fullKph - shake.fromKph)) * shake.amplitude
    return a * (math.sin(seconds * 41.3) * 0.6 + math.sin(seconds * 17.9) * 0.4),
        a * (math.sin(seconds * 37.1 + 1.3) * 0.6 + math.sin(seconds * 23.7) * 0.4)
end

-- ── theme ──
local function rgb(hex) return type(hex) == "string" and hex:match("^#(%x%x%x%x%x%x)$") and hex:lower() or nil end

--- The theme layer: the sheet's rules that hold a theme colour, with the config's colours
--- (the gear colour on the lines marked "gear"). nil when the theme is the sheet's own.
function U.themeRcss(source, theme)
    local swap, differs = {}, false
    for key, default in pairs(THEME) do
        local value = rgb(theme and theme[key]) or default
        swap[default:sub(2)] = value
        if value ~= default then differs = true end
    end
    local gear = rgb(theme and theme.gear) or swap[GEAR:sub(2)]
    if gear ~= GEAR then differs = true end
    if not differs or type(source) ~= "string" then return nil end
    local out = {}
    for line in source:gmatch("[^\r\n]+") do
        local rule = line:match("^%s*([%.#%a][^{}]*{.*})")
        if rule then
            local isGear = line:find("/* gear */", 1, true) ~= nil
            local replaced, count = rule:gsub("#(%x%x%x%x%x%x)", function(hex)
                if isGear and "#" .. hex == GEAR then return gear end
                return swap[hex]
            end)
            if count > 0 and replaced ~= rule then out[#out + 1] = replaced end
        end
    end
    return table.concat(out, "\n")
end

--- The filter of #holo: the bloom, the scanlines and the theme's opacity. Its lengths follow
--- the scale (a filter is measured on the screen, not on the scaled plane).
function U.filters(theme, scale)
    local accent = rgb(theme.accent) or THEME.accent
    local glow = (tonumber(theme.glow) or 1) * scale
    local parts = {}
    if glow > 0.01 then
        parts[#parts + 1] = ("drop-shadow(%sd9 0dp 0dp %.2fdp)"):format(accent, 2 * glow)
        parts[#parts + 1] = ("drop-shadow(%s6b 0dp 0dp %.2fdp)"):format(accent, 9 * glow)
    end
    -- the page's mask: 2 px clear, 1 px at 58 %
    if theme.scanlines ~= false then parts[#parts + 1] = ("scanlines(0.3 %.2f 0 0)"):format(math.max(2, 3 * scale)) end
    local opacity = tonumber(theme.opacity) or 1
    if opacity < 0.995 then parts[#parts + 1] = ("opacity(%.2f)"):format(opacity) end
    return #parts > 0 and table.concat(parts, " ") or "none"
end

local function defaults()
    local on, off = U.glyph("0")
    return {
        live = false, covered = false, enter = 0, leaving = false, glitch = false,
        hasName = false, name = "", zeros = "dim", over = false, idle = false, shake = "none",
        rpmLit = 0, shift = false,
        d1on = on, d1off = off, d2on = on, d2off = off, d3on = on, d3off = off, lead1 = true, lead2 = true,
        tagHbk = false, tagAbs = false, blinkAbs = false, tagTcs = false, blinkTcs = false,
        fuelLit = 0, fuelNone = true, fuelLow = false, fuelEmpty = false, condLit = 0, condLow = false,
        gear = "N", pop = 0, unit = "KPH",
        lightsOn = false, lightsCool = false, lightsWarn = false, engineOn = false, engineWarn = false,
        tiresWarn = false, tires = "",
        barFill = "scaleX(0)", barHead = "translateX(0dp)", ticks = {},
    }
end
U.defaults = defaults

local fontLoaded = false

--- A surface with the page API client/main.lua uses: on, send, destroy.
--- options: zIndex, fps (how often the numbers are smoothed and merged while it shows).
function U.create(options)
    if type(Open77.ui) ~= "table" or type(Open77.ui.create) ~= "function" then return nil, "nativeui_unavailable" end
    options = options or {}
    -- the HUD lab (tools/native-lab) draws it above the pre-game shell, whose cursor is held
    local lab = type(Op77UiLab) == "table" and Op77UiLab or nil
    local ignoreCapture = lab ~= nil and lab.ignoreCapture == true
    if not fontLoaded and type(Open77.ui.loadFont) == "function" then
        local ok, loaded, why = pcall(Open77.ui.loadFont, FONT[1], FONT[2])
        fontLoaded = ok and loaded ~= false
        if not fontLoaded then print("[speedometer] font " .. FONT[1] .. " not loaded: " .. tostring(ok and why or loaded)) end
    end
    local ui, why = Open77.ui.create({
        document = DOCUMENT, layer = lab and lab.layer or "hud", zIndex = math.floor(tonumber(options.zIndex) or 710), visible = true,
        models = { sp = defaults() },
    })
    if not ui then return nil, why end
    local interval = math.floor(1000 / clamp(math.floor(tonumber(options.fps) or 30), 10, 60))

    local page = { handlers = {} }
    local alive = true
    local held = defaults()      -- what the document's model holds
    local cfg = Speedo.pageConfig(SpeedoConfig or {})
    local themed = false
    local sheet = nil            -- ui/speedometer.rcss, read once
    local screenWidth = 1920     -- dp
    local target = nil           -- the last speedo:data
    local vehicleName = ""
    local shownSpeed, shownRpm = 0, 0
    local live, leaving, looping = false, false, false
    local enteredAt, last = 0, now()
    local hideToken = 0
    local lastGear = nil
    local nextGlitch = now() + 4000

    local function patch(fields)
        local changed
        for k, v in pairs(fields) do
            if type(v) == "table" or held[k] ~= v then
                held[k] = v
                changed = changed or {}
                changed[k] = v
            end
        end
        if changed then ui:merge("sp", changed) end
    end
    local function after(ms, fn)
        CreateThread(function()
            Wait(ms)
            if alive then fn() end
        end)
    end

    -- ── config & placement ──
    local function readScreen()
        if type(ui.state) ~= "function" then return false end
        local ok, state = pcall(ui.state, ui)
        local w, h = ok and type(state) == "table" and tonumber(state.width), ok and type(state) == "table" and tonumber(state.height)
        if not w or not h or w <= 0 or h <= 0 then return false end
        local width = math.floor(w * 1080 / h + 0.5)
        if width == screenWidth then return false end
        screenWidth = width
        return true
    end
    -- Bottom right, right / bottom from the config (dp of a 1080-high screen).
    local function layout()
        local l = cfg.layout
        local scale, right, bottom = U.scale(l, screenWidth)
        ui:style("#stage", {
            right = ("%.2fdp"):format(right), bottom = ("%.2fdp"):format(bottom), transform = ("scale(%.4f)"):format(scale),
        })
        ui:style("#holo", "filter", U.filters(cfg.theme, scale))
    end
    local function applyConfig(nextConfig)
        if type(nextConfig) == "table" then cfg = Speedo.merge(cfg, nextConfig) end
        local l, theme = cfg.layout, cfg.theme
        if sheet == nil then
            local ok, text = pcall(LoadResourceFile, GetCurrentResourceName(), SHEET)
            sheet = ok and type(text) == "string" and text or false
        end
        local layer = U.themeRcss(sheet or nil, theme)
        if layer or themed then
            ui:stylesheet("theme", layer)
            themed = layer ~= nil
        end
        ui:style("#haze", "opacity", theme.opacity < 0.995 and ("%.2f"):format(theme.opacity) or nil)
        ui:style("#plane", "transform", l.tilt and ("rotateX(%.2fdeg) rotateY(%.2fdeg)"):format(l.tiltX, l.tiltY) or "none")
        patch({
            zeros = cfg.leadingZeros, unit = cfg.unitLabel or (cfg.units == "mph" and "MPH" or "KPH"),
            hasName = cfg.showVehicleName and vehicleName ~= "", ticks = U.ticks(cfg.units, cfg.speedMax),
        })
        readScreen()
        layout()
    end

    -- ── the frame: numbers follow the samples, everything else is the last sample ──
    local function frame(t)
        local dt = math.min(0.1, math.max(0, (t - last) / 1000))
        last = t
        local s = target or { speed = 0, kph = 0, gear = "N", rpm = 0 }
        local speed, kph = tonumber(s.speed) or 0, tonumber(s.kph) or 0
        local since = t - enteredAt
        local testing = live and since < SELFTEST_MS
        local f = {}

        -- a critically damped follow of the 20 Hz samples
        shownSpeed = shownSpeed + (speed - shownSpeed) * (1 - math.exp(-dt * 11))
        if math.abs(speed - shownSpeed) < 0.05 then shownSpeed = speed end
        local rpmTarget = type(s.rpm) == "number" and s.rpm or math.min(1, kph / 160)
        shownRpm = shownRpm + (rpmTarget - shownRpm) * (1 - math.exp(-dt * 16))

        local rpm
        if testing then
            -- self-test: every segment lit, the strip sweeps up and back
            rpm = math.sin(math.pi * since / SELFTEST_MS)
            f.fuelLit, f.condLit = GAUGE_CELLS, GAUGE_CELLS
            f.tagHbk, f.tagAbs, f.tagTcs = true, true, true
        else
            rpm = shownRpm
            f.tagHbk = s.handbrake == true
            f.tagAbs, f.blinkAbs = s.abs == true, s.abs == true
            f.tagTcs, f.blinkTcs = s.tcs == true, s.tcs == true
            local fuel = type(s.fuel) == "table" and s.fuel or nil
            f.fuelNone = fuel == nil
            f.fuelLow = fuel ~= nil and fuel.low == true and fuel.empty ~= true
            f.fuelEmpty = fuel ~= nil and fuel.empty == true
            f.fuelLit = math.floor(clamp(fuel and tonumber(fuel.fraction) or 0, 0, 1) * GAUGE_CELLS + 0.5)
            f.condLow = s.damaged == true
            f.condLit = math.floor(clamp(type(s.health) == "number" and s.health or 1, 0, 1) * GAUGE_CELLS + 0.5)
        end
        local digits, lead = U.number(shownSpeed, testing)
        f.lead1, f.lead2 = lead[1], lead[2]
        for i = 1, 3 do f["d" .. i .. "on"], f["d" .. i .. "off"] = U.glyph(digits:sub(i, i)) end
        f.rpmLit = math.floor(clamp(rpm, 0, 1) * RPM_CELLS + 0.5)
        f.shift = rpm >= 0.95

        -- speed bar
        local fill = clamp(shownSpeed / cfg.speedMax, 0, 1)
        f.barFill = ("scaleX(%.4f)"):format(fill)
        f.barHead = ("translateX(%.1fdp)"):format(fill * (W - 4))
        f.over = speed > cfg.speedMax

        -- gear
        local gear = tostring(s.gear or "N")
        if gear ~= lastGear then
            f.gear = gear
            if lastGear ~= nil and not testing then f.pop = held.pop == 1 and 2 or 1 end
            lastGear = gear
        end

        -- icons: lights (high beams in the cool colour), engine, tyres
        local lights = math.floor(tonumber(s.lights) or 0)
        local broken = (tonumber(s.brokenLights) or 0) > 0
        local tires = math.floor(tonumber(s.tires) or 0)
        f.lightsOn = lights == 1 and not broken
        f.lightsCool = lights == 2 and not broken
        f.lightsWarn = lights > 0 and broken
        f.engineOn = s.engine == true and s.damaged ~= true
        f.engineWarn = s.damaged == true
        f.tiresWarn = tires > 0
        f.tires = tires > 0 and tostring(tires) or ""
        f.idle = not testing and s.engine == false and kph < 1

        -- high-speed shake
        local sx, sy = 0, 0
        if live and not testing then sx, sy = U.shake(cfg.shake, kph, t / 1000) end
        f.shake = (sx ~= 0 or sy ~= 0) and ("translate(%.2fdp, %.2fdp)"):format(sx, sy) or "none"

        -- the odd flicker
        if cfg.theme.flicker and live and not testing and t > nextGlitch then
            f.glitch = true
            after(70 + math.floor(math.random() * 60), function() patch({ glitch = false }) end)
            nextGlitch = t + 3500 + math.floor(math.random() * 6000)
        end
        patch(f)
    end
    local function loop()
        if looping then return end
        looping = true
        last = now()
        CreateThread(function()
            while alive and (live or leaving) do
                frame(now())
                Wait(interval)
            end
            looping = false
        end)
    end

    local function show(p)
        p = type(p) == "table" and p or {}
        hideToken = hideToken + 1
        vehicleName = tostring(p.name or "")
        local f = { name = vehicleName, hasName = cfg.showVehicleName and vehicleName ~= "", live = true, leaving = false }
        leaving = false
        if p.instant then
            f.enter = 3
            enteredAt = now() - ENTER_MS
        else
            f.enter = (held.enter == 1) and 2 or 1
            enteredAt = now()
            shownSpeed, shownRpm = 0, 0
        end
        live = true
        patch(f)
        loop()
    end
    local function hide()
        if not live then return end
        live, leaving = false, true
        patch({ enter = 0, leaving = true, shake = "none" })
        hideToken = hideToken + 1
        local token = hideToken
        after(EXIT_MS + 40, function()
            if token ~= hideToken then return end
            leaving = false
            patch({ live = false, leaving = false })
        end)
    end

    -- ── the page API ──
    function page.on(_, name, fn) page.handlers[name] = fn end
    function page.send(_, name, payload)
        if not alive then return end
        if name == "speedo:data" then
            if type(payload) == "table" then
                target = payload
                if live then loop() end
            end
        elseif name == "speedo:show" then show(payload)
        elseif name == "speedo:hide" then hide()
        elseif name == "speedo:config" then applyConfig(payload)
        end
    end
    function page.destroy()
        alive = false
        pcall(ui.destroy, ui)
    end

    -- (re)loaded: the document is back at its defaults; main.lua sends everything again
    local function ready()
        if not alive then return end
        held = defaults()
        ui:merge("sp", defaults())
        live, leaving, lastGear, themed = false, false, nil, false
        hideToken = hideToken + 1
        applyConfig(nil)
        local fn = page.handlers["speedo:ready"]
        if fn then fn() end
    end
    ui:onEvent("loaded", ready)
    ui:onEvent("reloaded", ready)
    ui:onEvent("error", function(name, detail)
        print("[speedometer] HUD " .. tostring(name) .. ": " .. tostring(type(detail) == "table" and detail.message or detail))
    end)

    -- NativeUI draws above every WebUI page: step aside at once while another interface
    -- holds the cursor (pause menu, inventory, phone). The same thread follows the screen's
    -- shape (the display shrinks on narrow screens), every two seconds.
    CreateThread(function()
        local turns = 0
        while alive do
            Wait(150)
            local busy = false
            if not ignoreCapture and type(Open77.input) == "table" and type(Open77.input.isCaptured) == "function" then
                local ok, _, cursor = pcall(Open77.input.isCaptured)
                busy = ok and cursor == true
            end
            if alive and busy ~= held.covered then patch({ covered = busy }) end
            turns = turns + 1
            if alive and turns % 13 == 0 and readScreen() then layout() end
        end
    end)

    return page
end
