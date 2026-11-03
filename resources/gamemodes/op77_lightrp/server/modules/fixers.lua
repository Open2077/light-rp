-- Fixer gigs: the fixers (server-side characters, server/config/fixers.lua) text
-- online players jobs taken at random from the gig catalogue (authored missions
-- tagged "Fixer gig" in the mission editor: no board in the city, nobody tags in).
--
--   offer     the fixer's text with a job card: Take the job / Pass (offerSeconds)
--   accepted  the fixer's brief: the meeting point (Pin on map), the objective, and
--             Share the job (a contact or a number) / Go now / Bail. A shared offer
--             reaches the other line from the same fixer; whoever accepts joins the
--             crew, up to the difficulty's squad size.
--   meet      the crew goes to the point; once everyone who accepted is there (and at
--             least the difficulty's minimum), a countdown, then the gig runs as a
--             mission (LightRP.missions.launchGig). "Go now" (the owner) launches with
--             those present; past meetMinutes the gig launches with them, or dies.
--   end       the mission pays (missions.lua, gig payout), the fixer texts the crew.
--
-- Crews (server/modules/parties.lua): the fixers text crew leaders, not their
-- members, and a leader who takes a job brings the crew: every free member with
-- a Neural-Link joins the gig's crew at once (up to the difficulty's size).
--
-- Messages go through op77_neuralink: its op77_neuralink:rpc event (npcLine,
-- sendMessage, updateMessage: they touch its database, and an export cannot yield),
-- answered on op77_lightrp:fixers:rpc; the buttons come back as the event
-- op77_neuralink:messageAction. Everything that talks to the phone runs in a thread.
-- Gigs live in memory: a server restart drops them (their buttons then answer "expired").
local C = LightRpFixers
local Missions = LightRP.missions
local Fixers = LightRP.module("fixers", {})

local gigs = {}          -- id -> gig
local gigOf = {}         -- playerId -> gig id (owner, crew member or pending invite target)
local lastOffer = {}     -- playerId -> ms of their last offer
local joinedAt = {}      -- playerId -> ms they came into the world
local lastChat = {}      -- playerId -> ms of the fixer's last auto-reply
local numbers = {}       -- contact id -> phone number of its line
local gigSeq = 0
local bootId = tostring(math.random(100000, 999999))
local dispatchOn = C.enabled ~= false

local function now() return LightRP.nowMs() end
local function name(id) return LightRP.characters.displayName(id) end
local function log(...) LightRP.log(...) end
local function bucketOf(id) return type(GetPlayerRoutingBucket) == "function" and GetPlayerRoutingBucket(id) or 0 end
local function money(n) return LightRP.money and LightRP.money.format(n) or ("€$" .. tostring(n)) end

-- ---------------------------------------------------------------------------
-- Contacts (the fixers' lines)

local contactById = {}
for _, c in ipairs(C.contacts) do contactById[c.id] = c end

-- Read-only exports of op77_neuralink (in memory, they never yield).
local function neural(fn, ...)
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil, tostring(a) end
    return a, b
end

-- A call to op77_neuralink that touches its database: the event, then the answer.
-- Must run in a thread (it waits).
local REPLY = "op77_lightrp:fixers:rpc"
local rpcSeq, rpcReplies, rpcDownUntil = 0, {}, 0
AddEventHandler(REPLY, function(id, ok, a, b)
    local from = tonumber(source)
    if from and from > 0 then return end
    if type(id) == "number" then rpcReplies[id] = { ok = ok == true, a = a, b = b } end
end)
local function nl(op, args, wait)
    if now() < rpcDownUntil then return nil, "neuralink_unavailable" end
    rpcSeq = rpcSeq + 1
    local id = rpcSeq
    TriggerEvent("op77_neuralink:rpc", id, op, args, REPLY)
    if wait == false then rpcReplies[id] = nil; return true end
    local deadline = now() + 8000
    while not rpcReplies[id] and now() < deadline do Wait(25) end
    local r = rpcReplies[id]
    rpcReplies[id] = nil
    if not r then
        -- the phone resource does not answer: do not stall every gig on it for long
        rpcDownUntil = now() + 30000
        log("fixers: op77_neuralink did not answer %s", op)
        return nil, "neuralink_timeout"
    end
    if not r.ok then return nil, r.a end
    return r.a, r.b
end
Fixers.nl = nl

-- The fixer's phone number (its NPC line is created once, then kept).
local function numberOf(contact)
    if numbers[contact.id] then return numbers[contact.id] end
    local number, why = nl("npcLine", { key = "fixer_" .. contact.id, number = contact.number, name = contact.name })
    if not number then log("fixers: no line for %s (%s)", contact.id, tostring(why)); return nil end
    numbers[contact.id] = number
    return number
end
Fixers.numberOf = numberOf

local function pick(list) return list[math.random(1, #list)] end
local function fill(text, vars)
    return (text:gsub("{(%w+)}", function(k) local v = vars[k]; return v ~= nil and tostring(v) or ("{" .. k .. "}") end))
end
local function line(contact, kind, vars)
    local pool = contact.lines and contact.lines[kind]
    if type(pool) ~= "table" or #pool == 0 then return nil end
    return fill(pick(pool), vars)
end

-- One text from the gig's fixer to a player (id) or a number. Returns the message id.
local function text(gig, to, body, meta)
    local from = numberOf(gig.contact)
    if not from or not body then return nil, "no_line" end
    local id, why = nl("sendMessage", { from = from, to = to, body = body, meta = meta })
    if not id then log("fixers: text to %s failed (%s)", tostring(to), tostring(why)) end
    return id, why
end
-- fire and forget: the button state follows without holding the caller
local function update(messageId, patch)
    if messageId then nl("updateMessage", { id = messageId, patch = patch }, false) end
end
local function resolve(messageId, label, tone)
    update(messageId, { resolved = { label = label, tone = tone or "dim" } })
end

-- ---------------------------------------------------------------------------
-- Gigs

local function pointOf(gig) return Missions.point(gig.point) end
local function diffOf(gig)
    local point = pointOf(gig)
    for _, d in ipairs(point and point.difficulties or {}) do if d.id == gig.difficulty then return d end end
end
local function ref(gig) return "gig:" .. bootId .. ":" .. gig.id end
local function gigOfRef(r)
    local boot, id = tostring(r or ""):match("^gig:(%d+):(%d+)$")
    if boot ~= bootId then return nil end
    return gigs[tonumber(id)]
end

local function vars(gig, viewer)
    local point, d = pointOf(gig), diffOf(gig)
    return {
        player = viewer and name(viewer) or "", title = point and point.title or "the job", location = point and point.location or "Night City",
        difficulty = d and d.label or "", payout = money(gig.payout), objective = gig.objective or "", crew = #gig.crew,
        max = d and d.max or 1, minutes = d and d.minutes or 15, owner = gig.owner and name(gig.owner) or "", fixer = gig.contact.name,
    }
end

local function crewIndex(gig, id) for i, m in ipairs(gig.crew) do if m == id then return i end end end
local function card(gig, tag, lines)
    local point, d = pointOf(gig), diffOf(gig)
    return { tag = tag, title = point and point.title or "Gig",
        subtitle = string.format("%s · %s · %d-%d operators", point and point.location or "Night City", d and d.label or "", d and d.min or 1, d and d.max or 1),
        lines = lines }
end

-- Is this player free for a gig (an offer, an invitation, the crew)?
local function free(id, ignoreGig)
    if not LightRP.characters.isRegistered(id) then return false, "no active character" end
    if not ignoreGig and gigOf[id] then return false, "already on a gig" end
    if Missions.instanceOf(id) then return false, "on a mission" end
    if LightRP.activities and LightRP.activities.owns(id) then return false, "in an activity" end
    local life = Open77.players.getLifeState(id)
    if life and life.phase ~= "alive" then return false, "down" end
    if bucketOf(id) ~= 0 then return false, "not in the city" end
    return true
end

local function hasPhone(id)
    local installed = neural(function() return exports.op77_neuralink:isInstalled(id) end)
    local number = neural(function() return exports.op77_neuralink:getNumber(id) end)
    return installed == true and type(number) == "string", number
end

local function pushGig(gig)
    for _, id in ipairs(gig.crew) do LightRP.state(id, "fixerGig") end
end

local function forget(gig, id)
    if gigOf[id] == gig.id then gigOf[id] = nil end
    LightRP.state(id, "fixerGig")
end

-- Closes a gig for good: every open button resolved, the crew told (unless launched).
local function close(gig, why, kind)
    if gig.state == "closed" then return end
    local wasRunning = gig.state == "running"
    gig.state = "closed"
    gigs[gig.id] = nil
    if gig.offerMessage and gig.offerOpen then resolve(gig.offerMessage, why == "expired" and "Expired" or "Closed") end
    for _, inv in pairs(gig.invites) do if inv.open then resolve(inv.messageId, "Closed") end end
    for id, msg in pairs(gig.briefs) do resolve(msg, kind == "success" and "Paid" or kind == "failed" and "Failed" or "Job off", kind == "success" and "ok" or kind == "failed" and "danger" or "dim") end
    if not wasRunning and kind == "cancelled" then
        for _, id in ipairs(gig.crew) do text(gig, id, line(gig.contact, "cancelled", vars(gig, id)) or "Job's off.") end
    end
    for _, id in ipairs(gig.crew) do forget(gig, id) end
    for key, inv in pairs(gig.invites) do if inv.player then forget(gig, inv.player) end end
    if gig.owner then forget(gig, gig.owner) end
    log("fixers: gig %d (%s) closed: %s", gig.id, gig.point, tostring(why))
end
Fixers.close = close

-- The brief: where, what, and the crew's buttons.
local function brief(gig, id, joining)
    local point = pointOf(gig)
    local d = diffOf(gig)
    local owner = id == gig.owner
    local actions = { { id = "share", label = "Share the job", input = "contact" } }
    if owner then actions[#actions + 1] = { id = "go", label = "Go now", style = "primary" } end
    actions[#actions + 1] = { id = "bail", label = "Bail", style = "danger" }
    local body = joining and fill("You're in. {owner} runs the crew. Meet point's pinned. {objective}", vars(gig, id))
        or line(gig.contact, "accepted", vars(gig, id)) or ("Meet point's pinned. " .. (gig.objective or ""))
    local msg = text(gig, id, body, {
        source = "op77_lightrp", ref = ref(gig),
        card = card(gig, "GIG · MEET POINT", {
            "Objective: " .. (gig.objective or "the job."),
            string.format("Pay: %s each · %d min on the clock", money(gig.payout), d and d.minutes or 15),
            string.format("Meet within %d min. Everyone who took the job must be there.", C.meetMinutes),
        }),
        location = { x = point.position.x, y = point.position.y, z = point.position.z, label = "the meet point" },
        actions = actions,
    })
    gig.briefs[id] = msg
end

local function crewNotice(gig, title, body, kind)
    for _, id in ipairs(gig.crew) do LightRP.notice(id, { kind = kind or "contract", title = title, body = body, durationMs = 8000 }) end
end

-- Offer a gig to a player: the fixer's text with Take the job / Pass.
function Fixers.offer(playerId, pointId, difficultyId)
    local ok, why = free(playerId)
    if not ok then return false, why end
    local phone = hasPhone(playerId)
    if not phone then return false, "no Neural-Link" end
    local catalog = Missions.fixerPoints()
    if #catalog == 0 then return false, "the gig catalogue is empty (tag a mission as a fixer gig in the editor)" end
    local point
    if pointId then
        point = Missions.point(pointId)
        if not point or not point.fixer then return false, "that mission is not a fixer gig" end
    else point = pick(catalog) end
    -- the difficulty: asked, else weighted
    local d
    if difficultyId then
        for _, x in ipairs(point.difficulties) do if x.id == difficultyId then d = x end end
        if not d then return false, "unknown difficulty" end
    else
        -- only what the owner's reputation tier opens (docs/pve-progression.md)
        local offered = {}
        for _, x in ipairs(point.difficulties) do
            if type(Missions.tierAllows) ~= "function" or Missions.tierAllows(playerId, x) then offered[#offered + 1] = x end
        end
        if #offered == 0 then offered = { point.difficulties[1] } end
        local total = 0
        for _, x in ipairs(offered) do total = total + ((C.difficultyWeights or {})[x.id] or 1) end
        local roll = math.random() * total
        for _, x in ipairs(offered) do
            roll = roll - ((C.difficultyWeights or {})[x.id] or 1)
            if not d and roll <= 0 then d = x end
        end
        d = d or offered[1]
    end
    local contact = point.fixerContact and contactById[point.fixerContact] or pick(C.contacts)
    gigSeq = gigSeq + 1
    local gig = { id = gigSeq, point = point.id, difficulty = d.id, contact = contact, owner = playerId, crew = {}, invites = {}, briefs = {},
        state = "offered", payout = math.floor(d.payout * (C.payoutMultiplier or 1) + 0.5), offeredAt = now(),
        expiresAt = now() + C.offerSeconds * 1000, shares = 0, shareTimes = {},
        objective = (point.fixerBrief and point.fixerBrief ~= "") and point.fixerBrief or point.description }
    gigs[gig.id] = gig
    gigOf[playerId] = gig.id
    lastOffer[playerId] = now()
    local msg = text(gig, playerId, line(contact, "offer", vars(gig, playerId)), {
        source = "op77_lightrp", ref = ref(gig),
        card = card(gig, "GIG · " .. string.upper(point.type or "JOB"), {
            string.format("Pay: %s each", money(gig.payout)),
            string.format("Time limit: %d min", d.minutes),
            string.format("Answer within %d min", math.floor(C.offerSeconds / 60 + 0.5)),
        }),
        actions = { { id = "accept", label = "Take the job", style = "primary" }, { id = "decline", label = "Pass", style = "danger" } },
    })
    if not msg then gigs[gig.id] = nil; gigOf[playerId] = nil; return false, "the message could not be sent" end
    gig.offerMessage, gig.offerOpen = msg, true
    log("fixers: %s offered gig %d (%s, %s) to %s", contact.name, gig.id, point.title, d.label, name(playerId))
    return true, gig
end

local function launch(gig, members)
    local d = diffOf(gig)
    gig.state = "running"
    local ok, launched = Missions.launchGig(gig.point, gig.difficulty, members, {
        id = gig.id, payout = gig.payout, fixerName = gig.contact.name,
        onEnd = function(_, success, why) CreateThread(function()
            local crew = {}
            for _, id in ipairs(gig.crew) do crew[#crew + 1] = id end
            for _, id in ipairs(crew) do
                text(gig, id, line(gig.contact, success and "success" or "failed", vars(gig, id)) or (success and "Paid." or "That went sideways."))
            end
            close(gig, success and "success" or ("failed: " .. tostring(why)), success and "success" or "failed")
        end) end,
    })
    if not ok then
        gig.state = "accepted"
        crewNotice(gig, "GIG", "The job could not start: " .. tostring(launched) .. ".", "error")
        log("fixers: gig %d launch failed: %s", gig.id, tostring(launched))
        return false
    end
    -- whoever was not launched is out of the crew
    local inside = {}
    for _, id in ipairs(launched) do inside[id] = true end
    for i = #gig.crew, 1, -1 do
        local id = gig.crew[i]
        if not inside[id] then table.remove(gig.crew, i); resolve(gig.briefs[id], "Left behind"); gig.briefs[id] = nil; forget(gig, id) end
    end
    log("fixers: gig %d launched with %d operator(s) (%s)", gig.id, #launched, d and d.label or "?")
    pushGig(gig)
    return true
end

-- Where a player stands (`position` is nil after two idle seconds: the full read then).
local function positionOf(id)
    local p = Open77.players.position(id)
    if p then return p end
    local ok, read = pcall(Open77.players.get, id)
    if ok and type(read) == "table" and type(read.position) == "table" then return read.position end
end
-- Distance to the meet point: horizontal metres, and whether the height is close enough
-- (a point placed on a floor above or below the street still counts), or nil.
local function meetDistance(id, point)
    local p = point and positionOf(id)
    if not p or bucketOf(id) ~= 0 then return nil end
    local flat = math.sqrt((p.x - point.position.x) ^ 2 + (p.y - point.position.y) ^ 2)
    return flat, math.abs(p.z - point.position.z) <= (C.meetHeight or 15)
end
local function atMeet(id, point)
    local flat, level = meetDistance(id, point)
    return flat ~= nil and level and flat <= C.meetRadius
end
Fixers.atMeet = atMeet

-- Crew present at the meet point.
local function present(gig)
    local point = pointOf(gig)
    local list = {}
    for _, id in ipairs(gig.crew) do if point and atMeet(id, point) then list[#list + 1] = id end end
    return list
end

local function startCountdown(gig, members, forced)
    gig.state, gig.launchAt, gig.forced = "countdown", now() + C.launchSeconds * 1000, forced == true
    crewNotice(gig, "CREW ASSEMBLED", string.format("%s starts in %d seconds. Stay at the meet point.", pointOf(gig).title, C.launchSeconds))
    pushGig(gig)
end

-- ---------------------------------------------------------------------------
-- Buttons

local function join(gig, id, inviteKey)
    local d = diffOf(gig)
    local inv = gig.invites[inviteKey]
    if gig.state ~= "accepted" and gig.state ~= "countdown" then return false, "That job is closed." end
    if d and #gig.crew >= d.max then return false, "The crew is full." end
    local ok, why = free(id, gigOf[id] == gig.id)
    if not ok then return false, "You can't take it: " .. why .. "." end
    if crewIndex(gig, id) then return false, "You are already in." end
    gig.crew[#gig.crew + 1] = id
    gigOf[id] = gig.id
    if inv then inv.open = false; resolve(inv.messageId, "Joined", "ok") end
    brief(gig, id, true)
    crewNotice(gig, "CREW", string.format("%s joined the crew (%d/%d).", name(id), #gig.crew, d and d.max or #gig.crew))
    -- above their street cred: in all the same, for the reward of their own tier (told once)
    if d and type(Missions.tellCarried) == "function" then Missions.tellCarried(id, pointOf(gig), d, false) end
    if gig.state == "countdown" then gig.state, gig.launchAt = "accepted", nil end
    pushGig(gig)
    return true
end

-- The owner's crew comes along: every free member with a phone joins the gig.
local function bringCrew(gig, owner)
    local P = LightRP.parties
    local party = P and type(P.of) == "function" and P.of(owner) or nil
    if not party or party.leader ~= owner or #party.members < 2 then return end
    local came, out = {}, {}
    for _, member in ipairs(party.members) do
        if member ~= owner then
            local ok, why = free(member)
            if ok and not hasPhone(member) then ok, why = false, "no Neural-Link" end
            if ok then
                local joined, msg = join(gig, member, nil)
                if joined then came[#came + 1] = name(member) else out[#out + 1] = name(member) .. " (" .. tostring(msg):gsub("%.$", ""):lower() .. ")" end
            else
                out[#out + 1] = name(member) .. " (" .. tostring(why) .. ")"
            end
        end
    end
    local parts = {}
    if #came > 0 then parts[#parts + 1] = "Your crew comes along: " .. table.concat(came, ", ") .. "." end
    if #out > 0 then parts[#parts + 1] = "Staying out: " .. table.concat(out, ", ") .. "." end
    if #parts > 0 then LightRP.notice(owner, { kind = "contract", title = "CREW", durationMs = 8000, body = table.concat(parts, " ") }) end
end

local function leave(gig, id, why)
    local i = crewIndex(gig, id)
    if not i then return end
    table.remove(gig.crew, i)
    resolve(gig.briefs[id], "You bailed", "danger")
    gig.briefs[id] = nil
    forget(gig, id)
    if #gig.crew == 0 then return close(gig, why or "everyone bailed", "cancelled") end
    if gig.owner == id then
        gig.owner = gig.crew[1]
        -- the new owner gets the "Go now" button with a fresh brief
        resolve(gig.briefs[gig.owner], "Superseded")
        brief(gig, gig.owner, false)
        crewNotice(gig, "CREW", string.format("%s left. %s runs the crew now.", name(id), name(gig.owner)), "warning")
    else
        crewNotice(gig, "CREW", string.format("%s left the crew (%d left).", name(id), #gig.crew), "warning")
    end
    if gig.state == "countdown" then gig.state, gig.launchAt = "accepted", nil end
    pushGig(gig)
end
Fixers.leave = leave

local function share(gig, from, number)
    local d = diffOf(gig)
    if gig.state ~= "accepted" and gig.state ~= "countdown" then return false, "That job is closed." end
    if not crewIndex(gig, from) then return false, "You are not on this job." end
    if d and #gig.crew >= d.max then return false, "The crew is already full." end
    if gig.shares >= C.maxShares then return false, "The fixer won't take more names for this job." end
    local t = now()
    local recent = {}
    for _, at in ipairs(gig.shareTimes) do if t - at < 60000 then recent[#recent + 1] = at end end
    if #recent >= C.sharesPerMinute then return false, "Slow down: the fixer is still reading the last names." end
    if gig.invites[number] and gig.invites[number].open then return false, "That line already has the offer." end
    local target = neural(function() return exports.op77_neuralink:getPlayerByNumber(number) end)
    if target and crewIndex(gig, target) then return false, "Already in the crew." end
    local v = vars(gig, target)
    v.owner = name(from)
    local msg, why = text(gig, number, line(gig.contact, "shared", v) or fill("{owner} vouched for you. {title}, {location}. In?", v), {
        source = "op77_lightrp", ref = ref(gig),
        card = card(gig, "GIG · SHARED BY " .. string.upper(name(from)), {
            string.format("Pay: %s each", money(gig.payout)),
            string.format("Crew %d/%d", #gig.crew, d and d.max or #gig.crew),
            string.format("Answer within %d min", math.floor(C.offerSeconds / 60 + 0.5)),
        }),
        actions = { { id = "join", label = "Join the crew", style = "primary" }, { id = "pass", label = "Pass", style = "danger" } },
    })
    if not msg then
        if why == "unknown_recipient" or why == "unknown_number" or why == false then return false, "No neural line answers to " .. number .. "." end
        return false, "The offer could not reach " .. number .. "."
    end
    recent[#recent + 1] = t
    gig.shareTimes, gig.shares = recent, gig.shares + 1
    gig.invites[number] = { messageId = msg, at = t, open = true, from = from, player = target }
    if target and not gigOf[target] then gigOf[target] = gig.id end
    log("fixers: %s shared gig %d with %s", name(from), gig.id, number)
    return true, "Sent to " .. number .. "."
end

local function onAction(playerId, a)
    if type(a) ~= "table" or a.source ~= "op77_lightrp" or type(a.ref) ~= "string" or not a.ref:match("^gig:") then return end
    local gig = gigOfRef(a.ref)
    if not gig then resolve(a.messageId, "Expired"); return end
    -- The answer shows in the phone (a Neural-Link toast: the player pressed the button
    -- there, and the LightRP notices sit behind it) and in the HUD; refusals are logged.
    local function answer(ok, msg)
        if not msg then return end
        LightRP.result(playerId, ok, msg, "fixer." .. a.action)
        neural(function() return exports.op77_neuralink:notify(playerId, ok and "GIG" or "GIG · NOT NOW", msg) end)
        if not ok then
            log("fixers: %s %s on gig %d refused: %s", name(playerId), tostring(a.action), gig.id, msg)
            -- and the fixer says why, in the conversation (it stays written there)
            text(gig, playerId, msg)
        end
    end
    if a.action == "accept" and a.messageId == gig.offerMessage then
        if playerId ~= gig.owner or gig.state ~= "offered" then return answer(false, "That offer is not yours anymore.") end
        local ok, why = free(playerId, true)
        if not ok then return answer(false, "You can't take it: " .. why .. ".") end
        gig.offerOpen = false
        resolve(gig.offerMessage, "Job taken", "ok")
        gig.state, gig.crew, gig.meetUntil = "accepted", { playerId }, now() + C.meetMinutes * 60000
        brief(gig, playerId, false)
        bringCrew(gig, playerId)
        pushGig(gig)
        log("fixers: %s took gig %d", name(playerId), gig.id)
    elseif a.action == "decline" and a.messageId == gig.offerMessage then
        if playerId ~= gig.owner or gig.state ~= "offered" then return end
        gig.offerOpen = false
        resolve(gig.offerMessage, "Passed")
        text(gig, playerId, line(gig.contact, "declined", vars(gig, playerId)))
        close(gig, "declined", "declined")
    elseif a.action == "join" or a.action == "pass" then
        local key
        for k, inv in pairs(gig.invites) do if inv.messageId == a.messageId then key = k end end
        local inv = key and gig.invites[key]
        if not inv or not inv.open then return resolve(a.messageId, "Closed") end
        if a.action == "pass" then
            inv.open = false
            resolve(inv.messageId, "Passed")
            if gigOf[playerId] == gig.id and not crewIndex(gig, playerId) then gigOf[playerId] = nil end
            if inv.from then LightRP.notice(inv.from, { kind = "info", title = "CREW", body = name(playerId) .. " passed on the job." }) end
            return
        end
        local ok, why = join(gig, playerId, key)
        if not ok then answer(false, why) end
    elseif a.action == "share" then
        answer(share(gig, playerId, a.value))
    elseif a.action == "go" then
        if playerId ~= gig.owner then return answer(false, "Only " .. name(gig.owner) .. " says go.") end
        if gig.state ~= "accepted" then return answer(false, gig.state == "countdown" and "The countdown is running." or "That job is closed.") end
        local point = pointOf(gig)
        if not atMeet(playerId, point) then
            local flat = meetDistance(playerId, point)
            return answer(false, flat and string.format("Get to the meet point first: you're %d m away. Pin it from the brief.", math.floor(flat + 0.5))
                or "Get to the meet point first (pin it from the brief).")
        end
        local d = diffOf(gig)
        local here = present(gig)
        if #here < (d and d.min or 1) then
            return answer(false, string.format("%s needs %d operator(s) at the meet point (%d there).", d and d.label or "This job", d and d.min or 1, #here))
        end
        log("fixers: %s says go on gig %d with %d operator(s) at the meet", name(playerId), gig.id, #here)
        startCountdown(gig, here, true)
    elseif a.action == "bail" then
        if gig.state == "running" then return answer(false, "You're on the job: /mission leave to abandon it.") end
        leave(gig, playerId, "bailed")
    end
end
AddEventHandler("op77_neuralink:messageAction", function(playerId, a)
    local from = tonumber(source)
    if from and from > 0 then return end
    CreateThread(function()
        local ok, err = pcall(onAction, tonumber(playerId), a)
        if not ok then log("fixers: action failed: %s", tostring(err)) end
    end)
end)

-- A player texting a fixer gets a short answer (once in a while).
AddEventHandler("op77_neuralink:npcMessage", function(playerId, m)
    playerId = tonumber(playerId)
    if not playerId or type(m) ~= "table" or type(m.npc) ~= "string" then return end
    local id = m.npc:match("^fixer_(.+)$")
    local contact = id and contactById[id]
    if not contact or (lastChat[playerId] and now() - lastChat[playerId] < 20000) then return end
    lastChat[playerId] = now()
    local replies = contact.lines and contact.lines.chat or { "Busy. If it's about a job, use the job message.", "I call you, not the other way round." }
    CreateThread(function()
        Wait(math.random(1500, 4000))
        local from = numberOf(contact)
        if from then nl("sendMessage", { from = from, to = playerId, body = pick(replies) }) end
    end)
end)

-- ---------------------------------------------------------------------------
-- HUD state: the gig chip (where to go, crew, clock)

LightRP.stateProvider("fixerGig", function(id)
    local gig = gigOf[id] and gigs[gigOf[id]]
    if not gig or not crewIndex(gig, id) or gig.state == "running" then return false end
    local point, d = pointOf(gig), diffOf(gig)
    if not point then return false end
    return { id = gig.id, title = point.title, location = point.location, fixer = gig.contact.name, state = gig.state,
        crew = #gig.crew, min = d and d.min or 1, max = d and d.max or 1, owner = gig.owner == id,
        here = #present(gig), position = point.position,
        meetInMs = gig.meetUntil and math.max(0, gig.meetUntil - now()) or nil,
        launchInMs = gig.state == "countdown" and math.max(0, gig.launchAt - now()) or nil }
end)

-- ---------------------------------------------------------------------------
-- Clock: expiries, the meeting, the dispatcher

local numbersReady
local function eligibleForOffer(id, t)
    if not dispatchOn or not LightRP.characters.isRegistered(id) then return false end
    if gigOf[id] or (lastOffer[id] and t - lastOffer[id] < C.dispatch.playerCooldownMinutes * 60000) then return false end
    if not joinedAt[id] or t - joinedAt[id] < C.dispatch.settleSeconds * 1000 then return false end
    if LightRP.tutorial and type(LightRP.tutorial.isActive) == "function" and LightRP.tutorial.isActive(id) then return false end
    -- a crew member waits for the leader's jobs
    local P = LightRP.parties
    local party = P and type(P.of) == "function" and P.of(id) or nil
    if party and #party.members > 1 and party.leader ~= id then return false end
    return free(id) and hasPhone(id)
end

local function openCount() local n = 0; for _ in pairs(gigs) do n = n + 1 end; return n end
-- the fixers' lines (once each; a failure retries on the next pass)
numbersReady = function() for _, c in ipairs(C.contacts) do numberOf(c) end end

local function dispatch(t)
    if openCount() >= C.dispatch.maxOpen or #Missions.fixerPoints() == 0 then return end
    numbersReady()
    local players = GetPlayers()
    for i = #players, 2, -1 do local j = math.random(1, i); players[i], players[j] = players[j], players[i] end
    for _, raw in ipairs(players) do
        local id = tonumber(raw)
        if id and openCount() < C.dispatch.maxOpen and math.random() < C.dispatch.chance and eligibleForOffer(id, t) then
            local ok, why = Fixers.offer(id)
            if not ok then log("fixers: no offer for %s (%s)", name(id), tostring(why)) end
        end
    end
end

local function tick(t)
    local list = {}
    for _, gig in pairs(gigs) do list[#list + 1] = gig end
    table.sort(list, function(a, b) return a.id < b.id end)
    for _, gig in ipairs(list) do if gigs[gig.id] == gig then
        if gig.state == "offered" and t >= gig.expiresAt then
            gig.offerOpen = false
            resolve(gig.offerMessage, "Expired")
            text(gig, gig.owner, line(gig.contact, "expired", vars(gig, gig.owner)))
            close(gig, "expired", "expired")
        elseif gig.state == "accepted" or gig.state == "countdown" then
            for key, inv in pairs(gig.invites) do
                if inv.open and t - inv.at >= C.offerSeconds * 1000 then
                    inv.open = false
                    resolve(inv.messageId, "Expired")
                    if inv.player and gigOf[inv.player] == gig.id and not crewIndex(gig, inv.player) then gigOf[inv.player] = nil end
                end
            end
            local d = diffOf(gig)
            if not d then close(gig, "the mission was withdrawn", "cancelled")
            else
                local here = present(gig)
                if gig.state == "countdown" then
                    local enough = gig.forced and #here >= d.min or #here == #gig.crew
                    if not enough then
                        gig.state, gig.launchAt = "accepted", nil
                        crewNotice(gig, "LAUNCH ON HOLD", "Someone left the meet point. Everyone back in.", "warning")
                    elseif t >= gig.launchAt then
                        launch(gig, here)
                    end
                elseif #here == #gig.crew and #here >= d.min then
                    startCountdown(gig, here, false)
                elseif t >= gig.meetUntil then
                    if #here >= d.min then launch(gig, here)
                    else close(gig, "nobody showed up", "cancelled") end
                end
            end
            if gigs[gig.id] then
                local key = string.format("%s:%d:%d", gig.state, #gig.crew, #present(gig))
                if key ~= gig.hudKey then gig.hudKey = key; pushGig(gig) end
            end
        end
    end end
end

CreateThread(function()
    local nextDispatch = now() + (C.dispatch.firstDelaySeconds or 180) * 1000
    while true do
        Wait(1000)
        local t = now()
        local ok, err = pcall(tick, t)
        if not ok then log("fixers: tick failed: %s", tostring(err)) end
        if t >= nextDispatch then
            nextDispatch = t + C.dispatch.everySeconds * 1000
            ok, err = pcall(dispatch, t)
            if not ok then log("fixers: dispatch failed: %s", tostring(err)) end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Lifecycle

local function drop(id, why)
    local gig = gigOf[id] and gigs[gigOf[id]]
    if gig then
        if gig.state == "offered" and gig.owner == id then close(gig, why, "cancelled")
        elseif crewIndex(gig, id) and gig.state ~= "running" then leave(gig, id, why)
        elseif gigOf[id] == gig.id and not crewIndex(gig, id) then gigOf[id] = nil end
    end
end
function Fixers.onGameplayReady(id) joinedAt[id] = joinedAt[id] or now() end
function Fixers.onCharacterLoaded(id) CreateThread(function() drop(id, "character changed") end); joinedAt[id] = now() end
Fixers.onCharacterActivated = Fixers.onCharacterLoaded
function Fixers.onDisconnected(id)
    joinedAt[id], lastChat[id] = nil, nil
    CreateThread(function() drop(id, "disconnected"); gigOf[id] = nil end)
end
function Fixers.onDatabaseReady()
    -- the fixers' lines exist before the first offer (op77_neuralink must run)
    CreateThread(function() Wait(5000); numbersReady() end)
end
for _, raw in ipairs(GetPlayers()) do local id = tonumber(raw); if id then joinedAt[id] = now() end end

-- ---------------------------------------------------------------------------
-- Staff commands (ACL command.fixers.*, restricted)

local function target(args) return tonumber(args[1]) end
LightRP.command("fixers.offer", { restricted = true, usage = "/fixers.offer <playerId> [missionId] [difficulty]" }, function(source, args)
    local id = target(args)
    if not id or not GetPlayerName(id) then return false, "usage: /fixers.offer <playerId> [missionId] [difficulty]" end
    local caller = source
    CreateThread(function()
        local ok, gig = Fixers.offer(id, args[2], args[3])
        local msg = ok and string.format("Gig %d (%s, %s) offered to %s by %s.", gig.id, pointOf(gig).title, gig.difficulty, name(id), gig.contact.name)
            or ("No offer: " .. tostring(gig) .. ".")
        LightRP.reply(tonumber(caller) or 0, "fixers.offer", ok, msg)
    end)
    return true, "Asking a fixer..."
end)
LightRP.command("fixers.list", { restricted = true, usage = "/fixers.list" }, function()
    local out = {}
    for _, gig in pairs(gigs) do
        local point = pointOf(gig)
        out[#out + 1] = string.format("#%d %s (%s) %s · owner %s · crew %d", gig.id, point and point.title or gig.point, gig.difficulty, gig.state,
            gig.owner and name(gig.owner) or "-", #gig.crew)
    end
    local catalog = {}
    for _, p in ipairs(Missions.fixerPoints()) do catalog[#catalog + 1] = p.title end
    return true, (#out > 0 and table.concat(out, " | ") or "No open gig.") .. " · Catalogue: " .. (#catalog > 0 and table.concat(catalog, ", ") or "empty")
        .. " · Dispatch " .. (dispatchOn and "on" or "off")
end)
LightRP.command("fixers.cancel", { restricted = true, usage = "/fixers.cancel <gigId>" }, function(_, args)
    local gig = gigs[tonumber(args[1] or "") or -1]
    if not gig then return false, "No such gig." end
    if gig.state == "running" then return false, "That gig is running: /missions.fail <playerId> ends it." end
    CreateThread(function() close(gig, "cancelled by staff", "cancelled") end)
    return true, "Gig cancelled."
end)
LightRP.command("fixers.dispatch", { restricted = true, usage = "/fixers.dispatch on|off|now" }, function(_, args)
    if args[1] == "on" or args[1] == "off" then dispatchOn = args[1] == "on"; return true, "Fixer dispatch " .. args[1] .. "." end
    if args[1] == "now" then CreateThread(function() dispatch(now()) end); return true, "Dispatch pass started." end
    return false, "usage: /fixers.dispatch on|off|now"
end)

Fixers.gigs = gigs
Fixers.gigOf = gigOf
Fixers.tick = tick
Fixers.dispatch = dispatch
function Fixers.setBoot(id) bootId = id end
