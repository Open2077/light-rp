-- Observer side: one independent remote BT per network id.
--
-- Every relayed `state` (20 Hz, already validated by open77_titan_schema) becomes a sample of that Titan's own
-- timeline. Each game frame the Titan is placed and its animation graph driven from the interpolated sample at a
-- fixed render delay behind the newest one; events are applied when the render time reaches their sample (each
-- exactly once, by sequence); the persistent `visuals` of the newest sample bring a late joiner up to date.
-- The remote entity is the same BT entity the owner pilots, spawned without any controller: nothing here reads
-- input, applies damage, or creates hit events.

local _ENV = require("controller.open77_titan_env")
local schema = require("controller.open77_titan_schema")
local audio = require("controller.open77_titan_audio")

local M = {}

local RENDER_DELAY = 0.12     -- seconds behind the newest sample
local EXTRAPOLATE = 0.25      -- longest extrapolation past the newest sample
local LINGER = 2.5            -- a removed Titan stays so its last effects and sounds play out
local SILENT = 8.0            -- no state for this long: the owner is gone, remove
local SPAWN_WAIT = 6.0
local WARM_STEPS, WARM_FRAMES = 14, 3   -- the controller's own graph warm-up (copied from its warmFrame)
local STOP_GRACE = 0.6        -- BreakLoop, then Kill after this
local VAR_EPSILON, VAR_REFRESH = 0.0005, 0.5
local REMOTE_TAG = "Open77TitanRemote"   -- the DynamicEntitySystem tag of every remote Titan's entity
M.TAG = REMOTE_TAG

local function lerp(a, b, u) return a + (b - a) * u end

local function lerp_angle(a, b, u)
  local d = ((b - a + 180.0) % 360.0) - 180.0
  return a + d * u
end

local function quaternion(rot)
  if rot.w ~= nil then return Quaternion.new(rot.x, rot.y, rot.z, rot.w) end
  return EulerAngles.ToQuat(EulerAngles.new(rot.x, rot.y, rot.z))
end

local function transform_of(pos, rot)
  local tr = WorldTransform.new()
  WorldTransform.SetPosition(tr, Vector4.new(pos.x, pos.y, pos.z, 1.0))
  if rot then pcall(function() WorldTransform.SetOrientation(tr, quaternion(rot)) end) end
  return tr
end

function M.new(ctx)
  local self = { remote = {}, count = 0, tracers = {}, spawned = 0, disabledDraw = false }
  local sounds = audio.new(ctx)

  local function env() return ctx.env end

  -- ------------------------------------------------------------------ small helpers ----------------------------
  local function valid(fx)
    if fx.inst == nil then return false end
    if ctx.clock - fx.born < 0.3 then return true end
    local ok, v = pcall(function() return fx.inst:IsValid() end)
    return ok and v == true
  end

  local function period_of(name)
    local E = env()
    if name == "bt_time" then return E.AHEAD and E.AHEAD.time end
    if name == "bt_time_back" then return E.BACK and E.BACK.time end
    if name == "bt_time_sprint" then return E.SPRINT and E.SPRINT.time end
    return nil
  end

  local function interpolate_vars(a, b, u)
    local out = {}
    for name, va in pairs(a) do
      local vb = b[name]
      if vb == nil or name:find("_clip$") then
        out[name] = va
      else
        local period = period_of(name)
        if period and period > 0 then
          if vb < va then vb = vb + period end
          out[name] = lerp(va, vb, u) % period
        elseif name:find("^bt_time") and vb < va - 0.001 then
          out[name] = (u >= 1.0) and vb or va
        else
          out[name] = lerp(va, vb, u)
        end
      end
    end
    for name, vb in pairs(b) do
      if out[name] == nil then out[name] = vb end
    end
    return out
  end

  -- the interpolated (or briefly extrapolated) state at render time T
  local function sample_at(R, T)
    local s = R.samples
    local n = #s
    if n == 0 then return nil end
    local first, last = s[1], s[n]
    if T <= first.te or n == 1 then return first, first, 0.0 end
    if T >= last.te then
      return last, last, 0.0, math.min(T - last.te, EXTRAPOLATE), s[n - 1]
    end
    for i = n - 1, 1, -1 do
      if s[i].te <= T then
        local a, b = s[i], s[i + 1]
        local span = b.te - a.te
        return a, b, (span > 1e-6) and ((T - a.te) / span) or 1.0
      end
    end
    return first, first, 0.0
  end

  -- ------------------------------------------------------------------ remote entity ----------------------------
  local function spawn(R)
    local E = env()
    local player = Game.GetPlayer()
    if not player then return end
    local s = R.samples[#R.samples]
    local tr = player:GetWorldTransform()
    WorldTransform.SetPosition(tr, Vector4.new(s.pose.x, s.pose.y, s.pose.z, 1.0))
    pcall(function() WorldTransform.SetOrientation(tr, EulerAngles.ToQuat(EulerAngles.new(0, 0, s.pose.yaw))) end)
    R.entId = ctx.spawn(E.PILOT_ENT, tr, "", REMOTE_TAG)
    R.spawnAt = ctx.clock
    R.spawnTries = (R.spawnTries or 0) + 1
    self.spawned = self.spawned + 1
  end

  local function component(R, name)
    local comp = R.comps[name]
    if comp == nil then
      local ok, found = pcall(function() return R.ent:FindComponentByName(name) end)
      comp = (ok and found) or false
      R.comps[name] = comp
    end
    return comp or nil
  end

  local function toggle_meshes(R, state)
    for name in pairs(schema.catalog.meshes) do
      local want = state[name] == true
      if R.meshApplied[name] ~= want then
        local comp = component(R, name)
        if comp then
          pcall(function() comp:Toggle(want) end)
          R.meshApplied[name] = want
        end
      end
    end
  end

  local function toggle_lights(R, state)
    for name in pairs(schema.catalog.lights) do
      local want = state[name] == true
      if R.lightApplied[name] ~= want then
        local comp = component(R, name)
        if comp then
          if not pcall(function() comp:ToggleLight(want) end) then pcall(function() comp:Toggle(want) end) end
          R.lightApplied[name] = want
        end
      end
    end
  end

  local function set_var(R, name, value, force)
    local last = R.sentVars[name]
    if not force and last ~= nil and math.abs(last - value) < VAR_EPSILON and ctx.clock - R.sentAt[name] < VAR_REFRESH then return end
    R.sentVars[name], R.sentAt[name] = value, ctx.clock
    AnimationControllerComponent.SetInputFloat(R.ent, name, value)
  end

  local function warm_values(R, i)
    local E = env()
    local s = i - 1
    local v = {
      bt_pilot = 0.004, bt_scene = 0.004, bt_pods = 0.004, bt_reload = 0.004, bt_melee = 0.004, bt_vortex = 0.004,
      bt_sword_hold = 0.004, bt_sword_block = 0.004, bt_charge = 0.004, bt_fist_guard = 0.004, bt_fist_block = 0.004,
      bt_jab = 0.004, bt_fist_guard_r = 0.004,
      bt_melee_clip = math.min(31.5, (s % 17) * 2 + 0.5), bt_reload_clip = 0.0,
      bt_charge_clip = (s % 2 == 0) and 0.5 or 1.5, bt_jab_clip = math.min(8.5, (s % 5) * 2 + 0.5),
      bt_aim_yaw = (s % 2 == 0) and -30.0 or 30.0, bt_aim_pitch = (s % 4 < 2) and -20.0 or 20.0,
      bt_turn_clip = 1.5 + 2.0 * (s % 3),
    }
    for _, name in ipairs({ "bt_move", "bt_sprint", "bt_back", "bt_dash", "bt_stance", "bt_settled", "bt_turn", "bt_sentry", "bt_sentry_out" }) do
      v[name] = 0.5
    end
    local dir = (math.floor(s / 4) % 2 == 0) and 45.0 or -45.0
    v.bt_dir, v.bt_dir_back = dir, dir
    local scenes = E.FPC and E.FPC.warmScenes
    v.bt_scene_clip = (scenes and #scenes > 0) and scenes[s % #scenes + 1] or 1.0
    return v
  end

  local function dispose_entity(R)
    if R.ent then
      local ent = R.ent
      pcall(function() ent:Dispose() end)
    end
    R.ent, R.entId = nil, nil
  end

  -- ------------------------------------------------------------------ effects ---------------------------------
  local function place_fx(fx, pos, rot)
    if not valid(fx) then return end
    pcall(function() fx.inst:UpdateTransform(transform_of(pos, rot)) end)
  end

  local function spawn_fx(R, f)
    if R.fx[f.fxId] or R.fxDead[f.fxId] then return end
    local tr = transform_of(f.position, f.rotation)
    local inst
    local ok, err = pcall(function() inst = Game.GetFxSystem():SpawnEffect(gameFxResource.new({ effect = RaRef(f.path) }), tr) end)
    if not ok or inst == nil then
      ctx.diag("observer.fx", "a remote effect could not be started (" .. tostring(f.path) .. "): " .. tostring(err))
      return
    end
    local fx = { inst = inst, born = ctx.clock, cur = f.position, to = f.position, rot = f.rotation }
    if f.target then
      pcall(function()
        local wp = NewObject("WorldPosition")
        WorldPosition.SetVector4(wp, Vector4.new(f.target.x, f.target.y, f.target.z, 1.0))
        inst:UpdateTargetPosition(wp)
      end)
    end
    R.fx[f.fxId] = fx
  end

  local function stop_fx(R, id)
    local fx = R.fx[id]
    R.knownFx[id] = nil
    R.fxDead[id] = ctx.clock
    if not fx then return end
    R.fx[id] = nil
    if valid(fx) then
      pcall(function() fx.inst:BreakLoop() end)
      R.dying[#R.dying + 1] = { inst = fx.inst, at = ctx.clock + STOP_GRACE, born = fx.born }
    end
  end

  local function move_fx(R, ev)
    local fx = R.fx[ev.fxId]
    if not fx then return end
    if ev.position then fx.to = ev.position end
    if ev.rotation then fx.rot = ev.rotation end
    if ev.target and valid(fx) then
      pcall(function()
        local wp = NewObject("WorldPosition")
        WorldPosition.SetVector4(wp, Vector4.new(ev.target.x, ev.target.y, ev.target.z, 1.0))
        fx.inst:UpdateTargetPosition(wp)
      end)
    end
    if ev.slot and R.ent and valid(fx) then
      pcall(function()
        local lt = WorldTransform.new()
        fx.inst:AttachToSlot(R.ent, entAttachmentTarget.Transform, CName.new(ev.slot), lt)
      end)
      fx.slot = ev.slot
    end
  end

  local function attached(R, name, action)
    if not R.ent then return end
    if schema.ONE_SHOT_ATTACHED[name] then
      -- one burst per sequenced start, never held: it is not an R.attached loop, and the controller never stops it
      if action == "start" then pcall(function() GameObjectEffectHelper.StartEffectEvent(R.ent, CName.new(name), false) end) end
      return
    end
    if action == "start" then
      if R.attached[name] then return end
      R.attached[name] = ctx.clock
      pcall(function() GameObjectEffectHelper.StartEffectEvent(R.ent, CName.new(name), false) end)
    elseif R.attached[name] then
      R.attached[name] = nil
      if action == "break" then
        pcall(function() GameObjectEffectHelper.BreakEffectLoopEvent(R.ent, CName.new(name)) end)
      else
        pcall(function() GameObjectEffectHelper.StopEffectEvent(R.ent, CName.new(name)) end)
      end
    end
  end

  local function add_tracer(R, ev, remaining)
    local E = env()
    if #self.tracers >= 96 then table.remove(self.tracers, 1) end
    self.tracers[#self.tracers + 1] = {
      from = ev.from, to = ev.to, at = ctx.clock, life = remaining or ev.life, streak = (E.XO16 and E.XO16.tracer) or 0.07,
      color = ev.color or { r = 255, g = 184, b = 64, a = 242 }, mark = ev.mark or "hit",
    }
  end

  local function apply_event(R, ev)
    local kind = ev.kind
    if kind == "fx_spawn" then spawn_fx(R, ev)
    elseif kind == "fx_move" then move_fx(R, ev)
    elseif kind == "fx_stop" then stop_fx(R, ev.fxId)
    elseif kind == "attached_fx" then attached(R, ev.name, ev.action)
    elseif kind == "sound" then sounds.play(R, ev)
    elseif kind == "sound_stop" then sounds.stop(R, ev)
    elseif kind == "tracer" then add_tracer(R, ev)
    end
  end

  -- the newest sample's persistent state: starts what a late joiner (or a dropped event) missed
  local function reconcile(R, visuals)
    local seenAttached, seenLoops = {}, {}
    for _, v in ipairs(visuals) do
      if v.kind == "fx" then
        if not R.knownFx[v.fxId] and not R.fx[v.fxId] and not R.fxDead[v.fxId] then spawn_fx(R, v) end
      elseif v.kind == "attached" then
        -- a one-shot is an event of its moment: in a snapshot it is stale (late joiner, old or malformed frame)
        if not schema.ONE_SHOT_ATTACHED[v.name] then
          seenAttached[v.name] = true
          if not R.attached[v.name] then attached(R, v.name, "start") end
        end
      elseif v.kind == "sound" then
        seenLoops[v.name] = true
        if not R.loops[v.name] then
          R.loops[v.name] = ctx.clock
          sounds.play(R, v)
        end
      elseif v.kind == "tracer" then
        if not R.baseline then add_tracer(R, v, v.life) end
      end
    end
    for name, since in pairs(R.attached) do
      if not seenAttached[name] and ctx.clock - since > 2.0 then attached(R, name, "stop") end
    end
    for name, since in pairs(R.loops) do
      if not seenLoops[name] and ctx.clock - since > 2.0 then
        R.loops[name] = nil
        sounds.stop(R, { name = name, backend = "audioxl" })
      end
    end
    R.baseline = true
  end

  -- ------------------------------------------------------------------ per-frame update --------------------------
  local function drive(R, dt)
    local E = env()
    local renderT = ctx.clock - RENDER_DELAY
    local a, b, u, ahead, prev = sample_at(R, renderT)
    if not a then return end
    -- pose
    local p = { x = lerp(a.pose.x, b.pose.x, u), y = lerp(a.pose.y, b.pose.y, u), z = lerp(a.pose.z, b.pose.z, u), yaw = lerp_angle(a.pose.yaw, b.pose.yaw, u) }
    local span_known
    if ahead and ahead > 0 and prev then
      local span = a.te - prev.te
      if span > 1e-3 then
        local vx, vy, vz = (a.pose.x - prev.pose.x) / span, (a.pose.y - prev.pose.y) / span, (a.pose.z - prev.pose.z) / span
        if vx * vx + vy * vy + vz * vz < 900.0 then
          p.x, p.y, p.z = p.x + vx * ahead, p.y + vy * ahead, p.z + vz * ahead
        end
        span_known = span
      end
    end
    R.pose = p
    pcall(function()
      Game.GetTeleportationFacility():Teleport(R.ent, Vector4.new(p.x, p.y, p.z, 1.0), EulerAngles.new(0, 0, p.yaw))
    end)
    -- animation graph
    local vars = interpolate_vars(a.vars, b.vars, u)
    if ahead and ahead > 0 and prev and span_known then
      for name, v in pairs(vars) do
        if name:find("^bt_time") and prev.vars[name] then
          local rate = (a.vars[name] - prev.vars[name]) / span_known
          if rate > 0 and rate < 4.0 then
            local period = period_of(name)
            local x = v + rate * ahead
            vars[name] = period and (x % period) or x
          end
        end
      end
    end
    for name, v in pairs(vars) do
      if schema.catalog.variables[name] then set_var(R, name, v, false) end
    end
    -- discrete state follows the sample the render time has reached
    toggle_meshes(R, a.meshes)
    toggle_lights(R, a.lights)
    R.mode, R.weapon = a.mode, a.weapon
    -- events due at the render time, in sequence
    local pending, keep = R.pending, {}
    for i = 1, #pending do
      local item = pending[i]
      if item.te <= renderT then
        if item.ev.seq > R.evSeq then
          R.evSeq = item.ev.seq
          local ok, err = pcall(apply_event, R, item.ev)
          if not ok then ctx.diag("observer.event." .. item.ev.kind, "a remote Titan event failed (" .. item.ev.kind .. "): " .. tostring(err)) end
        end
      else
        keep[#keep + 1] = item
      end
    end
    R.pending = keep
    -- drop samples the render time has passed (keep one before it)
    while #R.samples > 2 and R.samples[2].te <= renderT - 1.0 do table.remove(R.samples, 1) end
    -- effects: smooth movement, delayed kills
    for _, fx in pairs(R.fx) do
      local d = (fx.to.x - fx.cur.x) ^ 2 + (fx.to.y - fx.cur.y) ^ 2 + (fx.to.z - fx.cur.z) ^ 2
      if d > 1e-6 and not fx.slot then
        local k = math.min(1.0, dt / 0.05)
        fx.cur = { x = lerp(fx.cur.x, fx.to.x, k), y = lerp(fx.cur.y, fx.to.y, k), z = lerp(fx.cur.z, fx.to.z, k) }
        place_fx(fx, fx.cur, fx.rot)
      end
    end
    if ctx.clock >= (R.pruneAt or 0.0) then
      R.pruneAt = ctx.clock + 1.0
      sounds.maintain(R)
      for id, fx in pairs(R.fx) do
        if ctx.clock - fx.born > 1.0 and not valid(fx) then R.fx[id], R.knownFx[id] = nil, nil end
      end
      for id, at in pairs(R.fxDead) do
        if ctx.clock - at > 30.0 then R.fxDead[id] = nil end
      end
    end
    if #R.dying > 0 then
      local alive = {}
      for _, d in ipairs(R.dying) do
        if ctx.clock >= d.at then
          local inst = d.inst
          local ok, v = pcall(function() return inst:IsValid() end)
          if ok and v then pcall(function() inst:Kill() end) end
        else
          alive[#alive + 1] = d
        end
      end
      R.dying = alive
    end
  end

  local function tick_remote(R, dt)
    if R.state == "ending" then
      if ctx.clock >= R.endAt then self.dispose(R, "linger over") end
      if R.ent then drive(R, dt) end
      return
    end
    if ctx.clock - R.lastRecv > SILENT then
      ctx.log("remote Titan " .. R.id .. " has been silent for " .. SILENT .. " s: removed")
      R.state, R.endAt = "ending", ctx.clock
      return
    end
    if R.state == "spawn" then
      if not R.entId then
        spawn(R)
        return
      end
      local ent = Game.FindEntityByID(R.entId)
      if ent and IsDefined(ent) then
        R.ent = ent
        pcall(function() env().FPF.animAlways(ent, "remote BT " .. R.id) end)
        for name in pairs(schema.catalog.meshes) do
          local comp = component(R, name)
          if comp then pcall(function() comp:Toggle(false) end) end
          R.meshApplied[name] = false
        end
        R.state, R.warm = "warm", { i = 1, f = 0 }
      elseif ctx.clock - R.spawnAt > SPAWN_WAIT then
        ctx.diag("observer.spawn", "a remote Titan entity never arrived (is the BT archive installed on this client?)")
        R.entId = nil
        if R.spawnTries >= 3 then R.state, R.endAt = "ending", ctx.clock end
      end
      return
    end
    if not (R.ent and IsDefined(R.ent)) then
      -- the entity was streamed out or deleted: bring it back from the newest sample
      R.ent, R.entId, R.comps, R.meshApplied, R.lightApplied, R.sentVars, R.sentAt, R.state = nil, nil, {}, {}, {}, {}, {}, "spawn"
      R.spawnTries = 0
      return
    end
    if R.state == "warm" then
      R.warm.f = R.warm.f + 1
      if R.warm.f > WARM_FRAMES then R.warm.f, R.warm.i = 1, R.warm.i + 1 end
      if R.warm.i > WARM_STEPS then
        R.state, R.sentVars, R.sentAt = "live", {}, {}
        local last = R.samples[#R.samples]
        if last then for name, v in pairs(last.vars) do if schema.catalog.variables[name] then set_var(R, name, v, true) end end end
        R.pose = R.samples[#R.samples].pose
        return
      end
      for name, v in pairs(warm_values(R, R.warm.i)) do
        if schema.catalog.variables[name] then AnimationControllerComponent.SetInputFloat(R.ent, name, v) end
      end
      pcall(function()
        local s = R.samples[#R.samples].pose
        Game.GetTeleportationFacility():Teleport(R.ent, Vector4.new(s.x, s.y, s.z, 1.0), EulerAngles.new(0, 0, s.yaw))
      end)
      return
    end
    drive(R, dt)
  end

  -- ------------------------------------------------------------------ public ----------------------------------
  function self.dispose(R, why)
    if not self.remote[R.id] or self.remote[R.id] ~= R then return end
    self.remote[R.id] = nil
    self.count = self.count - 1
    for id in pairs(R.fx) do
      local fx = R.fx[id]
      if valid(fx) then pcall(function() fx.inst:Kill() end) end
    end
    for _, d in ipairs(R.dying) do pcall(function() d.inst:Kill() end) end
    for name in pairs(R.attached) do attached(R, name, "stop") end
    for name in pairs(R.loops) do sounds.stop(R, { name = name, backend = "audioxl" }) end
    sounds.release(R)
    dispose_entity(R)
    ctx.log("remote Titan " .. R.id .. " disposed (" .. tostring(why) .. ")")
  end

  local function new_remote(msg)
    return {
      id = msg.id, epoch = msg.epoch, owner = msg.owner, seq = 0, evSeq = 0, samples = {}, pending = {}, state = "spawn",
      comps = {}, meshApplied = {}, lightApplied = {}, sentVars = {}, sentAt = {}, fx = {}, fxDead = {}, knownFx = {}, dying = {},
      attached = {}, loops = {}, lastRecv = ctx.clock, emitter = "open77_titan_" .. msg.id,
    }
  end

  -- A validated relayed state (schema.state result).
  function self.state(msg)
    if ctx.titan and (msg.id == ctx.titan.id or msg.owner == ctx.session.player) then return end
    local R = self.remote[msg.id]
    if R and msg.epoch < R.epoch then return end
    if R and msg.epoch > R.epoch then
      self.dispose(R, "new epoch")
      R = nil
    end
    if not R then
      if self.count >= schema.CAPS.remoteTitans then
        ctx.diag("observer.cap", "more than " .. schema.CAPS.remoteTitans .. " remote Titans: the extra ones are not rendered")
        return
      end
      R = new_remote(msg)
      self.remote[msg.id] = R
      self.count = self.count + 1
      ctx.log("remote Titan " .. msg.id .. " (owner " .. msg.owner .. ", epoch " .. msg.epoch .. ") appears")
    elseif R.state == "ending" then
      return
    end
    if msg.seq <= R.seq then return end
    R.seq, R.lastRecv = msg.seq, ctx.clock
    local d = ctx.clock - msg.t
    if R.offset == nil or d < R.offset then R.offset = d else R.offset = R.offset + (d - R.offset) * 0.02 end
    local te = msg.t + R.offset
    local last = R.samples[#R.samples]
    if last and te <= last.te then te = last.te + 1e-3 end
    R.samples[#R.samples + 1] = {
      te = te, pose = msg.pose, vars = msg.vars, meshes = msg.meshes, lights = msg.lights, mode = msg.mode, weapon = msg.weapon,
    }
    if #R.samples > 16 then table.remove(R.samples, 1) end
    for _, ev in ipairs(msg.events) do
      if ev.seq > R.evSeq then
        if #R.pending >= 512 then table.remove(R.pending, 1) end
        R.pending[#R.pending + 1] = { te = te, ev = ev }
        if ev.kind == "fx_spawn" then R.knownFx[ev.fxId] = true end
      end
    end
    if R.state == "live" or R.state == "warm" or R.state == "spawn" then R.visuals = msg.visuals end
  end

  function self.remove(id, epoch, why)
    local R = self.remote[id]
    if not R or (epoch and epoch < R.epoch) then return end
    if R.state ~= "ending" then R.state, R.endAt = "ending", ctx.clock + LINGER end
    ctx.log("remote Titan " .. id .. " removed (" .. tostring(why) .. ")")
  end

  function self.clear(why)
    for _, R in pairs(self.remote) do self.dispose(R, why) end
    self.tracers = {}
  end

  function self.tick(dt)
    for _, R in pairs(self.remote) do
      local ok, err = pcall(tick_remote, R, dt)
      if not ok then ctx.diag("observer.tick." .. R.id, "remote Titan " .. R.id .. " failed: " .. tostring(err)) end
      if R.visuals and R.state == "live" then
        local ok2, err2 = pcall(reconcile, R, R.visuals)
        R.visuals = nil
        if not ok2 then ctx.diag("observer.visuals", "remote Titan visuals failed: " .. tostring(err2)) end
      end
    end
  end

  function self.snapshot()
    local out = {}
    for id, R in pairs(self.remote) do
      out[#out + 1] = string.format("%s:%s epoch %d samples %d pending %d fx %d", id, R.state, R.epoch, #R.samples, #R.pending, (function() local n = 0 for _ in pairs(R.fx) do n = n + 1 end return n end)())
    end
    table.sort(out)
    return out
  end

  -- Tracer streaks of remote Titans, drawn from the local camera inside the Titan frame's overlay pass.
  function self.draw()
    if #self.tracers == 0 or self.disabledDraw then return end
    local ok, err = pcall(function()
      local w, h = render.size()
      local cx, cy = w * 0.5, h * 0.5
      local cam = Game.GetCameraSystem()
      local function screen(p)
        local q = cam:ProjectPoint(Vector4.new(p.x, p.y, p.z, 1.0))
        return cx + q.x * cx, cy - q.y * cy, q.w
      end
      local function col(c, a) return GetColorU32(c.r / 255.0, c.g / 255.0, c.b / 255.0, (a or c.a or 255) / 255.0) end
      local keep = {}
      for _, t in ipairs(self.tracers) do
        local age = ctx.clock - t.at
        if age < t.life then
          keep[#keep + 1] = t
          if age < t.streak then
            local u = age / t.streak
            local a, b = math.max(0.0, u - 0.4), math.min(1.0, u + 0.1)
            local p1 = { x = lerp(t.from.x, t.to.x, a), y = lerp(t.from.y, t.to.y, a), z = lerp(t.from.z, t.to.z, a) }
            local p2 = { x = lerp(t.from.x, t.to.x, b), y = lerp(t.from.y, t.to.y, b), z = lerp(t.from.z, t.to.z, b) }
            local x1, y1, w1 = screen(p1)
            local x2, y2, w2 = screen(p2)
            if (w1 == nil or w1 > 0) and (w2 == nil or w2 > 0) then
              render.line(x1, y1, x2, y2, col(t.color, 56), 9)
              render.line(x1, y1, x2, y2, col(t.color), 3)
              render.line(x1, y1, x2, y2, GetColorU32(1.0, 0.97, 0.85, 1.0), 1)
            end
          elseif t.mark ~= "none" then
            local x, y, wh = screen(t.to)
            if wh == nil or wh > 0 then
              local c = col(t.color)
              render.line(x - 7, y - 7, x + 7, y + 7, c, 2)
              render.line(x - 7, y + 7, x + 7, y - 7, c, 2)
            end
          end
        end
      end
      self.tracers = keep
    end)
    if not ok then
      self.disabledDraw = true
      ctx.diag("observer.draw", "remote tracers cannot be drawn (no place on screen for a point of the world): " .. tostring(err))
    end
  end

  return self
end

return M
