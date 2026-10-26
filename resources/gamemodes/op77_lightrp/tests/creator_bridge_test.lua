-- Native mirror handoff/focus exercised through the real Lua UI bridge.
dofile("shared/events.lua")
local callbacks, net, events, threads, sent = {}, {}, {}, {}, {}
local nativeOpen, requestAccepted, focused = false, true, false
local cursor, keepInput, consumedKeys=false,false,{}
local allowedKeys={escape=true,enter=true,tab=true,backspace=true,space=true,up=true,down=true,left=true,right=true,home=true,["end"]=true,pageup=true,pagedown=true,insert=true,delete=true}
local voiceBlocked, shopVoiceBlocked, jobVoiceBlocked, garageVoiceBlocked, dealerVoiceBlocked
local tutorialVoiceBlocked, supportVoiceBlocked, housingVoiceBlocked
TriggerEvent = function(name, reason, value)
    assert(name == "open-voice:setHudBlocked")
    if reason == "op77_lightrp:onboarding" then voiceBlocked = value
    elseif reason == "op77_lightrp:shop" then shopVoiceBlocked = value
    elseif reason == "op77_lightrp:jobcenter" then jobVoiceBlocked = value
    elseif reason == "op77_lightrp:garage" then garageVoiceBlocked = value
    elseif reason == "op77_lightrp:dealership" then dealerVoiceBlocked = value
    elseif reason == "op77_lightrp:tutorial-dialog" then tutorialVoiceBlocked = value
    elseif reason == "op77_lightrp:support" then supportVoiceBlocked = value
    elseif reason == "op77_lightrp:housing" then housingVoiceBlocked = value
    elseif reason == "op77_lightrp:fuel" then -- another dialog's independent claim
    else error("unknown voice blocker") end
end
GetCurrentResourceName = function() return "op77_lightrp" end
LightRpConfig = { keys = { menu = { id = "menu", key = "F1" } } }
Open77 = { appearance = { isOpen = function() return nativeOpen end }, input = { keyFor = function() return "F2" end } }
WebUI = { create = function()
    return { on = function(_, name, fn) callbacks[name] = fn end,
        send = function(_, name, value) sent[#sent + 1] = { name = name, value = value }; return true end,
        setConsumedKeys = function(_, keys)
            for _,key in ipairs(keys) do
                if not allowedKeys[key:lower()] then return false,"unsupported_consumed_key" end
            end
            consumedKeys=keys;return true
        end,
        setFocus = function(_, keyboard, mouse, keep) focused=keyboard;cursor=mouse;keepInput=keep;return true end }
end }
local serverCalls={}
TriggerServerEvent = function(name,payload) serverCalls[#serverCalls+1]={name=name,payload=payload};return requestAccepted, "test refusal" end
RegisterNetEvent = function(name, fn) net[name] = fn end
AddEventHandler = function(name, fn) events[name] = fn end
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
dofile("client/core/support.lua")
dofile("client/core/ui.lua")
local E, U = LightRpEvents, LightRpUi
assert(U.create())
assert(voiceBlocked, "voice is hidden before the initial character state")
callbacks[E.page.ready]()
net[E.net.state]({ character = { status = "draft" } })
local function tick() local ok, error = coroutine.resume(threads[1]); assert(ok, error) end
local function lastEditor()
    for i = #sent, 1, -1 do if sent[i].name == E.page.characterEditor then return sent[i].value end end
end
tick() -- reach the first Wait
U.setPromptFocus(true)
assert(focused)
U.setMenuOpen(true)
assert(not U.menuOpen and focused, "F1 cannot steal creation focus")
callbacks[E.page.action]({ type = "character.appearance.open", family = "female" })
assert(not focused and lastEditor().active)
assert(voiceBlocked, "native editor handoff must not reveal voice HUD")
U.setPromptFocus(true)
assert(not focused, "do not steal focus from native mirror")
nativeOpen = true; tick()
nativeOpen = false; tick()
assert(not lastEditor().active)
U.setPromptFocus(true); assert(focused)
callbacks[E.page.action]({ type = "character.appearance.open" })
events["open77:appearance:cancelled"](); tick()
assert(not lastEditor().active, "fast cancellation also resumes")
callbacks[E.page.action]({ type = "character.appearance.open" })
for _ = 1, 60 do tick() end
assert(not lastEditor().active and lastEditor().error:find("did not open"))
requestAccepted = false
callbacks[E.page.action]({ type = "character.appearance.open" })
assert(not lastEditor().active and lastEditor().error:find("test refusal"))
nativeOpen = true; tick()
assert(lastEditor().active, "automatic native editor also hides creation UI")
voiceBlocked = false
events.onClientResourceStart("open-voice")
assert(voiceBlocked, "late voice start/restart re-applies onboarding block")
net[E.net.state]({ character = { status = "active", welcomePending = true } })
assert(voiceBlocked, "welcome briefing is still onboarding")
net[E.net.state]({ needs = { food = 90 } })
assert(voiceBlocked, "unrelated patches cannot reveal voice")
net[E.net.state]({ character = { status = "active", welcomePending = false } })
assert(not voiceBlocked, "voice returns when entering gameplay")
callbacks[E.page.dialogState]({ kind = "tutorial", open = true })
U.setMenuOpen(true)
assert(tutorialVoiceBlocked and not U.menuOpen, "the tutorial conversation owns focus over F1 and voice")
callbacks[E.page.dialogState]({ kind = "tutorial", open = false })
assert(not tutorialVoiceBlocked, "walking objectives restore normal gameplay overlays")
callbacks[E.page.dialogState]({ kind = "shop", open = true })
assert(shopVoiceBlocked and not voiceBlocked, "shop suppresses higher-layer voice independently")
callbacks[E.page.dialogState]({ kind = "shop", open = false })
assert(not shopVoiceBlocked and not voiceBlocked)
callbacks[E.page.dialogState]({ kind = "jobcenter", open = true })
assert(jobVoiceBlocked and not voiceBlocked, "job center hides higher-layer voice")
callbacks[E.page.dialogState]({ kind = "jobcenter", open = false })
assert(not jobVoiceBlocked)
callbacks[E.page.dialogState]({ kind = "garage", open = true })
assert(garageVoiceBlocked and not dealerVoiceBlocked)
callbacks[E.page.dialogState]({ kind = "garage", open = false })
callbacks[E.page.dialogState]({ kind = "dealership", open = true })
assert(dealerVoiceBlocked and not garageVoiceBlocked)
callbacks[E.page.dialogState]({ kind = "dealership", open = false })
assert(not dealerVoiceBlocked)
nativeOpen=false;tick()
U.setMenuOpen(true)
assert(focused and keepInput and #consumedKeys==7,"F1 capture uses supported navigation keys with movement enabled")
U.setMenuOpen(false)
net[E.net.support]({kind="open",scope="player",body="A draft from the report command"})
assert(sent[#sent].value.body=="A draft from the report command","initial draft arrives atomically with the desk")
callbacks[E.page.dialogState]({kind="support",open=true})
callbacks[E.page.support]({operation="input",mode="menu"})
U.setPromptFocus(true);U.setMenuOpen(true);U.setPromptFocus(false)
assert(supportVoiceBlocked and focused and not U.menuOpen,"support retains input and voice priority over F1/prompts")
assert(keepInput and not cursor and #consumedKeys>=10,"Rage menu consumes navigation keys while preserving movement and camera")
callbacks[E.page.support]({operation="input",mode="form"})
assert(focused and cursor and not keepInput and #consumedKeys==0,"typing captures all input and the cursor")
callbacks[E.page.support]({operation="input",mode="menu"})
assert(keepInput and not cursor,"closing a form restores walking menu input")
callbacks[E.page.support]({operation="native",action="arbitrary_command"})
local beforeNative=#serverCalls
callbacks[E.page.support]({operation="native",action="advanced"})
assert(#serverCalls==beforeNative+1 and serverCalls[#serverCalls].payload=="adminfull","native actions use a fixed command allowlist")
callbacks[E.page.dialogState]({kind="support",open=false});U.setPromptFocus(false)
assert(not supportVoiceBlocked and not focused,"closing support restores gameplay focus")
net[E.net.state]({ character = { status = "draft" } })
assert(voiceBlocked, "creating another character hides voice again")
callbacks[E.page.dialogState]({kind="support",open=true})
callbacks[E.page.support]({operation="input",mode="menu"})
assert(focused and not keepInput,"onboarding cannot pass movement through the support menu")
nativeOpen=true;tick()
assert(not focused and #consumedKeys==0,"opening the native editor releases support input")
nativeOpen=false;tick()
assert(focused and not keepInput and #consumedKeys>=10,"closing the native editor restores support navigation")
callbacks[E.page.dialogState]({kind="support",open=false})
callbacks[E.page.support]({operation="input",mode="closed"})
assert(focused and cursor,"closing support restores the character creation form")
callbacks[E.page.support]({operation="input",mode="closed"})
assert(focused and cursor,"duplicate cleanup cannot release another screen's focus")
net[E.net.state]({character={status="active",welcomePending=false}})
callbacks[E.page.dialogState]({kind="housing",open=true})
callbacks[E.page.support]({operation="input",mode="menu"})
U.setMenuOpen(true)
assert(housingVoiceBlocked and not U.menuOpen and keepInput,"housing authoring preserves movement and blocks F1")
net[E.net.dialog]({kind="inventory"})
assert(not U.supportMode,"storage handoff releases Rage input before inventory mount")
callbacks[E.page.dialogState]({kind="housing",open=false})
U.setPromptFocus(true)
callbacks[E.page.support]({operation="input",mode="closed"})
assert(focused and cursor and not keepInput,"delayed housing cleanup must not steal inventory focus")
assert(not housingVoiceBlocked)
events.onClientResourceStop("op77_lightrp")
assert(not voiceBlocked, "gamemode stop releases its own suppression")
print("PASS: native editor lifecycle, focus, F1, voice suppression through loading/creation/welcome, restart, gameplay and cleanup")
