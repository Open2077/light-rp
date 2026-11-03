-- op77_chase NCPD Escape (chase.pve), end to end against fakes (tests/bots_env.lua): the
-- whole resource, a fake Light RP (difficulties, tier gate), a fake PreventionService
-- (setWanted / setMaxWanted), fake population, KVP and NPC / vehicle-AI natives.
--
-- police = "ncpd" (the default):
--   * registration: PvE with its difficulties, caps.botFill = false;
--   * the rules alone: the heat ramp by difficulty (3 / 4 / 5 stars), next star, the bust
--     meter (stopped, out of the car, boarding grace, drain, close call, blackout), down,
--     extraction, clock;
--   * solo by car, Standard: the difficulty reaches activityEnter, the instance gets its
--     traffic, no wanted level in the head start, then ceiling first and the ramp to 3, the
--     level re-sent, HUD + view with the bust meter; BUSTED when he stops; stars 0 / ceiling
--     5 at once; reputation x the difficulty; home; population back to empty;
--   * Hard: ESCAPED at the extraction (36 rep); Critical: ESCAPED by the clock at 5 stars
--     (60 rep); down = busted; out of his car = busted, a fast "out of car" is a car the
--     server cannot see; never boarding = busted after the grace; a close call;
--   * every other way out clears the level: leave, drop (still connected), a bucket change,
--     Light RP stopping, the resource stopping (refused) then the next start (ledger sweep),
--     a ledger entry for a gone or different player;
--   * the police probe: a refused raise = warned on the HUD (warn) or called off (void);
--   * population refused: the escape still runs; crews together (each his own level) and
--     solo (one instance each); the tier gate; /escape [mode] [difficulty]; staff status;
--     reputation rules;
-- police = "bots": the bot cops (grid, waves, arrest on the bot cars), no wanted level, no
-- population; broken bots = void; resource stop removes bodies and cars.
-- Never a database touch, never a test result.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test pve_test.lua
local H = dofile("tests/bots_env.lua")
local env
local AID = "chase.pve"

local function result(id)
    local list = H.results(id, AID)
    return list[#list] and list[#list].args[3], #list
end

local function noCars() assert(H.count(env.cars) == 0, "every car removed") end

-- Driving in circles around `center` at `kph` (radius r): a speed well above any threshold.
local function circling(center, kph, r)
    r = r or 60
    local w = (kph / 3.6) / r
    local t0 = env.clock
    return function(t)
        local a = w * (t - t0) / 1000
        return { x = center.x + r * math.cos(a), y = center.y + r * math.sin(a), z = center.z }
    end
end

local function wantedOps(id, op)
    local out = {}
    for _, w in ipairs(env.wantedLog) do if w.id == id and (op == nil or w.op == op) then out[#out + 1] = w end end
    return out
end

local function cleared(id)
    local w = H.wanted(id)
    return w.level == 0 and w.maxLevel == 5
end

local function ledger()
    local n = 0
    for k in pairs(env.kvp) do if k:sub(1, 14) == "escape.wanted." then n = n + 1 end end
    return n
end

-- Join (Light RP's panel: options.mode + options.difficulty), wait for GO; by car he sits
-- in his car and drives circles.
local function start(id, mode, difficulty, opts)
    opts = opts or {}
    H.fire("op77_lightrp:activity:join", id, AID, { mode = mode, difficulty = difficulty, squad = opts.squad })
    H.runUntil(function() return ChasePve.matchOf(id) ~= nil end, 6, "an escape for " .. id)
    local match = ChasePve.matchOf(id)
    H.runUntil(function() return match.state == "active" end, 30, "GO for " .. id)
    local m = ChasePve.member(match, id)
    if mode ~= "foot" and not opts.noSeat then env.seats[id] = match.cars[id].id end
    if not opts.still then env.pos[id] = circling(m.point.position, mode == "foot" and 15 or 40) end
    return match, m
end

local function closed(match) H.runUntil(function() return ChasePve.matches[match.id] == nil end, 25, "closed") end

-- ════════════════════════════════════════════════════════════════ police = "ncpd"

env = H.load()
local reg = env.registered[AID]
assert(reg and reg.pve == true and reg.difficulties[1] == "standard" and reg.difficulties[3] == "critical", "PvE with its difficulties")
assert(reg.caps.botFill == false and reg.minPlayers == 1 and reg.modes[2].id == "foot", "botFill = false, solo, car or foot")
assert(ChasePve.policeMode() == "ncpd", "the game's own NCPD by default")

-- ---------------------------------------------------------------- the rules alone

do
    local E = ChaseEscapeRules
    local D = ChaseConfig.pve.difficulties
    assert(E.ceiling(D.standard.heat) == 3 and E.ceiling(D.hard.heat) == 4 and E.ceiling(D.critical.heat) == 5, "3 / 4 / 5 stars")
    local head = 6000
    assert(E.starsAt(D.standard.heat, head, 5999) == 0, "nothing in the head start")
    assert(E.starsAt(D.standard.heat, head, 6000) == 1 and E.starsAt(D.standard.heat, head, 36000) == 2
        and E.starsAt(D.standard.heat, head, 81000) == 3 and E.starsAt(D.standard.heat, head, 400000) == 3, "Standard ramps to 3")
    assert(E.starsAt(D.hard.heat, head, 6000) == 2 and E.starsAt(D.hard.heat, head, 81000) == 4, "Hard starts at 2, ramps to 4")
    assert(E.starsAt(D.critical.heat, head, 100999) == 4 and E.starsAt(D.critical.heat, head, 101000) == 5, "Critical: MaxTac at +95 s")
    assert(E.nextStarMs(D.standard.heat, head, 10000) == 26000 and E.nextStarMs(D.standard.heat, head, 90000) == nil, "next star")
    assert(E.difficulty("nonsense") == "standard" and E.difficulty("hard") == "hard", "unknown difficulty = the default")

    -- The meter, by car: armed by the first star and the car, fills when stopped, drains.
    local run = E.newRun("vehicle", "standard", 0)
    local p = { x = 0, y = 0, z = 0 }
    local function at(t, pos, extra)
        local s = { pos = pos, down = false, inCar = true, boarded = true }
        for k, v in pairs(extra or {}) do s[k] = v end
        return E.step(run, t, s)
    end
    for t = 0, 5800, 200 do assert(at(t, p) == nil) end
    assert(run.stars == 0 and run.bustMeter == 0, "no star, no meter in the head start, even stopped")
    local outcome, events = at(6000, p)
    assert(run.stars == 1 and events[1].kind == "heat" and events[1].stars == 1, "first star")
    for t = 6200, 10600, 200 do outcome = at(t, p) end
    assert(outcome == nil and run.bustMeter > 0.9 and run.why == "stopped", "filling while stopped")
    outcome = at(10800, p)
    assert(outcome and outcome.outcome == "runner_busted" and outcome.detail == "stopped", "busted after bustFillSeconds")

    -- A close call: 3.5 s stopped (0.7), then he drives off; the meter drains to 0.
    run = E.newRun("vehicle", "standard", 0)
    for t = 0, 6000, 200 do at(t, p) end
    for t = 6200, 9600, 200 do at(t, p) end
    assert(run.bustMeter >= 0.6, "past the close-call mark")
    local x, calls = 0, nil
    for t = 9800, 14000, 200 do
        x = x + 4
        local _, ev = at(t, { x = x, y = 0, z = 0 })
        for _, e in ipairs(ev) do if e.kind == "close_call" then calls = e.count end end
    end
    assert(run.bustMeter == 0 and calls == 1 and run.closeCalls == 1, "drained: one close call")

    -- Out of every car: fills even while walking; a fast "out of car" is a car we cannot see.
    run = E.newRun("vehicle", "standard", 0)
    for t = 0, 6000, 200 do at(t, p) end
    x = 0
    for t = 6200, 8000, 200 do x = x + 0.3; at(t, { x = x, y = 0, z = 0 }, { inCar = false }) end
    assert(run.why == "out_of_car" and run.bustMeter > 0.2, "walking away from the car fills")
    run = E.newRun("vehicle", "standard", 0)
    for t = 0, 6000, 200 do at(t, p) end
    x = 0
    for t = 6200, 9000, 200 do x = x + 3; at(t, { x = x, y = 0, z = 0 }, { inCar = false }) end
    assert(run.bustMeter == 0, "54 km/h without a seat: in a car the server cannot see")

    -- Never boarded: armed only after the boarding grace.
    run = E.newRun("vehicle", "standard", 0)
    for t = 0, 14800, 200 do at(t, p, { inCar = false, boarded = false }) end
    assert(run.stars == 1 and run.bustMeter == 0 and not run.armed, "grace: not armed yet")
    at(15200, p, { inCar = false, boarded = false })
    assert(run.armed and run.bustMeter > 0, "armed after boardingGraceSeconds")

    -- On foot: walking pace counts as stopped, a run does not.
    run = E.newRun("foot", "hard", 0)
    for t = 0, 8000, 200 do E.step(run, t, { pos = p, down = false }) end
    assert(run.stars == 2 and run.armed, "Hard on foot: 2 stars after the 8 s head start")
    x = 0
    for t = 8200, 9600, 200 do x = x + 0.2; E.step(run, t, { pos = { x = x, y = 0, z = 0 }, down = false }) end
    assert(run.why == "stopped", "3.6 km/h on foot is stopped")
    for t = 9800, 12000, 200 do x = x + 1.2; E.step(run, t, { pos = { x = x, y = 0, z = 0 }, down = false }) end
    assert(run.why == nil and run.bustMeter < 0.5, "a run drains it")

    -- Blackout: frozen, then emptied; down; extraction; the clock.
    run = E.newRun("vehicle", "standard", 0)
    for t = 0, 8000, 200 do at(t, p) end
    local before = run.bustMeter
    for t = 8200, 10000, 200 do at(t, nil) end
    assert(run.bustMeter == before, "an unknown position freezes the meter")
    for t = 10200, 11600, 200 do at(t, nil) end
    assert(run.bustMeter == 0, "a long blackout empties it")
    outcome = at(11800, p, { down = true })
    assert(outcome.outcome == "runner_down", "down = busted at once")
    run = E.newRun("vehicle", "standard", 0)
    run.extraction = { position = { x = 100, y = 0, z = 0 }, radius = 15, zTolerance = 8 }
    assert(at(1000, { x = 90, y = 0, z = 2 }).outcome == "runner_extracted", "inside the extraction radius")
    run = E.newRun("vehicle", "standard", 0)
    x = 0
    for t = 0, 149800, 200 do x = x + 3; assert(at(t, { x = x, y = 0, z = 0 }) == nil, "moving: never busted") end
    assert(at(150000, { x = x + 3, y = 0, z = 0 }).outcome == "time_expired", "the clock")
    print("PASS escape rules")
end

-- ---------------------------------------------------------------- solo by car, Standard: busted

H.run(2)
H.fire("op77_lightrp:activity:join", 1, AID, { mode = "vehicle", difficulty = "standard" })
assert(env.qhud[1] and env.qhud[1].queued and env.qhud[1].difficultyLabel == "Standard", "getting ready (Standard)")
H.runUntil(function() return ChasePve.matchOf(1) ~= nil end, 4, "the escape starts")
local match = ChasePve.matchOf(1)
local enter
for _, c in ipairs(env.calls) do if c.name == "activityEnter" and c.args[1] == 1 then enter = c end end
assert(enter and enter.args[2] == AID and enter.args[3].difficulty == "standard", "activityEnter carries the difficulty")
assert(match.police == "ncpd" and match.difficulty == "standard" and match.copCount == 0, "no bot, the NCPD")
assert(H.count(ChaseBots.bots) == 0 and H.count(env.npcs) == 0, "not one bot")
local pop = env.population[match.bucket]
assert(pop and pop.crowd == 0.5 and pop.traffic == 1.0 and pop.police == true, "the instance gets crowd, traffic and police")
H.runUntil(function() return match.state == "active" end, 30, "GO")
assert(H.count(env.cars) == 1, "his own car only")
local carId = match.cars[1].id
env.seats[1] = carId
env.pos[1] = circling(ChasePve.member(match, 1).point.position, 40)
H.run(5)
assert(#wantedOps(1) == 0 and H.wanted(1).level == 0, "no wanted level during the head start")
assert(env.hud[1].headStartMs and env.hud[1].stars == 0, "the HUD counts the head start down")
H.run(1.5)
local ops = wantedOps(1)
assert(#ops >= 2 and ops[1].op == "max" and ops[1].level == 3 and ops[2].op == "set" and ops[2].level == 1, "ceiling first, then 1 star")
assert(H.wanted(1).level == 1 and H.wanted(1).maxLevel == 3, "the server holds 1 of 3")
assert(env.kvp["escape.wanted.1"] == "license:p1", "in the ledger, with his identifier")
H.runUntil(function() return H.wanted(1).level == 2 end, 31, "2 stars at +30 s")
H.runUntil(function() return H.wanted(1).level == 3 end, 46, "3 stars at +75 s")
assert(ChasePve.member(match, 1).boarded, "he sat in his car")
local sets = #wantedOps(1, "set")
H.run(16)
assert(#wantedOps(1, "set") > sets and H.wanted(1).level == 3, "the level is sent again (the engine may have dropped it)")
local hud = env.hud[1]
assert(hud.police == "ncpd" and hud.stars == 3 and hud.ceiling == 3 and hud.wanted == 3 and hud.difficultyLabel == "Standard", "HUD: the heat")
assert(hud.bustArmed and hud.bustMeter == 0 and hud.remainingMs > 0 and hud.extraction, "HUD: the bust meter, the clock, the extraction")
assert(H.noted(1, "Extraction point located"), "the extraction showed up")
dofile("client/view.lua")
local view = ChaseView.hud(hud)
local function stat(h, label) for _, s in ipairs(h.stats or {}) do if s.label == label then return s.value end end end
assert(view.title == "NCPD Escape" and view.subtitle == "Solo - Standard" and stat(view, "Wanted") == "★★★" and stat(view, "Heat") == "MAX",
    "the client draws the stars")
assert(view.progress and view.progress[1].id == "bust" and view.progress[1].value == 0, "the bust meter is on screen")
assert(view.scoreboard.columns[2] == "Heat" and #view.scoreboard.rows == 1, "runners only")
-- He stops.
env.pos[1] = env.pos[1](env.clock)
H.run(2)
assert(env.hud[1].bustWhy == "stopped" and env.hud[1].bustMeter > 0, "the meter fills")
assert(ChaseView.hud(env.hud[1]).objective:find("MOVE"), "the HUD tells him to move")
H.runUntil(function() return result(1) ~= nil end, 6, "busted")
local r = result(1)
assert(r.won == false and r.stats.outcome == "busted" and r.stats.how == "arrest" and r.stats.police == "ncpd", "busted for stopping")
assert(r.difficulty == "standard" and r.stats.stars == 3 and r.reputation == 6, "Standard busted: 6 rep, 3 stars")
-- Light RP's end-of-match recap: the runner, no cop; the stars reached, the result, the time.
local function line(recap, label) for _, l in ipairs(recap.lines) do if l.label == label then return l.value end end end
assert(r.recap and r.recap.detail == "NCPD Escape" and #r.recap.rows == 1 and r.recap.rows[1].id == 1 and r.recap.rows[1].outcome == "busted",
    "the runner on the recap")
assert(r.recap.rows[1].placement == 2 and r.recap.rows[1].timeMs == r.stats.seconds * 1000)
assert(line(r.recap, "Police") == "NCPD - Standard" and line(r.recap, "Stars reached") == "3 of 3" and line(r.recap, "Result") == "Busted - stopped"
    and line(r.recap, "Time") == ("%d:%02d"):format(r.stats.seconds // 60, r.stats.seconds % 60) and #r.recap.lines <= 8, "recap lines")
for _, l in ipairs(r.recap.lines) do assert(#l.label <= 32 and #l.value <= 64, "recap line limits") end
assert(cleared(1) and ledger() == 0, "stars 0, ceiling 5, out of the ledger, at once")
assert(H.noted(1, "You stopped: the NCPD cuffed you"), "told why")
assert(env.frozen[1] == true, "cuffed until he goes home")
closed(match)
assert(H.left(1, AID) and env.frozen[1] == false, "home")
assert(env.depopulated[#env.depopulated] == match.bucket, "the instance is empty again")
noCars()

-- ---------------------------------------------------------------- Hard: the extraction

match = start(2, "vehicle", "hard")
H.run(7)
assert(H.wanted(2).level == 2 and H.wanted(2).maxLevel == 4, "Hard: 2 stars at once, ceiling 4")
H.runUntil(function() return ChasePve.member(match, 2).run.extraction ~= nil end, 60, "the extraction at +55 s")
H.runUntil(function() return env.clock - match.startedAtMs >= 61000 end, 10, "past minSeconds")
env.pos[2] = ChasePve.member(match, 2).run.extraction.position
H.runUntil(function() return result(2) ~= nil end, 3, "extracted")
r = result(2)
assert(r.won and r.stats.how == "extraction" and r.reputation == 36 and r.difficulty == "hard", "Hard escape: 36 rep")
assert(line(r.recap, "Result") == "Escaped - extraction" and line(r.recap, "Stars reached") == "3 of 4" and r.recap.rows[1].escapes == 1
    and r.recap.rows[1].placement == 1, "recap: escaped at the extraction")
assert(cleared(2), "cleared")
closed(match)

-- ---------------------------------------------------------------- Critical: the clock, MaxTac

match = start(3, "vehicle", "critical")
H.runUntil(function() return H.wanted(3).level == 5 end, 110, "MaxTac")
assert(H.wanted(3).maxLevel == 5 and H.noted(3, "MaxTac"), "5 stars, told")
H.runUntil(function() return result(3) ~= nil end, 90, "the clock")
r = result(3)
assert(r.won and r.stats.how == "clock" and r.stats.seconds >= 179 and r.stats.stars == 5 and r.reputation == 60, "Critical clock: 60 rep")
assert(cleared(3), "cleared")
closed(match)

-- ---------------------------------------------------------------- down, out of the car, never boarding, a close call

match = start(4, "vehicle", "standard")
H.run(8)
env.alive[4] = false
H.runUntil(function() return result(4) ~= nil end, 2, "down")
assert(result(4).stats.how == "takedown" and result(4).reputation == 0 and cleared(4), "down = busted (under minSeconds: no rep), cleared")
closed(match)
assert(#env.respawned > 0, "respawned before going home")

match = start(5, "vehicle", "standard")
H.run(9)
env.seats[5] = nil
local m5 = ChasePve.member(match, 5).point.position
local t5 = env.clock
env.pos[5] = function(t) return { x = m5.x + (t - t5) / 1000, y = m5.y, z = m5.z } end -- walking away at 3.6 km/h
H.runUntil(function() return result(5) ~= nil end, 9, "out of the car")
assert(result(5).stats.how == "arrest" and H.noted(5, "You left your ride") and cleared(5), "busted out of his car")
closed(match)

match = start(6, "vehicle", "standard", { noSeat = true, still = true })
H.run(14)
assert(result(6) == nil and not ChasePve.member(match, 6).run.armed, "never in his car: the grace")
H.runUntil(function() return result(6) ~= nil end, 8, "busted after the grace")
assert(cleared(6))
closed(match)

match = start(7, "vehicle", "standard")
H.run(10)
local moving = env.pos[7]
env.pos[7] = moving(env.clock)
H.run(4.4) -- the 1 s speed window sees him stop after ~0.9 s: ~3.5 s of filling, 0.7
assert(ChasePve.member(match, 7).run.bustMeter >= 0.6 and result(7) == nil, "past the close-call mark, not busted")
env.pos[7] = circling(env.pos[7], 40)
H.runUntil(function() return ChasePve.member(match, 7).run.closeCalls == 1 end, 6, "a close call")
assert(H.noted(7, "Close call"), "told")
H.fire("op77_lightrp:activity:leaveRequest", 7, AID)
r = result(7)
assert(r.stats.forfeit and r.reputation == 0 and r.stats.shakes == 1, "a leaver: forfeit, nothing; the close call in the stats")
assert(cleared(7) and ledger() == 0, "a leave clears the level")
closed(match)

-- ---------------------------------------------------------------- every other way out

-- A drop while still connected (character switch): cleared, no result, no leave.
match = start(8, "vehicle", "standard")
H.run(8)
assert(H.wanted(8).level == 1)
env.owner[8] = nil
H.fire("op77_lightrp:activity:dropped", 8, AID, "character_changed")
assert(cleared(8) and result(8) == nil, "dropped: cleared, no result")
closed(match)
assert(not H.left(8, AID), "never activityLeave'd")

-- A bucket change away from the instance (a staff teleport home): cleared; the same bucket: kept.
match = start(9, "vehicle", "standard")
H.run(8)
H.fire("onPlayerBucketChange", "9", tostring(match.bucket), "0")
assert(H.wanted(9).level == 1, "the instance itself: kept")
H.fire("onPlayerBucketChange", "9", "0", tostring(match.bucket))
assert(cleared(9) and not ChasePolice.isRaised(9), "out of the instance: cleared")
H.fire("op77_lightrp:activity:leaveRequest", 9, AID)
closed(match)

-- Light RP stopping: void, cleared.
match = start(10, "vehicle", "standard")
H.run(8)
H.fire("onResourceStop", "op77_lightrp")
assert(match.void and cleared(10), "Light RP stopped: void and cleared")
closed(match)
H.fire("onResourceStart", "op77_lightrp")
H.run(3)

-- The resource stopping: the runtime refuses (resource_stopping), the ledger keeps him; the
-- next start clears him. A gone player's entry and a reused id's entry are dropped.
match = start(11, "vehicle", "standard")
H.run(8)
assert(H.wanted(11).level == 1)
env.wantedRefuse[11] = "resource_stopping"
H.fire("onResourceStop", "op77_chase")
assert(H.wanted(11).level == 1 and env.kvp["escape.wanted.11"], "refused while stopping: still raised, still in the ledger")
noCars()
local kvp, wanted = env.kvp, env.wanted
kvp["escape.wanted.12"] = "license:p12"         -- a player who left meanwhile
kvp["escape.wanted.3"] = "license:someone-else" -- the id now belongs to somebody else
env = H.load({ before = function(e)
    e.kvp, e.wanted = kvp, wanted
    e.connected[12] = false
end })
H.run(2)
assert(cleared(11), "the next start clears what the previous run left raised")
assert(next(env.kvp) == nil, "the ledger is empty again")
local touched3 = false
for _, w in ipairs(env.wantedLog) do if w.id == 3 or w.id == 12 then touched3 = true end end
assert(not touched3, "a gone player and a reused id are left alone")

-- ---------------------------------------------------------------- the police probe

-- the default is "void" (owner, 2026-11-03); "warn" is checked first, then "void" below
ChaseConfig.pve.onPoliceBlocked = "warn"
match = start(1, "vehicle", "standard")
H.run(7)
_G.source = 1
env.net["op77_chase:police"]({ expected = 1, requested = 0, suppressed = true, acknowledged = false, attached = true })
H.run(3)
assert(not ChasePve.member(match, 1).policeBlocked, "not after one report")
H.run(4)
assert(ChasePve.member(match, 1).policeBlocked and env.hud[1].policeBlocked, "refused for 6 s: blocked, on the HUD")
assert(H.noted(1, "Your game refused the NCPD") and match.state == "active", "warn: the run goes on")
assert(ChaseView.hud(env.hud[1]).objective, "drawn")
H.command("chase.pve.status", 0, {})
local text = env.replies[#env.replies].text
assert(text:find("wanted: 1=1/3 server 1/3 game 0 suppressed") and text:find("BLOCKED"), "staff status: ours, the server's, the game's")
H.fire("op77_lightrp:activity:leaveRequest", 1, AID)
closed(match)

env = H.load({ after = function() ChaseConfig.pve.onPoliceBlocked = "void" end })
H.run(2)
match = start(1, "vehicle", "standard")
H.run(7)
_G.source = 1
env.net["op77_chase:police"]({ expected = 1, requested = 1, suppressed = false, acknowledged = true })
H.run(8)
assert(match.state == "active", "a game that holds the level: nothing to say")
env.net["op77_chase:police"]({ expected = 1, requested = 0, suppressed = true })
H.runUntil(function() return match.state == "resolved" end, 8, "void")
assert(match.void and result(1) == nil and cleared(1), "void: called off, nothing counts, cleared")
closed(match)

-- ---------------------------------------------------------------- population refused, crews, tier gate, commands

env = H.load({ before = function(e) e.populationRefuse = "permission_denied:world.population" end })
H.run(2)
match = start(1, "vehicle", "standard")
assert(not match.populated, "population refused: the escape still runs, without traffic")
H.fire("op77_lightrp:activity:leaveRequest", 1, AID)
closed(match)
assert(#env.depopulated == 0, "nothing to empty")

-- A crew, together: one instance, each runner his own level.
local squad = { id = "squad:9", leader = 2, members = { 2, 3 } }
H.fire("op77_lightrp:activity:join", 2, AID, { mode = "vehicle", difficulty = "hard", squad = squad })
H.run(3)
assert(ChasePve.matchOf(2) == nil and env.qhud[2].crew == 2, "waits for the crew")
H.fire("op77_lightrp:activity:join", 3, AID, { mode = "foot", difficulty = "hard", squad = squad })
H.runUntil(function() return ChasePve.matchOf(2) ~= nil end, 3, "together")
match = ChasePve.matchOf(2)
assert(ChasePve.matchOf(3) == match and match.mode == "vehicle" and match.difficulty == "hard", "one instance, the leader's mode")
H.runUntil(function() return match.state == "active" end, 30, "crew GO")
env.seats[2], env.seats[3] = match.cars[2].id, match.cars[3].id
env.pos[2] = circling(ChasePve.member(match, 2).point.position, 40)
env.pos[3] = circling(ChasePve.member(match, 3).point.position, 40, 80)
H.run(8)
assert(H.wanted(2).level == 2 and H.wanted(3).level == 2, "each runner his own wanted level")
env.alive[3] = false
H.runUntil(function() return result(3) ~= nil end, 2, "runner 3 down")
assert(cleared(3) and H.wanted(2).level == 2 and match.state == "active", "only his level comes down, the other runs on")
do
    local recap = result(3).recap
    local values = {}
    for _, l in ipairs(recap.lines) do values[#values + 1] = l.value end
    local all = table.concat(values, "|")
    assert(#recap.rows == 2 and line(recap, "Police") == "NCPD - Hard" and line(recap, "Stars reached") == "2 of 4", "crew recap")
    assert(all:find("Busted %- down %- 2★ %- 0:%d%d") and all:find("Still running %- 2★"), "a line per runner: " .. all)
end
H.fire("op77_lightrp:activity:leaveRequest", 2, AID)
closed(match)
assert(cleared(2))

-- A crew, solo: one instance each, started together.
env = H.load({ after = function() ChaseConfig.pve.crews = "solo" end })
H.run(2)
squad = { id = "squad:10", leader = 4, members = { 4, 5 } }
H.fire("op77_lightrp:activity:join", 4, AID, { mode = "vehicle", difficulty = "critical", squad = squad })
H.fire("op77_lightrp:activity:join", 5, AID, { mode = "vehicle", difficulty = "critical", squad = squad })
H.runUntil(function() return ChasePve.matchOf(4) ~= nil and ChasePve.matchOf(5) ~= nil end, 4, "two instances")
assert(ChasePve.matchOf(4) ~= ChasePve.matchOf(5) and ChasePve.matchOf(4).bucket ~= ChasePve.matchOf(5).bucket, "one instance each")
assert(ChasePve.matchOf(5).difficulty == "critical", "the crew's difficulty")
H.fire("op77_lightrp:activity:leaveRequest", 4, AID)
H.fire("op77_lightrp:activity:leaveRequest", 5, AID)
H.run(2)

-- The tier gate: Light RP refuses a difficulty above his tier (the core's sentence).
env.tierRefuse[6] = { critical = "Critical needs Known street cred." }
H.command("escape", 6, { "critical" })
assert(env.replies[#env.replies].ok == false and env.replies[#env.replies].text == "Critical needs Known street cred.", "/escape critical refused")
local check
for _, c in ipairs(env.calls) do if c.name == "activityCheck" and c.args[1] == 6 then check = c end end
assert(check and check.args[3].difficulty == "critical", "activityCheck carries the difficulty")
H.command("escape", 6, { "foot", "hard" })
assert(env.replies[#env.replies].ok and ChasePveMain.queue.entries[1].difficulty == "hard" and ChasePveMain.queue.entries[1].mode == "foot",
    "/escape foot hard")
H.runUntil(function() return ChasePve.matchOf(6) ~= nil end, 5, "started from the command")
assert(ChasePve.matchOf(6).difficulty == "hard" and ChasePve.matchOf(6).mode == "foot")
H.command("escape", 6, { "status" })
assert(env.replies[#env.replies].text:find("Hard") and env.replies[#env.replies].text:find("the NCPD"), "/escape status")
H.command("escape", 6, { "leave" })
H.command("escape", 7, { "fly" })
assert(env.replies[#env.replies].ok == false and env.replies[#env.replies].text:find("usage"), "usage")
H.command("escape", 7, { "car", "insane" })
assert(env.replies[#env.replies].ok == false, "an unknown difficulty")
H.command("escape", 7, { "hardcore", "car" })
assert(env.replies[#env.replies].ok and ChasePveMain.queue.entries[1].difficulty == "critical", "aliases, any order")
H.command("escape", 7, { "leave" })
-- One chase activity at a time.
H.fire("op77_lightrp:activity:join", 8, AID, { mode = "vehicle" })
H.fire("op77_lightrp:activity:join", 8, "chase.1v1", { mode = "vehicle" })
assert(H.noted(8, "NCPD Escape") and not ChaseQueue.has(8), "the 1v1 refuses a player in NCPD Escape")
H.command("escape", 8, { "leave" })
H.run(2)

-- Staff stop: void.
match = start(9, "vehicle", "standard")
H.run(8)
H.command("chase.pve.stop", 0, { tostring(match.id) })
assert(env.commands["chase.pve.stop"].restricted and match.void and cleared(9), "staff stop: void, cleared")
closed(match)
assert(result(9) == nil)
H.run(6)
local status
for _, e in ipairs(H.events("op77_lightrp:activity:status")) do if e.args[1] == AID then status = e.args[2] end end
assert(status and status.phase == "idle" and status.joinable and status.detail:find("against the NCPD"), "hub status")

-- ---------------------------------------------------------------- reputation rules

do
    local P = ChasePve
    P.daily, P.dailyDay = {}, nil
    local runner = { id = 50, identifier = "license:x", characterKey = 2, outcome = "busted", seconds = 59 }
    assert(P.reputation({ difficulty = "critical" }, runner) == 0, "under minSeconds: nothing")
    runner.outcome, runner.seconds = "escaped", 100
    local rep = ChaseConfig.pve.reputation
    for i = 1, rep.perDay + 1 do
        local got = P.reputation({ difficulty = "standard" }, runner)
        if i <= rep.perDay then assert(got == rep.escaped) else assert(got == 0, "past perDay: nothing") end
    end
    P.daily = {}
    assert(P.reputation({ difficulty = "hard" }, runner) == 36 and P.reputation({ difficulty = "critical" }, runner) == 60, "x2, x3.33")
    runner.outcome = "busted"
    assert(P.reputation({ difficulty = "critical" }, runner) == 20, "busted on Critical")
    assert(P.reputation({}, { id = 51, outcome = "left", seconds = 120 }) == 0, "a leaver: nothing")
    assert(rep.escaped < ChaseConfig.reputation.win and rep.busted < ChaseConfig.reputation.loss, "Standard pays less than the PvP chase")
end

assert(#env.db == 0, "NCPD Escape never touches the database")
for _, e in ipairs(H.results()) do assert(e.args[3].test == nil, "never a test result") end
print("PASS NCPD Escape (police = ncpd)")

-- ════════════════════════════════════════════════════════════════ police = "bots"

local function copsOf(m)
    local out = {}
    for _, x in ipairs(m.members) do if x.bot then out[#out + 1] = x.id end end
    return out
end
local function attached(m)
    for _, c in ipairs(copsOf(m)) do
        local bot = ChaseBots.bots[c]
        if not (bot and bot.attached) then return false end
    end
    return true
end
local function noTraces()
    assert(H.count(ChaseBots.bots) == 0, "every bot removed")
    assert(H.count(env.npcs) == 0, "every body removed")
    noCars()
end
local BOTS = function() ChaseConfig.pve.police = "bots" end

env = H.load({ after = BOTS })
H.run(6) -- past the bots' settle window
H.fire("op77_lightrp:activity:join", 1, AID, { mode = "vehicle" })
H.runUntil(function() return ChasePve.matchOf(1) ~= nil end, 4, "the bot escape starts")
match = ChasePve.matchOf(1)
assert(match.police == "bots" and match.copCount == 3 and #copsOf(match) == 3, "1 runner: base 1 + 2 per runner = 3 cops")
assert(env.population[match.bucket] == nil, "the bot escape stays empty")
for j, c in ipairs(copsOf(match)) do
    assert(ChasePve.member(match, c).point == match.route.cops[#match.route.cops - j + 1], "cops from the front of the grid")
end
H.runUntil(function() return match.state == "active" and attached(match) end, 30, "GO")
assert(H.count(env.cars) == 4, "his own car and the three cop cars")
local rp = env.pos[1]
for i, c in ipairs(copsOf(match)) do H.moveCar(H.botCar(c), H.offset(rp, i * 6, 200)) end
H.run(11)
assert(H.count(match.copReleased) == 2, "wave 1 after the head start")
H.runUntil(function() return #H.aiCalls("vehicles.ai.chase", function(a) return a[2].targetId == 1 end) >= 2 end, 5, "they chase him")
H.runUntil(function() return env.clock - match.startedAtMs >= 65000 end, 60, "past minSeconds")
H.moveCar(H.botCar(copsOf(match)[1]), H.offset(rp, 4, 0))
H.runUntil(function() return result(1) ~= nil end, 30, "busted on the bot car's position")
r = result(1)
assert(r.stats.how == "arrest" and r.stats.police == "bots" and r.reputation == ChaseConfig.pve.reputation.busted, "busted by the bots")
assert(r.recap and #r.recap.rows == 1 and r.recap.rows[1].id == 1 and r.recap.rows[1].outcome == "busted", "the runner on the recap, no cop car")
assert(r.recap.lines[1].label == "NCPD units" and r.recap.lines[1].value == "3" and r.recap.rows[1].timeMs == r.stats.seconds * 1000)
assert(#env.wantedLog == 0, "no wanted level with the bots")
closed(match)
assert(H.left(1, AID))
noTraces()

env = H.load({ after = BOTS, before = function() _G.Open77.npcs = nil; _G.Open77.vehicles.ai = nil end })
H.fire("op77_lightrp:activity:join", 1, AID, { mode = "vehicle" })
H.runUntil(function() return ChasePve.matchOf(1) ~= nil end, 6, "match")
match = ChasePve.matchOf(1)
H.runUntil(function() return match.state == "resolved" end, 30, "called off")
assert(match.void and result(1) == nil, "broken bots: nothing counts")
closed(match)
noTraces()

env = H.load({ after = BOTS })
H.run(6)
H.fire("op77_lightrp:activity:join", 2, AID, { mode = "vehicle" })
H.runUntil(function() return ChasePve.matchOf(2) ~= nil end, 4, "match")
match = ChasePve.matchOf(2)
H.runUntil(function() return match.state == "active" and attached(match) end, 30, "GO")
assert(H.count(env.cars) == 4 and H.count(env.npcs) == 3)
H.fire("onResourceStop", "op77_chase")
assert(H.count(env.cars) == 0 and H.count(env.npcs) == 0, "resource stop: cars and bodies removed")
assert(#env.db == 0)

print("PASS: op77_chase NCPD Escape (ncpd: PvE registration + botFill=false; heat ramp 3/4/5, bust meter stopped / out of car / grace / "
    .. "drain / close call / blackout, down, extraction, clock; Standard busted with ceiling-first ramp, re-sent level, HUD + view, "
    .. "6 rep; Hard extraction 36; Critical clock + MaxTac 60; cleared on bust/escape/leave/drop/bucket change/Light RP stop/"
    .. "resource stop + next-start sweep; police probe warn/void; population refused; crews together/solo; tier gate; /escape "
    .. "mode+difficulty; staff status/stop; reputation x difficulty. bots: grid, waves, arrest, no wanted, broken = void, stop)")
