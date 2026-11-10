-- HUD lab scenes of open77_chat: the chat driven through ChatUi (client/ui.lua) with what
-- client/main.lua sends. No server and no keyboard here: the open state is shown without
-- the lease (the adapter opens on "chat:open" whatever the focus), typed lines and keys are
-- replayed with the adapter's lab hooks (page:labType, page:labInput).
-- Idle delays are shortened for the lab (10 s and 6 s in the game).
Op77UiLab.chatIdleMs = 2500
Op77UiLab.chatIdleAfterCloseMs = 2000

local page, ready = nil, false

local function surface(lab)
    if not page then
        local why
        page, why = ChatUi.create()
        if not page then error("chat surface: " .. tostring(why)) end
        page:on("chat:ready", function() ready = true end)
        page:on("chat:submit", function(p) lab.log("chat:submit " .. tostring(p and p.text)) end)
        page:on("chat:close", function() lab.log("chat:close") end)
        page:on("chat:focusLost", function() lab.log("chat:focusLost (the shell holds the keyboard)") end)
    end
    for _ = 1, 60 do
        if ready then break end
        lab.wait(50)
    end
    if not ready then lab.log("chat: the document never reported loaded") end
    return page
end
local function send(name, payload) page:send(name, payload or {}) end
local function say(message) send("chat:addMessage", message) end
-- every scene starts closed and empty
local function reset(lab)
    surface(lab)
    page:setFocus(false, false)
    send("chat:close")
    send("chat:state", { enabled = true })
    send("chat:clear")
    send("chat:clearSuggestions")
    lab.wait(150)
end

local SUGGESTIONS = {
    { command = "/me", help = "Describe an action of your character", parameters = { { name = "action" } } },
    { command = "/mechanic", help = "Call a mechanic to your position", parameters = {} },
    { command = "/meet", help = "Propose a meeting point", parameters = { { name = "player" }, { name = "place", optional = true } } },
    { command = "/ooc", help = "Talk out of character", parameters = { "text" } },
    { command = "/id", help = "Show your temporary player id", parameters = {} },
    { command = "/help", help = "Open the guide", parameters = {} },
}

local function feed()
    say({ author = "Judy Alvarez", text = "Anyone near Lizzie's?", color = { 255, 204, 0 } })
    say({ author = "V", text = "On my way.", color = { 127, 180, 214 }, playerId = "12" })
    say({ author = "Panam", text = "Convoy leaves in five.", channel = "squad" })
    say({ author = "River", text = "psst, behind you", channel = "whisper" })
    say({ author = "Kerry", text = "brb, phone", channel = "ooc", role = "vip" })
    say({ author = "Regina", text = "Keep it clean out there.", channel = "admin", role = "admin", playerId = "1" })
    say({ author = "Takemura", text = "Local only.", channel = "local", time = "21:07" })
    say({ author = "* Jackie", text = "raises his glass and laughs", color = { 255, 138, 31 } })
    say({ type = "action", author = "Misty", text = "shuffles the deck", color = { 255, 63, 180 } })
end

HudLab.scene("chat-welcome", function(lab)
    reset(lab)
    -- the first line main.lua adds on chat:ready
    say({ type = "system", author = "OPEN77", text = "Chat connected — press T to type", color = { 255, 204, 0 } })
    lab.wait(1200)
    say({ author = "Judy Alvarez", text = "Hey, you made it." })
    lab.wait(900)
    say({ author = "V", text = "Wouldn't miss it.", color = { 127, 180, 214 } })
end)

HudLab.scene("chat-feed", function(lab)
    reset(lab)
    -- channels and colours, with and without a channel tag, emotes, a time
    local lines = {
        { author = "Judy Alvarez", text = "Anyone near Lizzie's?", color = { 255, 204, 0 } },
        { author = "V", text = "On my way.", color = { 127, 180, 214 }, playerId = "12" },
        { author = "Panam", text = "Convoy leaves in five.", channel = "squad" },
        { author = "River", text = "psst, behind you", channel = "whisper" },
        { author = "Kerry", text = "brb, phone", channel = "ooc", role = "vip" },
        { author = "Regina", text = "Keep it clean out there.", channel = "admin", role = "admin", playerId = "1" },
        { author = "Takemura", text = "A line that carries its time (shown in the open panel).", channel = "local", time = "21:07" },
        { author = "* Jackie", text = "raises his glass and laughs", color = { 255, 138, 31 } },
        { type = "action", author = "Misty", text = "shuffles the deck", color = { 255, 63, 180 } },
    }
    for _, line in ipairs(lines) do
        say(line)
        lab.wait(450)
    end
    say({ author = "Johnny Silverhand", color = { 255, 46, 60 },
        text = "A long line that has to wrap: wake up, samurai, we have a city to burn, and this sentence keeps going well past the width of the chat so that the plate, its cut corner and the colour edge can be checked on several lines." })
end)

HudLab.scene("chat-kinds", function(lab)
    reset(lab)
    say({ type = "system", author = "COMMAND", text = "Command completed.", color = { 0, 229, 255 } })
    lab.wait(500)
    say({ type = "warning", text = "Server restart in 10 minutes." })
    lab.wait(500)
    say({ type = "error", author = "COMMAND", text = "Unknown command: /fly", color = { 255, 76, 92 } })
    lab.wait(900)
    say({ type = "join", author = "Panam Palmer", text = "from Watson" })   -- a join without text is dropped, as on the page
    lab.wait(400)
    say({ type = "leave", author = "Rogue", text = "timed out" })
    lab.wait(500)
    say({ author = "Judy Alvarez", text = "V, are you there?", mention = true })
    lab.wait(1200)
    say({ type = "announce", title = "City notice", text = "The Afterlife opens tonight at 22:00. Leave your iron at the door.", time = "20:45" })
    lab.wait(900)
    say({ segments = { { text = "Segments: ", bold = true }, { text = "red ", color = { 255, 46, 60 } }, { text = "green ", color = { 143, 224, 74 } }, { text = "plain" } } })
end)

HudLab.scene("chat-burst", function(lab)
    reset(lab)
    -- a history replay: more than 3 lines in one frame arrive without animation
    for i = 1, 14 do say({ author = "Player " .. i, text = "replayed line " .. i }) end
    lab.wait(1500)
    say({ author = "V", text = "and one live line, animated" })
end)

HudLab.scene("chat-idle", function(lab)
    reset(lab)
    say({ author = "V", text = "This chat hides 2.5 s after its last line (10 s in the game)." })
    lab.wait(4200)          -- fading out, then hidden
    say({ author = "Judy Alvarez", text = "...and any new line brings it back." })
    lab.wait(1200)
    say({ author = "V", text = "A line can ask to stay longer (duration).", duration = 20000 })
end)

HudLab.scene("chat-open", function(lab)
    reset(lab)
    feed()
    lab.wait(600)
    -- the panel, the composer and the keys; the keyboard lease is asked as main.lua does
    -- (the shell may refuse it: the open state shows anyway)
    page:setFocus(true, false)
    send("chat:open")
    lab.wait(1500)
    page:labType("Hello Night City")
    lab.wait(1500)
    -- Enter: the composer flashes, the line goes to main.lua (logged)
    page:labInput("keydown", "", { key = "enter", value = "Hello Night City" })
    lab.wait(900)
    page:labType("")
end)

HudLab.scene("chat-commands", function(lab)
    reset(lab)
    feed()
    send("chat:addSuggestions", { suggestions = SUGGESTIONS })
    page:setFocus(true, false)
    send("chat:open")
    lab.wait(800)
    page:labType("/")                 -- the command index replaces the keys
    lab.wait(1300)
    page:labType("/me")
    lab.wait(1000)
    page:labInput("keydown", "", { key = "down" })
    lab.wait(700)
    page:labInput("keydown", "", { key = "down" })
    lab.wait(900)
    page:labInput("keydown", "", { key = "tab" })   -- completes the selected command
end)

HudLab.scene("chat-counter", function(lab)
    reset(lab)
    feed()
    page:setFocus(true, false)
    send("chat:open")
    lab.wait(600)
    page:labType(("a short line "):rep(12):sub(1, 159))     -- 159: no counter yet
    lab.wait(1200)
    page:labType(("counter from 160 "):rep(12):sub(1, 160))   -- 160: the counter shows
    lab.wait(1500)
    page:labType(("near the limit "):rep(18):sub(1, 232))     -- 232: red
    lab.wait(1500)
    page:labType(("full "):rep(60):sub(1, 256))               -- 256/256
end)

HudLab.scene("chat-unread", function(lab)
    reset(lab)
    for i = 1, 24 do say({ author = "Player " .. (i % 5 + 1), text = "line " .. i .. " of the log" }) end
    page:setFocus(true, false)
    send("chat:open")
    lab.wait(900)
    page:labInput("keydown", "", { key = "pageup" })    -- reading back: the view stops following
    lab.wait(900)
    say({ author = "Judy Alvarez", text = "new while reading (1)" })
    lab.wait(700)
    say({ author = "V", text = "new while reading (2)" })
    lab.wait(700)
    say({ author = "Panam", text = "new while reading (3)", channel = "squad" })
    lab.wait(1800)                                       -- "3 NEW" chip, the view has not moved
    page:labInput("keydown", "", { key = "pagedown" })
    lab.wait(600)
    page:labInput("keydown", "", { key = "pagedown" })
    lab.wait(600)
    page:labInput("keydown", "", { key = "pagedown" }) -- back at the newest line: the chip goes
end)

HudLab.scene("chat-empty-disabled", function(lab)
    reset(lab)
    page:setFocus(true, false)
    send("chat:open")                  -- open and empty: "No messages yet. Say something."
    lab.wait(2000)
    send("chat:state", { enabled = false })   -- disabled by the server: nothing on screen
    lab.wait(1500)
    send("chat:state", { enabled = true })
    say({ type = "system", author = "OPEN77", text = "Chat enabled again." })
end)

HudLab.scene("chat-clear", function(lab)
    reset(lab)
    page:setFocus(false, false)
end)
