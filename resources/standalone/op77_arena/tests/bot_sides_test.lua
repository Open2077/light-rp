-- Bots never aim at their own side. The real server/bots.lua, an explicit host
-- standing in for the arena (match.sides through `arenaSide`), and the bot tick
-- driven one iteration at a time. Covers what the ENGINE is told (one combat
-- group per side, a friendly row towards each same-side human, applied after the
-- loadout), the scripted target choice and the seek walk skipping team-mates, a
-- rebuilt body after death, the halftime swap (clusters trade ends, sides stay),
-- a real side change, a human leaving, the match ending, the free-for-all left
-- untouched, the op77_arena `add` options (health, damage, tag, team; kept by
-- paced spawns and respawns), and a platform build without the natives.
-- Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test bot_sides_test.lua
local say = print
local printed = {}
_G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    printed[#printed + 1] = table.concat(parts, " ")
end

local T = 1000000 -- milliseconds
local function stub(path)
    return setmetatable({}, {
        __index = function(t, k) local child = stub(path .. "." .. tostring(k)); rawset(t, k, child); return child end,
        __call = function() return nil end,
    })
end
_G.Open77 = stub("Open77")
Open77.time.monotonic = function() return T / 1000 end
Open77.time.nowMs = function() return T end
Open77.time.unix = function() return 1700000000 end

-- ── the world: NPC bodies and what each was told ──
local INSTANCE, FFA, BUCKET = 3, 7, 4100100
local world, nextNpc = {}, 4294967312
Open77.npcs.create = function(def)
    local id = nextNpc
    nextNpc = nextNpc + 1
    world[id] = {
        x = def.position.x, y = def.position.y, z = 100.0, yaw = 0.0, bucket = def.bucket,
        health = def.health or 100, maxHealth = def.maxHealth or 100,
        group = nil, rows = {}, loadouts = 0, groupCalls = 0, attitudeCalls = 0,
    }
    return id
end
Open77.npcs.get = function(id)
    local n = world[id]
    if n == nil then return nil end
    return { x = n.x, y = n.y, z = n.z, yaw = n.yaw, bucket = n.bucket, health = n.health, maxHealth = n.maxHealth }
end
Open77.npcs.remove = function(id) world[id] = nil; return true end
-- Wholesale: a loadout is the whole record, so the group goes with it (api.json).
Open77.npcs.setLoadout = function(id)
    local n = world[id]
    if n == nil then return false, "npc_not_found" end
    n.loadouts = n.loadouts + 1
    n.group = nil
    return true
end
Open77.npcs.setGroup = function(id, group)
    local n = world[id]
    if n == nil then return false, "npc_not_found" end
    if group ~= nil then
        assert(type(group) == "string" and #group <= 64 and not group:find("[^%w_%.%-]"), "group name: " .. tostring(group))
    end
    n.groupCalls = n.groupCalls + 1
    n.group = group
    return true
end
Open77.npcs.setAttitude = function(id, attitude, options)
    local n = world[id]
    if n == nil then return false, "npc_not_found" end
    assert(attitude == nil or attitude == "friendly" or attitude == "neutral" or attitude == "hostile")
    assert(type(options) == "table" and type(options.towards) == "number", "a row towards one player")
    n.attitudeCalls = n.attitudeCalls + 1
    n.rows[options.towards] = attitude
    return true
end
Open77.npcs.setHealth = function(id, health) local n = world[id]; if n then n.health = health end; return true end
Open77.npcs.setTransform = function(id, t) local n = world[id]; if n and t.position then n.x, n.y = t.position.x, t.position.y end; return true end
Open77.npcs.revive = function() return true end
Open77.npcs.tasks.moveTo = function() return 1 end
Open77.npcs.tasks.clear = function() return true end
Open77.npcs.tasks.lookAt = function() return 1 end

local playerAt = { x = 0.0, y = 0.0 }
local playerBucket = {} -- player -> bucket (default: the arena's)
Open77.players.position = function(id) return { x = playerAt.x, y = playerAt.y, z = 100.0, bucket = playerBucket[id] or BUCKET } end
Open77.players.getLifeState = function() return { phase = "alive" } end
Open77.players.isDead = function() return false end
local shots = {}
Open77.players.damage = function(id, amount, info) shots[#shots + 1] = { victim = id, attacker = info and info.attacker, amount = amount }; return true end

local handlers, threads, net = {}, {}, {}
_G.AddEventHandler = function(name, fn) handlers[name] = fn end
_G.RegisterNetEvent = function(name, fn) net[name] = fn end
_G.RegisterCommand = function() end
_G.TriggerEvent = function() end
_G.TriggerClientEvent = function() end
_G.CreateThread = function(fn) threads[#threads + 1] = fn end
_G.SetTimeout = function() end
_G.Wait = function() coroutine.yield() end
_G.GetCurrentResourceName = function() return "op77_arena" end
_G.json = { encode = function() return "{}" end, decode = function() return {} end }

assert(pcall(dofile, "shared/config.lua"))
local bots = DeathmatchConfig.bots
bots.enabled = true
bots.weaponRecord = bots.weaponRecord or "Items.Preset_Lexington_Default"
bots.combat = bots.combat or {}
bots.combat.mode = "native"
bots.combat.forceWeapon = true
bots.combat.seek = bots.combat.seek or {}
bots.combat.seek.enabled, bots.combat.seek.preferBots, bots.combat.seek.seekPlayers = true, true, true
bots.combat.seek.patrol = true
local ok, err = pcall(dofile, "server/bots.lua")
assert(ok, tostring(err))
local B = DeathmatchBots

-- ── the arena, as bots.lua sees it ──
local sides = {}     -- Arena.match.sides: participant -> side
local playerInstance = {} -- player -> instance (the net handlers' host call); empty unless a test sets it
local humans = { 1 }
local marksA = { { x = 2.0, y = 0.0, z = 100.0 }, { x = 4.0, y = 0.0, z = 100.0 } }
local marksB = { { x = 10.0, y = 0.0, z = 100.0 }, { x = 12.0, y = 0.0, z = 100.0 }, { x = 14.0, y = 0.0, z = 100.0 } }
local views = {
    [INSTANCE] = { id = INSTANCE, bucket = BUCKET, capacity = 6, spawns = marksA, marks = marksB },
    [FFA] = { id = FFA, bucket = BUCKET + 1, capacity = 12, spawns = marksB, marks = marksB },
}
B.setHost({
    instance = function(id) return views[tonumber(id)] end,
    instances = function() return { views[INSTANCE], views[FFA] } end,
    playersIn = function(id) return tonumber(id) == INSTANCE and humans or {} end,
    capacity = function(id) local v = views[tonumber(id)]; return v and v.capacity end,
    arenaSide = function(id) return sides[tonumber(id)] end,
    instanceOfPlayer = function(id) return playerInstance[tonumber(id)] end,
    addParticipant = function() return true end,
    removeParticipant = function() return true end,
    rebindNpc = function() return true end,
    isPlayerAlive = function() return true end,
    protectionRemaining = function() return 0 end,
})
assert(#threads == 1, "one bot tick thread")
local tick = coroutine.wrap(threads[1])
local function step(ms) T = T + (ms or 500); tick() end

local function npc(id) return world[B.npcIdOf(id)] end
local function team(side)
    local out = {}
    for id, s in pairs(sides) do if id < 0 and s == side then out[#out + 1] = id end end
    table.sort(out, function(a, b) return a > b end)
    return out
end
local function place(id, x) local n = npc(id); n.x, n.y = x, 0.0 end

T = T + 6000 -- past the spawn settle window

-- ── a 3v3 with one human: two bots join him on side 1, three play side 2 ──
local team1, team2
do
    sides[1] = 1
    local function adopt(id, side) sides[id] = side end -- Arena.adoptBot
    B.addToArena(INSTANCE, 1, 2, marksA, nil, adopt)
    B.addToArena(INSTANCE, 2, 3, marksB, nil, adopt)
    for _ = 1, 10 do step(500) end
    team1, team2 = team(1), team(2)
    assert(#team1 == 2 and #team2 == 3, "five bots on the roster")
    for _, id in ipairs(team1) do
        local n = npc(id)
        assert(n.loadouts >= 1, "the loadout ran")
        assert(n.group == "op77_arena.i3.s1", "side 1 group, standing after the wholesale loadout: " .. tostring(n.group))
        assert(n.rows[1] == "friendly", "friendly to its own human")
    end
    for _, id in ipairs(team2) do
        local n = npc(id)
        assert(n.group == "op77_arena.i3.s2", "side 2 group")
        assert(n.rows[1] == nil, "no row: the human of the other side stays the enemy")
    end
    say("PASS each side told to the engine (group per side, friendly row to its human)")
end

-- ── nothing changed: no native called again ──
do
    local before = {}
    for _, id in ipairs(team1) do before[id] = npc(id).groupCalls + npc(id).attitudeCalls end
    for _ = 1, 6 do step(500) end
    for _, id in ipairs(team1) do
        assert(npc(id).groupCalls + npc(id).attitudeCalls == before[id], "steady state is free")
    end
    say("PASS steady state calls nothing")
end

-- Scripted targeting, one tick: the target is chosen, nothing fires yet (reaction time).
local function retarget()
    for _, id in ipairs(team1) do local b = B.get(id); b.target, b.reacquireAtMs = nil, 0 end
    for _, id in ipairs(team2) do local b = B.get(id); b.target, b.reacquireAtMs = nil, 0 end
    bots.combat.mode = "scripted"
    step(100)
    bots.combat.mode = "native"
end
local function assertTargets(label)
    for _, id in ipairs(team1) do
        local target = B.get(id).target
        assert(target ~= nil, label .. ": side 1 bot has a target")
        assert(target.kind == "bot" and sides[target.id] == 2,
            label .. ": side 1 bot aims at side 2, not at its human (" .. tostring(target.kind) .. " " .. tostring(target.id) .. ")")
    end
    for _, id in ipairs(team2) do
        local target = B.get(id).target
        assert(target ~= nil, label .. ": side 2 bot has a target")
        assert((target.kind == "player" and target.id == 1) or (target.kind == "bot" and sides[target.id] == 1),
            label .. ": side 2 bot aims at side 1 (" .. tostring(target.kind) .. " " .. tostring(target.id) .. ")")
    end
end

-- ── scripted target choice: the nearest body is a team-mate every time ──
do
    playerAt.x = 0.0
    place(team1[1], 2.0); place(team1[2], 4.0)
    place(team2[1], 10.0); place(team2[2], 12.0); place(team2[3], 14.0)
    retarget()
    assertTargets("round 1")
    say("PASS scripted targets skip team-mates (human and bot)")
end

-- ── seek: with the other side down, a bot never walks to its own human ──
do
    for _, id in ipairs(team2) do handlers.onNpcDied(B.npcIdOf(id), "player:1", "firearm") end
    for _, id in ipairs(team1) do local b = B.get(id); b.seekIssuedAtMs, b.lastCombatAtMs, b.seekTargetId = 0, 0, nil end
    step(7000)
    for _, id in ipairs(team1) do
        local b = B.get(id)
        assert(b.seekTargetId == nil, "side 1 bot seeks nobody (its human is a team-mate): " .. tostring(b.seekTargetId))
    end
    say("PASS seek skips the bot's own human")
end

-- ── round 2, sides swapped ends: dead bots come back in NEW bodies, same side ──
do
    local old = {}
    for _, id in ipairs(team2) do old[id] = B.get(id).lastNpcKey or tostring(B.npcIdOf(id)) end
    step(1500) -- corpses released
    for _, id in ipairs(team2) do assert(B.npcIdOf(id) == nil, "corpse handed back") end
    B.arenaRoundStart(INSTANCE, { [1] = marksB, [2] = marksA }) -- halftime: clusters trade ends
    for _ = 1, 10 do step(500) end
    for _, id in ipairs(team2) do
        local fresh = B.npcIdOf(id)
        assert(fresh ~= nil and tostring(fresh) ~= old[id], "a rebuilt body")
        assert(npc(id).group == "op77_arena.i3.s2", "the new body is told its side")
        assert(npc(id).rows[1] == nil)
    end
    for _, id in ipairs(team1) do
        assert(npc(id).group == "op77_arena.i3.s1" and npc(id).rows[1] == "friendly", "the swap changes ends, not sides")
    end
    -- Mirrored positions: the human and his bots on the far end now.
    playerAt.x = 20.0
    place(team1[1], 18.0); place(team1[2], 16.0)
    place(team2[1], 8.0); place(team2[2], 6.0); place(team2[3], 4.0)
    retarget()
    assertTargets("after the swap")
    say("PASS respawned bodies and the halftime swap keep the sides")
end

-- ── a real side change, then the human leaves, then the match ends ──
do
    sides[1] = 2 -- the next match puts the human on side 2
    step(1100)
    for _, id in ipairs(team1) do assert(npc(id).rows[1] == nil, "side 1 bot: row towards a human who changed sides cleared") end
    for _, id in ipairs(team2) do assert(npc(id).rows[1] == "friendly", "side 2 bot: friendly to its new team-mate") end
    -- Seek, side 2 alone with its human: never towards him. The round is live,
    -- so the side 1 bots stay down (elimination) instead of respawning.
    B.arenaRoundLive(INSTANCE)
    for _, id in ipairs(team1) do handlers.onNpcDied(B.npcIdOf(id), "player:1", "firearm") end
    for _, id in ipairs(team2) do local b = B.get(id); b.seekIssuedAtMs, b.lastCombatAtMs, b.seekTargetId = 0, 0, nil end
    step(7000)
    for _, id in ipairs(team2) do
        local b = B.get(id)
        assert(b.seekTargetId == nil, "side 2 bot does not seek its new team-mate: " .. tostring(b.seekTargetId))
    end

    humans = {}
    step(1100)
    for _, id in ipairs(team2) do assert(npc(id).rows[1] == nil, "a human who left keeps no row") end

    for _, id in ipairs(team2) do sides[id] = nil end
    step(1100)
    for _, id in ipairs(team2) do assert(npc(id).group == nil, "no side, no group") end
    say("PASS side change, departure and match end clear what is stale")
end

-- ── free-for-all: a bot without a side states nothing ──
do
    local added = B.add(FFA, 1)
    if added == 0 then for _ = 1, 4 do step(500) end end
    for _ = 1, 4 do step(500) end
    local found = 0
    for _, row in ipairs(B.snapshot(FFA)) do
        local n = npc(row.id)
        assert(n ~= nil and n.groupCalls == 0 and n.attitudeCalls == 0 and n.group == nil, "untouched")
        found = found + 1
    end
    assert(found >= 1, "a free-for-all bot exists")
    say("PASS free-for-all untouched")
end

-- ── op77_arena add options: health, damage, tag, team; paced spawns and respawns keep them ──
do
    local plain = nil
    for _, row in ipairs(B.snapshot(FFA)) do plain = plain or row.id end
    local base = B.get(plain).maxHealth
    assert(base and base > 0 and B.get(plain).damageScale == 1.0 and B.get(plain).tag == nil, "a plain bot is unscaled")
    local added, _, queued = B.add(FFA, 2, "veteran", { healthScale = 2.25, damageScale = 1.6, tag = "ally", team = 1 })
    added, queued = tonumber(added) or 0, tonumber(queued) or 0
    assert(added + queued == 2, "two asked for")
    assert(B.pendingCount(FFA, "ally") == queued and B.pendingCount(FFA, false) == 0, "parked spawns keep their tag")
    for _ = 1, 8 do step(500) end
    assert(B.pendingCount(FFA) == 0)
    local scaled = {}
    for _, row in ipairs(B.snapshot(FFA)) do
        local bot = B.get(row.id)
        if bot.tag == "ally" then
            scaled[#scaled + 1] = row.id
            assert(row.tag == "ally" and bot.team == 1 and bot.damageScale == 1.6)
            assert(math.abs(bot.maxHealth - base * 2.25) < 0.001 and bot.health == bot.maxHealth, "health scaled, full")
            assert(math.abs(npc(row.id).maxHealth - base * 2.25) < 0.001 and npc(row.id).health == npc(row.id).maxHealth,
                "the body is born with it")
        end
    end
    assert(#scaled == 2, "both arrived with their options (paced or not)")
    -- A respawn rebuilds the body with the same maximum.
    local id = scaled[1]
    local oldNpc = B.npcIdOf(id)
    handlers.onNpcDied(oldNpc, "player:1", "firearm")
    for _ = 1, 10 do step(500) end
    assert(B.npcIdOf(id) ~= nil and B.npcIdOf(id) ~= oldNpc and B.get(id).state == "alive", "reborn")
    assert(math.abs(npc(id).maxHealth - base * 2.25) < 0.001 and math.abs(B.get(id).health - base * 2.25) < 0.001,
        "reborn with its own maximum")
    -- Damage: the same engine hit, x1.6 from the scaled bot (after the per-hit clamp).
    local function hit(victim, botId)
        playerInstance[victim] = FFA
        playerBucket[victim] = BUCKET + 1
        local n = npc(botId)
        n.x, n.y = playerAt.x + 3.0, playerAt.y
        n.bucket = BUCKET + 1
        local before = #shots
        _G.source = victim
        net["deathmatch:npcHurtMe"]({ npcId = B.npcIdOf(botId), amount = 10.0 })
        _G.source = nil
        assert(#shots == before + 1, "the hit landed")
        return shots[#shots].amount
    end
    local plainHit, scaledHit = hit(21, plain), hit(22, scaled[2])
    assert(plainHit > 0 and math.abs(scaledHit - plainHit * 1.6) < 0.001,
        ("damage x1.6: %s vs %s"):format(tostring(scaledHit), tostring(plainHit)))
    playerInstance[21], playerInstance[22] = nil, nil
    say("PASS add options (health x2.25 on spawn, parked spawn and respawn; damage x1.6; tag, team)")
end

-- ── a platform build without the natives: said once, nothing raises ──
do
    rawset(Open77.npcs, "setGroup", nil)
    humans = { 1 }
    sides[1] = 1
    local function adopt(id, side) sides[id] = side end
    B.addToArena(INSTANCE, 1, 1, marksA, nil, adopt)
    for _ = 1, 6 do step(500) end
    local said = 0
    for _, line in ipairs(printed) do if line:find("setGroup is missing", 1, true) then said = said + 1 end end
    assert(said == 1, "said once: " .. said)
    say("PASS missing natives degrade to the ledger alone")
end

for _, line in ipairs(printed) do
    assert(not line:find("tick raised", 1, true), "a tick raised: " .. line)
end
say("PASS: op77_arena bot sides (engine groups and rows per side, scripted targets, seek, respawn, swap, side change, departure, FFA, add options, missing natives)")
