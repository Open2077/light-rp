-- Roleplay chat. Normal text is in-character and travels by distance; the
-- global broadcast open77_chat would do is vetoed here through the cancellable
-- `chatMessage` event, so no IC line ever reaches the whole server.
local Config = LightRpConfig.chat
local colors = Config.colors

local function say(target, author, text, color, kind)
    TriggerClientEvent("chat:addMessage", target, {
        type = kind or "player",
        author = author,
        text = text,
        color = color or colors.ic,
    })
end
LightRp.say = say

function LightRp.system(playerId, text)
    say(playerId, "LIGHT RP", text, colors.system, "system")
end

function LightRp.broadcast(author, text, color)
    say(-1, author, text, color or colors.system, "system")
end

-- Command result: printed in the caller's chat as the console answer.
function LightRp.reply(source, raw, ok, text)
    print("[lightrp] " .. text)
    if source ~= nil and source > 0 then
        TriggerClientEvent("open77:command:result", source, raw or "", ok == true, text)
    end
end

-- Everyone within `range` metres of the speaker, in the same routing bucket,
-- the speaker included. Positions come from the host's snapshot roster.
local function recipientsNear(playerId, range)
    local origin = Open77.players.position(playerId)
    local list = { playerId }
    if origin == nil then return list end
    local squaredRange = range * range
    for id, position in pairs(Open77.players.positions() or {}) do
        id = tonumber(id)
        if id ~= nil and id ~= playerId and (position.bucket or 0) == (origin.bucket or 0) then
            local dx, dy, dz = position.x - origin.x, position.y - origin.y, position.z - origin.z
            if dx * dx + dy * dy + dz * dz <= squaredRange then list[#list + 1] = id end
        end
    end
    return list
end
LightRp.recipientsNear = recipientsNear

local function sayNear(playerId, range, author, text, color)
    for _, id in ipairs(recipientsNear(playerId, range)) do
        say(id, author, text, color)
    end
end
LightRp.sayNear = sayNear

local function joinArgs(args, from)
    local count = args.n or #args
    from = from or 1
    if count < from then return "" end
    return (table.concat(args, " ", from, count)):gsub("^%s+", ""):gsub("%s+$", "")
end
LightRp.joinArgs = joinArgs

local function needsCharacter(playerId)
    if not Config.requireCharacterForIc or LightRp.isRegistered(playerId) then return false end
    LightRp.system(playerId, "Vous n'avez pas encore de personnage : /register Prénom Nom. En attendant, /ooc parle hors-jeu.")
    return true
end

-- ---------------------------------------------------------------------------
-- The veto: plain chat becomes IC proximity speech.

AddEventHandler("chatMessage", function(player, _, text)
    local playerId = tonumber(player)
    if playerId == nil then return end
    CancelEvent()
    if type(text) ~= "string" or text == "" then return end
    if needsCharacter(playerId) then return end
    sayNear(playerId, Config.icRange, LightRp.displayName(playerId), text, colors.ic)
end)

-- ---------------------------------------------------------------------------
-- Player commands

RegisterCommand("ooc", function(source, args, raw)
    local text = joinArgs(args)
    if text == "" then return LightRp.reply(source, raw, false, "usage: /ooc <message>") end
    local name = GetPlayerName(source) or ("Joueur " .. tostring(source))
    say(-1, "OOC · " .. name, text, colors.ooc)
end, false)

RegisterCommand("me", function(source, args, raw)
    local text = joinArgs(args)
    if text == "" then return LightRp.reply(source, raw, false, "usage: /me <action>") end
    if needsCharacter(source) then return end
    sayNear(source, Config.meRange, "* " .. LightRp.displayName(source), text, colors.me)
end, false)

RegisterCommand("do", function(source, args, raw)
    local text = joinArgs(args)
    if text == "" then return LightRp.reply(source, raw, false, "usage: /do <description>") end
    if needsCharacter(source) then return end
    sayNear(source, Config.meRange, "* Scène", text .. " (( " .. LightRp.displayName(source) .. " ))", colors["do"])
end, false)

RegisterCommand("try", function(source, args, raw)
    local text = joinArgs(args)
    if text == "" then return LightRp.reply(source, raw, false, "usage: /try <action>") end
    if needsCharacter(source) then return end
    local success = math.random(100) <= (LightRpConfig.tryChancePercent or 50)
    local outcome = success and "réussit" or "échoue"
    sayNear(source, Config.meRange, "* " .. LightRp.displayName(source), text .. " et " .. outcome .. ".", colors["try"])
end, false)

RegisterCommand("roll", function(source, args, raw)
    local maximum = math.floor(tonumber(args[1]) or 100)
    if maximum < 2 or maximum > 1000000 then return LightRp.reply(source, raw, false, "usage: /roll [2..1000000]") end
    if needsCharacter(source) then return end
    sayNear(source, Config.meRange, "* " .. LightRp.displayName(source),
        string.format("lance un dé (1-%d) : %d", maximum, math.random(maximum)), colors["try"])
end, false)

RegisterCommand("s", function(source, args, raw)
    local text = joinArgs(args)
    if text == "" then return LightRp.reply(source, raw, false, "usage: /s <message>  (crier)") end
    if needsCharacter(source) then return end
    sayNear(source, Config.shoutRange, LightRp.displayName(source) .. " crie", text, colors.shout)
end, false)

RegisterCommand("w", function(source, args, raw)
    local text = joinArgs(args)
    if text == "" then return LightRp.reply(source, raw, false, "usage: /w <message>  (chuchoter, 4 m)") end
    if needsCharacter(source) then return end
    sayNear(source, Config.whisperRange, LightRp.displayName(source) .. " chuchote", text, colors.whisper)
end, false)

-- Private message by session id (the /id shown by the chat).
RegisterCommand("pm", function(source, args, raw)
    local target = tonumber(args[1])
    local text = joinArgs(args, 2)
    if target == nil or text == "" then return LightRp.reply(source, raw, false, "usage: /pm <id> <message>") end
    if GetPlayerName(target) == nil then return LightRp.reply(source, raw, false, "Aucun joueur avec l'id " .. tostring(target)) end
    local from = GetPlayerName(source) or tostring(source)
    say(target, "PM de " .. from .. " (" .. tostring(source) .. ")", text, colors.ooc)
    say(source, "PM à " .. (GetPlayerName(target) or tostring(target)), text, colors.ooc)
end, false)

RegisterCommand("register", function(source, args, raw)
    local first, last = args[1], args[2]
    if first == nil or last == nil or (args.n or #args) > 2 then
        return LightRp.reply(source, raw, false, "usage: /register <Prénom> <Nom>   (lettres, tirets et apostrophes)")
    end
    local ok, reason = LightRp.register(source, first, last)
    if not ok then
        return LightRp.reply(source, raw, false, "Nom refusé (" .. tostring(reason) .. ") : "
            .. LightRpConfig.names.minLength .. " à " .. LightRpConfig.names.maxLength .. " lettres par mot.")
    end
    LightRp.reply(source, raw, true, "Personnage enregistré : " .. LightRp.displayName(source))
    LightRp.system(source, "Bienvenue, " .. LightRp.displayName(source) .. ". Votre nom est maintenant celui que les autres lisent.")
end, false)

RegisterCommand("rules", function(source, _, raw)
    for _, line in ipairs(LightRpConfig.rules) do LightRp.system(source, line) end
    LightRp.reply(source, raw, true, "Règles envoyées.")
end, false)

RegisterCommand("who", function(source, _, raw)
    local players = GetPlayers()
    local names = {}
    for _, id in ipairs(players) do names[#names + 1] = LightRp.displayName(id) end
    table.sort(names)
    LightRp.reply(source, raw, true, string.format("%d en ville : %s", #players, table.concat(names, ", ")))
end, false)

RegisterCommand("report", function(source, args, raw)
    local text = joinArgs(args)
    if text == "" then return LightRp.reply(source, raw, false, "usage: /report <message>") end
    LightRp.report(source, text)
    LightRp.reply(source, raw, true, "Signalement transmis au staff. Merci.")
end, false)

RegisterCommand("help", function(source, _, raw)
    local lines = {
        "Chat normal = parole RP à 20 m. /w chuchoter (4 m), /s crier (45 m), /ooc hors-jeu (global).",
        "/me <action>, /do <description>, /try <action>, /roll [max], /pm <id> <message>.",
        "/register <Prénom> <Nom> crée votre personnage. /car <modèle> et /dv pour un véhicule, /cars pour la liste.",
        "/rules, /who, /report <message>.",
    }
    for _, line in ipairs(lines) do LightRp.system(source, line) end
    LightRp.reply(source, raw, true, "Aide envoyée.")
end, false)
