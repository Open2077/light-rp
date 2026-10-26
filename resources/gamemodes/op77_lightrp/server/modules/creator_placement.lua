-- Scene authoring, restricted to command.lightrp.scene. Never changes the
-- character's registration or the production scene without a config edit.
local Placement = LightRP.module("creatorPlacement", {})
local EVENT = LightRpEvents.net.creator
local sessions, serial = {}, 0
local CLIP = "sit_chair_lean180__2h_on_lap__01__long__01"
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < 100000 end
local function allowed(player) return Open77.acl.isAllowed(player, "command.lightrp.scene") == true end
local function reply(player, ok, message) LightRP.reply(player, "lightrp.scene", ok, message) end
local function current(player, s)
    local a = Open77.animations.current(player)
    return a and a.playbackId == s.playback
end
local function unseat(player, s)
    if s.playback then Open77.animations.stop(player, s.playback); s.playback = nil end
end
function Placement.has(player) return sessions[player] ~= nil end
function Placement.stop(player, disconnected)
    local s = sessions[player]
    if not s then return end
    sessions[player] = nil
    unseat(player, s)
    Open77.environment.clearBucket(s.bucket)
    if not disconnected then
        if GetPlayerRoutingBucket(player) == s.bucket then SetPlayerRoutingBucket(player, s.previousBucket) end
        TriggerClientEvent(EVENT, player, { phase = "placement_closed" })
    end
end
local function seat(player, s, p, yaw)
    local at = Open77.players.position(player)
    if not at or (p.x-at.x)^2 + (p.y-at.y)^2 + (p.z-at.z)^2 > 16 then
        return false, "Move near the bench first, then /lightrp.scene sit."
    end
    local animation, why = Open77.animations.playAt(player, "chair", p, yaw, { loop = true, clip = CLIP })
    if not animation then return false, tostring(why) end
    s.playback, s.anchor = animation.playbackId, { x = p.x, y = p.y, z = p.z, yaw = yaw }
    return true, "Seated preview. /lightrp.scene move <x> <y> <z> (metres), turn <degrees>, save, or walk."
end
LightRP.command("lightrp.scene", { restricted = true }, function(player, args)
    if not player or player <= 0 then return false, "Run this command in game." end
    if not allowed(player) then return false, "Permission denied." end
    local op = string.lower(args[1] or "start")
    local s = sessions[player]
    if op == "stop" then Placement.stop(player); return true, "Placement closed." end
    if not Open77.ready.isReady(player) then return false, "Wait until the character has entered the world." end
    if op == "start" then
        if s then return true, "Placement already open. Use sit, walk, move, turn, save or stop." end
        LightRP.creator.stop(player)
        local bucket = LightRpConfig.characters.arrivalScene.bucketBase + 10000 + player
        if #GetPlayersInBucket(bucket) > 0 then return false, "Placement bucket is occupied." end
        s = { previousBucket = GetPlayerRoutingBucket(player), bucket = bucket, last = -10000 }
        sessions[player] = s
        for _, call in ipairs({
            function() return Open77.environment.setTime(12, 0, 0, bucket) end,
            function() return Open77.environment.setTimeFrozen(true, bucket) end,
            function() return Open77.environment.setWeather("sunny", 0, bucket) end,
            function() return Open77.environment.setWeatherFrozen(true, bucket) end,
            function() return SetPlayerRoutingBucket(player, bucket) end,
        }) do
            local ok, why = call()
            if not ok then Placement.stop(player); return false, tostring(why) end
        end
        TriggerClientEvent(EVENT, player, { phase = "placement" })
        return true, "Placement open: walk to your location, then /lightrp.scene sit. F7 changes perspective."
    end
    if not s then return false, "Start with /lightrp.scene." end
    local now = LightRP.nowMs()
    if now - s.last < 600 then return false, "Wait a moment for the previous placement." end
    s.last = now
    if op == "walk" then
        s.nonce = nil
        unseat(player, s)
        TriggerClientEvent(EVENT, player, { phase = "placement" })
        return true, "Walking enabled. Choose your location, then /lightrp.scene sit."
    elseif op == "sit" then
        serial = serial + 1
        s.nonce, s.expires = serial, now + 3000
        TriggerClientEvent(EVENT .. ":sample", player, serial)
        return true, "Reading your position and facing..."
    elseif op == "save" then
        if not s.anchor or not current(player, s) then return false, "Use sit and wait for the seated pose before saving." end
        local p, at = s.anchor, Open77.players.position(player)
        if not at or (p.x-at.x)^2 + (p.y-at.y)^2 + (p.z-at.z)^2 > 0.25 then
            return false, "The body has not settled at the seat. Wait before saving."
        end
        local text = string.format("position = { x = %.6f, y = %.6f, z = %.6f }, heading = %.6f", p.x, p.y, p.z, p.yaw)
        local ok, why = Open77.kvp.set("creator.placement.draft", text)
        if not ok then return false, "Save failed: " .. tostring(why) end
        LightRP.log("CREATOR PLACEMENT saved player=%d %s", player, text)
        return true, "Saved scene anchor: " .. text
    elseif op == "preview" then
        if not s.anchor or not current(player, s) then return false, "Use /lightrp.scene sit first." end
        local distance, side, height, aimHeight, fov = tonumber(args[2] or 3.6), tonumber(args[3] or -1.5),
            tonumber(args[4] or 0.4), tonumber(args[5] or 1.2), tonumber(args[6] or 48)
        if not finite(distance) or distance < 1 or distance > 10 or not finite(side) or math.abs(side)>8
            or not finite(height) or height < 0.1 or height > 5 or not finite(aimHeight) or aimHeight < 0.5 or aimHeight > 3
            or not finite(fov) or fov < 25 or fov > 90 then
            return false, "preview [distance 1..10] [side -8..8] [height .1..5] [look-height .5..3] [fov 25..90]"
        end
        TriggerClientEvent(EVENT .. ":preview", player, { position = s.anchor, heading = s.anchor.yaw,
            shot = { x = side, y = distance, z = height, aimX = 0, aimZ = aimHeight, fov = fov } })
        LightRP.log("CREATOR CAMERA preview player=%d distance=%.3f side=%.3f height=%.3f aimHeight=%.3f fov=%.3f",
            player, distance, side, height, aimHeight, fov)
        return true, "Cinematic preview. /lightrp.scene walk restores the normal camera."
    elseif op == "move" or op == "turn" then
        if not s.anchor or not current(player, s) then return false, "Use /lightrp.scene sit first." end
        local p = s.anchor
        if op == "turn" then
            local degrees = tonumber(args[2])
            if not finite(degrees) or math.abs(degrees) > 180 then return false, "turn <degrees>, from -180 to 180." end
            return seat(player, s, p, (p.yaw + degrees) % 360)
        end
        local x, y, z = tonumber(args[2]), tonumber(args[3]), tonumber(args[4])
        if not finite(x) or not finite(y) or not finite(z) or math.abs(x)>1 or math.abs(y)>1 or math.abs(z)>1 then
            return false, "move <x> <y> <z>, each from -1 to 1 metre; example: move 0 0 0.05."
        end
        return seat(player, s, { x = p.x+x, y = p.y+y, z = p.z+z }, p.yaw)
    end
    return false, "Usage: /lightrp.scene [start|sit|walk|move x y z|turn degrees|save|stop]"
end)
RegisterNetEvent(EVENT .. ":sample", function(nonce, value)
    local player = tonumber(source)
    local s = sessions[player]
    if not s or not s.nonce or nonce ~= s.nonce or not allowed(player) then return end
    s.nonce = nil
    if LightRP.nowMs() > s.expires or type(value) ~= "table" then return end
    local p, at = value.position, Open77.players.position(player)
    if not Open77.ready.isReady(player) or not at or type(p) ~= "table"
        or not finite(p.x) or not finite(p.y) or not finite(p.z) or not finite(value.yaw)
        or (p.x-at.x)^2 + (p.y-at.y)^2 + (p.z-at.z)^2 > 4 then
        return reply(player, false, "Position unavailable. Try again on solid ground.")
    end
    if value.mounted or (not value.grounded and not current(player, s)) then
        return reply(player, false, "Leave the vehicle/noclip and stand on solid ground before sitting.")
    end
    reply(player, seat(player, s, p, value.yaw))
end)
function Placement.onDisconnected(player) Placement.stop(player, true) end
function Placement.onCharacterSwitched(player) Placement.stop(player) end
AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    local ids = {}; for player in pairs(sessions) do ids[#ids+1] = player end
    for _, player in ipairs(ids) do Placement.stop(player) end
end)
