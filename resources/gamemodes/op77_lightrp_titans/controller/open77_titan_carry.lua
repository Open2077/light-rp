-- Open77 <-> BT-7274 controller bridge: the physical carry (grab, hold, throw) of one canonical NPC or vehicle.
--
-- The author's controller grabs whatever is in BT's hand, holds it and throws it, all on this machine. Here the same
-- motion is kept - it is still the author's code that moves the body - but it runs under a server-granted claim:
--   * the FINAL target of a grab (the one carryStart / carTake143 is about to take) is named to the resource, and no
--     mutation happens before the grant; the toss clip waits at the grab point (2 s at most) and a refusal ends the
--     reach through the controller's own grabMiss;
--   * while the claim lives, the pose the controller gives the body (the held rig's world position, a vehicle's
--     full rotation and velocity, the thrown body's measured motion) is published at 20 Hz so that the canonical
--     body, and every other client's rendering of it, follows;
--   * everything the grab changed on the body (its disabled components, its Stun, the rig offset, the mover it had to
--     suspend for its placement, a vehicle's flight, the landing splash) is put back deterministically whenever the
--     claim, the Titan, the session or the gesture ends, however it ends.
--   * a thrown person's release is described once, from the controller's own push (FPF.ragdollPush149, called through
--     unchanged): where its root stood, the impulse and point the authored push applied and its radius and delay. Every
--     flight frame and the release repeat that one descriptor, because the host runs a batch of messages newest first
--     and no single message can be relied on to arrive first; a thrown person with no such descriptor is never published.
-- Outside an Open77 Titan session every wrapper here calls the controller's own function unchanged.

local _ENV = require("controller.open77_titan_env")
local schema = require("controller.open77_titan_schema")

local M = {}

local CARRY = schema.CARRY
local finite = schema.finite
local floor, sqrt, abs, max, min, sin, cos, rad = math.floor, math.sqrt, math.abs, math.max, math.min, math.sin, math.cos, math.rad

local SETTLE = 0.1            -- after the release the thrown body is taken to be where it was let go for this long (the controller's own impulse follows 0.12 s after the ragdoll, and the placement of the whole body must have landed)
local FLIGHT_SEE = 1.5        -- by this time the thrown body must have moved FLIGHT_MOVED metres, or its motion is not observable
local FLIGHT_MOVED = 0.5
local REST_AFTER = 1.0        -- at rest = no more than REST_DIST metres of travel over REST_WINDOW seconds, not before REST_AFTER
local REST_WINDOW = 0.6
local REST_DIST = 0.25
local SLOT_MARGIN = 0.5       -- a body slot is the thrown body's position only when it moved this much more than the entity's root
local NPC_AXIS = 50.0         -- m/s per axis: the resource's wire limit for a person's velocity
local OUTBOX_LIMIT, OUTBOX_LIFE, OUTBOX_EVERY = 4, 5.0, 0.25
local LATE_LIMIT, LATE_LIFE = 8, 10.0
local PIN_EPS = 1.0e-4
local SLOT_NAMES = { "Chest", "Head", "Spine", "Hips" }
local SLOT_GIVE_UP = 30
local PLACE_WAIT = 0.3        -- a held person's body and rig have this long, from the placement being asked for, to read back at the held place before its throw; after that the throw is cancelled
local PLACE_NEAR = 0.3        -- metres: the root counts as at the held place within this
local LAUNCH_RADIUS = 2.0    -- m: the influence radius the authored FPF.ragdollPush149 applies its impulse with (a literal of that function, pinned by titan_seams.py)
local LAUNCH_DELAY = 0.12    -- s: the delay it applies the impulse after the ragdoll (the same)

local function wrap180(a) return (a + 180.0) % 360.0 - 180.0 end
local function round(v, places) local m = 10 ^ places return floor(v * m + 0.5) / m end
local function dist(ax, ay, az, b) return sqrt((ax - b[1]) ^ 2 + (ay - b[2]) ^ 2 + (az - b[3]) ^ 2) end

-- Where a held person's whole body is put before its throw: the platform's client API (Open77.npcs.placeCarried) places
-- the canonical body's own root, and only while this client's HOLD claim lives (it refuses everything else without
-- changing anything). The controller's own ways - the AI teleport order and the teleportation facility - only queue a
-- request that a puppet never obeys, so neither is used, as a fallback or otherwise. True only when the API took the
-- placement: an API that is missing, raises or refuses places nothing.
local function place_root(ent, x, y, z, yaw)
  local ok, placed = pcall(function()
    return Open77.npcs.placeCarried(ent:GetEntityID(), { x = x, y = y, z = z }, yaw)
  end)
  return ok and placed == true
end

-- A held person's skeleton rig is put back on its entity by writing its local transform to identity. True when the call
-- went through; that the engine also shows it in the world is NOT implied (see settle_rig).
local function clear_rig(rig)
  return (pcall(function() rig:SetLocalTransform(Vector4.new(0.0, 0.0, 0.0, 1.0), Quaternion.new(0.0, 0.0, 0.0, 1.0)) end))
end

-- A person's own mover (`moveComponent`) rewrites its root every frame while it is enabled, and the placement API above
-- refuses to place a root it would overwrite. These turn the body's enabled movers off through the engine's own Toggle
-- (never by writing isEnabled) and put back exactly the ones they turned off; a mover that was already off is never
-- touched.
-- The body's enabled movers, or nil when its components cannot be read (a component that cannot be told from a mover
-- counts as unreadable).
local function enabled_movers(ent)
  local ok, comps = pcall(function() return ent:GetComponents() end)
  if not ok or type(comps) ~= "table" then return nil end
  local found = {}
  for _, comp in ipairs(comps) do
    local okn, name = pcall(function() return comp:GetClassName() end)
    if not okn then return nil end
    if name == "moveComponent" then
      local oke, on = pcall(function() return comp:IsEnabled() end)
      if not oke then return nil end
      if on == true then found[#found + 1] = comp end
    end
  end
  return found
end

-- Back on: every listed mover that does not read enabled already. True when all of them read enabled afterwards.
local function put_back_movers(movers)
  local all = true
  for _, comp in ipairs(movers) do
    local ok, on = pcall(function() return comp:IsEnabled() end)
    if not (ok and on == true) then
      pcall(function() comp:Toggle(true) end)
      local okn, now = pcall(function() return comp:IsEnabled() end)
      if not (okn and now == true) then all = false end
    end
  end
  return all
end

-- Off: exactly the movers that were enabled, each verified to read disabled. The movers turned off are returned (an
-- empty list when none was enabled). Anything that cannot be read, toggled or verified puts back what had been turned
-- off and returns nil: a body whose mover cannot be held off is never placed.
local function suspend_movers(ent)
  local movers = enabled_movers(ent)
  if movers == nil then return nil end
  local owned = {}
  for _, comp in ipairs(movers) do
    owned[#owned + 1] = comp
    pcall(function() comp:Toggle(false) end)
    local ok, on = pcall(function() return comp:IsEnabled() end)
    if not (ok and on == false) then
      put_back_movers(owned)
      return nil
    end
  end
  return owned
end

-- ------------------------------------------------------------------ reading the game ------------------------------
local function read3(p)
  if p == nil then return nil end
  local ok, x, y, z = pcall(function() return p.x, p.y, p.z end)
  if ok and finite(x) and finite(y) and finite(z) then return x, y, z end
end

local function world_pos(ent)
  local ok, p = pcall(function() return ent:GetWorldPosition() end)
  if ok then return read3(p) end
end

local function world_yaw(ent)
  local ok, y = pcall(function() return ent:GetWorldYaw() end)
  if ok and finite(y) then return y end
end

-- The world translation the engine reports for a component right now: what it has propagated, not what was last
-- written to the component's local transform (the engine shows a write in the world only once it has updated it).
local function component_world(comp)
  local ok, w = pcall(function() return comp:GetLocalToWorld().W end)
  if ok then return read3(w) end
end

local function quat4(q)
  if q == nil then return nil end
  local ok, i, j, k, r = pcall(function() return q.i, q.j, q.k, q.r end)
  if ok and finite(i) and finite(j) and finite(k) and finite(r) then return i, j, k, r end
end

-- The engine's own Euler -> quaternion, the one the controller's Teleport calls are made in.
local function euler_quat(roll, pitch, yaw)
  local ok, q = pcall(function() return EulerAngles.ToQuat(EulerAngles.new(roll, pitch, yaw)) end)
  if ok then return quat4(q) end
end

local function yaw_quat(yaw)
  local i, j, k, r = euler_quat(0.0, 0.0, yaw)
  if i then return i, j, k, r end
  local h = rad(yaw) * 0.5
  return 0.0, 0.0, sin(h), cos(h)
end

local function world_quat(ent)
  local ok, q = pcall(function() return ent:GetWorldOrientation() end)
  if ok then return quat4(q) end
end

-- The native entity identity as the exact unsigned decimal string. An EntityID is a 64-bit integer: one with the top
-- bit set is a negative Lua integer, whose unsigned value is read here without ever passing through a float.
local function u64_text(n)
  if n >= 0 then return string.format("%d", n) end
  local q = (n >> 1) // 5            -- the unsigned quotient by ten
  return string.format("%d%d", q, n - q * 10)
end

local function native_id(ent)
  local ok, id = pcall(function() return ent:GetEntityID() end)
  if not ok or id == nil then return nil, "no entity id" end
  if math.type(id) ~= "integer" or id == 0 then return nil, "no entity hash" end
  local exact = schema.decimal_id(u64_text(id))
  if not exact then return nil, "the identity has no exact decimal form" end
  return exact
end
M.native_id = native_id

-- A body slot of a thrown person (its animated/ragdoll rig, which moves when the entity's root does not).
local function slot_pos(ent, cache)
  if cache.slotsFor ~= ent then cache.slots, cache.slotsFor, cache.slotName, cache.slotForm, cache.slotFails = nil, ent, nil, nil, 0 end
  if cache.slots == false then return nil end
  if cache.slots == nil then
    cache.slots = false
    for _, find in ipairs({ function() return ent:FindComponentByName("slots") end, function() return ent:GetSlotComponent() end }) do
      local ok, comp = pcall(find)
      if ok and comp ~= nil then cache.slots = comp break end
    end
    if cache.slots == false then return nil end
  end
  local comp = cache.slots
  local function read(name, withArgument)
    local a, b
    if withArgument then a, b = comp:GetSlotTransform(name, WorldTransform.new()) else a, b = comp:GetSlotTransform(name) end
    local t = b
    if t == nil and type(a) ~= "boolean" then t = a end
    if a == false or t == nil then return nil end
    local v = WorldPosition.ToVector4(WorldTransform.GetWorldPosition(t))
    return v.x, v.y, v.z
  end
  for _, name in ipairs(cache.slotName and { cache.slotName } or SLOT_NAMES) do
    for _, form in ipairs(cache.slotForm and { cache.slotForm } or { 1, 2 }) do
      local ok, x, y, z = pcall(read, name, form == 2)
      if ok and finite(x) and finite(y) and finite(z) then
        cache.slotName, cache.slotForm, cache.slotFails = name, form, 0
        return x, y, z
      end
    end
  end
  cache.slotFails = (cache.slotFails or 0) + 1
  if cache.slotFails >= SLOT_GIVE_UP then cache.slots = false end
  return nil
end

-- ------------------------------------------------------------------ the module ------------------------------------
function M.new(ctx)
  local self = {
    c = nil,            -- the one live carry of this Titan
    late = {},          -- request -> what a grant that arrives after the controller gave up must be answered with
    outbox = {},        -- releases the queue has not taken yet
    nextRequest = 0, requestAt = -100.0, flushAt = 0.0,
    mode = nil, out = nil, orig = nil, cache = {},
    requests = 0, grants = 0, denials = 0, holds = 0, throws = 0, aborts = 0,
  }

  local function E() return ctx.env end

  local function enabled()
    return ctx.session.active and ctx.titan ~= nil and ctx.link ~= nil and ctx.env ~= nil and ctx.env.PS.ent ~= nil
  end
  self.enabled = enabled

  function self.reset()
    self.c, self.late, self.outbox, self.cache, self.mode, self.out = nil, {}, {}, {}, nil, nil
    self.flushAt = 0.0
  end

  function self.status()
    local c = self.c
    return string.format("carry %s (requests %d, grants %d, denied %d, held %d, thrown %d, aborted %d, queued releases %d)",
      c and (c.phase .. " " .. c.kind) or "none", self.requests, self.grants, self.denials, self.holds, self.throws, self.aborts, #self.outbox)
  end

  -- ---------------------------------------------------------------- what the controller changed on the body ------
  local function has_stun(ent)
    local has
    local ok = pcall(function() has = Game.GetStatusEffectSystem():HasStatusEffect(ent:GetEntityID(), TweakDBID.new(E().FPC.fist.stagger.stun)) end)
    if ok then return has == true end
    return nil
  end

  local function vehicle_heavy(veh)
    local mass = 1500.0
    pcall(function()
      local m = veh:GetTotalMass()
      if m and m > 50.0 then mass = m end
    end)
    return mass > E().FPC.fist.grab143.carMass
  end
  self.vehicle_heavy = vehicle_heavy   -- the grab key offers only a vehicle this lets the controller lift (open77_titan_grab)

  -- Whatever this carry left running for its body: the vehicle's kinematic flight, the landing splash, the wake-up.
  function self.clear_flight(c)
    local PS = E().PS
    local key = c.key
    local F = PS.carFly145
    if F and F.key == key then
      PS.carFly145 = nil
      local ent = c.Cr and c.Cr.ent or c.ent
      if ent ~= nil and IsDefined(ent) then pcall(function() ent:PhysicsWakeUp() end) end
    end
    local L = PS.tossLand
    if L and L.skip == key then PS.tossLand = nil end
    local V = PS.carLand143
    if V and V.key == key then PS.carLand143 = nil end
  end

  -- The movers this carry turned off for its body's placement, back on, once. A carry that turned none off has nothing
  -- to put back.
  local function resume_movers(c)
    local owned = c.movers
    c.movers = nil
    if owned and not put_back_movers(owned) then
      ctx.diag("carry.mover.restore", "a held person's mover could not be turned back on after its carry: the body may stand still")
    end
  end

  -- The controller's own undo of a carry, run when nothing else will: the disabled components back, this carry's
  -- Stun off, the skeleton back on its object, a vehicle awake, the flight and landing of this body cancelled, its
  -- suspended mover back on and the interrupted punch cleared. Only this body's state is touched.
  function self.restore_body(c, why)
    local env = E()
    local PS, FPF, FPC = env.PS, env.FPF, env.FPC
    local Cr = c.Cr
    if not Cr then return end
    Cr.thrown = true
    local ent = Cr.ent
    if ent ~= nil and IsDefined(ent) then
      if Cr.car then
        pcall(function() ent:PhysicsWakeUp() end)
      else
        if Cr.disabled then pcall(function() ent:MountingEndEnableComponents() end) Cr.disabled = false end
        if c.ownStun then pcall(function() StatusEffectHelper["StatusEffectHelper::RemoveStatusEffect;GameObjectTweakDBIDUint32"](ent, TweakDBID.new(FPC.fist.stagger.stun)) end) end
      end
    end
    -- the rig component is reset directly as well: the controller's own session end clears PS.holds149 before the
    -- carry ends here, and then holdLetGo149 has no entry left to put the skeleton back with
    local rig = Cr.root149
    pcall(FPF.holdLetGo149, Cr, "the carry was ended (" .. tostring(why) .. ")")
    if rig ~= nil then clear_rig(rig) end
    self.clear_flight(c)
    resume_movers(c)
    local punch = c.M
    if punch then
      if PS.punch == punch then PS.punch, PS.punchW = nil, 0.0 end
      if PS.lunge and PS.lunge.punch == punch then PS.lunge = nil end
    end
  end

  -- ---------------------------------------------------------------- poses --------------------------------------
  -- A clean wire pose from a sample; the velocity is the finite difference to the previous sample (never invented).
  function self.pose(c, x, y, z, yaw, qi, qj, qk, qr, phase, axisCap)
    local vx, vy, vz = 0.0, 0.0, 0.0
    local prev = c.prev
    if prev and ctx.clock - prev.t > 1.0e-3 then
      local dt = ctx.clock - prev.t
      vx, vy, vz = (x - prev.x) / dt, (y - prev.y) / dt, (z - prev.z) / dt
    end
    c.prev = { x = x, y = y, z = z, t = ctx.clock }
    if axisCap then
      vx, vy, vz = max(-axisCap, min(axisCap, vx)), max(-axisCap, min(axisCap, vy)), max(-axisCap, min(axisCap, vz))
    end
    return schema.carry_pose({ x = x, y = y, z = z, yaw = wrap180(yaw), qx = qi, qy = qj, qz = qk, qw = qr, vx = vx, vy = vy, vz = vz, phase = phase })
  end

  -- The held body's world pose. A person held by the controller's rig offset stands where its OBJECT was taken:
  -- the held place is the rig's world position the controller keeps in Cr.hold149, not the entity's root. Once the
  -- body's placement for the throw was asked for (c.placing), the held place is exactly that place until the throw.
  function self.hold_pose(c)
    local Cr = c.Cr
    local ent = Cr.ent
    if ent == nil or not IsDefined(ent) then return nil, "lost" end
    local PS = E().PS
    if c.kind == "npc" then
      local H, at = Cr.hold149, c.placing
      local x, y, z, yaw
      if at then
        x, y, z, yaw = at.x, at.y, at.z, at.yaw
      elseif Cr.root149 and H and finite(H.x) and finite(H.y) and finite(H.z) then
        x, y, z, yaw = H.x, H.y, H.z, wrap180(PS.yaw + 180.0)
      else
        x, y, z = world_pos(ent)
        yaw = world_yaw(ent)
      end
      if not x then return nil, "position" end
      yaw = yaw or wrap180(PS.yaw + 180.0)
      local i, j, k, r = yaw_quat(yaw)
      return self.pose(c, x, y, z, yaw, i, j, k, r, "hold", NPC_AXIS)
    end
    local x, y, z = world_pos(ent)
    if not x then return nil, "position" end
    local yaw = world_yaw(ent) or 0.0
    local i, j, k, r = world_quat(ent)
    if not i then i, j, k, r = yaw_quat(yaw) end
    return self.pose(c, x, y, z, yaw, i, j, k, r, "hold", nil)
  end

  -- The thrown body's measured place, never a computed arc. Until SETTLE the body is where it was let go (the throw's
  -- impulse is still being queued). After that: the entity's root when it follows the body; otherwise the movement of
  -- one of the body's own slots since it was let go (added to where it was let go, so the published place stays
  -- root-equivalent). A body that shows no motion at all by FLIGHT_SEE is `unobserved`, not flown on paper.
  function self.measure_free(c)
    local fl = c.flight
    local ent = c.Cr.ent
    local age = ctx.clock - fl.t0
    local o = fl.origin
    local rx, ry, rz = world_pos(ent)
    local sx, sy, sz
    if c.kind == "npc" then sx, sy, sz = slot_pos(ent, self.cache) end
    if not rx and not sx then return nil, "lost" end
    if sx and not fl.baseSlot then fl.baseSlot = { sx, sy, sz } end
    local yaw = world_yaw(ent) or fl.yaw or 0.0
    local x, y, z = o[1], o[2], o[3]
    if age >= SETTLE then
      local dRoot = rx and dist(rx, ry, rz, o) or -1.0
      local dSlot = (sx and fl.baseSlot) and dist(sx, sy, sz, fl.baseSlot) or -1.0
      if not fl.latch and dSlot > dRoot + SLOT_MARGIN then fl.latch = "slot" end
      if fl.latch == "slot" and sx and fl.baseSlot then
        x, y, z = o[1] + sx - fl.baseSlot[1], o[2] + sy - fl.baseSlot[2], o[3] + sz - fl.baseSlot[3]
      elseif rx then
        x, y, z = rx, ry, rz
      end
      fl.via = fl.latch or "root"
      fl.maxMoved = max(fl.maxMoved or 0.0, dist(x, y, z, o))
      local win = fl.win or {}
      fl.win = win
      win[#win + 1] = { t = ctx.clock, x, y, z }
      while #win > 1 and win[1].t < ctx.clock - REST_WINDOW - 0.05 do table.remove(win, 1) end
      if fl.maxMoved >= FLIGHT_MOVED and age >= REST_AFTER and #win >= 2 and ctx.clock - win[1].t >= REST_WINDOW * 0.9 and dist(x, y, z, { win[1][1], win[1][2], win[1][3] }) < REST_DIST then
        fl.rest = true
      end
      if age >= FLIGHT_SEE and fl.maxMoved < FLIGHT_MOVED then fl.unobserved = true end
    end
    local i, j, k, r
    if c.kind == "vehicle" then i, j, k, r = world_quat(ent) end
    if not i then i, j, k, r = yaw_quat(yaw) end
    return self.pose(c, x, y, z, yaw, i, j, k, r, "flight", c.kind == "npc" and NPC_AXIS or nil)
  end

  -- A vehicle thrown by the controller's kinematic flight (PS.carFly145): its exact position, velocity and rotation.
  function self.flight_pose(c)
    local fl = c.flight
    local F = fl.F
    local landed = E().PS.carFly145 ~= F and not F.lost   -- a flight the port ended with no ground to meet (F.lost) is still in the air
    local ent = c.Cr.ent
    local yaw = F.yaw or 0.0
    local i, j, k, r
    if landed then i, j, k, r = euler_quat(0.0, 0.0, yaw) else i, j, k, r = euler_quat(F.roll or 0.0, F.pitch or 0.0, yaw) end
    if not i and ent ~= nil and IsDefined(ent) then i, j, k, r = world_quat(ent) end
    if not i then return nil, "rotation" end
    local vx, vy, vz = F.vx or 0.0, F.vy or 0.0, F.vz or 0.0
    if landed then vx, vy, vz = 0.0, 0.0, 0.0 end
    return schema.carry_pose({ x = F.x, y = F.y, z = F.z, yaw = wrap180(yaw), qx = i, qy = j, qz = k, qw = r, vx = vx, vy = vy, vz = vz, phase = "flight" })
  end

  -- Where the body really is after an abnormal end: its root after the restore, or the last pose published.
  function self.rest_pose(c)
    if c.phase == "flight" and c.last then return c.last end
    local ent = c.Cr and c.Cr.ent or c.ent
    if ent ~= nil and IsDefined(ent) then
      local x, y, z = world_pos(ent)
      if x then
        local yaw = world_yaw(ent) or (c.last and c.last.yaw) or 0.0
        local i, j, k, r
        if c.kind == "vehicle" then i, j, k, r = world_quat(ent) end
        if not i then i, j, k, r = yaw_quat(yaw) end
        local p = schema.carry_pose({ x = x, y = y, z = z, yaw = wrap180(yaw), qx = i, qy = j, qz = k, qw = r, vx = 0.0, vy = 0.0, vz = 0.0, phase = c.phase == "flight" and "flight" or "hold" })
        if p then return p end
      end
    end
    return c.last
  end

  -- ---------------------------------------------------------------- outgoing --------------------------------------
  -- One strictly increasing sequence per claim; a release the queue refuses is retried with the same sequence.
  function self.release(claim, token, pose, reason)
    claim.seq = (claim.seq or 0) + 1
    local msg = {
      v = schema.VERSION, op = "carry_release", id = claim.titan.id, epoch = claim.titan.epoch, token = token,
      seq = claim.seq, t = round(ctx.clock, 3), pose = pose, reason = CARRY.reasons[reason] and reason or "interrupted",
      launch = pose.phase == "flight" and claim.launch or nil,
    }
    if ctx.send(msg) then return true end
    if #self.outbox >= OUTBOX_LIMIT then table.remove(self.outbox, 1) end
    self.outbox[#self.outbox + 1] = { msg = msg, till = ctx.clock + OUTBOX_LIFE }
    ctx.diag("carry.release.queue", "a carry release could not be queued; it is retried for a few seconds")
    return false
  end

  function self.flush()
    if #self.outbox == 0 or ctx.clock < self.flushAt then return end
    self.flushAt = ctx.clock + OUTBOX_EVERY
    local keep = {}
    for _, e in ipairs(self.outbox) do
      if ctx.clock >= e.till then
        ctx.log("carry: a release was never taken by the queue")
      elseif not ctx.send(e.msg) then
        keep[#keep + 1] = e
      end
    end
    self.outbox = keep
  end

  -- At most one frame per 1/20 s. A frame is a replaceable sample: a refused one is dropped, the next supersedes it.
  function self.pump(c, sampler)
    if ctx.clock < c.nextAt then return nil end
    c.nextAt = ctx.clock + 1.0 / CARRY.frameHz
    local pose = sampler()
    if not pose then
      c.misses = (c.misses or 0) + 1
      return nil
    end
    c.last = pose
    local msg = { v = schema.VERSION, op = "carry_frame", id = c.titan.id, epoch = c.titan.epoch, token = c.token, seq = c.seq + 1, t = round(ctx.clock, 3), pose = pose,
      launch = pose.phase == "flight" and c.launch or nil }
    if ctx.send(msg) then
      c.seq, c.lastOkAt, c.frames = c.seq + 1, ctx.clock, (c.frames or 0) + 1
    else
      c.failed = (c.failed or 0) + 1
    end
    return pose
  end

  -- A claim that was granted but never began (late grant, wrong body, refused by the controller): the owner gives it
  -- straight back with the body's actual place.
  function self.give_back(info, token, reason)
    local ent = info.ent
    local pose
    if ent ~= nil and IsDefined(ent) then
      local x, y, z = world_pos(ent)
      if x then
        local yaw = world_yaw(ent) or 0.0
        local i, j, k, r
        if info.kind == "vehicle" then i, j, k, r = world_quat(ent) end
        if not i then i, j, k, r = yaw_quat(yaw) end
        pose = schema.carry_pose({ x = x, y = y, z = z, yaw = wrap180(yaw), qx = i, qy = j, qz = k, qw = r, vx = 0.0, vy = 0.0, vz = 0.0, phase = "hold" })
      end
    end
    if not pose then
      ctx.diag("carry.giveback.nopose", "a carry grant could not be given back with a pose (the body is gone): the server's watchdog ends it")
      return
    end
    self.release({ titan = info.titan, seq = 0 }, token, pose, reason)
  end

  function self.remember_late(c)
    local count, oldest, oldestAt = 0, nil, math.huge
    for request, info in pairs(self.late) do
      count = count + 1
      if info.till < oldestAt then oldest, oldestAt = request, info.till end
    end
    if count >= LATE_LIMIT and oldest then self.late[oldest] = nil end
    self.late[c.request] = { titan = c.titan, ent = c.ent, kind = c.kind, till = ctx.clock + LATE_LIFE }
  end

  -- ---------------------------------------------------------------- ending ----------------------------------------
  -- Local end of a carry whatever the phase, then the owner's release unless the server already ended it.
  function self.abort(c, reason, opts)
    opts = opts or {}
    local env = E()
    local PS = env.PS
    self.c = nil
    self.aborts = self.aborts + 1
    ctx.log(string.format("carry: ended locally (%s) in the %s phase%s", tostring(reason), tostring(c.phase), opts.server and ": the server ended the claim" or ""))
    if c.phase == "pending" then
      local punch = c.M
      if punch then
        punch.hold, punch.hitDone[1] = nil, true
        if PS.punch == punch then self.orig.grabMiss(punch, "the carry was cancelled (" .. tostring(reason) .. ")") end
      end
      -- a grant that already came is given back now; only a grant still to come is remembered
      if c.grant then
        self.give_back(c, c.grant.token, reason)
      elseif not opts.server then
        self.remember_late(c)
      end
      return
    end
    if c.phase == "holding" then
      self.restore_body(c, reason)
    elseif c.phase == "flight" then
      self.clear_flight(c)
      resume_movers(c)
    end
    if opts.server then return end
    local pose = self.rest_pose(c)
    if pose then
      self.release(c, c.token, pose, reason)
    else
      ctx.diag("carry.release.nopose", "a carry ended with no readable pose: the server's watchdog ends the claim")
    end
  end

  function self.finish(c, reason, pose)
    self.c = nil
    resume_movers(c)
    if pose then
      self.release(c, c.token, pose, reason)
    else
      ctx.diag("carry.release.nopose", "a carry ended with no readable pose: the server's watchdog ends the claim")
    end
    ctx.log(string.format("carry: %s %s ended (%s), %d frames sent%s", c.kind, tostring(c.key), reason, c.frames or 0,
      c.flight and c.flight.via and (", thrown body read from its " .. c.flight.via .. ", moved " .. string.format("%.1f", c.flight.maxMoved or 0.0) .. " m") or ""))
  end

  -- Everything: the Titan is going away, the session is over, the owner is cleaned up.
  function self.abort_all(reason)
    local c = self.c
    if c then self.abort(c, reason) end
    self.late = {}
  end

  function self.drop_outbox()
    self.outbox = {}
  end

  -- ---------------------------------------------------------------- gate -----------------------------------------
  local function miss(M_, why)
    ctx.diag("carry.miss." .. tostring(why), "the grab ended without a carry: " .. tostring(why))
    self.orig.grabMiss(M_, why)
  end

  -- The clip waits at the grab point: the grab's hit is re-armed each frame and the pose, the yaw and the lunge stay.
  function self.pin(c, M_)
    local h = M_.clip and M_.clip.hits and M_.clip.hits[1]
    local at = h and h.t or M_.t
    M_.hitDone[1] = nil
    M_.hold = at
    M_.t = at - PIN_EPS
    local L = E().PS.lunge
    if L and L.punch == M_ then
      c.lungeT = c.lungeT or L.t
      L.t = c.lungeT
    end
  end

  local function unpin(M_)
    M_.hold = nil
    M_.hitDone[1] = true
  end

  -- Runs the controller's own target selection and refusal logic with every effect on a body held back, and says what
  -- it would have done: take a person, take a vehicle, shove something, or nothing.
  function self.probe(M_)
    local FPF = E().FPF
    local PS = E().PS
    local hits = {}
    for k, v in pairs(M_.hit) do hits[k] = v end
    local L = PS.lunge
    local scale = (L and L.punch == M_) and L.scale or nil
    local carry0 = M_.carry
    local out = {}
    self.mode, self.out = "probe", out
    local saved = { hit = FPF.hit, attack = FPF.attack, fistStagger = FPF.fistStagger, punchSound = FPF.punchSound }
    FPF.hit = function(ent) out.shove = out.shove or ent end
    FPF.attack = function() end
    FPF.fistStagger = function() end
    FPF.punchSound = function() end
    local ok, err = pcall(self.orig.tossGrab, M_)
    FPF.hit, FPF.attack, FPF.fistStagger, FPF.punchSound = saved.hit, saved.attack, saved.fistStagger, saved.punchSound
    self.mode, self.out = nil, nil
    M_.carry = carry0
    for k in pairs(M_.hit) do if hits[k] == nil then M_.hit[k] = nil end end
    for k, v in pairs(hits) do M_.hit[k] = v end
    if scale ~= nil and PS.lunge and PS.lunge.punch == M_ then PS.lunge.scale = scale end
    if not ok then error(err, 0) end
    return out
  end

  function self.begin(M_)
    if ctx.clock - self.requestAt < CARRY.requestGap then return miss(M_, "the Titan server was asked less than a second ago") end
    local out = self.probe(M_)
    local target
    if out.person then
      target = { kind = "npc", ent = out.person.ent, key = out.person.key, d = out.person.d }
    elseif out.vehicle and not out.vehicle.heavy then
      target = { kind = "vehicle", ent = out.vehicle.T.ent, key = out.vehicle.T.key, d = out.vehicle.d, T = out.vehicle.T }
    elseif out.vehicle then
      return miss(M_, "too heavy to lift: not shoved while the Titan server owns carries")
    elseif out.shove ~= nil then
      return miss(M_, "too big to lift: not shoved while the Titan server owns carries")
    else
      return miss(M_, out.miss or "nothing to take")
    end
    if target.ent == nil or not IsDefined(target.ent) then return miss(M_, "the body is gone") end
    -- The fist's own pick (the probe above) is not the offer: an occupied or NPC-driven car, a seated person, another player's
    -- body is refused here with the offer's own rule (self.allows, set by the grab module), so the server is never asked for it.
    if self.allows and not self.allows(target) then
      return miss(M_, "not a body the Titan server lets BT carry (occupied, driven, another player's or not networked)")
    end
    local id, why = native_id(target.ent)
    if not id then return miss(M_, why or "the body cannot be named") end
    self.nextRequest = self.nextRequest + 1
    local T = ctx.titan
    local c = {
      phase = "pending", M = M_, request = self.nextRequest, kind = target.kind, ent = target.ent, key = target.key, entityId = id,
      d = target.d, T = target.T, titan = { id = T.id, epoch = T.epoch }, startedAt = ctx.clock, deadline = ctx.clock + CARRY.pending, seq = 0,
    }
    local sent = ctx.send({ v = schema.VERSION, op = "carry_request", id = c.titan.id, epoch = c.titan.epoch, request = c.request, kind = c.kind, entity = id })
    if not sent then return miss(M_, "the request could not be queued (the bridge is full)") end
    self.requests = self.requests + 1
    self.requestAt = ctx.clock
    self.c = c
    self.pin(c, M_)
    ctx.log(string.format("carry: asked for %s %s (request %d)", c.kind, id, c.request))
  end

  local function deny(c, M_, why, late)
    self.c = nil
    self.denials = self.denials + 1
    if late then self.remember_late(c) end
    unpin(M_)
    ctx.log(string.format("carry: not granted (%s)", tostring(why)))
    miss(M_, "the Titan server did not grant it (" .. tostring(why) .. ")")
  end

  -- The grant is in: take exactly the body that was claimed, through the controller's own functions.
  local function commit(c, M_)
    local env = E()
    local g = c.grant
    -- The request number binds the grant to the pending request, whose exact native body the client resource already
    -- resolved before it forwarded anything. The grant names that body by its CANONICAL id (a different number from
    -- the native one the request carried), so only the kind can be compared here.
    if g.kind ~= c.kind then
      self.give_back(c, g.token, "unmatched")
      return deny(c, M_, "it granted another kind of body than the one reached for")
    end
    c.canonicalId = g.entityId
    if c.ent == nil or not IsDefined(c.ent) then
      self.give_back(c, g.token, "lost")
      return deny(c, M_, "the body is gone")
    end
    if c.kind == "vehicle" and vehicle_heavy(c.ent) then
      self.give_back(c, g.token, "refused")
      return deny(c, M_, "the vehicle is too heavy to lift")
    end
    self.grants = self.grants + 1
    unpin(M_)
    c.token, c.lastOkAt, c.nextAt = g.token, ctx.clock, 0.0
    if c.kind == "npc" then
      c.ownStun = has_stun(c.ent) ~= true
      M_.carry = { ent = c.ent, key = c.key, at = env.S.clock }
      M_.hit[c.key] = true
      local L = env.PS.lunge
      if L and L.punch == M_ then L.scale = 1.0 end
      local ok, err = pcall(self.orig.carryStart, M_, c.d)
      if not ok then
        c.Cr, c.phase = M_.carry, "holding"
        self.c = c
        self.abort(c, "refused")
        error(err, 0)
      end
    else
      local ok, err = pcall(self.orig.carTake143, M_, c.T, c.d)
      if not ok then
        self.give_back(c, g.token, "refused")
        self.c = nil
        error(err, 0)
      end
    end
    local Cr = M_.carry
    if not Cr or Cr.ent ~= c.ent or (c.kind == "vehicle") ~= (Cr.car == true) then
      self.give_back(c, g.token, "refused")
      self.c = nil
      return
    end
    c.Cr, c.phase = Cr, "holding"
    self.holds = self.holds + 1
    self.c = c
    ctx.log(string.format("carry: holding %s %s (canonical %s) under its claim (%.1f m from the hand)", c.kind, c.entityId, tostring(c.canonicalId), c.d or 0.0))
  end

  local function pending(c, M_)
    if c.deny then return deny(c, M_, c.deny) end
    if c.grant then return commit(c, M_) end
    if ctx.clock >= c.deadline then return deny(c, M_, "no answer in " .. CARRY.pending .. " s", true) end
    self.pin(c, M_)
  end

  local function gate(M_)
    local c = self.c
    if c and c.M ~= M_ then return miss(M_, "the Titan is already carrying") end
    if not c then return self.begin(M_) end
    if c.phase == "pending" then return pending(c, M_) end
  end

  -- ---------------------------------------------------------------- release (the throw) ---------------------------
  -- A held person's whole body has to stand at the held place, and its rig on it, BEFORE the controller's ragdoll
  -- throw runs: a ragdoll formed at the old root would miss its own impulse, and a body slot read before the rig stands
  -- on its root is the stale held one. Both are awaited against what the engine READS BACK (never a sleep), together for
  -- at most PLACE_WAIT from the moment the placement was asked for, with the clip pinned at the release meanwhile; if
  -- either does not arrive nothing is thrown and the body is put back - the wait is never faked.
  -- The root: the platform's placement API (place_root) places the canonical body's own root ONCE (the claim must
  -- still be live; nothing is retried through the controller's own teleports), with the offset kept, until the root
  -- READ BACK is within PLACE_NEAR of the place it was asked for. That place and its yaw are read once, when the API
  -- is asked (c.placing), and are all the wait compares with, publishes as the hold and throws from: the hand keeps
  -- moving while the root is awaited, so a later read of Cr.hold149 is another place. An API that refuses the
  -- placement (or is missing) cancels the throw at once: the body is never released from where it was taken.
  -- The body's own mover is turned off first and stays off (c.movers) through the whole throw, so that it cannot
  -- overwrite the placed root before the queued ragdoll and impulse run; abort and landing put it back.
  -- Returns true when the root stands at the requested place, false while it does not (yet), nil when the placement was refused.
  function self.place_body(c)
    local Cr = c.Cr
    local at = c.placing
    if not at then
      local H = Cr.hold149
      local owned = suspend_movers(Cr.ent)
      if owned == nil then return nil end
      if #owned > 0 then c.movers = owned end
      at = { x = H.x, y = H.y, z = H.z, yaw = wrap180(E().PS.yaw + 180.0), since = ctx.clock }
      if not place_root(Cr.ent, at.x, at.y, at.z, at.yaw) then return nil end
      c.placing = at
    end
    local x, y, z = world_pos(Cr.ent)
    return x ~= nil and dist(x, y, z, { at.x, at.y, at.z }) <= PLACE_NEAR
  end

  -- The rig: once the root stands at the held place its offset is cleared, and the throw waits until the rig's own world
  -- translation reads back on the root captured then (its mover is off, so that is where the rig has to arrive). The
  -- world and slot readback lags the write, so a slot read before it is still the held one: the clear is written again
  -- until it reads back, and the controller's tossCarry must not rewrite the offset meanwhile (see attach). True when
  -- the rig reads back on the root, false while it does not (yet), nil when the root cannot be read or the rig cannot
  -- be written (the throw is then cancelled).
  function self.settle_rig(c)
    local Cr = c.Cr
    local s = c.settle
    local fresh = s == nil
    if fresh then
      local x, y, z = world_pos(Cr.ent)
      if not x then return nil end
      if not clear_rig(Cr.root149) then return nil end
      s = { x = x, y = y, z = z }
      c.settle = s
    end
    local rx, ry, rz = component_world(Cr.root149)
    if rx and dist(rx, ry, rz, { s.x, s.y, s.z }) <= PLACE_NEAR then return true end
    if not fresh and not clear_rig(Cr.root149) then return nil end
    return false
  end

  function self.pin_release(M_)
    local h = M_.clip and M_.clip.hits and M_.clip.hits[2]
    local at = h and h.t or M_.t
    M_.hitDone[2] = nil
    M_.hold = at
    M_.t = at - PIN_EPS
  end

  -- The body stands at the place it was put and its rig stands on it (settle_rig): note where the thrown body starts.
  function self.prepare_release(c)
    local Cr = c.Cr
    local ent = Cr.ent
    local at = c.placing
    local fl = {}
    c.flight = fl
    if at and Cr.root149 then
      fl.origin, fl.yaw, fl.via0 = { at.x, at.y, at.z }, at.yaw, "rig"
    else
      local x, y, z = world_pos(ent)
      if x then fl.origin = { x, y, z } end
      fl.yaw = world_yaw(ent)
    end
    -- where one of the body's own slots stands at the moment it is let go: the thrown body's movement is read from here
    local sx, sy, sz = slot_pos(ent, self.cache)
    if sx then fl.baseSlot = { sx, sy, sz } end
  end

  -- The authored push of the throw (FPF.ragdollPush149) as the clients that watch must replay it, built from the very
  -- arguments the authored function applies: the impulse point (x, y, z), the impulse (ux, uy, uz times power), with
  -- the radius and the delay it uses, the controller clock now, and the released body's ROOT pose prepare_release
  -- noted (the placement, not the impulse point). One table that is never changed afterwards. nil plus the field that
  -- cannot be told when the arguments or the root do not describe a throw: nothing is ever guessed.
  function self.describe_launch(c, x, y, z, ux, uy, uz, power)
    local fl = c.flight
    local o = fl and fl.origin
    if not (o and finite(fl.yaw)) then return nil, "root" end
    if not (finite(x) and finite(y) and finite(z) and finite(ux) and finite(uy) and finite(uz) and finite(power)) then return nil, "push" end
    return schema.carry_launch({
      t = round(ctx.clock, 3), x = o[1], y = o[2], z = o[3], yaw = wrap180(fl.yaw),
      px = x, py = y, pz = z, ix = ux * power, iy = uy * power, iz = uz * power, radius = LAUNCH_RADIUS, delay = LAUNCH_DELAY,
    })
  end

  function self.enter_flight(c)
    local PS = E().PS
    local fl = c.flight or {}
    c.flight = fl
    c.phase = "flight"
    self.throws = self.throws + 1
    fl.t0 = ctx.clock
    if not fl.origin then
      local x, y, z = world_pos(c.Cr.ent)
      if x then fl.origin = { x, y, z } elseif c.last then fl.origin = { c.last.x, c.last.y, c.last.z } else fl.origin = { 0.0, 0.0, 0.0 } end
    end
    if c.kind == "vehicle" then
      local F = PS.carFly145
      if F and F.key == c.key then fl.F = F end
    end
    c.nextAt = 0.0
    ctx.log(string.format("carry: %s %s thrown (%s)", c.kind, c.entityId, fl.F and "the controller's own flight" or "its motion is read from the game"))
  end

  function self.on_release(M_, orig)
    local c = self.c
    if not (c and c.M == M_ and c.phase == "holding" and M_.carry == c.Cr and not c.Cr.thrown) then return orig(M_) end
    local Cr = c.Cr
    c.flight = nil
    if c.kind == "npc" then
      local H = Cr.hold149
      if Cr.root149 and H and finite(H.x) and finite(H.y) and finite(H.z) then
        local waited = c.placing ~= nil
        local placed = self.place_body(c)
        if placed == nil then
          ctx.diag("carry.place.refused", "the Titan bridge did not place a held person's body before its throw (its mover could not be turned off, the placement was refused, or the client's Open77.npcs.placeCarried is missing): the throw is cancelled and the body put back")
          return self.abort(c, "refused")
        end
        if not placed then
          if ctx.clock - c.placing.since >= PLACE_WAIT then
            ctx.diag("carry.place", "a held person's body did not reach the held place before its throw: the throw is cancelled and the body put back")
            return self.abort(c, "stalled")
          end
          return self.pin_release(M_)
        end
        local settled = self.settle_rig(c)
        if settled == nil then
          ctx.diag("carry.rig.refused", "the Titan bridge could not clear a held person's rig offset before its throw (the body's root could not be read or its rig could not be written): the throw is cancelled and the body put back")
          return self.abort(c, "refused")
        end
        if not settled then
          if ctx.clock - c.placing.since >= PLACE_WAIT then
            ctx.diag("carry.rig", "a held person's rig did not settle on its root before its throw: the throw is cancelled and the body put back")
            return self.abort(c, "stalled")
          end
          return self.pin_release(M_)
        end
        if waited then M_.hold, M_.hitDone[2] = nil, true end
        H.x, H.y, H.z = c.placing.x, c.placing.y, c.placing.z   -- the controller's throw reads the place the body was put at, not where the hand has moved on to
      end
      self.prepare_release(c)
    end
    c.releasing = true
    local ok, err = pcall(orig, M_)
    c.releasing = nil
    if not Cr.thrown then
      self.abort(c, "interrupted")
    elseif c.kind == "npc" and not c.launch then
      -- the person was thrown, but the authored push never described the throw: what observers would have to replay is unknown, so nothing is published
      ctx.diag("carry.launch", "the thrown person's authored push did not give a launch the Titan server can take (" .. tostring(c.launchWhy or "it was not made or did not finish") .. "): the throw is not published and the claim is given back")
      self.abort(c, "refused")
    else
      self.enter_flight(c)
    end
    if not ok then error(err, 0) end
  end

  -- ---------------------------------------------------------------- per frame -------------------------------------
  function self.expire_late()
    for request, info in pairs(self.late) do
      if ctx.clock >= info.till then self.late[request] = nil end
    end
  end

  -- The flight of a thrown body: the controller's own (a vehicle's kinematic one, PS.carFly145) or the body's measured
  -- motion. It lasts CARRY.flightMax from the throw, which is what the server allows from the flight's first pose; a
  -- hold has no time limit of its own and is not counted here.
  local function flight_tick(c)
    local fl = c.flight
    local env = E()
    local age = ctx.clock - fl.t0
    if c.Cr.ent == nil or not IsDefined(c.Cr.ent) then return self.finish(c, "lost", c.last) end
    if fl.F then
      if env.PS.carFly145 ~= fl.F then
        -- The authored flight is over: on the ground, or - the port's end of a flight at the server's allowance, F.lost - with
        -- no ground anywhere under it, which is a flight that ran out of time and not a landing.
        return self.finish(c, fl.F.lost and "flight_timeout" or "landed", self.flight_pose(c) or c.last)
      end
      self.pump(c, function() return self.flight_pose(c) end)
    else
      self.pump(c, function() return self.measure_free(c) end)
      if fl.unobserved then
        ctx.diag("carry.unobserved", "a thrown body showed no motion the game lets the bridge read (neither its root nor its slots moved): the throw is not published")
        return self.finish(c, "unobserved", c.last)
      end
      if fl.rest then return self.finish(c, "landed", c.last) end
    end
    if age >= CARRY.flightMax then
      -- the release pose becomes the canonical final pose: read the body now rather than reuse the last 20 Hz sample
      local pose = (fl.F and self.flight_pose(c)) or (not fl.F and self.measure_free(c)) or c.last
      return self.finish(c, "flight_timeout", pose or c.last)
    end
  end

  function self.tick()
    self.flush()
    local c = self.c
    if not c then
      self.expire_late()
      return
    end
    local env = E()
    local PS = env.PS
    if not ctx.session.active then return self.abort(c, "session_end") end
    local T = ctx.titan
    if not T or T.id ~= c.titan.id or T.epoch ~= c.titan.epoch or PS.ent == nil then return self.abort(c, "titan_gone") end
    if c.phase == "pending" then
      if PS.punch ~= c.M then return self.abort(c, "interrupted") end
      if ctx.clock > c.deadline + 0.5 then return self.abort(c, "timeout") end
      return
    end
    local Cr = c.Cr
    if c.phase == "holding" then
      if Cr.ent == nil or not IsDefined(Cr.ent) then return self.abort(c, "lost") end
      if Cr.thrown or PS.punch ~= c.M or c.M.carry ~= Cr then return self.abort(c, "interrupted") end
      self.pump(c, function() return self.hold_pose(c) end)
      if ctx.clock - c.lastOkAt > CARRY.stall then return self.abort(c, "stalled") end
      return
    end
    flight_tick(c)
  end

  -- ---------------------------------------------------------------- from the resource -----------------------------
  function self.inbound(msg)
    local T = ctx.titan
    local op = msg.op
    if op == "carry_grant" then
      if not T or T.id ~= msg.id or T.epoch ~= msg.epoch then
        ctx.diag("carry.grant.stale", "a carry grant for another Titan was ignored")
        return
      end
      local c = self.c
      if c and c.phase == "pending" and c.request == msg.request then
        c.grant = { token = msg.token, kind = msg.kind, entityId = msg.entityId }
        return
      end
      local late = self.late[msg.request]
      if late then
        self.late[msg.request] = nil
        self.give_back(late, msg.token, "timeout")
        return
      end
      ctx.diag("carry.grant.unknown", "a carry grant nobody asked for was ignored (the server's watchdog ends it)")
    elseif op == "carry_denied" then
      local c = self.c
      if c and c.phase == "pending" and c.request == msg.request then
        c.deny = msg.reason
      elseif self.late[msg.request] then
        self.late[msg.request] = nil
      end
    elseif op == "carry_ended" then
      local c = self.c
      if c and c.titan.id == msg.id and c.titan.epoch == msg.epoch then
        if c.token == msg.token then
          self.abort(c, "interrupted", { server = true })
          ctx.log("carry: the server ended the claim (" .. tostring(msg.reason) .. ")")
        elseif c.phase == "pending" and c.grant and c.grant.token == msg.token then
          -- The server released the claim before its grant was ever committed here (both came in one drain): nothing is
          -- taken, and the released claim is not given back either. The reach ends as a denial at its next re-arm.
          c.grant, c.deny = nil, "the server ended the claim (" .. tostring(msg.reason) .. ")"
          ctx.log("carry: the server ended the claim before it was taken (" .. tostring(msg.reason) .. ")")
        end
      end
    end
  end

  -- ---------------------------------------------------------------- the controller ---------------------------------
  local REQUIRED = { "grabStart", "grabMiss", "tossGrab", "carryStart", "carTake143", "tossCarry", "tossRelease", "holdLetGo149", "ragdollPush149", "hit", "attack", "fistStagger", "punchSound" }

  function self.attach(env)
    local FPF = env.FPF
    for _, name in ipairs(REQUIRED) do
      if FPF[name] == nil then error("controller function FPF." .. name .. " missing: this is not the supported release", 0) end
    end
    self.reset()
    local orig = { grabMiss = FPF.grabMiss, tossGrab = FPF.tossGrab, carryStart = FPF.carryStart, carTake143 = FPF.carTake143, tossCarry = FPF.tossCarry, tossRelease = FPF.tossRelease, ragdollPush149 = FPF.ragdollPush149 }
    self.orig = orig

    FPF.grabMiss = function(M_, why)
      if self.mode == "probe" then
        self.out.miss = self.out.miss or tostring(why)
        return
      end
      return orig.grabMiss(M_, why)
    end

    FPF.tossGrab = function(M_)
      if not enabled() then
        local c = self.c
        if c and c.M == M_ then return self.abort(c, ctx.session.active and "titan_gone" or "session_end") end
        return orig.tossGrab(M_)
      end
      return gate(M_)
    end

    FPF.carryStart = function(M_, d)
      if self.mode == "probe" then
        local Cr = M_.carry
        self.out.person = { ent = Cr and Cr.ent, key = Cr and Cr.key, d = d }
        return
      end
      if not enabled() then return orig.carryStart(M_, d) end
      ctx.diag("carry.ungated", "the controller tried to take a body that the Titan server did not grant: refused")
      if M_.carry and M_.carry.key then M_.hit[M_.carry.key] = nil end
      M_.carry = nil
      return orig.grabMiss(M_, "the carry was not granted by the Titan server")
    end

    FPF.carTake143 = function(M_, T, d)
      if self.mode == "probe" then
        self.out.vehicle = { T = T, d = d, heavy = vehicle_heavy(T.ent) }
        return
      end
      if not enabled() then return orig.carTake143(M_, T, d) end
      ctx.diag("carry.ungated", "the controller tried to take a body that the Titan server did not grant: refused")
      return orig.grabMiss(M_, "the carry was not granted by the Titan server")
    end

    FPF.tossRelease = function(M_)
      return self.on_release(M_, orig.tossRelease)
    end

    -- The throw's one push of the body this carry is releasing: the authored function runs once, with its own
    -- arguments and its own results and errors, and the launch is taken from those arguments only when it returned.
    -- Every other call of it - another body, no carry, a release not under way - is the authored function untouched.
    local function took(c, launch, ...)
      c.launch = launch
      return ...
    end
    FPF.ragdollPush149 = function(ent, ...)
      local c = self.c
      if not (c and c.releasing and c.kind == "npc" and c.launch == nil and c.Cr and c.Cr.ent == ent) then
        return orig.ragdollPush149(ent, ...)
      end
      local x, y, z, ux, uy, uz, power = ...
      local described, launch, why = pcall(self.describe_launch, c, x, y, z, ux, uy, uz, power)
      if not described then launch, why = nil, "error" end
      if not launch then
        c.launchWhy = why
        return orig.ragdollPush149(ent, ...)
      end
      return took(c, launch, orig.ragdollPush149(ent, ...))
    end

    -- While the rig offset is being cleared for the throw (settle_rig) the authored hold must not run: it writes the
    -- offset to the moving hand on every frame, after the release hit of that same frame, which would undo the clear -
    -- and it counts a cleared offset as the game putting the skeleton's component back (three of those drop the hold).
    FPF.tossCarry = function(M_)
      local c = self.c
      if c and c.M == M_ and c.settle and c.phase == "holding" and M_.carry == c.Cr then return end
      return orig.tossCarry(M_)
    end
  end

  -- /titan action grab: the controller's own input path (the Reload action sets PS.reloadKey, the gun frame turns it
  -- into the fists' GRAB, the perk gate applies). Returns true or false and the reason.
  function self.request_grab()
    local env = E()
    local S, PS = env.S, env.PS
    if not (S.driving and S.pilot and PS.mode == "pilot") then return false, "BT has to be piloted to grab" end
    if PS.weapon ~= "fist" then return false, "grab needs the fists (use the fist weapon first)" end
    if PS.punch or self.c then return false, "BT's fist is busy" end
    PS.reloadKey = true
    ctx.releases[#ctx.releases + 1] = { field = "reloadKey", at = ctx.clock + 0.4 }
    return true
  end

  return self
end

return M
