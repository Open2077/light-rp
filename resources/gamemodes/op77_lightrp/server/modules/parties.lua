-- Crews: the one way players group up for multiplayer content (missions, the
-- Chimera raid, the activities, fixer gigs). A crew has a leader and up to
-- `party.maxSize` members; the leader invites (ALT + click on a player, the
-- panels or /crew invite; an invite lasts `inviteSeconds`), the invited player
-- accepts or declines (the HUD prompt keys, F1 > Crew, /crew accept), anyone
-- leaves, the leader kicks and hands the lead over. When the leader leaves, the
-- next member leads; a crew of one dissolves. Crews live in memory: they end
-- with a disconnect or a character change, like a voice call. Solo play stays:
-- a player alone is a crew of one everywhere it matters.
--
--   LightRP.parties.of(playerId)            -> crew or nil   (LightRP.crews is the same module)
--   LightRP.parties.members(playerId)       -> { ids } (the player alone when not in a crew)
--   LightRP.parties.matchmaking(playerId)   -> missions open to strangers? (the crew's, or the solo player's)
--   hooks onPartyChanged(crewId, ids) after any change, onCrewLeft(playerId, crewId),
--         onCrewJoined(playerId, crewId), onCrewMatchmaking(playerId, on)
local C = LightRpMissions.party
local Party = LightRP.module("parties", {})
LightRP.crews = Party

local parties = {}  -- id -> { id, leader, members = { ids }, invites = { [playerId] = expiresMs }, matchmaking, sig }
local memberOf = {} -- playerId -> crew id
local soloOpen = {} -- playerId -> true: a player alone opened their missions to matchmaking
local sequence = 0

local FAR = C.farRange or 250.0

local function name(id) return LightRP.characters.displayName(id) end
local function active(id) return LightRP.characters.isRegistered(id) end
local function now() return LightRP.nowMs() end
local function bucketOf(id) return type(GetPlayerRoutingBucket) == "function" and (tonumber(GetPlayerRoutingBucket(id)) or 0) or 0 end
-- A player's last known position (`position` is nil after two idle seconds).
local function positionOf(id)
    local p = Open77.players.position(id)
    if p then return p end
    if type(Open77.players.get) ~= "function" then return nil end
    local ok, read = pcall(Open77.players.get, id)
    if ok and type(read) == "table" and type(read.position) == "table" then return read.position end
end

function Party.of(playerId) local id = memberOf[playerId]; return id and parties[id] end
function Party.get(id) return parties[id] end
function Party.members(playerId)
    local p = Party.of(playerId)
    if not p then return { playerId } end
    local list = {}
    for i, id in ipairs(p.members) do list[i] = id end
    return list
end
function Party.isLeader(playerId) local p = Party.of(playerId); return p ~= nil and p.leader == playerId end
-- Missions: may strangers fill the empty places of this player's entry (and may
-- they be matched into other open lobbies)? Off by default, for a crew and alone.
function Party.matchmaking(playerId)
    local p = Party.of(playerId)
    if p then return p.matchmaking == true end
    return soloOpen[playerId] == true
end

-- Pending invites of a player: { party, from, fromName, expiresInMs }, newest first.
local function invitesFor(playerId)
    local list, t = {}, now()
    for _, p in pairs(parties) do
        local expires = p.invites[playerId]
        if expires and expires > t then list[#list + 1] = { party = p.id, from = p.leader, fromName = name(p.leader), expiresInMs = expires - t } end
    end
    table.sort(list, function(a, b) return a.expiresInMs > b.expiresInMs end)
    return list
end

local function push(ids)
    local seen = {}
    for _, id in ipairs(ids) do
        if id and not seen[id] then seen[id] = true; LightRP.state(id, "party") end
    end
end
local function changed(p, extra)
    local ids = {}
    if p then for _, id in ipairs(p.members) do ids[#ids + 1] = id end end
    for _, id in ipairs(extra or {}) do ids[#ids + 1] = id end
    push(ids)
    LightRP.eachModule("onPartyChanged", p and p.id, ids)
end

-- ---------------------------------------------------------------------------
-- What the HUD shows of each member: life, what keeps them busy, far away.

local function lifeOf(id)
    local M = LightRP.medical
    if M and type(M.isDowned) == "function" and M.isDowned(id) then return "down" end
    local life = Open77.players.getLifeState(id)
    local phase = life and life.phase or "alive"
    if phase == "alive" or phase == "recovering" then return "alive" end
    if phase == "revivepending" or phase == "dying" or phase == "down" then return "down" end
    return "dead"
end

local function busyOf(id)
    local M = LightRP.missions
    if M and type(M.instanceOf) == "function" then
        local inst = M.instanceOf(id)
        if inst then
            local point = type(M.point) == "function" and M.point(inst.point)
            return "mission", point and point.title or "Mission"
        end
        if type(M.taggedOn) == "function" then
            local title = M.taggedOn(id)
            if title then return "lobby", title end
        end
    end
    local A = LightRP.activities
    if A and type(A.owner) == "function" then
        local owner = A.owner(id)
        if owner and owner ~= "missions" then
            local a = A.registry and A.registry[owner]
            return "activity", a and a.label or tostring(owner)
        end
    end
    return nil
end

local function farFrom(viewer, id)
    if viewer == id then return false end
    if bucketOf(viewer) ~= bucketOf(id) then return true end
    local a, b = positionOf(viewer), positionOf(id)
    if not a or not b then return false end
    return (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2 > FAR * FAR
end

local function memberView(p, viewer, id)
    local busy, label = busyOf(id)
    return { id = id, name = name(id), leader = id == p.leader, you = id == viewer,
        tier = LightRP.missions and type(LightRP.missions.tier) == "function" and LightRP.missions.tier(id) or 1,
        state = lifeOf(id), busy = busy, busyLabel = label, far = farFrom(viewer, id) }
end

LightRP.stateProvider("party", function(playerId)
    local p = Party.of(playerId)
    local state = { you = playerId, invites = invitesFor(playerId), maxSize = C.maxSize, inviteSeconds = C.inviteSeconds,
        matchmaking = Party.matchmaking(playerId) }
    if p then
        local members = {}
        for _, id in ipairs(p.members) do members[#members + 1] = memberView(p, playerId, id) end
        local pending, t = {}, now()
        for id, expires in pairs(p.invites) do
            if expires > t then pending[#pending + 1] = { id = id, name = name(id), expiresInMs = expires - t } end
        end
        table.sort(pending, function(a, b) return a.id < b.id end)
        state.id, state.leader, state.members, state.pending = p.id, p.leader, members, pending
    end
    return state
end)

-- The frame follows life states, activities, missions and distance: a crew is
-- pushed again when what its members see of each other changed.
local function signature(p)
    local parts = {}
    for _, id in ipairs(p.members) do
        local busy, label = busyOf(id)
        parts[#parts + 1] = tostring(id) .. ":" .. lifeOf(id) .. ":" .. tostring(busy) .. ":" .. tostring(label)
    end
    for _, viewer in ipairs(p.members) do
        local row = {}
        for _, id in ipairs(p.members) do row[#row + 1] = farFrom(viewer, id) and "1" or "0" end
        parts[#parts + 1] = table.concat(row)
    end
    return table.concat(parts, "|")
end
function Party.refresh(p)
    if not p or parties[p.id] ~= p then return end
    local sig = signature(p)
    if sig ~= p.sig then
        p.sig = sig
        push(p.members)
    end
end

-- ---------------------------------------------------------------------------
-- Membership

local function dissolve(p)
    parties[p.id] = nil
    for _, id in ipairs(p.members) do memberOf[id] = nil end
end

local function remove(p, playerId)
    for i, id in ipairs(p.members) do if id == playerId then table.remove(p.members, i) break end end
    memberOf[playerId] = nil
    LightRP.eachModule("onCrewLeft", playerId, p.id)
    if #p.members <= 1 then
        local last = p.members[1]
        -- an invite still out keeps the crew of one (the leader waits for the answer)
        if last and next(p.invites) ~= nil then
            p.leader = last
            changed(p, { playerId })
            return
        end
        dissolve(p)
        if last then LightRP.notice(last, { kind = "info", title = "CREW", body = "Your crew has dissolved." }) end
        changed(nil, { playerId, last })
        return
    end
    if p.leader == playerId then
        p.leader = p.members[1]
        LightRP.notice(p.leader, { kind = "info", title = "CREW", body = "You lead the crew now." })
        for _, id in ipairs(p.members) do
            if id ~= p.leader then LightRP.notice(id, { kind = "info", title = "CREW", body = name(p.leader) .. " leads the crew now." }) end
        end
    end
    changed(p, { playerId })
end

function Party.invite(from, target)
    if not target or from == target then return false, from == target and "You cannot invite yourself." or "Choose a player to invite." end
    if not active(from) then return false, "Finish your character first." end
    if not active(target) then return false, "That player is not in the city." end
    local p = Party.of(from)
    if p and p.leader ~= from then return false, "Only the crew leader invites." end
    if memberOf[target] then
        if p and memberOf[target] == p.id then return false, name(target) .. " is already in your crew." end
        return false, name(target) .. " is already in a crew."
    end
    if p and p.invites[target] and p.invites[target] > now() then return false, name(target) .. " already has your invite." end
    if p and #p.members >= C.maxSize then return false, "Your crew is full." end
    if bucketOf(from) ~= bucketOf(target) then return false, name(target) .. " is not around you." end
    local a, b = positionOf(from), positionOf(target)
    if a and b and ((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) > C.inviteRange ^ 2 then
        return false, name(target) .. " is too far away."
    end
    if not p then
        sequence = sequence + 1
        p = { id = "crew:" .. sequence, leader = from, members = { from }, invites = {}, matchmaking = false }
        parties[p.id], memberOf[from] = p, p.id
    end
    p.invites[target] = now() + C.inviteSeconds * 1000
    LightRP.notice(target, { kind = "contract", title = "CREW INVITE", durationMs = 6000,
        body = name(from) .. " invites you to their crew." })
    changed(p, { target })
    return true, "Crew invite sent to " .. name(target) .. "."
end

function Party.accept(playerId, partyId)
    local p = partyId and parties[partyId]
    if not p then
        -- the only (or newest) pending invite
        local best
        for _, q in pairs(parties) do
            local expires = q.invites[playerId]
            if expires and expires > now() and (not best or expires > best.invites[playerId]) then best = q end
        end
        p = best
    end
    if not p or not p.invites[playerId] or p.invites[playerId] < now() then return false, "No crew invite waiting for you." end
    -- a crew of one (only invites out) gives way: its invites are dropped
    local own = Party.of(playerId)
    if own and own ~= p and #own.members == 1 then
        local touched = {}
        for id in pairs(own.invites) do touched[#touched + 1] = id end
        dissolve(own)
        changed(nil, touched)
    elseif own and own ~= p then
        return false, "Leave your crew first."
    end
    if #p.members >= C.maxSize then p.invites[playerId] = nil; changed(p, { playerId }); return false, "That crew is full." end
    p.invites[playerId] = nil
    p.members[#p.members + 1] = playerId
    memberOf[playerId] = p.id
    for _, id in ipairs(p.members) do
        if id ~= playerId then LightRP.notice(id, { kind = "info", title = "CREW", body = name(playerId) .. " joined the crew." }) end
    end
    LightRP.eachModule("onCrewJoined", playerId, p.id)
    changed(p)
    return true, "You joined " .. name(p.leader) .. "'s crew."
end

function Party.decline(playerId, partyId)
    local p = partyId and parties[partyId]
    if not p then
        for _, q in pairs(parties) do if q.invites[playerId] then p = q end end
    end
    if not p or not p.invites[playerId] then return false, "No crew invite to decline." end
    p.invites[playerId] = nil
    LightRP.notice(p.leader, { kind = "info", title = "CREW", body = name(playerId) .. " declined your crew invite." })
    if #p.members <= 1 and next(p.invites) == nil then dissolve(p) end
    changed(parties[p.id], { playerId, p.leader })
    return true, "Crew invite declined."
end

function Party.leave(playerId)
    local p = Party.of(playerId)
    if not p then return false, "You are not in a crew." end
    if #p.members == 1 then
        -- a crew of one waiting for answers: the invites are withdrawn
        local touched = { playerId }
        for id in pairs(p.invites) do touched[#touched + 1] = id end
        dissolve(p)
        LightRP.eachModule("onCrewLeft", playerId, p.id)
        changed(nil, touched)
        return true, "Crew invites withdrawn."
    end
    for _, id in ipairs(p.members) do
        if id ~= playerId then LightRP.notice(id, { kind = "info", title = "CREW", body = name(playerId) .. " left the crew." }) end
    end
    remove(p, playerId)
    return true, "You left the crew."
end

function Party.kick(leader, target)
    local p = Party.of(leader)
    if not p or p.leader ~= leader then return false, "Only the crew leader removes members." end
    if not target or target == leader or memberOf[target] ~= p.id then return false, "That player is not in your crew." end
    LightRP.notice(target, { kind = "warning", title = "CREW", body = name(leader) .. " removed you from the crew." })
    for _, id in ipairs(p.members) do
        if id ~= leader and id ~= target then LightRP.notice(id, { kind = "info", title = "CREW", body = name(target) .. " was removed from the crew." }) end
    end
    remove(p, target)
    return true, name(target) .. " was removed from the crew."
end

function Party.promote(leader, target)
    local p = Party.of(leader)
    if not p or p.leader ~= leader then return false, "Only the crew leader hands the lead over." end
    if not target or target == leader or memberOf[target] ~= p.id then return false, "That player is not in your crew." end
    p.leader = target
    LightRP.notice(target, { kind = "info", title = "CREW", body = "You lead the crew now." })
    for _, id in ipairs(p.members) do
        if id ~= target and id ~= leader then LightRP.notice(id, { kind = "info", title = "CREW", body = name(target) .. " leads the crew now." }) end
    end
    changed(p)
    return true, name(target) .. " leads the crew now."
end

-- Missions: open the empty places of the crew (or of a player alone) to
-- strangers, the old public matchmaking. The crew leader decides.
function Party.setMatchmaking(playerId, on)
    if not active(playerId) then return false, "Finish your character first." end
    local p = Party.of(playerId)
    if p and p.leader ~= playerId then return false, "Only the crew leader opens the crew to matchmaking." end
    on = on == true
    if p then p.matchmaking = on else soloOpen[playerId] = on or nil end
    changed(p, p and nil or { playerId })
    LightRP.eachModule("onCrewMatchmaking", playerId, on)
    if p then
        return true, on and "Open to matchmaking: solo players can fill your crew's empty places on mission boards."
            or "Matchmaking off: only your crew enters your missions."
    end
    return true, on and "Open to matchmaking: mission boards match you with other players."
        or "Matchmaking off: you enter missions alone, or with a crew."
end

-- A crew ends for whoever leaves the city or changes character.
function Party.onDisconnected(playerId)
    local p = Party.of(playerId)
    if p then
        if #p.members == 1 then
            local touched = { playerId }
            for id in pairs(p.invites) do touched[#touched + 1] = id end
            dissolve(p)
            changed(nil, touched)
        else
            remove(p, playerId)
        end
    end
    soloOpen[playerId] = nil
    for _, q in pairs(parties) do
        if q.invites[playerId] then
            q.invites[playerId] = nil
            if #q.members <= 1 and next(q.invites) == nil then dissolve(q); changed(nil, { q.leader }) else changed(q) end
        end
    end
end
Party.onCharacterLoaded = Party.onDisconnected

-- A fall shows on the crew frame at once.
function Party.onLifeState(playerId)
    local p = Party.of(playerId)
    if p then Party.refresh(p) end
end

-- Expired invites drop out once a second; the frames refresh every two.
function Party.tick(t)
    for _, p in pairs(parties) do
        local touched = {}
        for id, expires in pairs(p.invites) do
            if expires <= t then p.invites[id] = nil; touched[#touched + 1] = id end
        end
        if #touched > 0 then
            if #p.members <= 1 and next(p.invites) == nil then
                dissolve(p)
                LightRP.notice(p.leader, { kind = "info", title = "CREW", body = "Nobody answered your crew invite." })
                touched[#touched + 1] = p.leader
                changed(nil, touched)
            else changed(p, touched) end
        end
    end
end
CreateThread(function()
    local beat = 0
    while true do
        Wait(1000)
        beat = beat + 1
        local ok, err = pcall(Party.tick, now())
        if not ok then LightRP.log("crews: tick failed: %s", tostring(err)) end
        if beat % math.max(1, math.floor((C.refreshMs or 2000) / 1000)) == 0 then
            for _, p in pairs(parties) do
                local done, why = pcall(Party.refresh, p)
                if not done then LightRP.log("crews: refresh failed: %s", tostring(why)) end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Page actions (panels, F1, the HUD prompt, ALT + click) and commands. Every
-- target comes from the client: it is checked here, whatever the page showed.

local function answer(playerId, action, ok, text) LightRP.result(playerId, ok, text, action) end
local function target(payload)
    local value = type(payload) == "table" and tonumber(payload.target) or nil
    if value and value >= 1 and value % 1 == 0 and value < 2 ^ 31 then return math.floor(value) end
    return nil
end
local function crewId(payload)
    local value = type(payload) == "table" and payload.party or nil
    return type(value) == "string" and #value <= 32 and value or nil
end
LightRP.action("party.invite", function(id, payload) answer(id, "party.invite", Party.invite(id, target(payload))) end)
LightRP.action("party.accept", function(id, payload) answer(id, "party.accept", Party.accept(id, crewId(payload))) end)
LightRP.action("party.decline", function(id, payload) answer(id, "party.decline", Party.decline(id, crewId(payload))) end)
LightRP.action("party.leave", function(id) answer(id, "party.leave", Party.leave(id)) end)
LightRP.action("party.kick", function(id, payload) answer(id, "party.kick", Party.kick(id, target(payload))) end)
LightRP.action("party.promote", function(id, payload) answer(id, "party.promote", Party.promote(id, target(payload))) end)
LightRP.action("party.matchmaking", function(id, payload)
    answer(id, "party.matchmaking", Party.setMatchmaking(id, type(payload) == "table" and payload.on == true))
end)

local USAGE = "/crew invite <id> · accept · decline · leave · kick <id> · lead <id> · matchmaking on|off"
local function crewCommand(source, args)
    if not source or source <= 0 then return false, "Players only." end
    local verb, arg = args[1], tonumber(args[2])
    if verb == "invite" then return Party.invite(source, arg)
    elseif verb == "accept" then return Party.accept(source)
    elseif verb == "decline" then return Party.decline(source)
    elseif verb == "leave" then return Party.leave(source)
    elseif verb == "kick" then return Party.kick(source, arg)
    elseif verb == "lead" or verb == "promote" then return Party.promote(source, arg)
    elseif verb == "matchmaking" or verb == "mm" then
        if args[2] ~= "on" and args[2] ~= "off" then return true, "Matchmaking is " .. (Party.matchmaking(source) and "on" or "off") .. ". /crew matchmaking on|off" end
        return Party.setMatchmaking(source, args[2] == "on")
    elseif verb ~= nil then return false, "usage: " .. USAGE
    end
    local p = Party.of(source)
    if not p then
        local invites = invitesFor(source)
        if #invites > 0 then return true, invites[1].fromName .. " invites you to their crew: /crew accept or /crew decline." end
        return true, "No crew. ALT + click a player > Invite to crew, or /crew invite <id>."
    end
    local names = {}
    for _, id in ipairs(p.members) do names[#names + 1] = name(id) .. (id == p.leader and " (leader)" or "") end
    return true, "Crew: " .. table.concat(names, ", ") .. (p.matchmaking and " · open to matchmaking" or "")
end
LightRP.command("crew", { usage = USAGE }, crewCommand)
LightRP.command("party", { usage = USAGE }, crewCommand) -- the old name
