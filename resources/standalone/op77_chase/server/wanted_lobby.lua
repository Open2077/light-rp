-- op77_chase Most Wanted lobby: a remote queue (players keep playing in the city) that
-- starts a match as soon as it is full, or after a countdown once the minimum is ready,
-- with whoever is there. Pure Lua; tests/wanted_test.lua drives it.
--
--   L.add(id, mode, now) -> position, total | nil, "already_queued"
--   L.remove(id) / L.has(id) / L.position(id) / L.size() / L.reset()
--   L.expire(now, timeoutMs) -> ids removed
--   L.readiness(now, ready, dropAfterMs) -> readyEntries, notReady, dropped
--       ready(id) -> true | false, reason (Light RP activityCheck right now)
--   L.poll(now, ready, opts) -> start | nil, notReady, dropped
--       opts = { min, max, countdownMs, dropAfterMs, defaultMode }
--       start = { ids = {...}, mode }; L.countdownEndsAtMs is set while counting down
--   L.take(now, ready, n, dropAfterMs) -> ids (removed): drop-ins for a running match
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

function L.add(id, mode, now)
    if indexOf(id) then return nil, "already_queued" end
    L.entries[#L.entries + 1] = { id = id, mode = WantedRules.normalizeMode(mode), since = now }
    return #L.entries, #L.entries
end

-- Back at the head (the match could not start through no fault of theirs).
function L.requeueFront(ids, modes, now)
    for i = #ids, 1, -1 do
        if not indexOf(ids[i]) then
            table.insert(L.entries, 1, { id = ids[i], mode = modes and modes[ids[i]] or nil, since = now })
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
    local ids, modes, taken = {}, {}, {}
    for i = 1, math.min(n, #list) do
        ids[#ids + 1] = list[i].id
        modes[list[i].id] = list[i].mode
        taken[#taken + 1] = list[i]
    end
    for _, id in ipairs(ids) do L.remove(id) end
    return ids, modes, taken
end

function L.poll(now, ready, opts)
    local readyList, notReady, dropped = L.readiness(now, ready, opts.dropAfterMs)
    local min, max = math.max(2, opts.min or 3), math.max(2, opts.max or 8)
    if #readyList >= max or (#readyList >= min and L.countdownEndsAtMs ~= nil and now >= L.countdownEndsAtMs) then
        local mode = L.mode(readyList, opts.defaultMode)
        local ids, modes = takeEntries(readyList, max)
        L.countdownEndsAtMs = nil
        return { ids = ids, modes = modes, mode = mode }, notReady, dropped
    end
    if #readyList >= min then
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
function L.take(now, ready, n, dropAfterMs)
    if n <= 0 or #L.entries == 0 then return {}, {}, {} end
    local readyList, notReady, dropped = L.readiness(now, ready, dropAfterMs)
    local ids = takeEntries(readyList, n)
    if #L.entries == 0 then L.countdownEndsAtMs = nil end
    return ids, notReady, dropped
end
