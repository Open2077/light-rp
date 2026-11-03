-- The events board (server/modules/events_board.lua, page events_board_page.lua, client
-- client/core/events_board.lua): the view built from mocked providers (turf status
-- lines, world bosses, activities, weekly boards, records), a failing provider alone,
-- the HTTP routes (page, view.json, 404, 405, HEAD), the TV's placement along the
-- hub's heading, the kvp override and the staff command, the respawn, the clients'
-- screen (bind shape, range and slack), and the fallbacks: no HTTP, no props, no kvp,
-- disabled.
dofile("shared/events.lua")
dofile("shared/config.lua")
dofile("server/config/activities.lua")
dofile("server/config/events_board.lua")
local E, C, H = LightRpEvents, LightRpEventsBoard, LightRpActivities.hub
local SEP = " \u{B7} "

-- the live config: a 16:9 set at x3, the URL from the listener, the route /board
assert(C.enabled ~= false and C.url == nil and C.http.prefix == "/board" and C.http.listenOrigin == "http://127.0.0.1:11781")
assert(C.screens[C.tv.screen] and C.screens[C.tv.screen].model == "electronics.tv.16x9" and C.tv.scale == 3.0 and C.tv.bucket == 0)
assert(C.rotateMs * 4 <= 20000, "one cycle of the four panels in 20 s at most")

local function near(a, b, eps) return math.abs(a - b) < (eps or 1e-3) end

-- A JSON encoder for the routes (sorted keys, so the output is stable).
local function encode(v)
    local t = type(v)
    if t == "nil" then return "null" elseif t == "boolean" then return tostring(v)
    elseif t == "number" then return v % 1 == 0 and string.format("%d", v) or string.format("%.14g", v)
    elseif t == "string" then return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"'
    elseif t == "table" then
        if next(v) == nil then return "[]" end
        if #v > 0 then local parts = {}; for i, x in ipairs(v) do parts[i] = encode(x) end; return "[" .. table.concat(parts, ",") .. "]" end
        local keys, parts = {}, {}
        for k in pairs(v) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        for _, k in ipairs(keys) do parts[#parts + 1] = encode(k) .. ":" .. encode(v[k]) end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    error("cannot encode " .. t)
end
json = { encode = encode }

-- ---------------------------------------------------------------------------
-- The world around the module

local clock = 1000000
local logs, commands, netHandlers, eventHandlers, clientEvents, threads = {}, {}, {}, {}, {}, {}
local registry = {}
LightRP = {
    module = function(name, value) value.name = name; LightRP[name] = value; return value end,
    command = function(name, options, fn) commands[name] = { options = options, fn = fn } end,
    log = function(fmt, ...) logs[#logs + 1] = select("#", ...) > 0 and string.format(fmt, ...) or tostring(fmt) end,
    nowMs = function() return clock end,
    characters = { isRegistered = function() return true end, displayName = function() return "Staff Member" end },
    activities = { registry = registry, events = { status = "op77_lightrp:activity:status" } },
}
local function logged(text) for _, line in ipairs(logs) do if line:find(text, 1, true) then return line end end end

CreateThread = function(fn) threads[#threads + 1] = fn end
local waits, waitLimit = 0, math.huge
Wait = function() waits = waits + 1; if waits > waitLimit then error("stop-loop") end end
local function run(fn, limit)
    waits, waitLimit = 0, limit
    local ok, err = pcall(fn)
    waitLimit = math.huge
    return ok, err
end
RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
AddEventHandler = function(name, fn) eventHandlers[name] = fn end
TriggerClientEvent = function(name, target, payload) clientEvents[#clientEvents + 1] = { name = name, target = target, payload = payload } end
GetCurrentResourceName = function() return "op77_lightrp" end
local players = { "1", "2" }
GetPlayers = function() return players end
GetPlayerRoutingBucket = function() return 0 end

local turfList, turfFails = {}, false
exports = setmetatable({}, { __index = function(_, name)
    if name == "op77_turf" then
        return { influence = function(_, limit)
            if turfFails then error("op77_turf is stopped") end
            local out = {}
            for i, r in ipairs(turfList) do if i <= limit then out[i] = r end end
            return out, 2914
        end }
    end
    error("no export " .. tostring(name))
end })

-- props: ids from 500, a store the respawn check reads
local store, created, moved, removed, nextProp, refuseCreate = {}, {}, {}, {}, 500, nil
local kv, kvpSet = {}, {}
local listenCalls, handler = {}, nil
local stand = { position = { x = H.center.x, y = H.center.y, z = H.center.z }, heading = 90 }
local function freshOpen77()
    Open77 = {
        http = { listen = function(prefix, fn) listenCalls[#listenCalls + 1] = prefix; handler = fn; return "/op77_lightrp" .. prefix end },
        props = {
            create = function(def)
                if refuseCreate then return nil, refuseCreate end
                nextProp = nextProp + 1
                created[#created + 1] = def
                store[tostring(nextProp)] = { id = nextProp, model = def.model, resource = "op77_lightrp", position = def.position }
                return nextProp
            end,
            setTransform = function(id, def)
                if not store[tostring(id)] then return false, "not_found" end
                moved[#moved + 1] = { id = id, def = def }
                store[tostring(id)].position = def.position
                return true
            end,
            get = function(id) return store[tostring(id)] end,
            remove = function(id) removed[#removed + 1] = tostring(id); store[tostring(id)] = nil; return true end,
            all = function() local out = {}; for _, s in pairs(store) do out[#out + 1] = s end; return out end,
        },
        kvp = {
            get = function(key) return kv[key] end,
            set = function(key, value) kv[key] = value; kvpSet[#kvpSet + 1] = key; return true end,
            delete = function(key) kv[key] = nil; return true end,
        },
        players = {
            get = function() return { position = stand.position, heading = stand.heading } end,
            position = function() return stand.position end,
        },
    }
end
freshOpen77()

dofile("server/modules/events_board_fonts.lua")
dofile("server/modules/events_board_page.lua")
dofile("server/modules/events_board.lua")
local EB = LightRP.eventsBoard
assert(EB, "registered as a module (the guide's module:eventsBoard)")

-- ---------------------------------------------------------------------------
-- HTTP: one route, the page and the data

assert(#listenCalls == 1 and listenCalls[1] == "/board" and EB.http.route == "/op77_lightrp/board")
assert(logged("events board: serving /op77_lightrp/board (the TV loads http://127.0.0.1:11781/op77_lightrp/board/)"))
assert(EB.url() == "http://127.0.0.1:11781/op77_lightrp/board/", "the local default from the listener's origin")

local function call(method, path)
    local out = {}
    local res = { send = function(status, body, headers) out.status, out.body, out.headers = status, body, headers; return true end }
    handler({ method = method, path = path, query = "", headers = {} }, res)
    return out
end
local page = call("GET", "/board/")
assert(page.status == 200 and page.headers["Content-Type"] == "text/html; charset=utf-8", "the page")
assert(page.body:sub(1, 15) == "<!doctype html>" and page.body:find("view.json", 1, true), "it polls view.json next to itself")
assert(page.body:find("@font-face{font-family:'Zen Dots'", 1, true) and page.body:find("data:font/woff2;base64,", 1, true), "fonts inlined")
assert(page.body:find('"pollMs":10000', 1, true) and page.body:find('"rotateMs":5000', 1, true), "the config in the script")
assert(not page.body:find("https?://") , "no external host (no CDN)")
assert(#page.body < 256 * 1024, "under the listener's 256 KiB answer: " .. #page.body)
assert(page.headers["Content-Security-Policy"]:find("connect-src 'self'", 1, true))
assert(call("GET", "/board").status == 200 and call("GET", "/board/index.html").status == 200, "with or without the slash")
local data = call("GET", "/board/view.json")
assert(data.status == 200 and data.headers["Content-Type"] == "application/json; charset=utf-8")
assert(data.body:find('"now":1000000', 1, true) and data.body:find('"turf":{', 1, true) and data.body:find('"boss":{', 1, true))
local missing = call("GET", "/board/secret")
assert(missing.status == 404 and missing.body == '{"error":"not_found"}', "an unknown route")
assert(call("GET", "/boardx").status == 404 and call("GET", "/elsewhere").status == 404)
local post = call("POST", "/board/view.json")
assert(post.status == 405 and post.headers.Allow == "GET, HEAD")
local head = call("HEAD", "/board/view.json")
assert(head.status == 200 and head.body == "")
-- the page's script never sees markup from a string
local P = LightRpEventsBoardPage
assert(not P.jsonString("</script><b>&"):find("[<>&]"), "a string cannot close the script")
assert(P.render({ title = "A \"quoted\" title", hub = "Hub" }):find('"title":"A \\"quoted\\" title"', 1, true))

-- ---------------------------------------------------------------------------
-- The TV: along the hub's heading, facing its centre; the clients told

local function offsetOf(forward, right)
    local h = math.rad(H.heading)
    return H.center.x - math.sin(h) * forward + math.cos(h) * right, H.center.y + math.cos(h) * forward + math.sin(h) * right
end
local ex, ey = offsetOf(12, 4)
assert(near(EB.tv.position.x, ex) and near(EB.tv.position.y, ey) and EB.tv.position.z == H.center.z, "forward 12 / right 4")
local faceCenter = math.deg(math.atan(-(H.center.x - ex), H.center.y - ey)) % 360
assert(near(EB.tv.heading, faceCenter) and EB.tv.source == "offset from The Crossing", "the screen faces the hub's centre")
local d = math.sqrt((ex - H.center.x) ^ 2 + (ey - H.center.y) ^ 2)
assert(d > 10 and d < 15, "near the centre")

assert(#threads == 2, "the TV thread and the cache timer")
local tvThread, cacheThread = threads[1], threads[2]
local ok, err = run(tvThread, 0)
assert(not ok and err:find("stop-loop", 1, true), "made at the first try, then the respawn check waits: " .. tostring(err))
assert(#created == 1, "one prop")
local def = created[1]
assert(def.model == "electronics.tv.16x9" and def.scale == 3.0 and near(def.yaw, faceCenter) and def.bucket == 0)
assert(def.physics == "static" and def.collision == true and def.streamingRadius == 150)
assert(EB.tv.prop == "501" and logged("events board: TV tv.16x9 at"))
local told = clientEvents[#clientEvents]
assert(told.name == E.net.eventsBoardTv and told.target == -1)
local info = told.payload
-- the surface at the rectangle's own aspect (1.16 x 0.66: 1280 x 728, as open77_media sizes it)
assert(info.prop == "501" and info.url == "http://127.0.0.1:11781/op77_lightrp/board/" and info.width == 1280 and info.height == 728,
    string.format("%s %s %s %s", tostring(info.prop), tostring(info.url), tostring(info.width), tostring(info.height)))
assert(near(info.quad.width, 3.48) and near(info.quad.height, 1.98), "the picture at x3")
assert(near(info.quad.offset.x, 0) and near(info.quad.offset.y, 0.346182) and near(info.quad.offset.z, 1.26), "the offset scaled too")
assert(info.quad.right.x == 1 and info.quad.up.z == 1 and info.quad.faces.y == 1, "named vectors (the native's shape)")
assert(info.drawRadius == 60 and info.drawHysteresis == 15 and info.fps == 15 and info.position == EB.tv.position)

-- a client asks (script restart): told alone, at most once a second
source = 7
netHandlers[E.net.eventsBoardHello]()
assert(clientEvents[#clientEvents].target == 7)
local before = #clientEvents
netHandlers[E.net.eventsBoardHello]()
assert(#clientEvents == before, "rate limited")
clock = clock + 1500
netHandlers[E.net.eventsBoardHello]()
assert(#clientEvents == before + 1)
source = 0
netHandlers[E.net.eventsBoardHello]()
assert(#clientEvents == before + 1, "the server itself is not a client")

-- gone: made again by the respawn check (Johnny's pattern)
store["501"] = nil
local remade = EB.watch()
assert(remade == true and EB.tv.prop == "502" and #created == 2 and clientEvents[#clientEvents].payload.prop == "502")
assert(EB.watch() == false, "standing: nothing to do")

-- a hot reload left a TV of this resource where the new one goes: swept
store["900"] = { id = 900, model = "electronics.tv.16x9", resource = "op77_lightrp", position = { x = ex + 1, y = ey, z = 0 } }
store["901"] = { id = 901, model = "electronics.tv.16x9", resource = "open77_media", position = { x = ex, y = ey, z = 0 } }
EB.tv.prop = nil
assert(EB.placeProp() == true)
assert(store["900"] == nil and store["901"] ~= nil, "only our own orphan goes")

-- ---------------------------------------------------------------------------
-- Staff: place (kvp + config line), where, reset, respawn, refresh

local cmd = commands["lightrp.board"]
assert(cmd and cmd.options.restricted == true, "restricted (command.lightrp.* in acl.jsonc)")
stand.position, stand.heading = { x = 100.0, y = 200.0, z = 30.0 }, 90
local okPlace, line = cmd.fn(3, { "place" })
assert(okPlace and line:find("position = { x = 101.500, y = 200.000, z = 30.000 }, heading = 90.0,", 1, true), tostring(line))
assert(line:find("bucket 0", 1, true) and line:find("kept until /lightrp.board reset", 1, true))
assert(kv[EB.KVP_PLACEMENT] == "101.500,200.000,30.000,90.0", "saved in kvp")
assert(moved[#moved].id == EB.tv.prop and moved[#moved].def.yaw == 90, "the standing TV moved, not a new one")
assert(clientEvents[#clientEvents].payload.position.x == 101.5)
assert(not cmd.fn(0, { "place" }), "in game only")
GetPlayerRoutingBucket = function() return 4 end
assert(not cmd.fn(3, { "place" }), "in the city only")
GetPlayerRoutingBucket = function() return 0 end
local okWhere, where = cmd.fn(3, { "where" })
assert(okWhere and where:find("staff placement (kvp)", 1, true) and where:find("page http://127.0.0.1:11781/op77_lightrp/board/", 1, true))

-- the kvp override wins at the next start, over the config
local pos, heading, src = EB.placement()
assert(pos.x == 101.5 and pos.y == 200 and heading == 90 and src == "staff placement (kvp)")
C.tv.position = { x = 5, y = 6, z = 7 }
pos = EB.placement()
assert(pos.x == 101.5, "kvp before the config position")
kv[EB.KVP_PLACEMENT] = "garbage"
pos, heading, src = EB.placement()
assert(pos.x == 5 and src == "config position", "an unreadable kvp value is ignored")
C.tv.position = nil
local okReset, resetLine = cmd.fn(3, { "reset" })
assert(okReset and kv[EB.KVP_PLACEMENT] == nil and resetLine:find("Back to the config", 1, true))
assert(near(EB.tv.position.x, ex) and EB.tv.source == "offset from The Crossing")
local propBefore = EB.tv.prop
local okRespawn = cmd.fn(3, { "respawn" })
assert(okRespawn and removed[#removed] == propBefore and EB.tv.prop ~= propBefore, "respawn: a new prop")
assert(cmd.fn(3, { "refresh" }) and EB.cacheState.reason == "staff")
assert(cmd.fn(3, { "nope" }) == false)

-- aim [scale]: the client reads the crosshair, the TV hangs on that surface
local notices = {}
LightRP.notice = function(id, n) notices[#notices + 1] = { id = id, n = n } end
local function aimed(id, reply) _G.source = id; netHandlers[E.net.eventsBoardAimed](reply); _G.source = nil end
stand.position, stand.heading = { x = 100.0, y = 200.0, z = 30.0 }, 90
local okAim, aimText = cmd.fn(3, { "aim", "5" })
local ask = clientEvents[#clientEvents]
assert(okAim and aimText:find("scale 5.00", 1, true) and ask.name == E.net.eventsBoardAim and ask.target == 3 and ask.payload.token, "asks the staff's client")
assert(not cmd.fn(3, { "aim", "huge" }), "a scale is a number")
assert(not cmd.fn(0, { "aim" }), "in game only")
-- a wall facing west (normal -X) 20 m east of the staff, at 38 m up: the picture centred there
local propAim = EB.tv.prop
aimed(3, { token = ask.payload.token, position = { x = 120, y = 200, z = 38 }, normal = { x = -1, y = 0, z = 0 } })
local q = EB.screen(5).quad
assert(near(EB.tv.heading, 90) and EB.tv.scale == 5, "faces out of the wall (west = 90), scale 5")
assert(near(EB.tv.position.x, 120 - 0.06 * 5) and near(EB.tv.position.y, 200 + q.offset.x * -1) and near(EB.tv.position.z, 38 - q.offset.z), "back on the wall, picture centred on the hit")
assert(near(q.width, 1.16 * 5) and near(q.offset.z, 0.42 * 5), "the quad at the new scale")
assert(removed[#removed] == propAim and EB.tv.prop ~= propAim and created[#created].scale == 5, "a new scale is a new prop")
assert(kv[EB.KVP_PLACEMENT] == string.format("%.3f,%.3f,%.3f,%.1f,%.2f", EB.tv.position.x, EB.tv.position.y, EB.tv.position.z, 90, 5), "saved with its scale")
assert(notices[#notices].id == 3 and notices[#notices].n.kind == "success", "told")
assert(clientEvents[#clientEvents].name == E.net.eventsBoardTv and near(clientEvents[#clientEvents].payload.quad.width, 1.16 * 5), "clients get the bigger screen")
local p5, h5, s5, sc5 = EB.placement()
assert(p5.x == tonumber(string.format("%.3f", EB.tv.position.x)) and h5 == 90 and sc5 == 5, "the next start keeps the scale")
local _, whereAim = cmd.fn(3, { "where" })
assert(whereAim:find("scale = 5.00", 1, true), "where says the scale")
-- the same scale again: moved, not remade
cmd.fn(3, { "aim" })
local propKeep = EB.tv.prop
aimed(3, { token = clientEvents[#clientEvents].payload.token, position = { x = 100, y = 230, z = 34 }, normal = { x = 0, y = -1, z = 0 } })
assert(EB.tv.prop == propKeep and EB.tv.scale == 5 and near(EB.tv.heading, 180), "kept scale, moved; faces south")
-- the ground: faces the staff instead; no surface: told, nothing moves
cmd.fn(3, { "aim" })
aimed(3, { token = clientEvents[#clientEvents].payload.token, position = { x = 100, y = 190, z = 30 }, normal = { x = 0, y = 0, z = 1 },
    from = { x = 100, y = 200, z = 30 } })
assert(near(EB.tv.heading, 0), "a floor hit faces the staff (north)")
local before = EB.tv.position.x
cmd.fn(3, { "aim" })
aimed(3, { token = clientEvents[#clientEvents].payload.token, error = "nothing_under_crosshair" })
assert(EB.tv.position.x == before and notices[#notices].n.body:find("Nothing under your crosshair", 1, true))
-- too far, a stale or foreign answer, a second answer
cmd.fn(3, { "aim" })
aimed(3, { token = clientEvents[#clientEvents].payload.token, position = { x = 900, y = 200, z = 30 }, normal = { x = -1, y = 0, z = 0 } })
assert(EB.tv.position.x == before and notices[#notices].n.body:find("Too far", 1, true))
local n0 = #notices
aimed(3, { token = 1, position = { x = 110, y = 200, z = 30 }, normal = { x = -1, y = 0, z = 0 } })
aimed(4, { token = 1, position = { x = 110, y = 200, z = 30 }, normal = { x = -1, y = 0, z = 0 } })
assert(EB.tv.position.x == before and #notices == n0, "nothing pending: ignored")
cmd.fn(3, { "aim" })
local tok = clientEvents[#clientEvents].payload.token
clock = clock + 11000
aimed(3, { token = tok, position = { x = 110, y = 200, z = 30 }, normal = { x = -1, y = 0, z = 0 } })
assert(EB.tv.position.x == before, "an answer after 10 s is dropped")
-- reset: the config's spot and scale
cmd.fn(3, { "reset" })
assert(EB.tv.scale == nil and EB.screen().scale == C.tv.scale and kv[EB.KVP_PLACEMENT] == nil, "reset: the config's scale")
assert(EB.parsePlacement("1,2,3,90") and select(3, EB.parsePlacement("1,2,3,90")) == nil, "a four-field kvp value: no scale")
assert(select(3, EB.parsePlacement("1,2,3,90,99")) == 12, "a saved scale is clamped")
LightRP.notice = nil

-- ---------------------------------------------------------------------------
-- The view: each provider from its source

-- turf: the status lines of op77_turf (server/war.lua warStatus)
local t = clock
assert(EB.readTurf(t).state == "none" and EB.readTurf(t).headline == "NO TURF WAR SCHEDULED", "op77_turf not running")
registry["turf.war"] = { id = "turf.war", label = "Turf War", kind = "pvp",
    status = { phase = "running", players = 9, queued = 2, detail = "Watson" .. SEP .. "Tyger Claws vs Maelstrom" .. SEP .. "~12 min left" } }
local turf = EB.readTurf(t)
assert(turf.state == "live" and turf.headline == "LIVE NOW" and turf.where == "Watson" and turf.players == 9 and turf.queued == 2)
assert(turf.line == "Tyger Claws vs Maelstrom" .. SEP .. "~12 min left")
registry["turf.war"].status.detail = "Friendly match" .. SEP .. "Kabuki" .. SEP .. "A vs B" .. SEP .. "~3 min left"
turf = EB.readTurf(t)
assert(turf.where == "Kabuki" and turf.line:sub(1, 14) == "Friendly match", "a match keeps its kind in the line")
registry["turf.war"].status.detail = "Kabuki" .. SEP .. "war over"
assert(EB.readTurf(t).state == "over" and EB.readTurf(t).headline == "WAR OVER")
registry["turf.war"].status = { phase = "lobby", players = 0, queued = 3, detail = "3/6 fighters queued" }
turf = EB.readTurf(t)
assert(turf.state == "forming" and turf.where == nil and turf.line == "3/6 fighters queued" and turf.queued == 3)
registry["turf.war"].status = { phase = "idle", players = 0, queued = 0, detail = "Scheduled: Japantown in ~14 min" }
turf = EB.readTurf(t)
assert(turf.state == "scheduled" and turf.where == "Japantown" and turf.atMs == t + 14 * 60000 and turf.approx == true)
assert(turf.headline == "IN {t}" and turf.due == "STARTING")
registry["turf.war"].status = { phase = "idle", players = 0, queued = 0, detail = "Gang war for a district. Queue and keep playing." }
turf = EB.readTurf(t)
assert(turf.state == "open" and turf.headline == "NO WAR SCHEDULED" and turf.line)

-- world bosses
assert(EB.readBoss(t).state == "none", "no world boss module")
local current, catalogue, nextAt = nil, {}, nil
LightRP.worldBosses = { current = function() return current end, catalogue = function() return catalogue end, nextAt = function() return nextAt end }
LightRpWorldBosses = { enabled = true, schedule = { minPlayers = 3 } }
nextAt = t + 30 * 60000
assert(EB.readBoss(t).headline == "NO WORLD BOSS SCHEDULED", "no published world boss: none scheduled")
catalogue = { { id = "wb1", title = "Smasher's Return" } }
local boss = EB.readBoss(t)
assert(boss.state == "scheduled" and boss.atMs == nextAt and boss.headline == "IN {t}" and boss.line == "Needs 3 players in the city")
players = { "1", "2", "3" }
assert(EB.readBoss(t).line == "Location revealed when it spawns")
nextAt = t - 5000
assert(EB.readBoss(t).atMs == t, "overdue: any moment, never in the past")
current = { def = { title = "Smasher's Return" }, bossLabel = "Adam Smasher", location = "Northside", phase = "fight",
    bossFraction = 0.42, fighters = 5, endsAt = t + 600000 }
boss = EB.readBoss(t)
assert(boss.state == "live" and boss.where == "Northside" and boss.health == 0.42 and boss.fighters == 5 and boss.endsAtMs == t + 600000)
assert(boss.line == "Adam Smasher" .. SEP .. "Smasher's Return")
current.phase, current.success = "cleanup", true
assert(EB.readBoss(t).state == "over" and EB.readBoss(t).headline == "BOSS DOWN")
current.phase, current.success = "done", false
assert(EB.readBoss(t).headline == "GOT AWAY")
current = nil
LightRpWorldBosses.enabled = false
assert(EB.readBoss(t).state == "none", "world bosses off")
LightRpWorldBosses.enabled = true

-- activities: live, then forming, then open; by label; at most activities.max
registry["arena.ffa"] = { id = "arena.ffa", label = "Combat Zone", kind = "pvp", status = { phase = "running", players = 6, queued = 1, detail = "Round 2" } }
registry["race.trial"] = { id = "race.trial", label = "Time Trial", kind = "race", status = { phase = "lobby", players = 0, queued = 2, detail = "2/4 racers" } }
registry["chase.1v1"] = { id = "chase.1v1", label = "NCPD Chase", kind = "chase", status = { phase = "idle", players = 0, queued = 0, detail = "Run from the cops." } }
registry["arena.duel"] = { id = "arena.duel", label = "Duel", kind = "pvp" } -- no status yet
local acts = EB.readActivities()
local order = {}
for i, a in ipairs(acts) do order[i] = a.id end
assert(table.concat(order, ",") == "arena.ffa,race.trial,arena.duel,chase.1v1,turf.war", table.concat(order, ","))
assert(acts[1].state == "live" and acts[1].players == 6 and acts[1].line == "Round 2")
assert(acts[3].state == "open" and acts[3].line == nil, "an open activity: no detail line")
C.activities.max = 2
assert(#EB.readActivities() == 2)
C.activities.max = 7

-- weekly: turf influence (export) and Dogtown kills (this week's board only)
turfList = { { gang = "tyger_claws", label = "Tyger Claws", color = "#E8C13A", points = 1234, wins = 3 },
    { gang = "maelstrom", label = "Maelstrom", color = "red", points = 40 }, { gang = "voodoo", label = "Voodoo Boys", points = 0 } }
local week = 2914
LightRP.dogtown = { board = function() return { week = week, rows = { { rank = 1, name = "Nyx Vale", kills = 12 }, { rank = 2, name = "Jax", kills = 0 } } } end,
    weekIndex = function() return 2914 end }
local weekly = EB.readWeekly()
assert(#weekly == 2 and weekly[1].key == "turf" and weekly[2].key == "dogtown")
assert(#weekly[1].rows == 2 and weekly[1].rows[1].value == "1,234 pts" and weekly[1].rows[1].color == "#E8C13A")
assert(weekly[1].rows[2].color == nil, "a colour that is not #RRGGBB is dropped")
assert(#weekly[2].rows == 1 and weekly[2].rows[1].name == "Nyx Vale" and weekly[2].rows[1].value == "12 kills")
week = 2913
assert(#EB.readWeekly()[2].rows == 0 and EB.readWeekly()[2].empty, "last week's board: empty this week, said so")
turfFails = true
assert(#EB.readWeekly() == 1 and EB.readWeekly()[1].key == "dogtown", "op77_turf stopped: no turf board")
turfFails = false
LightRpDogtown = { enabled = false }
assert(#EB.readWeekly() == 1, "Dogtown off: no Dogtown board")
LightRpDogtown = nil

-- records: the Hall of Fame cache, all time
assert(#EB.readRecords() == 0, "no Hall of Fame")
LightRP.hallOfFame = { cache = function() return { boards = {
    ["pvp.wins"] = { def = { title = "MOST WINS", unit = "wins" }, meta = {}, rows = {
        { rank = 1, name = "Mira Sol", value = 14 }, { rank = 2, name = "Jax Rook", value = 9 }, { rank = 2, name = "Tomas", value = 9 }, { rank = 4, name = "X", value = 1 } } },
    ["pve.wins"] = { def = { title = "PVE WINS", unit = "wins" }, meta = {}, rows = {} },
} } end }
local records = EB.readRecords()
assert(#records == 2 and records[1].title == "MOST WINS" and records[1].subtitle == "All time" and #records[1].rows == 3)
assert(records[1].rows[1].value == "14 wins" and records[1].rows[3].rank == 2, "shared ranks kept")
assert(#records[2].rows == 0 and records[2].empty)
assert(EB.display(61234, "time") == "1:01.2" and EB.display(1600, "rep") == "1,600 rep" and EB.display(7, "count") == "7")
assert(EB.display(2500, "eddies") == "\u{20AC}$2,500", "eddies without the money module")
assert(EB.display(1, "wins") == "1 win" and EB.display(1, "clears") == "1 clear" and EB.display(1, "rep") == "1 rep", "singular for one")
assert(EB.counted(1, "kills") == "1 kill" and EB.counted(1, "pts") == "1 pt" and EB.counted(2, "kills") == "2 kills")

-- the whole view, and a provider that fails alone (one log line, an empty section)
local view = EB.build("test")
assert(view.v == 1 and view.title == "WHAT'S ON" and view.hub == "The Crossing" and view.join == "Join with Adam Smasher here, or F1 > Activities")
assert(view.turf.state == "open" and view.boss.state == "scheduled" and #view.activities == 5 and #view.weekly == 2 and #view.records == 2)
EB.providers.records = function() error("boom") end
logs = {}
view = EB.build("test")
assert(#view.records == 0 and view.turf.state == "open", "the others still answer")
assert(logged("events board: the records section failed"))
EB.build("test")
local count = 0
for _, l in ipairs(logs) do if l:find("records section failed", 1, true) then count = count + 1 end end
assert(count == 1, "logged once, not at every rebuild")
EB.providers.records = EB.readRecords

-- the cache: rebuilt when stale; view.json counts from the server's clock
local builtAt = EB.cacheState.at
assert(EB.view() == EB.cacheState.view and EB.cacheState.at == builtAt, "fresh: the cache")
clock = clock + C.refreshMs
EB.view()
assert(EB.cacheState.at == clock, "stale: rebuilt")
assert(EB.payload().now == clock and EB.cacheState.view.now == nil, "now is added to the answer, not the cache")
-- the cache timer thread rebuilds, and an activity's status pokes a rebuild soon
local okTimer, errTimer = run(cacheThread, 1)
assert(not okTimer and errTimer:find("stop-loop", 1, true) and EB.cacheState.reason == "timer")
local status = eventHandlers["op77_lightrp:activity:status"]
assert(status, "hooked on the activities' status event")
local n = #threads
status(); status()
assert(#threads == n + 1, "one pending rebuild for a burst of statuses")
run(threads[#threads], 5)
assert(EB.cacheState.reason == "status" and EB.cacheState.pending == false)

-- ---------------------------------------------------------------------------
-- Fallbacks: no HTTP, no props, no kvp, disabled

local function reload()
    logs, threads, clientEvents, listenCalls = {}, {}, {}, {}
    dofile("server/modules/events_board.lua")
    return LightRP.eventsBoard
end
-- the listener off in the server config
Open77.http.listen = function() return nil, "http_handlers_unavailable" end
EB = reload()
assert(EB.http.route == nil and logged("events board: no HTTP route (http_handlers_unavailable): the TV stays dark"))
run(threads[1], 0)
assert(EB.tv.prop and clientEvents[#clientEvents].payload.url == false, "the TV stands, dark: no URL to load")
-- no Open77.http at all
Open77.http = nil
EB = reload()
assert(EB.http.route == nil and logged("no HTTP route (Open77.http unavailable)"))
-- a configured public URL is used as given once the route exists
freshOpen77()
C.url = "https://play.example.net/board/"
EB = reload()
run(threads[1], 0)
assert(clientEvents[#clientEvents].payload.url == "https://play.example.net/board/" and logged("the TV loads https://play.example.net/board/"))
C.url = "javascript:alert(1)"
assert(EB.url() == "http://127.0.0.1:11781/op77_lightrp/board/" and logged("is not an http(s) address"), "not an address: the listener's")
C.url = nil
-- no props layer: no TV, one line, the page still served
Open77.props = nil
EB = reload()
local okSpawn, why = run(threads[1], 0)
assert(not okSpawn and EB.tv.prop == nil and logged("no props layer here: no TV (the page is still served)"))
assert(EB.http.route and EB.info().prop == false and EB.info().url == false)
assert(EB.watch() == false, "the respawn check does nothing without props")
-- the props layer refuses: retried, then given up with one line per state
freshOpen77()
refuseCreate = "unknown_model"
EB = reload()
local okRetry, errRetry = run(threads[1], 2)
assert(not okRetry and errRetry:find("stop-loop", 1, true) and logged("TV not made yet (unknown_model): retrying"))
refuseCreate = nil
-- no kvp: placed for this session, said so
Open77.kvp = nil
EB = reload()
local okNoKvp, noKvpLine = commands["lightrp.board"].fn(3, { "place" })
assert(okNoKvp and noKvpLine:find("this session only, not saved: kvp_unavailable", 1, true))
assert(EB.placement() and select(3, EB.placement()) == "offset from The Crossing", "nothing saved: the config next time")
-- disabled: no module at all (the guide's question hides)
freshOpen77()
LightRP.eventsBoard = nil
C.enabled = false
reload()
assert(LightRP.eventsBoard == nil and #listenCalls == 0 and #threads == 0, "disabled: nothing registered, nothing served")
C.enabled = true

-- ---------------------------------------------------------------------------
-- The client: the page on the TV's screen while near it

local surfaces, binds, unbinds, destroyed = {}, {}, {}, 0
local me = { x = 0, y = 0, z = 0 }
local clientNet, clientThreads, clientHandlers, sent = {}, {}, {}, {}
local refusePage = nil
LightRpUi = { log = function(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end }
RegisterNetEvent = function(name, fn) clientNet[name] = fn end
CreateThread = function(fn) clientThreads[#clientThreads + 1] = fn end
AddEventHandler = function(name, fn) clientHandlers[name] = fn end
local sentPayload = {}
TriggerServerEvent = function(name, payload) sent[#sent + 1] = name; sentPayload[#sent] = payload; return true end
local timer = 0
GetGameTimer = function() return timer end
WebUI = { create = function(opts)
    if refusePage then return nil, refusePage end
    local page = { opts = opts }
    function page:destroy() destroyed = destroyed + 1 end
    surfaces[#surfaces + 1] = page
    return page
end }
Open77 = { character = { position = function() return me.x, me.y, me.z end },
    media = { bind = function(def) binds[#binds + 1] = def; return tostring(#binds) end, unbind = function(id) unbinds[#unbinds + 1] = id; return true end } }
logs = {}
dofile("client/core/events_board.lua")
clientHandlers.onClientResourceStart("op77_lightrp")
assert(sent[1] == E.net.eventsBoardHello, "a started script asks for the TV")
local tick = clientThreads[1]
local function step() waits, waitLimit = 0, 1; pcall(tick); waitLimit = math.huge end
local tvInfo = { prop = "501", url = "http://127.0.0.1:11781/op77_lightrp/board/", position = { x = 0, y = 50, z = 0 },
    quad = { offset = { x = 0, y = 0.35, z = 1.26 }, right = { x = 1, y = 0, z = 0 }, up = { x = 0, y = 0, z = 1 }, width = 3.48, height = 1.98, faces = { x = 0, y = 1, z = 0 } },
    width = 1280, height = 720, fps = 15, label = "The Crossing: events board", drawRadius = 60, drawHysteresis = 15 }
clientNet[E.net.eventsBoardTv](tvInfo)
step()
assert(#surfaces == 1 and #binds == 1, "in range: one page, one screen")
local opts = surfaces[1].opts
assert(opts.entry == tvInfo.url and opts.hudSuppressed == true and opts.transparent == false and opts.layer == "hud" and opts.width == 1280 and opts.height == 720)
assert(binds[1].prop == "501" and binds[1].page == surfaces[1] and binds[1].quad.offset.z == 1.26 and binds[1].quad.right.x == 1)
step()
assert(#surfaces == 1, "already up: nothing new")
me.y = -20 -- 70 m: inside the slack
step()
assert(#unbinds == 0)
me.y = -30 -- 80 m: past radius + hysteresis
step()
assert(#unbinds == 1 and destroyed == 1, "out of range: unbound and destroyed")
me.y = 0
step()
assert(#surfaces == 2, "back in range: up again")
tvInfo = { prop = "777", url = tvInfo.url, position = tvInfo.position, quad = tvInfo.quad, width = 1280, height = 720, drawRadius = 60, drawHysteresis = 15 }
clientNet[E.net.eventsBoardTv](tvInfo)
step()
assert(#unbinds == 2 and #surfaces == 3 and binds[#binds].prop == "777", "a new prop: the screen follows it")
clientNet[E.net.eventsBoardTv]({ prop = "777", url = false, position = tvInfo.position })
step()
assert(#unbinds == 3 and #surfaces == 3, "no page to show (HTTP off): nothing on the screen")
-- a refused page: one line, then a pause before the next try
refusePage = "undeclared_entry"
clientNet[E.net.eventsBoardTv](tvInfo)
step(); step()
local refusals = 0
for _, l in ipairs(logs) do if l:find("page not created (undeclared_entry)", 1, true) then refusals = refusals + 1 end end
assert(refusals == 1 and #surfaces == 3, "logged once")
refusePage = nil
step()
assert(#surfaces == 3, "waits before trying again")
timer = timer + 31000
step()
assert(#surfaces == 4, "then tries again")
-- no native media API on this client: one line, no page
Open77.media = nil
clientHandlers.onClientResourceStop("op77_lightrp")
clientNet[E.net.eventsBoardTv](tvInfo)
step(); step()
assert(#surfaces == 4 and logged("the native media API is missing on this client"))

-- /lightrp.board aim: the crosshair's hit back to the server (static + terrain first)
local rays = {}
Open77.camera = { aimRay = function(dist, opts)
    rays[#rays + 1] = { dist = dist, opts = opts }
    if opts and opts.groups then return nil, "invalid_options" end -- an older client
    return { hit = true, position = { x = 10, y = 20, z = 8 }, normal = { x = 0, y = -1, z = 0 }, distance = 30 }
end }
me.x, me.y, me.z = 10, 0, 0
clientNet[E.net.eventsBoardAim]({ token = 7, maxDistance = 250 })
local reply = sentPayload[#sent]
assert(sent[#sent] == E.net.eventsBoardAimed and reply.token == 7 and reply.position.z == 8 and reply.normal.y == -1 and reply.from.x == 10, "the hit, the normal, the staff")
assert(rays[1].dist == 250 and rays[1].opts.groups[1] == "Static" and rays[2].opts.dynamic == false, "grouped trace, then the static one")
Open77.camera.aimRay = function() return { hit = false } end
clientNet[E.net.eventsBoardAim]({ token = 8 })
assert(sentPayload[#sent].token == 8 and sentPayload[#sent].error == "nothing_under_crosshair")
Open77.camera = nil
clientNet[E.net.eventsBoardAim]({ token = 9 })
assert(sentPayload[#sent].error == "aim_unavailable", "no aim API: said so")

-- ---------------------------------------------------------------------------
-- The manifest

local m = assert(io.open("open77.lua", "rb")); local manifest = m:read("*a"); m:close()
local function at(text) return assert(manifest:find(text, 1, true), "manifest: " .. text) end
assert(at('server_script "server/config/events_board.lua"') < at('server_script "server/modules/events_board_fonts.lua"'))
assert(at('server_script "server/modules/events_board_page.lua"') < at('server_script "server/modules/events_board.lua"'))
assert(at('server_script "server/modules/activities.lua"') < at('server_script "server/modules/events_board.lua"'), "after activities: the status hook")
at('client_script "client/core/events_board.lua"')
at('"http.serve"')

print("PASS: events board view from turf, world bosses, activities, weekly boards and records (a failing provider alone), routes (page, view.json, 404, 405, HEAD), TV along the hub heading with respawn and orphan sweep, staff place/aim (wall, floor, scale, too far, stale)/where/reset/respawn with kvp, client screen in range with slack, client aim reply, fallbacks without HTTP, props, kvp or when disabled")
