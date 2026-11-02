-- Mission editor + mission run, client side: open, capture at the feet and at the
-- crosshair (heading toward the author), page <-> server relay, the 3D draft
-- preview (focus highlight), F9/F10/F11, the run's checkpoint markers and
-- perimeter walls, and cleanup.
dofile("shared/events.lua"); dofile("shared/safezones.lua"); dofile("shared/mission_defs.lua")
local E = LightRpEvents
local clock, threads, net, events, keys = { ms = 0 }, {}, {}, {}, {}
local function step(n) for _ = 1, n or 1 do clock.ms = clock.ms + 100
    for _, thread in ipairs(threads) do if coroutine.status(thread) ~= "dead" then local ok, why = coroutine.resume(thread); assert(ok, why) end end end end
GetGameTimer = function() return clock.ms end
GetCurrentResourceName = function() return "op77_lightrp" end
AddEventHandler = function(name, fn) events[name] = fn end
RegisterNetEvent = function(name, fn) net[name] = fn end
local toServer = {}
TriggerServerEvent = function(name, payload, ...) toServer[#toServer + 1] = { name = name, payload = payload, rest = { ... } } end
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
RegisterKeyMapping = function(id, _, _, fn) keys[id] = fn; return true end
local sentToPage, input = {}, {}
local pageHandlers = {}
local fakePage = { on = function(_, name, fn) pageHandlers[name] = fn end, setConsumedKeys = function() return true end, setFocus = function() return true end }
LightRpUi = { log = function() end, characterReady = true, page = fakePage,
    send = function(name, payload) sentToPage[#sentToPage + 1] = { name = name, payload = payload }; return true end,
    setSupportInput = function(mode) input[#input + 1] = mode end, setMenuOpen = function() end }
local drawn, markers, nextId = {}, {}, 0
local state = { alive = true, attached = true, position = { x = 10, y = 20, z = 3 }, yaw = 45 }
local aim = { hit = true, position = { x = 10, y = 40, z = 3 } }
local aimCalls, groupsRefused = {}, false
local blocked = {}
LightRpControlClaims = { set = function(owner, action, on) assert(owner == "missioneditor"); blocked[action] = on; return true end }
Open77 = {
    character = { state = function() return state end },
    -- like the platform: `groups` traces Static + Terrain (open ground); older clients refuse it
    camera = { aimRay = function(distance, options)
        assert(distance == 250)
        if options.groups then
            assert(options.groups[1] == "Static" and options.groups[2] == "Terrain" and options.dynamic == nil, "terrain traced")
            aimCalls[#aimCalls + 1] = "groups"
            if groupsRefused then return nil, "ray_groups_unavailable_on_this_host" end
            return aim
        end
        assert(options.dynamic == false)
        aimCalls[#aimCalls + 1] = "static"
        return aim
    end },
    debugDraw = { set = function(key, batch) drawn[key] = batch; return true end, clear = function(key) drawn[key] = nil; return true end },
    markers = { create = function(o) nextId = nextId + 1; markers[nextId] = o; return nextId end, remove = function(h) markers[h] = nil; return true end },
}
dofile("client/core/safezones.lua")
dofile("client/core/mission_editor.lua")
dofile("client/core/mission_run.lua")
local Editor = LightRpMissionEditor
Editor.start(); Editor.bind(fakePage)
local PAGE = "lightrp:ui:missioneditor"
local function last(kind) for i = #sentToPage, 1, -1 do local p = sentToPage[i].payload; if sentToPage[i].name == PAGE and p.kind == kind then return p end end end

-- open from the server
net["op77_lightrp:missioneditor"]({ kind = "open" })
assert(Editor.active and input[#input] == "menu" and last("open"), "opened in menu mode")
-- captures answered locally
pageHandlers[PAGE]({ operation = "capture", mode = "feet", request = "q1" })
local r = last("response")
assert(r.request == "q1" and r.ok and r.data.position.x == 10 and r.data.heading == 45, "feet: position + facing")
pageHandlers[PAGE]({ operation = "capture", mode = "aim", request = "q2" })
r = last("response")
assert(r.ok and r.data.position.y == 40 and math.abs(r.data.heading - 180) < 0.01, "aim: hit point, facing back at the author")
assert(aimCalls[#aimCalls] == "groups", "the aim traces the terrain group")
groupsRefused = true
pageHandlers[PAGE]({ operation = "capture", mode = "aim", request = "q2b" })
assert(last("response").ok and aimCalls[#aimCalls] == "static", "older client: static trace fallback")
groupsRefused = false
aim = { hit = false }
pageHandlers[PAGE]({ operation = "capture", mode = "aim", request = "q3" })
assert(not last("response").ok and last("response").error:find("Nothing under the crosshair"), "aim at the sky refused")
-- anything else goes to the server
pageHandlers[PAGE]({ operation = "list", request = "q4" })
step(3)
assert(toServer[#toServer].name == "op77_lightrp:missioneditor" and toServer[#toServer].payload.operation == "list", "relayed to the server")
-- the preview, with the focused spawn point highlighted
local draft = { point = { x = 0, y = 0, z = 0 }, starts = { { x = 1, y = 1, z = 0, heading = 0 } },
    perimeter = { shape = "circle", center = { x = 0, y = 0, z = 0 }, radius = 20, minZ = -5, maxZ = 10 },
    spawns = { { id = "s1", position = { x = 5, y = 5, z = 0 }, heading = 90, count = 3, trigger = "checkpoint" } },
    checkpoints = { { id = "c1", position = { x = 0, y = 8, z = 0 }, radius = 3, spawns = { "s1" } } } }
pageHandlers[PAGE]({ operation = "preview", mission = draft, focus = "spawn:s1" })
step(20)
local batch = drawn["lightrp:missions:draft"]
assert(batch and #batch.lines > 80 and #batch.triangles == 0, "perimeter, board, start, spawn and checkpoint drawn (no fill out of the perimeter page)")
local white, tie = 0, false
for _, l in ipairs(batch.lines) do
    if l.color == "#ffffffff" then white = white + 1 end
    if l.color == "#ff9f1c80" then tie = true end
end
assert(white > 0 and tie, "the focused spawn is white, the checkpoint is tied to its spawn")
-- menu mode: F10 / F11 ask the page to place the open page's element
keys["lightrp.missions.capture"]()
assert(last("captureKey").mode == "aim", "F10: where the author aims")
keys["lightrp.missions.feet"]()
assert(last("captureKey").mode == "feet", "F11: at the feet")
-- build mode
pageHandlers[PAGE]({ operation = "preview", mission = draft, build = { tool = "spawn", heading = nil, count = 3, spread = 2 } })
keys["lightrp.missions.inspector"]()
assert(Editor.mode == "world" and last("editor").mode == "world", "F9 to build mode")
assert(blocked.Attack == true and blocked.Melee == true and blocked.Grenade == true, "no shooting while building")
aim = { hit = true, position = { x = 5.4, y = 5.2, z = 0 } }      -- right next to the spawn point
step(20)
assert(last("hover").hovered.type == "spawn" and last("hover").hovered.id == "s1", "the aimed spawn point is reported")
assert(drawn["lightrp:missions:ghost"] and #drawn["lightrp:missions:ghost"].lines > 10, "the spawn ghost follows the crosshair")
local hoverWhite = false
for _, l in ipairs(drawn["lightrp:missions:ghost"].lines) do hoverWhite = hoverWhite or l.color == "#ffffffff" end
assert(hoverWhite, "the aimed element is highlighted white")
local fills = #drawn["lightrp:missions:draft"].triangles
assert(fills == 0, "no perimeter fill unless the perimeter is being edited")
keys["lightrp.missions.place"]()
local b = last("build")
assert(b.action == "place" and b.position.x == 5.4 and b.hovered.id == "s1" and math.abs(b.heading - 342.74) < 0.1, "click: place at the crosshair, facing the author")
keys["lightrp.missions.select"]()
assert(last("build").action == "select", "right click selects")
keys["lightrp.missions.remove"]()
assert(last("build").action == "delete", "Delete removes")
keys["lightrp.missions.toolNext"]()
assert(last("build").action == "tool" and last("build").delta == 1, "Down: next tool")
keys["lightrp.missions.turnLeft"]()
assert(last("build").action == "rotate" and last("build").delta == 15, "Left: turn")
pageHandlers[PAGE]({ operation = "preview", mission = draft, build = { tool = "spawn", heading = 90 } })
keys["lightrp.missions.place"]()
assert(last("build").heading == 90, "a manual facing wins")
keys["lightrp.missions.feet"]()
assert(last("build").action == "placeFeet" and last("build").position.x == 10, "F11 in build mode: at the feet")
aim = { hit = true, position = { x = 40, y = 40, z = 0 } }
step(20)
assert(last("hover").hovered == nil, "nothing aimed: hover cleared")
aim = { hit = false }
keys["lightrp.missions.place"]()
assert(last("build").action == "error", "aiming at the sky: an error, not a placement")
keys["lightrp.missions.inspector"]()
assert(Editor.mode == "menu" and blocked.Attack == false and drawn["lightrp:missions:ghost"] == nil, "back to the menu: weapons and ghost released")
-- close
pageHandlers[PAGE]({ operation = "close" })
assert(not Editor.active and drawn["lightrp:missions:draft"] == nil, "closed, preview cleared")

-- the run: checkpoints as markers, no perimeter drawn, NPC hits relayed, cleared at the end
local hello = false
for _, m in ipairs(toServer) do hello = hello or (m.name == "op77_lightrp:missionrun" and m.payload.kind == "hello") end
step(1)
for _, m in ipairs(toServer) do hello = hello or (m.name == "op77_lightrp:missionrun" and m.payload.kind == "hello") end
assert(hello, "asks for the running mission on start")
net["op77_lightrp:missionrun"]({ kind = "state", instance = "mission:1", perimeter = draft.perimeter,
    checkpoints = { { id = "c1", label = "A", position = { x = 0, y = 8, z = 0 }, radius = 3, required = true, reached = false },
        { id = "c2", label = "B", position = { x = 0, y = -8, z = 0 }, radius = 3, required = false, reached = true } } })
local count = 0; for _ in pairs(markers) do count = count + 1 end
assert(count == 1, "one marker: the unreached checkpoint")
step(20)
assert(drawn["lightrp:missions:perimeter"] == nil, "the perimeter is not drawn for the players")
-- a hit of an NPC this client owns goes to the server during the run
local before = #toServer
assert(events["open77:npcPlayerHit"], "npcPlayerHit relay")
events["open77:npcPlayerHit"]("7", "4294967300", "3", "12.5", "1")
local relayed = toServer[#toServer]
assert(#toServer == before + 1 and relayed.name == "op77_lightrp:missionrun:npcHit" and relayed.payload == "7" and relayed.rest[1] == "4294967300"
    and relayed.rest[2] == "3" and relayed.rest[3] == "12.5", "relayed with victim, npc, epoch, amount")
net["op77_lightrp:missionrun"]({ kind = "end", instance = "mission:1" })
before = #toServer; events["open77:npcPlayerHit"]("7", "1", "1", "5", "2"); assert(#toServer == before, "no relay outside a mission")
count = 0; for _ in pairs(markers) do count = count + 1 end
assert(count == 0 and drawn["lightrp:missions:perimeter"] == nil, "cleared at the end")
-- a response past 900 values reaches the page as JSON text parts (page:send and the
-- sandbox's json.encode both stop at 1024 values: the encoder is plain Lua)
do
    local missions = {}
    for i = 1, 150 do
        local spawns = {}
        for j = 1, 6 do spawns[j] = { id = "s" .. j, label = "Spawn é \"" .. j .. "\"\n", position = { x = j + 0.25, y = -j, z = 1e-3 }, count = 3, route = {} } end
        missions[i] = { id = "m" .. i, title = "Mission " .. i .. " — Kabuki", enabled = i % 2 == 0, spawns = spawns }
    end
    -- the platform encoder refuses it: no json here, on purpose
    local savedJson = json
    json = { encode = function() return nil end }
    local data = { ready = true, missions = missions, fixers = { { id = "okoro", name = "Mama Okoro" } }, empty = {} }
    local before = #sentToPage
    local event = { kind = "response", request = "big-1", ok = true, data = data }
    net["op77_lightrp:missioneditor"](event)
    json = savedJson
    local parts, joined, total = {}, {}, nil
    for i = before + 1, #sentToPage do
        local p = sentToPage[i].payload
        if p.kind == "parts" then parts[#parts + 1] = p; total = p.parts; joined[p.part] = p.text end
    end
    assert(#parts >= 2 and total == #parts, "split in parts: " .. #parts .. " " .. tostring(sentToPage[#sentToPage].payload.error))
    for _, p in ipairs(parts) do
        assert(#p.text <= 48 * 1024 and p.data == nil and p.id == parts[1].id, "small parts of one event, no table payload")
        local first = p.text:byte(1)
        assert(first < 0x80 or first >= 0xC0, "a part never starts inside a UTF-8 sequence")
    end
    local text = table.concat(joined)
    assert(text == LightRpMissionEditor.encodeJson(event), "the parts join back into the whole event")
    -- written for tools: python checks it with a strict JSON parser
    local out = io.open("tests/_editor_parts.json", "wb")
    if out then out:write(text); out:close() end
    -- a small response is relayed as is
    net["op77_lightrp:missioneditor"]({ kind = "response", request = "small-1", ok = true, data = { ready = true, missions = {} } })
    assert(sentToPage[#sentToPage].payload.data and sentToPage[#sentToPage].payload.parts == nil, "small: as is")
end

print("PASS: mission editor client (large responses in JSON parts, open, feet/aim capture, relay, preview + focus, build mode: hover, ghost, click/select/delete/tool/rotate, facing, weapons blocked, close) and mission run (markers, no perimeter drawn, NPC hit relay, cleanup)")
