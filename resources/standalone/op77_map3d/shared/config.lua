-- op77_map3d configuration. Everything under `page` is sent to the map page and
-- deep-merged over its defaults (ui/src/config.ts lists every key); the rest is
-- client behaviour. A server can also change the page at runtime:
--   exports.op77_map3d:setConfig({ theme = { accent = "#3FE0D0" } })   -- client
Map3DConfig = {
    -- The key that opens the city map (rebindable in the game's key settings).
    key = { id = "op77_map3d.open", name = "City map (3D)", key = "M" },
    -- Minimap zoom, held to zoom continuously (rebindable). The numpad names need a client
    -- that knows them (Unstable 167+); older ones get `fallback` instead.
    zoomKeys = {
        zoomIn = { id = "op77_map3d.zoomIn", name = "Minimap: zoom in", key = "NUMPADPLUS", fallback = "PAGEUP" },
        zoomOut = { id = "op77_map3d.zoomOut", name = "Minimap: zoom out", key = "NUMPADMINUS", fallback = "PAGEDOWN" },
    },

    -- Take over from the game's own map and minimap while this resource runs.
    replaceNativeMap = true,     -- the game's map key/menu is blocked (input.actions)
    pauseMenuMap = true,         -- the pause menu's CITY MAP opens this map (open77_pause providers)
    pauseMenuPriority = 100,     -- against other map providers: the highest wins
    hideNativeMinimap = true,    -- the vanilla HUD minimap is hidden (ui.vanilla.hud)

    -- The waypoint is shared with the game: setting one here also places the native
    -- waypoint (other resources reading Open77.blips.waypoint() see it), and a native
    -- waypoint placed by another resource becomes this map's destination.
    mirrorNativeWaypoint = true,

    -- Print open/close and waypoint changes (with their origin) to the client log.
    debug = false,

    -- How often the player's position reaches the page (Hz).
    playerRate = 30,

    -- WebUI surface frame rates (fixed when the surface is created; 60 at most). The
    -- minimap has its own small surface, the open map a full-screen one hidden while
    -- closed. page.minimap.fps / page.map.idleFps cap how often the page redraws.
    fps = { minimap = 60, map = 60, holo = 30 },

    -- Surface order: the minimap and the holo GPS under the gamemode's interfaces
    -- (LightRP's page is 720), the open map above them.
    zIndex = { minimap = 700, holo = 699, map = 781 },
    -- Hide the minimap and the holo GPS while another interface holds the cursor
    -- (inventory, F1 menu, phone...).
    hideUnderMenus = true,
    -- How long the open map's surface stays up after closing, for its closing animation
    -- (the page's own is 240 ms). 0 hides it at once.
    closeAnimationMs = 260,

    -- Other players near you shown as blips (category "player").
    nearbyPlayers = { enabled = true, radius = 350, interval = 1.0, color = "#3FE0D0" },

    -- Influence zones: where players gather, drawn on the open map (never the minimap) so
    -- the others can find the action (a heat field on the ground, the buildings lit, a
    -- beacon over the busiest). The server groups the positions (shared/influence.lua) and
    -- sends only zones of `minPlayers` or more, never a player: a zone shows a crowd, it
    -- cannot be used to follow someone (below 3 players there is never a zone, whatever
    -- the setting). `enabled = false` turns the feature off for the whole server
    -- (nothing is gathered or sent; also exports.op77_map3d:setInfluenceEnabled(false) or
    -- the console command `map3d.influence off`). When on, each player can hide it from
    -- the map's legend ("Activity zones").
    influence = {
        enabled = true,
        interval = 3,         -- seconds between updates
        cell = 150,           -- metres: players in touching cells are one zone
        padding = 70,         -- metres around the outermost player of a zone
        minRadius = 90, maxRadius = 900,
        snap = 25,            -- the zone's centre is snapped to this grid (it does not follow its players to the metre)
        minPlayers = 5,       -- players a zone needs to exist (3 at the very least)
        maxZones = 24,
        sameBucket = true,    -- zones of your own routing bucket only (instances and missions stay private)
        -- density levels, by players in the zone (lowest first); the page colours them
        -- with page.influence.colors, in the same order
        levels = {
            { min = 5, id = "active", label = "ACTIVE" },
            { min = 10, id = "busy", label = "BUSY" },
            { min = 18, id = "crowded", label = "CROWDED" },
            { min = 30, id = "hotspot", label = "HOTSPOT" },
        },
    },

    -- Page settings (theme, minimap, full map, GPS, categories, texts).
    page = {
        theme = {
            accent = "#FFCC00",
            buildingEdge = "#FFCC00",
            roadEdge = "#FFCC00",
            terrainGrid = "#FFCC00",
        },
        minimap = {
            enabled = true,
            anchor = "top-right",
            size = 264,
            shape = "chamfer",   -- chamfer | circle | square
            tilt = 10,           -- degrees from straight down on foot
            vehicleTilt = 54,    -- in a vehicle (GTA-like)
            rotate = true,
        },
        map = {
            title = "NIGHT CITY",
            subtitle = "CITY MAP",
            initialPitch = 42,
            doubleClickWaypoint = true,
        },
        gps = {
            enabled = true,
            units = "metric",    -- metric | imperial
            avoidHighways = false,
        },
        -- How the influence zones look on the open map (the server's `influence` above
        -- decides whether there are any): one colour per density level, labels, player
        -- counts in them.
        influence = {
            colors = { "#3FE0D0", "#FFCC00", "#FF8A1F", "#FF2E3C" },
            labels = true,
            showCount = true,
            buildings = true,    -- the buildings inside a zone light up
            beaconLevel = 2,     -- from this level on, a column of light marks the zone
        },
        categories = {
            { id = "player", label = "Players", icon = "user", color = "#3FE0D0" },
            { id = "service", label = "Services", icon = "store" },
            { id = "job", label = "Jobs", icon = "briefcase" },
            { id = "mission", label = "Missions", icon = "mission", color = "#FF2E3C" },
            { id = "vehicle", label = "Vehicles", icon = "car", color = "#7FB4D6" },
            { id = "housing", label = "Housing", icon = "home", color = "#8FE04A" },
            -- LightRP's gun stores (each pin draws its own weapon: op77_lightrp map_icons.lua)
            { id = "weapons", label = "Gun stores", color = "#FF7A1A",
                icon = [[<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" fill-rule="evenodd"><g transform="translate(12 12) scale(1.08) translate(-12 -12.6)"><path d="M2.8 6.2H19.3V5.5h1v.7h.6q.8 0 .8.8v2.4q0 .8-.8.8h-6.4l-.2.6q-.6 2.2-2.4 2.2h-1.6l-1 5.8q-.1.8-.9.8H5.3q-.8 0-.7-.8l1-6.6q-1.3-.1-2.1-.8l-.6-.6Q2.4 10.6 2.4 9.8V7.4L2 6.8q0-.6.8-.6zM10.5 10.6h2.8q-.4 1.6-1.7 1.6h-1.3zM4 7.1h.5v2.4H4zM5.2 7.1h.5v2.4h-.5zM6.4 7.1h.5v2.4h-.5zM11.6 7.1h3.4V8h-3.4z"/><path d="M11.2 10.6h.7l-.3 1.3h-.6z"/><path d="M2.4 5.2h1.2l.4 1H2.6z"/></g></svg>]] },
            { id = "default", label = "Other", icon = "pin" },
        },
    },
}
