-- HUD lab scenes of open-voice: the plate driven through OpenVoiceHud (client/ui.lua) with
-- the payload client/main.lua publishes. No voice service here: every state is written out.
local page, ready = nil, false

local MODES = {
    { name = "whisper", label = "Whisper", distance = 3, color = "#22D8E2" },
    { name = "normal", label = "Normal", distance = 20, color = "#22D8E2" },
    { name = "shout", label = "Shout", distance = 40, color = "#22D8E2" },
    { name = "radio", label = "Radio", distance = 2.5, color = "#3FE0D0" }, -- not in the palette: the server's colour
}

local function surface(lab)
    if not page then
        local why
        page, why = OpenVoiceHud.create({ visible = true })
        if not page then error("voice surface: " .. tostring(why)) end
        page:on("open-voice:ready", function() ready = true end)
    end
    for _ = 1, 60 do
        if ready then break end
        lab.wait(50)
    end
    if not ready then lab.log("voice: the document never reported loaded") end
    page:show()
    return page
end

-- what main.lua's publish() builds
local function payload(fields)
    local p = {
        visible = true, configured = true, mode = "Normal", modeName = "normal", distance = 20, color = "#22D8E2",
        key = "F11", modeIndex = 2, modeCount = #MODES, modes = MODES, reachPercent = 50, state = "idle",
        available = true, microphoneDetected = false, transmitting = false, captureEnabled = true, inputLevel = 0,
        activation = "ptt", activeTalkers = 0, captureState = "ready", error = "",
    }
    for k, v in pairs(fields or {}) do p[k] = v end
    return p
end
local function send(fields) page:send("open-voice:update", payload(fields)) end

HudLab.scene("voice-states", function(lab)
    surface(lab)
    send({ state = "idle" })                                   -- OPEN
    lab.wait(1100)
    send({ state = "detected", microphoneDetected = true, inputLevel = 4 / 14 })   -- SIGNAL
    lab.wait(1100)
    for cells = 0, 14 do                                       -- TRANSMIT, the level sweeping the 14 cells
        send({ state = "talking", transmitting = true, inputLevel = cells / 14 })
        lab.wait(110)
    end
    lab.wait(700)
    send({ state = "muted", captureEnabled = false })          -- MUTED
    lab.wait(1100)
    send({ state = "offline", available = false })             -- VOICE OFF
    lab.wait(1100)
    send({ state = "idle" })
end)

HudLab.scene("voice-ranges", function(lab)
    surface(lab)
    send({ state = "idle" })
    lab.wait(600)
    local steps = {
        { mode = "Whisper", modeName = "whisper", distance = 3, modeIndex = 1 },
        { mode = "Normal", modeName = "normal", distance = 20, modeIndex = 2 },
        { mode = "Shout", modeName = "shout", distance = 40, modeIndex = 3 },
        { mode = "Radio", modeName = "radio", distance = 2.5, modeIndex = 4, color = "#3FE0D0" },
    }
    for _, step in ipairs(steps) do
        step.state = "detected"; step.inputLevel = 6 / 14
        send(step)
        lab.wait(1500)
    end
    -- transmitting on the server-coloured preset: digits, meter and tag go white-hot
    send({ mode = "Radio", modeName = "radio", distance = 2.5, modeIndex = 4, color = "#3FE0D0",
        state = "talking", transmitting = true, inputLevel = 12 / 14 })
end)

HudLab.scene("voice-single-range", function(lab)
    surface(lab)
    -- one preset only: the reach is written out ("NORMAL · 20 M") instead of the tags
    local one = { MODES[2] }
    send({ modes = one, modeCount = 1, modeIndex = 1, state = "idle" })
    lab.wait(1500)
    send({ modes = one, modeCount = 1, modeIndex = 1, mode = "Long range", modeName = "long", distance = 1000, color = "#8FE04A", state = "detected", inputLevel = 5 / 14 })
end)

HudLab.scene("voice-heard-error", function(lab)
    surface(lab)
    send({ state = "idle", activeTalkers = 1 })
    lab.wait(1200)
    send({ state = "talking", transmitting = true, inputLevel = 9 / 14, activeTalkers = 3 })
    lab.wait(1500)
    send({ state = "idle", activeTalkers = 12, error = "RATE_LIMITED" })
    lab.wait(2500)
    send({ state = "idle", activeTalkers = 0, error = "" })
    lab.wait(800)
    -- the longest rejection main.lua can send (80 characters) wraps above the plate
    send({ state = "muted", captureEnabled = false, error = ("INVALID SERVER VOICE CONFIG "):rep(3):sub(1, 80) })
end)

HudLab.scene("voice-hide", function(lab)
    surface(lab)
    send({ state = "detected", inputLevel = 5 / 14 })
    lab.wait(1200)
    -- setHudVisible(false): the fade, then main.lua hides the document 220 ms later
    send({ state = "detected", inputLevel = 5 / 14, visible = false })
    lab.wait(220)
    page:hide()
    lab.wait(1200)
    page:show()
    send({ state = "detected", inputLevel = 5 / 14, visible = true })
    lab.wait(1500)
    -- setHudBlocked(reason, true): hidden at once, no fade
    send({ state = "detected", inputLevel = 5 / 14, visible = false })
    page:hide()
    lab.wait(1200)
    page:show()
    send({ state = "idle", visible = true })
end)
