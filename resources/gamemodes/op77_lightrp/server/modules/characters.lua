-- Characters: the registered name, the saved position, playtime. Keyed on the
-- Master identity (GetPlayerIdentifier), so a renamed account keeps its character.
local Config = LightRpConfig
local Db = LightRP.db

local characters = {} -- playerId -> { identifier, accountName, firstName, lastName, position, heading, joinedAtMs, playtimeMs, lastKnown }

local Characters = LightRP.module("characters", {})
Characters.byPlayer = characters

Db.schema([[
    CREATE TABLE IF NOT EXISTS lightrp_characters (
        identifier   VARCHAR(64)  NOT NULL PRIMARY KEY,
        account_name VARCHAR(64)  NOT NULL DEFAULT '',
        first_name   VARCHAR(32)  NULL,
        last_name    VARCHAR(32)  NULL,
        last_x       DOUBLE       NULL,
        last_y       DOUBLE       NULL,
        last_z       DOUBLE       NULL,
        last_heading DOUBLE       NULL,
        food         DOUBLE       NOT NULL DEFAULT 100,
        drink        DOUBLE       NOT NULL DEFAULT 100,
        playtime_ms  BIGINT       NOT NULL DEFAULT 0,
        created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
        last_seen    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
]])

-- ---------------------------------------------------------------------------
-- Names

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

function Characters.get(playerId) return characters[playerId] end

function Characters.isRegistered(playerId)
    local c = characters[playerId]
    return c ~= nil and c.firstName ~= nil
end

function Characters.displayName(playerId)
    local c = characters[playerId]
    if c and c.firstName then return c.firstName .. " " .. c.lastName end
    return GetPlayerName(playerId) or ("Joueur " .. tostring(playerId))
end

-- ---------------------------------------------------------------------------
-- Load / save

local function load(playerId)
    local identifier = GetPlayerIdentifier(playerId)
    local c = { identifier = identifier, accountName = GetPlayerName(playerId) or ("Joueur " .. tostring(playerId)),
                joinedAtMs = LightRP.nowMs(), playtimeMs = 0, food = 100, drink = 100 }
    characters[playerId] = c
    if not Db.ready or identifier == nil then return c end
    Db.run([[INSERT INTO lightrp_characters (identifier, account_name) VALUES (?, ?)
             ON DUPLICATE KEY UPDATE account_name = VALUES(account_name), last_seen = CURRENT_TIMESTAMP]], { identifier, c.accountName })
    local row = Db.single("SELECT first_name, last_name, last_x, last_y, last_z, last_heading, food, drink, playtime_ms FROM lightrp_characters WHERE identifier = ?", { identifier })
    if row then
        if row.first_name and row.last_name then c.firstName, c.lastName = row.first_name, row.last_name end
        if row.last_x ~= nil and row.last_y ~= nil and row.last_z ~= nil then
            c.position = { x = row.last_x, y = row.last_y, z = row.last_z }
            c.heading = row.last_heading or 0
        end
        c.food = tonumber(row.food) or 100
        c.drink = tonumber(row.drink) or 100
        c.playtimeMs = tonumber(row.playtime_ms) or 0
    end
    return c
end

local function save(playerId)
    local c = characters[playerId]
    if c == nil or not Db.ready or c.identifier == nil then return end
    local playtime = LightRP.nowMs() - (c.joinedAtMs or LightRP.nowMs())
    local last = c.lastKnown
    if last then
        Db.run([[UPDATE lightrp_characters SET playtime_ms = playtime_ms + ?, last_seen = CURRENT_TIMESTAMP,
                 last_x = ?, last_y = ?, last_z = ?, food = ?, drink = ? WHERE identifier = ?]],
            { playtime, last.x, last.y, last.z, c.food or 100, c.drink or 100, c.identifier })
    else
        Db.run("UPDATE lightrp_characters SET playtime_ms = playtime_ms + ?, last_seen = CURRENT_TIMESTAMP, food = ?, drink = ? WHERE identifier = ?",
            { playtime, c.food or 100, c.drink or 100, c.identifier })
    end
end

function Characters.samplePosition(playerId)
    local c = characters[playerId]
    if c == nil then return end
    local position = Open77.players.position(playerId)
    if position then c.lastKnown = { x = position.x, y = position.y, z = position.z } end
end

-- /register and the menu form.
function Characters.register(playerId, firstName, lastName)
    if not validName(firstName) or not validName(lastName) then return false, "invalid_name" end
    firstName, lastName = titleCase(firstName), titleCase(lastName)
    local c = characters[playerId] or load(playerId)
    c.firstName, c.lastName = firstName, lastName
    if Db.ready and c.identifier then
        Db.run([[INSERT INTO lightrp_characters (identifier, account_name, first_name, last_name) VALUES (?, ?, ?, ?)
                 ON DUPLICATE KEY UPDATE first_name = VALUES(first_name), last_name = VALUES(last_name)]],
            { c.identifier, c.accountName, firstName, lastName })
    end
    LightRP.state(playerId, "character")
    LightRP.broadcastState("online")
    return true
end

-- ---------------------------------------------------------------------------
-- State + lifecycle

LightRP.stateProvider("character", function(playerId)
    local c = characters[playerId] or {}
    return {
        registered = c.firstName ~= nil,
        firstName = c.firstName, lastName = c.lastName,
        accountName = c.accountName or (GetPlayerName(playerId) or ""),
        playerId = playerId,
        userId = c.identifier,
        playtimeMs = (c.playtimeMs or 0) + (LightRP.nowMs() - (c.joinedAtMs or LightRP.nowMs())),
    }
end)

LightRP.stateProvider("online", function()
    local list = {}
    for _, id in ipairs(GetPlayers()) do list[#list + 1] = { id = id, name = Characters.displayName(id) } end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end)

function Characters.onConnected(playerId)
    CreateThread(function()
        load(playerId)
        LightRP.state(playerId, "character")
    end)
end

function Characters.onDisconnected(playerId)
    CreateThread(function()
        save(playerId)
        characters[playerId] = nil
        LightRP.broadcastState("online")
    end)
end

CreateThread(function()
    while true do
        Wait(20000)
        for playerId in pairs(characters) do Characters.samplePosition(playerId) end
    end
end)

-- ---------------------------------------------------------------------------
-- Actions + commands

LightRP.action("register", function(playerId, payload)
    local ok, reason = Characters.register(playerId, tostring(payload.firstName or ""), tostring(payload.lastName or ""))
    if not ok then
        return LightRP.result(playerId, false, string.format("Nom refusé (%s) : %d à %d lettres par mot, lettres, tirets et apostrophes.",
            tostring(reason), Config.names.minLength, Config.names.maxLength), "register")
    end
    LightRP.result(playerId, true, "Personnage enregistré : " .. Characters.displayName(playerId), "register")
end)

LightRP.command("register", { usage = "/register <Prénom> <Nom>" }, function(source, args)
    if args[1] == nil or args[2] == nil or (args.n or #args) > 2 then return false end
    local ok, reason = Characters.register(source, args[1], args[2])
    if not ok then return false, "Nom refusé (" .. tostring(reason) .. ")." end
    return true, "Personnage enregistré : " .. Characters.displayName(source)
end)
