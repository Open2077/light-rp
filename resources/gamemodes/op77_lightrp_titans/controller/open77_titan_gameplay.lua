-- Open77 <-> BT-7274 controller bridge: the owner-local gameplay seam.
--
-- The owner's machine keeps running the author's own simulation of BT (its health pools, magazine, core, abilities); this
-- module is the one place mission code reaches it through, on that machine and nowhere else. It is not a second simulation
-- and not a server-authoritative claim: it reads what the controller holds and hands blows and repairs to the controller's
-- own functions.
--   * snapshot(env): a detached, compact, typed copy of the authored fields. A substate the controller has not created, or
--     does not model, is omitted - a zero is never invented for it. Seconds are on the controller's own clock (S.clock),
--     which stands still while the game is paused. The pause is only what the controller cached (PS.pauseLast / PS.pauseBy);
--     nothing here calls the game.
--   * hit(env, request): the final FPF.bossHit, so the vortex shield, the phase dash, the parry, the flight and sentry
--     perks, the smoke cover and the loadout's resistances all apply exactly as for another mod's blow. The pools change at
--     the controller's next frame, not in this call; `damage` is the controller's estimate of what it took.
--   * repair(env, amount): hull points back, never above the full hull, never the shield, never an end that already came
--     (H.gone). FPF.healthSet is not this: it is a diagnostic that removes the shield and holds the regeneration for a minute.
--   * creditCore(env, request): the BURST CORE charge the controller gives for a blow or a kill the server confirmed on another
--     player's Titan, by the controller's own functions (FPF.coreBossCredit, FPF.coreOnce, FPF.coreGain): no health, no game
--     event and no sums of this module's own.
--   * creditKill(env, rank): the BURST CORE charge the author's own kill table gives a foe of a rank the server's `creditKill`
--     names (FPC.perk.core.kill: grunt, rare, heavy), through FPF.coreGain, with the rules of a kill the game itself reported.
--   * fillCore(env): the restricted `titan.core` test command: the core filled to its ceiling, set directly (not through
--     FPF.coreGain, whose gates and scale a test fill must not meet).
-- `env` is the table the controller hands the bridge at attach ({S, PS, P, FPF, FPC, ...}); the dash numbers need `TF` and
-- `DASH` in it as well (file-local constants of the controller, not part of its attach table by themselves).
-- No network, no timer, no engine lookup, no access to arbitrary controller state or functions.

local _ENV = require("controller.open77_titan_env")

local M = {}

local max, huge, floor = math.max, math.huge, math.floor

-- The controller functions this module calls (the bridge's attach refuses a controller that lacks one).
M.REQUIRED_FPF = {
  "bossHit", "magSize", "coreMax", "perk", "perkValue", "sentryOn", "mtmsDry", "mtmsSalvo", "mtmsRecharge",
  "vortexTime", "vortexCost", "vortexRecharge", "smokeRecharge",
  "coreBossCredit", "coreOn", "coreOnce", "coreGain", "flightImmune",
}

local function finite(v)
  return type(v) == "number" and v == v and v > -huge and v < huge
end

-- ------------------------------------------------------------------ snapshot ---------------------------------------
-- The hull is FPC.health.segment * segments (HULL PLATING adds a segment), the shield and the doomed pool their own
-- numbers. `current` is the hull alone. Dead is the controller's own end: its health gone (H.gone, FPF.health) or the
-- death scene of a BT with nobody in it (FPF.deathStart).
local function health(env, H)
  local K, act = env.FPC.health, env.PS.act
  return {
    current = H.health, max = K.segment * K.segments,
    shield = H.shield, shieldMax = K.shield,
    doomed = H.doomed or 0.0, doomedMax = K.doomed,
    dead = H.gone == true or (act ~= nil and act.kind == "death"),
  }
end

-- The gun the controller made when V took the seat (PS.gun). The broadsword and the fists carry no magazine.
local function ammo(env)
  local G = env.PS.gun
  if G == nil or type(G.ammo) ~= "number" then return nil end
  local capacity = env.FPF.magSize()
  if capacity <= 0 then return nil end
  return { current = G.ammo, capacity = capacity, reloading = G.reloadT ~= nil }
end

-- PS.core exists once the BURST CORE perk is on (FPF.coreFrame); `left` is the burst's remaining time while it burns.
local function core(env)
  local C = env.PS.core
  if C == nil then return nil end
  return { charge = C.charge, max = env.FPF.coreMax(), active = C.left ~= nil }
end

-- FPF.jumpCan's "it is in a jump": one that has not handed back to walking. The controller has no wait between jumps.
local function jump(env)
  local J = env.PS.jump
  return { active = J ~= nil and not (J.out or (J.stage == "land" and J.free)) }
end

-- A dash lasts DASH.time from PS.dashT = 0; the next one needs TF.dodgeDrain of PS.power and TF.dodgeTime + TF.dodgeInterval
-- since the last (the controller's gait step). Power comes back at TF.powerRegen times the THRUSTER REGEN perk a second
-- once TF.powerDelay has passed - not while skating, when the time cannot be told.
local function dash(env)
  local PS, TF, DASH = env.PS, env.TF, env.DASH
  local running = PS.dashT
  local out = { active = running ~= nil }
  if DASH ~= nil and running ~= nil then out.remaining = max(0.0, DASH.time - running) end
  if TF ~= nil and finite(PS.power) and finite(PS.sinceDash) then
    local gap = max(0.0, TF.dodgeTime + TF.dodgeInterval - PS.sinceDash)
    local short = TF.dodgeDrain - PS.power
    if short <= 0.0 then
      out.cooldown = gap
    elseif not PS.skate then
      local rate = TF.powerRegen * env.FPF.perkValue("dashregen")
      out.cooldown = max(gap, max(0.0, TF.powerDelay - PS.sinceDash) + short / rate)
    end
  end
  return out
end

-- PS.mtms (FPF.mtmsFrame): `frac` is the share of the pods used. A missile is there once (1 - frac) * salvo reaches one
-- (FPF.mtmsDry); the share then falls at 1 / mtmsRecharge a second, starting FPC.mtms.delay after the last use and only
-- while no salvo is held or queued.
local function missiles(env)
  local Q = env.PS.mtms
  if Q == nil then return nil end
  local FPF = env.FPF
  local active = Q.held == true or #Q.queue > 0
  local out = { active = active }
  if not FPF.mtmsDry(Q) then
    out.cooldown = 0.0
  elseif not active then
    local wait = max(0.0, env.FPC.mtms.delay - (env.S.clock - Q.lastUse))
    out.cooldown = wait + (Q.frac - (1.0 - 1.0 / FPF.mtmsSalvo())) * FPF.mtmsRecharge()
  end
  return out
end

-- PS.vortex (FPF.vortexFrame): `frac` is the share of the charge used; the shield uses it up in vortexTime seconds and a
-- new one needs frac + vortexCost < 1, which the charge reaches at 1 / vortexRecharge a second after FPC.vortex.delay.
local function vortex(env)
  local V = env.PS.vortex
  if V == nil then return nil end
  local FPF = env.FPF
  local out = { active = V.on == true }
  if V.on then
    out.remaining = max(0.0, 1.0 - V.frac) * FPF.vortexTime()
  else
    local over = V.frac + FPF.vortexCost() - 1.0
    if over < 0.0 then
      out.cooldown = 0.0
    else
      out.cooldown = max(0.0, env.FPC.vortex.delay - (env.S.clock - V.lastUse)) + over * FPF.vortexRecharge()
    end
  end
  return out
end

-- PS.esmoke (FPF.smokeFrame): `charge` counts charges and fills at 1 / smokeRecharge a second; one is needed. A cloud
-- hurts for FPC.esmoke.life seconds from its start (PS.clouds, FPF.cloudsOut152).
local function smoke(env)
  local Q = env.PS.esmoke
  if Q == nil then return nil end
  local life, now = env.FPC.esmoke.life, env.S.clock
  local out = { active = false }
  for _, cloud in ipairs(env.PS.clouds) do
    local left = life - (now - cloud.at)
    if left > 0.0 then
      out.active = true
      if out.remaining == nil or left > out.remaining then out.remaining = left end
    end
  end
  out.cooldown = (Q.charge >= 1.0) and 0.0 or (1.0 - Q.charge) * env.FPF.smokeRecharge()
  return out
end

-- PS.flight runs FPC.perk.flightStrike.time seconds (F.t counts up). What starts one is a full core, not a wait.
local function flight(env)
  local F = env.PS.flight
  if F == nil then
    if env.FPF.perk("flight") < 1 then return nil end
    return { active = false }
  end
  if F.on ~= true then return { active = false } end
  return { active = true, remaining = max(0.0, env.FPC.perk.flightStrike.time - F.t) }
end

-- PS.sentry lasts FPC.perk.sentryMode.time from its start (R.at); PS.sentryReadyAt is when the next may begin.
local function sentry(env)
  local FPF, PS, now = env.FPF, env.PS, env.S.clock
  local on = FPF.sentryOn()
  if not on and FPF.perk("sentry") < 1 then return nil end
  local out = { active = on, cooldown = max(0.0, (PS.sentryReadyAt or 0.0) - now) }
  if on then out.remaining = max(0.0, env.FPC.perk.sentryMode.time - (now - PS.sentry.at)) end
  return out
end

-- Returns the state, or nil and why there is none: "no_session" (the controller is let go of everything) or "no_titan"
-- (no health table: no BT was called, or it is destroyed). The abilities, the gun and the core are BT's while it stands in
-- the world; its health stays with it while it is away.
function M.snapshot(env)
  local S, PS = env.S, env.PS
  if S.gone then return nil, "no_session" end
  local H = PS.hp
  if H == nil then return nil, "no_titan" end
  local out = { health = health(env, H), paused = PS.pauseLast == true }
  if out.paused and type(PS.pauseBy) == "string" then out.pauseReason = PS.pauseBy end
  if PS.ent ~= nil then
    out.ammo, out.core = ammo(env), core(env)
    out.abilities = {
      jump = jump(env), dash = dash(env), missiles = missiles(env), vortex = vortex(env), smoke = smoke(env),
      flight = flight(env), sentry = sentry(env),
    }
  end
  return out
end

-- ------------------------------------------------------------------ hit --------------------------------------------
-- request: {record, origin = {x, y, z}, direction = {x, y, z}, attacker, kind, scale}, already validated. The controller
-- takes the blow's place and the way it travels in x and y only. Returns accepted, outcome, damage: `accepted` is
-- the controller's own answer (a blow it handled - taken, caught, parried, phased, missed - or false with its reason),
-- `damage` the points of BT's health it estimates the blow takes, 0 when none. A raise is reported as "failed" with the
-- error text as a fourth value.
function M.hit(env, request)
  local origin, direction = request.origin, request.direction
  local ok, accepted, outcome, damage = pcall(env.FPF.bossHit, request.record, origin.x, origin.y, origin.z,
    direction.x, direction.y, request.attacker, request.kind, request.scale)
  if not ok then return false, "failed", 0.0, tostring(accepted) end
  return accepted == true, outcome, finite(damage) and damage or 0.0
end

-- ------------------------------------------------------------------ repair ------------------------------------------
-- Gives the hull up to `amount` points back and returns what it gave, or nil and why not. The refusals are those of
-- FPF.healthSet (no BT standing, a scene, the eject, the warm-up) plus the end that already came and a hull that is full.
-- The shield, the timers of the last hit and the mending are the controller's; a hull above nothing ends the doomed
-- state and the down time, as hpBegin ends them for a BT that is boarded again with health.
function M.repair(env, amount)
  if not finite(amount) or amount <= 0.0 then return nil, "invalid_amount" end
  local S, PS = env.S, env.PS
  if S.gone then return nil, "no_session" end
  local H = PS.hp
  if H == nil or PS.ent == nil then return nil, "no_titan" end
  if H.gone then return nil, "gone" end
  if PS.warm then return nil, "coming" end
  if PS.act then return nil, "busy" end
  if PS.eject then return nil, "ejecting" end
  local K = env.FPC.health
  local full = K.segment * K.segments
  local room = full - H.health
  if room <= 0.0 then return nil, "full" end
  local applied = room
  if amount < room then
    applied = amount
    H.health = H.health + amount
  else
    H.health = full
  end
  if H.health > 0.0 then H.doomed, H.down = nil, nil end
  return applied
end

-- ------------------------------------------------------------------ core credit ------------------------------------
-- request: {target = {id, epoch}, record, killing}. `target` is the other player's Titan (the server's id text and its life)
-- that the server confirmed a blow of this Titan's on, `record` the authored attack record (a TweakDB name) of that blow and
-- `killing` whether it ended the target. The server's decision is the only trigger: nothing here watches a hit, and no game
-- event, target or health is made up for the controller. What the author's BURST CORE gives for it is the author's own:
--   * a blow that does not kill goes to FPF.coreBossCredit, the share, budget, points and charge sums of the boss-hit credit
--     (FPF.coreBossHit hands the game's own hit events to the same function), with the target's canonical label for its log
--     line. A record without a share, a spent budget, a burning core and a BURST CORE that is off are its refusals, and
--     P.coreScale is applied inside it, once.
--   * a killing blow is the author's kill reward for a boss (FPC.perk.core.kill.boss, what FPF.coreWorth gives a target of
--     this size) through the final FPF.coreGain (a burning core, the flight strike's immunity and P.coreScale are its
--     gates), once for each target and life (FPF.coreOnce, the key FPF.coreKill uses for a target of its own, here the
--     canonical label). The flight strike's own records fill no core, as in FPF.coreKill (FPF.flightHitOf reads the record
--     from an event; the request carries it). Like FPF.coreKill, a kill that FPF.coreGain then refuses has used up the
--     target's one chance.
-- Returns the charge added to the core (after the scale and the core's own ceiling; 0 when the core was full) or nil and
-- why: "invalid_request", "no_session", "no_titan", "no_core" (no core, or BURST CORE is off), "core_active" (it burns),
-- for a blow "unknown_record" (no share for the record) and "capped" (the budget gives nothing now), for a kill "duplicate",
-- "flight_strike", "flight_immune" and "refused", and "failed" with the error text as a third value when the controller raised.
local function ident(v)
  return type(v) == "string" and #v >= 1 and #v <= 20 and v:find("^%d+$") ~= nil
end

local function positive_int(v)
  return finite(v) and v >= 1 and v == floor(v) and v < 2 ^ 53
end

local function added(C, before)
  return max(0.0, C.charge - before)
end

local function blow(env, record, label)
  local C = env.PS.core
  local before = C ~= nil and C.charge or nil
  local credited, why = env.FPF.coreBossCredit(record, label)
  if credited == nil then return nil, why end
  return added(C, before)
end

local function kill(env, record, label)
  local PS, FPF, FPC = env.PS, env.FPF, env.FPC
  local flight = FPC.perk.flightStrike.records
  if record == flight.hit or record == flight.blast then return nil, "flight_strike" end
  local C = PS.core
  if PS.ent == nil then return nil, "no_titan" end
  if C == nil or FPF.perk("burstcore") < 1 then return nil, "no_core" end
  if FPF.coreOnce(label) then return nil, "duplicate" end
  local before = C.charge
  if FPF.coreGain(FPC.perk.core.kill.boss, "a boss", label) ~= true then
    if FPF.flightImmune() then return nil, "flight_immune" end
    if FPF.coreOn() then return nil, "core_active" end
    return nil, "refused"
  end
  return added(C, before)
end

function M.creditCore(env, request)
  local target = type(request) == "table" and request.target or nil
  if type(target) ~= "table" or not ident(target.id) or not positive_int(target.epoch)
      or type(request.record) ~= "string" or request.record == "" or #request.record > 160
      or type(request.killing) ~= "boolean" then
    return nil, "invalid_request"
  end
  if env.S.gone then return nil, "no_session" end
  local label = string.format("open77:titan:%s:%d", target.id, target.epoch)
  local ok, applied, why = pcall(request.killing and kill or blow, env, request.record, label)
  if not ok then return nil, "failed", tostring(applied) end
  if applied == nil then return nil, type(why) == "string" and why or "refused" end
  return applied
end

-- ------------------------------------------------------------------ kill credit ------------------------------------
-- A server mission's `creditKill` (the `credit_kill` message): `rank` is "grunt", "rare" or "heavy", already validated. The charge
-- is the controller's own value for it (FPC.perk.core.kill: 5, 7 and 10 as authored) given by FPF.coreGain, the function its own
-- kill credit (FPF.coreKill) ends in: no gain without BURST CORE level 1, none while a burst burns or during the flight strike,
-- P.coreScale applied once, and never past the core's ceiling. The server names no victim, so nothing is counted once per target
-- (FPF.coreOnce): the server's call is the only trigger, one call one kill. Returns the charge added (0 when the core was full) or
-- nil and why: "invalid_request", "no_session", "no_titan" (no BT standing), "no_core" (no core, or BURST CORE is off) and "refused"
-- (a burst burning, or the flight strike).
function M.creditKill(env, rank)
  local PS, FPF, FPC = env.PS, env.FPF, env.FPC
  local points = (rank == "grunt" or rank == "rare" or rank == "heavy") and FPC.perk.core.kill[rank] or nil
  if not finite(points) then return nil, "invalid_request" end
  if env.S.gone then return nil, "no_session" end
  if PS.ent == nil then return nil, "no_titan" end
  local C = PS.core
  if C == nil or FPF.perk("burstcore") < 1 then return nil, "no_core" end
  local before = C.charge
  if FPF.coreGain(points, "a kill the server confirmed", rank) ~= true then return nil, "refused" end
  return added(C, before)
end

-- ------------------------------------------------------------------ core fill ---------------------------------------
-- The restricted `titan.core` test command: the core filled to its ceiling, to try BURST CORE and FLIGHT STRIKE without earning
-- the charge. The charge is set here, not given through FPF.coreGain, whose gates (a burning core, the flight strike's immunity,
-- P.coreScale) would refuse or scale a fill that is meant to be exact; a burst that already burns is left alone (C.left).
-- Returns the charge added (0 when the core was already full) or nil and why: "no_session", "no_titan", "no_core" (no core, or
-- BURST CORE is off).
function M.fillCore(env)
  local PS, FPF = env.PS, env.FPF
  if env.S.gone then return nil, "no_session" end
  if PS.ent == nil then return nil, "no_titan" end
  local C = PS.core
  if C == nil or FPF.perk("burstcore") < 1 then return nil, "no_core" end
  local before = C.charge
  C.charge = FPF.coreMax()
  return added(C, before)
end

return M
