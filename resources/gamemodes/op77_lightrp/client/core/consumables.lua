-- Inventory -> gameplay handoff before requesting the synchronized workspot.
-- The animation service owns camera priority, rig, authored props and cleanup.
local E = LightRpEvents
local active
LightRpConsumables = { isActive = function() return active ~= nil end }
local function finish(a, status)
    if active ~= a or a.sent then return end
    a.sent = true
    TriggerServerEvent(E.net.consumeFinish, { token = a.token, status = status })
    if status ~= "success" and a.playbackId then
        -- Exact-ID cancellation is safe even if another action just started.
        Open77.animations.cancel(a.playbackId)
    end
end
local function clear(a)
    if active ~= a then return end
    active = nil
    if a.actionId then LightRpActions.cancel(a.actionId) end
end
local function health()
    local stats = Open77.stats and Open77.stats.get()
    local h = stats and stats.health
    return h and tonumber(h.value or h.current)
end
RegisterNetEvent(E.net.consume, function(p)
    if type(p) ~= "table" or type(p.token) ~= "string" then return end
    if p.phase == "finished" then
        if active and active.token == p.token then clear(active) end
        return
    end
    if p.phase == "prepare" then
        if active then
            if active.token ~= p.token then TriggerServerEvent(E.net.consumeFinish, { token = p.token, status = "cancelled" }) end
            return
        end
        local a = { token = p.token, expires = GetGameTimer() + 7000, health = health() }
        active = a
        CreateThread(function()
            if not LightRpUi.ready or not LightRpUi.characterReady or LightRpActions.isActive() then finish(a, "cancelled"); return end
            LightRpUi.send(E.page.dialogClose, { kind = "inventory" })
            local deadline = GetGameTimer() + 2500
            -- Wait for React's focus-release acknowledgement, not a guessed delay.
            while active == a and (LightRpUi.dialogs.inventory or LightRpUi.promptActive) and GetGameTimer() < deadline do Wait(50) end
            if active ~= a or a.sent then return end
            if LightRpUi.dialogs.inventory or LightRpUi.promptActive or LightRpUi.menuOpen then finish(a, "cancelled"); return end
            for _, open in pairs(LightRpUi.dialogs) do if open then finish(a, "cancelled"); return end end
            TriggerServerEvent(E.net.consumeReady, { token = a.token })
        end)
        return
    end
    local a = active
    if p.phase ~= "play" or not a or a.token ~= p.token or a.playbackId or a.sent then return end
    a.playbackId = p.playbackId
    a.expires = GetGameTimer() + p.durationMs + 12000
    CreateThread(function()
        -- Let the native workspot mount / temporary TPP acquire the body before
        -- the action UI captures gameplay input. Native failures cancel below.
        Wait(900)
        if active ~= a or a.sent then return end
        local id = LightRpActions.progress({ label = p.label, description = p.itemLabel .. " · Stay still",
            durationMs = p.durationMs, icon = p.icon, cancellable = true, allowMovement = false },
            function(result) finish(a, result.status) end)
        a.actionId = id
        if not id then finish(a, "cancelled") end
    end)
end)
AddEventHandler("onAnimationPlaybackFailed", function(_, playbackId)
    if active and active.playbackId == playbackId then
        local a = active
        finish(a, "cancelled"); clear(a)
    end
end)
CreateThread(function()
    while true do
        Wait(100)
        local a = active
        if a then
            local currentHealth = health()
            if not LightRpUi.characterReady or (currentHealth and a.health and currentHealth < a.health - 0.1)
                or GetGameTimer() > a.expires then
                finish(a, "cancelled"); clear(a)
            else
                a.health = currentHealth or a.health
            end
        end
    end
end)
AddEventHandler("onClientResourceStop", function(name)
    if name ~= GetCurrentResourceName() or not active then return end
    local a = active
    -- Even if the progress module has already released its focus, stop ours.
    if a.playbackId then Open77.animations.cancel(a.playbackId) end
    finish(a, "cancelled"); clear(a)
end)
