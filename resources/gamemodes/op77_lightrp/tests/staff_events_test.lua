-- Staff events (server/modules/staff_events.lua) on the world boss engine, host stubbed
-- (the harness of world_boss_test.lua): rights, the three kinds, where, levels, pay or not,
-- silent, several at once, spots, stop / win, audit idempotence, event nights, the command.
local clock = 0
local threads = {}
local function run(ms)
    clock = clock + (ms or 500)
    for i = #threads, 1, -1 do
        local co = threads[i]
        if coroutine.status(co) == "dead" then table.remove(threads, i)
        else local ok, err = coroutine.resume(co); if not ok then error(err) end end
    end
end
local function seconds(n) for _ = 1, n * 2 do run(500) end end
_G.CreateThread = function(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; local ok, err = coroutine.resume(co); if not ok then error(err) end end
_G.Wait = function() coroutine.yield() end
local stored = {}
_G.json = { encode = function(v) stored[#stored + 1] = v; return "#" .. #stored end, decode = function(s) return stored[tonumber(s:sub(2))] end }

local positions, buckets, life = {}, {}, {}
local sent, paid, notices, netHandlers = {}, {}, {}, {}
_G.GetPlayers = function() local t = {} for id in pairs(positions) do t[#t + 1] = tostring(id) end table.sort(t) return t end
_G.GetPlayerRoutingBucket = function(id) return buckets[id] or 0 end
_G.SetPlayerRoutingBucket = function(id, b) buckets[id] = b return true end
_G.GetPlayerIdentifier = function(id) return "license:" .. id end
_G.GetPlayerName = function(id) return positions[id] and ("P" .. id) or nil end
_G.TriggerClientEvent = function(name, target, payload) sent[#sent + 1] = { name = name, target = target, payload = payload } end
_G.TriggerLatentClientEvent = function(name, target, _, payload) sent[#sent + 1] = { name = name, target = target, payload = payload, latent = true }; return #sent end
_G.RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
local events = {}
_G.AddEventHandler = function(name, fn) events[name] = events[name] or {}; table.insert(events[name], fn) end
local function fire(name, ...) for _, fn in ipairs(events[name] or {}) do fn(...) end end

local npcs, npcSeq = {}, 100
_G.Open77 = {
    time = { monotonic = function() return clock / 1000 end },
    acl = { isAllowed = function() return false end },
    npcs = { ai = { native = 2 }, damage = { mortal = 0 },
        create = function(def) npcSeq = npcSeq + 1; local hp = 100 * ((def.difficulty or {}).healthMultiplier or 1); npcs[npcSeq] = { def = def, health = hp, maxHealth = hp, position = def.position }; return npcSeq end,
        get = function(id) local n = npcs[id]; return n and { health = n.health, maxHealth = n.maxHealth, alive = n.health > 0, position = n.position,
            bucket = n.def.bucket, authorityPlayerId = 1, authorityEpoch = 4 } end,
        remove = function(id) npcs[id] = nil; return true end,
        setCombatEnabled = function() return true end, setPerceptionEnabled = function() return true end,
        setTransform = function(id, d) if npcs[id] then npcs[id].position = d.position end; return true end,
        tasks = { attack = function() return true end, guard = function() return true end, patrol = function() return true end, wander = function() return true end } },
    players = {
        position = function(id) local p = positions[id]; return p and { x = p.x, y = p.y, z = p.z, heading = p.heading or 0 } end,
        get = function(id) return { position = positions[id], health = 100, maxHealth = 100, armor = 0, lifePhase = life[id] or "alive" } end,
        getLifeState = function(id) return { phase = life[id] or "alive", bucket = buckets[id] or 0 } end,
        teleport = function(id, spot, opts) return { await = function() positions[id] = { x = spot.x, y = spot.y, z = spot.z }; return true end } end,
        heal = function() return true end, kill = function() return true end, setHealth = function() return true end,
        damage = function() return true end, respawn = function() return true end,
    },
}
_G.LightRpEvents = { net = { mission = "op77_lightrp:mission" } }
_G.LightRpConfig = { spawn = { health = 100 } }
local blips = {}
_G.exports = { op77_map3d = {
    addBlip = function(_, _, b) blips[#blips + 1] = b; return "blip-" .. #blips end, -- exports.op77_map3d:addBlip(-1, b)
    removeBlip = function() return true end } }

local modules, commands, providers = {}, {}, {}
local chars = {}
local hooks = { finished = 0, ended = 0 }
-- the desk's rights: 1 = operator (events + pay), 2 = moderator (events), 3 = a player
local rights = { [1] = { view = true, events = true, eventsPay = true }, [2] = { view = true, events = true } }
-- the audit table and the spots table, when the database is "up"
local audit, spotRows = {}, {}
_G.LightRP = {
    nowMs = function() return clock end, log = function(fmt, ...) if os.getenv("MISSION_TEST_LOG") then print(string.format(fmt, ...)) end end,
    module = function(name, def) def.name = name; modules[#modules + 1] = def; LightRP[name] = LightRP[name] or def; return def end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if m[hook] then m[hook](...) end end end,
    action = function() end,
    command = function(name, _, fn) commands[name] = fn end,
    stateProvider = function(key, fn) providers[key] = fn end,
    state = function() end, result = function() end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, body = n.body } end,
    broadcastNotice = function(n) notices[#notices + 1] = { id = -1, title = n.title, body = n.body } end,
    dialog = function() end, interaction = function() end, removeInteraction = function() end,
    characters = {
        isRegistered = function(id) return chars[id] ~= nil end,
        displayName = function(id) return chars[id] or ("P" .. id) end,
        get = function(id) return chars[id] and { status = "active", identifier = "id-" .. id, key = "default" } end,
    },
    money = { addBank = function(id, amount) paid[id] = (paid[id] or 0) + amount; return true end, format = function(n) return "$" .. n end },
    support = { allowed = function(player, right) return rights[player] ~= nil and rights[player][right] == true end,
        identity = function(player) return chars[player] and { identifier = "id-" .. player } end },
    admin = { handlers = {} },
    staff = { moveTo = function(player, p, heading, cb) positions[player] = { x = p.x, y = p.y, z = p.z, heading = heading }; cb(true) end },
    db = { ready = false, schema = function() end, single = function() end,
        read = function(sql, params)
            if sql:find("FROM lightrp_staff_audit", 1, true) then
                local r = audit[params[1] .. "#" .. params[2]]
                return true, r and { { outcome = r.outcome, detail = r.detail } } or {}
            end
            if sql:find("FROM lightrp_event_spots", 1, true) then
                local out = {}
                for _, s in pairs(spotRows) do out[#out + 1] = s end
                return true, out
            end
            return true, {}
        end,
        run = function(sql, params)
            if sql:find("^INSERT INTO lightrp_staff_audit") then audit[params[1] .. "#" .. params[9]] = { outcome = "pending", detail = "", action = params[6] } end
            if sql:find("^UPDATE lightrp_staff_audit") then local r = audit[params[3] .. "#" .. params[4]]; if r then r.outcome, r.detail = params[1], params[2] end end
            if sql:find("^INSERT INTO lightrp_event_spots") then
                spotRows[params[1]] = { id = params[1], name = params[2], district = params[3], x = params[4], y = params[5], z = params[6], heading = params[7], created_by = params[8], at = 0 }
            end
            if sql:find("^DELETE FROM lightrp_event_spots") then spotRows[params[1]] = nil end
            return true, 1
        end },
}
LightRP.module("hookProbe", {
    onWorldBossFinished = function() hooks.finished = hooks.finished + 1 end,
    onWorldEventEnded = function() hooks.ended = hooks.ended + 1 end,
})

dofile("shared/safezones.lua")
dofile("shared/mission_defs.lua")
dofile("server/config/missions.lua")
dofile("server/modules/parties.lua")
dofile("server/modules/missions.lua")
dofile("server/modules/mission_engine.lua")
dofile("server/modules/mission_editor.lua")
dofile("server/config/economy.lua")
dofile("server/config/world_bosses.lua")
LightRpWorldBosses.enabled = false -- no random world boss in the way
dofile("server/modules/world_bosses.lua")
dofile("server/config/staff_events.lua")
dofile("server/modules/staff_events.lua")
local D = LightRpMissionDefs
local WB, Engine, SE = LightRP.worldBosses, LightRP.missionEngine, LightRP.staffEvents
local C, WC = LightRpStaffEvents, LightRpWorldBosses
local H = LightRP.admin.handlers
assert(H.events == SE.view and H.eventsAction == SE.action, "the desk's handlers")

-- a world boss of the catalogue, authored at O
local O = { x = 500, y = 500, z = 10 }
local wb, why = D.validate({ id = "wb-1", title = "Burn Notice", description = "", location = "Kabuki", type = "eliminate", enabled = true,
    point = O, perimeter = { shape = "circle", center = O, radius = 40, minZ = 0, maxZ = 40 },
    starts = { { x = 500, y = 500, z = 10, heading = 0 } },
    spawns = {
        { id = "boss", label = "Juggernaut", position = { x = 505, y = 500, z = 10 }, enemy = "militech", count = 1, trigger = "start" },
        { id = "guards", position = { x = 510, y = 500, z = 10 }, enemy = "militech", count = 2, trigger = "start", behavior = "patrol",
            route = { { x = 520, y = 500, z = 10 } } },
        { id = "late1", position = { x = 515, y = 500, z = 10 }, enemy = "valentinos", count = 2, trigger = "checkpoint" },
    },
    worldBoss = { enabled = true, boss = "boss", health = 50, reward = 30000, minShare = 5, minutes = 10 } })
assert(wb, tostring(why))
wb.id = "wb-1"
Engine.publish(wb)

-- players: 1 and 2 staff in the city, 3 a player, 4 in an instance
for id, p in pairs({ [1] = { x = 1000, y = 1000, z = 20, heading = 90 }, [2] = { x = 2000, y = 1000, z = 15 },
    [3] = { x = 2010, y = 1000, z = 15 }, [4] = { x = 3000, y = 3000, z = 10 } }) do
    chars[id] = "Char " .. id; positions[id] = p; buckets[id] = 0
end
buckets[4] = 7
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
local function noticeOf(id, title) for i = #notices, 1, -1 do if notices[i].id == id and notices[i].title == title then return notices[i].body end end end
local function bossOf(ev) for _, n in pairs(ev.bossNpcs) do return n end end
local function kill(ev, by)
    local boss = bossOf(ev)
    for _, who in ipairs(by) do fire("onNpcDamaged", tostring(boss), "player:" .. who, "500", "1", "player_hit") end
    npcs[boss].health = 0
    fire("onNpcDied", tostring(boss), "player:" .. by[1], "player_hit")
    seconds(2)
end
-- a refusal: before the audit (nil, why) or audited as failed ({ accepted = false, message })
local function refusal(r, w)
    if r == nil then return w or "" end
    assert(not r.accepted, "accepted: " .. tostring(r.message))
    return r.message
end
local function closeAll()
    for _, ev in ipairs(WB.events()) do if ev.phase == "fight" then WB.finish(ev, false, "test") end end
    seconds(WC.cleanupSeconds + 3)
    assert(#WB.events() == 0, "every event closed")
end

-- ── rights and the view ──
assert(H.events(3, {}) == nil, "a player sees nothing")
assert(select(2, H.eventsAction(3, { action = "launch", confirmed = true, kind = "psycho", where = "here" })):find("permission"), "nor acts")
local v = H.events(1, {})
assert(#v.bosses == 1 and v.bosses[1].id == "wb-1" and #v.psychos == 16 and #v.crews == #C.gang.crews and #v.levels == 3 and #v.presets == 4)
assert(v.canPay == true and v.inCity == true and v.maxLive == WC.maxLive and #v.live == 0 and v.random.enabled == false)
assert(not v.psychos[1].label:find("Cyberpsycho: ", 1, true), "the psychos' labels without the prefix")
assert(H.events(2, {}).canPay == false, "a moderator cannot pay")

-- ── a cyberpsycho here, for fun, by a moderator ──
local nextBefore = WB.nextAt()
local r, err = H.eventsAction(2, { action = "launch", kind = "psycho", where = "here", enemy = "psycho_kabuki" })
assert(not r and err:find("Review"), "a launch is confirmed")
assert(select(2, H.eventsAction(2, { action = "launch", confirmed = true, kind = "psycho", where = "here", pay = true })):find("world boss right"),
    "a paid event needs the world boss right")
notices, blips = {}, {}
r = H.eventsAction(2, { action = "launch", confirmed = true, kind = "psycho", where = "here", enemy = "psycho_kabuki", level = "hard",
    name = "Static", location = "Kabuki market", minutes = 10, radius = 40, mutation = "evt-test-0001" })
assert(r and r.accepted, tostring(r and r.message))
local ev = WB.events()[1]
assert(ev.kind == "psycho" and ev.noPay and ev.custom and ev.by == "P2" and ev.bossLabel == "Static" and ev.location == "Kabuki market")
assert(#ev.def.spawns == 1 and ev.def.spawns[1].enemy == "psycho_kabuki" and ev.def.spawns[1].behavior == "assault")
assert(ev.def.worldBoss.health == math.floor(C.psycho.health * 1.6 + 0.5) and ev.def.worldBoss.minutes == 10, "health x the level, the time picked")
assert(ev.def.difficulties[1].enemyCount == 1 and ev.def.difficulties[1].enemyDamage == 1.25, "one psycho, the level's damage")
local c = ev.def.perimeter.center
assert(ev.def.perimeter.radius == 40 and c.x == 2000 and c.y == 1000, "a circle around the staff")
assert(noticeOf(1, "CYBERPSYCHO SIGHTING"):find("no pay", 1, true), "the city is told: no pay")
assert(#blips == 1 and blips[1].icon == "skull" and blips[1].label == "CYBERPSYCHO: Static", "its own pin")
seconds(3)
local boss = bossOf(ev)
assert(boss and npcs[boss].maxHealth == 100 * ev.def.worldBoss.health and npcs[boss].def.bucket == 0, "out in the city")
local hud = providers.worldBoss(3)
assert(hud and hud.tag == "CYBERPSYCHO" and hud.noPay and hud.reward == 0 and hud.rewardMax == 0, "the zone HUD: its tag, no pay")
local row = H.events(1, {}).live[1]
assert(row.kind == "psycho" and row.pay == false and row.by == "P2" and row.distance == 1000 and row.boss == "Static", "the desk's live list")
-- the same request again: the first outcome, no second psycho
assert(H.eventsAction(2, { action = "launch", confirmed = true, kind = "psycho", where = "here", mutation = "evt-test-0001" }).accepted)
assert(#WB.events() == 2, "without a database the key is not kept (the next block checks it with one)")
WB.finish(WB.events()[2], false, "test")
seconds(WC.resultSeconds + 1)
assert(#WB.events() == 1)
-- killed: nobody paid, nothing counted
paid, notices = {}, {}
kill(ev, { 3, 2 })
assert(ev.phase == "cleanup" and next(paid) == nil, "no pay")
assert(noticeOf(3, "CYBERPSYCHO DOWN"):find("no pay", 1, true), "told so")
assert(hooks.finished == 0 and hooks.ended == 0, "no drop, contract or title")
seconds(WC.cleanupSeconds + 3)
assert(#WB.events() == 0 and WB.nextAt() == nextBefore, "closed; the random clock untouched")

-- ── paid, on a player: like a world boss ──
paid = {}
r = H.eventsAction(1, { action = "launch", confirmed = true, kind = "psycho", where = "player", target = 3, pay = true })
assert(r and r.accepted, tostring(r and r.message))
ev = WB.events()[1]
assert(not ev.noPay and ev.def.perimeter.center.x == 2010 and C.psycho.names[1] and ev.bossLabel ~= "", "on the player, a handle from the list")
seconds(3)
kill(ev, { 3 })
assert(paid[3] and paid[3] > 0 and hooks.finished == 1 and hooks.ended == 1, "paid and counted")
closeAll()

-- ── where: refusals ──
assert(refusal(H.eventsAction(1, { action = "launch", confirmed = true, kind = "psycho", where = "player", target = 4 })):find("instance"), "a player in an instance")
assert(refusal(H.eventsAction(1, { action = "launch", confirmed = true, kind = "psycho", where = "player", target = 99 })):find("not connected"))
buckets[1] = 5
assert(refusal(H.eventsAction(1, { action = "launch", confirmed = true, kind = "psycho", where = "here" })):find("instance"), "here: the staff in an instance")
buckets[1] = 0
assert(refusal(H.eventsAction(1, { action = "launch", confirmed = true, kind = "psycho", where = "origin" })):find("own place"), "only a world boss has its own place")
assert(refusal(H.eventsAction(1, { action = "launch", confirmed = true, kind = "nope", where = "here" })):find("kind"))
assert(refusal(H.eventsAction(1, { action = "launch", confirmed = true, kind = "psycho", where = "here", location = string.rep("x", 41) })):find("40"))
assert(#WB.events() == 0)

-- ── a gang attack, brutal, on a player ──
r = H.eventsAction(1, { action = "launch", confirmed = true, kind = "gang", where = "player", target = 2, crew = "sixthstreet", level = "brutal", radius = 60 })
assert(r and r.accepted, tostring(r and r.message))
local gang = WB.events()[1]
local by = {}
for _, s in ipairs(gang.def.spawns) do by[s.id] = s end
assert(gang.kind == "gang" and gang.bossLabel == "6th Street warlord" and by.warlord.enemy == "sixthstreet_shotgun" and by.warlord.behavior == "defend")
assert(by.squad1.count == 6 and by.squad2.count == 2 and by.squad1.trigger == "start", "the squad x2")
assert(by.wave1.count == 8 and by.wave2.count == 6 and by.wave1.trigger == "checkpoint" and by.wave1.behavior == "assault", "the waves x2")
local function dist(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end
local gc = gang.def.perimeter.center
assert(math.abs(dist(by.squad1.position, gc) - C.gang.guardRing) < 0.01 and math.abs(dist(by.wave1.position, gc) - 60 * C.gang.waveRing) < 0.01, "the rings")
assert(gang.def.difficulties[1].enemyHealth == 2.5 and gang.def.difficulties[1].enemyCount == 1, "the level on health, numbers already counted")
assert(gang.def.worldBoss.health == C.gang.health and gang.words.down == "WARLORD DOWN")

-- ── a world boss of the catalogue moved here, and at its own place ──
r = H.eventsAction(1, { action = "launch", confirmed = true, kind = "boss", where = "here", boss = "wb-1", radius = 50, name = "Big Joe" })
assert(r and r.accepted, tostring(r and r.message))
local moved = WB.event("worldboss:" .. tostring(#WB.events() + 1)) or WB.events()[2]
assert(moved.def.id == "wb-1" and not moved.custom and moved.bossLabel == "Big Joe", "the catalogue id (its drops), a new name")
by = {}
for _, s in ipairs(moved.def.spawns) do by[s.id] = s end
local mc = moved.def.perimeter.center
assert(mc.x == 1000 and mc.y == 1000 and moved.def.perimeter.radius == 50 and by.boss.position.x == 1000, "the boss on the staff")
assert(math.abs(dist(by.guards.position, mc) - 9) < 0.01 and by.guards.behavior == "defend" and #by.guards.route == 0, "the guards around it, no patrol")
assert(by.late1.trigger == "checkpoint" and math.abs(dist(by.late1.position, mc) - 40) < 0.01, "the reinforcements from the edge")
assert(moved.def.worldBoss.minutes == 10, "the authored time kept")
assert(select(2, SE.launch("T", { kind = "boss", where = "origin", boss = "wb-1" })):find("already out"), "one of a boss at a time")
WB.finish(moved, false, "test")
seconds(WC.resultSeconds + 1)
local home = SE.launch("T", { kind = "boss", where = "origin", boss = "wb-1", level = "hard" })
assert(home and home.def.perimeter.center.x == 500 and home.location == "Kabuki", "at its own place")
local guards
for _, s in ipairs(home.def.spawns) do if s.id == "guards" then guards = s end end
assert(guards.count == 3 and home.def.difficulties[1].enemyHealth == 1.6, "the level on the guards and the health")

-- ── several at once, up to maxLive ──
local before = #WB.events()
for _ = before + 1, WC.maxLive do assert(SE.launch("T", { kind = "psycho", where = "player", target = 3 })) end
assert(#WB.events() == WC.maxLive)
assert(select(2, SE.launch("T", { kind = "psycho", where = "player", target = 3 })):find("most at once"), "no more than maxLive")
-- the zone HUD of a player in the gang's zone is the gang's
local inGang = providers.worldBoss(2)
assert(inGang and inGang.tag == "GANG ATTACK", "each zone its own HUD")
closeAll()

-- ── silent ──
notices, blips = {}, {}
assert(SE.launch("T", { kind = "psycho", where = "player", target = 3, silent = true }))
assert(#blips == 0 and noticeOf(1, "CYBERPSYCHO SIGHTING") == nil, "no notice, no pin")
assert(WB.current() == nil, "not the board's headline")
closeAll()

-- ── stop and win ──
local fun = SE.launch("P1", { kind = "psycho", where = "player", target = 3 })
local paidEv = SE.launch("P1", { kind = "gang", where = "player", target = 2, pay = true })
assert(fun and paidEv)
assert(select(2, H.eventsAction(2, { action = "stop", id = fun.id })):find("Confirm"))
assert(select(2, H.eventsAction(2, { action = "win", confirmed = true, id = paidEv.id })):find("world boss right"), "a paid win needs the right")
r = H.eventsAction(2, { action = "win", confirmed = true, id = fun.id })
assert(r.accepted and fun.phase == "cleanup" and fun.success, "a fun one ended as a win")
r = H.eventsAction(2, { action = "stop", confirmed = true, id = paidEv.id })
assert(r.accepted and paidEv.phase == "done" and not paidEv.success, "called off")
assert(select(2, H.eventsAction(2, { action = "stop", confirmed = true, id = paidEv.id })):find("already ending"))
closeAll()

-- ── spots ──
positions[1] = { x = 1500, y = 1500, z = 30, heading = 45 }
r = H.eventsAction(1, { action = "spotSave", name = "Plaza", district = "Watson" })
assert(r and r.accepted, tostring(r and r.message))
v = H.events(1, {})
assert(#v.spots == 1 and v.spots[1].name == "Plaza" and v.spots[1].district == "Watson" and v.spots[1].distance == 0)
local spot = v.spots[1].id
assert(select(2, H.eventsAction(1, { action = "spotSave", name = "" })):find("Name"))
positions[1] = { x = 1000, y = 1000, z = 20, heading = 90 }
r = H.eventsAction(2, { action = "launch", confirmed = true, kind = "psycho", where = "spot", spot = spot })
assert(r.accepted and WB.events()[1].location == "Plaza" and WB.events()[1].def.perimeter.center.x == 1500, "at the spot, its name")
r = H.eventsAction(1, { action = "goto", spot = spot })
assert(r.accepted and positions[1].x == 1500, "go to a spot")
r = H.eventsAction(1, { action = "goto", id = WB.events()[1].id })
assert(r.accepted and math.abs(positions[1].y - (1500 - math.min(40, C.radius.default * 0.6))) < 0.01, "go to an event: on its edge")
closeAll()
assert(select(2, H.eventsAction(1, { action = "spotDelete", spot = spot })):find("Confirm"))
assert(H.eventsAction(1, { action = "spotDelete", confirmed = true, spot = spot }).accepted and #H.events(1, {}).spots == 0)

-- ── the audit, with a database: one row per request, a repeat answers the first ──
LightRP.db.ready = true
r = H.eventsAction(2, { action = "launch", confirmed = true, kind = "psycho", where = "player", target = 3, mutation = "evt-test-0100" })
assert(r.accepted and #WB.events() == 1)
local again = H.eventsAction(2, { action = "launch", confirmed = true, kind = "psycho", where = "player", target = 3, mutation = "evt-test-0100" })
assert(again.accepted and again.message == r.message and #WB.events() == 1, "the same key: the first outcome, one psycho")
local row1 = audit["id-2#evt-test-0100"]
assert(row1 and row1.outcome == "success" and row1.action == "eventLaunch" and row1.detail:find("is out", 1, true), "audited")
-- a spot is written to the table too
r = H.eventsAction(1, { action = "spotSave", name = "Dock", district = "" })
assert(r.accepted and count(spotRows) == 1)
LightRP.db.ready = false
closeAll()

-- ── event nights ──
-- Psycho Night here, two rounds (one point: one psycho a round)
notices = {}
assert(select(2, H.eventsAction(2, { action = "night", preset = "psycho_night" })):find("Review"))
r = H.eventsAction(2, { action = "night", confirmed = true, preset = "psycho_night", rounds = 2, where = "here" })
assert(r and r.accepted, tostring(r and r.message))
assert(noticeOf(-1, "EVENT NIGHT"):find("Psycho Night starts in 30 s", 1, true), "announced")
assert(select(2, SE.startNight("T", 1, { preset = "siege", where = "here" })):find("already running"), "one night at a time")
seconds(C.nights.introSeconds + 2)
assert(#WB.events() == 1 and SE.night().phase == "live" and SE.night().index == 1, "round 1 out")
local r1 = WB.events()[1]
assert(r1.nightId and r1.def.perimeter.center.x == 2000 and r1.noPay, "here (the staff who started it), no pay")
assert(H.events(1, {}).night.round == 1 and H.events(1, {}).live[1].night, "the desk sees the night")
kill(r1, { 3 })
seconds(WC.cleanupSeconds + 3)
assert(SE.night().phase == "break" and SE.night().won == 1, "a break after a won round")
assert(noticeOf(-1, "EVENT NIGHT"):find("round 2 of 2", 1, true))
seconds(C.nights.breakSeconds + 2)
assert(#WB.events() == 1 and SE.night().index == 2, "round 2 out")
local r2 = WB.events()[1]
assert(r2.def.difficulties[1].enemyDamage == 1.25, "harder: hard")
r = H.eventsAction(1, { action = "stop", confirmed = true, id = r2.id })
seconds(WC.resultSeconds + 3)
assert(SE.night().phase == "done", "over")
assert(noticeOf(-1, "EVENT NIGHT"):find("1 of 2 fight(s) won", 1, true), tostring(noticeOf(-1, "EVENT NIGHT")))

-- Psycho Night at the spots: the last round two at once
positions[1] = { x = 1800, y = 1800, z = 30 }
assert(H.eventsAction(1, { action = "spotSave", name = "Market" }).accepted)
positions[1] = { x = 1000, y = 1000, z = 20 }
assert(count(H.events(1, {}).spots) >= 2)
assert(SE.startNight("T", 1, { preset = "psycho_night", rounds = 2, where = "spots" }))
assert(#SE.night().rounds[2] == 2 and #SE.night().rounds[1] == 1, "the last round: two psychos")
assert(SE.night().rounds[2][1].spot ~= SE.night().rounds[2][2].spot, "at two spots")
assert(H.eventsAction(1, { action = "nightStop", confirmed = true }).accepted and SE.night().phase == "done")

-- Gang War: two gangs at once at two spots; Siege: a psycho leads the last one
assert(SE.startNight("T", 1, { preset = "gang_war", rounds = 2, where = "spots" }))
seconds(C.nights.introSeconds + 2)
assert(#WB.events() == 2 and WB.events()[1].kind == "gang" and WB.events()[2].kind == "gang", "two gangs at once")
assert(WB.events()[1].def.perimeter.center.x ~= WB.events()[2].def.perimeter.center.x, "at two spots")
r = H.eventsAction(1, { action = "nightStop", confirmed = true, callOff = true })
assert(r.accepted and r.message:find("2 event", 1, true), tostring(r.message))
closeAll()
assert(select(2, SE.startNight("T", 1, { preset = "gang_war", rounds = 2, where = "here" })):find("saved spots"), "Gang War needs spots")
assert(SE.startNight("T", 1, { preset = "siege", rounds = 3, where = "here" }))
local plan = SE.night().rounds
assert(#plan == 3 and plan[3][1].warlord and D.ENEMY[plan[3][1].warlord].psycho and not plan[1][1].warlord, "a psycho leads the last gang")
assert(plan[1][1].level == "normal" and plan[3][1].level == "brutal", "harder every round")
seconds(C.nights.introSeconds + 2)
assert(WB.events()[1].kind == "gang")
SE.startNight("T", 1, { preset = "siege" }) -- refused while it runs
assert(H.eventsAction(1, { action = "nightStop", confirmed = true, callOff = true }).accepted)
closeAll()
-- Boss Rush: the catalogue's bosses at their own place
assert(SE.startNight("T", 1, { preset = "boss_rush" }))
seconds(C.nights.introSeconds + 2)
assert(#WB.events() == 1 and WB.events()[1].def.id == "wb-1" and WB.events()[1].def.perimeter.center.x == 500, "Boss Rush: at its own place")
assert(H.eventsAction(1, { action = "nightStop", confirmed = true, callOff = true }).accepted)
closeAll()
-- a round that cannot come out (the engine full) is retried, then skipped; the night ends
for _ = 1, WC.maxLive do assert(SE.launch("T", { kind = "psycho", where = "player", target = 3 })) end
assert(SE.startNight("T", 1, { preset = "siege", rounds = 2, where = "here" }))
seconds(C.nights.introSeconds + 2)
assert(SE.night().index == 1 and SE.night().phase == "break" and SE.night().tries == 1, "full: retried")
seconds(10 * 6)
assert(SE.night().index == 2, "skipped to round 2 (not back to 1)")
notices = {}
seconds(10 * 6 + 2)
assert(SE.night().phase == "done" and noticeOf(-1, "EVENT NIGHT"):find("0 of 0", 1, true), "over when the last round is skipped")
closeAll()
-- a paid night needs the right
assert(select(2, H.eventsAction(2, { action = "night", confirmed = true, preset = "siege", where = "here", pay = true })):find("world boss right"))

-- ── random world bosses: on/off, next ──
r = H.eventsAction(1, { action = "random", enabled = true })
assert(r.accepted and WC.enabled == true and H.events(1, {}).random.enabled)
assert(H.eventsAction(1, { action = "next", minutes = 5 }).accepted and WB.nextAt() == clock + 5 * 60000)
assert(H.eventsAction(1, { action = "random", enabled = false }).accepted and WC.enabled == false)
assert(select(2, H.eventsAction(2, { action = "random", enabled = true })):find("world boss right") and WC.enabled == false, "a moderator cannot")

-- ── /lightrp.event ──
local ok, text = commands["lightrp.event"](1, { "psycho", "hard" })
assert(ok and text:find("is out", 1, true), tostring(text))
assert(WB.events()[1].def.difficulties[1].enemyDamage == 1.25 and WB.events()[1].noPay, "here, hard, for fun")
ok, text = commands["lightrp.event"](1, { "list" })
assert(ok and text:find(WB.events()[1].id, 1, true))
ok, text = commands["lightrp.event"](1, { "boss", "burn" })
assert(ok and WB.events()[2].def.id == "wb-1" and WB.events()[2].def.perimeter.center.x == 500, "a boss by its title, at its own place")
ok, text = commands["lightrp.event"](1, { "stop", "all" })
assert(ok and text:find("2 event", 1, true))
closeAll()
ok = commands["lightrp.event"](1, { "gang", "maelstrom", "brutal" })
assert(ok and WB.events()[1].bossLabel == "Maelstrom chromehead")
closeAll()
assert(not commands["lightrp.event"](0, { "psycho" }), "the console has no position")

print("PASS: staff events (rights + pay right, view, psycho here/on a player/at a spot with level, name, place, time and radius, no pay = no money, drop, contract or title, paid = a world boss, refusals (instance, offline, origin, kind, text), gang attack rings and counts, a catalogue boss moved (compact layout, no patrol, its id) and at its own place, several at once up to maxLive with their own HUD, silent, stop / win, spots save / go to / delete, audit idempotence and spot rows, nights (psycho night here and at spots, gang war, siege, boss rush, stop, paid right), random on/off/next, /lightrp.event)")
