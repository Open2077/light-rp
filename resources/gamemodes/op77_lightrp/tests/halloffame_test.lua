-- The Hall of Fame (server/modules/halloffame.lua): the board beside the activities
-- terminal, the boards aggregated from the stored stats, competition ranking and its
-- ties, race times lowest first on the current course, the wealth switch, the cache
-- and its rate limits, the payload under the plain-event limit, the staff command,
-- the session rows without a database, and no account identifier in any payload.
dofile("shared/events.lua")
dofile("shared/config.lua")
dofile("server/config/activities.lua")
dofile("server/config/halloffame.lua")
local C = LightRpHallOfFame

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
local spots = { [1] = { x = 0, y = 0, z = 0 }, [2] = { x = 0, y = 0, z = 0 } }
local staffRead = { position = { x = 10, y = 20, z = 5 }, heading = 90 }
-- a board left by the previous generation (removed at start) and another resource's (kept)
local allProps = {
    { id = "7", resource = "op77_lightrp", model = C.board.model, position = { x = -763.5, y = 777.9, z = 22.4 } },
    { id = "8", resource = "open77_media", model = C.board.model, position = { x = -763.5, y = 777.9, z = 22.4 } },
}
Open77 = {
    props = {
        create = function(def) propSeq = propSeq + 1; props[tostring(propSeq)] = def; return tostring(propSeq) end,
        setTransform = function(id, def) if not props[id] then return false, "not_found" end; transforms[#transforms + 1] = { id = id, def = def }; return true end,
        remove = function(id) removed[#removed + 1] = id; return true end,
        all = function() return allProps end,
    },
    players = {
        position = function(id) local s = spots[id]; return s and { x = s.x, y = s.y, z = s.z, bucket = buckets[id] or 0 } end,
        get = function() return staffRead end,
    },
}

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
assert(math.abs(HoF.board.position.x - (-763.777)) < 0.01 and math.abs(HoF.board.position.y - 777.723) < 0.01,
    string.format("forward 6 / right -4 of the hub: %.3f %.3f", HoF.board.position.x, HoF.board.position.y))
assert(math.abs(HoF.board.heading - 266.3) < 0.1, "the screen faces the arrival point: " .. HoF.board.heading)
local terminal = { x = -760.553, y = 780.294 }
local apart = math.sqrt((HoF.board.position.x - terminal.x) ^ 2 + (HoF.board.position.y - terminal.y) ^ 2)
assert(apart > 3 and apart < 5, "a few metres from the activities terminal: " .. apart)
-- the E point stands 1.8 m in front of the screen, toward the hub
assert(math.abs(point.position.x - (-761.98)) < 0.05 and math.abs(point.position.y - 777.61) < 0.05,
    string.format("E point %.2f %.2f", point.position.x, point.position.y))
local created = props[HoF.board.prop]
assert(created and created.model == "electronics.tv.screen.16x9" and created.collision == true and created.physics == "static",
    "a static board with a collider (ALT + click hits physical bodies)")
assert(math.abs(created.yaw - HoF.board.heading) < 1e-6 and created.bucket == 0 and created.scale == 2.5)
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
assert(math.abs(point.position.x - 9.0) < 1e-6 and math.abs(point.position.y - 20) < 1e-6, "the E point follows, in front of the screen")
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

print(string.format("PASS: board beside the terminal (%.3f, %.3f, heading %.1f), E point, prop + orphan sweep, competition ranks and ties,"
    .. " race times on the current course, PvE/missions/clears by difficulty, wealth switch + bank-only fallback, cache 5 min +"
    .. " 30 s/player + 10 s floor, payload max %d values (%s) ~%d bytes, extension trim, staff place/where/refresh, no identifiers, no-DB mode, retry + database-ready rebuild",
    initial.x, initial.y, initial.heading, maxValues, tostring(maxTab), maxBytes))
