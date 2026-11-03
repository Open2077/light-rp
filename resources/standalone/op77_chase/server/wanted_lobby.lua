-- op77_chase Most Wanted lobby: a remote queue (players keep playing in the city) that
-- starts a match as soon as it is full, or after a countdown once the minimum is ready,
-- with whoever is there. Pure Lua; tests/wanted_test.lua drives it.
--
--   L.add(id, mode, now, squad) -> position, total | nil, "already_queued"
--   L.remove(id) / L.has(id) / L.position(id) / L.size() / L.reset()
--   L.expire(now, timeoutMs) -> ids removed
--   L.readiness(now, ready, dropAfterMs) -> readyEntries, notReady, dropped
--       ready(id) -> true | false, reason (Light RP activityCheck right now)
--   L.poll(now, ready, opts) -> start | nil, notReady, dropped
--       opts = { min, max, countdownMs, dropAfterMs, defaultMode, allowSolo, squadHoldMs }
--       start = { ids = {...}, modes, mode, squads = { [id] = squad } }; L.countdownEndsAtMs
--       is set while counting down
--   L.take(now, ready, n, dropAfterMs, squadHoldMs) -> ids, notReady, dropped, squads:
--       drop-ins for a running match (removed from the lobby)
--
-- Crews (Light RP squads, options.squad = { id, leader, members } on the join): an entry
-- keeps its squad; a crew is taken whole (it is split only when it is bigger than the match
-- itself, or when that is the only way to reach the minimum), and while some crewmate is not
-- queued or not ready yet the crew waits for him up to squadHoldMs after it queued.
ChaseWantedLobby = { entries = {}, countdownEndsAtMs = nil }
local L = ChaseWantedLobby

local function indexOf(id)
    for i, entry in ipairs(L.entries) do
        if entry.id == id then return i, entry end
    end
    return nil
end

function L.reset() L.entries = {}; L.countdownEndsAtMs = nil end
function L.size() return #L.entries end
function L.has(id) return indexOf(id) ~= nil end

-- A Light RP squad as the lobby keeps it: { id, leader, members = { ids } }, or nil (alone,
-- malformed, or a crew of one).
function L.squad(value)
    if type(value) ~= "table" or value.id == nil or type(value.members) ~= "table" then return nil end
    local members = {}
    for _, id in ipairs(value.members) do
        id = tonumber(id)
        if id and id > 0 and id % 1 == 0 then members[#members + 1] = math.tointeger(id) end
    end
    if #members < 2 then return nil end
    return { id = tostring(value.id), leader = tonumber(value.leader), members = members }
end

function L.add(id, mode, now, squad)
    if indexOf(id) then return nil, "already_queued" end
    L.entries[#L.entries + 1] = { id = id, mode = WantedRules.normalizeMode(mode), since = now, squad = L.squad(squad) }
    return #L.entries, #L.entries
end

-- Back at the head (the match could not start through no fault of theirs).
function L.requeueFront(ids, modes, now, squads)
    for i = #ids, 1, -1 do
        if not indexOf(ids[i]) then
            table.insert(L.entries, 1, { id = ids[i], mode = modes and modes[ids[i]] or nil, since = now,
                squad = squads and L.squad(squads[ids[i]]) or nil })
        end
    end
end

function L.remove(id)
    local i = indexOf(id)
    if not i then return false end
    table.remove(L.entries, i)
    return true
end

function L.position(id)
    local i, entry = indexOf(id)
    if not i then return nil end
    return i, #L.entries, entry
end

function L.expire(now, timeoutMs)
    local gone = {}
    for i = #L.entries, 1, -1 do
        if now - L.entries[i].since >= timeoutMs then
            gone[#gone + 1] = L.entries[i].id
            table.remove(L.entries, i)
        end
    end
    return gone
end

-- The mode most of them asked for; nobody asked = the default; a tie = the default.
function L.mode(entries, default)
    local votes = { vehicle = 0, foot = 0 }
    for _, entry in ipairs(entries) do
        if entry.mode then votes[entry.mode] = votes[entry.mode] + 1 end
    end
    if votes.foot > votes.vehicle then return "foot" end
    if votes.vehicle > votes.foot then return "vehicle" end
    return default or "vehicle"
end

function L.readiness(now, ready, dropAfterMs)
    local readyList, notReady, dropped = {}, {}, {}
    for i = #L.entries, 1, -1 do
        local entry = L.entries[i]
        local ok, why = ready(entry.id)
        if ok then
            entry.notReadySince = nil
            table.insert(readyList, 1, entry)
        else
            entry.notReadySince = entry.notReadySince or now
            if dropAfterMs and (now - entry.notReadySince) >= dropAfterMs then
                dropped[#dropped + 1] = { id = entry.id, reason = why }
                table.remove(L.entries, i)
            else
                notReady[#notReady + 1] = { id = entry.id, reason = why }
            end
        end
    end
    return readyList, notReady, dropped
end

local function takeEntries(list, n)
    local ids, modes, taken, squads = {}, {}, {}, {}
    for i = 1, math.min(n, #list) do
        ids[#ids + 1] = list[i].id
        modes[list[i].id] = list[i].mode
        squads[list[i].id] = list[i].squad
        taken[#taken + 1] = list[i]
    end
    for _, id in ipairs(ids) do L.remove(id) end
    return ids, modes, taken, squads
end

-- The ready entries in groups, in queue order: a crew's ready members together (at the
-- place of the first one), everyone else alone. A crew still missing a member (not queued
-- yet, or not ready) is held while its first member queued less than holdMs ago.
local function groups(readyList, now, holdMs)
    local out, byCrew, isReady = {}, {}, {}
    for _, entry in ipairs(readyList) do
        isReady[entry.id] = true
        local key = entry.squad and entry.squad.id
        local g = key and byCrew[key]
        if g then
            g.entries[#g.entries + 1] = entry
            g.since = math.min(g.since, entry.since)
        else
            g = { entries = { entry }, squad = entry.squad, since = entry.since }
            out[#out + 1] = g
            if key then byCrew[key] = g end
        end
    end
    -- Crewmates queued but not ready count for the hold too (their own entry may be older).
    for _, entry in ipairs(L.entries) do
        local g = entry.squad and byCrew[entry.squad.id]
        if g then g.since = math.min(g.since, entry.since) end
    end
    for _, g in ipairs(out) do
        if g.squad and (holdMs or 0) > 0 and now - g.since < holdMs then
            for _, id in ipairs(g.squad.members) do
                if not isReady[id] then g.held = true break end
            end
        end
    end
    return out
end
L.groups = groups

-- Whole groups in order while they fit in n; a crew bigger than n alone is split only when
-- nothing was picked yet (it would never fit), and crews are split when that is the only
-- way to reach `atLeast`.
local function pick(list, n, atLeast)
    local entries, skipped = {}, {}
    for _, g in ipairs(list) do
        if not g.held then
            if #entries + #g.entries <= n then
                for _, e in ipairs(g.entries) do entries[#entries + 1] = e end
            elseif #entries == 0 and #g.entries > n then
                for i = 1, n do entries[#entries + 1] = g.entries[i] end
            else
                skipped[#skipped + 1] = g
            end
        end
        if #entries >= n then break end
    end
    if atLeast and #entries < atLeast then
        for _, g in ipairs(skipped) do
            for _, e in ipairs(g.entries) do
                if #entries >= math.min(n, atLeast) then break end
                entries[#entries + 1] = e
            end
        end
    end
    return entries
end

local function available(list)
    local n = 0
    for _, g in ipairs(list) do if not g.held then n = n + #g.entries end end
    return n
end

function L.poll(now, ready, opts)
    local readyList, notReady, dropped = L.readiness(now, ready, opts.dropAfterMs)
    local floor = opts.allowSolo and 1 or 2
    local min, max = math.max(floor, opts.min or 3), math.max(2, opts.max or 8)
    local list = groups(readyList, now, opts.squadHoldMs)
    local count = available(list)
    if count >= max or (count >= min and L.countdownEndsAtMs ~= nil and now >= L.countdownEndsAtMs) then
        local chosen = pick(list, max, min)
        if #chosen >= min then
            local mode = L.mode(chosen, opts.defaultMode)
            local ids, modes, _, squads = takeEntries(chosen, max)
            L.countdownEndsAtMs = nil
            return { ids = ids, modes = modes, mode = mode, squads = squads }, notReady, dropped
        end
    end
    if count >= min then
        if L.countdownEndsAtMs == nil then
            L.countdownEndsAtMs = now + (opts.countdownMs or 45000)
            L.countdownStarted = true
        end
    else
        L.countdownEndsAtMs = nil
    end
    return nil, notReady, dropped
end

-- Ready players for a running match's free seats (head of the queue first).
-- A crew goes in whole or waits for a match with room for all of it.
function L.take(now, ready, n, dropAfterMs, holdMs)
    if n <= 0 or #L.entries == 0 then return {}, {}, {}, {} end
    local readyList, notReady, dropped = L.readiness(now, ready, dropAfterMs)
    local chosen = {}
    for _, g in ipairs(groups(readyList, now, holdMs)) do
        if not g.held and #chosen + #g.entries <= n then
            for _, e in ipairs(g.entries) do chosen[#chosen + 1] = e end
        end
        if #chosen >= n then break end
    end
    local ids, _, _, squads = takeEntries(chosen, n)
    if #L.entries == 0 then L.countdownEndsAtMs = nil end
    return ids, notReady, dropped, squads
end
