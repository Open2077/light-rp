-- Owner side: what this machine's Titan lands on another player's Titan is observed, reported, and never applied here.
--
-- A remote Titan is a presentation body (open77_titan_observer: a DynamicEntitySpec entity, not a managed NPC). The
-- controller's own weapons and abilities find their targets in PS.npcs and send their blows through FPF.hit, FPF.hitFull
-- and FPF.attack. This module makes the remote bodies visible to exactly those entry points, and turns what reaches them
-- into reports:
--   * FPF.listMore: the live remote Titans are added to the controller's list of people (PS.npcs / PS.npcShape), each with
--     the controller's own big-body cylinder (FPC.big.titan). The rays, the fists' reach and the area loops then treat
--     them as they treat any other big target; a wall on the way still wins, because the controller's world rays run first.
--   * FPF.bigTarget, FPF.wouldFight: a live remote Titan is a big target the controller may fight; everything else is the
--     authored answer.
--   * FPF.hit, FPF.hitFull: a blow on a remote Titan is queued as one report and no native hit is sent to the presentation
--     body; any other target is the authored function. Every direct blow is its own report (a burst's rounds, a vortex's
--     hits): nothing is merged by record or time.
--   * FPF.attack: the authored area attack runs untouched (its world effect and its hits on everything else), and the same
--     blast is tested against the cylinder of every live remote Titan with the attack's own reach (FPF.attackReach); the
--     nearest wall (Static, Terrain) between the blast and the body stops it. A blast is a candidate until the frame ends.
--   * FPF.punchTargets, FPF.spinTargets: a remote Titan's entry is rebuilt with its cylinder, so the fists and the sword's spin
--     reach its near side as they reach any big body (the authored functions read the radius from a character record the
--     presentation body lacks). FPF.waveMeet: an arc wave meets a remote Titan by its cylinder the same way, once per wave.
--   * FPF.designable: a live remote Titan is a target for the designator without being asked what only a puppet answers.
-- The controller's gates that ask the game whether a target is active or hostile (ScriptedPuppet.IsActive, IsHostile) ask the
-- bridge instead (OP77.targetActive, OP77.targetHostile): the module answers for a remote Titan, the game for everything else.
-- What a remote Titan takes from a gas cloud or the electric smoke is the controller's own blow on it every tick (the controller
-- sends one for each person in the cloud), so it is reported like any other.
-- The game's status effects (burning, poison, smoke blindness, stun, knock-down, electrocution) are the controller's own calls
-- on its target, and a remote Titan's body is a presentation mesh that takes them for nobody. The port sends each of those calls
-- through OP77.statusObserved(ent, effect) first: for the body of one of the observer's Titans the module answers true (the
-- controller does not ask the game; an ended Titan's body included) and, only while the Titan is live, queues one status
-- report with the exact authored effect record; for everything else it answers false and the controller's own call runs
-- unchanged. A duration is reported only when the controller itself supplies one (it supplies none today: the game's own
-- record decides how long an effect lasts), and nothing is merged: two applications are two reports. Nothing is applied to a
-- remote Titan here, and no status is decided or priced: the mission reads the observation and decides.
-- Nothing here invents damage: a blow's report names the target, the authored attack record, where the blow came from, where it
-- landed and which way it went. The mission decides what it is worth and applies it with the Titan server's `hit`.
--
-- Use: `local combat = M.new(ctx, observer)`; `combat.install()` once per attached controller (ctx.env), `combat.frame()` once
-- per frame after the controller's own update, `combat.clear()` when the owner's Titan or the session ends,
-- `combat.targetActive(ent)` / `combat.targetHostile(ent)` for the controller's ScriptedPuppet.IsActive / IsHostile gates (nil: not
-- a remote Titan) and `combat.find(ent)` for the canonical identity of a live remote Titan. ctx.sendHit(report) queues one report
-- and answers true when it took it. `combat.statusObserved(ent, effect, duration)` is the bridge's OP77.statusObserved: it answers
-- true when the controller must not ask the game (a body of the observer's) and false for everything else; the reports it queues
-- leave at the end of the frame, after the blows, through ctx.sendStatus(report), which answers true when it took one.

local _ENV = require("controller.open77_titan_env")

local M = {}

local MAX_PENDING = 128      -- reports waiting for the frame to end
local SAME_CENTER = 1e-4     -- two area attacks centred this close (per axis) are one impact reported twice
local SAME_IMPACT = 1.0      -- an area attack and a direct blow of the same record on the same Titan this close are one impact
local WALL_SLACK = 0.1       -- a wall this close to the body is the body's own ground, not a cover

local REQUIRED = { "listMore", "bigTarget", "wouldFight", "hit", "hitFull", "attack", "punchTargets", "attackReach", "designable",
  "spinTargets", "waveMeet" }
local CALLED = { "coreWorth" }   -- functions the module calls (not wraps): the supported release has them

local function finite(v)
  return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function finite3(x, y, z)
  return finite(x) and finite(y) and finite(z)
end

local function unit_part(v)
  if v > 1 then return 1 end
  if v < -1 then return -1 end
  return v
end

-- A direction of length 1 (each part within +-1), or nil for a zero or non-finite one.
local function unit(x, y, z)
  if not finite3(x, y, z) then return nil end
  local n = math.sqrt(x * x + y * y + z * z)
  if n < 1e-6 then return nil end
  return { x = unit_part(x / n), y = unit_part(y / n), z = unit_part(z / n) }
end

-- The exact text of an entity's id, or nil. Handles are never compared: two userdata for one entity are two values.
-- (The protected calls name functions of their own: these run for every candidate of every frame a remote Titan is here, and a
-- closure per call was an allocation each time.)
local function entity_text(ent) return tostring(ent:GetEntityID()) end
local function key_of(ent)
  if ent == nil then return nil end
  local ok, text = pcall(entity_text, ent)
  if ok and type(text) == "string" and text ~= "" and text ~= "0" then return text end
  return nil
end

local function world_position(ent)
  local p = ent:GetWorldPosition()
  return p.x, p.y, p.z
end

local function position_of(ent)
  local ok, x, y, z = pcall(world_position, ent)
  if ok and finite3(x, y, z) then return x, y, z end
  return nil
end

local function nested(root, ...)
  local at = root
  for i = 1, select("#", ...) do
    if type(at) ~= "table" then return nil end
    at = at[(select(i, ...))]
  end
  return at
end

function M.new(ctx, observer)
  local self = { sent = 0, refused = 0, gone = 0, duplicates = 0, suppressed = 0, statuses = 0 }
  local pending = {}
  local statuses = {}   -- status reports waiting for the frame to end
  local installed = nil

  local function env() return ctx.env end

  local function diag(key, text)
    ctx.diag("combat." .. key, text)
  end

  -- ------------------------------------------------------------------ who is a remote Titan --------------------
  -- A remote body is a target only while its Titan is live: placed, driven and not ended. Another player's Titan is never
  -- this machine's own (the observer does not make one; this is the same check again).
  local function live(R)
    if R.state ~= "live" or R.ent == nil then return false end
    local T, S = ctx.titan, ctx.session
    if T ~= nil and R.id == T.id then return false end
    if S ~= nil and S.player ~= nil and R.owner == S.player then return false end
    return IsDefined(R.ent) and true or false
  end

  local function identity(R)
    return { kind = "titan", id = R.id, epoch = R.epoch, owner = R.owner }
  end

  local function sorted_remotes()
    local list = {}
    for _, R in pairs(observer.remote) do list[#list + 1] = R end
    table.sort(list, function(a, b)
      if #a.id ~= #b.id then return #a.id < #b.id end
      return a.id < b.id
    end)
    return list
  end

  -- The observer's record whose body is this entity (any state), or nil. Nothing is kept between calls.
  local function locate(ent)
    if ent == nil or next(observer.remote) == nil then return nil end
    local key = key_of(ent)
    if key == nil then return nil end
    for _, R in pairs(observer.remote) do
      if R.ent ~= nil and key_of(R.ent) == key then return R, key end
    end
    return nil
  end

  local function known(ent)
    local ok, R = pcall(locate, ent)
    if ok then return R end
    diag("locate", "a target could not be told from a remote Titan: " .. tostring(R))
    return nil
  end

  function self.find(ent)
    local R = locate(ent)
    if R == nil or not live(R) then return nil end
    return identity(R)
  end

  -- true for a body of one of the observer's Titans (live or not): another player's Titan, which the bridge's PvP gate
  -- (OP77.playerTarget) keeps out of the controller's auto-targeting while the server's flag is off.
  function self.titanBody(ent)
    return known(ent) ~= nil
  end

  -- true / false for a body of one of the observer's Titans (live or not), nil for anything else.
  function self.targetActive(ent)
    local R = locate(ent)
    if R == nil then return nil end
    return live(R)
  end

  -- true for a live remote Titan (a foe the controller's abilities may strike: the answer FPF.wouldFight gives), false for a
  -- body of the observer's that is not live, nil for anything else: the native IsHostile is the answer for those.
  function self.targetHostile(ent)
    local R = locate(ent)
    if R == nil then return nil end
    return live(R)
  end

  -- ------------------------------------------------------------------ what the controller knows ----------------
  local function titan_shape()
    local s = nested(env().FPC, "big", "titan")
    if type(s) == "table" and finite(s[1]) and finite(s[2]) and s[1] > 0 and s[2] > 0 then return s[1], s[2], s end
    return nil
  end

  local function origin()
    local PS = env().PS
    if finite3(PS.x, PS.y, PS.z) then return { x = PS.x, y = PS.y, z = PS.z } end
    return nil
  end

  local function add_record(set, record)
    if type(record) == "string" then set[record] = true end
  end

  -- The authored record families: what the controller's own fists, blade and slam strike with, and its blasts. Anything
  -- else it sends as a direct blow is a projectile: a round, a missile, a thrown-back hit.
  local function kind_of(record)
    local e = env()
    local FPC, PS = e.FPC, e.PS
    local melee, blast = {}, {}
    add_record(melee, PS.punchRecord)
    local big = nested(FPC, "punchBig", "records")
    if type(big) == "table" then
      for name in pairs(big) do add_record(melee, name) end
    end
    local sword = nested(FPC, "sword", "records")
    if type(sword) == "table" then
      add_record(melee, sword.slash)
      add_record(melee, sword.core)
    end
    add_record(melee, nested(FPC, "sword", "charge", "record"))
    local fist = nested(FPC, "fist", "records")
    if type(fist) == "table" then
      add_record(melee, fist.jab)
      add_record(melee, fist.heavy)
      add_record(melee, fist.charged)
      add_record(melee, fist.core)
      add_record(blast, fist.blast)
    end
    add_record(blast, nested(FPC, "mtmsBlast", "attack"))
    add_record(blast, nested(FPC, "slam", "record"))
    add_record(blast, nested(FPC, "eject", "attack"))
    add_record(blast, nested(FPC, "perk", "flightStrike", "records", "blast"))
    -- the clouds' ticks (the gas, the electric smoke) are area effects that surround a body, not projectiles
    add_record(blast, nested(FPC, "hazard", "gasHurt"))
    add_record(blast, nested(FPC, "esmoke", "attack"))
    local pound = nested(FPC, "poundRadial", "records")
    if type(pound) == "table" then
      for _, name in ipairs(pound) do add_record(blast, name) end
    end
    if melee[record] then return "melee" end
    if blast[record] then return "blast" end
    return "ranged"
  end

  -- ------------------------------------------------------------------ the list of people ----------------------
  -- Called by the wrapped FPF.listMore after the authored one: the live remote Titans in scope that are not in the list
  -- are added with the big-body cylinder; one that the game's own search already listed gets the cylinder in place of
  -- the shape that search gave it. The authored list marks even a body it left out as seen, so `seen` is not consulted.
  local function append(list, shapes, seen)
    if next(observer.remote) == nil then return end
    local e = env()
    local PS = e.PS
    local radius, height, shape = titan_shape()
    if radius == nil then
      diag("shape", "the controller has no big-body shape for a Titan (FPC.big.titan): remote Titans are not targets")
      return
    end
    local own = PS.ent ~= nil and key_of(PS.ent) or nil
    local ox, oy, oz = PS.x, PS.y, PS.z
    if not finite3(ox, oy, oz) then ox, oy, oz = position_of(Game.GetPlayer()) end
    if ox == nil then return end
    local scope = (nested(e.XO16, "range") or 250.0) + 60.0
    local listed = {}
    for i, ent in ipairs(list) do
      local k = key_of(ent)
      if k ~= nil then listed[k] = i end
    end
    for _, R in ipairs(sorted_remotes()) do
      if live(R) then
        local k = key_of(R.ent)
        if k ~= nil and k ~= own then
          local at = listed[k]
          if at ~= nil then
            shapes[at] = shape
            seen[k] = true
          else
            local x, y, z = position_of(R.ent)
            if x ~= nil and math.sqrt((x - ox) ^ 2 + (y - oy) ^ 2 + (z - oz) ^ 2) <= scope then
              list[#list + 1] = R.ent
              shapes[#list] = shape
              seen[k] = true
            end
          end
        end
      end
    end
  end

  -- ------------------------------------------------------------------ queueing -------------------------------------
  local function refuse(key, text)
    self.refused = self.refused + 1
    diag(key, text)
    return false
  end

  local function push(entry)
    if #pending >= MAX_PENDING then
      return refuse("cap", "more than " .. MAX_PENDING .. " blows on remote Titans in one frame: the extra ones are not reported")
    end
    pending[#pending + 1] = entry
    return true
  end

  -- PS.noBlast as the authored FPF.hit sets it for a punch on a big body: the area attack beside that hit is left out, so a
  -- blow is taken once. The remote Titan is such a body; the native hit the authored function would send is not sent.
  local function note_no_blast(R, record, x, y, z)
    local e = env()
    local P, PS, S, FPC = e.P, e.PS, e.S, e.FPC
    if not P.fullHits then return end
    local records = nested(FPC, "punchBig", "records")
    if type(records) ~= "table" or not records[record] then return end
    local radius = titan_shape()
    local cx, cy = position_of(R.ent)
    PS.noBlast = { x = x, y = y, z = z, at = S.clock, record = record, cx = cx or x, cy = cy or y, r = radius or 0.0 }
  end

  local function queue_direct(R, record, x, y, z, dx, dy, dz)
    if not live(R) then
      self.gone = self.gone + 1
      return false
    end
    if type(record) ~= "string" or record == "" then return refuse("record", "a blow on a remote Titan named no attack record") end
    if not finite3(x, y, z) then return refuse("point", "a blow on a remote Titan had no finite place (" .. record .. ")") end
    local from = origin()
    if from == nil then return refuse("origin", "a blow on a remote Titan was sent while BT has no place") end
    local direction = unit(dx, dy, dz) or unit(x - from.x, y - from.y, z - from.z)
    if direction == nil then return refuse("direction", "a blow on a remote Titan had no direction (" .. record .. ")") end
    return push({ sense = "direct", target = identity(R), record = record, origin = from, point = { x = x, y = y, z = z },
      direction = direction, kind = kind_of(record), scale = 1 })
  end

  local function take_direct(R, noBlast, record, x, y, z, dx, dy, dz)
    local ok, taken = pcall(function()
      if noBlast and live(R) then note_no_blast(R, record, x, y, z) end
      return queue_direct(R, record, x, y, z, dx, dy, dz)
    end)
    if ok then return taken end
    diag("direct", "a blow on a remote Titan failed: " .. tostring(taken))
    return false
  end

  -- ------------------------------------------------------------------ status effects --------------------------------
  -- One application of a status effect by the controller to a body of the observer's: the report names the Titan, the effect
  -- (the controller's own record string, exactly) and, only when the controller supplied a real duration, that duration. The
  -- module adds no damage, no default duration and no instigator, and merges nothing: two applications are two reports.
  local function queue_status(R, effect, duration)
    if not live(R) then
      self.gone = self.gone + 1
      return false
    end
    if type(effect) ~= "string" or effect == "" then return refuse("status.effect", "a status effect on a remote Titan named no effect record") end
    if duration ~= nil and not (finite(duration) and duration > 0) then
      return refuse("status.duration", "a status effect on a remote Titan (" .. effect .. ") had a duration that is not a positive number")
    end
    if #statuses >= MAX_PENDING then
      return refuse("status.cap", "more than " .. MAX_PENDING .. " status effects on remote Titans in one frame: the extra ones are not reported")
    end
    statuses[#statuses + 1] = { target = identity(R), effect = effect, duration = duration }
    return true
  end

  -- true when the controller must not ask the game for this effect on this body (a body of one of the observer's Titans, live
  -- or not: it is nobody's to take it); false for everything else, whose effect the controller applies as it always did. Only a
  -- live Titan's attempt is reported.
  function self.statusObserved(ent, effect, duration)
    local R = known(ent)
    if R == nil then return false end
    local ok, err = pcall(queue_status, R, effect, duration)
    if not ok then diag("status", "a status effect on a remote Titan could not be reported (" .. tostring(effect) .. "): " .. tostring(err)) end
    return true
  end

  -- True when a wall (Static, Terrain: what the controller's rail and rays treat as the world) stands between the
  -- two points, false when none does, nil and the reason when the world could not be asked.
  local function walled(cx, cy, cz, qx, qy, qz, dist)
    local ok, queries = pcall(function() return Game.GetSpatialQueriesSystem() end)
    if not ok or queries == nil then return nil, "no spatial query system" end
    local ux, uy, uz = (qx - cx) / dist, (qy - cy) / dist, (qz - cz) / dist
    local from, to = Vector4.new(cx, cy, cz, 1.0), Vector4.new(qx, qy, qz, 1.0)
    for _, group in ipairs({ "Static", "Terrain" }) do
      local asked, hit, result = pcall(function() return queries:SyncRaycastByCollisionGroup(from, to, group, nil, false, false) end)
      if not asked then return nil, tostring(hit) end
      if hit and result ~= nil and result.position ~= nil then
        local p = result.position
        local along = (p.x - cx) * ux + (p.y - cy) * uy + (p.z - cz) * uz
        if along >= 0 and along < dist - WALL_SLACK then return true end
      end
    end
    return false
  end

  local function same_area(a, b)
    return a.sense == "area" and a.record == b.record and a.target.id == b.target.id and a.target.epoch == b.target.epoch
      and math.abs(a.center.x - b.center.x) <= SAME_CENTER and math.abs(a.center.y - b.center.y) <= SAME_CENTER
      and math.abs(a.center.z - b.center.z) <= SAME_CENTER
  end

  -- One area attack at (x, y, z): a candidate for every live remote Titan whose cylinder the attack's reach touches with
  -- no wall in between. The point of a candidate is the nearest point of the body to the centre; a centre inside the body
  -- is its own point.
  local function queue_area(record, x, y, z)
    if next(observer.remote) == nil then return end
    if type(record) ~= "string" or record == "" or not finite3(x, y, z) then return end
    local FPF = env().FPF
    local asked, reach = pcall(FPF.attackReach, record)
    if not asked or not finite(reach) or reach <= 0 then
      diag("reach", "the reach of an area attack (" .. record .. ") is not known: it is not tested against remote Titans")
      return
    end
    local radius, height = titan_shape()
    if radius == nil then return end
    local from = origin()
    if from == nil then return end
    for _, R in ipairs(sorted_remotes()) do
      if live(R) then
        local px, py, pz = position_of(R.ent)
        if px ~= nil then
          local hx, hy = x - px, y - py
          local flat = math.sqrt(hx * hx + hy * hy)
          local qx, qy = x, y
          if flat > radius then qx, qy = px + hx / flat * radius, py + hy / flat * radius end
          local qz = math.min(math.max(z, pz), pz + height)
          local dist = math.sqrt((qx - x) ^ 2 + (qy - y) ^ 2 + (qz - z) ^ 2)
          if dist <= reach then
            local blocked, why = false, nil
            if dist > 1e-6 then blocked, why = walled(x, y, z, qx, qy, qz, dist) end
            if blocked == nil then
              refuse("occlusion", "a blast near a remote Titan could not be tested against the world (" .. tostring(why) .. "): not reported")
            elseif not blocked then
              local direction = unit(qx - from.x, qy - from.y, qz - from.z) or unit(px - from.x, py - from.y, pz - from.z)
              if direction == nil then
                refuse("direction", "a blast on a remote Titan had no direction (" .. record .. ")")
              else
                local entry = { sense = "area", target = identity(R), record = record, origin = from, center = { x = x, y = y, z = z },
                  point = { x = qx, y = qy, z = qz }, direction = direction, kind = "blast", scale = 1 }
                local duplicate = false
                for _, other in ipairs(pending) do
                  if same_area(other, entry) then duplicate = true break end
                end
                if duplicate then
                  self.duplicates = self.duplicates + 1
                else
                  push(entry)
                end
              end
            end
          end
        end
      end
    end
  end

  -- ------------------------------------------------------------------ the fists' reach ---------------------------
  -- The authored take() for a big body (FPF.punchTargets, flat and pitched), for one remote Titan.
  local function titan_target(ent, key, range, angle, radius, height)
    local e = env()
    local PS, S, FPC, FPF = e.PS, e.S, e.FPC, e.FPF
    local px, py, pz = position_of(ent)
    if px == nil or not finite3(PS.x, PS.y, PS.z) or not finite(S.yaw) then return nil end
    local ry = math.rad(S.yaw)
    local fx, fy = -math.sin(ry), math.cos(ry)
    local dx0, dy0 = px - PS.x, py - PS.y
    local dx, dy, z = dx0, dy0, pz
    local pitch, pivot = nil, nil
    if PS.hitPitchOn and FPF.hitPitchNow then pitch, pivot = FPF.hitPitchNow() end
    local turned = pitch ~= nil and math.abs(pitch) >= 0.5
    if turned then
      local rx, ry2 = fy, -fx
      local cp, sp = math.cos(math.rad(pitch)), math.sin(math.rad(pitch))
      local oz = PS.z + pivot
      local a, b, c = dx0 * fx + dy0 * fy, dx0 * rx + dy0 * ry2, pz - oz
      local a2, c2 = a * cp + c * sp, -a * sp + c * cp
      dx, dy, z = fx * a2 + rx * b, fy * a2 + ry2 * b, oz + c2
    end
    local dist = math.sqrt(dx * dx + dy * dy)
    local near = math.max(0.0, dist - radius)
    local wide = (dist > 0.01) and math.deg(math.atan(radius, dist)) or 0.0
    local cone = math.cos(math.rad(math.min(89.0, angle + wide)))
    if not (near <= range and math.abs(z - PS.z) < 5.0 and (dist < 1.5 + radius or (dx * fx + dy * fy) / dist >= cone)) then
      return nil
    end
    local n = math.max(math.sqrt(dx0 * dx0 + dy0 * dy0), 0.01)
    local ux, uy = dx0 / n, dy0 / n
    return { ent = ent, kind = "person", dist = near, x = px - ux * radius, y = py - uy * radius,
      z = pz + math.min(height * 0.5, FPC.punchBig.up), key = key, dx = ux, dy = uy, r = radius, pitched = turned and pitch or nil }
  end

  -- A list the controller built of its targets (what FPF.punchTargets, FPF.spinTargets answer) with the entry of every body
  -- of the observer's rebuilt as the authored take() builds it for a big body (`build(ent, key, radius, height)`), or dropped
  -- when the Titan is not live or out of reach. Entries of everything else are left as the authored function made them.
  local function adjust_entries(out, build, sorted)
    if next(observer.remote) == nil then return out end
    local radius, height = titan_shape()
    if radius == nil then return out end
    local PS = env().PS
    local bodies, any = {}, false
    for _, R in pairs(observer.remote) do
      local k = (R.ent ~= nil) and key_of(R.ent) or nil
      if k ~= nil then bodies[k], any = live(R), true end
    end
    if not any then return out end
    local order, present = {}, {}
    for _, ent in ipairs(PS.npcs or {}) do
      local k = key_of(ent)
      if k ~= nil and bodies[k] == true and not present[k] and IsDefined(ent) then
        present[k] = ent
        order[#order + 1] = k
      end
    end
    -- the authored entry of any body of the observer's (it reads no radius for it) is replaced, or dropped when the Titan ended
    local changed = #order > 0
    for _, T in ipairs(out) do
      if T.kind == "person" and bodies[T.key] ~= nil then changed = true end
    end
    if not changed then return out end
    local fixed = {}
    for _, T in ipairs(out) do
      if not (T.kind == "person" and bodies[T.key] ~= nil) then fixed[#fixed + 1] = T end
    end
    for _, k in ipairs(order) do
      local T = build(present[k], k, radius, height)
      if T ~= nil then fixed[#fixed + 1] = T end
    end
    if sorted then table.sort(fixed, function(a, b) return a.dist < b.dist end) end
    return fixed
  end

  local function adjust_targets(out, range, angle)
    return adjust_entries(out, function(ent, key, radius, height) return titan_target(ent, key, range, angle, radius, height) end, true)
  end

  -- ------------------------------------------------------------------ the sword ----------------------------------
  -- The authored take() of FPF.spinTargets for a big body (the spin's reach is measured from the body's near side and the
  -- list keeps the controller's order), for one remote Titan.
  local function spin_builder(reach)
    return function(ent, key, radius, height)
      local e = env()
      local PS, FPC = e.PS, e.FPC
      local K = nested(FPC, "sword", "spin")
      if type(K) ~= "table" or not finite(K.high) or not finite(K.near) or not finite(reach) then return nil end
      local px, py, pz = position_of(ent)
      if px == nil or not finite3(PS.x, PS.y, PS.z) then return nil end
      local dx, dy = px - PS.x, py - PS.y
      local dist = math.sqrt(dx * dx + dy * dy)
      local near = math.max(0.0, dist - radius)
      if near > reach or math.abs(pz - PS.z) >= K.high then return nil end
      local n = math.max(dist, 0.01)
      local ux, uy = dx / n, dy / n
      return { ent = ent, kind = "person", dist = near, x = px - ux * radius, y = py - uy * radius,
        z = pz + math.min(height * 0.5, FPC.punchBig.up), key = key, dx = ux, dy = uy, r = radius, close = dist < K.near + radius }
    end
  end

  -- One step of an arc wave (FPF.waveMeet) meeting a remote Titan: the authored test and effects for a big body (the width
  -- measured from its near side, two metres more in height, one meeting for each wave, the blow at the near side), with the
  -- Titan's cylinder in place of the character record's radius the presentation body lacks. The blow and the area attack
  -- are the controller's own calls (the wave's record is one of the controller's big-body records, so while P.fullHits is on
  -- the blow goes with its attack type set and the authored PS.noBlast leaves the area attack beside it out, as for any big
  -- body; with it off the attack runs and its blast is the blow's own); the shield an arc wave in the core gives back is the
  -- controller's own, asked as its own chain asks it. The electrocution the authored chain applies after a meeting
  -- (FPC.sword.wave.shock) is reported as that attempt, at the same point, instead of being asked of the presentation body.
  local function wave_meet(R, W, x, y, z, rec)
    if not live(R) then return end
    local e = env()
    local FPF, P = e.FPF, e.P
    local K = nested(e.FPC, "sword", "wave")
    local radius = titan_shape()
    if type(K) ~= "table" or not finite(K.wide) or not finite(K.high) or radius == nil then
      refuse("wave", "the controller's arc wave has no width or height (FPC.sword.wave): remote Titans are not reached by it")
      return
    end
    if type(W) ~= "table" or type(W.hit) ~= "table" or type(rec) ~= "string" or not finite3(x, y, z) then return end
    local px, py, pz = position_of(R.ent)
    if px == nil then return end
    local dx, dy = px - x, py - y
    local d = math.sqrt(dx * dx + dy * dy)
    if d - radius > K.wide or math.abs(pz - z) > K.high + 2.0 then return end
    local key = key_of(R.ent)
    if key == nil or W.hit[key] then return end
    W.hit[key] = true
    W.people = (W.people or 0) + 1
    local hx, hy = px, py
    if d > 0.01 then hx, hy = px - dx / d * radius, py - dy / d * radius end
    if FPF.hit(R.ent, rec, hx, hy, pz + 1.0, W.fx, W.fy, 0.0) then W.sent = (W.sent or 0) + 1 end
    if FPF.attack(rec, hx, hy, pz + 0.5) then W.attacks = (W.attacks or 0) + 1 end
    if P.waveShield160 and W.step ~= nil and type(FPF.waveShield160) == "function" then
      local given, why = pcall(FPF.waveShield160, W, R.ent)
      if not given then diag("wave", "the shield of an arc wave in the core could not be given back: " .. tostring(why)) end
    end
    if K.shock then
      local asked, why = pcall(queue_status, R, K.shock)
      if asked then
        W.shocked = (W.shocked or 0) + 1
      else
        diag("wave", "the electrocution of an arc wave could not be reported: " .. tostring(why))
      end
    end
  end

  -- ------------------------------------------------------------------ the end of the frame -----------------------
  -- The live remote Titans as of the last frame, [Titan id] = { epoch, key }: compared with the observer's records in place, because
  -- the frame asks every game frame and a sorted list, its text and a closure per frame were allocations while a remote Titan is here.
  local liveRows, liveCount = {}, 0

  local function membership_changed()
    local n = 0
    for id, R in pairs(observer.remote) do
      if live(R) then
        n = n + 1
        local row = liveRows[id]
        if row == nil or row.epoch ~= R.epoch or row.key ~= key_of(R.ent) then return true end
      end
    end
    return n ~= liveCount
  end

  local function remember_membership()
    liveRows, liveCount = {}, 0
    for id, R in pairs(observer.remote) do
      if live(R) then
        liveRows[id] = { epoch = R.epoch, key = key_of(R.ent) }
        liveCount = liveCount + 1
      end
    end
  end

  local function still_there(target)
    local R = observer.remote[target.id]
    return R ~= nil and R.epoch == target.epoch and R.owner == target.owner and live(R)
  end

  local function report_of(entry)
    local t = entry.target
    return {
      target = { kind = t.kind, id = t.id, epoch = t.epoch, owner = t.owner },
      record = entry.record,
      origin = { x = entry.origin.x, y = entry.origin.y, z = entry.origin.z },
      point = { x = entry.point.x, y = entry.point.y, z = entry.point.z },
      direction = { x = entry.direction.x, y = entry.direction.y, z = entry.direction.z },
      kind = entry.kind,
      scale = entry.scale,
    }
  end

  local function distance(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
  end

  -- An area attack that a direct blow of the same record on the same Titan lies within one impact of is that blow's own
  -- blast: each direct blow covers at most one such attack, nearest first. Every direct blow is kept.
  local function resolve(batch)
    local covered, kept = {}, {}
    for i, a in ipairs(batch) do
      if a.sense == "area" then
        local best, near = nil, nil
        for j, d in ipairs(batch) do
          if d.sense == "direct" and not covered[j] and d.record == a.record and d.target.id == a.target.id
            and d.target.epoch == a.target.epoch then
            local gap = distance(d.point, a.center)
            if gap <= SAME_IMPACT and (near == nil or gap < near) then best, near = j, gap end
          end
        end
        if best ~= nil then
          covered[best] = true
          self.suppressed = self.suppressed + 1
        else
          kept[#kept + 1] = a
        end
      else
        kept[#kept + 1] = a
      end
    end
    return kept
  end

  local function flush_hits()
    if #pending == 0 then return end
    local batch = pending
    pending = {}
    for _, entry in ipairs(resolve(batch)) do
      if not still_there(entry.target) then
        self.gone = self.gone + 1
        diag("gone", "a blow on a remote Titan that has ended was not reported")
      elseif type(ctx.sendHit) ~= "function" then
        refuse("send", "a blow on a remote Titan has nowhere to go: ctx.sendHit is missing")
      else
        local ok, took = pcall(ctx.sendHit, report_of(entry))
        if ok and took == true then
          self.sent = self.sent + 1
        else
          refuse("send", "the bridge did not take a blow on a remote Titan (" .. entry.record .. "): "
            .. (ok and "its queue is full or closed" or tostring(took)))
        end
      end
    end
  end

  local function status_report_of(entry)
    local t = entry.target
    local report = { target = { kind = t.kind, id = t.id, epoch = t.epoch, owner = t.owner }, effect = entry.effect }
    if entry.duration ~= nil then report.duration = entry.duration end
    return report
  end

  -- Every status effect the controller asked in the frame, in the order asked, once each: nothing is merged and nothing is
  -- retried. The Titan is checked again here (its id, epoch and owner and that it is still live).
  local function flush_statuses()
    if #statuses == 0 then return end
    local batch = statuses
    statuses = {}
    for _, entry in ipairs(batch) do
      if not still_there(entry.target) then
        self.gone = self.gone + 1
        diag("status.gone", "a status effect on a remote Titan that has ended was not reported")
      elseif type(ctx.sendStatus) ~= "function" then
        refuse("status.send", "a status effect on a remote Titan has nowhere to go: ctx.sendStatus is missing")
      else
        local ok, took = pcall(ctx.sendStatus, status_report_of(entry))
        if ok and took == true then
          self.statuses = self.statuses + 1
        else
          refuse("status.send", "the bridge did not take a status effect on a remote Titan (" .. entry.effect .. "): "
            .. (ok and "its queue is full or closed" or tostring(took)))
        end
      end
    end
  end

  function self.frame()
    local e = env()
    if e == nil then return end
    if membership_changed() then
      remember_membership()
      -- the controller's list of people is rebuilt every quarter of a second (and kept for longer while it is fresh): a Titan
      -- that appeared or ended is in or out of it at its next refresh, not a moment later
      e.PS.npcsAt, e.PS.npcsMade166 = -10, nil
    end
    flush_hits()
    flush_statuses()
  end

  -- The owner's Titan or the session ended: what was waiting is not reported.
  function self.clear()
    pending = {}
    statuses = {}
  end

  function self.pendingCount()
    return #pending
  end

  function self.statusPendingCount()
    return #statuses
  end

  function self.status()
    return string.format("combat: %d blows reported, %d status effects reported, %d refused, %d dropped, %d blasts covered by their blow, %d duplicate blasts, %d waiting",
      self.sent, self.statuses, self.refused, self.gone, self.suppressed, self.duplicates, #pending + #statuses)
  end

  -- ------------------------------------------------------------------ the controller ---------------------------------
  -- Wraps the final authored functions, once for each controller attached. Every wrapper's first act is to tell whether the
  -- target is a remote Titan; a call about anything else reaches the authored function with its own arguments, unchanged.
  function self.install()
    local e = env()
    if e == nil then error("no controller is attached", 0) end
    if installed == e then return false end
    local FPF = e.FPF
    for _, name in ipairs(REQUIRED) do
      if type(FPF[name]) ~= "function" then error("controller function FPF." .. name .. " missing: this is not the supported release", 0) end
    end
    for _, name in ipairs(CALLED) do
      if type(FPF[name]) ~= "function" then error("controller function FPF." .. name .. " missing: this is not the supported release", 0) end
    end
    if titan_shape() == nil then error("controller table FPC.big.titan missing: this is not the supported release", 0) end
    if not finite(nested(e.FPC, "punchBig", "up")) then error("controller value FPC.punchBig.up missing: this is not the supported release", 0) end
    local base = {}
    for _, name in ipairs(REQUIRED) do base[name] = FPF[name] end
    installed = e
    pending = {}
    statuses = {}

    local function listed(list, shapes, seen, ok, ...)
      local added, err = pcall(append, list, shapes, seen)
      if not added then diag("list", "remote Titans could not be added to the controller's list of people: " .. tostring(err)) end
      if not ok then error((...), 0) end
      return ...
    end
    FPF.listMore = function(list, shapes, seen, ...)
      return listed(list, shapes, seen, pcall(base.listMore, list, shapes, seen, ...))
    end

    FPF.bigTarget = function(who, ...)
      local R = known(who)
      if R ~= nil then return live(R) end
      return base.bigTarget(who, ...)
    end

    FPF.wouldFight = function(ent, zone, ...)
      local R = known(ent)
      if R ~= nil then
        if live(R) then return true, "hostile" end
        return false
      end
      return base.wouldFight(ent, zone, ...)
    end

    FPF.hit = function(who, record, x, y, z, dx, dy, dz, ...)
      local R = known(who)
      if R == nil then return base.hit(who, record, x, y, z, dx, dy, dz, ...) end
      return take_direct(R, true, record, x, y, z, dx, dy, dz)
    end

    FPF.hitFull = function(who, record, x, y, z, dx, dy, dz, ...)
      local R = known(who)
      if R == nil then return base.hitFull(who, record, x, y, z, dx, dy, dz, ...) end
      return take_direct(R, false, record, x, y, z, dx, dy, dz)
    end

    FPF.attack = function(record, x, y, z, ...)
      local PS = env().PS
      local before = PS.noBlast
      local skipped = before ~= nil and before.skipped or 0
      local started = base.attack(record, x, y, z, ...)
      -- an attack the authored function left out beside a punch on a big body is covered by that punch's own blow
      local after = PS.noBlast
      if not (after ~= nil and after == before and (after.skipped or 0) > skipped) then
        local ok, err = pcall(queue_area, record, x, y, z)
        if not ok then diag("area", "a blast could not be tested against remote Titans: " .. tostring(err)) end
      end
      return started
    end

    FPF.punchTargets = function(range, angle, ...)
      local out = base.punchTargets(range, angle, ...)
      local ok, fixed = pcall(adjust_targets, out, range, angle)
      if ok then return fixed end
      diag("reach", "the fists' reach to a remote Titan could not be worked out: " .. tostring(fixed))
      return out
    end

    -- The designator's lock: a live remote Titan is designable as a person is, without being asked what only a puppet can
    -- answer (IsNPC, IsActive): it is defined and live (this module's own test), and its worth is the authored one.
    FPF.designable = function(ent, ...)
      local R = known(ent)
      if R == nil then return base.designable(ent, ...) end
      if not live(R) then return false end
      local asked, worth = pcall(function() return env().FPF.coreWorth(ent) end)
      if not asked then
        diag("designate", "the worth of a remote Titan could not be asked: " .. tostring(worth))
        return false
      end
      return worth ~= nil
    end

    FPF.spinTargets = function(reach, ...)
      local out = base.spinTargets(reach, ...)
      local ok, fixed = pcall(adjust_entries, out, spin_builder(reach), false)
      if ok then return fixed end
      diag("reach", "the sword's reach to a remote Titan could not be worked out: " .. tostring(fixed))
      return out
    end

    FPF.waveMeet = function(W, ent, kind, x, y, z, rec, ...)
      local R = (kind == "person") and known(ent) or nil
      if R == nil then return base.waveMeet(W, ent, kind, x, y, z, rec, ...) end
      local ok, err = pcall(wave_meet, R, W, x, y, z, rec)
      if not ok then diag("wave", "an arc wave could not be tested against a remote Titan: " .. tostring(err)) end
    end
    return true
  end

  return self
end

return M
