-- Owner side: the Titan HUD's state, one small table of what the controller holds while V pilots BT. It has two readers. The page
-- (resources/gamemodes/op77_lightrp_titans/ui/hud.html, hud_panel.js) draws the PROTOCOLS lamps, the control hints, the notices and the carry's
-- prompt. LightRP's own HUD (op77_lightrp, client/core/hud.lua) asks the client export `hudState` (client.lua), which answers
-- `M.current()` below, and shows the hull and the shield on its health and armor gauges, the weapon on its weapon readout and the
-- ability cells and the core on its bar over the quick items: the page does not draw those.
--
-- What the state holds while V pilots BT (and nothing else; the crosshair, the aim range, the execution hint, the gun tracers and the
-- world labels stay on the canvas, where they belong to a point of the picture):
--   hull      the hull's segments, the shield, the DOOMED pool, the red flash of a hit
--   core      the BURST CORE bar: its charge, its state (charging / ready / active) and the key of its control
--   weapon    the selected weapon's name, magazine and reload (guns), its notes (charge, spin, block, arc wave ...)
--   abilities the cells of the controller's own slot model (FPF.slotStates: SENTRY / MISSILES / VORTEX / SMOKE, with the sentry
--             cell's weapon-dependent meaning) and the two gauges it drew as bars (DASH charges, JETS fuel), each with the key
--             the controller binds it to, its state (ready / empty / active), its fill, its count and the seconds it still
--             needs (the owner's gameplay report, open77_titan_gameplay.snapshot)
--   protocols the three PROTOCOLS lamps and the LINK words
--   controls  the controller's own key labels for the controls that are not an ability cell
--   notice    EJECTING / BT stops - V climbs out
--   mission   what a server mission made of this Titan: `className` (the class's label, nil without one), `allowed` (the nine
--             abilities - missiles, vortex, smoke, dash, jets, sentry, flight, designator, core - its class lets through: all true
--             without a class) and `held` (the Titan takes no controls but the camera look)
--   grab      ctx.grabUi (the carry's prompt: ready / held / charging), passed through
-- Nothing is decided here: every value is one the controller or the gameplay report already holds, and the key labels are the
-- controller's own (FPF.keyWord) under the same gates its canvas hints had (P.keyHints, S.keysOk).
--
-- `frame()` runs once per game frame after the controller's overlay (open77_titan_bridge.lua: frame). The state is built at most
-- every EVERY seconds. It is kept as `M.current()` (nil while V does not pilot) and handed to `render.state(tbl)`
-- (resources/gamemodes/op77_lightrp_titans/render.lua) only when it differs from the one handed over last; numbers are rounded so a value
-- that only drifts in the noise does not count as a change. While V does not pilot (or the controller shows no HUD: a paused game, a
-- cut scene, the cockpit wall) the page is cleared once with `render.state(nil)` and `M.current()` is nil. A section that cannot be read
-- is left out and reported once through ctx.diag; the others still show. A table handed to render.state, or answered by `current`, is
-- never changed afterwards.

local _ENV = require("controller.open77_titan_env")
local gameplay = require("controller.open77_titan_gameplay")

local M = {}

local EVERY = 0.2            -- seconds between two builds of the state (5 Hz; the page's meters ease between two states: hud.css transitions)
local FULL = 0.98            -- a fill at or above this is a full cell: no fill is drawn (the controller's FPC.slots.full)
local MAX_NOTES = 4
local MAX_CONTROLS = 12

local floor, ceil, max, min, huge = math.floor, math.ceil, math.max, math.min, math.huge

local function finite(v)
  return type(v) == "number" and v == v and v > -huge and v < huge
end

-- A share in [0, 1], rounded to 1/200 (a bar that is 0.5 % wider is not a new picture).
local function frac(v)
  if not finite(v) then return 0.0 end
  if v < 0.0 then v = 0.0 elseif v > 1.0 then v = 1.0 end
  return floor(v * 200.0 + 0.5) / 200.0
end

-- Seconds, rounded to tenths; zero for anything that is not a time still to run.
local function tenths(v)
  if not finite(v) or v <= 0.0 then return 0.0 end
  return floor(v * 10.0 + 0.5) / 10.0
end

local function whole(v)
  if not finite(v) then return 0 end
  return floor(v + 0.5)
end

-- ------------------------------------------------------------------ what is shown --------------------------------------
-- The conditions of the controller's own drawHud (fragments/draw.lua): V in the seat with BT's gun table, the overlay on, no
-- cockpit wall, no execution scene, a live session that is not paused.
local function piloted(env)
  local S, PS, P, PF = env.S, env.PS, env.P, env.PF
  if S.gone or S.paused or S.endMenu then return false end
  if not (S.driving and S.pilot and PS.mode == "pilot") then return false end
  if PS.gun == nil or PS.hp == nil or PS.exec then return false end
  if not P.hud or (PF ~= nil and PF.wallOn) then return false end
  return true
end

-- The controller's own label of a binding (FPF.keyWord: Mod Settings' key, or the pad's), shown only under the gates its canvas
-- hints had; nil for a key it cannot name.
local function keycap(env, field, always)
  if not always and not (env.P.keyHints and env.S.keysOk) then return nil end
  local word = env.FPF.keyWord(field)
  if type(word) ~= "string" or word == "" or word == "?" or word == "None" then return nil end
  return word
end

-- ------------------------------------------------------------------ the sections ---------------------------------------
local function hull(env, self)
  local PS, P, S, K = env.PS, env.P, env.S, env.FPC.health
  local H = PS.hp
  local out = {
    segments = K.segments, segment = K.segment, hull = whole(max(0.0, H.health)),
    low = H.health <= K.segment, name = "BT-7274",
  }
  if finite(H.shield) and H.shield > 0.0 and K.shield > 0 then out.shield = frac(H.shield / K.shield) end
  if H.doomed then
    out.doomed = frac(H.doomed / K.doomed)
    local ok, text = pcall(env.FPF.doomedText)
    if ok and type(text) == "string" then out.doomedText = text end
  end
  -- The red flash behind the bar when BT is hit (FPF.jarFlash's own moment): each new one is one more number for the page.
  local J, KJ = PS.jar, env.FPC.jar
  if J and P.jar and finite(J.flashAt) and J.flashAt ~= self.flashAt then
    self.flashAt = J.flashAt
    if S.clock - J.flashAt < KJ.flash + 0.5 then self.flashes = self.flashes + 1 end
  end
  if self.flashes > 0 then out.flash = self.flashes end
  return out
end

-- FPF.coreLine's own reading of the BURST CORE bar: its charge, the burst burning down, the shot's cost marked at level 3.
-- `flight`: FLIGHT STRIKE takes the core's key (FPF.sharedKeyDrop): the bar is the strike's, which spends the core, named for it,
-- active while BT flies and ready when the controller would start one (FPF.flightCan); the FLIGHT cell is left out.
local function core(env, flight)
  local PS, FPF = env.PS, env.FPF
  local C = PS.core
  local most = FPF.coreMax()
  if not C or not finite(most) or most <= 0.0 then return nil end
  local need = FPF.coreShot()
  local share, state = frac(C.charge / most), "charging"
  if C.left then
    state = "active"
    share = frac((C.charge + need * min(1.0, max(0.0, C.left / max(C.time or 1.0, 0.1)))) / most)
  elseif C.charge >= need - 1e-6 then
    state = "ready"
  end
  local out = { share = share, state = state, key = keycap(env, "coreKey") }
  if FPF.perk("burstcore") >= 3 then out.need = frac(need / most) end
  if flight then
    out.name, out.ability, out.key = "FLIGHT STRIKE", "flight", keycap(env, "flightKey")
    if PS.flight then
      out.state = "active"
    else
      local ok, can = pcall(FPF.flightCan)
      out.state = (ok and can == true) and "ready" or "charging"
    end
  end
  return out
end

-- FPF.gunNote / swordNote / fistNote: "   CHARGE 2   BLOCK 40 % ON": each run of three spaces ends one note.
local NOTE = { sword = "swordNote", fist = "fistNote" }

local function notes(env, id)
  local fn = env.FPF[NOTE[id] or "gunNote"]
  if type(fn) ~= "function" then return nil end
  local ok, text = pcall(fn)
  if not ok or type(text) ~= "string" then return nil end
  local list = {}
  for piece in (text .. "   "):gmatch("(.-)%s%s%s+") do
    piece = piece:gsub("^%s+", "")
    if piece ~= "" and #list < MAX_NOTES then list[#list + 1] = piece end
  end
  return #list > 0 and list or nil
end

local function weapon(env, report)
  local PS, FPC = env.PS, env.FPC
  local id = PS.weapon or "xo16"
  local W = FPC.guns[id]
  local out = { id = id, name = W and W.name or string.upper(id), melee = id == "sword" or id == "fist" }
  local ammo = report and report.ammo
  if ammo then out.ammo, out.capacity = whole(ammo.current), whole(ammo.capacity) end
  local G = PS.gun
  if G and G.reloadT then
    local total = G.reloadFull or env.XO16.reload
    out.reload = { left = tenths(G.reloadT), done = frac(finite(total) and total > 0.0 and 1.0 - G.reloadT / total or 0.0) }
  end
  out.notes = notes(env, id)
  return out
end

-- One ability cell. `left` is what the owner's gameplay report says the cell still needs: the seconds before it is ready again
-- (empty) or before it runs out (active).
local function cell(id, name, key, state, fill, count, report)
  local out = { id = id, name = name, key = key, state = state }
  if finite(fill) and fill < FULL then out.fill = frac(fill) end
  if count ~= nil then out.count = whole(count) end
  local A = report and report.abilities and report.abilities[id]
  if A then
    local left = (state == "active") and A.remaining or ((state == "empty") and A.cooldown or nil)
    if finite(left) and left > 0.05 then out.left = tenths(left) end
  end
  return out
end

-- What the sentry slot means depends on the weapon, as FPF.slotStates' own wrappers make it: SENTRY MODE with a gun, the sword's
-- spin or phase dash, the fists' shoulder charge. Only the gun's has a wait the gameplay report knows.
local function sentryName(env)
  local PS, P, FPF = env.PS, env.P, env.FPF
  if PS.weapon == "sword" then return (P.phaseDash and FPF.perk("sentry") >= 1) and "PHASE" or "SPIN", false end
  if PS.weapon == "fist" and P.fistShoulder and FPF.perk("sentry") > 0 then return "SHOULDER", false end
  return "SENTRY", PS.weapon ~= "fist"
end

local SLOT_NAMES = { missiles = "MISSILES", vortex = "VORTEX", smoke = "SMOKE" }

local function slots(env, report, out)
  local PS, FPC = env.PS, env.FPC
  local ok, model = pcall(env.FPF.slotStates, PS.mtms, PS.vortex, PS.esmoke)
  if not ok or type(model) ~= "table" then return end
  for _, id in ipairs(FPC.slots.order) do
    local W = model[id]
    local item = FPC.slots.items[id]
    if type(W) == "table" and item then
      local name, timed = SLOT_NAMES[id], true
      if id == "sentry" then name, timed = sentryName(env) end
      if id == "vortex" and env.FPF.arcOn() then name = "ARC FIELD" end
      local c = cell(id, name, keycap(env, item.key), W.state, W.fill, W.count, timed and report or nil)
      if id == "vortex" and W.color ~= "blue" then c.tone = W.color end
      out[#out + 1] = c
    end
  end
end

-- The dash's charges: PS.power in units of one dash (TF.dodgeDrain); the cell's count is the whole dashes there are.
local function dash(env, report)
  local PS, TF, FPF = env.PS, env.TF, env.FPF
  if TF == nil or not finite(PS.power) or not finite(TF.dodgeDrain) or TF.dodgeDrain <= 0.0 then return nil end
  local most = max(1, floor(FPF.dashMax() / TF.dodgeDrain + 1e-6))
  local have = PS.power / TF.dodgeDrain
  local count = min(most, floor(have + 1e-6))
  local A = report and report.abilities and report.abilities.dash
  local state
  if PS.dashT ~= nil then
    state = "active"
  elseif A and finite(A.cooldown) then
    state = (A.cooldown > 0.05) and "empty" or "ready"
  else
    state = (count >= 1) and "ready" or "empty"
  end
  return cell("dash", "DASH", keycap(env, "dashKey"), state, (count < most) and (have - count) or nil, (most > 1) and count or nil, report)
end

-- VTOL JETS: the fuel left (PS.jet, the perk's own gauge); empty is a dry tank.
local function jets(env, report)
  local PS, FPF = env.PS, env.FPF
  local T = PS.jet
  if not T or not finite(T.fuel) then return nil end
  local full = FPF.gaugeMax()
  if not finite(full) or full <= 0.0 then return nil end
  local state = T.on and "active" or ((T.fuel <= 0.0) and "empty" or "ready")
  return cell("jets", "JETS", keycap(env, "jumpKey"), state, T.fuel / full, nil, report)
end

-- FLIGHT STRIKE: a cell of its own once the perk is owned. Active while the strike runs (the gameplay report's remaining time),
-- ready when the controller would start one now (FPF.flightCan: the core full, the perk and BURST CORE level it needs, no burst
-- burning), empty otherwise.
local function flight(env, report)
  local FPF = env.FPF
  if FPF.perk("flight") < 1 then return nil end
  local A = report and report.abilities and report.abilities.flight
  local state = "empty"
  if A and A.active then
    state = "active"
  else
    local ok, can = pcall(FPF.flightCan)
    if ok and can == true then state = "ready" end
  end
  return cell("flight", "FLIGHT", keycap(env, "flightKey"), state, nil, nil, report)
end

-- TARGET DESIGNATOR: a cell once the perk is owned; active while a target is painted (FPF.designated), ready otherwise. A class's
-- BARRAGE (FPF.barrageOn) takes the cell: active from the call to the last rocket, empty with its wait while it cools down.
local function designator(env)
  local FPF = env.FPF
  if FPF.perk("designator") < 1 then return nil end
  if FPF.barrageOn() then
    local state, left, done = FPF.barrageState()
    local c = cell("designator", "BARRAGE", keycap(env, "designateKey"), state, done, nil, nil)
    if finite(left) and left > 0.05 then c.left = tenths(left) end
    return c
  end
  local ok, painted = pcall(FPF.designated)
  return cell("designator", "DESIGNATE", keycap(env, "designateKey"), (ok and painted ~= nil) and "active" or "ready", nil, nil, nil)
end

-- The broadsword's SPIN SLASH, on the game's reload key (R) once the sword's commands are on (P.swordCmds) and the perk that
-- owns it is there (FPF.cellOwned142: sentry): its charges, active while BT spins.
local function spin(env)
  local PS, P, FPF = env.PS, env.P, env.FPF
  if PS.weapon ~= "sword" or not P.swordCmds or FPF.perk("sentry") < 1 then return nil end
  local most = env.FPC.sword.spin.charges
  local c = PS.spinCharge or most
  local state = PS.spin and "active" or ((c >= 1.0) and "ready" or "empty")
  local key = (P.keyHints and env.S.keysOk) and "R" or nil
  return cell("spin", "SPIN", key, state, (c < most) and (c - floor(c)) or nil, (most > 1) and floor(c + 1e-6) or nil, nil)
end

local function abilities(env, report, flightOnCore)
  local out = {}
  slots(env, report, out)
  local d = dash(env, report)
  if d then out[#out + 1] = d end
  local j = jets(env, report)
  if j then out[#out + 1] = j end
  local f = not flightOnCore and flight(env, report)
  if f then out[#out + 1] = f end
  local t = designator(env)
  if t then out[#out + 1] = t end
  local w = spin(env)
  if w then out[#out + 1] = w end
  return #out > 0 and out or nil
end

-- PROTOCOLS: three lamps (owned or not), each lit for a while by what BT does; two or three lit make a LINK.
local function hex(c)
  local function byte(v) return floor(min(1.0, max(0.0, v)) * 255.0 + 0.5) end
  return string.format("#%02x%02x%02x", byte(c[1]), byte(c[2]), byte(c[3]))
end

local function protocols(env)
  local P, FPF, S, PS = env.P, env.FPF, env.S, env.PS
  local Q = env.FPC.proto159
  if not P.protocols159 or type(Q) ~= "table" or type(FPF.protoOn159) ~= "function" then return nil end
  local L = PS.proto159
  local lamps, any = {}, false
  for i, id in ipairs(Q.ids) do
    local have = FPF.perk(id) > 0
    any = any or have
    local lamp = { name = Q.names[i], have = have, color = hex(Q.colors[i]) }
    if have and FPF.protoOn159(i) then
      lamp.on = true
      local secs = FPF.perkValue(id)
      if L and finite(secs) and secs > 0.0 then lamp.left = frac((L.till[i] - S.clock) / secs) end
    end
    lamps[i] = lamp
  end
  if not any then return nil end
  return { lamps = lamps, link = FPF.protoCount159() }
end

-- The controls that are not an ability cell. The labels are the controller's own, so a key moved in Mod Settings moves here.
local CONTROLS = {
  { field = "jumpKey", label = "Jump / jets" },
  { field = "dashKey", label = "Dash" },
  { field = "punchKey", label = "Melee" },
  { field = "coreKey", label = "Burst core", needs = "core" },
  { field = "flightKey", label = "Flight strike", needs = "flight" },
  { field = "viewKey", label = "View" },
  { field = "shoulderKey", label = "Shoulder" },
}

local function controls(env, report)
  if not env.P.keyHints then return nil end
  local out = {}
  for _, entry in ipairs(CONTROLS) do
    local wanted = true
    if entry.needs == "core" then wanted = env.PS.core ~= nil and env.FPF.coreMax() > 0.0 end
    if entry.needs == "flight" then wanted = report ~= nil and report.abilities ~= nil and report.abilities.flight ~= nil end
    local key = wanted and keycap(env, entry.field) or nil
    if key and #out < MAX_CONTROLS then out[#out + 1] = { key = key, label = entry.label } end
  end
  -- Held on the embark key, which is the game's use key (F) without the mod's key script: FPF.keyWord says which.
  local leave = keycap(env, "embarkKey", true)
  if leave and #out < MAX_CONTROLS then out[#out + 1] = { key = leave, label = "Disembark (hold)" } end
  return #out > 0 and out or nil
end

local function notice(env)
  local PS = env.PS
  if PS.eject then return "eject" end
  if not PS.auto and PS.outAsked then return "leave" end
  return nil
end

-- A server mission's hold and class (FPF.mission, set by the bridge from the server's `hold` and `class` messages): the label, the
-- abilities that are allowed (a fresh table of the nine, every one true without a class) and the hold.
local ABILITY_IDS = { "missiles", "vortex", "smoke", "dash", "jets", "sentry", "flight", "designator", "core" }

local function mission(env)
  local FPF = env.FPF
  local out = { className = FPF.mission.className, held = FPF.held(), allowed = {} }
  for _, id in ipairs(ABILITY_IDS) do out.allowed[id] = FPF.allowed(id) end
  return out
end

-- ctx.grabUi (open77_titan_grab): { phase = "ready" | "held" | "charging", key, label, target = "person" | "vehicle",
-- charge = 0..1 (charging) }. Passed through; a malformed one is ignored. A hold has no time limit, so there is no countdown.
local PHASES = { ready = true, held = true, charging = true }

local function grab(ctx)
  local g = ctx.grabUi
  if type(g) ~= "table" or not PHASES[g.phase] then return nil end
  local out = {
    phase = g.phase,
    key = tostring(g.key or "E"),
    label = tostring(g.label or ""),
    target = (g.target == "vehicle") and "vehicle" or "person",
  }
  if g.phase == "charging" then out.charge = frac(g.charge) end
  return out
end

-- ------------------------------------------------------------------ change detection -----------------------------------
local function same(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do
    if not same(v, b[k]) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

-- ------------------------------------------------------------------ the module -----------------------------------------
-- The state built last while V pilots (nil once the page is cleared): what the client export `hudState` answers, whatever the page
-- could be given. One controller runs per game, so one is enough.
local latest = nil

function M.current()
  return latest
end

function M.new(ctx)
  local hud = {}
  -- `last` is the state handed to the page (nil: the page is clear), `due` the clock of the next build, `self` what the builders
  -- keep between two builds.
  local last, due = nil, 0.0
  local self = { flashAt = nil, flashes = 0 }

  local function section(name, fn, ...)
    local ok, result = pcall(fn, ...)
    if ok then return result end
    ctx.diag("hud." .. name, "the HUD's " .. name .. " could not be read: " .. tostring(result))
    return nil
  end

  local function build(env)
    local report = section("report", gameplay.snapshot, env)
    local made = section("mission", mission, env) or {}
    local flightOnCore = section("keys", function() return env.FPF.sharedKeyDrop() end) == "core"
    return {
      on = true,
      top = env.FPC.hpTop,
      hull = section("hull", hull, env, self),
      core = section("core", core, env, flightOnCore),
      weapon = section("weapon", weapon, env, report),
      abilities = section("abilities", abilities, env, report, flightOnCore),
      protocols = section("protocols", protocols, env),
      controls = section("controls", controls, env, report),
      notice = section("notice", notice, env),
      grab = grab(ctx),
      className = made.className,
      allowed = made.allowed,
      held = made.held,
    }
  end

  local function clear()
    latest = nil
    if last == nil then return end
    last = nil
    if render and type(render.state) == "function" then pcall(render.state, nil) end
  end

  function hud.frame()
    local env = ctx.env
    if not env or not render or type(render.state) ~= "function" then return end
    local ok, shown = pcall(piloted, env)
    if not ok then
      ctx.diag("hud.gate", "the HUD could not tell whether V pilots: " .. tostring(shown))
      shown = false
    end
    if not shown then
      clear()
      due = 0.0
      return
    end
    if ctx.clock < due then return end
    due = ctx.clock + EVERY
    local built, state = pcall(build, env)
    if not built then
      ctx.diag("hud.build", "the HUD's state could not be built: " .. tostring(state))
      return
    end
    latest = state
    if last ~= nil and same(last, state) then return end
    local sent, why = pcall(render.state, state)
    if not sent then
      ctx.diag("hud.send", "the HUD page could not be given its state: " .. tostring(why))
      return
    end
    last = state
  end

  -- The page cleared when it shows anything, whatever the gate says: the bridge calls it instead of `frame` while the controller's
  -- overlay is idle (no BT out), and it is nothing but a read of `last` once the page is clear.
  function hud.clear()
    due = 0.0
    clear()
  end

  return hud
end

return M
