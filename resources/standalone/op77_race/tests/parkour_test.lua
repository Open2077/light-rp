-- The parkour race (race.parkour): a rooftop race whose runners are lent double jump and
-- dash for the race only. Registration, courses, the grant and its removal at every exit,
-- own implants left alone, race.foot unchanged, hostile events. The fake dash and cyberware
-- natives (H.installAbilityNatives) follow the guides: nothing here ran on a real server.
local H = dofile("tests/harness.lua")
H.installBotNatives()
H.installAbilityNatives()
local LOBBY = { x = -756.581, y = 777.257, z = 22.454, bucket = 0 }
for id = 1, 8 do H.addPlayer(id, "P" .. id, { x = LOBBY.x + id * 3, y = LOBBY.y, z = LOBBY.z, bucket = 0 }) end
math.randomseed(77)
H.refuse.define = true
H.load(H.SERVER)
local E, L, A, C, P, Config, S = RaceEngine, RaceLobby, RaceActivity, RaceCourses, RaceParkour, RaceConfig, RaceShared
local parkour = A.byKey.parkour
local toGo = (Config.engine.loadSeconds.parkour + Config.engine.countdownSeconds) * 1000 + 1500

local function racer(id) return E.racers[id] end
local function instance(id) return E.instanceOf(id) end
local function hasDash(id) local g = H.dash[id]; return g ~= nil and g.owner == "op77_race" end
local function hasLease(id) return H.leaseOf(id) ~= nil end
local function restored(id) return H.leaseOf(id) == nil and P.held[id] == nil end

local matchSeq = 0
local function match(ids, extra)
    matchSeq = matchSeq + 1
    local m = { id = "m" .. matchSeq, ranked = false, friendly = true, players = ids }
    for key, value in pairs(extra or {}) do m[key] = value end
    return m
end
-- A match starts as soon as all its players are in.
local function start(ids, course, extra)
    local m = match(ids, extra)
    for _, id in ipairs(ids) do
        H.fire("op77_lightrp:activity:join", id, "race.parkour", { match = m, course = course, ranked = m.ranked })
    end
end
local function toRacing(ids, course, extra)
    start(ids, course, extra)
    H.advance(toGo)
    for _, id in ipairs(ids) do H.eq(racer(id) and racer(id).state, "racing", "racing") end
    return instance(ids[1])
end
local function clear()
    for id = 1, 8 do
        local r = racer(id)
        if r then H.fire("op77_lightrp:activity:leaveRequest", id, r.activityId)
        elseif L.queuedIn(id) then H.fire("op77_lightrp:activity:leaveRequest", id, "race." .. L.queuedIn(id)) end
    end
    local guard = 0
    while (H.count(E.racers) > 0 or H.count(E.instances) > 0 or H.count(P.held) > 0) and guard < 200 do H.advance(250); guard = guard + 1 end
    H.eq(H.count(E.racers), 0, "everyone out")
    H.eq(H.count(P.held), 0, "nothing still held")
    for id = 1, 8 do
        H.eq(hasDash(id), false, "no dash left")
        H.eq(hasLease(id), false, "no lease left")
    end
    H.advance(1000)
end
local function step(id)
    local inst, r = instance(id), racer(id)
    local cp = inst.course.checkpoints[r.nextCheckpoint].position
    H.move(id, cp.x, cp.y, cp.z)
    H.advance(600)
end
local function resultFor(id)
    local found
    for _, event in ipairs(H.eventsNamed("op77_lightrp:activity:result")) do
        if event.args[1] == id then found = event.args[3] end
    end
    return found
end
local function kill(id)
    H.players[id].life = "dead"
    H.fire("onPlayerLifeStateChanged", id)
end
local shortId -- the three-step course the editor test saves
local function read(path)
    local file = assert(io.open(path, "r"))
    local text = file:read("a")
    file:close()
    return text
end

H.test("the platform refuses the abilities: no parkour race, said so; the rest goes on", function()
    H.advance(300)
    H.eq(P.available(), false, "nothing defined")
    H.fire("op77_lightrp:activity:join", 1, "race.parkour", {})
    H.ok(H.noticeFor(1, "not available"), "told why")
    H.eq(L.queuedIn(1), nil, "not queued")
    H.fire("op77_lightrp:activity:join", 1, "race.foot", {})
    H.eq(L.queuedIn(1), "foot", "the rooftop race does not care")
    H.fire("op77_lightrp:activity:leaveRequest", 1, "race.foot")
    H.refuse.define = false
    H.advance(Config.parkour.defineRetryMs + 500)
    H.eq(P.available(), true, "defined on a later try")
end)

H.test("definitions: session dash, legs lease, this resource's, never the implant permission", function()
    H.ok(H.logged("dash defined"), "logged")
    H.eq(Config.parkour.dash.profile, "dash")
    H.eq(Config.parkour.legs.slot, "legs")
    H.eq(Config.parkour.legs.profile, "double_jump")
    H.ok(Config.parkour.leaseMs <= 300000, "within the platform's ceiling")
    local manifest = read("open77.lua")
    H.ok(manifest:find('server_script "server/parkour.lua"', 1, true), "loaded")
    for _, name in ipairs({ "players.dash.define", "players.dash.manage", "players.dash.read",
        "players.cyberware.define", "players.cyberware.read", "players.cyberware.temporary" }) do
        H.ok(manifest:find('"' .. name .. '"', 1, true), "declares " .. name)
    end
    H.eq(manifest:find('"players.cyberware.manage"', 1, true), nil, "cannot touch an owned implant")
    H.eq(manifest:find('"players.cyberware.identity"', 1, true), nil, "cannot rebind a character")
    local code = read("server/parkour.lua")
    H.eq(code:find("%.install"), nil, "never installs")
    H.eq(code:find("[%.%(]remove%f[%A]"), nil, "never removes")
end)

H.test("registration: race.parkour, kind race, its courses as join choices, no bots", function()
    A.register()
    local def = H.core.registered["race.parkour"]
    H.ok(def, "registered")
    H.eq(def.kind, "race")
    H.eq(def.modeKey, "course")
    H.eq(def.minPlayers, 2); H.eq(def.maxPlayers, 8)
    H.eq(#def.modes, 1)
    H.eq(def.modes[1].id, "rooftop-parkour")
    H.eq(def.botFill, nil, "never offers bots")
    H.eq(def.pve, nil)
    H.eq(H.core.registered["race.foot"].modeKey, nil, "the rooftop race rotates its courses as before")
    H.eq(H.core.registered["race.foot"].modes, nil)
end)

H.test("the built-in parkour course is Rooftop Run, coordinate for coordinate", function()
    local run, roof = C.get("rooftop-run"), C.get("rooftop-parkour")
    H.ok(roof and roof.builtin and roof.parkour == true and S.onFoot(roof), "a built-in parkour course")
    H.eq(run.parkour, nil, "Rooftop Run stays what it was")
    H.eq(#roof.checkpoints, #run.checkpoints)
    H.eq(S.distance(roof.start.position, run.start.position), 0.0)
    for index, checkpoint in ipairs(run.checkpoints) do
        H.eq(S.distance(roof.checkpoints[index].position, checkpoint.position), 0.0, "checkpoint " .. index)
    end
end)

H.test("a parkour course is the parkour race's alone; the others' lists do not change", function()
    H.eq(table.concat(C.ids("parkour"), ","), "rooftop-parkour")
    H.eq(table.concat(C.ids("foot"), ","), "rooftop-run")
    for _, id in ipairs(C.ids("trial")) do H.ok(id ~= "rooftop-parkour", "not in the time trial") end
    H.eq(C.eligible(C.get("rooftop-parkour"), "foot"), false)
    H.eq(C.eligible(C.get("rooftop-run"), "parkour"), false)
    H.eq(C.eligible(C.get("street-circuit"), "parkour"), false)
    H.eq(select(2, C.normalize({ name = "Bad", parkour = true, vehicle = "archer_hella",
        start = { position = { x = 0, y = 0, z = 0 } }, checkpoints = {} })), "parkour_on_foot")
    H.fire("op77_lightrp:activity:join", 1, "race.trial", { course = "rooftop-parkour" })
    H.eq(racer(1), nil, "no time trial on it")
end)

H.test("the editor builds a parkour course; saved, it joins the catalogue; the file keeps it", function()
    H.command("race.editor", 1, { "open", "--parkour" }, "race.editor open --parkour")
    H.ok(RaceEditor.sessions[1].draft.parkour, "a parkour draft")
    H.move(1, 100, 100, 40)
    H.command("race.editor", 1, { "start" }, "race.editor start")
    H.move(1, 110, 100, 60)
    H.command("race.editor", 1, { "cp" }, "race.editor cp")
    H.move(1, 130, 100, 62)
    H.command("race.editor", 1, { "cp" }, "race.editor cp")
    H.command("race.editor", 1, { "name", "Short Parkour" }, "race.editor name Short Parkour")
    H.command("race.editor", 1, { "type", "sprint" }, "race.editor type sprint")
    H.command("race.editor", 1, { "save" }, "race.editor save")
    local id
    for _, summary in ipairs(C.list("parkour")) do if summary.name == "Short Parkour" then id = summary.id end end
    H.ok(id, "saved as a parkour course")
    H.eq(C.get(id).parkour, true)
    H.eq(H.files["courses/" .. id .. ".json"].parkour, true, "in the file")
    H.command("race.editor", 1, { "parkour", "off" }, "race.editor parkour off")
    H.command("race.editor", 1, { "save" }, "race.editor save")
    H.eq(C.get(id).parkour, nil, "switched off")
    H.ok(C.eligible(C.get(id), "foot"), "then an ordinary rooftop course")
    H.command("race.editor", 1, { "parkour", "on" }, "race.editor parkour on")
    H.command("race.editor", 1, { "save" }, "race.editor save")
    H.command("race.editor", 1, { "close" }, "race.editor close")
    H.eq(H.count(H.dash), 0, "the editor grants nothing")
    H.eq(C.eligible(C.get(id), "foot"), false)
    -- the course every later test races: three steps, a known id
    C.remove(id)
    local saved = C.save(1, { name = "Test Line", type = "sprint", vehicle = "on_foot", parkour = true, checkpointRadius = 3,
        start = { position = { x = 100, y = 100, z = 40 }, heading = 90 },
        checkpoints = { { position = { x = 110, y = 100, z = 60 } }, { position = { x = 130, y = 100, z = 62 } },
            { position = { x = 150, y = 100, z = 64 } } } }, "Staff")
    H.ok(saved, "test course")
    shortId = saved.id
    H.move(1, LOBBY.x + 3, LOBBY.y, LOBBY.z)
end)

local function shortCourse() return shortId end

H.test("in the queue nothing; on the line the legs, in the race's bucket; the dash at GO, never before", function()
    H.fire("op77_lightrp:activity:join", 1, "race.parkour", { course = shortCourse(), ranked = true })
    H.fire("op77_lightrp:activity:join", 2, "race.parkour", { course = shortCourse(), ranked = true })
    H.eq(L.queuedIn(1), "parkour", "queued")
    H.advance(1500)
    H.eq(H.abilityCalls("dash.grant"), 0, "no dash in the queue")
    H.eq(H.abilityCalls("cyber.lease"), 0, "no lease in the queue")
    H.advance(parkour.joinSeconds * 1000)
    local inst = instance(1)
    H.ok(inst and inst.abilities, "the instance lends")
    H.eq(inst.course.id, shortCourse(), "the course chosen")
    H.eq(inst.mode, "parkour")
    H.advance(1000)
    H.eq(inst.phase, "loading")
    local l = H.leases[1]
    H.ok(l, "lent once on the line")
    H.eq(l.bucket, inst.bucket, "after the bucket move, which would end it")
    H.eq(l.definition, Config.parkour.legs.id)
    H.eq(l.grade, Config.parkour.grade)
    H.eq(hasDash(1), false, "no dash during the hold")
    H.ok(H.players[1].frozen, "held on the line")
    H.advance(Config.engine.loadSeconds.parkour * 1000 - 1000)
    H.eq(inst.phase, "countdown", "the legs were there in time")
    H.eq(hasDash(1), false, "no dash in the countdown")
    H.advance(Config.engine.countdownSeconds * 1000 + 300)
    H.eq(racer(1).state, "racing")
    H.ok(hasDash(1) and hasDash(2), "dash at GO")
    H.eq(H.dash[1].definition, Config.parkour.dash.id)
    H.ok(H.noticeFor(1, "Double jump and dash"), "told, with the key")
    H.eq(H.leases[1].phase, "active")
    H.eq(H.durable[1], nil, "the durable record never written")
    clear()
end)

H.test("the start waits for slow legs, not for ever; a runner left without them races on and is told", function()
    H.refuse.lease[3] = true
    start({ 3, 4 }, shortCourse())
    H.advance(Config.engine.loadSeconds.parkour * 1000 + 2000)
    local inst = instance(3)
    H.eq(inst.phase, "loading", "the countdown waits")
    H.advance(Config.parkour.readyWaitSeconds * 1000)
    H.ok(inst.phase == "countdown" or inst.phase == "active", "but not for ever")
    H.advance(Config.engine.countdownSeconds * 1000 + Config.parkour.checkAfterMs + 1500)
    H.eq(racer(3).state, "racing", "races on")
    H.ok(H.noticeFor(3, "did not come through"), "told once")
    H.eq(H.noticeFor(4, "did not come through"), nil, "the other is fine")
    H.ok(H.logged("is racing without its abilities"), "logged")
    H.refuse.lease[3] = nil
    H.advance(1500)
    H.ok(hasLease(3), "a refusal is tried again")
    clear()
end)

H.test("finish: lost at the line, still in the instance, while the others keep theirs", function()
    local inst = toRacing({ 1, 2 }, shortCourse())
    step(1); step(1)
    -- one engine tick, by hand: the crossing itself takes it, not the sweep a second later
    local line = inst.course.checkpoints[racer(1).nextCheckpoint].position
    H.move(1, line.x, line.y, line.z)
    E.tick(E.nowMs())
    H.eq(racer(1).state, "finished")
    H.eq(hasDash(1), false, "dash gone at the line")
    H.eq(H.leases[1] and H.leases[1].phase, "restoring", "lease on its way out at the line")
    H.ok(hasDash(2) and hasLease(2), "the runner behind keeps theirs")
    H.advance(1500)
    H.eq(hasLease(1), false, "restored")
    H.eq(P.held[1], nil, "nothing held")
    H.ok(racer(1) ~= nil, "still watching")
    H.advance(3000)
    H.eq(hasDash(1), false, "and never given back while watching")
    clear()
end)

H.test("DNF by the finish window", function()
    toRacing({ 1, 2 }, shortCourse())
    step(1); step(1); step(1)
    H.advance(Config.engine.finishGraceSeconds * 1000 + 1000)
    H.eq(racer(2).state, "dnf")
    H.eq(hasDash(2), false, "dash gone")
    H.advance(1000)
    H.eq(hasLease(2), false, "lease gone")
    clear()
end)

H.test("DNF by a vehicle in a foot race", function()
    toRacing({ 3, 4 }, shortCourse())
    H.seats[3] = { vehicleId = 99, seat = "seat_front_left" }
    H.advance(300)
    H.seats[3] = nil
    H.eq(hasDash(3), false, "dash gone")
    H.advance(1000)
    H.eq(hasLease(3), false, "lease gone")
    H.ok(hasDash(4), "the other races on")
    clear()
end)

H.test("leave: taken before the core takes the player back", function()
    toRacing({ 1, 2 }, shortCourse())
    local order = {}
    local real = H.coreExports.activityLeave
    H.coreExports.activityLeave = function(...)
        order[#order + 1] = { dash = hasDash(1), released = H.abilityCalls("cyber.releaseLease", 1) }
        return real(...)
    end
    local released = H.abilityCalls("cyber.releaseLease", 1)
    H.fire("op77_lightrp:activity:leaveRequest", 1, "race.parkour")
    H.advance(600)
    H.coreExports.activityLeave = real
    H.eq(order[1].dash, false, "dash already gone")
    H.ok(order[1].released > released, "lease already released")
    H.advance(1000)
    H.ok(restored(1), "nothing left")
    H.eq(racer(1), nil)
    clear()
end)

H.test("/race.leave and the core dropping the player (a character switch)", function()
    toRacing({ 1, 2, 3 }, shortCourse())
    H.command("race.leave", 1, {}, "race.leave")
    H.fire("op77_lightrp:activity:dropped", 2, "race.parkour", "character")
    H.eq(hasDash(1), false); H.eq(hasDash(2), false)
    H.advance(1500)
    H.ok(restored(1) and restored(2), "nothing left")
    H.ok(hasDash(3) and hasLease(3), "the third races on")
    clear()
end)

H.test("disconnect: the session takes everything, no call on a gone player", function()
    toRacing({ 5, 6 }, shortCourse())
    H.dash[5], H.leases[5] = nil, nil -- what the platform does with the session
    H.fire("onPlayerDisconnected", 5)
    H.eq(P.held[5], nil, "forgotten at once")
    local calls = #H.abilityLog
    H.advance(1500)
    for index = calls + 1, #H.abilityLog do H.ok(H.abilityLog[index].id ~= 5, "no call for the gone player") end
    H.ok(hasDash(6) and hasLease(6), "the other races on")
    clear()
end)

H.test("a player gone without the event is dropped by the sweep", function()
    toRacing({ 5, 6 }, shortCourse())
    local p5 = H.players[5]
    H.players[5] = nil
    H.dash[5], H.leases[5] = nil, nil
    E.racers[5].releasing = true
    H.advance(1500)
    H.eq(P.held[5], nil, "not chased for ever")
    H.players[5] = p5
    E.racers[5].releasing = nil
    clear()
end)

H.test("death in the race: the platform ends the lease, the revived runner gets it back", function()
    toRacing({ 1, 2 }, shortCourse())
    local first = H.leases[1].id
    kill(1)
    H.eq(H.leases[1] and H.leases[1].id, first)
    H.leaseOf(1)
    H.eq(H.leases[1].phase, "restoring", "death ended it")
    H.advance(4000)
    H.eq(H.players[1].life, "alive", "revived at the last checkpoint")
    H.eq(racer(1).state, "racing")
    H.ok(H.leases[1] and H.leases[1].id ~= first, "a new lease")
    H.ok(hasDash(1), "dash still there")
    clear()
end)

H.test("a new body without the dash gets it again", function()
    toRacing({ 1, 2 }, shortCourse())
    H.dash[1] = nil
    H.advance(1500)
    H.ok(hasDash(1), "granted again")
    clear()
end)

H.test("death on the way out: revived to go back, nothing lent again", function()
    toRacing({ 1, 2 }, shortCourse())
    H.players[1].life = "dead"
    H.leaseOf(1)
    local leases = H.abilityCalls("cyber.lease", 1)
    local grants = H.abilityCalls("dash.grant", 1)
    H.fire("op77_lightrp:activity:leaveRequest", 1, "race.parkour")
    H.eq(hasDash(1), false, "dash gone first")
    H.advance(4000)
    H.eq(H.players[1].life, "alive", "revived")
    H.eq(racer(1), nil, "returned")
    H.eq(H.abilityCalls("cyber.lease", 1), leases, "no lease on the way out")
    H.eq(H.abilityCalls("dash.grant", 1), grants, "no grant on the way out")
    H.ok(restored(1), "nothing left")
    clear()
end)

H.test("a finisher who dies keeps nothing", function()
    toRacing({ 1, 2 }, shortCourse())
    step(1); step(1); step(1)
    H.advance(1000)
    local grants = H.abilityCalls("dash.grant", 1)
    kill(1)
    H.advance(1500)
    H.eq(H.abilityCalls("dash.grant", 1), grants)
    H.eq(hasLease(1), false)
    H.players[1].life = "alive"
    clear()
end)

H.test("the lease runs out mid-race: lent again, once the old one is gone", function()
    toRacing({ 1, 2 }, shortCourse())
    local first = H.leases[1].id
    H.leases[1].expiresAt = H.clock + 200
    H.advance(2500)
    H.ok(H.leases[1] and H.leases[1].id ~= first, "lent again")
    H.eq(racer(1).state, "racing")
    H.eq(H.logged("lease_active"), false, "never asked over a lease still there")
    clear()
end)

H.test("own legs: no lease at all, the implant is untouched", function()
    local record = { revision = 7, legs = { definition = "lightrp.legs", grade = { id = "training" }, instanceId = "i1" } }
    H.durable[3] = record
    local leases, releases = H.abilityCalls("cyber.lease", 3), H.abilityCalls("cyber.releaseLease", 3)
    toRacing({ 3, 4 }, shortCourse())
    H.eq(H.abilityCalls("cyber.lease", 3), leases, "no lease over a paid implant")
    H.eq(H.leases[3], nil)
    H.ok(hasLease(4), "the runner without legs has one")
    H.eq(instance(3).phase, "active", "own legs do not hold the start")
    H.fire("op77_lightrp:activity:leaveRequest", 3, "race.parkour")
    H.advance(1500)
    H.eq(H.durable[3], record, "same record")
    H.eq(record.revision, 7); H.eq(record.legs.instanceId, "i1")
    H.eq(H.abilityCalls("cyber.releaseLease", 3), releases, "nothing to release")
    clear()
    H.durable[3] = nil
end)

H.test("own dash: no grant, no revoke, still there after the race", function()
    H.dash[3] = { owner = "op77_lightrp", definition = "lightrp.dash.basic" }
    local grants, revokes = H.abilityCalls("dash.grant", 3), H.abilityCalls("dash.revoke", 3)
    toRacing({ 3, 4 }, shortCourse())
    H.eq(H.abilityCalls("dash.grant", 3), grants, "the current read says it is another's")
    H.eq(H.dash[3].owner, "op77_lightrp")
    H.ok(H.noticeFor(3, "Double jump and dash"), "told like the others")
    H.fire("op77_lightrp:activity:leaveRequest", 3, "race.parkour")
    H.advance(1500)
    H.eq(H.abilityCalls("dash.revoke", 3), revokes, "nothing to revoke")
    H.eq(H.dash[3] and H.dash[3].owner, "op77_lightrp", "theirs stays")
    H.dash[3] = nil
    clear()
end)

H.test("own dash granted between the read and the grant: grant_owned is theirs, not a refusal", function()
    local current = Open77.dash.current
    Open77.dash.current = function(id) if id == 3 then return nil end return current(id) end
    H.dash[3] = { owner = "op77_lightrp", definition = "lightrp.dash.basic" }
    toRacing({ 3, 4 }, shortCourse())
    Open77.dash.current = current
    H.ok(P.held[3].ownDash, "known as theirs")
    H.fire("op77_lightrp:activity:leaveRequest", 3, "race.parkour")
    H.advance(1500)
    H.eq(H.dash[3].owner, "op77_lightrp", "still theirs")
    H.dash[3] = nil
    clear()
end)

H.test("an implant whose dash lapsed: ours fills in, revoking it clears the way for theirs", function()
    toRacing({ 3, 4 }, shortCourse())
    H.ok(hasDash(3), "ours while Light RP's grant is missing")
    H.fire("op77_lightrp:activity:leaveRequest", 3, "race.parkour")
    H.advance(1500)
    H.eq(H.dash[3], nil, "Light RP's check finds none and grants its own")
    clear()
end)

H.test("a refused take-back is asked again until the platform says it is gone", function()
    toRacing({ 1, 2 }, shortCourse())
    H.refuse.revoke, H.refuse.release = 2, 2
    H.fire("op77_lightrp:activity:leaveRequest", 1, "race.parkour")
    H.ok(hasDash(1), "the first revoke was refused")
    H.advance(600)
    H.eq(racer(1), nil, "the player is back anyway")
    H.advance(4000)
    H.eq(hasDash(1), false, "revoked on a later try")
    H.eq(H.refuse.revoke, 0)
    H.ok(restored(1), "and only then forgotten")
    H.refuse.release = 0 -- the bucket change on the way back ended that lease before a third ask
    clear()
end)

H.test("a refused release at the line, no bucket change to help: asked again, gone, only then forgotten", function()
    toRacing({ 1, 2 }, shortCourse())
    H.refuse.release = 2
    step(1); step(1); step(1)
    H.eq(racer(1).state, "finished")
    H.ok(H.leases[1] ~= nil and H.leases[1].phase ~= "restoring", "the first ask was refused")
    H.ok(P.held[1] ~= nil, "still tracked")
    H.advance(3500)
    H.eq(H.refuse.release, 0, "asked until it went through")
    H.ok(restored(1), "gone")
    H.ok(racer(1) ~= nil, "without leaving the instance")
    clear()
end)

H.test("back in a race while the last lease still restores: one lease at a time", function()
    H.restoreMs = 3000
    toRacing({ 1, 2 }, shortCourse())
    clear()
    H.restoreMs = 3000
    toRacing({ 3, 4 }, shortCourse())
    local old = H.leases[3].id
    H.fire("op77_lightrp:activity:leaveRequest", 3, "race.parkour")
    H.advance(300)
    H.eq(H.leases[3].id, old)
    H.fire("op77_lightrp:activity:leaveRequest", 4, "race.parkour")
    H.advance(600)
    start({ 3, 4 }, shortCourse())
    H.advance(1200)
    H.eq(H.leases[3] and H.leases[3].id, old, "the old one still restoring")
    H.advance(toGo + 3000)
    H.ok(H.leases[3] and H.leases[3].id ~= old, "the new one once it is gone")
    H.eq(H.logged("lease_active"), false, "never asked over the old one")
    H.restoreMs = 500
    clear()
end)

H.test("match: unranked even if the core says ranked, its own heat, the chosen course, no bots", function()
    local events = #H.eventsNamed("op77_lightrp:activity:recap")
    local inst = toRacing({ 1, 2 }, shortCourse(), { ranked = true, friendly = false, bots = { 3 } })
    H.eq(inst.match ~= nil, true)
    H.eq(inst.course.id, shortCourse())
    H.eq(#(inst.bots or {}), 0, "no bots")
    H.eq(H.count(H.npcs), 0)
    H.ok(racer(1).unranked and racer(2).unranked, "unranked")
    H.eq(H.noticeFor(1, "Ranked match"), nil, "not announced as ranked")
    H.ok(H.noticeFor(1, "Unranked match"), "announced as unranked")
    local key = racer(1).key
    local payload = E.payload(1)
    H.ok(payload.unranked and payload.mode == "parkour", "the HUD says so")
    step(1); step(1); step(1)
    step(2); step(2); step(2)
    local result = resultFor(1)
    H.ok(result, "a result")
    H.eq(result.unranked, true)
    H.eq(result.reputation, 0)
    H.eq(result.placement, 1)
    H.eq(result.stats.mode, "parkour")
    H.ok(result.recap and #result.recap.rows == 2, "the recap travels with it")
    H.ok(#H.eventsNamed("op77_lightrp:activity:recap") > events, "and the final board")
    H.eq(RaceRecords.best(inst.course.id, inst.course.revision, key), nil, "no best time written")
    clear()
end)

H.test("a match without a course runs a parkour course, never another kind", function()
    start({ 1, 2 }, nil)
    H.advance(500)
    local inst = instance(1)
    H.ok(inst and inst.course.parkour, "a parkour course")
    clear()
end)

H.test("queue: the first choice sets the heat; a later other choice is told; the choice dies with the queue", function()
    H.fire("op77_lightrp:activity:join", 1, "race.parkour", { course = shortCourse() })
    H.fire("op77_lightrp:activity:join", 2, "race.parkour", { course = "rooftop-parkour" })
    H.eq(L.queues.parkour.course, shortCourse())
    H.ok(H.noticeFor(2, "first choice in the queue"), "told")
    H.fire("op77_lightrp:activity:leaveRequest", 1, "race.parkour")
    H.fire("op77_lightrp:activity:leaveRequest", 2, "race.parkour")
    H.eq(L.queues.parkour.course, nil, "gone with the queue")
    H.fire("op77_lightrp:activity:join", 1, "race.parkour", {})
    H.fire("op77_lightrp:activity:join", 2, "race.parkour", { course = shortCourse() })
    H.advance(parkour.joinSeconds * 1000 + 500)
    H.eq(instance(1).course.id, shortCourse(), "no choice takes the next one's")
    clear()
end)

H.test("a chosen course deleted before the heat: another parkour course, never a foot one", function()
    local spare = C.save(1, { name = "Spare Line", type = "sprint", vehicle = "on_foot", parkour = true, checkpointRadius = 3,
        start = { position = { x = 0, y = 0, z = 40 } }, checkpoints = { { position = { x = 10, y = 0, z = 40 } } } }, "Staff")
    H.fire("op77_lightrp:activity:join", 1, "race.parkour", { course = spare.id })
    H.fire("op77_lightrp:activity:join", 2, "race.parkour", {})
    H.ok(C.remove(spare.id), "deleted")
    H.advance(parkour.joinSeconds * 1000 + 500)
    local inst = instance(1)
    H.ok(inst and inst.course.parkour, "still parkour")
    clear()
end)

H.test("staff bot mode: no lone heat, no bots, /race.force still works", function()
    H.fire("op77_lightrp:activity:bots", true)
    H.fire("op77_lightrp:activity:join", 1, "race.parkour", {})
    H.advance(1000)
    H.eq(L.windowRemainingMs("parkour"), nil, "one runner opens nothing")
    H.command("race.force", 0, { "parkour" }, "race.force parkour")
    H.advance(500)
    H.ok(instance(1), "forced")
    H.eq(#(instance(1).bots or {}), 0, "no bots")
    H.fire("op77_lightrp:activity:bots", false)
    clear()
end)

H.test("hostile joins: another kind of course, junk, every door refuses before anything is lent", function()
    local calls = #H.abilityLog
    H.fireNet("op77_race:join", 1, { activity = "parkour", course = "street-circuit" })
    H.advance(400)
    H.eq(L.queuedIn(1), nil, "a street course is no parkour course")
    H.ok(H.noticeFor(1, "does not exist"), "told")
    H.fireNet("op77_race:join", 1, { activity = "parkour", course = "rooftop-run" })
    H.advance(400)
    H.eq(L.queuedIn(1), nil, "nor is the rooftop run")
    H.fireNet("op77_race:join", 1, { activity = "parkour", course = 42 })
    H.advance(400)
    H.fire("op77_lightrp:activity:join", 2, "race.parkour", { course = {} })
    H.eq(L.queuedIn(2), nil, "a table")
    H.fire("op77_lightrp:activity:join", 2, "race.parkour", { course = ("x"):rep(5000) })
    H.eq(L.queuedIn(2), nil, "a long string")
    H.fire("op77_lightrp:activity:join", 2, "race.parkour", { course = "../../server" })
    H.eq(L.queuedIn(2), nil, "a path")
    H.command("race.join", 3, { "parkour", "shion-sprint" }, "race.join parkour shion-sprint")
    H.eq(L.queuedIn(3), nil, "/race.join too")
    L.leave(1)
    for index = calls + 1, #H.abilityLog do
        local op = H.abilityLog[index].op
        H.ok(op ~= "dash.grant" and op ~= "cyber.lease", "nothing lent")
    end
    clear()
end)

H.test("hostile events: nobody gets anything from the client side, in or out of a race", function()
    local grants, leases = H.abilityCalls("dash.grant"), H.abilityCalls("cyber.lease")
    for _, name in ipairs({ "op77_race:ready", "op77_race:leave", "op77_race:restart", "op77_race:respawn" }) do
        H.fireNet(name, 4)
        H.advance(1100)
    end
    H.fireNet("op77_race:editorAction", 4, { action = "start" })
    H.fireNet("op77_race:join", 4, { activity = "nothing" })
    H.fireNet("op77_race:join", 4, "not a table")
    H.advance(1500)
    H.eq(H.abilityCalls("dash.grant"), grants, "no grant")
    H.eq(H.abilityCalls("cyber.lease"), leases, "no lease")
    for name in pairs(H.netHandlers) do
        H.ok(not name:lower():find("abilit") and not name:lower():find("dash") and not name:lower():find("lease"),
            "no net door to the abilities: " .. name)
    end
    -- a racer out of the race asks for the checkpoint, the restart, the state
    toRacing({ 1, 2 }, shortCourse())
    H.fire("op77_lightrp:activity:leaveRequest", 1, "race.parkour")
    H.advance(1500)
    grants, leases = H.abilityCalls("dash.grant", 1), H.abilityCalls("cyber.lease", 1)
    for _, name in ipairs({ "op77_race:respawn", "op77_race:restart", "op77_race:ready" }) do
        H.fireNet(name, 1)
        H.advance(1100)
    end
    H.eq(H.abilityCalls("dash.grant", 1), grants, "nothing after the exit")
    H.eq(H.abilityCalls("cyber.lease", 1), leases)
    H.eq(hasDash(1), false)
    -- a racer in it cannot restart the heat (a trial's key), and END keeps what they have
    H.fireNet("op77_race:restart", 2)
    H.eq(racer(2).state, "racing")
    H.advance(2100)
    H.fireNet("op77_race:respawn", 2)
    H.advance(1000)
    H.ok(hasDash(2) and hasLease(2), "still lent")
    clear()
end)

H.test("race.foot is exactly what it was: no native, no lease, no grant, ranked, its rule in the README", function()
    local def = A.byKey.foot
    H.eq(def.abilities, nil); H.eq(def.unranked, nil); H.eq(def.noBots, nil)
    H.eq(def.description, "Two to eight runners across the rooftops. No implants handed out.")
    H.ok(read("README.md"):find("**Nothing is handed out.** No Athlete legs, Dash, Overdrive, implant or weapon.", 1, true),
        "the README's rule stands")
    local before = #H.abilityLog
    H.fire("op77_lightrp:activity:join", 1, "race.foot", { ranked = true })
    H.fire("op77_lightrp:activity:join", 2, "race.foot", { ranked = true })
    H.advance(def.joinSeconds * 1000 + 500)
    local inst = instance(1)
    H.ok(inst and inst.mode == "foot", "a rooftop race")
    H.eq(inst.course.id, "rooftop-run", "on its own course")
    H.eq(inst.abilities, nil)
    H.advance(toGo)
    H.eq(racer(1).state, "racing")
    H.eq(racer(1).unranked, nil, "ranked as before")
    H.eq(H.count(P.held), 0)
    H.eq(#H.abilityLog, before, "not one ability native")
    H.fire("op77_lightrp:activity:leaveRequest", 1, "race.foot")
    H.fire("op77_lightrp:activity:leaveRequest", 2, "race.foot")
    H.advance(3000)
    H.eq(#H.abilityLog, before, "nor on the way out")
    clear()
end)

H.test("a time trial and a street race never reach it either", function()
    local before = #H.abilityLog
    H.fire("op77_lightrp:activity:join", 3, "race.trial", { course = "rooftop-run" })
    H.advance(1000)
    H.ok(instance(3), "a trial")
    H.eq(instance(3).abilities, nil)
    H.advance(toGo)
    H.eq(#H.abilityLog, before)
    clear()
end)

H.test("a lease the platform failed: forgotten and lent again; an own record stays out of it", function()
    toRacing({ 1, 2 }, shortCourse())
    local first = H.leases[1].id
    H.leases[1].phase = "failed"
    H.advance(1500)
    H.ok(H.leases[1] and H.leases[1].id ~= first, "lent again")
    H.eq(P.held[1].lease, H.leases[1].id, "the new one is tracked")
    -- with an implant of their own by now, nothing more is lent
    local second = H.leases[2].id
    H.leases[2].phase = "failed"
    H.durable[2] = { revision = 1, legs = { definition = "own" } }
    H.advance(1500)
    H.eq(H.leases[2].id, second, "not lent over a record of their own")
    H.eq(P.held[2].lease, nil)
    H.eq(P.held[2].ownLegs, true)
    H.durable[2], H.leases[2] = nil, nil
    clear()
end)

H.test("a lease failed at the take-back leaves nothing held", function()
    toRacing({ 1, 2 }, shortCourse())
    H.leases[1].phase = "failed"
    local before = H.abilityCalls("cyber.releaseLease", 1)
    H.fire("op77_lightrp:activity:leaveRequest", 1, "race.parkour")
    H.advance(1500)
    H.eq(P.held[1], nil, "not held for ever")
    H.eq(H.abilityCalls("cyber.releaseLease", 1), before, "nothing to release")
    H.leases[1] = nil
    clear()
end)

H.test("core restart mid-race: everyone back through our fallback, nothing left lent, the queue gone", function()
    H.fire("op77_lightrp:activity:join", 3, "race.parkour", {})
    toRacing({ 1, 2 }, shortCourse())
    H.fire("onResourceStop", "op77_lightrp")
    H.eq(hasDash(1), false, "dash gone at once")
    H.eq(hasDash(2), false)
    H.advance(3000)
    H.ok(restored(1) and restored(2), "nothing left")
    H.eq(racer(1), nil)
    H.eq(H.players[1].bucket, 0, "back in the world")
    H.eq(L.queuedIn(3), nil)
    H.core.owner = {}
    H.fire("onResourceStart", "op77_lightrp")
    H.advance(1000)
    H.ok(A.registered, "registered again")
    clear()
end)

H.test("provider stop mid-race: every grant revoked and every lease released at once", function()
    toRacing({ 1, 2 }, shortCourse())
    local before = H.abilityCalls("cyber.releaseLease")
    H.fire("onResourceStop", "op77_race")
    H.eq(hasDash(1), false); H.eq(hasDash(2), false)
    H.eq(H.abilityCalls("cyber.releaseLease"), before + 2, "both asked")
    H.eq(H.count(P.held), 0, "nothing tracked")
    H.ok(H.players[1].godMode == false, "protections off too")
end)

H.done("parkour_test")
