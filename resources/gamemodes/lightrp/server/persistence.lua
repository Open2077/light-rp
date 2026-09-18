-- Characters and their memory: the registered name, the last position, the
-- reports players file. Runs first, so the two other server scripts find the
-- LightRp table ready.
--
-- Persistence is optional at runtime. With the owner's MySQL bridge configured
-- (database.enabled + OP77_DATABASE_CONNECTION), characters survive restarts;
-- without it the resource still runs and everything lives for the session.
LightRp = LightRp or {}
local Config = LightRpConfig

local characters = {}     -- playerId -> { identifier, name, firstName, lastName, position, joinedAtMs }
LightRp.characters = characters

local databaseReady = false

local function log(format, ...)
    print("[lightrp] " .. string.format(format, ...))
end
LightRp.log = log

local function nowMs()
    return math.floor(Open77.time.monotonic() * 1000)
end
LightRp.nowMs = nowMs

function LightRp.hasDatabase()
    return databaseReady
end

-- ---------------------------------------------------------------------------
-- Names

-- Accepts letters (ASCII or accented), spaces, hyphens and apostrophes.
local function validName(value)
    if type(value) ~= "string" then return false end
    local length = utf8.len(value)
    if length == nil or length < Config.names.minLength or length > Config.names.maxLength then return false end
    for _, code in utf8.codes(value) do
        local ascii = code < 128
        local letter = (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
        local punctuation = code == 32 or code == 45 or code == 39
        local accented = Config.names.allowAccents and code >= 0xC0 and code <= 0x24F
        if not (letter or punctuation or (not ascii and accented)) then return false end
    end
    return value:sub(1, 1) ~= " " and value:sub(-1) ~= " "
end
LightRp.validName = validName

local function titleCase(value)
    return (value:gsub("^%l", string.upper))
end

-- What other players read: the character, or the account name until /register.
function LightRp.displayName(playerId)
    local character = characters[playerId]
    if character and character.firstName then
        return character.firstName .. " " .. character.lastName
    end
    return GetPlayerName(playerId) or ("Joueur " .. tostring(playerId))
end

function LightRp.isRegistered(playerId)
    local character = characters[playerId]
    return character ~= nil and character.firstName ~= nil
end

-- ---------------------------------------------------------------------------
-- Database

CreateThread(function()
    if type(MySQL) ~= "table" or type(MySQL.update) ~= "table" then
        log("no database bridge: characters are kept for this session only")
        return
    end
    local ok, err = pcall(function()
        MySQL.update.await([[
            CREATE TABLE IF NOT EXISTS lightrp_characters (
                identifier   VARCHAR(64)  NOT NULL PRIMARY KEY,
                account_name VARCHAR(64)  NOT NULL DEFAULT '',
                first_name   VARCHAR(32)  NULL,
                last_name    VARCHAR(32)  NULL,
                last_x       DOUBLE       NULL,
                last_y       DOUBLE       NULL,
                last_z       DOUBLE       NULL,
                last_heading DOUBLE       NULL,
                playtime_ms  BIGINT       NOT NULL DEFAULT 0,
                created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
                last_seen    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        ]])
        MySQL.update.await([[
            CREATE TABLE IF NOT EXISTS lightrp_reports (
                id           BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
                identifier   VARCHAR(64)  NOT NULL,
                reporter     VARCHAR(96)  NOT NULL,
                message      VARCHAR(512) NOT NULL,
                created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
                handled      TINYINT(1)   NOT NULL DEFAULT 0
            )
        ]])
    end)
    if ok then
        databaseReady = true
        log("persistence ready (lightrp_characters, lightrp_reports)")
    else
        log("persistence disabled: %s", tostring(err))
    end
end)

local function loadCharacter(playerId)
    local identifier = GetPlayerIdentifier(playerId)
    local character = {
        identifier = identifier,
        name = GetPlayerName(playerId) or ("Joueur " .. tostring(playerId)),
        joinedAtMs = nowMs(),
    }
    characters[playerId] = character
    if not databaseReady or identifier == nil then return character end
    local ok, err = pcall(function()
        MySQL.update.await([[
            INSERT INTO lightrp_characters (identifier, account_name)
            VALUES (?, ?)
            ON DUPLICATE KEY UPDATE account_name = VALUES(account_name), last_seen = CURRENT_TIMESTAMP
        ]], { identifier, character.name })
        local row = MySQL.single.await(
            "SELECT first_name, last_name, last_x, last_y, last_z, last_heading FROM lightrp_characters WHERE identifier = ?",
            { identifier })
        if row then
            if row.first_name and row.last_name then
                character.firstName, character.lastName = row.first_name, row.last_name
            end
            if row.last_x ~= nil and row.last_y ~= nil and row.last_z ~= nil then
                character.position = { x = row.last_x, y = row.last_y, z = row.last_z }
                character.heading = row.last_heading or 0
            end
        end
    end)
    if not ok then log("load failed for %d: %s", playerId, tostring(err)) end
    return character
end

-- The position is sampled while the player is in the world, because the
-- session is already gone when onPlayerDisconnected fires.
local function samplePosition(playerId)
    local character = characters[playerId]
    if character == nil then return end
    local position = Open77.players.position(playerId)
    if position then
        character.lastKnown = { x = position.x, y = position.y, z = position.z }
    end
end

local function saveCharacter(playerId)
    local character = characters[playerId]
    if character == nil or not databaseReady or character.identifier == nil then return end
    local playtime = nowMs() - (character.joinedAtMs or nowMs())
    local last = character.lastKnown
    local ok, err = pcall(function()
        if last then
            MySQL.update.await([[
                UPDATE lightrp_characters
                SET playtime_ms = playtime_ms + ?, last_seen = CURRENT_TIMESTAMP,
                    last_x = ?, last_y = ?, last_z = ?
                WHERE identifier = ?
            ]], { playtime, last.x, last.y, last.z, character.identifier })
        else
            MySQL.update.await(
                "UPDATE lightrp_characters SET playtime_ms = playtime_ms + ?, last_seen = CURRENT_TIMESTAMP WHERE identifier = ?",
                { playtime, character.identifier })
        end
    end)
    if not ok then log("save failed for %d: %s", playerId, tostring(err)) end
end

-- /register: creates or renames the character. Returns ok, reason.
function LightRp.register(playerId, firstName, lastName)
    if not validName(firstName) or not validName(lastName) then return false, "invalid_name" end
    firstName, lastName = titleCase(firstName), titleCase(lastName)
    local character = characters[playerId] or loadCharacter(playerId)
    character.firstName, character.lastName = firstName, lastName
    if databaseReady and character.identifier then
        local ok, err = pcall(function()
            MySQL.update.await([[
                INSERT INTO lightrp_characters (identifier, account_name, first_name, last_name)
                VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE first_name = VALUES(first_name), last_name = VALUES(last_name)
            ]], { character.identifier, character.name, firstName, lastName })
        end)
        if not ok then log("register save failed for %d: %s", playerId, tostring(err)) end
    end
    return true
end

-- /report: always logged, filed in the database when there is one.
function LightRp.report(playerId, message)
    local character = characters[playerId]
    local reporter = LightRp.displayName(playerId)
    log("REPORT from %s (%s): %s", reporter, character and character.identifier or "?", message)
    if databaseReady and character and character.identifier then
        pcall(function()
            MySQL.update.await("INSERT INTO lightrp_reports (identifier, reporter, message) VALUES (?, ?, ?)",
                { character.identifier, reporter, message })
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Lifecycle

AddEventHandler("onPlayerConnected", function(playerIdStr)
    local playerId = tonumber(playerIdStr)
    if playerId == nil or playerId <= 0 then return end
    CreateThread(function() loadCharacter(playerId) end)
end)

AddEventHandler("onPlayerDisconnected", function(playerIdStr)
    local playerId = tonumber(playerIdStr)
    if playerId == nil then return end
    CreateThread(function()
        saveCharacter(playerId)
        characters[playerId] = nil
    end)
end)

-- Every 20 s remember where everyone stands, so a disconnect can save it.
CreateThread(function()
    while true do
        Wait(20000)
        for playerId in pairs(characters) do samplePosition(playerId) end
    end
end)
