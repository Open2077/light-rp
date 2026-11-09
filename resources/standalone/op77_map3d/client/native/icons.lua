-- Blip and maneuver icons for the native map: 24 x 24 line drawings (the WebUI
-- page's icons.ts), and a resource's own inline SVG, turned into one NativeUI
-- <path> each (a <path> takes every SVG path command; circles, rects and simple
-- <g transform="translate() scale()"> groups are converted here).
Map3DIcons = {}
local I = Map3DIcons

local P = {
    pin = '<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0C18.5 15.4 12 21 12 21z"/><circle cx="12" cy="10" r="2.4"/>',
    user = '<circle cx="12" cy="8" r="3.6"/><path d="M4.5 20.5c1.4-4 4.2-5.6 7.5-5.6s6.1 1.6 7.5 5.6"/>',
    car = '<path d="M4 15.5v-3.2l1.8-4.6A2 2 0 0 1 7.7 6.4h8.6a2 2 0 0 1 1.9 1.3l1.8 4.6v3.2"/><path d="M3.5 15.5h17v3h-17z"/><circle cx="7.5" cy="18.5" r="1.4"/><circle cx="16.5" cy="18.5" r="1.4"/><path d="M5.6 12h12.8"/>',
    store = '<path d="M4 9.5 5.5 4.5h13L20 9.5"/><path d="M4 9.5c0 1.6 1.3 2.6 2.7 2.6s2.6-1 2.6-2.6c0 1.6 1.2 2.6 2.7 2.6s2.7-1 2.7-2.6c0 1.6 1.2 2.6 2.6 2.6S20 11.1 20 9.5"/><path d="M5.5 12v7.5h13V12"/><path d="M10 19.5v-4h4v4"/>',
    briefcase = '<rect x="3.5" y="7.5" width="17" height="12" rx="1"/><path d="M8.5 7.5V5h7v2.5"/><path d="M3.5 12.5h17"/>',
    target = '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="4"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4"/>',
    home = '<path d="M4 11 12 4l8 7"/><path d="M6 9.5V20h12V9.5"/><path d="M10 20v-5h4v5"/>',
    flag = '<path d="M5 21V4"/><path d="M5 4h11l-2 3.5L16 11H5"/>',
    star = '<path d="m12 3.5 2.5 5.4 5.8.6-4.3 3.9 1.2 5.8L12 16.3l-5.2 2.9L8 13.4 3.7 9.5l5.8-.6z"/>',
    skull = '<path d="M6 16v-4.5a6 6 0 0 1 12 0V16l-2 1v3H8v-3z"/><circle cx="9.5" cy="12" r="1.3"/><circle cx="14.5" cy="12" r="1.3"/><path d="M11 20v-2M13 20v-2"/>',
    shield = '<path d="M12 3 5 6v5.5c0 4.3 2.9 7.6 7 9.5 4.1-1.9 7-5.2 7-9.5V6z"/>',
    police = '<path d="M12 3 5 6v5.5c0 4.3 2.9 7.6 7 9.5 4.1-1.9 7-5.2 7-9.5V6z"/><path d="m12 8.2 1.2 2.5 2.7.3-2 1.9.6 2.7-2.5-1.4-2.5 1.4.6-2.7-2-1.9 2.7-.3z"/>',
    hospital = '<rect x="4" y="4" width="16" height="16" rx="1.5"/><path d="M12 8v8M8 12h8"/>',
    fuel = '<path d="M5 20V5.5A1.5 1.5 0 0 1 6.5 4h6A1.5 1.5 0 0 1 14 5.5V20"/><path d="M4 20h11"/><path d="M5 10h9"/><path d="M14 8.5h2l2.5 2.5v6a1.5 1.5 0 0 1-3 0V13H14"/>',
    wrench = '<path d="M14.5 5.5a4 4 0 0 0 4.9 4.9l-9 9a2.1 2.1 0 0 1-3-3l9-9a4 4 0 0 0-1.9-1.9"/>',
    shirt = '<path d="M8 4 4 6.5l1.8 4L8 9.5V20h8V9.5l2.2 1 1.8-4L16 4c-.5 1.5-2 2.5-4 2.5S8.5 5.5 8 4z"/>',
    gun = '<path d="M3 9h15l2 2-2 1H11l-1.5 2H8l-1 5H4l1.3-5.5L3 12z"/><path d="M13 12v2.5h-2.5"/>',
    phone = '<rect x="7" y="2.5" width="10" height="19" rx="1.8"/><path d="M11 18.5h2"/>',
    dollar = '<path d="M12 3v18"/><path d="M16.5 7.5c0-1.6-2-2.8-4.5-2.8S7.5 6 7.5 7.8 9.5 10.5 12 11s4.5 1.5 4.5 3.3-2 3.1-4.5 3.1-4.5-1.2-4.5-2.8"/>',
    bed = '<path d="M3 19V6"/><path d="M3 15h18v4"/><path d="M3 11h6a2 2 0 0 1 2 2v2"/><path d="M11 11h7a3 3 0 0 1 3 3v1"/><circle cx="6.5" cy="9" r="1.6"/>',
    food = '<path d="M6 3v8a2 2 0 0 0 2 2v8"/><path d="M10 3v8a2 2 0 0 1-2 2"/><path d="M8 3v6"/><path d="M17 21V3c-2 1-3 3.5-3 6v4h3"/>',
    info = '<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5.5"/><path d="M12 7.6v.1"/>',
    warning = '<path d="M12 3.5 21 19.5H3z"/><path d="M12 10v4.5"/><path d="M12 17.2v.1"/>',
    garage = '<path d="M3 20V9l9-5 9 5v11"/><path d="M6.5 20v-7.5h11V20"/><path d="M6.5 15h11M6.5 17.5h11"/>',
    crosshair = '<circle cx="12" cy="12" r="7"/><path d="M12 2.5v5M12 16.5v5M2.5 12h5M16.5 12h5"/>',
    waypoint = '<path d="M12 21.5 7 16.5a7 7 0 1 1 10 0z"/><path d="m12 7 1.3 2.7 2.9.4-2.1 2 .5 2.9-2.6-1.4-2.6 1.4.5-2.9-2.1-2 2.9-.4z"/>',
    bank = '<path d="M3 9.5 12 4l9 5.5"/><path d="M5 10v7M9.5 10v7M14.5 10v7M19 10v7"/><path d="M3 20h18"/>',
    mission = '<path d="M12 3 4.5 7.5v9L12 21l7.5-4.5v-9z"/><path d="M12 8v5"/><path d="M12 15.8v.1"/>',
    search = '<circle cx="11" cy="11" r="6.5"/><path d="m16 16 4.5 4.5"/>',
    district = '<path d="M3 20h18"/><path d="M5 20V9l5-3v14"/><path d="M10 20V4l9 4v12"/><path d="M13 10h3M13 13h3M13 16h3"/>',
    bus = '<rect x="4.5" y="3.5" width="15" height="15" rx="2"/><path d="M4.5 11h15"/><path d="M7.5 18.5V21M16.5 18.5V21"/><path d="M8 15h.1M16 15h.1"/>',
    -- the native UI's own (were CSS/inline SVG in the page)
    close = '<path d="M6 6l12 12M18 6 6 18"/>',
    nosignal = '<path d="M2 8.5a15 15 0 0 1 20 0"/><path d="M5.5 12a10 10 0 0 1 13 0"/><path d="M9 15.5a5 5 0 0 1 6 0"/><path d="M12 19h.1"/><path d="M3 3l18 18"/>',
}

local M = {
    start = '<circle cx="12" cy="12" r="3"/><path d="M12 4v4M12 16v4"/>',
    straight = '<path d="M12 20V5"/><path d="m7 10 5-5 5 5"/>',
    left = '<path d="M17 20v-7a4 4 0 0 0-4-4H6"/><path d="m10 5-4 4 4 4"/>',
    right = '<path d="M7 20v-7a4 4 0 0 1 4-4h7"/><path d="m14 5 4 4-4 4"/>',
    ["slight-left"] = '<path d="M15 20v-6l-6-6"/><path d="M8 13V8h5"/>',
    ["slight-right"] = '<path d="M9 20v-6l6-6"/><path d="M16 13V8h-5"/>',
    ["sharp-left"] = '<path d="M16 4v9l-8 6"/><path d="M8 13v6h6"/>',
    ["sharp-right"] = '<path d="M8 4v9l8 6"/><path d="M16 13v6h-6"/>',
    uturn = '<path d="M8 20V9a4 4 0 0 1 8 0v4"/><path d="m12 10 4 4 4-4"/>',
    arrive = '<path d="M6 21V4"/><path d="M6 4h10l-2 3.5L16 11H6"/>',
}

local function attr(tag, name)
    return tag:match("[%s]" .. name .. '%s*=%s*"([^"]*)"') or tag:match("[%s]" .. name .. "%s*=%s*'([^']*)'")
end
local function num(v, d) return tonumber(v) or d or 0 end
local function f(n) return (string.format("%.3f", n):gsub("0+$", ""):gsub("%.$", "")) end

-- circle / ellipse / rect as path data
local function circle(cx, cy, rx, ry)
    return ("M%s %sA%s %s 0 1 0 %s %sA%s %s 0 1 0 %s %sZ"):format(
        f(cx - rx), f(cy), f(rx), f(ry), f(cx + rx), f(cy), f(rx), f(ry), f(cx - rx), f(cy))
end
local function rect(x, y, w, h, rx)
    if rx <= 0 then return ("M%s %sH%sV%sH%sZ"):format(f(x), f(y), f(x + w), f(y + h), f(x)) end
    rx = math.min(rx, w / 2, h / 2)
    return ("M%s %sH%sA%s %s 0 0 1 %s %sV%sA%s %s 0 0 1 %s %sH%sA%s %s 0 0 1 %s %sV%sA%s %s 0 0 1 %s %sZ"):format(
        f(x + rx), f(y), f(x + w - rx), f(rx), f(rx), f(x + w), f(y + rx), f(y + h - rx), f(rx), f(rx), f(x + w - rx), f(y + h),
        f(x + rx), f(rx), f(rx), f(x), f(y + h - rx), f(y + rx), f(rx), f(rx), f(x + rx), f(y))
end

-- path data under x' = s x + tx, y' = s y + ty (uniform scale: relative and arc data scale, absolute moves)
local ARGS = { M = 2, L = 2, H = 1, V = 1, C = 6, S = 4, Q = 4, T = 2, A = 7, Z = 0 }
local function transformPath(d, s, tx, ty)
    if s == 1 and tx == 0 and ty == 0 then return d end
    local out, cmd = {}, nil
    local tokens = {}
    for c, rest in d:gmatch("([MmLlHhVvCcSsQqTtAaZz])([^MmLlHhVvCcSsQqTtAaZz]*)") do
        local nums = {}
        -- arc flags may run together ("0 1 0" as "010" is not used by these icons); no exponents
        for n in rest:gmatch("[-+]?%d*%.?%d+") do nums[#nums + 1] = tonumber(n) end
        tokens[#tokens + 1] = { c, nums }
    end
    for _, t in ipairs(tokens) do
        cmd = t[1]
        local up, rel = cmd:upper(), cmd ~= cmd:upper()
        local n, nums = ARGS[up], t[2]
        out[#out + 1] = cmd
        if n == 0 then goto continue end
        for i = 1, #nums, n do
            for k = 0, n - 1 do
                local v = nums[i + k]
                if v == nil then break end
                local isX, isY
                if up == "H" then isX = true
                elseif up == "V" then isY = true
                elseif up == "A" then
                    if k == 5 then isX = true elseif k == 6 then isY = true end
                    if k < 2 then v = v * s end
                else
                    isX, isY = k % 2 == 0, k % 2 == 1
                end
                if isX then v = v * s + (rel and 0 or tx)
                elseif isY then v = v * s + (rel and 0 or ty) end
                out[#out + 1] = (k > 0 and " " or "") .. f(v)
            end
            out[#out + 1] = " "
        end
        ::continue::
    end
    return table.concat(out)
end

local function parseTransform(t)
    local s, tx, ty = 1, 0, 0
    if not t then return s, tx, ty end
    -- x' = s x + t, composed left to right: M = M * op (translate(a): k = 1; scale(k): a = 0)
    for name, args in t:gmatch("(%a+)%s*%(([^)]*)%)") do
        local v = {}
        for n in args:gmatch("[-+]?%d*%.?%d+") do v[#v + 1] = tonumber(n) end
        if name == "translate" then
            tx, ty = tx + s * (v[1] or 0), ty + s * (v[2] or 0)
        elseif name == "scale" then
            s = s * (v[1] or 1)
        end
    end
    return s, tx, ty
end

--- The path data of an SVG body (or a whole <svg>), and whether it is filled.
function I.pathData(svg)
    local parts = {}
    local stack = { { 1, 0, 0 } }
    for close, tag in svg:gmatch("<(/?)(%a[^>]*)>") do
        local name = tag:match("^(%a+)")
        if close == "/" then
            if name == "g" and #stack > 1 then table.remove(stack) end
        elseif name == "g" then
            local cur = stack[#stack]
            local s, tx, ty = parseTransform(attr(" " .. tag, "transform"))
            -- compose: outer(inner(x)) = cs (s x + tx) + ctx
            stack[#stack + 1] = { cur[1] * s, cur[1] * tx + cur[2], cur[1] * ty + cur[3] }
            if tag:sub(-1) == "/" then table.remove(stack) end
        else
            local t = " " .. tag
            local d
            if name == "path" then d = attr(t, "d")
            elseif name == "circle" then local r = num(attr(t, "r")); d = circle(num(attr(t, "cx")), num(attr(t, "cy")), r, r)
            elseif name == "ellipse" then d = circle(num(attr(t, "cx")), num(attr(t, "cy")), num(attr(t, "rx")), num(attr(t, "ry")))
            elseif name == "rect" then d = rect(num(attr(t, "x")), num(attr(t, "y")), num(attr(t, "width")), num(attr(t, "height")), num(attr(t, "rx")))
            end
            if d then
                local cur = stack[#stack]
                parts[#parts + 1] = transformPath(d, cur[1], cur[2], cur[3])
            end
        end
    end
    local svgTag = svg:match("<svg[^>]*>") or ""
    local filled = (attr(" " .. svgTag, "fill") or "none") ~= "none"
    return table.concat(parts, " "), filled
end

local cache = {}
--- RML for an icon in a 24 x 24 box: name of a built-in, inline <svg>, or an image path.
---   class: extra classes; the colour comes from the CSS of its parent (.ic { stroke / fill })
function I.rml(icon, class)
    icon = type(icon) == "string" and icon or "pin"
    class = class or ""
    if icon:match("^%s*<svg") then
        local d, filled = I.pathData(icon)
        return ('<path class="ic %s %s" view-box="0 0 24 24" d="%s"/>'):format(filled and "ic-fill" or "ic-line", class, d)
    end
    if icon:match("^nui:") or icon:match("^%./") or icon:match("%.png$") or icon:match("%.webp$") or icon:match("%.svg$") then
        return ('<img class="ic-img %s" src="%s"/>'):format(class, icon:gsub('"', ""))
    end
    local key = icon
    local d = cache[key]
    if not d then
        d = I.pathData(P[icon] or P.pin)
        cache[key] = d
    end
    return ('<path class="ic ic-line %s" view-box="0 0 24 24" d="%s"/>'):format(class, d)
end

function I.maneuver(kind, class)
    local key = "m:" .. tostring(kind)
    local d = cache[key]
    if not d then
        d = I.pathData(M[kind] or M.straight)
        cache[key] = d
    end
    return ('<path class="ic ic-line ic-man %s" view-box="0 0 24 24" d="%s"/>'):format(class or "", d)
end

function I.known(name) return P[name] ~= nil end
