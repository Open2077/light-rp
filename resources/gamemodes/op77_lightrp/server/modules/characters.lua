-- Characters: the persistent identity of a player.
--
-- One account (the Master identity, GetPlayerIdentifier) owns up to
-- Config.characters.maxSlots characters, each keyed by a `character_key` that is
-- also the key open77_appearance and open77_wardrobe persist under. The body and
-- the face belong to open77_appearance (native creator on first join, `/appearance`
-- later); the clothes to open77_wardrobe; this module owns everything else:
--
--   civil state   first/last name, birth date, origin, short story
--   workflow      status draft -> active, and which step is still missing
--   memory        last position, needs, playtime, appearance revision
--   slots         select / create / archive, through open77:appearance:setCharacter
--
-- The creation wizard in the page is driven by the `character` state key; every
-- step is an action validated here.
local Config = LightRpConfig
local CC = Config.characters
local Db = LightRP.db

local characters = {} -- playerId -> current character table (see load)
local Characters = LightRP.module("characters", {})
Characters.byPlayer = characters

Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_accounts (
        identifier    VARCHAR(64) NOT NULL PRIMARY KEY,
        account_name  VARCHAR(64) NOT NULL DEFAULT '',
        active_key    VARCHAR(64) NOT NULL DEFAULT 'default',
        created_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_seen     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
        welcome_seen_at TIMESTAMP NULL
    )
]])
-- v2 of the character table: one row per (account, slot). The v1 table (one row
-- per account, no slot) is renamed away on first start, see migrate().
Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_characters (
        identifier     VARCHAR(64) NOT NULL,
        character_key  VARCHAR(64) NOT NULL DEFAULT 'default',
        status         VARCHAR(16) NOT NULL DEFAULT 'draft',
        first_name     VARCHAR(32) NULL,
        last_name      VARCHAR(32) NULL,
        birth_date     DATE        NULL,
        origin         VARCHAR(32) NULL,
        story          VARCHAR(600) NULL,
        body_family    VARCHAR(8)  NULL,
        appearance_rev BIGINT      NOT NULL DEFAULT 0,
        appearance_at  TIMESTAMP   NULL,
        last_x         DOUBLE      NULL,
        last_y         DOUBLE      NULL,
        last_z         DOUBLE      NULL,
        last_heading   DOUBLE      NULL,
        food           DOUBLE      NOT NULL DEFAULT 100,
        drink          DOUBLE      NOT NULL DEFAULT 100,
        playtime_ms    BIGINT      NOT NULL DEFAULT 0,
        job            VARCHAR(32) NOT NULL DEFAULT 'unemployed',
        job_grade      INT         NOT NULL DEFAULT 0,
        gang           VARCHAR(32) NOT NULL DEFAULT 'none',
        gang_grade     INT         NOT NULL DEFAULT 0,
        created_at     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_seen      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (identifier, character_key)
    )
]])

-- ---------------------------------------------------------------------------
-- Helpers

local function validName(value)
    if type(value) ~= "string" then return false end
    local length = utf8.len(value)
    if length == nil or length < Config.names.minLength or length > Config.names.maxLength then return false end
    for _, code in utf8.codes(value) do
        local letter = (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
        local punctuation = code == 32 or code == 45 or code == 39
        local accented = Config.names.allowAccents and code >= 0xC0 and code <= 0x24F
        if not (letter or punctuation or accented) then return false end
    end
    return value:sub(1, 1) ~= " " and value:sub(-1) ~= " "
end
Characters.validName = validName

local function titleCase(value) return (value:gsub("^%l", string.upper)) end

-- "YYYY-MM-DD", plausible, and old enough. Returns the normalised string or nil.
local function validBirthDate(value)
    local y, m, d = tostring(value or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if not y then return nil end
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if m < 1 or m > 12 or d < 1 or d > 31 then return nil end
    local leap = y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)
    local days = { 31, leap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if d > days[m] then return nil end
    -- Night City lives in 2077; the calendar is the game's.
    local age = CC.currentYear - y
    if age < CC.minAge or age > CC.maxAge then return nil end
    return string.format("%04d-%02d-%02d", y, m, d)
end

local originByKey = {}
for _, origin in ipairs(CC.origins) do originByKey[origin.key] = origin end

local function slotKey(index)
    return index == 1 and "default" or ("slot" .. tostring(index))
end

local function validKey(value)
    value = tostring(value or "")
    if value == "default" then return value end
    local n = tonumber(value:match("^slot(%d+)$") or "")
    if n and n >= 2 and n <= CC.maxSlots then return value end
    return nil
end

-- ---------------------------------------------------------------------------
-- Reads

function Characters.get(playerId) return characters[playerId] end

function Characters.isRegistered(playerId)
    local c = characters[playerId]
    return c ~= nil and c.status == "active"
end

function Characters.hasName(playerId)
    local c = characters[playerId]
    return c ~= nil and c.firstName ~= nil
end

function Characters.displayName(playerId)
    local c = characters[playerId]
    if c and c.firstName then return c.firstName .. " " .. c.lastName end
    return GetPlayerName(playerId) or ("Joueur " .. tostring(playerId))
end

-- What the appearance package knows for this account/key (same database).
local function appearanceRow(identifier, key)
    if not Db.ready then return nil end
    return Db.single([[
        SELECT c.body_family, c.status, a.revision, a.updated_at
        FROM open77_characters c
        LEFT JOIN open77_player_appearances a ON a.user_id = c.user_id AND a.character_key = c.character_key
        WHERE c.user_id = ? AND c.character_key = ?
    ]], { identifier, key })
end

-- The wizard step still missing, in order: identity, appearance, done.
local function nextStep(c)
    if c.firstName == nil then return "identity" end
    if Db.ready and c.bodyFamily == nil then return "appearance" end
    if c.status ~= "active" then return "confirm" end
    return "done"
end

-- ---------------------------------------------------------------------------
-- Load / save

local function emptyCharacter(playerId, identifier, key)
    return {
        identifier = identifier, key = key,
        accountName = GetPlayerName(playerId) or ("Player " .. tostring(playerId)),
        status = "draft", joinedAtMs = LightRP.nowMs(), playtimeMs = 0, food = 100, drink = 100,
        appearanceRevision = 0,
    }
end

local function migrate()
    -- v1 table: no character_key column. Keep the data aside, never silently drop it.
    local column = Db.single([[SELECT COUNT(*) AS n FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'lightrp_characters' AND COLUMN_NAME = 'character_key']])
    local exists = Db.single([[SELECT COUNT(*) AS n FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'lightrp_characters']])
    if exists and tonumber(exists.n) == 1 and column and tonumber(column.n) == 0 then
        Db.run("RENAME TABLE lightrp_characters TO lightrp_characters_v1")
        LightRP.log("migrated: legacy lightrp_characters kept as lightrp_characters_v1")
        for _, sql in ipairs(Db.pending) do Db.run(sql) end
    end
    -- Accounts created before the first-spawn briefing existed.
    local welcome = Db.single([[SELECT COUNT(*) AS n FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'lightrp_accounts' AND COLUMN_NAME = 'welcome_seen_at']])
    if welcome and tonumber(welcome.n) == 0 then
        Db.run("ALTER TABLE lightrp_accounts ADD COLUMN welcome_seen_at TIMESTAMP NULL")
        LightRP.log("migrated: lightrp_accounts.welcome_seen_at added")
    end
    -- Characters created before jobs and gangs existed.
    for column, ddl in pairs({ job = "VARCHAR(32) NOT NULL DEFAULT 'unemployed'", job_grade = "INT NOT NULL DEFAULT 0",
                               gang = "VARCHAR(32) NOT NULL DEFAULT 'none'", gang_grade = "INT NOT NULL DEFAULT 0" }) do
        local present = Db.single(string.format([[SELECT COUNT(*) AS n FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'lightrp_characters' AND COLUMN_NAME = '%s']], column))
        if present and tonumber(present.n) == 0 then
            Db.run(string.format("ALTER TABLE lightrp_characters ADD COLUMN %s %s", column, ddl))
            LightRP.log("migrated: lightrp_characters.%s added", column)
        end
    end
end

local function loadSlots(identifier)
    local rows = Db.query([[SELECT character_key, status, first_name, last_name, body_family, playtime_ms, last_seen
        FROM lightrp_characters WHERE identifier = ? AND status <> 'archived' ORDER BY created_at]], { identifier })
    local slots = {}
    for _, row in ipairs(rows) do
        slots[#slots + 1] = {
            key = row.character_key, status = row.status,
            name = row.first_name and (row.first_name .. " " .. row.last_name) or nil,
            bodyFamily = row.body_family, playtimeMs = tonumber(row.playtime_ms) or 0,
            lastSeen = row.last_seen and tostring(row.last_seen) or nil,
        }
    end
    return slots
end

local function load(playerId, key)
    local identifier = GetPlayerIdentifier(playerId)
    if not Db.ready or identifier == nil then
        local c = emptyCharacter(playerId, identifier, key or "default")
        characters[playerId] = c
        LightRP.eachModule("onCharacterLoaded", playerId, c)
        return c
    end
    Db.run([[INSERT INTO lightrp_accounts (identifier, account_name) VALUES (?, ?)
             ON DUPLICATE KEY UPDATE account_name = VALUES(account_name), last_seen = CURRENT_TIMESTAMP]],
        { identifier, GetPlayerName(playerId) or "" })
    local account = Db.single("SELECT active_key, welcome_seen_at FROM lightrp_accounts WHERE identifier = ?", { identifier })
    key = key or (account and account.active_key) or "default"
    local c = emptyCharacter(playerId, identifier, key)
    c.welcomeSeen = account ~= nil and account.welcome_seen_at ~= nil
    characters[playerId] = c
    local row = Db.single([[SELECT status, first_name, last_name, birth_date, origin, story, body_family, appearance_rev, appearance_at,
        last_x, last_y, last_z, last_heading, food, drink, playtime_ms, job, job_grade, gang, gang_grade
        FROM lightrp_characters WHERE identifier = ? AND character_key = ?]],
        { identifier, key })
    if row then
        c.status = row.status or "draft"
        c.firstName, c.lastName = row.first_name, row.last_name
        c.birthDate = row.birth_date and tostring(row.birth_date):sub(1, 10) or nil
        c.origin, c.story = row.origin, row.story
        c.bodyFamily = row.body_family
        c.appearanceRevision = tonumber(row.appearance_rev) or 0
        c.appearanceSavedAt = row.appearance_at and tostring(row.appearance_at) or nil
        if row.last_x ~= nil and row.last_y ~= nil and row.last_z ~= nil then
            c.position = { x = row.last_x, y = row.last_y, z = row.last_z }
            c.heading = row.last_heading or 0
        end
        c.food, c.drink = tonumber(row.food) or 100, tonumber(row.drink) or 100
        c.playtimeMs = tonumber(row.playtime_ms) or 0
        c.job, c.jobGrade = row.job or "unemployed", tonumber(row.job_grade) or 0
        c.gang, c.gangGrade = row.gang or "none", tonumber(row.gang_grade) or 0
    end
    -- The appearance package is the authority on the body: pick up what it has,
    -- including a first character created before this module ran.
    local appearance = appearanceRow(identifier, key)
    if appearance and appearance.status == "active" then
        c.bodyFamily = appearance.body_family
        c.appearanceRevision = tonumber(appearance.revision) or c.appearanceRevision
        if appearance.updated_at then c.appearanceSavedAt = tostring(appearance.updated_at) end
    end
    c.slots = loadSlots(identifier)
    LightRP.eachModule("onCharacterLoaded", playerId, c)
    return c
end

local function persistCivil(c)
    if not Db.ready or c.identifier == nil then return end
    -- The bridge refuses a positional array with holes, so optional columns travel
    -- as "" and become NULL in SQL.
    Db.run([[INSERT INTO lightrp_characters (identifier, character_key, status, first_name, last_name, birth_date, origin, story, body_family, appearance_rev)
             VALUES (?, ?, ?, NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), NULLIF(?, ''), ?)
             ON DUPLICATE KEY UPDATE status = VALUES(status), first_name = VALUES(first_name), last_name = VALUES(last_name),
                 birth_date = VALUES(birth_date), origin = VALUES(origin), story = VALUES(story),
                 body_family = COALESCE(VALUES(body_family), body_family), appearance_rev = GREATEST(appearance_rev, VALUES(appearance_rev))]],
        { c.identifier, c.key, c.status, c.firstName or "", c.lastName or "", c.birthDate or "", c.origin or "", c.story or "", c.bodyFamily or "", c.appearanceRevision or 0 })
end

local function save(playerId)
    local c = characters[playerId]
    if c == nil or not Db.ready or c.identifier == nil or c.firstName == nil then return end
    local now = LightRP.nowMs()
    local playtime = now - (c.joinedAtMs or now)
    c.joinedAtMs = now
    c.playtimeMs = (c.playtimeMs or 0) + playtime
    local last = c.lastKnown
    if last then
        Db.run([[UPDATE lightrp_characters SET playtime_ms = playtime_ms + ?, last_seen = CURRENT_TIMESTAMP,
                 last_x = ?, last_y = ?, last_z = ?, food = ?, drink = ? WHERE identifier = ? AND character_key = ?]],
            { playtime, last.x, last.y, last.z, c.food or 100, c.drink or 100, c.identifier, c.key })
    else
        Db.run([[UPDATE lightrp_characters SET playtime_ms = playtime_ms + ?, last_seen = CURRENT_TIMESTAMP, food = ?, drink = ?
                 WHERE identifier = ? AND character_key = ?]], { playtime, c.food or 100, c.drink or 100, c.identifier, c.key })
    end
end

function Characters.samplePosition(playerId)
    local c = characters[playerId]
    if c == nil then return end
    local position = Open77.players.position(playerId)
    if position then c.lastKnown = { x = position.x, y = position.y, z = position.z } end
end

-- ---------------------------------------------------------------------------
-- Workflow

-- Step 1: civil state. Creates the draft or edits an existing character.
function Characters.setIdentity(playerId, fields)
    local c = characters[playerId] or load(playerId)
    local first = titleCase(tostring(fields.firstName or ""))
    local last = titleCase(tostring(fields.lastName or ""))
    if not validName(first) or not validName(last) then return false, "invalid_name" end
    local birth = fields.birthDate ~= nil and fields.birthDate ~= "" and validBirthDate(fields.birthDate) or nil
    if fields.birthDate ~= nil and fields.birthDate ~= "" and birth == nil then return false, "invalid_birth_date" end
    local origin = fields.origin ~= nil and fields.origin ~= "" and originByKey[tostring(fields.origin)] and tostring(fields.origin) or nil
    if fields.origin ~= nil and fields.origin ~= "" and origin == nil then return false, "invalid_origin" end
    local story = fields.story ~= nil and tostring(fields.story) or nil
    if story then
        if utf8.len(story) == nil then return false, "invalid_story" end
        local boundary = utf8.offset(story, 601)
        if boundary then story = story:sub(1, boundary - 1) end
    end
    if story == "" then story = nil end
    c.firstName, c.lastName, c.birthDate, c.origin, c.story = first, last, birth, origin, story
    persistCivil(c)
    c.slots = c.identifier and Db.ready and loadSlots(c.identifier) or c.slots
    LightRP.state(playerId, { "character", "online" })
    return true
end

-- Step 3: the player confirms. The body must exist when persistence is on.
function Characters.finish(playerId)
    local c = characters[playerId]
    if c == nil or c.firstName == nil then return false, "identity_missing" end
    if Db.ready then
        local appearance = appearanceRow(c.identifier, c.key)
        if appearance == nil or appearance.status ~= "active" then return false, "appearance_missing" end
        c.bodyFamily = appearance.body_family
        c.appearanceRevision = tonumber(appearance.revision) or 0
    end
    local wasActive = c.status == "active"
    c.status = "active"
    persistCivil(c)
    if Db.ready then
        Db.run("UPDATE lightrp_accounts SET active_key = ? WHERE identifier = ?", { c.key, c.identifier })
        c.slots = loadSlots(c.identifier)
    end
    LightRP.state(playerId, { "character", "online" })
    if not wasActive then LightRP.eachModule("onCharacterActivated", playerId, c) end
    return true
end

-- Slots: play another character, start a new one, archive one.
function Characters.select(playerId, key)
    key = validKey(key)
    if key == nil then return false, "invalid_slot" end
    local current = characters[playerId]
    if current == nil then return false, "not_loaded" end
    if current.key == key then return true end
    if not Db.ready then return false, "database_required" end
    save(playerId)
    local exists = Db.single("SELECT status FROM lightrp_characters WHERE identifier = ? AND character_key = ?", { current.identifier, key })
    if exists == nil or exists.status == "archived" then return false, "unknown_slot" end
    Db.run("UPDATE lightrp_accounts SET active_key = ? WHERE identifier = ?", { key, current.identifier })
    local c = load(playerId, key)
    -- The appearance and wardrobe packages follow: body, face and clothes of that slot.
    TriggerEvent("open77:appearance:setCharacter", playerId, key)
    LightRP.state(playerId, { "character", "needs", "online" })
    LightRP.eachModule("onCharacterSwitched", playerId, c)
    return true
end

function Characters.startNew(playerId)
    local current = characters[playerId]
    if current == nil then return false, "not_loaded" end
    if not Db.ready then return false, "database_required" end
    local used = {}
    for _, slot in ipairs(loadSlots(current.identifier)) do used[slot.key] = true end
    local key
    for index = 1, CC.maxSlots do
        if not used[slotKey(index)] then key = slotKey(index) break end
    end
    if key == nil then return false, "no_free_slot" end
    save(playerId)
    Db.run("INSERT INTO lightrp_characters (identifier, character_key, status) VALUES (?, ?, 'draft')", { current.identifier, key })
    Db.run("UPDATE lightrp_accounts SET active_key = ? WHERE identifier = ?", { key, current.identifier })
    local c = load(playerId, key)
    TriggerEvent("open77:appearance:setCharacter", playerId, key)
    LightRP.state(playerId, { "character", "needs" })
    LightRP.eachModule("onCharacterSwitched", playerId, c)
    return true, key
end

function Characters.archive(playerId, key)
    key = validKey(key)
    local current = characters[playerId]
    if key == nil or current == nil then return false, "invalid_slot" end
    if current.key == key then return false, "slot_in_use" end
    if not Db.ready then return false, "database_required" end
    Db.run("UPDATE lightrp_characters SET status = 'archived' WHERE identifier = ? AND character_key = ?", { current.identifier, key })
    current.slots = loadSlots(current.identifier)
    LightRP.state(playerId, "character")
    return true
end

-- ---------------------------------------------------------------------------
-- The appearance package tells us when a body exists or changed (host-wide events).

AddEventHandler("open77:appearance:characterCreated", function(player, userId, key, family)
    local playerId = tonumber(player)
    local c = playerId and characters[playerId]
    if c == nil or c.key ~= tostring(key) then return end
    c.bodyFamily = tostring(family)
    c.appearanceRevision = 1
    persistCivil(c)
    if Db.ready then Db.run("UPDATE lightrp_characters SET appearance_at = CURRENT_TIMESTAMP WHERE identifier = ? AND character_key = ?", { c.identifier, c.key }) end
    LightRP.state(playerId, "character")
    LightRP.notice(playerId, { kind = "success", title = "Body saved", body = "Your appearance is stored. Finish your identity to enter the city." })
end)

AddEventHandler("open77:appearance:saved", function(player, userId, key, revision)
    local playerId = tonumber(player)
    local c = playerId and characters[playerId]
    if c == nil or c.key ~= tostring(key) then return end
    c.appearanceRevision = tonumber(revision) or c.appearanceRevision
    if Db.ready then
        Db.run("UPDATE lightrp_characters SET appearance_rev = ?, appearance_at = CURRENT_TIMESTAMP WHERE identifier = ? AND character_key = ?",
            { c.appearanceRevision, c.identifier, c.key })
    end
    LightRP.state(playerId, "character")
    LightRP.notice(playerId, { kind = "success", title = "Appearance saved", body = "Revision " .. tostring(c.appearanceRevision) .. "." })
end)

-- ---------------------------------------------------------------------------
-- State + lifecycle

LightRP.stateProvider("character", function(playerId)
    local c = characters[playerId] or {}
    local origins = {}
    for _, origin in ipairs(CC.origins) do origins[#origins + 1] = { key = origin.key, label = origin.label } end
    return {
        registered = c.status == "active",
        status = c.status or "draft",
        step = characters[playerId] and nextStep(c) or "identity",
        key = c.key or "default",
        firstName = c.firstName, lastName = c.lastName,
        birthDate = c.birthDate, origin = c.origin, story = c.story,
        bodyFamily = c.bodyFamily,
        appearanceRevision = c.appearanceRevision or 0,
        appearanceSavedAt = c.appearanceSavedAt,
        appearanceTracked = Db.ready,
        accountName = c.accountName or (GetPlayerName(playerId) or ""),
        playerId = playerId,
        userId = c.identifier,
        playtimeMs = (c.playtimeMs or 0) + (LightRP.nowMs() - (c.joinedAtMs or LightRP.nowMs())),
        slots = c.slots or {},
        maxSlots = CC.maxSlots,
        origins = origins,
        minAge = CC.minAge, maxAge = CC.maxAge, currentYear = CC.currentYear,
        nameMinLength = Config.names.minLength, nameMaxLength = Config.names.maxLength,
        nameAllowAccents = Config.names.allowAccents,
        -- First-spawn briefing: once per account, after the character is active.
        welcomePending = LightRpConfig.welcome.enabled and c.status == "active" and not c.welcomeSeen,
        welcomeReadSeconds = LightRpConfig.welcome.readSeconds or 15,
    }
end)

LightRP.stateProvider("online", function()
    local list = {}
    for _, id in ipairs(GetPlayers()) do list[#list + 1] = { id = id, name = Characters.displayName(id) } end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end)

function Characters.onDatabaseReady()
    migrate()
    for _, id in ipairs(GetPlayers()) do
        if characters[id] and characters[id].identifier and characters[id].firstName == nil then
            load(id)
            LightRP.state(id, { "character", "needs" })
        end
    end
end

function Characters.onConnected(playerId)
    CreateThread(function()
        load(playerId)
        LightRP.state(playerId, { "character", "needs" })
    end)
end

function Characters.onDisconnected(playerId)
    CreateThread(function()
        save(playerId)
        characters[playerId] = nil
        LightRP.broadcastState("online")
    end)
end

Characters.save = save

-- Position every 5 s (the disconnect hook cannot read a gone player), the row
-- every 60 s so a crash loses at most a minute of position and playtime.
CreateThread(function()
    local ticks = 0
    while true do
        Wait(5000)
        ticks = ticks + 1
        for playerId in pairs(characters) do Characters.samplePosition(playerId) end
        if ticks % 12 == 0 then
            for playerId, c in pairs(characters) do if c.status == "active" then save(playerId) end end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Actions (the wizard and the Personnage tab) + commands

local REASONS = {
    invalid_name = "Name refused: letters, hyphens and apostrophes, " .. Config.names.minLength .. " to " .. Config.names.maxLength .. " characters per word.",
    invalid_birth_date = string.format("Invalid birth date (YYYY-MM-DD, %d to %d years old in %d).", CC.minAge, CC.maxAge, CC.currentYear),
    invalid_origin = "Origine inconnue.",
    invalid_story = "Your backstory contains invalid text. Please enter it again.",
    identity_missing = "Fill in the identity first.",
    appearance_missing = "The body is not saved yet: open the mirror and confirm your appearance.",
    database_required = "This action needs the database.",
    invalid_slot = "Emplacement invalide.", unknown_slot = "Emplacement vide.", slot_in_use = "Ce personnage est en jeu.",
    no_free_slot = "All slots are taken.", not_loaded = "Character not loaded.",
}
local function explain(reason) return REASONS[reason] or ("Denied: " .. tostring(reason)) end

LightRP.action("character.identity", function(playerId, payload)
    local ok, reason = Characters.setIdentity(playerId, payload)
    if not ok then return LightRP.result(playerId, false, explain(reason), "character.identity") end
    LightRP.result(playerId, true, "Identity saved: " .. Characters.displayName(playerId), "character.identity")
end)

LightRP.action("register", function(playerId, payload) -- kept for the old page contract
    local ok, reason = Characters.setIdentity(playerId, payload)
    LightRP.result(playerId, ok, ok and ("Identity saved: " .. Characters.displayName(playerId)) or explain(reason), "register")
end)

LightRP.action("character.finish", function(playerId)
    local ok, reason = Characters.finish(playerId)
    if not ok then return LightRP.result(playerId, false, explain(reason), "character.finish") end
    LightRP.result(playerId, true, "Welcome to Night City, " .. Characters.displayName(playerId) .. ".", "character.finish")
end)

LightRP.action("character.select", function(playerId, payload)
    local ok, reason = Characters.select(playerId, payload.key)
    LightRP.result(playerId, ok, ok and ("Character loaded: " .. Characters.displayName(playerId)) or explain(reason), "character.select")
end)

LightRP.action("character.new", function(playerId)
    local ok, reason = Characters.startNew(playerId)
    LightRP.result(playerId, ok, ok and "New slot opened: create this character." or explain(reason), "character.new")
end)

LightRP.action("character.archive", function(playerId, payload)
    local ok, reason = Characters.archive(playerId, payload.key)
    LightRP.result(playerId, ok, ok and "Character archived." or explain(reason), "character.archive")
end)

-- Commands that step out of the roleplay are staff-only on this server; their
-- suggestions are pulled from the player's chat index once it is up.
local HIDDEN_SUGGESTIONS = { "/wardrobe", "/appearance", "/barber", "/gender", "/weather", "/weather.status", "/weather.time", "/vehicle.list", "/vehicle.damage.dump", "/elevator.list", "/clear", "/id" }
function Characters.onUiReady(playerId)
    SetTimeout(1500, function()
        if GetPlayerName(playerId) == nil or LightRP.staff.isStaff(playerId) then return end
        for _, command in ipairs(HIDDEN_SUGGESTIONS) do TriggerEvent("chat:removeSuggestion", playerId, command) end
    end)
end

-- The player closed the first-spawn briefing: never show it again on this account.
LightRP.action("welcome.ack", function(playerId)
    local c = characters[playerId]
    if c == nil then return end
    c.welcomeSeen = true
    if Db.ready and c.identifier then
        Db.run("UPDATE lightrp_accounts SET welcome_seen_at = CURRENT_TIMESTAMP WHERE identifier = ?", { c.identifier })
    end
    LightRP.state(playerId, "character")
end)

LightRP.command("register", { usage = "/register <FirstName> <LastName>" }, function(source, args)
    if args[1] == nil or args[2] == nil or (args.n or #args) > 2 then return false end
    local ok, reason = Characters.setIdentity(source, { firstName = args[1], lastName = args[2] })
    if not ok then return false, explain(reason) end
    local c = characters[source]
    return true, "Identity saved: " .. Characters.displayName(source) .. (c and c.status ~= "active" and " — finish the creation on screen." or "")
end)

-- A character handoff and a checkout must not race across yielding DB calls.
Characters.switching = {}
for _, method in ipairs({ "select", "startNew" }) do
    local original = Characters[method]
    Characters[method] = function(playerId, ...)
        if Characters.switching[playerId] or (LightRP.shops and LightRP.shops.isBusy(playerId)) then return false, "busy" end
        Characters.switching[playerId] = true
        local result = table.pack(pcall(original, playerId, ...))
        Characters.switching[playerId] = nil
        if not result[1] then error(result[2]) end
        return table.unpack(result, 2, result.n)
    end
end
