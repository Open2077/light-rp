-- Arena kits are issued inside the buy window, not at GO (2026-11-04). On the real
-- engine (the manifest's server side) with stubbed natives, a fake client weapon
-- inventory, a timer queue and a coroutine scheduler for the teleport promise:
--   * the kit is issued only once the round-start placement has LANDED (teleport
--     settled / respawn acknowledged), still in the buy window, with the 250 ms gap;
--   * a buy-window kit change re-issues at once; re-picking the same kit does not;
--   * a late completion from a superseded version is dropped;
--   * no damage is accepted during the buy window (M5, and player -> bot reports);
--   * GO with a verified matching kit sends reserve ammunition and nothing else;
--   * GO with an issue still in flight leaves it alone (Team Arena 2v2);
--   * GO with nothing verified falls back to the full issue;
--   * between rounds an unchanged kit is checked with a snapshot: kept weapons are
--     not re-issued (holstered ones are drawn), wiped ones are re-issued in the window.
-- Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test arena_kit_test.lua
local say = print
local logs = {}
_G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    logs[#logs + 1] = table.concat(parts, " ")
end

local T = 9000000
local loading = true
local online = {}
for id = 3, 40 do online[id] = true end
local handlers, net = {}, {}
local answers = { activityCheck = true, activityEnter = true, activityLeave = true, activityRegister = true, activityBots = false }
answers.activityPlayer = function(id) return { name = "Char" .. tostring(id), identifier = "license:" .. tostring(id) } end

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
Open77.exports.callSync = function(resource, name, ...)
    local answer = answers[name]
    if type(answer) == "function" then return answer(...) end
    return answer
end

-- ---------------------------------------------------------------- scheduler --
-- Threads and timers started while the manifest loads are dropped (the engine
-- tick loop, registration retries), exactly as the other suites do. After that,
-- `CreateThread` runs a real coroutine, `Wait` yields until the clock gets there
-- and a teleport promise's `await` yields until the test lands it.
local threads, timers = {}, {}
local function resume(thread)
    local ok, condition = coroutine.resume(thread.co)
    assert(ok, "thread raised: " .. tostring(condition))
    thread.condition = condition
end
_G.CreateThread = function(fn)
    if loading then return end
    local thread = { co = coroutine.create(fn) }
    threads[#threads + 1] = thread
    resume(thread)
end
_G.Wait = function(ms)
    if not coroutine.isyieldable() then return end
    coroutine.yield({ untilMs = T + (tonumber(ms) or 0) })
end
_G.SetTimeout = function(ms, fn)
    if loading then return end
    timers[#timers + 1] = { at = T + (tonumber(ms) or 0), fn = fn }
end
local function pump()
    for _ = 1, 100 do
        local progressed = false
        for _, thread in ipairs(threads) do
            if coroutine.status(thread.co) == "suspended" then
                local c = thread.condition
                if c == nil or (c.untilMs ~= nil and T >= c.untilMs) or (c.promise ~= nil and c.promise.done) then
                    resume(thread)
                    progressed = true
                end
            end
        end
        if not progressed then return end
    end
end
local function runTimers()
    while true do
        local due, index = nil, nil
        for i, timer in ipairs(timers) do
            if T >= timer.at and (due == nil or timer.at < due.at) then due, index = timer, i end
        end
        if due == nil then return end
        table.remove(timers, index)
        due.fn()
    end
end

-- ------------------------------------------------------------------- life --
local life = {}       -- playerId -> { phase, revision }
local wipeOnRespawn = {}
local promises = {}   -- teleport promises, in order
local respawns = {}
for id = 3, 40 do life[id] = { phase = "alive", revision = 1 } end
Open77.players.getLifeState = function(id)
    local state = life[tonumber(id)]
    if state == nil then return nil end
    return { phase = state.phase, revision = state.revision }
end
Open77.players.isDead = function(id)
    local state = life[tonumber(id)]
    return state ~= nil and (state.phase == "dead" or state.phase == "respawnpending")
end
Open77.players.kill = function(id) life[id].phase = "dead"; life[id].revision = life[id].revision + 1; return true end

-- ---------------------------------------------------------------- weapons --
-- The fake client: what each player holds, by slot, and what is in hand. Removal
-- and holster apply at once; an assign applies when the test completes it.
local W, nextRequest = {}, 0
local inv, hand = {}, {}
local function slotsOf(id) inv[id] = inv[id] or {}; return inv[id] end
local function idFor(record)
    local h = 7
    for i = 1, #record do h = (h * 131 + record:byte(i)) % 0x7FFFFFF end
    return ("0x%016X"):format(h + 0x100000)
end

local currentInstance -- set below; the round state each call was made in
local function roundStateOf(id)
    local instance = Deathmatch.instances.of(id)
    return instance and instance.round and instance.round.state or "none"
end
local function record(op, id, fields)
    nextRequest = nextRequest + 1
    local call = { op = op, playerId = id, id = "op77_arena:weapon:" .. nextRequest, atMs = T, state = roundStateOf(id) }
    for k, v in pairs(fields or {}) do call[k] = v end
    W[#W + 1] = call
    return call.id
end
Open77.weapons.holster = function(id)
    hand[id] = hand[id] and { active = hand[id].active, drawn = false } or nil
    return record("holster", id)
end
Open77.weapons.remove = function(id, slot) slotsOf(id)[slot] = nil; return record("remove", id, { slot = slot }) end
Open77.weapons.assign = function(id, rec, slot, options)
    return record("assign", id, { record = rec, slot = slot, options = options })
end
Open77.weapons.setAmmo = function(id, slot, options) return record("setAmmo", id, { slot = slot, options = options }) end
Open77.weapons.setActive = function(id, slot)
    hand[id] = { active = slot, drawn = true }
    return record("setActive", id, { slot = slot })
end
Open77.weapons.requestSnapshot = function(id) return record("snapshot", id) end

Open77.players.respawn = function(id)
    life[id].phase = "respawnpending"
    life[id].revision = life[id].revision + 1
    respawns[#respawns + 1] = id
    if wipeOnRespawn[id] then inv[id] = {}; hand[id] = nil
    elseif hand[id] then hand[id] = { active = hand[id].active, drawn = false } end -- holstered
    return true
end
Open77.players.teleport = function(id)
    local promise = { playerId = id, done = false }
    function promise:await()
        while not self.done do coroutine.yield({ promise = self }) end
        return self.ok, self.why
    end
    promises[#promises + 1] = promise
    return promise
end

local damageFn
Open77.combat.onDamage = function(fn) damageFn = fn end

_G.json = { encode = function() return "{}" end, decode = function() return {} end }
_G.RegisterCommand = function() end
_G.AddEventHandler = function(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
_G.RegisterNetEvent = function(name, fn) net[name] = fn end
_G.TriggerEvent = function() end
_G.TriggerClientEvent = function() end
_G.GetCurrentResourceName = function() return "op77_arena" end
_G.GetResourceState = function() return "running" end
_G.GetPlayers = function() local out = {} for id in pairs(online) do out[#out + 1] = tostring(id) end return out end
_G.GetPlayerName = function() return nil end
_G.GetPlayerIdentifiers = function() return {} end
_G.SetPlayerRoutingBucket = function() return true end
_G.GetPlayerRoutingBucket = function() return 0 end
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

local DM, H, L = Deathmatch, ArenaHost, LightRpArena
local Config = DeathmatchConfig
local ACT = L.activities
DM.nowMs = function() return T end
DM.tune = DM.tune or {}
assert(type(damageFn) == "function", "main.lua registered the damage arbiter")
local norm = DM.loadout.normalizeWeaponId
local SETTLE = Config.arena.kitSettleMs
assert(SETTLE == 1000, "kitSettleMs default")

-- ------------------------------------------------------------------ driving --
local function fire(name, ...) for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
local function advance(ms)
    local target = T + ms
    while T < target do
        T = math.min(target, T + 250)
        runTimers(); pump()
        DM.loadout.sweep(T)
        DM.arena.tick(T)
        runTimers(); pump()
    end
end
local function advanceUntil(predicate, limitMs, what)
    local limit = T + (limitMs or 60000)
    while not predicate() do
        assert(T < limit, "timed out waiting for " .. tostring(what))
        advance(250)
    end
end
-- Lands a player's pending move: the teleport promise settles, or the respawn is
-- acknowledged (respawnpending -> recovering).
local function land(id)
    if life[id].phase == "respawnpending" then
        life[id].phase = "recovering"
        life[id].revision = life[id].revision + 1
    end
    for _, promise in ipairs(promises) do
        if promise.playerId == id and not promise.done then promise.done, promise.ok = true, true end
    end
    pump()
end
local function inFlight(id)
    for _, promise in ipairs(promises) do
        if promise.playerId == id and not promise.done then return true end
    end
    return false
end
local function complete(call, accepted, reason)
    if call.completed then return end
    call.completed = true
    if accepted == nil then accepted = true end
    local id = call.playerId
    local result
    if call.op == "assign" and accepted then
        slotsOf(id)[call.slot] = idFor(call.record)
        if call.options and call.options.active then hand[id] = { active = call.slot, drawn = true } end
        result = { slot = call.slot, record = call.record, tweakDbId = idFor(call.record) }
    elseif call.op == "snapshot" and accepted then
        result = {}
        for slot = 1, 3 do
            local held = slotsOf(id)[slot]
            local inHand = hand[id] ~= nil and hand[id].active == slot
            result[#result + 1] = { slot = slot, equipped = held ~= nil, record = "", tweakDbId = held or "",
                active = inHand, drawn = inHand and hand[id].drawn == true }
        end
    elseif call.op == "setAmmo" then
        result = { slot = call.slot }
    end
    fire("open77:weapons:completed", tostring(id), call.id, call.op, accepted, reason or "", result)
end
local TRACKED = { assign = true, setAmmo = true, snapshot = true }
-- Completes every outstanding tracked request (and the follow-ups it causes).
local function settle(filter)
    local progressed = true
    while progressed do
        progressed = false
        for _, call in ipairs(W) do
            if not call.completed and TRACKED[call.op] and (filter == nil or filter(call)) then
                complete(call, true)
                progressed = true
            end
        end
    end
end
local function callsOf(id, from, op)
    local out = {}
    for index = from or 1, #W do
        local call = W[index]
        if call.playerId == id and (op == nil or call.op == op) then out[#out + 1] = call end
    end
    return out
end
local function count(id, from, op) return #callsOf(id, from, op) end
local STRIP_OPS = { holster = true, remove = true, assign = true, clear = true }
local function strips(id, from)
    local n = 0
    for _, call in ipairs(callsOf(id, from)) do if STRIP_OPS[call.op] then n = n + 1 end end
    return n
end
local function mark() return #W + 1 end
local function weaponId(id) local instance = DM.instances.of(id); return instance and instance.weaponIds[id] end
local function logged(pattern, from)
    for index = from or 1, #logs do if logs[index]:find(pattern) then return true end end
    return false
end
local function matchJoin(ids, activity, spec, extra)
    for _, id in ipairs(ids) do
        local options = { ranked = false, match = {} }
        for k, v in pairs(spec) do options.match[k] = v end
        for _, side in ipairs({ 1, 2 }) do
            for _, member in ipairs(spec.teams and spec.teams[side] or {}) do
                if member == id then options.match.side = side end
            end
        end
        for k, v in pairs(extra or {}) do options[k] = v end
        fire("op77_lightrp:activity:join", id, activity, options)
    end
end
local function damage(victim, attacker, weapon)
    return damageFn({ victim = victim, attacker = attacker, weaponTdbId = weapon, attackKind = "ranged" })
end
local AJAX, SARATOGA, GRAD = "Items.Preset_Ajax_Default", "Items.Preset_Saratoga_Default", "Items.Preset_Grad_Default"
local UNITY, KATANA = "Items.Preset_Unity_Default", "Items.Preset_Katana_Default"

-- ── 1. round 1: nothing at placement; the kit lands after the placement, in the window ──
local duel
do
    T = T + 1000
    matchJoin({ 3, 4 }, ACT.duel.id, { id = "match:k1", friendly = true, ranked = false, players = { 3, 4 },
        teams = { { 3 }, { 4 } } })
    duel = DM.instances.of(3)
    assert(duel and duel == DM.instances.of(4) and duel.format == "1v1", "one duel instance")
    assert(duel.round and duel.round.state == "buy" and duel.round.number == 1, "round 1 opens on its buy window")
    assert(inFlight(3) and inFlight(4), "the living are moved by teleport")
    assert(strips(3) == 0 and strips(4) == 0, "nothing issued at placement")

    advance(3000)
    assert(duel.round.state == "buy")
    assert(count(3) == 0 and count(4) == 0, "nothing issued while the teleport is in flight")
    assert(DM.bodySettled(3) == false, "in flight is not landed")

    land(3); land(4)
    local landedAt = T
    assert(DM.bodySettled(3) == true, "landed")
    advance(SETTLE - 250)
    assert(count(3) == 0 and count(4) == 0, "not before the settle margin")
    advance(500)
    assert(count(3, nil, "holster") == 1 and count(3, nil, "remove") == 3, "armed after the margin")
    advanceUntil(function() return count(3, nil, "assign") == 3 and count(4, nil, "assign") == 3 end, 2000, "assigns")
    for _, id in ipairs({ 3, 4 }) do
        local lastRemove, firstAssign = 0, math.huge
        for _, call in ipairs(callsOf(id)) do
            assert(call.state == "buy", "every weapon call of round 1 is inside the buy window")
            assert(call.atMs >= landedAt + SETTLE, "never before the placement landed + margin")
            if call.op == "remove" then lastRemove = math.max(lastRemove, call.atMs) end
            if call.op == "assign" then firstAssign = math.min(firstAssign, call.atMs) end
        end
        assert(firstAssign - lastRemove >= 250, "the 250 ms gap is kept")
    end
    local slot1 = callsOf(3, nil, "assign")[3]
    assert(slot1.slot == 1 and slot1.record == AJAX and slot1.options.active == true, "slot 1 last, active, default kit")
    assert(logged("player 3 armed in the buy window %(issued"), "the arming is logged")
    -- Player 4's kit verifies; player 3's assigns are left in flight on purpose.
    settle(function(call) return call.playerId == 4 end)
    assert(weaponId(4) == norm(idFor(AJAX)), "player 4 verified in the window")
    assert(weaponId(3) == nil, "player 3 not yet")
    say("PASS kit issued after the BUY placement lands (teleport settled + margin, 250 ms gap, all inside the window)")
end

-- ── 2. a kit change in the window re-issues at once; the superseded completion is dropped ──
do
    local old = callsOf(3, nil, "assign")
    local before = mark()
    assert(DM.arena.pickKit(3, "smg") == true, "/arena.kit smg in the window")
    assert(count(3, before, "holster") == 1 and count(3, before, "remove") == 3, "stripped at once, same tick")
    assert(count(3, before, "assign") == 0, "assigns wait for the gap")
    advance(250)
    local fresh = callsOf(3, before, "assign")
    assert(#fresh == 3 and fresh[3].record == SARATOGA and fresh[3].slot == 1, "the SMG kit, slot 1 last")
    assert(duel.round.state == "buy")

    -- The rifle's slot-1 verdict arrives late: a previous version, dropped.
    for _, call in ipairs(old) do complete(call, true) end
    assert(weaponId(3) == nil, "a late completion from the previous version is dropped")
    settle(function(call) return call.playerId == 3 end)
    assert(weaponId(3) == norm(idFor(SARATOGA)), "the new kit verifies")

    -- Re-picking the kit a player already holds re-issues nothing (the net route).
    local again = mark()
    _G.source = 4
    net["deathmatch:pickKit"]("rifle")
    _G.source = nil
    assert(strips(4, again) == 0 and count(4, again, "snapshot") == 0, "same kit: nothing")
    say("PASS buy-window kit change re-issues at once; late completion dropped; same kit untouched")
end

-- ── 3. nothing can be hurt during the buy window ──
do
    assert(duel.round.state == "buy")
    assert(damage(4, 3, idFor(SARATOGA)) == false, "M5: no damage in the buy window")
    assert(damage(3, 4, idFor(AJAX)) == false, "both ways")
    -- The player -> bot report path refuses the same way (bots.lua gate 1b).
    local count0, enabled0 = DeathmatchBots.count, Config.bots.enabled
    DeathmatchBots.count = function() return 1 end
    Config.bots.enabled = true
    local from = #logs + 1
    _G.source = 3
    net["deathmatch:npcHit"]({ npcId = "0x1", weapon = idFor(SARATOGA), seq = 1 })
    assert(logged("reason=round_not_live", from), "player -> bot refused in the buy window")
    DeathmatchBots.count, Config.bots.enabled = count0, enabled0
    _G.source = nil
    say("PASS no damage accepted during the buy window (players and bots)")
end

-- ── 4. GO with a verified matching kit: reserve ammunition, nothing else ──
do
    local before = mark()
    advanceUntil(function() return duel.round.state == "active" end, 30000, "GO")
    for _, id in ipairs({ 3, 4 }) do
        assert(strips(id, before) == 0, "GO re-assigns nothing for player " .. id)
        assert(count(id, before, "snapshot") == 0)
        local ammo = callsOf(id, before, "setAmmo")
        assert(#ammo == 2, "reserve for the two firearms")
        for _, call in ipairs(ammo) do
            assert(call.options.reserve > 0 and call.options.magazine == nil and call.options.activate == false,
                "RESERVE ONLY, never a magazine, never yanks the hand")
        end
    end
    assert(logged("GO loadouts: .*3=topped_up") and logged("GO loadouts: .*4=topped_up"))
    assert(weaponId(3) == norm(idFor(SARATOGA)) and weaponId(4) == norm(idFor(AJAX)), "verification survives GO")
    advance(2000) -- past the round-start shield
    assert(damage(4, 3, idFor(SARATOGA)) == true, "a live round accepts the verified weapon")
    local from = #logs + 1
    local count0 = DeathmatchBots.count
    DeathmatchBots.count = function() return 1 end
    _G.source = 3
    net["deathmatch:npcHit"]({ npcId = "0x1", weapon = idFor(SARATOGA), seq = 2 })
    _G.source = nil
    DeathmatchBots.count = count0
    assert(not logged("reason=round_not_live", from), "the bot gate opens with the round")
    settle()
    say("PASS GO with a verified matching kit sends reserve-only ammunition and re-assigns nothing")
end

-- ── 5. round 2: unchanged kits survive the placement (teleport and respawn) ──
do
    life[4].phase = "dead"
    DM.onDeath(4, 3, "player")
    assert(duel.round.state == "between", "player 4 eliminated, round over")
    local before = mark()
    advanceUntil(function() return duel.round.number == 2 end, 30000, "round 2")
    assert(duel.round.state == "buy")
    assert(life[4].phase == "respawnpending" and inFlight(3), "the dead respawn, the living teleport")
    advance(3000)
    assert(count(3, before) == 0 and count(4, before) == 0, "nothing before landing")

    land(3)
    advance(SETTLE + 250)
    assert(count(3, before, "snapshot") == 1 and strips(3, before) == 0, "unchanged kit: asked, not re-issued")
    assert(count(4, before) == 0, "the respawn is still pending: nothing for player 4")
    land(4)
    assert(DM.bodySettled(4) == true, "recovering counts as landed")
    advance(SETTLE + 250)
    assert(count(4, before, "snapshot") == 1 and strips(4, before) == 0)
    settle()
    assert(strips(3, before) == 0 and strips(4, before) == 0, "both kept: no strip, no assign")
    assert(count(3, before, "setActive") == 0, "player 3 still had it drawn")
    assert(count(4, before, "setActive") == 1, "the respawn holstered player 4: drawn back in the window")
    assert(logged("loadout kept player=3 .*verified kit$") and logged("loadout kept player=4 .*primary drawn back"),
        "the verdict is in the server log")
    assert(weaponId(3) == norm(idFor(SARATOGA)) and weaponId(4) == norm(idFor(AJAX)), "verification kept")

    local go = mark()
    advanceUntil(function() return duel.round.state == "active" end, 30000, "GO 2")
    assert(strips(3, go) == 0 and strips(4, go) == 0 and count(3, go, "setAmmo") == 2 and count(4, go, "setAmmo") == 2)
    settle()
    say("PASS round 2: unchanged kits kept across teleport and respawn (snapshot, no strip/reassign; holstered primary drawn)")
end

-- ── 6. round 3: a placement that wiped the weapons is re-issued in the window ──
do
    advance(2000)
    life[3].phase = "dead"
    wipeOnRespawn[3] = true
    DM.onDeath(3, 4, "player")
    assert(duel.round.state == "between")
    local before = mark()
    advanceUntil(function() return duel.round.number == 3 end, 30000, "round 3")
    land(3); land(4)
    advance(SETTLE + 250)
    settle(function(call) return call.op == "snapshot" end)
    assert(count(3, before, "holster") == 1 and count(3, before, "remove") == 3, "wiped: re-issued")
    assert(weaponId(3) == nil, "and unverified until the verdict")
    assert(strips(4, before) == 0, "player 4 kept")
    assert(logged("placement did not keep player=3"))
    advance(250)
    assert(count(3, before, "assign") == 3)
    for _, call in ipairs(callsOf(3, before)) do assert(call.state == "buy", "the re-issue is inside the window") end
    settle()
    assert(weaponId(3) == norm(idFor(SARATOGA)))
    local go = mark()
    advanceUntil(function() return duel.round.state == "active" end, 30000, "GO 3")
    assert(strips(3, go) == 0 and strips(4, go) == 0, "GO 3 re-assigns nothing")
    say("PASS round 3: wiped weapons re-issued inside the window, GO tops up only")
end

-- ── 7. GO with nothing verified: the full issue, as GO always did ──
do
    T = T + 1000
    matchJoin({ 5, 6 }, ACT.duel.id, { id = "match:k2", friendly = true, ranked = false, players = { 5, 6 },
        teams = { { 5 }, { 6 } } })
    local other = DM.instances.of(5)
    assert(other and other ~= duel and other.round.state == "buy")
    -- A pick made before the body landed is recorded, not issued.
    assert(DM.arena.pickKit(5, "sniper") == true)
    assert(count(5) == 0, "pick before landing: recorded only")
    local before = mark()
    -- The teleports never settle inside the window.
    advanceUntil(function() return other.round.state == "active" end, 30000, "GO without landing")
    for _, id in ipairs({ 5, 6 }) do
        assert(count(id, before, "holster") == 1 and count(id, before, "remove") == 3, "full issue at GO")
        for _, call in ipairs(callsOf(id, before)) do assert(call.state == "active") end
    end
    assert(logged("GO loadouts: .*5=issued"))
    advance(250)
    assert(callsOf(5, before, "assign")[3].record == GRAD, "the recorded pick is the one issued")
    -- The late landing does not arm again: the window is closed.
    local late = mark()
    land(5); land(6)
    advance(SETTLE + 500)
    assert(count(5, late, "snapshot") == 0 and strips(5, late) == 0, "no arming after GO")
    settle()
    assert(weaponId(5) == norm(idFor(GRAD)))
    say("PASS GO with nothing verified falls back to the full issue (and a late landing does not re-arm)")
end

-- ── 8. Team Arena 2v2: everyone armed in the window; an issue in flight at GO is left alone ──
do
    T = T + 1000
    matchJoin({ 7, 8, 9, 10 }, ACT.teams.id, { id = "match:t1", friendly = true, ranked = false, format = "2v2",
        players = { 7, 8, 9, 10 }, teams = { { 7, 8 }, { 9, 10 } } }, { mode = "2v2" })
    local teams = DM.instances.of(7)
    assert(teams and teams.format == "2v2" and teams.round.state == "buy")
    for _, id in ipairs({ 7, 8, 9, 10 }) do land(id) end
    advance(SETTLE + 500)
    for _, id in ipairs({ 7, 8, 9, 10 }) do
        assert(count(id, nil, "assign") == 3, "player " .. id .. " armed in the window")
    end
    -- Player 8's verdicts are lost for good; everybody else verifies.
    settle(function(call) return call.playerId ~= 8 end)
    -- Player 7 changes kit one second before GO: the new issue is still in flight at GO.
    advanceUntil(function() return T >= teams.round.buyEndsAtMs - 1000 end, 30000, "a second before GO")
    assert(DM.arena.pickKit(7, "shotgun") == true)
    advance(250)
    assert(callsOf(7, nil, "assign")[6].record == "Items.Preset_Carnage_Default", "the shotgun kit is out")
    local before = mark()
    advanceUntil(function() return teams.round.state == "active" end, 30000, "teams GO")
    assert(strips(7, before) == 0 and count(7, before, "setAmmo") == 0, "an issue still in flight is left alone")
    assert(logged("GO loadouts: .*7=in_flight"))
    -- Verdicts lost past the pending bound read as finished: GO re-issues, as it always did.
    assert(count(8, before, "holster") == 1 and count(8, before, "remove") == 3, "lost verdicts: full issue at GO")
    assert(logged("GO loadouts: .*8=issued"))
    for _, id in ipairs({ 9, 10 }) do
        assert(strips(id, before) == 0 and count(id, before, "setAmmo") == 2, "player " .. id .. " topped up")
    end
    advance(250) -- the GO re-issue's assigns follow the 250 ms gap
    settle()
    assert(weaponId(7) == norm(idFor("Items.Preset_Carnage_Default")), "the in-flight issue verifies on its own")
    assert(count(7, before, "setAmmo") == 2, "and brings its own ammunition")
    assert(weaponId(8) == norm(idFor(AJAX)))
    say("PASS Team Arena 2v2: armed in the window; GO leaves an in-flight issue alone, re-issues lost verdicts, tops up the rest")
end

say("PASS: op77_arena arena kits (after the placement, kit change, late completion, no buy damage, GO top-up, GO fallback, survival keep/wipe, Team Arena)")
