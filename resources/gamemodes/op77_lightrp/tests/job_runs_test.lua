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
        queries = q
        assert(#q == 3 and q[1].query:find("lightrp_wallets") and q[2].query:find("lightrp_job_run_receipts") and q[3].query:find("lightrp_transactions"))
        if yieldDb then coroutine.yield("sql") end
        if failDb or receipts[q[2].values[1]] then return false, "database_error" end
        receipts[q[2].values[1]] = true; paid = paid + 1; return true
    end,
}
LightRP = { db = Db, nowMs = function() return now end, log = noop, state = noop, stateProvider = noop, command = noop, result = noop,
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
dofile("server/config/job_runs.lua"); dofile("server/modules/job_runs.lua")
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
    assert(R.finish(1, { token = w.token, status = "success", reward = 999999 }))
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

desk(); assert(R.start(1)); p.bucket = 9; R.tick(); assert(not R.snapshot(1).active, "bucket cancels")
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
print("PASS: AC route only; item jobs cannot issue legacy orders, lifts, exact atomic payouts/receipts, no skip/replay/early/range exploit, SQL rollback/retry, in-flight locks/disconnect, cancellation/death/bucket/expiry/DB/desk guards, unconditional safe exit")
