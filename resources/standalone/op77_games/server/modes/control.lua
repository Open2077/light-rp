-- Control: one point, two teams. The team alone on the point takes it (more bodies, faster);
-- once it is theirs every second they hold it alone is banked. First to 180 wins, else the
-- leader at the clock. A trailing team still on the point at the clock forces overtime, 30 s at
-- most. Standing in the enemy spawn hurts after a grace and stops your shots. The point and the
-- spawn circles are the server's reading of bodies: no client says anything here.
--
-- The pure rules are GamesControl.count / capture / overtime / guards / camped, on plain tables.
local E = GamesEngine

local C = {
    target = 180,      -- seconds held to win
    seconds = 600,
    respawnMs = 5000,  -- less for a short-handed team, 2 s at least
    radius = 8,        -- the point: a cylinder, radius (m)...
    height = 4,        -- ...and height above the placed spot (m)
    below = 1.5,       -- metres under the spot that still count as on it
    capture = 5,       -- seconds for one body to take the point
    maxRate = 2,       -- capture speed cap (1 body: x1, 2: x1.5, 3+: x2)
    overtime = 30,     -- at most this many seconds past the clock
    matchPoint = 20,   -- "Match point" this close to the target
    spawnGuard = 12,   -- m around each team's spawn the enemy may not camp
    spawnGrace = 2,    -- seconds in the enemy spawn before it hurts
    spawnDamage = 20,  -- a second, after the grace
    boundsMargin = 15, -- m, the play area always covers the spawns and the point by this much
    respawnFloorMs = 2000,
}

GamesControl = { rules = C }
local G = GamesControl

local LABELS = { "Red", "Blue" }
local COLORS = { "danger", "info" }
local RINGS = { [0] = { r = 255, g = 255, b = 255, a = 150 }, { r = 255, g = 70, b = 70, a = 200 }, { r = 70, g = 170, b = 255, a = 200 } }

local function spawnOf(map, side) return side == 1 and map.redSpawn or map.blueSpawn end

-- Whether a body at `at` stands on the point at `pos`.
function G.inside(pos, at)
    local dz = at.z - pos.z
    return E.flat(pos, at) <= C.radius and dz >= -C.below and dz <= C.height
end

function G.newZone(pos)
    return { pos = pos, owner = 0, capturer = 0, progress = 0, contested = false, holder = nil, count = { 0, 0 }, on = { {}, {} } }
end

-- One tick of bodies: `bodies` = { { id, side, at } }, those who can stand on a point.
function G.count(zone, bodies)
    zone.count, zone.on = { 0, 0 }, { {}, {} }
    for _, body in ipairs(bodies) do
        if G.inside(zone.pos, body.at) then
            zone.count[body.side] = zone.count[body.side] + 1
            table.insert(zone.on[body.side], body.id)
        end
    end
    local red, blue = zone.count[1], zone.count[2]
    zone.contested = red > 0 and blue > 0
    zone.holder = (red > 0 and blue == 0 and 1) or (blue > 0 and red == 0 and 2) or nil
end

-- One step of the capture: "held" when its owner stands on it alone (the mode banks), "taken"
-- when it just changed hands, else nil. Contested freezes; the other team's progress goes first.
function G.capture(zone, dt)
    local holder = zone.holder
    local rate = holder and math.min(C.maxRate, 1 + (zone.count[holder] - 1) * 0.5) or 1
    local step = dt * rate / C.capture
    local result
    if zone.contested then
        result = nil
    elseif not holder then
        zone.progress = math.max(0, zone.progress - dt / C.capture)
    elseif holder == zone.owner then
        zone.progress = math.max(0, zone.progress - step)
        result = "held"
    elseif zone.capturer ~= 0 and zone.capturer ~= holder then
        zone.progress = math.max(0, zone.progress - step)
    else
        zone.capturer = holder
        zone.progress = math.min(1, zone.progress + step)
        if zone.progress >= 1 then
            zone.owner, zone.capturer, zone.progress = holder, 0, 0
            result = "taken"
        end
    end
    if zone.progress <= 0 then zone.capturer = 0 end
    return result
end

-- The team ahead on the raw score, nil when level.
function G.leader(score)
    if score[1] == score[2] then return nil end
    return score[1] > score[2] and 1 or 2
end

-- Each team's no-camping circle, never reaching the point.
function G.guards(map)
    local out = {}
    for side = 1, 2 do
        local spawn = spawnOf(map, side)
        local guard = math.min(C.spawnGuard, E.flat(spawn, map.point) - C.radius - 3)
        out[side] = { pos = spawn, radius = guard >= 4 and guard or 0 }
    end
    return out
end

-- The play area covers both spawns and the point.
function G.area(map)
    local area = map.radius
    for _, spot in ipairs({ map.redSpawn, map.blueSpawn, map.point }) do
        area = math.max(area, E.distance(spot, map.centre) + C.boundsMargin)
    end
    return area
end

-- One body against the enemy's circle: `state` keeps the entry and the last sting. Answers
-- true when this tick hurts. `at` nil: dead or unreadable, the circle lets go.
function G.camped(state, guard, at, t)
    if at == nil or guard.radius <= 0 or E.flat(at, guard.pos) > guard.radius then
        state.inSpawn = nil
        return false
    end
    state.inSpawn = state.inSpawn or t
    if t - state.inSpawn < C.spawnGrace * 1000 then return false end
    if state.stungAt and t - state.stungAt < 1000 then return false end
    state.stungAt = t
    return true
end

-- The clock is about to ring with the trailing team on the point: a new deadline, 30 s past the
-- first at most. `zone.count` is this tick's. Nil: nothing changes.
function G.overtime(c, endsAt, t)
    local leader = G.leader(c.score)
    if leader == nil or endsAt - t >= 1000 or c.zone.count[3 - leader] <= 0 then return nil end
    if c.overtimeUntil == nil then c.overtimeUntil = endsAt + C.overtime * 1000 end
    return math.min(t + 1000, c.overtimeUntil)
end

local function hurt(match, p)
    local ok, done, why = pcall(Open77.players.damage, p.id, C.spawnDamage, { cause = "games_spawn_guard" })
    if not ok or done ~= true then E.log(("%s: spawn guard on %d refused: %s"):format(match.id, p.id, tostring(ok and why or done))) end
end

local function teamSize(match, side)
    local n = 0
    for _, p in pairs(match.players) do if p.side == side then n = n + 1 end end
    return n
end

-- ---------------------------------------------------------------- one tick --

local function step(match, t)
    local c = match.control
    local dt = math.min(0.5, (t - (c.lastTick or t)) / 1000)
    c.lastTick = t
    local bodies = {}
    for _, p in ipairs(E.members(match)) do
        local at = p.alive and t >= p.holdUntil and E.read(p.id) or nil
        if at then bodies[#bodies + 1] = { id = p.id, side = p.side, at = at } end
        if G.camped(p.ctl, c.guards[3 - p.side], at, t) then hurt(match, p) end
        p.ctl.onPoint = false
    end
    local zone = c.zone
    G.count(zone, bodies)
    for side = 1, 2 do
        for _, id in ipairs(zone.on[side]) do match.players[id].ctl.onPoint = true end
    end
    local result = G.capture(zone, dt)
    if result == "held" then
        local owner = zone.owner
        c.score[owner] = c.score[owner] + dt
        for _, id in ipairs(zone.on[owner]) do
            local state = match.players[id].ctl
            state.hold = state.hold + dt
        end
    elseif result == "taken" then
        for _, id in ipairs(zone.on[zone.owner]) do
            local state = match.players[id].ctl
            state.takes = state.takes + 1
        end
        E.feed(match, ("%s took the point"):format(LABELS[zone.owner]), COLORS[zone.owner])
        E.banner(match, "POINT TAKEN", LABELS[zone.owner] .. " holds it.", COLORS[zone.owner], 1500)
        E.cue(match, "green")
    end
    for side = 1, 2 do
        if c.score[side] >= C.target then return E.finish(match, "target") end
    end
    local untilT = G.overtime(c, match.endsAt, t)
    if untilT then
        if not c.overtime then
            c.overtime = true
            E.feed(match, "Overtime", "danger")
            E.banner(match, "OVERTIME", "The trailing team is on the point.", "danger", 2000)
        end
        match.endsAt = untilT
    end
end

local function objective(c, p)
    local zone, side = c.zone, p.side
    if p.ctl.inSpawn then return "Leave the enemy spawn" end
    if zone.contested then return "Contested: clear the point" end
    if zone.capturer ~= 0 and zone.progress > 0 then
        return zone.capturer == side and "Capturing: stay on the point" or "Stop the capture"
    end
    if zone.owner == 0 then return "Take the point" end
    return zone.owner == side and "Hold the point" or "Take the point back"
end

local function world(match)
    local c = match.control
    local at = c.zone.pos
    return {
        markers = { point = { position = { x = at.x, y = at.y, z = at.z - 0.85 }, shape = "ring", radius = C.radius, height = 1,
            color = RINGS[c.zone.owner] } },
        blips = { point = { position = { x = at.x, y = at.y, z = at.z }, title = "The point" } },
    }
end

E.mode({
    id = "games.control", key = "control", label = "Control", kind = "pvp",
    description = "Two teams, one point. Stand on it alone to take it, hold it alone to bank seconds. First to 180 wins.",
    minPlayers = 2, maxPlayers = 16,
    -- The play area widens itself over both spawns and the point: nothing to keep inside.
    schema = {
        points = {
            { key = "point", label = "Control point", color = "#ffcc00" },
            { key = "redSpawn", label = "Red spawn", color = "#ff4d4d" },
            { key = "blueSpawn", label = "Blue spawn", color = "#22d8e2" },
            { key = "centre", label = "Play area centre", color = "#f2f3f5" },
        },
        numbers = { { key = "radius", label = "Play area radius", min = 10, max = 400, default = 80, unit = "m" } },
        area = { centre = "centre", radius = "radius" },
    },
    prepare = function(map)
        map.radius = G.area(map)
        map.spawns = { map.redSpawn, map.blueSpawn } -- spawnFor reads the named two; this is the engine's fallback
    end,
    pvp = true, teams = 2,
    seconds = C.seconds, respawnMs = C.respawnMs,
    kit = true,

    setup = function(match)
        match.control = { score = { 0, 0 }, zone = G.newZone(match.map.point), guards = G.guards(match.map) }
        for _, p in pairs(match.players) do p.ctl = { hold = 0, takes = 0, pointKills = 0, onPoint = false } end
    end,

    spawnFor = function(match, p) return spawnOf(match.map, p.side), 3.0 end,

    tick = step,

    -- Nobody shoots from inside the enemy spawn.
    damage = function(_, _, attacker) if attacker.ctl.inSpawn then return false end end,

    killed = function(match, victim, killer)
        local onPoint = victim.ctl.onPoint or (killer and killer.ctl.onPoint)
        if killer and onPoint then killer.ctl.pointKills = killer.ctl.pointKills + 1 end
        victim.ctl.onPoint, victim.ctl.inSpawn = false, nil
        local short = teamSize(match, 3 - victim.side) - teamSize(match, victim.side)
        victim.respawnAt = E.now() + math.max(C.respawnFloorMs, C.respawnMs - math.max(0, short) * 1000)
    end,

    hud = function(match, p, view)
        local c = match.control
        local zone = c.zone
        view.teams = {
            { name = LABELS[1], color = COLORS[1], score = math.floor(c.score[1]), self = p.side == 1 },
            { name = LABELS[2], color = COLORS[2], score = math.floor(c.score[2]), self = p.side == 2 },
        }
        view.objective = objective(c, p)
        if match.phase == "running" and c.score[p.side] >= C.target - C.matchPoint then view.objective = "Match point: " .. view.objective end
        if zone.capturer ~= 0 and zone.progress > 0 then
            view.progress = { { id = "capture", label = "Capture", value = zone.progress, tone = COLORS[zone.capturer] } }
        end
        view.stats = {
            { label = "Held", value = ("%d s"):format(math.floor(p.ctl.hold)) },
            { label = "Takes", value = tostring(p.ctl.takes) },
            { label = "Kills", value = tostring(p.kills) },
        }
        if c.overtimeUntil and view.timer then view.timer = { remainingMs = math.max(0, c.overtimeUntil - E.now()), label = "OVERTIME" } end
        view.world = world(match)
    end,

    results = function(match, reason)
        local c = match.control
        local winner
        if reason == "forfeit" then
            for _, p in pairs(match.players) do winner = p.side end
        else
            winner = G.leader(c.score)
        end
        local ranking = {}
        for _, p in pairs(match.roster) do
            local state = p.ctl
            p.won = winner ~= nil and p.side == winner
            p.score = math.floor(state.hold)
            p.placement = winner and (p.won and 1 or 2) or nil
            p.row = { outcome = winner and (p.won and "won" or "lost") or nil, holdS = math.floor(state.hold), captures = state.takes }
            ranking[#ranking + 1] = p
        end
        -- The objective players first: hold, captures and point kills, then kills.
        local function worth(p) return p.ctl.takes * 75 + math.floor(p.ctl.hold) + p.ctl.pointKills * 25 + p.kills * 50 end
        table.sort(ranking, function(a, b)
            if (a.won == true) ~= (b.won == true) then return a.won == true end
            if worth(a) ~= worth(b) then return worth(a) > worth(b) end
            return a.id < b.id
        end)
        return {
            ranking = ranking, winnerSide = winner,
            sides = { { id = 1, label = LABELS[1], score = math.floor(c.score[1]) }, { id = 2, label = LABELS[2], score = math.floor(c.score[2]) } },
            lines = {
                { label = "Winner", value = winner and LABELS[winner] or "Draw" },
                { label = "Target", value = ("%d s"):format(C.target) },
            },
            columns = { "holdS", "captures", "kills", "deaths" },
        }
    end,
})
