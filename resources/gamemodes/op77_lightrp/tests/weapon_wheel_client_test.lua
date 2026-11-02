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
local serverEvents = {}
TriggerServerEvent = function(name) serverEvents[#serverEvents + 1] = name; return true end
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
local map = assert(mappings["lightrp.weaponwheel"], "the TAB mapping")
assert(map.key == "TAB" and map.hold == true and map.consume == true, "a consumed hold key on TAB")
local function last() return sent[#sent] end

-- press: the mouse only (the keyboard stays with the game), the page opens, fresh state, a sound
map.onPressed()
assert(W.open and focus[#focus].keyboard == false and focus[#focus].cursor == true, "mouse-only focus")
assert(last().name == "lightrp:ui:weaponwheel" and last().payload.kind == "open" and last().payload.key == "TAB")
assert(refreshed == 1 and sounds[#sounds] == "ui_radial_menu_open", "the game's radial menu sound")
map.onPressed(); assert(#focus == 1, "a second press does not reopen")
-- the page's feedback: the game's own UI events
handlers["lightrp:ui:weaponwheel"]({ kind = "hover" }); assert(sounds[#sounds] == "ui_menu_hover")
handlers["lightrp:ui:weaponwheel"]({ kind = "chosen" }); assert(sounds[#sounds] == "ui_menu_item_weapon_equip")
handlers["lightrp:ui:weaponwheel"]({ kind = "chosen", unarmed = true }); assert(sounds[#sounds] == "ui_menu_item_weapon_unequip")
-- the holster slot: the server puts away whatever is in the hands (gun, fists, blades)
handlers["lightrp:ui:weaponwheel"]({ kind = "holster" }); assert(serverEvents[#serverEvents] == "op77_lightrp:armament:holster", "holster goes to the server")
-- release (held past a tap): the page commits, the focus goes back
clock = 400; map.onReleased()
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
-- not behind a loading screen (it opened behind the shell cover, in game 2026-11-02)
LightRpUi.loadingScreen = function() return true end; map.onPressed(); assert(not W.open, "not behind a loading screen"); LightRpUi.loadingScreen = nil
-- no equipment state (no weapon, nothing bought yet): the wheel still opens, to put the fists down
local state = LightRpArmamentClient.state; LightRpArmamentClient.state = function() return nil end
map.onPressed(); assert(W.open, "opens with no equipment state"); W.close(false, "test"); LightRpArmamentClient.state = state
local armament = LightRpArmamentClient; LightRpArmamentClient = nil
map.onPressed(); assert(W.open, "opens before the armament bridge exists"); W.close(false, "test"); LightRpArmamentClient = armament

-- the safety loop: interrupted -> cancel; a release the mapping missed -> commit
map.onPressed(); assert(W.open)
LightRpUi.menuOpen = true; coroutine.resume(threads[1]); coroutine.resume(threads[1])
assert(not W.open and last().payload.kind == "cancel" and last().payload.reason == "interrupted"); LightRpUi.menuOpen = nil
clock = 600; keyDown = true; map.onPressed(); coroutine.resume(threads[1]); assert(W.open, "held: stays open")
clock = 1000; keyDown = false; coroutine.resume(threads[1])
assert(not W.open and last().payload.kind == "commit" and last().payload.reason == "released", "missed release still commits")

-- a tap: the wheel stays open (latched), the page is told, the key again commits
clock = 2000; keyDown = true; map.onPressed(); clock = 2100; keyDown = false; map.onReleased()
assert(W.open and W.latched() and last().payload.kind == "latch" and last().payload.key == "TAB", "a tap latches the wheel")
clock = 2600; coroutine.resume(threads[1]); assert(W.open, "a latched wheel with the key up stays open")
clock = 4000; coroutine.resume(threads[1]); assert(W.open, "still open: the key read down at the press is no release (in game 2026-11-02)")
map.onPressed(); assert(not W.open and last().payload.kind == "commit" and last().payload.reason == "toggle", "the key again picks")
-- a tap then a left click on the page commits
clock = 4500; keyDown = true; map.onPressed(); keyDown = false; map.onReleased(); assert(W.latched())
clock = 5000; coroutine.resume(threads[1]); assert(W.open, "latched after a real tap")
handlers["lightrp:ui:weaponwheel"]({ kind = "close", commit = true }); assert(not W.open and last().payload.kind == "commit")

-- a key state that never reads the consumed key down (Jeremzzzer, 2026-11-02): the
-- safety loop no longer closes the held wheel at 0.4 s; only the release or a timeout does
clock = 6000; keyDown = false; map.onPressed()
clock = 6500; coroutine.resume(threads[1]); assert(W.open, "isDown false without ever reading down is no release")
clock = 6900; map.onReleased(); assert(not W.open and last().payload.reason == "release", "the mapping's release commits")
clock = 7000; map.onPressed(); clock = 7000 + W.LATCH_MS + 1; coroutine.resume(threads[1])
assert(not W.open and last().payload.kind == "cancel" and last().payload.reason == "timeout", "an unanswered wheel times out")

-- the release the client synthesizes when the page takes the cursor, key still held:
-- latched, then the real release (seen by isDown) commits
clock = 30000; keyDown = true; map.onPressed(); clock = 30016; map.onReleased(); assert(W.latched())
clock = 30200; coroutine.resume(threads[1]); assert(W.open)
clock = 30800; keyDown = false; coroutine.resume(threads[1])
assert(not W.open and last().payload.reason == "released", "a held key released after a phantom release commits")
-- or a second release from the mapping while latched commits
clock = 40000; keyDown = true; map.onPressed(); map.onReleased(); clock = 40600; map.onReleased()
assert(not W.open and last().payload.kind == "commit" and last().payload.reason == "release")
print("PASS: weapon wheel client (TAB hold mapping, opens without weapons, holster to the server, mouse-only focus, open/commit/cancel, click close, input owners, vehicle/death refusals, game UI sounds, safety loop, tap latch, key state blind to the consumed key, timeout)")
