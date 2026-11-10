-- The weapon HUD on NativeUI (ui/weaponhud.rml): what the former WebUI page's script did, in
-- Lua. client/main.lua talks to this module as it talked to that page:
--   page:on("weapon:ready", fn)
--   page:send("weapon:config", pageConfig)   the sanitized config (WeaponHud.pageConfig)
--   page:send("weapon:show", { key, name, type, class, melee, capacity, instant? })
--   page:send("weapon:hide", {})
--   page:send("weapon:data", { magazine, capacity, reserve, reloading, shots, reloaded, low, empty, left? })
--   page:send("weapon:inset", { px })
--   page:destroy()
-- Presentation only: every decision stays in main.lua. The document is driven by the data
-- model "wh"; only the values that changed are merged. Timers are Lua threads.
WeaponHudUi = {}
local U = WeaponHudUi

local DOCUMENT, SHEET = "ui/weaponhud.rml", "ui/weaponhud.rcss"
local FONT = { "ui/fonts/share-tech-mono-400.ttf", "Share Tech Mono" }
local ENTER_MS, EXIT_MS, SELFTEST_MS, ROLL_MS = 600, 340, 480, 420
local CELLS_WIDTH, CELL_GAP = 410, 3
-- the colours ui/weaponhud.rcss is written with
local THEME = { accent = "#ffcc00", core = "#fff7da", warn = "#ff3b3b", cool = "#7fd8ff" }

local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
local function now() return GetGameTimer() end

-- ── seven-segment digits (op77_speedometer's): 64 x 112, slanted, one path per state ──
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

--- Three characters and which are leading zeros: "test" -> 888, nil -> ---, else 000..999.
function U.number(n)
    if n == "test" then return "888", { false, false, false } end
    if n == nil then return "---", { false, false, false } end
    local s = ("%03d"):format(clamp(math.floor((tonumber(n) or 0) + 0.5), 0, 999))
    local first = s:find("[1-9]")
    return s, { first == nil or 1 < first, first == nil or 2 < first, false }
end

--- How a magazine is drawn: cells, rounds per cell.
function U.cellLayout(capacity, maxCells)
    capacity = tonumber(capacity) or 0
    if capacity <= 0 then return 0, 1 end
    local n = math.min(maxCells, capacity)
    local perCell = math.ceil(capacity / n)
    return math.ceil(capacity / perCell), perCell
end

-- ── theme ──
local function rgb(hex) return type(hex) == "string" and hex:match("^#(%x%x%x%x%x%x)$") and hex:lower() or nil end

--- The theme layer: the sheet's rules that hold a theme colour, with the config's colours.
--- nil when the theme is the sheet's own.
function U.themeRcss(source, theme)
    local swap, differs = {}, false
    for key, default in pairs(THEME) do
        local value = rgb(theme and theme[key]) or default
        swap[default:sub(2)] = value
        if value ~= default then differs = true end
    end
    if not differs or type(source) ~= "string" then return nil end
    local out = {}
    for line in source:gmatch("[^\r\n]+") do
        if line:match("^%s*[%.#%a][^{}]*{.*}%s*$") then
            local replaced, count = line:gsub("#(%x%x%x%x%x%x)", function(hex) return swap[hex] end)
            if count > 0 and replaced ~= line then out[#out + 1] = replaced end
        end
    end
    return table.concat(out, "\n")
end

--- The filters whose lengths follow the scale (a filter is measured on the screen, not on
--- the scaled plane): the bloom, the scanlines and the theme's opacity on #holo, the glow of
--- the melee edge.
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
    return #parts > 0 and table.concat(parts, " ") or "none",
        ("drop-shadow(%scc 0dp 0dp %.2fdp)"):format(accent, math.max(0.5, 6 * scale))
end

local function defaults()
    local on, off = U.glyph("-")
    return {
        live = false, covered = false, enter = 0, leaving = false, test = false,
        melee = false, reloading = false, empty = false, low = false, zeros = "dim", glitch = false,
        name = "WEAPON", klass = "", hasKlass = false, klassSmart = false, klassTech = false, kind = "", hasKind = false,
        cells = {}, e1 = 0, e1x = "0dp", e2 = 0, e2x = "0dp", e3 = 0, e3x = "0dp", ew = "0dp",
        d1on = on, d1off = off, d2on = on, d2off = off, d3on = on, d3off = off, lead1 = false, lead2 = false,
        hit = 0, kick = 0, reserve = "---", reserveOut = false, tag = "", tagKind = 0,
        fill = "scaleX(0)", leftHand = "", hasLeft = false, meleeClass = "BLADE",
    }
end
U.defaults = defaults

local fontLoaded = false

--- A surface with the page API client/main.lua uses: on, send, destroy.
function U.create(options)
    if type(Open77.ui) ~= "table" or type(Open77.ui.create) ~= "function" then return nil, "nativeui_unavailable" end
    options = options or {}
    -- the HUD lab (tools/native-lab) draws it above the pre-game shell, whose cursor is held
    local lab = type(Op77UiLab) == "table" and Op77UiLab or nil
    local ignoreCapture = lab ~= nil and lab.ignoreCapture == true
    if not fontLoaded and type(Open77.ui.loadFont) == "function" then
        local ok, loaded, why = pcall(Open77.ui.loadFont, FONT[1], FONT[2])
        fontLoaded = ok and loaded ~= false
        if not fontLoaded then print("[weaponhud] font " .. FONT[1] .. " not loaded: " .. tostring(ok and why or loaded)) end
    end
    local ui, why = Open77.ui.create({
        document = DOCUMENT, layer = lab and lab.layer or "hud", zIndex = math.floor(tonumber(options.zIndex) or 705), visible = true,
        models = { wh = defaults() },
    })
    if not ui then return nil, why end

    local page = { handlers = {} }
    local alive = true
    local held = defaults()      -- what the document's model holds
    local cfg = WeaponHud.pageConfig(WeaponHudConfig or {})
    local inset, lifted = 0, 0
    local themed = false
    local sheet = nil            -- ui/weaponhud.rcss, read once
    local current, data = nil, nil            -- the weapon:show payload, the last weapon:data
    local live, testing, enteredAt = false, false, 0
    local hideToken, testToken = 0, 0
    local shownMag, roll, rolling = nil, nil, false
    local cellCount, perCell, litCells = 0, 1, -1
    local nextGlitch = now() + 5000

    local function patch(fields)
        local changed
        for k, v in pairs(fields) do
            if type(v) == "table" or held[k] ~= v then
                held[k] = v
                changed = changed or {}
                changed[k] = v
            end
        end
        if changed then ui:merge("wh", changed) end
    end
    local function after(ms, fn)
        CreateThread(function()
            Wait(ms)
            if alive then fn() end
        end)
    end
    local function again(key) return held[key] == 1 and 2 or 1 end -- restarts an A/B animation

    -- ── digits and cells ──
    local function setNumber(n)
        local s, lead = U.number(n)
        local f = { lead1 = lead[1], lead2 = lead[2] }
        for i = 1, 3 do f["d" .. i .. "on"], f["d" .. i .. "off"] = U.glyph(s:sub(i, i)) end
        patch(f)
    end
    local function buildCells(capacity)
        cellCount, perCell = U.cellLayout(capacity, cfg.maxCells)
        litCells = -1
        local list = {}
        for i = 1, cellCount do list[i] = { on = false, tip = false } end
        patch({ cells = list })
    end
    local function setCells(magazine, eject)
        local lit = magazine == nil and 0 or math.ceil(magazine / perCell)
        if lit == litCells and not eject then return end
        local f = {}
        if eject and litCells > lit and cellCount > 0 then
            -- the cells just emptied fly off (three at most per sample)
            local width = (CELLS_WIDTH - CELL_GAP * (cellCount - 1)) / cellCount
            local slot = 0
            for i = math.max(lit, litCells - 3), math.min(litCells, cellCount) - 1 do
                slot = slot + 1
                f["e" .. slot] = again("e" .. slot)
                f["e" .. slot .. "x"] = ("%.2fdp"):format(i * (width + CELL_GAP))
            end
            f.ew = ("%.2fdp"):format(width)
        end
        if lit ~= litCells then
            litCells = lit
            local list = {}
            for i = 1, cellCount do list[i] = { on = i <= lit, tip = i == lit } end
            f.cells = list
        end
        patch(f)
    end

    -- ── config & placement ──
    local function layout()
        local l = cfg.layout
        ui:style("#stage", {
            left = ("%.2fdp"):format(math.max(0, l.left + l.offsetX)),
            bottom = ("%.2fdp"):format(math.max(0, l.bottom - l.offsetY)),
            transform = ("scale(%.4f)"):format(l.scale),
        })
        local lift = clamp(inset, 0, l.maxInset)
        if lift ~= lifted then
            lifted = lift
            ui:animate("#lift", { to = { y = -lift }, duration = 0.3, easing = "cubic-bezier(0.2,0.9,0.25,1)" })
        end
    end
    local function applyConfig(nextConfig)
        if type(nextConfig) == "table" then cfg = WeaponHud.merge(cfg, nextConfig) end
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
        local holo, edge = U.filters(theme, l.scale)
        ui:style("#holo", "filter", holo)
        ui:style("#edge-front", "filter", edge)
        ui:style("#haze", "opacity", theme.opacity < 0.995 and ("%.2f"):format(theme.opacity) or nil)
        ui:style("#plane", "transform", l.tilt and ("rotateX(%.2fdeg) rotateY(%.2fdeg)"):format(l.tiltX, l.tiltY) or "none")
        patch({ zeros = cfg.leadingZeros })
        layout()
    end

    -- ── state ──
    local render

    local function show(p)
        if type(p) ~= "table" then return end
        hideToken = hideToken + 1
        local switched = not current or current.key ~= p.key
        current = p
        local klass = tostring(p.class or "")
        local kind = tostring(p.type or "")
        local name = tostring(p.name or "")
        local f = {
            name = name ~= "" and name or "WEAPON", klass = klass, hasKlass = klass ~= "",
            klassSmart = klass == "SMART", klassTech = klass == "TECH", kind = kind, hasKind = kind ~= "",
            live = true, leaving = false,
        }
        if switched or cellCount == 0 then buildCells(not p.melee and p.capacity or 0) end
        if p.instant then
            f.enter = 3
        else
            -- unfold, with a self-test: every segment and cell lit for a moment
            f.enter = (held.enter == 1) and 2 or 1
            f.test = true
            testing = true
            setNumber("test")
            shownMag = nil
            testToken = testToken + 1
            local token = testToken
            after(SELFTEST_MS, function()
                if token ~= testToken then return end
                testing = false
                patch({ test = false })
                render(false)
            end)
        end
        enteredAt = now()
        live = true
        patch(f)
        if p.instant then render(false) end
    end

    local function hide()
        if not live then return end
        live = false
        testing = false
        testToken = testToken + 1
        patch({ test = false, enter = 0, leaving = true })
        hideToken = hideToken + 1
        local token = hideToken
        after(EXIT_MS + 40, function()
            if token ~= hideToken then return end
            patch({ live = false, leaving = false })
            current = nil
        end)
    end

    local function startRoll()
        if rolling then return end
        rolling = true
        CreateThread(function()
            -- reload done: the count rolls up while the cells refill in a sweep
            while alive and roll do
                local k = math.min(1, (now() - roll.at) / ROLL_MS)
                local e = 1 - (1 - k) ^ 3
                shownMag = math.floor(roll.from + (roll.to - roll.from) * e + 0.5)
                setNumber(shownMag)
                if k >= 1 then roll = nil else Wait(0) end
            end
            rolling = false
        end)
    end

    render = function(animate)
        if not current or testing then return end
        local d = data or {}
        local melee = current.melee == true or d.capacity == nil
        if not current.melee and d.capacity and cellCount == 0 then buildCells(d.capacity) end
        local reloading = d.reloading == true
        local empty = d.empty == true
        local f = {
            melee = current.melee == true,
            meleeClass = current.class == "BLUNT" and "BLUNT" or "BLADE",
            reloading = reloading and not melee,
            empty = empty and not reloading and not melee,
            low = d.low == true and not empty and not reloading,
            reserve = (melee or d.reserve == nil) and "---" or ("%03d"):format(math.floor(d.reserve)),
            reserveOut = d.reserve == 0,
        }
        f.tag, f.tagKind = "", 0
        if not (melee and current.melee) then
            if reloading then f.tag, f.tagKind = "RELOADING", 2
            elseif empty then f.tag, f.tagKind = d.reserve == 0 and "NO AMMO" or "RELOAD", 1
            elseif d.low == true then f.tag = "LOW AMMO" end
        end
        local capacity = tonumber(d.capacity) or 0
        f.fill = ("scaleX(%.4f)"):format(capacity > 0 and clamp((tonumber(d.magazine) or 0) / capacity, 0, 1) or 0)
        local left = type(d.left) == "table" and d.left or nil
        if left and left.magazine ~= nil then
            f.leftHand = ("LEFT %02d"):format(math.floor(left.magazine)) .. (left.capacity and (" / " .. math.floor(left.capacity)) or "")
            f.hasLeft = true
        else
            f.leftHand, f.hasLeft = "", false
        end
        patch(f)

        if melee then
            setNumber(nil); setCells(nil, false); shownMag = nil
            return
        end
        local mag = d.magazine
        if animate and (tonumber(d.shots) or 0) > 0 then
            -- a shot: the digits flicker, the plate kicks, the emptied cells fly off
            patch({ hit = again("hit"), kick = again("kick") })
            setCells(mag, true)
            shownMag, roll = mag, nil
            setNumber(mag)
        elseif animate and shownMag ~= nil and mag ~= nil and mag > shownMag then
            roll = { from = shownMag, to = mag, at = now() }
            setCells(mag, false)
            startRoll()
        else
            if not roll then shownMag = mag; setNumber(mag) end
            setCells(mag, false)
        end
    end

    local function onData(p)
        if type(p) ~= "table" then return end
        data = p
        if live then render(true) end
        -- the odd flicker
        local t = now()
        if cfg.theme.flicker and live and t > nextGlitch and t - enteredAt > ENTER_MS then
            patch({ glitch = true })
            after(70 + math.floor(math.random() * 60), function() patch({ glitch = false }) end)
            nextGlitch = t + 4000 + math.floor(math.random() * 6000)
        end
    end

    -- ── the page API ──
    function page.on(_, name, fn) page.handlers[name] = fn end
    function page.send(_, name, payload)
        if not alive then return end
        if name == "weapon:data" then onData(payload)
        elseif name == "weapon:show" then show(payload)
        elseif name == "weapon:hide" then hide()
        elseif name == "weapon:config" then applyConfig(payload)
        elseif name == "weapon:inset" then
            inset = tonumber(type(payload) == "table" and payload.px) or 0
            layout()
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
        ui:merge("wh", defaults())
        current, live, testing, roll, shownMag = nil, false, false, nil, nil
        cellCount, perCell, litCells, lifted, themed = 0, 1, -1, 0, false
        hideToken, testToken = hideToken + 1, testToken + 1
        applyConfig(nil)
        local fn = page.handlers["weapon:ready"]
        if fn then fn() end
    end
    ui:onEvent("loaded", ready)
    ui:onEvent("reloaded", ready)
    ui:onEvent("error", function(name, detail)
        print("[weaponhud] HUD " .. tostring(name) .. ": " .. tostring(type(detail) == "table" and detail.message or detail))
    end)

    -- NativeUI draws above every WebUI page: step aside at once while another interface
    -- holds the cursor (pause menu, inventory, phone), whatever main.lua's sampling rate
    CreateThread(function()
        while alive do
            Wait(150)
            local busy = false
            if not ignoreCapture and type(Open77.input) == "table" and type(Open77.input.isCaptured) == "function" then
                local ok, _, cursor = pcall(Open77.input.isCaptured)
                busy = ok and cursor == true
            end
            if alive and busy ~= held.covered then patch({ covered = busy }) end
        end
    end)

    return page
end
