-- The real resource lifecycle (client/main.lua) against a fake chat surface: history replay
-- after a document reload, focus refusal, the Light RP command quoting rules.
-- Run with Lua 5.4 from the resource folder:  lua tests/recovery.test.lua
local handlers, callbacks, published, exported, sent, localEvents = {}, {}, {}, {}, {}, {}
local focusAllowed, focused, destroyed = true, false, 0
function RegisterNetEvent(name, fn) handlers[name] = fn end
AddEventHandler = RegisterNetEvent
function exports(name, fn) exported[name] = fn end
function GetCurrentResourceName() return "open77_chat" end
function TriggerEvent(name, ...) localEvents[#localEvents + 1] = { name, ... } end
function TriggerServerEvent(name, ...) sent[#sent + 1] = { name, ... }; return true end
function SetTimeout() end
Open77 = {
    time = { monotonic = function() return 1 end },
    -- Serialization is stubbed; the resource's ordering, count and byte budget
    -- are tested using variable-length serialized strings.
    json = { encode = function(m) return m.text end, decode = function(s) return { text = s } end },
}
-- the chat surface (client/ui.lua on NativeUI) speaks the page API main.lua uses
ChatUi = { create = function() return {
    on = function(_, name, fn) callbacks[name] = fn end,
    send = function(_, name, value) published[#published + 1] = { name = name, value = value } end,
    setFocus = function(_, keyboard, cursor)
        assert(cursor == false, "the composer takes the keyboard only")
        focused = keyboard and focusAllowed
        return not keyboard or focusAllowed
    end,
    destroy = function() destroyed = destroyed + 1 end,
} end }
dofile("client/main.lua")
handlers.onClientResourceStart("open77_chat")
assert(callbacks["chat:focusLost"], "a lost keyboard closes the composer")
callbacks["chat:ready"]()
local welcome = published[#published]
for i = #published, 1, -1 do if published[i].name == "chat:addMessage" then welcome = published[i] break end end
assert(welcome.value.text:find("press T to type", 1, true) and welcome.value.color[1] == 255 and welcome.value.color[2] == 204, "the Light RP welcome line")
for i = 1, 60 do handlers["chat:addMessage"]({ text = "message " .. i }) end
handlers["chat:open"]()
assert(focused)
handlers["chat:close"]()
assert(not focused, "closing releases the focus")
published = {}
callbacks["chat:ready"]()
local messages = {}
for _, event in ipairs(published) do
    if event.name == "chat:addMessage" then messages[#messages + 1] = event.value.text end
end
assert(#messages == 48 and messages[1] == "message 13" and messages[48] == "message 60",
    "replacement document must receive bounded history in order without another welcome")
focusAllowed = false
handlers["chat:open"]()
focusAllowed = true
handlers["chat:open"]()
assert(focused, "a refused focus must not latch the composer open")
-- the keyboard taken by a page closes the composer and publishes the real state
localEvents = {}
callbacks["chat:focusLost"]()
assert(not focused and localEvents[#localEvents][1] == "open77:chat:visibility" and localEvents[#localEvents][2] == false)

-- Light RP quoting rules: an apostrophe inside a word is text, a quote that never closes too
local function submit(text, staysOpen)
    sent = {}
    handlers["chat:open"]()
    callbacks["chat:submit"]({ text = text })
    assert(focused == (staysOpen == true), "a submitted line closes the composer; a refused one keeps it")
    return sent[#sent]
end
local event = submit("/ooc I'm here")
assert(event[1] == "open77:command:execute" and event[2] == "ooc" and event[3] == "I'm" and event[4] == "here")
event = submit("/ooc 'sup everyone")
assert(event[2] == "ooc" and event[3] == "'sup" and event[4] == "everyone", "an unterminated quote is read as text")
event = submit('/me "waves slowly" now')
assert(event[2] == "me" and event[3] == "waves slowly" and event[4] == "now", "a quote at the start of a word still groups")
event = submit("hello there")
assert(event[1] == "chat:submit" and event[2] == "hello there")
published = {}
submit("/broken\\", true)
handlers["chat:close"]()
local refused
for _, item in ipairs(published) do if item.name == "chat:addMessage" and item.value.type == "error" then refused = item.value end end
assert(refused and refused.text:find("escape", 1, true), "a trailing escape is still refused")

exported.clear()
handlers["chat:addMessage"]({ text = string.rep("x", 140000) })
handlers["chat:addMessage"]({ text = string.rep("y", 140000) })
published = {}
callbacks["chat:ready"]()
messages = {}
for _, item in ipairs(published) do
    if item.name == "chat:addMessage" then messages[#messages + 1] = item.value.text end
end
assert(#messages == 1 and messages[1]:sub(1, 1) == "y", "history must also respect the byte budget")
handlers["chat:clear"]()
published = {}
callbacks["chat:ready"]()
for _, item in ipairs(published) do assert(item.name ~= "chat:addMessage", "clear must survive recovery") end
assert(exported.isEnabled() == true and exported.setEnabled(false) == true and exported.isEnabled() == false)
handlers.onClientResourceStop("open77_chat")
assert(destroyed == 1)

-- without NativeUI: one line, no surface, nothing else breaks
local printed = {}
local output = print
print = function(text) printed[#printed + 1] = tostring(text) end
ChatUi = { create = function() return nil, "nativeui_unavailable" end }
handlers.onClientResourceStart("open77_chat")
exported.addMessage({ text = "nobody sees this" })
print = output
assert(#printed == 1 and printed[1]:find("nativeui_unavailable", 1, true))
print("Chat recovery, focus refusal and loss, ordered history, count/byte limits, clear, quoting rules, no NativeUI passed")
