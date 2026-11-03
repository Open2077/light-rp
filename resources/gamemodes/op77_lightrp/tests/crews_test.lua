-- Crews (server/modules/parties.lua) with missions.lua, the host stubbed:
-- invite / accept / decline / leave / kick / lead, lead passing and dissolving,
-- invite expiry, the page actions' validation (what ALT + click sends), the
-- HUD state (life, busy, far, you), /crew and /party, and the mission entry by
-- crew (leader only, private lobby, matchmaking toggle, leaving untags).
local clock = 0
local threads = {}
local function tick(ms)
    clock = clock + (ms or 1000)
    for i = #threads, 1, -1 do
        local co = threads[i]
        if coroutine.status(co) == "dead" then table.remove(threads, i)
        else local ok, err = coroutine.resume(co); if not ok then error(err) end end
    end
end
_G.CreateThread = function(fn) local co = coroutine.create(fn); threads[#threads + 1] = co; local ok, err = coroutine.resume(co); if not ok then error(err) end end
_G.Wait = function() coroutine.yield() end
_G.json = { encode = function(v)
    local function enc(x)
        if type(x) == "table" then local parts = {} for k, y in pairs(x) do parts[#parts + 1] = tostring(k) .. "=" .. enc(y) end table.sort(parts) return "{" .. table.concat(parts, ",") .. "}" end
        return tostring(x)
    end
    return enc(v)
end }

local positions, buckets, life = {}, {}, {}
local sent, notices, results, dialogs, states = {}, {}, {}, {}, {}
_G.GetPlayers = function() local t = {} for id in pairs(positions) do t[#t + 1] = tostring(id) end table.sort(t) return t end
_G.GetPlayerRoutingBucket = function(id) return buckets[id] or 0 end
_G.SetPlayerRoutingBucket = function(id, b) buckets[id] = b return true end
_G.TriggerClientEvent = function(name, target, payload) sent[#sent + 1] = { name = name, target = target, payload = payload } end
_G.Open77 = { players = {
    position = function(id) local p = positions[id]; return p and { x = p.x, y = p.y, z = p.z, bucket = buckets[id] or 0 } end,
    get = function(id) return { position = positions[id], health = 100, maxHealth = 100, armor = 0, lifePhase = life[id] or "alive" } end,
    getLifeState = function(id) return { phase = life[id] or "alive" } end,
    heal = function() return true end,
    teleport = function(id, spot, opts) return { await = function() buckets[id] = opts.bucket; positions[id] = { x = spot.x, y = spot.y, z = spot.z }; return true end } end,
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
    money = { addBank = function() return true end, format = function(n) return "$" .. n end },
    db = { ready = false, schema = function() end, single = function() end, run = function() end },
}

dofile("server/config/missions.lua")
dofile("server/modules/parties.lua")
dofile("server/modules/missions.lua")
local Crew, Missions = LightRP.parties, LightRP.missions
assert(LightRP.crews == Crew, "LightRP.crews is the parties module")
local C = LightRpMissions.party
local blackout = LightRpMissions.points[1] -- sector04_blackout: standard 2-4
local at = blackout.position
local function spawn(id, name, dx)
    chars[id] = name
    positions[id] = { x = at.x + (dx or 0), y = at.y, z = at.z }
    buckets[id] = 0
    LightRP.eachModule("onCharacterLoaded", id)
end
local function lastResult(id, action)
    for i = #results, 1, -1 do if results[i].id == id and (not action or results[i].action == action) then return results[i] end end
end
local function act(id, type, payload) actions[type](id, payload or {}); return lastResult(id, type) end
local function noticed(id, pattern)
    for i = #notices, 1, -1 do if notices[i].id == id and (notices[i].body or ""):find(pattern, 1, true) then return true end end
    return false
end
local function member(state, id) for _, m in ipairs(state.members or {}) do if m.id == id then return m end end end

spawn(1, "Jack", 0); spawn(2, "Kei", 2); spawn(3, "Rosa", 3); spawn(4, "Vi", 1); spawn(5, "Dex", 4)

-- ── invite / accept / decline ──
local r = act(1, "party.invite", { target = 2 })
assert(r.ok and r.text == "Crew invite sent to Kei.", r.text)
local crew = Crew.of(1)
assert(crew and crew.leader == 1 and #crew.members == 1 and crew.matchmaking == false, "inviting starts a crew of one, matchmaking off")
local s2 = providers.party(2)
assert(#s2.invites == 1 and s2.invites[1].fromName == "Jack" and s2.invites[1].expiresInMs == C.inviteSeconds * 1000 and s2.inviteSeconds == C.inviteSeconds)
assert(noticed(2, "Jack invites you to their crew."))
r = act(1, "party.invite", { target = 2 })
assert(not r.ok and r.text:find("already has your invite"), r.text)
r = act(2, "party.accept", {})
assert(r.ok and r.text == "You joined Jack's crew." and Crew.of(2) == crew and #crew.members == 2)
assert(noticed(1, "Kei joined the crew."))
assert(Crew.invite(1, 3)); r = act(3, "party.decline", {})
assert(r.ok and Crew.of(3) == nil and noticed(1, "Rosa declined your crew invite."))
r = act(3, "party.accept", {})
assert(not r.ok and r.text == "No crew invite waiting for you.")

-- ── what ALT + click sends is checked here, whatever the page showed ──
for _, bad in ipairs({ "abc", -1, 0, 1.5, 2 ^ 40, {}, nil }) do
    r = act(1, "party.invite", { target = bad })
    assert(not r.ok, "bad target refused: " .. tostring(bad))
end
r = act(1, "party.invite", { target = 1 }); assert(not r.ok and r.text == "You cannot invite yourself.")
r = act(1, "party.invite", { target = 99 }); assert(not r.ok and r.text == "That player is not in the city.")
r = act(1, "party.invite", { target = 2 }); assert(not r.ok and r.text == "Kei is already in your crew.")
r = act(2, "party.invite", { target = 3 }); assert(not r.ok and r.text == "Only the crew leader invites.")
r = act(2, "party.kick", { target = 1 }); assert(not r.ok and r.text == "Only the crew leader removes members.")
r = act(2, "party.promote", { target = 2 }); assert(not r.ok and r.text == "Only the crew leader hands the lead over.")
r = act(1, "party.kick", { target = 4 }); assert(not r.ok and r.text == "That player is not in your crew.")
r = act(1, "party.kick", { target = 1 }); assert(not r.ok and r.text == "That player is not in your crew.")
r = act(1, "party.promote", { target = 4 }); assert(not r.ok and r.text == "That player is not in your crew.")
r = act(4, "party.leave", {}); assert(not r.ok and r.text == "You are not in a crew.")
r = act(4, "party.accept", { party = string.rep("x", 200) }); assert(not r.ok)
-- another bucket (an activity, a mission, a dwelling) is not "around you"
buckets[3] = 7
r = act(1, "party.invite", { target = 3 }); assert(not r.ok and r.text == "Rosa is not around you.")
buckets[3] = 0
-- someone already in another crew
assert(Crew.invite(4, 5) and Crew.accept(5))
r = act(1, "party.invite", { target = 5 }); assert(not r.ok and r.text == "Dex is already in a crew.")
assert(Crew.leave(5) and Crew.of(4) == nil and Crew.of(5) == nil, "a crew of two dissolves when one leaves")
assert(noticed(4, "Your crew has dissolved."))

-- ── the HUD state: you, leader, life, busy, far ──
assert(Crew.invite(1, 3) and Crew.accept(3))
local st = providers.party(2)
assert(st.id == crew.id and st.leader == 1 and st.you == 2 and #st.members == 3 and st.matchmaking == false)
assert(member(st, 1).leader and member(st, 2).you and not member(st, 1).you and member(st, 3).state == "alive" and member(st, 3).far == false)
life[3] = "revivepending"
assert(member(providers.party(2), 3).state == "down", "down shows")
life[3] = "dead"
assert(member(providers.party(2), 3).state == "dead")
life[3] = nil
positions[3] = { x = at.x + C.farRange + 50, y = at.y, z = at.z }
assert(member(providers.party(2), 3).far and not member(providers.party(3), 3).far, "far from the viewer, never from yourself")
positions[3] = { x = at.x + 3, y = at.y, z = at.z }
-- a change is pushed by the refresh loop, a fall at once
local before = #states
life[2] = "revivepending"; LightRP.eachModule("onLifeState", 2, "revivepending", "alive")
assert(#states > before, "a fall pushes the crew at once")
life[2] = nil; tick(C.refreshMs)

-- ── lead passes, kick, dissolve ──
r = act(1, "party.promote", { target = 2 })
assert(r.ok and crew.leader == 2 and noticed(3, "Kei leads the crew now."))
r = act(2, "party.kick", { target = 3 })
assert(r.ok and Crew.of(3) == nil and noticed(3, "Kei removed you from the crew.") and #crew.members == 2)
r = act(2, "party.leave", {})
assert(r.ok and Crew.of(1) == nil and Crew.of(2) == nil, "a crew of one dissolves")
-- the leader leaves a crew of three: the next member leads
assert(Crew.invite(1, 2) and Crew.accept(2) and Crew.invite(1, 3) and Crew.accept(3))
crew = Crew.of(1)
assert(Crew.leave(1) and crew.leader == 2 and #crew.members == 2 and noticed(2, "You lead the crew now."))
assert(Crew.leave(3) and Crew.of(2) == nil)

-- ── invites expire; a crew of one nobody answered dissolves ──
assert(Crew.invite(1, 2))
tick(C.inviteSeconds * 1000 + 1000)
assert(#providers.party(2).invites == 0 and Crew.of(1) == nil and noticed(1, "Nobody answered your crew invite."))

-- ── a disconnect or a character change ends the crew for that player ──
assert(Crew.invite(1, 2) and Crew.accept(2) and Crew.invite(1, 3) and Crew.accept(3))
LightRP.eachModule("onCharacterLoaded", 3)
assert(Crew.of(3) == nil and #Crew.of(1).members == 2, "a character change leaves the crew")
LightRP.eachModule("onDisconnected", 1)
assert(Crew.of(2) == nil, "the leader left the city: a crew of one dissolves")
spawn(1, "Jack", 0); spawn(3, "Rosa", 3)

-- ── /crew and /party ──
local ok, text = commands.crew(1, { "invite", "2" }); assert(ok and text == "Crew invite sent to Kei.")
ok, text = commands.party(2, {}); assert(ok and text:find("/crew accept"), text)
ok, text = commands.party(2, { "accept" }); assert(ok)
ok, text = commands.crew(1, {}); assert(ok and text == "Crew: Jack (leader), Kei", text)
ok, text = commands.crew(1, { "matchmaking" }); assert(ok and text:find("Matchmaking is off"))
ok, text = commands.crew(2, { "matchmaking", "on" }); assert(not ok and text:find("leader"))
ok, text = commands.crew(1, { "lead", "2" }); assert(ok and Crew.of(1).leader == 2)
ok, text = commands.crew(2, { "kick", "1" }); assert(ok and Crew.of(1) == nil and Crew.of(2) == nil)
ok, text = commands.crew(1, { "dance" }); assert(not ok and text:find("usage"))
ok, text = commands.crew(0, {}); assert(not ok, "the console has no crew")

-- ── missions: entry by crew ──
local function open(id) assert(Missions.open(id, blackout.id)); for i = #dialogs, 1, -1 do if dialogs[i].id == id then return dialogs[i].payload end end end
local function board(id, type, extra)
    clock = clock + 2000
    local payload = { session = open(id).session }
    for k, v in pairs(extra or {}) do payload[k] = v end
    actions[type](id, payload)
    return lastResult(id, type)
end
local function queue(id) return providers.missionQueue(id) end
assert(Crew.invite(1, 2) and Crew.accept(2))
r = board(2, "mission.tag", { difficulty = "standard" })
assert(not r.ok and r.text == "Your crew leader tags the crew in. Leave the crew to go solo.", r.text)
r = board(3, "mission.tag", { difficulty = "standard" })
assert(not r.ok and r.text:find("Form a crew"), "alone below the minimum, matchmaking off: refused")
-- a stranger open to matchmaking waits in their own open lobby
assert(board(4, "mission.matchmaking", { on = true }).ok)
r = board(4, "mission.tag", { difficulty = "standard" })
assert(r.ok and queue(4).count == 1 and queue(4).state == "open", r.text)
-- the crew's private lobby: nobody else, countdown at the minimum
r = board(1, "mission.tag", { difficulty = "standard" })
assert(r.ok and queue(1).count == 2 and queue(2).count == 2 and queue(1).state == "countdown" and queue(4).count == 1, r.text)
assert(noticed(2, "Jack tagged the crew in"))
local snap = open(1)
assert(snap.entry.crew and snap.entry.size == 2 and snap.entry.leads and snap.entry.matchmaking == false and snap.entry.open == false)
assert(open(4).boards.standard.members[1].name == "Vi" and #open(4).boards.standard.members == 1, "the stranger does not see the crew's lobby as theirs")
-- a crew member leaving the crew comes off its entry; the countdown stops
assert(Crew.leave(2))
assert(queue(2) == false and noticed(2, "You left the crew"), "leaving the crew untags")
assert(queue(1).count == 1 and queue(1).state == "open", "below the minimum: the launch is cancelled")
assert(noticed(1, "needs 2"))
-- joining a crew drops a player's own tag
r = board(1, "mission.untag")
assert(r.ok and queue(1) == false)
assert(Crew.invite(1, 4) and Crew.accept(4))
assert(queue(4) == false and noticed(4, "You joined a crew"), "a new member's own tag drops")
-- the leader opens the crew to matchmaking: its lobby takes strangers again
assert(board(1, "mission.matchmaking", { on = true }).ok and Crew.matchmaking(4), "the crew's flag")
r = board(1, "mission.tag", { difficulty = "standard" })
assert(r.ok and queue(1).count == 2 and queue(1).state == "open", "open: it waits to be full")
assert(board(3, "mission.matchmaking", { on = true }).ok)
r = board(3, "mission.tag", { difficulty = "standard" })
assert(r.ok and queue(3).count == 3 and queue(1).count == 3, "a solo player open to matchmaking fills the crew's empty place")
-- closing it again: the lobby launches with who is in it
assert(board(1, "mission.matchmaking", { on = false }).ok)
assert(queue(1).state == "countdown", "closed with the minimum: the countdown starts")
-- a crew in somebody else's open lobby that closes itself comes off that board
r = board(1, "mission.untag"); board(4, "mission.untag"); board(3, "mission.untag")
assert(queue(1) == false and queue(3) == false)
r = board(3, "mission.tag", { difficulty = "standard" })
assert(r.ok and queue(3).count == 1, "Rosa's open lobby")
assert(board(1, "mission.matchmaking", { on = true }).ok)
r = board(1, "mission.tag", { difficulty = "standard" })
assert(r.ok and queue(1).count == 3 and not queue(1).host, "the crew joined Rosa's open lobby")
assert(board(1, "mission.matchmaking", { on = false }).ok)
assert(queue(1) == false and queue(4) == false and queue(3).count == 1, "the crew left the shared board, Rosa stays")
assert(noticed(4, "Matchmaking off"))

print("PASS: crews (invite/accept/decline/leave/kick/lead, lead passing, dissolve, expiry, disconnect, character change), page action validation, HUD state (you/leader/life/far, pushes), /crew + /party, mission entry by crew (leader only, private lobby, countdown at the minimum, leaving untags, joining untags, matchmaking toggle open/close/shared board)")
