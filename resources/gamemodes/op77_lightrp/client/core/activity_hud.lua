-- The shared in-match activity HUD: what an activity provider (op77_race, op77_arena,
-- op77_chase, a turf war...) shows its player during a match, drawn by Light RP's page
-- (ui/src/features/activityhud) in Light RP's design. Pure overlay: no focus, no input,
-- no key binding.
--
-- Client exports of op77_lightrp (README.md, "HUD d'activité"):
--   ActivityHudShow(hud)           -> true | false, reason   replaces the whole state
--   ActivityHudPush(kind, payload) -> true | false, reason   "feed" | "banner" | "result"
--   ActivityHudClear()             -> true | false, reason
--   Notice(notice)                 -> true | false, reason   a notice in Light RP's stack
--                                                            (shared/notice.lua)
--
-- One HUD at a time, owned by the resource that showed it; a newer Show replaces it,
-- whoever sends it. The caller is another resource: everything is validated and
-- clamped here (types, lengths, counts, bad entries dropped) before it reaches the
-- page. The HUD goes when its owner stops or restarts, or when the character changes.
local E = LightRpEvents.page
local SELF = GetCurrentResourceName()

local H = { current = nil }
LightRpActivityHud = H

local PHASES = { lobby = true, countdown = true, running = true, ended = true }
local TONES = { accent = true, danger = true, info = true, success = true }
local LIMIT = {
    activity = 48, title = 48, subtitle = 80, objective = 120,
    label = 24, value = 24, timerLabel = 16, id = 32,
    team = 24, score = 8, column = 16, cell = 16, row = 32,
    key = 12, hint = 32,
    feed = 96, bannerTitle = 40, bannerText = 120,
    resultTitle = 40, resultSubtitle = 80, placement = 8,
}
local COUNT = { stats = 4, progress = 3, teams = 4, columns = 4, rows = 16, hints = 4, lines = 6, scan = 64 }
local MAX_TIMER_MS = 24 * 3600 * 1000
local MAX_COUNTDOWN_MS = 60000
local RATE = { windowMs = 1000, calls = 30 } -- per owner, Show and Push together

-- ---------------------------------------------------------------------------
-- Validation helpers (exported on H for the tests)

local function now()
    if type(GetGameTimer) == "function" then return GetGameTimer() end
    return math.floor(os.clock() * 1000)
end

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function numberText(value)
    if math.type(value) == "integer" then return tostring(value) end
    if value == math.floor(value) and math.abs(value) < 1e15 then return string.format("%d", value) end
    return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", ""))
end

-- A short single-line text: strings (and numbers when allowed), control characters
-- replaced, trimmed, cut on a UTF-8 boundary. nil when empty or of another type.
local function text(value, max, numbers)
    if numbers and finite(value) then value = numberText(value) end
    if type(value) ~= "string" then return nil end
    value = value:gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #value == 0 then return nil end
    if #value > max then
        local cut = max
        while cut > 0 do
            local b = value:byte(cut + 1)
            if not b or b < 0x80 or b >= 0xC0 then break end
            cut = cut - 1
        end
        value = value:sub(1, cut):gsub("%s+$", "")
        if #value == 0 then return nil end
    end
    return value
end
H.text = text

local function clamp(value, low, high)
    if not finite(value) then return nil end
    if value < low then return low end
    if value > high then return high end
    return value
end

local function tone(value) return TONES[value] and value or nil end

-- A team colour: "#rgb" / "#rrggbb", or one of the signal tones. Anything else: none.
local function colour(value)
    if type(value) ~= "string" then return nil end
    if value:match("^#%x%x%x$") or value:match("^#%x%x%x%x%x%x$") then return value:lower() end
    return tone(value)
end

-- The array part of a provider's list, at most `max` valid entries (scanning a bounded
-- number of raw entries, so a huge table costs nothing).
local function list(value, max, each)
    if type(value) ~= "table" then return nil end
    local out = {}
    for index = 1, COUNT.scan do
        if #out >= max then break end
        local raw = value[index]
        if raw == nil then break end
        local item = each(raw, index, out)
        if item ~= nil then out[#out + 1] = item end
    end
    return #out > 0 and out or nil -- an empty list stays out (Lua {} would reach the page as an object)
end

local function stat(raw)
    if type(raw) ~= "table" then return nil end
    local label = text(raw.label, LIMIT.label, true)
    if not label then return nil end
    return { label = label, value = text(raw.value, LIMIT.value, true) or "-" }
end

local function progress(raw, index)
    if type(raw) ~= "table" then return nil end
    local value = clamp(raw.value, 0, 1)
    if value == nil then return nil end
    local id = text(raw.id, LIMIT.id, true) or ("p" .. index)
    return { id = id, label = text(raw.label, LIMIT.label, true), value = value, tone = tone(raw.tone) or "accent" }
end

local function team(raw)
    if type(raw) ~= "table" then return nil end
    local name = text(raw.name, LIMIT.team, true)
    if not name then return nil end
    return { name = name, color = colour(raw.color), score = text(raw.score, LIMIT.score, true), self = raw.self == true or nil }
end

local function hint(raw)
    if type(raw) ~= "table" then return nil end
    local key, label = text(raw.key, LIMIT.key, true), text(raw.label, LIMIT.hint, true)
    if not key or not label then return nil end
    return { key = key, label = label }
end

local function timer(raw)
    if type(raw) ~= "table" then return nil end
    local remaining = clamp(raw.remainingMs, 0, MAX_TIMER_MS)
    if remaining == nil then return nil end
    return { remainingMs = math.floor(remaining), label = text(raw.label, LIMIT.timerLabel, true), countUp = raw.countUp == true or nil }
end

-- Milliseconds until GO. A small number (10 or less) is read as seconds: nobody sends
-- a 10 ms countdown, and `countdown = 3` is the natural way to write three seconds.
local function countdown(raw)
    if not finite(raw) or raw < 0 then return nil end
    if raw <= 10 then raw = raw * 1000 end
    return math.floor(math.min(raw, MAX_COUNTDOWN_MS))
end

local function scoreboard(raw, teams)
    if type(raw) ~= "table" then return nil end
    -- A bad header stays as a blank one: dropping it would shift every value after it.
    local columns = list(raw.columns, COUNT.columns, function(c) return text(c, LIMIT.column, true) or "" end) or {}
    local selfSeen = false
    local rows = list(raw.rows, COUNT.rows, function(r)
        if type(r) ~= "table" then return nil end
        local name = text(r.name, LIMIT.row, true)
        if not name then return nil end
        local values = {}
        if type(r.values) == "table" then
            for index = 1, #columns do
                values[index] = text(r.values[index], LIMIT.cell, true) or "-"
            end
        end
        local mine = r.self == true and not selfSeen
        if mine then selfSeen = true end
        local side = nil
        if finite(r.team) and r.team % 1 == 0 and teams and teams[math.floor(r.team)] then side = math.floor(r.team)
        elseif type(r.team) == "string" and teams then
            for i, t in ipairs(teams) do if t.name == r.team then side = i; break end end
        end
        return { name = name, values = #values > 0 and values or nil, self = mine or nil, team = side }
    end)
    if not rows then return nil end
    return { columns = #columns > 0 and columns or nil, rows = rows }
end

-- The whole HUD as the page receives it, or nil, reason.
function H.normalize(hud)
    if type(hud) ~= "table" then return nil, "invalid_hud" end
    local activity = text(hud.activity, LIMIT.activity, false)
    if activity then activity = activity:gsub("[^%w_%-%.:]", "") end
    local teams = list(hud.teams, COUNT.teams, team)
    local clean = {
        activity = activity ~= "" and activity or nil,
        title = text(hud.title, LIMIT.title, true) or "Activity",
        subtitle = text(hud.subtitle, LIMIT.subtitle, true),
        phase = PHASES[hud.phase] and hud.phase or "running",
        timer = timer(hud.timer),
        countdown = countdown(hud.countdown),
        objective = text(hud.objective, LIMIT.objective, true),
        stats = list(hud.stats, COUNT.stats, stat),
        progress = list(hud.progress, COUNT.progress, progress),
        teams = teams,
        scoreboard = scoreboard(hud.scoreboard, teams),
        hints = list(hud.hints, COUNT.hints, hint),
    }
    return clean
end

function H.normalizePush(kind, payload)
    if type(payload) ~= "table" then return nil, "invalid_payload" end
    if kind == "feed" then
        local line = text(payload.text, LIMIT.feed, true)
        if not line then return nil, "invalid_payload" end
        return { text = line, tone = tone(payload.tone) }
    elseif kind == "banner" then
        local title, body = text(payload.title, LIMIT.bannerTitle, true), text(payload.text, LIMIT.bannerText, true)
        if not title and not body then return nil, "invalid_payload" end
        local duration = clamp(payload.durationMs, 800, 10000)
        return { title = title, text = body, tone = tone(payload.tone), durationMs = math.floor(duration or 3000) }
    elseif kind == "result" then
        local placement
        if math.type(payload.placement) == "integer" or (finite(payload.placement) and payload.placement % 1 == 0) then
            local n = math.floor(payload.placement)
            if n >= 1 and n <= 999 then placement = n end
        else
            placement = text(payload.placement, LIMIT.placement, false)
        end
        local title = text(payload.title, LIMIT.resultTitle, true)
        if not title and placement == nil then return nil, "invalid_payload" end
        local duration = clamp(payload.durationMs, 2000, 30000)
        return {
            title = title, placement = placement, subtitle = text(payload.subtitle, LIMIT.resultSubtitle, true),
            lines = list(payload.lines, COUNT.lines, stat), durationMs = math.floor(duration or 8000),
        }
    end
    return nil, "invalid_kind"
end

-- ---------------------------------------------------------------------------
-- Ownership

local characterKey, characterActive = nil, false

local function generationOf(name)
    if type(Open77) ~= "table" or type(Open77.resource) ~= "table" or type(Open77.resource.generation) ~= "function" then return nil end
    local ok, value = pcall(Open77.resource.generation, name)
    return ok and value or nil
end

-- Who is calling: another resource through the exports, or Light RP itself.
local function caller()
    local name = type(GetInvokingResource) == "function" and GetInvokingResource() or nil
    if type(name) ~= "string" or name == "" or name == SELF then return SELF, nil end
    local generation = type(GetInvokingResourceGeneration) == "function" and GetInvokingResourceGeneration() or nil
    return name, generation or generationOf(name)
end

local function send(payload)
    if not LightRpUi or LightRpUi.page == nil then return false, "ui_unavailable" end
    local sent, why = LightRpUi.send(E.activityHud, payload)
    if sent == false then return false, why or "ui_unavailable" end
    return true
end

local function limited(entry)
    local t = now()
    if t - (entry.windowAt or -math.huge) >= RATE.windowMs then entry.windowAt, entry.calls = t, 0 end
    entry.calls = (entry.calls or 0) + 1
    return entry.calls > RATE.calls
end

local function drop(reason)
    if H.current == nil then return false end
    H.current = nil
    send({ op = "clear", reason = reason })
    return true
end
H.drop = drop

-- ---------------------------------------------------------------------------
-- The API

function H.show(hud)
    local owner, generation = caller()
    local clean, why = H.normalize(hud)
    if not clean then return false, why end
    local entry = H.current
    if entry == nil or entry.owner ~= owner or entry.generation ~= generation then
        entry = { owner = owner, generation = generation }
    end
    if limited(entry) then return false, "rate_limited" end
    entry.hud, entry.characterKey = clean, characterKey
    H.current = entry
    return send({ op = "show", hud = clean })
end

function H.push(kind, payload)
    local owner, generation = caller()
    local entry = H.current
    -- A HUD shown by another resource is theirs; transient items alone belong to nobody.
    if entry and entry.hud and entry.owner ~= owner and owner ~= SELF then return false, "not_owner" end
    local item, why = H.normalizePush(kind, payload)
    if not item then return false, why end
    if entry == nil or (entry.hud == nil and entry.owner ~= owner) then
        entry = { owner = owner, generation = generation, characterKey = characterKey }
        H.current = entry
    end
    if limited(entry) then return false, "rate_limited" end
    return send({ op = "push", kind = kind, item = item })
end

function H.clear()
    local owner = caller()
    local entry = H.current
    if entry == nil then return true end
    if entry.owner ~= owner and owner ~= SELF then return false, "not_owner" end
    drop("cleared")
    return true
end

function H.isActive() return H.current ~= nil and H.current.hud ~= nil end
function H.owner() return H.current and H.current.owner or nil end

-- A notice from a provider's client (the same as the server export `notice`): Light RP's
-- notice stack, in its design, never a UI of the provider's. shared/notice.lua cleans it.
local noticeRates = {} -- caller -> { windowAt, calls }
function H.notice(notice)
    local owner = caller()
    local payload, why = LightRpNotice.clean(notice)
    if not payload then return false, why end
    local entry = noticeRates[owner] or {}
    noticeRates[owner] = entry
    if limited(entry) then return false, "rate_limited" end
    payload.source = payload.source or "LIGHT RP"
    if not LightRpUi or LightRpUi.page == nil then return false, "ui_unavailable" end
    local sent, failure = LightRpUi.send(E.notice, payload)
    if sent == false then return false, failure or "ui_unavailable" end
    return true
end

exports("ActivityHudShow", H.show)
exports("ActivityHudPush", H.push)
exports("ActivityHudClear", H.clear)
exports("Notice", H.notice)

-- ---------------------------------------------------------------------------
-- Lifetime: the owner's stop or restart, a character change

AddEventHandler("onClientResourceStop", function(name)
    local entry = H.current
    if entry and name == entry.owner then drop("owner_stopped") end
end)

RegisterNetEvent(LightRpEvents.net.state, function(patch)
    if type(patch) ~= "table" or type(patch.character) ~= "table" then return end
    local c = patch.character
    characterKey = type(c.key) == "string" and c.key or characterKey
    characterActive = c.status == "active"
    local entry = H.current
    if entry == nil then return end
    if not characterActive then drop("character_changed"); return end
    if entry.characterKey == nil then entry.characterKey = characterKey
    elseif entry.characterKey ~= characterKey then drop("character_changed") end
end)

CreateThread(function()
    while true do
        Wait(500)
        local entry = H.current
        if entry and entry.owner ~= SELF then
            local state = type(GetResourceState) == "function" and GetResourceState(entry.owner) or "running"
            if state ~= "running" then drop("owner_stopped")
            elseif entry.generation ~= nil then
                local live = generationOf(entry.owner)
                if live ~= nil and live ~= entry.generation then drop("owner_restarted") end
            end
        end
    end
end)
