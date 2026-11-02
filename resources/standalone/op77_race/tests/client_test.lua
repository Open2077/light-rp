-- Client: checkpoint markers, op77_map3d blip and GPS (the player's own waypoint given
-- back), editor preview budget, key mappings and what they send, and the race drawn by
-- Light RP's activity HUD (op77_lightrp client exports ActivityHudShow / Push / Clear).
local H = dofile("tests/harness.lua")

local markers, nextMarker = {}, 0
Open77.markers = {
    create = function(options) nextMarker = nextMarker + 1; local id = "m" .. nextMarker; markers[id] = options; return id end,
    update = function(id, patch) if not markers[id] then return false end markers[id] = patch; return true end,
    remove = function(id) markers[id] = nil; return true end,
    get = function(id) return markers[id] and { failed = false } or nil end,
}
Open77.log = { info = function() end, warn = function() end, error = function() end, debug = function() end }
local sfx, vfx = {}, {}
Open77.sfx = { play = function(event, opts) sfx[#sfx + 1] = { event = event, opts = opts }; return "s" .. #sfx end, stop = function() return true end }
Open77.vfx = { play = function(effect, opts) vfx[#vfx + 1] = { effect = effect, opts = opts }; return "v" .. #vfx end, stop = function() return true end }
Open77.character = { state = function() return { yaw = 90.0, inVehicle = false } end }
Open77.camera = { view = function() return { forward = { x = 0, y = 1, z = 0 } } end }
local decoded = {}
Open77.json = { decode = function(text) return decoded[text] end }
local mappings = {}
Open77.input = { keyFor = function(id) return mappings[id] and mappings[id].key or nil end, isCaptured = function() return false end }
function RegisterKeyMapping(id, name, key, handler) mappings[id] = { name = name, key = key, handler = handler }; return true, key end

local map = { blips = {}, waypoint = { x = 1, y = 2, z = 3 }, calls = {} }
local mapExports = {
    addBlip = function(_, def) map.calls[#map.calls + 1] = "add"; local id = "b" .. #map.calls; map.blips[id] = def; return id end,
    updateBlip = function(_, id, patch) map.calls[#map.calls + 1] = "update"; if not map.blips[id] then return false end map.blips[id] = patch; return true end,
    removeBlip = function(_, id) map.blips[id] = nil; return true end,
    setWaypoint = function(_, pos) map.waypoint = pos; return true end,
    clearWaypoint = function() map.waypoint = nil; return true end,
    getWaypoint = function() return map.waypoint end,
}
exports.op77_map3d = mapExports

-- Light RP's client side of the activity HUD.
local hud = { shows = {}, pushes = {}, clears = 0, down = false }
local core = exports.op77_lightrp
core.ActivityHudShow = function(_, view)
    if hud.down then error("resource op77_lightrp is not running") end
    hud.shows[#hud.shows + 1] = view
    return true
end
core.ActivityHudPush = function(_, kind, item)
    if hud.down then error("resource op77_lightrp is not running") end
    hud.pushes[#hud.pushes + 1] = { kind = kind, item = item }
    return true
end
core.ActivityHudClear = function() hud.clears = hud.clears + 1; return true end
local function shown() return hud.shows[#hud.shows] end
local function pushed() return hud.pushes[#hud.pushes] end
local function stat(view, label)
    for _, s in ipairs(view.stats or {}) do if s.label == label then return s.value end end
end
local function hint(view, label)
    for _, h in ipairs(view.hints or {}) do if h.label == label then return h.key end end
end

H.load({ "shared/config.lua", "shared/race.lua", "client/markers.lua", "client/main.lua" })
local M = RaceMarkers

local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end return n end
local function state(overrides)
    local s = { self = 1, instance = "trial:1", run = 1, activity = "race.trial", mode = "trial", phase = "active", state = "racing",
        lap = 1, laps = 1, completed = 2, progressTotal = 8, elapsedMs = 41234, personalBestMs = 72405,
        course = { name = "Street Circuit", onFoot = false, vehicle = "Quadra Turbo-R V-Tech", start = { position = { x = 0, y = 0, z = 0 }, heading = 0 } },
        next = { index = 3, position = { x = 10, y = 20, z = 5 }, heading = 45, radius = 7, finish = false },
        canRestart = true, canRespawn = false }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

H.test("a car race shows one raised chevron, a pinned blip and a GPS route", function()
    M.sync(state())
    H.eq(count(markers), 1)
    local _, chevron = next(markers)
    H.eq(chevron.shape, "chevron"); H.eq(chevron.position.z, 8.0, "lifted 3 m")
    local _, blip = next(map.blips)
    H.eq(blip.edge, true); H.eq(blip.icon, "target"); H.eq(blip.routable, true)
    H.eq(map.waypoint.x, 10, "GPS to the checkpoint")
end)

H.test("an unchanged target is not rebuilt; the next one replaces it", function()
    local before = nextMarker
    M.sync(state())
    H.eq(nextMarker, before, "same signature, no new marker")
    M.sync(state({ next = { index = 4, position = { x = 30, y = 40, z = 5 }, heading = 0, radius = 7, finish = true } }))
    H.eq(count(markers), 1)
    local _, blip = next(map.blips)
    H.eq(blip.icon, "flag", "finish")
end)

H.test("clearing gives the player's own waypoint back", function()
    M.clear()
    H.eq(count(markers), 0); H.eq(count(map.blips), 0)
    H.eq(map.waypoint.x, 1); H.eq(map.waypoint.y, 2)
end)

H.test("on foot: ring and arrow, a blip, no GPS route", function()
    map.waypoint = nil
    M.sync(state({ course = { onFoot = true }, next = { index = 1, position = { x = 5, y = 5, z = 30 }, radius = 3 } }))
    H.eq(count(markers), 2)
    H.eq(map.waypoint, nil, "no road route on rooftops")
    M.sync(nil)
    H.eq(count(markers), 0)
end)

H.test("without op77_map3d the markers still work", function()
    exports.op77_map3d = nil
    M.sync(state({ run = 9 }))
    H.eq(count(markers), 1)
    M.clear()
    exports.op77_map3d = mapExports
end)

H.test("editor preview stays within its marker budget", function()
    local checkpoints = {}
    for i = 1, 60 do checkpoints[i] = { position = { x = i, y = 0, z = 0 }, heading = 0 } end
    M.preview({ vehicle = "archer_hella", start = { position = { x = 0, y = 0, z = 0 } },
        grid = { { position = { x = 0, y = -5, z = 0 } } }, checkpoints = checkpoints, checkpointRadius = 7 })
    H.eq(count(markers), RaceConfig.editor.previewMarkers)
    M.clearPreview()
    H.eq(count(markers), 0)
end)

H.test("keys: bound clear of Light RP, inert outside a race", function()
    H.fire("onClientResourceStart", "op77_race")
    H.eq(H.clientEvents[#H.clientEvents].name, "op77_race:ready", "the current state is asked for")
    H.eq(mappings["op77_race.respawn"].key, "END")
    H.eq(mappings["op77_race.restart"].key, "HOME")
    H.eq(mappings["op77_race.editor.checkpoint"].key, "INSERT")
    local taken = { TAB = 1, F1 = 1, F2 = 1, F3 = 1, F4 = 1, F5 = 1, F6 = 1, F7 = 1, F8 = 1, F9 = 1, F10 = 1, F11 = 1, ALT = 1, N = 1,
        E = 1, I = 1, L = 1, X = 1, Y = 1, H = 1, G = 1, R = 1, C = 1, M = 1, DELETE = 1, PAGEUP = 1, PAGEDOWN = 1 }
    for id, mapping in pairs(mappings) do H.ok(not taken[mapping.key], id .. " collides with " .. mapping.key) end
    local before = #H.clientEvents
    mappings["op77_race.restart"].handler()
    mappings["op77_race.editor.checkpoint"].handler()
    H.eq(#H.clientEvents, before, "nothing sent without a race or an editor session")
    H.eq(#hud.shows, 0, "no HUD outside a race")
end)

H.test("a time trial in the activity HUD: running clock, checkpoint, best times, restart key", function()
    H.netHandlers["op77_race:state"](state())
    local view = shown()
    H.eq(view.activity, "race.trial"); H.eq(view.title, "Time Trial"); H.eq(view.subtitle, "Street Circuit · Quadra Turbo-R V-Tech")
    H.eq(view.phase, "running")
    H.eq(view.timer.remainingMs, 41234); H.eq(view.timer.countUp, true)
    H.eq(stat(view, "Checkpoint"), "2/8"); H.eq(stat(view, "Personal best"), "1:12.405"); H.eq(stat(view, "Record"), "-")
    H.eq(stat(view, "Lap"), nil, "one lap: no lap counter")
    H.eq(view.progress[1].value, 0.25)
    H.eq(hint(view, "Restart"), "HOME"); H.eq(hint(view, "Quit"), "/race.leave"); H.eq(hint(view, "Last checkpoint"), nil)
    H.eq(view.scoreboard, nil, "alone on the course: no ranking")
    mappings["op77_race.restart"].handler()
    local sent = H.clientEvents[#H.clientEvents]
    H.eq(sent.name, "op77_race:restart"); H.eq(sent.server, true)
end)

H.test("loading, then the countdown in milliseconds (never a last instant read as seconds)", function()
    H.netHandlers["op77_race:state"](state({ run = 2, phase = "loading", state = "loading" }))
    H.eq(shown().phase, "countdown"); H.eq(shown().countdown, nil); H.eq(shown().objective, "Get ready")
    local sounds = #sfx
    H.netHandlers["op77_race:state"](state({ run = 2, phase = "countdown", state = "countdown", remainingMs = 2950 }))
    H.eq(shown().countdown, 2950)
    H.eq(#sfx, sounds + 1, "countdown sound once")
    H.netHandlers["op77_race:state"](state({ run = 2, phase = "countdown", state = "countdown", remainingMs = 6 }))
    H.eq(shown().countdown, 0)
    H.eq(#sfx, sounds + 1, "not twice for the same run")
end)

H.test("GO: sound, start one-shots with explicit durations, a banner", function()
    H.netHandlers["op77_race:pulse"]({ kind = "go" })
    H.ok(#sfx >= 1)
    H.eq(#vfx, #RaceConfig.presentation.startVfx)
    for _, entry in ipairs(vfx) do H.ok(entry.opts.duration and entry.opts.duration > 0, "duration set") end
    H.eq(pushed().kind, "banner"); H.eq(pushed().item.title, "GO")
end)

H.test("checkpoints go to the feed, laps and the finish to banners", function()
    H.netHandlers["op77_race:pulse"]({ kind = "checkpoint", completed = 3, total = 12, splitMs = 42180 })
    H.eq(pushed().kind, "feed"); H.eq(pushed().item.text, "Checkpoint 3/12  0:42.180")
    H.netHandlers["op77_race:pulse"]({ kind = "lap", lap = 2, laps = 3, lastLapMs = 61250 })
    H.eq(pushed().item.title, "LAP 2/3"); H.eq(pushed().item.text, "Last lap 1:01.250")
    H.netHandlers["op77_race:pulse"]({ kind = "lap", lap = 3, laps = 3 })
    H.eq(pushed().item.title, "FINAL LAP")
    H.netHandlers["op77_race:pulse"]({ kind = "finish", timeMs = 182480, outcome = { personalBest = true } })
    H.eq(pushed().item.title, "FINISH"); H.eq(pushed().item.text, "Personal best"); H.eq(pushed().item.tone, "success")
end)

H.test("a street race: position, laps, best lap and the ranking around our row", function()
    decoded["rows-json"] = {
        { id = 7, name = "Kei", rank = 1, state = "racing", progress = 9 },
        { id = 1, name = "Ann", rank = 2, state = "racing", progress = 8 },
        { id = 5, name = "Vi", rank = 3, state = "dnf", progress = 3 },
    }
    H.netHandlers["op77_race:state"](state({ instance = "grid:1", run = 1, activity = "race.grid", mode = "grid", laps = 3, lap = 2,
        completed = 8, progressTotal = 24, bestLapMs = 58210, canRestart = false, rows = "rows-json" }))
    local view = shown()
    H.eq(view.title, "Street Race")
    H.eq(stat(view, "Position"), "2/3"); H.eq(stat(view, "Lap"), "2/3"); H.eq(stat(view, "Best lap"), "0:58.210")
    H.eq(stat(view, "Personal best"), nil, "best times belong to the time trial")
    H.eq(#view.stats, 4)
    H.eq(view.scoreboard.columns[1], "CP"); H.eq(view.scoreboard.columns[2], "TIME")
    H.eq(view.scoreboard.rows[2].self, true); H.eq(view.scoreboard.rows[1].self, nil)
    H.eq(view.scoreboard.rows[1].values[1], "9/24")
    H.eq(view.scoreboard.rows[3].values[2], "OUT")
    H.eq(hint(view, "Restart"), nil, "no restart in a heat")
end)

H.test("results: the HUD counts back, the result card is pushed once per run", function()
    local rows = { { id = 1, name = "Ann", rank = 1, state = "finished", timeMs = 182480, progress = 24 },
        { id = 7, name = "Kei", rank = 2, state = "finished", timeMs = 183100, progress = 24 } }
    local results = state({ instance = "grid:1", run = 1, mode = "grid", phase = "results", state = "finished", place = 1,
        timeMs = 182480, remainingMs = 12000, laps = 3, bestLapMs = 58210, rows = rows })
    local before = #hud.pushes
    H.netHandlers["op77_race:state"](results)
    H.eq(shown().phase, "ended"); H.eq(shown().timer.label, "BACK IN"); H.eq(shown().timer.countUp, nil)
    H.eq(shown().scoreboard.rows[1].values[2], "3:02.480")
    H.eq(#hud.pushes, before + 1)
    local card = pushed()
    H.eq(card.kind, "result"); H.eq(card.item.placement, 1); H.eq(card.item.title, "Street Race")
    H.eq(card.item.lines[1].label, "Time"); H.eq(card.item.lines[1].value, "3:02.480")
    H.eq(card.item.durationMs, 12000)
    H.netHandlers["op77_race:state"](results)
    H.eq(#hud.pushes, before + 1, "not twice")
end)

H.test("a time trial result: personal best, previous best, board rank; DNF elsewhere", function()
    H.netHandlers["op77_race:state"](state({ run = 5, phase = "results", state = "finished", timeMs = 70100, remainingMs = 15000,
        recordMs = 68950, outcome = { personalBest = true, previousBestMs = 72405, rank = 3 } }))
    local card = pushed().item
    H.eq(card.title, "Personal best"); H.eq(card.placement, nil)
    H.eq(card.lines[2].label, "Previous best"); H.eq(card.lines[3].value, "1:08.950"); H.eq(card.lines[4].value, "#3")
    H.netHandlers["op77_race:state"](state({ run = 6, phase = "results", state = "dnf", remainingMs = 15000 }))
    H.eq(pushed().item.placement, "DNF")
end)

H.test("race over: markers, blip and HUD cleared", function()
    H.netHandlers["op77_race:state"](state({ run = 3 }))
    local clears = hud.clears
    H.netHandlers["op77_race:clear"]()
    H.eq(count(map.blips), 0)
    H.eq(hud.clears, clears + 1)
end)

H.test("queued for a street race: a lobby HUD with the grid's countdown, gone with the queue", function()
    H.netHandlers["op77_race:queue"]({ activity = "race.grid", label = "Street Race", mode = "grid", queued = 1, minPlayers = 2, maxPlayers = 8 })
    local view = shown()
    H.eq(view.phase, "lobby"); H.eq(view.timer, nil); H.eq(view.objective, "Waiting for 1 more racer")
    H.eq(stat(view, "Queued"), "1/8"); H.eq(hint(view, "Leave queue"), "/race.leave")
    H.netHandlers["op77_race:queue"]({ activity = "race.grid", label = "Street Race", mode = "grid", queued = 3, minPlayers = 2, maxPlayers = 8, windowMs = 28000 })
    H.eq(shown().timer.remainingMs, 28000); H.eq(shown().timer.label, "STARTS IN")
    -- launched: the race replaces the lobby, then the queue goes without clearing it
    H.netHandlers["op77_race:state"](state({ instance = "grid:2", mode = "grid", phase = "loading", state = "loading" }))
    local clears = hud.clears
    H.netHandlers["op77_race:queue"](false)
    H.eq(shown().title, "Street Race"); H.eq(shown().phase, "countdown"); H.eq(hud.clears, clears)
    H.netHandlers["op77_race:clear"]()
    H.eq(hud.clears, clears + 1)
end)

H.test("/race opens Light RP's Activities panel", function()
    H.netHandlers["op77_race:activities"]()
    local sent = H.clientEvents[#H.clientEvents]
    H.eq(sent.name, "op77_lightrp:action"); H.eq(sent.server, true)
    H.eq(sent.args[1].type, "activities.control"); H.eq(sent.args[1].operation, "open")
end)

H.test("the course editor in the HUD; its keys send the action and the facing", function()
    local point = function(x) return { position = { x = x, y = 0, z = 0 }, heading = 0 } end
    H.netHandlers["op77_race:editor"]({ draft = { name = "Draft", vehicle = "on_foot", grid = {}, checkpoints = { point(10), point(20) }, laps = 1 },
        message = "Checkpoint 2 captured." })
    local view = shown()
    H.eq(view.title, "Course editor"); H.eq(view.subtitle, "Draft"); H.eq(view.objective, "Checkpoint 2 captured.")
    H.eq(stat(view, "Checkpoints"), 2); H.eq(stat(view, "Start"), "Missing")
    H.eq(hint(view, "Checkpoint"), "INSERT")
    mappings["op77_race.editor.checkpoint"].handler()
    local sent = H.clientEvents[#H.clientEvents]
    H.eq(sent.name, "op77_race:editorAction")
    H.eq(sent.args[1].action, "checkpoint")
    H.eq(sent.args[1].heading, 0.0, "camera forward +Y is heading 0")
    local clears = hud.clears
    H.netHandlers["op77_race:editor"](false)
    H.eq(hud.clears, clears + 1, "editor closed: HUD cleared")
end)

H.test("Light RP down: nothing raises, the HUD comes back once it answers", function()
    hud.down = true
    local shows = #hud.shows
    H.netHandlers["op77_race:state"](state({ run = 8 }))
    H.netHandlers["op77_race:pulse"]({ kind = "checkpoint", completed = 1, total = 8, splitMs = 1000 })
    H.eq(#hud.shows, shows)
    hud.down = false
    H.advance(1100)
    H.eq(#hud.shows, shows + 1, "shown again by the watchdog")
    H.advance(2100)
    H.eq(#hud.shows, shows + 1, "and only once")
    H.fire("onClientResourceStart", "op77_lightrp")
    H.advance(1100)
    H.eq(#hud.shows, shows + 2, "a restarted core is given the HUD again")
    H.netHandlers["op77_race:clear"]()
end)

H.done("client_test")
