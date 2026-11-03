-- server/lightrp.lua against a fake engine and a stubbed host: admission, entry,
-- moves, the way home, the core's requests, duels, results, statuses, Arena Night.
-- Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test adapter_test.lua
local say = print
_G.print = function() end

local T = 1000000
local env

local function pack(...) local t = table.pack(...); t.multi = true; return t end

local function reset()
    env = {
        calls = {}, events = {}, client = {}, answers = {}, timers = {}, handlers = env and env.handlers or {},
        commands = env and env.commands or {}, net = env and env.net or {}, threads = {},
        life = {}, positions = {}, respawns = {}, teleports = {}, kills = {}, health = {}, holds = {},
        online = { [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },
        resourceState = "running", awaitResult = { true },
    }
    env.answers.activityCheck = true
    env.answers.activityEnter = true
    env.answers.activityLeave = true
    env.answers.activityRegister = true
    env.answers.activityPlayer = function(id) return { name = "Char" .. id, identifier = "license:" .. id, characterKey = "1" } end
end
reset()

_G.Open77 = {
    exports = {
        callSync = function(resource, name, ...)
            env.calls[#env.calls + 1] = { resource = resource, name = name, args = table.pack(...) }
            local answer = env.answers[name]
            if type(answer) == "function" then return answer(...) end
            if type(answer) == "table" and answer.multi then return table.unpack(answer, 1, answer.n) end
            return answer
        end,
    },
    players = {
        name = function(id) return env.online[id] and ("acct" .. id) or nil end,
        getLifeState = function(id) return env.life[id] and { phase = env.life[id] } or nil end,
        position = function(id) return env.positions[id] end,
        respawn = function(id, opts)
            env.respawns[#env.respawns + 1] = { id = id, opts = opts }
            env.life[id] = "alive"
            return true
        end,
        teleport = function(id, pos, opts)
            env.teleports[#env.teleports + 1] = { id = id, pos = pos, opts = opts }
            if env.teleportRefusal then return nil, env.teleportRefusal end
            local result = env.awaitResult
            return { await = function() return table.unpack(result) end }
        end,
        kill = function(id, opts) env.kills[#env.kills + 1] = { id = id, opts = opts }; env.life[id] = "dead"; return true end,
        getHealth = function(id) return { health = 50, maxHealth = 300 } end,
        setHealth = function(id, value) env.health[#env.health + 1] = { id = id, value = value }; return true end,
    },
    time = { unix = function() return 86400 * 20000 + 10 end },
}
_G.TriggerEvent = function(name, ...) env.events[#env.events + 1] = { name = name, args = table.pack(...) } end
_G.TriggerClientEvent = function(name, target, ...) env.client[#env.client + 1] = { name = name, target = target, args = table.pack(...) } end
_G.AddEventHandler = function(name, fn) env.handlers[name] = env.handlers[name] or {}; table.insert(env.handlers[name], fn) end
_G.RegisterNetEvent = function(name, fn) env.net[name] = fn end
_G.RegisterCommand = function(name, fn, restricted) env.commands[name] = { fn = fn, restricted = restricted } end
_G.SetTimeout = function(ms, fn) env.timers[#env.timers + 1] = fn end
_G.Wait = function() end
_G.GetCurrentResourceName = function() return "op77_arena" end
_G.GetResourceState = function() return env.resourceState end
_G.GetPlayers = function() local out = {} for id in pairs(env.online) do out[#out + 1] = tostring(id) end return out end

local loading = true
_G.CreateThread = function(fn) if loading then env.threads[#env.threads + 1] = fn else fn() end end

local function fire(name, ...) for _, fn in ipairs(env.handlers[name] or {}) do fn(...) end end
local function flush() local timers = env.timers; env.timers = {}; for _, fn in ipairs(timers) do fn() end end
local function clientEvents(name, target)
    local out = {}
    for _, e in ipairs(env.client) do if e.name == name and (target == nil or e.target == target) then out[#out + 1] = e end end
    return out
end
local function callsOf(name)
    local out = {}
    for _, c in ipairs(env.calls) do if c.name == name then out[#out + 1] = c end end
    return out
end
local function eventsOf(name)
    local out = {}
    for _, e in ipairs(env.events) do if e.name == name then out[#out + 1] = e end end
    return out
end

dofile("shared/config.lua")
dofile("shared/kabuki.lua")
dofile("shared/wire.lua")
dofile("shared/lightrp.lua")

-- ---------------------------------------------------------------------------
-- A fake engine with the real seams: every internal call goes through the table,
-- exactly as the engine resolves Deathmatch.place / .sendToLobby at call time.

local fake = { joins = {}, enqueues = {}, leaves = {}, places = {}, strips = {}, notices = {}, finishes = {} }
local members = {}      -- playerId -> instance
local queues = { ["1v1"] = {}, ["2v2"] = {}, ["3v3"] = {} }
local nextInstance = 1
local DM

local function attach(instance, id)
    members[id] = instance
    instance.members[id] = true
    instance.order[#instance.order + 1] = id
end
local function detach(id)
    local instance = members[id]
    if instance then instance.members[id] = nil end
    members[id] = nil
end
local function newInstance(format, ruleset)
    local instance = { id = nextInstance, format = format, ruleset = ruleset or "standard", members = {}, order = {},
        capacity = format == "ffa" and 16 or 2, bucket = 4100000 + nextInstance, rows = {}, tune = { roundSeconds = 300, killLimit = 25 } }
    nextInstance = nextInstance + 1
    DM.instances.registry[instance.id] = instance
    return instance
end
local function queuePosition(id)
    for _, format in ipairs({ "1v1", "2v2", "3v3" }) do
        for index, entry in ipairs(queues[format]) do if entry.id == id then return index, format end end
    end
    return nil
end

Deathmatch = {
    nowMs = function() return T end,
    playerId = function(v) local n = tonumber(v); return n and math.floor(n) or nil end,
    log = function() end,
    notice = function(id, kind, key, ...) fake.notices[#fake.notices + 1] = { id = id, kind = kind, key = key, args = table.pack(...) } end,
    playerName = function(id) return "acct" .. tostring(id) end,
    broadcastState = function() end,
    bounds = { hold = function(id, ms) env.holds[#env.holds + 1] = { id = id, ms = ms } end },
    scoring = { rows = function(instance) return instance and instance.rows or {} end },
    loadout = {
        strip = function(id) fake.strips[#fake.strips + 1] = id; return true end,
        bladeList = function() return { { key = "katana" }, { key = "knife" } } end,
        primaryList = function() return { { key = "ajax" } } end,
        chosenPrimary = function() return { key = "ajax" } end,
        chooseBlade = function() return true end,
        chooseWeapons = function(_, key) return key == "ajax", key end,
        kitList = function() return { { key = "rifle" } } end,
    },
    instances = {
        registry = {},
        of = function(id) return members[id] end,
        humans = function(instance)
            local out = {}
            for _, id in ipairs(instance.order) do if instance.members[id] and id > 0 then out[#out + 1] = id end end
            return out
        end,
        open = function(format, ruleset) return newInstance(format, ruleset) end,
        botCount = function() return 0 end,
    },
    round = {
        join = function(id, ruleset)
            fake.joins[#fake.joins + 1] = { id = id, ruleset = ruleset }
            local instance
            for _, i in pairs(DM.instances.registry) do
                if i.format == "ffa" and i.ruleset == ruleset and not i.closed then instance = i end
            end
            instance = instance or DM.instances.open("ffa", ruleset)
            attach(instance, id)
            DM.place(id, instance, "join", 5000)
            return instance
        end,
        finish = function(instance, reason, winnerId)
            fake.finishes[#fake.finishes + 1] = { instance = instance, reason = reason }
            instance.round = instance.round or {}
            instance.round.state = "standings"
            instance.round.result = { winnerId = winnerId, reason = reason }
            return true
        end,
    },
    arena = {
        enqueue = function(id, format, bots)
            fake.enqueues[#fake.enqueues + 1] = { id = id, format = format, bots = bots }
            local queue = queues[format]
            queue[#queue + 1] = { id = id }
            if format == "1v1" and #queue >= 2 then
                local a, b = queue[1].id, queue[2].id
                queues[format] = {}
                local instance = DM.instances.open("1v1")
                instance.match = { sides = { [a] = 1, [b] = 2 }, state = "playing", wins = { 0, 0 } }
                attach(instance, a); attach(instance, b)
                DM.place(a, instance, "arena_round", 5000)
                DM.place(b, instance, "arena_round", 5000)
            end
            return #queue, format
        end,
        queuePosition = queuePosition,
        queueCounts = function() return { ["1v1"] = #queues["1v1"], ["2v2"] = #queues["2v2"], ["3v3"] = #queues["3v3"] } end,
        pickKit = function() return true end,
    },
    place = function(id, instance, reason, graceMs, mark)
        fake.places[#fake.places + 1] = { id = id, instance = instance, reason = reason }
        return true
    end,
    sendToLobby = function() error("the engine's lobby placement must never run in Light RP") end,
    leave = function(id, scope)
        fake.leaves[#fake.leaves + 1] = { id = id, scope = scope }
        if scope == "queue" then
            local _, format = queuePosition(id)
            if format == nil then return false end
            for index = #queues[format], 1, -1 do if queues[format][index].id == id then table.remove(queues[format], index) end end
            DM.notice(id, "info", "queueLeft")
            return true
        end
        if members[id] == nil then return false end
        DM.loadout.strip(id)
        detach(id)
        DM.sendToLobby(id, "left_match")
        DM.notice(id, "info", "leftMatch")
        return true
    end,
}
DM = Deathmatch
local engineStrip = DM.loadout.strip

dofile("server/core.lua")
dofile("server/lightrp.lua")
dofile("server/lightrp_recap.lua")
loading = false
local H = ArenaHost

-- A clean slate between sections: no member, queue, entry or invite left over.
local function clean()
    for _, t in ipairs({ H.entered, H.returning, H.released, H.recent, H.throttle, H.checks, H.invites,
        H.evicting, H.lastQueued, members, DM.instances.registry }) do
        for k in pairs(t) do t[k] = nil end
    end
    H.duelQueue = {}
    queues["1v1"], queues["2v2"], queues["3v3"] = {}, {}, {}
    H.night = nil
end

-- ── wiring ──
do
    assert(DM.sendToLobby == H.returnHome, "the way home is ours")
    assert(type(DM.moveBody) == "function" and type(DM.wantsState) == "function")
    assert(FreeroamPvp and type(FreeroamPvp.entryFailure) == "function")
    assert(#env.threads == 1, "one tick loop, not started at load")
    assert(env.commands["arena.night"].restricted == true, "Arena Night is staff only")
    for _, name in ipairs({ "arena", "arena.ffa", "arena.blade", "arena.pve", "arena.queue", "arena.leave", "arena.weapon", "arena.kit", "duel" }) do
        assert(env.commands[name] and env.commands[name].restricted == false, name)
    end
    -- Bucket range and hosted switches.
    local B = DeathmatchConfig.buckets
    assert(B.lobby == 0 and B.ffaFirst >= 4100000 and B.arenaLast <= 4199999 and DeathmatchConfig.blade.bucket == 4100001)
    assert(DeathmatchConfig.freeroam == true and DeathmatchConfig.placeOnJoin == false)
    assert(DeathmatchConfig.tunables.fillWithBots.value == false and DeathmatchConfig.tunables.arenaFillWithBots.value == false)
    for _, weapon in ipairs(DeathmatchConfig.blade.weapons) do
        assert(not weapon.key:find("mantis"), "no Mantis Blades: implants are Light RP's")
    end
    assert(DeathmatchConfig.career.tablePrefix == "op77_arena_")
    say("PASS wiring")
end

-- ── registration ──
do
    fire("onResourceStart", "op77_arena")
    local registered = callsOf("activityRegister")
    assert(#registered == 5)
    local seen = {}
    for _, c in ipairs(registered) do
        local def = c.args[1]
        seen[def.id] = def
        assert(def.resource == "op77_arena" and def.kind == "pvp")
        assert(def.caps.rpWeapons == false and def.caps.rpItems == false and def.caps.needs == false and def.caps.vehicles == false)
    end
    assert(seen["arena.ffa"] and seen["arena.blade"] and seen["arena.duel"] and seen["arena.teams"] and seen["arena.pve"])
    assert(seen["arena.pve"].minPlayers == 1, "PvE is open to one player")
    assert(seen["arena.teams"].modes[1].id == "2v2" and seen["arena.duel"].minPlayers == 2)
    assert(#eventsOf("op77_lightrp:activity:status") == 5, "statuses forced after registering")
    -- Light RP restarting: register again.
    env.calls = {}
    fire("op77_lightrp:activity:ready")
    assert(#callsOf("activityRegister") == 5)
    say("PASS registration")
end

-- ── Combat Zone: admission, entry on first placement ──
do
    env.calls, env.client = {}, {}
    env.answers.activityCheck = pack(false, "Step out of the vehicle first.")
    local instance = DM.round.join(3, nil)
    assert(instance == nil and #fake.joins == 0, "refused before the engine")
    local notices = clientEvents("op77_lightrp:notice", 3)
    assert(#notices == 1 and notices[1].args[1].body == "Step out of the vehicle first." and notices[1].args[1].title == "Combat Zone")
    local leaves = callsOf("activityLeave")
    assert(#leaves == 1 and leaves[1].args[3].returnPlayer == false, "the core's pending join is cleared")

    T = T + 1000
    env.calls, env.client = {}, {}
    env.answers.activityCheck = true
    env.life[3] = "alive"
    instance = DM.round.join(3, nil)
    assert(instance ~= nil and fake.joins[1].ruleset == "standard")
    local enter = callsOf("activityEnter")
    assert(#enter == 1 and enter[1].args[2] == "arena.ffa", "entered at the first placement")
    assert(fake.places[#fake.places].id == 3, "then the engine places")
    assert(H.entered[3] and H.entered[3].activity == "arena.ffa" and H.entered[3].instanceId == instance.id)
    assert(#clientEvents("op77_arena:entered", 3) == 1)
    assert(DM.playerName(3) == "Char3", "character name on the board")
    assert(DM.wantsState(3) == true and DM.wantsState(4) == false)

    -- Joining again is a no-op; Blade Night while in the Combat Zone is refused.
    assert(DM.round.join(3, nil) == instance)
    T = T + 1000
    assert(DM.round.join(3, "blade") == nil)
    -- Throttle: two attempts inside the window.
    env.calls = {}
    T = T + 1000
    DM.round.join(4, "blade")
    local before = #callsOf("activityCheck")
    detach(4); H.forget(4)
    DM.round.join(4, "blade")
    assert(#callsOf("activityCheck") == before, "throttled")
    say("PASS combat zone admission + entry")
end

-- ── the core refuses the entry: undone, nobody placed ──
do
    T = T + 5000
    env.calls, env.client = {}, {}
    local placesBefore = #fake.places
    env.answers.activityEnter = pack(false, "You were hurt less than a minute ago. Wait 40 s.")
    local instance = DM.round.join(5, nil)
    assert(#fake.places == placesBefore, "the engine never placed them")
    assert(H.entered[5] == nil and H.evicting[5] == true)
    flush()
    assert(fake.leaves[#fake.leaves].id == 5 and members[5] == nil, "assignment undone outside the engine loop")
    assert(H.evicting[5] == nil)
    env.answers.activityEnter = true
    say("PASS refused entry is undone")
end

-- ── moves: teleport the living, respawn the dead ──
do
    reset(); env.handlers = env.handlers
    H.entered[6] = { activity = "arena.ffa", atMs = T, instanceId = 1, landed = false, totals = { kills = 0, deaths = 0 } }
    local pos = { x = 1, y = 2, z = 3 }
    assert(DM.moveBody(6, pos, 90, 4100000, "join", 5000, { phase = "alive" }) == true)
    local tp = env.teleports[1]
    assert(tp.opts.bucket == 4100000 and tp.opts.fade == true and tp.opts.dismount == true and tp.opts.heading == 90)
    assert(env.health[1].value == 300, "full health for the round")
    assert(H.entered[6].landed == true)
    assert(#env.kills == 0, "never kill -> respawn as a way in")

    assert(DM.moveBody(6, pos, 0, 4100000, "death_respawn", 5000, { phase = "dead" }) == true)
    local rs = env.respawns[1]
    assert(rs.opts.bucket == 4100000 and rs.opts.health == 1.0 and rs.opts.position.x == 1)

    local ok, why = DM.moveBody(6, pos, 0, 4100000, "x", 5000, { phase = "respawnpending" })
    assert(ok == false and why:find("transition_in_progress"))
    -- Recovering outside the arena bucket: refused (no kill as a way in).
    env.positions[6] = { x = 0, y = 0, z = 0, bucket = 0 }
    ok = DM.moveBody(6, pos, 0, 4100000, "x", 5000, { phase = "recovering" })
    assert(ok == false and #env.kills == 0)
    env.positions[6].bucket = 4100000
    assert(DM.moveBody(6, pos, 0, 4100000, "x", 5000, { phase = "recovering" }) == true and #env.kills == 1)

    -- A synchronous teleport refusal is a failed placement.
    env.teleportRefusal = "player_in_vehicle"
    ok, why = DM.moveBody(6, pos, 0, 4100000, "x", 5000, { phase = "alive" })
    assert(ok == false and why == "teleport:player_in_vehicle")
    env.teleportRefusal = nil

    -- The first move in fails: out again. A superseded move is left to the newer one.
    local left = #fake.leaves
    members[7] = DM.instances.registry[1]
    H.entered[7] = { activity = "arena.ffa", atMs = T, instanceId = 1, landed = false, totals = { kills = 0, deaths = 0 } }
    env.awaitResult = { false, "settle_superseded" }
    DM.moveBody(7, pos, 0, 4100000, "join", 5000, { phase = "alive" })
    assert(#fake.leaves == left, "superseded: nothing to undo")
    env.awaitResult = { false, "settle_timeout" }
    env.answers.activityLeave = true
    DM.moveBody(7, pos, 0, 4100000, "join", 5000, { phase = "alive" })
    assert(fake.leaves[#fake.leaves].id == 7, "a failed first move takes them out")
    env.awaitResult = { true }
    say("PASS moves")
end

-- ── the strip guard and the way home ──
do
    local strips = #fake.strips
    DM.loadout.strip(42)
    assert(#fake.strips == strips, "never strip someone the arena never armed")

    reset()
    local instance = DM.instances.registry[1]
    attach(instance, 8)
    H.entered[8] = { activity = "arena.ffa", atMs = T, instanceId = instance.id, landed = true, totals = { kills = 0, deaths = 0 } }
    env.life[8] = "dead"
    env.positions[8] = { x = 5, y = 6, z = 7, bucket = 4100000 }
    strips = #fake.strips
    DM.leave(8, "auto")
    assert(#fake.strips > strips and fake.strips[#fake.strips] == 8, "arena weapons removed on the way out")
    assert(#clientEvents("deathmatch:boundsClear", 8) >= 1)
    assert(env.respawns[1].id == 8 and env.respawns[1].opts.bucket == 4100000, "stood up where they lay first")
    local leave = callsOf("activityLeave")
    assert(#leave == 1 and leave[1].args[2] == "arena.ffa" and leave[1].args[3].returnPlayer == true)
    assert(#env.teleports == 0, "Light RP moves them home, not us")
    assert(H.entered[8] == nil and H.returning[8] == nil and H.recent[8] > T)
    assert(#clientEvents("op77_arena:returned", 8) == 1)
    assert(DM.wantsState(8) == true, "a last state for the HUD")

    -- The core refuses the leave and the player is stuck in an arena bucket: The Crossing.
    reset()
    attach(instance, 8)
    H.entered[8] = { activity = "arena.ffa", atMs = T, instanceId = instance.id, landed = true, totals = { kills = 0, deaths = 0 } }
    env.life[8] = "alive"
    env.positions[8] = { x = 5, y = 6, z = 7, bucket = 4100000 }
    env.answers.activityLeave = pack(false, "That player is not in this activity.")
    DM.leave(8, "auto")
    assert(#env.teleports == 1 and env.teleports[1].opts.bucket == 0 and env.teleports[1].pos.x == DeathmatchConfig.lobby.center.x)
    env.answers.activityLeave = true
    say("PASS strip guard + way home")
end

-- ── the core's requests: join, leaveRequest, dropped ──
do
    reset()
    T = T + 10000
    fire("op77_lightrp:activity:join", 4, "arena.teams", { mode = "3v3", from = "panel" })
    local q = fake.enqueues[#fake.enqueues]
    assert(q.id == 4 and q.format == "3v3" and q.bots == false)
    -- A bots request is never honoured.
    T = T + 10000
    DM.arena.enqueue(5, "2v2", true)
    assert(fake.enqueues[#fake.enqueues].bots == false)
    -- Duels never enter the engine's 1v1 queue directly.
    local count = #fake.enqueues
    assert(DM.arena.enqueue(6, "1v1") == nil and #fake.enqueues == count)

    -- leaveRequest for a queued player: out of the engine queue.
    fire("op77_lightrp:activity:leaveRequest", 4, "arena.teams")
    assert(fake.leaves[#fake.leaves].id == 4 and fake.leaves[#fake.leaves].scope == "queue")

    -- leaveRequest in a match: DM.leave, then the way home.
    local instance = DM.instances.registry[1]
    attach(instance, 3)
    H.entered[3] = { activity = "arena.ffa", atMs = T, instanceId = instance.id, landed = true, totals = { kills = 0, deaths = 0 } }
    env.life[3] = "alive"
    fire("op77_lightrp:activity:leaveRequest", 3, "arena.ffa")
    assert(members[3] == nil and #callsOf("activityLeave") == 1 and H.entered[3] == nil)

    -- dropped: ownership already released, never activityLeave.
    env.calls = {}
    attach(instance, 3)
    H.entered[3] = { activity = "arena.ffa", atMs = T, instanceId = instance.id, landed = true, totals = { kills = 0, deaths = 0 } }
    local strips = #fake.strips
    fire("op77_lightrp:activity:dropped", 3, "arena.ffa", "timeout")
    assert(members[3] == nil and H.entered[3] == nil)
    assert(#callsOf("activityLeave") == 0, "dropped never calls activityLeave")
    assert(#fake.strips > strips, "arena weapons still removed")
    -- dropped for an activity we do not hold for that player: ignored.
    fire("op77_lightrp:activity:dropped", 3, "arena.duel", "timeout")
    say("PASS core requests")
end

-- ── duels: challenge, accept, formation, random queue ──
do
    reset()
    clean()
    T = T + 10000
    env.positions[3] = { x = 0, y = 0, z = 0, bucket = 0 }
    env.positions[4] = { x = 30, y = 0, z = 0, bucket = 0 }
    local ok, text = H.challenge(3, 4)
    assert(ok == false and text:find("Get within 15 m"))
    env.positions[4] = { x = 5, y = 0, z = 0, bucket = 0 }
    T = T + 1000
    ok, text = H.challenge(3, 3)
    assert(ok == false)
    ok, text = H.challenge(3, 99)
    assert(ok == false and text == "No player with that id.")
    T = T + 1000
    ok, text = H.challenge(3, 4)
    assert(ok == true and H.invites[4].from == 3)
    local invite = clientEvents("op77_lightrp:notice", 4)
    assert(invite[#invite].args[1].title == "DUEL CHALLENGE" and invite[#invite].args[1].body:find("Char3"))

    -- Accept: both leave any queue, both go through the engine's 1v1 queue together.
    T = T + 1000
    local noticeCount = #fake.notices
    ok, text = H.accept(4)
    assert(ok == true, text)
    local i3, i4 = members[3], members[4]
    assert(i3 ~= nil and i3 == i4 and i3.format == "1v1")
    assert(H.entered[3].activity == "arena.duel" and H.entered[4].activity == "arena.duel")
    assert(H.entered[3].side == 1 and H.entered[4].side == 2)
    for index = noticeCount + 1, #fake.notices do
        assert(fake.notices[index].key ~= "queueLeft" and fake.notices[index].key ~= "queued", "formation is silent")
    end
    assert(H.formingDuel == false)

    -- Random queue: the first waits, the second pairs.
    T = T + 10000
    assert(H.queueDuel(5) == true and H.duelQueued(5))
    assert(DM.wantsState(5) == true)
    T = T + 1000
    assert(H.queueDuel(6) == true)
    assert(members[5] ~= nil and members[5] == members[6] and not H.duelQueued(5))

    -- Expiry of an invite.
    T = T + 1000
    env.positions[7] = { x = 0, y = 0, z = 0, bucket = 0 }
    env.positions[8] = { x = 1, y = 0, z = 0, bucket = 0 }
    assert(H.challenge(7, 8) == true)
    T = T + 31000
    H.tick(T)
    assert(H.invites[8] == nil)
    say("PASS duels")
end

-- ── results and reputation ──
do
    reset()
    clean()
    T = T + 100000
    -- FFA round: three humans, all in for over 90 s.
    local ffa = DM.instances.open("ffa", "standard")
    for _, id in ipairs({ 3, 4, 5 }) do
        attach(ffa, id)
        H.entered[id] = { activity = "arena.ffa", atMs = T - 200000, instanceId = ffa.id, landed = true, totals = { kills = 0, deaths = 0 } }
    end
    ffa.round = { state = "active", startedAtMs = T - 120000, number = 4 }
    ffa.rows = {
        { id = 4, rank = 1, kills = 9, deaths = 2, score = 900, assists = 1, bestStreak = 5 },
        { id = 3, rank = 2, kills = 5, deaths = 4, score = 500, assists = 0, bestStreak = 2 },
        { id = 5, rank = 3, kills = 1, deaths = 8, score = 100, assists = 2, bestStreak = 1 },
    }
    DM.round.finish(ffa, "kill_limit", 4)
    local results = eventsOf("op77_lightrp:activity:result")
    assert(#results == 3)
    local byId = {}
    for _, e in ipairs(results) do byId[e.args[1]] = e.args[3] end
    assert(byId[4].won == true and byId[4].placement == 1 and byId[4].reputation == 30 and byId[4].stats.kills == 9)
    assert(byId[3].won == false and byId[3].reputation == 20 and byId[5].reputation == 15)
    assert(byId[4].stats.timeMs == nil, "no race time for a fight")
    assert(byId[4].cash == nil and byId[4].items == nil)
    -- every result carries the round's whole board for Light RP's end-of-match recap
    local board = byId[4].recap
    assert(board and board.matchId == "arena:" .. ffa.id .. ":4" and #board.rows == 3 and board.durationMs == 120000)
    assert(byId[3].recap.matchId == board.matchId and byId[5].recap.rows[1].placement == 1, "one board for the round")

    -- Too short or too few: stats only.
    env.events = {}
    ffa.round = { state = "active", startedAtMs = T - 30000, number = 5 }
    DM.round.finish(ffa, "time_limit", 4)
    for _, e in ipairs(eventsOf("op77_lightrp:activity:result")) do assert(e.args[3].reputation == 0) end

    -- Arena Night doubles, capped at 50.
    env.events = {}
    H.night = { untilMs = T + 3600000, minutes = 60 }
    ffa.round = { state = "active", startedAtMs = T - 120000, number = 6 }
    DM.round.finish(ffa, "kill_limit", 4)
    byId = {}
    for _, e in ipairs(eventsOf("op77_lightrp:activity:result")) do byId[e.args[1]] = e.args[3] end
    assert(byId[4].reputation == 50 and byId[3].reputation == 40 and byId[5].reputation == 30)
    -- The round forced over to start the night pays nothing.
    env.events = {}
    ffa.round = { state = "active", startedAtMs = T - 120000, number = 7 }
    DM.round.finish(ffa, "arena_night")
    for _, e in ipairs(eventsOf("op77_lightrp:activity:result")) do assert(e.args[3].reputation == 0) end
    H.night = nil

    -- A leaver mid-round: the round so far, no reputation.
    env.events = {}
    ffa.round = { state = "active", startedAtMs = T - 120000, number = 8 }
    DM.leave(5, "auto")
    results = eventsOf("op77_lightrp:activity:result")
    assert(#results == 1 and results[1].args[1] == 5 and results[1].args[3].reputation == 0 and results[1].args[3].stats.quit == true)
    assert(results[1].args[3].recap and #results[1].args[3].recap.rows == 3, "a leaver's recap: the round so far")

    -- Duel: best of three, winner 20 / loser 5, reported once, kills over all rounds.
    env.events = {}
    local duel = DM.instances.open("1v1")
    attach(duel, 6); attach(duel, 7)
    duel.match = { sides = { [6] = 1, [7] = 2 }, state = "playing", wins = { 1, 0 } }
    for _, id in ipairs({ 6, 7 }) do
        H.entered[id] = { activity = "arena.duel", atMs = T - 60000, instanceId = duel.id, landed = true, totals = { kills = 0, deaths = 0 } }
    end
    duel.round = { id = "x:1" }
    duel.rows = { { id = 6, kills = 1, deaths = 0 }, { id = 7, kills = 0, deaths = 1 } }
    H.tick(T)
    duel.round = { id = "x:2" }
    duel.rows = { { id = 6, kills = 1, deaths = 0 }, { id = 7, kills = 0, deaths = 1 } }
    duel.match.state = "resolved"
    duel.match.wins = { 2, 0 }
    duel.match.result = { reason = "best_of", winnerSide = 1, wins = { 2, 0 }, rounds = 2 }
    H.tick(T)
    H.tick(T + 500)
    results = eventsOf("op77_lightrp:activity:result")
    assert(#results == 2, "one result each, once")
    byId = {}
    for _, e in ipairs(results) do byId[e.args[1]] = e.args[3] end
    assert(byId[6].won == true and byId[6].placement == 1 and byId[6].reputation == 20 and byId[6].stats.kills == 2)
    assert(byId[7].won == false and byId[7].placement == 2 and byId[7].reputation == 5 and byId[7].stats.deaths == 2)
    assert(byId[6].stats.roundsWon == 2 and byId[7].stats.roundsLost == 2)
    local duelBoard = byId[6].recap
    assert(duelBoard and duelBoard.winnerSide == 1 and duelBoard.lines[1].value == "2 - 0" and duelBoard.matchId == byId[7].recap.matchId)
    for _, row in ipairs(duelBoard.rows) do
        if row.id == 6 then assert(row.kills == 2 and row.side == 1, "the match, not the last round") end
        if row.id == 7 then assert(row.deaths == 2 and row.side == 2) end
    end

    -- Same pair, same day: reputation for the first three only.
    local rewarded = 0
    for _ = 1, 4 do if H.duelRewardAllowed(6, 7) then rewarded = rewarded + 1 end end
    assert(rewarded == 2, "1 already used by the match above")

    -- Forfeit: no reputation.
    env.events = {}
    local teams = DM.instances.open("2v2")
    attach(teams, 3); attach(teams, 4)
    teams.match = { sides = { [3] = 1, [4] = 2 }, state = "resolved", wins = { 0, 1 },
        result = { reason = "opponents_left", winnerSide = 2, wins = { 0, 1 } } }
    for _, id in ipairs({ 3, 4 }) do
        H.entered[id] = { activity = "arena.teams", atMs = T, instanceId = teams.id, landed = true, totals = { kills = 0, deaths = 0 } }
    end
    H.tick(T)
    for _, e in ipairs(eventsOf("op77_lightrp:activity:result")) do assert(e.args[3].reputation == 0) end

    -- Quitting a live team match is a loss.
    env.events = {}
    local live = DM.instances.open("3v3")
    attach(live, 8)
    live.match = { sides = { [8] = 2 }, state = "playing", wins = { 1, 1 } }
    H.entered[8] = { activity = "arena.teams", atMs = T, instanceId = live.id, landed = true, totals = { kills = 3, deaths = 1 } }
    DM.leave(8, "auto")
    results = eventsOf("op77_lightrp:activity:result")
    assert(#results == 1 and results[1].args[3].won == false and results[1].args[3].placement == 2 and results[1].args[3].reputation == 0)
    say("PASS results + reputation")
end

-- ── statuses, queue bookkeeping, entryFailure ──
do
    reset()
    for id in pairs(DM.instances.registry) do DM.instances.registry[id] = nil end
    for id in pairs(members) do members[id] = nil end
    for id in pairs(H.entered) do H.entered[id] = nil end
    queues["2v2"], queues["1v1"], queues["3v3"] = {}, {}, {}
    ArenaCore.forgetStatuses()
    H.tick(T)
    local st = {}
    for _, e in ipairs(eventsOf("op77_lightrp:activity:status")) do st[e.args[1]] = e.args[2] end
    assert(st["arena.ffa"].phase == "idle" and st["arena.ffa"].joinable == true)
    assert(st["arena.duel"].phase == "idle" and st["arena.teams"].queued == 0)
    env.events = {}
    H.tick(T + 500)
    assert(#eventsOf("op77_lightrp:activity:status") == 0, "unchanged statuses are not resent")

    queues["2v2"] = { { id = 3 }, { id = 4 } }
    H.tick(T + 1000)
    st = {}
    for _, e in ipairs(eventsOf("op77_lightrp:activity:status")) do st[e.args[1]] = e.args[2] end
    assert(st["arena.teams"].phase == "lobby" and st["arena.teams"].queued == 2)

    -- The engine drops 3 from the queue (stale): the core's pending entry goes too.
    env.calls = {}
    queues["2v2"] = { { id = 4 } }
    H.tick(T + 1500)
    local leaves = callsOf("activityLeave")
    assert(#leaves == 1 and leaves[1].args[1] == 3 and leaves[1].args[2] == "arena.teams" and leaves[1].args[3].returnPlayer == false)

    -- entryFailure: cached, and a refusal is a sentence.
    env.calls = {}
    env.answers.activityCheck = pack(false, "You are on a mission. Finish or leave it first.")
    local why = FreeroamPvp.entryFailure(4)
    assert(why == "You are on a mission. Finish or leave it first.")
    FreeroamPvp.entryFailure(4)
    assert(#callsOf("activityCheck") == 1, "cached between engine ticks")
    flush()
    local cleared = callsOf("activityLeave")
    assert(#cleared >= 1, "the core's pending join is cleared outside the engine loop")
    for _, c in ipairs(cleared) do assert(c.args[2] == "arena.teams" and c.args[3].returnPlayer == false) end
    env.answers.activityCheck = true
    T = T + 5000
    assert(FreeroamPvp.entryFailure(4) == nil)
    say("PASS statuses + queue bookkeeping")
end

-- ── notices and names ──
do
    reset()
    clean()
    fake.notices = {}
    -- Outside a match: a Light RP notice, formatted.
    DM.notice(3, "info", "queued", 2, "Team Arena 2v2")
    local n = clientEvents("op77_lightrp:notice", 3)
    assert(#n == 1 and n[1].args[1].body == "Position 2 for Team Arena 2v2." and n[1].args[1].source == "COMBAT ZONE")
    assert(#fake.notices == 0)
    -- In a match: the engine's own event (the client turns it into a HUD banner).
    local instance = DM.instances.open("ffa", "standard")
    attach(instance, 3)
    DM.notice(3, "success", "roundWon")
    assert(#fake.notices == 1 and fake.notices[1].key == "roundWon")
    -- Spawn shield / resupply cards are dropped.
    DM.notice(3, "info", "protectionOn", 5)
    DM.notice(3, "info", "resupplied")
    assert(#fake.notices == 1)
    -- Bots never get notices.
    DM.notice(-1, "info", "roundWon")
    assert(#fake.notices == 1)
    say("PASS notices")
end

-- ── Arena Night ──
do
    reset()
    for id in pairs(DM.instances.registry) do DM.instances.registry[id] = nil end
    local ffa = DM.instances.open("ffa", "standard")
    ffa.round = { state = "active", startedAtMs = T, number = 1 }
    fake.finishes = {}
    local ok = H.nightStart(3, 30)
    assert(ok == true and H.night.minutes == 30)
    assert(fake.finishes[1].reason == "arena_night", "the running round ends; the next one plays night rules")
    assert(ffa.tune.killLimit == LightRpArena.night.killLimit and ffa.tune.roundSeconds == LightRpArena.night.roundSeconds)
    local announce = eventsOf("op77_lightrp:announce")
    assert(#announce == 1 and announce[1].args[2].title == "ARENA NIGHT", "announced through Light RP")
    -- A Combat Zone opened during the night gets the rules too.
    ffa.closed = true
    local fresh = DM.instances.open("ffa", "standard")
    assert(fresh.tune.killLimit == LightRpArena.night.killLimit)
    local blade = DM.instances.open("ffa", "blade")
    assert(blade.tune.killLimit == 25, "Blade Night keeps its rules")
    -- Expiry restores.
    H.tick(T + 31 * 60000)
    assert(H.night == nil and fresh.tune.killLimit == 25 and fresh.nightBase == nil)
    -- Without Light RP running: our own broadcast.
    env.resourceState = "stopped"
    env.events, env.client = {}, {}
    H.nightStart(3)
    assert(#eventsOf("op77_lightrp:announce") == 0 and clientEvents("op77_lightrp:notice", -1)[1].args[1].title == "ARENA NIGHT")
    H.nightStop("staff")
    say("PASS arena night")
end

-- ── disconnect and resource stop ──
do
    reset()
    clean()
    H.entered[3] = { activity = "arena.ffa", atMs = T, instanceId = 999, landed = true, totals = { kills = 0, deaths = 0 } }
    H.duelQueue = { { playerId = 3, atMs = T } }
    fire("onPlayerDisconnected", "3")
    assert(H.entered[3] == nil and not H.duelQueued(3) and H.names[3] == nil)

    H.entered[4] = { activity = "arena.ffa", atMs = T, instanceId = 1, landed = true, totals = { kills = 0, deaths = 0 } }
    local strips = #fake.strips
    fire("onResourceStop", "op77_arena")
    assert(H.stopped == true and #fake.strips == strips + 1, "arena weapons go before Light RP returns them")
    assert(DM.place(9, DM.instances.open("ffa", "standard"), "join") == false, "nothing enters a stopping provider")
    say("PASS disconnect + stop")
end

say("PASS: op77_arena adapter (wiring, registration, admission, entry, moves, way home, core requests, duels, results, statuses, notices, Arena Night, stop)")
