-- op77_chase queue: a remote queue (the player keeps playing in the city while he waits)
-- with mode preferences. Pure Lua; tests/match_test.lua drives it.
--
--   Q.add(id, mode, now, squad)  -> position, total | nil, "already_queued"
--   Q.remove(id)                 -> true when the player was queued
--   Q.position(id)               -> position, total | nil
--   Q.expire(now, timeoutMs)     -> ids whose entry expired (removed)
--   Q.pair(now, ready, opts)     -> { a, b, mode } | nil, notReady, dropped
--       ready(id) -> true | false, reason: eligibility right now (Light RP activityCheck).
--       Entries that are not ready are skipped, not removed, until they have been failing
--       for opts.dropAfterMs; `notReady` lists { id, reason } to tell the player.
--       Crews (Light RP squads, options.squad = { id, leader, members }): two members of
--       one squad are paired together first; a squad member is not paired with a stranger
--       for opts.squadHoldMs while another member of his squad has not queued yet.
ChaseQueue = { entries = {} }
local Q = ChaseQueue

local function indexOf(id)
    for i, entry in ipairs(Q.entries) do
        if entry.id == id then return i, entry end
    end
    return nil
end

function Q.normalizeMode(mode)
    if mode == nil then return nil end
    mode = tostring(mode):lower()
    if mode == "foot" or mode == "onfoot" or mode == "on_foot" then return "foot" end
    if mode == "vehicle" or mode == "car" or mode == "cars" or mode == "drive" then return "vehicle" end
    return nil
end

function Q.reset() Q.entries = {} end
function Q.size() return #Q.entries end
function Q.has(id) return indexOf(id) ~= nil end

-- A squad as handed over by Light RP, or nil (a squad of one is no crew).
function Q.squad(value)
    if type(value) ~= "table" or value.id == nil or type(value.members) ~= "table" then return nil end
    local members = {}
    for _, m in ipairs(value.members) do
        local id = tonumber(type(m) == "table" and m.id or m)
        if id then members[#members + 1] = math.tointeger(id) or id end
    end
    if #members < 2 then return nil end
    return { id = tostring(value.id), leader = tonumber(value.leader), members = members }
end

function Q.add(id, mode, now, squad)
    if indexOf(id) then return nil, "already_queued" end
    Q.entries[#Q.entries + 1] = { id = id, mode = Q.normalizeMode(mode), since = now, squad = Q.squad(squad) }
    return #Q.entries, #Q.entries
end

-- Put a player back at the head (his opponent failed to enter at the last moment).
function Q.requeueFront(id, mode, now, squad)
    if indexOf(id) then return end
    table.insert(Q.entries, 1, { id = id, mode = Q.normalizeMode(mode), since = now, squad = Q.squad(squad) })
end

-- Held back from strangers: a crew member whose crewmates have not all queued yet.
function Q.held(entry, now, holdMs)
    local squad = entry.squad
    if squad == nil or not holdMs or holdMs <= 0 or (now - entry.since) >= holdMs then return false end
    for _, member in ipairs(squad.members) do
        if member ~= entry.id and not indexOf(member) then return true end
    end
    return false
end

function Q.remove(id)
    local i = indexOf(id)
    if not i then return false end
    table.remove(Q.entries, i)
    return true
end

function Q.position(id)
    local i, entry = indexOf(id)
    if not i then return nil end
    return i, #Q.entries, entry
end

function Q.expire(now, timeoutMs)
    local gone = {}
    for i = #Q.entries, 1, -1 do
        if now - Q.entries[i].since >= timeoutMs then
            gone[#gone + 1] = Q.entries[i].id
            table.remove(Q.entries, i)
        end
    end
    return gone
end

local function compatible(a, b) return a == nil or b == nil or a == b end

function Q.pair(now, ready, opts)
    opts = opts or {}
    local notReady, dropped = {}, {}
    if #Q.entries < 2 then return nil, notReady, dropped end
    local readyList = {}
    for i = #Q.entries, 1, -1 do
        local entry = Q.entries[i]
        local ok, why = ready(entry.id)
        if ok then
            entry.notReadySince = nil
            table.insert(readyList, 1, entry)
        else
            entry.notReadySince = entry.notReadySince or now
            if opts.dropAfterMs and (now - entry.notReadySince) >= opts.dropAfterMs then
                dropped[#dropped + 1] = { id = entry.id, reason = why }
                table.remove(Q.entries, i)
            else
                notReady[#notReady + 1] = { id = entry.id, reason = why }
            end
        end
    end
    local function take(a, b)
        Q.remove(a.id); Q.remove(b.id)
        return { a = a.id, b = b.id, mode = a.mode or b.mode or opts.defaultMode or "vehicle",
            modes = { [a.id] = a.mode, [b.id] = b.mode }, squads = { [a.id] = a.squad, [b.id] = b.squad },
            squad = (a.squad and b.squad and a.squad.id == b.squad.id) and a.squad.id or nil },
            notReady, dropped
    end
    -- A crew of two faces each other (whatever modes they picked: the first one's).
    for i = 1, #readyList - 1 do
        for j = i + 1, #readyList do
            local a, b = readyList[i], readyList[j]
            if a.squad and b.squad and a.squad.id == b.squad.id then return take(a, b) end
        end
    end
    for i = 1, #readyList - 1 do
        for j = i + 1, #readyList do
            local a, b = readyList[i], readyList[j]
            local crew = a.squad and b.squad and a.squad.id == b.squad.id
            if compatible(a.mode, b.mode) and not crew and not Q.held(a, now, opts.squadHoldMs) and not Q.held(b, now, opts.squadHoldMs) then
                return take(a, b)
            end
        end
    end
    return nil, notReady, dropped
end
