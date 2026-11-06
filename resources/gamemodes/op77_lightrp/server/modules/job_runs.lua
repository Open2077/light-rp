local lightrpEvery = LightRP.every or function(ms, fn) while true do Wait(tonumber(ms) or 1000); fn() end end -- framework.lua (tests: the plain loop, in the calling thread)
local expireFlags, expireFlag = LightRP.expireFlags or function() end, LightRP.expireFlag or function() end -- framework.lua
-- Private, server-authoritative work orders. The client reports only an attempt
-- token and its outcome: it cannot select locations, durations or rewards.
local C, E, Db = LightRpJobRuns, LightRpEvents, LightRP.db
local Runs = LightRP.module("jobRuns", {})
local runs, starting, cooldown = {}, {}, {}
local accessBusy, lastBegin = {}, {}
local push
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_job_run_receipts (
    run_id VARCHAR(64) NOT NULL PRIMARY KEY, identifier VARCHAR(128) NOT NULL,
    character_key VARCHAR(64) NOT NULL, job VARCHAR(32) NOT NULL,
    amount BIGINT NOT NULL, completed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local function identity(id)
    local c = LightRP.characters.get(id)
    return c and c.status == "active" and c.identifier and (c.identifier .. "#" .. c.key), c
end
local function eligible(id)
    local owner = identity(id)
    local life, p = Open77.players.getLifeState(id), Open77.players.position(id)
    return owner and life and life.phase == "alive" and p and (p.bucket or 0) == 0
        and not (LightRP.characters.switching or {})[id]
end
local function near(id, p)
    return eligible(id) and LightRP.nearInteraction(id, { position = p, radius = C.range, bucket = 0 }, 0.4)
end
local function current(id, run)
    return runs[id] == run and identity(id) == run.owner and LightRP.jobs.get(id).name == run.job and eligible(id)
end
local function notify(id, body, kind)
    LightRP.notice(id, { kind = kind or "info", title = "Work order", body = body, durationMs = 7000 })
end
function Runs.isBusy(id) return starting[id] ~= nil or accessBusy[id] == true or (runs[id] and runs[id].busy == true) end

-- Routes drawn when the order is collected (`generator` in server/config/job_runs.lua).
local Generators = {}
local function distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end
local function copyPoint(p) return { x = p.x, y = p.y, z = p.z } end
-- n entries of a list at random: all different while the list is long enough,
-- never the same one twice in a row.
local function draw(list, n)
    local out, bag = {}, {}
    for i = 1, n do
        if #bag == 0 then for k = 1, #list do bag[k] = k end end
        local k = math.random(#bag)
        if #bag > 1 and out[i - 1] == list[bag[k]] then k = k % #bag + 1 end
        out[i] = list[bag[k]]
        table.remove(bag, k)
    end
    return out
end
-- The courier: n orders, a pickup for each, then a drop-off for each; paid by the route's length.
function Generators.delivery(base, origin)
    local D = LightRpDelivery
    if not D or #(D.pickups or {}) == 0 or #(D.dropoffs or {}) == 0 then return nil end
    local n = math.random(D.orders.min, math.max(D.orders.min, D.orders.max))
    local steps = {}
    for i, p in ipairs(draw(D.pickups, n)) do
        steps[#steps + 1] = { kind = "pickup", order = i, place = p.name, label = "Pick up · " .. p.name,
            position = copyPoint(p.position), durationMs = D.pickupMs }
    end
    for i, d in ipairs(draw(D.dropoffs, n)) do
        steps[#steps + 1] = { kind = "dropoff", order = i, place = d.name, label = "Deliver · " .. d.name,
            position = copyPoint(d.position), durationMs = D.dropoffMs }
    end
    local length, last = 0, origin
    for _, step in ipairs(steps) do length = length + distance(last, step.position); last = step.position end
    local km = length / 1000
    local pay = math.floor(D.pay.base + D.pay.perStop * #steps + D.pay.perKm * km + 0.5)
    pay = math.max(D.pay.min, math.min(D.pay.max, pay))
    return { generated = true, label = base.label, icon = base.icon, reward = pay, orders = n,
        distanceKm = math.floor(km * 10 + 0.5) / 10, steps = steps, item = D.item, lifetimeMs = D.lifetimeMs }
end
-- The Big Contract (economy.lua jobs.bigContract): one draw of n orders split
-- in two halves with different addresses, one per courier, each paid like a run.
function Generators.duo(base, origin, orders)
    local D = LightRpDelivery
    if not D or #(D.pickups or {}) == 0 or #(D.dropoffs or {}) == 0 then return nil end
    local lo = math.max(2, math.floor(tonumber(orders and orders.min) or 5))
    local n = math.random(lo, math.max(lo, math.floor(tonumber(orders and orders.max) or lo)))
    local picks, drops = draw(D.pickups, n), draw(D.dropoffs, n)
    local halves = {}
    for h = 1, 2 do
        local steps, k = {}, 0
        for i = h, n, 2 do
            k = k + 1
            steps[#steps + 1] = { kind = "pickup", order = k, place = picks[i].name, label = "Pick up · " .. picks[i].name,
                position = copyPoint(picks[i].position), durationMs = D.pickupMs }
        end
        k = 0
        for i = h, n, 2 do
            k = k + 1
            steps[#steps + 1] = { kind = "dropoff", order = k, place = drops[i].name, label = "Deliver · " .. drops[i].name,
                position = copyPoint(drops[i].position), durationMs = D.dropoffMs }
        end
        local length, last = 0, origin
        for _, step in ipairs(steps) do length = length + distance(last, step.position); last = step.position end
        local km = length / 1000
        local pay = math.floor(D.pay.base + D.pay.perStop * #steps + D.pay.perKm * km + 0.5)
        pay = math.max(D.pay.min, math.min(D.pay.max, pay))
        halves[h] = { generated = true, label = "Big Contract", icon = base.icon, reward = pay, orders = k,
            distanceKm = math.floor(km * 10 + 0.5) / 10, steps = steps, item = D.item, lifetimeMs = D.lifetimeMs }
    end
    return halves
end
Runs.generators = Generators
local function bigContract()
    local J = LightRpEconomy and LightRpEconomy.jobs
    local cfg = J and J.bigContract
    return type(cfg) == "table" and cfg.enabled ~= false and cfg or nil
end

-- The orders a run hands out (pickups) live in the bag of the character who
-- took the run: removed again when it ends without being delivered.
local function carriedItem(run) return run.route.item end
local function dropCarried(run)
    local item = carriedItem(run)
    if not item or not run.inv or not LightRP.inventory.get(run.inv) then return end
    local count = LightRP.inventory.count(run.inv, item)
    if count > 0 then LightRP.inventory.removeItem(run.inv, item, count) end
end
-- No run is ever active on joining or when a new one starts: an order still in
-- the bag is left over from a run that ended elsewhere (a restart, a crash).
local function dropStale(id, item)
    local inv = item and LightRP.inventory.playerId(id)
    if not inv then return end
    local count = LightRP.inventory.count(inv, item)
    if count > 0 then LightRP.inventory.removeItem(inv, item, count) end
end

function Runs.preview(job)
    local route = C.routes[job]
    if route and route.generator == "delivery" and LightRpDelivery then
        local D = LightRpDelivery
        return { label = route.label, reward = D.pay.min, variable = true, stops = D.orders.max * 2, duo = bigContract() ~= nil or nil,
            orders = { min = D.orders.min, max = D.orders.max }, estimate = route.estimate, description = route.description,
            remote = route.remoteDispatch == true, lifetimeMinutes = math.floor((D.lifetimeMs or C.lifetimeMs) / 60000) }
    end
    if not route or #route.steps == 0 then return nil end
    local count = 0
    for _, step in ipairs(route.steps) do if step.kind == "work" then count = count + 1 end end
    return { label = route.label, reward = route.reward, stops = count, estimate = route.estimate, description = route.description,
        remote = route.remoteDispatch == true, lifetimeMinutes = math.floor(C.lifetimeMs / 60000) }
end
-- Every stop of the route with its state, for the run tracker on the right:
-- done, now, todo. `place` is the address alone; `order` ties a delivery's
-- pickup and drop-off together.
local function stops(run)
    local list = {}
    for i, s in ipairs(run.route.steps) do
        list[i] = { kind = s.kind, label = s.label, place = s.place or s.label, order = s.order,
            state = i < run.index and "done" or i == run.index and "now" or "todo" }
    end
    return list
end
function Runs.snapshot(id)
    local run = runs[id]
    if not run then return { active = false } end
    local step = run.route.steps[run.index]
    return { active = true, id = run.id, job = run.job, label = run.route.label, reward = run.route.reward,
        jobLabel = LightRpJobs[run.job] and LightRpJobs[run.job].label or run.job,
        index = run.index, total = #run.route.steps, busy = run.busy == true,
        working = run.work ~= nil, icon = run.route.icon,
        orders = run.route.orders, carried = run.carried, distanceKm = run.route.distanceKm,
        stops = stops(run), expiresInMs = math.max(0, run.expires - LightRP.nowMs()),
        duo = run.duo and { partner = run.duo.partnerName, half = run.duo.half } or nil, -- Big Contract (job_crew.lua)
        objective = { label = step.label, place = step.place or step.label, kind = step.kind, position = step.position, radius = C.range },
        hint = step.kind == "lift" and "Use the marked service access. No climbing required."
            or step.kind == "return" and "Return to dispatch to receive your bank payment."
            or step.kind == "pickup" and "Go to the yellow marker and press E to collect the order. It needs 1 kg free in your bag."
            or step.kind == "dropoff" and (run.index == #run.route.steps and "Last delivery: press E at the marker to hand it over. The pay lands in your bank."
                or "Press E at the marker to hand the order over, then head to the next address.")
            or "Follow the yellow marker. Press E at the work point. Escape cancels the action." }
end
LightRP.stateProvider("jobRun", Runs.snapshot)
push = function(id) LightRP.state(id, { "jobRun" }) end
local function stopWork(id, run)
    if not run.work then return end
    run.work = nil
    TriggerClientEvent(E.net.jobWork, id, { cancel = true })
end
function Runs.cancel(id, reason)
    local run = runs[id]
    if Runs.isBusy(id) then return false, "Please wait for the current operation to finish." end
    if not run then return false, "You have no active work order." end
    stopWork(id, run); runs[id] = nil
    -- abandoned by the player (not expired, not a job change or a fall): no instant reroll
    if reason == nil and (tonumber(C.cancelCooldownMs) or 0) > 0 then cooldown[id] = LightRP.nowMs() + C.cancelCooldownMs end
    push(id)
    dropCarried(run)
    notify(id, reason or "Work order cancelled. No payment was issued. Service exits remain available.", "warning")
    return true, "Work order cancelled."
end
-- Each grade adds LightRpEconomy.jobs.gradeBonus to the pay (server/config/economy.lua).
local function graded(route, id)
    local per = LightRpEconomy and LightRpEconomy.jobs and tonumber(LightRpEconomy.jobs.gradeBonus) or 0
    local grade = math.max(0, tonumber(LightRP.jobs.get(id).grade) or 0)
    if per <= 0 or grade <= 0 then return route end
    local copy = {}
    for k, v in pairs(route) do copy[k] = v end
    copy.reward = math.floor(route.reward * (1 + per * grade) + 0.5)
    return copy
end
local function atDeskNear(id)
    for _, desk in ipairs(LightRpConfig.jobs.centers) do if near(id, desk.position) then return true end end
    return false
end
-- Why a player cannot take a work order now, or nil.
local function refusal(id)
    if LightRP.activities and LightRP.activities.owns(id) then return "Not during an activity or a mission." end
    if LightRP.jobWork and LightRP.jobWork.isActive(id) then return "Stop your current item work first (Escape)." end
    if Runs.isBusy(id) then return "Please wait for the current operation to finish." end
    if runs[id] then return "Finish or cancel your current work order first." end
    if not eligible(id) then return "Load an active character and return to the public world first." end
end
-- The Big Contract: the asking courier and a crewmate (another account, a courier
-- too, free, close by) each get one half; economy.lua jobs.bigContract.
function Runs.startDuo(id)
    local cfg = bigContract()
    if not cfg then return false, "The Big Contract is not offered right now." end
    local why = refusal(id)
    if why then return false, why end
    if LightRP.jobs.get(id).name ~= "delivery" then return false, "The Big Contract is for couriers." end
    if not Db.ready then return false, "The database is unavailable. Work orders cannot be paid right now." end
    if not atDeskNear(id) then return false, "The Big Contract is handed out at a Job Center desk (briefcase on the map)." end
    if (cooldown[id] or 0) > LightRP.nowMs() then return false, "Dispatch is preparing your next route. Try again in a moment." end
    local mine = LightRP.characters.get(id)
    local here = Open77.players.position(id)
    local crew = LightRP.parties and LightRP.parties.of(id)
    local partner
    for _, other in ipairs(crew and crew.members or {}) do
        local c = other ~= id and LightRP.characters.get(other)
        local there = c and Open77.players.position(other)
        if c and c.identifier ~= mine.identifier and not refusal(other) and LightRP.jobs.get(other).name == "delivery"
            and there and here and distance(here, there) <= (tonumber(cfg.range) or 30) and (cooldown[other] or 0) <= LightRP.nowMs() then
            partner = other
            break
        end
    end
    if not partner then
        return false, string.format("The Big Contract needs a crewmate who is also a Courier, free, on another account and within %d m.", math.floor(tonumber(cfg.range) or 30))
    end
    local owners = { identity(id), identity(partner) }
    local ticket = {}
    starting[id], starting[partner] = ticket, ticket
    local rowA, rowB = Db.single("SELECT UUID() AS id"), Db.single("SELECT UUID() AS id")
    local cancelled = starting[id] ~= ticket or starting[partner] ~= ticket
    starting[id], starting[partner] = nil, nil
    if cancelled then return false, "The request was cancelled." end
    if not rowA or not rowB or type(rowA.id) ~= "string" or type(rowB.id) ~= "string" then return false, "The database could not issue a work order. Please retry." end
    for i, pid in ipairs({ id, partner }) do
        if identity(pid) ~= owners[i] or refusal(pid) or LightRP.jobs.get(pid).name ~= "delivery" then
            return false, "A courier changed or left. Ask for the Big Contract again."
        end
    end
    local halves = Generators.duo(C.routes.delivery, here, cfg.orders)
    if not halves then return false, "Dispatch has no route to offer right now. Please retry later." end
    local pair = { id, partner }
    for i, pid in ipairs(pair) do
        local route = graded(halves[i], pid)
        dropStale(pid, route.item)
        local c = LightRP.characters.get(pid)
        runs[pid] = { id = i == 1 and rowA.id or rowB.id, owner = owners[i], identifier = c.identifier, key = c.key, job = "delivery",
            route = route, index = 1, serial = 0, expires = LightRP.nowMs() + (route.lifetimeMs or C.lifetimeMs),
            inv = LightRP.inventory.playerId(pid), carried = 0,
            duo = { id = rowA.id, partner = pair[3 - i], half = i == 1 and "A" or "B", partnerName = LightRP.characters.displayName(pair[3 - i]) } }
        push(pid)
        notify(pid, string.format("Big Contract with %s: your half is %d orders, %.1f km, %s on delivery. Land your last drop within %d s of theirs for the best bonus.",
            runs[pid].duo.partnerName, route.orders, route.distanceKm, LightRP.money.format(route.reward), math.floor(tonumber(cfg.togetherSeconds) or 120)))
        LightRP.eachModule("onJobRunStarted", pid, runs[pid])
    end
    return true, "Big Contract accepted. Follow your GPS; your partner has the other half."
end

-- remote: asked from the player menu rather than at a job center desk; only a
-- route with `remoteDispatch` accepts it.
function Runs.start(id, remote, duo)
    if duo then return Runs.startDuo(id) end
    if LightRP.activities and LightRP.activities.owns(id) then return false, "Not during an activity or a mission." end
    if LightRP.jobWork and LightRP.jobWork.isActive(id) then return false, "Stop your current item work first (Escape)." end
    if Runs.isBusy(id) then return false, "Please wait for the current operation to finish." end
    if runs[id] then push(id); return false, "Finish or cancel your current work order first." end
    if not eligible(id) then return false, "Load an active character and return to the public world first." end
    if not Db.ready then return false, "The database is unavailable. Work orders cannot be paid right now." end
    local job = LightRP.jobs.get(id).name
    if LightRP.jobWork and LightRP.jobWork.preview(job) then return false, "Your job is worked at its own points, no work order: player menu, My job, for the GPS of each stage." end
    local route = C.routes[job]
    if not route or (not route.generator and #route.steps == 0) then return false, "Choose an available job at the employment office first." end
    local atDesk = remote and route.remoteDispatch == true
    for _, desk in ipairs(LightRpConfig.jobs.centers) do if not atDesk and near(id, desk.position) then atDesk = true end end
    if not atDesk then return false, "This job's work orders are handed out at a Job Center desk (briefcase on the map)." end
    if (cooldown[id] or 0) > LightRP.nowMs() then return false, "Dispatch is preparing your next route. Try again in a moment." end
    local owner, char = identity(id)
    local ticket = {}; starting[id] = ticket
    local row = Db.single("SELECT UUID() AS id")
    if starting[id] ~= ticket then return false, "The request was cancelled." end
    starting[id] = nil
    if not row or type(row.id) ~= "string" then return false, "The database could not issue a work order. Please retry." end
    if identity(id) ~= owner or not eligible(id) or LightRP.jobs.get(id).name ~= job then return false, "Your character changed. Request a new work order." end
    if route.generator then
        local generate = Generators[route.generator]
        local here = Open77.players.position(id)
        route = generate and here and generate(route, here)
        if not route then return false, "Dispatch has no route to offer right now. Please retry later." end
        dropStale(id, route.item)
    end
    route = graded(route, id)
    runs[id] = { id = row.id, owner = owner, identifier = char.identifier, key = char.key, job = job,
        route = route, index = 1, serial = 0, expires = LightRP.nowMs() + (route.lifetimeMs or C.lifetimeMs),
        inv = LightRP.inventory.playerId(id), carried = 0 }
    push(id)
    notify(id, route.generated and string.format("%d orders to deliver, %.1f km: %s on completion. Follow your GPS. To abandon: player menu, My job.",
            route.orders, route.distanceKm, LightRP.money.format(route.reward))
        or "Route assigned. Follow your GPS. Payment is issued after the complete route. To abandon: player menu, My job.")
    LightRP.eachModule("onJobRunStarted", id, runs[id])
    return true, "Work order accepted. Follow the yellow marker."
end
local function advance(id, run)
    run.index = run.index + 1
    push(id)
end
function Runs.begin(id, payload)
    local now = LightRP.nowMs()
    if now - (lastBegin[id] or -1000) < 500 then return false end
    lastBegin[id] = now
    local run = runs[id]
    if type(payload) ~= "table" or not run or payload.id ~= run.id or payload.index ~= run.index then return false end
    if run.busy or run.work or not current(id, run) then return false end
    if LightRP.nowMs() > run.expires then return Runs.cancel(id, "This work order expired. Collect another at dispatch.") end
    local step = run.route.steps[run.index]
    if not near(id, step.position) then notify(id, "Move closer to the marked work point.", "warning"); return false end
    local item = carriedItem(run)
    if step.kind == "pickup" and item then
        local inv = run.inv and LightRP.inventory.get(run.inv)
        if not inv or not LightRP.inventory.canHold(inv, item, 1) then
            notify(id, "Your bag is full: make room for the order (1 kg), then press E again.", "warning"); return false
        end
    elseif step.kind == "dropoff" and item and (not run.inv or LightRP.inventory.count(run.inv, item) < 1) then
        notify(id, "You no longer carry an order to hand over. Abandon the run from the player menu, My job.", "warning"); return false
    end
    if step.kind == "lift" then
        run.busy = true; push(id)
        local cover = LightRP.zoneLoading and LightRP.zoneLoading.cover(id, { title = step.label or "Service lift",
            subtitle = "Service lift", expectedMs = 3000 })
        CreateThread(function()
            local called, placed = pcall(function()
                local promise = Open77.players.teleport(id, step.destination, { heading = step.heading or 0, dismount = true })
                return promise and promise:await()
            end)
            if LightRP.zoneLoading then LightRP.zoneLoading.release(id, cover) end
            run.busy = false
            if not current(id, run) then return end
            if called and placed then advance(id, run) else push(id); notify(id, "Service access failed. Press E to retry.", "error") end
        end)
        return true
    end
    run.serial = run.serial + 1
    run.work = { token = run.id .. ":" .. run.serial, at = LightRP.nowMs(), index = run.index }
    TriggerClientEvent(E.net.jobWork, id, { token = run.work.token, label = step.label,
        durationMs = step.durationMs, icon = run.route.icon })
    push(id)
    return true
end
function Runs.finish(id, payload)
    local run = runs[id]
    if type(payload) ~= "table" or not run or not run.work or payload.token ~= run.work.token or run.busy then return false end
    local work, step = run.work, run.route.steps[run.index]
    run.work = nil -- consume before any yield: duplicate completion can never pay twice
    if payload.status ~= "success" or not current(id, run) or not near(id, step.position)
        or LightRP.nowMs() - work.at < step.durationMs or LightRP.nowMs() > run.expires
        or LightRP.nowMs() - work.at > step.durationMs + 15000 then
        push(id); return false
    end
    local item = carriedItem(run)
    if item and (step.kind == "pickup" or step.kind == "dropoff") then
        run.busy = true; push(id)
        local moved, why
        if step.kind == "pickup" then moved, why = LightRP.inventory.addItem(run.inv, item, 1)
        else moved, why = LightRP.inventory.removeItem(run.inv, item, 1) end
        run.busy = false
        if runs[id] ~= run then return false end
        if not moved then
            push(id)
            notify(id, step.kind == "pickup" and "The order does not fit in your bag. Make room and press E again."
                or "You no longer carry an order to hand over.", "warning")
            LightRP.log("job run %s: %s refused (%s)", run.id, step.kind, tostring(why))
            return false
        end
        run.carried = run.carried + (step.kind == "pickup" and 1 or -1)
    end
    LightRP.eachModule("onJobRunStep", id, run, step) -- crew bonus (job_crew.lua)
    -- Every step but the last moves on; the last one pays (AC's report, the courier's last drop-off).
    if run.index < #run.route.steps then advance(id, run); return true end
    run.busy = true; push(id)
    local called, ok, why = pcall(LightRP.money.exchange, id, "bank", run.route.reward,
        { query = "INSERT INTO lightrp_job_run_receipts (run_id, identifier, character_key, job, amount) VALUES (?, ?, ?, ?, ?)",
          values = { run.id, run.identifier, run.key, run.job, run.route.reward } },
        function() run.paid = true end, "job_run", run.route.label, LightRpJobs[run.job].label)
    run.busy = false
    if runs[id] ~= run then return ok == true end -- disconnected; SQL still belongs to captured wallet
    if called and ok then
        runs[id] = nil; cooldown[id] = LightRP.nowMs() + (tonumber(run.route.cooldownMs) or C.cooldownMs); push(id)
        notify(id, LightRP.money.format(run.route.reward) .. " deposited in your bank. Route complete.", "money")
        LightRP.log("job run paid: %s %s amount=%d", run.id, run.job, run.route.reward)
        LightRP.eachModule("onJobRunCompleted", id, run) -- contracts, crew bonus, Big Contract premium
        return true
    end
    push(id)
    LightRP.log("job run payment failed: %s %s", run.id, tostring(called and why or ok))
    notify(id, "Payment could not be confirmed. Your completed route is kept. Press E at dispatch to retry.", "error")
    return false
end
RegisterNetEvent(E.net.jobBegin, function(payload) Runs.begin(source, payload) end)
RegisterNetEvent(E.net.jobFinish, function(payload) Runs.finish(source, payload) end)
LightRP.action("jobs.start", function(id, payload)
    local ok, message = Runs.start(id, type(payload) == "table" and payload.from == "menu", type(payload) == "table" and payload.duo == true)
    LightRP.result(id, ok, message, "jobs.start")
end)
LightRP.action("jobs.gps", function(id)
    local run = runs[id]
    if run then push(id); TriggerClientEvent(E.net.jobGps, id) end
    LightRP.result(id, run ~= nil, run and "GPS set to your next stop." or "You have no active work order.", "jobs.gps")
end)
LightRP.action("jobs.cancel", function(id)
    local ok, message = Runs.cancel(id); LightRP.result(id, ok, message, "jobs.cancel")
end)
LightRP.command("job", { usage = "/job <start|duo|status|cancel|gps>" }, function(id, args)
    if args[1] == "start" then return Runs.start(id) end
    if args[1] == "duo" then return Runs.startDuo(id) end
    if args[1] == "cancel" then return Runs.cancel(id) end
    local run = runs[id]
    if not run then return false, "No active work order. Collect one at the employment office. Sanitation and scrap are free item activities: /work sanitation or /work scrapper." end
    push(id)
    if args[1] == "gps" then TriggerClientEvent(E.net.jobGps, id) end
    return true, string.format("%s · %d/%d · %s · %s on completion. /job cancel to abandon.", run.route.label, run.index, #run.route.steps, run.route.steps[run.index].label, LightRP.money.format(run.route.reward))
end)
function Runs.onJobChanged(id) Runs.cancel(id, "Your job changed. The unfinished work order was cancelled.") end
function Runs.onCharacterSwitched(id) Runs.cancel(id, "Character changed. The unfinished work order was cancelled.") end
function Runs.onLifeState(id, phase) if phase ~= "alive" then Runs.cancel(id, "Work order cancelled because you are incapacitated.") end end
function Runs.onDisconnected(id) runs[id], starting[id], cooldown[id], accessBusy[id], lastBegin[id] = nil, nil, nil, nil, nil end
function Runs.onGameplayReady(id)
    -- an order left in the bag by a run that ended while away (restart, crash)
    if not runs[id] and LightRpDelivery then dropStale(id, LightRpDelivery.item) end
    push(id)
end

-- Exits remain usable without a run, even after cancellation, job switch or a
-- reconnect. The server checks the exact roof entrance, life and bucket again.
function Runs.onInteract(id, point)
    for name, lift in pairs(C.lifts) do
        local leaving = point == "jobexit." .. name
        local entering = point == "jobentry." .. name
        local r = runs[id]
        if (leaving or (entering and r and r.job == "ac_cleaner"))
            and near(id, leaving and lift.roof or lift.ground) and not Runs.isBusy(id) then
            local run = runs[id]
            if run then stopWork(id, run); push(id) end
            accessBusy[id] = true
            LightRP.staff.moveTo(id, leaving and lift.ground or lift.roof, lift.heading or 0, function(ok)
                accessBusy[id] = nil
                if not ok then notify(id, "Service exit failed. Please retry.", "error") end
            end)
            return
        end
    end
end
CreateThread(function()
    Wait(750)
    for name, lift in pairs(C.lifts) do
        -- the way up is for the job; the way down stays open to anyone on the roof
        LightRP.interaction("jobentry." .. name, { position = lift.ground, radius = 2.0, jobs = { "ac_cleaner" },
            prompt = "Service access · AC workers", key = "E", ring = false })
        LightRP.interaction("jobexit." .. name, { position = lift.roof, radius = 2.0,
            prompt = "Service exit · Street level", key = "E", ring = false,
            marker = { shape = "cylinder", radius = 0.45, height = 0.35, color = { r = 255, g = 204, b = 0, a = 160 }, maxDistance = 20 } })
    end
end)
function Runs.tick()
    for id, run in pairs(runs) do
        if not run.busy then
            local now = LightRP.nowMs()
            local mine = identity(id) == run.owner and LightRP.jobs.get(id).name == run.job
            -- Out of the public world for a moment (a loading screen after a long
            -- trip, a fitting room): the run waits; it ends if that lasts.
            local away = mine and not eligible(id)
            if away then run.awayAt = run.awayAt or now else run.awayAt = nil end
            if not mine or now > run.expires or (away and now - run.awayAt > (C.awayGraceMs or 0)) then
                Runs.cancel(id, "Work order ended. Visit dispatch for a new route.")
            elseif run.work and away then stopWork(id, run); push(id)
            elseif run.work then
                local step = run.route.steps[run.index]
                if not near(id, step.position) or LightRP.nowMs() - run.work.at > step.durationMs + 15000 then stopWork(id, run); push(id) end
            end
        end
    end
end
CreateThread(function() lightrpEvery(250, function()  Runs.tick() end, "job_runs:500") end)

-- Stale flags left by tasks the instruction quota killed (framework.lua expireFlags).
expireFlags("job_runs.starting", starting)
expireFlags("job_runs.run.busy", runs, nil, "busy")
expireFlags("job_runs.accessBusy", accessBusy)
