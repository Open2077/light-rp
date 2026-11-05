-- Open77 <-> BT-7274 controller bridge (the Titan resource's client).
--
-- Loaded by the controller (controller/init.lua: the author's mod as Open77's port script generated it, kept by hand here) before
-- anything else and used by the
-- resource's client.lua, in the same Lua state. The controller stays the author's own controller: this module
--   * receives its file-local entry points once (`attach`) and wraps its per-frame update and its call function,
--   * records what the controller shows the world at the output seams (open77_titan_capture) and turns it into
--     20 Hz frames for the Open77 resource, handed to the resource's link (`link`),
--   * renders every other player's Titan from relayed frames (open77_titan_observer),
--   * executes the user's /titan commands by calling the controller's real functions (at the start of a frame, one heavy command a
--     frame: the controller's functions for them need more of the 4 ms than what is left behind its own update), and the server's
--     restricted `titan.core` test command (a core filled to its ceiling, open77_titan_gameplay.fillCore),
--   * answers the controller's reads of its Titan-level facts and its gun fact from the server's loadout and the
--     selected weapon, in memory: the controller's own perk poll, damage, health and ability code runs unchanged,
--   * runs the physical carry (grab, hold, throw of one canonical NPC or vehicle) under a server-granted claim
--     (open77_titan_carry),
--   * offers the physical carry to the player as one key (open77_titan_grab: a prompt for a body in reach, the key takes it,
--     the hand holds it, the key held charges the throw, letting go throws it; ctx.grabUi is what the HUD shows),
--   * reports the owner's gameplay (hull, shield, ammunition, core, abilities: open77_titan_gameplay.snapshot) in every
--     frame, and answers a server script's `hit`, `repair` and `core_credit` requests by calling the controller's own boss-hit,
--     hull repair and authored core credit (open77_titan_gameplay), once per request number, with a `gameplay_result`,
--   * reports what this controller's weapons land on, and the status effects its own calls apply to, another player's Titan
--     (open77_titan_combat makes the remote bodies targets of the controller's own aiming, ray and area code) as
--     `hit_observed` and `status_observed` observations under the grant's own id and epoch, numbered per grant (one count for
--     both), one message per blow or effect; nothing is applied to the remote body here and no damage or status is decided
--     (the server forwards the observation to its scripts and a mission prices it),
--   * reports what the controller's weapons take off a car (FPF.wreck, and the blast of a car it blows up: `OP77.vehicleHit`) as
--     `vehicle_hit` messages under the same id, epoch and count, summed per car; no car is damaged here either, the server applies
--     the report to the car's canonical health unless a script vetoes it,
--   * reports what its weapons land on another player's body (`OP77.playerHit`) as `player_hit` messages, summed per victim and
--     attack record over 0.1 s under the same id, epoch and count; the server prices the record and applies it under Open77's PvP rules,
--   * reports what its weapons land on an Open77 NPC (`OP77.npcHit`: the body is told by its engine entity from Open77.npcs.all) as
--     `npc_hit` messages, one per blow and a round on one NPC at most every 0.05 s, under the same id, epoch and count; the server
--     publishes them and the mission that owns the NPC validates and prices each one (no NPC is hurt here and no amount is sent),
--   * reports what its missiles' blasts take off the platform's own cars (`OP77.vehicleBlast`) as `vehicle_hit` too, wherever they are,
--   * drives the controller's frame (`frame`): the server's one-off commands first, then the game's menu transitions (`menu`), the
--     batch of game events the redscript forwarder queued, the controller's update, this module's tick and the overlay drawn
--     through the render module,
--   * offers the two actions the interpreter's overlay window had for the player (`resetCooldown`, `bring`),
--   * supplies the few services the controller used to get from the interpreter it was written for: a clock, a log,
--     and entity spawning (Codeware's DynamicEntitySystem).
--   * carries out a server mission's controls on this machine (the resource's spawn options, setHold, setClass and creditKill): the
--     piloted spawn (BT on the ground at V's own place and heading, V seated at once, no call-down), a hold on every control, a class
--     (its loadout, its ability lock, its walk and run speed and its weapon, in one step) and the core charge of a kill.
-- There is no authored progression: outside a grant every level is at its maximum and the XO-16 is selected. Outside an
-- Open77 Titan session every other hook is inert and the controller behaves as the original mod.

local _ENV = require("controller.open77_titan_env")
local schema = require("controller.open77_titan_schema")
local captureMod = require("controller.open77_titan_capture")
local observerMod = require("controller.open77_titan_observer")
local carryMod = require("controller.open77_titan_carry")
local gameplayMod = require("controller.open77_titan_gameplay")
local combatMod = require("controller.open77_titan_combat")
local grabMod = require("controller.open77_titan_grab")
local json = require("controller.open77_titan_json")
local loadout = schema.loadout

local M = {}

local PREFIX = "[titans] "
local LOG_LIMIT = 400
local HEARTBEAT_EVERY = 1.0
local BRIDGE_DEAD = 3.0         -- no message accepted by the resource for this long: the resource is not taking frames
local KEEPALIVE_LOST = 7.0      -- no op='session' active=true for this long: the resource is gone
local REQUEST_WAIT = 8.0
local GRANT_UNUSED = 25.0
local GONE_AFTER = 1.5
local MAX_MESSAGES = 64         -- relayed messages handled per game frame (64 Titans at 20 Hz is ~21 a frame at 60 fps)
local STATUS_EVERY = 30.0

-- values of the controller's gun fact (FPC.perk.gunFact), which the wrapped FPF.factGet answers from ctx.weaponFact
local WEAPON_FACT = { xo16 = 0, rail = 1, pred = 2, sword = 3, fist = 4 }
-- /titan action values -> the controller's own key names (FPF.bind); held keys are released after HOLD seconds
local ACTION_KEY = { jump = "jump", dash = "dash", punch = "punch", missiles = "missiles", vortex = "vortex", smoke = "smoke", core = "core", view = "view", shoulder = "shoulder" }
local HOLD = { punch = 0.15, missiles = 0.35, vortex = 1.0 }

local REQUIRED_ENV = {
  "S", "PS", "PF", "P", "FPF", "FPC", "XO16", "VERSION", "PILOT_ENT", "AHEAD", "BACK", "SPRINT", "EMBARK_RANGE", "TAG",
  "log", "guard", "restrict", "deletePilot", "spawnPilot", "startPilot", "startEmbark", "startDismount", "stopDrive",
}
local REQUIRED_FPF = {
  "update", "callBt", "gunPick", "gunMeshes", "factGet", "bind", "ejectStart", "sideTo", "viewVolume", "animAlways", "callNote",
  "hideV", "god", "disarm", "skillsOff", "show", "spawn", "forwarded", "drawFrame", "inkMenu", "inkMenuNone", "bringBt",
  "input", "releaseInput", "ragdoll", "landingGround", "mission", "held", "holdSet", "classSet", "allowed",
  "later", "laterPending", "laterFlush",
}

local ctx = {
  env = nil, clock = 0.0, titan = nil, request = nil, catalog = schema.catalog,
  session = { active = false, player = nil, lastAt = 0.0 },
  diags = {}, diagKeys = 0, diagFull = false, logged = 0, link = nil, verbose = false,
  lastPublishOk = 0.0, heartbeatAt = 0.0, heartbeatN = 0, allowSpawn = false, queued = nil, releases = {},
  savedKeep = nil, statusAt = 0.0, scripted = {}, results = {}, vehicleQueue = {}, vehicleAt = 0.0, playerQueue = {},
  npcQueue = {}, npcRoundAt = {}, npcRoundN = 0,
  held = nil, slice = math.huge, started = false, carRows = nil, carRowsAt = nil,
  levels = nil, revision = 0, weaponFact = 0, perkFacts = nil, gunFact = nil, pvp = false, drawn = true, backlog = false,
  handled = 0, idle = false, idleWait = 0.0,
  events = { sys = nil, retryAt = 0.0, checkAt = 0.0, lost = 0, decoy = 0, titan = 0 },
  menus = { scenario = "", queue = {} },
}

-- ------------------------------------------------------------------ time-limit cuts ---------------------------------
-- The host's instruction hook names the limit that fired in the error it raises ("(time limit)"; the instruction cap, a runaway
-- loop, says "(instruction limit)" and is a real failure: it is not matched).
local function is_time_cut(text)
  return type(text) == "string" and string.find(text, "(time limit)", 1, true) ~= nil
end

-- ------------------------------------------------------------------ logging --------------------------------------
-- The bridge's own lines: a few per session, capped for the life of the resource.
function ctx.log(msg)
  if ctx.logged >= LOG_LIMIT then return end
  ctx.logged = ctx.logged + 1
  Open77.log.info(PREFIX .. msg)
end

-- One log line per distinct problem, however often it recurs (and at most 64 distinct ones are remembered; the first one past
-- that says so, once).
function ctx.diag(key, text)
  local n = ctx.diags[key]
  if n == nil then
    if ctx.diagKeys >= 64 then
      if not ctx.diagFull then
        ctx.diagFull = true
        Open77.log.warn(PREFIX .. "diagnostic keys exhausted: later distinct problems are not logged")
      end
      return
    end
    ctx.diagKeys = ctx.diagKeys + 1
    ctx.diags[key] = 1
    Open77.log.warn(PREFIX .. text)
  else
    ctx.diags[key] = n + 1
  end
end

function ctx.capturing()
  return ctx.session.active and ctx.titan ~= nil
end

local capture = captureMod.new(ctx)
local observer = observerMod.new(ctx)
local carry = carryMod.new(ctx)
local combat = combatMod.new(ctx, observer)
local grab = grabMod.new(ctx, carry)
local hud = require("controller.open77_titan_hud").new(ctx)

-- ------------------------------------------------------------------ bodies Open77 drives ---------------------------
-- Another player's body on this machine is an Open77 proxy, and an Open77 NPC is a server-owned body under Open77's own
-- life and ragdoll policy; the controller's searches list both like anyone else. Open77 refuses a proxy its ragdoll and
-- grants an NPC one only under its own policy (its creator's vehicle-contact opt-in, or a carry claim:
-- NpcLedgerLife::KeepsContactRagdoll). The controller's knock-downs (a forced ragdoll and an impulse 0.12 s later) are left
-- out on every such body, but for two the controller asks for by name: the body this Titan holds or has thrown under a carry
-- claim, and the NPC a mission class's BERSERKER CORE launches (FPF.ragdollAsked, set around that one call). The crash the
-- guard was first made for (Cyberpunk2077.exe+0x9E3AA9) was the impulse's DelaySystem.DelayEvent, now the controller's own
-- queue (FPF.later). A player's body also gets none of the controller's status effects:
-- nothing applied here would reach that player. An NPC keeps them (they are its PvE reactions), and blows on either still
-- go through the controller's own hit path.
-- A body is told by its engine entity id, which Open77.players.nearby (another player with a body: `playerId`) and
-- Open77.npcs.all (an Open77 NPC in this client's interest set: `id`) report as `engineEntity` (0 while unknown). Both are
-- reads of the platform's own tables, not a world query; the set is made at most every OWNED_BODIES_EVERY seconds, out to
-- OWNED_BODIES_RADIUS around the player for the players: the server's playerReach (shared.lua), so a railgun hit at its 400 m
-- range is still told to be a player's body.
local OWNED_BODIES_EVERY = 0.25
local OWNED_BODIES_RADIUS = 450.0
local bodies = { at = -100.0, set = {}, players = 0 }    -- `players`: how many of the set are another player's body

-- engine entity id -> { kind = "player", player = <id> } or { kind = "npc", npc = <id> }
local function owned_bodies()
  if ctx.clock - bodies.at < OWNED_BODIES_EVERY then return bodies.set end
  bodies.at = ctx.clock
  local set, players_here = {}, 0
  local ok, players = pcall(Open77.players.nearby, OWNED_BODIES_RADIUS)
  if not ok then
    ctx.diag("owned-bodies.players", "the players Open77 drives could not be listed: " .. tostring(players))
  elseif type(players) == "table" then   -- nil and a reason: this machine has no body to measure from yet
    for _, row in ipairs(players) do
      local e = row.engineEntity
      if not row.isLocal and math.type(e) == "integer" and e ~= 0 then
        set[e] = { kind = "player", player = row.playerId }
        players_here = players_here + 1
      end
    end
  end
  local okn, npcs = pcall(Open77.npcs.all)
  if not okn then
    ctx.diag("owned-bodies.npcs", "the NPCs Open77 drives could not be listed: " .. tostring(npcs))
  elseif type(npcs) == "table" then
    for _, row in ipairs(npcs) do
      local e = row.engineEntity
      if math.type(e) == "integer" and e ~= 0 and set[e] == nil then set[e] = { kind = "npc", npc = row.id } end
    end
  end
  bodies.set, bodies.players = set, players_here
  return set
end

-- One entity's id, as a protected call needs it: a function of its own, so asking costs no closure (the controller's targeting loops
-- ask once per candidate, every frame they run).
local function entity_id_of(ent) return ent:GetEntityID() end

local function owned_row(ent)
  if ent == nil then return nil end
  local ok, id = pcall(entity_id_of, ent)
  if not ok or math.type(id) ~= "integer" or id == 0 then return nil end
  return owned_bodies()[id]
end

-- "player", "npc" or nil
local function owned_body(ent)
  local row = owned_row(ent)
  return row and row.kind or nil
end

-- The player id of another player's body, or nil
local function owned_player_id(ent)
  local row = owned_row(ent)
  if row and row.kind == "player" and math.type(row.player) == "integer" and row.player >= 1 then return row.player end
  return nil
end

local function player_body(ent)
  return owned_body(ent) == "player"
end
M.playerBody = player_body
ctx.playerBody = player_body        -- the grab key never offers another player's body (open77_titan_grab)

local spared = {}
local function spare(what, kind)
  local key = what .. kind
  if spared[key] then return end
  spared[key] = true
  ctx.log(what .. " on " .. (kind == "player" and "another player's body" or "an Open77 NPC") .. " is left out (Open77 drives that body)")
end

-- Whether two entities are one, as a protected call needs it: a function of its own, so asking costs no closure.
local function same_entity(a, b)
  local id = a:GetEntityID()
  return id ~= nil and id == b:GetEntityID()
end

-- The body this Titan holds or has thrown under a server claim: Open77 grants it its ragdoll for the claim, and the
-- controller's own throw needs it (FPF.ragdoll on the carried body, open77_titan_carry).
local function carried(ent)
  local c = carry.c
  local held = c and (c.Cr and c.Cr.ent or c.ent)
  if held == nil then return false end
  local ok, same = pcall(same_entity, ent, held)
  return ok and same == true
end

-- The NPC the controller names for its ragdoll (FPF.ragdollAsked: BERSERKER CORE's launch); never another player's body.
local function asked_npc(ent, kind)
  local env = ctx.env
  local named = env and env.FPF.ragdollAsked
  if kind ~= "npc" or named == nil then return false end
  local ok, same = pcall(same_entity, ent, named)
  return ok and same == true
end

-- The controller reads StatusEffectHelper as a global of this environment: it is replaced by a plain table holding the
-- entries the controller and its modules use, each forwarded to the game's own; the two ApplyStatusEffect overloads skip a
-- player's body. Open77's scripts/titans/test_titan_bridge.py checked that the controller it generated uses no other entry; a hand edit keeps to the list.
M.STATUS_ENTRIES = {
  "GetAppliedEffects",
  "StatusEffectHelper::RemoveStatusEffect;GameObjectTweakDBIDUint32",
  "StatusEffectHelper::RemoveAllStatusEffectsByType;GameObjectgamedataStatusEffectType",
}
M.STATUS_APPLY = {
  "StatusEffectHelper::ApplyStatusEffect;GameObjectTweakDBIDFloat",
  "StatusEffectHelper::ApplyStatusEffect;GameObjectTweakDBIDEntityID",
}
if StatusEffectHelper ~= nil then
  local game = StatusEffectHelper
  local guarded = {}
  for _, key in ipairs(M.STATUS_ENTRIES) do
    guarded[key] = function(...) return game[key](...) end
  end
  for _, key in ipairs(M.STATUS_APPLY) do
    guarded[key] = function(ent, ...)
      if player_body(ent) then
        spare("a status effect", "player")
        return nil
      end
      return game[key](ent, ...)
    end
  end
  StatusEffectHelper = guarded
end

-- ------------------------------------------------------------------ the resource's link ----------------------------
-- The resource (client.lua) gives the bridge two functions with `M.link`: `send(message)` takes one controller
-- message (a table) and answers true when it took it, and `poll()` answers the next relayed server message (a table)
-- or nil. The messages never leave this Lua state as text.
function M.link(link)
  ctx.link = link
end

-- Returns true when the resource took the message.
function ctx.publish(message)
  local link = ctx.link
  if link == nil then return false end
  if link.send(message) == true then
    ctx.lastPublishOk = ctx.clock
    return true
  end
  return false
end

local function send(tbl)
  return ctx.publish(tbl)
end
ctx.send = send

local function poll()
  local link = ctx.link
  if link == nil then return nil end
  return link.poll()
end

-- ------------------------------------------------------------------ helpers over the controller ------------------
local function E() return ctx.env end

local function note(text)
  local env = E()
  if env then pcall(env.FPF.callNote, { key = "open77_titan_note", note = text }) end
end

-- Runs a controller function the way the controller runs its own: errors are contained, and reported once.
local function guarded(label, fn, ...)
  local ok = E().guard("Open77 " .. label, fn, ...)
  if not ok then ctx.diag("guard." .. label, "the controller function for '" .. label .. "' raised an error (see its log)") end
  return ok
end

local function titan_present()
  local env = E()
  return env.PS.ent ~= nil or env.PS.asked ~= nil
end

local function distance_to_titan()
  local env = E()
  local d
  pcall(function()
    local v = Game.GetPlayer():GetWorldPosition()
    d = math.sqrt((v.x - env.PS.x) ^ 2 + (v.y - env.PS.y) ^ 2)
  end)
  return d
end

-- ------------------------------------------------------------------ the server's loadout -------------------------
-- The controller keeps its Titan levels and its gun selection in the facts of a save. Here they are the server's
-- loadout (a complete, validated map) and the selected weapon, in memory: the wrapped FPF.factGet (attach) answers the
-- controller's own reads of those facts, so its perk poll and everything behind it run as they always did.

-- Makes `levels` the policy; when it differs the controller's own perk poll runs at its next frame, not after its interval.
local function set_policy(levels, revision)
  local changed = false
  for id, level in pairs(levels) do
    if ctx.levels[id] ~= level then changed = true break end
  end
  ctx.levels, ctx.revision = levels, revision
  if changed then E().S.perkAt = 0.0 end
end

-- No grant, no Titan: every level at its maximum and the XO-16 selected.
local function reset_policy()
  set_policy(loadout.defaults(), 0)
  ctx.weaponFact = 0
  -- A mission's hold and class belong to the Titan they were made for.
  local env = ctx.env
  if env then
    env.FPF.holdSet(false)
    env.FPF.classSet(nil)
  end
end

-- ------------------------------------------------------------------ the server's scripted controls ----------------
-- A server script's held and analog controls (the resource's `input` export) reach the controller as `input` messages
-- that name this Titan's id and epoch, and `input_release` lets go of all of them. `ctx.scripted` is what the script holds
-- now, as the controller was last told ([name] = true for a pressed button or key, the level of an axis): only a change
-- is forwarded, because a repeated press would toggle or fire again, and everything is forgotten whenever the controller
-- lets go (the explicit release, the end of the piloting, the Titan, the session).
local function piloting(env)
  return env.S.driving and env.S.pilot and env.PS.mode == "pilot"
end

local function drop_input(release)
  local held = ctx.scripted
  ctx.scripted = {}
  if release and ctx.env and next(held) ~= nil then guarded("release scripted input", ctx.env.FPF.releaseInput) end
end

-- A blow the combat module still holds in this frame belongs to the Titan that landed it: it ends with it, with the session and
-- with a new grant.
local function drop_hits()
  combat.clear()
  ctx.vehicleQueue, ctx.vehicleAt = {}, 0.0
  ctx.playerQueue = {}
  ctx.npcQueue, ctx.npcRoundAt, ctx.npcRoundN = {}, {}, 0
  ctx.carRows = nil
end

local function forget_titan()
  ctx.titan = nil
  ctx.results = {}
  drop_input(true)
  drop_hits()
  reset_policy()
end

-- ------------------------------------------------------------------ owner: what the user's commands call ----------
local function request(action)
  local ok = send({ v = schema.VERSION, op = "request", action = action })
  if not ok then ctx.diag("request.full", "the Titan request could not be queued (the bridge is full or gone)") end
  return ok
end

-- Puts V and the controller back to what they were: the original controller's own undo of a drive plus its
-- interrupted-session cleanup (movement restrictions, invulnerability, workspot, V's body, camera, helper entities).
local function restore_owner(why)
  local env = E()
  local S, FPF = env.S, env.FPF
  if S.driving then guarded("stop drive", env.stopDrive, why) end
  guarded("V's restrictions", env.restrict, false)
  guarded("V's invulnerability", FPF.god, false)
  S.godUntil = nil
  guarded("V's body", FPF.hideV, false, true)
  guarded("V's weapon", FPF.disarm, false)
  guarded("BT's skills", FPF.skillsOff)
  pcall(function() Game.GetPlayer():GetFPPCameraComponent():Activate() end)
  S.cleanup, S.cleanupAt = true, nil
end

-- Ends everything the grant stood for locally: drive, Titan, first-person objects.
local function clean_owner(why)
  local env = E()
  carry.abort_all("titan_gone")
  drop_input(true)
  drop_hits()
  restore_owner(why)
  if titan_present() then guarded("delete BT", env.deletePilot) end
  capture.reset()
end

-- Keep the latest weapon and pilot commands independently while objects warm up; choose the weapon before embarking.
local QUEUE_ORDER = { "weapon", "pilot" }

local function queue_command(action, value, by_class)
  ctx.queued = ctx.queued or {}
  ctx.queued[action] = { till = ctx.clock + 20.0, value = value, by_class = by_class }
end

local function drop_queued(action)
  local Q = ctx.queued
  if not Q then return end
  Q[action] = nil
  if next(Q) == nil then ctx.queued = nil end
end

-- The piloted spawn (the grant's `piloted` option): BT on the ground at V's own place and heading, with no call-down, so none of
-- FPF.callBt's refusals (the sky over the landing, the cooldown, the lock of the call) applies. The placement itself needs V in the
-- world, no drive under way and ground under V. True once the controller took the spawn, false for a refused placement.
local function place_piloted(env)
  if env.S.driving then return false end
  local player = Game.GetPlayer()
  if not player then return false end
  local pos = player:GetWorldPosition()
  local ground = env.FPF.landingGround(pos.x, pos.y, pos.z)
  if ground == nil then return false end
  env.spawnPilot({ x = pos.x, y = pos.y, z = ground, yaw = player:GetWorldYaw() })
  return env.PS.id ~= nil
end

local function spawn_local(by)
  local env = E()
  if titan_present() then return true end
  local piloted = ctx.titan ~= nil and ctx.titan.piloted == true
  local ok, res
  if piloted then
    ok, res = pcall(place_piloted, env)
  else
    ctx.allowSpawn = true
    ok, res = pcall(env.FPF.callBt, by)
    ctx.allowSpawn = false
  end
  if not ok then
    ctx.diag("spawn.error", "the controller's " .. (piloted and "placement" or "call function") .. " failed: " .. tostring(res))
    res = false
  end
  if not res then
    -- the original controller refused (BT is leaving, nothing to land on, a roof) or V has no ground to stand BT on: give the grant back
    note("BT cannot be called here")
    ctx.log("the controller refused to spawn the granted Titan: releasing the grant")
    request("remove")
    forget_titan()
    return false
  end
  ctx.titan.spawnedAt = ctx.clock
  if piloted then
    -- V is seated as soon as BT has arrived and warmed up (the queued pilot command, instant: never the boarding scene)
    queue_command("pilot", "instant")
    ctx.log("the granted Titan stands at V's place (" .. tostring(by) .. "); V is seated as soon as it is ready")
  else
    ctx.log("the granted Titan is being called down (" .. tostring(by) .. ")")
  end
  return true
end

-- True once V pilots (or is climbing in); the second answer says the call worked on the controller (the frame's slice of one-off
-- commands is spent on that, see pump_messages). A start the host's time limit cut half-way leaves the controller driving with V
-- never aboard: startPilot and startEmbark set S.driving first and PS.mode ("pilot" / "mount") only after FPF.aboard, and every
-- live pilot session is in one of the modes pilot, mount, dismount and eject (a dismount ends in "wait" and stopDrive within the
-- same frame), so a driving pilot in mode wait or none is that cut start: the drive is undone (the next try, a frame later, starts
-- afresh) instead of the command being taken for done.
-- With `instant` V is seated at once, whatever the distance to BT (the piloted spawn): the boarding scene is never started.
local function pilot_local(instant)
  local env = E()
  local S, PS = env.S, env.PS
  if S.driving then
    if S.pilot and (PS.mode == "wait" or PS.mode == "none") then
      ctx.diag("pilot.stale", "the controller was driving without a pilot aboard (a start that was cut short): it is undone and started again")
      guarded("stop drive", env.stopDrive, "an interrupted start")
      return false, true
    end
    return true
  end
  if not (PS.ent and not PS.warm and not PS.act) then return false end
  local d = distance_to_titan()
  if not instant and d and d <= env.EMBARK_RANGE and PS.mode == "wait" then
    guarded("embark", env.startEmbark, nil, false)
  else
    guarded("start piloting", env.startPilot, false)
  end
  return S.driving == true, true
end

local function exit_local()
  local env = E()
  local S, PS = env.S, env.PS
  if not S.driving then return end
  if env.FPF.held() then
    ctx.diag("exit.held", "a climb out was refused: the Titan is held")
    return
  end
  if S.pilot and PS.mode == "pilot" then
    guarded("climb out", env.startDismount)
  else
    guarded("stop drive", env.stopDrive, "Open77 exit")
  end
end

-- FPF.spawn can dispose live handles, not requests still streaming in. Wait for those requests before replacing the view.
local function first_person_settling()
  local env = E()
  local PF, PS = env.PF, env.PS
  return PF.asked ~= nil or PF.wallAsked ~= nil or PS.wsAsked ~= nil or PF.warm ~= nil or PF.wallWarm ~= nil
end

-- A weapon whose perk is 0 cannot be selected (the server refuses its command, and the grab key, which takes the fists out through
-- here, asks `canWield` first), and a held Titan takes no switch at all. The class's own weapon is how a held Titan is given the
-- one it keeps: `by_class` skips both rules.
local function can_wield(weapon)
  local perk = loadout.weaponPerk(weapon)
  return perk == nil or (ctx.levels[perk] or 0) > 0
end
ctx.canWield = can_wield

-- gunPick changes configuration only; a live loadout also needs new view objects and updated outside meshes.
-- FPF.spawn normally belongs to a new Titan, so preserve health when using it for a weapon change.
-- The selection is the bridge's own: the controller's gun pick reads it through the wrapped FPF.factGet.
local function weapon_local(name, by_class)
  local env = E()
  local K = WEAPON_FACT[name]
  if K == nil then return true end
  if not by_class then
    if env.FPF.held() then
      ctx.diag("weapon.held", "a weapon switch was refused: the Titan is held")
      return true
    end
    if not can_wield(name) then
      ctx.diag("weapon." .. name .. ".perk", "a switch to '" .. name .. "' was refused: its perk is 0 in this Titan's loadout")
      return true
    end
  end
  local FPF, PS, PF = env.FPF, env.PS, env.PF
  if PS.weapon == name then
    ctx.weaponFact = K
    return true
  end
  if first_person_settling() then return false end
  local was = PS.weapon
  ctx.weaponFact = K
  guarded("gun pick", FPF.gunPick, "the Open77 command")
  if PS.weapon ~= name then
    ctx.diag("weapon." .. name, "the controller selected '" .. tostring(PS.weapon) .. "' for the weapon command '" .. name .. "' (its perks are off)")
  end
  if PS.weapon == was then return true, true end
  if PF.ent ~= nil then
    local hp = PS.hp
    if PF.shown then guarded("first person off", FPF.show, false) end
    guarded("first-person model", FPF.spawn)
    PS.hp = hp
  end
  guarded("gun meshes", FPF.gunMeshes)
  return true, true
end

-- The grab key brings the fists out, and the weapon back after the throw, through this very command (open77_titan_grab).
ctx.selectWeapon = weapon_local
ctx.firstPersonSettling = first_person_settling

local function press(key)
  local env = E()
  guarded("key " .. key, env.FPF.bind, key, true)
  ctx.releases[#ctx.releases + 1] = { key = key, at = ctx.clock + (HOLD[key] or 0.05) }
end

local function action_local(name)
  local env = E()
  if env.FPF.held() then
    ctx.diag("action.held", "an action was refused: the Titan is held")
    return
  end
  if name == "eject" then
    guarded("eject", env.FPF.ejectStart, "the Open77 command")
    return
  end
  if name == "grab" then
    local ok, why = carry.request_grab()
    if not ok then
      ctx.diag("action.grab." .. tostring(why), "grab refused: " .. tostring(why))
      note("Titan: " .. tostring(why))
    end
    return
  end
  local key = ACTION_KEY[name]
  if key then press(key) end
end

-- Returns when the queued commands could not run yet, ran or timed out. Each runs only while the frame's slice lasts (ctx.slice, one
-- call that worked on the controller: pilot_local, weapon_local) so a retried pilot or weapon command, like a fresh one, has the
-- frame to itself; the rest wait for the next frame's start.
local function run_queued()
  local Q = ctx.queued
  if not Q then return end
  if not ctx.titan then
    ctx.queued = nil
    return
  end
  for _, action in ipairs(QUEUE_ORDER) do
    local q = Q[action]
    if q then
      if ctx.clock > q.till then
        Q[action] = nil
        ctx.diag("queue." .. action, "the queued " .. action .. " command timed out: BT never became ready for it")
      elseif ctx.slice > 0 then
        local done, worked
        if action == "pilot" then done, worked = pilot_local(q.value == "instant") else done, worked = weapon_local(q.value, q.by_class) end
        if worked then ctx.slice = ctx.slice - 1 end
        if done then Q[action] = nil end
      end
    end
  end
  if next(Q) == nil then ctx.queued = nil end
end

-- `/titan log on|off`: the controller's own log lines, as the client-only `titanlog` command switches them. It needs no Titan.
local function handle_log_command(msg)
  M.setVerbose(msg.value == "on")
  print("[titans] controller log " .. msg.value)
end

-- `titan.core <player>` (the server's restricted test command): the BURST CORE filled to its ceiling by the gameplay module,
-- which writes the charge directly. A field write: cheap, so it is no heavy command. One visible line says what happened.
local function fill_core()
  local env = E()
  local called, added, why = pcall(gameplayMod.fillCore, env)
  if not called then
    ctx.diag("command.core.error", "the controller's core fill failed: " .. tostring(added))
    return
  end
  if schema.finite(added) and added >= 0 then
    local C = env.PS.core
    print(string.format("[titans] BURST CORE filled: +%.0f (%.0f of %.0f)", added, C and C.charge or 0.0, env.FPF.coreMax()))
  else
    print("[titans] BURST CORE not filled: " .. tostring(why))
  end
end

local function handle_command(msg)
  if msg.action == "log" then return handle_log_command(msg) end
  if not ctx.titan and msg.action ~= "spawn" then
    ctx.diag("command.none", "a Titan command arrived but this player has no Titan")
    return
  end
  local a = msg.action
  ctx.log("command " .. a .. (msg.value and (" " .. msg.value) or ""))
  if a == "spawn" then
    if not ctx.titan then
      ctx.request = { action = "spawn", at = ctx.clock, by = "the spawn command" }
      request("spawn")
    else
      spawn_local("the Open77 command")
    end
  elseif a == "remove" then
    clean_owner("Open77 remove")
    request("remove")
    forget_titan()
  elseif a == "pilot" then
    if not pilot_local() then queue_command("pilot") end
  elseif a == "exit" then
    exit_local()
  elseif a == "weapon" then
    if weapon_local(msg.value) then drop_queued("weapon") else queue_command("weapon", msg.value) end
  elseif a == "action" then
    action_local(msg.value)
  elseif a == "core" then
    fill_core()
  end
end

-- ------------------------------------------------------------------ session -------------------------------------
-- The server's Titan PvP flag as the last session message said it (see "the Titan PvP flag").
local function set_pvp(on)
  if ctx.pvp == on then return end
  ctx.pvp = on
  ctx.log("Titan PvP is " .. (on and "on" or "off") .. " (the server's word)")
end

local function start_session(player)
  local s = ctx.session
  s.active, s.player, s.lastAt = true, player, ctx.clock
  ctx.lastPublishOk, ctx.heartbeatAt, ctx.heartbeatN = ctx.clock, 0.0, 0
  ctx.statusAt = ctx.clock + STATUS_EVERY
  -- the controller's own "BT in the save" persistence would respawn a Titan behind the server's back
  local P = E().P
  ctx.savedKeep = P.keep
  P.keep = false
  capture.reset()
  carry.reset()
  grab.reset()
  drop_hits()
  ctx.log("session started (player " .. tostring(player) .. ", controller " .. tostring(E().VERSION) .. ")")
end

local function end_session(reason)
  local s = ctx.session
  if not s.active then return end
  s.active = false
  ctx.pvp = false
  drop_input(true)
  carry.abort_all("session_end")
  carry.drop_outbox()
  grab.reset()
  if ctx.titan then
    clean_owner(reason)
  end
  ctx.titan, ctx.request, ctx.queued, ctx.releases, ctx.results, ctx.held = nil, nil, nil, {}, {}, nil
  drop_hits()
  reset_policy()
  observer.clear(reason)
  if ctx.savedKeep ~= nil then E().P.keep = ctx.savedKeep end
  ctx.savedKeep = nil
  ctx.log("session ended (" .. tostring(reason) .. ")")
end

-- A scripted control reaches the controller only for the Titan it names, and only while that Titan is piloted; the
-- controller's own gates (pause, camera, auto drive) then have the last word, and a control one of them refused is not
-- remembered as held, so the script's next call is not mistaken for a repeat.
local function handle_input(msg)
  local T = ctx.titan
  if not T or T.id ~= msg.id or T.epoch ~= msg.epoch then
    ctx.diag("input.stale", "a scripted control named a Titan that is not this player's current one and was refused")
    return
  end
  local env = E()
  if not piloting(env) then
    ctx.diag("input.idle", "a scripted control arrived while the Titan is not piloted and was refused")
    return
  end
  local held, name, kind, value = ctx.scripted, msg.name, msg.kind, msg.value
  if kind == "relative" then
    if value == 0 then return end
  elseif kind == "axis" then
    if (held[name] or 0) == value then return end
  elseif (held[name] == true) == value then
    return
  end
  local ok, took = pcall(env.FPF.input, name, kind, value)
  if not ok then
    ctx.diag("input.fault", "a scripted control failed in the controller: " .. tostring(took))
  elseif took == true and kind ~= "relative" then
    if value == false or value == 0 then held[name] = nil else held[name] = value end
  end
end

local function handle_input_release(msg)
  local T = ctx.titan
  if not T or T.id ~= msg.id or T.epoch ~= msg.epoch then
    ctx.diag("input.stale", "a scripted control named a Titan that is not this player's current one and was refused")
    return
  end
  ctx.scripted = {}
  guarded("release scripted input", E().FPF.releaseInput)
end

-- ------------------------------------------------------------------ the server's gameplay requests -----------------
-- A server script's `hit`, `repair` and `creditCore` exports reach the controller as scoped messages (id, epoch and a request
-- number that grows per Titan). Each is handled once: the Titan's request high-water mark refuses a repeat or an older number
-- before anything runs, and a message for another Titan or epoch is ignored (nothing answers it: the server's own timeout
-- ends what it asked). The controller's own functions decide (gameplay.hit is its final boss-hit, gameplay.repair adds
-- hull only, gameplay.creditCore adds the authored core charge a confirmed hit or kill is worth); the answer,
-- `op = 'gameplay_result'`, says whether the request was taken and with what word and amount. It
-- is not the Titan's health: the pools settle at the controller's next frame and the next gameplay report carries them.
-- An answer waits in a small outbox until the resource takes it (its send budget can refuse) and is dropped after the
-- server's own timeout, which has by then answered for it.
local RESULT_WAIT = 5.0
local RESULT_LIMIT = 64

local function flush_results()
  local queue = ctx.results
  if #queue == 0 then return end
  while #queue > 0 do
    local entry = queue[1]
    if ctx.clock > entry.expires then
      ctx.diag("gameplay.expired", "a gameplay answer could not be sent in time and was dropped")
    elseif not ctx.publish(entry.message) then
      return
    end
    table.remove(queue, 1)
  end
end

local function answer(T, request, kind, ok, reason, amount)
  local message = { v = schema.VERSION, op = "gameplay_result", id = T.id, epoch = T.epoch, request = request, kind = kind, ok = ok,
    reason = reason, amount = amount }
  local clean, why = schema.result(message)
  if not clean then
    ctx.diag("gameplay.answer." .. tostring(why), "a gameplay answer was refused by the schema (" .. tostring(why) .. ")")
    clean = { v = schema.VERSION, op = "gameplay_result", id = T.id, epoch = T.epoch, request = request, kind = kind, ok = false,
      reason = "invalid_result" }
  end
  local queue = ctx.results
  if #queue >= RESULT_LIMIT then
    table.remove(queue, 1)
    ctx.diag("gameplay.backlog", "the gameplay answers are not being taken: the oldest was dropped")
  end
  queue[#queue + 1] = { message = clean, expires = ctx.clock + RESULT_WAIT }
  flush_results()
end

local function amount_of(value)
  if schema.finite(value) and value >= 0 then return math.min(value, schema.ACTION.amount) end
  return 0.0
end

local function handle_action(msg)
  local T = ctx.titan
  if not T or T.id ~= msg.id or T.epoch ~= msg.epoch then
    ctx.diag("gameplay.stale", "a gameplay request named a Titan that is not this player's current one and was ignored")
    return
  end
  if msg.request <= T.requests then
    ctx.diag("gameplay.repeat", "a gameplay request that was already handled arrived again and was ignored")
    return
  end
  T.requests = msg.request
  local env = E()
  if msg.op == "hit" then
    local request = { record = msg.record, origin = msg.origin, direction = msg.direction, attacker = msg.attacker,
      kind = msg.kind, scale = msg.scale }
    local called, accepted, outcome, damage, fault = pcall(gameplayMod.hit, env, request)
    if not called then
      ctx.diag("gameplay.hit.error", "the controller's hit failed: " .. tostring(accepted))
      return answer(T, msg.request, "hit", false, "controller_error")
    end
    if fault ~= nil then ctx.diag("gameplay.hit.fault", "the controller's hit raised: " .. tostring(fault)) end
    if accepted == true then
      return answer(T, msg.request, "hit", true, schema.reason(outcome), amount_of(damage))
    end
    return answer(T, msg.request, "hit", false, schema.reason(outcome))
  end
  if msg.op == "core_credit" then
    -- The helper answers the core charge it actually added (0 when the controller's own rules added none: still taken) or nil
    -- and why it did not apply the credit at all; the same answer is made of both.
    local request = { target = { id = msg.target.id, epoch = msg.target.epoch }, record = msg.record, killing = msg.killing }
    local called, applied, why = pcall(gameplayMod.creditCore, env, request)
    if not called then
      ctx.diag("gameplay.core.error", "the controller's core credit failed: " .. tostring(applied))
      return answer(T, msg.request, "core_credit", false, "controller_error")
    end
    if schema.finite(applied) and applied >= 0 then
      return answer(T, msg.request, "core_credit", true, nil, amount_of(applied))
    end
    return answer(T, msg.request, "core_credit", false, schema.reason(why))
  end
  local called, applied, why = pcall(gameplayMod.repair, env, msg.amount)
  if not called then
    ctx.diag("gameplay.repair.error", "the controller's repair failed: " .. tostring(applied))
    return answer(T, msg.request, "repair", false, "controller_error")
  end
  if schema.finite(applied) and applied > 0 then
    return answer(T, msg.request, "repair", true, nil, amount_of(applied))
  end
  return answer(T, msg.request, "repair", false, schema.reason(why))
end

-- ------------------------------------------------------------------ the owner's blows and effects on other Titans ---
-- open77_titan_combat hands every blow this controller's weapons land on a remote Titan (another player's Titan: a body
-- rendered here, which nothing is ever applied to) to `ctx.sendHit(report)`, and every status effect the controller's own
-- calls would apply to one to `ctx.sendStatus(report)`, once per frame and in the order they happened. A report becomes one
-- `hit_observed` or `status_observed` message named after this player's own grant (id and epoch) and numbered by the grant:
-- the two kinds share the grant's one count (T.hitSeq), as the server's one window of the newest numbers expects. Delivery is
-- best effort under the resource's send budget and nothing retries: the answer is true when the resource took the message,
-- and then, only then, the grant's count advances (so the server's count has no gaps from here); false when it was not taken
-- (no live grant, a report the server's schema would refuse, or the resource's budget said no), and the module drops that
-- report and says so.
local OBSERVATIONS = {
  hit = { op = "hit_observed", noun = "a blow on a remote Titan", passive = "hit", report = schema.hit_report, wire = schema.hit_observed },
  status = {
    op = "status_observed", noun = "a status effect on a remote Titan", passive = "affected",
    report = schema.status_report, wire = schema.status_observed,
  },
}

local function send_observation(label, report)
  local kind, T = OBSERVATIONS[label], ctx.titan
  if T == nil or not ctx.session.active then
    ctx.diag(label .. ".idle", kind.noun .. " was reported while this player has no live Titan grant: not sent")
    return false
  end
  local clean, why = kind.report(report)
  if not clean then
    ctx.diag(label .. ".report." .. tostring(why), "a report of " .. kind.noun .. " was refused by the schema (" .. tostring(why) .. ")")
    return false
  end
  if clean.target.id == T.id then
    ctx.diag(label .. ".self", "a report named this player's own Titan as the one that was " .. kind.passive .. ": not sent")
    return false
  end
  local message = { v = schema.VERSION, op = kind.op, id = T.id, epoch = T.epoch, seq = T.hitSeq + 1 }
  for key, value in pairs(clean) do message[key] = value end
  local wire, reason = kind.wire(message)
  if not wire then
    ctx.diag(label .. ".message." .. tostring(reason), kind.noun .. " made a message the server would refuse (" .. tostring(reason) .. "): not sent")
    return false
  end
  if not ctx.publish(wire) then return false end
  T.hitSeq = wire.seq
  return true
end

function ctx.sendHit(report)
  return send_observation("hit", report)
end

function ctx.sendStatus(report)
  return send_observation("status", report)
end

-- ------------------------------------------------------------------ the owner's blows on cars ---------------------------------
-- A car is the server's: only its canonical ledger sticks (every client resets a car's local damage to it), and the controller's own
-- stat pool write changes nothing on one. What the controller's weapons take off a car is therefore reported instead:
-- OP77.vehicleHit(veh, share) names the car by its canonical id (the lookup the grab key makes), adds `share` (percent of the car's
-- full health) to what is already waiting for that car, never more than one whole car, and remembers where the car is. The sums leave
-- at most every VEHICLE_EVERY seconds, one `vehicle_hit` message per car, named after this player's own grant and numbered with the
-- observations above (T.hitSeq). The server decides: it applies the sum to the car unless a script vetoes it. A message the
-- resource's budget refused waits and goes with a later frame; one that has waited VEHICLE_WAIT seconds is dropped. Everything here
-- ends with the Titan, the session and a new grant.
local VEHICLE_EVERY = 0.1       -- s between two sends: a sustained hazard is summed, not sent every frame
local VEHICLE_WAIT = 2.0        -- s a report waits for the resource to take it
local VEHICLE_PENDING = 32      -- cars waiting at once

local function vehicle_live()
  if ctx.titan == nil or not ctx.session.active then
    ctx.diag("vehicle.idle", "a blow on a car was reported while this player has no live Titan grant: not sent")
    return false
  end
  return true
end

-- `text` is the car's canonical id as text, `share` percent of its full health, `point` where the car is.
local function queue_vehicle_id(text, share, point)
  if not schema.finite(share) or share <= 0 then return false end
  local cap = schema.VEHICLE.share
  local queue = ctx.vehicleQueue
  for _, entry in ipairs(queue) do
    if entry.vehicle == text then
      entry.share, entry.point = math.min(cap, entry.share + share), point
      return true
    end
  end
  if #queue >= VEHICLE_PENDING then
    ctx.diag("vehicle.backlog", "the blows on cars are not being sent: one was dropped")
    return false
  end
  queue[#queue + 1] = { vehicle = text, share = math.min(cap, share), point = point, since = ctx.clock }
  return true
end

local function queue_vehicle_hit(veh, share)
  if not vehicle_live() then return false end
  if not schema.finite(share) or share <= 0 then return false end
  local id, why = grabMod.vehicle_id(veh)
  if not id then
    ctx.diag("vehicle.unnamed", "a blow on a car with no canonical Open77 id was not reported (" .. tostring(why) .. "): the server cannot damage it")
    return false
  end
  local okp, at = pcall(function() local p = veh:GetWorldPosition() return { x = p.x, y = p.y, z = p.z } end)
  if not okp then
    ctx.diag("vehicle.position", "the position of a car that was hit could not be read: " .. tostring(at))
    return false
  end
  return queue_vehicle_id(string.format("%d", id), share, at)
end

-- The platform's cars as of this controller frame, for the blasts of the frame: ctx.clock moves once a frame (in M.tick, behind the
-- controller's update), so every blast of a salvo that goes off in one frame reads one list. A failed read is not kept.
local function streamed_vehicles()
  if ctx.carRows ~= nil and ctx.carRowsAt == ctx.clock then return true, ctx.carRows end
  local ok, rows = pcall(Open77.vehicles.all)
  if ok and type(rows) == "table" then ctx.carRows, ctx.carRowsAt = rows, ctx.clock end
  return ok, rows
end

-- A blast at (x, y, z) takes `direct` percent off the nearest car that met it (within BLAST_MET of the point) and `near` percent off
-- every other car within `radius`, among the platform's own cars (Open77.vehicles.all: canonical ids, streamed, with their health
-- and position), so that no engine query decides which cars count and no car is too far to be named.
local BLAST_MET = 7.0

local function vehicle_blast(x, y, z, direct, radius, near)
  local fin = schema.finite
  local wantDirect = fin(direct) and direct > 0
  local wantNear = fin(near) and near > 0 and fin(radius) and radius > 0
  if not (wantDirect or wantNear) or not (fin(x) and fin(y) and fin(z)) then return false end
  if not vehicle_live() then return false end
  local ok, rows = streamed_vehicles()
  if not ok or type(rows) ~= "table" then
    ctx.diag("vehicle.blast.list", "the cars a blast reaches could not be listed: " .. tostring(ok and "no rows" or rows))
    return false
  end
  local cars, met, metD2 = {}, nil, BLAST_MET * BLAST_MET
  for _, row in ipairs(rows) do
    local p = type(row) == "table" and row.position or nil
    if type(p) == "table" and math.type(row.id) == "integer" and row.id >= 1 and row.streamed == true
        and type(row.health) == "number" and row.health > 0 and fin(p.x) and fin(p.y) and fin(p.z) then
      local d2 = (p.x - x) ^ 2 + (p.y - y) ^ 2 + (p.z - z) ^ 2
      local car = { text = string.format("%d", row.id), at = { x = p.x, y = p.y, z = p.z }, d2 = d2 }
      cars[#cars + 1] = car
      if wantDirect and d2 <= metD2 then met, metD2 = car, d2 end
    end
  end
  local queued = false
  if met and queue_vehicle_id(met.text, direct, met.at) then queued = true end
  if wantNear then
    local reach2 = radius * radius
    for _, car in ipairs(cars) do
      if car ~= met and car.d2 <= reach2 and queue_vehicle_id(car.text, near, car.at) then queued = true end
    end
  end
  return queued
end

local function flush_vehicle_hits()
  local queue = ctx.vehicleQueue
  if #queue == 0 or ctx.clock < ctx.vehicleAt then return end
  local T = ctx.titan
  if T == nil or not ctx.session.active then
    ctx.vehicleQueue = {}
    return
  end
  local sent = 0
  while #queue > 0 do
    local entry = queue[1]
    if ctx.clock - entry.since > VEHICLE_WAIT then
      ctx.diag("vehicle.expired", "a blow on a car could not be sent in time and was dropped")
    else
      local message = { v = schema.VERSION, op = "vehicle_hit", id = T.id, epoch = T.epoch, seq = T.hitSeq + 1,
        vehicle = entry.vehicle, share = entry.share, point = entry.point }
      local wire, reason = schema.vehicle_hit(message)
      if not wire then
        ctx.diag("vehicle.message." .. tostring(reason), "a blow on a car made a message the server would refuse (" .. tostring(reason) .. "): not sent")
      elseif not ctx.publish(wire) then
        break                   -- the resource's budget said no: this one and the rest wait for a later frame
      else
        T.hitSeq = wire.seq
        sent = sent + 1
      end
    end
    table.remove(queue, 1)
  end
  if sent > 0 then ctx.vehicleAt = ctx.clock + VEHICLE_EVERY end
end

-- ------------------------------------------------------------------ the owner's blows on other players ----------------------------
-- Another player's body is Open77's, and the platform's own rules (team, scope, friendly fire, the server's arbiters) decide what a
-- blow on it costs, so what the controller's weapons land on one is reported to the server instead. OP77.playerHit(ent, record) is what the generated
-- controller calls at every blow it lands on a person: when `ent` is another player's body it is queued under the victim and the
-- attack record and summed (`count`, at most schema.PLAYER.count). An entry leaves once it is PLAYER_EVERY seconds old, as one
-- `player_hit` message named after this player's own grant and numbered with the observations above (T.hitSeq, which advances only
-- when the resource took the message). A message the resource's budget refused waits and goes with a later frame; one that has
-- waited PLAYER_WAIT seconds is dropped. The server prices the record itself and applies it under Open77's PvP rules; the report
-- carries no amount. Everything here ends with the Titan, the session and a new grant.
local PLAYER_EVERY = 0.1      -- s a report is summed for before it is sent
local PLAYER_WAIT = 2.0       -- s a report waits for the resource to take it
local PLAYER_PENDING = 32     -- (player, record) pairs waiting at once

local function queue_player_hit(ent, record)
  local pid = owned_player_id(ent)
  if pid == nil then return false end
  if ctx.titan == nil or not ctx.session.active then
    ctx.diag("player.idle", "a blow on a player was reported while this player has no live Titan grant: not sent")
    return false
  end
  local text = string.format("%d", pid)
  local clean, why = schema.player_report({ player = text, record = record, count = 1 })
  if not clean then
    ctx.diag("player.report." .. tostring(why), "a report of a blow on a player was refused by the schema (" .. tostring(why) .. ")")
    return false
  end
  local key, queue = text .. "|" .. record, ctx.playerQueue
  for _, entry in ipairs(queue) do
    if entry.key == key then
      entry.count = math.min(schema.PLAYER.count, entry.count + 1)
      return true
    end
  end
  if #queue >= PLAYER_PENDING then
    ctx.diag("player.backlog", "the blows on players are not being sent: one was dropped")
    return false
  end
  queue[#queue + 1] = { key = key, player = text, record = record, count = 1, since = ctx.clock }
  return true
end

local function flush_player_hits()
  local queue = ctx.playerQueue
  if #queue == 0 then return end
  local T = ctx.titan
  if T == nil or not ctx.session.active then
    ctx.playerQueue = {}
    return
  end
  while #queue > 0 do
    local entry = queue[1]
    local age = ctx.clock - entry.since
    if age > PLAYER_WAIT then
      ctx.diag("player.expired", "a blow on a player could not be sent in time and was dropped")
    elseif age < PLAYER_EVERY - 1e-6 then
      break                     -- still being summed; the entries are in the order they were made, so every later one is younger
    else
      local message = { v = schema.VERSION, op = "player_hit", id = T.id, epoch = T.epoch, seq = T.hitSeq + 1,
        player = entry.player, record = entry.record, count = entry.count }
      local wire, reason = schema.player_hit(message)
      if not wire then
        ctx.diag("player.message." .. tostring(reason), "a blow on a player made a message the server would refuse (" .. tostring(reason) .. "): not sent")
      elseif not ctx.publish(wire) then
        break                   -- the resource's budget said no: this one and the rest wait for a later frame
      else
        T.hitSeq = wire.seq
      end
    end
    table.remove(queue, 1)
  end
end

-- ------------------------------------------------------------------ the owner's blows on Open77 NPCs ---------------------------
-- An Open77 NPC is the platform's body and its health the platform's too: what the controller's weapons land on one is reported to
-- the server instead of being left to the game alone (the game's own damage reaches the platform only as "native"). OP77.npcHit(ent,
-- record, x, y, z) is what the generated controller calls at every blow it lands on a person, next to OP77.playerHit: when `ent` is an
-- Open77 NPC (its engine entity id is in Open77.npcs.all, the set owned_bodies lists: never another player's body, a car, this
-- Titan or its decoy, another player's Titan) and this player holds a live grant, one `npc_hit` message is queued for it, named
-- after the grant's id and epoch and numbered with the observations above (T.hitSeq, which advances only when the resource took the
-- message). It carries the NPC's platform id as text, the attack record, the kind of blow the record stands for (NPC_KIND: a
-- round, a blast, a fist, a blade, or other) and where it landed. No amount: a mission validates and prices it. A round on one NPC
-- is reported at most every schema.NPC.roundGap seconds (one waits for the resource while it is pending: the rest of the burst
-- is the same blow to the server); every other blow is its own message. A message the resource's budget refused waits and goes
-- with a later frame; one that has waited NPC_WAIT seconds is dropped. Everything here ends with the Titan, the session and a
-- new grant.
local NPC_WAIT = 2.0          -- s a report waits for the resource to take it
local NPC_PENDING = 64        -- reports waiting at once
local NPC_ROUND_KEYS = 64     -- NPCs the round spacing remembers before it forgets the stale ones
local NPC_KIND = {}
for _, record in ipairs({ "XO16_Hit", "Pred_Hit", "Rail_1", "Rail_2", "Rail_3", "Rail_4" }) do NPC_KIND["Attacks.BT7274_" .. record] = "round" end
for _, record in ipairs({ "Missile", "FlightRocket", "MissileBlast", "FlightBlast", "Fist_Blast", "Pound_Mid", "Pound_Edge", "Eject" }) do
  NPC_KIND["Attacks.BT7274_" .. record] = "blast"
end
for _, record in ipairs({ "Punch", "Fist", "Fist_Heavy", "Fist_Charged", "Fist_Core" }) do NPC_KIND["Attacks.BT7274_" .. record] = "melee" end
for _, record in ipairs({ "Sword", "Sword_Core", "Sword_Charged", "ArcWave" }) do NPC_KIND["Attacks.BT7274_" .. record] = "blade" end
-- Anything else (the vortex, the smoke and the gas, the fallback record a weapon uses when TweakXL did not load its own) is "other".

-- The platform's id of an Open77 NPC the controller's blow landed on, or nil: this Titan's own body and its decoy are refused even
-- if a list ever named them.
local function owned_npc_id(ent)
  if ent == nil then return nil end
  local ok, eid = pcall(entity_id_of, ent)
  if not ok or math.type(eid) ~= "integer" or eid == 0 then return nil end
  local row = owned_bodies()[eid]
  if row == nil or row.kind ~= "npc" or math.type(row.npc) ~= "integer" or row.npc < 1 then return nil end
  local PS = ctx.env and ctx.env.PS
  if type(PS) == "table" then
    if PS.ent ~= nil then
      local okp, own = pcall(entity_id_of, PS.ent)
      if okp and own == eid then return nil end
    end
    local decoy = PS.decoy
    if type(decoy) == "table" and decoy.hash == tostring(eid) then return nil end
  end
  return row.npc
end

local function forget_stale_rounds()
  local keep, kept = {}, 0
  for text, at in pairs(ctx.npcRoundAt) do
    if ctx.clock - at < 1.0 then keep[text], kept = at, kept + 1 end
  end
  ctx.npcRoundAt, ctx.npcRoundN = keep, kept
end

local function queue_npc_hit(ent, record, x, y, z)
  local npc = owned_npc_id(ent)
  if npc == nil then return false end
  if ctx.titan == nil or not ctx.session.active then
    ctx.diag("npc.idle", "a blow on an NPC was reported while this player has no live Titan grant: not sent")
    return false
  end
  local kind = type(record) == "string" and NPC_KIND[record] or "other"
  local text = string.format("%d", npc)
  local queue = ctx.npcQueue
  if kind == "round" then
    local last = ctx.npcRoundAt[text]
    if last ~= nil and ctx.clock - last < schema.NPC.roundGap - 1e-6 then return true end
    for _, entry in ipairs(queue) do
      if entry.npc == text and entry.kind == "round" then return true end
    end
  end
  local point = { x = x, y = y, z = z }
  if not (schema.finite(x) and schema.finite(y) and schema.finite(z)) then
    local okp, at = pcall(function() local p = ent:GetWorldPosition() return { x = p.x, y = p.y, z = p.z } end)
    if not okp then
      ctx.diag("npc.position", "the place of an NPC that was hit could not be read: " .. tostring(at))
      return false
    end
    point = at
  end
  local clean, why = schema.npc_report({ npc = text, record = record, kind = kind, point = point })
  if not clean then
    ctx.diag("npc.report." .. tostring(why), "a report of a blow on an NPC was refused by the schema (" .. tostring(why) .. ")")
    return false
  end
  if #queue >= NPC_PENDING then
    ctx.diag("npc.backlog", "the blows on NPCs are not being sent: one was dropped")
    return false
  end
  if kind == "round" then
    if ctx.npcRoundAt[text] == nil then
      if ctx.npcRoundN >= NPC_ROUND_KEYS then forget_stale_rounds() end
      ctx.npcRoundN = ctx.npcRoundN + 1
    end
    ctx.npcRoundAt[text] = ctx.clock
  end
  queue[#queue + 1] = { npc = text, record = clean.record, kind = kind, point = clean.point, since = ctx.clock }
  return true
end

local function flush_npc_hits()
  local queue = ctx.npcQueue
  if #queue == 0 then return end
  local T = ctx.titan
  if T == nil or not ctx.session.active then
    ctx.npcQueue = {}
    return
  end
  while #queue > 0 do
    local entry = queue[1]
    if ctx.clock - entry.since > NPC_WAIT then
      ctx.diag("npc.expired", "a blow on an NPC could not be sent in time and was dropped")
    else
      local message = { v = schema.VERSION, op = "npc_hit", id = T.id, epoch = T.epoch, seq = T.hitSeq + 1,
        npc = entry.npc, record = entry.record, kind = entry.kind, point = entry.point }
      local wire, reason = schema.npc_hit(message)
      if not wire then
        ctx.diag("npc.message." .. tostring(reason), "a blow on an NPC made a message the server would refuse (" .. tostring(reason) .. "): not sent")
      elseif not ctx.publish(wire) then
        break                   -- the resource's budget said no: this one and the rest wait for a later frame
      else
        T.hitSeq = wire.seq
      end
    end
    table.remove(queue, 1)
  end
end

-- ------------------------------------------------------------------ a mission's controls --------------------------------
-- The server's `hold`, `class` and `credit_kill` messages name this Titan's id and epoch like a scripted control; one for another
-- Titan or epoch is ignored. The controller holds and gates (FPF.holdSet, FPF.classSet, init.lua's mission seam): the bridge only
-- hands the message over, and a class changes the loadout, the lock, the speed and the weapon in this one handler.
local function handle_hold(msg)
  local T = ctx.titan
  if not T or T.id ~= msg.id or T.epoch ~= msg.epoch then
    ctx.diag("hold.stale", "a hold named a Titan that is not this player's current one and was ignored")
    return
  end
  guarded("hold", E().FPF.holdSet, msg.held)
end

local function handle_class(msg)
  local T = ctx.titan
  if not (T and T.id == msg.id and T.epoch == msg.epoch and msg.revision > ctx.revision) then
    ctx.log("a class update for Titan " .. msg.id .. " epoch " .. msg.epoch .. " revision " .. msg.revision .. " was ignored")
    return
  end
  set_policy(msg.loadout, msg.revision)
  guarded("class", E().FPF.classSet, msg.class)
  -- The class's weapon is the only one its Titan can select (its perk is 1, the other four are 0): switched to now, or as soon as
  -- BT's first-person objects have settled. Clearing the class leaves the weapon in the hands.
  local weapon = msg.class and msg.class.weapon or nil
  if weapon then
    if weapon_local(weapon, true) then drop_queued("weapon") else queue_command("weapon", weapon, true) end
  end
  ctx.log("class: Titan " .. msg.id .. " epoch " .. msg.epoch .. " revision " .. msg.revision .. " is "
    .. (msg.class and msg.class.id or "no class"))
end

-- The core charge of one kill, by the controller's own kill table and rules (open77_titan_gameplay.creditKill). Nothing answers it:
-- a credit that added nothing is reported once per reason.
local function handle_credit_kill(msg)
  local T = ctx.titan
  if not T or T.id ~= msg.id or T.epoch ~= msg.epoch then
    ctx.diag("credit_kill.stale", "a kill credit named a Titan that is not this player's current one and was ignored")
    return
  end
  local called, added, why = pcall(gameplayMod.creditKill, E(), msg.rank)
  if not called then
    ctx.diag("credit_kill.error", "the controller's kill credit failed: " .. tostring(added))
  elseif added == nil then
    ctx.diag("credit_kill." .. tostring(why), "a kill credit added nothing: " .. tostring(why))
  end
end

local function handle(msg)
  local op = msg.op
  if op == "session" then
    ctx.session.lastAt = ctx.clock
    if msg.active then
      if not ctx.session.active then start_session(msg.player) end
      ctx.session.player = msg.player or ctx.session.player
      set_pvp(msg.pvp == true)
    else
      end_session("the resource ended the session")
    end
    return
  end
  if not ctx.session.active then
    ctx.diag("outside." .. op, "a Titan " .. op .. " arrived outside a session and was ignored")
    return
  end
  if op == "state" then
    observer.state(msg)
  elseif op == "carry_grant" or op == "carry_denied" or op == "carry_ended" then
    carry.inbound(msg)
  elseif op == "grant" then
    local T = ctx.titan
    local same = T ~= nil and T.id == msg.id and T.epoch == msg.epoch
    if T and not same then clean_owner("a new grant replaced the old one") end
    ctx.titan = { id = msg.id, epoch = msg.epoch, owner = msg.owner, grantedAt = ctx.clock, seen = false,
      requests = same and T.requests or 0, hitSeq = same and T.hitSeq or 0, piloted = msg.piloted == true }
    capture.reset()
    if not same then
      ctx.weaponFact = 0
      E().FPF.classSet(nil)
    end
    -- the spawn export's `hold` option: held from the grant, before BT stands anywhere
    E().FPF.holdSet(msg.hold == true)
    if not same or msg.revision > ctx.revision then set_policy(msg.loadout, msg.revision) end
    ctx.log("grant: Titan " .. msg.id .. " epoch " .. msg.epoch .. " loadout revision " .. ctx.revision
      .. (msg.piloted and ", piloted" or "") .. (msg.hold and ", held" or ""))
    if ctx.request and ctx.request.action == "spawn" then
      local by = ctx.request.by
      ctx.request = nil
      spawn_local(by)
    end
  elseif op == "loadout" then
    local T = ctx.titan
    if T and T.id == msg.id and T.epoch == msg.epoch and msg.revision > ctx.revision then
      set_policy(msg.loadout, msg.revision)
      ctx.log("loadout: Titan " .. msg.id .. " epoch " .. msg.epoch .. " revision " .. msg.revision)
    else
      ctx.log("a loadout update for Titan " .. msg.id .. " epoch " .. msg.epoch .. " revision " .. msg.revision .. " was ignored")
    end
  elseif op == "class" then
    handle_class(msg)
  elseif op == "hold" then
    handle_hold(msg)
  elseif op == "credit_kill" then
    handle_credit_kill(msg)
  elseif op == "command" then
    handle_command(msg)
  elseif op == "input" then
    handle_input(msg)
  elseif op == "input_release" then
    handle_input_release(msg)
  elseif op == "hit" or op == "repair" or op == "core_credit" then
    handle_action(msg)
  elseif op == "remove" then
    local T = ctx.titan
    if T and (not msg.id or msg.id == T.id) and (not msg.epoch or msg.epoch == T.epoch) then
      ctx.log("the server removed this player's Titan (" .. msg.reason .. ")")
      clean_owner("Open77 " .. msg.reason)
      ctx.request = nil
      forget_titan()
    elseif msg.id then
      observer.remove(msg.id, msg.epoch, msg.reason)
    end
  elseif op == "error" then
    ctx.diag("server." .. msg.reason, "the Titan server refused: " .. msg.reason)
    note("Titan: " .. msg.reason)
    ctx.request = nil
  end
end

-- ------------------------------------------------------------------ the server's messages -------------------------------
-- A one-off command of the user's (/titan spawn, remove, pilot, exit, weapon, eject), the grant that has the controller call BT down
-- or replaces the Titan it had, and the server's removal of this player's Titan each run controller functions of their own that are
-- heavy for a 4 ms frame (startPilot alone measured 3.8 ms, stopDrive 5.8 ms). Run behind the controller's update, which has used
-- part of the frame by then, they were cut half-way. They run at the START of the frame (M.frame: start_commands), one a frame, so
-- the slice is theirs; a second one finds ctx.slice spent and is held for the next frame's start, and the messages behind it wait
-- with it (their order matters: a grant before the command that needs it). The core fill and the log switch are field writes: they
-- are not in this table and run as soon as their message is handled.
local HEAVY_COMMANDS = { spawn = true, remove = true, pilot = true, exit = true, weapon = true }

local function is_heavy(msg)
  local op = msg.op
  if op == "command" then
    return HEAVY_COMMANDS[msg.action] == true or (msg.action == "action" and msg.value == "eject")
  end
  if op == "class" then return true end
  local T = ctx.titan
  if op == "remove" then
    return T ~= nil and (not msg.id or msg.id == T.id) and (not msg.epoch or msg.epoch == T.epoch)
  end
  if op == "grant" then
    local same = T ~= nil and T.id == msg.id and T.epoch == msg.epoch
    return (T ~= nil and not same) or (ctx.request ~= nil and ctx.request.action == "spawn")
  end
  return false
end

local function pump_messages()
  local backlog = true               -- the loop ran out of its quota, not of messages
  for _ = 1, MAX_MESSAGES do
    local msg = ctx.held
    if msg ~= nil then
      ctx.held = nil
    else
      local value = poll()
      if value == nil then backlog = false break end
      local reason
      msg, reason = schema.inbound(value)
      if not msg then ctx.diag("invalid." .. tostring(reason), "a bridge message was refused (" .. tostring(reason) .. ")") end
    end
    if msg then
      if is_heavy(msg) then
        if ctx.slice <= 0 then
          ctx.held = msg
          backlog = false
          break
        end
        ctx.slice = ctx.slice - 1
      end
      local ok, err = pcall(handle, msg)
      if not ok then ctx.diag("handle." .. msg.op, "handling a " .. msg.op .. " message failed: " .. tostring(err)) end
      ctx.handled = ctx.handled + 1
    end
  end
  ctx.backlog = backlog
end

-- The first thing of a frame (M.frame), before the game's menus and events and the controller's update: the server's messages, in
-- their order, with the one-off commands among them, and the queued commands that could not run yet.
local function start_commands()
  ctx.slice = 1
  pump_messages()
  if ctx.session.active then run_queued() end
  ctx.started = true
end

-- ------------------------------------------------------------------ the owner's Titan over time ------------------
local function watch_titan()
  local T = ctx.titan
  if not T then return end
  local env = E()
  local present = titan_present()
  if present then
    T.seen, T.lastSeen = true, ctx.clock
  elseif T.seen and ctx.clock - (T.lastSeen or 0) > GONE_AFTER and not env.S.driving then
    ctx.log("the Titan is gone (sent home, destroyed, or deleted): telling the server")
    carry.abort_all("titan_gone")
    request("remove")
    capture.reset()
    forget_titan()
    return
  elseif not T.seen and ctx.clock - T.grantedAt > GRANT_UNUSED then
    ctx.diag("grant.unused", "the granted Titan never appeared: the grant is given back")
    carry.abort_all("titan_gone")
    request("remove")
    forget_titan()
    return
  end
  if env.S.gone and ctx.clock - (T.goneAt or ctx.clock) > 1.0 then
    carry.abort_all("titan_gone")
    request("remove")
    forget_titan()
    return
  end
  if env.S.gone then T.goneAt = T.goneAt or ctx.clock else T.goneAt = nil end
end

local function release_keys()
  local keep = {}
  for _, r in ipairs(ctx.releases) do
    if ctx.clock >= r.at then
      if r.field then
        E().PS[r.field] = false
      else
        guarded("release " .. r.key, E().FPF.bind, r.key, false)
      end
    else
      keep[#keep + 1] = r
    end
  end
  ctx.releases = keep
end

local function heartbeat()
  ctx.heartbeatAt = ctx.clock + HEARTBEAT_EVERY
  ctx.heartbeatN = ctx.heartbeatN + 1
  send({ v = schema.VERSION, op = "heartbeat", n = ctx.heartbeatN })
end

local function status_line()
  return string.format("frames %d (refused %d), events dropped %d, queue %d, remote Titans %d, titan %s, %s, %s, %s",
    capture.sent, capture.refused, capture.dropped, #capture.events, observer.count, ctx.titan and (ctx.titan.id .. "/" .. ctx.titan.epoch) or "none", carry.status(), grab.status(), combat.status())
end

-- ------------------------------------------------------------------ per-frame --------------------------------------
function M.tick(delta)
  ctx.clock = ctx.clock + delta
  if not ctx.env then return end
  -- Behind a frame's start (M.frame) the slice of the one-off commands is spent for this frame, and what is left waits for the next
  -- frame's start; a tick no frame start came before (the controller's update called on its own) runs them all, as it always did.
  local early = ctx.started
  ctx.started = false
  ctx.slice = early and 0 or math.huge
  -- The frame's start read the server's messages a moment ago and nothing arrives in between: a second look is for what a start left
  -- behind because it ran out of its quota (ctx.backlog), and for a tick no frame start came before.
  if not early or ctx.backlog then pump_messages() end
  local s = ctx.session
  if s.active then
    if ctx.link == nil then
      end_session("the resource's link is gone")
    elseif ctx.clock - s.lastAt > KEEPALIVE_LOST then
      end_session("no session keepalive from the resource")
    else
      if ctx.clock >= ctx.heartbeatAt then heartbeat() end
      if ctx.clock - ctx.lastPublishOk > BRIDGE_DEAD then
        end_session("the bridge stopped accepting messages")
      end
    end
  end
  -- What follows runs only when it has something to do: each is a call (or three) in every frame otherwise.
  if carry.c ~= nil or carry.outbox[1] ~= nil or next(carry.late) ~= nil then carry.tick() end
  -- the grab key's state, behind the controller's update and the carry's tick it reads: what is offered, held and charging
  if ctx.titan ~= nil or grab.state ~= "idle" or ctx.grabUi ~= nil then
    local okg, errg = pcall(grab.tick, delta)
    if not okg then
      ctx.diag("grab.tick", "the grab key failed in its frame: " .. tostring(errg))
      pcall(grab.reset)
    end
  end
  if s.active then
    if ctx.request and ctx.clock - ctx.request.at > REQUEST_WAIT then
      ctx.log("no answer to the " .. ctx.request.action .. " request")
      ctx.request = nil
    end
    if next(ctx.scripted) ~= nil and not piloting(ctx.env) then drop_input(true) end
    if ctx.releases[1] ~= nil then release_keys() end
    if ctx.results[1] ~= nil then flush_results() end
    if not early and ctx.queued ~= nil then run_queued() end
    if ctx.titan ~= nil then watch_titan() end
    capture.watch()
    if ctx.titan then
      -- contained: a frame that cannot be made must not take the rest of the tick (hits, status, combat) down with it
      local okf, errf = pcall(capture.frame)
      if not okf then
        ctx.diag(is_time_cut(errf) and "capture.frame.cut" or ("capture.frame." .. tostring(errf)), "a Titan frame could not be made: " .. tostring(errf))
      end
    end
    if ctx.clock >= ctx.statusAt then
      ctx.statusAt = ctx.clock + STATUS_EVERY
      ctx.log("status: " .. status_line())
    end
  end
  if observer.count > 0 then observer.tick(delta) end
  -- The blows the controller's own update just sent, after the remote bodies have moved: this tick runs behind the controller's
  -- update, and the module re-lists the people (PS.npcsAt) when the set of live remote Titans changed.
  local okc, errc = pcall(combat.frame)
  if not okc then ctx.diag("combat.frame", "the combat module failed in its frame: " .. tostring(errc)) end
  if ctx.vehicleQueue[1] ~= nil then
    local okv, errv = pcall(flush_vehicle_hits)
    if not okv then ctx.diag("vehicle.flush", "the blows on cars could not be sent: " .. tostring(errv)) end
  end
  if ctx.playerQueue[1] ~= nil then
    local okp, errp = pcall(flush_player_hits)
    if not okp then ctx.diag("player.flush", "the blows on players could not be sent: " .. tostring(errp)) end
  end
  if ctx.npcQueue[1] ~= nil then
    local okn, errn = pcall(flush_npc_hits)
    if not okn then ctx.diag("npc.flush", "the blows on NPCs could not be sent: " .. tostring(errn)) end
  end
end

-- ------------------------------------------------------------------ hooks called by the patched controller --------
M.var = capture.var
M.spawnEffect = capture.spawnEffect
M.hintMove = capture.hintMove
M.hintTarget = capture.hintTarget
M.hintSlot = capture.hintSlot
M.hintSpawn = capture.hintSpawn
M.nativeSound = capture.nativeSound
M.axl = capture.axl
M.effectEvent = capture.effectEvent
M.tracer = capture.tracer

-- A frame now, with the events queued so far: the controller calls it just before it deletes BT (a blast's effect and boom would
-- otherwise be dropped with the Titan, never sent). Without a session or a Titan it sends nothing; a failure must not stop the
-- controller's own deletion.
function M.flushFrame()
  local ok, err = pcall(capture.frame, true)
  if not ok then ctx.diag("capture.flush", "the frame before BT's removal failed: " .. tostring(err)) end
end

function M.draw()
  observer.draw()
end

-- The controller's ScriptedPuppet.IsActive gates that its missiles, vortex shield and electric smoke ask about a target (the
-- generated controller calls this in their place): a body of another player's Titan is a presentation entity, not a puppet,
-- and the combat module answers for it; anything else keeps the game's own answer.
function M.targetActive(ent)
  local ok, known = pcall(combat.targetActive, ent)
  if ok and known ~= nil then return known end
  if not ok then ctx.diag("combat.active", "the combat module could not tell a target from a remote Titan: " .. tostring(known)) end
  return ScriptedPuppet.IsActive(ent)
end

-- ------------------------------------------------------------------ the Titan PvP flag ------------------------------------
-- The server's Titan PvP flag (the resource's `setTitanPvp` export) rides the `session` message: ctx.pvp is its last word, false until
-- the server says otherwise and false again once the session ends. While it is off another player's Titan and another player's body
-- are never a foe of the controller's own targeting: the missile lock, the flight strike's rockets, the designator, the AI, the slam
-- and every other authored gate that asks `OP77.targetHostile` is told "no" for them. A blow the player aims by hand is not decided here.
function M.titanPvp()
  return ctx.pvp == true
end

-- True for the body of another player's Titan (the observer's, live or not) and for another player's own body. Never raises: a body
-- that cannot be told is no player's.
local function player_target(ent)
  if ent == nil then return false end
  if observer.count > 0 and combat.titanBody(ent) then return true end
  owned_bodies()                               -- (refreshed at most four times a second)
  if bodies.players == 0 then return false end   -- nobody else is here: no body to read an id of, however many candidates ask
  return owned_body(ent) == "player"
end

function M.playerTarget(ent)
  local ok, yes = pcall(player_target, ent)
  if ok then return yes == true end
  ctx.diag("player.target", "a target could not be told from another player's: " .. tostring(yes))
  return false
end

-- The controller's `ent:IsHostile()` gates (the generated controller calls this in their place): another player's Titan or body is
-- no foe while the server's Titan PvP flag is off; otherwise the combat module answers for a body of another player's Titan (true
-- while it is live, false for one that has ended) and anything else is the game's own native method call on the entity, its raw
-- result returned and not protected here: every call site of the controller guards its own call and compares the answer itself.
function M.targetHostile(ent)
  if not ctx.pvp and M.playerTarget(ent) then return false end
  local ok, known = pcall(combat.targetHostile, ent)
  if ok and known ~= nil then return known end
  if not ok then ctx.diag("combat.hostile", "the combat module could not tell a target from a remote Titan: " .. tostring(known)) end
  return ent:IsHostile()
end

-- The controller's own status calls on an entity (fire, shock, stun, blind: the generated controller calls this before the
-- native ApplyStatusEffect): the combat module answers true for a body of another player's Titan, whose effect is then only
-- reported to the server as an observation and never applied (and the native call is skipped); false for anything else, where
-- the controller's own native call runs unchanged. A module that fails is reported and answers false.
function M.statusObserved(ent, effect, duration)
  local ok, handled = pcall(combat.statusObserved, ent, effect, duration)
  if ok then return handled == true end
  ctx.diag("combat.status", "the combat module could not tell a status effect on a remote Titan from the game's: " .. tostring(handled))
  return false
end

-- What the controller's own FPF.wreck would take off a car, and the blast of a car it would blow up (the generated controller calls
-- this in place of its stat pool write and its local blast): queued here, sent to the server as `vehicle_hit` (see "the owner's blows on
-- cars"). Answers true when the car has a canonical id and the report was queued: the controller then takes nothing off the car
-- itself, and a car it answers false for is the controller's own call (it has none to take from: nothing but the server's ledger
-- sticks). Errors are contained, like the frame's flush.
function M.vehicleHit(veh, share)
  local ok, queued = pcall(queue_vehicle_hit, veh, share)
  if ok then return queued == true end
  ctx.diag("vehicle.queue", "a blow on a car could not be queued: " .. tostring(queued))
  return false
end

-- A blast of the controller's own (a missile, the flight rocket's) at a point: `directShare` percent off the nearest car that met it
-- and `nearShare` off every other car within `nearRadius`, among the platform's cars (see vehicle_blast), queued like a blow on one
-- car and sent as `vehicle_hit`. Answers true when anything was queued. Errors are contained.
function M.vehicleBlast(x, y, z, directShare, nearRadius, nearShare)
  local ok, queued = pcall(vehicle_blast, x, y, z, directShare, nearRadius, nearShare)
  if ok then return queued == true end
  ctx.diag("vehicle.blast", "a blast on cars could not be queued: " .. tostring(queued))
  return false
end

-- A blow of the controller's on `ent` (the generated controller calls this at every blow it lands on a person, with the attack
-- record): queued for the server when `ent` is another player's body and this player holds a live grant (see "the owner's blows on
-- other players"). Answers true when it was queued, false for anything else (an NPC, a car, nobody). Errors are contained.
function M.playerHit(ent, record)
  local ok, queued = pcall(queue_player_hit, ent, record)
  if ok then return queued == true end
  ctx.diag("player.queue", "a blow on a player could not be queued: " .. tostring(queued))
  return false
end

-- A blow of the controller's on `ent` (the generated controller calls this next to OP77.playerHit, with the attack record and where
-- the blow landed): queued for the server when `ent` is an Open77 NPC and this player holds a live grant (see "the owner's blows on
-- Open77 NPCs"). Answers true when it was queued or is one more round of a burst already reported, false for anything else (a
-- player, a car, a vanilla ped, nobody). Errors are contained.
function M.npcHit(ent, record, x, y, z)
  local ok, queued = pcall(queue_npc_hit, ent, record, x, y, z)
  if ok then return queued == true end
  ctx.diag("npc.queue", "a blow on an NPC could not be queued: " .. tostring(queued))
  return false
end

-- ------------------------------------------------------------------ services for the controller -------------------
-- A monotonic clock in seconds (what the controller took os.time / os.clock for).
function M.now()
  return Open77.time.monotonic()
end

-- The controller's own log() writes through these: a line goes to the Open77 log while `verbose` is on (the resource
-- turns it on with its `titanlog` command), and a failure of one of its guarded parts is always reported, once.
function M.logOn()
  return ctx.verbose
end

function M.logLine(msg)
  Open77.log.info(PREFIX .. "controller: " .. msg)
end

function M.setVerbose(on)
  ctx.verbose = on == true
end

function M.fault(label, err)
  ctx.diag("fault." .. label .. "." .. tostring(err), "the controller's " .. label .. " failed: " .. tostring(err))
end

-- Whether a failure's text says the host's per-frame time limit cut the code short rather than the code being broken. ResourceHost's
-- instruction hook names the limit that fired ("(time limit)"; the instruction cap, a runaway loop, says "(instruction limit)" and is a
-- real failure: it is not matched). Never raises.
function M.cutByTimeLimit(text)
  return is_time_cut(text)
end

-- V's hidden-body record, kept outside the controller's own state so that a resource restart cannot lose it: the meshes the
-- controller switched off ({ [part] = { [component name] = true } }) as JSON in this machine's KVP, or nothing once V's body is back.
-- (A restart while V's body is hidden left V invisible and locked: the new controller knew nothing of it.) Errors only reach the log.
local HIDDEN_KEY = "titans:vHidden"

function M.rememberHidden(hidden)
  local ok, err = pcall(function()
    if type(hidden) == "table" then
      local text, why = json.encode(hidden)
      if type(text) ~= "string" then error("the record could not be encoded: " .. tostring(why), 0) end
      local saved, reason = Open77.kvp.set(HIDDEN_KEY, text)
      if saved == false then error("the record was not stored: " .. tostring(reason), 0) end
    else
      local _, reason = Open77.kvp.delete(HIDDEN_KEY)
      if reason ~= nil then error("the record could not be deleted: " .. tostring(reason), 0) end
    end
  end)
  if not ok then ctx.diag("hidden.remember", "V's hidden-body record could not be kept: " .. tostring(err)) end
end

-- Spawns an entity from a template through Codeware's DynamicEntitySystem at a world transform and returns its
-- EntityID, which Game.FindEntityByID answers with the entity once the engine has made it (the controller polls for it
-- exactly as it did with the interpreter's own spawner). The entity is tagged so the controller's leftover cleanup
-- (DeleteTagged) finds it.
function M.spawn(path, transform, appearance, tag)
  local spec = DynamicEntitySpec.new()
  spec.templatePath = RaRef(path)   -- a raRef: the depot path's 64-bit hash, not a ResRef struct
  if appearance ~= nil and appearance ~= "" then spec.appearanceName = appearance end
  spec.alwaysSpawned = true
  spec.persistState = false
  spec.persistSpawn = false
  spec.spawnInView = true
  spec.tags = { tag }
  spec.position = WorldPosition.ToVector4(WorldTransform.GetWorldPosition(transform))
  spec.orientation = transform.Orientation or WorldTransform.GetOrientation(transform)
  local id = Game.GetDynamicEntitySystem():CreateEntity(spec)
  return id
end
ctx.spawn = M.spawn

-- ------------------------------------------------------------------ the game's menus -------------------------------
-- The interpreter the controller was written for told it when the game entered one of its menu scenarios: the pause
-- menu and the menu after V's death (a session can end from either: the HUD widgets of the controller are let go of after
-- a moment, FPF.inkMenu) and the gameplay scenario every menu returns to (FPF.inkMenuNone). Open77 raises the same
-- transitions as the client event `open77:menuStateChanged`, whose `scenario` is the vanilla scenario the game left
-- gameplay for, or "" in gameplay. The resource hands each new scenario to `M.menu`; the next frame applies them in order.
local MENU_CUES = {
  MenuScenario_PauseMenu = { "the game's pause menu", true },
  MenuScenario_DeathMenu = { "the menu after V's death", false },
}
local MENU_QUEUE = 8

function M.menu(scenario)
  local menus = ctx.menus
  if type(scenario) ~= "string" or scenario == menus.scenario then return end
  menus.scenario = scenario
  local queue = menus.queue
  if #queue >= MENU_QUEUE then table.remove(queue, 1) end
  queue[#queue + 1] = scenario
end

local function apply_menus(env)
  local menus = ctx.menus
  local queue = menus.queue
  if #queue == 0 then return end
  menus.queue = {}
  if env.S.gone then return end
  for _, scenario in ipairs(queue) do
    local cue = MENU_CUES[scenario]
    if cue then
      guarded("a menu opens", env.FPF.inkMenu, cue[1], cue[2])
    elseif scenario == "" then
      guarded("no menu", env.FPF.inkMenuNone)
    end
  end
end

-- ------------------------------------------------------------------ what the overlay's window offered ---------------
-- While the interpreter's overlay was open, the mod's window offered two buttons: end the wait before BT can be called
-- again, and bring a BT that is out to V. The resource offers both as a client command and a rebindable key (client.lua).
function M.resetCooldown()
  local env = ctx.env
  if not env then return false end
  env.PS.awayTill = nil
  ctx.log("the wait for BT is ended by the player")
  note("BT-7274 can be called now.")
  return true
end

function M.bring(by)
  if not ctx.env then return false end
  return guarded("BT brought to V", ctx.env.FPF.bringBt, by or "the Open77 command")
end

-- ------------------------------------------------------------------ the game's events, drained -------------------
-- r6/scripts/open77_titans/Open77TitanEvents.reds keeps what the controller observed in the game's own functions
-- (inputs, Mod Settings keys, hits, the end of a session). The resource's session switches it on; once per
-- frame its batch goes to the controller (FPF.forwarded).
-- The calls into the forwarder system, each a function of its own so that a protected call needs no closure: the drain runs every game
-- frame, and a closure with its upvalues per call was an allocation in every frame.
local function events_system()
  return Game.GetScriptableSystemsContainer():Get(CName.new("Open77TitanEvents"))
end
local function events_enable(sys, on) sys:Enable(on) end
local function events_wants(sys) return sys:Wants() end
local function events_pending(sys) return sys:Pending() end
local function events_drain(sys) return sys:Drain() end
local function events_watch(sys, decoy, titan) sys:Watch(decoy, titan) end

-- The entity ids of BT's stand-in target and of BT's own body, read when one of the two entities changes (not every frame): what was
-- read before a failure stays, as it did when the two reads were one protected block.
local watched_decoy, watched_titan = 0, 0
local function read_watched(decoyEnt, titanEnt)
  if decoyEnt then watched_decoy = decoyEnt:GetEntityID() end
  if titanEnt then watched_titan = titanEnt:GetEntityID() end
end

local function drain_events(env)
  local queue = ctx.events
  local sys = queue.sys
  if not ctx.session.active then
    if sys ~= nil and queue.enabled then
      pcall(events_enable, sys, false)
      queue.enabled = false
    end
    -- No entity handle outlives the session in this table (the controller lets go of its own at the end of one, and a handle kept
    -- here would be a stale one to a deleted BT); the next session asks the system what to watch afresh.
    if queue.titanEnt or queue.decoyEnt then
      queue.titanEnt, queue.decoyEnt, queue.titan, queue.decoy = false, false, nil, nil
    end
    return
  end
  -- A world load replaces the game's scriptable systems: Open77's pristine load right after a connect, which comes
  -- after this session has started, is one. The system switched on before still answers, so Pending never fails, but
  -- it no longer hears the game; the new one was never switched on. Once a second the current one is asked, and one
  -- that is not switched on replaces it (and is told what to watch again).
  if sys ~= nil and queue.enabled and ctx.clock >= queue.checkAt then
    queue.checkAt = ctx.clock + 1.0
    local okc, current = pcall(events_system)
    local okw, wants = false, nil
    if okc and current ~= nil then okw, wants = pcall(events_wants, current) end
    if okw and wants == false then
      sys, queue.sys, queue.enabled = current, current, false
      queue.decoy, queue.titan = nil, nil
      queue.decoyEnt, queue.titanEnt = false, false   -- never equal to an entity: the next look tells the new system what to watch
      ctx.log("the game's Open77TitanEvents was replaced (a world load): the new one is switched on")
    end
  end
  if sys == nil then
    if ctx.clock < queue.retryAt then return end
    queue.retryAt = ctx.clock + 2.0
    local ok, found = pcall(events_system)
    if not (ok and found ~= nil) then
      ctx.diag("events.missing", "the Open77TitanEvents system is not in the game (r6/scripts/open77_titans/Open77TitanEvents.reds did not load): "
        .. "keys and hits do not reach the controller")
      return
    end
    sys, queue.sys, queue.enabled = found, found, false
  end
  if not queue.enabled then
    if not pcall(events_enable, sys, true) then
      queue.sys = nil
      return
    end
    queue.enabled = true
  end
  -- the entities whose hits matter besides the player's (BT's stand-in target and BT's own body): their ids are read, and the system
  -- told, only when one of the two entities is another than at the last look
  local PS = env.PS
  local decoyEnt = PS.decoy and PS.decoy.ent or nil
  local titanEnt = PS.ent
  if decoyEnt ~= queue.decoyEnt or titanEnt ~= queue.titanEnt then
    watched_decoy, watched_titan = 0, 0
    pcall(read_watched, decoyEnt, titanEnt)
    local told = watched_decoy == queue.decoy and watched_titan == queue.titan
    if not told then told = pcall(events_watch, sys, watched_decoy, watched_titan) end
    if told then
      queue.decoy, queue.titan = watched_decoy, watched_titan
      queue.decoyEnt, queue.titanEnt = decoyEnt, titanEnt    -- a refused Watch is asked again at the next frame
    end
  end
  local ok, count = pcall(events_pending, sys)
  if not ok then
    queue.sys, queue.enabled = nil, false   -- the game instance ended: look the system up again
    return
  end
  if count == 0 then return end
  local okb, batch = pcall(events_drain, sys)
  if not okb then
    queue.sys, queue.enabled = nil, false
    return
  end
  if batch.dropped > 0 then
    queue.lost = queue.lost + batch.dropped
    ctx.diag("events.dropped", "the game's event queue overflowed: " .. batch.dropped .. " event(s) were dropped (the Titan frame is not draining it)")
  end
  local okf, err = pcall(env.FPF.forwarded, batch)
  if not okf then ctx.diag("events.forwarded", "handling the game's events failed: " .. tostring(err)) end
end

-- ------------------------------------------------------------------ the overlay ----------------------------------------
-- The controller's overlay (FPF.drawFrame) and the HUD page's state (hud.frame) are drawn every game frame, and with no Titan anywhere
-- they cost a tenth of the controller's frame to draw nothing (measured 2026-11-04: 10.8 us of Lua for the overlay's own calls). The
-- controller says whether it is idle (FPF.idleOk: no BT in the world or in flight, nothing of BT's left to draw, asked after its own
-- update); a controller that does not know the question is never idle. While it is, and no other player's Titan is drawn here
-- (observer.draw is the overlay's too), neither runs.
local function overlay_idle(env)
  local idleOk = env.FPF.idleOk
  if idleOk == nil or observer.count > 0 then return false end
  local ok, yes = pcall(idleOk)
  if ok then return yes == true end
  ctx.diag(is_time_cut(yes) and "idle.cut" or "idle", "the controller could not say whether it is idle: the overlay is drawn: " .. tostring(yes))
  return false
end

-- What the overlay left behind is taken away once, when it stops: the canvas is given one empty frame (the page keeps the last one it
-- got) and the HUD page is cleared (when it shows anything); after that an idle frame calls nothing of the render module.
local function overlay_release()
  hud.clear()
  if ctx.drawn then
    ctx.drawn = false
    render.beginFrame()
    render.endFrame()
  end
end

-- While the controller is idle and the bridge has nothing of its own in flight, the frame's events, the controller's update (with the
-- bridge's tick) and the overlay's pass run ten times a second, with the time of the frames in between: run every frame they were
-- ~80 us of Lua per frame for a player who has no Titan (measured 2026-11-04, after the controller's own idle path). A message
-- from the server (a grant, a command, the session's keepalive) or a menu runs the frame at once; a key the player presses waits
-- in the forwarder's queue (it holds 256 actions) for 0.1 s at most.
local IDLE_EVERY = 0.1

-- An event the controller queued for later (FPF.later) keeps the frames coming: the throttled idle frame would hold it back.
local function bridge_quiet()
  return ctx.titan == nil and ctx.request == nil and ctx.queued == nil and ctx.releases[1] == nil and next(ctx.scripted) == nil
    and ctx.menus.queue[1] == nil and observer.count == 0 and carry.c == nil and carry.outbox[1] == nil and next(carry.late) == nil
    and grab.state == "idle" and not ctx.env.FPF.laterPending()
end

-- One controller frame. The resource calls it once per game frame with the seconds since the last one.
function M.frame(delta)
  local env = ctx.env
  if not env then return end
  local handled = ctx.handled
  local okc, errc = pcall(start_commands)
  if not okc then ctx.diag("commands", "the commands of the frame's start could not be run: " .. tostring(errc)) end
  if ctx.idle and ctx.handled == handled and bridge_quiet() then
    local waited = ctx.idleWait + delta
    if waited < IDLE_EVERY then
      ctx.idleWait = waited
      return
    end
  end
  delta, ctx.idleWait = delta + ctx.idleWait, 0.0
  apply_menus(env)
  drain_events(env)
  env.FPF.update(delta)
  local okl, errl = pcall(env.FPF.laterFlush)
  if not okl then ctx.diag("later", "the controller's delayed events could not be sent: " .. tostring(errl)) end
  local idle = overlay_idle(env)
  ctx.idle = idle
  if not render then return end
  if idle then return overlay_release() end
  ctx.drawn = true
  render.beginFrame()
  local ok, err = pcall(env.FPF.drawFrame)
  render.endFrame()
  hud.frame()
  if not ok then ctx.diag("draw", "the controller's overlay failed: " .. tostring(err)) end
end

function M.status()
  return status_line()
end

-- What the grab key shows now (ctx.grabUi: the HUD reads it from the context itself); the tests read it here.
function M.grabUi()
  return ctx.grabUi
end

-- The controller's file-local entry points, handed over once at the end of its file.
function M.attach(env)
  for _, name in ipairs(REQUIRED_ENV) do
    if env[name] == nil then error("controller entry point missing: " .. name, 0) end
  end
  for _, name in ipairs(REQUIRED_FPF) do
    if env.FPF[name] == nil then error("controller function FPF." .. name .. " missing: this is not the supported release", 0) end
  end
  for _, name in ipairs(gameplayMod.REQUIRED_FPF) do
    if env.FPF[name] == nil then error("controller function FPF." .. name .. " missing: this is not the supported release", 0) end
  end
  if not schema.catalog then error("catalog unavailable: " .. tostring(schema.catalogError), 0) end
  if not loadout then error("loadout unavailable: " .. tostring(schema.loadoutError), 0) end
  local perk = env.FPC.perk
  if type(perk) ~= "table" or type(perk.fact) ~= "string" or type(perk.gunFact) ~= "string" then
    error("the controller's Titan level facts are missing: this is not the supported release", 0)
  end
  ctx.env = env
  ctx.clock, ctx.titan, ctx.request, ctx.queued, ctx.releases = 0.0, nil, nil, nil, {}
  ctx.scripted, ctx.results, ctx.vehicleQueue, ctx.vehicleAt, ctx.playerQueue = {}, {}, {}, 0.0, {}
  ctx.npcQueue, ctx.npcRoundAt, ctx.npcRoundN = {}, {}, 0
  ctx.session.active, ctx.session.player, ctx.session.lastAt = false, nil, 0.0
  ctx.pvp, ctx.drawn, ctx.backlog = false, true, false
  ctx.idle, ctx.idleWait = false, 0.0
  ctx.levels, ctx.revision, ctx.weaponFact = loadout.defaults(), 0, 0
  ctx.gunFact, ctx.perkFacts = perk.gunFact, {}
  for id in pairs(loadout.max) do ctx.perkFacts[perk.fact .. id] = id end
  capture.reset()
  observer.clear("attached")
  -- This VM has spawned nothing yet. Entities a previous one tagged (a resource restart: the client cannot call the
  -- game at stop) belong to no Titan any more and would stay in the world; delete them before anything is spawned.
  for _, tag in ipairs({ env.TAG, env.FPC.decoy.tag, observerMod.TAG }) do
    pcall(function() Game.GetDynamicEntitySystem():DeleteTagged(tag) end)
  end
  -- A previous controller in this client (the resource was restarted while V's body was hidden) left V's meshes off and V locked
  -- (FPF.hideV records what it switched off outside the controller's state, M.rememberHidden): hand the controller that record
  -- and its own interrupted-session cleanup, which switches the meshes back on, takes off the restrictions and the god mode, ends
  -- the workspot, puts the camera back and deletes the tagged entities once the game is running again, 2 s after.
  local okh, record = pcall(function() return Open77.kvp.get(HIDDEN_KEY) end)
  if okh and type(record) == "string" and record ~= "" then
    local okd, decoded = pcall(json.decode, record)
    if okd and type(decoded) == "table" then
      env.PS.vHidden = decoded
      env.S.cleanup, env.S.cleanupAt = true, nil
      ctx.log("a previous controller left V hidden: its leftovers are undone in 2 s")
    else
      pcall(Open77.kvp.delete, HIDDEN_KEY)
      ctx.diag("hidden.restore", "V's hidden-body record of a previous controller could not be read and was dropped")
    end
  end
  carry.attach(env)
  combat.install()
  grab.attach(env)

  local FPF = env.FPF

  -- The controller's own reads of its level facts and of its gun fact are answered from memory; every other fact is the game's.
  local factGet = FPF.factGet
  FPF.factGet = function(name)
    local id = ctx.perkFacts[name]
    if id ~= nil then return ctx.levels[id] end
    if name == ctx.gunFact then return ctx.weaponFact end
    return factGet(name)
  end
  -- The controller's forced ragdoll and its impulse, on an Open77 body only when the controller names it (see "bodies Open77
  -- drives").
  local ragdoll = FPF.ragdoll
  FPF.ragdoll = function(ent, ...)
    local kind = owned_body(ent)
    if kind ~= nil and not carried(ent) and not asked_npc(ent, kind) then
      spare("a ragdoll", kind)
      return false
    end
    return ragdoll(ent, ...)
  end
  local update = FPF.update
  FPF.update = function(delta)
    local okc, errc = pcall(update, delta)
    -- A time-limit cut has a key of its own: under one shared key the first cut silenced every later, real failure.
    if not okc then ctx.diag(is_time_cut(errc) and "update.cut" or ("update." .. tostring(errc)), "the controller's frame update failed: " .. tostring(errc)) end
    local ok, err = pcall(M.tick, delta)
    if not ok then ctx.diag(is_time_cut(err) and "tick.cut" or ("tick." .. tostring(err)), "the Titan bridge failed in its frame update: " .. tostring(err)) end
  end

  local callBt = FPF.callBt
  FPF.callBt = function(by)
    if not ctx.session.active or ctx.allowSpawn then return callBt(by) end
    if ctx.titan and titan_present() then return callBt(by) end   -- a local re-call of a Titan this player holds
    if ctx.titan then return spawn_local(by) end
    if ctx.request and ctx.clock - ctx.request.at < REQUEST_WAIT then
      ctx.log("the call is already waiting for the server")
      return false
    end
    ctx.request = { action = "spawn", at = ctx.clock, by = by }
    return request("spawn")
  end
  ctx.log("attached to the controller " .. tostring(env.VERSION))
end

return M
