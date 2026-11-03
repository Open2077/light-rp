-- Jobs and gangs on a character: one job + grade, one gang + grade, persisted
-- on lightrp_characters (job, job_grade, gang, gang_grade) and replicated in the
-- player's state bag (`job`, `gang`) for other resources. Paychecks land in the
-- bank every jobs.paycheckMinutes for grades that carry a salary, to players who
-- really worked lately (LightRP.workActivity, LightRpEconomy.paychecks).
--
--   LightRP.jobs.get(playerId)  -> { name, label, tag, grade, gradeLabel, salary }
--   LightRP.jobs.gang(playerId) -> { name, label, tag, color, grade, gradeLabel }
--   LightRP.jobs.setJob(playerId, name, grade)  / setGang(playerId, name, grade)
--   LightRP.jobs.has(playerId, jobName, minGrade) / LightRP.jobs.inGang(playerId, gangName, minGrade)
--   hooks onJobChanged(playerId, job, previous), onGangChanged(playerId, gang, previous)
local Config = LightRpConfig.jobs or {}
local Db = LightRP.db
local Jobs = LightRP.module("jobs", {})

local JOBS, GANGS = LightRpJobs, LightRpGangs

local function clampGrade(catalogue, name, grade)
    local def = catalogue[name]
    if def == nil then return nil end
    grade = math.floor(tonumber(grade) or 0)
    if def.grades[grade] == nil then return nil end
    return grade
end

local function view(catalogue, name, grade, fallback)
    local def = catalogue[name] or catalogue[fallback]
    name = catalogue[name] and name or fallback
    grade = def and def.grades[grade] and grade or 0
    local g = def and def.grades[grade] or {}
    return { name = name, label = def and def.label or name, tag = def and def.tag or "", color = def and def.color, grade = grade,
        gradeLabel = g.label or "", salary = g.salary or 0 }
end

function Jobs.get(playerId)
    local c = LightRP.characters.get(playerId)
    return view(JOBS, c and c.job or "unemployed", c and c.jobGrade or 0, "unemployed")
end

function Jobs.gang(playerId)
    local c = LightRP.characters.get(playerId)
    return view(GANGS, c and c.gang or "none", c and c.gangGrade or 0, "none")
end

function Jobs.has(playerId, jobName, minGrade)
    local job = Jobs.get(playerId)
    return job.name == jobName and job.grade >= (minGrade or 0)
end

function Jobs.inGang(playerId, gangName, minGrade)
    local gang = Jobs.gang(playerId)
    return gang.name == gangName and gang.grade >= (minGrade or 0)
end

local function publish(playerId)
    if type(Open77.state) == "table" and type(Open77.state.player) == "function" then
        local ok, bag = pcall(Open77.state.player, playerId)
        if ok and bag then
            pcall(bag.set, bag, "job", Jobs.get(playerId))
            pcall(bag.set, bag, "gang", Jobs.gang(playerId))
        end
    end
    LightRP.state(playerId, { "job", "gang" })
end

local function persist(c)
    if not Db.ready or c.identifier == nil then return true end
    return Db.run("UPDATE lightrp_characters SET job = ?, job_grade = ?, gang = ?, gang_grade = ? WHERE identifier = ? AND character_key = ?",
        { c.job or "unemployed", c.jobGrade or 0, c.gang or "none", c.gangGrade or 0, c.identifier, c.key })
end

function Jobs.setJob(playerId, name, grade)
    if LightRP.jobRuns and LightRP.jobRuns.isBusy(playerId) then return false, "busy" end
    if LightRP.jobWork and LightRP.jobWork.isBusy(playerId) then return false, "busy" end
    local c = LightRP.characters.get(playerId)
    if c == nil or c.status ~= "active" then return false, "no_character" end
    name = string.lower(tostring(name or ""))
    if JOBS[name] == nil then return false, "unknown_job" end
    grade = clampGrade(JOBS, name, grade)
    if grade == nil then return false, "unknown_grade" end
    local previous = Jobs.get(playerId)
    c.job, c.jobGrade = name, grade
    local ok = persist(c)
    if not ok then c.job, c.jobGrade = previous.name, previous.grade; return false, "database_error" end
    publish(playerId)
    local job = Jobs.get(playerId)
    LightRP.notice(playerId, { kind = "info", title = name == "unemployed" and "Unemployed" or job.label, durationMs = 8000,
        body = name == "unemployed" and "You no longer have a job." or string.format("You are now %s (grade %d).", job.gradeLabel, job.grade) })
    LightRP.eachModule("onJobChanged", playerId, job, previous)
    LightRP.log("jobs: %s -> %s grade %d", LightRP.characters.displayName(playerId), name, grade)
    return true, job
end

function Jobs.setGang(playerId, name, grade)
    local c = LightRP.characters.get(playerId)
    if c == nil or c.status ~= "active" then return false, "no_character" end
    name = string.lower(tostring(name or ""))
    if GANGS[name] == nil then return false, "unknown_gang" end
    grade = clampGrade(GANGS, name, grade)
    if grade == nil then return false, "unknown_grade" end
    local previous = Jobs.gang(playerId)
    c.gang, c.gangGrade = name, grade
    local ok = persist(c)
    if not ok then c.gang, c.gangGrade = previous.name, previous.grade; return false, "database_error" end
    publish(playerId)
    local gang = Jobs.gang(playerId)
    LightRP.notice(playerId, { kind = "info", title = name == "none" and "Gang" or gang.label, durationMs = 8000,
        body = name == "none" and "You are no longer affiliated." or string.format("You are now %s of the %s.", gang.gradeLabel, gang.label) })
    LightRP.eachModule("onGangChanged", playerId, gang, previous)
    LightRP.log("jobs: %s -> gang %s grade %d", LightRP.characters.displayName(playerId), name, grade)
    return true, gang
end

local REASONS = { no_character = "That player has no active character.", busy = "Wait for the current step to finish, then try again.", unknown_job = "Unknown job. /lightrp.jobs lists them.",
    unknown_gang = "Unknown gang. /lightrp.jobs lists them.", unknown_grade = "That grade does not exist for it.", database_error = "The database refused." }
local function explain(reason) return REASONS[reason] or ("Denied: " .. tostring(reason)) end

-- ---------------------------------------------------------------------------
-- State for the page, replication, paychecks

LightRP.stateProvider("job", function(playerId)
    local job = Jobs.get(playerId)
    job.paycheckMinutes = Config.paycheckMinutes or 30
    -- The job guide (shared/jobs.lua) and how the work is done: a work order
    -- (`run`, job_runs) or free item work (`work`, job_work). Static per job.
    local def = JOBS[job.name]
    job.guide = def and def.guide or nil
    job.art = def and def.recruitment and { image = def.recruitment.image, icon = def.recruitment.icon } or nil
    job.run = LightRP.jobRuns and LightRP.jobRuns.preview(job.name) or nil
    job.work = LightRP.jobWork and LightRP.jobWork.preview(job.name) or nil
    return job
end)
LightRP.stateProvider("gang", function(playerId) return Jobs.gang(playerId) end)

function Jobs.onCharacterLoaded(playerId, c)
    if c and c.status == "active" then publish(playerId) end
end
function Jobs.onCharacterActivated(playerId, c) Jobs.onCharacterLoaded(playerId, c) end

-- One payday: the salary of every salaried player who really worked lately
-- (server/modules/work_activity.lua; idle players are told once why not).
function Jobs.payday()
    local paid = 0
    local W = LightRP.workActivity
    for _, playerId in ipairs(GetPlayers()) do
        local job = Jobs.get(playerId)
        if job.salary > 0 and LightRP.money and LightRP.money.get(playerId) then
            local eligible, why = true, nil
            if W then eligible, why = W.eligible(playerId) end
            if not eligible then
                W.skipped(playerId, job, why)
            elseif LightRP.money.addBank(playerId, job.salary, "salary", job.label .. " · " .. job.gradeLabel, job.label) then
                paid = paid + 1
                if W then W.paid(playerId) end
                LightRP.notice(playerId, { kind = "money", title = "Paycheck", body = string.format("%s from %s.", LightRP.money.format(job.salary), job.label), durationMs = 8000 })
            end
        end
    end
    return paid
end

CreateThread(function()
    local minutes = tonumber(Config.paycheckMinutes) or 30
    if minutes <= 0 then return end
    while true do
        Wait(minutes * 60000)
        Jobs.payday()
    end
end)

-- ---------------------------------------------------------------------------
-- Job centers: a clerk and a desk that hands out the listed jobs

local centers = {} -- interaction id -> center

local function spawnClerk(center)
    if type(Open77.npcs) ~= "table" or type(Open77.npcs.create) ~= "function" then return nil end
    local pool = LightRpConfig.rentals and LightRpConfig.rentals.npcPool or {}
    local candidates = {}
    for i, candidate in ipairs(pool) do candidates[i] = candidate end
    for i = #candidates, 2, -1 do local j = math.random(i); candidates[i], candidates[j] = candidates[j], candidates[i] end
    for _, candidate in ipairs(candidates) do
        local definition = {
            position = { x = center.position.x, y = center.position.y, z = center.position.z }, yaw = tonumber(center.heading) or 0.0, bucket = center.bucket or 0,
            persistent = false, despawnWhenUnobserved = false, streamingRadius = 150.0,
            behavior = { combatEnabled = false, perceptionEnabled = false, voiceEnabled = false },
        }
        if candidate.record then definition.record = candidate.record else definition.template = candidate.template end
        if type(Open77.npcs.damage) == "table" then definition.damagePolicy = Open77.npcs.damage.invulnerable or Open77.npcs.damage.immortal end
        if type(Open77.npcs.ai) == "table" then definition.aiMode = Open77.npcs.ai.tasks end
        local ok, npcId = pcall(Open77.npcs.create, definition)
        if ok and npcId then
            pcall(Open77.npcs.setAIEnabled, npcId, false)
            LightRP.log("%s %s: clerk %s spawned as %s (AI off)", center.kind or "job center", center.id, tostring(npcId), candidate.record or candidate.template)
            return npcId
        end
    end
    LightRP.log("%s %s: no clerk candidate accepted; the desk still works", center.kind or "job center", center.id)
    return nil
end
-- Other desks (the dealerships) staff their counter the same way:
-- { id, kind, position, heading, bucket }.
Jobs.spawnClerk = spawnClerk

local function offersOf(center)
    local list = {}
    for _, name in ipairs(center.jobs or {}) do
        local def = JOBS[name]
        if def and name ~= "unemployed" then
            local count = 0
            for _ in pairs(def.grades) do count = count + 1 end
            local entry = def.grades[0] or {}
            list[#list + 1] = { name = name, label = def.label, tag = def.tag, grades = count,
                entryGrade = { label = entry.label or "", salary = entry.salary or 0 }, recruitment = def.recruitment,
                route = LightRP.jobRuns and LightRP.jobRuns.preview(name),
                work = LightRP.jobWork and LightRP.jobWork.preview(name) }
        end
    end
    return list
end

CreateThread(function()
    Wait(700)
    for _, entry in ipairs(Config.centers or {}) do
        local center = {}
        for k, v in pairs(entry) do center[k] = v end
        center.offers = offersOf(center)
        center.npcId = spawnClerk(center)
        local id = "jobcenter." .. center.id
        centers[id] = center
        LightRP.interaction(id, {
            position = center.position, radius = Config.centerRadius or 2.0,
            bucket = center.bucket, -- nil: every bucket (the city desks); the arrival hall's desk has its own
            label = center.name, prompt = Config.centerPrompt or "Job center", key = "E", promptHeight = 1.1,
            marker = center.marker or Config.centerMarker, ring = false,
            blip = Config.centerBlip and { icon = Config.centerBlip.icon, color = Config.centerBlip.color, size = Config.centerBlip.size,
                sprite = Config.centerBlip.sprite, title = center.name, description = Config.centerBlip.description } or nil,
        })
    end
    if #(Config.centers or {}) > 0 then LightRP.log("jobs: %d job center(s) open", #Config.centers) end
end)

function Jobs.onInteract(playerId, id)
    local center = centers[id]
    if center == nil then return end
    local c = LightRP.characters.get(playerId)
    if c == nil or c.status ~= "active" then return LightRP.result(playerId, false, "Finish your character first.", "jobs.open") end
    LightRP.dialog(playerId, "jobcenter", { spot = { id = center.id, name = center.name }, jobs = center.offers, paycheckMinutes = Config.paycheckMinutes or 30 })
end

local function nearCenter(playerId, center)
    local p = Open77.players.position(playerId)
    local life = Open77.players.getLifeState(playerId)
    return p and (p.bucket or 0) == (center.bucket or 0) and life and life.phase == "alive"
        and LightRP.nearInteraction(playerId, { position = center.position, radius = Config.centerRadius or 2.0 }, 2.0)
end

LightRP.action("jobs.apply", function(playerId, payload)
    local center = centers["jobcenter." .. tostring(payload.spot or "")]
    if center == nil then return LightRP.result(playerId, false, "That desk does not exist.", "jobs.apply") end
    if not nearCenter(playerId, center) then return LightRP.result(playerId, false, "Walk up to the desk.", "jobs.apply") end
    local wanted = string.lower(tostring(payload.job or ""))
    local offered = false
    for _, offer in ipairs(center.offers) do if offer.name == wanted then offered = true end end
    if not offered then return LightRP.result(playerId, false, "This desk does not offer that job.", "jobs.apply") end
    if Jobs.get(playerId).name == wanted then return LightRP.result(playerId, false, "That is already your job.", "jobs.apply") end
    local ok, result = Jobs.setJob(playerId, wanted, 0)
    LightRP.result(playerId, ok, ok and string.format("Hired: %s, %s.", result.label, result.gradeLabel) or explain(result), "jobs.apply")
end)

LightRP.action("jobs.quit", function(playerId)
    if Jobs.get(playerId).name == "unemployed" then return LightRP.result(playerId, false, "You have no job to quit.", "jobs.quit") end
    -- quitting ends a run in progress (onJobChanged) and stops item work
    if LightRP.jobWork and LightRP.jobWork.isActive(playerId) then LightRP.jobWork.cancel(playerId) end
    local ok, result = Jobs.setJob(playerId, "unemployed", 0)
    LightRP.result(playerId, ok, ok and "You quit your job." or explain(result), "jobs.quit")
end)

-- ---------------------------------------------------------------------------
-- Staff commands


local function target(source, value)
    if value == nil or value == "" or value == "me" then return source end
    local id = tonumber(value)
    if id == nil or GetPlayerName(id) == nil then return nil end
    return id
end

LightRP.command("lightrp.setjob", { restricted = true, usage = "/lightrp.setjob <id|me> <job> [grade]" }, function(source, args)
    local id = target(source, args[1])
    if id == nil or args[2] == nil then return false end
    local ok, result = Jobs.setJob(id, args[2], args[3] or 0)
    return ok, ok and string.format("%s is now %s, %s (grade %d).", LightRP.characters.displayName(id), result.label, result.gradeLabel, result.grade) or explain(result)
end)

LightRP.command("lightrp.setgang", { restricted = true, usage = "/lightrp.setgang <id|me> <gang> [grade]" }, function(source, args)
    local id = target(source, args[1])
    if id == nil or args[2] == nil then return false end
    local ok, result = Jobs.setGang(id, args[2], args[3] or 0)
    return ok, ok and string.format("%s is now %s of %s (grade %d).", LightRP.characters.displayName(id), result.gradeLabel, result.label, result.grade) or explain(result)
end)

LightRP.command("lightrp.jobs", { restricted = true }, function()
    local jobs, gangs = {}, {}
    for name, def in pairs(JOBS) do local n = 0 for _ in pairs(def.grades) do n = n + 1 end jobs[#jobs + 1] = string.format("%s (0-%d)", name, n - 1) end
    for name, def in pairs(GANGS) do local n = 0 for _ in pairs(def.grades) do n = n + 1 end gangs[#gangs + 1] = string.format("%s (0-%d)", name, n - 1) end
    table.sort(jobs); table.sort(gangs)
    return true, "Jobs: " .. table.concat(jobs, ", ") .. " · Gangs: " .. table.concat(gangs, ", ")
end)
