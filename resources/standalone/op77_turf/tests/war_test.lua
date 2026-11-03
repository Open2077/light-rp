-- op77_turf flows end to end, against a fake Light RP (the activity exports and events)
-- and a fake world (TurfWorld replaced), through the real wiring (server/main.lua):
--   registration; leaveRequest while queued; join -> enter -> place -> countdown ->
--   capture / contest / kills / respawn timing / protection / kits / bounds / late
--   joiner -> target -> results + influence -> release -> leave; forfeit + dropped;
--   Light RP restart; staff-scheduled war + stop; provider restart.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test war_test.lua
local realPrint = print
local logs = {}
print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    logs[#logs + 1] = table.concat(parts, " ")
end

-- ---------------------------------------------------------------- host
local host = { handlers = {}, net = {}, commands = {}, exports = {}, threads = {}, damage = nil, offDamage = {} }
local core = { registered = {}, registerCount = 0, owned = {}, busy = {}, players = {}, enters = {}, leaves = {},
    results = {}, statuses = {}, announces = {} }

_G.Open77 = {
    exports = {
        callSync = function(resource, name, ...)
            assert(resource == "op77_lightrp")
            local a = { ... }
            if name == "activityRegister" then
                core.registered[a[1].id] = a[1]; core.registerCount = core.registerCount + 1
                return true
            elseif name == "activityCheck" then
                local id = a[1]
                if core.busy[id] then return false, core.busy[id] end
                if core.owned[id] and core.owned[id] ~= a[2] then return false, "You are busy elsewhere." end
                return true
            elseif name == "activityEnter" then
                local id = a[1]
                if core.owned[id] then return false, "Already in an activity." end
                core.owned[id] = a[2]; core.enters[#core.enters + 1] = id
                return true
            elseif name == "activityLeave" then
                local id = a[1]
                if core.owned[id] ~= a[2] then return false, "That player is not in this activity." end
                core.owned[id] = nil; core.leaves[#core.leaves + 1] = { id = id, opts = a[3] }
                return true
            elseif name == "activityOwner" then return core.owned[a[1]]
            elseif name == "activityPlayer" then return core.players[a[1]] end
            error("unknown export " .. tostring(name))
        end,
    },
    time = { monotonic = function() return 0 end },
    combat = {
        onDamage = function(fn) host.damage = fn; return fn end,
        offDamage = function(fn) host.offDamage[#host.offDamage + 1] = fn; return true end,
    },
    players = {},
}
_G.TriggerEvent = function(name, ...)
    local a = table.pack(...)
    if name == "op77_lightrp:activity:result" then core.results[#core.results + 1] = { id = a[1], activity = a[2], result = a[3] }
    elseif name == "op77_lightrp:activity:status" then core.statuses[#core.statuses + 1] = a[2]
    elseif name == "op77_lightrp:announce" then core.announces[#core.announces + 1] = a[1] end
end
_G.TriggerClientEvent = function() end
_G.AddEventHandler = function(name, fn) host.handlers[name] = host.handlers[name] or {}; table.insert(host.handlers[name], fn) end
_G.RegisterNetEvent = function(name, fn) host.net[name] = fn end
_G.RegisterCommand = function(name, fn, restricted) host.commands[name] = { fn = fn, restricted = restricted } end
_G.exports = function(name, fn) host.exports[name] = fn end
_G.CreateThread = function(fn) host.threads[#host.threads + 1] = fn end
_G.Wait = function() end
_G.GetCurrentResourceName = function() return "op77_turf" end
_G.GetPlayers = function() return {} end

dofile("shared/config.lua")
dofile("server/rules.lua")
dofile("server/core.lua")
dofile("server/world.lua")
dofile("server/bots.lua")
dofile("server/influence.lua")
dofile("server/war.lua")

-- ---------------------------------------------------------------- fake world
local clock = 1000000
local pl, teams, frozen, equips, respawns, teleports, scopes, removed, cleared, clearedKits = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
local pushes, notes, pending, refuseRespawn, sites = {}, {}, {}, {}, {}
local lastReply

local W = TurfWorld
W.now = function() return clock end
W.unix = function() return 1793577600 + clock // 1000 end
W.position = function(id)
    local p = pl[id]
    if not p or not p.connected or not p.pos then return nil end
    return { x = p.pos.x, y = p.pos.y, z = p.pos.z, bucket = p.pos.bucket }
end
W.phase = function(id) return pl[id] and pl[id].phase or nil end
W.name = function(id) return "P" .. id end
W.connected = function(id) return pl[id] ~= nil and pl[id].connected == true end
W.setupBucket = function() end
W.place = function(id, point, bucket, done) pending[#pending + 1] = { id = id, point = point, bucket = bucket, done = done } end
W.teleport = function(id, point, bucket)
    teleports[#teleports + 1] = { id = id, point = point }
    pl[id].pos = { x = point.x, y = point.y, z = point.z, bucket = bucket }
end
W.respawn = function(id, point, bucket)
    if refuseRespawn[id] and refuseRespawn[id] > 0 then refuseRespawn[id] = refuseRespawn[id] - 1; return false, "life_busy" end
    if not W.isDown(pl[id].phase) then return false, "not_dead" end
    respawns[#respawns + 1] = { id = id, point = point, at = clock }
    pl[id].phase = "alive"
    pl[id].pos = { x = point.x, y = point.y, z = point.z, bucket = bucket }
    return true
end
W.respawnInPlace = function(id, bucket) return W.respawn(id, pl[id].pos, bucket) end
W.freeze = function(id, v) frozen[id] = v; return true end
W.setTeam = function(id, team) teams[id] = team; return true end
W.createScope = function(bucket, ids)
    scopes[#scopes + 1] = { bucket = bucket, ids = table.concat(ids, ",") }
    return "scope" .. #scopes
end
W.removeScope = function(scope) removed[scope] = true; return true end
W.equip = function(id, kit, current) equips[#equips + 1] = { id = id, kit = kit.id, current = current, at = clock } end
W.clearKit = function(id) clearedKits[id] = (clearedKits[id] or 0) + 1; return true end
W.state = function() end
W.board = function() end
W.site = function(id, payload) sites[id] = payload end
W.push = function(id, kind, payload) pushes[#pushes + 1] = { id = id, kind = kind, payload = payload } end
W.clear = function(id) cleared[id] = (cleared[id] or 0) + 1 end
W.notify = function(id, kind, message) notes[#notes + 1] = { id = id, kind = kind, message = message } end
W.reply = function(source, raw, ok, text) lastReply = { ok = ok, text = text } end
W.pose = function(id) return W.position(id), 90 end

dofile("server/main.lua")

-- ---------------------------------------------------------------- helpers
local CFG = TurfConfig
local R = TurfRules

local function fire(name, src, ...)
    _G.source = src
    for _, h in ipairs(host.handlers[name] or {}) do h(...) end
    _G.source = nil
end
local function net(name, src, ...) _G.source = src; host.net[name](...); _G.source = nil end
local function command(name, src, args) _G.source = src; host.commands[name].fn(src, args or {}, name); _G.source = nil end
local lastStatusAt = clock
local function advance(ms)
    local target = clock + ms
    while clock < target do
        clock = math.min(target, clock + 250)
        Turf.tick(clock)
        if clock - lastStatusAt >= 1000 then lastStatusAt = clock; TurfCore.status(Turf.status(clock), false, nil, clock) end
    end
end
local function flush(fail)
    local list = pending
    pending = {}
    for _, p in ipairs(list) do
        if fail and fail[p.id] then p.done(false, "teleport_failed")
        else
            pl[p.id].pos = { x = p.point.x, y = p.point.y, z = p.point.z, bucket = p.bucket }
            if W.isDown(pl[p.id].phase) then pl[p.id].phase = "alive" end
            p.done(true)
        end
    end
end
local GANGS = { valentinos = "Valentinos", maelstrom = "Maelstrom", tyger_claws = "Tyger Claws", animals = "Animals",
    voodoo_boys = "Voodoo Boys" }
local function addPlayer(id, gang)
    pl[id] = { pos = { x = -756.6, y = 777.3, z = 22.5, bucket = 0 }, phase = "alive", connected = true }
    core.players[id] = { name = "P" .. id, identifier = "license:" .. id, characterKey = "c" .. id,
        gang = gang and { id = gang, label = GANGS[gang], grade = 1 } or nil }
end
local function at(id, x, y, z) pl[id].pos = { x = x, y = y, z = z, bucket = Turf.war.bucket } end
local function lastStatus() return core.statuses[#core.statuses] end
local function resultOf(id, from)
    for i = #core.results, from or 1, -1 do if core.results[i].id == id then return core.results[i].result end end
end
local function leftIds(from)
    local out = {}
    for i = from or 1, #core.leaves do out[core.leaves[i].id] = core.leaves[i] end
    return out
end
local function pushed(id, kind, pattern, from)
    for i = from or 1, #pushes do
        local p = pushes[i]
        if p.id == id and p.kind == kind and (pattern == nil or tostring(p.payload.title or p.payload.text):find(pattern)) then return p end
    end
end
local function noted(id, pattern, from)
    for i = from or 1, #notes do if notes[i].id == id and notes[i].message:find(pattern) then return notes[i] end end
end
local function dist(a, b) local dx, dy = a.x - b.x, a.y - b.y; return math.sqrt(dx * dx + dy * dy) end

local function main()
    -- ============================================================ registration
    assert(host.damage, "the damage arbiter is installed at load")
    host.threads[1]() -- the registration thread
    local def = core.registered["turf.war"]
    assert(def and def.kind == "pvp" and def.modeKey == "site" and #def.modes == 2 and core.registerCount == 1)
    assert(lastStatus().phase == "idle" and lastStatus().joinable == true)
    for _, name in ipairs({ "turf.schedule", "turf.start", "turf.stop", "turf.testing", "turf.survey", "turf.status", "turf.zone" }) do
        assert(host.commands[name] and host.commands[name].restricted == true, name .. " is staff (ACL command." .. name .. ")")
    end
    assert(host.commands.turf.restricted == false)

    -- ============================================================ leaveRequest while queued
    addPlayer(9, nil)
    fire("op77_lightrp:activity:join", nil, 9, "race.grid", {})
    assert(#Turf.queue == 0, "another activity's join is not ours")
    fire("op77_lightrp:activity:join", nil, 9, "turf.war", { site = "badlands" })
    assert(#Turf.queue == 1 and Turf.queue[1].site == "badlands" and Turf.queue[1].gang == nil)
    assert(lastStatus().phase == "lobby" and lastStatus().queued == 1)
    local wq = lastStatus().queue
    assert(wq and wq.v == 1 and #wq.lobbies == 1 and wq.lobbies[1].players[1] == 9 and wq.lobbies[1].need == Turf.minPlayers()
        and wq.lobbies[1].max == CFG.activity.maxPlayers and wq.lobbies[1].startsInMs == nil, "the queue panel: 1 / 6, no countdown yet")
    assert(not noted(9, "."), "no queued notice: Light RP answered the join, its queue panel shows the line")
    local leavesBefore = #core.leaves
    fire("op77_lightrp:activity:leaveRequest", nil, 9, "turf.war")
    assert(#Turf.queue == 0 and #core.leaves == leavesBefore, "a queued player is dropped, never activityLeave'd")
    assert(not noted(9, ".") and (cleared[9] or 0) >= 1, "Light RP's answer to the leave says it: no second notice")
    assert(lastStatus().phase == "idle")

    -- ============================================================ the full war
    -- 3 Valentinos, 3 Maelstrom, one unaffiliated, one Tyger Claw: 4 v 4.
    local roster = { { 1, "valentinos" }, { 2, "valentinos" }, { 3, "valentinos" }, { 4, "maelstrom" }, { 5, "maelstrom" },
        { 6, "maelstrom" }, { 7, nil }, { 8, "tyger_claws" } }
    for i, r in ipairs(roster) do
        addPlayer(r[1], r[2])
        clock = clock + 10
        fire("op77_lightrp:activity:join", nil, r[1], "turf.war", i <= 5 and { site = "kabuki" } or {})
    end
    assert(#Turf.queue == 8)
    advance(250)
    assert(Turf.lobby ~= nil, "6 queued: the lobby counts down")
    advance(1000)
    assert(lastStatus().phase == "lobby")
    local lq = lastStatus().queue.lobbies[1]
    assert(#lq.players == 8 and lq.startsInMs and lq.startsInMs > 0, "the lobby's countdown is the panel's")
    local sent = #core.statuses
    advance(3000)
    assert(#core.statuses == sent, "the countdown running down sends nothing")
    advance(41000)
    local war = Turf.war
    assert(war and war.state == "placing", "the lobby closed: the war is placing")
    assert(war.site.id == "kabuki", "the voted site")
    assert(war.bucket == CFG.buckets.from)
    assert(#core.enters == 8 and #Turf.queue == 0)
    assert(war.sides[1].gang == "valentinos" and war.sides[2].gang == "maelstrom")
    assert(war.members[1].side == 1 and war.members[7].side == 1 and war.members[7].merc == true)
    assert(war.members[4].side == 2 and war.members[8].side == 2 and war.members[8].merc == true and war.members[4].merc == false)
    assert(teams[1] == 4401 and teams[4] == 4402 and teams[7] == 4401 and teams[8] == 4402, "combat teams per side")
    assert(sites[1] and #sites[1].zones == 3 and sites[1].side == 1)
    assert(lastStatus().phase == "running" or true)
    advance(1000)
    assert(lastStatus().phase == "running" and lastStatus().players == 8)

    -- placed -> countdown: held, armed
    flush()
    advance(250)
    assert(war.state == "countdown")
    assert(frozen[1] == true and frozen[8] == true)
    local armed = {}
    for _, e in ipairs(equips) do armed[e.id] = e.kit end
    for id = 1, 8 do assert(armed[id] == "assault", "kit for " .. id) end
    assert(host.damage({ victim = 4, attacker = 1, amount = 10 }) == false, "no damage before FIGHT")
    advance(10000)
    assert(war.state == "running")
    assert(frozen[1] == false and frozen[5] == false)
    assert(#scopes >= 1 and scopes[#scopes].bucket == war.bucket and scopes[#scopes].ids == "1,2,3,4,5,6,7,8", "the PvP scope")
    assert(pushed(1, "banner", "FIGHT"))

    -- damage verdicts (through the installed arbiter)
    assert(host.damage({ victim = 4, attacker = 1, amount = 10 }) == true, "across sides")
    assert(host.damage({ victim = 2, attacker = 1, amount = 10 }) == false, "same side")
    assert(host.damage({ victim = 4, attacker = 99, amount = 10 }) == false, "an outsider cannot hurt a fighter")
    assert(host.damage({ victim = 99, attacker = 4, amount = 10 }) == false, "a fighter cannot hurt an outsider")
    assert(host.damage({ victim = 50, attacker = 51, amount = 10 }) == nil, "not our business")
    assert(host.damage({ victim = 4, attacker = 4, amount = 10, source = "vehicle" }) == true, "self / environment")

    -- capture: two attackers take zone A in 10 s
    local A, C3 = CFG.sites[1].zones[1], CFG.sites[1].zones[3]
    at(1, A.x + 1, A.y, A.z + 0.2); at(2, A.x - 1, A.y + 1, A.z + 0.2)
    local mark = #pushes
    local score0 = war.sides[1].score
    advance(9000)
    assert(war.zones[1].owner == nil and war.zones[1].capturing == 1)
    advance(1000)
    assert(war.zones[1].owner == 1, "captured in 10 s with two attackers")
    assert(war.members[1].captures == 1 and war.members[2].captures == 1 and war.members[3].captures == 0)
    assert(war.sides[1].score >= score0 + CFG.scoring.captureBonus)
    assert(pushed(1, "banner", "ZONE A CAPTURED", mark) and pushed(4, "banner", "ZONE A LOST", mark))
    assert(pushed(5, "feed", "captured", mark))
    assert(war.members[1].holdSeconds >= 9)

    -- contest: frozen while both sides stand in it
    at(4, A.x, A.y - 1, A.z)
    advance(3000)
    assert(war.zones[1].contested and war.zones[1].progress == 0 and war.zones[1].owner == 1)
    local spawn1 = R.sideSpawn(war.site, 1, 1)
    at(1, spawn1.x, spawn1.y, spawn1.z); at(2, spawn1.x + 1, spawn1.y, spawn1.z)
    advance(5000)
    assert(war.zones[1].capturing == 2 and war.zones[1].progress > 0.3 and war.zones[1].progress < 0.4, "4 alone: taking it")
    local spawn2 = R.sideSpawn(war.site, 2, war.members[4].slot)
    at(4, spawn2.x, spawn2.y, spawn2.z)

    -- a kill: credit, score, respawn after exactly 6 s at the side spawn, then protection
    local s1 = war.sides[1].score
    advance(250)
    pl[4].phase = "dead"
    fire("open77:playerKilled", nil, 4, 1, "{}")
    assert(war.members[4].down and war.members[4].deaths == 1 and war.members[1].kills == 1)
    assert(war.sides[1].score == s1 + CFG.scoring.killPoints)
    fire("open77:playerDied", nil, 4, '{"killer":1}')
    assert(war.members[4].deaths == 1 and war.members[1].kills == 1, "one death, however many events")
    assert(pushed(6, "feed", "eliminated"))
    advance(1000)
    assert(not scopes[#scopes].ids:find("4"), "the scope follows the living: " .. scopes[#scopes].ids)
    advance(4750)
    for _, r in ipairs(respawns) do assert(r.id ~= 4, "not before 6 s") end
    advance(250)
    local rs = respawns[#respawns]
    assert(rs and rs.id == 4, "respawned at 6 s")
    local expect = R.sideSpawn(war.site, 2, war.members[4].slot)
    assert(dist(rs.point, expect) < 0.01 and math.abs(rs.point.z - (expect.z + CFG.match.spawnLiftMetres)) < 0.01,
        "side 2 holds nothing: its spawn")
    advance(250)
    assert(war.members[4].down == false and (war.members[4].protectedUntil or 0) > clock, "protected")
    assert(equips[#equips].id == 4, "re-armed")
    assert(host.damage({ victim = 4, attacker = 1, amount = 10 }) == false, "spawn protection")
    assert(host.damage({ victim = 1, attacker = 4, amount = 10 }) == true, "shooting breaks it")
    assert(host.damage({ victim = 4, attacker = 1, amount = 10 }) == true)
    advance(1500)
    assert(scopes[#scopes].ids == "1,2,3,4,5,6,7,8", "back in the scope")

    -- a kit chosen right after a spawn swaps at once; later, from the next life
    local nEquips = #equips
    net("op77_turf:kit", 4, "next")
    assert(war.members[4].kit == "breacher" and #equips == nEquips + 1 and equips[#equips].kit == "breacher",
        "within the swap window after a spawn: at once")
    nEquips = #equips
    net("op77_turf:kit", 3, "tech")
    assert(war.members[3].kit == "tech" and #equips == nEquips, "long after the spawn: from the next life")
    net("op77_turf:kit", 3, "nope")
    assert(war.members[3].kit == "tech", "an unknown kit changes nothing")
    -- respawn at a held zone: side 1 falls near C, comes back at A (the zone it holds)
    at(2, C3.x, C3.y - 3, C3.z)
    advance(1000)
    pl[2].phase = "dead"
    refuseRespawn[2] = 1
    fire("open77:playerKilled", nil, 2, 5, "{}")
    advance(6000)
    for _, r in ipairs(respawns) do assert(r.id ~= 2, "the first respawn was refused") end
    advance(2000)
    rs = respawns[#respawns]
    assert(rs.id == 2, "retried 2 s later")
    assert(math.abs(dist(rs.point, A) - CFG.life.zoneSpawnOffset) < 0.01, "on the ring of the held zone A")
    advance(250)
    nEquips = #equips
    net("op77_turf:kit", 2, "marksman")
    assert(war.members[2].kit == "marksman" and #equips == nEquips + 1 and equips[#equips].kit == "marksman", "swapped at once")

    -- a stale "alive" read right after the death event is not a new life
    pl[5].phase = "alive"
    fire("open77:playerKilled", nil, 5, 3, "{}")
    advance(2000)
    assert(war.members[5].down == true, "still down 2 s later")
    advance(1250)
    assert(war.members[5].down == false and war.members[5].deaths == 1, "revived elsewhere: counted once")

    -- out of bounds for 8 s: back to the spawn
    at(6, war.site.bounds.center.x + war.site.bounds.radius + 20, war.site.bounds.center.y, 8)
    local nTp = #teleports
    advance(7000)
    assert(#teleports == nTp)
    advance(1500)
    assert(#teleports == nTp + 1 and teleports[#teleports].id == 6 and noted(6, "left the war zone"))

    -- a late joiner (Maelstrom) goes in on his own side while the balance allows
    addPlayer(10, "maelstrom")
    fire("op77_lightrp:activity:join", nil, 10, "turf.war", {})
    advance(1000)
    assert(war.members[10] and war.members[10].side == 2 and war.members[10].merc == false and teams[10] == 4402)
    assert(core.owned[10] == "turf.war" and #Turf.queue == 0)
    flush()
    advance(250)
    assert(war.members[10].placed and (war.members[10].protectedUntil or 0) > clock and equips[#equips].id == 10)
    -- someone waiting while the war is on waits for an opening on a side (no count to reach)
    Turf.queue[1] = { id = 77 }
    local dq = Turf.warQueue(clock).lobbies[1]
    assert(dq.players[1] == 77 and dq.need == nil and dq.mode == "Next opening in the war" and dq.startsInMs == nil)
    Turf.queue[1] = nil

    -- long enough to count, then the target
    advance(150000)
    assert(war.state == "running" and war.zones[1].owner == 1)
    war.sides[1].score = CFG.match.targetScore - 5
    war.sides[2].score = math.min(war.sides[2].score, 100)
    local resultsFrom = #core.results + 1
    advance(6000)
    assert(war.state == "resolved" and war.winner == 1 and war.reason == "target")
    assert(war.counted == true)
    local r1, r4, r7, r10 = resultOf(1, resultsFrom), resultOf(4, resultsFrom), resultOf(7, resultsFrom), resultOf(10, resultsFrom)
    assert(r1 and r1.won == true and r1.placement == 1 and r1.stats.gang == "valentinos" and r1.stats.captures == 1)
    assert(r1.stats.kills == 1 and r1.stats.deaths == 0 and r1.stats.holdSeconds >= 9)
    assert(r1.reputation == CFG.rewards.win + math.min(1 * CFG.rewards.perCapture + 1 * CFG.rewards.perKill, CFG.rewards.bonusCap))
    assert(r4 and r4.won == false and r4.placement == 2 and r4.stats.deaths == 1 and r4.reputation >= CFG.rewards.loss)
    assert(r7 and r7.stats.mercenary == true and r7.stats.gang == nil and r7.won == true)
    assert(r10 and r10.reputation > 0, "the late joiner played long enough")
    local n = 0
    for i = resultsFrom, #core.results do n = n + 1; assert(core.results[i].activity == "turf.war") end
    assert(n == 9, "one result per fighter: " .. n)
    -- the board for Light RP's end-of-match recap: the same for every fighter
    local board = r1.recap
    assert(board and board.matchId == r4.recap.matchId and board.matchId:match("^turf:pvp:%d+@%d+$"), tostring(board and board.matchId))
    assert(board.detail == "Turf War" and board.winnerSide == 1 and board.sides[1].score >= CFG.match.targetScore)
    assert(board.sides[1].label == war.sides[1].label and #board.rows >= 9 and board.lines[1].label == "Site")
    local row1
    for _, row in ipairs(board.rows) do if row.id == 1 then row1 = row end end
    assert(row1 and row1.side == 1 and row1.kills == 1 and row1.captures == 1 and row1.holdS >= 9 and row1.bot == nil)
    assert(table.concat(board.columns, ",") == "kills,deaths,captures,holdS,score")
    -- influence of the week, in memory now (the database thread is not run here)
    local val, mae = TurfInfluence.rows.valentinos, TurfInfluence.rows.maelstrom
    assert(val and val.points == CFG.influence.win + 2 * CFG.influence.perCapture and val.wins == 1 and val.wars == 1)
    assert(mae and mae.points == CFG.influence.loss and mae.wins == 0)
    assert(TurfInfluence.rows.tyger_claws == nil, "a mercenary's gang earns nothing")
    local list, week = host.exports.influence()
    assert(list[1].gang == "valentinos" and list[2].gang == "maelstrom" and week == R.weekIndex(W.unix()))
    assert(#host.exports.influence(1) == 1)
    local points, rank = host.exports.influenceOf("Valentinos")
    assert(points == val.points and rank == 1)
    assert(host.exports.influenceOf("animals") == nil)
    local card = pushed(1, "result", "VICTORY")
    assert(card and card.payload.placement == 1)
    local hasCity, hasInfluence = false, false
    for _, line in ipairs(card.payload.lines) do
        if line.label == "Who holds the city" then hasCity = line.value:find("Valentinos") ~= nil end
        if line.label == "Valentinos influence" then hasInfluence = true end
    end
    assert(hasCity and hasInfluence, "the end card shows the week's influence")
    assert(pushed(4, "result", "DEFEAT"))
    assert(Turf.sharedView(war, clock).influence[1].gang == "valentinos", "and so does the ended HUD")

    -- the scoreboard, then everyone goes home
    local leavesFrom = #core.leaves + 1
    assert(war.releaseAt - war.resolvedAt == CFG.match.scoreboardSeconds * 1000)
    advance(war.releaseAt - clock - 250)
    assert(Turf.war == war and #core.leaves == leavesFrom - 1, "the end card stays up")
    advance(500)
    local left = leftIds(leavesFrom)
    for _, id in ipairs({ 1, 2, 3, 4, 5, 6, 7, 8, 10 }) do
        assert(left[id] and left[id].opts.returnPlayer == true, "returned: " .. id)
        assert(teams[id] == 0 and core.owned[id] == nil and (clearedKits[id] or 0) >= 1)
    end
    assert(Turf.war == nil, "closed")
    advance(1000)
    assert(lastStatus().phase == "idle")

    -- ============================================================ forfeit + dropped (testing mode)
    command("turf.testing", 0, { "on" })
    assert(Turf.testing and Turf.minPlayers() == 2)
    addPlayer(11, "animals"); addPlayer(12, "animals"); addPlayer(13, "voodoo_boys")
    for _, id in ipairs({ 11, 12, 13 }) do clock = clock + 10; fire("op77_lightrp:activity:join", nil, id, "turf.war", {}) end
    advance(46000)
    war = Turf.war
    assert(war and war.members[11].side == 1 and war.members[12].side == 1 and war.members[13].side == 2)
    flush(); advance(250); advance(10000)
    assert(war.state == "running")
    resultsFrom, leavesFrom = #core.results + 1, #core.leaves + 1
    fire("op77_lightrp:activity:leaveRequest", nil, 12, "turf.war")
    local r12 = resultOf(12, resultsFrom)
    assert(r12 and r12.reputation == 0 and r12.won == false and r12.stats.forfeit == true, "a forfeit, no reputation")
    local left12
    for _, row in ipairs(r12.recap.rows) do if row.id == 12 then left12 = row end end
    assert(left12 and left12.left == true and r12.recap.winnerSide == nil, "mid-war: the leaver marked, no winner yet")
    assert(leftIds(leavesFrom)[12] and core.owned[12] == nil and teams[12] == 0)
    assert(war.state == "running", "his side plays on")
    core.owned[13] = nil -- Light RP released him before telling us
    fire("op77_lightrp:activity:dropped", nil, 13, "turf.war", "disconnected")
    assert(war.members[13].gone and teams[13] == 0)
    assert(not leftIds(leavesFrom)[13], "dropped: never activityLeave'd")
    assert(war.state == "resolved" and war.winner == 1 and war.reason == "forfeit")
    local r11 = resultOf(11, resultsFrom)
    assert(r11 and r11.won == true and r11.reputation == 0, "too short to count")
    assert(resultOf(13, resultsFrom) == nil)
    advance(10500)
    assert(leftIds(leavesFrom)[11] and Turf.war == nil)

    -- ============================================================ Light RP restarts mid-war
    addPlayer(21, nil); addPlayer(22, nil); addPlayer(23, nil)
    for _, id in ipairs({ 21, 22 }) do clock = clock + 10; fire("op77_lightrp:activity:join", nil, id, "turf.war", {}) end
    advance(46000)
    war = Turf.war
    assert(war and war.sides[1].gang == nil and war.sides[1].label == "Free Agents" and war.members[21].merc)
    flush(); advance(250); advance(10000)
    assert(war.state == "running")
    core.busy[23] = "You are in a vehicle."
    fire("op77_lightrp:activity:join", nil, 23, "turf.war", {})
    advance(1000)
    assert(#Turf.queue == 1, "not ready: stays queued")
    local scope = war.scope
    resultsFrom, leavesFrom = #core.results + 1, #core.leaves + 1
    core.owned[21], core.owned[22] = nil, nil -- the stopping core returned them
    fire("onResourceStop", nil, "op77_lightrp")
    assert(Turf.war == nil and war.void and #Turf.queue == 0)
    assert(#core.leaves == leavesFrom - 1 and #core.results == resultsFrom - 1, "no leave, no result: the core is gone")
    assert(teams[21] == 0 and teams[22] == 0 and removed[scope] and (cleared[23] or 0) >= 1)
    local registered = core.registerCount
    fire("op77_lightrp:activity:ready", nil)
    host.threads[#host.threads]()
    assert(core.registerCount == registered + 1, "registered again on ready")
    fire("onResourceStart", nil, "op77_lightrp")
    host.threads[#host.threads]()
    assert(core.registerCount == registered + 2, "and on a core start")

    -- ============================================================ staff-scheduled war, then stopped
    local nAnn = #core.announces
    command("turf.schedule", 0, { "badlands", "10" })
    assert(lastReply.ok and Turf.schedule and core.announces[nAnn + 1]:find("Badlands Compound") and core.announces[nAnn + 1]:find("10 min"))
    advance(1000)
    assert(lastStatus().phase == "idle" and lastStatus().detail:find("Scheduled"))
    advance(300000)
    local function announced(pattern)
        for i = nAnn + 1, #core.announces do if core.announces[i]:find(pattern) then return true end end
    end
    assert(announced("in 5 min") and not announced("in 2 min"))
    advance(300000)
    assert(announced("in 2 min") and announced("in 1 min") and announced("in 30 s"))
    assert(Turf.lobby and Turf.lobby.scheduled and Turf.lobby.site == "badlands" and announced("is open"))
    addPlayer(41, "valentinos"); addPlayer(42, "maelstrom")
    command("turf", 41, { "join" })
    assert(lastReply.ok and #Turf.queue == 1)
    command("turf", 42, { "join", "kabuki" })
    assert(#Turf.queue == 2 and Turf.queue[2].site == "kabuki")
    command("turf", 42, { "kit", "gunner" })
    assert(lastReply.ok and Turf.queue[2].kit == "gunner")
    advance(61000)
    war = Turf.war
    assert(war and war.site.id == "badlands", "the scheduled site, whatever the votes")
    assert(war.members[42].kit == "gunner")
    flush(); advance(250)
    assert(war.state == "countdown")
    resultsFrom = #core.results + 1
    command("turf.stop", 0, {})
    assert(lastReply.ok and war.void and war.state == "resolved")
    assert(#core.results == resultsFrom - 1, "a stopped war sends no result")
    assert(pushed(41, "result", "WAR CALLED OFF") and frozen[41] == false)
    advance(10500)
    assert(Turf.war == nil and core.owned[41] == nil and core.owned[42] == nil)

    -- a war needs two sides: one crew alone splits (training war)
    addPlayer(51, "animals"); addPlayer(52, "animals")
    command("turf", 51, {}); command("turf", 52, {})
    command("turf.start", 0, { "kabuki" })
    war = Turf.war
    assert(war and war.members[51].side ~= war.members[52].side and war.members[52].merc, "a turncoat on the other side")

    -- ============================================================ the provider restarts
    flush(); advance(250)
    assert(war.state == "countdown" and frozen[51] == true)
    fire("onResourceStop", nil, "op77_turf")
    assert(teams[51] == 0 and teams[52] == 0 and frozen[51] == false and frozen[52] == false)
    assert(host.offDamage[1] == host.damage, "the arbiter is removed")

    command("turf.survey", 51, { "test", "mark" })
    assert(lastReply.ok and lastReply.text:find("heading = 90.0") and lastReply.text:find("test mark"))
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
    realPrint(table.concat(logs, "\n", math.max(1, #logs - 40)))
    error(err, 0)
end
realPrint("PASS war_test: registration, leaveRequest while queued, join->enter->countdown->capture/contest/kills/respawn timing/protection/kits/bounds/late joiner->target->results+influence->release->leave, forfeit+dropped, Light RP restart, scheduled war+stop, training split, provider restart")
