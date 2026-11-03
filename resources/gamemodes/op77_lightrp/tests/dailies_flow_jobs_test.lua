-- Dailies fed by the job flows (server/modules/dailies.lua K.full_truck, K.full_round,
-- K.two_wheels, K.fragile, K.water_break), driven through the REAL producers:
-- server/modules/job_work.lua (E at a work point, the client's batch reports on
-- op77_lightrp:work:finish, /work stop; sales through the real inventory and wallet),
-- server/modules/job_runs.lua (jobs.start at the desk or from the menu, the client's
-- op77_lightrp:job:begin / :finish, service lifts, payment) and, for the drink,
-- server/modules/inventory.lua + server/modules/consumables.lua (inventory.use, the
-- client's consume:ready / consume:finish, Inv.completeUse -> onItemUsed). Seats and
-- vehicle health come from the dailies sampler itself (LightRP.dailies.sample, the
-- producer of those samples). Only the host is stubbed: natives, a transactional SQL
-- model (the one tests/job_work_test.lua uses, plus the dailies and receipt tables),
-- and the LightRP core shims. Progress is read from providers.dailies(id).list.
dofile("shared/events.lua"); dofile("shared/config.lua"); dofile("shared/jobs.lua")
dofile("shared/items.lua"); dofile("shared/consumables.lua")
local noop = function() end
local function clone(v) if type(v) ~= "table" then return v end local t = {} for k, x in pairs(v) do t[k] = clone(x) end return t end
local encoded, serial = {}, 0
_G.json = { encode = function(v) serial = serial + 1; encoded[tostring(serial)] = clone(v); return tostring(serial) end,
    decode = function(k) return clone(encoded[k] or {}) end }

-- ── the host ──
local clock, unixNow = 1000, 20395 * 86400 + 3600 -- Monday 2025-11-03, 01:00 UTC
local life, seat, locked = "alive", nil, false
local position = { x = 0, y = 0, z = 0, bucket = 0 }
local records, health, drivers = {}, {}, {}
local char = { identifier = "acc1", key = "default", status = "active", job = "unemployed", jobGrade = 0 }
local state = { inventories = {}, wallets = {}, migrations = {}, ledger = {}, receipts = {}, dailies = {}, meta = {} }
local uuid = 0
local db = { ready = true, schema = noop, query = function() return {} end }
function db.read(sql, p)
    if sql:find("lightrp_inventories", 1, true) then local v = state.inventories[p[1]]; return true, v and { clone(v) } or {} end
    if sql:find("lightrp_cash_migrations", 1, true) then local v = state.migrations[p[1]]; return true, v and { clone(v) } or {} end
    if sql:find("lightrp_wallets", 1, true) then
        for _, w in pairs(state.wallets) do if w.identifier == p[1] and w.character_key == p[2] then return true, { clone(w) } end end
        return true, {}
    end
    if sql:find("FROM lightrp_dailies_meta", 1, true) then local m = state.meta[p[1]]; return true, m and { clone(m) } or {} end
    if sql:find("FROM lightrp_dailies ", 1, true) then
        local out = {}
        for i = 2, #p do local r = state.dailies[p[1] .. "|" .. p[i]]; if r then out[#out + 1] = clone(r) end end
        return true, out
    end
    error("unmodelled read: " .. sql)
end
function db.single(sql, p)
    if sql == "SELECT UUID() AS id" then uuid = uuid + 1; return { id = "run-" .. uuid } end
    if sql:find("SELECT 1", 1, true) then return state.wallets[p[1]] and { x = 1 } end
    local _, rows = db.read(sql, p); return rows[1]
end
local function apply(s, sql, p)
    if sql:find("INSERT INTO lightrp_inventories", 1, true) then s.inventories[p[1]] = { items = p[6], slots = p[4], max_weight = p[5] }
    elseif sql:find("INSERT INTO lightrp_cash_migrations", 1, true) then s.migrations[p[1]] = { account_number = p[1], inventory_id = p[2] }
    elseif sql:find("INSERT INTO lightrp_wallets", 1, true) then s.wallets[p[1]] = { account_number = p[1], identifier = p[2], character_key = p[3], owner_name = p[4], cash = p[5], bank = p[6] }
    elseif sql:find("SET cash = 0", 1, true) then s.wallets[p[1]].cash = 0
    elseif sql:find("SET bank = ?", 1, true) then s.wallets[p[2]].bank = p[1]
    elseif sql:find("INSERT INTO lightrp_transactions", 1, true) then s.ledger[#s.ledger + 1] = clone(p)
    elseif sql:find("INSERT INTO lightrp_job_run_receipts", 1, true) then
        if s.receipts[p[1]] then error("duplicate receipt " .. p[1]) end
        s.receipts[p[1]] = { job = p[4], amount = p[5] }
    elseif sql:find("INSERT INTO lightrp_dailies_meta", 1, true) then s.meta[p[1]] = { streak = p[2], last_day = p[3], claimed = p[4], counts = p[5] }
    elseif sql:find("INSERT INTO lightrp_dailies ", 1, true) then s.dailies[p[1] .. "|" .. p[2]] = { period = p[2], state = p[3] }
    elseif sql:find("DELETE FROM lightrp_dailies ", 1, true) then for i = 2, #p do s.dailies[p[1] .. "|" .. p[i]] = nil end
    elseif sql:find("UPDATE lightrp_characters", 1, true) then -- the job columns
    else error("unmodelled write: " .. sql) end
end
function db.run(sql, p) apply(state, sql, p); return true, 1 end
function db.transaction(writes)
    local draft = clone(state)
    for _, q in ipairs(writes) do apply(draft, q.query, q.values) end
    state = draft; return true
end

local handlers, actions, commands, providers, notices = {}, {}, {}, {}, {}
local lastCycle, lastWork, lastConsume
local animation, animationSerial = nil, 0
_G.LightRP = {
    db = db, log = noop, nowMs = function() return clock end,
    module = function(name, def)
        def.name = name
        for i = #LightRP._modules, 1, -1 do if LightRP._modules[i].name == name then table.remove(LightRP._modules, i) end end
        LightRP._modules[#LightRP._modules + 1] = def; LightRP[name] = def; return def
    end,
    _modules = {},
    eachModule = function(hook, ...) for _, m in ipairs(LightRP._modules) do if type(m[hook]) == "function" then m[hook](...) end end end,
    command = function(name, _, fn) commands[name] = fn end,
    action = function(name, fn) actions[name] = fn end,
    state = noop, stateProvider = function(key, fn) providers[key] = fn end, result = noop, dialog = noop,
    notice = function(id, n) assert(type(n.kind) == "string"); notices[#notices + 1] = { id = id, title = n.title, body = n.body } end,
    interaction = noop, removeInteraction = noop,
    characters = { switching = {}, get = function(id) return id == 1 and char or nil end, displayName = function() return "Worker" end },
    nearInteraction = function(_, d, slack)
        return (position.bucket or 0) == (d.bucket or 0)
            and (position.x - d.position.x) ^ 2 + (position.y - d.position.y) ^ 2 + (position.z - d.position.z) ^ 2 <= (d.radius + (slack or 0)) ^ 2
    end,
    -- the first day guide opens its practice sites (tests/job_work_test.lua does the same)
    tutorial = { allowsWork = function() return true end },
}
_G.Open77 = {
    time = { unix = function() return unixNow end },
    players = {
        position = function(id) return id == 1 and position or nil end,
        positions = function() return { [1] = { x = position.x, y = position.y, z = position.z, bucket = position.bucket } } end,
        getLifeState = function() return { phase = life } end,
        teleport = function(_, dest) return { await = function() position = { x = dest.x, y = dest.y, z = dest.z, bucket = 0 }; return true end } end,
    },
    vehicles = {
        getPlayerSeat = function() return seat end,
        get = function(v) return { record = records[v], bucket = position.bucket, position = position } end,
        getHealth = function(v) return health[v] end,
        getDriver = function(v) return drivers[v] end,
        isLocked = function() return locked end,
    },
    animations = {
        current = function() return animation end,
        play = function(_, profile, options)
            assert(options.loop and options.clip)
            animationSerial = animationSerial + 1
            animation = { active = true, playbackId = "anim:" .. animationSerial, profile = profile, clip = options.clip }
            return animation
        end,
        stop = function(_, id) if animation and animation.playbackId == id then animation = nil end end,
    },
}
_G.RegisterNetEvent = function(name, fn) handlers[name] = fn end
_G.AddEventHandler = noop
_G.CreateThread = function(fn)
    -- run at once up to its first Wait; long-lived loops stay parked there
    local co = coroutine.create(fn)
    local ok, err = coroutine.resume(co)
    if not ok then error(err) end
end
_G.Wait = function() if coroutine.isyieldable() then coroutine.yield() end end
_G.GetPlayers = function() return { "1" } end
_G.GetPlayerName = function(id) return id == 1 and "Worker" or nil end
_G.GetCurrentResourceName = function() return "op77_lightrp" end
local NET = LightRpEvents.net
_G.TriggerClientEvent = function(event, _, p)
    if event == NET.workCycle and type(p) == "table" and p.token then lastCycle = p end
    if event == NET.jobWork and type(p) == "table" and p.token then lastWork = p end
    if event == NET.consume then lastConsume = p end
end

-- the producers (manifest order), then the dailies module that listens to them
dofile("server/modules/inventory.lua")
dofile("server/modules/economy.lua")
dofile("server/config/economy.lua")
dofile("server/modules/jobs.lua")
dofile("server/modules/consumables.lua")
dofile("server/modules/vehicles.lua") -- LightRP.vehicles.byKey: the catalogue categories (Bikes)
dofile("server/config/job_work.lua"); dofile("server/modules/job_work.lua")
dofile("server/config/job_runs.lua"); dofile("server/config/delivery.lua"); dofile("server/modules/job_runs.lua")
dofile("server/config/dailies.lua"); dofile("server/modules/dailies.lua")
local Inv, Money, W, Runs = LightRP.inventory, LightRP.money, LightRP.jobWork, LightRP.jobRuns
local CW, CR = LightRpJobWork, LightRpJobRuns
local function D() return LightRP.dailies end -- the module is reloaded once (a restart)
for _, hook in ipairs({ "onJobWorkCompleted", "onJobRunStarted", "onJobRunStep", "onJobRunCompleted", "onItemUsed" }) do
    assert(type(D()[hook]) == "function", "dailies listens to " .. hook)
end
LightRP.eachModule("onCharacterLoaded", 1, char)
assert(Money.get(1) and Inv.player(1), "wallet and bag loaded")
assert(Inv.count(Inv.playerId(1), "water") > 0, "the starting water")

-- ── helpers ──
local function card(contractId)
    for _, c in ipairs(providers.dailies(1).list or {}) do if c.id == contractId then return c end end
end
local function isDone(contractId) local c = card(contractId); return c ~= nil and c.done == true end
local function value(contractId) local c = card(contractId); return c and c.value or nil end
local function give(contractId)
    local ok, text = commands["lightrp.dailies"](0, { "give", "1", contractId })
    assert(ok, text)
    assert(card(contractId) and not isDone(contractId) and value(contractId) == 0, "given from zero: " .. contractId)
end
local function noticed(title)
    for i = #notices, 1, -1 do if notices[i].id == 1 and notices[i].title == title then return true end end
    return false
end
local function count(name) return Inv.count(Inv.playerId(1), name) end

-- job_work: press E at the point (the interaction dispatch), report up to n batches
-- the way the client does (after the progress bar), then /work stop if still working.
local function workPoint(job, short)
    for _, p in ipairs(CW.jobs[job].points) do
        if p.id == short then return p end
    end
    error("no point " .. job .. "." .. short)
end
local function work(job, short, n)
    local p = workPoint(job, short)
    clock = clock + 600
    position = { x = p.position.x, y = p.position.y, z = p.position.z, bucket = CW.jobs[job].bucket or 0 }
    LightRP.eachModule("onInteract", 1, "work." .. job .. "." .. short)
    assert(W.isActive(1), "working at " .. job .. "." .. short .. ": " .. tostring(notices[#notices] and notices[#notices].body))
    local done = 0
    while W.isActive(1) and done < (n or math.huge) do
        local token = lastCycle.token
        clock = clock + lastCycle.durationMs + 5
        _G.source = 1; handlers[NET.workFinish]({ token = token, status = "success" })
        done = done + 1
    end
    if W.isActive(1) then local ok = commands["work"](1, { "stop" }); assert(ok) end
    assert(not W.isActive(1))
    return done
end
-- collect n batches at a site and process them all
local function haul(job, site, n)
    assert(work(job, site, n) == n, "collected " .. n .. " at " .. site)
    local d = CW.jobs[job]
    local batches = count(d.raw) // d.input
    assert(work(job, (job == "sanitation" and "recycling" or "workshop"), batches) == batches, "processed")
end
local function sell(job)
    local d = CW.jobs[job]
    local goods = count(d.product)
    local bank = Money.get(1).bank
    assert(work(job, "buyer", 1) == 1, "sold")
    assert(count(d.product) == 0 and Money.get(1).bank > bank, "goods gone, bank paid")
    return goods
end

-- job_runs: the client's begin / finish for the current stop. `between` runs on the
-- way to it (driving samples, a drink). A lift runs its teleport and advances.
local function step(between)
    local s = Runs.snapshot(1)
    assert(s.active, "a run in progress")
    if between then between(s) end
    local o = s.objective.position
    clock = clock + 600
    position = { x = o.x, y = o.y, z = o.z, bucket = 0 }
    _G.source = 1
    lastWork = nil
    handlers[NET.jobBegin]({ id = s.id, index = s.index })
    if s.objective.kind == "lift" then
        assert(Runs.snapshot(1).index == s.index + 1, "through the service lift")
        return s
    end
    assert(lastWork and lastWork.token, "work started at " .. s.objective.kind .. " " .. s.index)
    clock = clock + lastWork.durationMs + 20
    handlers[NET.jobFinish]({ token = lastWork.token, status = "success" })
    assert(not Runs.snapshot(1).active or Runs.snapshot(1).index == s.index + 1, "stop " .. s.index .. " done")
    return s
end
local function startRun(job)
    clock = clock + CR.cooldownMs + 1000
    char.job = job
    if job == "delivery" then
        actions["jobs.start"](1, { from = "menu" }) -- dispatch from the player menu
    else
        local desk = LightRpConfig.jobs.centers[1].position
        position = { x = desk.x, y = desk.y, z = desk.z, bucket = 0 }
        actions["jobs.start"](1, {})
    end
    local s = Runs.snapshot(1)
    assert(s.active and s.job == job, "work order accepted")
    return s
end
-- the dailies sampler, on the way: n samples 5 s apart
local function sample(n) for _ = 1, n or 1 do clock = clock + 5000; D().sample(5) end end
local BIKE, CAR, CAR2 = 50, 60, 61
records[BIKE] = LightRP.vehicles.byKey.apollo.record
records[CAR] = LightRP.vehicles.byKey.cortes.record
records[CAR2] = LightRP.vehicles.byKey.hella.record
assert(LightRP.vehicles.byKey.apollo.category == "Bikes" and LightRP.vehicles.byKey.cortes.category ~= "Bikes")
local function drive(vehicle, seatName) return function() seat = { vehicleId = vehicle, seat = seatName or "seat_front_left" }; sample(2); seat = nil end end
local function delivery(between) local receipts = 0 for _ in pairs(state.receipts) do receipts = receipts + 1 end
    while Runs.snapshot(1).active do step(between) end
    local after = 0 for _ in pairs(state.receipts) do after = after + 1 end
    assert(after == receipts + 1, "the run was paid")
end

-- ════════════════════════════════════════════════════════════════════════
-- full_truck: at least 11 goods in one sale (sanitation, scrapper)
-- ════════════════════════════════════════════════════════════════════════
char.job = "sanitation"
give("full_truck")
-- failure: a sale of 10
haul("sanitation", "collection_west", 5)
haul("sanitation", "collection_center", 5)
assert(count("recyclables") == 10)
assert(sell("sanitation") == 10)
assert(not isDone("full_truck"), "10 goods is one bagful")
-- success: 11 in one sale
haul("sanitation", "collection_west", 6)
haul("sanitation", "collection_center", 5)
assert(sell("sanitation") == 11)
assert(isDone("full_truck") and noticed("DAILY COMPLETE"), "11 goods in one sale")
-- No trunk was used above, and that is the intended reading: the goal reads "one
-- bagful of pickups makes 10" (a 40 kg bag holds 10 trash bags of 4 kg, processed
-- into 10 goods). 11 takes a second load collected before the sale; the trunk is
-- not required, so the threshold stays at 11 with nothing in the trunk.

-- failure: a practice run (the first day guide's site, its own bucket) selling 11
give("full_truck")
for _ = 1, 11 do assert(work("tutorial", "crates", nil) == 1, "one practice crate per press") end
for _ = 1, 11 do assert(work("tutorial", "bench", nil) == 1) end
assert(count("practice_parts") == 11)
assert(sell("tutorial") == 11)
assert(not isDone("full_truck"), "a practice sale of 11 does not count")

-- success: the scrapper's 11
char.job = "scrapper"
give("full_truck")
haul("scrapper", "salvage_south", 8)
haul("scrapper", "salvage_north", 3)
assert(count("salvaged_parts") == 11)
assert(sell("scrapper") == 11)
assert(isDone("full_truck"), "scrapper: 11 parts in one sale")

-- ════════════════════════════════════════════════════════════════════════
-- full_round: both collection sites, then the buyer, no sale in between
-- ════════════════════════════════════════════════════════════════════════
char.job = "sanitation"
give("full_round")
haul("sanitation", "collection_west", 1)
assert(value("full_round") == 1, "one site")
haul("sanitation", "collection_west", 1)
assert(value("full_round") == 1, "the same site twice is still one")
haul("sanitation", "collection_center", 1)
assert(value("full_round") == 2, "both sites")
sell("sanitation")
assert(isDone("full_round"), "both sites, then the buyer")

-- failure: a sale with one site resets the round; it takes both again
give("full_round")
haul("sanitation", "collection_center", 2)
assert(value("full_round") == 1)
sell("sanitation")
assert(not isDone("full_round") and value("full_round") == 0, "a sale after one site starts over")
haul("sanitation", "collection_west", 1)
assert(value("full_round") == 1, "the old site is forgotten")
-- the round is kept in the stored entry: the dailies resource restarts and the
-- player reconnects between the two sites
dofile("server/modules/dailies.lua")
LightRP.eachModule("onDisconnected", 1)
LightRP.eachModule("onCharacterLoaded", 1, char)
assert(card("full_round") and value("full_round") == 1, "restored from the database with its site")
haul("sanitation", "collection_center", 1)
assert(value("full_round") == 2)
sell("sanitation")
assert(isDone("full_round"), "finished after the restart")

-- the scrapper's own sites; the sanitation sites mean nothing to it
char.job = "scrapper"
give("full_round")
haul("scrapper", "salvage_north", 1)
haul("scrapper", "salvage_south", 1)
assert(value("full_round") == 2)
sell("scrapper")
assert(isDone("full_round"), "scrapper round")

-- ════════════════════════════════════════════════════════════════════════
-- two_wheels: a whole delivery run driving only a bike
-- ════════════════════════════════════════════════════════════════════════
math.randomseed(77)
char.job = "delivery"
give("two_wheels")
startRun("delivery")
delivery(drive(BIKE))
assert(isDone("two_wheels"), "a whole run on a bike")

-- failure: a car for part of the run
give("two_wheels")
startRun("delivery")
local legs = 0
delivery(function() legs = legs + 1; drive(legs == 2 and CAR or BIKE)() end)
assert(not isDone("two_wheels"), "a car on one leg")

-- failure: on foot the whole run (nothing driven)
give("two_wheels")
startRun("delivery")
delivery(function() sample(2) end)
assert(not isDone("two_wheels"), "walking is not riding")

-- a bike passenger is not the rider; the rider is found through getDriver whatever the seat
give("two_wheels")
startRun("delivery")
drivers[BIKE] = 2
delivery(drive(BIKE, "seat_back"))
assert(not isDone("two_wheels"), "riding pillion")
give("two_wheels")
startRun("delivery")
drivers[BIKE] = 1
delivery(drive(BIKE, "seat_front"))
assert(isDone("two_wheels"), "the driver of the bike, by getDriver")
drivers[BIKE] = nil

-- a cancelled bike run never counts, and the next run starts clean
give("two_wheels")
startRun("delivery")
step(drive(BIKE))
actions["jobs.cancel"](1) -- abandoned from the player menu
assert(not Runs.snapshot(1).active and not isDone("two_wheels"))
startRun("delivery")
delivery(drive(CAR))
assert(not isDone("two_wheels"), "the cancelled run's bike does not carry over")

-- ════════════════════════════════════════════════════════════════════════
-- fragile: a whole delivery run in one car losing at most 5 % of its health
-- ════════════════════════════════════════════════════════════════════════
give("fragile")
health[CAR] = 1000
startRun("delivery")
local stops = 0
delivery(function() stops = stops + 1; if stops == 2 then health[CAR] = 960 end; drive(CAR)() end)
assert(isDone("fragile"), "4 % lost: fine")

-- failure: 7 % lost on the way, repaired before the end
give("fragile")
health[CAR] = 1000
startRun("delivery")
stops = 0
delivery(function()
    stops = stops + 1
    seat = { vehicleId = CAR, seat = "seat_front_left" }
    sample(1)
    if stops == 2 then health[CAR] = 930 end
    sample(1)
    if stops == 2 then health[CAR] = 1000 end
    seat = nil
end)
assert(not isDone("fragile"), "the lowest health counts, not the repaired one")

-- failure: damage after the last sample, read at the last drop-off
give("fragile")
health[CAR] = 1000
startRun("delivery")
stops = 0
local total = Runs.snapshot(1).total
delivery(function() stops = stops + 1; drive(CAR)(); if stops == total then health[CAR] = 940 end end)
assert(not isDone("fragile"), "6 % lost on the last leg")

-- failure: two cars in one run
give("fragile")
health[CAR], health[CAR2] = 1000, 1000
startRun("delivery")
stops = 0
delivery(function() stops = stops + 1; drive(stops == 2 and CAR2 or CAR)() end)
assert(not isDone("fragile"), "one car for the whole run")

-- failure: no car at all
give("fragile")
startRun("delivery")
delivery(function() sample(2) end)
assert(not isDone("fragile"), "no car driven")

-- the driver is found the same way as for two_wheels (drives(): seat_front_left, or
-- getDriver naming the player): from another seat, it counts when getDriver says so
give("fragile")
health[CAR] = 1000
drivers[CAR] = 1
startRun("delivery")
delivery(drive(CAR, "seat_front"))
assert(isDone("fragile"), "the driver from another seat, by getDriver")
-- failure: the same seat when getDriver names someone else (a passenger)
give("fragile")
drivers[CAR] = 2
startRun("delivery")
delivery(drive(CAR, "seat_front"))
assert(not isDone("fragile"), "a passenger is not the driver")
drivers[CAR] = nil

-- ════════════════════════════════════════════════════════════════════════
-- water_break: a drink between the first and the last AC unit, then the route done
-- ════════════════════════════════════════════════════════════════════════
-- the drink: inventory.use (consumables: the bottle animation), the client's ready
-- and finish reports, Inv.completeUse -> onItemUsed
local function use(name)
    local inv = Inv.player(1)
    local slot
    for k, item in pairs(inv.items) do if item.name == name then slot = k end end
    assert(slot, "a " .. name .. " in the bag")
    local before = count(name)
    lastConsume = nil
    actions["inventory.use"](1, { slot = slot })
    assert(lastConsume and lastConsume.phase == "prepare", "the consumption is prepared")
    _G.source = 1; handlers[NET.consumeReady]({ token = lastConsume.token })
    assert(lastConsume.phase == "play", "the animation plays")
    clock = clock + lastConsume.durationMs + 10
    handlers[NET.consumeFinish]({ token = lastConsume.token, status = "success" })
    assert(lastConsume.phase == "finished" and lastConsume.ok == true and count(name) == before - 1, name .. " consumed")
end
-- the AC route: lift, work x3, lift, report
local route = CR.routes.ac_cleaner.steps
local first, lastUnit
for i, s in ipairs(route) do if s.kind == "work" then first = first or i; lastUnit = i end end
assert(first == 2 and lastUnit == 4 and #route == 6, "lift, three units, lift, report")
local function acRun(drinkAt, item)
    startRun("ac_cleaner")
    while Runs.snapshot(1).active do
        local index = Runs.snapshot(1).index
        -- drinkAt = the stop about to be done: the drink comes after stop index - 1
        step(function() if index == drinkAt then use(item or "water") end end)
    end
end
char.job = "ac_cleaner"
assert(Inv.addItem(Inv.playerId(1), "water", 5)) -- enough bottles for every case below
-- success: after the first unit, before the second
give("water_break")
local bank = Money.get(1).bank
acRun(first + 1)
assert(Money.get(1).bank > bank, "the route paid")
assert(isDone("water_break"), "a drink on the roof between the first and the last unit")

-- success: right before the last unit is done (after the second)
give("water_break")
acRun(lastUnit)
assert(isDone("water_break"), "before the last unit")

-- failure: on the roof, before the first unit is done
give("water_break")
acRun(first)
assert(not isDone("water_break"), "before the first unit")

-- failure: after the last unit (before the lift down)
give("water_break")
acRun(lastUnit + 1)
assert(not isDone("water_break"), "after the last unit")

-- failure: food is not a drink
give("water_break")
acRun(first + 1, "burrito")
assert(not isDone("water_break"), "a burrito is not a water break")

-- failure: the drink in an abandoned route does not carry over to the next one
give("water_break")
startRun("ac_cleaner")
step(); step(); use("water")
actions["jobs.cancel"](1)
assert(not Runs.snapshot(1).active)
acRun(nil)
assert(not isDone("water_break"), "no drink in this route")

-- ── nothing paid twice, nothing left running ──
assert(not Runs.snapshot(1).active and not W.isActive(1))
print("dailies_flow_jobs_test: ok")
