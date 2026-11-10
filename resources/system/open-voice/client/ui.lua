-- The Light RP voice HUD on NativeUI (ui/voice.rml): the hologram plate, bottom right.
-- client/main.lua builds the payload and talks to this module as it talked to the WebUI
-- page: page:on("open-voice:ready", fn), page:send("open-voice:update", payload),
-- page:show(), page:hide(). Presentation only: every decision (state, reach, errors,
-- visibility, blockers) stays in main.lua and on the server. Only what changed reaches
-- the document. The look is the former WebUI page's, value for value (ui/voice.rcss).
OpenVoiceHud = {}
local V = OpenVoiceHud

local STATES = { idle = true, detected = true, talking = true, muted = true, offline = true }
local STATE_LABELS = { idle = "OPEN", detected = "SIGNAL", talking = "TRANSMIT", muted = "MUTED", offline = "VOICE OFF" }
-- Reach presets on the design system's voice palette; unknown presets keep the server's colour.
local REACH_COLORS = { whisper = "#7FB4D6", normal = "#FFCC00", shout = "#FF3FB4" }
local LIVE = "#FFCC00"
local CORE = "#FFF7DA"
local PEAK = "#FF2E3C"
local CELLS = 14
V.CELLS = CELLS

local function clamp(v, a, b) return v < a and a or (v > b and b or v) end
local function bounded(v, max) return tostring(v == nil and "" or v):sub(1, max) end
local function esc(s) return (tostring(s or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("{", "{ "):gsub("}", " }")) end
local function round(v) return math.floor(v + 0.5) end

function V.safeColor(value)
    local text = tostring(value or "")
    return text:match("^#%x%x%x%x%x%x$") and text or nil
end

function V.reachColor(name, fallback)
    return REACH_COLORS[name] or V.safeColor(fallback) or LIVE
end

function V.formatDistance(value)
    local metres = math.max(0, tonumber(value) or 0)
    if metres ~= metres then metres = 0 end
    if metres > 0 and metres < 10 and metres ~= math.floor(metres) then
        return ("%.1f"):format(metres)
    end
    return tostring(round(metres))
end

function V.resolveState(p, level)
    local supplied = bounded(p.state, 16):lower()
    if STATES[supplied] then return supplied end
    if p.configured ~= true or p.available == false then return "offline" end
    if p.captureEnabled ~= true then return "muted" end
    if p.transmitting == true then return "talking" end
    if p.microphoneDetected == true or level > 0.025 then return "detected" end
    return "idle"
end

-- ---- the reach in seven-segment digits --------------------------------------------------
-- The page's SVG (op77_speedometer's digits, smaller): segments a-g, a decimal point for
-- "2.5". Digit 24 x 44, advance 30, slanted by matrix(1 0 -0.09 1 3.96 0). Here every lit
-- segment of the number is one path and every unlit one another.
local SEG = { ["0"] = "abcdef", ["1"] = "bc", ["2"] = "abged", ["3"] = "abgcd", ["4"] = "fgbc", ["5"] = "afgcd",
    ["6"] = "afgedc", ["7"] = "abc", ["8"] = "abcdefg", ["9"] = "abcdfg", ["-"] = "g" }
local DW, DH, T, GAP, ADV = 24, 44, 5, 1.2, 30
local function hSeg(cy, x0, x1)
    return { { x0, cy }, { x0 + T / 2, cy - T / 2 }, { x1 - T / 2, cy - T / 2 }, { x1, cy }, { x1 - T / 2, cy + T / 2 }, { x0 + T / 2, cy + T / 2 } }
end
local function vSeg(cx, y0, y1)
    return { { cx, y0 }, { cx + T / 2, y0 + T / 2 }, { cx + T / 2, y1 - T / 2 }, { cx, y1 }, { cx - T / 2, y1 - T / 2 }, { cx - T / 2, y0 + T / 2 } }
end
local SEGMENTS = {
    a = hSeg(T / 2, T / 2 + GAP, DW - T / 2 - GAP), g = hSeg(DH / 2, T / 2 + GAP, DW - T / 2 - GAP), d = hSeg(DH - T / 2, T / 2 + GAP, DW - T / 2 - GAP),
    f = vSeg(T / 2, T / 2 + GAP, DH / 2 - GAP), b = vSeg(DW - T / 2, T / 2 + GAP, DH / 2 - GAP),
    e = vSeg(T / 2, DH / 2 + GAP, DH - T / 2 - GAP), c = vSeg(DW - T / 2, DH / 2 + GAP, DH - T / 2 - GAP),
}
local SEGMENT_ORDER = { "a", "b", "c", "d", "e", "f", "g" }
local function slant(x, y, dx) return x - 0.09 * y + DH * 0.09 + dx, y end

--- { width, on, off }: the dp width of the readout and the two path strings.
function V.digits(text)
    local cells = {}
    for ch in tostring(text):gmatch(".") do
        if ch == "." and #cells > 0 then cells[#cells].dot = true
        elseif SEG[ch] ~= nil then cells[#cells + 1] = { ch = ch, dot = false } end
    end
    while #cells < 2 do table.insert(cells, 1, { ch = " ", dot = false }) end
    local on, off = {}, {}
    for i, cell in ipairs(cells) do
        local dx = (i - 1) * ADV
        local lit = SEG[cell.ch] or ""
        for _, k in ipairs(SEGMENT_ORDER) do
            local parts = {}
            for n, q in ipairs(SEGMENTS[k]) do
                local x, y = slant(q[1], q[2], dx)
                parts[n] = ("%s%.2f %.2f"):format(n == 1 and "M" or "L", x, y)
            end
            local out = lit:find(k, 1, true) and on or off
            out[#out + 1] = table.concat(parts) .. "Z"
        end
        if cell.dot then
            local r = T / 2 + 0.4
            local x, y = slant(DW + 3, DH - T / 2, dx)
            on[#on + 1] = ("M%.2f %.2fa%.1f %.1f 0 1 0 %.1f 0a%.1f %.1f 0 1 0 %.1f 0Z"):format(x - r, y, r, r, 2 * r, r, r, -2 * r)
        end
    end
    return { width = #cells * ADV - (ADV - DW) + 6, on = table.concat(on), off = table.concat(off) }
end

function V.digitsRml(d)
    local function path(class, data)
        if data == "" then return "" end
        return ('<path class="%s" view-box="0 0 %d %d" style="width: %ddp;" d="%s"/>'):format(class, d.width, DH, d.width, data)
    end
    return path("seg-off", d.off) .. path("seg-on", d.on)
end

-- ---- the reach presets ---------------------------------------------------------------------
--- The presets the plate lists: { name, label, metres, color }, and a key that changes
--- only when the list itself does.
function V.ranges(modes)
    local list, keys = {}, {}
    if type(modes) == "table" then
        for i = 1, math.min(8, #modes) do
            local m = modes[i]
            if type(m) == "table" then
                local name = bounded(m.name, 24):lower()
                local metres = tonumber(m.distance)
                list[#list + 1] = {
                    name = name,
                    label = bounded(m.label or m.name or "", 12):upper(),
                    metres = (metres and metres == metres and metres > 0 and metres < math.huge) and (V.formatDistance(metres) .. "M") or "",
                    color = V.reachColor(name, m.color),
                }
                keys[#keys + 1] = ("%s|%s|%s|%s"):format(tostring(m.name), tostring(m.label), tostring(m.color), tostring(m.distance))
            end
        end
    end
    return list, table.concat(keys, ";")
end

function V.rangesRml(list)
    local out = {}
    for i, m in ipairs(list) do
        local metres = m.metres ~= "" and ('<span class="rg-m">%s</span>'):format(esc(m.metres)) or ""
        out[i] = ('<div class="rg" id="rg-%d"><span>%s</span>%s<div class="rg-sel"></div></div>'):format(i, esc(m.label), metres)
    end
    return table.concat(out)
end

--- Each preset's colour (lit label, 14 % tint, selector), as a stylesheet layer.
function V.rangesSheet(list)
    local out = {}
    for i, m in ipairs(list) do
        out[#out + 1] = ("#rg-%d.on { color: %s; background-color: %s24; }"):format(i, m.color, m.color)
        out[#out + 1] = ("#rg-%d .rg-sel { background-color: %s; }"):format(i, m.color)
    end
    out[#out + 1] = "#voice.s-talking #ranges .rg.on { color: " .. CORE .. "; }"
    return table.concat(out, "\n")
end

--- Everything drawn in the active reach's colour (the page's --mode-color), as a layer.
function V.modeSheet(color)
    local c = V.safeColor(color) or LIVE
    return table.concat({
        "#dist7 path.seg-on { fill: " .. c .. "; }",
        "#dist-unit { color: " .. c .. "; }",
        "#mode-label { color: " .. c .. "; }",
        "#meter .cell.lit { background-color: " .. c .. "; }",
        "#voice.s-talking #dist7 path.seg-on { fill: " .. CORE .. "; }",
        "#voice.s-talking #meter .cell.lit { background-color: " .. CORE .. "; }",
        "#voice #meter .cell.lit.peak { background-color: " .. PEAK .. "; }",
        "#voice.s-talking #meter .cell.lit.tip { background-color: #FFFFFF; }",
    }, "\n")
end

--- The document's model from the payload client/main.lua publishes.
function V.model(p)
    p = type(p) == "table" and p or {}
    local level = clamp(tonumber(p.inputLevel) or 0, 0, 1)
    local state = V.resolveState(p, level)
    local modeName = bounded(p.modeName or p.mode or "normal", 24):lower()
    local err = bounded(p.error, 80)
    local off = state == "muted" or state == "offline"
    local count = 0
    if type(p.modes) == "table" then
        for i = 1, math.min(8, #p.modes) do if type(p.modes[i]) == "table" then count = count + 1 end end
    end
    return {
        shown = p.visible ~= false,
        state = state,
        stateLabel = STATE_LABELS[state],
        off = off,
        lit = off and 0 or round(level * CELLS),
        label = bounded(p.mode or p.modeName or "Voice", 24):upper(),
        modeName = modeName,
        distance = V.formatDistance(p.distance),
        color = V.reachColor(modeName, p.color),
        key = bounded(p.key or "F11", 12):upper(),
        heard = math.max(0, round(tonumber(p.activeTalkers) or 0)),
        error = err,
        hasError = #err > 0,
        -- with the tags on screen the separate readout would say the same thing twice
        multi = count >= 2,
    }
end

--- The page's narrow-screen rules (4:3, 5:4): 0 none, 1 = scale .78, 2 = scale .64.
function V.narrow(width, height)
    width, height = tonumber(width), tonumber(height)
    if not width or not height or height <= 0 then return 0 end
    local aspect = width / height
    if aspect <= 13 / 10 then return 2 end
    if aspect <= 13 / 9 then return 1 end
    return 0
end

local function defaults()
    return {
        shown = false, state = "offline", stateLabel = STATE_LABELS.offline, off = true, lit = 0,
        label = "NORMAL", modeName = "normal", distance = "20", color = LIVE, key = "F11",
        heard = 0, error = "", hasError = false, multi = false, changing = false, narrow = 0,
    }
end

--- A surface with the page API client/main.lua uses: on, send, show, hide, destroy.
function V.create(options)
    if type(Open77) ~= "table" or type(Open77.ui) ~= "table" or type(Open77.ui.create) ~= "function" then
        return nil, "nativeui_unavailable"
    end
    options = type(options) == "table" and options or {}
    if type(Open77.ui.loadFont) == "function" then
        local ok, done, why = pcall(Open77.ui.loadFont, "ui/fonts/share-tech-mono-400.ttf", "Share Tech Mono", false)
        if not ok or not done then print("[open-voice] font not loaded: " .. tostring(ok and why or done)) end
    end
    -- The HUD lab (tools/native-lab) sets Op77UiLab before this script loads: the document
    -- is then drawn on its layer (above the pre-game shell). Absent, nothing changes.
    local lab = type(Op77UiLab) == "table" and Op77UiLab or nil
    local ui, why = Open77.ui.create({
        document = "ui/voice.rml", layer = lab and lab.layer or "hud", zIndex = 12, visible = options.visible ~= false,
        models = { voice = defaults() },
    })
    if not ui then return nil, why end

    local page = { handlers = {} }
    local shown = nil            -- the model the document holds
    local rangesKey, ranges = nil, {}
    local activeRange = nil
    local digitsText, modeColor = nil, nil
    local previousMode = nil
    local changeToken = 0
    local narrowSent, narrowAt = nil, nil
    local alive = true

    local function reset()
        shown, rangesKey, ranges, activeRange, digitsText, modeColor = nil, nil, {}, nil, nil, nil
        narrowSent, narrowAt = nil, nil
    end
    -- Narrow screens: smaller, so the plate stays right of op77_map3d's GPS. The screen is
    -- read with an update, every 2 s at most: no thread, nothing while the HUD is idle.
    local function checkNarrow()
        local at = type(GetGameTimer) == "function" and GetGameTimer() or 0
        if narrowAt and at - narrowAt < 2000 then return end
        narrowAt = at
        local ok, state = pcall(ui.state, ui)
        if not ok or type(state) ~= "table" then return end
        local narrow = V.narrow(state.width, state.height)
        if narrow ~= narrowSent then
            narrowSent = narrow
            ui:set("voice", "narrow", narrow)
        end
    end
    local function ready()
        reset()
        local fn = page.handlers["open-voice:ready"]
        if fn then fn() end
    end
    ui:onEvent("loaded", ready)
    ui:onEvent("reloaded", ready)
    ui:onEvent("error", function(name, detail)
        print("[open-voice] HUD " .. tostring(name) .. ": " .. tostring(detail and detail.message))
    end)

    function page.on(_, name, fn) page.handlers[name] = fn end
    function page.show() ui:show() end
    function page.hide() ui:hide() end

    -- A new reach: the digits retune, the label drops in, the selector flashes white and
    -- grows under the new preset (the page's 340 ms "mode-changing").
    local function modeChanged(index)
        changeToken = changeToken + 1
        local token = changeToken
        ui:set("voice", "changing", false)
        CreateThread(function()
            Wait(0)
            if not alive or token ~= changeToken then return end
            ui:set("voice", "changing", true)
            Wait(340)
            if alive and token == changeToken then ui:set("voice", "changing", false) end
        end)
        if index and ranges[index] then
            ui:animate("#rg-" .. index .. " .rg-sel", {
                from = { scaleX = 0.15, ["background-color"] = "#FFFFFF" },
                to = { scaleX = 1, ["background-color"] = ranges[index].color },
                duration = 0.32, easing = "cubic-bezier(.2,.9,.25,1.15)",
            })
        end
    end

    function page.send(_, name, payload)
        if name ~= "open-voice:update" then return end
        payload = type(payload) == "table" and payload or {}
        local m = V.model(payload)

        -- the preset tags, rebuilt only when the list itself changes
        local list, key = V.ranges(payload.modes)
        if key ~= rangesKey then
            rangesKey, ranges, activeRange = key, list, nil
            ui:rml("#ranges", V.rangesRml(list))
            ui:stylesheet("ranges", V.rangesSheet(list))
        end
        local active = nil
        for i, range in ipairs(ranges) do if range.name == m.modeName then active = i break end end
        if active ~= activeRange then
            if activeRange then ui:class("#rg-" .. activeRange, "on", false) end
            if active then ui:class("#rg-" .. active, "on", true) end
            activeRange = active
        end
        if m.color ~= modeColor then
            modeColor = m.color
            ui:stylesheet("mode", V.modeSheet(m.color))
        end
        if m.distance ~= digitsText then
            digitsText = m.distance
            local d = V.digits(m.distance)
            ui:style("#dist7", { width = d.width .. "dp" })
            ui:rml("#dist7", V.digitsRml(d))
        end

        local changed = {}
        for k, v in pairs(m) do
            if not shown or shown[k] ~= v then changed[k] = v end
        end
        if next(changed) then ui:merge("voice", changed) end
        shown = m
        checkNarrow()

        if previousMode == nil then previousMode = m.modeName
        elseif previousMode ~= m.modeName then
            previousMode = m.modeName
            modeChanged(active)
        end
    end

    function page.destroy()
        alive = false
        pcall(ui.destroy, ui)
    end
    return page
end
