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
local crews = {}    -- squad id -> { id, def, members, expected, leader, options, at } gathering for a race vs AI
L.crews = crews

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
    return nil
end

function L.size(key)
    local q = queues[key]
    local n = q and #q.members or 0
    for _, crew in pairs(crews) do
        if crew.def.key == key then n = n + #crew.members end
    end
    return n
end

-- Staff bot mode (RaceActivity.bots): one player is enough to open a queued heat, and
-- the launch fills it with bots. Read live, so switching it off starts no new bot race.
function L.botMode() return A.bots == true end

-- Bot mode on and this server can put bots of that kind on the course (natives present).
-- Without them bot mode changes nothing: no lone heat that nobody joins.
local function botsHere(def)
    return def.queued == true and L.botMode() and RaceBots ~= nil and RaceBots.capable(def.mode == "foot")
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
    squads[playerId] = nil
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

-- ---------------------------------------------------------------- vs AI --

local function aiAvailable() return RaceBots ~= nil and RaceBots.capable(false) end

-- Starts a race vs AI for these players (one, or a crew). The grid takes as many as the
-- course has slots; AI drivers fill it up to pve.fillTo. Returns true, or false and a sentence.
local function startPve(def, playerIds, options, chooser)
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
    local pve = type(Config.pve) == "table" and Config.pve or {}
    local fillTo = math.min(capacity, math.floor(tonumber(pve.fillTo) or capacity))
    local inst, reason = E.start(def, course, take, { fillTo = fillTo })
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
    local ok, why = startPve(crew.def, members, crew.options, chooser)
    if not ok then
        for _, playerId in ipairs(members) do L.hooks.notice(playerId, "error", crew.def.label, why) end
    end
    L.hooks.changed()
    return ok, why
end

local function joinPve(def, playerId, options)
    local squad = squadOf(options, playerId)
    if squad == nil then return startPve(def, { playerId }, options) end
    local crew = crews[squad.id]
    if crew == nil then
        crew = { id = squad.id, def = def, members = {}, expected = squad.expected, leader = squad.leader, at = E.nowMs() }
        crews[squad.id] = crew
    end
    if not contains(crew.members, playerId) then crew.members[#crew.members + 1] = playerId end
    if crew.options == nil or squad.leader == playerId then crew.options = options end
    if crewComplete(crew) then
        launchCrew(crew)
    else
        L.hooks.notice(playerId, "info", def.label, "Waiting for your crew.")
        L.hooks.changed()
    end
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
    if current == def.key then return true end
    if current ~= nil then L.leave(playerId) end
    if def.mode == "trial" then
        local course, why = courseFor(def, playerId, options)
        if course == nil then return false, why end
        lastCourse.trial[playerId] = course.id
        local inst, reason = E.start(def, course, { playerId })
        if inst == nil then return false, sentence(reason) end
        return true
    end
    if def.mode == "pve" then return joinPve(def, playerId, options) end
    if #RaceCourses.ids(def.mode) == 0 then return false, REASONS.course_unavailable end
    local q = queue(def.key)
    q.members[#q.members + 1] = playerId
    local squad = squadOf(options, playerId)
    squads[playerId] = squad
    if squad and q.crews[squad.id] == nil then q.crews[squad.id] = E.nowMs() end
    local waiting = #q.members
    local minimum = L.minimum(def)
    if waiting < minimum then
        L.hooks.notice(playerId, "info", def.label,
            ("You are in the queue. Waiting for %d more."):format(minimum - waiting))
    elseif botsHere(def) then
        L.hooks.notice(playerId, "info", def.label, "Bot mode: bots fill the grid. Nothing is recorded.")
    else
        L.hooks.notice(playerId, "info", def.label, "You are in the queue. The race starts soon.")
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
    local course = RaceCourses.pick(def.mode, q.lastCourse)
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
    q.botWindow = nil
    local fillTo = botFill(def, capacity)
    local inst, reason = E.start(def, course, chosen, fillTo and { fillTo = fillTo } or nil)
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
end

function L.forget(playerId)
    L.leave(playerId)
    for _, remembered in pairs(lastCourse) do remembered[playerId] = nil end
end

function L.clear()
    for key in pairs(queues) do queues[key] = nil end
    for squadId in pairs(crews) do crews[squadId] = nil end
    for playerId in pairs(squads) do squads[playerId] = nil end
end
