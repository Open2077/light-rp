-- The active implants (server/modules/cyberware_active.lua) and the iconic drops
-- (server/modules/cyberware_iconics.lua) on top of the cyberware module, against a fake
-- platform and framework: the client kit, Berserk (armor layer absorbed first, regeneration,
-- cooldown from the end, early ends), Pain Editor (threshold, once a minute), Second Heart
-- (medical downed only, delay, cooldown per character, Dogtown / ranked / non-PvE activity
-- refusals), Kiroshi scan (range, bucket, crew, Dogtown bounty, NPCs) and the Clairvoyant
-- crew mark (map blip, arrow updates, expiry, cleanup on death and disconnect), suspension in
-- PvP; iconic rolls (chance, pity counter, owned items, eligible participants, critical raid
-- only, test runs never drop).
local clock, threads = 0, {}
_G.CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
_G.Wait = function(ms) clock = clock + (ms or 0); coroutine.yield() end
-- runs every thread once per round, `rounds` rounds (the module's daemons never end)
local function step(rounds)
    for _ = 1, rounds or 1 do
        for i, co in ipairs(threads) do
            if co and coroutine.status(co) ~= "dead" then
                local ok, err = coroutine.resume(co)
                if not ok then error(err) end
            end
            if co and coroutine.status(co) == "dead" then threads[i] = false end
        end
    end
    local live = {}
    for _, co in ipairs(threads) do if co then live[#live + 1] = co end end
    threads = live
end

local handlers, netHandlers, commands, actions = {}, {}, {}, {}
_G.AddEventHandler = function(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
_G.RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
_G.RegisterCommand = function(name, fn) commands[name] = fn end
_G.GetCurrentResourceName = function() return "op77_lightrp" end
_G.json = { decode = function(s) return load("return " .. s)() end }
local function fire(name, ...) for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
local sent = {} -- { player, payload } of "op77_lightrp:cyberware"
_G.TriggerClientEvent = function(name, player, payload)
    if name == "op77_lightrp:cyberware" then sent[#sent + 1] = { player = player, payload = payload } end
    return true
end
local function lastSent(player, kind)
    for i = #sent, 1, -1 do if sent[i].player == player and sent[i].payload.kind == kind then return sent[i].payload end end
end
local blips = { added = {}, updated = 0, removed = {} }
_G.exports = { op77_map3d = {
    addBlip = function(_, target, def) blips.added[#blips.added + 1] = { target = target, def = def }; return "srv:op77_lightrp:" .. def.id end,
    updateBlip = function(_, id, patch) blips.updated = blips.updated + 1; blips.last = patch; return true end,
    removeBlip = function(_, id) blips.removed[#blips.removed + 1] = id; return true end,
} }

-- The platform ------------------------------------------------------------------
local P = { armor = {}, regen = {}, life = {}, pos = {}, bucket = {}, revived = {}, grants = { dash = {}, reflex = {}, abilities = {} } }
local function grantApi(kind)
    return {
        define = function() return { ok = true } end,
        grant = function(pid, id) P.grants[kind][pid] = id; return { ok = true } end,
        revoke = function(pid) P.grants[kind][pid] = nil; return { ok = true } end,
        current = function(pid) return P.grants[kind][pid] and { ownedByCaller = true } or nil end,
    }
end
local npcs = {}
_G.Open77 = {
    time = { monotonic = function() return clock / 1000 end },
    dash = grantApi("dash"), reflex = grantApi("reflex"), abilities = grantApi("abilities"),
    stats = {
        get = function(pid) return { health = { maximum = 100, regenPerSecond = 0, regenEnabled = false },
            stamina = { maximum = 100, regenPerSecond = 20 }, armor = P.armor[pid] or 0 } end,
        setMax = function() return true end,
        setRegenRate = function(pid, pool, v) if pool == "health" then P.regen[pid] = v end return true end,
        setRegenEnabled = function() return true end,
    },
    players = {
        getLifeState = function(pid) return { phase = P.life[pid] or "alive", position = P.pos[pid] } end,
        get = function(pid) local p = P.pos[pid]; return p and { position = p, bucket = P.bucket[pid] or 0, ageMs = 0 } or nil end,
        setArmor = function(pid, v) P.armor[pid] = v; return true end,
        setFallDamage = function() return true end,
        revive = function(pid, opts) P.revived[#P.revived + 1] = { pid = pid, opts = opts }; P.life[pid] = "alive"; return true end,
    },
    npcs = { get = function(id) return npcs[id] end },
}

-- The framework -------------------------------------------------------------------
local rows, stored, pity, notices, broadcasts, logs = {}, {}, {}, {}, {}, {}
local modules = {}
local function tableOf(sql) return sql:match("lightrp_cyberware_stock") and stored or rows end
_G.LightRP = {
    log = function(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end,
    notice = function(pid, def) notices[#notices + 1] = { player = pid, def = def } end,
    broadcastNotice = function(def) broadcasts[#broadcasts + 1] = def end,
    result = function() end,
    nowMs = function() return clock end,
    action = function(name, fn) actions[name] = fn end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if m[hook] then m[hook](...) end end end,
    db = {
        ready = true, schema = function() end,
        run = function(sql, p)
            if sql:match("lightrp_cyberware_pity") then pity[p[1] .. "#" .. p[2] .. "#" .. p[3]] = p[4] return true end
            local t = tableOf(sql)
            if sql:match("^INSERT") then t[p[1] .. "#" .. p[2] .. "#" .. p[3]] = true
            elseif sql:match("^DELETE") then t[p[1] .. "#" .. p[2] .. "#" .. p[3]] = nil end
            return true
        end,
        transaction = function(queries) for _, q in ipairs(queries) do LightRP.db.run(q.query, q.values) end return true end,
        single = function(sql, p)
            local n = pity[p[1] .. "#" .. p[2] .. "#" .. p[3]]
            return n and { misses = n } or nil
        end,
        query = function(sql, p)
            local out = {}
            for key in pairs(tableOf(sql)) do
                local id, k, item = key:match("^(.-)#(.-)#(.*)$")
                if id == p[1] and k == p[2] then out[#out + 1] = { item = item } end
            end
            return out
        end,
    },
    money = {
        get = function() return { bank = 0, cash = 0 } end,
        removeBank = function() return true end, addBank = function() return true end,
        format = function(n) return "€$ " .. n end,
    },
    ripperdoc = { isSeated = function() return true end },
    characters = { displayName = function(pid) return "Runner" .. pid end },
}
local crews = {} -- playerId -> crew { leader, members }
LightRP.parties = {
    of = function(pid) return crews[pid] end,
    members = function(pid) return crews[pid] and crews[pid].members or { pid } end,
}
local downed = {} -- playerId -> medical phase
LightRP.medical = { restoring = {}, view = function(pid) local phase = downed[pid]; return { downed = phase ~= nil, phase = phase or "healthy", receiving = false } end }
function LightRP.module(name, def) def.name = name; modules[#modules + 1] = def; LightRP[name] = LightRP[name] or def; return def end

dofile("server/config/cyberware.lua")
dofile("server/modules/cyberware.lua")
dofile("server/modules/cyberware_active.lua")
dofile("server/modules/cyberware_iconics.lua")
step(2)
threads = {} -- the watchdog stays out
local CW = LightRpCyberwareConfig
local Cyber, Active, Iconics = LightRP.cyberware, LightRP.cyberware_active, LightRP.cyberware_iconics

local function noticeOf(player, title)
    for i = #notices, 1, -1 do if notices[i].player == player and notices[i].def.title == title then return notices[i].def end end
end
local function load(pid, key)
    P.pos[pid] = P.pos[pid] or { x = pid * 2, y = 0, z = 0 }
    LightRP.eachModule("onCharacterLoaded", pid, { identifier = "acct" .. pid, key = key or "default" })
    step(3)
end
local function give(pid, item)
    commands["lightrp.cyberware"](0, { tostring(pid), "give", item })
    step(3)
end
for _, pid in ipairs({ 7, 8, 9 }) do load(pid) end

-- The client kit follows the fitted implants
assert(lastSent(7, "kit") and lastSent(7, "kit").scan == false and lastSent(7, "kit").berserk == false, "an empty kit")
give(7, "kiroshi_clairvoyant")
give(7, "berserk_mk1")
local kit = lastSent(7, "kit")
assert(kit.scan and kit.mark and kit.berserk, "Clairvoyant: scan + mark, Berserk")
give(9, "kiroshi_optics")
assert(lastSent(9, "kit").scan and not lastSent(9, "kit").mark, "plain Kiroshi: scan only")

-- Berserk: +80 armor now, +4 health / s; the layer is absorbed first and never stays
P.armor[7] = 0
actions["cyberware.berserk"](7)
assert(P.armor[7] == 80 and P.regen[7] == 4, "Berserk on: armor " .. tostring(P.armor[7]) .. ", regen " .. tostring(P.regen[7]))
assert(noticeOf(7, "BERSERK").kind == "success")
actions["cyberware.berserk"](7)
assert(noticeOf(7, "BERSERK").body:find("already running"), "one at a time")
P.armor[7] = 30 -- 50 absorbed by the layer
step(2)
assert(P.armor[7] == 0 and P.regen[7] == 0, "the leftover layer goes: armor " .. tostring(P.armor[7]))
assert(noticeOf(7, "BERSERK").body:find("over"), "told it is over")
actions["cyberware.berserk"](7)
assert(noticeOf(7, "BERSERK").body:find("recharging: 30 s"), noticeOf(7, "BERSERK").body)
clock = clock + 30000
-- with armor of its own: what the layer did not absorb stays, never more than before
give(7, "subdermal_armor")
assert(P.armor[7] == 30, "Subdermal Armor 30")
actions["cyberware.berserk"](7)
assert(P.armor[7] == 110, "30 + 80")
P.armor[7] = 90
step(2)
assert(P.armor[7] == 30, "back to the armor it had: " .. tostring(P.armor[7]))
P.armor[7] = 110 -- hit past the layer into its own: kept as is
clock = clock + 30000
actions["cyberware.berserk"](7)
P.armor[7] = 12
step(2)
assert(P.armor[7] == 12, "below what it had: nothing changed")
-- death ends it early
clock = clock + 30000
actions["cyberware.berserk"](7)
assert(P.regen[7] == 4)
P.life[7] = "dead"
LightRP.eachModule("onLifeState", 7, "dead")
assert(P.regen[7] == 0, "the layer ends with the body")
step(2)
P.life[7] = "alive"
LightRP.eachModule("onLifeState", 7, "alive")
step(3)
-- no Berserk fitted: refused with a reason
actions["cyberware.berserk"](8)
assert(noticeOf(8, "BERSERK").body:find("No Berserk"), "no Berserk")

-- Pain Editor: under 30% after a hit, +4 / s for 6 s, once a minute
give(8, "pain_editor")
fire("open77:playerDamaged", "8", "7", 40, "ranged", "w", "torso", 45, 100, false)
assert((P.regen[8] or 0) == 0, "45% left: nothing")
fire("open77:playerDamaged", "8", "7", 40, "ranged", "w", "torso", 0, 100, true)
assert((P.regen[8] or 0) == 0, "a lethal hit: nothing")
fire("open77:playerDamaged", "8", "7", 20, "ranged", "w", "torso", 25, 100, false)
assert(P.regen[8] == 4 and noticeOf(8, "PAIN EDITOR"), "25% left: the repair runs")
step(2)
assert(P.regen[8] == 0, "six seconds later it stops")
fire("open77:playerDamaged", "8", "7", 5, "ranged", "w", "torso", 20, 100, false)
assert(P.regen[8] == 0, "once a minute")
clock = clock + 60000
fire("open77:playerDamaged", "8", "7", 5, "ranged", "w", "torso", 20, 100, false)
assert(P.regen[8] == 4, "a minute later, again")
step(2)

-- Second Heart: a city downed state, up again after 5 s, once an hour per character
give(9, "second_heart")
downed[9] = "saving"
P.life[9] = "dead"
LightRP.eachModule("onLifeState", 9, "dead")
step(2)
assert(#P.revived == 0, "not before the delay and the saved downed state")
downed[9] = "downed"
step(2)
assert(#P.revived == 1 and P.revived[1].pid == 9 and P.revived[1].opts.health == 0.4, "revived by the Second Heart")
assert(noticeOf(9, "SECOND HEART").body:find("60 min"), "told, with the recharge")
downed[9] = nil
LightRP.eachModule("onLifeState", 9, "alive")
-- an hour of cooldown, per character: a reconnect does not reset it
LightRP.eachModule("onDisconnected", 9)
load(9)
downed[9] = "downed"
P.life[9] = "dead"
LightRP.eachModule("onLifeState", 9, "dead")
step(3)
assert(#P.revived == 1, "once an hour")
assert(Active.secondHeartReadyIn(9) > 3500000, "the cooldown survived the reconnect")
P.life[9] = "alive"; downed[9] = nil
LightRP.eachModule("onLifeState", 9, "alive")
clock = clock + 3600000
-- Dogtown: quiet (the Dogtown module, when it runs)
local tagged = false
LightRP.dogtown = { contains = function(pos) return pos and pos.x == 18 end, inZone = function() return tagged end }
downed[9] = "downed"; P.life[9] = "dead"
LightRP.eachModule("onLifeState", 9, "dead")
step(3)
assert(#P.revived == 1 and noticeOf(9, "SECOND HEART").body:find("Dogtown"), "quiet in Dogtown")
P.life[9] = "alive"; downed[9] = nil
assert(Active.secondHeartBlocked(9, { position = { x = 0, y = 0, z = 0 } }) == nil, "outside Dogtown")
tagged = true
assert(Active.secondHeartBlocked(9, { position = { x = 0, y = 0, z = 0 } }) == "dogtown", "tagged after leaving Dogtown: still its fight")
LightRP.dogtown = nil
-- activities: always off, PvE included (owner decision 2026-11-03)
local activity, rankedFlag = nil, nil
LightRP.activities = { owns = function() return activity ~= nil end, current = function() return activity end,
    isRanked = function() return rankedFlag end }
activity, rankedFlag = { pve = false, ranked = false }, false
assert(Active.secondHeartBlocked(9, {}) == "activity", "a PvP activity, even a friendly one")
activity, rankedFlag = { pve = true, ranked = true }, true
assert(Active.secondHeartBlocked(9, {}) == "activity", "a ranked PvE run")
activity, rankedFlag = { pve = true, ranked = false }, false
assert(Active.secondHeartBlocked(9, {}) == "activity", "an unranked PvE run too (owner: never in an activity)")
activity, rankedFlag = { pve = true, ranked = false }, nil
assert(Active.secondHeartBlocked(9, {}) == "activity", "no flag from isRanked: ranked")
LightRP.activities = { owns = function() return activity ~= nil end, current = function() return activity end }
activity = { pve = true, ranked = false }
assert(Active.secondHeartBlocked(9, {}) == "activity", "without isRanked: still an activity")
activity = { pve = true }
assert(Active.secondHeartBlocked(9, {}) == "activity", "no flag at all: ranked")
LightRP.activities = { owns = function() return true end, current = function() return nil end, isRanked = function() return nil end }
assert(Active.secondHeartBlocked(9, {}) == "activity", "an internal owner (missions) blocks it")
LightRP.activities = nil
-- a death that is not a city downed state (a mission respawn): nothing
P.life[9] = "dead"
LightRP.eachModule("onLifeState", 9, "dead")
step(3)
assert(#P.revived == 1, "no downed state, no Second Heart")
P.life[9] = "alive"

-- Kiroshi scan: name, crew, bounty (when the Dogtown module has one), in range only
P.pos[7], P.pos[8], P.pos[9] = { x = 0, y = 0, z = 0 }, { x = 5, y = 0, z = 0 }, { x = 3, y = 0, z = 0 }
crews[7] = { leader = 7, members = { 7, 9 } }; crews[9] = crews[7]
actions["cyberware.scan"](7, { target = { kind = "player", playerId = 8 } })
local scan = noticeOf(7, "KIROSHI SCAN")
assert(scan and scan.body == "Name: Runner8 · Crew: none", scan and scan.body)
actions["cyberware.scan"](7, { target = { kind = "player", playerId = 9 } })
assert(noticeOf(7, "KIROSHI SCAN") == scan, "two seconds between scans")
clock = clock + 2000
LightRP.dogtown = { bountyReward = function(pid) return pid == 9 and 2500 or 0 end, bounties = function() return { [9] = "srv:bounty" } end,
    streak = function(pid) return pid == 9 and 5 or 0 end }
actions["cyberware.scan"](7, { target = { kind = "player", playerId = 9 } })
assert(noticeOf(7, "KIROSHI SCAN").body == "Name: Runner9 · Crew: Runner7's crew (2) · Dogtown bounty: €$ 2500 (5-kill streak)", noticeOf(7, "KIROSHI SCAN").body)
clock = clock + 2000
actions["cyberware.scan"](7, { target = { kind = "player", playerId = 8 } })
assert(noticeOf(7, "KIROSHI SCAN").body == "Name: Runner8 · Crew: none · Dogtown bounty: none", noticeOf(7, "KIROSHI SCAN").body)
LightRP.dogtown = nil
clock = clock + 2000
P.pos[8] = { x = 80, y = 0, z = 0 }
actions["cyberware.scan"](7, { target = { kind = "player", playerId = 8 } })
assert(noticeOf(7, "KIROSHI SCAN").body:find("out of range"), "range")
P.pos[8] = { x = 5, y = 0, z = 0 }
clock = clock + 2000
P.bucket[8] = 3
actions["cyberware.scan"](7, { target = { kind = "player", playerId = 8 } })
assert(noticeOf(7, "KIROSHI SCAN").body:find("out of range"), "another bucket")
P.bucket[8] = nil
clock = clock + 2000
npcs[42] = { x = 4, y = 0, z = 0, bucket = 0, health = 50, maxHealth = 100 }
actions["cyberware.scan"](7, { target = { kind = "npc", npcId = 42 } })
assert(noticeOf(7, "KIROSHI SCAN").body == "No ID on file. Crew: none · Health 50%", noticeOf(7, "KIROSHI SCAN").body)
clock = clock + 2000
actions["cyberware.scan"](7, { target = { kind = "npc" } })
assert(noticeOf(7, "KIROSHI SCAN").body:find("Civilian"), "an ambient NPC")
actions["cyberware.scan"](8, { target = { kind = "player", playerId = 7 } })
assert(noticeOf(8, "KIROSHI").body:find("No Kiroshi"), "no optics, no scan")

-- Clairvoyant: a crew mark, on the map and above the target, for 10 s
actions["cyberware.mark"](9, { target = { kind = "player", playerId = 8 } })
assert(noticeOf(9, "CLAIRVOYANT").body:find("Clairvoyant optics"), "plain Kiroshi cannot mark")
actions["cyberware.mark"](7, { target = { kind = "player", playerId = 9 } })
assert(noticeOf(7, "CLAIRVOYANT").body:find("your crew"), "not your own crew")
actions["cyberware.mark"](7, { target = { kind = "npc" } })
assert(noticeOf(7, "CLAIRVOYANT").body:find("Nothing to lock onto"), "not an ambient NPC")
local sentBefore = #sent
actions["cyberware.mark"](7, { target = { kind = "player", playerId = 8 } })
local marks = Active.marks()
local id, m = next(marks)
assert(m and m.owner == 7 and #m.recipients == 2, "one mark for the crew of two")
assert(#blips.added == 1 and blips.added[1].def.icon == "target" and blips.added[1].target[1] == 7 and blips.added[1].target[2] == 9, "map blip for the crew")
assert(lastSent(7, "mark").id == id and lastSent(9, "mark").x == 5 and lastSent(9, "mark").label == "Runner8", "the arrow for both")
assert(noticeOf(9, "CLAIRVOYANT").body:find("Runner7 marked Runner8"), "the crew is told")
assert(lastSent(8, "mark") == nil, "the target is not told")
actions["cyberware.mark"](7, { target = { kind = "player", playerId = 8 } })
assert(noticeOf(7, "CLAIRVOYANT").body:find("Recharging"), "30 s between marks")
-- it follows the target, then runs out
P.pos[8] = { x = 6, y = 1, z = 0 }
step(2)
assert(blips.updated >= 1 and blips.last.x == 6 and lastSent(9, "mark").x == 6, "follows the target")
for _ = 1, 25 do step(1) end
assert(next(marks) == nil and lastSent(9, "unmark") and lastSent(9, "unmark").id == id and #blips.removed == 1, "gone after 10 s")
-- the target's death ends it
clock = clock + 30000
actions["cyberware.mark"](7, { target = { kind = "player", playerId = 8 } })
id = next(marks)
assert(id, "marked again")
P.life[8] = "dead"
LightRP.eachModule("onLifeState", 8, "dead")
assert(next(marks) == nil and lastSent(7, "unmark").id == id, "the target died: unmarked")
P.life[8] = "alive"
step(30)
-- an owned NPC can be marked, a crew member in another bucket does not get it, the marker's
-- disconnect ends it
clock = clock + 30000
P.bucket[9] = 2
actions["cyberware.mark"](7, { target = { kind = "npc", npcId = 42 } })
id, m = next(marks)
assert(m and m.label == "Target" and #m.recipients == 1 and m.recipients[1] == 7, "NPC mark, same bucket only")
P.bucket[9] = nil
LightRP.eachModule("onDisconnected", 7)
assert(next(marks) == nil, "the marker left: unmarked")
step(30)
load(7)

-- Suspension in PvP (activeInPvp = false): the kit empties, Berserk stands down
clock = clock + 60000
actions["cyberware.berserk"](7)
assert(P.regen[7] == 4, "Berserk running")
CW.activeInPvp = false
LightRP.eachModule("onActivityChanged", 7, "arena.ffa", { pve = false })
kit = lastSent(7, "kit")
assert(not kit.scan and not kit.mark and not kit.berserk and P.regen[7] == 0, "suspended: nothing active")
LightRP.eachModule("onActivityChanged", 7, nil, { left = "arena.ffa" })
assert(lastSent(7, "kit").berserk, "restored after")
CW.activeInPvp = true
step(3)

-- Iconic drops: world bosses (eligible participants only), with the pity counter
local roll = 0.99
_G.math.random = function(n) if n then return 1 end return roll end
local function boss(results)
    LightRP.eachModule("onWorldBossFinished", { id = "wb", title = "Test", boss = "Boss", success = true, results = results })
    step(2)
end
local pityAt = CW.iconics.sources.worldBoss.pity
for i = 1, pityAt - 1 do boss({ [7] = { eligible = true }, [8] = { eligible = false } }) end
assert(pity["acct7#default#worldBoss"] == pityAt - 1 and pity["acct8#default#worldBoss"] == nil, "misses counted, ineligible not rolled")
assert(not Cyber.stored(7).feral_biomonitor, "no drop yet")
boss({ [7] = { eligible = true } })
assert(Cyber.stored(7).feral_biomonitor and stored["acct7#default#feral_biomonitor"], "the pity drop lands in storage")
assert(pity["acct7#default#worldBoss"] == 0, "the counter starts over")
assert(noticeOf(7, "ICONIC IMPLANT").body:find("Feral Biomonitor") and broadcasts[#broadcasts].body:find("Runner7 pulled an iconic implant out of the World bosses"),
    "the winner and the city are told")
boss({ [7] = { eligible = true } })
assert(pity["acct7#default#worldBoss"] == 0, "owning every item of a source: not rolled")
-- a lucky roll
roll = 0.01
boss({ [8] = { eligible = true } })
assert(Cyber.stored(8).feral_biomonitor and pity["acct8#default#worldBoss"] == 0, "a roll under the chance drops")
-- a failed world boss drops nothing
LightRP.eachModule("onWorldBossFinished", { success = false, results = { [9] = { eligible = true } } })
step(2)
assert(not Cyber.stored(9).feral_biomonitor, "an escaped boss drops nothing")
-- the Chimera on Critical only, never a test run
local function raid(difficulty, test)
    LightRP.eachModule("onRaidFinished", { instance = "i1", point = "chimera_raid", difficulty = difficulty, success = true, test = test, members = { 9 } })
    step(2)
end
raid("hard", false)
raid("critical", true)
assert(not Cyber.stored(9).chimera_plating and pity["acct9#default#chimeraCritical"] == nil, "Hard and test runs never roll")
raid("critical", false)
assert(Cyber.stored(9).chimera_plating, "Critical: dropped")
assert(Iconics.roll(9, "chimeraCritical") == nil, "owned: no second roll")
-- the dropped iconic is fitted like any stored implant (the fitting fee, its capacity)
local done
Cyber.operate(9, "install", "chimera_plating", function(ok, message) done = { ok, message } end)
step(3)
assert(done and done[1] == true and Cyber.installed(9).chimera_plating, tostring(done and done[2]))

print("cyberware_active_test: ok")
