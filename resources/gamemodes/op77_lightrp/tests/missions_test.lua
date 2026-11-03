-- Missions matchmaking and squads, server side, with the host stubbed:
-- squads (invite / accept / leave / kick / lead), tagging alone and as a squad,
-- matchmaking that fills a squad's empty seats, the countdown when full or when
-- the host launches, untag on walking away, launch into a bucket, finish with
-- payout and reputation, abandon.
local clock = 0
local threads = {}
local function tick(ms)
    clock = clock + (ms or 500)
    for i = #threads, 1, -1 do
        local co = threads[i]
        if coroutine.status(co) == "dead" then table.remove(threads, i)
        else local ok, err = coroutine.resume(co); if not ok then error(err) end end
    end
end
_G.CreateThread = function(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; local ok, err = coroutine.resume(co); if not ok then error(err) end end
_G.Wait = function() coroutine.yield() end

local positions, buckets, life, hp, phase = {}, {}, {}, {}, {}
_G.json = { encode = function(v)
    local function enc(x)
        if type(x) == "table" then local parts = {} for k, y in pairs(x) do parts[#parts + 1] = tostring(k) .. "=" .. enc(y) end table.sort(parts) return "{" .. table.concat(parts, ",") .. "}" end
        return tostring(x)
    end
    return enc(v)
end }
local sent, notices, results, dialogs, states, paid, teleports, healed = {}, {}, {}, {}, {}, {}, {}, {}
_G.GetPlayers = function() local t = {} for id in pairs(positions) do t[#t + 1] = tostring(id) end table.sort(t) return t end
_G.GetPlayerRoutingBucket = function(id) return buckets[id] or 0 end
_G.SetPlayerRoutingBucket = function(id, b) buckets[id] = b return true end
_G.TriggerClientEvent = function(name, target, payload) sent[#sent + 1] = { name = name, target = target, payload = payload } end
_G.Open77 = { players = {
    position = function(id) local p = positions[id]; return p and { x = p.x, y = p.y, z = p.z, bucket = buckets[id] or 0 } end,
    get = function(id) return { position = positions[id], health = hp[id] or 100, maxHealth = 100, armor = 40, lifePhase = phase[id] or "alive" } end,
    getLifeState = function(id) return { phase = life[id] or "alive" } end,
    heal = function(id, amount) healed[id] = amount; return true, amount end,
    teleport = function(id, spot, opts)
        teleports[#teleports + 1] = { id = id, spot = spot, bucket = opts.bucket }
        return { await = function() buckets[id] = opts.bucket; positions[id] = { x = spot.x, y = spot.y, z = spot.z }; return true end }
    end,
} }
_G.LightRpEvents = { net = { mission = "op77_lightrp:mission" } }

local modules, actions, commands, providers = {}, {}, {}, {}
local chars = {}
_G.LightRP = {
    nowMs = function() return clock end, log = function() end,
    module = function(name, def) def.name = name; modules[#modules + 1] = def; LightRP[name] = LightRP[name] or def; return def end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if m[hook] then m[hook](...) end end end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    stateProvider = function(key, fn) providers[key] = fn end,
    state = function(id, key) states[#states + 1] = { id = id, key = key } end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, body = n.body } end,
    result = function(id, ok, text, action) results[#results + 1] = { id = id, ok = ok, text = text, action = action } end,
    dialog = function(id, kind, payload) payload.kind = kind; dialogs[#dialogs + 1] = { id = id, payload = payload } end,
    interaction = function() end,
    characters = {
        isRegistered = function(id) return chars[id] ~= nil end,
        displayName = function(id) return chars[id] or ("P" .. id) end,
        get = function(id) return chars[id] and { status = "active", identifier = "id-" .. id, key = "default" } end,
    },
    money = { addBank = function(id, amount) paid[id] = (paid[id] or 0) + amount; return true end, format = function(n) return "$" .. n end },
    db = { ready = false, schema = function() end, single = function() end, run = function() end },
}

dofile("server/config/missions.lua")
dofile("server/modules/parties.lua")
dofile("server/modules/missions.lua")
local Party, Missions = LightRP.parties, LightRP.missions
local P = LightRpMissions.points[1]
local at = P.position
local function spawn(id, name, dx)
    chars[id] = name
    positions[id] = { x = at.x + (dx or 0), y = at.y, z = at.z }
    buckets[id] = 0
    Missions.onCharacterLoaded(id)
end
local function lastResult(id) for i = #results, 1, -1 do if results[i].id == id then return results[i] end end end
local function view(id) return providers.missionQueue(id) end
local function open(id) assert(Missions.open(id, P.id)); for i = #dialogs, 1, -1 do if dialogs[i].id == id then return dialogs[i].payload end end end
local function act(id, type, extra)
    local s = open(id)
    local payload = { session = s.session }
    for k, v in pairs(extra or {}) do payload[k] = v end
    actions[type](id, payload)
    return lastResult(id)
end

spawn(1, "Jack Okonkwo", 0); spawn(2, "Kei Mori", 2); spawn(3, "Rosa Vasquez", 3); spawn(4, "Vi Asada", 1); spawn(5, "Far Away", 400)

-- ── squads ──
assert(Party.invite(1, 2))
assert(Party.of(1).leader == 1 and providers.party(2).invites[1].fromName == "Jack Okonkwo", "invite pending")
assert(Party.invite(2, 3), "anyone starts a squad by inviting")
assert(Party.accept(2), "a squad of one gives way to the invite")
assert(providers.party(3).invites[1] == nil, "2's dropped squad took its invite along")
assert(#Party.of(1).members == 2 and Party.of(2) == Party.of(1))
assert(Party.invite(1, 3)); assert(Party.accept(3))
assert(select(2, Party.invite(2, 4)) == "Only the squad leader invites.")
assert(select(2, Party.invite(1, 5)):find("too far"))
assert(Party.promote(1, 2) and Party.of(1).leader == 2)
assert(Party.kick(2, 3) and Party.of(3) == nil and #Party.of(1).members == 2)
assert(Party.promote(2, 1))
local squadState = providers.party(1)
assert(#squadState.members == 2 and squadState.members[1].leader, "party state for the page")

-- ── difficulty view ──
local s = open(4)
assert(#s.difficulties == 3 and s.difficulties[1].id == "standard" and not s.difficulties[1].locked and s.difficulties[2].locked and s.difficulties[3].locked, "only the first difficulty is open")
assert(s.difficulties[2].requires == "STANDARD" and s.difficulties[3].requires == s.difficulties[2].label and s.difficulties[1].requires == nil)
assert(s.me.tier == 1 and s.boards.standard.max == 4)
assert(#s.nearby >= 2, "players around to invite")

-- ── tag solo, then a squad fills the same lobby ──
local r = act(4, "mission.tag", { difficulty = "standard" })
assert(r.ok, r.text)
assert(view(4).count == 1 and view(4).state == "open" and view(4).host)
-- the critical board refuses who lacks its reputation tier (III)...
clock = clock + 2000
r = act(3, "mission.tag", { difficulty = "critical" })
assert(not r.ok and r.text:find("reputation tier III (Operator)", 1, true), r.text)
-- ...and, with the tier, who has not completed hard here
Missions.addReputation(3, 1500)
clock = clock + 2000
r = act(3, "mission.tag", { difficulty = "critical" })
assert(not r.ok and r.text:find("Complete HARD", 1, true), r.text)
Missions.addReputation(3, -1500)
-- the squad (1 lead, 2) tags as a group: joins Vi's lobby (room for 2)
clock = clock + 2000
r = act(1, "mission.tagGroup", { difficulty = "standard" })
assert(r.ok, r.text)
assert(view(1).count == 3 and view(2).count == 3 and not view(1).host, "squad joined the fullest lobby with room")
-- a non-leader cannot tag the squad
clock = clock + 2000
r = act(2, "mission.tagGroup", { difficulty = "standard" })
assert(not r.ok and r.text:find("leader"))
-- the board shows everyone, the host first
s = open(3)
assert(#s.boards.standard.members == 3 and s.boards.standard.members[1].host and s.boards.standard.members[1].name == "Vi Asada")
assert(s.difficulties[1].tagged == 3)

-- ── the fourth fills it: countdown ──
clock = clock + 2000
r = act(3, "mission.tag", { difficulty = "standard" })
assert(r.ok and r.text:find("full"), r.text)
assert(view(3).state == "countdown" and view(3).countdownMs > 0)
-- someone leaves: cancelled; back: countdown again
actions["mission.untag"](3, { session = open(3).session })
assert(view(4).state == "open" and view(4).count == 3)
clock = clock + 2000
assert(act(3, "mission.tag", { difficulty = "standard" }).ok and view(3).state == "countdown")
-- walking away untags
positions[3] = { x = at.x + 200, y = at.y, z = at.z }
tick()
assert(view(3) == false and view(4).state == "open", "wandered off: untagged, countdown cancelled")
positions[3] = { x = at.x + 3, y = at.y, z = at.z }

-- the 3D map, jammed for operators inside a mission
local mapJams = {}
_G.GetCurrentResourceName = _G.GetCurrentResourceName or function() return "op77_lightrp" end
_G.exports = _G.exports or {}
exports.op77_map3d = {
    jam = function(_, target, def) mapJams[target] = def; return "srv:op77_lightrp:" .. def.id end,
    unjam = function(_, id) for t in pairs(mapJams) do if id:find("mission:" .. t, 1, true) then mapJams[t] = nil end end; return true end,
}

-- ── the host launches with the minimum ──
r = act(1, "mission.launch")
assert(not r.ok and r.text:find("host"))
r = act(4, "mission.launch")
assert(r.ok and view(4).state == "countdown")
tick(LightRpMissions.hostCountdown * 1000 + 100)
local inst = Missions.instanceOf(4)
assert(inst and #inst.members == 3 and buckets[4] == inst.bucket and buckets[1] == inst.bucket and buckets[2] == inst.bucket, "launched in its bucket")
assert(view(4).running and view(4).title == P.title)
assert(mapJams[4] and mapJams[1] and mapJams[2] and mapJams[4].strength == 1, "every operator's map is jammed in the mission")
-- the squad frame: every operator, health / armor / life state, pushed when it changes
local squad = view(4).squad
assert(#squad == 3 and squad[1].host and squad[1].health == 100 and squad[1].armor == 40 and squad[1].state == "alive", "squad frame")
tick(); local pushes = #states
hp[1], phase[1] = 0, "revivepending"
tick()
assert(#states > pushes, "a change pushes the frame")
local down
for _, m in ipairs(view(4).squad) do if m.id == 1 then down = m end end
assert(down.state == "down" and down.health == 0, "down shows")
hp[1], phase[1] = 100, "alive"
-- the closed board got told
local closed = false
for _, e in ipairs(sent) do if e.target == 4 and e.payload.closed then closed = true end end
assert(closed, "the board closes for the operators")
-- someone in a mission cannot open boards or tag
assert(not Missions.open(4, P.id))

-- ── an operator abandons; the mission completes for the others ──
commands.mission(2, { "leave" })
assert(not Missions.instanceOf(2) and buckets[2] == 0 and #inst.members == 2)
assert(not mapJams[2] and mapJams[4], "leaving lifts the jam for that operator only")
assert(commands["missions.complete"](0, { "4" }))
assert(not Missions.instanceOf(4) and buckets[4] == 0 and buckets[1] == 0, "home again")
assert(next(mapJams) == nil, "the map comes back for everyone at the end")
assert(paid[4] == 12000 and paid[1] == 12000 and not paid[2], "payout to the finishers only")
assert(healed[4] and healed[1] and healed[2], "everyone leaving the mission is healed, the one who abandoned too")
assert(Missions.reputation(4) == LightRpMissions.reputationGain.standard)

-- ── a difficulty needs its reputation tier AND the one before it completed here ──
local hard = open(4).difficulties[2]
assert(hard.locked and hard.tierLocked and hard.tier == 2 and hard.tierName == "Merc", "a standard completed is not enough: hard needs tier II")
local tierNotices = #notices
assert(commands["missions.rep"](0, { "4", "500" }))
assert(notices[#notices].title == "STREET CRED" and #notices > tierNotices, "reaching a tier is told")
assert(not open(4).difficulties[2].locked and open(4).difficulties[3].locked, "tier II + standard completed opens hard, not critical")
assert(Missions.cleared(4, P.id, "standard") == 1 and Missions.cleared(2, P.id, "standard") == 0)
assert(open(2).difficulties[2].locked, "the one who abandoned did not complete it")
assert(commands["missions.rep"](0, { "3", "5000" }))
assert(open(3).difficulties[2].locked and not open(3).difficulties[2].tierLocked, "reputation alone opens nothing: the ladder holds")
assert(commands["missions.unlock"](0, { "3", P.id, "standard" }) and commands["missions.unlock"](0, { "3", P.id, "hard" }))
assert(not open(3).difficulties[3].locked, "staff unlock")
local okRep, repText = commands["missions.rep"](0, { "3" })
assert(okRep and repText:find("5000 reputation, tier IV (Edgerunner), next at 10000", 1, true), repText)
-- five tiers; a gig crew member carried above their tier earns their tier's gain
assert(Missions.tier(3) == 4 and Missions.tierInfo(3).next == 10000 and Missions.tierInfo(3).nextName == "Legend")
assert(Missions.requiredTier({ id = "critical", tier = 0 }) == 3, "editor difficulties (tier 0) follow their id")
assert(Missions.reputationFor(3, { id = "critical" }) == LightRpMissions.reputationGain.critical)
assert(Missions.reputationFor(2, { id = "critical" }) == LightRpMissions.reputationGain.standard, "tier I carried: standard gain")

-- ── time runs out ──
clock = clock + 2000
assert(act(5, "mission.tag", { difficulty = "standard" }).ok == false, "far away player cannot tag")
positions[5] = { x = at.x, y = at.y + 1, z = at.z }
clock = clock + 2000
assert(act(5, "mission.tag", { difficulty = "standard" }).ok)
assert(commands["missions.launch"](0, { "5" }))
local solo = Missions.instanceOf(5)
assert(solo and #solo.members == 1)
tick(LightRpMissions.points[1].difficulties[1].minutes * 60000 + 1000)
assert(not Missions.instanceOf(5) and buckets[5] == 0 and not paid[5], "failed on time")

-- ── disconnect while tagged and while in a squad ──
clock = clock + 2000
assert(act(4, "mission.tag", { difficulty = "standard" }).ok)
LightRP.eachModule("onDisconnected", 4)
assert(view(4) == false)
LightRP.eachModule("onDisconnected", 1)
assert(Party.of(2) == nil, "squad of one dissolves when the other leaves the city")
print("PASS: squads (invite/accept/lead/kick/dissolve), boards (tiers, nearby), tag solo / squad fills the fullest lobby, countdown when full, cancel on leave/wander, host launch with the minimum, bucket instance, squad frame (health/armor/down), abandon, payout + reputation, tiers, time out, disconnects")
