-- Client: checkpoint markers, op77_map3d blip and GPS (the player's own waypoint given
-- back), editor preview budget, key mappings and what they send.
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

local pages = {}
WebUI = { create = function(options)
    local page = { options = options, sent = {}, handlers = {}, focus = nil, shown = options.visible }
    function page:on(name, fn) self.handlers[name] = fn end
    function page:send(name, payload) self.sent[#self.sent + 1] = { name = name, payload = payload } end
    function page:setFocus(k, c) self.focus = { k, c } end
    function page:setConsumedKeys(list) self.consumed = list end
    function page:show() self.shown = true end
    function page:hide() self.shown = false end
    pages[#pages + 1] = page
    return page
end }

H.load({ "shared/config.lua", "shared/race.lua", "client/markers.lua", "client/main.lua" })
local M = RaceMarkers

local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end return n end
local function state(overrides)
    local s = { instance = "trial:1", run = 1, phase = "active", state = "racing", lap = 1, laps = 1,
        course = { name = "Street Circuit", onFoot = false, start = { position = { x = 0, y = 0, z = 0 }, heading = 0 } },
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
end)

H.test("the page: created on the HUD layer, state relayed, restart key live in a trial", function()
    local page = pages[1]
    H.ok(page, "surface created")
    H.eq(page.options.layer, "hud"); H.eq(page.options.zIndex, RaceConfig.ui.zIndex)
    page.handlers["race:ready"]()
    H.netHandlers["op77_race:state"](state())
    local relayed = page.sent[#page.sent]
    H.eq(relayed.name, "race:state")
    mappings["op77_race.restart"].handler()
    local sent = H.clientEvents[#H.clientEvents]
    H.eq(sent.name, "op77_race:restart"); H.eq(sent.server, true)
end)

H.test("GO plays its sound and the start one-shots with explicit durations", function()
    H.netHandlers["op77_race:pulse"]({ kind = "go" })
    H.ok(#sfx >= 1)
    H.eq(#vfx, #RaceConfig.presentation.startVfx)
    for _, entry in ipairs(vfx) do H.ok(entry.opts.duration and entry.opts.duration > 0, "duration set") end
end)

H.test("the panel takes focus and consumes Escape; closing gives it back", function()
    local page = pages[1]
    H.netHandlers["op77_race:panel"](true)
    H.eq(page.focus[1], true); H.eq(page.consumed[1], "escape")
    H.eq(H.clientEvents[#H.clientEvents].name, "op77_race:openMenu")
    page.handlers["race:close"]()
    H.eq(page.focus[1], false)
end)

H.test("editor keys send the action and the facing", function()
    H.netHandlers["op77_race:editor"]({ draft = { name = "Draft", vehicle = "on_foot", grid = {}, checkpoints = {} } })
    mappings["op77_race.editor.checkpoint"].handler()
    local sent = H.clientEvents[#H.clientEvents]
    H.eq(sent.name, "op77_race:editorAction")
    H.eq(sent.args[1].action, "checkpoint")
    H.eq(sent.args[1].heading, 0.0, "camera forward +Y is heading 0")
end)

H.test("race over: markers, blip and HUD cleared", function()
    H.netHandlers["op77_race:state"](state({ run = 3 }))
    H.netHandlers["op77_race:clear"]()
    H.eq(count(map.blips), 0)
    H.eq(pages[1].sent[#pages[1].sent].name, "race:clear")
end)

H.done("client_test")
