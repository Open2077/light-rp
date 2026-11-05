-- Jobs worked together (docs/dailies-titles.md §5): the +15 % crew bonus and the
-- premium of the Courier's Big Contract. Numbers: LightRpEconomy.jobs.crewBonus
-- and .bigContract (server/config/economy.lua).
--
-- A crew bonus needs a crewmate (parties.lua) on ANOTHER account, in the same job,
-- who did real work in the last few minutes: a batch at a fixed site (and close
-- by), or a step of a work order. The bonus is a separate ledger line
-- (`crew_bonus`), capped per account and UTC day. Practice sites and the Big
-- Contract (it has its own premium) never get it.
local JobCrew = LightRP.module("jobCrew", {})

local recent = {} -- playerId -> { at, job, account }: the last real work
local paid = {}   -- account -> { day, amount }: crew bonus paid today
local duos = {}   -- Big Contract id -> { [playerId] = { at, reward, account } }

local function now() return LightRP.nowMs() end
local function cfg()
    local J = LightRpEconomy and LightRpEconomy.jobs
    return type(J) == "table" and type(J.crewBonus) == "table" and J.crewBonus or {}
end
local function bigCfg()
    local J = LightRpEconomy and LightRpEconomy.jobs
    local b = type(J) == "table" and J.bigContract
    return type(b) == "table" and b.enabled ~= false and b or nil
end
local function today()
    if LightRP.dailies and type(LightRP.dailies.day) == "function" then return LightRP.dailies.day() end
    local fn = (Open77 and Open77.time and Open77.time.unix) or GetUnixTime
    local ok, v = pcall(fn)
    return math.floor((ok and tonumber(v) or 0) / 86400)
end
local function accountOf(id)
    local c = LightRP.characters and LightRP.characters.get(id)
    return c and c.status == "active" and c.identifier or nil
end
local function nameOf(id) return LightRP.characters and LightRP.characters.displayName(id) or tostring(id) end
local function jobLabel(job) return type(LightRpJobs) == "table" and LightRpJobs[job] and LightRpJobs[job].label or tostring(job) end
local function money(n) return LightRP.money.format(n) end
local function positionOf(id)
    local ok, p = pcall(Open77.players.position, id)
    return ok and type(p) == "table" and p or nil
end
local function dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function worked(id, job)
    local account = accountOf(id)
    if account and job then recent[id] = { at = now(), job = job, account = account } end
end
-- A crewmate on another account, same job, with real work in the last minutes;
-- within `range` metres when given (a fixed site).
local function partnerOf(id, job, range)
    local P = LightRP.parties
    local crew = P and type(P.of) == "function" and P.of(id)
    local mine = accountOf(id)
    if not crew or not mine then return nil end
    local window = (tonumber(cfg().recentMinutes) or 5) * 60000
    local here = range and positionOf(id)
    for _, other in ipairs(crew.members or {}) do
        local r = recent[other]
        if other ~= id and r and r.job == job and r.account ~= mine and accountOf(other) == r.account and now() - r.at <= window then
            if not range then return other end
            local there = positionOf(other)
            if here and there and (here.bucket or 0) == (there.bucket or 0) and dist(here, there) <= range then return other end
        end
    end
end
JobCrew.partnerOf = partnerOf

local function bonus(id, base, job, partner)
    local c = cfg()
    local rate = tonumber(c.rate) or 0
    local account = accountOf(id)
    base = math.floor(tonumber(base) or 0)
    if rate <= 0 or base <= 0 or not account then return 0 end
    local day = today()
    local row = paid[account]
    if not row or row.day ~= day then row = { day = day, amount = 0 }; paid[account] = row end
    local amount = math.min(math.floor(base * rate + 0.5), (tonumber(c.dailyCap) or math.huge) - row.amount)
    if amount <= 0 then return 0 end
    local ok = LightRP.money.addBank(id, amount, "crew_bonus", "Crew bonus · " .. jobLabel(job), nameOf(partner))
    if not ok then return 0 end
    row.amount = row.amount + amount
    LightRP.notice(id, { kind = "money", title = string.format("CREW BONUS +%d%%", math.floor(rate * 100 + 0.5)), durationMs = 6000,
        body = string.format("+%s for working with %s.", money(amount), nameOf(partner)) })
    return amount
end
JobCrew.bonus = bonus

local function premium(id, run)
    local b = bigCfg()
    if not b or type(run.duo) ~= "table" then return end
    local t = now()
    for duoId, d in pairs(duos) do
        local stale = true
        for _, e in pairs(d) do if t - e.at < 3 * 3600000 then stale = false end end
        if stale then duos[duoId] = nil end
    end
    local d = duos[run.duo.id] or {}
    duos[run.duo.id] = d
    d[id] = { at = t, reward = math.floor(tonumber(run.route and run.route.reward) or 0), account = accountOf(id) }
    local other = d[run.duo.partner]
    if not other then
        LightRP.notice(id, { kind = "info", title = "BIG CONTRACT", durationMs = 8000,
            body = string.format("Your half is delivered. When %s lands theirs, you both get the Big Contract bonus.", run.duo.partnerName or "your partner") })
        return
    end
    local together = math.abs(d[id].at - other.at) <= (tonumber(b.togetherSeconds) or 120) * 1000
    local rate = together and (tonumber(b.togetherBonus) or 0) or (tonumber(b.bonus) or 0)
    duos[run.duo.id] = nil
    local c, day = cfg(), today()
    for pid, e in pairs(d) do
        local amount = math.floor(e.reward * rate + 0.5)
        -- the same daily cap as the crew bonus (it used to bypass every cap)
        local row = e.account and paid[e.account]
        if e.account and (not row or row.day ~= day) then row = { day = day, amount = 0 }; paid[e.account] = row end
        if row then amount = math.min(amount, (tonumber(c.dailyCap) or math.huge) - row.amount) end
        if amount > 0 and accountOf(pid) == e.account then
            local partner = pid == id and run.duo.partner or id
            local ok = LightRP.money.addBank(pid, amount, "crew_bonus", together and "Big Contract · served together" or "Big Contract", nameOf(partner))
            if ok then
                if row then row.amount = row.amount + amount end
                LightRP.notice(pid, { kind = "money", title = together and "SERVED TOGETHER" or "BIG CONTRACT", durationMs = 9000,
                    body = string.format("+%s (+%d%%) with %s.%s", money(amount), math.floor(rate * 100 + 0.5), nameOf(partner),
                        together and "" or " Land your last drops closer together for the full bonus.") })
            end
        end
    end
end

function JobCrew.onJobWorkCompleted(id, job, kind, info)
    info = type(info) == "table" and info or {}
    if info.practice then return end
    worked(id, job)
    if kind ~= "sell" then return end
    local partner = partnerOf(id, job, tonumber(cfg().range) or 60)
    if partner then bonus(id, info.total, job, partner) end
end
function JobCrew.onJobRunStep(id, run) if type(run) == "table" then worked(id, run.job) end end
function JobCrew.onJobRunCompleted(id, run)
    if type(run) ~= "table" then return end
    worked(id, run.job)
    if run.duo then return premium(id, run) end
    local partner = partnerOf(id, run.job, nil)
    if partner then bonus(id, run.route and run.route.reward, run.job, partner) end
end
function JobCrew.onDisconnected(id) recent[id] = nil end
function JobCrew.onCharacterSwitched(id) recent[id] = nil end
