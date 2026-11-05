-- Parkour, client side (client/core/parkour.lua, parkour_editor.lua) with the host stubbed:
-- start orbs for the nearest courses only, the run's orbs follow the checkpoints, every
-- server event reaches the page, the keys go to the server only during a run, the editor
-- relays, captures, draws the draft and turns build clicks into page actions.
local threads = {}
_G.CreateThread = function(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; local ok, err = coroutine.resume(co); if not ok then error(err, 0) end end
_G.Wait = function() coroutine.yield() end
local function tick(n)
    for _ = 1, n or 1 do
        for i = #threads, 1, -1 do
            local co = threads[i]
            if coroutine.status(co) == "dead" then table.remove(threads, i)
            else local ok, err = coroutine.resume(co); if not ok then error(err, 0) end end
        end
    end
end
local nets, mappings, toServer, toPage, markers, nextMarker, sounds, draws = {}, {}, {}, {}, {}, 0, {}, {}
_G.RegisterNetEvent = function(name, fn) nets[name] = fn end
_G.RegisterKeyMapping = function(id, _, key, fn) mappings[id] = { key = key, fn = fn }; return true, key end
_G.TriggerServerEvent = function(name, payload) toServer[#toServer + 1] = { name = name, payload = payload }; return true end
_G.AddEventHandler = function() end
_G.GetCurrentResourceName = function() return "op77_lightrp" end
_G.GetGameTimer = function() return 1000 end
local me = { x = 0, y = 0, z = 10 }
local keysDown = {}
_G.Open77 = {
    character = { state = function() return { position = me, yaw = 45, alive = true, attached = true } end },
    markers = {
        create = function(def) nextMarker = nextMarker + 1; markers[tostring(nextMarker)] = def; return tostring(nextMarker) end,
        remove = function(id) markers[id] = nil; return true end,
    },
    sfx = { play2d = function(e) sounds[#sounds + 1] = e end },
    vfx = { play = function() return 1 end },
    input = { isCaptured = function() return false end, isDown = function(k) return keysDown[k] == true end },
    camera = { aimRay = function() return { hit = true, position = { x = 12, y = 3, z = 10 }, distance = 12 } end },
    debugDraw = { set = function(key, batch) draws[key] = batch; return true end, clear = function(key) draws[key] = nil end },
    blips = { setWaypoint = function(p) toServer[#toServer + 1] = { name = "waypoint", payload = p }; return true end },
}
_G.LightRpEvents = {
    net = { parkour = "op77_lightrp:parkour", parkourKey = "op77_lightrp:parkour:key", parkourEditor = "op77_lightrp:parkour:editor" },
    page = { parkour = "lightrp:ui:parkour", parkourEditor = "lightrp:ui:parkoureditor", dialogClose = "lightrp:ui:dialog:close" },
}
local pageHandlers = {}
local supportMode
_G.LightRpUi = {
    log = function(fmt, ...) if os.getenv("PARKOUR_TEST_LOG") then print(string.format(fmt, ...)) end end,
    send = function(name, payload) toPage[#toPage + 1] = { name = name, payload = payload } end,
    setSupportInput = function(mode) supportMode = mode end, setMenuOpen = function() end,
    characterReady = true,
}
local function check(cond, label) if not cond then error("FAILED: " .. label, 2) end end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function lastPage(name, kind)
    for i = #toPage, 1, -1 do
        local p = toPage[i]
        if p.name == name and (not kind or (type(p.payload) == "table" and p.payload.kind == kind)) then return p.payload end
    end
end

dofile("shared/parkour.lua")
dofile("client/core/parkour.lua")
dofile("client/core/parkour_editor.lua")
local Parkour, Editor = LightRpParkourClient, LightRpParkourEditor
local page = { on = function(_, name, fn) pageHandlers[name] = fn end, setConsumedKeys = function() end, setFocus = function() return true end }
LightRpUi.page = page
Parkour.bind(page)
Editor.bind(page)
Parkour.start()
check(mappings["lightrp.parkour.restart"].key == "HOME" and mappings["lightrp.parkour.checkpoint"].key == "END", "run keys mapped")

-- start orbs: 6 courses, the 4 nearest within sight get an orb (core + beam + ring)
local list = {}
for i = 1, 6 do list[i] = { id = "c" .. i, name = "C" .. i, start = { x = i * 20, y = 0, z = 10, radius = 3 } } end
list[6].start.x = 900 -- out of sight
nets["op77_lightrp:parkour"]({ kind = "courses", courses = list })
tick(2)
check(count(markers) == 12, "4 start orbs x 3 markers: " .. count(markers))

-- keys do nothing outside a run
mappings["lightrp.parkour.restart"].fn()
check(#toServer == 0, "no key outside a run")

-- a run: the start orbs go, the next checkpoint / the one after / the finish show
local course = { id = "c1", name = "C1", difficulty = "hard", revision = 1,
    start = { x = 0, y = 0, z = 10, radius = 3, heading = 0 },
    checkpoints = { { x = 20, y = 0, z = 10, radius = 3 }, { x = 40, y = 0, z = 10, radius = 3 } },
    finish = { x = 60, y = 0, z = 10, radius = 3 } }
nets["op77_lightrp:parkour"]({ kind = "run", phase = "loading", course = course, attempt = 1, music = { file = "audio/x.webm", volume = 0.05 } })
check(lastPage("lightrp:ui:parkour", "run").music.volume == 0.05, "the run (and its music) reaches the page")
check(lastPage("lightrp:ui:dialog:close").kind == "parkour", "the card closes when the run starts")
-- next (core + trigger + beam) + later (core) + finish (core + beam) = 6
check(count(markers) == 6, "run orbs: " .. count(markers))
nets["op77_lightrp:parkour"]({ kind = "countdown", goInMs = 3000, attempt = 1 })
nets["op77_lightrp:parkour"]({ kind = "go", attempt = 1 })
mappings["lightrp.parkour.restart"].fn()
check(toServer[#toServer].name == "op77_lightrp:parkour:key" and toServer[#toServer].payload.op == "restart", "HOME restarts during a run")
mappings["lightrp.parkour.checkpoint"].fn()
check(toServer[#toServer].payload.op == "checkpoint", "END goes back to the last checkpoint")
nets["op77_lightrp:parkour"]({ kind = "cp", index = 1, total = 2, elapsedMs = 2125, attempt = 1 })
-- next = checkpoint 2 (3) + finish shown as next-after? no: the one after is the finish -> next (3) + finish (2) = 5
check(count(markers) == 5, "after checkpoint 1: " .. count(markers))
check(lastPage("lightrp:ui:parkour", "cp").elapsedMs == 2125, "the split reaches the page")
nets["op77_lightrp:parkour"]({ kind = "cp", index = 2, total = 2, elapsedMs = 4400, attempt = 1 })
check(count(markers) == 4, "next is the finish (core + trigger + beam + ring): " .. count(markers))
nets["op77_lightrp:parkour"]({ kind = "finish", timeMs = 7125, splits = "2125,4400", attempt = 1 })
check(count(markers) == 0 and #sounds > 0, "finish: the orbs go, a jingle plays")
nets["op77_lightrp:parkour"]({ kind = "result", timeMs = 7125, attempt = 1, rank = 1 })
check(lastPage("lightrp:ui:parkour", "result").rank == 1, "the result reaches the page")
pageHandlers["lightrp:ui:parkour"]({ op = "leave" })
check(toServer[#toServer].payload.op == "leave", "the card's leave reaches the server")
nets["op77_lightrp:parkour"]({ kind = "ended" })
check(Parkour.run == nil and lastPage("lightrp:ui:parkour", "ended"), "ended")
tick(2)
check(count(markers) == 12, "start orbs back after the run")

-- GPS to a course start
check(Parkour.gps("c2") == true and toServer[#toServer].payload.x == 40, "GPS to the start")
check(Parkour.gps("nope") == false, "GPS refuses an unknown course")

-- ---------------------------------------------------------------------------
-- The editor
nets["op77_lightrp:parkour:editor"]({ kind = "open" })
check(Editor.active and supportMode == "menu", "editor open in menu mode")
check(lastPage("lightrp:ui:parkoureditor", "open"), "open reaches the page")
tick(2)
check(count(markers) == 0, "no start orbs while editing")
pageHandlers["lightrp:ui:parkoureditor"]({ operation = "capture", mode = "feet", request = "r1" })
local cap = lastPage("lightrp:ui:parkoureditor", "response")
check(cap.ok and cap.data.position.x == 0 and cap.data.heading == 45, "capture at my feet")
pageHandlers["lightrp:ui:parkoureditor"]({ operation = "capture", mode = "aim", request = "r2" })
cap = lastPage("lightrp:ui:parkoureditor", "response")
check(cap.ok and cap.data.position.x == 12, "capture where I aim")
pageHandlers["lightrp:ui:parkoureditor"]({ operation = "list", request = "r3" })
tick(1)
check(toServer[#toServer].name == "op77_lightrp:parkour:editor" and toServer[#toServer].payload.operation == "list", "list forwarded to the server")
pageHandlers["lightrp:ui:parkoureditor"]({ operation = "preview", course = course, focus = "checkpoint:1", tool = { name = "checkpoint", radius = 3 } })
tick(3)
check(draws["lightrp:parkour:draft"] and #draws["lightrp:parkour:draft"].lines > 100, "the draft is drawn")
-- build mode: a click places where the crosshair hits
mappings["lightrp.parkour.editor.build"].fn()
check(Editor.mode == "world" and supportMode == "closed", "F9: build mode")
keysDown.MOUSE1 = true
tick(2)
local build = lastPage("lightrp:ui:parkoureditor", "build")
check(build and build.action == "place" and build.position.x == 12, "LEFT CLICK: a place action at the crosshair")
keysDown.MOUSE1 = nil
-- the aim at x=12 is not inside any orb (start r3 at 0, cp at 20): no hover
check(Editor.hover == nil, "nothing hovered at x=12")
mappings["lightrp.parkour.editor.build"].fn()
check(Editor.mode == "menu", "F9: back to the menu")
pageHandlers["lightrp:ui:parkoureditor"]({ operation = "close" })
check(not Editor.active and draws["lightrp:parkour:draft"] == nil, "closed: the drawing goes")

print("parkour_client_test: ok")
