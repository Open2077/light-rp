local lightrpEvery = LightRP.every or function(ms, fn) while true do Wait(tonumber(ms) or 1000); fn() end end -- framework.lua (tests: the plain loop, in the calling thread)
-- The queue panel: one queue state per player (page state key `queue`), whatever they
-- wait for. Fed by:
--   * the core's joins (activities.lua `pending`): a ranked search the core holds (its
--     searchers / the players a match needs), a core match on its way, a provider join;
--   * the providers' own queues, through the status event's optional `queue` shape (v1,
--     activities.lua header): who waits in which lobby, what it needs, when it starts.
--     A player in a provider's lobby without a core join (queued by the provider's own
--     command) shows too. A provider without the shape falls back on its activity's
--     minPlayers / maxPlayers and the status' `queued`;
--   * the mission boards (missions.lua): a tagged crew waiting for its launch.
-- One view per player, pushed when it changes only (never every second: the page
-- counts the wait and the start on its own). Nothing while the player is in play.
--
-- The view (about a dozen values):
--   false | { v = 1, id, label, mode, count, need, max, sinceMs, startsInMs,
--             state = "waiting"|"starting"|"joining", crew, source = "core"|"provider"|"mission" }
-- `crew`: queued by the crew leader (leaving takes only them out).
--
-- Leaving (action `queue.leave`: the page's cancel key, F1 > Leave queue): whatever queue
-- the view shows; never a running activity.
local A = LightRP.activities
local Q = LightRP.module("activityQueue", {})

local VERSION = 1
local MAX_LOBBIES, MAX_LOBBY_PLAYERS, MAX_PLAYERS = 32, 64, 256
local START_SLACK_MS = 1500 -- a provider's countdown re-sent a moment later is the same start

local rosters = {} -- activityId -> { at, lobbies = { lobby }, of = { [playerId] = lobby } }
local seen = {}    -- playerId -> { key, at }: when the queue they are in now was first seen
local sent = {}    -- playerId -> { sig, startsAt }: what their panel shows
Q.rosters = rosters

local function now() return LightRP.nowMs() end
local function pid(value)
    local n = tonumber(value)
    if not n or n <= 0 or n % 1 ~= 0 or n > 2147483647 then return nil end
    return math.tointeger(n)
end
local function int(value, lo, hi)
    local n = tonumber(value)
    if not n or n ~= n then return nil end
    n = math.floor(n)
    if n < lo or n > hi then return nil end
    return n
end
local function text(value, max)
    if type(value) ~= "string" then return nil end
    value = value:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then return nil end
    if #value > max then value = value:sub(1, max) end
    return value
end
local function missions() return LightRP.missions end

-- ---------------------------------------------------------------------------
-- A provider's queue (status.queue, v1)

-- The roster of one status: lobbies with their players, a player in one lobby only.
-- Anything malformed is dropped; an unknown version is no roster at all.
function Q.parse(raw, t)
    if type(raw) ~= "table" or raw.v ~= VERSION or type(raw.lobbies) ~= "table" then return nil end
    local lobbies, of, total = {}, {}, 0
    for i, l in ipairs(raw.lobbies) do
        if i > MAX_LOBBIES then break end
        if type(l) == "table" and type(l.players) == "table" then
            local lobby = { players = {}, need = int(l.need, 1, 1000), max = int(l.max, 1, 1000),
                mode = text(l.mode, 32), joining = l.joining == true or nil }
            for _, p in ipairs(l.players) do
                local id = pid(p)
                if id and not of[id] and #lobby.players < MAX_LOBBY_PLAYERS and total < MAX_PLAYERS then
                    lobby.players[#lobby.players + 1] = id
                    of[id] = lobby
                    total = total + 1
                end
            end
            lobby.count = math.max(#lobby.players, int(l.count, 0, 10000) or 0)
            if lobby.need and lobby.max and lobby.max <= lobby.need then lobby.max = nil end
            local ms = int(l.startsInMs, 0, 3600000)
            lobby.startsAt = ms and (t + ms) or nil
            if #lobby.players > 0 then lobbies[#lobbies + 1] = lobby end
        end
    end
    return { at = t, lobbies = lobbies, of = of }
end

-- activities.lua A.status: a provider's status arrived (with or without its queue).
function Q.status(a, raw)
    local old, new = rosters[a.id], Q.parse(raw, now())
    rosters[a.id] = new
    -- the same countdown sent again a moment later keeps its start (what the page counts)
    if old and new then
        for _, lobby in ipairs(new.lobbies) do
            local before = old.of[lobby.players[1]]
            if lobby.startsAt and before and before.startsAt and math.abs(lobby.startsAt - before.startsAt) <= START_SLACK_MS then
                lobby.startsAt = before.startsAt
            end
        end
    end
    local ids = {}
    if old then for id in pairs(old.of) do ids[id] = true end end
    if new then for id in pairs(new.of) do ids[id] = true end end
    -- its joins too: without a roster they read the status' `queued`
    for id, q in pairs(A.pending) do if q.activity == a.id then ids[id] = true end end
    for id in pairs(ids) do Q.refresh(id) end
end

-- activities.lua forget: the provider went; its players' panels follow.
function Q.forget(activityId)
    local old = rosters[activityId]
    rosters[activityId] = nil
    if old then for id in pairs(old.of) do Q.refresh(id) end end
end

local function unlist(id, activityId)
    local r = rosters[activityId]
    local lobby = r and r.of[id]
    if not lobby then return end
    r.of[id] = nil
    for i, p in ipairs(lobby.players) do if p == id then table.remove(lobby.players, i) break end end
    lobby.count = math.max(#lobby.players, lobby.count - 1)
end

-- The provider lobby this player is listed in: activityId, lobby (activities in id order).
local function listed(id)
    local found
    for aid, r in pairs(rosters) do
        if r.of[id] and A.registry[aid] and (found == nil or aid < found) then found = aid end
    end
    if found then return found, rosters[found].of[id] end
end

-- ---------------------------------------------------------------------------
-- The view

local function sinceFor(id, key, at)
    local s = seen[id]
    if not s or s.key ~= key then
        s = { key = key, at = at or now() }
        seen[id] = s
    elseif at and at < s.at then
        s.at = at
    end
    return s.at
end

local function modeLabel(a, q)
    if q.mode ~= nil then
        for _, m in ipairs(a.modes or {}) do if m.id == q.mode then return text(m.label, 32) or tostring(q.mode) end end
        return text(tostring(q.mode), 32)
    end
    if a.pve and q.difficulty ~= nil and A.diffLabel then return text(A.diffLabel(q.difficulty), 32) end
    return nil
end

local function fromLobby(v, lobby)
    v.count, v.need, v.max = lobby.count, lobby.need, lobby.max
    v.mode = lobby.mode or v.mode
    if lobby.joining then v.state = "joining"
    elseif lobby.startsAt then v.state, v.startsAt = "starting", lobby.startsAt end
end

-- A join the core holds or sent (activities.lua `pending`).
local function joinView(id, q)
    local a = A.registry[q.activity]
    if not a then return nil end
    local v = { id = a.id, label = a.label, mode = modeLabel(a, q), state = "waiting", source = "core",
        crew = (q.lead ~= nil and q.lead ~= id) or nil }
    v.at = sinceFor(id, a.id, q.at)
    local m = q.match and A.matches[q.match]
    if q.match then
        v.state = "joining"
        local n = m and #m.players or 1
        v.count, v.need = n, n
        return v
    end
    if q.held then
        local s = A.searchView and A.searchView(id, q, a) or {}
        v.count, v.need = math.max(1, s.found or 1), s.needed or math.max(2, a.minPlayers)
        return v
    end
    v.source = "provider"
    local r = rosters[a.id]
    local lobby = r and r.of[id]
    if lobby then fromLobby(v, lobby)
    else
        v.count = math.max(1, a.status and a.status.queued or 0)
        v.need = a.minPlayers
        v.max = a.maxPlayers > a.minPlayers and a.maxPlayers or nil
    end
    return v
end

-- The queue this player is in now, with absolute times (at, startsAt), or nil.
function Q.compute(id)
    if A.owned[id] then return nil end -- in play: the match started
    local q = A.pending[id]
    if q then
        local v = joinView(id, q)
        if v then return v end
    end
    local aid, lobby = listed(id)
    if aid then
        local a = A.registry[aid]
        local v = { id = aid, label = a.label, state = "waiting", source = "provider" }
        fromLobby(v, lobby)
        v.at = sinceFor(id, aid, nil)
        return v
    end
    local M = missions()
    local m = M and M.queueEntry and M.queueEntry(id)
    if m then
        local v = { id = "missions", label = m.label, mode = m.mode, count = m.count, need = m.need,
            max = m.max ~= nil and m.max > m.need and m.max or nil, state = m.startsAt and "starting" or "waiting",
            startsAt = m.startsAt, source = "mission" }
        v.at = sinceFor(id, "mission:" .. tostring(m.key), nil)
        return v
    end
    return nil
end

-- What the page gets (the times relative to now).
function Q.view(id)
    local v = Q.compute(id)
    if not v then seen[id] = nil; return false end
    local t = now()
    return { v = VERSION, id = v.id, label = v.label, mode = v.mode, count = v.count, need = v.need, max = v.max,
        sinceMs = math.max(0, t - v.at), startsInMs = v.startsAt and math.max(0, v.startsAt - t) or nil,
        state = v.state, crew = v.crew, source = v.source }
end
LightRP.stateProvider("queue", Q.view)

local function signature(v)
    return table.concat({ v.id, v.label, v.mode or "", v.count or "", v.need or "", v.max or "", v.state,
        v.crew and "c" or "", v.source, v.at }, "|")
end

-- Push this player's panel when what it shows changed. Returns true when pushed.
function Q.refresh(id)
    id = pid(id)
    if not id then return false end
    local v = Q.compute(id)
    local last = sent[id]
    if not v then
        seen[id] = nil
        if not last then return false end
        sent[id] = nil
        LightRP.state(id, "queue")
        return true
    end
    local sig = signature(v)
    if last and last.sig == sig and (last.startsAt == nil) == (v.startsAt == nil)
        and (v.startsAt == nil or math.abs(v.startsAt - last.startsAt) <= START_SLACK_MS) then
        return false
    end
    sent[id] = { sig = sig, startsAt = v.startsAt }
    LightRP.state(id, "queue")
    return true
end
A.queueStatus, A.queueForget, A.queueTouched = Q.status, Q.forget, Q.refresh

-- Every second: whoever waits, or still shows a panel (a provider that went quiet, a
-- board that launched without a push).
function Q.tick()
    local ids = {}
    for id in pairs(A.pending) do ids[id] = true end
    for _, r in pairs(rosters) do for id in pairs(r.of) do ids[id] = true end end
    local M = missions()
    if M and M.queuedPlayers then for _, id in ipairs(M.queuedPlayers()) do ids[id] = true end end
    for id in pairs(sent) do ids[id] = true end
    for id in pairs(ids) do Q.refresh(id) end
end

-- ---------------------------------------------------------------------------
-- Leaving

function Q.leave(id)
    local v = Q.compute(id)
    if not v then return false, "You are not in a queue." end
    if v.source == "mission" then
        local M = missions()
        if not (M and M.untag) then return false, "The mission boards are not available." end
        M.untag(id)
        Q.refresh(id)
        return true, "You left the board for " .. v.label .. "."
    end
    -- a join the core holds or sent: its own way out (a crew leader takes the crew along)
    if A.pending[id] then
        local ok, why = A.requestLeave(id)
        Q.refresh(id)
        return ok, why
    end
    -- a provider queue joined with the provider's own command: ask it, and the panel
    -- goes now (its next status confirms)
    unlist(id, v.id)
    local ok, err = pcall(TriggerEvent, A.events.leaveRequest, id, v.id)
    if not ok then LightRP.log("activity queue: leave request failed: %s", tostring(err)) end
    Q.refresh(id)
    return true, "You left the queue for " .. v.label .. "."
end

LightRP.action("queue.leave", function(id)
    local ok, why = Q.leave(id)
    LightRP.result(id, ok, why, "queue.leave")
end)

-- ---------------------------------------------------------------------------
-- Lifecycle (after activities.lua's own hooks: its joins are already gone)

local function letGo(id, tell)
    for aid, r in pairs(rosters) do
        if r.of[id] then
            unlist(id, aid)
            -- the provider hears of it like a /leave (it may follow the character change itself)
            if tell and not A.owned[id] then pcall(TriggerEvent, A.events.leaveRequest, id, aid) end
        end
    end
end
function Q.onDisconnected(id)
    letGo(id, false)
    seen[id], sent[id] = nil, nil
end
local function characterChanged(id)
    letGo(id, true)
    Q.refresh(id)
end
Q.onCharacterLoaded, Q.onCharacterSwitched = characterChanged, characterChanged

CreateThread(function()
    lightrpEvery(1000, function()
        
        local ok, err = pcall(Q.tick)
        if not ok then LightRP.log("activity queue: tick failed: %s", tostring(err)) end
    end, "activity_queue:328")
end)
