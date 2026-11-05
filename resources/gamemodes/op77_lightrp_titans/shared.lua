-- op77_lightrp_titans: the one wire contract (v=2) both halves enforce.
--
-- Shared by the server (authority: every client frame is untrusted) and the
-- client (defence in depth: nothing malformed reaches the server or the
-- controller). Pure data and arithmetic: no engine calls, so the same file runs
-- under the offline protocol tests.
--
-- Everything is a fixed, bounded schema. A validator never executes, resolves or
-- forwards client text: names must be members of the generated catalog
-- (`Open77TitanCatalog`, catalog.lua), every number is finite and range-checked,
-- and what comes out is a COPY holding only the known keys, never the input table.
--
-- Version 2 adds the Titan loadout (loadout.lua): the grant carries the owner's complete perk map and the
-- server's `loadout` op replaces it. Both are validated here as complete maps (every perk, nothing else).
--
-- The mission's controls ride the same version: the grant may carry `piloted` / `hold` (the options of the `spawn` export), and
-- the `hold`, `class` and `credit_kill` ops carry a mission's hold, class and kill credit to the owner's controller. The class
-- is validated by one function here (T.normalizeClass for the export's spec, the message's own copy of it on the wire) and the
-- controller's schema (controller/open77_titan_schema.lua) takes the same keys and bounds.
Open77Titans = {}
local T = Open77Titans

T.protocol = 2

-- loadout.lua (a shared script listed before this one) assigns the global the same way catalog.lua does. Both
-- halves and the controller use this one module for the perk ids, their maxima and the complete-map checks.
if type(Open77TitanLoadout) ~= "table" or type(Open77TitanLoadout.complete) ~= "function" then
    error("op77_lightrp_titans: loadout.lua must be listed before shared.lua and assign Open77TitanLoadout", 0)
end
T.loadout = Open77TitanLoadout

-- Net events. One server -> client event carries every bridge op; the client -> server events are separate so the
-- server can budget them apart.
T.event = {
    ready = "op77_lightrp:titans:ready",       -- client -> server  { bridge = bool, reason?, answer? } (answer = true: the reply to probe)
    frame = "op77_lightrp:titans:frame",       -- client -> server  frame (the controller's 20 Hz publish)
    request = "op77_lightrp:titans:request",   -- client -> server  "spawn" | "remove"
    message = "op77_lightrp:titans:msg",       -- server -> client  session/grant/loadout/class/hold/credit_kill/command/input/input_release/hit/repair/core_credit/state/remove/error
    carry = "op77_lightrp:titans:carry",       -- client -> server  carry_request / carry_frame / carry_release (own budget)
    result = "op77_lightrp:titans:result",     -- client -> server  gameplay_result: the owner's answer to a hit / repair / core credit (own budget)
    hit = "op77_lightrp:titans:hit",           -- client -> server  hit_observed: a blow the owner's Titan landed on another Titan (own budget)
    status = "op77_lightrp:titans:status",     -- client -> server  status_observed: a status effect the owner's Titan applied to another Titan (the hit budget)
    vehicle = "op77_lightrp:titans:vehicle",   -- client -> server  vehicle_hit: a blow the owner's Titan landed on a car (the hit budget)
    player = "op77_lightrp:titans:player",     -- client -> server  player_hit: a blow the owner's Titan landed on another player (the hit budget)
    npc = "op77_lightrp:titans:npc",           -- client -> server  npc_hit: a blow the owner's Titan landed on a platform NPC (the hit budget)
    probe = "op77_lightrp:titans:probe",       -- server -> client  (no arguments) the resource started on the server: every client that has already decided its bridge answers once with ready { answer = true }
}

-- Every cap below is enforced identically on both sides. The client's event and
-- JSON ENCODERS (TriggerServerEvent, Open77.json.encode) count every table key as
-- well as every value against a 1024 limit at depth 8, so `nodes` is a KEYED
-- count (see countNodes): a frame of N JSON values costs 2N-1. 1000 leaves 24 for
-- what the client adds before encoding (v/op: 4; the relayed state's v/op/owner/
-- serverTime: 8). The decoder counts values only, so it is never the tighter side.
T.limits = {
    messageBytes = 32768,       -- native bridge bound, UTF-8 bytes per message
    frameBytes = 30720,         -- one frame as JSON; the relay adds ~200 bytes
    nodes = 1000,               -- keyed nodes per frame (keys + values, containers included)
    coordinate = 1000000,       -- |x|,|y|,|z| of any point
    yaw = 3600,                 -- degrees, |yaw|
    rotation = 100000,          -- |component| of an event rotation
    variable = 1000000,         -- |value| of one animation variable
    variables = 64,
    meshes = 32,
    lights = 16,
    visuals = 32,
    events = 24,
    fxId = 48,                  -- characters
    gain = 4,
    tracerLife = 10,            -- seconds
    tracerWidth = 5,
    integer = 9007199254740991, -- largest exactly representable id / sequence
    time = 1000000000,          -- controller monotonic seconds
    -- Server-side budgets (token buckets).
    frameRate = 25,             -- sustained frames per second (the controller publishes 20)
    frameBurst = 5,
    byteRate = 131072,          -- sustained frame bytes per second
    byteBurst = 262144,
    eventRate = 240,            -- sustained relayed events per second per Titan
    eventBurst = 128,
    commandRate = 3,            -- sustained user commands / requests per second per player
    commandBurst = 6,
    inbox = 8,                  -- frames of one owner buffered inside a server tick
    -- Authority timers (seconds) and movement admission.
    firstFrame = 20,            -- a grant with no frame yet is released after this
    stall = 5,                  -- a live Titan that stops publishing is released after this
    spawnRadius = 150,          -- first pose must be within this of the owner (existing hit-range convention)
    dropRadius = 500,           -- ... or this when the first frame is the call-down (mode 'drop') arriving from the sky
    dropWindow = 15,            -- one continuous run of mode 'drop' or 'leave' may last at most this (seconds)
    poseSpeed = 250,            -- m/s: the player snapshot plausibility ceiling per axis
    poseSlack = 5,              -- metres of slack on top of poseSpeed * dt
    poseMinGap = 0.05,
    poseMaxGap = 2,
    poseViolations = 60,        -- consecutive rejected poses before the Titan is released (~3 s)
    titans = 64,                -- server-wide ceiling; one per player in practice
    heartbeat = 2,              -- client re-asserts the bridge and session this often (seconds)
    -- Physical carry: the Titan's fist grabs a canonical NPC or vehicle, holds it and
    -- throws it (server.lua, "Physical carry"). Its own budgets, never the event budget.
    carryReach = 12,            -- m: Titan root -> body at the grab, and held pose -> Titan root
    carryFresh = 1,             -- s: the Titan's latest accepted frame must be this recent to start a carry
    carryFlight = 30,           -- s of flight after the throw, from the first accepted flight pose: a thrown person's ragdoll and a thrown vehicle alike. A hold has no time limit; only the stall, reach and presence rules end it
    carryFlightSlack = 0.75,    -- s: transport latency allowed on top of carryFlight
    carryStall = 1,             -- s without an accepted sample releases the claim
    carrySpeed = 60,            -- m/s ceiling of a held body's hand and of a thrown vehicle (a flight adds gravity)
    carryNpcFlightSpeed = 200,  -- m/s base of a thrown NPC's flight (its ragdoll flies ~160): replaces carrySpeed there
    carryGravity = 9.81,
    carrySlack = 2,             -- m on top of speed * gap (hand swing, quantization)
    carryMinGap = 0.1,
    carryMaxGap = 1,
    carryVelocity = 100,        -- m/s: |v| one sample may report (the platform's own bound)
    carryNormal = 0.02,         -- |q|^2 - 1 tolerated before a quaternion is renormalized
    carryRate = 25,             -- sustained samples per second (the controller sends 20)
    carryBurst = 5,
    carryMessageRate = 60,      -- every carry message of one player, parsed or not
    carryMessageBurst = 30,
    carryRequestRate = 1,       -- grab requests per second: a grab is a 3.4 s punch
    carryRequestBurst = 3,
    carryViolations = 5,        -- consecutive rejected samples before the claim is released
    carryPending = 5,           -- s: the client remembers an unanswered request this long
    carryPendingMax = 4,        -- unanswered requests the client remembers
    carryLaunchLag = 1.5,       -- s: a thrown person's FIRST accepted flight message may be this long after the release it reports (every later one repeats it)
    carryLaunchPoint = 2,       -- m: from the released body's root to the impulse point (the authored push is 0.6 m above it)
    carryLaunchImpulse = 1000,  -- |component| of the authored impulse (the throw's own is at most 912)
    carryLaunchRadius = 10,     -- m: the impulse's influence radius (the authored 2)
    carryLaunchDelay = 1,       -- s: how long after the ragdoll the impulse is applied (the authored 0.12)
    -- Gameplay: what the owner's controller reports of its Titan (health, ammunition, core, abilities: frame.gameplay) and
    -- the hit / repair requests a server script sends it (server.lua, "Gameplay"). Every figure is bounded and finite.
    gameplayValue = 1000000,    -- |value| of any reported health, ammunition, core or timer figure
    gameplayText = 64,          -- characters of a reported pause reason
    actionPending = 32,         -- unanswered hit / repair requests of one Titan
    actionTimeout = 5,          -- s: an unanswered request ends as 'timeout'
    actionRecord = 160,         -- characters of a hit's TweakDB record name
    actionAttacker = 96,        -- characters of a hit's attribution text
    actionScale = 4,            -- the controller's own ceiling on a hit's scale (FPC.bossScaleUp162.most amplifies no further)
    actionAmount = 1000000,     -- one repair, or the damage / amount an answer may report
    actionReason = 160,         -- characters of the controller's own word on a request (it can echo a record name)
    resultRate = 30,            -- sustained answers per second of one Titan
    resultBurst = 40,           -- (a full pending set is 32)
    -- Observed hits (hit_observed) and observed status effects (status_observed): the owner's report that its Titan landed a
    -- blow on, or applied a status effect to, another player's Titan. Both spend ONE eventRate / eventBurst bucket per source
    -- Titan and share ONE per-grant sequence; `hitWindow` is how many of the newest sequence numbers the server remembers to
    -- refuse a repeat while still taking reports that arrive newest-first inside one tick.
    hitWindow = 256,
    -- Blows on cars (vehicle_hit): the owner's report that its Titan's weapons landed on a canonical vehicle. It spends the same
    -- eventRate / eventBurst bucket and sequence as the observations above. `vehicleShare` is the controller's own unit, a
    -- percentage of the car's full health (FPF.wreck's `share`), so one report is at most the whole car. `vehicleReach` is how far
    -- the car may be from the Titan's latest accepted pose: the controller's longest weapon is the railgun (FPC.perk.rail.range,
    -- 400 m; the XO-16 and the Predator reach 250 m and the missiles 101.6 m), plus 50 m for a car that drives on and a pose that
    -- is a frame old. `vehiclePending` / `vehicleVerdict` bound the hits the server holds while a script's veto settles (a count
    -- for the server, seconds for one hit).
    vehicleShare = 100,
    vehicleReach = 450,
    vehiclePending = 256,
    vehicleVerdict = 10,
    -- Blows on players (player_hit): the owner's report that its Titan's weapons landed on another player's body, per player and
    -- attack record, summed by the bridge over a short window. It spends the same bucket and sequence as the reports above.
    -- `playerHitCount` is how many blows one report may sum; `playerReach` is how far the victim may be from the Titan's latest
    -- accepted pose (the same bound as a car's: the railgun's 400 m plus a pose a frame old).
    playerHitCount = 64,
    playerReach = 450,
    -- Blows on platform NPCs (npc_hit): the owner's report that its Titan's weapons landed on an NPC the platform owns. The server
    -- does not own the NPC and never touches it: a mission validates it and prices the blow. The report spends the same bucket and
    -- sequence as the reports above. A `round` (kind below) on one NPC is at most once per `npcRoundGap` seconds: the controller
    -- spaces its rounds by it, and the server keeps a bucket of `npcRoundBurst` rounds per NPC refilling at 1 / npcRoundGap, so
    -- the sustained rate is exactly that and one round of slack covers transport jitter. At most `npcRoundKeys` NPCs hold a
    -- bucket at a time (a stale one goes first). 60 a second: a mission's Burst Core fires the XO-16 and the Predator three
    -- times as fast (up to about 50 and 60 rounds a second), and at 20 a second one NPC took no more of them than without it.
    npcRoundGap = 1 / 60,
    npcRoundBurst = 2,
    npcRoundKeys = 128,
}
local L = T.limits

-- 'drop' is the controller's call-down (only as the first frames of a grant), 'leave'
-- the send-home jump away (only after non-drop frames); see server.lua modeAdmitted.
T.modes = {
    none = true, wait = true, pilot = true, mount = true, dismount = true, eject = true,
    drop = true, leave = true,
}
T.weapons = { xo16 = true, rail = true, pred = true, sword = true, fist = true }
-- Repeatable real controls of the controller (its Mod Settings key names).
T.actions = {
    jump = true, dash = true, punch = true, missiles = true, vortex = true,
    smoke = true, core = true, eject = true, view = true, shoulder = true, grab = true,
}
-- `core` (fill the BURST CORE, no value) is sent by the restricted `titan.core` command alone: /titan never parses it and the
-- server's `command` export has no vocabulary for it.
T.commandActions = { spawn = true, remove = true, pilot = true, exit = true, weapon = true, action = true, log = true, core = true }

-- Server-driven controls (the server's `input` export): every control a server script may hold on a piloted Titan,
-- with the kind of value it takes. Exact and case-sensitive; never a physical key, a function name or free text.
--   axis      a level in -1 .. 1 of one of the game's input axes: MoveX / MoveY (the stick), CameraX / CameraY (the right stick)
--   relative  one relative step of the mouse look, CameraMouseX / CameraMouseY, in the raw units the game's own
--             RELATIVE_CHANGE input carries (the controller divides it by 45 for degrees), bounded to +/-20000
--   button    true presses and false releases one of the game's actions
--   key       true presses and false releases one of the BT-7274 mod's own pilot keys (its Mod Settings names)
-- Companion commands (follow, home, call, embark, eject) are not in it. controller/open77_titan_schema.lua (S.INPUT) holds the
-- same table for the controller's bridge; tests/client.test.lua compares the two.
T.inputs = {
    MoveX = "axis", MoveY = "axis", CameraX = "axis", CameraY = "axis",
    CameraMouseX = "relative", CameraMouseY = "relative",
    Forward = "button", Back = "button", Left = "button", Right = "button", Sprint = "button", ToggleSprint = "button",
    Jump = "button", Dodge = "button", RangedAttack = "button", Reload = "button", QuickMelee = "button",
    RangedADS = "button", CameraAim = "button",
    jump = "key", dash = "key", punch = "key", missiles = "key", vortex = "key", smoke = "key", core = "key",
    view = "key", shoulder = "key", sentry = "key", designate = "key", flight = "key",
}
T.inputLimits = { axis = 1, relative = 20000 }
T.requestActions = { spawn = true, remove = true }
T.removeReasons = {
    owner_removed = true, owner_left = true, owner_dead = true, bucket_changed = true,
    resource_stopped = true, owner_stalled = true, controller_timeout = true,
    out_of_scope = true, pose_rejected = true, owner_restarted = true,
}
-- Why the client could not set the bridge up. Fixed codes: the client never
-- sends free text and the server never echoes any.
T.bridgeReasons = { bridge_missing = true, rtti_denied = true, rtti_unavailable = true }

local function set(...)
    local result = {}
    for _, value in ipairs({ ... }) do result[value] = true end
    return result
end

-- What a mission may switch off on a class (`setClass`): the nine abilities of the Titan the controller gates, by the mission's
-- names (`jets` is the controller's jump, `designator` its TARGET DESIGNATOR), and the three kinds of foe a kill credit names.
T.classAbilities = set("missiles", "vortex", "smoke", "dash", "jets", "sentry", "flight", "designator", "core")
T.killRanks = set("grunt", "rare", "heavy")
-- The walk and run speed a class may ask for, as a multiple of BT's own.
T.classSpeed = { min = 0.5, max = 1.5 }
-- The damage BT takes while it wears the class, as a multiple of what the controller would take (a mission's difficulty).
T.classHarm = { min = 0.1, max = 50 }
-- How many times slower BT's shield comes back while it wears the class: the wait after a hit and the refill both (a mission's
-- difficulty; 1 is the controller's own 6 s and 2 s).
T.classRegen = { min = 0.25, max = 10 }

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
T.finite = finite

local function whole(value, minimum, maximum)
    if not finite(value) or value % 1 ~= 0 or value < minimum or value > maximum then return nil end
    return math.tointeger(value) or value
end
T.whole = whole

-- True when `value` has no key outside `allowed`; bounded so a hostile table
-- cannot make the check itself expensive.
local function keysOnly(value, allowed)
    local count = 0
    for key in pairs(value) do
        count = count + 1
        if count > 32 or allowed[key] ~= true then return false end
    end
    return true
end

-- The real getter where the host keeps it (nil in the client resource host's sandbox, where nothing can attach a
-- metatable): a table that carries a metatable is never read, so no metamethod runs on a caller's word. Used for what
-- a server script hands an export (the hit request); wire-decoded frames and messages cannot carry one.
local getmetatable = getmetatable
local function plain(value)
    return type(value) == "table" and (getmetatable == nil or getmetatable(value) == nil)
end

local XYZ, XYZW = set("x", "y", "z"), set("x", "y", "z", "w")
local COLOR = set("r", "g", "b", "a")
local POSE = set("x", "y", "z", "yaw")

function T.isId(value)
    return type(value) == "string" and #value >= 1 and #value <= 16 and value:find("^[1-9]%d*$") ~= nil
end

local function fxId(value)
    return type(value) == "string" and #value >= 1 and #value <= L.fxId and value:find("^[%w_:.%-]+$") ~= nil
end

local function point(value)
    if type(value) ~= "table" or not keysOnly(value, XYZ) then return nil end
    local x, y, z, c = value.x, value.y, value.z, L.coordinate
    if not (finite(x) and finite(y) and finite(z)) or math.abs(x) > c or math.abs(y) > c or math.abs(z) > c then
        return nil
    end
    return { x = x, y = y, z = z }
end

local function rotation(value)
    if type(value) ~= "table" or not keysOnly(value, XYZW) then return nil end
    local x, y, z, w, r = value.x, value.y, value.z, value.w, L.rotation
    if not (finite(x) and finite(y) and finite(z)) or math.abs(x) > r or math.abs(y) > r or math.abs(z) > r then
        return nil
    end
    if w == nil then return { x = x, y = y, z = z } end
    if not finite(w) or math.abs(w) > r then return nil end
    return { x = x, y = y, z = z, w = w }
end

-- Packed 0xAARRGGBB-style integer, or {r,g,b,a?} in 0..255.
local function color(value)
    if type(value) == "number" then return whole(value, 0, 4294967295) end
    if type(value) ~= "table" or not keysOnly(value, COLOR) then return nil end
    local out = {}
    for _, key in ipairs({ "r", "g", "b" }) do
        local channel = value[key]
        if not finite(channel) or channel < 0 or channel > 255 then return nil end
        out[key] = channel
    end
    if value.a ~= nil then
        if not finite(value.a) or value.a < 0 or value.a > 255 then return nil end
        out.a = value.a
    end
    return out
end

local function optionalPoint(raw, key, out, reason)
    if raw[key] == nil then return nil end
    local value = point(raw[key])
    if not value then return reason end
    out[key] = value
end

-- ---------------------------------------------------------------------------
-- Event and visual kinds. Each `build(raw, catalog, out)` fills `out` or returns
-- the reason token. `keys` is the exact allowed key set: nothing else survives.
-- ---------------------------------------------------------------------------
local function fxFields(raw, catalog, out)
    if not fxId(raw.fxId) then return "fx_id" end
    if type(raw.path) ~= "string" or catalog.effects[raw.path] ~= true then return "fx_path" end
    local position = point(raw.position)
    if not position then return "fx_position" end
    out.fxId, out.path, out.position = raw.fxId, raw.path, position
    if raw.rotation ~= nil then
        out.rotation = rotation(raw.rotation)
        if not out.rotation then return "fx_rotation" end
    end
    local reason = optionalPoint(raw, "target", out, "fx_target")
    if reason then return reason end
    if raw.loop ~= nil then
        if type(raw.loop) ~= "boolean" then return "fx_loop" end
        out.loop = raw.loop
    end
end

local function attachedFields(raw, catalog, out)
    if type(raw.name) ~= "string" or catalog.attachedEffects[raw.name] ~= true then return "attached_name" end
    out.name = raw.name
end

local function soundFields(raw, catalog, out)
    if type(raw.name) ~= "string" or catalog.sounds[raw.name] ~= true then return "sound_name" end
    if raw.backend ~= "native" and raw.backend ~= "audioxl" then return "sound_backend" end
    out.name, out.backend = raw.name, raw.backend
    local reason = optionalPoint(raw, "position", out, "sound_position")
    if reason then return reason end
    if raw.gain ~= nil then
        if not finite(raw.gain) or raw.gain < 0 or raw.gain > L.gain then return "sound_gain" end
        out.gain = raw.gain
    end
end

local TRACER_MARKS = { none = true, hit = true, person = true }

local function tracerFields(raw, _, out)
    local from, to = point(raw.from), point(raw.to)
    if not from or not to then return "tracer_points" end
    if not finite(raw.life) or raw.life <= 0 or raw.life > L.tracerLife then return "tracer_life" end
    out.from, out.to, out.life = from, to, raw.life
    if raw.color ~= nil then
        out.color = color(raw.color)
        if out.color == nil then return "tracer_color" end
    end
    if raw.width ~= nil then
        if not finite(raw.width) or raw.width <= 0 or raw.width > L.tracerWidth then return "tracer_width" end
        out.width = raw.width
    end
    if raw.mark ~= nil then
        if type(raw.mark) ~= "string" or TRACER_MARKS[raw.mark] ~= true then return "tracer_mark" end
        out.mark = raw.mark
    end
end

local EVENT_KINDS = {
    fx_spawn = { keys = set("kind", "seq", "fxId", "path", "position", "rotation", "target", "loop"), build = fxFields },
    fx_move = {
        keys = set("kind", "seq", "fxId", "position", "rotation", "target", "slot"),
        build = function(raw, catalog, out)
            if not fxId(raw.fxId) then return "fx_id" end
            out.fxId = raw.fxId
            local reason = optionalPoint(raw, "position", out, "fx_position")
            if reason then return reason end
            if raw.rotation ~= nil then
                out.rotation = rotation(raw.rotation)
                if not out.rotation then return "fx_rotation" end
            end
            reason = optionalPoint(raw, "target", out, "fx_target")
            if reason then return reason end
            if raw.slot ~= nil then
                -- The catalog's optional `slots` dictionary: BT entity slot names.
                local slots = catalog.slots
                if type(raw.slot) ~= "string" or type(slots) ~= "table" or slots[raw.slot] ~= true then
                    return "fx_slot"
                end
                out.slot = raw.slot
            end
            if out.position == nil and out.rotation == nil and out.target == nil and out.slot == nil then
                return "fx_move_empty"
            end
        end,
    },
    fx_stop = {
        keys = set("kind", "seq", "fxId"),
        build = function(raw, _, out)
            if not fxId(raw.fxId) then return "fx_id" end
            out.fxId = raw.fxId
        end,
    },
    attached_fx = {
        keys = set("kind", "seq", "name", "action"),
        build = function(raw, catalog, out)
            local reason = attachedFields(raw, catalog, out)
            if reason then return reason end
            if raw.action ~= "start" and raw.action ~= "stop" and raw.action ~= "break" then return "attached_action" end
            out.action = raw.action
        end,
    },
    sound = { keys = set("kind", "seq", "name", "backend", "position", "gain"), build = soundFields },
    sound_stop = {
        keys = set("kind", "seq", "name"),
        build = function(raw, catalog, out)
            if type(raw.name) ~= "string" or catalog.sounds[raw.name] ~= true then return "sound_name" end
            out.name = raw.name
        end,
    },
    tracer = { keys = set("kind", "seq", "from", "to", "life", "color", "width", "mark"), build = tracerFields },
}

-- Persistent late-join state: what is still going on, no sequence. The same
-- field validation as the matching event.
local VISUAL_KINDS = {
    fx = { keys = set("kind", "fxId", "path", "position", "rotation", "target", "loop"), build = fxFields },
    attached = { keys = set("kind", "name"), build = attachedFields },
    sound = { keys = set("kind", "name", "backend", "position", "gain"), build = soundFields },
    tracer = { keys = set("kind", "from", "to", "life", "color", "width", "mark"), build = tracerFields },
}

local function item(raw, kinds, catalog, withSequence)
    if type(raw) ~= "table" then return nil, "item_invalid" end
    local spec = type(raw.kind) == "string" and kinds[raw.kind] or nil
    if not spec then return nil, "item_kind" end
    if not keysOnly(raw, spec.keys) then return nil, "item_keys" end
    local out = { kind = raw.kind }
    if withSequence then
        out.seq = whole(raw.seq, 1, L.integer)
        if not out.seq then return nil, "event_seq" end
    end
    local reason = spec.build(raw, catalog, out)
    if reason then return nil, reason end
    return out
end

-- A Lua sequence of exactly 1..n, at most `maximum` long.
local function sequence(raw, maximum)
    if type(raw) ~= "table" then return nil end
    local count = 0
    for _ in pairs(raw) do
        count = count + 1
        if count > maximum then return nil end
    end
    for index = 1, count do
        if raw[index] == nil then return nil end
    end
    return count
end

local function dictionary(raw, names, maximum, check, reason)
    if type(raw) ~= "table" then return nil, reason end
    local out, count = {}, 0
    for name, value in pairs(raw) do
        count = count + 1
        if count > maximum then return nil, reason .. "_count" end
        if type(name) ~= "string" or names[name] ~= true then return nil, reason .. "_unknown" end
        local clean = check(value)
        if clean == nil then return nil, reason .. "_value" end
        out[name] = clean
    end
    return out
end

local function variableValue(value)
    if finite(value) and math.abs(value) <= L.variable then return value end
end
local function boolean(value)
    if type(value) == "boolean" then return value end
end

-- Keyed node count, the measure the client's encoders apply: a value is one node
-- and every table entry costs one more for its key (array indices included).
local function countNodes(value)
    if type(value) ~= "table" then return 1 end
    local nodes = 1
    for _, child in pairs(value) do nodes = nodes + 1 + countNodes(child) end
    return nodes
end
T.countNodes = countNodes

function T.checkCatalog(catalog)
    if type(catalog) ~= "table" then return false, "catalog_missing" end
    for _, name in ipairs({ "variables", "meshes", "lights", "effects", "attachedEffects", "sounds" }) do
        if type(catalog[name]) ~= "table" then return false, "catalog_" .. name end
    end
    return true
end

-- ---------------------------------------------------------------------------
-- The owner's gameplay report (frame.gameplay): what its controller says of the Titan's own hull, shield, ammunition,
-- core and abilities, once per published frame. A fixed, bounded, optional schema that the controller's bridge
-- (open77_titan_schema.lua, S.gameplay) mirrors key for key: a substate the controller has nothing to say about is
-- ABSENT, never a zero. It is the owner's word, not the server's: the server records the last accepted copy and invents
-- nothing around it.
--   health     { current, max, shield?, shieldMax?, doomed?, doomedMax?, dead }  hull / shield / doomed pools, dead = real boolean
--   ammo       { current, capacity, reloading }   whole numbers and a boolean; only while piloting a gun with a magazine
--   core       { charge, max, active }
--   abilities  { jump | dash | missiles | vortex | smoke | flight | sentry = { active, remaining?, cooldown? } }
--   paused     boolean; pauseReason is the controller's own short text while it is paused
-- ---------------------------------------------------------------------------
local GAMEPLAY_KEYS = set("health", "ammo", "core", "abilities", "paused", "pauseReason")
local HEALTH_KEYS = set("current", "max", "shield", "shieldMax", "doomed", "doomedMax", "dead")
local HEALTH_FIGURES = { "current", "max", "shield", "shieldMax", "doomed", "doomedMax" }
local AMMO_KEYS = set("current", "capacity", "reloading")
local CORE_KEYS = set("charge", "max", "active")
T.abilities = set("jump", "dash", "missiles", "vortex", "smoke", "flight", "sentry")
local ABILITY_KEYS = set("active", "remaining", "cooldown")

-- One reported figure: finite and within +/-gameplayValue, and not below `minimum`.
local function figure(value, minimum)
    if finite(value) and value >= minimum and math.abs(value) <= L.gameplayValue then return value end
end

-- Printable ASCII only, so that nothing but plain text ever reaches a server script or its log.
local function printable(value, minimum, maximum)
    return type(value) == "string" and #value >= minimum and #value <= maximum and value:find("^[ -~]*$") ~= nil
end

local function gameplayHealth(raw)
    if type(raw) ~= "table" or not keysOnly(raw, HEALTH_KEYS) or type(raw.dead) ~= "boolean" then return nil end
    local out = { dead = raw.dead }
    for _, key in ipairs(HEALTH_FIGURES) do
        local value = raw[key]
        if value ~= nil then
            out[key] = figure(value, -L.gameplayValue)
            if out[key] == nil then return nil end
        end
    end
    if out.current == nil or out.max == nil then return nil end
    return out
end

local function gameplayAmmo(raw)
    if type(raw) ~= "table" or not keysOnly(raw, AMMO_KEYS) or type(raw.reloading) ~= "boolean" then return nil end
    local current, capacity = whole(raw.current, 0, L.gameplayValue), whole(raw.capacity, 1, L.gameplayValue)
    if not current or not capacity then return nil end
    return { current = current, capacity = capacity, reloading = raw.reloading }
end

local function gameplayCore(raw)
    if type(raw) ~= "table" or not keysOnly(raw, CORE_KEYS) or type(raw.active) ~= "boolean" then return nil end
    local charge, max = figure(raw.charge, 0), figure(raw.max, 0)
    if charge == nil or max == nil or max <= 0 then return nil end
    return { charge = charge, max = max, active = raw.active }
end

local function gameplayAbilities(raw)
    if type(raw) ~= "table" then return nil end
    local out = {}
    for name, value in pairs(raw) do
        if type(name) ~= "string" or T.abilities[name] ~= true or type(value) ~= "table"
            or not keysOnly(value, ABILITY_KEYS) or type(value.active) ~= "boolean" then
            return nil
        end
        local clean = { active = value.active }
        for _, key in ipairs({ "remaining", "cooldown" }) do
            if value[key] ~= nil then
                clean[key] = figure(value[key], 0)
                if clean[key] == nil then return nil end
            end
        end
        out[name] = clean
    end
    return out
end

-- Returns a COPY holding only the known keys, or nil plus a reason token. Every key is optional but `paused`.
function T.normalizeGameplay(raw)
    if type(raw) ~= "table" or not keysOnly(raw, GAMEPLAY_KEYS) then return nil, "gameplay_keys" end
    if type(raw.paused) ~= "boolean" then return nil, "gameplay_paused" end
    local out = { paused = raw.paused }
    if raw.health ~= nil then
        out.health = gameplayHealth(raw.health)
        if not out.health then return nil, "gameplay_health" end
    end
    if raw.ammo ~= nil then
        out.ammo = gameplayAmmo(raw.ammo)
        if not out.ammo then return nil, "gameplay_ammo" end
    end
    if raw.core ~= nil then
        out.core = gameplayCore(raw.core)
        if not out.core then return nil, "gameplay_core" end
    end
    if raw.abilities ~= nil then
        out.abilities = gameplayAbilities(raw.abilities)
        if not out.abilities then return nil, "gameplay_abilities" end
    end
    if raw.pauseReason ~= nil then
        if not printable(raw.pauseReason, 1, L.gameplayText) then return nil, "gameplay_text" end
        out.pauseReason = raw.pauseReason
    end
    return out
end

local FRAME_KEYS = set("v", "op", "id", "epoch", "seq", "t", "pose", "mode", "weapon", "vars", "meshes", "lights",
    "visuals", "events")
-- Only the owner's controller reports gameplay: a relayed state never carries it.
local FRAME_EXTRA = set("gameplay")

-- FRAME_KEYS plus one extra set, merged once per set (the sets are this file's own constants). No metatable: the
-- client resource host removes setmetatable.
local mergedKeys = {}
local function allowedKeys(extra)
    if extra == nil then return FRAME_KEYS end
    local allowed = mergedKeys[extra]
    if not allowed then
        allowed = {}
        for key in pairs(FRAME_KEYS) do allowed[key] = true end
        for key in pairs(extra) do allowed[key] = true end
        mergedKeys[extra] = allowed
    end
    return allowed
end

-- Validates one frame/state body. Returns the sanitized frame, or nil plus a
-- reason token. The third and fourth results report how many visuals/events
-- were dropped individually (and the first reason): a bad event never costs the
-- motion in the same frame, but it is never relayed and the owner is told.
local function snapshot(raw, catalog, op, extra)
    if type(raw) ~= "table" then return nil, "frame_invalid" end
    if not keysOnly(raw, allowedKeys(extra)) then return nil, "frame_keys" end
    if raw.v ~= T.protocol or raw.op ~= op then return nil, "frame_op" end
    if not T.isId(raw.id) then return nil, "frame_id" end
    local epoch = whole(raw.epoch, 1, L.integer)
    if not epoch then return nil, "frame_epoch" end
    local seq = whole(raw.seq, 1, L.integer)
    if not seq then return nil, "frame_seq" end
    if not finite(raw.t) or raw.t < 0 or raw.t > L.time then return nil, "frame_time" end
    local pose = raw.pose
    if type(pose) ~= "table" or not keysOnly(pose, POSE) then return nil, "pose_invalid" end
    local at = point({ x = pose.x, y = pose.y, z = pose.z })
    if not at or not finite(pose.yaw) or math.abs(pose.yaw) > L.yaw then return nil, "pose_invalid" end
    if type(raw.mode) ~= "string" or T.modes[raw.mode] ~= true then return nil, "frame_mode" end
    if type(raw.weapon) ~= "string" or T.weapons[raw.weapon] ~= true then return nil, "frame_weapon" end

    local vars, why = dictionary(raw.vars, catalog.variables, L.variables, variableValue, "vars")
    if not vars then return nil, why end
    local meshes
    meshes, why = dictionary(raw.meshes, catalog.meshes, L.meshes, boolean, "meshes")
    if not meshes then return nil, why end
    local lights
    lights, why = dictionary(raw.lights, catalog.lights, L.lights, boolean, "lights")
    if not lights then return nil, why end
    local gameplay
    if raw.gameplay ~= nil then
        gameplay, why = T.normalizeGameplay(raw.gameplay)
        if not gameplay then return nil, why end
    end

    local visualCount = sequence(raw.visuals, L.visuals)
    if not visualCount then return nil, "visuals_count" end
    local eventCount = sequence(raw.events, L.events)
    if not eventCount then return nil, "events_count" end

    local dropped, firstDrop = 0, nil
    local visuals, events = {}, {}
    for index = 1, visualCount do
        local clean, reason = item(raw.visuals[index], VISUAL_KINDS, catalog, false)
        if clean then visuals[#visuals + 1] = clean
        else dropped, firstDrop = dropped + 1, firstDrop or reason end
    end
    local previous = 0
    for index = 1, eventCount do
        local clean, reason = item(raw.events[index], EVENT_KINDS, catalog, true)
        if clean and clean.seq <= previous then clean, reason = nil, "event_order" end
        if clean then
            previous = clean.seq
            events[#events + 1] = clean
        else
            dropped, firstDrop = dropped + 1, firstDrop or reason
        end
    end

    local frame = {
        id = raw.id, epoch = epoch, seq = seq, t = raw.t,
        pose = { x = at.x, y = at.y, z = at.z, yaw = pose.yaw },
        mode = raw.mode, weapon = raw.weapon,
        vars = vars, meshes = meshes, lights = lights, visuals = {}, events = {}, gameplay = gameplay,
    }
    local used = countNodes(frame)
    if used > L.nodes then return nil, "frame_nodes" end
    -- Past the keyed cap the TAIL is shed, never the motion: persistent visuals
    -- first, then the newest events. A frame refused whole would starve the Titan
    -- until the stall watchdog fires; a shed event is reported (`frame_nodes`) and
    -- its sequence is not consumed, so nothing ever skips past an undelivered one.
    local visualCost, eventCost = {}, {}
    for index, clean in ipairs(visuals) do
        visualCost[index] = 1 + countNodes(clean)
        used = used + visualCost[index]
    end
    for index, clean in ipairs(events) do
        eventCost[index] = 1 + countNodes(clean)
        used = used + eventCost[index]
    end
    while used > L.nodes do
        local last = #visuals
        if last > 0 then
            used, visuals[last] = used - visualCost[last], nil
        else
            last = #events
            used, events[last] = used - eventCost[last], nil
        end
        dropped, firstDrop = dropped + 1, firstDrop or "frame_nodes"
    end
    frame.visuals, frame.events = visuals, events
    return frame, nil, dropped, firstDrop
end

-- Controller -> server frame: {v=2, op='frame', id, epoch, seq, t, pose, ...}.
function T.normalizeFrame(raw, catalog)
    return snapshot(raw, catalog, "frame", FRAME_EXTRA)
end

local STATE_EXTRA = set("owner", "serverTime")
local GRANT_KEYS = set("v", "op", "id", "epoch", "owner", "revision", "loadout", "piloted", "hold")
local LOADOUT_KEYS = set("v", "op", "id", "epoch", "revision", "loadout")

local function reasonToken(value)
    return type(value) == "string" and #value <= 64 and value:find("^[a-z_]+:?[a-z_]*$") ~= nil
end

-- ---------------------------------------------------------------------------
-- Physical carry: the Titan's fist grabs a canonical NPC or vehicle, holds it in
-- its hand and throws it. The controller never names an engine body on the
-- network: it hands the client resource the NATIVE entity text (`entity`, exact
-- unsigned decimal, never a float) and the client resolves it to the canonical
-- id it already replicates; only that canonical id (`entityId`) is ever sent to
-- the server, and the grant carries an opaque token that every later sample must
-- present.
-- ---------------------------------------------------------------------------
T.carryKinds = set("npc", "vehicle")
T.carryPhases = set("hold", "flight")
-- What the controller may report when it lets go of a body (its own vocabulary).
T.carryReleaseReasons = set("landed", "flight_timeout", "interrupted", "titan_gone", "session_end", "unmatched",
    "refused", "lost", "unobserved", "stalled", "timeout", "clipped")
-- Every code a denial or an end can carry. A fixed vocabulary: the server maps
-- whatever the platform answers into it (anything unknown becomes 'refused'), so
-- neither a platform string nor free text ever reaches the controller.
T.carryReasons = set(
    -- resolved on the client, before anything is asked of the server
    "not_networked", "entity_unresolved", "body_not_ready",
    -- refused by the server
    "stale_titan", "not_active", "not_fist", "titan_busy", "stale_request", "rate_limited", "already_carrying",
    "owner_unavailable", "bucket_mismatch", "target_missing", "target_dead", "target_far", "target_claimed",
    "target_busy", "unavailable", "refused",
    -- ends the server (or the platform) decides
    "carrier_dead", "carrier_left", "bucket_changed", "resource_stopped", "titan_removed", "titan_stalled",
    "claim_stalled", "claim_expired", "flight_expired", "pose_rejected", "entity_removed", "entity_died", "claim_lost"
)
-- An end the controller itself asked for is echoed back with its own reason.
for reason in pairs(T.carryReleaseReasons) do T.carryReasons[reason] = true end

local MAX_NATIVE_ID = "18446744073709551615"

-- A REDengine entity id: the exact unsigned 64-bit decimal text. Kept as text from
-- the controller to the client's lookup; no number conversion ever touches it.
function T.isNativeId(value)
    if type(value) ~= "string" or #value < 1 or #value > 20 or value:find("^[1-9]%d*$") == nil then return false end
    return #value < 20 or value <= MAX_NATIVE_ID
end

-- The platform's claim token: opaque, short, printable.
function T.isToken(value)
    return type(value) == "string" and #value >= 1 and #value <= 64 and value:find("^[%w_:.%-]+$") ~= nil
end

local CARRY_POSE = set("x", "y", "z", "yaw", "qx", "qy", "qz", "qw", "vx", "vy", "vz", "phase")

-- One authored sample of the held body. Returns a COPY with the quaternion
-- renormalized (a unit rotation is what the platform takes), or nil plus a reason.
function T.normalizeCarryPose(raw)
    if type(raw) ~= "table" or not keysOnly(raw, CARRY_POSE) then return nil, "carry_pose" end
    local at = point({ x = raw.x, y = raw.y, z = raw.z })
    if not at or not finite(raw.yaw) or math.abs(raw.yaw) > L.yaw then return nil, "carry_pose" end
    local qx, qy, qz, qw = raw.qx, raw.qy, raw.qz, raw.qw
    if not (finite(qx) and finite(qy) and finite(qz) and finite(qw)) then return nil, "carry_rotation" end
    local norm = qx * qx + qy * qy + qz * qz + qw * qw
    if not (math.abs(norm - 1) <= L.carryNormal) then return nil, "carry_rotation" end
    local vx, vy, vz = raw.vx, raw.vy, raw.vz
    if not (finite(vx) and finite(vy) and finite(vz)) then return nil, "carry_velocity" end
    if not (vx * vx + vy * vy + vz * vz <= L.carryVelocity * L.carryVelocity) then return nil, "carry_velocity" end
    if type(raw.phase) ~= "string" or T.carryPhases[raw.phase] ~= true then return nil, "carry_phase" end
    local scale = 1 / math.sqrt(norm)
    return {
        x = at.x, y = at.y, z = at.z, yaw = raw.yaw,
        qx = qx * scale, qy = qy * scale, qz = qz * scale, qw = qw * scale,
        vx = vx, vy = vy, vz = vz, phase = raw.phase,
    }
end

local CARRY_LAUNCH_FIELDS = { "t", "x", "y", "z", "yaw", "px", "py", "pz", "ix", "iy", "iz", "radius", "delay" }
local CARRY_LAUNCH = {}
for _, key in ipairs(CARRY_LAUNCH_FIELDS) do CARRY_LAUNCH[key] = true end
local CARRY_LAUNCH_POINTS = { "x", "y", "z", "px", "py", "pz" }
local CARRY_LAUNCH_IMPULSE = { "ix", "iy", "iz" }

-- The release of a thrown person: the controller clock `t` of its authored push, the released body's ROOT pose
-- (`x y z yaw`), and the point (`px py pz`), impulse (`ix iy iz`), `radius` and `delay` of that push. Every field is
-- required, finite and bounded, the impulse is not zero and its point is near the root. Returns a COPY, or nil plus a
-- reason.
function T.normalizeCarryLaunch(raw)
    if type(raw) ~= "table" or not keysOnly(raw, CARRY_LAUNCH) then return nil, "carry_launch" end
    local out = {}
    for _, key in ipairs(CARRY_LAUNCH_FIELDS) do
        local value = raw[key]
        if not finite(value) then return nil, "carry_launch" end
        out[key] = value
    end
    if out.t < 0 or out.t > L.time then return nil, "carry_launch_time" end
    for _, key in ipairs(CARRY_LAUNCH_POINTS) do
        if math.abs(out[key]) > L.coordinate then return nil, "carry_launch_point" end
    end
    if math.abs(out.yaw) > L.yaw then return nil, "carry_launch_yaw" end
    for _, key in ipairs(CARRY_LAUNCH_IMPULSE) do
        if math.abs(out[key]) > L.carryLaunchImpulse then return nil, "carry_launch_impulse" end
    end
    if out.ix == 0 and out.iy == 0 and out.iz == 0 then return nil, "carry_launch_impulse" end
    if not (out.radius > 0 and out.radius <= L.carryLaunchRadius) then return nil, "carry_launch_radius" end
    if out.delay < 0 or out.delay > L.carryLaunchDelay then return nil, "carry_launch_delay" end
    local dx, dy, dz = out.px - out.x, out.py - out.y, out.pz - out.z
    if dx * dx + dy * dy + dz * dz > L.carryLaunchPoint * L.carryLaunchPoint then return nil, "carry_launch_point" end
    return out
end

local CARRY_REQUEST_KEYS = {
    controller = set("v", "op", "id", "epoch", "request", "kind", "entity"),
    server = set("v", "op", "id", "epoch", "request", "kind", "entityId"),
}
local CARRY_FRAME_KEYS = set("v", "op", "id", "epoch", "token", "seq", "t", "pose", "launch")
local CARRY_RELEASE_KEYS = set("v", "op", "id", "epoch", "token", "seq", "t", "pose", "reason", "launch")

local function carryHeader(raw, op, keys, out)
    if not keysOnly(raw, keys) then return "message_keys" end
    if raw.v ~= T.protocol or raw.op ~= op then return "message_op" end
    local epoch = whole(raw.epoch, 1, L.integer)
    if not T.isId(raw.id) or not epoch then return "carry_id" end
    out.v, out.op, out.id, out.epoch = T.protocol, op, raw.id, epoch
end

-- `side` is 'controller' (controller -> client resource: the request names the NATIVE
-- entity text) or 'server' (client resource -> server: the request names only the
-- canonical id, so a native id is a schema violation there, not a field to ignore).
local function normalizeCarry(raw, side)
    if type(raw) ~= "table" then return nil, "message_invalid" end
    local op, out, reason = raw.op, {}, nil
    if op == "carry_request" then
        reason = carryHeader(raw, op, CARRY_REQUEST_KEYS[side], out)
        if reason then return nil, reason end
        out.request = whole(raw.request, 1, L.integer)
        if not out.request then return nil, "carry_request" end
        if type(raw.kind) ~= "string" or T.carryKinds[raw.kind] ~= true then return nil, "carry_kind" end
        out.kind = raw.kind
        if side == "controller" then
            if not T.isNativeId(raw.entity) then return nil, "carry_entity" end
            out.entity = raw.entity
        else
            if not T.isId(raw.entityId) then return nil, "carry_entity" end
            out.entityId = raw.entityId
        end
        return out
    elseif op == "carry_frame" or op == "carry_release" then
        reason = carryHeader(raw, op, op == "carry_frame" and CARRY_FRAME_KEYS or CARRY_RELEASE_KEYS, out)
        if reason then return nil, reason end
        if not T.isToken(raw.token) then return nil, "carry_token" end
        out.token = raw.token
        out.seq = whole(raw.seq, 1, L.integer)
        if not out.seq then return nil, "carry_seq" end
        if not finite(raw.t) or raw.t < 0 or raw.t > L.time then return nil, "carry_time" end
        out.t = raw.t
        out.pose, reason = T.normalizeCarryPose(raw.pose)
        if not out.pose then return nil, reason end
        -- Only a thrown person's flight carries its release (the kind of body is the server's to check): the release
        -- cannot be later than the message that repeats it.
        if raw.launch ~= nil then
            out.launch, reason = T.normalizeCarryLaunch(raw.launch)
            if not out.launch then return nil, reason end
            if out.pose.phase ~= "flight" then return nil, "carry_launch_phase" end
            if out.launch.t > out.t then return nil, "carry_launch_time" end
        end
        if op == "carry_release" then
            if type(raw.reason) ~= "string" or T.carryReleaseReasons[raw.reason] ~= true then return nil, "carry_reason" end
            out.reason = raw.reason
        end
        return out
    end
    return nil, "message_op"
end

-- Controller -> client resource: carry_request (native `entity` text), carry_frame, carry_release.
function T.normalizeControllerCarry(raw) return normalizeCarry(raw, "controller") end
-- Client resource -> server: the same, with the canonical `entityId` in the request.
function T.normalizeServerCarry(raw) return normalizeCarry(raw, "server") end

-- A control of the server's `input` export: `name` from T.inputs (case-sensitive), `value` of its kind: a finite number
-- within +/-1 (axis) or +/-20000 (relative), or exactly true / false (button, key). Returns name, kind, value, or nil
-- plus input_name / input_value; nothing else is read from either argument.
function T.normalizeInput(name, value)
    if type(name) ~= "string" then return nil, "input_name" end
    local kind = T.inputs[name]
    if kind == nil then return nil, "input_name" end
    local limit = T.inputLimits[kind]
    if limit ~= nil then
        if not finite(value) or value < -limit or value > limit then return nil, "input_value" end
    elseif type(value) ~= "boolean" then
        return nil, "input_value"
    end
    return name, kind, value
end

-- ---------------------------------------------------------------------------
-- Gameplay requests: a server script's `hit` and `repair` exports reach the owner's controller as scoped messages, and
-- the controller answers each exactly once with a `gameplay_result`. Exact keys, bounded text, finite numbers: nothing a
-- caller or the client supplies is ever resolved, executed or forwarded as it came.
--   hit     record   a TweakDB record name (letters, digits, '_' and '.', at most actionRecord characters)
--           origin   { x, y, z } within the world bound; direction { x, y, z } within -1..1 and not the zero vector
--           attacker plain text of at most actionAttacker printable characters (attribution only; default "")
--           kind     ranged | melee | blast;  scale  finite, above 0 and at most actionScale (default 1)
--   repair  amount   finite, above 0 and at most actionAmount
-- ---------------------------------------------------------------------------
T.hitKinds = set("ranged", "melee", "blast")
T.resultKinds = set("hit", "repair", "core_credit")
local HIT_FIELDS = set("record", "origin", "direction", "attacker", "kind", "scale")
local RESULT_KEYS = set("v", "op", "id", "epoch", "request", "kind", "ok", "reason", "amount")

-- A TweakDB record name: letters, digits, '_' and '.', at most actionRecord characters. A hit's record, a status effect and a
-- core credit's record are all this one shape.
local function recordName(value)
    return type(value) == "string" and #value >= 1 and #value <= L.actionRecord and value:find("^[%w_.]+$") ~= nil
end
T.isRecordName = recordName

local function heading(value)
    if not plain(value) or not keysOnly(value, XYZ) then return nil end
    local x, y, z = value.x, value.y, value.z
    if not (finite(x) and finite(y) and finite(z)) or math.abs(x) > 1 or math.abs(y) > 1 or math.abs(z) > 1 then
        return nil
    end
    if x == 0 and y == 0 and z == 0 then return nil end
    return { x = x, y = y, z = z }
end

-- The six fields of a hit (keys already checked by the caller). Returns a COPY with every field present, or nil plus a token.
local function hitFields(raw)
    local record = raw.record
    if not recordName(record) then
        return nil, "hit_record"
    end
    local origin = plain(raw.origin) and point(raw.origin) or nil
    if not origin then return nil, "hit_origin" end
    local direction = heading(raw.direction)
    if not direction then return nil, "hit_direction" end
    local attacker = raw.attacker
    if attacker == nil then attacker = "" end
    if not printable(attacker, 0, L.actionAttacker) then return nil, "hit_attacker" end
    if type(raw.kind) ~= "string" or T.hitKinds[raw.kind] ~= true then return nil, "hit_kind" end
    local scale = raw.scale
    if scale == nil then scale = 1 end
    if not finite(scale) or scale <= 0 or scale > L.actionScale then return nil, "hit_scale" end
    return { record = record, origin = origin, direction = direction, attacker = attacker, kind = raw.kind, scale = scale }
end

-- The `request` argument of the server's `hit` export. Returns a copy, or nil plus hit_keys / hit_record / hit_origin /
-- hit_direction / hit_attacker / hit_kind / hit_scale.
function T.normalizeHit(raw)
    if not plain(raw) or not keysOnly(raw, HIT_FIELDS) then return nil, "hit_keys" end
    return hitFields(raw)
end

-- ---------------------------------------------------------------------------
-- Observed hits, the other way round: the owner's controller saw ITS Titan land a blow on ANOTHER player's Titan (a body it
-- renders from relayed states; nothing is applied there) and says so, controller -> client resource -> server, as
--   { v, op = 'hit_observed', id, epoch, seq, target = { kind = 'titan', id, epoch, owner }, record, origin, point,
--     direction, kind = ranged | melee | blast, scale }
-- `id` / `epoch` name the SOURCE (the sender's own Titan); `seq` grows by one per delivered report of that grant; `target` is
-- the canonical identity of the Titan the controller saw hit (ids are text, `owner` the text of the player number); `record`,
-- `origin` (where the blow came from), `direction`, `kind` and `scale` are exactly the fields of a hit (above), and `point`
-- is where it landed (a world point within the same bound). Exact keys, nothing else survives. It is the owner's word, an
-- observation and not a measurement: the server only forwards it (server.lua) and a mission decides what it is worth.
-- Returns a COPY, or nil plus a token: observed_keys / observed_op / observed_source / observed_seq / observed_target /
-- hit_record / hit_origin / hit_direction / hit_kind / hit_scale / hit_point.
--
-- Observed status effects are the same observation of a status effect the controller's Titan applied to another player's Titan
-- (its own fire, shock, stun, blind, ...: authored attempts the controller would make on a person):
--   { v, op = 'status_observed', id, epoch, seq, target = { kind = 'titan', id, epoch, owner }, effect, duration? }
-- `id`, `epoch`, `seq` and `target` are the observation's own (above, one sequence per grant shared with the hits); `effect` is
-- the authored TweakDB status record, a record name exactly as a hit's; `duration` is present only when the controller's own
-- call supplied one, in seconds, finite and from 0 to limits.time: none is ever invented for a call that had none. Exact
-- keys. Nothing is applied: a mission reads the event and decides. Returns a COPY, or nil plus a token: observed_keys /
-- observed_op / observed_source / observed_seq / observed_target / status_effect / status_duration.
--
-- Blows on cars are the third observation, of what the controller's weapons landed on a canonical vehicle (a car; the
-- controller's own FPF.wreck, and the blast of a car it blew up, reported instead of taken off the car locally):
--   { v, op = 'vehicle_hit', id, epoch, seq, vehicle, share, point }
-- `id`, `epoch` and `seq` are the observation's own (above, one sequence per grant shared with the other two); `vehicle` is the
-- car's canonical id (text, as a carry's `entityId`); `share` is what the controller took off it since its last report, in
-- percent of the car's full health (finite, above 0 and at most limits.vehicleShare: a lethal blow is 100); `point` is where the
-- car was (a world point within the same bound). Exact keys. Unlike the two above this one is acted on: the server applies it to
-- the car once no script vetoes it (server.lua "Blows on cars"). Returns a COPY, or nil plus a token: observed_keys / observed_op /
-- observed_source / observed_seq / vehicle_id / vehicle_share / hit_point.
-- ---------------------------------------------------------------------------
local OBSERVED_KEYS = set("v", "op", "id", "epoch", "seq", "target", "record", "origin", "point", "direction", "kind", "scale")
local STATUS_KEYS = set("v", "op", "id", "epoch", "seq", "target", "effect", "duration")
local VEHICLE_KEYS = set("v", "op", "id", "epoch", "seq", "vehicle", "share", "point")
local PLAYER_KEYS = set("v", "op", "id", "epoch", "seq", "player", "record", "count")
local NPC_KEYS = set("v", "op", "id", "epoch", "seq", "npc", "record", "kind", "point")
local OBSERVED_TARGET = set("kind", "id", "epoch", "owner")

-- The source of every observation: the sender's own Titan (`id`, `epoch`) and the sender's count (`seq`). Returns a COPY
-- { id, epoch, seq } or nil plus observed_source / observed_seq.
local function observedSource(raw)
    local epoch, seq = whole(raw.epoch, 1, L.integer), whole(raw.seq, 1, L.integer)
    if not T.isId(raw.id) or not epoch then return nil, "observed_source" end
    if not seq then return nil, "observed_seq" end
    return { id = raw.id, epoch = epoch, seq = seq }
end

-- What the two observations of a Titan share: the source (above) and the canonical identity of the target. Returns a COPY
-- { id, epoch, seq, target } or nil plus observed_source / observed_seq / observed_target.
local function observedHeader(raw)
    local out, why = observedSource(raw)
    if not out then return nil, why end
    local target = raw.target
    if not plain(target) or not keysOnly(target, OBSERVED_TARGET) or target.kind ~= "titan" then
        return nil, "observed_target"
    end
    local targetEpoch = whole(target.epoch, 1, L.integer)
    if not T.isId(target.id) or not targetEpoch or not T.isId(target.owner) then return nil, "observed_target" end
    out.target = { kind = "titan", id = target.id, epoch = targetEpoch, owner = target.owner }
    return out
end

function T.normalizeHitObserved(raw)
    if not plain(raw) or not keysOnly(raw, OBSERVED_KEYS) then return nil, "observed_keys" end
    if raw.v ~= T.protocol or raw.op ~= "hit_observed" then return nil, "observed_op" end
    local out, why = observedHeader(raw)
    if not out then return nil, why end
    local hit, reason = hitFields(raw)
    if not hit then return nil, reason end
    local at = plain(raw.point) and point(raw.point) or nil
    if not at then return nil, "hit_point" end
    out.v, out.op = T.protocol, "hit_observed"
    out.record, out.origin, out.point, out.direction, out.kind, out.scale =
        hit.record, hit.origin, at, hit.direction, hit.kind, hit.scale
    return out
end

function T.normalizeStatusObserved(raw)
    if not plain(raw) or not keysOnly(raw, STATUS_KEYS) then return nil, "observed_keys" end
    if raw.v ~= T.protocol or raw.op ~= "status_observed" then return nil, "observed_op" end
    local out, why = observedHeader(raw)
    if not out then return nil, why end
    if not recordName(raw.effect) then return nil, "status_effect" end
    local duration = raw.duration
    if duration ~= nil and not (finite(duration) and duration >= 0 and duration <= L.time) then return nil, "status_duration" end
    out.v, out.op, out.effect, out.duration = T.protocol, "status_observed", raw.effect, duration
    return out
end

function T.normalizeVehicleHit(raw)
    if not plain(raw) or not keysOnly(raw, VEHICLE_KEYS) then return nil, "observed_keys" end
    if raw.v ~= T.protocol or raw.op ~= "vehicle_hit" then return nil, "observed_op" end
    local out, why = observedSource(raw)
    if not out then return nil, why end
    if not T.isId(raw.vehicle) then return nil, "vehicle_id" end
    local share = raw.share
    if not finite(share) or share <= 0 or share > L.vehicleShare then return nil, "vehicle_share" end
    local at = plain(raw.point) and point(raw.point) or nil
    if not at then return nil, "hit_point" end
    out.v, out.op, out.vehicle, out.share, out.point = T.protocol, "vehicle_hit", raw.vehicle, share, at
    return out
end

-- Blows on players are the fourth observation, of what the controller's weapons landed on another player's body:
--   { v, op = 'player_hit', id, epoch, seq, player, record, count }
-- `id`, `epoch` and `seq` are the observation's own (above); `player` is the victim's player id (text, as a carry's ids);
-- `record` is the authored TweakDB record of the blow (a record name exactly as a hit's); `count` is how many blows of that
-- record the bridge summed (a whole number from 1 to limits.playerHitCount). Acted on by the server, which prices the record
-- itself (server.lua "Blows on players"); the report carries no amount. Exact keys. Returns a COPY, or nil plus a token:
-- observed_keys / observed_op / observed_source / observed_seq / player_id / hit_record / player_count.
function T.normalizePlayerHit(raw)
    if not plain(raw) or not keysOnly(raw, PLAYER_KEYS) then return nil, "observed_keys" end
    if raw.v ~= T.protocol or raw.op ~= "player_hit" then return nil, "observed_op" end
    local out, why = observedSource(raw)
    if not out then return nil, why end
    if not T.isId(raw.player) then return nil, "player_id" end
    if not recordName(raw.record) then return nil, "hit_record" end
    local count = whole(raw.count, 1, L.playerHitCount)
    if not count then return nil, "player_count" end
    out.v, out.op, out.player, out.record, out.count = T.protocol, "player_hit", raw.player, raw.record, count
    return out
end

-- Blows on platform NPCs are the fifth observation, of what the controller's weapons landed on an NPC the platform owns (a
-- body Open77.npcs.all lists; the controller resolves its engine entity to the platform's id and never reports a player, a car,
-- its own Titan or another Titan's body):
--   { v, op = 'npc_hit', id, epoch, seq, npc, record, kind, point }
-- `id`, `epoch` and `seq` are the observation's own (above, one sequence per grant shared with the others); `npc` is the NPC's
-- platform id (text, as a carry's ids); `record` is the authored TweakDB record of the blow (a record name exactly as a hit's);
-- `kind` says what sort of blow it was, from the closed set T.npcKinds: round (a bullet, shell or bolt), blast (an explosion's
-- hit), melee (a fist), blade (the sword) or other; `point` is where it landed (a world point within the same bound). Exact keys.
-- The report carries no amount and the server never touches the NPC: it publishes the report as the host event onTitanNpcHit
-- (server.lua "Blows on NPCs") and the mission that owns the NPC validates and prices it. Returns a COPY, or nil plus a token:
-- observed_keys / observed_op / observed_source / observed_seq / npc_id / hit_record / npc_kind / hit_point.
T.npcKinds = set("round", "blast", "melee", "blade", "other")
function T.normalizeNpcHit(raw)
    if not plain(raw) or not keysOnly(raw, NPC_KEYS) then return nil, "observed_keys" end
    if raw.v ~= T.protocol or raw.op ~= "npc_hit" then return nil, "observed_op" end
    local out, why = observedSource(raw)
    if not out then return nil, why end
    if not T.isId(raw.npc) then return nil, "npc_id" end
    if not recordName(raw.record) then return nil, "hit_record" end
    if type(raw.kind) ~= "string" or T.npcKinds[raw.kind] ~= true then return nil, "npc_kind" end
    local at = plain(raw.point) and point(raw.point) or nil
    if not at then return nil, "hit_point" end
    out.v, out.op, out.npc, out.record, out.kind, out.point = T.protocol, "npc_hit", raw.npc, raw.record, raw.kind, at
    return out
end

-- The `amount` argument of the server's `repair` export. Returns it, or nil plus repair_amount.
function T.normalizeRepair(amount)
    if finite(amount) and amount > 0 and amount <= L.actionAmount then return amount end
    return nil, "repair_amount"
end

-- The mission's confirmed Titan-versus-Titan hit or kill, credited to the player's own Titan as authored BURST CORE charge
-- (the server's `creditCore` export). `target` is the canonical identity of the victim's Titan, an id (text) and an epoch;
-- the victim's Titan may be gone already, so the server never looks it up. `record` is the authored TweakDB record of the
-- blow that was confirmed, and `killing` says whether that blow killed. Nothing here says how much charge: the owner's
-- controller applies its own authored rules and answers with the points it actually added.
local CORE_KEYS = set("target", "record", "killing")
local CORE_TARGET = set("id", "epoch")

-- The three fields (keys already checked by the caller). Returns a COPY, or nil plus core_target / core_record / core_killing.
local function coreFields(raw)
    local target = raw.target
    if not plain(target) or not keysOnly(target, CORE_TARGET) then return nil, "core_target" end
    local epoch = whole(target.epoch, 1, L.integer)
    if not T.isId(target.id) or not epoch then return nil, "core_target" end
    if not recordName(raw.record) then return nil, "core_record" end
    if type(raw.killing) ~= "boolean" then return nil, "core_killing" end
    return { target = { id = target.id, epoch = epoch }, record = raw.record, killing = raw.killing }
end

-- The `request` argument of the server's `creditCore` export. Returns a copy, or nil plus core_keys / core_target /
-- core_record / core_killing.
function T.normalizeCoreCredit(raw)
    if not plain(raw) or not keysOnly(raw, CORE_KEYS) then return nil, "core_keys" end
    return coreFields(raw)
end

-- The owner's answer to one request, controller -> client -> server:
-- { v, op = 'gameplay_result', id, epoch, request, kind = 'hit' | 'repair' | 'core_credit', ok, reason?, amount? }.
-- `ok` says the controller took the request (hit: its final boss-hit took it; repair: hull was added; core_credit: the
-- controller's own authored rules ran, even when they added nothing) and `reason` is its own word (a refusal's text, a hit's
-- outcome), plain text of at most actionReason characters, required when refused. `amount` (the hit's damage estimate, the
-- hull a repair added, the core charge a credit actually added) is present when ok and absent when refused. It says nothing
-- of what the Titan's health is: that is the next frame's gameplay report. Returns a COPY, or nil plus a token.
function T.normalizeGameplayResult(raw)
    if type(raw) ~= "table" or not keysOnly(raw, RESULT_KEYS) then return nil, "result_keys" end
    if raw.v ~= T.protocol or raw.op ~= "gameplay_result" then return nil, "result_op" end
    local epoch, request = whole(raw.epoch, 1, L.integer), whole(raw.request, 1, L.integer)
    if not T.isId(raw.id) or not epoch or not request then return nil, "result_header" end
    if type(raw.kind) ~= "string" or T.resultKinds[raw.kind] ~= true then return nil, "result_kind" end
    if type(raw.ok) ~= "boolean" then return nil, "result_ok" end
    local out = { v = T.protocol, op = raw.op, id = raw.id, epoch = epoch, request = request, kind = raw.kind, ok = raw.ok }
    if raw.reason ~= nil then
        if not printable(raw.reason, 1, L.actionReason) then return nil, "result_reason" end
        out.reason = raw.reason
    elseif not raw.ok then
        return nil, "result_reason"
    end
    if raw.ok then
        local amount = raw.amount
        if not finite(amount) or amount < 0 or amount > L.actionAmount then return nil, "result_amount" end
        out.amount = amount
    elseif raw.amount ~= nil then
        return nil, "result_amount"
    end
    return out
end

-- The options of the `spawn` export (a table of two optional booleans, or nothing): `piloted` puts BT on the ground at the owner's
-- own place and seats V at once (no call-down), `hold` starts the Titan held. Returns { piloted, hold } as booleans, or nil and
-- invalid_options for anything else (a non-table, another key, a value that is not a boolean).
local SPAWN_OPTIONS = set("piloted", "hold")
function T.normalizeSpawnOptions(raw)
    if raw == nil then return { piloted = false, hold = false } end
    if not plain(raw) or not keysOnly(raw, SPAWN_OPTIONS) then return nil, "invalid_options" end
    for key in pairs(SPAWN_OPTIONS) do
        if raw[key] ~= nil and type(raw[key]) ~= "boolean" then return nil, "invalid_options" end
    end
    return { piloted = raw.piloted == true, hold = raw.hold == true }
end

-- A class: the label the HUD shows, the weapon, the abilities the controller lets through, the speed multiple and the damage
-- multiple and the shield's regeneration multiple, in one table. The fields common to the export's spec and to the wire's `class`
-- table (the spec also carries `perks`, which the loadout folds in, and its `abilities` may name only the ones that are on).
-- Returns a COPY { id, label, weapon, speed, harm, regen, abilities } with all nine abilities present as booleans (missing =
-- false), a speed, a harm and a regen (1.0 unless given), or nil and class_keys / class_id / class_label / class_weapon /
-- class_speed / class_harm / class_regen / class_abilities.
local CLASS_SPEC_KEYS = set("id", "label", "weapon", "perks", "abilities", "speed", "harm", "regen")
local CLASS_WIRE_KEYS = set("id", "label", "weapon", "abilities", "speed", "harm", "regen")

local function classFields(raw, keys)
    if not plain(raw) or not keysOnly(raw, keys) then return nil, "class_keys" end
    local id = raw.id
    if type(id) ~= "string" or #id < 1 or #id > 32 or id:find("^[a-z0-9_]+$") == nil then return nil, "class_id" end
    if not printable(raw.label, 1, 32) then return nil, "class_label" end
    if type(raw.weapon) ~= "string" or T.weapons[raw.weapon] ~= true then return nil, "class_weapon" end
    local speed = raw.speed
    if speed == nil then
        speed = 1.0
    elseif not finite(speed) or speed < T.classSpeed.min or speed > T.classSpeed.max then
        return nil, "class_speed"
    end
    local harm = raw.harm
    if harm == nil then
        harm = 1.0
    elseif not finite(harm) or harm < T.classHarm.min or harm > T.classHarm.max then
        return nil, "class_harm"
    end
    local regen = raw.regen
    if regen == nil then
        regen = 1.0
    elseif not finite(regen) or regen < T.classRegen.min or regen > T.classRegen.max then
        return nil, "class_regen"
    end
    local given = raw.abilities
    if not plain(given) then return nil, "class_abilities" end
    for name, value in pairs(given) do
        if T.classAbilities[name] ~= true or type(value) ~= "boolean" then return nil, "class_abilities" end
    end
    local abilities = {}
    for name in pairs(T.classAbilities) do abilities[name] = given[name] == true end
    return { id = id, label = raw.label, weapon = raw.weapon, speed = speed, harm = harm, regen = regen, abilities = abilities }
end

-- The `spec` argument of the server's `setClass` export. Returns the clean class (classFields' copy) and the Titan's complete
-- loadout for it (the sparse `perks` over the defaults, then the class weapon's perk at 1 and the other four weapons' at 0), or
-- nil and a token: classFields' own, or the loadout validators' (loadout_invalid / loadout_unknown / loadout_value /
-- loadout_range) for `perks`.
function T.normalizeClass(raw)
    local class, why = classFields(raw, CLASS_SPEC_KEYS)
    if not class then return nil, why end
    local loadout, reason = T.loadout.forClass(class.weapon, raw.perks)
    if not loadout then return nil, reason end
    return class, loadout
end

-- Server -> controller messages, validated on the client before they enter the
-- native queue (the server builds them, but the client does not take that on
-- faith). Returns the sanitized copy or nil plus a reason token.
function T.normalizeServerMessage(raw, catalog)
    if type(raw) ~= "table" then return nil, "message_invalid" end
    if raw.v ~= T.protocol then return nil, "message_version" end
    local op = raw.op
    if op == "state" then
        local frame, reason, dropped, firstDrop = snapshot(raw, catalog, "state", STATE_EXTRA)
        if not frame then return nil, reason end
        if not T.isId(raw.owner) then return nil, "state_owner" end
        if not finite(raw.serverTime) or raw.serverTime < 0 then return nil, "state_time" end
        frame.v, frame.op, frame.owner, frame.serverTime = T.protocol, "state", raw.owner, raw.serverTime
        return frame, nil, dropped, firstDrop
    elseif op == "session" then
        -- `pvp` is the server's Titan PvP flag (the `setTitanPvp` export): present on a session the server opens or re-asserts,
        -- absent on the one that ends it. Anything but a boolean refuses the message, like `active`.
        if not keysOnly(raw, set("v", "op", "active", "player", "pvp")) then return nil, "message_keys" end
        if type(raw.active) ~= "boolean" or not T.isId(raw.player) then return nil, "session_invalid" end
        if raw.pvp ~= nil and type(raw.pvp) ~= "boolean" then return nil, "session_invalid" end
        return { v = T.protocol, op = op, active = raw.active, player = raw.player, pvp = raw.pvp }
    elseif op == "grant" then
        -- The first loadout of a Titan: revision 1 and the complete map, in the grant itself. `piloted` and `hold` are the
        -- spawn export's options: each is absent or a boolean, and only a true one is carried on.
        if not keysOnly(raw, GRANT_KEYS) then return nil, "message_keys" end
        local epoch = whole(raw.epoch, 1, L.integer)
        if not T.isId(raw.id) or not epoch or not T.isId(raw.owner) then return nil, "grant_invalid" end
        if whole(raw.revision, 1, 1) == nil then return nil, "grant_revision" end
        local loadout = T.loadout.complete(raw.loadout)
        if not loadout then return nil, "grant_loadout" end
        if (raw.piloted ~= nil and type(raw.piloted) ~= "boolean") or (raw.hold ~= nil and type(raw.hold) ~= "boolean") then
            return nil, "grant_options"
        end
        return { v = T.protocol, op = op, id = raw.id, epoch = epoch, owner = raw.owner, revision = 1, loadout = loadout,
            piloted = raw.piloted == true or nil, hold = raw.hold == true or nil }
    elseif op == "loadout" then
        -- A later change of the owner's Titan: the whole new map and a revision the owner compares.
        if not keysOnly(raw, LOADOUT_KEYS) then return nil, "message_keys" end
        local epoch = whole(raw.epoch, 1, L.integer)
        if not T.isId(raw.id) or not epoch then return nil, "loadout_invalid" end
        local revision = whole(raw.revision, 1, L.integer)
        if not revision then return nil, "loadout_revision" end
        local loadout = T.loadout.complete(raw.loadout)
        if not loadout then return nil, "loadout_map" end
        return { v = T.protocol, op = op, id = raw.id, epoch = epoch, revision = revision, loadout = loadout }
    elseif op == "class" then
        -- A mission's class for this Titan: the whole loadout under a newer revision (as the `loadout` op) and, unless the
        -- class is being cleared, the class itself. The owner's controller applies both, the weapon and the locks in one step.
        if not keysOnly(raw, set("v", "op", "id", "epoch", "revision", "loadout", "class")) then return nil, "message_keys" end
        local epoch = whole(raw.epoch, 1, L.integer)
        if not T.isId(raw.id) or not epoch then return nil, "class_invalid" end
        local revision = whole(raw.revision, 1, L.integer)
        if not revision then return nil, "class_revision" end
        local loadout = T.loadout.complete(raw.loadout)
        if not loadout then return nil, "class_loadout" end
        local out = { v = T.protocol, op = op, id = raw.id, epoch = epoch, revision = revision, loadout = loadout }
        if raw.class ~= nil then
            local class, why = classFields(raw.class, CLASS_WIRE_KEYS)
            if not class then return nil, why end
            out.class = class
        end
        return out
    elseif op == "hold" then
        if not keysOnly(raw, set("v", "op", "id", "epoch", "held")) then return nil, "message_keys" end
        local epoch = whole(raw.epoch, 1, L.integer)
        if not T.isId(raw.id) or not epoch or type(raw.held) ~= "boolean" then return nil, "hold_invalid" end
        return { v = T.protocol, op = op, id = raw.id, epoch = epoch, held = raw.held }
    elseif op == "credit_kill" then
        if not keysOnly(raw, set("v", "op", "id", "epoch", "rank")) then return nil, "message_keys" end
        local epoch = whole(raw.epoch, 1, L.integer)
        if not T.isId(raw.id) or not epoch or type(raw.rank) ~= "string" or T.killRanks[raw.rank] ~= true then
            return nil, "credit_invalid"
        end
        return { v = T.protocol, op = op, id = raw.id, epoch = epoch, rank = raw.rank }
    elseif op == "remove" then
        if not keysOnly(raw, set("v", "op", "id", "epoch", "reason")) then return nil, "message_keys" end
        local epoch = whole(raw.epoch, 1, L.integer)
        if not T.isId(raw.id) or not epoch or T.removeReasons[raw.reason] ~= true then return nil, "remove_invalid" end
        return { v = T.protocol, op = op, id = raw.id, epoch = epoch, reason = raw.reason }
    elseif op == "command" then
        if not keysOnly(raw, set("v", "op", "action", "value")) then return nil, "message_keys" end
        local action = raw.action
        if type(action) ~= "string" or T.commandActions[action] ~= true then return nil, "command_action" end
        local out = { v = T.protocol, op = op, action = action }
        if action == "weapon" then
            if T.weapons[raw.value] ~= true then return nil, "command_value" end
            out.value = raw.value
        elseif action == "action" then
            if T.actions[raw.value] ~= true then return nil, "command_value" end
            out.value = raw.value
        elseif action == "log" then
            if raw.value ~= "on" and raw.value ~= "off" then return nil, "command_value" end
            out.value = raw.value
        elseif raw.value ~= nil then
            return nil, "command_value"
        end
        return out
    elseif op == "input" then
        -- One control a server script holds on this Titan: scoped to its id and epoch, named from T.inputs, valued by
        -- the kind the name has. The controller derives the kind again from its own schema.
        if not keysOnly(raw, set("v", "op", "id", "epoch", "name", "value")) then return nil, "message_keys" end
        local epoch = whole(raw.epoch, 1, L.integer)
        if not T.isId(raw.id) or not epoch then return nil, "input_invalid" end
        local name, kind, value = T.normalizeInput(raw.name, raw.value)
        if not name then return nil, kind end
        return { v = T.protocol, op = op, id = raw.id, epoch = epoch, name = name, value = value }
    elseif op == "input_release" then
        if not keysOnly(raw, set("v", "op", "id", "epoch")) then return nil, "message_keys" end
        local epoch = whole(raw.epoch, 1, L.integer)
        if not T.isId(raw.id) or not epoch then return nil, "input_invalid" end
        return { v = T.protocol, op = op, id = raw.id, epoch = epoch }
    elseif op == "hit" then
        if not keysOnly(raw, set("v", "op", "id", "epoch", "request", "record", "origin", "direction", "attacker", "kind", "scale")) then
            return nil, "message_keys"
        end
        local epoch, request = whole(raw.epoch, 1, L.integer), whole(raw.request, 1, L.integer)
        if not T.isId(raw.id) or not epoch or not request then return nil, "action_invalid" end
        local hit, why = hitFields(raw)
        if not hit then return nil, why end
        hit.v, hit.op, hit.id, hit.epoch, hit.request = T.protocol, op, raw.id, epoch, request
        return hit
    elseif op == "repair" then
        if not keysOnly(raw, set("v", "op", "id", "epoch", "request", "amount")) then return nil, "message_keys" end
        local epoch, request = whole(raw.epoch, 1, L.integer), whole(raw.request, 1, L.integer)
        if not T.isId(raw.id) or not epoch or not request then return nil, "action_invalid" end
        local amount, why = T.normalizeRepair(raw.amount)
        if not amount then return nil, why end
        return { v = T.protocol, op = op, id = raw.id, epoch = epoch, request = request, amount = amount }
    elseif op == "core_credit" then
        if not keysOnly(raw, set("v", "op", "id", "epoch", "request", "target", "record", "killing")) then
            return nil, "message_keys"
        end
        local epoch, request = whole(raw.epoch, 1, L.integer), whole(raw.request, 1, L.integer)
        if not T.isId(raw.id) or not epoch or not request then return nil, "action_invalid" end
        local credit, why = coreFields(raw)
        if not credit then return nil, why end
        credit.v, credit.op, credit.id, credit.epoch, credit.request = T.protocol, op, raw.id, epoch, request
        return credit
    elseif op == "carry_grant" then
        if not keysOnly(raw, set("v", "op", "id", "epoch", "request", "kind", "entityId", "token")) then
            return nil, "message_keys"
        end
        local epoch, request = whole(raw.epoch, 1, L.integer), whole(raw.request, 1, L.integer)
        if not T.isId(raw.id) or not epoch or not request or type(raw.kind) ~= "string" or T.carryKinds[raw.kind] ~= true
            or not T.isId(raw.entityId) or not T.isToken(raw.token) then
            return nil, "carry_invalid"
        end
        return { v = T.protocol, op = op, id = raw.id, epoch = epoch, request = request, kind = raw.kind,
            entityId = raw.entityId, token = raw.token }
    elseif op == "carry_denied" then
        if not keysOnly(raw, set("v", "op", "id", "epoch", "request", "reason")) then return nil, "message_keys" end
        local epoch, request = whole(raw.epoch, 1, L.integer), whole(raw.request, 1, L.integer)
        if not T.isId(raw.id) or not epoch or not request or type(raw.reason) ~= "string" or T.carryReasons[raw.reason] ~= true then
            return nil, "carry_invalid"
        end
        return { v = T.protocol, op = op, id = raw.id, epoch = epoch, request = request, reason = raw.reason }
    elseif op == "carry_ended" then
        if not keysOnly(raw, set("v", "op", "id", "epoch", "token", "reason")) then return nil, "message_keys" end
        local epoch = whole(raw.epoch, 1, L.integer)
        if not T.isId(raw.id) or not epoch or not T.isToken(raw.token) or type(raw.reason) ~= "string"
            or T.carryReasons[raw.reason] ~= true then
            return nil, "carry_invalid"
        end
        return { v = T.protocol, op = op, id = raw.id, epoch = epoch, token = raw.token, reason = raw.reason }
    elseif op == "error" then
        if not keysOnly(raw, set("v", "op", "reason")) or not reasonToken(raw.reason) then return nil, "error_invalid" end
        return { v = T.protocol, op = op, reason = raw.reason }
    end
    return nil, "message_op"
end

-- ---------------------------------------------------------------------------
-- Small shared helpers.
-- ---------------------------------------------------------------------------
function T.bucket(capacity, perSecond, now)
    return { tokens = capacity, capacity = capacity, rate = perSecond, at = now }
end

-- Takes `cost` tokens when available. A clock that moved backwards only
-- re-anchors the bucket; it never mints tokens.
function T.take(bucket, cost, now)
    local elapsed = now - bucket.at
    if elapsed > 0 then
        bucket.tokens = math.min(bucket.capacity, bucket.tokens + elapsed * bucket.rate)
    end
    bucket.at = now
    if bucket.tokens >= cost then
        bucket.tokens = bucket.tokens - cost
        return true
    end
    return false
end

local function names(dictionary)
    local list = {}
    for name in pairs(dictionary) do list[#list + 1] = name end
    table.sort(list)
    return table.concat(list, "|")
end

T.usage = "usage: /titan [status|spawn|remove|pilot|exit|log <on|off>|weapon <" .. names(T.weapons) ..
    ">|action <" .. names(T.actions) .. ">]"

-- `/titan` arguments (a table.pack of strings). Returns verb, value or nil, usage.
function T.parseCommand(args)
    local count = type(args) == "table" and (args.n or #args) or 0
    if count > 2 then return nil, T.usage end
    local verb = count >= 1 and string.lower(tostring(args[1])) or "status"
    if (verb == "status" or verb == "spawn" or verb == "remove" or verb == "pilot" or verb == "exit") and count <= 1 then
        return verb
    end
    if count == 2 then
        local value = string.lower(tostring(args[2]))
        if verb == "weapon" and T.weapons[value] then return verb, value end
        if verb == "action" and T.actions[value] then return verb, value end
        if verb == "log" and (value == "on" or value == "off") then return verb, value end
    end
    return nil, T.usage
end
