-- The Hall of Fame (server/modules/halloffame.lua): the board beside the activities
-- terminal, the boards aggregated from the stored stats, competition ranking and its
-- ties, race times lowest first on the current course, the wealth switch, the cache
-- and its rate limits, the payload under the plain-event limit, the staff command,
-- the session rows without a database, and no account identifier in any payload.
-- Exclusions: staff accounts (online through the ACL, remembered offline, configured,
-- revoked) and test characters (config + the command's kvp list) on no board.
dofile("shared/events.lua")
dofile("shared/config.lua")
dofile("server/config/activities.lua")
dofile("server/config/halloffame.lua")
local C = LightRpHallOfFame
-- The live config: the owner's survey (2026-11-03), the Arasaka sculpture at scale 3.
assert(C.board.model == "decor.sculpture.arasaka" and C.board.scale == 4.5 and C.board.heading == 232.6
    and math.abs(C.board.position.x - (-773.499)) < 1e-3 and math.abs(C.board.position.y - 799.148) < 1e-3, "the surveyed board")
do local found for _, row in ipairs(C.board.models) do if row.model == C.board.model then found = row end end
    assert(found and found.collision ~= false and found.height and found.width and found.depth,
        "the default is a listed candidate with a collider, a height and a footprint") end
do -- at the live scale the E prompt reaches all around the plinth, the icon stays in view
    local w = 0.57 * math.sqrt(2) / 2 * 4.5 + 1.4
    assert(w > 3.2 and w < 3.3, "sculpture x4.5: half diagonal 1.81 + reach 1.4")
end
-- Below, the offset path and the first candidate as the default (the arithmetic these
-- assertions pin), whatever the live survey says.
C.board.position, C.board.heading, C.board.model, C.board.scale = nil, nil, C.board.models[1].model, nil

local noop = function() end
local clock = 1000000
local interactions, dialogs, results, commands, actions, clientEvents, netHandlers, logs = {}, {}, {}, {}, {}, {}, {}, {}
local queries = {}
local db = { ready = true }
LightRP = {
    module = function(name, value) value.name = name; LightRP[name] = value; return value end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    result = function(id, ok, text, kind) results[#results + 1] = { id = id, ok = ok, text = text, kind = kind } end,
    log = function(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end,
    dialog = function(id, kind, payload) payload.kind = kind; dialogs[#dialogs + 1] = { id = id, kind = kind, payload = payload } end,
    interaction = function(id, def) interactions[id] = def end,
    batchInteractions = function(fn) return fn() end,
    nowMs = function() return clock end,
    eachModule = noop, state = noop, notice = noop,
}
LightRpMissions = { reputation = { tiers = { 0, 500, 1500 } } }

-- ---------------------------------------------------------------------------
-- The data: characters, activity totals and course times, missions, wallets

local chars = {
    { id = "license:aaa111", key = "default", first = "Jax", last = "Rook" },   -- player 1 (the viewer)
    { id = "license:bbb222", key = "default", first = "Mira", last = "Sol" },
    { id = "license:ccc333", key = "second", first = "Tomas", last = "Kade" },
    { id = "license:ddd444", key = "default", first = "Nyx", last = "Vale" },
    { id = "license:eee555", key = "default", first = "", last = "" },          -- never named: off the boards
}
local totals = {
    { "license:aaa111", "default", "arena.ffa", wins = 3, played = 5, kills = 10, deaths = 4 },
    { "license:aaa111", "default", "race.grid", wins = 1, played = 2, kills = 0, deaths = 0 },
    { "license:bbb222", "default", "arena.duel", wins = 4, played = 6, kills = 3, deaths = 3 },
    { "license:ccc333", "second", "arena.teams", wins = 4, played = 7, kills = 10, deaths = 2 },
    { "license:ddd444", "default", "arena.pve", wins = 5, played = 5, kills = 30, deaths = 1 },  -- PvE only
    { "license:eee555", "default", "arena.ffa", wins = 99, played = 99, kills = 99, deaths = 0 },
}
local times = {
    { "license:aaa111", "default", "race.trial", "watson_loop@1", 60000, 100 },   -- an older course
    { "license:bbb222", "default", "race.trial", "watson_loop@2", 65000, 200 },
    { "license:ccc333", "second", "race.trial", "watson_loop@2", 61000, 150 },
    { "license:ddd444", "default", "race.trial", "", 50000, 300 },               -- totals row: not a course
    { "license:aaa111", "default", "race.foot", "", 90000, 100 },
    { "license:bbb222", "default", "race.foot", "", 80000, 100 },
}
local reps = {
    { "license:aaa111", "default", rep = 600, completed = 3 },
    { "license:bbb222", "default", rep = 1600, completed = 10 },
    { "license:ddd444", "default", rep = 100, completed = 1 },
}
local clears = {
    { "license:aaa111", "default", "sector04_blackout", "critical", 1 },
    { "license:aaa111", "default", "sector04_blackout", "standard", 5 },
    { "license:bbb222", "default", "sector04_blackout", "hard", 4 },
    { "license:bbb222", "default", "sector04_blackout", "standard", 2 },
    { "license:ccc333", "second", "chimera_raid", "hard", 2 },
}
local wallets = {
    { "license:bbb222", "default", 2000, nil },
    { "license:aaa111", "default", 1000, "A" },
    { "license:ccc333", "second", 0, "C" },
}
local decoded = { A = { { name = "cash", count = 500 }, { name = "medkit", count = 2 } }, C = { { name = "cash", count = 50 } } }
json = { decode = function(s) if decoded[s] then return decoded[s] end error("bad json") end }

-- Twelve characters better than everyone above at everything, so every board is full
-- and the viewer's rank falls outside the top ten.
for i = 1, 12 do
    local id = string.format("license:x%02d", i)
    chars[#chars + 1] = { id = id, key = "default", first = "Extra", last = string.format("Number %02d", i) }
    totals[#totals + 1] = { id, "default", "arena.ffa", wins = 10 + i, played = 30, kills = 40 + i, deaths = 5 }
    totals[#totals + 1] = { id, "default", "turf.pve", wins = 10 + i, played = 30, kills = 40 + i, deaths = 5 }
    times[#times + 1] = { id, "default", "race.trial", "watson_loop@2", 30000 + i, 120 }
    times[#times + 1] = { id, "default", "race.grid", "", 40000 + i, 120 }
    times[#times + 1] = { id, "default", "race.foot", "", 50000 + i, 120 }
    reps[#reps + 1] = { id, "default", rep = 2000 + i, completed = 20 + i }
    clears[#clears + 1] = { id, "default", "sector04_blackout", "critical", 2 + i }
    clears[#clears + 1] = { id, "default", "chimera_raid", "critical", 2 + i }
    wallets[#wallets + 1] = { id, "default", 100000 + i, nil }
end

local failWalletJoin, failRep = false, false
local function rowsFor(sql)
    if sql:find("FROM lightrp_characters", 1, true) then
        local out = {}
        for _, c in ipairs(chars) do out[#out + 1] = { identifier = c.id, character_key = c.key, first_name = c.first, last_name = c.last } end
        return out
    elseif sql:find("board = ''", 1, true) then
        local out = {}
        for _, t in ipairs(totals) do
            out[#out + 1] = { identifier = t[1], character_key = t[2], activity_id = t[3], character_name = "acct-" .. t[1],
                played = t.played, wins = t.wins, kills = t.kills, deaths = t.deaths }
        end
        return out
    elseif sql:find("best_time_ms IS NOT NULL", 1, true) then
        local out = {}
        for _, t in ipairs(times) do
            out[#out + 1] = { identifier = t[1], character_key = t[2], activity_id = t[3], board = t[4], best_time_ms = t[5], t = t[6] }
        end
        return out
    elseif sql:find("FROM lightrp_mission_rep", 1, true) then
        if failRep then return nil end
        local out = {}
        for _, r in ipairs(reps) do out[#out + 1] = { identifier = r[1], character_key = r[2], rep = r.rep, completed = r.completed } end
        return out
    elseif sql:find("FROM lightrp_mission_clears", 1, true) then
        local out = {}
        for _, r in ipairs(clears) do out[#out + 1] = { identifier = r[1], character_key = r[2], point_id = r[3], difficulty = r[4], completed = r[5] } end
        return out
    elseif sql:find("FROM lightrp_wallets", 1, true) then
        if failWalletJoin and sql:find("JOIN", 1, true) then return nil end
        local out = {}
        local joined = sql:find("JOIN", 1, true) ~= nil
        for _, w in ipairs(wallets) do out[#out + 1] = { identifier = w[1], character_key = w[2], bank = w[3], items = joined and w[4] or nil } end
        return out
    end
    error("unexpected query: " .. sql)
end
LightRP.db = {
    schema = noop, run = noop,
    read = function(sql, params)
        assert(db.ready, "no query without a database")
        queries[#queries + 1] = sql
        local rows = rowsFor(sql)
        if rows == nil then return false, "error" end
        return true, rows
    end,
}
setmetatable(LightRP.db, { __index = function(_, k) if k == "ready" then return db.ready end end })

local online = {
    [1] = { identifier = "license:aaa111", key = "default", status = "active", firstName = "Jax", lastName = "Rook" },
    [2] = { identifier = "license:fff666", key = "default", status = "active", firstName = "Fay", lastName = "Nox" },
}
LightRP.characters = { get = function(id) return online[id] end, displayName = function(id) return "Account" .. tostring(id) end }
LightRP.activities = { registry = {
    ["arena.ffa"] = { kind = "pvp", label = "Combat Zone" }, ["arena.pve"] = { kind = "pvp", label = "Combat Zone PvE" },
    ["race.trial"] = { kind = "race", label = "Time Trial" }, ["turf.pve"] = { kind = "event", label = "Turf PvE" },
    ["future.mode"] = { kind = "pvp", label = "Future" },
} }
local points = { sector04_blackout = { id = "sector04_blackout", type = "HEIST", title = "Sector 04 Blackout" } }
LightRP.missions = { point = function(id) return points[id] end, reputation = function() return 0 end }

-- ---------------------------------------------------------------------------
-- The host: threads as coroutines (Wait yields), props, players

local threads = {}
CreateThread = function(fn)
    local co = coroutine.create(fn)
    local ok, err = coroutine.resume(co)
    assert(ok, err)
    if coroutine.status(co) ~= "dead" then threads[#threads + 1] = co end
end
Wait = function(ms) if coroutine.isyieldable() then coroutine.yield(ms) end end
local function pump()
    for i = #threads, 1, -1 do
        local ok, err = coroutine.resume(threads[i])
        assert(ok, err)
        if coroutine.status(threads[i]) == "dead" then table.remove(threads, i) end
    end
end
RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
AddEventHandler = noop
GetCurrentResourceName = function() return "op77_lightrp" end
GetPlayers = function() return { "1", "2" } end
local buckets = { 0, 0 }
GetPlayerRoutingBucket = function(id) return buckets[id] or 0 end
TriggerClientEvent = function(name, id, payload) clientEvents[#clientEvents + 1] = { name = name, id = id, payload = payload } end

local props, removed, transforms, propSeq = {}, {}, {}, 41
local refuseModels = {} -- models the props layer refuses (an alias it does not know)
local spots = { [1] = { x = 0, y = 0, z = 0 }, [2] = { x = 0, y = 0, z = 0 } }
local staffRead = { position = { x = 10, y = 20, z = 5 }, heading = 90 }
-- a board left by the previous generation (removed at start) and another resource's (kept)
local allProps = {
    { id = "7", resource = "op77_lightrp", model = C.board.model, position = { x = -763.5, y = 777.9, z = 22.4 } },
    { id = "8", resource = "open77_media", model = C.board.model, position = { x = -763.5, y = 777.9, z = 22.4 } },
}
Open77 = {
    props = {
        create = function(def)
            if refuseModels[def.model] then return nil, "unknown_model" end
            propSeq = propSeq + 1; props[tostring(propSeq)] = def; return tostring(propSeq)
        end,
        setTransform = function(id, def) if not props[id] then return false, "not_found" end; transforms[#transforms + 1] = { id = id, def = def }; return true end,
        remove = function(id) removed[#removed + 1] = id; return true end,
        all = function() return allProps end,
    },
    players = {
        position = function(id) local s = spots[id]; return s and { x = s.x, y = s.y, z = s.z, bucket = buckets[id] or 0 } end,
        get = function() return staffRead end,
    },
}
-- The resource's kvp store (data/, kept over restarts): a plain table outliving the module.
local kvpStore = {}
Open77.kvp = {
    set = function(k, v)
        assert(type(k) == "string" and k ~= "" and #k <= 256 and not k:find("%c"), "kvp key: " .. tostring(k))
        assert(type(v) == "string" and #v <= 65536, "kvp value")
        kvpStore[k] = v
        return true
    end,
    get = function(k, default) local v = kvpStore[k]; if v == nil then return default end; return v end,
    delete = function(k) local had = kvpStore[k] ~= nil; kvpStore[k] = nil; return had end,
    find = function(prefix, limit)
        assert(limit == nil or (limit >= 1 and limit <= 4096), "kvp limit")
        local keys = {}
        for k in pairs(kvpStore) do if k:sub(1, #prefix) == prefix then keys[#keys + 1] = k end end
        table.sort(keys)
        local out = {}
        for i = 1, math.min(#keys, limit or 4096) do out[i] = { key = keys[i], value = kvpStore[keys[i]], type = "string" } end
        return out
    end,
}
-- The ACL (players online only), and server/modules/staff.lua's test over it.
local aclGrants, aclBroken = {}, false
Open77.acl = { isAllowed = function(id, permission)
    if aclBroken then return false, "permission_denied:acl.read" end
    return aclGrants[id] ~= nil and aclGrants[id][permission] == true
end }
LightRP.staff = { isStaff = function(id)
    for _, permission in ipairs(LightRpConfig.staffPermissions) do
        if Open77.acl.isAllowed(id, permission) == true then return true end
    end
    return false
end }

local function countValues(value, n)
    n = (n or 0) + 1
    if type(value) ~= "table" then return n end
    for _, item in pairs(value) do n = countValues(item, n + 1) end
    return n
end
-- A rough JSON size: keys, strings and numbers (the plain event also has a byte limit).
local function jsonBytes(value)
    if type(value) == "table" then
        local n = 2
        for k, v in pairs(value) do n = n + #tostring(k) + 4 + jsonBytes(v) end
        return n
    end
    return #tostring(value) + 2
end
local function serialize(value, out)
    out = out or {}
    if type(value) == "table" then
        for k, v in pairs(value) do out[#out + 1] = tostring(k); serialize(v, out) end
    else out[#out + 1] = tostring(value) end
    return out
end
local function boardOf(payload, key) for _, b in ipairs(payload.boards) do if b.key == key then return b end end end
local function last() return dialogs[#dialogs].payload end

dofile("server/modules/halloffame.lua")
local HoF = LightRP.hallOfFame
assert(HoF and type(HoF.registerBoard) == "function", "LightRP.hallOfFame.registerBoard")

-- ---------------------------------------------------------------------------
-- The board: beside the activities terminal, facing the arrival point

local point = interactions["halloffame.board"]
local initial = { x = HoF.board.position.x, y = HoF.board.position.y, heading = HoF.board.heading }
assert(point and point.bucket == 0 and point.key == "E" and point.label == "Hall of Fame", "the E point")
assert(point.marker == nil and point.ring == false, "no floor marker nor ground ring: the icon and the E prompt")
assert(point.blip and point.blip.icon == "trophy" and point.blip.title == "Hall of Fame" and point.blip.mapCategory == "service"
    and point.blip.mapColor == "#FFCC00" and type(point.blip.description) == "string" and point.blip.description ~= "",
    "a floating trophy icon with the distance, and a map pin")
do -- the icon floats over the prop (arcade 1.87 m + 0.4), the E point right in front of it
    local ip, bp = point.blip.position, HoF.board.position
    assert(ip and ip.x == bp.x and ip.y == bp.y and math.abs(ip.z - (bp.z + 1.87 + 0.4)) < 1e-6, "the trophy just above the arcade")
    assert(point.position.x == bp.x and point.position.y == bp.y and point.radius == 2.6, "E at the object's centre, prompt within 2.6 m")
end
assert(math.abs(HoF.board.position.x - (-763.777)) < 0.01 and math.abs(HoF.board.position.y - 777.723) < 0.01,
    string.format("forward 6 / right -4 of the hub: %.3f %.3f", HoF.board.position.x, HoF.board.position.y))
assert(math.abs(HoF.board.heading - 266.3) < 0.1, "the screen faces the arrival point: " .. HoF.board.heading)
local terminal = { x = -760.553, y = 780.294 }
local apart = math.sqrt((HoF.board.position.x - terminal.x) ^ 2 + (HoF.board.position.y - terminal.y) ^ 2)
assert(apart > 3 and apart < 5, "a few metres from the activities terminal: " .. apart)
-- the E point stands at the board's centre (interact.distance 0)
assert(math.abs(point.position.x - (-763.777)) < 0.05 and math.abs(point.position.y - 777.723) < 0.05,
    string.format("E point %.2f %.2f", point.position.x, point.position.y))
local created = props[HoF.board.prop]
assert(created and created.model == C.board.model and created.model == C.board.models[1].model, "the default: the first candidate")
assert(created.collision == true and created.physics == "static", "a static board with a collider (ALT + click hits physical bodies)")
assert(math.abs(created.yaw - (HoF.board.heading + C.board.models[1].yaw) % 360) < 1e-6 and created.bucket == 0
    and created.scale == C.board.models[1].scale, "its row's scale and yaw")
assert(HoF.board.saved == false, "nothing saved yet: the config's default")
assert(#removed == 1 and removed[1] == "7", "the previous generation's board goes, another resource's stays")
local boardEvent = clientEvents[#clientEvents]
assert(boardEvent.name == LightRpEvents.net.hallOfFameBoard and boardEvent.id == -1 and boardEvent.payload.prop == HoF.board.prop,
    "every client learns which prop is the board")

-- a client that restarts asks again, at most once a second
local before = #clientEvents
source = 2
netHandlers[LightRpEvents.net.hallOfFameHello]()
netHandlers[LightRpEvents.net.hallOfFameHello]()
assert(#clientEvents == before + 1 and clientEvents[#clientEvents].id == 2)
HoF.onGameplayReady(1)
assert(clientEvents[#clientEvents].id == 1 and clientEvents[#clientEvents].payload.prop == HoF.board.prop)

-- ---------------------------------------------------------------------------
-- Opening: from the board only, then the cache

spots[1] = { x = -770, y = 760, z = 22.4 } -- 19 m away
actions["halloffame.open"](1, { type = "halloffame.open", from = "board" })
assert(#dialogs == 0 and results[#results].ok == false and results[#results].text:find("Walk up"), "too far from the board")
assert(#queries == 0, "a refused open queries nothing")

spots[1] = { x = point.position.x, y = point.position.y, z = point.position.z }
HoF.onInteract(1, "halloffame.board")
local p = last()
assert(p.kind == "halloffame" and p.tab == "overview" and p.database == true and p.hub == "The Crossing")
assert(#queries == 6, "one refresh reads six tables: " .. #queries)
local tabs = table.concat(p.tabs, ",")
assert(tabs == "overview,pvp,races,pve,missions,wealth", tabs)
assert(p.updatedAgoS == 0)

-- ---------------------------------------------------------------------------
-- PvP: summed over the PvP activities, PvE and the unnamed left out, competition ranks

local wins = HoF.cache().boards["pvp.wins"].rows
local byName = {}
for _, r in ipairs(wins) do byName[r.name] = r end
assert(byName["Mira Sol"].rank == 13 and byName["Mira Sol"].value == 4, "Mira: 4 wins in 6 played")
assert(byName["Jax Rook"].value == 4 and byName["Jax Rook"].rank == 14, "Jax: arena 3 + street race 1, 7 played")
assert(byName["Tomas Kade"].rank == 14, "Tomas ties Jax exactly (4 wins, 7 played): the same rank")
assert(wins[13].name == "Mira Sol" and wins[14].name == "Jax Rook" and wins[15].name == "Tomas Kade", "a tie reads by name")
assert(byName["Nyx Vale"] == nil, "a PvE win is not a PvP win")
for _, r in ipairs(wins) do assert(r.name ~= "" and not r.name:find("acct-", 1, true), "never the stored account-side name") end
assert(#wins == 15, "the unnamed character is off the boards: " .. #wins)
local kills = HoF.cache().boards["pvp.kills"].rows
local kRank = {}
for _, r in ipairs(kills) do kRank[r.name] = r.rank end
assert(kRank["Tomas Kade"] < kRank["Jax Rook"], "same kills: fewer deaths first")

actions["halloffame.tab"](1, { type = "halloffame.tab", tab = "pvp" })
p = last()
local pw = boardOf(p, "pvp.wins")
assert(p.tab == "pvp" and #pw.rows == 10 and pw.total == 15 and pw.unit == "wins")
assert(pw.rows[1].name == "Extra Number 12" and pw.rows[1].rank == 1 and pw.rows[1].value == 22)
assert(pw.mine and pw.mine.rank == 14 and pw.mine.value == 4, "the viewer's rank outside the top ten")
for _, r in ipairs(pw.rows) do assert(r.you == nil, "the viewer is not in the top ten") end
assert(#queries == 6, "a tab change reads the cache")

-- ---------------------------------------------------------------------------
-- Races: the current course, lowest time first

actions["halloffame.tab"](1, { type = "halloffame.tab", tab = "races" })
p = last()
local trial = boardOf(p, "races.race.trial")
assert(trial and trial.ascending == true and trial.unit == "time", "a race board ranks lowest first")
assert(trial.subtitle == "Best time · WATSON LOOP · REV 2", tostring(trial.subtitle))
assert(trial.rows[1].value == 30001 and trial.rows[1].name == "Extra Number 01", "fastest first")
local trialAll = HoF.cache().boards["races.race.trial"].rows
assert(#trialAll == 14 and trialAll[13].name == "Tomas Kade" and trialAll[14].name == "Mira Sol", "61.0 s before 65.0 s")
for _, r in ipairs(trialAll) do assert(r.name ~= "Jax Rook" and r.name ~= "Nyx Vale", "an older course and a totals row stay out") end
local foot = boardOf(p, "races.race.foot")
assert(foot.subtitle == "Best time · All courses" and HoF.cache().boards["races.race.foot"].byKey["license:aaa111#default"])
assert(foot.mine and foot.mine.rank == 14 and foot.mine.value == 90000)
assert(HoF.courseLabel("watson_loop@0") == "WATSON LOOP")

-- ---------------------------------------------------------------------------
-- PvE and missions

actions["halloffame.tab"](1, { type = "halloffame.tab", tab = "pve" })
p = last()
local pveWins = HoF.cache().boards["pve.wins"].rows
local pveNames = {}
for _, r in ipairs(pveWins) do pveNames[r.name] = r end
assert(pveNames["Nyx Vale"] and pveNames["Nyx Vale"].value == 5 and pveNames["Jax Rook"] == nil, "arena.pve and turf.pve count as PvE")
local rep = boardOf(p, "pve.rep")
assert(rep.rows[1].value == 2012 and rep.rows[1].detail == "TIER 3", tostring(rep.rows[1].detail))
assert(rep.mine.value == 600 and rep.mine.detail == "TIER 2")
assert(HoF.tierOf(0) == "TIER 1" and HoF.tierOf(1499) == "TIER 2")

actions["halloffame.tab"](1, { type = "halloffame.tab", tab = "missions" })
p = last()
local heists = HoF.cache().boards["missions.heists"].rows
local h = {}
for _, r in ipairs(heists) do h[r.name] = r end
assert(h["Jax Rook"].value == 6 and h["Mira Sol"].value == 6 and h["Jax Rook"].rank < h["Mira Sol"].rank,
    "one critical clear outranks hard ones at the same total")
assert(h["Jax Rook"].detail == "CRIT 1 · STD 5" and h["Mira Sol"].detail == "HARD 4 · STD 2", h["Jax Rook"].detail)
assert(h["Tomas Kade"] == nil, "a raid is not a heist")
local raids = HoF.cache().boards["missions.raids"].rows
local tomas
for _, r in ipairs(raids) do if r.name == "Tomas Kade" then tomas = r end end
assert(tomas and tomas.detail == "HARD 2", "chimera_raid keeps its type when its point is gone (config knownTypes)")
assert(boardOf(p, "missions.completed").mine.value == 3)

-- ---------------------------------------------------------------------------
-- Wealth: bank + the cash item, behind its switch

actions["halloffame.tab"](1, { type = "halloffame.tab", tab = "wealth" })
p = last()
local rich = HoF.cache().boards["wealth.richest"]
local jax = rich.rows[rich.byKey["license:aaa111#default"]]
assert(jax.value == 1500 and jax.detail == nil, "bank 1000 + cash 500; no split by default")
assert(boardOf(p, "wealth.richest").mine.value == 1500 and p.wealthBankOnly == nil)
assert(rich.rows[rich.byKey["license:ccc333#second"]].value == 50, "cash only")

C.showWealthSplit = true
clock = clock + 11000
HoF.refresh("test")
rich = HoF.cache().boards["wealth.richest"]
assert(rich.rows[rich.byKey["license:aaa111#default"]].detail == "bank 1000 · cash 500")
C.showWealthSplit = false

failWalletJoin = true
clock = clock + 11000
HoF.refresh("test")
rich = HoF.cache().boards["wealth.richest"]
assert(rich.rows[rich.byKey["license:aaa111#default"]].value == 1000, "the join failed: the bank alone")
assert(HoF.payload(1, "wealth").wealthBankOnly == true, "and the panel says so")
failWalletJoin = false

C.showWealth = false
clock = clock + 11000
local mark = #queries
HoF.refresh("test")
for i = mark + 1, #queries do assert(not queries[i]:find("lightrp_wallets", 1, true), "wealth off: no wallet query") end
assert(HoF.cache().boards["wealth.richest"] == nil)
p = HoF.payload(1, "wealth")
assert(p.tab == "overview" and not table.concat(p.tabs, ","):find("wealth"), "wealth off: no tab")
for _, b in ipairs(p.boards) do assert(b.key ~= "wealth.richest", "nor an overview podium") end
C.showWealth = true
clock = clock + 11000
HoF.refresh("test")

-- ---------------------------------------------------------------------------
-- The cache and its rate limits

mark = #queries
HoF.open(1, "pvp"); HoF.open(1, "overview"); HoF.open(2, "pvp")
assert(#queries == mark, "opening reads the cache")
assert(last().updatedAgoS == 0)
clock = clock + 2000
assert(HoF.requestRefresh(1, "pvp") == false and #queries == mark, "the server floor: 10 s between refreshes")
assert(last().tab == "pvp", "a refused refresh still answers the panel")
clock = clock + 9000
assert(HoF.requestRefresh(1, "pvp") == true and #queries == mark + 6, "REFRESH rebuilds")
clock = clock + 5000
assert(HoF.requestRefresh(1, "pvp") == false and last().refreshInS == 25, "30 s per player: " .. tostring(last().refreshInS))
assert(HoF.requestRefresh(2, "pvp") == false, "another player within the floor")
clock = clock + 6000
assert(HoF.requestRefresh(2, "pvp") == true and #queries == mark + 12, "another player after the floor")
clock = clock + 20000
assert(HoF.requestRefresh(1, "pvp") == true and #queries == mark + 18, "the player again after 30 s")
actions["halloffame.refresh"](2, { type = "halloffame.refresh", tab = "pvp" })
assert(#queries == mark + 18, "the page action goes through the same limits")
assert(last().updatedAgoS == 0)
clock = clock + 60000
HoF.open(1, "overview")
assert(#queries == mark + 18 and last().updatedAgoS == 60, "a minute later: still the cache")
clock = clock + C.cache.refreshMs
HoF.open(1, "overview")
assert(#queries == mark + 24, "stale after five minutes: the next open rebuilds first")

-- the five-minute timer (a coroutine waiting on its first delay)
mark = #queries
pump()
assert(#queries == mark, "the timer skips a fresh cache")
clock = clock + C.cache.refreshMs
pump()
assert(#queries == mark + 6, "and rebuilds a stale one")

-- a table that did not answer (not created yet at start): read again 30 s later, not 5 min
failRep = true
clock = clock + 11000
HoF.refresh("test")
assert(HoF.cache().retryAt and #HoF.cache().boards["pve.rep"].rows == 0, "the missing table leaves its boards empty for now")
failRep = false
mark = #queries
clock = clock + 20000
HoF.open(1, "pve")
assert(#queries == mark, "not before the retry delay")
clock = clock + 11000
HoF.open(1, "pve")
assert(#queries == mark + 6 and #HoF.cache().boards["pve.rep"].rows > 0 and not HoF.cache().retryAt, "read again after 30 s")

-- ---------------------------------------------------------------------------
-- The payload: under the plain-event limit on every tab, no identifier

local maxValues, maxBytes, maxTab = 0, 0, nil
for _, tab in ipairs(HoF.tabs()) do
    local payload = HoF.payload(1, tab)
    payload.kind = "halloffame"
    local n, bytes = countValues(payload), jsonBytes(payload)
    assert(n <= 900, tab .. ": " .. n .. " values")
    if n > maxValues then maxValues, maxTab = n, tab end
    maxBytes = math.max(maxBytes, bytes)
    assert(bytes < 40 * 1024, tab .. ": " .. bytes .. " bytes")
end
p = HoF.payload(1, "overview")
assert(#p.boards == 12 and #p.boards[1].rows == 3, "the overview: twelve podiums")

-- extension boards: forty full boards on one tab still fit in one plain event
for i = 1, 40 do
    assert(HoF.registerBoard("ext.board" .. i, { tab = "pve", title = "EXTENSION " .. i, unit = "kills",
        provider = function(ctx)
            local rows = {}
            for j, c in ipairs(chars) do rows[#rows + 1] = { identifier = c.id, characterKey = c.key, value = j, detail = "a detail" } end
            return rows
        end }))
end
assert(not HoF.registerBoard("bad key!", { tab = "pve", title = "X", provider = noop }), "invalid key")
assert(not HoF.registerBoard("x.y", { tab = "nowhere", title = "X", provider = noop }), "invalid tab")
assert(not HoF.registerBoard("x.y", { tab = "pve", title = "X" }), "provider required")
clock = clock + 11000
HoF.refresh("test")
local big = HoF.payload(1, "pve")
assert(countValues(big) <= 900 and #big.boards >= 3, "trimmed to fit: " .. countValues(big))
for i = 1, 40 do assert(HoF.unregisterBoard("ext.board" .. i)) end

-- a provider handing back an identifier as a name: the character's own name wins
assert(HoF.registerBoard("dogtown.kills", { tab = "pvp", title = "DOGTOWN KILLS", unit = "kills",
    provider = function(ctx) return { { identifier = "license:bbb222", characterKey = "default", name = "license:bbb222", value = 7 },
        { key = ctx.keyOf("license:eee555", "default"), value = 3 } } end }))
clock = clock + 11000
HoF.refresh("test")
local dog = HoF.cache().boards["dogtown.kills"].rows
assert(#dog == 1 and dog[1].name == "Mira Sol", "the provider's name never wins over the character's; the unnamed stays out")

local everything = {}
for _, d in ipairs(dialogs) do serialize(d.payload, everything) end
serialize(HoF.payload(1, "pvp"), everything)
local blob = table.concat(everything, "\n")
assert(not blob:find("license:", 1, true) and not blob:find("#default", 1, true) and not blob:find("#second", 1, true),
    "no account identifier in any payload")
assert(not blob:find("acct-", 1, true) and not blob:find("Account", 1, true), "nor an account name")

-- ---------------------------------------------------------------------------
-- The full ladder of one board (a card clicked): podium + list + the viewer's own
-- rank, from the cache, in one plain event

local function rebuildNow() clock = clock + 11000; HoF.refresh("test") end
-- the worst case: 120 characters with the longest names (64), details (60) and a long title on every row
local ladderBase = #chars
for i = 1, 120 do
    chars[#chars + 1] = { id = string.format("license:l%03d", i), key = "default", first = string.rep("W", 30) .. string.format("%03d", i), last = string.rep("X", 40) }
end
local viewerAt = 80 -- where the viewer (Jax, player 1) stands on that board
assert(HoF.registerBoard("ext.ladder", { tab = "pvp", title = "LADDER CHECK", subtitle = string.rep("S", 80), unit = "kills",
    provider = function()
        local out, value = {}, 2000
        for i = 1, 120 do
            if not (i == 6 or i == 50) then value = value - 2 end -- ties: 5 = 6, 49 = 50 (across the cut)
            if i == viewerAt then out[#out + 1] = { identifier = "license:aaa111", characterKey = "default", value = value + 1, detail = string.rep("D", 80) } end
            out[#out + 1] = { identifier = string.format("license:l%03d", i), characterKey = "default", value = value, detail = string.rep("D", 80) }
        end
        return out
    end }))
LightRP.titles = { forKey = function() return string.rep("T", 40) end } -- titles.lua labels are ~15 characters
rebuildNow()

mark = #queries
local shownBefore = #dialogs
actions["halloffame.board"](1, { type = "halloffame.board", key = "ext.ladder", tab = "overview" })
assert(#dialogs == shownBefore + 1 and #queries == mark, "a ladder reads the cache")
p = last()
local lad = p.ladder
assert(p.kind == "halloffame" and p.tab == "overview" and p.boards == nil and p.title == "HALL OF FAME" and p.hub == "The Crossing"
    and table.concat(p.tabs, ",") == "overview,pvp,races,pve,missions,wealth" and p.database == true and p.updatedAgoS == 0,
    "the header of the tab it was opened from, no boards")
assert(lad.key == "ext.ladder" and lad.title == "LADDER CHECK" and lad.unit == "kills" and lad.total == 121 and lad.ascending == nil, tostring(lad.total))
assert(#lad.rows == 50, "fifty rows: " .. #lad.rows)
assert(lad.rows[1].rank == 1 and lad.rows[5].rank == 5 and lad.rows[6].rank == 5 and lad.rows[7].rank == 7, "ties share a rank")
assert(lad.rows[49].rank == 49 and lad.rows[50].rank == 49, "a tie across the cut")
for i, r in ipairs(lad.rows) do
    assert(r.you == nil and #r.name == 64 and #r.detail == 60 and r.title == string.rep("T", 40), "row " .. i .. ": the worst case")
end
assert(lad.mine and lad.mine.rank == 80 and lad.mine.value == 2000 - 2 * 78 + 1 and lad.mine.detail == string.rep("D", 60),
    "the viewer outside the fifty: their own rank")
local ladderValues, ladderBytes = countValues(p), jsonBytes(p)
assert(ladderValues == HoF.countValues(p), "the module counts as framework.lua")
assert(ladderValues <= 900 and ladderBytes < 40 * 1024, string.format("50 worst-case rows in one plain event: %d values, %d bytes", ladderValues, ladderBytes))

-- the viewer inside the fifty: their row highlighted (and `mine`, which the page hides then)
viewerAt = 30
rebuildNow()
lad = HoF.ladderPayload(1, "ext.ladder", "pvp").ladder
assert(lad.rows[30].you == true and lad.rows[30].name == "Jax Rook" and lad.rows[30].rank == 30 and lad.mine.rank == 30, "the viewer's row")
for i, r in ipairs(lad.rows) do assert(i == 30 or r.you == nil, "one highlighted row") end

-- a ladderSize over the limit: the tail goes, never the podium nor `mine`
viewerAt = 75
rebuildNow()
C.ladderSize = 100
p = HoF.ladderPayload(1, "ext.ladder", "pvp"); p.kind = "halloffame"
assert(countValues(p) <= 900 and #p.ladder.rows >= 50 and #p.ladder.rows < 75, "trimmed to fit: " .. #p.ladder.rows .. " rows, " .. countValues(p))
assert(p.ladder.rows[1].rank == 1 and p.ladder.rows[3].rank == 3 and p.ladder.mine.rank == 75, "the podium and the viewer's rank stay")
for _, r in ipairs(p.ladder.rows) do assert(r.you == nil, "the viewer's row was trimmed: `mine` says it") end
local trimmedRows = #p.ladder.rows
C.ladderSize = 3
assert(#HoF.ladderPayload(1, "ext.ladder", "pvp").ladder.rows == 10 and HoF.ladderSize() == 10, "at least ten")
C.ladderSize = "lots"
assert(HoF.ladderSize() == 50 and #HoF.ladderPayload(1, "ext.ladder", "pvp").ladder.rows == 50, "junk: fifty")
C.ladderSize = 50

-- an ascending board: lowest first, every row of it
actions["halloffame.board"](1, { type = "halloffame.board", key = "races.race.trial", tab = "races" })
lad = last().ladder
assert(last().tab == "races" and lad.ascending == true and lad.unit == "time" and lad.subtitle == "Best time · WATSON LOOP · REV 2", tostring(lad.subtitle))
assert(#lad.rows == #HoF.cache().boards["races.race.trial"].rows and #lad.rows == lad.total and lad.rows[1].value == 30001, "fastest first, all of them")
for i = 2, #lad.rows do assert(lad.rows[i].value >= lad.rows[i - 1].value, "lowest first") end
assert(lad.mine == nil, "the viewer has no time on the current course")

-- wealth: behind its switch
actions["halloffame.board"](1, { type = "halloffame.board", key = "wealth.richest", tab = "wealth" })
assert(last().ladder.key == "wealth.richest" and last().ladder.mine.value == 1500 and last().ladder.rows[1].detail == nil, "the richest, total only")
C.showWealth = false
shownBefore = #dialogs
actions["halloffame.board"](1, { type = "halloffame.board", key = "wealth.richest", tab = "wealth" })
assert(#dialogs == shownBefore and results[#results].ok == false and results[#results].kind == "halloffame.board"
    and results[#results].text == "That board is not on the Hall of Fame.", "wealth off: refused, nothing sent")
assert(HoF.ladderPayload(1, "wealth.richest", "pvp") == nil)
C.showWealth = true

-- unknown boards and a closed Hall of Fame: a clean refusal, never an error
for _, bad in ipairs({ "nope.board", 42, {}, "" }) do
    shownBefore = #dialogs
    actions["halloffame.board"](1, { type = "halloffame.board", key = bad, tab = "pvp" })
    assert(#dialogs == shownBefore and results[#results].ok == false and results[#results].kind == "halloffame.board", "refused: " .. tostring(bad))
end
actions["halloffame.board"](1, { type = "halloffame.board", tab = "pvp" })
assert(results[#results].ok == false, "no key")
C.enabled = false
shownBefore = #dialogs
actions["halloffame.board"](1, { type = "halloffame.board", key = "pvp.wins", tab = "pvp" })
assert(#dialogs == shownBefore and results[#results].ok == false and results[#results].text == "The Hall of Fame is closed.")
C.enabled = true
-- a junk tab: the board's own
p = HoF.ladderPayload(1, "pvp.kills", "nowhere")
assert(p.tab == "pvp" and p.ladder.key == "pvp.kills")

-- a board registered but not computed yet: an empty ladder, not a refusal
assert(HoF.registerBoard("ext.later", { tab = "pve", title = "LATER", unit = "count", provider = function() return {} end }))
lad = HoF.ladderPayload(1, "ext.later", "overview").ladder
assert(lad.title == "LATER" and #lad.rows == 0 and lad.total == 0 and lad.mine == nil, "empty until the next rebuild")
assert(HoF.unregisterBoard("ext.later"))

-- exclusions: a test character leaves the ladder (the others close ranks), an excluded viewer has no rank
viewerAt = 30
C.exclude.characters = { "license:l001#default" }
rebuildNow()
lad = HoF.ladderPayload(1, "ext.ladder", "pvp").ladder
assert(lad.total == 120 and lad.rows[1].rank == 1 and lad.rows[1].name:sub(31, 33) == "002", "the leader excluded: " .. lad.rows[1].name)
assert(lad.rows[29].you == true and lad.mine.rank == 29, "the viewer moves up one")
C.exclude.characters = { "license:l001#default", "license:aaa111#default" }
lad = HoF.ladderPayload(1, "ext.ladder", "pvp").ladder
assert(lad.mine == nil, "excluded viewer, before the rebuild: no rank")
for _, r in ipairs(lad.rows) do assert(r.you == nil, "and no highlighted row") end
rebuildNow()
lad = HoF.ladderPayload(1, "ext.ladder", "pvp").ladder
assert(lad.total == 119 and lad.mine == nil, "after it: off the ladder")
for _, r in ipairs(lad.rows) do assert(r.name ~= "Jax Rook") end
C.exclude.characters = {}
rebuildNow()

-- a stale cache: rebuilt first, as an open; a fresh one is read as is
mark = #queries
clock = clock + C.cache.refreshMs
actions["halloffame.board"](1, { type = "halloffame.board", key = "pvp.wins", tab = "pvp" })
assert(#queries == mark + 6 and last().ladder.key == "pvp.wins" and last().updatedAgoS == 0, "stale: rebuilt before the ladder")
actions["halloffame.board"](1, { type = "halloffame.board", key = "pvp.wins", tab = "pvp" })
assert(#queries == mark + 6, "fresh: the cache")

-- REFRESH on a ladder answers the ladder (inside the limits too); a board gone answers the tab
clock = clock + 31000
actions["halloffame.refresh"](1, { type = "halloffame.refresh", tab = "pvp", key = "ext.ladder" })
assert(#queries == mark + 12 and last().ladder and last().ladder.key == "ext.ladder" and last().refreshInS == 30, "rebuilt, the ladder again")
actions["halloffame.refresh"](1, { type = "halloffame.refresh", tab = "pvp", key = "ext.ladder" })
assert(#queries == mark + 12 and last().ladder.key == "ext.ladder", "a refused refresh still answers the ladder")
actions["halloffame.refresh"](1, { type = "halloffame.refresh", tab = "pvp", key = "nope.board" })
assert(last().ladder == nil and last().boards and last().tab == "pvp", "an unknown board: the tab")

assert(HoF.unregisterBoard("ext.ladder"))
for i = #chars, ladderBase + 1, -1 do chars[i] = nil end
LightRP.titles = nil
rebuildNow()

-- ---------------------------------------------------------------------------
-- Staff: /lightrp.halloffame place | where | refresh

local cmd = commands["lightrp.halloffame"]
local ok, line = cmd(0, { "place" })
assert(not ok and line:find("In game only"), "the console cannot place it")
buckets[1] = 3
ok, line = cmd(1, { "place" })
assert(not ok and line:find("bucket 0"), "nor from a private instance")
buckets[1] = 0
local moved = #transforms
ok, line = cmd(1, { "place" })
assert(ok, tostring(line))
local t = transforms[#transforms]
assert(#transforms == moved + 1 and t.id == HoF.board.prop and t.def.yaw == 90, "the same prop, turned to the staff's heading")
assert(math.abs(t.def.position.x - 10.8) < 1e-6 and math.abs(t.def.position.y - 20) < 1e-6 and t.def.position.z == 5,
    "0.8 m behind the staff, who faces -X at heading 90")
point = interactions["halloffame.board"]
assert(math.abs(point.position.x - 10.8) < 1e-6 and math.abs(point.position.y - 20) < 1e-6, "the E point follows, at the board's centre")
assert(line == "position = { x = 10.800, y = 20.000, z = 5.000 }, heading = 90.0, -- server/config/halloffame.lua `board`, bucket 0", line)
assert(clientEvents[#clientEvents].name == LightRpEvents.net.hallOfFameBoard and clientEvents[#clientEvents].id == -1)
ok, line = cmd(1, {})
assert(ok and line:find("x = 10.800", 1, true) and line:find("prop " .. HoF.board.prop, 1, true), "where")
-- a prop that vanished is made again at the new place
props[HoF.board.prop] = nil
local oldProp = HoF.board.prop
staffRead = { position = { x = 0, y = 0, z = 1 }, heading = 0 }
ok, line = cmd(1, { "place" })
assert(ok and HoF.board.prop ~= oldProp and props[HoF.board.prop].yaw == 0 and math.abs(props[HoF.board.prop].position.y + 0.8) < 1e-6)
mark = #queries
ok, line = cmd(1, { "refresh" })
assert(ok and #queries == mark + 6, "refresh rebuilds at once")
assert(cmd(1, { "dance" }) == false, "unknown verb: the usage")
-- the board's new place drives the click range
spots[1] = { x = 0, y = 3, z = 1 }
local count = #dialogs
actions["halloffame.open"](1, { type = "halloffame.open", from = "board" })
assert(#dialogs == count + 1, "near the moved board")

-- ---------------------------------------------------------------------------
-- Without a database: the session rows and the online characters

db.ready = false
LightRP.activities.memoryRows = function()
    return {
        { key = "license:aaa111|default|arena.ffa|", activity_id = "arena.ffa", board = "", character_name = "Jax Rook", played = 2, wins = 2, kills = 5, deaths = 1 },
        { key = "license:zzz|default|arena.ffa|", activity_id = "arena.ffa", board = "", character_name = "Old Timer", played = 1, wins = 1, kills = 1, deaths = 0 },
        { key = "license:aaa111|default|race.trial|loop@1", activity_id = "race.trial", board = "loop@1", character_name = "Jax Rook", played = 1, best_time_ms = 70000 },
        { key = "license:zzz|default|race.trial|loop@1", activity_id = "race.trial", board = "loop@1", character_name = "Old Timer", played = 1, best_time_ms = 65000 },
        { key = "license:aaa111|default|race.trial|", activity_id = "race.trial", board = "", character_name = "Jax Rook", played = 1, wins = 0, best_time_ms = 70000 },
    }
end
LightRP.missions.reputation = function(id) return id == 1 and 700 or 0 end
clock = clock + 11000
HoF.refresh("test")
p = HoF.payload(1, "pvp")
assert(p.database == false, "the panel says the boards are this session's")
pw = boardOf(p, "pvp.wins")
assert(#pw.rows == 2 and pw.rows[1].name == "Jax Rook" and pw.rows[1].you == true and pw.rows[2].name == "Old Timer")
p = HoF.payload(1, "races")
trial = boardOf(p, "races.race.trial")
assert(trial.rows[1].name == "Old Timer" and trial.rows[1].value == 65000 and trial.subtitle == "Best time · LOOP · REV 1")
p = HoF.payload(1, "pve")
assert(boardOf(p, "pve.rep").rows[1].value == 700 and boardOf(p, "pve.rep").rows[1].name == "Jax Rook")
assert(HoF.cache().boards["wealth.richest"] and #HoF.cache().boards["wealth.richest"].rows == 0, "no wealth without a database")
assert(#HoF.cache().boards["dogtown.kills"].rows == 0, "an offline character named after its identifier stays out")
local noDb = table.concat(serialize(HoF.payload(1, "pvp")), "\n") .. table.concat(serialize(HoF.payload(1, "overview")), "\n")
assert(not noDb:find("license:", 1, true), "no identifier without a database either")

-- the database comes up: the session boards are rebuilt from it a moment later
db.ready = true
mark = #queries
HoF.onDatabaseReady()
assert(#queries == mark, "not at once: the other modules create their tables first")
pump()
assert(#queries == mark + 6 and HoF.payload(1, "pvp").database == true, "then from the database")

-- ---------------------------------------------------------------------------
-- Exclusions: staff (online, offline, config, revoked), test characters, the command

local function holding(key)
    local list = {}
    for boardKey, entry in pairs(HoF.cache().boards) do if entry.byKey[key] then list[#list + 1] = boardKey end end
    table.sort(list)
    return list
end
local function noRank(payload)
    for _, b in ipairs(payload.boards) do
        if b.mine then return false end
        for _, r in ipairs(b.rows) do if r.you then return false end end
    end
    return true
end
local function rebuild() clock = clock + 11000; HoF.refresh("test") end
local FAY, JAX, NYX = "license:fff666#default", "license:aaa111#default", "license:ddd444#default"

-- Fay Nox (player 2, online) leads every board; a registered board (a coming Dogtown) too
chars[#chars + 1] = { id = "license:fff666", key = "default", first = "Fay", last = "Nox" }
totals[#totals + 1] = { "license:fff666", "default", "arena.ffa", wins = 90, played = 90, kills = 300, deaths = 1 }
totals[#totals + 1] = { "license:fff666", "default", "turf.pve", wins = 90, played = 90, kills = 300, deaths = 1 }
times[#times + 1] = { "license:fff666", "default", "race.foot", "", 1000, 500 }
reps[#reps + 1] = { "license:fff666", "default", rep = 90000, completed = 900 }
clears[#clears + 1] = { "license:fff666", "default", "sector04_blackout", "critical", 90 }
wallets[#wallets + 1] = { "license:fff666", "default", 9000000, nil }
assert(HoF.registerBoard("dogtown.staffcheck", { tab = "pvp", title = "DOGTOWN", unit = "kills",
    provider = function() return { { identifier = "license:fff666", characterKey = "default", value = 9 },
        { identifier = "license:aaa111", characterKey = "default", value = 4 }, { identifier = "license:ddd444", characterKey = "default", value = 2 } } end }))
rebuild()
local fayBoards = #holding(FAY)
-- pvp wins/kills, rooftop race, pve wins/kills/rep, contracts, heists, richest, the registered board
assert(fayBoards == 10 and HoF.cache().boards["pvp.wins"].rows[1].name == "Fay Nox", "Fay on every board she plays: " .. fayBoards)
assert(HoF.cache().excluded == 0 and next(kvpStore) == nil, "nobody excluded yet, nothing stored")

-- staff online: the ACL says so at the rebuild; off every board, the registered one included, ranks closed
aclGrants[2] = { ["command.admin"] = true }
rebuild()
assert(#holding(FAY) == 0, "a staff online is on no board: " .. table.concat(holding(FAY), ","))
assert(HoF.cache().boards["pvp.wins"].rows[1].name == "Extra Number 12" and HoF.cache().boards["pvp.wins"].rows[1].rank == 1, "the others close ranks")
local dogtown = HoF.cache().boards["dogtown.staffcheck"].rows
assert(#dogtown == 2 and dogtown[1].name == "Jax Rook" and dogtown[1].rank == 1, "a registered board goes through the same filter")
assert(kvpStore["halloffame.staff.license:fff666"] == "Fay Nox", "the staff account is remembered (kvp)")
assert(HoF.cache().excluded == 1 and HoF.excludedBy(FAY) == "staff")

-- staff offline: the ACL cannot answer for them any more; the remembered account still counts
GetPlayers = function() return { "1" } end
local fayOnline = online[2]
online[2] = nil
rebuild()
assert(#holding(FAY) == 0, "a staff offline stays off the boards")

-- the ACL cannot answer (acl.read refused): nothing is forgotten
GetPlayers = function() return { "1", "2" } end
online[2] = fayOnline
aclGrants[2], aclBroken = nil, true
rebuild()
assert(#holding(FAY) == 0 and kvpStore["halloffame.staff.license:fff666"], "an ACL failure is not a demotion")
aclBroken = false

-- rights revoked: forgotten the next time they are seen online (opening the panel), back at once
mark = #queries
clock = clock + 11000
HoF.open(2, "pvp")
assert(kvpStore["halloffame.staff.license:fff666"] == nil and #queries == mark + 6, "forgotten, and the open rebuilds first")
assert(#holding(FAY) == fayBoards and boardOf(last(), "pvp.wins").rows[1].you == true, "back on the boards, her own row highlighted")
aclGrants[2] = { ["command.lightrp.status"] = true } -- a helper is staff too (LightRpConfig.staffPermissions)
rebuild()
assert(#holding(FAY) == 0)

-- the viewer becomes staff: no "YOU #N" from the panel's next answer, before the rebuild itself
aclGrants[1] = { ["command.adminfull"] = true }
clock = clock + 2000 -- inside the 10 s floor: the cache is not rebuilt yet
mark = #queries
actions["halloffame.tab"](1, { type = "halloffame.tab", tab = "pvp" })
assert(#queries == mark and HoF.cache().boards["pvp.wins"].byKey[JAX], "the cache still holds the viewer")
assert(noRank(last()), "but the excluded viewer sees no rank and no highlighted row")
assert(HoF.cache().retryAt, "the boards are marked for a rebuild")
clock = clock + 11000
pump() -- the timer picks it up
assert(#queries == mark + 6 and #holding(JAX) == 0, "rebuilt without the viewer")
for _, tab in ipairs(HoF.tabs()) do assert(noRank(HoF.payload(1, tab)), "no rank on " .. tab) end
aclGrants[1] = nil
clock = clock + 11000
HoF.open(1, "pvp")
assert(#holding(JAX) > 0 and boardOf(last(), "pvp.wins").mine, "demoted: ranked again")

-- staff never seen online: exclude.staffAccounts (their acl.jsonc userId)
C.exclude.staffAccounts = { "license:ddd444" }
rebuild()
assert(#holding(NYX) == 0 and HoF.excludedBy(NYX) == "staff (exclude.staffAccounts)", "a configured staff account, offline")

-- the switch: exclude.staff = false puts every staff back; Fay is still remembered meanwhile
C.exclude.staff = false
rebuild()
assert(#holding(FAY) == fayBoards and #holding(NYX) > 0 and kvpStore["halloffame.staff.license:fff666"], "staff exclusion off")
C.exclude.staff = true
rebuild()
assert(#holding(FAY) == 0 and #holding(NYX) == 0)
C.exclude.staffAccounts = {}

-- test characters and accounts from the config
C.exclude.characters = { "license:ccc333#second" }
C.exclude.accounts = { "license:bbb222" }
rebuild()
assert(#holding("license:ccc333#second") == 0 and #holding("license:bbb222#default") == 0, "config test character and account")
assert(#HoF.cache().boards["dogtown.kills"].rows == 0, "Mira's account is off the earlier registered board too")
C.exclude.tests = false
rebuild()
assert(#holding("license:ccc333#second") > 0 and #holding("license:bbb222#default") > 0, "tests switch off")
C.exclude.tests, C.exclude.characters, C.exclude.accounts = true, {}, {}

-- the command: exclude / include / excluded, applied at the rebuild it triggers
ok, line = cmd(1, { "exclude" })
assert(not ok and line:find("usage", 1, true), tostring(line))
ok, line = cmd(1, { "exclude", "99" })
assert(not ok and line:find("No player 99", 1, true), tostring(line))
ok, line = cmd(1, { "exclude", "a#b#c" })
assert(not ok and line:find("Invalid", 1, true), tostring(line))
mark = #queries
ok, line = cmd(1, { "exclude", "1" })
assert(ok and line:find("Jax Rook (license:aaa111#default) excluded", 1, true), tostring(line))
assert(#queries == mark + 6 and #holding(JAX) == 0, "a player online: their character, rebuilt at once")
assert(kvpStore["halloffame.exclude.license:aaa111#default"] == "Jax Rook", "saved")
assert(noRank(HoF.payload(1, "pvp")) and noRank(HoF.payload(1, "overview")), "an excluded viewer: no YOU #N")
ok, line = cmd(1, { "exclude", "1" })
assert(ok and line:find("already", 1, true))
ok, line = cmd(1, { "exclude", "license:x05#default" })
assert(ok and line:find("Extra Number 05", 1, true) and #holding("license:x05#default") == 0, "an offline character id: " .. line)
ok, line = cmd(1, { "exclude", "license:x06" })
assert(ok and line:find("every character", 1, true) and #holding("license:x06#default") == 0, "a whole account")
ok, line = cmd(0, { "exclude", "license:x07#default" })
assert(ok and #holding("license:x07#default") == 0, "from the console too")
ok, line = cmd(1, { "exclude", "2", "account" })
assert(ok and kvpStore["halloffame.exclude.license:fff666"] == "Fay Nox", "a player online's whole account")
ok, line = cmd(1, { "excluded" })
assert(ok and line:find("Staff (on): 1 seen online [Fay Nox (license:fff666) [every character]]", 1, true), line)
assert(line:find("Tests (on): 5 by command", 1, true) and line:find("Jax Rook (license:aaa111#default)", 1, true)
    and line:find("license:x06 [every character]", 1, true) and line:find("Last rebuild: ", 1, true), line)

ok, line = cmd(1, { "include", "1" })
assert(ok and line:find("back on the boards", 1, true) and #holding(JAX) > 0 and boardOf(HoF.payload(1, "pvp"), "pvp.wins").mine, line)
assert(kvpStore["halloffame.exclude.license:aaa111#default"] == nil)
ok, line = cmd(1, { "include", "1" })
assert(not ok and line:find("is not excluded", 1, true), line)
ok, line = cmd(1, { "include", "license:x05#default" })
assert(ok and #holding("license:x05#default") > 0)
ok, line = cmd(1, { "include", "license:x06#default" })
assert(not ok and line:find("stays excluded: test list (account)", 1, true), line)
ok, line = cmd(1, { "include", "2" })
assert(not ok and line:find("stays excluded", 1, true), "Fay's character: her account is listed (and staff)")
-- her account off the test list and forgotten as staff; still staff online, so remembered again at the rebuild
ok, line = cmd(1, { "include", "2", "account" })
assert(ok and line:find("off the test list", 1, true) and line:find("forgotten as staff", 1, true), line)
assert(#holding(FAY) == 0 and kvpStore["halloffame.staff.license:fff666"] == "Fay Nox", "seen online with staff rights: remembered again")

-- persisted: a restart (a new generation of the module) reads the kvp store back
GetPlayers = function() return { "1" } end
online[2] = nil
dofile("server/modules/halloffame.lua")
local restarted = LightRP.hallOfFame
assert(restarted ~= HoF and next(restarted.saved.staff) == nil, "a fresh module: nothing in memory before its first use")
HoF, cmd = restarted, commands["lightrp.halloffame"]
rebuild()
assert(#holding(FAY) == 0, "the remembered staff, offline, after a restart")
assert(#holding("license:x06#default") == 0 and #holding("license:x07#default") == 0, "the test list after a restart")
assert(#holding(JAX) > 0 and #holding("license:x05#default") > 0, "the included ones stay included")
ok, line = cmd(1, { "include", "license:x06" })
assert(ok and #holding("license:x06#default") > 0)

-- ---------------------------------------------------------------------------
-- The board's model, picked live by the staff: /lightrp.halloffame model

-- props.all as the server answers it: every prop of the bucket, the live ones included
local strays = {}
Open77.props.all = function()
    local list = {}
    for _, s in ipairs(allProps) do list[#list + 1] = s end
    for _, s in ipairs(strays) do list[#list + 1] = s end
    for id, def in pairs(props) do list[#list + 1] = { id = id, resource = "op77_lightrp", model = def.model, position = def.position } end
    return list
end
Open77.props.remove = function(id) removed[#removed + 1] = id; props[id] = nil; return true end
local function removedSince(n) local set = {}; for i = n + 1, #removed do set[removed[i]] = (set[removed[i]] or 0) + 1 end; return set end
local function liveBoards()
    local n = 0
    for _, def in pairs(props) do
        local d = (def.position.x - HoF.board.position.x) ^ 2 + (def.position.y - HoF.board.position.y) ^ 2
        if d < 25 and HoF.boardModels()[def.model] then n = n + 1 end
    end
    return n
end
local rows = C.board.models
assert(#rows >= 6 and rows[1].model == C.board.model, "the config default is the first candidate")
local seenModels = {}
for i, row in ipairs(rows) do
    assert(type(row.model) == "string" and row.model:match("^%a[%w_]*[%w_%.]*$") and not seenModels[row.model], "row " .. i .. ": an alias, once")
    seenModels[row.model] = true
    assert(type(row.scale) == "number" and row.scale >= 0.1 and row.scale <= 10 and type(row.yaw) == "number"
        and type(row.label) == "string" and row.label ~= "", "row " .. i .. ": scale, yaw, label")
end
assert(seenModels["electronics.tv.screen.16x9"], "the old board stays in the list, to go back")

-- the list: numbered, the one in use marked
local KEY = HoF.KVP_MODEL
local boardAt = HoF.board.prop
ok, line = cmd(1, { "model" })
assert(ok and line:find("1* " .. rows[1].model, 1, true) and line:find("2 " .. rows[2].model, 1, true), line)
for i, row in ipairs(rows) do assert(line:find(i .. (i == 1 and "*" or "") .. " " .. row.model, 1, true), "listed: " .. row.model) end
assert(line:find("config's default", 1, true) and #line <= 900, "the model in use and its source, under the chat limit")
assert(HoF.board.prop == boardAt and kvpStore[KEY] == nil, "listing changes nothing")

-- swap by number: a new prop, the old one gone, the clients told, the choice saved
mark = #removed
local events, heading = #clientEvents, HoF.board.heading
local pointBefore = interactions["halloffame.board"]
ok, line = cmd(1, { "model", "2" })
assert(ok, tostring(line))
local swapped = props[HoF.board.prop]
assert(HoF.board.prop ~= boardAt and swapped.model == rows[2].model and swapped.scale == rows[2].scale, "the second candidate at its scale")
assert(math.abs(swapped.yaw - (heading + rows[2].yaw) % 360) < 1e-6 and swapped.collision == true and swapped.physics == "static")
assert(swapped.position.x == HoF.board.position.x and swapped.position.y == HoF.board.position.y, "where the board stands")
assert(removedSince(mark)[boardAt] == 1 and props[boardAt] == nil and liveBoards() == 1, "the old board removed once: one board")
assert(clientEvents[#clientEvents].name == LightRpEvents.net.hallOfFameBoard and clientEvents[#clientEvents].id == -1
    and clientEvents[#clientEvents].payload.prop == HoF.board.prop and #clientEvents > events, "every client learns the new prop (ALT + click)")
assert(kvpStore[KEY] == rows[2].model .. "||0.0" and HoF.board.saved == true, "saved: the model, the row's scale, no extra turn")
assert(line:find("Kept over restarts", 1, true) and line:find("model = \"" .. rows[2].model .. "\"", 1, true), line)
local pointAfter = interactions["halloffame.board"]
assert(pointAfter.position.x == pointBefore.position.x and pointAfter.position.y == pointBefore.position.y
    and pointAfter.blip and pointAfter.marker == nil, "the E point stays in front of the board")
assert(math.abs(pointAfter.blip.position.z - (HoF.board.position.z + (rows[2].height or 2.0) * rows[2].scale + 0.4)) < 1e-6,
    "the icon moves to the new prop's height")

-- swap by alias with a scale and a turn; a row without a collider asks for none
local painting
for _, row in ipairs(rows) do if row.collision == false then painting = row end end
assert(painting, "a candidate without a collider")
local before = HoF.board.prop
ok, line = cmd(1, { "model", painting.model, "1.5", "90" })
assert(ok, tostring(line))
local p2 = props[HoF.board.prop]
assert(p2.model == painting.model and p2.scale == 1.5 and p2.collision == false and p2.physics == "none", "no collider asked of a host without one")
assert(math.abs(p2.yaw - (heading + painting.yaw + 90) % 360) < 1e-6, "the row's yaw plus the turn")
assert(props[before] == nil and liveBoards() == 1)
assert(kvpStore[KEY] == string.format("%s|1.500|90.0", painting.model), kvpStore[KEY])
ok, line = cmd(1, { "where" })
assert(ok and line:find("model " .. painting.model, 1, true) and line:find("scale 1.5,", 1, true)
    and line:find(string.format("row yaw %d + rotate 90", painting.yaw), 1, true) and line:find("staff's choice", 1, true), line)
assert(line:find("prop " .. HoF.board.prop, 1, true) and line:find(string.format("yaw = %d,", (painting.yaw + 90 + 180) % 360 - 180), 1, true),
    "where: the prop and the config line: " .. line)

-- "-" keeps the row's scale; a turn reads in (-180, 180]
ok, line = cmd(1, { "model", "3", "-", "540" })
assert(ok and props[HoF.board.prop].model == rows[3].model and props[HoF.board.prop].scale == rows[3].scale and HoF.board.rotate == 180, line)
assert(kvpStore[KEY] == rows[3].model .. "||180.0", kvpStore[KEY])

-- mistakes change nothing
local state = { prop = HoF.board.prop, model = HoF.board.model, kvp = kvpStore[KEY], removed = #removed }
for _, bad in ipairs({ { "model", "99" }, { "model", "0" }, { "model", "base\\environment\\x.mesh" }, { "model", "2", "50" },
    { "model", "2", "big" }, { "model", "2", "1", "left" } }) do
    ok, line = cmd(1, bad)
    assert(not ok and type(line) == "string" and line ~= "", "refused: " .. table.concat(bad, " "))
end
assert(HoF.board.prop == state.prop and HoF.board.model == state.model and kvpStore[KEY] == state.kvp and #removed == state.removed)
-- a model the props layer refuses leaves the old board standing, the old choice in use and saved
refuseModels["electronics.nothing"] = true
ok, line = cmd(1, { "model", "electronics.nothing", "2" })
assert(not ok and line:find("refused", 1, true) and line:find("stays", 1, true), line)
assert(HoF.board.prop == state.prop and HoF.board.model == state.model and HoF.board.saved == true and kvpStore[KEY] == state.kvp
    and #removed == state.removed and liveBoards() == 1, "nothing swapped")

-- the orphan sweep knows every candidate: strays of any of them near the board go, others stay
local bx, by = HoF.board.position.x, HoF.board.position.y
strays = {
    { id = "90", resource = "op77_lightrp", model = rows[1].model, position = { x = bx + 1, y = by, z = 0 } },
    { id = "91", resource = "op77_lightrp", model = rows[#rows].model, position = { x = bx, y = by - 2, z = 0 } },
    { id = "92", resource = "op77_lightrp", model = "furniture.chair.metal", position = { x = bx, y = by, z = 0 } },  -- not a board
    { id = "93", resource = "open77_media", model = rows[2].model, position = { x = bx, y = by, z = 0 } },          -- another resource's
    { id = "94", resource = "op77_lightrp", model = rows[2].model, position = { x = bx + 30, y = by, z = 0 } },     -- far away
}
mark = #removed
local old = HoF.board.prop
ok, line = cmd(1, { "model", "4" })
assert(ok, line)
local gone = removedSince(mark)
assert(gone["90"] == 1 and gone["91"] == 1 and gone[old] == 1, "the strays of other candidates and the old board, once each")
assert(not gone["92"] and not gone["93"] and not gone["94"] and not gone[HoF.board.prop], "nothing else, never the new board")
strays = {}

-- reset: the config's default, the saved choice forgotten
ok, line = cmd(1, { "model", "reset" })
assert(ok and line:find("config's default", 1, true), line)
assert(kvpStore[KEY] == nil and HoF.board.saved == false and HoF.board.model == C.board.model and HoF.board.rotate == 0
    and props[HoF.board.prop].model == rows[1].model and props[HoF.board.prop].scale == rows[1].scale and liveBoards() == 1)

-- the default reads board.scale / board.yaw before its row
C.board.scale, C.board.yaw = 1.7, 15
local c = HoF.choiceFor(C.board.model)
assert(c.scale == 1.7 and c.yaw == 15 and HoF.choiceFor(rows[2].model).scale == rows[2].scale, "overrides for the default only")
C.board.scale, C.board.yaw = nil, nil

-- kept over restarts: a new generation wears the saved model; strays of every candidate around
-- its place go (the hot reload's leftovers), its own board stays alone
ok, line = cmd(1, { "model", "2", "1.2", "45" })
assert(ok and kvpStore[KEY] == rows[2].model .. "|1.200|45.0", tostring(kvpStore[KEY]))
strays = {
    { id = "95", resource = "op77_lightrp", model = rows[#rows].model, position = { x = initial.x + 0.5, y = initial.y, z = 22 } },
    { id = "96", resource = "op77_lightrp", model = rows[3].model, position = { x = initial.x, y = initial.y + 1, z = 22 } },
}
mark = #removed
dofile("server/modules/halloffame.lua")
HoF, cmd = LightRP.hallOfFame, commands["lightrp.halloffame"]
gone = removedSince(mark)
local fresh = props[HoF.board.prop]
assert(HoF.board.saved == true and HoF.board.model == rows[2].model and HoF.board.scale == 1.2 and HoF.board.rotate == 45, "the saved choice wins at start")
assert(fresh.model == rows[2].model and fresh.scale == 1.2 and math.abs(fresh.yaw - (HoF.board.heading + rows[2].yaw + 45) % 360) < 1e-6)
assert(gone["95"] == 1 and gone["96"] == 1, "the previous generation's boards of other models swept at start")
assert(interactions["halloffame.board"].blip.icon == "trophy" and interactions["halloffame.board"].marker == nil)
strays = {}
-- an unreadable choice is ignored: the config's default
kvpStore[KEY] = "not a choice"
local logged = #logs
dofile("server/modules/halloffame.lua")
HoF, cmd = LightRP.hallOfFame, commands["lightrp.halloffame"]
assert(HoF.board.saved == false and HoF.board.model == C.board.model and props[HoF.board.prop].model == rows[1].model, "garbage: the default")
local ignored = false
for i = logged + 1, #logs do if logs[i]:find("unreadable board model", 1, true) then ignored = true end end
assert(ignored, "logged")
local decoded = HoF.decodeChoice(rows[2].model .. "|abc|zz")
assert(decoded and decoded.model == rows[2].model and decoded.scale == rows[2].scale and decoded.rotate == 0, "bad numbers: the row's")
assert(HoF.decodeChoice("a|b") == nil and HoF.decodeChoice(nil) == nil and HoF.decodeChoice("bad path\\x|1|0") == nil)
kvpStore[KEY] = nil
rebuild()

-- still no identifier in a player's payload
everything = {}
for _, d in ipairs(dialogs) do serialize(d.payload, everything) end
for _, tab in ipairs(HoF.tabs()) do serialize(HoF.payload(1, tab), everything) end
blob = table.concat(everything, "\n")
assert(not blob:find("license:", 1, true) and not blob:find("#default", 1, true), "no account identifier in any payload")

print(string.format("PASS: board beside the terminal (%.3f, %.3f, heading %.1f), E point, prop + orphan sweep, competition ranks and ties,"
    .. " race times on the current course, PvE/missions/clears by difficulty, wealth switch + bank-only fallback, cache 5 min +"
    .. " 30 s/player + 10 s floor, payload max %d values (%s) ~%d bytes, extension trim,"
    .. " ladder (cache only, 50 worst-case rows = %d values ~%d bytes, ladderSize 100 trimmed to %d rows, ties across the cut, viewer in/out/trimmed,"
    .. " ascending, wealth gate, refusals, empty, exclusions, stale rebuild, refresh), staff place/where/refresh, board model picker (list, swap by number/alias, scale/rotate, refused, kvp + restart, reset, sweep across models), trophy blip without a floor marker, no identifiers, no-DB mode, retry + database-ready rebuild,"
    .. " exclusions: staff online/offline/config/revoked/ACL failure, registered boards, no YOU #N, switches, test list command, kvp across a restart",
    initial.x, initial.y, initial.heading, maxValues, tostring(maxTab), maxBytes, ladderValues, ladderBytes, trimmedRows))
