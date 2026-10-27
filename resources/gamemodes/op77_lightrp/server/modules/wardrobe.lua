-- Wardrobe points: places in the city where a player changes clothes. Each
-- point is a proximity interaction (3D marker, E prompt, map blip) that opens
-- the platform's wardrobe UI for an active character, the same screen the
-- creation wizard opens. No command is involved: /wardrobe is staff-only.
--
-- A fitting room is private: from a shared bucket (the city, the first day's
-- hall) the player changes in a bucket of their own, with the world's time and
-- weather, and comes back when the wardrobe closes (their client says so, see
-- client/core/wardrobe.lua), when they reconnect or switch character. A home's
-- wardrobe (housing.lua) is private already and opens in place.
local Config = LightRpConfig.wardrobes
local E = LightRpEvents
local Wardrobe = LightRP.module("wardrobe", {})

local spots = {}   -- interaction id -> spot
local rooms = {}   -- player -> { bucket = private, from = shared bucket }

local function interactionId(spot) return "wardrobe." .. spot.id end
local function privateBucket(player) return (Config.privateBucketBase or 710000) + player end
local function shared(bucket)
    if bucket == 0 then return true end
    for _, b in ipairs(Config.sharedBuckets or {}) do if b == bucket then return true end end
    return false
end

-- The fitting room keeps the world's look: same time, rate and weather as the bucket left.
local function copyEnvironment(from, to)
    local env = Open77.environment
    local state = env and (env.getState(from) or env.getState())
    if not state then return false end
    for _, call in ipairs({
        function() return env.setTime(state.hour, state.minute, state.second, to) end,
        function() return env.setTimeRate(state.rate, to) end,
        function() return env.setTimeFrozen(state.timeFrozen, to) end,
        function() return env.setWeather(state.weather, 0, to) end,
        function() return env.setWeatherFrozen(state.weatherFrozen, to) end,
    }) do if not call() then return false end end
    return true
end

local function enterRoom(player)
    if rooms[player] then return true end
    local from = GetPlayerRoutingBucket(player)
    if not shared(from) then return true end -- a home, a private scene: private already
    local bucket = privateBucket(player)
    for _, occupant in ipairs(GetPlayersInBucket(bucket)) do
        if tonumber(occupant) ~= player then return false end
    end
    copyEnvironment(from, bucket)
    if not SetPlayerRoutingBucket(player, bucket) then return false end
    local room = { bucket = bucket, from = from, opened = false }
    rooms[player] = room
    LightRP.log("wardrobe: player %d changes in private bucket %d (from %d)", player, bucket, from)
    -- The client may refuse to open (in a vehicle, still loading): it never says "closed" then.
    SetTimeout(10000, function()
        if rooms[player] == room and not room.opened then Wardrobe.leaveRoom(player) end
    end)
    return true
end

-- Back to the bucket left, only from our own room: an admin or a teleport may have moved them meanwhile.
function Wardrobe.leaveRoom(player, disconnected)
    local room = rooms[player]
    if not room then return end
    rooms[player] = nil
    if not disconnected and GetPlayerRoutingBucket(player) == room.bucket then
        if not SetPlayerRoutingBucket(player, room.from) then
            LightRP.log("wardrobe: player %d could not return to bucket %d", player, room.from)
        end
    end
    if Open77.environment and Open77.environment.clearBucket then Open77.environment.clearBucket(room.bucket) end
end
function Wardrobe.inRoom(player) return rooms[player] ~= nil end

-- private: change in a fitting room of one's own when in a shared place.
-- noTakeAway: no offer to take the saved look away as items (the creation wizard).
local function offerTakeAway(playerId, enabled)
    pcall(function() exports.open77_appearance:setTakeAway(playerId, enabled) end)
end
function Wardrobe.open(playerId, private, noTakeAway)
    local c = LightRP.characters.get(playerId)
    if c == nil or c.status ~= "active" then return false, "no_character" end
    local life = Open77.players.getLifeState(playerId)
    if life == nil or life.phase ~= "alive" then return false, "not_alive" end
    if private and not enterRoom(playerId) then return false, "room_busy" end
    -- After a save the fitting room offers to put the look in the bag
    -- (server/modules/clothing.lua grants the items).
    offerTakeAway(playerId, not noTakeAway and LightRP.inventory ~= nil and LightRP.inventory.playerId(playerId) ~= nil)
    TriggerClientEvent("open77:wardrobe_ui:open", playerId)
    return true
end

-- A top and a bottom on: what the fitting room shows (the active saved outfit over the equipment).
function Wardrobe.dressed(shown)
    if type(shown) ~= "table" or type(shown.equipment) ~= "table" then return false end
    local look = {}
    for slot, value in pairs(shown.equipment) do look[slot] = value end
    local wardrobe = shown.wardrobe
    local active = type(wardrobe) == "table" and wardrobe.active
    local outfit = active and type(wardrobe.outfits) == "table" and wardrobe.outfits[tostring(active)]
    if type(outfit) == "table" then for slot, value in pairs(outfit) do look[slot] = value end end
    local function on(slot) return look[slot] ~= nil and look[slot] ~= false end
    return (on("InnerChest") or on("OuterChest") or on("Outfit")) and (on("Legs") or on("Outfit"))
end
function Wardrobe.isDressed(playerId)
    local ok, shown = pcall(function() return exports.open77_appearance:visibleOutfit(playerId) end)
    return ok and Wardrobe.dressed(shown) or false
end

CreateThread(function()
    if not Config or not Config.enabled then return end
    Wait(500)
    for _, entry in ipairs(Config.spots or {}) do
        local spot = {}
        for k, v in pairs(entry) do spot[k] = v end
        spots[interactionId(spot)] = spot
        LightRP.interaction(interactionId(spot), {
            position = spot.position, radius = Config.interactRadius or 2.0, bucket = spot.bucket,
            label = spot.name, prompt = Config.prompt or "Change outfit", key = Config.key or "E", promptHeight = spot.promptHeight or 1.1,
            marker = spot.marker or Config.marker, ring = false,
            -- One map category; the interaction and description keep the branch name.
            blip = Config.blip and not spot.noBlip and { icon = Config.blip.icon, color = Config.blip.color, size = Config.blip.size,
                sprite = Config.blip.sprite, title = Config.blip.title or "Wardrobe",
                description = (spot.name or "Wardrobe") .. "\n" .. (Config.blip.description or "") } or nil,
        })
    end
    LightRP.log("wardrobe: %d point(s) placed", #(Config.spots or {}))
end)

local function explain(reason)
    return reason == "no_character" and "Finish your character first."
        or reason == "room_busy" and "The fitting room is not ready. Please retry."
        or "Not right now."
end

function Wardrobe.onInteract(playerId, id)
    local spot = spots[id]
    if spot == nil then return end
    local ok, reason = Wardrobe.open(playerId, true)
    if not ok then LightRP.result(playerId, false, explain(reason), "wardrobe.open") end
end

-- The wizard's "Wardrobe" button lands here too (client-local action rerouted).
LightRP.action("character.wardrobe.open", function(playerId)
    local ok, reason = Wardrobe.open(playerId, false, true)
    if not ok then LightRP.result(playerId, false, explain(reason), "character.wardrobe.open") end
end)

-- The fitting room opened or closed on the client.
RegisterNetEvent(E.net.wardrobe, function(visible)
    local player = tonumber(source)
    if not player then return end
    if visible == true then
        if rooms[player] then rooms[player].opened = true end
    else
        offerTakeAway(player, false)
        Wardrobe.leaveRoom(player)
    end
end)

-- A saved look: the first day's dressing step waits for one with clothes on.
AddEventHandler("open77:presentation:committed", function(player, shown)
    player = tonumber(player)
    if player and LightRP.tutorial and LightRP.tutorial.onDressed then LightRP.tutorial.onDressed(player, Wardrobe.dressed(shown)) end
end)

function Wardrobe.onDisconnected(player) Wardrobe.leaveRoom(player, true) end
function Wardrobe.onCharacterLoaded(player) Wardrobe.leaveRoom(player) end
AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    for player in pairs(rooms) do Wardrobe.leaveRoom(player) end
end)
