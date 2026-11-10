-- HUD lab scenes for client/native/queue.lua, missions.lua, raid.lua and workorder.lua.
-- Payloads have the shapes of ui/src/bridge/protocol.ts (QueueState, MissionQueueState,
-- MissionObjective, FixerGigState, WorldBossState, RaidState, JobRunState, JobRunLive).
--
-- The lab's character is playerId 1. The kit choices (mission-kit, raid-ready) make the
-- modules take the keyboard by themselves (doc:focus, no cursor); `hudlab:missions-clear`
-- or any later scene of this file gives it back. A key pressed there calls
-- TriggerServerEvent, which has no session in the lab.
local E = LightRpEvents
local ME = 1

-- client/core/queue.lua is not in the lab: the panel asks it for the bound key.
local queueKey = "U"
LightRpQueue = LightRpQueue or { keyName = function() return queueKey or nil end }

-- Takes away whatever an earlier scene of this file left (and the raid's cover on the HUD).
local function clear(lab)
    queueKey = "U"
    lab.page(E.page.raid, { phase = "placing" })   -- drops a result still showing
    lab.page(E.page.raid, { phase = "ended" })
    lab.page("lightrp:ui:fuel:state", { phase = "finished" })
    lab.state({ queue = false, missionQueue = false, fixerGig = false, worldBoss = false, jobRun = { active = false } })
    lab.wait(150)
end

local SQUAD = {
    { id = 1, name = "Lab Runner", citizen = "LR-0001", host = true, health = 100, maxHealth = 100, armor = 40, state = "alive" },
    { id = 2, name = "Jackie Welles", citizen = "JW-2077", host = false, health = 62, maxHealth = 100, armor = 0, state = "alive" },
    { id = 3, name = "Panam Palmer", citizen = "PP-0420", host = false, health = 0, maxHealth = 100, armor = 0, state = "down" },
}
local KITS = {
    { id = "assault", label = "ASSAULT", blurb = "Rifle and frags. The all-rounder." },
    { id = "breacher", label = "BREACHER", blurb = "Shotgun, incendiaries, heavy plating." },
    { id = "marksman", label = "MARKSMAN", blurb = "Sniper rifle and a sidearm. Stay far." },
    { id = "gunner", label = "GUNNER", blurb = "Light machine gun, more ammunition." },
    { id = "tech", label = "TECH", blurb = "Tech rifle, EMP grenades, a medkit more." },
}
local function mission(objective, endsInMs)
    return { running = true, instance = "lab-1", title = "Arasaka Waterfront", difficulty = "HARD", difficultyId = "hard",
        endsInMs = endsInMs or 754000, members = 3, squad = SQUAD, objective = objective }
end

HudLab.scene("missions-clear", function(lab) clear(lab) end)

-- ---- the queue panel ---------------------------------------------------------------------
HudLab.scene("queue-panel", function(lab)
    clear(lab)
    -- the core's ranked search, alone: QUEUED, 1 / 2-8, NEED 1 MORE, the wait counts up
    lab.state({ queue = { v = 1, id = "arena", label = "Arena", mode = "Gun game", count = 1, need = 2, max = 8, sinceMs = 0, state = "waiting", source = "core" } })
    lab.wait(2500)
    -- a provider's lobby with the minimum there, queued by the crew leader
    lab.state({ queue = { v = 1, id = "race", label = "Street race", mode = "Santo Domingo sprint", count = 4, need = 2, max = 6, sinceMs = 73000, state = "waiting", crew = true, source = "provider" } })
    lab.wait(2500)
    -- scheduled: STARTING, the accent frame, the countdown
    lab.state({ queue = { v = 1, id = "race", label = "Street race", mode = "Santo Domingo sprint", count = 5, need = 2, max = 6, sinceMs = 76000, startsInMs = 8000, state = "starting", source = "provider" } })
    lab.wait(4000)
    -- MATCH FOUND / JOINING
    lab.state({ queue = { v = 1, id = "race", label = "Street race", mode = "Santo Domingo sprint", count = 6, need = 2, max = 6, sinceMs = 80000, state = "joining", source = "provider" } })
    lab.wait(2000)
    -- a mission board: TAGGED, then LAUNCHING; the key cleared: F1 / LEAVE QUEUE
    queueKey = false
    lab.state({ queue = { v = 1, id = "mission:waterfront", label = "Arasaka Waterfront", mode = "HARD", count = 2, need = 2, max = 4, sinceMs = 31000, state = "waiting", source = "mission" } })
    lab.wait(2500)
    queueKey = "U"
    lab.state({ queue = { v = 1, id = "mission:waterfront", label = "Arasaka Waterfront", mode = "HARD", count = 3, need = 2, max = 4, sinceMs = 34000, startsInMs = 10000, state = "starting", source = "mission" } })
    lab.wait(2500)
    -- under a fixer gig's chip: 40 dp lower
    lab.state({ fixerGig = { id = 7, title = "Clean sweep", location = "Kabuki", fixer = "Regina Jones", state = "accepted", crew = 3, min = 2, max = 4, owner = true, here = 1, meetInMs = 95000 } })
end)

-- ---- the running mission's chip -------------------------------------------------------------
HudLab.scene("mission-chip", function(lab)
    clear(lab)
    lab.state({ missionQueue = mission(nil, 754000) })
    lab.wait(2500)
    -- the last seconds
    lab.state({ missionQueue = { running = true, instance = "lab-1", title = "Arasaka Waterfront", difficulty = "CRITICAL", difficultyId = "critical", endsInMs = 9000, members = 3, squad = SQUAD } })
end)

-- ---- a fixer gig taken, before it runs --------------------------------------------------------
HudLab.scene("fixer-gig", function(lab)
    clear(lab)
    -- accepted, short of the minimum: CREW 1/4 · NEED 1
    lab.state({ fixerGig = { id = 7, title = "Clean sweep", location = "Kabuki", fixer = "Regina Jones", state = "accepted", crew = 1, min = 2, max = 4, owner = true, here = 1 } })
    lab.wait(2500)
    -- the crew is taken, one at the meet point: AT THE MEET 1/3 and the meeting clock
    lab.state({ fixerGig = { id = 7, title = "Clean sweep", location = "Kabuki", fixer = "Regina Jones", state = "accepted", crew = 3, min = 2, max = 4, owner = true, here = 1, meetInMs = 95000 } })
    lab.wait(3000)
    lab.state({ fixerGig = { id = 7, title = "Clean sweep", location = "Kabuki", fixer = "Regina Jones", state = "accepted", crew = 3, min = 2, max = 4, owner = true, here = 2, meetInMs = 61000 } })
    lab.wait(2000)
    -- everyone there
    lab.state({ fixerGig = { id = 7, title = "Clean sweep", location = "Kabuki", fixer = "Regina Jones", state = "accepted", crew = 3, min = 2, max = 4, owner = true, here = 3, meetInMs = 58000 } })
    lab.wait(2000)
    -- the launch countdown
    lab.state({ fixerGig = { id = 7, title = "Clean sweep", location = "Kabuki", fixer = "Regina Jones", state = "countdown", crew = 3, min = 2, max = 4, owner = true, here = 3, launchInMs = 10000 } })
end)

-- ---- the world boss -----------------------------------------------------------------------------
HudLab.scene("world-boss", function(lab)
    clear(lab)
    local function boss(fields)
        local b = { id = "wb-1", title = "World boss", location = "Arroyo docks", boss = "Sasquatch", phase = "fight",
            bossHealth = 1, enemiesLeft = 12, fighters = 7, endsInMs = 600000, share = 0, minShare = 5, eligible = false,
            damage = 0, kills = 0, reward = 45000, inZone = true }
        for k, v in pairs(fields) do b[k] = v end
        return b
    end
    lab.state({ worldBoss = boss({}) })
    lab.wait(2000)
    lab.state({ worldBoss = boss({ bossHealth = 0.74, enemiesLeft = 9, endsInMs = 512000, share = 3.2, damage = 1840, kills = 1 }) })
    lab.wait(2000)
    -- above the minimum that pays
    lab.state({ worldBoss = boss({ bossHealth = 0.41, enemiesLeft = 4, fighters = 9, endsInMs = 388000, share = 11.6, eligible = true, damage = 12480, kills = 3 }) })
    lab.wait(2000)
    -- out of the zone: dimmed, OUT OF THE ZONE
    lab.state({ worldBoss = boss({ bossHealth = 0.12, enemiesLeft = 1, fighters = 8, endsInMs = 201000, share = 14.9, eligible = true, damage = 21930, kills = 4, inZone = false }) })
    lab.wait(2500)
    -- a staff event on the same engine
    lab.state({ worldBoss = boss({ tag = "CYBERPSYCHO", boss = "Ellis Carter", location = "Japantown", noPay = true, bossHealth = 0.58, enemiesLeft = 0, fighters = 3, endsInMs = 240000, share = 37.5, damage = 6200, kills = 0 }) })
    lab.wait(2500)
    -- cleanup without a result yet: OVER
    lab.state({ worldBoss = boss({ phase = "cleanup", bossHealth = 0, enemiesLeft = 2, share = 14.9, eligible = true, damage = 21930, kills = 4 }) })
    lab.wait(2000)
    -- the results: under the minimum, nobody paid, paid
    lab.state({ worldBoss = boss({ phase = "done", bossHealth = 0, enemiesLeft = 0, share = 3.2, damage = 1840, kills = 1,
        result = { success = true, share = 3.2, pay = 0, eligible = false, damage = 1840, kills = 1 } }) })
    lab.wait(2500)
    lab.state({ worldBoss = boss({ phase = "done", bossHealth = 0.33, enemiesLeft = 5, share = 14.9, eligible = true, damage = 21930, kills = 4,
        result = { success = false, share = 14.9, pay = 0, eligible = true, damage = 21930, kills = 4 } }) })
    lab.wait(2500)
    lab.state({ worldBoss = boss({ phase = "done", bossHealth = 0, enemiesLeft = 0, share = 14.9, eligible = true, damage = 21930, kills = 4,
        result = { success = true, share = 14.9, pay = 6705, eligible = true, damage = 21930, kills = 4 } }) })
end)

-- ---- an authored mission's objective ---------------------------------------------------------
HudLab.scene("mission-objective", function(lab)
    clear(lab)
    -- staging: DEPLOYING, contact in N s
    lab.state({ missionQueue = mission({ kind = "eliminate", phase = "staging", enemiesLeft = 14, kills = 0, lives = 3, startsInMs = 6000 }) })
    lab.wait(3000)
    -- eliminate: checkpoints reached / to reach / optional
    lab.state({ missionQueue = mission({ kind = "eliminate", phase = "fight", enemiesLeft = 14, kills = 0, lives = 3, checkpoints = {
        { label = "Breach the loading dock", reached = false, required = true },
        { label = "Reach the server room", reached = false, required = true },
        { label = "Loot the armoury", reached = false, required = false },
    } }, 740000) })
    lab.wait(2500)
    lab.state({ missionQueue = mission({ kind = "eliminate", phase = "fight", enemiesLeft = 1, kills = 13, lives = 2, checkpoints = {
        { label = "Breach the loading dock", reached = true, required = true },
        { label = "Reach the server room", reached = false, required = true },
        { label = "Loot the armoury", reached = true, required = false },
    } }, 612000) })
    lab.wait(2500)
    -- waves: the live wave pulses, then the intermission's countdown
    lab.state({ missionQueue = mission({ kind = "waves", phase = "wave", enemiesLeft = 8, kills = 21, lives = 2, wave = 2, waves = 5 }, 540000) })
    lab.wait(2500)
    lab.state({ missionQueue = mission({ kind = "waves", phase = "intermission", enemiesLeft = 0, kills = 29, lives = 2, wave = 2, waves = 5, nextWaveInMs = 8000 }, 500000) })
    lab.wait(3000)
    lab.state({ missionQueue = mission({ kind = "waves", phase = "wave", enemiesLeft = 11, kills = 29, lives = 1, wave = 3, waves = 5 }, 490000) })
end)

HudLab.scene("mission-out-of-zone", function(lab)
    clear(lab)
    lab.state({ missionQueue = mission({ kind = "eliminate", phase = "fight", enemiesLeft = 6, kills = 8, lives = 3, outOfBoundsMs = 10000, checkpoints = {
        { label = "Breach the loading dock", reached = true, required = true },
        { label = "Reach the server room", reached = false, required = true },
    } }, 600000) })
end)

HudLab.scene("mission-respawn", function(lab)
    clear(lab)
    -- KIT ISSUED: ready in the briefing, waiting for the squad
    lab.state({ missionQueue = mission({ kind = "eliminate", phase = "staging", enemiesLeft = 14, kills = 0, lives = 3, startsInMs = 20000,
        loadouts = KITS, loadout = "assault", ready = true, readyCount = 2, squadSize = 3 }) })
    lab.wait(3000)
    -- DOWN: back in N s (no kit choice on this mission)
    lab.state({ missionQueue = mission({ kind = "eliminate", phase = "fight", enemiesLeft = 9, kills = 5, lives = 2, respawnInMs = 6000 }, 650000) })
    lab.wait(4000)
    -- OUT: no team respawn left
    lab.state({ missionQueue = mission({ kind = "eliminate", phase = "fight", enemiesLeft = 9, kills = 5, lives = 0, spectating = true }, 640000) })
end)

-- The kit choice. The module takes the keyboard here (see the header).
HudLab.scene("mission-kit", function(lab)
    clear(lab)
    -- down, canChoose: NEXT LIFE · PICK A KIT above the DOWN chip
    lab.state({ missionQueue = mission({ kind = "waves", phase = "wave", enemiesLeft = 8, kills = 21, lives = 2, wave = 2, waves = 5,
        respawnInMs = 12000, canChoose = true, loadouts = KITS, loadout = "marksman" }, 540000) })
    lab.wait(5000)
    -- the briefing: MISSION / BRIEFING, the kits, READY [Enter]
    lab.state({ missionQueue = mission({ kind = "eliminate", phase = "staging", enemiesLeft = 14, kills = 0, lives = 3, startsInMs = 45000,
        loadouts = KITS, loadout = "assault", ready = false, readyCount = 1, squadSize = 3 }) })
    lab.wait(2500)
    lab.state({ missionQueue = mission({ kind = "eliminate", phase = "staging", enemiesLeft = 14, kills = 0, lives = 3, startsInMs = 42500,
        loadouts = KITS, loadout = "tech", ready = false, readyCount = 2, squadSize = 3 }) })
end)

-- ---- the raid ---------------------------------------------------------------------------------
local function raid(fields)
    local r = { instance = "raid-lab", title = "Chimera", difficulty = "HARD", difficultyId = "hard", readyKey = "Y", loaded = true,
        arena = { x = -2380, y = -2720, z = 26 } }
    for k, v in pairs(fields) do r[k] = v end
    return r
end
local function operators(mine, jackie, panam, panamLoaded)
    return {
        { id = ME, name = "Lab Runner", ready = mine, down = false, loaded = true },
        { id = 2, name = "Jackie Welles", ready = jackie, down = false, loaded = true },
        { id = 3, name = "Panam Palmer", ready = panam, down = false, loaded = panamLoaded },
    }
end

-- The ready check. While this operator picks a kit the module takes the keyboard; the
-- scene ends with this operator ready, which gives it back.
HudLab.scene("raid-ready", function(lab)
    clear(lab)
    -- this client still loads the arena: LOADING, the button greyed
    lab.page(E.page.raid, raid({ phase = "ready", loaded = false, readyEndsInMs = 45000, operators = operators(false, false, false, false), loadouts = KITS, loadout = "assault" }))
    lab.wait(2500)
    lab.page(E.page.raid, raid({ phase = "ready", readyEndsInMs = 42000, operators = operators(false, true, false, false), loadouts = KITS, loadout = "assault" }))
    lab.wait(2500)
    lab.page(E.page.raid, raid({ phase = "ready", readyEndsInMs = 39000, operators = operators(false, true, false, true), loadouts = KITS, loadout = "gunner" }))
    lab.wait(2500)
    -- ready: 440 wide, the kits dimmed but the pick, "Loadout issued"
    lab.page(E.page.raid, raid({ phase = "ready", readyEndsInMs = 36000, operators = operators(true, true, false, true), loadouts = KITS, loadout = "gunner" }))
    lab.wait(3000)
    -- everyone ready: the launch countdown, then the uplink
    lab.page(E.page.raid, raid({ phase = "launch", launchInMs = 5000, operators = operators(true, true, true, true) }))
    lab.wait(5200)
    lab.page(E.page.raid, raid({ phase = "placing", operators = operators(true, true, true, true) }))
end)

HudLab.scene("raid-intro", function(lab)
    clear(lab)
    lab.page(E.page.raid, raid({ phase = "intro", difficulty = "CRITICAL", difficultyId = "critical", operators = operators(true, true, true, true),
        intro = { boss = { x = -2380, y = -2720, z = 26 }, durationMs = 11000, difficulty = "CRITICAL", operators = 3 } }))
    lab.wait(11300)
    -- the fight starts: the cover on the HUD goes
    lab.page(E.page.raid, raid({ phase = "fight", difficulty = "CRITICAL", difficultyId = "critical", bossId = "npc-1", operators = operators(true, true, true, true),
        boss = { healthPercent = 100, phase = "armored", label = "CHIMERA", enraged = false }, adds = 0, lives = 0, fightSeconds = 0, enrageInMs = 480000 }))
end)

HudLab.scene("raid-boss", function(lab)
    clear(lab)
    local function fight(boss, fields)
        local r = raid({ phase = "fight", bossId = "npc-1", operators = operators(true, true, true, true), boss = boss, adds = 0, lives = 3, fightSeconds = 0, enrageInMs = 480000 })
        for k, v in pairs(fields or {}) do r[k] = v end
        return r
    end
    lab.page(E.page.raid, fight({ healthPercent = 100, phase = "armored", label = "CHIMERA", enraged = false },
        { announce = { title = "ENGAGE", body = "Break its plating. Aim for the joints.", tone = "info", at = 0 } }))
    lab.wait(4500)
    -- locked on a squad mate
    lab.page(E.page.raid, fight({ healthPercent = 71, phase = "exposed", label = "CHIMERA", enraged = false, target = 2, targetName = "Jackie Welles" },
        { adds = 4, lives = 2, fightSeconds = 96, enrageInMs = 384000, announce = { title = "PLATING BREACHED", body = "The core is exposed. Reinforcements inbound.", tone = "success", at = 96 } }))
    lab.wait(4500)
    -- locked on this operator: YOU ARE TARGETED
    lab.page(E.page.raid, fight({ healthPercent = 54, phase = "gas", label = "CHIMERA", enraged = false, target = ME, targetName = "Lab Runner" },
        { adds = 6, lives = 1, fightSeconds = 211, enrageInMs = 269000, announce = { title = "GAS VENTING", body = "Get to high ground.", tone = "warning", at = 211 } }))
    lab.wait(4500)
    -- shielded, the overclock under a minute, no respawn left
    lab.page(E.page.raid, fight({ healthPercent = 30, phase = "core", label = "CHIMERA", enraged = false, repairing = true, repairInMs = 14000 },
        { adds = 2, lives = 0, fightSeconds = 428, enrageInMs = 52000 }))
    lab.wait(3500)
    -- flatlined: the respawn countdown
    lab.page(E.page.raid, fight({ healthPercent = 22, phase = "core", label = "CHIMERA", enraged = false },
        { adds = 3, lives = 1, fightSeconds = 450, enrageInMs = 30000, respawnInMs = 5000 }))
    lab.wait(5200)
    -- out of the fight
    lab.page(E.page.raid, fight({ healthPercent = 18, phase = "core", label = "CHIMERA", enraged = false },
        { adds = 3, lives = 0, fightSeconds = 462, enrageInMs = 18000, out = true }))
    lab.wait(3000)
    -- overclocked, unlimited respawns
    lab.page(E.page.raid, fight({ healthPercent = 9, phase = "core", label = "CHIMERA", enraged = true, target = 3, targetName = "Panam Palmer" },
        { adds = 5, lives = -1, fightSeconds = 481, announce = { title = "OVERCLOCK", body = "The Chimera burns its limiters. End it now.", tone = "danger", at = 481 } }))
end)

HudLab.scene("raid-result", function(lab)
    clear(lab)
    local boss = { healthPercent = 0, phase = "core", label = "CHIMERA", enraged = true }
    -- CHIMERA DOWN with the fight's time, then MISSION COMPLETE for 6 s
    lab.page(E.page.raid, raid({ phase = "victory", operators = operators(true, true, true, true), boss = boss, adds = 0, lives = 1, fightSeconds = 503 }))
    lab.wait(4000)
    lab.page(E.page.raid, { phase = "ended", result = "victory" })
    lab.wait(6500)
    -- CREW WIPED, then MISSION FAILED (left on screen until it expires)
    lab.page(E.page.raid, raid({ phase = "wipe", operators = operators(true, true, true, true), boss = { healthPercent = 37, phase = "gas", label = "CHIMERA", enraged = false }, adds = 6, lives = 0, fightSeconds = 244 }))
    lab.wait(4000)
    lab.page(E.page.raid, { phase = "ended", result = "failed" })
end)

-- ---- the work order ----------------------------------------------------------------------------
local function courier(index, states, fields)
    local places = { "Megabuilding H10", "Lizzie's Bar", "Kabuki Market", "Tom's Diner" }
    local kinds = { "pickup", "dropoff", "pickup", "dropoff" }
    local stops = {}
    for i = 1, 4 do
        stops[i] = { kind = kinds[i], label = (kinds[i] == "pickup" and "Pick up at " or "Deliver to ") .. places[i], place = places[i], order = (i + 1) // 2, state = states[i] }
    end
    local run = { active = true, id = "run-lab-1", job = "delivery", jobLabel = "Courier", label = "Courier round", reward = 1840,
        index = index, total = 4, icon = "package", hint = "Ride to the marker and press E.", orders = 2, carried = 0, distanceKm = 3.4,
        stops = stops, expiresInMs = 600000,
        objective = { label = stops[index].label, place = places[index], kind = kinds[index], position = { x = -1200 + index * 90, y = 310, z = 12 }, radius = 3 } }
    for k, v in pairs(fields or {}) do run[k] = v end
    return run
end

HudLab.scene("workorder", function(lab)
    clear(lab)
    -- a courier round: far from the first pickup, the GPS on
    lab.state({ money = { cash = 1250, bank = 48200, currency = "€$" }, jobRun = courier(1, { "now", "todo", "todo", "todo" }) })
    lab.page(E.page.jobRun, { distance = 1840, menuKey = "F1", gps = true })
    lab.wait(2500)
    -- closer, the route lost: NO ROUTE blinks
    lab.page(E.page.jobRun, { distance = 240, menuKey = "F1", gps = false })
    lab.wait(2500)
    -- on the marker: the E key, the wider rail
    lab.page(E.page.jobRun, { distance = 2, menuKey = "F1", gps = true })
    lab.wait(2500)
    lab.state({ jobRun = courier(1, { "now", "todo", "todo", "todo" }, { busy = true, expiresInMs = 592000 }) })
    lab.wait(1500)
    -- the next stop swaps in: deliver order 01
    lab.state({ jobRun = courier(2, { "done", "now", "todo", "todo" }, { carried = 1, expiresInMs = 590000 }) })
    lab.page(E.page.jobRun, { distance = 620, menuKey = "F1", gps = true })
    lab.wait(3000)
    lab.state({ jobRun = courier(3, { "done", "done", "now", "todo" }, { carried = 0, expiresInMs = 410000 }) })
    lab.page(E.page.jobRun, { distance = 1100, menuKey = "F1", gps = true })
    lab.wait(3000)
    -- the last drop, under three minutes: the clock turns red, ON THIS DROP
    lab.state({ jobRun = courier(4, { "done", "done", "done", "now" }, { carried = 1, expiresInMs = 170000 }) })
    lab.page(E.page.jobRun, { distance = 85, menuKey = "F1", gps = true })
    lab.wait(4000)
    -- a route of plain stops, a half of a Big Contract, working on the marker
    lab.state({ jobRun = { active = true, id = "run-lab-2", job = "ac_cleaner", jobLabel = "AC technician", label = "Maintenance round", reward = 12600,
        index = 2, total = 4, icon = "fan", hint = "Service the unit on the roof.", working = true, expiresInMs = 1500000,
        duo = { partner = "Jackie Welles", half = "A" },
        stops = {
            { kind = "lift", label = "Take the service lift", place = "Megabuilding H8 lift", state = "done" },
            { kind = "work", label = "Service the AC unit", place = "H8 rooftop, unit 3", state = "now" },
            { kind = "work", label = "Service the AC unit", place = "H8 rooftop, unit 7", state = "todo" },
            { kind = "return", label = "Return to the depot", place = "Coastview depot", state = "todo" },
        },
        objective = { label = "Service the AC unit", place = "H8 rooftop, unit 3", kind = "work", position = { x = -1410, y = 1220, z = 118 }, radius = 3 } } })
    lab.page(E.page.jobRun, { distance = 2, menuKey = "F1", gps = true })
end)

HudLab.scene("workorder-fuel", function(lab)
    clear(lab)
    lab.page("lightrp:ui:fuel:state", { phase = "approach", token = "lab", label = "Quadra Turbo-R 740", expiresMs = 20000, cancelKey = "X", position = { x = 0, y = 0, z = 0 } })
end)
