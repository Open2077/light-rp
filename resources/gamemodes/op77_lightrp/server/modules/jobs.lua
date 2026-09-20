-- Jobs and gangs on a character: one job + grade, one gang + grade, persisted
-- on lightrp_characters (job, job_grade, gang, gang_grade) and replicated in the
-- player's state bag (`job`, `gang`) for other resources. Paychecks land in the
-- bank every jobs.paycheckMinutes for grades that carry a salary.
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

-- ---------------------------------------------------------------------------
-- State for the page, replication, paychecks

LightRP.stateProvider("job", function(playerId)
    local job = Jobs.get(playerId)
    job.paycheckMinutes = Config.paycheckMinutes or 30
    return job
end)
LightRP.stateProvider("gang", function(playerId) return Jobs.gang(playerId) end)

function Jobs.onCharacterLoaded(playerId, c)
    if c and c.status == "active" then publish(playerId) end
end
function Jobs.onCharacterActivated(playerId, c) Jobs.onCharacterLoaded(playerId, c) end

CreateThread(function()
    local minutes = tonumber(Config.paycheckMinutes) or 30
    if minutes <= 0 then return end
    while true do
        Wait(minutes * 60000)
        for _, playerId in ipairs(GetPlayers()) do
            local job = Jobs.get(playerId)
            if job.salary > 0 and LightRP.money and LightRP.money.get(playerId) then
                local ok = LightRP.money.addBank(playerId, job.salary, "salary", job.label .. " · " .. job.gradeLabel, job.label)
                if ok then LightRP.notice(playerId, { kind = "money", title = "Paycheck", body = string.format("%s from %s.", LightRP.money.format(job.salary), job.label), durationMs = 8000 }) end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Staff commands

local REASONS = { no_character = "That player has no active character.", unknown_job = "Unknown job. /lightrp.jobs lists them.",
    unknown_gang = "Unknown gang. /lightrp.jobs lists them.", unknown_grade = "That grade does not exist for it.", database_error = "The database refused." }
local function explain(reason) return REASONS[reason] or ("Denied: " .. tostring(reason)) end

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
