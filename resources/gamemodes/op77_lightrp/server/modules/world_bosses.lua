local lightrpEvery = LightRP.every or function(ms, fn) while true do Wait(tonumber(ms) or 1000); fn() end end -- framework.lua (tests: the plain loop, in the calling thread)
-- World bosses: open-world events built from authored missions tagged "World boss" in
-- the mission editor (shared/mission_defs.lua worldBoss). No board, no tag, no instance:
--
--   spawn      at random (server/config/world_bosses.lua schedule), the mission's start
--              spawn points appear in the city (bucket 0): the boss (its spawn point,
--              health x worldBoss.health) and its guards; a blip and a city-wide notice.
--   the zone   the perimeter (+ zoneMargin) is the event zone, nothing more: whoever
--              stands in it is a target and sees the common objective, the boss's health
--              and their own share. Leaving it costs nothing.
--   reinforce  the non-start spawn points come at 66 % and 33 % of the boss's health.
--   credit     onNpcDamaged / onNpcDied with the server-validated source "player:<id>"
--              (platform hit pricing): damage points + a kill bonus earned by the damage
--              the killer dealt to that target.
--   the end    boss down: the pool is shared by contribution among those at or above the
--              mission's minimum share (a latecomer's last shot or an idle player: nothing).
--              Time out: the boss leaves, nobody is paid.
--   the pool   the editor's reward is the most it can be: with LightRpEconomy.worldBosses
--              it is perFighter x paid fighters ^ crewExponent, and one fighter never
--              gets more than maxSharePerMinute x the time limit (WB.pool, WB.headCap;
--              docs/economy-balance.md §15). Without that table, the editor's reward.
--   per day    a character paid for C.dailyPaid world bosses since 00:00 UTC is paid
--              nothing more that day, money nor reputation (owner decision 2026-11-04,
--              §16): they still fight, are told why, and do not count as a paid fighter.
--
--   at once    the random one and the staff's (server/modules/staff_events.lua) run side by
--              side, up to C.maxLive; the same definition never twice. A staff event can
--              be silent (no city notice, no map pin) or pay nothing (a fun event: no
--              money, no reputation, and nothing counts for dailies, titles or drops).
--
-- The enemies are the mission engine's own (spawns, behaviours, deaths): Engine.world.
local C = LightRpWorldBosses
local D = LightRpMissionDefs
local Db = LightRP.db
local WB = LightRP.module("worldBosses", {})

Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_worldboss_daily (
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL, day_index INT NOT NULL,
    paid_events INT NOT NULL DEFAULT 0,
    PRIMARY KEY (identifier, character_key, day_index)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local catalogue = {}     -- definition id -> definition (published, enabled world bosses)
-- The running events, oldest first. Each enemy's event is known by its id (npcEvent).
local events = {}
local npcEvent = {}      -- tostring(npc id) -> its event
local nextAt = nil       -- ms of the next random spawn
local eventSeq = 0
local daily = {}         -- "identifier#key" -> { day, count, synced, identifier, key }: paid events today

local function now() return LightRP.nowMs() end
local function log(...) LightRP.log(...) end
local function name(id) return LightRP.characters.displayName(id) end
local function money(n) return LightRP.money and LightRP.money.format(n) or ("€$" .. tostring(n)) end
local function fill(text, vars) return (text:gsub("{(%w+)}", function(k) return vars[k] ~= nil and tostring(vars[k]) or "" end)) end

-- ---------------------------------------------------------------------------
-- Pay per character and UTC day: the day index of the rest of the economy
-- (mission_pay.lua, activity_pay.lua), a write-through cache read once from SQL.

local function unix()
    if Open77 and Open77.time and type(Open77.time.unix) == "function" then return math.floor(Open77.time.unix()) end
    if type(GetUnixTime) == "function" then return math.floor(GetUnixTime()) end
    return os.time()
end
local function today() return math.floor(unix() / 86400) end
local function dailyCap() return math.max(0, math.floor(tonumber(C.dailyPaid) or 0)) end
local function dailyOf(id)
    local c = LightRP.characters.get and LightRP.characters.get(id)
    if not c or not c.identifier then return nil end
    local identifier, key = tostring(c.identifier), tostring(c.key or "default")
    local k, day = identifier .. "#" .. key, today()
    local entry = daily[k]
    if not entry or entry.day ~= day then entry = { day = day, count = 0, synced = false, identifier = identifier, key = key }; daily[k] = entry end
    if not entry.synced and Db.ready then
        entry.synced = true
        local row = Db.single("SELECT paid_events FROM lightrp_worldboss_daily WHERE identifier = ? AND character_key = ? AND day_index = ?",
            { identifier, key, day })
        entry.count = math.max(entry.count, row and tonumber(row.paid_events) or 0)
    end
    return entry
end
-- capped, paid today, the cap: this character's world boss pay is over until 00:00 UTC.
function WB.dailyCapped(id)
    local cap = dailyCap()
    if cap <= 0 then return false, 0, 0 end
    local entry = dailyOf(id)
    if not entry then return false, 0, cap end
    return entry.count >= cap, entry.count, cap
end
local function countPaid(id)
    local entry = dailyOf(id)
    if not entry then return end
    entry.count = entry.count + 1
    if Db.ready then
        Db.run("INSERT INTO lightrp_worldboss_daily (identifier, character_key, day_index, paid_events) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE paid_events = GREATEST(paid_events, VALUES(paid_events))",
            { entry.identifier, entry.key, entry.day, entry.count })
    end
end
local function cappedText(paidToday)
    return string.format("Daily world boss pay reached: you were paid for %d world boss%s today. Fight on if you like; no pay or reputation from world bosses until 00:00 UTC.",
        paidToday, paidToday == 1 and "" or "es")
end
WB.cappedText = cappedText
-- The running event's instance (fighters in the zone as members, city bucket) and the
-- enemy's id when `npcId` is one of its enemies: mission_engine.lua's NPC hit relay applies
-- those hits to the fighters (the enemies opt into authoritativePlayerHits, so the engine
-- itself never drains a player's health).
function WB.instanceOfNpc(npcId)
    local ev = npcEvent[tostring(npcId)]
    if not ev or ev.phase ~= "fight" or not ev.inst then return nil end
    local key = ev.npcs[tostring(npcId)]
    if key == nil then return nil end
    return ev.inst, key
end

local function bucketOf(id) return type(GetPlayerRoutingBucket) == "function" and GetPlayerRoutingBucket(id) or 0 end
local function positionOf(id)
    local p = Open77.players.position(id)
    if p then return p end
    local ok, read = pcall(Open77.players.get, id)
    if ok and type(read) == "table" and type(read.position) == "table" then return read.position end
end
local function alive(id)
    local life = Open77.players.getLifeState(id)
    return not life or life.phase == "alive"
end
local function engine() return LightRP.missionEngine and LightRP.missionEngine.world end
local function online()
    local list = {}
    for _, raw in ipairs(GetPlayers()) do
        local id = tonumber(raw)
        if id and LightRP.characters.isRegistered(id) then list[#list + 1] = id end
    end
    return list
end

-- The events: a copy of the list, one by id, the one whose zone holds a player.
function WB.events() local out = {} for i, ev in ipairs(events) do out[i] = ev end return out end
function WB.event(id) for _, ev in ipairs(events) do if ev.id == id then return ev end end end
function WB.zoneOf(player) for _, ev in ipairs(events) do if ev.inZone[player] then return ev end end end
function WB.maxLive() return math.max(1, math.floor(tonumber(C.maxLive) or 4)) end

-- ---------------------------------------------------------------------------
-- Catalogue (the mission engine publishes and withdraws)

function WB.publish(def) catalogue[def.id] = D.clone(def) end
function WB.withdraw(id) catalogue[id] = nil end
function WB.catalogue()
    local list = {}
    for _, def in pairs(catalogue) do list[#list + 1] = def end
    table.sort(list, function(a, b) return a.title < b.title end)
    return list
end

-- ---------------------------------------------------------------------------
-- The zone

-- Inside the perimeter, or within zoneMargin of it (the height never matters: a boss on
-- a roof is fought from the street too).
local function inZone(def, p, margin)
    local z = def.perimeter
    local flat = { shape = z.shape, center = z.center, radius = z.radius, length = z.length, width = z.width,
        heading = z.heading, points = z.points, fullHeight = true }
    if D.inside(flat, p) then return true end
    margin = margin or C.zoneMargin or 0
    if z.shape == "circle" then
        return math.sqrt((p.x - z.center.x) ^ 2 + (p.y - z.center.y) ^ 2) <= z.radius + margin
    end
    -- box / polygon: within the margin of the centre's bounding reach
    local reach = 0
    if z.shape == "box" then reach = math.sqrt((z.length / 2) ^ 2 + (z.width / 2) ^ 2)
    else for _, q in ipairs(z.points or {}) do reach = math.max(reach, math.sqrt((q.x - z.center.x) ^ 2 + (q.y - z.center.y) ^ 2)) end end
    return math.sqrt((p.x - z.center.x) ^ 2 + (p.y - z.center.y) ^ 2) <= reach + margin
end
WB.inZone = inZone

-- ---------------------------------------------------------------------------
-- Contribution

local function maxHealthOf(ev, key, npcId)
    if not ev.npcMax[key] then
        local ok, npc = pcall(Open77.npcs.get, tonumber(npcId) or npcId)
        local m = ok and type(npc) == "table" and tonumber(npc.maxHealth)
        if m and m > 0 then ev.npcMax[key] = m end
    end
    return ev.npcMax[key] or 100
end
local function entry(ev, id)
    local c = ev.contrib[id]
    if not c then
        c = { damage = 0, bossDamage = 0, kills = 0, score = 0, on = {}, name = name(id), firstAt = now() }
        ev.contrib[id] = c
    end
    return c
end
local function totalScore(ev)
    local total = 0
    for _, c in pairs(ev.contrib) do total = total + c.score end
    return total
end
local function shareOf(ev, id)
    local c, total = ev.contrib[id], totalScore(ev)
    if not c or total <= 0 then return 0 end
    return c.score / total * 100
end
WB.shareOf = function(id) local ev = WB.zoneOf(id) or WB.current(); return ev and shareOf(ev, id) or 0 end
-- The share that pays. The mission's minimum, lowered when many fight so a crowd still
-- gets paid: never under a quarter (fairShareFraction) of an equal share between
-- everyone who scored. A last shot or a watcher stays far below it either way.
local function needed(ev)
    local n = 0
    for _, c in pairs(ev.contrib) do if c.score > 0 then n = n + 1 end end
    local w = ev.def.worldBoss
    if n <= 0 then return w.minShare end
    return math.min(w.minShare, (C.fairShareFraction or 0.25) * 100 / n)
end
WB.needed = function(id) local ev = (id and WB.zoneOf(id)) or WB.current(); return ev and needed(ev) or 0 end

-- The pool that pays `fighters` (server/config/economy.lua worldBosses, read at call
-- time) and the most one of them gets. Pure.
local function economy()
    local E = LightRpEconomy and LightRpEconomy.worldBosses
    return type(E) == "table" and E or nil
end
function WB.pool(reward, fighters)
    reward = math.max(0, math.floor(tonumber(reward) or 0))
    local E = economy()
    local per = E and tonumber(E.perFighter) or 0
    if per <= 0 then return reward end
    local n = math.max(1, math.floor(tonumber(fighters) or 1))
    local exponent = math.max(0, math.min(1, tonumber(E.crewExponent) or 1))
    return math.min(reward, math.floor(per * n ^ exponent + 0.5))
end
function WB.headCap(minutes)
    local E = economy()
    local perMinute = E and tonumber(E.maxSharePerMinute) or 0
    if perMinute <= 0 then return math.huge end
    return math.floor(perMinute * math.max(1, tonumber(minutes) or 1))
end
-- The pool the HUD and the zone notice quote: the fighters in the zone now (or the
-- paid ones once it ended), as if they all earned a share.
local function poolNow(ev)
    if ev.pool then return ev.pool end
    return WB.pool(ev.def.worldBoss.reward, math.max(1, ev.fighters or 0))
end

local function playerOf(source)
    local id = tonumber(tostring(source or ""):match("^player:(%d+)$"))
    return id
end
AddEventHandler("onNpcDamaged", function(npcId, source, amount)
    local ev = npcEvent[tostring(npcId)]
    if not ev or ev.phase ~= "fight" then return end
    local key = tostring(npcId)
    if not ev.npcs[key] then return end
    local id = playerOf(source)
    local value = tonumber(amount)
    if not id or not value or value ~= value or value <= 0 then return end
    local c = entry(ev, id)
    value = math.min(value, 100000)
    maxHealthOf(ev, key, npcId)
    c.on[key] = (c.on[key] or 0) + value
    c.damage = c.damage + value
    if ev.bossNpcs[key] then c.bossDamage = c.bossDamage + value end
    c.score = c.score + value
    ev.dirty = true
end)
AddEventHandler("onNpcDied", function(npcId, source)
    local ev = npcEvent[tostring(npcId)]
    if not ev then return end
    local key = tostring(npcId)
    if not ev.npcs[key] then return end
    local id = playerOf(source)
    if not id then return end
    local c = entry(ev, id)
    if ev.bossNpcs[key] then ev.lastHit = id end -- titles.lua: Boss Killer
    c.kills = c.kills + 1
    local max = maxHealthOf(ev, key, npcId)
    local earned = math.min(1, (c.on[key] or 0) / math.max(1, (C.killAssist or 0.1) * max))
    c.score = c.score + (C.killShare or 0.25) * max * earned
    ev.dirty = true
end)

-- ---------------------------------------------------------------------------
-- The HUD (state key worldBoss)

local function bossHealth(ev)
    local health, maxHealth, standing = 0, 0, 0
    for key, npcId in pairs(ev.bossNpcs) do
        local ok, npc = pcall(Open77.npcs.get, npcId)
        if ok and type(npc) == "table" then
            local h, m = tonumber(npc.health) or 0, tonumber(npc.maxHealth) or 0
            if npc.alive ~= false and h > 0 then standing = standing + 1; health = health + h end
            maxHealth = maxHealth + math.max(m, h)
            ev.bossMax[key] = math.max(ev.bossMax[key] or 0, m, h)
        else
            maxHealth = maxHealth + (ev.bossMax[key] or 0)
        end
    end
    return health, maxHealth, standing
end

local function view(ev, id)
    local c = ev.contrib[id]
    local share = shareOf(ev, id)
    local w = ev.def.worldBoss
    -- the daily cap as read at the zone entry (no SQL read here)
    local capped = ev.capped[id] == true
    return {
        id = ev.id, title = ev.def.title, location = ev.location, boss = ev.bossLabel, phase = ev.phase,
        bossHealth = ev.bossFraction, enemiesLeft = ev.run.alive + #ev.run.queue, fighters = ev.fighters,
        endsInMs = ev.phase == "fight" and math.max(0, ev.endsAt - now()) or nil,
        share = math.floor(share * 10 + 0.5) / 10, minShare = math.floor(needed(ev) * 10 + 0.5) / 10,
        eligible = not capped and share >= needed(ev) and (c and c.score or 0) > 0, dailyCapped = capped or nil,
        damage = c and math.floor(c.damage + 0.5) or 0, kills = c and c.kills or 0, reward = ev.noPay and 0 or poolNow(ev), rewardMax = ev.noPay and 0 or w.reward,
        inZone = ev.inZone[id] == true,
        -- the HUD's tag (WORLD BOSS, CYBERPSYCHO...) and a staff event that pays nothing
        tag = ev.words.tag, noPay = ev.noPay or nil,
        -- a bystander in the zone still sees how it ended
        result = ev.results and (ev.results[id] or { success = ev.success == true, share = 0, pay = 0, eligible = false, damage = 0, kills = 0 }) or nil,
    }
end
LightRP.stateProvider("worldBoss", function(id)
    -- only in a zone, and the end only for a few seconds
    for _, ev in ipairs(events) do
        if ev.inZone[id] and not (ev.hudUntil and now() >= ev.hudUntil) then return view(ev, id) end
    end
    return false
end)
local function pushHud(ev, force)
    for id in pairs(ev.watchers) do
        local v = view(ev, id)
        -- the clock runs on the page: the key leaves it out
        local key = string.format("%s:%.3f:%d:%d:%.1f:%s:%d:%d:%s", v.phase, v.bossHealth or 0, v.enemiesLeft, v.fighters, v.share,
            tostring(v.eligible), v.damage, v.kills, tostring(v.inZone))
        if force or ev.hudKeys[id] ~= key then
            ev.hudKeys[id] = key
            LightRP.state(id, "worldBoss")
        end
    end
end

-- ---------------------------------------------------------------------------
-- Blip and announcements

local function blip(ev, on)
    local ok, err = pcall(function()
        if on then
            if ev.silent then return end -- a silent staff event: found, not announced
            local z = ev.def.perimeter.center
            local why
            ev.blipId, why = exports.op77_map3d:addBlip(-1, { id = ev.blipKey, position = { x = z.x, y = z.y, z = z.z },
                icon = ev.look.icon or "skull", color = ev.look.color or C.blip.color,
                label = fill(ev.look.label or C.blip.label, { title = ev.def.title, boss = ev.bossLabel }),
                description = ev.bossLabel .. " · " .. ev.location, pulse = C.blip.pulse, edge = C.blip.edge, routable = true,
                category = "event", priority = 2, scale = 1.4 })
            if not ev.blipId then log("world boss: map blip refused: %s", tostring(why)) end
        elseif ev.blipId then
            exports.op77_map3d:removeBlip(ev.blipId)
            ev.blipId = nil
        end
    end)
    if not ok then log("world boss: map blip failed: %s", tostring(err)) end
end

-- ---------------------------------------------------------------------------
-- Start / stop

-- The words of an event (a staff event brings its own: CYBERPSYCHO, GANG ATTACK...).
local WORDS = { tag = "WORLD BOSS", zone = "WORLD BOSS ZONE", down = "WORLD BOSS DOWN", away = "WORLD BOSS ESCAPED" }
local function wordsOf(custom)
    local out = {}
    for k, v in pairs(WORDS) do out[k] = type(custom) == "table" and type(custom[k]) == "string" and custom[k] or v end
    return out
end

-- `opts` (staff_events.lua): { custom, pay = false, silent, by, kind, words, look = { icon,
-- color, label }, announce = { title, body, bodyNoPay } }. Nil: a world boss as authored.
local function start(def, why, opts)
    opts = type(opts) == "table" and opts or {}
    for _, other in ipairs(events) do
        if other.def.id == def.id then return false, def.title .. " is already out." end
    end
    if #events >= WB.maxLive() then return false, string.format("%d world events are already out: that is the most at once.", #events) end
    local W = engine()
    if not W then return false, "The mission engine is not ready." end
    local boss = def.worldBoss
    local diff = def.difficulties[1]
    eventSeq = eventSeq + 1
    local run = { def = D.clone(def), instance = "worldboss:" .. eventSeq, difficulty = diff, phase = "fight",
        spawns = {}, queue = {}, enemies = {}, alive = 0, total = 0, kills = 0, failedSpawns = 0, reached = {}, waveIndex = 0,
        outside = {}, out = {}, respawns = {}, down = {}, alerting = {}, reviving = {}, retries = {} }
    for _, s in ipairs(run.def.spawns) do
        local copy = D.clone(s)
        -- the boss: its spawn point's health multiplier on top of the difficulty's
        if copy.id == boss.boss then copy.healthMultiplier = boss.health end
        run.spawns[copy.id] = copy
    end
    local bossSpawn = run.spawns[boss.boss]
    local ev = { id = run.instance, def = run.def, run = run, startedAt = now(), endsAt = now() + boss.minutes * 60000,
        phase = "fight", contrib = {}, npcs = {}, bossNpcs = {}, bossMax = {}, inZone = {}, watchers = {}, hudKeys = {}, capped = {},
        reinforced = {}, bossFraction = 1, fighters = 0, npcMax = {},
        bossLabel = bossSpawn and bossSpawn.label or "The boss", location = def.location ~= "" and def.location or "Night City",
        custom = opts.custom == true, noPay = opts.pay == false, silent = opts.silent == true, by = opts.by, kind = opts.kind or "boss",
        words = wordsOf(opts.words), look = type(opts.look) == "table" and opts.look or {}, blipKey = ("worldboss_%d"):format(eventSeq) }
    -- every enemy of the event is known by id (credit) and the boss's apart (its bar)
    run.onCreated = function(npcId, s)
        ev.npcs[tostring(npcId)] = npcId
        npcEvent[tostring(npcId)] = ev
        if s.id == boss.boss then ev.bossNpcs[tostring(npcId)] = npcId; ev.bossSeen = true end
    end
    ev.inst = { id = ev.id, bucket = 0, members = {}, run = run, world = true }
    for _, s in ipairs(run.def.spawns) do if s.trigger == "start" then W.enqueue(run, s.id) end end
    events[#events + 1] = ev
    blip(ev, true)
    -- the most the pool can reach: every player online fighting and paid
    local vars = { boss = ev.bossLabel, location = ev.location, title = def.title, reward = money(WB.pool(boss.reward, #online())) }
    if not ev.silent then
        local a = type(opts.announce) == "table" and opts.announce or {}
        local body = ev.noPay and (a.bodyNoPay or "{boss} spotted in {location}. A staff event: no pay, just the glory.") or (a.body or C.announce.body)
        for _, id in ipairs(online()) do
            LightRP.notice(id, { kind = "warning", title = fill(a.title or C.announce.title, vars), body = fill(body, vars), durationMs = 12000 })
        end
    end
    log("world boss: %s (%s) out at %s, %s%s%s", def.title, ev.bossLabel, ev.location, tostring(why or "random"),
        ev.noPay and ", no pay" or "", ev.silent and ", silent" or "")
    return true, ev
end
WB.start = start

local function finish(ev, success, why)
    if ev.phase == "done" or ev.phase == "cleanup" then return end
    ev.phase = success and "cleanup" or "done"
    ev.success = success == true
    -- the result stays on the zone's HUD a few seconds; a win's bodies go later
    ev.hudUntil = now() + (C.resultSeconds or 10) * 1000
    ev.cleanupAt = success and now() + (C.cleanupSeconds or 45) * 1000 or ev.hudUntil
    local w = ev.def.worldBoss
    ev.results = {}
    -- the pool, shared by score among those at or above the minimum share
    local total = totalScore(ev)
    local eligibleScore = 0
    local need = needed(ev)
    ev.need = need
    local eligible = 0
    -- a snapshot: the payments below yield (SQL), and a late kill event may add a contributor
    local ids = {}
    for id in pairs(ev.contrib) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do
        local c = ev.contrib[id]
        c.share = total > 0 and c.score / total * 100 or 0
        c.eligible = success and not ev.noPay and c.score > 0 and c.share >= need
        -- past the daily cap (owner decision 2026-11-04): the fight and the share count
        -- (results.eligible: contracts, titles, iconic rolls), the money and reputation do not
        if c.eligible then c.capped, c.paidToday = WB.dailyCapped(id) end
        if c.eligible and not c.capped then eligibleScore = eligibleScore + c.score; eligible = eligible + 1 end
    end
    -- the pool grows with the fighters paid (WB.pool), a share never past WB.headCap
    local pool, headCap = WB.pool(w.reward, eligible), WB.headCap(w.minutes)
    ev.pool = pool
    local paid = 0
    for _, id in ipairs(ids) do
        local c = ev.contrib[id]
        local pay = 0
        if c.eligible and not c.capped and eligibleScore > 0 then pay = math.min(headCap, math.floor(pool * c.score / eligibleScore)) end
        if pay > 0 and GetPlayerName(id) then
            local credited = not LightRP.money or LightRP.money.addBank(id, pay, "worldboss", "World boss: " .. ev.def.title) == true
            if credited then
                paid = paid + 1
                countPaid(id)
                if LightRP.missions and LightRP.missions.addReputation then LightRP.missions.addReputation(id, C.reputation) end
            else
                log("world boss: %s payout of %d to %s failed", ev.def.title, pay, tostring(id))
                pay, c.failed = 0, true
            end
        end
        c.pay = pay
        ev.results[id] = { success = success, share = math.floor(c.share * 10 + 0.5) / 10, pay = pay, eligible = c.eligible == true,
            damage = math.floor(c.damage + 0.5), kills = c.kills, dailyCapped = c.capped == true or nil }
        if GetPlayerName(id) then
            local body
            if not success then body = (why or "The boss got away.") .. string.format(" Your share: %.1f %%. Nobody is paid.", c.share)
            elseif ev.noPay then body = string.format("Your share: %.1f %% (%d damage, %d kill%s). A staff event: no pay, the glory is yours.",
                c.share, math.floor(c.damage + 0.5), c.kills, c.kills == 1 and "" or "s")
            elseif pay > 0 then body = string.format("Your share: %.1f %% (%d damage, %d kill%s). %s paid to your account, +%d reputation.",
                c.share, math.floor(c.damage + 0.5), c.kills, c.kills == 1 and "" or "s", money(pay), C.reputation)
            elseif c.failed then body = string.format("Your share: %.1f %%. The bank did not answer: tell the staff, nothing was paid.", c.share)
            elseif c.capped then body = string.format("Your share: %.1f %% (%d damage, %d kill%s). %s", c.share, math.floor(c.damage + 0.5), c.kills,
                c.kills == 1 and "" or "s", cappedText(c.paidToday or 0))
            else body = string.format("Your share: %.1f %%, under the %.1f %% needed: no reward. Fight it, don't watch it.", c.share, need) end
            LightRP.notice(id, { kind = success and (pay > 0 and "success" or "warning") or "error",
                title = success and ev.words.down or ev.words.away, body = body, durationMs = 12000 })
        end
    end
    if not success then
        -- whoever stands in the zone without a share yet is told too
        for id in pairs(ev.inZone) do
            if not ev.contrib[id] and GetPlayerName(id) then
                LightRP.notice(id, { kind = "error", title = ev.words.away, durationMs = 8000, body = (why or "The boss got away.") .. " Nobody is paid." })
            end
        end
    end
    if success and not ev.silent then
        for _, id in ipairs(online()) do
            if not ev.contrib[id] then
                LightRP.notice(id, { kind = "info", title = ev.words.down, durationMs = 8000,
                    body = ev.noPay and string.format("%s fell in %s.", ev.bossLabel, ev.location)
                        or string.format("%s fell in %s. %d fighter%s paid.", ev.bossLabel, ev.location, paid, paid == 1 and "" or "s") })
            end
        end
    end
    log("world boss: %s %s (%s); %d contributor(s), %d paid", ev.def.title, success and "down" or "escaped", tostring(why or ""),
        (function() local n = 0 for _ in pairs(ev.contrib) do n = n + 1 end return n end)(), paid)
    -- a fun staff event (no pay) counts for nothing: no iconic drop, contract or title
    if not ev.noPay then
        LightRP.eachModule("onWorldBossFinished", { id = ev.def.id, title = ev.def.title, boss = ev.bossLabel, success = ev.success, results = ev.results }) -- iconic drops (cyberware_iconics.lua)
    end
    -- the end-of-fight recap (recap.lua): each fighter's damage, share and pay, as paid above
    if LightRP.recap then pcall(LightRP.recap.worldBossEnded, ev, success, why, ev.noPay and 0 or C.reputation) end
    blip(ev, false)
    pushHud(ev, true)
    if not ev.noPay then LightRP.eachModule("onWorldEventEnded", ev, success) end -- contracts, titles
    if not success then
        local W = engine()
        if W then W.clearEnemies(ev.run) end
    end
end
WB.finish = finish

local function close(ev)
    local W = engine()
    if W then W.clearEnemies(ev.run) end
    for i = #events, 1, -1 do if events[i] == ev then table.remove(events, i) end end
    for key, owner in pairs(npcEvent) do if owner == ev then npcEvent[key] = nil end end
    ev.closed = true
    -- the HUD of the last fighters goes away with the event
    for id in pairs(ev.watchers) do LightRP.state(id, "worldBoss") end
    -- a world boss of the catalogue (random or staff) restarts the random clock; a staff
    -- event built from scratch (staff_events.lua) leaves it alone
    if not ev.custom then
        local s = C.schedule
        nextAt = now() + math.random(s.minMinutes, math.max(s.minMinutes, s.maxMinutes)) * 60000
    end
    LightRP.eachModule("onWorldEventClosed", ev) -- staff_events.lua: event nights
end

-- Enemies stay in the zone. One past the perimeter by `leashMetres` is leashed: combat and
-- perception off (the native AI would keep chasing its target through any task), the
-- engine's retargeting held, and a run back to its post (re-ordered every few seconds).
-- Back inside the perimeter it fights again; still out after `leashTeleportSeconds`, it is
-- put back on its post.
local LEASH_CHECK_MS, LEASH_REORDER_MS = 1000, 5000
local function setFighting(npcId, on)
    pcall(Open77.npcs.setCombatEnabled, npcId, on)
    pcall(Open77.npcs.setPerceptionEnabled, npcId, on)
end
local function leash(ev, t)
    local def, out = ev.def, C.leashMetres or 20
    local teleportMs = (C.leashTeleportSeconds or 30) * 1000
    for npcId, e in pairs(ev.run.enemies or {}) do
        if not e.deadAt and (e.leashAt or 0) <= t then
            e.leashAt = t + LEASH_CHECK_MS
            local ok, npc = pcall(Open77.npcs.get, npcId)
            local p = ok and type(npc) == "table" and npc.position
            local s = e.spawn
            if p and not e.leashed and not WB.inZone(def, p, out) then
                e.leashed, e.leashedAt, e.leashOrderAt, e.taskAt = true, t, t, math.huge
                setFighting(npcId, false)
                pcall(Open77.npcs.tasks.guard, npcId, s.position, 4, { speed = "run" })
            elseif p and e.leashed then
                if WB.inZone(def, p, 0) then
                    -- home: an ambusher not yet alerted stays blind, as it started
                    e.leashed, e.taskAt = nil, 0
                    if s.behavior ~= "ambush" or e.alerted then setFighting(npcId, true) end
                elseif t - e.leashedAt >= teleportMs then
                    pcall(Open77.npcs.setTransform, npcId, { position = { x = s.position.x, y = s.position.y, z = s.position.z }, yaw = s.heading or 0 })
                    e.leashedAt, e.leashOrderAt = t, t
                    pcall(Open77.npcs.tasks.guard, npcId, s.position, 4, { speed = "run" })
                elseif t - e.leashOrderAt >= LEASH_REORDER_MS then
                    -- an alert (a shot from outside) turns combat back on: held off again
                    e.leashOrderAt, e.taskAt = t, math.huge
                    setFighting(npcId, false)
                    pcall(Open77.npcs.tasks.guard, npcId, s.position, 4, { speed = "run" })
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- The clock

local function tick(ev)
    local W = engine()
    local t = now()
    if ev.phase == "done" then
        if t >= (ev.cleanupAt or 0) then close(ev) end
        return
    end
    if ev.phase == "cleanup" then
        if W then W.enemiesTick(ev.inst) end
        if not ev.hudClosed and t >= ev.hudUntil then
            ev.hudClosed = true
            for id in pairs(ev.watchers) do LightRP.state(id, "worldBoss") end
        end
        if t >= ev.cleanupAt then close(ev) end
        return
    end
    -- who is in the zone: targets, HUD, a contribution entry (first time)
    local members, fighters = {}, 0
    for _, id in ipairs(online()) do
        local p = bucketOf(id) == 0 and positionOf(id)
        local inside = p and inZone(ev.def, p) or false
        if inside ~= (ev.inZone[id] == true) then
            ev.inZone[id] = inside or nil
            if inside then
                local capped, paidToday = false, 0
                if not ev.noPay then capped, paidToday = WB.dailyCapped(id) end
                ev.capped[id] = capped or nil
                if ev.noPay then
                    LightRP.notice(id, { kind = "contract", title = ev.words.zone, durationMs = 9000,
                        body = string.format("Take down %s with everyone here. A staff event, for the glory: nothing is paid.", ev.bossLabel) })
                elseif capped then
                    LightRP.notice(id, { kind = "warning", title = ev.words.zone, durationMs = 9000,
                        body = string.format("Take down %s with everyone here. %s", ev.bossLabel, cappedText(paidToday)) })
                else
                    LightRP.notice(id, { kind = "contract", title = ev.words.zone, durationMs = 9000,
                        body = string.format("Take down %s with everyone here. Your share of %s%s follows your damage and kills; a last shot or watching earns nothing.",
                            ev.bossLabel, money(poolNow(ev)), poolNow(ev) < ev.def.worldBoss.reward and " (more as fighters join)" or "") })
                end
            end
        end
        if inside then
            ev.watchers[id] = true
            if alive(id) then members[#members + 1] = id; fighters = fighters + 1 end
        end
    end
    for id in pairs(ev.contrib) do ev.watchers[id] = true end
    ev.inst.members, ev.fighters = members, fighters
    if W then W.enemiesTick(ev.inst) end
    leash(ev, t)
    -- the boss
    local health, maxHealth, standing = bossHealth(ev)
    ev.bossFraction = maxHealth > 0 and health / maxHealth or (ev.bossSeen and 0 or 1)
    if ev.bossSeen and standing == 0 then
        finish(ev, true)
        return
    end
    if not ev.bossSeen and t - ev.startedAt > C.spawnTimeoutSeconds * 1000 then
        log("world boss: %s called off, the boss did not spawn", ev.def.title)
        finish(ev, false, "The boss never showed up.")
        return
    end
    -- reinforcements at the health thresholds
    for i, threshold in ipairs(C.reinforcements or {}) do
        if not ev.reinforced[i] and ev.bossSeen and ev.bossFraction <= threshold then
            ev.reinforced[i] = true
            local count, list = 0, {}
            for _, s in ipairs(ev.def.spawns) do if s.trigger ~= "start" then list[#list + 1] = s end end
            -- spread the reinforcement spawn points over the thresholds
            local per = math.ceil(#list / math.max(1, #C.reinforcements))
            for j = (i - 1) * per + 1, math.min(#list, i * per) do count = count + W.enqueue(ev.run, list[j].id) end
            if count > 0 then
                for id in pairs(ev.inZone) do
                    LightRP.notice(id, { kind = "warning", title = "REINFORCEMENTS", durationMs = 6000,
                        body = string.format("%d hostile%s joining %s.", count, count == 1 and "" or "s", ev.bossLabel) })
                end
            end
        end
    end
    if t >= ev.endsAt then
        finish(ev, false, ev.bossLabel .. " got away.")
        return
    end
    pushHud(ev, false)
end

CreateThread(function()
    nextAt = now() + (C.schedule.firstDelayMinutes or 20) * 60000
    lightrpEvery(1000, function()
        
        if #events > 0 then
            for _, ev in ipairs(WB.events()) do
                local ok, err = pcall(tick, ev)
                if not ok then log("world boss: tick failed (%s): %s", tostring(ev.id), tostring(err)) end
            end
        elseif C.enabled and nextAt and now() >= nextAt then
            nextAt = now() + 5 * 60000   -- retried in 5 min if nothing could start
            local list = WB.catalogue()
            if #list > 0 and #online() >= (C.schedule.minPlayers or 1) then
                local ok, why = start(list[math.random(1, #list)], "random")
                if not ok then log("world boss: random start refused (%s)", tostring(why)) end
            end
        end
    end, "world_bosses:678")
end)

function WB.onDisconnected(id)
    for _, ev in ipairs(events) do ev.inZone[id], ev.watchers[id], ev.hudKeys[id] = nil, nil, nil end
end

-- ---------------------------------------------------------------------------
-- Staff (ACL command.worldboss.*)

local function find(text)
    text = tostring(text or ""):lower()
    if text == "" then local list = WB.catalogue(); return list[math.random(1, math.max(1, #list))] end
    if catalogue[text] then return catalogue[text] end
    for _, def in pairs(catalogue) do if def.title:lower():find(text, 1, true) then return def end end
end
LightRP.command("worldboss.start", { restricted = true, usage = "/worldboss.start [mission id or title]" }, function(_, args)
    local def = find(table.concat(args, " "))
    if not def then return false, "No world boss matches (tag a mission \"World boss\" in /lightrp.missions)." end
    local ok, why = start(def, "staff")
    if not ok then return false, why end
    return true, string.format("%s is out at %s.", def.title, def.location ~= "" and def.location or "its zone")
end)
LightRP.command("worldboss.stop", { restricted = true, usage = "/worldboss.stop [win] [all]" }, function(_, args)
    -- the oldest event still fighting, or every one with "all"
    local win, all = false, false
    for _, a in ipairs(args) do if a == "win" then win = true elseif a == "all" then all = true end end
    local ended = 0
    for _, ev in ipairs(WB.events()) do
        if ev.phase == "fight" and (all or ended == 0) then
            if win then finish(ev, true) else finish(ev, false, "Called off by the staff.") end
            ended = ended + 1
        end
    end
    if ended == 0 then return false, "No world boss is out." end
    return true, ended == 1 and "World boss ended." or string.format("%d world events ended.", ended)
end)
LightRP.command("worldboss.list", { restricted = true, usage = "/worldboss.list" }, function()
    local names = {}
    for _, def in ipairs(WB.catalogue()) do names[#names + 1] = def.title end
    local out = {}
    for _, ev in ipairs(events) do
        out[#out + 1] = string.format("%s (%s, boss %d %%, %d fighter(s))", ev.def.title, ev.phase, math.floor((ev.bossFraction or 0) * 100), ev.fighters)
    end
    local status = #out > 0 and ("Out: " .. table.concat(out, "; ") .. ".")
        or string.format("None out; next in %d min.", math.max(0, math.floor(((nextAt or now()) - now()) / 60000)))
    return true, status .. " Catalogue: " .. (#names > 0 and table.concat(names, ", ") or "empty")
end)
LightRP.command("worldboss.next", { restricted = true, usage = "/worldboss.next <minutes>" }, function(_, args)
    local m = tonumber(args[1])
    if not m or m < 0 then return false, "usage: /worldboss.next <minutes>" end
    nextAt = now() + m * 60000
    return true, string.format("Next random world boss in %d min.", m)
end)

WB.tick = tick
-- The headline event (the events board's LIVE NOW): the oldest the city was told about.
function WB.current()
    for _, ev in ipairs(events) do if not ev.silent and ev.phase == "fight" then return ev end end
    for _, ev in ipairs(events) do if not ev.silent then return ev end end
end
function WB.setNext(ms) nextAt = ms end
function WB.nextAt() return nextAt end -- the events board (events_board.lua)
