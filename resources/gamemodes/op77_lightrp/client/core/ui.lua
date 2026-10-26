-- The single WebUI surface of the framework and the bridge around it.
--
-- One page hosts the HUD, the notices, the creation wizard, the briefing and the
-- player menu. The surface stays visible and transparent at all times (the
-- hide->show path does not repaint on current client builds); the page decides
-- what to draw. The player menu (F1) takes the keyboard only; dialogs take the
-- keyboard and the cursor.
local E = LightRpEvents
local Ui = { page = nil, ready = false, menuOpen = false, promptActive = false, actionFocus = false, characterReady = false, queued = {}, dialogs = {} } -- dialogs[kind] = open?
LightRpUi = Ui
local VOICE_ONBOARDING = "op77_lightrp:onboarding"
local VOICE_SHOP = "op77_lightrp:shop"
local VOICE_JOBS = "op77_lightrp:jobcenter"
local VOICE_GARAGE = "op77_lightrp:garage"
local VOICE_DEALER = "op77_lightrp:dealership"
local VOICE_FUEL = "op77_lightrp:fuel"
local function syncVoiceHud()
    TriggerEvent("open-voice:setHudBlocked", VOICE_ONBOARDING, not Ui.characterReady)
    TriggerEvent("open-voice:setHudBlocked", VOICE_SHOP, Ui.dialogs.shop == true)
    TriggerEvent("open-voice:setHudBlocked", VOICE_JOBS, Ui.dialogs.jobcenter == true)
    TriggerEvent("open-voice:setHudBlocked", VOICE_GARAGE, Ui.dialogs.garage == true)
    TriggerEvent("open-voice:setHudBlocked", VOICE_DEALER, Ui.dialogs.dealership == true)
    TriggerEvent("open-voice:setHudBlocked", VOICE_FUEL, Ui.dialogs.fuel == true)
    TriggerEvent("open-voice:setHudBlocked", "op77_lightrp:tutorial-dialog", Ui.dialogs.tutorial == true)
    TriggerEvent("open-voice:setHudBlocked", "op77_lightrp:support", Ui.dialogs.support == true)
    TriggerEvent("open-voice:setHudBlocked", "op77_lightrp:housing", Ui.dialogs.housing == true)
end
AddEventHandler("onClientResourceStart", function(name)
    -- A voice start/restart must not reveal its higher WebUI during creation.
    if name == "open-voice" then syncVoiceHud() end
end)
AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() then
        TriggerEvent("open-voice:setHudBlocked", VOICE_ONBOARDING, false)
        TriggerEvent("open-voice:setHudBlocked", VOICE_SHOP, false)
        TriggerEvent("open-voice:setHudBlocked", VOICE_JOBS, false)
        TriggerEvent("open-voice:setHudBlocked", VOICE_GARAGE, false)
        TriggerEvent("open-voice:setHudBlocked", VOICE_DEALER, false)
        TriggerEvent("open-voice:setHudBlocked", VOICE_FUEL, false)
        TriggerEvent("open-voice:setHudBlocked", "op77_lightrp:tutorial-dialog", false)
        TriggerEvent("open-voice:setHudBlocked", "op77_lightrp:support", false)
        TriggerEvent("open-voice:setHudBlocked", "op77_lightrp:housing", false)
    end
end)
-- Keep the creation surface out of the native mirror. Observe the real editor,
-- not a guessed save timer: cancelling must also give the wizard its input back.
local editorWaiting, editorSeen, editorSuspended = nil, false, false
local function editorState(active, reason)
    editorSuspended = active
    if LightRpCreator then LightRpCreator.editor(active) end
    Ui.send(E.page.characterEditor, { active = active, error = reason })
    if Ui.supportMode then
        if active then
            if Ui.page then Ui.page:setConsumedKeys({}); Ui.page:setFocus(false, false) end
        else
            Ui.setSupportInput(Ui.supportMode)
        end
    elseif active then
        Ui.setPromptFocus(false)
    end
end

local function log(format, ...)
    print("[lightrp] " .. (select("#", ...) > 0 and string.format(format, ...) or tostring(format)))
end
Ui.log = log

-- Send to the page; buffered until it announces itself.
function Ui.send(name, payload)
    if Ui.page == nil then return false end
    if not Ui.ready then
        Ui.queued[#Ui.queued + 1] = { name, payload }
        return true
    end
    return Ui.page:send(name, payload or {})
end

-- The player menu is RageUI-style: the player keeps walking and looking around
-- while it is open. Only its navigation keys are withheld from the game (so
-- Escape does not pause and Enter/arrows do not leak); everything else passes.
local MENU_KEYS = { "escape", "enter", "backspace", "up", "down", "left", "right" }

function Ui.setMenuOpen(open)
    if Ui.page == nil then return end
    if open and (Ui.dialogs.tutorial or Ui.dialogs.support or Ui.dialogs.housing or Ui.dialogs.customization) then return end
    if open and LightRpAnimations then LightRpAnimations.close() end
    if open and Ui.creationActive then
        Ui.setPromptFocus(not editorSuspended)
        return
    end
    if open then
        if LightRpActions then LightRpActions.interrupt("interrupted") end
        Ui.menuOpen = true
        local binding = LightRpConfig.keys.menu
        local toggleKey = Open77.input.keyFor(binding.id) or binding.key
        -- The native capture API accepts navigation keys, never F1/F2 bindings.
        -- The page handles the toggle key; adding it here rejects the whole list.
        local consumed, why = Ui.page:setConsumedKeys(MENU_KEYS)
        if not consumed then log("consumed keys refused (%s): the menu will block movement", tostring(why)) end
        local focused, reason = Ui.page:setFocus(true, false, consumed == true)
        if not focused then
            log("keep-input focus refused (%s), falling back to full keyboard focus", tostring(reason))
            Ui.page:setFocus(true, false)
        end
        Ui.send(E.page.open, { toggleKey = toggleKey, freecamKey = LightRpFreecam and LightRpFreecam.key() or nil })
    else
        if not Ui.menuOpen then return end
        Ui.menuOpen = false
        Ui.page:setFocus(false, false)
        Ui.page:setConsumedKeys({})
        Ui.send(E.page.closed, {})
        TriggerServerEvent(E.net.action, { type = "menu.close" })
    end
end

function Ui.toggleMenu()
    Ui.setMenuOpen(not Ui.menuOpen)
end

-- The registration prompt needs the keyboard too; the page tells us when it
-- shows or hides it through the same close/action channel, so a dialog and the
-- menu share one focus owner.
function Ui.setPromptFocus(active)
    if not active and LightRpVehicleCustomizationClient and LightRpVehicleCustomizationClient.isActive() then return end
    if Ui.supportMode then return end -- the compact menu owns its input policy
    if not active and (Ui.dialogs.support or Ui.dialogs.housing) then return end
    if active and LightRpCreator and LightRpCreator.isPlacing() then return end
    if active and editorSuspended then return end
    if active and LightRpAnimations then LightRpAnimations.close() end
    Ui.promptActive = active == true
    if active and LightRpActions then LightRpActions.interrupt("interrupted") end
    if Ui.page == nil or Ui.menuOpen or Ui.actionFocus then return end
    Ui.page:setFocus(active == true, active == true)
end

-- Rage-style support/admin navigation passes movement and camera to the game.
-- Only text entry takes the cursor and all keyboard input. Never let unrelated
-- prompt cleanup turn a walking menu into a full-input modal (or release it).
function Ui.setSupportInput(mode)
    if mode ~= "menu" and mode ~= "form" then mode = nil end
    local previous=Ui.supportMode
    Ui.supportMode=mode
    if Ui.page==nil then return end
    if mode==nil then
        if not previous then return end -- a native tool may already own focus
        Ui.promptActive=false
        Ui.page:setConsumedKeys({})
        Ui.page:setFocus(false,false)
        if Ui.creationActive then Ui.setPromptFocus(true) end
        return
    end
    Ui.setMenuOpen(false)
    if not previous then
        if LightRpAnimations then LightRpAnimations.close() end
        if LightRpActions then LightRpActions.interrupt("interrupted") end
    end
    Ui.promptActive=true
    if editorSuspended then return end -- never steal the native appearance editor
    local keys={}
    if mode=="menu" then
        keys={"escape","enter","backspace","up","down","left","right","pageup","pagedown","tab"}
    end
    local consumed=Ui.page:setConsumedKeys(keys)
    local keep=mode=="menu" and Ui.characterReady and not Ui.creationActive and consumed==true
    local ok=Ui.page:setFocus(true,mode=="form",keep)
    if not ok then Ui.page:setFocus(true,mode=="form") end
end

function Ui.claimActionFocus(keys, allowMovement)
    if Ui.page == nil then return false, "ui_unavailable" end
    if LightRpAnimations then LightRpAnimations.close() end
    local ok, why = Ui.page:setConsumedKeys(keys)
    if not ok then return false, why end
    local focused, reason = Ui.page:setFocus(true, false, allowMovement)
    if not focused then Ui.page:setConsumedKeys({}); return false, reason end
    Ui.actionFocus = true
    return true
end
function Ui.releaseActionFocus()
    if not Ui.actionFocus or Ui.page == nil then return end
    Ui.actionFocus = false
    Ui.page:setConsumedKeys({})
    if not Ui.menuOpen and not Ui.promptActive then Ui.page:setFocus(false, false) end
end

function Ui.create()
    local page, err = WebUI.create({
        entry = "web/index.html",
        layer = "hud",
        zIndex = 720, -- above open77_chat (700): the F1 menu draws over the chat log
        width = 1920,
        height = 1080,
        fps = 60,
        transparent = true,
        visible = true,
    })
    if page == nil then
        log("WebUI failed: %s", tostring(err))
        return false
    end
    Ui.page = page
    if LightRpCreator then LightRpCreator.bind(page) end
    if LightRpTutorial then LightRpTutorial.bind(page) end
    if LightRpSupport then LightRpSupport.bind(page) end
    syncVoiceHud() -- hidden until the authoritative character state is ready
    if LightRpActions then LightRpActions.bind(page) end
    if LightRpAnimations then LightRpAnimations.bind(page) end
    if LightRpFreecam then LightRpFreecam.bind(page) end
    if LightRpVehicleCustomizationClient then LightRpVehicleCustomizationClient.bind(page) end

    page:on(E.page.ready, function()
        Ui.ready = true
        if LightRpCreator then LightRpCreator.publish() end
        if LightRpTutorial then LightRpTutorial.publish() end
        for _, item in ipairs(Ui.queued) do page:send(item[1], item[2] or {}) end
        Ui.queued = {}
        log("page ready")
        TriggerServerEvent(E.net.ready, {})
    end)

    page:on(E.page.close, function()
        Ui.setMenuOpen(false)
        Ui.setPromptFocus(false)
    end)

    -- Every action is forwarded to the server as-is; the server validates. Two
    -- exceptions open another package's native screen and must leave from here:
    -- the appearance mirror and the wardrobe take the game's input themselves.
    page:on(E.page.action, function(payload)
        if type(payload) ~= "table" or type(payload.type) ~= "string" then return end
        -- Read-only polling must not eat the global player-action rate budget.
        if payload.type == "fuel.refresh" then TriggerServerEvent(E.net.fuelRefresh,payload); return end
        if payload.type == "inventory.close" and LightRpInventory then LightRpInventory.closed() end
        if payload.type == "voice.range" and LightRpHud then LightRpHud.setVoiceRange(payload.range) end
        -- The route to a home's entrance is local: nothing to ask the server.
        if payload.type == "homes.track" then
            local ok = LightRpHomes and LightRpHomes.track(payload.id, payload.entrance, payload.label)
            if ok ~= true then Ui.send(E.page.result, { ok = false, text = "The route could not be set.", action = payload.type }) end
            return
        end
        if payload.type == "character.appearance.open" then
            local mode = payload.mode == "hairdresser" and "hairdresser" or "ripperdoc"
            local family = (payload.family == "male" or payload.family == "female") and payload.family or nil
            Ui.setMenuOpen(false)
            Ui.setPromptFocus(false)
            if Ui.creationActive then
                editorWaiting, editorSeen = 0, false
                editorState(true)
            end
            local accepted, reason = TriggerServerEvent("open77:appearance:requestOpen", mode, family)
            if not accepted and Ui.creationActive then
                editorWaiting = nil
                editorState(false, "The editor could not be requested: " .. tostring(reason))
            end
            return
        end
        if payload.type == "character.wardrobe.open" then
            -- Not a command any more (/wardrobe is staff-only): the server opens
            -- the wardrobe UI through the same client event the command fired.
            Ui.setMenuOpen(false)
            Ui.setPromptFocus(false)
        end
        local accepted, reason = TriggerServerEvent(E.net.action, payload)
        if not accepted then
            Ui.send(E.page.result, { ok = false, text = "network refused: " .. tostring(reason), action = payload.type })
        end
    end)

    -- Prompt focus: the page asks for the keyboard when the registration dialog
    -- mounts and releases it when the character is registered.
    page:on("lightrp:ui:focus", function(payload)
        Ui.setPromptFocus(type(payload) == "table" and payload.active == true)
    end)

    -- Which page dialogs are on screen, so a toggle key closes instead of reopening.
    page:on(E.page.dialogState, function(payload)
        if type(payload) == "table" and type(payload.kind) == "string" then
            Ui.dialogs[payload.kind] = payload.open == true
            if payload.kind == "shop" or payload.kind == "jobcenter" or payload.kind == "garage" or payload.kind == "dealership" or payload.kind == "fuel" or payload.kind == "tutorial" or payload.kind == "support" or payload.kind == "housing" then syncVoiceHud() end
        end
    end)

    return true
end

-- Server -> client relays
RegisterNetEvent(E.net.state, function(patch)
    if type(patch) == "table" and type(patch.character) == "table" then
        Ui.creationActive = patch.character.status ~= "active"
        if LightRpCreator then LightRpCreator.sync(patch.character) end
        Ui.characterReady = patch.character.status == "active" and not patch.character.welcomePending
        if not Ui.characterReady and LightRpAnimations then LightRpAnimations.close() end
        syncVoiceHud()
        if not Ui.characterReady and LightRpActions then LightRpActions.interrupt("interrupted") end
    end
    Ui.send(E.page.state, patch)
end)
RegisterNetEvent(E.net.notice, function(payload) Ui.send(E.page.notice, payload) end)
RegisterNetEvent(E.net.result, function(payload) Ui.send(E.page.result, payload) end)
RegisterNetEvent(E.net.shop, function(payload) Ui.send(E.page.shop, payload) end)
RegisterNetEvent(E.net.garage, function(payload) Ui.send(E.page.garage, payload) end)
RegisterNetEvent(E.net.dealership, function(payload) Ui.send(E.page.dealership, payload) end)

for _, event in ipairs({ "open77:appearance:confirmed", "open77:appearance:cancelled" }) do
    AddEventHandler(event, function()
        if editorSuspended then editorSeen = true end -- also handles a mirror closed between two polls
    end)
end

CreateThread(function()
    while true do
        Wait(250)
        if Ui.creationActive or editorSuspended then
            local opened = Open77.appearance and Open77.appearance.isOpen and Open77.appearance.isOpen()
            if opened then
                editorSeen, editorWaiting = true, nil
                if not editorSuspended then editorState(true) end
            elseif editorSeen then
                editorSeen, editorWaiting = false, nil
                editorState(false)
            elseif editorWaiting ~= nil then
                editorWaiting = editorWaiting + 250
                if editorWaiting >= 15000 then
                    editorWaiting = nil
                    editorState(false, "The appearance editor did not open. You can try again; your identity is still here.")
                end
            end
        end
    end
end)
RegisterNetEvent(E.net.dialog, function(payload)
    -- A housing menu can open storage directly. Release its keyboard policy
    -- before the inventory mounts, otherwise its later cleanup steals focus.
    if type(payload)=="table" and payload.kind~="housing" and payload.kind~="support" and Ui.supportMode then Ui.setSupportInput("closed") end
    if LightRpAnimations then LightRpAnimations.close() end
    if LightRpActions then LightRpActions.interrupt("interrupted") end
    if type(payload) == "table" and payload.kind == "inventory" then
        local key = LightRpConfig.keys.inventory
        payload.toggleKey = key and (Open77.input.keyFor(key.id) or key.key) or "I"
    end
    Ui.send(E.page.dialog, payload)
end)
