-- Gun Game: rules lifted from the source mode, on the engine.
-- Run: lua tests/gungame_test.lua
local H = dofile("tests/harness.lua")

-- The platform's dash, as far as the mode reads it.
H.dash, H.dashLog = {}, {}
Open77.dash = {
    define = function(def) H.dashLog[#H.dashLog + 1] = { "define", def.id } return { ok = true } end,
    grant = function(id, definition)
        H.dashLog[#H.dashLog + 1] = { "grant", id, definition }
        if H.dash[id] == "theirs" then return nil, "grant_owned" end
        H.dash[id] = "ours"
        return { ok = true }
    end,
    revoke = function(id)
        H.dashLog[#H.dashLog + 1] = { "revoke", id }
        if H.revokeRefused and H.revokeRefused > 0 then
            H.revokeRefused = H.revokeRefused - 1
            return nil, "invalid_operation"
        end
        if H.dash[id] == "ours" then H.dash[id] = nil end
        return { ok = true }
    end,
    current = function(id)
        local holder = H.dash[id]
        if holder == nil then return nil end
        return { ownedByCaller = holder == "ours", projection = { status = "ready" } }
    end,
}

H.loadServer()
H.advance(200)
local E, G = GamesEngine, GamesGungame
local R = G.rules
local KNIFE = H.hash(G.knife)
local TOP = #R.ladder

local function gun(step) return H.hash(R.ladder[step].record) end

local nextId = 0
local function players(n)
    local ids = {}
    for _ = 1, n do
        nextId = nextId + 1
        H.addPlayer(nextId)
        ids[#ids + 1] = nextId
    end
    return ids
end

local function live(n, map)
    local ids = players(n)
    H.matchJoin("games.gungame", ids, { map = map })
    return H.untilPhase(ids[1], "running"), ids
end

local function stepOf(match, id) return match.players[id].gg.step end

local function revive(id)
    H.settle(2600)
    H.ok(H.players[id].life == "alive", "back")
    H.settle(2100) -- past the protection, armed again
end

-- A clean shot and the death it causes.
local function kill(match, killer, victim, weapon, kind)
    H.eq(H.hit(killer, victim, weapon or gun(stepOf(match, killer)), { attackKind = kind or "ranged" }), true, "the shot lands")
    H.die(victim, killer)
    H.settle(100)
end

local function lastResults()
    local byId = {}
    for _, e in ipairs(H.eventsNamed("op77_lightrp:activity:result")) do byId[e.args[1]] = e.args[3] end
    return byId
end

H.test("the activity: registered, three maps, 14 steps ending on the knife", function()
    local def = H.ok(H.core.registered["games.gungame"], "registered")
    H.eq(def.kind, "pvp")
    H.eq(def.modeKey, "map")
    H.eq(#def.modes, 3)
    H.eq(def.modes[1].id, "hotel")
    H.eq(TOP, 14)
    H.eq(R.ladder[1].name, "Lexington")
    H.eq(R.ladder[14].melee, true)
    H.eq(R.ladder[14].record, G.knife)
    for step, entry in ipairs(R.ladder) do
        H.ok(entry.record:match("^Items%.Preset_[%w_]+_Default$"), "a record")
        if not entry.melee then H.ok(entry.reserve > 0, "a reserve for step " .. step) end
    end
end)

H.test("every map: spawns inside the play area, each with a heading", function()
    for _, map in ipairs(H.mapsOf("gungame")) do
        H.ok(map.id:match("^[a-z0-9%-]+$"), "a slug")
        H.ok(#map.spawns >= 2, "spawns")
        for _, spawn in ipairs(map.spawns) do
            H.ok(E.distance(spawn, map.centre) <= map.radius, map.id .. ": a spawn out of bounds")
            H.ok(type(spawn.heading) == "number", "heading")
        end
    end
end)

H.test("the ladder's first weapon is in hand before GO, alone (no knife beside it)", function()
    local match, ids = live(2)
    H.eq(H.weapons[ids[1]][1], "Items.Preset_Lexington_Default")
    H.eq(H.weapons[ids[1]][2], nil, "no knife in an idle slot: it blinded every weapon snapshot")
    H.eq(H.weapons[ids[1]][3], nil)
    H.eq(match.players[ids[1]].plan, G.sets[1])
    E.cancel(match)
    H.settle(500)
end)

H.test("a kill climbs one step and hands the next weapon at once", function()
    local match, ids = live(2)
    local a, b = ids[1], ids[2]
    kill(match, a, b)
    H.eq(stepOf(match, a), 2)
    H.eq(stepOf(match, b), 1, "the victim keeps theirs")
    H.settle(400)
    H.eq(H.weapons[a][1], "Items.Preset_Nova_Default", "the next weapon")
    H.eq(H.weapons[a][2], nil, "alone")
    H.eq(H.hit(a, b, gun(2)), false, "b is still down")
    E.cancel(match)
    H.settle(500)
end)

H.test("the ladder: every step is an explicit kit, handed at once, the old hand's word worth nothing", function()
    local match, ids = live(2)
    local a, b = ids[1], ids[2]
    local p = match.players[a]
    for step, entry in ipairs(R.ladder) do
        local kit = G.sets[step]
        H.eq(kit.primary, entry.record, "the step's one weapon, in hand")
        H.eq(kit.label, entry.name)
        H.eq(kit.secondary, nil, "one weapon per step, no knife beside it")
        if entry.melee then
            H.eq(kit.reserve, nil, "a knife holds no rounds")
        else
            H.eq(kit.reserve[1], entry.reserve)
        end
    end
    H.eq(H.coreCalls("activityKit", a)[1].args[3], G.sets[1], "the first step, handed on landing")
    for step = 1, #R.ladder - 1 do
        local hand = H.kits[a].hand
        local before = #H.coreCalls("activityKit", a)
        local old = H.kits[a]
        kill(match, a, b, nil)
        H.eq(stepOf(match, a), step + 1)
        H.eq(#H.coreCalls("activityKit", a), before + 1, "re-handed once")
        local call = H.coreCalls("activityKit", a)[before + 1]
        H.eq(call.args[3], G.sets[step + 1], "the next step's kit")
        H.eq(call.args[4].immediate, true, "mid-fight: no landing wait")
        H.ok(H.kits[a].hand ~= hand, "a new hand")
        H.eq(H.weapons[a][1], R.ladder[step + 1].record)
        H.kitReport(a, old, "armed")
        H.settle(100) -- the new hand reports
        H.eq(p.plan, G.sets[step + 1])
        H.eq(H.hit(a, b, gun(step)), false, "the last step's gun is dead")
        revive(b)
    end
    H.eq(H.weapons[a][2], nil, "the knife alone")
    H.eq(H.hit(a, b, H.hash(G.knife), { attackKind = "melee" }), true, "the knife verified by slot 1")
    E.cancel(match)
    H.settle(500)
end)

H.test("the gate: a step moved before anyone re-armed: the gun in hand counts for nothing", function()
    local match, ids = live(2)
    local a, b = ids[1], ids[2]
    H.eq(H.hit(a, b, gun(1)), true, "the step's weapon")
    match.players[a].gg.step = 2 -- no tick ran
    H.eq(H.hit(a, b, gun(1)), false, "held strictly: the plan is the step's, or nothing")
    E.cancel(match)
    H.settle(500)
end)

H.test("the old weapon is dead the moment a step is taken", function()
    local match, ids = live(3)
    local a, b, c = ids[1], ids[2], ids[3]
    H.hit(a, b, gun(1))
    H.die(b, a)
    H.eq(stepOf(match, a), 2)
    H.eq(H.hit(a, c, gun(1)), false, "no verified weapon during the swap")
    H.settle(400)
    H.eq(H.hit(a, c, gun(1)), false, "Lexington: wrong step")
    H.eq(H.hit(a, c, gun(2)), true, "Nova: this step")
    E.cancel(match)
    H.settle(500)
end)

H.test("a wrong weapon: no damage; a reported kill with no such hit scores nothing and costs nothing", function()
    local match, ids = live(2)
    local a, b = ids[1], ids[2]
    H.eq(H.hit(a, b, H.hash("Items.Preset_Defender_Default")), false, "not the step's weapon")
    H.eq(H.hit(a, b, nil), false, "no weapon on the hit")
    H.eq(H.hit(a, b, gun(1), { attackKind = "explosion" }), false, "explosions never count")
    match.players[b].gg.step = 3
    H.settle(500) -- re-armed for step 3
    H.die(b, a)
    H.settle(100)
    H.eq(stepOf(match, a), 1, "no climb")
    H.eq(stepOf(match, b), 3, "no price")
    H.eq(match.players[a].kills, 0, "no kill on the board")
    E.cancel(match)
    H.settle(500)
end)

H.test("a kill credited through an old hit made on an earlier step scores nothing", function()
    local match, ids = live(3)
    local a, b, c = ids[1], ids[2], ids[3]
    H.eq(H.hit(a, c, gun(1)), true, "a Lexington hit on c")
    kill(match, a, b)
    H.eq(stepOf(match, a), 2)
    H.settle(400)
    H.die(c, a) -- c dies a moment later of that old hit: the killer is on the Nova now
    H.settle(100)
    H.eq(stepOf(match, a), 2, "no second climb")
    E.cancel(match)
    H.settle(500)
end)

H.test("below the top step the knife is not handed: its hits never count, the step's gun in melee climbs", function()
    local match, ids = live(2)
    local a, b = ids[1], ids[2]
    match.players[a].gg.step, match.players[b].gg.step = 5, 4
    H.settle(500)
    H.eq(H.hit(a, b, KNIFE, { attackKind = "melee" }), false, "no knife in the kit: refused")
    H.eq(match.players[a].gg.humiliations, 0)
    E.cancel(match)
    H.settle(500)
    match, ids = live(2)
    a, b = ids[1], ids[2]
    kill(match, a, b, gun(1), "melee")
    H.eq(stepOf(match, a), 2, "the step's weapon in melee climbs")
    E.cancel(match)
    H.settle(500)
end)

H.test("the top step: the knife alone, melee only", function()
    local match, ids = live(2)
    local a, b = ids[1], ids[2]
    match.players[a].gg.step = G.rules and #G.rules.ladder or 14
    H.settle(300)
    H.eq(H.hit(a, b, KNIFE, { attackKind = "ranged" }), false, "the last step is melee only")
    E.cancel(match)
    H.settle(500)
end)

H.test("a death nobody earned costs one step, never below the first", function()
    local match, ids = live(2)
    local a = ids[1]
    H.die(a)
    H.settle(100)
    H.eq(stepOf(match, a), 1, "the floor")
    revive(a)
    match.players[a].gg.step = 4
    H.settle(300)
    H.die(a)
    H.settle(100)
    H.eq(stepOf(match, a), 3)
    E.cancel(match)
    H.settle(500)
end)

H.test("a trade: a killer already down climbs and stands up armed for it", function()
    local match, ids = live(2)
    local a, b = ids[1], ids[2]
    H.eq(H.hit(a, b, gun(1)), true)
    H.die(a, b) -- a falls first, b wins nothing yet (no hit by b)
    H.die(b, a) -- a's shot lands after its death
    H.settle(100)
    H.eq(stepOf(match, a), 2)
    revive(a)
    H.eq(H.weapons[a][1], R.ladder[2].record, "armed on the way back")
    E.cancel(match)
    H.settle(500)
end)

H.test("the final step: the knife only, a kill wins at once, with a recap", function()
    local match, ids = live(3)
    local a, b, c = ids[1], ids[2], ids[3]
    match.players[a].gg.step = TOP - 1
    H.settle(500)
    kill(match, a, b)
    H.eq(stepOf(match, a), TOP)
    H.settle(400)
    H.eq(H.weapons[a][1], G.knife, "only the knife")
    H.eq(H.weapons[a][2], nil)
    H.eq(H.hit(a, c, gun(TOP - 1)), false, "the last gun is gone")
    H.eq(H.hit(a, c, KNIFE, { attackKind = "ranged" }), false, "melee only")
    kill(match, a, c, KNIFE, "melee")
    H.eq(match.phase, "ended")
    H.eq(match.reason, "ladder")
    local results = lastResults()
    H.eq(results[a].won, true)
    H.eq(results[a].placement, 1)
    H.eq(results[a].score, TOP)
    H.eq(results[b].won, false)
    H.eq(results[a].unranked, true)
    H.eq(results[a].recap.rows[1].id, a)
    H.eq(results[a].recap.lines[1].value, match.players[a].name)
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("the guard: another weapon drawn re-arms, at most every 2 s, strings as the host sends them", function()
    local match, ids = live(2)
    local a = ids[1]
    local function arms() return #H.coreCalls("activityKit", a) end
    H.settle(2100)
    local before = arms()
    H.fire("onPlayerWeaponChanged", tostring(a), "3", "Items.Preset_Defender_Default", "true")
    H.settle(400)
    H.eq(arms(), before + 1, "armed again")
    H.fire("onPlayerWeaponChanged", tostring(a), "3", "Items.Preset_Defender_Default", "true")
    H.settle(400)
    H.eq(arms(), before + 1, "not twice in 2 s")
    H.settle(2000)
    H.fire("onPlayerWeaponChanged", tostring(a), "1", G.knife, "true")
    H.fire("onPlayerWeaponChanged", tostring(a), "1", R.ladder[1].record, "true")
    H.fire("onPlayerWeaponChanged", tostring(a), "3", "Items.Preset_Defender_Default", "false")
    H.settle(400)
    H.eq(arms(), before + 1, "the step's weapons and a holster change nothing")
    H.fire("onPlayerWeaponChanged", "junk", "1", "Items.X", "true")
    H.fire("onPlayerWeaponChanged", "999", "1", "Items.X", "true")
    E.cancel(match)
    H.settle(500)
end)

H.test("live setting DASH_gungame: granted at GO, taken back on leaving, an implant's stays", function()
    local ids = players(3)
    H.dash[ids[3]] = "theirs"
    H.matchJoin("games.gungame", ids)
    H.untilPhase(ids[1], "countdown")
    H.eq(H.dash[ids[1]], nil, "never before GO")
    local match = H.untilPhase(ids[1], "running")
    H.settle(200)
    H.eq(H.dash[ids[1]], "ours")
    H.eq(H.dash[ids[3]], "theirs", "their own")
    H.fire("op77_lightrp:activity:leaveRequest", ids[1], "games.gungame")
    H.eq(H.dash[ids[1]], nil, "taken back")
    H.fire("op77_lightrp:activity:leaveRequest", ids[3], "games.gungame")
    H.eq(H.dash[ids[3]], "theirs", "nothing of ours to take")
    H.eq(match.reason, "forfeit")
    H.settle(7000)
    H.eq(H.dash[ids[2]], nil, "the winner's goes at the end of the card")
    H.noneInBuckets()
end)

H.test("a refused take-back is asked again", function()
    local match, ids = live(2)
    H.settle(200)
    H.revokeRefused = 2
    H.fire("op77_lightrp:activity:leaveRequest", ids[1], "games.gungame")
    H.eq(H.dash[ids[1]], "ours", "refused so far")
    H.settle(2500)
    H.eq(H.dash[ids[1]], nil, "gone")
    H.settle(7000)
    H.eq(match.closed, true)
end)

H.test("the HUD: the weapon, the step, what comes next, the leader", function()
    local match, ids = live(2)
    local a, b = ids[1], ids[2]
    kill(match, a, b)
    H.settle(400)
    local view = H.lastClient("op77_games:hud", b).args[1]
    H.eq(view.objective, "Kill with the Lexington")
    H.eq(view.stats[1].value, "Lexington")
    H.eq(view.stats[2].value, "1/14")
    H.eq(view.stats[3].value, "Nova")
    H.eq(view.stats[4].value, match.players[a].name .. " 2")
    H.eq(view.world, nil, "no objective in the world")
    E.cancel(match)
    H.settle(500)
end)

H.test("the clock: the highest step, reached first; level at step 1 is nobody's", function()
    local function body(step, stepAt) return { gg = { step = step, stepAt = stepAt } } end
    local a, b = body(4, 100), body(4, 90)
    H.eq(G.clockWinner({ a, b }), b, "reached first")
    H.eq(G.clockWinner({ body(1, 0), body(1, 0) }), nil, "nobody off the first step")
    H.eq(G.clockWinner({ body(3, 50), body(3, 50) }), nil, "a true tie")
    H.eq(G.clockWinner({ body(1, 0), body(2, 9), body(5, 200) }).gg.step, 5)
    H.eq(G.clockWinner({}), nil)

    local match, ids = live(2)
    kill(match, ids[1], ids[2])
    match.endsAt = E.now() + 200
    H.settle(400)
    H.eq(match.reason, "time")
    H.eq(lastResults()[ids[1]].won, true)
    H.settle(7000)

    match, ids = live(2)
    match.endsAt = E.now() + 200
    H.settle(400)
    local results = lastResults()
    H.eq(results[ids[1]].won, false, "no winner")
    H.eq(results[ids[2]].won, false)
    H.eq(results[ids[1]].recap.lines[1].value, "Nobody")
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("a forfeit: the one left wins whatever the ladder says", function()
    local match, ids = live(2)
    kill(match, ids[1], ids[2])
    H.fire("op77_lightrp:activity:leaveRequest", ids[1], "games.gungame")
    H.eq(match.reason, "forfeit")
    H.eq(lastResults()[ids[2]].won, true)
    H.eq(lastResults()[ids[1]].won, false)
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("leaving mid-match: three players, one leaves, one disconnects", function()
    local match, ids = live(3)
    H.fire("op77_lightrp:activity:leaveRequest", ids[1], "games.gungame")
    H.eq(match.phase, "running", "two remain")
    H.eq(H.weaponCount(ids[1]), 0, "weapons off")
    H.fire("onPlayerDisconnected", ids[2])
    H.removePlayer(ids[2])
    H.eq(match.reason, "forfeit")
    H.eq(lastResults()[ids[3]].won, true)
    H.settle(7000)
    H.noneInBuckets()
end)

H.test("a hostile client: the mode listens to no client, and strangers' hits count for nothing", function()
    for name in pairs(H.netHandlers) do
        H.ok(not name:find("gungame"), "this mode takes nothing from a client: " .. name)
    end
    H.ok(H.netHandlers["op77_games:ready"], "only the engine's ready reaches it")
    local match, ids = live(2)
    local stranger = H.addPlayer(900)
    H.eq(stranger.bucket, 0)
    H.eq(E.matchOf(900), nil)
    local before = #H.clientNamed("op77_games:hud", 900)
    H.fireNet("op77_games:ready", 900)
    H.eq(#H.clientNamed("op77_games:hud", 900), before, "no state for a stranger")
    H.eq(H.hit(900, ids[1], gun(1)), false, "nobody reaches in")
    H.die(ids[1], 900)
    H.settle(100)
    H.eq(stepOf(match, ids[1]), 1, "a stranger's kill is nobody's: the floor")
    H.fireNet("op77_games:ready", ids[2])
    H.settle(100)
    H.eq(H.lastClient("op77_games:hud", ids[2]).args[1].activity, "games.gungame", "its own, and only that")
    H.removePlayer(900)
    E.cancel(match)
    H.settle(500)
end)

H.done("gungame_test")
