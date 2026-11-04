-- op77_lightrp_titans (server): one server-owned BT-7274 per player and a bounded
-- audiovisual relay.
--
-- The controller (the BT-7274 controller in the owner's client resource) simulates the Titan; this
-- file decides what the rest of the session may believe about it. The server
-- creates the Titan record (opaque id + epoch, owner from the authenticated
-- connection), accepts frames only from that owner for that id and epoch with a
-- strictly increasing sequence, validates every field against shared.lua and the
-- catalog, budgets rate and bytes, and relays only the accepted frame to players
-- in the owner's scope. Late joiners get the last persistent state with no events;
-- old shots are never replayed. It never decides damage to a Titan: observers only render, the owner's controller keeps the Titan's
-- health and reports it in each frame (frame.gameplay), and a server script's hit / repair requests are answered by it. What
-- one owner's controller SAW its Titan land on another player's Titan, or the status effect its own calls would apply to it,
-- reaches server scripts only as the host events onTitanHitObserved / onTitanStatusObserved (authenticated observations, see
-- "Observed hits and status effects"); this file never turns one into a hit, a repair or a status effect. The authored core
-- charge a confirmed Titan hit or kill is worth is the server script's call too (creditCore), answered by the owner's
-- controller like a hit. What the controller's weapons take off a CAR is different, because only the canonical ledger sticks
-- on a car: the owner reports each blow (vehicle_hit), the server authenticates it, publishes it as the cancellable host event
-- onTitanVehicleHit and, unless a script vetoes it, takes the share off the car's canonical health ("Blows on cars"). A blow on
-- another PLAYER is reported the same way (player_hit) but priced here, per attack record, and applied with Open77.players.damage
-- under the platform's PvP rules ("Blows on players"). A blow on a platform NPC is reported (npc_hit) and published as onTitanNpcHit
-- for the mission that owns the NPC to validate and price: this file never touches an NPC for it ("Blows on NPCs").
--
-- It also arbitrates the Titan's fist physically grabbing a canonical NPC or
-- vehicle ("Physical carry"): one resource-owned claim per Titan and per body, every
-- authored sample validated here before it reaches Open77.npcs / Open77.vehicles
-- beginCarry / updateCarry / endCarry, every exit funnelled through removeTitan.
--
-- Every Titan also owns its server-controlled loadout (loadout.lua): the level of every
-- authored upgrade, all at their maximum by default, changed only by server Lua through
-- this resource's server exports (spawn/remove/getLoadout/setLoadout/getLoadoutSpec, see the
-- end of the file, which also holds the command, input, releaseInput, hit, repair, creditCore and getState exports: the same
-- /titan controls, the held / analog pilot controls and the mission's hit, repair and core credit requests for server Lua, and
-- a copy of the state the server accepted; and the setTitanPvp / titanPvp pair, the Titan PvP flag every bridge client is sent
-- with its `session` message). The record owns the loadout and its revision; the owner's controller is
-- told the full scoped map on the grant and on every change, and no client message can set it.
-- The server itself arbitrates only what it can see: grab/shoulder and a carry claim need the
-- `sentry` perk, the core action needs `burstcore`.
-- The restricted `titan.core` command (the ACL right command.titan.core; the console is always allowed and names a player) fills
-- the BURST CORE of the caller's own Titan for testing. It is a cheat in PvP, so it is a command of its own: /titan never parses
-- it and the `command` export has no vocabulary for it.
--
-- The mission controls (the `spawn` export's `piloted` / `hold` options, setHold, setClass and creditKill) are one message each to
-- the owner's controller, which is what holds, locks and credits. The server validates the call and keeps only the last word it
-- sent (titan.held, titan.class) and the loadout a class made, from which it refuses a `weapon` command for a weapon whose perk is 0.
local T = Open77Titans
local L = T.limits
local RESOURCE = GetCurrentResourceName()

local catalogOk, catalogReason = T.checkCatalog(Open77TitanCatalog)
if not catalogOk then
    error("op77_lightrp_titans: catalog.lua must assign Open77TitanCatalog with the variables, meshes, lights, effects, "
        .. "attachedEffects and sounds dictionaries (" .. tostring(catalogReason) .. ")", 0)
end
local catalog = Open77TitanCatalog

-- The perks this file arbitrates itself must exist in the schema, or the policy below would
-- silently never bite.
local LOADOUT = T.loadout
if type(LOADOUT) ~= "table" or type(LOADOUT.defaults) ~= "function" or type(LOADOUT.patch) ~= "function"
    or type(LOADOUT.weaponPerk) ~= "function" or type(LOADOUT.forClass) ~= "function"
    or type(LOADOUT.max) ~= "table" or type(LOADOUT.max.sentry) ~= "number" or type(LOADOUT.max.burstcore) ~= "number" then
    error("op77_lightrp_titans: loadout.lua must assign Open77TitanLoadout (max, defaults, patch, weaponPerk and forClass, with the "
        .. "sentry and burstcore perks) before shared.lua", 0)
end

-- A loadout map leaves this file only as a fresh copy: a caller (same VM or not) can never
-- hold a reference into a Titan's record.
local function copyLoadout(map)
    local copy = {}
    for perk, level in pairs(map) do copy[perk] = level end
    return copy
end

-- A plain nested table (the owner's gameplay report) leaves this file only as a fresh deep copy.
local function copyTree(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do copy[key] = copyTree(child) end
    return copy
end

local titans = {}     -- [ownerPlayerId] = Titan record (one per player)
local clients = {}    -- [playerId] = { ready, bridge, reason, readyAt, commands }
local hides = {}      -- [ownerPlayerId] = V network-body visibility ownership (see setHide)
local bodies = {}     -- ["npc:12"] = the Titan whose carry claim holds that body (one claim per body)
local stats = { framesAccepted = 0, framesRejected = 0, eventsRelayed = 0, eventsDropped = 0,
    eventsReplayed = 0, sendFailures = 0,
    carryRequested = 0, carryGranted = 0, carryDenied = 0, carryAccepted = 0, carryRejected = 0,
    carryStale = 0, carryDropped = 0, carryEnded = 0, carryEndFailures = 0,
    actionsSent = 0, actionsAnswered = 0, actionsUnanswered = 0, actionsIgnored = 0,
    hitsObserved = 0, hitsRejected = 0, hitsIgnored = 0,
    statusObserved = 0, statusRejected = 0, statusIgnored = 0,
    vehicleHitsObserved = 0, vehicleHitsRejected = 0, vehicleHitsIgnored = 0,
    vehicleHitsVetoed = 0, vehicleHitsApplied = 0, vehicleHitsFailed = 0,
    playerHitsObserved = 0, playerHitsRejected = 0, playerHitsIgnored = 0, playerHitsApplied = 0, playerHitsRefused = 0,
    npcHitsObserved = 0, npcHitsRejected = 0, npcHitsIgnored = 0 }
local running = true
-- Frames wait here, per owner, until the end of the host tick (see drainInbox).
local inbox, flushing = {}, false

-- Titan ids come from the resource's own persisted sequence (Open77.kvp, one JSON
-- file under this resource's data/ directory, flushed when the resource stops), so
-- a restart or reload continues counting instead of reissuing an id that a late
-- frame or a stale client record could still name. A failed write refuses the spawn.
local function nextTitanId()
    local n = Open77.kvp.increment("titans.serial", 1)
    n = type(n) == "number" and math.tointeger(n) or nil
    if not n or n < 1 then return nil end
    return tostring(n)
end

local function clock() return Open77.time.monotonic() end

-- A problem that repeats is printed once per key, and at most 64 keys: a refused blow names itself in the log without a client
-- being able to flood it.
local LOG_KEYS = 64
local logged, loggedCount = {}, 0
local function logOnce(key, text)
    if logged[key] then return end
    if loggedCount >= LOG_KEYS then
        if loggedCount == LOG_KEYS then
            loggedCount = loggedCount + 1
            print("[titans] log keys exhausted: later distinct problems are not logged")
        end
        return
    end
    logged[key] = true
    loggedCount = loggedCount + 1
    print("[titans] " .. text)
end
local function forgetLog() logged, loggedCount = {}, 0 end

-- Lifecycle and request outcomes are announced to every resource of this server with the host-local TriggerEvent (never
-- to a client). The state has already changed when this runs and never waits for a listener; a refused publish is logged.
-- `owner` is the player NUMBER (what every export takes), the Titan id is text.
local function emit(name, ...)
    local ok, accepted, why = pcall(TriggerEvent, name, ...)
    if not ok or accepted == false then
        print(("[titans] event %s was not published: %s"):format(name, tostring(ok and why or accepted)))
    end
end

-- The same announcement, vetoable: the verdict handle, or nil (and the reason is logged) when the event could not be published.
-- The handlers run inline and the verdict settles one host tick later (settleVehicleHits reads it).
local function emitCancellable(name, ...)
    local ok, verdict, why = pcall(TriggerCancellableEvent, name, ...)
    if not ok or verdict == nil then
        print(("[titans] event %s was not published: %s"):format(name, tostring(ok and why or verdict)))
        return nil
    end
    return verdict
end

-- Net-event `source`, command sources and host-event arguments (strings) all end
-- up here. 0 is the console and must never reach `Open77.players.*`: an id
-- below 1 stops the resource.
local function playerId(value)
    local n = tonumber(value)
    if n == nil or n ~= n or n < 1 or n % 1 ~= 0 or n > 4294967295 then return nil end
    return math.tointeger(n) or n
end

local TEXT = {
    bridge_unavailable = "the Titan bridge is not available on your client (see the client log for the missing piece)",
    already_spawned = "you already have a Titan; /titan remove it first",
    no_titan = "you have no Titan; /titan spawn first",
    not_active = "your Titan is not up yet: the controller has not published its first frame",
    owner_unavailable = "you are not ready or the server has no fresh position for you yet",
    owner_dead = "you are dead",
    titan_limit = "the server Titan limit is reached",
    rate_limited = "too fast; wait a moment",
    id_unavailable = "the server could not allocate a Titan id (the resource's persistent storage refused the write)",
    invalid_request = "unsupported request",
    not_fist = "BT is not wielding the fist: /titan weapon fist first",
    loadout_disabled = "the server disabled that ability in your Titan's loadout",
}
local BRIDGE_TEXT = {
    bridge_missing = "the Open77 Titan bridge natives are not registered: this client needs the Open77 build with the Titan bridge (plugin + Open77TitanBridge.reds)",
    rtti_denied = "the client did not grant rtti.native to this resource",
    rtti_unavailable = "this client build has no Open77.rtti",
}

local function reply(player, raw, ok, text)
    text = "[titan] " .. text
    print(text)
    TriggerClientEvent("open77:command:result", player, raw or "", ok == true, text)
end

local function bridgeReady(player)
    local client = clients[player]
    return client ~= nil and client.ready == true and client.bridge == true
end

-- The server's Titan PvP flag (the `setTitanPvp` export, see the end of the file): false until a server script turns it on.
local titanPvp = false

-- The message that opens a client's session and re-asserts it when the flag changes: the controller's bridge takes the flag from it.
local function sessionMessage(player)
    return { v = T.protocol, op = "session", active = true, player = tostring(player), pvp = titanPvp }
end

-- One reliable event carries every bridge op. `false` here means the target is
-- not a player any more; the payload itself is bounded by construction.
local function send(player, message)
    local ok = TriggerClientEvent(T.event.message, player, message)
    if ok == false then stats.sendFailures = stats.sendFailures + 1 end
    return ok ~= false
end

local function removeMessage(titan, reason)
    return { v = T.protocol, op = "remove", id = titan.id, epoch = titan.epoch, reason = reason }
end

local function sendError(player, reason)
    if bridgeReady(player) then send(player, { v = T.protocol, op = "error", reason = reason }) end
end

-- Tells the owner about a rejected frame/event at most once per 5 s per kind.
local function report(titan, key, reason)
    local now = clock()
    if (titan.reports[key] or -math.huge) + 5 > now then return end
    titan.reports[key] = now
    sendError(titan.owner, reason)
end

-- ---------------------------------------------------------------------------
-- V's network body while its owner pilots. `setVisible` is the server-canonical
-- visibility bit (it replicates; the controller's local SetInvisible does not).
-- Ownership is minimal: this resource only undoes a hide it applied itself, and
-- never touches a player somebody else had already hidden. The platform also
-- releases the bit on death, respawn, bucket change, disconnect and resource stop.
-- ---------------------------------------------------------------------------
local function pumpHide(owner)
    local hide = hides[owner]
    if not hide or not hide.ours then return end
    if hide.applied == hide.want then
        if not hide.want then hides[owner] = nil end
        return
    end
    local ok, reason = Open77.players.setVisible(owner, not hide.want)
    if ok then
        hide.applied, hide.attempts = hide.want, 0
        if not hide.want then hides[owner] = nil end
        return
    end
    hide.attempts = (hide.attempts or 0) + 1
    reason = tostring(reason)
    local denied = reason:find("^permission_denied") ~= nil
    -- A revive/respawn in flight is transient and retried by the tick; anything
    -- else that repeats is not going to resolve.
    if denied or reason == "player_not_found" or reason == "invalid_argument" or hide.attempts >= 40 then
        hides[owner] = nil
        print("[titans] player visibility refused for " .. tostring(owner) .. ": " .. reason)
        local titan = titans[owner]
        if titan and denied then sendError(owner, "visibility_unavailable") end
    end
end

local function setHide(owner, hidden)
    local hide = hides[owner]
    if hidden then
        if hide and not hide.ours then hides[owner], hide = nil, nil end
        if not hide then
            if Open77.players.isVisible(owner) == false then
                hides[owner] = { ours = false }
                return
            end
            hide = { ours = true, want = true, applied = false, attempts = 0 }
            hides[owner] = hide
        else
            hide.want = true
        end
    else
        if not hide then return end
        if not hide.ours then hides[owner] = nil return end
        hide.want = false
    end
    pumpHide(owner)
end

-- ---------------------------------------------------------------------------
-- Lifecycle.
-- ---------------------------------------------------------------------------
-- Every way a Titan can leave, as the carry end the owner's controller is told.
local TITAN_END = {
    owner_removed = "titan_removed", owner_left = "carrier_left", owner_dead = "carrier_dead",
    bucket_changed = "bucket_changed", resource_stopped = "resource_stopped", owner_stalled = "titan_stalled",
    controller_timeout = "titan_removed", out_of_scope = "titan_removed", pose_rejected = "titan_removed",
    owner_restarted = "titan_removed",
}
local releaseCarry  -- the Physical carry section below

-- ---------------------------------------------------------------------------
-- Gameplay requests in flight (the hit / repair exports). One entry per request number, answered once by the owner's
-- controller or ended here as 'timeout' or 'titan_removed': every request ends in exactly one
-- onTitanActionResult(owner, id, request, kind, ok, reason, amount), and none is ever dropped silently.
-- ---------------------------------------------------------------------------
local function settle(titan, request, ok, reason, amount)
    local entry = titan.pending[request]
    if not entry then return false end
    titan.pending[request] = nil
    titan.pendingCount = titan.pendingCount - 1
    emit("onTitanActionResult", titan.owner, titan.id, request, entry.kind, ok, reason, amount)
    return true
end

-- Ends, oldest first, every request sent before `deadline` (all of them without one) as not taken, for `reason`.
local function settleUnanswered(titan, reason, deadline)
    if titan.pendingCount == 0 then return end
    local due = {}
    for request, entry in pairs(titan.pending) do
        if deadline == nil or entry.at < deadline then due[#due + 1] = request end
    end
    table.sort(due)
    for _, request in ipairs(due) do
        if settle(titan, request, false, reason) then stats.actionsUnanswered = stats.actionsUnanswered + 1 end
    end
end

-- The weapons resource flings a player's body in a car blast; a pilot is parked inside the Titan, so it is told to leave the
-- pilot alone while piloting. A failure (the resource is not running, the platform refused) is logged once.
local function setLaunchExempt(player, exempt)
    local ok, accepted, why = pcall(function()
        return Open77.exports.callSync("open77_weapons", "setLaunchExempt", player, exempt)
    end)
    if not ok then
        logOnce("launch-exempt", "launch exemption failed: " .. tostring(accepted))
    elseif accepted ~= true then
        logOnce("launch-exempt", "launch exemption failed: " .. tostring(why))
    end
end

-- A scripted death (freeroam's teleport, a join spawn, an admin move) is not the owner going down while BT stands
-- outside; inside BT the pilot leaves the cockpit with it, so the Titan goes.
local function ownerDeathEndsTitan(titan)
    if not Open77.players.isDead(titan.owner) then return false end
    local life = Open77.players.getLifeState(titan.owner)
    if type(life) == "table" and life.cause == "script" and titan.mode ~= "pilot" then return false end
    return true
end

local function removeTitan(titan, reason)
    if titans[titan.owner] ~= titan then return false end
    -- A held body goes back to the world before anything else about the Titan changes.
    releaseCarry(titan, TITAN_END[reason] or "titan_removed")
    titans[titan.owner] = nil
    inbox[titan.owner] = nil
    -- Requests still waiting for an answer end here with a reason of their own, before the Titan is announced gone.
    settleUnanswered(titan, "titan_removed")
    local message = removeMessage(titan, reason)
    if reason ~= "owner_left" and bridgeReady(titan.owner) then send(titan.owner, message) end
    for viewer in pairs(titan.viewers) do
        if bridgeReady(viewer) then send(viewer, message) end
    end
    titan.viewers = {}
    setHide(titan.owner, false)
    setLaunchExempt(titan.owner, false)
    print(("[titans] released Titan %s of player %d: %s"):format(titan.id, titan.owner, reason))
    emit("onTitanRemoved", titan.owner, titan.id, reason)
    return true
end

local function stateMessage(titan, events)
    local snapshot = titan.snapshot
    return {
        v = T.protocol, op = "state", id = titan.id, epoch = titan.epoch, owner = tostring(titan.owner),
        seq = snapshot.seq, t = snapshot.t, serverTime = clock(),
        pose = snapshot.pose, mode = snapshot.mode, weapon = snapshot.weapon,
        vars = snapshot.vars, meshes = snapshot.meshes, lights = snapshot.lights,
        visuals = snapshot.visuals, events = events,
    }
end

-- Who may see this Titan: exactly the players the platform streams its owner to
-- (same routing bucket, inside the player scope), and only if their client has a
-- working bridge. A viewer that appears gets the latest persistent state with no
-- events; one that leaves is told to drop the remote.
local function reconcile(titan)
    if titans[titan.owner] ~= titan then return end
    local observers = Open77.players.observers(titan.owner)
    if type(observers) ~= "table" then return end
    local present = {}
    for _, viewer in ipairs(observers) do
        if viewer ~= titan.owner and bridgeReady(viewer) then
            present[viewer] = true
            if not titan.viewers[viewer] then
                titan.viewers[viewer] = true
                if titan.snapshot then send(viewer, stateMessage(titan, {})) end
            end
        end
    end
    for viewer in pairs(titan.viewers) do
        if not present[viewer] then
            titan.viewers[viewer] = nil
            if bridgeReady(viewer) then send(viewer, removeMessage(titan, "out_of_scope")) end
        end
    end
end

local function countTitans()
    local count = 0
    for _ in pairs(titans) do count = count + 1 end
    return count
end

-- Creates the Titan record for a living, ready, in-bucket player and grants it.
-- `direct` is the /titan path: the server also commands the spawn. The controller's
-- own call key goes through `request` instead and spawns on the grant it asked for.
local function spawnTitan(player, direct, loadout, options)
    if not bridgeReady(player) then return nil, "bridge_unavailable" end
    if titans[player] then return nil, "already_spawned" end
    if countTitans() >= L.titans then return nil, "titan_limit" end
    local read = Open77.players.get(player)
    if type(read) ~= "table" or read.ready == false then return nil, "owner_unavailable" end
    if read.dead == true then return nil, "owner_dead" end
    if read.fresh ~= true or type(read.position) ~= "table" then return nil, "owner_unavailable" end
    local id = nextTitanId()
    if not id then return nil, "id_unavailable" end
    local now = clock()
    local titan = {
        id = id, epoch = 1, owner = player, bucket = read.bucket or 0,
        grantedAt = now, active = false, seq = 0, t = -1, eventSeq = 0,
        poseViolations = 0, accepted = 0, rejected = 0, viewers = {}, reports = {},
        carryRequest = 0,
        pending = {}, pendingCount = 0, requestSeq = 0, destroyed = false,
        results = T.bucket(L.resultBurst, L.resultRate, now),
        loadout = loadout or LOADOUT.defaults(), revision = 1,
        -- What a mission asked at the spawn (the export's options) and later (setHold, setClass): the server keeps the last word
        -- it sent so a status can say it; the controller is what holds and gates.
        held = options ~= nil and options.hold == true,
        carryRequests = T.bucket(L.carryRequestBurst, L.carryRequestRate, now),
        carryMessages = T.bucket(L.carryMessageBurst, L.carryMessageRate, now),
        frames = T.bucket(L.frameBurst, L.frameRate, now),
        bytes = T.bucket(L.byteBurst, L.byteRate, now),
        events = T.bucket(L.eventBurst, L.eventRate, now),
        observed = T.bucket(L.eventBurst, L.eventRate, now), hitSeen = {}, hitHigh = 0,
        npcRounds = {}, npcRoundN = 0,
    }
    titans[player] = titan
    local grant = { v = T.protocol, op = "grant", id = titan.id, epoch = titan.epoch, owner = tostring(player),
        revision = titan.revision, loadout = copyLoadout(titan.loadout) }
    -- The options ride the grant, and only a true one: a piloted Titan is placed at the owner's own place and seats V at once, a
    -- held one starts held (the controller gates every control until setHold releases it).
    if options ~= nil and options.piloted == true then grant.piloted = true end
    if options ~= nil and options.hold == true then grant.hold = true end
    send(player, grant)
    if direct then send(player, { v = T.protocol, op = "command", action = "spawn" }) end
    print(("[titans] granted Titan %s to player %d (bucket %s)%s%s"):format(titan.id, player, tostring(titan.bucket),
        grant.piloted and ", piloted" or "", grant.hold and ", held" or ""))
    emit("onTitanCreated", player, titan.id, titan.epoch)
    return titan
end

local function distance(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

-- ---------------------------------------------------------------------------
-- Physical carry. The Titan's fist grabs a canonical NPC or vehicle, holds it in
-- its hand and throws it. The owner's controller authors the motion; this section
-- decides what the rest of the session may believe about it:
--   * one claim per Titan and per body, bound to the Titan's id and epoch, to its
--     authenticated owner and to the platform's opaque token;
--   * a claim starts only for a live Titan wielding the fist, a ready carrier and a
--     living, free body of the same routing bucket within reach of the Titan's root;
--   * every sample is strictly sequenced, finite, inside the hand envelope (hold; however long it lasts, as long as
--     it is fed) or the bounded flight (<= 30 s from its first accepted pose, for a vehicle and a person alike; a
--     speed ceiling plus gravity), and budgeted apart from the Titan's frames and one-shot events;
--   * a thrown person's flight messages and its release carry the owner's authored release (root pose, the impulse
--     and its point, radius, delay, time): checked against the claim, the Titan and the clock, fixed by the first
--     accepted flight message, refused when it is missing or changes, and handed to updateCarry as its fourth argument;
--   * the canonical body moves ONLY through Open77.npcs / Open77.vehicles
--     beginCarry / updateCarry / endCarry, a resource-owned claim the platform
--     publishes as canonical motion: never a per-frame teleport, never a clone;
--   * every way a claim can end funnels through releaseCarry, which gives the body
--     back through endCarry and tells the owner's controller.
-- The server never sees a native entity id: the client resource resolved the
-- controller's grab to the canonical id (see client.lua) before asking.
-- ---------------------------------------------------------------------------
local CARRY_API = { npc = "npcs", vehicle = "vehicles" }
-- Titan modes in which it is never grabbing (the call-down, the send-home jump, the eject).
local CARRY_BLOCKED = { drop = true, leave = true, eject = true }

-- What the platform answers to a refused beginCarry, in shared.lua's fixed
-- vocabulary. Anything it adds later is 'refused': never passed through.
local BEGIN_DENIED = {
    npc_not_found = "target_missing", vehicle_not_found = "target_missing",
    carrier_unavailable = "owner_unavailable", carrier_busy = "already_carrying", wrong_bucket = "bucket_mismatch",
    npc_dead = "target_dead", already_carried = "target_claimed",
    npc_mounted = "target_busy", npc_presentation = "target_busy", vehicle_occupied = "target_busy",
    vehicle_seat_reserved = "target_busy", vehicle_ai_driven = "target_busy", vehicle_driven = "target_busy",
}
-- ... and what it says when a claim is gone (a refused update, or an unsolicited end). The platform's only duration
-- bound is a flight's own allowance, so `duration_exceeded` is the same end as this resource's flight_expired; a hold
-- has none, and only its idle watchdog (ttl_expired) can end it for time.
local CLAIM_ENDED = {
    ttl_expired = "claim_expired", claim_expired = "claim_expired", duration_exceeded = "flight_expired",
    resource_stopped = "resource_stopped", carrier_left = "carrier_left", carrier_dead = "carrier_dead",
    carrier_bucket_changed = "bucket_changed", bucket_changed = "bucket_changed", wrong_bucket = "bucket_changed",
    entity_removed = "entity_removed", entity_died = "entity_died", npc_dead = "entity_died",
    occupied = "target_busy", seat_reserved = "target_busy",
    vehicle_occupied = "target_busy", invalid_pose = "pose_rejected", invalid_argument = "pose_rejected",
    launch_required = "pose_rejected", invalid_launch = "pose_rejected", launch_changed = "pose_rejected",
    carrier_unavailable = "owner_unavailable",
}

local function deniedReason(why)
    if type(why) ~= "string" then return "refused" end
    if why == "unavailable" or why:find("^permission_denied") then return "unavailable" end
    return BEGIN_DENIED[why] or "refused"
end

local function endedReason(why)
    return type(why) == "string" and CLAIM_ENDED[why] or "claim_lost"
end

-- Host-event ids arrive as text or numbers; the claim index keys on the canonical text.
local function idText(value)
    local n = tonumber(value)
    n = n and math.tointeger(n)
    if not n or n < 1 then return nil end
    return string.format("%d", n)
end

local function carryKey(kind, entityId) return kind .. ":" .. entityId end

-- The one door to the platform. A missing function, a refused permission or an
-- exception is an explicit 'unavailable' for the caller to report, never a skip.
local function core(kind, name, ...)
    local api = Open77[CARRY_API[kind]]
    local fn = type(api) == "table" and api[name] or nil
    if type(fn) ~= "function" then return nil, "unavailable" end
    local ok, first, second = pcall(fn, ...)
    if not ok then
        print(("[titans] carry: Open77.%s.%s raised: %s"):format(CARRY_API[kind], name, tostring(first)))
        return nil, "unavailable"
    end
    return first, second
end

-- The body's canonical place, from the platform's own read: { bucket, x, y, z,
-- alive, occupied, health } (a vehicle's health, 0..1, when the platform reports one) or nil plus the denial reason.
local function readTarget(kind, id)
    local read, why
    if kind == "npc" then
        read, why = core("npc", "presence", id)
    else
        read, why = core("vehicle", "get", id)
    end
    if type(read) ~= "table" then return nil, deniedReason(why) == "unavailable" and "unavailable" or "target_missing" end
    if not (T.finite(read.x) and T.finite(read.y) and T.finite(read.z)) then return nil, "target_missing" end
    local target = { bucket = read.bucket, x = read.x, y = read.y, z = read.z }
    if kind == "npc" then
        target.alive = read.alive == true
        target.occupied = false
    else
        target.alive = read.destroyed ~= true and read.exploded ~= true
        target.occupied = type(read.occupants) == "table" and #read.occupants > 0
        target.health = read.health
    end
    return target
end

local function denyCarry(titan, wire, reason)
    stats.carryDenied = stats.carryDenied + 1
    titan.lastCarryDenial = { request = wire.request, kind = wire.kind, entityId = wire.entityId, reason = reason }
    print(("[titans] carry denied for player %d: %s %s: %s"):format(
        titan.owner, tostring(wire.kind), tostring(wire.entityId), reason))
    if bridgeReady(titan.owner) then
        send(titan.owner, { v = T.protocol, op = "carry_denied", id = wire.id, epoch = wire.epoch,
            request = wire.request, reason = reason })
    end
end

-- The ONE exit of a claim. `platformEnded` is true when the platform already
-- ended it (and said so), so there is nothing left to give back; every other
-- exit asks endCarry, which is idempotent and never touches a newer claim.
function releaseCarry(titan, reason, platformEnded)
    local carry = titan.carry
    if not carry then return false end
    titan.carry = nil
    if bodies[carry.key] == titan then bodies[carry.key] = nil end
    local ended, why = true, nil
    if not platformEnded then
        ended, why = core(carry.kind, "endCarry", carry.id, carry.token)
        if not ended then
            stats.carryEndFailures = stats.carryEndFailures + 1
            print(("[titans] carry: endCarry of %s failed: %s"):format(carry.key, tostring(why)))
        end
    end
    stats.carryEnded = stats.carryEnded + 1
    titan.lastCarryEnd = {
        kind = carry.kind, entityId = carry.entityId, token = carry.token, reason = reason, at = clock(),
        pose = carry.pose, phase = carry.phase, accepted = carry.accepted, endOk = ended == true, endReason = why,
    }
    print(("[titans] carry of %s ended for player %d: %s"):format(carry.key, titan.owner, reason))
    if reason ~= "carrier_left" and bridgeReady(titan.owner) then
        send(titan.owner, { v = T.protocol, op = "carry_ended", id = titan.id, epoch = titan.epoch,
            token = carry.token, reason = reason })
    end
    return true
end

-- Whether `pose` is a believable next sample of this claim: true, or false plus the
-- reason. 'flight_expired' is not a bad sample but the end of the claim: a flight, of a person's ragdoll or of a
-- vehicle alike, lasts carryFlight from its first accepted pose (carry.flightAt on this clock, carry.flightT on the
-- wire's). A hold has no time limit at all, so nothing here counts from the grant.
local function carryAdmitted(titan, carry, pose, t, now)
    if carry.phase == "flight" and pose.phase ~= "flight" then return false, "phase_order" end
    local cap, flown = L.carrySpeed, 0
    if pose.phase == "flight" then
        -- A thrown NPC ragdoll outruns any hand or vehicle, so it has its own speed base.
        if carry.kind == "npc" then cap = L.carryNpcFlightSpeed end
        if carry.phase == "flight" then
            flown = now - carry.flightAt
            if flown > L.carryFlight + L.carryFlightSlack or t - carry.flightT > L.carryFlight + 0.1 then
                return false, "flight_expired"
            end
        end
        -- The authored arc is the owner's ragdoll or ballistic flight: a speed
        -- ceiling that grows with gravity over the (bounded) flight, not a teleport.
        cap = cap + L.carryGravity * math.min(flown, L.carryFlight)
    elseif distance(pose, titan.pose) > L.carryReach then
        return false, "hold_far"
    end
    local gap = math.min(math.max(now - carry.poseAt, L.carryMinGap), L.carryMaxGap)
    if distance(pose, carry.pose) > cap * gap + L.carrySlack then return false, "speed" end
    -- A vehicle in the hand moves with the Titan, which dashes: its velocity bound is the platform's own, not the hand's.
    local vmax = (pose.phase ~= "flight" and carry.kind == "vehicle") and L.carryVelocity or cap
    if pose.vx * pose.vx + pose.vy * pose.vy + pose.vz * pose.vz > vmax * vmax * (1 + 1e-9) then return false, "velocity" end
    return true
end

-- The release of a thrown person rides on every flight message of its claim and on its release, because the host
-- dispatches a tick's messages NEWEST FIRST: the first flight message may be overtaken by the next one, which must be
-- able to carry the throw on its own. So the first accepted one fixes the descriptor for the claim, a later one
-- may only repeat it exactly, and nothing else (a hold, a vehicle) carries one. The platform is handed the
-- descriptor with the flight message that is accepted, `elapsed` = how long before that message the release was made
-- (the release stamps the throw at its own time, whichever message arrived first); the `t` it was made at stays here.
-- Returns true, nil and the descriptor for the platform (nil: this message has none), or false and the reason.
local LAUNCH_FIELDS = { "t", "x", "y", "z", "yaw", "px", "py", "pz", "ix", "iy", "iz", "radius", "delay" }
local function carryLaunch(titan, carry, wire)
    local launch = wire.launch
    if wire.pose.phase ~= "flight" or carry.kind ~= "npc" then
        if launch then return false, "launch_unexpected" end
        return true
    end
    if not launch then return false, "launch_missing" end
    local known = carry.launch
    if known then
        for _, key in ipairs(LAUNCH_FIELDS) do
            if launch[key] ~= known[key] then return false, "launch_changed" end
        end
    else
        -- The release happened after the last hold sample this claim accepted and not long before the message that
        -- reports it, with the body and the impulse near the Titan that threw it (not wherever the flight is by now).
        if launch.t < carry.t or wire.t - launch.t > L.carryLaunchLag then return false, "launch_stale" end
        if distance(launch, titan.pose) > L.carryReach
            or distance({ x = launch.px, y = launch.py, z = launch.pz }, titan.pose) > L.carryReach then
            return false, "launch_far"
        end
    end
    -- `elapsed` is the release's age at THIS message. Late in a flight a repeat can be a hair past the platform's
    -- own horizon (the wire clock may run 0.1 s over it, see carryAdmitted): it is held there, and the platform only
    -- stamps the release from the message that first carries it.
    return true, nil, {
        x = launch.x, y = launch.y, z = launch.z, yaw = launch.yaw, px = launch.px, py = launch.py, pz = launch.pz,
        ix = launch.ix, iy = launch.iy, iz = launch.iz, radius = launch.radius, delay = launch.delay,
        elapsed = math.min(wire.t - launch.t, L.carryFlight),
    }
end

-- One carry_frame or carry_release of the owner. The host dispatches the messages
-- of one tick NEWEST FIRST, so a release can overtake the frames before it: it
-- carries the final pose, applies it when it is newer than anything accepted, and
-- ends the claim regardless; the older frames that follow find no claim (or a
-- newer sequence) and are dropped without penalty.
local function onCarrySample(titan, wire, now)
    local carry = titan.carry
    if wire.id ~= titan.id or wire.epoch ~= titan.epoch or not carry or carry.token ~= wire.token then
        stats.carryStale = stats.carryStale + 1
        return
    end
    local release = wire.op == "carry_release"
    if not release and not T.take(carry.samples, 1, now) then
        stats.carryDropped = stats.carryDropped + 1
        return
    end
    local fresh = wire.seq > carry.seq and wire.t >= carry.t
    if not fresh and not release then
        stats.carryStale = stats.carryStale + 1
        return
    end
    if fresh then
        local pose = wire.pose
        local admitted, why = carryAdmitted(titan, carry, pose, wire.t, now)
        local launch
        if admitted then admitted, why, launch = carryLaunch(titan, carry, wire) end
        if admitted then
            local ok, lost = core(carry.kind, "updateCarry", carry.id, carry.token, pose, launch)
            if not ok then return releaseCarry(titan, endedReason(lost)) end
            carry.seq, carry.t, carry.pose, carry.poseAt, carry.lastAt = wire.seq, wire.t, pose, now, now
            if pose.phase == "flight" and carry.phase ~= "flight" then carry.flightAt, carry.flightT = now, wire.t end
            if wire.launch and not carry.launch then carry.launch = wire.launch end
            carry.phase, carry.violations, carry.accepted = pose.phase, 0, carry.accepted + 1
            stats.carryAccepted = stats.carryAccepted + 1
        elseif why == "flight_expired" then
            return releaseCarry(titan, "flight_expired")
        elseif not release then
            carry.violations = carry.violations + 1
            stats.carryRejected = stats.carryRejected + 1
            titan.lastCarryReject = why
            report(titan, "carry:" .. why, "carry_rejected:" .. why)
            if carry.violations >= L.carryViolations then return releaseCarry(titan, "pose_rejected") end
            return
        end
    end
    if release then releaseCarry(titan, wire.reason) end
end

-- One carry_request of the owner, already resolved by the client to the canonical
-- id. Every refusal answers with a fixed reason and touches nothing.
local function onCarryRequest(titan, wire, now)
    stats.carryRequested = stats.carryRequested + 1
    if wire.id ~= titan.id or wire.epoch ~= titan.epoch then return denyCarry(titan, wire, "stale_titan") end
    if not T.take(titan.carryRequests, 1, now) then return denyCarry(titan, wire, "rate_limited") end
    if wire.request <= titan.carryRequest then return denyCarry(titan, wire, "stale_request") end
    titan.carryRequest = wire.request
    if not titan.active or not titan.snapshot then return denyCarry(titan, wire, "not_active") end
    if titan.weapon ~= "fist" then return denyCarry(titan, wire, "not_fist") end
    -- A grab needs the sentry perk: nothing the owner's controller authored changes that.
    if titan.loadout.sentry == 0 then return denyCarry(titan, wire, "refused") end
    if CARRY_BLOCKED[titan.mode] or now - titan.lastFrameAt > L.carryFresh then
        return denyCarry(titan, wire, "titan_busy")
    end
    if titan.carry then return denyCarry(titan, wire, "already_carrying") end

    local owner = Open77.players.get(titan.owner)
    if type(owner) ~= "table" or owner.ready == false or owner.dead == true then
        return denyCarry(titan, wire, "owner_unavailable")
    end
    if owner.bucket ~= titan.bucket then return denyCarry(titan, wire, "bucket_mismatch") end

    local key = carryKey(wire.kind, wire.entityId)
    if bodies[key] then return denyCarry(titan, wire, "target_claimed") end
    local id = math.tointeger(tonumber(wire.entityId))
    if not id then return denyCarry(titan, wire, "target_missing") end
    local target, why = readTarget(wire.kind, id)
    if not target then return denyCarry(titan, wire, why) end
    if target.bucket ~= titan.bucket then return denyCarry(titan, wire, "bucket_mismatch") end
    -- A wreck is carried like any car (`alive` is a car's not being destroyed); only a dead person is refused.
    if wire.kind == "npc" and not target.alive then return denyCarry(titan, wire, "target_dead") end
    if target.occupied then return denyCarry(titan, wire, "target_busy") end
    if distance(target, titan.pose) > L.carryReach then return denyCarry(titan, wire, "target_far") end

    local token, refusal = core(wire.kind, "beginCarry", id, titan.owner)
    if not token or not T.isToken(token) then
        -- A claim with a token this resource cannot name is still a claim: give it back.
        if type(token) == "string" then core(wire.kind, "endCarry", id, token) end
        if token then print("[titans] carry: the platform returned a malformed token for " .. key) end
        return denyCarry(titan, wire, token and "refused" or deniedReason(refusal))
    end
    titan.carry = {
        kind = wire.kind, id = id, entityId = wire.entityId, key = key, token = token, request = wire.request,
        claimedAt = now, lastAt = now, poseAt = now, seq = 0, t = -1, phase = "hold", violations = 0, accepted = 0,
        pose = { x = target.x, y = target.y, z = target.z },
        samples = T.bucket(L.carryBurst, L.carryRate, now),
    }
    bodies[key] = titan
    stats.carryGranted = stats.carryGranted + 1
    print(("[titans] carry of %s granted to player %d (Titan %s)"):format(key, titan.owner, titan.id))
    if bridgeReady(titan.owner) then
        send(titan.owner, { v = T.protocol, op = "carry_grant", id = titan.id, epoch = titan.epoch,
            request = wire.request, kind = wire.kind, entityId = wire.entityId, token = token })
    end
end

local function onCarryMessage(player, raw)
    local titan = titans[player]
    if not titan then return end   -- no Titan, nothing to bind: no answer either
    local now = clock()
    if not T.take(titan.carryMessages, 1, now) then
        stats.carryDropped = stats.carryDropped + 1
        return
    end
    local wire, reason = T.normalizeServerCarry(raw)
    if not wire then
        stats.carryRejected = stats.carryRejected + 1
        report(titan, "carry-wire", "carry_rejected:" .. reason)
        return
    end
    if wire.op == "carry_request" then return onCarryRequest(titan, wire, now) end
    return onCarrySample(titan, wire, now)
end

-- The platform ended a claim of this resource (or the body it holds is gone).
local function platformEnded(kind, id, token, reason, ended)
    local entityId = idText(id)
    local titan = entityId and bodies[carryKey(kind, entityId)]
    local carry = titan and titan.carry
    if not carry or (token ~= nil and tostring(token) ~= carry.token) then return end
    releaseCarry(titan, endedReason(reason), ended)
end

-- A claim whose flight outlived its allowance, whose Titan stopped being in a fist state or that nobody feeds
-- any more ends here. A hold's own time is never a reason: it lasts as long as it is fed and fresh.
local function watchCarry(titan, now)
    local carry = titan.carry
    if carry.phase == "flight" and now - carry.flightAt > L.carryFlight + L.carryFlightSlack then
        releaseCarry(titan, "flight_expired")
    elseif now - titan.lastFrameAt > L.carryStall * 2 then
        releaseCarry(titan, "titan_stalled")
    elseif now - carry.lastAt > L.carryStall then
        releaseCarry(titan, "claim_stalled")
    end
end

-- What the server accepted and what the platform holds, for diagnostics: the
-- record of the claim, the platform's own read of it (token only to its owner) and
-- whether the two agree.
local function carryReport(titan)
    local carry = titan.carry
    local result = { active = carry ~= nil, last = titan.lastCarryEnd, denied = titan.lastCarryDenial }
    if not carry then return result end
    local now = clock()
    result.kind, result.entityId, result.token, result.phase = carry.kind, carry.entityId, carry.token, carry.phase
    result.seq, result.accepted, result.pose = carry.seq, carry.accepted, carry.pose
    result.age, result.idle = now - carry.claimedAt, now - carry.lastAt
    local platform = core(carry.kind, "carry", carry.id)
    if type(platform) == "table" then
        result.platform = platform
        result.platformAgrees = platform.token == carry.token and tonumber(platform.carrier) == titan.owner
    end
    return result
end

local function carryText(titan)
    local state = carryReport(titan)
    if not state.active then
        local last = state.last
        return last and ("carry=none last=%s:%s/%s"):format(last.kind, last.entityId, last.reason) or "carry=none"
    end
    local pose = state.pose
    return ("carry=%s:%s phase=%s accepted=%d age=%.1f idle=%.2f pose=%.1f,%.1f,%.1f platform=%s"):format(
        state.kind, state.entityId, state.phase, state.accepted, state.age, state.idle, pose.x, pose.y, pose.z,
        state.platform and (state.platformAgrees and "agrees" or "DISAGREES") or "unreadable")
end

-- Movement admission for the Titan root. The platform's own player-snapshot
-- admission (SessionManager.IsPlausible) only bounds coordinates and velocity
-- and constrains active dash/forced-motion leases, so the controller driving V
-- every frame is admitted there; this keeps the same ceilings for the Titan.
--
-- Distance from the owner is only a rule for the FIRST pose of a grant (150 m, or
-- 500 m when that frame is the 'drop' call-down arriving from the sky); afterwards a
-- Titan may stand anywhere the owner left it and only continuity applies.
-- 'drop' may only be the opening frames of a grant, 'leave' only after non-drop
-- frames, and one continuous run of either lasts at most `dropWindow` seconds:
-- they relax nothing else, so they cannot be used to bypass the continuity rule.
local EXTENDED = { drop = true, leave = true }

local function motionAdmitted(titan, frame, now)
    local mode, previous = frame.mode, titan.mode
    if mode == "drop" and previous ~= nil and previous ~= "drop" then return false, "mode_transition" end
    if mode == "leave" and (previous == nil or previous == "drop") then return false, "mode_transition" end
    if EXTENDED[mode] and previous == mode and now - titan.extendedAt > L.dropWindow then
        return false, "mode_expired"
    end
    if not titan.pose then
        local read = Open77.players.get(titan.owner)
        if type(read) ~= "table" or read.bucket ~= titan.bucket then return false, "owner_unavailable" end
        if read.fresh ~= true or type(read.position) ~= "table" then return false, "owner_position_unknown" end
        local radius = mode == "drop" and L.dropRadius or L.spawnRadius
        if distance(read.position, frame.pose) > radius then return false, "pose_far" end
        return true
    end
    local gap = math.max(math.min(now - titan.poseAt, L.poseMaxGap), L.poseMinGap)
    if distance(titan.pose, frame.pose) > L.poseSpeed * gap + L.poseSlack then return false, "pose_jump" end
    return true
end

local function reject(titan, reason)
    stats.framesRejected = stats.framesRejected + 1
    titan.rejected = titan.rejected + 1
    titan.lastReject = reason
    return false, reason
end

-- One controller frame from `player`. Returns true, or false plus a reason token.
-- Cheapest checks first; nothing a rejected frame carries is ever relayed, and a
-- frame that fails never advances the sequence or any dedup cursor.
local function acceptFrame(player, raw)
    local titan = titans[player]
    if not titan then return false, "no_titan" end
    if type(raw) ~= "table" then return reject(titan, "frame_invalid") end
    if raw.id ~= titan.id then return reject(titan, "stale_id") end
    if T.whole(raw.epoch, 1, L.integer) ~= titan.epoch then return reject(titan, "stale_epoch") end
    local seq = T.whole(raw.seq, 1, L.integer)
    if not seq or seq <= titan.seq then return reject(titan, "stale_seq") end
    local now = clock()
    if not T.take(titan.frames, 1, now) then return reject(titan, "rate_limited") end

    local frame, reason, dropped, firstDrop = T.normalizeFrame(raw, catalog)
    if not frame then
        report(titan, "frame", "frame_rejected:" .. reason)
        return reject(titan, reason)
    end
    if frame.t < titan.t then return reject(titan, "stale_time") end
    local size = #json.encode(frame)
    if size > L.frameBytes then
        report(titan, "frame", "frame_rejected:frame_bytes")
        return reject(titan, "frame_bytes")
    end
    if not T.take(titan.bytes, size, now) then return reject(titan, "bandwidth_limited") end

    local admitted, why = motionAdmitted(titan, frame, now)
    if not admitted then
        titan.poseViolations = titan.poseViolations + 1
        report(titan, "pose", "frame_rejected:" .. why)
        reject(titan, why)
        if titan.poseViolations >= L.poseViolations then removeTitan(titan, "pose_rejected") end
        return false, why
    end
    titan.poseViolations = 0

    -- Events: only ones newer than anything this Titan already published, in
    -- order, inside the per-Titan budget. A replayed or rate-dropped event is
    -- consumed (its sequence is behind the cursor) and never delivered later.
    local relayed, cursor = {}, titan.eventSeq
    for _, event in ipairs(frame.events) do
        if event.seq > cursor then
            cursor = event.seq
            if T.take(titan.events, 1, now) then
                relayed[#relayed + 1] = event
            else
                stats.eventsDropped = stats.eventsDropped + 1
            end
        else
            stats.eventsReplayed = stats.eventsReplayed + 1
        end
    end
    titan.eventSeq = cursor
    if dropped and dropped > 0 then
        stats.eventsDropped = stats.eventsDropped + dropped
        report(titan, "items", "event_rejected:" .. tostring(firstDrop))
    end

    local previousMode = titan.mode
    if EXTENDED[frame.mode] and previousMode ~= frame.mode then titan.extendedAt = now end
    titan.seq, titan.t, titan.pose, titan.poseAt = seq, frame.t, frame.pose, now
    titan.mode, titan.weapon, titan.snapshot, titan.lastFrameAt = frame.mode, frame.weapon, frame, now
    if frame.gameplay then titan.gameplay = frame.gameplay end
    -- Dropped out of the fist (or into a call-down/eject) with a body in hand: let go. A thrown body is no longer in the
    -- hand: its flight is the controller's own (FPF.placeFrame runs it whatever BT wields), and the grab key gives the
    -- weapon back during it. Ending the claim then would leave a vehicle where its last sample put it, in the air.
    if titan.carry and ((frame.weapon ~= "fist" and titan.carry.phase ~= "flight") or CARRY_BLOCKED[frame.mode]) then
        releaseCarry(titan, "interrupted")
    end
    titan.accepted = titan.accepted + 1
    stats.framesAccepted = stats.framesAccepted + 1
    if not titan.active then
        titan.active = true
        reply(player, "titan", true, "BT-7274 is up (id " .. titan.id .. ")")
        emit("onTitanReady", player, titan.id, titan.epoch)
    end
    -- V's network body is hidden for everyone else exactly while the Titan is piloted.
    if frame.mode ~= previousMode then
        setHide(player, frame.mode == "pilot")
        setLaunchExempt(player, frame.mode == "pilot")
        if previousMode ~= nil then emit("onTitanModeChanged", player, titan.id, previousMode, frame.mode) end
    end
    -- The owner's own report that its Titan's hull is gone: announced once. The server never infers it, and the Titan
    -- stays until the controller itself deletes the actor (the owner then removes the grant).
    local health = frame.gameplay and frame.gameplay.health
    if health and health.dead == true and not titan.destroyed then
        titan.destroyed = true
        emit("onTitanDestroyed", player, titan.id)
    end

    if next(titan.viewers) ~= nil then
        local message = stateMessage(titan, relayed)
        for viewer in pairs(titan.viewers) do send(viewer, message) end
        stats.eventsRelayed = stats.eventsRelayed + #relayed
    end
    return true
end

local function describe(reason)
    return TEXT[reason] or tostring(reason)
end

-- What the server counted of the reports it acts on, appended to every status answer: a refused blow is a number here, not a
-- silence.
local function countersText()
    return (" cars applied=%d ignored=%d vetoed=%d failed=%d players applied=%d refused=%d ignored=%d"
        .. " npcs observed=%d ignored=%d carry requested=%d granted=%d denied=%d rejected=%d"):format(
        stats.vehicleHitsApplied, stats.vehicleHitsIgnored, stats.vehicleHitsVetoed, stats.vehicleHitsFailed,
        stats.playerHitsApplied, stats.playerHitsRefused, stats.playerHitsIgnored,
        stats.npcHitsObserved, stats.npcHitsIgnored,
        stats.carryRequested, stats.carryGranted, stats.carryDenied, stats.carryRejected)
end

local function statusText(player)
    local titan = titans[player]
    if not titan then return "no Titan" .. countersText() end
    local viewers = 0
    for _ in pairs(titan.viewers) do viewers = viewers + 1 end
    return ("id=%s epoch=%d %s mode=%s weapon=%s held=%s class=%s viewers=%d frames=%d rejected=%d last_reject=%s %s"):format(
        titan.id, titan.epoch, titan.active and "active" or "granted", tostring(titan.mode or "-"),
        tostring(titan.weapon or "-"), tostring(titan.held == true), titan.class and titan.class.id or "-", viewers, titan.accepted,
        titan.rejected, tostring(titan.lastReject or "-"), carryText(titan)) .. countersText()
end

local function commandBucket(player)
    local client = clients[player]
    if not client then
        client = {}
        clients[player] = client
    end
    if not client.commands then client.commands = T.bucket(L.commandBurst, L.commandRate, clock()) end
    return client.commands
end

-- The `/titan action` values the loadout can switch off, with the perk each one needs.
local ACTION_PERK = { grab = "sentry", shoulder = "sentry", core = "burstcore" }

-- The one authorization point for /titan and controller requests. A player can
-- only ever act on their own Titan: the target is never a parameter.
local function execute(player, verb, value, direct)
    if verb == "status" then return true, nil, statusText(player) end
    if not T.take(commandBucket(player), 1, clock()) then return false, "rate_limited" end
    -- The controller's own log, switched on the caller's client: it needs a bridge, not a Titan.
    if verb == "log" then
        if value ~= "on" and value ~= "off" then return false, "invalid_request" end
        if not bridgeReady(player) then return false, "bridge_unavailable" end
        if not send(player, { v = T.protocol, op = "command", action = "log", value = value }) then
            return false, "owner_unavailable"
        end
        return true, nil, "controller log " .. value
    end
    if verb == "spawn" then
        local titan, reason = spawnTitan(player, direct)
        if not titan then return false, reason end
        return true, nil, "BT-7274 granted (id " .. titan.id .. "); waiting for the controller"
    end
    local titan = titans[player]
    if not titan then return false, "no_titan" end
    if verb == "remove" then
        removeTitan(titan, "owner_removed")
        return true, nil, "BT-7274 removed"
    end
    if verb ~= "pilot" and verb ~= "exit" and verb ~= "weapon" and verb ~= "action" and verb ~= "core" then return false, "invalid_request" end
    if not titan.active then return false, "not_active" end
    -- `core` comes only from the restricted titan.core command (/titan never parses it, the `command` export has no vocabulary for
    -- it); it fills the core the BURST CORE perk gives, so the loadout that disabled the perk refuses it like the core key.
    if verb == "core" and titan.loadout.burstcore == 0 then return false, "loadout_disabled" end
    -- A weapon whose perk is 0 cannot be selected: the loadout (a class's, or the one the Titan was spawned with) took it away.
    -- The value is the vocabulary's already (parseCommand, the `command` export).
    if verb == "weapon" then
        local perk = LOADOUT.weaponPerk(value)
        if perk and titan.loadout[perk] == 0 then return false, "loadout_disabled" end
    end
    -- Grabbing is a punch of the fist: refused here with the reason instead of sent to a controller that cannot.
    if verb == "action" then
        local perk = ACTION_PERK[value]
        if perk and titan.loadout[perk] == 0 then return false, "loadout_disabled" end
        if value == "grab" and titan.weapon ~= "fist" then return false, "not_fist" end
    end
    -- A target the platform no longer knows is not a delivered command: never a success the caller could act on.
    if not send(player, { v = T.protocol, op = "command", action = verb, value = value }) then
        return false, "owner_unavailable"
    end
    return true, nil, "sent " .. verb .. (value and (" " .. value) or "")
end

-- ---------------------------------------------------------------------------
-- Periodic upkeep: liveness, ownership and scope.
-- ---------------------------------------------------------------------------
local function inspect(titan, now)
    local read = Open77.players.get(titan.owner)
    if type(read) ~= "table" then return removeTitan(titan, "owner_left") end
    if read.bucket ~= titan.bucket then return removeTitan(titan, "bucket_changed") end
    if ownerDeathEndsTitan(titan) then return removeTitan(titan, "owner_dead") end
    if not titan.active then
        if now - titan.grantedAt > L.firstFrame then
            reply(titan.owner, "titan", false, "the BT controller published nothing for " .. L.firstFrame ..
                " s: check that the client has the BT-7274 package installed and the controller started (client log, [titans] lines)")
            return removeTitan(titan, "controller_timeout")
        end
    elseif now - titan.lastFrameAt > L.stall then
        return removeTitan(titan, "owner_stalled")
    end
    if titan.pendingCount > 0 then settleUnanswered(titan, "timeout", now - L.actionTimeout) end
    if titan.carry then watchCarry(titan, now) end
    reconcile(titan)
end

-- Reads the verdicts of the hits on cars that wait for a script's veto and applies the ones nobody vetoed (see "Blows on cars").
local settleVehicleHits

local function tick()
    local now = clock()
    local list = {}
    for _, titan in pairs(titans) do list[#list + 1] = titan end
    for _, titan in ipairs(list) do inspect(titan, now) end
    local owners = {}
    for owner in pairs(hides) do owners[#owners + 1] = owner end
    for _, owner in ipairs(owners) do pumpHide(owner) end
    settleVehicleHits()
end

-- ---------------------------------------------------------------------------
-- Wire.
-- ---------------------------------------------------------------------------
-- A client announces itself when it starts (a cold start) and, once, in answer to the probe below (`info.answer`). The answer
-- exists for the server-only restart: this run's `clients` is empty while the live clients' controllers are up and announce
-- nothing more. An answer only introduces a client this run has never heard from, as the cold start would: from a client
-- that already has a record it returns here, before anything below runs, so a repeated or late answer never takes the
-- owner_restarted exit and cannot destroy a Titan. (A Titan exists only for a client with a record: an introducing answer meets none.)
RegisterNetEvent(T.event.ready, function(info)
    local player = playerId(source)
    if not player then return end
    local now = clock()
    local client = clients[player]
    if client and type(info) == "table" and info.answer == true then return end
    if not client then
        client = {}
        clients[player] = client
    end
    if client.readyAt and now - client.readyAt < 1 then return end
    client.readyAt = now
    local bridge = type(info) == "table" and info.bridge == true
    client.ready, client.bridge = true, bridge
    client.reason = (not bridge) and (type(info) == "table" and T.bridgeReasons[info.reason] and info.reason
        or "bridge_missing") or nil
    -- A (re)started client lost the controller's state: its previous Titan is gone.
    if titans[player] then removeTitan(titans[player], "owner_restarted") end
    if not bridge then
        reply(player, "titan", false, "BT-7274 is unavailable on this client: " .. BRIDGE_TEXT[client.reason])
        return
    end
    send(player, sessionMessage(player))
    for _, titan in pairs(titans) do reconcile(titan) end
    TriggerClientEvent("chat:addSuggestion", player, "/titan", "Your BT-7274 (own Titan only)", {
        { name = "verb", help = "status | spawn | remove | pilot | exit | weapon | action" },
        { name = "value", help = "weapon: xo16|rail|pred|sword|fist; action: jump|dash|punch|missiles|vortex|smoke|core|eject|view|shoulder|grab" },
    })
end)

-- The host runs the frames that arrived in one tick NEWEST FIRST (the delivery
-- tasks are drained from the tail of the scheduler), so two 20 Hz frames landing
-- together would run as N+1 then N and the strictly increasing sequence would
-- discard N together with its one-shot events. Frames are therefore buffered per
-- owner (bounded) and accepted in sequence order when the host reaches the task
-- scheduled below, i.e. once the whole tick's deliveries have run. Every check,
-- budget and lifecycle rule still applies inside acceptFrame.
local function drainInbox()
    flushing = false
    local owners = {}
    for owner in pairs(inbox) do owners[#owners + 1] = owner end
    for _, owner in ipairs(owners) do
        local queue = inbox[owner]
        inbox[owner] = nil
        table.sort(queue, function(a, b) return a.seq < b.seq end)
        for _, entry in ipairs(queue) do acceptFrame(owner, entry.frame) end
    end
end

RegisterNetEvent(T.event.frame, function(frame)
    local player = playerId(source)
    local titan = player and titans[player]
    if not titan then return end
    local seq = type(frame) == "table" and T.whole(frame.seq, 1, L.integer) or nil
    -- Without a usable sequence there is nothing to order: refuse it at once.
    if not seq then return acceptFrame(player, frame) end
    local queue = inbox[player]
    if not queue then
        queue = {}
        inbox[player] = queue
    end
    if #queue >= L.inbox then return reject(titan, "inbox_full") end
    queue[#queue + 1] = { seq = seq, frame = frame }
    if not flushing then
        flushing = true
        SetTimeout(0, drainInbox)
    end
end)

-- The controller's own call key / its Titan disappearing locally.
RegisterNetEvent(T.event.request, function(action)
    local player = playerId(source)
    if not player then return end
    if type(action) ~= "string" or T.requestActions[action] ~= true then
        return sendError(player, "invalid_request")
    end
    local ok, reason = execute(player, action, nil, false)
    if not ok then
        -- Removing something already gone is not an error worth surfacing.
        if not (action == "remove" and reason == "no_titan") then sendError(player, reason) end
    end
end)

-- The owner's carry stream: its own event so its budget never touches the frames' or
-- the one-shot events'. Everything is bound to the authenticated sender's own Titan.
RegisterNetEvent(T.event.carry, function(raw)
    local player = playerId(source)
    if player then onCarryMessage(player, raw) end
end)

-- The owner's answer to a hit / repair of its own Titan. Only an answer that is well formed, names this Titan and epoch
-- and matches a request still pending of the same kind settles it, and only once: anything else (a duplicate, a late or
-- foreign answer, an unsolicited one) changes nothing. Its own budget; nothing is parsed while nothing is pending.
RegisterNetEvent(T.event.result, function(raw)
    local player = playerId(source)
    local titan = player and titans[player]
    if not titan then return end
    if titan.pendingCount == 0 or not T.take(titan.results, 1, clock()) then
        stats.actionsIgnored = stats.actionsIgnored + 1
        return
    end
    local result = T.normalizeGameplayResult(raw)
    local entry = result and result.id == titan.id and result.epoch == titan.epoch and titan.pending[result.request] or nil
    if not entry or entry.kind ~= result.kind then
        stats.actionsIgnored = stats.actionsIgnored + 1
        return
    end
    stats.actionsAnswered = stats.actionsAnswered + 1
    settle(titan, result.request, result.ok, result.reason, result.amount)
end)

-- ---------------------------------------------------------------------------
-- Observed hits and status effects. The owner's controller renders every other player's Titan from relayed states and
-- notices when ITS Titan's weapons land on one (hit_observed) or when its own calls would apply a status effect to one
-- (status_observed: shared.lua T.normalizeHitObserved / T.normalizeStatusObserved), each through its own event and ONE budget
-- and ONE sequence per source Titan (the blows on cars below share both). The report is the owner's word: an observation, not a
-- collision the server measured and not anti-cheat. What the server does is authenticate and bound it, then publish it ONCE as
-- the host event
--   onTitanHitObserved(sourceOwner, sourceTitanId, targetOwner, targetTitanId, report)
--   onTitanStatusObserved(sourceOwner, sourceTitanId, targetOwner, targetTitanId, report)
-- (owners are player numbers, Titan ids text; report = { target = { kind = 'titan', id, epoch, owner (number) }, seq, and
-- for a hit record, origin, point, direction, kind, scale; for a status effect effect and, only when the controller's call
-- supplied one, duration }, a detached copy). Nothing else happens: no damage, no `hit` dispatch, no status effect, no
-- team, friendly-fire, weapon or price rule. A mission script that wants a hit to count checks its own policy and calls
-- the `hit` export on targetOwner, and one that wants a status effect to take hold does it itself. Accepted only when, in
-- this order:
--   * the sender has a Titan and its observation budget (the event rate, a bucket of its own) has a token: nothing is parsed before;
--   * the report is well formed (the closed schema) and names the sender's OWN current Titan id and epoch, which has
--     published an accepted controller frame (a Titan that is only granted observes nothing);
--   * its `seq` is new: a repeat, or one older than the window of the newest hitWindow numbers, is ignored (reports of
--     one tick arrive newest-first, so strict ordering would lose the older ones). Hits and status effects are numbered
--     together by the controller, so the window remembers both kinds;
--   * the target is another player's current Titan, exactly by id, epoch and owner, that has published, and the sender
--     is in that Titan's viewer set (the players the platform streams its owner to, with a working bridge): a Titan the
--     sender cannot see cannot be named.
-- A report that fails any of them changes nothing and is never published. A malformed one is also reported back to its
-- owner as an error (rate limited, like every refused frame); a stale, repeated, foreign or over-budget one is only counted.
-- ---------------------------------------------------------------------------
local OBSERVED = {
    hit = {
        normalize = T.normalizeHitObserved, key = "hit-wire", token = "hit_rejected:",
        ignored = "hitsIgnored", rejected = "hitsRejected",
    },
    status = {
        normalize = T.normalizeStatusObserved, key = "status-wire", token = "status_rejected:",
        ignored = "statusIgnored", rejected = "statusRejected",
    },
    vehicle = {
        normalize = T.normalizeVehicleHit, key = "vehicle-wire", token = "vehicle_hit_rejected:",
        ignored = "vehicleHitsIgnored", rejected = "vehicleHitsRejected", prefix = "car hit ignored: ",
    },
    player = {
        normalize = T.normalizePlayerHit, key = "player-wire", token = "player_hit_rejected:",
        ignored = "playerHitsIgnored", rejected = "playerHitsRejected", prefix = "player hit refused: ",
    },
    npc = {
        normalize = T.normalizeNpcHit, key = "npc-wire", token = "npc_hit_rejected:",
        ignored = "npcHitsIgnored", rejected = "npcHitsRejected", prefix = "npc hit ignored: ",
    },
}

-- An observation that is dropped is counted, and for the kinds that act on a car or a player (`prefix`) it also says why in the
-- log, once per reason.
local function ignoreObserved(kind, reason)
    stats[kind.ignored] = stats[kind.ignored] + 1
    if kind.prefix then logOnce(kind.prefix .. reason, kind.prefix .. reason) end
end

-- The part of the admission every observation shares. Returns the source Titan and the normalized message, or nothing; the
-- sequence number is not used up here (`remember` does that, once the caller's own checks held).
local function admitSource(player, raw, kind)
    local titan = titans[player]
    if not titan then return end
    if not T.take(titan.observed, 1, clock()) then return ignoreObserved(kind, "budget") end
    local wire, reason = kind.normalize(raw)
    if not wire then
        stats[kind.rejected] = stats[kind.rejected] + 1
        report(titan, kind.key, kind.token .. reason)
        return
    end
    if wire.id ~= titan.id or wire.epoch ~= titan.epoch or not titan.active then return ignoreObserved(kind, "stale_titan") end
    if wire.seq <= titan.hitHigh - L.hitWindow or titan.hitSeen[wire.seq % L.hitWindow] == wire.seq then
        return ignoreObserved(kind, "replay")
    end
    return titan, wire
end

local function remember(titan, wire)
    titan.hitSeen[wire.seq % L.hitWindow] = wire.seq
    if wire.seq > titan.hitHigh then titan.hitHigh = wire.seq end
end

-- The one admission of an observation of a Titan, hit or status effect. Returns the source Titan, the target Titan and the
-- normalized message, or nothing; the sequence number is used up only when every check held.
local function admitObserved(player, raw, kind)
    local titan, wire = admitSource(player, raw, kind)
    if not titan then return end
    local targetOwner = playerId(wire.target.owner)
    local target = targetOwner and titans[targetOwner]
    if not target or target == titan or target.id ~= wire.target.id or target.epoch ~= wire.target.epoch
        or not target.active or target.viewers[player] ~= true then
        stats[kind.ignored] = stats[kind.ignored] + 1
        return
    end
    remember(titan, wire)
    return titan, target, wire
end

local function onHitObserved(player, raw)
    local titan, target, wire = admitObserved(player, raw, OBSERVED.hit)
    if not titan then return end
    stats.hitsObserved = stats.hitsObserved + 1
    emit("onTitanHitObserved", player, titan.id, target.owner, target.id, {
        target = { kind = "titan", id = target.id, epoch = target.epoch, owner = target.owner },
        record = wire.record, origin = wire.origin, point = wire.point, direction = wire.direction,
        kind = wire.kind, scale = wire.scale, seq = wire.seq,
    })
end

local function onStatusObserved(player, raw)
    local titan, target, wire = admitObserved(player, raw, OBSERVED.status)
    if not titan then return end
    stats.statusObserved = stats.statusObserved + 1
    emit("onTitanStatusObserved", player, titan.id, target.owner, target.id, {
        target = { kind = "titan", id = target.id, epoch = target.epoch, owner = target.owner },
        effect = wire.effect, duration = wire.duration, seq = wire.seq,
    })
end

RegisterNetEvent(T.event.hit, function(raw)
    local player = playerId(source)
    if player then onHitObserved(player, raw) end
end)

RegisterNetEvent(T.event.status, function(raw)
    local player = playerId(source)
    if player then onStatusObserved(player, raw) end
end)

-- ---------------------------------------------------------------------------
-- Blows on cars. A car's health is the canonical ledger's and nothing else sticks on it (a client resets a car's local damage to
-- it), so what the owner's controller takes off a car cannot stay a local effect: it reports it (vehicle_hit, shared.lua
-- T.normalizeVehicleHit: the car's canonical id, the percentage of its full health taken off since the last report, where
-- the car was) on its own event, under the same budget and the same per-source sequence as the observations above, and the
-- server acts on it. The report is the owner's word, so what the server does is authenticate and bound it before it touches
-- the car, and let scripts decide. Admitted only when, in this order:
--   * the sender, its budget, the report's schema, its own current Titan and epoch (which has published) and a new `seq`:
--     exactly as an observation (admitSource);
--   * the car exists in the platform's ledger (Open77.vehicles.get), is neither destroyed nor exploded nor at zero health,
--     is in the sender's routing bucket and within limits.vehicleReach of the Titan's latest accepted pose (the car's place
--     is the server's own read, never the report's `point`);
--   * fewer than limits.vehiclePending hits are waiting for a verdict.
-- A report that fails any of them changes nothing, is never published and uses no sequence number; a malformed one is also
-- reported back to its owner (rate limited), the rest are only counted. An admitted one is published ONCE with
-- TriggerCancellableEvent as
--   onTitanVehicleHit(sourceOwner, sourceTitanId, vehicleId, report)
-- (owner a player number, Titan id text, vehicleId the car's canonical id as a number; report = { share, point, seq, health }, a
-- detached copy: the percentage taken off, where the car was, the sender's count and the car's health, 0..1, BEFORE the hit). A
-- handler vetoes it with CancelEvent(): nothing happens to the car then. The verdict settles one host tick later and is read
-- by the next report and by the upkeep; a hit nobody vetoed is applied to the car as it is THEN (it may have changed while the
-- verdict was pending; a car that is gone or destroyed is left alone): its health becomes health - share / 100, or, when that
-- leaves it at VEHICLE_DEAD or less, the car is exploded (terminal, replicated with its blast to every client). A verdict that
-- never settles in limits.vehicleVerdict seconds applies nothing. Nothing here knows about teams, friendly fire or price: that
-- is what the veto is for.
-- ---------------------------------------------------------------------------
local VEHICLE_DEAD = 0.005      -- health at or below which a hit blows the car up instead of leaving it a sliver
local pendingHits = {}          -- hits waiting for the verdict of their onTitanVehicleHit: { verdict, vehicle, share, at }

local function applyVehicleHit(hit)
    local car = readTarget("vehicle", hit.vehicle)
    if not car or not car.alive or not T.finite(car.health) or car.health <= 0 then
        stats.vehicleHitsIgnored = stats.vehicleHitsIgnored + 1
        return
    end
    local health = car.health - hit.share / 100
    local ok, why
    if health <= VEHICLE_DEAD then
        ok, why = core("vehicle", "explode", hit.vehicle)
    else
        ok, why = core("vehicle", "setHealth", hit.vehicle, health)
    end
    if ok == true then
        stats.vehicleHitsApplied = stats.vehicleHitsApplied + 1
    else
        stats.vehicleHitsFailed = stats.vehicleHitsFailed + 1
        print(("[titans] a hit on vehicle %d was not applied: %s"):format(hit.vehicle, tostring(why)))
    end
end

-- Reads the verdict of every waiting hit: a veto drops it, a verdict that is not one (lost, expired, never settled) applies
-- nothing, a settled hit nobody vetoed is applied. Hits whose verdict is still pending wait.
function settleVehicleHits()
    if #pendingHits == 0 then return end
    local now, waiting = clock(), {}
    for _, hit in ipairs(pendingHits) do
        local ok, canceled, status = pcall(function() return hit.verdict:canceled() end)
        if ok and canceled == nil and status == "pending" and now - hit.at <= L.vehicleVerdict then
            waiting[#waiting + 1] = hit
        elseif ok and canceled == true then
            stats.vehicleHitsVetoed = stats.vehicleHitsVetoed + 1
        elseif ok and canceled == false then
            applyVehicleHit(hit)
        else
            stats.vehicleHitsFailed = stats.vehicleHitsFailed + 1
        end
    end
    pendingHits = waiting
end

local function onVehicleHit(player, raw)
    settleVehicleHits()
    local titan, wire = admitSource(player, raw, OBSERVED.vehicle)
    if not titan then return end
    local id = math.tointeger(tonumber(wire.vehicle))
    local car = id and readTarget("vehicle", id)
    local pose = titan.pose
    local why
    if not car then why = "unknown_target"
    elseif not car.alive or not T.finite(car.health) or car.health <= 0 then why = "wreck"
    elseif car.bucket ~= titan.bucket then why = "bucket"
    elseif not pose or distance(car, pose) > L.vehicleReach then why = "out_of_reach"
    elseif #pendingHits >= L.vehiclePending then why = "pending_full" end
    if why then return ignoreObserved(OBSERVED.vehicle, why) end
    remember(titan, wire)
    local verdict = emitCancellable("onTitanVehicleHit", player, titan.id, id, {
        share = wire.share, point = wire.point, seq = wire.seq, health = car.health,
    })
    if not verdict then
        stats.vehicleHitsFailed = stats.vehicleHitsFailed + 1
        return
    end
    stats.vehicleHitsObserved = stats.vehicleHitsObserved + 1
    pendingHits[#pendingHits + 1] = { verdict = verdict, vehicle = id, share = wire.share, at = clock() }
end

RegisterNetEvent(T.event.vehicle, function(raw)
    local player = playerId(source)
    if player then onVehicleHit(player, raw) end
end)

-- ---------------------------------------------------------------------------
-- Blows on players. Only the server's health ledger counts on a player, so what the owner's controller's weapons land on another
-- player's body cannot stay a local effect: the owner reports each blow (player_hit, shared.lua T.normalizePlayerHit: the
-- victim's player id, the authored attack record, how many blows of it the bridge summed over a short window) on its own event,
-- under the same budget and per-source sequence as the reports above. The record names the blow and nothing else: the AMOUNT
-- is this server's, priced per record below (a mission changes it with the setPlayerDamage export), so a report asks for no
-- more than its count of already-priced blows. Admitted only when, in this order:
--   * the sender, its budget, the schema, its own current Titan and epoch (which has published) and a new `seq`: exactly as an
--     observation (admitSource);
--   * the victim is another player (never the owner), alive, in the sender's routing bucket and within limits.playerReach of
--     the Titan's latest accepted pose (the victim's place is the server's own read, never the report's);
--   * the record has a price above 0.
-- A report that fails any of them changes nothing and uses no sequence number. An admitted one is applied with
-- Open77.players.damage under pvp = true: the platform's own PvP rules (the same combat bucket, combat scope, friendly fire,
-- team, the damage multipliers and every Open77.combat.onDamage arbiter) decide, and a refusal is counted and logged once.
-- ---------------------------------------------------------------------------
local PLAYER_DAMAGE_MAX = 300   -- the platform's own ceiling on one scripted blow (Open77.players.damage clamps to it)
local PLAYER_DAMAGE = {}        -- [attack record] = { amount, kind }: what ONE blow of that record takes off a player

local function price(amount, kind, ...)
    for _, record in ipairs({ ... }) do PLAYER_DAMAGE[record] = { amount = amount, kind = kind } end
end
price(8, "ranged", "Attacks.BT7274_XO16_Hit", "Attacks.BT7274_Pred_Hit", "Attacks.ExplosionSmall", "Attacks.BT7274_Vortex",
    "Attacks.BT7274_Vortex_x2", "Attacks.BT7274_Vortex_x4", "Attacks.BT7274_Vortex_x8", "Attacks.BT7274_Vortex_x16",
    "Attacks.BT7274_Vortex_x32", "Attacks.BT7274_Vortex_x64")
price(25, "ranged", "Attacks.BT7274_Rail_1")
price(50, "ranged", "Attacks.BT7274_Rail_2")
price(75, "ranged", "Attacks.BT7274_Rail_3")
price(100, "ranged", "Attacks.BT7274_Rail_4")
price(35, "explosion", "Attacks.BT7274_Missile", "Attacks.BT7274_FlightRocket")
price(15, "explosion", "Attacks.BT7274_MissileBlast", "Attacks.BT7274_FlightBlast", "Attacks.BT7274_Fist_Blast")
price(60, "melee", "Attacks.BT7274_Punch", "Attacks.BT7274_Fist", "Attacks.BT7274_Fist_Heavy", "Attacks.BT7274_Fist_Charged",
    "Attacks.BT7274_Fist_Core", "Attacks.BT7274_Sword", "Attacks.BT7274_Sword_Core", "Attacks.BT7274_Sword_Charged",
    "Attacks.BT7274_ArcWave")
price(40, "explosion", "Attacks.BT7274_Pound_Mid", "Attacks.BT7274_Pound_Edge")
price(100, "explosion", "Attacks.BT7274_Eject")
price(2, "explosion", "Attacks.BT7274_Smoke", "Attacks.BT7274_Gas")

local function onPlayerHit(player, raw)
    local titan, wire = admitSource(player, raw, OBSERVED.player)
    if not titan then return end
    local kind = OBSERVED.player
    local victim = playerId(wire.player)
    if not victim then return ignoreObserved(kind, "unknown_target") end
    if victim == titan.owner then return ignoreObserved(kind, "self") end
    local read = Open77.players.get(victim)
    if type(read) ~= "table" then return ignoreObserved(kind, "unknown_target") end
    if read.dead == true then return ignoreObserved(kind, "dead") end
    if read.bucket ~= titan.bucket then return ignoreObserved(kind, "bucket") end
    local at, pose = read.position, titan.pose
    if not pose or type(at) ~= "table" or not (T.finite(at.x) and T.finite(at.y) and T.finite(at.z))
        or distance(at, pose) > L.playerReach then
        return ignoreObserved(kind, "out_of_reach")
    end
    local priced = PLAYER_DAMAGE[wire.record]
    if not priced or priced.amount <= 0 then return ignoreObserved(kind, "no_price:" .. wire.record) end
    remember(titan, wire)
    stats.playerHitsObserved = stats.playerHitsObserved + 1
    local ok, applied, why = pcall(Open77.players.damage, victim, priced.amount * wire.count,
        { attacker = titan.owner, cause = priced.kind, pvp = true })
    if ok and applied == true then
        stats.playerHitsApplied = stats.playerHitsApplied + 1
    else
        stats.playerHitsRefused = stats.playerHitsRefused + 1
        local refusal = tostring(ok and why or applied)
        logOnce(kind.prefix .. refusal, kind.prefix .. refusal)
    end
end

RegisterNetEvent(T.event.player, function(raw)
    local player = playerId(source)
    if player then onPlayerHit(player, raw) end
end)

-- ---------------------------------------------------------------------------
-- Blows on NPCs. An NPC is the platform's body (a mission or another resource created it) and its health the platform's, so the
-- server of this resource neither owns nor touches it. What the owner's controller's weapons land on one is reported
-- (npc_hit, shared.lua T.normalizeNpcHit: the NPC's platform id, the attack record, the kind of blow and where it landed) on
-- its own event, under the same budget and per-source sequence as the reports above, and published for the mission that
-- owns the NPC to validate and price. A report asks for no amount. Admitted only when, in this order:
--   * the sender, its budget, the schema, its own current Titan and epoch (which has published) and a new `seq`: exactly as an
--     observation (admitSource);
--   * the Titan has a latest accepted pose (the mission measures the NPC against it);
--   * a `round` finds a token in the bucket of its NPC (limits.npcRoundGap, npcRoundBurst): the sustained rate on one NPC is at
--     most one round per 50 ms, whatever the controller sends. Every other kind is its own blow and has no bucket.
-- A report that fails any of them changes nothing, is never published and uses no sequence number; a malformed one is also
-- reported back to its owner (rate limited), the rest are only counted. An admitted one is published ONCE with TriggerEvent as
--   onTitanNpcHit(owner, titanId, npcId, info)
-- (owner a player number, Titan id and NPC id text, as every NPC event names the NPC; info = { record, kind, point = { x, y, z },
-- titan = { x, y, z }, at }, a detached copy: the attack record, round | blast | melee | blade | other, where the controller says
-- the blow landed, the Titan's latest accepted pose, and the server's monotonic clock in seconds). Nothing else happens: the NPC
-- is not read, so whether it exists, is hostile, is alive, stands in the sender's bucket or within reach of the Titan, and what
-- the blow is worth, are the listening mission's to decide from its own records. The point is the owner's word and the Titan's
-- pose the server's own.
-- ---------------------------------------------------------------------------
-- Whether a round on `npc` may go on: the bucket of that NPC, made on its first round. A full table makes room by forgetting the
-- buckets that have refilled (they would answer the same as a new one); one that cannot refuses the round.
local function npcRoundAllowed(titan, npc, at)
    local bucket = titan.npcRounds[npc]
    if not bucket then
        if titan.npcRoundN >= L.npcRoundKeys then
            for key, held in pairs(titan.npcRounds) do
                if at - held.at >= L.npcRoundBurst * L.npcRoundGap then
                    titan.npcRounds[key] = nil
                    titan.npcRoundN = titan.npcRoundN - 1
                end
            end
            if titan.npcRoundN >= L.npcRoundKeys then return false end
        end
        bucket = T.bucket(L.npcRoundBurst, 1 / L.npcRoundGap, at)
        titan.npcRounds[npc] = bucket
        titan.npcRoundN = titan.npcRoundN + 1
    end
    return T.take(bucket, 1, at)
end

local function onNpcHit(player, raw)
    local titan, wire = admitSource(player, raw, OBSERVED.npc)
    if not titan then return end
    local kind = OBSERVED.npc
    -- Only a Titan its owner pilots lands priced blows: the owner's accepted frames say `pilot` (a BT on its own, a granted
    -- Titan or a held one reports nothing a mission may pay for).
    if titan.mode ~= "pilot" then return ignoreObserved(kind, "not_piloting") end
    if titan.held == true then return ignoreObserved(kind, "held") end
    local pose = titan.pose
    if not pose then return ignoreObserved(kind, "no_pose") end
    local at = clock()
    if wire.kind == "round" and not npcRoundAllowed(titan, wire.npc, at) then return ignoreObserved(kind, "round_rate") end
    remember(titan, wire)
    stats.npcHitsObserved = stats.npcHitsObserved + 1
    emit("onTitanNpcHit", player, titan.id, wire.npc, {
        record = wire.record, kind = wire.kind, point = wire.point,
        titan = { x = pose.x, y = pose.y, z = pose.z }, at = at,
    })
end

RegisterNetEvent(T.event.npc, function(raw)
    local player = playerId(source)
    if player then onNpcHit(player, raw) end
end)

-- The platform's word on claims of this resource (ids and tokens as text), and the
-- registries' removal and death of a body that may be in a hand.
AddEventHandler("onNpcCarryEnded", function(id, token, reason) platformEnded("npc", id, token, reason, true) end)
AddEventHandler("onVehicleCarryEnded", function(id, token, reason) platformEnded("vehicle", id, token, reason, true) end)
AddEventHandler("onNpcRemoved", function(id) platformEnded("npc", id, nil, "entity_removed", false) end)
AddEventHandler("onNpcDied", function(id) platformEnded("npc", id, nil, "entity_died", false) end)
AddEventHandler("onVehicleRemoved", function(id) platformEnded("vehicle", id, nil, "entity_removed", false) end)

RegisterCommand("titan", function(caller, args, raw)
    local player = playerId(caller)
    if not player then
        print("[titans] /titan acts on the caller's own Titan; run it from a player")
        return
    end
    local verb, value = T.parseCommand(args)
    if not verb then return reply(player, raw, false, value) end
    local ok, reason, text = execute(player, verb, value, true)
    if ok then reply(player, raw, true, text) else reply(player, raw, false, describe(reason)) end
end, false)

-- Filling the BURST CORE is a cheat in PvP, so it is a command of its own and never a /titan verb anyone can type. Restricted
-- (RegisterCommand's third argument): the platform checks the ACL right `command.titan.core` before this runs and the server
-- console is always allowed, so there is no rights check in this file. A player fills their own Titan's core; the console names
-- the player, because it has no Titan of its own. Admission is execute's (a Titan, its first frame, the BURST CORE perk).
RegisterCommand("titan.core", function(caller, args, raw)
    local count = type(args) == "table" and (args.n or #args) or 0
    local player = playerId(caller)
    local target = player
    if player then
        if count ~= 0 then return reply(player, raw, false, "usage: /titan.core") end
    else
        target = count == 1 and playerId(args[1]) or nil
        if not target then
            print("[titan] usage: titan.core <player id>")
            return
        end
        -- execute would make a command budget for any number; a player without a Titan is answered here instead.
        if not titans[target] then
            print("[titan] player " .. target .. " has no Titan")
            return
        end
    end
    local ok, reason, text = execute(target, "core", nil, true)
    if ok then reply(target, raw, true, text) else reply(target, raw, false, describe(reason)) end
end, true)

AddEventHandler("onPlayerDisconnected", function(id)
    local player = playerId(id)
    if not player then return end
    local titan = titans[player]
    if titan then removeTitan(titan, "owner_left") end
    clients[player] = nil
    hides[player] = nil
    inbox[player] = nil
    for _, other in pairs(titans) do other.viewers[player] = nil end
end)

AddEventHandler("onPlayerBucketChange", function(id, bucket)
    local player = playerId(id)
    local titan = player and titans[player]
    if titan and tonumber(bucket) ~= titan.bucket then removeTitan(titan, "bucket_changed") end
end)

AddEventHandler("onPlayerLifeStateChanged", function(id, _, phase)
    local player = playerId(id)
    local titan = player and titans[player]
    if titan and phase ~= "alive" and phase ~= "recovering" and ownerDeathEndsTitan(titan) then
        removeTitan(titan, "owner_dead")
    end
end)

local function scopeChanged(subject)
    local player = playerId(subject)
    local titan = player and titans[player]
    if titan then reconcile(titan) end
end
AddEventHandler("onPlayerEnteredScope", scopeChanged)
AddEventHandler("onPlayerLeftScope", scopeChanged)

-- Once, when this resource starts (its own VM gets onResourceStart after every script has run, so every handler above is
-- registered): ask every connected client to say whether its bridge is up. A client that was already running announces
-- itself only at ITS start, so after a server-only restart this run would know none of them and refuse every spawn as
-- bridge_unavailable. Clients that start later announce themselves. Nothing is retried and nothing is granted by it.
AddEventHandler("onResourceStart", function(name)
    if name ~= RESOURCE then return end
    local sent, why = TriggerClientEvent(T.event.probe, -1)
    if sent == false then print("[titans] readiness probe not sent: " .. tostring(why)) end
end)

AddEventHandler("onResourceStop", function(name)
    if name ~= RESOURCE then return end
    running = false
    local list = {}
    for _, titan in pairs(titans) do list[#list + 1] = titan end
    for _, titan in ipairs(list) do removeTitan(titan, "resource_stopped") end
    for player in pairs(clients) do
        if bridgeReady(player) then
            send(player, { v = T.protocol, op = "session", active = false, player = tostring(player) })
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Server exports: the one door through which server Lua controls a Titan: its life, loadout and
-- controls, and reads what the server holds of it.
-- `exports.op77_lightrp_titans:<name>(...)` (or Open77.exports.call) from another server
-- resource; a server-only registry, never a client RPC, a net event or a command. The
-- player is always a plain number the caller supplies (never `source`, text or a name),
-- every argument is validated before anything changes, and nothing returned aliases the
-- Titan's record. Each one answers a value, or nil plus a reason token.
--   getLoadoutSpec()             -> { [perk] = highest level } for every authored perk
--   spawn(player, overrides?, options?) -> Titan id (text); every perk at its maximum unless `overrides`
--                                   ({ [perk] = level }, validated sparse over the defaults) lowers it; `options` is nil or
--                                   { piloted?, hold? } (booleans, anything else is nil, invalid_options): `piloted` puts BT on
--                                   the ground at the owner's own place and heading and seats V at once (no call-down, no
--                                   cooldown, no sky check), `hold` starts the Titan held
--   remove(player)               -> true
--   getLoadout(player)           -> the Titan's complete { [perk] = level } map
--   setLoadout(player, changes)  -> the new complete map; `changes` is a sparse { [perk] = level };
--                                   the owner's controller is sent the whole map under a newer revision
--   command(player, action, value?) -> true once the command was dispatched to the owner's controller (the
--                                   controller has not necessarily run it, let alone finished its animation);
--                                   `action` is pilot | exit | weapon | action, exactly the /titan verbs of the
--                                   same name, with the same value vocabulary and the same admission
--   input(player, name, value)   -> true once the control was dispatched to the owner's piloted controller; `name` is
--                                   one of shared.lua's T.inputs (the game's MoveX MoveY CameraX CameraY axes -1..1,
--                                   CameraMouseX / CameraMouseY relative steps within +/-20000 raw units, Forward Back
--                                   Left Right Sprint ToggleSprint Jump Dodge RangedAttack Reload QuickMelee RangedADS
--                                   CameraAim and the mod's jump dash punch missiles vortex smoke core view shoulder
--                                   sentry designate flight as true = press / false = release); no chat budget is spent
--   releaseInput(player)         -> true once the owner's controller was told to let go of every control a script held
--   hit(player, request)         -> request number once a hit was dispatched to the owner's controller; `request` is exactly
--                                   { record, origin = {x,y,z}, direction = {x,y,z}, attacker?, kind, scale? } (below)
--   repair(player, amount)       -> request number once a hull repair was dispatched; hull only, never a revival
--   creditCore(player, request)  -> request number once a core credit was dispatched to the player's own controller;
--                                   `request` is exactly { target = { id = text, epoch }, record, killing = boolean } (below)
--   setHold(player, held)        -> true; held = no movement, fire, reload, ability, melee, weapon switch, disembark or eject
--                                   from the owner's controller (the camera still looks around), released with false;
--                                   idempotent; false, invalid_player | invalid_value | no_titan | bridge_unavailable
--   setClass(player, spec?)      -> true; `spec` is { id, label, weapon, perks?, abilities, speed?, harm?, regen? } (below);
--                                   applied in one step by the owner's controller: the loadout, the ability lock, the speed, the
--                                   damage multiple, the shield's regeneration multiple and the weapon; nil clears it (default
--                                   loadout, everything allowed, speed, harm and regen 1); false, invalid_player | invalid_class |
--                                   invalid_id | invalid_label | invalid_weapon | invalid_abilities | invalid_speed | invalid_harm |
--                                   invalid_regen |
--                                   loadout_* | no_titan | bridge_unavailable
--   creditKill(player, rank)     -> true once a kill's core charge was dispatched to the player's own controller; `rank` is
--                                   "grunt" | "rare" | "heavy"; false, invalid_player | invalid_value | no_titan | bridge_unavailable
--   getState(player)             -> a detached snapshot of what the server accepted and recorded for the Titan (below)
--   setPlayerDamage(record, amount) -> true; what ONE blow of an attack record takes off a PLAYER (a finite 0..300, 0 turns the
--                                   record off); a bad record or amount is false, invalid_record | invalid_amount
--   playerDamage(record)         -> the price of a record, or nil when nothing prices it (below, "Blows on players")
--   setTitanPvp(enabled)         -> true; whether a Titan's auto-targeting may take another player's Titan or body for a foe
--                                   (off by default; every bridge client is sent the value at its session start and on each
--                                   change); false, invalid_value unless `enabled` is a boolean
--   titanPvp()                   -> that flag, a boolean
-- Host events (TriggerEvent, to every server resource; owner is the player number, ids are text): onTitanCreated(owner, id,
-- epoch) when the grant exists, onTitanReady(owner, id, epoch) at the first accepted frame, onTitanModeChanged(owner, id,
-- old, new) at an accepted change of the reported mode, onTitanDestroyed(owner, id) once, at the first accepted report that
-- the hull is dead, onTitanActionResult(owner, id, request, kind, ok, reason, amount) once per hit / repair / core credit,
-- onTitanHitObserved(sourceOwner, sourceId, targetOwner, targetId, report) once per accepted observation that the source's
-- controller made of its Titan landing a blow on the target's, onTitanStatusObserved(sourceOwner, sourceId, targetOwner,
-- targetId, report) once per accepted observation of a status effect its controller's own calls would apply to the target's
-- (both untrusted and never applied: see "Observed hits and status effects"), onTitanVehicleHit(sourceOwner, sourceId, vehicleId,
-- report) once per accepted report that the source's controller took a share off a canonical car (the one cancellable event: a
-- handler's CancelEvent() keeps the car as it is, and otherwise the server applies the share to the car's health; see "Blows on
-- cars"), onTitanNpcHit(sourceOwner, sourceId, npcId, info) once per accepted report that the source's controller landed a blow on
-- an NPC the platform owns (untrusted and never applied here: the mission that owns the NPC validates and prices it; see "Blows on
-- NPCs"), and onTitanRemoved(owner, id, reason) whenever the Titan ends.
-- ---------------------------------------------------------------------------
local function exportPlayer(value)
    if type(value) ~= "number" then return nil end
    return playerId(value)
end

local function exportReason(reason)
    return type(reason) == "string" and reason or "loadout_invalid"
end

local function exportTitan(value)
    local player = exportPlayer(value)
    if not player then return nil, "invalid_player" end
    local titan = titans[player]
    if not titan then return nil, "no_titan" end
    return titan
end

local function publish(name, fn)
    local ok, why = exports(name, fn)
    if not ok then print(("[titans] export %s was not published: %s"):format(name, tostring(why))) end
end

publish("getLoadoutSpec", function() return copyLoadout(LOADOUT.max) end)

publish("spawn", function(player, overrides, options)
    local id = exportPlayer(player)
    if not id then return nil, "invalid_player" end
    local loadout, why = LOADOUT.patch(LOADOUT.defaults(), overrides == nil and {} or overrides)
    if not loadout then return nil, exportReason(why) end
    local clean, bad = T.normalizeSpawnOptions(options)
    if not clean then return nil, bad end
    local titan, reason = spawnTitan(id, true, loadout, clean)
    if not titan then return nil, reason end
    return titan.id
end)

publish("remove", function(player)
    local titan, reason = exportTitan(player)
    if not titan then return nil, reason end
    removeTitan(titan, "owner_removed")
    return true
end)

publish("getLoadout", function(player)
    local titan, reason = exportTitan(player)
    if not titan then return nil, reason end
    return copyLoadout(titan.loadout)
end)

publish("setLoadout", function(player, changes)
    local titan, reason = exportTitan(player)
    if not titan then return nil, reason end
    if not bridgeReady(titan.owner) then return nil, "bridge_unavailable" end
    local loadout, why = LOADOUT.patch(titan.loadout, changes)
    if not loadout then return nil, exportReason(why) end
    local revision = titan.revision + 1
    -- The owner must be told before the record moves: a target that is gone changes nothing.
    if not send(titan.owner, { v = T.protocol, op = "loadout", id = titan.id, epoch = titan.epoch,
        revision = revision, loadout = copyLoadout(loadout) }) then
        return nil, "owner_unavailable"
    end
    titan.loadout, titan.revision = loadout, revision
    print(("[titans] loadout of Titan %s of player %d is now revision %d"):format(titan.id, titan.owner, revision))
    -- Without the sentry perk a body in the fist (granted, or still waiting for its first sample) is let go.
    if loadout.sentry == 0 then releaseCarry(titan, "interrupted") end
    return copyLoadout(loadout)
end)

-- command: the /titan controls that act on a live controller, dispatched for a player number. The vocabulary is
-- shared.lua's (T.commandActions with T.weapons / T.actions), exact and case-sensitive, and only these four verbs:
-- spawn/remove/setLoadout are their own exports, and nothing else (no event, function or free text) is ever
-- dispatched. `false` means the verb takes no value. Validation touches nothing, spends no command budget and
-- sends nothing; admission (rate, an active controller, the fist for a grab, the loadout) is execute's.
local CONTROL_VALUES = { pilot = false, exit = false, weapon = T.weapons, action = T.actions }

publish("command", function(player, verb, value)
    local id = exportPlayer(player)
    if not id then return nil, "invalid_player" end
    if type(verb) ~= "string" or T.commandActions[verb] ~= true or CONTROL_VALUES[verb] == nil then
        return nil, "invalid_command"
    end
    local vocabulary = CONTROL_VALUES[verb]
    if vocabulary then
        if type(value) ~= "string" or vocabulary[value] ~= true then return nil, "invalid_value" end
    elseif value ~= nil then
        return nil, "invalid_value"
    end
    -- Before execute, which would allocate a rate budget for any number a script names.
    if not titans[id] then return nil, "no_titan" end
    local ok, reason = execute(id, verb, value, false)
    if not ok then return nil, reason end
    return true
end)

-- input / releaseInput: held and analog controls of a piloted Titan, for a trusted server resource only (never a
-- client message, and no budget of the player's /titan commands: a script drives a control every tick, as setLoadout
-- is trusted to be called). The vocabulary is shared.lua's T.inputs: the game's actions, axes and relative mouse
-- steps the controller already consumes, and the BT-7274 mod's pilot keys; a bad name or value is refused before
-- anything is looked up or sent. Admission is the Titan's: it exists (no_titan), its controller published
-- (not_active) and it is being piloted by the last accepted frame's mode (not_piloting). The message names the
-- Titan's id and epoch, so a controller holding another Titan ignores it; what the controller does with it (its
-- pause and camera gates, the controller's own debounce) is not known here, so true is dispatch, not effect.
-- releaseInput lets go of everything a script held, in any mode of an active Titan.
local INPUT_REASON = { input_name = "invalid_input", input_value = "invalid_value" }

publish("input", function(player, name, value)
    local id = exportPlayer(player)
    if not id then return nil, "invalid_player" end
    local key, reasonOrKind = T.normalizeInput(name, value)
    if not key then return nil, INPUT_REASON[reasonOrKind] end
    local titan = titans[id]
    if not titan then return nil, "no_titan" end
    if not titan.active then return nil, "not_active" end
    if titan.mode ~= "pilot" then return nil, "not_piloting" end
    if not send(id, { v = T.protocol, op = "input", id = titan.id, epoch = titan.epoch, name = key, value = value }) then
        return nil, "owner_unavailable"
    end
    return true
end)

publish("releaseInput", function(player)
    local id = exportPlayer(player)
    if not id then return nil, "invalid_player" end
    local titan = titans[id]
    if not titan then return nil, "no_titan" end
    if not titan.active then return nil, "not_active" end
    if not send(id, { v = T.protocol, op = "input_release", id = titan.id, epoch = titan.epoch }) then
        return nil, "owner_unavailable"
    end
    return true
end)

-- hit / repair / creditCore: a mission script's request to the owner's controller, for a trusted server resource only (never
-- a client message, and no budget of the player's /titan commands). The request is validated whole (shared.lua:
-- T.normalizeHit, T.normalizeRepair, T.normalizeCoreCredit) before anything is looked up or sent, then needs the Titan
-- (no_titan) to be active (not_active) with room among its 32 unanswered requests (pending_full). It answers a positive
-- request number of that Titan, or nil plus a reason; the request is DISPATCHED, not done: the owner's controller decides
-- (its own boss-hit, its own hull-only repair, its own authored core rules) and the outcome arrives once as
-- onTitanActionResult(owner, id, request, kind, ok, reason, amount), with reason = 'timeout' after 5 s without an answer and
-- 'titan_removed' when the Titan goes first. `amount` is the controller's own estimate (a hit's damage in Titan health points,
-- the hull a repair added, the BURST CORE charge a credit actually added: 0 is taken and added nothing, a refusal carries a
-- reason instead), present when ok. What the Titan's health then is, is the next gameplay report in getState, never this
-- answer. creditCore names the Titan that was hit or killed by id and epoch only: that Titan may be gone already (a kill
-- removes it), so the server never needs its record, and it never decides what the credit is worth or whether the mission's
-- confirmation was right: the controller credits a kill once per Titan id and epoch, and paces blows by its authored budget.
local REQUEST_REASON = {
    hit_keys = "invalid_request", hit_record = "invalid_record", hit_origin = "invalid_origin",
    hit_direction = "invalid_direction", hit_attacker = "invalid_attacker", hit_kind = "invalid_kind",
    hit_scale = "invalid_scale", repair_amount = "invalid_amount",
    core_keys = "invalid_request", core_target = "invalid_target", core_record = "invalid_record",
    core_killing = "invalid_killing",
}

local function dispatchRequest(titan, op, fields, kind)
    if titan.pendingCount >= L.actionPending then return nil, "pending_full" end
    if not bridgeReady(titan.owner) then return nil, "bridge_unavailable" end
    local request = titan.requestSeq + 1
    local message = { v = T.protocol, op = op, id = titan.id, epoch = titan.epoch, request = request }
    for key, value in pairs(fields) do message[key] = value end
    -- Dispatched first: a target that is gone leaves no request and no number behind.
    if not send(titan.owner, message) then return nil, "owner_unavailable" end
    titan.requestSeq = request
    titan.pending[request] = { kind = kind, at = clock() }
    titan.pendingCount = titan.pendingCount + 1
    stats.actionsSent = stats.actionsSent + 1
    return request
end

publish("hit", function(player, request)
    local id = exportPlayer(player)
    if not id then return nil, "invalid_player" end
    local hit, why = T.normalizeHit(request)
    if not hit then return nil, REQUEST_REASON[why] end
    local titan = titans[id]
    if not titan then return nil, "no_titan" end
    if not titan.active then return nil, "not_active" end
    return dispatchRequest(titan, "hit", hit, "hit")
end)

publish("repair", function(player, amount)
    local id = exportPlayer(player)
    if not id then return nil, "invalid_player" end
    local clean, why = T.normalizeRepair(amount)
    if not clean then return nil, REQUEST_REASON[why] end
    local titan = titans[id]
    if not titan then return nil, "no_titan" end
    if not titan.active then return nil, "not_active" end
    return dispatchRequest(titan, "repair", { amount = clean }, "repair")
end)

publish("creditCore", function(player, request)
    local id = exportPlayer(player)
    if not id then return nil, "invalid_player" end
    local credit, why = T.normalizeCoreCredit(request)
    if not credit then return nil, REQUEST_REASON[why] end
    local titan = titans[id]
    if not titan then return nil, "no_titan" end
    if not titan.active then return nil, "not_active" end
    return dispatchRequest(titan, "core_credit", credit, "core_credit")
end)

-- setHold(player, held): the mission's hold on a Titan, a message to the owner's controller whose one gate covers every control
-- (the game's actions, the Mod Settings keys, a script's `input`, the pilot frame's own reading) except the camera look. It needs
-- the Titan only, not its first frame: the spawn's `hold` option has it held from the grant. Sent every time (the controller ends
-- in the same state however often), so the answer is dispatch, not effect.
publish("setHold", function(player, held)
    local id = exportPlayer(player)
    if not id then return false, "invalid_player" end
    if type(held) ~= "boolean" then return false, "invalid_value" end
    local titan = titans[id]
    if not titan then return false, "no_titan" end
    if not bridgeReady(id) then return false, "bridge_unavailable" end
    if not send(id, { v = T.protocol, op = "hold", id = titan.id, epoch = titan.epoch, held = held }) then
        return false, "owner_unavailable"
    end
    titan.held = held
    return true
end)

-- setClass(player, spec): a mission's class for a Titan. `spec` = { id = [a-z0-9_] 1..32, label = printable ASCII 1..32, weapon =
-- xo16 | rail | pred | sword | fist, perks = sparse { [perk] = level } (optional), abilities = { missiles, vortex, smoke, dash, jets,
-- sentry, flight, designator, core = boolean; a missing key is false }, speed = 0.5..1.5 (default 1), harm = 0.1..50 (default 1: the
-- damage BT takes while it wears the class, as a multiple of what the controller would take), regen = 0.25..10 (default 1: how many
-- times slower its shield comes back, the wait after a hit and the refill both) }. The Titan's loadout becomes
-- the perks over the defaults, then the class weapon's perk at 1 and the other four weapons' at 0 (so the server refuses a
-- `weapon` command for them from here on, and the controller its own switches), under a newer revision. The owner's controller
-- applies the loadout, the ability lock, the walk and run speed and the weapon in ONE step (the `class` message) and keeps them for
-- the Titan's life. `spec` nil clears the class: every perk at its maximum again, every ability allowed, speed 1. Validated whole
-- before anything is looked up or sent.
local CLASS_REASON = {
    class_keys = "invalid_class", class_id = "invalid_id", class_label = "invalid_label", class_weapon = "invalid_weapon",
    class_speed = "invalid_speed", class_harm = "invalid_harm", class_regen = "invalid_regen", class_abilities = "invalid_abilities",
}

publish("setClass", function(player, spec)
    local id = exportPlayer(player)
    if not id then return false, "invalid_player" end
    local class, loadout
    if spec == nil then
        loadout = LOADOUT.defaults()
    else
        local clean, second = T.normalizeClass(spec)
        if not clean then return false, CLASS_REASON[second] or exportReason(second) end
        class, loadout = clean, second
    end
    local titan = titans[id]
    if not titan then return false, "no_titan" end
    if not bridgeReady(id) then return false, "bridge_unavailable" end
    local revision = titan.revision + 1
    local message = { v = T.protocol, op = "class", id = titan.id, epoch = titan.epoch, revision = revision,
        loadout = copyLoadout(loadout) }
    if class then message.class = copyTree(class) end
    -- The owner must be told before the record moves: a target that is gone changes nothing.
    if not send(id, message) then return false, "owner_unavailable" end
    titan.loadout, titan.revision, titan.class = loadout, revision, class
    print(("[titans] class of Titan %s of player %d is now %s (loadout revision %d)"):format(titan.id, id,
        class and class.id or "none", revision))
    -- Without the sentry perk a body in the fist (granted, or still waiting for its first sample) is let go.
    if loadout.sentry == 0 then releaseCarry(titan, "interrupted") end
    return true
end)

-- creditKill(player, rank): the core charge a kill of a `grunt`, `rare` or `heavy` foe is worth, credited by the owner's own
-- controller with its own kill values and its own rules (no gain without the BURST CORE perk, never past the core's ceiling,
-- nothing while the core burns). Dispatched, not answered: there is no request number and no result, and the answer is the next
-- gameplay report's core charge.
publish("creditKill", function(player, rank)
    local id = exportPlayer(player)
    if not id then return false, "invalid_player" end
    if type(rank) ~= "string" or T.killRanks[rank] ~= true then return false, "invalid_value" end
    local titan = titans[id]
    if not titan then return false, "no_titan" end
    if not bridgeReady(id) then return false, "bridge_unavailable" end
    if not send(id, { v = T.protocol, op = "credit_kill", id = titan.id, epoch = titan.epoch, rank = rank }) then
        return false, "owner_unavailable"
    end
    return true
end)

-- getState: a detached copy of what the server accepted from the owner's controller (mode, weapon, root pose and the
-- last gameplay report) and of its own records of the Titan (grant, loadout, claim). `position` / `rotation` (and `mode` /
-- `weapon`) are the last accepted frame's and absent until the controller's first one; `owner` is the player number;
-- `revision` and `loadout` are the loadout's; `carry` is the claim the server arbitrates (never its platform token). What a mission
-- last told the controller (held, class) is in `/titan status`, not here.
-- `gameplay` is the owner's LATEST ACCEPTED report (health { current, max, shield?, shieldMax?, doomed?, doomedMax?, dead },
-- ammo, core, abilities, paused, pauseReason: shared.lua T.normalizeGameplay), absent until the controller has reported one
-- and kept (not cleared) by a frame that carries none. It is the owner's word, not the server's: the server holds no
-- health of its own and invents none, and a hit or repair is reflected only once a later report says so.
publish("getState", function(player)
    local titan, reason = exportTitan(player)
    if not titan then return nil, reason end
    local viewers = 0
    for _ in pairs(titan.viewers) do viewers = viewers + 1 end
    local state = {
        id = titan.id, epoch = titan.epoch, owner = titan.owner, active = titan.active == true,
        mode = titan.mode, weapon = titan.weapon, revision = titan.revision, loadout = copyLoadout(titan.loadout),
        viewers = viewers,
        frames = { accepted = titan.accepted, rejected = titan.rejected, lastReject = titan.lastReject },
        carry = { active = titan.carry ~= nil },
    }
    local pose = titan.pose
    if pose then
        state.position = { x = pose.x, y = pose.y, z = pose.z }
        state.rotation = { yaw = pose.yaw }
    end
    if titan.gameplay then state.gameplay = copyTree(titan.gameplay) end
    local carry, last = titan.carry, titan.lastCarryEnd
    if carry then
        state.carry.kind, state.carry.entityId, state.carry.phase = carry.kind, carry.entityId, carry.phase
    end
    if last then state.carry.last = { kind = last.kind, entityId = last.entityId, reason = last.reason } end
    return state
end)

-- setPlayerDamage(record, amount): what ONE blow of an attack record takes off a player (the owner's report names the record,
-- never an amount). `amount` is finite, 0..300 (the platform's own cap on one scripted blow); 0 turns the record off. A record
-- the table does not price yet is priced under the kind 'unknown' (no kind multiplier). playerDamage(record) answers the
-- price, or nil for a record nothing prices. Both are server-only, like every export here.
publish("setPlayerDamage", function(record, amount)
    if not T.isRecordName(record) then return false, "invalid_record" end
    if not T.finite(amount) or amount < 0 or amount > PLAYER_DAMAGE_MAX then return false, "invalid_amount" end
    local entry = PLAYER_DAMAGE[record]
    if entry then entry.amount = amount else PLAYER_DAMAGE[record] = { amount = amount, kind = "unknown" } end
    return true
end)

publish("playerDamage", function(record)
    local entry = T.isRecordName(record) and PLAYER_DAMAGE[record] or nil
    return entry and entry.amount or nil
end)

-- setTitanPvp(enabled) / titanPvp(): whether a Titan's auto-targeting may take another player's Titan or body for a foe (the missile
-- lock, the flight strike's rockets, the designator, the AI, the slam). Off until a server script turns it on; the answer of
-- setTitanPvp is true, or false and invalid_value for anything but a boolean. The flag rides the `session` message every bridge
-- client is sent when its session opens and again, to every client with a bridge, on each change (an unchanged value sends
-- nothing). It decides nothing here: what a blow on a Titan or a player costs is the mission's and Open77's PvP rules', as before.
publish("setTitanPvp", function(enabled)
    if type(enabled) ~= "boolean" then return false, "invalid_value" end
    if enabled == titanPvp then return true end
    titanPvp = enabled
    local list = {}
    for player in pairs(clients) do
        if bridgeReady(player) then list[#list + 1] = player end
    end
    for _, player in ipairs(list) do send(player, sessionMessage(player)) end
    return true
end)

publish("titanPvp", function() return titanPvp end)

CreateThread(function()
    while running do
        local ok, err = pcall(tick)
        Wait(250)
        if not ok then print("[titans] upkeep failed: " .. tostring(err)) end
    end
end)

-- Read-only handles for the protocol tests; nothing else uses them.
Open77TitansServer = {
    titans = titans, clients = clients, hides = hides, stats = stats, bodies = bodies,
    acceptFrame = acceptFrame, execute = execute, tick = tick, reconcile = reconcile,
    spawnTitan = spawnTitan, removeTitan = removeTitan, inbox = inbox, drainInbox = drainInbox,
    carryReport = carryReport, releaseCarry = releaseCarry, settleVehicleHits = settleVehicleHits, forgetLog = forgetLog,
}
print("[titans] resource ready; no Titan is created until a player runs /titan spawn")
