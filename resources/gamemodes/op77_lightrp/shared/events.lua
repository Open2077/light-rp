-- Every event name the framework uses, in one place. Mirror of ui/src/bridge/protocol.ts.
LightRpEvents = {
    -- page <-> client Lua (WebUI bridge)
    page = {
        ready = "lightrp:ui:ready",     -- page -> Lua: painted and listening
        action = "lightrp:ui:action",   -- page -> Lua: { type = "...", ... } forwarded to the server
        close = "lightrp:ui:close",     -- page -> Lua: the player asked to close the menu (ESC, X)
        state = "lightrp:ui:state",     -- Lua -> page: full state or a patch
        hud = "lightrp:ui:hud",         -- Lua -> page: sampled vitals / vehicle / voice
        open = "lightrp:ui:open",       -- Lua -> page: { view = "character" | ... }
        closed = "lightrp:ui:closed",   -- Lua -> page: the menu is closed, drop focus visuals
        notice = "lightrp:ui:notice",   -- Lua -> page: { kind, title, body, source, durationMs }
        result = "lightrp:ui:result",   -- Lua -> page: { ok, text, action }
    },
    -- client <-> server (network events)
    net = {
        action = "op77_lightrp:action",       -- client -> server: a validated UI action
        ready = "op77_lightrp:ready",         -- client -> server: the page is up, send my state
        state = "op77_lightrp:state",         -- server -> client: state or patch
        notice = "op77_lightrp:notice",       -- server -> client: notice payload
        result = "op77_lightrp:result",       -- server -> client: action result
        menuOpen = "op77_lightrp:menu:open",  -- server -> client: open the menu on a view
    },
}
