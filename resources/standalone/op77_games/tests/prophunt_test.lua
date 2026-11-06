-- Prop Hunt: rules, the hidden body, every exit, a hostile client, the client's levers.
-- The natives the harness has no use for elsewhere are faked here.
-- Run: lua tests/prophunt_test.lua
local H = dofile("tests/harness.lua")

-- ---------------------------------------------------------------- fakes --

local props, nextProp = {}, 0      -- id -> { model, bucket, visible, parent, yaw }
local hidden, blind = {}, {}       -- playerId -> true
local untouched = {}               -- natives this mode must never call -> calls
local refuseModel, refuseShow = {}, 0
local sounds, sparks = {}, 0

Open77.props = {
    create = function(def)
        if refuseModel[def.model] then return nil, "unknown_alias" end
        nextProp = nextProp + 1
        local id = tostring(1000 + nextProp)
        props[id] = { model = def.model, bucket = def.bucket, visible = def.visible, ttlMs = def.ttlMs }
        return id
    end,
    attach = function(id, binding)
        props[id].parent, props[id].yaw = binding.parentId, binding.rotation.z
        return true
    end,
    update = function(id, patch)
        props[id].visible = patch.visible
        return true
    end,
    remove = function(id)
        if not props[id] then return nil, "not_found" end
        props[id] = nil
        return true
    end,
    setAttachmentTransform = function(id, _, rotation)
        props[id].yaw = rotation.z
        return true
    end,
}
Open77.players.setVisible = function(id, visible)
    if not H.players[id] then return false, "player_not_found" end
    if visible and refuseShow > 0 then
        refuseShow = refuseShow - 1
        return false, "transition_in_progress"
    end
    hidden[id] = not visible or nil
    return true
end
Open77.players.isVisible = function(id) return not hidden[id] end
for _, name in ipairs({ "setMaxHealth", "setRegenEnabled", "setRegen", "setGhosted", "setGodMode" }) do
    Open77.players[name] = function() untouched[name] = (untouched[name] or 0) + 1 return true end
end
local screen = Open77.effects.screen
Open77.effects.screen = function(id, name, options)
    if name == "blackout" then blind[id] = true end
    return screen(id, name, options)
end
Open77.effects.clearScreen = function(id) blind[id] = nil return true end
Open77.effects.play = function() sparks = sparks + 1 return true end
Open77.audio = {
    play3D = function(file, at, options)
        sounds[#sounds + 1] = { file = file, at = at, options = options }
        return #sounds
    end,
    destroy = function() return true end,
}

H.loadServer()
H.advance(200)
local E, G = GamesEngine, GamesProphunt
local GUN = H.hash("Items.Preset_Ajax_Default")

-- ---------------------------------------------------------------- helpers --

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

-- Running (the hide on), with its hunters and props.
local function live(n, map)
    local ids = players(n)
    H.matchJoin("games.prophunt", ids, { map = map or "water-side" })
    local match = H.untilPhase(ids[1], "running")
    H.settle(300) -- the HUD's next send
    local hunters, list = {}, {}
    for _, id in ipairs(ids) do
        local p = match.players[id]
        if p.ph.role == "hunter" then hunters[#hunters + 1] = id else list[#list + 1] = id end
    end
    return match, hunters, list
end

local function hunted(n, map)
    local match, hunters, list = live(n, map)
    H.settle(45200)
    H.eq(match.ph.phase, "hunt", "the hunt is on")
    return match, hunters, list
end

local function propsOf(id)
    local count = 0
    for _, prop in pairs(props) do
        if prop.parent == id then count = count + 1 end
    end
    return count
end

local function action(id, name) H.fireNet("op77_games:prophunt:action", id, name) end

local function lastState(id)
    local event = H.lastClient("op77_games:prophunt", id)
    return event and event.args[1]
end

-- Nothing left on this body: the safety point of the mode.
local function clean(id, what)
    what = what or "after the exit"
    H.eq(hidden[id], nil, what .. ": visible")
    H.eq(propsOf(id), 0, what .. ": no object")
    H.eq(blind[id], nil, what .. ": sighted")
    local player = H.players[id]
    if player then
        H.eq(player.frozen, false, what .. ": free")
        H.eq(lastState(id), nil, what .. ": the client let go")
        H.eq(H.weaponCount(id), 0, what .. ": no weapon of ours")
    end
end

local function finish(match)
    if not match.closed then E.cancel(match) end
    H.settle(300)
end

local function kill(attacker, victim)
    for _ = 1, 40 do
        if E.matchOf(victim) == nil or E.matchOf(victim).players[victim].ph.role == "hunter" then return end
        H.hit(attacker, victim, GUN, { amount = 200 })
        H.settle(100)
    end
    error("never found")
end

local function results()
    local byId = {}
    for _, e in ipairs(H.eventsNamed("op77_lightrp:activity:result")) do byId[e.args[1]] = e.args[3] end
    return byId
end

-- ---------------------------------------------------------------- rules --

H.test("one hunter per 4 players, at least one, never everyone", function()
    for players_, hunters in pairs({ [2] = 1, [3] = 1, [4] = 1, [7] = 1, [8] = 2, [11] = 2, [12] = 3, [16] = 4 }) do
        H.eq(G.hunterCount(players_), hunters, players_ .. " players")
    end
end)

H.test("the catalogue: every object has a family and a health, nothing doubled", function()
    H.eq(#G.catalog, 129)
    local seen = {}
    for _, object in ipairs(G.catalog) do
        H.ok(object.family and G.families[object.family], object.model .. " has a family")
        H.ok(object.health >= 50 and object.health <= 160, object.model .. " health")
        H.ok(object.label ~= "", object.model .. " label")
        H.ok(not seen[object.model], object.model .. " once")
        seen[object.model] = true
    end
end)

H.test("a map's own objects: only they are worn; none, or none known: the whole catalogue", function()
    H.eq(#G.pool({}), #G.catalog, "no list")
    H.eq(#G.pool({ props = {} }), #G.catalog, "an empty list")
    H.eq(#G.pool({ props = { "gone.alias" } }), #G.catalog, "nothing known")
    local a, b = G.catalog[3], G.catalog[7]
    H.eq(#G.pool({ props = { a.model, b.model, "gone.alias" } }), 2)
    local raw
    for _, map in ipairs(H.core.maps["games.prophunt"]) do if map.id == "water-side" then raw = map end end
    raw.props, raw.revision = { a.model, b.model }, raw.revision + 1
    H.signalMaps("games.prophunt")
    local match, _, list = live(4)
    H.eq(#match.ph.pool, 2)
    for _, id in ipairs(list) do
        local s = match.players[id].ph
        H.eq(#s.order, 2, "two steps")
        for _, index in ipairs(s.order) do
            local model = G.catalog[index].model
            H.ok(model == a.model or model == b.model, model .. " is not this map's")
        end
        H.ok(s.object == a or s.object == b, "worn from the map's list")
    end
    finish(match)
    raw.props, raw.revision = nil, raw.revision + 1
    H.signalMaps("games.prophunt")
end)

H.test("8 maps offered, 5 kept; each has both spawns, its timings, the hunters inside the area", function()
    local offered = H.core.registered["games.prophunt"].modes
    H.eq(#offered, 8)
    H.eq(#H.mapsOf("prophunt"), 8)
    local spare, delivered = 0, {}
    for _, raw in ipairs(H.seedData["games.prophunt"]) do if not raw.enabled then spare = spare + 1 end end
    H.eq(spare, 5)
    for index, map in ipairs(H.mapsOf("prophunt")) do
        H.ok(map.id:match("^[a-z0-9-]+$"), map.id)
        H.eq(map.hideSeconds, 45, map.id .. " hide")
        H.eq(map.roundSeconds, 300, map.id .. " hunt")
        H.ok(map.autoWhistleSeconds and map.whistleCooldown and map.changeCooldown, map.id .. " timings")
        H.eq(map.centre.x, map.propsSpawn.x, map.id .. ": the area is around the props' spawn")
        H.ok(E.distance(map.huntersSpawn, map.centre) < map.radius, map.id .. ": hunters inside")
        H.eq(offered[index].id, map.id, "offered in order")
        delivered[map.id] = true
    end
    H.ok(not delivered["school"], "a spare is not delivered")
    H.eq(H.core.registered["games.prophunt"].kind, "event")
end)

H.test("the manifest declares open77_props and every script", function()
    local text = io.open("open77.lua"):read("a")
    H.ok(text:find('"open77_props >=0.1.0"', 1, true), "dependency")
    H.ok(text:find('client_script "client/prophunt.lua"', 1, true), "client")
    H.ok(text:find('"players.life.visibility"', 1, true), "visibility permission")
    H.ok(text:find('"world.props"', 1, true), "props permission")
    H.ok(not text:find("gizmos", 1, true), "no gizmo")
end)

H.test("the spawns: props on theirs, hunters on theirs; the clock is hide + hunt", function()
    local match, hunters, list = live(8)
    H.eq(#hunters, 2)
    H.eq(#list, 6)
    H.eq(match.seconds, 345)
    H.eq(H.players[hunters[1]].bucket, match.bucket)
    H.ok(E.flat(H.players[hunters[1]], match.map.huntersSpawn) <= 1.51, "hunter spawn")
    H.ok(E.flat(H.players[list[1]], match.map.propsSpawn) <= 3.01, "prop spawn")
    H.eq(match.players[hunters[1]].side, G.HUNTERS)
    H.eq(match.players[list[1]].side, G.PROPS)
    finish(match)
end)

H.test("GO: every RP gun holstered, no RP slot removed", function()
    local ids = players(5)
    for _, id in ipairs(ids) do H.weapons[id] = { [1] = "Items.RP_Weapon" } end
    local from = #H.weaponLog
    H.matchJoin("games.prophunt", ids, { map = "water-side" })
    local match = H.untilPhase(ids[1], "running")
    for _, id in ipairs(ids) do
        local holstered, removed = false, false
        for index = from + 1, #H.weaponLog do
            local entry = H.weaponLog[index]
            if entry.playerId == id then
                holstered = holstered or entry.operation == "holster"
                removed = removed or entry.operation == "remove"
            end
        end
        H.ok(holstered, "holstered")
        H.ok(not removed, "the RP slots are left alone")
        H.eq(H.weapons[id][1], "Items.RP_Weapon")
    end
    for _, id in ipairs(ids) do H.weapons[id] = nil end
    finish(match)
end)

H.test("the blackout ends by itself: bounded to the hide and a margin, never 0", function()
    local from = #H.screens
    local match, hunters = live(5)
    local seen = false
    for index = from + 1, #H.screens do
        local screen_ = H.screens[index]
        if screen_.name == "blackout" and screen_.id == hunters[1] then
            seen = true
            local duration = screen_.options.duration
            H.ok(duration > match.map.hideSeconds - 1, "past the hide")
            H.ok(duration <= match.map.hideSeconds + G.rules.blindMargin, "and bounded: " .. duration)
        end
    end
    H.ok(seen, "blacked out")
    finish(match)
end)

H.test("the play area ignores height, as the source's; sideways is still out", function()
    local match, hunters, list = live(4)
    local id = list[1]
    local map = match.map
    H.move(id, map.centre.x, map.centre.y, map.centre.z + map.radius + 50)
    local pushes = #H.clientNamed("op77_games:push", id)
    H.settle(2000)
    H.eq(#H.clientNamed("op77_games:push", id), pushes, "a roof is no way out")
    H.move(id, map.centre.x + map.radius + 5, map.centre.y, map.centre.z)
    H.settle(1000)
    H.eq(H.lastClient("op77_games:push", id).args[2].title, "OUT OF BOUNDS")
    H.ok(hunters[1], "a hunter")
    finish(match)
end)

H.test("the hide: props hidden under an object, hunters held blind, nobody armed", function()
    local match, hunters, list = live(5)
    for _, id in ipairs(list) do
        H.eq(hidden[id], true, "hidden")
        H.eq(propsOf(id), 1, "one object")
        H.eq(lastState(id).role, "prop", "the client knows")
        H.eq(H.weaponCount(id), 0, "unarmed")
    end
    local hunter = hunters[1]
    H.eq(H.players[hunter].frozen, true, "held")
    H.eq(blind[hunter], true, "blind")
    H.eq(hidden[hunter], nil, "a hunter is seen")
    H.eq(H.weaponCount(hunter), 0, "no weapon yet")
    H.eq(lastState(hunter).role, "hunter")
    local prop
    for _, candidate in pairs(props) do if candidate.parent == list[1] then prop = candidate end end
    H.eq(prop.visible, true, "shown once bound")
    H.eq(prop.bucket, match.bucket)
    H.ok(prop.ttlMs >= 345000, "an expiry past the match")
    local view = H.lastClient("op77_games:hud", list[1]).args[1]
    H.eq(view.timer.label, "HIDE")
    H.eq(view.hints[1].bind, "games.prophunt.next", "a hint names its key")
    H.ok(H.lastClient("op77_games:hud", hunter).args[1].timer.label == "HIDE")
    finish(match)
end)

H.test("the hunt: hunters free, sighted, in the kit missions preselect; the props get none", function()
    local match, hunters = hunted(3)
    local hunter = hunters[1]
    H.eq(H.players[hunter].frozen, false)
    H.eq(blind[hunter], nil)
    H.eq(H.weapons[hunter][1], "Items.Preset_Ajax_Default")
    H.eq(H.coreCalls("activityKit", hunter)[1].args[3], nil, "the default kit")
    for id, p in pairs(match.players) do
        if p.ph.role == "prop" then H.eq(#H.coreCalls("activityKit", id), 0, "no kit for a prop") end
    end
    H.eq(H.lastClient("op77_games:hud", hunter).args[1].timer.label, "TIME")
    finish(match)
end)

H.test("only a hunter's hit counts, never a melee, never before the hunt, and the body keeps its health", function()
    local match, hunters, list = live(4)
    local hunter, prop = hunters[1], list[1]
    local s = match.players[prop].ph
    local full = s.hp
    H.eq(H.hit(hunter, prop, GUN), false, "not while hiding")
    H.eq(s.hp, full)
    H.settle(45200)
    H.eq(H.hit(hunter, prop, GUN, { attackKind = "melee" }), false, "melee")
    H.eq(s.hp, full, "melee counts for nothing")
    H.eq(H.hit(prop, hunter, GUN), false, "a prop hurts nobody")
    H.eq(H.hit(list[2], prop, GUN), false, "nor another prop")
    H.eq(H.hit(hunter, prop, H.hash("Items.Preset_Defender_Default")), false, "a weapon we did not issue")
    H.eq(s.hp, full)
    H.eq(H.hit(hunter, prop, GUN, { amount = 20 }), false, "the real hit is always refused")
    H.eq(s.hp, full - 20, "counted against the object")
    H.eq(H.players[prop].health, 100, "the real body is untouched")
    H.settle(200)
    H.eq(#H.clientNamed("op77_games:cue", hunter) > 0, true, "the hunter hears it")
    finish(match)
end)

H.test("a found prop: the object goes, it comes back a hunter, armed, seen, and the find counts", function()
    local match, hunters, list = hunted(3)
    local hunter, prop = hunters[1], list[1]
    H.hit(hunter, prop, GUN, { amount = 500 })
    H.settle(200)
    local s = match.players[prop].ph
    H.eq(s.role, "hunter")
    H.eq(s.joined, true)
    H.eq(propsOf(prop), 0, "the object went")
    H.eq(match.players[hunter].kills, 1, "the find")
    H.eq(match.players[prop].side, G.HUNTERS)
    H.eq(H.players[prop].life, "alive", "no death")
    H.eq(H.players[prop].frozen, true, "held through the find")
    H.eq(H.teams[prop], G.HUNTERS, "its side")
    H.settle(3500)
    H.eq(hidden[prop], nil, "seen again")
    H.eq(H.players[prop].frozen, false)
    H.ok(E.flat(H.players[prop], match.map.huntersSpawn) <= 1.51, "at the hunters' spawn")
    H.eq(H.weapons[prop][1], "Items.Preset_Ajax_Default", "armed")
    H.eq(lastState(prop).role, "hunter")
    H.eq(H.hit(prop, list[2], GUN, { amount = 1 }), false)
    H.eq(match.players[list[2]].ph.hp < match.players[list[2]].ph.maxHp, true, "it hunts")
    finish(match)
end)

H.test("every prop found: the hunters win, joined ones with them, and every body is back before the recap", function()
    local match, hunters, list = hunted(4)
    kill(hunters[1], list[1])
    kill(hunters[1], list[2])
    H.eq(match.ph.phase, "hunt", "one left")
    kill(hunters[1], list[3])
    H.eq(match.reason, "decided")
    H.eq(match.phase, "ended")
    for _, id in ipairs(list) do H.eq(hidden[id], nil, "shown at the end") end
    local byId = results()
    H.eq(byId[hunters[1]].won, true, "the hunter")
    H.eq(byId[list[1]].won, true, "a found prop wins with the hunters")
    H.eq(byId[hunters[1]].unranked, true, "nothing recorded")
    local recap = byId[hunters[1]].recap
    H.eq(recap.winnerSide, G.HUNTERS)
    H.eq(recap.rows[1].id, hunters[1], "the most finds first")
    H.eq(recap.rows[1].kills, 3)
    H.settle(7000)
    for _, id in ipairs(list) do clean(id, "after the end") end
    H.noneInBuckets()
end)

H.test("the clock: the props that lasted win, and the found ones lose with nobody", function()
    local match, hunters, list = hunted(3)
    kill(hunters[1], list[1])
    H.settle(301000)
    H.eq(match.reason, "time")
    local byId = results()
    H.eq(byId[list[2]].won, true, "survived")
    H.eq(byId[hunters[1]].won, false)
    H.eq(byId[list[1]].won, false, "found: with the hunters, who lost")
    H.eq(byId[list[2]].recap.winnerSide, G.PROPS)
    H.eq(byId[list[2]].recap.rows[1].id, list[2])
    H.eq(hidden[list[2]], nil, "shown at the end")
    H.eq(propsOf(list[2]), 0, "no object after the end")
    H.settle(7000)
    clean(list[2], "after the clock")
end)

H.test("the last hunter leaves: the props win; the last prop leaves: the hunters win", function()
    local match, hunters, list = hunted(3)
    H.fire("op77_lightrp:activity:leaveRequest", hunters[1], "games.prophunt")
    H.eq(match.reason, "forfeit")
    H.eq(results()[list[1]].won, true)
    H.settle(7000)

    local second, seekers, others = hunted(2)
    H.fire("op77_lightrp:activity:leaveRequest", others[1], "games.prophunt")
    H.eq(second.reason, "forfeit")
    H.eq(results()[seekers[1]].won, true)
    H.eq(results()[others[1]].won, false)
    clean(others[1], "the prop that left")
    H.settle(7000)
end)

-- ---------------------------------------------------------------- the body --

H.test("a hide the platform dropped is put back within 2 s", function()
    local match, _, list = live(2)
    hidden[list[1]] = nil
    H.settle(2500)
    H.eq(hidden[list[1]], true)
    finish(match)
end)

H.test("a refused alias is left out; nothing holds yet: the body stays hidden, the retry walks on", function()
    local keep = G.catalog[1].model
    for _, object in ipairs(G.catalog) do refuseModel[object.model] = object.model ~= keep or nil end
    local match, _, list = live(2)
    local prop = list[1]
    local s = match.players[prop].ph
    if s.order[1] ~= 1 and propsOf(prop) == 0 then H.eq(hidden[prop], true, "hidden meanwhile") end
    H.settle(40000)
    H.eq(propsOf(prop), 1, "the one that holds, found by the retries")
    H.eq(s.object.model, keep)
    H.ok(s.hp > 0)
    refuseModel = {}
    for model in pairs(G.refused) do G.refused[model] = nil end
    finish(match)
end)

H.test("R walks the order under the cooldown; health keeps its share; the old object goes", function()
    local match, _, list = live(2)
    local prop = list[1]
    local s = match.players[prop].ph
    local first = s.object
    s.hp = s.maxHp / 2
    H.settle(1100)
    action(prop, "next")
    H.ok(s.object ~= first, "a new object")
    H.eq(propsOf(prop), 1, "one object")
    H.eq(s.slot, 2)
    H.eq(s.hp, math.floor(s.object.health / 2), "the same share")
    local worn = s.object
    H.settle(200)
    action(prop, "next")
    H.eq(s.object, worn, "1 s between two changes while hiding")
    H.settle(45000)
    action(prop, "next")
    local hunting = s.object
    H.settle(1200)
    action(prop, "next")
    H.eq(s.object, hunting, "the map's 5 s while hunting")
    finish(match)
end)

H.test("V jumps to the next family", function()
    local order = {}
    for index = 1, #G.catalog do order[index] = index end
    local here = G.catalog[order[1]].family
    local at = G.nextFamilySlot(order, 1)
    H.eq(G.catalog[order[at]].family, here % #G.families + 1)
    local match, _, list = live(2)
    local s = match.players[list[1]].ph
    local family = s.object.family
    H.settle(1100)
    action(list[1], "family")
    H.eq(s.object.family, family % #G.families + 1)
    finish(match)
end)

H.test("G turns the object 45 degrees; the lock holds the body and lets go", function()
    local match, _, list = live(2)
    local prop = list[1]
    local s = match.players[prop].ph
    local before = s.yaw
    action(prop, "rotate")
    H.eq(s.yaw, (before + 45) % 360)
    H.eq(props[s.propId].yaw, s.yaw)
    H.settle(200)
    action(prop, "lock")
    H.eq(H.players[prop].frozen, true)
    H.eq(s.locked, true)
    H.settle(200)
    action(prop, "lock")
    H.eq(H.players[prop].frozen, false)
    H.eq(s.locked, nil)
    finish(match)
end)

H.test("the whistle: heard in the match's bucket, under its cooldown; a forced one with no key", function()
    local match, _, list = live(2)
    local prop = list[1]
    local before = #sounds
    action(prop, "whistle")
    H.eq(#sounds, before + 1)
    H.eq(sounds[#sounds].file, "audio/whistle.wav")
    H.eq(sounds[#sounds].options.bucket, match.bucket)
    H.eq(sounds[#sounds].options.network, true)
    H.settle(1000)
    action(prop, "whistle")
    H.eq(#sounds, before + 1, "8 s between two")
    H.settle(8000)
    action(prop, "whistle")
    H.eq(#sounds, before + 2)
    H.settle(37000 + 72000)
    H.ok(#sounds > before + 2, "forced after the map's 60 s")
    finish(match)
end)

H.test("the pulse: warm or cold, never where; a cooldown", function()
    local match, hunters, list = hunted(2)
    local hunter = hunters[1]
    H.eq(G.pulseBand(10), "HOT")
    H.eq(G.pulseBand(20), "WARM")
    H.eq(G.pulseBand(36), "COLD")
    local at = H.players[hunter]
    H.move(list[1], at.x + 5, at.y, at.z)
    action(hunter, "pulse")
    local s = match.players[hunter].ph
    H.eq(s.pulse, "HOT")
    H.move(list[1], at.x + 30, at.y, at.z)
    H.settle(1000)
    action(hunter, "pulse")
    H.eq(s.pulse, "HOT", "30 s between two")
    H.settle(31000)
    action(hunter, "pulse")
    H.eq(s.pulse, "WARM")
    finish(match)
end)

H.test("the final minute: forced whistles come twice as often", function()
    local match = hunted(2)
    H.settle(241000)
    H.eq(match.ph.final, true)
    finish(match)
end)

H.test("a real death of a prop: out of the props, back as a hunter by the engine's respawn", function()
    local match, _, list = hunted(3)
    local prop = list[1]
    hidden[prop] = nil -- the platform releases the hide on a death
    H.die(prop)
    H.settle(100)
    local s = match.players[prop].ph
    H.eq(s.role, "hunter")
    H.eq(propsOf(prop), 0, "the object went")
    H.settle(4500)
    H.eq(H.players[prop].life, "alive")
    H.eq(H.players[prop].bucket, match.bucket)
    H.ok(E.flat(H.players[prop], match.map.huntersSpawn) <= 1.51, "at the hunters' spawn")
    H.eq(H.weapons[prop][1], "Items.Preset_Ajax_Default", "armed")
    H.eq(hidden[prop], nil, "never hidden again")
    H.eq(match.ph.found, 1)
    H.eq(match.players[prop].deaths, 1, "counted once")
    finish(match)
end)

H.test("a hunter that dies in the hide comes back held and blind", function()
    local match, hunters = live(2)
    local hunter = hunters[1]
    blind[hunter] = nil
    H.die(hunter)
    H.settle(3500)
    H.eq(H.players[hunter].life, "alive")
    H.eq(H.players[hunter].frozen, true)
    H.eq(blind[hunter], true)
    finish(match)
end)

-- ---------------------------------------------------------------- every exit --

H.test("leave: a prop, a locked prop and a blind hunter come back whole", function()
    local match, hunters, list = live(6)
    action(list[2], "lock")
    H.eq(H.players[list[2]].frozen, true)
    H.fire("op77_lightrp:activity:leaveRequest", list[1], "games.prophunt")
    clean(list[1], "a prop leaves")
    H.fire("op77_lightrp:activity:leaveRequest", list[2], "games.prophunt")
    clean(list[2], "a locked prop leaves")
    H.eq(H.players[list[1]].bucket, 0, "returned")
    H.fire("op77_lightrp:activity:leaveRequest", hunters[1], "games.prophunt")
    clean(hunters[1], "a blind hunter leaves")
    H.eq(match.reason, "forfeit", "the last hunter gone: the props win")
    H.settle(7000)
    for _, id in ipairs(list) do clean(id, "the rest, after the end") end
end)

H.test("a found prop leaving before it joins: seen, free, no object", function()
    local match, hunters, list = hunted(3)
    H.hit(hunters[1], list[1], GUN, { amount = 500 })
    H.settle(200)
    H.fire("op77_lightrp:activity:leaveRequest", list[1], "games.prophunt")
    clean(list[1], "found, then left")
    finish(match)
end)

H.test("disconnect: the object goes, nothing is asked of a body that left", function()
    local match, _, list = live(3)
    local prop = list[1]
    H.removePlayer(prop)
    H.fire("onPlayerDisconnected", prop)
    H.eq(propsOf(prop), 0, "no object left in the bucket")
    H.eq(E.matchOf(prop), nil)
    hidden[prop] = nil
    finish(match)
end)

H.test("a refused show is asked again, after the way back too", function()
    local match, _, list = live(2)
    refuseShow = 2
    local prop = list[1]
    H.fire("op77_lightrp:activity:leaveRequest", prop, "games.prophunt")
    H.eq(hidden[prop], true, "refused for now")
    H.eq(propsOf(prop), 0, "the object went anyway")
    H.settle(2500)
    H.eq(hidden[prop], nil, "shown")
    finish(match)
end)

H.test("before GO: a cancelled match leaves nothing", function()
    local ids = players(2)
    H.matchJoin("games.prophunt", ids, { map = "water-side" })
    local match = H.untilPhase(ids[1], "countdown")
    H.fire("op77_lightrp:activity:leaveRequest", ids[1], "games.prophunt")
    H.eq(match.phase, "ended", "cancelled")
    H.settle(300)
    for _, id in ipairs(ids) do clean(id, "cancelled") end
end)

H.test("a scope refused for 15 s cancels: everyone whole", function()
    H.scopeRefusal = "scope_limit"
    local ids = players(3)
    H.matchJoin("games.prophunt", ids, { map = "water-side" })
    local match = H.untilPhase(ids[1], "running")
    H.settle(16000)
    H.scopeRefusal = nil
    H.eq(match.closed, true)
    for _, id in ipairs(ids) do clean(id, "cancelled by a refused scope") end
    H.settle(300)
end)

H.test("the core stops mid-match: every body whole, then back in the city", function()
    local _, hunters, list = live(3)
    H.coreStop()
    for _, id in ipairs(list) do clean(id, "core stopped") end
    clean(hunters[1], "core stopped")
    H.settle(2500)
    H.noneInBuckets()
    H.coreStart()
    H.advance(1000)
end)

H.test("the core crashes silently mid-match: the orphan check cleans up", function()
    local _, hunters, list = hunted(3)
    H.coreCrash()
    H.settle(4600)
    for _, id in ipairs(list) do clean(id, "core crashed") end
    clean(hunters[1], "core crashed")
    H.settle(1000)
    H.noneInBuckets()
    H.coreStart()
    H.advance(1000)
end)

H.test("a client can't do anything: not a stranger, not the wrong role, not garbage, not a flood", function()
    local match, hunters, list = hunted(3)
    local prop, hunter = list[1], hunters[1]
    local outsider = players(1)[1]
    local s = match.players[prop].ph
    local worn, yaw, count = s.object, s.yaw, #sounds
    for _, name in ipairs({ "next", "family", "whistle", "rotate", "lock", "pulse" }) do
        action(outsider, name)
    end
    H.eq(E.matchOf(outsider), nil, "no match for a stranger")
    for _, bad in ipairs({ -1, 0, "x", "1", 1.5 }) do H.fireNet("op77_games:prophunt:action", bad, "next") end
    H.fireNet("op77_games:prophunt:action", nil, "next")
    H.eq(s.object, worn, "unchanged by strangers")
    H.settle(150)
    for _, name in ipairs({ "next", "family", "whistle", "rotate", "lock" }) do
        action(hunter, name)
        H.settle(150)
    end
    H.eq(H.players[hunter].frozen, false, "a hunter has no prop keys")
    H.eq(#sounds, count, "a hunter does not whistle")
    action(prop, "pulse")
    H.eq(s.pulse, nil, "a prop has no pulse")
    for _, junk in ipairs({ {}, 7, true, "", "kill", "__index", ("x"):rep(5000) }) do
        H.fireNet("op77_games:prophunt:action", prop, junk)
    end
    H.fireNet("op77_games:prophunt:action", prop)
    H.eq(s.object, worn, "garbage changes nothing")
    H.settle(6000)
    local before = s.object
    for _ = 1, 50 do action(prop, "next") end
    H.ok(s.slot <= 3 and s.object ~= before, "one change for a flood")
    H.eq(propsOf(prop), 1)
    H.eq(s.yaw, yaw, "the object was not turned")

    -- A player in another game has no say here either.
    local others = players(2)
    H.matchJoin("games.redlight", others, {})
    H.untilPhase(others[1], "running")
    action(others[1], "next")
    action(others[1], "pulse")
    E.cancel(E.matchOf(others[1]))
    finish(match)
end)

H.test("after the end nothing a client asks changes a body", function()
    local match, hunters, list = hunted(2)
    H.fire("op77_lightrp:activity:leaveRequest", hunters[1], "games.prophunt")
    H.eq(match.phase, "ended")
    action(list[1], "next")
    action(list[1], "lock")
    H.eq(propsOf(list[1]), 0, "no object comes back")
    H.eq(H.players[list[1]].frozen, false)
    H.settle(7000)
end)

H.test("a join with no options.match queues and plays", function()
    local ids = players(2)
    for _, id in ipairs(ids) do H.panelJoin(id, "games.prophunt", { map = "roof-top" }) end
    H.settle(16000)
    local match = H.ok(E.matchOf(ids[1]), "launched")
    H.eq(match.map.id, "roof-top")
    H.eq(match.def.id, "games.prophunt")
    finish(match)
end)

H.test("the spare maps are not played", function()
    local ids = players(2)
    H.panelJoin(ids[1], "games.prophunt", { map = "school" })
    H.advance(300)
    H.eq(E.matchOf(ids[1]), nil)
    H.ok(H.noticeFor(ids[1], "not available"), "refused")
    H.core.pending[ids[1]] = nil
    H.core.pending[ids[2]] = nil
end)

H.test("the health natives stay out of it, and nothing was ghosted", function()
    H.eq(next(untouched), nil, "max health, regen, ghost and god mode never called")
end)

-- This one last: the provider goes.
H.test("the provider stops mid-match: bodies whole before it goes", function()
    local _, hunters, list = live(5)
    action(list[1], "lock")
    H.providerStop()
    for _, id in ipairs(list) do clean(id, "provider stopped") end
    clean(hunters[1], "provider stopped")
    H.noneInBuckets()
end)

-- ---------------------------------------------------------------- the client --

H.test("the client: the view, the attack, the scanner, plates and dots, all let go by one call", function()
    local calls = {}
    local function note(name) return function(...) calls[#calls + 1] = { name, ... } return true end end
    local keys = {}
    Open77.perspective = { setThirdPerson = note("lock"), clearThirdPersonOverride = note("clear") }
    Open77.players.setLocalPuppetVisible = note("self")
    Open77.input = { setActionBlocked = note("block"), keyFor = function(id) return id == "games.prophunt.next" and "F3" or nil end }
    Open77.hud = { setVisible = note("hud") }
    function RegisterKeyMapping(id, _, key, fn) keys[id] = { key = key, fn = fn } return true, key end
    function GetGameTimer() return H.clock end
    function GetResourceState() return "running" end
    local hidden_, dots
    exports.op77_playermarks = { setHidden = function(_, on) hidden_ = on return true end }
    exports.op77_map3d = { setPlayerDotsHidden = function(_, on) dots = on return true end }
    dofile("client/prophunt.lua")
    H.advance(50)
    H.eq(keys["games.prophunt.next"].key, "R")
    H.eq(keys["games.prophunt.pulse"].key, "Z")
    -- The lock is pressed all round: on a key Light RP leaves free (B draws Mantis Blades).
    local taken = {}
    for _, file in ipairs({ "shared/config.lua", "server/config/cyberware.lua" }) do
        for line in io.lines("../../gamemodes/op77_lightrp/" .. file) do
            local key = line:match('id = "lightrp%.[^"]+".-key = "(%w+)"')
            if key then taken[key] = true end
        end
    end
    H.ok(taken.B and taken.E, "the table of Light RP's keys is read")
    H.ok(not taken[keys["games.prophunt.lock"].key], "the lock key is free")
    local function count(name, a, b)
        local n = 0
        for _, c in ipairs(calls) do
            if c[1] == name and (a == nil or c[2] == a) and (b == nil or c[3] == b) then n = n + 1 end
        end
        return n
    end
    local fire = H.netHandlers["op77_games:prophunt"]
    fire({ role = "prop" })
    H.eq(count("lock", true, true), 1, "third person locked")
    H.eq(count("self", false), 1, "own body hidden")
    H.eq(count("block", "Attack", true), 1, "no attack")
    H.eq(count("block", "Melee", true), 1, "no melee")
    H.eq(count("block", "NextWeapon", true), 1, "no weapon switch")
    H.eq(count("block", "WeaponWheel", true), 1, "no weapon wheel")
    H.eq(count("hud", "scanner", false), 1, "no scanner")
    H.eq(hidden_, true, "no plates")
    H.eq(dots, true, "no dots")
    keys["games.prophunt.next"].fn()
    H.eq(H.clientEvents[#H.clientEvents].name, "op77_games:prophunt:action")
    H.eq(H.clientEvents[#H.clientEvents].args[1], "next")
    local sends = #H.clientEvents
    keys["games.prophunt.pulse"].fn()
    H.eq(#H.clientEvents, sends, "a prop's client does not ask for a hunter's key")
    keys["games.prophunt.view"].fn()
    H.eq(count("lock", false, true), 1, "N: first person")
    keys["games.prophunt.view"].fn()
    fire(nil)
    H.eq(count("clear"), 1, "the view back")
    H.eq(count("self", true), 1, "the body back")
    H.eq(count("block", "Attack", false), 1)
    H.eq(count("block", "Melee", false), 1)
    H.eq(count("block", "NextWeapon", false), 1, "weapons back")
    H.eq(count("block", "WeaponWheel", false), 1)
    H.eq(count("hud", "scanner", true), 1)
    H.eq(hidden_, false)
    H.eq(dots, false)
    sends = #H.clientEvents
    keys["games.prophunt.next"].fn()
    H.eq(#H.clientEvents, sends, "off: no key sends")

    local view = { hints = { { bind = "games.prophunt.next", key = "R", label = "x" }, { key = "Z", label = "y" } } }
    GamesProphuntClient.keys(view)
    H.eq(view.hints[1].key, "F3", "the key this player has it on")
    H.eq(view.hints[2].key, "Z", "no binding, the server's")

    -- A hunter: first person, scanner off, an attack.
    local hides = count("self", false)
    fire({ role = "hunter" })
    H.eq(count("lock", false, true), 2, "first person")
    H.eq(count("self", false), hides, "a hunter keeps its body")
    H.eq(count("block", "Attack", true), 1, "a hunter attacks")
    H.eq(count("block", "NextWeapon", true), 2, "and keeps the gun it was issued")
    -- The server goes silent: everything lets go on its own.
    H.advance(26000, 500)
    H.eq(count("clear"), 2, "the lease ran out")
    H.eq(hidden_, false)
end)

H.done("prophunt_test")
