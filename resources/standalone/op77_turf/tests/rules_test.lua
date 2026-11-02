-- op77_turf rules: gang keys, sides and mercenaries, late joiners, capture, contest,
-- score, respawn points, bounds, rewards, influence, weeks.
-- Run: pwsh -NoProfile -File tests/run-lua.ps1 -LuaDll <lua54.dll> -Test rules_test.lua
dofile("shared/config.lua")
dofile("server/rules.lua")
local R = TurfRules
local CFG = TurfConfig

local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end
local function ids(list) table.sort(list); return table.concat(list, ",") end

-- ---------------------------------------------------------------- gang keys
do
    assert(R.gangKey({ id = "Valentinos" }) == "valentinos", "activityPlayer's { id }")
    assert(R.gangKey({ name = "tyger_claws" }) == "tyger_claws", "a { name } view")
    assert(R.gangKey(" maelstrom ") == "maelstrom")
    assert(R.gangKey("none") == nil and R.gangKey("") == nil and R.gangKey("unaffiliated") == nil and R.gangKey(nil) == nil)
    assert(R.gangKey("bad key!") == nil and R.gangKey(42) == nil, "junk is unaffiliated")
    local info = R.gangInfo("valentinos", nil, CFG.gangs)
    assert(info.label == "Valentinos" and info.color == "#D9A441")
    info = R.gangInfo("valentinos", { label = "Los Valentinos", color = "#112233" }, CFG.gangs)
    assert(info.label == "Los Valentinos" and info.color == "#112233", "the view's label and colour win")
    info = R.gangInfo("iron_wolves", nil, CFG.gangs)
    assert(info.label == "Iron wolves" and info.color == "#C9CED6", "an unknown gang still has a name and a colour")
    assert(R.gangInfo(nil) == nil)
end

-- ---------------------------------------------------------------- sides
local function entry(id, gang, at) return { id = id, gang = gang, at = at or id } end

do
    -- The two most represented gangs; ties by who queued first.
    local g1, g2 = R.topGangs({ entry(1, "a", 5), entry(2, "b", 1), entry(3, "a", 6), entry(4, "c", 2), entry(5, "b", 7) })
    assert(g1 == "b" and g2 == "a", "two each: b queued first")
    g1, g2 = R.topGangs({ entry(1, nil), entry(2, "x") })
    assert(g1 == "x" and g2 == nil)
end

do
    -- 3 Valentinos + 3 Maelstrom + 2 others: 4 v 4, the others are mercenaries.
    local list = { entry(1, "valentinos"), entry(2, "valentinos"), entry(3, "valentinos"), entry(4, "maelstrom"),
        entry(5, "maelstrom"), entry(6, "maelstrom"), entry(7, nil), entry(8, "tyger_claws") }
    local f = R.formSides(list, { maxPlayers = 24, maxImbalance = 1 })
    assert(f.gangs[1] == "valentinos" and f.gangs[2] == "maelstrom")
    assert(#f.sides[1] == 4 and #f.sides[2] == 4, "balanced")
    assert(ids(f.sides[1]) == "1,2,3,7" and ids(f.sides[2]) == "4,5,6,8", ids(f.sides[1]) .. " / " .. ids(f.sides[2]))
    assert(f.merc[7] and f.merc[8] and not f.merc[1] and not f.merc[4], "only the outsiders are mercenaries")
    assert(#f.bench == 0)
end

do
    -- 5 Valentinos vs 1 Maelstrom and 2 free: the mercenaries fill the small side, the
    -- crew's surplus waits (balance within 1).
    local list = { entry(1, "valentinos"), entry(2, "valentinos"), entry(3, "valentinos"), entry(4, "valentinos"),
        entry(5, "valentinos"), entry(6, "maelstrom"), entry(7, nil), entry(8, nil) }
    local f = R.formSides(list, { maxImbalance = 1 })
    assert(#f.sides[2] == 3 and ids(f.sides[2]) == "6,7,8", ids(f.sides[2]))
    assert(#f.sides[1] == 4, "4 v 3: within one")
    assert(ids(f.bench) == "5", "the last Valentino waits as a reinforcement")
    -- Turncoats allowed: he signs on with the other side as a mercenary.
    f = R.formSides(list, { maxImbalance = 1, allowTurncoats = true })
    assert(#f.sides[1] == 4 and #f.sides[2] == 4 and f.merc[5] and #f.bench == 0)
end

do
    -- No gang at all: two free sides, everyone a mercenary, alternating by queue order.
    local f = R.formSides({ entry(1), entry(2), entry(3), entry(4), entry(5) })
    assert(f.gangs[1] == nil and f.gangs[2] == nil)
    assert(#f.sides[1] == 3 and #f.sides[2] == 2 and ids(f.sides[1]) == "1,3,5")
    for id = 1, 5 do assert(f.merc[id]) end
    -- One crew alone (2 players): one side only unless turncoats are allowed.
    f = R.formSides({ entry(1, "animals"), entry(2, "animals") })
    assert(#f.sides[1] == 1 and #f.sides[2] == 0, "a lone crew does not split by itself")
    f = R.formSides({ entry(1, "animals"), entry(2, "animals") }, { allowTurncoats = true })
    assert(#f.sides[1] == 1 and #f.sides[2] == 1 and f.merc[2], "training war: one turncoat")
end

do
    -- The cap: 30 queued, 24 fight, the rest wait.
    local list = {}
    for i = 1, 30 do list[i] = entry(i, i % 2 == 0 and "a" or "b") end
    local f = R.formSides(list, { maxPlayers = 24 })
    assert(#f.sides[1] + #f.sides[2] == 24 and #f.bench == 6)
end

do
    -- Late joiners: their own side when the balance allows, mercenaries to the smaller side.
    local gangs = { "valentinos", "maelstrom" }
    local s, merc = R.placeLate({ 4, 4 }, gangs, "valentinos", {})
    assert(s == 1 and merc == false)
    s = R.placeLate({ 5, 4 }, gangs, "valentinos", {})
    assert(s == nil, "his side is ahead: he waits")
    s, merc = R.placeLate({ 5, 4 }, gangs, "valentinos", { allowTurncoats = true })
    assert(s == 2 and merc == true)
    s, merc = R.placeLate({ 5, 4 }, gangs, nil, {})
    assert(s == 2 and merc == true, "a mercenary to the smaller side")
    s, merc = R.placeLate({ 4, 4 }, gangs, "animals", {})
    assert(s == 1 and merc == true)
    assert(R.placeLate({ 12, 12 }, gangs, nil, { maxPlayers = 24 }) == nil, "full")
end

-- ---------------------------------------------------------------- capture
local CAP = { seconds = 15, perExtraAttacker = 0.5, maxAttackers = 3, decayPerSecond = 0.05 }
local SITE = CFG.sites[1]

do
    assert(near(R.captureRate(1, CAP), 1 / 15))
    assert(near(R.captureRate(2, CAP), 1.5 / 15))
    assert(near(R.captureRate(3, CAP), 2 / 15))
    assert(near(R.captureRate(8, CAP), 2 / 15), "capped at three attackers")
    assert(R.captureRate(0, CAP) == 0)
end

do
    -- One attacker takes a neutral zone in 15 s, two in 10 s.
    local zones = R.newZones(SITE)
    local z = zones[1]
    local ev
    for _ = 1, 14 do ev = R.stepZone(z, { 1, 0 }, 1, CAP); assert(ev == nil) end
    assert(z.capturing == 1 and near(z.progress, 14 / 15))
    ev = R.stepZone(z, { 1, 0 }, 1, CAP)
    assert(ev and ev.kind == "captured" and ev.side == 1 and ev.previous == nil and ev.zone == "A")
    assert(z.owner == 1 and z.capturing == nil and z.progress == 0)

    local z2 = R.newZones(SITE)[2]
    for i = 1, 10 do ev = R.stepZone(z2, { 0, 2 }, 1, CAP); if i < 10 then assert(ev == nil) end end
    assert(ev and ev.side == 2 and z2.owner == 2, "two attackers: 10 s")
end

do
    -- Contested: frozen. The enemy's half-capture is wound back first. Owner alone clears it.
    local z = R.newZones(SITE)[1]
    z.owner = 1
    for _ = 1, 6 do R.stepZone(z, { 0, 1 }, 1, CAP) end
    assert(z.capturing == 2 and near(z.progress, 6 / 15))
    local before = z.progress
    assert(R.stepZone(z, { 2, 1 }, 1, CAP) == nil and z.contested and near(z.progress, before), "contested = frozen")
    R.stepZone(z, { 1, 0 }, 3, CAP)
    assert(z.owner == 1 and near(z.progress, 3 / 15) and z.capturing == 2, "the owner back alone winds it down")
    R.stepZone(z, { 1, 0 }, 5, CAP)
    assert(z.progress == 0 and z.capturing == nil)

    -- A side reverses the other's progress before building its own.
    local n = R.newZones(SITE)[3]
    for _ = 1, 3 do R.stepZone(n, { 1, 0 }, 1, CAP) end
    assert(n.capturing == 1 and near(n.progress, 3 / 15))
    R.stepZone(n, { 0, 1 }, 5, CAP)
    assert(n.capturing == 2 and near(n.progress, 2 / 15), "3/15 wound back, then 2/15 for side 2")

    -- Abandoned: fades.
    R.stepZone(n, { 0, 0 }, 1, CAP)
    assert(near(n.progress, 2 / 15 - 0.05))
    R.stepZone(n, { 0, 0 }, 10, CAP)
    assert(n.progress == 0 and n.capturing == nil)

    -- A held zone flips straight to the attacker (no neutral stop).
    local h = R.newZones(SITE)[2]
    h.owner = 2
    local ev
    for _ = 1, 15 do ev = R.stepZone(h, { 1, 0 }, 1, CAP) or ev end
    assert(ev and ev.side == 1 and ev.previous == 2 and h.owner == 1)
end

do
    -- In a zone: radius in the plane, a vertical band.
    local def = { x = 0, y = 0, z = 10, radius = 6 }
    assert(R.inZone(def, { x = 3, y = 4, z = 10 }, 3.5))
    assert(not R.inZone(def, { x = 5, y = 4, z = 10 }, 3.5))
    assert(not R.inZone(def, { x = 0, y = 0, z = 14 }, 3.5), "a deck above does not count")
    assert(R.inZone(def, { x = 0, y = 0 }, 3.5), "no z: the plane decides")
    assert(not R.inZone(def, nil))
end

-- ---------------------------------------------------------------- score
do
    local war = { zones = R.newZones(SITE), sides = { { score = 0 }, { score = 0 } } }
    war.zones[1].owner, war.zones[2].owner = 1, 1
    war.zones[3].owner = 2
    local scoring = { pointsPerZonePerSecond = 1 }
    for _ = 1, 4 do assert(R.stepScore(war, 0.25, scoring, 900) == nil) end
    assert(war.sides[1].score == 2 and war.sides[2].score == 1, "fractional steps carry over")
    war.sides[1].score = 899
    assert(R.stepScore(war, 1, scoring, 900) == 1)
    war.sides[1].score, war.sides[2].score = 899, 899
    war.zones[1].owner, war.zones[2].owner, war.zones[3].owner = 1, 2, nil
    war.carry = { 0, 0 }
    assert(R.stepScore(war, 1, scoring, 900) == 0, "both reach it level: a draw")

    war.sides[1].score, war.sides[2].score = 300, 280
    assert(R.timeWinner(war) == 1)
    war.sides[2].score = 300
    war.zones[1].owner, war.zones[2].owner, war.zones[3].owner = 2, 2, 1
    assert(R.timeWinner(war) == 2, "level: more zones held")
    war.zones[3].owner = nil
    war.zones[2].owner = nil
    war.zones[1].owner = nil
    assert(R.timeWinner(war) == 0)
end

-- ---------------------------------------------------------------- respawn points
do
    local life = { respawnAtZones = true, zoneSpawnOffset = 1.5 }
    local war = { zones = R.newZones(SITE) }
    local p, zone = R.respawnPoint(war, SITE, 1, 1, { x = -1220, y = 2020, z = 7.8 }, life)
    assert(zone == nil and p.x == SITE.spawns[1].points[1].x, "nothing held: the side's spawn")
    p = R.respawnPoint(war, SITE, 1, 2, nil, life)
    assert(p.x == SITE.spawns[1].points[2].x, "slot 2: second spawn point")
    p = R.respawnPoint(war, SITE, 1, 3, nil, life)
    assert(p.x == SITE.spawns[1].points[1].x, "round robin")

    war.zones[1].owner, war.zones[3].owner = 1, 1
    p, zone = R.respawnPoint(war, SITE, 1, 1, { x = -1220, y = 2045, z = 7.8 }, life)
    assert(zone == "C", "the held zone nearest to the death")
    local dx, dy = p.x - SITE.zones[3].x, p.y - SITE.zones[3].y
    assert(near(math.sqrt(dx * dx + dy * dy), 1.5, 1e-3), "on the ring around the zone")
    assert(p.heading >= 0 and p.heading < 360)

    war.zones[3].contested = true
    p, zone = R.respawnPoint(war, SITE, 1, 1, { x = -1220, y = 2045, z = 7.8 }, life)
    assert(zone == "A", "a contested zone is no spawn")
    war.zones[1].capturing, war.zones[1].progress = 2, 0.3
    p, zone = R.respawnPoint(war, SITE, 1, 1, { x = -1220, y = 2045, z = 7.8 }, life)
    assert(zone == nil, "an enemy capture running: no spawn there")
    p, zone = R.respawnPoint(war, SITE, 1, 1, { x = -1220, y = 2045, z = 7.8 }, { respawnAtZones = false })
    assert(zone == nil)

    local after = CFG.sites[3]
    local w2 = { zones = R.newZones(after) }
    w2.zones[2].owner = 1
    p, zone = R.respawnPoint(w2, after, 1, 1, { x = after.zones[2].x, y = after.zones[2].y }, life)
    assert(zone == nil, "spawnable = false keeps an interior out")

    assert(near(R.headingTo({ x = 0, y = 0 }, { x = 0, y = 10 }), 0))
    assert(near(R.headingTo({ x = 0, y = 0 }, { x = -10, y = 0 }), 90))
end

do
    local bounds = SITE.bounds
    assert(R.inBounds(bounds, { x = bounds.center.x + 10, y = bounds.center.y }))
    assert(not R.inBounds(bounds, { x = bounds.center.x + bounds.radius + 1, y = bounds.center.y }))
    assert(R.inBounds(bounds, nil), "unknown position: never punished")
end

-- ---------------------------------------------------------------- rewards and influence
local REW = CFG.rewards
local function member(id, side, ident, extra)
    local m = { id = id, side = side, identifier = ident, captures = 0, kills = 0, deaths = 0, holdSeconds = 0, playedMs = 600000 }
    for k, v in pairs(extra or {}) do m[k] = v end
    return m
end

do
    local war = { playedMs = 600000, members = {
        [1] = member(1, 1, "acc1"), [2] = member(2, 1, "acc2"), [3] = member(3, 2, "acc3"), [4] = member(4, 2, "acc4") } }
    assert(R.counted(war, REW, 4))
    assert(not R.counted(war, REW, 5), "too few accounts")
    war.members[4].identifier = "acc1"
    assert(not R.counted(war, REW, 4), "two characters of one account count once")
    war.members[4].identifier = "acc4"
    war.playedMs = 100000
    assert(not R.counted(war, REW, 4), "too short")
    war.playedMs = 600000
    war.void = true
    assert(not R.counted(war, REW, 4))
    war.void = nil

    local m = member(1, 1, "a", { captures = 3, kills = 9 })
    assert(R.reputation(m, war, 1, REW, true) == 30 + 10, "win + capped bonus")
    assert(R.reputation(m, war, 2, REW, true) == 12 + 10)
    assert(R.reputation(member(2, 1, "b", { kills = 2 }), war, 0, REW, true) == 18 + 2, "draw")
    assert(R.reputation(m, war, 1, REW, false) == 0, "a war that did not count")
    assert(R.reputation(member(3, 1, "c", { left = true }), war, 1, REW, true) == 0, "a leaver")
    assert(R.reputation(member(4, 1, "d", { playedMs = 60000 }), war, 1, REW, true) == 0, "a late joiner who barely played")
    assert(R.personalScore({ captures = 2, kills = 3, holdSeconds = 51 }, CFG.scoring) == 40 + 9 + 10)
end

do
    local war = { sides = { { gang = "valentinos" }, { gang = "maelstrom" } }, members = {
        [1] = member(1, 1, "a", { gang = "valentinos", captures = 4 }),
        [2] = member(2, 1, "b", { gang = "valentinos", captures = 9 }),
        [3] = member(3, 1, "c", { gang = nil, merc = true, captures = 5 }),
        [4] = member(4, 2, "d", { gang = "maelstrom", captures = 1 }),
        [5] = member(5, 2, "e", { gang = "animals", merc = true, captures = 2 }) } }
    local d = R.influence(war, 1, CFG.influence)
    assert(d.valentinos.points == 10 + 10 and d.valentinos.wins == 1 and d.valentinos.captures == 13,
        "win + captures capped at 10; the mercenary's captures do not count")
    assert(d.maelstrom.points == 2 + 1 and d.maelstrom.wins == 0 and d.maelstrom.wars == 1)
    assert(d.animals == nil, "a mercenary's own gang earns nothing")
    d = R.influence(war, 0, CFG.influence)
    assert(d.valentinos.points == 5 + 10 and d.maelstrom.points == 5 + 1)
    war.sides[2].gang = nil
    d = R.influence(war, 2, CFG.influence)
    assert(d.maelstrom == nil and d.valentinos.points == 2 + 10, "a free side earns no influence")
end

do
    -- Weeks start Monday 00:00 UTC.
    local monday = 1793577600 -- 2026-11-02 00:00:00 UTC, a Monday
    local w = R.weekIndex(monday)
    assert(R.weekIndex(monday - 1) == w - 1, "Sunday 23:59:59 is the week before")
    assert(R.weekIndex(monday + 7 * 86400 - 1) == w)
    assert(R.weekStart(w) == monday)
    assert(R.clock(65000) == "1:05" and R.clock(0) == "0:00")
end

print("PASS rules_test: gangs, sides + mercenaries + bench, late joiners, capture + contest + decay, score + carry, respawn points, bounds, rewards, influence, weeks")
