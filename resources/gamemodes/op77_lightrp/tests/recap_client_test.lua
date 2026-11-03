-- The end-of-match recap, client side (client/core/recap.lua): never over a loading
-- screen, a dead or downed body, the creator, the F1 menu, another dialog or an action
-- bar; clear 750 ms in a row first; the newest match replaces a waiting one; F1 shows
-- it at once; given up after 60 s.
dofile("shared/events.lua")
local network, sent = {}, {}
local loading, alive, medical, acting = false, true, false, false
RegisterNetEvent = function(name, fn) network[name] = fn end
CreateThread = function() end
Wait = function() end
Open77 = { character = { state = function() return { alive = alive, grounded = true } end } }
LightRpMedical = { isActive = function() return medical end }
LightRpActions = { isActive = function() return acting end }
LightRpUi = { ready = true, characterReady = true, creationActive = false, menuOpen = false, actionFocus = false, dialogs = {},
    loadingScreen = function() return loading end,
    send = function(name, payload) sent[#sent + 1] = { name = name, payload = payload }; return true end }
dofile("client/core/recap.lua")
local E, R, Ui = LightRpEvents, LightRpRecap, LightRpUi
assert(network[E.net.recap] == R.receive, "the plain and latent event share the name")
local function ticks(n) for _ = 1, n do R.tick(250) end end
local function recap(id) return { kind = "recap", id = id, rows = { { id = 1 } } } end

-- clear: shown after 750 ms in a row, through the page's dialog channel
network[E.net.recap](recap("a"))
ticks(2)
assert(#sent == 0, "not before 750 ms clear")
ticks(1)
assert(#sent == 1 and sent[1].name == E.page.dialog and sent[1].payload.kind == "recap" and sent[1].payload.id == "a")
ticks(4)
assert(#sent == 1, "once")

-- every blocker holds it, and resets the streak
local blockers = {
    function(on) loading = on end,
    function(on) alive = not on end,
    function(on) medical = on end,
    function(on) acting = on end,
    function(on) Ui.creationActive = on end,
    function(on) Ui.menuOpen = on end,
    function(on) Ui.characterReady = not on end,
    function(on) Ui.dialogs.shop = on or nil end,
}
for i, set in ipairs(blockers) do
    sent = {}
    network[E.net.recap](recap("b" .. i))
    ticks(2)
    set(true)
    ticks(8)
    assert(#sent == 0, "blocker " .. i)
    set(false)
    ticks(2)
    assert(#sent == 0, "the streak starts again (" .. i .. ")")
    ticks(1)
    assert(#sent == 1 and sent[1].payload.id == "b" .. i, "shown once clear (" .. i .. ")")
end

-- the newest match replaces one still waiting
sent = {}
loading = true
network[E.net.recap](recap("old"))
network[E.net.recap](recap("new"))
ticks(10)
loading = false
ticks(3)
assert(#sent == 1 and sent[1].payload.id == "new")

-- F1 / recap: shown at once, a waiting one dropped
sent = {}
loading = true
network[E.net.recap](recap("waiting"))
local again = recap("again"); again.reopened = true
network[E.net.recap](again)
assert(#sent == 1 and sent[1].payload.id == "again")
loading = false
ticks(5)
assert(#sent == 1, "the waiting one is gone")

-- never clear for 60 s: given up, nothing pops up later
sent = {}
loading = true
network[E.net.recap](recap("late"))
ticks(60000 / 250 + 1)
loading = false
ticks(5)
assert(#sent == 0 and R.queued == nil)

-- junk is ignored
network[E.net.recap](nil)
network[E.net.recap]({ kind = "recap" })
ticks(5)
assert(#sent == 0)
print("recap_client_test: ok")
