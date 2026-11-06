-- Every event name the framework uses, in one place. Mirror of ui/src/bridge/protocol.ts.
LightRpEvents = {
    -- page <-> client Lua (WebUI bridge)
    page = {
        customization = "lightrp:ui:customization",
        support = "lightrp:ui:support",
        animationsAction = "lightrp:ui:animations:action",
        animationsState = "lightrp:ui:animations:state",
        animationsCatalog = "lightrp:ui:animations:catalog",
        animationsPreferences = "lightrp:ui:animations:preferences",
        ready = "lightrp:ui:ready",     -- page -> Lua: painted and listening
        action = "lightrp:ui:action",   -- page -> Lua: { type = "...", ... } forwarded to the server
        close = "lightrp:ui:close",     -- page -> Lua: the player asked to close the menu (Backspace, Escape, F1)
        dialogState = "lightrp:ui:dialog:state", -- page -> Lua: { kind, open } which dialogs are on screen
        dialogClose = "lightrp:ui:dialog:close", -- Lua -> page: { kind } close that dialog
        characterEditor = "lightrp:ui:character:editor", -- Lua -> page: { active, error? } native editor handoff
        creator = "lightrp:ui:creator", -- scene state / camera and audio preferences
        tutorial = "lightrp:ui:tutorial", -- first-day controls / local presentation
        tutorialGuide = "lightrp:ui:tutorialguide", -- Lua -> page: { label, distance, angle, rise } | { hide = true } the way to the objective (client/core/tutorial_guide.lua)
        jobRun = "lightrp:ui:jobrun",   -- Lua -> page: { distance, menuKey } live data of the work order tracker
        freecam = "lightrp:ui:freecam", -- page -> Lua: { operation = "toggle" }; Lua -> page: free camera state and keys
        maneki = "lightrp:ui:maneki",   -- Lua -> page: the Maneki-neko placement tool's bar (client/core/maneki_editor.lua)
        arrivalTour = "lightrp:ui:arrivaltour", -- Lua -> page: { title, subtitle, lines, durationMs } or false (client/core/arrival_tour.lua)
        staffAnnounce = "lightrp:ui:staffannounce", -- Lua -> page: { title, text, from, durationMs } the staff broadcast banner (client/core/staff_announce.lua)
        parkour = "lightrp:ui:parkour", -- Lua -> page: the run HUD, the course card's leaderboard, the music (client/core/parkour.lua)
        parkourEditor = "lightrp:ui:parkoureditor", -- page <-> Lua: the staff parkour editor (client/core/parkour_editor.lua)
        state = "lightrp:ui:state",     -- Lua -> page: full state or a patch
        hud = "lightrp:ui:hud",         -- Lua -> page: sampled vitals / vehicle / voice
        open = "lightrp:ui:open",       -- Lua -> page: the player menu opens
        closed = "lightrp:ui:closed",   -- Lua -> page: the menu is closed, drop focus visuals
        notice = "lightrp:ui:notice",   -- Lua -> page: { kind, title, body, source, durationMs }
        result = "lightrp:ui:result",   -- Lua -> page: { ok, text, action }
        dialog = "lightrp:ui:dialog",   -- Lua -> page: { kind = "rental", ... } opens a dialog
        interact = "lightrp:ui:interact", -- Lua -> page: { id, prompt, key } for the nearest point in range, {} when none
        inventory = "lightrp:ui:inventory", -- Lua -> page: { inventories = { snapshot, ... } } fresh copies of what is on screen
        shop = "lightrp:ui:shop",
        garage = "lightrp:ui:garage",
        dealership = "lightrp:ui:dealership",
        raid = "lightrp:ui:raid",             -- Lua -> page: raid state (ready check, boss, announcements, intro)
        mission = "lightrp:ui:mission",       -- Lua -> page: { session, state? , closed? } live mission board
        guide = "lightrp:ui:guide",           -- Lua -> page: guide search index / topics, with the player's key names (client/core/guide.lua)
        activityHud = "lightrp:ui:activityhud", -- Lua -> page: { op = "show", hud } | { op = "push", kind, item } | { op = "clear" } (client/core/activity_hud.lua)
        actionStart = "lightrp:ui:activity:start",
        actionStarted = "lightrp:ui:activity:started",
        actionFinish = "lightrp:ui:activity:finish",
        actionResult = "lightrp:ui:activity:result",
    },
    -- client <-> server (network events)
    net = {
        pvpPlayers = "op77_lightrp:pvp:players", -- server -> client: the player ids in a PvP fight (nameplates hidden)
        arrivalTour = "op77_lightrp:arrival:tour", -- server -> client: { center } the camera tour of the central square after the hall (server/modules/tutorial.lua)
        rpNames = "op77_lightrp:rpnames", -- server -> client: { "id<TAB>First Last", ... } the characters' names for the nameplates (server/modules/rp_names.lua)
        staffGhosts = "op77_lightrp:staff:ghosts", -- server -> client: the staff in ghost mode (no nameplate, no map dot)
        staffGhost = "op77_lightrp:staff:ghost",   -- server -> the ghost: { on } (its client toggles the platform noclip)
        customization = "op77_lightrp:customization",
        support = "op77_lightrp:support",
        action = "op77_lightrp:action",       -- client -> server: a validated UI action
        ready = "op77_lightrp:ready",         -- client -> server: the page is up, send my state
        creator = "op77_lightrp:creator",     -- server-authorized arrival scene lifecycle
        tutorial = "op77_lightrp:tutorial",   -- first-day guide, no client-selected rewards
        state = "op77_lightrp:state",         -- server -> client: state or patch
        notice = "op77_lightrp:notice",       -- server -> client: notice payload
        result = "op77_lightrp:result",       -- server -> client: action result
        dialog = "op77_lightrp:dialog",       -- server -> client: open a page dialog
        recap = "op77_lightrp:recap",         -- server -> client: the end-of-match recap (server/modules/recap.lua), latent when large
        interactions = "op77_lightrp:interactions", -- server -> client: the proximity points to draw
        interact = "op77_lightrp:interact",   -- client -> server: E pressed at a point (id)
        interactionsRequest = "op77_lightrp:interactions:request", -- client -> server: send me the list (once in the world)
        keysToggle = "op77_lightrp:keys:toggle", -- client -> server: L pressed for a vehicle (id)
        inventory = "op77_lightrp:inventory",  -- server -> client: inventory snapshots for the page
        shop = "op77_lightrp:shop",
        garage = "op77_lightrp:garage",
        dealership = "op77_lightrp:dealership",
        mission = "op77_lightrp:mission",     -- server -> client: mission board updates
        raid = "op77_lightrp:raid",           -- server -> client: raid state (server/modules/mission_chimera.lua)
        raidReady = "op77_lightrp:raid:ready", -- client -> server: the ready key
        raidHello = "op77_lightrp:raid:hello", -- client -> server: send me the raid state
        raidLoaded = "op77_lightrp:raid:loaded", -- client -> server: the arena finished loading here
        raidHit = "op77_lightrp:raid:hit",       -- client -> server: the local player's shot hit the Chimera
        cameraChange = "op77_lightrp:camera:change",       -- server -> client: /camchange (client/core/camera.lua)
        cameraCinematic = "op77_lightrp:camera:cinematic", -- server -> client: /cinematic
        actionDemo = "op77_lightrp:activity:demo", -- staff-only visual playground, never grants rewards
        jobBegin = "op77_lightrp:job:begin",
        jobFinish = "op77_lightrp:job:finish",
        jobWork = "op77_lightrp:job:work",
        workCycle = "op77_lightrp:work:cycle",
        workFinish = "op77_lightrp:work:finish",
        workGps = "op77_lightrp:work:gps",
        jobGps = "op77_lightrp:job:gps",
        vehicleGps = "op77_lightrp:vehicle:gps", -- server -> client: route to a vehicle just bought (or the garage holding it)
        activitiesGps = "op77_lightrp:activities:gps", -- server -> client: route to a contract board or The Crossing (activities_hub.lua)
        hallOfFameBoard = "op77_lightrp:halloffame:board", -- server -> client: which prop is the Hall of Fame board (halloffame.lua)
        hallOfFameHello = "op77_lightrp:halloffame:hello", -- client -> server: send me the board
        eventsBoardTv = "op77_lightrp:eventsboard:tv", -- server -> client: the events board's prop, screen and page (events_board.lua)
        eventsBoardHello = "op77_lightrp:eventsboard:hello", -- client -> server: send me the events board
        eventsBoardAim = "op77_lightrp:eventsboard:aim", -- server -> client: /lightrp.board aim, read your crosshair
        eventsBoardAimed = "op77_lightrp:eventsboard:aimed", -- client -> server: the crosshair's hit (position, normal)
        guide = "op77_lightrp:guide",         -- server -> client: the guide NPC's id, search index and topics (server/modules/guide.lua)
        consume = "op77_lightrp:consume:state", -- server-owned preparation / playback / finish
        consumeReady = "op77_lightrp:consume:ready",
        consumeFinish = "op77_lightrp:consume:finish",
        fuel = "op77_lightrp:fuel:state",
        fuelSnapshot = "op77_lightrp:fuel:snapshot",
        fuelRefresh = "op77_lightrp:fuel:refresh",
        fuelReady = "op77_lightrp:fuel:ready",
        fuelFinish = "op77_lightrp:fuel:finish",
        wardrobe = "op77_lightrp:wardrobe",    -- client -> server: the fitting room opened (true) or closed (false)
        maneki = "op77_lightrp:maneki",        -- server -> client: { kind = "near" | "found" | "editor" | "staff" } (server/modules/maneki.lua)
        manekiCollect = "op77_lightrp:maneki:collect", -- client -> server: { id, how = "take" | "shot" }
        manekiEdit = "op77_lightrp:maneki:edit",       -- client -> server: the staff placement tool { op = "place" | "delete" | "close", ... }
        staffAnnounce = "op77_lightrp:staffannounce", -- server -> client: a staff announcement for the banner (server/modules/staff.lua Staff.announce)
        parkour = "op77_lightrp:parkour",          -- server -> client: { kind = "courses" | "run" | "countdown" | "go" | "cp" | "finish" | "result" | "dnf" | "respawn" | "ended" | "board" | "close" } (server/modules/parkour.lua)
        parkourKey = "op77_lightrp:parkour:key",   -- client -> server: { op = "restart" | "checkpoint" | "leave" | "ready" }
        parkourEditor = "op77_lightrp:parkour:editor", -- both ways: the staff editor's requests and responses
    },
}
