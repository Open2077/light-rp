-- Paychecks go to active players only (owner decision 4, docs/economy-balance.md):
-- the real jobs.lua payday + work_activity.lua, every native and SQL call stubbed.
dofile("shared/config.lua"); dofile("shared/jobs.lua")
dofile("server/config/economy.lua")
local noop = function() end
local now, modules, notices, logs, threads, credits = 1000000, {}, {}, {}, {}, {}
local chars = {
    [1] = { identifier = "alice", key = "default", status = "active", job = "sanitation", jobGrade = 0 },
    [2] = { identifier = "bob", key = "default", status = "active", job = "trauma", jobGrade = 0 },
    [3] = { identifier = "carol", key = "default", status = "active", job = "unemployed", jobGrade = 0 },
}
local positions = { [1] = { x = 0, y = 0, z = 0, bucket = 0 }, [2] = { x = 500, y = 0, z = 0, bucket = 0 }, [3] = { x = 0, y = 0, z = 0, bucket = 0 } }
local lives, owned = { [1] = "alive", [2] = "alive", [3] = "alive" }, {}
LightRP = { db = { ready = false, schema = noop }, nowMs = function() return now end, command = noop, stateProvider = noop, interaction = noop,
    action = noop, state = noop, result = noop, dialog = noop,
    log = function(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, body = n.body } end,
    module = function(name, value) LightRP[name] = value; modules[#modules + 1] = value; return value end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if m[hook] then m[hook](...) end end end,
    characters = { get = function(id) return chars[tonumber(id)] end, displayName = function(id) return chars[tonumber(id)] and chars[tonumber(id)].identifier end },
    activities = { owns = function(id) return owned[tonumber(id)] == true end },
    money = { get = function(id) return chars[tonumber(id)] and {} or nil end, format = function(n) return "€$" .. n end,
        addBank = function(id, amount, kind) credits[#credits + 1] = { id = id, amount = amount, kind = kind }; return true end },
}
Open77 = { players = { position = function(id) return positions[tonumber(id)] end, getLifeState = function(id) return { phase = lives[tonumber(id)] } end } }
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = noop
GetPlayers = function() return { "1", "2", "3" } end
dofile("server/modules/work_activity.lua")
dofile("server/modules/jobs.lua")
local W, Jobs = LightRP.workActivity, LightRP.jobs
local P = LightRpEconomy.paychecks
assert(P.requireActivity == true and P.windowMinutes == 30 and P.moveMetres == 600)
-- pinned: this test checks the mechanics at the pre-2026-11-05 numbers (balance lives in config)
P.moveMetres, LightRpJobs.sanitation.grades[0].salary, LightRpJobs.trauma.grades[0].salary = 75, 100, 225

local function payday() credits, notices = {}, {}; return Jobs.payday() end
local function paidTo(id) for _, c in ipairs(credits) do if tonumber(c.id) == id then return c.amount end end end

-- Nobody did anything: no salary, one notice each saying why, logged; the unemployed get nothing either way.
assert(payday() == 0 and #credits == 0)
assert(#notices == 2 and notices[1].title == "No paycheck" and notices[1].body:find("30 minutes"))
assert(logs[#logs]:find("skipped, idle"))
-- told once per idle streak
assert(payday() == 0 and #notices == 0, "the idle notice is not repeated")

-- A job task (a sold batch) makes alice active; bob still idle.
LightRP.eachModule("onJobWorkCompleted", 1, "sanitation", "sell")
assert(payday() == 1 and paidTo(1) == 100 and credits[1].kind == "salary" and not paidTo(2))
assert(#notices == 1 and notices[1].title == "Paycheck")
-- the window is 30 minutes: 31 minutes later, alice is idle again and told again (a new streak)
now = now + 31 * 60000
assert(payday() == 0 and #notices == 1 and tonumber(notices[1].id) == 1)

-- Serving a customer: a stabilized patient (medic) or a real transfer received.
LightRP.eachModule("onPatientStabilized", 2, 1)
assert(payday() == 1 and paidTo(2) == 225)
now = now + 31 * 60000
LightRP.eachModule("onMoneyChanged", 2, "bank", 20, 1000, "transfer_in")
assert(payday() == 0, "a token transfer is not a customer")
LightRP.eachModule("onMoneyChanged", 2, "bank", 80, 1080, "transfer_in")
LightRP.eachModule("onMoneyChanged", 1, "bank", 400, 1500, "job_run")
assert(payday() == 2, "a fare paid by transfer, a work order paid")
LightRP.eachModule("onMoneyChanged", 1, "bank", -50, 1450, "job_run")
now = now + 31 * 60000

-- Moving: the server's own samples. The first sample anchors, small moves around it do not count.
W.sample()
positions[1] = { x = 40, y = 30, z = 0, bucket = 0 }; W.sample() -- 50 m
positions[1] = { x = 0, y = 60, z = 0, bucket = 0 }; W.sample() -- 60 m from the anchor
assert(payday() == 0, "pacing on the spot is not work")
positions[1] = { x = 0, y = 90, z = 0, bucket = 0 }; W.sample() -- 90 m from the anchor
assert(payday() == 1 and paidTo(1) == 100, "walking or driving around the city counts")
now = now + 31 * 60000
-- a teleport is not a walk
positions[1] = { x = 5000, y = 90, z = 0, bucket = 0 }; W.sample()
assert(payday() == 0, "a jump of kilometres re-anchors without credit")
-- in an activity, in another bucket or downed: no movement credit, and the way back is not a walk
owned[1] = true; positions[1] = { x = 5100, y = 90, z = 0, bucket = 4100001 }; W.sample()
positions[1] = { x = 5300, y = 90, z = 0, bucket = 4100001 }; W.sample()
owned[1] = nil; positions[1] = { x = 5000, y = 300, z = 0, bucket = 0 }; W.sample()
assert(payday() == 0, "back from an activity is a teleport, not work")
lives[1] = "dead"; positions[1] = { x = 5000, y = 500, z = 0, bucket = 0 }; W.sample(); lives[1] = "alive"
assert(payday() == 0, "a downed player does not walk")
-- a position nil after two idle seconds falls back to players.get, never errors
W.sample() -- alive again: anchors here
positions[1] = nil; Open77.players.get = function() return { position = { x = 5000, y = 700, z = 0, bucket = 0 } } end
W.sample(); assert(payday() == 1, "the last known position is used")
Open77.players.get = nil; positions[1] = { x = 5000, y = 700, z = 0, bucket = 0 }

-- The old rule is one switch away.
P.requireActivity = false
now = now + 31 * 60000
assert(payday() == 2 and paidTo(1) == 100 and paidTo(2) == 225)
P.requireActivity = true
-- A character change or a disconnect forgets the activity.
LightRP.eachModule("onJobWorkCompleted", 1, "sanitation", "sell")
LightRP.eachModule("onCharacterSwitched", 1)
assert(payday() == 0)
print("paychecks_test: idle gets nothing (told once per streak), job tasks, patients, transfers, server-sampled movement (anchor, teleport, activity, downed, fallback), switch and window checks passed")
