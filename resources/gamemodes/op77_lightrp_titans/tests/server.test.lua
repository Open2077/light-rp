-- op77_lightrp_titans: server authority and protocol invariants.
--
-- Loads the REAL shared.lua and server.lua against a fake platform (events,
-- players, visibility, clock) and drives them through the same handlers the
-- host calls. It asserts ownership, epoch, sequence replay, validation, rate and
-- size caps, late join without stale events, visibility restoration and every
-- lifecycle exit. It does not prove the controller itself (client.test.lua takes its schema's side of the wire; the bridge and
-- the controller are live acceptance) or two real clients; those are live acceptance.
--
-- The Physical carry section drives the claim lifecycle against a fake Open77.npcs /
-- Open77.vehicles that keeps the platform's contract (one claim per body and per
-- carrier, a token per claim, idempotent end): identity binding, the grant and every
-- refusal, reach, sequencing and the hand/flight envelopes, the newest-first release, a thrown person's release
-- descriptor (fixed by its first flight message, repeated by every later one, refused when missing or changed),
-- budgets, watchdogs, every Titan exit, platform failures and diagnostics. It does not
-- prove the native Carried projection or a real two-client throw; that is live acceptance.
--
-- The loadout section drives the five server exports (getLoadoutSpec, spawn, remove, getLoadout,
-- setLoadout) against the real loadout.lua: the full default of every spawn route, sparse changes
-- and per-Titan revisions, refusals that leave no trace, copies, lifecycle and scope isolation, and
-- the policy this file applies itself (sentry: grab, shoulder and the carry claim; burstcore: the
-- core action), including the claim state the fake platform actually holds.
--
-- The server-controls section drives the `command` and `getState` exports: exact verb/value vocabulary and
-- no send or budget spent on a bad call, no_titan / not_active, the same loadout and fist admission as /titan, a
-- dispatched command (true means sent, not performed), a failed send (owner_unavailable), the shared command
-- budget, and a getState copy that shares nothing with the Titan's record and holds no health of the server's own (only
-- the owner's last accepted gameplay report, in the gameplay section below).
--
-- The input section drives `input` and `releaseInput`: the exact vocabulary and ranges (the same ones the client's
-- validator enforces), a refusal that sends and spends nothing, the Titan admission (no_titan, not_active,
-- not_piloting), delivery to the owner alone under the Titan's own id and epoch with no command budget, and no client
-- door. The controller's side of it is live acceptance (client.test.lua proves the schema's side of the wire).
--
-- The gameplay section drives frame.gameplay (the closed bounded schema, the last accepted copy, a refused report never
-- recorded, never relayed to viewers), the `hit` / `repair` exports (validation before any side effect, numbering and
-- the pending bound, the owner as the only recipient, no client door, an answer settling its request once, a timeout and
-- a teardown ending every request exactly once) and the lifecycle events (created, ready, mode changed, destroyed and
-- removed, once each, on accepted edges only).
--
-- The observed-hit section drives hit_observed (the owner's report that its Titan landed a blow on another player's Titan):
-- the source is the sender's own current, published Titan and epoch; the target is another player's current, published Titan
-- by exact id, epoch and owner that the sender can see; malformed input is refused whole and costs no sequence; a repeat is
-- ignored while newest-first arrivals are all taken, inside a bounded window; a per-Titan budget of its own is spent before
-- parsing; and each accepted report is published exactly once as the host event onTitanHitObserved as a detached copy, with
-- nothing sent, requested or answered. It does not prove a real two-client scope or the controller's own observation.
--
-- The observed-status section is the same for a status effect the owner's controller's own calls would apply to another
-- player's Titan (status_observed on its own event): the same source and target rule, ONE budget and ONE sequence window shared
-- with the hits (numbers interleave, a number is used once whichever kind took it), a closed schema whose duration is optional
-- and never invented, each accepted observation published exactly once as onTitanStatusObserved, and nothing applied.
--
-- The core-credit section drives the `creditCore` export (a confirmed Titan hit or kill, credited as authored core charge by the
-- owner's controller): validation before anything is looked up or sent, the victim named by identity only (it may already be
-- gone), the same numbering, pending bound and send discipline as hit and repair, no client door, an answer of its own kind
-- settling it once (0 taken, a refusal's word, a stranger's or another kind's answer ignored), and a timeout and a teardown
-- ending it exactly once.
--
-- The blows-on-players section proves that the owner's `player_hit` (a victim, an attack record and a count: never an amount) is
-- priced by the server per record, admitted only for another living player in the sender's bucket within reach of the Titan's
-- pose, applied with Open77.players.damage under pvp = true (the platform's PvP rules decide, a refusal is counted and logged),
-- refused whole when malformed, and shares the observations' one budget and sequence; setPlayerDamage / playerDamage change and
-- read the price. The lifecycle section adds the scripted death (a teleport keeps an unpiloted Titan), the launch exemption the
-- weapons resource is given while the owner pilots, `/titan log`, the counters of `/titan status` and the log's one line per
-- ignored blow. A wreck is carried like any car, and a car in the hand has the platform's own velocity bound. The titan.core section
-- proves the restricted command that fills the BURST CORE (registered restricted, never a /titan verb or an export, admitted like the
-- core key, the console naming the player) and the message it sends.
--
-- The restart-handshake section proves how a server-only restart (a new VM of this resource while the clients and their
-- controllers keep running) rediscovers them: the resource's own start sends one probe to every client, a client's answer
-- introduces it exactly as its cold start would (a Titan can be granted again), and an answer never touches a client the run
-- already knows nor destroys a Titan, while a plain ready still takes the owner_restarted exit.
--
-- The Titan PvP section proves the `setTitanPvp` / `titanPvp` pair: off by default, a boolean only (anything else is refused with
-- invalid_value and tells nobody), carried in the `session` message to every client with a bridge on each change and to every
-- session at its start, never to a client without one, and no client message or Titan state of it.
--
-- Run from this resource's directory with any Lua 5.4 (from elsewhere, pass the resource's directory with its trailing slash):
--   lua tests/server.test.lua
local root = ... or "./"
local passed = 0
local report = print
print = function() end   -- the resource logs every lifecycle edge

local function test(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ": " .. tostring(err))
    passed = passed + 1
    report("PASS " .. name)
end

-- ---------------------------------------------------------------------------
-- Fake platform.
-- ---------------------------------------------------------------------------
local now = 1000
local sent, handlers, commands = {}, {}, {}
local restricted = {}                       -- [command name] = RegisterCommand's third argument (the platform's ACL gate)
local players, observers, visible, visibleCalls = {}, {}, {}, {}
local visibleFailure
local lifeStates = {}                       -- [id] = what Open77.players.getLifeState answers (nil: nothing known)
local damageCalls, damageRefusal = {}, nil  -- Open77.players.damage: { id, amount, options } in order, and an optional refusal
local exportCalls, exportFailure = {}, nil  -- Open77.exports.callSync: { target, name, args } in order, and an optional raise
local sendFails

local function encode(value)
    if type(value) == "table" then
        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local parts = {}
        for _, key in ipairs(keys) do parts[#parts + 1] = string.format("%q:%s", tostring(key), encode(value[key])) end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif type(value) == "string" then
        return string.format("%q", value)
    end
    return tostring(value)
end
json = { encode = encode }

Open77 = {
    time = { monotonic = function() return now end, unix = function() return 1700000000 end },
    players = {
        get = function(id)
            local player = players[id]
            if not player then return nil, "player_not_found" end
            return player
        end,
        isDead = function(id) local player = players[id]; return player ~= nil and player.dead == true end,
        getLifeState = function(id) return lifeStates[id] end,
        damage = function(id, amount, options)
            damageCalls[#damageCalls + 1] = { id = id, amount = amount, options = options }
            if damageRefusal then return false, damageRefusal end
            return true
        end,
        observers = function(id) return observers[id] or { id } end,
        isVisible = function(id) if visible[id] == nil then return true end return visible[id] end,
        setVisible = function(id, value)
            visibleCalls[#visibleCalls + 1] = { id, value }
            if visibleFailure then return false, visibleFailure end
            visible[id] = value
            return true
        end,
    },
    -- The synchronous cross-resource call RAISES when the callee is missing, as the platform's does.
    exports = {
        callSync = function(target, name, ...)
            exportCalls[#exportCalls + 1] = { target = target, name = name, args = table.pack(...) }
            if exportFailure then error(exportFailure, 0) end
            return true
        end,
    },
}
-- The resource's persistent store (Open77.kvp): survives a simulated restart.
local kvpStore, kvpFail = {}, false
Open77.kvp = {
    increment = function(key, delta)
        if kvpFail then return false, "storage_write_failed" end
        kvpStore[key] = (kvpStore[key] or 0) + (delta or 1)
        return kvpStore[key]
    end,
}
-- SetTimeout(0, fn) runs on the host's NEXT pass, after every delivery of this one.
local timers = {}
function SetTimeout(ms, fn) timers[#timers + 1] = { ms = ms, fn = fn } end
local function runTimers()
    local due = timers
    timers = {}
    for _, timer in ipairs(due) do timer.fn() end
end
function GetCurrentResourceName() return "op77_lightrp_titans" end
function RegisterNetEvent(name, fn) handlers[name] = handlers[name] or {}; handlers[name][#handlers[name] + 1] = fn end
AddEventHandler = RegisterNetEvent
function RegisterCommand(name, fn, gated) commands[name] = fn; restricted[name] = gated end
function CreateThread() end
function Wait() end
function TriggerClientEvent(name, target, ...)
    if sendFails then return false end   -- the target is not a player any more
    sent[#sent + 1] = { name = name, target = target, args = { ... } }
    return true
end
-- Host-local events the resource raised (TriggerEvent): { name, args = table.pack(...) }.
local events = {}
function TriggerEvent(name, ...)
    events[#events + 1] = { name = name, args = table.pack(...) }
    return true
end
-- Cancellable host events: the verdict handle answers nil, "pending" until the host's next tick (`settleVerdicts`), then whether
-- a script vetoed the event (the event record's `vetoed`, which a test sets as a handler's CancelEvent() would).
local verdictsFail
function TriggerCancellableEvent(name, ...)
    if verdictsFail then return nil, verdictsFail end
    local event = { name = name, args = table.pack(...), cancellable = true, settled = false, vetoed = false }
    events[#events + 1] = event
    return setmetatable({}, { __index = {
        canceled = function() if not event.settled then return nil, "pending" end return event.vetoed end,
        status = function() return event.settled and "settled" or "pending" end,
    } })
end
local function settleVerdicts()
    for _, event in ipairs(events) do
        if event.cancellable then event.settled = true end
    end
end
local function eventsNamed(name)
    local list = {}
    for _, event in ipairs(events) do
        if event.name == name then list[#list + 1] = event.args end
    end
    return list
end
local function fire(name, who, ...)
    source = who
    for _, fn in ipairs(handlers[name] or {}) do fn(...) end
    source = nil
end
-- The client's encoders (TriggerServerEvent, Open77.json.encode) count every table
-- key as well as every value against a limit of 1024.
local function keyed(value)
    if type(value) ~= "table" then return 1 end
    local nodes = 1
    for _, child in pairs(value) do nodes = nodes + 1 + keyed(child) end
    return nodes
end

Open77TitanCatalog = {
    variables = { bt_speed = true, bt_turn = true },
    meshes = { mesh_gun = true }, lights = { light_eye = true },
    effects = { ["base\\fx\\muzzle.effect"] = true }, attachedEffects = { thruster = true },
    sounds = { bt_step = true }, slots = { hand_l = true },
}
dofile(root .. "loadout.lua")
dofile(root .. "shared.lua")
-- The server runtime's exports(name, fn) registry: publishing a name again replaces it.
local exported = {}
exports = setmetatable({}, { __call = function(_, name, fn)
    if type(name) ~= "string" or type(fn) ~= "function" then return nil, "invalid_export_name" end
    exported[name] = fn
    return true
end })
dofile(root .. "server.lua")
local T, S = Open77Titans, Open77TitansServer
local MSG = T.event.message

-- What the host does with the frames that arrive in one tick: its scheduler drains
-- the delivery tasks from the tail, so the NEWEST runs first.
local function arrive(who, frames)
    source = who
    for index = #frames, 1, -1 do handlers[T.event.frame][1](frames[index]) end
    source = nil
end

-- ---------------------------------------------------------------------------
-- Fixtures.
-- ---------------------------------------------------------------------------
local function clear(tbl) for key in pairs(tbl) do tbl[key] = nil end end

local function reset()
    runTimers()
    for _, titan in pairs(S.titans) do S.removeTitan(titan, "owner_removed") end
    clear(S.clients); clear(S.hides); clear(visible); clear(visibleCalls); clear(sent); clear(observers); clear(events)
    clear(lifeStates); clear(damageCalls); clear(exportCalls)
    visibleFailure, damageRefusal, exportFailure = nil, nil, nil
    sendFails = nil
    for id = 1, 3 do
        players[id] = { ready = true, fresh = true, position = { x = 0, y = 0, z = 0 }, bucket = 0, dead = false }
    end
    now = now + 100
end

local function ready(player, bridge)
    now = now + 2
    fire(T.event.ready, player, { bridge = bridge ~= false, reason = bridge == false and "bridge_missing" or nil })
end

local function command(player, ...)
    commands.titan(player, table.pack(...), "titan")
end

local function spawn(player)
    command(player, "spawn")
    return S.titans[player]
end

-- Messages the server addressed to `target` on the bridge event, optionally one op.
local function messages(target, op)
    local list = {}
    for _, event in ipairs(sent) do
        local message = event.args[1]
        if event.name == MSG and event.target == target and (op == nil or message.op == op) then
            list[#list + 1] = message
        end
    end
    return list
end

local function lastReply(player)
    for index = #sent, 1, -1 do
        local event = sent[index]
        if event.name == "open77:command:result" and event.target == player then return event.args end
    end
end

local function frame(titan, seq, extra)
    local body = {
        v = T.protocol, op = "frame", id = titan.id, epoch = titan.epoch, seq = seq, t = seq * 0.05,
        pose = { x = 0, y = 0, z = 0, yaw = 0 }, mode = "wait", weapon = "xo16",
        vars = { bt_speed = 0.5 }, meshes = { mesh_gun = true }, lights = { light_eye = false },
        visuals = {}, events = {},
    }
    for key, value in pairs(extra or {}) do body[key] = value end
    return body
end

local seqOf = setmetatable({}, { __mode = "k" })
-- Publishes the next frame for `titan` as its owner and returns accept's result.
local function publish(titan, extra)
    seqOf[titan] = (seqOf[titan] or 0) + 1
    now = now + 0.05
    local ok, reason = S.acceptFrame(titan.owner, frame(titan, seqOf[titan], extra))
    if not ok then seqOf[titan] = seqOf[titan] - 1 end
    return ok, reason
end

local function shot(seq, fxId)
    return { kind = "fx_spawn", seq = seq, fxId = fxId or ("f" .. seq), path = "base\\fx\\muzzle.effect",
        position = { x = 1, y = 2, z = 3 } }
end

local function withViewers(...)
    for _, viewer in ipairs({ ... }) do ready(viewer) end
end

-- ---------------------------------------------------------------------------
-- Authority: who may create, publish and command.
-- ---------------------------------------------------------------------------
test("grant is server-created, owned by the authenticated caller, one per player", function()
    reset(); ready(1)
    local titan = spawn(1)
    assert(titan and titan.owner == 1 and titan.epoch == 1 and T.isId(titan.id))
    local grant = messages(1, "grant")[1]
    assert(grant and grant.id == titan.id and grant.owner == "1" and grant.epoch == 1)
    assert(messages(1, "command")[1].action == "spawn", "/titan spawn must also command the spawn")
    command(1, "spawn")
    assert(lastReply(1)[2] == false and S.titans[1] == titan, "a second Titan was created")
    assert(not S.spawnTitan(1, true))
    commands.titan(0, table.pack("spawn"), "titan")
    assert(S.titans[0] == nil, "the console must not own a Titan")
end)

test("a client without a working bridge cannot spawn and is told why", function()
    reset(); ready(1, false)
    command(1, "spawn")
    assert(S.titans[1] == nil and lastReply(1)[2] == false)
    ready(2)
    players[2].dead = true
    command(2, "spawn")
    assert(S.titans[2] == nil, "a dead player got a Titan")
    players[2].dead = false; players[2].fresh = false
    command(2, "spawn")
    assert(S.titans[2] == nil, "a player with no fresh position got a Titan")
end)

test("only the owner's connection can publish for its id, epoch and sequence", function()
    reset(); ready(1); ready(2)
    local a = spawn(1)
    assert(publish(a))
    -- Another player has no Titan; naming A's id changes nothing.
    fire(T.event.frame, 2, frame(a, 99))
    assert(S.titans[1].seq == 1 and S.titans[2] == nil)
    local b = spawn(2)
    assert(not S.acceptFrame(2, frame(a, 99)), "B published A's id")
    local _, why = S.acceptFrame(2, frame(b, 1, { epoch = 2 }))
    assert(why == "stale_epoch", why)
    _, why = S.acceptFrame(1, frame(a, 2, { id = "42" }))
    assert(why == "stale_id", why)
    _, why = S.acceptFrame(1, frame(a, 1))
    assert(why == "stale_seq", "replay of an accepted sequence: " .. tostring(why))
    _, why = S.acceptFrame(1, frame(a, 0))
    assert(why == "stale_seq", why)
    now = now + 0.05
    assert(S.acceptFrame(1, frame(a, 5)), "gaps are legal")
    assert(a.seq == 5)
end)

test("a rejected frame never advances the sequence, time or events cursor", function()
    reset(); ready(1)
    local titan = spawn(1)
    assert(publish(titan))
    now = now + 0.05
    local ok, why = S.acceptFrame(1, frame(titan, 2, { vars = { bt_speed = 0 / 0 } }))
    assert(not ok and why == "vars_value", why)
    ok, why = S.acceptFrame(1, frame(titan, 2, { vars = { not_in_catalog = 1 } }))
    assert(not ok and why == "vars_unknown", why)
    assert(titan.seq == 1 and titan.eventSeq == 0)
    now = now + 0.05
    assert(S.acceptFrame(1, frame(titan, 2, { events = { shot(7) } })))
    assert(titan.seq == 2 and titan.eventSeq == 7)
    now = now + 0.05
    ok, why = S.acceptFrame(1, frame(titan, 3, { t = 0.01 }))
    assert(not ok and why == "stale_time", why)
end)

-- ---------------------------------------------------------------------------
-- Validation and caps.
-- ---------------------------------------------------------------------------
test("frame fields are checked against the catalog, ranges and fixed caps", function()
    reset(); ready(1)
    local titan = spawn(1)
    local function refused(extra, token)
        local ok, why = publish(titan, extra)
        assert(not ok and why == token, tostring(why) .. " (wanted " .. token .. ")")
    end
    refused({ pose = { x = 0, y = 0, z = 0, yaw = math.huge } }, "pose_invalid")
    refused({ pose = { x = 2e6, y = 0, z = 0, yaw = 0 } }, "pose_invalid")
    refused({ pose = { x = 0, y = 0, z = 0, yaw = 0, extra = 1 } }, "pose_invalid")
    refused({ mode = "flying" }, "frame_mode")
    refused({ weapon = "laser" }, "frame_weapon")
    refused({ meshes = { mesh_gun = 1 } }, "meshes_value")
    refused({ meshes = { other = true } }, "meshes_unknown")
    refused({ lights = { light_eye = true, other = true } }, "lights_unknown")
    refused({ events = {} , bogus = true }, "frame_keys")
    refused({ op = "state" }, "frame_op")
    -- 65 catalogued variables: the fixed cap of 64 must refuse before any name is trusted.
    local many = {}
    for index = 1, 70 do Open77TitanCatalog.variables["v" .. index] = true end
    for index = 1, 65 do many["v" .. index] = 1 end
    refused({ vars = many }, "vars_count")
    for index = 1, 70 do Open77TitanCatalog.variables["v" .. index] = nil end
    local events = {}
    for index = 1, 25 do events[index] = shot(index) end
    refused({ events = events }, "events_count")
    local visuals = {}
    for index = 1, 33 do visuals[index] = { kind = "attached", name = "thruster" } end
    refused({ visuals = visuals }, "visuals_count")
    assert(titan.accepted == 0)
    events = {}
    for index = 1, 24 do events[index] = shot(index) end
    assert(publish(titan, { events = events }), "24 events is the contract maximum")
end)

test("one bad event or visual is dropped and reported, never relayed, and costs no motion", function()
    reset(); ready(1); ready(2)
    local titan = spawn(1)
    observers[1] = { 1, 2 }
    assert(publish(titan)); S.reconcile(titan)
    clear(sent)
    local bad = shot(2); bad.path = "base\\fx\\not_in_catalog.effect"
    local good = shot(3)
    local extra = shot(4); extra.cmd = "os.execute"
    assert(publish(titan, { events = { shot(1), bad, good, extra },
        visuals = { { kind = "attached", name = "nope" }, { kind = "attached", name = "thruster" } } }))
    local state = messages(2, "state")[1]
    assert(#state.events == 2 and state.events[1].seq == 1 and state.events[2].seq == 3)
    assert(#state.visuals == 1 and state.visuals[1].name == "thruster")
    local errors = messages(1, "error")
    assert(#errors == 1 and errors[1].reason == "event_rejected:attached_name", errors[1] and errors[1].reason)
    assert(titan.eventSeq == 3)
    clear(sent)
    now = now + 1
    assert(publish(titan, { events = { shot(5, "g"), { kind = "fx_stop", seq = 6, fxId = "g", extra = 1 } } }))
    assert(#messages(1, "error") == 0, "reports are limited to one per 5 s")
end)

test("event sequence is strictly increasing and replays are never delivered", function()
    reset(); ready(1); ready(2)
    local titan = spawn(1)
    observers[1] = { 1, 2 }
    assert(publish(titan)); S.reconcile(titan)
    clear(sent)
    assert(publish(titan, { events = { shot(1), shot(2), shot(2, "dup"), shot(1, "old") } }))
    local state = messages(2, "state")[1]
    assert(#state.events == 2, "same-frame duplicates and reordering")
    clear(sent)
    assert(publish(titan, { events = { shot(2, "again"), shot(3) } }))
    state = messages(2, "state")[1]
    assert(#state.events == 1 and state.events[1].seq == 3, "an event older than the cursor was replayed")
    assert(S.stats.eventsReplayed >= 1)
end)

test("per-Titan event budget and frame rate are enforced", function()
    reset(); ready(1); ready(2)
    local titan = spawn(1)
    observers[1] = { 1, 2 }
    assert(publish(titan)); S.reconcile(titan)
    -- The next take sees a clock behind the bucket: it re-anchors and never mints tokens.
    titan.events.tokens, titan.events.at = 2, now + 10
    clear(sent)
    assert(publish(titan, { events = { shot(1), shot(2), shot(3), shot(4) } }))
    local state = messages(2, "state")[1]
    assert(#state.events == 2 and titan.eventSeq == 4, "budget must drop the excess and consume its sequences")
    -- Six frames in one instant exceed the burst of five.
    reset(); ready(1)
    titan = spawn(1)
    local accepted, limited = 0, 0
    for index = 1, 8 do
        local ok, why = S.acceptFrame(1, frame(titan, index))
        if ok then accepted = accepted + 1 elseif why == "rate_limited" then limited = limited + 1 end
    end
    assert(accepted == 5 and limited == 3, accepted .. "/" .. limited)
    -- A byte budget refuses a frame the bucket cannot pay for.
    now = now + 1
    titan.bytes.tokens, titan.bytes.at = 10, now + 10
    local _, why = S.acceptFrame(1, frame(titan, 20))
    assert(why == "bandwidth_limited", why)
end)

test("a frame over the byte cap is refused whole; time and range are bounded", function()
    reset(); ready(1)
    local titan = spawn(1)
    -- 64 catalogued variables with 500-character names: inside every count cap,
    -- but over the 30720-byte frame cap.
    local big = {}
    for index = 1, 64 do
        local name = string.format("%03d", index) .. string.rep("x", 500)
        Open77TitanCatalog.variables[name] = true
        big[name] = 1
    end
    local ok, why = publish(titan, { vars = big })
    assert(not ok and why == "frame_bytes", tostring(why))
    assert(titan.accepted == 0 and titan.seq == 0)
    for name in pairs(big) do Open77TitanCatalog.variables[name] = nil end
    ok, why = publish(titan, { t = 1e12 })
    assert(not ok and why == "frame_time", why)
    local events = {}
    for index = 1, 24 do
        local event = shot(index)
        event.fxId = string.rep("a", 48)
        events[index] = event
    end
    assert(publish(titan, { events = events }), "24 maximal events fit under the caps")
end)

test("Titan root movement is admitted near the owner and only at plausible speed", function()
    reset(); ready(1)
    local titan = spawn(1)
    local ok, why = publish(titan, { pose = { x = 400, y = 0, z = 0, yaw = 0 } })
    assert(not ok and why == "pose_far", why)
    assert(publish(titan, { pose = { x = 20, y = 0, z = 0, yaw = 0 } }))
    ok, why = publish(titan, { pose = { x = 520, y = 0, z = 0, yaw = 0 } })
    assert(not ok and why == "pose_jump", why)
    assert(publish(titan, { pose = { x = 25, y = 0, z = 0, yaw = 90 } }))
    assert(titan.poseViolations == 0)
    for _ = 1, 59 do publish(titan, { pose = { x = 900, y = 0, z = 0, yaw = 0 } }) end
    assert(S.titans[1] == titan)
    publish(titan, { pose = { x = 900, y = 0, z = 0, yaw = 0 } })
    assert(S.titans[1] == nil, "a persistently impossible pose must release the Titan")
    assert(messages(1, "remove")[1].reason == "pose_rejected")
end)

-- ---------------------------------------------------------------------------
-- Relay, scope and late join.
-- ---------------------------------------------------------------------------
test("only in-scope players with a bridge receive the accepted frame; never the owner", function()
    reset(); withViewers(1, 2); ready(3, false)
    local titan = spawn(1)
    observers[1] = { 1, 2, 3 }
    assert(publish(titan)); S.reconcile(titan)
    clear(sent)
    assert(publish(titan, { events = { shot(1) }, mode = "pilot", vars = { bt_speed = 0.75 } }))
    local state = messages(2, "state")[1]
    assert(state and state.id == titan.id and state.epoch == 1 and state.owner == "1" and state.seq == 2)
    assert(state.mode == "pilot" and state.vars.bt_speed == 0.75 and #state.events == 1 and state.serverTime)
    assert(#messages(1, "state") == 0 and #messages(3, "state") == 0)
    assert(state.v == T.protocol and state.op == "state")
end)

test("late join gets the latest persistent state with no events, then only new ones", function()
    reset(); withViewers(1, 2, 3)
    local titan = spawn(1)
    observers[1] = { 1, 2 }
    assert(publish(titan)); S.reconcile(titan)
    assert(publish(titan, { events = { shot(1), shot(2) },
        visuals = { { kind = "attached", name = "thruster" } }, vars = { bt_speed = 0.9 } }))
    clear(sent)
    observers[1] = { 1, 2, 3 }
    fire("onPlayerEnteredScope", nil, "1", "3", "interest")
    local joined = messages(3, "state")
    assert(#joined == 1, "the late joiner must be sent state at once")
    assert(#joined[1].events == 0, "old shots must never be replayed")
    assert(joined[1].vars.bt_speed == 0.9 and #joined[1].visuals == 1 and joined[1].seq == 2)
    clear(sent)
    assert(publish(titan, { events = { shot(2, "replay"), shot(3) } }))
    assert(#messages(3, "state")[1].events == 1 and messages(3, "state")[1].events[1].seq == 3)
    -- Out of scope: told to drop the remote, and no further state.
    clear(sent)
    observers[1] = { 1, 2 }
    fire("onPlayerLeftScope", nil, "1", "3", "interest")
    local removed = messages(3, "remove")
    assert(#removed == 1 and removed[1].reason == "out_of_scope" and removed[1].id == titan.id)
    clear(sent)
    assert(publish(titan))
    assert(#messages(3, "state") == 0 and #messages(2, "state") == 1)
end)

test("a viewer whose bridge comes up later receives the existing Titan", function()
    reset(); ready(1)
    local titan = spawn(1)
    observers[1] = { 1, 2 }
    assert(publish(titan, { vars = { bt_speed = 0.1 } }))
    clear(sent)
    ready(2)
    local joined = messages(2, "state")
    assert(#joined == 1 and #joined[1].events == 0 and joined[1].vars.bt_speed == 0.1)
    assert(#messages(2, "session") == 1 and messages(2, "session")[1].player == "2")
end)

-- ---------------------------------------------------------------------------
-- Visibility of V's network body.
-- ---------------------------------------------------------------------------
test("V's network body is hidden exactly while piloting and restored on every exit", function()
    reset(); ready(1)
    local titan = spawn(1)
    assert(publish(titan, { mode = "wait" }))
    assert(#visibleCalls == 0)
    assert(publish(titan, { mode = "pilot" }))
    assert(#visibleCalls == 1 and visibleCalls[1][2] == false and visible[1] == false)
    assert(publish(titan, { mode = "pilot" }))
    assert(#visibleCalls == 1, "hide must not repeat")
    assert(publish(titan, { mode = "dismount" }))
    assert(#visibleCalls == 2 and visible[1] == true)
    assert(publish(titan, { mode = "pilot" }))
    assert(visible[1] == false)
    S.removeTitan(titan, "owner_removed")
    assert(visible[1] == true and S.hides[1] == nil, "removal while piloting must restore V")
end)

test("a hide this resource did not make is never undone; transient refusals are retried", function()
    reset(); ready(1)
    local titan = spawn(1)
    visible[1] = false
    assert(publish(titan, { mode = "pilot" }))
    assert(#visibleCalls == 0 and S.hides[1] and S.hides[1].ours == false)
    assert(publish(titan, { mode = "wait" }))
    S.removeTitan(titan, "owner_removed")
    assert(#visibleCalls == 0 and visible[1] == false, "somebody else's invisibility was undone")

    reset(); ready(1)
    titan = spawn(1)
    visibleFailure = "transition_in_progress"
    assert(publish(titan, { mode = "pilot" }))
    assert(S.hides[1] and S.hides[1].applied == false)
    visibleFailure = nil
    S.tick()
    assert(visible[1] == false and S.hides[1].applied == true, "tick must retry the hide")

    reset(); ready(1)
    titan = spawn(1)
    visibleFailure = "permission_denied:players.life.visibility"
    assert(publish(titan, { mode = "pilot" }))
    assert(S.hides[1] == nil and messages(1, "error")[1].reason == "visibility_unavailable")
end)

-- ---------------------------------------------------------------------------
-- Lifecycle.
-- ---------------------------------------------------------------------------
local function liveWithViewer()
    reset(); withViewers(1, 2)
    local titan = spawn(1)
    observers[1] = { 1, 2 }
    assert(publish(titan, { mode = "pilot" })); S.reconcile(titan)
    clear(sent)
    return titan
end

local function released(titan, reason)
    assert(S.titans[titan.owner] == nil, "Titan still registered after " .. reason)
    local removed = messages(2, "remove")
    assert(#removed == 1 and removed[1].reason == reason and removed[1].id == titan.id, "viewer not told: " .. reason)
    assert(visible[1] ~= false and S.hides[1] == nil, "V left hidden after " .. reason)
    assert(next(titan.viewers) == nil)
end

test("owner disconnect releases the Titan, viewers, V and the client record", function()
    local titan = liveWithViewer()
    fire("onPlayerDisconnected", nil, "1", "connection_closed")
    released(titan, "owner_left")
    assert(#messages(1, "remove") == 0 and S.clients[1] == nil)
    -- A disconnecting viewer is simply forgotten.
    titan = liveWithViewer()
    fire("onPlayerDisconnected", nil, "2", "connection_closed")
    assert(titan.viewers[2] == nil and S.titans[1] == titan)
end)

test("owner death, bucket change and client restart release the Titan", function()
    local titan = liveWithViewer()
    players[1].dead = true
    fire("onPlayerLifeStateChanged", nil, "1", "9", "dead", "pvp_damage")
    released(titan, "owner_dead")
    assert(messages(1, "remove")[1].reason == "owner_dead")

    titan = liveWithViewer()
    fire("onPlayerBucketChange", nil, "1", 7, 0)
    released(titan, "bucket_changed")

    titan = liveWithViewer()
    players[1].bucket = 5
    S.tick()
    released(titan, "bucket_changed")

    titan = liveWithViewer()
    ready(1)
    released(titan, "owner_restarted")
    assert(#messages(1, "session") >= 1)
end)

test("a stalled owner, a silent controller and a missing player are released by the upkeep tick", function()
    local titan = liveWithViewer()
    now = now + 6
    S.tick()
    released(titan, "owner_stalled")

    reset(); ready(1)
    titan = spawn(1)
    now = now + 5
    S.tick()
    assert(S.titans[1] == titan, "a grant gets time for the controller to load")
    now = now + 16
    S.tick()
    assert(S.titans[1] == nil and messages(1, "remove")[1].reason == "controller_timeout")
    assert(not lastReply(1)[2], "the owner must be told why")

    titan = liveWithViewer()
    players[1] = nil
    S.tick()
    released(titan, "owner_left")
end)

test("resource stop releases every Titan, restores V and ends every session", function()
    local titan = liveWithViewer()
    fire("onResourceStop", nil, "op77_lightrp_titans")
    released(titan, "resource_stopped")
    assert(#messages(1, "remove") == 1)
    assert(#messages(1, "session") == 1 and messages(1, "session")[1].active == false)
    assert(#messages(2, "session") == 1 and messages(2, "session")[1].active == false)
end)

-- ---------------------------------------------------------------------------
-- /titan commands and controller requests.
-- ---------------------------------------------------------------------------
test("/titan routes real controls only to the caller's own active Titan", function()
    reset(); withViewers(1, 2)
    command(1, "pilot")
    assert(lastReply(1)[2] == false and #messages(1, "command") == 0, "no Titan yet")
    local titan = spawn(1)
    clear(sent)
    command(1, "pilot")
    assert(#messages(1, "command") == 0 and lastReply(1)[2] == false, "not active yet")
    assert(publish(titan))
    now = now + 5
    clear(sent)
    command(1, "weapon", "rail")
    command(1, "action", "dash")
    command(1, "pilot")
    command(1, "exit")
    local sentCommands = messages(1, "command")
    assert(#sentCommands == 4)
    assert(sentCommands[1].action == "weapon" and sentCommands[1].value == "rail")
    assert(sentCommands[2].action == "action" and sentCommands[2].value == "dash")
    assert(sentCommands[3].action == "pilot" and sentCommands[3].value == nil and sentCommands[4].action == "exit")
    assert(#messages(2, "command") == 0, "commands are never relayed to another player")
    now = now + 5
    clear(sent)
    for _, args in ipairs({ { "weapon", "laser" }, { "weapon" }, { "action", "os.execute" }, { "action", "dash", "x" },
        { "nonsense" }, { "spawn", "extra" } }) do
        command(1, table.unpack(args))
    end
    assert(#messages(1, "command") == 0 and lastReply(1)[2] == false)
    -- Players cannot reach each other's Titan: the target is never a parameter.
    command(2, "remove")
    assert(S.titans[1] == titan and lastReply(2)[2] == false)
end)

test("commands are rate limited per player", function()
    reset(); ready(1)
    local titan = spawn(1)
    assert(publish(titan))
    clear(sent)
    for _ = 1, 12 do command(1, "view") ; command(1, "action", "view") end
    assert(#messages(1, "command") <= T.limits.commandBurst, #messages(1, "command"))
    assert(lastReply(1)[2] == false)
end)

test("controller requests: spawn grants without a spawn command, remove is idempotent", function()
    reset(); ready(1)
    fire(T.event.request, 1, "spawn")
    local titan = S.titans[1]
    assert(titan and #messages(1, "grant") == 1 and #messages(1, "command") == 0)
    now = now + 2
    fire(T.event.request, 1, "spawn")
    assert(messages(1, "error")[1].reason == "already_spawned")
    now = now + 2
    fire(T.event.request, 1, "remove")
    assert(S.titans[1] == nil and messages(1, "remove")[1].reason == "owner_removed")
    now = now + 2
    clear(sent)
    fire(T.event.request, 1, "remove")
    assert(#messages(1, "error") == 0)
    now = now + 2
    fire(T.event.request, 1, "teleport")
    assert(messages(1, "error")[1].reason == "invalid_request")
    fire(T.event.request, 1, { "spawn" })
    assert(S.titans[1] == nil)
end)

test("the ready report carries only fixed reason codes", function()
    reset()
    now = now + 2
    fire(T.event.ready, 1, { bridge = false, reason = "<script>" })
    assert(S.clients[1].reason == "bridge_missing" and S.clients[1].bridge == false)
    now = now + 2
    fire(T.event.ready, 1, "not a table")
    assert(S.clients[1].bridge == false)
    now = now + 2
    fire(T.event.ready, 0, { bridge = true })
    assert(S.clients[0] == nil, "the console id must never be registered")
end)

-- ---------------------------------------------------------------------------
-- Tick ordering, transport cap, call-down modes, ids.
-- ---------------------------------------------------------------------------
test("frames that arrive together run newest-first on the host; the inbox restores sequence order", function()
    reset(); withViewers(1, 2)
    local titan = spawn(1)
    observers[1] = { 1, 2 }
    assert(publish(titan)); S.reconcile(titan)
    clear(sent)
    now = now + 0.05
    local older = frame(titan, 2, { events = { shot(1) }, pose = { x = 1, y = 0, z = 0, yaw = 0 } })
    local newer = frame(titan, 3, { events = { shot(2), shot(3) }, pose = { x = 2, y = 0, z = 0, yaw = 0 } })
    arrive(1, { older, newer })   -- the host runs `newer` first
    assert(#messages(2, "state") == 0, "nothing may be accepted before the end of the tick")
    assert(#timers == 1, "exactly one flush is scheduled")
    runTimers()
    local states = messages(2, "state")
    assert(#states == 2 and states[1].seq == 2 and states[2].seq == 3, "order of delivery")
    assert(#states[1].events == 1 and states[1].events[1].fxId == "f1")
    assert(#states[2].events == 2 and states[2].events[1].fxId == "f2" and states[2].events[2].fxId == "f3")
    assert(titan.seq == 3 and titan.eventSeq == 3 and S.inbox[1] == nil)
    -- No ordering is promised beyond one tick: a frame older than an accepted one stays refused.
    arrive(1, { frame(titan, 2) })
    runTimers()
    assert(titan.seq == 3 and #messages(2, "state") == 2)
end)

test("the per-owner inbox is bounded, dies with its Titan and is never opened for strangers", function()
    reset(); ready(1); ready(2)
    local titan = spawn(1)
    assert(publish(titan))
    local flood = {}
    for seq = 2, 21 do flood[#flood + 1] = frame(titan, seq) end
    arrive(1, flood)
    assert(#S.inbox[1] == T.limits.inbox, #S.inbox[1])
    runTimers()
    assert(S.inbox[1] == nil and titan.accepted <= 1 + T.limits.frameBurst, titan.accepted)
    arrive(1, { frame(titan, 40) })
    assert(#S.inbox[1] == 1)
    S.removeTitan(titan, "owner_removed")
    assert(S.inbox[1] == nil, "queued frames of a released Titan must go with it")
    runTimers()
    arrive(2, { frame(titan, 41) })
    assert(S.inbox[2] == nil, "a player with no Titan must not allocate anything")
    -- A frame with nothing to order by is refused at once, not queued.
    now = now + 2
    titan = spawn(1)
    arrive(1, { "not a frame", { seq = "x" }, { seq = 0 / 0 } })
    assert(S.inbox[1] == nil and #timers == 0 and titan.rejected == 3, titan.rejected)
end)

test("a frame over the keyed transport cap sheds visuals, then the newest events, never the motion", function()
    reset(); withViewers(1, 2)
    local titan = spawn(1)
    observers[1] = { 1, 2 }
    assert(publish(titan)); S.reconcile(titan)
    clear(sent)
    local vars = {}
    for index = 1, 64 do
        Open77TitanCatalog.variables["w" .. index] = true
        vars["w" .. index] = 1
    end
    local function full(kind, id, seq)
        return { kind = kind, seq = seq, fxId = id, path = "base\\fx\\muzzle.effect", loop = true,
            position = { x = 1, y = 2, z = 3 }, target = { x = 1, y = 2, z = 3 },
            rotation = { x = 1, y = 2, z = 3, w = 4 } }
    end
    local events, visuals = {}, {}
    for index = 1, 24 do events[index] = full("fx_spawn", "f" .. index, index) end
    for index = 1, 32 do visuals[index] = full("fx", "v" .. index) end
    local raw = frame(titan, 2, { vars = vars, events = events, visuals = visuals })
    assert(keyed(raw) > 1024, "the fixture must exceed what the client could ever send")
    now = now + 0.05
    assert(S.acceptFrame(1, raw), "an oversized frame must not cost the Titan its motion")
    local state = messages(2, "state")[1]
    assert(state and state.vars.w64 == 1 and state.pose, "motion survives")
    assert(#state.visuals == 0, "persistent visuals are shed first")
    assert(#state.events >= 1 and #state.events < 24, "the newest events are shed next")
    for index, event in ipairs(state.events) do assert(event.seq == index, "a prefix of the events survives") end
    assert(titan.eventSeq == #state.events, "a shed event's sequence is not consumed")
    assert(keyed(state) <= 1024, "the relayed state must be encodable by the client: " .. keyed(state))
    assert(keyed(titan.snapshot) + 4 <= 1024, "the client adds v and op before TriggerServerEvent")
    assert(messages(1, "error")[1].reason == "event_rejected:frame_nodes")
    for index = 1, 64 do Open77TitanCatalog.variables["w" .. index] = nil end
end)

test("call-down and send-home modes: opening frames only, bounded runs, nothing else relaxed", function()
    reset(); ready(1)
    local titan = spawn(1)
    local ok, why = publish(titan, { mode = "leave" })
    assert(not ok and why == "mode_transition", "a grant cannot open with 'leave': " .. tostring(why))
    ok, why = publish(titan, { mode = "drop", pose = { x = 600, y = 0, z = 0, yaw = 0 } })
    assert(not ok and why == "pose_far", "even a call-down starts within 500 m: " .. tostring(why))
    ok, why = publish(titan, { mode = "wait", pose = { x = 400, y = 0, z = 280, yaw = 0 } })
    assert(not ok and why == "pose_far", "only the call-down gets the wide first radius")
    assert(publish(titan, { mode = "drop", pose = { x = 400, y = 0, z = 280, yaw = 0 } }), "the call-down arrives from the sky")
    assert(publish(titan, { mode = "drop", pose = { x = 400, y = 0, z = 277, yaw = 0 } }), "55 m/s falls under the ordinary rule")
    ok, why = publish(titan, { mode = "leave", pose = { x = 400, y = 0, z = 277, yaw = 0 } })
    assert(not ok and why == "mode_transition", "drop cannot go straight to leave: " .. tostring(why))
    assert(publish(titan, { mode = "wait", pose = { x = 400, y = 0, z = 277, yaw = 0 } }))
    ok, why = publish(titan, { mode = "drop", pose = { x = 400, y = 0, z = 277, yaw = 0 } })
    assert(not ok and why == "mode_transition", "a call-down cannot be re-entered: " .. tostring(why))
    assert(#visibleCalls == 0, "V is hidden only while piloting")
    -- A leave run lasts at most dropWindow seconds, then the frames are refused.
    assert(publish(titan, { mode = "leave", pose = { x = 400, y = 0, z = 277, yaw = 0 } }))
    now = now + 14
    assert(publish(titan, { mode = "leave", pose = { x = 400, y = 0, z = 277, yaw = 0 } }))
    now = now + 2
    ok, why = publish(titan, { mode = "leave", pose = { x = 400, y = 0, z = 277, yaw = 0 } })
    assert(not ok and why == "mode_expired", why)
    assert(publish(titan, { mode = "wait", pose = { x = 400, y = 0, z = 277, yaw = 0 } }))
    assert(publish(titan, { mode = "leave", pose = { x = 400, y = 0, z = 277, yaw = 0 } }), "a new run is a new window")
    assert(S.titans[1] == titan and titan.mode == "leave")
end)

-- ---------------------------------------------------------------------------
-- Physical carry: claims on canonical NPCs and vehicles.
--
-- A fake platform implements the contract Open77.npcs / Open77.vehicles give this
-- resource (beginCarry / updateCarry / endCarry / carry: one claim per body and per
-- carrier, a token per claim, an idempotent end that never touches a newer claim)
-- over two tiny registries. It also counts every call that would be a per-frame
-- teleport or any other mutation of the body: there must be none.
-- ---------------------------------------------------------------------------
local world, claims, coreCalls = { npc = {}, vehicle = {} }, {}, {}
local coreSerial, beginRefusal, beginToken, updateRefusal, forbidden = 0, nil, nil, nil, 0

-- A thrown person's release as the platform's updateCarry takes it: flat, in the order the resource builds it, with the
-- age of the release (`elapsed`) instead of the controller's clock.
local PLATFORM_LAUNCH = { "x", "y", "z", "yaw", "px", "py", "pz", "ix", "iy", "iz", "radius", "delay" }

local function fakeApi(kind)
    local api = {}
    local function key(id) return kind .. ":" .. tostring(id) end
    local function record(call, fields)
        fields.kind, fields.call = kind, call
        coreCalls[#coreCalls + 1] = fields
    end
    function api.beginCarry(id, player)
        record("beginCarry", { id = id, player = player })
        if beginRefusal then return nil, beginRefusal end
        local body = world[kind][id]
        if not body then return nil, kind .. "_not_found" end
        if not players[player] or players[player].bucket ~= body.bucket then return nil, "wrong_bucket" end
        if claims[key(id)] then return nil, "already_carried" end
        for _, claim in pairs(claims) do
            if claim.carrier == player then return nil, "carrier_busy" end
        end
        coreSerial = coreSerial + 1
        local token = beginToken or string.format("%032x", coreSerial)
        claims[key(id)] = { token = token, carrier = player, phase = "hold" }
        return token
    end
    function api.updateCarry(id, token, pose, launch)
        record("updateCarry", { id = id, token = token, pose = pose, launch = launch })
        local claim = claims[key(id)]
        if not claim then return false, "not_carried" end
        if claim.token ~= token then return false, "token_mismatch" end
        if updateRefusal then
            if updateRefusal == "claim_expired" or updateRefusal == "superseded" then claims[key(id)] = nil end
            return false, updateRefusal
        end
        -- The platform's own contract: a person's first flight update must describe its release, an identical repeat
        -- never relaunches and a changed one is refused, and nothing else (a hold, a vehicle) carries one.
        local flies = kind == "npc" and pose.phase == "flight"
        if launch ~= nil and not flies then return false, "invalid_launch" end
        if flies and launch == nil and not claim.launch then return false, "launch_required" end
        if launch then
            if launch.t ~= nil or type(launch.elapsed) ~= "number" or not (launch.elapsed >= 0 and launch.elapsed <= 30) then
                return false, "invalid_launch"
            end
            for _, field in ipairs(PLATFORM_LAUNCH) do
                if type(launch[field]) ~= "number" then return false, "invalid_launch" end
                if claim.launch and claim.launch[field] ~= launch[field] then return false, "launch_changed" end
            end
            claim.launch = claim.launch or launch
        end
        local body = world[kind][id]
        body.x, body.y, body.z, body.yaw = pose.x, pose.y, pose.z, pose.yaw
        claim.phase, claim.pose = pose.phase, pose
        return true
    end
    function api.endCarry(id, token)
        record("endCarry", { id = id, token = token })
        local claim = claims[key(id)]
        if not claim then return true, "not_carried" end
        if claim.token ~= token then return false, "token_mismatch" end
        claims[key(id)] = nil
        return true
    end
    function api.carry(id)
        local claim = claims[key(id)]
        if not claim then return nil end
        return { id = id, carrier = claim.carrier, phase = claim.phase, token = claim.token, idle = 0 }
    end
    for _, name in ipairs({ "setTransform", "setFrozen", "setAIEnabled", "setRagdoll", "update", "remove", "create" }) do
        api[name] = function() forbidden = forbidden + 1 end
    end
    return api
end
Open77.npcs, Open77.vehicles = fakeApi("npc"), fakeApi("vehicle")
function Open77.npcs.presence(id)
    local body = world.npc[id]
    if not body then return nil, "npc_not_found" end
    return { id = id, resource = "open77_npcs", owned = false, bucket = body.bucket, x = body.x, y = body.y, z = body.z,
        alive = body.alive ~= false, authorityPlayerId = 0, epoch = 1 }
end
function Open77.vehicles.get(id)
    local body = world.vehicle[id]
    if not body then return nil end
    return { id = id, bucket = body.bucket, x = body.x, y = body.y, z = body.z, occupants = body.occupants or {},
        destroyed = body.destroyed, exploded = body.exploded, health = body.health }
end
-- What the platform does to a car's canonical ledger for a script (the calls the Titan resource makes for a hit on a car): every
-- call is recorded, `vehicleFailure` makes the platform refuse them, and the registry is what `get` then reads.
local vehicleCalls, vehicleFailure = {}, nil
function Open77.vehicles.setHealth(id, health)
    vehicleCalls[#vehicleCalls + 1] = { call = "setHealth", id = id, health = health }
    local body = world.vehicle[id]
    if not body then return false, "vehicle_not_found" end
    if vehicleFailure then return false, vehicleFailure end
    if type(health) ~= "number" or health < 0 or health > 1 then return false, "invalid_health" end
    body.health = health
    return true
end
function Open77.vehicles.explode(id)
    vehicleCalls[#vehicleCalls + 1] = { call = "explode", id = id }
    local body = world.vehicle[id]
    if not body then return false, "vehicle_not_found" end
    if vehicleFailure then return false, vehicleFailure end
    if body.exploded then return false, "already_exploded" end
    body.health, body.destroyed, body.exploded = 0, true, true
    return true
end

local DROP = {}
local function merge(base, overrides)
    for key, value in pairs(overrides or {}) do
        if value == DROP then base[key] = nil else base[key] = value end
    end
    return base
end

local function carryWorld()
    clear(claims); clear(coreCalls)
    beginRefusal, beginToken, updateRefusal = nil, nil, nil
    world.npc = {
        [5] = { bucket = 0, x = 3, y = 0, z = 0, alive = true },
        [6] = { bucket = 0, x = -4, y = 2, z = 0, alive = true },
    }
    world.vehicle = { [9] = { bucket = 0, x = 0, y = 6, z = 0, occupants = {} } }
end

-- Two live Titans, both at the origin and wielding the fist, in a world with two NPCs
-- (5 at 3 m, 6 at 4.5 m) and a parked vehicle (9 at 6 m).
local function twoTitans()
    reset(); carryWorld()
    ready(1); ready(2)
    local a, b = spawn(1), spawn(2)
    assert(publish(a, { mode = "pilot", weapon = "fist" }) and publish(b, { mode = "pilot", weapon = "fist" }))
    clear(sent); clear(coreCalls)
    return a, b
end
local function carryFixture() return (twoTitans()) end

local function lastMessage(target, op)
    local list = messages(target, op)
    return list[#list]
end
local function calls(name)
    local list = {}
    for _, call in ipairs(coreCalls) do
        if call.call == name then list[#list + 1] = call end
    end
    return list
end
local function denied(titan)
    local message = lastMessage(titan.owner, "carry_denied")
    return message and message.reason
end
local function poseOf(overrides)
    return merge({ x = 1, y = 0, z = 1, yaw = 0, qx = 0, qy = 0, qz = 0, qw = 1, vx = 0, vy = 0, vz = 0, phase = "hold" },
        overrides)
end

local requestOf = setmetatable({}, { __mode = "k" })
local function request(titan, kind, entityId, extra)
    requestOf[titan] = (requestOf[titan] or 0) + 1
    now = now + 0.05
    local message = merge({ v = T.protocol, op = "carry_request", id = titan.id, epoch = titan.epoch,
        request = requestOf[titan], kind = kind, entityId = tostring(entityId) }, extra)
    fire(T.event.carry, titan.owner, message)
    return message
end

-- A thrown person's release as the controller sends it: one per claim, repeated by every flight message (the host runs
-- a tick's messages newest first, so the first one cannot be relied on). It is made at the first flight message's own
-- time unless a test writes one itself; once the claim fixed one, every later message repeats that one.
local function launchOf(overrides)
    return merge({ t = 0, x = 1, y = 0, z = 1, yaw = 0, px = 1, py = 0, pz = 1.6, ix = 0, iy = 912, iz = 547.2,
        radius = 2, delay = 0.12 }, overrides)
end
local launches = {}
local function defaultLaunch(titan, token, message)
    local held = titan.carry
    if not (held and held.token == token and held.kind == "npc" and type(message.pose) == "table" and message.pose.phase == "flight") then
        return nil
    end
    local known = held.launch or launches[token]
    if not known then
        known = launchOf({ t = message.t })
        launches[token] = known
    end
    return merge({}, known)
end

local carrySeq, carryClock = {}, {}
local function carryMessage(op, titan, token, extra, pose)
    carrySeq[token] = (carrySeq[token] or 0) + 1
    carryClock[token] = (carryClock[token] or 0) + 0.05
    local message = { v = T.protocol, op = op, id = titan.id, epoch = titan.epoch, token = token,
        seq = carrySeq[token], t = carryClock[token], pose = poseOf(pose) }
    if op == "carry_release" then message.reason = "landed" end
    merge(message, extra)
    if message.launch == nil and not (extra and extra.launch == DROP) then message.launch = defaultLaunch(titan, token, message) end
    return message
end
local function sample(titan, token, pose, extra)
    now = now + 0.05
    local message = carryMessage("carry_frame", titan, token, extra, pose)
    fire(T.event.carry, titan.owner, message)
    return message
end
local function release(titan, token, pose, extra)
    now = now + 0.05
    local message = carryMessage("carry_release", titan, token, extra, pose)
    fire(T.event.carry, titan.owner, message)
    return message
end

-- A request and the grant it earned.
local function claim(titan, kind, entityId)
    clear(sent)
    request(titan, kind, entityId)
    local grant = lastMessage(titan.owner, "carry_grant")
    assert(grant, "no grant: " .. tostring(denied(titan)))
    return grant.token, grant
end

-- One Titan frame (the controller's own stream), so only the CLAIM can look stale to the upkeep.
local function keepAlive(titan) assert(publish(titan, { mode = "pilot", weapon = "fist" })) end
local function refresh(titan)
    now = now + 2
    keepAlive(titan)
end

local function expectDenied(reason, setup, kind, id)
    local titan = carryFixture()
    if setup then setup(titan) end
    clear(sent); clear(coreCalls)
    request(titan, kind or "npc", id or 5)
    assert(denied(titan) == reason, ("expected %s, got %s"):format(reason, tostring(denied(titan))))
    local message = lastMessage(1, "carry_denied")
    assert(T.carryReasons[reason] == true and T.normalizeServerMessage(message, Open77TitanCatalog),
        "the controller's validator must accept a denial: " .. reason)
    assert(#calls("beginCarry") == 0 and titan.carry == nil and next(S.bodies) == nil, "state touched: " .. reason)
    assert(#messages(1, "carry_grant") == 0)
    return titan
end

test("a grant binds one claim to the Titan, its owner and the platform's token", function()
    local titan = carryFixture()
    local granted = S.stats.carryGranted
    local message = request(titan, "npc", 5)
    local begun = calls("beginCarry")
    assert(#begun == 1 and begun[1].kind == "npc" and begun[1].id == 5 and begun[1].player == 1)
    assert(math.type(begun[1].id) == "integer" and math.type(begun[1].player) == "integer", "the platform takes integers")
    local grants = messages(1, "carry_grant")
    assert(#grants == 1)
    local grant = grants[1]
    assert(grant.v == T.protocol and grant.id == titan.id and grant.epoch == titan.epoch and grant.request == message.request)
    assert(grant.kind == "npc" and grant.entityId == "5" and T.isToken(grant.token) and #grant.token == 32)
    assert(claims["npc:5"].token == grant.token and claims["npc:5"].carrier == 1)
    assert(S.bodies["npc:5"] == titan and titan.carry.token == grant.token and titan.carry.phase == "hold")
    assert(#messages(2) == 0, "the grant goes to the owner's controller only")
    assert(S.stats.carryGranted == granted + 1)
    local state = S.carryReport(titan)
    assert(state.active and state.platformAgrees == true and state.kind == "npc" and state.entityId == "5")
    assert(T.normalizeServerMessage(grant, Open77TitanCatalog), "the controller's validator accepts the grant")

    -- A vehicle claim is the same contract on the other registry.
    local b = select(2, twoTitans())
    local token = claim(b, "vehicle", 9)
    assert(calls("beginCarry")[1].kind == "vehicle" and claims["vehicle:9"].token == token and S.bodies["vehicle:9"] == b)
    assert(forbidden == 0, "a carry is never a teleport, a freeze or an AI switch")
end)

test("the server accepts only the canonical id: a native entity id or a malformed claim never reaches the platform", function()
    local titan = carryFixture()
    local bad = {
        { entity = "12345678901234567890", entityId = DROP },          -- the controller's native form
        { entity = "12345678901234567890" },                           -- ... next to the canonical one
        { kind = "prop" }, { kind = DROP }, { entityId = "0" }, { entityId = "05" }, { entityId = "5.0" },
        { entityId = 5 }, { entityId = "12345678901234567" }, { request = 0 }, { request = 1.5 }, { request = "1" },
        { epoch = 0 }, { id = "abc" }, { __extra = true }, { v = 1 },
    }
    for index, extra in ipairs(bad) do
        local before = S.stats.carryRejected
        request(titan, "npc", 5, extra)
        assert(S.stats.carryRejected == before + 1, "accepted malformed request #" .. index)
    end
    assert(#calls("beginCarry") == 0 and next(S.bodies) == nil and #messages(1, "carry_grant") == 0)
    local errors = messages(1, "error")
    assert(#errors == 1 and errors[1].reason:find("^carry_rejected:"), "the owner is told once, with a fixed token")
    assert(T.normalizeServerMessage(errors[1], Open77TitanCatalog))
    -- ... and a non-table payload costs nothing but a count.
    fire(T.event.carry, 1, "carry_request"); fire(T.event.carry, 1, 7); fire(T.event.carry, 1, nil)
    assert(#calls("beginCarry") == 0)
end)

test("a request is bound to the current Titan generation and the authenticated sender", function()
    local a, b = twoTitans()
    request(a, "npc", 5, { id = "999" })
    assert(denied(a) == "stale_titan")
    request(a, "npc", 5, { epoch = 2 })
    assert(denied(a) == "stale_titan")
    request(a, "npc", 5, { id = b.id })
    assert(denied(a) == "stale_titan", "the connection binds the Titan, never the message")
    request(b, "npc", 5, { id = a.id })
    assert(denied(b) == "stale_titan")
    assert(#calls("beginCarry") == 0 and next(S.bodies) == nil)

    -- A player with no Titan gets no answer and moves nothing.
    clear(sent)
    fire(T.event.carry, 3, { v = T.protocol, op = "carry_request", id = a.id, epoch = a.epoch, request = 1, kind = "npc", entityId = "5" })
    assert(#messages(3) == 0 and #calls("beginCarry") == 0)

    -- Request numbers only go forward, per Titan.
    local first = request(a, "npc", 5)
    local token = lastMessage(1, "carry_grant").token
    release(a, token)
    requestOf[a] = first.request - 1
    request(a, "npc", 5)
    assert(denied(a) == "stale_request", denied(a))
    assert(#calls("beginCarry") == 1, "a replayed request number never reaches the platform")
end)

test("every refusal is explicit, fixed-vocabulary and touches nothing", function()
    expectDenied("not_fist", function(t) assert(publish(t, { weapon = "xo16" })) end)
    expectDenied("titan_busy", function(t) assert(publish(t, { mode = "eject", weapon = "fist" })) end)
    expectDenied("titan_busy", function() now = now + 1.5 end)
    expectDenied("owner_unavailable", function() players[1].dead = true end)
    expectDenied("owner_unavailable", function() players[1].ready = false end)
    expectDenied("bucket_mismatch", function() players[1].bucket = 4 end)
    expectDenied("bucket_mismatch", function() world.npc[5].bucket = 2 end)
    expectDenied("target_missing", nil, "npc", 99)
    expectDenied("target_missing", nil, "vehicle", 99)
    expectDenied("target_dead", function() world.npc[5].alive = false end)
    expectDenied("target_busy", function()
        world.vehicle[9].occupants = { { playerId = 2, seat = "seat_front_left" } }
    end, "vehicle", 9)
    expectDenied("target_far", function() world.npc[5].x = 12.1 end)
    expectDenied("target_far", function() world.npc[5].x, world.npc[5].y, world.npc[5].z = 8, 8, 5 end)

    -- A grant that is not up yet.
    reset(); carryWorld(); ready(1)
    local titan = spawn(1)
    request(titan, "npc", 5)
    assert(denied(titan) == "not_active" and #calls("beginCarry") == 0)

    -- The rate budget: a grab is a 3.4 s punch.
    titan = carryFixture()
    for _ = 1, 3 do request(titan, "npc", 99) end
    assert(denied(titan) == "target_missing")
    request(titan, "npc", 5)
    assert(denied(titan) == "rate_limited" and #calls("beginCarry") == 0)
end)

test("a wreck is carried like any car: only a dead person is refused", function()
    for _, wreck in ipairs({ { destroyed = true, health = 0 }, { exploded = true, destroyed = true, health = 0 } }) do
        local titan = carryFixture()
        for field, value in pairs(wreck) do world.vehicle[9][field] = value end
        local requested, granted, accepted = S.stats.carryRequested, S.stats.carryGranted, S.stats.carryAccepted
        local token, grant = claim(titan, "vehicle", 9)
        local begun = calls("beginCarry")
        assert(#begun == 1 and begun[1].kind == "vehicle" and begun[1].id == 9 and begun[1].player == 1, "the platform was asked")
        assert(grant.kind == "vehicle" and grant.entityId == "9" and grant.id == titan.id and grant.epoch == titan.epoch)
        assert(T.normalizeServerMessage(grant, Open77TitanCatalog), "the controller's validator accepts the grant")
        assert(S.stats.carryRequested == requested + 1 and S.stats.carryGranted == granted + 1)
        assert(S.bodies["vehicle:9"] == titan and titan.carry.token == token and claims["vehicle:9"].token == token)
        -- The next in-reach hold sample on the wreck is accepted and reaches the platform.
        sample(titan, token, { x = 1, z = 1 })
        assert(S.stats.carryAccepted == accepted + 1 and #calls("updateCarry") == 1 and titan.carry.pose.x == 1,
            tostring(titan.lastCarryReject))
    end
    -- A dead person is still refused, with the same fixed reason.
    expectDenied("target_dead", function() world.npc[5].alive = false end)
end)

test("reach is 12 m from the accepted Titan root, in three dimensions", function()
    local titan = carryFixture()
    world.npc[5].x = 11.9
    claim(titan, "npc", 5)
    release(titan, titan.carry.token)
    -- The root moves (inside the movement admission): the same body is now out of reach.
    now = now + 1
    assert(publish(titan, { mode = "pilot", weapon = "fist", pose = { x = -1, y = 0, z = 0, yaw = 0 } }))
    now = now + 0.9
    publish(titan, { mode = "pilot", weapon = "fist", pose = { x = -1.2, y = 0, z = 0, yaw = 0 } })
    clear(sent)
    request(titan, "npc", 5)
    assert(denied(titan) == "target_far", "11.9 m from the origin is 13.1 m from the root")
    world.npc[5].x = 5
    request(titan, "npc", 5)
    assert(lastMessage(1, "carry_grant"), "within reach of the NEW root: " .. tostring(denied(titan)))
end)

test("the platform's refusals are mapped into the fixed vocabulary; a missing or failing API is 'unavailable'", function()
    local cases = {
        { "already_carried", "target_claimed", "npc" }, { "carrier_busy", "already_carrying", "npc" },
        { "npc_mounted", "target_busy", "npc" }, { "npc_presentation", "target_busy", "npc" },
        { "vehicle_ai_driven", "target_busy", "vehicle" }, { "vehicle_driven", "target_busy", "vehicle" },
        { "vehicle_seat_reserved", "target_busy", "vehicle" }, { "vehicle_occupied", "target_busy", "vehicle" },
        { "wrong_bucket", "bucket_mismatch", "npc" }, { "carrier_unavailable", "owner_unavailable", "npc" },
        { "npc_dead", "target_dead", "npc" },
        { "carry_limit", "refused", "npc" }, { "a_reason_added_next_year", "refused", "vehicle" },
        { "permission_denied:npcs.foreign", "unavailable", "npc" }, { "permission_denied:world.vehicles", "unavailable", "vehicle" },
    }
    for _, case in ipairs(cases) do
        local titan = carryFixture()
        beginRefusal = case[1]
        request(titan, case[3], case[3] == "npc" and 5 or 9)
        assert(denied(titan) == case[2], case[1] .. " -> " .. tostring(denied(titan)))
        assert(#calls("beginCarry") == 1 and titan.carry == nil and next(S.bodies) == nil and next(claims) == nil)
        assert(T.normalizeServerMessage(lastMessage(1, "carry_denied"), Open77TitanCatalog))
    end
    local api = Open77.npcs
    local original = api.beginCarry
    local titan = carryFixture()
    api.beginCarry = nil
    request(titan, "npc", 5)
    assert(denied(titan) == "unavailable" and titan.carry == nil)
    api.beginCarry = function() error("boom") end
    request(titan, "npc", 5)
    assert(denied(titan) == "unavailable" and titan.carry == nil and next(S.bodies) == nil)
    api.beginCarry = original

    -- A token this resource cannot name is still a claim: it goes straight back.
    titan = carryFixture()
    beginToken = "not a token!"
    request(titan, "npc", 5)
    assert(denied(titan) == "refused" and titan.carry == nil and next(S.bodies) == nil)
    assert(#calls("endCarry") == 1 and calls("endCarry")[1].token == "not a token!" and next(claims) == nil)
end)

test("one body per Titan and one claim per body, across Titans and resources", function()
    local a, b = twoTitans()
    local token = claim(a, "npc", 5)
    clear(coreCalls)
    request(a, "npc", 6)
    assert(denied(a) == "already_carrying" and #calls("beginCarry") == 0, "one body per Titan")
    request(b, "npc", 5)
    assert(denied(b) == "target_claimed" and #calls("beginCarry") == 0, "one claim per body: no platform trip")
    assert(S.bodies["npc:5"] == a and b.carry == nil)
    -- Another body is a separate claim; the carrier of the first stays untouched.
    claim(b, "npc", 6)
    assert(S.bodies["npc:6"] == b and a.carry.token == token and claims["npc:5"].token == token)
    -- A body the platform says another RESOURCE holds is refused by the platform's own answer.
    release(a, token)
    claims["vehicle:9"] = { token = "foreign", carrier = 3 }
    refresh(a)
    request(a, "vehicle", 9)
    assert(denied(a) == "target_claimed" and #calls("beginCarry") >= 1 and a.carry == nil)
    assert(claims["vehicle:9"].token == "foreign", "somebody else's claim is never touched")
    -- Once a Titan lets go, the body is free for the other one.
    release(b, b.carry.token)
    refresh(a)
    request(a, "npc", 6)
    assert(lastMessage(1, "carry_grant") and S.bodies["npc:6"] == a)
end)

test("a claim cannot be used, ended or hijacked by anybody but its owner's own Titan and token", function()
    local a, b = twoTitans()
    local token = claim(a, "npc", 5)
    clear(coreCalls)
    local stale = S.stats.carryStale
    -- The other Titan's owner presents the token, with its own and with the victim's identity.
    sample(b, token, {})
    sample(b, token, {}, { id = a.id, epoch = a.epoch })
    release(b, token)
    release(b, token, {}, { id = a.id, epoch = a.epoch })
    -- A player with no Titan.
    fire(T.event.carry, 3, carryMessage("carry_release", a, token))
    -- The owner, with a stale generation or somebody else's token.
    sample(a, token, {}, { epoch = 2 })
    sample(a, token, {}, { id = b.id })
    sample(a, string.rep("0", 32), {})
    release(a, string.rep("0", 32))
    assert(S.stats.carryStale == stale + 8, S.stats.carryStale - stale)
    assert(#calls("updateCarry") == 0 and #calls("endCarry") == 0, "nothing reached the platform")
    assert(a.carry and a.carry.token == token and claims["npc:5"].token == token and S.bodies["npc:5"] == a)
    assert(#messages(1, "carry_ended") == 0 and #messages(2, "carry_ended") == 0 and #messages(1, "error") == 0)
    -- ... and then the real owner still can.
    sample(a, token, {})
    assert(#calls("updateCarry") == 1 and a.carry.accepted == 1)
end)

test("samples are strictly sequenced; malformed ones never reach the platform", function()
    local titan = carryFixture()
    local token = claim(titan, "npc", 5)
    clear(coreCalls)
    sample(titan, token, { x = 1, z = 1 })
    assert(#calls("updateCarry") == 1 and calls("updateCarry")[1].token == token and calls("updateCarry")[1].id == 5)
    assert(calls("updateCarry")[1].pose.phase == "hold" and titan.carry.seq == 1 and world.npc[5].x == 1)
    -- An older or equal sequence, or an older clock, is the host's reordering: dropped, no penalty.
    local stale = S.stats.carryStale
    sample(titan, token, { x = 2 }, { seq = 1 })
    sample(titan, token, { x = 2 }, { t = 0.01 })
    assert(#calls("updateCarry") == 1 and titan.carry.seq == 1 and titan.carry.violations == 0)
    assert(S.stats.carryStale == stale + 2 and #messages(1, "error") == 0)

    -- The wire validator drops each malformed field before anything else runs.
    local nan, inf = 0 / 0, math.huge
    local bad = {
        { pose = { x = nan } }, { pose = { x = inf } }, { pose = { y = -inf } }, { pose = { z = 1e7 } },
        { pose = { yaw = 4000 } }, { pose = { x = DROP } }, { pose = { qw = 0 } }, { pose = { qw = 1.05 } },
        { pose = { qx = nan } }, { pose = { vx = 101 } }, { pose = { vz = -inf } }, { pose = { vy = DROP } },
        { pose = { phase = "teleport" } }, { pose = { phase = DROP } }, { pose = { extra = 1 } },
        { extra = { token = "bad token" } }, { extra = { token = DROP } }, { extra = { seq = 0 } },
        { extra = { seq = 1.5 } }, { extra = { seq = 2 ^ 60 } }, { extra = { t = nan } }, { extra = { t = 1e12 } },
        { extra = { pose = "1,2,3" } }, { extra = { reason = "landed" } },
    }
    local rejected = S.stats.carryRejected
    for index, case in ipairs(bad) do
        local message = carryMessage("carry_frame", titan, token, case.extra, case.pose)
        now = now + 0.05
        fire(T.event.carry, 1, message)
        assert(S.stats.carryRejected == rejected + index, "accepted malformed sample #" .. index)
    end
    assert(#calls("updateCarry") == 1 and titan.carry.seq == 1, "none of them reached the platform")
    -- A release names a reason from the controller's vocabulary only.
    local before = S.stats.carryRejected
    release(titan, token, {}, { reason = "because" })
    release(titan, token, {}, { reason = DROP })
    assert(S.stats.carryRejected == before + 2 and titan.carry, "an unknown release reason is not a release")
    -- The claim is still there, and a good sample still works.
    sample(titan, token, { x = 1.5, z = 1 })
    assert(#calls("updateCarry") == 2 and titan.carry.seq > 1)
    -- A stalled claim is the answer to a controller that only sends garbage.
    now = now + 1.2
    keepAlive(titan)
    S.tick()
    assert(titan.carry == nil and lastMessage(1, "carry_ended").reason == "claim_stalled")
end)

test("hold samples stay inside the hand envelope, and a run of bad ones ends the claim", function()
    local titan = carryFixture()
    local token = claim(titan, "npc", 5)
    clear(coreCalls)
    sample(titan, token, { x = 1, z = 1 })
    assert(#calls("updateCarry") == 1)
    -- Further than 12 m from the Titan's root.
    sample(titan, token, { x = 13, z = 0 })
    assert(titan.lastCarryReject == "hold_far" and #calls("updateCarry") == 1 and titan.carry.pose.x == 1)
    -- Inside reach, but a jump no hand makes (60 m/s plus the slack).
    sample(titan, token, { x = 11, z = 0 })
    assert(titan.lastCarryReject == "speed" and #calls("updateCarry") == 1 and titan.carry.violations == 2)
    local errors = messages(1, "error")
    assert(#errors == 2 and errors[1].reason == "carry_rejected:hold_far" and errors[2].reason == "carry_rejected:speed",
        "each distinct reason is reported, once per 5 s")
    -- A reported velocity above the ceiling is not a believable sample either.
    sample(titan, token, { x = 1, z = 1, vx = 90 })
    assert(titan.lastCarryReject == "velocity" and #calls("updateCarry") == 1)
    -- One good sample resets the run ...
    sample(titan, token, { x = 1.2, z = 1 })
    assert(#calls("updateCarry") == 2 and titan.carry.violations == 0)
    for _ = 1, 4 do sample(titan, token, { x = 13, z = 0 }) end
    assert(titan.carry and titan.carry.violations == 4 and #calls("endCarry") == 0)
    sample(titan, token, { x = 1.4, z = 1 })
    assert(titan.carry.violations == 0)
    -- ... and five in a row end it, restoring the body.
    for _ = 1, 5 do sample(titan, token, { x = 13, z = 0 }) end
    assert(titan.carry == nil and S.bodies["npc:5"] == nil and next(claims) == nil)
    assert(#calls("endCarry") == 1 and calls("endCarry")[1].token == token)
    local ended = lastMessage(1, "carry_ended")
    assert(ended.reason == "pose_rejected" and ended.token == token and ended.id == titan.id)
    assert(world.npc[5].x == 1.4, "the body stays where the last ACCEPTED sample put it")
end)

test("a car in the hand moves at the platform's own velocity bound; a person's hand and a flight keep theirs", function()
    local limits = T.limits
    local titan = carryFixture()
    local token = claim(titan, "vehicle", 9)
    clear(coreCalls)
    -- The Titan dashes: the car in its hand outruns a swinging hand, up to the bound the platform itself enforces.
    sample(titan, token, { x = 1, z = 1, vx = 90 })
    assert(#calls("updateCarry") == 1 and titan.carry.violations == 0, tostring(titan.lastCarryReject))
    -- A 3.5 m snap between two samples (the car settling into the hand) is inside the speed envelope.
    sample(titan, token, { x = 4.5, z = 1, vx = 90 })
    assert(#calls("updateCarry") == 2 and titan.carry.pose.x == 4.5, tostring(titan.lastCarryReject))
    sample(titan, token, { x = 4.5, z = 1, vx = limits.carryVelocity })
    assert(#calls("updateCarry") == 3, "exactly the bound is allowed: " .. tostring(titan.lastCarryReject))
    -- Over the platform's bound the wire's own validator drops the sample before the claim ever sees it.
    local rejected = S.stats.carryRejected
    sample(titan, token, { x = 4.5, z = 1, vx = 101 })
    assert(#calls("updateCarry") == 3 and S.stats.carryRejected == rejected + 1 and titan.carry.violations == 0)
    local errors = messages(1, "error")
    assert(errors[#errors].reason == "carry_rejected:carry_velocity", errors[#errors].reason)
    -- ... and so is a vector that is over the bound across its axes.
    sample(titan, token, { x = 4.5, z = 1, vx = 60, vy = 60, vz = 60 })
    assert(#calls("updateCarry") == 3 and S.stats.carryRejected == rejected + 2)
    -- A person's hand keeps the hand speed (the NPC case above), and a thrown car's flight keeps its own base.
    local npcTitan = carryFixture()
    local npcToken = claim(npcTitan, "npc", 5)
    sample(npcTitan, npcToken, { x = 1, z = 1, vx = 90 })
    assert(npcTitan.lastCarryReject == "velocity")
    local flier = carryFixture()
    local flightToken = claim(flier, "vehicle", 9)
    sample(flier, flightToken, { x = 1, z = 1 })
    sample(flier, flightToken, { x = 2, z = 3, vx = 90, phase = "flight" })
    assert(flier.lastCarryReject == "velocity" and flier.carry.phase == "hold", "a flight's own cap, not the hold's")
end)

-- One flight sample `age` s after the throw on the server clock (counted from carry.flightAt) and
-- `wireAge` s after it on the wire clock (counted from carry.flightT; the same by default): what a
-- controller whose clock keeps pace with the server's sends. sample() itself advances the server clock by
-- 0.05 s, so `age` is the clock the server reads it at. Nothing counts from the grant, so any age is fair.
local function flightSampleAt(titan, token, age, pose, wireAge)
    local carry = titan.carry
    assert(carry.phase == "flight" and now <= carry.flightAt + age, "flight samples only go forward")
    now = carry.flightAt + age - 0.05
    return sample(titan, token, pose, { t = carry.flightT + (wireAge or age) })
end

test("flight is one-way, bounded in speed and time, and never a teleport", function()
    local limits = T.limits
    local titan = carryFixture()
    local token = claim(titan, "npc", 5)
    sample(titan, token, { x = 1, z = 1 })
    sample(titan, token, { x = 2, z = 3, vx = 10, vz = 5, phase = "flight" })
    assert(titan.carry.phase == "flight" and claims["npc:5"].phase == "flight")
    -- Past 12 m from the root is the point of a throw: the hand envelope no longer applies ...
    for step = 1, 10 do
        now = now + 0.05
        sample(titan, token, { x = 2 + step * 2.5, z = 3, vx = 25, phase = "flight" })
    end
    assert(titan.carry.pose.x == 27 and titan.carry.violations == 0)
    -- ... the speed ceiling (plus gravity) does.
    sample(titan, token, { x = 500, z = 3, vx = 25, phase = "flight" })
    assert(titan.lastCarryReject == "speed" and titan.carry.pose.x == 27)
    -- Nothing goes back into the hand.
    sample(titan, token, { x = 27, z = 3, phase = "hold" })
    assert(titan.lastCarryReject == "phase_order" and titan.carry.phase == "flight")

    -- A flight lasts carryFlight (30 s) from its first accepted pose, a person's ragdoll and a vehicle's arc alike:
    -- a sample 4.8 s in, fresh on both clocks, is admitted ...
    clear(coreCalls)
    flightSampleAt(titan, token, 4.8, { x = 28, z = 3, vx = 25, phase = "flight" })
    assert(titan.carry and titan.carry.pose.x == 28 and titan.carry.violations == 0 and #calls("updateCarry") == 1)
    -- ... with the gravity allowance still growing with the flight: 9 s in, the ceiling is (200 + 9.81 * 9)
    -- m/s over the 1 s gap bound plus the slack, a step the allowance of 4 s in (200 + 9.81 * 4) would refuse.
    local fourSeconds = limits.carryNpcFlightSpeed + limits.carryGravity * 4 + limits.carrySlack
    local nineSeconds = limits.carryNpcFlightSpeed + limits.carryGravity * 9 + limits.carrySlack
    flightSampleAt(titan, token, 9, { x = 28 + nineSeconds + 0.5, z = 3, phase = "flight" })
    assert(titan.lastCarryReject == "speed" and titan.carry.pose.x == 28 and titan.carry.violations == 1)
    flightSampleAt(titan, token, 9.05, { x = 28 + fourSeconds + 1, z = 3, phase = "flight" })
    assert(titan.carry.pose.x == 28 + fourSeconds + 1 and titan.carry.violations == 0 and #calls("updateCarry") == 2)
    -- ... and nothing goes back into the hand however late.
    flightSampleAt(titan, token, 9.1, { x = 28 + fourSeconds + 1, z = 3, phase = "hold" })
    assert(titan.lastCarryReject == "phase_order" and titan.carry.phase == "flight" and #calls("updateCarry") == 2)
    -- The gravity allowance stops growing at the flight time: 30.4 s in (inside the slack, the wire
    -- clock at the horizon) the ceiling is (200 + 9.81 * 30) m/s over the 1 s gap bound plus the slack, not the
    -- (200 + 9.81 * 30.4) an allowance growing past the horizon would give.
    local atHorizon = limits.carryNpcFlightSpeed + limits.carryGravity * limits.carryFlight + limits.carrySlack
    local from = titan.carry.pose.x
    flightSampleAt(titan, token, limits.carryFlight + 0.4, { x = from + atHorizon + 0.5, z = 3, phase = "flight" }, limits.carryFlight)
    assert(titan.lastCarryReject == "speed" and titan.carry.pose.x == from)
    flightSampleAt(titan, token, limits.carryFlight + 0.45, { x = from + atHorizon - 0.5, z = 3, phase = "flight" }, limits.carryFlight)
    assert(titan.carry and titan.carry.pose.x == from + atHorizon - 0.5 and titan.carry.violations == 0)
    -- It ends past carryFlight plus the slack on the server clock, whatever the sample's own clock says.
    clear(coreCalls)
    flightSampleAt(titan, token, limits.carryFlight + limits.carryFlightSlack + 0.05,
        { x = 29, z = 3, vx = 25, phase = "flight" }, limits.carryFlight)
    assert(titan.carry == nil and #calls("updateCarry") == 0 and #calls("endCarry") == 1)
    assert(lastMessage(1, "carry_ended").reason == "flight_expired" and next(claims) == nil)

    -- A flight nobody samples is cut by the upkeep as well, at the same deadline.
    titan = carryFixture()
    token = claim(titan, "npc", 5)
    sample(titan, token, { x = 2, z = 3, vx = 10, phase = "flight" })
    now = titan.carry.flightAt + limits.carryFlight + limits.carryFlightSlack + 0.05
    assert(publish(titan, { mode = "pilot", weapon = "fist" }))
    S.tick()
    assert(titan.carry == nil and lastMessage(1, "carry_ended").reason == "flight_expired" and next(claims) == nil)
    assert(S.titans[1] == titan, "the Titan itself is fine")
end)

-- A thrown person's ragdoll falls from ~190 m and is still rising at 2.4 s, and a thrown car flies on until it
-- really lands: each gets carryFlight from its first accepted flight pose. Each ends past
-- `carryFlight + carryFlightSlack` on the server clock or past `carryFlight + 0.1` on the wire clock, from
-- whichever the sample trips; the flight's one-way phase is the same for both. Nothing counts from the grant
-- (the test after this one).
test("a person's flight and a vehicle's are cut past the same flight allowance on either clock", function()
    local limits = T.limits
    local horizon, slack, WIRE = limits.carryFlight, limits.carryFlightSlack, 0.1 -- the wire clock's own allowance is a literal of the rule
    local shapes = {
        npc = { id = 5, held = {} },
        vehicle = { id = 9, held = { y = 6 } },
    }
    local function pose(kind, x) return merge({ x = x, z = 0, phase = "flight" }, shapes[kind].held) end
    -- A claim of `kind`, held, then thrown: the flight clocks of both sides start at the throw.
    local function thrown(kind)
        local titan = carryFixture()
        local token = claim(titan, kind, shapes[kind].id)
        sample(titan, token, merge({ x = 1, z = 0 }, shapes[kind].held))
        sample(titan, token, pose(kind, 2))
        assert(titan.carry.phase == "flight" and titan.carry.violations == 0 and titan.carry.flightAt, kind .. " throw")
        return titan, token
    end
    local function alive(kind, titan, token, age, x, wireAge)
        flightSampleAt(titan, token, age, pose(kind, x), wireAge)
        assert(titan.carry and titan.carry.phase == "flight" and titan.carry.pose.x == x and titan.carry.violations == 0,
            ("%s sample at %.2f s (wire %.2f s) must be admitted"):format(kind, age, wireAge or age))
    end
    local function cut(kind, titan, token, age, x, wireAge)
        clear(coreCalls)
        flightSampleAt(titan, token, age, pose(kind, x), wireAge)
        assert(titan.carry == nil and #calls("updateCarry") == 0 and #calls("endCarry") == 1,
            ("%s sample at %.2f s (wire %.2f s) must end the claim"):format(kind, age, wireAge or age))
        assert(lastMessage(1, "carry_ended").reason == "flight_expired" and next(claims) == nil and next(S.bodies) == nil)
    end

    for _, kind in ipairs({ "npc", "vehicle" }) do
        -- The server clock: the flight goes on until horizon + slack ..., and ends past it whatever the wire
        -- clock claims (inside its own bound).
        local titan, token = thrown(kind)
        alive(kind, titan, token, horizon + slack - 0.05, 3, horizon)
        cut(kind, titan, token, horizon + slack + 0.05, 4, horizon)
        -- The wire clock: horizon + 0.1, however early the server's clock reads it.
        titan, token = thrown(kind)
        alive(kind, titan, token, horizon, 3, horizon + WIRE - 0.05)
        cut(kind, titan, token, horizon + 0.1, 4, horizon + WIRE + 0.05)
    end

    -- A sample 4.8 s after the throw is well inside the flight of either kind.
    local titan, token = thrown("npc")
    alive("npc", titan, token, 4.8, 3)
    titan, token = thrown("vehicle")
    alive("vehicle", titan, token, 4.8, 3)

    -- A vehicle's gravity allowance grows with its flight, as long as the flight does: 15 s in, the ceiling is
    -- (60 + 9.81 * 15) m/s over the 1 s gap bound plus the slack ...
    titan, token = thrown("vehicle")
    local fifteen = limits.carrySpeed + limits.carryGravity * 15 + limits.carrySlack
    local from = titan.carry.pose.x
    flightSampleAt(titan, token, 15, pose("vehicle", from + fifteen + 0.5))
    assert(titan.lastCarryReject == "speed" and titan.carry.pose.x == from and titan.carry.violations == 1)
    alive("vehicle", titan, token, 15.05, from + fifteen - 0.5)
    -- ... and stops growing at the horizon: 30.4 s in (inside the slack, the wire clock at the horizon) it is
    -- (60 + 9.81 * 30) m/s over the 1 s gap bound plus the slack, not what an allowance growing past it would give.
    titan, token = thrown("vehicle")
    local ceiling = limits.carrySpeed + limits.carryGravity * horizon + limits.carrySlack
    from = titan.carry.pose.x
    flightSampleAt(titan, token, horizon + 0.4, pose("vehicle", from + ceiling + 0.5), horizon)
    assert(titan.lastCarryReject == "speed" and titan.carry.pose.x == from and titan.carry.violations == 1)
    alive("vehicle", titan, token, horizon + 0.45, from + ceiling - 0.5, horizon)

    -- The upkeep cuts a flight whose samples stopped at the same deadline, 30.75 s after the throw (the last
    -- sample 0.1 s old, so no stall is in play); until then it leaves the flight of either kind alone.
    for _, kind in ipairs({ "npc", "vehicle" }) do
        titan, token = thrown(kind)
        local thrownAt = titan.carry.flightAt
        alive(kind, titan, token, 4.7, 3, 4.7)
        now = thrownAt + 4.8
        keepAlive(titan)
        S.tick()
        assert(titan.carry and titan.carry.phase == "flight" and claims[kind .. ":" .. shapes[kind].id].token == token, kind)
        local deadline = horizon + slack + 0.05
        alive(kind, titan, token, deadline - 0.1, 4, horizon)
        now = thrownAt + deadline
        keepAlive(titan)
        S.tick()
        assert(titan.carry == nil and lastMessage(1, "carry_ended").reason == "flight_expired" and next(claims) == nil, kind)
    end
end)

-- A hold has no time limit at all: a body in the hand stays there for as long as the controller feeds fresh
-- samples, and a throw gets its whole flight from its own first accepted pose, however long the hold before it was.
test("a hold has no time limit, and the flight allowance counts from the throw, not from the grant", function()
    local limits = T.limits
    local ids, held = { npc = 5, vehicle = 9 }, { npc = {}, vehicle = { y = 6 } }
    local function pose(kind, x, phase) return merge({ x = x, z = 0, phase = phase or "flight" }, held[kind]) end

    for _, kind in ipairs({ "npc", "vehicle" }) do
        local titan = carryFixture()
        local token = claim(titan, kind, ids[kind])
        local grantedAt = titan.carry.claimedAt
        -- Two minutes of hold, fed every 0.45 s: nothing ends it.
        for step = 1, 270 do
            now = now + 0.4
            keepAlive(titan)
            sample(titan, token, pose(kind, 1 + (step % 2) * 0.1, "hold"))
            S.tick()
            assert(titan.carry and titan.carry.phase == "hold" and titan.carry.violations == 0,
                ("%s hold ended at step %d"):format(kind, step))
        end
        assert(now - grantedAt > 120 and #messages(1, "carry_ended") == 0 and #calls("endCarry") == 0)
        assert(claims[kind .. ":" .. ids[kind]].token == token and S.bodies[kind .. ":" .. ids[kind]] == titan)

        -- A throw after that gets its whole flight from ITS first accepted pose: 29 s in, 150 s after the grant,
        -- a sample is admitted ...
        sample(titan, token, pose(kind, 2))
        assert(titan.carry.phase == "flight" and titan.carry.violations == 0)
        assert(titan.carry.claimedAt == grantedAt and titan.carry.flightAt - grantedAt > 120, kind .. ": the throw is late in the hold")
        flightSampleAt(titan, token, 29, pose(kind, 3), 29)
        assert(titan.carry and titan.carry.pose.x == 3 and titan.carry.violations == 0, kind .. " flight 29 s in")
        -- ... and the flight ends past carryFlight plus the slack from the throw, with the flight's own reason.
        clear(coreCalls)
        flightSampleAt(titan, token, limits.carryFlight + limits.carryFlightSlack + 0.05, pose(kind, 4), limits.carryFlight)
        assert(titan.carry == nil and #calls("updateCarry") == 0 and #calls("endCarry") == 1, kind)
        assert(lastMessage(1, "carry_ended").reason == "flight_expired" and next(claims) == nil and next(S.bodies) == nil)
    end
end)

-- The genuine author's NPC ragdoll moves ~160 m/s once thrown; a vehicle's arc and a
-- hand do not. Samples here are 0.1 s apart, so a 16 m step is exactly that 160 m/s.
test("a thrown NPC may fly at its ragdoll's 160 m/s; the same step is refused for a vehicle's flight and a held NPC", function()
    local STEP = 16
    -- |v| = 58: inside every ceiling, so only the position step decides.
    local moving = { vx = 50, vz = 30 }

    -- A thrown NPC: the jump from the hand and the rest of the arc keep the pace.
    local titan = carryFixture()
    local token = claim(titan, "npc", 5)
    sample(titan, token, { x = 1, z = 0 })
    clear(coreCalls)
    local x = 1
    for step = 1, 10 do
        now = now + 0.05
        x = x + STEP
        sample(titan, token, merge({ x = x, z = 0, phase = "flight" }, moving))
        assert(titan.carry and titan.carry.pose.x == x and titan.carry.violations == 0, "NPC flight step " .. step)
    end
    assert(titan.carry.phase == "flight" and titan.lastCarryReject == nil)
    assert(#calls("updateCarry") == 10 and world.npc[5].x == x and claims["npc:5"].phase == "flight")

    -- A thrown vehicle: the jump from the hand is refused ...
    titan = carryFixture()
    token = claim(titan, "vehicle", 9)
    sample(titan, token, { x = 1, y = 6, z = 0 })
    clear(coreCalls)
    now = now + 0.05
    sample(titan, token, merge({ x = 1 + STEP, y = 6, z = 0, phase = "flight" }, moving))
    assert(titan.lastCarryReject == "speed" and titan.carry.phase == "hold" and titan.carry.pose.x == 1)
    assert(#calls("updateCarry") == 0 and titan.carry.violations == 1)
    -- ... a step inside the vehicle's own ceiling is still a flight ...
    now = now + 0.05
    sample(titan, token, merge({ x = 7, y = 6, z = 0, phase = "flight" }, moving))
    assert(titan.carry.phase == "flight" and titan.carry.pose.x == 7 and titan.carry.violations == 0)
    -- ... and mid-flight the 160 m/s step is refused all the same.
    now = now + 0.05
    sample(titan, token, merge({ x = 7 + STEP, y = 6, z = 0, phase = "flight" }, moving))
    assert(titan.lastCarryReject == "speed" and titan.carry.pose.x == 7 and titan.carry.violations == 1)
    assert(#calls("updateCarry") == 1 and claims["vehicle:9"].phase == "flight")

    -- A held NPC: walked across the Titan within the hand's pace, the 16 m step is no hand's.
    titan = carryFixture()
    token = claim(titan, "npc", 5)
    for _, at in ipairs({ -4, -10 }) do
        now = now + 0.05
        sample(titan, token, { x = at, z = 0 })
    end
    assert(titan.carry.pose.x == -10 and titan.carry.violations == 0 and titan.carry.phase == "hold")
    clear(coreCalls)
    now = now + 0.05
    sample(titan, token, merge({ x = -10 + STEP, z = 0 }, moving))
    assert(titan.lastCarryReject == "speed" and titan.carry.pose.x == -10 and titan.carry.phase == "hold")
    assert(#calls("updateCarry") == 0 and world.npc[5].x == -10 and titan.carry.violations == 1)
    assert(forbidden == 0)
end)

test("a thrown NPC's flight stays bounded by 200 m/s plus the gravity of the flight so far, plus the slack", function()
    local limits = T.limits
    local titan = carryFixture()
    local token = claim(titan, "npc", 5)
    sample(titan, token, { x = 1, z = 0 })
    clear(coreCalls)
    -- The throw itself, 0.1 s after the hand: no gravity has accrued, so 200 m/s * 0.1 s + the slack is all.
    now = now + 0.05
    sample(titan, token, { x = 1 + limits.carryNpcFlightSpeed * 0.1 + limits.carrySlack + 0.5, z = 0, phase = "flight" })
    assert(titan.lastCarryReject == "speed" and titan.carry.phase == "hold" and #calls("updateCarry") == 0)
    -- The authored 160 m/s throw is inside it.
    now = now + 0.05
    sample(titan, token, { x = 17, z = 0, phase = "flight" })
    assert(titan.carry.phase == "flight" and titan.carry.pose.x == 17 and titan.carry.violations == 0)
    -- One second into the flight the ceiling is (200 + 9.81 * 1) m/s over the 1 s gap bound, plus the slack.
    now = now + 0.95
    local ceiling = (limits.carryNpcFlightSpeed + limits.carryGravity * 1) * 1 + limits.carrySlack
    sample(titan, token, { x = 17 + ceiling + 0.5, z = 0, phase = "flight" })
    assert(titan.lastCarryReject == "speed" and titan.carry.pose.x == 17 and titan.carry.violations == 1)
    assert(#calls("updateCarry") == 1)
    -- A step over the base alone but inside the gravity allowance is a believable fall.
    local beyondBase = limits.carryNpcFlightSpeed + limits.carrySlack + 3
    sample(titan, token, { x = 17 + beyondBase, z = 0, phase = "flight" })
    assert(titan.carry.pose.x == 17 + beyondBase and titan.carry.violations == 0 and #calls("updateCarry") == 2)
end)

test("newest-first dispatch: a release carries the final pose and ends the claim before the frames it overtakes", function()
    local titan = carryFixture()
    local token = claim(titan, "npc", 5)
    clear(coreCalls)
    local staleBefore = S.stats.carryStale
    now = now + 0.1
    local f1 = carryMessage("carry_frame", titan, token, nil, { x = 1, z = 1 })
    local f2 = carryMessage("carry_frame", titan, token, nil, { x = 2, z = 1.5 })
    local f3 = carryMessage("carry_frame", titan, token, nil, { x = 3, z = 2 })
    local last = carryMessage("carry_release", titan, token, { reason = "landed" }, { x = 4, z = 2.5 })
    -- All four arrive in one host tick: the host runs the newest first.
    for _, message in ipairs({ last, f3, f2, f1 }) do fire(T.event.carry, 1, message) end
    local updates = calls("updateCarry")
    assert(#updates == 1 and updates[1].pose.x == 4 and updates[1].pose.z == 2.5, "the final pose is what the release said")
    assert(#calls("endCarry") == 1 and calls("endCarry")[1].token == token)
    assert(world.npc[5].x == 4 and next(claims) == nil and next(S.bodies) == nil)
    local ended = messages(1, "carry_ended")
    assert(#ended == 1 and ended[1].reason == "landed" and ended[1].token == token)
    assert(S.stats.carryStale == staleBefore + 3 and #messages(1, "error") == 0, "the overtaken frames are dropped without penalty")

    -- A release older than what was accepted still ends the claim; its pose is not applied.
    titan = carryFixture()
    token = claim(titan, "npc", 5)
    clear(coreCalls)
    sample(titan, token, { x = 1, z = 1 }); sample(titan, token, { x = 2, z = 1 }); sample(titan, token, { x = 3, z = 1 })
    now = now + 0.05
    local older = carryMessage("carry_release", titan, token, { seq = 2, reason = "interrupted" }, { x = 9, z = 9 })
    fire(T.event.carry, 1, older)
    assert(#calls("updateCarry") == 3 and #calls("endCarry") == 1 and world.npc[5].x == 3)
    assert(lastMessage(1, "carry_ended").reason == "interrupted" and titan.carry == nil)

    -- A final pose outside the envelope is not applied either, but the claim is still over.
    titan = carryFixture()
    token = claim(titan, "npc", 5)
    clear(coreCalls)
    sample(titan, token, { x = 1, z = 1 })
    release(titan, token, { x = 40, z = 0 })
    assert(#calls("updateCarry") == 1 and #calls("endCarry") == 1 and world.npc[5].x == 1 and titan.carry == nil)
end)

-- A thrown person's flight messages and its release carry the owner's release (carryLaunch in server.lua): the first
-- accepted one fixes it for the claim, every later one repeats it.
local function thrownFixture()
    local titan = carryFixture()
    local token = claim(titan, "npc", 5)
    local held = sample(titan, token, { x = 1, z = 1 })
    clear(coreCalls)
    return titan, token, held
end
local function flightPose(x) return { x = x or 2, y = 0, z = 3, vx = 10, vz = 5, phase = "flight" } end
-- A release made with the next message (and so 0 s before it), with `overrides` laid over it.
local function releaseAt(held, overrides) return merge(launchOf({ t = held.t + 0.05 }), overrides) end
local function sameRelease(given, wire, field)
    assert(given[field] == wire[field], field .. ": " .. tostring(given[field]) .. " ~= " .. tostring(wire[field]))
end

test("a thrown person's release is fixed by its first accepted flight message, handed to the platform with its age and repeated unchanged", function()
    local titan, token, held = thrownFixture()
    -- Only a flight carries one: a hold with a release is no message at all.
    local rejected = S.stats.carryRejected
    sample(titan, token, { x = 1, z = 1 }, { launch = launchOf({ t = held.t }) })
    assert(S.stats.carryRejected == rejected + 1 and #calls("updateCarry") == 0 and titan.carry.violations == 0)
    -- The release was made 0.1 s before the first message that reports it.
    now = now + 0.05
    local first = carryMessage("carry_frame", titan, token, { t = held.t + 0.4, launch = launchOf({ t = held.t + 0.3 }) }, flightPose(2))
    carryClock[token] = first.t
    fire(T.event.carry, 1, first)
    local updates = calls("updateCarry")
    assert(#updates == 1 and updates[1].pose.phase == "flight" and titan.carry.phase == "flight" and titan.carry.violations == 0)
    local given = updates[1].launch
    assert(given.t == nil, "the controller's clock stays on this side")
    assert(math.abs(given.elapsed - 0.1) < 1e-9, "the platform is told the release's age, not a time of its own: " .. tostring(given.elapsed))
    for _, field in ipairs(PLATFORM_LAUNCH) do sameRelease(given, first.launch, field) end
    assert(titan.carry.launch.t == held.t + 0.3 and claims["npc:5"].launch.iy == 912)
    -- Every later flight message repeats it, and the platform is told its age afresh.
    for step = 1, 3 do
        now = now + 0.05
        local message = sample(titan, token, flightPose(2 + step))
        local again = calls("updateCarry")[#calls("updateCarry")].launch
        assert(titan.carry.pose.x == 2 + step and titan.carry.violations == 0)
        assert(math.abs(again.elapsed - (message.t - (held.t + 0.3))) < 1e-9)
        for _, field in ipairs(PLATFORM_LAUNCH) do sameRelease(again, first.launch, field) end
    end
    -- ... and so does the release that ends the claim.
    now = now + 0.05
    local last = release(titan, token, flightPose(6))
    updates = calls("updateCarry")
    assert(#updates == 5 and updates[5].pose.x == 6 and math.abs(updates[5].launch.elapsed - (last.t - (held.t + 0.3))) < 1e-9)
    assert(#calls("endCarry") == 1 and titan.carry == nil and next(claims) == nil)

    -- The release ends with its claim: the next claim on the same body starts with none and fixes its own.
    refresh(titan)
    local again = claim(titan, "npc", 5)
    assert(again ~= token and titan.carry.launch == nil)
    local hold = sample(titan, again, { x = 1, z = 1 })
    sample(titan, again, flightPose(2), { launch = launchOf({ t = hold.t + 0.05, ix = 5 }) })
    assert(titan.carry.phase == "flight" and titan.carry.launch.ix == 5 and claims["npc:5"].launch.ix == 5)

    -- A vehicle's flight and a hold carry none: the platform is given none, and a vehicle's flight with one is refused.
    titan = carryFixture()
    token = claim(titan, "vehicle", 9)
    sample(titan, token, { x = 1, y = 6, z = 0 })
    now = now + 0.05
    sample(titan, token, { x = 2, y = 6, z = 1, vx = 5, phase = "flight" })
    updates = calls("updateCarry")
    assert(#updates == 2 and updates[1].launch == nil and updates[2].launch == nil and titan.carry.phase == "flight")
    sample(titan, token, { x = 3, y = 6, z = 1, vx = 5, phase = "flight" }, { launch = launchOf({ t = 0 }) })
    assert(titan.lastCarryReject == "launch_unexpected" and #calls("updateCarry") == 2 and titan.carry.pose.x == 2)
    assert(titan.carry.launch == nil and claims["vehicle:9"].launch == nil)
end)

test("a thrown person's flight without its release, with another one or an impossible one is refused before the platform", function()
    local lag = T.limits.carryLaunchLag
    -- `wire`: the shared validator drops it before this resource looks at the claim; otherwise it is a refused sample.
    local function refused(name, reason, extra, wire)
        local titan, token, held = thrownFixture()
        local rejected = S.stats.carryRejected
        now = now + 0.05
        sample(titan, token, flightPose(2), type(extra) == "function" and extra(held) or extra)
        assert(#calls("updateCarry") == 0 and #calls("endCarry") == 0 and titan.carry.phase == "hold", name)
        assert(claims["npc:5"].phase == "hold" and claims["npc:5"].launch == nil and titan.carry.launch == nil, name)
        assert(S.stats.carryRejected == rejected + 1, name)
        if wire then
            assert(titan.carry.violations == 0 and titan.lastCarryReject == nil, name)
        else
            assert(titan.carry.violations == 1 and titan.lastCarryReject == reason, name .. ": " .. tostring(titan.lastCarryReject))
        end
    end
    refused("none", "launch_missing", { launch = DROP })
    refused("older than the claim's last hold sample", "launch_stale", function(held) return { launch = releaseAt(held, { t = held.t - 0.04 }) } end)
    refused("too long before its message", "launch_stale", function(held)
        return { t = held.t + lag + 0.2, launch = releaseAt(held, { t = held.t + 0.05 }) }
    end)
    refused("a root out of the Titan's reach", "launch_far", function(held) return { launch = releaseAt(held, { x = 12.5, px = 12.5 }) } end)
    refused("an impulse point out of the Titan's reach", "launch_far", function(held) return { launch = releaseAt(held, { x = 11.5, px = 12.8 }) } end)
    local wireCases = {
        { "later than its message", function(held) return { t = held.t + 0.5 } end },
        { "without a radius", { radius = DROP } }, { "without an impulse", { iz = DROP } }, { "not a number", { ix = 0 / 0 } },
        { "infinite", { py = math.huge } }, { "no impulse at all", { ix = 0, iy = 0, iz = 0 } }, { "an impulse past the bound", { iy = 1001 } },
        { "a radius past the bound", { radius = 11 } }, { "no radius", { radius = 0 } }, { "a negative delay", { delay = -0.01 } },
        { "a delay past the bound", { delay = 2 } }, { "a point away from its body", { pz = 5 } },
        { "a coordinate past the bound", { x = 1e7 } }, { "a yaw past the bound", { yaw = 4000 } }, { "a time before the clock", { t = -1 } },
        { "a foreign field", { spin = 1 } },
    }
    for _, case in ipairs(wireCases) do
        refused(case[1], nil, function(held)
            local overrides = type(case[2]) == "function" and case[2](held) or case[2]
            return { launch = releaseAt(held, overrides) }
        end, true)
    end
    refused("not a table", nil, { launch = "now" }, true)

    -- The age bound is the message's own: a release a little inside it is taken.
    local titan, token, held = thrownFixture()
    now = now + 0.05
    sample(titan, token, flightPose(2), { t = held.t + lag - 0.05, launch = releaseAt(held, { t = held.t + 0.05 }) })
    assert(titan.carry.phase == "flight" and #calls("updateCarry") == 1)
    assert(math.abs(calls("updateCarry")[1].launch.elapsed - (lag - 0.1)) < 1e-9)

    -- Once fixed, another release is refused whichever field it changes, and so is none; an identical one is taken.
    titan, token, held = thrownFixture()
    now = now + 0.05
    sample(titan, token, flightPose(2))
    local fixed = titan.carry.launch
    local accepted = #calls("updateCarry")
    assert(accepted == 1 and fixed)
    for _, field in ipairs({ "t", "x", "y", "z", "yaw", "px", "py", "pz", "ix", "iy", "iz", "radius", "delay" }) do
        local changed = merge({}, fixed)
        changed[field] = changed[field] + (field == "t" and -0.01 or 0.25)
        titan.lastCarryReject = nil
        now = now + 0.05
        sample(titan, token, flightPose(2), { launch = changed })
        assert(titan.lastCarryReject == "launch_changed" and #calls("updateCarry") == accepted and titan.carry.launch == fixed, field)
        now = now + 0.05
        sample(titan, token, flightPose(2))                                  -- the identical repeat is taken and ends the run of refusals
        accepted = accepted + 1
        assert(#calls("updateCarry") == accepted and titan.carry.violations == 0 and titan.carry.launch == fixed, field)
    end
    titan.lastCarryReject = nil
    now = now + 0.05
    sample(titan, token, flightPose(2), { launch = DROP })
    assert(titan.lastCarryReject == "launch_missing" and titan.carry.launch == fixed and #calls("updateCarry") == accepted)
end)

test("newest-first dispatch: a first flight message overtaken by the next one still gives the platform the release, with its true age", function()
    local titan, token, held = thrownFixture()
    local stale = S.stats.carryStale
    now = now + 0.1
    local at = held.t + 0.1
    local a = carryMessage("carry_frame", titan, token, { t = at + 0.05, launch = launchOf({ t = at }) }, flightPose(2))
    local b = carryMessage("carry_frame", titan, token, { t = at + 0.1, launch = launchOf({ t = at }) }, flightPose(3))
    for _, message in ipairs({ b, a }) do fire(T.event.carry, 1, message) end     -- one host tick: the newest first
    local updates = calls("updateCarry")
    assert(#updates == 1 and updates[1].pose.x == 3, "the newer message carried the throw on its own")
    assert(math.abs(updates[1].launch.elapsed - 0.1) < 1e-9, "the platform is told when the release was made, not when this message was")
    assert(S.stats.carryStale == stale + 1 and titan.carry.violations == 0 and #messages(1, "error") == 0, "the overtaken message costs nothing")
    assert(titan.carry.launch.t == at and titan.carry.phase == "flight" and claims["npc:5"].phase == "flight")

    -- A release that overtakes the flight carries the throw as well, and ends the claim after applying it.
    titan, token, held = thrownFixture()
    now = now + 0.1
    at = held.t + 0.1
    local frame = carryMessage("carry_frame", titan, token, { t = at + 0.05, launch = launchOf({ t = at }) }, flightPose(2))
    local done = carryMessage("carry_release", titan, token, { t = at + 0.1, launch = launchOf({ t = at }) }, flightPose(3))
    for _, message in ipairs({ done, frame }) do fire(T.event.carry, 1, message) end
    updates = calls("updateCarry")
    assert(#updates == 1 and updates[1].pose.x == 3 and math.abs(updates[1].launch.elapsed - 0.1) < 1e-9)
    assert(#calls("endCarry") == 1 and titan.carry == nil and next(claims) == nil and world.npc[5].x == 3)

    -- A release whose throw cannot be described is not applied, and the claim is over all the same.
    titan, token = thrownFixture()
    release(titan, token, flightPose(3), { launch = DROP })
    assert(#calls("updateCarry") == 0 and #calls("endCarry") == 1 and titan.carry == nil and next(claims) == nil)
end)

test("a stale or duplicate release cannot end a replacement claim", function()
    local titan = carryFixture()
    local first = claim(titan, "npc", 5)
    local stale = release(titan, first)
    assert(titan.carry == nil and next(claims) == nil)
    local second = claim(titan, "vehicle", 9)
    assert(second ~= first and titan.carry.token == second)
    clear(coreCalls)
    -- The controller re-sends its release (the queue was full), a replay of an old frame arrives.
    fire(T.event.carry, 1, stale)
    fire(T.event.carry, 1, carryMessage("carry_frame", titan, first))
    assert(#calls("endCarry") == 0 and #calls("updateCarry") == 0)
    assert(titan.carry and titan.carry.token == second and claims["vehicle:9"].token == second)
end)

test("carry samples have their own budget: they never spend the Titan's frames or one-shot events", function()
    local titan = carryFixture()
    local token = claim(titan, "npc", 5)
    titan.events.tokens, titan.events.rate = 0, 0
    titan.frames.tokens, titan.frames.rate = 0, 0
    local ok, why = publish(titan, { mode = "pilot", weapon = "fist" })
    assert(not ok and why == "rate_limited", "the Titan's own frames are out of budget")
    clear(coreCalls)
    for index = 1, 3 do sample(titan, token, { x = 1 + index * 0.1, z = 1 }) end
    assert(#calls("updateCarry") == 3 and titan.events.tokens == 0 and titan.frames.tokens == 0)

    -- The reverse: a flood of samples is shed at the stream's own bound (a burst of 5) ...
    titan = carryFixture()
    token = claim(titan, "npc", 5)
    clear(coreCalls)
    local dropped = S.stats.carryDropped
    now = now + 0.1
    for _ = 1, 10 do fire(T.event.carry, 1, carryMessage("carry_frame", titan, token, nil, { x = 1, z = 1 })) end
    assert(#calls("updateCarry") == 5 and S.stats.carryDropped == dropped + 5, "a burst of five, the rest shed")
    -- ... without starving the Titan's own stream ...
    assert(publish(titan, { mode = "pilot", weapon = "fist" }))
    for index = 1, 12 do
        fire(T.event.carry, 1, carryMessage("carry_frame", titan, token, { seq = 100 + index, t = 5 + index * 0.001 }, { x = 1, z = 1 }))
    end
    assert(#calls("updateCarry") == 6 and S.stats.carryDropped == dropped + 5 + 11, "the refill since the Titan's frame admits one")
    -- ... and a release is never rate limited.
    release(titan, token)
    assert(titan.carry == nil, "a release is honored whatever the sample budget")
end)

test("upkeep ends claims that stall or whose Titan went quiet, never one that is only old", function()
    local titan = carryFixture()
    local token = claim(titan, "npc", 5)
    now = now + 0.8
    keepAlive(titan)
    S.tick()
    assert(titan.carry, "a claim gets a second to receive its first sample")
    now = now + 0.3
    keepAlive(titan)
    S.tick()
    assert(titan.carry == nil and lastMessage(1, "carry_ended").reason == "claim_stalled")
    assert(#calls("endCarry") == 1 and next(claims) == nil and S.titans[1] == titan)

    -- A sample extends it.
    titan = carryFixture()
    token = claim(titan, "npc", 5)
    now = now + 0.8
    sample(titan, token, { x = 1, z = 1 })
    now = now + 0.8
    keepAlive(titan)
    S.tick()
    assert(titan.carry, "one second since the last ACCEPTED sample, not since the grant")

    -- Age alone ends nothing: a claim that is fed lives on ...
    titan = carryFixture()
    token = claim(titan, "npc", 5)
    local started = now
    for step = 1, 40 do
        now = now + 0.4
        keepAlive(titan)
        sample(titan, token, { x = 1 + (step % 2) * 0.1, z = 1 })
        S.tick()
        assert(titan.carry and titan.carry.violations == 0, "a fed hold ended at step " .. step)
    end
    assert(now - started > 17 and #messages(1, "carry_ended") == 0 and #calls("endCarry") == 0)
    -- ... and a hold that stops being fed ends at its stall, however old it is.
    now = now + 1.2
    keepAlive(titan)
    S.tick()
    assert(titan.carry == nil and lastMessage(1, "carry_ended").reason == "claim_stalled")
    assert(#calls("endCarry") == 1 and next(claims) == nil)

    -- The Titan's own stream going quiet while samples keep coming is a stalled Titan.
    titan = carryFixture()
    token = claim(titan, "npc", 5)
    for step = 1, 8 do
        now = now + 0.3
        sample(titan, token, { x = 1 + (step % 2) * 0.1, z = 1 })
    end
    S.tick()
    assert(titan.carry == nil and lastMessage(1, "carry_ended").reason == "titan_stalled" and S.titans[1] == titan)
    assert(next(claims) == nil)
end)

test("every way a Titan leaves gives the body back through endCarry, and tells the controller first", function()
    local exits = {
        { "owner_left", nil, function() fire("onPlayerDisconnected", nil, "1", "connection_closed") end },
        { "owner_dead", "carrier_dead", function()
            players[1].dead = true
            fire("onPlayerLifeStateChanged", nil, "1", "9", "dead", "pvp_damage")
        end },
        { "bucket_changed", "bucket_changed", function() fire("onPlayerBucketChange", nil, "1", 7, 0) end },
        { "bucket_changed", "bucket_changed", function() players[1].bucket = 5; S.tick() end },
        { "owner_left", nil, function() players[1] = nil; S.tick() end },
        { "owner_dead", "carrier_dead", function() players[1].dead = true; S.tick() end },
        { "owner_restarted", "titan_removed", function() ready(1) end },
        { "owner_stalled", "titan_stalled", function() now = now + 6; S.tick() end },
        { "owner_removed", "titan_removed", function() command(1, "remove") end },
        { "resource_stopped", "resource_stopped", function() fire("onResourceStop", nil, "op77_lightrp_titans") end },
    }
    for _, kind in ipairs({ "npc", "vehicle" }) do
        for index, exit in ipairs(exits) do
            local titan = carryFixture()
            local token = claim(titan, kind, kind == "npc" and 5 or 9)
            sample(titan, token, { x = 1, z = 1 })
            clear(sent); clear(coreCalls)
            exit[3]()
            local label = kind .. " exit #" .. index .. " (" .. exit[1] .. ")"
            assert(S.titans[1] == nil, "Titan still registered: " .. label)
            assert(next(claims) == nil and next(S.bodies) == nil and titan.carry == nil, "body not given back: " .. label)
            local ended = calls("endCarry")
            assert(#ended == 1 and ended[1].token == token and ended[1].kind == kind, "endCarry: " .. label)
            if exit[2] then
                local told = messages(1, "carry_ended")
                assert(#told == 1 and told[1].reason == exit[2] and told[1].token == token, "controller not told: " .. label)
                local endedAt, removedAt
                for position, event in ipairs(sent) do
                    local message = event.args[1]
                    if event.target == 1 and event.name == MSG then
                        if message.op == "carry_ended" then endedAt = position end
                        if message.op == "remove" then removedAt = position end
                    end
                end
                assert(endedAt and removedAt and endedAt < removedAt, "the end must precede the removal: " .. label)
            else
                assert(#messages(1, "carry_ended") == 0, "a player who left is not messaged: " .. label)
            end
            assert(titan.lastCarryEnd and titan.lastCarryEnd.endOk == true and titan.lastCarryEnd.kind == kind)
        end
    end
    assert(forbidden == 0)
end)

test("a failing platform ends the claim, restores the body and tells the controller", function()
    local cases = {
        { "claim_expired", "claim_expired" }, { "duration_exceeded", "flight_expired" }, { "superseded", "claim_lost" },
        { "npc_dead", "entity_died" }, { "wrong_bucket", "bucket_changed" }, { "invalid_pose", "pose_rejected" },
        { "something_new", "claim_lost" }, { "carrier_unavailable", "owner_unavailable" },
        { "launch_required", "pose_rejected" }, { "invalid_launch", "pose_rejected" }, { "launch_changed", "pose_rejected" },
    }
    for _, case in ipairs(cases) do
        local titan = carryFixture()
        local token = claim(titan, "npc", 5)
        updateRefusal = case[1]
        clear(coreCalls)
        sample(titan, token, { x = 1, z = 1 })
        assert(titan.carry == nil and next(S.bodies) == nil, case[1])
        assert(#calls("updateCarry") == 1 and #calls("endCarry") == 1, "update failures call endCarry: " .. case[1])
        local ended = lastMessage(1, "carry_ended")
        assert(ended and ended.reason == case[2] and ended.token == token, case[1] .. " -> " .. tostring(ended and ended.reason))
        assert(S.titans[1] == titan, "the Titan survives its body's claim")
    end
    -- A failure while releasing: the claim ends all the same.
    local titan = carryFixture()
    local token = claim(titan, "npc", 5)
    updateRefusal = "superseded"
    release(titan, token)
    assert(titan.carry == nil and next(claims) == nil and lastMessage(1, "carry_ended").reason == "claim_lost")
end)

test("platform events end the claim they name, and only that one", function()
    local titan = carryFixture()
    local token = claim(titan, "npc", 5)
    clear(coreCalls); clear(sent)
    fire("onNpcCarryEnded", nil, "5", "ffffffffffffffffffffffffffffffff", "superseded")   -- a stale claim's token
    fire("onNpcCarryEnded", nil, "6", token, "superseded")                                -- another body
    fire("onVehicleCarryEnded", nil, "5", token, "superseded")                            -- another registry
    fire("onNpcRemoved", nil, "6", "removed", "open77_npcs")
    fire("onNpcDied", nil, "99", "player:2", "bullet")
    assert(titan.carry and #messages(1, "carry_ended") == 0 and #calls("endCarry") == 0)
    fire("onNpcCarryEnded", nil, "5", token, "ttl_expired")
    assert(titan.carry == nil and next(S.bodies) == nil)
    assert(#calls("endCarry") == 0, "the platform already ended it: nothing to give back")
    local ended = messages(1, "carry_ended")
    assert(#ended == 1 and ended[1].reason == "claim_expired" and ended[1].token == token)

    -- The registries' removals and deaths: the claim goes, endCarry is asked (idempotent).
    for _, case in ipairs({
        { "npc", 5, function() fire("onNpcRemoved", nil, "5", "removed", "open77_npcs") end, "entity_removed" },
        { "npc", 5, function() fire("onNpcDied", nil, "5", "player:2", "bullet") end, "entity_died" },
        { "vehicle", 9, function() fire("onVehicleRemoved", nil, "9", 3) end, "entity_removed" },
        { "vehicle", 9, function() fire("onVehicleCarryEnded", nil, "9", "x", "occupied") end, nil },
    }) do
        titan = carryFixture()
        token = claim(titan, case[1], case[2])
        clear(coreCalls); clear(sent)
        case[3]()
        if case[4] then
            assert(titan.carry == nil and lastMessage(1, "carry_ended").reason == case[4], case[4])
            assert(#calls("endCarry") == 1 and next(claims) == nil)
        else
            assert(titan.carry, "an end naming another token is ignored")
        end
    end
end)

test("a Titan that stops wielding the fist, or is called down or ejected, lets go of its body", function()
    for _, change in ipairs({ { weapon = "rail" }, { mode = "eject" }, { mode = "pilot", weapon = "sword" } }) do
        local titan = carryFixture()
        local token = claim(titan, "npc", 5)
        clear(coreCalls)
        assert(publish(titan, merge({ mode = "pilot", weapon = "fist" }, change)))
        assert(titan.carry == nil and next(claims) == nil and #calls("endCarry") == 1)
        assert(lastMessage(1, "carry_ended").reason == "interrupted" and lastMessage(1, "carry_ended").token == token)
        assert(S.titans[1] == titan)
    end
    -- Staying in the fist does not.
    local titan = carryFixture()
    claim(titan, "npc", 5)
    assert(publish(titan, { mode = "pilot", weapon = "fist" }))
    assert(titan.carry)
    -- Nor does the weapon coming back while the thrown body flies: the flight is no longer in the hand.
    titan = carryFixture()
    local token = claim(titan, "npc", 5)
    sample(titan, token, { x = 1, z = 1 })
    now = now + 0.05
    sample(titan, token, { x = 2, z = 3, vx = 10, vz = 5, phase = "flight" })
    assert(titan.carry.phase == "flight")
    clear(coreCalls)
    assert(publish(titan, { mode = "pilot", weapon = "xo16" }))
    assert(titan.carry and #calls("endCarry") == 0)
end)

test("diagnostics show the accepted claim, the platform's own view of it, and what ended it", function()
    local titan = carryFixture()
    command(1, "status")
    assert(lastReply(1)[3]:find("carry=none", 1, true) and not lastReply(1)[3]:find("last=", 1, true))
    local token = claim(titan, "npc", 5)
    sample(titan, token, { x = 1.5, y = 0.5, z = 2 })
    command(1, "status")
    local text = lastReply(1)[3]
    assert(text:find("carry=npc:5 phase=hold accepted=1", 1, true), text)
    assert(text:find("pose=1.5,0.5,2.0", 1, true) and text:find("platform=agrees", 1, true), text)
    local state = S.carryReport(titan)
    assert(state.active and state.token == token and state.pose.x == 1.5 and state.accepted == 1)
    assert(state.platform.carrier == 1 and state.platform.token == token and state.platformAgrees == true)
    -- The accepted record and the platform's authority diverging is visible, not hidden.
    claims["npc:5"].token = "someone-elses"
    assert(S.carryReport(titan).platformAgrees == false)
    command(1, "status")
    assert(lastReply(1)[3]:find("platform=DISAGREES", 1, true))
    claims["npc:5"].token = token
    release(titan, token, { x = 1.6, y = 0.5, z = 2 }, { reason = "landed" })
    command(1, "status")
    assert(lastReply(1)[3]:find("carry=none last=npc:5/landed", 1, true), lastReply(1)[3])
    assert(S.carryReport(titan).last.endOk == true and S.carryReport(titan).last.pose.x == 1.6)
    -- A refusal is visible too.
    request(titan, "npc", 99)
    assert(S.carryReport(titan).denied.reason == "target_missing" and S.carryReport(titan).denied.entityId == "99")
end)

test("/titan action grab triggers the controller's real grab, and only from the fist", function()
    reset(); carryWorld(); ready(1)
    local titan = spawn(1)
    clear(sent)
    command(1, "action", "grab")
    assert(lastReply(1)[2] == false and #messages(1, "command") == 0, "no controller yet")
    assert(publish(titan, { weapon = "xo16" }))
    now = now + 5
    clear(sent)
    command(1, "action", "grab")
    assert(lastReply(1)[2] == false and lastReply(1)[3]:find("fist", 1, true) and #messages(1, "command") == 0)
    assert(publish(titan, { weapon = "fist" }))
    now = now + 5
    clear(sent)
    command(1, "action", "grab")
    local sentCommands = messages(1, "command")
    assert(#sentCommands == 1 and sentCommands[1].action == "action" and sentCommands[1].value == "grab")
    assert(T.normalizeServerMessage(sentCommands[1], Open77TitanCatalog), "the controller's validator accepts it")
    assert(T.actions.grab == true and T.usage:find("grab", 1, true))
end)

test("the carry wire is a closed schema: native ids only toward the client, canonical ids only toward the server", function()
    local function request(extra) return merge({ v = T.protocol, op = "carry_request", id = "9", epoch = 1, request = 1, kind = "npc" }, extra) end
    for _, entity in ipairs({ "1", "9007199254740993", "9223372036854775808", "18446744073709551615" }) do
        local clean = T.normalizeControllerCarry(request({ entity = entity }))
        assert(clean and clean.entity == entity and type(clean.entity) == "string", entity)
    end
    for _, entity in ipairs({ "18446744073709551616", "99999999999999999999", "123456789012345678901", "0", "007", "-1",
        "1.5", "0x10", " 1", "1 ", "", "1e3", 12, 1.5e19, true }) do
        assert(T.normalizeControllerCarry(request({ entity = entity })) == nil, "accepted entity " .. tostring(entity))
    end
    assert(T.normalizeControllerCarry(request({})) == nil, "a request without a native id")
    assert(T.normalizeControllerCarry(request({ entity = "5", entityId = "5" })) == nil)
    -- Toward the server the NATIVE field does not exist.
    assert(T.normalizeServerCarry(request({ entityId = "12" })).entityId == "12")
    assert(T.normalizeServerCarry(request({ entity = "12" })) == nil)
    assert(T.normalizeServerCarry(request({ entityId = "12", entity = "12" })) == nil)
    for _, entityId in ipairs({ "1.5", "0", "5x", 12, "12345678901234567" }) do
        assert(T.normalizeServerCarry(request({ entityId = entityId })) == nil, tostring(entityId))
    end

    -- The pose: a unit quaternion within tolerance is renormalized; everything else is refused.
    local function pose(extra) return poseOf(extra) end
    local clean = T.normalizeCarryPose(pose({ qw = 1.005 }))
    assert(clean and math.abs(clean.qx ^ 2 + clean.qy ^ 2 + clean.qz ^ 2 + clean.qw ^ 2 - 1) < 1e-12)
    assert(T.normalizeCarryPose(pose({ qw = 1.05 })) == nil and T.normalizeCarryPose(pose({ qw = 0 })) == nil)
    local input = pose()
    assert(T.normalizeCarryPose(input) ~= input, "a copy, never the input")

    -- Server -> controller.
    local TOKEN = string.rep("a", 32)
    local grant = { v = T.protocol, op = "carry_grant", id = "9", epoch = 1, request = 3, kind = "vehicle", entityId = "7", token = TOKEN }
    assert(T.normalizeServerMessage(grant, Open77TitanCatalog).token == TOKEN)
    for _, broken in ipairs({ { token = "has space" }, { token = "" }, { token = string.rep("a", 65) }, { kind = "prop" },
        { entityId = "07" }, { request = 0 }, { epoch = 0 }, { extra = 1 }, { token = DROP } }) do
        assert(T.normalizeServerMessage(merge(merge({}, grant), broken), Open77TitanCatalog) == nil, "accepted " .. next(broken))
    end
    local denial = { v = T.protocol, op = "carry_denied", id = "9", epoch = 1, request = 3, reason = "not_networked" }
    assert(T.normalizeServerMessage(denial, Open77TitanCatalog).reason == "not_networked")
    assert(T.normalizeServerMessage(merge(merge({}, denial), { reason = "os.execute" }), Open77TitanCatalog) == nil)
    local ended = { v = T.protocol, op = "carry_ended", id = "9", epoch = 1, token = TOKEN, reason = "landed" }
    assert(T.normalizeServerMessage(ended, Open77TitanCatalog).reason == "landed")
    assert(T.normalizeServerMessage(merge(merge({}, ended), { reason = "x y" }), Open77TitanCatalog) == nil)
    for reason in pairs(T.carryReleaseReasons) do assert(T.carryReasons[reason], reason) end
    assert(forbidden == 0, "no carry path ever mutated a body by any other API")
end)

-- ---------------------------------------------------------------------------
-- The server-controlled loadout: every authored upgrade at its maximum by default, changed
-- only by server Lua through the exports. Nothing here re-tests loadout.lua's own rules;
-- these drive what this resource does with them.
-- ---------------------------------------------------------------------------
local X = exported
local SPEC = X.getLoadoutSpec()

local function copyMap(map)
    local copy = {}
    for key, value in pairs(map) do copy[key] = value end
    return copy
end
local function sameMap(a, b)
    for key, value in pairs(a) do if b[key] ~= value then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
-- Everything the server sent on the bridge event with this op, whoever it was for.
local function toAnyone(op)
    local list = {}
    for _, event in ipairs(sent) do
        if event.name == MSG and event.args[1].op == op then list[#list + 1] = event end
    end
    return list
end
local function opsTo(target)
    local ops = {}
    for _, message in ipairs(messages(target)) do ops[#ops + 1] = message.op end
    return table.concat(ops, ",")
end

-- What a malformed, hostile or merely careless server resource could pass as overrides / changes.
local BAD_MAPS = {
    { nope = 1 }, { sentry = 2 }, { sentry = -1 }, { sentry = 0.5 }, { sentry = 0 / 0 }, { sentry = math.huge },
    { sentry = -math.huge }, { sentry = "0" }, { sentry = true }, { sentry = {} }, { [1] = 0 }, { sentry = 0, nope = 0 },
    { burstcore = 4 }, "sentry", 42, true, false,
    setmetatable({ sentry = 0 }, {}),
    setmetatable({}, { __index = function() error("executed") end }),
    setmetatable({}, { __pairs = function() error("executed") end }),
}

test("every spawn route grants the full authored loadout to the owner alone, as a fresh map", function()
    reset(); withViewers(1, 2, 3)
    assert(SPEC.sentry == 1 and SPEC.burstcore == 3, "the default is every perk at its maximum")
    local routes = {
        function() command(1, "spawn") end,                   -- /titan spawn
        function() fire(T.event.request, 2, "spawn") end,     -- the controller's own call key
        function() assert(T.isId(X.spawn(3))) end,            -- server Lua, no overrides
    }
    for owner, route in ipairs(routes) do
        route()
        local titan = S.titans[owner]
        assert(titan and titan.revision == 1 and sameMap(titan.loadout, SPEC), "route " .. owner)
        local grants = messages(owner, "grant")
        assert(#grants == 1 and grants[1].revision == 1 and sameMap(grants[1].loadout, SPEC), "grant of route " .. owner)
        assert(T.normalizeServerMessage(grants[1], Open77TitanCatalog), "the controller's validator accepts the grant")
        assert(sameMap(X.getLoadout(owner), SPEC))
    end
    assert(S.titans[3].id == messages(3, "grant")[1].id)
    -- Every grant is addressed to the very player it names, and the two direct routes command the spawn.
    local grants = toAnyone("grant")
    assert(#grants == 3)
    for _, event in ipairs(grants) do assert(event.args[1].owner == tostring(event.target)) end
    assert(#messages(1, "command") == 1 and #messages(2, "command") == 0 and #messages(3, "command") == 1)
end)

test("spawn overrides are sparse over the defaults; a bad one is refused before anything is created or counted", function()
    reset(); ready(1); ready(2); ready(3)
    local serial = kvpStore["titans.serial"] or 0
    clear(sent)
    for index, overrides in ipairs(BAD_MAPS) do
        local id, why = X.spawn(1, overrides)
        assert(id == nil and type(why) == "string", "accepted overrides #" .. index)
        assert(S.titans[1] == nil and #sent == 0 and kvpStore["titans.serial"] == serial, "overrides #" .. index .. " left a trace")
    end
    local id = X.spawn(1, { sentry = 0, burstcore = 2 })
    assert(id and tonumber(id) == serial + 1, "a refused override must not have consumed a Titan id")
    local expected = copyMap(SPEC)
    expected.sentry, expected.burstcore = 0, 2
    local titan = S.titans[1]
    assert(titan.id == id and titan.revision == 1 and sameMap(titan.loadout, expected))
    assert(sameMap(messages(1, "grant")[1].loadout, expected) and sameMap(X.getLoadout(1), expected))
    -- The caller keeps its own table.
    local overrides = { burstcore = 1 }
    assert(X.spawn(2, overrides))
    overrides.burstcore = 3
    assert(S.titans[2].loadout.burstcore == 1 and X.getLoadout(2).burstcore == 1)

    -- The existing admission applies to this route too, and refuses before anything changes.
    local nilId, why = X.spawn(1)
    assert(nilId == nil and why == "already_spawned")
    players[3].dead = true
    nilId, why = X.spawn(3)
    assert(nilId == nil and why == "owner_dead")
    players[3].dead, players[3].fresh = false, false
    nilId, why = X.spawn(3)
    assert(nilId == nil and why == "owner_unavailable")
    players[3].fresh, S.clients[3].bridge = true, false
    nilId, why = X.spawn(3)
    assert(nilId == nil and why == "bridge_unavailable")
    S.clients[3].bridge = true
    local limit = T.limits.titans
    T.limits.titans = 2
    nilId, why = X.spawn(3)
    T.limits.titans = limit
    assert(nilId == nil and why == "titan_limit")
    serial = kvpStore["titans.serial"]
    kvpFail = true
    nilId, why = X.spawn(3)
    kvpFail = false
    assert(nilId == nil and why == "id_unavailable")
    assert(S.titans[3] == nil and #messages(3, "grant") == 0, "a refused spawn created a Titan")
    assert(X.spawn(3) and kvpStore["titans.serial"] == serial + 1)

    -- The player is a number the caller supplies: never text, a table or a console id.
    S.removeTitan(S.titans[3], "owner_removed")
    clear(sent)
    for _, player in ipairs({ "3", "x", 0, -1, 1.5, 0 / 0, math.huge, 2 ^ 40, true, {} }) do
        local result, reason = X.spawn(player)
        assert(result == nil and reason == "invalid_player", tostring(player))
    end
    local result, reason = X.spawn(nil)
    assert(result == nil and reason == "invalid_player")
    assert(S.titans[3] == nil and S.titans[0] == nil and #sent == 0)
end)

test("setLoadout changes only what it names, advances a per-Titan revision and tells the owner alone", function()
    reset(); withViewers(1, 2, 3)
    local a, b = spawn(1), spawn(2)
    observers[1] = { 1, 2, 3 }
    assert(publish(a) and publish(b)); S.reconcile(a)
    clear(sent)
    local result = X.setLoadout(1, { sentry = 0, burstcore = 1 })
    local expected = copyMap(SPEC)
    expected.sentry, expected.burstcore = 0, 1
    assert(sameMap(result, expected) and sameMap(a.loadout, expected) and a.revision == 2)
    local updates = messages(1, "loadout")
    assert(#updates == 1 and #toAnyone("loadout") == 1, "only the owner is told")
    local update = updates[1]
    assert(update.v == T.protocol and update.id == a.id and update.epoch == a.epoch and update.revision == 2)
    assert(sameMap(update.loadout, expected))
    assert(T.normalizeServerMessage(update, Open77TitanCatalog), "the controller's validator accepts the update")
    assert(#toAnyone("state") == 0 and #toAnyone("grant") == 0, "an update is not a state or a grant")
    assert(b.revision == 1 and sameMap(b.loadout, SPEC) and sameMap(X.getLoadout(2), SPEC), "another Titan was touched")

    -- A sparse change keeps what it does not name.
    result = X.setLoadout(1, { burstcore = 3 })
    expected.burstcore = 3
    assert(sameMap(result, expected) and a.revision == 3 and messages(1, "loadout")[2].revision == 3)
    -- An empty change is valid and still the owner's newest word.
    result = X.setLoadout(1, {})
    assert(sameMap(result, expected) and a.revision == 4 and #messages(1, "loadout") == 3)
    -- A perk can be given back.
    result = X.setLoadout(1, { sentry = 1 })
    assert(result.sentry == 1 and a.revision == 5 and X.getLoadout(1).sentry == 1)

    -- A Titan still waiting for its controller gets the update right behind its grant.
    reset(); ready(1)
    local waiting = spawn(1)
    assert(X.setLoadout(1, { sentry = 0 }) and waiting.active == false and waiting.revision == 2)
    assert(opsTo(1) == "session,grant,command,loadout", opsTo(1))
end)

test("invalid, unknown, out-of-range and nonfinite changes, and bad targets, are refused and change nothing", function()
    reset(); ready(1); ready(2)
    local a, b = spawn(1), spawn(2)
    assert(X.setLoadout(1, { sentry = 0 }))             -- a non-default state to protect
    local before, revision = copyMap(a.loadout), a.revision
    clear(sent)
    for index, changes in ipairs(BAD_MAPS) do
        local result, why = X.setLoadout(1, changes)
        assert(result == nil and type(why) == "string", "accepted changes #" .. index)
        assert(sameMap(a.loadout, before) and a.revision == revision, "changes #" .. index .. " moved the record")
    end
    local result, why = X.setLoadout(1)
    assert(result == nil and type(why) == "string")
    -- A patch is all or nothing.
    result, why = X.setLoadout(1, { burstcore = 0, nope = 1 })
    assert(result == nil and sameMap(a.loadout, before) and a.revision == revision)
    assert(#sent == 0 and a.carry == nil, "a refused change must tell nobody")
    assert(sameMap(b.loadout, SPEC) and b.revision == 1)

    -- The target is a player number: never text, never a Titan nobody owns.
    for _, target in ipairs({ "1", "2", 0, -1, 1.5, 0 / 0, math.huge, 2 ^ 40, true, {} }) do
        result, why = X.setLoadout(target, { sentry = 1 })
        assert(result == nil and why == "invalid_player", tostring(target))
        result, why = X.getLoadout(target)
        assert(result == nil and why == "invalid_player", tostring(target))
        result, why = X.remove(target)
        assert(result == nil and why == "invalid_player", tostring(target))
    end
    result, why = X.setLoadout(nil, { sentry = 1 })
    assert(result == nil and why == "invalid_player")
    result, why = X.setLoadout(3, { sentry = 1 })
    assert(result == nil and why == "no_titan")
    result, why = X.getLoadout(3)
    assert(result == nil and why == "no_titan")
    result, why = X.remove(3)
    assert(result == nil and why == "no_titan")
    assert(S.titans[1] == a and S.titans[2] == b and #sent == 0)
    assert(sameMap(a.loadout, before) and a.revision == revision and sameMap(b.loadout, SPEC) and b.revision == 1)
end)

test("nothing returned, sent or accepted aliases the Titan's record", function()
    reset(); ready(1)
    local titan = spawn(1)
    local grant = messages(1, "grant")[1]
    grant.loadout.sentry = 0                         -- the message in flight is the host's, not the record's
    assert(titan.loadout.sentry == 1)
    local read = X.getLoadout(1)
    read.sentry, read.stray = 0, true
    assert(sameMap(X.getLoadout(1), SPEC) and titan.loadout.stray == nil)
    local spec = X.getLoadoutSpec()
    spec.sentry = 0
    assert(X.getLoadoutSpec().sentry == 1 and T.loadout.max.sentry == 1 and T.loadout.defaults().sentry == 1)
    local changes = { sentry = 0 }
    local result = X.setLoadout(1, changes)
    changes.sentry, changes.burstcore = 1, 0         -- the caller keeps editing its own table
    result.burstcore = 0
    assert(titan.loadout.sentry == 0 and titan.loadout.burstcore == SPEC.burstcore)
    local update = messages(1, "loadout")[1]
    update.loadout.burstcore = 0
    assert(titan.loadout.burstcore == SPEC.burstcore)
    S.removeTitan(titan, "owner_removed")
    now = now + 2
    assert(sameMap(spawn(1).loadout, SPEC), "a new Titan starts from the untouched defaults")
end)

test("a loadout lives and dies with its Titan: every exit resets it, and no update reaches the next one", function()
    local exits = {
        { "export remove", function() assert(X.remove(1) == true) end },
        { "/titan remove", function() command(1, "remove") end },
        { "owner death", function() players[1].dead = true; fire("onPlayerLifeStateChanged", nil, "1", "9", "dead", "x") end },
        { "bucket change", function() fire("onPlayerBucketChange", nil, "1", 7, 0) end },
        { "client restart", function() ready(1) end },
        { "disconnect", function() fire("onPlayerDisconnected", nil, "1", "connection_closed"); ready(1) end },
        { "silent controller", function() now = now + 21; S.tick() end },
    }
    for _, exit in ipairs(exits) do
        local label = exit[1]
        reset(); ready(1)
        local old = spawn(1)
        assert(X.setLoadout(1, { sentry = 0, burstcore = 0 }) and old.revision == 2, label)
        exit[2]()
        assert(S.titans[1] == nil, label)
        local gone, why = X.getLoadout(1)
        assert(gone == nil and why == "no_titan", label)
        clear(sent)
        local late, lateWhy = X.setLoadout(1, { sentry = 1 })
        assert(late == nil and lateWhy == "no_titan" and #toAnyone("loadout") == 0, label .. ": a dead Titan took an update")
        assert(select(2, X.remove(1)) == "no_titan", label)
        players[1].dead = false                  -- the owner respawned
        now = now + 2
        local fresh = spawn(1)
        assert(fresh and fresh ~= old and fresh.id ~= old.id and fresh.revision == 1 and sameMap(fresh.loadout, SPEC), label)
        assert(sameMap(messages(1, "grant")[1].loadout, SPEC) and #messages(1, "loadout") == 0, label)
    end
end)

test("Titans never share loadout state: one owner's change, removal or refusal never reaches another's", function()
    reset(); withViewers(1, 2)
    local a, b = spawn(1), spawn(2)
    assert(X.setLoadout(2, { burstcore = 0 }) and X.setLoadout(1, { sentry = 0 }))
    assert(a.loadout.burstcore == SPEC.burstcore and b.loadout.sentry == SPEC.sentry and a.revision == 2 and b.revision == 2)
    assert(messages(1, "loadout")[1].id == a.id and messages(2, "loadout")[1].id == b.id)
    assert(X.remove(1) == true)
    assert(S.titans[2] == b and b.revision == 2 and b.loadout.burstcore == 0 and b.loadout.sentry == SPEC.sentry)
    now = now + 2
    local c = spawn(1)
    assert(c.id ~= a.id and c.revision == 1 and sameMap(c.loadout, SPEC), "the update of the old Titan is scoped to its own id")
    assert(b.revision == 2 and b.loadout.burstcore == 0)
end)

test("a loadout the owner cannot be told about is not applied", function()
    local titan = carryFixture()
    local token = claim(titan, "npc", 5)
    local before = copyMap(titan.loadout)
    sendFails = true
    local result, why = X.setLoadout(1, { sentry = 0 })
    sendFails = nil
    assert(result == nil and why == "owner_unavailable")
    assert(titan.revision == 1 and sameMap(titan.loadout, before), "a refused update moved the record")
    assert(titan.carry and titan.carry.token == token and claims["npc:5"], "a refused update let go of the body")
    S.clients[1].bridge = false
    result, why = X.setLoadout(1, { sentry = 0 })
    assert(result == nil and why == "bridge_unavailable" and titan.revision == 1 and titan.carry)
    S.clients[1].bridge = true
    assert(X.setLoadout(1, { sentry = 0 }) and titan.revision == 2 and titan.carry == nil, "reachable again, it goes through")
end)

test("without the sentry perk a held body is let go and no new grab is admitted; other perks leave a claim alone", function()
    local a, b = twoTitans()
    local token = claim(a, "npc", 5)
    sample(a, token, { x = 1.5, y = 0.5, z = 2 })
    assert(a.carry.accepted == 1)
    clear(coreCalls); clear(sent)
    -- Another perk, even the core, is none of the claim's business.
    assert(X.setLoadout(1, { burstcore = 0 }))
    assert(a.carry and claims["npc:5"].token == token and #calls("endCarry") == 0 and #messages(1, "carry_ended") == 0)
    -- The sentry perk is.
    clear(sent)
    assert(X.setLoadout(1, { sentry = 0 }))
    assert(a.carry == nil and next(S.bodies) == nil and next(claims) == nil, "the canonical claim was not given back")
    local ends = calls("endCarry")
    assert(#ends == 1 and ends[1].kind == "npc" and ends[1].id == 5 and ends[1].token == token)
    local ended = messages(1, "carry_ended")
    assert(#ended == 1 and ended[1].token == token and ended[1].reason == "interrupted")
    assert(T.normalizeServerMessage(ended[1], Open77TitanCatalog), "the controller's validator accepts the end")
    assert(opsTo(1) == "loadout,carry_ended", opsTo(1))
    assert(S.titans[1] == a, "only the claim ends, never the Titan")
    -- What the controller sends for the dead claim is stale.
    local updates, stale = #calls("updateCarry"), S.stats.carryStale
    sample(a, token, { x = 1.6, y = 0.5, z = 2 })
    assert(#calls("updateCarry") == updates and S.stats.carryStale == stale + 1)
    -- A new grab is refused with the platform untouched, whatever the body.
    clear(sent); clear(coreCalls)
    request(a, "npc", 5)
    assert(denied(a) == "refused" and #calls("beginCarry") == 0 and next(claims) == nil and a.carry == nil)
    assert(T.normalizeServerMessage(lastMessage(1, "carry_denied"), Open77TitanCatalog))
    -- Another Titan is not affected.
    claim(b, "npc", 6)
    assert(claims["npc:6"].carrier == 2 and b.carry)
    -- Giving the perk back admits grabs again.
    assert(X.setLoadout(1, { sentry = 1 }))
    now = now + 3
    refresh(a)
    request(a, "npc", 5)
    assert(lastMessage(1, "carry_grant"), "the perk is back: " .. tostring(denied(a)))
    assert(forbidden == 0)

    -- A claim the controller has not fed yet is let go the same way.
    a = carryFixture()
    local pendingToken = claim(a, "vehicle", 9)
    assert(a.carry.accepted == 0)
    clear(coreCalls); clear(sent)
    assert(X.setLoadout(1, { sentry = 0 }))
    assert(a.carry == nil and next(claims) == nil and next(S.bodies) == nil)
    assert(#calls("endCarry") == 1 and calls("endCarry")[1].token == pendingToken and calls("endCarry")[1].kind == "vehicle")
    assert(lastMessage(1, "carry_ended").token == pendingToken)

    -- A Titan spawned without the perk never carries.
    reset(); carryWorld(); ready(1)
    assert(X.spawn(1, { sentry = 0 }))
    local titan = S.titans[1]
    assert(publish(titan, { mode = "pilot", weapon = "fist" }))
    clear(sent); clear(coreCalls)
    request(titan, "npc", 5)
    assert(denied(titan) == "refused" and #calls("beginCarry") == 0 and next(claims) == nil and next(S.bodies) == nil)
end)

test("/titan action grab, shoulder and core follow the loadout; every other control is untouched", function()
    reset(); ready(1)
    local titan = spawn(1)
    assert(publish(titan, { weapon = "fist" }))
    -- One command per call, the per-player budget refilled first. Returns whether it was sent, and the reply.
    local function try(...)
        now = now + 5
        clear(sent)
        command(1, ...)
        return #messages(1, "command") == 1, lastReply(1)
    end
    for _, value in ipairs({ "grab", "shoulder", "core", "dash" }) do assert(try("action", value), value) end
    assert(X.setLoadout(1, { sentry = 0 }))
    local delivered, reply = try("action", "grab")
    assert(not delivered and reply[2] == false and reply[3]:find("loadout", 1, true), reply[3])
    assert(not try("action", "shoulder"))
    assert(try("action", "core") and try("action", "dash") and try("pilot") and try("weapon", "rail"))
    assert(X.setLoadout(1, { sentry = 1, burstcore = 0 }))
    assert(try("action", "grab") and try("action", "shoulder") and not try("action", "core"))
    -- Everything switched off still leaves every other control alone, but for the selection of a weapon whose own perk is 0.
    local zero = {}
    for perk in pairs(SPEC) do zero[perk] = 0 end
    assert(X.setLoadout(1, zero))
    assert(not try("action", "grab") and not try("action", "shoulder") and not try("action", "core"))
    for _, value in ipairs({ "jump", "dash", "punch", "missiles", "vortex", "smoke", "eject", "view" }) do
        assert(try("action", value), value)
    end
    assert(try("pilot") and try("exit"))
    for _, weapon in ipairs({ "xo16", "rail", "pred", "sword", "fist" }) do
        local delivered, refusal = try("weapon", weapon)
        assert(not delivered and refusal[2] == false and refusal[3]:find("loadout", 1, true), weapon)
    end
end)

test("frames leave the loadout alone, and viewers never see it", function()
    reset(); withViewers(1, 2)
    local titan = spawn(1)
    observers[1] = { 1, 2 }
    assert(publish(titan)); S.reconcile(titan)
    assert(X.setLoadout(1, { sentry = 0, burstcore = 0 }))
    clear(sent)
    for _ = 1, 20 do assert(publish(titan)) end
    local states = messages(2, "state")
    assert(#states == 20)
    for _, state in ipairs(states) do assert(state.loadout == nil and state.revision == nil) end
    assert(titan.loadout.sentry == 0 and titan.revision == 2)
end)

test("no client message can read, grant or change a loadout", function()
    reset(); ready(1)
    local titan = spawn(1)
    assert(publish(titan))
    local before = copyMap(titan.loadout)
    -- A frame, a request, a command or a carry message that names a loadout is malformed, never a grant.
    local ok, why = publish(titan, { loadout = { sentry = 5 } })
    assert(not ok and why == "frame_keys", why)
    ok, why = publish(titan, { revision = 9 })
    assert(not ok and why == "frame_keys", why)
    now = now + 2
    clear(sent)
    fire(T.event.request, 1, "setLoadout")
    assert(messages(1, "error")[1].reason == "invalid_request")
    now = now + 2
    fire(T.event.request, 1, { action = "spawn", loadout = {} })
    command(1, "loadout", "sentry", "0")
    now = now + 2
    command(1, "action", "sentry")
    carryWorld()
    local rejected = S.stats.carryRejected
    request(titan, "npc", 5, { loadout = { sentry = 5 } })
    assert(S.stats.carryRejected == rejected + 1)
    assert(sameMap(titan.loadout, before) and titan.revision == 1 and #toAnyone("loadout") == 0)
end)

-- ---------------------------------------------------------------------------
-- Server Lua controls: `command` dispatches the /titan controls that act on a live controller and `getState`
-- copies what the server accepted. Neither runs on a client's word, reaches another player's Titan, or
-- reports a result the controller has not published.
-- ---------------------------------------------------------------------------
-- A table that runs code if anything but its type is ever asked of it.
local HOSTILE = setmetatable({}, {
    __index = function() error("executed") end, __newindex = function() error("executed") end,
    __tostring = function() error("executed") end, __len = function() error("executed") end,
    __pairs = function() error("executed") end, __call = function() error("executed") end,
})
local BAD_PLAYERS = { "1", "x", 0, -1, 1.5, 0 / 0, math.huge, -math.huge, 2 ^ 40, true, false, {}, HOSTILE, print }

-- One export call with the player's command budget refilled: the results and every command message the player was sent.
local function control(player, ...)
    now = now + 5
    clear(sent)
    local ok, why = X.command(player, ...)
    return ok, why, messages(player, "command")
end

local function keysOf(map)
    local list = {}
    for key in pairs(map) do list[#list + 1] = tostring(key) end
    table.sort(list)
    return table.concat(list, ",")
end

local function sameTree(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for key, value in pairs(a) do if not sameTree(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end

test("command refuses a bad player, verb or value before anything is spent or sent", function()
    reset(); ready(1)
    local titan = spawn(1)
    assert(publish(titan, { weapon = "fist" }))
    now = now + 5
    clear(sent)
    local bucket = S.clients[1].commands
    local tokens, anchored = bucket.tokens, bucket.at
    local function refused(token, ...)
        local ok, why = X.command(...)
        assert(ok == nil and why == token, ("%s (wanted %s)"):format(tostring(why), token))
    end
    for index, player in ipairs(BAD_PLAYERS) do
        local ok, why = X.command(player, "pilot")
        assert(ok == nil and why == "invalid_player", "bad player #" .. index)
    end
    refused("invalid_player", nil, "pilot")
    refused("invalid_player")
    -- Only pilot, exit, weapon and action, exactly spelled: spawn and remove have their own exports, and nothing else exists.
    for _, verb in ipairs({ "spawn", "remove", "status", "setLoadout", "loadout", "getState", "core", "os.execute", "Pilot", "PILOT",
        " pilot", "pilot ", "", "weapon\n", 1, true, false, {}, HOSTILE, print }) do
        refused("invalid_command", 1, verb)
        refused("invalid_command", 1, verb, "rail")
    end
    refused("invalid_command", 1)
    refused("invalid_command", 1, nil, "rail")
    -- pilot and exit take no value; weapon and action take exactly one of shared.lua's.
    for _, value in ipairs({ "x", "", 0, true, false, {}, HOSTILE, "rail", "dash" }) do
        refused("invalid_value", 1, "pilot", value)
        refused("invalid_value", 1, "exit", value)
    end
    for _, value in ipairs({ "laser", "XO16", "Rail", " rail", "rail ", "", "grab", "pilot", 1, true, false, {}, HOSTILE, print }) do
        refused("invalid_value", 1, "weapon", value)
    end
    refused("invalid_value", 1, "weapon")
    for _, value in ipairs({ "sentry", "os.execute", "Dash", "dash ", "", "xo16", "spawn", "remove", 1, true, false, {}, HOSTILE, print }) do
        refused("invalid_value", 1, "action", value)
    end
    refused("invalid_value", 1, "action")
    assert(#sent == 0, "a refused command sent something")
    assert(bucket.tokens == tokens and bucket.at == anchored, "validation spent the player's command budget")
    assert(S.titans[1] == titan and titan.active and titan.revision == 1, "a refused command touched the Titan")

    -- A client cannot reach these controls by another door: its request vocabulary stays spawn and remove.
    for _, action in ipairs({ "pilot", "exit", "weapon", "action", "command", "getState" }) do
        now = now + 2
        clear(sent)
        fire(T.event.request, 1, action)
        local errors = messages(1, "error")
        assert(#errors == 1 and errors[1].reason == "invalid_request" and #messages(1, "command") == 0, action)
    end
end)

test("command answers no_titan or not_active without sending, and allocates nothing for a player with no Titan", function()
    reset(); ready(1); ready(2)
    clear(sent)
    for _, player in ipairs({ 1, 2, 77 }) do
        local ok, why = X.command(player, "weapon", "rail")
        assert(ok == nil and why == "no_titan", "player " .. player)
    end
    assert(#sent == 0 and S.clients[1].commands == nil and S.clients[2].commands == nil and S.clients[77] == nil)
    local titan = spawn(1)                           -- granted; its controller has not published yet
    local ok, why, sentCommands = control(1, "action", "dash")
    assert(ok == nil and why == "not_active" and #sentCommands == 0 and #sent == 0 and titan.active == false)
    assert(publish(titan))
    ok, why, sentCommands = control(1, "action", "dash")
    assert(ok == true and why == nil and #sentCommands == 1)
    -- A player without a Titan cannot reach this one: the player is the only target there is.
    ok, why = X.command(2, "pilot")
    assert(ok == nil and why == "no_titan" and #messages(1, "command") == 1 and #messages(2, "command") == 0)
    assert(X.remove(1) == true)
    ok, why, sentCommands = control(1, "pilot")
    assert(ok == nil and why == "no_titan" and #sentCommands == 0 and #sent == 0)
end)

test("command applies /titan's loadout and fist admission: a refusal is a reason, never a send", function()
    reset(); ready(1)
    local titan = spawn(1)
    assert(publish(titan, { weapon = "xo16" }))
    local ok, why, sentCommands = control(1, "action", "grab")
    assert(ok == nil and why == "not_fist" and #sentCommands == 0 and #sent == 0)
    assert(control(1, "action", "shoulder") == true, "only a grab needs the fist")
    assert(publish(titan, { weapon = "fist" }))
    for _, value in ipairs({ "grab", "shoulder", "core", "dash" }) do assert(control(1, "action", value) == true, value) end
    assert(X.setLoadout(1, { sentry = 0 }))
    for _, value in ipairs({ "grab", "shoulder" }) do
        ok, why, sentCommands = control(1, "action", value)
        assert(ok == nil and why == "loadout_disabled" and #sentCommands == 0 and #sent == 0, value)
    end
    for _, args in ipairs({ { "action", "core" }, { "action", "dash" }, { "pilot" }, { "exit" }, { "weapon", "rail" } }) do
        assert(control(1, table.unpack(args)) == true, args[1] .. " " .. tostring(args[2]))
    end
    assert(X.setLoadout(1, { sentry = 1, burstcore = 0 }))
    ok, why, sentCommands = control(1, "action", "core")
    assert(ok == nil and why == "loadout_disabled" and #sentCommands == 0 and #sent == 0)
    assert(control(1, "action", "grab") == true and control(1, "action", "shoulder") == true)
    -- It is the same admission: /titan refuses the same control with the same loadout.
    now = now + 5
    clear(sent)
    command(1, "action", "core")
    assert(#messages(1, "command") == 0 and lastReply(1)[2] == false)
end)

test("command dispatches the control to the owner's controller and returns true: dispatch, not completion", function()
    reset(); withViewers(1, 2)
    local a, b = spawn(1), spawn(2)
    observers[1] = { 1, 2 }
    assert(publish(a, { mode = "pilot", weapon = "fist" }) and publish(b, { weapon = "fist" })); S.reconcile(a)
    -- Both bare verbs, every weapon and every action, each from a refilled budget.
    local wanted = { { "pilot" }, { "exit" } }
    for weapon in pairs(T.weapons) do wanted[#wanted + 1] = { "weapon", weapon } end
    for action in pairs(T.actions) do wanted[#wanted + 1] = { "action", action } end
    for _, args in ipairs(wanted) do
        now = now + 5
        clear(sent)
        local results = table.pack(X.command(1, table.unpack(args)))
        assert(results.n == 1 and results[1] == true, args[1] .. " " .. tostring(args[2]))
        assert(#sent == 1 and sent[1].name == MSG and sent[1].target == 1, "only the owner is told, once, and no chat reply")
        local message = sent[1].args[1]
        assert(message.v == T.protocol and message.op == "command" and message.action == args[1] and message.value == args[2])
        assert(T.normalizeServerMessage(message, Open77TitanCatalog), "the controller's validator accepts it")
    end
    -- Dispatch is not completion: the server's own record is exactly as before until the controller publishes.
    assert(a.mode == "pilot" and a.weapon == "fist")
    now = now + 5
    clear(sent)
    assert(X.command(1, "weapon", "sword") == true)
    assert(a.weapon == "fist" and X.getState(1).weapon == "fist", "the server guessed the controller's result")
    assert(publish(a, { mode = "pilot", weapon = "sword" }) and X.getState(1).weapon == "sword")
    -- Each Titan is commanded alone.
    now = now + 5
    clear(sent)
    assert(X.command(2, "exit") == true)
    assert(#sent == 1 and sent[1].target == 2 and #messages(1, "command") == 0 and #messages(2, "command") == 1)
    assert(#messages(2, "command") == 1 and lastReply(2) == nil)
    -- The chat path keeps its own text.
    now = now + 5
    clear(sent)
    command(1, "weapon", "rail")
    local reply = lastReply(1)
    assert(reply[2] == true and reply[3] == "[titan] sent weapon rail", reply[3])
    assert(#messages(1, "command") == 1 and messages(1, "command")[1].value == "rail")
end)

test("a command that could not be sent is owner_unavailable, never a success, over the export and /titan alike", function()
    reset(); ready(1)
    local titan = spawn(1)
    assert(publish(titan))
    now = now + 5
    clear(sent)
    local failures = S.stats.sendFailures
    sendFails = true
    local ok, why = X.command(1, "pilot")
    sendFails = nil
    assert(ok == nil and why == "owner_unavailable", tostring(why))
    assert(#sent == 0 and S.stats.sendFailures == failures + 1)
    assert(S.titans[1] == titan and titan.active, "a failed send is not a reason to drop the Titan")
    now = now + 5
    sendFails = true
    local executed, reason, text = S.execute(1, "weapon", "rail", true)
    sendFails = nil
    assert(executed == false and reason == "owner_unavailable" and text == nil, "execute reported a command that was never sent")
    -- /titan prints what it refused, not that it sent.
    now = now + 5
    local printed, quiet = {}, print
    print = function(line) printed[#printed + 1] = line end
    sendFails = true
    command(1, "pilot")
    sendFails = nil
    print = quiet
    assert(#printed == 1 and printed[1]:find("^%[titan%] ") and not printed[1]:find("sent", 1, true), tostring(printed[1]))
    -- Nothing was lost but the command: the same call goes through once the target is reachable again.
    now = now + 5
    clear(sent)
    assert(X.command(1, "pilot") == true and #messages(1, "command") == 1)
end)

test("command spends the player's /titan command budget and reports rate_limited when it is gone", function()
    reset(); ready(1)
    local titan = spawn(1)
    assert(publish(titan))
    now = now + 5
    clear(sent)
    local delivered = 0
    for _ = 1, T.limits.commandBurst + 4 do
        local ok, why = X.command(1, "action", "view")
        if ok == true then delivered = delivered + 1 else assert(ok == nil and why == "rate_limited", tostring(why)) end
    end
    assert(delivered == T.limits.commandBurst and #messages(1, "command") == delivered, delivered)
    command(1, "pilot")                              -- the chat path draws on the same budget
    assert(lastReply(1)[2] == false and #messages(1, "command") == delivered)
    now = now + 5
    assert(X.command(1, "pilot") == true)
end)

-- ---------------------------------------------------------------------------
-- Server-driven held and analog controls: `input` holds one control of a piloted Titan until the script changes it,
-- `releaseInput` lets go of all of them. What the controller then does with them (its pause gate, its own
-- debounce, the state it ends in) is live acceptance, against the real controller.
-- ---------------------------------------------------------------------------
local function drive(player, name, value)
    clear(sent)
    local ok, why = X.input(player, name, value)
    return ok, why, messages(player, "input")
end

test("input's vocabulary is the exact bounded set, and a bad player, name or value is refused before anything is spent or sent", function()
    reset(); ready(1)
    local titan = spawn(1)
    assert(publish(titan, { mode = "pilot", weapon = "fist" }))
    now = now + 5
    clear(sent)
    local list = {}
    for name, kind in pairs(T.inputs) do list[#list + 1] = name .. ":" .. kind end
    table.sort(list)
    assert(table.concat(list, ",") == "Back:button,CameraAim:button,CameraMouseX:relative,CameraMouseY:relative,"
        .. "CameraX:axis,CameraY:axis,Dodge:button,Forward:button,Jump:button,Left:button,MoveX:axis,MoveY:axis,"
        .. "QuickMelee:button,RangedADS:button,RangedAttack:button,Reload:button,Right:button,Sprint:button,"
        .. "ToggleSprint:button,core:key,dash:key,designate:key,flight:key,jump:key,missiles:key,punch:key,"
        .. "sentry:key,shoulder:key,smoke:key,view:key,vortex:key", table.concat(list, ","))
    assert(T.inputLimits.axis == 1 and T.inputLimits.relative == 20000)
    local bucket = S.clients[1].commands
    local tokens, anchored = bucket.tokens, bucket.at
    local function refused(token, ...)
        local ok, why = X.input(...)
        assert(ok == nil and why == token, ("%s (wanted %s)"):format(tostring(why), token))
    end
    for index, player in ipairs(BAD_PLAYERS) do
        local ok, why = X.input(player, "MoveX", 0.5)
        assert(ok == nil and why == "invalid_player", "bad player #" .. index)
    end
    refused("invalid_player", nil, "MoveX", 0.5)
    refused("invalid_player")
    -- Companion commands, the game's other actions, other spellings and anything that is not text are not controls.
    for _, name in ipairs({ "follow", "home", "call", "embark", "eject", "Choice1", "Choice1_Hold", "forward", "FORWARD",
        "moveX", "Move_X", " jump", "jump ", "", "os.execute", "W", 1, true, false, {}, HOSTILE, print }) do
        refused("invalid_input", 1, name, true)
        refused("invalid_input", 1, name, 0.5)
    end
    refused("invalid_input", 1)
    refused("invalid_input", 1, nil, true)
    -- A value is exactly its kind: a finite number within the range for an axis or a relative step, a boolean otherwise.
    for _, name in ipairs({ "MoveX", "MoveY", "CameraX", "CameraY" }) do
        for _, value in ipairs({ 1.0001, -1.0001, 2, math.huge, -math.huge, 0 / 0, "0.5", "", true, false, {}, HOSTILE, print }) do
            refused("invalid_value", 1, name, value)
        end
        refused("invalid_value", 1, name)
    end
    for _, name in ipairs({ "CameraMouseX", "CameraMouseY" }) do
        for _, value in ipairs({ 20000.5, -20000.5, 1e9, math.huge, -math.huge, 0 / 0, "450", true, {}, HOSTILE }) do
            refused("invalid_value", 1, name, value)
        end
    end
    for _, name in ipairs({ "Forward", "RangedAttack", "ToggleSprint", "jump", "core", "flight" }) do
        for _, value in ipairs({ 0, 1, 0.5, "true", "", {}, HOSTILE, print }) do refused("invalid_value", 1, name, value) end
        refused("invalid_value", 1, name)
    end
    assert(#sent == 0, "a refused control sent something")
    assert(bucket.tokens == tokens and bucket.at == anchored, "validation spent the player's command budget")
    assert(S.titans[1] == titan and titan.active and titan.mode == "pilot", "a refused control touched the Titan")
    -- The limits themselves are inside, and the wire validator the client runs says the same as the export.
    for _, case in ipairs({ { "MoveX", 1 }, { "MoveY", -1 }, { "CameraX", 0 }, { "CameraMouseX", 20000 },
        { "CameraMouseY", -20000 }, { "RangedAttack", true }, { "ToggleSprint", false }, { "view", true } }) do
        local ok, why, inputs = drive(1, case[1], case[2])
        assert(ok == true and why == nil and #inputs == 1, case[1])
        local clean = T.normalizeServerMessage(inputs[1], Open77TitanCatalog)
        assert(clean and clean.name == case[1] and clean.value == case[2] and clean.id == titan.id and clean.epoch == titan.epoch, case[1])
    end
end)

test("the client's message validator holds the same kinds and ranges, a scoped Titan and no extra keys", function()
    local function valid(extra)
        return merge({ v = T.protocol, op = "input", id = "7001", epoch = 1, name = "MoveX", value = 0.5 }, extra)
    end
    local function verdict(extra) return select(2, T.normalizeServerMessage(valid(extra), Open77TitanCatalog)) end
    assert(verdict({}) == nil)
    assert(verdict({ name = "follow" }) == "input_name" and verdict({ name = "movex" }) == "input_name" and verdict({ name = 5 }) == "input_name")
    assert(verdict({ value = 1.5 }) == "input_value" and verdict({ value = 0 / 0 }) == "input_value" and verdict({ value = true }) == "input_value")
    assert(verdict({ name = "CameraMouseY", value = 20001 }) == "input_value" and verdict({ name = "Forward", value = 1 }) == "input_value")
    assert(verdict({ name = "CameraMouseY", value = -20000 }) == nil and verdict({ name = "Forward", value = false }) == nil)
    assert(verdict({ epoch = 0 }) == "input_invalid" and verdict({ epoch = 1.5 }) == "input_invalid" and verdict({ id = "x" }) == "input_invalid")
    assert(verdict({ id = DROP }) == "input_invalid" and verdict({ epoch = DROP }) == "input_invalid")
    assert(verdict({ kind = "axis" }) == "message_keys" and verdict({ player = "1" }) == "message_keys")
    local release = { v = T.protocol, op = "input_release", id = "7001", epoch = 2 }
    assert(T.normalizeServerMessage(release, Open77TitanCatalog), "a release of that Titan")
    release.value = false
    assert(select(2, T.normalizeServerMessage(release, Open77TitanCatalog)) == "message_keys")
    release.value, release.epoch = nil, 0
    assert(select(2, T.normalizeServerMessage(release, Open77TitanCatalog)) == "input_invalid")
end)

test("input reaches only the piloted Titan of that player, names its id and epoch, and spends no command budget", function()
    reset(); withViewers(1, 2)
    local a, b = spawn(1), spawn(2)
    observers[1] = { 1, 2 }
    now = now + 5
    local ok, why, inputs = drive(77, "MoveX", 0.5)
    assert(ok == nil and why == "no_titan" and #sent == 0 and S.clients[77] == nil)
    ok, why, inputs = drive(1, "MoveX", 0.5)
    assert(ok == nil and why == "not_active" and #sent == 0)
    for _, mode in ipairs({ "none", "wait", "mount", "dismount", "eject" }) do
        assert(publish(a, { mode = mode }))
        for _, value in ipairs({ 0.5, 0 }) do
            ok, why, inputs = drive(1, "MoveY", value)
            assert(ok == nil and why == "not_piloting" and #sent == 0, mode)
        end
        ok, why = drive(1, "RangedAttack", false)
        assert(ok == nil and why == "not_piloting" and #sent == 0, "a release is a control too: " .. mode)
    end
    assert(publish(a, { mode = "pilot", weapon = "fist" }) and publish(b, { mode = "pilot" }))
    S.reconcile(a)
    local bucket = S.clients[1].commands
    local tokens, anchored = bucket.tokens, bucket.at
    ok, why, inputs = drive(1, "CameraMouseX", -450.5)
    assert(ok == true and why == nil and #sent == 1 and sent[1].name == MSG and sent[1].target == 1, "only the owner is told, once, and no chat reply")
    local message = inputs[1]
    assert(message.v == T.protocol and message.op == "input" and message.id == a.id and message.epoch == a.epoch
        and message.name == "CameraMouseX" and message.value == -450.5)
    assert(#messages(2, "input") == 0 and lastReply(1) == nil)
    -- A script holds a control every tick: no budget, whatever the rate, and each one is delivered.
    clear(sent)
    for index = 1, 100 do assert(X.input(1, "RangedAttack", index % 2 == 0) == true) end
    assert(#messages(1, "input") == 100 and bucket.tokens == tokens and bucket.at == anchored)
    -- Another Titan is another target, and the dispatch is not the Titan's own record.
    ok, why, inputs = drive(2, "MoveX", 1)
    assert(ok == true and #inputs == 1 and inputs[1].id == b.id and #messages(1, "input") == 0)
    assert(a.mode == "pilot" and a.weapon == "fist" and X.getState(1).mode == "pilot")
    -- A Titan that is replaced is a new id and epoch: the old one is never named again.
    assert(X.remove(1) == true)
    ok, why = drive(1, "MoveX", 0.5)
    assert(ok == nil and why == "no_titan" and #sent == 0)
    local c = spawn(1)
    assert(c ~= nil and c.id ~= a.id)
    ok, why = drive(1, "MoveX", 0.5)
    assert(ok == nil and why == "not_active")
    assert(publish(c, { mode = "pilot" }))
    ok, why, inputs = drive(1, "MoveX", 0.5)
    assert(ok == true and inputs[1].id == c.id and inputs[1].epoch == c.epoch and inputs[1].id ~= a.id)
    -- A target the platform no longer knows is not a delivered control.
    local failures = S.stats.sendFailures
    clear(sent)
    sendFails = true
    ok, why = X.input(1, "MoveX", 0.25)
    sendFails = nil
    assert(ok == nil and why == "owner_unavailable" and #sent == 0 and S.stats.sendFailures == failures + 1)
    assert(S.titans[1] == c and c.active, "a failed send is not a reason to drop the Titan")
end)

test("releaseInput lets go for an active Titan in any mode, names its id and epoch and no client can call it", function()
    reset(); ready(1); ready(2)
    local function release(player)
        clear(sent)
        local ok, why = X.releaseInput(player)
        return ok, why, messages(player, "input_release")
    end
    for index, player in ipairs(BAD_PLAYERS) do
        local ok, why = X.releaseInput(player)
        assert(ok == nil and why == "invalid_player", "bad player #" .. index)
    end
    local ok, why = release(77)
    assert(ok == nil and why == "no_titan" and #sent == 0 and S.clients[77] == nil)
    local titan = spawn(1)
    ok, why = release(1)
    assert(ok == nil and why == "not_active" and #sent == 0)
    now = now + 5
    local bucket = S.clients[1].commands
    local tokens, anchored = bucket.tokens, bucket.at
    for _, mode in ipairs({ "wait", "pilot", "dismount" }) do
        assert(publish(titan, { mode = mode }))
        local inputs
        ok, why, inputs = release(1)
        assert(ok == true and why == nil and #sent == 1 and #inputs == 1, mode)
        assert(inputs[1].v == T.protocol and inputs[1].id == titan.id and inputs[1].epoch == titan.epoch)
        assert(T.normalizeServerMessage(inputs[1], Open77TitanCatalog), "the client's validator accepts it")
    end
    assert(bucket.tokens == tokens and bucket.at == anchored, "a release spent the command budget")
    assert(#messages(2, "input_release") == 0)
    clear(sent)
    sendFails = true
    ok, why = X.releaseInput(1)
    sendFails = nil
    assert(ok == nil and why == "owner_unavailable" and #sent == 0)
    -- Neither export is a client's door: the request vocabulary stays spawn and remove.
    for _, action in ipairs({ "input", "releaseInput", "input_release" }) do
        now = now + 2
        clear(sent)
        fire(T.event.request, 1, action)
        local errors = messages(1, "error")
        assert(#errors == 1 and errors[1].reason == "invalid_request" and #messages(1, "input") == 0
            and #messages(1, "input_release") == 0, action)
    end
end)

test("getState refuses a bad player and a missing Titan with a reason and touches nothing", function()
    reset(); ready(1)
    clear(sent)
    for index, player in ipairs(BAD_PLAYERS) do
        local state, why = X.getState(player)
        assert(state == nil and why == "invalid_player", "bad player #" .. index)
    end
    local state, why = X.getState(nil)
    assert(state == nil and why == "invalid_player")
    for _, player in ipairs({ 1, 77 }) do
        state, why = X.getState(player)
        assert(state == nil and why == "no_titan", "player " .. player)
    end
    assert(#sent == 0 and S.clients[77] == nil and S.titans[77] == nil)
    spawn(1)
    assert(X.getState(1) and X.remove(1) == true)
    state, why = X.getState(1)
    assert(state == nil and why == "no_titan")
end)

test("getState reports what the server accepted: grant, controller frames, loadout and claim, and no health of its own", function()
    reset(); ready(1)
    local titan = spawn(1)
    local state = X.getState(1)
    assert(state.id == titan.id and T.isId(state.id) and state.epoch == 1 and state.owner == 1 and state.active == false)
    assert(state.revision == 1 and sameMap(state.loadout, SPEC) and state.viewers == 0)
    assert(state.carry.active == false and state.carry.last == nil)
    assert(state.frames.accepted == 0 and state.frames.rejected == 0 and state.frames.lastReject == nil)
    assert(keysOf(state) == "active,carry,epoch,frames,id,loadout,owner,revision,viewers", keysOf(state))

    now = now + 2
    assert(publish(titan, { mode = "pilot", weapon = "fist", pose = { x = 1.5, y = -2, z = 3, yaw = 45 } }))
    local _, why = S.acceptFrame(1, frame(titan, 1))
    assert(why == "stale_seq")
    state = X.getState(1)
    assert(state.active == true and state.mode == "pilot" and state.weapon == "fist")
    assert(state.position.x == 1.5 and state.position.y == -2 and state.position.z == 3 and state.rotation.yaw == 45)
    assert(keysOf(state.position) == "x,y,z" and keysOf(state.rotation) == "yaw")
    assert(state.frames.accepted == 1 and state.frames.rejected == 1 and state.frames.lastReject == "stale_seq")
    assert(keysOf(state) == "active,carry,epoch,frames,id,loadout,mode,owner,position,revision,rotation,viewers,weapon", keysOf(state))
    assert(state.health == nil and state.gameplay == nil, "the server holds no health of its own and none was reported")

    local viewed = liveWithViewer()
    state = X.getState(1)
    assert(state.id == viewed.id and state.viewers == 1 and state.mode == "pilot" and state.weapon == "xo16")

    local carrier = carryFixture()
    assert(X.setLoadout(1, { burstcore = 1 }))
    state = X.getState(1)
    assert(state.revision == 2 and state.loadout.burstcore == 1 and state.loadout.sentry == SPEC.sentry)
    local token = claim(carrier, "npc", 5)
    state = X.getState(1)
    assert(state.carry.active == true and state.carry.kind == "npc" and state.carry.entityId == "5" and state.carry.phase == "hold")
    assert(keysOf(state.carry) == "active,entityId,kind,phase", keysOf(state.carry))
    for key, value in pairs(state.carry) do assert(value ~= token, key .. " leaks the claim's platform token") end
    assert(X.getState(2).carry.active == false, "another Titan's claim")
    assert(X.setLoadout(1, { sentry = 0 }))          -- the sentry perk gone, the body is let go
    state = X.getState(1)
    assert(state.carry.active == false and state.revision == 3)
    assert(state.carry.last.kind == "npc" and state.carry.last.entityId == "5" and state.carry.last.reason == "interrupted")
    assert(keysOf(state.carry.last) == "entityId,kind,reason" and keysOf(state.carry) == "active,last")
end)

test("getState is a detached snapshot: editing it never reaches the Titan, and the Titan never reaches it", function()
    local titan = carryFixture()
    local token = claim(titan, "npc", 5)
    local snapshot = X.getState(1)
    local before = X.getState(1)                     -- a second, independent copy to compare with
    -- Everything reachable from the live record or the server's handles: none of it may appear in a snapshot.
    local live = {}
    local function mark(value)
        if type(value) ~= "table" or live[value] then return end
        live[value] = true
        for key, child in pairs(value) do mark(key); mark(child) end
    end
    mark(titan); mark(S); mark(T)
    local function scan(value, path)
        local kind = type(value)
        assert(kind == "table" or kind == "string" or kind == "number" or kind == "boolean", path .. " is a " .. kind)
        if kind == "string" then assert(value ~= token, path .. " leaks the claim's token") end
        if kind ~= "table" then return end
        assert(not live[value] and getmetatable(value) == nil, path .. " aliases or wraps the record")
        for key, child in pairs(value) do scan(key, path .. ".<key>"); scan(child, path .. "." .. tostring(key)) end
    end
    scan(snapshot, "state")
    assert(snapshot ~= before and snapshot.loadout ~= before.loadout and snapshot.position ~= before.position
        and snapshot.carry ~= before.carry and snapshot.frames ~= before.frames and sameTree(snapshot, before))

    -- The caller edits every field it was given.
    snapshot.id, snapshot.epoch, snapshot.owner, snapshot.active, snapshot.mode = "99", 9, 2, false, "eject"
    snapshot.weapon, snapshot.revision, snapshot.viewers = "sword", 99, 5
    snapshot.loadout.sentry, snapshot.loadout.stray = 0, true
    snapshot.position.x, snapshot.rotation.yaw = 999, 999
    snapshot.carry.active, snapshot.carry.kind, snapshot.carry.entityId, snapshot.carry.phase = false, "vehicle", "9", "flight"
    snapshot.carry.last = { reason = "x" }
    snapshot.frames.accepted = -1
    assert(titan.id ~= "99" and titan.epoch == 1 and titan.owner == 1 and titan.active == true)
    assert(titan.mode == "pilot" and titan.weapon == "fist" and titan.revision == 1 and titan.accepted == 1)
    assert(sameMap(titan.loadout, SPEC) and titan.loadout.stray == nil)
    assert(titan.pose.x == 0 and titan.pose.yaw == 0)
    assert(titan.carry and titan.carry.kind == "npc" and titan.carry.entityId == "5" and titan.carry.phase == "hold"
        and titan.carry.token == token and claims["npc:5"].token == token and titan.lastCarryEnd == nil)
    local again = X.getState(1)
    assert(again ~= snapshot and again.loadout ~= snapshot.loadout and sameTree(again, before))

    -- The Titan moves on; a copy taken earlier does not.
    local frozen = X.getState(1)
    assert(X.setLoadout(1, { burstcore = 0 }))
    assert(publish(titan, { mode = "pilot", weapon = "fist", pose = { x = 0.5, y = 0, z = 0, yaw = 10 } }))
    assert(X.setLoadout(1, { sentry = 0 }))          -- lets go of the body
    assert(sameTree(frozen, before))
    assert(frozen.revision == 1 and frozen.loadout.burstcore == SPEC.burstcore and frozen.position.x == 0
        and frozen.rotation.yaw == 0 and frozen.carry.active == true and frozen.frames.accepted == 1)
    local moved = X.getState(1)
    assert(moved.revision == 3 and moved.loadout.burstcore == 0 and moved.position.x == 0.5 and moved.rotation.yaw == 10
        and moved.carry.active == false and moved.frames.accepted == 2)
    -- And it outlives the Titan.
    assert(X.remove(1) == true)
    assert(sameTree(frozen, before) and X.getState(1) == nil)
end)

-- ---------------------------------------------------------------------------
-- Gameplay: the owner's report (frame.gameplay), a server script's hit / repair requests and the host events a Titan's
-- life raises. The report is the owner's word, kept as the last ACCEPTED copy; a request is dispatched, not done, and
-- ends in exactly one onTitanActionResult.
-- ---------------------------------------------------------------------------
local function gameplayOf()
    return {
        health = { current = 9000.0, max = 10800.0, shield = 640.0, shieldMax = 1000.0, doomed = 0.0, doomedMax = 2500.0,
            dead = false },
        ammo = { current = 44, capacity = 60, reloading = false },
        core = { charge = 75.0, max = 150.0, active = true },
        abilities = {
            jump = { active = false }, dash = { active = false, cooldown = 0.0 },
            vortex = { active = true, remaining = 2.9 }, sentry = { active = false, cooldown = 12.5 },
        },
        paused = true, pauseReason = "the game is paused",
    }
end

local function hitOf()
    return { record = "Attacks.Bullet_Rifle_Basic", origin = { x = 10, y = -4, z = 1.5 },
        direction = { x = 0, y = 1, z = 0 }, attacker = "player:2", kind = "ranged", scale = 2 }
end

-- Player 1's Titan, granted and active (one accepted frame), with nothing recorded of it yet.
local function liveTitan()
    reset(); ready(1)
    local titan = spawn(1)
    now = now + 2
    assert(publish(titan))
    clear(sent); clear(events)
    return titan
end

-- The owner's answer to a request, as the client forwards it; `edit` may damage it.
local function answered(player, titan, request, kind, edit)
    local message = { v = T.protocol, op = "gameplay_result", id = titan.id, epoch = titan.epoch, request = request,
        kind = kind, ok = true, reason = "taken", amount = 120.5 }
    if edit then edit(message) end
    fire(T.event.result, player, message)
end

test("frame.gameplay is a closed bounded schema: the last accepted report is recorded, a refused one never is", function()
    reset(); ready(1)
    local titan = spawn(1)
    now = now + 2
    assert(X.getState(1).gameplay == nil, "a report before the controller made one")
    assert(publish(titan))
    assert(X.getState(1).gameplay == nil, "a frame without a report invented one")
    assert(publish(titan, { gameplay = gameplayOf() }))
    assert(sameTree(X.getState(1).gameplay, gameplayOf()))
    -- A report is replaced whole, never merged with the previous one: a substate that is gone is gone.
    assert(publish(titan, { gameplay = { paused = false } }))
    assert(sameTree(X.getState(1).gameplay, { paused = false }))
    assert(publish(titan, { gameplay = gameplayOf() }))
    assert(publish(titan))
    assert(sameTree(X.getState(1).gameplay, gameplayOf()), "a frame without a report must keep the last accepted one")

    local frames = titan.accepted
    local function refused(token, edit)
        local bad = gameplayOf()
        edit(bad)
        local ok, why = publish(titan, { gameplay = bad })
        assert(not ok and why == token, ("%s (wanted %s)"):format(tostring(why), token))
        assert(sameTree(X.getState(1).gameplay, gameplayOf()), "a refused frame changed the recorded report: " .. token)
    end
    refused("gameplay_keys", function(g) g.armor = 1 end)
    refused("gameplay_paused", function(g) g.paused = nil end)
    refused("gameplay_paused", function(g) g.paused = 1 end)
    refused("gameplay_health", function(g) g.health.dead = nil end)
    refused("gameplay_health", function(g) g.health.dead = "no" end)
    refused("gameplay_health", function(g) g.health.max = nil end)
    refused("gameplay_health", function(g) g.health.current = 0 / 0 end)
    refused("gameplay_health", function(g) g.health.shield = math.huge end)
    refused("gameplay_health", function(g) g.health.current = 2e6 end)
    refused("gameplay_health", function(g) g.health.armor = 1 end)
    refused("gameplay_health", function(g) g.health = 5 end)
    refused("gameplay_ammo", function(g) g.ammo.current = 1.5 end)
    refused("gameplay_ammo", function(g) g.ammo.current = -1 end)
    refused("gameplay_ammo", function(g) g.ammo.capacity = 0 end)
    refused("gameplay_ammo", function(g) g.ammo.reloading = 0 end)
    refused("gameplay_core", function(g) g.core.max = 0 end)
    refused("gameplay_core", function(g) g.core.charge = -1 end)
    refused("gameplay_core", function(g) g.core.active = nil end)
    refused("gameplay_abilities", function(g) g.abilities.warp = { active = true } end)
    refused("gameplay_abilities", function(g) g.abilities.dash.extra = 1 end)
    refused("gameplay_abilities", function(g) g.abilities.dash.cooldown = -1 end)
    refused("gameplay_abilities", function(g) g.abilities.vortex.remaining = 0 / 0 end)
    refused("gameplay_abilities", function(g) g.abilities.jump = true end)
    refused("gameplay_abilities", function(g) g.abilities.dash.active = nil end)
    refused("gameplay_text", function(g) g.pauseReason = ("x"):rep(65) end)
    refused("gameplay_text", function(g) g.pauseReason = "" end)
    refused("gameplay_text", function(g) g.pauseReason = 5 end)
    refused("gameplay_text", function(g) g.pauseReason = "two\nlines" end)
    for _, junk in ipairs({ "x", 5, true, {} }) do
        local ok, why = publish(titan, { gameplay = junk })
        assert(not ok and (why == "gameplay_keys" or why == "gameplay_paused"), tostring(why))
    end
    assert(titan.accepted == frames, "a refused report must not count as an accepted frame")

    -- The edges of every range are legal.
    local edge = gameplayOf()
    edge.pauseReason, edge.health.current, edge.health.max = ("x"):rep(64), -1, 1e6
    assert(publish(titan, { gameplay = edge }))
    assert(sameTree(X.getState(1).gameplay, edge))
end)

test("gameplay stays with the owner: a relayed state never carries it, and a forged one is refused", function()
    local titan = liveWithViewer()
    assert(publish(titan, { gameplay = gameplayOf() }))
    local states = messages(2, "state")
    assert(#states == 1 and states[1].gameplay == nil and #messages(1, "state") == 0)
    assert(T.normalizeServerMessage(states[1], Open77TitanCatalog))
    local forged = {}
    for key, value in pairs(states[1]) do forged[key] = value end
    forged.gameplay = gameplayOf()
    local clean, why = T.normalizeServerMessage(forged, Open77TitanCatalog)
    assert(clean == nil and why == "frame_keys", tostring(why))
end)

test("getState's gameplay is a detached copy of the accepted report, never the sender's or the record's table", function()
    reset(); ready(1)
    local titan = spawn(1)
    now = now + 2
    local sentReport = gameplayOf()
    assert(publish(titan, { gameplay = sentReport }))
    sentReport.health.current, sentReport.abilities.dash.active = -5, true        -- the sender edits after it sent
    local state = X.getState(1)
    assert(state.gameplay.health.current == 9000 and state.gameplay.abilities.dash.active == false)
    state.gameplay.health.current, state.gameplay.core, state.gameplay.abilities.stray = 1, nil, {}
    state.gameplay.abilities.dash.cooldown = 99
    local again = X.getState(1)
    assert(again ~= state and again.gameplay ~= state.gameplay and again.gameplay.health ~= state.gameplay.health
        and again.gameplay.abilities ~= state.gameplay.abilities)
    assert(again.gameplay.health.current == 9000 and again.gameplay.core.active == true
        and again.gameplay.abilities.stray == nil and again.gameplay.abilities.dash.cooldown == 0)
    assert(titan.gameplay ~= again.gameplay and titan.gameplay.health ~= again.gameplay.health)
    -- A copy taken earlier does not follow the Titan.
    local frozen = X.getState(1)
    local moved = gameplayOf()
    moved.health.current = 100
    assert(publish(titan, { gameplay = moved }))
    assert(frozen.gameplay.health.current == 9000 and X.getState(1).gameplay.health.current == 100)
end)

test("lifecycle events fire once each, on accepted edges only", function()
    reset(); ready(1)
    local titan = spawn(1)
    local created = eventsNamed("onTitanCreated")
    assert(#created == 1 and created[1].n == 3 and created[1][1] == 1 and created[1][2] == titan.id and created[1][3] == 1)
    assert(#eventsNamed("onTitanReady") == 0)
    now = now + 2
    local ok = publish(titan, { mode = "flying" })
    assert(not ok and #eventsNamed("onTitanReady") == 0, "a refused frame made the Titan ready")
    assert(publish(titan))
    local readied = eventsNamed("onTitanReady")
    assert(#readied == 1 and readied[1].n == 3 and readied[1][1] == 1 and readied[1][2] == titan.id and readied[1][3] == 1)
    assert(#eventsNamed("onTitanModeChanged") == 0, "the first reported mode is not a change")
    assert(publish(titan) and #eventsNamed("onTitanModeChanged") == 0 and #eventsNamed("onTitanReady") == 1)
    ok = publish(titan, { mode = "pilot", vars = { not_in_catalog = 1 } })
    assert(not ok and #eventsNamed("onTitanModeChanged") == 0, "a refused frame changed the mode")
    assert(publish(titan, { mode = "pilot" }))
    local changed = eventsNamed("onTitanModeChanged")
    assert(#changed == 1 and changed[1].n == 4 and changed[1][1] == 1 and changed[1][2] == titan.id
        and changed[1][3] == "wait" and changed[1][4] == "pilot")
    assert(publish(titan, { mode = "pilot" }) and #eventsNamed("onTitanModeChanged") == 1)
    assert(publish(titan, { mode = "wait" }))
    changed = eventsNamed("onTitanModeChanged")
    assert(#changed == 2 and changed[2][3] == "pilot" and changed[2][4] == "wait")

    -- The hull is gone only when the owner's accepted report says so, and that is announced once.
    assert(publish(titan, { gameplay = gameplayOf() }) and #eventsNamed("onTitanDestroyed") == 0)
    local dead = gameplayOf()
    dead.health.dead = true
    local malformed = gameplayOf()
    malformed.health.dead, malformed.ammo.current = true, -1
    ok = publish(titan, { gameplay = malformed })
    assert(not ok and #eventsNamed("onTitanDestroyed") == 0 and titan.destroyed == false, "a refused report destroyed it")
    assert(publish(titan, { gameplay = dead }))
    local destroyed = eventsNamed("onTitanDestroyed")
    assert(#destroyed == 1 and destroyed[1].n == 2 and destroyed[1][1] == 1 and destroyed[1][2] == titan.id)
    assert(publish(titan, { gameplay = dead }) and publish(titan))
    assert(#eventsNamed("onTitanDestroyed") == 1, "the destruction was announced twice")
    assert(S.titans[1] == titan, "the server removed the Titan on a report: only the owner's controller deletes its actor")
    assert(#eventsNamed("onTitanRemoved") == 0)

    assert(S.removeTitan(titan, "owner_removed"))
    local removed = eventsNamed("onTitanRemoved")
    assert(#removed == 1 and removed[1].n == 3 and removed[1][1] == 1 and removed[1][2] == titan.id
        and removed[1][3] == "owner_removed")
    assert(not S.removeTitan(titan, "owner_removed") and #eventsNamed("onTitanRemoved") == 1)

    -- A new Titan of the same player has its own life.
    now = now + 2
    local second = spawn(1)
    assert(#eventsNamed("onTitanCreated") == 2 and eventsNamed("onTitanCreated")[2][2] == second.id)
    assert(second.destroyed == false and #eventsNamed("onTitanDestroyed") == 1)
end)

test("hit and repair refuse a bad call before anything is looked up, sent or spent", function()
    local titan = liveTitan()
    local bucket = S.clients[1].commands
    local tokens, anchored, sentBefore = bucket.tokens, bucket.at, S.stats.actionsSent
    for index, player in ipairs(BAD_PLAYERS) do
        local id, why = X.hit(player, hitOf())
        assert(id == nil and why == "invalid_player", "bad player #" .. index)
        id, why = X.repair(player, 10)
        assert(id == nil and why == "invalid_player", "bad player #" .. index)
    end
    local function refusedHit(token, edit)
        local request = hitOf()
        edit(request)
        local id, why = X.hit(1, request)
        assert(id == nil and why == token, ("%s (wanted %s)"):format(tostring(why), token))
    end
    for _, junk in ipairs({ "x", 5, true, print, HOSTILE, setmetatable({}, {}), setmetatable(hitOf(), {}),
        setmetatable(hitOf(), { __index = function() error("executed") end }) }) do
        local id, why = X.hit(1, junk)
        assert(id == nil and why == "invalid_request", tostring(why))
    end
    local id, why = X.hit(1, nil)
    assert(id == nil and why == "invalid_request", tostring(why))
    id, why = X.hit(1, {})
    assert(id == nil and why == "invalid_record", tostring(why))
    refusedHit("invalid_request", function(r) r.bogus = 1 end)
    refusedHit("invalid_request", function(r) r.id = "1" end)
    for _, record in ipairs({ "", ("a"):rep(161), "has space", "bad/slash", "semi;colon", "new\nline", "Attacks.\195\169", 5, true, HOSTILE }) do
        refusedHit("invalid_record", function(r) r.record = record end)
    end
    refusedHit("invalid_record", function(r) r.record = nil end)
    for _, origin in ipairs({ { x = 1, y = 2 }, { x = 1, y = 2, z = 3, w = 4 }, { x = 0 / 0, y = 0, z = 0 }, { x = 2e6, y = 0, z = 0 },
        { x = 1, y = 2, z = "3" }, "x", HOSTILE, setmetatable({ x = 1, y = 2, z = 3 }, { __index = function() error("executed") end }) }) do
        refusedHit("invalid_origin", function(r) r.origin = origin end)
    end
    refusedHit("invalid_origin", function(r) r.origin = nil end)
    for _, direction in ipairs({ { x = 0, y = 0, z = 0 }, { x = 2, y = 0, z = 0 }, { x = 0 / 0, y = 1, z = 0 }, { x = 1, y = 0 },
        { x = 1, y = 0, z = 0, w = 1 }, { x = 0, y = -1.0001, z = 0 }, "x", HOSTILE }) do
        refusedHit("invalid_direction", function(r) r.direction = direction end)
    end
    refusedHit("invalid_direction", function(r) r.direction = nil end)
    for _, attacker in ipairs({ ("a"):rep(97), "line\nbreak", "tab\t", 5, true, {}, HOSTILE }) do
        refusedHit("invalid_attacker", function(r) r.attacker = attacker end)
    end
    for _, kind in ipairs({ "laser", "RANGED", "", 5, true, {}, HOSTILE }) do
        refusedHit("invalid_kind", function(r) r.kind = kind end)
    end
    refusedHit("invalid_kind", function(r) r.kind = nil end)
    for _, scale in ipairs({ 0, -1, 4.5, 0 / 0, math.huge, -math.huge, "2", true, {}, HOSTILE }) do
        refusedHit("invalid_scale", function(r) r.scale = scale end)
    end
    for _, amount in ipairs({ 0, -1, 0 / 0, math.huge, -math.huge, 1000001, "5", true, {}, HOSTILE }) do
        id, why = X.repair(1, amount)
        assert(id == nil and why == "invalid_amount", type(amount) .. ": " .. tostring(why))
    end
    id, why = X.repair(1, nil)
    assert(id == nil and why == "invalid_amount", tostring(why))
    -- A valid request for a Titan that is not there says so, after the validation.
    id, why = X.hit(77, hitOf())
    assert(id == nil and why == "no_titan", tostring(why))
    id, why = X.repair(2, 5)
    assert(id == nil and why == "no_titan", tostring(why))
    assert(#sent == 0 and #events == 0 and titan.pendingCount == 0 and titan.requestSeq == 0
        and S.stats.actionsSent == sentBefore and S.clients[77] == nil)
    assert(bucket.tokens == tokens and bucket.at == anchored, "a refused call spent the player's command budget")
end)

test("hit and repair are dispatched to the owner alone, numbered per Titan, bounded, and have no client door", function()
    reset(); ready(1); ready(2)
    local a = spawn(1)
    local id, why = X.hit(1, hitOf())
    assert(id == nil and why == "not_active", tostring(why))
    id, why = X.repair(1, 5)
    assert(id == nil and why == "not_active", tostring(why))
    assert(a.requestSeq == 0 and a.pendingCount == 0)
    now = now + 2
    assert(publish(a))
    local b = spawn(2)
    now = now + 2
    assert(publish(b))
    clear(sent); clear(events)
    local bucket = S.clients[1].commands
    local tokens, anchored, sentBefore = bucket.tokens, bucket.at, S.stats.actionsSent

    local request = hitOf()
    assert(X.hit(1, request) == 1)
    local hits = messages(1, "hit")
    assert(#hits == 1 and #messages(2) == 0 and #messages(1, "repair") == 0)
    assert(keysOf(hits[1]) == "attacker,direction,epoch,id,kind,op,origin,record,request,scale,v", keysOf(hits[1]))
    assert(hits[1].id == a.id and hits[1].epoch == 1 and hits[1].request == 1 and hits[1].v == T.protocol)
    assert(hits[1].record == "Attacks.Bullet_Rifle_Basic" and hits[1].kind == "ranged" and hits[1].scale == 2
        and hits[1].attacker == "player:2")
    assert(hits[1].origin ~= request.origin and hits[1].direction ~= request.direction, "the message aliases the caller's tables")
    request.origin.x, request.record = 999, "Changed"
    assert(hits[1].origin.x == 10 and hits[1].record == "Attacks.Bullet_Rifle_Basic")
    assert(T.normalizeServerMessage(hits[1], Open77TitanCatalog), "the client's validator must take what the server sends")

    assert(X.repair(1, 250.5) == 2)
    local repairs = messages(1, "repair")
    assert(#repairs == 1 and keysOf(repairs[1]) == "amount,epoch,id,op,request,v" and repairs[1].amount == 250.5
        and repairs[1].request == 2 and repairs[1].id == a.id and repairs[1].epoch == 1)
    assert(T.normalizeServerMessage(repairs[1], Open77TitanCatalog))
    -- Each Titan counts its own requests; the optional fields default.
    local plainHit = hitOf()
    plainHit.attacker, plainHit.scale = nil, nil
    assert(X.hit(2, plainHit) == 1)
    local defaulted = messages(2, "hit")[1]
    assert(defaulted.attacker == "" and defaulted.scale == 1 and defaulted.id == b.id and #messages(1, "hit") == 1)
    assert(T.normalizeServerMessage(defaulted, Open77TitanCatalog))
    -- The edges of every bound are legal.
    local edge = hitOf()
    edge.record, edge.attacker, edge.scale = ("A"):rep(160), ("a"):rep(96), 4
    assert(X.hit(1, edge) == 3 and X.repair(1, 1000000) == 4)
    assert(a.requestSeq == 4 and a.pendingCount == 4 and b.requestSeq == 1)
    assert(bucket.tokens == tokens and bucket.at == anchored, "a request spent the player's command budget")
    assert(S.stats.actionsSent == sentBefore + 5 and #eventsNamed("onTitanActionResult") == 0, "dispatch is not completion")

    -- A failed send leaves no request and no gap in the numbering.
    sendFails = true
    id, why = X.hit(1, hitOf())
    assert(id == nil and why == "owner_unavailable" and a.requestSeq == 4 and a.pendingCount == 4, tostring(why))
    sendFails = nil
    assert(X.repair(1, 5) == 5)

    -- 32 unanswered requests at most, per Titan; an answer makes room.
    for _ = a.pendingCount + 1, 32 do assert(X.hit(1, hitOf())) end
    assert(a.pendingCount == 32 and a.requestSeq == 32)
    clear(sent)
    id, why = X.hit(1, hitOf())
    assert(id == nil and why == "pending_full" and #messages(1, "hit") == 0 and a.requestSeq == 32, tostring(why))
    id, why = X.repair(1, 5)
    assert(id == nil and why == "pending_full")
    assert(X.hit(2, hitOf()) == 2, "another Titan's pending set is its own")
    answered(1, a, 7, "hit")
    assert(a.pendingCount == 31 and X.hit(1, hitOf()) == 33)

    -- No client door: neither the controller's request event nor a chat command can ask for a hit or a repair.
    clear(sent)
    now = now + 2
    for _, action in ipairs({ "hit", "repair" }) do
        fire(T.event.request, 1, action)
        local errors = messages(1, "error")
        assert(#errors >= 1 and errors[#errors].reason == "invalid_request", action)
    end
    command(1, "hit", "Attacks.X")
    command(1, "repair", "5")
    assert(#messages(1, "hit") == 0 and #messages(1, "repair") == 0 and lastReply(1)[2] == false)
    assert(a.requestSeq == 33)
end)

test("an answer settles its request once; a malformed, foreign, stale or unsolicited one changes nothing", function()
    reset(); ready(1); ready(2)
    local a = spawn(1)
    now = now + 2
    assert(publish(a))
    local b = spawn(2)
    now = now + 2
    assert(publish(b))
    assert(X.hit(1, hitOf()) == 1 and X.repair(1, 100) == 2 and X.hit(2, hitOf()) == 1)
    clear(events)
    local answeredBefore = S.stats.actionsAnswered
    local function ignored(player, titan, request, kind, edit)
        now = now + 0.05
        local before = S.stats.actionsIgnored
        answered(player, titan, request, kind, edit)
        assert(#eventsNamed("onTitanActionResult") == 0 and a.pendingCount == 2 and b.pendingCount == 1
            and S.stats.actionsIgnored == before + 1, "an answer that must be ignored settled something")
    end
    -- Another player's connection, however it names A's request.
    ignored(2, a, 1, "hit")
    ignored(2, b, 2, "hit")
    -- Stale: another id, another epoch, a request number that was never sent, the wrong kind.
    ignored(1, a, 1, "hit", function(m) m.id = "99999" end)
    ignored(1, a, 1, "hit", function(m) m.epoch = 2 end)
    ignored(1, a, 9, "hit")
    ignored(1, a, 1, "repair")
    ignored(1, a, 2, "hit")
    -- Malformed: every field of the closed schema.
    local MALFORMED = {
        function(m) m.extra = 1 end,
        function(m) m.ok = false end,                                      -- a refusal that carries an amount
        function(m) m.ok, m.amount, m.reason = false, nil, nil end,          -- a refusal with no reason
        function(m) m.amount = nil end,                                    -- taken, with no amount
        function(m) m.amount = 0 / 0 end,
        function(m) m.amount = -1 end,
        function(m) m.amount = 2e6 end,
        function(m) m.reason = ("x"):rep(161) end,
        function(m) m.reason = "two\nlines" end,
        function(m) m.reason = 5 end,
        function(m) m.reason = "" end,
        function(m) m.kind = "heal" end,
        function(m) m.v = 1 end,
        function(m) m.op = "frame" end,
        function(m) m.request = 1.5 end,
        function(m) m.request = "1" end,
        function(m) m.id = 1 end,
        function(m) m.epoch = "1" end,
        function(m) m.ok = "yes" end,
    }
    for _, edit in ipairs(MALFORMED) do ignored(1, a, 1, "hit", edit) end
    for _, raw in ipairs({ "x", 5, true }) do
        now = now + 0.05
        fire(T.event.result, 1, raw)
    end
    fire(T.event.result, 1)
    fire(T.event.result, 3, { v = T.protocol, op = "gameplay_result" })            -- a player with no Titan
    fire(T.event.result, nil, { v = T.protocol, op = "gameplay_result" })          -- no sender at all
    assert(#eventsNamed("onTitanActionResult") == 0 and a.pendingCount == 2 and b.pendingCount == 1)

    -- The real answers: each settles its own request, with exactly what the controller said.
    now = now + 1
    answered(1, a, 2, "repair", function(m) m.reason = nil; m.amount = 100 end)
    local results = eventsNamed("onTitanActionResult")
    assert(#results == 1 and results[1].n == 7 and results[1][1] == 1 and results[1][2] == a.id and results[1][3] == 2
        and results[1][4] == "repair" and results[1][5] == true and results[1][6] == nil and results[1][7] == 100)
    now = now + 0.05
    answered(1, a, 2, "repair")                                                        -- the duplicate
    assert(#eventsNamed("onTitanActionResult") == 1 and a.pendingCount == 1, "an answer settled its request twice")
    now = now + 0.05
    answered(1, a, 1, "hit", function(m) m.ok, m.reason, m.amount = false, "no BT", nil end)
    results = eventsNamed("onTitanActionResult")
    assert(#results == 2 and results[2][3] == 1 and results[2][4] == "hit" and results[2][5] == false
        and results[2][6] == "no BT" and results[2][7] == nil and a.pendingCount == 0)
    now = now + 0.05
    answered(2, b, 1, "hit", function(m) m.reason, m.amount = ("y"):rep(160), 0 end)
    results = eventsNamed("onTitanActionResult")
    assert(#results == 3 and results[3][2] == b.id and results[3][5] == true and results[3][6] == ("y"):rep(160)
        and results[3][7] == 0 and b.pendingCount == 0)
    assert(S.stats.actionsAnswered == answeredBefore + 3)
end)

test("an unanswered request ends once as a timeout, and a late answer settles nothing", function()
    local titan = liveTitan()
    local unansweredBefore = S.stats.actionsUnanswered
    assert(X.hit(1, hitOf()) == 1 and X.repair(1, 5) == 2)
    now = now + 3
    assert(publish(titan))
    S.tick()
    assert(#eventsNamed("onTitanActionResult") == 0 and titan.pendingCount == 2, "a request timed out early")
    assert(X.hit(1, hitOf()) == 3)
    now = now + 2.4
    assert(publish(titan))
    S.tick()
    local results = eventsNamed("onTitanActionResult")
    assert(#results == 2, "exactly the two old requests time out")
    assert(results[1][3] == 1 and results[1][4] == "hit" and results[1][5] == false and results[1][6] == "timeout"
        and results[1][7] == nil and results[1].n == 7 and results[1][1] == 1 and results[1][2] == titan.id)
    assert(results[2][3] == 2 and results[2][4] == "repair" and results[2][5] == false and results[2][6] == "timeout")
    assert(titan.pendingCount == 1 and S.stats.actionsUnanswered == unansweredBefore + 2)
    answered(1, titan, 1, "hit")
    answered(1, titan, 2, "repair")
    S.tick()
    assert(#eventsNamed("onTitanActionResult") == 2 and titan.pendingCount == 1, "a late answer or a tick settled again")
    answered(1, titan, 3, "hit")
    assert(#eventsNamed("onTitanActionResult") == 3 and eventsNamed("onTitanActionResult")[3][6] == "taken")
end)

test("a Titan that ends takes every pending request with it, once, before it is announced removed", function()
    local titan = liveTitan()
    assert(X.hit(1, hitOf()) == 1 and X.repair(1, 5) == 2 and X.hit(1, hitOf()) == 3)
    clear(events)
    assert(S.removeTitan(titan, "owner_dead"))
    assert(titan.pendingCount == 0 and next(titan.pending) == nil)
    assert(#events == 4, #events)
    for index = 1, 3 do
        local event = events[index]
        assert(event.name == "onTitanActionResult" and event.args.n == 7 and event.args[1] == 1 and event.args[2] == titan.id
            and event.args[3] == index and event.args[5] == false and event.args[6] == "titan_removed"
            and event.args[7] == nil, "request " .. index)
    end
    assert(events[1].args[4] == "hit" and events[2].args[4] == "repair" and events[3].args[4] == "hit")
    assert(events[4].name == "onTitanRemoved" and events[4].args[3] == "owner_dead")
    -- Nothing is left to answer, to expire or to remove again.
    answered(1, titan, 1, "hit")
    S.tick()
    assert(not S.removeTitan(titan, "owner_dead") and #events == 4)
    local id, why = X.hit(1, hitOf())
    assert(id == nil and why == "no_titan", tostring(why))
    -- A new Titan of the same player numbers from 1, and the old Titan's answers name another id.
    now = now + 2
    local second = spawn(1)
    assert(publish(second))
    assert(X.hit(1, hitOf()) == 1)
    clear(events)
    answered(1, titan, 1, "hit")
    assert(#eventsNamed("onTitanActionResult") == 0 and second.pendingCount == 1)
    answered(1, second, 1, "hit")
    assert(#eventsNamed("onTitanActionResult") == 1 and second.pendingCount == 0)
end)

-- ---------------------------------------------------------------------------
-- Core credit: a mission script's confirmed Titan-versus-Titan hit or kill, credited to the script's own player's Titan as
-- authored core charge by the `creditCore` export. The request names the victim's Titan by identity only (it may be gone
-- already), travels to the owner's controller as a scoped core_credit message of the same numbering, bounds and answer
-- discipline as hit and repair, and ends in exactly one onTitanActionResult of kind core_credit.
-- ---------------------------------------------------------------------------
local function creditOf(extra)
    return merge({ target = { id = "55", epoch = 3 }, record = "Attacks.BT7274_XO16_Hit", killing = false }, extra)
end

test("creditCore refuses a bad call before anything is looked up, sent or spent", function()
    local titan = liveTitan()
    local bucket = S.clients[1].commands
    local tokens, anchored, sentBefore = bucket.tokens, bucket.at, S.stats.actionsSent
    for index, player in ipairs(BAD_PLAYERS) do
        local id, why = X.creditCore(player, creditOf())
        assert(id == nil and why == "invalid_player", "bad player #" .. index)
    end
    local function refused(token, edit)
        local request = creditOf()
        edit(request)
        local id, why = X.creditCore(1, request)
        assert(id == nil and why == token, ("%s (wanted %s)"):format(tostring(why), token))
    end
    for _, junk in ipairs({ "x", 5, true, print, HOSTILE, setmetatable({}, {}), setmetatable(creditOf(), {}),
        setmetatable(creditOf(), { __index = function() error("executed") end }) }) do
        local id, why = X.creditCore(1, junk)
        assert(id == nil and why == "invalid_request", tostring(why))
    end
    local id, why = X.creditCore(1, nil)
    assert(id == nil and why == "invalid_request", tostring(why))
    id, why = X.creditCore(1, {})
    assert(id == nil and why == "invalid_target", tostring(why))
    refused("invalid_request", function(r) r.bogus = 1 end)
    refused("invalid_request", function(r) r.id = "1" end)
    refused("invalid_request", function(r) r.attacker = "player:2" end)
    refused("invalid_request", function(r) r.request = 1 end)
    for _, target in ipairs({ "55", 55, true, HOSTILE, { id = "55" }, { epoch = 3 }, { id = "0", epoch = 3 }, { id = "055", epoch = 3 },
        { id = 55, epoch = 3 }, { id = ("9"):rep(17), epoch = 3 }, { id = "55", epoch = 0 }, { id = "55", epoch = 1.5 },
        { id = "55", epoch = "3" }, { id = "55", epoch = 2 ^ 53 }, { id = "55", epoch = 0 / 0 }, { id = "55", epoch = math.huge },
        { id = "55", epoch = 3, owner = "2" }, { id = "55", epoch = 3, kind = "titan" },
        setmetatable({ id = "55", epoch = 3 }, {}),
        setmetatable({ id = "55", epoch = 3 }, { __index = function() error("executed") end }) }) do
        refused("invalid_target", function(r) r.target = target end)
    end
    refused("invalid_target", function(r) r.target = nil end)
    for _, record in ipairs({ "", ("a"):rep(161), "has space", "bad/slash", "semi;colon", "new\nline", "Attacks.\195\169", 5, true, HOSTILE }) do
        refused("invalid_record", function(r) r.record = record end)
    end
    refused("invalid_record", function(r) r.record = nil end)
    for _, killing in ipairs({ "true", 1, 0, {}, HOSTILE, print }) do
        refused("invalid_killing", function(r) r.killing = killing end)
    end
    refused("invalid_killing", function(r) r.killing = nil end)
    -- A valid request for a Titan that is not there says so, after the validation.
    id, why = X.creditCore(77, creditOf())
    assert(id == nil and why == "no_titan", tostring(why))
    id, why = X.creditCore(2, creditOf())
    assert(id == nil and why == "no_titan", tostring(why))
    assert(#sent == 0 and #events == 0 and titan.pendingCount == 0 and titan.requestSeq == 0
        and S.stats.actionsSent == sentBefore and S.clients[77] == nil)
    assert(bucket.tokens == tokens and bucket.at == anchored, "a refused call spent the player's command budget")
end)

test("creditCore is dispatched to the owner alone, numbered with hit and repair, bounded, and has no client door", function()
    reset(); ready(1); ready(2)
    local a = spawn(1)
    local id, why = X.creditCore(1, creditOf())
    assert(id == nil and why == "not_active", tostring(why))
    assert(a.requestSeq == 0 and a.pendingCount == 0 and #messages(1, "core_credit") == 0)
    now = now + 2
    assert(publish(a))
    local b = spawn(2)
    now = now + 2
    assert(publish(b))
    clear(sent); clear(events)
    local bucket = S.clients[1].commands
    local tokens, anchored, sentBefore = bucket.tokens, bucket.at, S.stats.actionsSent

    local request = creditOf()
    assert(X.creditCore(1, request) == 1)
    local credits = messages(1, "core_credit")
    assert(#credits == 1 and #messages(2) == 0 and #sent == 1, "the owner alone is told")
    local message = credits[1]
    assert(keysOf(message) == "epoch,id,killing,op,record,request,target,v", keysOf(message))
    assert(keysOf(message.target) == "epoch,id", keysOf(message.target))
    assert(message.v == T.protocol and message.id == a.id and message.epoch == 1 and message.request == 1
        and message.target.id == "55" and message.target.epoch == 3 and message.record == "Attacks.BT7274_XO16_Hit"
        and message.killing == false)
    assert(message.target ~= request.target, "the message aliases the caller's table")
    request.target.id, request.record, request.killing = "99", "Changed", true
    assert(message.target.id == "55" and message.record == "Attacks.BT7274_XO16_Hit" and message.killing == false)
    assert(T.normalizeServerMessage(message, Open77TitanCatalog), "the client's validator must take what the server sends")

    -- One numbering with hit and repair. The target is the mission's word: a repeat of the same target is dispatched again
    -- (the controller's own rule decides what it is worth) and a target the server never saw is no different.
    assert(X.hit(1, hitOf()) == 2 and X.creditCore(1, creditOf({ killing = true })) == 3 and X.repair(1, 5) == 4)
    assert(X.creditCore(1, creditOf()) == 5 and X.creditCore(1, creditOf()) == 6)
    assert(X.creditCore(1, creditOf({ target = { id = "99999", epoch = 7 } })) == 7)
    assert(messages(1, "core_credit")[2].killing == true and messages(1, "core_credit")[5].target.id == "99999"
        and messages(1, "core_credit")[5].target.epoch == 7)
    -- The edges of every bound are legal; each Titan counts its own requests.
    assert(X.creditCore(1, { target = { id = ("9"):rep(16), epoch = 2 ^ 53 - 1 }, record = ("A"):rep(160), killing = true }) == 8)
    local edge = messages(1, "core_credit")[6]
    assert(edge.target.id == ("9"):rep(16) and edge.target.epoch == 9007199254740991 and #edge.record == 160)
    assert(T.normalizeServerMessage(edge, Open77TitanCatalog))
    assert(X.creditCore(2, creditOf()) == 1 and #messages(2, "core_credit") == 1 and messages(2, "core_credit")[1].id == b.id)
    assert(a.requestSeq == 8 and a.pendingCount == 8 and b.requestSeq == 1)
    assert(bucket.tokens == tokens and bucket.at == anchored, "a request spent the player's command budget")
    assert(S.stats.actionsSent == sentBefore + 9 and #eventsNamed("onTitanActionResult") == 0, "dispatch is not completion")

    -- A failed send, or a bridge that is gone, leaves no request and no gap in the numbering.
    sendFails = true
    id, why = X.creditCore(1, creditOf())
    assert(id == nil and why == "owner_unavailable" and a.requestSeq == 8 and a.pendingCount == 8, tostring(why))
    sendFails = nil
    S.clients[1].bridge = false
    id, why = X.creditCore(1, creditOf())
    assert(id == nil and why == "bridge_unavailable" and a.requestSeq == 8, tostring(why))
    S.clients[1].bridge = true
    assert(X.creditCore(1, creditOf()) == 9)

    -- 32 unanswered requests at most, shared with hit and repair; an answer makes room.
    for _ = a.pendingCount + 1, 32 do assert(X.creditCore(1, creditOf())) end
    assert(a.pendingCount == 32 and a.requestSeq == 32)
    clear(sent)
    id, why = X.creditCore(1, creditOf())
    assert(id == nil and why == "pending_full" and #messages(1, "core_credit") == 0 and a.requestSeq == 32, tostring(why))
    id, why = X.hit(1, hitOf())
    assert(id == nil and why == "pending_full", tostring(why))
    assert(X.creditCore(2, creditOf()) == 2, "another Titan's pending set is its own")
    answered(1, a, 9, "core_credit")
    assert(a.pendingCount == 31 and X.creditCore(1, creditOf()) == 33)

    -- No client door: not the controller's request event, not a chat command, and no client event carries one.
    clear(sent)
    now = now + 2
    for _, action in ipairs({ "core_credit", "creditCore" }) do
        fire(T.event.request, 1, action)
        local errors = messages(1, "error")
        assert(#errors >= 1 and errors[#errors].reason == "invalid_request", action)
    end
    command(1, "creditCore", "Attacks.X")
    command(1, "core_credit")
    local forged = { v = T.protocol, op = "core_credit", id = a.id, epoch = a.epoch, request = 1, target = { id = "55", epoch = 3 },
        record = "Attacks.X", killing = true }
    for _, name in ipairs({ T.event.frame, T.event.result, T.event.carry, T.event.hit, T.event.status }) do
        fire(name, 1, forged)
    end
    runTimers()
    assert(#messages(1, "core_credit") == 0 and a.requestSeq == 33 and lastReply(1)[2] == false)
end)

test("a core credit answer settles its own request once, with exactly what the controller said, and no other kind's answer does", function()
    local titan = liveTitan()
    assert(X.creditCore(1, creditOf()) == 1 and X.hit(1, hitOf()) == 2 and X.creditCore(1, creditOf({ killing = true })) == 3
        and X.creditCore(1, creditOf()) == 4 and X.repair(1, 5) == 5)
    local function ignored(request, kind, edit)
        now = now + 0.05
        local before = S.stats.actionsIgnored
        answered(1, titan, request, kind, edit)
        assert(#eventsNamed("onTitanActionResult") == 0 and titan.pendingCount == 5 and S.stats.actionsIgnored == before + 1,
            "an answer that must be ignored settled something")
    end
    -- A request is answered in its own kind only: a hit's, a repair's or a stranger's answer never settles a credit, and a
    -- credit's answer never settles a hit or a repair.
    ignored(1, "hit")
    ignored(1, "repair")
    ignored(3, "hit")
    ignored(2, "core_credit")
    ignored(5, "core_credit")
    ignored(9, "core_credit")
    ignored(1, "core_credit", function(m) m.id = "99999" end)
    ignored(1, "core_credit", function(m) m.epoch = 2 end)
    -- A malformed answer to a credit: a taken one with no amount or an impossible one, a refused one with an amount or no reason.
    for _, edit in ipairs({
        function(m) m.amount = nil end, function(m) m.amount = -1 end, function(m) m.amount = 0 / 0 end,
        function(m) m.amount = 2e6 end, function(m) m.ok, m.amount = false, 5 end, function(m) m.ok, m.reason, m.amount = false, nil, nil end,
        function(m) m.reason = "" end, function(m) m.reason = "two\nlines" end, function(m) m.extra = 1 end,
    }) do ignored(1, "core_credit", edit) end
    -- The real answers. Taken and added nothing (0), taken and added some, refused with the controller's own word.
    now = now + 1
    answered(1, titan, 1, "core_credit", function(m) m.reason = nil; m.amount = 0 end)
    local results = eventsNamed("onTitanActionResult")
    assert(#results == 1 and results[1].n == 7 and results[1][1] == 1 and results[1][2] == titan.id and results[1][3] == 1
        and results[1][4] == "core_credit" and results[1][5] == true and results[1][6] == nil and results[1][7] == 0)
    now = now + 0.05
    answered(1, titan, 1, "core_credit")                                              -- the duplicate
    assert(#eventsNamed("onTitanActionResult") == 1 and titan.pendingCount == 4, "an answer settled its request twice")
    now = now + 0.05
    answered(1, titan, 3, "core_credit", function(m) m.reason = nil; m.amount = 37.5 end)
    results = eventsNamed("onTitanActionResult")
    assert(#results == 2 and results[2][3] == 3 and results[2][4] == "core_credit" and results[2][5] == true
        and results[2][6] == nil and results[2][7] == 37.5)
    now = now + 0.05
    answered(1, titan, 4, "core_credit", function(m) m.ok, m.reason, m.amount = false, "already credited", nil end)
    results = eventsNamed("onTitanActionResult")
    assert(#results == 3 and results[3][3] == 4 and results[3][4] == "core_credit" and results[3][5] == false
        and results[3][6] == "already credited" and results[3][7] == nil and results[3].n == 7)
    assert(titan.pendingCount == 2 and titan.pending[2].kind == "hit" and titan.pending[5].kind == "repair",
        "a credit's answer settled another kind's request")
end)

test("an unanswered core credit ends once as a timeout and a Titan that ends takes it with it, once, before it is announced removed", function()
    local titan = liveTitan()
    assert(X.creditCore(1, creditOf()) == 1)
    now = now + 3
    assert(publish(titan))
    S.tick()
    assert(#eventsNamed("onTitanActionResult") == 0 and titan.pendingCount == 1, "a credit timed out early")
    assert(X.creditCore(1, creditOf({ killing = true })) == 2)
    now = now + 2.4
    assert(publish(titan))
    S.tick()
    local results = eventsNamed("onTitanActionResult")
    assert(#results == 1 and results[1].n == 7 and results[1][1] == 1 and results[1][2] == titan.id and results[1][3] == 1
        and results[1][4] == "core_credit" and results[1][5] == false and results[1][6] == "timeout" and results[1][7] == nil)
    answered(1, titan, 1, "core_credit")                                              -- late
    S.tick()
    assert(#eventsNamed("onTitanActionResult") == 1 and titan.pendingCount == 1, "a late answer or a tick settled again")
    assert(X.creditCore(1, creditOf()) == 3)
    clear(events)
    assert(S.removeTitan(titan, "owner_dead"))
    assert(titan.pendingCount == 0 and next(titan.pending) == nil and #events == 3, #events)
    for index, request in ipairs({ 2, 3 }) do
        local event = events[index]
        assert(event.name == "onTitanActionResult" and event.args.n == 7 and event.args[1] == 1 and event.args[2] == titan.id
            and event.args[3] == request and event.args[4] == "core_credit" and event.args[5] == false
            and event.args[6] == "titan_removed" and event.args[7] == nil, "request " .. request)
    end
    assert(events[3].name == "onTitanRemoved" and events[3].args[3] == "owner_dead")
    answered(1, titan, 2, "core_credit")
    S.tick()
    assert(not S.removeTitan(titan, "owner_dead") and #events == 3)
    local id, why = X.creditCore(1, creditOf())
    assert(id == nil and why == "no_titan", tostring(why))
end)

test("a core credit names its target by identity only: a Titan that a kill already removed is credited the same", function()
    reset(); ready(1); ready(2)
    local a, b = spawn(1), spawn(2)
    now = now + 2
    assert(publish(a) and publish(b))
    local identity = { id = b.id, epoch = b.epoch }
    assert(S.removeTitan(b, "owner_dead") and S.titans[2] == nil)
    clear(sent); clear(events)
    assert(X.creditCore(1, { target = identity, record = "Attacks.BT7274_XO16_Hit", killing = true }) == 1)
    local message = messages(1, "core_credit")[1]
    assert(message.target.id == b.id and message.target.epoch == b.epoch and message.killing == true and message.id == a.id)
    -- Only the source Titan's own state is read: a target no one ever held is dispatched the same.
    assert(X.creditCore(1, creditOf({ target = { id = "123456", epoch = 9 } })) == 2 and a.pendingCount == 2)
end)

-- ---------------------------------------------------------------------------
-- Observed hits: the owner's report that its Titan landed a blow on another player's Titan (hit_observed on its own event).
-- The server authenticates the source, bounds and de-duplicates the report and checks the target against what the sender can
-- see, then publishes it once as onTitanHitObserved. It is the owner's word: nothing is applied, requested or answered.
-- ---------------------------------------------------------------------------
local observedSeqOf = setmetatable({}, { __mode = "k" })
-- A report of `source`'s Titan about `target`'s, numbered per source unless `extra` says otherwise (DROP removes a key).
local function observedOf(source, target, extra)
    observedSeqOf[source] = (observedSeqOf[source] or 0) + 1
    return merge({
        v = T.protocol, op = "hit_observed", id = source.id, epoch = source.epoch, seq = observedSeqOf[source],
        target = { kind = "titan", id = target.id, epoch = target.epoch, owner = tostring(target.owner) },
        record = "Attacks.BT7274_XO16_Hit", origin = { x = 0, y = 0, z = 1 }, point = { x = 20, y = 0, z = 3 },
        direction = { x = 1, y = 0, z = 0 }, kind = "ranged", scale = 1,
    }, extra)
end
local function observe(player, message)
    now = now + 0.01
    fire(T.event.hit, player, message)
end
local function observations() return eventsNamed("onTitanHitObserved") end

-- Player 1's Titan A and player 2's Titan B, both active and in each other's scope, and player 3 (a bridge, no Titan) in both.
local function duel()
    reset(); withViewers(1, 2, 3)
    local a, b = spawn(1), spawn(2)
    observers[1], observers[2] = { 1, 2, 3 }, { 2, 1, 3 }
    now = now + 2
    assert(publish(a) and publish(b))
    S.reconcile(a); S.reconcile(b)
    assert(a.viewers[2] and a.viewers[3] and b.viewers[1] and b.viewers[3])
    clear(sent); clear(events)
    return a, b
end

test("an observation of a visible Titan of another player is published once, as a detached copy, and applies nothing", function()
    local a, b = duel()
    local observed, requested = S.stats.hitsObserved, S.stats.actionsSent
    local raw = observedOf(a, b)
    observe(1, raw)
    local seen = observations()
    assert(#seen == 1 and #events == 1 and seen[1].n == 5, "exactly one host event, and nothing else was raised")
    local args = seen[1]
    assert(args[1] == 1 and math.type(args[1]) == "integer" and args[2] == a.id and args[3] == 2
        and math.type(args[3]) == "integer" and args[4] == b.id and type(args[2]) == "string" and type(args[4]) == "string")
    local report = args[5]
    assert(keysOf(report) == "direction,kind,origin,point,record,scale,seq,target", keysOf(report))
    assert(keysOf(report.target) == "epoch,id,kind,owner" and report.target.kind == "titan" and report.target.id == b.id
        and report.target.epoch == b.epoch and report.target.owner == 2 and math.type(report.target.owner) == "integer")
    assert(report.record == "Attacks.BT7274_XO16_Hit" and report.kind == "ranged" and report.scale == 1 and report.seq == 1
        and report.origin.x == 0 and report.origin.z == 1 and report.point.x == 20 and report.point.z == 3
        and report.direction.x == 1 and keysOf(report.origin) == "x,y,z" and keysOf(report.point) == "x,y,z"
        and keysOf(report.direction) == "x,y,z")
    -- Detached: no table is shared with the sender's message, and a later write to either changes nothing of the other.
    assert(report ~= raw and report.target ~= raw.target and report.origin ~= raw.origin and report.point ~= raw.point
        and report.direction ~= raw.direction)
    raw.origin.x, raw.target.id, raw.record = 99, "x", "other"
    assert(report.origin.x == 0 and report.target.id == b.id and report.record == "Attacks.BT7274_XO16_Hit")
    report.point.x, report.target.owner = -1, 7
    observe(1, observedOf(a, b))
    local second = observations()[2][5]
    assert(second ~= report and second.target ~= report.target and second.point ~= report.point and second.point.x == 20
        and second.target.owner == 2 and second.seq == 2, "a report shares state with another report")
    -- A record name is data: it never chooses what the server raises.
    observe(1, observedOf(a, b, { record = "onTitanRemoved" }))
    assert(#observations() == 3 and #events == 3)
    for _, event in ipairs(events) do assert(event.name == "onTitanHitObserved", event.name) end
    -- Observed, not applied: nobody was sent anything, no hit or repair was dispatched or answered, nothing was recorded.
    assert(#sent == 0, "an observation caused a message to a client")
    assert(S.stats.actionsSent == requested and a.pendingCount == 0 and b.pendingCount == 0 and a.requestSeq == 0
        and b.requestSeq == 0 and #messages(2, "hit") == 0 and #messages(1, "hit") == 0, "an observation became a hit")
    assert(X.getState(2).gameplay == nil and not b.destroyed and S.stats.hitsObserved == observed + 3)
end)

test("only the sender's own current Titan, epoch and published frame can be the source of an observation", function()
    local a, b = duel()
    local c = spawn(3)                 -- granted: its controller has not published a frame yet
    clear(sent); clear(events)
    local observed = S.stats.hitsObserved
    local function refused(player, message, why)
        observe(player, message)
        assert(#observations() == 0 and #events == 0, why .. ": an observation was published")
    end
    refused(1, observedOf(a, b, { seq = 1, id = b.id }), "another Titan's id")
    refused(1, observedOf(a, b, { seq = 1, id = "99999" }), "an id nobody holds")
    refused(1, observedOf(a, b, { seq = 1, epoch = 2 }), "another epoch")
    refused(2, observedOf(a, b, { seq = 1 }), "another player's connection with A's identity")
    refused(4, observedOf(a, b, { seq = 1 }), "a player with no Titan")
    refused(3, observedOf(c, b, { seq = 1 }), "a granted Titan whose controller has not published")
    refused(nil, observedOf(a, b, { seq = 1 }), "no sender at all")
    refused(77, observedOf(a, b, { seq = 1 }), "a player the server never saw")
    assert(S.stats.hitsObserved == observed)
    -- None of that used up sequence 1: the real source still has it, and so has C once it has published.
    observe(1, observedOf(a, b, { seq = 1 }))
    assert(#observations() == 1 and observations()[1][1] == 1 and observations()[1][2] == a.id)
    now = now + 0.05
    assert(publish(c))
    observe(3, observedOf(c, b, { seq = 1 }))
    assert(#observations() == 2 and observations()[2][1] == 3 and observations()[2][2] == c.id and observations()[2][3] == 2)
end)

test("the target must be another player's current Titan, exactly, one that has published and one the sender can see", function()
    local a, b = duel()
    local c = spawn(3)
    observers[3] = { 3, 1, 2 }
    S.reconcile(c)
    assert(c.viewers[1] and c.viewers[2])
    clear(sent); clear(events)
    local function named(id, epoch, owner)
        return { target = { kind = "titan", id = id, epoch = epoch, owner = owner } }
    end
    local function refused(message, why)
        observe(1, message)
        assert(#observations() == 0 and #events == 0, why .. ": an observation was published")
    end
    refused(observedOf(a, a, { seq = 1 }), "the sender's own Titan")
    refused(observedOf(a, b, merge({ seq = 1 }, named(b.id, 1, "1"))), "B's id under A's owner")
    refused(observedOf(a, b, merge({ seq = 1 }, named(b.id, 1, "3"))), "B's id under C's owner")
    refused(observedOf(a, b, merge({ seq = 1 }, named(b.id, 1, "99"))), "B's id under a player with no Titan")
    refused(observedOf(a, b, merge({ seq = 1 }, named(b.id, 2, "2"))), "another epoch of B")
    refused(observedOf(a, b, merge({ seq = 1 }, named("99999", 1, "2"))), "an id nobody holds")
    refused(observedOf(a, b, merge({ seq = 1 }, named(c.id, 1, "2"))), "C's id under B's owner")
    refused(observedOf(a, c, { seq = 1 }), "C, whose controller has not published")
    -- The sender must be among the players the platform streams the target's owner to.
    observers[2] = { 2, 3 }
    S.reconcile(b)
    assert(b.viewers[1] == nil and b.viewers[3])
    refused(observedOf(a, b, { seq = 1 }), "a Titan the sender cannot see")
    observers[2] = { 2, 1, 3 }
    S.reconcile(b)
    assert(b.viewers[1])
    observe(1, observedOf(a, b, { seq = 1 }))
    assert(#observations() == 1 and observations()[1][4] == b.id, "the same report, once B is in scope again")
    -- ... and C once it has published, by its own identity.
    now = now + 0.05
    assert(publish(c))
    observe(1, observedOf(a, c, { seq = 2 }))
    assert(#observations() == 2 and observations()[2][3] == 3 and observations()[2][4] == c.id)
    -- The identity in the report is the server's own record of the Titan that was hit: its owner's number and its id.
    assert(observations()[2][5].target.owner == 3 and observations()[2][5].target.id == c.id)
end)

test("a malformed or oversized observation is refused whole, never published, never consumes a sequence, and is reported once", function()
    local a, b = duel()
    local rejected = S.stats.hitsRejected
    local function bad(edit)
        return function()
            local message = observedOf(a, b, { seq = 1 })
            edit(message)
            return message
        end
    end
    local cases = {
        bad(function(m) m.v = 1 end), bad(function(m) m.op = "hit" end), bad(function(m) m.op = "frame" end),
        bad(function(m) m.op = "carry_request" end), bad(function(m) m.extra = true end),
        bad(function(m) m.attacker = "player:1" end), bad(function(m) m.request = 1 end),
        bad(function(m) m.id = 9 end), bad(function(m) m.id = "0" end), bad(function(m) m.id = ("9"):rep(17) end),
        bad(function(m) m.epoch = 0 end), bad(function(m) m.epoch = 1.5 end), bad(function(m) m.epoch = "1" end),
        bad(function(m) m.seq = 0 end), bad(function(m) m.seq = 1.5 end), bad(function(m) m.seq = 0 / 0 end),
        bad(function(m) m.seq = math.huge end), bad(function(m) m.seq = 2 ^ 53 end), bad(function(m) m.seq = "1" end),
        bad(function(m) m.seq = nil end),
        bad(function(m) m.target = nil end), bad(function(m) m.target = "2" end), bad(function(m) m.target.kind = "npc" end),
        bad(function(m) m.target.kind = nil end), bad(function(m) m.target.id = "0" end), bad(function(m) m.target.id = 2 end),
        bad(function(m) m.target.epoch = 0 end), bad(function(m) m.target.epoch = "1" end),
        bad(function(m) m.target.owner = "x" end), bad(function(m) m.target.owner = 2 end),
        bad(function(m) m.target.owner = nil end), bad(function(m) m.target.extra = 1 end),
        bad(function(m) m.record = nil end), bad(function(m) m.record = "bad record" end), bad(function(m) m.record = "" end),
        bad(function(m) m.record = ("r"):rep(T.limits.actionRecord + 1) end), bad(function(m) m.record = 5 end),
        bad(function(m) m.origin = nil end), bad(function(m) m.origin.x = 0 / 0 end),
        bad(function(m) m.origin.y = math.huge end), bad(function(m) m.origin.z = T.limits.coordinate + 1 end),
        bad(function(m) m.origin.w = 1 end), bad(function(m) m.origin.z = nil end),
        bad(function(m) m.point = nil end), bad(function(m) m.point.x = 0 / 0 end),
        bad(function(m) m.point.y = -math.huge end), bad(function(m) m.point.z = -T.limits.coordinate - 1 end),
        bad(function(m) m.point.w = 1 end), bad(function(m) m.point.x = nil end), bad(function(m) m.point = 1 end),
        bad(function(m) m.direction = nil end), bad(function(m) m.direction = { x = 0, y = 0, z = 0 } end),
        bad(function(m) m.direction.x = 2 end), bad(function(m) m.direction.y = 0 / 0 end),
        bad(function(m) m.kind = nil end), bad(function(m) m.kind = "laser" end), bad(function(m) m.kind = 1 end),
        bad(function(m) m.scale = 0 end), bad(function(m) m.scale = -1 end), bad(function(m) m.scale = T.limits.actionScale + 0.5 end),
        bad(function(m) m.scale = 0 / 0 end), bad(function(m) m.scale = "1" end),
        -- a table that carries a metatable is never read, so nothing it holds can run
        bad(function(m) setmetatable(m, {}) end), bad(function(m) setmetatable(m.target, {}) end),
        bad(function(m) setmetatable(m.origin, {}) end), bad(function(m) setmetatable(m.point, {}) end),
        bad(function(m) setmetatable(m.direction, {}) end),
        function() return setmetatable({}, { __pairs = function() error("executed") end, __index = function() error("executed") end }) end,
        function() return nil end, function() return 1 end, function() return "hit_observed" end, function() return true end,
        function() return print end, function() return HOSTILE end, function() return {} end,
    }
    for index, make in ipairs(cases) do
        observe(1, make())
        assert(#observations() == 0 and #events == 0, "case " .. index .. " was published")
    end
    assert(S.stats.hitsRejected == rejected + #cases, "every one was counted as refused: " .. (S.stats.hitsRejected - rejected))
    -- The owner hears of it, at most once per five seconds.
    local errors = messages(1, "error")
    assert(#errors == 1 and errors[1].reason:find("^hit_rejected:%l[%l_]*$"), #errors .. " " .. tostring(errors[1] and errors[1].reason))
    now = now + 5
    observe(1, bad(function(m) m.kind = "laser" end)())
    errors = messages(1, "error")
    assert(#errors == 2 and errors[2].reason == "hit_rejected:hit_kind" and #observations() == 0)
    -- Not one of them used sequence 1; the sender is nowhere told another Titan's.
    now = now + 1
    observe(1, observedOf(a, b, { seq = 1 }))
    assert(#observations() == 1 and observations()[1][5].seq == 1 and #messages(2, "error") == 0)
    -- The extremes of every bound are taken, and the report is the sender's numbers, nothing computed from them.
    local limits = T.limits
    now = now + 1
    observe(1, observedOf(a, b, { seq = 2, scale = limits.actionScale, record = ("r"):rep(limits.actionRecord),
        origin = { x = limits.coordinate, y = -limits.coordinate, z = 0 }, point = { x = -limits.coordinate, y = 0, z = limits.coordinate },
        direction = { x = -1, y = 1, z = 0.001 }, kind = "melee" }))
    local edge = observations()[2] and observations()[2][5]
    assert(edge and edge.scale == 4 and #edge.record == limits.actionRecord and edge.origin.x == limits.coordinate
        and edge.point.z == limits.coordinate and edge.direction.x == -1 and edge.direction.z == 0.001 and edge.kind == "melee")
end)

test("a repeated sequence number is ignored, reports that arrive newest-first in one tick are all taken, and the window is bounded", function()
    local a, b = duel()
    for seq = 1, 5 do observe(1, observedOf(a, b, { seq = seq })) end
    assert(#observations() == 5)
    for _, seq in ipairs({ 1, 3, 5, 5 }) do observe(1, observedOf(a, b, { seq = seq })) end
    assert(#observations() == 5 and S.stats.hitsIgnored >= 4, "a repeat was published twice")
    -- One tick's deliveries run newest first: 8, 7, 6 are three reports and each is taken.
    for seq = 8, 6, -1 do observe(1, observedOf(a, b, { seq = seq })) end
    assert(#observations() == 8)
    assert(observations()[6][5].seq == 8 and observations()[7][5].seq == 7 and observations()[8][5].seq == 6, "arrival order")
    for _, seq in ipairs({ 6, 7, 8 }) do observe(1, observedOf(a, b, { seq = seq })) end
    assert(#observations() == 8, "a late arrival was taken twice")
    -- Only the newest hitWindow numbers are remembered: older than that is refused, newer than that and unseen is taken.
    local window = T.limits.hitWindow
    observe(1, observedOf(a, b, { seq = 20 + window }))
    assert(#observations() == 9)
    observe(1, observedOf(a, b, { seq = 20 }))
    observe(1, observedOf(a, b, { seq = 5 }))
    assert(#observations() == 9, "a number out of the window was taken")
    observe(1, observedOf(a, b, { seq = 21 }))
    observe(1, observedOf(a, b, { seq = 21 }))
    assert(#observations() == 10 and observations()[10][5].seq == 21, "inside the window once, never twice")
    -- A report the server refuses for its target does not use its number up.
    observers[2] = { 2 }
    S.reconcile(b)
    observe(1, observedOf(a, b, { seq = 400 }))
    assert(#observations() == 10)
    observers[2] = { 2, 1, 3 }
    S.reconcile(b)
    observe(1, observedOf(a, b, { seq = 400 }))
    observe(1, observedOf(a, b, { seq = 400 }))
    assert(#observations() == 11 and observations()[11][5].seq == 400)
    -- The same number from the other player's Titan is its own sequence.
    observe(2, observedOf(b, a, { seq = 400 }))
    assert(#observations() == 12 and observations()[12][1] == 2 and observations()[12][5].seq == 400)
end)

test("observations have a budget of their own per source Titan, spent before anything is parsed", function()
    local a, b = duel()
    local limits = T.limits
    assert(limits.eventBurst == 128, "the budget is the event rate and burst")
    local frames, relayed, carried, results = a.frames.tokens, a.events.tokens, a.carryMessages.tokens, a.results.tokens
    -- At one instant exactly the burst gets through; the rest is dropped without a word.
    local ignored = S.stats.hitsIgnored
    for seq = 1, limits.eventBurst + 50 do fire(T.event.hit, 1, observedOf(a, b, { seq = seq })) end
    assert(#observations() == limits.eventBurst and S.stats.hitsIgnored == ignored + 50, #observations())
    -- It is a bucket of its own: the Titan's frames, one-shot events, carry and answers are untouched, and so is B's.
    assert(a.frames.tokens == frames and a.events.tokens == relayed and a.carryMessages.tokens == carried
        and a.results.tokens == results, "an observation spent another budget")
    assert(publish(a))
    observe(2, observedOf(b, a, { seq = 1 }))
    assert(#observations() == limits.eventBurst + 1 and observations()[limits.eventBurst + 1][1] == 2)
    -- Garbage spends it too, and a valid report with no token left is not taken: nothing was parsed for it.
    now = now + 2
    local before, rejected = #observations(), S.stats.hitsRejected
    for _ = 1, limits.eventBurst + 72 do fire(T.event.hit, 1, {}) end
    assert(S.stats.hitsRejected == rejected + limits.eventBurst, "only what had a token was parsed")
    fire(T.event.hit, 1, observedOf(a, b, { seq = 1000 }))
    assert(#observations() == before, "a valid report was taken with no budget left")
    -- The bucket refills with time (the sustained rate), and a refused report cost no sequence number.
    now = now + 1
    fire(T.event.hit, 1, observedOf(a, b, { seq = 1000 }))
    assert(#observations() == before + 1 and observations()[before + 1][5].seq == 1000)
end)

test("an observation belongs to one Titan generation: a replaced or removed Titan cannot be named by its old identity", function()
    local a, b = duel()
    observe(1, observedOf(a, b, { seq = 1 }))
    assert(#observations() == 1)
    -- B is replaced: its old identity names nothing any more, the new one does.
    S.removeTitan(b, "owner_removed")
    now = now + 2
    local b2 = spawn(2)
    assert(publish(b2))
    S.reconcile(b2)
    clear(events)
    observe(1, observedOf(a, b, { seq = 2 }))
    assert(#observations() == 0, "a replaced target was named by its old id")
    observe(1, observedOf(a, b2, { seq = 2 }))
    assert(#observations() == 1 and observations()[1][4] == b2.id and observations()[1][5].target.id == b2.id)
    -- A is replaced: the old grant cannot report, the new one counts from 1 again.
    S.removeTitan(a, "owner_removed")
    now = now + 2
    local a2 = spawn(1)
    assert(publish(a2))
    S.reconcile(a2)
    clear(events)
    observe(1, observedOf(a, b2, { seq = 3 }))
    assert(#observations() == 0, "a replaced source reported with its old id")
    observe(1, observedOf(a2, b2, { seq = 1 }))
    assert(#observations() == 1 and observations()[1][2] == a2.id and observations()[1][5].seq == 1)
    -- A gone target and a gone source leave nothing to authenticate.
    S.removeTitan(b2, "owner_removed")
    clear(events)
    observe(1, observedOf(a2, b2, { seq = 2 }))
    S.removeTitan(a2, "owner_removed")
    observe(1, observedOf(a2, b2, { seq = 3 }))
    assert(#observations() == 0 and S.titans[1] == nil)
end)

test("an observation is no door to anything else, and no other door carries one", function()
    local a, b = duel()
    local requested = S.stats.actionsSent
    -- The observation event takes only the observation: the other client messages are refused there.
    observe(1, { v = T.protocol, op = "gameplay_result", id = a.id, epoch = a.epoch, request = 1, kind = "hit", ok = true,
        reason = "taken", amount = 1 })
    observe(1, { v = T.protocol, op = "carry_request", id = a.id, epoch = a.epoch, request = 1, kind = "npc", entityId = "5" })
    observe(1, { v = T.protocol, op = "frame" })
    observe(1, { v = T.protocol, op = "hit", id = b.id, epoch = b.epoch, request = 1, record = "Attacks.X",
        origin = { x = 0, y = 0, z = 0 }, direction = { x = 1, y = 0, z = 0 }, kind = "ranged" })
    assert(#observations() == 0 and #eventsNamed("onTitanActionResult") == 0 and a.pendingCount == 0 and b.pendingCount == 0)
    -- And an observation sent on any other event is that event's refusal, never a published observation.
    local before = S.stats.framesRejected
    for _, name in ipairs({ T.event.frame, T.event.result, T.event.carry, T.event.request }) do
        fire(name, 1, observedOf(a, b, { seq = 1 }))
    end
    runTimers()
    assert(#observations() == 0 and #events == 0 and #messages(2, "hit") == 0 and #messages(1, "hit") == 0,
        "another event took an observation")
    assert(b.pendingCount == 0 and S.stats.framesRejected > before)
    -- No export takes one: the only way a script sees an observation is the host event, and the only way it counts is its own call.
    assert(X.hitObserved == nil and X.observeHit == nil and X.hit ~= nil)
    assert(S.stats.actionsSent == requested)
end)

-- ---------------------------------------------------------------------------
-- Observed status effects: the same observation as a hit, for a status effect the owner's controller's own calls would apply to
-- another player's Titan (status_observed on its own event). One source and target rule, ONE budget and ONE per-source
-- sequence window with the hits; published once as onTitanStatusObserved and applied by nothing.
-- ---------------------------------------------------------------------------
-- A status observation of `source`'s Titan about `target`'s, numbered by the same per-source count as the hits.
local function statusOf(source, target, extra)
    observedSeqOf[source] = (observedSeqOf[source] or 0) + 1
    return merge({
        v = T.protocol, op = "status_observed", id = source.id, epoch = source.epoch, seq = observedSeqOf[source],
        target = { kind = "titan", id = target.id, epoch = target.epoch, owner = tostring(target.owner) },
        effect = "BaseStatusEffect.Burning",
    }, extra)
end
local function observeStatus(player, message)
    now = now + 0.01
    fire(T.event.status, player, message)
end
local function statuses() return eventsNamed("onTitanStatusObserved") end

test("an observed status effect of a visible Titan of another player is published once, as a detached copy, and applies nothing", function()
    local a, b = duel()
    local hits, effects, requested = S.stats.hitsObserved, S.stats.statusObserved, S.stats.actionsSent
    local raw = statusOf(a, b)
    observeStatus(1, raw)
    local seen = statuses()
    assert(#seen == 1 and #events == 1 and seen[1].n == 5, "exactly one host event, and nothing else was raised")
    local args = seen[1]
    assert(args[1] == 1 and math.type(args[1]) == "integer" and args[2] == a.id and args[3] == 2
        and math.type(args[3]) == "integer" and args[4] == b.id and type(args[2]) == "string" and type(args[4]) == "string")
    local report = args[5]
    assert(keysOf(report) == "effect,seq,target", "no duration is made up for a call that had none: " .. keysOf(report))
    assert(keysOf(report.target) == "epoch,id,kind,owner" and report.target.kind == "titan" and report.target.id == b.id
        and report.target.epoch == b.epoch and report.target.owner == 2 and math.type(report.target.owner) == "integer")
    assert(report.effect == "BaseStatusEffect.Burning" and report.seq == 1 and report.duration == nil)
    -- Detached: no table is shared with the sender's message, and a later write to either changes nothing of the other.
    assert(report ~= raw and report.target ~= raw.target)
    raw.target.id, raw.effect = "x", "other"
    assert(report.target.id == b.id and report.effect == "BaseStatusEffect.Burning")
    report.target.owner = 7
    observeStatus(1, statusOf(a, b))
    assert(statuses()[2][5].target ~= report.target and statuses()[2][5].target.owner == 2)
    -- A duration is kept exactly as given, and 0 is a duration; the edges of the bound are taken.
    observeStatus(1, statusOf(a, b, { duration = 2.5 }))
    observeStatus(1, statusOf(a, b, { duration = 0 }))
    observeStatus(1, statusOf(a, b, { duration = T.limits.time }))
    local list = statuses()
    assert(#list == 5 and keysOf(list[3][5]) == "duration,effect,seq,target" and list[3][5].duration == 2.5
        and list[4][5].duration == 0 and list[5][5].duration == T.limits.time)
    -- An effect name is data: it never chooses what the server raises, and its longest form is taken.
    observeStatus(1, statusOf(a, b, { effect = "onTitanRemoved" }))
    observeStatus(1, statusOf(a, b, { effect = ("E"):rep(T.limits.actionRecord) }))
    assert(#statuses() == 7 and #events == 7 and #statuses()[7][5].effect == T.limits.actionRecord)
    for _, event in ipairs(events) do assert(event.name == "onTitanStatusObserved", event.name) end
    -- Observed, not applied: nobody was sent anything, no request was dispatched or answered, nothing was recorded.
    assert(#sent == 0, "an observation caused a message to a client")
    assert(S.stats.actionsSent == requested and a.pendingCount == 0 and b.pendingCount == 0 and a.requestSeq == 0
        and b.requestSeq == 0 and #messages(2, "hit") == 0 and #messages(2, "repair") == 0 and #messages(1, "core_credit") == 0
        and #messages(2, "core_credit") == 0, "a status observation became a request")
    assert(X.getState(2).gameplay == nil and not b.destroyed and S.stats.statusObserved == effects + 7
        and S.stats.hitsObserved == hits)
end)

test("a malformed observed status effect is refused whole, never published, never consumes a sequence, and is reported once", function()
    local a, b = duel()
    local rejected, hits = S.stats.statusRejected, S.stats.hitsRejected
    local function bad(edit)
        return function()
            local message = statusOf(a, b, { seq = 1 })
            edit(message)
            return message
        end
    end
    local cases = {
        bad(function(m) m.v = 1 end), bad(function(m) m.op = "hit_observed" end), bad(function(m) m.op = "status" end),
        bad(function(m) m.op = "frame" end), bad(function(m) m.extra = true end), bad(function(m) m.request = 1 end),
        -- the fields of a hit are not the fields of a status effect
        bad(function(m) m.record = "Attacks.BT7274_XO16_Hit" end), bad(function(m) m.origin = { x = 0, y = 0, z = 1 } end),
        bad(function(m) m.point = { x = 0, y = 0, z = 1 } end), bad(function(m) m.direction = { x = 1, y = 0, z = 0 } end),
        bad(function(m) m.kind = "ranged" end), bad(function(m) m.scale = 1 end), bad(function(m) m.attacker = "player:1" end),
        bad(function(m) m.id = 9 end), bad(function(m) m.id = "0" end), bad(function(m) m.id = ("9"):rep(17) end),
        bad(function(m) m.epoch = 0 end), bad(function(m) m.epoch = 1.5 end), bad(function(m) m.epoch = "1" end),
        bad(function(m) m.seq = 0 end), bad(function(m) m.seq = 1.5 end), bad(function(m) m.seq = 0 / 0 end),
        bad(function(m) m.seq = math.huge end), bad(function(m) m.seq = 2 ^ 53 end), bad(function(m) m.seq = "1" end),
        bad(function(m) m.seq = nil end),
        bad(function(m) m.target = nil end), bad(function(m) m.target = "2" end), bad(function(m) m.target.kind = "npc" end),
        bad(function(m) m.target.kind = nil end), bad(function(m) m.target.id = "0" end), bad(function(m) m.target.id = 2 end),
        bad(function(m) m.target.epoch = 0 end), bad(function(m) m.target.epoch = "1" end),
        bad(function(m) m.target.owner = "x" end), bad(function(m) m.target.owner = 2 end),
        bad(function(m) m.target.owner = nil end), bad(function(m) m.target.extra = 1 end),
        bad(function(m) m.effect = nil end), bad(function(m) m.effect = "bad effect" end), bad(function(m) m.effect = "" end),
        bad(function(m) m.effect = "semi;colon" end), bad(function(m) m.effect = ("e"):rep(T.limits.actionRecord + 1) end),
        bad(function(m) m.effect = 5 end), bad(function(m) m.effect = true end), bad(function(m) m.effect = {} end),
        bad(function(m) m.duration = -1 end), bad(function(m) m.duration = -0.001 end), bad(function(m) m.duration = 0 / 0 end),
        bad(function(m) m.duration = math.huge end), bad(function(m) m.duration = -math.huge end),
        bad(function(m) m.duration = T.limits.time + 1 end), bad(function(m) m.duration = "1" end),
        bad(function(m) m.duration = true end), bad(function(m) m.duration = {} end),
        -- a table that carries a metatable is never read, so nothing it holds can run
        bad(function(m) setmetatable(m, {}) end), bad(function(m) setmetatable(m.target, {}) end),
        function() return setmetatable({}, { __pairs = function() error("executed") end, __index = function() error("executed") end }) end,
        function() return nil end, function() return 1 end, function() return "status_observed" end, function() return true end,
        function() return print end, function() return HOSTILE end, function() return {} end,
        function() return observedOf(a, b, { seq = 1 }) end,           -- a hit report on the status event
    }
    for index, make in ipairs(cases) do
        observeStatus(1, make())
        assert(#statuses() == 0 and #events == 0, "case " .. index .. " was published")
    end
    assert(S.stats.statusRejected == rejected + #cases, "every one was counted as refused: " .. (S.stats.statusRejected - rejected))
    assert(S.stats.hitsRejected == hits, "a refused status effect was counted as a hit")
    -- The owner hears of it, at most once per five seconds.
    local errors = messages(1, "error")
    assert(#errors == 1 and errors[1].reason:find("^status_rejected:%l[%l_]*$"), #errors .. " " .. tostring(errors[1] and errors[1].reason))
    assert(T.normalizeServerMessage(errors[1], Open77TitanCatalog), "the client must take the error the server sends")
    now = now + 5
    observeStatus(1, bad(function(m) m.duration = -1 end)())
    errors = messages(1, "error")
    assert(#errors == 2 and errors[2].reason == "status_rejected:status_duration" and #statuses() == 0)
    -- Not one of them used sequence 1; the sender is nowhere told another Titan's.
    now = now + 1
    observeStatus(1, statusOf(a, b, { seq = 1 }))
    assert(#statuses() == 1 and statuses()[1][5].seq == 1 and #messages(2, "error") == 0)
    -- And a hit on the status event is that event's refusal, a status effect on the hit event the hit event's.
    local before = #statuses()
    fire(T.event.hit, 1, statusOf(a, b, { seq = 2 }))
    assert(#statuses() == before and #observations() == 0)
end)

test("an observed status effect needs the sender's own published Titan and a visible, published Titan of another player", function()
    local a, b = duel()
    local c = spawn(3)                 -- granted: its controller has not published a frame yet
    clear(sent); clear(events)
    local effects = S.stats.statusObserved
    local function refused(player, message, why)
        observeStatus(player, message)
        assert(#statuses() == 0 and #events == 0, why .. ": an observation was published")
    end
    refused(1, statusOf(a, b, { seq = 1, id = b.id }), "another Titan's id")
    refused(1, statusOf(a, b, { seq = 1, id = "99999" }), "an id nobody holds")
    refused(1, statusOf(a, b, { seq = 1, epoch = 2 }), "another epoch")
    refused(2, statusOf(a, b, { seq = 1 }), "another player's connection with A's identity")
    refused(4, statusOf(a, b, { seq = 1 }), "a player with no Titan")
    refused(3, statusOf(c, b, { seq = 1 }), "a granted Titan whose controller has not published")
    refused(nil, statusOf(a, b, { seq = 1 }), "no sender at all")
    refused(77, statusOf(a, b, { seq = 1 }), "a player the server never saw")
    local function named(id, epoch, owner)
        return { seq = 1, target = { kind = "titan", id = id, epoch = epoch, owner = owner } }
    end
    refused(1, statusOf(a, a, { seq = 1 }), "the sender's own Titan")
    refused(1, statusOf(a, b, named(b.id, 1, "1")), "B's id under A's owner")
    refused(1, statusOf(a, b, named(b.id, 1, "3")), "B's id under C's owner")
    refused(1, statusOf(a, b, named(b.id, 1, "99")), "B's id under a player with no Titan")
    refused(1, statusOf(a, b, named(b.id, 2, "2")), "another epoch of B")
    refused(1, statusOf(a, b, named("99999", 1, "2")), "an id nobody holds")
    refused(1, statusOf(a, b, named(c.id, 1, "2")), "C's id under B's owner")
    refused(1, statusOf(a, c, { seq = 1 }), "C, whose controller has not published")
    observers[2] = { 2, 3 }
    S.reconcile(b)
    assert(b.viewers[1] == nil)
    refused(1, statusOf(a, b, { seq = 1 }), "a Titan the sender cannot see")
    observers[2] = { 2, 1, 3 }
    S.reconcile(b)
    assert(S.stats.statusObserved == effects)
    -- None of that used up sequence 1: the real source still has it, and C has it once it has published.
    observeStatus(1, statusOf(a, b, { seq = 1 }))
    assert(#statuses() == 1 and statuses()[1][1] == 1 and statuses()[1][2] == a.id and statuses()[1][4] == b.id)
    now = now + 0.05
    assert(publish(c))
    observers[3] = { 3, 1, 2 }
    S.reconcile(c)
    observeStatus(3, statusOf(c, b, { seq = 1 }))
    observeStatus(1, statusOf(a, c, { seq = 2 }))
    assert(#statuses() == 3 and statuses()[2][1] == 3 and statuses()[3][3] == 3 and statuses()[3][5].target.owner == 3)
end)

test("hits and status effects share one sequence: a number is used once whichever kind took it, and the window holds both", function()
    local a, b = duel()
    observe(1, observedOf(a, b))
    observeStatus(1, statusOf(a, b))
    observe(1, observedOf(a, b))
    observeStatus(1, statusOf(a, b))
    assert(#observations() == 2 and #statuses() == 2)
    assert(observations()[1][5].seq == 1 and statuses()[1][5].seq == 2 and observations()[2][5].seq == 3
        and statuses()[2][5].seq == 4, "one count, in the order the controller made it")
    -- A number a hit used is not a status effect's, and the other way round.
    observeStatus(1, statusOf(a, b, { seq = 1 }))
    observe(1, observedOf(a, b, { seq = 2 }))
    observeStatus(1, statusOf(a, b, { seq = 3 }))
    observe(1, observedOf(a, b, { seq = 4 }))
    assert(#observations() == 2 and #statuses() == 2, "a number was taken by both kinds")
    -- One tick's deliveries run newest first, whichever kind each one is: 7, 6 and 5 are three observations, all taken.
    observeStatus(1, statusOf(a, b, { seq = 7 }))
    observe(1, observedOf(a, b, { seq = 6 }))
    observeStatus(1, statusOf(a, b, { seq = 5 }))
    assert(#observations() == 3 and #statuses() == 4)
    assert(statuses()[3][5].seq == 7 and observations()[3][5].seq == 6 and statuses()[4][5].seq == 5, "arrival order")
    for _, seq in ipairs({ 5, 6, 7 }) do
        observeStatus(1, statusOf(a, b, { seq = seq }))
        observe(1, observedOf(a, b, { seq = seq }))
    end
    assert(#observations() == 3 and #statuses() == 4, "a late arrival was taken twice")
    -- One window of the newest numbers of both kinds: a hit far ahead pushes an old status number out of it.
    local window = T.limits.hitWindow
    observe(1, observedOf(a, b, { seq = 20 + window }))
    assert(#observations() == 4)
    observeStatus(1, statusOf(a, b, { seq = 20 }))
    observeStatus(1, statusOf(a, b, { seq = 8 }))
    assert(#statuses() == 4, "a number out of the window was taken")
    observeStatus(1, statusOf(a, b, { seq = 21 }))
    observeStatus(1, statusOf(a, b, { seq = 21 }))
    observe(1, observedOf(a, b, { seq = 21 }))
    assert(#statuses() == 5 and #observations() == 4 and statuses()[5][5].seq == 21, "inside the window once, never twice")
    -- A status effect the server refuses for its target does not use its number up: the next hit can still have it.
    observers[2] = { 2 }
    S.reconcile(b)
    observeStatus(1, statusOf(a, b, { seq = 400 }))
    assert(#statuses() == 5)
    observers[2] = { 2, 1, 3 }
    S.reconcile(b)
    observe(1, observedOf(a, b, { seq = 400 }))
    observeStatus(1, statusOf(a, b, { seq = 400 }))
    assert(#observations() == 5 and observations()[5][5].seq == 400 and #statuses() == 5)
    -- The same number from the other player's Titan is its own sequence.
    observeStatus(2, statusOf(b, a, { seq = 400 }))
    assert(#statuses() == 6 and statuses()[6][1] == 2 and statuses()[6][5].seq == 400)
end)

test("hits and status effects spend one budget per source Titan, before anything is parsed", function()
    local a, b = duel()
    local limits = T.limits
    local frames, relayed, carried, results = a.frames.tokens, a.events.tokens, a.carryMessages.tokens, a.results.tokens
    local hitsIgnored, effectsIgnored = S.stats.hitsIgnored, S.stats.statusIgnored
    -- At one instant exactly the burst gets through, whichever kind spends it; the rest is dropped without a word.
    for seq = 1, limits.eventBurst do
        if seq % 2 == 0 then
            fire(T.event.status, 1, statusOf(a, b, { seq = seq }))
        else
            fire(T.event.hit, 1, observedOf(a, b, { seq = seq }))
        end
    end
    assert(#observations() == limits.eventBurst / 2 and #statuses() == limits.eventBurst / 2)
    fire(T.event.status, 1, statusOf(a, b, { seq = limits.eventBurst + 1 }))
    fire(T.event.hit, 1, observedOf(a, b, { seq = limits.eventBurst + 2 }))
    assert(#observations() + #statuses() == limits.eventBurst, "the burst is the event rate's, shared by both kinds")
    assert(S.stats.statusIgnored == effectsIgnored + 1 and S.stats.hitsIgnored == hitsIgnored + 1)
    -- It is a bucket of its own: the Titan's frames, one-shot events, carry and answers are untouched, and so is B's.
    assert(a.frames.tokens == frames and a.events.tokens == relayed and a.carryMessages.tokens == carried
        and a.results.tokens == results, "an observation spent another budget")
    assert(publish(a))
    observeStatus(2, statusOf(b, a, { seq = 1 }))
    assert(#statuses() == limits.eventBurst / 2 + 1 and statuses()[limits.eventBurst / 2 + 1][1] == 2)
    -- Garbage on either event spends it too, and a valid report with no token left is not taken: nothing was parsed for it.
    now = now + 2
    local before, rejected = #statuses(), S.stats.statusRejected
    for _ = 1, limits.eventBurst + 72 do fire(T.event.status, 1, {}) end
    assert(S.stats.statusRejected == rejected + limits.eventBurst, "only what had a token was parsed")
    local hitsBefore = #observations()
    fire(T.event.hit, 1, observedOf(a, b, { seq = 1000 }))
    fire(T.event.status, 1, statusOf(a, b, { seq = 1001 }))
    assert(#observations() == hitsBefore and #statuses() == before, "a valid report was taken with no budget left")
    -- The bucket refills with time (the sustained rate), and a refused report cost no sequence number.
    now = now + 1
    fire(T.event.status, 1, statusOf(a, b, { seq = 1000 }))
    fire(T.event.hit, 1, observedOf(a, b, { seq = 1001 }))
    assert(#statuses() == before + 1 and statuses()[before + 1][5].seq == 1000
        and #observations() == hitsBefore + 1 and observations()[hitsBefore + 1][5].seq == 1001)
end)

test("an observed status effect belongs to one Titan generation: a replaced or removed Titan cannot be named by its old identity", function()
    local a, b = duel()
    observeStatus(1, statusOf(a, b, { seq = 1 }))
    assert(#statuses() == 1)
    S.removeTitan(b, "owner_removed")
    now = now + 2
    local b2 = spawn(2)
    assert(publish(b2))
    S.reconcile(b2)
    clear(events)
    observeStatus(1, statusOf(a, b, { seq = 2 }))
    assert(#statuses() == 0, "a replaced target was named by its old id")
    observeStatus(1, statusOf(a, b2, { seq = 2 }))
    assert(#statuses() == 1 and statuses()[1][4] == b2.id and statuses()[1][5].target.id == b2.id)
    -- A is replaced: the old grant cannot report, the new one counts from 1 again, hits and status effects alike.
    S.removeTitan(a, "owner_removed")
    now = now + 2
    local a2 = spawn(1)
    assert(publish(a2))
    S.reconcile(a2)
    clear(events)
    observeStatus(1, statusOf(a, b2, { seq = 3 }))
    assert(#statuses() == 0, "a replaced source reported with its old id")
    observeStatus(1, statusOf(a2, b2, { seq = 1 }))
    assert(#statuses() == 1 and statuses()[1][2] == a2.id and statuses()[1][5].seq == 1)
    observe(1, observedOf(a2, b2, { seq = 2 }))
    assert(#observations() == 1)
    -- A gone target and a gone source leave nothing to authenticate.
    S.removeTitan(b2, "owner_removed")
    clear(events)
    observeStatus(1, statusOf(a2, b2, { seq = 3 }))
    S.removeTitan(a2, "owner_removed")
    observeStatus(1, statusOf(a2, b2, { seq = 4 }))
    assert(#statuses() == 0 and S.titans[1] == nil)
end)

test("an observed status effect is no door to anything else: it settles no request, applies nothing, and no other event or export carries one", function()
    local a, b = duel()
    -- One pending request of every kind on each Titan: an observation neither answers nor adds to them.
    assert(X.hit(1, hitOf()) == 1 and X.repair(1, 5) == 2 and X.creditCore(1, creditOf()) == 3 and X.hit(2, hitOf()) == 1
        and X.creditCore(2, creditOf()) == 2)
    clear(sent); clear(events)
    local requested = S.stats.actionsSent
    observeStatus(1, statusOf(a, b))
    observeStatus(2, statusOf(b, a))
    assert(#statuses() == 2 and a.pendingCount == 3 and b.pendingCount == 2 and a.requestSeq == 3 and b.requestSeq == 2
        and #eventsNamed("onTitanActionResult") == 0 and #sent == 0 and S.stats.actionsSent == requested,
        "a status observation settled or added a request")
    -- The status event takes only the status observation: the other client messages are refused there.
    observeStatus(1, observedOf(a, b))
    observeStatus(1, { v = T.protocol, op = "gameplay_result", id = a.id, epoch = a.epoch, request = 3, kind = "core_credit",
        ok = true, amount = 1 })
    observeStatus(1, { v = T.protocol, op = "core_credit", id = a.id, epoch = a.epoch, request = 9, target = { id = b.id, epoch = b.epoch },
        record = "Attacks.X", killing = true })
    observeStatus(1, { v = T.protocol, op = "frame" })
    assert(#statuses() == 2 and #eventsNamed("onTitanActionResult") == 0 and a.pendingCount == 3 and b.pendingCount == 2)
    -- And a status observation sent on any other event is that event's refusal, never a published observation.
    for _, name in ipairs({ T.event.frame, T.event.result, T.event.carry, T.event.request, T.event.hit }) do
        fire(name, 1, statusOf(a, b, { seq = 99 }))
    end
    runTimers()
    assert(#statuses() == 2 and #observations() == 0 and #messages(2, "hit") == 0 and #messages(1, "core_credit") == 0
        and #eventsNamed("onTitanActionResult") == 0 and a.pendingCount == 3 and b.pendingCount == 2,
        "another event took a status observation")
    -- No export takes one: the only way a script sees an observation is the host event, and the only way it counts is its own call.
    assert(X.statusObserved == nil and X.observeStatus == nil and X.applyStatus == nil and X.creditCore ~= nil)
    assert(S.stats.actionsSent == requested)
end)

-- ---------------------------------------------------------------------------
-- Blows on cars: the owner's report that its Titan's weapons took a share (percent of its full health) off a canonical car
-- (vehicle_hit on its own event). The server authenticates and bounds it, publishes it once as the cancellable onTitanVehicleHit
-- and, unless a script vetoes it, takes the share off the car's canonical health once the verdict has settled (setHealth, or
-- explode when it leaves nothing). It shares the observations' one budget and one sequence per source Titan.
-- ---------------------------------------------------------------------------
local function cars()
    clear(vehicleCalls)
    vehicleFailure, verdictsFail = nil, nil
    world.vehicle = {
        [9] = { bucket = 0, x = 0, y = 6, z = 0, health = 1.0 },
        [12] = { bucket = 0, x = -30, y = 40, z = 2, health = 0.5 },
    }
end
-- A report of `source`'s Titan about car `id`, numbered by the same per-source count as the observations.
local function vehicleHitOf(source, id, extra)
    observedSeqOf[source] = (observedSeqOf[source] or 0) + 1
    return merge({
        v = T.protocol, op = "vehicle_hit", id = source.id, epoch = source.epoch, seq = observedSeqOf[source],
        vehicle = tostring(id), share = 25, point = { x = 0, y = 6, z = 0 },
    }, extra)
end
local function reportCar(player, message)
    now = now + 0.01
    fire(T.event.vehicle, player, message)
end
local function vehicleHits() return eventsNamed("onTitanVehicleHit") end
local function vehicleEvents()
    local list = {}
    for _, event in ipairs(events) do
        if event.name == "onTitanVehicleHit" then list[#list + 1] = event end
    end
    return list
end
-- The host's next tick: the verdicts settle and the upkeep reads them.
local function hostTick()
    settleVerdicts()
    S.settleVehicleHits()
end
local function near(a, b) return math.abs(a - b) < 1e-9 end

test("a blow on a car is published once, cancellably, as a detached copy, and the car is touched only once the verdict has settled", function()
    local a, b = duel(); cars()
    local stats = { observed = S.stats.vehicleHitsObserved, applied = S.stats.vehicleHitsApplied, requested = S.stats.actionsSent }
    local raw = vehicleHitOf(a, 9)
    reportCar(1, raw)
    local seen = vehicleHits()
    assert(#seen == 1 and #events == 1 and seen[1].n == 4 and events[1].cancellable == true, "exactly one cancellable host event")
    local args = seen[1]
    assert(args[1] == 1 and math.type(args[1]) == "integer" and args[2] == a.id and type(args[2]) == "string"
        and args[3] == 9 and math.type(args[3]) == "integer")
    local report = args[4]
    assert(keysOf(report) == "health,point,seq,share", keysOf(report))
    assert(report.share == 25 and report.seq == 1 and report.health == 1.0 and keysOf(report.point) == "x,y,z" and report.point.y == 6)
    -- Detached: no table is shared with the sender's message, and a later write to either changes nothing of the other.
    assert(report ~= raw and report.point ~= raw.point)
    raw.point.y, raw.share = 99, 99
    assert(report.point.y == 6 and report.share == 25)
    -- Nothing happens to the car, nobody is told, no request is made, until the verdict settles.
    assert(#vehicleCalls == 0 and world.vehicle[9].health == 1.0 and #sent == 0 and S.stats.actionsSent == stats.requested)
    S.settleVehicleHits()
    assert(#vehicleCalls == 0, "the car was changed before the verdict settled")
    assert(S.stats.vehicleHitsObserved == stats.observed + 1 and S.stats.vehicleHitsApplied == stats.applied)
    hostTick()
    assert(#vehicleCalls == 1 and vehicleCalls[1].call == "setHealth" and vehicleCalls[1].id == 9 and near(vehicleCalls[1].health, 0.75))
    assert(near(world.vehicle[9].health, 0.75) and S.stats.vehicleHitsApplied == stats.applied + 1)
    -- Once: nothing is applied again.
    hostTick(); hostTick()
    assert(#vehicleCalls == 1 and #vehicleHits() == 1 and #sent == 0 and not b.destroyed)
end)

test("a script's veto keeps the car as it is, and only the vetoed hit", function()
    local a = duel(); cars()
    local vetoed, applied = S.stats.vehicleHitsVetoed, S.stats.vehicleHitsApplied
    reportCar(1, vehicleHitOf(a, 9, { share = 30 }))
    reportCar(1, vehicleHitOf(a, 9, { share = 10 }))
    assert(#vehicleEvents() == 2)
    vehicleEvents()[1].vetoed = true
    hostTick()
    assert(#vehicleCalls == 1 and near(vehicleCalls[1].health, 0.9), "the vetoed hit changed the car, or the other did not")
    assert(S.stats.vehicleHitsVetoed == vetoed + 1 and S.stats.vehicleHitsApplied == applied + 1)
    -- A hit that kills is vetoed as well: the car is not exploded.
    reportCar(1, vehicleHitOf(a, 9, { share = 100 }))
    vehicleEvents()[3].vetoed = true
    hostTick()
    assert(#vehicleCalls == 1 and world.vehicle[9].exploded == nil and near(world.vehicle[9].health, 0.9))
end)

test("a hit takes its share off the health as it is when the verdict settles, and blows the car up when nothing is left", function()
    local a = duel(); cars()
    -- 50 % of a car at 0.5 leaves nothing: explode, never a health of zero.
    reportCar(1, vehicleHitOf(a, 12, { share = 50 }))
    hostTick()
    assert(#vehicleCalls == 1 and vehicleCalls[1].call == "explode" and vehicleCalls[1].id == 12 and world.vehicle[12].exploded == true)
    -- A whole car's share is lethal whatever the car's health was.
    reportCar(1, vehicleHitOf(a, 9, { share = 100 }))
    hostTick()
    assert(#vehicleCalls == 2 and vehicleCalls[2].call == "explode" and vehicleCalls[2].id == 9)
    -- What would leave a sliver (0.005 or less) blows it up; a little more is set.
    cars()
    reportCar(1, vehicleHitOf(a, 12, { share = 49.6 }))
    hostTick()
    assert(#vehicleCalls == 1 and vehicleCalls[1].call == "explode")
    cars()
    reportCar(1, vehicleHitOf(a, 12, { share = 49 }))
    hostTick()
    assert(#vehicleCalls == 1 and vehicleCalls[1].call == "setHealth" and near(vehicleCalls[1].health, 0.01))
    -- The car is read again: another script's damage in the tick the verdict took counts, a car that was blown up meanwhile
    -- or that is gone is left alone.
    cars()
    reportCar(1, vehicleHitOf(a, 9, { share = 30 }))
    world.vehicle[9].health = 0.5
    hostTick()
    assert(#vehicleCalls == 1 and near(vehicleCalls[1].health, 0.2), "the health the report saw was applied")
    cars()
    local ignored = S.stats.vehicleHitsIgnored
    reportCar(1, vehicleHitOf(a, 9, { share = 30 }))
    reportCar(1, vehicleHitOf(a, 12, { share = 30 }))
    world.vehicle[9].health, world.vehicle[9].destroyed, world.vehicle[9].exploded = 0, true, true
    world.vehicle[12] = nil
    hostTick()
    assert(#vehicleCalls == 0 and S.stats.vehicleHitsIgnored == ignored + 2, "a car that is gone or a wreck was changed")
end)

test("a hit waits for its verdict: the next report or the upkeep reads it, and one that never settles applies nothing", function()
    local a = duel(); cars()
    local failed = S.stats.vehicleHitsFailed
    reportCar(1, vehicleHitOf(a, 9, { share = 10 }))
    settleVerdicts()
    -- The next report drains what has settled before it is admitted.
    reportCar(1, vehicleHitOf(a, 9, { share = 10 }))
    assert(#vehicleCalls == 1 and near(vehicleCalls[1].health, 0.9) and #vehicleHits() == 2)
    -- The upkeep (the 250 ms tick of the resource) reads the verdicts as well.
    settleVerdicts()
    S.tick()
    assert(#vehicleCalls == 2 and near(vehicleCalls[2].health, 0.8))
    -- A verdict that is still pending waits; one that is not settled after limits.vehicleVerdict seconds applies nothing.
    reportCar(1, vehicleHitOf(a, 9, { share = 10 }))
    now = now + T.limits.vehicleVerdict - 1
    S.settleVehicleHits()
    assert(#vehicleCalls == 2 and S.stats.vehicleHitsFailed == failed)
    now = now + 2
    S.settleVehicleHits()
    hostTick()
    assert(#vehicleCalls == 2 and S.stats.vehicleHitsFailed == failed + 1, "a verdict that never settled was applied")
    -- A platform that refuses is counted, and a hit that could not be published is not applied.
    reportCar(1, vehicleHitOf(a, 9, { share = 10 }))
    vehicleFailure = "vehicle_not_found"
    hostTick()
    assert(#vehicleCalls == 3 and S.stats.vehicleHitsFailed == failed + 2 and near(world.vehicle[9].health, 0.8))
    vehicleFailure = nil
    verdictsFail = "reserved_event"
    reportCar(1, vehicleHitOf(a, 9, { share = 10 }))
    hostTick()
    assert(#vehicleCalls == 3 and S.stats.vehicleHitsFailed == failed + 3 and #vehicleHits() == 4, "an unpublished hit was applied")
end)

test("the source of a blow on a car is the sender's own current Titan, epoch and published frame", function()
    local a, b = duel(); cars()
    local c = spawn(3)                 -- granted: its controller has not published a frame yet
    clear(sent); clear(events)
    local function refused(player, message, why)
        reportCar(player, message)
        assert(#vehicleHits() == 0 and #events == 0 and #vehicleCalls == 0, why .. ": a blow was published")
    end
    refused(1, vehicleHitOf(a, 9, { seq = 1, id = b.id }), "another Titan's id")
    refused(1, vehicleHitOf(a, 9, { seq = 1, id = "99999" }), "an id nobody holds")
    refused(1, vehicleHitOf(a, 9, { seq = 1, epoch = 2 }), "another epoch")
    refused(2, vehicleHitOf(a, 9, { seq = 1 }), "another player's connection with A's identity")
    refused(4, vehicleHitOf(a, 9, { seq = 1 }), "a player with no Titan")
    refused(3, vehicleHitOf(c, 9, { seq = 1 }), "a granted Titan whose controller has not published")
    refused(nil, vehicleHitOf(a, 9, { seq = 1 }), "no sender at all")
    refused(77, vehicleHitOf(a, 9, { seq = 1 }), "a player the server never saw")
    -- None of that used up sequence 1.
    reportCar(1, vehicleHitOf(a, 9, { seq = 1 }))
    assert(#vehicleHits() == 1 and vehicleHits()[1][1] == 1 and vehicleHits()[1][2] == a.id)
    -- A Titan that is gone cannot report with its old identity.
    S.removeTitan(a, "owner_removed")
    reportCar(1, vehicleHitOf(a, 9, { seq = 2 }))
    assert(#vehicleHits() == 1)
end)

test("the car must exist, be alive, be in the sender's bucket and be within reach of the Titan's latest pose, and a refusal changes nothing", function()
    local a, b = duel(); cars()
    clear(events)
    local ignored, observed = S.stats.vehicleHitsIgnored, S.stats.vehicleHitsObserved
    local function refused(message, why)
        reportCar(1, message)
        hostTick()
        assert(#vehicleHits() == 0 and #events == 0 and #vehicleCalls == 0, why .. ": a blow was published or applied")
    end
    -- No such car, and cars that are already wrecks.
    refused(vehicleHitOf(a, 99, { seq = 1 }), "an unknown car")
    world.vehicle[9].destroyed = true
    refused(vehicleHitOf(a, 9, { seq = 1 }), "a destroyed car")
    world.vehicle[9].destroyed, world.vehicle[9].exploded = nil, true
    refused(vehicleHitOf(a, 9, { seq = 1 }), "an exploded car")
    world.vehicle[9].exploded, world.vehicle[9].health = nil, 0
    refused(vehicleHitOf(a, 9, { seq = 1 }), "a car with no health left")
    world.vehicle[9].health = nil
    refused(vehicleHitOf(a, 9, { seq = 1 }), "a car the platform reports no health for")
    world.vehicle[9].health = 1.0
    -- Another routing bucket.
    world.vehicle[9].bucket = 7
    refused(vehicleHitOf(a, 9, { seq = 1 }), "a car in another bucket")
    world.vehicle[9].bucket = 0
    -- Reach: the controller's longest weapon (the railgun, 400 m) plus margin, from the Titan's accepted pose, by the car's
    -- canonical place and not by the report's point.
    assert(T.limits.vehicleReach == 450)
    world.vehicle[9].y = 450.5
    refused(vehicleHitOf(a, 9, { seq = 1, point = { x = 0, y = 6, z = 0 } }), "a car out of reach (the report's own point is near)")
    world.vehicle[9].y = 6
    world.vehicle[12].x, world.vehicle[12].y, world.vehicle[12].z = 300, 300, 300
    refused(vehicleHitOf(a, 12, { seq = 1 }), "a car out of reach in three dimensions")
    -- Not one of those used up sequence 1: the same report is taken once the car is as it should be, and only then.
    assert(S.stats.vehicleHitsIgnored == ignored + 8 and S.stats.vehicleHitsObserved == observed)
    world.vehicle[12].x, world.vehicle[12].y, world.vehicle[12].z = 0, 450, 0
    reportCar(1, vehicleHitOf(a, 12, { seq = 1 }))
    assert(#vehicleHits() == 1 and vehicleHits()[1][3] == 12, "a car exactly at the reach was refused")
    reportCar(1, vehicleHitOf(a, 12, { seq = 1 }))
    assert(#vehicleHits() == 1, "a repeat was published")
    -- The reach is from the Titan's LATEST accepted pose: once it has moved away the same car is out of reach.
    now = now + 1
    assert(publish(a, { pose = { x = 0, y = -100, z = 0, yaw = 0 } }))
    reportCar(1, vehicleHitOf(a, 12, { seq = 2 }))
    assert(#vehicleHits() == 1, "the Titan's old pose was used")
    reportCar(1, vehicleHitOf(a, 9, { seq = 2 }))
    assert(#vehicleHits() == 2 and vehicleHits()[2][3] == 9)
    assert(not b.destroyed)
end)

test("a malformed blow on a car is refused whole, never published or applied, never consumes a sequence, and is reported once", function()
    local a = duel(); cars()
    local rejected = S.stats.vehicleHitsRejected
    local function bad(edit)
        return function()
            local message = vehicleHitOf(a, 9, { seq = 1 })
            edit(message)
            return message
        end
    end
    local cases = {
        bad(function(m) m.v = 1 end), bad(function(m) m.op = "hit_observed" end), bad(function(m) m.op = "status_observed" end),
        bad(function(m) m.op = "frame" end), bad(function(m) m.extra = true end), bad(function(m) m.target = { kind = "titan" } end),
        bad(function(m) m.record = "Attacks.X" end), bad(function(m) m.request = 1 end),
        bad(function(m) m.id = 9 end), bad(function(m) m.id = "0" end), bad(function(m) m.id = ("9"):rep(17) end),
        bad(function(m) m.epoch = 0 end), bad(function(m) m.epoch = 1.5 end), bad(function(m) m.epoch = "1" end),
        bad(function(m) m.seq = 0 end), bad(function(m) m.seq = 1.5 end), bad(function(m) m.seq = 0 / 0 end),
        bad(function(m) m.seq = math.huge end), bad(function(m) m.seq = 2 ^ 53 end), bad(function(m) m.seq = "1" end),
        bad(function(m) m.seq = nil end),
        bad(function(m) m.vehicle = nil end), bad(function(m) m.vehicle = 9 end), bad(function(m) m.vehicle = "0" end),
        bad(function(m) m.vehicle = "09" end), bad(function(m) m.vehicle = "x" end), bad(function(m) m.vehicle = "-9" end),
        bad(function(m) m.vehicle = "9.5" end), bad(function(m) m.vehicle = ("9"):rep(17) end), bad(function(m) m.vehicle = "" end),
        bad(function(m) m.share = nil end), bad(function(m) m.share = 0 end), bad(function(m) m.share = -1 end),
        bad(function(m) m.share = T.limits.vehicleShare + 0.001 end), bad(function(m) m.share = 150 end),
        bad(function(m) m.share = 0 / 0 end), bad(function(m) m.share = math.huge end), bad(function(m) m.share = "25" end),
        bad(function(m) m.share = true end),
        bad(function(m) m.point = nil end), bad(function(m) m.point.x = 0 / 0 end), bad(function(m) m.point.y = math.huge end),
        bad(function(m) m.point.z = T.limits.coordinate + 1 end), bad(function(m) m.point.w = 1 end), bad(function(m) m.point.z = nil end),
        bad(function(m) m.point = 1 end),
        -- a table that carries a metatable is never read, so nothing it holds can run
        bad(function(m) setmetatable(m, {}) end), bad(function(m) setmetatable(m.point, {}) end),
        function() return setmetatable({}, { __pairs = function() error("executed") end, __index = function() error("executed") end }) end,
        function() return nil end, function() return 1 end, function() return "vehicle_hit" end, function() return true end,
        function() return print end, function() return HOSTILE end, function() return {} end,
    }
    for index, make in ipairs(cases) do
        reportCar(1, make())
        assert(#vehicleHits() == 0 and #events == 0 and #vehicleCalls == 0, "case " .. index .. " was published")
    end
    hostTick()
    assert(#vehicleCalls == 0 and S.stats.vehicleHitsRejected == rejected + #cases, "every one is counted as refused")
    -- Told to the owner once (rate limited like every refused frame), with the schema's own token.
    local errors = messages(1, "error")
    assert(#errors == 1 and errors[1].reason:find("vehicle_hit_rejected:", 1, true) == 1, #errors)
    -- The edges are fine: a whole car at the largest share, a sliver, and the largest coordinate.
    local limits = T.limits
    reportCar(1, vehicleHitOf(a, 9, { seq = 1, share = limits.vehicleShare }))
    reportCar(1, vehicleHitOf(a, 9, { seq = 2, share = 1e-6, point = { x = limits.coordinate, y = -limits.coordinate, z = 0 } }))
    assert(#vehicleHits() == 2 and vehicleHits()[1][4].share == 100 and vehicleHits()[2][4].share == 1e-6
        and vehicleHits()[2][4].point.x == limits.coordinate, "no malformed case used sequence 1 up")
end)

test("blows on cars spend the observations' one budget and one sequence window, a number is used once whichever kind took it", function()
    local a, b = duel(); cars()
    local limits = T.limits
    -- Numbers interleave: 1 and 2 were a blow and an effect on a Titan, 3 is a car.
    observe(1, observedOf(a, b))
    observeStatus(1, statusOf(a, b))
    reportCar(1, vehicleHitOf(a, 9))
    assert(#observations() == 1 and #statuses() == 1 and #vehicleHits() == 1 and vehicleHits()[1][4].seq == 3)
    -- A used number is used: for a car after a hit or an effect, and for a hit or an effect after a car.
    for _, seq in ipairs({ 1, 2, 3 }) do reportCar(1, vehicleHitOf(a, 9, { seq = seq })) end
    reportCar(1, vehicleHitOf(a, 9, { seq = 10 }))
    observe(1, observedOf(a, b, { seq = 10 }))
    observeStatus(1, statusOf(a, b, { seq = 3 }))
    assert(#vehicleHits() == 2 and #observations() == 1 and #statuses() == 1, "a number was taken twice")
    -- Reports of one tick arrive newest-first: all are taken, then none twice.
    for seq = 22, 20, -1 do reportCar(1, vehicleHitOf(a, 9, { seq = seq })) end
    assert(#vehicleHits() == 5)
    for _, seq in ipairs({ 20, 21, 22 }) do reportCar(1, vehicleHitOf(a, 9, { seq = seq })) end
    assert(#vehicleHits() == 5)
    -- Only the newest hitWindow numbers are remembered.
    reportCar(1, vehicleHitOf(a, 9, { seq = 30 + limits.hitWindow }))
    reportCar(1, vehicleHitOf(a, 9, { seq = 30 }))
    reportCar(1, vehicleHitOf(a, 9, { seq = 3 }))
    assert(#vehicleHits() == 6, "a number out of the window was taken")
    -- One bucket: a Titan's observations, effects and blows on cars draw on the same tokens, at one instant exactly the burst.
    now = now + 2
    local before, ignored = #statuses(), S.stats.vehicleHitsIgnored
    local carried, results = a.carryMessages.tokens, a.results.tokens
    for seq = 1000, 1099 do fire(T.event.status, 1, statusOf(a, b, { seq = seq })) end
    for seq = 1100, 1149 do fire(T.event.vehicle, 1, vehicleHitOf(a, 9, { seq = seq })) end
    assert(#statuses() == before + 100 and #vehicleHits() == 6 + (limits.eventBurst - 100)
        and S.stats.vehicleHitsIgnored == ignored + (150 - limits.eventBurst), "the two kinds did not share one bucket")
    -- It is a bucket of its own: the Titan's carry messages and answers are untouched.
    assert(a.carryMessages.tokens == carried and a.results.tokens == results, "a blow on a car spent another budget")
end)

test("only so many hits wait for a verdict at once, and a refused one costs no sequence number", function()
    local a = duel(); cars()
    local limits = T.limits
    local ignored = S.stats.vehicleHitsIgnored
    local seq = 0
    for _ = 1, 3 do
        now = now + 1
        for _ = 1, 100 do
            seq = seq + 1
            fire(T.event.vehicle, 1, vehicleHitOf(a, 9, { seq = seq, share = 0.1 }))
        end
    end
    assert(#vehicleHits() == limits.vehiclePending and S.stats.vehicleHitsIgnored == ignored + (300 - limits.vehiclePending),
        #vehicleHits())
    -- Once the verdicts have settled the room is back, and the number a full queue refused is still free.
    now = now + 1
    hostTick()
    assert(#vehicleCalls == limits.vehiclePending)
    reportCar(1, vehicleHitOf(a, 9, { seq = seq }))
    assert(#vehicleHits() == limits.vehiclePending + 1, "the number a full queue refused was used up")
end)

test("a blow on a car is no door to anything else, and no other door carries one", function()
    local a, b = duel(); cars(); clear(coreCalls)
    local requested = S.stats.actionsSent
    -- The vehicle event takes only the vehicle blow: the other client messages are refused there.
    reportCar(1, observedOf(a, b))
    reportCar(1, statusOf(a, b))
    reportCar(1, { v = T.protocol, op = "gameplay_result", id = a.id, epoch = a.epoch, request = 1, kind = "hit", ok = true,
        reason = "taken", amount = 1 })
    reportCar(1, { v = T.protocol, op = "carry_request", id = a.id, epoch = a.epoch, request = 1, kind = "vehicle", entityId = "9" })
    reportCar(1, { v = T.protocol, op = "frame" })
    assert(#vehicleHits() == 0 and #observations() == 0 and #statuses() == 0 and #vehicleCalls == 0)
    -- And a blow on a car sent on any other event is that event's refusal, never a published or applied one.
    local before = S.stats.framesRejected
    for _, name in ipairs({ T.event.frame, T.event.result, T.event.carry, T.event.request, T.event.hit, T.event.status }) do
        fire(name, 1, vehicleHitOf(a, 9, { seq = 99 }))
    end
    runTimers()
    hostTick()
    assert(#vehicleHits() == 0 and #vehicleCalls == 0 and #messages(1, "core_credit") == 0 and S.stats.framesRejected > before,
        "another event took a blow on a car")
    assert(world.vehicle[9].health == 1.0 and #coreCalls == 0)
    -- No export carries one and none applies one: the only way a script sees it is the host event, and it can only veto.
    assert(X.vehicleHit == nil and X.hitVehicle == nil and X.damageVehicle == nil and X.hit ~= nil)
    assert(S.stats.actionsSent == requested and T.event.vehicle == "op77_lightrp:titans:vehicle")
end)

-- ---------------------------------------------------------------------------
-- Blows on players: the owner's report that its Titan's weapons landed on another player's body (player_hit on its own
-- event). The report names the record and a count, never an amount: the server prices it (a mission's setPlayerDamage changes
-- the price), admits it against the victim it reads itself and applies it with Open77.players.damage under pvp = true, so the
-- platform's PvP rules decide. It shares the observations' one budget and one sequence per source Titan.
-- ---------------------------------------------------------------------------
local function playerHitOf(source, victim, extra)
    observedSeqOf[source] = (observedSeqOf[source] or 0) + 1
    return merge({
        v = T.protocol, op = "player_hit", id = source.id, epoch = source.epoch, seq = observedSeqOf[source],
        player = tostring(victim), record = "Attacks.BT7274_XO16_Hit", count = 1,
    }, extra)
end
local function reportPlayer(player, message)
    now = now + 0.01
    fire(T.event.player, player, message)
end
-- What the server printed while `fn` ran (the suite silences print).
local function printed(fn)
    local lines, original = {}, print
    print = function(text) lines[#lines + 1] = tostring(text) end
    local ok, err = pcall(fn)
    print = original
    assert(ok, err)
    return lines
end
local function countLines(lines, text)
    local count = 0
    for _, line in ipairs(lines) do
        if line == text then count = count + 1 end
    end
    return count
end

-- The default price of one blow of each record: amount, platform kind.
local PRICES = {
    { 8, "ranged", "Attacks.BT7274_XO16_Hit", "Attacks.BT7274_Pred_Hit", "Attacks.ExplosionSmall", "Attacks.BT7274_Vortex",
        "Attacks.BT7274_Vortex_x2", "Attacks.BT7274_Vortex_x4", "Attacks.BT7274_Vortex_x8", "Attacks.BT7274_Vortex_x16",
        "Attacks.BT7274_Vortex_x32", "Attacks.BT7274_Vortex_x64" },
    { 25, "ranged", "Attacks.BT7274_Rail_1" }, { 50, "ranged", "Attacks.BT7274_Rail_2" },
    { 75, "ranged", "Attacks.BT7274_Rail_3" }, { 100, "ranged", "Attacks.BT7274_Rail_4" },
    { 35, "explosion", "Attacks.BT7274_Missile", "Attacks.BT7274_FlightRocket" },
    { 15, "explosion", "Attacks.BT7274_MissileBlast", "Attacks.BT7274_FlightBlast", "Attacks.BT7274_Fist_Blast" },
    { 60, "melee", "Attacks.BT7274_Punch", "Attacks.BT7274_Fist", "Attacks.BT7274_Fist_Heavy", "Attacks.BT7274_Fist_Charged",
        "Attacks.BT7274_Fist_Core", "Attacks.BT7274_Sword", "Attacks.BT7274_Sword_Core", "Attacks.BT7274_Sword_Charged",
        "Attacks.BT7274_ArcWave" },
    { 40, "explosion", "Attacks.BT7274_Pound_Mid", "Attacks.BT7274_Pound_Edge" },
    { 100, "explosion", "Attacks.BT7274_Eject" },
    { 2, "explosion", "Attacks.BT7274_Smoke", "Attacks.BT7274_Gas" },
}

test("a blow on another player is priced by the server per record and applied under the PvP rules", function()
    local a = duel()
    local applied, observed, requested = S.stats.playerHitsApplied, S.stats.playerHitsObserved, S.stats.actionsSent
    reportPlayer(1, playerHitOf(a, 3, { count = 3 }))
    assert(#damageCalls == 1, #damageCalls)
    local call = damageCalls[1]
    assert(call.id == 3 and math.type(call.id) == "integer" and call.amount == 24, "8 per blow, 3 blows: " .. tostring(call.amount))
    assert(keysOf(call.options) == "attacker,cause,pvp" and call.options.attacker == 1 and math.type(call.options.attacker) == "integer"
        and call.options.cause == "ranged" and call.options.pvp == true, "the owner is the attacker and the PvP rules are asked for")
    assert(S.stats.playerHitsApplied == applied + 1 and S.stats.playerHitsObserved == observed + 1)
    assert(#events == 0 and #sent == 0 and S.stats.actionsSent == requested, "a blow on a player publishes, sends and requests nothing")
    -- The default price of every record the controller reports.
    clear(damageCalls)
    local seq = 1
    for _, row in ipairs(PRICES) do
        for index = 3, #row do
            seq = seq + 1
            reportPlayer(1, playerHitOf(a, 3, { seq = seq, record = row[index] }))
            local last = damageCalls[#damageCalls]
            assert(last and last.amount == row[1] and last.options.cause == row[2] and last.id == 3, row[index])
            assert(X.playerDamage(row[index]) == row[1], row[index])
        end
    end
    assert(X.playerDamage("Attacks.Nothing_Like_It") == nil and X.playerDamage(5) == nil and X.playerDamage(nil) == nil)
end)

test("a blow on a player is admitted only for another living player in reach, and a refusal changes nothing and uses no sequence", function()
    local a = duel()
    local ignored, observed = S.stats.playerHitsIgnored, S.stats.playerHitsObserved
    local function refused(message, why)
        reportPlayer(1, message)
        assert(#damageCalls == 0, why .. ": damage was applied")
    end
    refused(playerHitOf(a, 1, { seq = 1 }), "the owner as the victim")
    refused(playerHitOf(a, 99, { seq = 1 }), "a player the server never saw")
    refused(playerHitOf(a, "4294967296", { seq = 1 }), "a number no player has")
    players[3].dead = true
    refused(playerHitOf(a, 3, { seq = 1 }), "a dead player")
    players[3].dead = false
    players[3].bucket = 4
    refused(playerHitOf(a, 3, { seq = 1 }), "a player in another bucket")
    players[3].bucket = 0
    assert(T.limits.playerReach == 450 and T.limits.playerHitCount == 64)
    players[3].position = { x = 450.5, y = 0, z = 0 }
    refused(playerHitOf(a, 3, { seq = 1 }), "a player beyond 450 m")
    players[3].position = { x = 300, y = 300, z = 300 }
    refused(playerHitOf(a, 3, { seq = 1 }), "a player beyond 450 m in three dimensions")
    players[3].position = nil
    refused(playerHitOf(a, 3, { seq = 1 }), "a player with no position")
    players[3].position = { x = 0, y = 0, z = 0 }
    refused(playerHitOf(a, 3, { seq = 1, record = "Attacks.Nothing_Like_It" }), "a record nothing prices")
    refused(playerHitOf(a, 3, { seq = 1, epoch = a.epoch + 1 }), "another epoch of the Titan")
    assert(S.stats.playerHitsIgnored == ignored + 10 and S.stats.playerHitsObserved == observed, "ten refusals, none observed")
    -- None of them used sequence 1: a player exactly at the reach is hit by it, and only once.
    players[3].position = { x = 0, y = 450, z = 0 }
    reportPlayer(1, playerHitOf(a, 3, { seq = 1 }))
    assert(#damageCalls == 1 and damageCalls[1].id == 3 and damageCalls[1].amount == 8, "a player exactly at the reach was refused")
    reportPlayer(1, playerHitOf(a, 3, { seq = 1 }))
    assert(#damageCalls == 1, "a repeated sequence number was applied")
    -- The reach is from the Titan's LATEST accepted pose.
    now = now + 1
    assert(publish(a, { pose = { x = 0, y = -100, z = 0, yaw = 0 } }))
    reportPlayer(1, playerHitOf(a, 3, { seq = 2 }))
    assert(#damageCalls == 1, "the Titan's old pose was used")
end)

test("a victim is the server's own read: the report's claims about where it stands change nothing", function()
    local a = duel()
    players[3].position = { x = 100, y = 0, z = 0 }
    reportPlayer(1, playerHitOf(a, 3, { count = 2, record = "Attacks.BT7274_Missile" }))
    assert(#damageCalls == 1 and damageCalls[1].amount == 70 and damageCalls[1].options.cause == "explosion")
    assert(damageCalls[1].options.attacker == 1, "the attacker is the authenticated sender, never the report's word")
end)

test("setPlayerDamage prices a record, 0 turns it off, and a bad record or amount changes nothing", function()
    local a = duel()
    assert(X.playerDamage("Attacks.BT7274_XO16_Hit") == 8)
    assert(X.setPlayerDamage("Attacks.BT7274_XO16_Hit", 0) == true and X.playerDamage("Attacks.BT7274_XO16_Hit") == 0)
    local ignored = S.stats.playerHitsIgnored
    reportPlayer(1, playerHitOf(a, 3, { seq = 1 }))
    assert(#damageCalls == 0 and S.stats.playerHitsIgnored == ignored + 1, "a record set to 0 applied something")
    assert(X.setPlayerDamage("Attacks.BT7274_XO16_Hit", 12.5) == true and X.playerDamage("Attacks.BT7274_XO16_Hit") == 12.5)
    reportPlayer(1, playerHitOf(a, 3, { seq = 1, count = 2 }))
    assert(#damageCalls == 1 and damageCalls[1].amount == 25 and damageCalls[1].options.cause == "ranged",
        "the sequence the disabled record refused was free, and the new price applies")
    -- The two edges of the amount, and a record the table does not know yet (priced under the kind 'unknown').
    assert(X.setPlayerDamage("Attacks.BT7274_XO16_Hit", 300) == true and X.playerDamage("Attacks.BT7274_XO16_Hit") == 300)
    assert(X.playerDamage("Attacks.Mission_Blow") == nil)
    assert(X.setPlayerDamage("Attacks.Mission_Blow", 20) == true)
    reportPlayer(1, playerHitOf(a, 3, { seq = 2, record = "Attacks.Mission_Blow" }))
    assert(#damageCalls == 2 and damageCalls[2].amount == 20 and damageCalls[2].options.cause == "unknown")
    for index, record in ipairs({ "", ("A"):rep(T.limits.actionRecord + 1), "has space", "x;y", 5, true, {}, HOSTILE }) do
        local ok, why = X.setPlayerDamage(record, 5)
        assert(ok == false and why == "invalid_record", "bad record #" .. index)
    end
    assert(select(2, X.setPlayerDamage(nil, 5)) == "invalid_record")
    for index, amount in ipairs({ -0.001, 300.001, 0 / 0, math.huge, -math.huge, "8", true, {}, HOSTILE }) do
        local ok, why = X.setPlayerDamage("Attacks.BT7274_XO16_Hit", amount)
        assert(ok == false and why == "invalid_amount", "bad amount #" .. index)
    end
    assert(select(2, X.setPlayerDamage("Attacks.BT7274_XO16_Hit", nil)) == "invalid_amount")
    assert(X.playerDamage("Attacks.BT7274_XO16_Hit") == 300, "a refused call changed the price")
    -- The price table is the file's own state: put back what the next tests expect.
    assert(X.setPlayerDamage("Attacks.BT7274_XO16_Hit", 8) and X.setPlayerDamage("Attacks.Mission_Blow", 0))
end)

test("a refusal of the platform is counted and logged once; a platform that raises is a refusal too, and both used their sequence", function()
    local a = duel(); S.forgetLog()
    local refused, applied = S.stats.playerHitsRefused, S.stats.playerHitsApplied
    damageRefusal = "same_team"
    local lines = printed(function()
        reportPlayer(1, playerHitOf(a, 3, { seq = 1 }))
        reportPlayer(1, playerHitOf(a, 3, { seq = 2 }))
    end)
    assert(#damageCalls == 2 and S.stats.playerHitsRefused == refused + 2 and S.stats.playerHitsApplied == applied)
    assert(countLines(lines, "[titans] player hit refused: same_team") == 1, "once per reason: " .. table.concat(lines, " | "))
    -- The platform saw those two: their numbers are used.
    reportPlayer(1, playerHitOf(a, 3, { seq = 1 }))
    assert(#damageCalls == 2, "a refused blow's sequence number was free")
    damageRefusal = nil
    local original = Open77.players.damage
    Open77.players.damage = function() error("boom", 0) end
    lines = printed(function() reportPlayer(1, playerHitOf(a, 3, { seq = 3 })) end)
    Open77.players.damage = original
    assert(S.stats.playerHitsRefused == refused + 3 and countLines(lines, "[titans] player hit refused: boom") == 1, table.concat(lines, " | "))
    reportPlayer(1, playerHitOf(a, 3, { seq = 4 }))
    assert(S.stats.playerHitsApplied == applied + 1, "the next blow is applied again")
end)

test("the source of a blow on a player is the sender's own current Titan, epoch and published frame", function()
    local a, b = duel()
    local c = spawn(3)                 -- granted: its controller has not published a frame yet
    clear(sent); clear(events)
    local function refused(player, message, why)
        reportPlayer(player, message)
        assert(#damageCalls == 0, why .. ": a blow was applied")
    end
    refused(2, playerHitOf(a, 3, { seq = 1 }), "another player's connection with A's identity")
    refused(4, playerHitOf(a, 3, { seq = 1 }), "a player with no Titan")
    refused(3, playerHitOf(c, 1, { seq = 1 }), "a granted Titan whose controller has not published")
    refused(nil, playerHitOf(a, 3, { seq = 1 }), "no sender at all")
    refused(77, playerHitOf(a, 3, { seq = 1 }), "a player the server never saw")
    refused(1, playerHitOf(a, 3, { seq = 1, id = b.id }), "B's id under A's connection")
    refused(1, playerHitOf(a, 3, { seq = 1, epoch = 2 }), "another epoch of A")
    refused(1, playerHitOf(a, 3, { seq = 1, id = "99999" }), "an id nobody holds")
    reportPlayer(1, playerHitOf(a, 3, { seq = 1 }))
    assert(#damageCalls == 1 and not b.destroyed, "none of those used sequence 1 up")
end)

test("a malformed blow on a player is refused whole, never applied, never consumes a sequence, and is reported once", function()
    local a = duel()
    local rejected = S.stats.playerHitsRejected
    local function bad(edit)
        return function()
            local message = playerHitOf(a, 3, { seq = 1 })
            edit(message)
            return message
        end
    end
    local cases = {
        bad(function(m) m.v = 1 end), bad(function(m) m.op = "vehicle_hit" end), bad(function(m) m.op = "frame" end),
        bad(function(m) m.extra = true end), bad(function(m) m.vehicle = "9" end), bad(function(m) m.share = 25 end),
        bad(function(m) m.target = { kind = "titan" } end), bad(function(m) m.point = { x = 0, y = 0, z = 0 } end),
        bad(function(m) m.id = 9 end), bad(function(m) m.id = "0" end), bad(function(m) m.epoch = 0 end),
        bad(function(m) m.epoch = 1.5 end), bad(function(m) m.seq = 0 end), bad(function(m) m.seq = 1.5 end),
        bad(function(m) m.seq = 2 ^ 53 end), bad(function(m) m.seq = nil end),
        bad(function(m) m.player = nil end), bad(function(m) m.player = 3 end), bad(function(m) m.player = "0" end),
        bad(function(m) m.player = "03" end), bad(function(m) m.player = "x" end), bad(function(m) m.player = "" end),
        bad(function(m) m.player = ("3"):rep(17) end),
        bad(function(m) m.record = nil end), bad(function(m) m.record = "" end), bad(function(m) m.record = "Attacks X" end),
        bad(function(m) m.record = ("A"):rep(T.limits.actionRecord + 1) end), bad(function(m) m.record = 5 end),
        bad(function(m) m.count = nil end), bad(function(m) m.count = 0 end), bad(function(m) m.count = -1 end),
        bad(function(m) m.count = 1.5 end), bad(function(m) m.count = T.limits.playerHitCount + 1 end),
        bad(function(m) m.count = "1" end), bad(function(m) m.count = 0 / 0 end), bad(function(m) m.count = math.huge end),
        bad(function(m) setmetatable(m, {}) end),
        function() return nil end, function() return 1 end, function() return "player_hit" end, function() return true end,
        function() return HOSTILE end, function() return {} end,
    }
    for index, make in ipairs(cases) do
        reportPlayer(1, make())
        assert(#damageCalls == 0, "case " .. index .. " was applied")
    end
    assert(S.stats.playerHitsRejected == rejected + #cases, "every one is counted as refused")
    local errors = messages(1, "error")
    assert(#errors == 1 and errors[1].reason:find("player_hit_rejected:", 1, true) == 1, "reported once, with the schema's own token")
    assert(T.normalizeServerMessage(errors[1], Open77TitanCatalog), "the controller's validator accepts the report")
    -- The edges are fine, and no malformed case used sequence 1 up.
    reportPlayer(1, playerHitOf(a, 3, { seq = 1, count = T.limits.playerHitCount }))
    assert(#damageCalls == 1 and damageCalls[1].amount == 8 * T.limits.playerHitCount)
    reportPlayer(1, playerHitOf(a, 3, { seq = 2, count = 1, record = "Attacks.BT7274_Rail_1" }))
    assert(#damageCalls == 2 and damageCalls[2].amount == 25)
end)

test("the schema's refusal tokens come in the order the controller's twin expects", function()
    local a = duel()
    local function token(edit)
        local message = playerHitOf(a, 3, { seq = 1 })
        edit(message)
        return select(2, T.normalizePlayerHit(message))
    end
    assert(T.normalizePlayerHit(playerHitOf(a, 3, { seq = 1 })), "a good one passes")
    assert(token(function(m) m.extra = 1 end) == "observed_keys")
    assert(token(function(m) m.op = "vehicle_hit" end) == "observed_op")
    assert(token(function(m) m.id = "x" end) == "observed_source" and token(function(m) m.epoch = 0 end) == "observed_source")
    assert(token(function(m) m.seq = 0 end) == "observed_seq")
    assert(token(function(m) m.player = "x" end) == "player_id")
    assert(token(function(m) m.record = "a b" end) == "hit_record")
    assert(token(function(m) m.count = 65 end) == "player_count")
    -- Several faults at once: the first in that order.
    assert(token(function(m) m.count, m.record, m.player = 0, "", "x" end) == "player_id")
    assert(token(function(m) m.seq, m.id = 0, "x" end) == "observed_source")
    -- A copy comes back: the caller's table is never the result.
    local raw = playerHitOf(a, 3, { seq = 7, count = 2.0 })
    local clean = T.normalizePlayerHit(raw)
    assert(clean ~= raw and keysOf(clean) == "count,epoch,id,op,player,record,seq,v" and math.type(clean.count) == "integer")
end)

test("blows on players spend the observations' one budget and one sequence window", function()
    local a, b = duel(); cars()
    local limits = T.limits
    reportCar(1, vehicleHitOf(a, 9))
    reportPlayer(1, playerHitOf(a, 3, { seq = 1 }))
    assert(#vehicleHits() == 1 and #damageCalls == 0, "a number a car used was taken again by a player")
    reportPlayer(1, playerHitOf(a, 3, { seq = 2 }))
    reportCar(1, vehicleHitOf(a, 9, { seq = 2 }))
    observe(1, observedOf(a, b, { seq = 2 }))
    assert(#damageCalls == 1 and #vehicleHits() == 1 and #observations() == 0, "a number a player used was taken again")
    -- Reports of one tick arrive newest-first: all are taken, then none twice.
    clear(damageCalls)
    for seq = 12, 10, -1 do reportPlayer(1, playerHitOf(a, 3, { seq = seq })) end
    for _, seq in ipairs({ 10, 11, 12 }) do reportPlayer(1, playerHitOf(a, 3, { seq = seq })) end
    assert(#damageCalls == 3)
    -- One bucket: effects and blows on players draw on the same tokens, at one instant exactly the burst.
    now = now + 2
    clear(damageCalls)
    local ignored = S.stats.playerHitsIgnored
    local carried, results = a.carryMessages.tokens, a.results.tokens
    for seq = 1000, 1099 do fire(T.event.status, 1, statusOf(a, b, { seq = seq })) end
    for seq = 1100, 1149 do fire(T.event.player, 1, playerHitOf(a, 3, { seq = seq })) end
    assert(#damageCalls == limits.eventBurst - 100 and S.stats.playerHitsIgnored == ignored + (150 - limits.eventBurst),
        "the two kinds did not share one bucket")
    assert(a.carryMessages.tokens == carried and a.results.tokens == results, "a blow on a player spent another budget")
end)

test("a blow on a player is no door to anything else, and no other door carries one", function()
    local a, b = duel(); cars(); clear(coreCalls)
    local requested = S.stats.actionsSent
    -- The player event takes only the player blow: the other client messages are refused there.
    reportPlayer(1, observedOf(a, b))
    reportPlayer(1, statusOf(a, b))
    reportPlayer(1, vehicleHitOf(a, 9))
    reportPlayer(1, { v = T.protocol, op = "carry_request", id = a.id, epoch = a.epoch, request = 1, kind = "vehicle", entityId = "9" })
    reportPlayer(1, { v = T.protocol, op = "frame" })
    assert(#damageCalls == 0 and #observations() == 0 and #statuses() == 0 and #vehicleHits() == 0 and #coreCalls == 0)
    -- And a blow on a player sent on any other event is that event's refusal, never an applied one.
    local before = S.stats.framesRejected
    for _, name in ipairs({ T.event.frame, T.event.result, T.event.carry, T.event.request, T.event.hit, T.event.status,
        T.event.vehicle }) do
        fire(name, 1, playerHitOf(a, 3, { seq = 99 }))
    end
    runTimers()
    hostTick()
    assert(#damageCalls == 0 and S.stats.framesRejected > before, "another event took a blow on a player")
    -- No export carries one: a script prices a record, and only the owner's controller reports a blow.
    assert(X.playerHit == nil and X.damagePlayer == nil and X.setPlayerDamage ~= nil and X.playerDamage ~= nil)
    assert(S.stats.actionsSent == requested and T.event.player == "op77_lightrp:titans:player")
end)

-- ---------------------------------------------------------------------------
-- Blows on NPCs: the owner's report that its Titan's weapons landed on an NPC the platform owns (npc_hit on its own event: the
-- NPC's platform id, the attack record, the kind of blow and where it landed). The server neither owns nor reads the NPC: it
-- authenticates the sender against its own live Titan, spends the observations' one budget and sequence, spaces rounds on one NPC
-- and publishes onTitanNpcHit with the Titan's own pose for the mission that owns the NPC to validate and price.
-- ---------------------------------------------------------------------------
local function npcHitOf(source, npc, extra)
    observedSeqOf[source] = (observedSeqOf[source] or 0) + 1
    return merge({
        v = T.protocol, op = "npc_hit", id = source.id, epoch = source.epoch, seq = observedSeqOf[source],
        npc = tostring(npc), record = "Attacks.BT7274_Punch", kind = "melee", point = { x = 3, y = 4, z = 5 },
    }, extra)
end
local function reportNpc(player, message)
    now = now + 0.01
    fire(T.event.npc, player, message)
end
local function npcHits() return eventsNamed("onTitanNpcHit") end
-- Only a Titan its owner pilots reports blows a mission may price: the NPC tests fly piloted Titans.
local function piloting(...)
    for _, t in ipairs({ ... }) do assert(publish(t, { mode = "pilot" })) end
end

test("a blow on an NPC is published once as onTitanNpcHit with the Titan's own pose, and the server touches nothing", function()
    local a = duel(); clear(coreCalls); clear(damageCalls)
    now = now + 1
    assert(publish(a, { pose = { x = 10, y = 20, z = 30, yaw = 90 }, mode = "pilot" }))
    clear(events)
    clear(sent)
    local observed, requested, forbiddenBefore = S.stats.npcHitsObserved, S.stats.actionsSent, forbidden
    -- Whatever the platform's NPC registry is asked, this test would fail: the report is never checked against the NPC.
    local registry = Open77.npcs
    Open77.npcs = setmetatable({}, { __index = function() error("the NPC was read") end })
    local raw = npcHitOf(a, 77, { record = "Attacks.BT7274_Sword", kind = "blade", point = { x = 1.5, y = 2.5, z = 3.5 } })
    reportNpc(1, raw)
    Open77.npcs = registry
    local list = npcHits()
    assert(#list == 1 and #events == 1, "exactly one host event, and nothing else was raised")
    local args = list[1]
    assert(args.n == 4 and args[1] == 1 and math.type(args[1]) == "integer" and args[2] == a.id and args[3] == "77"
        and type(args[2]) == "string" and type(args[3]) == "string" and type(args[4]) == "table")
    local info = args[4]
    assert(keysOf(info) == "at,kind,point,record,titan", keysOf(info))
    assert(info.record == "Attacks.BT7274_Sword" and info.kind == "blade" and info.at == now
        and info.point.x == 1.5 and info.point.y == 2.5 and info.point.z == 3.5 and keysOf(info.point) == "x,y,z")
    assert(info.titan.x == 10 and info.titan.y == 20 and info.titan.z == 30 and keysOf(info.titan) == "x,y,z",
        "the Titan's own latest accepted pose, never a field of the report")
    -- Detached: no table is shared with the sender's message or the Titan's record.
    assert(info.point ~= raw.point and info.titan ~= a.pose)
    raw.point.x, raw.record = 99, "other"
    info.titan.x, info.point.y = -1, -1
    assert(info.record == "Attacks.BT7274_Sword" and a.pose.x == 10)
    -- A record name is data: it never chooses what the server raises, and an unknown record is fine (the mission prices by kind).
    reportNpc(1, npcHitOf(a, 78, { record = "onTitanRemoved" }))
    reportNpc(1, npcHitOf(a, 79, { record = "Attacks.Mission_Blow", kind = "other" }))
    assert(#npcHits() == 3 and #events == 3)
    for _, event in ipairs(events) do assert(event.name == "onTitanNpcHit", event.name) end
    assert(npcHits()[2][3] == "78" and npcHits()[3][4].kind == "other")
    assert(#sent == 0, "a blow on an NPC caused a message to a client")
    -- The latest pose is the one the next report carries.
    now = now + 1
    assert(publish(a, { pose = { x = 15, y = 25, z = 35, yaw = 0 }, mode = "pilot" }))
    reportNpc(1, npcHitOf(a, 77))
    local latest = npcHits()[4][4].titan
    assert(latest.x == 15 and latest.y == 25 and latest.z == 35, "the Titan's latest pose")
    -- Nothing was applied, sent, requested or read: the server is only the messenger.
    assert(#damageCalls == 0 and #coreCalls == 0 and forbidden == forbiddenBefore and S.stats.actionsSent == requested,
        "a blow on an NPC caused a request or a platform call")
    assert(S.stats.npcHitsObserved == observed + 4 and a.pendingCount == 0 and not a.destroyed)
end)

test("a blow on an NPC takes only the sender's own current Titan, epoch and published frame, and a new sequence number", function()
    local a, b = duel()
    piloting(a, b)
    local c = spawn(3)                 -- granted: its controller has not published a frame yet
    clear(sent); clear(events)
    local function refused(player, message, why)
        reportNpc(player, message)
        assert(#npcHits() == 0, why .. ": a blow was published")
    end
    refused(2, npcHitOf(a, 77, { seq = 1 }), "another player's connection with A's identity")
    refused(4, npcHitOf(a, 77, { seq = 1 }), "a player with no Titan")
    refused(3, npcHitOf(c, 77, { seq = 1 }), "a granted Titan whose controller has not published")
    refused(nil, npcHitOf(a, 77, { seq = 1 }), "no sender at all")
    refused(77, npcHitOf(a, 77, { seq = 1 }), "a player the server never saw")
    refused(1, npcHitOf(a, 77, { seq = 1, id = b.id }), "B's id under A's connection")
    refused(1, npcHitOf(a, 77, { seq = 1, epoch = 2 }), "another epoch of A")
    refused(1, npcHitOf(a, 77, { seq = 1, id = "99999" }), "an id nobody holds")
    local ignored = S.stats.npcHitsIgnored
    -- None of them used sequence 1 up: it is taken once.
    reportNpc(1, npcHitOf(a, 77, { seq = 1 }))
    assert(#npcHits() == 1)
    reportNpc(1, npcHitOf(a, 77, { seq = 1 }))
    reportNpc(1, npcHitOf(a, 78, { seq = 1 }))
    assert(#npcHits() == 1 and S.stats.npcHitsIgnored == ignored + 2, "a repeated sequence number was published")
    -- Reports of one tick arrive newest-first: all are taken, then none twice, inside the bounded window.
    for seq = 12, 10, -1 do reportNpc(1, npcHitOf(a, 77, { seq = seq })) end
    for _, seq in ipairs({ 10, 11, 12 }) do reportNpc(1, npcHitOf(a, 77, { seq = seq })) end
    assert(#npcHits() == 4)
    reportNpc(1, npcHitOf(a, 77, { seq = 2000 }))
    reportNpc(1, npcHitOf(a, 77, { seq = 2000 - T.limits.hitWindow }))
    assert(#npcHits() == 5, "a number older than the window was published")
    -- A removed Titan reports nothing, and one that is removed and spawned again is a new identity.
    local old = a
    S.removeTitan(a, "owner_removed")
    clear(events)
    reportNpc(1, npcHitOf(old, 77, { seq = 3000 }))
    assert(#npcHits() == 0, "a blow of a Titan that is gone")
    local fresh = spawn(1)
    now = now + 2
    assert(publish(fresh, { mode = "pilot" }))
    reportNpc(1, npcHitOf(old, 77, { seq = 3001 }))
    assert(#npcHits() == 0, "the old Titan's identity under the new Titan")
    reportNpc(1, npcHitOf(fresh, 77))
    assert(#npcHits() == 1, "the new Titan's own blow")
end)

test("only a Titan its owner pilots, and not held, reports a blow on an NPC a mission may price", function()
    local a = duel()
    clear(events)
    local ignored = S.stats.npcHitsIgnored
    reportNpc(1, npcHitOf(a, 77))
    assert(#npcHits() == 0 and S.stats.npcHitsIgnored == ignored + 1, "a Titan whose frames do not say pilot")
    piloting(a)
    a.held = true
    reportNpc(1, npcHitOf(a, 78))
    assert(#npcHits() == 0 and S.stats.npcHitsIgnored == ignored + 2, "a held Titan")
    a.held = false
    reportNpc(1, npcHitOf(a, 79))
    assert(#npcHits() == 1, "piloted and free")
end)

test("a malformed blow on an NPC is refused whole, never published, never consumes a sequence, and is reported once", function()
    local a = duel()
    piloting(a)
    local rejected = S.stats.npcHitsRejected
    local limit = T.limits.coordinate
    local function bad(edit)
        return function()
            local message = npcHitOf(a, 77, { seq = 1 })
            edit(message)
            return message
        end
    end
    local cases = {
        bad(function(m) m.v = 1 end), bad(function(m) m.op = "player_hit" end), bad(function(m) m.op = "frame" end),
        bad(function(m) m.extra = true end), bad(function(m) m.player = "3" end), bad(function(m) m.count = 1 end),
        bad(function(m) m.vehicle = "9" end), bad(function(m) m.target = { kind = "titan" } end),
        bad(function(m) m.id = 9 end), bad(function(m) m.id = "0" end), bad(function(m) m.epoch = 0 end),
        bad(function(m) m.epoch = 1.5 end), bad(function(m) m.seq = 0 end), bad(function(m) m.seq = 1.5 end),
        bad(function(m) m.seq = 2 ^ 53 end), bad(function(m) m.seq = nil end),
        bad(function(m) m.npc = nil end), bad(function(m) m.npc = 77 end), bad(function(m) m.npc = "0" end),
        bad(function(m) m.npc = "077" end), bad(function(m) m.npc = "x" end), bad(function(m) m.npc = "" end),
        bad(function(m) m.npc = "7.5" end), bad(function(m) m.npc = ("7"):rep(17) end), bad(function(m) m.npc = true end),
        bad(function(m) m.record = nil end), bad(function(m) m.record = "" end), bad(function(m) m.record = "Attacks X" end),
        bad(function(m) m.record = ("A"):rep(T.limits.actionRecord + 1) end), bad(function(m) m.record = 5 end),
        bad(function(m) m.kind = nil end), bad(function(m) m.kind = "ranged" end), bad(function(m) m.kind = "ROUND" end),
        bad(function(m) m.kind = "melee " end), bad(function(m) m.kind = "" end), bad(function(m) m.kind = 5 end),
        bad(function(m) m.kind = {} end), bad(function(m) m.kind = true end),
        bad(function(m) m.point = nil end), bad(function(m) m.point = {} end), bad(function(m) m.point = { x = 1, y = 2 } end),
        bad(function(m) m.point = { x = 1, y = 2, z = 3, w = 4 } end), bad(function(m) m.point = { x = 0 / 0, y = 0, z = 0 } end),
        bad(function(m) m.point = { x = math.huge, y = 0, z = 0 } end), bad(function(m) m.point = { x = limit + 1, y = 0, z = 0 } end),
        bad(function(m) m.point = { x = 0, y = -limit - 1, z = 0 } end), bad(function(m) m.point = { x = "1", y = 2, z = 3 } end),
        bad(function(m) m.point = 5 end), bad(function(m) m.point = setmetatable({ x = 1, y = 2, z = 3 }, {}) end),
        bad(function(m) setmetatable(m, {}) end),
        function() return nil end, function() return 1 end, function() return "npc_hit" end, function() return true end,
        function() return HOSTILE end, function() return {} end,
    }
    for index, make in ipairs(cases) do
        reportNpc(1, make())
        assert(#npcHits() == 0, "case " .. index .. " was published")
    end
    assert(S.stats.npcHitsRejected == rejected + #cases, "every one is counted as refused")
    local errors = messages(1, "error")
    assert(#errors == 1 and errors[1].reason:find("npc_hit_rejected:", 1, true) == 1, "reported once, with the schema's own token")
    assert(T.normalizeServerMessage(errors[1], Open77TitanCatalog), "the controller's validator accepts the report")
    -- The edges are fine, and no malformed case used sequence 1 up.
    for index, kind in ipairs({ "round", "blast", "melee", "blade", "other" }) do
        reportNpc(1, npcHitOf(a, 1000 + index, { seq = index, kind = kind, point = { x = limit, y = -limit, z = 0 } }))
    end
    assert(#npcHits() == 5, "every kind of the closed set and the largest point")
    reportNpc(1, npcHitOf(a, ("9"):rep(16), { seq = 6 }))
    assert(#npcHits() == 6 and npcHits()[6][3] == ("9"):rep(16), "the longest id")
end)

test("the NPC schema's refusal tokens come in the order the controller's twin expects, and a copy comes back", function()
    local a = duel()
    piloting(a)
    local function token(edit)
        local message = npcHitOf(a, 77, { seq = 1 })
        edit(message)
        return select(2, T.normalizeNpcHit(message))
    end
    assert(T.normalizeNpcHit(npcHitOf(a, 77, { seq = 1 })), "a good one passes")
    assert(token(function(m) m.extra = 1 end) == "observed_keys")
    assert(token(function(m) m.op = "player_hit" end) == "observed_op")
    assert(token(function(m) m.id = "x" end) == "observed_source" and token(function(m) m.epoch = 0 end) == "observed_source")
    assert(token(function(m) m.seq = 0 end) == "observed_seq")
    assert(token(function(m) m.npc = "x" end) == "npc_id")
    assert(token(function(m) m.record = "a b" end) == "hit_record")
    assert(token(function(m) m.kind = "laser" end) == "npc_kind")
    assert(token(function(m) m.point = {} end) == "hit_point")
    -- Several faults at once: the first in that order.
    assert(token(function(m) m.point, m.kind, m.record, m.npc = {}, "x", "", "x" end) == "npc_id")
    assert(token(function(m) m.point, m.kind, m.record = {}, "x", "" end) == "hit_record")
    assert(token(function(m) m.point, m.kind = {}, "x" end) == "npc_kind")
    assert(token(function(m) m.seq, m.id = 0, "x" end) == "observed_source")
    local raw = npcHitOf(a, 77, { seq = 7 })
    local clean = T.normalizeNpcHit(raw)
    assert(clean ~= raw and clean.point ~= raw.point and keysOf(clean) == "epoch,id,kind,npc,op,point,record,seq,v")
    assert(clean.npc == "77" and clean.kind == "melee" and clean.seq == 7 and keysOf(clean.point) == "x,y,z")
    -- The closed set of kinds, and the twin the controller validates with
    assert(keysOf(T.npcKinds) == "blade,blast,melee,other,round")
end)

test("a round on one NPC is at most one per gap (1/60 s) on average: its own bucket per NPC, kinds other than a round have none", function()
    local a, b = duel(); piloting(a, b); clear(events)
    local limits = T.limits
    assert(limits.npcRoundGap == 1 / 60 and limits.npcRoundBurst == 2 and limits.npcRoundKeys == 128)
    now = now + 5
    -- At one instant exactly the burst passes.
    local rejected = S.stats.npcHitsIgnored
    for _ = 1, 10 do fire(T.event.npc, 1, npcHitOf(a, 5, { kind = "round" })) end
    assert(#npcHits() == limits.npcRoundBurst and S.stats.npcHitsIgnored == rejected + 8, "the burst of a bucket, then none")
    -- Another NPC has its own bucket, and so does another Titan.
    fire(T.event.npc, 1, npcHitOf(a, 6, { kind = "round" }))
    fire(T.event.npc, 2, npcHitOf(b, 5, { kind = "round" }))
    assert(#npcHits() == limits.npcRoundBurst + 2, "a bucket per NPC and per Titan")
    -- A round refused by the bucket used no sequence number: the same blow goes through once the bucket has refilled.
    local again = npcHitOf(a, 5, { kind = "round" })
    fire(T.event.npc, 1, again)
    local count = #npcHits()
    now = now + 1
    fire(T.event.npc, 1, again)
    assert(#npcHits() == count + 1, "a refused round's sequence number was used up")
    fire(T.event.npc, 1, again)
    assert(#npcHits() == count + 1, "and a taken one is taken once")
    -- Sustained: a round every 10 ms for a second is the bucket's rate (60 a second) plus its burst, not 100.
    now = now + 5
    clear(events)
    for _ = 1, 100 do
        now = now + 0.01
        fire(T.event.npc, 1, npcHitOf(a, 5, { kind = "round" }))
    end
    local taken = #npcHits()
    assert(taken >= 59 and taken <= 60 + limits.npcRoundBurst, "a second of rounds on one NPC: " .. taken)
    -- Spaced by the gap every round goes through, and at 0.8 of it only a part.
    now = now + 5
    clear(events)
    for _ = 1, 40 do
        now = now + limits.npcRoundGap
        fire(T.event.npc, 1, npcHitOf(a, 5, { kind = "round" }))
    end
    assert(#npcHits() == 40, "rounds spaced by the controller's own gap are all taken: " .. #npcHits())
    now = now + 5
    clear(events)
    for _ = 1, 100 do
        now = now + limits.npcRoundGap * 0.8
        fire(T.event.npc, 1, npcHitOf(a, 5, { kind = "round" }))
    end
    taken = #npcHits()
    assert(taken >= 78 and taken <= 80 + limits.npcRoundBurst + 1, "rounds at 0.8 of the gap are one per gap at most: " .. taken)
    -- Every other kind is its own blow: thirty at one instant on one NPC are all published.
    now = now + 5
    clear(events)
    for _, kind in ipairs({ "blast", "melee", "blade", "other" }) do
        for _ = 1, 7 do fire(T.event.npc, 1, npcHitOf(a, 5, { kind = kind })) end
    end
    assert(#npcHits() == 28, "a blast, a fist, a blade and the rest have no bucket: " .. #npcHits())
end)

test("the round buckets are bounded: a full table forgets the refilled ones and refuses a new NPC otherwise", function()
    local a = duel(); piloting(a); clear(events)
    local limits = T.limits
    now = now + 10
    -- npcRoundKeys distinct NPCs inside less than the time a bucket needs to refill: all taken, the next one refused.
    local step = limits.npcRoundBurst * limits.npcRoundGap * 0.9 / limits.npcRoundKeys
    for npc = 1, limits.npcRoundKeys do
        now = now + step
        fire(T.event.npc, 1, npcHitOf(a, npc, { kind = "round" }))
    end
    assert(#npcHits() == limits.npcRoundKeys and a.npcRoundN == limits.npcRoundKeys, "a bucket per NPC up to the bound")
    now = now + step
    local over = npcHitOf(a, limits.npcRoundKeys + 1, { kind = "round" })
    fire(T.event.npc, 1, over)
    assert(#npcHits() == limits.npcRoundKeys and a.npcRoundN == limits.npcRoundKeys, "a new NPC with the table full of live buckets")
    -- A bucket that has refilled is forgotten to make room: the same report is taken now.
    now = now + 1
    fire(T.event.npc, 1, over)
    assert(#npcHits() == limits.npcRoundKeys + 1 and a.npcRoundN <= limits.npcRoundKeys, "the table never outgrows its bound")
    local held = 0
    for _ in pairs(a.npcRounds) do held = held + 1 end
    assert(held == a.npcRoundN, "the count is the table's size")
    -- Blows of other kinds make no bucket at all.
    local before = a.npcRoundN
    for npc = 500, 520 do fire(T.event.npc, 1, npcHitOf(a, npc, { kind = "blast" })) end
    assert(a.npcRoundN == before, "only rounds hold a bucket")
    -- A Titan's buckets end with it.
    local old = a.npcRounds
    S.removeTitan(a, "owner_removed")
    local fresh = spawn(1)
    assert(fresh.npcRounds ~= old and next(fresh.npcRounds) == nil and fresh.npcRoundN == 0)
end)

test("blows on NPCs spend the observations' one budget and one sequence window", function()
    local a, b = duel(); cars(); piloting(a, b)
    local limits = T.limits
    reportCar(1, vehicleHitOf(a, 9))
    reportNpc(1, npcHitOf(a, 77, { seq = 1 }))
    assert(#vehicleHits() == 1 and #npcHits() == 0, "a number a car used was taken again by an NPC")
    reportNpc(1, npcHitOf(a, 77, { seq = 2 }))
    reportCar(1, vehicleHitOf(a, 9, { seq = 2 }))
    reportPlayer(1, playerHitOf(a, 3, { seq = 2 }))
    observe(1, observedOf(a, b, { seq = 2 }))
    assert(#npcHits() == 1 and #vehicleHits() == 1 and #damageCalls == 0 and #observations() == 0, "a number an NPC used was taken again")
    -- One bucket: effects and blows on NPCs draw on the same tokens, at one instant exactly the burst.
    now = now + 2
    clear(events)
    local ignored = S.stats.npcHitsIgnored
    local carried, results = a.carryMessages.tokens, a.results.tokens
    for seq = 1000, 1099 do fire(T.event.status, 1, statusOf(a, b, { seq = seq })) end
    for seq = 1100, 1149 do fire(T.event.npc, 1, npcHitOf(a, 77, { seq = seq })) end
    assert(#npcHits() == limits.eventBurst - 100 and S.stats.npcHitsIgnored == ignored + (150 - limits.eventBurst),
        "the two kinds did not share one bucket")
    assert(a.carryMessages.tokens == carried and a.results.tokens == results, "a blow on an NPC spent another budget")
end)

test("a blow on an NPC is no door to anything else, and no other door carries one", function()
    local a, b = duel(); cars(); piloting(a, b); clear(coreCalls)
    local requested = S.stats.actionsSent
    -- The NPC event takes only the NPC blow: the other client messages are refused there.
    reportNpc(1, observedOf(a, b))
    reportNpc(1, statusOf(a, b))
    reportNpc(1, vehicleHitOf(a, 9))
    reportNpc(1, playerHitOf(a, 3))
    reportNpc(1, { v = T.protocol, op = "carry_request", id = a.id, epoch = a.epoch, request = 1, kind = "npc", entityId = "9" })
    reportNpc(1, { v = T.protocol, op = "frame" })
    assert(#npcHits() == 0 and #damageCalls == 0 and #observations() == 0 and #statuses() == 0 and #vehicleHits() == 0 and #coreCalls == 0)
    -- And a blow on an NPC sent on any other event is that event's refusal, never a published one.
    local before = S.stats.framesRejected
    for _, name in ipairs({ T.event.frame, T.event.result, T.event.carry, T.event.request, T.event.hit, T.event.status,
        T.event.vehicle, T.event.player }) do
        fire(name, 1, npcHitOf(a, 77, { seq = 99 }))
    end
    runTimers()
    hostTick()
    assert(#npcHits() == 0 and #damageCalls == 0 and S.stats.framesRejected > before, "another event took a blow on an NPC")
    -- No export carries one, and no export or event hurts an NPC: the report is a message and nothing else.
    assert(X.npcHit == nil and X.hitNpc == nil and X.damageNpc == nil and X.setNpcDamage == nil and X.hit ~= nil)
    assert(S.stats.actionsSent == requested and T.event.npc == "op77_lightrp:titans:npc")
    assert(T.event.npc ~= T.event.player and T.event.npc ~= T.event.vehicle and T.event.npc ~= T.event.hit and T.event.npc ~= T.event.status)
end)

-- ---------------------------------------------------------------------------
-- A scripted death (freeroam's teleport) is not the owner going down while BT stands outside.
-- ---------------------------------------------------------------------------
test("a scripted death keeps an unpiloted Titan and releases a piloted one; any other death releases both", function()
    local script = { phase = "dead", cause = "script", weapon = "freeroam:teleport" }
    local function die(life)
        players[1].dead = true
        lifeStates[1] = life
        fire("onPlayerLifeStateChanged", nil, "1", "9", life and life.phase or "dead", life and life.weapon or "x")
    end
    -- Outside BT: the teleport leaves it standing, through the event and through the upkeep, and the owner's return too.
    reset(); ready(1)
    local titan = spawn(1)
    assert(publish(titan, { mode = "wait" }))
    die(script)
    assert(S.titans[1] == titan, "a teleport released an unpiloted Titan")
    S.tick()
    assert(S.titans[1] == titan, "the upkeep released it")
    lifeStates[1] = { phase = "respawnpending", cause = "script", weapon = "freeroam:teleport" }
    fire("onPlayerLifeStateChanged", nil, "1", "9", "respawnpending", "x")
    S.tick()
    assert(S.titans[1] == titan, "the respawn in flight released it")
    players[1].dead, lifeStates[1] = false, nil
    fire("onPlayerLifeStateChanged", nil, "1", "9", "recovering", "x")
    fire("onPlayerLifeStateChanged", nil, "1", "9", "alive", "x")
    S.tick()
    assert(S.titans[1] == titan and #eventsNamed("onTitanRemoved") == 0)

    -- Inside BT the pilot leaves the cockpit with the scripted death: the Titan goes, by event and by upkeep alike.
    titan = liveWithViewer()
    die(script)
    released(titan, "owner_dead")
    titan = liveWithViewer()
    players[1].dead, lifeStates[1] = true, script
    S.tick()
    released(titan, "owner_dead")

    -- Any other death ends an unpiloted Titan as it always did.
    for _, life in ipairs({ { phase = "dead", cause = "ranged", weapon = "x" }, { phase = "dead", cause = "environment" }, false }) do
        reset(); ready(1)
        titan = spawn(1)
        assert(publish(titan, { mode = "wait" }))
        die(life or nil)
        assert(S.titans[1] == nil and messages(1, "remove")[1].reason == "owner_dead", tostring(life and life.cause))
    end
    -- The same without the event: the upkeep reads the platform's own answer.
    reset(); ready(1)
    titan = spawn(1)
    assert(publish(titan, { mode = "wait" }))
    players[1].dead, lifeStates[1] = true, { phase = "dead", cause = "melee" }
    S.tick()
    assert(S.titans[1] == nil)
end)

-- ---------------------------------------------------------------------------
-- A car blast flings a body; the pilot is parked inside BT, so open77_weapons is told to leave it alone while piloting.
-- ---------------------------------------------------------------------------
test("the pilot is exempt from blast launches exactly while piloting, and every exit lifts it", function()
    reset(); ready(1)
    local titan = spawn(1)
    clear(exportCalls)
    local function last()
        local call = exportCalls[#exportCalls]
        return call and call.target, call and call.name, call and call.args[1], call and call.args[2], call and call.args.n
    end
    assert(publish(titan, { mode = "wait" }))
    local target, name, player, exempt, n = last()
    assert(#exportCalls == 1 and target == "open77_weapons" and name == "setLaunchExempt" and player == 1 and exempt == false and n == 2)
    assert(math.type(player) == "integer", "the platform takes an integer player")
    assert(publish(titan, { mode = "wait" }) and #exportCalls == 1, "a frame that changes no mode asks nothing")
    assert(publish(titan, { mode = "pilot" }) and #exportCalls == 2)
    target, name, player, exempt = last()
    assert(target == "open77_weapons" and name == "setLaunchExempt" and player == 1 and exempt == true, "piloting exempts")
    assert(publish(titan, { mode = "pilot" }) and #exportCalls == 2)
    assert(publish(titan, { mode = "wait" }) and #exportCalls == 3 and select(4, last()) == false, "getting out lifts it")
    assert(publish(titan, { mode = "pilot" }) and #exportCalls == 4 and select(4, last()) == true)
    S.removeTitan(titan, "owner_removed")
    assert(#exportCalls == 5 and select(4, last()) == false and select(3, last()) == 1, "every exit lifts it")
    -- The owner's death, a disconnect and the resource's own stop are exits too.
    for _, exit in ipairs({
        function() players[1].dead = true; fire("onPlayerLifeStateChanged", nil, "1", "9", "dead", "x") end,
        function() fire("onPlayerDisconnected", nil, "1", "connection_closed") end,
        function() fire("onResourceStop", nil, "op77_lightrp_titans") end,
    }) do
        local piloted = liveWithViewer()
        clear(exportCalls)
        exit()
        assert(S.titans[1] == nil and select(4, last()) == false and select(3, last()) == 1)
        assert(piloted.owner == 1)
    end
end)

test("a launch exemption the weapons resource cannot take is logged once and changes nothing else", function()
    reset(); ready(1); ready(2)
    S.forgetLog()
    local titan = spawn(1)
    exportFailure = "export open77_weapons:setLaunchExempt export_resource_unavailable"
    local lines = printed(function()
        assert(publish(titan, { mode = "pilot" }), "the frame is still accepted")
        assert(publish(titan, { mode = "wait" }))
        assert(publish(titan, { mode = "pilot" }))
    end)
    assert(titan.mode == "pilot" and S.hides[1] and S.hides[1].want == true, "piloting still hides V")
    local text = "[titans] launch exemption failed: " .. exportFailure
    assert(countLines(lines, text) == 1, "once per run: " .. table.concat(lines, " | "))
    -- A refusal that does not raise is reported by its reason.
    exportFailure = nil
    local original = Open77.exports.callSync
    Open77.exports.callSync = function() return false, "invalid_player" end
    S.forgetLog()
    lines = printed(function() assert(publish(titan, { mode = "wait" })) end)
    Open77.exports.callSync = original
    assert(countLines(lines, "[titans] launch exemption failed: invalid_player") == 1, table.concat(lines, " | "))
    -- Without any Open77.exports at all the frame is still taken.
    local exportsApi = Open77.exports
    Open77.exports = nil
    assert(publish(titan, { mode = "pilot" }))
    Open77.exports = exportsApi
end)

-- ---------------------------------------------------------------------------
-- Failures are visible: /titan log, the counters of /titan status, and the log's one line per ignored blow.
-- ---------------------------------------------------------------------------
test("/titan log on and off reach the caller's controller, need no Titan, and are answered", function()
    reset(); ready(1); ready(2)
    clear(sent)
    command(1, "log", "on")
    local sentCommand = messages(1, "command")[1]
    assert(sentCommand and sentCommand.action == "log" and sentCommand.value == "on" and keysOf(sentCommand) == "action,op,v,value")
    assert(sentCommand.v == T.protocol and sentCommand.op == "command")
    assert(T.normalizeServerMessage(sentCommand, Open77TitanCatalog), "the controller's validator accepts it")
    assert(lastReply(1)[2] == true and lastReply(1)[3] == "[titan] controller log on", lastReply(1)[3])
    assert(#messages(2) == 0 and S.titans[1] == nil, "only the caller is told, and no Titan is made")
    clear(sent)
    command(1, "LOG", "OFF")
    assert(messages(1, "command")[1].value == "off" and lastReply(1)[3] == "[titan] controller log off")
    -- A bridge-less client has no controller to switch.
    reset(); ready(1, false)
    clear(sent)
    command(1, "log", "on")
    assert(#messages(1, "command") == 0 and lastReply(1)[2] == false)
    -- Only on and off, and nothing else carries the word.
    local verb, usage = T.parseCommand(table.pack("log", "maybe"))
    assert(verb == nil and usage == T.usage and T.usage:find("log <on|off>", 1, true))
    assert(T.parseCommand(table.pack("log")) == nil and T.parseCommand(table.pack("log", "on", "now")) == nil)
    assert(select(2, X.command(1, "log", "on")) == "invalid_command", "a script cannot switch a player's log")
    assert(T.normalizeServerMessage({ v = T.protocol, op = "command", action = "log", value = "loud" }, Open77TitanCatalog) == nil)
    assert(T.normalizeServerMessage({ v = T.protocol, op = "command", action = "log" }, Open77TitanCatalog) == nil)
    assert(T.normalizeServerMessage({ v = T.protocol, op = "command", action = "pilot", value = "on" }, Open77TitanCatalog) == nil)
    -- It spends the player's /titan budget like every command.
    reset(); ready(1)
    clear(sent)
    for _ = 1, T.limits.commandBurst do command(1, "log", "on") end
    assert(#messages(1, "command") == T.limits.commandBurst)
    command(1, "log", "on")
    assert(#messages(1, "command") == T.limits.commandBurst and lastReply(1)[2] == false, "an eighth command inside the burst")
end)

test("/titan status ends in every counter of the reports the server acts on, with or without a Titan", function()
    local suffix = " cars applied=%d+ ignored=%d+ vetoed=%d+ failed=%d+ players applied=%d+ refused=%d+ ignored=%d+"
        .. " npcs observed=%d+ ignored=%d+ carry requested=%d+ granted=%d+ denied=%d+ rejected=%d+$"
    reset(); ready(1)
    command(1, "status")
    local text = lastReply(1)[3]
    assert(text:find("^%[titan%] no Titan" .. suffix), text)
    assert(text:find("players applied=", 1, true))
    local a = duel(); cars()
    reportPlayer(1, playerHitOf(a, 3))
    damageRefusal = "same_team"
    reportPlayer(1, playerHitOf(a, 3))
    reportPlayer(1, playerHitOf(a, 1))
    command(1, "status")
    text = lastReply(1)[3]
    assert(text:find("^%[titan%] id=" .. a.id .. " epoch=") and text:find(suffix), text)
    local counted = (" cars applied=%d ignored=%d vetoed=%d failed=%d players applied=%d refused=%d ignored=%d npcs observed=%d ignored=%d carry requested=%d granted=%d denied=%d rejected=%d")
        :format(S.stats.vehicleHitsApplied, S.stats.vehicleHitsIgnored, S.stats.vehicleHitsVetoed, S.stats.vehicleHitsFailed,
            S.stats.playerHitsApplied, S.stats.playerHitsRefused, S.stats.playerHitsIgnored,
            S.stats.npcHitsObserved, S.stats.npcHitsIgnored,
            S.stats.carryRequested, S.stats.carryGranted, S.stats.carryDenied, S.stats.carryRejected)
    assert(text:sub(-#counted) == counted, text)
    assert(S.stats.playerHitsApplied >= 1 and S.stats.playerHitsRefused >= 1 and S.stats.playerHitsIgnored >= 1)
    reportNpc(1, npcHitOf(a, 77))
    reportNpc(1, npcHitOf(a, 77, { seq = 1 }))
    assert(S.stats.npcHitsObserved >= 1 and S.stats.npcHitsIgnored >= 1 and text:find(" npcs observed=", 1, true))
    -- The status of a player with no budget is still answered: it is not a command.
    for _ = 1, 20 do command(1, "status") end
    assert(lastReply(1)[2] == true)
end)

test("two distinct carry-sample rejections inside 5 s are both reported to the owner", function()
    local titan = carryFixture()
    local token = claim(titan, "npc", 5)
    sample(titan, token, { x = 1, z = 1 })
    sample(titan, token, { x = 13, z = 0 })
    sample(titan, token, { x = 11, z = 0 })
    local errors = messages(1, "error")
    assert(#errors == 2 and errors[1].reason == "carry_rejected:hold_far" and errors[2].reason == "carry_rejected:speed")
    sample(titan, token, { x = 13, z = 0 })
    assert(#messages(1, "error") == 2, "the same reason twice inside 5 s is reported once")
    now = now + 5.1
    keepAlive(titan)
    sample(titan, token, { x = 13, z = 0 })
    assert(#messages(1, "error") == 3, "and again after 5 s")
end)

test("an ignored blow names its reason in the log once per reason, and at most 64 reasons are ever logged", function()
    local a = duel(); cars(); S.forgetLog()
    -- Cars.
    world.vehicle[9].destroyed = true
    local lines = printed(function()
        reportCar(1, vehicleHitOf(a, 9, { seq = 1 }))
        reportCar(1, vehicleHitOf(a, 9, { seq = 1 }))
        reportCar(1, vehicleHitOf(a, 99, { seq = 1 }))
        reportCar(1, vehicleHitOf(a, 9, { seq = 1, epoch = 2 }))
    end)
    assert(countLines(lines, "[titans] car hit ignored: wreck") == 1, table.concat(lines, " | "))
    assert(countLines(lines, "[titans] car hit ignored: unknown_target") == 1 and countLines(lines, "[titans] car hit ignored: stale_titan") == 1)
    world.vehicle[9].destroyed = nil
    world.vehicle[9].bucket = 3
    lines = printed(function() reportCar(1, vehicleHitOf(a, 9, { seq = 1 })) end)
    assert(countLines(lines, "[titans] car hit ignored: bucket") == 1)
    world.vehicle[9].bucket, world.vehicle[9].y = 0, 900
    lines = printed(function() reportCar(1, vehicleHitOf(a, 9, { seq = 1 })) end)
    assert(countLines(lines, "[titans] car hit ignored: out_of_reach") == 1)
    world.vehicle[9].y = 6
    reportCar(1, vehicleHitOf(a, 9, { seq = 1 }))
    lines = printed(function() reportCar(1, vehicleHitOf(a, 9, { seq = 1 })) end)
    assert(countLines(lines, "[titans] car hit ignored: replay") == 1)
    -- Players (sequence 1 is a car's by now: 50 is free, and no refusal here uses it).
    players[3].dead = true
    lines = printed(function()
        reportPlayer(1, playerHitOf(a, 1, { seq = 50 }))
        reportPlayer(1, playerHitOf(a, 1, { seq = 50 }))
        reportPlayer(1, playerHitOf(a, 99, { seq = 50 }))
        reportPlayer(1, playerHitOf(a, 3, { seq = 50 }))
    end)
    for _, reason in ipairs({ "self", "unknown_target", "dead" }) do
        assert(countLines(lines, "[titans] player hit refused: " .. reason) == 1, reason .. ": " .. table.concat(lines, " | "))
    end
    players[3].dead = false
    players[3].bucket = 4
    lines = printed(function() reportPlayer(1, playerHitOf(a, 3, { seq = 50 })) end)
    assert(countLines(lines, "[titans] player hit refused: bucket") == 1)
    players[3].bucket, players[3].position = 0, { x = 900, y = 0, z = 0 }
    lines = printed(function() reportPlayer(1, playerHitOf(a, 3, { seq = 50 })) end)
    assert(countLines(lines, "[titans] player hit refused: out_of_reach") == 1)
    players[3].position = { x = 0, y = 0, z = 0 }
    lines = printed(function() reportPlayer(1, playerHitOf(a, 3, { seq = 50, record = "Attacks.Nothing_Like_It" })) end)
    assert(countLines(lines, "[titans] player hit refused: no_price:Attacks.Nothing_Like_It") == 1)
    -- The log has a bound of its own: 64 distinct reasons, then one line saying so, then nothing.
    S.forgetLog()
    lines = printed(function()
        for index = 1, 70 do reportPlayer(1, playerHitOf(a, 3, { seq = 50, record = "Attacks.Unpriced_" .. index })) end
    end)
    local priced = 0
    for _, line in ipairs(lines) do
        if line:find("[titans] player hit refused: no_price:", 1, true) == 1 then priced = priced + 1 end
    end
    assert(priced == 64 and #lines == 65, priced .. " reasons, " .. #lines .. " lines")
    assert(lines[65] == "[titans] log keys exhausted: later distinct problems are not logged", lines[65])
    S.forgetLog()
end)

-- ---------------------------------------------------------------------------
-- The restricted titan.core command: the BURST CORE filled for testing.
-- ---------------------------------------------------------------------------
local function core(caller, ...)
    commands["titan.core"](caller, table.pack(...), "titan.core")
end

-- A Titan owned by `player` whose controller has published its first frame, with the command budget refilled before each call.
local function coreTitan(player)
    reset(); withViewers(1, 2)
    local titan = spawn(player)
    assert(publish(titan)); S.reconcile(titan)
    return titan
end

test("titan.core is registered restricted and is no /titan verb and no export", function()
    assert(type(commands["titan.core"]) == "function" and restricted["titan.core"] == true, "the ACL gate is the platform's")
    assert(restricted.titan == false, "/titan stays open to every player")
    assert(T.commandActions.core == true)
    coreTitan(1)
    now = now + 5
    clear(sent)
    command(1, "core")                                        -- /titan core: the usage, nothing sent
    assert(#messages(1, "command") == 0 and lastReply(1)[2] == false and lastReply(1)[3] == "[titan] " .. T.usage, lastReply(1)[3])
    assert(T.parseCommand(table.pack("core")) == nil and T.parseCommand(table.pack("core", "on")) == nil)
    for _, verb in ipairs({ "core", "CORE" }) do
        local ok, why = X.command(1, verb)
        assert(ok == nil and why == "invalid_command", "the export has no core fill: " .. tostring(why))
        ok, why = X.command(1, verb, "on")
        assert(ok == nil and why == "invalid_command")
    end
    assert(#sent == 1, "only the usage reply left this resource")
    -- The core KEY stays what it was: /titan action core and the export's action core press it.
    local ok, why, delivered = control(1, "action", "core")
    assert(ok == true and why == nil and #delivered == 1 and delivered[1].action == "action" and delivered[1].value == "core")
end)

test("titan.core from a player with an active Titan sends the core command to that player alone, and the client's validator takes it", function()
    local titan = coreTitan(1)
    observers[1] = { 1, 2 }
    now = now + 5
    clear(sent)
    core(1)
    local list = messages(1, "command")
    assert(#list == 1 and keysOf(list[1]) == "action,op,v", "exactly the command: " .. keysOf(list[1] or {}))
    assert(list[1].v == T.protocol and list[1].op == "command" and list[1].action == "core")
    local clean = T.normalizeServerMessage(list[1], Open77TitanCatalog)
    assert(clean and clean.action == "core" and clean.value == nil, "the controller's validator takes it")
    assert(lastReply(1)[2] == true and lastReply(1)[3] == "[titan] sent core", lastReply(1)[3])
    assert(#messages(2) == 0 and #sent == 2, "the command and its answer reached the caller and nobody else")
    assert(S.titans[1] == titan and titan.active, "the Titan is untouched")
    -- No value rides on it: the validator refuses one, as it does for pilot.
    assert(T.normalizeServerMessage({ v = T.protocol, op = "command", action = "core", value = "x" }, Open77TitanCatalog) == nil)
    assert(T.normalizeServerMessage({ v = T.protocol, op = "command", action = "core", value = false }, Open77TitanCatalog) == nil)
end)

test("titan.core is admitted like the core key: a Titan, its first frame and the BURST CORE perk, and a refusal sends nothing", function()
    reset(); withViewers(1, 2)
    local function try()
        now = now + 5
        clear(sent)
        core(1)
        return #messages(1, "command") == 1, lastReply(1)
    end
    local delivered, answer = try()
    assert(not delivered and answer[2] == false and answer[3]:find("no Titan", 1, true), answer[3])
    local titan = spawn(1)                                    -- granted: its controller has not published a frame yet
    delivered, answer = try()
    assert(not delivered and answer[2] == false and answer[3]:find("not up yet", 1, true), answer[3])
    assert(publish(titan))
    assert(try(), "an active Titan")
    assert(X.setLoadout(1, { burstcore = 0 }))
    delivered, answer = try()
    assert(not delivered and answer[2] == false and answer[3]:find("loadout", 1, true), answer[3])
    assert(#sent == 1, "a refusal is answered and nothing else is sent")
    assert(X.setLoadout(1, { burstcore = 1 }))
    assert(try(), "any level of the perk")
    -- It spends the player's command budget like every command, and says so when it is gone.
    now = now + 5
    clear(sent)
    for _ = 1, T.limits.commandBurst do core(1) end
    assert(#messages(1, "command") == T.limits.commandBurst)
    core(1)
    assert(#messages(1, "command") == T.limits.commandBurst and lastReply(1)[2] == false)
    -- A dead owner's Titan is gone, and the dispatch with it.
    players[1].dead = true
    fire("onPlayerLifeStateChanged", nil, "1", "9", "dead", "pvp_damage")
    delivered, answer = try()
    assert(not delivered and answer[2] == false and answer[3]:find("no Titan", 1, true), answer[3])
end)

test("titan.core from the console names the player; without a usable id it prints the usage and sends nothing", function()
    reset(); withViewers(1, 2)
    local a, b = spawn(1), spawn(2)
    assert(publish(a) and publish(b))
    local function run(...)
        local args = table.pack(...)
        now = now + 5
        clear(sent)
        return printed(function() core(0, table.unpack(args, 1, args.n)) end)
    end
    local lines = run("2")
    assert(#messages(2, "command") == 1 and messages(2, "command")[1].action == "core" and #messages(1, "command") == 0)
    assert(#messages(1) == 0 and lastReply(2)[2] == true, "the named player is the one told")
    assert(#lines == 1 and lines[1] == "[titan] sent core", table.concat(lines, " | "))
    lines = run(" 1 ")                                        -- the id as the console types it
    assert(#messages(1, "command") == 1 and #messages(2, "command") == 0)
    for _, args in ipairs({ {}, { "x" }, { "" }, { "0" }, { "-1" }, { "1.5" }, { "2", "extra" }, { "1", "2" }, { "nan" },
        { "4294967296" } }) do
        lines = run(table.unpack(args))
        assert(#sent == 0, "no usable id sent something: " .. table.concat(args, " "))
        assert(#lines == 1 and lines[1] == "[titan] usage: titan.core <player id>", table.concat(lines, " | "))
    end
    -- A player the console names who has no Titan is answered in the console alone, before any command budget is made for the id.
    lines = run("3")
    assert(#sent == 0, "nothing is dispatched or replied")
    assert(#lines == 1 and lines[1] == "[titan] player 3 has no Titan", table.concat(lines, " | "))
    assert(S.titans[0] == nil, "the console never owns a Titan")
end)

test("titan.core from a player acts on their own Titan only: any argument is the usage", function()
    local a = coreTitan(1)
    local b = spawn(2)
    assert(publish(b))
    for _, args in ipairs({ { "2" }, { "1" }, { "x" }, { "" }, { "1", "2" } }) do
        now = now + 5
        clear(sent)
        core(1, table.unpack(args))
        assert(#sent == 1 and lastReply(1)[2] == false and lastReply(1)[3] == "[titan] usage: /titan.core", table.concat(args, " "))
    end
    now = now + 5
    clear(sent)
    core(2)
    assert(#messages(2, "command") == 1 and #messages(1, "command") == 0, "each player's own Titan")
end)

test("Titan ids come from the persisted sequence; a refused write refuses the spawn", function()
    reset(); ready(1)
    kvpFail = true
    command(1, "spawn")
    assert(S.titans[1] == nil and #messages(1, "grant") == 0 and lastReply(1)[2] == false)
    kvpFail = false
    local first = spawn(1)
    S.removeTitan(first, "owner_removed")
    now = now + 2
    local second = spawn(1)
    assert(tonumber(second.id) == tonumber(first.id) + 1, "ids count up: " .. first.id .. " -> " .. second.id)
end)

test("a restart continues the id sequence and its old ids can never be named again", function()
    reset(); ready(1)
    local first = spawn(1)
    local firstId = first.id
    S.removeTitan(first, "owner_removed")
    fire("onResourceStop", nil, "op77_lightrp_titans")   -- an orderly stop (the store flushes)
    clear(handlers); clear(commands)
    timers = {}
    dofile(root .. "server.lua")                   -- the new VM, same data directory
    S = Open77TitansServer
    ready(1)
    local second = spawn(1)
    assert(second and tonumber(second.id) == tonumber(firstId) + 1 and second.id ~= firstId,
        "a restart reissued an id: " .. firstId .. " -> " .. tostring(second and second.id))
    assert(second.revision == 1 and sameMap(second.loadout, SPEC), "a restart must not carry a loadout over")
    local ok, why = S.acceptFrame(1, frame(first, 1))
    assert(not ok and why == "stale_id", "a frame of the previous run was accepted: " .. tostring(why))
end)

-- ---------------------------------------------------------------------------
-- Restart handshake: a server-only restart knows no client; the probe and the answers to it.
-- ---------------------------------------------------------------------------
local function answer(player, bridge)
    fire(T.event.ready, player, { bridge = bridge ~= false, reason = bridge == false and "bridge_missing" or nil, answer = true })
end

local function probes()
    local list = {}
    for _, event in ipairs(sent) do
        if event.name == T.event.probe then list[#list + 1] = event end
    end
    return list
end

test("the resource's own start sends one probe to every client; another resource's start and a refused send change nothing", function()
    reset()
    fire("onResourceStart", nil, "some_other_resource")
    assert(#probes() == 0, "another resource's start probed the clients")
    fire("onResourceStart", nil, "op77_lightrp_titans")
    local list = probes()
    assert(#list == 1 and list[1].target == -1 and #list[1].args == 0, "one broadcast probe without arguments")
    assert(next(S.clients) == nil and next(S.titans) == nil and #messages(1) == 0, "a probe records and grants nothing")
    clear(sent)
    sendFails = true
    fire("onResourceStart", nil, "op77_lightrp_titans")   -- a refused broadcast is logged, never raised
    sendFails = nil
    assert(#probes() == 0 and next(S.clients) == nil)
end)

test("an answer introduces a client this run never heard from exactly as its cold start would", function()
    reset()
    assert(X.spawn(1) == nil and select(2, X.spawn(1)) == "bridge_unavailable", "before the answer: the live failure")
    answer(1)
    local client = S.clients[1]
    assert(client and client.ready == true and client.bridge == true and client.reason == nil)
    local sessions = messages(1, "session")
    assert(#sessions == 1 and sessions[1].active == true and sessions[1].player == "1", "the controller gets its session")
    local id = X.spawn(1)
    assert(T.isId(id) and S.titans[1] and S.titans[1].id == id, "the answered client can be granted a Titan")
    -- A client whose bridge is down says so in its answer: same reply, same refusal, a fixed reason only.
    answer(2, false)
    assert(S.clients[2].ready == true and S.clients[2].bridge == false and S.clients[2].reason == "bridge_missing")
    assert(lastReply(2)[2] == false and #messages(2, "session") == 0)
    assert(X.spawn(2) == nil and select(2, X.spawn(2)) == "bridge_unavailable" and S.titans[2] == nil)
    fire(T.event.ready, 3, { bridge = false, reason = "<script>", answer = true })
    assert(S.clients[3].reason == "bridge_missing" and S.clients[3].bridge == false, "a free-text reason is never kept")
    fire(T.event.ready, 0, { bridge = true, answer = true })
    assert(S.clients[0] == nil, "the console id must never be registered")
end)

test("an answer never touches a client the run already knows, and never destroys a live Titan; a plain ready still does", function()
    local titan = liveWithViewer()
    local id, epoch = titan.id, titan.epoch
    assert(titan.active == true and S.clients[1].bridge == true)
    -- Late, repeated and even contradicting answers, past the plain ready's one-second gate and inside it.
    answer(1)
    now = now + 5
    answer(1)
    answer(1, false)
    now = now + 5
    answer(1)
    assert(S.titans[1] == titan and titan.active == true and titan.id == id and titan.epoch == epoch, "the Titan was replaced")
    assert(S.clients[1].bridge == true and S.clients[1].reason == nil, "an answer overwrote a known client's record")
    assert(#sent == 0, "an answer for a known client sent something: " .. #sent)
    assert(#eventsNamed("onTitanRemoved") == 0 and #messages(2, "remove") == 0 and #messages(1, "remove") == 0)
    assert(visible[1] == false and S.hides[1] ~= nil, "V was shown again while the Titan is piloted")
    assert(publish(titan, { mode = "pilot" }), "the Titan no longer accepts its controller's frames")
    -- The cold start's own announcement is a plain ready: it keeps its owner_restarted meaning.
    now = now + 2
    fire(T.event.ready, 1, { bridge = true, answer = "yes" })   -- only answer = true is an answer: anything else is a plain ready
    released(titan, "owner_restarted")
    assert(#eventsNamed("onTitanRemoved") == 1)
end)

test("a client's own start announcement followed at once by its answer is one registration, with one session", function()
    reset()
    now = now + 2
    fire(T.event.ready, 1, { bridge = true })
    answer(1)
    assert(S.clients[1].bridge == true and #messages(1, "session") == 1, "the answer registered the client a second time")
    local titan = spawn(1)
    assert(titan, "the client can spawn")
    answer(1)
    assert(S.titans[1] == titan and #messages(1, "remove") == 0, "an answer after the grant took the grant away")
end)

test("a server-only restart: the new run knows no client, probes, rediscovers the live ones and keeps what they then own", function()
    reset(); ready(1); ready(2)
    local old = spawn(1)
    assert(publish(old, { mode = "pilot" }) and old.active == true)
    -- The old run ends in order (its clients are told) and a new VM of the same resource starts; the clients' controllers
    -- never restart, so neither client announces anything by itself.
    clear(sent)
    fire("onResourceStop", nil, "op77_lightrp_titans")
    assert(#messages(1, "session") == 1 and messages(1, "session")[1].active == false, "the old run ended the session")
    clear(handlers); clear(commands)
    timers = {}
    dofile(root .. "server.lua")
    S = Open77TitansServer
    clear(sent); clear(events)
    assert(next(S.clients) == nil and next(S.titans) == nil, "a new run starts knowing nothing")
    local id, why = X.spawn(1)
    assert(id == nil and why == "bridge_unavailable", "the failure of the live restart: " .. tostring(why))
    assert(X.spawn(2) == nil and select(2, X.spawn(2)) == "bridge_unavailable")
    -- The host runs the resource's own onResourceStart after every script ran. The live clients answer at once, inside the
    -- broadcast itself: every handler the answers need already exists at the moment the probe leaves.
    local original, probed = TriggerClientEvent, 0
    TriggerClientEvent = function(name, target, ...)
        local ok = original(name, target, ...)
        if name == T.event.probe then
            probed = probed + 1
            answer(1)
            answer(2)
        end
        return ok
    end
    fire("onResourceStart", nil, "op77_lightrp_titans")
    TriggerClientEvent = original
    assert(probed == 1, "one probe for the start: " .. probed)
    assert(S.clients[1] and S.clients[1].bridge == true and S.clients[2] and S.clients[2].bridge == true)
    assert(#messages(1, "session") == 1 and messages(1, "session")[1].active == true, "the session is open again")
    assert(#messages(2, "session") == 1 and messages(2, "session")[1].active == true)
    -- Spawning works again, for both, and a repeated answer later does not take either Titan away.
    local first, second = spawn(1), spawn(2)
    assert(first and second and first.owner == 1 and second.owner == 2, "the rediscovered clients could not spawn")
    assert(publish(first, { mode = "pilot" }) and publish(second) and first.active == true and second.active == true)
    now = now + 5
    answer(1)
    answer(2)
    assert(S.titans[1] == first and S.titans[2] == second and first.active == true and second.active == true)
    assert(#messages(1, "remove") == 0 and #messages(2, "remove") == 0 and #eventsNamed("onTitanRemoved") == 0)
    -- A client that starts after the probe still announces itself, as it always did.
    ready(3)
    assert(S.clients[3] and S.clients[3].bridge == true and #messages(3, "session") == 1)
end)

-- ---------------------------------------------------------------------------
-- The Titan PvP flag: a server script's switch (setTitanPvp / titanPvp) for whether a Titan's auto-targeting may take another
-- player's Titan or body for a foe. It is the server's word, carried to every bridge client in the `session` message, and it
-- decides nothing here.
-- ---------------------------------------------------------------------------
test("the Titan PvP flag is off until a script turns it on, and every session opens with the current value", function()
    reset(); ready(1); ready(2, false)
    assert(X.titanPvp() == false)
    local sessions = messages(1, "session")
    assert(#sessions == 1 and sessions[1].active == true and sessions[1].pvp == false, "the session carries the flag")
    local clean = T.normalizeServerMessage(sessions[1], Open77TitanCatalog)
    assert(clean and clean.pvp == false and clean.active == true and clean.player == "1", "the client's validator takes it")
    assert(#messages(2, "session") == 0, "a client without a bridge has no session")
    -- The message that ends a session names no flag, and the validator takes it that way.
    clear(sent)
    fire("onResourceStop", nil, "op77_lightrp_titans")
    local ended = messages(1, "session")
    assert(#ended == 1 and ended[1].active == false and ended[1].pvp == nil)
    assert(T.normalizeServerMessage(ended[1], Open77TitanCatalog))
end)

test("setTitanPvp tells every client with a bridge, once per change, and a client that starts later is told at its start", function()
    reset(); ready(1); ready(2); ready(3, false)
    S.clients[4] = {}                                            -- a player the server knows only from a command: no session, no bridge
    clear(sent)
    assert(X.setTitanPvp(true) == true and X.titanPvp() == true)
    for _, player in ipairs({ 1, 2 }) do
        local list = messages(player, "session")
        assert(#list == 1 and list[1].active == true and list[1].pvp == true and list[1].player == tostring(player), "player " .. player)
        local clean = T.normalizeServerMessage(list[1], Open77TitanCatalog)
        assert(clean and clean.pvp == true, "the client's validator takes the change")
    end
    assert(#messages(3) == 0 and #messages(4) == 0, "a client without a bridge was told")
    clear(sent)
    assert(X.setTitanPvp(true) == true and #sent == 0, "an unchanged value sends nothing")
    ready(5)
    assert(messages(5, "session")[1].pvp == true, "a session that starts later opens with the flag on")
    clear(sent)
    assert(X.setTitanPvp(false) == true and X.titanPvp() == false)
    for _, player in ipairs({ 1, 2, 5 }) do
        local list = messages(player, "session")
        assert(#list == 1 and list[1].pvp == false, "player " .. player .. " was told it is off again")
    end
    assert(#messages(3) == 0)
    ready(6)
    assert(messages(6, "session")[1].pvp == false)
end)

test("setTitanPvp refuses anything but a boolean, tells nobody and changes nothing; it is no client's door and no state of a Titan", function()
    reset(); ready(1)
    X.setTitanPvp(true)
    clear(sent)
    for index, value in ipairs({ 1, 0, "true", "false", "", {}, print, 0 / 0, math.huge, HOSTILE }) do
        local ok, why = X.setTitanPvp(value)
        assert(ok == false and why == "invalid_value", "bad value #" .. index)
    end
    local ok, why = X.setTitanPvp(nil)
    assert(ok == false and why == "invalid_value")
    assert(X.titanPvp() == true and #sent == 0, "a refused call changed or sent something")
    assert(select("#", X.titanPvp()) == 1 and type(X.titanPvp()) == "boolean")
    -- No client message sets it: the request vocabulary stays spawn and remove.
    for _, action in ipairs({ "setTitanPvp", "titanPvp", "pvp" }) do
        now = now + 2
        clear(sent)
        fire(T.event.request, 1, action)
        local errors = messages(1, "error")
        assert(#errors == 1 and errors[1].reason == "invalid_request" and #messages(1, "session") == 0 and X.titanPvp() == true, action)
    end
    spawn(1)
    assert(X.getState(1).pvp == nil, "the flag is not part of a Titan's state")
    X.setTitanPvp(false)
end)

-- ---------------------------------------------------------------------------
-- The mission controls: the `spawn` export's options, setHold, setClass (with the weapon rule it brings) and creditKill. Each is
-- one message to the owner's controller, which holds, locks and credits; this resource validates the call whole before it looks
-- anything up or sends anything, keeps only the last word it sent, and refuses a `weapon` command for a weapon whose perk is 0.
-- ---------------------------------------------------------------------------
local NINE = { "missiles", "vortex", "smoke", "dash", "jets", "sentry", "flight", "designator", "core" }
local WEAPON_PERKS = { xo16 = "xo16", rail = "railgun", pred = "predator", sword = "sword", fist = "fist" }
local IS_WEAPON_PERK = { xo16 = true, railgun = true, predator = true, sword = true, fist = true }

-- A valid class; `over` replaces fields (a field set to false is removed).
local function classSpec(over)
    local spec = {
        id = "vanguard", label = "Vanguard", weapon = "xo16", perks = { xoammo = 2, xodamage = 2, xoreload = 2 },
        abilities = { missiles = true, vortex = true, jets = true, core = true }, speed = 1.0,
    }
    for key, value in pairs(over or {}) do spec[key] = value ~= false and value or nil end
    return spec
end

-- A trace of nothing: no message sent, the Titan's loadout, revision and last word untouched.
local function untouched(titan, revision, loadout, held, class)
    assert(#sent == 0, "a refused call sent something")
    assert(S.titans[titan.owner] == titan and titan.revision == revision and sameMap(titan.loadout, loadout), "the loadout moved")
    assert(titan.held == held and titan.class == class, "the last word moved")
end

test("spawn takes options: piloted and hold ride the grant, nothing else does, and a bad one is refused before anything is created", function()
    reset(); ready(1); ready(2); ready(3)
    local serial = kvpStore["titans.serial"] or 0
    clear(sent)
    local BAD_OPTIONS = {
        { pilotd = true }, { piloted = "yes" }, { piloted = 1 }, { hold = 1 }, { hold = "true" }, { hold = {} }, { piloted = true, extra = false },
        { [1] = true }, "piloted", 42, true, false, print,
        setmetatable({ piloted = true }, {}),
        setmetatable({}, { __index = function() error("executed") end }),
        setmetatable({}, { __pairs = function() error("executed") end }),
        HOSTILE,
    }
    for index, options in ipairs(BAD_OPTIONS) do
        local id, why = X.spawn(1, nil, options)
        assert(id == nil and why == "invalid_options", "accepted options #" .. index .. ": " .. tostring(why))
        assert(S.titans[1] == nil and #sent == 0 and kvpStore["titans.serial"] == serial, "options #" .. index .. " left a trace")
    end
    -- good overrides do not rescue bad options, and the player and the overrides are still judged
    local id, why = X.spawn(1, { sentry = 0 }, { hold = "x" })
    assert(id == nil and why == "invalid_options" and S.titans[1] == nil and #sent == 0)
    id, why = X.spawn(1, { nope = 1 }, { hold = true })
    assert(id == nil and why == "loadout_unknown" and S.titans[1] == nil and #sent == 0)
    id, why = X.spawn("1", nil, { hold = true })
    assert(id == nil and why == "invalid_player" and #sent == 0)

    -- piloted + hold, the overrides alongside
    id = X.spawn(1, { sentry = 0 }, { piloted = true, hold = true })
    assert(id and tonumber(id) == serial + 1, "a refused call must not have consumed a Titan id")
    local grants = messages(1, "grant")
    assert(#grants == 1 and grants[1].piloted == true and grants[1].hold == true and grants[1].loadout.sentry == 0)
    assert(opsTo(1) == "grant,command", opsTo(1))
    local clean = T.normalizeServerMessage(grants[1], Open77TitanCatalog)
    assert(clean and clean.piloted == true and clean.hold == true and clean.revision == 1, "the client's validator keeps both")
    assert(S.titans[1].held == true)
    now = now + 5
    command(1, "status")
    local status = lastReply(1)[3]
    assert(status:find("held=true", 1, true) and status:find("class=-", 1, true), status)
    -- one of them, either one
    assert(X.spawn(2, nil, { piloted = true }))
    local g2 = messages(2, "grant")[1]
    assert(g2.piloted == true and g2.hold == nil and S.titans[2].held == false)
    assert(X.spawn(3, nil, { hold = true, piloted = false }))
    local g3 = messages(3, "grant")[1]
    assert(g3.piloted == nil and g3.hold == true and S.titans[3].held == true)
    -- none: the grant is what it always was, whatever way the Titan is made
    local function nextGrant(count)
        local grant = messages(3, "grant")[count]
        assert(grant and grant.piloted == nil and grant.hold == nil and S.titans[3].held == false, "grant " .. count)
    end
    S.removeTitan(S.titans[3], "owner_removed")
    assert(X.spawn(3, nil, {}))
    nextGrant(2)
    S.removeTitan(S.titans[3], "owner_removed")
    assert(X.spawn(3))
    nextGrant(3)
    S.removeTitan(S.titans[3], "owner_removed")
    command(3, "spawn")
    nextGrant(4)        -- /titan spawn carries no option
    S.removeTitan(S.titans[3], "owner_removed")
    fire(T.event.request, 3, "spawn")
    nextGrant(5)        -- neither does the controller's own call key
end)

test("the grant's options are checked on the wire: a boolean or nothing, and only a true one is carried on", function()
    reset(); ready(1)
    assert(X.spawn(1, nil, { piloted = true, hold = true }))
    local grant = messages(1, "grant")[1]
    local function with(key, value)
        local copy = {}
        for k, v in pairs(grant) do copy[k] = v end
        copy[key] = value
        return copy
    end
    assert(T.normalizeServerMessage(with("piloted", nil), Open77TitanCatalog), "piloted is optional")
    local falsy = T.normalizeServerMessage(with("piloted", false), Open77TitanCatalog)
    assert(falsy and falsy.piloted == nil and falsy.hold == true, "a false option is not carried on")
    for _, key in ipairs({ "piloted", "hold" }) do
        for _, value in ipairs({ 1, 0, "true", "", {}, print }) do
            local clean, why = T.normalizeServerMessage(with(key, value), Open77TitanCatalog)
            assert(clean == nil and why == "grant_options", key .. " " .. tostring(value))
        end
    end
    local clean, why = T.normalizeServerMessage(with("pilot", true), Open77TitanCatalog)
    assert(clean == nil and why == "message_keys")
    assert(T.normalizeSpawnOptions(nil).piloted == false and T.normalizeSpawnOptions({ hold = true }).hold == true)
end)

test("setHold sends one closed message to the owner alone, every time, and refuses before it looks anything up or sends", function()
    reset(); withViewers(1, 2)
    local a, b = spawn(1), spawn(2)
    observers[1] = { 1, 2 }
    clear(sent)
    local bucket = S.clients[1].commands
    local tokens = bucket.tokens
    for index, player in ipairs(BAD_PLAYERS) do
        local ok, why = X.setHold(player, true)
        assert(ok == false and why == "invalid_player", "bad player #" .. index)
    end
    for index, value in ipairs({ 1, 0, "true", "false", "", {}, print, 0 / 0, HOSTILE }) do
        local ok, why = X.setHold(1, value)
        assert(ok == false and why == "invalid_value", "value #" .. index)
    end
    local ok, why = X.setHold(1)
    assert(ok == false and why == "invalid_value")
    untouched(a, 1, SPEC, false, nil)
    ok, why = X.setHold(9, true)
    assert(ok == false and why == "no_titan" and #sent == 0)

    -- before the first frame, as the spawn option does it
    assert(a.active == false)
    assert(X.setHold(1, true) == true and select("#", X.setHold(1, true)) == 1)
    local list = messages(1, "hold")
    assert(#list == 2 and #messages(2) == 0 and #toAnyone("hold") == 2, "the owner alone, once per call")
    local m = list[1]
    assert(m.v == T.protocol and m.op == "hold" and m.id == a.id and m.epoch == a.epoch and m.held == true)
    local keys = 0
    for _ in pairs(m) do keys = keys + 1 end
    assert(keys == 5, "a closed message")
    local clean = T.normalizeServerMessage(m, Open77TitanCatalog)
    assert(clean and clean.held == true and clean.id == a.id and clean.epoch == a.epoch)
    assert(a.held == true and b.held == false)

    -- release is idempotent too, and needs no first frame, no loadout and no budget
    clear(sent)
    for _ = 1, 20 do assert(X.setHold(1, false) == true) end
    assert(#messages(1, "hold") == 20 and messages(1, "hold")[20].held == false and a.held == false)
    assert(bucket.tokens == tokens, "no command budget is spent")

    -- refusals of the platform and of the client
    S.clients[1].bridge = false
    clear(sent)
    ok, why = X.setHold(1, true)
    assert(ok == false and why == "bridge_unavailable" and #sent == 0 and a.held == false)
    S.clients[1].bridge = true
    sendFails = true
    ok, why = X.setHold(1, true)
    sendFails = nil
    assert(ok == false and why == "owner_unavailable" and a.held == false, "a target that is gone changes nothing")

    -- the controller's validator takes the message and nothing like it
    local function with(key, value)
        local copy = {}
        for k, v in pairs(m) do copy[k] = v end
        copy[key] = value
        return copy
    end
    for _, bad in ipairs({
        { "held", "yes" }, { "held", 1 }, { "held", nil }, { "id", "0" }, { "id", nil }, { "epoch", 0 }, { "epoch", 1.5 }, { "epoch", nil },
    }) do
        local result, reason = T.normalizeServerMessage(with(bad[1], bad[2]), Open77TitanCatalog)
        assert(result == nil and reason == "hold_invalid", bad[1] .. " " .. tostring(bad[2]) .. " " .. tostring(reason))
    end
    local result, reason = T.normalizeServerMessage(with("extra", true), Open77TitanCatalog)
    assert(result == nil and reason == "message_keys")

    -- no client door
    for _, action in ipairs({ "setHold", "hold" }) do
        now = now + 2
        clear(sent)
        fire(T.event.request, 1, action)
        local errors = messages(1, "error")
        assert(#errors == 1 and errors[1].reason == "invalid_request" and #messages(1, "hold") == 0, action)
    end
end)

test("setClass refuses a bad call whole, before it looks anything up or sends, and with the reason that names the fault", function()
    reset(); ready(1)
    local titan = spawn(1)
    now = now + 5
    clear(sent)
    for index, player in ipairs(BAD_PLAYERS) do
        local ok, why = X.setClass(player, classSpec())
        assert(ok == false and why == "invalid_player", "bad player #" .. index)
    end
    local function refused(reason, spec, label)
        local ok, why = X.setClass(1, spec)
        assert(ok == false and why == reason, (label or "?") .. ": " .. tostring(why) .. " (wanted " .. reason .. ")")
        untouched(titan, 1, SPEC, false, nil)
    end
    for index, spec in ipairs({ "vanguard", 42, true, false, print, HOSTILE, setmetatable(classSpec(), {}) }) do
        refused("invalid_class", spec, "spec #" .. index)
    end
    refused("invalid_class", classSpec({ extra = 1 }), "an unknown key")
    refused("invalid_class", classSpec({ [1] = "x" }), "an index")
    for _, id in ipairs({ "", "Vanguard", "van guard", "van-guard", ("a"):rep(33), 1, true, {}, "vanguard\n" }) do
        refused("invalid_id", classSpec({ id = id }), "id " .. tostring(id))
    end
    refused("invalid_id", classSpec({ id = false }), "no id")
    for index, label in ipairs({ "", ("L"):rep(33), "caf\195\169", "tab\t", "line\nbreak", 42, true, {}, HOSTILE }) do
        refused("invalid_label", classSpec({ label = label }), "label #" .. index)
    end
    refused("invalid_label", classSpec({ label = false }), "no label")
    for _, weapon in ipairs({ "laser", "Rail", "xo-16", "", 1, true, {}, print }) do
        refused("invalid_weapon", classSpec({ weapon = weapon }), "weapon " .. tostring(weapon))
    end
    refused("invalid_weapon", classSpec({ weapon = false }), "no weapon")
    for _, speed in ipairs({ 0.49, 1.51, 0, -1, 2, "1", true, {}, 0 / 0, math.huge, -math.huge }) do
        refused("invalid_speed", classSpec({ speed = speed }), "speed " .. tostring(speed))
    end
    for _, harm in ipairs({ 0.09, 50.01, 0, -1, "5", true, {}, 0 / 0, math.huge }) do
        refused("invalid_harm", classSpec({ harm = harm }), "harm " .. tostring(harm))
    end
    for _, regen in ipairs({ 0.24, 10.01, 0, -1, "2", true, {}, 0 / 0, math.huge }) do
        refused("invalid_regen", classSpec({ regen = regen }), "regen " .. tostring(regen))
    end
    for index, abilities in ipairs({ "all", 1, true, { nope = true }, { missiles = 1 }, { missiles = "true" }, { core = {} }, { [1] = true },
        { missiles = true, nope = false }, setmetatable({ missiles = true }, {}), HOSTILE }) do
        refused("invalid_abilities", classSpec({ abilities = abilities }), "abilities #" .. index)
    end
    refused("invalid_abilities", classSpec({ abilities = false }), "no abilities")
    -- the perks are the loadout's own: sparse, known, whole and in range
    refused("loadout_unknown", classSpec({ perks = { nope = 1 } }), "unknown perk")
    refused("loadout_range", classSpec({ perks = { xoammo = 3 } }), "perk over its maximum")
    refused("loadout_range", classSpec({ perks = { xoammo = -1 } }), "perk under zero")
    refused("loadout_value", classSpec({ perks = { xoammo = 0.5 } }), "perk half a level")
    refused("loadout_value", classSpec({ perks = { xoammo = "2" } }), "perk as text")
    refused("loadout_value", classSpec({ perks = { xoammo = 0 / 0 } }), "perk NaN")
    refused("loadout_invalid", classSpec({ perks = "xoammo" }), "perks as text")
    refused("loadout_invalid", classSpec({ perks = setmetatable({ xoammo = 1 }, {}) }), "perks with a metatable")
    -- a perk list may name the weapon perks; the class weapon's rule is applied after it, not refused
    assert(X.setClass(1, classSpec({ perks = { railgun = 0, xo16 = 0 } })) == true and X.getLoadout(1).xo16 == 1)

    -- no Titan, no bridge, a target that is gone: the reason, and nothing changed
    X.setClass(1, nil)
    local ok, why = X.setClass(2, classSpec())
    assert(ok == false and why == "no_titan")
    clear(sent)
    local before = titan.revision
    S.clients[1].bridge = false
    ok, why = X.setClass(1, classSpec())
    assert(ok == false and why == "bridge_unavailable" and #sent == 0 and titan.revision == before)
    S.clients[1].bridge = true
    sendFails = true
    ok, why = X.setClass(1, classSpec())
    sendFails = nil
    assert(ok == false and why == "owner_unavailable" and titan.revision == before and titan.class == nil)
    assert(sameMap(titan.loadout, SPEC))
end)

test("setClass is one message to the owner alone: the whole loadout under a newer revision and the class, applied by the controller in one step", function()
    reset(); withViewers(1, 2)
    local a, b = spawn(1), spawn(2)
    observers[1] = { 1, 2 }
    clear(sent)
    local spec = classSpec()
    assert(X.setClass(1, spec) == true and select("#", X.setClass(1, spec)) == 1)
    local list = messages(1, "class")
    assert(#list == 2 and #messages(2) == 0 and #toAnyone("class") == 2, "the owner alone, once per call")
    local m = list[2]
    assert(m.v == T.protocol and m.op == "class" and m.id == a.id and m.epoch == a.epoch and m.revision == 3, "one revision per call")
    assert(list[1].revision == 2)
    local expected = copyMap(SPEC)
    expected.xoammo, expected.xodamage, expected.xoreload = 2, 2, 2
    expected.railgun, expected.predator, expected.sword, expected.fist, expected.xo16 = 0, 0, 0, 0, 1
    assert(sameMap(m.loadout, expected) and sameMap(a.loadout, expected) and sameMap(X.getLoadout(1), expected))
    assert(m.class.id == "vanguard" and m.class.label == "Vanguard" and m.class.weapon == "xo16" and m.class.speed == 1.0)
    for _, name in ipairs(NINE) do
        assert(type(m.class.abilities[name]) == "boolean", name .. " is not on the wire as a boolean")
        assert(m.class.abilities[name] == (spec.abilities[name] == true), name)
    end
    local keys = 0
    for _ in pairs(m.class.abilities) do keys = keys + 1 end
    assert(keys == 9)
    assert(a.revision == 3 and a.class.id == "vanguard" and X.getState(1).revision == 3)
    now = now + 5
    command(1, "status")
    assert(lastReply(1)[3]:find("held=false class=vanguard", 1, true), lastReply(1)[3])
    assert(b.revision == 1 and b.class == nil and sameMap(b.loadout, SPEC), "another player's Titan is not touched")
    -- the controller's validator takes it, as a copy of its own
    local clean = T.normalizeServerMessage(m, Open77TitanCatalog)
    assert(clean and clean.revision == 3 and clean.class.id == "vanguard" and sameMap(clean.loadout, expected))
    assert(clean.loadout ~= m.loadout and clean.class ~= m.class and clean.class.abilities ~= m.class.abilities)
    -- nothing the server holds aliases what it sent, or what the caller passed
    m.loadout.sentry, m.class.label = 0, "x"
    assert(a.loadout.sentry == 1 and a.class.label == "Vanguard")
    spec.abilities.smoke, spec.label = true, "Changed"
    assert(a.class.abilities.smoke == false and a.class.label == "Vanguard")

    -- missing keys are false and the speed is 1 unless given; a spec may leave the perks out
    clear(sent)
    assert(X.setClass(1, { id = "bare", label = "Bare", weapon = "fist", abilities = {} }))
    local bare = messages(1, "class")[1]
    for _, name in ipairs(NINE) do assert(bare.class.abilities[name] == false, name) end
    assert(bare.class.speed == 1.0 and bare.class.weapon == "fist" and bare.loadout.fist == 1 and bare.loadout.xo16 == 0)
    assert(bare.class.harm == 1.0 and bare.class.regen == 1.0, "the damage BT takes and its shield are the controller's own unless given")
    assert(T.normalizeServerMessage(bare, Open77TitanCatalog), "an empty class is a class")
    -- the speed bounds are inclusive
    for _, speed in ipairs({ 0.5, 0.85, 1.2, 1.5 }) do
        clear(sent)
        assert(X.setClass(1, classSpec({ speed = speed })) and messages(1, "class")[1].class.speed == speed, speed)
    end
    -- and so are the damage multiple's: the owner's controller gets it with the class
    for _, harm in ipairs({ 0.1, 1.0, 5, 20, 50 }) do
        clear(sent)
        assert(X.setClass(1, classSpec({ harm = harm })) and messages(1, "class")[1].class.harm == harm, harm)
    end
    for _, regen in ipairs({ 0.25, 1.0, 2.5, 10 }) do
        clear(sent)
        assert(X.setClass(1, classSpec({ regen = regen })) and messages(1, "class")[1].class.regen == regen, regen)
    end
    -- a class with no sentry perk lets a body in the fist go, like setLoadout does
    assert(X.setClass(1, classSpec({ perks = { sentry = 0 } })))
    assert(a.loadout.sentry == 0)

    -- clearing: every perk at its maximum, no class on the wire, everything allowed again
    clear(sent)
    local revision = a.revision
    assert(X.setClass(1, nil) == true)
    local cleared = messages(1, "class")
    assert(#cleared == 1 and cleared[1].class == nil and cleared[1].revision == revision + 1 and sameMap(cleared[1].loadout, SPEC))
    assert(a.class == nil and sameMap(X.getLoadout(1), SPEC))
    local again = T.normalizeServerMessage(cleared[1], Open77TitanCatalog)
    assert(again and again.class == nil and again.revision == revision + 1)
    -- and the loadout export carries on from there
    clear(sent)
    assert(X.setLoadout(1, { xodamage = 1 }) and messages(1, "loadout")[1].revision == revision + 2)
end)

test("the class message is checked on the wire: the loadout whole, the class closed, every field bounded", function()
    reset(); ready(1)
    local titan = spawn(1)
    assert(X.setClass(1, classSpec()))
    local m = messages(1, "class")[1]
    local function with(path, value)
        local copy = { v = m.v, op = m.op, id = m.id, epoch = m.epoch, revision = m.revision, loadout = copyMap(m.loadout) }
        copy.class = { id = m.class.id, label = m.class.label, weapon = m.class.weapon, speed = m.class.speed,
            abilities = copyMap(m.class.abilities) }
        local target, key = copy, path[1]
        if path[2] then target, key = copy[path[1]], path[2] end
        if path[3] then target, key = copy[path[1]][path[2]], path[3] end
        target[key] = value
        return copy
    end
    local function bad(path, value, reason)
        local result, why = T.normalizeServerMessage(with(path, value), Open77TitanCatalog)
        assert(result == nil and why == reason, table.concat(path, ".") .. "=" .. tostring(value) .. " -> " .. tostring(why))
    end
    bad({ "extra" }, true, "message_keys")
    bad({ "id" }, "0", "class_invalid")
    bad({ "epoch" }, 0, "class_invalid")
    bad({ "revision" }, 0, "class_revision")
    bad({ "revision" }, 1.5, "class_revision")
    bad({ "loadout", "xoammo" }, nil, "class_loadout")
    bad({ "loadout", "xoammo" }, 3, "class_loadout")
    bad({ "loadout", "nope" }, 1, "class_loadout")
    bad({ "class" }, "vanguard", "class_keys")
    bad({ "class", "extra" }, 1, "class_keys")
    bad({ "class", "perks" }, {}, "class_keys")
    bad({ "class", "id" }, "Vanguard", "class_id")
    bad({ "class", "id" }, ("a"):rep(33), "class_id")
    bad({ "class", "label" }, "", "class_label")
    bad({ "class", "label" }, "caf\195\169", "class_label")
    bad({ "class", "weapon" }, "laser", "class_weapon")
    bad({ "class", "speed" }, 1.6, "class_speed")
    bad({ "class", "speed" }, "1", "class_speed")
    bad({ "class", "harm" }, 50.5, "class_harm")
    bad({ "class", "harm" }, 0, "class_harm")
    bad({ "class", "harm" }, "5", "class_harm")
    bad({ "class", "regen" }, 10.5, "class_regen")
    bad({ "class", "regen" }, 0.2, "class_regen")
    bad({ "class", "regen" }, "2", "class_regen")
    bad({ "class", "abilities" }, "all", "class_abilities")
    bad({ "class", "abilities", "nope" }, true, "class_abilities")
    bad({ "class", "abilities", "core" }, 1, "class_abilities")
    -- a speed the sender left out is 1, an ability it left out is off; the clean copy always has all nine
    local sparse = with({ "class", "speed" }, nil)
    sparse.class.abilities = { missiles = true }
    local clean = T.normalizeServerMessage(sparse, Open77TitanCatalog)
    assert(clean and clean.class.speed == 1.0 and clean.class.abilities.missiles == true and clean.class.abilities.core == false)
    assert(clean.class.harm == 1.0 and clean.class.regen == 1.0, "a harm or a regen the sender left out is 1")
    local harsh = with({ "class", "harm" }, 5)
    assert(T.normalizeServerMessage(harsh, Open77TitanCatalog).class.harm == 5, "a harm in range goes through")
    -- the class may be absent (cleared), and only then
    local gone = with({ "class" }, nil)
    assert(T.normalizeServerMessage(gone, Open77TitanCatalog).class == nil)
    assert(titan.class.id == "vanguard")
end)

test("the five missions' classes are all accepted, each with exactly its weapon selectable", function()
    reset(); ready(1)
    local titan = spawn(1)
    local classes = {
        { id = "vanguard", label = "Vanguard", weapon = "xo16", speed = 1.0,
          perks = { xoammo = 2, xodamage = 2, xoreload = 2 }, abilities = { missiles = true, vortex = true, jets = true, core = true } },
        { id = "ronin", label = "Ronin", weapon = "sword", speed = 1.2,
          perks = { airdash = 1, dashregen = 3, dashcap = 2, dashdist = 2, skate = 3, sworddamage = 2, swordspeed = 2, swordreach = 2 },
          abilities = { dash = true, smoke = true, core = true } },
        { id = "northstar", label = "Northstar", weapon = "rail", speed = 1.0,
          perks = { jumpgauge = 1, jumpcharge = 2, jumpcap = 2, railcap = 2, railcharge = 2, raildamage = 2, flight = 1, designator = 1 },
          abilities = { jets = true, flight = true, designator = true, core = true } },
        { id = "legion", label = "Legion", weapon = "pred", speed = 0.85,
          perks = { sentry = 1, hull = 3, armor = 3, blastres = 3, predcap = 2, predspin = 2, preddamage = 2 },
          abilities = { sentry = true, vortex = true, smoke = true, core = true } },
        { id = "brawler", label = "Brawler", weapon = "fist", speed = 1.0,
          perks = { fistdamage = 2, fistarmor = 2, fiststun = 2, vortexthrow = 2 },
          abilities = { jets = true, dash = true, vortex = true, core = true } },
    }
    assert(publish(titan))
    for _, class in ipairs(classes) do
        clear(sent)
        assert(X.setClass(1, class) == true, class.id)
        local m = messages(1, "class")[1]
        assert(T.normalizeServerMessage(m, Open77TitanCatalog), class.id .. " is refused by the controller's validator")
        local loadout = X.getLoadout(1)
        for weapon, perk in pairs(WEAPON_PERKS) do
            assert(loadout[perk] == (weapon == class.weapon and 1 or 0), class.id .. " " .. weapon)
        end
        for perk, level in pairs(class.perks) do assert(loadout[perk] == level, class.id .. " " .. perk) end
        for perk, max in pairs(SPEC) do
            if class.perks[perk] == nil and not IS_WEAPON_PERK[perk] then
                assert(loadout[perk] == max, class.id .. " left " .. perk .. " at " .. loadout[perk])
            end
        end
        -- exactly its own weapon can be selected; nothing is sent for the other four
        for weapon in pairs(WEAPON_PERKS) do
            local ok, why, commands = control(1, "weapon", weapon)
            if weapon == class.weapon then
                assert(ok == true and #commands == 1 and commands[1].value == weapon, class.id .. " " .. weapon)
            else
                assert(ok == nil and why == "loadout_disabled" and #commands == 0 and #sent == 0, class.id .. " " .. weapon)
            end
        end
    end
end)

test("a weapon whose perk is 0 cannot be selected: /titan, the command export and every way a Titan is made refuse it, with no send", function()
    reset(); ready(1); ready(2)
    local titan = spawn(1)
    assert(publish(titan))
    for weapon in pairs(WEAPON_PERKS) do assert(control(1, "weapon", weapon) == true, "the default loadout owns " .. weapon) end
    -- a class takes four weapons away
    assert(X.setClass(1, classSpec({ weapon = "rail" })))
    for _, weapon in ipairs({ "xo16", "pred", "sword", "fist" }) do
        local ok, why, commands = control(1, "weapon", weapon)
        assert(ok == nil and why == "loadout_disabled" and #commands == 0 and #sent == 0, weapon)
        now = now + 5
        clear(sent)
        command(1, "weapon", weapon)
        assert(#messages(1, "command") == 0 and lastReply(1)[2] == false, "/titan " .. weapon .. " went through")
    end
    local ok, why, commands = control(1, "weapon", "rail")
    assert(ok == true and #commands == 1 and commands[1].value == "rail")
    now = now + 5
    clear(sent)
    command(1, "weapon", "rail")
    assert(#messages(1, "command") == 1 and lastReply(1)[2] == true)
    -- the refusal is about the weapon only: the other controls and actions still go
    for _, args in ipairs({ { "pilot" }, { "exit" }, { "action", "dash" }, { "action", "core" } }) do
        assert(control(1, table.unpack(args)) == true, args[1] .. " " .. tostring(args[2]))
    end
    -- the rule is the loadout's, not the class's: setLoadout and the spawn's overrides apply it too
    assert(X.setLoadout(1, { railgun = 0, fist = 1 }))
    ok, why = X.command(1, "weapon", "rail")
    assert(ok == nil and why == "loadout_disabled", "setLoadout took the railgun")
    assert(control(1, "weapon", "fist") == true)
    assert(X.spawn(2, { sword = 0 }))
    assert(publish(S.titans[2]))
    ok, why = X.command(2, "weapon", "sword")
    assert(ok == nil and why == "loadout_disabled", "a spawn override took the sword")
    assert(control(2, "weapon", "fist") == true)
    -- a bad value is still invalid_value, whatever the loadout says
    ok, why = X.command(1, "weapon", "laser")
    assert(ok == nil and why == "invalid_value")
    -- clearing the class gives every weapon back
    assert(X.setClass(1, nil))
    for weapon in pairs(WEAPON_PERKS) do assert(control(1, "weapon", weapon) == true, weapon .. " after the class") end
end)

test("creditKill dispatches one closed message to the owner alone, takes only three ranks and spends no request or budget", function()
    reset(); withViewers(1, 2)
    local a, b = spawn(1), spawn(2)
    observers[1] = { 1, 2 }
    clear(sent)
    local bucket = S.clients[1].commands
    local tokens = bucket.tokens
    for index, player in ipairs(BAD_PLAYERS) do
        local ok, why = X.creditKill(player, "grunt")
        assert(ok == false and why == "invalid_player", "bad player #" .. index)
    end
    for index, rank in ipairs({ "boss", "Grunt", "grunt ", "", "vehicle", "av", "turret", 5, true, {}, print, HOSTILE }) do
        local ok, why = X.creditKill(1, rank)
        assert(ok == false and why == "invalid_value", "rank #" .. index)
    end
    local ok, why = X.creditKill(1)
    assert(ok == false and why == "invalid_value")
    assert(#sent == 0, "a refused call sent something")
    ok, why = X.creditKill(9, "grunt")
    assert(ok == false and why == "no_titan" and #sent == 0)

    -- granted only: there is no first-frame admission, and no answer to wait for
    local requests, pending, actions = a.requestSeq, a.pendingCount, S.stats.actionsSent
    for _, rank in ipairs({ "grunt", "rare", "heavy" }) do
        clear(sent)
        local result = { X.creditKill(1, rank) }
        assert(#result == 1 and result[1] == true, rank)
        local list = messages(1, "credit_kill")
        assert(#list == 1 and #messages(2) == 0 and #sent == 1, "the owner alone")
        local m = list[1]
        assert(m.v == T.protocol and m.op == "credit_kill" and m.id == a.id and m.epoch == a.epoch and m.rank == rank)
        local keys = 0
        for _ in pairs(m) do keys = keys + 1 end
        assert(keys == 5, "a closed message")
        local clean = T.normalizeServerMessage(m, Open77TitanCatalog)
        assert(clean and clean.rank == rank and clean.id == a.id and clean.epoch == a.epoch)
    end
    assert(a.requestSeq == requests and a.pendingCount == pending and S.stats.actionsSent == actions, "a kill credit is no request")
    assert(bucket.tokens == tokens, "no command budget is spent")

    -- a target that is gone, a client without a bridge
    S.clients[1].bridge = false
    clear(sent)
    ok, why = X.creditKill(1, "heavy")
    assert(ok == false and why == "bridge_unavailable" and #sent == 0)
    S.clients[1].bridge = true
    sendFails = true
    ok, why = X.creditKill(1, "heavy")
    sendFails = nil
    assert(ok == false and why == "owner_unavailable")

    -- the wire: a rank of the three, a Titan and an epoch, nothing else
    local m = { v = T.protocol, op = "credit_kill", id = a.id, epoch = a.epoch, rank = "rare" }
    assert(T.normalizeServerMessage(m, Open77TitanCatalog))
    for _, bad in ipairs({ { "rank", "boss" }, { "rank", 1 }, { "rank", nil }, { "id", "x" }, { "epoch", 0 }, { "extra", true } }) do
        local copy = {}
        for k, v in pairs(m) do copy[k] = v end
        copy[bad[1]] = bad[2]
        local result, reason = T.normalizeServerMessage(copy, Open77TitanCatalog)
        assert(result == nil and reason == (bad[1] == "extra" and "message_keys" or "credit_invalid"), bad[1] .. " " .. tostring(reason))
    end
    -- no client door
    for _, action in ipairs({ "creditKill", "credit_kill", "setClass", "class" }) do
        now = now + 2
        clear(sent)
        fire(T.event.request, 1, action)
        local errors = messages(1, "error")
        assert(#errors == 1 and errors[1].reason == "invalid_request", action)
    end
end)

test("the mission controls die with the Titan: a removed Titan has no hold, class or credit to send", function()
    reset(); ready(1)
    local titan = spawn(1)
    assert(X.setClass(1, classSpec()) and X.setHold(1, true))
    S.removeTitan(titan, "owner_removed")
    clear(sent)
    assert(select(2, X.setHold(1, false)) == "no_titan")
    assert(select(2, X.setClass(1, classSpec())) == "no_titan")
    assert(select(2, X.creditKill(1, "grunt")) == "no_titan")
    assert(#sent == 0)
    -- a new Titan starts with nothing of the last one's
    assert(X.spawn(1))
    local fresh = S.titans[1]
    assert(fresh.held == false and fresh.class == nil and fresh.revision == 1 and sameMap(fresh.loadout, SPEC))
end)

test("the controller's loadout and catalog modules are the resource's own files with `local` in front of the table", function()
    local function read(path)
        local file = assert(io.open(root .. path, "rb"))
        local text = file:read("a")
        file:close()
        return text
    end
    local loadout = read("loadout.lua"):gsub("\nOpen77TitanLoadout = {", "\nlocal Open77TitanLoadout = {", 1)
    assert(loadout == read("controller/open77_titan_loadout.lua"), "the two loadout files drifted apart")
    local catalog = read("catalog.lua"):gsub("\nOpen77TitanCatalog = {", "\nlocal Open77TitanCatalog = {", 1)
    assert(catalog == read("controller/open77_titan_catalog.lua"), "the two catalog files drifted apart")
    assert(Open77TitanLoadout.weaponPerk("rail") == "railgun" and Open77TitanLoadout.weaponPerk("laser") == nil
        and Open77TitanLoadout.weaponPerk(1) == nil)
    local ok, reason = Open77TitanLoadout.forClass("laser", {})
    assert(ok == nil and reason == "loadout_weapon")
end)

report(("%d server tests passed"):format(passed))
