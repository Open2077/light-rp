-- op77_turf HUD model: turns the server's war state into the table Light RP's shared
-- activity HUD takes (op77_lightrp client export ActivityHudShow). Pure functions, no
-- natives: tests/hud_test.lua runs them as they are.
--
--   hud = { activity, title, subtitle, phase = "lobby"|"countdown"|"running"|"ended",
--           timer = { remainingMs, label, countUp }, countdown, objective,
--           stats = { { label, value } } (<= 4),
--           progress = { { id, label, value 0..1, tone } } (<= 3),
--           teams = { { name, color, score, self } } (<= 4),
--           scoreboard = { columns, rows = { { name, values, self, team } } } (<= 16),
--           hints = { { key, label } } (<= 4) }
TurfHud = {}
local H = TurfHud

local MAX_ROWS = 16
local BOT_PREFIX = "[BOT] "

local function clock(ms)
    local s = math.max(0, math.floor((ms or 0) / 1000 + 0.5))
    return ("%d:%02d"):format(s // 60, s % 60)
end
H.clock = clock

-- "#RRGGBB" -> { r, g, b, a }; nil on junk.
function H.rgb(hex, a)
    if type(hex) ~= "string" then return nil end
    local r, g, b = hex:match("^#(%x%x)(%x%x)(%x%x)$")
    if not r then return nil end
    return { r = tonumber(r, 16), g = tonumber(g, 16), b = tonumber(b, 16), a = a or 200 }
end

local function sideOf(shared, s) return shared.sides and shared.sides[s] or { label = "Side " .. tostring(s) } end

-- One zone's line on the HUD: who holds it, who is taking it, contested.
function H.zoneProgress(zone, shared, mySide)
    local name = ("%s · %s"):format(tostring(zone.id), tostring(zone.label))
    if zone.contested then
        return { id = zone.id, label = name .. " · CONTESTED", value = zone.capturing and zone.progress or (zone.owner and 1 or 0),
            tone = "accent" }
    end
    if zone.capturing then
        local who = sideOf(shared, zone.capturing).label
        return { id = zone.id, label = ("%s · %s taking it"):format(name, who), value = zone.progress or 0,
            tone = zone.capturing == mySide and "success" or "danger" }
    end
    if zone.owner then
        return { id = zone.id, label = ("%s · %s"):format(name, sideOf(shared, zone.owner).label), value = 1,
            tone = zone.owner == mySide and "success" or "danger" }
    end
    return { id = zone.id, label = name .. " · neutral", value = 0, tone = "info" }
end

-- Marker colour of a zone: the owner's colour, the accent when contested, else neutral.
-- Returns { r, g, b, a }, plus a key that changes only when the colour does.
function H.zoneColor(zone, shared, palette)
    if zone.contested then return palette.contested, "contested" end
    if zone.owner then
        local side = sideOf(shared, zone.owner)
        return H.rgb(side.color, 190) or palette.neutral, "owner" .. tostring(zone.owner)
    end
    return palette.neutral, "neutral"
end

local function kitLabel(personal, kits)
    for _, kit in ipairs(kits or {}) do if kit.id == personal.kit then return kit.label end end
    return personal.kitLabel or tostring(personal.kit or "-")
end

-- A Gang Sweep (mode "pve"): the humans take the zones from the NPC gang (side 2).
local function sweepObjective(shared, personal, target)
    local holders = sideOf(shared, 2).label
    if shared.phase == "placing" then return "Deploying to " .. tostring(shared.site and shared.site.label) end
    if shared.phase == "countdown" then return ("%s hold every zone · take them, first to %s"):format(holders, tostring(target)) end
    if shared.phase == "ended" then
        if shared.void then return "Sweep called off · nothing counts" end
        if shared.winner == 0 then return "Draw" end
        if shared.winner == personal.side then return "Victory · the district is yours" end
        return "Defeat · " .. holders .. " keep the turf"
    end
    if personal.respawnMs then return ("Down · back in %ds"):format(math.ceil(personal.respawnMs / 1000)) end
    if personal.outMs then return ("Back to the war zone! %ds"):format(math.ceil(personal.outMs / 1000)) end
    if personal.protectedMs then return "Spawn protection · take the zones from " .. holders end
    return ("Take the zones from %s · first to %s"):format(holders, tostring(target))
end

local function objective(shared, personal, target)
    if shared.mode == "pve" then return sweepObjective(shared, personal, target) end
    local mine = sideOf(shared, personal.side)
    local as = ("You fight for %s%s"):format(mine.label, personal.merc and " (mercenary)" or "")
    if shared.phase == "placing" then return "Deploying to " .. tostring(shared.site and shared.site.label) .. " · " .. as end
    if shared.phase == "countdown" then return as .. " · hold the zones, first to " .. tostring(target) end
    if shared.phase == "ended" then
        if shared.void then return "War called off · nothing counts" end
        if shared.winner == 0 then return "Draw" end
        return (shared.winner == personal.side and "Victory" or "Defeat") .. " · " .. sideOf(shared, shared.winner).label .. " holds the turf"
    end
    if personal.respawnMs then return ("Down · back in %ds"):format(math.ceil(personal.respawnMs / 1000)) end
    if personal.outMs then return ("Back to the war zone! %ds"):format(math.ceil(personal.outMs / 1000)) end
    if personal.protectedMs then return "Spawn protection · " .. as end
    return as .. " · first to " .. tostring(target)
end

local function scoreboard(shared, board, myId)
    local columns = { "K", "D", "CAP", "SCORE" }
    local rows, selfRow = {}, nil
    for _, r in ipairs(board or {}) do
        local name = tostring(r.name)
        -- A bot always reads as one (the server names it so; never trust that alone).
        if r.bot and name:sub(1, #BOT_PREFIX) ~= BOT_PREFIX then name = BOT_PREFIX .. name end
        local row = { name = name .. (r.merc and " ·M" or ""), values = { r.kills or 0, r.deaths or 0, r.captures or 0, r.score or 0 },
            self = r.id == myId, team = sideOf(shared, r.side).label }
        if row.self then selfRow = row end
        if #rows < MAX_ROWS then rows[#rows + 1] = row
        elseif row.self then rows[MAX_ROWS] = row end
    end
    return { columns = columns, rows = rows }, selfRow
end

-- The war HUD. opts = { kits, kitKey, target }.
function H.war(shared, personal, board, opts)
    opts = opts or {}
    personal = personal or {}
    local phase = shared.phase
    local hudPhase = (phase == "placing" or phase == "countdown") and "countdown" or (phase == "ended" and "ended" or "running")
    local site = shared.site or {}
    local pve = shared.mode == "pve"
    local hud = { activity = pve and "turf.pve" or "turf.war", title = pve and "GANG SWEEP" or "TURF WAR",
        subtitle = site.district and (tostring(site.label) .. " · " .. tostring(site.district)) or tostring(site.label),
        phase = hudPhase, objective = objective(shared, personal, opts.target or shared.target) }
    if phase == "countdown" then
        hud.timer = { remainingMs = shared.countdownMs or 0, label = "FIGHT IN" }
        hud.countdown = math.max(0, math.ceil((shared.countdownMs or 0) / 1000))
    elseif phase == "placing" then
        hud.timer = { remainingMs = shared.countdownMs or 0, label = "DEPLOYING" }
    elseif phase == "ended" then
        hud.timer = { remainingMs = shared.remainingMs or 0, label = "HOME IN" }
    else
        hud.timer = { remainingMs = shared.remainingMs or 0, label = "TIME LEFT" }
    end
    if phase == "ended" and type(shared.influence) == "table" and #shared.influence > 0 then
        -- The end card: who holds the city this week.
        hud.stats = {}
        for i, row in ipairs(shared.influence) do
            if i > 4 then break end
            local value = tostring(row.points)
            if row.delta then value = value .. (" (+%d)"):format(row.delta) end
            hud.stats[i] = { label = ("#%d %s"):format(i, tostring(row.label)), value = value }
        end
    else
        hud.stats = {
            { label = "K / D", value = ("%d / %d"):format(personal.kills or 0, personal.deaths or 0) },
            { label = "Captures", value = tostring(personal.captures or 0) },
            { label = "On zones", value = clock((personal.hold or 0) * 1000) },
            { label = "Kit", value = kitLabel(personal, opts.kits) },
        }
    end
    hud.progress = {}
    for i, zone in ipairs(shared.zones or {}) do
        if i > 3 then break end
        hud.progress[i] = H.zoneProgress(zone, shared, personal.side)
    end
    hud.teams = {}
    for s = 1, 2 do
        local side = sideOf(shared, s)
        hud.teams[s] = { name = side.label, color = side.color, score = side.score or 0, self = personal.side == s }
    end
    hud.scoreboard = scoreboard(shared, board, personal.id)
    hud.hints = {}
    if phase ~= "ended" then
        hud.hints[1] = { key = opts.kitKey or "K", label = phase == "running" and "Kit (next life)" or "Change kit" }
    end
    return hud
end

-- The lobby HUD for a queued player while the war is about to start.
function H.lobby(personal, opts)
    opts = opts or {}
    if personal.mode == "pve" then return H.sweepLobby(personal, opts) end
    local hud = { activity = "turf.war", title = "TURF WAR", subtitle = personal.site or "Night City", phase = "lobby",
        objective = ("Queued %d/%d · you will be pulled in when it starts"):format(personal.position or 0, personal.min or 0) }
    if personal.lobbyMs then hud.timer = { remainingMs = personal.lobbyMs, label = "STARTS IN" } end
    hud.stats = {
        { label = "Fighters", value = ("%d / %d"):format(personal.total or 0, personal.min or 0) },
        { label = "Side", value = personal.gang or "Mercenary" },
        { label = "Kit", value = kitLabel(personal, opts.kits) },
    }
    hud.hints = { { key = opts.kitKey or "K", label = "Change kit" } }
    return hud
end

-- A Gang Sweep line-up: the crew gathering, or waiting for a free sweep slot.
function H.sweepLobby(personal, opts)
    opts = opts or {}
    local objective
    if personal.waiting then
        objective = "Every sweep slot is taken · you go in when one frees up"
    elseif (personal.min or 0) > (personal.total or 0) then
        objective = ("Your crew is gathering %d/%d"):format(personal.total or 0, personal.min or 0)
    else
        objective = "Going in"
    end
    local hud = { activity = "turf.pve", title = "GANG SWEEP", subtitle = personal.site or "Night City", phase = "lobby",
        objective = objective }
    if personal.lobbyMs and not personal.waiting then hud.timer = { remainingMs = personal.lobbyMs, label = "STARTS IN" } end
    hud.stats = {
        { label = "Crew", value = ("%d / %d"):format(personal.total or 0, math.max(personal.min or 0, personal.total or 0)) },
        { label = "Kit", value = kitLabel(personal, opts.kits) },
    }
    hud.hints = { { key = opts.kitKey or "K", label = "Change kit" } }
    return hud
end

-- A result card for ActivityHudPush("result", ...): only the fields the HUD knows.
function H.result(payload)
    local lines = {}
    for _, line in ipairs(type(payload.lines) == "table" and payload.lines or {}) do
        if type(line) == "table" then lines[#lines + 1] = { label = tostring(line.label), value = tostring(line.value) } end
    end
    return { title = payload.title, placement = payload.placement, subtitle = payload.subtitle, lines = lines,
        durationMs = payload.durationMs }
end

-- A stable text of a HUD without its running clocks: the HUD is re-sent when this
-- changes (or now and then to resync the clock), not every second for nothing.
local function walk(value, out)
    local t = type(value)
    if t ~= "table" then out[#out + 1] = tostring(value) return end
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
        if k ~= "remainingMs" and k ~= "countdown" then
            out[#out + 1] = tostring(k) .. "="
            walk(value[k], out)
            out[#out + 1] = ","
        end
    end
    out[#out + 1] = "}"
end

function H.signature(hud)
    local out = {}
    walk(hud, out)
    return table.concat(out)
end
