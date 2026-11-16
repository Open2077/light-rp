-- The launcher's server check (open77_preflight) in Light RP's words: who is coming back.
--
-- open77_preflight owns the check (Warden bans, the whitelist, rules, the screens); its
-- config.lua names this resource as `ui.provider`, so before it shows a screen it asks
--
--   exports.op77_lightrp:preflightScreen(screen, context)
--       screen  = "welcome" (anonymous, the server page) | "rules" | "greeting" | "allowed"
--                 | "refused" | "apply" | "full"
--       context = { player = { userId, name, ... }, server = { name, players, maxPlayers }, ... }
--
-- and merges the table we return into that screen's data (resources/system/open77_preflight/
-- ui/custom/*.rml read it). Everything here is read-only and fails open: no database, an
-- error or a slow query only means the screen is shown without these values, and the
-- check never waits more than open77_preflight's providerTimeoutMs for us.
local Preflight = {}
LightRP.preflight = Preflight

local Db = LightRP.db
local MAX_CHARACTERS = 4
local PLAYER_CACHE_SECONDS = 60
local WELCOME_CACHE_SECONDS = 300

local cache = {}          -- userId (lower) -> { at, value }
local welcome = { at = -math.huge, value = nil }

local function now()
    return GetUnixTime and GetUnixTime() or os.time()
end

-- "just now", "12 min ago", "3 h ago", "yesterday", "5 days ago", "3 weeks ago", "4 months ago".
function Preflight.ago(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds < 0 then return "" end
    if seconds < 120 then return "just now" end
    if seconds < 3600 then return ("%d min ago"):format(math.floor(seconds / 60)) end
    if seconds < 86400 then return ("%d h ago"):format(math.floor(seconds / 3600)) end
    local days = math.floor(seconds / 86400)
    if days == 1 then return "yesterday" end
    if days < 14 then return ("%d days ago"):format(days) end
    if days < 60 then return ("%d weeks ago"):format(math.floor(days / 7)) end
    return ("%d months ago"):format(math.floor(days / 30))
end

-- "45 min", "14 h", "120 h".
function Preflight.playtime(ms)
    local minutes = math.floor((tonumber(ms) or 0) / 60000)
    if minutes < 60 then return ("%d min"):format(minutes) end
    return ("%d h"):format(math.floor(minutes / 60))
end

-- "1,284".
function Preflight.thousands(n)
    local text = tostring(math.floor(tonumber(n) or 0))
    local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (result:gsub("^,", ""))
end

local function jobLabel(job, grade)
    local entry = type(LightRpJobs) == "table" and LightRpJobs[job] or nil
    if type(entry) ~= "table" or job == "unemployed" then return "Citizen" end
    local rank = type(entry.grades) == "table" and entry.grades[tonumber(grade) or 0] or nil
    local label = tostring(entry.label or job)
    if type(rank) == "table" and type(rank.label) == "string" and rank.label ~= label then label = label .. " · " .. rank.label end
    return label
end

local function fullName(row)
    local first = type(row.first_name) == "string" and row.first_name or ""
    local last = type(row.last_name) == "string" and row.last_name or ""
    return ((first .. " " .. last):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- The data of a returning (or first-time) player, from lightrp_accounts and
-- lightrp_characters. nil when the database cannot answer.
function Preflight.player(userId)
    local ok, accounts = Db.read([[SELECT active_key, UNIX_TIMESTAMP(last_seen) AS seen
        FROM lightrp_accounts WHERE identifier = ? LIMIT 1]], { userId })
    if not ok then return nil end
    local rows
    ok, rows = Db.read([[SELECT character_key, status, first_name, last_name, job, job_grade, playtime_ms,
            UNIX_TIMESTAMP(last_seen) AS seen
        FROM lightrp_characters WHERE identifier = ? AND status = 'active'
        ORDER BY last_seen DESC LIMIT ]] .. MAX_CHARACTERS, { userId })
    if not ok then return nil end

    local account = accounts[1]
    local clock = now()
    local characters, current = {}, nil
    for _, row in ipairs(rows) do
        local name = fullName(row)
        if name ~= "" then
            local character = {
                name = name,
                job = jobLabel(row.job, row.job_grade),
                seen = Preflight.ago(clock - (tonumber(row.seen) or clock)),
                playtime = Preflight.playtime(row.playtime_ms),
                active = account ~= nil and row.character_key == account.active_key,
            }
            characters[#characters + 1] = character
            -- The character the account plays now, else the one seen last.
            if character.active or current == nil then current = character end
        end
    end

    local data = {
        returning = current ~= nil,
        firstVisit = account == nil,
        characterCount = #characters,
        hasCharacters = #characters > 0,
        -- Several characters: the list under the greeting. One: the card alone says it.
        hasOthers = #characters > 1,
    }
    if #characters > 0 then data.characters = characters end
    if current then
        data.character = current.name
        data.characterJob = current.job
        data.characterPlaytime = current.playtime
        data.lastSeen = current.seen
        data.allowedMessage = "Welcome back to Night City, {character}."
    elseif account then
        -- An account whose character is not finished yet (the creator was left halfway).
        data.allowedMessage = "Welcome back, {name}. Your character is waiting in the creator."
    else
        data.allowedMessage = "Welcome to Night City, {name}. Your story starts in the lobby."
    end
    return data
end

-- The server page: how many people live in the city.
function Preflight.welcome()
    local clock = now()
    if clock - welcome.at < WELCOME_CACHE_SECONDS then return welcome.value end
    welcome.at = clock
    local ok, rows = Db.read("SELECT COUNT(*) AS n FROM lightrp_characters WHERE status = 'active'", {})
    if ok and rows[1] then
        local residents = tonumber(rows[1].n) or 0
        welcome.value = { residents = Preflight.thousands(residents), hasResidents = residents > 0 }
    end
    return welcome.value
end

exports("preflightScreen", function(screen, context)
    -- Only the server check asks; the answer is about an account, never sent elsewhere.
    if GetInvokingResource() ~= "open77_preflight" then return nil end
    if not Db.ready or type(screen) ~= "string" then return nil end
    if screen == "welcome" then return Preflight.welcome() end
    local player = type(context) == "table" and type(context.player) == "table" and context.player or nil
    local userId = player and type(player.userId) == "string" and player.userId:lower() or nil
    if not userId or not userId:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
        return nil
    end
    -- One join asks for two or three screens in a row (rules, greeting): one query.
    local cached = cache[userId]
    if cached and now() - cached.at < PLAYER_CACHE_SECONDS then return cached.value end
    local value = Preflight.player(userId)
    if value ~= nil then
        cache[userId] = { at = now(), value = value }
    end
    return value
end)

-- The cache only spares a second query inside one join: drop old entries now and then.
CreateThread(function()
    while true do
        Wait(300000)
        local clock = now()
        for userId, entry in pairs(cache) do
            if clock - entry.at >= PLAYER_CACHE_SECONDS then cache[userId] = nil end
        end
    end
end)

