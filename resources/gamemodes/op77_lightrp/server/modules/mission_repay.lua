-- Authored missions saved before the 2026-11 economy pass keep their old payouts in
-- lightrp_mission_defs (the editor stores each difficulty's payout). The pay rule
-- caps them at payout time (mission_pay.lua, 250 €$ per minute), but their boards
-- still announce the old figure. This staff command brings them to the new scale.
--
--   /lightrp.missions.repay          preview: every change, nothing written
--   /lightrp.missions.repay apply    write them (revision-checked) and republish
--
-- Rule, per difficulty. The ceiling is the lower of maxSharePerMinute x its minutes
-- (the guard) and authored.maxShare of its difficulty (prod audit 2026-11-04). A
-- payout above the GUARD is on the old scale: it is scaled by new default / old
-- default of its difficulty (standard 8,000 -> 2,400, hard 15,000 -> 3,000, critical
-- 30,000 -> 4,400), rounded to 50, never below the new default, and kept under the
-- ceiling. A payout under the guard but above authored.maxShare is brought down to
-- it. A payout already under the ceiling is left as the staff set it. Running it
-- twice changes nothing the second time. (The pay rule caps at the same ceiling
-- whatever is stored; this only makes the editor show it.)
-- ACL: command.lightrp.missions.repay (staff roles hold command.lightrp.*).
local D, Db = LightRpMissionDefs, LightRP.db
local E = (LightRpEconomy and LightRpEconomy.missions) or {}
local Repay = LightRP.module("missionRepay", {})

-- The editor defaults before the economy pass (shared/mission_defs.lua, 2026-10).
Repay.OLD_DEFAULTS = { standard = 8000, hard = 15000, critical = 30000 }

local function defaults()
    local out = {}
    for _, d in ipairs(D.DIFFICULTIES) do out[d.id] = d.payout end
    return out
end
local function guard(minutes)
    local perMinute = tonumber(E.maxSharePerMinute) or 0
    if perMinute <= 0 then return math.huge end
    return math.floor(perMinute * (tonumber(minutes) or 0))
end
local function ceiling(d)
    local most = type(E.authored) == "table" and type(E.authored.maxShare) == "table" and tonumber(E.authored.maxShare[d.id]) or 0
    return most > 0 and math.min(guard(d.minutes), math.floor(most)) or guard(d.minutes)
end

-- The new payout of one stored difficulty, or nil when it stays as it is.
function Repay.payout(d)
    local payout = tonumber(d and d.payout)
    local old, new = Repay.OLD_DEFAULTS[d and d.id], defaults()[d and d.id]
    if not payout or not old or not new then return nil end
    local cap = ceiling(d)
    if payout <= cap then return nil end
    local top = math.max(0, cap - cap % 50)
    if payout <= guard(d.minutes) then return top end
    local scaled = math.floor(payout * new / old / 50 + 0.5) * 50
    return math.min(top, math.max(new, scaled))
end

-- { { id, title, revision, changes = { { difficulty, from, to } } } } for live missions.
function Repay.plan()
    local list = {}
    local Editor = LightRP.missionEditor
    for _, def in pairs(Editor and Editor.records or {}) do
        if not def.deleted then
            local changes = {}
            for _, d in ipairs(def.difficulties or {}) do
                local to = Repay.payout(d)
                if to and to ~= d.payout then changes[#changes + 1] = { difficulty = d.id, from = d.payout, to = to } end
            end
            if #changes > 0 then list[#list + 1] = { id = def.id, title = def.title, revision = def.revision, changes = changes } end
        end
    end
    table.sort(list, function(a, b) return a.title == b.title and a.id < b.id or a.title < b.title end)
    return list
end

local function describe(entry)
    local parts = {}
    for _, c in ipairs(entry.changes) do parts[#parts + 1] = string.format("%s %d -> %d", c.difficulty, c.from, c.to) end
    return string.format("%s (%s): %s", entry.title, entry.id, table.concat(parts, ", "))
end

local function author(source)
    local id = tonumber(source) or 0
    local a = id > 0 and type(GetPlayerIdentifier) == "function" and GetPlayerIdentifier(id) or nil
    -- never a nil in the parameter list: the database bridge refuses a list with a hole
    return type(a) == "string" and #a > 0 and #a <= 128 and a or "console:mission-repay"
end

-- Writes one mission at its new payouts. Returns the saved definition or nil, reason.
function Repay.applyOne(entry, source)
    local Editor = LightRP.missionEditor
    local old = Editor and Editor.records[entry.id]
    if not old or old.deleted or old.revision ~= entry.revision then return nil, "changed meanwhile" end
    local def = D.clone(old)
    local byId = {}
    for _, c in ipairs(entry.changes) do byId[c.difficulty] = c.to end
    for _, d in ipairs(def.difficulties) do if byId[d.id] then d.payout = byId[d.id] end end
    local stored = D.clone(def)
    stored.revision, stored.deleted = nil, nil
    local valid, why = D.validate(stored)
    if not valid then return nil, why end
    local revision = (old.revision or 0) + 1
    local ok, result = Db.run("UPDATE lightrp_mission_defs SET definition=?,revision=?,deleted=0,author=? WHERE id=? AND revision=?",
        { json.encode(stored), revision, author(source), entry.id, old.revision })
    local affected = type(result) == "table" and (result.affectedRows or result.changedRows) or result
    if not ok then return nil, "storage refused" end
    if tonumber(affected) == 0 then return nil, "changed meanwhile" end
    valid.id, valid.revision, valid.deleted = entry.id, revision, false
    Editor.records[entry.id] = valid
    if LightRP.missionEngine and LightRP.missionEngine.publish then LightRP.missionEngine.publish(valid) end
    return valid
end

local function say(source, text)
    LightRP.log("mission repay: %s", text)
    if (tonumber(source) or 0) > 0 and LightRP.chat and LightRP.chat.system then pcall(LightRP.chat.system, source, text) end
end

function Repay.run(source, apply)
    local Editor = LightRP.missionEditor
    if not Editor or not Editor.ready or not Db.ready then return false, "Mission storage is unavailable: nothing to do yet." end
    local plan = Repay.plan()
    if #plan == 0 then return true, "Every authored mission is already on the new payout scale." end
    local done, failed = 0, 0
    for _, entry in ipairs(plan) do
        if apply then
            local saved, why = Repay.applyOne(entry, source)
            if saved then done = done + 1; say(source, "updated " .. describe(entry))
            else failed = failed + 1; say(source, "skipped " .. entry.title .. " (" .. entry.id .. "): " .. tostring(why)) end
        else
            say(source, describe(entry))
        end
    end
    if not apply then return true, string.format("%d mission(s) would change. /lightrp.missions.repay apply writes them.", #plan) end
    return failed == 0, string.format("%d mission(s) updated and republished, %d skipped.", done, failed)
end

LightRP.command("lightrp.missions.repay", { restricted = true, usage = "/lightrp.missions.repay [apply]" }, function(source, args)
    return Repay.run(source, args and args[1] == "apply")
end)
