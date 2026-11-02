-- client/core/interact.lua: a long interaction list is built in slices (one script
-- resume must stay short: the client kills a handler that overruns its budget), a full
-- custom-icon budget stops further custom tries, and a newer list stops an older build.
dofile("shared/config.lua")
dofile("shared/events.lua")
local handlers, threads, logs, iconCalls, nativeBlips, markers = {}, {}, {}, 0, 0, 0
RegisterNetEvent = function(name, fn) handlers[name] = fn end
AddEventHandler = function() end
local asked = 0
TriggerServerEvent = function(name) if name == LightRpEvents.net.interactionsRequest then asked = asked + 1 end end
RegisterKeyMapping = function() return true, "E" end
GetCurrentResourceName = function() return "op77_lightrp" end
GetResourceState = function() return "stopped" end
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
Open77 = {
    character = { state = function() return { position = { x = 0, y = 0, z = 0 }, attached = attachedNow == true } end },
    markers = { create = function() markers = markers + 1; return markers end, remove = function() return true end, update = function() return true end },
    anchors = { create = function() return 1 end, remove = function() return true end, update = function() return true end },
    blips = { create = function() nativeBlips = nativeBlips + 1; return nativeBlips end, remove = function() return true end },
}
LightRpUi = { page = {}, log = function(f, ...) logs[#logs + 1] = string.format(f, ...) end, send = function() end }
exports = setmetatable({}, { __call = function() end })
exports.open77_icons = { create = function() iconCalls = iconCalls + 1; return nil, "blip_visual_budget_exceeded" end, remove = function() return true end }
local firstThread = #threads + 1
dofile("client/core/interact.lua")
-- the request loop: nothing before the world, then one ask, again after 5 s, none once a list came
local clock = 0
GetGameTimer = function() return clock end
local lastLoaded = #threads
local function step() for i = firstThread, lastLoaded do if coroutine.status(threads[i]) ~= "dead" then assert(coroutine.resume(threads[i])) end end end
step(); step(); assert(asked == 0, "not in the world: no request")
attachedNow = true; clock = 1000
step(); assert(asked == 1, "in the world: ask for the list")
clock = 3000; step(); assert(asked == 1, "not again within 5 s")
clock = 7000; step(); assert(asked == 2, "again after 5 s while nothing came")
local build = handlers[LightRpEvents.net.interactions]
build({}) -- a list arrived: no more requests
clock = 20000; step(); assert(asked == 2, "a list came: no more requests")
local function list(n, prefix)
    local out = {}
    for i = 1, n do out[i] = { id = prefix .. i, rev = 1, position = { x = i, y = 0, z = 0 }, label = prefix .. i,
        marker = { shape = "cylinder" }, blip = { icon = "shirt", sprite = "clothes", title = "Wardrobe" } } end
    return out
end
local function run(co) while coroutine.status(co) ~= "dead" do assert(coroutine.resume(co)) end end

-- 30 points: 4 at once, the rest after yields
local before = #threads
build(list(30, "w"))
assert(#LightRpInteract.points == 4, "the first slice at once, got " .. #LightRpInteract.points)
assert(#threads == before + 1, "the rest goes to a thread")
local co = threads[#threads]
assert(coroutine.resume(co)); assert(#LightRpInteract.points == 4, "nothing more before the first yield returns")
assert(coroutine.resume(co)); assert(#LightRpInteract.points == 8, "one slice per resume")
run(co)
assert(#LightRpInteract.points == 30 and logs[#logs]:find("30 interaction point", 1, true), "every point, shops after the wardrobes included")
-- the full visual budget answered once: no further custom tries, native sprites instead
assert(iconCalls == 1 and nativeBlips == 30, "one refused custom try, then native: " .. iconCalls .. "/" .. nativeBlips)

-- a newer list stops an older build still running
build(list(20, "a"))
local old = threads[#threads]
assert(coroutine.resume(old))            -- first slice of a: yields
local beforeB = #threads
build(list(3, "b"))                       -- the old points retire in slices too
for i = beforeB + 1, #threads do run(threads[i]) end -- only this build's own work
assert(#LightRpInteract.points == 3 and #LightRpInteract.retiring == 0, "the new list replaces the old, old handles all removed")
run(old)
assert(#LightRpInteract.points == 3, "the old build stopped without adding its points")
for _, p in ipairs(LightRpInteract.points) do assert(p.id:sub(1, 1) == "b") end

-- an identical list (new tables, same content) touches nothing: the server re-sent one
-- every few seconds while driving and every marker, blip and pin was rebuilt each time
local same = list(3, "b")
local markersBefore, blipsBefore = markers, nativeBlips
local before3 = {}
for i, p in ipairs(LightRpInteract.points) do before3[i] = p end
local logsBefore = #logs
build(same)
assert(markers == markersBefore and nativeBlips == blipsBefore, "an unchanged list creates nothing")
for i, p in ipairs(LightRpInteract.points) do assert(p == before3[i], "the same points are kept") end
assert(#logs == logsBefore, "an unchanged list is not even logged")
-- one changed entry (the server gives it a new revision): only that point is rebuilt
same[2].label = "changed"; same[2].rev = 2
build(same)
assert(#LightRpInteract.points == 3 and markers == markersBefore + 1, "only the changed point is rebuilt")
local stayed = 0
for _, p in ipairs(LightRpInteract.points) do if p == before3[1] or p == before3[3] then stayed = stayed + 1 end end
assert(stayed == 2, "the unchanged points stay")
assert(logs[#logs]:find("(2 kept, 1 added, 1 removed)", 1, true), logs[#logs])
-- a removed entry goes, a new one comes, the rest stays
build({ same[1], same[3], { id = "c1", rev = 1, position = { x = 9, y = 0, z = 0 }, marker = { shape = "cylinder" } } })
assert(#LightRpInteract.points == 3 and markers == markersBefore + 2, "one removed, one added")
local ids = {}
for _, p in ipairs(LightRpInteract.points) do ids[p.id] = true end
assert(ids.b1 and ids.b3 and ids.c1 and not ids.b2)
print("PASS: interaction build in slices (first slice at once, one slice per resume, every point built, visual budget stops custom tries, newer list wins, unchanged points kept, only changes rebuilt)")
