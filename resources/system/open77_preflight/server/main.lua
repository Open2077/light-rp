-- open77_preflight: what a player sees between pressing Join in the launcher and the
-- game starting.
--
--   1. The server checks the player's identity and its door list (access.json: Warden
--      bans and the whitelist). When the list says no, onPreflightRefused runs here
--      and presents it: a ban page, or the whitelist application form. This resource
--      can never let such a player in; only the door list can change its mind, and
--      when it does (an unban, an approval) the server sends the session on to step 2.
--   2. onPreflight runs for everybody the door list admits: kicked a moment ago?
--      maintenance? Discord required? server full? rules to accept? Then allowed.
--
-- Everything fails safe. If this resource errors or stops, a player the door list
-- admits is allowed and a player it refuses reads the server's own plain sentence.
-- The in-game handshake checks the door list again whatever happened here.

Preflight = {}

local preflight = Open77.preflight
local access = Open77.access
local store = PreflightStore

-- ------------------------------------------------------------------ settings

local function section(name)
    local value = type(PreflightConfig) == "table" and PreflightConfig[name] or nil
    return type(value) == "table" and value or {}
end

local function pick(value, default)
    if value == nil then return default end
    return value
end

local function text(value, default)
    if type(value) == "string" and value ~= "" then return value end
    return default
end

local function httpsLink(value, label)
    if type(value) ~= "string" or value == "" then return nil end
    if value:sub(1, 8) ~= "https://" or value:find("[%s\"<>]") then
        print(("config: the %s link is ignored (a link must start with https://)"):format(label))
        return nil
    end
    return value
end

local function stringList(value)
    local list = {}
    if type(value) == "table" then
        for _, item in ipairs(value) do
            if type(item) == "string" and item ~= "" then list[#list + 1] = item end
        end
    end
    return list
end

local linksConfig = section("links")
local welcomeConfig = section("welcome")
local rulesConfig = section("rules")
local discordConfig = section("discord")
local whitelistConfig = section("whitelist")
local maintenanceConfig = section("maintenance")
local fullConfig = section("full")
local bansConfig = section("bans")
local uiConfig = section("ui")
local greetingConfig = section("greeting")

-- The screens this resource shows, each a document under ui/ (ui/<screen>.rml unless
-- config.lua's ui.documents names another file of this resource).
local SCREENS = { "welcome", "rules", "apply", "refused", "full", "greeting" }

local function documentPath(value, screen)
    if type(value) ~= "string" or value == "" then return nil end
    if not value:match("^[%w_%-%./]+%.rml$") or value:find("..", 1, true) or value:sub(1, 1) == "/" then
        print(("config: ui.documents.%s is ignored (a path to an .rml file of this resource, like ui/custom/%s.rml)")
            :format(screen, screen))
        return nil
    end
    return value
end

local function clamp(value, low, high, default)
    value = tonumber(value)
    if value == nil or value ~= value then return default end
    return math.max(low, math.min(high, value))
end

local CONFIG = {
    discordLink = httpsLink(linksConfig.discord, "Discord"),
    appealLink = httpsLink(linksConfig.appeal, "appeal"),
    websiteLink = httpsLink(linksConfig.website, "website"),
    welcome = {
        enabled = pick(welcomeConfig.enabled, true) == true,
        title = text(welcomeConfig.title, nil),
        text = text(welcomeConfig.text, nil),
        showPlayers = pick(welcomeConfig.showPlayers, true) == true,
        showRules = pick(welcomeConfig.showRules, true) == true,
    },
    announcements = stringList(type(PreflightConfig) == "table" and PreflightConfig.announcements or nil),
    rules = {
        enabled = rulesConfig.enabled == true,
        title = text(rulesConfig.title, "Server rules"),
        items = stringList(rulesConfig.items),
        checkbox = pick(rulesConfig.checkbox, true) == true,
    },
    discord = {
        required = discordConfig.required == true,
        message = text(discordConfig.message, "This server needs a Discord account linked to your OPEN//77 account. " ..
            "Link it in the launcher (Settings > Account), then join again."),
    },
    whitelist = {
        applications = pick(whitelistConfig.applications, true) == true,
        prompt = text(whitelistConfig.prompt, "Tell the staff who you are and how you found the server."),
        minLength = math.max(0, math.min(200, math.floor(tonumber(whitelistConfig.minLength) or 10))),
        reapply = pick(whitelistConfig.reapply, true) == true,
        inviteCodes = {},
    },
    maintenance = {
        enabled = maintenanceConfig.enabled == true,
        message = text(maintenanceConfig.message, "The server is under maintenance. Please come back later."),
        allowWhitelisted = maintenanceConfig.allowWhitelisted == true,
        allow = {},
    },
    full = {
        mode = (fullConfig.mode == "refuse" or fullConfig.mode == "off") and fullConfig.mode or "wait",
        message = text(fullConfig.message, "The server is full. You will be let in as soon as a slot frees."),
    },
    bans = {
        showReason = pick(bansConfig.showReason, true) == true,
        showStaff = bansConfig.showStaff == true,
    },
    allowedMessage = type(PreflightConfig) == "table" and type(PreflightConfig.allowedMessage) == "string"
        and PreflightConfig.allowedMessage or "Welcome to {server}, {name}.",
    kickSeconds = math.max(0, math.min(3600, math.floor(tonumber(type(PreflightConfig) == "table" and PreflightConfig.kickSeconds) or 120))),
    ui = {
        documents = {},
        data = {},
        provider = text(uiConfig.provider, nil),
        providerExport = text(uiConfig.providerExport, "preflightScreen"),
        providerTimeoutMs = math.floor(clamp(uiConfig.providerTimeoutMs, 50, 5000, 1500)),
    },
    greeting = {
        enabled = greetingConfig.enabled == true,
        seconds = clamp(greetingConfig.seconds, 0, 15, 4),
    },
}
do
    local documents = type(uiConfig.documents) == "table" and uiConfig.documents or {}
    for _, screen in ipairs(SCREENS) do CONFIG.ui.documents[screen] = documentPath(documents[screen], screen) end
    for key, value in pairs(type(uiConfig.data) == "table" and uiConfig.data or {}) do
        if type(key) == "string" then CONFIG.ui.data[key] = value end
    end
end
for _, code in ipairs(stringList(whitelistConfig.inviteCodes)) do CONFIG.whitelist.inviteCodes[code:upper()] = true end
for _, id in ipairs(stringList(maintenanceConfig.allow)) do CONFIG.maintenance.allow[id:lower()] = true end
if CONFIG.rules.enabled and #CONFIG.rules.items == 0 then
    print("config: rules.enabled is on but rules.items is empty; the rules step is skipped")
    CONFIG.rules.enabled = false
end
store.setVersion(rulesConfig.version)

Preflight.config = CONFIG

-- ------------------------------------------------------------------ state

-- Is this resource the one the server's configuration names (preflight.resource)?
-- When it is not, Open77.preflight answers (false, reason): the exports still work,
-- the screens are somebody else's.
local owner = false
do
    local status, reason = preflight.status()
    owner = type(status) == "table"
    if not owner then
        print(("not the preflight owner (%s): the exports stay available, the launcher screens belong to the " ..
            "resource named by preflight.resource"):format(tostring(reason)))
    end
end
Preflight.owner = owner

-- Each time a session enters a step it gets a new stage number; a loop or a handler
-- left over from an earlier step sees that it is no longer current and stops.
local stages = {}
-- userId (lower) -> { message, untilUnix }: kicked through the export a moment ago.
local kicks = {}

local function enter(session)
    local stage = (stages[session.id] or 0) + 1
    stages[session.id] = stage
    return stage
end

local function current(session, stage)
    return stages[session.id] == stage and session:alive()
end

local function serverInfo(session)
    local info = preflight.server()
    if type(info) ~= "table" then info = session and session.server or nil end
    if type(info) ~= "table" then info = {} end
    return {
        name = text(info.name, "this server"),
        description = text(info.description, ""),
        players = tonumber(info.players) or 0,
        maxPlayers = tonumber(info.maxPlayers) or 0,
        whitelist = info.whitelist == true,
    }
end

local function announcements()
    local live = store.get("announcement", "")
    local list = {}
    if type(live) == "string" and live ~= "" then list[#list + 1] = live end
    for _, line in ipairs(CONFIG.announcements) do list[#list + 1] = line end
    return list
end

function Preflight.maintenance()
    local live = store.get("maintenance")
    local enabled = CONFIG.maintenance.enabled
    if live == "on" then enabled = true elseif live == "off" then enabled = false end
    local message = store.get("maintenance.message", "")
    if type(message) ~= "string" or message == "" then message = CONFIG.maintenance.message end
    return enabled, message
end

-- Lists never travel empty: an empty Lua table has no way to say it is a list, so a
-- screen tests the `has...` flag next to it instead.
local function withList(data, key, list)
    local flag = "has" .. key:sub(1, 1):upper() .. key:sub(2)
    if #list > 0 then
        data[key] = list
        data[flag] = true
    else
        data[flag] = false
    end
end

local function linkData(data)
    data.discord = CONFIG.discordLink or ""
    data.hasDiscord = CONFIG.discordLink ~= nil
    data.website = CONFIG.websiteLink or ""
    data.hasWebsite = CONFIG.websiteLink ~= nil
    return data
end

-- ------------------------------------------------------------------ your own screens

-- One line per distinct problem a minute, not one per player.
local warnedAt = {}
local function warnOnce(line)
    local now = GetUnixTime()
    if warnedAt[line] and now - warnedAt[line] < 60 then return end
    warnedAt[line] = now
    print(line)
end

local function merge(into, extra)
    if type(extra) ~= "table" then return into end
    for key, value in pairs(extra) do
        if type(key) == "string" then into[key] = value end
    end
    return into
end

-- What config.lua's ui.provider is told about the screen it completes. No session: the
-- anonymous welcome screen.
local function screenContext(screen, session, data)
    local info = serverInfo(session)
    local context = {
        screen = screen,
        server = { name = info.name, players = info.players, maxPlayers = info.maxPlayers, whitelist = info.whitelist },
    }
    if session then
        local player = session.player
        context.player = {
            userId = tostring(player.userId),
            name = player.name,
            ticket = player.ticket == true,
            discord = player.discord,
        }
        context.locale = type(session.launcher) == "table" and session.launcher.locale or nil
        context.kind = type(data) == "table" and data.kind or nil
    end
    return context
end

-- Extra data for one screen from the provider resource (ui.provider), or nil. It never
-- waits longer than ui.providerTimeoutMs, and a provider that errors, is stopped or is
-- slow only means the screen goes on without its values.
local function provide(screen, session, data)
    local ui = CONFIG.ui
    if not ui.provider then return nil end
    local ok, value, reason = pcall(function()
        local pending, why = Open77.exports.call(ui.provider, ui.providerExport, screen, screenContext(screen, session, data))
        if not pending then return nil, why or "call_refused" end
        local deadline = GetGameTimer() + ui.providerTimeoutMs
        while pending:status() == "pending" do
            if GetGameTimer() >= deadline then return nil, "timeout" end
            Wait(0)
        end
        local answer, failure = pending:await()
        if answer == nil then return nil, failure end
        if type(answer) ~= "table" then return nil, "the export did not return a table" end
        return answer
    end)
    if not ok then value, reason = nil, tostring(value) end
    if value == nil and reason ~= nil then
        warnOnce(("ui.provider %s:%s gave no data for the %s screen (%s); it is shown without")
            :format(ui.provider, ui.providerExport, screen, tostring(reason)))
    end
    return value
end

-- A screen's data: config.lua's ui.data, then what this resource computed, then the
-- provider's values (which win). Also returns the provider's own table, or nil.
local function decorate(screen, session, data)
    local result = merge({}, CONFIG.ui.data)
    merge(result, data)
    local extra = provide(screen, session, result)
    return merge(result, extra), extra
end

-- The view of a screen: config.lua's document when it names one, else the shipped file.
local function screenView(screen, data, shipped)
    local custom = CONFIG.ui.documents[screen]
    return { file = (not shipped and custom) or ("ui/" .. screen .. ".rml"), data = data }
end

local function gone(reason)
    return reason == "session_ended" or reason == "session_not_found"
end

-- Shows a screen. A document of yours that cannot be sent (not well-formed, too big,
-- missing) falls back to the shipped one, so a typo never strands a player.
local function present(session, screen, data)
    local ok, reason = session:show(screenView(screen, data))
    if ok or gone(reason) or not CONFIG.ui.documents[screen] then return ok, reason end
    warnOnce(("your %s screen (%s) was not shown (%s); the shipped one is used")
        :format(screen, CONFIG.ui.documents[screen], tostring(reason)))
    return session:show(screenView(screen, data, true))
end

-- ------------------------------------------------------------------ welcome screen

local welcomeSignature = nil
-- The provider's values for the welcome screen, refreshed by the loop below.
local welcomeExtra = nil

-- A stable text of a value, to tell whether the welcome screen changed.
local function stableText(value, depth)
    depth = depth or 0
    if type(value) ~= "table" then return tostring(value) end
    if depth > 6 then return "{...}" end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. stableText(value[key], depth + 1) end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- `refresh`: ask ui.provider again (only from a thread: the provider is called
-- asynchronously). Otherwise its last values are kept.
function Preflight.publishWelcome(force, refresh)
    if not owner then return end
    if refresh and CONFIG.welcome.enabled and CONFIG.ui.provider then
        welcomeExtra = provide("welcome", nil, nil)
    end
    if not CONFIG.welcome.enabled then
        if welcomeSignature ~= "off" then
            preflight.welcome(nil)
            welcomeSignature = "off"
        end
        return
    end
    local info = serverInfo()
    local maintenance, maintenanceMessage = Preflight.maintenance()
    local lines = announcements()
    -- The launcher caches hello for a minute; republishing only on a real change keeps
    -- the screen's revision quiet.
    local signature = table.concat({ info.name, info.description, info.players, info.maxPlayers, tostring(info.whitelist),
        tostring(maintenance), maintenanceMessage, table.concat(lines, "\n"), stableText(welcomeExtra) }, "|")
    if not force and signature == welcomeSignature then return end
    local data = linkData(merge({}, CONFIG.ui.data))
    merge(data, {
        title = CONFIG.welcome.title or info.name,
        text = CONFIG.welcome.text or info.description,
        hasText = (CONFIG.welcome.text or info.description) ~= "",
        showPlayers = CONFIG.welcome.showPlayers and info.maxPlayers > 0,
        players = info.players,
        maxPlayers = info.maxPlayers,
        full = info.maxPlayers > 0 and info.players >= info.maxPlayers,
        whitelist = info.whitelist,
        applications = info.whitelist and CONFIG.whitelist.applications,
        maintenance = maintenance,
        maintenanceMessage = maintenanceMessage,
        needDiscord = CONFIG.discord.required,
        rulesTitle = CONFIG.rules.title,
    })
    withList(data, "announcements", lines)
    withList(data, "rules", (CONFIG.rules.enabled and CONFIG.welcome.showRules) and CONFIG.rules.items or {})
    merge(data, welcomeExtra)
    local ok, reason = preflight.welcome(screenView("welcome", data))
    if not ok and CONFIG.ui.documents.welcome then
        warnOnce(("your welcome screen (%s) was not published (%s); the shipped one is used")
            :format(CONFIG.ui.documents.welcome, tostring(reason)))
        ok, reason = preflight.welcome(screenView("welcome", data, true))
    end
    if ok then
        welcomeSignature = signature
    else
        print("the welcome screen was not published: " .. tostring(reason))
    end
end

-- ------------------------------------------------------------------ refusal pages

-- A full refusal page. `message` is also the launcher's own verdict line, so the
-- player reads it even on a launcher that shows no view. For a door-list refusal
-- leave `code` nil: the server keeps the door's own code (banned, not_whitelisted).
local function refusePage(session, kind, title, message, code, extra)
    local stage = stages[session.id]
    local info = serverInfo(session)
    local data = linkData({
        kind = kind,
        title = title,
        message = message,
        server = info.name,
        userId = session.player.userId,
        name = session.player.name,
        appeal = CONFIG.appealLink or CONFIG.discordLink or "",
        hasAppeal = (CONFIG.appealLink or CONFIG.discordLink) ~= nil,
    })
    for key, value in pairs(extra or {}) do data[key] = value end
    data = decorate("refused", session, data)
    -- The provider may have taken a moment: a newer step (a ban, an approval) wins.
    if stages[session.id] ~= stage or not session:alive() then return end
    local ok, reason = session:refuse(message, { code = code, view = screenView("refused", data) })
    if not ok and not gone(reason) and CONFIG.ui.documents.refused then
        warnOnce(("your refused screen (%s) was not shown (%s); the shipped one is used")
            :format(CONFIG.ui.documents.refused, tostring(reason)))
        ok, reason = session:refuse(message, { code = code, view = screenView("refused", data, true) })
    end
    if not ok and not gone(reason) then
        -- A page that cannot be shown must not leave the player without an answer.
        print(("refusal page not shown (%s); %s gets the plain message"):format(tostring(reason), session.player.name))
        session:refuse(message, { code = code })
    end
end
Preflight.refusePage = refusePage

local function banPage(session, message, details)
    local reason = CONFIG.bans.showReason and text(details.reason, "") or ""
    refusePage(session, "banned", "You are banned", message, nil, {
        reason = reason,
        hasReason = reason ~= "",
        permanent = details.permanent == true,
        expires = text(details.expiresText, ""),
        hasExpiry = details.permanent ~= true and text(details.expiresText, "") ~= "",
        staff = CONFIG.bans.showStaff and text(details.bannedBy, "") or "",
        hasStaff = CONFIG.bans.showStaff and text(details.bannedBy, "") ~= "",
    })
end

-- ------------------------------------------------------------------ whitelist application

local function clean(value, limit)
    local result = tostring(value or ""):gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if #result > limit then result = result:sub(1, limit) end
    return result
end

-- userId (lower) -> { count, untilUnix }: wrong invite codes typed lately.
local codeFailures = {}

local function showApplication(session, stage, message, request)
    local pending = type(request) == "table" and request.status == "pending"
    local denied = type(request) == "table" and request.status == "denied"
    local info = serverInfo(session)
    local data = linkData({
        server = info.name,
        name = session.player.name,
        userId = session.player.userId,
        prompt = CONFIG.whitelist.prompt,
        pending = pending,
        denied = denied,
        note = denied and text(request.note, "") or "",
        hasNote = denied and text(request.note, "") ~= "",
        sent = pending and text(request.message, "") or "",
        askCode = next(CONFIG.whitelist.inviteCodes) ~= nil,
        error = "",
    })
    data = decorate("apply", session, data)
    if not current(session, stage) then return end
    local ok, reason = present(session, "apply", data)
    if not ok then
        print(("application form not shown (%s); %s gets the plain refusal"):format(tostring(reason), session.player.name))
        session:refuse(message)
        return
    end
    session:status(pending and "Your application is waiting for the staff." or "This server is whitelisted.")
    -- Wait for the player, or for the staff: an approval sends the session to onPreflight.
    session:hold()

    session:on("apply", function(_, inputs)
        if not current(session, stage) then return end
        local userId, name = session.player.userId, session.player.name
        local code = clean(inputs.code, 64):upper()
        if code ~= "" then
            -- Five wrong codes lock the account out of the code field for ten minutes:
            -- a code is a password, and this form is reachable by anybody with an account.
            local key, now = tostring(userId):lower(), GetUnixTime()
            local failures = codeFailures[key]
            if failures and now >= failures.untilUnix then
                failures = nil
                codeFailures[key] = nil
            end
            if failures and failures.count >= 5 then
                session:data({ error = "Too many wrong invite codes. Try again in a few minutes, or send an application." })
                return
            end
            if not CONFIG.whitelist.inviteCodes[code] then
                codeFailures[key] = { count = (failures and failures.count or 0) + 1, untilUnix = now + 600 }
                session:data({ error = "That invite code is not valid." })
                return
            end
            codeFailures[key] = nil
            local allowed, why = access.allow(userId, name, "invite code")
            if allowed ~= true then
                session:data({ error = "The server could not save your access (" .. tostring(why) .. "). Try again." })
                return
            end
            print(("%s (%s) whitelisted with an invite code"):format(name, userId))
            session:status("Invite code accepted.")
            return -- the door list changed: the server sends this session on to onPreflight
        end
        local application = clean(inputs.application, 300)
        if #application < CONFIG.whitelist.minLength then
            session:data({ error = ("Write at least %d characters."):format(CONFIG.whitelist.minLength) })
            return
        end
        local filed, why = access.request(userId, name, application)
        if filed ~= true then
            session:data({ error = why == "requests_full"
                and "The staff has too many applications waiting. Try again later."
                or "The server could not save your application. Try again." })
            return
        end
        print(("whitelist application from %s (%s)"):format(name, userId))
        -- The request is on file: the server presents this refusal again, now as pending.
        session:data({ pending = true, denied = false, sent = application, error = "" })
        session:status("Your application is waiting for the staff.")
    end)

    session:on("withdraw", function()
        if not current(session, stage) then return end
        access.forgetRequest(session.player.userId)
    end)
end

AddEventHandler("onPreflightRefused", function(session, code, message, details)
    local stage = enter(session)
    details = type(details) == "table" and details or {}
    if code == "banned" then
        banPage(session, message, details)
        return
    end
    if code == "not_whitelisted" then
        local request = type(details.request) == "table" and details.request or nil
        local denied = request ~= nil and request.status == "denied"
        if CONFIG.whitelist.applications and not (denied and not CONFIG.whitelist.reapply) then
            showApplication(session, stage, message, request)
            return
        end
        refusePage(session, "whitelist", denied and "Application denied" or "Whitelisted server", message, nil, {
            note = denied and text(request.note, "") or "",
            hasNote = denied and text(request.note, "") ~= "",
        })
        return
    end
    -- A door-list code this version does not know: the server's sentence, on a page.
    refusePage(session, "refused", "Access refused", message, nil)
end)

-- ------------------------------------------------------------------ the steps past the door

-- `{key}` in a template: the text or number `values[key]`; anything else stays as written.
local function fill(template, values)
    return (template:gsub("{([%w_]+)}", function(key)
        local value = values[key]
        if type(value) == "string" or type(value) == "number" then return tostring(value) end
        return nil
    end))
end

-- The player passed every step. With greeting.enabled they first see the greeting
-- screen for greeting.seconds (or until they press its button); then allowed, with
-- allowedMessage as the launcher's line.
local function finish(session, stage)
    local info = serverInfo(session)
    local data = linkData({
        server = info.name,
        name = session.player.name,
        players = info.players,
        maxPlayers = info.maxPlayers,
        seconds = CONFIG.greeting.seconds,
    })
    local extra = nil
    if CONFIG.greeting.enabled or CONFIG.ui.provider then
        data, extra = decorate(CONFIG.greeting.enabled and "greeting" or "allowed", session, data)
        if stage and not current(session, stage) then return end
    end
    -- The provider may word the line itself (allowedMessage), e.g. per character.
    local template = CONFIG.allowedMessage
    if type(extra) == "table" and type(extra.allowedMessage) == "string" then template = extra.allowedMessage end
    local message = fill(template, data)
    if CONFIG.greeting.enabled and stage then
        data.message = message
        -- `left`: whole seconds before the game starts (counts down; 0 with seconds = 0).
        local left = math.ceil(CONFIG.greeting.seconds)
        data.left = left
        data.counting = left > 0
        if present(session, "greeting", data) then
            session:status(nil)
            session:hold()
            local go = false
            session:on("enter", function()
                if current(session, stage) then go = true end
            end)
            -- 0 seconds: the greeting waits for the button.
            local deadline = CONFIG.greeting.seconds > 0 and GetGameTimer() + CONFIG.greeting.seconds * 1000 or nil
            while not go and (deadline == nil or GetGameTimer() < deadline) do
                Wait(100)
                if not current(session, stage) then return end
                if deadline then
                    local now = math.max(0, math.ceil((deadline - GetGameTimer()) / 1000))
                    if now ~= left then
                        left = now
                        session:data({ left = left })
                    end
                end
            end
            if not current(session, stage) then return end
        end
    end
    session:hide()
    session:status(nil) -- the line of the last step ("Read and accept the rules") is over
    session:allow(message ~= "" and message or nil)
end

local proceed

local function showRules(session, stage)
    local info = serverInfo(session)
    local data = linkData({
        server = info.name,
        name = session.player.name,
        title = CONFIG.rules.title,
        rules = CONFIG.rules.items,
        version = store.version(),
        checkbox = CONFIG.rules.checkbox,
        error = "",
    })
    withList(data, "announcements", announcements())
    data = decorate("rules", session, data)
    if not current(session, stage) then return end
    local ok, reason = present(session, "rules", data)
    if not ok then
        -- A screen that cannot be shown must not strand the player: let them in.
        print(("rules screen not shown (%s); allowing %s"):format(tostring(reason), session.player.name))
        finish(session, stage)
        return
    end
    session:status("Read and accept the rules to join.")
    session:hold()

    session:on("accept_rules", function(_, inputs)
        if not current(session, stage) then return end
        -- A checkbox arrives as a boolean; older launchers sent "true" or "on".
        local agreed = inputs.agree == true or inputs.agree == "true" or inputs.agree == "on"
        if CONFIG.rules.checkbox and not agreed then
            session:data({ error = "Tick the box to accept the rules." })
            return
        end
        store.accept(session.player.userId)
        proceed(session, "rules")
    end)

    session:on("decline_rules", function()
        if not current(session, stage) then return end
        refusePage(session, "rules", "Rules declined", "You need to accept the rules to play on this server.", "rules_declined")
    end)
end

-- Holds the player on a waiting screen while the server is full. True when the
-- session may go on (a slot freed, or the player chose to try anyway).
local function waitForSlot(session, stage, info)
    local skip = false
    local data = decorate("full", session, linkData({
        server = info.name, name = session.player.name, message = CONFIG.full.message,
        players = info.players, maxPlayers = info.maxPlayers,
    }))
    if not current(session, stage) then return false end
    local ok = present(session, "full", data)
    if not ok then return true end
    session:status("The server is full.")
    session:hold()
    session:on("try_anyway", function() skip = true end)
    while current(session, stage) do
        Wait(1000)
        if not current(session, stage) then return false end
        local now = serverInfo(session)
        if skip or now.maxPlayers <= 0 or now.players < now.maxPlayers then
            session:hide()
            return true
        end
        if now.players ~= info.players or now.maxPlayers ~= info.maxPlayers then
            info = now
            session:data({ players = now.players, maxPlayers = now.maxPlayers })
        end
    end
    return false
end

-- `after` names the step that just completed, so it is not asked twice.
proceed = function(session, after)
    local stage = enter(session)
    local player = session.player
    local userId = tostring(player.userId):lower()

    local kick = kicks[userId]
    if kick then
        if GetUnixTime() < kick.untilUnix then
            refusePage(session, "kicked", "You were kicked", kick.message, "kicked")
            return
        end
        kicks[userId] = nil
    end

    local maintenance, maintenanceMessage = Preflight.maintenance()
    if maintenance and not CONFIG.maintenance.allow[userId]
        and not (CONFIG.maintenance.allowWhitelisted and access.isAllowed(player.userId) == true) then
        refusePage(session, "maintenance", "Maintenance", maintenanceMessage, "maintenance")
        return
    end

    if CONFIG.discord.required and not player.discord then
        -- No ticket at all: the launcher could not prove anything (too old, or the
        -- master was unreachable); a ticket without `discord`: no account is linked.
        refusePage(session, "discord", "Discord account required", CONFIG.discord.message, "discord_required", {
            noTicket = player.ticket ~= true,
        })
        return
    end

    if CONFIG.full.mode ~= "off" and after ~= "full" and after ~= "rules" then
        local info = serverInfo(session)
        if info.maxPlayers > 0 and info.players >= info.maxPlayers then
            if CONFIG.full.mode == "refuse" then
                refusePage(session, "full", "Server full",
                    ("The server is full (%d / %d). Try again in a moment."):format(info.players, info.maxPlayers), "server_full")
                return
            end
            if not waitForSlot(session, stage, info) then return end
        end
    end

    if CONFIG.rules.enabled and not store.accepted(player.userId) then
        showRules(session, stage)
        return
    end

    finish(session, stage)
end

AddEventHandler("onPreflight", function(session)
    proceed(session)
end)

AddEventHandler("onPreflightEnd", function(session, reason)
    stages[session.id] = nil
    if reason == "refused" or reason == "allowed" then return end
    print(("%s (%s): server check %s"):format(session.player.name, session.player.userId, reason))
end)

-- ------------------------------------------------------------------ the door list changed

-- The server itself re-checks the open sessions (a ban lands on a player who is on the
-- launcher's screen; an approval lets a waiting one through): nothing to do for them
-- here. Only the welcome screen shows the whitelist switch.
AddEventHandler("onAccessChanged", function(_, change)
    if change == "whitelist_on" or change == "whitelist_off" then Preflight.publishWelcome() end
end)

-- ------------------------------------------------------------------ kick

-- Removes a player now and tells them why at their next server check. `target` is a
-- player id (number) or an account id (GUID string). Returns the account id, or nil, reason.
function Preflight.kick(target, message)
    local userId
    if type(target) == "number" then
        local identity = Open77.players.identity(target)
        userId = type(identity) == "table" and identity.userId or nil
        if not userId then return nil, "player_not_found" end
    elseif type(target) == "string" and target:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") then
        userId = target
    else
        return nil, "invalid_target"
    end
    userId = userId:lower()
    message = clean(message, 300)
    if message == "" then message = "You were kicked from the server." end
    if CONFIG.kickSeconds > 0 then
        kicks[userId] = { message = message, untilUnix = GetUnixTime() + CONFIG.kickSeconds }
    end
    -- In game: every seat this account holds. The reason travels in one packet (127 bytes).
    local reason = message
    if #reason > 120 then
        local cut = 117
        -- Never cut a UTF-8 character in half.
        while cut > 0 and (reason:byte(cut + 1) or 0) >= 0x80 and (reason:byte(cut + 1) or 0) < 0xC0 do cut = cut - 1 end
        reason = reason:sub(1, cut) .. "..."
    end
    for _, playerId in ipairs(Open77.players.all() or {}) do
        local identity = Open77.players.identity(playerId)
        if type(identity) == "table" and tostring(identity.userId):lower() == userId then
            Open77.players.kick(playerId, reason)
        end
    end
    -- On the launcher's screen: the open check ends with the same words.
    if owner then
        local session = preflight.find(userId)
        if type(session) == "table" and session:alive() then
            enter(session)
            -- In a thread: the page may wait for ui.provider, and an export caller cannot wait.
            CreateThread(function()
                refusePage(session, "kicked", "You were kicked", message, "kicked")
            end)
        end
    end
    return userId
end

-- ------------------------------------------------------------------ console

RegisterCommand("preflight.status", function()
    local status = preflight.status()
    local state = access.status()
    local maintenance = Preflight.maintenance()
    local pending = 0
    if type(state) == "table" then
        for _, request in ipairs(state.requests or {}) do
            if request.status == "pending" then pending = pending + 1 end
        end
    end
    if type(status) ~= "table" then
        print(("not the preflight owner; whitelist=%s pending requests=%d maintenance=%s")
            :format(tostring(type(state) == "table" and state.whitelistEnabled), pending, tostring(maintenance)))
        return
    end
    print(("owner=%s required=%s sessions=%d interactive=%d passes=%d allowed=%d refused=%d | whitelist=%s pending requests=%d " ..
        "maintenance=%s rules=%s (version %s)"):format(status.resource, tostring(status.required), status.sessions, status.interactive,
        status.passes, status.counters.allowed, status.counters.refused,
        tostring(type(state) == "table" and state.whitelistEnabled), pending, tostring(maintenance),
        tostring(CONFIG.rules.enabled), store.version()))
end, true)

function Preflight.setMaintenance(mode, message)
    if mode == "default" then
        store.set("maintenance", nil)
        store.set("maintenance.message", nil)
    else
        store.set("maintenance", mode and "on" or "off")
        message = clean(message, 300)
        if message ~= "" then store.set("maintenance.message", message)
        elseif not mode then store.set("maintenance.message", nil) end
    end
    Preflight.publishWelcome()
    return Preflight.maintenance()
end

RegisterCommand("preflight.maintenance", function(_, args)
    local what = tostring(args[1] or ""):lower()
    if what == "on" or what == "off" or what == "default" then
        Preflight.setMaintenance(what == "default" and "default" or what == "on", table.concat(args, " ", 2))
    elseif what ~= "" then
        print("usage: preflight.maintenance on [message] | off | default")
        return
    end
    local enabled, message = Preflight.maintenance()
    print(("maintenance %s%s"):format(enabled and "ON" or "off", enabled and (": " .. message) or ""))
end, true)

RegisterCommand("preflight.announce", function(_, args)
    local line = clean(table.concat(args, " "), 200)
    if line == "" then
        print("usage: preflight.announce <text> | clear")
        return
    end
    store.set("announcement", line:lower() ~= "clear" and line or nil)
    Preflight.publishWelcome()
    if owner then preflight.broadcast({ notice = line:lower() ~= "clear" and line or "" }) end
    print(line:lower() == "clear" and "announcement cleared" or ("announcement: " .. line))
end, true)

RegisterCommand("preflight.rules.reset", function(_, args)
    local count = store.reset(args[1])
    print(args[1] and (count == 1 and "this player will be asked to accept the rules again" or "this player had not accepted the rules")
        or ("every player will be asked to accept the rules again (" .. count .. " bucket(s) cleared)"))
end, true)

-- ------------------------------------------------------------------ start

Preflight.publishWelcome(true)
if owner then
    -- The player count on the welcome screen: checked now and then, republished only
    -- when it changed.
    -- The provider's welcome values (ui.provider) are asked here, and once right away:
    -- it cannot be called while this file loads.
    CreateThread(function()
        if CONFIG.ui.provider then
            Wait(1000)
            Preflight.publishWelcome(false, true)
        end
        while true do
            Wait(15000)
            Preflight.publishWelcome(false, true)
        end
    end)
    local custom = {}
    for _, screen in ipairs(SCREENS) do
        if CONFIG.ui.documents[screen] then custom[#custom + 1] = screen end
    end
    print(("server check ready: rules=%s discord=%s applications=%s full=%s maintenance=%s greeting=%s screens=%s provider=%s")
        :format(tostring(CONFIG.rules.enabled), tostring(CONFIG.discord.required), tostring(CONFIG.whitelist.applications),
            CONFIG.full.mode, tostring((Preflight.maintenance())), tostring(CONFIG.greeting.enabled),
            #custom > 0 and table.concat(custom, ",") or "shipped", CONFIG.ui.provider or "none"))
end
