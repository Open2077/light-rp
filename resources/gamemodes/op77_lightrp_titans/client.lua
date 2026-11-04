-- op77_lightrp_titans (client): the Titan controller of this machine and its link to the Open77 server.
--
-- The author's BT-7274 controller no longer needs Cyber Engine Tweaks: it is committed in controller/ (generated once by Open77's
-- scripts/titans/prepare_bt7274_package.py, maintained by hand since), runs inside this resource's Lua state under an explicit environment
-- (controller/open77_titan_env.lua) and is driven from here, once per game frame, by one SetTick:
--
--   controller --link.send(table)--> [this file] --TriggerServerEvent--> server
--   controller <--link.poll()------- [this file] <---net event---------- server
--
-- This file is a bounded forwarder, not a trust boundary. The authenticated server stays in charge of ownership, motion
-- and every nested field of a controller frame (T.normalizeFrame), and the controller's bridge validates every relayed
-- state (schema.inbound) before it touches the engine. Frames and states are therefore NOT normalized a second time
-- here: they are routed on a small envelope (routingEnvelope) and the table is forwarded as is; the event layer bounds
-- depth and value count, and the queues below bound what waits. Every other message (session, grant, loadout, class, hold,
-- credit_kill, remove, command, input, hit, repair, core_credit, carry, and the controller's gameplay_result answer and its
-- hit_observed, status_observed, vehicle_hit, player_hit and npc_hit reports) is small and keeps its full strict normalization in both directions. Requests and
-- carry messages are closed sets: there is no free-text command, and a frame's strings are only honoured after the server
-- matches them to the catalog.
-- It also owns the one piece of Titan presentation the controller cannot do itself: hiding the local avatar
-- (third-person double included) while piloting. It also hands the controller what only Open77 can tell it: the
-- game's menu transitions (open77:menuStateChanged), and the player's own two actions (the `titanbring` and
-- `titancooldown` commands and keys). The `titanhints` command shows or hides the HUD page's control hints (render.lua).
local T = Open77Titans
local L = T.limits
local finite, abs = T.finite, math.abs
local RESOURCE = GetCurrentResourceName()

-- What to fix, per failure code. These are the only strings that describe a setup problem; the code, never free text,
-- travels to the server.
local ADVICE = {
    bridge_missing = "The Open77 Titan carry native (Open77TitanBridgePlaceCarriedNpc) is not registered. This client needs "
        .. "the Open77 build that includes it (client/redscript/Open77TitanBridge.reds); reinstall the client and restart the game.",
    rtti_denied = "This resource was not granted rtti.native, so it cannot reach the game. The resource manifest must declare it.",
    rtti_unavailable = "Open77.rtti is unavailable on this client build, so the Titan controller cannot run.",
    scheduler_denied = "This resource could not reserve its frame time (scheduler.dedicated): the operator must select it in "
        .. "resources.load and the manifest must declare the permission.",
    controller_missing = "The Titan controller is not in this resource (resources/gamemodes/op77_lightrp_titans/controller/). It is "
        .. "committed with the resource, not generated on the server: redeploy the resource from the repository.",
    controller_failed = "The Titan controller failed to load (see the lines above): the BT-7274 package, Codeware or the "
        .. "controller build is not what this resource expects.",
}

local OUTGOING_BURST, OUTGOING_RATE = 30, 60
local PENDING_LIMIT = 64
-- The controller's whole frame (events, update, bridge, overlay) runs inside one reserved slice per game frame. The
-- slice is the measured 0.74-1.34 ms of the controller on LuaJIT times Lua 5.4's speed; resize it with a measurement.
local RESERVATION = 4000

local state = {
    running = false,
    bridge = false,
    session = nil,     -- the active session message (re-delivered as a keepalive)
    own = nil,         -- { id, epoch, revision } of this player's granted Titan; revision = the newest loadout relayed
    hidden = false,    -- the local avatar is hidden by this resource
    inbox = {},        -- messages the controller has not taken yet, in order
    out = nil,         -- token bucket for what is forwarded to the server
    logged = {},
    lostShots = 0,     -- queued one-shot events dropped because the controller stopped draining
    carry = nil,       -- { id, epoch, token, kind, entityId }: the claim the server granted this controller
    carryRequests = {}, -- [request] = { id, epoch, kind, entityId, at }: asked of the server, not answered yet
    lastAt = nil,      -- the clock of the previous frame
    controller = nil,
    bridgeModule = nil,
    announced = nil,   -- { bridge, reason? } this client told the server at start (nil until start() has decided)
}

local function clock() return Open77.time.monotonic() end

-- Diagnostics are rate-limited per key and carry only validator/native tokens.
local function once(key, text, interval, level)
    local now = clock()
    if (state.logged[key] or -math.huge) + (interval or 10) > now then return end
    state.logged[key] = now
    Open77.log[level or "warn"]("[titans] " .. text)
end

-- The one engine write the controller makes through the host: the carried person's root.
local function probe()
    local rtti = Open77.rtti
    if type(rtti) ~= "table" or type(rtti.global) ~= "function" or type(rtti.type) ~= "function" then
        return false, "rtti_unavailable"
    end
    local ok, found, reason = pcall(rtti.global, "Open77TitanBridgePlaceCarriedNpc")
    if not ok or found == nil then
        reason = tostring(ok and reason or found)
        if reason:find("^permission_denied") then return false, "rtti_denied" end
        return false, "bridge_missing"
    end
    return true
end

-- Over the backlog bound, the oldest motion-only state goes first (its Titan's newer state supersedes it anyway), then
-- the oldest state that carries one-shot events, and only then anything else. Losing events is never silent.
local function trimBacklog()
    while #state.inbox > PENDING_LIMIT do
        local drop
        for index, entry in ipairs(state.inbox) do
            if entry.motionOf then drop = index break end
        end
        if not drop then
            for index, entry in ipairs(state.inbox) do
                if entry.state then drop = index break end
            end
        end
        local entry = table.remove(state.inbox, drop or 1)
        if entry.shots > 0 then
            state.lostShots = state.lostShots + entry.shots
            once("backlog-shots", "the controller is not draining its messages: " .. entry.shots ..
                " queued shot/sound event(s) of a remote Titan were dropped (" .. state.lostShots .. " lost so far)",
                10, "error")
        else
            once("backlog", "the controller is not draining its messages; dropped the oldest queued message")
        end
    end
end

-- A state carries the Titan's whole persistent snapshot, so a newer state supersedes every older MOTION-ONLY state of the
-- same Titan still waiting. A state that carries events is never merged or discarded here: each one-shot is delivered
-- exactly once, in order, and the newest pose always arrives after it. A loadout update carries the Titan's whole policy,
-- so it supersedes an older queued one of the same Titan and epoch (the grant that opened it is never merged: it creates
-- the Titan).
local function enqueue(message)
    local isState = message.op == "state"
    -- A state's events are only counted: routingEnvelope guarantees the container and the controller's bridge validates
    -- the items.
    local shots = isState and #message.events or 0
    local key
    if message.op == "session" then
        key = "session"
    elseif message.op == "loadout" then
        key = "loadout:" .. message.id .. ":" .. message.epoch
    end
    for index = #state.inbox, 1, -1 do
        local entry = state.inbox[index]
        if (key ~= nil and entry.key == key) or (isState and entry.motionOf == message.id) then
            table.remove(state.inbox, index)
        end
    end
    state.inbox[#state.inbox + 1] = {
        message = message, key = key, state = isState, shots = shots,
        motionOf = (isState and shots == 0) and message.id or nil,
    }
    trimBacklog()
    return true
end

local function poll()
    local entry = table.remove(state.inbox, 1)
    return entry and entry.message or nil
end

-- Hide the local avatar while this player's Titan is piloted. The setter is the
-- documented per-resource hide: it is released when this resource stops or
-- reloads, on death and on disconnect.
local function setPuppet(hidden)
    if state.hidden == hidden then return end
    local setter = Open77.players and Open77.players.setLocalPuppetVisible
    if type(setter) ~= "function" then
        if hidden then once("puppet-api", "this client has no Open77.players.setLocalPuppetVisible; your avatar stays visible inside the Titan") end
        return
    end
    local ok, reason = setter(not hidden)
    if ok then
        state.hidden = hidden
    else
        once("puppet", "could not change the local avatar visibility: " .. tostring(reason))
    end
end

local function clearOwn()
    state.own = nil
    state.carry, state.carryRequests = nil, {}
    setPuppet(false)
end

-- ---------------------------------------------------------------------------
-- Physical carry (controller -> server). The controller names a native body by
-- the exact unsigned decimal TEXT of its REDengine entity id. This file turns it
-- into the canonical NPC/vehicle id the replication layer already assigned to
-- that body, and only the canonical id leaves this machine. The id is never a
-- Lua number on the way: a double rounds everything above 2^53, and a rounded id
-- names a different body.
-- ---------------------------------------------------------------------------

-- The same 64 bits as the text, as a Lua integer. Integer arithmetic wraps modulo
-- 2^64, which is exactly how the world reads publish an unsigned 64-bit id.
local function nativeBits(text)
    local bits = 0
    for index = 1, #text do bits = bits * 10 + (text:byte(index) - 48) end
    return bits
end

local function sameEntity(value, text, bits)
    if math.type(value) == "integer" then return value == bits end
    return value == text
end

local function canonicalText(id)
    if math.type(id) ~= "integer" or id < 1 then return nil end
    local text = string.format("%d", id)
    return T.isId(text) and text or nil
end

local function pendingCount()
    local count = 0
    for _ in pairs(state.carryRequests) do count = count + 1 end
    return count
end

local function expireCarryRequests(now)
    for request, entry in pairs(state.carryRequests) do
        if now - entry.at > L.carryPending then state.carryRequests[request] = nil end
    end
end

-- The controller waits for exactly one answer per request: a refusal decided on
-- this machine is delivered to it like the server's own.
local function denyCarry(header, reason)
    enqueue({
        v = T.protocol, op = "carry_denied", id = header.id, epoch = header.epoch,
        request = header.request, reason = reason,
    })
end

-- An NPC has no entity-id lookup of its own: the server-owned set (Open77.npcs.all, vanilla peds excluded) is the one
-- read that carries both the engine id and the Open77 id, and it costs no world query. A body in no row is a vanilla
-- population ped: scenery, a different one on every client.
local function resolveNpc(text, bits)
    local npcs = Open77.npcs
    if type(npcs) ~= "table" or type(npcs.all) ~= "function" then return nil, "entity_unresolved" end
    local rows, why = npcs.all()
    if type(rows) ~= "table" then
        once("carry:scan", "carry: the NPC list failed: " .. tostring(why), 5)
        return nil, "entity_unresolved"
    end
    for _, npc in ipairs(rows) do
        if type(npc) == "table" and sameEntity(npc.engineEntity, text, bits) then
            local id = canonicalText(npc.id)
            if not id then return nil, "not_networked" end
            if npc.streamed ~= true or npc.entity == 0 or not (npc.health and npc.health > 0) then
                return nil, "body_not_ready"
            end
            return id
        end
    end
    return nil, "not_networked"
end

-- `vehicles.fromEntity` takes the id as decimal text, and answers for either id a
-- vehicle carries, so the REDengine one is checked on the answer.
local function resolveVehicle(text, bits)
    local vehicles = Open77.vehicles
    if type(vehicles) ~= "table" or type(vehicles.fromEntity) ~= "function" then return nil, "entity_unresolved" end
    local snapshot, why = vehicles.fromEntity(text)
    if type(snapshot) ~= "table" then
        if why == "unknown_entity" then return nil, "not_networked" end
        once("carry:lookup", "carry: the vehicle lookup failed: " .. tostring(why), 5)
        return nil, "entity_unresolved"
    end
    local id = canonicalText(snapshot.id)
    if not id or not sameEntity(snapshot.engineEntity, text, bits) then return nil, "entity_unresolved" end
    if snapshot.streamed ~= true then return nil, "body_not_ready" end
    return id
end

local function requestCarry(message)
    expireCarryRequests(clock())
    if state.carry then return denyCarry(message, "already_carrying") end
    if state.carryRequests[message.request] then return denyCarry(message, "stale_request") end
    if pendingCount() >= L.carryPendingMax then return denyCarry(message, "rate_limited") end
    local bits = nativeBits(message.entity)
    local entityId, reason
    if message.kind == "npc" then
        entityId, reason = resolveNpc(message.entity, bits)
    else
        entityId, reason = resolveVehicle(message.entity, bits)
    end
    if not entityId then return denyCarry(message, reason) end
    state.carryRequests[message.request] = {
        id = message.id, epoch = message.epoch, kind = message.kind, entityId = entityId, at = clock(),
    }
    local sent, why = TriggerServerEvent(T.event.carry, {
        v = T.protocol, op = "carry_request", id = message.id, epoch = message.epoch,
        request = message.request, kind = message.kind, entityId = entityId,
    })
    if not sent then
        state.carryRequests[message.request] = nil
        once("send:" .. tostring(why), "carry request not sent: " .. tostring(why))
        denyCarry(message, "unavailable")
    end
end

-- A request that cannot even be parsed still gets its answer when its header
-- names the request; otherwise the controller's own pending timeout ends it.
local function requestHeader(message)
    if type(message) ~= "table" or not T.isId(message.id) then return nil end
    local epoch, request = T.whole(message.epoch, 1, L.integer), T.whole(message.request, 1, L.integer)
    if not epoch or not request then return nil end
    return { id = message.id, epoch = epoch, request = request }
end

local function forwardCarry(message)
    local clean, reason = T.normalizeControllerCarry(message)
    if not clean then
        once("carry:" .. tostring(reason), "controller carry message rejected locally: " .. tostring(reason), 5)
        local header = message.op == "carry_request" and requestHeader(message) or nil
        if header then denyCarry(header, "entity_unresolved") end
        return
    end
    local own = state.own
    if not own or own.id ~= clean.id or own.epoch ~= clean.epoch then
        once("carry:grant", "controller carry message without a matching grant dropped", 5)
        if clean.op == "carry_request" then denyCarry(clean, "stale_titan") end
        return
    end
    if clean.op == "carry_request" then return requestCarry(clean) end
    local carry = state.carry
    if not carry or carry.token ~= clean.token or carry.id ~= clean.id or carry.epoch ~= clean.epoch then
        once("carry:token", "controller carry sample without a live claim dropped", 5)
        return
    end
    -- The release of a thrown person (its flight phase is checked with the message) belongs to a person's claim only.
    if clean.launch ~= nil and carry.kind ~= "npc" then
        once("carry:launch", "controller carry launch for a body that is not a person dropped", 5)
        return
    end
    -- The release is the last thing this claim sends; the server's carry_ended confirms it.
    if clean.op == "carry_release" then state.carry = nil end
    local sent, why = TriggerServerEvent(T.event.carry, clean)
    if not sent then once("send:" .. tostring(why), "carry message not sent: " .. tostring(why)) end
end

-- ---------------------------------------------------------------------------
-- Routing envelope: the only fields of a controller frame or a relayed state that THIS
-- file acts on. Who it is for (id, epoch), where it sits in the stream (seq, t), whether
-- it hides the local avatar (mode) and that the pose is a real position. A fixed
-- handful of reads, with the validator's own tokens and bounds; everything nested
-- (vars, meshes, lights, visuals, events) is left to the authoritative server and to the
-- controller's bridge, which re-validates it in full and sheds what it refuses.
-- Returns nil when sound, else a reason token.
-- ---------------------------------------------------------------------------
local function routingEnvelope(message)
    if not T.isId(message.id) then return "frame_id" end
    if not T.whole(message.epoch, 1, L.integer) then return "frame_epoch" end
    if not T.whole(message.seq, 1, L.integer) then return "frame_seq" end
    local at = message.t
    if not finite(at) or at < 0 or at > L.time then return "frame_time" end
    local pose = message.pose
    if type(pose) ~= "table" then return "pose_invalid" end
    local x, y, z, yaw, bound = pose.x, pose.y, pose.z, pose.yaw, L.coordinate
    if not (finite(x) and finite(y) and finite(z) and finite(yaw))
        or abs(x) > bound or abs(y) > bound or abs(z) > bound or abs(yaw) > L.yaw then
        return "pose_invalid"
    end
    if T.modes[message.mode] ~= true then return "frame_mode" end
end

-- ---------------------------------------------------------------------------
-- Server -> controller.
-- ---------------------------------------------------------------------------
local function onServerMessage(message)
    local op = message.op
    if op == "session" then
        -- The newest session message is what every keepalive re-delivers, so the server's Titan PvP flag (`pvp`, shared.lua) it
        -- carries reaches the controller's bridge again every beat and a change is simply a newer session.
        if message.active then
            state.session = message
        else
            state.session = nil
            clearOwn()
        end
    elseif op == "grant" then
        if state.session and message.owner == state.session.player then
            state.own = { id = message.id, epoch = message.epoch, revision = message.revision }
        end
    elseif op == "loadout" or op == "class" then
        -- Only the newest word on this controller's own Titan is relayed: the server sends it
        -- to the owner alone, but a late or replayed one for another Titan, epoch or revision
        -- is never the controller's to apply.
        local own = state.own
        if not (own and own.id == message.id and own.epoch == message.epoch and message.revision > own.revision) then
            once(op .. ":stale", "dropped a " .. op .. " update that is not newer for this controller's Titan", 5)
            return
        end
        own.revision = message.revision
    elseif op == "remove" then
        if state.own and state.own.id == message.id then clearOwn() end
    elseif op == "carry_grant" then
        local pending, own = state.carryRequests[message.request], state.own
        state.carryRequests[message.request] = nil
        if not (pending and own and own.id == message.id and own.epoch == message.epoch and pending.id == message.id
            and pending.epoch == message.epoch and pending.kind == message.kind and pending.entityId == message.entityId) then
            -- Nothing waits for it: the claim lapses on the server within a second.
            once("carry:orphan", "the server granted a carry that matches no pending request", 5, "error")
            return
        end
        state.carry = { id = message.id, epoch = message.epoch, token = message.token, kind = message.kind,
            entityId = message.entityId }
    elseif op == "carry_denied" then
        local pending = state.carryRequests[message.request]
        if not (pending and pending.id == message.id and pending.epoch == message.epoch) then
            once("carry:denied", "dropped a carry denial that matches no pending request", 5)
            return
        end
        state.carryRequests[message.request] = nil
    elseif op == "carry_ended" then
        local own = state.own
        if not (own and own.id == message.id and own.epoch == message.epoch) then return end
        if state.carry and state.carry.token == message.token then state.carry = nil end
    elseif op == "hit" or op == "repair" or op == "core_credit" or op == "hold" or op == "credit_kill" then
        -- A server script's request is scoped to one Titan and epoch: only the controller that holds that grant takes it.
        local own = state.own
        if not (own and own.id == message.id and own.epoch == message.epoch) then
            once("gameplay:stale", "dropped a server request that does not name this controller's Titan", 5)
            return
        end
    elseif op == "error" then
        Open77.log.warn("[titans] server: " .. message.reason)
    end
    enqueue(message)
end

-- A relayed state is the server's own canonical snapshot of a Titan: it takes the cheap
-- envelope path and is delivered as decoded. The rest of the ops are small and are
-- rebuilt field by field.
local function acceptServerMessage(raw)
    if type(raw) == "table" and raw.op == "state" and raw.v == T.protocol then
        local reason = routingEnvelope(raw)
        if reason then return nil, reason end
        if not T.isId(raw.owner) then return nil, "state_owner" end
        if not finite(raw.serverTime) or raw.serverTime < 0 then return nil, "state_time" end
        if type(raw.events) ~= "table" then return nil, "events_count" end
        return raw
    end
    return T.normalizeServerMessage(raw, Open77TitanCatalog)
end

RegisterNetEvent(T.event.message, function(raw)
    if not state.bridge then return end
    local message, reason = acceptServerMessage(raw)
    if not message then
        once("server:" .. tostring(reason), "dropped a malformed server message: " .. tostring(reason))
        return
    end
    onServerMessage(message)
end)

-- The server's probe: its Titan resource just started and knows no client, while this one has been up all along and announces
-- itself only at its own start. Answer once with what start() announced (bridge up, or the same fixed failure code), marked
-- as an answer so the server never takes it for a restart. Before start() has decided there is nothing to say: start()
-- announces on its own. Nothing is restarted, granted or retried here, and the controller never hears of it.
RegisterNetEvent(T.event.probe, function()
    local told = state.announced
    if not (state.running and told) then return end
    local sent, why = TriggerServerEvent(T.event.ready, { bridge = told.bridge, reason = told.reason, answer = true })
    if not sent then once("send:" .. tostring(why), "readiness answer not sent: " .. tostring(why)) end
end)

-- The game's menus. The controller used to be told when the pause menu or the menu after V's death opened (a session
-- can end from either) and when gameplay came back; Open77 raises the same transitions as this event, whose last
-- argument is the vanilla scenario the game left gameplay for ("" in gameplay). The bridge applies them at its next frame.
AddEventHandler("open77:menuStateChanged", function(_, _, _, scenario)
    if state.bridge then state.bridgeModule.menu(scenario) end
end)

-- ---------------------------------------------------------------------------
-- Controller -> server.
-- ---------------------------------------------------------------------------
-- The controller's link: false only when the message is refused for budget (its cue to hold events); a message that is
-- not valid or never leaves this machine is consumed. The once-per-second heartbeat exists only so that a refused send
-- tells the controller the session is gone; it is not validated, relayed or answered and costs no budget.
local function handleOutgoing(message)
    if type(message) ~= "table" or message.v ~= T.protocol then
        once("out:shape", "the controller sent a message that is not protocol-" .. T.protocol)
        return true
    end
    if message.op == "heartbeat" then return state.bridge end
    if not state.bridge or not T.take(state.out, 1, clock()) then return false end
    if message.op == "frame" then
        -- Routing only: the frame goes to the server as it is. The server's T.normalizeFrame is the one validation of
        -- its nested fields and sheds what it refuses.
        local reason = routingEnvelope(message)
        if reason then
            once("frame:" .. reason, "controller frame rejected locally: " .. reason, 5)
            return true
        end
        local own = state.own
        if not own or own.id ~= message.id or own.epoch ~= message.epoch then
            once("frame:grant", "controller frame without a matching grant dropped", 5)
            return true
        end
        setPuppet(message.mode == "pilot")
        local sent, why = TriggerServerEvent(T.event.frame, message)
        if not sent then once("send:" .. tostring(why), "frame not sent: " .. tostring(why)) end
    elseif message.op == "request" and type(message.action) == "string" and T.requestActions[message.action] then
        local sent, why = TriggerServerEvent(T.event.request, message.action)
        if not sent then once("send:" .. tostring(why), "request not sent: " .. tostring(why)) end
    elseif message.op == "gameplay_result" then
        -- The controller's answer to a hit / repair: validated with the server's own rules and sent only for this
        -- controller's own Titan and epoch; the server matches it to what it asked and takes it once.
        local clean, reason = T.normalizeGameplayResult(message)
        if not clean then
            once("result:" .. tostring(reason), "controller gameplay answer rejected locally: " .. tostring(reason), 5)
            return true
        end
        local own = state.own
        if not own or own.id ~= clean.id or own.epoch ~= clean.epoch then
            once("result:grant", "controller gameplay answer without a matching grant dropped", 5)
            return true
        end
        local sent, why = TriggerServerEvent(T.event.result, clean)
        if not sent then once("send:" .. tostring(why), "gameplay answer not sent: " .. tostring(why)) end
    elseif message.op == "hit_observed" then
        -- The owner's controller saw its Titan land a blow on another player's Titan: validated with the server's own rules and
        -- sent only for this controller's own Titan and epoch (the source). Whether the target is a Titan the server lets this
        -- player name is the server's to decide; nothing here resolves or applies anything.
        local clean, reason = T.normalizeHitObserved(message)
        if not clean then
            once("hit:" .. tostring(reason), "controller hit report rejected locally: " .. tostring(reason), 5)
            return true
        end
        local own = state.own
        if not own or own.id ~= clean.id or own.epoch ~= clean.epoch then
            once("hit:grant", "controller hit report without a matching grant dropped", 5)
            return true
        end
        local sent, why = TriggerServerEvent(T.event.hit, clean)
        if not sent then once("send:" .. tostring(why), "hit report not sent: " .. tostring(why)) end
    elseif message.op == "status_observed" then
        -- The same observation for a status effect the owner's controller's own calls would apply to another player's Titan:
        -- validated with the server's own rules and sent only for this controller's own Titan and epoch (the source), on its own
        -- event. What the server lets it name is the server's to decide; nothing here resolves or applies anything.
        local clean, reason = T.normalizeStatusObserved(message)
        if not clean then
            once("status:" .. tostring(reason), "controller status report rejected locally: " .. tostring(reason), 5)
            return true
        end
        local own = state.own
        if not own or own.id ~= clean.id or own.epoch ~= clean.epoch then
            once("status:grant", "controller status report without a matching grant dropped", 5)
            return true
        end
        local sent, why = TriggerServerEvent(T.event.status, clean)
        if not sent then once("send:" .. tostring(why), "status report not sent: " .. tostring(why)) end
    elseif message.op == "vehicle_hit" then
        -- What the owner's controller took off a car (its FPF.wreck, summed per car by the bridge): validated with the server's own
        -- rules and sent only for this controller's own Titan and epoch (the source), on its own event and the same forwarding
        -- budget. The car is named by the canonical id the bridge resolved; whether the server lets the hit count is its to decide.
        local clean, reason = T.normalizeVehicleHit(message)
        if not clean then
            once("vehicle:" .. tostring(reason), "controller vehicle hit rejected locally: " .. tostring(reason), 5)
            return true
        end
        local own = state.own
        if not own or own.id ~= clean.id or own.epoch ~= clean.epoch then
            once("vehicle:grant", "controller vehicle hit without a matching grant dropped", 5)
            return true
        end
        local sent, why = TriggerServerEvent(T.event.vehicle, clean)
        if not sent then once("send:" .. tostring(why), "vehicle hit not sent: " .. tostring(why)) end
    elseif message.op == "player_hit" then
        -- A blow of the owner's controller on another player's body (summed per player and record by the bridge): the same
        -- local validation, grant match and forwarding budget as a car hit, on its own event. Whether the victim may be hurt
        -- is the server's to decide.
        local clean, reason = T.normalizePlayerHit(message)
        if not clean then
            once("player:" .. tostring(reason), "controller player hit rejected locally: " .. tostring(reason), 5)
            return true
        end
        local own = state.own
        if not own or own.id ~= clean.id or own.epoch ~= clean.epoch then
            once("player:grant", "controller player hit without a matching grant dropped", 5)
            return true
        end
        local sent, why = TriggerServerEvent(T.event.player, clean)
        if not sent then once("send:" .. tostring(why), "player hit not sent: " .. tostring(why)) end
    elseif message.op == "npc_hit" then
        -- A blow of the owner's controller on an NPC the platform owns (named by its platform id, one message per blow): the same
        -- local validation, grant match and forwarding budget as a car or player hit, on its own event. Whether the NPC may be
        -- hurt, and for how much, is the server's and the mission's to decide: this resource only forwards the observation.
        local clean, reason = T.normalizeNpcHit(message)
        if not clean then
            once("npc:" .. tostring(reason), "controller NPC hit rejected locally: " .. tostring(reason), 5)
            return true
        end
        local own = state.own
        if not own or own.id ~= clean.id or own.epoch ~= clean.epoch then
            once("npc:grant", "controller NPC hit without a matching grant dropped", 5)
            return true
        end
        local sent, why = TriggerServerEvent(T.event.npc, clean)
        if not sent then once("send:" .. tostring(why), "NPC hit not sent: " .. tostring(why)) end
    elseif message.op == "carry_request" or message.op == "carry_frame" or message.op == "carry_release" then
        forwardCarry(message)
    else
        once("out:op", "ignored an unsupported controller message")
    end
    return true
end

local function heartbeat()
    if state.session then enqueue(state.session) end
end

-- One controller frame: the seconds since the previous one (the host's tick carries none), then the bridge's frame. The
-- session heartbeat rides it: a thread of its own would be a second scheduled task to restart when one dies.
local function frame()
    local now = clock()
    local delta = state.lastAt and math.min(math.max(now - state.lastAt, 0.0), 5.0) or (1.0 / 30.0)
    state.lastAt = now
    expireCarryRequests(now)
    if state.session and (state.beatAt == nil or now - state.beatAt >= L.heartbeat) then
        state.beatAt = now
        local ok, err = pcall(heartbeat)
        if not ok then once("heartbeat", "heartbeat failed: " .. tostring(err)) end
    end
    state.bridgeModule.frame(delta)
end

-- What the CET overlay's window offered the player while it was open: end the wait before BT can be called again, and
-- bring a BT that is out to V. Each is a client command (no permission) and a rebindable key (input.actions); a refusal
-- of either is reported once and leaves the other in place.
local function offer(command, id, label, key, act)
    local function run()
        if not state.bridge then return end
        local ok, err = pcall(act, state.bridgeModule)
        if not ok then once("action:" .. id, "the " .. command .. " action failed: " .. tostring(err)) end
    end
    local ok, commanded, why = pcall(RegisterCommand, command, run, false)
    if not (ok and commanded) then once("command:" .. command, "the " .. command .. " command was refused: " .. tostring(ok and why or commanded)) end
    local okKey, bound, effective = pcall(RegisterKeyMapping, id, label, key, run)
    if not (okKey and bound) then once("key:" .. id, label .. " has no key: " .. tostring(okKey and effective or bound)) end
end

-- What the server is told about this client's bridge, once, when start() has decided. It is remembered so that the server's
-- probe (a restarted server knows no client) is answered with this same fact and never with a guess.
local function announce(info)
    state.announced = info
    TriggerServerEvent(T.event.ready, info)
end

local function fail(reason, detail)
    Open77.log.error("[titans] " .. ADVICE[reason] .. (detail and (" (" .. tostring(detail) .. ")") or ""))
    announce({ bridge = false, reason = reason })
end

local function start()
    if state.running then return end
    state.running = true
    local ok, reason = T.checkCatalog(Open77TitanCatalog)
    if not ok then
        Open77.log.error("[titans] catalog.lua did not define Open77TitanCatalog: " .. tostring(reason))
        announce({ bridge = false, reason = "bridge_missing" })
        return
    end
    local bridge, why = probe()
    if not bridge then return fail(why) end
    local reserved, denied = Open77.scheduler.reserve(RESERVATION)
    if not reserved then return fail("scheduler_denied", denied) end
    -- The controller's main chunk: one `require`, the whole file-local state of the author's script.
    local loaded, controller, err = pcall(require, "controller.init")
    if not loaded or type(controller) ~= "table" then
        local missing = tostring(loaded and err or controller):find("not found", 1, true)
        return fail(missing and "controller_missing" or "controller_failed", loaded and err or controller)
    end
    local linked, module = pcall(require, "controller.open77_titan_bridge")
    if not linked or type(module) ~= "table" then return fail("controller_failed", module) end
    state.controller, state.bridgeModule = controller, module
    module.link({ send = handleOutgoing, poll = poll })
    state.bridge = true
    state.out = T.bucket(OUTGOING_BURST, OUTGOING_RATE, clock())
    announce({ bridge = true })
    pcall(RegisterCommand, "titanlog", function()
        module.setVerbose(not module.logOn())
        print("[titans] controller log " .. (module.logOn() and "on" or "off"))
    end, false)
    -- The HUD page's control hints (ui/hud_panel.js) are on until the player hides them: one command, asked of the render
    -- module that owns the page. A game without the page has nothing to switch.
    pcall(RegisterCommand, "titanhints", function()
        local loaded, render = pcall(require, "render")
        if not loaded or type(render) ~= "table" or type(render.toggleHints) ~= "function" then return end
        local shown = render.toggleHints()
        print("[titans] control hints " .. (shown and "on" or "off"))
    end, false)
    offer("titanbring", "titans.bring", "Titan: bring BT to me", "NUMPAD7", function(module) module.bring() end)
    offer("titancooldown", "titans.cooldown", "Titan: end the wait before BT can be called again", "NUMPAD6",
        function(module) module.resetCooldown() end)
    SetTick(function()
        local okf, errf = pcall(frame)
        if not okf then
            once("frame", "the controller frame failed: " .. tostring(errf))
        end
    end)
end

-- The ground under up to 32 points, for the other resources of this server (the Titan Assault's spawn probe): the
-- controller's own trace (its FPF.ground), straight down from `reach` metres above each point to `reach` below, in the
-- two collision groups the game's ground is made of. Open77.world.raycast traces Static and Dynamic only and falls
-- through the open terrain of the Badlands, which is `Terrain`. Each answer is { static = z | false, terrain = z | false }:
-- a static hit well above the terrain is a tree, a rock or a roof, which the caller tells apart. nil plus a reason when the
-- controller is not running here.
local GROUND_GROUPS = { static = "Static", terrain = "Terrain" }
exports("ground", function(points, reach)
    if not state.bridge then return nil, "controller_unavailable" end
    reach = tonumber(reach)
    if type(points) ~= "table" or not reach or reach <= 0 or reach > 200 then return nil, "invalid_value" end
    local okEnv, env = pcall(require, "controller.open77_titan_env")
    local okSqs, sqs = pcall(function() return env.Game.GetSpatialQueriesSystem() end)
    if not okEnv or not okSqs or not sqs then return nil, "rtti_unavailable" end
    local answers = {}
    for i = 1, math.min(#points, 32) do
        local p, answer = points[i], { static = false, terrain = false }
        local x, y, z = type(p) == "table" and tonumber(p.x), type(p) == "table" and tonumber(p.y), type(p) == "table" and tonumber(p.z)
        if x and y and z then
            for key, group in pairs(GROUND_GROUPS) do
                local ok, hit, res = pcall(function()
                    return sqs:SyncRaycastByCollisionGroup(env.Vector4.new(x, y, z + reach, 1.0), env.Vector4.new(x, y, z - reach, 1.0),
                        group, nil, false, false)
                end)
                if ok and hit and res and res.position and tonumber(res.position.z) then answer[key] = res.position.z end
            end
        end
        answers[i] = answer
    end
    return answers
end)

-- The Titan HUD's state while V pilots BT, for the other resources of this server: LightRP's HUD shows the hull and the shield on
-- its health and armor gauges, the weapon on its weapon readout and the ability cells and the core on its quick-item bar. It is the
-- table the controller's HUD module (controller/open77_titan_hud.lua) built last, with the fields ui/hud_panel.js lists, and nil when
-- V does not pilot, the controller shows no HUD (a paused game, a cut scene) or this client has no controller. A call from another
-- resource gets a copy: nothing can be changed through it.
exports("hudState", function()
    if not state.bridge then return nil end
    local loaded, hud = pcall(require, "controller.open77_titan_hud")
    if not loaded or type(hud) ~= "table" or type(hud.current) ~= "function" then return nil end
    return hud.current()
end)

AddEventHandler("onClientResourceStart", function(name)
    if name == RESOURCE then start() end
end)

-- The tick and the reservation end with the resource; nothing can be called into the game from here.
AddEventHandler("onClientResourceStop", function(name)
    if name ~= RESOURCE then return end
    state.running = false
    setPuppet(false)
    local loaded, render = pcall(require, "render")
    if loaded and type(render) == "table" then render.destroy() end
end)
