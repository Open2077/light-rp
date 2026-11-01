-- op77_loadscreen: the cover state machine, the client wiring and the server front.
-- Run: pwsh -File tests/run-lua.ps1
dofile("client/cover.lua")
local C = LoadscreenCover

local function kinds(actions)
    local out = {}
    for _, a in ipairs(actions) do out[#out + 1] = a[1] end
    return table.concat(out, ",")
end

-- ---------------------------------------------------------------- normalize
local n = C.normalize({ title = ("x"):rep(200), subtitle = 5, zone = "Watson\n", timeoutMs = 1e9, target = { x = 1, y = 2 } })
assert(#n.title == 64 and n.subtitle == nil and n.zone == "Watson " and n.timeoutMs == C.defaults.maxTimeoutMs)
assert(n.target == nil, "a target needs x, y and z")
n = C.normalize({ id = 7, target = { x = 1, y = 2, z = 3 }, targetRadius = 0, expectedMs = 0 / 0 })
assert(n.id == "7" and n.target.z == 3 and n.targetRadius == 0.5 and n.expectedMs == C.defaults.expectedMs)
assert(C.normalize(nil).timeoutMs == C.defaults.timeoutMs)

-- ---------------------------------------------------------------- explicit request + release
local c = C.new()
local id = c:request({ title = "Kabuki Studio", zone = "Watson" }, 0)
local a = c:update(0, {})
assert(kinds(a) == "show" and a[1][2].title == "Kabuki Studio" and a[1][2].zone == "Watson")
assert(kinds(c:update(100, {})) == "", "shown once")
c:release(id, 500)
assert(kinds(c:update(500, {})) == "complete", "the bar lands first")
assert(kinds(c:update(1200, {})) == "", "still inside minVisibleMs (2200)")
assert(kinds(c:update(2300, {})) == "hide")
assert(not c:active())

-- a second request while shown refreshes the texts, not the cover
c = C.new()
c:request({ id = "a", title = "One" }, 0); c:update(0, {})
c:request({ id = "b", title = "Two" }, 300)
a = c:update(300, {})
assert(kinds(a) == "show" and a[1][2].title == "Two")
c:release("b", 400); a = c:update(400, {})
assert(kinds(a) == "show" and a[1][2].title == "One", "a is still open: its texts come back")
c:release(nil, 500); assert(kinds(c:update(500, {})) == "complete")

-- timeout
c = C.new()
c:request({ timeoutMs = 1000 }, 0); c:update(0, {})
assert(kinds(c:update(999, {})) == "")
assert(kinds(c:update(1000, {})) == "complete")
assert(kinds(c:update(2200, {})) == "hide")

-- ---------------------------------------------------------------- target release
c = C.new()
c:request({ target = { x = 100, y = 0, z = 0 } }, 0); c:update(0, {})
local far = { position = { x = 0, y = 0, z = 0 }, alive = true, grounded = true }
local there = { position = { x = 101, y = 1, z = 0.5 }, alive = true, grounded = true }
assert(kinds(c:update(1000, far)) == "")
assert(kinds(c:update(1500, there)) == "", "arrived: stability window starts")
assert(kinds(c:update(2000, { position = there.position, alive = true, grounded = false })) == "", "falling resets it")
assert(kinds(c:update(2100, there)) == "")
assert(kinds(c:update(2899, there)) == "")
assert(kinds(c:update(2900, there)) == "complete", "800 ms standing on the mark")
assert(kinds(c:update(3550, there)) == "hide")

-- a native loading screen holds a target request open
c = C.new()
c:request({ target = { x = 0, y = 0, z = 0 } }, 0); c:update(0, {})
c:native({ active = true, revision = 1 }, 100)
local here = { position = { x = 0, y = 0, z = 0 }, alive = true, grounded = true }
assert(kinds(c:update(2000, here)) == "")
c:native({ active = false, revision = 2 }, 2500)
assert(kinds(c:update(2600, here)) == "")
assert(kinds(c:update(3400, here)) == "complete")

-- ---------------------------------------------------------------- native-only covers
c = C.new()
c:native({ active = true, revision = 1 }, 0)
assert(kinds(c:update(100, {})) == "", "nativeDelayMs: a blink is not covered")
c:native({ active = true, revision = 2, progressKnown = true, progress = 0.4 }, 250)
a = c:update(250, {})
assert(kinds(a) == "show,progress" and a[2][2] == 0.4 and a[1][2].title == nil)
assert(kinds(c:update(300, {})) == "", "same progress is not resent")
c:native({ active = true, revision = 1 }, 310) -- an older snapshot is ignored
assert(c.nativeState.progress == 0.4)
c:native({ active = false, revision = 3, progressKnown = true, progress = 1 }, 900)
assert(kinds(c:update(900, {})) == "complete")
assert(kinds(c:update(1449, {})) == "", "nativeMinVisibleMs from 250")
assert(kinds(c:update(1550, {})) == "hide")

-- a cycle that blinks on and off before nativeDelayMs is never shown
c = C.new()
c:native({ active = true, revision = 1 }, 0)
c:native({ active = false, revision = 2 }, 50)
assert(kinds(c:update(60, {})) == "" and not c.visible)

-- a stuck native cycle is let go after nativeTimeoutMs
c = C.new()
c:native({ active = true, revision = 1 }, 0)
assert(kinds(c:update(300, {})) == "show")
assert(kinds(c:update(C.defaults.nativeTimeoutMs, {})) == "complete")
assert(kinds(c:update(C.defaults.nativeTimeoutMs + 700, {})) == "hide")

-- a native cycle that stops changing while the body stands up is over (a respawn
-- closes the game's loading screen without reporting it)
c = C.new()
local up = { position = { x = 0, y = 0, z = 0 }, alive = true, grounded = true }
c:native({ active = true, revision = 1 }, 0)
c:native({ active = true, revision = 2, progressKnown = true, progress = 0.39 }, 300)
assert(kinds(c:update(300, up)) == "show,progress")
c:native({ active = true, revision = 2, progressKnown = true, progress = 0.39 }, 2000) -- the same state, polled
assert(kinds(c:update(4299, up)) == "", "4 s since the last change")
assert(kinds(c:update(4300, up)) == "complete", "stale and standing: lifted")
assert(kinds(c:update(4950, up)) == "hide")
-- a moving bar keeps it up however long, and so does a body that is not up yet
c = C.new()
c:native({ active = true, revision = 1 }, 0)
assert(kinds(c:update(300, up)) == "show")
for t = 1000, 12000, 1000 do
    c:native({ active = true, revision = 1 + t, progressKnown = true, progress = t / 20000 }, t)
    assert(not kinds(c:update(t, up)):find("complete"), "progress still moving")
end
assert(kinds(c:update(15000, { alive = false })) == "", "a body not up keeps the cover")
assert(kinds(c:update(15000, { alive = true, grounded = false })) == "", "in the air keeps it too")
assert(kinds(c:update(16000, up)) == "complete")
assert(c:needsBody() == false or c.nativeState.active == true)

-- ---------------------------------------------------------------- client wiring
local clock = 0
local handlers, netHandlers, exported, threads = {}, {}, {}, {}
local sent, hudCalls, pageHandlers = {}, {}, {}
local loading = { active = false, revision = 0, kind = "unknown", progressKnown = false }
local body = { position = { x = 0, y = 0, z = 0 }, alive = true, grounded = true }
_G.Open77 = {
    time = { monotonic = function() return clock end },
    character = { state = function() return body end },
    hud = { setVisible = function(which, v) hudCalls[#hudCalls + 1] = which .. "=" .. tostring(v); return true end },
    screen = { loadingState = function() return loading end },
    webui = { create = function(opts)
        assert(opts.layer == "modal" and opts.visible == true and opts.transparent == true and opts.entry == "web/index.html")
        return {
            send = function(_, name, payload) sent[#sent + 1] = { name = name, payload = payload } end,
            on = function(_, name, fn) pageHandlers[name] = fn end,
            setFocus = function() return true end,
        }
    end },
}
_G.GetCurrentResourceName = function() return "op77_loadscreen" end
_G.AddEventHandler = function(name, fn) handlers[name] = fn end
_G.RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
_G.exports = function(name, fn) exported[name] = fn end
_G.CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
_G.Wait = function() coroutine.yield() end
local function runThreads() for _, t in ipairs(threads) do if coroutine.status(t) ~= "dead" then assert(coroutine.resume(t)) end end end
local function names() local o = {} for _, s in ipairs(sent) do o[#o + 1] = s.name end return table.concat(o, ",") end
local printed = {}
local realPrint = print
_G.print = function(...) printed[#printed + 1] = table.concat({ ... }, " ") end

dofile("client/main.lua")
assert(netHandlers["op77_loadscreen:cover"] and netHandlers["op77_loadscreen:release"] and handlers["open77:loadingScreen:changed"])
assert(exported.cover and exported.release and exported.isActive)
handlers.onClientResourceStart("other")
assert(pageHandlers["ui:ready"] == nil, "only our own start creates the page")
handlers.onClientResourceStart("op77_loadscreen")

-- a server cover before the page is ready is replayed on ready
netHandlers["op77_loadscreen:cover"]({ id = "lightrp:1", title = "Arrival Hall", target = { x = 50, y = 0, z = 0 } })
assert(#sent == 0 and hudCalls[1] == "all=false", "HUD hidden at once, page not ready yet")
pageHandlers["ui:ready"]()
assert(names() == "cover:show" and sent[1].payload.title == "Arrival Hall")
assert(exported.isActive() == true)
-- the body arrives on the mark: released by the client alone
clock = 1.0; body.position = { x = 50, y = 0, z = 0 }; runThreads()
clock = 1.9; runThreads()
assert(names() == "cover:show,cover:complete", names())
clock = 2.6; runThreads()
assert(names() == "cover:show,cover:complete,cover:hide" and hudCalls[2] == "all=true")
assert(exported.isActive() == false)

-- the server release path and a client export
sent = {}
local cid = exported.cover({ title = "Mission" })
assert(type(cid) == "string" and names() == "cover:show")
clock = 5.0; netHandlers["op77_loadscreen:release"]({ id = cid })
clock = 7.0; runThreads()
assert(names() == "cover:show,cover:complete,cover:hide", names())

-- a native loading screen is covered with its real progress
sent = {}
clock = 10.0; handlers["open77:loadingScreen:changed"]({ active = true, revision = 5, progressKnown = false })
clock = 10.3; runThreads()
handlers["open77:loadingScreen:changed"]({ active = true, revision = 6, progressKnown = true, progress = 0.5 })
assert(names() == "cover:show,cover:progress" and sent[2].payload.value == 0.5, names())
handlers["open77:loadingScreen:changed"]({ active = false, revision = 7, progressKnown = true, progress = 1 })
clock = 12.0; runThreads()
assert(names() == "cover:show,cover:progress,cover:complete,cover:hide", names())

-- an older client without loadingState still loads, with explicit covers only
handlers, netHandlers, exported = {}, {}, {}
Open77.screen = nil
dofile("client/main.lua")
assert(handlers["open77:loadingScreen:changed"] == nil and exported.cover)
assert(printed[#printed]:find("cannot report", 1, true))

-- ---------------------------------------------------------------- server front
local toClient = {}
local commands, timeouts = {}, {}
_G.TriggerClientEvent = function(name, player, payload) toClient[#toClient + 1] = { name = name, player = player, payload = payload } end
_G.RegisterCommand = function(name, fn, restricted) commands[name] = { fn = fn, restricted = restricted } end
_G.SetTimeout = function(ms, fn) timeouts[#timeouts + 1] = { ms = ms, fn = fn } end
exported = {}
dofile("server/main.lua")
local sid = exported.cover(3, { title = "Kabuki Studio" })
assert(sid == "srv:1" and toClient[1].name == "op77_loadscreen:cover" and toClient[1].player == 3 and toClient[1].payload.id == "srv:1")
assert(exported.cover(0, {}) == nil and exported.cover(1.5, {}) == nil, "player ids are validated")
assert(exported.release(3, sid) == true and toClient[2].payload.id == "srv:1")
assert(exported.release(3) == true and toClient[3].payload.id == nil, "nil releases everything")
assert(commands["loadscreen.test"].restricted == true)
commands["loadscreen.test"].fn(4, { "3" })
assert(toClient[4].player == 4 and timeouts[1].ms == 3000)
timeouts[1].fn()
assert(toClient[5].name == "op77_loadscreen:release" and toClient[5].payload.id == toClient[4].payload.id)

_G.print = realPrint
print("op77_loadscreen tests passed")
