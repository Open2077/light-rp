-- op77_map3d: blip and area validation, the client (surfaces, blips, areas, owners, waypoint mirror, open)
-- and the server (targets, late joiners, cleanup). Run: pwsh -File tests/run-lua.ps1
dofile("shared/config.lua")
-- off on our servers (owner, 2026-11-06): no player positions on the map; the feature is still tested
assert(Map3DConfig.nearbyPlayers.enabled == false, "player dots are off by default")
for _, c in ipairs(Map3DConfig.page.categories) do assert(c.id ~= "player", "no Players entry in the legend") end
Map3DConfig.nearbyPlayers.enabled = true; dofile("shared/blip.lua"); dofile("shared/jam.lua"); dofile("shared/area.lua"); dofile("shared/influence.lua")
-- influence zones: touching cells are one zone, graded by players, densest first; a
-- crowd only (5 by default, never fewer than 3 whatever the setting)
do
  local I, IC = Map3DInfluence, Map3DConfig.influence
  assert(IC.minPlayers == 5 and IC.levels[1].min == 5)
  assert(I.level(5, IC.levels) == 1 and I.level(12, IC.levels) == 2 and I.level(20, IC.levels) == 3 and I.level(40, IC.levels) == 4)
  local pts = {}
  for k = 1, 7 do pts[#pts + 1] = { x = 1000 + k * 30, y = 500 + (k % 2) * 40, z = 10 } end   -- a crowd across two cells
  for k = 1, 12 do pts[#pts + 1] = { x = -500 + k * 8, y = 300, z = 4 } end                 -- a bigger one
  pts[#pts + 1] = { x = -2000, y = -2000, z = 5 }                                             -- someone alone
  pts[#pts + 1] = { x = 4000, y = 4000 }; pts[#pts + 1] = { x = 4010, y = 4005 }             -- a pair
  for k = 1, 3 do pts[#pts + 1] = { x = 7000 + k * 5, y = 7000 } end                         -- a trio
  local zones = I.cluster(pts, IC)
  assert(#zones == 2, "only the crowds make zones: no lone player, pair or trio")
  assert(zones[1].count == 12 and zones[1].level == 2 and zones[2].count == 7 and zones[2].level == 1, "densest first, graded")
  assert(zones[1].x % IC.snap == 0 and zones[1].radius >= IC.minRadius and zones[1].radius <= IC.maxRadius, "snapped and bounded")
  local loose = I.cluster(pts, { cell = IC.cell, levels = IC.levels, minPlayers = 1 })
  assert(#loose == 3 and loose[3].count == 3, "a setting below 3 is raised to 3: the trio shows, the pair and the lone player never")
  assert(I.signature(zones) == I.signature(I.cluster(pts, IC)), "stable for the same positions")
  assert(#I.cluster({}, IC) == 0)
end
-- jam validation: zones need a position and a radius; strength fades over `fade`
assert(Map3DJam.normalize({ radius = 5 }) == nil, "a zone needs a position")
local z = assert(Map3DJam.normalize({ position = { x = 0, y = 0 }, radius = 100, fade = 50, strength = 0.8 }))
assert(Map3DJam.at(z, 10, 0) == 0.8 and math.abs(Map3DJam.at(z, 125, 0) - 0.4) < 1e-9 and Map3DJam.at(z, 200, 0) == 0)
assert(Map3DJam.at(assert(Map3DJam.normalize({ strength = 3 })), nil, nil) == 1, "a direct jam is everywhere, clamped to 1")
local B = Map3DBlip

-- ---------------------------------------------------------------- validation
assert(B.normalize({}) == nil, "a blip needs a position")
local b = assert(B.normalize({ position = { x = 1, y = 2 }, color = "red", scale = 9, label = string.rep("x", 200) }))
assert(b.z == 0 and b.color == nil and b.scale == 3 and #b.label == 96 and b.category == "default" and b.map and b.minimap)
assert(B.normalize({ x = 5, y = 6, color = "#FFCC00" }).color == "#FFCC00", "flat x/y and a hex colour")
local moved = assert(B.patch(b, { x = 10 }))
assert(moved.x == 10 and moved.y == 2, "a patch with x keeps y")
assert(B.patch(b, { position = { x = 3, y = 4, z = 5 } }).z == 5)
assert(B.patch(b, { color = false }).color == nil)

-- ---------------------------------------------------------------- client
local threads, handlers, netHandlers, exported, sentToServer = {}, {}, {}, {}, {}
local function runThreads(n) for _ = 1, n or 1 do for _, t in ipairs(threads) do if coroutine.status(t) ~= "dead" then assert(coroutine.resume(t)) end end end end
_G.CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
_G.Wait = function() coroutine.yield() end
_G.GetCurrentResourceName = function() return "op77_map3d" end
local invoking = nil
_G.GetInvokingResource = function() return invoking end
_G.AddEventHandler = function(name, fn) handlers[name] = fn end
_G.RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
_G.TriggerServerEvent = function(name) sentToServer[#sentToServer + 1] = name end
local events = {}
_G.TriggerEvent = function(name, ...) events[#events + 1] = { name = name, args = { ... } } end
local function lastEvent(name) for i = #events, 1, -1 do if events[i].name == name then return events[i].args[1] end end end
_G.exports = function(name, fn) exported[name] = fn end
local keyFn
local keyMaps = {}
_G.RegisterKeyMapping = function(id, _, _, fn) if type(id) == "table" then keyMaps[id.id] = id else keyFn = fn end; return true end
local pageSent, focus = {}, { false, false }
local surfaces = {}   -- role -> { options, handlers, visible }
local function newPage(role, options)
    local s = { options = options, handlers = {}, visible = options.visible }
    surfaces[role] = s
    return {
        send = function(_, name, payload) pageSent[#pageSent + 1] = { name = name, payload = payload, role = role } end,
        on = function(_, name, fn) s.handlers[name] = fn end,
        setFocus = function(_, k, c) assert(role == "full", "only the map takes focus"); focus = { k, c }; return true end,
        setConsumedKeys = function() return true end,
        show = function() s.visible = true end,
        hide = function() s.visible = false end,
        destroy = function() s.destroyed = true end,
    }
end
-- the native surfaces (client/native/app.lua is drawn by the client; its page API is what main.lua talks to)
_G.Map3DNative = { surface = function(role, o) return newPage(role, o) end }
local nativeWp, blocked, hudMinimap = nil, nil, true
local otherCursor = false
local kvpStore = {}
_G.Open77 = {
    kvp = { get = function(k) return kvpStore[k] end, set = function(k, v) kvpStore[k] = v; return true end },
    character = { state = function() return { position = { x = 100, y = 200, z = 10 }, yaw = 10, forward = { x = -0.70710678, y = 0.70710678, z = 0 }, groundSpeed = 3, attached = true } end,
        isInVehicle = function() return false end },
    camera = { view = function() return { forward = { x = 0, y = 1, z = 0 } } end },
    players = { nearby = function() return { { id = 7, name = "Jack", position = { x = 110, y = 205, z = 10 } }, { id = 1, isLocal = true, position = { x = 100, y = 200 } } } end },
    input = { setActionBlocked = function(action, v) assert(action == "Map"); blocked = v; return true end,
        isCaptured = function() return otherCursor, otherCursor end },
    hud = { setVisible = function(c, v) assert(c == "minimap"); hudMinimap = v; return true end },
    blips = { setWaypoint = function(p) nativeWp = p; return true end, clearWaypoint = function() nativeWp = nil; return true end,
        waypoint = function() return nativeWp end },
}
dofile("client/main.lua")
local function lastPage(name) for i = #pageSent, 1, -1 do if pageSent[i].name == name then return pageSent[i].payload end end end

handlers.onClientResourceStart("op77_map3d")
assert(blocked == true and hudMinimap == false, "the native map and minimap step aside")
assert(sentToServer[1] == "op77_map3d:hello")
local reg = lastEvent("open77:mapProvider:register")
assert(reg and reg.resource == "op77_map3d" and reg.priority == 100, "registered as the pause menu's city map")
runThreads(1)
local pageHandlers, miniHandlers = surfaces.full.handlers, surfaces.mini.handlers
assert(pageHandlers["map3d:ready"] and miniHandlers["map3d:ready"], "both surfaces created")
local mo, fo = surfaces.mini.options, surfaces.full.options
assert(mo.visible, "the minimap shows from the start")
assert(not fo.visible, "the map: hidden until opened")
-- a blip before the page is ready is kept and sent on ready
invoking = "shop"
local id = exported.addBlip({ position = { x = 1, y = 2 }, icon = "store", label = "24/7", category = "service" })
assert(id and id:find("^shop#"))
assert(not lastPage("map3d:blip"), "nothing reaches a page that is not ready")
pageHandlers["map3d:ready"]({})
miniHandlers["map3d:ready"]({})
assert(lastPage("map3d:role").role == "mini", "each surface is told its role")
-- minimap zoom keys: held, sent to the minimap's surface
local zin = assert(keyMaps["op77_map3d.zoomIn"], "zoom in mapping"); assert(zin.hold and zin.key == "NUMPADPLUS")
local before = #pageSent
zin.onPressed(); keyMaps["op77_map3d.zoomOut"].onReleased()
local z1, z2 = pageSent[before + 1], pageSent[before + 2]
assert(z1.name == "map3d:miniZoom" and z1.role == "mini" and z1.payload.dir == 1 and z1.payload.down)
assert(z2.payload.dir == -1 and z2.payload.down == false)
local set = lastPage("map3d:blips").set
assert(#set == 1 and set[1].id == id and set[1].label == "24/7" and set[1].owner == nil, "ready: config + every blip")
assert(lastPage("map3d:config").theme.accent == "#FFCC00")
-- display quality: performance until the player chooses (the open map asks on its first
-- opening), kept in KVP, followed by the other map surface, replayed to a reloaded page
do
  local q = lastPage("map3d:quality")
  assert(q and q.mode == "performance" and q.chosen == false, "never chosen: performance, and the open map asks")
  local before = #pageSent
  pageHandlers["map3d:quality"]({ mode = "quality" })
  assert(kvpStore["map3d:quality"] == "quality", "kept on this machine")
  local toMini, toFull = nil, false
  for i = before + 1, #pageSent do
    local e = pageSent[i]
    if e.name == "map3d:quality" then if e.role == "mini" then toMini = e.payload elseif e.role == "full" then toFull = true end end
  end
  assert(toMini and toMini.mode == "quality" and toMini.chosen and not toFull, "the minimap follows; the map that chose is not told again")
  assert(lastEvent("op77_map3d:qualityChanged") == "quality")
  miniHandlers["map3d:quality"]({ mode = "performance" })
  assert(kvpStore["map3d:quality"] == "quality", "only the open map chooses")
  assert(exported.setQuality("ultra") == false, "unknown mode refused")
  assert(exported.setQuality("performance") and kvpStore["map3d:quality"] == "performance", "a resource can switch it")
  local mode, chosen = exported.getQuality()
  assert(mode == "performance" and chosen == true)
  local saved = pageSent
  pageSent = {}
  pageHandlers["map3d:hello"]({})
  local r = lastPage("map3d:quality")
  assert(r.mode == "performance" and r.chosen == true, "a reloaded page gets the choice")
  pageSent = saved
end
-- player feed and nearby players
runThreads(3)
local pl = lastPage("map3d:player")
assert(pl and pl.x == 100 and math.abs(pl.yaw - 45) < 1e-6 and math.abs(pl.camYaw) < 1e-6 and pl.speed == 3, "first person: the arrow follows the body's forward, not the look yaw")
-- third person: the visible body faces its motion, keeps that facing when it stops
local tpsState = { position = { x = 100, y = 200, z = 10 }, yaw = 0, forward = { x = 0, y = 1, z = 0 }, velocity = { x = 3, y = 0, z = 0 }, groundSpeed = 3, attached = true }
Open77.perspective = { get = function() return "tps" end }
local realState = Open77.character.state
Open77.character.state = function() return tpsState end
runThreads(2)
pl = lastPage("map3d:player")
assert(math.abs(pl.yaw + 90) < 1e-6, "third person: moving east (+x) faces east (yaw -90), not the camera")
tpsState.velocity = { x = 0, y = 0, z = 0 }; tpsState.groundSpeed = 0
runThreads(2)
assert(math.abs(lastPage("map3d:player").yaw + 90) < 1e-6, "standing still keeps the last facing")
Open77.character.isAiming = function() return true end
runThreads(2)
assert(math.abs(lastPage("map3d:player").yaw) < 1e-6, "aiming turns the body to the camera")
Open77.character.isAiming = nil
-- in a car reversing (moving south) while facing north: the arrow keeps the car's nose
tpsState.velocity = { x = 0, y = -4, z = 0 }; tpsState.groundSpeed = 4
Open77.character.isInVehicle = function() return true end
Open77.vehicles = { getPlayerSeat = function() return { vehicleId = 12 } end, get = function(id) assert(id == 12); return { heading = 0 } end }
runThreads(2)
pl = lastPage("map3d:player")
assert(pl.vehicle and math.abs(pl.yaw) < 1e-6, "reversing does not turn the arrow: it is the car's heading")
Open77.vehicles = nil
Open77.character.isInVehicle = function() return false end
Open77.perspective = nil
Open77.character.state = realState
-- nearby player dots: shown, hidden by a resource (at once), back when it unhides or stops
local function lastDot() for i = #pageSent, 1, -1 do local s = pageSent[i]; if s.name == "map3d:blip" and s.payload.id:find("^player:") then return s.payload, i end end end
assert(lastDot().id == "player:7" and lastDot().label == "Jack", "a nearby player is a dot")
invoking = "op77_chase"
assert(exported.setPlayerDotsHidden(true, { 7 }))
local hid = lastPage("map3d:blips")
assert(hid and hid.remove and hid.remove[1] == "player:7", "hiding removes the dot at once")
assert(exported.arePlayerDotsHidden(7) and not exported.arePlayerDotsHidden(8))
local _, mark = lastDot()
runThreads(3)
local _, after = lastDot()
assert(after == mark, "a hidden player is not drawn again")
invoking = "other"
assert(exported.setPlayerDotsHidden(false), "another resource's false does not lift the chase's hide")
runThreads(3)
assert(select(2, lastDot()) == mark and exported.arePlayerDotsHidden(7))
invoking = "op77_chase"
assert(exported.setPlayerDotsHidden(false) and not exported.arePlayerDotsHidden(7))
runThreads(3)
assert(select(2, lastDot()) > mark, "shown again")
assert(exported.setPlayerDotsHidden(true), "true alone hides every player")
assert(exported.arePlayerDotsHidden(7) and exported.arePlayerDotsHidden(1234))
assert(not exported.setPlayerDotsHidden(true, "7"), "ids must be a list")
handlers.onClientResourceStop("op77_chase")
assert(not exported.arePlayerDotsHidden(7), "a stopping resource takes its hide along")
invoking = "shop"
-- updates and ownership
assert(exported.updateBlip(id, { label = "Shop" }) and lastPage("map3d:blip").label == "Shop")
invoking = "other"
assert(not exported.updateBlip(id, { label = "x" }), "another resource cannot change it")
local named = exported.addBlip({ id = "depot", x = 5, y = 5 })
assert(named == "other:depot")
handlers.onClientResourceStop("shop")
local rem = lastPage("map3d:blips").remove
assert(#rem == 1 and rem[1] == id, "a stopping resource takes its blips along")
assert(exported.getBlip(named) and not exported.getBlip(id))
-- waypoint: export -> page route + native mirror; page -> native; native -> page
assert(exported.setWaypoint({ x = 50, y = 60, z = 1 }))
assert(lastPage("map3d:route").x == 50 and nativeWp and nativeWp.x == 50)
pageSent = {}
pageHandlers["map3d:waypoint"]({ x = 70, y = 80, z = 2 })
assert(exported.getWaypoint().x == 70 and nativeWp.x == 70, "a waypoint placed on the page is the game's too")
local toMini, toFull = false, false
for _, s in ipairs(pageSent) do if s.name == "map3d:route" then if s.role == "mini" then toMini = s.payload.x == 70 else toFull = true end end end
assert(toMini and not toFull, "a route set on the map reaches the minimap, not back to the map")
pageHandlers["map3d:waypoint"]({ clear = true })
assert(exported.getWaypoint() == nil and nativeWp == nil)
nativeWp = { x = 300, y = 400, z = 0 }  -- another resource placed the native waypoint
runThreads(4)
assert(exported.getWaypoint() and exported.getWaypoint().x == 300 and lastPage("map3d:route").x == 300, "the map follows a native waypoint")
nativeWp = nil  -- the resource that placed it cleared it, after it had been read back
runThreads(4)
assert(exported.getWaypoint() == nil, "another resource's native waypoint that disappears clears the route")
-- ours, dropped by the game (it happens while driving): placed again, the route stays
assert(exported.setWaypoint({ x = 600, y = 700 }))
runThreads(2)
assert(nativeWp and nativeWp.x == 600)
nativeWp = nil
runThreads(2)
assert(exported.getWaypoint() and exported.getWaypoint().x == 600 and nativeWp and nativeWp.x == 600, "the game dropping our waypoint does not end the route")
exported.clearWaypoint()
-- the game refuses (or has not applied yet) our waypoint: the route stays
local realSet = Open77.blips.setWaypoint
Open77.blips.setWaypoint = function() return false, "world_unavailable" end
assert(exported.setWaypoint({ x = 500, y = 600 }))
runThreads(4)
assert(exported.getWaypoint() and exported.getWaypoint().x == 500, "a refused native waypoint does not wipe ours")
Open77.blips.waypoint = function() return nil, "native_unavailable" end
runThreads(2)
assert(exported.getWaypoint(), "a waypoint read that failed is not a clear")
Open77.blips.waypoint = function() return nativeWp end
Open77.blips.setWaypoint = realSet
-- a new destination while the game still reports the old one: the new one stays
assert(exported.setWaypoint({ x = 10, y = 10 }))
runThreads(2)
nativeWp = { x = 10, y = 10, z = 0 }
runThreads(2)
local lag = true
Open77.blips.setWaypoint = function(p) if not lag then nativeWp = p end; return true end
pageHandlers["map3d:waypoint"]({ x = 900, y = 900, z = 0 })
runThreads(4)
assert(exported.getWaypoint().x == 900, "a lagging native read of the previous waypoint does not bring the old route back")
lag = false
pageHandlers["map3d:waypoint"]({ x = 950, y = 950, z = 0 })
runThreads(2)
assert(exported.getWaypoint().x == 950 and nativeWp.x == 950)
nativeWp = { x = 42, y = 42, z = 0 }  -- then another resource really picks a place
runThreads(2)
assert(exported.getWaypoint().x == 42, "a genuinely new native waypoint is still followed")
Open77.blips.setWaypoint = realSet
-- route info and arrival are events
pageHandlers["map3d:routeInfo"]({ active = true, remaining = 999 })
miniHandlers["map3d:routeInfo"]({ active = true, remaining = 120 })
assert(exported.getRoute().remaining == 120, "route events come from the minimap's surface only")
-- open / close
local fakeNow = 0
_G.GetGameTimer = function() return fakeNow end
fakeNow = 1000
keyFn()
assert(exported.isOpen() and focus[1] and focus[2] and lastPage("map3d:open"))
-- M while open: the page closes the map and the mapping sees the same press
pageHandlers["map3d:close"]({})
fakeNow = 1100; keyFn()
assert(not exported.isOpen(), "the press that closed the map does not reopen it")
fakeNow = 2000; keyFn()
assert(exported.isOpen())
pageHandlers["map3d:typing"]({ active = true })
fakeNow = 3000; keyFn()
assert(exported.isOpen(), "an m typed in the search box is not the map key")
pageHandlers["map3d:typing"]({ active = false })
assert(surfaces.full.visible and not surfaces.mini.visible, "open: the map shows, the minimap rests")
pageHandlers["map3d:close"]({})
assert(not exported.isOpen() and not focus[1] and lastPage("map3d:close"))
assert(surfaces.mini.visible, "closed: the minimap is back at once")
assert(surfaces.full.visible, "the map's surface stays up for its closing animation")
runThreads(2)
assert(not surfaces.full.visible, "closed: the map's surface is hidden after it")
-- the player's switches on the map: the minimap's surface rests, the choices reach it
local before = #pageSent
pageHandlers["map3d:prefs"]({ hud = { minimap = false }, layers = { metro = false }, hiddenCats = { "job" } })
assert(not surfaces.mini.visible, "minimap switched off: its surface is hidden")
local got
for i = before + 1, #pageSent do if pageSent[i].name == "map3d:prefs" and pageSent[i].role == "mini" then got = pageSent[i].payload end end
assert(got and got.layers.metro == false and got.hiddenCats[1] == "job", "the minimap gets the same layers and categories")
fakeNow = fakeNow + 1000; keyFn(); fakeNow = fakeNow + 1000; pageHandlers["map3d:close"]({})
assert(not surfaces.mini.visible, "closing the map does not bring a switched-off minimap back")
pageHandlers["map3d:prefs"]({ hud = { minimap = true }, layers = {}, hiddenCats = {} })
assert(surfaces.mini.visible)
-- jamming: a direct jam reaches every surface; a zone follows the player
invoking = "rp_scrambler"
local jamId = assert(exported.jam({ label = "SIGNAL LOST" }))
assert(lastPage("map3d:jam").strength == 1 and lastPage("map3d:jam").label == "SIGNAL LOST", "the pages drown in static")
assert(exported.isJammed(), "jammed")
assert(lastEvent("op77_map3d:jammed") == true)
invoking = "intruder"
assert(not exported.unjam(jamId), "another resource cannot lift it")
invoking = "rp_scrambler"
assert(exported.unjam(jamId) and lastPage("map3d:jam").strength == 0)
local zoneId = assert(exported.addJamZone({ position = { x = 100, y = 200 }, radius = 30, strength = 0.5, label = "NO MAP" }))
runThreads(2) -- the player feed puts the player at (100, 200): inside
assert(lastPage("map3d:jam").strength == 0.5 and lastPage("map3d:jam").label == "NO MAP", "a zone around the player jams")
assert(not exported.addJamZone({ strength = 1 }), "a zone needs a position and a radius")
handlers.onClientResourceStop("rp_scrambler")
assert(lastPage("map3d:jam").strength == 0 and not exported.isJammed(), "a stopping resource takes its jams along")
netHandlers["op77_map3d:jams"]({ upsert = { { id = "srv:x:j", strength = 1 } } })
assert(lastPage("map3d:jam").strength == 1, "the server's jams count too")
netHandlers["op77_map3d:jams"]({ remove = { "srv:x:j" } })
assert(lastPage("map3d:jam").strength == 0)
-- another interface takes the cursor (inventory, F1 menu): the minimap steps aside
assert(surfaces.mini.visible)
otherCursor = true
runThreads(3)
assert(not surfaces.mini.visible, "an inventory or a menu hides the minimap")
otherCursor = false
runThreads(3)
assert(surfaces.mini.visible, "and it comes back when it closes")
-- the pause menu's CITY MAP
handlers["open77:mapProvider:show"]({ provider = "someone_else", requestId = "map:0" })
assert(not exported.isOpen(), "another provider's request is not ours")
handlers["open77:mapProvider:show"]({ provider = "op77_map3d", requestId = "map:1" })
assert(exported.isOpen() and lastEvent("open77:mapProvider:shown").requestId == "map:1", "opened and answered")
pageHandlers["map3d:close"]({})
events = {}
handlers["open77:mapProvider:query"]()
assert(lastEvent("open77:mapProvider:register"), "announces itself again when the menu asks")
-- moving the minimap gives it a new surface (the native document places it)
local oldMini = surfaces.mini
exported.setConfig({ minimap = { anchor = "bottom-left" } })
runThreads(1)
assert(oldMini.destroyed and surfaces.mini ~= oldMini)
miniHandlers = surfaces.mini.handlers
miniHandlers["map3d:ready"]({})
-- runtime config survives a page reload
exported.setTheme({ accent = "#3FE0D0" })
pageSent = {}
pageHandlers["map3d:hello"]({})
local patches = 0
for _, s in ipairs(pageSent) do if s.name == "map3d:config" then patches = patches + 1 end end
assert(patches == 3, "base config, then the runtime minimap and theme patches")
-- influence zones from the server reach the map pages, and a page that reloads gets them back
netHandlers["op77_map3d:influence"]({ enabled = true, levels = { { min = 1, id = "low", label = "QUIET" } },
  zones = { { id = "z1", x = 10, y = 20, z = 3, radius = 120, count = 4, level = 2 }, { id = "bad", x = "?" } } })
local inf = lastPage("map3d:influence")
assert(inf and inf.enabled and #inf.zones == 1 and inf.zones[1].count == 4 and inf.levels[1].label == "QUIET", "invalid zones dropped")
assert(lastEvent("op77_map3d:influenceChanged").zones[1].id == "z1", "other resources hear about them")
-- The runtime delivers a local TriggerEvent to RegisterNetEvent handlers too: the
-- client must never re-raise the server's own event name (it looped forever).
assert(lastEvent("op77_map3d:influence") == nil, "the server's event is not re-raised locally")
exported.setInfluenceVisible(false)
assert(lastPage("map3d:influenceVisible").visible == false)
pageSent = {}
pageHandlers["map3d:hello"]({})
assert(lastPage("map3d:influence").zones[1].id == "z1" and lastPage("map3d:influenceVisible").visible == false, "replayed to a reloaded page")
exported.setInfluenceVisible(true)
assert(exported.getInfluence().enabled)
-- areas: validation, ids per resource, replace, the cap, update/remove by their owner only,
-- a reloaded page gets them back (oldest first), a stopping resource takes its own along
do
  local A, was = Map3DArea, invoking
  local sq = { { x = 0, y = 0 }, { 100, 0 }, { x = 100, y = 100 }, { 0, 100 } }
  assert(not A.normalize({ points = { { 0, 0 }, { 1, 1 } } }), "fewer than 3 points")
  assert(not A.normalize({ points = { { 0, 0 }, { 1, 1 }, { 2, 2 } } }), "a line encloses nothing")
  assert(not A.normalize({ points = { { 0, 0 }, { 0 / 0, 1 }, { 2, 0 } } }), "NaN")
  assert(not A.normalize({ points = { { 0, 0 }, { math.huge, 1 }, { 2, 0 } } }), "infinite")
  assert(not A.normalize({ points = { { 0, 0 }, { "x", 1 }, { 2, 0 } } }), "not a number")
  assert(not A.normalize({ points = { { 0, 0 }, { 1e6, 1 }, { 2, 0 } } }), "far outside Night City")
  local many = {}
  for k = 1, A.MAX_POINTS + 1 do local t = k / (A.MAX_POINTS + 1) * 2 * math.pi; many[k] = { math.cos(t) * 100, math.sin(t) * 100 } end
  assert(select(2, A.normalize({ points = many })):find("at most 160"), "the point cap")
  many[#many] = nil
  local big = assert(A.normalize({ points = many }), "160 points are fine")
  assert(select(2, A.normalize({ points = sq, fill = "red" })):find("fill"), "a colour is #rrggbb")
  assert(not A.normalize({ points = sq, stroke = "#12345" }) and not A.normalize({ points = sq, pattern = "dots" }))
  assert(not A.normalize({ points = sq, labelPosition = { x = 1 } }) and not A.normalize({ points = sq, label = 5 }))
  local a = assert(A.normalize({ points = sq, fill = "#f00", fillOpacity = 3, strokeWidth = 99, label = string.rep("z", 99) }))
  assert(a.fill == "#FF0000" and a.stroke == "#FF0000" and a.fillOpacity == 1 and a.strokeWidth == 8 and #a.label == 64)
  assert(a.pattern == "hatch" and a.map and a.minimap and not a.pulse, "hatched, on both maps, still by default")
  local d = assert(A.normalize({ points = sq }))
  assert(d.fill == "#FF2E3C" and d.stroke == "#FF2E3C" and d.fillOpacity == 0.22 and d.strokeWidth == 2, "defaults: the danger red")
  assert(A.contains(d, 50, 50) and not A.contains(d, 150, 50))
  local p = A.patch(a, { fill = "#00FF00" })
  assert(p.fill == "#00FF00" and p.stroke == "#00FF00", "a new fill carries a matching stroke along")
  assert(A.patch(assert(A.normalize({ points = sq, stroke = "#FFFFFF" })), { fill = "#00FF00" }).stroke == "#FFFFFF", "an own stroke stays")
  assert(A.patch(a, { label = false }).label == nil and not A.patch(a, { pattern = "x" }))
  local pg = A.page("x", assert(A.normalize({ points = sq, labelPosition = { 5, 6 } })))
  assert(#pg.pts == 8 and pg.pts[3] == 100 and pg.pts[4] == 0 and pg.lx == 5 and pg.ly == 6 and pg.lz == nil, "the page gets a flat outline")
  -- what the host counts (every table, key and value): the largest definition fits an export
  -- argument and its page event, both limited to 1024 values
  local function values(v) if type(v) ~= "table" then return 1 end; local n = 1; for _, x in pairs(v) do n = n + 1 + values(x) end; return n end
  local def = { id = "dogtown", points = many, fill = "#FF2E3C", fillOpacity = 0.22, stroke = "#FF2E3C", strokeWidth = 2.5, pattern = "hatch",
    label = "DOGTOWN - DANGER ZONE", labelPosition = { x = 1, y = 2, z = 3 }, map = true, minimap = true, pulse = false }
  assert(values(def) <= 1024, "a 160-point definition is an export argument (" .. values(def) .. " values)")
  big.label, big.labelPosition = def.label, { x = 1, y = 2, z = 3 }
  assert(values(A.page("op77_lightrp:lightrp.dogtown", big)) < 760, "and its page event leaves room to spare")

  invoking = "turf"
  pageSent = {}
  local id1 = assert(exported.addArea({ id = "zone", points = sq, label = "TURF" }))
  assert(id1 == "turf:zone", "an id is the resource's")
  local ev = lastPage("map3d:area")
  assert(ev.id == id1 and #ev.pts == 8 and ev.label == "TURF" and ev.pattern == "hatch")
  local roles = {}
  for _, s in ipairs(pageSent) do if s.name == "map3d:area" then roles[s.role] = true end end
  assert(roles.mini and roles.full, "the map and the minimap draw it")
  local none, why = exported.addArea({ points = { { 0, 0 } } })
  assert(none == nil and why:find("3 points"), "a refused definition says why")
  assert(not exported.addArea({ id = string.rep("i", 65), points = sq }))
  assert(exported.addArea({ id = "zone", points = sq, label = "TURF 2" }) == id1 and exported.getArea("zone").label == "TURF 2", "the same id replaces it")
  local anon = assert(exported.addArea({ points = sq }))
  assert(anon:find("^turf#area"))
  -- update: by the owner, with or without the namespace; a refused patch changes nothing
  assert(exported.updateArea("zone", { fill = "#3FE0D0" }) and lastPage("map3d:area").fill == "#3FE0D0" and lastPage("map3d:area").stroke == "#3FE0D0")
  assert(exported.updateArea(id1, { pulse = true }) and exported.getArea(id1).pulse)
  local ok, err = exported.updateArea("zone", { fill = "nope" })
  assert(not ok and err:find("fill") and exported.getArea(id1).fill == "#3FE0D0")
  assert(select(2, exported.updateArea("nothing", { label = "x" })) == "unknown area")
  local copy = exported.getArea(id1)
  copy.points[1].x = 999
  assert(exported.getArea(id1).points[1].x == 0 and copy.owner == nil, "getArea hands out a copy")
  invoking = "intruder"
  assert(not exported.updateArea(id1, { label = "x" }) and not exported.removeArea(id1), "another resource cannot touch it")
  assert(exported.getArea("zone") == nil, "a bare id is the caller's own")
  -- 16 a resource (the map draws 16 at a time); replacing one is not a new one
  invoking = "turf"
  for k = 3, A.MAX_PER_OWNER do assert(exported.addArea({ id = "a" .. k, points = sq })) end
  local over, msg = exported.addArea({ id = "one-more", points = sq })
  assert(over == nil and msg:find("16"), "16 areas a resource")
  assert(exported.addArea({ id = "zone", points = sq }) == id1)
  invoking = "other"
  assert(exported.addArea({ id = "zone", points = sq }) == "other:zone", "the cap is per resource")
  invoking = "turf"
  assert(exported.removeArea("a3") and lastPage("map3d:areas").remove[1] == "turf:a3")
  assert(not exported.removeArea("a3"), "already gone")
  -- a page that reloads forgets what it had, then gets every area, oldest first
  pageSent = {}
  pageHandlers["map3d:hello"]({})
  local cleared, order = false, {}
  for _, s in ipairs(pageSent) do
    if s.role == "full" and s.name == "map3d:areas" and s.payload.clear then cleared = true end
    if s.role == "full" and s.name == "map3d:area" then assert(cleared, "cleared before the replay"); order[#order + 1] = s.payload.id end
  end
  assert(#order == 16 and order[1] == id1 and order[#order] == "other:zone", "replayed in drawing order (" .. #order .. ")")
  -- a stopping resource takes its areas along, not the others'
  handlers.onClientResourceStop("turf")
  assert(#lastPage("map3d:areas").remove == 15 and exported.getArea(id1) == nil and exported.getArea("other:zone"))
  invoking = "other"
  assert(exported.clearAreas() == 1 and exported.getArea("other:zone") == nil)
  invoking = was
end
-- server blips
netHandlers["op77_map3d:blips"]({ set = { { id = "srv:x:1", x = 9, y = 9, label = "Garage" } } })
assert(lastPage("map3d:blips").upsert[1].id == "srv:x:1")
handlers.onClientResourceStop("op77_map3d")
assert(blocked == false and hudMinimap == true, "the native map and minimap come back")
assert(lastEvent("open77:mapProvider:withdraw").resource == "op77_map3d", "withdrawn from the pause menu on stop")

-- ---------------------------------------------------------------- server
local sHandlers, sNet, sExports, toClient = {}, {}, {}, {}
_G.AddEventHandler = function(name, fn) sHandlers[name] = fn end
_G.RegisterNetEvent = function(name, fn) sNet[name] = fn end
_G.exports = function(name, fn) sExports[name] = fn end
_G.GetPlayers = function() return { "1", "2" } end
_G.TriggerClientEvent = function(name, target, payload) toClient[#toClient + 1] = { name = name, target = target, payload = payload } end
local sCommands = {}
_G.RegisterCommand = function(name, fn, restricted) assert(restricted, name .. " is staff only"); sCommands[name] = fn end
dofile("server/main.lua")
invoking = "jobs"
local all = assert(sExports.addBlip(-1, { id = "depot", x = 1, y = 1, label = "Depot" }))
assert(all == "srv:jobs:depot" and #toClient == 2, "everyone gets it")
toClient = {}
local mine = assert(sExports.addBlip(2, { x = 5, y = 5, label = "Your car" }))
assert(#toClient == 1 and toClient[1].target == 2)
toClient = {}
_G.source = 1; sNet["op77_map3d:hello"]()
assert(#toClient[1].payload.set == 1 and toClient[1].payload.set[1].id == all, "a late joiner gets only what is meant for it")
toClient = {}
_G.source = 2; sNet["op77_map3d:hello"]()
assert(#toClient[1].payload.set == 2)
invoking = "other"
assert(not sExports.updateBlip(all, { label = "x" }), "only the owner updates")
toClient = {}
sHandlers.onResourceStop("jobs")
assert(#toClient == 3, "the owner stops: removed for everyone it was shown to")
assert(sExports.setWaypoint(2, { x = 1, y = 2 }) and toClient[#toClient].name == "op77_map3d:waypoint")
-- server jams: everyone gets them, late joiners too, the owner's stop lifts them
invoking = "blackout"
toClient = {}
local sj = assert(sExports.addJamZone(-1, { id = "zone", position = { x = 0, y = 0 }, radius = 500, label = "NO SIGNAL" }))
assert(sj == "srv:blackout:zone" and #toClient == 2 and toClient[1].name == "op77_map3d:jams" and toClient[1].payload.upsert[1].radius == 500)
assert(not sExports.addJamZone(-1, { strength = 1 }), "a server zone needs a position and a radius")
toClient = {}
_G.source = 1; sNet["op77_map3d:hello"]()
local jamSync
for _, e in ipairs(toClient) do if e.name == "op77_map3d:jams" then jamSync = e.payload end end
assert(jamSync and #jamSync.set == 1 and jamSync.set[1].id == sj, "a late joiner gets the jams meant for it")
toClient = {}
sHandlers.onResourceStop("blackout")
assert(#toClient == 2 and toClient[1].payload.remove[1] == sj, "the owner stops: lifted for everyone")
-- staff commands
toClient = {}
sCommands["map3d.jam"](0, { "2", "0.6", "NO", "MAP", n = 4 })
assert(#toClient == 1 and toClient[1].target == 2 and toClient[1].payload.upsert[1].strength == 0.6 and toClient[1].payload.upsert[1].label == "NO MAP")
toClient = {}
sCommands["map3d.unjam"](0, { n = 0 })
assert(#toClient == 1 and toClient[1].payload.remove[1], "unjam lifts the command's jams")
-- influence zones on the server: grouped per bucket, sent when they change, hidden
-- players left out, the owner's switch
do
  -- players 1..6 together in the street, 7..11 in a mission instance
  local pos = {}
  for id = 1, 6 do pos[id] = { x = 100 + id * 10, y = 100, z = 5, bucket = 0 } end
  for id = 7, 11 do pos[id] = { x = 100 + id * 10, y = 100, z = 5, bucket = 3000001 } end
  Open77.players.positions = function() return pos end
  local function influenceFor(target)
    for i = #toClient, 1, -1 do local e = toClient[i]; if e.name == "op77_map3d:influence" and e.target == target then return e.payload end end
  end
  toClient = {}
  _G.source = 1; sNet["op77_map3d:hello"]()
  local inf = influenceFor(1)
  assert(inf and inf.enabled and #inf.zones == 1 and inf.zones[1].count == 6 and inf.levels[1].label == "ACTIVE", "the hello carries the zones")
  -- player 2 joins the instance: 5 left in the street (still a zone), 6 in the instance
  pos[2].bucket = 3000001
  toClient = {}
  sExports.setInfluenceEnabled(true)
  assert(influenceFor(1).zones[1].count == 5 and influenceFor(2).zones[1].count == 6, "zones stay in their bucket")
  -- one more leaves the street: 4 people are not a crowd, and nobody's position is sent
  pos[6] = { x = 5000, y = 5000, z = 5, bucket = 0 }
  toClient = {}
  sExports.setInfluenceEnabled(true)
  assert(#influenceFor(1).zones == 0, "below the threshold there is no zone, not even the lone player's")
  pos[6] = { x = 160, y = 100, z = 5, bucket = 0 }
  -- nothing changed: nothing sent
  toClient = {}
  sExports.setInfluenceEnabled(true)
  local again = 0 for _, e in ipairs(toClient) do if e.name == "op77_map3d:influence" then again = again + 1 end end
  assert(again == 2, "a fresh enable resends to everyone")
  -- hidden players are left out: the instance falls from 6 to 4, under the threshold
  sExports.setInfluenceHidden(7, true); sExports.setInfluenceHidden(8, true)
  assert(#sExports.getInfluenceZones(3000001) == 0 and #sExports.getInfluenceZones(0) == 1)
  -- the server owner turns it off: everyone is told, nothing more is sent
  toClient = {}
  sCommands["map3d.influence"](0, { "off", n = 1 })
  assert(influenceFor(1).enabled == false and #influenceFor(1).zones == 0 and influenceFor(2).enabled == false)
  assert(not sExports.isInfluenceEnabled() and #sExports.getInfluenceZones(0) == 0)
  toClient = {}
  _G.source = 1; sNet["op77_map3d:hello"]()
  assert(influenceFor(1).enabled == false, "a late joiner learns it is off")
  sCommands["map3d.influence"](0, { "on", n = 1 })
  assert(sExports.isInfluenceEnabled())
end

print("PASS: map3d blips (validation, owners, cleanup), page lifecycle, waypoint mirror both ways, open/close focus, runtime config replay, server targets and late joiners")
