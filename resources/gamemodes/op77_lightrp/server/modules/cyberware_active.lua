-- Active implants: what the fitted cyberware does beyond passive stats and platform grants
-- (server/config/cyberware.lua, kinds berserk, pain, second_heart, optics). Fitting, storage
-- and capacity stay in server/modules/cyberware.lua; this module only reads what is fitted
-- (LightRP.cyberware.fitted, nil while the implants are suspended in PvP).
--
--   Berserk (X)    a timed layer: armor + bonus now (Open77.players.setArmor), health regeneration
--                  + regen (LightRP.cyberware.boost -> Open77.stats.setRegenRate). At the end, the
--                  armor goes back to at most what it was: the layer is absorbed first and never
--                  stays. Cooldown from the end. Ends early on death, suspension, removal,
--                  disconnect, resource stop.
--   Pain Editor    a hit that leaves the body under `threshold` of its maximum (open77:playerDamaged,
--                  not lethal) starts a regeneration layer for a few seconds, once per cooldown.
--   Second Heart   a character downed in the city (medical: native dead + a saved "downed"
--                  record) gets back up by himself after `delayMs` (Open77.players.revive; the
--                  medical module settles the record). Once per `cooldownMs` per character (kept in
--                  memory across reconnects, not across a server restart). Never in Dogtown
--                  (LightRP.dogtown, when that module runs), never in an activity (PvE included,
--                  owner decision 2026-11-03), never in a mission (those own their deaths anyway).
--   Kiroshi optics ALT + click (client/core/cyberware.lua, open77_contextmenu): "cyberware.scan"
--                  answers with a notice (name, crew, Dogtown bounty when LightRP.dogtown.bounty
--                  exists); "cyberware.mark" (Clairvoyant) marks a player or an NPC this resource
--                  owns for the marker's crew: an op77_map3d blip and an arrow above the target,
--                  following it every `markUpdateMs`, gone after `durationMs`, on the target's or
--                  the marker's death or disconnect, and on resource stop.
--
-- Client contract (net event "op77_lightrp:cyberware"):
--   { kind = "kit", scan, mark, berserk }   what the context menu and the X key may offer
--   { kind = "mark", id, x, y, z, label, remainingMs, player? }   create / move the arrow
--   { kind = "unmark", id }
local C = LightRpCyberwareConfig
local OPTICS = type(C.optics) == "table" and C.optics or {}
local NET = "op77_lightrp:cyberware"
local Active = LightRP.module("cyberware_active", {})

local function log(fmt, ...) LightRP.log("cyberware: " .. fmt, ...) end
local function now() return LightRP.nowMs() end
local function notice(playerId, kind, title, body, durationMs)
    LightRP.notice(playerId, { kind = kind, title = title, body = body, source = "CYBERWARE", durationMs = durationMs })
end
local function Cyber() return LightRP.cyberware end
local function fitted(playerId, kind)
    local M = Cyber()
    return M and type(M.fitted) == "function" and M.fitted(playerId, kind) or nil
end
local function boost(playerId, name, rate)
    local M = Cyber()
    if M and type(M.boost) == "function" then M.boost(playerId, name, rate) end
end
local function life(playerId)
    local state = Open77.players.getLifeState and Open77.players.getLifeState(playerId)
    return type(state) == "table" and state.phase or nil, state
end
local function seconds(ms) return math.max(1, math.ceil(ms / 1000)) end
local function number(v) return string.format("%g", v) end

local tokens = 0
local function token() tokens = tokens + 1 return tokens end
local cooldowns = {} -- playerId -> { berserk, pain, scan, mark } (ms)
local function cd(playerId)
    local c = cooldowns[playerId]
    if not c then c = {}; cooldowns[playerId] = c end
    return c
end

-- ---------------------------------------------------------------------------
-- The client's kit

local function kitOf(playerId)
    local optics, berserk = fitted(playerId, "optics"), fitted(playerId, "berserk")
    return { kind = "kit", scan = optics ~= nil and optics.scan == true, mark = optics ~= nil and type(optics.mark) == "table",
        berserk = berserk ~= nil }
end
function Active.pushKit(playerId) TriggerClientEvent(NET, playerId, kitOf(playerId)) end

-- ---------------------------------------------------------------------------
-- Berserk

local running = {} -- playerId -> { token, armorBefore, item, untilMs }

local function readArmor(playerId)
    if type(Open77.stats) ~= "table" or type(Open77.stats.get) ~= "function" then return nil end
    local ok, stats = pcall(Open77.stats.get, playerId)
    return ok and type(stats) == "table" and tonumber(stats.armor) or nil
end

-- why: expired | death | suspended | removed | disconnect | character | stop
local function endBerserk(playerId, why)
    local b = running[playerId]
    if not b then return end
    running[playerId] = nil
    boost(playerId, "berserk", nil)
    -- The natural end (and a resource stop): what is left of the layer goes. Every other end
    -- comes with the passives applied again (respawn, clinic, suspension) or no body at all.
    if why == "expired" or why == "stop" then
        local armor = readArmor(playerId)
        if armor and armor > b.armorBefore then pcall(Open77.players.setArmor, playerId, b.armorBefore) end
    end
    if why == "expired" then
        local ready = cd(playerId).berserk or now()
        notice(playerId, "info", "BERSERK", string.format("Berserk is over. Ready again in %d s.", seconds(ready - now())), 4000)
    end
    log("berserk of %d ended (%s)", playerId, tostring(why))
end

function Active.startBerserk(playerId)
    local item = fitted(playerId, "berserk")
    local cfg = item and type(item.berserk) == "table" and item.berserk
    if not cfg then return false, "No Berserk fitted. A ripperdoc can fit one in the operating system." end
    if life(playerId) ~= "alive" then return false end
    if running[playerId] then return false, "Berserk is already running." end
    local c = cd(playerId)
    if now() < (c.berserk or 0) then return false, string.format("Berserk is recharging: %d s.", seconds(c.berserk - now())) end
    local before = readArmor(playerId) or 0
    local bonus, duration = tonumber(cfg.armor) or 0, tonumber(cfg.durationMs) or 8000
    local ok, why = Open77.players.setArmor(playerId, before + bonus)
    if ok == false then
        log("berserk of %d refused by setArmor: %s", playerId, tostring(why))
        return false, "Berserk did not kick in. Try again."
    end
    local b = { token = token(), armorBefore = before, item = item.id, untilMs = now() + duration }
    running[playerId] = b
    -- the cooldown runs from the end of the effect
    c.berserk = b.untilMs + (tonumber(cfg.cooldownMs) or 30000)
    boost(playerId, "berserk", tonumber(cfg.regen) or 0)
    notice(playerId, "success", "BERSERK", string.format("+%d armor and +%s health / s for %d s.", bonus, number(tonumber(cfg.regen) or 0),
        seconds(duration)), duration)
    log("berserk of %d started (%s): armor %s -> %s", playerId, item.id, number(before), number(before + bonus))
    CreateThread(function()
        Wait(duration)
        if running[playerId] == b then endBerserk(playerId, "expired") end
    end)
    return true
end

LightRP.action("cyberware.berserk", function(playerId)
    local ok, why = Active.startBerserk(playerId)
    if not ok and why then notice(playerId, "warning", "BERSERK", why, 3500) end
end)

-- ---------------------------------------------------------------------------
-- Pain Editor

local pains = {} -- playerId -> token of the running layer

local function endPain(playerId)
    if not pains[playerId] then return end
    pains[playerId] = nil
    boost(playerId, "pain", nil)
end

AddEventHandler("open77:playerDamaged", function(victim, _, _, _, _, _, remaining, maximum, lethal)
    local playerId = tonumber(victim)
    if not playerId or lethal == true or lethal == "true" then return end
    local item = fitted(playerId, "pain")
    local cfg = item and type(item.pain) == "table" and item.pain
    if not cfg then return end
    local rest, max = tonumber(remaining), tonumber(maximum)
    if not rest or not max or max <= 0 or rest <= 0 or rest / max >= (tonumber(cfg.threshold) or 0.3) then return end
    if life(playerId) ~= "alive" then return end
    local c = cd(playerId)
    if now() < (c.pain or 0) then return end
    local duration = tonumber(cfg.durationMs) or 6000
    c.pain = now() + (tonumber(cfg.cooldownMs) or 60000)
    local t = token()
    pains[playerId] = t
    boost(playerId, "pain", tonumber(cfg.regen) or 0)
    notice(playerId, "info", "PAIN EDITOR", string.format("Pain filed for later: +%s health / s for %d s.", number(tonumber(cfg.regen) or 0),
        seconds(duration)), duration)
    log("pain editor of %d triggered at %s/%s", playerId, number(rest), number(max))
    CreateThread(function()
        Wait(duration)
        if pains[playerId] == t then endPain(playerId) end
    end)
end)

-- ---------------------------------------------------------------------------
-- Second Heart

local hearts = {}  -- "identifier:key" -> ms when the next one is allowed
local pendingHeart = {} -- playerId -> token

local function heartKey(playerId)
    local M = Cyber()
    local identifier, key = M and type(M.owner) == "function" and M.owner(playerId)
    return identifier and (tostring(identifier) .. ":" .. tostring(key)) or nil
end

-- nil, or why the Second Heart stays quiet: dogtown | activity | mission
function Active.secondHeartBlocked(playerId, state)
    local D = LightRP.dogtown
    if type(D) == "table" then
        -- inside the Dogtown polygon (this death's position), or still in its fight (inside, or
        -- tagged after leaving it: server/modules/dogtown.lua inZone)
        local pos = type(state) == "table" and state.position or nil
        if type(D.contains) == "function" and type(pos) == "table" then
            local ok, inside = pcall(D.contains, pos)
            if ok and inside then return "dogtown" end
        end
        local inZone = type(D.inZone) == "function" and D.inZone or D.qualifies
        if type(inZone) == "function" then
            local ok, inside = pcall(inZone, playerId)
            if ok and inside then return "dogtown" end
        end
    end
    local A = LightRP.activities
    if type(A) == "table" and type(A.owns) == "function" and A.owns(playerId) then
        -- owner decision 2026-11-03: never inside an activity, PvE included -- every activity
        -- handles its own deaths (respawn, elimination, bust)
        return "activity"
    end
    local M = LightRP.missions
    if type(M) == "table" and type(M.handlesDeath) == "function" and M.handlesDeath(playerId) then return "mission" end
    return nil
end

function Active.secondHeartReadyIn(playerId)
    local key = heartKey(playerId)
    return key and math.max(0, (hearts[key] or 0) - now()) or nil
end

local function trySecondHeart(playerId)
    local item = fitted(playerId, "second_heart")
    if not item then return end
    local cfg = type(item.secondHeart) == "table" and item.secondHeart or {}
    local key = heartKey(playerId)
    if not key or now() < (hearts[key] or 0) then return end
    local t = token()
    pendingHeart[playerId] = t
    CreateThread(function()
        Wait(tonumber(cfg.delayMs) or 5000)
        local medical = LightRP.medical
        -- up to 20 s for the medical module to save the downed state
        for _ = 1, 40 do
            if pendingHeart[playerId] ~= t then return end
            local phase, state = life(playerId)
            if phase ~= "dead" then pendingHeart[playerId] = nil return end
            local view = medical and type(medical.view) == "function" and medical.view(playerId) or nil
            local status = type(view) == "table" and view.phase or nil
            if status == "downed" and not view.receiving and not (medical.restoring and medical.restoring[playerId]) then
                pendingHeart[playerId] = nil
                local blocked = Active.secondHeartBlocked(playerId, state)
                if blocked then
                    log("second heart of %d stays quiet (%s)", playerId, blocked)
                    if blocked == "dogtown" then notice(playerId, "warning", "SECOND HEART", "Your Second Heart stays quiet in Dogtown.", 5000) end
                    return
                end
                if not fitted(playerId, "second_heart") or now() < (hearts[key] or 0) then return end
                local ok, why = Open77.players.revive(playerId, { health = tonumber(cfg.health) or 0.4, graceMs = tonumber(cfg.graceMs) or 4000 })
                if ok then
                    local cooldown = tonumber(cfg.cooldownMs) or 3600000
                    hearts[key] = now() + cooldown
                    notice(playerId, "success", "SECOND HEART", string.format("Your Second Heart kicked in: back on your feet. It needs %d min to recharge.",
                        math.max(1, math.floor(cooldown / 60000 + 0.5))), 7000)
                    log("second heart of %d (%s) revived them", playerId, key)
                else
                    log("second heart revive of %d refused: %s", playerId, tostring(why))
                end
                return
            end
            -- not a city downed state (a mission, an activity, a hospital trip, a medic at work)
            if status ~= "saving" and status ~= "downed" then pendingHeart[playerId] = nil return end
            Wait(500)
        end
        pendingHeart[playerId] = nil
    end)
end

-- ---------------------------------------------------------------------------
-- Kiroshi optics: positions, targets

local function positionOf(playerId)
    if type(Open77.players.get) ~= "function" then return nil end
    local ok, r = pcall(Open77.players.get, playerId)
    if not ok or type(r) ~= "table" or type(r.position) ~= "table" or not tonumber(r.position.x) then return nil end
    return { x = r.position.x, y = r.position.y, z = tonumber(r.position.z) or 0, bucket = r.bucket }
end

-- Only NPCs this resource owns answer (no npcs.foreign permission): bosses, mission targets,
-- desks. Ambient NPCs have no server id at all.
local function npcOf(npcId)
    if type(Open77.npcs) ~= "table" or type(Open77.npcs.get) ~= "function" then return nil end
    local ok, npc = pcall(Open77.npcs.get, npcId)
    if not ok or type(npc) ~= "table" or not tonumber(npc.x) then return nil end
    return { x = npc.x, y = npc.y, z = tonumber(npc.z) or 0, bucket = npc.bucket, health = tonumber(npc.health), maxHealth = tonumber(npc.maxHealth) }
end

local function locate(target)
    if not target.id then return nil end
    if target.kind == "player" then return positionOf(target.id) end
    return npcOf(target.id)
end

local function distance(a, b)
    local x, y, z = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(x * x + y * y + z * z)
end

local function within(a, b, range)
    if not a or not b then return false end
    if a.bucket ~= nil and b.bucket ~= nil and a.bucket ~= b.bucket then return false end
    return distance(a, b) <= range
end

-- { kind = "player", id } | { kind = "npc", id|nil } from the page's target, nil when malformed
local function targetOf(p)
    local t = type(p) == "table" and p.target or nil
    if type(t) ~= "table" then return nil end
    if t.kind == "player" then
        local id = math.tointeger(tonumber(t.playerId))
        if id and id > 0 then return { kind = "player", id = id } end
        return nil
    end
    if t.kind == "npc" then
        local id = math.tointeger(tonumber(t.npcId))
        return { kind = "npc", id = id and id > 0 and id or nil }
    end
    return nil
end

local function crewOf(playerId)
    local P = LightRP.parties
    local list = P and type(P.members) == "function" and P.members(playerId) or nil
    return type(list) == "table" and #list > 0 and list or { playerId }
end

local function nameOf(playerId)
    local Ch = LightRP.characters
    return Ch and type(Ch.displayName) == "function" and Ch.displayName(playerId) or ("Player " .. tostring(playerId))
end

-- The Dogtown bounty, through the Dogtown module when it has one (lightrp/dogtown-rules):
-- LightRP.dogtown.bounty(playerId) -> number (eddies) | { amount, label } | nil. Absent: no line.
-- The Dogtown bounty on a player (server/modules/dogtown.lua): what killing them there pays now,
-- and their kill streak. nil without the Dogtown module.
function Active.bountyLine(playerId)
    local D = LightRP.dogtown
    if type(D) ~= "table" or type(D.bountyReward) ~= "function" then return nil end
    local ok, reward = pcall(D.bountyReward, playerId)
    if not ok then return nil end
    reward = math.floor(tonumber(reward) or 0)
    local marked = false
    if type(D.bounties) == "function" then
        local okList, list = pcall(D.bounties)
        marked = okList and type(list) == "table" and list[playerId] ~= nil
    end
    if reward <= 0 and not marked then return "Dogtown bounty: none" end
    local streak = 0
    if type(D.streak) == "function" then
        local okStreak, n = pcall(D.streak, playerId)
        streak = okStreak and math.floor(tonumber(n) or 0) or 0
    end
    return string.format("Dogtown bounty: %s%s", LightRP.money.format(math.max(0, reward)),
        streak > 0 and string.format(" (%d-kill streak)", streak) or "")
end

local function crewLine(playerId)
    local P = LightRP.parties
    local crew = P and type(P.of) == "function" and P.of(playerId) or nil
    if type(crew) ~= "table" or type(crew.members) ~= "table" or #crew.members < 2 then return "Crew: none" end
    return string.format("Crew: %s's crew (%d)", nameOf(crew.leader), #crew.members)
end

function Active.describe(target, where)
    if target.kind == "player" then
        local lines = { "Name: " .. nameOf(target.id), crewLine(target.id) }
        local bounty = Active.bountyLine(target.id)
        if bounty then lines[#lines + 1] = bounty end
        return table.concat(lines, " · ")
    end
    if not target.id then return "Civilian. No record on file." end
    local health = where and where.health and where.maxHealth and where.maxHealth > 0
        and string.format(" · Health %d%%", math.floor(where.health / where.maxHealth * 100 + 0.5)) or ""
    return "No ID on file. Crew: none" .. health
end

LightRP.action("cyberware.scan", function(playerId, p)
    local item = fitted(playerId, "optics")
    if not item or item.scan ~= true then
        return notice(playerId, "warning", "KIROSHI", "No Kiroshi optics fitted. A ripperdoc can fit them.", 4000)
    end
    if life(playerId) ~= "alive" then return end
    local target = targetOf(p)
    if not target or (target.kind == "player" and target.id == playerId) then return end
    local c = cd(playerId)
    if now() < (c.scan or 0) then return end
    c.scan = now() + (tonumber(OPTICS.scanCooldownMs) or 2000)
    local where
    if target.id then
        where = locate(target)
        if not within(positionOf(playerId), where, tonumber(OPTICS.scanRange) or 25) then
            return notice(playerId, "warning", "KIROSHI SCAN", "Target out of range.", 3000)
        end
    end
    notice(playerId, "info", "KIROSHI SCAN", Active.describe(target, where), 9000)
end)

-- ---------------------------------------------------------------------------
-- Kiroshi Clairvoyant: marks

local marks, markSeq, ticking = {}, 0, false -- id -> { id, owner, target, recipients, untilMs, label, blip }

local function sendMark(m, payload)
    for _, r in ipairs(m.recipients) do TriggerClientEvent(NET, r, payload) end
end

local function map3d(method, ...)
    local args = table.pack(...)
    local ok, a, b = pcall(function() return exports.op77_map3d[method](exports.op77_map3d, table.unpack(args, 1, args.n)) end)
    if not ok then return nil, a end
    return a, b
end

local function clearMark(id, why)
    local m = marks[id]
    if not m then return end
    marks[id] = nil
    if m.blip then map3d("removeBlip", m.blip) end
    sendMark(m, { kind = "unmark", id = id })
    log("mark %s on %s %s by %d ended (%s)", id, m.target.kind, tostring(m.target.id), m.owner, tostring(why))
end

-- Marks a player is part of: as the marker, as the target, or (recipients) dropped from them.
local function clearMarksOf(playerId, why)
    for id, m in pairs(marks) do
        if m.owner == playerId or (m.target.kind == "player" and m.target.id == playerId) then clearMark(id, why) end
    end
end

local function payloadOf(m, where)
    return { kind = "mark", id = m.id, x = where.x, y = where.y, z = where.z, label = m.label,
        remainingMs = math.max(0, m.untilMs - now()), player = m.target.kind == "player" and m.target.id or nil }
end

local function tick()
    for id, m in pairs(marks) do
        if now() >= m.untilMs then
            clearMark(id, "expired")
        else
            local where = locate(m.target)
            local gone = where == nil
            if m.target.kind == "player" then
                local phase = life(m.target.id)
                gone = gone or (phase ~= "alive" and phase ~= "recovering")
            elseif where and where.health and where.health <= 0 then
                gone = true
            end
            if gone then
                clearMark(id, "target gone")
            else
                if m.blip then map3d("updateBlip", m.blip, { x = where.x, y = where.y, z = where.z }) end
                sendMark(m, payloadOf(m, where))
            end
        end
    end
end

local function startTicking()
    if ticking then return end
    ticking = true
    CreateThread(function()
        while next(marks) ~= nil do
            Wait(tonumber(OPTICS.markUpdateMs) or 500)
            tick()
        end
        ticking = false
    end)
end

function Active.marks() return marks end

LightRP.action("cyberware.mark", function(playerId, p)
    local item = fitted(playerId, "optics")
    local cfg = item and type(item.mark) == "table" and item.mark
    if not cfg then return notice(playerId, "warning", "CLAIRVOYANT", "Mark for crew needs Kiroshi Clairvoyant optics.", 4000) end
    if life(playerId) ~= "alive" then return end
    local target = targetOf(p)
    if not target then return end
    if not target.id then
        return notice(playerId, "warning", "CLAIRVOYANT", "Nothing to lock onto: the Clairvoyant marks players and the city's own NPCs (bosses, mission targets).", 5000)
    end
    local crew = crewOf(playerId)
    if target.kind == "player" then
        if target.id == playerId then return end
        for _, member in ipairs(crew) do
            if member == target.id then return notice(playerId, "warning", "CLAIRVOYANT", "That is your crew.", 3000) end
        end
    end
    local c = cd(playerId)
    if now() < (c.mark or 0) then
        return notice(playerId, "warning", "CLAIRVOYANT", string.format("Recharging: %d s.", seconds(c.mark - now())), 3000)
    end
    local me, there = positionOf(playerId), locate(target)
    if not within(me, there, tonumber(OPTICS.markRange) or 25) then
        return notice(playerId, "warning", "CLAIRVOYANT", "Target out of range.", 3000)
    end
    c.mark = now() + (tonumber(cfg.cooldownMs) or 30000)
    -- one live mark per marker: a new one replaces it
    for id, m in pairs(marks) do if m.owner == playerId then clearMark(id, "replaced") end end
    local recipients = {}
    for _, member in ipairs(crew) do
        local pos = member == playerId and me or positionOf(member)
        if pos and (pos.bucket == nil or there.bucket == nil or pos.bucket == there.bucket) then recipients[#recipients + 1] = member end
    end
    markSeq = markSeq + 1
    local duration = tonumber(cfg.durationMs) or 10000
    local m = { id = "m" .. markSeq, owner = playerId, target = target, recipients = recipients, untilMs = now() + duration,
        label = target.kind == "player" and nameOf(target.id) or "Target" }
    marks[m.id] = m
    local blip, why = map3d("addBlip", recipients, { id = "cw_mark_" .. m.id, position = { x = there.x, y = there.y, z = there.z },
        icon = "target", color = OPTICS.markColor or "#FF3B3B", label = "MARKED · " .. m.label,
        description = "Kiroshi Clairvoyant · " .. nameOf(playerId), pulse = true, edge = true, routable = false,
        category = "cyberware", priority = 2, scale = 1.2 })
    if blip then m.blip = blip else log("mark %s: map blip refused: %s", m.id, tostring(why)) end
    sendMark(m, payloadOf(m, there))
    local owner = nameOf(playerId)
    for _, member in ipairs(recipients) do
        if member == playerId then
            notice(member, "success", "CLAIRVOYANT", string.format("%s marked for your crew (%d s).", m.label, seconds(duration)), 4000)
        else
            notice(member, "info", "CLAIRVOYANT", string.format("%s marked %s (%d s).", owner, m.label, seconds(duration)), 4000)
        end
    end
    log("mark %s: %d marked %s %s for %d crew member(s)", m.id, playerId, target.kind, tostring(target.id), #recipients)
    startTicking()
end)

-- ---------------------------------------------------------------------------
-- Lifecycle

local function endAll(playerId, why)
    endBerserk(playerId, why)
    endPain(playerId)
    pendingHeart[playerId] = nil
end

function Active.onCyberwareChanged(playerId)
    if running[playerId] and not fitted(playerId, "berserk") then endBerserk(playerId, "removed") end
    if pains[playerId] and not fitted(playerId, "pain") then endPain(playerId) end
    Active.pushKit(playerId)
end

function Active.onLifeState(playerId, phase)
    if phase == "alive" then return end
    endBerserk(playerId, "death")
    endPain(playerId)
    clearMarksOf(playerId, "death")
    if phase == "dead" and not pendingHeart[playerId] then trySecondHeart(playerId) end
end

function Active.onCharacterLoaded(playerId) endAll(playerId, "character"); clearMarksOf(playerId, "character") end
Active.onCharacterSwitched = Active.onCharacterLoaded
function Active.onGameplayReady(playerId) Active.pushKit(playerId) end
Active.onUiReady = Active.onGameplayReady

function Active.onDisconnected(playerId)
    endAll(playerId, "disconnect")
    clearMarksOf(playerId, "disconnect")
    for _, m in pairs(marks) do
        for i = #m.recipients, 1, -1 do if m.recipients[i] == playerId then table.remove(m.recipients, i) end end
    end
    cooldowns[playerId] = nil
end

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    for playerId in pairs(running) do endBerserk(playerId, "stop") end
    for id in pairs(marks) do clearMark(id, "stop") end
end)
