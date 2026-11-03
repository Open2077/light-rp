-- /lightrp.missions.repay: authored missions saved with the old payouts are brought to
-- the new scale (server/modules/mission_repay.lua). Real mission format and economy
-- config; the editor's records, SQL and the engine are stubbed.
local noop = function() end
local stored = {}
json = { encode = function(v) stored[#stored + 1] = v; return "#" .. #stored end, decode = function(s) return stored[tonumber(s:sub(2))] end }
dofile("shared/safezones.lua")
dofile("shared/mission_defs.lua")
dofile("server/config/economy.lua")
local D = LightRpMissionDefs
local runs, published, logs, chats, commands = {}, {}, {}, {}, {}
local refuse, stale = false, false
local Db = { ready = true, schema = noop,
    run = function(sql, params)
        runs[#runs + 1] = { sql = sql, params = params }
        for i = 1, 5 do assert(params[i] ~= nil, "no hole in the parameter list") end
        if refuse then return false end
        return true, { affectedRows = stale and 0 or 1 }
    end }
LightRP = { db = Db, module = function(name, t) LightRP[name] = t; return t end,
    log = function(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end,
    chat = { system = function(id, text) chats[#chats + 1] = { id = id, text = text } end },
    command = function(name, opts, fn) commands[name] = { opts = opts, fn = fn } end,
    missionEngine = { publish = function(def) published[#published + 1] = def end },
}
GetPlayerIdentifier = function(id) return "license:" .. id end

local O = { x = 100, y = 200, z = 10 }
local function mission(id, title, difficulties, revision)
    local def = assert(D.validate({ title = title, description = "", location = "Kabuki", type = "eliminate", enabled = true,
        point = { x = 140, y = 200, z = 10 }, perimeter = { shape = "circle", center = O, radius = 30, minZ = 0, maxZ = 40 },
        outOfBounds = { graceSeconds = 5 }, respawn = { seconds = 4, lives = 1 }, starts = { { x = 100, y = 200, z = 10, heading = 90 } },
        spawns = { { id = "s1", label = "Bay", position = { x = 110, y = 200, z = 10 }, heading = 0, enemy = "militech", count = 2, trigger = "start" } },
        checkpoints = {}, waves = {}, difficulties = difficulties }))
    def.id, def.revision, def.deleted = id, revision or 3, false
    return def
end
local records = {
    old = mission("old", "Old defaults", { { id = "standard", payout = 8000 }, { id = "hard", payout = 15000 }, { id = "critical", payout = 30000 } }),
    custom = mission("custom", "Custom old", { { id = "standard", payout = 12000 }, { id = "hard", payout = 40000, minutes = 30 }, { id = "critical", payout = 3000 } }),
    fresh = mission("fresh", "Already new", {}),
    gone = mission("gone", "Deleted", { { id = "standard", payout = 8000 } }),
}
records.gone.deleted = true
LightRP.missionEditor = { records = records, ready = true }
dofile("server/modules/mission_repay.lua")
local R = LightRP.missionRepay
local cmd = commands["lightrp.missions.repay"]
assert(cmd and cmd.opts.restricted, "a restricted staff command")

-- The rule, per difficulty.
assert(R.payout({ id = "standard", payout = 8000, minutes = 15 }) == 2400)
assert(R.payout({ id = "hard", payout = 15000, minutes = 15 }) == 3000)
assert(R.payout({ id = "critical", payout = 30000, minutes = 20 }) == 4400)
assert(R.payout({ id = "standard", payout = 12000, minutes = 15 }) == 3600, "a custom payout keeps its proportion")
assert(R.payout({ id = "standard", payout = 20000, minutes = 15 }) == 3750, "and stays under the ceiling (250 x 15)")
assert(R.payout({ id = "standard", payout = 3000, minutes = 15 }) == nil, "under the ceiling: left as the staff set it")
assert(R.payout({ id = "standard", payout = 2400, minutes = 15 }) == nil and R.payout({ id = "unknown", payout = 99999, minutes = 15 }) == nil)

-- Preview: lists the changes, writes nothing.
local ok, text = cmd.fn(0, {})
assert(ok and text:find("2 mission%(s%) would change") and #runs == 0 and #published == 0)
local plan = R.plan()
assert(#plan == 2 and plan[1].id == "custom" and plan[2].id == "old")
assert(#plan[1].changes == 2 and plan[1].changes[1].difficulty == "standard" and plan[1].changes[1].to == 3600
    and plan[1].changes[2].difficulty == "hard" and plan[1].changes[2].to == 7500, "40,000 x 0.2 = 8,000, capped at 250 x 30")
assert(#plan[2].changes == 3, "the old defaults all move")

-- Apply: one revision-checked UPDATE per mission, records and the engine refreshed.
ok, text = cmd.fn(7, { "apply" })
assert(ok and text:find("2 mission%(s%) updated") and #runs == 2 and #published == 2)
assert(runs[1].sql:find("WHERE id=%? AND revision=%?") and runs[1].params[4] == "custom" and runs[1].params[5] == 3 and runs[1].params[2] == 4)
assert(runs[1].params[3] == "license:7", "the staff member is the author")
local saved = stored[#stored]
assert(saved.revision == nil and saved.deleted == nil, "the stored JSON has no runtime fields")
local old = records.old
assert(LightRP.missionEditor.records.old.revision == 4 and LightRP.missionEditor.records.old.difficulties[1].payout == 2400
    and LightRP.missionEditor.records.old.difficulties[2].payout == 3000 and LightRP.missionEditor.records.old.difficulties[3].payout == 4400)
assert(published[2].id == "old" and published[2].difficulties[1].payout == 2400, "the board shows the new figure")
assert(LightRP.missionEditor.records.custom.difficulties[3].payout == 3000, "a payout under the ceiling is untouched")
assert(LightRP.missionEditor.records.gone.difficulties[1].payout == 8000, "deleted missions are left alone")
assert(#chats >= 2 and chats[1].id == 7 and #logs >= 4)

-- Idempotent: a second run finds nothing.
runs = {}
ok, text = cmd.fn(0, { "apply" })
assert(ok and text:find("already on the new payout scale") and #runs == 0)

-- A mission edited meanwhile is skipped, never overwritten; the console is a valid author.
LightRP.missionEditor.records.late = mission("late", "Late", { { id = "standard", payout = 9000 } }, 5)
stale = true
ok, text = cmd.fn(0, { "apply" })
assert(not ok and text:find("0 mission%(s%) updated and republished, 1 skipped") and runs[1].params[3] == "console:mission-repay")
assert(LightRP.missionEditor.records.late.difficulties[1].payout == 9000 and LightRP.missionEditor.records.late.revision == 5)
stale = false
refuse = true
ok = cmd.fn(0, { "apply" }); assert(not ok and LightRP.missionEditor.records.late.difficulties[1].payout == 9000, "storage refused: nothing changes")
refuse = false
-- No storage yet: nothing to do.
LightRP.missionEditor.ready = false
ok, text = cmd.fn(0, {}); assert(not ok and text:find("unavailable"))
print("mission_repay_test: rule (proportion, ceiling, untouched), preview, apply (revision check, author, republish), idempotence, stale and refused writes passed")
