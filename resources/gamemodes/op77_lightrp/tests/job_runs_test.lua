-- Lua 5.4, deterministic network/life/SQL boundary, actual jobs + economy + runs.
dofile("shared/events.lua"); dofile("shared/config.lua"); dofile("shared/jobs.lua"); dofile("shared/items.lua")
json = { encode = function() return "{}" end, decode = function() return {} end }
local noop = function() end
local now, sequence, paid, failDb, yieldDb = 1000, 0, 0, false, false
local p = { x = -645.578979, y = -412.519470, z = 8.196312, bucket = 0 }
local alive, char = true, { identifier = "test", key = "one", status = "active", job = "sanitation", jobGrade = 0 }
local handlers, actions, modules, threads, notices = {}, {}, {}, {}, {}
local lastWork, queries, teleportTo
local receipts = {}
local Db = { ready = true, schema = noop, query = function() return {} end, run = function() return true, 1 end,
    read = function(sql)
        if sql:find("SELECT account_number, owner_name",1,true) then return true,{{account_number="ABC-DEF",owner_name="Test",cash=20,bank=1000}} end
        return true,{}
    end,
    single = function(sql)
        if sql == "SELECT UUID() AS id" then sequence = sequence + 1; return { id = "order-" .. sequence } end
        return { account_number = "ABC-DEF", owner_name = "Test", cash = 20, bank = 1000 }
    end,
    transaction = function(q)
        if q[1].query:find("lightrp_cash_migrations",1,true) then return true end
        if q[1].query:find("lightrp_inventories",1,true) then return true end -- an order into / out of the bag
        queries = q
        assert(#q == 3 and q[1].query:find("lightrp_wallets") and q[2].query:find("lightrp_job_run_receipts") and q[3].query:find("lightrp_transactions"))
        if yieldDb then coroutine.yield("sql") end
        if failDb or receipts[q[2].values[1]] then return false, "database_error" end
        receipts[q[2].values[1]] = true; paid = paid + 1; return true
    end,
}
local providers = {}
LightRP = { db = Db, nowMs = function() return now end, log = noop, state = noop, stateProvider = function(name, f) providers[name] = f end, command = noop, result = noop,
    notice = function(_, notice) notices[#notices + 1] = notice end,
    module = function(name, value) LightRP[name] = value; modules[#modules + 1] = value; return value end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if m[hook] then m[hook](...) end end end,
    characters = { switching = {}, get = function() return char end, displayName = function() return "Test" end },
    action = function(name, fn) actions[name] = fn end, interaction = noop,
    nearInteraction = function(_, def, slack)
        local t = def.position
        return (p.x-t.x)^2 + (p.y-t.y)^2 + (p.z-t.z)^2 <= (def.radius + (slack or 0))^2
    end,
}
Open77 = { players = { position = function() return p end, getLifeState = function() return { phase = alive and "alive" or "dead" } end,
    teleport = function(_, dest) teleportTo = dest; return { await = function() p = dest; return true end } end }, vehicles = {} }
CreateThread = function(fn) threads[#threads+1] = fn end
Wait = noop; GetPlayers = function() return { 1 } end; GetPlayerName = function() return "Test" end
RegisterNetEvent = function(name, fn) handlers[name] = fn end
TriggerClientEvent = function(event, _, data) if event == LightRpEvents.net.jobWork then lastWork = data end end
AddEventHandler = noop
dofile("server/modules/inventory.lua"); dofile("server/modules/economy.lua"); dofile("server/modules/jobs.lua")
LightRP.inventory.onCharacterLoaded(1, char)
LightRP.money.onCharacterLoaded(1, char)
dofile("server/config/economy.lua"); dofile("server/config/job_runs.lua"); dofile("server/config/delivery.lua")
-- pinned: this test checks the mechanics at the pre-2026-11-05 numbers (balance lives in config)
LightRpJobRuns.cancelCooldownMs, LightRpJobRuns.routes.ac_cleaner.cooldownMs, LightRpJobRuns.routes.ac_cleaner.reward = 0, nil, 400
dofile("server/modules/job_runs.lua")
local R, C, Money = LightRP.jobRuns, LightRpJobRuns, LightRP.money
-- The two item activities must never issue old mission rewards.
assert(C.routes.sanitation == nil and C.routes.scrapper == nil)
for _,job in ipairs({"sanitation","scrapper"}) do char.job=job;assert(not R.start(1)) end
local routePositions = {}
local function desk() p = { x = -645.578979, y = -412.519470, z = 8.196312, bucket = 0 }; now = now + 16000 end
local function begin()
    local s = R.snapshot(1); now = now + 600; p = s.objective.position
    assert(R.begin(1, { id = s.id, index = s.index }))
    return s, lastWork
end
local function finish()
    local s, w = begin()
    if s.objective.kind == "lift" then threads[#threads](); return end
    now = now + w.durationMs + 20
    local ok = R.finish(1, { token = w.token, status = "success", reward = 999999 })
    if not ok then error("finish refused at " .. s.objective.kind .. " " .. s.index .. ": " .. tostring(notices[#notices] and notices[#notices].body)) end
end
for _, job in ipairs({ "ac_cleaner" }) do
    desk(); char.job = job
    local before = Money.get(1).bank
    assert(R.start(1)); assert(not R.start(1), "only one work order")
    assert(R.preview(job).stops == 3)
    while R.snapshot(1).active do
        local current = R.snapshot(1)
        if routePositions[job] and current.objective.kind == "return" then
            desk()
            assert(not R.begin(1, { id = current.id, index = current.index }), job .. " must unload at its own depot")
            assert(Money.get(1).bank == before, "no payment at the old dispatch")
            local otherJob = job == "sanitation" and "scrapper" or "sanitation"
            p = routePositions[otherJob][4]; now = now + 600
            assert(not R.begin(1, { id = current.id, index = current.index }), "cannot unload at another job's depot")
        end
        finish()
    end
    assert(Money.get(1).bank == before + C.routes[job].reward, "exact server reward")
    assert(queries[3].values[3] == "job_run" and queries[2].values[4] == job)
end
assert(paid == 1 and teleportTo == C.lifts.market.ground)
desk(); char.job = "ac_cleaner"; assert(R.start(1)); finish() -- pass the entrance lift before timed work
local s, w = begin()
assert(not R.finish(1, { token = w.token, status = "success" }), "early completion denied")
assert(R.snapshot(1).index == 2)
s, w = begin(); now = now + w.durationMs
p = { x = 1000, y = 0, z = 0 }; R.tick()
assert(lastWork.cancel and not R.finish(1, { token = w.token, status = "success" }), "leaving cancels, old token invalid")
s, w = begin(); now = now + w.durationMs
assert(not R.finish(1, { token = w.token, status = "cancelled" }) and R.snapshot(1).index == 2)
s, w = begin(); assert(not R.finish(1, { token = "forged", status = "success" }))
now = now + w.durationMs; assert(R.finish(1, { token = w.token, status = "success" }))
assert(not R.finish(1, { token = w.token, status = "success" }), "replayed completion")
assert(not R.begin(1, { id = s.id, index = 4 }), "cannot skip steps")
while R.snapshot(1).index < 6 do finish() end
local bank = Money.get(1).bank
s, w = begin(); now = now + w.durationMs; failDb = true
assert(not R.finish(1, { token = w.token, status = "success" }))
assert(R.snapshot(1).active and R.snapshot(1).index == 6 and Money.get(1).bank == bank, "failed SQL retains final step and wallet")
failDb = false; s, w = begin(); now = now + w.durationMs; yieldDb = true
local co = coroutine.create(function() assert(R.finish(1, { token = w.token, status = "success" })) end)
assert(coroutine.resume(co) and coroutine.status(co) == "suspended")
assert(R.isBusy(1) and not R.cancel(1) and not R.start(1))
assert(not LightRP.jobs.setJob(1, "scrapper", 0), "job switch blocked during payment")
assert(not R.finish(1, { token = w.token, status = "success" }))
assert(coroutine.resume(co) and coroutine.status(co) == "dead")
yieldDb = false; assert(Money.get(1).bank == bank + C.routes.ac_cleaner.reward and paid == 2)

desk(); assert(R.start(1)); p.bucket = 9; R.tick(); assert(R.snapshot(1).active, "a short trip out of the public world keeps the run")
local back = p; p = nil; now = now + 1000; R.tick(); assert(R.snapshot(1).active, "a loading screen (no position) keeps the run")
p = back; p.bucket = 0; R.tick(); p.bucket = 9; R.tick(); now = now + C.awayGraceMs - 1; R.tick()
assert(R.snapshot(1).active, "the grace restarts once back in the public world")
now = now + 2; R.tick(); assert(not R.snapshot(1).active, "staying out of the public world cancels")
desk(); assert(R.start(1)); alive = false; R.onLifeState(1, "dead"); assert(not R.snapshot(1).active); alive = true
desk(); assert(R.start(1)); assert(LightRP.jobs.setJob(1, "scrapper", 0)); assert(not R.snapshot(1).active, "job switch cancels")
desk(); char.job="ac_cleaner"; assert(R.start(1)); now = now + C.lifetimeMs + 1; R.tick(); assert(not R.snapshot(1).active, "expiry")
desk(); assert(R.start(1)); R.onDisconnected(1); assert(not R.snapshot(1).active, "disconnect")
desk(); Db.ready = false; assert(not R.start(1)); Db.ready = true
p.bucket = 3; assert(not R.start(1)); p.bucket = 0
alive = false; assert(not R.start(1)); alive = true
LightRP.characters.switching[1] = true; assert(not R.start(1)); LightRP.characters.switching[1] = nil
char.job = "taxi"; assert(not R.start(1), "legacy job cannot issue new routes")
char.job = "ac_cleaner"; desk(); p.x = p.x + 100; assert(not R.start(1), "desk proximity")

-- A committed detached wallet is paid exactly once and does not revive a run.
desk(); assert(R.start(1)); while R.snapshot(1).index < 6 do finish() end
s, w = begin(); now = now + w.durationMs; yieldDb = true
co = coroutine.create(function() R.finish(1, { token = w.token, status = "success" }) end)
assert(coroutine.resume(co)); R.onDisconnected(1); Money.onDisconnected(1)
assert(coroutine.resume(co) and coroutine.status(co) == "dead" and paid == 3 and not R.snapshot(1).active)
-- Roof exit survives job loss and disconnection; no run required.
LightRP.staff = { moveTo = function(_, dest, _, cb) p = dest; cb(true) end }
p = C.lifts.market.roof; R.onInteract(1, "jobexit.market"); assert(p == C.lifts.market.ground)
-- The courier: a route drawn per order, the orders carried in the bag, paid by distance.
math.randomseed(7)
LightRP.money.onCharacterLoaded(1, char) -- the disconnect above unloaded the wallet
yieldDb = false -- the detached-wallet case above leaves the SQL boundary yielding
local D, Inv = LightRpDelivery, LightRP.inventory
local invId = Inv.playerId(1)
local function orders() return Inv.count(invId, D.item) end
char.job = "delivery"
local preview = R.preview("delivery")
assert(preview.variable and preview.reward == D.pay.min and preview.orders.min == D.orders.min and preview.orders.max == D.orders.max)
assert(preview.remote == true and R.preview("ac_cleaner").remote == false, "only the courier's dispatch reaches the player menu")
-- Remote dispatch (F1 → My job → Start a run): anywhere for the courier, never for AC.
desk(); p = { x = 2000, y = 1500, z = 10, bucket = 0 }
assert(not R.start(1), "away from a desk without the menu")
assert(R.start(1, true) and R.snapshot(1).active, "the menu collects a courier run anywhere")
assert(R.cancel(1)); now = now + 16000
char.job = "ac_cleaner"; assert(not R.start(1, true), "AC orders stay at the desk"); char.job = "delivery"
for round = 1, 6 do
    desk(); local origin = { x = p.x, y = p.y, z = p.z }
    local before, receiptsBefore = Money.get(1).bank, paid
    assert(R.start(1)); assert(not R.start(1), "one run at a time")
    local first = R.snapshot(1)
    local n = first.orders
    assert(n >= D.orders.min and n <= D.orders.max and first.total == 2 * n, "n pickups then n drop-offs")
    assert(first.objective.kind == "pickup" and first.carried == 0)
    -- the pay is the configured formula over the drawn route, from the office
    local length, last = 0, origin
    local seen = {}
    while R.snapshot(1).active do
        local s = R.snapshot(1)
        assert(s.objective.kind == (s.index <= n and "pickup" or "dropoff"), "all pickups come first")
        local here = s.objective.position
        length = length + math.sqrt((here.x - last.x)^2 + (here.y - last.y)^2 + (here.z - last.z)^2); last = here
        if s.index > 1 then assert(seen[s.index - 1] ~= s.objective.label or #D.pickups == 1, "never the same point twice in a row") end
        seen[s.index] = s.objective.label
        local carried = orders()
        finish()
        if s.index <= n then assert(orders() == carried + 1, "a pickup puts an order in the bag")
        else assert(orders() == carried - 1, "a drop-off hands one over") end
    end
    local pay = math.floor(D.pay.base + D.pay.perStop * 2 * n + D.pay.perKm * length / 1000 + 0.5)
    pay = math.max(D.pay.min, math.min(D.pay.max, pay))
    assert(Money.get(1).bank == before + pay and paid == receiptsBefore + 1, "paid once, by distance, on the last drop-off")
    assert(queries[2].values[4] == "delivery" and queries[2].values[5] == pay)
    assert(orders() == 0, "nothing left in the bag")
end
-- Bag full at a pickup: refused before the progress bar, nothing moves.
desk(); assert(R.start(1))
local s0 = R.snapshot(1)
local inv = Inv.player(1); local saved = inv.items; inv.items = {}
for slot = 1, inv.slots do inv.items[slot] = { name = "water", count = LightRpItems.water.stack } end
p = s0.objective.position; now = now + 600
assert(not R.begin(1, { id = s0.id, index = 1 }) and R.snapshot(1).index == 1 and not R.snapshot(1).working, "a full bag cannot take the order")
inv.items = saved
finish(); assert(orders() == 1)
-- The order is gone (dropped, given away): the drop-off refuses, the run can be abandoned.
while R.snapshot(1).objective.kind == "pickup" do finish() end
local carried = orders(); assert(Inv.removeItem(invId, D.item, carried))
local sd = R.snapshot(1); p = sd.objective.position; now = now + 600
assert(not R.begin(1, { id = sd.id, index = sd.index }), "no order to hand over")
assert(Inv.addItem(invId, D.item, carried))
-- Cancelling takes the undelivered orders back.
assert(R.cancel(1) and orders() == 0, "cancel removes the orders")
-- Orders left by a run that ended elsewhere (a restart) go away on the next start and on joining.
assert(Inv.addItem(invId, D.item, 2)); desk(); assert(R.start(1) and orders() == 0, "stale orders cleared at start")
assert(R.cancel(1)); assert(Inv.addItem(invId, D.item, 1)); R.onGameplayReady(1); assert(orders() == 0, "stale orders cleared on joining")
-- A job switch cancels and takes the orders back.
desk(); assert(R.start(1)); finish(); assert(orders() == 1)
assert(LightRP.jobs.setJob(1, "scrapper", 0)); assert(not R.snapshot(1).active and orders() == 0, "job switch takes the orders back")
-- The desk offers the courier instead of AC Cleaner.
local offered = LightRpConfig.jobs.centers[1].jobs
assert(offered[3] == "delivery" and #offered == 3, "the courier replaced AC Cleaner at the desk")
-- Each grade adds LightRpEconomy.jobs.gradeBonus to the order's pay (grade 2: +20 %).
char.job = "ac_cleaner"; char.jobGrade = 2; desk()
local gradedBefore = Money.get(1).bank
assert(R.start(1)); while R.snapshot(1).active do finish() end
local graded = math.floor(C.routes.ac_cleaner.reward * (1 + 2 * LightRpEconomy.jobs.gradeBonus) + 0.5)
assert(graded > C.routes.ac_cleaner.reward and Money.get(1).bank == gradedBefore + graded, "a higher grade earns more per order")
assert(R.preview("ac_cleaner").reward == C.routes.ac_cleaner.reward, "the shared preview shows the base pay")
char.jobGrade = 0

-- The page's job state carries the job guide and how the job is worked (F1 → My job).
char.job = "delivery"; char.jobGrade = 0
local js = providers.job(1)
assert(#js.guide >= 5 and js.guide[1].demo == "courier-route" and js.run.remote and js.run.orders and js.art.image == "img/jobs/delivery.webp")
char.job = "ac_cleaner"; js = providers.job(1); assert(js.run and not js.run.remote and #js.guide > 0)
for name, def in pairs(LightRpJobs) do
    for i, page in ipairs(def.guide or {}) do
        assert(type(page.title) == "string" and type(page.body) == "string" and type(page.demo) == "string", name .. " guide page " .. i)
    end
end
print("PASS: job guide in the job state, remote dispatch (courier only); courier routes drawn per order (pickups then drop-offs, never twice in a row), orders carried in the bag, pay by distance on the last drop-off, full bag / lost order / cancel / stale / job switch; AC route only; item jobs cannot issue legacy orders, lifts, exact atomic payouts/receipts, no skip/replay/early/range exploit, SQL rollback/retry, in-flight locks/disconnect, cancellation/death/away grace/expiry/DB/desk guards, unconditional safe exit")
