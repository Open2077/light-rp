-- The events board at The Crossing (server/config/events_board.lua): a television by
-- the hub showing what is on in the city.
--
--   the view   one cached table: the next turf war (op77_turf's status line), the next
--              world boss (world_bosses.lua), the activities live, forming or open
--              (activities.lua registry), this week's boards (turf influence, Dogtown
--              kills) and the all-time records (the Hall of Fame cache). Rebuilt every
--              refreshMs, and soon after an activity's status changes. Every reader is
--              a provider in EB.providers, so a missing module empties its section
--              and nothing else.
--   the page   GET <route>/ answers the whole page (HTML, CSS, JS and fonts, from
--              events_board_page.lua), GET <route>/view.json the data, anything else
--              404. Read only; the only names in it are the ones the Hall of Fame and
--              the Dogtown board already show.
--   the TV     a prop this resource owns (config tv), respawned when it disappears.
--              The clients near it paint the page on its screen
--              (client/core/events_board.lua, Open77.media.bind).
--   the staff  /lightrp.board [where|place|reset|respawn|refresh]: place keeps the
--              spot in kvp and prints the line to paste into the config.
--
-- open77_media is not used, and cannot be driven from here: its spawn and control
-- events drop a caller without a player source (a server script has none) and check
-- that player's media ACL; its console commands need operator authority and answer
-- no id; a prop can only be moved by the resource that made it; and its page frames
-- https only, with a notice bar over any site that is not YouTube.
local C = LightRpEventsBoard
if type(C) ~= "table" or C.enabled == false then return end

local E = LightRpEvents
local EB = LightRP.module("eventsBoard", {})

local SELF = type(GetCurrentResourceName) == "function" and GetCurrentResourceName() or "op77_lightrp"
local KVP_PLACEMENT = "events_board.tv.placement" -- "x,y,z,heading": the staff's spot, until copied into the config
EB.KVP_PLACEMENT = KVP_PLACEMENT
local SEP = " \u{B7} "
local JSON_TYPE = "application/json; charset=utf-8"
local PAGE_CSP = "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; font-src data:; "
    .. "img-src data:; connect-src 'self'; base-uri 'none'; form-action 'none'"

local function now() return LightRP.nowMs() end
local function log(...) LightRP.log(...) end
local function cfg(path, default)
    local v = C
    for part in path:gmatch("[^.]+") do v = type(v) == "table" and v[part] or nil end
    if v == nil then return default end
    return v
end
local function num(value, default) local n = tonumber(value); if n == nil or n ~= n then return default end; return n end
local function int(value) local n = num(value, 0); return math.max(0, math.floor(n)) end
local function clip(text, max)
    if type(text) ~= "string" then return nil end
    text = text:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    if #text <= max then return text end
    local cut = max - 3
    while cut > 0 do local b = text:byte(cut + 1); if not b or b < 0x80 or b >= 0xC0 then break end; cut = cut - 1 end
    return text:sub(1, cut) .. "..."
end
local function split(text, sep)
    local out, from = {}, 1
    while true do
        local a, b = text:find(sep, from, true)
        if not a then out[#out + 1] = text:sub(from); break end
        out[#out + 1] = text:sub(from, a - 1)
        from = b + 1
    end
    return out
end
local function thousands(n)
    local s = tostring(math.floor(n + 0.5))
    local sign, digits = s:match("^(%-?)(%d+)$")
    if not digits then return s end
    return sign .. digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function hub() return type(LightRpActivities) == "table" and LightRpActivities.hub or nil end
local function hubName() local H = hub(); return H and H.name or "The Crossing" end
local function hostName() local H = hub(); return H and type(H.host) == "table" and H.host.name or "the terminal host" end

local function prefix()
    local p = tostring(cfg("http.prefix", "/board"))
    if p:sub(1, 1) ~= "/" then p = "/" .. p end
    p = p:gsub("/+$", "")
    return p == "" and "/board" or p
end

-- ---------------------------------------------------------------------------
-- The view: the providers (each answers its section, or fails alone)

local function registry()
    local A = LightRP.activities
    return type(A) == "table" and type(A.registry) == "table" and A.registry or nil
end

local NO_TURF = { state = "none", headline = "NO TURF WAR SCHEDULED" }
local NO_BOSS = { state = "none", headline = "NO WORLD BOSS SCHEDULED" }

-- op77_turf's status line (server/war.lua warStatus): no fixed schedule, a war starts
-- when the queue fills, or at the time the staff scheduled it.
function EB.readTurf(t)
    local reg = registry()
    local a = reg and reg["turf.war"]
    if type(a) ~= "table" or type(a.status) ~= "table" then return NO_TURF end
    local s = a.status
    local detail = type(s.detail) == "string" and s.detail or ""
    local out = { players = int(s.players), queued = int(s.queued) }
    if s.phase == "running" or s.phase == "lobby" then
        local parts = split(detail, SEP)
        local kind
        if #parts > 1 and parts[1]:find("match", 1, true) then kind = table.remove(parts, 1) end
        if #parts > 1 then
            out.where = clip(parts[1], 40)
            out.line = clip((kind and (kind .. SEP) or "") .. table.concat(parts, SEP, 2), 90)
        else
            out.line = clip(detail, 90)
        end
        if s.phase == "lobby" then
            out.state, out.headline = "forming", "FORMING"
        elseif detail:find("war over", 1, true) then
            out.state, out.headline, out.line = "over", "WAR OVER", nil
        else
            out.state, out.headline = "live", "LIVE NOW"
        end
        return out
    end
    local site, minutes = detail:match("^Scheduled: (.-) in ~?(%d+) min")
    if site then
        return { state = "scheduled", headline = "IN {t}", due = "STARTING", approx = true, where = clip(site, 40),
            atMs = t + tonumber(minutes) * 60000 }
    end
    return { state = "open", headline = "NO WAR SCHEDULED", line = "A war starts when enough fighters queue." }
end

local function onlineCount()
    if type(GetPlayers) ~= "function" then return 0 end
    local n = 0
    for _, raw in ipairs(GetPlayers()) do
        local id = tonumber(raw)
        if id and (not LightRP.characters or LightRP.characters.isRegistered(id)) then n = n + 1 end
    end
    return n
end

-- world_bosses.lua: the running event, or the next random one (none without a
-- published world boss mission).
function EB.readBoss(t)
    local WB, W = LightRP.worldBosses, LightRpWorldBosses
    if type(WB) ~= "table" or (type(W) == "table" and W.enabled == false) then return NO_BOSS end
    local ev = type(WB.current) == "function" and WB.current() or nil
    if type(ev) == "table" and type(ev.def) == "table" then
        local title, boss = clip(ev.def.title, 48), clip(ev.bossLabel, 48)
        local line = boss and title and boss ~= title and (boss .. SEP .. title) or boss or title
        if ev.phase == "fight" then
            return { state = "live", headline = "LIVE NOW", where = clip(ev.location, 40), line = line,
                health = math.max(0, math.min(1, num(ev.bossFraction, 1))), fighters = int(ev.fighters),
                endsAtMs = num(ev.endsAt, nil) }
        end
        return { state = "over", headline = ev.success and "BOSS DOWN" or "GOT AWAY", where = clip(ev.location, 40), line = line }
    end
    local list = type(WB.catalogue) == "function" and WB.catalogue() or {}
    local at = type(WB.nextAt) == "function" and num(WB.nextAt(), nil) or nil
    if #list == 0 or not at then return NO_BOSS end
    local need = type(W) == "table" and type(W.schedule) == "table" and int(W.schedule.minPlayers) or 1
    return { state = "scheduled", headline = "IN {t}", due = "ANY MOMENT", atMs = math.max(at, t),
        line = onlineCount() < need and string.format("Needs %d players in the city", need) or "Location revealed when it spawns" }
end

local STATE = { running = "live", lobby = "forming", idle = "open" }
local RANK = { live = 1, forming = 2, open = 3 }

function EB.readActivities()
    local reg = registry()
    if not reg then return {} end
    local list = {}
    for id, a in pairs(reg) do
        if type(a) == "table" then
            local s = type(a.status) == "table" and a.status or {}
            local state = STATE[s.phase] or "open"
            list[#list + 1] = { id = tostring(id), label = clip(a.label, 40) or tostring(id), kind = a.kind, state = state,
                players = int(s.players), queued = int(s.queued), line = state ~= "open" and clip(s.detail, 80) or nil }
        end
    end
    table.sort(list, function(x, y)
        if RANK[x.state] ~= RANK[y.state] then return RANK[x.state] < RANK[y.state] end
        if x.label ~= y.label then return x.label < y.label end
        return x.id < y.id
    end)
    local max = math.max(1, int(cfg("activities.max", 7)))
    while #list > max do table.remove(list) end
    return list
end

local function color(value) return type(value) == "string" and value:match("^#%x%x%x%x%x%x$") and value or nil end

-- "12 kills", "1 kill": a count and its plural unit, singular for exactly one.
function EB.counted(n, unit)
    unit = tostring(unit or "")
    if n == 1 and unit:sub(-1) == "s" then unit = unit:sub(1, -2) end
    return unit == "" and thousands(n) or (thousands(n) .. " " .. unit)
end

-- op77_turf's weekly influence (synchronous export, memory only); nil when it does not answer.
function EB.turfInfluence(size)
    local ok, list = pcall(function() return exports.op77_turf:influence(size) end)
    if not ok or type(list) ~= "table" then return nil end
    local rows = {}
    for i, r in ipairs(list) do
        if i > size then break end
        if type(r) == "table" and int(r.points) > 0 then
            rows[#rows + 1] = { rank = #rows + 1, name = clip(r.label or r.gang, 32) or "?", value = EB.counted(int(r.points), "pts"),
                color = color(r.color) }
        end
    end
    return rows
end

function EB.dogtownWeek(size)
    local D, cfgD = LightRP.dogtown, LightRpDogtown
    if type(D) ~= "table" or type(D.board) ~= "function" or (type(cfgD) == "table" and cfgD.enabled == false) then return nil end
    local board = D.board()
    if type(board) ~= "table" then return nil end
    local rows = {}
    -- a board from a week gone by is no board this week
    if type(D.weekIndex) ~= "function" or board.week == D.weekIndex() then
        for _, r in ipairs(board.rows or {}) do
            if #rows >= size then break end
            if type(r) == "table" and int(r.kills) > 0 then
                rows[#rows + 1] = { rank = int(r.rank) > 0 and int(r.rank) or #rows + 1, name = clip(r.name, 32) or "?",
                    value = EB.counted(int(r.kills), "kills") }
            end
        end
    end
    return rows
end

function EB.readWeekly()
    local size = math.max(1, math.min(10, int(cfg("weekly.size", 5))))
    local out = {}
    if cfg("weekly.turf", true) ~= false then
        local rows = EB.turfInfluence(size)
        if rows then out[#out + 1] = { key = "turf", title = "TURF INFLUENCE", subtitle = "Gangs this week", rows = rows,
            empty = "No turf war fought this week." } end
    end
    if cfg("weekly.dogtown", true) ~= false then
        local rows = EB.dogtownWeek(size)
        if rows then out[#out + 1] = { key = "dogtown", title = "DOGTOWN KILLS", subtitle = "This week", rows = rows,
            empty = "No kills in Dogtown this week." } end
    end
    return out
end

-- A Hall of Fame value as the board shows it.
function EB.display(value, unit)
    local n = num(value, 0)
    if unit == "time" then
        local tenths = math.floor(n / 100 + 0.5)
        return string.format("%d:%02d.%d", tenths // 600, (tenths // 10) % 60, tenths % 10)
    elseif unit == "eddies" then
        if LightRP.money and type(LightRP.money.format) == "function" then return LightRP.money.format(n) end
        return "\u{20AC}$" .. thousands(n)
    elseif unit == "count" then
        return thousands(n)
    end
    return EB.counted(n, unit == "points" and "pts" or tostring(unit or ""))
end

function EB.readRecords()
    local H = LightRP.hallOfFame
    if type(H) ~= "table" or type(H.cache) ~= "function" then return {} end
    local cache = H.cache()
    local boards = type(cache) == "table" and cache.boards or nil
    if type(boards) ~= "table" then return {} end
    local size = math.max(1, math.min(5, int(cfg("records.size", 3))))
    local out = {}
    for _, key in ipairs(cfg("records.boards", {})) do
        local entry = boards[key]
        if type(entry) == "table" and type(entry.def) == "table" and type(entry.rows) == "table" then
            local rows = {}
            for i = 1, math.min(size, #entry.rows) do
                local r = entry.rows[i]
                rows[i] = { rank = int(r.rank), name = clip(r.name, 32) or "?", value = EB.display(r.value, entry.def.unit) }
            end
            local meta = type(entry.meta) == "table" and entry.meta or {}
            out[#out + 1] = { key = key, title = clip(meta.title or entry.def.title, 32) or key, subtitle = "All time", rows = rows,
                empty = "Nobody on this board yet." }
        end
    end
    return out
end

EB.providers = { turf = EB.readTurf, boss = EB.readBoss, activities = EB.readActivities, weekly = EB.readWeekly, records = EB.readRecords }

-- ---------------------------------------------------------------------------
-- The cache

local cache = { view = nil, at = nil, failed = {}, pending = false }
EB.cacheState = cache

function EB.build(reason)
    local t = now()
    local function section(name, fallback)
        local fn = EB.providers[name]
        local ok, value = false, "no provider"
        if type(fn) == "function" then ok, value = pcall(fn, t) end
        if ok and value ~= nil then cache.failed[name] = nil; return value end
        if not cache.failed[name] then
            cache.failed[name] = true
            log("events board: the %s section failed (%s): shown empty", name, tostring(value))
        end
        return fallback
    end
    local join = tostring(cfg("join", "Join with {host} here, or F1 > Activities")):gsub("{host}", function() return hostName() end)
    cache.view = {
        v = 1, title = clip(cfg("title", "WHAT'S ON"), 40), hub = clip(hubName(), 40), join = clip(join, 80),
        pollMs = math.max(2000, int(cfg("pollMs", 10000))), rotateMs = math.max(3000, int(cfg("rotateMs", 5000))),
        builtAt = t,
        turf = section("turf", NO_TURF), boss = section("boss", NO_BOSS),
        activities = section("activities", {}), weekly = section("weekly", {}), records = section("records", {}),
    }
    cache.at = t
    cache.reason = reason
    return cache.view
end

function EB.view()
    if not cache.view or now() - cache.at >= math.max(1000, int(cfg("refreshMs", 20000))) then EB.build("stale") end
    return cache.view
end

-- What view.json answers: the cached view and the server's clock now (the page counts
-- down from it).
function EB.payload()
    local out = {}
    for k, v in pairs(EB.view()) do out[k] = v end
    out.now = now()
    return out
end

-- An activity's status moved: a rebuild soon, never closer than minRebuildMs to the last.
function EB.poke()
    if cache.pending then return end
    cache.pending = true
    CreateThread(function()
        local gap = math.max(0, int(cfg("minRebuildMs", 3000)) - (now() - (cache.at or 0)))
        Wait(math.max(500, gap))
        cache.pending = false
        EB.build("status")
    end)
end

-- ---------------------------------------------------------------------------
-- HTTP: the page and its data

local http = { route = nil, reason = nil }
EB.http = http
local pageCache = nil

function EB.page()
    if pageCache then return pageCache end
    local P = LightRpEventsBoardPage
    if type(P) ~= "table" or type(P.render) ~= "function" then return nil end
    pageCache = P.render({ title = cfg("title", "WHAT'S ON"), hub = hubName(), pollMs = int(cfg("pollMs", 10000)),
        rotateMs = int(cfg("rotateMs", 5000)) })
    return pageCache
end

local function headers(contentType)
    return { ["Content-Type"] = contentType, ["Referrer-Policy"] = "no-referrer" }
end

function EB.handle(req, res)
    local method = tostring(req and req.method or "GET"):upper()
    if method ~= "GET" and method ~= "HEAD" then
        local h = headers(JSON_TYPE); h.Allow = "GET, HEAD"
        return res.send(405, '{"error":"method_not_allowed"}', h)
    end
    local path, base = tostring(req.path or ""), prefix()
    local rest = path:sub(1, #base) == base and path:sub(#base + 1) or nil
    local body, h
    if rest == "" or rest == "/" or rest == "/index.html" then
        body = EB.page()
        if not body then return res.send(503, '{"error":"page_unavailable"}', headers(JSON_TYPE)) end
        h = headers("text/html; charset=utf-8")
        h["Content-Security-Policy"] = PAGE_CSP
    elseif rest == "/view.json" then
        local ok, encoded = pcall(json.encode, EB.payload())
        if not ok or type(encoded) ~= "string" then
            log("events board: view.json not encoded (%s)", tostring(encoded))
            return res.send(500, '{"error":"encode_failed"}', headers(JSON_TYPE))
        end
        body, h = encoded, headers(JSON_TYPE)
    else
        return res.send(404, '{"error":"not_found"}', headers(JSON_TYPE))
    end
    return res.send(200, method == "HEAD" and "" or body, h)
end

-- The address the TV loads: the config's url, else the listener's own route.
function EB.url()
    local url = C.url
    if type(url) == "string" and url ~= "" then
        if url:match("^https?://[^%s/@]+") and not url:find("%s") then return url end
        if not http.badUrl then http.badUrl = true; log("events board: config url %q is not an http(s) address: using the listener's", url) end
    end
    local origin = tostring(cfg("http.listenOrigin", "http://127.0.0.1:11781")):gsub("/+$", "")
    return origin .. (http.route or ("/" .. SELF .. prefix())) .. "/"
end

function EB.listen()
    local H = type(Open77) == "table" and Open77.http or nil
    if type(H) ~= "table" or type(H.listen) ~= "function" then
        http.route, http.reason = nil, "Open77.http unavailable"
    else
        local ok, route, why = pcall(H.listen, prefix(), EB.handle)
        if ok and type(route) == "string" then http.route, http.reason = route, nil
        else http.route, http.reason = nil, tostring(ok and why or route) end
    end
    if http.route then
        log("events board: serving %s (the TV loads %s)", http.route, EB.url())
    else
        log("events board: no HTTP route (%s): the TV stays dark; turn httpHandlers on in the server config", http.reason)
    end
    return http.route ~= nil
end

-- ---------------------------------------------------------------------------
-- The TV: the screen record, where it stands, the prop

local tv = { prop = nil, position = nil, heading = nil, source = nil }
EB.tv = tv

local function vector(v, s)
    if type(v) ~= "table" then return nil end
    local x, y, z = num(v.x or v[1], nil), num(v.y or v[2], nil), num(v.z or v[3], nil)
    if not (x and y and z) then return nil end
    s = s or 1
    return { x = x * s, y = y * s, z = z * s }
end

-- The record in use, its model, and the picture's rectangle at the TV's scale (named
-- vectors: the shape Open77.media.bind reads).
function EB.screen()
    local screens = type(C.screens) == "table" and C.screens or {}
    local name = tostring(cfg("tv.screen", "tv.16x9"))
    local rec = screens[name]
    if type(rec) ~= "table" then
        name, rec = "tv.16x9", screens["tv.16x9"]
        if type(rec) ~= "table" then name, rec = next(screens) end
    end
    if type(rec) ~= "table" or type(rec.quad) ~= "table" then return nil end
    local s = math.max(0.1, math.min(40, num(cfg("tv.scale", 1), 1)))
    local q = rec.quad
    return { name = name, model = rec.model, scale = s, quad = { offset = vector(q.offset, s), right = vector(q.right), up = vector(q.up),
        width = num(q.width, 1) * s, height = num(q.height, 1) * s, faces = vector(q.faces) } }
end

-- The page's pixels, at the rectangle's own aspect (1280 on the long side).
function EB.surfaceSize(quad)
    local w, h = num(quad and quad.width, 0), num(quad and quad.height, 0)
    if not (w > 0 and h > 0) then return 1280, 720 end
    local aspect = w / h
    local short = math.floor(1280 / (aspect > 1 and aspect or 1 / aspect) + 0.5)
    short = math.max(240, short - short % 2)
    if aspect >= 1 then return 1280, short end
    return short, 1280
end

local function kvp(fn, ...)
    local K = type(Open77) == "table" and Open77.kvp or nil
    if type(K) ~= "table" or type(K[fn]) ~= "function" then return false, "kvp_unavailable" end
    local ok, a, b = pcall(K[fn], ...)
    if not ok then return false, tostring(a) end
    return a, b
end

function EB.parsePlacement(text)
    if type(text) ~= "string" then return nil end
    local x, y, z, h = text:match("^(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)$")
    x, y, z, h = tonumber(x), tonumber(y), tonumber(z), tonumber(h)
    if not (x and y and z and h) then return nil end
    return { x = x, y = y, z = z }, h % 360
end

-- The staff's spot (kvp), else the config's position, else the offset along The
-- Crossing's heading. Heading: degrees about +Z, counter-clockwise, 0 facing +Y; the
-- screen faces it. -> position, heading, source
function EB.placement()
    local savedPos, savedHeading = EB.parsePlacement((kvp("get", KVP_PLACEMENT)))
    if savedPos then return savedPos, savedHeading, "staff placement (kvp)" end
    local T = type(C.tv) == "table" and C.tv or {}
    local H = hub() or { center = { x = 0, y = 0, z = 0 }, heading = 0 }
    local pos, source
    if type(T.position) == "table" then
        pos = { x = num(T.position.x, 0), y = num(T.position.y, 0), z = num(T.position.z, 0) }
        source = "config position"
    else
        local o = type(T.offset) == "table" and T.offset or {}
        local h = math.rad(num(H.heading, 0))
        local forward, right = num(o.forward, 0), num(o.right, 0)
        pos = { x = H.center.x - math.sin(h) * forward + math.cos(h) * right,
            y = H.center.y + math.cos(h) * forward + math.sin(h) * right, z = H.center.z + num(o.up, 0) }
        source = "offset from " .. hubName()
    end
    local heading = num(T.heading, nil)
    if heading == nil then
        local dx, dy = H.center.x - pos.x, H.center.y - pos.y
        heading = (dx * dx + dy * dy < 0.01) and num(H.heading, 0) or math.deg(math.atan(-dx, dy))
    end
    return pos, heading % 360, source
end

local function props()
    local P = type(Open77) == "table" and Open77.props or nil
    if type(P) == "table" and type(P.create) == "function" then return P end
end

-- A hot reload may leave the previous generation's TV where the new one goes.
local function sweepOrphans(model)
    local P = props()
    if not P or type(P.all) ~= "function" or not tv.position then return end
    local ok, list = pcall(P.all, int(cfg("tv.bucket", 0)))
    if not ok or type(list) ~= "table" then return end
    for _, s in ipairs(list) do
        local p = type(s) == "table" and (type(s.position) == "table" and s.position or s) or nil
        if p and s.resource == SELF and s.model == model and tostring(s.id) ~= tv.prop and type(p.x) == "number" and type(p.y) == "number"
            and (p.x - tv.position.x) ^ 2 + (p.y - tv.position.y) ^ 2 < 25 then
            pcall(P.remove, s.id)
        end
    end
end

-- Puts the TV where `tv` says: moved when it stands, created otherwise. -> true | false, reason
function EB.placeProp()
    local P = props()
    if not P then return false, "props_unavailable" end
    local sc = EB.screen()
    if not sc or type(sc.model) ~= "string" then return false, "no_screen_record" end
    if tv.prop and type(P.setTransform) == "function" then
        local ok, moved = pcall(P.setTransform, tv.prop, { position = tv.position, yaw = tv.heading })
        if ok and moved then return true end
        tv.prop = nil -- gone: a new one
    end
    sweepOrphans(sc.model)
    local collision = cfg("tv.collision", true) ~= false
    local ok, id, why = pcall(P.create, { model = sc.model, position = { x = tv.position.x, y = tv.position.y, z = tv.position.z },
        yaw = tv.heading, scale = sc.scale, bucket = int(cfg("tv.bucket", 0)), physics = collision and "static" or "none",
        collision = collision, streamingRadius = num(cfg("tv.streamingRadius", 150), 150) })
    if not ok then return false, tostring(id) end
    if not id then return false, tostring(why or "refused") end
    tv.prop = tostring(id)
    return true
end

-- Whether the TV still stands (true when the props layer cannot say).
function EB.standing()
    if not tv.prop then return false end
    local P = props()
    if not P or type(P.get) ~= "function" then return true end
    local ok, prop = pcall(P.get, tv.prop)
    return not ok or prop ~= nil
end

function EB.removeProp()
    local P = props()
    if tv.prop and P and type(P.remove) == "function" then pcall(P.remove, tv.prop) end
    tv.prop = nil
end

-- What the clients need to paint the page on the screen; url false: nothing to paint.
function EB.info()
    local sc = EB.screen()
    local quad = sc and sc.quad or nil
    local w, h = EB.surfaceSize(quad)
    return { prop = tv.prop or false, url = (http.route and tv.prop) and EB.url() or false,
        position = tv.position, bucket = int(cfg("tv.bucket", 0)), quad = quad, width = w, height = h,
        fps = math.max(1, math.min(30, int(cfg("tv.fps", 15)))), label = clip(cfg("tv.label", "Events board"), 120),
        drawRadius = num(cfg("tv.drawRadius", 60), 60), drawHysteresis = num(cfg("tv.drawHysteresis", 15), 15) }
end

function EB.sendTv(target)
    if type(TriggerClientEvent) ~= "function" then return end
    TriggerClientEvent(E.net.eventsBoardTv, target or -1, EB.info())
end

local helloAt = {}
RegisterNetEvent(E.net.eventsBoardHello, function()
    local id = tonumber(source)
    if id == nil or id <= 0 then return end
    local t = now()
    if helloAt[id] and t - helloAt[id] < 1000 then return end
    helloAt[id] = t
    EB.sendTv(id)
end)
function EB.onDisconnected(playerId) helloAt[playerId] = nil end

-- One spawn attempt (the start thread retries). -> true | false, reason
local propsWarned = false
function EB.spawn()
    local ok, why = EB.placeProp()
    if ok then
        log("events board: TV %s at %.1f, %.1f facing %.0f (prop %s, %s)", tostring(cfg("tv.screen", "tv.16x9")),
            tv.position.x, tv.position.y, tv.heading, tv.prop, tv.source or "")
        EB.sendTv(-1)
    elseif why == "props_unavailable" and not propsWarned then
        propsWarned = true
        log("events board: no props layer here: no TV (the page is still served)")
    end
    return ok, why
end

-- The respawn check (Johnny's pattern): a TV gone is made again.
function EB.watch()
    if not props() or not tv.position then return false end
    if tv.prop and EB.standing() then return false end
    tv.prop = nil
    local ok, why = EB.placeProp()
    if ok then
        log("events board: TV gone, made again (prop %s)", tv.prop)
        EB.sendTv(-1)
    end
    return ok, why
end

-- ---------------------------------------------------------------------------
-- Staff: /lightrp.board [where | place | reset | respawn | refresh]

local function placementLine(pos, heading)
    return string.format("position = { x = %.3f, y = %.3f, z = %.3f }, heading = %.1f, -- server/config/events_board.lua tv, bucket %d",
        pos.x, pos.y, pos.z, heading, int(cfg("tv.bucket", 0)))
end
EB.placementLine = placementLine

local function pageLine()
    if http.route then return "page " .. EB.url() end
    return "page off (" .. tostring(http.reason) .. ")"
end

local function moveTo(pos, heading, source)
    tv.position, tv.heading, tv.source = pos, heading % 360, source
    local ok, why = EB.placeProp()
    EB.sendTv(-1)
    return ok, why
end

LightRP.command("lightrp.board", { restricted = true, usage = "/lightrp.board [where | place | reset | respawn | refresh]" }, function(source, args)
    local verb = tostring(args and args[1] or "where"):lower()
    if verb == "where" then
        if not tv.position then return false, "The events board is not placed yet." end
        return true, string.format("%s · %s · prop %s · %s", placementLine(tv.position, tv.heading), tv.source or "?",
            tostring(tv.prop or "none"), pageLine())
    elseif verb == "refresh" then
        EB.build("staff")
        return true, "Events board: data rebuilt."
    elseif verb == "respawn" then
        if not tv.position then return false, "The events board is not placed yet." end
        EB.removeProp()
        local ok, why = moveTo(tv.position, tv.heading, tv.source)
        if not ok then return false, "Events board: the TV was not made (" .. tostring(why) .. ")." end
        return true, "Events board: TV made again, prop " .. tostring(tv.prop) .. "."
    elseif verb == "reset" then
        kvp("delete", KVP_PLACEMENT)
        local pos, heading, src = EB.placement()
        local ok, why = moveTo(pos, heading, src)
        local line = placementLine(tv.position, tv.heading)
        LightRP.log("events board: placement reset to the config: %s", line)
        return true, "Back to the config: " .. line .. (ok and "" or (" (the TV failed: " .. tostring(why) .. ")"))
    elseif verb == "place" then
        if not source or source <= 0 then return false, "In game only: stand at the spot, facing where the screen should face." end
        local read = type(Open77.players.get) == "function" and Open77.players.get(source) or nil
        local p = type(read) == "table" and read.position or Open77.players.position(source)
        if type(p) ~= "table" or type(p.x) ~= "number" then return false, "Your position is not available yet." end
        local bucket = type(GetPlayerRoutingBucket) == "function" and GetPlayerRoutingBucket(source) or (read and read.bucket) or p.bucket or 0
        if (tonumber(bucket) or 0) ~= int(cfg("tv.bucket", 0)) then
            return false, string.format("Stand in the city (routing bucket %d).", int(cfg("tv.bucket", 0)))
        end
        local heading = (type(read) == "table" and tonumber(read.heading or read.yaw)) or 0
        -- the TV goes behind the staff; its screen faces where they look
        local h, back = math.rad(heading), num(cfg("tv.staffSetback", 1.5), 1.5)
        local pos = { x = p.x + math.sin(h) * back, y = p.y - math.cos(h) * back, z = p.z }
        local saved, why = kvp("set", KVP_PLACEMENT, string.format("%.3f,%.3f,%.3f,%.1f", pos.x, pos.y, pos.z, heading % 360))
        local ok, propWhy = moveTo(pos, heading, saved == true and "staff placement (kvp)" or "staff placement (this session)")
        local line = placementLine(tv.position, tv.heading)
        LightRP.log("events board: placed by %s: %s", LightRP.characters and LightRP.characters.displayName(source) or tostring(source), line)
        return true, line .. (saved == true and "  (kept until /lightrp.board reset; paste into the config to make it the default)"
            or ("  (this session only, not saved: " .. tostring(why) .. ")"))
            .. (ok and "" or (" (the TV failed: " .. tostring(propWhy) .. ")"))
    end
    return false
end)

-- ---------------------------------------------------------------------------
-- Start: the route now, the TV once the world takes it, the cache timer, the
-- status hook, the respawn check.

do
    local pos, heading, src = EB.placement()
    tv.position, tv.heading, tv.source = pos, heading, src
end
EB.listen()

CreateThread(function()
    local retries = math.max(1, int(cfg("tv.spawnRetries", 30)))
    for attempt = 1, retries do
        local ok, why = EB.spawn()
        if ok or why == "props_unavailable" then break end
        if attempt == 1 then log("events board: TV not made yet (%s): retrying", tostring(why)) end
        if attempt == retries then log("events board: TV gave up after %d tries (%s)", retries, tostring(why)) break end
        Wait(math.max(1000, int(cfg("tv.spawnRetryMs", 10000))))
    end
    while true do
        Wait(math.max(5000, int(cfg("tv.respawnMs", 60000))))
        local ok, err = pcall(EB.watch)
        if not ok then log("events board: respawn check failed: %s", tostring(err)) end
    end
end)

CreateThread(function()
    Wait(2000)
    while true do
        local ok, err = pcall(EB.build, "timer")
        if not ok then log("events board: rebuild failed: %s", tostring(err)) end
        Wait(math.max(1000, int(cfg("refreshMs", 20000))))
    end
end)

do
    local A = LightRP.activities
    local statusEvent = type(A) == "table" and type(A.events) == "table" and A.events.status or nil
    if statusEvent and type(AddEventHandler) == "function" then
        AddEventHandler(statusEvent, function() EB.poke() end)
    end
end
