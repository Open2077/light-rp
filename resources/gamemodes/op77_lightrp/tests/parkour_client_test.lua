-- Parkour, client side (client/core/parkour.lua, parkour_editor.lua) with the host stubbed:
-- a ring + light column for the nearest starts only, the run shows the checkpoint to reach and
-- the finish, no marker is ever updated (an update while loading restarts it: the points
-- flickered), the runner is held until GO, the bearing reaches the page, every
-- server event reaches the page, the keys go to the server only during a run, the editor
-- relays, captures, draws the draft and turns build clicks into page actions.
local threads = {}
_G.CreateThread = function(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; local ok, err = coroutine.resume(co); if not ok then error(err, 0) end end
_G.Wait = function() coroutine.yield() end
local clock = 1000
local function tick(n)
    for _ = 1, n or 1 do
        clock = clock + 50
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
_G.GetGameTimer = function() return clock end
local me = { x = 0, y = 0, z = 10 }
local keysDown = {}
local frozen, updates = false, 0
_G.Open77 = {
    character = { state = function() return { position = me, yaw = 45, alive = true, attached = true } end,
        setFrozen = function(v) frozen = v == true; return true end },
    markers = {
        create = function(def)
            -- the marker API's ranges (wiki/markers.md): anything outside is invalid_argument in game
            assert(def.shape == "ring" or def.shape == "cylinder", "only rings and beams: " .. tostring(def.shape))
            assert(def.radius >= 0.1 and def.radius <= 50 and def.height >= 0.01 and def.height <= 100, "radius/height in range")
            assert(def.maxDistance >= 1 and def.maxDistance <= 500, "maxDistance in range")
            nextMarker = nextMarker + 1; markers[tostring(nextMarker)] = def; return tostring(nextMarker) end,
        remove = function(id) markers[id] = nil; return true end,
        update = function(id, patch) if markers[id] then updates = updates + 1; markers[id].position = patch.position end; return true end,
        list = function() local out = {} for _, m in pairs(markers) do out[#out + 1] = m end return out end,
    },
    sfx = { play2d = function(e) sounds[#sounds + 1] = e end },
    vfx = { play = function() return 1 end },
    input = { isCaptured = function() return false end, isDown = function(k) return keysDown[k] == true end },
    camera = { aimRay = function() return { hit = true, position = { x = 12, y = 3, z = 10 }, distance = 12 } end },
    -- the real limits (Open77.debugDraw.set): 512 lines per batch, refused whole past it
    debugDraw = { set = function(key, batch) if #batch.lines > 512 then return false, "invalid_debug_primitives" end; draws[key] = batch; return true end,
        clear = function(key) draws[key] = nil end },
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
local function shapes() local out = {} for _, m in pairs(markers) do out[m.shape] = (out[m.shape] or 0) + 1 end return out end
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
-- the orbs' markers are created one per frame: every server event, then enough frames
local function park(p) nets["op77_lightrp:parkour"](p); tick(20) end
local page = { on = function(_, name, fn) pageHandlers[name] = fn end, setConsumedKeys = function() end, setFocus = function() return true end }
LightRpUi.page = page
Parkour.bind(page)
Editor.bind(page)
Parkour.start()
check(mappings["lightrp.parkour.restart"].key == "HOME" and mappings["lightrp.parkour.checkpoint"].key == "END"
    and mappings["lightrp.parkour.leave"].key == "DELETE", "run keys mapped (leave on DELETE: F1 is the menu)")

-- starts: 6 courses, the 3 nearest within sight get a ring and a light column
local list = {}
for i = 1, 6 do list[i] = { id = "c" .. i, name = "C" .. i, start = { x = i * 20, y = 0, z = 10, radius = 3, heading = 90 } } end
list[6].start.x = 900 -- out of sight
park({ kind = "courses", courses = list })
tick(40)
check(count(markers) == 6, "3 starts x 2 markers: " .. count(markers))
local sh = shapes()
check(sh.ring == 3 and sh.cylinder == 3, "a start = a ring on the ground and a light column")
for _, m in pairs(markers) do
    check(m.maxDistance == 80, "a start shows only from close by (80 m)")
    if m.shape == "ring" then check(m.position.z == 10.05 and m.radius == 3, "the start ring lies on the ground, the trigger's size") end
end
tick(20)
check(updates == 0, "no marker is ever updated")

-- keys do nothing outside a run
mappings["lightrp.parkour.restart"].fn()
check(#toServer == 0, "no key outside a run")

-- a run: the start orbs go, the next checkpoint / the one after / the finish show
local course = { id = "c1", name = "C1", difficulty = "hard", revision = 1,
    start = { x = 0, y = 0, z = 10, radius = 3, heading = 0 },
    checkpoints = { { x = 20, y = 0, z = 10, radius = 3 }, { x = 40, y = 0, z = 10, radius = 3 } },
    finish = { x = 60, y = 0, z = 10, radius = 3 } }
park({ kind = "run", phase = "loading", course = course, attempt = 1, music = { file = "audio/x.webm", volume = 0.05 } })
check(lastPage("lightrp:ui:parkour", "run").music.volume == 0.05, "the run (and its music) reaches the page")
check(lastPage("lightrp:ui:dialog:close").kind == "parkour", "the card closes when the run starts")
-- the checkpoint to reach (ring + column) and the finish (ring + column)
tick(10)
check(count(markers) == 4, "run markers: " .. count(markers))
for _, m in pairs(markers) do
    if m.shape == "ring" and m.position.x == 20 then check(m.radius == 3 and m.position.z == 10.05, "the checkpoint ring lies on the ground, the trigger's size") end
    if m.shape == "cylinder" then check(m.maxDistance == 500 and m.height == 90, "the beam is seen from far away") end
end
park({ kind = "countdown", goInMs = 3000, attempt = 1 })
check(frozen == true, "held on the start during the countdown")
park({ kind = "go", attempt = 1 })
check(frozen == false, "released at GO")
tick(4)
local br = lastPage("lightrp:ui:parkour", "bearing")
check(br and br.label == "CP 1" and br.distance == 20, "the bearing to checkpoint 1 reaches the page")
mappings["lightrp.parkour.restart"].fn()
check(toServer[#toServer].name == "op77_lightrp:parkour:key" and toServer[#toServer].payload.op == "restart", "HOME restarts during a run")
mappings["lightrp.parkour.checkpoint"].fn()
check(toServer[#toServer].payload.op == "checkpoint", "END goes back to the last checkpoint")
mappings["lightrp.parkour.leave"].fn()
check(toServer[#toServer].payload.op == "leave", "DELETE leaves the run")
park({ kind = "cp", index = 1, total = 2, elapsedMs = 2125, attempt = 1 })
tick(20)
check(count(markers) == 4, "after checkpoint 1: checkpoint 2 and the finish: " .. count(markers))
check(lastPage("lightrp:ui:parkour", "cp").elapsedMs == 2125, "the split reaches the page")
park({ kind = "cp", index = 2, total = 2, elapsedMs = 4400, attempt = 1 })
tick(20)
check(count(markers) == 2, "only the finish left: " .. count(markers))
check(lastPage("lightrp:ui:parkour", "bearing").label == "FINISH", "the bearing points at the finish")
park({ kind = "finish", timeMs = 7125, splits = "2125,4400", attempt = 1 })
tick(20)
check(count(markers) == 0 and #sounds > 0 and updates == 0, "finish: the points go, a jingle plays, nothing was ever updated")
park({ kind = "result", timeMs = 7125, attempt = 1, rank = 1 })
check(lastPage("lightrp:ui:parkour", "result").rank == 1, "the result reaches the page")
pageHandlers["lightrp:ui:parkour"]({ op = "leave" })
check(toServer[#toServer].payload.op == "leave", "the card's leave reaches the server")
park({ kind = "ended" })
check(Parkour.run == nil and lastPage("lightrp:ui:parkour", "ended"), "ended")
tick(40)
check(count(markers) == 6, "starts back after the run")
check(lastPage("lightrp:ui:parkour", "bearing").hide == true, "the bearing hides after the run")

-- GPS to a course start
check(Parkour.gps("c2") == true and toServer[#toServer].payload.x == 40, "GPS to the start")
check(Parkour.gps("nope") == false, "GPS refuses an unknown course")

-- ---------------------------------------------------------------------------
-- The editor
nets["op77_lightrp:parkour:editor"]({ kind = "open" })
check(Editor.active and supportMode == "menu", "editor open in menu mode")
check(lastPage("lightrp:ui:parkoureditor", "open"), "open reaches the page")
tick(2)
tick(20)
check(count(markers) == 0, "no starts while editing")
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
local function drawn() local n, parts = 0, 0 for k, b in pairs(draws) do if k:find("^lightrp:parkour:draft") then n = n + #b.lines; parts = parts + 1 end end return n, parts end
local lines = drawn()
check(lines > 100, "the draft is drawn")
-- a long course (50 checkpoints): several batches, each under the 512-line limit, nothing refused
local long = { start = course.start, finish = { x = 1100, y = 0, z = 10, radius = 3 }, checkpoints = {} }
for i = 1, 50 do long.checkpoints[i] = { x = 20 * i, y = (i % 2) * 5, z = 10, radius = 3 } end
pageHandlers["lightrp:ui:parkoureditor"]({ operation = "preview", course = long, tool = { name = "checkpoint", radius = 3 } })
tick(80)
local longLines, parts = drawn()
check(longLines > 52 * 30 and parts >= 4, "a 50-checkpoint course is drawn whole, in several batches: " .. longLines .. " lines, " .. parts .. " batches")
pageHandlers["lightrp:ui:parkoureditor"]({ operation = "preview", course = course, tool = { name = "checkpoint", radius = 3 } })
tick(80)
local _, fewer = drawn()
check(fewer == 1, "back to a short course: the extra batches go (" .. fewer .. ")")
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
check(not Editor.active and select(2, drawn()) == 0, "closed: the drawing goes")

print("parkour_client_test: ok")
