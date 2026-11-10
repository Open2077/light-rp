-- The queue panel on NativeUI (ui/native/queue.rml), the page's QueuePanel.tsx: shown
-- whenever the player waits in a queue (server/modules/activity_queue.lua pushes the
-- "queue" state when it changes only). The wait counts up and the start counts down here,
-- from the push; the cancel key is the one client/core/queue.lua really bound.
--
-- The page's rules (ui/src/features/queue/model.ts, QueuePanel.tsx):
--   * a pushed view is cleaned first (normalize): junk fields dropped, `max` only when it
--     is more than `need`, a countdown only while starting
--   * nothing while the character is not active or its welcome is pending
--   * under the running mission's chip and a fixer gig's (40 dp lower)
-- The panel's cancel button answered a click "while the cursor is out"; the HUD steps
-- aside whenever the cursor is out (the shell), so only the key and F1 > Leave queue leave.
local N = LightRpNative
local Q = {}
LightRpNativeQueue = Q

local HOUR_MS = 3600000
local STATES = { waiting = true, starting = true, joining = true }
local SOURCES = { core = true, provider = true, mission = true }

local function whole(value, max)
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nil end
    local n = math.floor(value)
    if n >= 0 and n <= max then return n end
    return nil
end
-- The first `max` characters (not bytes) of a trimmed, single-line text; nil when empty.
local function text(value, max)
    if type(value) ~= "string" then return nil end
    local s = value:gsub("[%z\1-\31]+", " "):match("^%s*(.-)%s*$")
    if s == "" then return nil end
    local out, count = {}, 0
    for char in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > max then break end
        out[count] = char
    end
    return table.concat(out)
end
local function digits(n) return ("%d"):format(n) end

--- A pushed view, or nil.
function Q.normalize(raw)
    if type(raw) ~= "table" then return nil end
    local id, label = text(raw.id, 64), text(raw.label, 64)
    if not id or not label then return nil end
    local need = whole(raw.need, 1000)
    if need == 0 then need = nil end
    local max = whole(raw.max, 1000)
    if max ~= nil and (need == nil or max <= need) then max = nil end
    local startsInMs = whole(raw.startsInMs, HOUR_MS)
    local state = STATES[raw.state] and raw.state or (startsInMs ~= nil and "starting" or "waiting")
    return {
        id = id, label = label, mode = text(raw.mode, 32), count = whole(raw.count, 10000), need = need, max = max,
        sinceMs = whole(raw.sinceMs, 24 * HOUR_MS) or 0,
        startsInMs = state == "starting" and startsInMs or nil, state = state,
        crew = raw.crew == true or nil,
        source = SOURCES[raw.source] and raw.source or "provider",
    }
end

--- Players in the queue against the players it takes: "3 / 6", "3 / 2-8", or "3" alone.
function Q.countLabel(q)
    if q.count == nil and q.need == nil then return nil end
    local have = digits(q.count or 1)
    if q.need == nil then return have end
    return have .. " / " .. (q.max ~= nil and (digits(q.need) .. "-" .. digits(q.max)) or digits(q.need))
end
--- How many more it takes to start (0 once the minimum is there).
function Q.missing(q)
    if q.need == nil then return 0 end
    return math.max(0, q.need - (q.count or 1))
end
--- Elapsed time, floored: 0:07, 2:14, 1:02:09.
function Q.clockUp(ms)
    local s = math.max(0, math.floor(ms / 1000))
    local h, m = s // 3600, (s % 3600) // 60
    if h > 0 then return ("%d:%02d:%02d"):format(h, m, s % 60) end
    return ("%d:%02d"):format(m, s % 60)
end
--- Time left, rounded up (0:01 until it is really over).
function Q.clockDown(ms)
    local s = math.max(0, math.ceil(ms / 1000))
    return ("%d:%02d"):format(s // 60, s % 60)
end
--- The panel's tag, its tone, and a note beside the count ("NEED 2 MORE").
function Q.statusOf(q)
    if q.state == "joining" then return { tag = "MATCH FOUND", note = "JOINING", tone = "go" } end
    if q.state == "starting" then return { tag = q.source == "mission" and "LAUNCHING" or "STARTING", tone = "accent" } end
    local more = Q.missing(q)
    return { tag = q.source == "mission" and "TAGGED" or "QUEUED", note = more > 0 and ("NEED " .. digits(more) .. " MORE") or nil, tone = "plain" }
end
--- The cancel key's cap: the bound key, "U" until the client says, none once cleared.
function Q.keyCap(key)
    if key == false then return nil end
    local k = type(key) == "string" and key:match("^%s*(.-)%s*$") or ""
    if k ~= "" then return k:sub(1, 12) end
    return key == nil and "U" or nil
end

--- The document's values for a normalized view, `elapsed` ms after its push.
function Q.view(q, elapsed, key, under)
    elapsed = math.max(0, elapsed)
    local status = Q.statusOf(q)
    local count = Q.countLabel(q)
    local left = q.startsInMs ~= nil and math.max(0, q.startsInMs - elapsed) or nil
    local cap = Q.keyCap(key)
    return {
        on = true, starting = q.state == "starting", under = under == true,
        tag = status.tag, toneAccent = status.tone == "accent", toneGo = status.tone == "go",
        label = q.label, hasMode = q.mode ~= nil, mode = q.mode or "",
        hasCount = count ~= nil, count = count or "", hasNote = status.note ~= nil, note = status.note or "",
        hasStart = left ~= nil, startsIn = left ~= nil and Q.clockDown(left) or "",
        waited = Q.clockUp(q.sinceMs + elapsed),
        cap = cap or "F1", cancel = cap and "CANCEL" or "LEAVE QUEUE",
    }
end

local function model()
    return {
        ready = false, hidden = true, quiet = false,
        on = false, starting = false, under = false,
        tag = "", toneAccent = false, toneGo = false, label = "", hasMode = false, mode = "",
        hasCount = false, count = "", hasNote = false, note = "", hasStart = false, startsIn = "",
        waited = "0:00", cap = "U", cancel = "CANCEL",
    }
end

local doc
local queue, received = nil, 0
local ticking, epoch = false, 0

-- The key really bound (client/core/queue.lua); a rebind does not reach the state patches
-- the host sees, so it is read again on every tick.
local function boundKey()
    if LightRpQueue and type(LightRpQueue.keyName) == "function" then return LightRpQueue.keyName() or false end
    return N.state.queueKey
end
local function away()
    local character = N.state.character
    return type(character) ~= "table" or character.status ~= "active" or (character.welcomePending and true or false)
end
local function under()
    local mission = N.state.missionQueue
    return (N.state.fixerGig and true or false) or (type(mission) == "table" and mission.running == true)
end

-- Draws the panel; returns the ms until a clock changes, nil when nothing counts.
local function render()
    if not doc then return nil end
    if not queue or away() then
        N.patch(doc, "queue", { on = false })
        return nil
    end
    local elapsed = math.max(0, N.now() - received)
    N.patch(doc, "queue", Q.view(queue, elapsed, boundKey(), under()))
    if not N.shell.ready or N.shell.hidden or N.shell.quiet then return nil end
    local wait = 1000 - (queue.sinceMs + elapsed) % 1000
    if queue.startsInMs ~= nil then
        local left = queue.startsInMs - elapsed
        if left > 0 then wait = math.min(wait, (left - 1) % 1000 + 1) end
    end
    return math.max(40, wait + 15)
end
-- One thread at most counts; a push restarts it so the next tick falls on its own second.
local function refresh()
    local wait = render()
    epoch = epoch + 1
    ticking = wait ~= nil
    if not wait then return end
    local mine = epoch
    CreateThread(function()
        while true do
            Wait(wait)
            if mine ~= epoch then return end
            wait = render()
            if not wait then ticking = false; return end
        end
    end)
end
-- Something that moves no clock changed: draw, and count again if nothing was counting.
local function redraw()
    if ticking then render() else refresh() end
end

N.onStart(function()
    local values = model()
    values.ready, values.hidden, values.quiet = N.shell.ready, N.shell.hidden, N.shell.quiet
    doc = N.create({ document = "ui/native/queue.rml", zIndex = 30, models = { queue = values } })
    refresh()
end)
N.onShell(function(shell)
    N.patch(doc, "queue", { ready = shell.ready, hidden = shell.hidden, quiet = shell.quiet })
    refresh()
end)
N.onState("queue", function(value)
    queue, received = Q.normalize(value), N.now()
    refresh()
end)
N.onState("character", redraw)
N.onState("fixerGig", redraw)
N.onState("missionQueue", redraw)
