-- op77_chase adapters: ChaseCore (the Light RP activity contract) and ChaseWorld (the
-- natives), with the host stubbed.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test adapter_test.lua
local env

local function stubs()
    env = { calls = {}, events = {}, client = {}, threads = {}, answers = {}, raise = nil }
    _G.Open77 = {
        exports = {
            callSync = function(resource, name, ...)
                env.calls[#env.calls + 1] = { resource = resource, name = name, args = table.pack(...) }
                if env.raise then error(env.raise) end
                local answer = env.answers[name]
                if type(answer) == "function" then return answer(...) end
                if type(answer) == "table" and answer.multi then return table.unpack(answer, 1, answer.n) end
                return answer
            end,
        },
        time = { monotonic = function() return 12.3456 end },
    }
    _G.TriggerEvent = function(name, ...) env.events[#env.events + 1] = { name = name, args = table.pack(...) } end
    _G.TriggerClientEvent = function(name, target, ...) env.client[#env.client + 1] = { name = name, target = target, args = table.pack(...) } end
    _G.CreateThread = function(fn) fn() end
    _G.Wait = function() end
    _G.GetCurrentResourceName = function() return "op77_chase" end
    _G.GetPlayers = function() return { "3", "7" } end
end

local function pack(...) local t = table.pack(...); t.multi = true; return t end

stubs()
dofile("shared/config.lua")
dofile("server/core.lua")
dofile("server/world.lua")

-- ── ChaseCore: the contract calls ──
do
    local C = ChaseCore
    env.answers.activityRegister = true
    assert(C.register({ id = "chase.1v1" }) == true)
    assert(env.calls[1].resource == "op77_lightrp" and env.calls[1].name == "activityRegister")
    assert(env.calls[1].args[1].id == "chase.1v1")

    env.answers.activityRegister = pack(false, "duplicate id")
    local ok, why = C.register({ id = "chase.1v1" })
    assert(ok == false and why == "duplicate id")

    -- check / enter: the activity id is ours; a refusal keeps Light RP's sentence.
    env.calls = {}
    env.answers.activityCheck = pack(false, "You are in a vehicle.")
    ok, why = C.check(7)
    assert(ok == false and why == "You are in a vehicle.")
    assert(env.calls[1].args[1] == 7 and env.calls[1].args[2] == "chase.1v1")
    env.answers.activityCheck = true
    assert(C.check(7) == true)
    env.answers.activityEnter = true
    assert(C.enter(7) == true)
    env.answers.activityEnter = false
    ok, why = C.enter(7)
    assert(ok == false and why == "You cannot join a chase right now.", "a bare false still gets a sentence")

    -- A synchronous export that raises (resource stopped, export missing) never escapes.
    env.raise = "no such export"
    ok, why = C.check(7)
    assert(ok == false and why == "Light RP did not answer. Try again in a moment.")
    ok, why = C.enter(7)
    assert(ok == false and why:find("did not answer"))
    assert(C.leave(7) == false)
    assert(C.owner(7) == nil and C.player(7) == nil and C.owned(7) == false)
    assert(C.register({}) == false)
    env.raise = nil

    -- leave: default opts return the player.
    env.calls = {}
    env.answers.activityLeave = true
    assert(C.leave(7) == true)
    assert(env.calls[1].name == "activityLeave" and env.calls[1].args[2] == "chase.1v1" and env.calls[1].args[3].returnPlayer == true)
    assert(C.leave(7, { returnPlayer = false }) == true and env.calls[2].args[3].returnPlayer == false)

    -- owner / player
    env.answers.activityOwner = "chase.1v1"
    assert(C.owner(7) == "chase.1v1" and C.owned(7) == true)
    env.answers.activityOwner = "arena.ffa"
    assert(C.owned(7) == false)
    env.answers.activityOwner = nil
    assert(C.owner(7) == nil)
    env.answers.activityPlayer = { name = "V", identifier = "license:abc", characterKey = 2 }
    assert(C.player(7).identifier == "license:abc")
    env.answers.activityPlayer = "garbage"
    assert(C.player(7) == nil)

    -- Missing exports API altogether.
    local saved = Open77.exports
    Open77.exports = nil
    ok, why = C.check(7)
    assert(ok == false and why:find("did not answer"))
    Open77.exports = saved

    -- result / status: host-wide events, status only on change.
    C.result(7, { placement = 1, won = true })
    local e = env.events[#env.events]
    assert(e.name == "op77_lightrp:activity:result" and e.args[1] == 7 and e.args[2] == "chase.1v1" and e.args[3].won == true)
    env.events = {}
    local s = { phase = "lobby", players = 0, queued = 1, joinable = true, detail = "1 waiting" }
    assert(C.status(s) == true and C.status(s) == false, "same status twice is sent once")
    assert(C.status(s, true) == true, "forced")
    assert(C.status({ phase = "running", players = 2, queued = 0, joinable = true, detail = "x" }) == true)
    assert(#env.events == 3 and env.events[1].name == "op77_lightrp:activity:status" and env.events[1].args[1] == "chase.1v1")
    print("PASS core")
end

-- ── ChaseWorld: placement ──
do
    local W = ChaseWorld
    assert(W.now() == 12345)
    local life = {}
    local teleports, respawns = {}, {}
    Open77.players = {
        getLifeState = function(id) return life[id] and { phase = life[id] } or nil end,
        position = function(id) return id == 3 and { x = 1, y = 2, z = 3, bucket = 0 } or nil end,
        name = function(id) return id == 3 and "Vee" or nil end,
        teleport = function(id, pos, opts)
            teleports[#teleports + 1] = { id = id, pos = pos, opts = opts }
            if id == 9 then return nil, "player_not_alive" end
            return { await = function() if id == 8 then return false, "settle_superseded" end return true end }
        end,
        respawn = function(id, opts)
            respawns[#respawns + 1] = { id = id, opts = opts }
            life[id] = "alive"
            return true
        end,
        setFrozen = function(id, frozen) return id ~= 0 end,
    }
    assert(W.alive(3) == nil, "unknown life state is nil, never 'down'")
    life[3] = "alive"; assert(W.alive(3) == true)
    life[3] = "recovering"; assert(W.alive(3) == true)
    life[3] = "dead"; assert(W.alive(3) == false)
    assert(W.name(3) == "Vee" and W.name(4) == "#4")
    assert(W.connected(7) == true and W.connected(8) == false)
    assert(W.position(3).bucket == 0 and W.position(4) == nil)

    local results = {}
    local function done(ok, why) results[#results + 1] = { ok = ok, why = why } end
    local point = { position = { x = 10, y = 20, z = 30 }, heading = 90 }
    life[7] = "alive"
    W.place(7, point, 4300001, done)
    assert(results[1].ok == true and teleports[1].opts.bucket == 4300001 and teleports[1].opts.dismount == true
        and teleports[1].opts.fade == true and teleports[1].opts.heading == 90)
    life[8] = "alive"
    W.place(8, point, 4300001, done)
    assert(results[2].ok == false and results[2].why == "settle_superseded", "a failed await is a failed placement")
    life[9] = "alive"
    W.place(9, point, 4300001, done)
    assert(results[3].ok == false and results[3].why == "player_not_alive")
    -- A player who went down is respawned on the mark, inside the bucket.
    life[3] = "dead"
    W.place(3, point, 4300001, done)
    assert(results[4].ok == true and #respawns == 1 and respawns[1].opts.bucket == 4300001 and respawns[1].opts.position.x == 10)
    -- A native that raises is a failed placement, not a crash.
    Open77.players.teleport = function() error("boom") end
    life[7] = "alive"
    W.place(7, point, 4300001, done)
    assert(results[5].ok == false and results[5].why:find("boom"))

    assert(W.freeze(3, true) == true and W.freeze(0, true) == false)
    -- respawnInPlace uses the position, then the fallback mark.
    respawns = {}
    Open77.players.respawn = function(id, opts) respawns[#respawns + 1] = { id = id, opts = opts } return true end
    assert(W.respawnInPlace(3, 4300002) == true and respawns[1].opts.position.x == 1 and respawns[1].opts.bucket == 4300002)
    assert(W.respawnInPlace(4, 4300002, point) == true and respawns[2].opts.position.x == 10)
    assert(W.respawnInPlace(4, 4300002) == false)
    print("PASS world placement")
end

-- ── ChaseWorld: cars ──
do
    local W = ChaseWorld
    local created, removed = {}, {}
    Open77.vehicles = {
        flags = { engineOn = 1, lightsOn = 2, locked = 4, frozen = 8, sirenOn = 16 },
        create = function(def)
            created[#created + 1] = def
            if def.record == "Vehicle.ncpd_villefort_cortes_heat_1" then return nil, "unknown_record" end
            return 100 + #created
        end,
        remove = function(id) removed[#removed + 1] = id return true end,
        all = function(bucket)
            return { { id = 1, resource = "op77_chase", bucket = bucket }, { id = 2, resource = "op77_lightrp", bucket = bucket },
                { id = 3, resource = "op77_chase", bucket = bucket + 1 } }
        end,
        get = function(id) return id == 101 and { position = { x = 5, y = 6, z = 7 } } or nil end,
        getPlayerSeat = function(id) return id == 3 and { vehicleId = 101, seat = 0 } or nil end,
        forcePlayerOutOfVehicle = function() return true end,
    }
    local mark = { position = { x = 1, y = 2, z = 3 }, yaw = 75.5 }
    local id, record = W.createCar(ChaseConfig.vehicles.runner, mark, 4300003)
    assert(id == 101 and record == "Vehicle.v_standard2_archer_hella_player")
    assert(created[1].bucket == 4300003 and created[1].yaw == 75.5 and created[1].flags == (1 | 2), "engine + lights")
    -- The NCPD livery refused: the plain chassis, still with the siren flag.
    id, record = W.createCar(ChaseConfig.vehicles.cop, mark, 4300003)
    assert(id == 103 and record == "Vehicle.v_standard2_villefort_cortes_player" and created[3].flags == (1 | 2 | 16))
    assert(W.carPosition(101).x == 5 and W.carPosition(999) == nil)
    assert(W.seat(3) == 101 and W.seat(4) == nil)
    assert(W.forceOut(3, 101) == true)
    -- The sweep only removes this resource's cars in that bucket.
    assert(W.sweepBucket(4300003) == 1 and removed[1] == 1)
    assert(W.removeCar(101) == true and W.removeCar(nil) == false)
    Open77.vehicles = nil
    assert(W.createCar(ChaseConfig.vehicles.runner, mark, 1) == nil and W.sweepBucket(1) == 0 and W.seat(3) == nil)
    print("PASS world cars")
end

-- ── ChaseWorld: presentation ──
do
    local W = ChaseWorld
    local sent = {}
    Open77.notifications = { send = function(id, n) sent[#sent + 1] = { id = id, n = n } end }
    W.notify(3, "warning", "GO.", 3000)
    assert(sent[1].id == 3 and sent[1].n.type == "warning" and sent[1].n.title == "NCPD Chase" and sent[1].n.durationMs == 3000)
    env.client = {}
    W.hud(3, { state = "active" }); W.queueHud(3, { queued = true })
    W.reply(3, "/chase", true, "ok"); W.reply(0, "chase.status", true, "console only")
    assert(env.client[1].name == "op77_chase:hud" and env.client[2].name == "op77_chase:queue")
    assert(env.client[3].name == "open77:command:result" and env.client[3].args[2] == true and #env.client == 3)
    Open77.notifications = nil
    W.notify(3, "info", "silent") -- no notifications resource: nothing, no error
    print("PASS world presentation")
end

print("PASS: op77_chase adapters (contract calls, raising exports, status dedupe, placement teleport/respawn/failures, cars + fallback + sweep, HUD/notify/reply)")
