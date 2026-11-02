-- Activity HUD (client/core/activity_hud.lua): validation and clamping of what another
-- resource sends, ownership (a newer Show replaces, pushes and clears of others refused),
-- rate limit, and the HUD going with its owner's stop/restart or a character change.
dofile("shared/events.lua")
local time, caller, callerGen, running, liveGen = 1000, nil, nil, true, {}
local handlers, network, exportsList, sent, thread = {}, {}, {}, {}, nil
GetGameTimer = function() return time end
GetCurrentResourceName = function() return "op77_lightrp" end
GetInvokingResource = function() return caller end
GetInvokingResourceGeneration = function() return callerGen end
GetResourceState = function() return running and "running" or "stopped" end
Open77 = { resource = { generation = function(name) return liveGen[name] or 1 end } }
CreateThread = function(fn) thread = coroutine.create(fn) end
Wait = function() coroutine.yield() end
AddEventHandler = function(name, fn) handlers[name] = fn end
RegisterNetEvent = function(name, fn) network[name] = fn end
exports = function(name, fn) exportsList[name] = fn end
LightRpUi = { page = {}, send = function(name, value) sent[#sent + 1] = { name = name, value = value }; return true end, log = function() end }
dofile("client/core/activity_hud.lua")
local E = LightRpEvents
local H = LightRpActivityHud
local Show, Push, Clear = exportsList.ActivityHudShow, exportsList.ActivityHudPush, exportsList.ActivityHudClear
assert(coroutine.resume(thread)) -- the watchdog waits for its first period
assert(Show and Push and Clear, "the three exports are registered")
local function last() return sent[#sent] end
local function tick() assert(coroutine.resume(thread)) end
local function count(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end return n end
local function as(resource, gen) caller, callerGen = resource, gen; if resource then liveGen[resource] = gen end end
network[E.net.state]({ character = { key = "slot1", status = "active" } })

-- a full HUD goes through, typed and clamped
as("op77_race", 4)
local long = string.rep("x", 300)
local stats, rows = {}, {}
for i = 1, 9 do stats[i] = { label = "S" .. i, value = i * 10 } end
for i = 1, 30 do rows[i] = { name = "Racer " .. i, values = { i, "0:4" .. i, "extra" }, self = i == 3 or i == 5, team = i % 2 == 0 and "Blue" or 1 } end
assert(Show({
    activity = "race.grid<script>", title = long, subtitle = "Street\nCircuit", phase = "running",
    timer = { remainingMs = 12345.7, label = "TIME", countUp = true }, countdown = 99999999, objective = 42,
    stats = stats,
    progress = { { id = "course", label = "Course", value = 1.7, tone = "magenta" }, { value = 0 / 0 }, { label = "Lap", value = -2, tone = "danger" }, { value = 0.5 }, { value = 0.25 } },
    teams = { { name = "Red", color = "#FF2E3C", score = 12, self = true }, { name = "Blue", color = "url(javascript:x)", score = "9" }, { color = "#fff" }, "bad", { name = "Green", color = "success" }, { name = "Gold" }, { name = "Fifth" } },
    scoreboard = { columns = { "CP", {}, "TIME", "4", "5th" }, rows = rows },
    hints = { { key = "HOME", label = "Restart" }, { key = "END" }, { key = "/race.leave", label = "Quit" }, { key = "F", label = "Interact" }, { key = "G", label = "Five" }, { key = "H", label = "Six" } },
}))
local msg = last()
assert(msg.name == E.page.activityHud and msg.value.op == "show")
local hud = msg.value.hud
assert(hud.activity == "race.gridscript", "ids keep identifier characters only: " .. hud.activity)
assert(#hud.title == 48 and hud.subtitle == "Street Circuit", "lengths cut, control characters replaced")
assert(hud.timer.remainingMs == 12345 and hud.timer.countUp == true and hud.timer.label == "TIME")
assert(hud.countdown == 60000, "countdown clamped to 60 s")
assert(hud.objective == "42", "numbers become text")
assert(#hud.stats == 4 and hud.stats[1].value == "10", "four stats at most")
assert(#hud.progress == 3, "three bars at most, the NaN one dropped")
assert(hud.progress[1].value == 1 and hud.progress[1].tone == "accent", "value clamped to 1, unknown tone back to accent")
assert(hud.progress[2].value == 0 and hud.progress[2].tone == "danger" and hud.progress[2].id == "p3")
assert(#hud.teams == 4, "nameless and non-table teams dropped, four at most")
assert(hud.teams[1].color == "#ff2e3c" and hud.teams[1].score == "12" and hud.teams[1].self == true)
assert(hud.teams[2].color == nil, "a colour is a hex or a tone, never CSS")
assert(hud.teams[3].name == "Green" and hud.teams[3].color == "success")
assert(#hud.scoreboard.columns == 4 and hud.scoreboard.columns[2] == "", "a bad header is kept blank so values stay aligned")
assert(#hud.scoreboard.rows == 16, "sixteen rows at most")
local r1, r3, r5 = hud.scoreboard.rows[1], hud.scoreboard.rows[3], hud.scoreboard.rows[5]
assert(#r1.values == 4 and r1.values[1] == "1" and r1.values[3] == "extra" and r1.values[4] == "-", "one value per column")
assert(r3.self == true and r5.self == nil, "one self row")
assert(r1.team == 1 and hud.scoreboard.rows[2].team == 2, "a team by index or by name")
assert(#hud.hints == 4 and hud.hints[2].key == "/race.leave", "hints need a key and a label, four at most")

-- defaults and refusals
assert(select(2, Show("nope")) == "invalid_hud")
assert(Show({ phase = "warmup", stats = {}, teams = { {} } }))
hud = last().value.hud
assert(hud.title == "Activity" and hud.phase == "running" and hud.stats == nil and hud.teams == nil, "empty lists stay out, unknown phase is running")
assert(Show({ phase = "countdown", countdown = 3 }))
assert(last().value.hud.countdown == 3000, "a small countdown is seconds")
assert(Show({ phase = "countdown", countdown = 2500, timer = { remainingMs = -5 } }))
assert(last().value.hud.countdown == 2500 and last().value.hud.timer.remainingMs == 0)
assert(Show({ timer = { remainingMs = "soon" } }) and last().value.hud.timer == nil)

-- pushes
local before = #sent
assert(Push("feed", { text = "Vi took the zone", tone = "success" }))
assert(last().value.op == "push" and last().value.kind == "feed" and last().value.item.tone == "success")
assert(select(2, Push("feed", { text = "" })) == "invalid_payload")
assert(select(2, Push("toast", { text = "x" })) == "invalid_kind")
assert(select(2, Push("banner", "x")) == "invalid_payload")
assert(Push("banner", { title = "FINAL LAP", durationMs = 60000, tone = "neon" }))
local banner = last().value.item
assert(banner.durationMs == 10000 and banner.tone == nil and banner.text == nil)
assert(Push("banner", { text = "Only a line" }) and last().value.item.durationMs == 3000)
assert(Push("result", { placement = 2, title = "Finished", subtitle = "Street Circuit",
    lines = { { label = "Time", value = "1:02.345" }, { value = "no label" }, { label = "Best lap", value = 61.25 } }, durationMs = 1 }))
local result = last().value.item
assert(result.placement == 2 and result.durationMs == 2000 and #result.lines == 2 and result.lines[2].value == "61.25")
assert(Push("result", { placement = "DNF" }) and last().value.item.placement == "DNF")
assert(select(2, Push("result", { placement = 0 })) == "invalid_payload", "a result needs a title or a placement")
assert(#sent == before + 5, "refused pushes send nothing")

-- ownership: another resource cannot push into or clear our HUD, but its Show replaces it
as("op77_arena", 2)
assert(select(2, Push("feed", { text = "intruder" })) == "not_owner")
assert(select(2, Clear()) == "not_owner")
assert(H.owner() == "op77_race")
assert(Show({ title = "Arena" }) and H.owner() == "op77_arena", "a newer Show replaces, whoever sends it")
as("op77_race", 4)
assert(select(2, Clear()) == "not_owner")
as("op77_arena", 2)
assert(Clear() and not H.isActive() and last().value.op == "clear")
assert(Clear(), "nothing to clear is fine")
-- transient items alone belong to nobody
assert(Push("result", { title = "Arena over" }) and H.owner() == "op77_arena" and not H.isActive())
as("op77_race", 4)
assert(Push("banner", { title = "GO" }) and H.owner() == "op77_race")
as(nil, nil)
assert(Clear(), "Light RP itself may always clear")

-- rate limit: 30 calls a second per owner
as("op77_race", 4)
local refused
for _ = 1, 40 do
    local ok, why = Show({ title = "Spam" })
    if not ok then refused = why end
end
assert(refused == "rate_limited")
time = time + 1100
assert(Show({ title = "Later" }), "the window moves on")

-- lifetime: owner stop, owner restart, character change
handlers.onClientResourceStop("op77_other")
assert(H.isActive(), "another resource's stop leaves it")
handlers.onClientResourceStop("op77_race")
assert(not H.isActive() and last().value.op == "clear" and last().value.reason == "owner_stopped")
assert(Show({ title = "Again" }))
liveGen.op77_race = 5
tick()
assert(not H.isActive() and last().value.reason == "owner_restarted")
liveGen.op77_race = 4
assert(Show({ title = "Again" }))
running = false; tick(); running = true
assert(not H.isActive(), "a stopped owner seen by the watchdog")
assert(Show({ title = "Again" }))
network[E.net.state]({ money = { cash = 3 } })
network[E.net.state]({ character = { key = "slot1", status = "active" } })
assert(H.isActive(), "the same character keeps it")
network[E.net.state]({ character = { key = "slot2", status = "active" } })
assert(not H.isActive() and last().value.reason == "character_changed")
assert(Show({ title = "Again" }))
network[E.net.state]({ character = { key = "slot2", status = "draft" } })
assert(not H.isActive(), "back to creation clears it")

-- no page: refused, nothing thrown
LightRpUi.page = nil
local ok, why = Show({ title = "No page" })
assert(not ok and why == "ui_unavailable")
LightRpUi.page = {}
assert(count(exportsList) == 3)
print("PASS: activity HUD (clamping of every field, defaults, pushes, ownership, transient items, rate limit, owner stop/restart, character change, no page)")
