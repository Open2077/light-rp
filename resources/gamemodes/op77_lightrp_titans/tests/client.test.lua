-- op77_lightrp_titans: client forwarder against a fake controller bridge.
--
-- Loads the REAL shared.lua and client.lua with fake Open77 services (time, log, rtti, scheduler, world reads), a fake
-- host (net events, threads, the frame tick, commands and key mappings the test steps by hand) and a fake bridge module
-- that hands the test the link client.lua gives it: `send(message)` for what the controller publishes and `poll()` for
-- what the server relayed. Messages cross as tables, in one Lua state: there is no mailbox and no text.
--
-- It asserts the start-up contract (the frame time is reserved before the controller is loaded, every way a start can
-- fail ends in one fixed code and one actionable log, and nothing runs after a failure), the frame tick, local
-- ownership and routing-envelope enforcement in both directions (frames and relayed states are forwarded as decoded:
-- their nested content belongs to the server's validator and the controller's bridge, which the shared validator calls
-- here stand in for), the queue between the server and the controller (ordering, replacement, bounds), the sustained
-- forwarding budget, the local-avatar hide window, the game's menu transitions and the two player actions handed to the
-- bridge. It does not prove the controller itself or the redscript forwarder; those are live acceptance. The schema twin section
-- loads the controller's real schema module and holds it to the resource's shared.lua.
--
-- The restart-handshake tests prove the answer to the server's probe (a server-only restart knows no client and the running
-- ones announce nothing more): the same fact start() announced, marked as an answer, only once start() has decided, the same
-- fixed code after a failed start, and nothing restarted, queued for the controller or sent besides that one event.
--
-- The Physical carry section proves the native-id -> canonical-id resolution (exact 64-bit text, ambient/unbound/
-- not-ready refusals, one answer per request) and that only the granted claim's own validated samples are forwarded.
--
-- The loadout section proves what the forwarder does with the server's grant and loadout updates: only a complete
-- validated map is relayed, only for the controller's own Titan and epoch and only when newer; a backlog never costs the
-- grant to newer updates; frames and states pay nothing for it; and the controller has no way to publish one.
--
-- The gameplay section proves that a server script's hit / repair reaches the controller only for its own Titan and epoch
-- as a validated closed message, that the controller's answer leaves only as a validated copy for them (and spends the
-- forwarding budget), and that a frame's gameplay report is forwarded as decoded for the server's validator to judge. The
-- observed-hit section proves that the controller's `hit_observed` report leaves as a validated closed copy on its own event,
-- only under its own grant, one per message, and spends the same budget. The core-credit section proves that a server core
-- credit reaches the controller only for its own Titan and epoch as a closed validated copy, and that the controller's answer of
-- that kind (taken with nothing added, with some, or refused) leaves only as a validated copy for them. The observed-status
-- section proves that the controller's `status_observed` report leaves as a validated closed copy on its own event, only under
-- its own grant, with an optional duration that is never invented, and spends the one forwarding budget the hits spend.
-- The player-hit section proves the same for `player_hit` (a victim, an attack record and a count, on its own event, under the
-- same budget). The heartbeat rides the frame tick (the resource holds no thread of its own), a frame the platform cut for its
-- time limit is reported once and the next frame runs, and an NPC's native id is resolved over the server-owned set
-- (Open77.npcs.all) with no world scan.
-- The session message carries the server's Titan PvP flag: delivered as sent, re-asserted by the keepalive as the server last
-- said it, a flag that is no boolean (or an unknown key) dropped whole.
--
-- Run from this resource's directory with any Lua 5.4 (from elsewhere, pass the resource's directory with its trailing slash):
--   lua tests/client.test.lua
local root = ... or "./"
local passed = 0
local report = print
print = function() end

local function test(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    passed = passed + 1
    report("PASS " .. name)
end

-- ---------------------------------------------------------------------------
-- Fakes. All tables are cleared in place so a fresh client.lua load sees them.
-- ---------------------------------------------------------------------------
local now = 100
local handlers, sent, logs, threads, ticks, puppet, commands, keymaps = {}, {}, {}, {}, {}, {}, {}, {}
local order, frames, menus, actions, reserved, polled = {}, {}, {}, {}, {}, {}
local link, verbose, current = nil, false, {}
local puppetResult = true

local function clear(tbl) for key in pairs(tbl) do tbl[key] = nil end end

-- Serializes a value deterministically, so a test can look for a number in what would leave this machine.
local function encode(value)
    if type(value) == "table" then
        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local parts = {}
        for _, key in ipairs(keys) do parts[#parts + 1] = string.format("%q:%s", tostring(key), encode(value[key])) end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif type(value) == "string" then
        return string.format("%q", value)
    end
    return tostring(value)
end

local rttiType = function() return {} end
Open77 = {
    time = { monotonic = function() return now end },
    log = {
        warn = function(text) logs[#logs + 1] = { "warn", text } end,
        error = function(text) logs[#logs + 1] = { "error", text } end,
    },
    players = { setLocalPuppetVisible = function(visible) puppet[#puppet + 1] = visible; return puppetResult end },
    rtti = {
        type = rttiType,
        global = function(name)
            if current.rtti == "missing" then error("function_not_found:" .. name, 0) end
            if current.rtti == "denied" then error("permission_denied:rtti.native", 0) end
            return function() end
        end,
    },
    scheduler = {
        reserve = function(microseconds)
            order[#order + 1] = "reserve"
            reserved[#reserved + 1] = microseconds
            if current.reserve == false then return nil, "permission_denied:scheduler.dedicated" end
            return true
        end,
    },
}
function GetCurrentResourceName() return "op77_lightrp_titans" end
function RegisterNetEvent(name, fn) handlers[name] = handlers[name] or {}; handlers[name][#handlers[name] + 1] = fn end
AddEventHandler = RegisterNetEvent
function TriggerServerEvent(name, ...) sent[#sent + 1] = { name = name, args = { ... } }; return true end
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function Wait(ms) return coroutine.yield(ms) end
function SetTick(fn) ticks[#ticks + 1] = fn end
function RegisterCommand(name, handler)
    if current.commands == false then return false, "refused" end
    commands[name] = handler
    return true
end
function RegisterKeyMapping(id, label, key, handler)
    if current.keys == false then return false, "permission_denied:input.actions" end
    keymaps[id] = { label = label, key = key, run = handler }
    return true, key
end
local exported = {}
function exports(name, fn) exported[name] = fn end
local function fire(name, ...)
    for _, fn in ipairs(handlers[name] or {}) do fn(...) end
end

-- The bridge module as client.lua sees it: what it is handed, and what it is asked to do.
local bridge = {
    link = function(handed) link = handed end,
    frame = function(delta)
        if current.frame == "raises" then error("the frame failed", 0) end
        if current.frame == "timelimit" then error("Open77 script execution budget exceeded (time limit)", 0) end
        frames[#frames + 1] = delta
    end,
    menu = function(scenario) menus[#menus + 1] = scenario end,
    bring = function() if current.action == "raises" then error("cannot bring", 0) end actions[#actions + 1] = "bring" end,
    resetCooldown = function() actions[#actions + 1] = "cooldown" end,
    logOn = function() return verbose end,
    setVerbose = function(on) verbose = on end,
}

Open77TitanCatalog = {
    variables = { bt_speed = true }, meshes = { mesh_gun = true }, lights = { light_eye = true },
    effects = { ["base\\fx\\muzzle.effect"] = true }, attachedEffects = { thruster = true },
    sounds = { bt_step = true }, slots = {},
}
local catalog = Open77TitanCatalog
-- The client resource host removes getmetatable and setmetatable (and more) before any resource script runs, so
-- nothing here can see or attach a metatable; the shared modules load into that sandbox, not the interpreter's
-- globals. dofile stays only as this harness's own loader.
setmetatable, getmetatable = nil, nil
dofile(root .. "loadout.lua")
dofile(root .. "shared.lua")
local T = Open77Titans
local V = T.protocol
local MSG = T.event.message

-- Starts the resource. `breaks` names what is made to fail: catalog = false, rtti = "unavailable" | "missing" |
-- "denied", reserve = false, controller = "missing" | "failed", bridge = "failed", commands = false, keys = false; and
-- `hold = true` loads the resource without starting it (onClientResourceStart is the test's to fire).
local function boot(breaks)
    for _, tbl in ipairs({ handlers, sent, logs, threads, ticks, puppet, commands, keymaps, order, frames, menus, actions, reserved, polled }) do clear(tbl) end
    current = breaks or {}
    link, verbose, puppetResult = nil, false, true
    now = now + 100
    if current.catalog == false then Open77TitanCatalog = nil else Open77TitanCatalog = catalog end
    Open77.rtti.type = current.rtti ~= "unavailable" and rttiType or nil
    package.loaded["controller.init"], package.loaded["controller.open77_titan_bridge"] = nil, nil
    package.preload["controller.init"] = function()
        order[#order + 1] = "controller"
        if current.controller == "missing" then error("module 'controller.init' not found", 0) end
        if current.controller == "failed" then error("attempt to call a nil value", 0) end
        return { fpf = {} }
    end
    package.preload["controller.open77_titan_bridge"] = function()
        order[#order + 1] = "bridge"
        if current.bridge == "failed" then error("the bridge module failed", 0) end
        return bridge
    end
    dofile(root .. "client.lua")
    if not current.hold then fire("onClientResourceStart", "op77_lightrp_titans") end
end

local function server(message) fire(MSG, message) end
local function sentNamed(name)
    local list = {}
    for _, event in ipairs(sent) do if event.name == name then list[#list + 1] = event.args end end
    return list
end
-- What the controller has taken from the server's queue, in order: everything waiting is polled first.
local function drain()
    assert(link, "the bridge was never linked")
    while true do
        local message = link.poll()
        if message == nil then return end
        polled[#polled + 1] = message
    end
end
local function delivered(op)
    drain()
    local list = {}
    for _, message in ipairs(polled) do if message.op == op then list[#list + 1] = message end end
    return list
end
local function polledCount() drain(); return #polled end
local function errorLogs(needle)
    local list = {}
    for _, entry in ipairs(logs) do
        if entry[1] == "error" and (needle == nil or entry[2]:find(needle, 1, true)) then list[#list + 1] = entry end
    end
    return list
end

local SESSION = { v = V, op = "session", active = true, player = "1" }
local function grantWith(changes)
    local message = { v = V, op = "grant", id = "9", epoch = 1, owner = "1", revision = 1, loadout = T.loadout.defaults() }
    for key, value in pairs(changes or {}) do message[key] = value end
    return message
end
local GRANT = grantWith()
-- A complete loadout update for the granted Titan; `changes` lowers perks, `extra` overrides message fields.
local function loadoutUpdate(revision, changes, extra)
    local map = T.loadout.defaults()
    for perk, level in pairs(changes or {}) do map[perk] = level end
    local message = { v = V, op = "loadout", id = "9", epoch = 1, revision = revision, loadout = map }
    for key, value in pairs(extra or {}) do message[key] = value end
    return message
end
local function sameMap(a, b)
    for key, value in pairs(a) do if b[key] ~= value then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function granted()
    boot()
    server(SESSION)
    server(GRANT)
end
local function cetFrame(extra)
    local body = {
        v = V, op = "frame", id = "9", epoch = 1, seq = 1, t = 0.05, pose = { x = 0, y = 0, z = 0, yaw = 0 },
        mode = "wait", weapon = "xo16", vars = { bt_speed = 1 }, meshes = {}, lights = {}, visuals = {}, events = {},
    }
    for key, value in pairs(extra or {}) do body[key] = value end
    return body
end
-- What the controller publishes: the link's send, true when the resource took the message.
local function publish(message) return link.send(message) end

-- ---------------------------------------------------------------------------
-- Start-up.
-- ---------------------------------------------------------------------------
test("a start reserves the frame time, loads the controller, links the bridge and only then says it is ready", function()
    boot()
    assert(table.concat(order, ",") == "reserve,controller,bridge", table.concat(order, ","))
    assert(#reserved == 1 and reserved[1] == 4000, "the whole of the reservable slice")
    assert(type(link) == "table" and type(link.send) == "function" and type(link.poll) == "function")
    local ready = sentNamed(T.event.ready)
    assert(#ready == 1 and ready[1][1].bridge == true and #logs == 0)
    assert(#ticks == 1 and #threads == 0, "one frame tick, no thread of its own: the heartbeat rides the frame")
    server(SESSION)
    assert(#delivered("session") == 1)
end)

local FAILURES = {
    { code = "bridge_missing", breaks = { catalog = false }, reserved = 0 },
    { code = "rtti_unavailable", breaks = { rtti = "unavailable" }, reserved = 0 },
    { code = "rtti_denied", breaks = { rtti = "denied" }, reserved = 0 },
    { code = "bridge_missing", breaks = { rtti = "missing" }, reserved = 0 },
    { code = "scheduler_denied", breaks = { reserve = false }, reserved = 1 },
    { code = "controller_missing", breaks = { controller = "missing" }, reserved = 1 },
    { code = "controller_failed", breaks = { controller = "failed" }, reserved = 1 },
    { code = "controller_failed", breaks = { bridge = "failed" }, reserved = 1 },
}
test("every way a start can fail ends in one fixed code and one actionable log, and nothing runs after it", function()
    for index, case in ipairs(FAILURES) do
        local label = case.code .. " #" .. index
        boot(case.breaks)
        local ready = sentNamed(T.event.ready)
        assert(#ready == 1 and ready[1][1].bridge == false and ready[1][1].reason == case.code, label)
        assert(#logs == 1 and logs[1][1] == "error" and logs[1][2]:find("[titans]", 1, true), label)
        assert(#reserved == case.reserved, label .. ": the frame time is reserved only once the game can be reached")
        assert(#ticks == 0 and #threads == 0 and link == nil, label .. ": nothing may run without the controller")
        assert(next(commands) == nil and next(keymaps) == nil, label .. ": no command or key for a controller that is not there")
        server(SESSION)
        fire("open77:menuStateChanged", "1", "1", "vanilla", "MenuScenario_PauseMenu")
        assert(#sent == 1 and #menus == 0, label .. ": an unavailable controller takes nothing")
    end
end)

test("the server's message handler is registered once: a grant reaches the controller once", function()
    granted()
    assert(#handlers[MSG] == 1, "one handler for the server's messages")
    assert(#delivered("grant") == 1 and #delivered("session") == 1)
end)

-- A restarted server knows no client and the running ones announce nothing more: it probes, and a client that has decided its
-- bridge answers with the same fact, marked as an answer.
local function answers() return sentNamed(T.event.ready) end

test("a probe is answered once with the readiness start() announced, as an answer, and changes nothing else", function()
    granted()
    assert(#handlers[T.event.probe] == 1, "one handler for the server's probe")
    local before, queued, ticked, threaded = #sent, polledCount(), #ticks, #threads
    fire(T.event.probe)
    local list = answers()
    assert(#list == 2 and list[1][1].answer == nil and list[1][1].bridge == true, "the start announced itself once, plainly")
    assert(list[2][1].bridge == true and list[2][1].answer == true and list[2][1].reason == nil, "the answer is the same fact")
    assert(#sent == before + 1 and sent[#sent].name == T.event.ready, "nothing but the one answer was sent")
    -- The controller never hears of it, nothing restarted, and the live session and grant still own the Titan.
    assert(polledCount() == queued and #ticks == ticked and #threads == threaded and #logs == 0 and #reserved == 1)
    assert(publish(cetFrame()) == true and #sentNamed(T.event.frame) == 1, "the grant still owns the Titan")
    assert(#sentNamed(T.event.request) == 0, "the probe asked for no spawn")
    -- Each probe is answered, from the same remembered fact, and a probe never changes it.
    fire(T.event.probe)
    list = answers()
    assert(#list == 3 and list[3][1].bridge == true and list[3][1].answer == true)
end)

test("a probe before start() has decided is not answered: the start announces on its own; none after the resource stopped", function()
    boot({ hold = true })
    assert(#handlers[T.event.probe] == 1, "the handler is registered at load, before any probe can arrive")
    fire(T.event.probe)
    assert(#sent == 0, "a client that has not decided its bridge claims nothing")
    fire("onClientResourceStart", "op77_lightrp_titans")
    local list = answers()
    assert(#list == 1 and list[1][1].bridge == true and list[1][1].answer == nil, "the start is announced plainly, exactly once")
    fire("onClientResourceStop", "op77_lightrp_titans")
    fire(T.event.probe)
    assert(#answers() == 1, "a stopped resource answers nothing")
end)

test("after a failed start a probe repeats the same fixed code as an answer, with no new log and no restart", function()
    for index, case in ipairs(FAILURES) do
        local label = case.code .. " #" .. index
        boot(case.breaks)
        local ticked, threaded, logged, reservedCount = #ticks, #threads, #logs, #reserved
        fire(T.event.probe)
        local list = answers()
        assert(#list == 2 and list[1][1].answer == nil and list[1][1].reason == case.code, label)
        assert(list[2][1].bridge == false and list[2][1].reason == case.code and list[2][1].answer == true, label)
        assert(#sent == 2 and #logs == logged and #ticks == ticked and #threads == threaded and #reserved == reservedCount
            and link == nil, label .. ": a probe starts nothing and says nothing new")
    end
end)

test("a refused send of the answer is reported once and is not an error", function()
    boot()
    local original = TriggerServerEvent
    TriggerServerEvent = function() return false, "network_unavailable" end
    fire(T.event.probe)
    fire(T.event.probe)
    TriggerServerEvent = original
    assert(#logs == 1 and logs[1][1] == "warn" and logs[1][2]:find("network_unavailable", 1, true), "reported once")
end)

test("the controller frame runs once per tick with the seconds since the last one", function()
    boot()
    ticks[1]()
    assert(#frames == 1 and math.abs(frames[1] - 1 / 30) < 1e-9, "the first frame has no earlier one")
    now = now + 0.05
    ticks[1]()
    assert(math.abs(frames[2] - 0.05) < 1e-9)
    now = now + 60
    ticks[1]()
    assert(frames[3] == 5.0, "a long gap is capped")
    now = now - 10
    ticks[1]()
    assert(frames[4] == 0.0, "a clock that went back never runs the controller backwards")
end)

test("a controller frame that fails is contained and reported, and the next frame runs", function()
    boot()
    current.frame = "raises"
    ticks[1]()
    ticks[1]()
    local warnings = {}
    for _, entry in ipairs(logs) do if entry[1] == "warn" and entry[2]:find("the controller frame failed", 1, true) then warnings[#warnings + 1] = entry end end
    assert(#warnings == 1, "one report, however often it recurs")
    current.frame = nil
    ticks[1]()
    assert(#frames == 1)
end)

test("a frame cut by the time limit is reported once and the next frame runs", function()
    boot()
    current.frame = "timelimit"
    ticks[1]()
    ticks[1]()
    local warnings = {}
    for _, entry in ipairs(logs) do
        if entry[1] == "warn" and entry[2]:find("(time limit)", 1, true) then warnings[#warnings + 1] = entry end
    end
    assert(#warnings == 1, "and reported once, however often it recurs")
    assert(#frames == 0, "the cut frame never completed")
    current.frame = nil
    ticks[1]()
    assert(#frames == 1, "the next frame ran")
end)

test("the game's menu transitions are handed to the controller, once it runs", function()
    boot()
    fire("open77:menuStateChanged", "1", "1", "vanilla", "MenuScenario_PauseMenu")
    fire("open77:menuStateChanged", "1", "0", "overlay", "")
    assert(#menus == 2 and menus[1] == "MenuScenario_PauseMenu" and menus[2] == "")
end)

test("the player's two actions are a command and a rebindable key each, and reach the bridge", function()
    boot()
    assert(type(commands.titanbring) == "function" and type(commands.titancooldown) == "function" and type(commands.titanlog) == "function")
    assert(keymaps["titans.bring"].key == "NUMPAD7" and keymaps["titans.cooldown"].key == "NUMPAD6")
    commands.titanbring()
    keymaps["titans.bring"].run()
    commands.titancooldown()
    keymaps["titans.cooldown"].run()
    assert(table.concat(actions, ",") == "bring,bring,cooldown,cooldown", table.concat(actions, ","))
    commands.titanlog()
    assert(verbose == true)
    commands.titanlog()
    assert(verbose == false)
end)

test("the control hints are one command that asks the render module to show or hide them", function()
    boot()
    assert(type(commands.titanhints) == "function")
    commands.titanhints()                                                            -- no render module (no page): nothing to switch, nothing raised
    local shown, asked = true, 0
    package.loaded["render"] = nil
    package.preload["render"] = function()
        return { toggleHints = function() asked = asked + 1; shown = not shown; return shown end, destroy = function() end }
    end
    commands.titanhints()
    assert(asked == 1 and shown == false)
    commands.titanhints()
    assert(asked == 2 and shown == true)
    package.preload["render"], package.loaded["render"] = nil, nil
    boot({ commands = false })
    assert(commands.titanhints == nil, "the command needs the commands' own permission, like the others")
end)

test("an action that fails is contained and reported once; a refused key leaves the commands in place", function()
    boot()
    current.action = "raises"
    commands.titanbring()
    commands.titanbring()
    local failed = {}
    for _, entry in ipairs(logs) do if entry[2]:find("action failed", 1, true) then failed[#failed + 1] = entry end end
    assert(#failed == 1 and #actions == 0)
    boot({ keys = false })
    assert(next(keymaps) == nil and commands.titanbring and commands.titancooldown, "the commands do not need the permission")
    local refused = {}
    for _, entry in ipairs(logs) do if entry[2]:find("has no key", 1, true) then refused[#refused + 1] = entry end end
    assert(#refused == 2, "one report for each key")
    boot({ commands = false })
    assert(commands.titanbring == nil and keymaps["titans.bring"] ~= nil, "the keys do not need the commands")
end)

-- ---------------------------------------------------------------------------
-- The server's messages on their way to the controller.
-- ---------------------------------------------------------------------------
test("server messages are validated before they are queued; a relayed state by its routing envelope", function()
    boot(); server(SESSION)
    local state = {
        v = V, op = "state", id = "9", epoch = 1, owner = "2", seq = 3, t = 1, serverTime = 5,
        pose = { x = 0, y = 0, z = 0, yaw = 0 }, mode = "wait", weapon = "xo16",
        vars = {}, meshes = {}, lights = {}, visuals = {}, events = {},
    }
    server(state)
    assert(#delivered("state") == 1 and delivered("state")[1] == state, "a state is delivered as received")
    local before = polledCount()
    local function broken(mutate)
        local copy = {}
        for key, value in pairs(state) do copy[key] = value end
        mutate(copy)
        return copy
    end
    for _, bad in ipairs({
        { v = V, op = "state", id = "9", epoch = 1, owner = "2", seq = 3, t = 1, serverTime = 5, mode = "wait" },
        broken(function(m) m.id = 9 end),
        broken(function(m) m.owner = "x" end),
        broken(function(m) m.epoch = 0 end),
        broken(function(m) m.seq = 1.5 end),
        broken(function(m) m.t = -1 end),
        broken(function(m) m.t = 0 / 0 end),
        broken(function(m) m.serverTime = -1 end),
        broken(function(m) m.mode = "fly" end),
        broken(function(m) m.pose = { x = 0 / 0, y = 0, z = 0, yaw = 0 } end),
        broken(function(m) m.pose = { x = 2000000, y = 0, z = 0, yaw = 0 } end),
        broken(function(m) m.pose = { x = 0, y = 0, z = 0, yaw = 4000 } end),
        broken(function(m) m.events = nil end),
        broken(function(m) m.events = "none" end),
        { v = V, op = "remove", id = "9", epoch = 1, reason = "because" },
        { v = V, op = "command", action = "weapon", value = "laser" },
        { v = V, op = "command", action = "load", value = "x" },
        grantWith({ epoch = 0 }),
        grantWith({ extra = "x" }),
        { v = V, op = "error", reason = "Not A Token" },
        -- The previous wire version is never delivered: not a v1 grant (no loadout), session or state.
        { v = 1, op = "session", active = true, player = "1" },
        { v = 1, op = "grant", id = "9", epoch = 1, owner = "1" },
        { v = 1, op = "state", id = "9", epoch = 1, owner = "2", seq = 3, t = 1, serverTime = 5 },
        { v = V + 1, op = "session", active = true, player = "1" },
        { v = V, op = "execute", code = "os.exit()" },
        "text",
    }) do server(bad) end
    assert(polledCount() == before, "a malformed server message reached the controller")
    -- Nothing nested is walked here: the controller's bridge (schema.inbound) validates a relayed
    -- state's maps, visuals and events and drops what it refuses. The state is not copied.
    local nested = broken(function(m)
        m.extra = "x"
        m.vars = { not_in_catalog = 1 }
        m.events = { { kind = "fx_stop", seq = 1, fxId = "a", extra = 1 } }
    end)
    server(nested)
    assert(polledCount() == before + 1 and polled[before + 1] == nested)
end)

test("the controller reads its messages in order, and a newer state replaces an older motion-only one", function()
    boot(); server(SESSION)
    server(GRANT)
    local function state(seq)
        return { v = V, op = "state", id = "9", epoch = 1, owner = "2", seq = seq, t = seq, serverTime = 5,
            pose = { x = 0, y = 0, z = 0, yaw = 0 }, mode = "wait", weapon = "xo16",
            vars = {}, meshes = {}, lights = {}, visuals = {}, events = {} }
    end
    server(state(1)); server(state(2)); server(state(3))
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_removed" })
    assert(#polled == 0, "nothing is read until the controller polls")
    local ops = {}
    drain()
    for index = 1, #polled do ops[#ops + 1] = polled[index].op end
    assert(table.concat(ops, ",") == "session,grant,state,remove", table.concat(ops, ","))
    assert(delivered("state")[1].seq == 3, "the stale states must have been replaced")
end)

local function remoteState(seq, events, id)
    return { v = V, op = "state", id = id or "9", epoch = 1, owner = "2", seq = seq, t = seq, serverTime = 5,
        pose = { x = seq, y = 0, z = 0, yaw = 0 }, mode = "wait", weapon = "xo16",
        vars = {}, meshes = {}, lights = {}, visuals = {}, events = events or {} }
end
local function stop(fxId, seq) return { kind = "fx_stop", seq = seq, fxId = fxId } end

test("a state that carries events is never merged or dropped; only motion-only states are replaced", function()
    boot(); server(SESSION)
    server(remoteState(1, { stop("a", 1) }))         -- carries a one-shot: must survive
    server(remoteState(2))                           -- motion only
    server(remoteState(3))                           -- motion only: replaces 2
    server(remoteState(4, { stop("b", 2), stop("c", 3) }))
    server(remoteState(5))                           -- the newest pose, after both events
    local states = delivered("state")
    local order = {}
    for index, message in ipairs(states) do order[index] = message.seq .. ":" .. #message.events end
    assert(table.concat(order, ",") == "1:1,4:2,5:0", table.concat(order, ","))
    assert(states[1].events[1].fxId == "a" and states[2].events[1].fxId == "b" and states[2].events[2].fxId == "c")
    assert(states[3].pose.x == 5, "the latest pose must be what the controller ends up with")
    assert(#delivered("state") == 3, "each event-bearing state is delivered exactly once")
    -- Different Titans never supersede each other.
    local base = polledCount()
    server(remoteState(1, nil, "20")); server(remoteState(1, nil, "21")); server(remoteState(2, nil, "20"))
    drain()
    local seen = {}
    for index = base + 1, #polled do seen[#seen + 1] = polled[index].id .. "@" .. polled[index].seq end
    assert(table.concat(seen, ",") == "21@1,20@2", table.concat(seen, ","))
end)

test("an overfull backlog drops motion first, then the oldest event-bearing state, and says so", function()
    boot(); server(SESSION); drain()
    for seq = 1, 70 do server(remoteState(seq, { stop("e" .. seq, seq) })) end
    local errors = errorLogs("dropped")
    assert(#errors == 1 and errors[1][2]:find("shot/sound event", 1, true), "event loss must be reported as an error")
    local states = delivered("state")
    assert(#states == 64 and states[1].seq == 7 and states[64].seq == 70, "the oldest six were shed, FIFO kept")
    -- Motion-only states go before any event-bearing one.
    boot(); server(SESSION); drain()
    for seq = 1, 64 do server(remoteState(seq, { stop("e" .. seq, seq) }, tostring(seq))) end
    server(remoteState(99, nil, "999"))
    states = delivered("state")
    assert(#states == 64 and states[1].seq == 1 and states[64].seq == 64, "no event-bearing state was sacrificed for motion")
end)

test("a backlog keeps the grant and only the newest loadout of a Titan, in order", function()
    boot(); server(SESSION)
    server(GRANT)
    server(loadoutUpdate(2, { sentry = 0 }))
    server(remoteState(1, nil, "20"))
    server(loadoutUpdate(3, { sentry = 1, burstcore = 0 }))
    for revision = 4, 200 do server(loadoutUpdate(revision, { burstcore = revision % 4 })) end
    drain()
    local ops, revisions = {}, {}
    for _, message in ipairs(polled) do
        ops[#ops + 1] = message.op
        if message.op == "loadout" then revisions[#revisions + 1] = message.revision end
    end
    assert(table.concat(ops, ",") == "session,grant,state,loadout", table.concat(ops, ","))
    assert(#revisions == 1 and revisions[1] == 200, "only the newest word of the Titan survives")
    assert(delivered("grant")[1].revision == 1 and delivered("loadout")[1].loadout.burstcore == 0)
    for _, entry in ipairs(logs) do assert(not entry[2]:find("dropped", 1, true), "the backlog shed something: " .. entry[2]) end
end)

test("the heartbeat rides the frame tick, re-asserts the session without piling up and keeps its period", function()
    boot()
    assert(#threads == 0, "no thread of its own")
    local period = T.limits.heartbeat
    for _ = 1, 4 do now = now + period; ticks[1]() end
    assert(#delivered("session") == 0, "no session, no keepalive")
    server(SESSION)
    for _ = 1, 4 do now = now + period; ticks[1]() end
    assert(#delivered("session") == 1, "one pending keepalive, however many beats")
    for _ = 1, 3 do now = now + period; ticks[1]() end
    local second = delivered("session")[2]
    assert(#delivered("session") == 2 and second.active == true and second.player == "1", "and it is the session as the server last said it")
    -- Ticks inside the period beat nothing; the one that completes it does.
    now = now + period / 2
    ticks[1]()
    assert(#delivered("session") == 2, "no beat inside the period")
    now = now + period / 2
    ticks[1]()
    assert(#delivered("session") == 3, "the beat at the period")
end)

test("the server's Titan PvP flag rides the session message: delivered as sent, re-asserted as last said, a malformed one dropped", function()
    boot()
    server({ v = V, op = "session", active = true, player = "1", pvp = true })
    local first = delivered("session")
    assert(#first == 1 and first[1].active == true and first[1].pvp == true, "the controller is told the flag")
    -- The keepalive re-delivers the session as the server last said it, flag included ...
    now = now + T.limits.heartbeat
    ticks[1]()
    assert(#delivered("session") == 2 and delivered("session")[2].pvp == true, "the keepalive lost the flag")
    -- ... and a change is a new session message that replaces it: the newest word is the one every later beat carries.
    server({ v = V, op = "session", active = true, player = "1", pvp = false })
    assert(delivered("session")[3].pvp == false)
    now = now + T.limits.heartbeat
    ticks[1]()
    assert(#delivered("session") == 4 and delivered("session")[4].pvp == false and delivered("session")[4].active == true)
    -- A session without the flag (an older word, or the message that ends it) carries none; a flag that is no boolean is dropped whole.
    server({ v = V, op = "session", active = false, player = "1" })
    local ended = delivered("session")
    assert(ended[#ended].active == false and ended[#ended].pvp == nil)
    boot()
    for _, bad in ipairs({ 1, 0, "true", "", {}, print }) do
        server({ v = V, op = "session", active = true, player = "1", pvp = bad })
    end
    assert(#delivered("session") == 0, "a malformed flag reached the controller")
    server({ v = V, op = "session", active = true, player = "1", pvp = true, extra = 1 })
    assert(#delivered("session") == 0, "a session with a key nobody knows reached the controller")
end)

test("the end of a session reaches the controller; a session that follows replaces it", function()
    boot(); server(SESSION)
    drain()
    server({ v = V, op = "session", active = false, player = "1" })
    assert(#delivered("session") == 2 and delivered("session")[2].active == false)
    -- Between two polls the newest word of the session is the only one: the controller never sees a lapse it missed.
    boot(); server(SESSION)
    server({ v = V, op = "session", active = false, player = "1" })
    server(SESSION)
    assert(#delivered("session") == 1 and delivered("session")[1].active == true)
end)

test("stopping the resource ends its heartbeat and leaves nothing hidden", function()
    granted()
    publish(cetFrame({ mode = "pilot" }))
    assert(#puppet == 1 and puppet[1] == false)
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_dead" })
    local count = #puppet
    fire("onClientResourceStop", "op77_lightrp_titans")
    assert(#puppet == count, "nothing is hidden at stop")
    assert(#threads == 0, "the heartbeat has no thread left to outlive the resource")
end)

-- ---------------------------------------------------------------------------
-- What the controller sends the server.
-- ---------------------------------------------------------------------------
test("controller frames are forwarded as decoded for the granted id and epoch; the server validates the rest", function()
    granted()
    publish(cetFrame({ id = "10", mode = "pilot" }))
    publish(cetFrame({ epoch = 2, mode = "pilot" }))
    publish({ v = V, op = "execute", code = "boom" })
    publish(cetFrame({ v = 1, mode = "pilot" }))   -- the previous wire version is never forwarded
    -- A malformed routing envelope is refused here: nothing is forwarded and, even
    -- for a pilot frame, the local avatar is left alone.
    for _, bad in ipairs({
        { id = 9 }, { epoch = 0 }, { seq = "1" }, { seq = 0 }, { t = 0 / 0 }, { t = -1 }, { mode = "fly" },
        { pose = false }, { pose = { x = 0 / 0, y = 0, z = 0, yaw = 0 } },
        { pose = { x = 2000000, y = 0, z = 0, yaw = 0 } }, { pose = { x = 0, y = 0, z = 0, yaw = 4000 } },
        { pose = { x = 0, y = 0, z = 0 } },
    }) do
        bad.mode = bad.mode or "pilot"
        publish(cetFrame(bad))
    end
    assert(#sentNamed(T.event.frame) == 0, "an invalid or unowned frame was forwarded")
    assert(#puppet == 0, "a refused frame changed the local avatar")
    assert(publish(cetFrame()) == true, "a frame the resource took")
    local sentFrames = sentNamed(T.event.frame)
    assert(#sentFrames == 1 and sentFrames[1][1].v == V and sentFrames[1][1].op == "frame" and sentFrames[1][1].id == "9")
    assert(sentFrames[1][1].vars.bt_speed == 1)
    -- Nested content is not walked here: the frame goes as decoded and the server's own
    -- validator (T.normalizeFrame) is what refuses it or strips an item.
    local unknownVar = cetFrame({ seq = 2, vars = { not_in_catalog = 1 } })
    publish(unknownVar)
    sentFrames = sentNamed(T.event.frame)
    assert(#sentFrames == 2 and sentFrames[2][1] == unknownVar)
    assert(T.normalizeFrame(unknownVar, Open77TitanCatalog) == nil, "the server must still refuse it")
    local mixed = cetFrame({ seq = 3, events = { { kind = "fx_stop", seq = 1, fxId = "a", extra = 1 }, { kind = "fx_stop", seq = 2, fxId = "b" } } })
    publish(mixed)
    sentFrames = sentNamed(T.event.frame)
    assert(#sentFrames == 3 and sentFrames[3][1] == mixed and #mixed.events == 2, "forwarded untouched")
    local clean, _, dropped = T.normalizeFrame(mixed, Open77TitanCatalog)
    assert(clean and dropped == 1 and #clean.events == 1 and clean.events[1].fxId == "b", "the server strips the bad item")
    -- Requests are a closed set.
    publish({ v = V, op = "request", action = "spawn" })
    publish({ v = V, op = "request", action = "remove" })
    publish({ v = V, op = "request", action = "fly" })
    local requests = sentNamed(T.event.request)
    assert(#requests == 2 and requests[1][1] == "spawn" and requests[2][1] == "remove")
end)

-- 24 fx_spawn events (the most one frame may carry) and 8 persistent visuals: the
-- effect-heavy snapshot of a Titan firing everything at once, about 900 keyed
-- nodes, inside the 1000 the server accepts.
local function heavyEvents(first)
    local events = {}
    for index = 1, T.limits.events do
        local seq = first + index - 1
        events[index] = {
            kind = "fx_spawn", seq = seq, fxId = "fx" .. seq, path = "base\\fx\\muzzle.effect", loop = index % 2 == 0,
            position = { x = index, y = 2 * index, z = 3 }, rotation = { x = 0, y = 0, z = 0.5, w = 0.5 },
        }
    end
    return events
end
local function heavyVisuals()
    local visuals = {}
    for index = 1, 8 do
        visuals[index] = { kind = "fx", fxId = "loop" .. index, path = "base\\fx\\muzzle.effect", loop = true,
            position = { x = index, y = 0, z = 1 } }
    end
    return visuals
end
local function inOrder(events, first)
    assert(#events == T.limits.events, "an event was lost: " .. #events)
    for index, event in ipairs(events) do
        assert(event.seq == first + index - 1 and event.fxId == "fx" .. (first + index - 1), "events out of order")
    end
end

test("a maximum effect-heavy frame or state is forwarded whole, in order and uncopied", function()
    granted()
    local frame = cetFrame({ seq = 7, events = heavyEvents(100), visuals = heavyVisuals() })
    publish(frame)
    local sentFrames = sentNamed(T.event.frame)
    assert(#sentFrames == 1 and sentFrames[1][1] == frame, "the frame must be forwarded as decoded, not discarded or rebuilt")
    inOrder(sentFrames[1][1].events, 100)
    -- It is a frame the server's validator keeps whole: nothing here was shed on its behalf.
    local clean, why, dropped = T.normalizeFrame(frame, Open77TitanCatalog)
    assert(clean, tostring(why))
    assert(dropped == 0 and #clean.visuals == 8 and T.countNodes(clean) <= T.limits.nodes)
    inOrder(clean.events, 100)
    -- The relayed direction: delivered as received, and kept in order behind a backlog.
    local relay = remoteState(8, heavyEvents(100))
    relay.visuals = heavyVisuals()
    server(relay)
    assert(#delivered("state") == 1 and delivered("state")[1] == relay)
    inOrder(delivered("state")[1].events, 100)
    local second = remoteState(9, heavyEvents(124))
    second.visuals = heavyVisuals()
    server(second)
    server(remoteState(10))
    local states = delivered("state")
    assert(#states == 3 and states[2] == second and states[3].seq == 10, "event-bearing state kept, newest pose last")
    inOrder(states[2].events, 124)
end)

test("frames before a grant, after a remove, or after the session ends are dropped", function()
    boot(); server(SESSION)
    publish(cetFrame())
    assert(#sentNamed(T.event.frame) == 0, "frame without a grant")
    server(GRANT)
    publish(cetFrame())
    assert(#sentNamed(T.event.frame) == 1)
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_dead" })
    publish(cetFrame({ seq = 2 }))
    assert(#sentNamed(T.event.frame) == 1, "frame after remove")
    server(GRANT)
    server({ v = V, op = "session", active = false, player = "1" })
    publish(cetFrame({ seq = 3 }))
    assert(#sentNamed(T.event.frame) == 1, "frame after session end")
    -- A grant for somebody else's player id is not ours.
    server(SESSION)
    server(grantWith({ id = "11", owner = "2" }))
    publish(cetFrame({ id = "11", seq = 4 }))
    assert(#sentNamed(T.event.frame) == 1)
end)

test("the local avatar is hidden exactly while piloting and restored on every exit", function()
    granted()
    publish(cetFrame({ mode = "wait" }))
    assert(#puppet == 0)
    publish(cetFrame({ mode = "pilot", seq = 2 }))
    assert(#puppet == 1 and puppet[1] == false)
    publish(cetFrame({ mode = "pilot", seq = 3 }))
    assert(#puppet == 1, "hide must not repeat")
    publish(cetFrame({ mode = "dismount", seq = 4 }))
    assert(#puppet == 2 and puppet[2] == true)
    publish(cetFrame({ mode = "pilot", seq = 5 }))
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_dead" })
    assert(puppet[#puppet] == true, "removal while piloting must restore the avatar")
    local count = #puppet
    fire("onClientResourceStop", "op77_lightrp_titans")
    assert(#puppet == count, "nothing is hidden at stop")
    -- A refused hide is retried on the next frame instead of being believed.
    granted()
    puppetResult = false
    publish(cetFrame({ mode = "pilot" }))
    publish(cetFrame({ mode = "pilot", seq = 2 }))
    assert(#puppet == 2, "a failed hide must be retried")
end)

test("forwarding is budgeted: a refused send is the controller's cue to hold, and the budget refills with time", function()
    granted()
    local accepted = 0
    for _ = 1, 100 do
        if publish({ v = V, op = "request", action = "spawn" }) then accepted = accepted + 1 end
    end
    assert(accepted == 30, "the burst, no more: " .. accepted)
    assert(#sentNamed(T.event.request) == accepted, "what was refused was not forwarded")
    now = now + 1
    assert(publish({ v = V, op = "request", action = "spawn" }) == true, "the budget refills with time")
end)

test("the controller's liveness beat is consumed locally: never relayed, validated or budgeted", function()
    granted()
    for index = 1, 100 do assert(publish({ v = V, op = "heartbeat", n = index }) == true) end
    assert(#sent == 1 and sent[1].name == T.event.ready, "a heartbeat reached the server: " .. #sent)
    -- 100 beats cost no forwarding budget: the full burst of 30 requests still passes.
    for _ = 1, 30 do assert(publish({ v = V, op = "request", action = "spawn" }) == true) end
    assert(#sentNamed(T.event.request) == 30)
    -- And a beat does not need a grant, frame or catalog entry.
    boot(); server(SESSION)
    publish({ v = V, op = "heartbeat", n = 1 })
    assert(#sent == 1)
end)

-- ---------------------------------------------------------------------------
-- Physical carry: the controller names a native body by the exact decimal text of
-- its REDengine id; only the canonical id the replication layer assigned leaves
-- this machine. The fakes mirror the real reads: world rows publish the engine id
-- as a Lua INTEGER (an unsigned 64-bit id above 2^63 is its negative twin), the
-- vehicle lookup takes the id as decimal text, and an NPC has no lookup of its own.
-- ---------------------------------------------------------------------------
local TOKEN = string.rep("ab", 16)
local rows, snapshots, vehicleLookups, npcCalls, npcFailure = {}, { vehicle = {} }, {}, {}, nil
-- The server-owned NPC set: vanilla population peds are in no row, and every row is a canonical NPC's snapshot (its Open77 `id`,
-- the REDengine id as `engineEntity`, and the replicated readiness). There is no world scan at all: Open77.world is not even
-- defined here, so a client that still asked for one would fail every test below.
Open77.npcs = {
    all = function(...)
        npcCalls[#npcCalls + 1] = select("#", ...)
        if npcFailure then return nil, npcFailure end
        return rows
    end,
}
Open77.vehicles = {
    fromEntity = function(entity)
        vehicleLookups[#vehicleLookups + 1] = entity
        local found = snapshots.vehicle[entity]   -- keyed by the exact decimal TEXT: a number finds nothing
        if found == nil then return nil, "unknown_entity" end
        if type(found) == "string" then return nil, found end
        return found
    end,
}

local function carryWorld()
    clear(rows); clear(snapshots.vehicle); clear(vehicleLookups); clear(npcCalls)
    npcFailure = nil
end

local requestNumber = 0
local function controllerRequest(kind, entity, extra)
    requestNumber = requestNumber + 1
    local message = { v = V, op = "carry_request", id = "9", epoch = 1, request = requestNumber, kind = kind, entity = entity }
    for key, value in pairs(extra or {}) do message[key] = value end
    publish(message)
    return message
end
local function carryEvents() return sentNamed(T.event.carry) end
local function lastDenial()
    local list = delivered("carry_denied")
    return list[#list]
end
local function answerDenied(request)
    server({ v = V, op = "carry_denied", id = "9", epoch = 1, request = request.request, reason = "target_far" })
end
local function carryPose(extra)
    local pose = { x = 1, y = 2, z = 3, yaw = 10, qx = 0, qy = 0, qz = 0, qw = 1, vx = 0, vy = 0, vz = 0, phase = "hold" }
    for key, value in pairs(extra or {}) do pose[key] = value end
    return pose
end
local function controllerSample(op, extra, pose)
    local message = { v = V, op = op, id = "9", epoch = 1, token = TOKEN, seq = 1, t = 0.05, pose = carryPose(pose) }
    if op == "carry_release" then message.reason = "landed" end
    for key, value in pairs(extra or {}) do message[key] = value end
    publish(message)
    return message
end
-- A Titan with a granted claim on canonical NPC 31 (native 4003).
local function claimed()
    granted(); carryWorld()
    rows[1] = { engineEntity = 4003, id = 31, streamed = true, entity = 9, health = 100 }
    local request = controllerRequest("npc", "4003")
    server({ v = V, op = "carry_grant", id = "9", epoch = 1, request = request.request, kind = "npc", entityId = "31", token = TOKEN })
    assert(#delivered("carry_grant") == 1, "the grant must reach the controller")
    return request
end

test("an NPC's native id resolves to its canonical id by exact 64-bit text, never through a float", function()
    granted(); carryWorld()
    -- 2^53 and 2^53 + 1 are the SAME double: a float conversion cannot tell these bodies apart.
    local function ready(id, engine) return { engineEntity = engine, id = id, streamed = true, entity = 100 + id, health = 100 } end
    rows[1] = ready(11, 9007199254740992)
    rows[2] = ready(12, 9007199254740993)
    rows[3] = ready(13, -1)                              -- 2^64 - 1
    rows[4] = ready(14, math.mininteger)                 -- 2^63
    rows[5] = ready(15, math.mininteger + 5)             -- 2^63 + 5
    local expected = {
        ["9007199254740992"] = "11", ["9007199254740993"] = "12", ["18446744073709551615"] = "13",
        ["9223372036854775808"] = "14", ["9223372036854775813"] = "15",
    }
    local count = 0
    for text, canonical in pairs(expected) do
        count = count + 1
        local request = controllerRequest("npc", text)
        local events = carryEvents()
        assert(#events == count, "no request reached the server for " .. text)
        local wire = events[count][1]
        assert(wire.entityId == canonical, text .. " resolved to " .. tostring(wire.entityId))
        assert(wire.entity == nil and wire.op == "carry_request" and wire.request == request.request)
        assert(wire.id == "9" and wire.epoch == 1 and wire.kind == "npc")
        for key in pairs(wire) do
            assert(({ v = true, op = true, id = true, epoch = true, request = true, kind = true, entityId = true })[key], key)
        end
        assert(not encode(wire):find(text, 1, true), "the native id must never be on the wire")
        answerDenied(request)
    end
    assert(#npcCalls == 5 and npcCalls[1] == 0 and npcCalls[5] == 0, "the server-owned set, asked for with no argument")
    -- Another 64-bit id with no row is no networked body, and is not rounded onto a neighbour.
    controllerRequest("npc", "9223372036854775809")
    assert(lastDenial().reason == "not_networked" and #carryEvents() == 5)
end)

test("a vehicle's native id is looked up as decimal text and checked against the answer", function()
    granted(); carryWorld()
    snapshots.vehicle["18446744073709551614"] = { id = 21, engineEntity = -2, entity = 5000, streamed = true }
    snapshots.vehicle["9007199254740993"] = { id = 22, engineEntity = 9007199254740993, streamed = true }
    local request = controllerRequest("vehicle", "18446744073709551614")
    local wire = carryEvents()[1][1]
    assert(wire.entityId == "21" and wire.kind == "vehicle" and wire.entity == nil)
    assert(not encode(wire):find("18446744073709551614", 1, true))
    answerDenied(request)
    request = controllerRequest("vehicle", "9007199254740993")
    assert(carryEvents()[2][1].entityId == "22")
    answerDenied(request)
    for _, lookup in ipairs(vehicleLookups) do assert(type(lookup) == "string", "the lookup must take the exact text") end
    -- fromEntity answers for either id a vehicle carries: a native id that merely equals ANOTHER
    -- vehicle's Open77 entity id must not resolve to it.
    snapshots.vehicle["5000"] = { id = 23, engineEntity = 777, entity = 5000, streamed = true }
    controllerRequest("vehicle", "5000")
    assert(lastDenial().reason == "entity_unresolved" and #carryEvents() == 2)
end)

test("ambient, unbound and not-ready bodies are refused here, with a reason, and never reach the server", function()
    granted(); carryWorld()
    local function refused(reason, kind, entity, extra)
        local before = #carryEvents()
        local request = controllerRequest(kind, entity, extra)
        local denial = lastDenial()
        assert(denial and denial.request == request.request and denial.reason == reason and denial.id == "9",
            ("expected %s for %s %s, got %s"):format(reason, kind, tostring(entity), tostring(denial and denial.reason)))
        assert(T.carryReasons[reason] == true and #carryEvents() == before, "a local refusal must not reach the server")
    end
    -- A vanilla population ped is in no row of the server-owned set: scenery, every client sees another.
    refused("not_networked", "npc", "4001")
    refused("not_networked", "npc", "4002")
    rows[1] = { engineEntity = 4003, id = 31 }
    refused("body_not_ready", "npc", "4003")      -- canonical, but no replicated readiness
    rows[1] = { engineEntity = 4003, id = 31, streamed = false, entity = 0, health = 100 }
    refused("body_not_ready", "npc", "4003")
    rows[1] = { engineEntity = 4003, id = 31, streamed = true, entity = 9, health = 0 }
    refused("body_not_ready", "npc", "4003")
    rows[1] = { engineEntity = 4003, id = 31, streamed = true, entity = 9, health = 100 }
    rows[2] = { engineEntity = 4004, id = 0, streamed = true, entity = 9, health = 100 }
    refused("not_networked", "npc", "4004")       -- a row with no canonical id is no networked body
    npcFailure = "part_layout_not_proven"
    refused("entity_unresolved", "npc", "4003")
    npcFailure = nil
    refused("not_networked", "vehicle", "5001")   -- traffic is not in the replica table
    snapshots.vehicle["5002"] = "permission_denied:vehicles.read"
    refused("entity_unresolved", "vehicle", "5002")
    snapshots.vehicle["5003"] = { id = 41, engineEntity = 5003, streamed = false }
    refused("body_not_ready", "vehicle", "5003")
    -- A request the controller phrased badly still gets its one answer.
    refused("entity_unresolved", "npc", "0x10")
    refused("entity_unresolved", "npc", 4003)
    refused("entity_unresolved", "npc", "4003", { kind = "prop" })
    refused("entity_unresolved", "npc", "4003", { extra = true })
    -- The Titan generation is the controller's own: a stale one is answered, not forwarded.
    local before = #carryEvents()
    local request = controllerRequest("npc", "4003", { epoch = 2 })
    assert(lastDenial().reason == "stale_titan" and lastDenial().request == request.request and #carryEvents() == before)
    request = controllerRequest("npc", "4003", { id = "10" })
    assert(lastDenial().reason == "stale_titan" and #carryEvents() == before)
    boot(); server(SESSION)                        -- no grant at all
    request = controllerRequest("npc", "4003")
    assert(lastDenial().reason == "stale_titan" and #carryEvents() == 0)
end)

test("a granted claim forwards only its own, fully validated samples; the release closes it", function()
    local first = claimed()
    local grant = delivered("carry_grant")[1]
    assert(grant.token == TOKEN and grant.entityId == "31" and grant.request == first.request and grant.kind == "npc")
    local base = #carryEvents()
    controllerSample("carry_frame", { seq = 1 })
    controllerSample("carry_frame", { seq = 2, t = 0.1 }, { x = 2, phase = "flight", vx = 20 })
    local events = carryEvents()
    assert(#events == base + 2)
    local frame = events[base + 2][1]
    assert(frame.op == "carry_frame" and frame.token == TOKEN and frame.seq == 2 and frame.pose.x == 2)
    assert(frame.pose.phase == "flight" and frame.pose.qw == 1 and frame.entity == nil and frame.entityId == nil)
    -- Nothing else of this Titan's claim gets through: wrong token, wrong generation, bad pose, extra keys.
    controllerSample("carry_frame", { seq = 3, token = string.rep("cd", 16) })
    controllerSample("carry_frame", { seq = 3, epoch = 2 })
    controllerSample("carry_frame", { seq = 3, id = "10" })
    controllerSample("carry_frame", { seq = 3 }, { x = 0 / 0 })
    controllerSample("carry_frame", { seq = 3 }, { qw = 2 })
    controllerSample("carry_frame", { seq = 3 }, { vx = 500 })
    controllerSample("carry_frame", { seq = 3 }, { phase = "teleport" })
    controllerSample("carry_frame", { seq = 3, entity = "4003" })
    controllerSample("carry_frame", { seq = 3, reason = "landed" })
    assert(#carryEvents() == base + 2, "a rejected sample is never forwarded")
    -- One grab at a time, decided here without a trip to the server.
    local before = #carryEvents()
    local second = controllerRequest("npc", "4003")
    assert(lastDenial().reason == "already_carrying" and lastDenial().request == second.request and #carryEvents() == before)
    -- The release is the last message of the claim.
    controllerSample("carry_release", { seq = 4, t = 0.2, reason = "landed" })
    assert(#carryEvents() == before + 1 and carryEvents()[before + 1][1].op == "carry_release")
    assert(carryEvents()[before + 1][1].reason == "landed")
    controllerSample("carry_frame", { seq = 5, t = 0.25 })
    controllerSample("carry_release", { seq = 5, t = 0.25 })
    assert(#carryEvents() == before + 1, "nothing follows the release")
    -- The server's confirmation reaches the controller, for this Titan only.
    server({ v = V, op = "carry_ended", id = "10", epoch = 1, token = TOKEN, reason = "landed" })
    assert(#delivered("carry_ended") == 0)
    server({ v = V, op = "carry_ended", id = "9", epoch = 1, token = TOKEN, reason = "landed" })
    assert(#delivered("carry_ended") == 1 and delivered("carry_ended")[1].reason == "landed")
    -- ... and a new grab is possible again.
    local third = controllerRequest("npc", "4003")
    assert(#carryEvents() == before + 2 and carryEvents()[before + 2][1].request == third.request)
end)

-- A thrown person's release (`launch`) rides on its flight messages and its release: the shared validator checks it
-- field by field, only a person's claim and only a flight may carry one.
test("a thrown person's release is forwarded with its flight messages and its release, validated, and never on a hold or another body", function()
    local release = { t = 0.05, x = 1, y = 2, z = 3, yaw = 10, px = 1, py = 2, pz = 3.6, ix = 0, iy = 912, iz = 547.2, radius = 2, delay = 0.12 }
    local function launch(overrides)
        local copy = {}
        for key, value in pairs(release) do copy[key] = value end
        for key, value in pairs(overrides or {}) do
            if value == false then copy[key] = nil else copy[key] = value end
        end
        return copy
    end
    local flight = { x = 2, phase = "flight", vx = 20 }
    claimed()
    controllerSample("carry_frame", { seq = 1 })
    local base = #carryEvents()
    controllerSample("carry_frame", { seq = 2, t = 0.1, launch = launch() }, flight)
    controllerSample("carry_frame", { seq = 3, t = 0.15, launch = launch() }, flight)
    local events = carryEvents()
    assert(#events == base + 2, "the flight messages reach the server")
    for index = base + 1, base + 2 do
        local wire, count = events[index][1], 0
        for key, value in pairs(wire.launch) do
            count = count + 1
            assert(release[key] == value, key)
        end
        assert(count == 13, "all of the release and nothing more")
    end
    -- Nothing that is not a complete, finite, bounded release of a flight gets through.
    local bad = {
        { launch(), { phase = "hold" } },                                -- a hold has no release
        { launch({ radius = false }) }, { launch({ iz = false }) }, { launch({ ix = 0 / 0 }) }, { launch({ py = math.huge }) },
        { launch({ ix = 0, iy = 0, iz = 0 }) }, { launch({ iy = 1001 }) }, { launch({ radius = 11 }) }, { launch({ radius = 0 }) },
        { launch({ delay = -0.01 }) }, { launch({ delay = 2 }) }, { launch({ pz = 6 }) }, { launch({ x = 1e7 }) },   -- pz 6 is 3 m above the root (z 3): 2 m exactly is still inside
        { launch({ yaw = 4000 }) }, { launch({ t = -1 }) }, { launch({ t = 0.5 }) },                    -- later than the message that carries it
        { launch({ spin = 1 }) }, { "now" }, { true },
    }
    for index, case in ipairs(bad) do
        local pose = { x = 2, phase = "flight", vx = 20 }
        for key, value in pairs(case[2] or {}) do pose[key] = value end
        controllerSample("carry_frame", { seq = 4, t = 0.2, launch = case[1] }, pose)
        assert(#carryEvents() == base + 2, "a malformed release was forwarded: #" .. index)
    end
    -- The release that ends the claim carries it too.
    controllerSample("carry_release", { seq = 4, t = 0.2, reason = "landed", launch = launch() }, flight)
    events = carryEvents()
    assert(#events == base + 3 and events[base + 3][1].op == "carry_release" and events[base + 3][1].launch.iy == 912)

    -- A vehicle's claim has none to carry.
    granted(); carryWorld()
    snapshots.vehicle["4100"] = { id = 21, engineEntity = 4100, entity = 5000, streamed = true }
    local request = controllerRequest("vehicle", "4100")
    server({ v = V, op = "carry_grant", id = "9", epoch = 1, request = request.request, kind = "vehicle", entityId = "21", token = TOKEN })
    assert(delivered("carry_grant")[#delivered("carry_grant")].kind == "vehicle")
    base = #carryEvents()
    controllerSample("carry_frame", { seq = 1, t = 0.1, launch = launch() }, flight)
    controllerSample("carry_release", { seq = 2, t = 0.2, reason = "landed", launch = launch() }, flight)
    assert(#carryEvents() == base, "a vehicle's flight with a release is dropped here")
    controllerSample("carry_frame", { seq = 1, t = 0.1 }, flight)
    assert(#carryEvents() == base + 1 and carryEvents()[base + 1][1].launch == nil)
end)

test("an unsolicited end, a removed Titan or a finished session closes the claim for good", function()
    claimed()
    controllerSample("carry_frame", { seq = 1 })
    local base = #carryEvents()
    assert(base == 2)
    server({ v = V, op = "carry_ended", id = "9", epoch = 1, token = TOKEN, reason = "claim_stalled" })
    assert(delivered("carry_ended")[1].reason == "claim_stalled")
    controllerSample("carry_frame", { seq = 2, t = 0.1 })
    assert(#carryEvents() == base, "frames after an end are dropped")
    -- The Titan itself going away.
    claimed()
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_removed" })
    controllerSample("carry_frame", { seq = 1 })
    assert(#carryEvents() == 1, "only the request went out")
    -- The session ending.
    claimed()
    server({ v = V, op = "session", active = false, player = "1" })
    controllerSample("carry_frame", { seq = 1 })
    assert(#carryEvents() == 1)
end)

test("the server's answers are matched to their request, once; strangers are dropped", function()
    granted(); carryWorld()
    rows[1] = { engineEntity = 4003, id = 31, streamed = true, entity = 9, health = 100 }
    local request = controllerRequest("npc", "4003")
    -- A grant for another request, kind or body is not the controller's: it is dropped loudly.
    for _, grant in ipairs({
        { request = request.request + 1 }, { entityId = "32" }, { kind = "vehicle" }, { id = "10" }, { epoch = 2 },
    }) do
        local message = { v = V, op = "carry_grant", id = "9", epoch = 1, request = request.request, kind = "npc", entityId = "31", token = TOKEN }
        for key, value in pairs(grant) do message[key] = value end
        server(message)
        if not grant.request then
            -- the mismatch consumed the pending entry: ask again for the next case
            request = controllerRequest("npc", "4003")
        end
    end
    assert(#delivered("carry_grant") == 0, "no mismatching grant reaches the controller")
    assert(#errorLogs() >= 1, "an orphaned grant is logged at error level")
    -- A malformed grant never gets that far.
    server({ v = V, op = "carry_grant", id = "9", epoch = 1, request = request.request, kind = "npc", entityId = "31", token = "no good" })
    server({ v = V, op = "carry_denied", id = "9", epoch = 1, request = request.request, reason = "os.execute" })
    assert(#delivered("carry_grant") == 0 and #delivered("carry_denied") == 0)
    -- A denial answers exactly the request it names, then it is spent.
    server({ v = V, op = "carry_denied", id = "9", epoch = 1, request = request.request + 7, reason = "target_far" })
    assert(#delivered("carry_denied") == 0, "no pending request of that number")
    server({ v = V, op = "carry_denied", id = "9", epoch = 1, request = request.request, reason = "target_far" })
    server({ v = V, op = "carry_denied", id = "9", epoch = 1, request = request.request, reason = "target_far" })
    assert(#delivered("carry_denied") == 1 and delivered("carry_denied")[1].reason == "target_far")
end)

test("unanswered requests are bounded and expire; a grant after the expiry is dropped", function()
    granted(); carryWorld()
    rows[1] = { engineEntity = 4003, id = 31, streamed = true, entity = 9, health = 100 }
    local pending = {}
    for index = 1, T.limits.carryPendingMax do pending[index] = controllerRequest("npc", "4003") end
    assert(#carryEvents() == T.limits.carryPendingMax)
    local flood = controllerRequest("npc", "4003")
    assert(lastDenial().reason == "rate_limited" and lastDenial().request == flood.request)
    assert(#carryEvents() == T.limits.carryPendingMax, "an unanswered flood is not forwarded")
    -- Past the pending window the requests are forgotten ...
    now = now + T.limits.carryPending + 1
    ticks[1]()
    server({ v = V, op = "carry_grant", id = "9", epoch = 1, request = pending[1].request, kind = "npc", entityId = "31", token = TOKEN })
    assert(#delivered("carry_grant") == 0, "nothing waits for it any more")
    local again = controllerRequest("npc", "4003")
    assert(#carryEvents() == T.limits.carryPendingMax + 1 and carryEvents()[#carryEvents()][1].request == again.request)
end)

test("the carry stream is forwarded, not free: it spends the sustained forwarding budget", function()
    claimed()
    local before = #carryEvents()
    -- 100 samples in one instant: the burst bounds what leaves, and a refused send tells the controller to hold.
    local accepted = 0
    for index = 1, 100 do
        local took = publish({ v = V, op = "carry_frame", id = "9", epoch = 1, token = TOKEN,
            seq = index, t = index * 0.001, pose = carryPose() })
        if took then accepted = accepted + 1 end
    end
    assert(accepted >= 1 and accepted < 100, accepted)
    assert(#carryEvents() - before == accepted, "what the budget refused was not forwarded")
end)

-- ---------------------------------------------------------------------------
-- The server-controlled loadout: the full policy rides the grant and every update.
-- ---------------------------------------------------------------------------
test("a grant relays the complete loadout to the controller; a malformed or legacy one grants nothing", function()
    granted()
    local grants = delivered("grant")
    assert(#grants == 1 and grants[1].revision == 1 and sameMap(grants[1].loadout, T.loadout.max))
    publish(cetFrame())
    assert(#sentNamed(T.event.frame) == 1, "a good grant must own the Titan")
    local function refused(label, mutate)
        boot(); server(SESSION)
        local message = grantWith()
        mutate(message)
        server(message)
        assert(#delivered("grant") == 0, "a malformed grant reached the controller: " .. label)
        publish(cetFrame())
        assert(#sentNamed(T.event.frame) == 0, "a malformed grant still owned the Titan: " .. label)
    end
    refused("no loadout", function(m) m.loadout = nil end)
    refused("no revision", function(m) m.revision = nil end)
    refused("revision 0", function(m) m.revision = 0 end)
    refused("revision 1.5", function(m) m.revision = 1.5 end)
    refused("revision text", function(m) m.revision = "1" end)
    refused("a perk missing", function(m) m.loadout.sentry = nil end)
    refused("unknown perk", function(m) m.loadout.nope = 1 end)
    refused("above the maximum", function(m) m.loadout.sentry = 2 end)
    refused("negative", function(m) m.loadout.sentry = -1 end)
    refused("fraction", function(m) m.loadout.sentry = 0.5 end)
    refused("NaN", function(m) m.loadout.sentry = 0 / 0 end)
    refused("infinite", function(m) m.loadout.sentry = math.huge end)
    refused("text", function(m) m.loadout.sentry = "1" end)
    refused("empty", function(m) m.loadout = {} end)
    refused("not a map", function(m) m.loadout = "all" end)
    refused("extra field", function(m) m.stray = true end)
    refused("legacy version", function(m) m.v = 1 end)
end)

test("a loadout update reaches the controller only for its own Titan and epoch, and only when newer", function()
    granted()
    local function relayed() return delivered("loadout") end
    server(loadoutUpdate(2, { sentry = 0 }))
    assert(#relayed() == 1 and relayed()[1].v == V and relayed()[1].id == "9" and relayed()[1].revision == 2)
    assert(sameMap(relayed()[1].loadout, loadoutUpdate(2, { sentry = 0 }).loadout))
    -- Replays, the past, other Titans and other epochs are not the controller's.
    server(loadoutUpdate(2, { sentry = 1 }))
    server(loadoutUpdate(1, { sentry = 1 }))
    server(loadoutUpdate(5, { sentry = 1 }, { id = "10" }))
    server(loadoutUpdate(5, { sentry = 1 }, { epoch = 2 }))
    assert(#relayed() == 1)
    -- A malformed one never moves the revision: the next valid word is still accepted.
    server(loadoutUpdate(50, { burstcore = 4 }))
    server(loadoutUpdate(50, {}, { extra = true }))
    server(loadoutUpdate(50, {}, { v = 1 }))
    server(loadoutUpdate(0, {}))
    server(loadoutUpdate(1.5, {}))
    server(loadoutUpdate("7", {}))
    assert(#relayed() == 1)
    server(loadoutUpdate(3, { burstcore = 1 }))
    assert(#relayed() == 2 and relayed()[2].revision == 3 and relayed()[2].loadout.burstcore == 1 and relayed()[2].loadout.sentry == 1)
    server(loadoutUpdate(9, {}))                      -- gaps are fine
    assert(#relayed() == 3 and relayed()[3].revision == 9)

    -- Before any grant, after a removal, for somebody else's Titan and after the session: nothing to update.
    boot(); server(SESSION)
    server(loadoutUpdate(2, {}))
    assert(#relayed() == 0, "an update before the grant")
    server(GRANT)
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_removed" })
    server(loadoutUpdate(2, {}))
    assert(#relayed() == 0, "an update after the removal")
    server(grantWith({ id = "11" }))
    server(loadoutUpdate(2, { sentry = 0 }, { id = "11" }))
    assert(#relayed() == 1 and relayed()[1].id == "11", "a new Titan counts its own revisions")
    server(grantWith({ id = "12", owner = "2" }))
    server(loadoutUpdate(2, {}, { id = "12" }))
    assert(#relayed() == 1, "somebody else's Titan is not ours")
    server(loadoutUpdate(3, {}, { id = "11" }))
    assert(#relayed() == 2 and relayed()[2].revision == 3)
    server({ v = V, op = "session", active = false, player = "1" })
    server(loadoutUpdate(4, {}, { id = "11" }))
    assert(#relayed() == 2, "an update after the session ended")
end)

test("frames and relayed states are forwarded as they are and carry no loadout", function()
    granted()
    server(loadoutUpdate(2, { sentry = 0 }))
    for seq = 1, 25 do
        publish(cetFrame({ seq = seq }))
        server(remoteState(seq, nil, "20"))
    end
    assert(#sentNamed(T.event.frame) == 25 and #delivered("state") == 1, "a newer motion-only state replaces an older one")
    for _, state in ipairs(delivered("state")) do assert(state.loadout == nil and state.revision == nil) end
end)

-- ---------------------------------------------------------------------------
-- Gameplay: a server script's hit / repair requests come in, the controller's answers and its gameplay report go out.
-- ---------------------------------------------------------------------------
local function hitMessage(extra)
    local message = { v = V, op = "hit", id = "9", epoch = 1, request = 1, record = "Attacks.Bullet_Rifle_Basic",
        origin = { x = 1, y = 2, z = 3 }, direction = { x = 0, y = 1, z = 0 }, attacker = "player:2", kind = "ranged", scale = 2 }
    for key, value in pairs(extra or {}) do message[key] = value end
    return message
end
local function repairMessage(extra)
    local message = { v = V, op = "repair", id = "9", epoch = 1, request = 2, amount = 100 }
    for key, value in pairs(extra or {}) do message[key] = value end
    return message
end
local function answerOf(extra)
    local message = { v = V, op = "gameplay_result", id = "9", epoch = 1, request = 1, kind = "hit", ok = true,
        reason = "taken", amount = 12.5 }
    for key, value in pairs(extra or {}) do message[key] = value end
    return message
end

test("a server hit or repair reaches the controller only for its own Titan and epoch, closed and bounded", function()
    granted()
    server(hitMessage())
    server(repairMessage())
    local hits, repairs = delivered("hit"), delivered("repair")
    assert(#hits == 1 and hits[1].request == 1 and hits[1].record == "Attacks.Bullet_Rifle_Basic" and hits[1].scale == 2
        and hits[1].direction.y == 1 and hits[1].attacker == "player:2" and hits[1].kind == "ranged")
    assert(#repairs == 1 and repairs[1].request == 2 and repairs[1].amount == 100)
    for _, bad in ipairs({
        hitMessage({ id = "10" }), hitMessage({ epoch = 2 }), hitMessage({ request = 0 }), hitMessage({ record = "bad record" }),
        hitMessage({ origin = { x = 0 / 0, y = 0, z = 0 } }), hitMessage({ direction = { x = 0, y = 0, z = 0 } }),
        hitMessage({ kind = "laser" }), hitMessage({ scale = 5 }), hitMessage({ scale = 0 }), hitMessage({ attacker = "a\nb" }),
        hitMessage({ extra = 1 }), hitMessage({ v = 1 }),
        repairMessage({ id = "10" }), repairMessage({ epoch = 2 }), repairMessage({ amount = 0 }),
        repairMessage({ amount = 1000001 }), repairMessage({ amount = 0 / 0 }), repairMessage({ extra = true }),
    }) do
        server(bad)
    end
    assert(#delivered("hit") == 1 and #delivered("repair") == 1, "a request that is not this controller's was relayed")
    -- Not the controller's before its grant or after its Titan is gone.
    boot(); server(SESSION)
    server(hitMessage())
    server(repairMessage())
    assert(#delivered("hit") == 0 and #delivered("repair") == 0, "a request before the grant")
    server(GRANT)
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_removed" })
    server(hitMessage({ request = 7 }))
    server(repairMessage({ request = 8 }))
    assert(#delivered("hit") == 0 and #delivered("repair") == 0, "a request after the removal")
end)

test("the controller's answer leaves only for its own Titan and epoch, validated, and spends the forwarding budget", function()
    granted()
    local input = answerOf()
    assert(publish(input) == true)
    local answers = sentNamed(T.event.result)
    local first = answers[1] and answers[1][1]
    assert(#answers == 1 and first ~= input and first.v == V and first.op == "gameplay_result" and first.id == "9"
        and first.epoch == 1 and first.request == 1 and first.kind == "hit" and first.ok == true and first.reason == "taken"
        and first.amount == 12.5, "the answer must be forwarded as a validated copy")
    -- A repair that was done (no reason) and a hit that was refused (no amount) are both legal answers.
    assert(publish({ v = V, op = "gameplay_result", id = "9", epoch = 1, request = 2, kind = "repair", ok = true, amount = 100 }))
    assert(publish({ v = V, op = "gameplay_result", id = "9", epoch = 1, request = 3, kind = "hit", ok = false, reason = "no BT" }))
    answers = sentNamed(T.event.result)
    assert(#answers == 3 and answers[2][1].reason == nil and answers[2][1].amount == 100
        and answers[3][1].ok == false and answers[3][1].amount == nil and answers[3][1].reason == "no BT")
    -- Another Titan or epoch, an unknown field, a bad kind, number or text: consumed here, never forwarded.
    for _, bad in ipairs({
        answerOf({ id = "10" }), answerOf({ epoch = 2 }), answerOf({ extra = 1 }), answerOf({ kind = "heal" }),
        answerOf({ ok = "yes" }), answerOf({ amount = 0 / 0 }), answerOf({ amount = -1 }), answerOf({ amount = 2000000 }),
        answerOf({ reason = "two\nlines" }), answerOf({ reason = ("x"):rep(161) }), answerOf({ request = 0 }),
        answerOf({ v = 1 }), answerOf({ ok = false }),
    }) do
        assert(publish(bad) == true, "a malformed answer must be consumed, not held")
    end
    assert(#sentNamed(T.event.result) == 3, "a malformed or foreign answer left this machine")
    -- After the Titan is gone there is nothing to answer for.
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_removed" })
    assert(publish(answerOf()) == true and #sentNamed(T.event.result) == 3, "an answer after the removal")
    -- The answers share the sustained forwarding budget: a refused send is the controller's cue to keep them.
    granted()
    local accepted = 0
    for _ = 1, 100 do
        if publish(answerOf()) then accepted = accepted + 1 end
    end
    assert(accepted == 30 and #sentNamed(T.event.result) == 30, "the burst, no more: " .. accepted)
end)

local function coreMessage(extra)
    local message = { v = V, op = "core_credit", id = "9", epoch = 1, request = 3, target = { id = "12", epoch = 2 },
        record = "Attacks.BT7274_XO16_Hit", killing = true }
    for key, value in pairs(extra or {}) do message[key] = value end
    return message
end
local function coreWithout(key)
    local message = coreMessage()
    message[key] = nil
    return message
end

test("a server core credit reaches the controller only for its own Titan and epoch, as a closed validated copy", function()
    granted()
    local input = coreMessage()
    server(input)
    local credits = delivered("core_credit")
    assert(#credits == 1, "the credit was not relayed")
    local first = credits[1]
    assert(first ~= input and first.target ~= input.target, "the controller must get a copy, not the relayed table")
    assert(first.v == V and first.id == "9" and first.epoch == 1 and first.request == 3 and first.target.id == "12"
        and first.target.epoch == 2 and first.record == "Attacks.BT7274_XO16_Hit" and first.killing == true)
    local keys, targetKeys = {}, {}
    for key in pairs(first) do keys[#keys + 1] = key end
    for key in pairs(first.target) do targetKeys[#targetKeys + 1] = key end
    table.sort(keys)
    table.sort(targetKeys)
    assert(table.concat(keys, ",") == "epoch,id,killing,op,record,request,target,v", table.concat(keys, ","))
    assert(table.concat(targetKeys, ",") == "epoch,id", table.concat(targetKeys, ","))
    -- A blow that did not kill is a credit too; the controller's own rules decide what either is worth.
    server(coreMessage({ request = 4, killing = false }))
    assert(#delivered("core_credit") == 2 and delivered("core_credit")[2].killing == false)
    for _, bad in ipairs({
        coreMessage({ id = "10" }), coreMessage({ id = 9 }), coreMessage({ epoch = 2 }), coreMessage({ epoch = 1.5 }),
        coreMessage({ request = 0 }), coreMessage({ request = 1.5 }), coreMessage({ request = "3" }),
        coreMessage({ v = 1 }), coreMessage({ extra = 1 }), coreMessage({ attacker = "player:2" }), coreMessage({ amount = 5 }),
        coreWithout("target"), coreWithout("record"), coreWithout("killing"), coreWithout("request"),
        coreMessage({ target = "12" }), coreMessage({ target = { id = "12" } }), coreMessage({ target = { epoch = 2 } }),
        coreMessage({ target = { id = "0", epoch = 2 } }), coreMessage({ target = { id = "012", epoch = 2 } }),
        coreMessage({ target = { id = 12, epoch = 2 } }), coreMessage({ target = { id = ("9"):rep(17), epoch = 2 } }),
        coreMessage({ target = { id = "12", epoch = 0 } }), coreMessage({ target = { id = "12", epoch = "2" } }),
        coreMessage({ target = { id = "12", epoch = 2 ^ 53 } }), coreMessage({ target = { id = "12", epoch = 2, owner = "2" } }),
        coreMessage({ record = "bad record" }), coreMessage({ record = "" }), coreMessage({ record = ("r"):rep(161) }),
        coreMessage({ record = 5 }), coreMessage({ killing = "yes" }), coreMessage({ killing = 1 }), coreMessage({ killing = {} }),
    }) do
        server(bad)
    end
    assert(#delivered("core_credit") == 2, "a request that is not this controller's, or malformed, was relayed")
    -- The edges of every bound are taken.
    server(coreMessage({ request = 5, record = ("r"):rep(160), target = { id = ("9"):rep(16), epoch = 2 ^ 53 - 1 } }))
    assert(#delivered("core_credit") == 3 and #delivered("core_credit")[3].record == 160)
    -- Not the controller's before its grant or after its Titan is gone.
    boot(); server(SESSION)
    server(coreMessage())
    assert(#delivered("core_credit") == 0, "a request before the grant")
    server(GRANT)
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_removed" })
    server(coreMessage({ request = 7 }))
    assert(#delivered("core_credit") == 0, "a request after the removal")
end)

test("the controller's core credit answer leaves only for its own Titan and epoch, validated: taken with nothing added, with some, or refused", function()
    granted()
    local function answer(extra)
        local message = { v = V, op = "gameplay_result", id = "9", epoch = 1, request = 3, kind = "core_credit", ok = true, amount = 37.5 }
        for key, value in pairs(extra or {}) do message[key] = value end
        return message
    end
    local input = answer()
    assert(publish(input) == true)
    local out = sentNamed(T.event.result)
    local first = out[1] and out[1][1]
    assert(#out == 1 and first ~= input and first.v == V and first.op == "gameplay_result" and first.id == "9" and first.epoch == 1
        and first.request == 3 and first.kind == "core_credit" and first.ok == true and first.amount == 37.5
        and first.reason == nil, "the answer must be forwarded as a validated copy")
    -- Taken and added nothing is an answer of its own (a full core is not a refusal), and so is a refusal with the word of the controller.
    assert(publish(answer({ request = 4, amount = 0 })) == true)
    assert(publish({ v = V, op = "gameplay_result", id = "9", epoch = 1, request = 5, kind = "core_credit", ok = false, reason = "duplicate" }) == true)
    out = sentNamed(T.event.result)
    assert(#out == 3 and out[2][1].ok == true and out[2][1].amount == 0 and out[2][1].reason == nil
        and out[3][1].ok == false and out[3][1].amount == nil and out[3][1].reason == "duplicate")
    -- Another Titan or epoch, another kind's word for it, an impossible number or a refusal that carries an amount: consumed here.
    for _, bad in ipairs({
        answer({ id = "10" }), answer({ epoch = 2 }), answer({ kind = "credit" }), answer({ kind = "core" }), answer({ extra = 1 }),
        answer({ amount = -1 }), answer({ amount = 0 / 0 }), answer({ amount = 2000000 }), answer({ amount = "1" }),
        answer({ ok = false }), answer({ ok = false, reason = "refused" }), answer({ request = 0 }), answer({ v = 1 }),
    }) do
        assert(publish(bad) == true, "a malformed answer must be consumed, not held")
    end
    local noAmount = answer()
    noAmount.amount = nil
    assert(publish(noAmount) == true)
    assert(#sentNamed(T.event.result) == 3, "a malformed or foreign answer left this machine")
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_removed" })
    assert(publish(answer({ request = 6 })) == true and #sentNamed(T.event.result) == 3, "an answer after the removal")
end)

test("a controller frame's gameplay report is forwarded as decoded; the server's validator is its one check", function()
    granted()
    local report = { health = { current = 9000, max = 10800, dead = false }, paused = false }
    local good = cetFrame({ seq = 1, gameplay = report })
    assert(publish(good) == true)
    local malformed = cetFrame({ seq = 2, gameplay = { paused = "no" } })
    assert(publish(malformed) == true)
    local frames = sentNamed(T.event.frame)
    assert(#frames == 2 and frames[1][1] == good and frames[2][1] == malformed, "forwarded untouched")
    assert(T.normalizeFrame(good, Open77TitanCatalog).gameplay.health.current == 9000)
    local clean, why = T.normalizeFrame(malformed, Open77TitanCatalog)
    assert(clean == nil and why == "gameplay_paused", tostring(why))
end)

-- ---------------------------------------------------------------------------
-- Observed hits: what the controller saw its Titan land on ANOTHER player's Titan leaves as its own event, once, as a
-- validated copy, for the controller's own grant only. The client resolves nothing and applies nothing.
-- ---------------------------------------------------------------------------
local function observedMessage(extra)
    local message = { v = V, op = "hit_observed", id = "9", epoch = 1, seq = 1,
        target = { kind = "titan", id = "12", epoch = 1, owner = "2" },
        record = "Attacks.BT7274_XO16_Hit", origin = { x = 1, y = 2, z = 3 }, point = { x = 30, y = 2, z = 3 },
        direction = { x = 1, y = 0, z = 0 }, kind = "ranged", scale = 1 }
    for key, value in pairs(extra or {}) do message[key] = value end
    return message
end
local function observedSent() return sentNamed(T.event.hit) end

test("an observed hit leaves for the controller's own Titan and epoch as a validated copy, on its own event", function()
    granted()
    local input = observedMessage()
    assert(publish(input) == true)
    local out = observedSent()
    local first = out[1] and out[1][1]
    assert(#out == 1 and select("#", table.unpack(out[1])) == 1 and first ~= input, "one copy, one argument")
    assert(first.v == V and first.op == "hit_observed" and first.id == "9" and first.epoch == 1 and first.seq == 1
        and first.record == "Attacks.BT7274_XO16_Hit" and first.kind == "ranged" and first.scale == 1
        and first.target.kind == "titan" and first.target.id == "12" and first.target.epoch == 1 and first.target.owner == "2"
        and first.origin.x == 1 and first.point.x == 30 and first.direction.x == 1)
    local keys = {}
    for key in pairs(first) do keys[#keys + 1] = key end
    table.sort(keys)
    assert(table.concat(keys, ",") == "direction,epoch,id,kind,op,origin,point,record,scale,seq,target,v", table.concat(keys, ","))
    -- Nothing of the controller's table is shared with what was sent, so a later write to it changes nothing sent.
    assert(first.target ~= input.target and first.origin ~= input.origin and first.point ~= input.point
        and first.direction ~= input.direction)
    input.origin.x, input.target.id, input.record = 99, "13", "other"
    assert(first.origin.x == 1 and first.target.id == "12" and first.record == "Attacks.BT7274_XO16_Hit")
    -- A report without its scale is the unscaled one, as a server hit is; the controller's own words travel nowhere else.
    local unscaled = observedMessage({ seq = 2 })
    unscaled.scale = nil
    assert(publish(unscaled) == true and observedSent()[2][1].scale == 1)
    assert(#sentNamed(T.event.frame) == 0 and #sentNamed(T.event.result) == 0 and #sentNamed(T.event.carry) == 0
        and #sentNamed(T.event.request) == 0, "an observation travelled on another event")
end)

test("an observation of another Titan, a foreign epoch or a malformed one is consumed here and never forwarded", function()
    granted()
    local function without(key)
        local message = observedMessage()
        message[key] = nil
        return message
    end
    local function target(extra)
        local message = observedMessage()
        for key, value in pairs(extra) do message.target[key] = value end
        return message
    end
    local noTargetKind, noTargetOwner = observedMessage(), observedMessage()
    noTargetKind.target.kind, noTargetOwner.target.owner = nil, nil
    for _, bad in ipairs({
        observedMessage({ id = "10" }), observedMessage({ id = 9 }), observedMessage({ epoch = 2 }), observedMessage({ epoch = 1.5 }),
        observedMessage({ seq = 0 }), observedMessage({ seq = 1.5 }), observedMessage({ seq = 0 / 0 }), observedMessage({ seq = "1" }),
        observedMessage({ v = 1 }), observedMessage({ op = "hit" }), observedMessage({ extra = 1 }),
        observedMessage({ attacker = "player:1" }), observedMessage({ request = 1 }),
        without("target"), without("record"), without("origin"), without("point"), without("direction"), without("kind"),
        observedMessage({ target = "12" }), target({ kind = "npc" }), noTargetKind, target({ id = "0" }),
        target({ id = "012" }), target({ id = 12 }), target({ epoch = 0 }), target({ epoch = "1" }), target({ owner = "x" }),
        target({ owner = 2 }), noTargetOwner, target({ extra = true }),
        observedMessage({ record = "bad record" }), observedMessage({ record = "" }), observedMessage({ record = ("r"):rep(161) }),
        observedMessage({ origin = { x = 0 / 0, y = 0, z = 0 } }), observedMessage({ origin = { x = 1e7, y = 0, z = 0 } }),
        observedMessage({ origin = { x = 0, y = 0, z = 0, w = 1 } }), observedMessage({ origin = { x = 0, y = 0 } }),
        observedMessage({ point = { x = 0, y = 1 / 0, z = 0 } }), observedMessage({ point = { x = 0, y = 0, z = -1e7 } }),
        observedMessage({ point = { x = 0, y = 0, z = 0, extra = 1 } }), observedMessage({ point = 1 }),
        observedMessage({ direction = { x = 0, y = 0, z = 0 } }), observedMessage({ direction = { x = 2, y = 0, z = 0 } }),
        observedMessage({ kind = "laser" }), observedMessage({ kind = 1 }), observedMessage({ scale = 0 }),
        observedMessage({ scale = 4.5 }), observedMessage({ scale = 0 / 0 }), observedMessage({ scale = "1" }),
    }) do
        now = now + 0.5   -- every message, valid or not, spends a token before it is looked at: keep the bucket full
        assert(publish(bad) == true, "a malformed observation must be consumed, not held")
    end
    assert(#observedSent() == 0, "a malformed or foreign observation left this machine: " .. #observedSent())
    -- The controller cannot pick the event: only the one observation op is forwarded, under the one event name.
    for _, op in ipairs({ "onTitanHitObserved", "hit", "hit_observe", "gameplay_hit", "applyDamage" }) do
        now = now + 0.5
        assert(publish(observedMessage({ op = op })) == true)
    end
    assert(#observedSent() == 0 and #sent == 1 and sent[1].name == T.event.ready, "another op reached the server")
    assert(publish(observedMessage()) == true and #observedSent() == 1, "the good one still passes")
end)

test("an observation needs this controller's grant: before it, after the removal or the session's end it goes nowhere", function()
    boot(); server(SESSION)
    assert(publish(observedMessage()) == true and #observedSent() == 0, "before the grant")
    server(GRANT)
    assert(publish(observedMessage()) == true and #observedSent() == 1)
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_removed" })
    assert(publish(observedMessage({ seq = 2 })) == true and #observedSent() == 1, "after the removal")
    server(GRANT)
    assert(publish(observedMessage({ seq = 3 })) == true and #observedSent() == 2)
    server({ v = V, op = "session", active = false, player = "1" })
    assert(publish(observedMessage({ seq = 4 })) == true and #observedSent() == 2, "after the session's end")
    -- A newer epoch of a granted Titan is another Titan: the old epoch is not this controller's any more.
    boot(); server(SESSION); server(grantWith({ epoch = 2 }))
    assert(publish(observedMessage()) == true and #observedSent() == 0, "an observation for the previous epoch")
    assert(publish(observedMessage({ epoch = 2 })) == true and #observedSent() == 1)
end)

test("observations spend the forwarding budget: a refused send is the controller's cue to keep it, and it refills with time", function()
    granted()
    local accepted = 0
    for index = 1, 100 do
        if publish(observedMessage({ seq = index })) then accepted = accepted + 1 end
    end
    assert(accepted == 30 and #observedSent() == 30, "the burst, no more: " .. accepted)
    assert(observedSent()[30][1].seq == 30, "what was refused was not forwarded, and the order is kept")
    now = now + 1
    assert(publish(observedMessage({ seq = 31 })) == true and #observedSent() == 31, "the budget refills with time")
    -- Frames, requests and answers share it: with the budget gone an observation is refused like any of them.
    for _ = 1, 100 do publish({ v = V, op = "request", action = "spawn" }) end
    assert(publish(observedMessage({ seq = 32 })) == false and #observedSent() == 31)
end)

-- ---------------------------------------------------------------------------
-- Observed status effects: what the controller's own calls would apply to ANOTHER player's Titan leaves as its own event, once,
-- as a validated copy, for the controller's own grant only, and spends the one forwarding budget the hits spend.
-- ---------------------------------------------------------------------------
local function statusMessage(extra)
    local message = { v = V, op = "status_observed", id = "9", epoch = 1, seq = 1,
        target = { kind = "titan", id = "12", epoch = 1, owner = "2" }, effect = "BaseStatusEffect.Burning" }
    for key, value in pairs(extra or {}) do message[key] = value end
    return message
end
local function statusSent() return sentNamed(T.event.status) end

test("an observed status effect leaves for the controller's own Titan and epoch as a validated copy, on its own event", function()
    granted()
    local input = statusMessage()
    assert(publish(input) == true)
    local out = statusSent()
    local first = out[1] and out[1][1]
    assert(#out == 1 and select("#", table.unpack(out[1])) == 1 and first ~= input, "one copy, one argument")
    assert(first.v == V and first.op == "status_observed" and first.id == "9" and first.epoch == 1 and first.seq == 1
        and first.effect == "BaseStatusEffect.Burning" and first.duration == nil
        and first.target.kind == "titan" and first.target.id == "12" and first.target.epoch == 1 and first.target.owner == "2")
    local keys = {}
    for key in pairs(first) do keys[#keys + 1] = key end
    table.sort(keys)
    assert(table.concat(keys, ",") == "effect,epoch,id,op,seq,target,v", "no duration is made up: " .. table.concat(keys, ","))
    -- Nothing of the controller's table is shared with what was sent, so a later write to it changes nothing sent.
    assert(first.target ~= input.target)
    input.target.id, input.effect = "13", "other"
    assert(first.target.id == "12" and first.effect == "BaseStatusEffect.Burning")
    -- A duration the controller's own call supplied is kept exactly (0 is a duration), and nothing else leaves with it.
    assert(publish(statusMessage({ seq = 2, duration = 4.5 })) == true and publish(statusMessage({ seq = 3, duration = 0 })) == true)
    out = statusSent()
    assert(#out == 3 and out[2][1].duration == 4.5 and out[3][1].duration == 0 and out[2][1].seq == 2)
    assert(#sentNamed(T.event.frame) == 0 and #sentNamed(T.event.result) == 0 and #sentNamed(T.event.carry) == 0
        and #sentNamed(T.event.request) == 0 and #sentNamed(T.event.hit) == 0, "an observation travelled on another event")
end)

test("a status observation of another Titan, a foreign epoch or a malformed one is consumed here and never forwarded", function()
    granted()
    local function without(key)
        local message = statusMessage()
        message[key] = nil
        return message
    end
    local function target(extra)
        local message = statusMessage()
        for key, value in pairs(extra) do message.target[key] = value end
        return message
    end
    local noTargetKind, noTargetOwner = statusMessage(), statusMessage()
    noTargetKind.target.kind, noTargetOwner.target.owner = nil, nil
    for _, bad in ipairs({
        statusMessage({ id = "10" }), statusMessage({ id = 9 }), statusMessage({ epoch = 2 }), statusMessage({ epoch = 1.5 }),
        statusMessage({ seq = 0 }), statusMessage({ seq = 1.5 }), statusMessage({ seq = 0 / 0 }), statusMessage({ seq = "1" }),
        statusMessage({ v = 1 }), statusMessage({ op = "hit" }), statusMessage({ extra = 1 }), statusMessage({ request = 1 }),
        -- the fields of a hit are not the fields of a status effect
        statusMessage({ record = "Attacks.BT7274_XO16_Hit" }), statusMessage({ point = { x = 0, y = 0, z = 0 } }),
        statusMessage({ origin = { x = 0, y = 0, z = 0 } }), statusMessage({ direction = { x = 1, y = 0, z = 0 } }),
        statusMessage({ kind = "ranged" }), statusMessage({ scale = 1 }), statusMessage({ attacker = "player:1" }),
        without("target"), without("effect"),
        statusMessage({ target = "12" }), target({ kind = "npc" }), noTargetKind, target({ id = "0" }), target({ id = "012" }),
        target({ id = 12 }), target({ epoch = 0 }), target({ epoch = "1" }), target({ owner = "x" }), target({ owner = 2 }),
        noTargetOwner, target({ extra = true }),
        statusMessage({ effect = "bad effect" }), statusMessage({ effect = "" }), statusMessage({ effect = ("e"):rep(161) }),
        statusMessage({ effect = 5 }), statusMessage({ effect = true }), statusMessage({ effect = {} }),
        statusMessage({ duration = -1 }), statusMessage({ duration = 0 / 0 }), statusMessage({ duration = 1 / 0 }),
        statusMessage({ duration = -1 / 0 }), statusMessage({ duration = T.limits.time + 1 }), statusMessage({ duration = "1" }),
        statusMessage({ duration = true }), statusMessage({ duration = {} }),
    }) do
        now = now + 0.5   -- every message, valid or not, spends a token before it is looked at: keep the bucket full
        assert(publish(bad) == true, "a malformed observation must be consumed, not held")
    end
    assert(#statusSent() == 0, "a malformed or foreign observation left this machine: " .. #statusSent())
    -- The controller cannot pick the event: only the one observation op is forwarded, under the one event name.
    for _, op in ipairs({ "onTitanStatusObserved", "status", "status_observe", "applyStatus", "applyStatusEffect", "hit_observed" }) do
        now = now + 0.5
        assert(publish(statusMessage({ op = op })) == true)
    end
    assert(#statusSent() == 0 and #observedSent() == 0 and #sent == 1 and sent[1].name == T.event.ready, "another op reached the server")
    assert(publish(statusMessage()) == true and #statusSent() == 1, "the good one still passes")
end)

test("a status observation needs this controller's grant: before it, after the removal or the session's end it goes nowhere", function()
    boot(); server(SESSION)
    assert(publish(statusMessage()) == true and #statusSent() == 0, "before the grant")
    server(GRANT)
    assert(publish(statusMessage()) == true and #statusSent() == 1)
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_removed" })
    assert(publish(statusMessage({ seq = 2 })) == true and #statusSent() == 1, "after the removal")
    server(GRANT)
    assert(publish(statusMessage({ seq = 3 })) == true and #statusSent() == 2)
    server({ v = V, op = "session", active = false, player = "1" })
    assert(publish(statusMessage({ seq = 4 })) == true and #statusSent() == 2, "after the session's end")
    -- A newer epoch of a granted Titan is another Titan: the old epoch is not this controller's any more.
    boot(); server(SESSION); server(grantWith({ epoch = 2 }))
    assert(publish(statusMessage()) == true and #statusSent() == 0, "an observation for the previous epoch")
    assert(publish(statusMessage({ epoch = 2 })) == true and #statusSent() == 1)
end)

test("hits and status effects spend one forwarding budget: a refused send is the controller's cue to keep it, and it refills with time", function()
    granted()
    local accepted = 0
    for index = 1, 100 do
        local message = index % 2 == 0 and statusMessage({ seq = index }) or observedMessage({ seq = index })
        if publish(message) then accepted = accepted + 1 end
    end
    assert(accepted == 30 and #statusSent() + #observedSent() == 30, "the burst, no more, whichever kind spent it: " .. accepted)
    assert(#statusSent() == 15 and #observedSent() == 15 and statusSent()[15][1].seq == 30,
        "what was refused was not forwarded, and the order is kept")
    now = now + 1
    assert(publish(statusMessage({ seq = 31 })) == true and #statusSent() == 16, "the budget refills with time")
    -- Frames, requests, answers and the other kind share it: with the budget gone a status observation is refused like any of them.
    for _ = 1, 100 do publish({ v = V, op = "request", action = "spawn" }) end
    assert(publish(statusMessage({ seq = 32 })) == false and #statusSent() == 16)
    assert(publish(observedMessage({ seq = 33 })) == false and #observedSent() == 15)
end)

-- ---------------------------------------------------------------------------
-- Blows on cars: what the controller's weapons took off a canonical car leaves as its own event, once, as a validated copy, for
-- the controller's own grant only, and spends the one forwarding budget the observations spend. The car is named by the id the
-- bridge resolved; nothing here looks at it.
-- ---------------------------------------------------------------------------
local function vehicleMessage(extra)
    local message = { v = V, op = "vehicle_hit", id = "9", epoch = 1, seq = 1, vehicle = "14", share = 25,
        point = { x = 3, y = 4, z = 5 } }
    for key, value in pairs(extra or {}) do message[key] = value end
    return message
end
local function vehicleSent() return sentNamed(T.event.vehicle) end

test("a blow on a car leaves for the controller's own Titan and epoch as a validated copy, on its own event", function()
    granted()
    local input = vehicleMessage()
    assert(publish(input) == true)
    local out = vehicleSent()
    local first = out[1] and out[1][1]
    assert(#out == 1 and select("#", table.unpack(out[1])) == 1 and first ~= input, "one copy, one argument")
    assert(first.v == V and first.op == "vehicle_hit" and first.id == "9" and first.epoch == 1 and first.seq == 1
        and first.vehicle == "14" and first.share == 25 and first.point.x == 3 and first.point.y == 4 and first.point.z == 5)
    local keys = {}
    for key in pairs(first) do keys[#keys + 1] = key end
    table.sort(keys)
    assert(table.concat(keys, ",") == "epoch,id,op,point,seq,share,v,vehicle", table.concat(keys, ","))
    -- Nothing of the controller's table is shared with what was sent, so a later write to it changes nothing sent.
    assert(first.point ~= input.point)
    input.point.x, input.share, input.vehicle = 99, 99, "15"
    assert(first.point.x == 3 and first.share == 25 and first.vehicle == "14")
    -- The extremes are the schema's: a whole car, and a sliver.
    assert(publish(vehicleMessage({ seq = 2, share = T.limits.vehicleShare })) == true
        and publish(vehicleMessage({ seq = 3, share = 1e-6 })) == true)
    out = vehicleSent()
    assert(#out == 3 and out[2][1].share == 100 and out[3][1].share == 1e-6)
    assert(#sentNamed(T.event.frame) == 0 and #sentNamed(T.event.result) == 0 and #sentNamed(T.event.carry) == 0
        and #sentNamed(T.event.request) == 0 and #sentNamed(T.event.hit) == 0 and #sentNamed(T.event.status) == 0,
        "a blow on a car travelled on another event")
end)

test("a blow on a car of another Titan, a foreign epoch or a malformed one is consumed here and never forwarded", function()
    granted()
    local function without(key)
        local message = vehicleMessage()
        message[key] = nil
        return message
    end
    local function point(extra)
        local message = vehicleMessage()
        for key, value in pairs(extra) do message.point[key] = value end
        return message
    end
    for _, bad in ipairs({
        vehicleMessage({ id = "10" }), vehicleMessage({ id = 9 }), vehicleMessage({ epoch = 2 }), vehicleMessage({ epoch = 1.5 }),
        vehicleMessage({ seq = 0 }), vehicleMessage({ seq = 1.5 }), vehicleMessage({ seq = 0 / 0 }), vehicleMessage({ seq = "1" }),
        vehicleMessage({ v = 1 }), vehicleMessage({ op = "hit" }), vehicleMessage({ extra = 1 }), vehicleMessage({ request = 1 }),
        -- the fields of the other observations are not the fields of a blow on a car
        vehicleMessage({ target = { kind = "titan", id = "12", epoch = 1, owner = "2" } }), vehicleMessage({ record = "Attacks.X" }),
        vehicleMessage({ effect = "BaseStatusEffect.Burning" }), vehicleMessage({ kind = "ranged" }),
        without("vehicle"), without("share"), without("point"),
        vehicleMessage({ vehicle = 14 }), vehicleMessage({ vehicle = "0" }), vehicleMessage({ vehicle = "014" }),
        vehicleMessage({ vehicle = "x" }), vehicleMessage({ vehicle = "" }), vehicleMessage({ vehicle = ("9"):rep(17) }),
        vehicleMessage({ share = 0 }), vehicleMessage({ share = -1 }), vehicleMessage({ share = T.limits.vehicleShare + 0.001 }),
        vehicleMessage({ share = 0 / 0 }), vehicleMessage({ share = 1 / 0 }), vehicleMessage({ share = "25" }),
        vehicleMessage({ share = true }),
        vehicleMessage({ point = 1 }), point({ x = 0 / 0 }), point({ y = 1 / 0 }), point({ z = T.limits.coordinate + 1 }),
        point({ w = 1 }), point({ z = false }),
    }) do
        now = now + 0.5   -- every message, valid or not, spends a token before it is looked at: keep the bucket full
        assert(publish(bad) == true, "a malformed blow on a car must be consumed, not held")
    end
    assert(#vehicleSent() == 0, "a malformed or foreign blow on a car left this machine: " .. #vehicleSent())
    -- The controller cannot pick the event: only the one op is forwarded, under the one event name.
    for _, op in ipairs({ "onTitanVehicleHit", "vehicle", "vehicleHit", "damageVehicle", "hit_observed", "status_observed" }) do
        now = now + 0.5
        assert(publish(vehicleMessage({ op = op })) == true)
    end
    assert(#vehicleSent() == 0 and #observedSent() == 0 and #statusSent() == 0 and #sent == 1 and sent[1].name == T.event.ready,
        "another op reached the server")
    assert(publish(vehicleMessage()) == true and #vehicleSent() == 1, "the good one still passes")
end)

test("a blow on a car needs this controller's grant: before it, after the removal or the session's end it goes nowhere", function()
    boot(); server(SESSION)
    assert(publish(vehicleMessage()) == true and #vehicleSent() == 0, "before the grant")
    server(GRANT)
    assert(publish(vehicleMessage()) == true and #vehicleSent() == 1)
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_removed" })
    assert(publish(vehicleMessage({ seq = 2 })) == true and #vehicleSent() == 1, "after the removal")
    server(GRANT)
    assert(publish(vehicleMessage({ seq = 3 })) == true and #vehicleSent() == 2)
    server({ v = V, op = "session", active = false, player = "1" })
    assert(publish(vehicleMessage({ seq = 4 })) == true and #vehicleSent() == 2, "after the session's end")
    -- A newer epoch of a granted Titan is another Titan: the old epoch is not this controller's any more.
    boot(); server(SESSION); server(grantWith({ epoch = 2 }))
    assert(publish(vehicleMessage()) == true and #vehicleSent() == 0, "a blow for the previous epoch")
    assert(publish(vehicleMessage({ epoch = 2 })) == true and #vehicleSent() == 1)
end)

test("blows on cars spend the one forwarding budget with the observations: a refused send is the cue to keep it, and it refills with time", function()
    granted()
    local accepted = 0
    for index = 1, 100 do
        local message = index % 3 == 0 and vehicleMessage({ seq = index })
            or index % 3 == 1 and statusMessage({ seq = index }) or observedMessage({ seq = index })
        if publish(message) then accepted = accepted + 1 end
    end
    assert(accepted == 30 and #vehicleSent() + #statusSent() + #observedSent() == 30, "the burst, no more, whichever kind spent it: " .. accepted)
    assert(#vehicleSent() == 10 and vehicleSent()[10][1].seq == 30, "what was refused was not forwarded, and the order is kept")
    now = now + 1
    assert(publish(vehicleMessage({ seq = 31 })) == true and #vehicleSent() == 11, "the budget refills with time")
    for _ = 1, 100 do publish({ v = V, op = "request", action = "spawn" }) end
    assert(publish(vehicleMessage({ seq = 32 })) == false and #vehicleSent() == 11)
    assert(publish(statusMessage({ seq = 33 })) == false and #statusSent() == 10)
end)

-- ---------------------------------------------------------------------------
-- Blows on players: what the controller's weapons landed on another player's body leaves as its own event, once, as a validated
-- copy, for the controller's own grant only, under the same forwarding budget. The victim is named by the player id the bridge
-- resolved and the record by name; the amount is the server's, so there is none to forward.
-- ---------------------------------------------------------------------------
local function playerMessage(extra)
    local message = { v = V, op = "player_hit", id = "9", epoch = 1, seq = 1, player = "3", record = "Attacks.BT7274_XO16_Hit", count = 2 }
    for key, value in pairs(extra or {}) do message[key] = value end
    return message
end
local function playerSent() return sentNamed(T.event.player) end

test("a blow on a player leaves for the controller's own Titan and epoch as a validated copy, on its own event", function()
    granted()
    local input = playerMessage()
    assert(publish(input) == true)
    local out = playerSent()
    local first = out[1] and out[1][1]
    assert(#out == 1 and select("#", table.unpack(out[1])) == 1 and first ~= input, "one copy, one argument")
    assert(first.v == V and first.op == "player_hit" and first.id == "9" and first.epoch == 1 and first.seq == 1
        and first.player == "3" and first.record == "Attacks.BT7274_XO16_Hit" and first.count == 2)
    local keys = {}
    for key in pairs(first) do keys[#keys + 1] = key end
    table.sort(keys)
    assert(table.concat(keys, ",") == "count,epoch,id,op,player,record,seq,v", table.concat(keys, ","))
    input.count, input.player = 9, "4"
    assert(first.count == 2 and first.player == "3", "a later write to the controller's table changes nothing sent")
    -- The extremes are the schema's: the largest count, and a record of the longest length.
    assert(publish(playerMessage({ seq = 2, count = T.limits.playerHitCount })) == true
        and publish(playerMessage({ seq = 3, count = 1, record = ("A"):rep(T.limits.actionRecord) })) == true)
    out = playerSent()
    assert(#out == 3 and out[2][1].count == 64 and #out[3][1].record == T.limits.actionRecord)
    assert(#sentNamed(T.event.frame) == 0 and #sentNamed(T.event.result) == 0 and #sentNamed(T.event.carry) == 0
        and #sentNamed(T.event.request) == 0 and #sentNamed(T.event.hit) == 0 and #sentNamed(T.event.status) == 0
        and #sentNamed(T.event.vehicle) == 0, "a blow on a player travelled on another event")
end)

test("a blow on a player of another Titan, a foreign epoch or a malformed one is consumed here and never forwarded", function()
    granted()
    local function without(key)
        local message = playerMessage()
        message[key] = nil
        return message
    end
    for _, bad in ipairs({
        playerMessage({ id = "10" }), playerMessage({ id = 9 }), playerMessage({ epoch = 2 }), playerMessage({ epoch = 1.5 }),
        playerMessage({ seq = 0 }), playerMessage({ seq = 1.5 }), playerMessage({ seq = 0 / 0 }), playerMessage({ seq = "1" }),
        playerMessage({ v = 1 }), playerMessage({ op = "hit" }), playerMessage({ extra = 1 }), playerMessage({ request = 1 }),
        -- the fields of the other reports are not the fields of a blow on a player
        playerMessage({ vehicle = "14" }), playerMessage({ share = 25 }), playerMessage({ amount = 8 }),
        playerMessage({ target = { kind = "titan", id = "12", epoch = 1, owner = "2" } }), playerMessage({ point = { x = 0, y = 0, z = 0 } }),
        without("player"), without("record"), without("count"),
        playerMessage({ player = 3 }), playerMessage({ player = "0" }), playerMessage({ player = "03" }),
        playerMessage({ player = "x" }), playerMessage({ player = "" }), playerMessage({ player = ("9"):rep(17) }),
        playerMessage({ record = 5 }), playerMessage({ record = "" }), playerMessage({ record = "Attacks X" }),
        playerMessage({ record = ("A"):rep(T.limits.actionRecord + 1) }),
        playerMessage({ count = 0 }), playerMessage({ count = -1 }), playerMessage({ count = 1.5 }),
        playerMessage({ count = T.limits.playerHitCount + 1 }), playerMessage({ count = 0 / 0 }), playerMessage({ count = 1 / 0 }),
        playerMessage({ count = "2" }), playerMessage({ count = true }),
    }) do
        now = now + 0.5   -- every message, valid or not, spends a token before it is looked at: keep the bucket full
        assert(publish(bad) == true, "a malformed blow on a player must be consumed, not held")
    end
    assert(#playerSent() == 0, "a malformed or foreign blow on a player left this machine: " .. #playerSent())
    -- The controller cannot pick the event: only the one op is forwarded, under the one event name.
    for _, op in ipairs({ "onTitanPlayerHit", "player", "playerHit", "damagePlayer", "vehicle_hit", "hit_observed", "status_observed" }) do
        now = now + 0.5
        assert(publish(playerMessage({ op = op })) == true)
    end
    assert(#playerSent() == 0 and #vehicleSent() == 0 and #observedSent() == 0 and #statusSent() == 0
        and #sent == 1 and sent[1].name == T.event.ready, "another op reached the server")
    assert(publish(playerMessage()) == true and #playerSent() == 1, "the good one still passes")
end)

test("a blow on a player needs this controller's grant: before it, after the removal or the session's end it goes nowhere", function()
    boot(); server(SESSION)
    assert(publish(playerMessage()) == true and #playerSent() == 0, "before the grant")
    server(GRANT)
    assert(publish(playerMessage()) == true and #playerSent() == 1)
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_removed" })
    assert(publish(playerMessage({ seq = 2 })) == true and #playerSent() == 1, "after the removal")
    server(GRANT)
    assert(publish(playerMessage({ seq = 3 })) == true and #playerSent() == 2)
    server({ v = V, op = "session", active = false, player = "1" })
    assert(publish(playerMessage({ seq = 4 })) == true and #playerSent() == 2, "after the session's end")
    -- A newer epoch of a granted Titan is another Titan: the old epoch is not this controller's any more.
    boot(); server(SESSION); server(grantWith({ epoch = 2 }))
    assert(publish(playerMessage()) == true and #playerSent() == 0, "a blow for the previous epoch")
    assert(publish(playerMessage({ epoch = 2 })) == true and #playerSent() == 1)
end)

test("blows on players spend the one forwarding budget with the observations: a refused send is the cue to keep it", function()
    granted()
    local accepted = 0
    for index = 1, 100 do
        local message = index % 3 == 0 and playerMessage({ seq = index })
            or index % 3 == 1 and vehicleMessage({ seq = index }) or statusMessage({ seq = index })
        if publish(message) then accepted = accepted + 1 end
    end
    assert(accepted == 30 and #playerSent() + #vehicleSent() + #statusSent() == 30, "the burst, no more, whichever kind spent it: " .. accepted)
    assert(#playerSent() == 10 and playerSent()[10][1].seq == 30, "what was refused was not forwarded, and the order is kept")
    now = now + 1
    assert(publish(playerMessage({ seq = 31 })) == true and #playerSent() == 11, "the budget refills with time")
    for _ = 1, 100 do publish({ v = V, op = "request", action = "spawn" }) end
    assert(publish(playerMessage({ seq = 32 })) == false and #playerSent() == 11)
end)

-- ---------------------------------------------------------------------------
-- Blows on NPCs: what the controller's weapons landed on an NPC the platform owns leaves as its own event, once, as a validated
-- copy, for the controller's own grant only, under the same forwarding budget. The NPC is named by the platform id the bridge
-- resolved from its engine entity, the blow by its record and kind; the amount is the mission's, so there is none to forward.
-- ---------------------------------------------------------------------------
local function npcMessage(extra)
    local message = { v = V, op = "npc_hit", id = "9", epoch = 1, seq = 1, npc = "77", record = "Attacks.BT7274_XO16_Hit", kind = "round",
        point = { x = 3, y = 4, z = 5 } }
    for key, value in pairs(extra or {}) do message[key] = value end
    return message
end
local function npcSent() return sentNamed(T.event.npc) end

test("a blow on an NPC leaves for the controller's own Titan and epoch as a validated copy, on its own event", function()
    granted()
    local input = npcMessage()
    assert(publish(input) == true)
    local out = npcSent()
    local first = out[1] and out[1][1]
    assert(#out == 1 and select("#", table.unpack(out[1])) == 1 and first ~= input and first.point ~= input.point, "one copy, one argument")
    assert(first.v == V and first.op == "npc_hit" and first.id == "9" and first.epoch == 1 and first.seq == 1
        and first.npc == "77" and first.record == "Attacks.BT7274_XO16_Hit" and first.kind == "round"
        and first.point.x == 3 and first.point.y == 4 and first.point.z == 5)
    local keys = {}
    for key in pairs(first) do keys[#keys + 1] = key end
    table.sort(keys)
    assert(table.concat(keys, ",") == "epoch,id,kind,npc,op,point,record,seq,v", table.concat(keys, ","))
    input.npc, input.point.x, input.kind = "78", 99, "blast"
    assert(first.npc == "77" and first.point.x == 3 and first.kind == "round", "a later write to the controller's table changes nothing sent")
    -- Every kind of the closed set, the longest record and id, and the largest point are the schema's.
    for index, kind in ipairs({ "blast", "melee", "blade", "other" }) do
        assert(publish(npcMessage({ seq = index + 1, kind = kind, npc = ("9"):rep(16), record = ("A"):rep(T.limits.actionRecord),
            point = { x = T.limits.coordinate, y = -T.limits.coordinate, z = 0 } })) == true)
    end
    out = npcSent()
    assert(#out == 5 and out[5][1].kind == "other" and #out[5][1].record == T.limits.actionRecord and out[5][1].npc == ("9"):rep(16))
    assert(#sentNamed(T.event.frame) == 0 and #sentNamed(T.event.result) == 0 and #sentNamed(T.event.carry) == 0
        and #sentNamed(T.event.request) == 0 and #sentNamed(T.event.hit) == 0 and #sentNamed(T.event.status) == 0
        and #sentNamed(T.event.vehicle) == 0 and #sentNamed(T.event.player) == 0, "a blow on an NPC travelled on another event")
end)

test("a blow on an NPC of another Titan, a foreign epoch or a malformed one is consumed here and never forwarded", function()
    granted()
    local function without(key)
        local message = npcMessage()
        message[key] = nil
        return message
    end
    local limit = T.limits.coordinate
    for _, bad in ipairs({
        npcMessage({ id = "10" }), npcMessage({ id = 9 }), npcMessage({ epoch = 2 }), npcMessage({ epoch = 1.5 }),
        npcMessage({ seq = 0 }), npcMessage({ seq = 1.5 }), npcMessage({ seq = 0 / 0 }), npcMessage({ seq = "1" }),
        npcMessage({ v = 1 }), npcMessage({ op = "hit" }), npcMessage({ extra = 1 }), npcMessage({ request = 1 }),
        -- the fields of the other reports are not the fields of a blow on an NPC
        npcMessage({ vehicle = "14" }), npcMessage({ share = 25 }), npcMessage({ count = 2 }), npcMessage({ player = "3" }),
        npcMessage({ amount = 8 }), npcMessage({ target = { kind = "titan", id = "12", epoch = 1, owner = "2" } }),
        without("npc"), without("record"), without("kind"), without("point"),
        npcMessage({ npc = 77 }), npcMessage({ npc = "0" }), npcMessage({ npc = "077" }), npcMessage({ npc = "x" }),
        npcMessage({ npc = "" }), npcMessage({ npc = "7.5" }), npcMessage({ npc = ("9"):rep(17) }), npcMessage({ npc = true }),
        npcMessage({ record = 5 }), npcMessage({ record = "" }), npcMessage({ record = "Attacks X" }),
        npcMessage({ record = ("A"):rep(T.limits.actionRecord + 1) }),
        npcMessage({ kind = "ranged" }), npcMessage({ kind = "ROUND" }), npcMessage({ kind = "" }), npcMessage({ kind = 5 }),
        npcMessage({ kind = {} }), npcMessage({ kind = true }),
        npcMessage({ point = {} }), npcMessage({ point = { x = 1, y = 2 } }), npcMessage({ point = { x = 1, y = 2, z = 3, w = 4 } }),
        npcMessage({ point = { x = 0 / 0, y = 0, z = 0 } }), npcMessage({ point = { x = 1 / 0, y = 0, z = 0 } }),
        npcMessage({ point = { x = limit + 1, y = 0, z = 0 } }), npcMessage({ point = { x = "1", y = 2, z = 3 } }), npcMessage({ point = 5 }),
    }) do
        now = now + 0.5   -- every message, valid or not, spends a token before it is looked at: keep the bucket full
        assert(publish(bad) == true, "a malformed blow on an NPC must be consumed, not held")
    end
    assert(#npcSent() == 0, "a malformed or foreign blow on an NPC left this machine: " .. #npcSent())
    -- The controller cannot pick the event: only the one op is forwarded, under the one event name.
    for _, op in ipairs({ "onTitanNpcHit", "npc", "npcHit", "damageNpc", "player_hit", "vehicle_hit", "hit_observed", "status_observed" }) do
        now = now + 0.5
        assert(publish(npcMessage({ op = op })) == true)
    end
    assert(#npcSent() == 0 and #playerSent() == 0 and #vehicleSent() == 0 and #observedSent() == 0 and #statusSent() == 0
        and #sent == 1 and sent[1].name == T.event.ready, "another op reached the server")
    assert(publish(npcMessage()) == true and #npcSent() == 1, "the good one still passes")
end)

test("a blow on an NPC needs this controller's grant: before it, after the removal or the session's end it goes nowhere", function()
    boot(); server(SESSION)
    assert(publish(npcMessage()) == true and #npcSent() == 0, "before the grant")
    server(GRANT)
    assert(publish(npcMessage()) == true and #npcSent() == 1)
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_removed" })
    assert(publish(npcMessage({ seq = 2 })) == true and #npcSent() == 1, "after the removal")
    server(GRANT)
    assert(publish(npcMessage({ seq = 3 })) == true and #npcSent() == 2)
    server({ v = V, op = "session", active = false, player = "1" })
    assert(publish(npcMessage({ seq = 4 })) == true and #npcSent() == 2, "after the session's end")
    -- A newer epoch of a granted Titan is another Titan: the old epoch is not this controller's any more.
    boot(); server(SESSION); server(grantWith({ epoch = 2 }))
    assert(publish(npcMessage()) == true and #npcSent() == 0, "a blow for the previous epoch")
    assert(publish(npcMessage({ epoch = 2 })) == true and #npcSent() == 1)
end)

test("blows on NPCs spend the one forwarding budget with the other reports: a refused send is the cue to keep it", function()
    granted()
    local accepted = 0
    for index = 1, 100 do
        local message = index % 4 == 0 and npcMessage({ seq = index }) or index % 4 == 1 and playerMessage({ seq = index })
            or index % 4 == 2 and vehicleMessage({ seq = index }) or statusMessage({ seq = index })
        if publish(message) then accepted = accepted + 1 end
    end
    assert(accepted == 30 and #npcSent() + #playerSent() + #vehicleSent() + #statusSent() == 30, "the burst, no more, whichever kind spent it: " .. accepted)
    assert(#npcSent() == 7 and npcSent()[7][1].seq == 28, "what was refused was not forwarded, and the order is kept")
    now = now + 1
    assert(publish(npcMessage({ seq = 101 })) == true and #npcSent() == 8, "the budget refills with time")
    for _ = 1, 100 do publish({ v = V, op = "request", action = "spawn" }) end
    assert(publish(npcMessage({ seq = 102 })) == false and #npcSent() == 8)
end)

test("the server's `log` command reaches the controller as a closed message; anything else under that action is dropped", function()
    granted()
    server({ v = V, op = "command", action = "log", value = "on" })
    server({ v = V, op = "command", action = "log", value = "off" })
    server({ v = V, op = "command", action = "log", value = "loud" })
    server({ v = V, op = "command", action = "log" })
    server({ v = V, op = "command", action = "log", value = "on", extra = 1 })
    local list = delivered("command")
    assert(#list == 2 and list[1].action == "log" and list[1].value == "on" and list[2].value == "off", #list)
end)

test("the controller cannot publish a grant or a loadout: nothing about it ever leaves this machine", function()
    granted()
    local before = #sent
    publish({ v = V, op = "loadout", id = "9", epoch = 1, revision = 9, loadout = T.loadout.defaults() })
    publish(grantWith({ revision = 9 }))
    publish({ v = V, op = "setLoadout", id = "9", epoch = 1, loadout = { sentry = 0 } })
    publish({ v = V, op = "request", action = "loadout" })
    assert(#sent == before and #sentNamed(T.event.carry) == 0, "the controller reached the server with a loadout")
end)

-- ---------------------------------------------------------------------------
-- The mission's controls: the grant's options and the class, hold and credit_kill messages. The forwarder relays each only for the
-- controller's own Titan and epoch, whole and validated, in order; the class shares the loadout's revision. What the controller does
-- with them is live acceptance; what its schema accepts of them is the twin section below.
-- ---------------------------------------------------------------------------
local ABILITIES = { "missiles", "vortex", "smoke", "dash", "jets", "sentry", "flight", "designator", "core" }
local function classMessage(revision, extra)
    local message = { v = V, op = "class", id = "9", epoch = 1, revision = revision, loadout = T.loadout.defaults(),
        class = { id = "vanguard", label = "Vanguard", weapon = "xo16", speed = 1.0,
            abilities = { missiles = true, vortex = true, smoke = false, dash = false, jets = true, sentry = false, flight = false,
                designator = false, core = true } } }
    for key, value in pairs(extra or {}) do message[key] = value end
    return message
end
local function holdMessage(held, extra)
    local message = { v = V, op = "hold", id = "9", epoch = 1, held = held }
    for key, value in pairs(extra or {}) do message[key] = value end
    return message
end
local function creditMessage(rank, extra)
    local message = { v = V, op = "credit_kill", id = "9", epoch = 1, rank = rank }
    for key, value in pairs(extra or {}) do message[key] = value end
    return message
end

test("a grant's piloted and hold options reach the controller, and a malformed one grants nothing", function()
    boot(); server(SESSION)
    server(grantWith({ piloted = true, hold = true }))
    local grants = delivered("grant")
    assert(#grants == 1 and grants[1].piloted == true and grants[1].hold == true and grants[1].revision == 1)
    publish(cetFrame())
    assert(#sentNamed(T.event.frame) == 1, "a good grant owns the Titan")
    boot(); server(SESSION)
    server(grantWith({ piloted = false }))
    grants = delivered("grant")
    assert(#grants == 1 and grants[1].piloted == nil and grants[1].hold == nil, "a false option is not carried on")
    for _, bad in ipairs({ { piloted = "yes" }, { hold = 1 }, { piloted = {} }, { hold = "true" } }) do
        boot(); server(SESSION)
        server(grantWith(bad))
        assert(#delivered("grant") == 0, "a malformed option reached the controller")
        publish(cetFrame())
        assert(#sentNamed(T.event.frame) == 0, "a malformed grant still owned the Titan")
    end
end)

test("a class update reaches the controller only for its own Titan and epoch and only when newer than the loadout's last word", function()
    granted()
    server(classMessage(2))
    local list = delivered("class")
    assert(#list == 1 and list[1].v == V and list[1].id == "9" and list[1].revision == 2 and list[1].class.id == "vanguard")
    assert(list[1].class.abilities.missiles == true and list[1].class.abilities.dash == false and list[1].class.speed == 1.0)
    assert(sameMap(list[1].loadout, T.loadout.defaults()))
    -- one revision counter for both: a loadout of the same revision is not newer, the next is
    server(loadoutUpdate(2, { sentry = 0 }))
    assert(#delivered("loadout") == 0, "a loadout as old as the class")
    server(loadoutUpdate(3, { sentry = 0 }))
    assert(#delivered("loadout") == 1)
    server(classMessage(3))
    assert(#delivered("class") == 1, "a class as old as the loadout")
    server(classMessage(4))
    assert(#delivered("class") == 2 and delivered("class")[2].revision == 4)
    -- other Titans, other epochs and the past are not the controller's
    server(classMessage(9, { id = "10" }))
    server(classMessage(9, { epoch = 2 }))
    server(classMessage(1))
    assert(#delivered("class") == 2)
    -- a malformed one never moves the revision: the next valid word is still accepted
    local bad = classMessage(50)
    bad.class.abilities.nope = true
    server(bad)
    server(classMessage(50, { extra = true }))
    server(classMessage(50, { v = 1 }))
    server(classMessage(0))
    server(classMessage(1.5))
    server(classMessage("7"))
    local noWeapon = classMessage(50)
    noWeapon.class.weapon = "laser"
    server(noWeapon)
    local noMap = classMessage(50)
    noMap.loadout.sentry = 2
    server(noMap)
    assert(#delivered("class") == 2)
    server(classMessage(5))
    assert(#delivered("class") == 3 and delivered("class")[3].revision == 5)
    -- clearing the class is a class message with no class
    local cleared = classMessage(6)
    cleared.class = nil
    server(cleared)
    assert(#delivered("class") == 4 and delivered("class")[4].class == nil and delivered("class")[4].revision == 6)

    -- before any grant, after a removal, for somebody else's Titan and after the session: nothing to classify
    boot(); server(SESSION)
    server(classMessage(2))
    assert(#delivered("class") == 0, "a class before the grant")
    server(GRANT)
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_removed" })
    server(classMessage(2))
    assert(#delivered("class") == 0, "a class after the removal")
    server(grantWith({ id = "11" }))
    server(classMessage(2, { id = "11" }))
    assert(#delivered("class") == 1 and delivered("class")[1].id == "11", "a new Titan counts its own revisions")
    server(grantWith({ id = "12", owner = "2" }))
    server(classMessage(2, { id = "12" }))
    assert(#delivered("class") == 1, "somebody else's Titan is not ours")
    server({ v = V, op = "session", active = false, player = "1" })
    server(classMessage(3, { id = "11" }))
    assert(#delivered("class") == 1, "a class after the session ended")
end)

test("a hold and a kill credit reach the controller only for its own Titan and epoch, closed and in order", function()
    granted()
    server(holdMessage(true)); server(creditMessage("grunt")); server(holdMessage(false)); server(creditMessage("heavy"))
    server(creditMessage("rare"))
    drain()
    local seen = {}
    for _, message in ipairs(polled) do
        if message.op == "hold" then seen[#seen + 1] = "hold:" .. tostring(message.held)
        elseif message.op == "credit_kill" then seen[#seen + 1] = "credit:" .. message.rank end
    end
    assert(table.concat(seen, ",") == "hold:true,credit:grunt,hold:false,credit:heavy,credit:rare", table.concat(seen, ","))
    -- a repeated hold is relayed again: the controller's own gate is idempotent, and a hold is not a revision
    server(holdMessage(true)); server(holdMessage(true))
    assert(#delivered("hold") == 4)
    local before = #delivered("hold") + #delivered("credit_kill")
    -- other Titans and epochs, malformed and foreign
    server(holdMessage(true, { id = "10" })); server(holdMessage(true, { epoch = 2 }))
    server(creditMessage("grunt", { id = "10" })); server(creditMessage("grunt", { epoch = 2 }))
    for _, mutate in ipairs({
        { holdMessage, true, { held = "yes" } }, { holdMessage, true, { held = 1 } }, { holdMessage, true, { extra = true } },
        { holdMessage, true, { v = 1 } }, { holdMessage, true, { epoch = 0 } }, { holdMessage, true, { id = "x" } },
        { creditMessage, "boss", {} }, { creditMessage, "Grunt", {} }, { creditMessage, 5, {} }, { creditMessage, "grunt", { extra = 1 } },
        { creditMessage, "grunt", { v = 1 } }, { creditMessage, "grunt", { epoch = 1.5 } },
    }) do
        server(mutate[1](mutate[2], mutate[3]))
    end
    assert(#delivered("hold") + #delivered("credit_kill") == before, "a foreign or malformed message reached the controller")
    -- before the grant, after the removal and after the session: nothing to hold or credit
    boot(); server(SESSION)
    server(holdMessage(true)); server(creditMessage("grunt"))
    assert(#delivered("hold") == 0 and #delivered("credit_kill") == 0, "before the grant")
    server(GRANT)
    server({ v = V, op = "remove", id = "9", epoch = 1, reason = "owner_removed" })
    server(holdMessage(true)); server(creditMessage("grunt"))
    assert(#delivered("hold") == 0 and #delivered("credit_kill") == 0, "after the removal")
    server(grantWith({ id = "11" }))
    server(holdMessage(true, { id = "11" }))
    assert(#delivered("hold") == 1)
    server({ v = V, op = "session", active = false, player = "1" })
    server(holdMessage(false, { id = "11" })); server(creditMessage("grunt", { id = "11" }))
    assert(#delivered("hold") == 1 and #delivered("credit_kill") == 0, "after the session ended")
end)

test("the controller cannot publish a class, a hold or a kill credit: nothing of the kind leaves this machine", function()
    granted()
    local before = #sent
    publish(classMessage(9))
    publish(holdMessage(true))
    publish(creditMessage("heavy"))
    publish({ v = V, op = "setClass", id = "9", epoch = 1 })
    publish({ v = V, op = "request", action = "class" })
    publish({ v = V, op = "request", action = "hold" })
    assert(#sent == before and #sentNamed(T.event.carry) == 0, "the controller reached the server with a mission control")
end)

test("the ground export traces Static and Terrain under each point, only once the controller runs", function()
    boot({ hold = true })
    local none, why = exported.ground({ { x = 1, y = 2, z = 3 } }, 40)
    assert(none == nil and why == "controller_unavailable", "no controller, no trace")
    fire("onClientResourceStart", "op77_lightrp_titans")
    local casts = {}
    local sqs = {}
    function sqs:SyncRaycastByCollisionGroup(from, to, group, _, staticOnly, dynamicOnly)
        casts[#casts + 1] = { from = from, to = to, group = group, flags = { staticOnly, dynamicOnly } }
        if from.x == 1 then return group == "Terrain", { position = { x = 1, y = 2, z = 80.5 } } end
        if from.x == 2 then return true, { position = { x = 2, y = 2, z = group == "Static" and 86 or 80 } } end
        if from.x == 3 then error("trace failed", 0) end
        return false, nil
    end
    package.loaded["controller.open77_titan_env"] = {
        Game = { GetSpatialQueriesSystem = function() return sqs end },
        Vector4 = { new = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end },
    }
    local answers = exported.ground({ { x = 1, y = 2, z = 80 }, { x = 2, y = 2, z = 80 }, { x = 3, y = 2, z = 80 }, "nothing",
        { x = 5, y = 2, z = 80 } }, 40)
    package.loaded["controller.open77_titan_env"] = nil
    assert(#answers == 5, "one answer per point")
    assert(answers[1].terrain == 80.5 and answers[1].static == false, "open ground: terrain only")
    assert(answers[2].static == 86 and answers[2].terrain == 80, "both groups answer: the caller tells a tree from the ground")
    assert(answers[3].static == false and answers[3].terrain == false, "a raised trace is no ground")
    assert(answers[4].static == false and answers[5].terrain == false, "a bad point and a miss")
    assert(casts[1].from.z == 120 and casts[1].to.z == 40 and casts[1].flags[1] == false and casts[1].flags[2] == false,
        "40 m above to 40 m below, the group's own filter")
    local many = {}
    for i = 1, 40 do many[i] = { x = 9, y = 9, z = 0 } end
    package.loaded["controller.open77_titan_env"] = { Game = { GetSpatialQueriesSystem = function() return sqs end }, Vector4 = { new = function(x, y, z) return { x = x, y = y, z = z } end } }
    assert(#exported.ground(many, 40) == 32, "at most 32 points")
    package.loaded["controller.open77_titan_env"] = nil
    assert(exported.ground(many, 0) == nil and exported.ground(many, 500) == nil and exported.ground("x", 40) == nil, "bad reach or points")
end)

-- ---------------------------------------------------------------------------
-- The schema twin: controller/open77_titan_schema.lua is the controller's own validator of what the resource delivers. Loaded for
-- real here (its environment module is the plain table of this state's globals), it is held to shared.lua: the same names, the same
-- bounds, the same verdict on the messages above, and the same copy of what it accepts.
-- ---------------------------------------------------------------------------
package.path = root .. "?.lua;" .. package.path
package.preload["controller.open77_titan_env"] = function()
    local env = {}
    for key, value in pairs(_G) do env[key] = value end
    env.require = require
    return env
end
package.loaded["controller.open77_titan_schema"] = nil
local S = require("controller.open77_titan_schema")

local function listOf(set)
    local list = {}
    for key in pairs(set) do list[#list + 1] = key end
    table.sort(list)
    return table.concat(list, ",")
end

test("the schema twin loads for real, with the resource's own loadout and catalog", function()
    assert(S.VERSION == V and type(S.inbound) == "function")
    assert(S.loadout and S.loadoutError == nil, tostring(S.loadoutError))
    assert(sameMap(S.loadout.max, T.loadout.max) and sameMap(S.loadout.defaults(), T.loadout.defaults()))
    assert(S.loadout.weaponPerk("rail") == "railgun" and S.loadout.weaponPerk("fist") == "fist" and S.loadout.weaponPerk("laser") == nil)
    local weapons = { "xo16", "rail", "pred", "sword", "fist" }
    for _, weapon in ipairs(weapons) do
        assert(S.loadout.weaponPerk(weapon) == T.loadout.weaponPerk(weapon), weapon)
        local mine, theirs = S.loadout.forClass(weapon, { xoammo = 1 }), T.loadout.forClass(weapon, { xoammo = 1 })
        assert(mine and theirs and sameMap(mine, theirs), weapon)
    end
end)

test("the schema twin names the same controls, commands, weapons, abilities, ranks and bounds as shared.lua", function()
    assert(listOf(S.INPUT) == listOf(T.inputs))
    for name, kind in pairs(T.inputs) do assert(S.INPUT[name] == kind, name) end
    assert(S.INPUT_LIMIT.axis == T.inputLimits.axis and S.INPUT_LIMIT.relative == T.inputLimits.relative)
    assert(listOf(S.COMMANDS) == listOf(T.commandActions) and listOf(S.WEAPONS) == listOf(T.weapons) and listOf(S.ACTIONS) == listOf(T.actions))
    assert(listOf(S.CLASS.abilities) == listOf(T.classAbilities) and listOf(S.CLASS.abilities) == table.concat((function()
        local sorted = {}
        for _, name in ipairs(ABILITIES) do sorted[#sorted + 1] = name end
        table.sort(sorted)
        return sorted
    end)(), ","))
    assert(S.CLASS.speedMin == T.classSpeed.min and S.CLASS.speedMax == T.classSpeed.max)
    assert(S.CLASS.harmMin == T.classHarm.min and S.CLASS.harmMax == T.classHarm.max)
    assert(S.CLASS.regenMin == T.classRegen.min and S.CLASS.regenMax == T.classRegen.max)
    assert(listOf(S.RANKS) == listOf(T.killRanks) and listOf(S.RANKS) == "grunt,heavy,rare")
    assert(S.ACTION.record == T.limits.actionRecord and S.ACTION.reason == T.limits.actionReason and S.ACTION.amount == T.limits.actionAmount)
end)

-- Both validators on one message: whether each accepts it.
local function verdicts(message)
    local shared = T.normalizeServerMessage(message, catalog)
    local twin = S.inbound(message)
    return shared ~= nil, twin ~= nil, shared, twin
end
local function sameClass(a, b)
    if a == nil or b == nil then return a == b end
    if a.id ~= b.id or a.label ~= b.label or a.weapon ~= b.weapon or a.speed ~= b.speed then return false end
    return sameMap(a.abilities, b.abilities)
end

test("the schema twin gives the grant's options the verdict shared.lua gives, and the same copy", function()
    local function check(label, changes, accepted)
        local message = grantWith(changes)
        local shared, twin, a, b = verdicts(message)
        assert(shared == accepted and twin == accepted, label .. ": shared " .. tostring(shared) .. ", twin " .. tostring(twin))
        if accepted then
            assert(a.piloted == b.piloted and a.hold == b.hold and a.id == b.id and a.epoch == b.epoch and a.owner == b.owner, label)
            assert(sameMap(a.loadout, b.loadout) and a.revision == 1 and b.revision == 1, label)
        end
    end
    check("plain", {}, true)
    check("piloted", { piloted = true }, true)
    check("hold", { hold = true }, true)
    check("both", { piloted = true, hold = true }, true)
    check("false options", { piloted = false, hold = false }, true)
    for _, value in ipairs({ 1, 0, "true", "", {}, print }) do
        check("piloted " .. type(value), { piloted = value }, false)
        check("hold " .. type(value), { hold = value }, false)
    end
    local _, _, shared, twin = verdicts(grantWith({ piloted = true, hold = false }))
    assert(shared.piloted == true and shared.hold == nil and twin.piloted == true and twin.hold == nil, "only a true option is carried on")
end)

test("the schema twin gives class, hold and credit_kill the verdict shared.lua gives, and the same copy", function()
    local cases = {}
    local function add(label, message) cases[#cases + 1] = { label, message } end
    -- class
    add("class", classMessage(2))
    local function classWith(mutate)
        local message = classMessage(2)
        mutate(message)
        return message
    end
    add("class cleared", classWith(function(m) m.class = nil end))
    add("class sparse", classWith(function(m) m.class.speed = nil; m.class.abilities = { core = true } end))
    add("class empty abilities", classWith(function(m) m.class.abilities = {} end))
    add("class speed low edge", classWith(function(m) m.class.speed = 0.5 end))
    add("class speed high edge", classWith(function(m) m.class.speed = 1.5 end))
    add("class harm", classWith(function(m) m.class.harm = 5 end))
    add("class harm high edge", classWith(function(m) m.class.harm = 50 end))
    add("class regen", classWith(function(m) m.class.regen = 2.5 end))
    add("class 32-char id", classWith(function(m) m.class.id = ("a"):rep(32) end))
    add("class 32-char label", classWith(function(m) m.class.label = ("L"):rep(32) end))
    add("class every weapon", classWith(function(m) m.class.weapon = "sword" end))
    for _, mutation in ipairs({
        { "extra key", function(m) m.extra = true end },
        { "old version", function(m) m.v = 1 end },
        { "id zero", function(m) m.id = "0" end },
        { "id text", function(m) m.id = "x" end },
        { "id number", function(m) m.id = 9 end },
        { "epoch zero", function(m) m.epoch = 0 end },
        { "epoch fraction", function(m) m.epoch = 1.5 end },
        { "revision zero", function(m) m.revision = 0 end },
        { "revision text", function(m) m.revision = "2" end },
        { "no revision", function(m) m.revision = nil end },
        { "no loadout", function(m) m.loadout = nil end },
        { "perk missing", function(m) m.loadout.sentry = nil end },
        { "perk over", function(m) m.loadout.sentry = 2 end },
        { "perk unknown", function(m) m.loadout.nope = 1 end },
        { "class text", function(m) m.class = "vanguard" end },
        { "class extra key", function(m) m.class.perks = {} end },
        { "class no id", function(m) m.class.id = nil end },
        { "class id capital", function(m) m.class.id = "Vanguard" end },
        { "class id space", function(m) m.class.id = "van guard" end },
        { "class id empty", function(m) m.class.id = "" end },
        { "class id long", function(m) m.class.id = ("a"):rep(33) end },
        { "class id number", function(m) m.class.id = 1 end },
        { "class label empty", function(m) m.class.label = "" end },
        { "class label long", function(m) m.class.label = ("L"):rep(33) end },
        { "class label accent", function(m) m.class.label = "caf\195\169" end },
        { "class label tab", function(m) m.class.label = "a\tb" end },
        { "class label number", function(m) m.class.label = 5 end },
        { "class weapon unknown", function(m) m.class.weapon = "laser" end },
        { "class weapon capital", function(m) m.class.weapon = "Rail" end },
        { "class weapon number", function(m) m.class.weapon = 1 end },
        { "class no weapon", function(m) m.class.weapon = nil end },
        { "class speed low", function(m) m.class.speed = 0.49 end },
        { "class speed high", function(m) m.class.speed = 1.51 end },
        { "class speed text", function(m) m.class.speed = "1" end },
        { "class speed NaN", function(m) m.class.speed = 0 / 0 end },
        { "class speed inf", function(m) m.class.speed = math.huge end },
        { "class harm low", function(m) m.class.harm = 0.09 end },
        { "class harm high", function(m) m.class.harm = 50.5 end },
        { "class harm text", function(m) m.class.harm = "5" end },
        { "class harm NaN", function(m) m.class.harm = 0 / 0 end },
        { "class regen low", function(m) m.class.regen = 0.2 end },
        { "class regen high", function(m) m.class.regen = 10.5 end },
        { "class regen text", function(m) m.class.regen = "2" end },
        { "class abilities text", function(m) m.class.abilities = "all" end },
        { "class abilities none", function(m) m.class.abilities = nil end },
        { "class ability unknown", function(m) m.class.abilities.nope = true end },
        { "class ability number", function(m) m.class.abilities.core = 1 end },
        { "class ability text", function(m) m.class.abilities.core = "true" end },
        { "class ability index", function(m) m.class.abilities[1] = true end },
    }) do
        add(mutation[1], classWith(mutation[2]))
    end
    -- hold and credit_kill
    add("hold on", holdMessage(true)); add("hold off", holdMessage(false))
    for _, bad in ipairs({ { held = "yes" }, { held = 1 }, { held = {} }, { held = false, extra = true }, { v = 1 }, { epoch = 0 },
        { epoch = 1.5 }, { id = "x" }, { id = "0" }, { id = 9 } }) do
        add("hold " .. listOf(bad), holdMessage(true, bad))
    end
    add("hold no held", holdMessage(nil))
    for _, rank in ipairs({ "grunt", "rare", "heavy" }) do add("credit " .. rank, creditMessage(rank)) end
    for _, rank in ipairs({ "boss", "Grunt", "grunt ", "", 5, true, {} }) do add("credit rank " .. type(rank), creditMessage(rank)) end
    for _, bad in ipairs({ { extra = 1 }, { v = 1 }, { epoch = 0 }, { epoch = 1.5 }, { id = "x" }, { id = "0" }, { id = 9 } }) do
        add("credit " .. listOf(bad), creditMessage("grunt", bad))
    end
    add("credit no rank", creditMessage(nil))

    local accepted, refused = 0, 0
    for _, case in ipairs(cases) do
        local label, message = case[1], case[2]
        local shared, twin, a, b = verdicts(message)
        assert(shared == twin, label .. ": shared " .. tostring(shared) .. ", twin " .. tostring(twin))
        if shared then
            accepted = accepted + 1
            assert(a.op == b.op and a.id == b.id and a.epoch == b.epoch, label)
            if a.op == "class" then
                assert(a.revision == b.revision and sameMap(a.loadout, b.loadout) and sameClass(a.class, b.class), label)
                if a.class then
                    local keys = 0
                    for _ in pairs(b.class.abilities) do keys = keys + 1 end
                    assert(keys == 9, label .. ": all nine abilities in the copy")
                end
            elseif a.op == "hold" then
                assert(a.held == b.held, label)
            else
                assert(a.rank == b.rank, label)
            end
        else
            refused = refused + 1
        end
    end
    assert(accepted == 17 and refused >= 67, accepted .. " accepted, " .. refused .. " refused: the battery changed")
end)

test("the schema twin copies what it accepts: nothing it returns aliases the message", function()
    local message = classMessage(2)
    local clean = S.inbound(message)
    assert(clean.class ~= message.class and clean.class.abilities ~= message.class.abilities and clean.loadout ~= message.loadout)
    message.class.label, message.class.abilities.core, message.loadout.sentry = "x", false, 0
    assert(clean.class.label == "Vanguard" and clean.class.abilities.core == true and clean.loadout.sentry == 1)
end)

test("the schema twin gives a blow on an NPC the verdict shared.lua gives, the same tokens and the same copy", function()
    assert(listOf(S.NPC.kinds) == listOf(T.npcKinds) and listOf(S.NPC.kinds) == "blade,blast,melee,other,round")
    assert(S.NPC.roundGap == T.limits.npcRoundGap, "the controller spaces its rounds as the server's bucket expects")
    local limit = T.limits.coordinate
    local function make(extra, drop)
        local message = npcMessage(extra)
        if drop then message[drop] = nil end
        return message
    end
    local cases = {
        { make(), true }, { make({ kind = "blast" }), true }, { make({ kind = "melee" }), true }, { make({ kind = "blade" }), true },
        { make({ kind = "other" }), true }, { make({ npc = ("9"):rep(16) }), true }, { make({ record = ("A"):rep(T.limits.actionRecord) }), true },
        { make({ point = { x = limit, y = -limit, z = 0 } }), true }, { make({ seq = 2 ^ 53 - 1 }), true },
        { make({ v = 1 }) }, { make({ op = "player_hit" }) }, { make({ extra = 1 }) }, { make({ count = 1 }) }, { make({ player = "3" }) },
        { make({ id = 9 }) }, { make({ id = "0" }) }, { make({ epoch = 0 }) }, { make({ epoch = 1.5 }) }, { make({ seq = 0 }) },
        { make({ seq = 1.5 }) }, { make({ seq = 2 ^ 53 }) }, { make({ npc = 77 }) }, { make({ npc = "0" }) }, { make({ npc = "077" }) },
        { make({ npc = ("9"):rep(17) }) }, { make({ record = "" }) }, { make({ record = "a b" }) },
        { make({ record = ("A"):rep(T.limits.actionRecord + 1) }) }, { make({ kind = "ranged" }) }, { make({ kind = "ROUND" }) },
        { make({ kind = 5 }) }, { make({ point = { x = 1, y = 2 } }) }, { make({ point = { x = limit + 1, y = 0, z = 0 } }) },
        { make({ point = { x = 0 / 0, y = 0, z = 0 } }) }, { make({ point = { x = 1, y = 2, z = 3, w = 4 } }) },
        { make({}, "npc") }, { make({}, "record") }, { make({}, "kind") }, { make({}, "point") }, { make({}, "seq") }, { make({}, "id") },
        { 5 }, { "npc_hit" }, { true },
    }
    local accepted = 0
    for index, case in ipairs(cases) do
        local message, want = case[1], case[2] == true
        local shared, sharedWhy = T.normalizeNpcHit(message)
        local twin, twinWhy = S.npc_hit(message)
        assert((shared ~= nil) == want and (twin ~= nil) == want, "case " .. index .. ": shared " .. tostring(shared ~= nil) .. ", twin " .. tostring(twin ~= nil))
        if want then
            accepted = accepted + 1
            assert(shared ~= message and twin ~= message and shared.point ~= message.point and twin.point ~= message.point, "a copy, never the message")
            assert(listOf(shared) == listOf(twin) and shared.npc == twin.npc and shared.record == twin.record and shared.kind == twin.kind
                and shared.seq == twin.seq and shared.epoch == twin.epoch and shared.id == twin.id and shared.v == twin.v and shared.op == twin.op
                and sameMap(shared.point, twin.point), "the same copy: case " .. index)
        elseif type(message) == "table" and sharedWhy ~= "observed_keys" then
            -- the tokens the server reports back and the controller's own diagnostics agree wherever both parse the keys
            assert(sharedWhy == twinWhy, "case " .. index .. ": " .. tostring(sharedWhy) .. " / " .. tostring(twinWhy))
        end
    end
    assert(accepted == 9, "the battery changed")
    -- The bridge's report is the message without its header, under the same rules.
    local report = { npc = "77", record = "Attacks.BT7274_XO16_Hit", kind = "round", point = { x = 1, y = 2, z = 3 } }
    local clean = S.npc_report(report)
    assert(clean and clean ~= report and clean.point ~= report.point and listOf(clean) == "kind,npc,point,record")
    for _, edit in ipairs({
        function(r) r.npc = 77 end, function(r) r.record = "" end, function(r) r.kind = "laser" end, function(r) r.point = {} end,
        function(r) r.seq = 1 end, function(r) r.extra = 1 end, function(r) r.npc = nil end,
    }) do
        local copy = { npc = "77", record = "Attacks.BT7274_XO16_Hit", kind = "round", point = { x = 1, y = 2, z = 3 } }
        edit(copy)
        assert(S.npc_report(copy) == nil)
    end
    assert(select(2, S.npc_report({ npc = "x", record = "", kind = "laser", point = {} })) == "npc_id"
        and select(2, S.npc_report({ npc = "7", record = "", kind = "laser", point = {} })) == "hit_record"
        and select(2, S.npc_report({ npc = "7", record = "a", kind = "laser", point = {} })) == "npc_kind"
        and select(2, S.npc_report({ npc = "7", record = "a", kind = "round", point = {} })) == "hit_point"
        and select(2, S.npc_report({ npc = "7", record = "a", kind = "round", extra = 1 })) == "report_keys"
        and select(2, S.npc_report("nothing")) == "report_keys")
end)

-- ---------------------------------------------------------------------------
-- The HUD state LightRP's HUD reads: the hudState export answers what the HUD module (controller/open77_titan_hud.lua, loaded for
-- real over the plain environment above) built last, and nil whenever V does not pilot. The fake world below gives the module only
-- what its gate asks for: its sections raise on everything else, are left out and reported, and the notice (one field the world
-- has) is what proves the table is the one built.
-- ---------------------------------------------------------------------------
test("the hudState export answers the state the HUD module built last, whatever the page took, and nil when V does not pilot or nothing runs", function()
    boot({ controller = "failed" })
    assert(exported.hudState() == nil, "a client without a controller has no HUD state")
    boot()
    assert(exported.hudState() == nil, "nothing built yet")
    local env = require("controller.open77_titan_env")
    local given, pageDown = {}, false
    env.render = { state = function(state)
        if pageDown then error("page down", 0) end
        given[#given + 1] = state == nil and "cleared" or state
    end }
    package.loaded["controller.open77_titan_hud"] = nil
    local diags = {}
    local world = {
        S = { driving = true, pilot = true, gone = false, paused = false, endMenu = false, clock = 0.0 },
        PS = { mode = "pilot", gun = {}, hp = {}, eject = true }, P = { hud = true }, FPC = { hpTop = 0.13 },
    }
    local ctx = { env = world, clock = 0.0, diag = function(key, text) diags[key] = text end }
    local hud = require("controller.open77_titan_hud").new(ctx)
    assert(exported.hudState() == nil, "a module that has not run says nothing")
    hud.frame()
    local built = exported.hudState()
    assert(type(built) == "table" and built.on == true and built.top == 0.13 and built.notice == "eject", "the built state")
    assert(built == given[1], "the table the page was given is the one answered")
    assert(diags["hud.hull"] and diags["hud.weapon"], "a section the world cannot answer is left out and said")
    -- A page that cannot take the state does not take it from LightRP's HUD: the state is kept all the same.
    pageDown, ctx.clock, world.PS.eject = true, 0.3, nil
    hud.frame()
    assert(diags["hud.send"] and exported.hudState() ~= built and exported.hudState().notice == nil, "the newest state, though the page refused it")
    pageDown = false
    -- A pause, a cut scene or a cockpit wall: not piloted, so nothing is answered, and the page is cleared.
    ctx.clock, world.S.paused = 0.6, true
    hud.frame()
    assert(exported.hudState() == nil and given[#given] == "cleared", "not piloted: no state, a cleared page")
    world.S.paused, ctx.clock = false, 0.9
    hud.frame()
    assert(exported.hudState() ~= nil, "piloted again")
    hud.clear()
    assert(exported.hudState() == nil, "the bridge clears it while the overlay is idle")
    env.render, package.loaded["controller.open77_titan_hud"] = nil, nil
end)

report(("%d client tests passed"):format(passed))
