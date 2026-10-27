-- Squads: players who play missions together. A squad has a leader and up to
-- `party.maxSize` members; the leader invites (an invite lasts a minute), the
-- invited player accepts or declines, anyone leaves, the leader kicks and hands
-- the lead over. A squad of one dissolves. Squads live in memory: they end with
-- a disconnect or a character change, like a voice call.
--
--   LightRP.parties.of(playerId)        -> squad or nil
--   LightRP.parties.members(playerId)   -> { ids } (the player alone when not in a squad)
--   hook onPartyChanged(partyId, memberIds) after any change
local C = LightRpMissions.party
local Party = LightRP.module("parties", {})

local parties = {}  -- id -> { id, leader, members = { ids }, invites = { [playerId] = expiresMs } }
local memberOf = {} -- playerId -> party id
local sequence = 0

local function name(id) return LightRP.characters.displayName(id) end
local function active(id) return LightRP.characters.isRegistered(id) end
local function now() return LightRP.nowMs() end

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

-- Who has a pending invite from which squads: playerId -> { partyId = true }.
local function invitesFor(playerId)
    local list, t = {}, now()
    for _, p in pairs(parties) do
        local expires = p.invites[playerId]
        if expires and expires > t then list[#list + 1] = { party = p.id, from = p.leader, fromName = name(p.leader), expiresInMs = expires - t } end
    end
    return list
end

local function push(ids)
    for _, id in ipairs(ids) do LightRP.state(id, "party") end
end
local function changed(p, extra)
    local ids = {}
    if p then for _, id in ipairs(p.members) do ids[#ids + 1] = id end end
    for _, id in ipairs(extra or {}) do ids[#ids + 1] = id end
    push(ids)
    LightRP.eachModule("onPartyChanged", p and p.id, ids)
end

LightRP.stateProvider("party", function(playerId)
    local p = Party.of(playerId)
    local state = { invites = invitesFor(playerId), maxSize = C.maxSize }
    if p then
        local members = {}
        for _, id in ipairs(p.members) do
            members[#members + 1] = { id = id, name = name(id), leader = id == p.leader, tier = LightRP.missions and LightRP.missions.tier(id) or 1 }
        end
        local pending = {}
        for id, expires in pairs(p.invites) do
            if expires > now() then pending[#pending + 1] = { id = id, name = name(id) } end
        end
        state.id, state.leader, state.members, state.pending = p.id, p.leader, members, pending
    end
    return state
end)

local function dissolve(p)
    parties[p.id] = nil
    for _, id in ipairs(p.members) do memberOf[id] = nil end
end

local function remove(p, playerId)
    for i, id in ipairs(p.members) do if id == playerId then table.remove(p.members, i) break end end
    memberOf[playerId] = nil
    if #p.members <= 1 then
        local last = p.members[1]
        dissolve(p)
        if last then LightRP.notice(last, { kind = "info", title = "SQUAD", body = "Your squad has dissolved." }) end
        changed(nil, { playerId, last })
        return
    end
    if p.leader == playerId then
        p.leader = p.members[1]
        LightRP.notice(p.leader, { kind = "info", title = "SQUAD", body = "You lead the squad now." })
    end
    changed(p, { playerId })
end

function Party.invite(from, target)
    if from == target then return false, "You cannot invite yourself." end
    if not active(from) then return false, "Finish your character first." end
    if not target or not active(target) then return false, "That player is not in the city." end
    if memberOf[target] then return false, name(target) .. " is already in a squad." end
    local p = Party.of(from)
    if p and p.leader ~= from then return false, "Only the squad leader invites." end
    if p and #p.members >= C.maxSize then return false, "Your squad is full." end
    local a, b = Open77.players.position(from), Open77.players.position(target)
    if a and b and ((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) > C.inviteRange ^ 2 then
        return false, name(target) .. " is too far away."
    end
    if not p then
        sequence = sequence + 1
        p = { id = "squad:" .. sequence, leader = from, members = { from }, invites = {} }
        parties[p.id], memberOf[from] = p, p.id
    end
    p.invites[target] = now() + C.inviteSeconds * 1000
    LightRP.notice(target, { kind = "contract", title = "SQUAD INVITE", durationMs = C.inviteSeconds * 1000,
        body = name(from) .. " invites you to their squad. Accept at a mission point, or type /party accept." })
    changed(p, { target })
    return true, "Invite sent to " .. name(target) .. "."
end

function Party.accept(playerId, partyId)
    -- a squad of one (only invites out) gives way: its invites are dropped
    local own = Party.of(playerId)
    if own and #own.members == 1 then
        local touched = {}
        for id in pairs(own.invites) do touched[#touched + 1] = id end
        dissolve(own)
        changed(nil, touched)
    elseif own then
        return false, "Leave your squad first."
    end
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
    if not p or not p.invites[playerId] or p.invites[playerId] < now() then return false, "No invite waiting for you." end
    if #p.members >= C.maxSize then p.invites[playerId] = nil; return false, "That squad is full." end
    p.invites[playerId] = nil
    p.members[#p.members + 1] = playerId
    memberOf[playerId] = p.id
    for _, id in ipairs(p.members) do
        if id ~= playerId then LightRP.notice(id, { kind = "info", title = "SQUAD", body = name(playerId) .. " joined the squad." }) end
    end
    changed(p)
    return true, "You joined " .. name(p.leader) .. "'s squad."
end

function Party.decline(playerId, partyId)
    local p = partyId and parties[partyId]
    if not p or not p.invites[playerId] then return false, "No invite to decline." end
    p.invites[playerId] = nil
    LightRP.notice(p.leader, { kind = "info", title = "SQUAD", body = name(playerId) .. " declined your invite." })
    if #p.members <= 1 and next(p.invites) == nil then dissolve(p) end
    changed(parties[p.id], { playerId, p.leader })
    return true, "Invite declined."
end

function Party.leave(playerId)
    local p = Party.of(playerId)
    if not p then return false, "You are not in a squad." end
    for _, id in ipairs(p.members) do
        if id ~= playerId then LightRP.notice(id, { kind = "info", title = "SQUAD", body = name(playerId) .. " left the squad." }) end
    end
    remove(p, playerId)
    return true, "You left the squad."
end

function Party.kick(leader, target)
    local p = Party.of(leader)
    if not p or p.leader ~= leader then return false, "Only the squad leader removes members." end
    if target == leader or memberOf[target] ~= p.id then return false, "That player is not in your squad." end
    LightRP.notice(target, { kind = "warning", title = "SQUAD", body = "You were removed from the squad." })
    remove(p, target)
    return true, name(target) .. " was removed from the squad."
end

function Party.promote(leader, target)
    local p = Party.of(leader)
    if not p or p.leader ~= leader then return false, "Only the squad leader hands the lead over." end
    if target == leader or memberOf[target] ~= p.id then return false, "That player is not in your squad." end
    p.leader = target
    LightRP.notice(target, { kind = "info", title = "SQUAD", body = "You lead the squad now." })
    changed(p)
    return true, name(target) .. " leads the squad now."
end

-- A squad ends for whoever leaves the city or changes character.
function Party.onDisconnected(playerId)
    local p = Party.of(playerId)
    if p then remove(p, playerId) end
    for _, q in pairs(parties) do q.invites[playerId] = nil end
end
Party.onCharacterLoaded = Party.onDisconnected

-- Expired invites drop out of the lists once a while.
CreateThread(function()
    while true do
        Wait(5000)
        local t = now()
        for _, p in pairs(parties) do
            local touched = {}
            for id, expires in pairs(p.invites) do
                if expires <= t then p.invites[id] = nil; touched[#touched + 1] = id end
            end
            if #touched > 0 then
                if #p.members <= 1 and next(p.invites) == nil then dissolve(p); changed(nil, { p.leader, table.unpack(touched) })
                else changed(p, touched) end
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Page actions and commands

local function answer(playerId, action, ok, text) LightRP.result(playerId, ok, text, action) end
local function target(payload) return type(payload) == "table" and tonumber(payload.target) end
LightRP.action("party.invite", function(id, payload) answer(id, "party.invite", Party.invite(id, target(payload))) end)
LightRP.action("party.accept", function(id, payload) answer(id, "party.accept", Party.accept(id, type(payload) == "table" and payload.party or nil)) end)
LightRP.action("party.decline", function(id, payload) answer(id, "party.decline", Party.decline(id, type(payload) == "table" and payload.party or nil)) end)
LightRP.action("party.leave", function(id) answer(id, "party.leave", Party.leave(id)) end)
LightRP.action("party.kick", function(id, payload) answer(id, "party.kick", Party.kick(id, target(payload))) end)
LightRP.action("party.promote", function(id, payload) answer(id, "party.promote", Party.promote(id, target(payload))) end)

LightRP.command("party", { usage = "/party invite <id> · accept · decline · leave · kick <id> · lead <id>" }, function(source, args)
    local verb, arg = args[1], tonumber(args[2])
    if verb == "invite" then return Party.invite(source, arg)
    elseif verb == "accept" then return Party.accept(source)
    elseif verb == "decline" then
        local p
        for _, q in pairs(parties) do if q.invites[source] then p = q end end
        return Party.decline(source, p and p.id)
    elseif verb == "leave" then return Party.leave(source)
    elseif verb == "kick" then return Party.kick(source, arg)
    elseif verb == "lead" or verb == "promote" then return Party.promote(source, arg)
    end
    local p = Party.of(source)
    if not p then return true, "No squad. /party invite <id> starts one." end
    local names = {}
    for _, id in ipairs(p.members) do names[#names + 1] = name(id) .. (id == p.leader and " (lead)" or "") end
    return true, "Squad: " .. table.concat(names, ", ")
end)
