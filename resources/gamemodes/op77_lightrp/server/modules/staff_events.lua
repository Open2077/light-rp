-- Staff events (/admin > Events, /lightrp.event): the staff launch world events where they
-- want, on the world boss engine (server/modules/world_bosses.lua), and chain them into
-- event nights. Config: server/config/staff_events.lua.
--
--   kinds      a world boss of the catalogue (at its own place, or moved: a compact layout
--              around the point), a cyberpsycho (one Psycho Squad record, a big health
--              multiplier), a gang attack (a warlord, its squad, two waves of
--              reinforcements from the edge of the zone)
--   where      its own place (a world boss), here (the staff's position, city only), on a
--              player (their position now), or a saved spot (lightrp_event_spots)
--   level      Normal / Hard / Brutal multiply health, damage and numbers
--   pay        on: exactly a world boss (pool, daily cap, reputation, dailies, titles,
--              drops), needs eventsPay; off: for fun, nothing paid or counted
--   silent     no city notice and no map pin: the players find it
--   nights     presets (Psycho Night, Boss Rush, Gang War, Siege) that launch rounds of
--              events with an announcement, a break between rounds and a final summary
--
-- Every write is audited in lightrp_staff_audit (admin.lua) under the desk's mutation key,
-- like the other staff tools: a repeated request answers the first outcome.
local C = LightRpStaffEvents
local D = LightRpMissionDefs
local S = LightRP.support
local Db = LightRP.db
local SE = LightRP.module("staffEvents", {})

Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_event_spots (
    id VARCHAR(24) NOT NULL PRIMARY KEY, name VARCHAR(40) NOT NULL, district VARCHAR(48) NOT NULL DEFAULT '',
    x DOUBLE NOT NULL, y DOUBLE NOT NULL, z DOUBLE NOT NULL, heading DOUBLE NOT NULL DEFAULT 0,
    created_by VARCHAR(96) NOT NULL DEFAULT '', created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local spots = {}          -- id -> { id, name, district, x, y, z, heading, by, at }
local spotsLoaded = false
local night = nil         -- the running event night, or nil
local seq = 0

local function now() return LightRP.nowMs() end
local function log(...) LightRP.log(...) end
local function engine() return LightRP.worldBosses end
local function finite(v) local n = tonumber(v); return n and n == n and math.abs(n) < 1e7 and n or nil end
local function clamp(v, low, high) return math.max(low, math.min(high, v)) end
local function round(v) return math.floor(v + 0.5) end
local function unix()
    local ok, v = pcall(function() return Open77.time.unix() end)
    if ok and tonumber(v) then return math.floor(tonumber(v)) end
    return os.time()
end
-- Optional text from the page: trimmed, one line, at most `max` characters; "" when absent,
-- nil when invalid.
local function clean(value, max)
    if value == nil then return "" end
    if type(value) ~= "string" then return nil end
    value = value:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    local n = utf8.len(value)
    if not n or n > max or value:find("[%z\1-\31]") then return nil end
    return value
end
-- At most `n` characters, never a cut UTF-8 sequence.
local function cut(text, n)
    local len = utf8.len(text)
    if len and len > n then return text:sub(1, utf8.offset(text, n + 1) - 1) end
    return len and text or ""
end
local function fill(text, vars) return (tostring(text):gsub("{(%w+)}", function(k) return vars[k] ~= nil and tostring(vars[k]) or "" end)) end
local function pick(list) return list[math.random(1, #list)] end
local function shuffled(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    for i = #out, 2, -1 do local j = math.random(1, i); out[i], out[j] = out[j], out[i] end
    return out
end
local function desk(player, right) return player ~= nil and player ~= 0 and S.allowed(player, "view") and S.allowed(player, right) end
local function positionOf(id)
    local p = Open77.players.position(id)
    if not p then return nil end
    local bucket = p.bucket
    if Open77.routingBuckets and Open77.routingBuckets.getPlayer then
        local b = Open77.routingBuckets.getPlayer(id)
        if b ~= nil then bucket = b end
    elseif type(GetPlayerRoutingBucket) == "function" then
        bucket = GetPlayerRoutingBucket(id)
    end
    return { x = p.x, y = p.y, z = p.z, heading = tonumber(p.heading) or 0, bucket = tonumber(bucket) or 0 }
end
local function distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
local function xyz(p) return { x = p.x, y = p.y, z = p.z } end
-- The game's yaw (degrees, 0 = +Y, counter-clockwise) looking from `a` to `b`.
local function yawTo(a, b) return math.deg(math.atan(-(b.x - a.x), b.y - a.y)) % 360 end
local function ring(center, radius, i, n, offset)
    local a = (offset or 0) + (i - 1) * 2 * math.pi / math.max(1, n)
    return { x = center.x + math.cos(a) * radius, y = center.y + math.sin(a) * radius, z = center.z }
end
local function circle(center, radius)
    return { shape = "circle", center = xyz(center), radius = radius, minZ = center.z - 50, maxZ = center.z + 100, fullHeight = true }
end
local function newId(kind)
    seq = seq + 1
    return ("staff-%s-%d-%d"):format(kind, unix() % 1000000, seq)
end

-- ---------------------------------------------------------------------------
-- Catalogues

local function catalogue() local W = engine(); return W and W.catalogue() or {} end
local function bossDef(id)
    for _, d in ipairs(catalogue()) do if d.id == id then return d end end
end
local function findBoss(text)
    text = tostring(text or ""):lower()
    for _, d in ipairs(catalogue()) do if d.id == text or d.title:lower():find(text, 1, true) then return d end end
end
local function levelOf(id)
    for i, l in ipairs(C.levels) do if l.id == id then return l, i end end
    return C.levels[1], 1
end
local function psychos()
    local out = {}
    for _, e in ipairs(D.ENEMIES) do if e.psycho then out[#out + 1] = e end end
    return out
end
local function crewOf(id)
    for _, c in ipairs(C.gang.crews) do if c.id == id then return c end end
end
local function presetOf(id)
    for _, n in ipairs(C.nights.presets) do if n.id == id then return n end end
end
SE.psychos, SE.levelOf, SE.crewOf = psychos, levelOf, crewOf

-- ---------------------------------------------------------------------------
-- Saved spots

local function loadSpots()
    if spotsLoaded or not Db.ready then return end
    spotsLoaded = true
    local ok, rows = Db.read("SELECT id, name, district, x, y, z, heading, created_by, UNIX_TIMESTAMP(created_at) AS at FROM lightrp_event_spots")
    if not ok then spotsLoaded = false; return end
    for _, r in ipairs(rows) do
        spots[r.id] = { id = r.id, name = r.name, district = r.district or "", x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z),
            heading = tonumber(r.heading) or 0, by = r.created_by or "", at = (tonumber(r.at) or 0) * 1000 }
    end
end
local function spotList()
    local list = {}
    for _, s in pairs(spots) do list[#list + 1] = s end
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
    return list
end
SE.spots = function() loadSpots(); return spotList() end

-- ---------------------------------------------------------------------------
-- Building an event

local KINDS = { boss = true, psycho = true, gang = true }
local WHERE = { origin = true, here = true, player = true, spot = true }

-- The point of an event: { x, y, z, heading, label }, or nil + why. "point" is internal
-- (an event night's fixed point).
local function resolvePlace(player, spec)
    if spec.where == "point" and spec.point then return spec.point end
    if spec.where == "here" then
        if not player or player == 0 then return nil, "The console has no position: choose a spot or a player." end
        local p = positionOf(player)
        if not p then return nil, "Your position is unavailable." end
        if p.bucket ~= 0 then return nil, "Go back to the city first: you are in an instance." end
        return { x = p.x, y = p.y, z = p.z, heading = p.heading, label = spec.district or "" }
    elseif spec.where == "player" then
        local id = finite(spec.target)
        if not id or not GetPlayerName(id) then return nil, "That player is not connected." end
        local p = positionOf(id)
        if not p then return nil, "That player's position is unavailable." end
        if p.bucket ~= 0 then return nil, "That player is in an instance (a mission, an activity, an interior)." end
        return { x = p.x, y = p.y, z = p.z, heading = p.heading, label = "" }
    elseif spec.where == "spot" then
        loadSpots()
        local s = spots[spec.spot]
        if not s then return nil, "That spot no longer exists. Refresh." end
        return { x = s.x, y = s.y, z = s.z, heading = s.heading, label = s.name }
    end
    return nil, "Choose where the event happens."
end

local function counted(n, level) return clamp(round(n * level.count), 1, D.MAX_COUNT) end

local function buildPsycho(spec, place, level, minutes, radius, location)
    local enemy = D.ENEMY[spec.enemy or ""]
    if spec.enemy == nil or spec.enemy == "" or spec.enemy == "random" then enemy = pick(psychos()) end
    if not enemy or not enemy.psycho then return nil, "Choose a cyberpsycho." end
    local P = C.psycho
    local name = (spec.name or "") ~= "" and spec.name or pick(P.names)
    return {
        id = newId("psycho"), title = P.title, description = "", location = location, type = "eliminate", enabled = true,
        point = xyz(place), perimeter = circle(place, radius), starts = { { x = place.x, y = place.y, z = place.z, heading = place.heading } },
        spawns = { { id = "psycho", label = name, position = xyz(place), heading = place.heading, enemy = enemy.id, count = 1,
            trigger = "start", behavior = "assault", radius = math.min(60, radius), alertRange = math.min(150, P.alertRange or 45), spread = 0 } },
        worldBoss = { enabled = true, boss = "psycho", health = clamp(round(P.health * level.health), 1, 200),
            reward = P.reward, minShare = P.minShare, minutes = minutes },
        difficulties = { { id = "standard", enemyHealth = 1, enemyDamage = clamp(level.damage, 0.25, 5), enemyCount = 1 } },
    }, { kind = "psycho", custom = true, words = P.words, look = P.look, announce = P.announce }
end

-- `warlord`: another enemy to lead the gang (a Siege's last round: a cyberpsycho).
local function buildGang(spec, place, level, minutes, radius, location, warlord)
    local crew = crewOf(spec.crew or "")
    if spec.crew == nil or spec.crew == "" or spec.crew == "random" then crew = pick(C.gang.crews) end
    if not crew then return nil, "Choose a gang." end
    local G = C.gang
    local lead = warlord or crew.warlord
    if not D.ENEMY[lead] then return nil, "This gang's warlord is not a known enemy." end
    local name = (spec.name or "") ~= "" and spec.name or (warlord and "Psycho warlord" or crew.title)
    local spawns = { { id = "warlord", label = name, position = xyz(place), heading = place.heading, enemy = lead, count = 1,
        trigger = "start", behavior = warlord and "assault" or "defend", radius = 12, alertRange = G.alertRange, spread = 0 } }
    for i, g in ipairs(crew.squad) do
        spawns[#spawns + 1] = { id = "squad" .. i, label = crew.label, position = ring(place, G.guardRing, i, #crew.squad, 0.5),
            heading = place.heading, enemy = g[1], count = counted(g[2], level), trigger = "start", behavior = "defend",
            radius = 15, alertRange = G.alertRange, spread = 3 }
    end
    local edge = radius * (G.waveRing or 0.8)
    for i, g in ipairs(crew.waves) do
        local p = ring(place, edge, i, #crew.waves, 1.2)
        spawns[#spawns + 1] = { id = "wave" .. i, label = crew.label .. " backup", position = p, heading = yawTo(p, place),
            enemy = g[1], count = counted(g[2], level), trigger = "checkpoint", behavior = "assault", radius = 20, alertRange = 150, spread = 3 }
    end
    return {
        id = newId("gang"), title = crew.label .. (warlord and " siege" or " attack"), description = "", location = location,
        type = "eliminate", enabled = true, point = xyz(place), perimeter = circle(place, radius),
        starts = { { x = place.x, y = place.y, z = place.z, heading = place.heading } }, spawns = spawns,
        worldBoss = { enabled = true, boss = "warlord", health = clamp(round(G.health), 1, 200), reward = G.reward, minShare = G.minShare, minutes = minutes },
        difficulties = { { id = "standard", enemyHealth = clamp(level.health, 0.25, 5), enemyDamage = clamp(level.damage, 0.25, 5), enemyCount = 1 } },
    }, { kind = "gang", custom = true, words = G.words, look = G.look, announce = G.announce }
end

-- A world boss of the catalogue: the level on its first difficulty and on its guards'
-- numbers (the boss stays one); moved (`place`), a compact layout around the point, since
-- the authored cover means nothing elsewhere: the boss on it, the other start groups on a
-- ring at 9 m, the reinforcements from the edge of the zone; patrols defend instead.
local function buildBoss(spec, place, level, minutes, radius, location)
    local base = bossDef(spec.boss)
    if not base then return nil, "That world boss is not in the catalogue (tag a mission \"World boss\" in /lightrp.missions)." end
    local d = D.clone(base)
    local bossId = d.worldBoss.boss
    local d1 = d.difficulties[1]
    d1.enemyHealth = clamp(d1.enemyHealth * level.health, 0.25, 5)
    d1.enemyDamage = clamp(d1.enemyDamage * level.damage, 0.25, 5)
    for _, s in ipairs(d.spawns) do
        if s.id ~= bossId then s.count = counted(s.count, level)
        elseif (spec.name or "") ~= "" then s.label = spec.name end
    end
    if minutes then d.worldBoss.minutes = minutes end
    if not place then return d, { kind = "boss", custom = false, validated = true } end
    local starts, others = {}, {}
    for _, s in ipairs(d.spawns) do
        s.route = {}
        if s.behavior == "patrol" then s.behavior = "defend" end
        s.radius = math.min(s.radius or 12, radius)
        if s.id == bossId then s.position, s.heading = xyz(place), place.heading
        elseif s.trigger == "start" then starts[#starts + 1] = s
        else others[#others + 1] = s end
    end
    for i, s in ipairs(starts) do s.position = ring(place, 9, i, #starts, 0.5) end
    for i, s in ipairs(others) do
        local p = ring(place, radius * 0.8, i, #others, 1.2)
        s.position, s.heading, s.trigger = p, yawTo(p, place), "checkpoint"
    end
    d.type, d.checkpoints, d.waves = "eliminate", {}, {}
    d.perimeter, d.point = circle(place, radius), xyz(place)
    d.starts = { { x = place.x, y = place.y, z = place.z, heading = place.heading } }
    d.location = location
    d.spawnById = nil
    return d, { kind = "boss", custom = false }
end

-- A spec (from the page, a command or a night) -> the running event, or nil + why.
local function launch(actorName, spec, player)
    local W = engine()
    if not W then return nil, "The world boss engine is not loaded." end
    local level = levelOf(spec.level)
    -- a world boss of the catalogue keeps its authored time unless the staff pick one
    local minutes = finite(spec.minutes) and clamp(math.floor(finite(spec.minutes)), C.minutes.min, C.minutes.max) or nil
    local fixed = minutes or C.minutes.default
    local radius = clamp(math.floor(finite(spec.radius) or C.radius.default), C.radius.min, C.radius.max)
    local place, why
    if not (spec.kind == "boss" and spec.where == "origin") then
        place, why = resolvePlace(player, spec)
        if not place then return nil, why end
    end
    local location = (spec.location or "") ~= "" and spec.location or (place and (place.label or "") ~= "" and place.label) or nil
    if location then location = cut(location, 40) end
    if location == "" then location = nil end
    local raw, meta
    if spec.kind == "psycho" then raw, meta = buildPsycho(spec, place, level, fixed, radius, location or "Night City")
    elseif spec.kind == "gang" then raw, meta = buildGang(spec, place, level, fixed, radius, location or "Night City", spec.warlord)
    elseif spec.kind == "boss" then raw, meta = buildBoss(spec, place, level, minutes, radius, location or "Night City")
    else return nil, "Choose a kind of event." end
    if not raw then return nil, meta end
    local def = raw
    if not meta.validated then
        local id = raw.id
        local v, bad = D.validate(raw)
        if not v then return nil, "The event could not be built: " .. tostring(bad) end
        v.id = id
        def = v
    end
    if spec.kind == "boss" and spec.where == "origin" and (spec.location or "") ~= "" then def.location = spec.location end
    local ok, ev = W.start(def, "staff:" .. tostring(actorName), { custom = meta.custom, kind = meta.kind, pay = spec.pay == true,
        silent = spec.silent == true, by = actorName, words = meta.words, look = meta.look, announce = meta.announce })
    if not ok then return nil, ev end
    ev.nightId = spec.night
    return ev
end
SE.launch = launch

-- The page's launch request -> a spec, or nil + why.
local function specOf(p)
    if not KINDS[p.kind] then return nil, "Choose a kind of event." end
    if not WHERE[p.where] then return nil, "Choose where the event happens." end
    if p.where == "origin" and p.kind ~= "boss" then return nil, "Only a world boss of the catalogue has its own place." end
    local location, name, district = clean(p.location, 40), clean(p.name, 32), clean(p.district, 48)
    if not location then return nil, "The place name is limited to 40 characters." end
    if not name then return nil, "The boss name is limited to 32 characters." end
    local function key(v) return type(v) == "string" and #v <= 64 and v:match("^[%w_%-]*$") and v or nil end
    return { kind = p.kind, where = p.where, boss = key(p.boss), enemy = key(p.enemy), crew = key(p.crew), spot = key(p.spot),
        target = finite(p.target), level = key(p.level), minutes = finite(p.minutes), radius = finite(p.radius),
        pay = p.pay == true, silent = p.silent == true, location = location, name = name, district = district or "" }
end
SE.specOf = specOf

local function describe(spec)
    local what = spec.kind == "psycho" and "Cyberpsycho" or spec.kind == "gang" and ("Gang attack: " .. tostring(spec.crew or "random"))
        or ("World boss: " .. tostring(spec.boss))
    local where = spec.where == "spot" and ("spot " .. tostring(spec.spot)) or spec.where == "player" and ("on player #" .. tostring(spec.target)) or spec.where
    return string.format("%s · %s · %s · %s%s", what, where, tostring(spec.level or "normal"), spec.pay and "paid" or "no pay", spec.silent and " · silent" or "")
end

-- ---------------------------------------------------------------------------
-- Audit (lightrp_staff_audit, created by admin.lua)

local function actorOf(player)
    if not player or player == 0 then return { identifier = "console", name = "Console" } end
    local c = S.identity(player)
    if not c then return nil end
    return { identifier = c.identifier, name = GetPlayerName(player) or "?" }
end
local function mutationOf(p)
    local m = p.mutation
    if type(m) == "string" and #m >= 8 and #m <= 96 and m:match("^[%w:_%-]+$") then return m end
end
local function audited(player, op, targetId, targetName, reason, mutation, act)
    local actor = actorOf(player)
    if not actor then return nil, "Your account is still loading." end
    if not mutation then seq = seq + 1; mutation = ("event:%d:%d"):format(unix(), seq) end
    if Db.ready then
        local ok, previous = Db.read("SELECT outcome, detail FROM lightrp_staff_audit WHERE actor_id = ? AND request_key = ?", { actor.identifier, mutation })
        if not ok then return nil, "The audit log is unavailable; nothing was changed." end
        if previous[1] then
            local r = previous[1]
            return { accepted = r.outcome == "success", outcome = r.outcome, message = r.detail }
        end
        local saved = Db.run([[INSERT INTO lightrp_staff_audit (actor_id, actor_name, target_id, target_name, character_key, action, reason, detail, request_key)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { actor.identifier, actor.name, tostring(targetId):sub(1, 128), tostring(targetName):sub(1, 96), "", op,
            tostring(reason):sub(1, 500), "", mutation })
        if not saved then return nil, "The audit could not be saved; nothing was changed." end
    end
    local called, success, label = pcall(act)
    if not called then log("staff event %s failed: %s", op, tostring(success)); success, label = false, "The action failed; see the server log." end
    label = tostring(label or (success and "Done." or "Refused."))
    local written = true
    if Db.ready then
        written = Db.run("UPDATE lightrp_staff_audit SET outcome = ?, detail = ? WHERE actor_id = ? AND request_key = ?",
            { success and "success" or "failed", label:sub(1, 500), actor.identifier, mutation })
    end
    log("staff %s (%s) by %s: %s", op, tostring(targetName), actor.name, label)
    return { accepted = success == true, outcome = written and (success and "success" or "failed") or "pending", message = label }
end

-- Alive: a teleport; dead: a respawn there (LightRP.staff.moveTo), into the city.
local function teleport(player, p, heading)
    local done, ok, why = false, false, nil
    LightRP.staff.moveTo(player, { x = p.x, y = p.y, z = p.z + 0.5 }, heading or 0, function(success, failure) ok, why, done = success, failure, true end, 0)
    local deadline = now() + 15000
    while not done and now() < deadline do Wait(20) end
    return ok == true, ok and "Teleported." or tostring(why or "The teleport did not answer.")
end

-- ---------------------------------------------------------------------------
-- Event nights

local function nightView()
    local n = night
    if not n then return nil end
    return { preset = n.preset, label = n.label, round = n.index, rounds = #n.rounds, phase = n.phase,
        nextInMs = (n.phase == "intro" or n.phase == "break") and math.max(0, n.at - now()) or nil,
        won = n.won, played = n.played, live = (function() local k = 0 for _ in pairs(n.live) do k = k + 1 end return k end)(), by = n.by }
end
SE.night = function() return night end

local function announce(title, body) LightRP.broadcastNotice({ kind = "warning", title = title, body = body, durationMs = 12000 }) end

-- A night's plan: an array of rounds, each an array of specs. `p` from the page or a
-- command: { preset, rounds, where = "spots" | "here", level, minutes, pay }.
local function planNight(player, p)
    local preset = presetOf(p.preset)
    if not preset then return nil, "Choose an event night." end
    local N = C.nights
    local rounds = clamp(math.floor(finite(p.rounds) or preset.rounds), preset.min or 1, N.maxRounds)
    local _, base = levelOf(p.level)
    local minutes = finite(p.minutes)
    local function levelAt(i, n) return C.levels[math.min(#C.levels, base + math.floor((i - 1) * 3 / math.max(1, n)))].id end
    local points
    if p.where == "here" then
        local me = player and player ~= 0 and positionOf(player)
        if not me then return nil, "The console has no position: use the saved spots." end
        if me.bucket ~= 0 then return nil, "Go back to the city first: you are in an instance." end
        points = { { where = "point", point = { x = me.x, y = me.y, z = me.z, heading = me.heading, label = clean(p.district, 48) or "" } } }
    else
        loadSpots()
        local list = spotList()
        if #list == 0 then return nil, "Save a few spots first (Events > Spots), or run it here." end
        points = {}
        for _, s in ipairs(shuffled(list)) do points[#points + 1] = { where = "spot", spot = s.id } end
    end
    local function at(i, spec)
        local q = points[((i - 1) % #points) + 1]
        spec.where, spec.spot, spec.point = q.where, q.spot, q.point
        spec.minutes, spec.pay, spec.location, spec.name, spec.night = minutes, p.pay == true, "", "", true
        return spec
    end
    local plan = {}
    if preset.id == "psycho_night" then
        for i = 1, rounds do
            local round = { at(i, { kind = "psycho", enemy = "random", level = levelAt(i, rounds) }) }
            -- the last round: two at once, at two spots (one point: one psycho, the hardest)
            if i == rounds and #points > 1 then round[2] = at(i + 1, { kind = "psycho", enemy = "random", level = levelAt(i, rounds) }) end
            plan[i] = round
        end
    elseif preset.id == "boss_rush" then
        local list = shuffled(catalogue())
        if #list == 0 then return nil, "No world boss in the catalogue (tag a mission \"World boss\" in /lightrp.missions)." end
        for i = 1, math.min(rounds, #list) do
            plan[i] = { { kind = "boss", where = "origin", boss = list[i].id, level = C.levels[base].id, minutes = minutes, pay = p.pay == true, location = "", name = "", night = true } }
        end
    elseif preset.id == "gang_war" then
        local count = clamp(rounds, 2, engine() and engine().maxLive() or 4)
        if p.where == "here" or #points < count then return nil, string.format("Gang War needs %d saved spots, one per gang.", count) end
        local crews = shuffled(C.gang.crews)
        local round = {}
        for i = 1, count do round[i] = at(i, { kind = "gang", crew = crews[((i - 1) % #crews) + 1].id, level = C.levels[base].id }) end
        plan[1] = round
    elseif preset.id == "siege" then
        local crews = shuffled(C.gang.crews)
        for i = 1, rounds do
            local spec = at(1, { kind = "gang", crew = crews[((i - 1) % #crews) + 1].id, level = levelAt(i, rounds) })
            if i == rounds then spec.warlord = pick(psychos()).id end
            plan[i] = { spec }
        end
    end
    return plan, preset
end

local function launchRound(n)
    local round = n.rounds[n.index] or {}
    local made = 0
    for _, spec in ipairs(round) do
        local s = D.clone(spec)
        s.night = n.id
        local ev, why = launch(n.by, s, nil)
        if ev then n.live[ev.id] = true; made = made + 1; n.played = n.played + 1
        else log("event night %s round %d: %s", n.label, n.index, tostring(why)) end
    end
    return made
end

local function nightOver(n)
    n.phase = "done"
    announce(C.nights.announce.title, fill(C.nights.announce.over, { name = n.label, won = n.won, played = n.played }))
    log("event night %s over: %d of %d won", n.label, n.won, n.played)
end

local function nightTick()
    local n = night
    if not n or n.phase == "done" then return end
    local t = now()
    if n.phase == "intro" or n.phase == "break" then
        if t < n.at then return end
        if n.phase == "intro" then n.index, n.phase = 1, "break" end
        if launchRound(n) > 0 then n.phase, n.tries = "live", 0; return end
        -- the engine is full (other events) or the round could not be built: retry, then skip
        n.tries = (n.tries or 0) + 1
        if n.tries >= 6 then
            n.tries = 0
            if n.index >= #n.rounds then nightOver(n); return end
            n.index = n.index + 1
        end
        n.at = t + 10000
        return
    end
    if n.phase == "live" and next(n.live) == nil then
        local N = C.nights
        if n.index >= #n.rounds then nightOver(n); return end
        n.index = n.index + 1
        n.phase, n.at = "break", t + N.breakSeconds * 1000
        announce(N.announce.title, fill(N.announce.next, { name = n.label, round = n.index, rounds = #n.rounds, seconds = N.breakSeconds }))
    end
end

function SE.onWorldEventClosed(ev)
    local n = night
    if not n or not n.live[ev.id] then return end
    n.live[ev.id] = nil
    if ev.success then n.won = n.won + 1 end
end

local function startNight(actorName, player, p)
    if night and night.phase ~= "done" then return nil, night.label .. " is already running: stop it first." end
    local plan, preset = planNight(player, p)
    if not plan then return nil, preset end
    if #plan == 0 then return nil, "Nothing to play." end
    local N = C.nights
    seq = seq + 1
    night = { id = "night-" .. seq, preset = preset.id, label = preset.label, rounds = plan, index = 0, phase = "intro",
        at = now() + N.introSeconds * 1000, live = {}, won = 0, played = 0, by = actorName, pay = p.pay == true }
    announce(N.announce.title, fill(N.announce.start, { name = preset.label, seconds = N.introSeconds, blurb = preset.blurb }))
    return night
end
SE.startNight = startNight

local function stopNight(callOff)
    local n = night
    if not n or n.phase == "done" then return false, "No event night is running." end
    n.phase = "done"
    local ended = 0
    if callOff then
        local W = engine()
        for id in pairs(n.live) do
            local ev = W and W.event(id)
            if ev and ev.phase == "fight" then W.finish(ev, false, "The staff ended the event night."); ended = ended + 1 end
        end
    end
    announce(C.nights.announce.title, n.label .. " is over.")
    return true, ended > 0 and string.format("%s stopped; %d event(s) called off.", n.label, ended) or (n.label .. " stopped; the events still out play on.")
end

-- ---------------------------------------------------------------------------
-- The desk (support.lua dispatches admin handlers): the view and the actions

local function row(ev, me)
    local c = ev.def.perimeter.center
    return { id = ev.id, kind = ev.kind or "boss", title = ev.def.title, boss = ev.bossLabel, location = ev.location, phase = ev.phase,
        health = math.floor((ev.bossFraction or 0) * 100 + 0.5), fighters = ev.fighters or 0,
        enemies = (ev.run and ev.run.alive or 0) + (ev.run and #ev.run.queue or 0),
        endsInMs = ev.phase == "fight" and math.max(0, ev.endsAt - now()) or nil, by = ev.by or "Random", pay = not ev.noPay,
        silent = ev.silent or nil, night = ev.nightId and true or nil, distance = me and math.floor(distance(me, c) + 0.5) or nil }
end

function SE.view(player)
    if not desk(player, "events") then return nil, "Events permission required." end
    loadSpots()
    local W = engine()
    local me = positionOf(player)
    if me and me.bucket ~= 0 then me = nil end
    local live = {}
    for _, ev in ipairs(W and W.events() or {}) do live[#live + 1] = row(ev, me) end
    local bosses = {}
    for _, d in ipairs(catalogue()) do bosses[#bosses + 1] = { id = d.id, title = d.title, location = d.location ~= "" and d.location or "Night City" } end
    local psychoList = {}
    for _, e in ipairs(psychos()) do psychoList[#psychoList + 1] = { id = e.id, label = (e.label:gsub("^Cyberpsycho: ", "")) } end
    local crews = {}
    for _, c in ipairs(C.gang.crews) do crews[#crews + 1] = { id = c.id, label = c.label } end
    local levels = {}
    for _, l in ipairs(C.levels) do levels[#levels + 1] = { id = l.id, label = l.label, blurb = l.blurb } end
    local presets = {}
    for _, n in ipairs(C.nights.presets) do presets[#presets + 1] = { id = n.id, label = n.label, blurb = n.blurb, rounds = n.rounds, min = n.min or 1 } end
    local spotRows = {}
    for _, s in ipairs(spotList()) do
        spotRows[#spotRows + 1] = { id = s.id, name = s.name, district = s.district, by = s.by, distance = me and math.floor(distance(me, s) + 0.5) or nil }
    end
    local nextAt = W and W.nextAt and W.nextAt()
    return { live = live, bosses = bosses, psychos = psychoList, crews = crews, levels = levels, presets = presets, spots = spotRows,
        night = nightView(), maxLive = W and W.maxLive() or 0, maxRounds = C.nights.maxRounds,
        random = { enabled = LightRpWorldBosses and LightRpWorldBosses.enabled ~= false or false, nextInMs = nextAt and math.max(0, nextAt - now()) or nil },
        minutes = C.minutes, radius = C.radius, canPay = desk(player, "eventsPay"), inCity = me ~= nil }
end

local function liveEvent(id)
    local W = engine()
    local ev = W and type(id) == "string" and W.event(id)
    return ev, W
end

function SE.action(player, p)
    if not desk(player, "events") then return nil, "Events permission required." end
    local op = p.action
    local note = clean(p.reason, 500)
    if not note then return nil, "The note is limited to 500 characters." end
    local actor = GetPlayerName(player) or "Staff"
    if op == "launch" then
        if p.confirmed ~= true then return nil, "Review the event first." end
        local spec, why = specOf(p)
        if not spec then return nil, why end
        if spec.pay and not desk(player, "eventsPay") then return nil, "A paid event needs the world boss right (command.worldboss.start)." end
        local text = describe(spec)
        return audited(player, "eventLaunch", spec.kind .. ":" .. spec.where, text, note ~= "" and note or text, mutationOf(p), function()
            local ev, bad = launch(actor, spec, player)
            if not ev then return false, bad end
            return true, string.format("%s is out in %s%s.", ev.bossLabel, ev.location, ev.silent and " (silent)" or "")
        end)
    elseif op == "stop" or op == "win" then
        if p.confirmed ~= true then return nil, "Confirm first." end
        local ev, W = liveEvent(p.id)
        if not ev then return nil, "That event is over. Refresh." end
        if ev.phase ~= "fight" then return nil, "That event is already ending." end
        if op == "win" and not ev.noPay and not desk(player, "eventsPay") then return nil, "Ending a paid event as a win pays its fighters: it needs the world boss right." end
        local title = ev.def.title .. " · " .. ev.bossLabel
        return audited(player, op == "win" and "eventWin" or "eventStop", ev.id, title, note ~= "" and note or title, mutationOf(p), function()
            if ev.phase ~= "fight" then return false, "That event is already ending." end
            if op == "win" then W.finish(ev, true) else W.finish(ev, false, "Called off by the staff.") end
            return true, op == "win" and "Ended as a win: the shares are settled as fought." or "Called off: nobody is paid."
        end)
    elseif op == "goto" then
        local ev = liveEvent(p.id)
        local target, heading
        if ev then
            local c, r = ev.def.perimeter.center, ev.def.perimeter.radius or 30
            target = { x = c.x, y = c.y - math.min(40, r * 0.6), z = c.z }
            heading = 0
        else
            loadSpots()
            local s = spots[p.spot]
            if not s then return nil, "That event or spot is gone. Refresh." end
            target, heading = s, s.heading
        end
        return audited(player, "eventGoto", ev and ev.id or p.spot, ev and ev.def.title or spots[p.spot].name, note ~= "" and note or "Go to", mutationOf(p),
            function() return teleport(player, target, heading) end)
    elseif op == "night" then
        if p.confirmed ~= true then return nil, "Review the night first." end
        if p.pay == true and not desk(player, "eventsPay") then return nil, "A paid night needs the world boss right (command.worldboss.start)." end
        local preset = presetOf(p.preset)
        if not preset then return nil, "Choose an event night." end
        local q = { preset = p.preset, rounds = p.rounds, where = p.where == "here" and "here" or "spots", level = p.level, minutes = p.minutes,
            pay = p.pay == true, district = p.district }
        local text = string.format("%s · %s round(s) · %s · %s", preset.label, tostring(q.rounds or preset.rounds), q.where, q.pay and "paid" or "no pay")
        return audited(player, "eventNight", preset.id, text, note ~= "" and note or text, mutationOf(p), function()
            local n, why = startNight(actor, player, q)
            if not n then return false, why end
            return true, string.format("%s announced: %d round(s), the first in %d s.", n.label, #n.rounds, C.nights.introSeconds)
        end)
    elseif op == "nightStop" then
        if p.confirmed ~= true then return nil, "Confirm first." end
        local label = night and night.label or "Event night"
        return audited(player, "eventNightStop", night and night.id or "night", label, note ~= "" and note or label, mutationOf(p),
            function() return stopNight(p.callOff == true) end)
    elseif op == "spotSave" then
        local name = clean(p.name, 40)
        if not name or name == "" then return nil, "Name the spot (1–40 characters)." end
        local me = positionOf(player)
        if not me then return nil, "Your position is unavailable." end
        if me.bucket ~= 0 then return nil, "Spots are in the city: you are in an instance." end
        loadSpots()
        local count = 0
        for _ in pairs(spots) do count = count + 1 end
        if count >= C.spots.max then return nil, string.format("At most %d spots: remove one first.", C.spots.max) end
        seq = seq + 1
        local s = { id = ("sp%x%03x%02x"):format(unix(), math.random(0, 0xfff), seq % 256), name = name, district = clean(p.district, 48) or "",
            x = me.x, y = me.y, z = me.z, heading = me.heading, by = actor, at = unix() * 1000 }
        return audited(player, "eventSpotSave", s.id, name, note ~= "" and note or name, mutationOf(p), function()
            if Db.ready and not Db.run("INSERT INTO lightrp_event_spots (id, name, district, x, y, z, heading, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                { s.id, s.name, s.district, s.x, s.y, s.z, s.heading, s.by }) then return false, "The spot could not be saved." end
            spots[s.id] = s
            return true, string.format("Spot \"%s\" saved%s.", s.name, s.district ~= "" and (" in " .. s.district) or "")
        end)
    elseif op == "spotDelete" then
        if p.confirmed ~= true then return nil, "Confirm first." end
        loadSpots()
        local s = spots[p.spot]
        if not s then return nil, "That spot is already gone. Refresh." end
        return audited(player, "eventSpotDelete", s.id, s.name, note ~= "" and note or s.name, mutationOf(p), function()
            if Db.ready and not Db.run("DELETE FROM lightrp_event_spots WHERE id = ?", { s.id }) then return false, "The spot could not be removed." end
            spots[s.id] = nil
            return true, string.format("Spot \"%s\" removed.", s.name)
        end)
    elseif op == "random" or op == "next" then
        -- the random world bosses pay: the world boss right
        if not desk(player, "eventsPay") then return nil, "The random world bosses need the world boss right (command.worldboss.start)." end
        local W = engine()
        if not W then return nil, "The world boss engine is not loaded." end
        local text = op == "random" and ("Random world bosses " .. (p.enabled == true and "on" or "off")) or ("Next random world boss in " .. tostring(p.minutes) .. " min")
        return audited(player, op == "random" and "eventRandom" or "eventNext", "worldbosses", text, note ~= "" and note or text, mutationOf(p), function()
            if op == "random" then
                LightRpWorldBosses.enabled = p.enabled == true
                return true, LightRpWorldBosses.enabled and "Random world bosses are on (until the next restart)." or "Random world bosses are off until the next restart."
            end
            local m = finite(p.minutes)
            if not m or m < 0 or m > 600 then return false, "Choose 0–600 minutes." end
            W.setNext(now() + math.floor(m) * 60000)
            return true, string.format("The next random world boss comes in %d min (if random spawns are on).", math.floor(m))
        end)
    end
    return nil, "Unknown event action."
end

if LightRP.admin and LightRP.admin.handlers then
    LightRP.admin.handlers.events = SE.view
    LightRP.admin.handlers.eventsAction = SE.action
end

CreateThread(function()
    while true do
        Wait(1000)
        if night then
            local ok, err = pcall(nightTick)
            if not ok then log("event night: tick failed: %s", tostring(err)) end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- /lightrp.event: the same from the chat (here, no pay, announced)

local USAGE = "/lightrp.event psycho [psycho|random] [normal|hard|brutal] · gang [gang|random] [level] · boss <title> [here] [level]"
    .. " · night <psycho_night|boss_rush|gang_war|siege> [rounds] [here] · stopnight · stop [all] · list"
LightRP.command("lightrp.event", { restricted = true, usage = USAGE }, function(player, args)
    local sub = tostring(args[1] or "list"):lower()
    local W = engine()
    if not W then return false, "The world boss engine is not loaded." end
    local actor = player and player ~= 0 and GetPlayerName(player) or "Console"
    local function levelArg(i) for j = i, #args do local l = levelOf(args[j]); if l.id == args[j] then return l.id end end return "normal" end
    if sub == "list" then
        local out = {}
        for _, ev in ipairs(W.events()) do
            out[#out + 1] = string.format("%s: %s (%s, %d %%, %d fighter(s))", ev.id, ev.bossLabel, ev.location, math.floor((ev.bossFraction or 0) * 100), ev.fighters or 0)
        end
        local n = night and night.phase ~= "done" and string.format(" Night: %s round %d/%d (%s).", night.label, night.index, #night.rounds, night.phase) or ""
        return true, (#out > 0 and table.concat(out, "; ") or "No world event is out.") .. n
    elseif sub == "stop" then
        local all, ended = args[2] == "all", 0
        local list = W.events()
        for i = #list, 1, -1 do
            local ev = list[i]
            if ev.phase == "fight" and (all or (ended == 0 and ev.by)) then W.finish(ev, false, "Called off by the staff."); ended = ended + 1 end
        end
        return ended > 0, ended > 0 and string.format("%d event(s) called off.", ended) or "No staff event is out (\"all\" ends the random one too)."
    elseif sub == "stopnight" then
        return stopNight(true)
    elseif sub == "psycho" or sub == "gang" or sub == "boss" then
        local spec = { kind = sub, where = "here", level = levelArg(2), pay = false, location = "", name = "", district = "" }
        if sub == "psycho" then spec.enemy = args[2] and D.ENEMY[args[2]] and args[2] or "random"
        elseif sub == "gang" then spec.crew = args[2] and crewOf(args[2]) and args[2] or "random"
        else
            local words = {}
            for i = 2, #args do if args[i] ~= "here" and levelOf(args[i]).id ~= args[i] then words[#words + 1] = args[i] end end
            local def = findBoss(table.concat(words, " "))
            if not def then return false, "No world boss matches (see /worldboss.list)." end
            spec.boss = def.id
            spec.where = "origin"
            for i = 2, #args do if args[i] == "here" then spec.where = "here" end end
        end
        local result = audited(player, "eventLaunch", sub .. ":" .. spec.where, describe(spec), "chat command", nil, function()
            local ev, why = launch(actor, spec, player)
            if not ev then return false, why end
            return true, string.format("%s is out in %s (%s).", ev.bossLabel, ev.location, ev.id)
        end)
        if not result then return false, "The audit log is unavailable." end
        return result.accepted, result.message
    elseif sub == "night" then
        local preset = presetOf(args[2])
        if not preset then return false, "Choose psycho_night, boss_rush, gang_war or siege." end
        local q = { preset = preset.id, rounds = tonumber(args[3]), where = "spots", level = "normal", pay = false }
        for i = 3, #args do if args[i] == "here" then q.where = "here" end end
        local result = audited(player, "eventNight", preset.id, preset.label, "chat command", nil, function()
            local n, why = startNight(actor, player, q)
            if not n then return false, why end
            return true, string.format("%s announced: %d round(s).", n.label, #n.rounds)
        end)
        if not result then return false, "The audit log is unavailable." end
        return result.accepted, result.message
    end
    return false, USAGE
end)
