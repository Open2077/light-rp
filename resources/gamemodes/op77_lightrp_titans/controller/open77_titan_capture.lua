-- Owner side: what the original BT controller shows the world, captured at the output seams.
--
-- The patched controller calls the hooks below from every place it writes to BT's animation graph, spawns or
-- moves a world effect, plays a sound on BT, starts an effect BT carries, or draws a tracer. The hooks always
-- let the native call happen unchanged; they only record it. Every 1/20 s `frame()` turns what was recorded into
-- one bounded v=1 frame (full variable, mesh and light snapshot, persistent visuals, new events) for the relay.
-- Presentation, plus one bounded gameplay report per frame: nothing here touches damage, hit events or the owner's
-- controls; the report only READS what the controller already keeps (open77_titan_gameplay.snapshot).

local _ENV = require("controller.open77_titan_env")
local json = require("controller.open77_titan_json")
local schema = require("controller.open77_titan_schema")
local audio = require("controller.open77_titan_audio")
local gameplay = require("controller.open77_titan_gameplay")

local M = {}

-- Effects that exist only on the owner's screen (mirrors Open77's scripts/titans/titan_seams.py OWNER_ONLY_EFFECT_PREFIXES).
local OWNER_ONLY_FX = {
  "titan\\bt7274\\fx\\bt_view_",
  "titan\\bt7274\\fx\\bt_cock_sparks",
  "titan\\bt7274\\fx\\xo16_muzzle_fp_",
}

-- AudioXL methods that only read state: not output, never replicated.
local READ_ONLY = { Has = true, IsPlaying = true, Position = true, Duration = true, PlayingSounds = true, HasEmitter = true, IsEnabled = true }

local TRACER_AMBER = { r = 255, g = 184, b = 64, a = 242 }
local TRACER_RED = { r = 255, g = 64, b = 51, a = 242 }

local function round(v, places)
  local m = 10 ^ places
  return math.floor(v * m + 0.5) / m
end

local function wrap180(a)
  return (a + 180.0) % 360.0 - 180.0
end

-- Node counts the capture keeps instead of counting again (json.count: as the client's encoder counts them). A visual or an
-- event costs one node more than its own count: the list it stands in.
local ATTACHED_COST = json.count({ kind = "attached", name = "" }) + 1       -- a name is a node whatever its length
local SEQ_NODES = json.count({ seq = 0 }) - json.count({})                   -- the key and the number of an event's sequence

-- What decides the count of a persistent effect's visual: its path, id and position are always there and always the same size;
-- a rotation is three numbers (a heading) or four (a quaternion), a target is three, and either may be absent.
local function fx_shape(p)
  local r = p.rot
  return (r == nil and 0 or (r.w ~= nil and 2 or 1)) * 2 + (p.target == nil and 0 or 1)
end

function M.new(ctx)
  local self = {
    vars = {}, events = {}, nodes = {}, evSeq = 0, fxSeq = 0, live = {}, attached = {}, looping = {}, emitters = {}, hint = nil,
    frameSeq = 0, nextAt = 0.0, sweepAt = 0.0, comps = {}, compsFor = nil, entHash = nil, dropped = 0, sent = 0, refused = 0,
  }

  local function env() return ctx.env end
  local function catalog() return schema.catalog end

  local function capturing() return ctx.capturing() end

  -- ---------------------------------------------------------------- event queue ------------------------------
  local function push(ev)
    if #self.events >= schema.CAPS.pendingEvents then
      -- bounded backlog: drop the oldest cheap-to-lose event first, never grow
      local victim
      for _, kind in ipairs({ "tracer", "sound", "fx_move", "fx_spawn", "attached_fx" }) do
        for i, e in ipairs(self.events) do
          if e.kind == kind then victim = i break end
        end
        if victim then break end
      end
      local at = victim or 1
      self.nodes[table.remove(self.events, at)] = nil
      self.dropped = self.dropped + 1
      ctx.diag("capture.backlog", "Titan event backlog is full: the oldest event was dropped (the relay or the bridge is not keeping up)")
    end
    self.evSeq = self.evSeq + 1
    ev.seq = self.evSeq
    -- the nodes of the event as the client's encoder counts them, plus the one the list costs: made once, here, where the event
    -- is final (every frame that does not take it yet would otherwise count it again). Kept by the event itself, not by position:
    -- the host's time limit can cut this function anywhere, and a count list that ran beside the queue could be left one short
    -- (inferred cause of the 2026-11-03 stall: every later frame raised and the Titan was released as stalled).
    local nodes = json.count(ev) + 1
    self.events[#self.events + 1] = ev
    self.nodes[ev] = nodes
  end

  local function entity_ids_equal(a, b) return a:GetEntityID() == b:GetEntityID() end

  local function sameEntity(a, b)
    if a == nil or b == nil then return false end
    local ok, same = pcall(entity_ids_equal, a, b)
    return ok and same == true
  end

  -- ---------------------------------------------------------------- animation graph ------------------------------
  function self.var(name, value)
    if not capturing() then return end
    if not catalog().variables[name] then
      ctx.diag("var." .. tostring(name), "the controller wrote an animation variable that is not in the catalog: " .. tostring(name))
      return
    end
    self.vars[name] = value
  end

  -- ---------------------------------------------------------------- effects in the world ------------------------
  local function world_fx(path)
    local E = env()
    local fp = E.FPC and E.FPC.fx and E.FPC.fx.fpMuzzle
    if fp and fp.list then
      for _, p in ipairs(fp.list) do
        if p == path then return fp.of end
      end
    end
    local rail = E.FPC and E.FPC.guns and E.FPC.guns.rail and E.FPC.guns.rail.fx
    if rail then
      if path == rail.muzzleFp then return rail.muzzle end
      if path == rail.chargeFp then return rail.charge end
    end
    if catalog().effects[path] then return path end
    for _, prefix in ipairs(OWNER_ONLY_FX) do
      if path:sub(1, #prefix) == prefix then return nil end
    end
    ctx.diag("fx.path." .. tostring(path), "an effect path is not in the catalog and is not replicated: " .. tostring(path))
    return nil
  end

  local function rot_out(r)
    if type(r) ~= "table" then return nil end
    if r.i ~= nil then
      if schema.finite(r.i) and schema.finite(r.j) and schema.finite(r.k) and schema.finite(r.r) then
        return { x = round(r.i, 5), y = round(r.j, 5), z = round(r.k, 5), w = round(r.r, 5) }
      end
    elseif schema.finite(r.yaw) and schema.finite(r.pitch) then
      return { x = 0, y = round(r.pitch, 3), z = round(r.yaw, 3) }
    end
    return nil
  end

  local function pos_out(x, y, z)
    if schema.finite(x) and schema.finite(y) and schema.finite(z) then return { x = round(x, 3), y = round(y, 3), z = round(z, 3) } end
    return nil
  end

  -- The recording stand-in of an effect instance: a plain table that has the six methods the controller calls on an
  -- instance (IsValid, UpdateTransform, UpdateTargetPosition, AttachToSlot, Kill, BreakLoop), each recording what it
  -- is asked and then doing it natively. There are no metatables in the sandbox, so the methods are fields.
  local proxy_methods = {}

  local function stopped(p)
    if p.stopped or p.mine == false then return end
    p.stopped = true
    self.live[p.id] = nil
    push({ kind = "fx_stop", fxId = p.id })
  end

  function proxy_methods.IsValid(p) return p.native:IsValid() end

  function proxy_methods.UpdateTransform(p, tr)
    local h = self.hint
    self.hint = nil
    if p.mine and not p.stopped then
      if h and h.kind == "move" then
        p.pos = pos_out(h.x, h.y, h.z) or p.pos
        p.rot = rot_out(h.rot) or p.rot
        p.slot = nil
        p.dirty = true
      else
        ctx.diag("fx.move.nohint", "an effect was moved without a position the bridge can read: its movement is not replicated")
      end
    end
    return p.native:UpdateTransform(tr)
  end

  function proxy_methods.UpdateTargetPosition(p, wp)
    local h = self.hint
    self.hint = nil
    if p.mine and not p.stopped then
      if h and h.kind == "target" then
        p.target = pos_out(h.x, h.y, h.z) or p.target
        p.dirty = true
      else
        ctx.diag("fx.target.nohint", "an effect target was set without a position the bridge can read: it is not replicated")
      end
    end
    return p.native:UpdateTargetPosition(wp)
  end

  function proxy_methods.AttachToSlot(p, ent, target, slot, lt)
    local h = self.hint
    self.hint = nil
    if p.mine and not p.stopped then
      if h and h.kind == "slot" and catalog().slots[h.slot] then
        p.slot = h.slot
        p.dirty = true
      else
        ctx.diag("fx.slot", "an effect was hung on a slot that is not in the catalog: it is not replicated")
      end
    end
    return p.native:AttachToSlot(ent, target, slot, lt)
  end

  function proxy_methods.Kill(p)
    stopped(p)
    return p.native:Kill()
  end

  function proxy_methods.BreakLoop(p)
    stopped(p)
    return p.native:BreakLoop()
  end

  function self.hintMove(x, y, z, rot) self.hint, self.hintAt = { kind = "move", x = x, y = y, z = z, rot = rot }, ctx.clock end
  function self.hintTarget(x, y, z) self.hint, self.hintAt = { kind = "target", x = x, y = y, z = z }, ctx.clock end
  function self.hintSlot(slot) self.hint, self.hintAt = { kind = "slot", slot = slot }, ctx.clock end

  -- The next effect spawned is recorded at this point instead of its own (no arguments: none). The first-person view model
  -- starts a missile's effects at the cockpit's pod; other players see them at BT's own pod.
  function self.hintSpawn(x, y, z)
    if x == nil then
      self.spawnHint = nil
    else
      self.spawnHint, self.spawnHintAt = { x = x, y = y, z = z }, ctx.clock
    end
  end

  -- Spawns an effect natively and, while a Titan is granted, returns a recording stand-in with the same methods.
  function self.spawnEffect(path, tr, x, y, z, rot)
    local seen = self.spawnHint
    self.spawnHint = nil
    local inst = Game.GetFxSystem():SpawnEffect(gameFxResource.new({ effect = RaRef(path) }), tr)
    if inst == nil or not capturing() then return inst end
    local p = { native = inst, born = ctx.clock }
    for name, method in pairs(proxy_methods) do p[name] = method end
    local world = world_fx(path)
    local position = (seen and pos_out(seen.x, seen.y, seen.z)) or pos_out(x, y, z)
    if not world or not position then
      p.mine = false
      return p
    end
    self.fxSeq = self.fxSeq + 1
    p.mine, p.id, p.path, p.pos, p.rot = true, "f" .. self.fxSeq, world, position, rot_out(rot)
    self.live[p.id] = p
    push({ kind = "fx_spawn", fxId = p.id, path = world, position = position, rotation = p.rot })
    return p
  end

  -- ---------------------------------------------------------------- effects BT carries ------------------------
  -- The name a world effect BT carries goes by. BT's first-person copy carries the cockpit variant of each effect,
  -- `<world name>_fp`, except the spent case: the controller starts the one `FPC.shells.fp` for every gun and names the
  -- world effect of the gun in hand in its own table (`FPC.shells[PS.weapon].name`). A gun that throws no case, or a
  -- controller without that table, gets no name: nothing is guessed (a plain strip would name `bt7274_shell`, which
  -- does not exist). Returns the name, or nil and why not.
  local function carried_name(E, name, isFp)
    if not isFp or type(name) ~= "string" then return name end
    local shells = E.FPC and E.FPC.shells
    if type(shells) == "table" and name == shells.fp then
      local weapon = E.PS and E.PS.weapon
      local gun = shells[weapon]
      if type(gun) == "table" and type(gun.name) == "string" then return gun.name end
      return nil, "the first-person spent case has no world effect for the weapon " .. tostring(weapon)
    end
    return (name:gsub("_fp$", ""))
  end

  function self.effectEvent(ent, name, action)
    if not capturing() then return end
    local E = env()
    local isBt = E.PS and sameEntity(ent, E.PS.ent)
    local isFp = not isBt and E.PF and sameEntity(ent, E.PF.ent)
    if not (isBt or isFp) then return end
    local world, why = carried_name(E, name, isFp)
    if why or not catalog().attachedEffects[world] then
      ctx.diag("attached." .. tostring(why or world), why or ("an effect started on the Titan's entity is not in the catalog: " .. tostring(world)))
      return
    end
    -- a one-shot burst is only ever an event (every start is its own, in order); a loop is also persistent state
    if not schema.ONE_SHOT_ATTACHED[world] then self.attached[world] = (action == "start") or nil end
    push({ kind = "attached_fx", name = world, action = action })
  end

  -- ---------------------------------------------------------------- tracers --------------------------------------
  function self.tracer(x1, y1, z1, x2, y2, z2, kind)
    if not capturing() then return end
    local a, b = pos_out(x1, y1, z1), pos_out(x2, y2, z2)
    if not (a and b) then return end
    local X = env().XO16 or {}
    push({
      kind = "tracer", from = a, to = b, life = round((X.tracer or 0.07) + (X.mark or 0.12), 3),
      color = (kind == "person") and TRACER_RED or TRACER_AMBER, width = 3,
      mark = (kind == "nothing") and "none" or ((kind == "person") and "person" or "hit"),
    })
  end

  -- ---------------------------------------------------------------- sounds ---------------------------------------
  local function view_scale()
    local FPF = env().FPF
    local ok, v = pcall(FPF.viewVolume)
    if ok and schema.finite(v) then return math.max(0.05, math.min(1.0, v)) end
    return 1.0
  end

  local function titan_root()
    local P = env().PS
    return { x = P.x or 0, y = P.y or 0, z = P.z or 0 }
  end

  -- Records a sound the controller plays for its own ears as the sound a bystander hears.
  function self.sound(name, backend, gain, position, loop)
    if not capturing() then return end
    local row, why = audio.world_row(catalog().sounds, name)
    if not row then
      if why ~= "voice" then
        ctx.diag("sound." .. tostring(name), "a sound the controller plays is not replicated (" .. tostring(why) .. "): " .. tostring(name))
      end
      return
    end
    local ev = { kind = "sound", name = row, backend = backend }
    if gain then ev.gain = round(math.max(0.0, math.min(4.0, gain / view_scale())), 3) end
    if position then ev.position = position end
    local stamp = ctx.clock
    local key = audio.family(row) .. (position and "@" or "")
    if self.lastSound and self.lastSound[key] == stamp then return end
    self.lastSound = self.lastSound or {}
    self.lastSound[key] = stamp
    if loop then self.looping[row] = { backend = backend, gain = ev.gain, position = position, since = ctx.clock } end
    push(ev)
  end

  function self.nativeSound(kind, where, name)
    if not capturing() then return end
    local position
    if kind == "at" and type(where) == "table" then position = pos_out(where[1], where[2], where[3]) end
    self.sound(name, "native", nil, position, false)
  end

  local function stop_sound(name)
    if not capturing() then return end
    local row = audio.world_row(catalog().sounds, name)
    if not row then return end
    self.looping[row] = nil
    push({ kind = "sound_stop", name = row })
  end

  local function emitter_position(name)
    local E = env()
    local at = self.emitters[name]
    if not at or at.attached then return nil end
    local root = titan_root()
    local dx, dy, dz = at.x - root.x, at.y - root.y, at.z - root.z
    if dx * dx + dy * dy + dz * dz < 144.0 then return nil end
    return pos_out(at.x, at.y, at.z)
  end

  -- The recording stand-in of AudioXL's class: a plain table with the methods the controller (and the observer's
  -- audio) call; read-only questions go through untouched. No metatables: the methods are fields.
  local axl_methods = {}
  local axl_proxy = {}

  function axl_methods.Play(p, name, ...)
    local took = p.native:Play(name, ...)
    if took ~= false then
      local _, gain, _, _, _, _, _, loop = ...
      self.sound(name, "audioxl", gain, nil, loop)
    end
    return took
  end

  function axl_methods.PlayOn(p, emitter, name, ...)
    local took = p.native:PlayOn(emitter, name, ...)
    if took ~= false then
      local gain, _, _, _, _, _, loop = ...
      self.sound(name, "audioxl", gain, emitter_position(emitter), loop)
    end
    return took
  end

  -- Spoken lines are the owner's own headset (subtitled dialogue): forwarded, not replicated.
  function axl_methods.PlayLine(p, ...) return p.native:PlayLine(...) end
  function axl_methods.PlayPhoneLine(p, ...) return p.native:PlayPhoneLine(...) end

  function axl_methods.Stop(p, name, ...)
    local r = p.native:Stop(name, ...)
    stop_sound(name)
    return r
  end

  function axl_methods.StopOn(p, emitter, name, ...)
    local r = p.native:StopOn(emitter, name, ...)
    if type(name) == "string" and name ~= "" then stop_sound(name) end
    return r
  end

  function axl_methods.CreateEmitter(p, name, x, y, z)
    local r = p.native:CreateEmitter(name, x, y, z)
    if r ~= false then self.emitters[name] = { x = x, y = y, z = z } end
    return r
  end

  function axl_methods.MoveEmitter(p, name, x, y, z)
    local r = p.native:MoveEmitter(name, x, y, z)
    if r ~= false and self.emitters[name] then self.emitters[name].x, self.emitters[name].y, self.emitters[name].z = x, y, z end
    return r
  end

  function axl_methods.AttachEmitter(p, name, ent)
    local r = p.native:AttachEmitter(name, ent)
    if r ~= false then self.emitters[name] = { attached = true } end
    return r
  end

  function axl_methods.DetachEmitter(p, name) return p.native:DetachEmitter(name) end

  function axl_methods.DestroyEmitter(p, name)
    self.emitters[name] = nil
    return p.native:DestroyEmitter(name)
  end

  for key in pairs(READ_ONLY) do
    axl_methods[key] = function(p, ...) return p.native[key](p.native, ...) end
  end
  for key, method in pairs(axl_methods) do axl_proxy[key] = method end

  -- The controller's single AudioXL accessor: raw class outside a session, recording stand-in inside one.
  function self.axl(sys)
    if sys == nil or not capturing() then return sys end
    axl_proxy.native = sys
    return axl_proxy
  end

  -- ---------------------------------------------------------------- meshes, lights, pose -------------------------
  local function component(ent, name)
    local comp = self.comps[name]
    if comp == nil then
      local ok, found = pcall(function() return ent:FindComponentByName(name) end)
      comp = (ok and found) or false
      self.comps[name] = comp
    end
    return comp or nil
  end

  -- A new BT entity (a fresh spawn) starts from empty variable, effect and component records.
  function self.watch()
    local PS = env().PS
    local hash = PS.id
    if hash ~= self.entHash then
      self.entHash = hash
      self.vars, self.attached, self.looping, self.comps, self.compsFor = {}, {}, {}, {}, nil
    end
  end

  -- obj[name](obj) under pcall without a closure per call: the capture reads every mesh and light 20 times a second.
  local function call0(obj, name) return obj[name](obj) end

  local function enabled(comp)
    local ok, on = pcall(call0, comp, "IsEnabled")
    return ok and on == true
  end

  -- Mesh states as a bystander sees them: the controller hides BT's outside meshes while the owner looks out of the
  -- cockpit (and shows shadow-only twins instead), which no other player should see.
  local function mesh_state(E, ent)
    local actual, out = {}, {}
    for name in pairs(catalog().meshes) do
      local comp = component(ent, name)
      actual[name] = comp ~= nil and enabled(comp)
    end
    for name in pairs(actual) do out[name] = actual[name] end
    if E.PF and E.PF.shown and E.FPC then
      for _, G in pairs(E.FPC.guns or {}) do
        if G.mesh and G.shadow and out[G.mesh] ~= nil then out[G.mesh] = actual[G.shadow] == true end
      end
      for _, name in ipairs({ "bt7274_body", "bt7274_cockpit" }) do
        if out[name] ~= nil then out[name] = true end
      end
      if E.FPC.lowerPart and out[E.FPC.lowerPart] ~= nil then out[E.FPC.lowerPart] = false end
    end
    return out
  end

  local function light_state(ent)
    local out = {}
    for name in pairs(catalog().lights) do
      local comp = component(ent, name)
      local on = false
      if comp then
        local ok, v = pcall(call0, comp, "IsOn")
        on = ok and v == true or (not ok and enabled(comp))
      end
      out[name] = on
    end
    return out
  end

  -- (the protected read is a function of its own: a closure with four upvalues per frame was an allocation 20 times a second)
  local function world_pose(ent)
    local p = ent:GetWorldPosition()
    return p.x, p.y, p.z, ent:GetWorldYaw()
  end

  local function pose(E, ent)
    local ok, x, y, z, yaw = pcall(world_pose, ent)
    if not ok then x, y, z, yaw = nil, nil, nil, nil end
    local PS = E.PS
    if not (schema.finite(x) and schema.finite(y) and schema.finite(z) and schema.finite(yaw)) then
      x, y, z, yaw = PS.x, PS.y, PS.z, PS.yaw
    elseif PS.sunk and E.FPC then
      z = z + (E.FPC.sink or 0.0)
    end
    if not (schema.finite(x) and schema.finite(y) and schema.finite(z) and schema.finite(yaw)) then return nil end
    return { x = round(x, 3), y = round(y, 3), z = round(z, 3), yaw = round(wrap180(yaw), 2) }
  end
  self.pose = pose

  -- ---------------------------------------------------------------- frame -----------------------------------------
  local function native_valid(p) return p.native:IsValid() end

  local function sweep()
    for id, p in pairs(self.live) do
      local ok, valid = pcall(native_valid, p)
      if ok and not valid and ctx.clock - p.born > 1.0 then self.live[id] = nil end
    end
  end

  local function visuals(budget)
    local list = {}
    local aged = {}
    for _, p in pairs(self.live) do
      if not p.stopped and ctx.clock - p.born >= 0.75 then aged[#aged + 1] = p end
    end
    table.sort(aged, function(a, b) return a.born > b.born end)
    for _, p in ipairs(aged) do
      local v = { kind = "fx", fxId = p.id, path = p.path, position = p.pos, rotation = p.rot, target = p.target }
      -- counted again only when the shape of what it carries changed (a rotation or a target came or went)
      local shape = fx_shape(p)
      if p.nodesShape ~= shape then p.nodes, p.nodesShape = json.count(v) + 1, shape end
      local c = p.nodes
      if #list >= schema.CAPS.visualsPerFrame or c > budget then break end
      budget = budget - c
      list[#list + 1] = v
    end
    local names = {}
    for name in pairs(self.attached) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
      local c = ATTACHED_COST
      if #list >= schema.CAPS.visualsPerFrame or c > budget then break end
      budget = budget - c
      list[#list + 1] = { kind = "attached", name = name }
    end
    local rows = {}
    for name in pairs(self.looping) do rows[#rows + 1] = name end
    table.sort(rows)
    for _, name in ipairs(rows) do
      local L = self.looping[name]
      local v = { kind = "sound", name = name, backend = L.backend, gain = L.gain, position = L.position }
      -- a looping sound never changes once it started (a new start is a new record): counted once
      if L.nodes == nil then L.nodes = json.count(v) + 1 end
      local c = L.nodes
      if #list >= schema.CAPS.visualsPerFrame or c > budget then break end
      budget = budget - c
      list[#list + 1] = v
    end
    return list
  end

  -- One fx_move per effect that moved since the last frame (movement is coalesced to the frame rate).
  -- Returns what the events it added take off the budget the way the packing below has always counted them: with their sequence
  -- number (a key and a number: two nodes more than the count that decides whether one fits) and the one the list costs.
  local function move_events(limit, out, budget)
    local ids = {}
    for id, p in pairs(self.live) do
      if p.dirty and not p.stopped then ids[#ids + 1] = id end
    end
    table.sort(ids, function(a, b) return tonumber(a:sub(2)) < tonumber(b:sub(2)) end)
    local spent = 0
    for _, id in ipairs(ids) do
      local p = self.live[id]
      local ev = { kind = "fx_move", fxId = id, position = p.pos, rotation = p.rot, target = p.target, slot = p.slot }
      local c = json.count(ev) + 1
      if #out >= limit or c > budget then break end
      budget = budget - c
      spent = spent + c + SEQ_NODES
      p.dirty = false
      self.evSeq = self.evSeq + 1
      ev.seq = self.evSeq
      out[#out + 1] = ev
    end
    return spent
  end

  function self.ready()
    local E = env()
    local T = ctx.titan
    return E ~= nil and T ~= nil and ctx.session.active and E.PS.ent ~= nil and E.PS.warm == nil and E.PS.asked == nil and not E.S.gone
  end

  function self.reset()
    self.vars, self.events, self.nodes, self.live, self.attached, self.looping, self.emitters = {}, {}, {}, {}, {}, {}, {}
    self.evSeq, self.fxSeq, self.frameSeq, self.hint, self.spawnHint, self.lastSound = 0, 0, 0, nil, nil, nil
    self.comps, self.compsFor = {}, nil
    self.nextAt = 0.0
  end

  -- One frame per 1/20 s; `now` sends one regardless of the rate (the controller is about to delete BT: the events queued so
  -- far, a blast's effect and boom, would go with it). Returns true when a frame was handed to the transport.
  function self.frame(now)
    local E = env()
    if not self.ready() or (not now and ctx.clock < self.nextAt) then return false end
    self.nextAt = ctx.clock + 1.0 / schema.CAPS.frameHz
    local ent = E.PS.ent
    if not IsDefined(ent) then return false end
    if self.compsFor ~= ent then self.comps, self.compsFor = {}, ent end
    local p = pose(E, ent)
    if not p then return false end
    if self.hint and ctx.clock - (self.hintAt or 0.0) > 1.0 then self.hint = nil end
    if self.spawnHint and ctx.clock - (self.spawnHintAt or 0.0) > 1.0 then self.spawnHint = nil end
    if ctx.clock >= self.sweepAt then
      self.sweepAt = ctx.clock + 0.5
      sweep()
    end

    local vars = {}
    local n = 0
    for name, v in pairs(self.vars) do
      n = n + 1
      if n > schema.CAPS.vars then break end
      vars[name] = round(v, 4)
    end
    -- the sky call-down and the jump away are announced as modes of their own: the server admits their long path
    -- (the server admits `drop` only as the first frames of a grant and `leave` only after a non-drop frame)
    local T = ctx.titan
    local act = E.PS.act
    local mode = (act and (act.kind == "drop" or act.kind == "leave")) and act.kind or (schema.MODES[E.PS.mode] and E.PS.mode or "none")
    if (mode == "drop" and T.sentMode ~= nil and T.sentMode ~= "drop") or (mode == "leave" and (T.sentMode == nil or T.sentMode == "drop")) then
      mode = schema.MODES[E.PS.mode] and E.PS.mode or "none"
    end
    local weapon = schema.WEAPONS[E.PS.weapon] and E.PS.weapon or "xo16"
    self.frameSeq = self.frameSeq + 1
    local frame = {
      v = schema.VERSION, op = "frame", id = ctx.titan.id, epoch = ctx.titan.epoch, seq = self.frameSeq,
      t = round(ctx.clock, 3), pose = p, mode = mode, weapon = weapon, vars = vars,
      meshes = mesh_state(E, ent), lights = light_state(ent), visuals = {}, events = {},
    }
    -- The owner's gameplay report beside the presentation, once per published frame (no stream or timer of its own). A
    -- substate the controller has nothing to say about is absent; a report the schema refuses is dropped, never repaired,
    -- and the frame goes out without it.
    local okg, report = pcall(gameplay.snapshot, E)
    if not okg then
      ctx.diag("capture.gameplay", "the gameplay report failed: " .. tostring(report))
    elseif type(report) == "table" then
      local clean, why = schema.gameplay(report)
      if clean then
        frame.gameplay = clean
      else
        ctx.diag("capture.gameplay." .. tostring(why), "the gameplay report was refused by the schema (" .. tostring(why) .. ")")
      end
    end
    -- Budget in nodes as the client's encoder counts them: every value, every table AND every key. Events get most
    -- of what the frame's fixed part leaves; the rest is kept for the persistent visuals.
    local free = schema.CAPS.valueBudget - json.count(frame)
    local reserve = math.min(220, math.floor(free * 0.3))
    local budget = free - reserve
    local sending = {}
    for i, ev in ipairs(self.events) do
      local c = self.nodes[ev] or (json.count(ev) + 1)
      if #sending >= schema.CAPS.eventsPerFrame or c > budget then break end
      budget = budget - c
      sending[#sending + 1] = ev
    end
    local queuedCount = #sending
    if queuedCount == #self.events then
      budget = budget - move_events(schema.CAPS.eventsPerFrame, sending, budget)
    end
    frame.events = sending
    frame.visuals = visuals(budget + reserve)

    local text = json.encode(frame)
    while text and #text > schema.CAPS.byteBudget and #sending > 0 do
      sending[#sending] = nil
      text = json.encode(frame)
    end
    if not text then
      ctx.diag("capture.encode", "a Titan frame could not be encoded")
      return false
    end
    local queued = math.min(queuedCount, #sending)
    if ctx.publish(frame) then
      self.sent = self.sent + 1
      T.sentMode = mode
      for _ = 1, queued do
        self.nodes[table.remove(self.events, 1)] = nil
      end
      return true
    end
    -- the transport is full: the frame is replaceable, the queued events stay queued, moved effects are marked dirty again
    self.refused = self.refused + 1
    for i = queued + 1, #sending do
      local live = self.live[sending[i].fxId]
      if live then live.dirty = true end
    end
    return false
  end

  function self.draw() end

  return self
end

return M
