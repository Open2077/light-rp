-- Jobs worked together (server/modules/job_crew.lua, job_runs.lua's Big Contract).
-- Part 1, the crew bonus and the premium against a stubbed host: who counts as a
-- partner (crewmate, another account, same job, real work in the last minutes,
-- close at a fixed site), practice sites, the daily cap per account, a refused
-- payment, together / apart / abandoned halves. Part 2, the real job_runs.lua:
-- who can take the Big Contract, the split of the orders, both halves worked to
-- the last drop-off and the premium paid once to each courier.
local clock = 0
local unixNow = 20395 * 86400 + 3600
_G.CreateThread = function() end
_G.Wait = function() end

-- ════════════════════════════ Part 1 ════════════════════════════
local pos, chars, crews = {}, {}, {}
local paid, notices = {}, {}
local payFails = false
_G.Open77 = { time = { unix = function() return unixNow end },
    players = { position = function(id) local p = pos[id]; return p and { x = p.x, y = p.y, z = p.z or 0, bucket = p.bucket or 0 } end } }
_G.LightRpJobs = { sanitation = { label = "Sanitation" }, scrapper = { label = "Scrapper" }, delivery = { label = "Courier" }, ac_cleaner = { label = "AC Cleaner" } }
local modules = {}
_G.LightRP = {
    nowMs = function() return clock end, log = function() end,
    module = function(name, def) def.name = name; modules[#modules + 1] = def; LightRP[name] = def; return def end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if type(m[hook]) == "function" then m[hook](...) end end end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, body = n.body } end,
    characters = { get = function(id) return chars[id] end, displayName = function(id) return chars[id] and chars[id].name or "?" end },
    parties = { of = function(id) return crews[id] end },
    money = {
        addBank = function(id, amount, kind, note, counterparty)
            if payFails then return false, "busy" end
            paid[#paid + 1] = { id = id, amount = amount, kind = kind, note = note, counterparty = counterparty }
            return true
        end,
        format = function(n) return "$" .. n end,
    },
}
dofile("server/config/economy.lua")
dofile("server/modules/job_crew.lua")
local J, CB, BC = LightRP.jobCrew, LightRpEconomy.jobs.crewBonus, LightRpEconomy.jobs.bigContract
assert(CB.rate == 0.15 and CB.dailyCap == 2000 and BC.bonus == 0.20 and BC.togetherBonus == 0.35)

local function join(id, account, name, x) chars[id] = { status = "active", identifier = account, key = "c1", name = name }; pos[id] = { x = x or 0, y = 0, z = 0, bucket = 0 } end
local function crewUp(...) local c = { id = "crew1", leader = 1, members = { ... } }; for _, id in ipairs(c.members) do crews[id] = c end end
local function lastPay() return paid[#paid] end
local function sell(id, job, total, practice) J.onJobWorkCompleted(id, job, "sell", { count = 10, total = total, practice = practice }) end
local function collect(id, job, practice) J.onJobWorkCompleted(id, job, "collect", { point = "site", practice = practice }) end
join(1, "acc1", "Kaito"); join(2, "acc2", "Rosa", 10)

-- ── a sale at a fixed site: the crewmate who worked there with you ──
collect(2, "sanitation"); sell(1, "sanitation", 1000)
assert(#paid == 0, "not in a crew")
crewUp(1, 2)
sell(1, "sanitation", 1000)
local p = lastPay()
assert(p and p.id == 1 and p.amount == 150 and p.kind == "crew_bonus" and p.note == "Crew bonus · Sanitation" and p.counterparty == "Rosa", "+15 %")
assert(notices[#notices].title == "CREW BONUS +15%" and notices[#notices].body == "+$150 for working with Rosa.")
-- what does not count
local n = #paid
collect(2, "scrapper"); sell(1, "sanitation", 1000); assert(#paid == n, "another job")
collect(2, "sanitation", true); clock = clock + 6 * 60000; collect(2, "sanitation", true); sell(1, "sanitation", 1000)
assert(#paid == n, "a practice site is not work, and the real work is over 5 minutes old")
collect(2, "sanitation"); pos[2].x = 61; sell(1, "sanitation", 1000); assert(#paid == n, "more than 60 m away")
pos[2].x, pos[2].bucket = 10, 4; sell(1, "sanitation", 1000); assert(#paid == n, "another bucket")
pos[2].bucket = 0
sell(1, "sanitation", 1000, true); assert(#paid == n, "a practice sale earns no bonus")
sell(1, "sanitation", 0); assert(#paid == n, "nothing sold, nothing added")
join(3, "acc1", "Kaito alt", 5); crewUp(1, 3); collect(3, "sanitation"); sell(1, "sanitation", 1000)
assert(#paid == n, "your own alt is not a crewmate")
crewUp(1, 2, 3)
sell(1, "sanitation", 1000); assert(#paid == n + 1 and lastPay().counterparty == "Rosa", "the real partner still counts")
-- a character switch forgets the work
J.onCharacterSwitched(2); sell(1, "sanitation", 1000); assert(#paid == n + 1, "switched character")
collect(2, "sanitation"); J.onDisconnected(2); sell(1, "sanitation", 1000); assert(#paid == n + 1, "disconnected")

-- ── a work order: anywhere on the route ──
J.onJobRunStep(2, { job = "ac_cleaner" })
pos[2].x = 5000
J.onJobRunCompleted(1, { job = "ac_cleaner", route = { reward = 600 } })
assert(lastPay().amount == 90 and lastPay().note == "Crew bonus · AC Cleaner", "routes have no range")
local m = #paid
J.onJobRunCompleted(1, { job = "delivery", route = { reward = 600 } }); assert(#paid == m, "partner on another job")

-- ── the daily cap, per account and UTC day ──
-- paid so far today: 150 + 150 + 90 = 390
collect(2, "sanitation"); pos[2].x = 10
sell(1, "sanitation", 10000); assert(lastPay().amount == 1500)
sell(1, "sanitation", 10000); assert(lastPay().amount == 110, "capped at 2,000 a day")
m = #paid
sell(1, "sanitation", 10000); assert(#paid == m, "nothing past the cap")
collect(1, "sanitation"); sell(2, "sanitation", 1000); assert(lastPay().id == 2 and lastPay().amount == 150, "the cap is per account")
unixNow = unixNow + 86400
collect(2, "sanitation"); sell(1, "sanitation", 1000); assert(lastPay().id == 1 and lastPay().amount == 150, "a new UTC day")
-- a refused payment uses nothing of the cap
payFails = true; m = #paid
sell(1, "sanitation", 10000); assert(#paid == m)
payFails = false
sell(1, "sanitation", 20000); assert(lastPay().amount == 1850, "2,000 - 150 left")

-- ── the Big Contract premium ──
unixNow = unixNow + 86400
clock = clock + 3600000
local function half(id, partner, reward, duoId) return { job = "delivery", route = { reward = reward }, duo = { id = duoId or "d1", partner = partner, partnerName = chars[partner].name } } end
m = #paid
J.onJobRunCompleted(1, half(1, 2, 800))
assert(#paid == m and notices[#notices].title == "BIG CONTRACT" and notices[#notices].body:find("When Rosa lands theirs", 1, true), "first half: waiting")
clock = clock + 60000
J.onJobRunCompleted(2, half(2, 1, 700))
assert(#paid == m + 2, "both paid, no crew bonus on top")
local byId = {}
for i = m + 1, #paid do byId[paid[i].id] = paid[i] end
assert(byId[1].amount == 280 and byId[2].amount == 245 and byId[1].note == "Big Contract · served together" and byId[1].counterparty == "Rosa" and byId[2].counterparty == "Kaito", "35 % within 2 minutes")
-- apart: 20 %
m = #paid
J.onJobRunCompleted(1, half(1, 2, 800, "d2")); clock = clock + 121000; J.onJobRunCompleted(2, half(2, 1, 700, "d2"))
byId = {}
for i = m + 1, #paid do byId[paid[i].id] = paid[i] end
assert(#paid == m + 2 and byId[1].amount == 160 and byId[2].amount == 140 and byId[1].note == "Big Contract", "20 % apart")
-- abandoned: the half that landed keeps its run pay, no premium; a stale half is forgotten
m = #paid
J.onJobRunCompleted(1, half(1, 2, 800, "d3"))
clock = clock + 3 * 3600000 + 1
J.onJobRunCompleted(2, half(2, 1, 700, "d4"))
assert(#paid == m, "no premium for an abandoned contract")
J.onJobRunCompleted(1, half(1, 2, 800, "d3"))
assert(#paid == m, "after 3 hours the old half is gone: this one waits again")
-- a courier who switched character between the halves gets nothing
m = #paid
J.onJobRunCompleted(1, half(1, 2, 800, "d5"))
chars[1] = { status = "active", identifier = "acc1", key = "c2", name = "Kaito" }
chars[1].identifier = "acc9"
J.onJobRunCompleted(2, half(2, 1, 700, "d5"))
assert(#paid == m + 1 and lastPay().id == 2, "only the courier still on the contract's account")
chars[1] = { status = "active", identifier = "acc1", key = "c1", name = "Kaito" }
-- switched off
BC.enabled = false; m = #paid
J.onJobRunCompleted(1, half(1, 2, 800, "d6")); J.onJobRunCompleted(2, half(2, 1, 700, "d6"))
assert(#paid == m, "Big Contract off")
BC.enabled = true
CB.rate = 0; m = #paid
collect(2, "sanitation"); sell(1, "sanitation", 1000); assert(#paid == m, "rate 0 turns the crew bonus off")
CB.rate = 0.15

-- ════════════════════════════ Part 2 ════════════════════════════
dofile("shared/events.lua"); dofile("shared/config.lua"); dofile("shared/jobs.lua")
local now, uuid = 1000, 0
local lastWork, bank, bag, premium, started = {}, {}, {}, {}, {}
local jobs = {}
pos, chars, crews = {}, {}, {}
modules = {}
local handlers = {}
local Db = { ready = true, schema = function() end, single = function(sql)
    if sql == "SELECT UUID() AS id" then uuid = uuid + 1; return { id = "order-" .. uuid } end
end, run = function() return true end, read = function() return true, {} end }
_G.LightRP = {
    db = Db, nowMs = function() return now end, log = function() end, state = function() end, stateProvider = function() end,
    command = function() end, result = function() end, interaction = function() end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, body = n.body } end,
    module = function(name, def) def.name = name; modules[#modules + 1] = def; LightRP[name] = def; return def end,
    eachModule = function(hook, ...) for _, m2 in ipairs(modules) do if type(m2[hook]) == "function" then m2[hook](...) end end end,
    action = function(name, fn) handlers[name] = fn end,
    characters = { switching = {}, get = function(id) return chars[id] end, displayName = function(id) return chars[id] and chars[id].name or "?" end },
    jobs = { get = function(id) return { name = jobs[id] or "unemployed", grade = 0 } end },
    parties = { of = function(id) return crews[id] end },
    nearInteraction = function(id, def, slack)
        local p2, t = pos[id], def.position
        return p2 ~= nil and (p2.x - t.x) ^ 2 + (p2.y - t.y) ^ 2 + (p2.z - t.z) ^ 2 <= (def.radius + (slack or 0)) ^ 2
    end,
    inventory = {
        playerId = function(id) return "inv" .. id end,
        get = function(inv) bag[inv] = bag[inv] or {}; return bag[inv] end,
        canHold = function() return true end,
        count = function(inv, item) return (bag[inv] or {})[item] or 0 end,
        addItem = function(inv, item, k) bag[inv] = bag[inv] or {}; bag[inv][item] = (bag[inv][item] or 0) + k; return true end,
        removeItem = function(inv, item, k) bag[inv] = bag[inv] or {}; if (bag[inv][item] or 0) < k then return false, "missing" end; bag[inv][item] = bag[inv][item] - k; return true end,
    },
    money = {
        format = function(v) return "$" .. v end,
        exchange = function(id, wallet, amount, receipt, onCommit) onCommit(); bank[id] = (bank[id] or 0) + amount; return true end,
        addBank = function(id, amount, kind, note) premium[#premium + 1] = { id = id, amount = amount, kind = kind, note = note }; return true end,
    },
}
_G.Open77 = { time = { unix = function() return unixNow end }, vehicles = {},
    players = { position = function(id) local p2 = pos[id]; return p2 and { x = p2.x, y = p2.y, z = p2.z, bucket = p2.bucket or 0 } end,
        getLifeState = function() return { phase = "alive" } end } }
_G.GetPlayers = function() return { "1", "2" } end
_G.RegisterNetEvent = function() end
_G.AddEventHandler = function() end
_G.TriggerClientEvent = function(event, target, data) if event == LightRpEvents.net.jobWork then lastWork[target] = data end end
dofile("server/config/economy.lua"); dofile("server/config/job_runs.lua"); dofile("server/config/delivery.lua")
dofile("server/modules/job_runs.lua")
dofile("server/modules/job_crew.lua")
LightRP.module("spy", { onJobRunStarted = function(id, run) started[#started + 1] = { id = id, run = run } end })
local R, D = LightRP.jobRuns, LightRpDelivery
local desk = LightRpConfig.jobs.centers[1].position
local function at(id, dx) pos[id] = { x = desk.x + (dx or 0), y = desk.y, z = desk.z, bucket = 0 } end
chars[1] = { status = "active", identifier = "acc1", key = "c1", name = "Kaito" }
chars[2] = { status = "active", identifier = "acc2", key = "c1", name = "Rosa" }
jobs[1], jobs[2] = "delivery", "delivery"
at(1); at(2, 2)
math.randomseed(11)

assert(R.preview("delivery").duo == true, "the desk offers the Big Contract")
local ok, why = R.start(1, false, true)
assert(not ok and why:find("needs a crewmate who is also a Courier", 1, true), why)
crews[1] = { id = "c", members = { 1, 2 } }; crews[2] = crews[1]
jobs[2] = "sanitation"; ok, why = R.startDuo(1); assert(not ok and why:find("needs a crewmate", 1, true), "partner on another job")
jobs[2] = "delivery"; at(2, 31); ok = R.startDuo(1); assert(not ok, "partner more than 30 m away")
at(2, 2); chars[2].identifier = "acc1"; ok = R.startDuo(1); assert(not ok, "your own alt is not a partner")
chars[2].identifier = "acc2"
jobs[1] = "sanitation"; ok, why = R.startDuo(1); assert(not ok and why == "The Big Contract is for couriers.")
jobs[1] = "delivery"; at(1, 10); ok, why = R.startDuo(1); assert(not ok and why:find("Job Center desk", 1, true), "asked at the desk")
at(1)
LightRpEconomy.jobs.bigContract.enabled = false
ok, why = R.startDuo(1); assert(not ok and why == "The Big Contract is not offered right now.")
assert(R.preview("delivery").duo == nil)
LightRpEconomy.jobs.bigContract.enabled = true
Db.ready = false; ok = R.startDuo(1); assert(not ok, "no database, no contract"); Db.ready = true

-- accepted: one draw, two halves
ok, why = R.start(1, false, true)
assert(ok and why:find("Big Contract accepted", 1, true), why)
local s1, s2 = R.snapshot(1), R.snapshot(2)
assert(s1.active and s2.active and s1.label == "Big Contract" and s2.label == "Big Contract")
local total = s1.orders + s2.orders
assert(total >= BC.orders.min and total <= BC.orders.max and math.abs(s1.orders - s2.orders) <= 1, "5 or 6 orders split in two")
assert(s1.total == 2 * s1.orders and s2.total == 2 * s2.orders, "each half: its pickups, then its drop-offs")
assert(s1.id ~= s2.id, "two work orders")
assert(s1.duo and s2.duo and s1.duo.half == "A" and s2.duo.half == "B" and s1.duo.partner ~= nil, "the work order card names the half and the partner")
assert(#started == 2 and started[1].run.duo.partner == 2 and started[2].run.duo.partner == 1 and started[1].run.duo.id == started[2].run.duo.id, "one contract, two halves")
assert(not R.start(2), "the partner already has a run")
ok = R.startDuo(1); assert(not ok, "one at a time")

-- both halves worked to the last drop-off
local function work(id)
    while R.snapshot(id).active do
        local s = R.snapshot(id)
        pos[id] = { x = s.objective.position.x, y = s.objective.position.y, z = s.objective.position.z, bucket = 0 }
        now = now + 600
        assert(R.begin(id, { id = s.id, index = s.index }), "begin " .. s.objective.kind)
        local w = lastWork[id]
        now = now + w.durationMs + 20
        assert(R.finish(id, { token = w.token, status = "success" }), "finish " .. s.objective.kind)
    end
end
local r1, r2 = s1.reward, s2.reward
work(1)
assert(bank[1] == r1 and #premium == 0, "first half paid as a run, the premium waits")
work(2)
assert(bank[2] == r2, "second half paid as a run")
assert(#premium == 2, "then the premium, once each")
local got = {}
for _, x in ipairs(premium) do got[x.id] = x end
local rate = BC.togetherBonus
assert(got[1].amount == math.floor(r1 * rate + 0.5) and got[2].amount == math.floor(r2 * rate + 0.5) and got[1].kind == "crew_bonus", "served together: +35 %")
assert(bag.inv1[D.item] == 0 and bag.inv2[D.item] == 0, "every order delivered")
print("job_crew_test: ok")
