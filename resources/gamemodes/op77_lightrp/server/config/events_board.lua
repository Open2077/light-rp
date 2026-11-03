-- The events board at The Crossing (server/modules/events_board.lua): a television by
-- the hub showing what is on in the city -- the next turf war, the next world boss,
-- the activities running or forming, and this week's boards -- so a player passing
-- through sees what to come back for, then goes on with their day.
--
-- How it is drawn: this server serves the board's page and its data over the inbound
-- HTTP listener (server config `httpHandlers`, permission http.serve), the TV is a prop
-- this resource owns, and every client near it paints the page on the screen
-- (client/core/events_board.lua, Open77.media.bind). Without the listener the TV still
-- stands, dark, and the log says why once.
LightRpEventsBoard = {
    enabled = true,

    http = {
        -- The listener's own origin: the server config's httpHandlers.listenUrl (a
        -- resource cannot read it). The platform's default is http://127.0.0.1:11781.
        listenOrigin = "http://127.0.0.1:11781",
        -- The route under /op77_lightrp: the page at <prefix>/, the data at <prefix>/view.json.
        prefix = "/board",
    },
    -- The address the TV loads. nil: <listenOrigin>/op77_lightrp<prefix>/, which only a
    -- game client on the server's own machine reaches (loopback). A public server puts
    -- the listener behind its reverse proxy (TLS there) and writes the public address
    -- here, e.g. "https://play.example.net/board/" proxied to
    -- http://127.0.0.1:11781/op77_lightrp/board/.
    url = nil,

    -- The data is rebuilt this often, and soon after an activity's status changes
    -- (never faster than minRebuildMs). The page asks for it every pollMs.
    refreshMs = 20000,
    minRebuildMs = 3000,
    pollMs = 10000,
    -- Each panel stays this long on screen (four panels: one cycle in 20 s); a panel
    -- with nothing to show is skipped.
    rotateMs = 5000,

    -- Texts on the screen (short, in-world).
    title = "WHAT'S ON",
    join = "Join with {host} here, or F1 > Activities",

    -- The activities listed: live first, then forming, then open, at most this many.
    activities = { max = 7 },
    -- This week: the turf influence (op77_turf, weekly) and the Dogtown kills (weekly).
    weekly = { turf = true, dogtown = true, size = 5 },
    -- All-time records from the Hall of Fame cache (server/modules/halloffame.lua board
    -- keys), the top `size` of each. Activity results keep no weekly history.
    records = { boards = { "pvp.wins", "pve.wins", "missions.completed" }, size = 3 },

    tv = {
        -- One of `screens` below, at this scale (the picture: 1.16 x 0.66 m x scale).
        screen = "tv.16x9",
        scale = 3.0,
        -- Where it stands: the staff's placement (/lightrp.board place, kept in kvp),
        -- else `position`, else this offset along The Crossing's heading
        -- (server/config/activities.lua hub). Without a heading the screen faces the
        -- hub's centre.
        position = nil,
        heading = nil,
        offset = { forward = 12.0, right = 4.0 },
        bucket = 0,
        collision = true,
        streamingRadius = 150.0,
        -- /lightrp.board place: the TV this far behind the staff, its screen facing
        -- where they look.
        staffSetback = 1.5,
        -- Start-up spawn retries, then a check that it still stands every respawnMs.
        spawnRetries = 30,
        spawnRetryMs = 10000,
        respawnMs = 60000,
        -- Clients paint the page within drawRadius metres, and drop it past
        -- drawRadius + drawHysteresis.
        drawRadius = 60.0,
        drawHysteresis = 15.0,
        fps = 15,
        label = "The Crossing: events board",
    },

    -- The screens the board can stand on: open77_media's records
    -- (resources/system/open77_media/shared/records.lua), copied because one resource
    -- cannot read another's files. quad: the picture's rectangle in the prop's own
    -- frame at scale 1 (multiplied by tv.scale); faces: the side carrying the picture.
    screens = {
        ["tv.16x9"] = { model = "electronics.tv.16x9",
            quad = { offset = { 0.0, 0.115394, 0.42 }, right = { 1.0, 0.0, 0.0 }, up = { 0.0, 0.0, 1.0 },
                width = 1.16, height = 0.66, faces = { 0.0, 1.0, 0.0 } } },
        ["tv.screen.16x9"] = { model = "electronics.tv.screen.16x9",
            quad = { offset = { 0.0, 0.115394, 0.42 }, right = { 1.0, 0.0, 0.0 }, up = { 0.0, 0.0, 1.0 },
                width = 1.16, height = 0.66, faces = { 0.0, 1.0, 0.0 } } },
        ["tv.large"] = { model = "electronics.tv.large",
            quad = { offset = { 0.000013, 0.111389, 0.506419 }, right = { 1.0, 0.0, 0.0 }, up = { 0.0, 0.0, 1.0 },
                width = 1.9186, height = 1.0146, faces = { 0.0, 1.0, 0.0 } } },
    },
}
