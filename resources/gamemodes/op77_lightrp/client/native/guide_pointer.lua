-- The way to the first day's objective on NativeUI (ui/native/guide_pointer.rml), the page's
-- GuidePointer.tsx + guide.ts. client/core/tutorial_guide.lua decides when it shows and
-- sends E.page.tutorialGuide ({ label, distance, angle, rise } or { hide = true }) when it
-- changes, at least once a second:
--   * in view: a waypoint over the objective, its name and distance. The page followed a
--     page anchor the plugin projected every frame ("tutorial.guide", 2.2 m over the
--     objective, seen up to 1000 m); here the same point is projected with
--     Open77.camera.project every frame.
--   * out of view (behind, beside, no projection): an arrow on a ring round the screen
--     centre, turned toward it, with the distance;
--   * within a few metres: nothing, the objective's own prompt takes over.
-- Nothing heard for 3.5 s: the client stopped guiding, the pointer goes.
-- The tutorial's dialogs and the objective card stay in the page.
local N = LightRpNative
local E = LightRpEvents
local M = {}
LightRpNativeGuidePointer = M

local STALE_MS = 3500      -- GUIDE_STALE_MS
local CLOSE_M = 4          -- GUIDE_CLOSE_M
local MARGIN_X, MARGIN_Y = 0.03, 0.06
local ANCHOR_LIFT, ANCHOR_VIEW = 2.2, 1000 -- client/core/tutorial_guide.lua

local doc
local latest = { way = nil, at = 0 }
local placed = {} -- what the document was last given: waypoint, edge, turn

local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end

--- The way from a page message, or nil (guide.ts readWay).
function M.readWay(message)
    if type(message) ~= "table" or message.hide or not finite(message.distance) then return nil end
    return {
        label = type(message.label) == "string" and message.label or "",
        distance = math.max(0, message.distance),
        angle = finite(message.angle) and message.angle or 0,
        rise = finite(message.rise) and message.rise or 0,
    }
end

function M.formatDistance(metres)
    if metres >= 1000 then return ("%.1f km"):format(metres / 1000) end
    return ("%d m"):format(math.floor(metres + 0.5))
end

--- Where the edge arrow sits for a bearing: on an ellipse round the screen centre, clear of
--- the objective card on the right. `angle` positive to the left; screen fractions.
function M.edgePoint(angle, rx, ry)
    rx, ry = rx or 0.25, ry or 0.31
    local turn = -angle -- clockwise from straight up
    local r = math.rad(turn)
    return 0.5 + math.sin(r) * rx, 0.5 - math.cos(r) * ry, turn
end

--- The model's texts for a way (pure).
function M.texts(way)
    local rise = math.abs(way.rise) >= 2
    return {
        label = way.label, hasLabel = way.label ~= "",
        distance = M.formatDistance(way.distance),
        rise = rise and ("%s m"):format(tostring(math.abs(way.rise))) or "", hasRise = rise, riseDown = rise and way.rise < 0,
    }
end

local function currentWay(now)
    if latest.way and now - latest.at <= STALE_MS then return latest.way end
    return nil
end

-- The objective the page's tutorial state names (the pointer was mounted only with one).
local function objective()
    local t = N.state.tutorial
    local o = type(t) == "table" and t.active and type(t.objective) == "table" and t.objective.position
    if type(o) ~= "table" or not (finite(o.x) and finite(o.y) and finite(o.z)) then return nil end
    return o
end

-- The anchor over the objective on screen: x, y (0..1 from the top left), on screen?
local function project(o)
    if type(Open77.camera) ~= "table" or type(Open77.camera.project) ~= "function" then return nil end
    local ok, p = pcall(Open77.camera.project, { x = o.x, y = o.y, z = o.z + ANCHOR_LIFT })
    if not ok or type(p) ~= "table" or not finite(p.x) or not finite(p.y) then return nil end
    local depth = tonumber(p.depth)
    return p.x, p.y, p.onScreen ~= false and (depth == nil or depth > 0)
end

local function model()
    return { ready = false, hidden = true, quiet = false, inView = false, atEdge = false,
        label = "", hasLabel = false, distance = "", rise = "", hasRise = false, riseDown = false }
end

local function place(key, sel, x, y)
    local value = ("%.2f|%.2f"):format(x * 100, y * 100)
    if placed[key] == value then return end
    placed[key] = value
    doc:style(sel, { left = ("%.2f%%"):format(x * 100), top = ("%.2f%%"):format(y * 100) })
end

-- One paint; returns whether the pointer shows (the caller then paints every frame).
local function paint()
    local o = objective()
    local way = o and currentWay(N.now()) or nil
    local shown = way ~= nil and way.distance >= CLOSE_M
    if not shown then
        N.patch(doc, "guide", { inView = false, atEdge = false })
        return false
    end
    local x, y, onScreen = project(o)
    local inView = x ~= nil and onScreen and way.distance <= ANCHOR_VIEW
        and x >= MARGIN_X and x <= 1 - MARGIN_X and y >= MARGIN_Y and y <= 1 - MARGIN_Y
    local values = M.texts(way)
    values.inView, values.atEdge = inView, not inView
    N.patch(doc, "guide", values)
    if inView then
        place("waypoint", "#waypoint", x, y)
    else
        local ex, ey, turn = M.edgePoint(way.angle)
        place("edge", "#edge", ex, ey)
        local rotation = ("rotate(%.1fdeg)"):format(turn)
        if placed.turn ~= rotation then placed.turn = rotation; doc:style("#arrow", "transform", rotation) end
    end
    return true
end

N.onStart(function()
    doc = N.create({ document = "ui/native/guide_pointer.rml", zIndex = 15, models = { guide = model() } })
    if not doc then return end
    doc:onEvent("reloaded", function()
        placed = {}
        N.forget(doc, "guide")
        N.patch(doc, "guide", { ready = N.shell.ready, hidden = N.shell.hidden, quiet = N.shell.quiet })
    end)
    N.patch(doc, "guide", { ready = N.shell.ready, hidden = N.shell.hidden, quiet = N.shell.quiet })
    CreateThread(function()
        while true do
            local ok, shown = pcall(paint)
            if not ok then N.log("guide pointer: " .. tostring(shown)) end
            -- the anchor moves every frame; hidden, the feed and the staleness are looked at 4 times a second
            Wait(ok and shown and not N.shell.hidden and 0 or 250)
        end
    end)
end)

N.onShell(function(shell)
    N.patch(doc, "guide", { ready = shell.ready, hidden = shell.hidden, quiet = shell.quiet })
end)

N.on(E.page.tutorialGuide, function(message)
    latest = { way = M.readWay(message), at = N.now() }
end)
