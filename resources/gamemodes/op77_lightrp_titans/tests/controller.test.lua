-- op77_lightrp_titans: the controller's mission seam and the bridge's mission handlers, on the REAL controller.
--
-- Loads controller/init.lua and every bridge module as the game does (`require`), under a stub environment: every global the
-- controller reads that this harness does not define answers a stub that takes any call, so the 36,000 lines of the controller
-- load and its own functions run on their own tables (S, PS, P, FPF) with nothing of the game behind them. What is real here is
-- the code: the hold's gates (FPF.actionIn, FPF.bind, FPF.input and the frame functions it guards), the class's lock on the nine
-- abilities, the walk and run speed in pilotStep, the dismount and eject refusals, the bridge's handling of the grant's options and
-- of the hold, class and kill-credit messages (the piloted spawn, the queued instant seat, the weapon rule), the kill's core
-- charge and the HUD's mission fields. What is not: the game. Whether BT stands where V stood, whether the camera follows, whether
-- the seat looks right and what the HUD page draws are live acceptance.
--
-- Run from this resource's directory with any Lua 5.4 (from elsewhere, pass the resource's directory with its trailing slash):
--   lua tests/controller.test.lua
local root = ... or "./"
local passed = 0
local report = print
local prints = {}
print = function(...)
    local parts = {}
    for index = 1, select("#", ...) do parts[#parts + 1] = tostring((select(index, ...))) end
    prints[#prints + 1] = table.concat(parts, " ")
end

local function test(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    passed = passed + 1
    report("PASS " .. name)
end

package.path = root .. "?.lua;" .. package.path

-- ---------------------------------------------------------------------------
-- The stub environment: the controller's own (controller/open77_titan_env.lua) in shape. A name the controller may read (the
-- lists of controller/open77_titan_names.lua and what the environment defines itself) is a field; any other name is nil, as in the
-- game, so a name no list knows - a function a hand edit forgot to declare before it is used, say - fails here as it fails there.
-- What the game would answer to the controller's calls is a stub that takes any call and answers itself.
-- ---------------------------------------------------------------------------
local stub = {}
setmetatable(stub, {
    __index = function() return stub end, __call = function() return stub end,
    __add = function() return 1 end, __sub = function() return 1 end, __mul = function() return 1 end, __div = function() return 1 end,
    __concat = function() return "" end, __unm = function() return 0 end, __lt = function() return false end, __le = function() return false end,
})

local clock = 0
local diagnostics = {}
local names = dofile(root .. "controller/open77_titan_names.lua")
local environment = {}
for _, name in ipairs(names.lua) do environment[name] = _G[name] end
-- math as the real environment makes it: the interpreter the controller was written for has atan2
environment.math = {}
for key, value in pairs(math) do environment.math[key] = value end
environment.math.atan2 = function(y, x) return math.atan(y, x) end
environment.string = string
for _, name in ipairs(names.types) do environment[name] = stub end
for _, name in ipairs(names.functions) do environment[name] = stub end
-- The game's input types: real values, so that a press, a release and an axis are told apart as the controller tells them.
local KIND = { BUTTON_PRESSED = 1, BUTTON_RELEASED = 2, AXIS_CHANGE = 3, RELATIVE_CHANGE = 4, BUTTON_HOLD_COMPLETE = 5 }
environment.gameinputActionType = KIND
environment.Vector4 = { new = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end }
environment.Vector3 = { new = function(x, y, z) return { x = x, y = y, z = z } end }
environment.Vector2 = { new = function(x, y) return { x = x, y = y } end }
environment.Quaternion = { new = function(i, j, k, r) return { i = i, j = j, k = k, r = r } end }
environment.CName = { new = function(text) return text end }
environment.IsDefined = function(value) return value ~= nil end
environment.NewObject = function() return stub end
environment.EnumInt = function(value) return value end
environment.EnumName = function(_, value) return tostring(value) end
environment.FromVariant = function(value) return value end
environment.GetColorU32 = function() return 0 end
for _, name in ipairs({ "EulerAngles", "WorldPosition", "WorldTransform", "TweakDBID", "TweakDB", "Enum", "Variant", "ResRefOf", "RaRef" }) do
    environment[name] = stub
end

-- The platform: the log the controller and the bridge write, the clock, the stores, and the encoder the host gives the bridge.
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
environment.Open77 = {
    log = {
        info = function() end,
        warn = function(text) diagnostics[#diagnostics + 1] = text end,
        error = function(text) diagnostics[#diagnostics + 1] = text end,
    },
    time = { monotonic = function() return clock end },
    kvp = { get = function() return nil end, set = function() end, delete = function() end },
    json = { encode = encode },
}
environment.require = require

-- V: the place and heading the piloted spawn takes. `ground` is what the controller's ground probe answers (nil: none).
local V = { x = 10.5, y = -20.25, z = 3.0, yaw = 90.0 }
local ground = 2.5
local player = {
    GetWorldPosition = function() return { x = V.x, y = V.y, z = V.z } end,
    GetWorldYaw = function() return V.yaw end,
}
local GAME = setmetatable({ GetPlayer = function() return player end }, { __index = function() return stub end })
environment.Game = GAME
package.preload["controller.open77_titan_env"] = function() return environment end

-- The bridge as the controller requires it, with its attach table kept: the controller's file-local entry points
-- (spawnPilot, startPilot, startDismount ...) are what the bridge calls, and what the tests replace to see the calls.
local attached
package.preload["controller.open77_titan_bridge"] = function()
    package.preload["controller.open77_titan_bridge"] = nil
    local module = dofile(root .. "controller/open77_titan_bridge.lua")
    local attach = module.attach
    module.attach = function(env)
        attached = env
        return attach(env)
    end
    return module
end

local controller = require("controller.init")
local OP77 = require("controller.open77_titan_bridge")
local schema = require("controller.open77_titan_schema")
local gameplay = require("controller.open77_titan_gameplay")
assert(attached, "the controller did not attach to the bridge: " .. table.concat(prints, " | "))
local FPF, PS, S, P, FPC = attached.FPF, attached.PS, attached.S, attached.P, attached.FPC
local env = attached

-- The resource's link: what the controller publishes, and what the server sends it.
local inbox, published = {}, {}
OP77.link({
    send = function(message) published[#published + 1] = message; return true end,
    poll = function() return table.remove(inbox, 1) end,
})
local function publishedOps(op)
    local list = {}
    for _, message in ipairs(published) do if message.op == op then list[#list + 1] = message end end
    return list
end
local function lastDiag(needle)
    for index = #diagnostics, 1, -1 do
        if diagnostics[index]:find(needle, 1, true) then return diagnostics[index] end
    end
end

-- A game frame of the bridge: its tick (what the controller's wrapped update runs behind the controller's own update, which the
-- harness leaves out: it would search a game that is not there for the entity the recorder "spawned"), then the one part of the
-- controller's own update the loadout needs, its perk poll (FPF.perkFrame reads the server's levels into S.perk).
local function tick(seconds)
    for _ = 1, math.max(1, math.floor(seconds / 0.05 + 0.5)) do
        clock = clock + 0.05
        S.clock = clock
        OP77.tick(0.05)
        pcall(FPF.perkFrame)
    end
end
local function deliver(message) inbox[#inbox + 1] = message end

local DEFAULTS = schema.loadout.defaults()
local function grantMessage(id, extra)
    local message = { v = 2, op = "grant", id = id or "7001", epoch = 1, owner = "42", revision = 1, loadout = schema.loadout.defaults() }
    for key, value in pairs(extra or {}) do message[key] = value end
    return message
end
local function classMessage(revision, class, loadout, id)
    return { v = 2, op = "class", id = id or "7001", epoch = 1, revision = revision, loadout = loadout, class = class }
end
local function abilities(...)
    local map = { missiles = false, vortex = false, smoke = false, dash = false, jets = false, sentry = false, flight = false,
        designator = false, core = false }
    for _, name in ipairs({ ... }) do map[name] = true end
    return map
end
local function loadoutFor(weapon, changes)
    local map = schema.loadout.forClass(weapon, changes or {})
    assert(map, "no loadout for " .. weapon)
    return map
end

-- The calls the bridge makes of the controller's entry points; each replacement is undone by `restore()`.
local calls
local saved = {}
local function replace(table_, key, value)
    saved[#saved + 1] = { table_, key, table_[key] }
    table_[key] = value
end
local function restore()
    for index = #saved, 1, -1 do saved[index][1][saved[index][2]] = saved[index][3] end
    saved = {}
end

-- A clean controller and bridge: no session, no Titan, nothing held, no class, nothing queued, the calls recorded.
local function fresh()
    restore()
    -- the bridge's own end of a session undoes a Titan, a hold and a class
    deliver({ v = 2, op = "session", active = false, player = "42" })
    tick(0.1)
    inbox, published, diagnostics = {}, {}, {}
    for key in pairs(PS.keyOn) do PS.keyOn[key] = false end
    S.driving, S.pilot, S.gone, S.paused = false, false, false, false
    PS.ent, PS.asked, PS.id, PS.warm, PS.act, PS.mode, PS.jump, PS.core = nil, nil, nil, nil, nil, "none", nil, nil
    PS.weapon, PS.fire, PS.punchKey, PS.sprintOn, PS.dashKey, PS.jumpKey = "xo16", false, false, false, false, false
    S.moveX, S.moveY, S.kf, S.kb, S.kl, S.kr, S.yaw = 0, 0, 0, 0, 0, 0, 0.0
    S.keyHeld = {}
    calls = { spawn = {}, pilot = 0, embark = 0, dismount = {}, ground = 0 }
    replace(env, "spawnPilot", function(at)
        calls.spawn[#calls.spawn + 1] = at
        PS.id, PS.asked = "pilot-" .. #calls.spawn, clock
    end)
    replace(env, "startPilot", function(demo)
        calls.pilot = calls.pilot + 1
        S.driving, S.pilot, PS.mode = true, true, "pilot"
    end)
    replace(env, "startEmbark", function() calls.embark = calls.embark + 1 end)
    replace(FPF, "landingGround", function() calls.ground = calls.ground + 1; return ground end)
    ground = 2.5
    V.x, V.y, V.z, V.yaw = 10.5, -20.25, 3.0, 90.0
    deliver({ v = 2, op = "session", active = true, player = "42" })
    tick(0.1)
end

-- BT stands in the world, warmed up and idle: what findPilot and warmFrame leave once the entity has arrived.
local function bt_arrives()
    PS.ent, PS.asked, PS.warm, PS.act, PS.mode = {}, nil, nil, nil, "wait"
end

-- ---------------------------------------------------------------------------
-- The seam on its own: the hold's gates, the class's lock, the speed.
-- ---------------------------------------------------------------------------
test("without a mission everything is allowed, nothing is held and the speed is BT's own", function()
    fresh()
    assert(FPF.held() == false and FPF.mission.className == nil and FPF.mission.allowed == nil and FPF.mission.speed == 1.0)
    for _, name in ipairs({ "missiles", "vortex", "smoke", "dash", "jets", "sentry", "flight", "designator", "core" }) do
        assert(FPF.allowed(name) == true, name)
    end
    assert(FPF.speedMul() == 1.0)
    assert(FPF.heldAction("MoveY", KIND.AXIS_CHANGE, 1) == false and FPF.heldKey("punch", true) == false)
end)

test("a class names its label, the abilities it allows and a speed; nil clears it; a bad speed is no speed", function()
    fresh()
    FPF.classSet({ label = "Ronin", abilities = abilities("dash", "smoke", "core"), speed = 1.2 })
    assert(FPF.mission.className == "Ronin" and FPF.speedMul() == 1.2)
    for _, name in ipairs({ "dash", "smoke", "core" }) do assert(FPF.allowed(name) == true, name) end
    for _, name in ipairs({ "missiles", "vortex", "jets", "sentry", "flight", "designator" }) do assert(FPF.allowed(name) == false, name) end
    assert(FPF.allowed("nope") == false, "an unknown name is not allowed once a class is set")
    -- the table the controller keeps is its own
    local given = abilities("core")
    FPF.classSet({ label = "Core only", abilities = given, speed = 0.85 })
    given.dash = true
    assert(FPF.allowed("dash") == false and FPF.speedMul() == 0.85)
    for _, speed in ipairs({ 0.49, 1.51, 0, -1, math.huge, "1" }) do
        FPF.classSet({ label = "x", abilities = abilities(), speed = speed })
        assert(FPF.speedMul() == 1.0, tostring(speed))
    end
    FPF.classSet({ label = "x" })
    assert(FPF.allowed("core") == false, "no abilities table: nothing allowed")
    FPF.classSet(nil)
    assert(FPF.mission.className == nil and FPF.mission.allowed == nil and FPF.speedMul() == 1.0 and FPF.allowed("core") == true)
    FPF.classSet("Ronin")
    assert(FPF.mission.className == nil and FPF.speedMul() == 1.0, "anything but a table clears")
end)

test("a hold refuses every control but the camera look, and a release always goes through", function()
    fresh()
    S.driving, S.pilot, S.cam, PS.mode = true, true, {}, "pilot"
    -- before the hold the controller takes them
    assert(FPF.input("MoveY", "axis", 1) == true and S.moveY == 1)
    assert(FPF.input("Forward", "button", true) == true and S.kf == 1)
    assert(FPF.input("RangedAttack", "button", true) == true and PS.fire == true)
    assert(FPF.input("Sprint", "button", true) == true and PS.sprintOn == true)
    FPF.holdSet(true)
    assert(FPF.held() == true and FPF.mission.held == true)
    -- what was held at that moment is let go
    assert(S.moveY == 0 and S.kf == 0 and PS.fire == false and PS.sprintOn == false, "the hold lets go of what is held")
    -- the game's own actions, one by one
    for _, case in ipairs({
        { "MoveY", "axis", 1 }, { "MoveX", "axis", -1 }, { "Forward", "button", true }, { "Back", "button", true },
        { "Left", "button", true }, { "Right", "button", true }, { "Sprint", "button", true }, { "ToggleSprint", "button", true },
        { "Jump", "button", true }, { "Dodge", "button", true }, { "RangedAttack", "button", true }, { "Reload", "button", true },
        { "QuickMelee", "button", true }, { "RangedADS", "button", true }, { "CameraAim", "button", true },
        { "jump", "key", true }, { "dash", "key", true }, { "punch", "key", true }, { "missiles", "key", true },
        { "vortex", "key", true }, { "smoke", "key", true }, { "core", "key", true }, { "sentry", "key", true },
        { "designate", "key", true }, { "flight", "key", true },
    }) do
        assert(FPF.input(case[1], case[2], case[3]) == false, case[1] .. " went through the hold")
    end
    assert(S.moveY == 0 and S.moveX == 0 and S.kf == 0 and S.kb == 0 and S.kl == 0 and S.kr == 0)
    assert(PS.fire == false and PS.reloadKey == false and PS.zoom == false and PS.sprintOn == false and PS.punchKey == false)
    assert(PS.dashKey == false and PS.jumpKey == false and PS.keyOn.missiles == false and PS.keyOn.vortex == false)
    -- the mod's keys, as the redscript forwarder and the bridge's own presses reach the controller
    for _, key in ipairs({ "jump", "dash", "punch", "missiles", "vortex", "smoke", "core", "sentry", "designate", "flight", "eject",
        "follow", "home", "call", "embark", "phone" }) do
        assert(FPF.keyIn(key, true) == true)      -- keyIn answers that the key reached bind: bind is where the hold is
        assert(S.keyHeld[key] == nil, key .. " reached the controller's key state")
    end
    assert(PS.punchKey == false and PS.jumpKey == false and PS.dashKey == false and S.embarkDown == nil)
    for _, key in ipairs({ "missiles", "vortex", "smoke", "core", "sentry", "flight" }) do
        assert((PS.keyN[key] or 0) == 0, key .. " counted a press")
    end
    -- the camera look is not held, and neither are the view and shoulder keys
    local yaw = S.yaw
    assert(FPF.input("CameraMouseX", "relative", 450) == true and S.yaw ~= yaw, "the look turned the camera")
    assert(FPF.input("CameraX", "axis", 0.5) == true and S.padX == 0.5)
    assert(FPF.input("CameraY", "axis", -0.5) == true and S.padY == -0.5)
    local view = P.view
    assert(FPF.keyIn("view", true) == true and P.view ~= view, "the view key still works")
    local third = P.third
    assert(FPF.keyIn("shoulder", true) == true and P.third ~= third, "the shoulder key still works")
    -- releases and zero levels go through: they can only clear
    S.keyHeld.dash = clock
    FPF.keyIn("dash", false)
    assert(S.keyHeld.dash == nil, "a release reaches bind")
    S.moveX = 1
    assert(FPF.input("MoveX", "axis", 0) == true and S.moveX == 0)
    S.kf = 1
    assert(FPF.input("Forward", "button", false) == true and S.kf == 0)
    -- the hold is idempotent, and released it gives everything back
    FPF.holdSet(true)
    assert(FPF.held() == true)
    FPF.holdSet(false)
    FPF.holdSet(false)
    assert(FPF.held() == false)
    assert(FPF.input("MoveY", "axis", 1) == true and S.moveY == 1)
    assert(FPF.input("Forward", "button", true) == true and S.kf == 1)
end)

test("the hold refuses by the game's own input types: a press, a hold-complete and a moving axis, never a release or a zero", function()
    fresh()
    assert(FPF.heldAction("Jump", KIND.BUTTON_PRESSED, 0) == false, "no hold, no refusal")
    FPF.holdSet(true)
    assert(FPF.heldAction("Jump", KIND.BUTTON_PRESSED, 0) == true)
    assert(FPF.heldAction("Choice1_Hold", KIND.BUTTON_HOLD_COMPLETE, 0) == true, "the use key held is how V climbs out")
    assert(FPF.heldAction("Choice1", KIND.BUTTON_PRESSED, 0) == true)
    assert(FPF.heldAction("MoveY", KIND.AXIS_CHANGE, 0.1) == true)
    assert(FPF.heldAction("MoveY", KIND.AXIS_CHANGE, 0) == false and FPF.heldAction("Jump", KIND.BUTTON_RELEASED, 0) == false)
    assert(FPF.heldAction("CameraMouseX", KIND.RELATIVE_CHANGE, 100) == false and FPF.heldAction("CameraY", KIND.AXIS_CHANGE, 1) == false)
    assert(FPF.heldKey("punch", true) == true and FPF.heldKey("punch", false) == false and FPF.heldKey("view", true) == false)
    -- a scripted control the hold refuses is one the controller never ran, so the bridge never remembers it as held
    assert(FPF.heldInput("MoveX", "axis", 1) == true and FPF.heldInput("MoveX", "axis", 0) == false)
    assert(FPF.heldInput("Jump", "button", true) == true and FPF.heldInput("Jump", "button", false) == false)
    assert(FPF.heldInput("dash", "key", true) == true and FPF.heldInput("dash", "key", false) == false)
    assert(FPF.heldInput("CameraMouseX", "relative", 5) == false and FPF.heldInput("view", "key", true) == false)
end)

test("a hold also refuses the eject, and the climb out unless the controller forces it", function()
    S.camPos, S.camComp = { x = 0.0, y = 0.0, z = 0.0 }, nil
    fresh()
    S.driving, S.pilot, S.cam, PS.mode = true, true, {}, "pilot"
    PS.eject = nil
    local ejected = {}
    replace(FPF, "ejectStartSeam", function(why) ejected[#ejected + 1] = why end)
    FPF.ejectStart("a command")
    assert(#ejected == 1, "no hold, the eject goes through")
    FPF.holdSet(true)
    FPF.ejectStart("a command")
    assert(#ejected == 1, "the hold refused the eject")
    -- the climb out is the controller's startDismount: refused while held, never when the controller forces it
    PS.speed, PS.dashT, PS.jump, PS.auto = 0, nil, nil, nil
    attached.startDismount(false)
    assert(PS.mode == "pilot", "the climb out was refused")
    FPF.holdSet(false)
    local before = PS.scenes
    attached.startDismount(false)
    assert(PS.mode == "dismount", "released, the climb out starts: " .. tostring(PS.mode))
    assert(PS.scenes == before + 1)
end)

test("the class's lock on the nine abilities is where each one's key is handled", function()
    fresh()
    local seen = {}
    local function record(name) return function(...) seen[#seen + 1] = name .. ":" .. tostring((select("#", ...) > 0) and (select(select("#", ...), ...)) or "") return "base" end end
    -- the frames take `free`: the lock switches it off, whatever the frame asked
    local frames = {}
    for _, name in ipairs({ "mtmsFrame", "vortexFrame", "smokeFrame" }) do
        replace(FPF, name .. "Seam", function(dt, free) frames[name] = free end)
    end
    local function free() for _, name in ipairs({ "mtmsFrame", "vortexFrame", "smokeFrame" }) do FPF[name](0.05, true) end end
    free()
    assert(frames.mtmsFrame == true and frames.vortexFrame == true and frames.smokeFrame == true, "no class: free as asked")
    FPF.classSet({ label = "Legion", abilities = abilities("vortex", "smoke", "sentry", "core"), speed = 0.85 })
    free()
    assert(not frames.mtmsFrame and frames.vortexFrame == true and frames.smokeFrame == true, "missiles are locked")
    FPF.classSet({ label = "Ronin", abilities = abilities("dash", "core"), speed = 1.2 })
    free()
    assert(not frames.mtmsFrame and not frames.vortexFrame and not frames.smokeFrame, "all three are locked")
    FPF.classSet({ label = "Vanguard", abilities = abilities("missiles", "vortex", "smoke"), speed = 1.0 })
    free()
    assert(frames.mtmsFrame == true and frames.vortexFrame == true and frames.smokeFrame == true)
    FPF.holdSet(true)
    free()
    assert(not frames.mtmsFrame and not frames.vortexFrame and not frames.smokeFrame, "a hold takes them too")
    FPF.holdSet(false)

    -- the others refuse the start, each with its own word and the base never asked
    local asked = {}
    for _, name in ipairs({ "jumpCan", "poundStart", "sentryCan", "flightCan", "designate", "coreFire" }) do
        replace(FPF, name .. "Seam", function() asked[#asked + 1] = name; return true end)
    end
    FPF.classSet(nil)
    assert(FPF.jumpCan() == true and FPF.sentryCan() == true and FPF.flightCan() == true and FPF.coreFire("x") == true
        and FPF.poundStart() == true)
    FPF.designate()
    assert(#asked == 6, "no class: the controller's own functions answer")
    asked = {}
    FPF.classSet({ label = "none", abilities = abilities(), speed = 1.0 })
    local ok, why = FPF.jumpCan()
    assert(ok == false and why:find("jets", 1, true), tostring(why))
    ok, why = FPF.sentryCan()
    assert(ok == false and why:find("SENTRY", 1, true), tostring(why))
    ok, why = FPF.flightCan()
    assert(ok == false and why:find("FLIGHT", 1, true), tostring(why))
    assert(FPF.coreFire("the core key") == false and FPF.poundStart() == false)
    FPF.designate()
    assert(#asked == 0, "a locked ability never reached the controller's own function: " .. table.concat(asked, ","))
    -- each is its own lock
    for lock, call in pairs({
        jets = function() return FPF.jumpCan(), FPF.poundStart() end, sentry = function() return FPF.sentryCan() end,
        flight = function() return FPF.flightCan() end, core = function() return FPF.coreFire("x") end,
        designator = function() FPF.designate() return true end,
    }) do
        FPF.classSet({ label = "only " .. lock, abilities = abilities(lock), speed = 1.0 })
        asked = {}
        call()
        assert(#asked >= 1, lock .. " was refused though its class allows it")
        for _, other in ipairs({ "jets", "sentry", "flight", "core", "designator" }) do
            if other ~= lock then
                local map = abilities(lock)
                assert(map[other] == false)
            end
        end
    end
end)

test("Burst Core still on the mod's 5 moves to Y every two seconds at most; a key the player chose stays", function()
    fresh()
    replace(environment, "Enum", { new = function(_, member) return member end })
    local sys = { coreKey = "IK_5", flightKey = "IK_Y" }
    replace(FPF, "keysSystemSeam", function() return sys end)
    FPF.mission.keysAt = nil
    assert(FPF.keysSystem() == sys and sys.coreKey == "IK_Y", "the mod's default moves to Y")
    sys.coreKey = "IK_5" -- a Mod Settings save writes the stored default back
    assert(FPF.keysSystem() == sys and sys.coreKey == "IK_5", "not looked at again within two seconds")
    S.clock = S.clock + FPC.lightKeys.every + 0.01
    FPF.keysSystem()
    assert(sys.coreKey == "IK_Y", "moved again")
    sys.coreKey = "IK_K"
    S.clock = S.clock + FPC.lightKeys.every + 0.01
    FPF.keysSystem()
    assert(sys.coreKey == "IK_K", "a key the player chose is left alone")
    replace(FPF, "keysSystemSeam", function() return nil end)
    S.clock = S.clock + FPC.lightKeys.every + 0.01
    assert(FPF.keysSystem() == nil, "no key system yet: nothing to move")
    FPF.mission.keysAt = nil
end)

test("on a shared key, a class with FLIGHT STRIKE takes the press as the flight strike and any other as the core", function()
    fresh()
    local sys = { coreKey = "IK_Y", flightKey = "IK_Y" }
    replace(FPF, "keysSystem", function() return sys end)
    local perks = { flight = 1 }
    replace(FPF, "perk", function(name) return perks[name] or 0 end)
    local got
    replace(FPF, "forwardedSeam", function(B) got = B end)
    local function press(...)
        local names, down = { ... }, {}
        for i = 1, #names do down[i] = true end
        got = nil
        FPF.forwarded({ ends = { 1 }, actionNames = { "Jump" }, actionKinds = { 1 }, actionValues = { 1 }, keyNames = names,
            keyDown = down, hits = { "h" } })
        return table.concat(got.keyNames, ","), got
    end
    -- Northstar: the jets, the flight strike, the designator and the core
    FPF.classSet({ label = "Northstar", abilities = abilities("jets", "flight", "designator", "core"), speed = 1.0 })
    local keys, B = press("core", "flight", "punch")
    assert(keys == "flight,punch", "Northstar's Y is the flight strike: " .. keys)
    assert(#B.keyDown == 2 and B.ends[1] == 1 and B.actionNames[1] == "Jump" and B.hits[1] == "h", "the rest of the batch goes as it came")
    perks.flight = 0
    assert(press("core", "flight") == "core", "no FLIGHT STRIKE perk: the core")
    perks.flight = 1
    FPF.classSet({ label = "Vanguard", abilities = abilities("missiles", "vortex", "jets", "core"), speed = 1.0 })
    assert(press("core", "flight") == "core", "a class without the flight strike: the core")
    FPF.classSet(nil)
    assert(press("core", "flight") == "flight", "no class (everything allowed): the flight strike, as the perk is on")
    -- keys of their own: both go through, and a batch without either is handed over untouched
    sys.flightKey = "IK_T"
    assert(press("core", "flight") == "core,flight", "separate keys: both")
    sys.flightKey = "IK_Y"
    local plain = { ends = {}, actionNames = {}, actionKinds = {}, actionValues = {}, keyNames = { "punch" }, keyDown = { true }, hits = {} }
    FPF.forwarded(plain)
    assert(got == plain, "no core or flight key: the batch itself")
end)

test("a class's damage multiple scales what BT takes; no class, or one out of bounds, takes it as the controller would", function()
    fresh()
    local seen
    replace(FPF, "healthSeam", function() seen = PS.hp and { a = PS.hp.pend.a, b = PS.hp.pend.b } or "none" end)
    local function take(a, b)
        PS.hp = { pend = { a = a, b = b } }
        seen = nil
        FPF.health(0.05)
        PS.hp = nil
        return seen
    end
    assert(FPF.mission.harm == 1.0)
    local got = take(10, 4)
    assert(got.a == 10 and got.b == 4, "no class: as gathered")
    FPF.classSet({ label = "Vanguard", abilities = abilities("missiles"), speed = 1.0, harm = 5 })
    assert(FPF.mission.harm == 5)
    got = take(10, 4)
    assert(got.a == 50 and got.b == 20, "five times what the frame gathered")
    for _, bad in ipairs({ 0.05, 60, "5", 0 / 0 }) do
        FPF.classSet({ label = "Vanguard", abilities = abilities("missiles"), speed = 1.0, harm = bad })
        assert(FPF.mission.harm == 1.0, "out of bounds: " .. tostring(bad))
    end
    FPF.classSet({ label = "Vanguard", abilities = abilities("missiles"), speed = 1.0, harm = 8 })
    FPF.classSet(nil)
    assert(FPF.mission.harm == 1.0, "clearing the class clears it")
    -- the shield's regeneration multiple: the wait after a hit and the refill are stretched for the call, and put back after it
    local K = FPC.health
    local delay, time = K.shieldDelay, K.shieldTime
    local during
    replace(FPF, "healthSeam", function() during = { K.shieldDelay, K.shieldTime } end)
    FPF.classSet({ label = "Vanguard", abilities = abilities("missiles"), speed = 1.0, regen = 2.5 })
    assert(FPF.mission.regen == 2.5)
    FPF.health(0.05)
    assert(during[1] == delay * 2.5 and during[2] == time * 2.5, "the shield waits and refills 2.5 times slower")
    assert(K.shieldDelay == delay and K.shieldTime == time, "the controller's own values are back")
    replace(FPF, "healthSeam", function() error("the health frame failed", 0) end)
    local ok = pcall(FPF.health, 0.05)
    assert(not ok and K.shieldDelay == delay and K.shieldTime == time, "back even when the frame raised")
    for _, bad in ipairs({ 0.2, 11, "2" }) do
        FPF.classSet({ label = "Vanguard", abilities = abilities("missiles"), speed = 1.0, regen = bad })
        assert(FPF.mission.regen == 1.0, "out of bounds: " .. tostring(bad))
    end
    FPF.classSet(nil)
    assert(FPF.mission.regen == 1.0)
    replace(FPF, "healthSeam", function() seen = PS.hp and { a = PS.hp.pend.a, b = PS.hp.pend.b } or "none" end)
    PS.hp = nil
    FPF.health(0.05) -- no BT health: nothing to scale, the controller's own function answers
    assert(seen == "none")
end)

test("a class with the fists turns the vortex shield into the ARC FIELD: pulses that shock everyone around BT, rings that run out", function()
    fresh()
    local hits, staggers, effects, asked = {}, {}, {}, nil
    local around = {
        { ent = "near", kind = "person", d = 4.0, x = 4.0, y = 0.0, z = 0.0, key = "a" },
        { ent = "car", kind = "vehicle", d = 5.0, x = 0.0, y = 5.0, z = 0.0, key = "b" },
    }
    replace(FPF, "fistRound", function(x, y, z, reach, high) asked = { reach = reach, high = high }; return around end)
    replace(FPF, "hit", function(ent, rec, x, y, z, fx, fy) hits[#hits + 1] = { ent = ent, rec = rec, fx = fx, fy = fy } end)
    replace(FPF, "fistStagger", function(ent, kind) staggers[#staggers + 1] = { ent = ent, kind = kind } end)
    replace(FPF, "fxAt", function(path, x, y, z) effects[#effects + 1] = { path = path, x = x, y = y, z = z }; return {} end)
    replace(FPF, "gunRecord", function(name) return name end)
    replace(P, "fxOn", true)
    PS.ent, PS.x, PS.y, PS.z, PS.fxLive, PS.arc = {}, 0.0, 0.0, 0.0, {}, nil
    PS.vortex = { on = true }
    local K = FPC.arcField
    PS.weapon = "fist"
    FPF.arcFrame()
    assert(PS.arc == nil and #hits == 0 and #effects == 0, "no class: the vortex shield is the controller's own")
    FPF.classSet({ label = "Vanguard", abilities = abilities("vortex"), speed = 1.0 })
    PS.weapon = "xo16"
    FPF.arcFrame()
    assert(PS.arc == nil and #hits == 0, "a class with another weapon: no field")
    FPF.classSet({ label = "Brawler", abilities = abilities("vortex"), speed = 1.0 })
    PS.weapon = "fist"
    FPF.arcFrame()
    assert(PS.arc and PS.arc.pulses == 1, "the first pulse comes with the shield")
    assert(asked.reach == K.reach and asked.high == K.high)
    assert(#hits == 1 and hits[1].ent == "near" and hits[1].rec == K.record and hits[1].fx == 1.0 and hits[1].fy == 0.0,
        "a person within reach is hit, pushed outward; a vehicle is not")
    assert(#staggers == 1 and staggers[1].ent == "near" and staggers[1].kind == "electric")
    assert(#effects == 1 + K.each and effects[1].path == K.fx.burst and effects[2].path == K.fx.ring, "the burst, and the first ring at once")
    for _ = 2, #K.rings do
        S.clock = S.clock + K.step + 1e-6
        FPF.arcFrame()
    end
    assert(#effects == 1 + K.each * #K.rings, "the other rings, one step apart")
    local last = effects[#effects]
    assert(math.abs(math.sqrt(last.x ^ 2 + last.y ^ 2) - K.rings[#K.rings]) < 1e-6, "the last ring at its radius")
    assert(#hits == 1, "one hit per pulse")
    S.clock = S.clock + K.pulse
    FPF.arcFrame()
    assert(PS.arc.pulses == 2 and #hits == 2, "the next pulse")
    PS.vortex.on = false
    FPF.arcFrame()
    assert(PS.arc == nil, "the shield let go: the field is down")
    -- the catch: from every side with the field, the shield's own front arc without it
    local arcs = {}
    replace(FPF, "vortexCatchArc", function() arcs[#arcs + 1] = FPC.vortex.arc; return true end)
    local front = FPC.vortex.arc
    FPF.classSet({ label = "Brawler", abilities = abilities("vortex"), speed = 1.0 })
    assert(FPF.vortexCatch({}, {}, "a") == true)
    FPF.classSet(nil)
    FPF.vortexCatch({}, {}, "a")
    assert(arcs[1] == 180.0 and arcs[2] == front and FPC.vortex.arc == front)
    replace(FPF, "vortexCatchArc", function() error("the catch failed", 0) end)
    FPF.classSet({ label = "Brawler", abilities = abilities("vortex"), speed = 1.0 })
    assert(not pcall(FPF.vortexCatch, {}, {}, "a") and FPC.vortex.arc == front, "the front arc is back even when the catch raised")
    FPF.classSet(nil)
    PS.vortex = nil
end)

test("a class with the designator calls a BARRAGE down with its key while V pilots: rockets from the sky, then a cooldown", function()
    fresh()
    bt_arrives()
    S.driving, S.pilot, PS.mode = true, true, "pilot"
    local K = FPC.barrage
    local foe = { GetWorldPosition = function() return { x = 40.0, y = 30.0, z = 2.0 } end }
    local marked = 0
    replace(FPF, "perk", function() return 1 end)
    replace(FPF, "designatePick", function() return foe end)
    replace(FPF, "designate118", function() marked = marked + 1 end)
    replace(OP77, "targetActive", function() return true end)
    replace(FPF, "fxAt", function() return {} end)
    replace(FPF, "tf", function() end)
    replace(P, "fxOn", true)
    PS.missiles, PS.fxLive, PS.barrage, PS.barrageReadyAt = {}, {}, nil, nil
    local function press()
        FPF.bind("designate", true)
        FPF.bind("designate", false)
        FPF.barrageFrame()
    end
    press()
    assert(PS.barrage == nil and marked == 0, "no class: the key is the authored designator's, which does nothing while V drives")
    FPF.classSet({ label = "Northstar", abilities = abilities("designator", "flight", "jets", "core") })
    press()
    assert(PS.barrage and marked == 1 and #PS.missiles == 0, "the foe is marked and the barrage called; nothing before the delay")
    S.clock = S.clock + K.delay + 1e-6
    FPF.barrageFrame()
    local m = PS.missiles[1]
    assert(#PS.missiles == 1 and m.barrage and m.flight and m.ent == foe, "the first rocket goes for the marked foe, as a flight rocket")
    assert(m.z >= 2.0 + K.height - 1e-6 and m.dz < 0, "it comes down from the sky")
    for _ = 2, K.rockets do
        S.clock = S.clock + K.every + 1e-6
        FPF.barrageFrame()
    end
    assert(#PS.missiles == K.rockets and PS.barrage == nil, "every rocket, then it is over")
    for i = 2, #PS.missiles do
        local r = PS.missiles[i]
        assert(r.ent == nil and r.loose and math.sqrt((r.tx - 40.0) ^ 2 + (r.ty - 30.0) ^ 2) <= K.spread + 1e-6, "the others round where it stands")
    end
    press()
    assert(PS.barrage == nil and marked == 1, "refused while it cools down")
    S.clock = PS.barrageReadyAt + 0.01
    press()
    assert(PS.barrage and marked == 2, "ready again after the cooldown")
    FPF.classSet(nil)
    PS.missiles, PS.barrage, PS.barrageReadyAt = {}, nil, nil
end)

test("a class's ultimates: one charge at a time, BURST and SWORD CORE three times as fast, BERSERKER's blows launch all but a boss", function()
    fresh()
    local K = FPC.missionCore
    local authoredRate, authoredSword = FPC.perk.core.rate, FPC.sword.core.rate
    replace(FPF, "perk", function() return 3 end)
    assert(FPF.coreMax() > FPF.coreShot(), "the authored core holds more than one charge")
    FPF.classSet({ label = "Vanguard", abilities = abilities("core"), speed = 1.0 })
    assert(FPC.perk.core.rate == K.rate and FPC.sword.core.rate == K.swordRate, "three times as fast")
    assert(FPF.coreMax() == FPF.coreShot(), "one charge at a time")
    FPF.classSet(nil)
    assert(FPC.perk.core.rate == authoredRate and FPC.sword.core.rate == authoredSword and FPF.coreMax() > FPF.coreShot(),
        "without a class the authored values are back")
    -- BERSERKER CORE: a blow that lands launches the one it met, outwards and up; a boss, a shock blast, a toss and no core do not
    local pushes, staggers = {}, {}
    replace(FPF, "ragdollPush149", function(ent, x, y, z, ux, uy, uz, power)
        pushes[#pushes + 1] = { ent = ent, ux = ux, uy = uy, uz = uz, power = power }
        return true
    end)
    replace(FPF, "fistStaggerBerserk", function(who, kind) staggers[#staggers + 1] = kind; return 1 end)
    local boss = {}
    replace(FPF, "coreWorth", function(who) if who == boss then return 25, "a boss" end return 5, "a foe" end)
    local function body(x, y) return { IsVehicle = function() return false end, GetWorldPosition = function() return { x = x, y = y, z = 0.0 } end } end
    PS.x, PS.y, PS.z, PS.weapon = 0.0, 0.0, 0.0, "fist"
    local foe = body(10.0, 0.0)
    FPF.classSet({ label = "Brawler", abilities = abilities("core"), speed = 1.0 })
    PS.core = { charge = 0.0, left = 5.0 }
    assert(FPF.fistStagger(foe, "heavy") == 1 and #pushes == 1 and #staggers == 0, "launched instead of staggered")
    local P1 = pushes[1]
    assert(P1.ent == foe and P1.ux > 0 and math.abs(P1.uy) < 1e-9 and math.abs(P1.uz - K.launch.up) < 1e-9 and P1.power == K.launch.power,
        "away from BT and up")
    FPF.fistStagger(boss, "heavy")
    FPF.fistStagger(foe, "blast")
    FPF.fistStagger(foe, "toss")
    assert(#pushes == 1 and staggers[1] == "heavy" and staggers[2] == "blast" and staggers[3] == "toss", "a boss, a blast, a toss: their own stagger")
    replace(FPF, "ragdollPush149", function() return false end)
    assert(FPF.fistStagger(foe, "uppercut") == 1 and staggers[4] == "uppercut", "a ragdoll that could not be asked: staggered instead")
    replace(FPF, "ragdollPush149", function(ent, x, y, z, ux, uy, uz, power)
        pushes[#pushes + 1] = { ent = ent, ux = ux, uy = uy, uz = uz, power = power }
        return true
    end)
    table.remove(staggers)
    PS.core.left = nil
    FPF.fistStagger(foe, "jab")
    assert(#pushes == 1 and staggers[4] == "jab", "no core burning: the authored stagger")
    FPF.classSet(nil)
    PS.core.left = 5.0
    FPF.fistStagger(foe, "jab")
    assert(#pushes == 1 and staggers[5] == "jab", "no class: the authored stagger")
    -- the core's charge: the controller's own reading of a killing blow counts without a class, never in one (the server credits it)
    local bt = { GetEntityID = function() return "bt" end }
    local n = 0
    local function kill()
        n = n + 1
        local id = "npc" .. n
        return { attackData = { HasFlag = function() return true end, GetSource = function() return bt end },
            target = { GetEntityID = function() return id end } }
    end
    PS.ent, PS.core = bt, { charge = 0.0 }
    FPF.coreKill(kill(), "b")
    local alone = PS.core.charge
    assert(alone > 0, "a killing blow without a class charges the core")
    FPF.classSet({ label = "Vanguard", abilities = abilities("core"), speed = 1.0 })
    FPF.coreKill(kill(), "b")
    assert(PS.core.charge == alone, "in a class only the server's kill credit charges it")
    FPF.classSet(nil)
    PS.core, PS.ent = nil, nil
end)

test("a ragdoll's impulse waits in the controller's own queue and is sent 0.12 s later, never through the delay system", function()
    fresh()
    -- DelaySystem.DelayEvent with a delay, called from Lua through Open77.rtti, crashed the game (no calling script function)
    local delayed = 0
    replace(GAME, "GetDelaySystem", function() delayed = delayed + 1; return stub end)
    FPF.laterQueue = {}
    local sent = {}
    local body = { QueueEvent = function(_, evt) sent[#sent + 1] = evt end }
    FPF.ragdoll(body, 1.0, 2.0, 3.0, 1.0, 0.0, 5.0)
    local asked = #sent -- the ragdoll request itself goes at once
    assert(delayed == 0, "the delay system is never asked")
    assert(FPF.laterPending(), "the impulse waits")
    S.clock = S.clock + 0.1
    FPF.laterFlush()
    assert(#sent == asked and FPF.laterPending(), "not before 0.12 s")
    S.clock = S.clock + 0.03
    FPF.laterFlush()
    assert(#sent == asked + 1 and not FPF.laterPending(), "sent once its delay has passed")
    -- the throw's push queues its own impulse beside the ragdoll's: both go
    sent = {}
    FPF.ragdollPush149(body, 1.0, 2.0, 3.0, 0.0, 1.0, 0.5, 10.0)
    asked = #sent
    S.clock = S.clock + 0.2
    FPF.laterFlush()
    assert(#sent == asked + 2 and delayed == 0, "the ragdoll's and the push's impulses")
    -- a body that is gone, an event that came due long ago (frames cut) and a session that ended send nothing
    sent = {}
    FPF.later(nil, "gone", 0.12)
    FPF.later(body, "late", 0.12)
    S.clock = S.clock + 0.12 + FPC.later.keep + 0.5
    FPF.laterFlush()
    assert(#sent == 0 and not FPF.laterPending(), "dropped")
    FPF.later(body, "ended", 0.12)
    S.gone = true
    FPF.laterFlush()
    S.gone = false
    S.clock = S.clock + 1.0
    FPF.laterFlush()
    assert(#sent == 0 and not FPF.laterPending(), "the session's end empties the queue")
end)

test("an event queued for later keeps the bridge's frames coming; with none, an idle bridge throttles them", function()
    fresh()
    local updates = 0
    replace(FPF, "update", function() updates = updates + 1 end)
    replace(FPF, "idleOk", function() return true end)
    FPF.laterQueue = {}
    OP77.frame(0.016) -- a full frame: the bridge learns the controller is idle
    updates = 0
    for _ = 1, 5 do OP77.frame(0.016) end
    assert(updates < 5, "idle and quiet: throttled (" .. updates .. " of 5)")
    FPF.later({ QueueEvent = function() end }, "evt", 0.12)
    updates = 0
    for _ = 1, 5 do OP77.frame(0.016) end
    assert(updates == 5, "an event waiting: every frame runs the update (" .. updates .. " of 5)")
    FPF.laterQueue = {}
end)

test("the dash and the jets of a class that has none never reach the pilot frame's own reading", function()
    fresh()
    -- the pilot frame reads these two fields; the gate is FPF.allowed in front of them (init.lua: pilotFrame)
    local source = io.open(root .. "controller/init.lua", "rb"):read("a")
    assert(source:find('if dash and not FPF.allowed("dash") then dash = false end', 1, true), "the dash gate is gone from pilotFrame")
    assert(source:find('if jump and not FPF.allowed("jets") then jump = false end', 1, true), "the jets gate is gone from pilotFrame")
    assert(source:find("local held = FPF.held()", 1, true) and source:find("or PS.outAsked ~= nil or held)", 1, true),
        "the hold is no longer told to the tactics")
    assert(source:find("and not PS.sentry and not held", 1, true) and source:find("not PS.auto and not E and not held then guard(\"GROUND POUND\"", 1, true),
        "the melee and the ground pound lost their hold")
    assert(source:find("if FPF.held() and not force then return end", 1, true), "the climb out lost its hold")
end)

test("the walk and run speed is the class's multiple of BT's; the dash and the standing still are not", function()
    fresh()
    local probe = { wall = function() return false end, ground = function(_, _, z) return z end }
    local function run(mul, seconds, sprint)
        FPF.classSet(mul and { label = "x", abilities = abilities(), speed = mul } or nil)
        PS.x, PS.y, PS.z, PS.yaw, PS.vx, PS.vy, PS.speed, PS.top = 0, 0, 0, 0, 0, 0, 0, controller.gait.tf.run
        PS.jump, PS.dashT, PS.lunge, PS.turn, PS.stand, PS.skate = nil, nil, nil, nil, nil, nil
        for _ = 1, math.floor(seconds / 0.05) do controller.gait.step(1, 0, 0, 0, sprint == true, false, 0.05, probe) end
        return PS.speed
    end
    local normal = run(nil, 4)
    assert(math.abs(normal - controller.gait.tf.run) < 0.05, "BT's own run is TF.run: " .. normal)
    for _, mul in ipairs({ 0.5, 0.85, 1.0, 1.2, 1.5 }) do
        local speed = run(mul, 4)
        assert(math.abs(speed - normal * mul) < 0.05, ("x%.2f gave %.3f m/s, wanted %.3f"):format(mul, speed, normal * mul))
    end
    -- sprinting is run speed too
    local sprinting = run(nil, 6, true)
    assert(sprinting > normal + 1.0, "BT sprints faster than it runs: " .. sprinting)
    local fast = run(1.2, 6, true)
    assert(math.abs(fast - sprinting * 1.2) < 0.1, ("a sprint at x1.2 gave %.3f, wanted %.3f"):format(fast, sprinting * 1.2))
    -- a stick pushed half way is half of the class's speed: the multiple is on the wish, not on a rounding of it
    FPF.classSet({ label = "x", abilities = abilities(), speed = 1.5 })
    PS.x, PS.y, PS.vx, PS.vy, PS.speed, PS.top = 0, 0, 0, 0, 0, controller.gait.tf.run
    for _ = 1, 80 do controller.gait.step(0.5, 0, 0, 0, false, false, 0.05, probe) end
    assert(math.abs(PS.speed - normal * 0.5 * 1.5) < 0.05, "half stick at x1.5: " .. PS.speed)
    -- standing still stays still
    FPF.classSet({ label = "x", abilities = abilities(), speed = 1.5 })
    PS.vx, PS.vy, PS.speed = 0, 0, 0
    for _ = 1, 40 do controller.gait.step(0, 0, 0, 0, false, false, 0.05, probe) end
    assert(PS.speed == 0)
    FPF.classSet(nil)
end)

test("a dash goes as far with a speed multiple as without one", function()
    fresh()
    local probe = { wall = function() return false end, ground = function(_, _, z) return z end }
    local function dashed(mul)
        FPF.classSet(mul and { label = "x", abilities = abilities("dash"), speed = mul } or nil)
        PS.x, PS.y, PS.z, PS.yaw, PS.vx, PS.vy, PS.speed, PS.top, PS.power, PS.sinceDash = 0, 0, 0, 0, 0, 0, 0, controller.gait.tf.run, 100.0, 10.0
        PS.jump, PS.dashT, PS.lunge, PS.turn, PS.stand, PS.skate = nil, nil, nil, nil, nil, nil
        controller.gait.step(1, 0, 0, 0, false, true, 0.05, probe)
        assert(PS.dashT ~= nil, "the dash began")
        -- to the last step that is still the dash: the step that ends it hands over to the class's run
        local steps, x, y = 1, PS.x, PS.y
        while PS.dashT ~= nil and PS.dashT < controller.gait.tf.dodgeTime and steps < 200 do
            x, y = PS.x, PS.y
            controller.gait.step(1, 0, 0, 0, false, false, 0.05, probe)
            steps = steps + 1
        end
        assert(steps < 200, "the dash ended")
        return math.sqrt(x ^ 2 + y ^ 2)
    end
    local plain = dashed(nil)
    assert(plain > 3.0, "the dash covers ground: " .. plain)
    for _, mul in ipairs({ 0.5, 0.85, 1.2, 1.5 }) do
        local far = dashed(mul)
        assert(math.abs(far - plain) < 1e-6, ("a dash went %.4f m at x%.2f and %.4f m without"):format(far, mul, plain))
    end
    FPF.classSet(nil)
end)

-- ---------------------------------------------------------------------------
-- The bridge on the real controller: the piloted spawn, the hold, the class and the kill credit as the server's messages
-- reach them. The controller's heavy entry points (spawnPilot, startPilot, startEmbark) are replaced by recorders; everything
-- else is the code that runs in the game.
-- ---------------------------------------------------------------------------
local function sessionAndGrant(extra, id)
    deliver(grantMessage(id, extra))
    tick(0.1)
end
local function spawnCommand()
    deliver({ v = 2, op = "command", action = "spawn" })
    tick(0.1)
end
local function titanRequests(action)
    local list = {}
    for _, message in ipairs(publishedOps("request")) do if message.action == action then list[#list + 1] = message end end
    return list
end

test("the controller's perks are the server's loadout in these tests", function()
    fresh()
    assert(P.perks == true, "the controller reads its levels from the loadout")
    sessionAndGrant()
    assert(FPF.perk("burstcore") == 3 and FPF.perk("railgun") == 1 and FPF.perk("fist") == 1)
end)

test("a piloted grant puts BT on the ground at V's place and heading, with no call-down, and seats V once BT is ready", function()
    fresh()
    local called = 0
    replace(FPF, "callBt", function() called = called + 1; return true end)
    sessionAndGrant({ piloted = true, hold = true })
    assert(FPF.held() == true, "held from the grant, before BT stands anywhere")
    assert(#calls.spawn == 0, "nothing is placed before the server commands the spawn")
    spawnCommand()
    assert(#calls.spawn == 1 and calls.ground == 1, "one placement, one ground probe")
    local at = calls.spawn[1]
    assert(at.x == V.x and at.y == V.y and at.z == 2.5 and at.yaw == V.yaw, ("%s %s %s %s"):format(at.x, at.y, at.z, at.yaw))
    assert(called == 0, "the controller's call-down was never asked for: no sky check, no cooldown, no drop")
    assert(PS.act == nil, "no drop scene")
    assert(calls.pilot == 0 and calls.embark == 0, "BT has not arrived yet")
    -- BT arrives but is still warming up: V waits
    PS.ent, PS.asked, PS.warm, PS.mode = {}, nil, { i = 1 }, "wait"
    PS.x, PS.y = V.x, V.y
    tick(0.2)
    assert(calls.pilot == 0 and calls.embark == 0, "not before BT is warmed up")
    PS.warm = nil
    tick(0.1)
    assert(calls.pilot == 1 and calls.embark == 0, ("seated at once, never by the boarding scene, though V stands at BT's feet (%d, %d, %s)"):format(calls.pilot, calls.embark, table.concat(diagnostics, " | ")))
    assert(S.driving == true and PS.mode == "pilot")
    tick(1.0)
    assert(calls.pilot == 1, "the seat is asked for once")
    assert(FPF.held() == true, "still held in the seat")
    -- the spawn command is the server's only: the hold lasts until it releases
    deliver({ v = 2, op = "hold", id = "7001", epoch = 1, held = false })
    tick(0.1)
    assert(FPF.held() == false)
end)

test("a plain grant is called down by the controller and boarded by its scene: the piloted spawn is the option's alone", function()
    fresh()
    local called = 0
    replace(FPF, "callBt", function() called = called + 1; return true end)
    sessionAndGrant()
    assert(FPF.held() == false)
    spawnCommand()
    assert(called == 1 and #calls.spawn == 0 and calls.ground == 0, "the controller's own call function ran")
    bt_arrives()
    PS.x, PS.y = V.x, V.y
    deliver({ v = 2, op = "command", action = "pilot" })
    tick(0.1)
    assert(calls.embark >= 1 and calls.pilot == 0, "V stands at BT's feet: the boarding scene, retried until V is aboard")
    -- a hold alone does not make a spawn piloted, and piloted alone does not hold
    fresh()
    sessionAndGrant({ hold = true })
    assert(FPF.held() == true)
    replace(FPF, "callBt", function() called = called + 1; return true end)
    spawnCommand()
    assert(#calls.spawn == 0, "held, not piloted: called down")
    fresh()
    sessionAndGrant({ piloted = true })
    assert(FPF.held() == false, "piloted, not held")
end)

test("a refused placement gives the grant back as a refused call does, and leaves no hold or class behind", function()
    local function refused(label, arrange, asked)
        fresh()
        local called = 0
        replace(FPF, "callBt", function() called = called + 1; return true end)
        arrange()
        sessionAndGrant({ piloted = true, hold = true })
        assert(FPF.held() == true, label)
        spawnCommand()
        assert(#titanRequests("remove") == 1, label .. ": the grant was not given back")
        assert(#calls.spawn == (asked or 0) and called == 0 and calls.pilot == 0, label)
        assert(FPF.held() == false and FPF.mission.className == nil, label .. ": the hold outlived the Titan")
        -- the Titan is forgotten: the server's later words for it are not this controller's
        deliver({ v = 2, op = "hold", id = "7001", epoch = 1, held = true })
        tick(0.1)
        assert(FPF.held() == false, label .. ": a word for a Titan this controller has forgotten was taken")
    end
    refused("no ground under V", function() ground = nil end)
    refused("V is driving already", function() S.driving = true end)
    local gamePlayer = GAME.GetPlayer
    GAME.GetPlayer = function() return nil end
    refused("no player", function() end)
    GAME.GetPlayer = gamePlayer
    refused("the game did not take the spawn", function()
        replace(env, "spawnPilot", function(at) calls.spawn[#calls.spawn + 1] = at; PS.id, PS.asked = nil, nil end)
    end, 1)
end)

test("a hold is the server's word for its own Titan: released and set again, and no other Titan's or epoch's", function()
    fresh()
    sessionAndGrant()
    local function word(held, extra)
        local message = { v = 2, op = "hold", id = "7001", epoch = 1, held = held }
        for key, value in pairs(extra or {}) do message[key] = value end
        deliver(message)
        tick(0.1)
    end
    word(true)
    assert(FPF.held() == true)
    word(true)
    assert(FPF.held() == true, "idempotent")
    word(false, { id = "9" })
    word(false, { epoch = 2 })
    assert(FPF.held() == true, "another Titan's or epoch's word is not this one's")
    word(false)
    assert(FPF.held() == false)
    word(false)
    assert(FPF.held() == false)
    -- a malformed one is refused by the schema and changes nothing
    word(true)
    deliver({ v = 2, op = "hold", id = "7001", epoch = 1, held = "no" })
    deliver({ v = 2, op = "hold", id = "7001", epoch = 1, held = false, extra = 1 })
    tick(0.1)
    assert(FPF.held() == true, "a malformed word changed the hold")
    -- the end of the Titan, of the session and a new grant: none carries a hold over
    deliver({ v = 2, op = "remove", id = "7001", epoch = 1, reason = "owner_removed" })
    tick(0.1)
    assert(FPF.held() == false)
    sessionAndGrant({ hold = true }, "7002")
    assert(FPF.held() == true)
    sessionAndGrant({}, "7003")
    assert(FPF.held() == false, "a new grant without the option is not held")
    word(true, { id = "7003" })
    assert(FPF.held() == true)
    deliver({ v = 2, op = "session", active = false, player = "42" })
    tick(0.1)
    assert(FPF.held() == false, "the session ended")
end)

test("a class sets the loadout, the lock, the speed and the weapon in one step, for its own Titan and only when newer", function()
    fresh()
    sessionAndGrant()
    local rail = loadoutFor("rail", { jumpgauge = 1, railcap = 2 })
    deliver(classMessage(2, { id = "northstar", label = "Northstar", weapon = "rail", speed = 1.0,
        abilities = abilities("jets", "flight", "designator", "core") }, rail))
    tick(0.1)
    assert(FPF.mission.className == "Northstar" and FPF.speedMul() == 1.0)
    assert(FPF.allowed("jets") and FPF.allowed("flight") and FPF.allowed("designator") and FPF.allowed("core"))
    assert(not FPF.allowed("missiles") and not FPF.allowed("vortex") and not FPF.allowed("smoke") and not FPF.allowed("dash")
        and not FPF.allowed("sentry"))
    assert(FPF.perk("railgun") == 1 and FPF.perk("xo16") == 0 and FPF.perk("predator") == 0 and FPF.perk("sword") == 0
        and FPF.perk("fist") == 0, "the loadout of the class")
    assert(PS.weapon == "rail", "the class's weapon is in hand: " .. tostring(PS.weapon))
    assert(FPF.factGet(FPC.perk.gunFact) == 1, "the gun fact the controller's own gun pick reads")
    -- an older or equal revision, another Titan and another epoch are not this controller's
    deliver(classMessage(2, { id = "ronin", label = "Ronin", weapon = "sword", speed = 1.2, abilities = abilities("dash") }, loadoutFor("sword")))
    deliver(classMessage(1, { id = "ronin", label = "Ronin", weapon = "sword", speed = 1.2, abilities = abilities("dash") }, loadoutFor("sword")))
    deliver(classMessage(9, { id = "ronin", label = "Ronin", weapon = "sword", speed = 1.2, abilities = abilities("dash") }, loadoutFor("sword"), "9"))
    local other = classMessage(9, { id = "ronin", label = "Ronin", weapon = "sword", speed = 1.2, abilities = abilities("dash") }, loadoutFor("sword"))
    other.epoch = 2
    deliver(other)
    tick(0.2)
    assert(FPF.mission.className == "Northstar" and PS.weapon == "rail", "nothing of those was taken")
    -- a malformed one is refused whole: no lock, no speed, no weapon
    local broken = classMessage(5, { id = "ronin", label = "Ronin", weapon = "sword", speed = 2.0, abilities = abilities("dash") }, loadoutFor("sword"))
    deliver(broken)
    tick(0.1)
    assert(FPF.mission.className == "Northstar" and FPF.speedMul() == 1.0 and PS.weapon == "rail")
    -- the next valid one is
    deliver(classMessage(5, { id = "ronin", label = "Ronin", weapon = "sword", speed = 1.2, abilities = abilities("dash", "smoke", "core") },
        loadoutFor("sword", { airdash = 1, skate = 3 })))
    tick(0.1)
    assert(FPF.mission.className == "Ronin" and FPF.speedMul() == 1.2 and FPF.allowed("dash") and not FPF.allowed("jets"))
    assert(PS.weapon == "sword" and FPF.perk("sword") == 1 and FPF.perk("railgun") == 0 and FPF.perk("skate") == 3)
    -- the class is the Titan's own: gone with it
    deliver({ v = 2, op = "remove", id = "7001", epoch = 1, reason = "owner_removed" })
    tick(0.1)
    assert(FPF.mission.className == nil and FPF.speedMul() == 1.0 and FPF.allowed("missiles"))
end)

test("clearing the class gives everything back and leaves the weapon in the hands", function()
    fresh()
    sessionAndGrant()
    deliver(classMessage(2, { id = "legion", label = "Legion", weapon = "pred", speed = 0.85, abilities = abilities("sentry", "vortex", "smoke", "core") },
        loadoutFor("pred", { hull = 3 })))
    tick(0.1)
    assert(FPF.speedMul() == 0.85 and PS.weapon == "pred" and FPF.perk("xo16") == 0)
    deliver(classMessage(3, nil, schema.loadout.defaults()))
    tick(0.1)
    assert(FPF.mission.className == nil and FPF.speedMul() == 1.0 and FPF.mission.allowed == nil)
    for _, name in ipairs({ "missiles", "vortex", "smoke", "dash", "jets", "sentry", "flight", "designator", "core" }) do
        assert(FPF.allowed(name) == true, name)
    end
    assert(FPF.perk("xo16") == 1 and FPF.perk("railgun") == 1 and FPF.perk("fist") == 1)
    assert(PS.weapon == "pred", "clearing the class does not switch the weapon")
end)

test("a weapon whose perk is 0 cannot be selected by a command; a held Titan takes no switch; the class's own weapon is let through", function()
    fresh()
    sessionAndGrant()
    local function weapon(name)
        deliver({ v = 2, op = "command", action = "weapon", value = name })
        tick(0.1)
    end
    weapon("sword")
    assert(PS.weapon == "sword", "an unclassed Titan owns every weapon: " .. tostring(PS.weapon))
    -- a hold alone refuses the switch
    deliver({ v = 2, op = "hold", id = "7001", epoch = 1, held = true })
    tick(0.1)
    weapon("fist")
    assert(PS.weapon == "sword", "a held Titan takes no weapon command")
    deliver({ v = 2, op = "hold", id = "7001", epoch = 1, held = false })
    tick(0.1)
    weapon("fist")
    assert(PS.weapon == "fist", "released, the same command is taken")
    -- a perk at 0 alone refuses it too
    deliver(classMessage(2, { id = "northstar", label = "Northstar", weapon = "rail", speed = 1.0, abilities = abilities("core") }, loadoutFor("rail")))
    tick(0.1)
    assert(PS.weapon == "rail", "the class's own weapon is in hand")
    for _, name in ipairs({ "xo16", "pred", "sword", "fist" }) do
        weapon(name)
        assert(PS.weapon == "rail", name .. " was selected though its perk is 0")
    end
    weapon("rail")
    assert(PS.weapon == "rail")
    -- a held Titan is given the weapon of its class all the same, and stays held
    deliver({ v = 2, op = "hold", id = "7001", epoch = 1, held = true })
    deliver(classMessage(3, { id = "ronin", label = "Ronin", weapon = "sword", speed = 1.2, abilities = abilities("dash") }, loadoutFor("sword")))
    tick(0.1)
    assert(PS.weapon == "sword" and FPF.held() == true, "a class gives a held Titan its weapon, and the hold stays")

    -- the player's other commands: a held Titan runs no action and does not climb out; released, the same ones run
    local ejected, climbed = 0, 0
    replace(FPF, "ejectStart", function() ejected = ejected + 1 end)
    replace(env, "startDismount", function() climbed = climbed + 1 end)
    S.driving, S.pilot, S.cam, PS.mode, PS.dashKeyAt = true, true, {}, "pilot", -10.0
    local function commands()
        deliver({ v = 2, op = "command", action = "action", value = "dash" })
        deliver({ v = 2, op = "command", action = "action", value = "eject" })
        deliver({ v = 2, op = "command", action = "exit" })
        tick(0.2)
    end
    commands()
    assert(PS.dashKey == false and ejected == 0 and climbed == 0, "a held Titan runs none of them")
    deliver({ v = 2, op = "hold", id = "7001", epoch = 1, held = false })
    tick(0.1)
    commands()
    assert(PS.dashKey == true and ejected == 1 and climbed == 1, ("released: dash %s, eject %d, climb %d"):format(tostring(PS.dashKey), ejected, climbed))
end)

test("the grab key takes no offer from a Titan that is held or has no fists", function()
    -- the bridge's context is private; the offer's gate is base_ready, which asks FPF.held and ctx.canWield. The controller's side of
    -- the first is the seam above and the bridge's side of the second the weapon test above: what is left to show is that the gate
    -- reads them
    local source = io.open(root .. "controller/open77_titan_grab.lua", "rb"):read("a")
    assert(source:find("if FPF.held() then return false end", 1, true), "the grab's offer lost its hold")
    assert(source:find('ctx.canWield and not ctx.canWield("fist")', 1, true), "the grab's offer lost its fist-perk rule")
end)

test("a scripted control the hold refuses is not remembered as held, so the script's next press is not taken for a repeat", function()
    fresh()
    sessionAndGrant()
    S.driving, S.pilot, S.cam, PS.mode = true, true, {}, "pilot"
    deliver({ v = 2, op = "hold", id = "7001", epoch = 1, held = true })
    deliver({ v = 2, op = "input", id = "7001", epoch = 1, name = "Forward", value = true })
    tick(0.1)
    assert(S.kf == 0, "the hold refused the press")
    deliver({ v = 2, op = "hold", id = "7001", epoch = 1, held = false })
    deliver({ v = 2, op = "input", id = "7001", epoch = 1, name = "Forward", value = true })
    tick(0.1)
    assert(S.kf == 1, "released, the same press is a press and not a repeat of one the controller never ran")
end)

test("a kill credit adds the controller's own core charge for the rank: 5, 7 and 10, never past the core, never without BURST CORE", function()
    fresh()
    sessionAndGrant()
    PS.ent, PS.core = {}, { charge = 0.0 }
    local scale = P.coreScale or 1.0
    local function credit(rank, extra)
        local message = { v = 2, op = "credit_kill", id = "7001", epoch = 1, rank = rank }
        for key, value in pairs(extra or {}) do message[key] = value end
        deliver(message)
        tick(0.1)
    end
    local kill = FPC.perk.core.kill
    assert(kill.grunt == 5.0 and kill.rare == 7.0 and kill.heavy == 10.0, "the controller's own values")
    assert(FPF.coreMax() == 150.0, "BURST CORE level 3: " .. FPF.coreMax())
    credit("grunt")
    assert(math.abs(PS.core.charge - 5.0 * scale) < 1e-9, PS.core.charge)
    credit("rare")
    assert(math.abs(PS.core.charge - 12.0 * scale) < 1e-9, PS.core.charge)
    credit("heavy")
    assert(math.abs(PS.core.charge - 22.0 * scale) < 1e-9, PS.core.charge)
    -- another Titan's, another epoch's and a malformed one are not this controller's
    credit("heavy", { id = "9" })
    credit("heavy", { epoch = 2 })
    credit("boss")
    credit("grunt", { extra = true })
    assert(math.abs(PS.core.charge - 22.0 * scale) < 1e-9, "nothing of those was credited")
    -- the ceiling
    PS.core.charge = FPF.coreMax() - 2.0
    credit("heavy")
    assert(PS.core.charge == FPF.coreMax(), "capped at the core's maximum: " .. PS.core.charge)
    -- a burning core and the flight strike take no charge: the controller's own rule
    PS.core.charge, PS.core.left = 0.0, 4.0
    credit("heavy")
    assert(PS.core.charge == 0.0, "a burning core takes none")
    PS.core.left, PS.flight = nil, { on = true }
    credit("heavy")
    assert(PS.core.charge == 0.0, "the flight strike takes none")
    PS.flight = nil
    -- no BURST CORE, no core, no BT: no gain, and the reason is reported once
    local noCore = schema.loadout.defaults()
    noCore.burstcore = 0
    deliver(classMessage(2, { id = "bare", label = "Bare", weapon = "fist", speed = 1.0, abilities = abilities() }, loadoutFor("fist", { burstcore = 0 })))
    tick(0.1)
    assert(FPF.perk("burstcore") == 0)
    credit("heavy")
    assert(PS.core.charge == 0.0, "no BURST CORE, no charge")
    PS.ent = nil
    credit("grunt")
    assert(PS.core.charge == 0.0)
    -- gameplay.creditKill itself, as the bridge calls it
    PS.ent = {}
    local added, why = gameplay.creditKill(env, "boss")
    assert(added == nil and why == "invalid_request")
    S.gone = true
    added, why = gameplay.creditKill(env, "grunt")
    assert(added == nil and why == "no_session")
    S.gone = false
end)

test("the HUD state carries the class's name, the abilities it allows and the hold, and the two cells of the strike and the designator", function()
    fresh()
    sessionAndGrant()
    local hudModule = require("controller.open77_titan_hud")
    local shown
    environment.render = { state = function(state) shown = state end }
    local hudDiags = {}
    local hud = hudModule.new({ env = env, clock = 0, diag = function(key, text) hudDiags[key] = text end, grabUi = nil })
    local function state(held)
        S.driving, S.pilot, PS.mode, S.gone, S.paused, S.endMenu = true, true, "pilot", false, false, false
        PS.gun, PS.hp, PS.exec, P.hud, PS.core = {}, {}, nil, true, { charge = FPF.coreMax() }
        shown = nil
        hud.clear()
        shown = nil
        hud.frame()
        return shown
    end
    local plain = state()
    assert(plain and plain.on == true, "the state is built: " .. tostring(next(hudDiags)))
    assert(plain.className == nil and plain.held == false, "no class, not held")
    for _, name in ipairs({ "missiles", "vortex", "smoke", "dash", "jets", "sentry", "flight", "designator", "core" }) do
        assert(plain.allowed[name] == true, name .. " is allowed without a class")
    end
    assert(hudDiags.mission == nil, "the mission section raised: " .. tostring(hudDiags.mission))
    -- a class: the label, its nine, a table of the state's own
    deliver(classMessage(2, { id = "northstar", label = "Northstar", weapon = "rail", speed = 1.0, abilities = abilities("jets", "flight", "designator", "core") },
        loadoutFor("rail", { flight = 1, designator = 1 })))
    deliver({ v = 2, op = "hold", id = "7001", epoch = 1, held = true })
    tick(0.1)
    local classed = state()
    assert(classed.className == "Northstar" and classed.held == true)
    for name, on in pairs({ missiles = false, vortex = false, smoke = false, dash = false, jets = true, sentry = false, flight = true,
        designator = true, core = true }) do
        assert(classed.allowed[name] == on, name)
    end
    assert(classed.allowed ~= FPF.mission.allowed, "the page gets a table of its own")
    -- the strike's and the designator's cells: there once the perk is owned, the strike ready only when the core is full; a class's
    -- designator is its BARRAGE
    replace(FPF, "sharedKeyDrop", function() return nil end)
    classed = state()
    local cells = {}
    for _, cell in ipairs(classed.abilities or {}) do cells[cell.id] = cell end
    assert(cells.flight and cells.flight.name == "FLIGHT" and cells.flight.state == "ready", "FLIGHT STRIKE with a full core: " .. tostring(cells.flight and cells.flight.state))
    assert(classed.core and classed.core.name == nil and classed.core.ability == nil, "on keys of their own the core is its own bar")
    assert(cells.designator and cells.designator.name == "BARRAGE" and cells.designator.state == "ready")
    PS.core.charge = 0.0
    hud.clear()
    shown = nil
    hud.frame()
    cells = {}
    for _, cell in ipairs(shown.abilities or {}) do cells[cell.id] = cell end
    assert(cells.flight and cells.flight.state == "empty", "an empty core cannot start it: " .. tostring(cells.flight and cells.flight.state))
    -- FLIGHT STRIKE on the core's key: one bar, named for the strike, and no FLIGHT cell
    replace(FPF, "sharedKeyDrop", function() return "core" end)
    local merged = state()
    cells = {}
    for _, cell in ipairs(merged.abilities or {}) do cells[cell.id] = cell end
    assert(cells.flight == nil and merged.core.name == "FLIGHT STRIKE" and merged.core.ability == "flight" and merged.core.state == "ready",
        "a full core on the shared key is the strike's: " .. tostring(merged.core.state))
    local function again()
        hud.clear()
        shown = nil
        hud.frame()
        return shown
    end
    PS.core.charge = 0.0
    assert(again().core.state == "charging", "an empty core: charging")
    PS.flight = { t = 0.0 }
    assert(again().core.state == "active", "BT flies: active")
    PS.flight = nil
    -- no perk, no cell
    deliver(classMessage(3, { id = "bare", label = "Bare", weapon = "fist", speed = 1.0, abilities = abilities("core") }, loadoutFor("fist", { flight = 0, designator = 0 })))
    tick(0.1)
    local bare = state()
    cells = {}
    for _, cell in ipairs(bare.abilities or {}) do cells[cell.id] = cell end
    assert(cells.flight == nil and cells.designator == nil, "a Titan without the perks has neither cell")
    environment.render = nil
end)

test("the broadsword's SPIN SLASH has a cell of its own on R: its charges, active while BT spins, none for another weapon", function()
    fresh()
    sessionAndGrant()
    local shown
    environment.render = { state = function(state) shown = state end }
    local hud = require("controller.open77_titan_hud").new({ env = env, clock = 0, diag = function() end, grabUi = nil })
    local function cells()
        S.driving, S.pilot, PS.mode, S.gone, S.paused, S.endMenu = true, true, "pilot", false, false, false
        PS.gun, PS.hp, PS.exec, P.hud, PS.core = {}, {}, nil, true, { charge = 0 }
        hud.clear()
        shown = nil
        hud.frame()
        local out = {}
        for _, c in ipairs(shown.abilities or {}) do out[c.id] = c end
        return out
    end
    replace(P, "keyHints", true)
    replace(S, "keysOk", true)
    local most = FPC.sword.spin.charges
    PS.weapon, PS.spinCharge, PS.spin = "sword", most, nil
    local spin = cells().spin
    assert(spin and spin.name == "SPIN" and spin.key == "R" and spin.state == "ready" and spin.count == most and spin.fill == nil,
        "a full SPIN cell on R")
    PS.spinCharge = 0.5
    spin = cells().spin
    assert(spin.state == "empty" and spin.count == 0 and math.abs(spin.fill - 0.5) < 1e-6, "no charge left: empty, refilling")
    PS.spin = {}
    assert(cells().spin.state == "active", "BT spins")
    PS.weapon, PS.spin = "xo16", nil
    assert(cells().spin == nil, "another weapon has none")
    PS.weapon, PS.spinCharge = "xo16", nil
    environment.render = nil
end)

-- ---------------------------------------------------------------------------
-- Blows on Open77 NPCs, on the real controller: OP77.npcHit is what its blow functions call next to OP77.playerHit. The body is told
-- by its engine entity id against the platform's NPC list (Open77.npcs.all); only an NPC of that list is reported, as an `npc_hit`
-- under the grant's id, epoch and count, with the kind its record stands for. Whether the game's own hit lands on the body, what
-- the server publishes and what the mission prices are not this test's: the engine, the server and the mission have their own.
-- ---------------------------------------------------------------------------
local npcRows, playerRows = {}, {}
environment.Open77.npcs = { all = function() return npcRows end }
environment.Open77.players = { nearby = function() return playerRows end }
-- A game entity: its id and place, and a "no" to every other question the controller may ask of it.
local function body(id)
    return setmetatable({ GetEntityID = function() return id end, GetWorldPosition = function() return { x = 1.0, y = 2.0, z = 3.0 } end },
        { __index = function() return function() return false end end })
end
local function npcHits() return publishedOps("npc_hit") end
local function tickBy(seconds)
    clock = clock + seconds
    S.clock = clock
    OP77.tick(seconds)
end
-- Two NPCs (platform ids 77 and 78) and two players (3, and the local one) the platform knows; the list is read afresh every quarter of a second.
local function npcWorld()
    npcRows = { { id = 77, engineEntity = 5001 }, { id = 78, engineEntity = 5002 } }
    playerRows = { { playerId = 3, engineEntity = 6001, isLocal = false }, { playerId = 42, engineEntity = 6002, isLocal = true } }
    tick(0.3)
end
local function keyList(map)
    local list = {}
    for key in pairs(map) do list[#list + 1] = tostring(key) end
    table.sort(list)
    return table.concat(list, ",")
end

test("the controller's ragdoll on an Open77 body only when it names it: BERSERKER's launch target, never another player's body", function()
    fresh(); sessionAndGrant(); npcWorld()
    local function body(id, sent)
        return setmetatable({ GetEntityID = function() return id end, QueueEvent = function() sent.n = sent.n + 1 end },
            { __index = function() return function() return false end end })
    end
    local function ragdoll(id, named)
        local sent = { n = 0 }
        local b = body(id, sent)
        FPF.laterQueue = {}
        FPF.ragdollAsked = named and b or nil
        local asked = FPF.ragdoll(b, 1.0, 2.0, 3.0, 1.0, 0.0, 5.0)
        FPF.ragdollAsked = nil
        return asked, sent.n, FPF.laterPending()
    end
    local asked, sent, later = ragdoll(5001, false)
    assert(asked == false and sent == 0 and not later, "an Open77 NPC's knock-down is left out, impulse and all")
    asked, sent, later = ragdoll(5001, true)
    assert(asked == true and sent >= 1 and later, "the NPC the controller names gets its ragdoll and impulse")
    asked, sent, later = ragdoll(6001, true)
    assert(asked == false and sent == 0 and not later, "another player's body never does, named or not")
    asked, sent, later = ragdoll(9001, false)
    assert(asked == true and sent >= 1, "a body Open77 does not drive is the controller's own business")
    FPF.laterQueue = {}
end)

test("a blow on an Open77 NPC is reported with its platform id, the kind of its record and where it landed, under the grant's id, epoch and count", function()
    fresh(); sessionAndGrant(); npcWorld()
    assert(OP77.npcHit(body(5001), "Attacks.BT7274_Sword", 1.5, 2.5, 3.5) == true)
    assert(#npcHits() == 0, "the report leaves with the frame's flush, not from inside the blow")
    tick(0.05)
    local list = npcHits()
    assert(#list == 1, #list)
    local message = list[1]
    assert(message.v == 2 and message.op == "npc_hit" and message.id == "7001" and message.epoch == 1 and message.seq == 1
        and message.npc == "77" and message.record == "Attacks.BT7274_Sword" and message.kind == "blade"
        and message.point.x == 1.5 and message.point.y == 2.5 and message.point.z == 3.5)
    assert(keyList(message) == "epoch,id,kind,npc,op,point,record,seq,v" and keyList(message.point) == "x,y,z", keyList(message))
    assert(schema.npc_hit(message) ~= nil, "the message is one the controller's own twin of the server's schema accepts")
    -- The count goes on with the grant, shared with the other observations, and the next NPC is its own report.
    assert(OP77.npcHit(body(5002), "Attacks.BT7274_Fist", 4, 5, 6) == true)
    tick(0.05)
    assert(#npcHits() == 2 and npcHits()[2].seq == 2 and npcHits()[2].npc == "78" and npcHits()[2].kind == "melee")
    -- The place is the blow's, or the body's own when the call has none.
    assert(OP77.npcHit(body(5001), "Attacks.BT7274_Punch", nil, nil, nil) == true)
    tick(0.05)
    assert(#npcHits() == 3 and npcHits()[3].point.x == 1.0 and npcHits()[3].point.y == 2.0 and npcHits()[3].point.z == 3.0)
    assert(OP77.npcHit(body(5001), "Attacks.BT7274_Punch", 0 / 0, 1, 1) == true)
    tick(0.05)
    assert(#npcHits() == 4 and npcHits()[4].point.x == 1.0, "a place that is not a number is the body's")
end)

test("the kind of a blow is its record's: rounds, blasts, fists, blades, and everything else", function()
    fresh(); sessionAndGrant(); npcWorld()
    local kinds = {
        round = { "XO16_Hit", "Pred_Hit", "Rail_1", "Rail_2", "Rail_3", "Rail_4" },
        blast = { "Missile", "FlightRocket", "MissileBlast", "FlightBlast", "Fist_Blast", "Pound_Mid", "Pound_Edge", "Eject" },
        melee = { "Punch", "Fist", "Fist_Heavy", "Fist_Charged", "Fist_Core" },
        blade = { "Sword", "Sword_Core", "Sword_Charged", "ArcWave" },
        other = { "Vortex", "Vortex_x2", "Vortex_x64", "Smoke", "Gas", "Unknown_Blow" },
    }
    local count = 0
    for kind, records in pairs(kinds) do
        for _, name in ipairs(records) do
            assert(OP77.npcHit(body(5001), "Attacks.BT7274_" .. name, 1, 2, 3) == true, name)
            tick(0.1)                      -- past the spacing of rounds
            count = count + 1
            local last = npcHits()[count]
            assert(last and last.record == "Attacks.BT7274_" .. name and last.kind == kind, name .. ": " .. tostring(last and last.kind))
        end
    end
    -- The game's own fallback record, which every weapon uses when TweakXL did not load its own, says nothing of the weapon.
    assert(OP77.npcHit(body(5001), "Attacks.ExplosionSmall", 1, 2, 3) == true)
    tick(0.1)
    assert(npcHits()[count + 1].kind == "other")
    -- A record the schema refuses is not sent, and says why once.
    assert(OP77.npcHit(body(5001), "Attacks X", 1, 2, 3) == false and lastDiag("refused by the schema (hit_record)"))
    assert(OP77.npcHit(body(5001), nil, 1, 2, 3) == false)
    tick(0.1)
    assert(#npcHits() == count + 1)
end)

test("a player, a car, a vanilla ped, the local player, this Titan and its decoy are never reported as an NPC", function()
    fresh(); sessionAndGrant(); npcWorld()
    local function refused(label, entity)
        assert(OP77.npcHit(entity, "Attacks.BT7274_Punch", 1, 2, 3) == false, label)
        tick(0.1)
        assert(#npcHits() == 0, label .. ": a report left")
    end
    refused("another player's body", body(6001))
    refused("the local player's own body", body(6002))
    refused("a car or a vanilla ped (no platform id)", body(7001))
    refused("an entity of a number the lists do not know", body(8123456789))
    refused("nothing", nil)
    refused("a thing with no entity id", {})
    refused("a thing whose id is not a number", { GetEntityID = function() return "5001" end })
    refused("an id of 0", { GetEntityID = function() return 0 end })
    -- An NPC row whose body is not streamed yet (engine entity 0) tells no body from another.
    npcRows = { { id = 79, engineEntity = 0 }, { id = 77, engineEntity = 5001 } }
    tick(0.3)
    refused("an NPC that has no body here yet", body(0))
    -- The Titan's own body and its decoy, even where a list named them.
    PS.ent = body(5001)
    assert(OP77.npcHit(body(5001), "Attacks.BT7274_Punch", 1, 2, 3) == false, "this Titan")
    PS.ent = nil
    PS.decoy = { hash = "5001" }
    assert(OP77.npcHit(body(5001), "Attacks.BT7274_Punch", 1, 2, 3) == false, "its decoy")
    PS.decoy = nil
    tick(0.1)
    assert(#npcHits() == 0)
    -- And the same body, with neither of those named, is a blow.
    assert(OP77.npcHit(body(5001), "Attacks.BT7274_Punch", 1, 2, 3) == true)
    tick(0.05)
    assert(#npcHits() == 1 and npcHits()[1].npc == "77")
    -- A list that raises is contained, and a blow on a body it cannot tell is not a report.
    local list = environment.Open77.npcs.all
    environment.Open77.npcs.all = function() error("platform down") end
    tick(0.3)
    assert(OP77.npcHit(body(5002), "Attacks.BT7274_Punch", 1, 2, 3) == false)
    environment.Open77.npcs.all = list
    tick(0.3)
    assert(#npcHits() == 1 and lastDiag("could not be listed"))
end)

test("a blow on an NPC needs the grant: none before it, none after the Titan or the session ends, and a new Titan counts again from 1", function()
    fresh(); npcWorld()
    assert(OP77.npcHit(body(5001), "Attacks.BT7274_Punch", 1, 2, 3) == false and lastDiag("no live Titan grant"), "no grant")
    tick(0.1)
    assert(#npcHits() == 0)
    sessionAndGrant()
    assert(OP77.npcHit(body(5001), "Attacks.BT7274_Punch", 1, 2, 3) == true)
    -- queued, not yet flushed: the Titan ends first
    deliver({ v = 2, op = "remove", id = "7001", epoch = 1, reason = "owner_removed" })
    tick(0.1)
    assert(#npcHits() == 0, "a blow of a Titan that is gone left")
    assert(OP77.npcHit(body(5001), "Attacks.BT7274_Punch", 1, 2, 3) == false, "after the removal")
    -- a new Titan: its own id, and the count starts again
    sessionAndGrant({}, "7002")
    assert(OP77.npcHit(body(5001), "Attacks.BT7274_Punch", 1, 2, 3) == true)
    tick(0.05)
    assert(#npcHits() == 1 and npcHits()[1].id == "7002" and npcHits()[1].seq == 1)
    -- the session's end drops what is queued and refuses what comes
    assert(OP77.npcHit(body(5001), "Attacks.BT7274_Fist", 1, 2, 3) == true)
    deliver({ v = 2, op = "session", active = false, player = "42" })
    tick(0.1)
    assert(#npcHits() == 1, "a blow queued when the session ended left")
    assert(OP77.npcHit(body(5001), "Attacks.BT7274_Fist", 1, 2, 3) == false, "after the session")
end)

test("rounds on one NPC are reported at most once per gap (1/60 s); another NPC, another kind and a pending round are told apart", function()
    fresh(); sessionAndGrant(); npcWorld()
    local npc1, npc2, round = body(5001), body(5002), "Attacks.BT7274_XO16_Hit"
    assert(schema.NPC.roundGap == 1 / 60)
    -- five rounds in one frame on one NPC are one report; a round on the other NPC is its own
    for _ = 1, 5 do assert(OP77.npcHit(npc1, round, 1, 2, 3) == true, "the burst's rounds are taken up, not refused") end
    assert(OP77.npcHit(npc2, round, 1, 2, 3) == true)
    tick(0.05)
    assert(#npcHits() == 2 and npcHits()[1].npc == "77" and npcHits()[2].npc == "78" and npcHits()[1].kind == "round")
    -- the next frame is 50 ms on: the next round goes
    OP77.npcHit(npc1, round, 1, 2, 3)
    tick(0.05)
    assert(#npcHits() == 3 and npcHits()[3].seq == 3)
    -- a round every 10 ms for a second: never more than one per gap (the frames are 10 ms apart here, so every other one goes: 50)
    published = {}
    for _ = 1, 100 do
        OP77.npcHit(npc1, round, 1, 2, 3)
        tickBy(0.01)
    end
    local taken = #npcHits()
    assert(taken >= 48 and taken <= 52, "a second of rounds on one NPC: " .. taken)
    -- a round every 50 ms is every one
    tickBy(0.1)
    published = {}
    for _ = 1, 20 do
        OP77.npcHit(npc2, round, 1, 2, 3)
        tickBy(0.05)
    end
    assert(#npcHits() == 20, "rounds spaced by the gap are all reported: " .. #npcHits())
    -- every other kind is its own blow, however many in a frame
    tickBy(0.1)
    published = {}
    for _, record in ipairs({ "Attacks.BT7274_MissileBlast", "Attacks.BT7274_MissileBlast", "Attacks.BT7274_Sword", "Attacks.BT7274_Sword", "Attacks.BT7274_Fist" }) do
        assert(OP77.npcHit(npc1, record, 1, 2, 3) == true)
    end
    tickBy(0.05)
    assert(#npcHits() == 5 and npcHits()[1].kind == "blast" and npcHits()[3].kind == "blade" and npcHits()[5].kind == "melee")
    -- the gap is the report's, not the call's: a round pending for the resource is not asked twice, and goes once it is taken
    tickBy(0.1)
    local refuse = true
    OP77.link({ send = function(message)
        if refuse then return false end
        published[#published + 1] = message
        return true
    end, poll = function() return table.remove(inbox, 1) end })
    published = {}
    for _ = 1, 4 do
        OP77.npcHit(npc2, round, 1, 2, 3)
        tickBy(0.05)
    end
    assert(#npcHits() == 0, "the resource took nothing")
    refuse = false
    tickBy(0.05)
    assert(#npcHits() == 1, "one pending round went once the resource took it: " .. #npcHits())
    OP77.npcHit(npc2, round, 1, 2, 3)
    tickBy(0.05)
    assert(#npcHits() == 2, "and the next round after the gap too")
    -- a report that waited past its time is dropped, not sent late
    refuse = true
    OP77.npcHit(npc1, "Attacks.BT7274_MissileBlast", 1, 2, 3)
    for _ = 1, 42 do tickBy(0.05) end
    refuse = false
    tickBy(0.05)
    assert(#npcHits() == 2 and lastDiag("could not be sent in time"), "a blow that waited two seconds was sent late")
    -- the original link of this file
    OP77.link({ send = function(message) published[#published + 1] = message; return true end, poll = function() return table.remove(inbox, 1) end })
end)

test("the controller's blow functions report an NPC they hit once per blow, and a player's body as a player", function()
    fresh(); sessionAndGrant(); npcWorld()
    local npc = body(5001)
    -- the missile blast's hit on each person near it, the punch, the sword and the fists all go through FPF.hit; the big bodies through FPF.hitFull
    FPF.hit(npc, "Attacks.BT7274_MissileBlast", 1, 2, 3, 0, 0, 1)
    tick(0.05)
    FPF.hitFull(npc, "Attacks.BT7274_Punch", 1, 2, 3, 0, 0, 1)
    tick(0.05)
    FPF.hit(npc, "Attacks.BT7274_Sword", 1, 2, 3, 0, 0, 1)
    tick(0.05)
    local list = npcHits()
    assert(#list == 3, #list)
    assert(list[1].kind == "blast" and list[1].npc == "77" and list[1].record == "Attacks.BT7274_MissileBlast", "FPF.hit")
    assert(list[2].kind == "melee" and list[2].record == "Attacks.BT7274_Punch", "FPF.hitFull")
    assert(list[3].kind == "blade" and list[3].record == "Attacks.BT7274_Sword")
    assert(list[1].point.x == 1 and list[1].point.y == 2 and list[1].point.z == 3, "where the blow landed")
    -- another player's body hit by the same functions is a player_hit and no npc_hit; a car and a vanilla ped are neither
    FPF.hit(body(6001), "Attacks.BT7274_Punch", 1, 2, 3, 0, 0, 1)
    FPF.hitFull(body(6001), "Attacks.BT7274_Punch", 1, 2, 3, 0, 0, 1)
    FPF.hit(body(7001), "Attacks.BT7274_Punch", 1, 2, 3, 0, 0, 1)
    FPF.hit(body(8001), "Attacks.BT7274_Sword", 1, 2, 3, 0, 0, 1)
    tick(0.2)
    assert(#npcHits() == 3, "a player, a car or a vanilla ped was reported as an NPC")
    local players = publishedOps("player_hit")
    assert(#players == 1 and players[1].player == "3" and players[1].count == 2, "the player's body is a player_hit")
    assert(#publishedOps("vehicle_hit") == 0)
    -- the XO-16's own round path is the file-local hitPerson: every place that reports a blow on a player reports it on an NPC, with the same arguments
    local file = assert(io.open(root .. "controller/init.lua", "rb"))
    local text = file:read("a")
    file:close()
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\r?\n") do lines[#lines + 1] = line end
    local seams, calls = 0, 0
    for index, line in ipairs(lines) do
        if line:find("OP77.npcHit(", 1, true) then calls = calls + 1 end
        local args = line:match("OP77%.playerHit%(([^)]*)%)")
        if args then
            seams = seams + 1
            local following = (lines[index + 1] or ""):match("^%s*OP77%.npcHit%(([^)]*)%)")
            assert(following == args .. ", x, y, z", "line " .. index .. ": OP77.playerHit(" .. args .. ") is not followed by OP77.npcHit")
        end
    end
    assert(seams == 3 and calls == 3, seams .. " player seams, " .. calls .. " NPC calls (hitPerson, FPF.hit, FPF.hitFull)")
end)

report(("%d controller tests passed"):format(passed))
