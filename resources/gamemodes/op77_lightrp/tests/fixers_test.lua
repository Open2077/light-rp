-- Fixer gigs (server/modules/fixers.lua), server side with the host and op77_neuralink
-- stubbed: the "Fixer gig" tag of a mission definition (no board), an offer by text,
-- Take the job / Pass, the brief with the meet point, sharing with a number, joining,
-- the meeting (countdown when the whole crew is there), the launch as a mission, the
-- payout and the fixer's last text, expiry, bail, "Go now", the dispatcher.
math.randomseed(7)
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
local timeouts = {}
_G.SetTimeout = function(_, fn) timeouts[#timeouts + 1] = fn end
_G.json = { encode = function(v)
    local function enc(x)
        if type(x) == "table" then local parts = {} for k, y in pairs(x) do parts[#parts + 1] = tostring(k) .. "=" .. enc(y) end table.sort(parts) return "{" .. table.concat(parts, ",") .. "}" end
        return tostring(x)
    end
    return enc(v)
end }
local handlers = {}
_G.AddEventHandler = function(name, fn) handlers[name] = fn end
_G.RegisterNetEvent = function() end

local positions, buckets, life = {}, {}, {}
local notices, results, paid = {}, {}, {}
_G.GetPlayers = function() local t = {} for id in pairs(positions) do t[#t + 1] = tostring(id) end table.sort(t) return t end
_G.GetPlayerName = function(id) return positions[id] and ("P" .. id) or nil end
_G.GetPlayerRoutingBucket = function(id) return buckets[id] or 0 end
_G.SetPlayerRoutingBucket = function(id, b) buckets[id] = b return true end
_G.TriggerClientEvent = function() end
_G.Open77 = { players = {
    position = function(id) local p = positions[id]; return p and { x = p.x, y = p.y, z = p.z, bucket = buckets[id] or 0 } end,
    get = function(id) return { position = positions[id], health = 100, maxHealth = 100, armor = 0, lifePhase = "alive" } end,
    getLifeState = function(id) return { phase = life[id] or "alive" } end,
    heal = function() return true end,
    teleport = function(id, spot, opts)
        return { await = function() buckets[id] = opts.bucket; positions[id] = { x = spot.x, y = spot.y, z = spot.z }; return true end }
    end,
} }
_G.LightRpEvents = { net = { mission = "op77_lightrp:mission" } }

-- op77_neuralink: lines by number, rich messages kept with their meta
local lines, messages, msgSeq, toasts = {}, {}, 0, {}
local function numberOfPlayer(id) return string.format("555-%04d", id) end
local neuralink = {
    npcLine = function(_, key, number, name) lines[number] = { npc = key, name = name }; return number end,
    isInstalled = function(_, id) return positions[id] ~= nil and id ~= 9 end,
    getNumber = function(_, id) return positions[id] and numberOfPlayer(id) or nil end,
    getPlayerByNumber = function(_, number) for id in pairs(positions) do if numberOfPlayer(id) == number then return id end end end,
    sendMessage = function(_, from, to, body, meta)
        if type(to) == "string" then
            local known = false
            for id in pairs(positions) do if numberOfPlayer(id) == to then known = true; to = id end end
            if not known then return nil, "unknown_number" end
        end
        msgSeq = msgSeq + 1
        messages[msgSeq] = { id = msgSeq, from = from, to = to, body = body, meta = meta }
        return msgSeq, 100 + to
    end,
    notify = function(_, id, title, body) toasts[#toasts + 1] = { id = id, title = title, body = body }; return true end,
    updateMessage = function(_, id, patch) local m = messages[id]; if not m then return false end; m.meta = m.meta or {}; for k, v in pairs(patch) do m.meta[k] = v end; return true end,
}
_G.exports = setmetatable({}, { __index = function(_, res) if res == "op77_neuralink" then return neuralink end end })
-- the database calls come over op77_neuralink:rpc (an export cannot yield), answered at once here
_G.TriggerEvent = function(name, ...) local h = handlers[name]; if h then h(...) end end
local rpcOps = { npcLine = function(a) return neuralink.npcLine(nil, a.key, a.number, a.name) end,
    sendMessage = function(a) return neuralink.sendMessage(nil, a.from, a.to, a.body, a.meta) end,
    updateMessage = function(a) return neuralink.updateMessage(nil, a.id, a.patch) end }
handlers["op77_neuralink:rpc"] = function(id, op, args, reply)
    local a, b = rpcOps[op](args)
    if a == nil or a == false then handlers[reply](id, false, b) else handlers[reply](id, true, a, b) end
end

local modules, actions, commands, providers = {}, {}, {}, {}
local chars = {}
_G.LightRP = {
    nowMs = function() return clock end, log = function() end,
    module = function(name, def) def.name = name; modules[#modules + 1] = def; LightRP[name] = LightRP[name] or def; return def end,
    eachModule = function(hook, ...) for _, m in ipairs(modules) do if m[hook] then m[hook](...) end end end,
    action = function(name, fn) actions[name] = fn end,
    command = function(name, _, fn) commands[name] = fn end,
    stateProvider = function(key, fn) providers[key] = fn end,
    state = function() end,
    notice = function(id, n) notices[#notices + 1] = { id = id, title = n.title, body = n.body } end,
    result = function(id, ok, text, action) results[#results + 1] = { id = id, ok = ok, text = text, action = action } end,
    dialog = function() end, interaction = function() end, removeInteraction = function() end,
    characters = {
        isRegistered = function(id) return chars[id] ~= nil end,
        displayName = function(id) return chars[id] or ("P" .. tostring(id)) end,
        get = function(id) return chars[id] and { status = "active", identifier = "id-" .. id, key = "default" } end,
    },
    money = { addBank = function(id, amount) paid[id] = (paid[id] or 0) + amount; return true end, format = function(n) return "$" .. n end },
    db = { ready = false, schema = function() end, single = function() end, run = function() end },
    parties = { of = function() return nil end },
}

-- ── the "Fixer gig" tag on a definition ──
dofile("shared/safezones.lua")
dofile("shared/mission_defs.lua")
local D = LightRpMissionDefs
local base = { title = "Burn Notice", type = "eliminate", enabled = true, point = { x = 100, y = 200, z = 10 },
    perimeter = { shape = "circle", center = { x = 100, y = 200, z = 10 }, radius = 40, minZ = 0, maxZ = 40 },
    starts = { { x = 100, y = 200, z = 10, heading = 0 } },
    spawns = { { id = "a", position = { x = 110, y = 200, z = 10 }, enemy = "militech", count = 2, trigger = "start" } } }
local def = assert(D.validate(base))
assert(def.fixer.enabled == false and def.fixer.contact == "any", "a mission is a board mission by default")
assert(D.point(def).fixer == false or D.point(def).fixer == nil)
base.fixer = { enabled = true, contact = "nix", brief = "Torch the stash, leave no witnesses." }
def = assert(D.validate(base))
local fp = D.point(def)
assert(fp.fixer == true and fp.fixerContact == "nix" and fp.fixerBrief == "Torch the stash, leave no witnesses.", "the tag reaches the board point")
base.fixer = { enabled = true, brief = string.rep("x", 241) }
assert(not D.validate(base), "brief limited to 240")
base.fixer = { enabled = "yes" }
assert(not D.validate(base), "enabled is a boolean")

dofile("server/config/missions.lua")
dofile("server/modules/missions.lua")
dofile("server/config/fixers.lua")
LightRpFixers.dispatch.chance, LightRpFixers.dispatch.settleSeconds, LightRpFixers.dispatch.firstDelaySeconds = 0, 0, 0
dofile("server/modules/fixers.lua")
local Missions, Fixers = LightRP.missions, LightRP.fixers

fp.id = "gig_burn"
fp.difficulties[1].min, fp.difficulties[1].max = 1, 3
Missions.addPoint(fp)
assert(#Missions.fixerPoints() == 1 and Missions.fixerPoints()[1].id == "gig_burn", "the catalogue lists the tagged mission")
local okOpen, whyOpen = Missions.open(1, "gig_burn")
assert(not okOpen and whyOpen:find("fixers"), "no board for a fixer gig")

local at = fp.position
local function spawn(id, name, x, y)
    chars[id] = name
    positions[id] = { x = x or 0, y = y or 0, z = at.z }
    buckets[id] = 0
    Fixers.onGameplayReady(id)
end
local function lastTo(id) local best; for _, m in pairs(messages) do if m.to == id and (not best or m.id > best.id) then best = m end end return best end
local function press(id, m, action, value)
    handlers["op77_neuralink:messageAction"](id, { messageId = m.id, action = action, value = value, source = m.meta and m.meta.source, ref = m.meta and m.meta.ref })
end
local function lastResult(id) for i = #results, 1, -1 do if results[i].id == id then return results[i] end end end

spawn(1, "Jack Okonkwo"); spawn(2, "Kei Mori"); spawn(3, "Rosa Vasquez"); spawn(4, "Vi Asada"); spawn(5, "Lou Pass")

-- ── an offer, taken ──
local ok, gig = Fixers.offer(1, "gig_burn", "standard")
assert(ok, tostring(gig))
local offer = lastTo(1)
assert(offer.from == "555-0619" and lines["555-0619"].name:find("Nix"), "the mission's fixer (Nix) texts from its own line")
assert(offer.body:find("Burn Notice") and offer.meta.card and offer.meta.actions[1].id == "accept" and offer.meta.actions[2].id == "decline")
assert(not select(1, Fixers.offer(1)), "one gig at a time")
press(1, offer, "accept")
assert(offer.meta.resolved and offer.meta.resolved.label == "Job taken", "the offer's buttons give way")
local brief = lastTo(1)
assert(brief.id ~= offer.id and brief.meta.location and brief.meta.location.x == at.x, "the brief carries the meet point")
assert(brief.body:find("Torch the stash"), "the brief carries the objective (the fixer brief)")
local ids = {}
for _, a in ipairs(brief.meta.actions) do ids[a.id] = a end
assert(ids.share and ids.share.input == "contact" and ids.go and ids.bail, "share / go / bail")
local hud = providers.fixerGig(1)
assert(hud and hud.state == "accepted" and hud.crew == 1 and hud.here == 0 and hud.owner and hud.meetInMs > 0, "the gig chip")

-- ── share with numbers: unknown line, then two players ──
press(1, brief, "share", "555-9999")
assert(not lastResult(1).ok and lastResult(1).text:find("No neural line"), "an unknown number is refused")
press(1, brief, "share", numberOfPlayer(2))
assert(lastResult(1).ok, "shared")
local invite2 = lastTo(2)
assert(invite2.meta.actions[1].id == "join" and invite2.body:find("Jack Okonkwo"), "the shared offer names who vouched")
press(1, brief, "share", numberOfPlayer(2))
assert(not lastResult(1).ok, "one pending offer per line")
press(1, brief, "share", numberOfPlayer(3))
local invite3 = lastTo(3)
press(3, invite3, "pass")
assert(invite3.meta.resolved.label == "Passed" and Fixers.gigOf[3] == nil)
press(2, invite2, "join")
assert(invite2.meta.resolved.label == "Joined" and providers.fixerGig(2).crew == 2, "2 joined the crew")
local brief2 = lastTo(2)
assert(brief2.meta.location and brief2.body:find("You're in"), "the joiner's brief")
local ids2 = {}
for _, a in ipairs(brief2.meta.actions) do ids2[a.id] = true end
assert(not ids2.go and ids2.bail and ids2.share, "only the owner says go")
press(2, brief2, "go")
assert(not lastResult(2).ok)
-- "Go now" far from the point says why, in the phone and in the conversation
local m0 = msgSeq
press(1, brief, "go")
assert(not lastResult(1).ok and lastResult(1).text:find("m away"), "the distance is given: " .. tostring(lastResult(1).text))
assert(toasts[#toasts].id == 1 and toasts[#toasts].body:find("m away"), "a toast in the phone")
assert(msgSeq == m0 + 1 and messages[msgSeq].to == 1 and messages[msgSeq].body:find("m away"), "the fixer writes why")

-- ── the meeting: one there, then both -> countdown -> launch ──
positions[1] = { x = at.x + 3, y = at.y, z = at.z + 8 } -- a floor above the point still counts
tick(1000)
assert(providers.fixerGig(1).here == 1 and providers.fixerGig(1).state == "accepted", "waiting for the whole crew")
positions[2] = { x = at.x - 4, y = at.y, z = at.z }
tick(1000)
assert(providers.fixerGig(1).state == "countdown", "the whole crew at the point: countdown")
positions[2] = { x = at.x + 300, y = at.y, z = at.z }
tick(1000)
assert(providers.fixerGig(1).state == "accepted", "someone walked off: on hold")
positions[2] = { x = at.x - 4, y = at.y, z = at.z }
for _ = 1, LightRpFixers.launchSeconds + 3 do tick(1000) end
local inst = Missions.instanceOf(1)
assert(inst and Missions.instanceOf(2) == inst and inst.gig and inst.gig.payout == 8000 and buckets[1] == inst.bucket, "the gig runs as a mission")
assert(providers.fixerGig(1) == false, "the mission chip takes over")
Missions.complete(inst.id)
assert(paid[1] == 8000 and paid[2] == 8000, "each operator paid")
assert(lastTo(1).body:find("sent") or lastTo(1).body:find("LEGEND") or lastTo(1).body:find("clean"), "the fixer's last text")
assert(brief.meta.resolved.label == "Paid" and Fixers.gigOf[1] == nil and Fixers.gigOf[2] == nil, "the gig is closed")

-- ── a fixer offers only difficulties of the owner's reputation tier ──
for _ = 1, 12 do
    ok, gig = Fixers.offer(4, "gig_burn")
    assert(ok and gig.difficulty == "standard", "tier I: standard gigs only, got " .. tostring(gig and gig.difficulty))
    Fixers.close(gig, "test", "cancelled")
end

-- ── expiry ──
ok, gig = Fixers.offer(4, "gig_burn")
assert(ok)
local offer4 = lastTo(4)
for _ = 1, LightRpFixers.offerSeconds + 2 do tick(1000) end
assert(offer4.meta.resolved.label == "Expired" and Fixers.gigOf[4] == nil, "an unanswered offer expires")
press(4, offer4, "accept")
assert(offer4.meta.resolved.label == "Expired", "a late press does nothing")

-- ── pass ──
ok = Fixers.offer(5, "gig_burn")
local offer5 = lastTo(5)
press(5, offer5, "decline")
assert(offer5.meta.resolved.label == "Passed" and lastTo(5).id ~= offer5.id and Fixers.gigOf[5] == nil, "pass: the fixer answers, the gig closes")

-- ── bail, and "Go now" with the minimum ──
positions[1], buckets[1], positions[2], buckets[2] = { x = 0, y = 0, z = at.z }, 0, { x = 0, y = 0, z = at.z }, 0
Fixers.offer(1, "gig_burn", "standard"); press(1, lastTo(1), "accept")
local b1 = lastTo(1)
press(1, b1, "share", numberOfPlayer(2)); press(2, lastTo(2), "join")
local b2 = lastTo(2)
press(1, b1, "bail")
assert(b1.meta.resolved.label == "You bailed" and Fixers.gigOf[1] == nil, "the owner bails")
local nb2 = lastTo(2)
assert(nb2.id ~= b2.id and providers.fixerGig(2).owner, "the crew passes to the next operator, with Go now")
positions[2] = { x = at.x, y = at.y + 2, z = at.z }
press(2, nb2, "go")
assert(providers.fixerGig(2).state == "countdown", "go now with the minimum present")
for _ = 1, LightRpFixers.launchSeconds + 2 do tick(1000) end
assert(Missions.instanceOf(2) and Missions.instanceOf(2).gig, "launched alone")
Missions.fail(Missions.instanceOf(2).id, "wiped")
assert(nb2.meta.resolved.label == "Failed")

-- ── the dispatcher: everybody eligible with chance 1, no Neural-Link no text ──
LightRpFixers.dispatch.chance = 1
spawn(9, "No Implant")
for id = 1, 9 do if positions[id] then buckets[id] = 0 end end
local before = msgSeq
Fixers.dispatch(clock)
local got = {}
for i = before + 1, msgSeq do got[messages[i].to] = true end
assert(not got[9], "no Neural-Link, no offer")
assert(not got[1] and not got[4] and not got[5], "a recent offer cools a player down")
assert(got[3] and got[2], "free players get a text (a shared job is no cooldown)")
assert(commands["fixers.list"](0, {}))

-- ── crews: the dispatcher texts leaders, not members; a leader's job brings the crew ──
spawn(10, "Mae Lead"); spawn(11, "Ana Mate"); spawn(12, "Bo Down"); spawn(13, "Cy Member")
local inCrew = { [10] = true, [11] = true, [12] = true, [9] = true }
local crewMock = { id = "crew:3", leader = 10, members = { 10, 11, 9, 12 } }
local otherCrew = { id = "crew:4", leader = 2, members = { 2, 13 } }
LightRP.parties = { of = function(id) if inCrew[id] then return crewMock elseif id == 13 or id == 2 then return otherCrew end end }
before = msgSeq
Fixers.dispatch(clock)
got = {}
for i = before + 1, msgSeq do got[messages[i].to] = true end
assert(got[10] and not got[11] and not got[13], "a crew member is not texted: the leader takes the jobs")
local crewOffer
for i = before + 1, msgSeq do if messages[i].to == 10 then crewOffer = messages[i] end end
life[12] = "revivepending"
press(10, crewOffer, "accept")
local crewGig = Fixers.gigOf[10] and providers.fixerGig(10)
assert(crewGig and crewGig.crew == 2 and Fixers.gigOf[11] == Fixers.gigOf[10], "the free member with a Neural-Link joins the gig's crew")
assert(Fixers.gigOf[9] == nil and Fixers.gigOf[12] == nil, "no implant, or down: stays out")
local told
for i = #notices, 1, -1 do if notices[i].id == 10 and notices[i].title == "CREW" then told = notices[i].body; break end end
assert(told and told:find("Your crew comes along: Ana Mate.", 1, true) and told:find("No Implant (no Neural-Link)", 1, true) and told:find("Bo Down (down)", 1, true), told)
assert(lastTo(11).body:find("You're in"), "the member gets the brief")
life[12] = nil

-- ── a crew member below the gig's difficulty: never refused, their tier's reward, told once ──
-- (owner decision 2026-11-03: the gig rule now holds everywhere)
spawn(14, "Op Lead", at.x + 1, at.y); spawn(15, "Street Mate", at.x + 2, at.y)
Missions.addReputation(14, 1500)
assert(Missions.tier(14) == 3 and Missions.tier(15) == 1)
local gigPoint = Missions.point("gig_burn")
local critical = gigPoint.difficulties[3]
assert(critical.id == "critical")
critical.min, critical.max = 1, 3
local opCrew = { id = "crew:5", leader = 14, members = { 14, 15 } }
LightRP.parties = { of = function(id) if id == 14 or id == 15 then return opCrew end end }
local okCritical, criticalGig = Fixers.offer(14, "gig_burn", "critical")
assert(okCritical and criticalGig.difficulty == "critical", tostring(criticalGig))
local noticesBefore = #notices
press(14, lastTo(14), "accept")
assert(Fixers.gigOf[15] == Fixers.gigOf[14], "the Street member comes along")
local streetTold = {}
for i = noticesBefore + 1, #notices do if notices[i].id == 15 and notices[i].title == "STREET CRED" then streetTold[#streetTold + 1] = notices[i].body end end
assert(#streetTold == 1 and streetTold[1] == "Critical is above your street cred: you play it, you earn the Standard reward (+100 reputation).",
    tostring(streetTold[1]))
for i = noticesBefore + 1, #notices do assert(not (notices[i].id == 14 and notices[i].title == "STREET CRED"), "the owner is told nothing") end
for _ = 1, LightRpFixers.launchSeconds + 3 do tick(1000) end
local criticalInst = Missions.instanceOf(14)
assert(criticalInst and Missions.instanceOf(15) == criticalInst and criticalInst.difficulty == "critical", "both play the critical gig")
Missions.complete(criticalInst.id)
assert(Missions.reputation(15) == LightRpMissions.reputationGain.standard, "the Street earns the standard reward")
assert(Missions.reputation(14) == 1500 + LightRpMissions.reputationGain.critical, "the owner earns the critical reward")
local gigDone
for i = #notices, 1, -1 do if notices[i].id == 15 and notices[i].title == "GIG COMPLETE" then gigDone = notices[i].body; break end end
assert(gigDone and gigDone:find("+100 reputation (Standard reward)", 1, true), gigDone)
LightRP.parties = { of = function() return nil end }

print("PASS: fixer gigs (editor tag, no board, offer/take/pass, brief with meet point + objective, share to numbers, join/pass, meeting countdown + hold, launch as mission, payout + fixer text, expiry, bail + new owner, go now, dispatcher, crews, a crew member below the gig's difficulty)")
