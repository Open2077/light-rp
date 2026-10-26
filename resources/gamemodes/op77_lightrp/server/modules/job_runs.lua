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
function Runs.preview(job)
    local route = C.routes[job]
    if not route or #route.steps == 0 then return nil end
    local count = 0
    for _, step in ipairs(route.steps) do if step.kind == "work" then count = count + 1 end end
    return { label = route.label, reward = route.reward, stops = count, estimate = route.estimate, description = route.description }
end
function Runs.snapshot(id)
    local run = runs[id]
    if not run then return { active = false } end
    local step = run.route.steps[run.index]
    return { active = true, id = run.id, job = run.job, label = run.route.label, reward = run.route.reward,
        index = run.index, total = #run.route.steps, busy = run.busy == true,
        working = run.work ~= nil, icon = run.route.icon,
        objective = { label = step.label, kind = step.kind, position = step.position, radius = C.range },
        hint = step.kind == "lift" and "Use the marked service access. No climbing required."
            or step.kind == "return" and "Return to dispatch to receive your bank payment."
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
    stopWork(id, run); runs[id] = nil; push(id)
    notify(id, reason or "Work order cancelled. No payment was issued. Service exits remain available.", "warning")
    return true, "Work order cancelled."
end
function Runs.start(id)
    if LightRP.jobWork and LightRP.jobWork.isActive(id) then return false, "Stop your current item work first (Escape)." end
    if Runs.isBusy(id) then return false, "Please wait for the current operation to finish." end
    if runs[id] then push(id); return false, "Finish or cancel your current work order first." end
    if not eligible(id) then return false, "Load an active character and return to the public world first." end
    if not Db.ready then return false, "The database is unavailable. Work orders cannot be paid right now." end
    local job = LightRP.jobs.get(id).name
    if LightRP.jobWork and LightRP.jobWork.preview(job) then return false, "This is free item work. Visit a collection point; use /work " .. job .. " for GPS. No shift is needed." end
    local route = C.routes[job]
    if not route or #route.steps == 0 then return false, "Choose an available job at the employment office first." end
    local atDesk = false
    for _, desk in ipairs(LightRpConfig.jobs.centers) do if near(id, desk.position) then atDesk = true end end
    if not atDesk then return false, "Visit the employment office to collect your work order." end
    if (cooldown[id] or 0) > LightRP.nowMs() then return false, "Dispatch is preparing your next route. Try again in a moment." end
    local owner, char = identity(id)
    local ticket = {}; starting[id] = ticket
    local row = Db.single("SELECT UUID() AS id")
    if starting[id] ~= ticket then return false, "The request was cancelled." end
    starting[id] = nil
    if not row or type(row.id) ~= "string" then return false, "The database could not issue a work order. Please retry." end
    if identity(id) ~= owner or not eligible(id) or LightRP.jobs.get(id).name ~= job then return false, "Your character changed. Request a new work order." end
    runs[id] = { id = row.id, owner = owner, identifier = char.identifier, key = char.key, job = job,
        route = route, index = 1, serial = 0, expires = LightRP.nowMs() + C.lifetimeMs }
    push(id)
    notify(id, "Route assigned. Follow your GPS. Payment is issued after the complete route; /job cancel abandons it.")
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
    if step.kind == "lift" then
        run.busy = true; push(id)
        CreateThread(function()
            local called, placed = pcall(function()
                local promise = Open77.players.teleport(id, step.destination, { heading = step.heading or 0, dismount = true })
                return promise and promise:await()
            end)
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
    if step.kind ~= "return" then advance(id, run); return true end
    run.busy = true; push(id)
    local called, ok, why = pcall(LightRP.money.exchange, id, "bank", run.route.reward,
        { query = "INSERT INTO lightrp_job_run_receipts (run_id, identifier, character_key, job, amount) VALUES (?, ?, ?, ?, ?)",
          values = { run.id, run.identifier, run.key, run.job, run.route.reward } },
        function() run.paid = true end, "job_run", run.route.label, LightRpJobs[run.job].label)
    run.busy = false
    if runs[id] ~= run then return ok == true end -- disconnected; SQL still belongs to captured wallet
    if called and ok then
        runs[id] = nil; cooldown[id] = LightRP.nowMs() + C.cooldownMs; push(id)
        notify(id, LightRP.money.format(run.route.reward) .. " deposited in your bank. Route complete.", "money")
        LightRP.log("job run paid: %s %s amount=%d", run.id, run.job, run.route.reward)
        return true
    end
    push(id)
    LightRP.log("job run payment failed: %s %s", run.id, tostring(called and why or ok))
    notify(id, "Payment could not be confirmed. Your completed route is kept. Press E at dispatch to retry.", "error")
    return false
end
RegisterNetEvent(E.net.jobBegin, function(payload) Runs.begin(source, payload) end)
RegisterNetEvent(E.net.jobFinish, function(payload) Runs.finish(source, payload) end)
LightRP.action("jobs.start", function(id)
    local ok, message = Runs.start(id); LightRP.result(id, ok, message, "jobs.start")
end)
LightRP.action("jobs.cancel", function(id)
    local ok, message = Runs.cancel(id); LightRP.result(id, ok, message, "jobs.cancel")
end)
LightRP.command("job", { usage = "/job <start|status|cancel|gps>" }, function(id, args)
    if args[1] == "start" then return Runs.start(id) end
    if args[1] == "cancel" then return Runs.cancel(id) end
    local run = runs[id]
    if not run then return false, "No AC maintenance order. Sanitation and scrap are free item activities: /work sanitation or /work scrapper." end
    push(id)
    if args[1] == "gps" then TriggerClientEvent(E.net.jobGps, id) end
    return true, string.format("%s · %d/%d · %s · %s on completion. /job cancel to abandon.", run.route.label, run.index, #run.route.steps, run.route.steps[run.index].label, LightRP.money.format(run.route.reward))
end)
function Runs.onJobChanged(id) Runs.cancel(id, "Your job changed. The unfinished work order was cancelled.") end
function Runs.onCharacterSwitched(id) Runs.cancel(id, "Character changed. The unfinished work order was cancelled.") end
function Runs.onLifeState(id, phase) if phase ~= "alive" then Runs.cancel(id, "Work order cancelled because you are incapacitated.") end end
function Runs.onDisconnected(id) runs[id], starting[id], cooldown[id], accessBusy[id], lastBegin[id] = nil, nil, nil, nil, nil end
function Runs.onGameplayReady(id) push(id) end

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
        LightRP.interaction("jobentry." .. name, { position = lift.ground, radius = 2.0,
            prompt = "Service access · AC workers", key = "E", ring = false })
        LightRP.interaction("jobexit." .. name, { position = lift.roof, radius = 2.0,
            prompt = "Service exit · Street level", key = "E", ring = false,
            marker = { shape = "cylinder", radius = 0.45, height = 0.35, color = { r = 255, g = 204, b = 0, a = 160 }, maxDistance = 20 } })
    end
end)
function Runs.tick()
    for id, run in pairs(runs) do
        if not run.busy then
            if not current(id, run) or LightRP.nowMs() > run.expires then Runs.cancel(id, "Work order ended. Visit dispatch for a new route.")
            elseif run.work then
                local step = run.route.steps[run.index]
                if not near(id, step.position) or LightRP.nowMs() - run.work.at > step.durationMs + 15000 then stopWork(id, run); push(id) end
            end
        end
    end
end
CreateThread(function() while true do Wait(250); Runs.tick() end end)
