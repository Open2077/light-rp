-- Missions, the entry half (The Division style). A mission point in the city
-- opens its board: pick a difficulty, then tag in. Entry is by crew
-- (server/modules/parties.lua): the crew leader tags the whole crew in, a member
-- cannot tag in alone, a player alone is a crew of one. A crew gets its own
-- lobby and nobody else joins it; it launches (countdown) as soon as it has the
-- difficulty's minimum. A crew leader who turns "open to matchmaking" on lets
-- strangers fill the empty places the old way: the tag joins the fullest open
-- lobby with room, a full lobby starts the countdown, and so does the host with
-- the minimum on board. Then the operators move into the mission's own routing
-- bucket.
--
-- What happens inside belongs to the mission scripts:
--   LightRP.missions.register("sector04_blackout", {
--       onStart = function(instance) end,          -- instance.id, bucket, point, difficulty, members (ids)
--       onTick = function(instance, seconds) end,  -- once a second while it runs
--       onLeave = function(instance, playerId, why) end,
--       onEnd = function(instance, success, why) end,
--   })
--   LightRP.missions.complete(instanceId) / LightRP.missions.fail(instanceId, why)
local C = LightRpMissions
local E = LightRpEvents
local Missions = LightRP.module("missions", {})

-- Inside a mission (raids included) the city has no signal: the 3D map and minimap
-- (op77_map3d, when it runs) drown in static for the operator until they are back.
local function setMapJam(id, on)
    pcall(function()
        if on then
            exports.op77_map3d:jam(id, { id = "mission:" .. id, strength = 1, label = C.mapJamLabel or "NO SIGNAL · MISSION ZONE" })
        else
            exports.op77_map3d:unjam("srv:" .. GetCurrentResourceName() .. ":mission:" .. id)
        end
    end)
end
local Db = LightRP.db

local points, order = {}, {}
-- A lobby is one crew's entry (`owner` = the crew id, or "solo:<playerId>"), private
-- unless the crew opened itself to matchmaking (`open`): only open lobbies take
-- other players, and only players who are open to matchmaking themselves.
local lobbies = {}       -- id -> { id, point, difficulty, members = { { id, squad } }, state = "open"|"countdown", launchAt, forced, open, owner }
local queueOf = {}       -- playerId -> lobby id
local instances = {}     -- id -> { id, point, difficulty, bucket, members = { ids }, startedAt, endsAt, state }
local instanceOf = {}    -- playerId -> instance id
local viewers = {}       -- playerId -> { session, point }
local scripts = {}       -- point id -> mission script
local reputation = {}    -- playerId -> { rep, completed }
local lastTag = {}
local lobbySeq, instanceSeq, sessionSeq = 0, 0, 0

local function now() return LightRP.nowMs() end
local function name(id) return LightRP.characters.displayName(id) end
local function citizen(id) return string.format("%03d", id) end
local function bucketOf(id) return type(GetPlayerRoutingBucket) == "function" and GetPlayerRoutingBucket(id) or 0 end

-- ---------------------------------------------------------------------------
-- The temporary kit: native weapons a mission or an activity hands out for a while
-- (LightRpRaid.loadouts, or an explicit { primary, secondary, reserve }). One path for
-- all of them: the authored missions (mission_engine.lua), the raid (mission_chimera.lua)
-- and the activities' providers (activity_kits.lua). It lives here because every mission
-- file loads after this one. It touches native slots only, never the inventory: the
-- armament stands aside meanwhile and projects the character's own weapons again after.
local K = {}
LightRP.kits = K
function K.list() return type(LightRpRaid) == "table" and LightRpRaid.loadouts or {} end
function K.byId(id)
    for _, kit in ipairs(K.list()) do if kit.id == id then return kit end end
end
-- What a mission preselects: the first kit.
function K.default() return K.list()[1] end

-- One native request, awaited (never from an export: it yields).
local waitingWeapons = {}
if type(AddEventHandler) == "function" then -- a mission test with no host events
    AddEventHandler("open77:weapons:completed", function(player, request, _, accepted, reason, result)
        waitingWeapons[tostring(player) .. ":" .. tostring(request)] = { accepted = accepted, reason = reason, result = result }
    end)
end
function K.weapons(player, method, ...)
    if type(Open77.weapons) ~= "table" or type(Open77.weapons[method]) ~= "function" then return nil, "weapons_api_unavailable" end
    local ok, request, why = pcall(Open77.weapons[method], player, ...)
    if not ok or not request then return nil, ok and why or request end
    local key = tostring(player) .. ":" .. tostring(request)
    local deadline = now() + 10000
    while not waitingWeapons[key] and now() < deadline do Wait(50) end
    local done = waitingWeapons[key]
    waitingWeapons[key] = nil
    if not done then return nil, "request_timeout" end
    if not done.accepted then return nil, done.reason end
    return done.result or true
end
function K.slots(snapshot) return type(snapshot) == "table" and (snapshot.slots or snapshot) or {} end
function K.capacity(snapshot, slot)
    for _, row in ipairs(K.slots(snapshot)) do
        if type(row) == "table" and tonumber(row.slot) == slot and type(row.ammo) == "table" then return tonumber(row.ammo.capacity) end
    end
end
-- In hand: slot 1 holds the kit's primary with rounds in it (a record without ammunition
-- is what a refused draw leaves behind). A primary with no reserve is a melee weapon.
function K.armed(snapshot, kit)
    for _, row in ipairs(K.slots(snapshot)) do
        if type(row) == "table" and tonumber(row.slot) == 1 then
            local a = type(row.ammo) == "table" and row.ammo or {}
            local rounds = tonumber(a.total) or ((tonumber(a.reserve) or 0) + (tonumber(a.magazine) or 0))
            return row.record == kit.primary and (rounds > 0 or not kit.reserve[1])
        end
    end
    return false
end
-- Any weapon of the kit still in a slot of this snapshot.
function K.holds(snapshot, kit)
    for _, row in ipairs(K.slots(snapshot)) do
        if type(row) == "table" and row.record ~= nil and (row.record == kit.primary or row.record == kit.secondary) then return true end
    end
    return false
end
-- The sequence, retried until the snapshot shows the kit (a client still loading answers
-- nothing, then refuses with queue_full). Runs on the caller's thread and yields.
--   o.tag        the log line's start ("mission 3: kit")
--   o.settleMs   the wait before the first try (default: the body lands in the arena first)
--   o.live()     false: stop before the next attempt
--   o.again()    optional, true: stop instead of retrying (another run is due)
--   o.stopped()  optional, true: no further request of this sequence goes out
--   o.assigned(slot, result)  optional: an assign the platform accepted
-- -> true, snapshot: in hand. false: every attempt failed. nil: stopped.
function K.deliver(id, kit, o)
    local function step(method, ...)
        if o.stopped and o.stopped() then return nil end
        local result, why = K.weapons(id, method, ...)
        if not result and why ~= "weapon_slot_empty" then
            LightRP.log("%s %s for %s: %s refused (%s)", o.tag, kit.id, name(id), method, tostring(why))
        end
        return result
    end
    Wait(o.settleMs or 1500)
    for attempt = 1, 6 do
        if not o.live() then return nil end
        step("clear")
        local first = step("assign", kit.primary, 1, { active = true, addToInventory = true })
        if first and o.assigned then o.assigned(1, first) end
        if kit.secondary then
            local second = step("assign", kit.secondary, 2, { active = false, addToInventory = true })
            if second and o.assigned then o.assigned(2, second) end
        end
        for slot = 1, 2 do
            if kit.reserve[slot] then
                step("setAmmo", slot, { reserve = kit.reserve[slot], activate = slot == 1 })
                local capacity = K.capacity(step("requestSnapshot"), slot)
                if capacity then step("setAmmo", slot, { magazine = capacity, activate = slot == 1 }) end
            end
        end
        step("setActive", 1)
        if o.stopped and o.stopped() then return nil end
        local check = K.weapons(id, "requestSnapshot")
        if K.armed(check, kit) then return true, check end
        if o.again and o.again() then return nil end
        LightRP.log("%s %s for %s not in hand (attempt %d), retrying", o.tag, kit.id, name(id), attempt)
        Wait(3000)
    end
    return false
end
-- The wheel picked a kit weapon (slot 1 primary, 2 secondary): drawn when the native
-- slot holds it, else the kit is handed out again (it never reached the hands, or the
-- player swapped it away). Holstering to the fists left no way back before (2026-11-02).
function K.draw(id, slot, kit, reissue)
    local record = slot == 2 and kit.secondary or kit.primary
    CreateThread(function()
        local snapshot = K.weapons(id, "requestSnapshot")
        local held = false
        for _, row in ipairs(K.slots(snapshot)) do
            if type(row) == "table" and tonumber(row.slot) == slot and row.record == record then held = true end
        end
        if held then
            local ok, why = K.weapons(id, "setActive", slot)
            if not ok then LightRP.log("kits: %s could not draw kit slot %d (%s)", name(id), slot, tostring(why)) end
        else
            LightRP.log("kits: kit slot %d of %s missing, handing the kit out again", slot, name(id))
            pcall(reissue)
        end
    end)
    return true
end

-- A player's last known position (`position` is nil after two idle seconds).
local function positionOf(id)
    local p = Open77.players.position(id)
    if p then return p end
    local ok, read = pcall(Open77.players.get, id)
    if ok and type(read) == "table" and type(read.position) == "table" then return read.position end
end
local function distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
local function near(id, point, radius)
    local p = positionOf(id)
    return p ~= nil and bucketOf(id) == 0 and distance(p, point.position) <= radius
end

-- ---------------------------------------------------------------------------
-- Reputation (per character)

Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_mission_rep (
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL,
    rep INT NOT NULL DEFAULT 0, completed INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, character_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local function owner(id)
    local c = LightRP.characters.get(id)
    if c and c.status == "active" and c.identifier then return c.identifier, c.key end
end
local function loadRep(id)
    reputation[id] = { rep = 0, completed = 0 }
    local identifier, key = owner(id)
    if not identifier or not Db.ready then return end
    local row = Db.single("SELECT rep, completed FROM lightrp_mission_rep WHERE identifier = ? AND character_key = ?", { identifier, key })
    if row then reputation[id] = { rep = tonumber(row.rep) or 0, completed = tonumber(row.completed) or 0 } end
end
local function saveRep(id)
    local identifier, key = owner(id)
    local r = reputation[id]
    if not identifier or not r or not Db.ready then return end
    Db.run("INSERT INTO lightrp_mission_rep (identifier, character_key, rep, completed) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE rep = VALUES(rep), completed = VALUES(completed)",
        { identifier, key, r.rep, r.completed })
end
function Missions.reputation(id) return (reputation[id] or {}).rep or 0 end

-- Unlocks: a difficulty opens once the character has the reputation tier it needs
-- (C.reputation.difficultyTiers, `requireTier`) and completed the one before it at
-- the same mission point (`requireClear`; the first is always open).
-- docs/pve-progression.md.
Db.schema([[CREATE TABLE IF NOT EXISTS lightrp_mission_clears (
    identifier VARCHAR(128) NOT NULL, character_key VARCHAR(64) NOT NULL,
    point_id VARCHAR(64) NOT NULL, difficulty VARCHAR(32) NOT NULL, completed INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier, character_key, point_id, difficulty)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
local clears = {} -- playerId -> { [pointId] = { [difficulty] = count } }
local function loadClears(id)
    clears[id] = {}
    local identifier, key = owner(id)
    if not identifier or not Db.ready then return end
    for _, row in ipairs(Db.query("SELECT point_id, difficulty, completed FROM lightrp_mission_clears WHERE identifier = ? AND character_key = ?", { identifier, key }) or {}) do
        clears[id][row.point_id] = clears[id][row.point_id] or {}
        clears[id][row.point_id][row.difficulty] = tonumber(row.completed) or 0
    end
end
function Missions.cleared(id, pointId, diffId)
    return ((clears[id] or {})[pointId] or {})[diffId] or 0
end
function Missions.addClear(id, pointId, diffId, count)
    clears[id] = clears[id] or {}
    clears[id][pointId] = clears[id][pointId] or {}
    local n = math.max(0, (clears[id][pointId][diffId] or 0) + (count or 1))
    clears[id][pointId][diffId] = n
    local identifier, key = owner(id)
    if not identifier or not Db.ready then return end
    Db.run("INSERT INTO lightrp_mission_clears (identifier, character_key, point_id, difficulty, completed) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE completed = VALUES(completed)",
        { identifier, key, pointId, diffId, n })
end
-- the difficulty before `d` at its point, or nil for the first
local function previousOf(point, d)
    for i, other in ipairs(point.difficulties) do
        if other.id == d.id then return point.difficulties[i - 1] end
    end
end
function Missions.tier(id)
    local rep, tier = Missions.reputation(id), 1
    for i, threshold in ipairs(C.reputation.tiers) do if rep >= threshold then tier = i end end
    return tier
end

-- ---------------------------------------------------------------------------
-- Reputation tiers: what opens the harder difficulties (here, activities.lua) and
-- the higher cyberware ranks (cyberware.lua).

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII" }
function Missions.tierName(tier) return (C.reputation.names or {})[tier] or ("Tier " .. tostring(tier)) end
-- "II (Merc)"
function Missions.tierLabel(tier) return (ROMAN[tier] or tostring(tier)) .. " (" .. Missions.tierName(tier) .. ")" end
-- What the pages show: the tier, its name, the points and the next threshold.
function Missions.tierInfo(id)
    local tier = Missions.tier(id)
    local tiers = C.reputation.tiers
    return { tier = tier, name = Missions.tierName(tier), points = Missions.reputation(id), max = #tiers,
        next = tiers[tier + 1], nextName = tiers[tier + 1] and Missions.tierName(tier + 1) or nil }
end
-- The tier a difficulty needs: its own `minTier`, else the config's tier for its
-- id, else its `tier` field (the built-in points), else 1.
function Missions.requiredTier(d)
    if type(d) ~= "table" then return 1 end
    local need = tonumber(d.minTier) or (C.reputation.difficultyTiers or {})[d.id] or tonumber(d.tier)
    need = need and math.floor(need) or 1
    return need >= 1 and need or 1
end
function Missions.tierAllows(id, d)
    return C.reputation.requireTier == false or Missions.tier(id) >= Missions.requiredTier(d)
end
local function ladderOpen(id, point, d)
    if C.reputation.requireClear == false then return true end
    local before = previousOf(point, d)
    return not before or Missions.cleared(id, point.id, before.id) > 0
end
function Missions.unlocked(id, point, d)
    return Missions.tierAllows(id, d) and ladderOpen(id, point, d)
end
-- The difficulty a finished run pays this character at: `d` itself when they have it
-- unlocked, else the highest one below it at `point` they have unlocked. A crew
-- member the leader brings above their street cred (or past the clear ladder) is
-- never refused: they play `d` in full and earn that one's reputation (owner
-- decision 2026-11-03, docs/pve-progression.md). `ladder`: the clear ladder counts
-- too (missions, the raid); a gig counts the tier only. Without a point, the ids of
-- `reputationGain` stand in for the difficulties. nil: nothing unlocked pays.
function Missions.rewardBasis(id, d, point, ladder)
    if type(d) ~= "table" then return nil end
    ladder = ladder == true and type(point) == "table"
    local function open(x) return Missions.tierAllows(id, x) and (not ladder or ladderOpen(id, point, x)) end
    if open(d) then return d end
    local best
    if type(point) == "table" then
        for _, x in ipairs(point.difficulties) do
            if x.id == d.id then break end
            if open(x) then best = x end
        end
        return best
    end
    local gain, bestGain = C.reputationGain[d.id] or 0, -1
    for diffId, amount in pairs(C.reputationGain) do
        if Missions.tierAllows(id, { id = diffId }) and amount <= gain and amount > bestGain then best, bestGain = { id = diffId }, amount end
    end
    return best
end
-- The reputation of the reward `basisId` earned on the difficulty `d` played: an
-- authored difficulty pays it in proportion to its size, like its eddies
-- (mission_pay.lua contentScale; 1 for Chimera, Sector 04 and big contracts).
local function gain(basisId, d)
    local rep = C.reputationGain[basisId] or 0
    local Pay = LightRP.missionPay
    if rep > 0 and Pay and type(Pay.contentScale) == "function" then rep = math.floor(rep * Pay.contentScale(d) + 0.5) end
    return rep
end
Missions.reputationGainOf = gain
-- The repeat rule on a finished run's reputation (owner decision 2026-11-04,
-- mission_pay.lua Pay.reputation): the reputation granted and the words the
-- notice adds when it is reduced ("" in full). A full grant starts the point's window.
local function repeatReputation(id, point, rep)
    local Pay = LightRP.missionPay
    if rep > 0 and Pay and type(Pay.reputation) == "function" then
        local amount, _, words = Pay.reputation(id, point.id, rep)
        return amount, words or ""
    end
    return rep, ""
end
-- The reputation a finished difficulty pays this character (Missions.rewardBasis).
function Missions.reputationFor(id, d, point, ladder)
    local basis = Missions.rewardBasis(id, d, point, ladder)
    return basis and gain(basis.id, d) or 0
end
-- "CRITICAL" -> "Critical": a difficulty's label inside a sentence.
local function sentenceLabel(d)
    local label = tostring(type(d) == "table" and (d.label or d.id) or d or "")
    return label:sub(1, 1):upper() .. label:sub(2):lower()
end
-- Tells a crew member brought into a difficulty they have not unlocked what they
-- earn there, once, as they enter. true, basis (nil: no reward) when they are below
-- it; false when `d` is theirs (nothing said).
function Missions.tellCarried(id, point, d, ladder)
    local basis = Missions.rewardBasis(id, d, point, ladder)
    if basis == d then return false end
    local earns = basis and string.format("you earn the %s reward (+%d reputation)", sentenceLabel(basis), gain(basis.id, d))
        or "it earns you no reputation"
    local body
    if not Missions.tierAllows(id, d) then
        body = string.format("%s is above your street cred: you play it, %s.", sentenceLabel(d), earns)
    else
        body = string.format("You have not cleared %s here yet: you play %s, %s.", sentenceLabel(previousOf(point, d)), sentenceLabel(d), earns)
    end
    LightRP.notice(id, { kind = "info", title = "STREET CRED", durationMs = 9000, body = body })
    return true, basis
end
Missions.sentenceLabel = sentenceLabel
function Missions.addReputation(id, amount)
    reputation[id] = reputation[id] or { rep = 0, completed = 0 }
    local before = Missions.tier(id)
    reputation[id].rep = math.max(0, reputation[id].rep + math.floor(tonumber(amount) or 0))
    saveRep(id)
    local after = Missions.tier(id)
    if after > before then
        local opens = (C.reputation.opens or {})[after]
        LightRP.notice(id, { kind = "success", title = "STREET CRED", durationMs = 10000,
            body = string.format("Reputation tier %s reached.%s", Missions.tierLabel(after), opens and (" " .. opens) or "") })
    end
end

-- ---------------------------------------------------------------------------
-- Lobbies

local function diffOf(point, id) for _, d in ipairs(point.difficulties) do if d.id == id then return d end end end

-- Crews (server/modules/parties.lua). A player alone, or in a crew of one still
-- waiting for answers, enters solo. Guarded: tests may stub parties with `of` only.
local function partyOf(id)
    local P = LightRP.parties
    return P and type(P.of) == "function" and P.of(id) or nil
end
local function crewOf(id)
    local crew = partyOf(id)
    if crew and #crew.members > 1 then return crew end
    return nil
end
local function matchmakingOf(id)
    local P = LightRP.parties
    return P ~= nil and type(P.matchmaking) == "function" and P.matchmaking(id) == true
end
local function entryKey(id) local crew = crewOf(id); return crew and crew.id or ("solo:" .. id) end

local function lobbyView(lobby, point, d)
    local members = {}
    for i, m in ipairs(lobby and lobby.members or {}) do
        members[i] = { id = m.id, name = name(m.id), citizen = citizen(m.id), tier = Missions.tier(m.id), host = i == 1, squad = m.squad }
    end
    return {
        id = lobby and lobby.id or nil, difficulty = d.id, members = members, min = d.min, max = d.max,
        state = lobby and lobby.state or "open",
        countdownMs = lobby and lobby.state == "countdown" and math.max(0, lobby.launchAt - now()) or nil,
        host = lobby and lobby.members[1] and name(lobby.members[1].id) or nil,
    }
end

-- The lobby a matchmaking tag of `size` operators joins: the fullest lobby open
-- to matchmaking with room.
local function pickLobby(point, d, size)
    local best
    for _, lobby in pairs(lobbies) do
        if lobby.open and lobby.point == point.id and lobby.difficulty == d.id and lobby.state == "open"
            and #lobby.members + size <= d.max and (not best or #lobby.members > #best.members) then
            best = lobby
        end
    end
    return best
end

-- What a player sees on a difficulty's board: their own lobby, else (open to
-- matchmaking) the one their crew would join.
local function boardFor(id, point, d)
    local mine = queueOf[id] and lobbies[queueOf[id]]
    if mine and mine.point == point.id and mine.difficulty == d.id then return mine end
    if not matchmakingOf(id) then return nil end
    local crew = crewOf(id)
    return pickLobby(point, d, crew and #crew.members or 1)
end
-- How many lobbies open to matchmaking have room for this player's crew: the
-- board tells a closed crew that somebody is looking for operators.
local function openLobbies(id, point, d)
    local crew = crewOf(id)
    local size, count = crew and #crew.members or 1, 0
    for _, lobby in pairs(lobbies) do
        if lobby.open and lobby.point == point.id and lobby.difficulty == d.id and lobby.state == "open"
            and lobby.id ~= queueOf[id] and #lobby.members + size <= d.max then
            count = count + 1
        end
    end
    return count
end

local pushPoint, pushQueue

local function startCountdown(lobby, seconds, forced)
    lobby.state, lobby.launchAt, lobby.forced = "countdown", now() + seconds * 1000, forced == true
    for _, m in ipairs(lobby.members) do
        LightRP.notice(m.id, { kind = "contract", title = "CREW READY", durationMs = seconds * 1000,
            body = string.format("%s launches in %d seconds. Stay near the mission point.", points[lobby.point].title, seconds) })
        pushQueue(m.id)
    end
end

-- A private lobby launches as soon as its crew is enough (nobody else comes); a
-- lobby open to matchmaking waits to be full, or for its host to launch early.
local function evaluate(lobby, why)
    local d = diffOf(points[lobby.point], lobby.difficulty)
    local n = #lobby.members
    if n == 0 then lobbies[lobby.id] = nil; return end
    if lobby.state == "open" and n >= (lobby.open and d.max or d.min) then startCountdown(lobby, C.countdown, false)
    elseif lobby.state == "countdown" and n < ((lobby.forced or not lobby.open) and d.min or d.max) then
        lobby.state, lobby.launchAt, lobby.forced = "open", nil, false
        local body = why or (lobby.open and "An operator left the board. Waiting for matchmaking to fill the crew again."
            or string.format("An operator left the board: %s needs %d. Tag the crew in again when it is ready.", d.label, d.min))
        for _, m in ipairs(lobby.members) do
            LightRP.notice(m.id, { kind = "warning", title = "LAUNCH CANCELLED", body = body })
        end
    end
end

local function untag(id, why)
    local lobby = queueOf[id] and lobbies[queueOf[id]]
    queueOf[id] = nil
    if not lobby then return end
    for i, m in ipairs(lobby.members) do if m.id == id then table.remove(lobby.members, i) break end end
    if why then LightRP.notice(id, { kind = "warning", title = "UNTAGGED", body = why }) end
    evaluate(lobby)
    pushQueue(id)
    for _, m in ipairs(lobby.members) do pushQueue(m.id) end
    pushPoint(lobby.point)
end
Missions.untag = untag

-- Can this player go on this board? The reason reads for them ("you") or for
-- their crew leader (their name).
local REASONS = {
    character = { "You have no active character.", "%s has no active character." },
    mission = { "You are already on a mission.", "%s is already on a mission." },
    down = { "You are down.", "%s is down." },
    tier = { "Complete %s first.", "%s must complete %s first." },
    rep = { "You need reputation tier %s: PvE missions, raids, gigs and PvE activities earn it.", "%s needs reputation tier %s." },
    away = { "You are not at the mission point.", "%s is not at the mission point." },
}
local function reason(code, id, self, d, point)
    local r = REASONS[code]
    local before = point and d and previousOf(point, d)
    local what = before and (before.label .. " " .. point.title) or ""
    if code == "rep" then what = Missions.tierLabel(Missions.requiredTier(d)) end
    if self then return r[1]:format(what) end
    return r[2]:format(name(id), what)
end
-- `carried`: a crew member their leader tags in. The difficulty is the leader's
-- pick: a member below its tier (or its clear ladder) is never refused, plays it in
-- full and earns the reward of the highest difficulty they have unlocked
-- (Missions.rewardBasis). The leader, and a player alone, are gated.
local function eligible(id, point, d, radius, test, gig, carried)
    if not LightRP.characters.isRegistered(id) then return false, "character" end
    if instanceOf[id] then return false, "mission" end
    local life = Open77.players.getLifeState(id)
    if life and life.phase ~= "alive" then return false, "down" end
    -- an editor test run starts wherever its author stands, at any difficulty
    if test then return bucketOf(id) == 0, "away" end
    -- a fixer gig is handed out: no unlock ladder, only the meeting point (the fixer
    -- offers its owner difficulties of their tier; a crew member's reputation follows
    -- their own tier, Missions.reputationFor)
    if not gig and not carried and not Missions.tierAllows(id, d) then return false, "rep" end
    if not gig and not carried and not ladderOpen(id, point, d) then return false, "tier" end
    if not near(id, point, radius) then return false, "away" end
    return true
end

-- Entry by crew: the leader tags the whole crew in (members within
-- `groupRadius`), a member alone cannot; a player alone is a crew of one. The
-- crew gets its own lobby unless it is open to matchmaking, which joins the
-- fullest open lobby with room (the old public board).
local function tag(id, pointId, diffId)
    local point = points[pointId]
    local d = point and diffOf(point, diffId)
    if not d then return false, "This board is closed." end
    if lastTag[id] and now() - lastTag[id] < C.tagCooldownMs then return false, "One moment." end
    lastTag[id] = now()
    local crew = crewOf(id)
    local list = { id }
    if crew then
        if crew.leader ~= id then return false, "Your crew leader tags the crew in. Leave the crew to go solo." end
        list = {}
        for _, member in ipairs(crew.members) do list[#list + 1] = member end
    end
    if #list > d.max then return false, string.format("Your crew is %d: %s takes %d operators at most.", #list, d.label, d.max) end
    for _, member in ipairs(list) do
        local ok, code = eligible(member, point, d, member == id and C.tagRadius or C.groupRadius, nil, nil, member ~= id)
        if not ok then return false, reason(code, member, member == id, d, point) end
    end
    local open = matchmakingOf(id)
    if not open and #list < d.min then
        if crew then
            return false, string.format("%s needs %d operators: your crew is %d. Invite more, or open the crew to matchmaking.", d.label, d.min, #list)
        end
        return false, string.format("%s needs %d operators. Form a crew (ALT on a player > Invite to crew), or turn matchmaking on.", d.label, d.min)
    end
    for _, member in ipairs(list) do
        if queueOf[member] then untag(member) end
    end
    local lobby = open and pickLobby(point, d, #list) or nil
    if not lobby then
        lobbySeq = lobbySeq + 1
        lobby = { id = "lobby:" .. lobbySeq, point = point.id, difficulty = d.id, members = {}, state = "open",
            open = open, owner = crew and crew.id or ("solo:" .. id) }
        lobbies[lobby.id] = lobby
    end
    local reduced = {}
    for _, member in ipairs(list) do
        lobby.members[#lobby.members + 1] = { id = member, squad = crew and crew.id or nil, carried = member ~= id or nil }
        queueOf[member] = lobby.id
        if member ~= id then
            LightRP.notice(member, { kind = "contract", title = "TAGGED IN", body = name(id) .. " tagged the crew in: " .. point.title .. " · " .. d.label .. "." })
            -- below the leader's pick: in all the same, for their own reward (told once)
            local below, basis = Missions.tellCarried(member, point, d, true)
            if below then reduced[#reduced + 1] = string.format("%s (%s)", name(member), basis and sentenceLabel(basis) or "none") end
        end
    end
    evaluate(lobby)
    for _, m in ipairs(lobby.members) do pushQueue(m.id) end
    pushPoint(point.id)
    local note = #reduced > 0 and (" Below " .. sentenceLabel(d) .. ", reduced reward: " .. table.concat(reduced, ", ") .. ".") or ""
    if lobby.state == "countdown" then
        return true, string.format("Tagged in. %s launches in %d seconds.", point.title, math.ceil((lobby.launchAt - now()) / 1000)) .. note
    end
    local missing = d.max - #lobby.members
    if not lobby.open then
        return true, string.format("Tagged in. %d/%d operators: %s needs %d.", #lobby.members, d.max, d.label, d.min) .. note
    end
    return true, string.format("Tagged in. %d/%d operators, matchmaking looks for %d more.", #lobby.members, d.max, missing) .. note
end

local function hostLaunch(id)
    local lobby = queueOf[id] and lobbies[queueOf[id]]
    if not lobby then return false, "You are not tagged in." end
    if lobby.members[1].id ~= id then return false, "Only the host launches early." end
    local d = diffOf(points[lobby.point], lobby.difficulty)
    if #lobby.members < d.min then return false, string.format("%s needs %d operators at least.", d.label, d.min) end
    if lobby.state == "countdown" then return false, "The countdown is already running." end
    startCountdown(lobby, C.hostCountdown, true)
    for _, m in ipairs(lobby.members) do pushQueue(m.id) end
    pushPoint(lobby.point)
    return true, "Launching."
end

-- ---------------------------------------------------------------------------
-- Instances

-- The squad frame: every operator's health, armor and life state, read from
-- the host's authoritative snapshot (players.stats.read / players.life.read).
local DOWN = { revivepending = "down", dead = "dead", respawnpending = "dead", recovering = "recovering" }
local function squadView(inst)
    local list = {}
    for i, id in ipairs(inst.members) do
        local ok, read = pcall(Open77.players.get, id)
        read = ok and type(read) == "table" and read or {}
        local phase = DOWN[read.lifePhase or ""] or (read.dead and "dead") or "alive"
        list[i] = { id = id, name = name(id), citizen = citizen(id), host = i == 1,
            health = math.floor((tonumber(read.health) or 0) + 0.5), maxHealth = math.floor((tonumber(read.maxHealth) or 100) + 0.5),
            armor = math.floor((tonumber(read.armor) or 0) + 0.5), state = phase }
    end
    return list
end

local function instanceView(inst, viewer)
    local point, d = points[inst.point], diffOf(points[inst.point], inst.difficulty)
    local view = { running = true, instance = inst.id, title = point.title, difficulty = d.label, difficultyId = d.id,
        endsInMs = math.max(0, inst.endsAt - now()), members = #inst.members, squad = squadView(inst) }
    -- what the mission script wants on the HUD (objective, wave, out-of-zone countdown)
    local script = scripts[inst.point]
    if script and script.view then
        local ok, objective = pcall(script.view, inst, viewer)
        if ok then view.objective = objective else LightRP.log("missions: %s view failed: %s", inst.point, tostring(objective)) end
    end
    return view
end

-- Leaving a mission (done, failed or abandoned) puts the operator back on their
-- feet at full health; a body still respawning is healed once it stands.
local function healOnReturn(id)
    if type(Open77.players.heal) ~= "function" then return end
    for _ = 1, 40 do
        local life = Open77.players.getLifeState(id)
        if not life then return end
        if life.phase == "alive" then
            local ok, applied, why = pcall(Open77.players.heal, id, 10000)
            if not ok or applied == false then LightRP.log("missions: %s could not be healed (%s)", name(id), tostring(ok and why or applied)) end
            return
        end
        Wait(250)
    end
end

local function sendHome(id, point, slot)
    local spot = point.position
    local p = { x = spot.x + ((slot or 1) - 1) * 0.8, y = spot.y - 1.5, z = spot.z }
    -- an operator down at the end of the mission comes back alive at the point
    local life = Open77.players.getLifeState(id)
    local cover = LightRP.zoneLoading and LightRP.zoneLoading.cover(id, { title = "Night City", subtitle = point.title,
        zone = "Shared city", target = p })
    if life and life.phase ~= "alive" then
        local ok, why = Open77.players.respawn(id, { position = p, heading = 0, bucket = 0,
            health = LightRpConfig.spawn and LightRpConfig.spawn.health or nil })
        if not ok then
            SetPlayerRoutingBucket(id, 0)
            LightRP.log("missions: %s could not be respawned at the point (%s)", name(id), tostring(why))
        end
        if LightRP.recap then pcall(LightRP.recap.home, id) end -- the end-of-mission recap may open
        CreateThread(function() healOnReturn(id) end)
        return
    end
    CreateThread(function()
        local promise, why = Open77.players.teleport(id, p, { heading = 0, bucket = 0, fade = true, dismount = true, timeoutMs = 30000 })
        local placed
        if promise then placed, why = promise:await() end
        if LightRP.zoneLoading then LightRP.zoneLoading.release(id, cover) end
        if not placed then
            SetPlayerRoutingBucket(id, 0)
            LightRP.log("missions: %s could not be brought back (%s)", name(id), tostring(why))
        end
        if LightRP.recap then pcall(LightRP.recap.home, id) end -- the end-of-mission recap may open
        healOnReturn(id)
    end)
end

local function removeMember(inst, id)
    for i, m in ipairs(inst.members) do if m == id then table.remove(inst.members, i) return true end end
end

local function finish(inst, success, why)
    if inst.state ~= "running" then return end
    inst.state = success and "complete" or "failed"
    instances[inst.id] = nil
    local point, d = points[inst.point], diffOf(points[inst.point], inst.difficulty)
    local script = scripts[inst.point]
    if script and script.onEnd then
        local ok, err = pcall(script.onEnd, inst, success, why)
        if not ok then LightRP.log("missions: %s onEnd failed: %s", inst.point, tostring(err)) end
    end
    -- the end-of-mission recap (recap.lua): the crew, the run, the raid's hits
    if LightRP.recap then pcall(LightRP.recap.missionEnded, inst, success, why, point, d) end
    -- What each finisher earns (crew pot, cooldown, daily cap): server/modules/mission_pay.lua.
    local payouts = {}
    if success and not inst.test then
        if LightRP.missionPay then payouts = LightRP.missionPay.settle(inst, point, d)
        else LightRP.log("missions: payout rules unavailable (mission_pay.lua not loaded), nothing paid for %s", inst.id) end
    end
    for slot, id in ipairs(inst.members) do
        instanceOf[id] = nil
        setMapJam(id, false)
        local pay = payouts[id] or { amount = 0, detail = "" }
        local gained = 0
        if success and inst.gig then
            -- a gig counts the tier only (no clear ladder); the money is mission_pay's
            local basis = Missions.rewardBasis(id, d, point, false)
            local rep, repWords = repeatReputation(id, point, basis and gain(basis.id, d) or 0)
            Missions.addReputation(id, rep); gained = rep
            LightRP.notice(id, { kind = "success", title = "GIG COMPLETE", durationMs = 10000,
                body = string.format("%s · %s. %s wired by %s%s, +%d reputation%s%s.", point.title, d.label,
                    LightRP.money and LightRP.money.format(pay.amount) or tostring(pay.amount), inst.gig.fixerName or "your fixer", pay.detail, rep, repWords,
                    basis ~= d and (" (" .. (basis and sentenceLabel(basis) or "no") .. " reward)") or "") })
        elseif inst.gig then
            LightRP.notice(id, { kind = "error", title = "GIG FAILED", durationMs = 10000, body = point.title .. ": " .. (why or "the job went sideways.") })
        elseif success and inst.test then
            LightRP.notice(id, { kind = "success", title = "TEST RUN COMPLETE", durationMs = 10000,
                body = point.title .. " · " .. d.label .. ". Editor test runs pay nothing and unlock nothing." })
        elseif success then
            reputation[id] = reputation[id] or { rep = 0, completed = 0 }
            reputation[id].completed = reputation[id].completed + 1
            -- a crew member carried above what they have unlocked: the reward of their best
            local basis = Missions.rewardBasis(id, d, point, true)
            local rep, repWords = repeatReputation(id, point, basis and gain(basis.id, d) or 0)
            Missions.addReputation(id, rep); gained = rep
            local opens = Missions.cleared(id, point.id, d.id) == 0 and point.difficulties[(function()
                for i, other in ipairs(point.difficulties) do if other.id == d.id then return i + 1 end end
            end)() or 0]
            Missions.addClear(id, point.id, d.id)
            if opens and Missions.tierAllows(id, opens) then
                LightRP.notice(id, { kind = "success", title = "UNLOCKED", durationMs = 10000,
                    body = string.format("%s · %s is now open to you.", point.title, opens.label) })
            elseif opens then
                LightRP.notice(id, { kind = "info", title = "CLEARED", durationMs = 10000,
                    body = string.format("%s · %s opens at reputation tier %s.", point.title, opens.label,
                        Missions.tierLabel(Missions.requiredTier(opens))) })
            end
            LightRP.notice(id, { kind = "success", title = "MISSION COMPLETE", durationMs = 10000,
                body = string.format("%s · %s. %s paid to your account%s, +%d reputation%s%s.", point.title, d.label, LightRP.money and LightRP.money.format(pay.amount) or tostring(pay.amount), pay.detail, rep, repWords,
                    basis ~= d and (" (" .. (basis and sentenceLabel(basis) or "no") .. " reward)") or "") })
        else
            LightRP.notice(id, { kind = "error", title = "MISSION FAILED", durationMs = 10000, body = point.title .. ": " .. (why or "the operation was lost.") })
        end
        if LightRP.recap then
            pcall(LightRP.recap.reward, id, "mission|" .. tostring(inst.id), { eddies = pay.amount, eddiesNote = pay.detail,
                eddiesReason = pay.state ~= "full" and pay.state or nil, reputation = gained })
        end
        sendHome(id, point, slot)
        if inst.loadout then Missions.restoreArms(id) end
        pushQueue(id)
    end
    LightRP.log("missions: %s %s (%s) %s%s", inst.id, point.title, d.label, success and "complete" or "failed", why and (": " .. why) or "")
    LightRP.eachModule("onMissionFinished", inst, point, d, success, why, payouts) -- contracts, titles
    if inst.gig and type(inst.gig.onEnd) == "function" then
        local ok, err = pcall(inst.gig.onEnd, inst, success, why)
        if not ok then LightRP.log("missions: gig end hook failed: %s", tostring(err)) end
    end
    if point.retired then
        local busy = false
        for _, other in pairs(instances) do busy = busy or other.point == point.id end
        if not busy and points[point.id] == point then points[point.id] = nil end
        return
    end
    pushPoint(inst.point)
end

function Missions.complete(instanceId) local inst = instances[instanceId]; if not inst then return false end finish(inst, true); return true end
function Missions.fail(instanceId, why) local inst = instances[instanceId]; if not inst then return false end finish(inst, false, why); return true end
function Missions.instanceOf(id) return instanceOf[id] and instances[instanceOf[id]] end
-- A death inside a running mission belongs to its script (no unconscious state, no hospital).
function Missions.handlesDeath(id) return instanceOf[id] ~= nil end
-- A mission that hands out its own weapons (inst.loadout = true) owns the native
-- slots meanwhile; the character's RP weapons come back when the player leaves it.
function Missions.handlesLoadout(id)
    local inst = instanceOf[id] and instances[instanceOf[id]]
    return inst ~= nil and inst.loadout == true
end
-- The kit a mission handed this operator ({ id, primary, secondary, names }), for the
-- weapon wheel: during a mission it lists the kit, not the pockets (scripts: kitOf).
function Missions.kitOf(id)
    local inst = instanceOf[id] and instances[instanceOf[id]]
    local script = inst and inst.loadout and scripts[inst.point]
    if not script or type(script.kitOf) ~= "function" then return nil end
    local ok, kit = pcall(script.kitOf, inst, id)
    return ok and type(kit) == "table" and kit or nil
end
-- The wheel picked a kit weapon: K.draw, the kit handed out again by the mission's script.
function Missions.drawKit(id, slot)
    local inst = instanceOf[id] and instances[instanceOf[id]]
    local script = inst and scripts[inst.point]
    local kit = Missions.kitOf(id)
    if not kit or (slot ~= 1 and slot ~= 2) then return false, "No mission kit." end
    return K.draw(id, slot, kit, function()
        if type(script.reissueKit) == "function" then script.reissueKit(inst, id) end
    end)
end
local function restoreArms(id)
    CreateThread(function()
        Wait(3000)
        if instanceOf[id] or not LightRP.armament or type(LightRP.armament.synchronize) ~= "function" then return end
        local ok, done, why = pcall(LightRP.armament.synchronize, id)
        if not ok or done == false then LightRP.log("missions: weapons of %s not restored (%s)", name(id), tostring(ok and why or done)) end
    end)
end
Missions.restoreArms = restoreArms
function Missions.point(id) return points[id] end
function Missions.difficulty(inst) return diffOf(points[inst.point], inst.difficulty) end
function Missions.name(id) return name(id) end
function Missions.pushSquad(inst) for _, id in ipairs(inst.members) do pushQueue(id) end end
-- More time on the clock of a running mission (a script's own phases).
function Missions.extend(inst, seconds) inst.endsAt = inst.endsAt + seconds * 1000; Missions.pushSquad(inst) end
function Missions.register(pointId, script) scripts[pointId] = script end
function Missions.unregister(pointId) scripts[pointId] = nil end
function Missions.instances() local list = {}; for _, inst in pairs(instances) do list[#list + 1] = inst end; return list end

-- One operator leaves a running mission (abandon, disconnect, character change).
local function leaveInstance(id, why, goHome)
    local inst = instanceOf[id] and instances[instanceOf[id]]
    instanceOf[id] = nil
    if inst then setMapJam(id, false) end
    if not inst then return end
    removeMember(inst, id)
    local script = scripts[inst.point]
    if script and script.onLeave then pcall(script.onLeave, inst, id, why) end
    if inst.loadout then Missions.restoreArms(id) end
    if goHome then
        sendHome(id, points[inst.point], 1)
        LightRP.notice(id, { kind = "warning", title = "MISSION ABANDONED", body = "You left " .. points[inst.point].title .. ". No payout." })
        pushQueue(id)
    end
    for _, other in ipairs(inst.members) do
        LightRP.notice(other, { kind = "warning", title = "OPERATOR LOST", body = name(id) .. " left the mission." })
        pushQueue(other)
    end
    if #inst.members == 0 then finish(inst, false, "every operator left") end
end

local function launch(lobby)
    local point, d = points[lobby.point], diffOf(points[lobby.point], lobby.difficulty)
    -- last check: everyone still there
    for i = #lobby.members, 1, -1 do
        local m = lobby.members[i]
        local ok = eligible(m.id, point, d, C.leash, lobby.test, lobby.gig ~= nil, m.carried)
        if not ok then
            table.remove(lobby.members, i)
            queueOf[m.id] = nil
            LightRP.notice(m.id, { kind = "warning", title = "UNTAGGED", body = "You were not ready when the mission launched." })
            pushQueue(m.id)
        end
    end
    if #lobby.members < d.min then
        lobby.state, lobby.launchAt, lobby.forced = "open", nil, false
        if #lobby.members == 0 then lobbies[lobby.id] = nil end
        for _, m in ipairs(lobby.members) do pushQueue(m.id) end
        pushPoint(point.id)
        return
    end
    lobbies[lobby.id] = nil
    instanceSeq = instanceSeq + 1
    local inst = { id = "mission:" .. instanceSeq, point = point.id, difficulty = d.id, bucket = C.bucketBase + instanceSeq,
        members = {}, startedAt = now(), endsAt = now() + d.minutes * 60000, state = "running", test = lobby.test == true, gig = lobby.gig }
    instances[inst.id] = inst
    for slot, m in ipairs(lobby.members) do
        queueOf[m.id] = nil
        instanceOf[m.id] = inst.id
        setMapJam(m.id, true)
        inst.members[#inst.members + 1] = m.id
        if viewers[m.id] then
            TriggerClientEvent(E.net.mission, m.id, { session = viewers[m.id].session, closed = true })
            viewers[m.id] = nil
        end
        local spot = point.start[((slot - 1) % #point.start) + 1]
        local cover = LightRP.zoneLoading and LightRP.zoneLoading.cover(m.id, { title = point.title, subtitle = d.label, zone = "Mission" })
        CreateThread(function()
            local promise, why = Open77.players.teleport(m.id, spot, { heading = spot.heading or 0, bucket = inst.bucket, fade = true, dismount = true, timeoutMs = 30000 })
            local placed
            if promise then placed, why = promise:await() end
            if LightRP.zoneLoading then LightRP.zoneLoading.release(m.id, cover) end
            if not placed and instanceOf[m.id] == inst.id then
                LightRP.log("missions: %s could not reach %s (%s)", name(m.id), inst.id, tostring(why))
                LightRP.notice(m.id, { kind = "error", title = "MISSION", body = "The mission area did not load. You stay in the city." })
                leaveInstance(m.id, "travel", false)
                SetPlayerRoutingBucket(m.id, 0)
            end
        end)
        LightRP.notice(m.id, { kind = "contract", title = "MISSION STARTED", durationMs = 8000,
            body = string.format("%s · %s. %d minutes on the clock.", point.title, d.label, d.minutes) })
        pushQueue(m.id)
    end
    LightRP.log("missions: %s launched %s (%s) with %d operator(s) in bucket %d", inst.id, point.title, d.label, #inst.members, inst.bucket)
    if LightRP.missionPay then LightRP.missionPay.announce(inst, point, d) end
    local script = scripts[point.id]
    if script and script.onStart then
        local ok, err = pcall(script.onStart, inst)
        if not ok then LightRP.log("missions: %s onStart failed: %s", point.id, tostring(err)) end
    end
    pushPoint(point.id)
end

-- ---------------------------------------------------------------------------
-- The page

local function nearbyPlayers(id)
    local list, me = {}, positionOf(id)
    if not me then return list end
    local squad = partyOf(id)
    for _, other in ipairs(GetPlayers()) do
        other = tonumber(other)
        if other and other ~= id and LightRP.characters.isRegistered(other) and bucketOf(other) == bucketOf(id) then
            local p = positionOf(other)
            if p and distance(p, me) <= C.party.nearby then
                local theirs = partyOf(other)
                list[#list + 1] = { id = other, name = name(other), citizen = citizen(other), tier = Missions.tier(other),
                    inSquad = theirs ~= nil, mine = squad ~= nil and theirs == squad,
                    invited = squad ~= nil and squad.invites[other] ~= nil and squad.invites[other] > now() }
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function snapshot(id, pointId)
    local point = points[pointId]
    local tier = Missions.tier(id)
    local difficulties, boards = {}, {}
    for _, d in ipairs(point.difficulties) do
        local lobby = boardFor(id, point, d)
        local need = Missions.requiredTier(d)
        local before = C.reputation.requireClear ~= false and previousOf(point, d) or nil
        -- what this player earns there: in full when it is unlocked, else (a crew member
        -- the leader brings) the reward of the highest difficulty they have unlocked
        local basis = Missions.rewardBasis(id, d, point, true)
        -- the payout after the ceilings (mission_pay.lua): an authored mission saved with an
        -- old or oversized figure shows what it really pays
        local payout = LightRP.missionPay and LightRP.missionPay.cap(d.payout, d) or d.payout
        difficulties[#difficulties + 1] = { id = d.id, label = d.label, blurb = d.blurb, payout = payout, minutes = d.minutes,
            min = d.min, max = d.max, tier = need, tierName = Missions.tierName(need), tierLocked = not Missions.tierAllows(id, d),
            locked = not Missions.unlocked(id, point, d), tagged = lobby and #lobby.members or 0,
            requires = before and before.label or nil, cleared = Missions.cleared(id, point.id, d.id),
            openLobbies = openLobbies(id, point, d),
            reputation = gain(d.id, d), earns = basis and gain(basis.id, d) or 0,
            earnsAs = basis and basis ~= d and basis.label or nil }
        boards[d.id] = lobbyView(lobby, point, d)
    end
    local mine = queueOf[id] and lobbies[queueOf[id]]
    local crew = crewOf(id)
    return {
        kind = "mission", session = viewers[id] and viewers[id].session,
        point = { id = point.id, title = point.title, type = point.type, location = point.location, description = point.description },
        me = { id = id, name = name(id), citizen = citizen(id), tier = tier, tierName = Missions.tierName(tier), reputation = Missions.reputation(id),
            nextTier = C.reputation.tiers[tier + 1] },
        difficulties = difficulties, boards = boards,
        tagged = mine and mine.point == point.id and { lobby = mine.id, difficulty = mine.difficulty, host = mine.members[1].id == id } or nil,
        taggedElsewhere = mine and mine.point ~= point.id and points[mine.point].title or nil,
        nearby = nearbyPlayers(id),
        -- how this player enters: alone, or with their crew (only its leader tags in)
        entry = { crew = crew and crew.id or nil, size = crew and #crew.members or 1, leader = crew and name(crew.leader) or nil,
            leads = crew == nil or crew.leader == id, matchmaking = matchmakingOf(id),
            open = mine ~= nil and mine.open == true },
        keys = { tagRadius = C.tagRadius },
    }
end

function pushPoint(pointId)
    for id, v in pairs(viewers) do
        if v.point == pointId then TriggerClientEvent(E.net.mission, id, { session = v.session, state = snapshot(id, pointId) }) end
    end
end

LightRP.stateProvider("missionQueue", function(id)
    local inst = instanceOf[id] and instances[instanceOf[id]]
    if inst then return instanceView(inst, id) end
    local lobby = queueOf[id] and lobbies[queueOf[id]]
    if not lobby then return false end
    local point, d = points[lobby.point], diffOf(points[lobby.point], lobby.difficulty)
    return { running = false, title = point.title, difficulty = d.label, difficultyId = d.id, count = #lobby.members, min = d.min, max = d.max,
        state = lobby.state, countdownMs = lobby.state == "countdown" and math.max(0, lobby.launchAt - now()) or nil,
        host = lobby.members[1] and lobby.members[1].id == id, open = lobby.open == true }
end)
-- A tagged board also shows in the player's queue panel (activity_queue.lua), which
-- hears of every change here.
function pushQueue(id)
    LightRP.state(id, "missionQueue")
    local queue = LightRP.activityQueue
    if queue and queue.refresh then queue.refresh(id) end
end
-- The board this player is tagged on, for the queue panel: nil once it launched.
function Missions.queueEntry(id)
    local lobby = queueOf[id] and lobbies[queueOf[id]]
    if not lobby or instanceOf[id] then return nil end
    local point = points[lobby.point]
    local d = point and diffOf(point, lobby.difficulty)
    if not d then return nil end
    return { key = lobby.id, label = point.title, mode = d.label, count = #lobby.members, need = d.min, max = d.max,
        startsAt = lobby.state == "countdown" and lobby.launchAt or nil }
end
function Missions.queuedPlayers()
    local list = {}
    for id in pairs(queueOf) do list[#list + 1] = id end
    return list
end

function Missions.open(id, pointId)
    local point = points[pointId]
    if not point then return false, "Unknown mission point." end
    if point.fixer then return false, "This job is not on any board: the fixers hand it out." end
    if not LightRP.characters.isRegistered(id) then return false, "Finish your character first." end
    if instanceOf[id] then return false, "You are on a mission." end
    sessionSeq = sessionSeq + 1
    viewers[id] = { session = "mission:" .. sessionSeq, point = pointId }
    LightRP.dialog(id, "mission", snapshot(id, pointId))
    return true
end

local function session(id, payload)
    local v = viewers[id]
    if not v or type(payload) ~= "table" or payload.session ~= v.session then return nil end
    return v
end
local function reply(id, action, ok, text)
    LightRP.result(id, ok, text, action)
    local v = viewers[id]
    if v then TriggerClientEvent(E.net.mission, id, { session = v.session, state = snapshot(id, v.point) }) end
end

LightRP.action("mission.tag", function(id, payload)
    local v = session(id, payload); if not v then return end
    reply(id, "mission.tag", tag(id, v.point, payload.difficulty))
end)
-- the old "tag the squad in": a crew always enters together now
LightRP.action("mission.tagGroup", function(id, payload)
    local v = session(id, payload); if not v then return end
    reply(id, "mission.tagGroup", tag(id, v.point, payload.difficulty))
end)
LightRP.action("mission.matchmaking", function(id, payload)
    local v = session(id, payload); if not v then return end
    local P = LightRP.parties
    if not P or type(P.setMatchmaking) ~= "function" then return reply(id, "mission.matchmaking", false, "Matchmaking is not available.") end
    reply(id, "mission.matchmaking", P.setMatchmaking(id, payload.on == true))
end)
LightRP.action("mission.untag", function(id, payload)
    local v = session(id, payload); if not v then return end
    if not queueOf[id] then return reply(id, "mission.untag", false, "You are not tagged in.") end
    untag(id)
    reply(id, "mission.untag", true, "Untagged.")
end)
LightRP.action("mission.launch", function(id, payload)
    local v = session(id, payload); if not v then return end
    reply(id, "mission.launch", hostLaunch(id))
end)
LightRP.action("mission.close", function(id, payload)
    if session(id, payload) then viewers[id] = nil end
end)
-- the crew panel of the board refreshes after a crew action
function Missions.onPartyChanged(_, ids)
    local seen = {}
    for _, id in ipairs(ids or {}) do
        local v = viewers[id]
        if v and not seen[v.point] then seen[v.point] = true; pushPoint(v.point) end
    end
end
-- Leaving (or being removed from) a crew takes the player off its entry.
function Missions.onCrewLeft(id, crewId)
    local lobby = queueOf[id] and lobbies[queueOf[id]]
    if not lobby then return end
    for _, m in ipairs(lobby.members) do
        if m.id == id and m.squad == crewId then
            untag(id, "You left the crew: you are no longer tagged with it.")
            return
        end
    end
end
-- A player who joins a crew enters with it: their own tag drops.
function Missions.onCrewJoined(id)
    if queueOf[id] then untag(id, "You joined a crew: your crew leader tags the crew in.") end
end
-- The leader opened or closed the crew to matchmaking while it is tagged in.
function Missions.onCrewMatchmaking(id, on)
    local lobby = queueOf[id] and lobbies[queueOf[id]]
    if not lobby then return end
    if lobby.owner == entryKey(id) then
        lobby.open = on
        evaluate(lobby, on and "Matchmaking on: waiting for players to fill the crew." or nil)
        for _, m in ipairs(lobby.members) do pushQueue(m.id) end
        pushPoint(lobby.point)
    elseif not on then
        -- the crew sits in somebody else's open lobby: it comes off that board
        local P = LightRP.parties
        local members = P and type(P.members) == "function" and P.members(id) or { id }
        for _, member in ipairs(members) do
            if queueOf[member] == lobby.id then untag(member, "Matchmaking off: your crew left the shared board. Tag the crew in again.") end
        end
    end
end
-- The point a player is tagged on (the crew frame shows it).
function Missions.taggedOn(id)
    local lobby = queueOf[id] and lobbies[queueOf[id]]
    return lobby and points[lobby.point] and points[lobby.point].title or nil
end

-- ---------------------------------------------------------------------------
-- Lifecycle

function Missions.onCharacterLoaded(id)
    if queueOf[id] then untag(id) end
    if instanceOf[id] then leaveInstance(id, "character", false) end
    viewers[id] = nil
    loadRep(id)
    loadClears(id)
end
Missions.onCharacterActivated = Missions.onCharacterLoaded
function Missions.onDisconnected(id)
    if queueOf[id] then untag(id) end
    if instanceOf[id] then leaveInstance(id, "disconnected", false) end
    viewers[id], reputation[id], lastTag[id], clears[id] = nil, nil, nil, nil
end
function Missions.onDatabaseReady() for _, id in ipairs(GetPlayers()) do loadRep(tonumber(id)); loadClears(tonumber(id)) end end
function Missions.onLifeState(id, phase)
    if phase ~= "alive" and queueOf[id] then untag(id, "You went down: you are no longer tagged.") end
    local inst = instanceOf[id] and instances[instanceOf[id]]
    local script = inst and scripts[inst.point]
    if script and script.onLifeState then
        local ok, err = pcall(script.onLifeState, inst, id, phase)
        if not ok then LightRP.log("missions: %s onLifeState failed: %s", inst.point, tostring(err)) end
    end
end
function Missions.onInteract(id, point)
    local pointId = point:match("^mission%.(.+)$")
    if pointId then local ok, why = Missions.open(id, pointId); if not ok then LightRP.result(id, false, why, "mission.open") end end
end

-- Countdowns, wanderers and clocks.
CreateThread(function()
    while true do
        Wait(500)
        local t = now()
        for _, lobby in pairs(lobbies) do
            local point = points[lobby.point]
            for i = #lobby.members, 1, -1 do
                local m = lobby.members[i]
                if not near(m.id, point, C.leash) then untag(m.id, "You walked away from " .. point.title .. ": you are no longer tagged.") end
            end
            if lobbies[lobby.id] and lobby.state == "countdown" and t >= lobby.launchAt then launch(lobby) end
        end
        for _, inst in pairs(instances) do
            if t >= inst.endsAt then finish(inst, false, "time ran out")
            else
                -- the squad frame follows health and life states: pushed when something changed
                local key = json.encode(squadView(inst))
                if key ~= inst.squadKey then
                    inst.squadKey = key
                    for _, id in ipairs(inst.members) do pushQueue(id) end
                end
                local script = scripts[inst.point]
                if script and script.onTick and t - (inst.lastTick or 0) >= 1000 then
                    inst.lastTick = t
                    local ok, err = pcall(script.onTick, inst, (t - inst.startedAt) / 1000)
                    if not ok then LightRP.log("missions: %s onTick failed: %s", inst.point, tostring(err)) end
                end
            end
        end
        -- open boards keep their countdowns ticking on the page
        for id, v in pairs(viewers) do
            if not near(id, points[v.point], C.leash) then
                TriggerClientEvent(E.net.mission, id, { session = v.session, closed = true })
                viewers[id] = nil
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Commands

LightRP.command("mission", { usage = "/mission leave (abandon the running mission, or untag)" }, function(source, args)
    if args[1] ~= "leave" then
        local inst = instanceOf[source] and instances[instanceOf[source]]
        if inst then return true, string.format("%s · %s · %d min left.", points[inst.point].title, inst.difficulty, math.ceil((inst.endsAt - now()) / 60000)) end
        local lobby = queueOf[source] and lobbies[queueOf[source]]
        if lobby then return true, string.format("Tagged in %s (%s), %d operator(s).", points[lobby.point].title, lobby.difficulty, #lobby.members) end
        return true, "No mission. Find a mission point in the city."
    end
    if instanceOf[source] then leaveInstance(source, "abandoned", true); return true, "You left the mission." end
    if queueOf[source] then untag(source); return true, "Untagged." end
    return false, "You are not on a mission."
end)

local function staffTarget(args) return tonumber(args[1]) end
LightRP.command("missions.complete", { restricted = true, usage = "/missions.complete <playerId>" }, function(_, args)
    local inst = Missions.instanceOf(staffTarget(args) or -1)
    if not inst then return false, "That player is not on a mission." end
    finish(inst, true); return true, inst.id .. " completed."
end)
LightRP.command("missions.fail", { restricted = true, usage = "/missions.fail <playerId> [reason]" }, function(_, args)
    local inst = Missions.instanceOf(staffTarget(args) or -1)
    if not inst then return false, "That player is not on a mission." end
    finish(inst, false, table.concat(args, " ", 2) ~= "" and table.concat(args, " ", 2) or "called off"); return true, inst.id .. " failed."
end)
-- Launch a lobby now, whatever its size (tests with one operator).
LightRP.command("missions.launch", { restricted = true, usage = "/missions.launch <playerId>" }, function(_, args)
    local lobby = queueOf[staffTarget(args) or -1] and lobbies[queueOf[staffTarget(args)]]
    if not lobby then return false, "That player is not tagged in." end
    lobby.state, lobby.forced = "countdown", true
    local d = diffOf(points[lobby.point], lobby.difficulty)
    local min = d.min
    d.min = 1
    launch(lobby)
    d.min = min
    return true, "Launched."
end)
-- Tests: resize a difficulty for this run of the server (missions.size sector04_blackout standard 1 1).
LightRP.command("missions.size", { restricted = true, usage = "/missions.size <point> <difficulty> <min> <max>" }, function(_, args)
    local point = points[args[1] or ""]
    local d = point and diffOf(point, args[2] or "")
    local min, max = tonumber(args[3]), tonumber(args[4])
    if not d or not min or not max or min < 1 or max < min or max > 16 then return false, "usage: /missions.size <point> <difficulty> <min> <max>" end
    d.min, d.max = math.floor(min), math.floor(max)
    for _, lobby in pairs(lobbies) do if lobby.point == point.id and lobby.difficulty == d.id then evaluate(lobby) end end
    pushPoint(point.id)
    return true, string.format("%s %s: %d-%d operators.", point.title, d.label, d.min, d.max)
end)
-- Staff: /missions.unlock <playerId> <pointId> <difficulty> counts that difficulty as completed
-- (so the next one opens); /missions.unlock <playerId> <pointId> <difficulty> reset forgets it.
LightRP.command("missions.unlock", { restricted = true, usage = "/missions.unlock <playerId> <pointId> <difficulty> [reset]" }, function(_, args)
    local id, point = staffTarget(args), points[tostring(args[2] or "")]
    local d = point and diffOf(point, tostring(args[3] or ""))
    if not id or not d or not LightRP.characters.isRegistered(id) then return false end
    if args[4] == "reset" then Missions.addClear(id, point.id, d.id, -Missions.cleared(id, point.id, d.id))
    else Missions.addClear(id, point.id, d.id) end
    local v = viewers[id]
    if v then pushPoint(v.point) end
    return true, string.format("%s: %s %s completed %d time(s).", name(id), point.title, d.label, Missions.cleared(id, point.id, d.id))
end)
-- Staff: /missions.rep <playerId> shows the street reputation; with <points> sets it.
LightRP.command("missions.rep", { restricted = true, usage = "/missions.rep <playerId> [points]" }, function(_, args)
    local id, amount = staffTarget(args), tonumber(args[2])
    if not id or not LightRP.characters.isRegistered(id) or (args[2] ~= nil and not amount) then return false, "usage: /missions.rep <playerId> [points]" end
    if not amount then
        local info = Missions.tierInfo(id)
        return true, string.format("%s: %d reputation, tier %s%s.", name(id), info.points, Missions.tierLabel(info.tier),
            info.next and string.format(", next at %d", info.next) or "")
    end
    Missions.addReputation(id, amount - Missions.reputation(id))
    local v = viewers[id]
    if v then pushPoint(v.point) end
    return true, string.format("%s: %d reputation, tier %d.", name(id), Missions.reputation(id), Missions.tier(id))
end)

-- ---------------------------------------------------------------------------
-- Points

-- A point added at runtime (the mission editor publishes them): replaces the one
-- with the same id. A running instance keeps playing on the old definition's
-- script state; its board, lobbies and interaction follow the new one.
local function registerInteraction(point)
    if not C.enabled then return end
    -- a fixer gig has no board: the fixers hand it out (server/modules/fixers.lua)
    if point.fixer then LightRP.removeInteraction("mission." .. point.id); return end
    LightRP.interaction("mission." .. point.id, { position = point.position, radius = 2.0, bucket = 0,
        label = point.title, prompt = "Open the mission board", key = "E", marker = C.marker, ring = false,
        blip = { sprite = "objective", title = point.title, description = point.type .. " · " .. point.location } })
end
function Missions.addPoint(point)
    assert(type(point) == "table" and type(point.id) == "string" and type(point.difficulties) == "table" and #point.difficulties > 0
        and type(point.start) == "table" and #point.start > 0 and type(point.position) == "table", "Invalid mission point")
    local old = points[point.id]
    if not old then order[#order + 1] = point.id end
    points[point.id] = point
    -- lobbies on a difficulty that no longer exists, or now too small, are dropped
    for _, lobby in pairs(lobbies) do
        if lobby.point == point.id then
            local d = diffOf(point, lobby.difficulty)
            if not d or #lobby.members > d.max then
                for i = #lobby.members, 1, -1 do untag(lobby.members[i].id, point.title .. " changed: you are no longer tagged.") end
            else evaluate(lobby) end
        end
    end
    registerInteraction(point)
    pushPoint(point.id)
end
function Missions.removePoint(pointId)
    local point = points[pointId]
    if not point then return false end
    LightRP.removeInteraction("mission." .. pointId)
    for _, lobby in pairs(lobbies) do
        if lobby.point == pointId then
            for i = #lobby.members, 1, -1 do untag(lobby.members[i].id, point.title .. " was withdrawn: you are no longer tagged.") end
        end
    end
    for id, v in pairs(viewers) do
        if v.point == pointId then TriggerClientEvent(E.net.mission, id, { session = v.session, closed = true }); viewers[id] = nil end
    end
    for i, key in ipairs(order) do if key == pointId then table.remove(order, i) break end end
    local busy = false
    for _, inst in pairs(instances) do busy = busy or inst.point == pointId end
    if busy then point.retired = true else points[pointId] = nil end
    return true
end
-- Launch a mission now for these players, without the board (the editor's test
-- run). Members must be registered, alive, in the city and not on a mission.
function Missions.launchNow(pointId, difficultyId, members)
    local point = points[pointId]
    local d = point and diffOf(point, difficultyId)
    if not d then return false, "Unknown mission or difficulty." end
    for _, id in ipairs(members) do
        if instanceOf[id] then return false, name(id) .. " is already on a mission." end
        if queueOf[id] then untag(id) end
        if not LightRP.characters.isRegistered(id) then return false, "Finish your character first." end
        if bucketOf(id) ~= 0 then return false, "Leave your current instance first." end
    end
    lobbySeq = lobbySeq + 1
    local lobby = { id = "lobby:" .. lobbySeq, point = point.id, difficulty = d.id, members = {}, state = "countdown", forced = true, test = true }
    for _, id in ipairs(members) do lobby.members[#lobby.members + 1] = { id = id } end
    lobbies[lobby.id] = lobby
    local min = d.min
    d.min = 1
    local ok, err = pcall(launch, lobby)
    d.min = min
    lobbies[lobby.id] = nil
    if not ok then return false, tostring(err) end
    for _, id in ipairs(members) do if instanceOf[id] then return true end end
    return false, "Nobody could be launched."
end

-- Launch a fixer gig for its crew (server/modules/fixers.lua checked them at the
-- meeting point). `gig` rides on the instance: { id, payout, fixerName, onEnd(inst, success, why) }.
function Missions.launchGig(pointId, difficultyId, members, gig)
    local point = points[pointId]
    local d = point and diffOf(point, difficultyId)
    if not d or point.retired then return false, "This job is no longer available." end
    for _, id in ipairs(members) do
        if instanceOf[id] then return false, name(id) .. " is already on a mission." end
        if queueOf[id] then untag(id) end
    end
    lobbySeq = lobbySeq + 1
    local lobby = { id = "lobby:" .. lobbySeq, point = point.id, difficulty = d.id, members = {}, state = "countdown", forced = true, gig = gig }
    for _, id in ipairs(members) do lobby.members[#lobby.members + 1] = { id = id } end
    lobbies[lobby.id] = lobby
    local min = d.min
    d.min = 1
    local ok, err = pcall(launch, lobby)
    d.min = min
    lobbies[lobby.id] = nil
    if not ok then return false, tostring(err) end
    local launched = {}
    for _, id in ipairs(members) do if instanceOf[id] then launched[#launched + 1] = id end end
    if #launched == 0 then return false, "Nobody could be launched." end
    return true, launched, instances[instanceOf[launched[1]]]
end
-- The gig catalogue: the published points tagged for the fixers.
function Missions.fixerPoints()
    local list = {}
    for _, id in ipairs(order) do
        local p = points[id]
        if p and p.fixer and not p.retired then list[#list + 1] = p end
    end
    return list
end
function Missions.near(id, point, radius) return near(id, point, radius) end

for _, point in ipairs(C.points) do
    assert(type(point.id) == "string" and not points[point.id] and #point.difficulties > 0 and #point.start > 0, "Invalid mission point config")
    points[point.id] = point
    order[#order + 1] = point.id
    if C.enabled and not point.disabled then
        LightRP.interaction("mission." .. point.id, { position = point.position, radius = 2.0, bucket = 0,
            label = point.title, prompt = "Open the mission board", key = "E", marker = C.marker, ring = false,
            blip = { sprite = "objective", title = point.title, description = point.type .. " · " .. point.location } })
    end
end
