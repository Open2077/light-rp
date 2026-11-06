-- The Maneki-neko client (client/core/maneki.lua, maneki_editor.lua) with the host stubbed:
-- streamed cats become local props with a private E prompt, the camera ray hits a cat
-- straight ahead and misses one beside it, a wall in between blocks the shot, the trigger
-- sends one shot per cat, a find removes the prop; the staff tool places on a click.
setmetatable = nil -- the client sandbox has none (memory: client-lua-sandbox-no-setmetatable)
local threads = {}
local function tick(n)
    for _ = 1, n or 1 do
        for i = #threads, 1, -1 do
            local co = threads[i]
            if coroutine.status(co) == "dead" then table.remove(threads, i)
            else local ok, err = coroutine.resume(co); if not ok then error(err) end end
        end
    end
end
_G.CreateThread = function(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; local ok, err = coroutine.resume(co); if not ok then error(err) end end
_G.Wait = function() coroutine.yield() end
local clock = 0
_G.GetGameTimer = function() return clock end
_G.GetCurrentResourceName = function() return "op77_lightrp" end
local events = {}
_G.AddEventHandler = function(name, fn) events[name] = fn end
local mapCalls = {}
_G.GetResourceState = function(name) return name == "op77_map3d" and "running" or "missing" end
local function mapStub(method) return function(_, ...) mapCalls[#mapCalls + 1] = { method = method, args = { ... } }; return method == "addBlip" and ("op77_lightrp:" .. tostring((...).id)) or true end end
_G.exports = { op77_map3d = { addBlip = mapStub("addBlip"), removeBlip = mapStub("removeBlip"), open = mapStub("open"), focus = mapStub("focus") } }
local net, server, page = {}, {}, {}
_G.RegisterNetEvent = function(name, fn) net[name] = fn end
_G.TriggerServerEvent = function(name, payload) server[#server + 1] = { name = name, payload = payload } end

local props, nextProp, removed = {}, 0, 0
local view = { position = { x = 0, y = 0, z = 1.6 }, forward = { x = 0, y = 1, z = 0 } }
local wall, firingNow, keys, markers = nil, false, {}, 0
_G.Open77 = {
    props = {
        create = function(def) nextProp = nextProp + 1; props[tostring(nextProp)] = def; return tostring(nextProp) end,
        remove = function(h) if props[h] then props[h] = nil; removed = removed + 1 end; return true end,
        setTransform = function(h, t) if props[h] then props[h].position = t.position end; return true end,
    },
    camera = {
        view = function() return view end,
        aimRay = function(max, opts)
            if wall then return { hit = true, distance = wall, position = { x = 0, y = wall, z = 1.6 }, normal = { x = 0, y = -1, z = 0 } } end
            return { hit = true, distance = 10, position = { x = 0, y = 10, z = 0 }, normal = { x = 0, y = 0, z = 1 } }
        end,
    },
    character = {
        state = function() return { position = { x = 0, y = 0, z = 0 } } end,
        aimState = function() return { firing = firingNow, weaponDrawn = true } end,
    },
    input = { isDown = function(k) return keys[k] == true end, isCaptured = function() return false end },
    markers = { create = function() markers = markers + 1; return markers end, remove = function() return true end },
    vfx = { play = function() return 1 end }, sfx = { play2d = function() return true end },
    world = { district = function() return { district = "Watson", subDistrict = "Kabuki" } end },
}
_G.LightRpEvents = { page = { maneki = "lightrp:ui:maneki" },
    net = { maneki = "op77_lightrp:maneki", manekiCollect = "op77_lightrp:maneki:collect", manekiEdit = "op77_lightrp:maneki:edit" } }
_G.LightRpEvents.page.dialog = "lightrp:ui:dialog"; _G.LightRpEvents.page.dialogClose = "lightrp:ui:dialog:close"
local pageNamed = {}
_G.LightRpUi = { log = function() end, send = function(name, p) page[#page + 1] = p; pageNamed[#pageNamed + 1] = { name = name, p = p } end, setMenuOpen = function() end }
local prompts = {}
_G.LightRpInteract = { setLocal = function(id, entry, cb) prompts[id] = entry and { entry = entry, cb = cb } or nil end }
_G.LightRpControlClaims = { set = function() return true end }

dofile("client/core/maneki.lua")
dofile("client/core/maneki_editor.lua")
local M = LightRpManeki
local function sentOf(name) local n, last = 0, nil for _, s in ipairs(server) do if s.name == name then n = n + 1; last = s.payload end end return n, last end
local function propCount() local n = 0 for _ in pairs(props) do n = n + 1 end return n end

-- Two cats: one straight ahead at 10 m, one 0.6 m to its side.
net["op77_lightrp:maneki"]({ kind = "near", model = "open77\\assets\\op77_lightrp\\maneki\\maneki_neko.ent", height = 0.16,
    spots = { { id = "a", x = 0, y = 10, z = 1.52, yaw = 0, s = 1 }, { id = "b", x = 0.6, y = 10, z = 1.52, yaw = 0, s = 1 } } })
tick()
assert(propCount() == 2, "two local props")
assert(props["1"].model:find("maneki_neko.ent", 1, true) and props["1"].collision == false, "the host entity, no collision")
assert(prompts["maneki.a"] and prompts["maneki.b"], "two private E prompts")
prompts["maneki.a"].cb()
local n, last = sentOf("op77_lightrp:maneki:collect")
assert(n == 1 and last.id == "a" and last.how == "take", "E sends a take")

-- The ray: straight ahead hits a, not b; a wall at 5 m blocks.
local hit = M.aimed(85)
assert(hit and hit.id == "a", "aimed at a")
view.forward = { x = 0.06, y = 1, z = 0 }
hit = M.aimed(85)
assert(hit and hit.id == "b", "aimed at b (0.6 m right at 10 m)")
view.forward = { x = 0.3, y = 1, z = 0 }
assert(M.aimed(85) == nil, "aimed between and beyond: nothing")
view.forward = { x = 0, y = 1, z = 0 }
wall = 5
assert(M.aimed(85) == nil, "a wall at 5 m blocks the cat at 10 m")
wall = nil

-- The trigger: one shot request per cat, not one per frame.
firingNow = true
for _ = 1, 10 do clock = clock + 16; tick() end
local shots = 0
for _, s in ipairs(server) do if s.payload.how == "shot" then shots = shots + 1 end end
assert(shots == 1, "one shot request, got " .. shots)
firingNow = false

-- The server confirms: the prop and the prompt go.
net["op77_lightrp:maneki"]({ kind = "found", id = "a", how = "shot", found = 1, total = 2 })
assert(M.cats.a == nil and prompts["maneki.a"] == nil and propCount() == 1, "found cat removed")

-- A new list without b: b goes too.
net["op77_lightrp:maneki"]({ kind = "near", spots = {} })
tick()
assert(propCount() == 0 and next(M.cats) == nil, "list emptied")

-- The staff tool: opens, places on a click (facing the camera), leaves on BACKSPACE.
net["op77_lightrp:maneki"]({ kind = "editor", active = true, scales = { 1, 1.5, 2, 3 } })
tick()
assert(LightRpManekiEditor.active, "tool on")
clock = clock + 100; tick()
assert(page[#page].active == true and page[#page].aim == true, "the bar shows an aim")
keys.MOUSE1 = true; clock = clock + 16; tick(); keys.MOUSE1 = false; clock = clock + 16; tick()
local placed
for _, s in ipairs(server) do if s.name == "op77_lightrp:maneki:edit" and s.payload.op == "place" then placed = s.payload end end
assert(placed and placed.y == 10 and placed.district == "Kabuki", "placed at the aim point")
assert(math.abs(placed.yaw - 0) < 1e-6 or math.abs(placed.yaw - 360) < 1e-6, "facing the camera (south of it: yaw 0, face -Y): " .. tostring(placed.yaw))
keys.UP = true; clock = clock + 16; tick(); keys.UP = false; clock = clock + 16; tick()
assert(page[#page].scale == 1.5, "UP grows the cat")
keys.BACKSPACE = true; clock = clock + 16; tick(); keys.BACKSPACE = false
assert(not LightRpManekiEditor.active, "BACKSPACE leaves")
local closes = 0
for _, s in ipairs(server) do if s.name == "op77_lightrp:maneki:edit" and s.payload.op == "close" then closes = closes + 1 end end
assert(closes == 1, "the server is told")

-- F1 > Maneki-neko: the panel, then a found cat on the city map, then back to the panel.
local function lastPage(name) for i = #pageNamed, 1, -1 do if pageNamed[i].name == name then return pageNamed[i].p end end end
net["op77_maneki"] = nil
net["op77_lightrp:maneki"]({ kind = "collection", collection = { kind = "maneki", total = 3, found = 2, intro = true,
    slots = { "mkA|Kabuki|1793810000000|take|-1440.5|128.0|18.2", "", "mkC||1793811000000|shot|100.0|-400.0|7.0" } } })
assert(lastPage("lightrp:ui:dialog").kind == "maneki", "the panel opens")
assert(#M.collection.found == 2 and M.collection.found[1].number == "01" and M.collection.found[2].number == "03", "two found, numbered by slot")
local ok = M.showOnMap("mkC")
assert(ok == true, "map opened")
local blips, opened, focus = 0, nil, nil
for _, c in ipairs(mapCalls) do
    if c.method == "addBlip" then blips = blips + 1; if c.args[1].id == "maneki.mkC" then assert(c.args[1].pulse == true and c.args[1].category == "maneki", "the clicked cat pulses") end end
    if c.method == "open" then opened = c.args[1] end
    if c.method == "focus" then focus = c.args[1] end
end
assert(blips == 2 and opened.x == 100 and focus.y == -400, "every found cat pinned, map on the clicked one")
assert(lastPage("lightrp:ui:dialog:close").kind == "maneki", "the panel steps aside")
assert(select(1, M.showOnMap("nope")) == false, "an unknown id is refused")
local before = #pageNamed
events["op77_map3d:closed"]()
local removed = 0
for _, c in ipairs(mapCalls) do if c.method == "removeBlip" then removed = removed + 1 end end
assert(removed == 2, "pins removed when the map closes")
local back = lastPage("lightrp:ui:dialog")
assert(#pageNamed > before and back.kind == "maneki" and back.intro == nil, "the panel comes back, without the explanation")
-- The tables leave room for every cat held, drawn or not, and a cat the shared prop quota
-- refused is built by the next list once they have.
LightRpManeki.clear()
assert(LightRpManeki.count == 0, "no cat held")
local create = Open77.props.create
Open77.props.create = function() return nil, "quota_exceeded" end
local refusedList = { { id = "q1", x = 1, y = 1, z = 0 }, { id = "q2", x = 2, y = 1, z = 0 } }
LightRpManeki.apply(refusedList); tick(2)
assert(LightRpManeki.count == 2 and not LightRpManeki.cats.q1.handle, "a refused cat is still held")
Open77.props.create = create
LightRpManeki.apply(refusedList); tick(2)
assert(LightRpManeki.cats.q1.handle and LightRpManeki.cats.q2.handle, "the next list builds the refused cats")
print("maneki_client_test: ok")
