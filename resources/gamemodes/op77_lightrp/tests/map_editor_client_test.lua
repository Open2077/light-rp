-- Map editor, client side (client/core/map_editor.lua on the mission editor's session): relay,
-- what the crosshair sees and what is drawn, both from the schema's layers, the shared keys going
-- to whichever editor is open, the two never open together, cleanup.
dofile("shared/events.lua"); dofile("shared/safezones.lua"); dofile("shared/mission_defs.lua")
local clock, threads, net, events, keys = { ms = 0 }, {}, {}, {}, {}
local function step(n) for _ = 1, n or 1 do clock.ms = clock.ms + 100
    for _, thread in ipairs(threads) do if coroutine.status(thread) ~= "dead" then local ok, why = coroutine.resume(thread); assert(ok, why) end end end end
GetGameTimer = function() return clock.ms end
GetCurrentResourceName = function() return "op77_lightrp" end
AddEventHandler = function(name, fn) events[name] = events[name] or {}; table.insert(events[name], fn) end
RegisterNetEvent = function(name, fn) net[name] = fn end
local toServer = {}
TriggerServerEvent = function(name, payload) toServer[#toServer + 1] = { name = name, payload = payload } end
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
local mappings = 0
RegisterKeyMapping = function(id, _, _, fn) assert(keys[id] == nil, id .. " mapped twice"); keys[id] = fn; mappings = mappings + 1; return true end
local toPage, input, handlers = {}, {}, {}
local page = { on = function(_, name, fn) handlers[name] = fn end, setConsumedKeys = function() return true end, setFocus = function() return true end }
LightRpUi = { log = function() end, characterReady = true, page = page,
    send = function(name, payload) toPage[#toPage + 1] = { name = name, payload = payload }; return true end,
    setSupportInput = function(mode) input[#input + 1] = mode end, setMenuOpen = function() end }
local drawn = {}
local refusedDraws, refuseAll = 0, false
local state = { alive = true, attached = true, position = { x = 10, y = 20, z = 3 }, yaw = 45 }
local aim = { hit = true, position = { x = 10, y = 40, z = 3 } }
local claims = {}
LightRpControlClaims = { set = function(owner, action, on) claims[owner .. ":" .. action] = on or nil; return true end }
Open77 = { character = { state = function() return state end }, camera = { aimRay = function() return aim end },
    debugDraw = { set = function(key, batch)
        -- the platform's limit: past it, or refused, nil and a reason, and the batch is not replaced
        if refuseAll or #batch.lines > 512 then refusedDraws = refusedDraws + 1; return nil, "debug_geometry_quota" end
        drawn[key] = batch; return true
    end, clear = function(key) drawn[key] = nil; return true end } }
dofile("client/core/safezones.lua")
dofile("client/core/mission_editor.lua")
dofile("client/core/map_editor.lua")
local Mission, Map = LightRpMissionEditor, LightRpMapEditor
Mission.start(); Map.start(); Map.start(); Mission.bind(page); Map.bind(page)
local NET, PAGE, MISSION_PAGE = "op77_lightrp:mapeditor", "lightrp:ui:mapeditor", "lightrp:ui:missioneditor"
local function last(kind, name) for i = #toPage, 1, -1 do local p = toPage[i]; if p.name == (name or PAGE) and p.payload.kind == kind then return p.payload end end end
assert(mappings == 10, "one set of mappings for both editors: " .. mappings)

-- nothing happens while closed
keys["lightrp.missions.inspector"]()
assert(Map.mode == "closed" and Mission.mode == "closed", "a key does nothing with no editor open")

net[NET]({ kind = "open" })
assert(Map.active and not Mission.active and input[#input] == "menu" and last("open"), "opened in menu mode")

-- the other one cannot open over it, and the other way round
net["op77_lightrp:missioneditor"]({ kind = "open" })
assert(not Mission.active and last("invalidate", MISSION_PAGE).error:find("editing missions"), "the mission editor waits")

-- captures and the relay
handlers[PAGE]({ operation = "capture", mode = "feet", request = "q1" })
assert(last("response").ok and last("response").data.position.x == 10, "at the feet")
handlers[PAGE]({ operation = "list", game = "games.tdm", request = "q2" })
step(3)
assert(toServer[#toServer].name == NET and toServer[#toServer].payload.game == "games.tdm", "relayed to the map editor's event")

-- the draft: a point, a list, the play area, nothing hidden
local map = { centre = { x = 0, y = 0, z = 0 }, radius = 30, secret = { x = 5, y = 5, z = 0 },
    spawns = { { x = 10, y = 0, z = 0, heading = 90 }, { x = -10, y = 0, z = 0 } } }
local layers = { { key = "centre", kind = "point", label = "Play area centre", color = "#ffcc00ff" }, { key = "spawns", kind = "list", label = "Spawn", color = "#3ddc84ff" } }
handlers[PAGE]({ operation = "preview", map = map, layers = layers, area = { centre = "centre", radius = "radius" }, focus = "list:spawns:2",
    build = { tool = "list:spawns", color = "#3ddc84ff" } })
step(20)
local batch = drawn["lightrp:maps:draft"]
assert(batch and #batch.lines > 100, "points and the ring are drawn")
local white, yellow, green = 0, 0, 0
for _, l in ipairs(batch.lines) do
    if l.color == "#ffffffff" then white = white + 1 elseif l.color == "#ffcc00ff" then yellow = yellow + 1 elseif l.color == "#3ddc84ff" then green = green + 1 end
end
assert(white > 0 and yellow > 0 and green > 0, "the focused spot is white, each layer has its colour")
for _, l in ipairs(batch.lines) do assert(not (l.a.x == 5 and l.a.y == 5), "a key that is no layer is not drawn") end

-- build mode: same keys, same claims, the editor's own owner
keys["lightrp.missions.inspector"]()
assert(Map.mode == "world" and last("editor").mode == "world", "F9 to build mode")
assert(claims["mapeditor:Attack"] and claims["mapeditor:Melee"] and claims["mapeditor:Grenade"], "no shooting while building")
assert(not Mission.active and Mission.mode == "closed", "the mission editor stays closed")
aim = { hit = true, position = { x = 10.5, y = 0.4, z = 0 } }
step(20)
local h = last("hover").hovered
assert(h.type == "list" and h.key == "spawns" and h.index == 1 and h.label == "Spawn 1" and h.position.x == 10, "the aimed spot is reported")
assert(drawn["lightrp:maps:ghost"] and #drawn["lightrp:maps:ghost"].lines > 10, "the ghost follows the crosshair")
aim = { hit = true, position = { x = 0.3, y = 0, z = 0 } }
step(20)
assert(last("hover").hovered.type == "point" and last("hover").hovered.key == "centre", "the aimed point")
aim = { hit = true, position = { x = 100, y = 100, z = 0 } }
step(20)
assert(last("hover").hovered == nil, "nothing aimed")

-- straight from one element to the next, nothing aimed between: the hover follows the key
do
    local pts = { { key = "a", kind = "point", label = "Control A", color = "#ffcc00ff" }, { key = "b", kind = "point", label = "Control B", color = "#22d8e2ff" },
        { key = "redSpawns", kind = "list", label = "Red spawn", color = "#ff9f1cff" }, { key = "blueSpawns", kind = "list", label = "Blue spawn", color = "#3ddc84ff" } }
    local both = { a = { x = 50, y = 0, z = 0 }, b = { x = 53, y = 0, z = 0 },
        redSpawns = { { x = 60, y = 0, z = 0 } }, blueSpawns = { { x = 63, y = 0, z = 0 } } }
    handlers[PAGE]({ operation = "preview", map = both, layers = pts, build = { tool = "move", color = "#ffffffff" } })
    aim = { hit = true, position = { x = 50, y = 0, z = 0 } }; step(20)
    assert(last("hover").hovered.key == "a", "the first point")
    aim = { hit = true, position = { x = 53, y = 0, z = 0 } }; step(20)
    assert(last("hover").hovered.key == "b", "the next point, of the same type: " .. tostring(last("hover").hovered.key))
    aim = { hit = true, position = { x = 60, y = 0, z = 0 } }; step(20)
    assert(last("hover").hovered.key == "redSpawns" and last("hover").hovered.index == 1, "a red spawn")
    aim = { hit = true, position = { x = 63, y = 0, z = 0 } }; step(20)
    assert(last("hover").hovered.key == "blueSpawns" and last("hover").hovered.index == 1, "the blue spawn of the same index")
    keys["lightrp.missions.remove"]()
    assert(last("build").hovered.key == "blueSpawns", "Delete acts on what is aimed")
    aim = { hit = true, position = { x = 100, y = 100, z = 0 } }; step(20)
    handlers[PAGE]({ operation = "preview", map = map, layers = layers, area = { centre = "centre", radius = "radius" },
        build = { tool = "list:spawns", color = "#3ddc84ff" } })
    step(20)
end

keys["lightrp.missions.place"]()
local action = last("build")
assert(action.action == "place" and action.position.x == 100 and action.heading ~= nil, "left click places")
keys["lightrp.missions.feet"]()
assert(last("build").action == "placeFeet" and last("build").position.x == 10 and last("build").heading == 45, "F11 at the feet")
keys["lightrp.missions.select"]()
assert(last("build").action == "select", "right click")
keys["lightrp.missions.remove"]()
assert(last("build").action == "delete", "Delete")
keys["lightrp.missions.toolNext"]()
assert(last("build").action == "tool" and last("build").delta == 1, "Down")
keys["lightrp.missions.turnRight"]()
assert(last("build").action == "rotate" and last("build").delta == -15, "Right")
for _, entry in ipairs(toPage) do assert(not (entry.name == MISSION_PAGE and entry.payload.kind == "build"), "no key reaches the closed mission editor") end

-- the ghosts
local g = Map.ghost({ tool = "radius", color = "#ffcc00ff" }, { x = 30, y = 0, z = 0 }, map)
assert(#g.lines == 49, "the radius tool: a circle and its spoke")
assert(#Map.ghost({ tool = "move", color = "#ffffffff" }, { x = 1, y = 1, z = 0 }, map).lines == 12, "move")
assert(#Map.ghost({ tool = "point:centre", color = "#ffcc00ff" }, { x = 1, y = 1, z = 0 }, map).lines > 12, "a point")
assert(Map.ghost(nil, { x = 1, y = 1, z = 0 }, map) == nil and Map.ghost({ tool = "move" }, nil, map) == nil, "no tool, no crosshair")
assert(Map.hovered("x", { x = 0, y = 0, z = 0 }) == nil and Map.hovered(map, nil) == nil, "junk")
assert(Map.geometry("x") == nil, "junk")
do local b = Map.geometry({ spawns = "nope", centre = { x = "a" } }); assert(b and #b.lines == 0, "a draft half written draws nothing") end

-- more points than the 512 lines take: fitted, nearest first, and the page is told
do
    local function around(batch, x)
        local n = 0
        for _, l in ipairs(batch.lines) do if math.abs(l.a.x - x) < 1.9 and math.abs(l.a.y - 20) < 1.9 and l.a.z < 4 then n = n + 1 end end
        return n
    end
    local ctf = { { key = "centre", kind = "point", label = "Centre", color = "#ffcc00ff" },
        { key = "red", kind = "list", label = "Red", color = "#ff9f1cff" }, { key = "blue", kind = "list", label = "Blue", color = "#3ddc84ff" } }
    local big = { centre = { x = 10, y = 20, z = 3, heading = 0 }, radius = 300, red = {}, blue = {} }
    for i = 1, 32 do
        big.red[i] = { x = 10 + i * 4, y = 20, z = 3, heading = 10 }
        big.blue[i] = { x = 10 - i * 4, y = 20, z = 3, heading = 10 }
    end
    local before = refusedDraws
    local function show(focus, m, l)
        handlers[PAGE]({ operation = "preview", map = m or big, layers = l or ctf, area = { centre = "centre", radius = "radius" }, focus = focus,
            build = { tool = "move", color = "#ffffffff" } })
        step(200)
        return drawn["lightrp:maps:draft"]
    end
    local b = show()
    assert(#b.lines <= 512, "fits: " .. #b.lines)
    assert(refusedDraws == before, "never refused")
    local note = last("drawing")
    assert(note and note.total == 65 and note.shown == 65 and note.full > 0 and note.full < 65, "the page hears what was simplified")
    assert(around(b, 14) == 16, "the nearest in full: " .. around(b, 14))
    local far = { x = 10 + 32 * 4, y = 20, z = 3 }
    assert(around(b, far.x) == 4, "the farthest simpler, drawn all the same: " .. around(b, far.x))

    -- the focus wins over the distance, and walking there moves the detail
    b = show("list:red:32")
    assert(#b.lines <= 512, "fits")
    local white = 0
    for _, l in ipairs(b.lines) do if l.color == "#ffffffff" then white = white + 1 end end
    assert(white == 16, "the focused point in full, however far: " .. white)
    state.position = { x = far.x, y = far.y, z = far.z }
    b = show()
    step(20)
    b = drawn["lightrp:maps:draft"]
    assert(#b.lines <= 512 and #b.lines > 100, "rebuilt")
    assert(around(b, far.x) == 16, "the point beside the author is in full now: " .. around(b, far.x))
    assert(around(b, 10 - 32 * 4) == 4, "the far side is the simple one now")
    state.position = { x = 10, y = 20, z = 3 }

    -- past what even pillars take: some points are not drawn, and that is said
    local crowd = { centre = big.centre, radius = 300, red = {} }
    for i = 1, 600 do crowd.red[i] = { x = 1000 + i, y = 20, z = 3 } end
    b = show(nil, crowd, ctf)
    assert(#b.lines == 512 and refusedDraws == before, "exactly the cap")
    note = last("drawing")
    assert(note.total == 601 and note.shown == 512 and note.full == 0, "not drawn, said")

    -- back under the cap: everything as before, and the page hears the note is over
    b = show(nil, map, layers)
    assert(last("drawing").full == last("drawing").total, "the note ends")
    assert(#b.lines > 128, "both rings again")
    local sent = 0
    for _, entry in ipairs(toPage) do if entry.payload.kind == "drawing" then sent = sent + 1 end end
    show("list:spawns:1", map, layers)
    local after = 0
    for _, entry in ipairs(toPage) do if entry.payload.kind == "drawing" then after = after + 1 end end
    assert(after == sent, "nothing to say when it fits")
end

-- F9 back to the menu, then close: nothing stays
keys["lightrp.missions.inspector"]()
assert(Map.mode == "menu" and not claims["mapeditor:Attack"], "weapons back")
assert(drawn["lightrp:maps:ghost"] == nil, "the ghost is gone")
handlers[PAGE]({ operation = "close" })
assert(not Map.active and drawn["lightrp:maps:draft"] == nil and input[#input] == "closed", "closed")

-- the page's messages do nothing while closed
handlers[PAGE]({ operation = "preview", map = map })
assert(Map.draft == nil, "no preview when closed")

-- and now the mission editor may open
net["op77_lightrp:missioneditor"]({ kind = "open" })
assert(Mission.active, "open")
net[NET]({ kind = "open" })
assert(not Map.active and last("invalidate").error:find("editing maps"), "the map editor waits")
handlers[MISSION_PAGE]({ operation = "close" })

-- a dead character closes it with a word
net[NET]({ kind = "open" })
handlers[PAGE]({ operation = "preview", map = map, layers = layers })
state = { alive = false, attached = true, position = state.position }
step(3)
assert(not Map.active and last("invalidate").error:find("Map editor closed"), "closed with a reason")
state = { alive = true, attached = true, position = { x = 10, y = 20, z = 3 }, yaw = 45 }

-- a big event reaches the page in parts on its own event
net[NET]({ kind = "open" })
do
    local big = { kind = "response", request = "big", ok = true, data = {} }
    for i = 1, 400 do big.data[i] = { x = i, y = i } end
    net[NET](big)
    step(1)
    assert(last("parts"), "parts")
end
-- the reply to "games" (1,345 values live): each game's schema goes through the native encoder, not
-- through Lua in the net handler, whose budget ended it with "The server has not answered"
do
    dofile("client/core/state_json.lua")
    local games = {}
    for g = 1, 6 do
        local points = {}
        for i = 1, 70 do points[i] = { key = "p" .. i, label = "Point " .. i, color = "#ff0000ff" } end
        games[g] = { id = "game" .. g, label = "Game " .. g, total = 1, enabled = 1, schema = { points = points } }
    end
    local reply = { kind = "response", request = "games", ok = true, data = { ready = true, games = games } }
    local count = LightRpMissionEditor.countValues(reply)
    assert(count > 1024, "as large as the live reply: " .. count)
    local native = 0
    local saved = Open77.json
    Open77.json = { encode = function(value)
        assert(LightRpMissionEditor.countValues(value) <= 1024, "the platform stops at 1,024 values")
        native = native + 1
        return LightRpStateJson.encode(value, false)
    end }
    local plain, before = LightRpStateJson.encode(reply, false), last("parts")
    local accepted = Open77.json
    Open77.json = { encode = function(value)
        if LightRpMissionEditor.countValues(value) > 1024 then error("too many values") end
        return accepted.encode(value)
    end }
    net[NET](reply)
    assert(native == 0 and last("parts") == before, "nothing encoded inside the net handler")
    step(1)
    Open77.json = saved
    assert(native == 6, "one native call per game: " .. native)
    local whole = last("parts")
    assert(whole ~= before and whole.parts == 1 and whole.text == plain, "the page gets the whole reply")
end
-- a refused wireframe is said, a nil refusal too
do
    handlers[PAGE]({ operation = "preview", map = map, layers = layers, build = { tool = "move", color = "#ffffffff" } })
    refuseAll = true
    step(20)
    refuseAll = false
    assert(last("error", LightRpEvents.page.notice), "3D preview unavailable, told")
end
-- a resource stop lets everything go
for _, fn in ipairs(events.onClientResourceStop or {}) do fn("op77_lightrp") end
assert(not Map.active, "stopped")

print("PASS: map editor client (relay, layers, hover, draft and ghost drawing, shared keys to the open editor, one editor at a time, cleanup, parts)")
