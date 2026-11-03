-- The Crossing (server/modules/activities_hub.lua): terminals placed along the
-- hub's heading, the map pin, the panel from a terminal, the contracts list (no
-- fixer gig, no withdrawn board), the GPS operation, the first-day pointer and
-- the staff survey line.
dofile("shared/events.lua")
dofile("shared/config.lua")
dofile("server/config/activities.lua")
assert(#LightRpActivities.hub.terminals == 1, "one terminal: activities and contracts are tabs of one panel")
-- the live config: the owner's survey (2026-11-03), Adam Smasher standing on it
do
    local t, host = LightRpActivities.hub.terminals[1], LightRpActivities.hub.host
    assert(t.position and math.abs(t.position.x - (-783.885)) < 1e-3 and math.abs(t.position.y - 787.366) < 1e-3
        and t.heading == 240.96 and t.npc == true, "the surveyed terminal with its host")
    assert(host.name == "Adam Smasher" and host.candidates[1].record == "Character.main_boss_adam_smasher", "Smasher first")
    for _, c in ipairs(host.candidates) do assert(c.record:match("^Character%.[%w_]+$"), "a record name") end
    t.position = nil -- below: the offset path
end
-- a contracts terminal still works when a server adds one (it opens the same panel on its tab)
table.insert(LightRpActivities.hub.terminals, { id = "contracts", kind = "contracts", label = "Contracts",
    prompt = "Browse the contract boards", offset = { forward = 5.0, right = 2.0 } })
local noop = function() end
local interactions, dialogs, notices, clientEvents, timers, commands, providers = {}, {}, {}, {}, {}, {}, {}
LightRP = {
    db = { ready = false, schema = noop, run = noop, read = function() return false end },
    module = function(name, value) value.name = name; LightRP[name] = value; return value end,
    stateProvider = function(key, fn) providers[key] = fn end, action = noop,
    command = function(name, _, fn) commands[name] = fn end,
    state = noop, result = noop, log = noop, eachModule = noop,
    notice = function(id, def) notices[#notices + 1] = { id = id, def = def } end,
    dialog = function(id, kind, payload) dialogs[#dialogs + 1] = { id = id, kind = kind, payload = payload } end,
    interaction = function(id, def) interactions[id] = def end,
    batchInteractions = function(fn) return fn() end,
    nowMs = function() return 1000 end,
    joinArgs = function(args) return table.concat(args, " ") end,
}
LightRP.characters = { switching = {}, get = function() return { identifier = "a", key = "default", status = "active" } end,
    displayName = function() return "Alex" end, isRegistered = function() return true end }
local threads = {}
CreateThread = function(fn) threads[#threads + 1] = fn end
local waits = 0
Wait = function() waits = waits + 1; if waits > 2 then error("stop-loop") end end
SetTimeout = function(_, fn) timers[#timers + 1] = fn end
AddEventHandler = noop
TriggerEvent = noop
exports = noop
GetPlayers = function() return { 1 } end
GetPlayerRoutingBucket = function() return 0 end
TriggerClientEvent = function(name, id, payload) clientEvents[#clientEvents + 1] = { name = name, id = id, payload = payload } end
local at = { x = -756.581, y = 777.257, z = 22.454 }
local created, removed, aiCalls, refuse = {}, {}, {}, {}
Open77 = { players = { position = function() return { x = at.x, y = at.y, z = at.z, bucket = 0 } end,
    get = function() return { position = { x = at.x, y = at.y, z = at.z }, heading = 52.6, bucket = 0 } end,
    getLifeState = function() return { phase = "alive" } end }, vehicles = {},
    npcs = { damage = { invulnerable = "invulnerable" }, ai = { tasks = "tasks" },
        create = function(def) if refuse[def.record] then return nil, "unknown record" end created[#created + 1] = def; return 900 + #created end,
        remove = function(id) removed[#removed + 1] = id; return true end,
        setAIEnabled = function(id, on) aiCalls[#aiCalls + 1] = { id = id, on = on }; return true end,
        get = function() return nil end } }
LightRpMissions = { points = { { id = "board_far" }, { id = "gig_only" }, { id = "board_near" } } }
local points = {
    board_far = { id = "board_far", title = "Far Board", type = "HEIST", location = "NORTH", position = { x = 0, y = 2000, z = 0 } },
    gig_only = { id = "gig_only", title = "A gig", fixer = true, position = { x = 0, y = 0, z = 0 } },
    board_near = { id = "board_near", title = "Near Board", type = "RAID", location = "WESTBROOK", position = { x = -700, y = 760, z = 22 } },
    published = { id = "published", title = "Published", type = "OP", location = "X", position = { x = -650, y = 700, z = 20 } },
    withdrawn = { id = "withdrawn", title = "Gone", retired = true, position = { x = 1, y = 1, z = 1 } },
}
LightRP.missions = { point = function(id) return points[id] end, handlesDeath = function() return false end }
LightRP.missionEditor = { records = { published = {}, withdrawn = {} } }

dofile("server/modules/activities.lua")
dofile("server/modules/activities_hub.lua")
local A, Hub = LightRP.activities, LightRP.activitiesHub

-- terminals: forward 5 m and 2 m to the left / right of a hub facing 52.6 degrees
local board, contracts = interactions["activities.board"], interactions["activities.contracts"]
assert(board and contracts and board.bucket == 0)
assert(math.abs(board.position.x - (-760.553)) < 0.01 and math.abs(board.position.y - 780.294) < 0.01, "offset along the heading")
assert(math.abs(contracts.position.x - (-759.338)) < 0.01 and math.abs(contracts.position.y - 781.883) < 0.01)
assert(board.blip and board.blip.title == "Activities" and board.blip.mapCategory == "mission" and board.blip.map == "crossing", "the map pin")
assert(contracts.blip == nil, "one pin for the hub")
assert(board.marker == nil and board.promptHeight == 1.4 and board.label == "Adam Smasher", "a host: no floor marker, the prompt on him")
assert(contracts.marker == LightRpActivities.hub.marker, "a terminal without a host keeps its marker")

-- the host: spawned on the terminal facing its heading, AI off, invulnerable; the boss
-- record refused -> the next one; gone -> respawned
refuse["Character.main_boss_adam_smasher"] = true
local okThread, errThread = pcall(threads[#threads])
assert(not okThread and errThread:find("stop-loop", 1, true), "the start thread spawns then watches: " .. tostring(errThread))
assert(#created == 2, "first spawn, then the respawn of a body gone")
local hostDef = created[1]
assert(hostDef.record == "Character.Smasher", "the boss record refused: the next candidate")
assert(math.abs(hostDef.position.x - board.position.x) < 1e-6 and hostDef.yaw == 240.96 and hostDef.bucket == 0)
assert(hostDef.behavior.combatEnabled == false and hostDef.behavior.perceptionEnabled == false and hostDef.behavior.voiceEnabled == false)
assert(hostDef.damagePolicy == "invulnerable" and hostDef.aiMode == "tasks" and hostDef.persistent == false and hostDef.despawnWhenUnobserved == false)
assert(aiCalls[1].id == 901 and aiCalls[1].on == false, "AI off: he stands")
assert(Hub.hosts.board == 902 and Hub.hosts.contracts == nil, "respawned; no host on a terminal without npc")
Hub.spawnHosts()
assert(removed[#removed] == 902 and Hub.hosts.board == 903, "a respawn removes the old body")
local surveyed = Hub.placeOf({ position = { x = 1, y = 2, z = 3 }, offset = { forward = 9 } })
assert(surveyed.x == 1 and surveyed.z == 3, "a surveyed position replaces the offset")

-- a terminal opens the panel on its tab
Hub.onInteract(1, "activities.contracts")
assert(dialogs[#dialogs].kind == "activities" and dialogs[#dialogs].payload.tab == "contracts")
Hub.onInteract(1, "activities.board")
assert(dialogs[#dialogs].payload.tab == "activities")

-- contracts: boards only, nearest first, published ones included
local view = providers.activities(1)
local ids = {}
for i, c in ipairs(view.contracts) do ids[i] = c.id end
assert(table.concat(ids, ",") == "board_near,published,board_far", "boards by distance: " .. table.concat(ids, ","))
assert(view.contracts[1].distance and view.contracts[1].distance < 100 and view.hub.position.x == -756.581)

-- GPS
local ok, text = A.operations.gps(1, { id = "board_near" })
assert(ok and text:find("Near Board") and clientEvents[#clientEvents].name == LightRpEvents.net.activitiesGps)
assert(clientEvents[#clientEvents].payload.position.x == -700)
ok = A.operations.gps(1, { id = "gig_only" }); assert(not ok, "no GPS to a fixer gig")
ok = A.operations.gps(1, { id = "withdrawn" }); assert(not ok, "nor to a withdrawn board")
ok = A.operations.gps(1, { id = "hub" }); assert(ok and clientEvents[#clientEvents].payload.title == "The Crossing")
assert(clientEvents[#clientEvents].payload.position.x == board.position.x, "the route leads to the activities terminal")

-- the first day ends: a pointer, and the route when far from it
local before = #clientEvents
Hub.onTutorialDone(1)
timers[#timers]()
assert(notices[#notices].def.title == "THE CROSSING" and #clientEvents == before, "already at The Crossing: no route")
at = { x = 0, y = 0, z = 0 }
Hub.onTutorialDone(1)
timers[#timers]()
assert(#clientEvents == before + 1 and clientEvents[#clientEvents].payload.title == "The Crossing", "far away: the route there")

-- staff survey
at = { x = 1.23456, y = -2.5, z = 3 }
local okSurvey, line = commands["lightrp.survey"](1, { "board" })
assert(okSurvey and line:find("x = 1.235", 1, true) and line:find("heading = 52.6", 1, true) and line:find("bucket 0", 1, true) and line:find("board"))
print("PASS: The Crossing terminals along the heading, one map pin, the host NPC instead of a marker, panel tabs, contracts without gigs or withdrawn boards, GPS, first-day pointer, survey line")
