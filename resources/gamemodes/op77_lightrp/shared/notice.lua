-- Another resource's notice in Light RP's own page (its design, its notice stack): the
-- cleaner behind the two exports an activity provider calls instead of a UI of its own
-- (owner rule 2026-11-02: what is adapted into Light RP renders in Light RP's UI).
--   server  exports.op77_lightrp:notice(playerId, notice) -> true | false, reason
--           (server/modules/activities.lua)
--   client  exports.op77_lightrp:Notice(notice)           -> true | false, reason
--           (client/core/activity_hud.lua)
-- notice = { kind, title, body, durationMs, source }
--   kind        info | success | warning | error; "danger" reads as warning; anything
--               else is info (the page draws a known kind only)
--   title       48 characters (optional)
--   body        280 characters, required; `text` / `message` are accepted for it
--   durationMs  2 to 20 s, 6 s by default
--   source      the head line, 24 characters (optional, "LIGHT RP" by default)
-- Control characters become spaces, texts are trimmed and cut on a UTF-8 boundary.
LightRpNotice = {}
local N = LightRpNotice

N.KINDS = { info = "info", success = "success", warning = "warning", error = "error", danger = "warning" }
N.LIMIT = { title = 48, body = 280, source = 24 }
N.DURATION = { default = 6000, min = 2000, max = 20000 }

-- A short single-line text, or nil when empty or not a string.
function N.text(value, max)
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

-- The payload the page gets, or nil plus a reason (invalid_notice, empty_notice).
function N.clean(notice)
    if type(notice) ~= "table" then return nil, "invalid_notice" end
    local body = N.text(notice.body, N.LIMIT.body) or N.text(notice.text, N.LIMIT.body)
        or N.text(notice.message, N.LIMIT.body)
    if body == nil then return nil, "empty_notice" end
    local duration = tonumber(notice.durationMs)
    if duration == nil or duration ~= duration or duration == math.huge or duration == -math.huge then
        duration = N.DURATION.default
    end
    duration = math.floor(math.max(N.DURATION.min, math.min(N.DURATION.max, duration)))
    return {
        kind = N.KINDS[notice.kind] or "info",
        title = N.text(notice.title, N.LIMIT.title),
        body = body,
        source = N.text(notice.source, N.LIMIT.source),
        durationMs = duration,
    }
end
