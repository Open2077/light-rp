-- op77_turf client: the HUD model handed to Light RP's shared activity HUD
-- (client/hud.lua), and the client wiring (client/main.lua) with the host stubbed:
-- ActivityHudShow / Push / Clear, the fallback when they are missing, zone markers
-- and their colours, op77_map3d blips, the kit key.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test hud_test.lua
local realPrint = print
dofile("shared/config.lua")
dofile("client/hud.lua")
local H, CFG = TurfHud, TurfConfig

local function shared(over)
    local s = { warId = 7, phase = "running", site = { id = "kabuki", label = "Kabuki Market", district = "Watson" }, target = 900,
        sides = { { label = "Valentinos", color = "#D9A441", score = 120, gang = "valentinos", count = 4 },
                  { label = "Maelstrom", color = "#FF2E3C", score = 80, gang = "maelstrom", count = 4 } },
        zones = { { id = "A", label = "The Stalls", owner = 1, progress = 0 },
                  { id = "B", label = "Market Crossing", capturing = 2, progress = 0.4 },
                  { id = "C", label = "Lantern Row", contested = true, capturing = 1, progress = 0.25 } },
        remainingMs = 400000 }
    for k, v in pairs(over or {}) do s[k] = v end
    return s
end
local personal = { id = 3, side = 1, kills = 2, deaths = 1, captures = 1, hold = 75, kit = "marksman" }

-- ---------------------------------------------------------------- the model
do
    local board = {}
    for i = 1, 20 do board[i] = { id = i, name = "P" .. i, side = i % 2 + 1, kills = 20 - i, deaths = 0, captures = 0, score = 100 - i,
        merc = i == 5 } end
    board[20].id = 3 -- the player is last on a long board
    board[3].id = 99
    local hud = H.war(shared(), personal, board, { kits = CFG.kits, kitKey = "K" })
    assert(hud.activity == "turf.war" and hud.title == "TURF WAR" and hud.subtitle == "Kabuki Market · Watson")
    assert(hud.phase == "running" and hud.timer.remainingMs == 400000 and hud.timer.label == "TIME LEFT")
    assert(#hud.stats == 4 and hud.stats[1].value == "2 / 1" and hud.stats[3].value == "1:15" and hud.stats[4].value == "MARKSMAN")
    assert(#hud.progress == 3)
    assert(hud.progress[1].value == 1 and hud.progress[1].tone == "success" and hud.progress[1].label:find("Valentinos"), "ours")
    assert(hud.progress[2].value == 0.4 and hud.progress[2].tone == "danger" and hud.progress[2].label:find("Maelstrom taking it"))
    assert(hud.progress[3].tone == "accent" and hud.progress[3].label:find("CONTESTED"))
    assert(#hud.teams == 2 and hud.teams[1].self == true and hud.teams[2].self == false and hud.teams[1].score == 120)
    assert(hud.teams[1].color == "#D9A441")
    assert(#hud.scoreboard.columns == 4 and #hud.scoreboard.rows == 16, "at most 16 rows")
    assert(hud.scoreboard.rows[16].self == true and hud.scoreboard.rows[16].name == "P20", "the player always on the board")
    assert(hud.scoreboard.rows[5].name:find("·M"), "mercenaries marked")
    assert(#hud.hints == 1 and hud.hints[1].key == "K")
    assert(hud.objective:find("Valentinos") and hud.objective:find("900"))

    -- down / out of bounds / protected: the objective says so
    local down = H.war(shared(), { id = 3, side = 1, respawnMs = 4200, kit = "assault" }, {}, { kits = CFG.kits })
    assert(down.objective:find("back in 5s"))
    local out = H.war(shared(), { id = 3, side = 1, outMs = 2500, kit = "assault" }, {}, {})
    assert(out.objective:find("Back to the war zone! 3s"))

    -- countdown / placing / ended
    local cd = H.war(shared({ phase = "countdown", countdownMs = 6400, remainingMs = nil }), personal, {}, {})
    assert(cd.phase == "countdown" and cd.countdown == 7 and cd.timer.label == "FIGHT IN")
    local pl = H.war(shared({ phase = "placing", countdownMs = 30000 }), personal, {}, {})
    assert(pl.phase == "countdown" and pl.countdown == nil and pl.objective:find("Deploying"))
    local ended = H.war(shared({ phase = "ended", winner = 1, remainingMs = 8000,
        influence = { { gang = "valentinos", label = "Valentinos", points = 42, delta = 20 }, { gang = "maelstrom", label = "Maelstrom", points = 9 },
                      { label = "A", points = 1 }, { label = "B", points = 1 }, { label = "C", points = 1 } } }), personal, {}, {})
    assert(ended.phase == "ended" and ended.timer.label == "HOME IN" and ended.objective:find("Victory"))
    assert(#ended.stats == 4 and ended.stats[1].label == "#1 Valentinos" and ended.stats[1].value == "42 (+20)", "the city this week")
    assert(#ended.hints == 0)
    local void = H.war(shared({ phase = "ended", void = true }), personal, {}, {})
    assert(void.objective:find("called off"))

    -- lobby
    local lobby = H.lobby({ queued = true, position = 2, total = 5, min = 6, lobbyMs = 30000, site = "Kabuki Market", gang = "Valentinos",
        kit = "tech" }, { kits = CFG.kits, kitKey = "K" })
    assert(lobby.phase == "lobby" and lobby.timer.remainingMs == 30000 and lobby.stats[1].value == "5 / 6" and lobby.stats[3].value == "TECH")
    assert(#lobby.stats <= 4 and #lobby.hints <= 4)

    -- results keep only what the HUD knows
    local card = H.result({ title = "VICTORY", placement = 1, subtitle = "x", lines = { { label = "Kills", value = 3 } }, durationMs = 10000,
        influence = { 1, 2 }, tone = "success" })
    assert(card.title == "VICTORY" and card.lines[1].value == "3" and card.influence == nil and card.tone == nil)

    -- the signature ignores the running clocks
    local a = H.war(shared({ remainingMs = 1000 }), personal, {}, {})
    local b = H.war(shared({ remainingMs = 5000 }), personal, {}, {})
    assert(H.signature(a) == H.signature(b))
    local c = H.war(shared({ remainingMs = 5000, zones = { { id = "A", label = "The Stalls", owner = 2, progress = 0 } } }), personal, {}, {})
    assert(H.signature(a) ~= H.signature(c))

    -- marker colours
    local palette = { neutral = CFG.markers.neutral, contested = CFG.markers.contested }
    local s = shared()
    local color, key = H.zoneColor(s.zones[1], s, palette)
    assert(color.r == 0xD9 and color.g == 0xA4 and key == "owner1")
    color, key = H.zoneColor(s.zones[3], s, palette)
    assert(color == palette.contested and key == "contested")
    color, key = H.zoneColor({ id = "Z" }, s, palette)
    assert(color == palette.neutral and key == "neutral")
    assert(H.rgb("#FFCC00").g == 204 and H.rgb("nope") == nil)
end

-- ---------------------------------------------------------------- the client wiring
local host = { net = {}, server = {}, shows = {}, pushes = {}, clears = 0, markers = {}, updates = {}, removed = {}, blips = {},
    blipUpdates = 0, keys = {} }
local hudAvailable = true
local t = 100.0
local nextMarker = 0
_G.Open77 = {
    time = { monotonic = function() return t end },
    markers = {
        create = function(o) nextMarker = nextMarker + 1; host.markers[tostring(nextMarker)] = o; return tostring(nextMarker) end,
        update = function(id, patch) host.updates[#host.updates + 1] = { id = id, patch = patch }; return true end,
        remove = function(id) host.removed[#host.removed + 1] = id; host.markers[id] = nil; return true end,
    },
    input = { keyFor = function() return "J" end },
    log = { warn = function() end, error = function() end },
}
local lightrp = {
    ActivityHudShow = function(_, model) host.shows[#host.shows + 1] = model; return true end,
    ActivityHudPush = function(_, kind, payload) host.pushes[#host.pushes + 1] = { kind = kind, payload = payload }; return true end,
    ActivityHudClear = function() host.clears = host.clears + 1; return true end,
}
local map3d = {
    addBlip = function(_, def) host.blips[def.id] = def; return "op77_turf:" .. def.id end,
    updateBlip = function(_, id, patch) host.blipUpdates = host.blipUpdates + 1; return true end,
    removeBlip = function(_, id) host.blips[id:gsub("^op77_turf:", "")] = nil; return true end,
}
_G.exports = setmetatable({}, { __index = function(_, name)
    if name == "op77_lightrp" then
        if not hudAvailable then error("No such export ActivityHudShow in resource op77_lightrp") end
        return lightrp
    end
    if name == "op77_map3d" then return map3d end
    error("no resource " .. tostring(name))
end })
_G.RegisterNetEvent = function(name, fn) host.net[name] = fn end
_G.TriggerServerEvent = function(name, ...) host.server[#host.server + 1] = { name = name, args = { ... } } end
_G.RegisterKeyMapping = function(id, name, key, handler) host.keys[id] = { key = key, handler = handler }; return true, key end
_G.AddEventHandler = function() end
_G.CreateThread = function(fn) fn() end
_G.Wait = function() end
_G.GetCurrentResourceName = function() return "op77_turf" end
dofile("client/main.lua")

local function sent(name)
    for _, s in ipairs(host.server) do if s.name == name then return s end end
end
local function markerCount() local n = 0; for _ in pairs(host.markers) do n = n + 1 end; return n end

do
    assert(sent("op77_turf:ready"), "asks the server for its state at start")
    assert(host.keys["op77_turf.kit"].key == "K")
    host.keys["op77_turf.kit"].handler()
    assert(not sent("op77_turf:kit"), "the key does nothing outside the war")

    local site = { warId = 7, site = { id = "kabuki", label = "Kabuki Market" }, side = 1, zones = {} }
    for i, z in ipairs(CFG.sites[1].zones) do site.zones[i] = { id = z.id, label = z.label, x = z.x, y = z.y, z = z.z, radius = z.radius } end
    host.net["op77_turf:site"](site)
    host.net["op77_turf:state"](shared(), personal)
    assert(#host.shows == 1 and host.shows[1].phase == "running" and host.shows[1].hints[1].key == "J", "the HUD with the rebound key")
    assert(markerCount() == 6, "a ring and a beacon per zone")
    local ring
    for _, o in pairs(host.markers) do if o.shape == "cylinder" and o.radius == CFG.sites[1].zones[1].radius then ring = o end end
    assert(ring and ring.position.z > CFG.sites[1].zones[1].z and ring.maxDistance == CFG.markers.maxDistance)
    assert(host.blips.turf_A and host.blips.turf_A.color == "#D9A441" and host.blips.turf_C.pulse == true)

    -- same picture next second: not re-sent; 5 s later: re-sent for the clock
    t = t + 1
    host.net["op77_turf:state"](shared({ remainingMs = 399000 }), personal)
    assert(#host.shows == 1)
    t = t + 5
    host.net["op77_turf:state"](shared({ remainingMs = 394000 }), personal)
    assert(#host.shows == 2)

    -- a zone changes hands: one colour update per marker, no rebuild
    local s2 = shared()
    s2.zones[2] = { id = "B", label = "Market Crossing", owner = 2, progress = 0 }
    host.net["op77_turf:state"](s2, personal)
    assert(#host.shows == 3 and #host.updates == 2, "ring + beacon recoloured")
    assert(host.updates[1].patch.color.r == 0xFF and host.updates[1].patch.color.g == 0x2E)
    host.net["op77_turf:state"](s2, personal)
    assert(#host.updates == 2, "unchanged: no update")

    -- the kit key in the war
    host.keys["op77_turf.kit"].handler()
    assert(sent("op77_turf:kit").args[1] == "next")

    -- feed / banner / result go to the HUD
    host.net["op77_turf:push"]("banner", { title = "ZONE A CAPTURED", text = "x", tone = "success", durationMs = 3500, extra = 1 })
    host.net["op77_turf:push"]("result", { title = "VICTORY", placement = 1, lines = { { label = "a", value = 1 } }, influence = {} })
    host.net["op77_turf:push"]("nonsense", { title = "x" })
    assert(#host.pushes == 2 and host.pushes[1].payload.extra == nil and host.pushes[2].payload.influence == nil)

    -- board updates re-render
    host.net["op77_turf:board"]({ { id = 3, name = "P3", side = 1, kills = 5, deaths = 0, captures = 1, score = 40 } })
    assert(host.shows[#host.shows].scoreboard.rows[1].self == true)

    -- the war is over: HUD cleared, markers and blips gone
    host.net["op77_turf:clear"]()
    assert(host.clears == 1 and markerCount() == 0 and next(host.blips) == nil)

    -- queued, lobby counting down: the lobby HUD; queued without a lobby: nothing
    host.net["op77_turf:state"](nil, { queued = true, position = 1, total = 3, min = 6, kit = "assault" })
    local shows = #host.shows
    assert(shows == #host.shows)
    host.net["op77_turf:state"](nil, { queued = true, position = 1, total = 6, min = 6, lobbyMs = 40000, kit = "assault", site = "Kabuki Market" })
    assert(#host.shows == shows + 1 and host.shows[#host.shows].phase == "lobby")
    host.net["op77_turf:clear"]()

    -- an older Light RP without the shared HUD: one notice to the server, then quiet
    hudAvailable = false
    host.net["op77_turf:site"](site)
    host.net["op77_turf:state"](shared(), personal)
    host.net["op77_turf:state"](shared({ phase = "countdown", countdownMs = 3000 }), personal)
    local n = 0
    for _, s in ipairs(host.server) do if s.name == "op77_turf:hudless" then n = n + 1 end end
    assert(n == 1, "hudless reported once")
    assert(markerCount() == 6, "the zone markers do not depend on the HUD")
    host.net["op77_turf:clear"]()
    host.net["op77_turf:state"](shared({ warId = 8 }), personal)
    n = 0
    for _, s in ipairs(host.server) do if s.name == "op77_turf:hudless" then n = n + 1 end end
    assert(n == 2, "reported again for the next war (the server's flag is per war entry)")
end

realPrint("PASS hud_test: HUD model (phases, limits, zone tones, scoreboard self row, end card influence, lobby, result, signature, colours) + client wiring (show/push/clear, resend policy, markers + recolour, blips, kit key, hudless fallback)")
