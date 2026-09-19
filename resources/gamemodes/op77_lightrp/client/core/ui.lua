-- The single WebUI surface of the framework and the bridge around it.
--
-- One page hosts the HUD, the notices, the registration prompt and the menu.
-- The surface stays visible and transparent at all times (the hide->show path
-- does not repaint on current client builds); the page decides what to draw.
-- Focus (keyboard + cursor) is taken only while the menu or a prompt is open.
local E = LightRpEvents
local Ui = { page = nil, ready = false, menuOpen = false, queued = {} }
LightRpUi = Ui

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

function Ui.setMenuOpen(open, view)
    if Ui.page == nil then return end
    if open then
        Ui.menuOpen = true
        Ui.page:setFocus(true, true)
        Ui.send(E.page.open, { view = view })
    else
        if not Ui.menuOpen then return end
        Ui.menuOpen = false
        Ui.page:setFocus(false, false)
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
    if Ui.page == nil or Ui.menuOpen then return end
    Ui.page:setFocus(active == true, active == true)
end

function Ui.create()
    local page, err = WebUI.create({
        entry = "web/index.html",
        layer = "hud",
        zIndex = 700,
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

    page:on(E.page.ready, function()
        Ui.ready = true
        for _, item in ipairs(Ui.queued) do page:send(item[1], item[2] or {}) end
        Ui.queued = {}
        log("page ready")
        TriggerServerEvent(E.net.ready, {})
    end)

    page:on(E.page.close, function()
        Ui.setMenuOpen(false)
        Ui.setPromptFocus(false)
    end)

    -- Every action is forwarded to the server as-is; the server validates.
    page:on(E.page.action, function(payload)
        if type(payload) ~= "table" or type(payload.type) ~= "string" then return end
        if payload.type == "voice.range" and LightRpHud then LightRpHud.setVoiceRange(payload.range) end
        if payload.type == "register" then Ui.setPromptFocus(true) end
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

    return true
end

-- Server -> client relays
RegisterNetEvent(E.net.state, function(patch) Ui.send(E.page.state, patch) end)
RegisterNetEvent(E.net.notice, function(payload) Ui.send(E.page.notice, payload) end)
RegisterNetEvent(E.net.result, function(payload) Ui.send(E.page.result, payload) end)
RegisterNetEvent(E.net.menuOpen, function(payload)
    Ui.setMenuOpen(true, type(payload) == "table" and payload.view or nil)
end)
