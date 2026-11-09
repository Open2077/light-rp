-- op77_map3d configuration. Everything under `page` is sent to the map page and
-- deep-merged over its defaults (client/native/defaults.lua lists every key); the rest is
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

    -- Display quality of the map and the minimap. "performance": a flat 2D map seen from
    -- straight above, without the costly effects (lighting, x-ray, animated route and
    -- zones, antialiasing), for small configurations; "quality": the 3D city. The first
    -- time a player opens the map they choose (ask = false: never asked, `default` until
    -- they switch); the choice is kept on their machine (KVP) and switched at any time
    -- under DISPLAY in the map's legend (exports.op77_map3d:setQuality from a resource).
    quality = { default = "performance", ask = true },

    -- Print open/close and waypoint changes (with their origin) to the client log.
    debug = false,

    -- How often the player's position reaches the page (Hz).
    playerRate = 30,

    -- Kept for older configs: the native map redraws only what moves;
    -- page.minimap.fps / page.map.idleFps cap its redraws while something animates.
    fps = { minimap = 60, map = 60 },

    -- Kept for older configs: the native document draws above WebUI pages and steps
    -- aside under other interfaces (hideUnderMenus).
    zIndex = { minimap = 700, map = 781 },
    -- Hide the minimap while another interface holds the cursor
    -- (inventory, F1 menu, phone...).
    hideUnderMenus = true,
    -- How long the open map's surface stays up after closing, for its closing animation
    -- (the page's own is 240 ms). 0 hides it at once.
    closeAnimationMs = 260,

    -- Other players near you shown as blips (category "player"). Off (owner, 2026-11-06): no
    -- player's position on the map or the minimap; the influence zones below still show where
    -- people gather, as zones only.
    nearbyPlayers = { enabled = false, radius = 350, interval = 1.0, color = "#3FE0D0" },

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
            { id = "service", label = "Services", icon = "store" },
            { id = "job", label = "Jobs", icon = "briefcase" },
            { id = "mission", label = "Missions", icon = "mission", color = "#FF2E3C" },
            { id = "vehicle", label = "Vehicles", icon = "car", color = "#7FB4D6" },
            { id = "housing", label = "Housing", icon = "home", color = "#8FE04A" },
            -- LightRP's bars and clubs (op77_lightrp mapPlaces)
            { id = "nightlife", label = "Bars & clubs", color = "#FF3FB4",
                icon = [[<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" fill-rule="evenodd"><path d="M3.2 4.2h17.6q.7 0 .3.6L13.1 14v5.2l3.6 1q.6.2.6.8v.4H6.7V21q0-.6.6-.8l3.6-1V14L2.9 4.8q-.4-.6.3-.6zM6.4 6.4l2.2 2.5h6.8l2.2-2.5z"/><path d="M16.9 1.4l1 .9-4.6 5.4-1-.9zM12.6 6.6a1.6 1.6 0 1 1-.1 3.2 1.6 1.6 0 0 1 .1-3.2z"/></svg>]] },
            -- LightRP's gun stores (each pin draws its own weapon: op77_lightrp map_icons.lua)
            { id = "weapons", label = "Gun stores", color = "#FF7A1A",
                icon = [[<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" fill-rule="evenodd"><g transform="translate(12 12) scale(1.08) translate(-12 -12.6)"><path d="M2.8 6.2H19.3V5.5h1v.7h.6q.8 0 .8.8v2.4q0 .8-.8.8h-6.4l-.2.6q-.6 2.2-2.4 2.2h-1.6l-1 5.8q-.1.8-.9.8H5.3q-.8 0-.7-.8l1-6.6q-1.3-.1-2.1-.8l-.6-.6Q2.4 10.6 2.4 9.8V7.4L2 6.8q0-.6.8-.6zM10.5 10.6h2.8q-.4 1.6-1.7 1.6h-1.3zM4 7.1h.5v2.4H4zM5.2 7.1h.5v2.4h-.5zM6.4 7.1h.5v2.4h-.5zM11.6 7.1h3.4V8h-3.4z"/><path d="M11.2 10.6h.7l-.3 1.3h-.6z"/><path d="M2.4 5.2h1.2l.4 1H2.6z"/></g></svg>]] },
            -- LightRP's Maneki-neko collection: only the cats this player found, shown from F1 > Maneki-neko
            { id = "maneki", label = "Maneki-neko", color = "#FFCC00",
                icon = [[<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor" fill-rule="evenodd"><path d="M5.6 2.6l3.2 3.3a7 7 0 0 1 6.4 0l3.2-3.3.7 5.3a6.6 6.6 0 0 1-6.3 7.8h-.6a6.6 6.6 0 0 1-6.3-7.8zM8.6 9.2h2.2v1.1H8.6zM13.2 9.2h2.2v1.1h-2.2z"/><path d="M6.6 15.2C5.4 16.6 5 18.2 5 19.6 5 21 6 21.6 7.4 21.6h9.2c1.4 0 2.4-.6 2.4-2 0-1.4-.4-3-1.6-4.4a7.6 7.6 0 0 1-10.8 0zM12 16.6a1.9 2.3 0 1 0 0 4.6 1.9 2.3 0 1 0 0-4.6z"/><path d="M19.4 13.6c1-1.4 1.6-3.4 1.6-5.2 0-1-.5-1.6-1.2-1.6s-1.2.6-1.2 1.6c0 1.4-.4 2.8-1 4z"/></svg>]] },
            { id = "default", label = "Other", icon = "pin" },
        },
    },
}
