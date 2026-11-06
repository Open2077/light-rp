-- Rooms: a player hosts a game at the rooms NPC of The Crossing (activities_hub.lua, a
-- `kind = "rooms"` terminal): picks the game, the map, the sides' size, a public room or a
-- private one with a code; others join; the host starts. A room is a friendly with no
-- crew requirement: the same set-up shape (teams / players / bench), the same launch
-- (A.launchFriendly -> startMatch with friendly = true), so the match, the recap and the
-- way back are the core's and nothing is ever recorded. Memory only, one room per player.
--
-- Hosted: the activities with lobby `rooms = true` (server/config/activities.lua) that are
-- registered right now; a provider that stops closes its rooms (A.roomsForget).
-- A room's shape comes from the lobby entry: `teams = n` sides of at most `size` players
-- each (the host picks), else everyone in `players`, `size` at most. The start re-checks
-- every member (A.check inside A.launchFriendly) and asks for at least two players.
--
-- Crews (server/modules/parties.lua): anyone in a crew creating or joining a room brings the
-- whole crew, the owner's rule, wider than the panel's where only the leader can. Each member
-- is checked like a join of their own: one who cannot come stays out and is told why, the
-- others come. Whoever comes has to fit, on one team of a team game: else nobody moves and the
-- one who asked hears why. Whoever brought the crew leaving takes along who came with them.
-- A room is no crew's: whoever later leaves the crew, or the crew ending, changes nothing.
--
-- Everything in `activities.rooms` is hostile input: an id, a code, a map and a size are
-- looked up, never trusted, and only the host may kick, move, change settings or start.
-- The crew is read here, never sent.
--
-- The page: state key `rooms`, pushed on change only, to the open menus for a public room
-- and to the members for any. `games` names what can be hosted; labels, maps and player
-- limits stay in the `activities` list (the same activities, a dozen values each here).
--   { enabled, eligible, reason, full, games = { { id, teams, least, most } },
--     list = public rooms { id, activity, label, mode, modeLabel, host, count, max, teams },
--     room = false | { id, activity, label, mode, modeLabel, private, code, host, mine, size,
--                      least, most, count, max, issue, teams = { { player } }, players = { player } } }
local C = LightRpActivities
local A = LightRP.activities
local R = LightRP.module("activityRooms", {})

local CFG = type(C.rooms) == "table" and C.rooms or {}
local ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" -- no 0/O, no 1/I
local ACTION = "activities.rooms"
-- Its own type: the server drops a second action of one type within 250 ms
-- (framework.lua), and a menu closing right after a click would stay watched.
local CLOSE_ACTION = "activities.rooms.close"

local rooms = {}    -- roomId -> room
local of = {}       -- playerId -> room
local watchers = {} -- playerId -> true: the menu is open
local standings = {} -- playerId -> what the open menu last heard of what they may do
local seq = 0
R.rooms, R.of, R.watchers = rooms, of, watchers

local function now() return LightRP.nowMs() end
local function name(id) return LightRP.characters.displayName(id) end
local function enabled() return C.enabled ~= false and CFG.enabled ~= false end
local function maxRooms() return math.max(0, math.floor(tonumber(CFG.maxRooms) or 24)) end
local function idleMs() return math.max(1000, math.floor(tonumber(CFG.idleMs) or 600000)) end
local function codeLength() return math.max(4, math.min(8, math.floor(tonumber(CFG.codeLength) or 5))) end
local function joinNoticeMs() return math.max(0, math.floor(tonumber(CFG.joinNoticeMs) or 60000)) end
local function whole(value)
    if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or math.abs(value) > 1e6 then return nil end
    return math.floor(value)
end
local function notify(id, kind, body)
    LightRP.notice(id, { kind = kind, title = "GAME ROOM", durationMs = 6000, body = body })
end
local function contains(list, p) for _, v in ipairs(list) do if v == p then return true end end return false end
local function remove(list, p)
    for i, v in ipairs(list) do if v == p then table.remove(list, i); return true end end
    return false
end

-- ---------------------------------------------------------------------------
-- Pushes: on change, coalesced. A public room changes the list for every open menu; a
-- private one is nobody's business but its members'.

local queued, toAll, toSome = false, false, {}
function R.flush()
    queued = false
    local set = toSome
    if toAll then for id in pairs(watchers) do set[id] = true end end
    toAll, toSome = false, {}
    for id in pairs(set) do LightRP.state(id, "rooms") end
end
local function schedule()
    if queued then return end
    queued = true
    SetTimeout(math.max(0, tonumber(CFG.pushMs) or 150), R.flush)
end
local function changed(room)
    for _, p in ipairs(room.members) do toSome[p] = true end
    if not room.private then toAll = true end
    schedule()
end
local function told(id) toSome[id] = true; schedule() end
local function menus() toAll = true; schedule() end

-- ---------------------------------------------------------------------------
-- What can be hosted

-- a, teams (nil: everyone in one list) | nil. A fixed teamSize is the core queue's shape,
-- not a room's.
local function hostable(activityId)
    local a = type(activityId) == "string" and A.registry[activityId] or nil
    if not a or a.offered == false or not A.offersFriendly(a) then return nil end
    local l = A.lobbyOf(activityId)
    if l.rooms ~= true then return nil end
    local shape, n = A.shapeOf(l)
    if shape == "teams" then return nil end
    return a, shape == "split" and n or nil
end
-- The range of `size`: per side with teams, the whole room without.
local function limits(a, teams)
    if teams then
        local most = math.max(1, a.maxPlayers // teams)
        return math.min(most, math.max(1, math.ceil(a.minPlayers / teams))), most
    end
    return math.min(a.maxPlayers, math.max(2, a.minPlayers)), a.maxPlayers
end
-- nil, "" or false: any map (the provider picks). ok, mode | false
local function pickMode(a, value)
    if value == nil or value == false or value == "" then return true, nil end
    if type(value) ~= "string" then return false end
    for _, m in ipairs(a.modes or {}) do if m.id == value then return true, value end end
    return false
end
local function pickSize(a, teams, value)
    local least, most = limits(a, teams)
    if value == nil then return most end
    local size = whole(value)
    if not size or size < least or size > most then return nil end
    return size
end
local function capacity(room) return room.teams and room.size * #room.teams or room.size end
local function newCode()
    local length = codeLength()
    for _ = 1, 64 do
        local chars = {}
        for i = 1, length do
            local at = math.random(#ALPHABET)
            chars[i] = ALPHABET:sub(at, at)
        end
        local code, taken = table.concat(chars), false
        for _, room in pairs(rooms) do if room.code == code then taken = true end end
        if not taken then return code end
    end
    return nil
end
local function count()
    local n = 0
    for _ in pairs(rooms) do n = n + 1 end
    return n
end

-- ---------------------------------------------------------------------------
-- Membership

local function close(room, kind, body)
    rooms[room.id] = nil
    for _, p in ipairs(room.members) do
        of[p] = nil
        toSome[p] = true
        if body then notify(p, kind, body) end
    end
    if not room.private then toAll = true end
    schedule()
    LightRP.log("rooms: room %d (%s) closed", room.id, room.activity)
end

-- Out of the room: the next member takes over, the last one closes it.
local function drop(room, id)
    of[id] = nil
    room.followed[id] = nil
    remove(room.members, id)
    if room.teams then
        for _, team in ipairs(room.teams) do remove(team, id) end
    else
        remove(room.players, id)
    end
    told(id)
    if #room.members == 0 then
        close(room)
        return
    end
    if room.host == id then
        room.host = room.members[1]
        notify(room.host, "info", "You now host this room.")
        room.at = now() -- a new host gets the time to act; a plain leave keeps nothing alive
    end
    changed(room)
end

-- The team these players land on, together: of those with places for all of them, the one
-- holding most of them, then the emptiest. nil: none.
local function teamFor(room, ids)
    local best, bestHeld
    for _, team in ipairs(room.teams) do
        local held = 0
        for _, p in ipairs(ids) do if contains(team, p) then held = held + 1 end end
        if #team - held + #ids <= room.size and (not best or held > bestHeld or (held == bestHeld and #team < #best)) then
            best, bestHeld = team, held
        end
    end
    return best
end

-- In the room, on `team` of a team game (a player already in moves there).
local function place(room, ids, team)
    for _, id in ipairs(ids) do
        if of[id] ~= room then
            room.members[#room.members + 1] = id
            of[id] = room
            if not room.teams then room.players[#room.players + 1] = id end
        end
        if room.teams and not contains(team, id) then
            for _, other in ipairs(room.teams) do remove(other, id) end
            team[#team + 1] = id
        end
    end
end

local function hostOnly(id)
    local room = of[id]
    if not room then return nil, "You are not in a room." end
    if room.host ~= id then return nil, "Only the host can do that." end
    return room
end

-- ---------------------------------------------------------------------------
-- The crew. The server's own membership: nothing of this comes from the client.

local function crewOf(id)
    local P = LightRP.parties
    local crew = P and type(P.of) == "function" and P.of(id) or nil
    if crew and #(crew.members or {}) > 1 then return crew end
    return nil
end

-- What a join of this member's own would answer. nil: they may come. room nil: being opened.
local function refusal(member, room, activityId)
    if of[member] then return "You are already in a room: leave it first." end
    if room and room.banned[member] then return "The host removed you from this room." end
    local free, why = A.check(member, activityId)
    if not free then return why end
    return nil
end

-- Who comes with `id` into `room` (nil: being opened). The rest of their crew, each on their
-- own join's checks; a player alone brings nobody.
--   { crew, coming = { ids }, inside = { ids already in this room }, out = { { id, why } } }
local function following(id, room, activityId)
    local crew = crewOf(id)
    local group = { crew = crew, coming = {}, inside = {}, out = {} }
    if not crew then return group end
    for _, member in ipairs(crew.members) do
        if member ~= id then
            if room and of[member] == room then
                group.inside[#group.inside + 1] = member
            else
                local why = refusal(member, room, activityId)
                if why then group.out[#group.out + 1] = { id = member, why = why }
                else group.coming[#group.coming + 1] = member end
            end
        end
    end
    return group
end

-- The joiner first, then whoever comes, then who is in already.
local function together(id, group)
    local ids = { id }
    for _, p in ipairs(group.coming) do ids[#ids + 1] = p end
    for _, p in ipairs(group.inside) do ids[#ids + 1] = p end
    return ids
end

local function lowerFirst(text) return (tostring(text):gsub("^%u", string.lower)) end

-- `did`: what the one who asked did, for the others. Who came is told how out; who did not, why.
local function tellCrew(id, group, did)
    for _, p in ipairs(group.coming) do
        LightRP.notice(p, { kind = "contract", title = "CREW", durationMs = 6000,
            body = name(id) .. " " .. did .. ": you are in it. /room opens it, /leave drops you out." })
    end
    for _, entry in ipairs(group.out) do
        LightRP.notice(entry.id, { kind = "warning", title = "CREW", durationMs = 7000,
            body = name(id) .. " " .. did .. ". You stay out: " .. lowerFirst(entry.why) })
    end
end

-- What the join's answer adds, for the one who joined.
local function crewLine(id, group)
    local parts = {}
    local n = #group.coming
    if n > 0 then parts[1] = string.format(" %d crew member%s with you.", n, n == 1 and "" or "s") end
    for _, entry in ipairs(group.out) do parts[#parts + 1] = " " .. name(entry.id) .. " stays out: " .. lowerFirst(entry.why) end
    return table.concat(parts)
end

-- Everyone comes in together; who followed is remembered for the way out of who brought them.
local function bring(room, id, group, team)
    place(room, together(id, group), team)
    if group.crew then
        for _, p in ipairs(group.coming) do room.followed[p] = id end
    end
end

-- ---------------------------------------------------------------------------
-- Operations: ok, text (a move and the settings answer with the next push)

function R.create(id, payload)
    if not enabled() then return false, "Game rooms are closed." end
    if of[id] then return false, "You are already in a room: leave it first." end
    local a, teams = hostable(payload.id)
    if not a then return false, "That game cannot be hosted right now." end
    if a.status.joinable == false then return false, a.label .. " is not taking players right now." end
    local ok, mode = pickMode(a, payload.mode)
    if not ok then return false, "That map is not offered." end
    local size = pickSize(a, teams, payload.size)
    if not size then return false, "That room size is not offered." end
    local free, why = A.check(id, a.id)
    if not free then return false, why end
    if count() >= maxRooms() then return false, "Every room is taken. Join one, or try again in a moment." end
    local group = following(id, nil, a.id)
    local crewSize = 1 + #group.coming
    if crewSize > size then
        local _, most = limits(a, teams)
        return false, string.format("Your crew is %d: this room takes %d%s. %s", crewSize, size, teams and " per side" or "",
            crewSize <= most and "Pick a bigger room." or "Start a friendly match to play it inside the crew.")
    end
    local private = payload.private == true
    local code
    if private then
        code = newCode()
        if not code then return false, "No room code is free. Try again in a moment." end
    end
    seq = seq + 1
    local room = { id = seq, host = id, activity = a.id, mode = mode, size = size, sideMax = size, private = private, code = code,
        members = {}, banned = {}, seen = {}, followed = {}, bench = {}, noBots = true, at = now() }
    if teams then
        room.teams = {}
        for i = 1, teams do room.teams[i] = {} end
    else
        room.players = {}
    end
    rooms[room.id] = room
    bring(room, id, group, room.teams and room.teams[1])
    changed(room)
    tellCrew(id, group, "opened a " .. a.label .. " room")
    LightRP.log("rooms: %s (%d) opened room %d: %s%s, %s, %d in", name(id), id, room.id, a.id, mode and (" " .. mode) or "",
        private and "private" or "public", #room.members)
    return true, (private and ("Room open. Code: " .. code .. ".") or "Room open.") .. crewLine(id, group)
end

function R.join(id, payload)
    if not enabled() then return false, "Game rooms are closed." end
    local room
    if type(payload.code) == "string" and #payload.code <= 16 then
        local code = payload.code:upper():gsub("[^%w]", "")
        for _, r in pairs(rooms) do if r.code == code then room = r end end
        if not room then return false, "No room has that code." end
    else
        local wanted = whole(payload.id)
        local r = wanted and rooms[wanted] or nil
        -- a private room is found by its code only: its id answers like a missing one
        if not r or r.private then return false, "That room is gone." end
        room = r
    end
    if of[id] == room then return true end
    if of[id] then return false, "You are already in a room: leave it first." end
    if room.banned[id] then return false, "The host removed you from this room." end
    local a = hostable(room.activity)
    if not a then
        close(room, "warning", "This game stopped: the room closed.")
        return false, "That room is gone."
    end
    if #room.members >= capacity(room) then return false, "That room is full." end
    local free, why = A.check(id, a.id)
    if not free then return false, why end
    local group = following(id, room, a.id)
    local ids = together(id, group)
    local crewSize, left = 1 + #group.coming, capacity(room) - #room.members
    if crewSize > left then
        return false, string.format("Your crew is %d: this room has %d place%s left.", crewSize, left, left == 1 and "" or "s")
    end
    local team = room.teams and teamFor(room, ids)
    if room.teams and not team then
        return false, string.format("Your crew is %d: no team of this room has that many places.", #ids)
    end
    bring(room, id, group, team)
    for _, p in ipairs(group.coming) do room.seen[p] = room.seen[p] or now() end
    -- Coming back keeps nothing alive and tells the host once per joinNoticeMs: a player
    -- going in and out can neither hold a room open nor flood its host.
    local t, seen = now(), room.seen[id]
    if seen == nil then room.at = t end
    if seen == nil or t - seen >= joinNoticeMs() then
        room.seen[id] = t
        notify(room.host, "info", name(id) .. " joined your room" .. (#group.coming > 0
            and string.format(" with %d crew member%s.", #group.coming, #group.coming == 1 and "" or "s") or "."))
    end
    changed(room)
    tellCrew(id, group, "joined " .. name(room.host) .. "'s " .. a.label .. " room")
    return true, "You joined " .. name(room.host) .. "'s room." .. crewLine(id, group)
end

function R.leave(id)
    local room = of[id]
    if not room then return false, "You are not in a room." end
    -- whoever brought the crew in takes it out, as from a queue (A.requestLeave)
    local crew, took = crewOf(id), 0
    if crew then
        for _, member in ipairs(crew.members) do
            if member ~= id and of[member] == room and room.followed[member] == id then
                drop(room, member)
                took = took + 1
                LightRP.notice(member, { kind = "info", title = "CREW", body = name(id) .. " left the room, and you with them." })
            end
        end
    end
    drop(room, id)
    return true, took > 0 and "You left the room with your crew." or "You left the room."
end
A.roomLeave = R.leave

function R.kick(id, payload)
    local room, why = hostOnly(id)
    if not room then return false, why end
    local target = whole(payload.target)
    if not target or of[target] ~= room then return false, "That player is not in your room." end
    if target == id then return false, "Leave the room instead." end
    room.banned[target] = true
    drop(room, target)
    notify(target, "warning", "The host removed you from the room.")
    return true, name(target) .. " is out of the room."
end

function R.move(id, payload)
    local room, why = hostOnly(id)
    if not room then return false, why end
    if not room.teams then return false, "This game has no teams." end
    local target, team = whole(payload.target), whole(payload.team)
    if not target or of[target] ~= room then return false, "That player is not in your room." end
    if not team or team < 1 or team > #room.teams then return false, "No such team." end
    local ok, refused = A.moveInSetup(room, target, team)
    if not ok then return false, refused end
    room.at = now()
    changed(room)
    return true
end

function R.settings(id, payload)
    local room, why = hostOnly(id)
    if not room then return false, why end
    local a = hostable(room.activity)
    if not a then
        close(room, "warning", "This game stopped: the room closed.")
        return false, "That game cannot be hosted right now."
    end
    local mode, size = room.mode, room.size
    if payload.mode ~= nil then
        local ok, picked = pickMode(a, payload.mode)
        if not ok then return false, "That map is not offered." end
        mode = picked
    end
    if payload.size ~= nil then
        size = pickSize(a, room.teams and #room.teams or nil, payload.size)
        if not size then return false, "That room size is not offered." end
        for _, team in ipairs(room.teams or { room.players }) do
            if #team > size then return false, "More players than that are already in: move or kick one first." end
        end
    end
    local private = room.private
    if payload.private == true or payload.private == false then private = payload.private end
    local code = room.code
    if private and not code then
        code = newCode()
        if not code then return false, "No room code is free. Try again in a moment." end
    elseif not private then
        code = nil
    end
    -- a room going private leaves the open menus' list: they hear of it
    if private ~= room.private then menus() end
    room.mode, room.size, room.sideMax, room.private, room.code = mode, size, size, private, code
    room.at = now()
    changed(room)
    return true
end

function R.start(id)
    local room, why = hostOnly(id)
    if not room then return false, why end
    local a = hostable(room.activity)
    if not a then
        close(room, "warning", "This game stopped: the room closed.")
        return false, "That game cannot be hosted right now."
    end
    if not pickMode(a, room.mode) then return false, "That map is gone: pick another." end
    -- the entries of this match, in this very tick, are not "another activity"
    room.starting = true
    local ok, text = A.launchFriendly(id, room, { from = "room", stuck = " Kick them or wait." })
    room.starting = nil
    room.at = now()
    if not ok then
        changed(room)
        return false, text
    end
    close(room)
    return true, text
end

local OPS = { create = R.create, join = R.join, leave = R.leave, kick = R.kick, move = R.move, settings = R.settings, start = R.start }

-- What an open menu shows of A.check: free, or the sentence why not. A countdown in that
-- sentence running down is no change.
local function standing(id)
    local free, why = A.check(id)
    if free then return "free" end
    return (tostring(why):gsub("%d+", "#"))
end

function R.open(id)
    watchers[id] = true
    standings[id] = standing(id)
    A.watch(id)
    LightRP.state(id, "activities")
    LightRP.state(id, "rooms")
    LightRP.dialog(id, "rooms", {})
end

LightRP.action(ACTION, function(id, payload)
    local op = payload.operation
    if op == "open" then R.open(id); return end
    local run = type(op) == "string" and OPS[op] or nil
    local ok, text = false, "Unknown room operation."
    if run then ok, text = run(id, payload) end
    if text ~= nil or not ok then LightRP.result(id, ok == true, text, ACTION) end
end)

local function closeMenu(id) watchers[id], standings[id] = nil, nil end
LightRP.action(CLOSE_ACTION, closeMenu)

LightRP.command("room", { usage = "/room (your game room, or the rooms list)" }, function(source)
    if not source or source <= 0 then return false, "Players only." end
    R.open(source)
end)

-- ---------------------------------------------------------------------------
-- Life around a room

-- activities.lua forget: the provider went, its rooms with it.
function A.roomsForget(activityId)
    for _, room in pairs(rooms) do
        if room.activity == activityId then close(room, "warning", "This game stopped: the room closed.") end
    end
    menus()
end
-- A provider (re)registered: the open menus list what it brought.
A.roomsListed = menus

-- Entering anything but this room's own match takes the player out of the room.
function R.onActivityChanged(id, activityId)
    local room = of[id]
    if not room or not activityId or room.starting then return end
    drop(room, id)
    notify(id, "info", "You joined " .. A.labelOf(activityId) .. ": you left the room.")
end

function R.onDisconnected(id)
    closeMenu(id)
    if of[id] then drop(of[id], id) end
end
local function characterChanged(id) if of[id] then drop(of[id], id) end end
R.onCharacterLoaded, R.onCharacterSwitched = characterChanged, characterChanged

-- Every 5 s: an idle room closes; a member a mission took (no activity event) leaves.
function R.tick()
    local t = now()
    for _, room in pairs(rooms) do
        if t - room.at >= idleMs() then
            close(room, "info", "Nobody touched this room for a while: it closed.")
        else
            for i = #room.members, 1, -1 do
                local p = room.members[i]
                if A.owner(p) ~= nil then
                    drop(room, p)
                    notify(p, "info", "You are busy elsewhere: you left the room.")
                end
            end
        end
    end
end

-- Every second, for the open menus only: the activities list stays live as long as the menu
-- is open, and what the player may do changes with nothing to push it (a hurt player's
-- cooldown runs out). Pushed on change only.
function R.watchTick()
    for id in pairs(watchers) do
        A.watch(id)
        local now_ = standing(id)
        if now_ ~= standings[id] then
            standings[id] = now_
            told(id)
        end
    end
end

CreateThread(function()
    while true do
        Wait(5000)
        local ok, err = pcall(R.tick)
        if not ok then LightRP.log("rooms: tick failed: %s", tostring(err)) end
    end
end)
CreateThread(function()
    while true do
        Wait(1000)
        local ok, err = pcall(R.watchTick)
        if not ok then LightRP.log("rooms: menu check failed: %s", tostring(err)) end
    end
end)

-- ---------------------------------------------------------------------------
-- The state

local function people(list, room)
    local out = {}
    for _, p in ipairs(list) do out[#out + 1] = { id = p, name = name(p), host = p == room.host or nil } end
    return out
end

local function modeLabel(a, mode)
    if mode == nil then return nil end
    for _, m in ipairs(a and a.modes or {}) do if m.id == mode then return m.label end end
    return mode
end

local function listing(room)
    local a = A.registry[room.activity]
    return { id = room.id, activity = room.activity, label = a and a.label or room.activity, mode = room.mode,
        modeLabel = modeLabel(a, room.mode), host = name(room.host), count = #room.members, max = capacity(room),
        teams = room.teams and #room.teams or nil }
end

local function roomView(id, room)
    local v = listing(room)
    local a = A.registry[room.activity]
    v.private, v.code, v.mine, v.size = room.private, room.code, room.host == id, room.size
    if a then v.least, v.most = limits(a, room.teams and #room.teams or nil) end
    v.issue = A.friendlyIssueOf(room)
    if room.teams then
        v.teams = {}
        for i, team in ipairs(room.teams) do v.teams[i] = people(team, room) end
    else
        v.players = people(room.players, room)
    end
    return v
end

function R.view(id)
    local games, ids = {}, {}
    for activityId in pairs(A.registry) do ids[#ids + 1] = activityId end
    table.sort(ids)
    for _, activityId in ipairs(ids) do
        local a, teams = hostable(activityId)
        if a then
            local least, most = limits(a, teams)
            games[#games + 1] = { id = a.id, teams = teams, least = least, most = most }
        end
    end
    local list, order = {}, {}
    for roomId, room in pairs(rooms) do if not room.private then order[#order + 1] = roomId end end
    table.sort(order)
    for _, roomId in ipairs(order) do list[#list + 1] = listing(rooms[roomId]) end
    local free, why = A.check(id)
    return { enabled = enabled(), eligible = free == true, reason = why, full = count() >= maxRooms(), games = games, list = list,
        room = of[id] and roomView(id, of[id]) or false }
end
LightRP.stateProvider("rooms", R.view)
