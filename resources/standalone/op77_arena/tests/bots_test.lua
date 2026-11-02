-- server/lightrp.lua: staff bot mode, crews and the PvE Combat Zone, against a fake
-- engine and a fake server/bots.lua. Covers the switch (event and activityBots at
-- registration), a solo Combat Zone filled with bots, team queues, a duel against a
-- bot, no record and no rating write with bots, cleanup, PvE sides, scaling and
-- results, and crews kept together.
-- Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test bots_test.lua
local say = print
_G.print = function() end

local T = 1000000
local env = {
    calls = {}, events = {}, client = {}, answers = {}, timers = {}, handlers = {}, commands = {}, net = {}, threads = {},
    life = {}, positions = {},
    online = {},
}
for id = 3, 12 do env.online[id] = true end
env.answers.activityCheck = true
env.answers.activityEnter = true
env.answers.activityLeave = true
env.answers.activityRegister = true
env.answers.activityBots = false
env.answers.activityPlayer = function(id) return { name = "Char" .. id, identifier = "license:" .. id, characterKey = "1" } end

_G.Open77 = {
    exports = {
        callSync = function(resource, name, ...)
            env.calls[#env.calls + 1] = { resource = resource, name = name, args = table.pack(...) }
            local answer = env.answers[name]
            if type(answer) == "function" then return answer(...) end
            return answer
        end,
    },
    players = {
        name = function(id) return env.online[id] and ("acct" .. id) or nil end,
        getLifeState = function(id) return { phase = env.life[id] or "alive" } end,
        position = function(id) return env.positions[id] end,
        respawn = function() return true end,
        teleport = function() return { await = function() return true end } end,
        kill = function() return true end,
        getHealth = function() return { health = 100, maxHealth = 100 } end,
        setHealth = function() return true end,
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
_G.GetResourceState = function() return "running" end
_G.GetPlayers = function() local out = {} for id in pairs(env.online) do out[#out + 1] = tostring(id) end table.sort(out) return out end
local loading = true
_G.CreateThread = function(fn) if loading then env.threads[#env.threads + 1] = fn else fn() end end

local function fire(name, ...) for _, fn in ipairs(env.handlers[name] or {}) do fn(...) end end
local function flush() local timers = env.timers; env.timers = {}; for _, fn in ipairs(timers) do fn() end end
local function results(id)
    local out = {}
    for _, e in ipairs(env.events) do
        if e.name == "op77_lightrp:activity:result" and (id == nil or e.args[1] == id) then out[#out + 1] = e.args[3] end
    end
    return out
end
local function lastResult(id) local r = results(id); return r[#r] end
local function noticesTo(id)
    local out = {}
    for _, e in ipairs(env.client) do if e.name == "op77_lightrp:notice" and e.target == id then out[#out + 1] = e.args[1] end end
    return out
end
local function queuedNotices(id)
    local n = 0
    for _, notice in ipairs(noticesTo(id)) do if notice.title == "QUEUED" or notice.title == "QUEUE" then n = n + 1 end end
    return n
end

dofile("shared/config.lua")
dofile("shared/kabuki.lua")
dofile("shared/wire.lua")
dofile("shared/lightrp.lua")
local L = LightRpArena

-- ---------------------------------------------------------------------------
-- The fake engine: the real seams, resolved through the tables at call time.

local fake = { enqueues = {}, leaves = {}, begins = {}, finishes = {}, teams = {}, ranked = {}, places = {}, notices = {} }
local members = {}
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
    local instance = { id = nextInstance, format = format, ruleset = ruleset or "standard", members = {}, order = {}, actors = {},
        capacity = format == "ffa" and 16 or (format == "1v1" and 2 or (format == "2v2" and 4 or 6)),
        bucket = 4100000 + nextInstance, rows = {} }
    nextInstance = nextInstance + 1
    DM.instances.registry[instance.id] = instance
    return instance
end
local function queuePosition(id)
    for _, format in ipairs({ "1v1", "2v2", "3v3" }) do
        for index, entry in ipairs(queues[format]) do if entry.playerId == id then return index, format end end
    end
    return nil
end

-- server/bots.lua, as far as the adapter uses it.
local bots = { adds = {}, clears = {}, dropped = {}, nextId = -1, live = {}, park = false }
DeathmatchBots = {
    count = function(instanceId)
        local n = 0
        for _, bot in pairs(bots.live) do if tostring(bot.instanceId) == tostring(instanceId) then n = n + 1 end end
        return n
    end,
    add = function(instanceId, count, profile)
        bots.adds[#bots.adds + 1] = { instanceId = instanceId, count = count, profile = profile }
        local added, queued = 0, 0
        for _ = 1, count do
            if bots.park then
                queued = queued + 1
            else
                local id = bots.nextId
                bots.nextId = id - 1
                bots.live[id] = { participantId = id, instanceId = instanceId }
                DM.instances.registry[instanceId].actors[id] = true
                added = added + 1
            end
        end
        return added, queued > 0 and "spacing" or nil, queued
    end,
    clear = function(instanceId, reason)
        bots.clears[#bots.clears + 1] = { instanceId = instanceId, reason = reason }
        local removed = 0
        for id, bot in pairs(bots.live) do
            if instanceId == nil or tostring(bot.instanceId) == tostring(instanceId) then
                bots.live[id] = nil
                local instance = DM.instances.registry[bot.instanceId]
                if instance then instance.actors[id] = nil end
                removed = removed + 1
            end
        end
        return removed
    end,
    dropPending = function(instanceId) bots.dropped[#bots.dropped + 1] = instanceId or "all"; return 0 end,
    get = function(id) return bots.live[id] end,
}
-- A parked spawn arriving (bots.lua's tick spending `pendingSpawns`).
local function arrive(instance, n)
    for _ = 1, n do
        local id = bots.nextId
        bots.nextId = id - 1
        bots.live[id] = { participantId = id, instanceId = instance.id }
        instance.actors[id] = true
    end
end

Deathmatch = {
    nowMs = function() return T end,
    playerId = function(v) local n = tonumber(v); return n and math.floor(n) or nil end,
    log = function() end,
    notice = function(id, kind, key, ...) fake.notices[#fake.notices + 1] = { id = id, key = key } end,
    playerName = function(id) return "acct" .. tostring(id) end,
    broadcastState = function() end,
    bounds = { hold = function() end },
    scoring = { rows = function(instance) return instance and instance.rows or {} end },
    loadout = { strip = function() return true end, bladeList = function() return {} end },
    setTeam = function(id, team, instance) fake.teams[id] = team; return true end,
    ranked = { recordRound = function(instance, opts) fake.ranked[#fake.ranked + 1] = instance; return true end },
    instances = {
        registry = {},
        of = function(id) return members[id] end,
        humans = function(instance)
            local out = {}
            for _, id in ipairs(instance.order) do if instance.members[id] and id > 0 then out[#out + 1] = id end end
            return out
        end,
        open = function(format, ruleset) return newInstance(format, ruleset) end,
        botCount = function(instance) local n = 0; for _ in pairs(instance.actors or {}) do n = n + 1 end; return n end,
    },
    round = {
        begin = function(instance, reason)
            fake.begins[#fake.begins + 1] = { instance = instance, reason = reason }
            instance.round = { number = (instance.round and instance.round.number or 0) + 1, state = "active", startedAtMs = T }
            for _, id in ipairs(DM.instances.humans(instance)) do
                DM.setTeam(id, 0, instance)
                DM.place(id, instance, "round_start", 1500)
            end
            return instance.round
        end,
        join = function(id, ruleset)
            local instance
            for _, i in pairs(DM.instances.registry) do
                if i.format == "ffa" and i.ruleset == ruleset and not i.closed then instance = i end
            end
            instance = instance or DM.instances.open("ffa", ruleset)
            attach(instance, id)
            DM.setTeam(id, 0, instance)
            if instance.round == nil then DM.round.begin(instance, "first_join")
            else DM.place(id, instance, "join", 5000) end
            return instance
        end,
        finish = function(instance, reason, winnerId)
            fake.finishes[#fake.finishes + 1] = { instance = instance, reason = reason }
            instance.round.state = "standings"
            instance.round.result = { winnerId = winnerId, reason = reason }
            -- The engine's ladder write, through the seam (round.lua -> DM.ranked.recordRound).
            DM.ranked.recordRound(instance, { reason = reason })
            return true
        end,
    },
    arena = {
        enqueue = function(id, format, wantsBots)
            fake.enqueues[#fake.enqueues + 1] = { id = id, format = format, bots = wantsBots }
            local position, current = queuePosition(id)
            if current == format then
                if wantsBots then queues[format][position].bots = true end
                DM.notice(id, "info", "queued", position)
                return position, format
            end
            local queue = queues[format]
            queue[#queue + 1] = { playerId = id, bots = wantsBots == true, atMs = T }
            DM.notice(id, "success", "queued", #queue)
            -- The engine's 1v1 with one consenting player: a match against a bot.
            if format == "1v1" and #queue == 1 and wantsBots then
                queues[format] = {}
                local instance = DM.instances.open("1v1")
                instance.match = { sides = { [id] = 1 }, state = "playing", wins = { 0, 0 }, botFill = "requested" }
                attach(instance, id)
                arrive(instance, 1)
                DM.place(id, instance, "arena_round", 5000)
            elseif format == "1v1" and #queue >= 2 then
                local a, b = queue[1].playerId, queue[2].playerId
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
        sideOf = function(id)
            local instance = members[tonumber(id)]
            return instance and instance.match and instance.match.sides[tonumber(id)] or nil
        end,
    },
    place = function(id, instance, reason) fake.places[#fake.places + 1] = { id = id, reason = reason }; return true end,
    sendToLobby = function() error("never the engine's lobby") end,
    leave = function(id, scope)
        fake.leaves[#fake.leaves + 1] = { id = id, scope = scope }
        if scope == "queue" then
            local _, format = queuePosition(id)
            if format == nil then return false end
            for index = #queues[format], 1, -1 do if queues[format][index].playerId == id then table.remove(queues[format], index) end end
            DM.notice(id, "info", "queueLeft")
            return true
        end
        if members[id] == nil then return false end
        detach(id)
        DM.setTeam(id, 0)
        DM.sendToLobby(id, "left_match")
        return true
    end,
}
DM = Deathmatch
local engineSetTeam, engineSideOf, engineRecord = DM.setTeam, DM.arena.sideOf, DM.ranked.recordRound

dofile("server/core.lua")
dofile("server/lightrp.lua")
loading = false
local H = ArenaHost

local function clean()
    for _, t in ipairs({ H.entered, H.returning, H.released, H.recent, H.throttle, H.checks, H.invites, H.evicting,
        H.lastQueued, H.squads, H.teamQueuedAt, H.teamUpgraded, members, DM.instances.registry, bots.live, fake.teams }) do
        for k in pairs(t) do t[k] = nil end
    end
    H.duelQueue = {}
    queues["1v1"], queues["2v2"], queues["3v3"] = {}, {}, {}
    bots.adds, bots.clears, bots.dropped, bots.park = {}, {}, {}, false
    fake.enqueues, fake.leaves, fake.begins, fake.finishes, fake.ranked, fake.notices = {}, {}, {}, {}, {}, {}
    env.events, env.client, env.calls = {}, {}, {}
    L.bots.teamWaitMs, L.bots.duelWaitMs, L.bots.blade, L.bots.ffa = 0, 0, true, true
    T = T + 10000
end
local function setMode(on) fire("op77_lightrp:activity:bots", on); assert(H.botMode == on) end
local function join(id, ruleset)
    T = T + 1000
    return DM.round.join(id, ruleset)
end
local function squad(id, leader, list) return { id = id, leader = leader, members = list } end

-- ── wiring: the seams are the adapter's, the event is host-wide ──
do
    assert(DM.setTeam ~= engineSetTeam and DM.arena.sideOf ~= engineSideOf and DM.ranked.recordRound ~= engineRecord)
    assert(DM.arena.planRoster == H.planRoster and DM.round.begin ~= H.engine.begin)
    assert(env.handlers["op77_lightrp:activity:bots"] and #env.handlers["op77_lightrp:activity:bots"] == 1)
    assert(env.net["op77_lightrp:activity:bots"] == nil, "never a net event")
    assert(env.commands["arena.pve"] and env.commands["arena.pve"].restricted == false)
    assert(H.botMode == false, "off at load")
    say("PASS wiring")
end

-- ── the switch: activityBots at every registration, then the event ──
do
    env.answers.activityBots = true
    fire("onResourceStart", "op77_arena")
    assert(H.botMode == true, "read after registering")
    local asked = 0
    for _, c in ipairs(env.calls) do if c.name == "activityBots" then asked = asked + 1 end end
    assert(asked == 1)
    fire("op77_lightrp:activity:bots", false)
    assert(H.botMode == false)
    fire("op77_lightrp:activity:bots", true)
    assert(H.botMode == true)
    fire("op77_lightrp:activity:bots", "yes")
    assert(H.botMode == false, "only a real true turns it on")
    -- Light RP restarted while the switch was on: ready -> register -> read again.
    env.answers.activityBots = true
    fire("op77_lightrp:activity:ready")
    assert(H.botMode == true)
    -- Light RP back without the export (older core): off.
    env.answers.activityBots = nil
    fire("op77_lightrp:activity:ready")
    assert(H.botMode == false)
    -- A registration that failed reads nothing.
    env.answers.activityRegister = false
    env.answers.activityBots = true
    fire("op77_lightrp:activity:ready")
    assert(H.botMode == false, "nothing registered, nothing read")
    env.answers.activityRegister = true
    env.answers.activityBots = false
    -- Statuses say practice while the switch is on.
    setMode(true)
    assert(H.statusOf("ffa").detail:find("bot practice", 1, true))
    assert(H.statusOf("teams").detail:find("bot practice", 1, true))
    assert(not H.statusOf("pve").detail:find("practice", 1, true), "PvE is not practice")
    setMode(false)
    assert(not H.statusOf("ffa").detail:find("practice", 1, true))
    say("PASS switch")
end

-- ── Combat Zone alone in bot mode: bots fill, nothing is recorded or rated ──
do
    clean()
    setMode(true)
    local instance = join(3, "standard")
    assert(instance and H.entered[3], "one player starts the Combat Zone")
    assert(#bots.adds == 1 and bots.adds[1].count == L.bots.fillTarget - 1, "filled to fillTarget bodies")
    assert(H.botCount(instance) == L.bots.fillTarget - 1)
    -- Asking again changes nothing (no double fill).
    assert(H.fillBots(instance) == 0)
    -- A second player: the round keeps its bots (one surplus) until it ends.
    join(4, "standard")
    assert(#bots.adds == 1 and H.botCount(instance) == L.bots.fillTarget - 1)
    -- The round ends: results are practice, the ladder write is refused.
    instance.rows = {
        { id = 3, rank = 1, score = 900, kills = 9, deaths = 1, assists = 0 },
        { id = -1, rank = 2, score = 300, kills = 3, deaths = 4, bot = true, active = true },
        { id = 4, rank = 3, score = 100, kills = 1, deaths = 5, assists = 0 },
    }
    T = T + 200000
    DM.round.finish(instance, "time_limit", 3)
    local r3, r4 = lastResult(3), lastResult(4)
    assert(r3 and r3.test == true and r3.reputation == 0, "practice: no reputation, test result")
    assert(r4 and r4.test == true and r4.reputation == 0)
    assert(#fake.ranked == 0, "no career / round / rating row with bots")
    assert(select(2, DM.ranked.recordRound(instance, {})) == "bots")
    -- Next round: one bot too many for two players -> removed before it starts, refilled after.
    bots.clears = {}
    DM.round.begin(instance, "rollover")
    assert(#bots.clears == 1 and bots.clears[1].reason == "round_reset")
    assert(H.botCount(instance) == L.bots.fillTarget - 2)
    say("PASS solo Combat Zone with bots")
end

-- ── paced spawns are counted while they arrive ──
do
    clean()
    setMode(true)
    bots.park = true
    local instance = join(3, "standard")
    assert(bots.adds[1].count == 5 and H.botCount(instance) == 0 and H.inFlight(instance) == 5)
    assert(H.fillBots(instance) == 0, "parked bots are not asked for twice")
    arrive(instance, 2)
    assert(H.inFlight(instance) == 3)
    T = T + L.bots.inFlightMs + 1
    assert(H.inFlight(instance) == 0, "a parked spawn that never came stops counting")
    say("PASS paced spawns")
end

-- ── Blade Night follows its own switch ──
do
    clean()
    setMode(true)
    L.bots.blade = false
    local instance = join(3, "blade")
    assert(instance and #bots.adds == 0, "blade fill off")
    L.bots.blade = true
    clean()
    setMode(true)
    instance = join(5, "blade")
    assert(#bots.adds == 1 and H.botCount(instance) == 5)
    say("PASS blade night")
end

-- ── bot mode off: nothing new is filled; a running round loses its bots at its end ──
do
    clean()
    setMode(true)
    local instance = join(3, "standard")
    assert(H.botCount(instance) == 5)
    setMode(false)
    assert(H.botCount(instance) == 5, "a running round keeps its bots")
    assert(bots.dropped[#bots.dropped] == instance.id, "parked spawns are dropped at once")
    instance.rows = { { id = 3, rank = 1, score = 100, kills = 1, deaths = 0 } }
    DM.round.finish(instance, "time_limit", 3)
    assert(H.botCount(instance) == 0 and bots.clears[#bots.clears].reason == "round_over")
    assert(lastResult(3).test == true, "the round had bots: still practice")
    -- The next round is a clean one: recorded, rated.
    DM.round.begin(instance, "rollover")
    assert(H.botCount(instance) == 0 and #bots.adds == 1)
    instance.rows = { { id = 3, rank = 1, score = 100, kills = 1, deaths = 0 } }
    fake.ranked = {}
    DM.round.finish(instance, "time_limit", 3)
    assert(lastResult(3).test == nil, "a clean round is recorded")
    assert(#fake.ranked == 1, "and reaches the ladder")
    -- A new Combat Zone with the switch off: no bot.
    clean()
    join(4, "standard")
    assert(#bots.adds == 0)
    say("PASS bot mode off")
end

-- ── cleanup: last player out, a disconnect, the resource stopping ──
do
    clean()
    setMode(true)
    local instance = join(3, "standard")
    join(4, "standard")
    DM.leave(3, "auto")
    assert(H.botCount(instance) > 0, "a player is still there")
    DM.leave(4, "auto")
    assert(H.botCount(instance) == 0 and bots.clears[#bots.clears].reason == "no_players", "bots go with the last player")
    -- A disconnect the engine handled on its own: the tick catches the empty instance.
    clean()
    setMode(true)
    instance = join(5, "standard")
    detach(5)
    H.tick(T)
    assert(H.botCount(instance) == 0)
    -- Stopping the resource: every parked spawn and every body.
    clean()
    setMode(true)
    instance = join(6, "standard")
    fire("onResourceStop", "op77_arena")
    assert(H.botCount(instance) == 0 and bots.dropped[#bots.dropped] == "all" and bots.clears[#bots.clears].reason == "resource_stop")
    H.stopped = false
    say("PASS cleanup")
end

-- ── team arenas: queue entries accept bots in bot mode, at once or after teamWaitMs ──
do
    clean()
    setMode(false)
    DM.arena.enqueue(5, "2v2", true)
    assert(fake.enqueues[#fake.enqueues].bots == false, "no bots without bot mode, whatever the caller says")
    assert(queuedNotices(5) == 1, "the player is told they are queued")
    setMode(true)
    local upgrade = fake.enqueues[#fake.enqueues]
    assert(upgrade.id == 5 and upgrade.bots == true, "switching on upgrades who is waiting")
    assert(queuedNotices(5) == 1, "quietly")
    assert(queues["2v2"][1].bots == true)
    T = T + 1000
    DM.arena.enqueue(6, "3v3", false)
    assert(fake.enqueues[#fake.enqueues].bots == true, "a new team queue entry accepts bots at once")
    -- With a wait: people first, bots after teamWaitMs.
    clean()
    setMode(false)
    setMode(true)
    L.bots.teamWaitMs = 30000
    DM.arena.enqueue(7, "2v2", false)
    assert(fake.enqueues[#fake.enqueues].bots == false)
    local before = #fake.enqueues
    T = T + 10000
    H.tick(T)
    assert(#fake.enqueues == before, "still waiting for people")
    T = T + 25000
    H.tick(T)
    assert(fake.enqueues[#fake.enqueues].id == 7 and fake.enqueues[#fake.enqueues].bots == true, "then bots complete it")
    -- A team match formed with bots is practice.
    clean()
    setMode(true)
    local instance = DM.instances.open("2v2")
    instance.match = { sides = { [3] = 1 }, state = "resolved", wins = { 2, 0 }, botFill = "requested",
        result = { reason = "best_of", winnerSide = 1, wins = { 2, 0 } } }
    attach(instance, 3)
    H.entered[3] = { activity = L.activities.teams.id, atMs = T, instanceId = instance.id, totals = { kills = 0, deaths = 0 } }
    setMode(false)
    assert(H.reportMatch(instance) == 1)
    assert(lastResult(3).test == true and lastResult(3).reputation == 0, "a match with bots: practice even after the switch")
    say("PASS team fill")
end

-- ── duels against a bot ──
do
    clean()
    setMode(false)
    local ok, text = H.duelBot(3)
    assert(not ok and text:find("bot mode"), "off: refused")
    setMode(true)
    T = T + 1000
    ok, text = H.duelBot(3)
    assert(ok and text:find("Best of three"))
    local instance = DM.instances.of(3)
    assert(instance and instance.format == "1v1" and H.entered[3] and H.entered[3].activity == L.activities.duel.id)
    assert(fake.enqueues[#fake.enqueues].bots == true and fake.enqueues[#fake.enqueues].format == "1v1")
    assert(queuedNotices(3) == 0, "the engine queue is the adapter's business")
    -- Busy: refused.
    T = T + 1000
    ok = H.duelBot(3)
    assert(not ok)
    -- The match result is practice.
    instance.match.state = "resolved"
    instance.match.result = { reason = "best_of", winnerSide = 1, wins = { 2, 1 } }
    H.reportMatch(instance)
    assert(lastResult(3).test == true and lastResult(3).reputation == 0)
    -- /duel bot as a command.
    clean()
    setMode(true)
    local replies = {}
    env.client = {}
    env.commands["duel"].fn(4, { "bot" }, "/duel bot")
    for _, e in ipairs(env.client) do if e.name == "open77:command:result" then replies[#replies + 1] = e.args[2] end end
    assert(replies[1] == true and DM.instances.of(4) ~= nil)
    -- The random queue: nobody waiting, a bot takes the duel.
    clean()
    setMode(true)
    assert(H.queueDuel(5) == true and DM.instances.of(5) ~= nil and #H.duelQueue == 0)
    -- With a wait: queued first, the bot after duelWaitMs.
    clean()
    setMode(true)
    L.bots.duelWaitMs = 20000
    assert(H.queueDuel(6) == true and DM.instances.of(6) == nil and #H.duelQueue == 1)
    T = T + 21000
    H.tick(T)
    assert(DM.instances.of(6) ~= nil and #H.duelQueue == 0)
    say("PASS duel vs bot")
end

-- ── no own record with bots: the rating seam ──
do
    clean()
    setMode(false)
    local clean_ = DM.instances.open("ffa", "standard")
    clean_.round = { number = 1, state = "active", startedAtMs = T }
    fake.ranked = {}
    assert(DM.ranked.recordRound(clean_, {}) == true and #fake.ranked == 1, "a human round reaches the ladder")
    setMode(true)
    local written, why = DM.ranked.recordRound(clean_, {})
    assert(written == false and why == "bot_mode" and #fake.ranked == 1)
    setMode(false)
    -- A removed bot's row from this round still counts; one from a past round does not.
    clean_.rows = { { id = -9, bot = true, active = false, kills = 2, deaths = 0 } }
    assert(H.hadBots(clean_) == true)
    clean_.rows = { { id = -9, bot = true, active = false, kills = 0, deaths = 0 } }
    assert(H.hadBots(clean_) == false, "an old bot row does not taint the next round")
    local pve = DM.instances.open("ffa", "pve")
    written, why = DM.ranked.recordRound(pve, {})
    assert(written == false and why == "unranked_ruleset" and #fake.ranked == 1, "PvE never rated")
    say("PASS no record with bots")
end

-- ── PvE: open without the switch, one side, bots scale with the players ──
do
    clean()
    setMode(false)
    local instance = join(3, "pve")
    assert(instance and instance.ruleset == "pve" and H.entered[3].activity == L.activities.pve.id)
    assert(#bots.adds == 1 and bots.adds[1].count == L.pve.botsFirst, "bots without the staff switch")
    -- Sides: players on one nonzero team (Open77.combat.setTeam: no friendly fire), bots the other.
    assert(fake.teams[3] == 1, "player team 1")
    local botId = next(instance.actors)
    assert(DM.arena.sideOf(3) == 1 and DM.arena.sideOf(botId) == 2)
    join(4, "pve")
    assert(fake.teams[4] == 1 and H.botCount(instance) == L.pve.botsFirst + L.pve.botsPerPlayer, "more players, more bots")
    -- Outside PvE nothing changes.
    local cz = join(5, "standard")
    assert(fake.teams[5] == 0 and DM.arena.sideOf(5) == nil and #bots.adds == 2, "Combat Zone untouched")
    DM.leave(5, "auto")
    -- Full at maxPlayers.
    for id = 6, 9 do join(id, "pve") end
    assert(#DM.instances.humans(instance) == L.pve.maxPlayers)
    assert(H.botCount(instance) == L.pve.botsMax, "capped at botsMax")
    assert(join(10, "pve") == nil, "PvE full")
    assert(noticesTo(10)[1].body:find("full"))
    assert(H.statusOf("pve").joinable == false)
    for id = 6, 9 do DM.leave(id, "auto") end
    -- Results: recorded (no test flag), reputation from config, only after minRoundMs.
    env.events = {}
    T = instance.round.startedAtMs + L.reputation.pve.minRoundMs + 1000
    H.entered[4].atMs = T - 5000 -- 4 came late
    instance.rows = {
        { id = 3, score = 500, kills = 5, deaths = 1 }, { id = 4, score = 200, kills = 2, deaths = 0 },
        { id = botId, score = 100, kills = 1, deaths = 7, bot = true, active = true },
    }
    DM.round.finish(instance, "time_limit", 3)
    local r3, r4 = lastResult(3), lastResult(4)
    assert(r3.test == nil and r3.won == true and r3.placement == 1 and r3.reputation == L.reputation.pve.win)
    assert(r3.stats.teamKills == 7 and r3.stats.botKills == 1)
    assert(r4.won == true and r4.reputation == 0, "too short in the round to earn")
    assert(L.reputation.pve.win < L.reputation.ffa.first, "PvE pays less than PvP")
    assert(#fake.ranked == 0, "no rating write")
    assert(H.botCount(instance) > 0, "PvE keeps its bots between rounds")
    -- The bots won this one.
    env.events = {}
    DM.round.begin(instance, "rollover")
    T = T + L.reputation.pve.minRoundMs + 1000
    instance.rows = { { id = 3, score = 0, kills = 0, deaths = 4 }, { id = botId, score = 400, kills = 4, deaths = 0, bot = true } }
    DM.round.finish(instance, "time_limit", botId)
    assert(lastResult(3).won == false and lastResult(3).placement == 2 and lastResult(3).reputation == L.reputation.pve.loss)
    -- Staff bot mode does not change PvE (Light RP itself skips results while it is on).
    setMode(true)
    DM.round.begin(instance, "rollover")
    T = T + L.reputation.pve.minRoundMs + 1000
    DM.round.finish(instance, "time_limit", 3)
    assert(lastResult(3).test == nil)
    setMode(false)
    -- A quit mid-round: a loss, nothing earned, recorded.
    DM.round.begin(instance, "rollover")
    instance.rows = { { id = 3, score = 0, kills = 0, deaths = 0 }, { id = 4, score = 0, kills = 0, deaths = 0 } }
    env.events = {}
    DM.leave(4, "auto")
    assert(lastResult(4).placement == 2 and lastResult(4).reputation == 0 and lastResult(4).test == nil and lastResult(4).stats.quit)
    -- One player fewer: the next round drops the surplus and refills.
    DM.round.finish(instance, "time_limit")
    DM.round.begin(instance, "rollover")
    assert(H.botCount(instance) == L.pve.botsFirst)
    -- The last player leaves: the bots go.
    DM.leave(3, "auto")
    assert(H.botCount(instance) == 0)
    say("PASS PvE")
end

-- ── crews ──
do
    clean()
    setMode(false)
    -- options.squad validation.
    assert(H.noteSquad(3, squad("c1", 3, { 3, 4 })) ~= nil)
    assert(H.noteSquad(5, squad("c1", 3, { 3, 4 })) == nil, "a squad without the player is ignored")
    assert(H.noteSquad(6, squad("c2", 6, { 6 })) == nil, "a crew of one is no crew")
    assert(H.noteSquad(7, "nope") == nil and H.squads[7] == nil)

    -- The panel join carries the crew; a command does not.
    clean()
    fire("op77_lightrp:activity:join", 3, L.activities.pve.id, { squad = squad("c1", 3, { 3, 4 }) })
    assert(H.squads[3] and H.squads[3].id == "c1" and DM.instances.of(3) ~= nil)
    T = T + 1000
    env.commands["arena.ffa"].fn(8, {}, "/arena.ffa")
    assert(H.squads[8] == nil)

    -- PvE / Combat Zone: room for the whole crew or nobody.
    clean()
    local pve
    for id = 3, 6 do pve = join(id, "pve") end
    H.noteSquad(7, squad("c3", 7, { 7, 8, 9 }))
    assert(join(7, "pve") == nil, "2 places for a crew of 3")
    assert(noticesTo(7)[1].body:find("whole crew"))
    H.noteSquad(7, squad("c4", 7, { 7, 8 }))
    assert(join(7, "pve") ~= nil)
    H.noteSquad(8, squad("c4", 7, { 7, 8 }))
    assert(join(8, "pve") == pve, "the second member follows into the same instance")

    -- Team Arena: a crew must fit on one side.
    clean()
    H.noteSquad(3, squad("c5", 3, { 3, 4, 5 }))
    assert(DM.arena.enqueue(3, "2v2") == nil and noticesTo(3)[1].body:find("3v3"))
    T = T + 1000
    assert(DM.arena.enqueue(3, "3v3") ~= nil, "a crew of three fits 3v3")
    H.noteSquad(6, squad("c6", 6, { 6, 7, 8, 9 }))
    assert(DM.arena.enqueue(6, "3v3") == nil, "a crew of four fits no team format")

    -- Duels: the random queue never sets two crewmates against each other.
    clean()
    H.noteSquad(3, squad("c7", 3, { 3, 4 }))
    H.noteSquad(4, squad("c7", 3, { 3, 4 }))
    assert(H.queueDuel(3) and H.queueDuel(4))
    assert(DM.instances.of(3) == nil and DM.instances.of(4) == nil and #H.duelQueue == 2, "crewmates not paired")
    assert(H.queueDuel(5) and DM.instances.of(5) ~= nil and DM.instances.of(5) == DM.instances.of(3), "a stranger takes one of them")
    say("PASS crews")
end

-- ── the roster plan (Arena.planRoster): crews on one side, bots complete it in bot mode ──
do
    clean()
    setMode(false)
    local function q(...) local out = {} for _, id in ipairs({ ... }) do out[#out + 1] = { playerId = id, bots = false } end return out end
    assert(H.planRoster("1v1", q(3), 2) == nil, "duels keep the engine's rule")
    -- Outside bot mode: a full roster or nothing.
    local plan = H.planRoster("2v2", q(5, 3), 4)
    assert(plan and #plan.roster == 0, "a short queue does not form without bot mode")
    H.noteSquad(3, squad("c8", 3, { 3, 4 }))
    H.noteSquad(4, squad("c8", 3, { 3, 4 }))
    plan = H.planRoster("2v2", q(5, 3, 4, 6), 4)
    assert(#plan.roster == 4 and plan.sides[3] == plan.sides[4] and plan.sides[5] == plan.sides[6] and plan.sides[3] ~= plan.sides[5],
        "the crew shares a side (the arrival-order rule would have split it)")
    -- A crew still arriving is held; the rest are not.
    plan = H.planRoster("2v2", q(5, 3, 6, 7), 4)
    assert(#plan.roster == 0, "member 4 is still on the way and three others cannot form alone")
    setMode(true)
    plan = H.planRoster("2v2", q(5, 3), 4)
    assert(#plan.roster == 1 and plan.roster[1] == 5, "bot mode: the solo player goes, the crew waits for its member")
    T = T + L.crews.gatherMs + 1
    plan = H.planRoster("2v2", q(3), 4)
    assert(#plan.roster == 1 and plan.roster[1] == 3, "after gatherMs the crew goes with whoever came")
    -- Bot mode: a crew of two alone forms on one side; the engine fills the rest.
    H.noteSquad(3, squad("c9", 3, { 3, 4 }))
    H.noteSquad(4, squad("c9", 3, { 3, 4 }))
    plan = H.planRoster("2v2", q(3, 4), 4)
    assert(#plan.roster == 2 and plan.sides[3] == 1 and plan.sides[4] == 1)
    -- Two crews of two in a 2v2: one each side.
    H.noteSquad(5, squad("c10", 5, { 5, 6 }))
    H.noteSquad(6, squad("c10", 5, { 5, 6 }))
    plan = H.planRoster("2v2", q(3, 5, 4, 6), 4)
    assert(#plan.roster == 4 and plan.sides[3] == plan.sides[4] and plan.sides[5] == plan.sides[6] and plan.sides[3] ~= plan.sides[5])
    -- A crew that cannot fit this match waits for the next one.
    H.noteSquad(7, squad("c11", 7, { 7, 8, 9 }))
    H.noteSquad(8, squad("c11", 7, { 7, 8, 9 }))
    H.noteSquad(9, squad("c11", 7, { 7, 8, 9 }))
    plan = H.planRoster("3v3", q(3, 4, 10, 7, 8, 9, 5), 6)
    local side7 = plan.sides[7]
    assert(side7 and plan.sides[8] == side7 and plan.sides[9] == side7, "a crew of three takes one side whole")
    assert(plan.sides[3] == plan.sides[4] and plan.sides[3] ~= side7)
    say("PASS roster plan")
end

say("PASS: op77_arena bots (switch, solo fill, paced spawns, blade, off, cleanup, teams, duel vs bot, no record, PvE, crews, roster plan)")
