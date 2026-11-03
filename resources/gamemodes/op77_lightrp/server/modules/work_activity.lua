-- Who really worked lately: paychecks go to active players only (rules:
-- server/config/economy.lua `paychecks`, rationale: docs/economy-balance.md).
-- Light RP has no clock-in: "on duty" is holding a salaried job; "active" is one
-- of these signals, all seen by the server itself, never a claim from a client:
--   moved    the server samples positions every `sampleSeconds`: getting
--            `moveMetres` away from the last anchor counts, in the city only
--            (bucket 0, alive, not in a mission or an activity); a jump of more
--            than `teleportMetres` between two samples re-anchors without credit
--   job      a job_work batch (onJobWorkCompleted), a work order accepted
--            (onJobRunStarted) or paid (job_run)
--   served   a patient stabilized with a kit (onPatientStabilized), a bank
--            transfer received from another player (transfer_in)
--
--   LightRP.workActivity.note(id, why)       record a signal now
--   LightRP.workActivity.last(id)            -> ms, why  (nil when none)
--   LightRP.workActivity.eligible(id)        -> true | false, reason ("idle")
--   LightRP.workActivity.paid(id)            payday succeeded: the idle streak ends
--   LightRP.workActivity.skipped(id, job, why) payday refused: noticed and logged once per streak
--   LightRP.workActivity.sample()            one position pass (the thread runs it)
local E = LightRpEconomy or {}
local C = E.paychecks or {}
local W = LightRP.module("workActivity", {})

local last = {}      -- playerId -> { at, why }
local anchors = {}   -- playerId -> { x, y, z }
local idle = {}      -- playerId -> true once the idle notice went out

local function now() return LightRP.nowMs() end
local function number(value, fallback)
    local n = tonumber(value)
    if n == nil or n ~= n then return fallback end
    return n
end
local function key(id) return tonumber(id) or id end

function W.note(id, why)
    id = key(id)
    if id == nil then return end
    last[id] = { at = now(), why = why or "work" }
end
function W.last(id)
    local entry = last[key(id)]
    if entry then return entry.at, entry.why end
end

local function windowMs() return math.max(1, number(C.windowMinutes, 30)) * 60000 end

function W.eligible(id)
    if C.requireActivity == false then return true end
    local at = W.last(id)
    if at and now() - at <= windowMs() then return true end
    return false, "idle"
end

function W.paid(id) idle[key(id)] = nil end

function W.skipped(id, job, why)
    id = key(id)
    if idle[id] then return end
    idle[id] = true
    local minutes = math.floor(number(C.windowMinutes, 30))
    LightRP.log("paychecks: %s (%s) skipped, %s: no work in the last %d min", tostring(id), tostring(job and job.name), tostring(why), minutes)
    pcall(LightRP.notice, id, { kind = "warning", title = "No paycheck", durationMs = 9000,
        body = string.format("%s pays people who work: nothing real in the last %d minutes (a job task, a patient, a customer, or getting around the city). Back to work and the next paycheck comes.",
            job and job.label or "Your employer", minutes) })
end

-- ---------------------------------------------------------------------------
-- Positions: the server's own samples.

local function positionOf(id)
    local p = Open77.players.position(id)
    if p then return p end
    if type(Open77.players.get) ~= "function" then return nil end
    local ok, read = pcall(Open77.players.get, id)
    if ok and type(read) == "table" and type(read.position) == "table" then return read.position end
end

local function inTheCity(id, p)
    if (tonumber(p.bucket) or 0) ~= 0 then return false end
    if LightRP.activities and LightRP.activities.owns and LightRP.activities.owns(id) then return false end
    local c = LightRP.characters and LightRP.characters.get(id)
    if not c or c.status ~= "active" then return false end
    local life = type(Open77.players.getLifeState) == "function" and Open77.players.getLifeState(id) or nil
    return life == nil or life.phase == "alive"
end

function W.sample()
    local move = math.max(1, number(C.moveMetres, 75))
    local jump = math.max(move, number(C.teleportMetres, 2000))
    for _, raw in ipairs(GetPlayers()) do
        local id = key(raw)
        local p = positionOf(id)
        if p and type(p.x) == "number" and type(p.y) == "number" and inTheCity(id, p) then
            local a = anchors[id]
            if not a then
                anchors[id] = { x = p.x, y = p.y, z = p.z or 0 }
            else
                local dx, dy, dz = p.x - a.x, p.y - a.y, (p.z or 0) - a.z
                local d = math.sqrt(dx * dx + dy * dy + dz * dz)
                if d >= move then
                    anchors[id] = { x = p.x, y = p.y, z = p.z or 0 }
                    if d <= jump then W.note(id, "moved") end
                end
            end
        elseif p then
            -- elsewhere (a mission, an activity, a home, the arrival hall): the way
            -- back is a teleport, never a walk
            anchors[id] = nil
        end
    end
end

CreateThread(function()
    while true do
        Wait(math.max(1, number(C.sampleSeconds, 20)) * 1000)
        local ok, err = pcall(W.sample)
        if not ok then LightRP.log("paychecks: position sample failed: %s", tostring(err)) end
    end
end)

-- ---------------------------------------------------------------------------
-- Signals from the other modules.

function W.onJobWorkCompleted(id) W.note(id, "job") end
function W.onJobRunStarted(id) W.note(id, "job") end
function W.onPatientStabilized(actor) W.note(actor, "served") end
function W.onMoneyChanged(id, _, delta, _, kind)
    if (tonumber(delta) or 0) <= 0 then return end
    if kind == "job_run" then W.note(id, "job")
    elseif kind == "transfer_in" and delta >= number(C.servedMinimum, 50) then W.note(id, "served") end
end
local function forget(id) id = key(id); last[id], anchors[id], idle[id] = nil, nil, nil end
function W.onDisconnected(id) forget(id) end
function W.onCharacterSwitched(id) forget(id) end
