-- Roleplay chat. Plain text is in-character and travels by distance: the global
-- broadcast open77_chat would do is vetoed through the cancellable `chatMessage`
-- event, so no IC line ever reaches the whole server.
local Config = LightRpConfig.chat
local colors = Config.colors
local Chat = LightRP.module("chat", {})

local function displayName(playerId) return LightRP.characters.displayName(playerId) end
local function registered(playerId) return LightRP.characters.isRegistered(playerId) end

function Chat.say(target, author, text, color, kind)
    TriggerClientEvent("chat:addMessage", target, { type = kind or "player", author = author, text = text, color = color or colors.ic })
end

function Chat.system(playerId, text) Chat.say(playerId, "LIGHT RP", text, colors.system, "system") end
function Chat.broadcast(author, text, color) Chat.say(-1, author, text, color or colors.system, "system") end

-- Everyone within `range` metres of the speaker, same routing bucket, speaker included.
function Chat.recipientsNear(playerId, range)
    local origin = Open77.players.position(playerId)
    local list = { playerId }
    if origin == nil then return list end
    local squared = range * range
    for id, position in pairs(Open77.players.positions() or {}) do
        id = tonumber(id)
        if id ~= nil and id ~= playerId and (position.bucket or 0) == (origin.bucket or 0) then
            local dx, dy, dz = position.x - origin.x, position.y - origin.y, position.z - origin.z
            if dx * dx + dy * dy + dz * dz <= squared then list[#list + 1] = id end
        end
    end
    return list
end

function Chat.sayNear(playerId, range, author, text, color)
    for _, id in ipairs(Chat.recipientsNear(playerId, range)) do Chat.say(id, author, text, color) end
end

local function needsCharacter(playerId)
    if not Config.requireCharacterForIc or registered(playerId) then return false end
    Chat.system(playerId, "No character yet: F5 or /register FirstName LastName. Meanwhile, /ooc talks out of character.")
    return true
end

-- The veto: plain chat becomes IC proximity speech.
AddEventHandler("chatMessage", function(player, _, text)
    local playerId = tonumber(player)
    if playerId == nil then return end
    CancelEvent()
    if type(text) ~= "string" or text == "" or needsCharacter(playerId) then return end
    local author = LightRP.titles and LightRP.titles.chatName(playerId, displayName(playerId)) or displayName(playerId) -- "Name · Title" (titles.lua)
    Chat.sayNear(playerId, Config.icRange, author, text, colors.ic)
end)

local join = LightRP.joinArgs

local function speech(name, range, formatAuthor, color, usage)
    LightRP.command(name, { usage = usage }, function(source, args)
        local text = join(args)
        if text == "" then return false end
        if needsCharacter(source) then return nil end
        Chat.sayNear(source, range, formatAuthor(displayName(source)), text, color)
    end)
end

speech("w", Config.whisperRange, function(n) return n .. " whispers" end, colors.whisper, "/w <message>  (4 m)")
speech("s", Config.shoutRange, function(n) return n .. " shouts" end, colors.shout, "/s <message>  (45 m)")
-- /me: the action also shows over the character (op77_actionbubble)
LightRP.command("me", { usage = "/me <action>" }, function(source, args)
    local text = join(args)
    if text == "" then return false end
    if needsCharacter(source) then return nil end
    Chat.sayNear(source, Config.meRange, "* " .. displayName(source), text, colors.me)
    if LightRP.bubbles then LightRP.bubbles.act(source, text, { range = Config.meRange, duration = 6 }) end
end)

LightRP.command("do", { usage = "/do <description>" }, function(source, args)
    local text = join(args)
    if text == "" then return false end
    if needsCharacter(source) then return nil end
    Chat.sayNear(source, Config.meRange, "* Scene", text .. " (( " .. displayName(source) .. " ))", colors["do"])
    if LightRP.bubbles then
        local here = Open77.players.position(source)
        LightRP.bubbles.act(source, text, { kind = "state", range = Config.meRange, duration = 8,
            position = here and { x = here.x, y = here.y, z = here.z + 1.2 } })
    end
end)

LightRP.command("try", { usage = "/try <action>" }, function(source, args)
    local text = join(args)
    if text == "" then return false end
    if needsCharacter(source) then return nil end
    local success = math.random(100) <= (LightRpConfig.tryChancePercent or 50)
    Chat.sayNear(source, Config.meRange, "* " .. displayName(source), text .. (success and " and succeeds." or " and fails."), colors["try"])
end)

LightRP.command("roll", { usage = "/roll [2..1000000]" }, function(source, args)
    local maximum = math.floor(tonumber(args[1]) or 100)
    if maximum < 2 or maximum > 1000000 then return false end
    if needsCharacter(source) then return nil end
    Chat.sayNear(source, Config.meRange, "* " .. displayName(source), string.format("rolls a die (1-%d): %d", maximum, math.random(maximum)), colors["try"])
end)

LightRP.command("ooc", { usage = "/ooc <message>" }, function(source, args)
    local text = join(args)
    if text == "" then return false end
    Chat.say(-1, "OOC · " .. (GetPlayerName(source) or tostring(source)), text, colors.ooc)
end)

LightRP.command("pm", { usage = "/pm <id> <message>" }, function(source, args)
    local target = tonumber(args[1])
    local text = join(args, 2)
    if target == nil or text == "" then return false end
    if GetPlayerName(target) == nil then return false, "No player with id " .. tostring(target) end
    Chat.say(target, "PM from " .. (GetPlayerName(source) or tostring(source)) .. " (" .. tostring(source) .. ")", text, colors.ooc)
    Chat.say(source, "PM to " .. (GetPlayerName(target) or tostring(target)), text, colors.ooc)
end)

LightRP.command("rules", {}, function(source)
    for _, line in ipairs(LightRpConfig.rules) do Chat.system(source, line) end
    return true, "Rules sent."
end)

LightRP.command("who", {}, function(source)
    local players = GetPlayers()
    local names = {}
    for _, id in ipairs(players) do names[#names + 1] = displayName(id) end
    table.sort(names)
    return true, string.format("%d in town: %s", #players, table.concat(names, ", "))
end)

local HELP = {
    "Plain chat is in-character speech (20 m). /w whisper (4 m), /s shout (45 m), /ooc out of character.",
    "/me <action> · /do <scene> · /try <attempt> · /roll [max] · /pm <id> <message>",
    "/money · /bank · /pay <id> <amount> · /transfer <XXX-XXX> <amount> [note]",
    "/who · /rules · /report <message> · F1 opens your player menu.",
    "/camchange [classic|shoulder|centered|left|right|reset] third-person camera · /cinematic [on|off] hides the HUD.",
}

LightRP.command("help", {}, function(source)
    for _, line in ipairs(HELP) do Chat.system(source, line) end
    return true, "That is every command."
end)

-- /report is filed by the staff module (it owns the table); chat only announces.
