-- Timed, authoritative consumption. No inventory mutation until completion.
-- Pending tickets are session-only and never survive disconnect/resource stop.
local E = LightRpEvents.net
local Consume = LightRP.module("consumables", {})
local pending, sequence = {}, 0
local function now() return LightRP.nowMs() end
local function valid(player, a)
    if GetPlayerName(player) == nil then return false end
    if a.character and (LightRP.characters.get(player) ~= a.character or a.character.status ~= "active") then return false end
    local inv = LightRP.inventory.player(player)
    if inv ~= a.inventory or inv.items[a.slot] ~= a.item or a.item.name ~= a.name or a.item.count < 1 then return false end
    local life = Open77.players.getLifeState(player)
    local p = Open77.players.position(player)
    if not life or life.phase ~= "alive" or not p or p.bucket ~= a.position.bucket then return false end
    local dx, dy, dz = p.x - a.position.x, p.y - a.position.y, p.z - a.position.z
    if dx * dx + dy * dy + dz * dz > 0.75 * 0.75 then return false end
    if a.playbackId then
        local current = Open77.animations.current(player)
        if not current or not current.active or current.playbackId ~= a.playbackId then return false end
    end
    return true
end

local function clear(player, a, ok, reason, silent)
    if pending[player] ~= a then return end
    pending[player] = nil -- callbacks from stop cannot cancel a subsequent action
    if a.playbackId then pcall(Open77.animations.stop, player, a.playbackId) end
    TriggerClientEvent(E.consume, player, { phase = "finished", token = a.token, ok = ok == true })
    if not ok and not silent then
        LightRP.notice(player, { kind = "info", title = "Action interrupted", body = reason or "Your item was kept. Try again while standing still.", durationMs = 3500 })
    end
end

function Consume.isActive(player) return pending[player] ~= nil end
function Consume.canCommit(player, a) return pending[player] == a and a.phase == "committing" and valid(player, a) end
function Consume.begin(player, inv, slot, item, template)
    if pending[player] then return false, "busy" end
    local config = LightRpConsumableProfiles[template.consumeAction]
    if not config or not Open77.animations then return false, "use_failed" end
    local current = Open77.animations.current(player)
    if current and current.active then return false, "busy" end
    local p = Open77.players.position(player)
    if not p then return false, "not_alive" end
    sequence = sequence + 1
    local a = { token = tostring(now()) .. ":" .. sequence, phase = "preparing", inventory = inv,
        slot = slot, item = item, name = item.name, config = config, label = template.label,
        position = p, expires = now() + 7000,
        character = LightRP.characters.get and LightRP.characters.get(player) }
    if not valid(player, a) then return false, "not_alive" end
    pending[player] = a
    TriggerClientEvent(E.consume, player, { phase = "prepare", token = a.token })
    return true, template.label
end

RegisterNetEvent(E.consumeReady, function(payload)
    local player = source
    local a = pending[player]
    if not a or type(payload) ~= "table" or payload.token ~= a.token or a.phase ~= "preparing" then return end
    if now() > a.expires or not valid(player, a) then clear(player, a, false); return end
    a.phase = "starting" -- duplicate ready messages cannot start another playback
    local current = Open77.animations.current(player)
    if current and current.active then clear(player, a, false); return end
    local success, playback, reason = pcall(Open77.animations.play, player, a.config.profile, {
        clip = a.config.clip, loop = true, durationMs = a.config.durationMs + 12000,
    })
    if not success or not playback then
        LightRP.log("consume animation refused for %d: %s", player, tostring(reason or playback))
        clear(player, a, false, "This action could not start. Your item was kept; get out of the vehicle and stand still.")
        return
    end
    a.playbackId, a.phase, a.startedAt = playback.playbackId, "playing", now()
    a.expires = now() + a.config.durationMs + 12000
    TriggerClientEvent(E.consume, player, { phase = "play", token = a.token, playbackId = a.playbackId,
        durationMs = a.config.durationMs, label = a.config.label, itemLabel = a.label, icon = a.config.icon })
end)

RegisterNetEvent(E.consumeFinish, function(payload)
    local player = source
    local a = pending[player]
    if not a or type(payload) ~= "table" or payload.token ~= a.token or a.phase == "committing" then return end
    if payload.status ~= "success" then clear(player, a, false); return end
    if a.phase ~= "playing" or now() > a.expires or now() - a.startedAt < a.config.durationMs or not valid(player, a) then
        clear(player, a, false); return
    end
    a.phase = "committing" -- no replay/double click can grant the effect twice, including during DB awaits
    local called, ok, reason = pcall(LightRP.inventory.completeUse, player, a)
    if not called then LightRP.log("consume commit failed for %d: %s", player, tostring(ok)) end
    clear(player, a, called and ok == true, "The item could not be used. Please try again.")
end)

function Consume.cancel(player)
    local a = pending[player]
    if a and a.phase ~= "committing" then clear(player, a, false, nil, true) end
end
Consume.onDisconnected = Consume.cancel
Consume.onCharacterLoaded = Consume.cancel
Consume.onCharacterActivated = Consume.cancel
AddEventHandler("open77:playerDamaged", function(victim, _, amount)
    local player = tonumber(victim)
    local a = player and pending[player]
    if a and a.phase ~= "committing" and (tonumber(amount) or 0) > 0 then clear(player, a, false) end
end)
CreateThread(function()
    while true do
        Wait(250)
        for player, a in pairs(pending) do
            if a.phase ~= "committing" and (now() > a.expires or not valid(player, a)) then clear(player, a, false) end
        end
    end
end)
AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    for player, a in pairs(pending) do clear(player, a, false, nil, true) end
end)
