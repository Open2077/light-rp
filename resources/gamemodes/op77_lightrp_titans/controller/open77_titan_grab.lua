-- Open77 <-> BT-7274 controller bridge: the grab key.
--
-- The author's fists grab with the reload key and then do everything on the clip's own clock: the hand closes, lifts, swings
-- and lets go 2.5 s after it began, whether the player is ready or not. In Open77 a grab is something the player does on
-- purpose with one key, like every other interaction:
--   * while V pilots BT, a body the fists could take is offered (ctx.grabUi, phase "ready": the HUD draws it as a prompt).
--     It is the controller's own pick - FPF.grabTarget, the target the reach would turn BT to - narrowed to what the Titan
--     server lets BT carry: a canonical living person who is not seated, or a light vehicle that nobody drives or sits in (a
--     wreck is one), within the carry reach, with SENTRY MODE granted, never another player's body and never a vehicle too heavy
--     to lift. The same narrowing is applied to the controller's own selection (grabTarget sees only such bodies; a seated person
--     is never shown to it, so its own swap of that person for the car is never made), so the offer and the reach agree on the body;
--   * the key takes it. Another weapon in the hands gives way to the fists first (and comes back after the throw); then the
--     controller's own grab runs (open77_titan_carry still asks the server before anything is touched and pins the clip at
--     the grab point for the answer). When the body is in the hand the clip waits at HOLD_AT, the body lifted in front of BT
--     - the same kind of pin the carry uses - so that it stays there (phase "held");
--   * the key again, held, charges (phase "charging", over CHARGE_TIME); letting go lets the clip run on to the authored
--     release (a hold has no time limit: only the player throws it, or the claim ends), and the controller's
--     own throw runs with its power scaled from MIN_THROW to the whole of it by the charge. The scaling is made around that one call
--     (FPC.fist.cmd.toss.throw, the person's impulse, and FPC.fist.throw149.speed, a vehicle's flight speed) and put back after it.
-- The key is the one the controller itself reads for the Titan's hand. With the mod's key script present (S.keysOk, always the
-- case in this package) it listens to the Mod Settings keys - BT7274Keys.OnBind, where "punch" is E by default and "embark"
-- (climbing out, F) is another key altogether; without it, the game's use action (Choice1, held = climbing out). A press that
-- this module takes is removed from the batch of the game's events before the controller gets it (FPF.forwarded), together with
-- its hold and its release: no punch, no climb-out, no eject tap comes out of it. A press it does not take - nothing to offer, no
-- grab under way - reaches the controller untouched, and so does everything else; the key is claimed only for presses that
-- found something to take or belong to a grab under way.
-- A carry that ends for any reason (the server's answer, the claim's end, the Titan or the session going) clears the state,
-- lets the clip go on and takes the pin off. Outside an Open77 Titan session every wrapper here calls the controller's own
-- function unchanged. Another module reads ctx.grabUi; nothing here draws.

local _ENV = require("controller.open77_titan_env")
local schema = require("controller.open77_titan_schema")
local carryMod = require("controller.open77_titan_carry")

local M = {}

local finite = schema.finite
local max, min = math.max, math.min

local PROBE_EVERY = 0.2          -- s: how often the offer is worked out (5 Hz); a press works it out afresh
local SCAN_LIFE = 0.5            -- s: the list of the NPCs that tells a canonical person from a passer-by is reused this long
local REACH = 12.0               -- m: the server's carryReach (shared.lua): the grab is never offered farther than this
-- s of the throw clip at which the hand waits with the body: the end of the pull-in, just before the wind-up starts, both feet
-- down (chosen live on 2026-11-04 from 0.9-2.03 s; 0.5 s before the release, the old place, is the wind-up's top with one foot in
-- the air). The release then plays the rest of the clip: the wind-up and the throw.
local HOLD_AT = 1.9
local CHARGE_TIME = 1.5          -- s of the key held to a full charge
local MIN_THROW = 0.35           -- of the authored throw: a tap, and a hold that was never charged
local ARM_MAX = 4.0              -- s for the fists to come out (the first-person objects are made again)
local START_WAIT = 0.75          -- s for the controller to start the reach once it was asked
local REACH_MAX = 5.0            -- s for the reach to end in a hold or a miss (the hit, the server's 2 s, the refusal's 0.35 s)
local AFTER_MAX = 4.0            -- s the rest of the throw's clip is waited for
local RESTORE_MAX = 6.0          -- s for the weapon the key took out of the hands to come back
local COOLDOWN = 1.1             -- s after a grab that took nothing: the server's request gap is a second
local KEY_STALE = 5.0            -- s: a key that is still "down" after this has lost its release
local GRACE = 0.3                -- s after a claimed release in which a stray hold or release event of the key is still claimed
local PUNCH_KEY = "punch"        -- BT7274Keys.OnBind's name of the melee key
local USE = { Choice1 = true, Choice1_Hold = true, ChoiceApply = true, Choice1_Release = true }

local function wrap180(a) return (a + 180.0) % 360.0 - 180.0 end
local function clamp(v, lo, hi) return max(lo, min(hi, v)) end

-- The 64 bits of a decimal entity id as a Lua integer (integer arithmetic wraps, as the engine's unsigned id does).
local function native_bits(text)
  local bits = 0
  for i = 1, #text do bits = bits * 10 + (text:byte(i) - 48) end
  return bits
end

local function same_entity(value, text, bits)
  if math.type(value) == "integer" then return value == bits end
  return value == text
end

local function canonical_id(value) return math.type(value) == "integer" and value >= 1 end

-- The canonical Open77 id of the vehicle `ent` is: the lookup client.lua's resolveVehicle makes for a carry request (the entity id
-- as decimal text, the answer checked against the engine's own id), shared by the grab key and by the bridge, which names a car
-- its Titan damaged by it. Returns the id (an integer) and the platform's snapshot, or nil and why (a car this machine's
-- population spawned has no canonical id).
function M.vehicle_id(ent)
  local text, why = carryMod.native_id(ent)
  if not text then return nil, why end
  local ok, snap = pcall(function() return Open77.vehicles.fromEntity(text) end)
  if not ok or type(snap) ~= "table" then return nil, "unknown_entity" end
  if not canonical_id(snap.id) or not same_entity(snap.engineEntity, text, native_bits(text)) then return nil, "entity_unresolved" end
  return snap.id, snap
end

function M.new(ctx, carry)
  local self = {
    state = "idle",            -- idle | arming | reach | held | charging | throwing | after | restoring
    keyDown = false, downAt = 0.0, engaged = false, graceTill = 0.0,
    probeAt = -100.0, cooldownTill = 0.0, scanned = { at = -100.0, index = nil },
    prevWeapon = nil, armAt = 0.0, fireAt = 0.0, afterAt = 0.0, restoreAt = 0.0,
    c = nil, M = nil, holdClip = nil, pinAt = nil, lungeT = nil,
    chargeAt = nil, throwScale = nil, releasing = false,
    grabs = 0, throws = 0, fails = 0,
  }
  local masking = false

  local function E() return ctx.env end

  function self.status()
    return string.format("grab %s (taken %d, thrown %d, failed %d)", self.state, self.grabs, self.throws, self.fails)
  end

  -- ---------------------------------------------------------------- what the player can grab -----------------------
  local function piloting(env)
    local S, PS = env.S, env.PS
    return S.driving and S.pilot and PS.mode == "pilot" and PS.ent ~= nil and not S.gone
  end

  local function alive(env)
    return ctx.session.active and ctx.titan ~= nil and ctx.link ~= nil and piloting(env)
  end

  -- Nothing that would make the controller ignore a grab asked for now, or the server refuse it before it looks at a body.
  local function base_ready(env)
    local S, PS, FPF = env.S, env.PS, env.FPF
    if not alive(env) or S.paused or PS.eject or PS.exec then return false end
    if ((ctx.levels and ctx.levels.sentry) or 0) < 1 then return false end   -- the grab comes with SENTRY MODE (server.lua refuses it without)
    if FPF.held() then return false end   -- a held Titan takes no grab: the key passes on to the controller, whose hold drops it
    -- the fists come out for a grab (ctx.selectWeapon), and a weapon whose perk is 0 cannot be selected: no offer, the melee key stays a punch
    if PS.weapon ~= "fist" and ctx.canWield and not ctx.canWield("fist") then return false end
    if carry.c ~= nil or PS.punch ~= nil or PS.pound or PS.fistCharge or PS.fistPress then return false end
    if PS.vortex and PS.vortex.on then return false end
    if type(FPF.flightImmune) == "function" then
      local ok, immune = pcall(FPF.flightImmune)
      if ok and immune then return false end
    end
    return true
  end

  -- The Open77 NPCs this client knows, as the platform lists them: engine entity id -> row, reused for SCAN_LIFE. A row that has no
  -- engine id yet (0) is not a body the hand could be told from a passer-by with, and is left out.
  local function scan()
    local s = self.scanned
    if s.index ~= nil and ctx.clock - s.at < SCAN_LIFE then return s.index end
    local ok, rows = pcall(Open77.npcs.all)
    s.at = ctx.clock
    if not ok or type(rows) ~= "table" then
      s.index = {}            -- a failed scan is reused as long as a good one: nobody is told from a passer-by without it
      ctx.diag("grab.scan", "the NPC list that tells a canonical person from a passer-by failed: " .. tostring(ok and "no rows" or rows))
      return s.index
    end
    local index = {}
    for _, row in ipairs(rows) do
      local e = type(row) == "table" and row.engineEntity or nil
      if e ~= nil and e ~= 0 and e ~= "0" then index[e] = row end
    end
    s.index = index
    return index
  end

  -- Whether the Titan server could be asked for this body: what client.lua resolves (resolveNpc / resolveVehicle) and the
  -- server admits, as far as this machine can tell - a canonical, streamed, living person who is not seated, or a streamed vehicle
  -- that nobody drives or sits in (a wreck is one) and is not too heavy to lift; never another player's body.
  function self.grabbable(X)
    local ent = X.ent
    if ent == nil or not IsDefined(ent) then return false end
    if ctx.playerBody and ctx.playerBody(ent) then return false end
    local text = carryMod.native_id(ent)
    if not text then return false end
    local bits = native_bits(text)
    if X.kind == "vehicle" then
      if carry.vehicle_heavy(ent) then return false end
      local id, snap = M.vehicle_id(ent)
      if id == nil or snap.streamed ~= true or snap.aiDriven == true then return false end
      return type(snap.occupants) ~= "table" or #snap.occupants == 0
    end
    local index = scan()
    local row = index and (index[bits] or index[text])
    if not row or not canonical_id(row.id) then return false end
    if row.streamed ~= true or row.entity == 0 or (row.health or 0) <= 0 then return false end
    -- a seated person is the car's to carry, which the controller's own test knows (FPF.tossGrab swaps in the car of one)
    local e = E()
    if e and type(e.FPF.seated149) == "function" then
      local okSeat, seated = pcall(e.FPF.seated149, ent)
      if okSeat and seated then return false end
    end
    return true
  end
  -- The same rule gates the carry module's request, whatever the fist itself found (see open77_titan_carry `begin`).
  carry.allows = function(target)
    return self.grabbable({ ent = target.ent, kind = target.kind == "vehicle" and "vehicle" or "person" })
  end

  -- The offer: the controller's own target, which is already narrowed to what can be taken.
  local function probe_target(env, fresh)
    if fresh then self.scanned.index = nil end
    local K = env.FPC.fist.cmd.grab
    local ok, X = pcall(env.FPF.grabTarget, K.look, K.cone)
    if not ok then
      ctx.diag("grab.probe", "the controller's grab target could not be asked for: " .. tostring(X))
      return nil
    end
    if type(X) ~= "table" or X.ent == nil or not finite(X.dist) or X.dist > min(K.look, REACH) then return nil end
    return { kind = X.kind == "vehicle" and "vehicle" or "person", ent = X.ent, d = X.dist, key = X.key }
  end

  -- The key's name as the HUD shows it: the controller's own word for the key it listens to (read again every two seconds).
  local label = { word = nil, at = -100.0 }
  local function key_label(env)
    if label.word ~= nil and ctx.clock - label.at < 2.0 then return label.word end
    local FPF = env.FPF
    local fn, field = FPF.keyWord, "punchKey"
    if not env.S.keysOk then fn, field = FPF.useKeyWord, nil end
    local word = "E"
    if type(fn) == "function" then
      local ok, got = pcall(fn, field)
      if ok and type(got) == "string" and got ~= "" and got ~= "?" then word = got end
    end
    label.word, label.at = word, ctx.clock
    return word
  end

  -- ---------------------------------------------------------------- the clip's pin -----------------------------------
  local function unpin()
    local M_ = self.M
    if M_ ~= nil and self.pinAt ~= nil and M_.hold == self.pinAt then M_.hold = nil end
    self.pinAt = nil
  end

  -- BT turns with the view while it holds, as the controller's own throw does (P.tossView145: the throw goes where the view
  -- points). The clip's yaw at the held time is fixed, so the offset the controller adds to it follows the view.
  local function turn_with_view(env, M_, dt)
    local rate = env.FPC.fist.tossView145 and env.FPC.fist.tossView145.turn or 420.0
    local clip = 0.0
    if type(env.FPF.cmdYawAt) == "function" then
      local ok, v = pcall(env.FPF.cmdYawAt, M_.clip, M_.hold)
      if ok and finite(v) then clip = v end
    end
    if not finite(env.S.yaw) or not finite(M_.yaw0) then return end
    local d = wrap180(wrap180(env.S.yaw - clip) - M_.yaw0)
    local most = rate * (finite(dt) and dt or 0.016)
    M_.yaw0 = wrap180(M_.yaw0 + clamp(d, -most, most))
  end

  -- The hand waits with the body: the clip is held (displayed and counted) at the held time, BT stands where it is.
  local function pin(env, dt)
    local M_ = self.M
    local at = self.holdClip
    if M_.t < at then return end
    M_.t, M_.hold, self.pinAt = at, at, at
    local L = env.PS.lunge
    if L and L.punch == M_ then
      self.lungeT = self.lungeT or L.t
      L.t = self.lungeT
    end
    turn_with_view(env, M_, dt)
  end

  -- ---------------------------------------------------------------- ending ---------------------------------------------
  -- The state back to nothing, whatever it was; the weapon is not restored (the Titan, the seat or the session is gone).
  local function clear()
    unpin()
    self.state = "idle"
    self.c, self.M, self.holdClip, self.lungeT = nil, nil, nil, nil
    self.chargeAt, self.throwScale, self.prevWeapon = nil, nil, nil
    ctx.grabUi = nil
  end

  -- The reach or the hold is over and the Titan is still in its seat: the weapon the key took out of the hands comes back.
  local function finish()
    unpin()
    self.c, self.M, self.holdClip, self.lungeT = nil, nil, nil, nil
    self.chargeAt, self.throwScale = nil, nil
    ctx.grabUi = nil
    local env = E()
    if self.prevWeapon ~= nil and env ~= nil and env.PS.weapon == "fist" then
      self.state, self.restoreAt = "restoring", ctx.clock
    else
      self.prevWeapon = nil
      self.state = "idle"
    end
  end

  local function fail(why)
    self.fails = self.fails + 1
    ctx.diag("grab.fail." .. tostring(why), "the grab key took nothing: " .. tostring(why))
    self.cooldownTill = ctx.clock + COOLDOWN
    finish()
  end

  local function enter_after()
    unpin()
    self.throwScale = nil
    ctx.grabUi = nil
    self.state, self.afterAt = "after", ctx.clock
  end

  -- ---------------------------------------------------------------- the grab -------------------------------------------
  local function fire()
    local ok, why = carry.request_grab()
    if not ok then return fail(why) end
    self.state, self.fireAt, self.M = "reach", ctx.clock, nil
  end

  -- Fists first: the weapon command the bridge already has (the controller's own pick, the first-person model made again),
  -- repeated every frame while the first-person objects are still settling.
  local function arm(env)
    local PS = env.PS
    if ctx.clock - self.armAt > ARM_MAX then return fail("the fists did not come out") end
    if PS.weapon ~= "fist" then
      if not (ctx.selectWeapon and ctx.selectWeapon("fist")) then return end
      if PS.weapon ~= "fist" then return fail("the controller would not take the fists out") end
    end
    if ctx.firstPersonSettling and ctx.firstPersonSettling() then return end
    if probe_target(env, true) == nil then return fail("nothing was left to take") end
    fire()
  end

  local function begin(env)
    ctx.grabUi = nil
    if env.PS.weapon ~= "fist" then
      self.prevWeapon = env.PS.weapon
      self.state, self.armAt = "arming", ctx.clock
      return arm(env)
    end
    self.prevWeapon = nil
    fire()
  end

  local function enter_held(env, c)
    self.state, self.c = "held", c
    local clip = self.M.clip or {}
    local hit = clip.hits and clip.hits[2]
    self.holdClip = math.min(HOLD_AT, hit and hit.t or clip.release or clip.time or HOLD_AT)
    self.chargeAt, self.lungeT = nil, nil
    self.grabs = self.grabs + 1
  end

  local function charge_now()
    if self.chargeAt == nil then return 0.0 end
    return clamp((ctx.clock - self.chargeAt) / CHARGE_TIME, 0.0, 1.0)
  end

  -- Let go: the clip runs on to its release hit and the controller's own throw runs there, scaled by what was charged.
  local function throw(why)
    if self.state ~= "held" and self.state ~= "charging" then return end
    local charge = self.state == "charging" and charge_now() or 0.0
    self.throwScale = MIN_THROW + (1.0 - MIN_THROW) * charge
    self.throws = self.throws + 1
    unpin()
    self.state = "throwing"
    ctx.grabUi = nil
    ctx.log(string.format("grab: thrown at %d%% of the authored throw (%s)", math.floor(self.throwScale * 100.0 + 0.5), why))
  end

  local function publish_hold(env)
    local c = self.c
    ctx.grabUi = {
      phase = self.state, key = key_label(env), label = "Throw", target = c.kind == "vehicle" and "vehicle" or "person",
      charge = self.state == "charging" and charge_now() or nil,
    }
  end

  local function publish_ready(t, env)
    local g = ctx.grabUi
    if t == nil then
      ctx.grabUi = nil
    elseif not (g and g.phase == "ready" and g.target == t.kind) then
      ctx.grabUi = { phase = "ready", key = key_label(env), label = "Grab", target = t.kind }
    end
  end

  -- ---------------------------------------------------------------- the key --------------------------------------------
  -- A press of the grab key; true when the grab takes it (the controller must not see it).
  function self.press()
    local s = self.state
    if s == "idle" then
      local env = E()
      if env == nil or ctx.clock < self.cooldownTill or not base_ready(env) then return false end
      if probe_target(env, true) == nil then return false end
      begin(env)
      return true
    end
    if s == "held" then
      self.state, self.chargeAt = "charging", ctx.clock
      return true
    end
    return true          -- a grab is under way (the fists coming out, the reach, a charge, the throw): the key is spent on it
  end

  function self.release()
    if self.state == "charging" then throw("the key was let go") end
  end

  -- One press or release of the key, from whichever of the controller's two paths carries it; true when it is the grab's.
  function self.key_event(down)
    local now = ctx.clock
    if down then
      if self.keyDown and now - self.downAt < KEY_STALE then return self.engaged end
      self.keyDown, self.downAt = true, now
      self.engaged = self.press()
      return self.engaged
    end
    self.keyDown = false
    local was = self.engaged
    self.engaged = false
    if was then
      self.graceTill = now + GRACE
      self.release()
    end
    return was
  end

  local function without(B, dropA, dropK)
    local out = {
      dropped = B.dropped, hits = B.hits, ends = B.ends,
      actionNames = {}, actionKinds = {}, actionValues = {}, keyNames = {}, keyDown = {},
    }
    local names, kinds, values = B.actionNames, B.actionKinds, B.actionValues
    for i = 1, names and #names or 0 do
      if not (dropA and dropA[i]) then
        local n = #out.actionNames + 1
        out.actionNames[n], out.actionKinds[n], out.actionValues[n] = names[i], kinds[i], values[i]
      end
    end
    local keys, downs = B.keyNames, B.keyDown
    for i = 1, keys and #keys or 0 do
      if not (dropK and dropK[i]) then
        local n = #out.keyNames + 1
        out.keyNames[n], out.keyDown[n] = keys[i], downs[i]
      end
    end
    return out
  end

  -- The batch of the game's events the controller is about to get, without the key presses (and the holds and releases that
  -- belong to them) that the grab took. The batch itself when nothing was taken.
  function self.filter(B)
    if type(B) ~= "table" or not ctx.session.active or ctx.titan == nil then return B end
    local env = E()
    if env == nil then return B end
    local names, kinds, keys, downs = B.actionNames, B.actionKinds, B.keyNames, B.keyDown
    local nA, nK = names and #names or 0, keys and #keys or 0
    if nA + nK == 0 then return B end
    local dropA, dropK
    if env.S.keysOk == true then
      for i = 1, nK do
        if keys[i] == PUNCH_KEY and self.key_event(downs[i] == true) then
          dropK = dropK or {}
          dropK[i] = true
        end
      end
    else
      local T = gameinputActionType
      for i = 1, nA do
        local name = names[i]
        if USE[name] then
          local taken
          if name == "Choice1" and T ~= nil and kinds[i] == T.BUTTON_PRESSED then
            taken = self.key_event(true)
          elseif name == "Choice1" and T ~= nil and kinds[i] == T.BUTTON_RELEASED then
            taken = self.key_event(false)
          else
            taken = self.engaged or ctx.clock < self.graceTill
          end
          if taken then
            dropA = dropA or {}
            dropA[i] = true
          end
        end
      end
    end
    if dropA == nil and dropK == nil then return B end
    return without(B, dropA, dropK)
  end

  -- ---------------------------------------------------------------- per frame ------------------------------------------
  function self.tick(dt)
    local env = E()
    if env == nil then return end
    if not alive(env) then
      if self.state ~= "idle" or ctx.grabUi ~= nil then clear() end
      return
    end
    local state, PS = self.state, env.PS
    if state == "idle" then
      if ctx.clock - self.probeAt >= PROBE_EVERY then
        self.probeAt = ctx.clock
        local t = nil
        if ctx.clock >= self.cooldownTill and base_ready(env) then t = probe_target(env, false) end
        publish_ready(t, env)
      end
    elseif state == "arming" then
      arm(env)
    elseif state == "reach" then
      local M_ = PS.punch
      if M_ ~= nil and M_.cmd and M_.fistKind == "toss" then self.M = M_ end
      local c = carry.c
      if self.M ~= nil and c ~= nil and c.M == self.M and c.phase == "holding" and c.Cr ~= nil and not c.Cr.thrown then
        enter_held(env, c)
        return self.tick(dt)
      end
      if self.M == nil then
        if ctx.clock - self.fireAt > START_WAIT then fail("the controller did not start the reach") end
      elseif PS.punch ~= self.M then
        fail("the reach ended without a carry")
      elseif ctx.clock - self.fireAt > REACH_MAX then
        fail("the reach was never answered")
      end
    elseif state == "held" or state == "charging" then
      local c, M_ = self.c, self.M
      local Cr = c.Cr
      if Cr ~= nil and Cr.thrown then return enter_after() end
      if not (carry.c == c and c.phase == "holding" and PS.punch == M_ and M_.carry == Cr) then
        return finish()
      end
      pin(env, dt)
      publish_hold(env)
    elseif state == "throwing" then
      local c = self.c
      local Cr = c and c.Cr
      if (Cr ~= nil and Cr.thrown) or carry.c ~= c or PS.punch ~= self.M then enter_after() end
    elseif state == "after" then
      if PS.punch ~= self.M or ctx.clock - self.afterAt > AFTER_MAX then finish() end
    elseif state == "restoring" then
      local want = self.prevWeapon
      if want == nil or PS.weapon ~= "fist" then
        self.prevWeapon, self.state = nil, "idle"
      elseif ctx.clock - self.restoreAt > RESTORE_MAX then
        ctx.diag("grab.restore", "the weapon the grab key took out of BT's hands did not come back")
        self.prevWeapon, self.state = nil, "idle"
      elseif PS.punch == nil and ctx.selectWeapon and ctx.selectWeapon(want) then
        self.prevWeapon, self.state = nil, "idle"
      end
    end
  end

  -- A new session, or the end of one: no state, no claim on the key, nothing shown.
  function self.reset()
    clear()
    self.keyDown, self.engaged, self.graceTill = false, false, 0.0
    self.probeAt, self.cooldownTill, self.scanned = -100.0, 0.0, { at = -100.0, index = nil }
    label.word = nil
  end

  -- ---------------------------------------------------------------- the controller ---------------------------------------
  local REQUIRED = { "grabTarget", "punchTargets", "tossRelease", "forwarded", "upperShare" }

  function self.attach(env)
    local FPF = env.FPF
    for _, name in ipairs(REQUIRED) do
      if FPF[name] == nil then error("controller function FPF." .. name .. " missing: this is not the supported release", 0) end
    end
    local K = env.FPC.fist and env.FPC.fist.cmd and env.FPC.fist.cmd.grab
    if type(K) ~= "table" or not finite(K.look) or not finite(K.cone) then
      error("the controller's grab reach (FPC.fist.cmd.grab.look and cone) is missing: this is not the supported release", 0)
    end
    local legs = env.FPC.sword and env.FPC.sword.legs
    if type(legs) ~= "table" or not finite(legs.fade) or legs.fade <= 0.0 then
      error("the controller's leg split fade (FPC.sword.legs.fade) is missing: this is not the supported release", 0)
    end
    self.reset()

    -- The controller's own selection sees only bodies the server could be asked for (while a Titan is granted), inside its own
    -- grabTarget: the list of the fists' targets is filtered there and nowhere else.
    local punchTargets = FPF.punchTargets
    FPF.punchTargets = function(...)
      local list = punchTargets(...)
      if not masking or type(list) ~= "table" then return list end
      local out = {}
      for _, X in ipairs(list) do
        if X.ent == nil or (X.r or 0.0) > 0.0 or self.grabbable(X) then out[#out + 1] = X end
      end
      return out
    end

    local grabTarget = FPF.grabTarget
    FPF.grabTarget = function(look, cone)
      if not (ctx.session.active and ctx.titan ~= nil) then return grabTarget(look, cone) end
      local was = masking
      masking = true
      local ok, X, b, c = pcall(grabTarget, look, cone)
      masking = was
      if not ok then error(X, 0) end
      if type(X) == "table" and X.ent ~= nil and not self.grabbable(X) then return nil end   -- a seated person's car, say
      return X, b, c
    end

    -- The throw of a body the key let go: the authored function, with its power scaled around that one call.
    local tossRelease = FPF.tossRelease
    FPF.tossRelease = function(M_)
      local f = self.throwScale
      local e = E()
      local toss = e and e.FPC.fist.cmd.toss
      if f == nil or self.releasing or M_ ~= self.M or type(toss) ~= "table" or not finite(toss.throw) then return tossRelease(M_) end
      local aim = e.FPC.fist.throw149
      local throw0, speed0 = toss.throw, type(aim) == "table" and aim.speed or nil
      self.releasing = true
      toss.throw = throw0 * f
      if finite(speed0) then aim.speed = speed0 * f end
      local ok, err = pcall(tossRelease, M_)
      toss.throw = throw0
      if finite(speed0) then aim.speed = speed0 end
      self.releasing = false
      if not ok then error(err, 0) end
    end

    -- While a body is in the hand (held or charging) BT's legs are its own - the stand or the walk - and the throw clip moves the
    -- arms only, so the pose waiting at HOLD_AT never freezes the legs. Released, the throw splits by movement as every blow with a
    -- leg split does (FPF.upperShare): standing, the whole body throws, legs and all; walking, the arms throw and the legs walk.
    -- The share is kept with the controller's own fade state (PS.upperU, FPC.sword.legs.fade), so neither change pops.
    local upperShare = FPF.upperShare
    FPF.upperShare = function(clip)
      local e = E()
      if e == nil or (self.state ~= "held" and self.state ~= "charging") or self.M == nil or e.PS.punch ~= self.M then
        return upperShare(clip)
      end
      local PS, S, K = e.PS, e.S, e.FPC.sword.legs
      local u = PS.upperU
      if not finite(u) or S.clock - (PS.upperUAt or -10.0) > 0.25 then
        u = 1.0
      else
        local step = (finite(S.dt) and S.dt or 0.016) / K.fade
        u = u + clamp(1.0 - u, -step, step)
      end
      PS.upperU, PS.upperUAt = u, S.clock
      return u
    end

    -- The game's events, without the presses the grab took.
    local forwarded = FPF.forwarded
    FPF.forwarded = function(B)
      local ok, filtered = pcall(self.filter, B)
      if not ok then
        ctx.diag("grab.filter", "the grab key could not be read from the game's events: " .. tostring(filtered))
        filtered = B
      end
      return forwarded(filtered)
    end
  end

  return self
end

return M
