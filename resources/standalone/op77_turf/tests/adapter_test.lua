-- op77_turf adapters: TurfCore (the Light RP activity contract) and TurfWorld (the
-- natives), with the host stubbed.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test adapter_test.lua
local env

local function stubs()
    env = { calls = {}, events = {}, client = {}, answers = {}, raise = nil, handlers = {}, natives = {}, life = {},
        positions = {}, weapons = {}, nextRequest = 0 }
    local function record(name, ...) env.natives[#env.natives + 1] = { name = name, args = table.pack(...) } end
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
        time = { monotonic = function() return 12.3456 end, unix = function() return 1793577600.5 end },
        players = {
            position = function(id) return env.positions[id] end,
            getLifeState = function(id) return env.life[id] and { phase = env.life[id] } or nil end,
            name = function(id) return "P" .. id end,
            respawn = function(id, opts) record("respawn", id, opts); env.life[id] = "alive"; return true end,
            teleport = function(id, position, opts)
                record("teleport", id, position, opts)
                if env.life[id] ~= "alive" then return nil, "player_dead" end
                return { await = function() return true end }
            end,
            setFrozen = function(id, frozen) record("setFrozen", id, frozen); return true end,
            get = function(id) return { heading = 123.4, position = env.positions[id] } end,
        },
        combat = {
            setTeam = function(id, team) record("setTeam", id, team); return true end,
            createScope = function(opts) record("createScope", opts); return "scope-1" end,
            removeScope = function(scope) record("removeScope", scope); return true end,
        },
        notifications = { send = function(id, n) record("notify", id, n) end },
    }
    -- Open77.weapons: every request is answered at once through open77:weapons:completed.
    local function answer(player, op, result)
        env.nextRequest = env.nextRequest + 1
        local request = env.nextRequest
        env.weapons[#env.weapons + 1] = { player = player, op = op }
        for _, h in ipairs(env.handlers["open77:weapons:completed"] or {}) do h(player, request, op, true, nil, result) end
        return request
    end
    Open77.weapons = {
        clear = function(p) return answer(p, "clear") end,
        assign = function(p, record) return answer(p, "assign:" .. tostring(record)) end,
        setAmmo = function(p, slot) return answer(p, "setAmmo:" .. slot) end,
        setActive = function(p, slot) return answer(p, "setActive:" .. slot) end,
        requestSnapshot = function(p)
            return answer(p, "snapshot", { slots = {
                { slot = 1, record = env.kitPrimary, ammo = { capacity = 30, magazine = 30, reserve = 300, total = 330 } },
                { slot = 2, record = "x", ammo = { capacity = 12 } } } })
        end,
    }
    _G.TriggerEvent = function(name, ...) env.events[#env.events + 1] = { name = name, args = table.pack(...) } end
    _G.TriggerClientEvent = function(name, target, ...) env.client[#env.client + 1] = { name = name, target = target, args = table.pack(...) } end
    _G.AddEventHandler = function(name, fn) env.handlers[name] = env.handlers[name] or {}; table.insert(env.handlers[name], fn) end
    _G.CreateThread = function(fn) fn() end
    _G.Wait = function() end
    _G.GetCurrentResourceName = function() return "op77_turf" end
    _G.GetPlayers = function() return { "3", "7" } end
    _G.SetRoutingBucketPopulationEnabled = function(b, on) record("population", b, on) end
    _G.SetRoutingBucketEntityLockdownMode = function(b, mode) record("lockdown", b, mode) end
    _G.exports = setmetatable({}, { __index = function() error("no such resource") end })
end

local function pack(...) local t = table.pack(...); t.multi = true; return t end
local function natives(name)
    local out = {}
    for _, n in ipairs(env.natives) do if n.name == name then out[#out + 1] = n end end
    return out
end

stubs()
dofile("shared/config.lua")
dofile("server/rules.lua")
dofile("server/core.lua")
dofile("server/world.lua")

-- ---------------------------------------------------------------- TurfCore
do
    local C = TurfCore
    local def = C.definition()
    assert(def.id == "turf.war" and def.kind == "pvp" and def.resource == "op77_turf")
    assert(def.minPlayers == 6 and def.maxPlayers == 24)
    assert(def.caps.rpWeapons == false and def.caps.rpItems == false and def.caps.needs == false and def.caps.vehicles == false)
    assert(def.modeKey == "site" and #def.modes == 2 and def.modes[1].id == "kabuki" and def.modes[2].id == "badlands",
        "the enabled sites are the join choices; the staff-only site is not offered")

    env.answers.activityRegister = true
    assert(C.register(def) == true)
    assert(env.calls[1].resource == "op77_lightrp" and env.calls[1].name == "activityRegister" and env.calls[1].args[1] == def)
    env.answers.activityRegister = pack(false, "duplicate id")
    local ok, why = C.register(def)
    assert(ok == false and why == "duplicate id")

    env.calls = {}
    env.answers.activityCheck = pack(false, "You are in a vehicle.")
    ok, why = C.check(7)
    assert(ok == false and why == "You are in a vehicle.", "Light RP's sentence reaches the player")
    assert(env.calls[1].args[1] == 7 and env.calls[1].args[2] == "turf.war")
    env.answers.activityCheck = true
    assert(C.check(7) == true)
    env.answers.activityEnter = false
    ok, why = C.enter(7)
    assert(ok == false and why == "You cannot join a turf war right now.", "a bare false still gets a sentence")

    -- A synchronous export raises when the call fails: never reaches the caller.
    env.raise = "export_yielded"
    ok, why = C.enter(7)
    assert(ok == false and why:find("did not answer"), "a transport failure becomes a generic sentence")
    assert(C.owner(7) == nil and C.player(7) == nil)
    ok, why = C.leave(7)
    assert(ok == false and tostring(why):find("export_yielded"))
    env.raise = nil

    env.calls = {}
    env.answers.activityLeave = true
    assert(C.leave(7) == true)
    assert(env.calls[1].args[3].returnPlayer == true, "returnPlayer by default")
    env.answers.activityOwner = "turf.war"
    assert(C.owned(7) == true)
    env.answers.activityOwner = "missions"
    assert(C.owned(7) == false)
    env.answers.activityPlayer = { name = "Vee", identifier = "license:1", characterKey = "c1", gang = { id = "valentinos" } }
    assert(C.player(7).gang.id == "valentinos")

    -- result / status / announce are host-wide events.
    env.events = {}
    C.result(7, { placement = 1, score = 50, won = true, stats = { captures = 2 }, reputation = 40 })
    assert(env.events[1].name == "op77_lightrp:activity:result" and env.events[1].args[1] == 7 and env.events[1].args[2] == "turf.war")
    assert(env.events[1].args[3].stats.captures == 2)
    assert(C.status({ phase = "idle", players = 0, queued = 0, joinable = true, detail = "x" }) == true)
    assert(C.status({ phase = "idle", players = 0, queued = 0, joinable = true, detail = "x" }) == false, "on change only")
    assert(C.status({ phase = "lobby", players = 0, queued = 3, joinable = true, detail = "x" }) == true)
    assert(C.status({ phase = "lobby", players = 0, queued = 3, joinable = true, detail = "x" }, true) == true, "forced")
    assert(env.events[#env.events].name == "op77_lightrp:activity:status" and env.events[#env.events].args[1] == "turf.war")
    C.announce("TURF WAR at Kabuki Market in 5 min.")
    local last = env.events[#env.events]
    assert(last.name == "op77_lightrp:announce" and last.args[1]:find("Kabuki") and last.args[2].title == "TURF WAR")
end

-- ---------------------------------------------------------------- TurfWorld
do
    local W = TurfWorld
    assert(W.now() == 12345, "monotonic milliseconds")
    assert(W.unix() == 1793577600)
    env.positions[3] = { x = 1, y = 2, z = 3, bucket = 4400001 }
    assert(W.position(3).bucket == 4400001 and W.position(9) == nil)
    env.life[3] = "alive"
    env.life[7] = "respawnpending"
    assert(W.alive(3) == true and W.alive(7) == false and W.alive(9) == nil, "unknown is never down")
    assert(W.isDown("dead") and W.isDown("respawnpending") and not W.isDown("alive") and not W.isDown("recovering"))
    assert(W.connected(3) and W.connected(7) and not W.connected(9))
    assert(W.name(3) == "P3")

    W.setupBucket(4400001)
    assert(#natives("population") == 1 and natives("population")[1].args[2] == false)
    assert(natives("lockdown")[1].args[2] == "relaxed")

    -- place: a living player is teleported into the bucket, a dead one respawned there.
    local results = {}
    W.place(3, { x = 10, y = 20, z = 30, heading = 90 }, 4400001, function(ok, why) results[#results + 1] = { ok, why } end)
    local tp = natives("teleport")[1]
    assert(results[1][1] == true and tp.args[3].bucket == 4400001 and tp.args[3].heading == 90 and tp.args[3].dismount == true)
    env.life[7] = "dead"
    W.place(7, { x = 10, y = 20, z = 30, heading = 0 }, 4400001, function(ok, why) results[#results + 1] = { ok, why } end)
    assert(results[2][1] == true and natives("respawn")[1].args[2].bucket == 4400001, "the dead are respawned in place of a teleport")
    env.life[7] = "dead"
    local ok = W.respawn(7, { x = 1, y = 2, z = 3, heading = 45 }, 4400001)
    assert(ok == true and natives("respawn")[2].args[2].heading == 45)
    assert(W.freeze(3, true) == true and natives("setFrozen")[1].args[2] == true)

    -- combat
    assert(W.setTeam(3, 4401) == true and natives("setTeam")[1].args[2] == 4401)
    assert(W.setTeam(3, nil) == true and natives("setTeam")[2].args[2] == 0)
    local scope = W.createScope(4400001, { 3, 7 })
    assert(scope == "scope-1" and natives("createScope")[1].args[1].bucket == 4400001 and #natives("createScope")[1].args[1].players == 2)
    assert(W.removeScope(scope) == true)
    local saved = Open77.combat.createScope
    Open77.combat.createScope = nil
    local none, why = W.createScope(4400001, { 3, 7 })
    assert(none == nil and why == "scope_api_unavailable", "an older host: no scope, a reason")
    Open77.combat.createScope = saved

    -- kits: clear, primary, secondary, reserves, magazines, draw - then a check.
    local kit = TurfConfig.kits[1]
    env.kitPrimary = kit.primary
    env.weapons = {}
    W.equip(3, kit, function() return true end)
    local ops = {}
    for _, w in ipairs(env.weapons) do ops[#ops + 1] = w.op end
    local seq = table.concat(ops, " ")
    assert(seq:find("^clear assign:" .. kit.primary:gsub("%p", "%%%0") .. " assign:" .. kit.secondary:gsub("%p", "%%%0")), seq)
    assert(seq:find("setActive:1 snapshot$"), "drawn, then verified: " .. seq)
    -- A kit superseded (new life / war over) stops between steps.
    env.weapons = {}
    W.equip(3, kit, function() return false end)
    assert(#env.weapons == 0)
    assert(W.clearKit(3) == true)

    -- presentation
    env.client = {}
    W.state(3, { phase = "running" }, { id = 3 })
    W.push(3, "banner", { title = "FIGHT" })
    W.clear(3)
    assert(env.client[1].name == "op77_turf:state" and env.client[1].target == 3)
    assert(env.client[2].name == "op77_turf:push" and env.client[2].args[1] == "banner")
    assert(env.client[3].name == "op77_turf:clear")
    W.notify(3, "info", "hello")
    local n = natives("notify")
    assert(n[#n].args[2].title == "Turf War" and n[#n].args[2].message == "hello")
    W.reply(3, "/turf", true, "done")
    assert(env.client[#env.client].name == "open77:command:result" and env.client[#env.client].args[3] == "done")
    local p, heading = W.pose(3)
    assert(p.x == 1 and heading == 123.4)
end

print("PASS adapter_test: TurfCore contract calls (register/check/enter/leave/owner/player, result/status/announce), TurfWorld wrappers (place, respawn, teams, scope, kits, presentation)")
