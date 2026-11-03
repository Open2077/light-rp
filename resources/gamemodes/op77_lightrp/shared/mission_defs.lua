-- Missions authored in game (staff mission editor). One definition is a whole
-- mission: where its board stands in the city, where the squad starts in its
-- instance, the perimeter it must stay in, the enemy spawn points, the
-- checkpoints that wake spawn points up, and for the survival type its waves.
--
--   type "eliminate"  kill every enemy of the zone: the start spawns, then the
--                     ones each checkpoint wakes up. Done once every required
--                     checkpoint was reached and no enemy is left standing.
--   type "waves"      survive the waves in order; a wave starts its delay after
--                     the previous one is cleared. Done when the last is cleared.
--
-- The perimeter has the safezone geometry (circle, box, polygon; floor/ceiling
-- or full height). Out of it an operator gets a warning and a countdown of
-- `outOfBounds.graceSeconds`; still out at zero, the character dies.
-- Validation here is the single contract: the editor page, the client preview
-- and the server (storage and runtime) all go through it.
local G = LightRpSafezoneGeometry
local M = { MAX_MISSIONS = 64, MAX_SPAWNS = 48, MAX_CHECKPOINTS = 16, MAX_WAVES = 20, MAX_STARTS = 8,
    SPAWN_RANGE = 300, MAX_COUNT = 12, MAX_ALIVE = 40 }
LightRpMissionDefs = M

M.TYPES = { "eliminate", "waves" }
M.TYPE_LABELS = { eliminate = "Elimination", waves = "Survival" }
M.TRIGGERS = { "start", "checkpoint", "wave" }

-- What a spawn point's squad does until it fights. Every behaviour but
-- `assault` waits for an alert: an operator within `alertRange` of one of them,
-- or one of them hurt; then the whole squad of that spawn point attacks.
--   assault  rush the nearest operator at once
--   defend   hold the area of `radius` around the spawn point, fight from it
--   patrol   walk the route (the spawn point, then its patrol points, in a loop)
--   wander   drift inside `radius` around the spawn point
--   ambush   stand still and silent (no combat, no perception) until alerted
M.BEHAVIORS = { "assault", "defend", "patrol", "wander", "ambush" }
M.BEHAVIOR_LABELS = { assault = "Assault", defend = "Defend the area", patrol = "Patrol a route", wander = "Wander", ambush = "Ambush" }
M.BEHAVIOR = {}
for _, b in ipairs(M.BEHAVIORS) do M.BEHAVIOR[b] = true end
M.MAX_ROUTE = 8

-- Enemies an author can place. `record` (TweakDB character) or `template`
-- (Open77 alias): both proven hostile in LightRP (the raid's adds).
-- 6th Street, the Wraiths (nomad raiders) and the Voodoo Boys are vanilla gang records picked
-- with the criteria of Open77's proven templates (docs/generated/npc-records-2.31.csv: category
-- gang, risk candidate, Ganger_Aggressive, armed, no quest). The cyberpsychos (`psycho = true`)
-- are the game's own Psycho Squad records: each one listed was spawned and checked in game (a
-- clothed body, hostile, killable); they make world bosses. Every mission enemy shares one
-- combat group (mission_engine.lua): mixed factions fight the players, not each other.
M.ENEMIES = {
    { id = "militech", label = "Militech trooper", record = "Character.max_border_guards", group = "Corporations" },
    { id = "militech_shotgun", label = "Militech breacher", record = "Character.max_border_guards_shotgun", group = "Corporations" },
    { id = "valentinos", label = "Valentinos gunner", template = "gang_valentinos_ranged_01", group = "Gangs" },
    { id = "tygerclaws", label = "Tyger Claws gunner", template = "gang_tygerclaws_ranged_01", group = "Gangs" },
    { id = "maelstrom", label = "Maelstrom ganger", template = "hostile_female_ranged_lab", group = "Gangs" },
    { id = "sixthstreet", label = "6th Street gunner", record = "Character.rcr_sixth_street_grunt_short_range_w_medium", group = "6th Street" },
    { id = "sixthstreet_shotgun", label = "6th Street breacher", record = "Character.rcr_sixth_street_grunt_short_range_m_hard", group = "6th Street" },
    { id = "sixthstreet_sniper", label = "6th Street sniper", record = "Character.rcr_sixth_street_sniper_long_range_m_medium", group = "6th Street" },
    { id = "wraiths", label = "Wraiths raider (nomads)", record = "Character.wraiths_grunt1_ranged1_nova_ma", group = "Nomads" },
    { id = "wraiths_gunner", label = "Wraiths gunner (nomads)", record = "Character.wraiths_grunt2_ranged2_copperhead_ma", group = "Nomads" },
    { id = "voodooboys", label = "Voodoo Boys gunner", record = "Character.voodooboys_grunt1_ranged2_saratoga_ma", group = "Voodoo Boys" },
    { id = "voodooboys_sidewinder", label = "Voodoo Boys enforcer", record = "Character.voodooboys_grunt1_ranged2_sidewinder_wa", group = "Voodoo Boys" },
    { id = "psycho_pacifica", label = "Cyberpsycho: Pacifica, Coastview", record = "Character.ma_pac_cvi_15_cyberpsycho", group = "Cyberpsychos", psycho = true },
    { id = "psycho_pacifica_2", label = "Cyberpsycho: Pacifica, Coastview II", record = "Character.ma_pac_cvi_08_psycho", group = "Cyberpsychos", psycho = true },
    { id = "psycho_downtown", label = "Cyberpsycho: City Center, Downtown", record = "Character.ma_cct_dtn_07_cyberpsycho", group = "Cyberpsychos", psycho = true },
    { id = "psycho_downtown_2", label = "Cyberpsycho: City Center, Downtown II", record = "Character.ma_cct_dtn_03_cyberpsycho", group = "Cyberpsychos", psycho = true },
    { id = "psycho_arroyo", label = "Cyberpsycho: Santo Domingo, Arroyo", record = "Character.ma_std_arr_06_cyberpsycho", group = "Cyberpsychos", psycho = true },
    { id = "psycho_rancho", label = "Cyberpsycho: Rancho Coronado", record = "Character.rcr_05_cyberpsycho", group = "Cyberpsychos", psycho = true },
    { id = "psycho_wellsprings", label = "Cyberpsycho: Heywood, Wellsprings", record = "Character.ma_hey_spr_04_cyberpsycho", group = "Cyberpsychos", psycho = true },
    { id = "psycho_wellsprings_2", label = "Cyberpsycho: Heywood, Wellsprings II", record = "Character.ma_hey_spr_06_cyberpsycho", group = "Cyberpsychos", psycho = true },
    { id = "psycho_kabuki", label = "Cyberpsycho: Watson, Kabuki", record = "Character.ma_wat_kab_08_cyberpsycho", group = "Cyberpsychos", psycho = true },
    { id = "psycho_kabuki_2", label = "Cyberpsycho: Watson, Kabuki II", record = "Character.ma_wat_kab_02_cyberpsycho", group = "Cyberpsychos", psycho = true },
    { id = "psycho_littlechina", label = "Cyberpsycho: Watson, Little China", record = "Character.ma_wat_lch_06_cyberpsycho", group = "Cyberpsychos", psycho = true },
    { id = "psycho_northside", label = "Cyberpsycho: Watson, Northside", record = "Character.ma_wat_nid_03_shard_psycho", group = "Cyberpsychos", psycho = true },
    { id = "psycho_northside_mantis", label = "Cyberpsycho: Northside (mantis blades)", record = "Character.ma_wat_nid_15_psycho", group = "Cyberpsychos", psycho = true },
    { id = "psycho_mox", label = "Cyberpsycho: Northside (Mox, mantis blades)", record = "Character.sts_wat_nid_01_cyberpsycho", group = "Cyberpsychos", psycho = true },
    { id = "psycho_badlands", label = "Cyberpsycho: Badlands", record = "Character.ma_bls_ina_se1_08_cyberpsycho", group = "Cyberpsychos", psycho = true },
    { id = "psycho_badlands_2", label = "Cyberpsycho: Badlands II", record = "Character.ma_bls_ina_se1_22_psycho", group = "Cyberpsychos", psycho = true },
}
M.ENEMY = {}
for _, e in ipairs(M.ENEMIES) do M.ENEMY[e.id] = e end

-- `payout`: each operator's share at the difficulty's `min` crew, before the crew
-- pot, cooldown and daily cap of server/modules/mission_pay.lua (docs/economy-balance.md).
M.DIFFICULTIES = {
    { id = "standard", label = "Standard", blurb = "The contract as written.", payout = 2400, minutes = 15, min = 1, max = 4,
        enemyHealth = 1, enemyDamage = 1, enemyCount = 1 },
    { id = "hard", label = "Hard", blurb = "More of them, and they hit harder.", payout = 3000, minutes = 15, min = 1, max = 4,
        enemyHealth = 1.5, enemyDamage = 1.25, enemyCount = 1.5 },
    { id = "critical", label = "Critical", blurb = "Bring your best kit and a full squad.", payout = 4400, minutes = 20, min = 2, max = 4,
        enemyHealth = 2.25, enemyDamage = 1.6, enemyCount = 2 },
}

local function clone(t) return G.clone(t) end
M.clone = clone
local function finite(n) return G.finite(n) end
local function within(n, low, high) return finite(n) and n >= low and n <= high end
local function key(s) return type(s) == "string" and #s >= 1 and #s <= 24 and s:match("^[%w_-]+$") ~= nil end
local function optionalText(s, max)
    if s == nil or s == "" then return "" end
    if type(s) ~= "string" then return nil end
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    local n = utf8.len(s)
    if not n or n > max or s:find("[%z\1-\9\11-\31]") then return nil end
    return s
end
local function list(t, max)
    if t == nil then return {} end
    if type(t) ~= "table" then return nil end
    local n = 0
    for k in pairs(t) do if not G.integer(k, 1, max) then return nil end; n = n + 1 end
    if n ~= #t then return nil end
    return t
end
local function heading(h) return finite(h) and h % 360 or 0 end
local function point(p) return G.point(p) end
local function distance2d(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end

-- Is a point inside a validated perimeter (same maths as the platform's
-- cylinder / box / poly, used for the editor's checks and as the server's
-- fallback when the zone service cannot answer)?
function M.inside(z, p)
    if not z.fullHeight and (p.z < z.minZ or p.z > z.maxZ) then return false end
    if z.shape == "circle" then return distance2d(z.center, p) <= z.radius end
    if z.shape == "box" then
        local a = -z.heading * math.pi / 180
        local dx, dy = p.x - z.center.x, p.y - z.center.y
        local x, y = dx * math.cos(a) - dy * math.sin(a), dx * math.sin(a) + dy * math.cos(a)
        return math.abs(x) <= z.length / 2 and math.abs(y) <= z.width / 2
    end
    local inside, n = false, #z.points
    for i = 1, n do
        local a, b = z.points[i], z.points[(i % n) + 1]
        if (a.y > p.y) ~= (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x then inside = not inside end
    end
    return inside
end

-- The perimeter in the safezone wire format (validated by the same function).
local function perimeter(raw)
    if type(raw) ~= "table" then return nil, "Draw the mission perimeter." end
    local z, why = G.validate({ label = "perimeter", bucket = 0, enabled = true, shape = raw.shape, center = raw.center,
        radius = raw.radius, length = raw.length, width = raw.width, heading = raw.heading, points = raw.points,
        minZ = raw.minZ, maxZ = raw.maxZ, fullHeight = raw.fullHeight == true })
    if not z then return nil, "Perimeter: " .. tostring(why) end
    local out = { shape = z.shape, center = z.center, minZ = z.minZ, maxZ = z.maxZ, fullHeight = z.fullHeight }
    if z.shape == "circle" then out.radius = z.radius
    elseif z.shape == "box" then out.length, out.width, out.heading = z.length, z.width, z.heading
    else out.points = z.points end
    return out
end

local function difficulties(raw)
    raw = type(raw) == "table" and raw or {}
    local byId = {}
    for _, d in ipairs(list(raw, 8) or {}) do if type(d) == "table" and type(d.id) == "string" then byId[d.id] = d end end
    local out = {}
    for i, base in ipairs(M.DIFFICULTIES) do
        local d = byId[base.id] or {}
        local v = { id = base.id, label = base.label, tier = 0 }
        v.blurb = optionalText(d.blurb, 120)
        if v.blurb == nil then return nil, base.label .. ": the description is too long." end
        if v.blurb == "" then v.blurb = base.blurb end
        v.payout = d.payout == nil and base.payout or d.payout
        v.minutes = d.minutes == nil and base.minutes or d.minutes
        v.min = d.min == nil and base.min or d.min
        v.max = d.max == nil and base.max or d.max
        if not G.integer(v.payout, 0, 1000000) then return nil, base.label .. ": payout must be 0–1,000,000." end
        if not G.integer(v.minutes, 3, 120) then return nil, base.label .. ": time limit must be 3–120 minutes." end
        if not G.integer(v.min, 1, 8) or not G.integer(v.max, v.min, 8) then return nil, base.label .. ": squad size must be 1–8 with min ≤ max." end
        for _, k in ipairs({ "enemyHealth", "enemyDamage", "enemyCount" }) do
            v[k] = d[k] == nil and base[k] or d[k]
            if not within(v[k], 0.25, 5) then return nil, base.label .. ": enemy multipliers must be 0.25–5." end
        end
        out[i] = v
    end
    return out
end

function M.validate(raw)
    if type(raw) ~= "table" then return nil, "Invalid mission." end
    local d = {}
    if raw.id ~= nil and raw.id ~= "" then
        if type(raw.id) ~= "string" or #raw.id > 64 or not raw.id:match("^[%w_-]+$") then return nil, "Invalid mission ID." end
        d.id = raw.id
    end
    d.title = G.text(raw.title, 60)
    if not d.title then return nil, "Choose a title of 1–60 characters." end
    d.description = optionalText(raw.description, 240)
    if not d.description then return nil, "The description is limited to 240 characters." end
    d.location = optionalText(raw.location, 40)
    if not d.location then return nil, "The location is limited to 40 characters." end
    if raw.type ~= "eliminate" and raw.type ~= "waves" then return nil, "Choose Elimination or Survival." end
    d.type = raw.type
    if type(raw.enabled) ~= "boolean" then return nil, "Invalid activation state." end
    d.enabled = raw.enabled
    d.point = point(raw.point)
    if not d.point then return nil, "Place the mission board (where players open the mission)." end

    local why
    d.perimeter, why = perimeter(raw.perimeter)
    if not d.perimeter then return nil, why end
    local center = { x = d.perimeter.center.x, y = d.perimeter.center.y, z = d.perimeter.center.z }

    local ob = type(raw.outOfBounds) == "table" and raw.outOfBounds or {}
    d.outOfBounds = { graceSeconds = ob.graceSeconds == nil and 10 or ob.graceSeconds }
    if not G.integer(d.outOfBounds.graceSeconds, 3, 60) then return nil, "Out-of-zone delay must be 3–60 seconds." end

    -- The kit handed out to the operators (server/modules/mission_engine.lua): a kit id of
    -- LightRpRaid.loadouts, or "none" for their own weapons. Absent: the first kit.
    if raw.loadout ~= nil then
        if type(raw.loadout) ~= "string" or #raw.loadout > 32 or not raw.loadout:match("^[%w_%-]+$") then
            return nil, "Invalid loadout."
        end
        d.loadout = raw.loadout
    end

    -- A fixer gig (server/modules/fixers.lua): no board in the city, nobody tags in.
    -- The fixers hand it out by message to a player, who can share it with contacts.
    --   contact  "any" (a random fixer) or the id of one of LightRpFixers.contacts
    --   brief    what the fixer writes about the job ("" = the mission description)
    d.fixer = { enabled = false, contact = "any", brief = "" }
    if raw.fixer ~= nil then
        local fx = raw.fixer
        if type(fx) ~= "table" or (fx.enabled ~= nil and type(fx.enabled) ~= "boolean") then return nil, "Invalid fixer settings." end
        local contact = fx.contact == nil and "any" or fx.contact
        if not key(contact) then return nil, "Fixer: invalid contact." end
        local brief = optionalText(fx.brief, 240)
        if brief == nil then return nil, "Fixer: the brief is limited to 240 characters." end
        d.fixer = { enabled = fx.enabled == true, contact = contact, brief = brief }
    end

    local rs = type(raw.respawn) == "table" and raw.respawn or {}
    d.respawn = { seconds = rs.seconds == nil and 10 or rs.seconds, lives = rs.lives == nil and 3 or rs.lives }
    if not G.integer(d.respawn.seconds, 3, 60) then return nil, "Respawn delay must be 3–60 seconds." end
    if not G.integer(d.respawn.lives, 0, 50) then return nil, "Team respawns must be 0–50." end

    local starts = list(raw.starts, M.MAX_STARTS)
    if not starts or #starts == 0 then return nil, "Place 1–8 squad start positions." end
    d.starts = {}
    for i, s in ipairs(starts) do
        local p = point(s)
        if not p then return nil, "Invalid start position " .. i .. "." end
        if not M.inside(d.perimeter, p) then return nil, "Start position " .. i .. " is outside the perimeter." end
        p.heading = heading(type(s) == "table" and s.heading)
        d.starts[i] = p
    end

    local spawns = list(raw.spawns, M.MAX_SPAWNS)
    if not spawns then return nil, "At most 48 spawn points." end
    d.spawns, d.spawnById = {}, nil
    local byId = {}
    for i, s in ipairs(spawns) do
        if type(s) ~= "table" or not key(s.id) or byId[s.id] then return nil, "Spawn point " .. i .. " has an invalid or duplicate ID." end
        local p = point(s.position)
        if not p then return nil, "Spawn point " .. i .. " has no position." end
        if distance2d(p, center) > M.SPAWN_RANGE then return nil, "Spawn point " .. i .. " is more than 300 m from the perimeter." end
        local label = optionalText(s.label, 40)
        if label == nil then return nil, "Spawn point " .. i .. ": name too long." end
        if not M.ENEMY[s.enemy] then return nil, "Spawn point " .. i .. ": choose an enemy." end
        if not G.integer(s.count, 1, M.MAX_COUNT) then return nil, "Spawn point " .. i .. ": 1–12 enemies." end
        if s.trigger ~= "start" and s.trigger ~= "checkpoint" and s.trigger ~= "wave" then return nil, "Spawn point " .. i .. ": choose when it spawns." end
        if d.type == "eliminate" and s.trigger == "wave" then return nil, "Spawn point " .. i .. ": waves only exist in Survival missions." end
        local behavior = s.behavior == nil and "assault" or s.behavior
        if not M.BEHAVIOR[behavior] then return nil, "Spawn point " .. i .. ": unknown behaviour." end
        local radius = s.radius == nil and 12 or s.radius
        local alertRange = s.alertRange == nil and 25 or s.alertRange
        local spread = s.spread == nil and 2 or s.spread
        if not within(radius, 1, 60) then return nil, "Spawn point " .. i .. ": area radius must be 1–60 m." end
        if not within(alertRange, 3, 150) then return nil, "Spawn point " .. i .. ": alert range must be 3–150 m." end
        if not within(spread, 0, 10) then return nil, "Spawn point " .. i .. ": group spread must be 0–10 m." end
        local route = list(s.route, M.MAX_ROUTE)
        if not route then return nil, "Spawn point " .. i .. ": at most 8 patrol points." end
        local points = {}
        for j, r in ipairs(route) do
            local q = point(r)
            if not q or distance2d(q, center) > M.SPAWN_RANGE then return nil, "Spawn point " .. i .. ": patrol point " .. j .. " is invalid or too far." end
            points[j] = q
        end
        if behavior == "patrol" and #points == 0 then return nil, "Spawn point " .. i .. ": a patrol needs at least one patrol point." end
        local v = { id = s.id, label = label ~= "" and label or ("Spawn " .. i), position = p, heading = heading(s.heading),
            enemy = s.enemy, count = s.count, trigger = s.trigger, behavior = behavior, radius = radius, alertRange = alertRange,
            spread = spread, route = points }
        d.spawns[i], byId[s.id] = v, v
    end

    local checkpoints = list(raw.checkpoints, M.MAX_CHECKPOINTS)
    if not checkpoints then return nil, "At most 16 checkpoints." end
    d.checkpoints = {}
    local used, cpIds = {}, {}
    for i, c in ipairs(checkpoints) do
        if type(c) ~= "table" or not key(c.id) or cpIds[c.id] then return nil, "Checkpoint " .. i .. " has an invalid or duplicate ID." end
        cpIds[c.id] = true
        local p = point(c.position)
        if not p then return nil, "Checkpoint " .. i .. " has no position." end
        if not M.inside(d.perimeter, p) then return nil, "Checkpoint " .. i .. " is outside the perimeter." end
        if not within(c.radius, 1, 30) then return nil, "Checkpoint " .. i .. ": radius must be 1–30 m." end
        local label = optionalText(c.label, 40)
        if label == nil then return nil, "Checkpoint " .. i .. ": name too long." end
        local ids = list(c.spawns, M.MAX_SPAWNS)
        if not ids then return nil, "Checkpoint " .. i .. ": invalid spawn list." end
        local v = { id = c.id, label = label ~= "" and label or ("Checkpoint " .. i), position = p, radius = c.radius,
            required = c.required ~= false, spawns = {} }
        for _, id in ipairs(ids) do
            local s = byId[id]
            if not s then return nil, "Checkpoint " .. i .. " wakes an unknown spawn point." end
            if s.trigger ~= "checkpoint" then return nil, "Checkpoint " .. i .. ": " .. s.label .. " is not a checkpoint spawn." end
            v.spawns[#v.spawns + 1] = id
            used[id] = true
        end
        d.checkpoints[i] = v
    end

    local waves = list(raw.waves, M.MAX_WAVES)
    if not waves then return nil, "At most 20 waves." end
    d.waves = {}
    if d.type == "waves" then
        if #waves == 0 then return nil, "A Survival mission needs at least one wave." end
        for i, w in ipairs(waves) do
            if type(w) ~= "table" then return nil, "Invalid wave " .. i .. "." end
            local delay = w.delaySeconds == nil and 10 or w.delaySeconds
            if not G.integer(delay, 0, 300) then return nil, "Wave " .. i .. ": delay must be 0–300 seconds." end
            local ids = list(w.spawns, M.MAX_SPAWNS)
            if not ids or #ids == 0 then return nil, "Wave " .. i .. " has no spawn point." end
            local v = { delaySeconds = delay, spawns = {} }
            for _, id in ipairs(ids) do
                local s = byId[id]
                if not s then return nil, "Wave " .. i .. " uses an unknown spawn point." end
                if s.trigger ~= "wave" then return nil, "Wave " .. i .. ": " .. s.label .. " is not a wave spawn." end
                v.spawns[#v.spawns + 1] = id
                used[id] = true
            end
            d.waves[i] = v
        end
    end
    -- a world boss brings its non-start spawn points as reinforcements (no checkpoint needed)
    local worldBossOn = type(raw.worldBoss) == "table" and raw.worldBoss.enabled == true
    for _, s in ipairs(d.spawns) do
        if s.trigger ~= "start" and not used[s.id] and not worldBossOn then
            return nil, s.label .. (s.trigger == "wave" and " is in no wave." or " is woken by no checkpoint.")
        end
    end
    if d.type == "eliminate" then
        local any = false
        for _, s in ipairs(d.spawns) do any = any or s.trigger == "start" or used[s.id] end
        if not any then return nil, "An Elimination mission needs at least one spawn point." end
    end

    -- A world boss (server/modules/world_bosses.lua): no board, no tag, no instance. It
    -- appears at random in the city (bucket 0) and anybody fights it; the perimeter is the
    -- event zone (no out-of-zone death). `boss` is the spawn point whose enemies are the
    -- boss (health x `health`); the others guard it, and the non-start ones come as
    -- reinforcements at 66 % and 33 % of the boss's health. The reward pool is shared by
    -- contribution (damage + kills); under `minShare` % of it, nothing.
    d.worldBoss = { enabled = false, boss = "", health = 25, reward = 30000, minShare = 5, minutes = 20 }
    if raw.worldBoss ~= nil then
        local wb = raw.worldBoss
        if type(wb) ~= "table" or (wb.enabled ~= nil and type(wb.enabled) ~= "boolean") then return nil, "Invalid world boss settings." end
        local v = { enabled = wb.enabled == true, boss = wb.boss == nil and "" or wb.boss,
            health = wb.health == nil and 25 or wb.health, reward = wb.reward == nil and 30000 or wb.reward,
            minShare = wb.minShare == nil and 5 or wb.minShare, minutes = wb.minutes == nil and 20 or wb.minutes }
        if type(v.boss) ~= "string" or (v.boss ~= "" and not key(v.boss)) then return nil, "World boss: invalid boss spawn point." end
        if not G.integer(v.health, 1, 200) then return nil, "World boss: boss health must be x1-x200." end
        if not G.integer(v.reward, 0, 1000000) then return nil, "World boss: reward pool must be 0-1,000,000." end
        if not G.integer(v.minShare, 0, 50) then return nil, "World boss: minimum share must be 0-50 %." end
        if not G.integer(v.minutes, 5, 120) then return nil, "World boss: time limit must be 5-120 minutes." end
        if v.enabled then
            if d.fixer.enabled then return nil, "A mission is either a fixer gig or a world boss, not both." end
            local s = byId[v.boss]
            if not s then return nil, "World boss: choose the spawn point of the boss." end
            if s.trigger ~= "start" then return nil, "World boss: the boss spawn point must spawn at the start." end
        end
        d.worldBoss = v
    end

    d.difficulties, why = difficulties(raw.difficulties)
    if not d.difficulties then return nil, why end
    return d
end

-- The mission point the board system (server/modules/missions.lua) runs.
function M.point(def)
    local starts = {}
    for i, s in ipairs(def.starts) do starts[i] = { x = s.x, y = s.y, z = s.z, heading = s.heading } end
    return { id = def.id, title = def.title, type = M.TYPE_LABELS[def.type], location = def.location ~= "" and def.location or "Night City",
        description = def.description ~= "" and def.description or (def.type == "waves" and "Hold the zone until the last wave falls."
            or "Clear the zone. Leave nobody standing."),
        position = def.point, start = starts, difficulties = clone(def.difficulties), custom = true,
        fixer = def.fixer and def.fixer.enabled == true or nil,
        worldBoss = def.worldBoss and def.worldBoss.enabled == true or nil,
        fixerContact = def.fixer and def.fixer.contact or nil, fixerBrief = def.fixer and def.fixer.brief or nil }
end

-- How many enemies a spawn point puts out at a difficulty.
function M.count(spawn, difficulty)
    return math.max(1, math.min(M.MAX_COUNT * 5, math.floor(spawn.count * (difficulty and difficulty.enemyCount or 1) + 0.5)))
end
