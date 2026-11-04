-- Wire schema (v=2) shared by the owner capture and the observer renderer: caps, the catalog allow-lists and the
-- validators for everything that arrives from the network. Nothing from a remote client reaches the game before it
-- has been copied through these functions: unknown keys are dropped, unknown names and out-of-range numbers refused.

local _ENV = require("controller.open77_titan_env")

local S = {}

S.VERSION = 2

-- The client's JSON encoder counts every value, table and key of a message (at most 1024 nodes); the resource accepts
-- frames up to 1000 nodes counted that way. Frames are packed to 900 so the relay's wrapper always fits.
S.CAPS = {
  frameHz = 20.0,
  valueBudget = 900,
  byteBudget = 30000,
  eventsPerFrame = 24,
  visualsPerFrame = 32,
  pendingEvents = 256,
  vars = 64, meshes = 32, lights = 16,
  coord = 1e6, rotation = 1e5, yaw = 3600.0, time = 1e9,
  remoteTitans = 64,
}

-- PS.mode of the controller, plus `drop` and `leave`: the call-down from the sky and the jump away on the jets
-- (PS.act.kind), during which BT is far above V.
S.MODES = { none = true, wait = true, pilot = true, mount = true, dismount = true, eject = true, drop = true, leave = true }
S.WEAPONS = { xo16 = true, rail = true, pred = true, sword = true, fist = true }
S.ACTIONS = { jump = true, dash = true, punch = true, missiles = true, vortex = true, smoke = true, core = true, eject = true, view = true, shoulder = true, grab = true }
-- `core` (fill the BURST CORE) takes no value, like pilot and exit: the validator drops one.
S.COMMANDS = { spawn = true, remove = true, pilot = true, exit = true, weapon = true, action = true, log = true, core = true }
-- A mission's class (the resource's shared.lua T.classAbilities, T.classSpeed, T.classHarm, T.classRegen and T.killRanks, key for
-- key and bound for bound): the nine abilities the controller gates, by the mission's names (`jets` is the controller's jump,
-- `designator` its TARGET DESIGNATOR), the bounds of the walk and run speed multiple, of the damage multiple and of the shield's
-- regeneration multiple, and the three kinds of foe a kill credit names.
S.CLASS = {
  abilities = { missiles = true, vortex = true, smoke = true, dash = true, jets = true, sentry = true, flight = true, designator = true, core = true },
  speedMin = 0.5, speedMax = 1.5, harmMin = 0.1, harmMax = 50, regenMin = 0.25, regenMax = 10,
}
S.RANKS = { grunt = true, rare = true, heavy = true }
-- Attached effects the controller starts afresh for every shot or spent case and never stops (the railgun's muzzle
-- flash, the two guns' cases): one authored burst per `attached_fx` start event. They travel as events only, never as
-- persistent `attached` visuals; every other attached effect (charges, thruster) is a loop held until its stop.
S.ONE_SHOT_ATTACHED = { bt7274_shell_xo16 = true, bt7274_shell_pred = true, bt7274_rail_muzzle = true }

-- Physical carry (grab, hold, throw of one canonical NPC or vehicle). Local->resource request/frame/release traffic and
-- resource->local grant/denied/ended answers; no engine identity travels but the request's own `entity` string.
S.CARRY = {
  kinds = { npc = true, vehicle = true },
  phases = { hold = true, flight = true },
  -- the bounded reasons the owner gives when it lets go (the resource validates the same list)
  reasons = {
    landed = true, flight_timeout = true, interrupted = true, titan_gone = true, session_end = true, unmatched = true,
    refused = true, lost = true, unobserved = true, stalled = true, timeout = true, clipped = true,
  },
  frameHz = 20.0,         -- carry_frame stream bound
  requestGap = 1.0,       -- seconds between two carry_request messages
  pending = 2.0,          -- the toss clip waits at the grab point at most this long for the grant
  stall = 0.8,            -- no accepted frame for this long while holding: the hold is dropped locally
  flightMax = 29.0,       -- a thrown body's flight, a person's ragdoll and a vehicle's kinematic flight alike, counted from the throw. The server allows 30 s from the first accepted flight pose (shared.lua carryFlight): ending a second earlier lets the final release arrive inside it. A hold has no time limit
  speedMax = 100.0,       -- m/s, wire cap for the published velocity
  -- a thrown person's release (`launch`, see S.carry_launch): the resource's own limits (carryLaunch* in shared.lua)
  launchImpulse = 1000.0, -- |ix|, |iy|, |iz| of the authored push's impulse
  launchRadius = 10.0,    -- m: the push's influence radius (the authored 2.0)
  launchDelay = 1.0,      -- s: how long after the ragdoll the push is applied (the authored 0.12)
  launchPoint = 2.0,      -- m: from the released body's root to the impulse point (the authored 0.6)
}

local ok, catalog = pcall(require, "controller.open77_titan_catalog")
if ok and type(catalog) == "table" then
  S.catalog = catalog
else
  S.catalog, S.catalogError = nil, tostring(catalog)
end

-- The Titan loadout (perk ids, their maxima, the complete-map checks): the resource's loadout.lua, installed as a module.
local loaded, loadout = pcall(require, "controller.open77_titan_loadout")
if loaded and type(loadout) == "table" and type(loadout.complete) == "function" then
  S.loadout = loadout
else
  S.loadout, S.loadoutError = nil, tostring(loadout)
end

local abs, huge, floor = math.abs, math.huge, math.floor

function S.finite(n)
  return type(n) == "number" and n == n and n ~= huge and n ~= -huge
end
local finite = S.finite

local function number_in(lo, hi)
  return function(v)
    if finite(v) and v >= lo and v <= hi then return v end
  end
end

local function vec(v)
  if type(v) ~= "table" then return nil end
  local lim = S.CAPS.coord
  local x, y, z = v.x, v.y, v.z
  if finite(x) and finite(y) and finite(z) and abs(x) <= lim and abs(y) <= lim and abs(z) <= lim then
    return { x = x, y = y, z = z }
  end
end
S.vec = vec

local function rotation(v)
  if type(v) ~= "table" then return nil end
  local lim = S.CAPS.rotation
  local x, y, z, w = v.x, v.y, v.z, v.w
  if not (finite(x) and finite(y) and finite(z) and abs(x) <= lim and abs(y) <= lim and abs(z) <= lim) then return nil end
  if w == nil then return { x = x, y = y, z = z } end
  if finite(w) and abs(w) <= lim then return { x = x, y = y, z = z, w = w } end
end

local function color(v)
  if type(v) ~= "table" then return nil end
  local r, g, b, a = v.r, v.g, v.b, v.a
  if not (finite(r) and finite(g) and finite(b) and r >= 0 and g >= 0 and b >= 0 and r <= 255 and g <= 255 and b <= 255) then return nil end
  if a == nil then return { r = r, g = g, b = b } end
  if finite(a) and a >= 0 and a <= 255 then return { r = r, g = g, b = b, a = a } end
end

local function member(set_name, key)
  return function(v)
    local set = S.catalog and S.catalog[set_name]
    if type(v) == "string" and set and set[v] then return v end
  end
end

local FIELD = {
  id = function(v) if type(v) == "string" and #v <= 48 and #v >= 1 and v:match("^[%w_:%.%-]+$") then return v end end,
  effect = member("effects"),
  attached = member("attachedEffects"),
  sound = member("sounds"),
  slot = member("slots"),
  vec = vec,
  rot = rotation,
  color = color,
  bool = function(v) if type(v) == "boolean" then return v end end,
  gain = number_in(0, 4),
  life = function(v) if finite(v) and v > 0 and v <= 10 then return v end end,
  width = function(v) if finite(v) and v > 0 and v <= 5 then return v end end,
  backend = function(v) if v == "native" or v == "audioxl" then return v end end,
  action = function(v) if v == "start" or v == "stop" or v == "break" then return v end end,
  mark = function(v) if v == "none" or v == "hit" or v == "person" then return v end end,
}

-- field specs: req/opt map a field to a FIELD validator; `any` lists fields of which at least one must be present
local EVENTS = {
  fx_spawn = { req = { fxId = "id", path = "effect", position = "vec" }, opt = { rotation = "rot", target = "vec", loop = "bool" } },
  fx_move = { req = { fxId = "id" }, opt = { position = "vec", rotation = "rot", target = "vec", slot = "slot" }, any = { "position", "rotation", "target", "slot" } },
  fx_stop = { req = { fxId = "id" }, opt = {} },
  attached_fx = { req = { name = "attached", action = "action" }, opt = {} },
  sound = { req = { name = "sound", backend = "backend" }, opt = { position = "vec", gain = "gain" } },
  sound_stop = { req = { name = "sound" }, opt = {} },
  tracer = { req = { from = "vec", to = "vec", life = "life" }, opt = { color = "color", width = "width", mark = "mark" } },
}
S.EVENT_KINDS = EVENTS

local VISUALS = {
  fx = { req = { fxId = "id", path = "effect", position = "vec" }, opt = { rotation = "rot", target = "vec", loop = "bool" } },
  attached = { req = { name = "attached" }, opt = {} },
  sound = { req = { name = "sound", backend = "backend" }, opt = { position = "vec", gain = "gain" } },
  tracer = { req = { from = "vec", to = "vec", life = "life" }, opt = { color = "color", width = "width", mark = "mark" } },
}

local function clean(spec, kind, src)
  local out = { kind = kind }
  for field, check in pairs(spec.req) do
    local v = FIELD[check](src[field])
    if v == nil then return nil, kind .. "." .. field end
    out[field] = v
  end
  for field, check in pairs(spec.opt) do
    if src[field] ~= nil then
      local v = FIELD[check](src[field])
      if v == nil then return nil, kind .. "." .. field end
      out[field] = v
    end
  end
  if spec.any then
    local found = false
    for _, field in ipairs(spec.any) do
      if out[field] ~= nil then found = true end
    end
    if not found then return nil, kind .. ".empty" end
  end
  return out
end

local function positive_int(v)
  return finite(v) and v >= 1 and v == floor(v) and v < 2 ^ 53
end

-- A relayed or locally built event -> clean copy, or nil and the reason.
function S.event(ev)
  if type(ev) ~= "table" then return nil, "event" end
  local spec = EVENTS[ev.kind]
  if not spec then return nil, "kind" end
  if not positive_int(ev.seq) then return nil, "seq" end
  local out, why = clean(spec, ev.kind, ev)
  if not out then return nil, why end
  out.seq = ev.seq
  return out
end

function S.visual(v)
  if type(v) ~= "table" then return nil, "visual" end
  local spec = VISUALS[v.kind]
  if not spec then return nil, "kind" end
  return clean(spec, v.kind, v)
end

local function carry_token(v)
  if type(v) ~= "string" or #v < 1 or #v > 128 then return nil end
  if v:find("[^%w%p]") or v:find('["\\]') then return nil end
  return v
end

local function reason_text(v)
  if type(v) ~= "string" then return "unspecified" end
  return (v:sub(1, 64):gsub("[^%w%p ]", "?"))
end

-- Exact unsigned decimal of a native 64-bit identity (never converted through a float); `<= 20` digits.
function S.decimal_id(v)
  if type(v) == "string" and #v >= 1 and #v <= 20 and v:match("^%d+$") and v:match("[1-9]") then return v end
end

-- A pose the owner is about to publish -> clean copy, or nil and the field. Finite and ranged; the rotation is
-- normalised (a zero quaternion is refused), the velocity is capped in length.
function S.carry_pose(p)
  if type(p) ~= "table" then return nil, "pose" end
  local lim = S.CARRY.speedMax
  for _, k in ipairs({ "x", "y", "z" }) do
    if not finite(p[k]) or abs(p[k]) > S.CAPS.coord then return nil, k end
  end
  for _, k in ipairs({ "vx", "vy", "vz", "qx", "qy", "qz", "qw" }) do
    if not finite(p[k]) then return nil, k end
  end
  if not finite(p.yaw) or abs(p.yaw) > S.CAPS.yaw then return nil, "yaw" end
  if not S.CARRY.phases[p.phase] then return nil, "phase" end
  local n = math.sqrt(p.qx * p.qx + p.qy * p.qy + p.qz * p.qz + p.qw * p.qw)
  if n < 1e-6 then return nil, "q" end
  local vx, vy, vz = p.vx, p.vy, p.vz
  local v = math.sqrt(vx * vx + vy * vy + vz * vz)
  if v > lim then vx, vy, vz = vx * lim / v, vy * lim / v, vz * lim / v end
  return {
    x = p.x, y = p.y, z = p.z, yaw = p.yaw, qx = p.qx / n, qy = p.qy / n, qz = p.qz / n, qw = p.qw / n,
    vx = vx, vy = vy, vz = vz, phase = p.phase,
  }
end

-- The fields of a thrown person's release, in a fixed order.
S.LAUNCH_FIELDS = { "t", "x", "y", "z", "yaw", "px", "py", "pz", "ix", "iy", "iz", "radius", "delay" }
local LAUNCH_POINTS = { "x", "y", "z", "px", "py", "pz" }
local LAUNCH_IMPULSE = { "ix", "iy", "iz" }

-- The release of a thrown person the owner is about to publish, which the resource validates again with the same
-- fields and bounds: `t` the controller clock at the authored push, `x y z yaw` the released body's ROOT pose,
-- `px py pz` the point and `ix iy iz` the impulse the authored push applies there, with its `radius` and `delay`.
-- Every field is required and finite, the impulse is not zero and its point is near the root. A clean copy, or nil and
-- the field that is wrong.
function S.carry_launch(l)
  if type(l) ~= "table" then return nil, "launch" end
  local out = {}
  for _, k in ipairs(S.LAUNCH_FIELDS) do
    if not finite(l[k]) then return nil, k end
    out[k] = l[k]
  end
  if out.t < 0 or out.t > S.CAPS.time then return nil, "t" end
  for _, k in ipairs(LAUNCH_POINTS) do
    if abs(out[k]) > S.CAPS.coord then return nil, k end
  end
  if abs(out.yaw) > S.CAPS.yaw then return nil, "yaw" end
  for _, k in ipairs(LAUNCH_IMPULSE) do
    if abs(out[k]) > S.CARRY.launchImpulse then return nil, k end
  end
  if out.ix == 0 and out.iy == 0 and out.iz == 0 then return nil, "impulse" end
  if not (out.radius > 0 and out.radius <= S.CARRY.launchRadius) then return nil, "radius" end
  if out.delay < 0 or out.delay > S.CARRY.launchDelay then return nil, "delay" end
  local dx, dy, dz = out.px - out.x, out.py - out.y, out.pz - out.z
  if dx * dx + dy * dy + dz * dz > S.CARRY.launchPoint ^ 2 then return nil, "point" end
  return out
end

local function id_string(v)
  if type(v) == "string" and #v >= 1 and #v <= 20 and v:match("^%d+$") then return v end
end
S.id = id_string

local function string_set(src, allowed, max)
  if type(src) ~= "table" then return nil end
  local out, n = {}, 0
  for k, v in pairs(src) do
    n = n + 1
    if n > max or type(k) ~= "string" or type(v) ~= "boolean" or not (allowed and allowed[k]) then return nil end
    out[k] = v
  end
  return out
end

local function number_map(src, allowed, max)
  if type(src) ~= "table" then return nil end
  local out, n = {}, 0
  for k, v in pairs(src) do
    n = n + 1
    if n > max or type(k) ~= "string" or not finite(v) or abs(v) > 1e6 or not (allowed and allowed[k]) then return nil end
    out[k] = v
  end
  return out
end

local function list(src, max)
  if src == nil then return {} end
  if type(src) ~= "table" then return nil end
  local out, n = {}, 0
  for k, v in pairs(src) do
    if type(k) ~= "number" then return nil end
    n = n + 1
    if n > max then return nil end
  end
  for i = 1, n do out[i] = src[i] end
  return out
end

-- A relayed `state` message -> clean table, or nil and the reason. Single bad events/visuals are dropped and
-- counted in `dropped`; a bad pose, mode, weapon or map refuses the whole message.
function S.state(msg)
  local c = S.catalog
  if not c then return nil, "catalog" end
  local id, owner = id_string(msg.id), id_string(msg.owner)
  if not id or not owner then return nil, "id" end
  if not positive_int(msg.epoch) or not positive_int(msg.seq) then return nil, "epoch" end
  if not finite(msg.t) or msg.t < 0 then return nil, "t" end
  local pose = msg.pose
  if type(pose) ~= "table" or not finite(pose.yaw) or abs(pose.yaw) > S.CAPS.yaw then return nil, "pose" end
  local p = vec(pose)
  if not p then return nil, "pose" end
  p.yaw = pose.yaw
  if not S.MODES[msg.mode] or not S.WEAPONS[msg.weapon] then return nil, "mode" end
  local vars = number_map(msg.vars, c.variables, S.CAPS.vars)
  local meshes = string_set(msg.meshes, c.meshes, S.CAPS.meshes)
  local lights = string_set(msg.lights, c.lights, S.CAPS.lights)
  if not vars or not meshes or not lights then return nil, "maps" end
  local events_in = list(msg.events, S.CAPS.eventsPerFrame)
  local visuals_in = list(msg.visuals, S.CAPS.visualsPerFrame)
  if not events_in or not visuals_in then return nil, "lists" end
  local dropped, events, visuals, last = 0, {}, {}, 0
  for _, ev in ipairs(events_in) do
    local e = S.event(ev)
    if e and e.seq > last then
      last = e.seq
      events[#events + 1] = e
    else
      dropped = dropped + 1
    end
  end
  for _, v in ipairs(visuals_in) do
    local e = S.visual(v)
    if e then visuals[#visuals + 1] = e else dropped = dropped + 1 end
  end
  return {
    id = id, epoch = msg.epoch, owner = owner, seq = msg.seq, t = msg.t, pose = p, mode = msg.mode, weapon = msg.weapon,
    vars = vars, meshes = meshes, lights = lights, events = events, visuals = visuals, dropped = dropped,
  }
end

-- Server-driven controls: every control a server script may hold on a piloted Titan and the kind of its value, exactly
-- the resource's shared.lua (T.inputs, T.inputLimits; tests/client.test.lua compares the two).
--   axis      a level in -1 .. 1 of one of the game's input axes (the stick, the right stick)
--   relative  one relative step of the mouse look in the game's own RELATIVE_CHANGE units, within +/-20000
--   button    true presses and false releases a game action
--   key       true presses and false releases one of the BT-7274 mod's own pilot keys (its Mod Settings names)
-- The controller (fragments/events.lua: FPF.input) turns a kind into the game's input type or the mod's key function;
-- no name here is a function, and no companion command (follow, home, call, embark, eject) is in the set.
S.INPUT = {
  MoveX = "axis", MoveY = "axis", CameraX = "axis", CameraY = "axis",
  CameraMouseX = "relative", CameraMouseY = "relative",
  Forward = "button", Back = "button", Left = "button", Right = "button", Sprint = "button", ToggleSprint = "button",
  Jump = "button", Dodge = "button", RangedAttack = "button", Reload = "button", QuickMelee = "button",
  RangedADS = "button", CameraAim = "button",
  jump = "key", dash = "key", punch = "key", missiles = "key", vortex = "key", smoke = "key", core = "key",
  view = "key", shoulder = "key", sentry = "key", designate = "key", flight = "key",
}
S.INPUT_LIMIT = { axis = 1, relative = 20000 }

-- A scripted control -> name, kind, value, or nil and the reason: a name of S.INPUT and a value of its kind (a finite
-- number within the kind's limit, or exactly true / false).
function S.input(name, value)
  if type(name) ~= "string" then return nil, "name" end
  local kind = S.INPUT[name]
  if kind == nil then return nil, "name" end
  local limit = S.INPUT_LIMIT[kind]
  if limit ~= nil then
    if not finite(value) or value < -limit or value > limit then return nil, "value" end
  elseif type(value) ~= "boolean" then
    return nil, "value"
  end
  return name, kind, value
end

-- ------------------------------------------------------------------ gameplay -----------------------------------------
-- The owner's gameplay report (frame.gameplay), the requests a server script sends (hit, repair, core_credit) and the
-- controller's answer to each (gameplay_result): the resource's shared.lua (T.normalizeGameplay, T.normalizeHit,
-- T.normalizeRepair, T.normalizeCoreCredit, T.normalizeGameplayResult and the limits actionXxx / gameplayXxx) key for key and
-- bound for bound, so that a report or an answer the controller publishes is never one the server refuses, and a request the
-- server sends is never one the controller does not understand. Every key set is exact; every substate the controller has
-- nothing to say about is absent.
S.GAMEPLAY = { value = 1e6, text = 64 }
S.ABILITIES = { jump = true, dash = true, missiles = true, vortex = true, smoke = true, flight = true, sentry = true }
S.HIT_KINDS = { ranged = true, melee = true, blast = true }
S.RESULT_KINDS = { hit = true, repair = true, core_credit = true }
-- record / attacker / reason text lengths, the controller's scale ceiling (FPC.bossScaleUp162.most), one amount
S.ACTION = { record = 160, attacker = 96, reason = 160, scale = 4.0, amount = 1e6 }

local function only(src, allowed)
  local n = 0
  for k in pairs(src) do
    n = n + 1
    if n > 32 or allowed[k] ~= true then return false end
  end
  return true
end

local function set_of(...)
  local out = {}
  for _, name in ipairs({ ... }) do out[name] = true end
  return out
end

-- Printable ASCII only (never a control byte or a byte above 126).
local function printable(v, lo, hi)
  return type(v) == "string" and #v >= lo and #v <= hi and not v:find("[^ -~]")
end

local function whole_in(v, lo, hi)
  if finite(v) and v >= lo and v <= hi and v == floor(v) then return v end
end

local function figure(v, minimum)
  if finite(v) and v >= minimum and abs(v) <= S.GAMEPLAY.value then return v end
end

local GAMEPLAY_KEYS = set_of("health", "ammo", "core", "abilities", "paused", "pauseReason")
local HEALTH_KEYS = set_of("current", "max", "shield", "shieldMax", "doomed", "doomedMax", "dead")
local HEALTH_FIGURES = { "current", "max", "shield", "shieldMax", "doomed", "doomedMax" }
local AMMO_KEYS = set_of("current", "capacity", "reloading")
local CORE_KEYS = set_of("charge", "max", "active")
local ABILITY_KEYS = set_of("active", "remaining", "cooldown")

local function gameplay_health(raw)
  if type(raw) ~= "table" or not only(raw, HEALTH_KEYS) or type(raw.dead) ~= "boolean" then return nil end
  local out = { dead = raw.dead }
  for _, key in ipairs(HEALTH_FIGURES) do
    if raw[key] ~= nil then
      out[key] = figure(raw[key], -S.GAMEPLAY.value)
      if out[key] == nil then return nil end
    end
  end
  if out.current == nil or out.max == nil then return nil end
  return out
end

local function gameplay_ammo(raw)
  if type(raw) ~= "table" or not only(raw, AMMO_KEYS) or type(raw.reloading) ~= "boolean" then return nil end
  local current, capacity = whole_in(raw.current, 0, S.GAMEPLAY.value), whole_in(raw.capacity, 1, S.GAMEPLAY.value)
  if not current or not capacity then return nil end
  return { current = current, capacity = capacity, reloading = raw.reloading }
end

local function gameplay_core(raw)
  if type(raw) ~= "table" or not only(raw, CORE_KEYS) or type(raw.active) ~= "boolean" then return nil end
  local charge, max = figure(raw.charge, 0), figure(raw.max, 0)
  if charge == nil or max == nil or max <= 0 then return nil end
  return { charge = charge, max = max, active = raw.active }
end

local function gameplay_abilities(raw)
  if type(raw) ~= "table" then return nil end
  local out = {}
  for name, value in pairs(raw) do
    if type(name) ~= "string" or not S.ABILITIES[name] or type(value) ~= "table" or not only(value, ABILITY_KEYS)
        or type(value.active) ~= "boolean" then
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

-- The module's snapshot -> a clean copy holding only the known keys, or nil and the reason token the server would give.
function S.gameplay(raw)
  if type(raw) ~= "table" or not only(raw, GAMEPLAY_KEYS) then return nil, "gameplay_keys" end
  if type(raw.paused) ~= "boolean" then return nil, "gameplay_paused" end
  local out = { paused = raw.paused }
  if raw.health ~= nil then
    out.health = gameplay_health(raw.health)
    if not out.health then return nil, "gameplay_health" end
  end
  if raw.ammo ~= nil then
    out.ammo = gameplay_ammo(raw.ammo)
    if not out.ammo then return nil, "gameplay_ammo" end
  end
  if raw.core ~= nil then
    out.core = gameplay_core(raw.core)
    if not out.core then return nil, "gameplay_core" end
  end
  if raw.abilities ~= nil then
    out.abilities = gameplay_abilities(raw.abilities)
    if not out.abilities then return nil, "gameplay_abilities" end
  end
  if raw.pauseReason ~= nil then
    if not printable(raw.pauseReason, 1, S.GAMEPLAY.text) then return nil, "gameplay_text" end
    out.pauseReason = raw.pauseReason
  end
  return out
end

local XYZ = set_of("x", "y", "z")

local function exact_point(v)
  if type(v) ~= "table" or not only(v, XYZ) then return nil end
  return vec(v)
end

local function heading(v)
  if type(v) ~= "table" or not only(v, XYZ) then return nil end
  local x, y, z = v.x, v.y, v.z
  if not (finite(x) and finite(y) and finite(z)) or abs(x) > 1 or abs(y) > 1 or abs(z) > 1 then return nil end
  if x == 0 and y == 0 and z == 0 then return nil end
  return { x = x, y = y, z = z }
end

-- A TweakDB record name (a hit's record, a status effect, a core credit's record): shared.lua's recordName.
local function record_name(v)
  return type(v) == "string" and #v >= 1 and #v <= S.ACTION.record and v:find("^[%w_.]+$") ~= nil
end

-- The six fields of a hit (the key set is the caller's): a COPY with every field present, or nil and the token.
local function hit_fields(raw)
  local record = raw.record
  if not record_name(record) then
    return nil, "hit_record"
  end
  local origin = exact_point(raw.origin)
  if not origin then return nil, "hit_origin" end
  local direction = heading(raw.direction)
  if not direction then return nil, "hit_direction" end
  local attacker = raw.attacker
  if attacker == nil then attacker = "" end
  if not printable(attacker, 0, S.ACTION.attacker) then return nil, "hit_attacker" end
  if type(raw.kind) ~= "string" or not S.HIT_KINDS[raw.kind] then return nil, "hit_kind" end
  local scale = raw.scale
  if scale == nil then scale = 1.0 end
  if not finite(scale) or scale <= 0 or scale > S.ACTION.scale then return nil, "hit_scale" end
  return { record = record, origin = origin, direction = direction, attacker = attacker, kind = raw.kind, scale = scale }
end

local function repair_amount(v)
  if finite(v) and v > 0 and v <= S.ACTION.amount then return v end
end

-- ------------------------------------------------------------------ observed hits and status effects ---------------
-- What this controller saw its Titan land on, or apply to, ANOTHER player's Titan (open77_titan_combat's reports) leaves as
-- `op = 'hit_observed'` or `op = 'status_observed'`: the resource's shared.lua (T.normalizeHitObserved,
-- T.normalizeStatusObserved) key for key and bound for bound, so that a report the bridge publishes is never one the client
-- or the server refuses. `id` / `epoch` name the SENDER's own Titan, `seq` is the sender's count of delivered observations of
-- that grant (hits and status effects are numbered together), `target` the canonical identity of the Titan that was hit
-- (text ids, the owner as text). A status effect is a record name and, only when the controller's own call supplied one, a
-- duration in seconds. Nothing here is a hit or a status effect: it is an observation the server forwards and a mission prices.
-- What it landed on a canonical CAR leaves as `op = 'vehicle_hit'` (T.normalizeVehicleHit): the car's canonical id as text, the
-- percentage of its health taken off since the last report and where the car was, numbered with the other two. That one the
-- server acts on once no script vetoes it.
-- What it landed on another PLAYER's body leaves as `op = 'player_hit'` (T.normalizePlayerHit): the victim's player id as text, the
-- attack record and how many such blows were summed (1 to S.PLAYER.count), numbered with the others. The report carries no amount: the
-- server prices the record and applies it under Open77's PvP rules.
local OBSERVED_KEYS = set_of("v", "op", "id", "epoch", "seq", "target", "record", "origin", "point", "direction", "kind", "scale")
local REPORT_KEYS = set_of("target", "record", "origin", "point", "direction", "kind", "scale")
local STATUS_KEYS = set_of("v", "op", "id", "epoch", "seq", "target", "effect", "duration")
local STATUS_REPORT_KEYS = set_of("target", "effect", "duration")
local TARGET_KEYS = set_of("kind", "id", "epoch", "owner")
local VEHICLE_KEYS = set_of("v", "op", "id", "epoch", "seq", "vehicle", "share", "point")
local VEHICLE_REPORT_KEYS = set_of("vehicle", "share", "point")
S.VEHICLE = { share = 100 }     -- percent of a car's full health in one report (shared.lua limits.vehicleShare)
local PLAYER_KEYS = set_of("v", "op", "id", "epoch", "seq", "player", "record", "count")
local PLAYER_REPORT_KEYS = set_of("player", "record", "count")
S.PLAYER = { count = 64 }       -- blows of one record summed in one report (shared.lua limits.playerHitCount)
local NPC_KEYS = set_of("v", "op", "id", "epoch", "seq", "npc", "record", "kind", "point")
local NPC_REPORT_KEYS = set_of("npc", "record", "kind", "point")
-- What an NPC blow may be called (shared.lua T.npcKinds) and how often a round on one NPC is reported (limits.npcRoundGap).
S.NPC = { kinds = set_of("round", "blast", "melee", "blade", "other"), roundGap = 1 / 60 }

-- The resource's own Titan id and player text: one to sixteen digits, no leading zero (shared.lua T.isId).
local function titan_text(v)
  return type(v) == "string" and #v >= 1 and #v <= 16 and v:find("^[1-9]%d*$") ~= nil
end

-- The canonical identity of the target of an observation (the key set is the caller's): a clean copy, or nil.
local function observed_target(raw)
  local target = raw.target
  if type(target) ~= "table" or not only(target, TARGET_KEYS) or target.kind ~= "titan" then return nil end
  if not titan_text(target.id) or not positive_int(target.epoch) or not titan_text(target.owner) then return nil end
  return { kind = "titan", id = target.id, epoch = target.epoch, owner = target.owner }
end

-- The target, the six fields of a hit and the point it landed at (the key set is the caller's): a clean body without header,
-- or nil and the token the server would give.
local function observed_body(raw)
  local target = observed_target(raw)
  if not target then return nil, "observed_target" end
  local hit, why = hit_fields(raw)
  if not hit then return nil, why end
  local point = exact_point(raw.point)
  if not point then return nil, "hit_point" end
  return {
    target = target,
    record = hit.record, origin = hit.origin, point = point, direction = hit.direction, kind = hit.kind, scale = hit.scale,
  }
end

-- The target and the status effect (the key set is the caller's): a clean body without header, or nil and the token the server
-- would give. The duration is absent unless it was given: no default is made up.
local function status_body(raw)
  local target = observed_target(raw)
  if not target then return nil, "observed_target" end
  if not record_name(raw.effect) then return nil, "status_effect" end
  local duration = raw.duration
  if duration ~= nil and not (finite(duration) and duration >= 0 and duration <= S.CAPS.time) then return nil, "status_duration" end
  return { target = target, effect = raw.effect, duration = duration }
end

-- The car and what was taken off it (the key set is the caller's): a clean body without header, or nil and the token the server
-- would give. `vehicle` is the car's canonical id as text; `share` a percentage of its full health, never above one whole car.
local function vehicle_body(raw)
  if not titan_text(raw.vehicle) then return nil, "vehicle_id" end
  local share = raw.share
  if not finite(share) or share <= 0 or share > S.VEHICLE.share then return nil, "vehicle_share" end
  local point = exact_point(raw.point)
  if not point then return nil, "hit_point" end
  return { vehicle = raw.vehicle, share = share, point = point }
end

-- The victim and the blow (the key set is the caller's): a clean body without header, or nil and the token the server would give.
-- `player` is the victim's player id as text, `record` the authored record of the blow, `count` how many such blows were summed.
local function player_body(raw)
  if not titan_text(raw.player) then return nil, "player_id" end
  if not record_name(raw.record) then return nil, "hit_record" end
  local count = raw.count
  if not finite(count) or count < 1 or count > S.PLAYER.count or count ~= floor(count) then return nil, "player_count" end
  return { player = raw.player, record = raw.record, count = math.tointeger(count) or count }
end

-- The NPC and the blow (the key set is the caller's): a clean body without header, or nil and the token the server would give.
-- `npc` is the platform's NPC id as text, `record` the authored record of the blow, `kind` one of S.NPC.kinds, `point` where it landed.
local function npc_body(raw)
  if not titan_text(raw.npc) then return nil, "npc_id" end
  if not record_name(raw.record) then return nil, "hit_record" end
  if type(raw.kind) ~= "string" or S.NPC.kinds[raw.kind] ~= true then return nil, "npc_kind" end
  local point = exact_point(raw.point)
  if not point then return nil, "hit_point" end
  return { npc = raw.npc, record = raw.record, kind = raw.kind, point = point }
end

-- The combat module's report ({ target, record, origin, point, direction, kind, scale }) -> a clean copy, or nil and a token.
function S.hit_report(report)
  if type(report) ~= "table" or not only(report, REPORT_KEYS) then return nil, "report_keys" end
  return observed_body(report)
end

-- The combat module's status report ({ target, effect, duration? }) -> a clean copy, or nil and a token.
function S.status_report(report)
  if type(report) ~= "table" or not only(report, STATUS_REPORT_KEYS) then return nil, "report_keys" end
  return status_body(report)
end

-- A complete outbound message -> a clean copy, or nil and the token the server would give. The copy is what is published.
function S.hit_observed(msg)
  if type(msg) ~= "table" or not only(msg, OBSERVED_KEYS) then return nil, "observed_keys" end
  if msg.v ~= S.VERSION or msg.op ~= "hit_observed" then return nil, "observed_op" end
  if not titan_text(msg.id) or not positive_int(msg.epoch) then return nil, "observed_source" end
  if not positive_int(msg.seq) then return nil, "observed_seq" end
  local body, why = observed_body(msg)
  if not body then return nil, why end
  body.v, body.op, body.id, body.epoch, body.seq = S.VERSION, "hit_observed", msg.id, msg.epoch, msg.seq
  return body
end

function S.status_observed(msg)
  if type(msg) ~= "table" or not only(msg, STATUS_KEYS) then return nil, "observed_keys" end
  if msg.v ~= S.VERSION or msg.op ~= "status_observed" then return nil, "observed_op" end
  if not titan_text(msg.id) or not positive_int(msg.epoch) then return nil, "observed_source" end
  if not positive_int(msg.seq) then return nil, "observed_seq" end
  local body, why = status_body(msg)
  if not body then return nil, why end
  body.v, body.op, body.id, body.epoch, body.seq = S.VERSION, "status_observed", msg.id, msg.epoch, msg.seq
  return body
end

-- The bridge's report of what its Titan's weapons took off a car ({ vehicle, share, point }) -> a clean copy, or nil and a token.
function S.vehicle_report(report)
  if type(report) ~= "table" or not only(report, VEHICLE_REPORT_KEYS) then return nil, "report_keys" end
  return vehicle_body(report)
end

function S.vehicle_hit(msg)
  if type(msg) ~= "table" or not only(msg, VEHICLE_KEYS) then return nil, "observed_keys" end
  if msg.v ~= S.VERSION or msg.op ~= "vehicle_hit" then return nil, "observed_op" end
  if not titan_text(msg.id) or not positive_int(msg.epoch) then return nil, "observed_source" end
  if not positive_int(msg.seq) then return nil, "observed_seq" end
  local body, why = vehicle_body(msg)
  if not body then return nil, why end
  body.v, body.op, body.id, body.epoch, body.seq = S.VERSION, "vehicle_hit", msg.id, msg.epoch, msg.seq
  return body
end

-- The bridge's report of a blow on another player's body ({ player, record, count }) -> a clean copy, or nil and a token.
function S.player_report(report)
  if type(report) ~= "table" or not only(report, PLAYER_REPORT_KEYS) then return nil, "report_keys" end
  return player_body(report)
end

function S.player_hit(msg)
  if type(msg) ~= "table" or not only(msg, PLAYER_KEYS) then return nil, "observed_keys" end
  if msg.v ~= S.VERSION or msg.op ~= "player_hit" then return nil, "observed_op" end
  if not titan_text(msg.id) or not positive_int(msg.epoch) then return nil, "observed_source" end
  if not positive_int(msg.seq) then return nil, "observed_seq" end
  local body, why = player_body(msg)
  if not body then return nil, why end
  body.v, body.op, body.id, body.epoch, body.seq = S.VERSION, "player_hit", msg.id, msg.epoch, msg.seq
  return body
end

-- The bridge's report of a blow on a platform NPC ({ npc, record, kind, point }) -> a clean copy, or nil and a token.
function S.npc_report(report)
  if type(report) ~= "table" or not only(report, NPC_REPORT_KEYS) then return nil, "report_keys" end
  return npc_body(report)
end

function S.npc_hit(msg)
  if type(msg) ~= "table" or not only(msg, NPC_KEYS) then return nil, "observed_keys" end
  if msg.v ~= S.VERSION or msg.op ~= "npc_hit" then return nil, "observed_op" end
  if not titan_text(msg.id) or not positive_int(msg.epoch) then return nil, "observed_source" end
  if not positive_int(msg.seq) then return nil, "observed_seq" end
  local body, why = npc_body(msg)
  if not body then return nil, why end
  body.v, body.op, body.id, body.epoch, body.seq = S.VERSION, "npc_hit", msg.id, msg.epoch, msg.seq
  return body
end

-- The controller's answer to one request (published as op = 'gameplay_result'), validated again with the resource's own
-- rules before it leaves: nil and the token when it is not one the server would take.
local RESULT_KEYS = set_of("v", "op", "id", "epoch", "request", "kind", "ok", "reason", "amount")
function S.result(msg)
  if type(msg) ~= "table" or not only(msg, RESULT_KEYS) then return nil, "result_keys" end
  if msg.v ~= S.VERSION or msg.op ~= "gameplay_result" then return nil, "result_op" end
  if not id_string(msg.id) or not positive_int(msg.epoch) or not positive_int(msg.request) then return nil, "result_header" end
  if not S.RESULT_KINDS[msg.kind] then return nil, "result_kind" end
  if type(msg.ok) ~= "boolean" then return nil, "result_ok" end
  if msg.reason ~= nil then
    if not printable(msg.reason, 1, S.ACTION.reason) then return nil, "result_reason" end
  elseif not msg.ok then
    return nil, "result_reason"
  end
  if msg.ok then
    if not finite(msg.amount) or msg.amount < 0 or msg.amount > S.ACTION.amount then return nil, "result_amount" end
  elseif msg.amount ~= nil then
    return nil, "result_amount"
  end
  return msg
end

-- The controller's own words (a refusal's text, a hit's outcome) -> printable ASCII of at most ACTION.reason characters;
-- anything else becomes '?'. Never empty.
function S.reason(v)
  if type(v) ~= "string" or v == "" then return "unspecified" end
  return (v:sub(1, S.ACTION.reason):gsub("[^ -~]", "?"))
end

-- The class table of a `class` message (shared.lua's classFields on the wire): { id, label, weapon, speed, harm, regen, abilities }
-- -> a clean copy with all nine abilities present as booleans, a speed, a harm and a regen (1.0 when absent), or nil.
local CLASS_KEYS = set_of("id", "label", "weapon", "abilities", "speed", "harm", "regen")
local function class_fields(c)
  if type(c) ~= "table" or not only(c, CLASS_KEYS) then return nil end
  local id = c.id
  if type(id) ~= "string" or #id < 1 or #id > 32 or not id:find("^[a-z0-9_]+$") then return nil end
  if not printable(c.label, 1, 32) or not S.WEAPONS[c.weapon] then return nil end
  local speed = c.speed
  if speed == nil then
    speed = 1.0
  elseif not finite(speed) or speed < S.CLASS.speedMin or speed > S.CLASS.speedMax then
    return nil
  end
  local harm = c.harm
  if harm == nil then
    harm = 1.0
  elseif not finite(harm) or harm < S.CLASS.harmMin or harm > S.CLASS.harmMax then
    return nil
  end
  local regen = c.regen
  if regen == nil then
    regen = 1.0
  elseif not finite(regen) or regen < S.CLASS.regenMin or regen > S.CLASS.regenMax then
    return nil
  end
  local given = c.abilities
  if type(given) ~= "table" then return nil end
  for name, value in pairs(given) do
    if not S.CLASS.abilities[name] or type(value) ~= "boolean" then return nil end
  end
  local abilities = {}
  for name in pairs(S.CLASS.abilities) do abilities[name] = given[name] == true end
  return { id = id, label = c.label, weapon = c.weapon, speed = speed, harm = harm, regen = regen, abilities = abilities }
end

-- Any message the resource delivers -> clean table with `op`, or nil and the reason.
function S.inbound(msg)
  if type(msg) ~= "table" or msg.v ~= S.VERSION or type(msg.op) ~= "string" then return nil, "envelope" end
  local op = msg.op
  if op == "state" then
    local st, why = S.state(msg)
    if st then st.op = "state" end
    return st, why
  elseif op == "session" then
    -- `pvp`: the server's Titan PvP flag (shared.lua's twin of this check); absent on the message that ends a session
    if type(msg.active) ~= "boolean" or (msg.pvp ~= nil and type(msg.pvp) ~= "boolean") then return nil, "session" end
    return { op = op, active = msg.active, player = id_string(msg.player), pvp = msg.pvp }
  elseif op == "grant" then
    local id, owner = id_string(msg.id), id_string(msg.owner)
    if not id or not owner or not positive_int(msg.epoch) or msg.revision ~= 1 then return nil, "grant" end
    if not S.loadout then return nil, "loadout" end
    local map = S.loadout.complete(msg.loadout)
    if not map then return nil, "grant" end
    -- the spawn export's options: each absent or a boolean, and only a true one is carried on (shared.lua's grant twin)
    if (msg.piloted ~= nil and type(msg.piloted) ~= "boolean") or (msg.hold ~= nil and type(msg.hold) ~= "boolean") then
      return nil, "grant"
    end
    return { op = op, id = id, epoch = msg.epoch, owner = owner, revision = 1, loadout = map,
      piloted = msg.piloted == true or nil, hold = msg.hold == true or nil }
  elseif op == "loadout" then
    local id = id_string(msg.id)
    if not id or not positive_int(msg.epoch) or not positive_int(msg.revision) then return nil, "loadout" end
    if not S.loadout then return nil, "loadout" end
    local map = S.loadout.complete(msg.loadout)
    if not map then return nil, "loadout" end
    return { op = op, id = id, epoch = msg.epoch, revision = msg.revision, loadout = map }
  elseif op == "class" then
    if not only(msg, set_of("v", "op", "id", "epoch", "revision", "loadout", "class")) then return nil, "class" end
    if not titan_text(msg.id) or not positive_int(msg.epoch) or not positive_int(msg.revision) then return nil, "class" end
    if not S.loadout then return nil, "loadout" end
    local map = S.loadout.complete(msg.loadout)
    if not map then return nil, "class" end
    local out = { op = op, id = msg.id, epoch = msg.epoch, revision = msg.revision, loadout = map }
    if msg.class ~= nil then
      out.class = class_fields(msg.class)
      if not out.class then return nil, "class" end
    end
    return out
  elseif op == "hold" then
    if not only(msg, set_of("v", "op", "id", "epoch", "held")) or not titan_text(msg.id) or not positive_int(msg.epoch)
        or type(msg.held) ~= "boolean" then
      return nil, "hold"
    end
    return { op = op, id = msg.id, epoch = msg.epoch, held = msg.held }
  elseif op == "credit_kill" then
    if not only(msg, set_of("v", "op", "id", "epoch", "rank")) or not titan_text(msg.id) or not positive_int(msg.epoch)
        or type(msg.rank) ~= "string" or not S.RANKS[msg.rank] then
      return nil, "credit_kill"
    end
    return { op = op, id = msg.id, epoch = msg.epoch, rank = msg.rank }
  elseif op == "command" then
    if not S.COMMANDS[msg.action] then return nil, "command" end
    local value = msg.value
    if msg.action == "weapon" and not S.WEAPONS[value] then return nil, "weapon" end
    if msg.action == "action" and not S.ACTIONS[value] then return nil, "action" end
    if msg.action == "log" and value ~= "on" and value ~= "off" then return nil, "log" end
    if msg.action ~= "weapon" and msg.action ~= "action" and msg.action ~= "log" then value = nil end
    return { op = op, action = msg.action, value = value }
  elseif op == "remove" then
    local id = msg.id ~= nil and id_string(msg.id) or nil
    if msg.id ~= nil and not id then return nil, "remove" end
    return { op = op, id = id, epoch = positive_int(msg.epoch) and msg.epoch or nil, reason = type(msg.reason) == "string" and msg.reason:sub(1, 64) or "removed" }
  elseif op == "input" then
    local id = id_string(msg.id)
    if not id or not positive_int(msg.epoch) then return nil, "input" end
    local name, kind, value = S.input(msg.name, msg.value)
    if not name then return nil, "input" end
    return { op = op, id = id, epoch = msg.epoch, name = name, kind = kind, value = value }
  elseif op == "input_release" then
    local id = id_string(msg.id)
    if not id or not positive_int(msg.epoch) then return nil, "input_release" end
    return { op = op, id = id, epoch = msg.epoch }
  elseif op == "error" then
    return { op = op, reason = type(msg.reason) == "string" and msg.reason:sub(1, 96) or "error" }
  elseif op == "hit" then
    local id = id_string(msg.id)
    if not id or not positive_int(msg.epoch) or not positive_int(msg.request)
        or not only(msg, set_of("v", "op", "id", "epoch", "request", "record", "origin", "direction", "attacker", "kind", "scale")) then
      return nil, "hit"
    end
    local hit = hit_fields(msg)
    if not hit then return nil, "hit" end
    hit.op, hit.id, hit.epoch, hit.request = op, id, msg.epoch, msg.request
    return hit
  elseif op == "repair" then
    local id = id_string(msg.id)
    if not id or not positive_int(msg.epoch) or not positive_int(msg.request) or not repair_amount(msg.amount)
        or not only(msg, set_of("v", "op", "id", "epoch", "request", "amount")) then
      return nil, "repair"
    end
    return { op = op, id = id, epoch = msg.epoch, request = msg.request, amount = msg.amount }
  elseif op == "core_credit" then
    local id = msg.id
    if not titan_text(id) or not positive_int(msg.epoch) or not positive_int(msg.request)
        or not only(msg, set_of("v", "op", "id", "epoch", "request", "target", "record", "killing")) then
      return nil, "core_credit"
    end
    local target = msg.target
    if type(target) ~= "table" or not only(target, set_of("id", "epoch")) or not titan_text(target.id) or not positive_int(target.epoch)
        or not record_name(msg.record) or type(msg.killing) ~= "boolean" then
      return nil, "core_credit"
    end
    return { op = op, id = id, epoch = msg.epoch, request = msg.request, target = { id = target.id, epoch = target.epoch },
      record = msg.record, killing = msg.killing }
  elseif op == "carry_grant" then
    local id, entity, token = id_string(msg.id), S.decimal_id(msg.entityId), carry_token(msg.token)
    if not id or not entity or not token or not positive_int(msg.epoch) or not positive_int(msg.request) or not S.CARRY.kinds[msg.kind] then return nil, "carry_grant" end
    return { op = op, id = id, epoch = msg.epoch, request = msg.request, kind = msg.kind, entityId = entity, token = token }
  elseif op == "carry_denied" then
    if not positive_int(msg.request) then return nil, "carry_denied" end
    local id = msg.id ~= nil and id_string(msg.id) or nil
    if msg.id ~= nil and not id then return nil, "carry_denied" end
    return { op = op, request = msg.request, reason = reason_text(msg.reason), id = id, epoch = positive_int(msg.epoch) and msg.epoch or nil }
  elseif op == "carry_ended" then
    local id, token = id_string(msg.id), carry_token(msg.token)
    if not id or not token or not positive_int(msg.epoch) then return nil, "carry_ended" end
    return { op = op, id = id, epoch = msg.epoch, token = token, reason = reason_text(msg.reason) }
  end
  return nil, "op"
end

return S
