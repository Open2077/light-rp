-- Admission.
--   Time trial: starts at once (one racer, one instance).
--   Street and rooftop races (queued heats): once the minimum is waiting, a join window
--     opens (later arrivals do not restart it), a full grid shortens it, and at its end
--     every queued player is re-checked with activityCheck before the instance starts.
--     Queued players are not owned by Light RP yet: they keep playing until the launch.
--   Street Race vs AI: starts at once for a player alone; a crew starts together once
--     every member has joined (or crews.gatherSeconds after the first), and AI drivers
--     fill the grid behind them.
--   Crews (options.squad = { id, leader, members } from the core): one instance, adjacent
--     slots, never split. A crew that does not fit the heat waits whole for the next one,
--     and a launch waits for crew members still on their way (crews.gatherSeconds).
--   Staff bot mode (RaceActivity.bots): one player opens a queued heat and the launch
--     fills its grid with bots.
--   Matches (options.match from Light RP's lobby, street and rooftop races): exactly the
--     listed players, in a heat of their own (never the public queue, never joined by
--     anyone else), started once all are in or matches.gatherSeconds after the first,
--     with options.fill AI racers on the grid (the staff bot mode's filling, capped to the
--     course and matches.fillTo). A friendly or AI-filled match is unranked; a ranked one
--     (humans only) is raced and recorded like a heat of our queue.
--   options.ranked == false (any activity): the run writes no best time and its result
--     says `unranked`.
--   Parkour race: queued like the rooftop race, but the course is a join choice
--     (options.course, from the panel or a match): the first choice in the queue sets the
--     heat's, a later different one is told so. Unranked and without bots, always.
--   Race vs AI difficulty (options.difficulty + options.scaling): how many AI drivers and
--     how they drive (Config.pve). One per race: a crew's first join sets it.
local Config = RaceConfig
local A = RaceActivity
local E = RaceEngine

RaceLobby = {}
local L = RaceLobby

local queues = {}   -- activity key -> { members = { playerId... }, windowEndsAt, lastCourse, crews = { [squadId] = firstAt } }
L.queues = queues
local lastCourse = { trial = {}, pve = {} } -- mode -> playerId -> course chosen last (a later join without one reuses it)
local squads = {}   -- playerId -> { id, leader, expected = { playerId... } } while queued for a heat with a crew
L.squads = squads
local crews = {}    -- squad id -> { id, def, members, expected, leader, options, difficulty, at } gathering for a race vs AI
L.crews = crews
local matches = {}  -- activity key .. "|" .. match id -> { key, id, def, expected, members, fill, friendly, ranked, at } gathering
L.matches = matches
local launched = {} -- the same key -> when it started: a late join for it is refused, not a lone heat
local LAUNCHED_KEEP_MS = 60000
local lastMatchCourse = {} -- activity key -> course a match ran last (matches rotate apart from the public heat)
local unranked = {} -- playerId -> true: their join came with options.ranked == false
L.unranked = unranked

local noop = function() end
L.hooks = {
    notice = noop,   -- (playerId, kind, title, text)
    changed = noop,  -- () queue or instances changed: status and menus
}

local function log(text) print("[race:lobby] " .. tostring(text)) end
local function connected(playerId) return Open77.players.name(playerId) ~= nil end
local function contains(list, value)
    for index, item in ipairs(list) do if item == value then return index end end
    return nil
end
local function gatherMs()
    local crewsConfig = type(Config.crews) == "table" and Config.crews or {}
    return math.floor((tonumber(crewsConfig.gatherSeconds) or 5) * 1000)
end
local function matchGatherMs()
    local seconds = type(Config.matches) == "table" and tonumber(Config.matches.gatherSeconds) or nil
    if seconds == nil then return gatherMs() end
    return math.floor(math.max(0, seconds) * 1000)
end
-- A count from outside (options.fill): a whole number in 0..64.
local function count(value)
    local n = tonumber(value)
    if n == nil or n ~= n or n <= 0 then return 0 end
    return math.floor(math.min(n, 64))
end
-- { [playerId] = true } for the ones whose entry is unranked (E.start opts.unranked).
local function unrankedOf(playerIds)
    local set = {}
    for _, playerId in ipairs(playerIds) do
        if unranked[playerId] then set[playerId] = true end
    end
    return set
end
-- A player we held in a queue or a match without starting them: Light RP still lists
-- them as queued, so it is told (activityLeave on a queued-only player, never an owned one).
local function releaseQueued(def, playerId)
    if A.owner(playerId) == nil then A.call("activityLeave", playerId, def.id, { returnPlayer = false }) end
end

local function queue(key)
    local q = queues[key]
    if q == nil then
        q = { members = {}, crews = {} }
        queues[key] = q
    end
    q.crews = q.crews or {}
    return q
end

local REASONS = {
    no_free_bucket = "Every race instance is in use. Try again in a moment.",
    nobody_admitted = "You could not be admitted.",
    course_unavailable = "No course is available for this race.",
    no_ai = "No AI driver is available on this server right now.",
}
local function sentence(reason) return REASONS[reason] or "The race could not start." end

-- ---------------------------------------------------------------- crews --

-- The crew a join came with, or nil (no crew, a crew of one, or a crew without this
-- player in it). Members are player ids, or tables carrying one.
local function squadOf(options, playerId)
    local squad = type(options) == "table" and options.squad or nil
    if type(squad) ~= "table" or squad.id == nil or type(squad.members) ~= "table" then return nil end
    local expected, mine = {}, false
    for _, member in ipairs(squad.members) do
        local raw = type(member) == "table" and (member.id or member.playerId) or member
        local id = math.tointeger(tonumber(raw))
        if id and id > 0 and not contains(expected, id) then
            expected[#expected + 1] = id
            if id == playerId then mine = true end
        end
    end
    if #expected < 2 or not mine then return nil end
    return { id = tostring(squad.id):sub(1, 64), leader = math.tointeger(tonumber(squad.leader)), expected = expected }
end
L.squadOf = squadOf

-- Crew entries of a queue whose members all left it are forgotten.
local function refreshCrews(q)
    if #q.members == 0 then q.course = nil end
    local present = {}
    for _, playerId in ipairs(q.members) do
        local squad = squads[playerId]
        if squad then present[squad.id] = true end
    end
    for squadId in pairs(q.crews) do
        if not present[squadId] then q.crews[squadId] = nil end
    end
end

-- A crew member listed by the core who is still on the way to this queue.
local function gathering(q, now)
    for squadId, since in pairs(q.crews) do
        if now - since < gatherMs() then
            local here, expected = {}, nil
            for _, playerId in ipairs(q.members) do
                local squad = squads[playerId]
                if squad and squad.id == squadId then here[playerId] = true; expected = squad.expected end
            end
            for _, playerId in ipairs(expected or {}) do
                if not here[playerId] and connected(playerId) and not E.busy(playerId) then return true end
            end
        end
    end
    return false
end
L.gathering = gathering

-- The queue in launch order, a crew as one block at the place of its first member.
local function blocks(q)
    local out, at = {}, {}
    for _, playerId in ipairs(q.members) do
        local squad = squads[playerId]
        if squad and at[squad.id] then
            local block = out[at[squad.id]]
            block[#block + 1] = playerId
        else
            out[#out + 1] = { playerId }
            if squad then at[squad.id] = #out end
        end
    end
    return out
end

-- ---------------------------------------------------------------- queues --

function L.queuedIn(playerId)
    for key, q in pairs(queues) do
        for index, memberId in ipairs(q.members) do
            if memberId == playerId then return key, index end
        end
    end
    for _, crew in pairs(crews) do
        local index = contains(crew.members, playerId)
        if index then return crew.def.key, index end
    end
    for _, m in pairs(matches) do
        local index = contains(m.members, playerId)
        if index then return m.def.key, index end
    end
    return nil
end

-- The match this player is gathering in, or nil.
function L.matchIn(playerId)
    for _, m in pairs(matches) do
        if contains(m.members, playerId) then return m end
    end
    return nil
end

function L.size(key)
    local q = queues[key]
    local n = q and #q.members or 0
    for _, crew in pairs(crews) do
        if crew.def.key == key then n = n + #crew.members end
    end
    for _, m in pairs(matches) do
        if m.def.key == key then n = n + #m.members end
    end
    return n
end

-- Staff bot mode (RaceActivity.bots): one player is enough to open a queued heat, and
-- the launch fills it with bots. Read live, so switching it off starts no new bot race.
function L.botMode() return A.bots == true end

-- Bot mode on and this server can put bots of that kind on the course (natives present).
-- Without them bot mode changes nothing: no lone heat that nobody joins.
local function botsHere(def)
    return def.queued == true and not def.noBots and L.botMode() and RaceBots ~= nil and RaceBots.capable(def.mode == "foot")
end
L.botsHere = botsHere

function L.minimum(def)
    if botsHere(def) then return 1 end
    return def.minPlayers
end

local function joinSeconds(def)
    local configured = L.botMode() and type(Config.bots) == "table" and type(Config.bots.joinSeconds) == "table"
        and tonumber(Config.bots.joinSeconds[def.mode]) or nil
    return configured or def.joinSeconds or 30
end

-- Racers in total (players + bots) for a heat launched in bot mode, within the course's capacity.
local function botFill(def, capacity)
    if not botsHere(def) or type(Config.bots) ~= "table" then return nil end
    local target = type(Config.bots.fillTo) == "table" and tonumber(Config.bots.fillTo[def.mode]) or nil
    if target == nil then return nil end
    return math.max(0, math.min(capacity, math.floor(target)))
end

function L.windowRemainingMs(key, now)
    local q = queues[key]
    if q == nil or q.windowEndsAt == nil then return nil end
    return math.max(0, q.windowEndsAt - (now or E.nowMs()))
end

-- Light RP's queue panel (status.queue, v1) for one activity: the heat (its minimum,
-- the grid's seats, the join window once open), each crew getting ready for a race vs
-- AI (its members; it goes when complete or when the gather wait is over), each match
-- gathering (joining). Lobby = { players, need, max, startsInMs, joining }.
function L.queueOf(def, now)
    now = now or E.nowMs()
    local lobbies = {}
    local q = def.queued and queues[def.key] or nil
    if q and #q.members > 0 then
        local players = {}
        for i, id in ipairs(q.members) do players[i] = id end
        lobbies[#lobbies + 1] = { players = players, need = L.minimum(def), max = def.maxPlayers,
            startsInMs = L.windowRemainingMs(def.key, now) }
    end
    for _, crew in pairs(crews) do
        if crew.def.key == def.key and #crew.members > 0 then
            local players = {}
            for i, id in ipairs(crew.members) do players[i] = id end
            lobbies[#lobbies + 1] = { players = players, need = math.max(#crew.members, #crew.expected),
                startsInMs = math.max(0, crew.at + gatherMs() - now) }
        end
    end
    for _, m in pairs(matches) do
        if m.def.key == def.key and #m.members > 0 then
            local players = {}
            for i, id in ipairs(m.members) do players[i] = id end
            lobbies[#lobbies + 1] = { players = players, need = math.max(#m.members, #m.expected), joining = true }
        end
    end
    -- pairs order is no order: the same lobbies give the same digest
    table.sort(lobbies, function(a, b) return a.players[1] < b.players[1] end)
    return { v = 1, lobbies = lobbies }
end

-- Removes a player from any queue or gathering crew. Returns true when they were in one.
function L.leave(playerId)
    local found = false
    for _, q in pairs(queues) do
        local index = contains(q.members, playerId)
        if index then
            table.remove(q.members, index)
            squads[playerId] = nil
            refreshCrews(q)
            found = true
        end
    end
    for squadId, crew in pairs(crews) do
        local index = contains(crew.members, playerId)
        if index then
            table.remove(crew.members, index)
            if #crew.members == 0 then crews[squadId] = nil end
            found = true
        end
    end
    for key, m in pairs(matches) do
        local index = contains(m.members, playerId)
        if index then
            table.remove(m.members, index)
            -- no longer waited for either
            local expected = contains(m.expected, playerId)
            if expected then table.remove(m.expected, expected) end
            if #m.members == 0 then matches[key] = nil end
            found = true
        end
    end
    squads[playerId] = nil
    unranked[playerId] = nil
    if found then L.hooks.changed() end
    return found
end

-- ---------------------------------------------------------------- courses --

-- The course a time trial or a race vs AI runs: the one asked for, else the one this
-- player chose last, else the first of the catalogue.
local function courseFor(def, playerId, options)
    local remembered = lastCourse[def.mode] or {}
    local wanted = type(options) == "table" and (options.course or options.courseId) or nil
    if type(wanted) == "string" then
        local course = RaceCourses.get(wanted)
        if course and RaceCourses.eligible(course, def.mode) then return course end
        if course and def.mode == "pve" then return nil, "That course cannot be raced against AI." end
        return nil, "That course does not exist."
    end
    local previous = remembered[playerId] and RaceCourses.get(remembered[playerId])
    if previous and RaceCourses.eligible(previous, def.mode) then return previous end
    local ids = RaceCourses.ids(def.mode)
    if #ids == 0 then return nil, REASONS.course_unavailable end
    return RaceCourses.get(ids[1])
end

-- The course a parkour join asked for (nil when it asked for none), or nil and a sentence.
local function chosenCourse(def, options)
    local wanted = type(options) == "table" and (options.course or options.courseId) or nil
    if wanted == nil then return nil end
    local course = type(wanted) == "string" and RaceCourses.get(wanted) or nil
    if course and RaceCourses.eligible(course, def.mode) then return course end
    return nil, "That course does not exist."
end

-- The stored choice of a heat or a match, if it can still be raced.
local function heatCourse(def, id)
    local course = id and RaceCourses.get(id) or nil
    return course and RaceCourses.eligible(course, def.mode) and course or nil
end

-- ---------------------------------------------------------------- vs AI --

local function aiAvailable() return RaceBots ~= nil and RaceBots.capable(false) end

local function bounded(value, low, high, fallback)
    local n = tonumber(value)
    if n == nil or n ~= n then return fallback end
    return math.max(low, math.min(high, n))
end

-- The difficulty a race vs AI join carries (Light RP: options.difficulty + options.scaling
-- = { enemies, health, damage, ai }), or nil (no pick: the race plays as configured).
local function difficultyOf(options)
    if type(options) ~= "table" then return nil end
    local scaling = type(options.scaling) == "table" and options.scaling or nil
    local id = type(options.difficulty) == "string" and options.difficulty:sub(1, 24) or nil
    if scaling == nil and id == nil then return nil end
    return { id = id, scaling = scaling or {} }
end
L.difficultyOf = difficultyOf

-- How the AI drivers play a difficulty (Config.pve): `damage` sets their pace (top speed
-- ceiling), `ai` their driving profile; `health` has nothing to scale in a race (the AI
-- drivers are invulnerable and nobody fights). nil without a difficulty.
local function botTuning(difficulty)
    if difficulty == nil then return nil end
    local pve = type(Config.pve) == "table" and Config.pve or {}
    local scaling = difficulty.scaling
    local profiles = type(pve.profiles) == "table" and pve.profiles or {}
    local profile = profiles[tostring(scaling.ai or "standard")] or profiles.standard or {}
    local car = type(Config.bots) == "table" and type(Config.bots.car) == "table" and Config.bots.car or {}
    local damage = bounded(scaling.damage, 0.25, 4, 1)
    local pace = math.max(0.25, 1 + (damage - 1) * bounded(pve.pacePerDamage, 0, 4, 0.8))
    local speed = math.min(bounded(pve.maxSpeed, 0.5, 55, 50), bounded(car.speed, 0.5, 55, 30) * pace)
    return {
        speed = math.floor(speed * 10 + 0.5) / 10,
        behavior = profile.behavior, arrivalRadius = profile.arrivalRadius,
        checkpointRadiusBonus = profile.checkpointRadiusBonus,
    }
end
L.botTuning = botTuning

-- Racers in total for a race vs AI: pve.fillTo, the AI share scaled by the difficulty's
-- `enemies` (rounded), within the course's grid.
local function pveFillTo(capacity, players, difficulty)
    local pve = type(Config.pve) == "table" and Config.pve or {}
    local fillTo = math.min(capacity, math.floor(tonumber(pve.fillTo) or capacity))
    if difficulty == nil then return fillTo end
    local ai = math.max(0, fillTo - players)
    ai = math.floor(ai * bounded(difficulty.scaling.enemies, 0, 4, 1) + 0.5)
    return math.min(capacity, players + ai)
end
L.pveFillTo = pveFillTo

-- Starts a race vs AI for these players (one, or a crew). The grid takes as many as the
-- course has slots; AI drivers fill it up to pve.fillTo (scaled by the difficulty).
-- Returns true, or false and a sentence.
local function startPve(def, playerIds, options, chooser, difficulty)
    local course, why = courseFor(def, chooser or playerIds[1], options)
    if course == nil then return false, why end
    -- alone and no AI: that would be a time trial without its board
    if #playerIds == 1 and not aiAvailable() then return false, REASONS.no_ai end
    local capacity = RaceCourses.capacity(course, def.maxPlayers)
    local take = {}
    for _, playerId in ipairs(playerIds) do
        if #take < capacity then
            take[#take + 1] = playerId
        else
            L.hooks.notice(playerId, "error", def.label, "Your crew is bigger than this course's grid: you were left out.")
        end
    end
    for _, playerId in ipairs(take) do lastCourse.pve[playerId] = course.id end
    local inst, reason = E.start(def, course, take, {
        fillTo = pveFillTo(capacity, #take, difficulty), unranked = unrankedOf(take),
        difficulty = difficulty and difficulty.id or nil, botTuning = botTuning(difficulty),
    })
    if inst == nil then return false, sentence(reason) end
    return true
end

local function crewComplete(crew)
    for _, playerId in ipairs(crew.expected) do
        if not contains(crew.members, playerId) and connected(playerId) and not E.busy(playerId) then return false end
    end
    return true
end

local function launchCrew(crew)
    if crews[crew.id] == crew then crews[crew.id] = nil end
    local members = {}
    for _, playerId in ipairs(crew.members) do
        if connected(playerId) and not E.busy(playerId) then members[#members + 1] = playerId end
    end
    if #members == 0 then return false, "nobody_left" end
    -- the leader's choice of course when the leader came; else the first to join
    local chooser = (crew.leader and contains(members, crew.leader)) and crew.leader or members[1]
    local ok, why = startPve(crew.def, members, crew.options, chooser, crew.difficulty)
    if not ok then
        for _, playerId in ipairs(members) do L.hooks.notice(playerId, "error", crew.def.label, why) end
    end
    L.hooks.changed()
    return ok, why
end

local function joinPve(def, playerId, options)
    local squad = squadOf(options, playerId)
    if squad == nil then return startPve(def, { playerId }, options, nil, difficultyOf(options)) end
    local crew = crews[squad.id]
    if crew == nil then
        crew = { id = squad.id, def = def, members = {}, expected = squad.expected, leader = squad.leader, at = E.nowMs() }
        crews[squad.id] = crew
    end
    if not contains(crew.members, playerId) then crew.members[#crew.members + 1] = playerId end
    if crew.options == nil or squad.leader == playerId then crew.options = options end
    -- one difficulty per race: the first one a crew join carries, never mixed
    if crew.difficulty == nil then crew.difficulty = difficultyOf(options) end
    if crewComplete(crew) then
        launchCrew(crew)
    else
        -- No "waiting for your crew" notice: Light RP's queue panel shows the crew gathering.
        L.hooks.changed()
    end
    return true
end

-- ---------------------------------------------------------------- matches --

-- The match Light RP formed for this join (options.match = { id, friendly, ranked,
-- players... }), or nil. Only street and rooftop races play matches; elsewhere the key
-- is ignored. Ranked only when Light RP says so (options.ranked / match.ranked true) and
-- nothing says otherwise: a friendly or AI-filled match is unranked, and so is a match
-- from a core that does not say.
local function matchOf(options, playerId)
    local m = type(options) == "table" and options.match or nil
    if type(m) ~= "table" or m.id == nil then return nil end
    local id = tostring(m.id):sub(1, 64)
    if id == "" then return nil end
    local expected = {}
    for _, member in ipairs(type(m.players) == "table" and m.players or {}) do
        local raw = type(member) == "table" and (member.id or member.playerId) or member
        local memberId = math.tointeger(tonumber(raw))
        if memberId and memberId > 0 and not contains(expected, memberId) then expected[#expected + 1] = memberId end
        if #expected >= 64 then break end
    end
    if not contains(expected, playerId) then expected[#expected + 1] = playerId end
    local friendly = m.friendly == true
    local ranked = (options.ranked == true or m.ranked == true) and options.ranked ~= false and m.ranked ~= false
        and not friendly
    return { id = id, friendly = friendly, ranked = ranked, expected = expected }
end
L.matchOf = matchOf

-- AI racers a match join asks for: options.fill (a race has no sides, every bot is an
-- opponent: enemies + allies), else a team shape's per-team bots. The same on every
-- join of the match: the largest is kept, never added up per player.
local function fillOf(options)
    local fill = type(options) == "table" and options.fill or nil
    local n = 0
    if type(fill) == "table" then n = count(fill.enemies) + count(fill.allies) end
    local m = type(options) == "table" and type(options.match) == "table" and options.match or nil
    if n == 0 and m and type(m.bots) == "table" then
        for _, perTeam in ipairs(m.bots) do n = n + count(perTeam) end
    end
    return math.min(n, 64)
end
L.fillOf = fillOf

-- Every listed player is here, or will not come (gone, racing elsewhere).
local function matchComplete(m)
    for _, playerId in ipairs(m.expected) do
        if not contains(m.members, playerId) and connected(playerId) and not E.busy(playerId) then return false end
    end
    return true
end

-- AI racers a match gets: what it asked for, within the course and matches.fillTo, and
-- none on a server that cannot put bots of that kind on the course. A ranked match is
-- humans only: never any.
local function matchBots(m, def, capacity, players)
    if m.fill <= 0 or def.noBots then return 0 end
    if m.ranked then
        log(("%s match %s is ranked: its fill (%d) is ignored"):format(def.id, m.id, m.fill))
        return 0
    end
    local caps = type(Config.matches) == "table" and type(Config.matches.fillTo) == "table" and Config.matches.fillTo or {}
    local total = math.min(capacity, math.floor(tonumber(caps[def.mode]) or capacity))
    local room = math.max(0, total - players)
    if room == 0 then return 0 end
    if RaceBots == nil or not RaceBots.capable(def.mode == "foot") then return 0, "no_ai" end
    return math.min(m.fill, room)
end

-- Starts the match's own heat with whoever made it.
local function launchMatch(m)
    if matches[m.key] == m then matches[m.key] = nil end
    launched[m.key] = E.nowMs()
    local def = m.def
    local members = {}
    for _, playerId in ipairs(m.members) do
        if connected(playerId) and not E.busy(playerId) then members[#members + 1] = playerId end
    end
    if #members == 0 then
        L.hooks.changed()
        return false, "nobody_left"
    end
    local course = heatCourse(def, m.course) or RaceCourses.pick(def.mode, lastMatchCourse[def.key])
    if course == nil then
        for _, playerId in ipairs(members) do
            L.hooks.notice(playerId, "error", def.label, REASONS.course_unavailable)
            releaseQueued(def, playerId)
        end
        L.hooks.changed()
        return false, "course_unavailable"
    end
    local capacity = RaceCourses.capacity(course, def.maxPlayers)
    local take = {}
    for _, playerId in ipairs(members) do
        if #take < capacity then
            take[#take + 1] = playerId
        else
            L.hooks.notice(playerId, "error", def.label, "Your match is bigger than this course's grid: you were left out.")
            releaseQueued(def, playerId)
        end
    end
    local bots, why = matchBots(m, def, capacity, #take)
    if why == "no_ai" then
        for _, playerId in ipairs(take) do
            L.hooks.notice(playerId, "info", def.label, "No AI racer is available on this server: the match races without them.")
        end
    end
    lastMatchCourse[def.key] = course.id
    -- unranked: every racer of it; ranked: raced and recorded like a heat of our queue
    local set = {}
    if not m.ranked then
        for _, playerId in ipairs(take) do set[playerId] = true end
    end
    local inst, reason = E.start(def, course, take, {
        fillTo = bots > 0 and (#take + bots) or nil, match = m.id, friendly = m.friendly, unranked = set,
    })
    if inst == nil then
        log(("%s match %s launch failed: %s"):format(def.id, m.id, tostring(reason)))
        for _, playerId in ipairs(take) do
            L.hooks.notice(playerId, "error", def.label, sentence(reason))
            releaseQueued(def, playerId)
        end
    elseif m.ranked then
        for _, playerId in ipairs(inst.members) do L.hooks.notice(playerId, "info", def.label, "Ranked match: the race is on.") end
    elseif RaceBots == nil or RaceBots.count(inst) == 0 then
        -- with AI racers, their notice already says unranked
        local text = m.friendly and "Friendly match: unranked, nothing is recorded."
            or "Unranked match: nothing is recorded."
        for _, playerId in ipairs(inst.members) do L.hooks.notice(playerId, "info", def.label, text) end
    end
    L.hooks.changed()
    return inst ~= nil, reason
end
L.launchMatch = launchMatch

local function joinMatch(def, playerId, options, info)
    local key = def.key .. "|" .. info.id
    if launched[key] then
        releaseQueued(def, playerId)
        return false, "Your match has already started without you."
    end
    local m = matches[key]
    if m == nil then
        m = { key = key, id = info.id, def = def, expected = info.expected, members = {}, fill = 0,
            friendly = info.friendly, ranked = info.ranked, course = info.course, at = E.nowMs() }
        matches[key] = m
    elseif not contains(m.expected, playerId) then
        -- every join of a match lists the same players: the first one's list holds (a
        -- member who left it is not waited for again)
        m.expected[#m.expected + 1] = playerId
    end
    if not contains(m.members, playerId) then m.members[#m.members + 1] = playerId end
    m.course = m.course or info.course
    m.fill = math.max(m.fill, fillOf(options))
    -- the others' joins arrive in the same tick: no notice while gathering
    if matchComplete(m) then launchMatch(m) else L.hooks.changed() end
    return true
end

-- ---------------------------------------------------------------- join --

-- The player joins an activity of ours. The caller has checked eligibility (the core
-- before its join event, our commands before calling this). Returns true, or false
-- and a sentence for the player.
function L.join(playerId, def, options)
    if def == nil then return false, "Unknown race." end
    if E.busy(playerId) then return false, "You are already in a race." end
    local current = L.queuedIn(playerId)
    local gathering = L.matchIn(playerId)
    local chosen
    if def.mode == "parkour" then
        local refused
        if RaceParkour == nil or not RaceParkour.available() then refused = "Parkour races are not available right now." end
        if refused == nil then chosen, refused = chosenCourse(def, options) end
        if refused then
            if current == nil then releaseQueued(def, playerId) end
            return false, refused
        end
    end
    -- a match Light RP formed: its own heat, out of any queue of ours
    local match = def.queued and matchOf(options, playerId) or nil
    if match then
        if def.unranked then match.ranked = false end
        match.course = chosen and chosen.id or nil
        if gathering and gathering.def == def and gathering.id == match.id then return true end
        if current ~= nil then L.leave(playerId) end
        if #RaceCourses.ids(def.mode) == 0 then return false, REASONS.course_unavailable end
        return joinMatch(def, playerId, options, match)
    end
    if current == def.key and gathering == nil then return true end
    if current ~= nil then L.leave(playerId) end
    unranked[playerId] = (type(options) == "table" and options.ranked == false) or nil
    if def.mode == "trial" then
        local course, why = courseFor(def, playerId, options)
        if course == nil then return false, why end
        lastCourse.trial[playerId] = course.id
        local inst, reason = E.start(def, course, { playerId }, { unranked = unrankedOf({ playerId }) })
        if inst == nil then return false, sentence(reason) end
        return true
    end
    if def.mode == "pve" then return joinPve(def, playerId, options) end
    if #RaceCourses.ids(def.mode) == 0 then return false, REASONS.course_unavailable end
    local q = queue(def.key)
    q.members[#q.members + 1] = playerId
    if chosen and q.course == nil then
        q.course = chosen.id
    elseif chosen and q.course ~= chosen.id then
        local heat = heatCourse(def, q.course)
        L.hooks.notice(playerId, "info", def.label, ("This heat runs %s: the first choice in the queue sets it."):format(heat and heat.name or q.course))
    end
    local squad = squadOf(options, playerId)
    squads[playerId] = squad
    if squad and q.crews[squad.id] == nil then q.crews[squad.id] = E.nowMs() end
    -- No "you are in the queue" notice: Light RP answers the panel's join and its queue
    -- panel shows the grid filling (/race.join replies in chat). Staff bot mode is not on
    -- the panel: that sentence alone is told, once the grid would go.
    if #q.members >= L.minimum(def) and botsHere(def) then
        L.hooks.notice(playerId, "info", def.label, "Bot mode: bots fill the grid. Nothing is recorded.")
    end
    L.hooks.changed()
    return true
end

-- Picks the course, re-checks every queued player in order, and starts the grid with
-- as many eligible players as the course takes; the rest wait for the next heat. A crew
-- goes whole or waits whole. force (staff /race.force): start even below the minimum.
function L.launch(def, now, force)
    local minimum = force and 1 or L.minimum(def)
    local q = queue(def.key)
    q.windowEndsAt = nil
    local course = heatCourse(def, q.course) or RaceCourses.pick(def.mode, q.lastCourse)
    if course == nil then
        for _, playerId in ipairs(q.members) do L.hooks.notice(playerId, "error", def.label, REASONS.course_unavailable) end
        return false, "course_unavailable"
    end
    local capacity = RaceCourses.capacity(course, def.maxPlayers)
    local chosen, rest = {}, {}
    for _, block in ipairs(blocks(q)) do
        if #chosen > 0 and #chosen + #block > capacity then
            -- does not fit beside the others: waits whole for the next heat
            for _, playerId in ipairs(block) do rest[#rest + 1] = playerId end
        else
            local eligible = {}
            for _, playerId in ipairs(block) do
                if not connected(playerId) or E.busy(playerId) then
                    squads[playerId] = nil -- gone, or already racing elsewhere: silently out of the queue
                else
                    local ok, why = A.check(playerId, def.id)
                    if ok then
                        eligible[#eligible + 1] = playerId
                    else
                        squads[playerId] = nil
                        L.hooks.notice(playerId, "error", def.label, tostring(why) .. " You left the queue.")
                    end
                end
            end
            for _, playerId in ipairs(eligible) do
                if #chosen < capacity then
                    chosen[#chosen + 1] = playerId
                else
                    -- only a crew bigger than the whole grid gets here
                    rest[#rest + 1] = playerId
                    L.hooks.notice(playerId, "info", def.label, "Your crew is bigger than this grid: you wait for the next race.")
                end
            end
        end
    end
    if #chosen < minimum then
        -- Not enough eligible racers right now: they keep their place.
        for index = #chosen, 1, -1 do table.insert(rest, 1, chosen[index]) end
        q.members = rest
        refreshCrews(q)
        for _, playerId in ipairs(q.members) do
            L.hooks.notice(playerId, "info", def.label, "Not enough racers are ready. You stay in the queue.")
        end
        L.hooks.changed()
        return false, "not_enough_players"
    end
    q.members = rest
    for _, playerId in ipairs(chosen) do squads[playerId] = nil end
    refreshCrews(q)
    q.lastCourse = course.id
    q.course = nil
    q.botWindow = nil
    local fillTo = botFill(def, capacity)
    local inst, reason = E.start(def, course, chosen, { fillTo = fillTo, unranked = unrankedOf(chosen) })
    if inst == nil then
        log(("%s launch failed: %s"):format(def.id, tostring(reason)))
        for _, playerId in ipairs(chosen) do L.hooks.notice(playerId, "error", def.label, sentence(reason)) end
    end
    L.hooks.changed()
    return inst ~= nil, reason
end

function L.tick(now)
    now = now or E.nowMs()
    for _, def in ipairs(Config.activities) do
        if def.queued then
            local q = queue(def.key)
            local pruned = false
            for index = #q.members, 1, -1 do
                local playerId = q.members[index]
                if not connected(playerId) or E.busy(playerId) then
                    table.remove(q.members, index)
                    squads[playerId] = nil
                    pruned = true
                end
            end
            if pruned then refreshCrews(q) end
            local count = #q.members
            if count >= L.minimum(def) then
                if q.windowEndsAt == nil then
                    local window = joinSeconds(def)
                    q.windowEndsAt = now + math.floor(window * 1000)
                    -- opened by bot mode alone: closing it later says why
                    q.botWindow = count < def.minPlayers or nil
                    for _, playerId in ipairs(q.members) do
                        L.hooks.notice(playerId, "info", def.label,
                            ("Grid forming: the race starts in %d seconds."):format(math.floor(window)))
                    end
                    L.hooks.changed()
                end
                if count >= def.maxPlayers then
                    q.windowEndsAt = math.min(q.windowEndsAt, now + math.floor((def.fullSeconds or 5) * 1000))
                end
                -- a crew still arriving holds the launch (gatherSeconds at most)
                if now >= q.windowEndsAt and not gathering(q, now) then L.launch(def, now) end
            elseif q.windowEndsAt ~= nil then
                q.windowEndsAt = nil
                local text = (q.botWindow and not L.botMode()) and "Bot mode is off. Waiting for more racers."
                    or "A racer left. Waiting for more."
                q.botWindow = nil
                for _, playerId in ipairs(q.members) do
                    L.hooks.notice(playerId, "info", def.label, text)
                end
                L.hooks.changed()
            end
        end
    end
    -- crews gathering for a race vs AI: go once complete, or when the wait is over
    for squadId, crew in pairs(crews) do
        for index = #crew.members, 1, -1 do
            local playerId = crew.members[index]
            if not connected(playerId) or E.busy(playerId) then table.remove(crew.members, index) end
        end
        if #crew.members == 0 then
            crews[squadId] = nil
        elseif crewComplete(crew) or now - crew.at >= gatherMs() then
            launchCrew(crew)
        end
    end
    -- matches: go once every listed player is in, or with whoever made it after the wait
    for key, m in pairs(matches) do
        for index = #m.members, 1, -1 do
            local playerId = m.members[index]
            if not connected(playerId) or E.busy(playerId) then table.remove(m.members, index) end
        end
        if #m.members == 0 then
            matches[key] = nil
            L.hooks.changed()
        elseif matchComplete(m) or now - m.at >= matchGatherMs() then
            launchMatch(m)
        end
    end
    for key, at in pairs(launched) do
        if now - at >= LAUNCHED_KEEP_MS then launched[key] = nil end
    end
end

function L.forget(playerId)
    L.leave(playerId)
    unranked[playerId] = nil
    for _, remembered in pairs(lastCourse) do remembered[playerId] = nil end
end

function L.clear()
    for key in pairs(queues) do queues[key] = nil end
    for squadId in pairs(crews) do crews[squadId] = nil end
    for playerId in pairs(squads) do squads[playerId] = nil end
    for key in pairs(matches) do matches[key] = nil end
    for key in pairs(launched) do launched[key] = nil end
    for playerId in pairs(unranked) do unranked[playerId] = nil end
end
