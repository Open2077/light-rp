-- The native map's defaults (the WebUI page's config.ts DEFAULT_CONFIG): the
-- resource's config (shared/config.lua page) and setConfig patches merge over it.
Map3DDefaults = {}
local D = Map3DDefaults

D.config = {
    theme = {
        background = "#17191f", terrain = "#1f2128", terrainGrid = "#ffcc00", water = "#0e1015", waterLine = "#4d5260",
        road = "#41444f", roadEdge = "#ffcc00", metro = "#8a6900", building = "#3a3d4a", buildingTop = "#666a7d",
        buildingEdge = "#ffcc00", landmark = "#ffcc00", accent = "#ffcc00", accentSoft = "rgba(255, 204, 0, 0.22)",
        text = "#f2f3f5", textDim = "#8a8f9c", panel = "rgba(6, 6, 8, 0.82)", danger = "#ff2e3c", fog = 0.35,
    },
    minimap = {
        enabled = true, anchor = "top-right", size = 264, margin = { 32, 26 }, shape = "chamfer",
        tilt = 10, vehicleTilt = 54, vehicleFollow = "camera", rotate = true, radius = 150, vehicleRadius = 250,
        fps = 60, supersample = 1.75, xray = 70, showRoute = true, showLabels = false,
    },
    map = {
        initialDistance = 2600, minDistance = 60, maxDistance = 11000, initialPitch = 42, maxPitch = 72,
        buildings = true, roadBorders = true, districtLabels = true, showCoordinates = true,
        doubleClickWaypoint = true, rightClickWaypoint = false, title = "NIGHT CITY", subtitle = "CITY MAP",
        resolution = 1, idleFps = 30, search = true,
    },
    gps = {
        enabled = true, rerouteDistance = 38, rerouteDelay = 1.2, arriveDistance = 22, snapMainNetwork = true,
        avoidHighways = false, units = "metric", routeWidth = 1, animationSpeed = 1.6,
    },
    influence = { colors = { "#3FE0D0", "#FFCC00", "#FF8A1F", "#FF2E3C" }, labels = true, showCount = true, buildings = true, beaconLevel = 2 },
    areas = { labels = true, hatch = 11, minimapHatch = 9, minimapStrength = 0.85, minimapLabel = true },
    categories = {
        { id = "player", label = "Players", icon = "user" },
        { id = "service", label = "Services", icon = "store" },
        { id = "job", label = "Jobs", icon = "briefcase" },
        { id = "mission", label = "Missions", icon = "target" },
        { id = "vehicle", label = "Vehicles", icon = "car" },
        { id = "housing", label = "Housing", icon = "home" },
        { id = "default", label = "Other", icon = "pin" },
    },
    keys = { open = "M", close = "ESC", waypoint = "Double click", recenter = "SPACE", rotate = "Right drag", pan = "Left drag" },
    locale = {
        setRoute = "Set route", clearRoute = "Clear route", waypoint = "Waypoint", arrived = "You have arrived",
        noRoute = "No road to that place", rerouting = "Rerouting", you = "You", legend = "Legend", recenter = "Recenter",
        northUp = "North up", view3d = "3D", view2d = "2D", search = "Search places",
        influence = "Activity zones", density = "DENSITY", players = "players", player = "player", minimap = "Minimap",
        noSignal = "NO SIGNAL", noResults = "Nothing found", district = "District", display = "DISPLAY",
        performance = "2D · Performance", quality = "3D · Quality", performanceOn = "PERFORMANCE MODE · 2D",
        qualityOn = "QUALITY MODE · 3D", displayTag = "MAP", displayTitle = "DISPLAY MODE",
        displayQuestion = "HOW SHOULD THE CITY BE DRAWN?", performanceTag = "LIGHT · ANY PC", performanceTitle = "PERFORMANCE",
        performanceText = "A flat 2D map without the heavy effects, on the map and the minimap. Smooth on small configurations.",
        qualityTag = "RECENT GRAPHICS CARD", qualityTitle = "QUALITY",
        qualityText = "The 3D city: lit buildings, x-ray minimap, animated route and activity zones.",
        confirm = "Confirm", displayHint = "Switch at any time under DISPLAY in the legend.",
        ["m.start"] = "START", ["m.straight"] = "CONTINUE", ["m.left"] = "TURN LEFT", ["m.right"] = "TURN RIGHT",
        ["m.slight-left"] = "KEEP LEFT", ["m.slight-right"] = "KEEP RIGHT", ["m.sharp-left"] = "SHARP LEFT",
        ["m.sharp-right"] = "SHARP RIGHT", ["m.uturn"] = "U-TURN", ["m.arrive"] = "DESTINATION",
        layers = "LAYERS", hud = "HUD", buildings = "Buildings", roadLines = "Road lines", metro = "Metro", districts = "Districts",
    },
}

D.districts = {
    city_center = "CITY CENTER", watson = "WATSON", westbrook = "WESTBROOK", heywood = "HEYWOOD",
    santo_domingo = "SANTO DOMINGO", pacifica = "PACIFICA", ep1_dogtown = "DOGTOWN", ep1_spaceport = "NCX SPACEPORT",
}

local function isArray(t)
    if type(t) ~= "table" then return false end
    if next(t) == nil then return true end
    return t[1] ~= nil
end

--- A deep copy.
function D.copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = D.copy(x) end
    return out
end

--- Objects merge recursively; arrays and scalars replace; nil is ignored (config.ts deepMerge).
function D.merge(base, patch)
    if type(patch) ~= "table" or isArray(patch) then return base end
    for k, v in pairs(patch) do
        local cur = base[k]
        if type(v) == "table" and not isArray(v) and type(cur) == "table" and not isArray(cur) then
            D.merge(cur, v)
        elseif v ~= nil then
            base[k] = D.copy(v)
        end
    end
    return base
end
