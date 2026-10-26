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
        freecam = "lightrp:ui:freecam", -- page -> Lua: { operation = "toggle" }; Lua -> page: free camera state and keys
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
        actionStart = "lightrp:ui:activity:start",
        actionStarted = "lightrp:ui:activity:started",
        actionFinish = "lightrp:ui:activity:finish",
        actionResult = "lightrp:ui:activity:result",
    },
    -- client <-> server (network events)
    net = {
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
        interactions = "op77_lightrp:interactions", -- server -> client: the proximity points to draw
        interact = "op77_lightrp:interact",   -- client -> server: E pressed at a point (id)
        keysToggle = "op77_lightrp:keys:toggle", -- client -> server: L pressed for a vehicle (id)
        inventory = "op77_lightrp:inventory",  -- server -> client: inventory snapshots for the page
        shop = "op77_lightrp:shop",
        garage = "op77_lightrp:garage",
        dealership = "op77_lightrp:dealership",
        actionDemo = "op77_lightrp:activity:demo", -- staff-only visual playground, never grants rewards
        jobBegin = "op77_lightrp:job:begin",
        jobFinish = "op77_lightrp:job:finish",
        jobWork = "op77_lightrp:job:work",
        workCycle = "op77_lightrp:work:cycle",
        workFinish = "op77_lightrp:work:finish",
        workGps = "op77_lightrp:work:gps",
        jobGps = "op77_lightrp:job:gps",
        consume = "op77_lightrp:consume:state", -- server-owned preparation / playback / finish
        consumeReady = "op77_lightrp:consume:ready",
        consumeFinish = "op77_lightrp:consume:finish",
        fuel = "op77_lightrp:fuel:state",
        fuelSnapshot = "op77_lightrp:fuel:snapshot",
        fuelRefresh = "op77_lightrp:fuel:refresh",
        fuelReady = "op77_lightrp:fuel:ready",
        fuelFinish = "op77_lightrp:fuel:finish",
    },
}
