-- The weapon wheel, client side (client/core/weapon_wheel.lua): the hold mapping,
-- the mouse-only focus, open / commit / cancel, the refusals and the sounds.
dofile("shared/config.lua")
local mappings, focus, sent, sounds, threads, handlers = {}, {}, {}, {}, {}, {}
local character = { alive = true, attached = true }
local keyDown = true
local refreshed = 0
GetGameTimer = function() return clock or 0 end
clock = 0
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
AddEventHandler = function() end
GetCurrentResourceName = function() return "op77_lightrp" end
RegisterKeyMapping = function(def) mappings[def.id] = def; return true, def.key end
local page = {
    setFocus = function(_, keyboard, cursor) focus[#focus + 1] = { keyboard = keyboard, cursor = cursor }; return true end,
    on = function(_, name, fn) handlers[name] = fn end,
}
LightRpUi = { page = page, characterReady = true, dialogs = {}, log = function() end,
    send = function(name, payload) sent[#sent + 1] = { name = name, payload = payload } end }
LightRpArmamentClient = { state = function() return { ready = true } end, refresh = function() refreshed = refreshed + 1 end }
Open77 = {
    character = { state = function() return character end },
    sfx = { play2d = function(event) sounds[#sounds + 1] = event; return true end },
    input = { isDown = function() return keyDown end },
}
dofile("client/core/weapon_wheel.lua")
local W = LightRpWeaponWheel
W.bind(page)
local map = assert(mappings["lightrp.weaponwheel"], "the CTRL mapping")
assert(map.key == "CTRL" and map.hold == true and map.consume == true, "a consumed hold key")
local function last() return sent[#sent] end

-- press: the mouse only (the keyboard stays with the game), the page opens, fresh state, a sound
map.onPressed()
assert(W.open and focus[#focus].keyboard == false and focus[#focus].cursor == true, "mouse-only focus")
assert(last().name == "lightrp:ui:weaponwheel" and last().payload.kind == "open" and last().payload.key == "CTRL")
assert(refreshed == 1 and sounds[#sounds] == "ui_radial_menu_open", "the game's radial menu sound")
map.onPressed(); assert(#focus == 1, "a second press does not reopen")
-- the page's feedback: the game's own UI events
handlers["lightrp:ui:weaponwheel"]({ kind = "hover" }); assert(sounds[#sounds] == "ui_menu_hover")
handlers["lightrp:ui:weaponwheel"]({ kind = "chosen" }); assert(sounds[#sounds] == "ui_menu_item_weapon_equip")
handlers["lightrp:ui:weaponwheel"]({ kind = "chosen", unarmed = true }); assert(sounds[#sounds] == "ui_menu_item_weapon_unequip")
-- release: the page commits, the focus goes back
map.onReleased()
assert(not W.open and last().payload.kind == "commit" and focus[#focus].keyboard == false and focus[#focus].cursor == false)
assert(sounds[#sounds] == "ui_radial_menu_close")
map.onReleased(); assert(last().payload.kind == "commit" and #sent == 2, "a release without a wheel does nothing")

-- right click on the page: cancel
map.onPressed(); handlers["lightrp:ui:weaponwheel"]({ kind = "close", commit = false })
assert(not W.open and last().payload.kind == "cancel" and sounds[#sounds] == "ui_radial_menu_close")
for _, event in ipairs(sounds) do assert(event:match("^ui_"), "only the game's UI events: " .. event) end
-- left click: commit
map.onPressed(); handlers["lightrp:ui:weaponwheel"]({ kind = "close", commit = true })
assert(not W.open and last().payload.kind == "commit")

-- refusals: another owner of the input, a vehicle, a dead character, no armament state
local count = #sent
LightRpUi.menuOpen = true; map.onPressed(); assert(not W.open and #sent == count, "the F1 menu owns the input"); LightRpUi.menuOpen = nil
LightRpUi.dialogs.inventory = true; map.onPressed(); assert(not W.open, "a dialog owns the input"); LightRpUi.dialogs.inventory = nil
character.vehicle = { mounted = true }; map.onPressed(); assert(not W.open, "not in a vehicle"); character.vehicle = nil
character.alive = false; map.onPressed(); assert(not W.open, "not while down"); character.alive = true
local state = LightRpArmamentClient.state; LightRpArmamentClient.state = function() return nil end
map.onPressed(); assert(not W.open, "no equipment state yet"); LightRpArmamentClient.state = state

-- the safety loop: interrupted -> cancel; a release the mapping missed -> commit
map.onPressed(); assert(W.open)
LightRpUi.menuOpen = true; coroutine.resume(threads[1]); coroutine.resume(threads[1])
assert(not W.open and last().payload.kind == "cancel" and last().payload.reason == "interrupted"); LightRpUi.menuOpen = nil
map.onPressed(); clock = 1000; keyDown = false; coroutine.resume(threads[1])
assert(not W.open and last().payload.kind == "commit" and last().payload.reason == "released", "missed release still commits")
print("PASS: weapon wheel client (CTRL hold mapping, mouse-only focus, open/commit/cancel, click close, input owners, vehicle/death refusals, game UI sounds, safety loop)")
