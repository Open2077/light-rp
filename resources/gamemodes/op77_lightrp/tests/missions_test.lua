-- Missions entry and crews, server side, with the host stubbed: crews
-- (invite / accept / leave / kick / lead), entry by crew (private lobby, its
-- leader tags it in), matchmaking that fills open lobbies, the countdown when
-- full or when the host launches, untag on walking away, launch into a bucket,
-- finish with payout and reputation, abandon. tests/crews_test.lua covers the
-- crews themselves in depth.
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

dofile("server/config/economy.lua")
dofile("server/modules/mission_pay.lua")
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

-- ── crews ──
assert(Party.invite(1, 2))
assert(Party.of(1).leader == 1 and providers.party(2).invites[1].fromName == "Jack Okonkwo", "invite pending")
assert(Party.invite(2, 3), "anyone starts a crew by inviting")
assert(Party.accept(2), "a crew of one gives way to the invite")
assert(providers.party(3).invites[1] == nil, "2's dropped crew took its invite along")
assert(#Party.of(1).members == 2 and Party.of(2) == Party.of(1))
assert(Party.invite(1, 3)); assert(Party.accept(3))
assert(select(2, Party.invite(2, 4)) == "Only the crew leader invites.")
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

-- ── alone below the minimum: matchmaking on, then a crew fills the lobby ──
local r = act(4, "mission.tag", { difficulty = "standard" })
assert(not r.ok and r.text:find("needs 2 operators", 1, true) and r.text:find("matchmaking"), r.text)
assert(act(4, "mission.matchmaking", { on = true }).ok and open(4).entry.matchmaking)
clock = clock + 2000
r = act(4, "mission.tag", { difficulty = "standard" })
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
-- the crew (1 lead, 2), matchmaking off: its own lobby, nobody joins, it launches at the minimum
assert(open(1).difficulties[1].openLobbies == 1, "the board says somebody is looking for operators")
clock = clock + 2000
r = act(1, "mission.tag", { difficulty = "standard" })
assert(r.ok and r.text:find("launches"), r.text)
assert(view(1).count == 2 and view(2).count == 2 and view(1).state == "countdown" and view(4).count == 1, "a private crew lobby")
assert(open(1).entry.crew and open(1).entry.leads and not open(2).entry.leads and open(2).entry.leader == "Jack Okonkwo")
-- a member cannot tag in, for the crew or alone
clock = clock + 2000
r = act(2, "mission.tag", { difficulty = "standard" })
assert(not r.ok and r.text == "Your crew leader tags the crew in. Leave the crew to go solo.", r.text)
r = act(2, "mission.matchmaking", { on = true })
assert(not r.ok and r.text:find("leader"), "only the leader opens the crew")
-- the leader opens the crew to matchmaking: the countdown stops, the lobby waits for players
assert(act(1, "mission.matchmaking", { on = true }).ok)
assert(view(1).state == "open" and Party.matchmaking(2), "an open lobby waits to be full")
-- tagging again joins the fullest open lobby with room: Vi's
clock = clock + 2000
r = act(1, "mission.tagGroup", { difficulty = "standard" })
assert(r.ok, r.text)
assert(view(1).count == 3 and view(2).count == 3 and not view(1).host, "the crew joined the fullest open lobby with room")
-- the board shows everyone, the host first (to who is open to matchmaking)
assert(open(3).boards.standard.id == nil, "matchmaking off: open lobbies stay off your board")
assert(act(3, "mission.matchmaking", { on = true }).ok)
s = open(3)
assert(#s.boards.standard.members == 3 and s.boards.standard.members[1].host and s.boards.standard.members[1].name == "Vi Asada")
assert(s.difficulties[1].tagged == 3)

-- ── the fourth fills it: countdown ──
clock = clock + 2000
assert(act(3, "mission.matchmaking", { on = true }).ok)
r = act(3, "mission.tag", { difficulty = "standard" })
assert(r.ok and r.text:find("launches"), r.text)
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
-- two finishers at the minimum crew of two: each gets the full share (mission_pay_test covers the rules)
assert(paid[4] == P.difficulties[1].payout and paid[1] == P.difficulties[1].payout and not paid[2], "payout to the finishers only")
local announced, done
for _, n in ipairs(notices) do
    if n.id == 4 and n.title == "PAYOUT" then announced = n end
    if n.id == 4 and n.title == "MISSION COMPLETE" then done = n end
end
assert(announced and announced.body:find("If you finish", 1, true), "the expected pay is announced at launch")
assert(done and done.body:find("$" .. P.difficulties[1].payout .. " paid", 1, true), "the notice quotes what was paid")
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

-- ── a crew member below the leader's difficulty: never refused, their own reward ──
-- (owner decision 2026-11-03, docs/pve-progression.md)
local function lastNotice(id, title)
    for i = #notices, 1, -1 do if notices[i].id == id and (not title or notices[i].title == title) then return notices[i] end end
end
assert(commands["missions.size"](0, { P.id, "critical", "2", "8" }) and commands["missions.size"](0, { P.id, "hard", "2", "6" }))
spawn(6, "Ada Strand", 1); spawn(7, "Low Seven", 2); spawn(8, "Mid Eight", 3)
assert(commands["missions.rep"](0, { "6", "5000" }))
assert(commands["missions.unlock"](0, { "6", P.id, "standard" }) and commands["missions.unlock"](0, { "6", P.id, "hard" }))
assert(Missions.tier(7) == 1 and Missions.unlocked(6, P, P.difficulties[3]), "6 has critical, 7 is a Street")
-- the leader's own gate still applies: a Street leading the crew cannot pick critical
assert(Party.invite(7, 6) and Party.accept(6) and Party.of(6).leader == 7)
clock = clock + 2000
r = act(7, "mission.tag", { difficulty = "critical" })
assert(not r.ok and r.text:find("reputation tier III (Operator)", 1, true), "leader gate: " .. r.text)
assert(view(6) == false and view(7) == false, "nobody tagged")
-- the Operator leads: the Street member is tagged with the crew, told once what they earn
assert(Party.promote(7, 6) and Party.of(7).leader == 6)
local s7 = open(7).difficulties[3]
assert(s7.locked and s7.tierLocked and s7.earns == LightRpMissions.reputationGain.standard and s7.earnsAs == "STANDARD"
    and s7.reputation == LightRpMissions.reputationGain.critical, "the member's board: locked for them, the reward they would earn")
local told = #notices
clock = clock + 2000
r = act(6, "mission.tag", { difficulty = "critical" })
assert(r.ok and r.text:find("launches", 1, true) and r.text:find("reduced reward: Low Seven (Standard)", 1, true), r.text)
assert(view(7).count == 2 and view(7).state == "countdown", "the member below the tier is on the board")
local credNotice = lastNotice(7, "STREET CRED")
assert(credNotice and #notices > told and credNotice.body == "Critical is above your street cred: you play it, you earn the Standard reward (+100 reputation).",
    credNotice and credNotice.body)
for i = told + 1, #notices do assert(not (notices[i].id == 6 and notices[i].title == "STREET CRED"), "the leader has nothing to be told") end
-- the launch keeps them (the last check does not gate a carried member)
tick(LightRpMissions.countdown * 1000 + 100)
local critical = Missions.instanceOf(7)
assert(critical and critical.difficulty == "critical" and Missions.instanceOf(6) == critical and #critical.members == 2, "launched at critical, both inside")
-- full payout and full difficulty, the reputation of their own best difficulty
local repBefore6 = Missions.reputation(6)
assert(commands["missions.complete"](0, { "6" }))
assert(paid[7] == P.difficulties[3].payout and paid[6] == P.difficulties[3].payout, "the critical payout to both")
assert(Missions.reputation(7) == LightRpMissions.reputationGain.standard, "the Street earns the standard reward")
assert(Missions.reputation(6) == repBefore6 + LightRpMissions.reputationGain.critical, "the leader earns the critical reward")
assert(lastNotice(7, "MISSION COMPLETE").body:find("+100 reputation (Standard reward)", 1, true), lastNotice(7, "MISSION COMPLETE").body)
assert(not lastNotice(6, "MISSION COMPLETE").body:find("reward)", 1, true), "the leader's notice names no reduced reward")
-- the clear ladder counts too: a Merc who never cleared standard here, carried into hard
assert(commands["missions.rep"](0, { "8", "600" }) and Missions.tier(8) == 2 and Missions.cleared(8, P.id, "standard") == 0)
assert(Party.invite(6, 8) and Party.accept(8))
clock = clock + 2000
r = act(6, "mission.tag", { difficulty = "hard" })
assert(r.ok and r.text:find("Mid Eight (Standard)", 1, true) and r.text:find("Low Seven (Standard)", 1, true), r.text)
assert(lastNotice(8, "STREET CRED").body == "You have not cleared Standard here yet: you play Hard, you earn the Standard reward (+100 reputation).",
    lastNotice(8, "STREET CRED").body)
assert(view(8).count == 3 and view(8).state == "countdown")
-- members leaving the crew come off its board; the leader untags
assert(Party.leave(8) and view(8) == false)
assert(Party.leave(7) and Party.of(7) == nil and view(7) == false)
actions["mission.untag"](6, { session = open(6).session })
assert(view(6) == false, "nobody left on the board")
-- a solo player is still gated: Low Seven alone cannot pick critical, nor hard
clock = clock + 2000
r = act(7, "mission.tag", { difficulty = "critical" })
assert(not r.ok and r.text:find("reputation tier III (Operator)", 1, true), "solo gate: " .. r.text)
clock = clock + 2000
r = act(7, "mission.tag", { difficulty = "hard" })
assert(not r.ok and r.text:find("reputation tier II (Merc)", 1, true), "solo gate: " .. r.text)
assert(commands["missions.size"](0, { P.id, "critical", "6", "8" }) and commands["missions.size"](0, { P.id, "hard", "4", "6" }))
for id = 6, 8 do LightRP.eachModule("onDisconnected", id); positions[id], chars[id] = nil, nil end

-- ── time runs out ──
clock = clock + 2000
assert(act(5, "mission.tag", { difficulty = "standard" }).ok == false, "far away player cannot tag")
positions[5] = { x = at.x, y = at.y + 1, z = at.z }
clock = clock + 2000
assert(act(5, "mission.matchmaking", { on = true }).ok)
assert(act(5, "mission.tag", { difficulty = "standard" }).ok)
assert(commands["missions.launch"](0, { "5" }))
local solo = Missions.instanceOf(5)
assert(solo and #solo.members == 1)
tick(LightRpMissions.points[1].difficulties[1].minutes * 60000 + 1000)
assert(not Missions.instanceOf(5) and buckets[5] == 0 and not paid[5], "failed on time")

-- ── the same mission again inside the hour: money and reputation at the repeat share,
--    and the notice says both (owner decision 2026-11-04, mission_pay_test covers the rule) ──
clock = clock + 2000
local repBefore4, paidBefore4 = Missions.reputation(4), paid[4]
assert(act(4, "mission.tag", { difficulty = "standard" }).ok)
assert(commands["missions.launch"](0, { "4" }))
assert(Missions.instanceOf(4), "launched again")
assert(commands["missions.complete"](0, { "4" }))
local share = LightRpEconomy.missions.reputationRepeatShare
local reduced = math.floor(LightRpMissions.reputationGain.standard * share + 0.5)
assert(Missions.reputation(4) == repBefore4 + reduced, "a quarter of the reputation: " .. (Missions.reputation(4) - repBefore4))
assert(paid[4] - paidBefore4 < P.difficulties[1].payout, "and a reduced payout")
local again = lastNotice(4, "MISSION COMPLETE").body
assert(again:find("+" .. reduced .. " reputation (" .. math.floor(share * 100 + 0.5) .. "% of " .. LightRpMissions.reputationGain.standard
    .. ": this job gave you its full reputation less than 60 min ago", 1, true), again)

-- ── disconnect while tagged and while in a crew ──
clock = clock + 2000
assert(act(4, "mission.tag", { difficulty = "standard" }).ok)
LightRP.eachModule("onDisconnected", 4)
assert(view(4) == false)
LightRP.eachModule("onDisconnected", 1)
assert(Party.of(2) == nil, "a crew of one dissolves when the other leaves the city")
print("PASS: crews (invite/accept/lead/kick/dissolve), boards (tiers, nearby), entry by crew (private lobby, leader only), matchmaking fills open lobbies, countdown when full, cancel on leave/wander, host launch with the minimum, bucket instance, crew frame (health/armor/down), abandon, payout + reputation, tiers, crew members below the tier or the ladder play for their own reward (leader and solo still gated), time out, disconnects")
