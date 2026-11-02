-- Admission. A time trial starts at once (one racer, one instance). Street and
-- rooftop races queue: once the minimum is waiting, a join window opens (later
-- arrivals do not restart it), a full grid shortens it, and at its end every queued
-- player is re-checked with activityCheck before the instance starts. Queued players
-- are not owned by Light RP yet: they keep playing until the launch.
local Config = RaceConfig
local A = RaceActivity
local E = RaceEngine

RaceLobby = {}
local L = RaceLobby

local queues = {}   -- activity key -> { members = { playerId... }, windowEndsAt, lastCourse }
L.queues = queues
local trialCourse = {} -- playerId -> last course chosen for a trial (a later join without one reuses it)

local noop = function() end
L.hooks = {
    notice = noop,   -- (playerId, kind, title, text)
    changed = noop,  -- () queue or instances changed: status and menus
}

local function log(text) print("[race:lobby] " .. tostring(text)) end
local function connected(playerId) return Open77.players.name(playerId) ~= nil end

local function queue(key)
    local q = queues[key]
    if q == nil then
        q = { members = {} }
        queues[key] = q
    end
    return q
end

function L.queuedIn(playerId)
    for key, q in pairs(queues) do
        for index, memberId in ipairs(q.members) do
            if memberId == playerId then return key, index end
        end
    end
    return nil
end

function L.size(key)
    local q = queues[key]
    return q and #q.members or 0
end

function L.windowRemainingMs(key, now)
    local q = queues[key]
    if q == nil or q.windowEndsAt == nil then return nil end
    return math.max(0, q.windowEndsAt - (now or E.nowMs()))
end

-- Removes a player from any queue. Returns true when they were queued.
function L.leave(playerId)
    local key, index = L.queuedIn(playerId)
    if key == nil then return false end
    table.remove(queues[key].members, index)
    L.hooks.changed()
    return true
end

local REASONS = {
    no_free_bucket = "Every race instance is in use. Try again in a moment.",
    nobody_admitted = "You could not be admitted.",
    course_unavailable = "No course is available for this race.",
}
local function sentence(reason) return REASONS[reason] or "The race could not start." end

local function trialCourseFor(playerId, options)
    local wanted = type(options) == "table" and (options.course or options.courseId) or nil
    if type(wanted) == "string" then
        local course = RaceCourses.get(wanted)
        if course and RaceCourses.eligible(course, "trial") then return course end
        return nil, "That course does not exist."
    end
    local remembered = trialCourse[playerId] and RaceCourses.get(trialCourse[playerId])
    if remembered then return remembered end
    local ids = RaceCourses.ids("trial")
    if #ids == 0 then return nil, REASONS.course_unavailable end
    return RaceCourses.get(ids[1])
end

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
        local course, why = trialCourseFor(playerId, options)
        if course == nil then return false, why end
        trialCourse[playerId] = course.id
        local inst, reason = E.start(def, course, { playerId })
        if inst == nil then return false, sentence(reason) end
        return true
    end
    if #RaceCourses.ids(def.mode) == 0 then return false, REASONS.course_unavailable end
    local q = queue(def.key)
    q.members[#q.members + 1] = playerId
    local waiting = #q.members
    if waiting < def.minPlayers then
        L.hooks.notice(playerId, "info", def.label,
            ("You are in the queue. Waiting for %d more."):format(def.minPlayers - waiting))
    else
        L.hooks.notice(playerId, "info", def.label, "You are in the queue. The race starts soon.")
    end
    L.hooks.changed()
    return true
end

-- Picks the course, re-checks every queued player in order, and starts the grid with
-- as many eligible players as the course takes; the rest wait for the next heat.
-- force (staff /race.force): start even below the minimum.
function L.launch(def, now, force)
    local minimum = force and 1 or def.minPlayers
    local q = queue(def.key)
    q.windowEndsAt = nil
    local course = RaceCourses.pick(def.mode, q.lastCourse)
    if course == nil then
        for _, playerId in ipairs(q.members) do L.hooks.notice(playerId, "error", def.label, REASONS.course_unavailable) end
        return false, "course_unavailable"
    end
    local capacity = RaceCourses.capacity(course, def.maxPlayers)
    local chosen, rest = {}, {}
    for _, playerId in ipairs(q.members) do
        if #chosen >= capacity then
            rest[#rest + 1] = playerId
        elseif not connected(playerId) or E.busy(playerId) then
            -- gone, or already racing elsewhere: silently out of the queue
        else
            local ok, why = A.check(playerId, def.id)
            if ok then
                chosen[#chosen + 1] = playerId
            else
                L.hooks.notice(playerId, "error", def.label, tostring(why) .. " You left the queue.")
            end
        end
    end
    if #chosen < minimum then
        -- Not enough eligible racers right now: they keep their place.
        for index = #chosen, 1, -1 do table.insert(rest, 1, chosen[index]) end
        q.members = rest
        for _, playerId in ipairs(q.members) do
            L.hooks.notice(playerId, "info", def.label, "Not enough racers are ready. You stay in the queue.")
        end
        L.hooks.changed()
        return false, "not_enough_players"
    end
    q.members = rest
    q.lastCourse = course.id
    local inst, reason = E.start(def, course, chosen)
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
        if def.mode ~= "trial" then
            local q = queue(def.key)
            for index = #q.members, 1, -1 do
                local playerId = q.members[index]
                if not connected(playerId) or E.busy(playerId) then table.remove(q.members, index) end
            end
            local count = #q.members
            if count >= def.minPlayers then
                if q.windowEndsAt == nil then
                    q.windowEndsAt = now + math.floor((def.joinSeconds or 30) * 1000)
                    for _, playerId in ipairs(q.members) do
                        L.hooks.notice(playerId, "info", def.label,
                            ("Grid forming: the race starts in %d seconds."):format(def.joinSeconds or 30))
                    end
                    L.hooks.changed()
                end
                if count >= def.maxPlayers then
                    q.windowEndsAt = math.min(q.windowEndsAt, now + math.floor((def.fullSeconds or 5) * 1000))
                end
                if now >= q.windowEndsAt then L.launch(def, now) end
            elseif q.windowEndsAt ~= nil then
                q.windowEndsAt = nil
                for _, playerId in ipairs(q.members) do
                    L.hooks.notice(playerId, "info", def.label, "A racer left. Waiting for more.")
                end
                L.hooks.changed()
            end
        end
    end
end

function L.forget(playerId)
    L.leave(playerId)
    trialCourse[playerId] = nil
end

function L.clear()
    for key in pairs(queues) do queues[key] = nil end
end
