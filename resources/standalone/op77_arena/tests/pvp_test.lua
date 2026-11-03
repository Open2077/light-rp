-- server/pvp.lua on the real engine and adapter (the manifest's server side), against a
-- simulated platform that keeps scopes the way DamageAuthorityService.CombatScopes does:
-- 2..32 unique combat-capable players in the bucket, one scope per player, 8 per
-- resource, a bucket change drops a participant and a scope under two goes by itself,
-- global PvP off. Covers: no scope for one person, a scope at two, rebuilt on join and
-- leave, kept through a death, removed when the instance empties or closes and on stop,
-- Team Arena sides (no friendly fire) and their clearing, the duel's 2-player scope,
-- PvE without a scope, the 8-slot budget gate, the 32-player cap, refusals (logged once,
-- retried, told), the periodic heal, the in-instance damage scale, the instance damage
-- gate still vetoing cross-instance hits, and never a global friendly fire.
-- Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test pvp_test.lua
local say = print
_G.print = function() end

local T = 7000000
local online = {}
for id = 3, 40 do online[id] = true end
local life = {}     -- id -> { phase, bucket }
local teams = {}    -- id -> combat team (Open77.combat.setTeam)
local teamCalls = {}
local ffCalls = {}
local logs = {}
local arbiters = {}
local handlers = {}
local notices = {}

for id in pairs(online) do life[id] = { phase = "alive", bucket = 0 } end

-- ---------------------------------------------------------------- platform --

local platform = { scopes = {}, byPlayer = {}, created = {}, removed = {}, nextId = 1, refuse = nil }

local function dropParticipant(id)
    local sid = platform.byPlayer[id]
    if sid == nil then return end
    platform.byPlayer[id] = nil
    local scope = platform.scopes[sid]
    if scope == nil then return end
    scope.players[id] = nil
    local n = 0
    for _ in pairs(scope.players) do n = n + 1 end
    if n < 2 then
        for p in pairs(scope.players) do platform.byPlayer[p] = nil end
        platform.scopes[sid] = nil
    end
end

local function setBucket(id, bucket)
    local l = life[id]
    if l == nil or bucket == nil then return end
    if l.bucket ~= bucket then dropParticipant(id) end
    l.bucket = bucket
end

local function capable(id)
    local l = life[id]
    return l ~= nil and (l.phase == "alive" or l.phase == "recovering")
end

local function scopeCount()
    local n = 0
    for _ in pairs(platform.scopes) do n = n + 1 end
    return n
end

-- The platform's PvP rule with global friendly fire OFF: same scope, same bucket, both
-- able to fight, not on one nonzero team.
local function canHurt(a, b)
    local sa, sb = platform.byPlayer[a], platform.byPlayer[b]
    if sa == nil or sa ~= sb then return false end
    local scope = platform.scopes[sa]
    if scope == nil or life[a].bucket ~= scope.bucket or life[b].bucket ~= scope.bucket then return false end
    if not capable(a) or not capable(b) then return false end
    local ta, tb = teams[a] or 0, teams[b] or 0
    if ta ~= 0 and ta == tb then return false end
    return true
end

local function stub(path)
    return setmetatable({}, {
        __index = function(t, k) local child = stub(path .. "." .. tostring(k)); rawset(t, k, child); return child end,
        __call = function() return nil end,
    })
end
_G.Open77 = stub("Open77")
Open77.time.unix = function() return 1700000000 end
Open77.time.nowMs = function() return T end
Open77.time.monotonic = function() return T end
Open77.ready.isReady = function(id) return online[tonumber(id)] == true end
Open77.players.name = function(id) return online[tonumber(id)] and ("acct" .. tostring(id)) or nil end
Open77.players.getLifeState = function(id)
    local l = life[tonumber(id)]
    return l and { phase = l.phase, bucket = l.bucket } or nil
end
Open77.players.position = function(id)
    local l = life[tonumber(id)]
    return l and { x = 2990.0 + (tonumber(id) or 0), y = -2400.0, z = 118.0, bucket = l.bucket } or nil
end
Open77.players.teleport = function(id, pos, opts)
    setBucket(tonumber(id), opts and tonumber(opts.bucket))
    return { await = function() return true end }
end
Open77.players.respawn = function(id, opts)
    setBucket(tonumber(id), opts and tonumber(opts.bucket))
    life[tonumber(id)].phase = "alive"
    return true
end
Open77.players.kill = function(id) life[tonumber(id)].phase = "dead"; return true end
Open77.combat.onDamage = function(fn) arbiters[#arbiters + 1] = fn; return fn end
Open77.combat.setTeam = function(id, team)
    teams[tonumber(id)] = team
    teamCalls[#teamCalls + 1] = { id = tonumber(id), team = team }
    return true
end
Open77.combat.setFriendlyFire = function(enabled) ffCalls[#ffCalls + 1] = enabled; return true end
Open77.combat.createScope = function(def)
    platform.created[#platform.created + 1] = def
    if platform.refuse then return nil, platform.refuse end
    local players = def.players
    if type(players) ~= "table" or #players < 2 or #players > 32 then return nil, "invalid_scope" end
    local seen = {}
    for _, p in ipairs(players) do
        if type(p) ~= "number" or p <= 0 or seen[p] then return nil, "invalid_scope" end
        seen[p] = true
    end
    if scopeCount() >= 8 then return nil, "scope_limit" end
    for _, p in ipairs(players) do
        local l = life[p]
        if l == nil or l.bucket ~= def.bucket or not capable(p) then return nil, "player_unavailable" end
        if platform.byPlayer[p] then return nil, "player_scoped" end
    end
    local sid = ("%032x"):format(platform.nextId)
    platform.nextId = platform.nextId + 1
    platform.scopes[sid] = { bucket = def.bucket, players = seen }
    for _, p in ipairs(players) do platform.byPlayer[p] = sid end
    return sid
end
Open77.combat.removeScope = function(sid)
    platform.removed[#platform.removed + 1] = sid
    local scope = platform.scopes[sid]
    if scope == nil then return nil, "scope_unavailable" end
    for p in pairs(scope.players) do platform.byPlayer[p] = nil end
    platform.scopes[sid] = nil
    return true
end

-- Light RP's contract: always yes; activityLeave brings the player home (bucket 0).
local answers = { activityCheck = true, activityEnter = true, activityRegister = true, activityBots = false }
answers.activityLeave = function(id) setBucket(tonumber(id), 0); return true end
Open77.exports.callSync = function(resource, name, ...)
    local answer = answers[name]
    if type(answer) == "function" then return answer(...) end
    return answer
end

_G.json = { encode = function() return "{}" end, decode = function() return {} end }
_G.RegisterCommand = function() end
_G.AddEventHandler = function(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
_G.RegisterNetEvent = function() end
_G.TriggerEvent = function() end
_G.TriggerClientEvent = function(name, target, payload)
    if name == "deathmatch:notice" and type(payload) == "table" then
        notices[#notices + 1] = { target = target, title = payload.title, message = payload.message }
    end
end
local loading, pending = true, {}
_G.CreateThread = function(fn) if not loading then pending[#pending + 1] = fn end end
_G.SetTimeout = function() end
_G.Wait = function() end
_G.GetCurrentResourceName = function() return "op77_arena" end
_G.GetResourceState = function() return "running" end
_G.GetPlayers = function() local out = {} for id in pairs(online) do out[#out + 1] = tostring(id) end return out end
_G.GetPlayerName = function() return nil end
_G.GetPlayerIdentifiers = function() return {} end
_G.SetPlayerRoutingBucket = function(id, bucket) setBucket(tonumber(id), tonumber(bucket)); return true end
_G.GetPlayerRoutingBucket = function(id) local l = life[tonumber(id)]; return l and l.bucket or 0 end
_G.IsPlayerAceAllowed = function() return false end
_G.SetRoutingBucketPopulationEnabled = function() end
_G.SetRoutingBucketEntityLockdownMode = function() end
_G.exports = setmetatable({}, { __index = function() return stub("exports") end, __call = function() end })

local manifest = io.open("open77.lua"):read("a")
for kind, path in manifest:gmatch('(%w+_script) "([^"]+)"') do
    if kind ~= "client_script" then
        local ok, err = pcall(dofile, path)
        assert(ok, path .. ": " .. tostring(err))
    end
end
loading = false

local DM, H, L, P = Deathmatch, ArenaHost, LightRpArena, ArenaPvp
DM.nowMs = function() return T end
DM.tune = DM.tune or {}
local engineLog = DM.log
DM.log = function(text) logs[#logs + 1] = tostring(text); return engineLog(text) end

-- Threads started by a flow (the way home, a teleport's await) run when drained.
local function drain()
    for _ = 1, 10 do
        if #pending == 0 then return end
        local batch = pending
        pending = {}
        for _, fn in ipairs(batch) do pcall(fn) end
    end
end
local function fire(name, ...) for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
local function step(ms) T = T + (ms or 600) end
local function tick(ms) step(ms); P.tick(T) end
local function join(id, key, options)
    step(1000)
    fire("op77_lightrp:activity:join", id, L.activities[key].id, options or {})
    drain()
end
local function leave(id, key)
    step(1000)
    fire("op77_lightrp:activity:leaveRequest", id, L.activities[key].id)
    drain()
end
local function logged(pattern)
    local n = 0
    for _, line in ipairs(logs) do if line:find(pattern) then n = n + 1 end end
    return n
end
local function scopeOf(instance) return P.scopes[instance.id] end
local function members(instance)
    local held = scopeOf(instance)
    local out = {}
    if held then for id in pairs(held.players) do out[#out + 1] = id end end
    table.sort(out)
    return table.concat(out, ",")
end
local function platformMembers(id)
    local sid = platform.byPlayer[id]
    local out = {}
    if sid and platform.scopes[sid] then for p in pairs(platform.scopes[sid].players) do out[#out + 1] = p end end
    table.sort(out)
    return table.concat(out, ",")
end
-- The engine's arbiter (main.lua) and whatever pvp.lua installed, chained as the host does.
local function arbitrate(event)
    local amount = event.amount
    for _, fn in ipairs(arbiters) do
        local ok, result = pcall(fn, event)
        if ok then
            if result == false then return false end
            if type(result) == "number" then amount = result; event.amount = result end
        end
    end
    return true, amount
end

-- ── wiring ──
do
    assert(type(P) == "table", "server/pvp.lua loaded")
    assert(P.budget() == 8 and P.maxPlayers() == 32, "the platform's limits")
    assert(#arbiters == 1, "only the engine's arbiter at the default time-to-kill (no idle arbiter)")
    assert(#ffCalls == 0, "nothing touches global friendly fire at load")
    say("PASS wiring")
end

-- ── Combat Zone: one person, no scope; two, a scope; rebuilt on join and leave ──
local ffa
do
    join(3, "ffa")
    ffa = DM.instances.of(3)
    assert(ffa and ffa.format == "ffa" and ffa.bucket == 4100000, "player 3 in the Combat Zone")
    assert(life[3].bucket == 4100000, "placed in the arena bucket")
    tick()
    assert(scopeOf(ffa) == nil and #platform.created == 0, "one person: no scope")
    assert(not canHurt(3, 4), "nobody to fight")

    join(4, "ffa")
    assert(DM.instances.of(4) == ffa, "player 4 in the same instance")
    tick()
    assert(members(ffa) == "3,4", "a scope over the two people: " .. members(ffa))
    local def = platform.created[#platform.created]
    assert(def.bucket == 4100000 and #def.players == 2, "createScope in the instance bucket")
    assert(canHurt(3, 4) and canHurt(4, 3), "they can hurt each other")
    assert(not canHurt(3, 5), "nobody outside the arena")
    assert(logged("PvP scope opened") == 1, "creation logged once")
    local created = #platform.created
    tick()
    tick()
    assert(#platform.created == created, "a stable roster is not rebuilt every tick")

    join(5, "ffa")
    tick()
    assert(members(ffa) == "3,4,5", "rebuilt on join: " .. members(ffa))
    assert(canHurt(5, 3) and canHurt(4, 5), "the newcomer fights everybody")
    assert(scopeCount() == 1, "the old scope was removed, one left")
    assert(logged("PvP scope opened") == 1, "a rebuild is not logged again")
    say("PASS Combat Zone scope: none for one, created at two, rebuilt on join")
end

-- ── a death keeps the scope; the respawn does not need a rebuild ──
do
    local created = #platform.created
    life[4].phase = "dead"
    tick()
    assert(#platform.created == created and members(ffa) == "3,4,5", "a dead fighter stays in the scope")
    assert(not canHurt(3, 4), "nobody hurts a body")
    life[4].phase = "alive"
    tick()
    assert(#platform.created == created and canHurt(3, 4), "the respawned fighter is still in it")
    say("PASS death and respawn keep the scope")
end

-- ── leaving: rebuilt without them; the street outside has no PvP ──
do
    leave(5, "ffa")
    assert(DM.instances.of(5) == nil and life[5].bucket == 0, "player 5 home, bucket 0")
    assert(platformMembers(3) == "3,4", "the platform already dropped the leaver (bucket change)")
    tick()
    assert(members(ffa) == "3,4", "rebuilt without the leaver: " .. members(ffa))
    assert(not canHurt(5, 6) and not canHurt(5, 3), "no PvP in the street")

    leave(4, "ffa")
    tick()
    assert(scopeOf(ffa) == nil and scopeCount() == 0, "one person left: scope removed")
    assert(not canHurt(3, 4), "no PvP with a single fighter")

    join(4, "ffa")
    tick()
    assert(members(ffa) == "3,4", "back to two: a scope again")
    say("PASS leave: rebuilt, removed under two, recreated")
end

-- ── left and back between two ticks: still rebuilt (the platform dropped them) ──
do
    leave(4, "ffa")
    join(4, "ffa")
    assert(platformMembers(4) == "", "the platform no longer has player 4 in a scope")
    tick()
    assert(platformMembers(4) == "3,4" and canHurt(3, 4), "rebuilt although the roster looks the same")
    say("PASS bounce out and back is healed")
end

-- ── the periodic heal: a removal nobody saw is repaired within refreshMs ──
do
    local sid = platform.byPlayer[3]
    Open77.combat.removeScope(sid) -- something outside this resource's view
    assert(not canHurt(3, 4))
    tick(1000)
    assert(not canHurt(3, 4), "not yet: the roster did not change")
    tick(L.pvp.refreshMs)
    assert(canHurt(3, 4), "healed by the periodic rebuild")
    say("PASS periodic heal")
end

-- ── the instance damage gate still vetoes what the scope allows across instances ──
local duel
do
    join(7, "duel")
    join(8, "duel")
    duel = DM.instances.of(7)
    assert(duel and duel.format == "1v1" and DM.instances.of(8) == duel, "a duel formed from the random queue")
    assert(duel.bucket >= 4100100 and duel.bucket <= 4100199, "duel bucket")
    tick()
    assert(members(duel) == "7,8", "the duel's 2-player scope: " .. members(duel))
    assert((teams[7] or 0) ~= 0 and (teams[8] or 0) ~= 0 and teams[7] ~= teams[8], "two corners, two teams")
    assert(canHurt(7, 8), "the duellists can hurt each other")
    assert(not canHurt(7, 3) and not canHurt(3, 8), "no hit across instances")
    -- The engine's arbiter (main.lua) is the second lock: a forged cross-instance report.
    local allowed = arbitrate({ victim = 3, attacker = 7, amount = 10, attackKind = "ranged", weaponTdbId = "x" })
    assert(allowed == false, "the instance damage gate refuses a cross-instance hit")
    -- Elimination: the body stays dead in the scope until the next round places it.
    local created = #platform.created
    life[8].phase = "dead"
    tick()
    assert(#platform.created == created and members(duel) == "7,8", "an eliminated duellist stays in the scope")
    say("PASS duel scope, teams, cross-instance veto")
end

-- ── Team Arena: one scope, sides on teams, teammates cannot hurt each other ──
local teamsMatch
do
    for _, id in ipairs({ 11, 12, 13, 14 }) do join(id, "teams", { mode = "2v2" }) end
    teamsMatch = DM.instances.of(11)
    assert(teamsMatch and teamsMatch.format == "2v2", "a 2v2 formed")
    tick()
    assert(members(teamsMatch) == "11,12,13,14", "one scope over the four: " .. members(teamsMatch))
    local sides = teamsMatch.match.sides
    local mate, foe
    for _, id in ipairs({ 12, 13, 14 }) do
        if sides[id] == sides[11] then mate = id else foe = foe or id end
    end
    assert(mate and foe, "two sides")
    assert(teams[11] == sides[11] and teams[mate] == sides[11] and teams[foe] == sides[foe], "teams = sides")
    assert(not canHurt(11, mate) and not canHurt(mate, 11), "no friendly fire between teammates")
    assert(canHurt(11, foe) and canHurt(foe, mate), "the other side can be hurt")
    -- Leaving mid-match: team cleared, scope rebuilt without them.
    leave(foe, "teams")
    assert(teams[foe] == 0, "the leaver's team is cleared")
    tick()
    assert(not members(teamsMatch):find(tostring(foe)), "rebuilt without the leaver: " .. members(teamsMatch))
    assert(not canHurt(foe, 11), "the leaver is out of it")
    say("PASS Team Arena: sides on teams, no friendly fire, leaver cleared")
end

-- ── PvE: players against bots, never a scope ──
local pve
do
    join(20, "pve")
    join(21, "pve")
    pve = DM.instances.of(20)
    assert(pve and pve.ruleset == "pve" and DM.instances.of(21) == pve, "two players in the PvE Combat Zone")
    tick()
    assert(scopeOf(pve) == nil, "PvE gets no scope")
    for _, def in ipairs(platform.created) do assert(def.bucket ~= pve.bucket, "never a createScope in the PvE bucket") end
    assert(not canHurt(20, 21), "PvE players cannot hurt each other")
    assert(not P.holdsSlot(pve), "PvE holds no scope slot")
    say("PASS PvE has no scope")
end

-- ── the budget: 8 per resource; a PvP instance beyond it does not open ──
do
    -- Open now: Combat Zone, the duel, the team match = 3. Blade Night = 4.
    join(22, "blade")
    local blade = DM.instances.of(22)
    assert(blade and blade.ruleset == "blade", "Blade Night open")
    assert(P.slotsInUse() == 4, "4 slots: " .. P.slotsInUse())
    local duels = {}
    local id = 23
    for _ = 1, 4 do
        join(id, "duel"); join(id + 1, "duel")
        duels[#duels + 1] = DM.instances.of(id)
        assert(duels[#duels] and DM.instances.of(id + 1) == duels[#duels], "duel formed")
        id = id + 2
    end
    assert(P.slotsInUse() == 8, "8 slots: " .. P.slotsInUse())
    tick()
    assert(scopeCount() <= 8, "never more than the platform allows")
    -- A ninth PvP instance: refused, never opened without a scope.
    join(31, "duel"); join(32, "duel")
    assert(DM.instances.of(31) == nil and DM.instances.of(32) == nil, "the ninth PvP instance is refused")
    assert(logged("PvP scope slots in use") == 1, "the refusal is logged once")
    local again = select(2, DM.instances.open("1v1"))
    assert(again == "pvp_scope_limit", "the gate answers pvp_scope_limit")
    assert(logged("PvP scope slots in use") == 1, "not logged again in the same streak")
    -- PvE is not PvP: it still opens (here: already open, the player joins it).
    join(33, "pve")
    assert(DM.instances.of(33) == pve, "PvE unaffected by the budget")
    -- A duel ends: a slot frees and the next one forms.
    leave(23, "duel")
    drain()
    tick()
    assert(P.slotsInUse() == 7, "a slot freed: " .. P.slotsInUse())
    join(31, "duel"); join(32, "duel")
    assert(DM.instances.of(31) ~= nil and DM.instances.of(31) == DM.instances.of(32), "the next duel forms")
    tick()
    assert(canHurt(31, 32), "with its scope")
    say("PASS 8-slot budget: refused beyond it, logged once, freed on close")
end

-- ── a refusal: logged once per instance and reason, retried, told if it lasts ──
do
    local instance = DM.instances.of(31)
    local held = scopeOf(instance)
    P.release(instance, "test")
    platform.refuse = "scope_limit"
    local before = logged("PvP scope refused")
    tick()
    assert(scopeOf(instance) == nil and logged("PvP scope refused") == before + 1, "refusal logged")
    local tries = #platform.created
    tick(200)
    assert(#platform.created == tries, "not retried every tick")
    tick(L.pvp.retryMs)
    assert(#platform.created == tries + 1, "retried after retryMs")
    assert(logged("PvP scope refused") == before + 1, "not logged again")
    local told = #notices
    tick(L.pvp.tellAfterMs)
    local tellings = 0
    for index = told + 1, #notices do
        if notices[index].title == "NO PVP" then tellings = tellings + 1 end
    end
    assert(tellings == 2, "both players told once the refusal lasts: " .. tellings)
    tick(L.pvp.retryMs)
    for index = told + 3, #notices do assert(notices[index].title ~= "NO PVP", "told once") end
    platform.refuse = nil
    tick(L.pvp.retryMs)
    assert(scopeOf(instance) ~= nil and canHurt(31, 32), "restored")
    assert(logged("PvP scope restored") >= 1, "restoration logged")
    assert(held ~= nil)
    say("PASS refusal: logged once, retried, told, restored")
end

-- ── the 32-player cap ──
do
    -- Capacity: an unlimited free-for-all would be clamped to one scope's worth.
    local zone = DM.instances.of(3)
    for _, id in ipairs(DM.instances.humans(zone)) do leave(id, "ffa") end
    drain()
    DM.instances.close(zone, "test")
    assert(scopeOf(zone) == nil, "closed: no scope")
    DeathmatchConfig.instances.ffaUnlimited = true
    local unlimited = DM.instances.open("ffa", "standard")
    DeathmatchConfig.instances.ffaUnlimited = false
    assert(unlimited and unlimited.capacity == 32, "PvP capacity clamped to 32: " .. tostring(unlimited and unlimited.capacity))
    -- A roster over 32 (forced through attach): the first 32 by arrival, said once.
    for id = 100, 139 do
        life[id] = { phase = "alive", bucket = unlimited.bucket }
        DM.instances.attach(unlimited, id)
    end
    tick()
    local held = scopeOf(unlimited)
    assert(held and #held.list == 32 and held.list[1] == 100 and held.list[32] == 131, "the first 32 by arrival")
    assert(logged("platform limit") == 1, "said once")
    for id = 100, 139 do DM.instances.detach(id, "test") end
    DM.instances.close(unlimited, "test")
    assert(scopeOf(unlimited) == nil, "removed on close")
    say("PASS 32-player cap")
end

-- ── close and empty: the scope goes with the instance ──
do
    -- A duellist walks out: the duel is forfeited and its scope goes.
    local instance = DM.instances.of(31)
    local sid = scopeOf(instance).id
    leave(31, "duel")
    drain()
    tick()
    assert(platform.scopes[sid] == nil and scopeOf(instance) == nil, "the forfeited duel's scope is gone")
    if instance.closed then assert(P.books[instance.id] == nil, "forgotten once closed") end
    -- The close hook: the scope goes with the close itself, not at the next tick.
    local held = scopeOf(teamsMatch)
    assert(held ~= nil, "the team match still fights with its scope")
    local removed = #platform.removed
    DM.instances.close(teamsMatch, "test")
    assert(platform.removed[removed + 1] == held.id and platform.scopes[held.id] == nil, "removeScope at the close")
    assert(scopeOf(teamsMatch) == nil and P.books[teamsMatch.id] == nil, "nothing kept for a closed instance")
    assert(logged("PvP scope closed") >= 1, "the closure is logged")
    say("PASS close removes the scope")
end

-- ── the in-instance time-to-kill scale (default 1.0: untouched) ──
do
    local blade = DM.instances.of(22)
    join(34, "blade")
    assert(DM.instances.of(34) == blade)
    local hit = { victim = 22, attacker = 34, amount = 40, bodyPart = "torso", attackKind = "melee" }
    assert(P.scaleDamage(hit) == nil, "1.0: the amount is left alone")
    L.pvp.damageMultiplier, L.pvp.headshotMultiplier = 0.5, 3.0
    assert(P.scaleDamage(hit) == 20, "scaled inside the PvP instance")
    assert(P.scaleDamage({ victim = 22, attacker = 34, amount = 40, bodyPart = "head" }) == 60, "headshot factor on top")
    assert(P.scaleDamage({ victim = 20, attacker = 21, amount = 40 }) == nil, "never in PvE")
    assert(P.scaleDamage({ victim = 22, attacker = 7, amount = 40 }) == nil, "never across instances")
    assert(P.scaleDamage({ victim = 22, attacker = 12884901889, amount = 40 }) == nil, "never a bot's hit")
    assert(P.scaleDamage({ victim = 5, attacker = 6, amount = 40 }) == nil, "never in the city")
    assert(P.scaleDamage({ victim = 22, attacker = 22, amount = 40 }) == nil, "never self-damage")
    L.pvp.damageMultiplier, L.pvp.headshotMultiplier = 1.0, 1.0
    say("PASS time-to-kill scale stays inside PvP instances")
end

-- ── resource stop: every scope released ──
do
    tick()
    assert(scopeCount() > 0, "scopes are open before the stop")
    fire("onResourceStop", "op77_arena")
    assert(scopeCount() == 0, "every scope removed on stop")
    assert(next(P.scopes) == nil and P.stopped, "nothing held")
    local created = #platform.created
    P.tick(T + 1000)
    assert(#platform.created == created, "nothing created after the stop")
    say("PASS stop releases every scope")
end

-- ── never global friendly fire, at runtime or in the source ──
do
    for _, enabled in ipairs(ffCalls) do assert(enabled ~= true, "setFriendlyFire(true) was called") end
    local files = {}
    for kind, path in manifest:gmatch('(%w+_script) "([^"]+)"') do files[#files + 1] = path end
    for _, path in ipairs(files) do
        local n = 0
        for line in io.lines(path) do
            n = n + 1
            local code = line:gsub("%-%-.*$", "")
            assert(not code:find("setFriendlyFire", 1, true), ("%s:%d calls setFriendlyFire"):format(path, n))
        end
    end
    say("PASS no setFriendlyFire anywhere")
end

say("PASS: op77_arena pvp scopes (one/two/join/leave, death, bounce, heal, duel, teams, PvE, budget, refusal, 32 cap, close, damage scale, stop, no global PvP)")
