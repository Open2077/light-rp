-- op77_map3d on NativeUI: the map and the minimap drawn by the client's own
-- D3D12 scene layer -- one document, one city loaded once, two views of it. client/main.lua keeps talking the page protocol it always did
-- (send / on / show / hide / setFocus per role); this module answers it.
--
-- The heavy parts stay native and generic: the 3D views, the GPS search
-- (scene graph + route), the areas and zones drawn in the scene's shaders,
-- markers pinned to the views (anchors: edge clamp, heading, clustering).
Map3DNative = {}
local N = Map3DNative
local D, T, I = Map3DDefaults, Map3DTheme, Map3DIcons

local RES = GetCurrentResourceName()
local SCENE = "city"
local DATA = "web/data/"
local LAYER_COMMON, LAYER_MINI, LAYER_FULL = 1, 2, 4

-- ---------------------------------------------------------------------------
-- state

local ui = nil
local manifest = nil
local cfg = D.copy(D.config)
local adapters = {}            -- role -> adapter
local handlers = {}            -- role -> message -> fn
local docLoaded, dataReady = false, false
local loadState = { world = 0, buildings = 0, roads = 0 }
local quality, qualityChosen = "performance", true
local perf = true
local isOpen, closingUntil = false, 0
local asking, askPick = false, "performance"
local minimapVisible = true
local miniShown, fullShown = false, false
local prefs = { hud = {}, layers = {}, hiddenCats = {} }
local player = { valid = false, x = -1450, y = 140, z = 20, yaw = 0, camYaw = 0, speed = 0, vehicle = false, vx = 0, vy = 0, t = 0, heading = 0 }
local blips = {}               -- id -> { b = blip, mini = serial, full = serial, sig = string }
local blipOrder = 0
local selected = nil           -- blip id with the card open
local waypoint = nil           -- { x, y, z }
local route = nil              -- { points, cumulative, length, seconds, maneuvers, id }
local routeSeq = 0
local nav = { hint = 0, offSince = nil, lastRoute = 0, lastAttempt = -1e9, arrivedFor = nil, lastInfo = 0, along = 0, lastProgress = 0 }
local areas = {}               -- id -> page area (normalized by shared/area.lua)
local areaSeq = 0
local influence = { enabled = false, zones = {}, levels = {} }
local influenceAllowed = true
local zonesShown = {}          -- id -> eased { x, y, r, level, alpha, target }
local jam = { strength = 0, label = nil }
local miniZoom, zoomDir = 1, 0
local miniCam = nil            -- eased minimap camera
local savedView = nil          -- { distance, yaw, pitch } of the open map (TS convention: pitch from straight down, radians)
local fullCam = { distance = 2600, yaw = 0, pitch = 48, target = { x = 0, y = 0, z = 0 } } -- last read (native pitch, degrees)
local keysHeld = {}
local typing = false
local searchResults, searchSel = {}, 1
local lastHover = nil
local warned = {}

local function warn(key, text) if not warned[key] then warned[key] = true; print("[map3d] " .. text) end end
local function now() return GetGameTimer() end
local function clamp(v, a, b) return v < a and a or (v > b and b or v) end
local function ease(rate, dt) return 1 - math.exp(-math.min(dt, 0.1) * rate) end
local function angleDelta(a, b) local d = (b - a) % 360; if d > 180 then d = d - 360 end; return d end
local function esc(s) return (tostring(s or ""):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")) end
local function L(key) return (cfg.locale or {})[key] or D.config.locale[key] or key end

local function emit(role, name, payload)
    local h = handlers[role]
    local fn = h and h[name]
    if fn then
        local ok, why = pcall(fn, payload)
        if not ok then print("[map3d] " .. role .. " " .. name .. ": " .. tostring(why)) end
    end
end
local function gpsRole() return adapters.mini and "mini" or "full" end
local function mapRole() return adapters.full and "full" or "mini" end

local function scene(op, spec) if ui then return ui:scene(SCENE, op, spec) end end
local function kvpGet(key)
    if type(Open77.kvp) ~= "table" or type(Open77.kvp.get) ~= "function" then return nil end
    local ok, v = pcall(Open77.kvp.get, key)
    if not ok or type(v) ~= "string" or v == "" then return nil end
    local okd, t = pcall(Open77.json.decode, v)
    return okd and t or nil
end
local function kvpSet(key, value)
    if type(Open77.kvp) ~= "table" or type(Open77.kvp.set) ~= "function" then return end
    local ok, s = pcall(Open77.json.encode, value)
    if ok then pcall(Open77.kvp.set, key, s) end
end

-- ---------------------------------------------------------------------------
-- formatting (gps.ts / app.ts)

local function fmtDist(m)
    m = math.max(0, m or 0)
    if (cfg.gps or {}).units == "imperial" then
        local ft = m * 3.28084
        if ft < 1000 then return ("%d ft"):format(math.floor(ft / 10 + 0.5) * 10) end
        return ("%.1f mi"):format(m / 1609.344)
    end
    if m < 1000 then return ("%d m"):format(math.floor(m / 5 + 0.5) * 5) end
    if m < 10000 then return ("%.1f km"):format(m / 1000) end
    return ("%d km"):format(math.floor(m / 1000 + 0.5))
end
local function fmtEta(remaining)
    if not route then return "" end
    local avg = route.length > 0 and route.length / math.max(1, route.seconds) or 12
    local s = remaining / math.max(4, avg)
    if s < 60 then return ("%d s"):format(math.max(1, math.floor(s + 0.5))) end
    return ("%d min"):format(math.floor(s / 60 + 0.5))
end

local function districtAt(x, y)
    if not manifest or type(manifest.districts) ~= "table" then return "BADLANDS" end
    local best, bestD = nil, 2600
    for key, d in pairs(manifest.districts) do
        local c = d.center or d.centre or d
        local cx, cy = tonumber(c.x or c[1]), tonumber(c.y or c[2])
        if cx and cy then
            local dist = math.sqrt((cx - x) ^ 2 + (cy - y) ^ 2)
            if dist < bestD then best, bestD = key, dist end
        end
    end
    if not best then return "BADLANDS" end
    return D.districts[best] or tostring(best):upper()
end

-- ---------------------------------------------------------------------------
-- document

local function rootClass(name, on) if ui then ui:class("#m3", name, on) end end

local function applyTheme()
    if not ui then return end
    ui:stylesheet("theme", T.rcss(cfg.theme))
end

local function categoryOf(id)
    for _, c in ipairs(cfg.categories or {}) do if c.id == id then return c end end
    return nil
end

local function placeMinimap()
    if not ui then return end
    local m = cfg.minimap or {}
    local size = tonumber(m.size) or 264
    local margin = type(m.margin) == "table" and m.margin or { 32, 26 }
    local anchor = tostring(m.anchor or "top-right")
    local style = { width = size .. "dp", height = size .. "dp" }
    style.left, style.right, style.top, style.bottom = "auto", "auto", "auto", "auto"
    if anchor:find("left") then style.left = (tonumber(margin[1]) or 32) .. "dp" else style.right = (tonumber(margin[1]) or 32) .. "dp" end
    if anchor:find("bottom") then style.bottom = ((tonumber(margin[2]) or 26) + 34) .. "dp" else style.top = (tonumber(margin[2]) or 26) .. "dp" end
    ui:style("#mini", style)
    ui:style("#mini-info", { top = (size + 6) .. "dp" })
    ui:style("#mini-toast", { top = (size + 30) .. "dp" })
    for _, shape in ipairs({ "chamfer", "circle", "square" }) do rootClass("shape-" .. shape, (m.shape or "chamfer") == shape) end
end

local function syncTexts()
    if not ui then return end
    ui:text("#title", (cfg.map or {}).title or "NIGHT CITY")
    ui:text("#subtitle", (cfg.map or {}).subtitle or "CITY MAP")
    ui:class("#m3", "has-search", (cfg.map or {}).search ~= false)
    ui:attr("#search-input", "placeholder", L("search"))
    local keys = cfg.keys or {}
    local help = {
        { "DRAG", "Pan" }, { "RIGHT DRAG", perf and "Rotate" or "Rotate / tilt" }, { "WHEEL", "Zoom" },
        { keys.waypoint or "Double click", L("waypoint") }, { keys.recenter or "SPACE", L("recenter") },
    }
    local parts = {}
    for _, h in ipairs(help) do parts[#parts + 1] = ('<span><span class="kbd">%s</span>%s</span>'):format(esc(h[1]), esc(h[2])) end
    ui:rml("#help", table.concat(parts))
    ui:rml("#search-icon", I.rml("search"))
    ui:rml("#t-center-icon", I.rml("crosshair"))
    ui:rml("#mini-wp-icon", I.rml("waypoint"))
    ui:rml(".jam-icon", I.rml("nosignal"))
end

-- ---------------------------------------------------------------------------
-- scene: data, styles, views

local function themeColor(key) return (cfg.theme or {})[key] or D.config.theme[key] end

local function applySceneStyle()
    if not ui then return end
    local th = cfg.theme or {}
    local fog = tonumber(th.fog) or 0.35
    scene("style", {
        background = T.hex(themeColor("background"), 0.35),
        fogColor = themeColor("background"), fog = clamp(fog * 1.6, 0, 0.95),
        fogNear = 3000 + (1 - fog) * 6000, fogFar = 12000 + (1 - fog) * 14000,
        ambient = 0.62, sun = 0.55, sunDirection = { x = -0.45, y = 0.35, z = 0.85 },
        rim = themeColor("landmark"), rimStrength = 0.25, rimPower = 2.5,
        lowColor = "#d9dbe3", highColor = "#ffffff", heightLow = 0, heightHigh = 260, heightMix = 0.35,
    })
end

local function layerVisible(key) return (prefs.layers or {})[key] ~= false end

local function applyStyles()
    if not ui or not dataReady then return end
    local th = cfg.theme or {}
    local function c(k) return themeColor(k) end
    local all = LAYER_COMMON
    local grid = perf and 1000 or 100
    scene("set", { name = "world/terrain", color = c("terrain"), unlit = perf, receivesAreas = true, receivesZones = true,
        grid = grid, gridColor = c("terrainGrid"), gridOpacity = perf and 0.1 or 0.08, layers = all })
    scene("set", { name = "world/cliffs", color = T.mix(c("terrain"), "#000000", 0.15), unlit = perf, receivesAreas = true, layers = all })
    scene("set", { name = "world/water", color = c("water"), unlit = true, receivesAreas = true, layers = all })
    scene("set", { name = "world/roads", color = c("road"), unlit = true, receivesAreas = true, receivesZones = true, layers = all, order = 1 })
    scene("set", { name = "world/roadBorders", color = c("roadEdge"), opacity = 0.22, unlit = true, transparent = true, layers = all,
        visible = layerVisible("roadBorders"), order = 2 })
    scene("set", { name = "world/metro", color = c("metro"), unlit = true, layers = all, visible = layerVisible("metro") })
    scene("set", { name = "world/landmarks", color = perf and T.mix(c("building"), c("landmark"), 0.14) or c("building"), unlit = perf,
        receivesAreas = true, edge = T.mix(c("building"), c("landmark"), 0.65), edgeWidth = perf and 0 or 1.2, layers = all })
    local buildings = layerVisible("buildings") and (cfg.map or {}).buildings ~= false
    scene("set", { name = "buildings", color = T.mix(c("building"), c("buildingTop"), 0.25), visible = buildings and not perf,
        edge = T.mix(c("building"), c("buildingEdge"), 0.4), edgeWidth = 1.1, receivesAreas = true,
        receivesZones = (cfg.influence or {}).buildings ~= false, xray = true, layers = all })
    scene("set", { name = "roofs", color = T.mix(c("building"), c("buildingTop"), 0.45), unlit = true, visible = buildings and perf,
        edge = T.mix(c("building"), c("buildingEdge"), 0.35), edgeWidth = 1, receivesAreas = true, layers = all })
    scene("zones", { colors = (cfg.influence or {}).colors or D.config.influence.colors, strength = 1 })
    scene("areas", { hatch = (cfg.areas or {}).hatch or 11 })
end

local function applyViews()
    if not ui then return end
    local m = cfg.minimap or {}
    local fps = tonumber(m.fps) or 60
    local bg = themeColor("background")
    local xray = (not perf) and (tonumber(m.xray) or 70) or 0
    scene("view", {
        view = "mini", layers = LAYER_COMMON + LAYER_MINI, samples = perf and 1 or 4,
        scale = perf and 1.25 or math.max(1, math.min(2, tonumber(m.supersample) or 1.75)),
        effects = perf and 0 or 1, maxFps = perf and math.min(30, fps) or fps, areas = true, zones = false,
        hatch = (cfg.areas or {}).minimapHatch or 9, areaStrength = (cfg.areas or {}).minimapStrength or 0.85,
        clear = T.hex(bg, 0.3), xray = xray > 0 and { x = player.x, y = player.y, z = player.z + 1.5, radius = xray } or false,
    })
    local zonesOn = influence.enabled and influenceAllowed and layerVisible("influence") and not perf
    scene("view", {
        view = "full", layers = LAYER_COMMON + LAYER_FULL, samples = perf and 1 or 4,
        scale = clamp(tonumber((cfg.map or {}).resolution) or 1, 0.5, perf and 1 or 2),
        effects = perf and 0 or 1, maxFps = tonumber((cfg.map or {}).idleFps) or 30, areas = true, zones = zonesOn,
        hatch = (cfg.areas or {}).hatch or 11, areaStrength = 1, clear = T.hex(bg, 0.35),
    })
    local mp = cfg.map or {}
    scene("camera", {
        view = "full", controls = "map", mode = perf and "ortho" or "perspective", fov = 42, near = 5, far = 40000,
        minDistance = tonumber(mp.minDistance) or 60, maxDistance = tonumber(mp.maxDistance) or 11000,
        minPitch = 90 - (tonumber(mp.maxPitch) or 72), maxPitch = 89.9, pickHeight = 20,
    })
    if perf then scene("camera", { view = "full", pitch = 89.9, animate = false }) end
    scene("camera", { view = "mini", controls = "none", mode = perf and "ortho" or "perspective", fov = 48, near = 2, far = 12000, minDistance = 10, maxDistance = 20000, minPitch = 1, maxPitch = 89.9 })
    rootClass("is-perf", perf)
    syncTexts()
end

local function buildScene()
    scene("config", { axis = "game" })
    applySceneStyle()
    scene("mesh", { name = "world", file = DATA .. ((manifest.world or {}).file or "world.glb") })
    local chunks = {}
    for _, d in ipairs((manifest.buildings or {}).districts or {}) do
        chunks[#chunks + 1] = { offset = d.offset, count = d.count, min = d.min, span = d.span, maxSize = d.maxSize }
    end
    local bfile = DATA .. ((manifest.buildings or {}).file or "buildings.bin")
    scene("instances", { name = "buildings", mesh = "box", file = bfile, axis = "scene", format = "boxes16", chunks = chunks, visible = false })
    scene("instances", { name = "roofs", mesh = "roof", file = bfile, axis = "scene", format = "boxes16", chunks = chunks, visible = false })
    local roads = manifest.roads or {}
    local a, flags = roads.arrays or {}, roads.flags or {}
    local rfile = DATA .. (roads.file or "roads.bin")
    scene("graph", { name = "roads", file = rfile, arrays = a, highway = flags.highway or 16384 })
    -- the destination marker: a beam and a pulsing ring (hidden until a waypoint)
    scene("mesh", { name = "tube", primitive = "tube" })
    scene("mesh", { name = "ring", primitive = "ring" })
    scene("object", { name = "dest_beam", mesh = "tube", beam = true, additive = true, unlit = true, visible = false, layers = LAYER_COMMON, order = 20 })
    scene("object", { name = "dest_ring", mesh = "ring", pulseRate = 0.8, pulseScale = 0.35, additive = true, unlit = true, visible = false, layers = LAYER_COMMON, order = 21 })
    scene("instances", { name = "beacons", mesh = "tube", items = {}, beam = true, additive = true, unlit = true, beamBands = 8, layers = LAYER_FULL, order = 22 })
end

local function stageProgress()
    if not ui then return end
    local done = loadState.world + loadState.buildings + loadState.roads
    ui:style("#ld-fill", { width = math.floor(done / 3 * 100) .. "%" })
    ui:text("#ld-stage", loadState.world == 0 and "TERRAIN" or loadState.buildings == 0 and "BUILDINGS" or loadState.roads == 0 and "ROAD NETWORK" or "MAP DATA")
end

-- forward declarations
local applyMode, syncBlips, syncWaypointBlip, refreshLegend, computeRoute, setWaypoint, syncDestination, syncAreas, syncZones, toast
-- heavy work is marked here and done by the frame loop, a little each frame
local dirty = {}
local blipQueue, blipQueueOrder = {}, {}   -- id -> def | false (remove), in arrival order

local function readyInfo()
    local st = ui and ui:state() or {}
    return { lanes = (manifest.roads or {}).lanes or 0, buildings = (manifest.buildings or {}).count or 0,
        vw = tonumber(st.width) or 1920, vh = tonumber(st.height) or 1080 }
end

local function onDataReady()
    if dataReady then return end
    dataReady = true
    rootClass("is-loading", false)
    applyStyles()
    applyViews()
    syncAreas()
    syncDestination()
    if waypoint then computeRoute() end
    for _, role in ipairs({ "mini", "full" }) do if adapters[role] then emit(role, "map3d:ready", readyInfo()) end end
    if adapters.full then emit("full", "map3d:prefs", prefs) end
end

local function onSceneEvent(name, detail)
    detail = type(detail) == "table" and detail or {}
    if name == "loaded" then
        if detail.object == "world" then loadState.world = 1
        elseif detail.object == "buildings" then loadState.buildings = 1
        elseif detail.graph == "roads" then loadState.roads = 1 end
        stageProgress()
        if loadState.world == 1 and loadState.buildings == 1 and loadState.roads == 1 then onDataReady() end
    elseif name == "error" then
        local message = tostring(detail.error or "load failed") .. " (" .. tostring(detail.object or detail.graph or detail.file) .. ")"
        print("[map3d] map data: " .. message)
        if ui then ui:rml("#loading", ("<b>MAP DATA</b><span>%s</span>"):format(esc(message))) end
        for _, role in ipairs({ "mini", "full" }) do if adapters[role] then emit(role, "map3d:error", { message = message }) end end
    elseif name == "route" then
        N.onRoute(detail)
    elseif name == "lost" then
        -- the GPU device was reset: geometry has to come again
        dataReady, loadState = false, { world = 0, buildings = 0, roads = 0 }
        scene("clear")
        buildScene()
    end
end

local function ensureDocument()
    if ui then return true end
    local text = LoadResourceFile(RES, DATA .. "manifest.json")
    if not text then print("[map3d] " .. DATA .. "manifest.json is missing"); return false end
    local ok, m = pcall(Open77.json.decode, text)
    if not ok or type(m) ~= "table" then print("[map3d] manifest.json unreadable"); return false end
    manifest = m
    pcall(Open77.ui.loadFont, "ui/native/fonts/zen-dots-400.ttf", "Zen Dots")
    pcall(Open77.ui.loadFont, "ui/native/fonts/share-tech-mono-400.ttf", "Share Tech Mono")
    local created, why = Open77.ui.create({ document = "ui/native/map.rml", layer = "hud", zIndex = 40, visible = true })
    if not created then print("[map3d] no NativeUI document: " .. tostring(why)); return false end
    ui = created
    ui:onEvent("loaded", function()
        docLoaded = true
        applyTheme()
        placeMinimap()
        syncTexts()
        rootClass("is-loading", true)
        rootClass("has-mini", false)
        buildScene()
        N.bindInput()
    end)
    ui:onEvent("reloaded", function() applyTheme(); placeMinimap(); syncTexts(); syncBlips(true); applyMode() end)
    ui:onEvent("scene", onSceneEvent)
    ui:onEvent("error", function(name, detail) warn("ui:" .. tostring(name), "ui " .. tostring(name) .. ": " .. tostring(detail and detail.message)) end)
    ui:onEvent("focus", function(name, detail)
        if name == "blur" and isOpen and detail and detail.reason == "taken" then
            -- another interface took the input: the map steps aside
            emit("full", "map3d:close", {})
        end
    end)
    return true
end

-- ---------------------------------------------------------------------------
-- prefs (the legend's switches), kept on this machine

local PREFS_KEY, VIEW_KEY, ZOOM_KEY = "map3d:prefs", "map3d:view", "map3d:miniZoom"
local function loadPrefs()
    local p = kvpGet(PREFS_KEY)
    if type(p) == "table" then
        prefs.hud = type(p.hud) == "table" and p.hud or {}
        prefs.layers = type(p.layers) == "table" and p.layers or {}
        prefs.hiddenCats = type(p.hiddenCats) == "table" and p.hiddenCats or {}
    end
    local z = kvpGet(ZOOM_KEY)
    if type(z) == "table" and tonumber(z.value) then miniZoom = clamp(tonumber(z.value), 0.35, 3) end
    local v = kvpGet(VIEW_KEY)
    if type(v) == "table" and tonumber(v.distance) then savedView = v end
end
local function savePrefs()
    kvpSet(PREFS_KEY, prefs)
    emit("full", "map3d:prefs", prefs)
end
local function catHidden(cat)
    for _, c in ipairs(prefs.hiddenCats or {}) do if c == cat then return true end end
    return false
end

-- ---------------------------------------------------------------------------
-- blips: an element per view, pinned by a native anchor

local function blipColor(b)
    if b.color then return b.color end
    local c = categoryOf(b.category or "default")
    return c and c.color or themeColor("accent")
end

local function blipRml(b, mini)
    local color = T.hex(blipColor(b))
    local isArrow = b.heading ~= nil
    local icon = isArrow and "" or I.rml(b.icon or "pin")
    -- the icon takes the blip colour: the stroke of a line icon, the fill of a filled one
    icon = icon:gsub('class="ic ic%-line', ('style="stroke: %s;" class="ic ic-line'):format(color), 1)
        :gsub('class="ic ic%-fill', ('style="fill: %s;" class="ic ic-fill'):format(color), 1)
    local parts = {}
    if isArrow then
        parts[#parts + 1] = ('<path class="arrow" view-box="0 0 24 24" d="M12 3 19 20 12 16 5 20z" style="fill: %s;"/>'):format(T.hex(themeColor("accent")))
    else
        parts[#parts + 1] = ('<div class="pin" style="decorator: fx(chamfer %d 1.5 0.0 0 %s);">%s</div>'):format(mini and 5 or 7, color, icon)
    end
    parts[#parts + 1] = ('<div class="ring" style="border-color: %s;"></div>'):format(color)
    if not mini then parts[#parts + 1] = ('<div class="label" style="border-left-color: %s;">%s</div>'):format(color, esc(b.label or "")) end
    parts[#parts + 1] = ('<div class="count" style="background-color: %s;"></div>'):format(color)
    return table.concat(parts)
end

local function blipClasses(b)
    local cls = { "blip" }
    if (b.priority or 0) >= 2 then cls[#cls + 1] = "prio" end
    if b.pulse then cls[#cls + 1] = "pulse" end
    if b.heading ~= nil then cls[#cls + 1] = "is-arrow" end
    if b.id == "__player" then cls[#cls + 1] = "is-self" end
    return table.concat(cls, " ")
end

local function iconColorStyle(b)
    return ("color: %s;"):format(T.hex(blipColor(b)))
end

local function anchorBlip(entry, view)
    local b = entry.b
    local serial = entry[view]
    if not serial then return end
    local spec = { scene = SCENE, view = view, point = { x = b.x, y = b.y, z = (b.z or 0) + 2 }, transform = true }
    if b.heading ~= nil then spec.heading = b.heading; spec.rotate = ".arrow" end
    spec.priority = b.priority or 0
    if view == "mini" then
        if b.edge then spec.clamp = (cfg.minimap or {}).shape == "circle" and "circle" or "rect"; spec.inset = 16 end
        spec.group, spec.cluster = "mini", 15
    else
        spec.group, spec.cluster, spec.fan = "full", 30, 36
    end
    ui:anchor(serial, spec)
end

local function shownOn(b, view)
    if b.id ~= "__player" and b.id ~= "__waypoint" and catHidden(b.category or "default") then return false end
    if view == "mini" then return b.minimap ~= false end
    return b.map ~= false
end

local function makeBlipElement(entry, view)
    local b = entry.b
    local parent = view == "mini" and "#mini-blips" or "#full-blips"
    local serial = ui:create(parent, { tag = "div", class = blipClasses(b), rml = blipRml(b, view == "mini") })
    entry[view] = serial
    if not shownOn(b, view) then ui:class(serial, "hide", true) end
    anchorBlip(entry, view)
end

local function dropBlipElement(entry, view)
    local serial = entry[view]
    if not serial then return end
    ui:unanchor(serial)
    ui:remove(serial)
    entry[view] = nil
end

local function blipSig(b)
    return table.concat({ tostring(b.icon), tostring(b.color), tostring(b.label), tostring(b.category), tostring(b.pulse),
        tostring(b.priority), tostring(b.heading ~= nil), tostring(b.edge), tostring(b.map), tostring(b.minimap) }, "|")
end

local function upsertBlipNow(def)
    if type(def) ~= "table" or def.id == nil or type(def.x) ~= "number" or type(def.y) ~= "number" then return end
    local id = tostring(def.id)
    local b = {}
    for k, v in pairs(def) do b[k] = v end
    b.id = id
    local entry = blips[id]
    if not ui or not docLoaded then
        blips[id] = entry or { b = b, order = 0 }
        if entry then entry.b = b end
        return
    end
    local sig = blipSig(b)
    if entry and entry.sig == sig then
        entry.b = b
        anchorBlip(entry, "mini")
        anchorBlip(entry, "full")
        return
    end
    if entry then dropBlipElement(entry, "mini"); dropBlipElement(entry, "full") end
    blipOrder = blipOrder + 1
    entry = { b = b, sig = sig, order = blipOrder }
    blips[id] = entry
    makeBlipElement(entry, "mini")
    makeBlipElement(entry, "full")
end

local function removeBlipNow(id)
    id = tostring(id)
    local entry = blips[id]
    if not entry then return end
    if ui then dropBlipElement(entry, "mini"); dropBlipElement(entry, "full") end
    blips[id] = nil
    if selected == id and id ~= "__waypoint" then N.select(nil) end
end

local function syncBlipsNow(rebuild)
    if not ui or not docLoaded then return end
    for _, entry in pairs(blips) do
        if rebuild or not entry.mini then
            dropBlipElement(entry, "mini"); dropBlipElement(entry, "full")
            entry.sig = blipSig(entry.b)
            makeBlipElement(entry, "mini")
            makeBlipElement(entry, "full")
        else
            for _, view in ipairs({ "mini", "full" }) do
                if entry[view] then ui:class(entry[view], "hide", not shownOn(entry.b, view)) end
            end
        end
    end
end

local function queueBlip(id, def)
    id = tostring(id)
    if blipQueue[id] == nil then blipQueueOrder[#blipQueueOrder + 1] = id end
    blipQueue[id] = def
end
local function upsertBlip(def)
    if type(def) ~= "table" or def.id == nil or type(def.x) ~= "number" or type(def.y) ~= "number" then return end
    local entry = blips[tostring(def.id)]
    -- a known blip whose look did not change only moves: no queue, no element work
    if entry and entry.mini and not blipQueue[tostring(def.id)] then
        local b = {}
        for k, v in pairs(def) do b[k] = v end
        b.id = tostring(def.id)
        if blipSig(b) == entry.sig then
            entry.b = b
            anchorBlip(entry, "mini")
            anchorBlip(entry, "full")
            return
        end
    end
    queueBlip(def.id, def)
end
local function removeBlip(id) queueBlip(id, false) end
function syncBlips(rebuild) dirty.blips = rebuild and "rebuild" or (dirty.blips or "sync") end

local function selfBlip()
    if not player.valid then return end
    upsertBlip({ id = "__player", x = player.x, y = player.y, z = player.z, heading = player.heading, category = "__self",
        priority = 2, color = themeColor("accent"), routable = false, minimap = false })
end

function syncWaypointBlip()
    if waypoint then
        upsertBlip({ id = "__waypoint", x = waypoint.x, y = waypoint.y, z = waypoint.z or 0, icon = "waypoint", label = L("waypoint"),
            edge = true, priority = 2, category = "__waypoint", routable = false })
    else
        removeBlip("__waypoint")
    end
end

-- ---------------------------------------------------------------------------
-- the minimap's own player arrow (at the eased centre), the north mark

local miniSelf = nil
local function ensureMiniSelf()
    if miniSelf or not ui then return end
    miniSelf = ui:create("#mini-blips", { tag = "div", class = "blip is-arrow is-self",
        rml = ('<path class="arrow" view-box="0 0 24 24" d="M12 3 19 20 12 16 5 20z"/>') })
    ui:anchor("#mini-north", { scene = SCENE, view = "mini", north = true, clamp = "rect", inset = 7, rotate = ".north-mark", transform = true })
end

-- ---------------------------------------------------------------------------
-- quality

local function applyModeNow()
    if not ui then return end
    perf = quality == "performance"
    rootClass("is-perf", perf)
    rootClass("is-open", isOpen)
    rootClass("has-route", route ~= nil)
    local hasMini = adapters.mini ~= nil and not isOpen and now() >= closingUntil and (cfg.minimap or {}).enabled ~= false
        and minimapVisible and dataReady and miniShown and player.valid
    rootClass("has-mini", hasMini)
    ui:style("#mini", "visibility", hasMini and "visible" or "hidden")
    asking = isOpen and dataReady and not qualityChosen and adapters.full ~= nil
    rootClass("is-asking", asking)
    if dataReady then applyStyles(); applyViews() end
    ui:class("#q-perf", "is-on", perf)
    ui:class("#q-quality", "is-on", not perf)
    ui:class("#qc-performance", "is-on", askPick == "performance")
    ui:class("#qc-quality", "is-on", askPick == "quality")
    syncZones(true)
    syncDestination()
end

local function setQuality(mode, fromChooser, chosen)
    if mode ~= "performance" and mode ~= "quality" then return end
    local changed = mode ~= quality
    quality = mode
    if chosen ~= nil then qualityChosen = chosen end
    if changed and isOpen then
        -- the open map changes projection: keep what it looks at
        if mode == "performance" then scene("camera", { view = "full", mode = "ortho", pitch = 89.9, duration = 0.5 })
        else
            local pitch = savedView and tonumber(savedView.pitch) and (90 - math.deg(savedView.pitch)) or 48
            scene("camera", { view = "full", mode = "perspective", pitch = math.min(pitch, 72), duration = 0.6 })
        end
    end
    applyMode()
    if fromChooser ~= nil then
        qualityChosen = true
        emit("full", "map3d:quality", { mode = mode })
        if not fromChooser then toast(mode == "performance" and L("performanceOn") or L("qualityOn")) end
        applyMode()
    end
end

-- ---------------------------------------------------------------------------
-- toasts

local toastSeq = 0
function toast(text, danger)
    if not ui then return end
    toastSeq = toastSeq + 1
    local target = isOpen and "#toast" or "#mini-toast"
    local seq = toastSeq
    ui:class("#toast", "show", false)
    ui:class("#mini-toast", "show", false)
    ui:text(target, text)
    ui:class(target, "danger", danger == true)
    CreateThread(function()
        Wait(0) -- a frame without the class restarts the animation
        if seq ~= toastSeq or not ui then return end
        ui:class(target, "show", true)
        Wait(2800)
        if seq == toastSeq and ui then ui:class(target, "show", false) end
    end)
end

-- ---------------------------------------------------------------------------
-- waypoint and GPS (the search runs natively: scene "route")

local function sameXY(a, b) return a and b and math.abs(a.x - b.x) < 0.5 and math.abs(a.y - b.y) < 0.5 end

local function routeStyle()
    local accent = themeColor("accent")
    local g = cfg.gps or {}
    local speed = perf and 0 or (tonumber(g.animationSpeed) or 1.6)
    local width = 8 * (tonumber(g.routeWidth) or 1)
    return {
        route = { lineColor = accent, width = width, widthBoost = 150, lineStyle = "chevrons", chevronPeriod = 9, chevronScale = 0.004,
            flow = speed, glow = 0.15, opacity = 0.95, travelledOpacity = 0.28, behindOpacity = 0.4, transparent = true, order = 10,
            layers = LAYER_FULL + (((cfg.minimap or {}).showRoute ~= false) and LAYER_MINI or 0), lift = 1.8 },
    }
end

function syncDestination()
    if not ui or not dataReady then return end
    if not waypoint then
        scene("set", { name = "dest_beam", visible = false })
        scene("set", { name = "dest_ring", visible = false })
        return
    end
    local d = isOpen and fullCam.distance or 400
    local s = math.max(4, d * 0.012)
    local z = waypoint.z or 0
    if route and route.points and #route.points >= 3 then z = route.points[#route.points] end
    local accent = themeColor("accent")
    scene("object", { name = "dest_beam", mesh = "tube", position = { x = waypoint.x, y = waypoint.y, z = z },
        scale = { x = s * 0.7, y = s * 0.7, z = 120 + d * 0.05 }, color = accent, opacity = 0.7, visible = true })
    scene("object", { name = "dest_ring", mesh = "ring", position = { x = waypoint.x, y = waypoint.y, z = z + 0.8 },
        scale = { x = s * 3.2, y = s * 3.2, z = 1 }, color = accent, opacity = 0.9, visible = true,
        pulseRate = perf and 0 or 0.8 })
end

local function emitRouteInfo(info) emit(gpsRole(), "map3d:routeInfo", info) end

function computeRoute()
    if not waypoint or not dataReady or (cfg.gps or {}).enabled == false then return end
    nav.lastAttempt = now()
    if not player.valid then route = nil; return end
    routeSeq = routeSeq + 1
    local g = cfg.gps or {}
    scene("route", {
        graph = "roads", id = routeSeq,
        from = { x = player.x, y = player.y, z = player.z }, to = { x = waypoint.x, y = waypoint.y, z = waypoint.z or 0 },
        heading = player.vehicle and player.yaw or nil, mainOnly = g.snapMainNetwork ~= false, avoidHighways = g.avoidHighways == true,
        lines = routeStyle(),
    })
end

function N.onRoute(d)
    if tonumber(d.id) ~= routeSeq then return end -- an older search
    if not waypoint then return end
    if not d.ok then
        route = nil
        scene("set", { name = "route", visible = false })
        toast(L("noRoute"), true)
        emitRouteInfo({ active = false })
        applyMode()
        return
    end
    route = { points = d.points or {}, cumulative = d.cumulative or {}, length = tonumber(d.length) or 0,
        seconds = tonumber(d.seconds) or 0, maneuvers = d.maneuvers or {}, id = d.id }
    nav.hint, nav.offSince, nav.lastRoute, nav.along = 0, nil, now(), 0
    scene("set", { name = "route", visible = true })
    emitRouteInfo({ active = true, length = math.floor(route.length + 0.5), seconds = math.floor(route.seconds + 0.5),
        computeMs = math.floor((tonumber(d.computeMs) or 0) + 0.5) })
    syncDestination()
    applyMode()
    N.navigate()
end

function setWaypoint(p, fromUser)
    if p and type(p.x) == "number" and type(p.y) == "number" then
        local wp = { x = p.x, y = p.y, z = tonumber(p.z) or 0 }
        if sameXY(wp, waypoint) and route then return end
        waypoint = wp
        if fromUser then emit("full", "map3d:waypoint", { x = wp.x, y = wp.y, z = wp.z }) end
        nav.arrivedFor = nil
        computeRoute()
    else
        if not waypoint and not route then return end
        waypoint, route = nil, nil
        routeSeq = routeSeq + 1
        if ui then
            scene("set", { name = "route", visible = false })
        end
        if fromUser then emit("full", "map3d:waypoint", { clear = true }) end
        emitRouteInfo({ active = false })
        nav.arrivedFor = nil
    end
    syncWaypointBlip()
    syncDestination()
    N.refreshNav(true)
    if selected then N.select(selected) end
    applyMode()
end

local function progressOn(px, py)
    local P, cum = route.points, route.cumulative
    local n = #cum
    local best = { along = 0, off = math.huge, index = 0 }
    local function scan(a, b)
        for i = a, b - 1 do
            local ax, ay, bx, by = P[i * 3 + 1], P[i * 3 + 2], P[i * 3 + 4], P[i * 3 + 5]
            if not bx then break end
            local dx, dy = bx - ax, by - ay
            local l2 = dx * dx + dy * dy
            if l2 == 0 then l2 = 1 end
            local t = clamp(((px - ax) * dx + (py - ay) * dy) / l2, 0, 1)
            local off = math.sqrt((px - ax - dx * t) ^ 2 + (py - ay - dy * t) ^ 2)
            if off < best.off then best = { along = cum[i + 1] + math.sqrt(l2) * t, off = off, index = i } end
        end
    end
    scan(math.max(0, nav.hint - 40), math.min(n - 1, nav.hint + 400))
    if best.off > 60 then scan(0, n - 1) end
    return best
end

local navHtml = {}
local function setRml(sel, rml)
    if navHtml[sel] == rml then return end
    navHtml[sel] = rml
    ui:rml(sel, rml)
end
local function setText(sel, text)
    if navHtml[sel] == text then return end
    navHtml[sel] = text
    ui:text(sel, text)
end

function N.refreshNav(force)
    if not ui then return end
    if force then navHtml = {} end
    -- the line under the minimap: district (or the area you stand in) and the waypoint
    local label, labelColor = nil, nil
    if (cfg.areas or {}).minimapLabel ~= false and player.valid then
        for _, a in pairs(areas) do
            if a.label and a.label ~= "" and a.minimap ~= false and N.areaContains(a, player.x, player.y) then
                label, labelColor = a.label, a.stroke or a.fill
            end
        end
    end
    setText("#mini-district", label or districtAt(player.x, player.y))
    ui:style("#mini-district", "color", labelColor and T.hex(labelColor) or T.hex(themeColor("text")))
    if waypoint then
        ui:style("#mini-wp", "visibility", "visible")
        if route then
            local remaining = math.max(0, route.length - nav.along)
            setText("#mini-wp-text", fmtDist(remaining) .. " · " .. fmtEta(remaining))
        else
            setText("#mini-wp-text", fmtDist(math.sqrt((waypoint.x - player.x) ^ 2 + (waypoint.y - player.y) ^ 2)))
        end
    else
        ui:style("#mini-wp", "visibility", "hidden")
    end
end

function N.navigate()
    if not waypoint or not player.valid then return end
    local g = cfg.gps or {}
    if not route then
        if now() - nav.lastAttempt > 2000 then computeRoute() end
        N.refreshNav()
        return
    end
    local pr = progressOn(player.x, player.y)
    nav.hint, nav.along = pr.index, pr.along
    local remaining = math.max(0, route.length - pr.along)
    local toDest = math.sqrt((waypoint.x - player.x) ^ 2 + (waypoint.y - player.y) ^ 2)
    local P = route.points
    local endGap = #P >= 3 and math.sqrt((P[#P - 2] - waypoint.x) ^ 2 + (P[#P - 1] - waypoint.y) ^ 2) or 0
    local arrive = tonumber(g.arriveDistance) or 22
    if now() - nav.lastProgress > 100 then
        nav.lastProgress = now()
        scene("set", { name = "route", progress = pr.along })
    end
    if (toDest < arrive or (remaining < arrive and toDest < arrive + endGap + 10)) and nav.arrivedFor ~= route.id then
        nav.arrivedFor = route.id
        toast(L("arrived"))
        emit(gpsRole(), "map3d:arrived", { x = waypoint.x, y = waypoint.y, distance = math.floor(toDest + 0.5) })
        setWaypoint(nil, true)
        return
    end
    -- off the route for a while: a new one
    if pr.off > (tonumber(g.rerouteDistance) or 38) then
        nav.offSince = nav.offSince or now()
        if now() - nav.offSince > (tonumber(g.rerouteDelay) or 1.2) * 1000 and now() - nav.lastRoute > 2500 then
            nav.offSince = nil
            toast(L("rerouting"))
            computeRoute()
        end
    else
        nav.offSince = nil
    end
    -- the next maneuver
    local nextM = nil
    for _, m in ipairs(route.maneuvers) do
        if m.at > pr.along + 4 and m.kind ~= "start" then nextM = m; break end
    end
    if nextM then
        local dist = fmtDist(nextM.at - pr.along)
        local label = L("m." .. nextM.kind)
        setRml("#mini-nav-icon", I.maneuver(nextM.kind))
        setText("#mini-nav-dist", dist)
        setText("#mini-nav-label", label)
        setRml("#rb-icon", I.maneuver(nextM.kind))
        setText("#rb-dist", dist)
        setText("#rb-label", label)
        setText("#rb-left", fmtDist(remaining))
        setText("#rb-eta", fmtEta(remaining))
    end
    N.refreshNav()
    if now() - nav.lastInfo > 500 then
        nav.lastInfo = now()
        emitRouteInfo({ active = true, remaining = math.floor(remaining + 0.5),
            next = nextM and { kind = nextM.kind, distance = math.floor(nextM.at - pr.along + 0.5) } or nil, off = math.floor(pr.off + 0.5) })
    end
end

-- ---------------------------------------------------------------------------
-- areas: drawn by the scene's overlay; labels anchored on the open map

local areaLabels = {}   -- id -> serial

-- the even-odd rule the scene draws with, on the page's flat outline
local function areaContains(a, x, y)
    local p, inside = a.pts, false
    local n = #p // 2
    local j = n
    for i = 1, n do
        local ax, ay, bx, by = p[i * 2 - 1], p[i * 2], p[j * 2 - 1], p[j * 2]
        if (ay > y) ~= (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax then inside = not inside end
        j = i
    end
    return inside
end

-- the centroid, or (concave outline) the middle of the widest span through it
local function areaLabelPoint(a)
    local p = a.pts
    local n = #p // 2
    local cx, cy = 0, 0
    for i = 1, n do cx, cy = cx + p[i * 2 - 1], cy + p[i * 2] end
    cx, cy = cx / n, cy / n
    if areaContains(a, cx, cy) then return cx, cy end
    local xs = {}
    local j = n
    for i = 1, n do
        local ax, ay, bx, by = p[i * 2 - 1], p[i * 2], p[j * 2 - 1], p[j * 2]
        if (ay > cy) ~= (by > cy) then xs[#xs + 1] = ax + (cy - ay) * (bx - ax) / (by - ay) end
        j = i
    end
    table.sort(xs)
    local best, bx = -1, cx
    for k = 1, #xs - 1, 2 do
        if xs[k + 1] - xs[k] > best then best, bx = xs[k + 1] - xs[k], (xs[k] + xs[k + 1]) / 2 end
    end
    return bx, cy
end
N.areaContains = areaContains

local function syncAreasNow()
    if not ui or not docLoaded then return end
    local list = {}
    for id, a in pairs(areas) do list[#list + 1] = { id = id, a = a } end
    table.sort(list, function(x, y) return (x.a.__seq or 0) < (y.a.__seq or 0) end)
    if #list > 16 then warn("areas16", "more than 16 areas: the newest 16 are drawn") end
    local items = {}
    for i = math.max(1, #list - 15), #list do
        local a = list[i].a
        if a.map ~= false or a.minimap ~= false then
            items[#items + 1] = { pts = a.pts, fill = a.fill, fillOpacity = a.fillOpacity, stroke = a.stroke, strokeWidth = a.strokeWidth,
                pattern = a.pattern, pulse = a.pulse }
        end
    end
    scene("areas", { items = items, hatch = (cfg.areas or {}).hatch or 11 })
    -- labels
    for id, serial in pairs(areaLabels) do
        if not areas[id] then ui:unanchor(serial); ui:remove(serial); areaLabels[id] = nil end
    end
    if (cfg.areas or {}).labels == false then return end
    for id, a in pairs(areas) do
        local serial = areaLabels[id]
        if a.label and a.label ~= "" and a.map ~= false then
            local color = T.hex(a.stroke or a.fill or "#ff2e3c")
            local rml = ('<div class="area-pill"><div style="decorator: fx(chamfer-solid 8 0 0 0 %s); color: #050506;">%s<span>%s</span></div></div>')
                :format(color, I.rml("warning"):gsub('class="ic ic%-line', 'style="stroke: #050506;" class="ic ic-line'), esc(a.label))
            if serial then ui:rml(serial, rml) else
                serial = ui:create("#full-areas", { tag = "div", class = "area-label", rml = rml })
                areaLabels[id] = serial
            end
            local lx, ly = a.lx, a.ly
            if not lx or not ly then lx, ly = areaLabelPoint(a) end
            ui:anchor(serial, { scene = SCENE, view = "full", point = { x = lx, y = ly, z = (a.lz or 20) + 2 }, transform = true })
        elseif serial then
            ui:unanchor(serial); ui:remove(serial); areaLabels[id] = nil
        end
    end
end

-- ---------------------------------------------------------------------------
-- influence zones: eased in Lua, drawn by the scene (ground field, beacons)

local zoneLabels = {}
local function zonesVisible() return influence.enabled and influenceAllowed and layerVisible("influence") end

function syncZones(snap)
    if not ui or not dataReady then return end
    local on = zonesVisible() and isOpen
    local items, beacons = {}, {}
    local colors = (cfg.influence or {}).colors or D.config.influence.colors
    local beaconLevel = tonumber((cfg.influence or {}).beaconLevel) or 2
    for id, z in pairs(zonesShown) do
        if on and z.alpha > 0.01 then
            items[#items + 1] = { x = z.x, y = z.y, radius = z.r, level = math.floor(z.level + 0.5), alpha = z.alpha }
            local lvl = math.floor(z.level + 0.5)
            if not perf and lvl >= beaconLevel then
                local r = clamp(z.r * 0.05, 5, 28)
                beacons[#beacons + 1] = { x = z.x, y = z.y, z = z.z or 0, sx = r * 2, sy = r * 2, sz = 120 + 90 * lvl,
                    color = T.hex(colors[clamp(lvl, 1, #colors)] or "#ffcc00", z.alpha) }
            end
        end
    end
    scene("zones", { items = items, colors = colors })
    scene("instances", { name = "beacons", mesh = "tube", items = beacons, beam = true, additive = true, unlit = true, beamBands = 8, layers = LAYER_FULL, order = 22 })
    -- labels
    local labels = (cfg.influence or {}).labels ~= false
    for id, z in pairs(zonesShown) do
        local serial = zoneLabels[id]
        if on and labels and z.alpha > 0.05 then
            local lvl = math.floor(z.level + 0.5)
            local color = T.hex(colors[clamp(lvl, 1, #colors)] or "#ffcc00")
            local levelInfo = (influence.levels or {})[lvl] or {}
            local count = ""
            if (cfg.influence or {}).showCount ~= false then
                count = ('<div class="zone-count" style="color: %s;">%d %s</div>'):format(color, z.count or 1, (z.count or 1) == 1 and L("player") or L("players"))
            end
            local rml = ('<div class="zone-stack" style="opacity: %.2f;">%s<div class="zone-pill" style="background-color: %s; color: #050506;">%s</div><div class="zone-stem" style="background-color: %s;"></div></div>')
                :format(z.alpha, count, color, esc(levelInfo.label or ("LEVEL " .. lvl)), color)
            if not serial then
                serial = ui:create("#full-zones", { tag = "div", class = "zone-label", rml = rml })
                zoneLabels[id] = serial
            elseif z.rml ~= rml then
                ui:rml(serial, rml)
            end
            z.rml = rml
            local h = (not perf and lvl >= beaconLevel) and (120 + 90 * lvl) or 40
            ui:anchor(serial, { scene = SCENE, view = "full", point = { x = z.x, y = z.y, z = (z.z or 0) + h }, transform = true })
        elseif serial then
            ui:unanchor(serial); ui:remove(serial); zoneLabels[id] = nil
        end
    end
end

local function easeZones(dt)
    local any = false
    for _, z in pairs(zonesShown) do
        local t = z.target
        local k = perf and 1 or ease(3, dt)
        if t then
            z.x, z.y, z.r, z.level = z.x + (t.x - z.x) * k, z.y + (t.y - z.y) * k, z.r + (t.radius - z.r) * k, z.level + (t.level - z.level) * k
            z.z, z.count = t.z or 0, t.count
            z.alpha = perf and 1 or (z.alpha + (1 - z.alpha) * ease(2.5, dt))
        else
            z.alpha = perf and 0 or (z.alpha - z.alpha * ease(4, dt))
        end
        if (t and (math.abs(z.alpha - 1) > 0.01 or math.abs(z.r - t.radius) > 0.5)) or (not t and z.alpha > 0.01) then any = true end
    end
    for id, z in pairs(zonesShown) do if not z.target and z.alpha <= 0.01 then zonesShown[id] = nil end end
    return any
end

local function setInfluence(p)
    local wasEnabled = influence.enabled
    influence = { enabled = p.enabled == true, zones = type(p.zones) == "table" and p.zones or {}, levels = type(p.levels) == "table" and p.levels or {} }
    local seen = {}
    for i, z in ipairs(influence.zones) do
        if i > 24 then break end
        local id = tostring(z.id or i)
        seen[id] = true
        local cur = zonesShown[id]
        local target = { x = z.x, y = z.y, z = z.z, radius = z.radius, level = math.max(1, z.level or 1), count = math.max(1, z.count or 1) }
        if cur then cur.target = target else
            zonesShown[id] = { x = z.x, y = z.y, z = z.z, r = z.radius * 0.6, level = target.level, alpha = 0, count = target.count, target = target }
        end
    end
    for id, z in pairs(zonesShown) do if not seen[id] then z.target = nil end end
    if wasEnabled ~= influence.enabled then refreshLegend() end
    applyMode()
end

-- ---------------------------------------------------------------------------
-- jamming

local function setJam(p)
    local s = clamp(tonumber(p and p.strength) or 0, 0, 1)
    jam = { strength = s, label = p and p.label }
    if not ui then return end
    rootClass("is-jamming", s > 0)
    rootClass("is-jammed", s >= 0.99)
    rootClass("has-jam-label", s >= 0.5)
    -- the page's dose: a dark veil 0.94 s, static .18 + .5 s, the sweep at s
    ui:style(".jam", { ["background-color"] = ("#08090c%02x"):format(math.floor(0.94 * s * 255)) })
    ui:style(".jam-noise", "opacity", ("%.2f"):format(0.18 + 0.5 * s))
    ui:style(".jam-sweep", "opacity", ("%.2f"):format(s))
    ui:text(".jam-text", p and p.label or L("noSignal"))
end

-- ---------------------------------------------------------------------------
-- legend, card, search

local function refreshLegendNow()
    if not ui or not docLoaded then return end
    local counts = {}
    for _, e in pairs(blips) do
        local c = e.b.category or "default"
        counts[c] = (counts[c] or 0) + 1
    end
    local rows = {}
    for i, c in ipairs(cfg.categories or {}) do
        local color = T.hex(c.color or themeColor("accent"))
        local icon = I.rml(c.icon or "pin"):gsub('class="ic', ('style="stroke: %s; fill: %s;" class="ic'):format(color, color), 1)
        -- a filled icon keeps no stroke, a line icon no fill
        icon = icon:gsub("ic%-line\"", "ic-line\""):gsub('fill: ' .. color .. ';" class="ic ic%-line', 'fill: transparent;" class="ic ic-line')
        icon = icon:gsub('stroke: ' .. color .. '; fill: ' .. color .. ';" class="ic ic%-fill', 'stroke: transparent; fill: ' .. color .. ';" class="ic ic-fill')
        rows[#rows + 1] = ('<div id="cat-%d" class="cat%s">%s<span class="cat-label">%s</span><span class="cat-count">%d</span></div>')
            :format(i, catHidden(c.id) and " is-off" or "", icon, esc(c.label or c.id), counts[c.id] or 0)
    end
    ui:rml("#lg-cats", table.concat(rows))
    ui:text("#lg-cat-title", L("legend"):upper())
    ui:text("#lg-display-title", L("display"))
    ui:text("#q-perf", L("performance"))
    ui:text("#q-quality", L("quality"))
    local function tog(id, label, on)
        return ('<div id="%s" class="tog %s"><span class="tog-label">%s</span><span class="tog-state">%s</span></div>'):format(id, on and "is-on" or "is-off", esc(label), on and "ON" or "OFF")
    end
    ui:rml("#lg-hud", tog("tog-hud-minimap", L("minimap"), (prefs.hud or {}).minimap ~= false))
    local layers = tog("tog-layer-buildings", L("buildings"), layerVisible("buildings")) .. tog("tog-layer-roadBorders", L("roadLines"), layerVisible("roadBorders"))
        .. tog("tog-layer-metro", L("metro"), layerVisible("metro")) .. tog("tog-layer-labels", L("districts"), layerVisible("labels"))
    local zones = ""
    if influence.enabled then
        layers = layers .. tog("tog-layer-influence", L("influence"), layerVisible("influence"))
        local colors = (cfg.influence or {}).colors or D.config.influence.colors
        local levels = influence.levels and #influence.levels > 0 and influence.levels or nil
        local chips = {}
        for i = 1, levels and #levels or #colors do
            local color = T.hex(colors[clamp(i, 1, #colors)] or "#ffcc00")
            local l = levels and levels[i] or { label = tostring(i), min = i }
            chips[#chips + 1] = ('<div class="lvl"><div class="lvl-bar" style="background-color: %s; filter: glow(4dp %s 1);"></div><div class="lvl-name">%s</div><div class="lvl-min">%s+</div></div>')
                :format(color, color, esc(l.label), tostring(l.min or i))
        end
        zones = '<div class="levels">' .. table.concat(chips) .. "</div>"
    end
    ui:rml("#lg-layers", layers)
    ui:rml("#lg-zones", zones)
end

local function blipDistance(b)
    if not player.valid then return nil end
    return math.sqrt((b.x - player.x) ^ 2 + (b.y - player.y) ^ 2)
end

function N.select(id)
    selected = id
    if not ui then return end
    local entry = id and blips[id]
    if not entry then ui:class("#card", "is-on", false); return end
    local b = entry.b
    local cat = categoryOf(b.category or "default")
    local color = T.hex(blipColor(b))
    ui:rml("#card-icon", (I.rml(b.icon or "pin"):gsub('class="ic', ('style="stroke: %s;" class="ic'):format(color), 1)))
    ui:text("#card-cat", ((cat and cat.label) or "PLACE"):upper())
    ui:text("#card-name", b.label or "Location")
    ui:text("#card-desc", b.description or "")
    ui:style("#card-desc", "display", (b.description and b.description ~= "") and "block" or "none")
    local d = blipDistance(b)
    ui:text("#card-dist", d and fmtDist(d) or "--")
    ui:text("#card-district", districtAt(b.x, b.y))
    local routable = b.routable ~= false and (cfg.gps or {}).enabled ~= false
    ui:style("#card-btn", "display", routable and "flex" or "none")
    local isDest = waypoint and math.abs(waypoint.x - b.x) < 1 and math.abs(waypoint.y - b.y) < 1
    ui:class("#card-btn", "is-clear", isDest == true)
    ui:rml("#card-btn", isDest and ("<span>" .. esc(L("clearRoute")) .. "</span>") or ("<span>" .. esc(L("setRoute")) .. '</span><span class="kbd">G</span>'))
    ui:class("#card", "is-on", true)
end

local function routeToSelected()
    local entry = selected and blips[selected]
    if not entry or entry.b.routable == false then return end
    local b = entry.b
    if waypoint and math.abs(waypoint.x - b.x) < 1 and math.abs(waypoint.y - b.y) < 1 then setWaypoint(nil, true)
    else setWaypoint({ x = b.x, y = b.y, z = b.z or 0 }, true) end
end

local function flyTo(pos, distance, pitch)
    local spec = { view = "full", target = { x = pos.x, y = pos.y, z = pos.z or 20 }, duration = 0.7 }
    if perf then spec.height = (distance or fullCam.distance) * 0.7677 else spec.distance = distance end
    if pitch and not perf then spec.pitch = pitch end
    scene("camera", spec)
end

local function score(text, words)
    text = text:lower()
    local total = 0
    for _, w in ipairs(words) do
        local at = text:find(w, 1, true)
        if not at then return 0 end
        total = total + ((at == 1 or text:sub(at - 1, at - 1) == " ") and 2 or 1)
    end
    return total
end

local function runSearch(query)
    query = tostring(query or ""):lower()
    local words = {}
    for w in query:gmatch("%S+") do words[#words + 1] = w end
    local list = {}
    for id, e in pairs(blips) do
        local b = e.b
        if id ~= "__player" and id ~= "__waypoint" and b.map ~= false and not catHidden(b.category or "default") then
            local cat = categoryOf(b.category or "default")
            local district = districtAt(b.x, b.y)
            local s = #words == 0 and 1 or (score(b.label or "", words) * 3 + score(table.concat({ b.label or "", b.description or "", cat and cat.label or "", district }, " "), words))
            if s > 0 then list[#list + 1] = { kind = "blip", id = id, b = b, score = s, dist = blipDistance(b) or 0, district = district, cat = cat } end
        end
    end
    if #words > 0 and manifest and type(manifest.districts) == "table" then
        for key, d in pairs(manifest.districts) do
            local name = D.districts[key] or tostring(key):upper()
            local s = score(name, words)
            local c = d.center or d.centre or d
            if s > 0 and tonumber(c.x or c[1]) then
                local x, y = tonumber(c.x or c[1]), tonumber(c.y or c[2])
                list[#list + 1] = { kind = "district", name = name, x = x, y = y, score = s * 3 + 1,
                    dist = player.valid and math.sqrt((x - player.x) ^ 2 + (y - player.y) ^ 2) or 0 }
            end
        end
    end
    table.sort(list, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.dist < b.dist end)
    searchResults = {}
    for i = 1, math.min(8, #list) do searchResults[i] = list[i] end
    searchSel = 1
    N.renderResults()
end

function N.renderResults()
    if #searchResults == 0 then ui:rml("#results", ('<div class="res-empty">%s</div>'):format(esc(L("noResults")))); return end
    local rows = {}
    for i, r in ipairs(searchResults) do
        local icon, name, sub
        if r.kind == "blip" then
            local color = T.hex(blipColor(r.b))
            icon = (I.rml(r.b.icon or "pin"):gsub('class="ic', ('style="stroke: %s;" class="ic'):format(color), 1))
            name = r.b.label or "Location"
            sub = (((r.cat and r.cat.label) or "Place") .. " · " .. r.district):upper()
        else
            icon, name, sub = I.rml("district"), r.name, L("district"):upper()
        end
        rows[#rows + 1] = ('<div id="res-%d" class="res%s">%s<div class="res-main"><div class="res-name">%s</div><div class="res-sub">%s</div></div><span class="res-dist">%s</span></div>')
            :format(i, i == searchSel and " is-sel" or "", icon, esc(name), esc(sub), player.valid and fmtDist(r.dist) or "")
    end
    ui:rml("#results", table.concat(rows))
end

local function pickResult(i)
    local r = searchResults[i]
    if not r then return end
    ui:blurElement("#search-input")
    if r.kind == "blip" then
        N.select(r.id)
        flyTo(r.b, 650)
    else
        flyTo({ x = r.x, y = r.y, z = 20 }, 1800)
    end
end

function applyMode() dirty.mode = true end
function refreshLegend() dirty.legend = true end
function syncAreas() dirty.areas = true end

--- The frame loop's share of the UI work.
local function flush()
    if dirty.theme then dirty.theme = false; applyTheme(); applySceneStyle() end
    if dirty.layout then dirty.layout = false; placeMinimap(); syncTexts() end
    if dirty.blips then
        local mode = dirty.blips
        dirty.blips = false
        syncBlipsNow(mode == "rebuild")
    end
    -- element work: a bounded number of blips per frame
    local n = 0
    while #blipQueueOrder > 0 and n < 24 do
        local id = table.remove(blipQueueOrder, 1)
        local def = blipQueue[id]
        blipQueue[id] = nil
        if def then upsertBlipNow(def) else removeBlipNow(id) end
        n = n + 1
        if #blipQueueOrder == 0 and isOpen then dirty.legend = true end
    end
    if dirty.areas then dirty.areas = false; syncAreasNow() end
    if dirty.mode then dirty.mode = false; applyModeNow() end
    if dirty.legend and isOpen then dirty.legend = false; refreshLegendNow() end
end

-- ---------------------------------------------------------------------------
-- the open map

local function openMap(focus)
    if isOpen then return end
    isOpen = true
    closingUntil = 0
    if not ui then return end
    ui:setZIndex(60)
    rootClass("is-closing", false)
    rootClass("is-opening", true)
    CreateThread(function() Wait(560); if isOpen then rootClass("is-opening", false) end end)
    -- the camera: the saved view, or a flight from above the camera's way to the focus
    local f = (focus and type(focus.x) == "number") and { x = focus.x, y = focus.y, z = focus.z or player.z or 20 } or (player.valid and { x = player.x, y = player.y, z = player.z } or nil)
    if dataReady and f then
        local camYaw = player.camYaw or 0
        if savedView then
            local pitch = perf and 89.9 or (90 - math.deg(tonumber(savedView.pitch) or math.rad(42)))
            scene("camera", { view = "full", target = f, distance = savedView.distance, height = savedView.distance * 0.7677,
                yaw = math.deg(tonumber(savedView.yaw) or 0), pitch = clamp(pitch, 18, 89.9), animate = false })
        else
            local a = math.rad(camYaw)
            scene("camera", { view = "full", target = { x = f.x - math.sin(a) * 400, y = f.y + math.cos(a) * 400, z = f.z }, distance = 260, height = 200,
                yaw = camYaw, pitch = perf and 89.9 or 48, animate = false })
            local d = (tonumber((cfg.map or {}).initialDistance) or 2600) * 0.45
            scene("camera", { view = "full", target = f, distance = d, height = d * 0.7677, yaw = camYaw, pitch = perf and 89.9 or 48, duration = 0.9 })
        end
    end
    askPick = quality
    refreshLegend()
    applyMode()
    syncZones(true)
end

local function closeMap()
    if not isOpen then return end
    isOpen = false
    typing = false
    keysHeld = {}
    -- the view comes back next time (TS convention: pitch from straight down, radians)
    local pitch = perf and (savedView and savedView.pitch or math.rad(42)) or math.rad(90 - (fullCam.pitch or 48))
    savedView = { distance = fullCam.distance, yaw = math.rad(fullCam.yaw or 0), pitch = pitch }
    kvpSet(VIEW_KEY, savedView)
    if ui then
        ui:blurElement("#search-input")
        ui:class("#search", "is-active", false)
        rootClass("is-closing", true)
        closingUntil = now() + 240
        CreateThread(function()
            Wait(250)
            if not isOpen then rootClass("is-closing", false); if ui then ui:setZIndex(40) end; applyMode() end
        end)
    end
    N.select(nil)
    applyMode()
end

-- ---------------------------------------------------------------------------
-- input on the open map

local function readFullCam()
    local s = ui and ui:sceneState(SCENE)
    local v = s and s.views and s.views.full
    if type(v) == "table" then
        fullCam.yaw, fullCam.pitch = v.yaw or fullCam.yaw, v.pitch or fullCam.pitch
        fullCam.distance = (v.mode == "ortho" and (v.height or 0) / 0.7677) or v.distance or fullCam.distance
        if type(v.target) == "table" then fullCam.target = v.target end
        fullCam.moving = v.moving
    end
end

local function zoomBy(k)
    readFullCam()
    local mp = cfg.map or {}
    local d = clamp(fullCam.distance * k, tonumber(mp.minDistance) or 60, tonumber(mp.maxDistance) or 11000)
    scene("camera", { view = "full", distance = d, height = d * 0.7677, duration = 0.5 })
end

local function recenter()
    if not player.valid then return end
    readFullCam()
    flyTo(player, math.min(fullCam.distance, 900))
end

local function northUp()
    readFullCam()
    local yaw = fullCam.yaw or 0
    scene("camera", { view = "full", yaw = math.floor(yaw / 360 + 0.5) * 360, duration = 0.6 })
end

local function togglePitch()
    if perf then return end
    readFullCam()
    -- TS: pitch > 0.15 rad from straight down -> straight down, else 42 degrees
    local fromDown = math.rad(90 - (fullCam.pitch or 48))
    scene("camera", { view = "full", pitch = fromDown > 0.15 and 89.9 or 48, duration = 0.6 })
end

local MOVE = { w = true, s = true, a = true, d = true, up = true, down = true, left = true, right = true, q = true, e = true, r = true, f = true,
    equals = true, minus = true, add = true, subtract = true }

function N.bindInput()
    ui:on("click", "#close", function() emit("full", "map3d:close", {}) end)
    ui:on("click", "#rb-clear", function() setWaypoint(nil, true) end)
    ui:on("click", "#card-btn", routeToSelected)
    ui:on("click", "#t-in", function() zoomBy(0.6) end)
    ui:on("click", "#t-out", function() zoomBy(1.6) end)
    ui:on("click", "#t-north", northUp)
    ui:on("click", "#t-pitch", togglePitch)
    ui:on("click", "#t-center", recenter)
    ui:on("click", "#q-perf", function() setQuality("performance", false) end)
    ui:on("click", "#q-quality", function() setQuality("quality", false) end)
    ui:on("click", "#qc-performance", function() setQuality("performance", true) end)
    ui:on("click", "#qc-quality", function() setQuality("quality", true) end)
    ui:on("mouseover", "#qc-performance", function() askPick = "performance"; applyMode() end)
    ui:on("mouseover", "#qc-quality", function() askPick = "quality"; applyMode() end)
    ui:on("click", ".cat", function(e)
        local i = tonumber(tostring(e.id or ""):match("cat%-(%d+)"))
        local c = i and (cfg.categories or {})[i]
        if not c then return end
        local list, found = {}, false
        for _, id in ipairs(prefs.hiddenCats or {}) do if id == c.id then found = true else list[#list + 1] = id end end
        if not found then list[#list + 1] = c.id end
        prefs.hiddenCats = list
        savePrefs()
        syncBlips(false)
        refreshLegend()
    end)
    ui:on("click", ".tog", function(e)
        local group, key = tostring(e.id or ""):match("tog%-(%a+)%-(%a+)")
        if not group then return end
        local t = group == "hud" and prefs.hud or prefs.layers
        t[key] = (t[key] == false)
        savePrefs()
        refreshLegend()
        applyMode()
        if key == "labels" then ui:style("#full-districts", "visibility", layerVisible("labels") and "visible" or "hidden") end
    end)
    ui:on("click", ".blip", function(e)
        if not isOpen then return end
        local serial = "@" .. tostring(math.floor(tonumber(e.serial) or 0))
        for id, entry in pairs(blips) do
            if entry.full == serial and id ~= "__player" then
                N.select(id)
                emit("full", "map3d:blipClick", { id = id })
                return
            end
        end
    end)
    ui:on("click", ".res", function(e)
        local i = tonumber(tostring(e.id or ""):match("res%-(%d+)"))
        if i then pickResult(i) end
    end)
    ui:on("scenepick", "#full-view", function(e)
        if not isOpen or asking then return end
        local mp = cfg.map or {}
        if e.double and mp.doubleClickWaypoint ~= false and (tonumber(e.button) or 0) == 0 then
            setWaypoint({ x = e.x, y = e.y, z = e.z }, true)
        elseif (tonumber(e.button) or 0) == 1 and mp.rightClickWaypoint then
            setWaypoint({ x = e.x, y = e.y, z = e.z }, true)
        elseif not e.double and (tonumber(e.button) or 0) == 0 then
            N.select(nil)
        end
    end)
    ui:on("scenehover", "#full-view", function(e)
        if not isOpen or (cfg.map or {}).showCoordinates == false then return end
        lastHover = e
        ui:text("#ro-x", ("X %d"):format(math.floor(e.x + 0.5)))
        ui:text("#ro-y", ("Y %d"):format(math.floor(e.y + 0.5)))
        ui:text("#ro-d", districtAt(e.x, e.y))
    end)
    ui:on("focus", "#search-input", function(e)
        typing = true
        ui:class("#search", "is-active", true)
        emit("full", "map3d:typing", { active = true })
        runSearch(e.value or "")
    end)
    ui:on("blur", "#search-input", function()
        typing = false
        ui:class("#search", "is-active", false)
        emit("full", "map3d:typing", { active = false })
    end)
    ui:on("change", "#search-input", function(e)
        if not typing then return end
        -- the "/" that opened the search lands in the box too: drop it
        if e.value == "/" or e.value == ":" then ui:value("#search-input", ""); runSearch(""); return end
        runSearch(e.value or "")
    end)
    ui:on("keydown", function(e)
        if not isOpen then return end
        local key = tostring(e.key or "")
        emit("full", "map3d:log", { message = ("key %s"):format(key) })
        if typing then
            if key == "down" then searchSel = searchSel % math.max(1, #searchResults) + 1; N.renderResults()
            elseif key == "up" then searchSel = (searchSel - 2) % math.max(1, #searchResults) + 1; N.renderResults()
            elseif key == "return" or key == "enter" then pickResult(searchSel)
            elseif key == "escape" then
                if (e.value or "") ~= "" then ui:value("#search-input", ""); runSearch("") else ui:blurElement("#search-input") end
            end
            return
        end
        if asking then
            if key == "1" then setQuality("performance", true)
            elseif key == "2" then setQuality("quality", true)
            elseif key == "left" or key == "right" or key == "tab" then askPick = askPick == "performance" and "quality" or "performance"; applyMode()
            elseif key == "return" or key == "enter" then setQuality(askPick, true)
            elseif key == "escape" or key == "m" then emit("full", "map3d:close", {}) end
            return
        end
        if key == "escape" or key == "m" then emit("full", "map3d:close", {})
        elseif key == "slash" or key == "divide" or (key == "f" and e.ctrl_key) then if (cfg.map or {}).search ~= false then ui:focusElement("#search-input") end
        elseif key == "space" then recenter()
        elseif key == "n" then northUp()
        elseif key == "g" then routeToSelected()
        elseif key == "delete" or key == "back" or key == "backspace" then setWaypoint(nil, true)
        elseif MOVE[key] then keysHeld[key] = true end
    end)
    ui:on("keyup", function(e) keysHeld[tostring(e.key or "")] = nil end)
end

local function moveWithKeys(dt)
    if not next(keysHeld) or typing or asking then return end
    readFullCam()
    local d = fullCam.distance
    local yaw = math.rad(fullCam.yaw or 0)
    -- screen forward on the ground (game axes): the camera looks along -(sin yaw, cos yaw) in scene x/z = game (x, -y)
    local fx, fy = -math.sin(yaw), math.cos(yaw)
    local rx, ry = math.cos(yaw), math.sin(yaw)
    local mf = ((keysHeld.w or keysHeld.up) and 1 or 0) - ((keysHeld.s or keysHeld.down) and 1 or 0)
    local mr = ((keysHeld.d or keysHeld.right) and 1 or 0) - ((keysHeld.a or keysHeld.left) and 1 or 0)
    local spec = { view = "full", duration = 0.15 }
    if mf ~= 0 or mr ~= 0 then
        local k = d * 0.9 * dt
        local t = fullCam.target
        spec.target = { x = t.x + (fx * mf + rx * mr) * k, y = t.y + (fy * mf + ry * mr) * k, z = t.z }
    end
    local dyaw = ((keysHeld.q and 1 or 0) - (keysHeld.e and 1 or 0)) * math.deg(1.4) * dt
    if dyaw ~= 0 then spec.yaw = fullCam.yaw + dyaw end
    local dp = ((keysHeld.r and 1 or 0) - (keysHeld.f and 1 or 0)) * math.deg(0.9) * dt
    if dp ~= 0 and not perf then spec.pitch = clamp(fullCam.pitch - dp, 18, 89.9) end
    local z = ((keysHeld.equals or keysHeld.add) and 1 or 0) - ((keysHeld.minus or keysHeld.subtract) and 1 or 0)
    if z ~= 0 then
        local nd = clamp(d * (1 - 1.6 * dt * z), tonumber((cfg.map or {}).minDistance) or 60, tonumber((cfg.map or {}).maxDistance) or 11000)
        spec.distance, spec.height = nd, nd * 0.7677
    end
    scene("camera", spec)
end

-- ---------------------------------------------------------------------------
-- per frame: the minimap camera follows the player

local function updateMini(dt)
    if not player.valid or not dataReady then return end
    local m = cfg.minimap or {}
    if zoomDir ~= 0 then miniZoom = clamp(miniZoom * math.exp(-zoomDir * dt * 1.4), 0.35, 3) end
    local age = math.min(0.1, (now() - player.t) / 1000)
    local px, py = player.x + player.vx * age, player.y + player.vy * age
    local speedK = clamp((player.speed - 8) / 32, 0, 1)
    local vr = tonumber(m.vehicleRadius) or 250
    local radius = (player.vehicle and (vr * 0.8 + (vr - vr * 0.8) * speedK) or (tonumber(m.radius) or 150)) * miniZoom
    local tilt = player.vehicle and (tonumber(m.vehicleTilt) or 54) or (tonumber(m.tilt) or 10)
    if perf then tilt = 0 end
    local yaw = 0
    if m.rotate ~= false then yaw = (player.vehicle and m.vehicleFollow == "vehicle") and player.yaw or player.camYaw end
    local c = miniCam
    if not c then
        c = { x = px, y = py, z = player.z, yaw = yaw, radius = radius, tilt = tilt }
        miniCam = c
    end
    local settling = math.abs(px - c.x) + math.abs(py - c.y) > 0.03 or math.abs(angleDelta(c.yaw, yaw)) > 0.2
        or math.abs(radius - c.radius) > 0.5 or math.abs(tilt - c.tilt) > 0.2 or player.speed > 0.2 or zoomDir ~= 0 or not c.sent
    if not settling then return end
    c.x = c.x + (px - c.x) * ease(16, dt)
    c.y = c.y + (py - c.y) * ease(16, dt)
    c.z = c.z + (player.z - c.z) * ease(8, dt)
    c.yaw = c.yaw + angleDelta(c.yaw, yaw) * ease(12, dt)
    c.radius = c.radius + (radius - c.radius) * ease(2.5, dt)
    c.tilt = c.tilt + (tilt - c.tilt) * ease(2.5, dt)
    c.sent = true
    local dist = c.radius / math.tan(math.rad(24))
    local ahead = c.radius * (0.1 + (0.32 - 0.1) * clamp((c.tilt - 10) / 44, 0, 1))
    local a = math.rad(c.yaw)
    local tx, ty = c.x - math.sin(a) * ahead, c.y + math.cos(a) * ahead
    ui:batch(function()
        scene("camera", { view = "mini", target = { x = tx, y = ty, z = c.z }, distance = dist, height = c.radius * 2,
            yaw = c.yaw, pitch = 90 - c.tilt, animate = false })
        if not perf and (tonumber(m.xray) or 70) > 0 then
            scene("view", { view = "mini", xray = { x = c.x, y = c.y, z = c.z + 1.5, radius = tonumber(m.xray) or 70 } })
        end
        if miniSelf then
            ui:anchor(miniSelf, { scene = SCENE, view = "mini", point = { x = c.x, y = c.y, z = c.z + 2 }, heading = player.heading, rotate = ".arrow", transform = true, priority = 2 })
        end
    end)
end


local lastSlow, perfSamples, lastPerf = 0, {}, 0
local function slowTick()
    -- 10 per second: what follows the open map's camera
    if not isOpen or not ui then return end
    readFullCam()
    ui:class("#full-blips", "near", fullCam.distance < 1800)
    ui:class("#full-districts", "far-off", fullCam.distance <= 1400)
    ui:style("#t-north-n", "transform", ("rotate(%.1fdeg)"):format(fullCam.yaw or 0))
    ui:text("#t-pitch-t", (math.rad(90 - (fullCam.pitch or 48)) > 0.15) and L("view2d") or L("view3d"))
    -- the terrain grid: 100 m close, 1000 m far
    local grid = (perf or fullCam.distance > 2200) and 1000 or 100
    if grid ~= N.grid then N.grid = grid; scene("set", { name = "world/terrain", grid = grid }) end
    if waypoint and math.abs((N.destD or 0) - fullCam.distance) > fullCam.distance * 0.1 then N.destD = fullCam.distance; syncDestination() end
end

local function perfTick()
    if not isOpen or not ui then return end
    local st = ui:state()
    local p = st and st.perf
    if type(p) ~= "table" then return end
    perfSamples[#perfSamples + 1] = tonumber(p.frameMs) or 0
    if #perfSamples > 40 then table.remove(perfSamples, 1) end
    ui:text("#pf-fps", ("%d"):format(math.floor((tonumber(p.fps) or 0) + 0.5)))
    ui:text("#pf-frame", ("%.1f ms"):format(tonumber(p.frameMs) or 0))
    ui:text("#pf-cpu", ("%.2f ms"):format((tonumber(p.updateMs) or 0) + (tonumber(p.renderMs) or 0)))
    local draws = tonumber(p.sceneDraws) or 0
    ui:text("#pf-scene", draws == 0 and ("still: nothing redrawn · %.0f MB"):format(tonumber(p.sceneGpuMB) or 0)
        or ("%d draws · %dk instances · %.0f MB"):format(draws, math.floor((tonumber(p.sceneInstances) or 0) / 1000), tonumber(p.sceneGpuMB) or 0))
    local maxMs = 1
    for _, v in ipairs(perfSamples) do if v > maxMs then maxMs = v end end
    local parts = {}
    for i, v in ipairs(perfSamples) do
        parts[#parts + 1] = ("%s%.1f %.1f"):format(i == 1 and "M" or "L", (i - 1) * 5, 21 - v / maxMs * 20)
    end
    ui:rml("#pf-spark", ('<path view-box="0 0 200 22" preserve-aspect="none" d="%s"/>'):format(table.concat(parts, " ")))
end

CreateThread(function()
    local last = now()
    while true do
        Wait(0)
        local t = now()
        local dt = math.min(0.1, (t - last) / 1000)
        last = t
        if ui and docLoaded then flush() end
        if ui and dataReady then
            if miniShown and not isOpen then updateMini(dt) end
            if isOpen then
                moveWithKeys(dt)
                if easeZones(dt) or N.zonesDirty then N.zonesDirty = false; syncZones() end
                if t - lastSlow > 100 then lastSlow = t; slowTick() end
                if t - lastPerf > 250 then lastPerf = t; perfTick() end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- the page protocol (client/main.lua)

local function canonical(role) return role == "full" or (role == "mini" and not adapters.full) end

local function onPlayer(p)
    local t = now()
    local x, y = tonumber(p.x), tonumber(p.y)
    if not x or not y then return end
    local dtu = (t - player.t) / 1000
    if player.valid and dtu > 0.005 and dtu < 0.5 then
        player.vx = player.vx * 0.5 + (x - player.x) / dtu * 0.5
        player.vy = player.vy * 0.5 + (y - player.y) / dtu * 0.5
    else
        player.vx, player.vy = 0, 0
    end
    local first = not player.valid
    player.x, player.y = x, y
    player.z = tonumber(p.z) or player.z
    player.yaw = tonumber(p.yaw) or player.yaw
    player.camYaw = tonumber(p.camYaw) or player.yaw
    player.speed = tonumber(p.speed) or 0
    player.vehicle = p.vehicle == true
    player.t = t
    player.valid = true
    -- the arrow turns the shortest way, most of the way per update
    local d = angleDelta(player.heading, player.yaw)
    player.heading = math.abs(d) > 120 and player.yaw or player.heading + d * 0.55
    if first then applyMode() end -- the minimap waits for a body in the world
    selfBlip()
    N.navigate()
    -- the line under the minimap (district, area, waypoint distance) a few times a second
    if not waypoint and ui and docLoaded and t - (N.lastInfoLine or 0) > 250 then
        N.lastInfoLine = t
        N.refreshNav()
    end
end

function N.receive(role, name, p)
    p = type(p) == "table" and p or {}
    if name == "map3d:role" or name == "map3d:holo" or name == "map3d:prefs" then return end -- (holo: older callers)
    if name == "map3d:miniZoom" then
        if role ~= "mini" then return end
        local dir = tonumber(p.dir) or 0
        if p.down then
            zoomDir = dir
            miniZoom = clamp(miniZoom * (dir > 0 and 0.88 or 1.14), 0.35, 3)
        elseif zoomDir == dir then
            zoomDir = 0
            kvpSet(ZOOM_KEY, { value = miniZoom })
        end
        return
    end
    if name == "map3d:open" then if role == "full" then openMap(p) end return end
    if name == "map3d:close" then if role == "full" then closeMap() end return end
    if not canonical(role) then return end
    if name == "map3d:quality" then
        if p.mode == "performance" or p.mode == "quality" then setQuality(p.mode, nil, p.chosen ~= false) end
    elseif name == "map3d:config" or name == "map3d:theme" then
        local patch = name == "map3d:theme" and { theme = p } or p
        local themeBefore = Open77.json.encode(cfg.theme)
        if type(patch.categories) == "table" then cfg.categories = D.copy(patch.categories) end
        D.merge(cfg, patch)
        if Open77.json.encode(cfg.theme) ~= themeBefore then
            dirty.theme = true
            syncBlips(true)
        end
        dirty.layout = true
        refreshLegend()
        applyMode()
    elseif name == "map3d:minimap" then
        minimapVisible = p.visible ~= false
        applyMode()
    elseif name == "map3d:player" then
        onPlayer(p)
    elseif name == "map3d:blips" then
        if p.set then
            local keep = {}
            for _, b in ipairs(p.set) do if b.id ~= nil then keep[tostring(b.id)] = true end end
            for id in pairs(blips) do if not keep[id] and id ~= "__player" and id ~= "__waypoint" then removeBlip(id) end end
            for _, b in ipairs(p.set) do upsertBlip(b) end
        end
        for _, b in ipairs(p.upsert or {}) do upsertBlip(b) end
        for _, id in ipairs(p.remove or {}) do removeBlip(id) end
        if isOpen then refreshLegend() end
    elseif name == "map3d:blip" then
        upsertBlip(p)
        if isOpen then refreshLegend() end
    elseif name == "map3d:blipRemove" then
        removeBlip(p.id)
        if isOpen then refreshLegend() end
    elseif name == "map3d:area" then
        local a = p
        if a.id ~= nil and type(a.pts) == "table" and #a.pts >= 6 then
            areaSeq = areaSeq + 1
            a.__seq = (areas[tostring(a.id)] and areas[tostring(a.id)].__seq) or areaSeq
            areas[tostring(a.id)] = a
            syncAreas()
        end
    elseif name == "map3d:areas" then
        if p.clear then areas = {} end
        for _, id in ipairs(p.remove or {}) do areas[tostring(id)] = nil end
        syncAreas()
    elseif name == "map3d:waypoint" or name == "map3d:route" then
        setWaypoint(type(p.x) == "number" and p or nil, false)
    elseif name == "map3d:focus" then
        if type(p.x) == "number" then readFullCam(); flyTo(p, p.distance or math.min(fullCam.distance, 700)) end
    elseif name == "map3d:jam" then
        setJam(p)
    elseif name == "map3d:influence" then
        setInfluence(p)
    elseif name == "map3d:influenceVisible" then
        influenceAllowed = p.visible ~= false
        refreshLegend()
        applyMode()
    end
end

local function setShown(role, on)
    if role == "mini" then
        miniShown = on
        if on then miniCam = miniCam and { x = miniCam.x, y = miniCam.y, z = miniCam.z, yaw = miniCam.yaw, radius = miniCam.radius, tilt = miniCam.tilt } end
        applyMode()
    elseif role == "full" then
        fullShown = on
    end
end

--- A surface for client/main.lua: the page API it always used, on the native document.
function N.surface(role, options)
    loadPrefs()
    if not ensureDocument() then return nil, "nativeui_unavailable" end
    handlers[role] = handlers[role] or {}
    local a = { role = role }
    function a.send(_, name, payload) N.receive(role, name, payload) end
    function a.on(_, name, fn) handlers[role][name] = fn end
    function a.show() setShown(role, true) end
    function a.hide() setShown(role, false) end
    function a.setFocus(_, keyboard, cursor)
        if role ~= "full" or not ui then return true end
        if keyboard or cursor then ui:focus({ keyboard = true, cursor = true }) else ui:blur() end
        return true
    end
    function a.setConsumedKeys() return true end
    function a.destroy()
        setShown(role, false)
        adapters[role] = nil
        handlers[role] = nil
    end
    adapters[role] = a
    if options and options.visible then setShown(role, true) end
    CreateThread(function()
        while not docLoaded do Wait(50) end
        if adapters[role] ~= a then return end
        if role == "mini" then ensureMiniSelf() end
        syncBlips(false)
        emit(role, "map3d:hello", {})
        if dataReady then emit(role, "map3d:ready", readyInfo()) end
    end)
    return a
end

function N.shutdown()
    if ui then pcall(ui.destroy, ui) end
    ui = nil
end
