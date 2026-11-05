-- op77_games engine: instances, the way in and out, the match clock, deaths, HUD, results.
-- Light RP owns the player (activityEnter ... activityLeave); this owns the match.
--
-- THE MODE CONTRACT. A mode is one file in server/modes/ that calls GamesEngine.mode(def),
-- plus one server_script line in open77.lua. Its maps are made in game (server/maps.lua).
--   Fields
--     id, key, label, description  activity id ("games.tdm"), short key, panel text
--     kind                 "pvp" | "event"
--     minPlayers, maxPlayers
--     schema     what a map of this game needs, read by the map editor and the core's
--                validation (server/maps.lua has the format). Plain data, next to the rules
--     prepare    function(map): fields derived from a delivered map, on this VM's copy.
--                The engine needs map.spawns, and map.centre + map.radius unless bounds = false
--     maps       filled by server/maps.lua: { id, name, radius, centre, spawns = { { x, y, z, heading } } }
--                A game with none is not offered and is no error (a test fixture may set its own)
--     pvp        true: a combat scope, the damage arbiter, kills. false: nobody hurts anybody
--     teams      2: sides, friendly fire off. nil: everyone alone
--     seconds    the clock from GO (setup may set match.seconds instead)
--     respawnMs  a death comes back after this long
--     protectMs  after a respawn nobody hurts you and you hurt nobody (optional)
--     kit        true: the game's kit of Config.kits, handed by Light RP (a mission's temporary
--                kit); nil: no weapons; or function(match, p) -> a kit of that contract, one
--                body's own (gun game's explicit steps)
--     bounds     false: no play area (default: map.radius around map.centre)
--     flatBounds true: that area ignores height (default: a sphere, as the source's PvP)
--     joinInProgress  true: a join may enter a running match
--   Hooks (every one optional, all run under pcall, none may Wait)
--     setup(match)              roster dealt, nobody placed yet
--     spawnFor(match, p)        -> point, spread | nil (nil: the spawn farthest from enemies)
--     start(match)              GO: bodies released, the clock runs
--     tick(match, now)          running, every Config.tickMs
--     killed(match, victim, killer)   after the engine's count; killer nil: nobody's kill
--     damage(match, event, attacker, victim)   a hit the arbiter would let through: false
--                               refuses it. A hook that raises refuses too. Its event is
--                               Open77.combat.onDamage's: .attackKind, .weaponTdbId
--     left(match, p, how)       p is gone, the way E.remove says: every exit passes here
--     hud(match, p, view)       add to one player's ActivityHud state. view.world, when set,
--                               is not HUD: { markers = { key = {...} }, blips = { key = {...} } }
--                               goes to client/objectives.lua and only to this player
--     results(match, reason)    -> { ranking = { p... }, sides, winnerSide, lines, columns }
--                               the mode sets p.won, and optionally p.placement, p.score,
--                               p.row (extra recap fields). reason: "time" | "forfeit" |
--                               "abandoned" | whatever the mode gave E.finish
--   A mode reads and writes `match` (.def, .map, .bucket, .phase, .players, .roster, .seconds)
--   and `p` (.id, .name, .side, .alive, .kills, .deaths, .holdUntil), and calls:
--     E.finish(match, reason)   E.members(match)        E.read(id) -> dated position
--     E.sendBack(match, p, onLanded)   a living body back to spawnFor, no death
--     E.setFrozen(p, frozen)    held or released; E.remove lets go of whoever is still held
--     E.feed(match, text, tone)   E.banner(target, title, text, tone, ms)   E.cue(target, name)
--                               (target: a match or a player id; cues are Config.sounds keys)
--     GamesCombat.arm(match, p, kit, immediate)   a new kit mid-match (gun game, a new hunter)
--   Rules the engine keeps and no mode repeats: a pvp match ends "forfeit" when under two
--   sides remain; a match ends "time" at the clock; a match nobody is left in closes.
--   A mode's own net event must check its sender with E.matchOf(source).
local Config = GamesConfig
local A = GamesActivity

GamesEngine = {}
local E = GamesEngine

local HOOKS = { setup = true, spawnFor = true, start = true, tick = true, killed = true, damage = true, left = true,
    hud = true, results = true }
local FIELDS = { id = true, key = true, label = true, description = true, kind = true, minPlayers = true, maxPlayers = true,
    maps = true, schema = true, prepare = true, pvp = true, teams = true, seconds = true, respawnMs = true, protectMs = true, kit = true, bounds = true,
    joinInProgress = true, flatBounds = true }

E.matches = {}    -- match id -> match
E.byPlayer = {}   -- playerId -> match
E.stopped = false
local byPlayer = E.byPlayer
local buckets = {} -- bucket -> match
local sequence, moves = 0, 0
local strays = {} -- playerId -> when first seen in our buckets without a match
local nextSweepAt = 0

local noop = function() end
E.hooks = { changed = noop } -- () queues or matches changed: the status

local function log(text) print("[games] " .. tostring(text)) end
E.log = log

function E.now() return math.floor(Open77.time.monotonic() * 1000) end

-- Open77.players.* raises on an id below 1: every id from outside goes through this.
function E.playerId(value)
    local id = math.tointeger(tonumber(value))
    if id == nil or id < 1 then return nil end
    return id
end

local function connected(id) return Open77.players.name(id) ~= nil end

function E.inRange(bucket)
    bucket = tonumber(bucket)
    return bucket ~= nil and bucket >= Config.buckets.first and bucket <= Config.buckets.last
end

function E.distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end
function E.flat(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- The server's own dated reading of a body, never a client's word: { x, y, z, ageMs },
-- or nil when it has none younger than the platform's two seconds. nil means "cannot
-- tell": no rule may read it as anything else.
function E.read(id)
    local ok, read = pcall(Open77.players.get, id)
    if not ok or type(read) ~= "table" or read.fresh ~= true or type(read.position) ~= "table" then return nil end
    local at = read.position
    if type(at.x) ~= "number" or type(at.y) ~= "number" or type(at.z) ~= "number" then return nil end
    return { x = at.x, y = at.y, z = at.z, ageMs = tonumber(read.ageMs) or 0 }
end

local function hook(match, name, ...)
    local fn = match.def[name]
    if fn == nil then return nil end
    local ok, first, second = pcall(fn, match, ...)
    if not ok then log(("%s hook of %s failed: %s"):format(name, match.def.id, tostring(first))) return nil end
    return first, second
end

function E.matchOf(id) return byPlayer[id] end

-- The present players, in a stable order.
function E.members(match)
    local list = {}
    for _, p in pairs(match.players) do list[#list + 1] = p end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function E.mapOf(def, wanted)
    for _, map in ipairs(def.maps) do
        if map.id == wanted then return map end
    end
    return nil
end

-- ---------------------------------------------------------------- modes --

function E.mode(def)
    for key in pairs(def) do
        assert(FIELDS[key] or HOOKS[key], ("mode %s: unknown field %s"):format(tostring(def.id), tostring(key)))
    end
    assert(type(def.id) == "string" and type(def.key) == "string" and type(def.label) == "string", "mode: id, key, label")
    assert(def.kind == "pvp" or def.kind == "event", def.id .. ": kind is pvp or event")
    assert(def.schema == nil or type(def.schema) == "table", def.id .. ": schema is a table")
    assert(def.prepare == nil or type(def.prepare) == "function", def.id .. ": prepare is a function")
    def.maps = def.maps or {}
    assert(type(def.maps) == "table", def.id .. ": maps is a list")
    def.minPlayers, def.maxPlayers = def.minPlayers or 2, def.maxPlayers or 16
    assert(not def.pvp or def.maxPlayers <= Config.scopes.maxPlayers, def.id .. ": a combat scope takes 32 players")
    A.add(def)
    return def
end

-- ---------------------------------------------------------------- HUD --

local function each(target, fn)
    if type(target) == "table" then
        for id in pairs(target.players) do fn(id) end
    else
        fn(target)
    end
end

local function hudPush(target, kind, payload)
    each(target, function(id) TriggerClientEvent("op77_games:push", id, kind, payload) end)
end

function E.feed(match, text, tone) hudPush(match, "feed", { text = text, tone = tone }) end
function E.banner(target, title, text, tone, ms)
    hudPush(target, "banner", { title = title, text = text, tone = tone or "accent", durationMs = ms or 2500 })
end
function E.cue(target, name) each(target, function(id) TriggerClientEvent("op77_games:cue", id, name) end) end

-- A stable text of a view: same state, same text. The timer's deadline stands for it.
local function serialize(value, out)
    if type(value) == "table" then
        local keys = {}
        for key in pairs(value) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        out[#out + 1] = "{"
        for _, key in ipairs(keys) do
            if key ~= "timer" and key ~= "countdown" then
                out[#out + 1] = tostring(key) .. "="
                serialize(value[key], out)
            end
        end
        out[#out + 1] = "}"
    else
        out[#out + 1] = tostring(value)
    end
end

local function viewFor(match, p, t)
    local def = match.def
    local view = { activity = def.id, title = def.label, subtitle = match.map.name }
    if match.phase == "placing" then
        view.phase = "countdown"
    elseif match.phase == "countdown" then
        view.phase = "countdown"
        local left = math.max(0, match.phaseEndsAt - t)
        view.countdown = left > 10 and left or 0 -- 10 or less would read as seconds
    elseif match.phase == "running" then
        view.phase = "running"
        view.timer = { remainingMs = math.max(0, match.endsAt - t), label = "TIME" }
    else
        view.phase = "ended"
    end
    hook(match, "hud", p, view)
    return view
end

local function sendHud(match, p, t, force)
    local view = viewFor(match, p, t)
    local out = { match.phase, "|", tostring(match.endsAt), "|" }
    serialize(view, out)
    local key = table.concat(out)
    if not force and p.hudKey == key then return end
    p.hudKey = key
    TriggerClientEvent("op77_games:hud", p.id, view)
end

-- Asks every mode's hud a few times a second; only what changed goes out.
local function flushHud(match, t)
    if t < (match.hudAt or 0) then return end
    match.hudAt = t + Config.hudMs
    for _, p in pairs(match.players) do sendHud(match, p, t) end
end

-- A client that (re)started asks for its state: only its own, only if it has one.
function E.resend(id)
    local match = byPlayer[id]
    local p = match and match.players[id]
    if p then sendHud(match, p, E.now(), true) end
end

-- ---------------------------------------------------------------- spawns --

-- The spawn farthest from every living enemy, not one used in the last 3 s if it can be
-- helped (random among equals).
local function farthestSpawn(match, p)
    local others = {}
    for _, other in pairs(match.players) do
        if other ~= p and other.alive and (other.side == nil or other.side ~= p.side) then
            local read = E.read(other.id)
            if read then others[#others + 1] = read end
        end
    end
    local t, used = E.now(), match.spawnUsed
    local best, bestGap, bestFresh
    local spawns = match.map.spawns
    local from = math.random(#spawns)
    for index = 1, #spawns do
        local spawn = spawns[(from + index - 2) % #spawns + 1]
        local gap = math.huge
        for _, at in ipairs(others) do gap = math.min(gap, E.distance(at, spawn)) end
        local fresh = used[spawn] == nil or t - used[spawn] > 3000
        if best == nil or (fresh and not bestFresh) or (fresh == bestFresh and gap > bestGap) then
            best, bestGap, bestFresh = spawn, gap, fresh
        end
    end
    used[best] = t
    return best, 0.5
end

local function spawnPoint(match, p)
    local point, spread = hook(match, "spawnFor", p)
    if type(point) ~= "table" then point, spread = farthestSpawn(match, p) end
    local angle, radius = math.random() * math.pi * 2, spread and math.random() * spread or 0
    return { x = point.x + math.cos(angle) * radius, y = point.y + math.sin(angle) * radius, z = point.z,
        heading = point.heading or 0.0 }
end

-- ---------------------------------------------------------------- bodies --

local function fullHealth(id)
    local ok, health = pcall(Open77.players.getHealth, id)
    if ok and type(health) == "table" and tonumber(health.maxHealth) then
        pcall(Open77.players.setHealth, id, health.maxHealth)
    end
end

local function phaseOf(id)
    local ok, life = pcall(Open77.players.getLifeState, id)
    if ok and type(life) == "table" then return (tostring(life.phase or ""):gsub("_", "")) end
    return nil
end

-- Moves a body inside the match: the living by teleport, the dead by respawn. While it
-- flies p.holdUntil is infinite: rules leave that body alone until Config settleMs after.
local function place(match, p, point, onLanded, onFailed)
    moves = moves + 1
    local token = moves
    p.move, p.holdUntil = token, math.huge
    local function done(ok, why)
        if match.players[p.id] ~= p or p.move ~= token then return end
        p.move = nil
        if ok then
            p.holdUntil = E.now() + Config.match.settleMs
            if onLanded then onLanded() end
        else
            p.holdUntil = 0
            log(("%d not placed in %s: %s"):format(p.id, match.id, tostring(why)))
            if onFailed then onFailed(why) end
        end
    end
    local target = { x = point.x, y = point.y, z = point.z }
    if phaseOf(p.id) == "dead" then
        local ok, why = Open77.players.respawn(p.id, { position = target, heading = point.heading or 0.0,
            bucket = match.bucket, health = 1.0, graceMs = Config.match.settleMs })
        return done(ok == true, why)
    end
    local promise, why = Open77.players.teleport(p.id, target, { heading = point.heading or 0.0, bucket = match.bucket,
        fade = true, dismount = true, timeoutMs = Config.teleportTimeoutMs })
    if not promise then return done(false, why) end
    CreateThread(function()
        local landed, failure = promise:await()
        done(landed ~= nil and landed ~= false, failure)
    end)
end

-- A living body back to its spawn, no death: red light's price.
function E.sendBack(match, p, onLanded)
    place(match, p, spawnPoint(match, p), onLanded, function()
        p.holdUntil = E.now() + Config.match.settleMs
    end)
end

local function setFrozen(p, frozen)
    local ok, done = pcall(Open77.players.setFrozen, p.id, frozen)
    p.frozen = frozen and ok and done == true
    return ok and done == true
end
E.setFrozen = setFrozen

-- ---------------------------------------------------------------- the way out --

-- The last resort: nobody stays in one of our buckets. Fire and forget from a stopping
-- resource (`noWait`); otherwise the failed teleport still gets the bucket back.
function E.fallback(id, noWait)
    if not connected(id) then return false end
    local point = Config.fallback
    local target = { x = point.x, y = point.y, z = point.z }
    log(("%d returned by the fallback"):format(id))
    if phaseOf(id) == "dead" then
        local ok = Open77.players.respawn(id, { position = target, heading = point.heading, bucket = point.bucket,
            health = 1.0, graceMs = 3000 })
        if ok == true then return true end
    end
    local promise = Open77.players.teleport(id, target, { heading = point.heading, bucket = point.bucket, fade = true,
        dismount = true, timeoutMs = Config.teleportTimeoutMs })
    local function lastResort()
        if type(SetPlayerRoutingBucket) == "function" then pcall(SetPlayerRoutingBucket, id, point.bucket) end
    end
    if not promise then lastResort() return false end
    if not noWait then
        CreateThread(function()
            local landed = promise:await()
            if not landed then lastResort() end
        end)
    end
    return true
end

-- The fallback, only if they really are still in one of our buckets by then.
local function fallbackIfStuck(id, delayMs)
    SetTimeout(delayMs, function()
        if byPlayer[id] ~= nil or E.stopped then return end
        local ok, here = pcall(Open77.players.position, id)
        if ok and type(here) == "table" and E.inRange(here.bucket) then E.fallback(id) end
    end)
end

local closeIfDone -- defined with the end of a match

-- THE one exit. `how` says who still has to release the player:
--   "left" "ended" "place_failed" "cancelled" "orphan"   ours: activityLeave, the core takes
--       them back; refused (a core that is gone), the fallback, if they are still inside
--   "dropped" "disconnect"   the core already released them: never activityLeave
function E.remove(id, how)
    local match = byPlayer[id]
    local p = match and match.players[id]
    if p == nil then return false end
    match.players[id], byPlayer[id] = nil, nil
    p.left, p.leftAt, p.how = how ~= "ended", E.now(), how
    p.move = nil
    GamesCombat.disarm(match, p)
    hook(match, "left", p, how)
    if connected(id) then
        if p.frozen then setFrozen(p, false) end
        TriggerClientEvent("op77_games:clear", id)
    end
    if how ~= "dropped" and how ~= "disconnect" then
        local ok, why = A.leave(id, match.def.id, { returnPlayer = true })
        if not ok then
            log(("%d: activityLeave refused (%s)"):format(id, tostring(why)))
            local here = Open77.players.position(id)
            if type(here) ~= "table" or E.inRange(here.bucket) then E.fallback(id) end
        end
    end
    log(("%d left %s (%s)"):format(id, match.id, how))
    closeIfDone(match)
    E.hooks.changed()
    return true
end

-- ---------------------------------------------------------------- the end --

-- Every participant, the ones who left included: they played it, they see the board.
local function buildRecap(match, reason, t)
    local out = hook(match, "results", reason)
    out = type(out) == "table" and out or {}
    local ranking, seen = {}, {}
    for _, p in ipairs(type(out.ranking) == "table" and out.ranking or {}) do
        if not seen[p] then seen[p] = true; ranking[#ranking + 1] = p end
    end
    local rest = {}
    for _, p in pairs(match.roster) do
        if not seen[p] then rest[#rest + 1] = p end
    end
    table.sort(rest, function(a, b)
        if a.kills ~= b.kills then return a.kills > b.kills end
        return a.id < b.id
    end)
    for _, p in ipairs(rest) do ranking[#ranking + 1] = p end
    local rows = {}
    for index, p in ipairs(ranking) do
        p.placement = p.placement or index
        local row = { id = p.id, name = p.name, side = p.side, kills = p.kills, deaths = p.deaths, score = p.score,
            placement = p.placement, left = p.left or nil,
            inMatchMs = math.max(0, (p.leftAt or t) - p.joinedAt) }
        for key, value in pairs(p.row or {}) do row[key] = value end
        rows[index] = row
    end
    local startedAt = match.startedAt or match.openedAt
    return { matchId = match.id, durationMs = math.max(0, t - startedAt), detail = match.map.name, sides = out.sides,
        winnerSide = out.winnerSide, rows = rows, lines = out.lines, columns = out.columns,
        mvp = ranking[1] and ranking[1].id or nil }, ranking
end

local function report(match, reason, t)
    local recap, ranking = buildRecap(match, reason, t)
    for _, p in ipairs(ranking) do
        A.result(p.id, match.def.id, {
            placement = p.placement, won = p.won == true, score = p.score,
            unranked = Config.unranked == true or nil,
            stats = { kills = p.kills, deaths = p.deaths, matchId = match.id, map = match.map.id,
                durationMs = math.max(0, (p.leftAt or t) - p.joinedAt), quit = p.left or nil },
            recap = recap,
        })
    end
    A.recap(match.def.id, recap)
end

-- The fight is over: results now, the way back after the result card. Once per match.
function E.finish(match, reason)
    if match.phase == "ended" or match.closed then return false end
    local t = E.now()
    match.phase, match.phaseEndsAt, match.reason = "ended", t + Config.match.endMs, reason
    GamesCombat.release(match)
    report(match, reason, t)
    for _, p in pairs(match.players) do
        hudPush(p.id, "result", { title = match.def.label, subtitle = match.map.name,
            placement = p.placement, durationMs = Config.match.endMs })
    end
    log(("%s ended (%s)"):format(match.id, tostring(reason)))
    closeIfDone(match)
    E.hooks.changed()
    return true
end

-- No result: nothing was played, or it can no longer be judged.
function E.cancel(match, why)
    if match.closed then return end
    log(("%s cancelled (%s)"):format(match.id, tostring(why)))
    match.phase = "ended"
    for _, p in ipairs(E.members(match)) do
        if why then A.notice(p.id, "warning", match.def.label, why) end
        E.remove(p.id, "cancelled")
    end
    closeIfDone(match)
end

local function close(match)
    if match.closed then return end
    match.closed = true
    GamesCombat.release(match, true)
    E.matches[match.id] = nil
    buckets[match.bucket] = nil
    log(("%s closed, bucket %d free"):format(match.id, match.bucket))
    E.hooks.changed()
end

-- Who is left decides. Called on every departure.
closeIfDone = function(match)
    if match.closed then return end
    local running = match.phase == "running"
    if next(match.players) == nil then
        if running then E.finish(match, "abandoned") else close(match) end
    elseif match.def.pvp and match.phase ~= "ended" then
        local sides, count = {}, 0
        for _, p in pairs(match.players) do
            local key = p.side or p.id
            if not sides[key] then sides[key] = true; count = count + 1 end
        end
        if count >= 2 then return end
        -- Before GO nothing was played: no winner, no board.
        if running then E.finish(match, "forfeit") else E.cancel(match, "The other side left before the start.") end
    end
end

-- ---------------------------------------------------------------- the way in --

local function allocateBucket()
    for bucket = Config.buckets.first, Config.buckets.last do
        if buckets[bucket] == nil then return bucket end
    end
    return nil
end

local function prepareBucket(bucket)
    if type(SetRoutingBucketPopulationEnabled) == "function" then pcall(SetRoutingBucketPopulationEnabled, bucket, false) end
    if type(SetRoutingBucketEntityLockdownMode) == "function" then pcall(SetRoutingBucketEntityLockdownMode, bucket, "relaxed") end
end

local function newPlayer(match, id, side)
    local info = A.player(id)
    local name = info and info.name or Open77.players.name(id) or ("Player " .. id)
    return { id = id, name = name, side = side, alive = true, kills = 0, deaths = 0, joinedAt = E.now(), holdUntil = math.huge }
end

local function deal(def, ids, teams)
    local sides = {}
    if not def.teams then return sides end
    for side, team in ipairs(type(teams) == "table" and teams or {}) do
        for _, id in ipairs(team) do sides[id] = math.min(side, def.teams) end
    end
    local counts = {}
    for side = 1, def.teams do counts[side] = 0 end
    for _, id in ipairs(ids) do
        if sides[id] then counts[sides[id]] = counts[sides[id]] + 1 end
    end
    for _, id in ipairs(ids) do
        if sides[id] == nil then
            local best = 1
            for side = 2, def.teams do if counts[side] < counts[best] then best = side end end
            sides[id] = best
            counts[best] = counts[best] + 1
        end
    end
    return sides
end

-- Enough people for this mode to be a match at all? A pvp match needs two sides.
function E.playable(def, ids, sides)
    if #ids < def.minPlayers then return false end
    if not def.pvp then return true end
    local seen, count = {}, 0
    for _, id in ipairs(ids) do
        local key = sides[id] or id
        if not seen[key] then seen[key] = true; count = count + 1 end
    end
    return count >= 2
end

local function admit(match, p)
    match.players[p.id], match.roster[p.id], byPlayer[p.id] = p, p, match
end

local function landed(match, p)
    p.landed, p.alive, p.respawnAt = true, true, nil
    fullHealth(p.id)
    GamesCombat.join(match, p)
    if match.phase == "placing" or match.phase == "countdown" then setFrozen(p, true) end
    local kit = GamesCombat.kitOf(match, p)
    if kit ~= nil then GamesCombat.arm(match, p, kit) end
end

local function placeIn(match, p)
    p.placeRetryAt = nil
    place(match, p, spawnPoint(match, p), function() landed(match, p) end, function()
        p.placeRetryAt = E.now() + Config.match.placeRetryMs
    end)
end

-- Starts a match over these players (the lobby re-checked them). Core order: activityEnter,
-- then the move. Nobody has moved when this refuses, and it releases nobody: whoever is
-- not in E.matchOf afterwards is still the caller's. Returns the match, or nil and a reason.
--   opts = { map = map id, teams = { { ids }... }, matchId, friendly }
function E.open(def, ids, opts)
    opts = opts or {}
    if E.stopped then return nil, "stopped" end
    if #def.maps == 0 then return nil, "no_map" end
    if def.pvp and GamesCombat.free() <= 0 then return nil, "no_scope" end
    local map = E.mapOf(def, opts.map)
    if map == nil then
        E.rotation = (E.rotation or 0) + 1
        map = def.maps[(E.rotation - 1) % #def.maps + 1]
    end
    local bucket = allocateBucket()
    if bucket == nil then return nil, "no_bucket" end

    local admitted = {}
    for _, id in ipairs(ids) do
        if connected(id) and byPlayer[id] == nil then admitted[#admitted + 1] = id end
    end
    local sides = deal(def, admitted, opts.teams)
    if not E.playable(def, admitted, sides) then return nil, "not_enough" end
    local entered = {}
    for _, id in ipairs(admitted) do
        local ok, why = A.enter(id, def.id)
        if ok then entered[#entered + 1] = id else A.notice(id, "warning", def.label, why) end
    end
    if not E.playable(def, entered, sides) then
        for _, id in ipairs(entered) do A.leave(id, def.id, { returnPlayer = false }) end
        return nil, "not_enough"
    end

    sequence = sequence + 1
    local t = E.now()
    local match = { id = ("games:%d:%d"):format(sequence, t), def = def, map = map, bucket = bucket, phase = "placing",
        players = {}, roster = {}, openedAt = t, phaseEndsAt = t + Config.match.placeTimeoutMs, seconds = def.seconds or 600,
        friendly = opts.friendly == true, matchId = opts.matchId, spawnUsed = {} }
    E.matches[match.id] = match
    buckets[bucket] = match
    prepareBucket(bucket)
    for _, id in ipairs(entered) do admit(match, newPlayer(match, id, sides[id])) end
    hook(match, "setup")
    for _, p in ipairs(E.members(match)) do placeIn(match, p) end
    log(("%s opened: %s on %s, bucket %d, %d players"):format(match.id, def.id, map.id, bucket, #entered))
    E.hooks.changed()
    return match
end

-- A running match this player could still enter. Only a mode that opted in has one.
function E.lateMatch(def, matchId)
    if not def.joinInProgress then return nil end
    for _, match in pairs(E.matches) do
        if match.def == def and match.matchId == matchId and match.phase == "running" then
            local count = 0
            for _ in pairs(match.players) do count = count + 1 end
            if count < def.maxPlayers then return match end
        end
    end
    return nil
end

function E.joinLate(match, id)
    if byPlayer[id] ~= nil then return false, "You are already in a game." end
    local ok, why = A.enter(id, match.def.id)
    if not ok then return false, why end
    local side
    if match.def.teams then
        local counts = {}
        for index = 1, match.def.teams do counts[index] = 0 end
        for _, other in pairs(match.players) do counts[other.side] = counts[other.side] + 1 end
        side = 1
        for index = 2, match.def.teams do if counts[index] < counts[side] then side = index end end
    end
    local p = newPlayer(match, id, side)
    admit(match, p)
    placeIn(match, p)
    return true
end

-- ---------------------------------------------------------------- deaths --

local function killerOf(match, p, reported, t)
    local killer = match.players[E.playerId(reported) or 0]
    if killer == nil and p.lastHitBy and t - (p.lastHitAt or 0) <= Config.match.lastHitMs then
        killer = match.players[p.lastHitBy]
    end
    if killer == nil or killer == p then return nil end
    if killer.side ~= nil and killer.side == p.side then return nil end
    return killer
end

-- From open77:playerKilled and open77:playerDied: both may report one death, in either
-- order. The first one counts; p.alive holds until the respawn.
function E.onDeath(id, reported)
    local match = byPlayer[id]
    local p = match and match.players[id]
    if p == nil or not p.alive or match.phase == "ended" then return end
    p.alive, p.frozen = false, false -- a death lifts a freeze
    p.respawnAt, p.respawnTries = E.now() + (match.def.respawnMs or 3000), 0
    p.outsideSince, p.outsideSamples = nil, nil
    if match.phase ~= "running" then return end
    local t = E.now()
    p.deaths = p.deaths + 1
    local killer = killerOf(match, p, reported, t)
    if killer then
        killer.kills = killer.kills + 1
        E.feed(match, ("%s took out %s"):format(killer.name, p.name), "info")
    end
    p.lastHitBy, p.lastHitAt = nil, nil
    hook(match, "killed", p, killer)
end

local function respawned(match, p, t)
    p.alive, p.respawnAt = true, nil
    if match.def.protectMs then p.protectedUntil = t + match.def.protectMs end
    GamesCombat.reissue(match, p) -- the core holds this hand until the body stands, or reports "failed"
end

local function serveRespawn(match, p, t)
    local phase = phaseOf(p.id)
    if phase == "alive" then return respawned(match, p, t) end -- it stood up by itself
    local point = spawnPoint(match, p)
    local ok, why = false, "still " .. tostring(phase)
    if phase == "dead" then
        ok, why = Open77.players.respawn(p.id, { position = { x = point.x, y = point.y, z = point.z },
            heading = point.heading, bucket = match.bucket, health = 1.0, graceMs = Config.match.settleMs })
    end
    if ok == true then
        p.holdUntil = t + Config.match.settleMs
        return respawned(match, p, t)
    end
    p.respawnTries = p.respawnTries + 1
    p.respawnAt = t + Config.match.respawnRetryMs
    if p.respawnTries >= Config.match.respawnTries then
        log(("%d could not respawn in %s: %s"):format(p.id, match.id, tostring(why)))
        A.notice(p.id, "warning", match.def.label, "You could not be brought back into the match.")
        E.remove(p.id, "left")
    end
end

-- ---------------------------------------------------------------- bounds --

-- Time and consecutive readable samples, both: time alone would convict across a lag gap,
-- samples alone would let a lagging player sit outside. An unreadable sample moves neither.
local function stepBounds(match, p, t)
    local read = E.read(p.id)
    if read == nil or not p.alive or t < p.holdUntil then return end
    local reach = match.def.flatBounds and E.flat or E.distance
    if reach(read, match.map.centre) <= match.map.radius then
        if p.outsideSince then E.banner(p.id, "BACK IN BOUNDS", "", "success", 1000) end
        p.outsideSince, p.outsideSamples = nil, nil
        return
    end
    if p.outsideSince == nil then
        p.outsideSince, p.outsideSamples = t, 0
        E.banner(p.id, "OUT OF BOUNDS", ("Back to the fight within %d s."):format(Config.bounds.graceSeconds), "danger", 3000)
    end
    p.outsideSamples = p.outsideSamples + 1
    if t - p.outsideSince >= Config.bounds.graceSeconds * 1000 and p.outsideSamples >= Config.bounds.samples then
        p.outsideSince, p.outsideSamples = nil, nil
        local ok, done, why = pcall(Open77.players.kill, p.id, { cause = "script", weapon = "games:out_of_bounds" })
        if not ok or done ~= true then log(("%d out of bounds, not killed: %s"):format(p.id, tostring(ok and why or done))) end
    end
end

-- ---------------------------------------------------------------- phases --

local function goLive(match, t)
    match.phase, match.startedAt, match.endsAt = "running", t, t + match.seconds * 1000
    for _, p in pairs(match.players) do
        if p.frozen then setFrozen(p, false) end
        p.holdUntil = 0
    end
    hook(match, "start")
    E.banner(match, "GO", "", "success", 1000)
    E.hooks.changed()
end

local function stepPlacing(match, t)
    local waiting = false
    for _, p in ipairs(E.members(match)) do
        if not p.landed then
            if t >= match.phaseEndsAt then
                A.notice(p.id, "warning", match.def.label, "You could not be brought into the match.")
                E.remove(p.id, "place_failed")
            else
                waiting = true
                if p.placeRetryAt and t >= p.placeRetryAt then placeIn(match, p) end
            end
        end
    end
    if match.closed or match.phase ~= "placing" or waiting then return end
    match.phase, match.phaseEndsAt = "countdown", t + Config.match.countdownMs
end

local function stepRunning(match, t)
    if t >= match.endsAt then E.finish(match, "time") return end
    local sample = match.def.bounds ~= false and t >= (match.boundsAt or 0)
    if sample then match.boundsAt = t + Config.bounds.sampleMs end
    for _, p in ipairs(E.members(match)) do
        if p.respawnAt and t >= p.respawnAt then serveRespawn(match, p, t) end
        if match.closed or match.phase ~= "running" then return end
        if sample then stepBounds(match, p, t) end
    end
    hook(match, "tick", t)
end

-- A member the core no longer calls ours (a core that crashed, a release we were not told
-- about) has nobody coming for them.
local function stepOwners(match, t)
    if t < (match.ownersAt or 0) then return end
    match.ownersAt = t + 1000
    for _, p in ipairs(E.members(match)) do
        if A.owner(p.id) == match.def.id then
            p.orphanSince = nil
        elseif p.orphanSince == nil then
            p.orphanSince = t
        elseif t - p.orphanSince >= Config.strays.orphanMs then
            E.remove(p.id, "orphan")
        end
    end
end

local function step(match, t)
    if match.phase == "placing" then
        stepPlacing(match, t)
    elseif match.phase == "countdown" then
        for _, p in pairs(match.players) do
            if p.landed and not p.frozen then setFrozen(p, true) end
        end
        if t >= match.phaseEndsAt then goLive(match, t) end
    elseif match.phase == "running" then
        stepRunning(match, t)
    elseif t >= match.phaseEndsAt then
        for _, p in ipairs(E.members(match)) do E.remove(p.id, "ended") end
        close(match)
        return
    end
    if match.closed then return end
    if match.def.pvp and (match.phase == "countdown" or match.phase == "running") then GamesCombat.sync(match, t) end
    if match.closed then return end
    stepOwners(match, t)
    if not match.closed then flushHud(match, t) end
end

-- Anybody in our buckets without a match, past the core's own way back: a reload that
-- lost a match, a return that failed, a landing after the leave.
local function sweep(t)
    if t < nextSweepAt or type(Open77.players.positions) ~= "function" then return end
    nextSweepAt = t + Config.strays.sweepMs
    local ok, positions = pcall(Open77.players.positions)
    if not ok or type(positions) ~= "table" then return end
    local seen = {}
    for rawId, at in pairs(positions) do
        local id = E.playerId(rawId)
        if id and byPlayer[id] == nil and type(at) == "table" and E.inRange(at.bucket) then
            seen[id] = true
            strays[id] = strays[id] or t
            if t - strays[id] >= Config.strays.graceMs then
                strays[id] = t
                local owner = A.owner(id)
                if A.mine(owner) then
                    if not A.leave(id, owner, { returnPlayer = true }) then E.fallback(id) end
                elseif owner == nil then
                    E.fallback(id)
                end
            end
        end
    end
    for id in pairs(strays) do
        if not seen[id] then strays[id] = nil end
    end
end

function E.tick(t)
    if E.stopped then return end
    t = t or E.now()
    local list = {}
    for _, match in pairs(E.matches) do list[#list + 1] = match end
    for _, match in ipairs(list) do
        if not match.closed then step(match, t) end
    end
    sweep(t)
end

-- ---------------------------------------------------------------- from the outside --

-- The core released this player (disconnect, timeout, character change...).
function E.dropped(id, reason)
    local removed = E.remove(id, reason == "disconnect" and "disconnect" or "dropped")
    if removed and reason == "core_stopped" then fallbackIfStuck(id, Config.strays.coreStoppedMs) end
    return removed
end

-- The core stopped: it teleports its players and tells us "core_stopped" for each, but a
-- crash tells nothing. Every match ends here; nobody can admit or return until it is back.
function E.coreStopped()
    for _, match in pairs(E.matches) do match.phase = "ended" end
    local ids = {}
    for id in pairs(byPlayer) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do
        E.remove(id, "dropped")
        fallbackIfStuck(id, Config.strays.coreStoppedMs)
    end
end

-- This resource stops. No thread survives it, and the core returns the players of a
-- stopping provider; our weapons go first. With the core gone too, the fallback.
function E.shutdown()
    E.stopped = true
    local coreUp = A.call("activityBots") ~= nil
    for id, match in pairs(byPlayer) do
        local p = match.players[id]
        GamesCombat.disarm(match, p)
        hook(match, "left", p, "shutdown")
        TriggerClientEvent("op77_games:clear", id)
        if not coreUp then E.fallback(id, true) end
    end
    GamesCombat.shutdown()
end
