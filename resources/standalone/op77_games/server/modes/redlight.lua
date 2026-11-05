-- Red Light, Green Light: run for the finish on green, stop on red. Moving under a red light
-- sends you back to the start line (not out); a death does the same. Every finisher wins; at
-- the clock (the map's time limit) whoever has not crossed is out. No weapons, nobody hurts
-- anybody, no play area: the course is the whole map.
--
-- The server decides everything and reads positions itself; no client says anything here. The
-- lights go out by HUD, sound and a screen flinch on the one sent back.
--
-- Lag must not punish. A client hears "red" half a round trip late and its stop reaches us half
-- a round trip later, so the 0.4 s reaction grace grows by the measured ping (capped). A reading
-- dated from before the grace ended never counts; an unreadable or stale one freezes the check;
-- the first reading after such a gap, once per red light, is a new anchor (not a conviction of
-- the catch-up jump); and one reading over the line is not enough: `strikes` in a row are.
local E = GamesEngine

local RL = {
    limit = 90, minClock = 30, maxClock = 600, -- the map's time limit, within these (s)
    greenMin = 4, greenMax = 10, -- a green light's random length (s)
    redMin = 3, redMax = 6,      -- a red light's random length (s)
    grace = 0.4,                 -- reaction time after the switch to red (s)
    maxLagMs = 300,              -- at most this much ping is added to it
    tolerance = 0.35,            -- metres a body may drift on the ground under a red light
    lift = 0.8,                  -- metres up or down it may settle (a landing)
    strikes = 2,                 -- readings in a row over the line before it counts
    staleMs = 500,               -- a reading older than this cannot judge anyone
    respawnMs = 2000,
}

GamesRedlight = { rules = RL }
local G = GamesRedlight

-- The length (s) of the next light, drawn afresh each time. `rnd` (0..1) is for the tests.
function G.duration(light, rnd)
    rnd = rnd or math.random()
    if light == "red" then return RL.redMin + (RL.redMax - RL.redMin) * rnd end
    return RL.greenMin + (RL.greenMax - RL.greenMin) * rnd
end

-- The course from a map: its start (the spawns' mean), the unit direction to the finish on
-- the ground and the distance to it.
function G.course(map)
    local start = { x = 0, y = 0, z = 0 }
    for _, p in ipairs(map.spawns) do
        start.x, start.y, start.z = start.x + p.x / #map.spawns, start.y + p.y / #map.spawns, start.z + p.z / #map.spawns
    end
    local dx, dy = map.finish.x - start.x, map.finish.y - start.y
    local length = math.sqrt(dx * dx + dy * dy)
    return { start = start, dx = dx / length, dy = dy / length, length = length }
end

-- Metres run along the course (past `length`: across the finish line), never below 0.
function G.progress(course, at)
    return math.max(0, (at.x - course.start.x) * course.dx + (at.y - course.start.y) * course.dy)
end

-- How long after the switch to red a body is judged, for this player's lag.
function G.graceMs(playerId)
    local ping = type(Open77.players.ping) == "function" and tonumber((Open77.players.ping(playerId))) or 0
    return RL.grace * 1000 + math.min(ping or 0, RL.maxLagMs)
end

local function switch(match, t, light)
    local rl = match.rl
    rl.light, rl.since = light, t
    rl.untilT = t + math.floor(G.duration(light) * 1000)
    if light == "red" then
        rl.cycle = rl.cycle + 1
        E.banner(match, "RED LIGHT", "Do not move.", "danger", 2000)
        E.cue(match, "red")
    else
        E.banner(match, "GREEN LIGHT", "Run.", "success", 1500)
        E.cue(match, "green")
    end
    for _, p in pairs(match.players) do
        local state = p.rl
        state.anchor, state.strikes, state.gap = nil, 0, nil
    end
end

local function shoot(match, p)
    local state = p.rl
    state.progress, state.anchor, state.strikes = 0, nil, 0
    state.resets = state.resets + 1
    p.deaths = p.deaths + 1
    pcall(Open77.effects.screen, p.id, "pain", {})
    E.cue(p.id, "hit")
    E.banner(p.id, "YOU MOVED", "Back to the start.", "danger", 2000)
    E.feed(match, p.name .. " moved on red: back to the start", "danger")
    E.sendBack(match, p, function()
        state.progress, state.anchor, state.strikes = 0, nil, 0
    end)
end

local function qualify(match, p, t)
    local rl, state = match.rl, p.rl
    rl.finished = rl.finished + 1
    state.finished, state.place, state.timeMs = true, rl.finished, t - match.startedAt
    E.feed(match, ("%s crossed the line (#%d)"):format(p.name, state.place), "success")
    E.banner(p.id, "FINISHED", ("Place %d"):format(state.place), "success", 3000)
end

-- One body, one reading. Returns nothing: a mover is sent back, a finisher marked.
local function judge(match, p, t)
    local rl, state = match.rl, p.rl
    local read = E.read(p.id)
    if read == nil or read.ageMs > RL.staleMs then
        state.gap = true -- the player's reading froze: anchor and strikes hold, nothing convicts
        return
    end
    if rl.light == "red" and t - read.ageMs >= rl.since + G.graceMs(p.id) then
        if state.gap then
            state.gap = nil
            if state.forgiven ~= rl.cycle then
                state.forgiven, state.anchor, state.strikes = rl.cycle, nil, 0
            end
        end
        local anchor = state.anchor
        if anchor == nil then
            state.anchor, state.strikes = { x = read.x, y = read.y, z = read.z }, 0
        elseif E.flat(anchor, read) > RL.tolerance or math.abs(read.z - anchor.z) > RL.lift then
            state.strikes = state.strikes + 1
            if state.strikes >= RL.strikes then return shoot(match, p) end
        else
            state.strikes = 0
        end
    end
    state.progress = G.progress(rl.course, read)
    if state.progress >= rl.course.length then qualify(match, p, t) end
end

local function rank(a, b)
    local x, y = a.rl, b.rl
    if (x.finished == true) ~= (y.finished == true) then return x.finished == true end
    if x.finished then return x.place < y.place end
    if x.progress ~= y.progress then return x.progress > y.progress end
    return a.id < b.id
end

E.mode({
    id = "games.redlight", key = "redlight", label = "Red Light, Green Light", kind = "event",
    description = "Run on green, freeze on red: move under the red light and you go back to the start. Cross the line before the clock.",
    minPlayers = 1, maxPlayers = 16,
    -- No play area (bounds = false): a map's stored centre and radius are kept, nothing reads them.
    schema = {
        points = {
            { key = "finish", label = "Finish line", color = "#ff4d4d" },
            { key = "centre", label = "Map centre", hidden = true },
        },
        lists = { { key = "spawns", label = "Start line spot", color = "#3ddc84", min = 1, max = 32 } },
        numbers = {
            { key = "timeLimit", label = "Time limit", min = RL.minClock, max = RL.maxClock, default = RL.limit, unit = "s", integer = true },
            { key = "radius", label = "Map radius", min = 10, max = 400, default = 80, unit = "m", hidden = true },
        },
        apart = { { a = "finish", b = "spawns", metres = 5 } }, -- a course with a length
    },
    pvp = false, bounds = false, respawnMs = RL.respawnMs,

    setup = function(match)
        local limit = tonumber(match.map.timeLimit) or RL.limit
        match.seconds = math.min(RL.maxClock, math.max(RL.minClock, limit))
        match.rl = { course = G.course(match.map), cycle = 0, finished = 0, light = "ready", nextSpawn = 0 }
        for _, p in pairs(match.players) do p.rl = { progress = 0, resets = 0, strikes = 0 } end
    end,

    -- The start line, one spawn after the other.
    spawnFor = function(match)
        local rl, spawns = match.rl, match.map.spawns
        rl.nextSpawn = rl.nextSpawn + 1
        return spawns[(rl.nextSpawn - 1) % #spawns + 1], 0.5
    end,

    start = function(match) switch(match, E.now(), "green") end,

    tick = function(match, t)
        local rl = match.rl
        if t >= rl.untilT then switch(match, t, rl.light == "green" and "red" or "green") end
        local running = 0
        for _, p in ipairs(E.members(match)) do
            if not p.rl.finished then
                running = running + 1
                if p.alive and t >= p.holdUntil then
                    judge(match, p, t)
                    if p.rl.finished then running = running - 1 end
                end
            end
        end
        if running == 0 then E.finish(match, "decided") end
    end,

    -- A death is no elimination: the progress is lost, the engine respawns the body on the line.
    killed = function(_, victim)
        local state = victim.rl
        if state.finished then return end
        state.progress, state.anchor, state.strikes = 0, nil, 0
        state.resets = state.resets + 1
    end,

    hud = function(match, p, view)
        local rl, state = match.rl, p.rl
        local length = rl.course.length
        if rl.light == "red" then view.objective = "RED LIGHT: do not move"
        elseif rl.light == "green" then view.objective = "GREEN LIGHT: run"
        else view.objective = "Reach the finish line" end
        view.progress = { { id = "course", label = "Course", value = math.min(1, state.progress / length),
            tone = rl.light == "red" and "danger" or "success" } }
        view.stats = {
            { label = "Left", value = ("%d m"):format(math.max(0, math.ceil(length - state.progress))) },
            { label = "Finished", value = tostring(rl.finished) },
        }
        if state.resets > 0 then view.stats[3] = { label = "Sent back", value = tostring(state.resets) } end
        if state.finished then view.objective = ("Finished: place %d"):format(state.place) end
    end,

    results = function(match)
        local ranking, finishers = {}, 0
        for _, p in pairs(match.roster) do
            local state = p.rl
            p.won = state.finished == true
            if p.won then finishers = finishers + 1 end
            p.score = math.floor(state.progress)
            p.row = { outcome = p.won and "finished" or "out", timeMs = state.timeMs, busts = state.resets }
            ranking[#ranking + 1] = p
        end
        table.sort(ranking, rank)
        return {
            ranking = ranking,
            lines = { { label = "Finished", value = ("%d of %d"):format(finishers, #ranking) } },
            columns = { "placement", "timeMs", "busts", "score" },
        }
    end,
})
