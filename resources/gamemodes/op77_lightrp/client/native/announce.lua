-- Announcements on NativeUI (ui/native/announce.rml): three passive overlays of the page,
-- none of them bound to the shell (they stay over a dialog, as they did in the page):
--
--   * the voice announcement signal (features/announce/AnnounceHalo.tsx + signalShader.ts):
--     while a staff member is on air for us a pixelated signal hangs at the top centre and
--     follows their voice. The page's fragment shader is the custom effect below, the same
--     maths in HLSL; its four uniforms (level, energy, talk, presence) are the effect's four
--     parameters, sprung here every frame exactly as the page's render loop did.
--     Data: client/core/announce.lua, page event "lightrp:ui:announce".
--   * the staff broadcast banner (features/announce/StaffBroadcast.tsx), E.page.staffAnnounce.
--     Its sounds are played by client/core/staff_announce.lua on the net event: unchanged.
--   * the arrival tour's caption (features/arrival/ArrivalTour.tsx), E.page.arrivalTour.
--     While it shows, the HUD and the notices step aside (N.cover, LightRpNativeNotices).
--
-- Like the page's gameplay interface, the three are not drawn in the vehicle workshop.
local N = LightRpNative
local E = LightRpEvents
local M = {}
LightRpNativeAnnounce = M

local PAGE_ANNOUNCE = "lightrp:ui:announce" -- client/core/announce.lua
local EASE_OUT = "cubic-bezier(0,.6,.3,1)"   -- --ease-out
local EASE_MECH = "cubic-bezier(.85,0,.15,1)" -- --ease-mech
local EFFECT = "lightrp-signal"

local doc
local effectOk = false

local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
local function str(v) if v == nil or v == false then return "" end return tostring(v) end
local function codepoints(s)
    local out = {}
    for ch in tostring(s):gmatch("[\0-\127\194-\253][\128-\191]*") do out[#out + 1] = ch end
    return out
end

-- =====================================================================================
-- The signal's shader (ui/src/features/announce/signalShader.ts, GLSL ES -> HLSL).
-- e.px is the page's `frag` (pixels, origin top-left, y down), e.size its uRes, e.time its
-- uTime; params = (uLevel, uEnergy, uTalk, uPresence); uCell = max(3, round(height / 75)).
-- =====================================================================================
local SIGNAL_HLSL = [[
float LrpSignalHash(float2 p) { return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453); }
float LrpSignalMod(float x, float y) { return x - y * floor(x / y); }
float4 Effect(EffectInput e)
{
    const float3 CYAN = float3(0.35, 0.96, 1.0);
    const float3 YELLOW = float3(1.0, 0.8, 0.0);
    const float3 RED = float3(1.0, 0.18, 0.24);
    const float CY = 0.42;
    const float LPI = 3.14159265;
    float uLevel = saturate(e.params.x);
    float uEnergy = saturate(e.params.y);
    float uTalk = saturate(e.params.z);
    float uPresence = saturate(e.params.w);
    float2 uRes = max(e.size, float2(1.0, 1.0));
    float uTime = e.time;
    float uCell = max(3.0, floor(uRes.y / 75.0 + 0.5));

    float2 fragp = e.px;
    // the row glitch: a few cell rows slide sideways for a beat while talking
    float rowIndex = floor(fragp.y / uCell);
    float beat = floor(uTime * 7.0);
    float glitch = step(0.985 - 0.02 * uTalk, LrpSignalHash(float2(rowIndex, beat))) * uTalk;
    fragp.x += glitch * uCell * (LrpSignalHash(float2(beat, rowIndex + 3.0)) > 0.5 ? 3.0 : -3.0);
    // snap to the pixel grid
    float2 q = (floor(fragp / uCell) + 0.5) * uCell;
    float2 uv = float2((q.x - uRes.x * 0.5) / uRes.y, q.y / uRes.y);
    float cell = uCell / uRes.y;
    float halfW = 0.5 * uRes.x / uRes.y;
    float span = halfW * 0.86;
    float ax = abs(uv.x);
    float bell = saturate(1.0 - (ax / span) * (ax / span));
    bell *= bell;

    float3 col = float3(0.0, 0.0, 0.0);
    float alpha = 0.0;

    // radar rings: dotted, pulsing out of the centre, flattened
    float2 rc = (uv - float2(0.0, CY)) * float2(0.55, 1.0);
    float d = length(rc);
    float ang = atan2(rc.y, rc.x + 0.000001);
    float dots = step(0.45, frac(ang * 18.0 / LPI + uTime * 0.15));
    for (int k = 0; k < 3; k++)
    {
        float ph = frac(uTime * (0.22 + 0.18 * uTalk) + float(k) / 3.0);
        float r = 0.06 + ph * 0.46;
        float ring = 1.0 - step(cell * 0.9, abs(d - r));
        float ra = ring * dots * (1.0 - ph) * (1.0 - ph) * (0.28 + 0.5 * uTalk);
        col += CYAN * ra; alpha += ra;
    }
    // the sweep: a faint wedge turning around the centre
    float sweep = frac((ang / (2.0 * LPI)) - uTime * 0.12);
    float wedge = smoothstep(0.88, 1.0, sweep) * step(d, 0.5) * step(0.05, d) * 0.16;
    col += CYAN * wedge * 0.6; alpha += wedge * 0.6;

    // LED equalizer, mirrored around the centre line
    float barW = 4.0 * cell;
    float bi = floor(uv.x / barW);
    float inBar = step(cell, LrpSignalMod(uv.x, barW));
    float n1 = LrpSignalHash(float2(bi, floor(uTime * 9.0)));
    float n2 = LrpSignalHash(float2(bi + 17.0, floor(uTime * 9.0) - 1.0));
    float wobble = lerp(n2, n1, frac(uTime * 9.0));
    float barH = (0.025 + 0.045 * uEnergy + (0.05 + 0.2 * wobble) * uLevel) * bell;
    float dy = abs(uv.y - CY);
    float seg = step(cell, LrpSignalMod(dy, cell * 3.0));
    float litCell = inBar * seg * step(dy, barH) * step(ax, span);
    float peak = smoothstep(barH * 0.55, barH, dy);
    float3 barCol = lerp(YELLOW, RED, peak);
    float ba = litCell * (0.42 + 0.3 * uTalk);
    col += barCol * ba; alpha += ba;

    // the oscilloscope trace (on top)
    float amp = (0.012 + 0.11 * uLevel + 0.02 * uEnergy) * bell;
    float w = sin(uv.x * 26.0 - uTime * 5.0) * 0.55 + sin(uv.x * 57.0 + uTime * 8.3) * 0.28
            + sin(uv.x * 11.0 - uTime * 2.1) * 0.17;
    float trace = CY + amp * w;
    float traceOn = (1.0 - step(cell * 1.1, abs(uv.y - trace))) * step(ax, span);
    float traceGlow = (1.0 - smoothstep(cell, cell * 4.0, abs(uv.y - trace))) * step(ax, span) * 0.25;
    col += CYAN * traceOn + CYAN * traceGlow * 0.5; alpha += traceOn * 0.95 + traceGlow * 0.3;
    // the end ticks of the trace
    float endTick = step(abs(ax - span), cell * 0.6) * step(dy, cell * 4.5);
    col += YELLOW * endTick; alpha += endTick;

    // scanlines, a faint dark band for contrast, the open / close
    float scan = 0.78 + 0.22 * step(0.5, frac(fragp.y / (uCell * 2.0)));
    float band = (1.0 - smoothstep(0.0, 0.3, dy)) * bell * 0.22;
    alpha = saturate(alpha);
    col = min(col, float3(1.0, 1.0, 1.0)) * scan;
    float a = max(alpha * scan, band) * uPresence;
    // premultiplied: the dark band adds coverage, no colour
    return float4(col * uPresence, a);
}
]]
M.SIGNAL_HLSL = SIGNAL_HLSL

-- =====================================================================================
-- the voice announcement signal
-- =====================================================================================
local casts = {}   -- speaker -> { speaker, name, mode, radius, self, audience }
local live = {}    -- speaker -> { level, talking, at }
local halo = { level = 0, energy = 0, talk = 0, presence = 0, shown = nil, running = false, on = false, sig = nil, label = nil, labelKey = nil }

--- Who is shown: whoever talks, else the latest cast (the page's Object.values order: by speaker id).
function M.pick(castList, levels)
    local ids = {}
    for id in pairs(castList) do ids[#ids + 1] = id end
    if #ids == 0 then return nil end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local l = levels[id]
        if l and l.talking then return castList[id] end
    end
    return castList[ids[#ids]]
end

--- The label's three texts for a cast (pure).
function M.label(c)
    local reach = c.mode == "server" and "SERVER-WIDE" or ("WITHIN %s M"):format(tostring(c.radius or 0))
    return {
        tag = c.self and "ON AIR" or "ANNOUNCEMENT",
        name = c.self and "YOU" or str(c.name):upper(),
        reach = reach .. (c.self and (" · %s LISTENING"):format(tostring(c.audience)) or " · STAFF"),
    }
end

local function approach(value, target, rate, dt) return value + (target - value) * (1 - math.exp(-dt * rate)) end

local function writeLabel(c)
    local l = M.label(c)
    local key = l.tag .. "|" .. l.name .. "|" .. l.reach
    if key == halo.labelKey then return end
    halo.labelKey = key
    doc:batch(function()
        doc:text("#halo-tag", l.tag)
        doc:text("#halo-name", l.name)
        doc:text("#halo-reach", l.reach)
    end)
end

local function paintHalo()
    if not halo.on then
        halo.on = true
        doc:class("#halo", "is-on", true)
    end
    if effectOk then
        local sig = ("fx(%s %.2f %.2f %.2f %.3f #5AF5FF)"):format(EFFECT, halo.level, halo.energy, halo.talk, halo.presence)
        if sig ~= halo.sig then halo.sig = sig; doc:style("#halo-signal", "decorator", sig) end
    else
        local sig = ("%.2f %.2f"):format(halo.presence, halo.level)
        if sig ~= halo.sig then
            halo.sig = sig
            doc:style("#halo-fallback", { opacity = ("%.2f"):format(halo.presence), transform = ("scaleY(%.2f)"):format(1 + 6 * halo.level) })
        end
    end
    -- the label sits under the signal and slides in with it
    local y = math.floor((0.62 + 0.12 * halo.presence) * 300 + 0.5)
    local label = ("%d %.2f"):format(y, math.max(0, halo.presence * 1.15 - 0.15))
    if label ~= halo.label then
        halo.label = label
        doc:style("#halo-label", { transform = ("translate(-50%%, %ddp)"):format(y), opacity = ("%.2f"):format(math.max(0, halo.presence * 1.15 - 0.15)) })
    end
end

-- the render loop: springs toward the live voice; it ends once off air and fully retracted
local function runHalo()
    if halo.running or not doc then return end
    halo.running = true
    CreateThread(function()
        local last = N.now()
        while doc do
            local now = N.now()
            local dt = math.min(0.05, math.max(0, (now - last) / 1000))
            last = now
            local pick = M.pick(casts, live)
            if pick then
                halo.shown = pick.speaker
                writeLabel(pick)
            end
            local l = pick and live[pick.speaker]
            -- a level older than 400 ms is silence (a dropped update)
            local fresh = l ~= nil and now - l.at < 400
            local targetLevel = fresh and l.talking and l.level or 0
            local targetTalk = fresh and l.talking and 1 or 0
            -- fast attack, softer release: it breathes, never twitches
            halo.level = approach(halo.level, targetLevel, targetLevel > halo.level and 8 or 3.5, dt)
            halo.energy = approach(halo.energy, halo.level, halo.level > halo.energy and 2.5 or 1.0, dt)
            halo.talk = approach(halo.talk, targetTalk, targetTalk > halo.talk and 5 or 2, dt)
            halo.presence = approach(halo.presence, pick and 1 or 0, pick and 3.2 or 4.5, dt)
            if not pick and halo.presence < 0.002 then
                halo.presence, halo.shown, halo.on, halo.sig, halo.label = 0, nil, false, nil, nil
                doc:class("#halo", "is-on", false)
                break
            end
            paintHalo()
            Wait(0)
        end
        halo.running = false
    end)
end

N.on(PAGE_ANNOUNCE, function(e)
    if type(e) ~= "table" then return end
    local speaker = tonumber(e.speaker)
    if not speaker then return end
    if e.kind == "cast" then
        casts[speaker] = { speaker = speaker, name = str(e.name), mode = e.mode == "radius" and "radius" or "server",
            radius = tonumber(e.radius), self = e.self == true, audience = tonumber(e.audience) or 0 }
        runHalo()
    elseif e.kind == "end" then
        casts[speaker], live[speaker] = nil, nil
    elseif e.kind == "level" then
        live[speaker] = { level = clamp(tonumber(e.level) or 0, 0, 1), talking = e.talking == true, at = N.now() }
    end
end)

-- =====================================================================================
-- the staff broadcast
-- =====================================================================================
local SB_OUT_MS = 520
-- sb-in .62s steps(1, end): each keyframe held until the next (12 %, 24 %, 36 %, 48 %)
local SB_IN = {
    [0] = { at = 0, style = { opacity = "0", transform = "translate(0dp, -8dp) scaleY(0.06)", filter = "brightness(2.2)" } },
    [1] = { at = 74, style = { opacity = "1", transform = "translate(14dp, 0dp) scaleY(0.3)", filter = "brightness(1.9) hue-rotate(20deg)" } },
    [2] = { at = 149, style = { opacity = "1", transform = "translate(-10dp, 0dp) scaleY(1.04)", filter = "brightness(1.6) hue-rotate(40deg)" } },
    [3] = { at = 223, style = { opacity = "1", transform = "translate(4dp, 0dp) scaleY(1)", filter = "brightness(1.3) hue-rotate(20deg)" } },
    [4] = { at = 298, style = { opacity = "1", transform = "translate(0dp, 0dp) scaleY(1)" } },
}
-- sb-out .52s steps(1, end): 25 %, 50 %, 75 %
local SB_OUT = {
    { at = 130, style = { opacity = "1", transform = "translate(12dp, 0dp) scaleY(1)", filter = "brightness(1.8) hue-rotate(-40deg)" } },
    { at = 260, style = { opacity = "0.8", transform = "translate(-8dp, 0dp) scaleY(0.4)", filter = "brightness(1.5) hue-rotate(-27deg)" } },
    { at = 390, style = { opacity = "0.6", transform = "translate(0dp, 0dp) scaleY(0.06)", filter = "brightness(1.3) hue-rotate(-13deg)" } },
}
local sbQueue, sbRunning = {}, false

--- The banner's message from the page payload, or nil (pure).
function M.broadcast(m)
    if type(m) ~= "table" or type(m.text) ~= "string" or not m.text:find("%S") then return nil end
    local title = type(m.title) == "string" and m.title ~= "" and m.title or "Staff announcement"
    local from = type(m.from) == "string" and m.from ~= "" and m.from or nil
    return { text = m.text, tag = title:upper(), from = from and from:upper() or nil,
        stayMs = math.max(4000, tonumber(m.durationMs) or 10000) }
end

local function sbStage(stage)
    doc:style("#sb", stage.style)
    if not stage.style.filter then doc:style("#sb", "filter", nil) end
end

local function sbPlay(m)
    local chars = codepoints(m.text)
    local total = #chars
    local perTick = math.max(1, math.ceil(total / 45)) -- about 28 characters a second, at most 1.6 s
    doc:batch(function()
        doc:text("#sb-tag", m.tag)
        doc:text("#sb-from-lead", m.from and "// SIGNED " or "// LIGHT/RP STAFF")
        doc:text("#sb-from-name", m.from or "")
        doc:text("#sb-said", "")
        doc:text("#sb-unsaid", m.text)
        doc:class("#sb", "is-typed", false)
        sbStage(SB_IN[0])
        doc:class("#sb", "is-on", true)
        doc:class("#sb", "is-in", true)
        -- .sb::after: a scan line sweeping down once (1.1 s, after .2 s)
        doc:animate("#sb-scan", { from = { top = "0%", opacity = 0.9 }, to = { top = "100%", opacity = 0 }, duration = 1.1, delay = 0.2, easing = EASE_OUT })
        -- the bar drains the time it stays
        doc:animate("#sb-fill", { from = { scaleX = 1 }, to = { scaleX = 0 }, duration = m.stayMs / 1000, easing = "linear" })
    end)
    local t0 = N.now()
    local stage, typed = 0, 0
    while true do
        local t = N.now() - t0
        if t >= m.stayMs then break end
        local s = stage
        while s < 4 and t >= SB_IN[s + 1].at do s = s + 1 end
        if s ~= stage then stage = s; sbStage(SB_IN[s]) end
        local want = math.min(total, math.floor(t / 35) * perTick)
        if want ~= typed then
            typed = want
            doc:batch(function()
                doc:text("#sb-said", table.concat(chars, "", 1, typed))
                doc:text("#sb-unsaid", table.concat(chars, "", typed + 1, total))
                if typed >= total then doc:class("#sb", "is-typed", true) end
            end)
        end
        if stage == 4 and typed >= total then Wait(math.max(0, math.min(100, m.stayMs - t))) else Wait(0) end
    end
    -- it collapses out
    local out0 = N.now()
    local done = 0
    while true do
        local t = N.now() - out0
        if t >= SB_OUT_MS then break end
        local s = done
        while s < #SB_OUT and t >= SB_OUT[s + 1].at do s = s + 1 end
        if s ~= done then done = s; sbStage(SB_OUT[s]) end
        Wait(0)
    end
    doc:batch(function()
        doc:class("#sb", "is-in", false)
        doc:class("#sb", "is-on", false)
        doc:style("#sb", "filter", nil)
        doc:style("#sb", { opacity = "0", transform = "translate(0dp, 0dp) scaleY(1)" })
    end)
end

local function runBroadcasts()
    if sbRunning or not doc then return end
    sbRunning = true
    CreateThread(function()
        while sbQueue[1] and doc do
            local ok, why = pcall(sbPlay, sbQueue[1])
            if not ok then N.log("staff broadcast: " .. tostring(why)) end
            table.remove(sbQueue, 1)
            Wait(0) -- one frame hidden: the next one's entrance starts over
        end
        sbRunning = false
    end)
end

N.on(E.page.staffAnnounce, function(payload)
    local m = M.broadcast(payload)
    if not m then return end
    -- several in a row queue: the one on screen and the last four
    while #sbQueue >= 5 do table.remove(sbQueue, 2) end
    sbQueue[#sbQueue + 1] = m
    runBroadcasts()
end)

-- =====================================================================================
-- the arrival tour's caption
-- =====================================================================================
local AT_OUT_MS = 650
local AT_BAR = 97.2 -- 9vh
local at = { token = 0, shown = false, leaving = false }

--- The caption from the page payload (pure).
function M.tour(m)
    m = type(m) == "table" and m or {}
    local lines = {}
    if type(m.lines) == "table" then
        for _, line in ipairs(m.lines) do
            if type(line) == "string" and #lines < 4 then lines[#lines + 1] = line end
        end
    end
    local duration = tonumber(m.durationMs)
    if not duration or duration == 0 then duration = 11000 end
    return {
        title = type(m.title) == "string" and m.title ~= "" and m.title or "NIGHT CITY",
        subtitle = type(m.subtitle) == "string" and m.subtitle or "",
        lines = lines, durationMs = clamp(duration, 3000, 30000),
        skip = m.skip ~= nil and m.skip ~= false and tostring(m.skip) ~= "" and tostring(m.skip) or nil,
    }
end

local function atAside(on)
    N.cover("arrival-tour", on)
    if LightRpNativeNotices then LightRpNativeNotices.suppress("arrival-tour", on) end
end

local function atWipe(k) -- at-wipe: clip-path inset(0 100% 0 0) -> inset(0), steps(14, end)
    local hidden = (1 - k) * 100
    doc:batch(function()
        doc:style("#at-title-clip", "transform", ("translateX(-%.2f%%)"):format(hidden))
        doc:style("#at-title-inner", "transform", ("translateX(%.2f%%)"):format(hidden))
    end)
end

local function atLeave()
    if not at.shown or at.leaving then return end
    at.leaving = true
    local token = at.token
    doc:batch(function()
        doc:animate("#at-caption", { to = { opacity = 0, y = 8 }, duration = 0.45, easing = EASE_OUT })
        doc:animate("#at-foot", { to = { opacity = 0, y = 8 }, duration = 0.45, easing = EASE_OUT })
        doc:animate("#at-bar-top", { to = { y = -AT_BAR }, duration = 0.6, delay = 0.1, easing = EASE_OUT })
        doc:animate("#at-bar-bottom", { to = { y = AT_BAR }, duration = 0.6, delay = 0.1, easing = EASE_OUT })
    end)
    CreateThread(function()
        Wait(AT_OUT_MS)
        if at.token ~= token or not at.leaving then return end
        at.shown, at.leaving = false, false
        doc:class("#at", "is-on", false)
        atAside(false)
    end)
end

local function atShow(m)
    at.token = at.token + 1
    at.shown, at.leaving = true, false
    local token = at.token
    atAside(true)
    doc:batch(function()
        doc:text("#at-title", m.title)
        doc:text("#at-split-a", m.title)
        doc:text("#at-split-b", m.title)
        doc:text("#at-subtitle", m.subtitle)
        doc:class("#at-subtitle", "hide", m.subtitle == "")
        doc:class("#at-lines", "hide", #m.lines == 0)
        for i = 1, 4 do
            doc:class("#at-l" .. i, "hide", m.lines[i] == nil)
            doc:text("#at-l" .. i .. " .at-lt", m.lines[i] or "")
        end
        doc:class("#at-skip", "hide", m.skip == nil)
        doc:text("#at-key", m.skip or "")
        doc:style("#at-title-clip", "transform", "translateX(-100%)")
        doc:style("#at-title-inner", "transform", "translateX(100%)")
        doc:class("#at", "is-on", true)
        -- at-fade .8s on the whole, the bars sliding in .7s
        doc:animate("#at", { from = { opacity = 0, y = 6 }, to = { opacity = 1, y = 0 }, duration = 0.8, easing = EASE_OUT })
        doc:animate("#at-bar-top", { from = { y = -AT_BAR }, to = { y = 0 }, duration = 0.7, easing = EASE_OUT })
        doc:animate("#at-bar-bottom", { from = { y = AT_BAR }, to = { y = 0 }, duration = 0.7, easing = EASE_OUT })
        -- back from a previous exit
        doc:animate("#at-caption", { from = { opacity = 1, y = 0 }, to = { opacity = 1, y = 0 }, duration = 0.01 })
        doc:animate("#at-eyebrow", { from = { opacity = 0, y = 6 }, to = { opacity = 1, y = 0 }, duration = 0.5, delay = 0.45, easing = EASE_OUT })
        doc:animate("#at-eyebrow-line", { from = { scaleX = 0 }, to = { scaleX = 1 }, duration = 0.6, delay = 0.45, easing = EASE_MECH })
        -- at-split 1.1s after .6s: the ghosts slide 6 -> -4 -> 0 and fade
        doc:animate("#at-split", { from = { opacity = 1 }, to = { opacity = 0 }, duration = 1.1, delay = 0.6, easing = EASE_OUT })
        doc:keyframes("#at-split", { channel = "x", stops = { { offset = 0, value = 6 }, { offset = 0.3, value = -4 }, { offset = 1, value = 0 } },
            duration = 1.1, delay = 0.6 })
        doc:animate("#at-subtitle", { from = { opacity = 0, y = 6 }, to = { opacity = 1, y = 0 }, duration = 0.6, delay = 1.0, easing = EASE_OUT })
        for i = 1, #m.lines do -- at-line .55s, one after the other from 1.2 s
            doc:animate("#at-l" .. i, { from = { opacity = 0, x = -14 }, to = { opacity = 1, x = 0 }, duration = 0.55, delay = 1.2 + (i - 1) * 0.55, easing = EASE_MECH })
        end
        doc:animate("#at-foot", { from = { opacity = 0, y = 6 }, to = { opacity = 1, y = 0 }, duration = 0.5, delay = 0.7, easing = EASE_OUT })
        -- the bar runs the tour's time
        doc:animate("#at-time-fill", { from = { scaleX = 0 }, to = { scaleX = 1 }, duration = m.durationMs / 1000, easing = "linear" })
    end)
    CreateThread(function()
        local t0 = N.now()
        local step = 0
        while at.token == token and at.shown and not at.leaving do
            local t = N.now() - t0
            -- the title wiped in: .9 s after .6 s, in 14 steps
            local k = t < 600 and 0 or math.min(14, math.floor((t - 600) / (900 / 14)))
            if k ~= step then step = k; atWipe(k / 14) end
            -- a lost "false" still ends it a little after the tour's time
            if t >= m.durationMs + 2500 then atLeave(); break end
            Wait(step < 14 and 0 or 100)
        end
    end)
end

N.on(E.page.arrivalTour, function(m)
    if not doc then return end
    if not m then atLeave(); return end
    atShow(M.tour(m))
end)

-- =====================================================================================
-- the document
-- =====================================================================================
local function gameplayHidden() -- App.tsx: the gameplay interface is hidden in the vehicle workshop
    local c = LightRpVehicleCustomizationClient
    if type(c) ~= "table" or type(c.isActive) ~= "function" then return false end
    local ok, active = pcall(c.isActive)
    return ok and active == true
end

N.onStart(function()
    if type(Open77.ui.registerEffect) == "function" then
        local ok, done, why = pcall(Open77.ui.registerEffect, EFFECT, SIGNAL_HLSL)
        effectOk = ok and done == true
        if not effectOk then N.log("announcement signal effect refused: " .. tostring(ok and why or done)) end
    end
    doc = N.create({ document = "ui/native/announce.rml", zIndex = 70 })
    if not doc then return end
    local function prepare()
        doc:batch(function()
            doc:attr("#sb-icon", "d", N.icon("radio"))
            doc:class("#halo", "is-css", not effectOk)
        end)
        halo.on, halo.sig, halo.label, halo.labelKey = false, nil, nil, nil
    end
    doc:onEvent("reloaded", prepare)
    prepare()
    if next(casts) ~= nil then runHalo() end
    if sbQueue[1] then runBroadcasts() end
    CreateThread(function()
        local hidden = false
        while true do
            local now = gameplayHidden()
            if now ~= hidden then hidden = now; doc:class("#root", "hide", hidden) end
            Wait(250)
        end
    end)
end)
