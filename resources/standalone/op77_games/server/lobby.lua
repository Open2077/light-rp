-- Admission, for a join with or without a Light RP match.
--   options.match   exactly the listed players, in one instance of their own, on their
--                   teams: started when all are in, or gatherSeconds after the first.
--                   Never joined by anyone else; a late join for it is refused.
--   no match        (the panel) a queue per activity: once the minimum waits a join window
--                   opens, a full lobby shortens it, its first join picks the map. Queued
--                   players are not owned yet: they keep playing until the launch. A game
--                   already running is never joined (E.lateMatch: unless its mode opted in);
--                   the queue makes the next one.
--   options.squad   (the crew the core sends along, one join per member, no match) a crew
--                   gets a place for everyone of it who can still come, or waits out whole;
--                   in a team game it plays on one side, unless it is the whole lobby: then
--                   nobody else is there to play and the deal splits it.
-- Whoever we held without starting is released with activityLeave: Light RP lists them.
local Config = GamesConfig
local A = GamesActivity
local E = GamesEngine
local C = GamesCombat

GamesLobby = {}
local L = GamesLobby

local queues = {}   -- def.id -> { members = { id... }, map, windowEndsAt }
local gathers = {}  -- def.id .. "|" .. match id -> { key, id, def, expected, members, teams, friendly, map, at }
local launched = {} -- the same key -> when it started
local squads = {}   -- playerId -> { id, members = { ids } } while queued with a crew
L.queues, L.gathers, L.squads = queues, gathers, squads

local REASONS = {
    no_scope = "Every fight slot is in use. Try again in a moment.",
    no_bucket = "Every instance is in use. Try again in a moment.",
    no_map = "This game has no map right now.",
    not_enough = "Not enough players are ready.",
    stopped = "This game is not available right now.",
}
-- The room closed when its host started it, and nothing brings it back.
local ROOM_GONE = " The room closed: host the game again."

local function contains(list, value)
    for index, item in ipairs(list) do if item == value then return index end end
    return nil
end
local function connected(id) return Open77.players.name(id) ~= nil end

-- A player we held without starting: the core still lists them as queued.
local function release(def, id)
    if A.owner(id) == nil then A.call("activityLeave", id, def.id, { returnPlayer = false }) end
end

local function tell(id, def, text, durationMs) A.notice(id, "warning", def.label, text, durationMs) end

function L.queuedIn(id)
    for key, q in pairs(queues) do
        if contains(q.members, id) then return key end
    end
    for _, g in pairs(gathers) do
        if contains(g.members, id) then return g.def.id end
    end
    return nil
end

-- Out of any queue or gathering. True when they were in one.
function L.leave(id)
    local found = false
    for _, q in pairs(queues) do
        local index = contains(q.members, id)
        if index then
            table.remove(q.members, index)
            found = true
        end
    end
    squads[id] = nil
    for _, g in pairs(gathers) do
        local index = contains(g.members, id)
        if index then
            table.remove(g.members, index)
            found = true
        end
        index = contains(g.expected, id)
        if index then table.remove(g.expected, index) end
    end
    return found
end

function L.clear()
    for key in pairs(queues) do queues[key] = nil end
    for key in pairs(gathers) do gathers[key] = nil end
    for id in pairs(squads) do squads[id] = nil end
end

-- ids from the outside: positive whole numbers, no repeats, this many at most.
local function idList(value, seen, limit)
    local out = {}
    for _, raw in ipairs(type(value) == "table" and value or {}) do
        local id = E.playerId(raw)
        if id and not seen[id] and #out < limit then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    return out
end

-- The crew a join came with, or nil: a crew of one, or one without this player, is none.
local function squadOf(options, id)
    local squad = options.squad
    if type(squad) ~= "table" or squad.id == nil then return nil end
    local members = idList(squad.members, {}, 64)
    if #members < 2 or not contains(members, id) then return nil end
    return { id = tostring(squad.id):sub(1, 64), members = members }
end

-- Places this join needs in the queue: theirs, and those of their crew still to come. A
-- member who cannot come any more (the core told them) keeps no place.
local function placesFor(def, q, id, squad)
    local need = 1
    for _, member in ipairs(squad and squad.members or {}) do
        if member ~= id and not contains(q.members, member) and connected(member) and A.check(member, def.id) then
            need = need + 1
        end
    end
    return need
end

-- The sides of a public lobby: each crew whole, the biggest first, on the side with the fewest
-- players; the deal (engine) spreads the others behind them. nil: no crew to keep together, or
-- a single crew that is the whole lobby.
local function crewSides(def, ids)
    if not def.teams then return nil end
    local crews, at = {}, {}
    for _, id in ipairs(ids) do
        local squad = squads[id]
        if squad then
            if not at[squad.id] then
                at[squad.id] = { order = #crews + 1 }
                crews[#crews + 1] = at[squad.id]
            end
            local crew = at[squad.id]
            crew[#crew + 1] = id
        end
    end
    if #crews == 0 or (#crews == 1 and #crews[1] == #ids) then return nil end
    table.sort(crews, function(a, b)
        if #a ~= #b then return #a > #b end
        return a.order < b.order
    end)
    local teams = {}
    for side = 1, def.teams do teams[side] = {} end
    for _, crew in ipairs(crews) do
        local side = teams[1]
        for _, team in ipairs(teams) do if #team < #side then side = team end end
        table.move(crew, 1, #crew, #side + 1, side)
    end
    return teams
end

-- The ones who can still go, the others told and released. Starts them, or holds nobody.
local function launch(def, ids, opts)
    local ready, stuck = {}, {}
    for _, id in ipairs(ids) do
        local ok, why = A.check(id, def.id)
        if ok then
            ready[#ready + 1] = id
        else
            if connected(id) then stuck[#stuck + 1] = { id = id, why = why } end
            release(def, id)
        end
    end
    -- the sides from who really goes: a crew whose opponents fell away is the whole lobby
    if opts.crews then
        opts.teams = crewSides(def, ready)
        for _, id in ipairs(ids) do squads[id] = nil end
    end
    local match, reason = E.open(def, ready, opts)
    local tail = match == nil and opts.room and ROOM_GONE or ""
    local duration = tail ~= "" and 8000 or nil
    for _, entry in ipairs(stuck) do tell(entry.id, def, entry.why .. tail, duration) end
    if match == nil then
        for _, id in ipairs(ready) do
            tell(id, def, (REASONS[reason] or "The game could not start.") .. tail, duration)
            release(def, id)
        end
        return nil, reason
    end
    for _, id in ipairs(ready) do
        if E.matchOf(id) ~= match then release(def, id) end
    end
    return match
end

local function launchGather(g)
    gathers[g.key] = nil
    launched[g.key] = E.now()
    return launch(g.def, g.members, { map = g.map, teams = g.teams, matchId = g.id, friendly = g.friendly, room = g.room })
end

local function joinMatch(id, def, options)
    local info = options.match
    local key = def.id .. "|" .. tostring(info.id)
    if launched[key] then
        local running = E.lateMatch(def, info.id)
        if running then return E.joinLate(running, id) end
        release(def, id)
        return false, "That match has already started."
    end
    local g = gathers[key]
    if g == nil then
        local seen = {}
        local teams = {}
        for side, team in ipairs(type(info.teams) == "table" and info.teams or {}) do
            teams[side] = idList(team, seen, def.maxPlayers)
        end
        local expected = idList(info.players, {}, def.maxPlayers)
        g = { key = key, id = info.id, def = def, expected = expected, members = {}, teams = teams,
            friendly = info.friendly == true, room = options.from == "room", map = options.map, at = E.now() }
        gathers[key] = g
    end
    if not contains(g.expected, id) then
        if #g.expected >= def.maxPlayers then
            release(def, id)
            return false, "That match is full."
        end
        g.expected[#g.expected + 1] = id
    end
    if not contains(g.members, id) then g.members[#g.members + 1] = id end
    return true
end

-- The player joins an activity of ours (the core checked eligibility before its join
-- event). Returns true, or false and a sentence for the player.
function L.join(id, def, options)
    options = type(options) == "table" and options or {}
    if E.matchOf(id) then return false, "You are already in a game." end
    if #def.maps == 0 then
        release(def, id)
        return false, REASONS.no_map
    end
    local current = L.queuedIn(id)
    if current and current ~= def.id then
        release(def, id)
        return false, "You are already waiting for another game."
    end
    if type(options.match) == "table" and options.match.id ~= nil then
        L.leave(id)
        return joinMatch(id, def, options)
    end
    if current then return true end
    local running = E.lateMatch(def, nil)
    if running then return E.joinLate(running, id) end
    if type(options.map) == "string" and E.mapOf(def, options.map) == nil then
        release(def, id)
        return false, "That map is not available."
    end
    local q = queues[def.id]
    if q == nil then
        q = { members = {} }
        queues[def.id] = q
    end
    local squad = squadOf(options, id)
    local need = placesFor(def, q, id, squad)
    if #q.members + need > def.maxPlayers then
        if #q.members == 0 then queues[def.id] = nil end
        release(def, id)
        if need > 1 then return false, "This lobby has no room for your whole crew. Try again in a moment." end
        return false, "This lobby is full. Try again in a moment."
    end
    q.members[#q.members + 1] = id
    squads[id] = squad
    q.map = q.map or options.map
    return true
end

local function stepQueue(def, q, t)
    for index = #q.members, 1, -1 do
        if not connected(q.members[index]) then
            squads[q.members[index]] = nil
            table.remove(q.members, index)
        end
    end
    if #q.members < def.minPlayers then
        q.windowEndsAt = nil
        if #q.members == 0 then queues[def.id] = nil end
        return
    end
    local lobby = Config.lobby
    if q.windowEndsAt == nil then q.windowEndsAt = t + lobby.windowSeconds * 1000 end
    if #q.members >= def.maxPlayers then q.windowEndsAt = math.min(q.windowEndsAt, t + lobby.fullWindowSeconds * 1000) end
    if t < q.windowEndsAt then return end
    queues[def.id] = nil
    launch(def, q.members, { map = q.map, crews = true })
end

function L.tick(t)
    for _, def in ipairs(A.list) do
        local q = queues[def.id]
        if q then stepQueue(def, q, t) end
    end
    for key, g in pairs(gathers) do
        if #g.members == 0 then
            gathers[key] = nil
        elseif #g.members >= #g.expected or t - g.at >= Config.lobby.gatherSeconds * 1000 then
            launchGather(g)
        end
    end
    for key, at in pairs(launched) do
        if t - at >= Config.lobby.launchedKeepMs then launched[key] = nil end
    end
end

-- status.queue v1: the public lobby, and each match on its way.
function L.queueOf(def, t)
    local lobbies = {}
    local q = queues[def.id]
    if q and #q.members > 0 then
        lobbies[#lobbies + 1] = { players = table.move(q.members, 1, #q.members, 1, {}), need = def.minPlayers, max = def.maxPlayers,
            startsInMs = q.windowEndsAt and math.max(0, q.windowEndsAt - t) or nil, mode = q.map }
    end
    for _, g in pairs(gathers) do
        if g.def == def and #g.members > 0 then
            lobbies[#lobbies + 1] = { players = table.move(g.members, 1, #g.members, 1, {}), need = #g.expected, joining = true }
        end
    end
    table.sort(lobbies, function(a, b) return a.players[1] < b.players[1] end)
    return { v = 1, lobbies = lobbies }
end

function L.statusOf(def, t)
    local games, players = 0, 0
    for _, match in pairs(E.matches) do
        if match.def == def then
            games = games + 1
            for _ in pairs(match.players) do players = players + 1 end
        end
    end
    local q = queues[def.id]
    local queued = q and #q.members or 0
    local detail = games > 0 and ("%d game%s on"):format(games, games == 1 and "" or "s") or (queued > 0 and "Waiting for players" or "Open")
    local joinable = not def.pvp or C.free() > 0
    if not joinable then detail = "Every fight slot is in use" end
    if #def.maps == 0 then joinable, detail = false, "No map" end
    return { phase = games > 0 and "running" or (queued > 0 and "lobby" or "idle"), players = players, queued = queued,
        joinable = joinable, detail = detail, queue = L.queueOf(def, t) }
end
