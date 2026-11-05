-- The Titan over LightRP's own HUD: client/core/hud.lua lays the piloted Titan's state (the op77_lightrp_titans client export
-- hudState) over the view it samples, and client/core/hotbar.lua stands down while it is there. Both are the real modules over
-- fakes of the host; the Titan resource is a table with one export whose answer the test chooses. While op77_weaponhud runs
-- BT's weapon goes to it (its setExternal export, here a recorder) and not to LightRP's own dial.
dofile("shared/config.lua")
dofile("shared/events.lua")
local E = LightRpEvents
local clock = 0
local threads, handlers, serverEvents, hudSent, hotbarSent, mappings = {}, {}, {}, {}, {}, {}
local function step(n)
    for _ = 1, n or 1 do
        clock = clock + 100
        for _, thread in ipairs(threads) do
            if coroutine.status(thread) ~= "dead" then local ok, why = coroutine.resume(thread); assert(ok, why) end
        end
    end
end

GetGameTimer = function() return clock end
GetCurrentResourceName = function() return "op77_lightrp" end
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
AddEventHandler = function(name, fn) handlers[name] = fn end
RegisterNetEvent = function(name, fn) handlers[name] = fn end
TriggerEvent = function() end
TriggerServerEvent = function(name, payload) serverEvents[#serverEvents + 1] = { name = name, payload = payload }; return true end
RegisterKeyMapping = function(def) mappings[def.id] = def; return true, def.key end

-- The Titan resource: running or not, and what hudState answers (an error when `raises`).
local titans = { state = "running", answer = nil, raises = false, calls = 0 }
local hologram = { state = "running", accept = true, raises = false, shown = false, calls = {} } -- op77_weaponhud
GetResourceState = function(name)
    if name == "op77_lightrp_titans" then return titans.state end
    if name == "op77_weaponhud" then return hologram.state end
    return "missing"
end
exports = { op77_lightrp_titans = { hudState = function()
    titans.calls = titans.calls + 1
    if titans.raises then error("export failed", 0) end
    return titans.answer
end } }

local ownWeapon = { active = true, reserve = 59, hands = { { hand = "right", label = "Militech Lexington", magazine = 21, capacity = 21, reloading = false } } }
local ownSamples = 0
LightRpWeaponHud = { sample = function() ownSamples = ownSamples + 1; return ownWeapon end }
local page = { on = function() end }
LightRpUi = { page = page, characterReady = true, dialogs = {}, log = function() end,
    send = function(name, payload)
        if name == E.page.hud then
            hudSent[#hudSent + 1] = { titan = payload.titan, weapon = payload.weapon, kit = payload.titanKit, armor = payload.armor, health = payload.health }
        elseif name == "lightrp:ui:hotbar" then
            hotbarSent[#hotbarSent + 1] = payload
        end
        return true
    end }
Open77 = { character = { state = function() return { alive = true, attached = true } end } }

dofile("client/core/hud.lua")
dofile("client/core/hotbar.lua")
local Hud, Hotbar = LightRpHud, LightRpHotbar
Hud.start()
Hotbar.bind(page)
handlers["op77_lightrp:hotbar"]({ kind = "state", state = { ready = true, revision = 1, inventoryId = "player:1", items = {} } })

local function lastHud() return hudSent[#hudSent] end
-- The last state sent to the hotbar page (the activation flashes are not states).
local function lastHotbar()
    for index = #hotbarSent, 1, -1 do
        if hotbarSent[index].kind == "state" then return hotbarSent[index] end
    end
end

-- The state the Titan's HUD module builds (controller/open77_titan_hud.lua), for a Vanguard.
local function vanguard()
    return {
        on = true, top = 0.13, className = "Vanguard", held = false,
        allowed = { missiles = true, vortex = true, smoke = false, dash = false, jets = true, sentry = false, flight = false,
            designator = false, core = true },
        hull = { segments = 3, segment = 1200, hull = 2500, shield = 0.7, low = false, name = "BT-7274", flash = 2 },
        core = { share = 0.5, state = "ready", key = "X", need = 0.25 },
        weapon = { id = "xo16", name = "XO-16", melee = false, ammo = 7, capacity = 40, reload = { left = 1.4, done = 0.45 }, notes = { "CHARGE 2" } },
        abilities = {
            { id = "missiles", name = "MISSILES", key = "Q", state = "ready", fill = 0.55, count = 5 },
            { id = "vortex", name = "VORTEX", key = "F", state = "empty", fill = 0.3, left = 8.2, tone = "red" },
            { id = "smoke", name = "SMOKE", key = "C", state = "active", left = 2.4 },
            { id = "jets", name = "JETS", key = "SPACE", state = "ready", fill = 0.7 },
        },
        protocols = { link = 2, lamps = {} }, controls = { { key = "E", label = "Disembark (hold)" } }, notice = "eject",
    }
end

-- On foot: the view is the player's own, and the Titan resource is asked once a loop.
step(2)
assert(lastHud().titan == nil and lastHud().kit == nil and lastHud().weapon == ownWeapon, "no Titan state: the player's own view")
assert(Hud.titanActive == false and titans.calls > 0, "asked, and nothing piloted")

-- Piloting: the hull and shield, BT's weapon, the allowed cells and the core.
titans.answer = vanguard()
step(1)
local titan, weapon, kit = lastHud().titan, lastHud().weapon, lastHud().kit
assert(Hud.titanActive == true, "the hotbar is told")
assert(titan.name == "BT-7274" and titan.className == "Vanguard" and titan.held == false and titan.flash == 2, "who it is")
-- before a pick the stand-by class carries the Titan's own name: the chip names it once
local standby = vanguard()
standby.className, standby.held = "BT-7274", true
titans.answer = standby
step(1)
assert(lastHud().titan.className == nil and lastHud().titan.name == "BT-7274" and lastHud().titan.held == true, "the stand-by class is not named twice")
titans.answer = vanguard()
step(1)
assert(titan.hull.value == 2500 and titan.hull.max == 3600 and titan.hull.low == false and titan.hull.doomed == nil, "the hull over its segments' total")
assert(titan.shield == 70, "the shield in percent: " .. tostring(titan.shield))
assert(weapon.active == true and weapon.titan == true and weapon.reserve == nil and #weapon.hands == 1, "BT's weapon, no reserve")
local hand = weapon.hands[1]
assert(hand.hand == "right" and hand.label == "XO-16" and hand.magazine == 7 and hand.capacity == 40 and hand.reloading == true and hand.melee == nil, "a gun's hand")
assert(#kit.abilities == 3 and kit.abilities[1].id == "missiles" and kit.abilities[2].id == "vortex" and kit.abilities[3].id == "jets",
    "the abilities the class allows, in order, the smoke cell dropped")
local missiles, vortex = kit.abilities[1], kit.abilities[2]
assert(missiles.name == "MISSILES" and missiles.key == "Q" and missiles.state == "ready" and missiles.fill == 0.55 and missiles.count == 5, "a cell's own fields")
assert(vortex.state == "empty" and vortex.left == 8.2 and vortex.tone == "red" and vortex.count == nil, "a waiting cell")
assert(kit.core.share == 0.5 and kit.core.state == "ready" and kit.core.key == "X" and kit.core.need == 0.25, "the core")
assert(kit.core.name == nil and kit.core.ability == nil, "the plain core sends no name and no ability")
-- A class whose core is an ability's (the Flight Strike takes the core key): the name and the icon the Titan sends reach the tile.
local strike = vanguard()
strike.core.name, strike.core.ability = "FLIGHT STRIKE", "flight"
titans.answer = strike
step(1)
assert(lastHud().kit.core.name == "FLIGHT STRIKE" and lastHud().kit.core.ability == "flight" and lastHud().kit.core.state == "ready", "a renamed core with an ability's icon")
strike.core.name, strike.core.ability = "", 4
step(1)
assert(lastHud().kit.core.name == nil and lastHud().kit.core.ability == nil, "an empty or mangled name and ability are dropped")
titans.answer = vanguard()
step(1)
assert(lastHud().armor == 0 and lastHud().health.value == 100, "the player's own gauges are untouched: the page picks")
-- A cell no class can lock (the broadsword's SPIN on R) is shown whatever the class allows; a locked one still is not.
local sword = vanguard()
sword.abilities[#sword.abilities + 1] = { id = "spin", name = "SPIN", key = "R", state = "ready", count = 3 }
titans.answer = sword
step(1)
local last = lastHud().kit.abilities[#lastHud().kit.abilities]
assert(#lastHud().kit.abilities == 4 and last.id == "spin" and last.key == "R" and last.count == 3, "the SPIN cell goes through")
titans.answer = vanguard()
step(1)

-- A melee weapon has no magazine; a class without the core has no core cell; a held, doomed hull.
local state = vanguard()
state.weapon = { id = "sword", name = "BROADSWORD", melee = true }
state.allowed.core = false
state.held = true
state.hull = { segments = 3, segment = 1200, hull = 0, doomed = 0.55, doomedText = "DOOMED", low = true, name = "BT-7274" }
titans.answer = state
step(1)
titan, weapon, kit = lastHud().titan, lastHud().weapon, lastHud().kit
hand = weapon.hands[1]
assert(hand.melee == true and hand.label == "BROADSWORD" and hand.magazine == nil and hand.capacity == nil and hand.reloading == false, "a melee hand")
assert(kit.core == nil, "no core for a class that may not use it")
assert(titan.held == true and titan.hull.doomed == 0.55 and titan.hull.doomedText == "DOOMED" and titan.hull.low == true and titan.shield == nil and titan.flash == nil,
    "held, doomed, no shield")

-- No class: every cell and the core; sections the controller could not read are left out, not invented.
state = vanguard()
state.allowed, state.className, state.weapon, state.hull = nil, nil, nil, nil
titans.answer = state
step(1)
titan, weapon, kit = lastHud().titan, lastHud().weapon, lastHud().kit
assert(#kit.abilities == 4 and kit.core ~= nil, "no class, no lock")
assert(titan.name == "BT-7274" and titan.className == nil and titan.hull == nil and titan.shield == nil, "a Titan with no hull section")
assert(weapon.active == false and weapon.titan == nil, "no weapon section: the player's own weapon is not shown in BT either")

-- A table the export mangled cannot break the sample.
titans.answer = { abilities = { "x", { id = 3 }, false }, core = "x", hull = { hull = "many", segments = 0 }, weapon = { name = 4, ammo = 0 / 0 } }
step(1)
assert(Hud.titanActive == true and lastHud().titan.hull.value == 0 and lastHud().titan.hull.max == 1 and #lastHud().kit.abilities == 0 and lastHud().kit.core == nil, "junk is dropped")
assert(lastHud().weapon.hands[1].label == "WEAPON" and lastHud().weapon.hands[1].magazine == nil, "a nameless gun")

-- Back on foot: everything is gone the same loop, the player's own weapon is back.
titans.answer = nil
step(1)
assert(lastHud().titan == nil and lastHud().kit == nil and lastHud().weapon == ownWeapon and Hud.titanActive == false, "on foot again")

-- No resource, a stopped one, or an export that fails: never an error, never a Titan.
titans.answer = vanguard()
titans.state = "stopped"
local calls = titans.calls
step(2)
assert(lastHud().titan == nil and Hud.titanActive == false and titans.calls == calls, "a stopped resource is not asked")
titans.state, titans.raises = "running", true
step(2)
assert(lastHud().titan == nil and lastHud().weapon == ownWeapon and Hud.titanActive == false, "a failing export is no Titan")
titans.raises = false
titans.answer = nil
local real = exports
exports = nil
step(2)
assert(lastHud().titan == nil and Hud.titanActive == false, "no exports at all")
exports = real

-- op77_weaponhud running (it announces itself): BT's weapon goes to its hologram through setExternal, and the page's own dial
-- stays down, with the hologram's top edge for the crew frame. The recorder keeps what each call carried.
exports.op77_weaponhud = {
    setExternal = function(_, state)
        hologram.calls[#hologram.calls + 1] = { state = state }
        if hologram.raises then error("export failed", 0) end
        return hologram.accept
    end,
    isShown = function() return hologram.shown end,
    getConfig = function() return { layout = { bottom = 142, offsetY = 0, scale = 0.6 } } end,
}
local function lastCall() return hologram.calls[#hologram.calls] and hologram.calls[#hologram.calls].state end
-- what the Titan reports for each of its weapons (controller/open77_titan_hud.lua)
local function titanWith(weapon) local t = vanguard(); t.weapon = weapon; return t end
local XO16 = { id = "xo16", name = "XO-16", melee = false, ammo = 7, capacity = 40, reload = { left = 1.4, done = 0.45 } }

handlers["op77_weaponhud:state"]({ active = true })
assert(Hud.externalWeaponHud == true)
ownSamples = 0
step(3)
assert(lastHud().weapon.active == false and lastHud().weapon.externalTop == 0 and ownSamples == 0, "on foot: the hologram is the weapon readout, LightRP's own is not even sampled")
assert(#hologram.calls == 1 and lastCall() == nil, "and whatever BT left in it is cleared once, not every loop")

titans.answer = titanWith(XO16)
hologram.shown = true
step(2)
local sent = lastCall()
assert(#hologram.calls == 2, "one call for the weapon")
assert(sent.key == "titan:xo16" and sent.name == "XO-16" and sent.class == "TITAN" and sent.type == "RIFLE" and sent.melee == false
    and sent.magazine == 7 and sent.capacity == 40 and sent.reloading == true and sent.reserve == nil, "an XO-16: badge TITAN, a rifle, its magazine, no reserve")
weapon = lastHud().weapon
assert(weapon.active == false and weapon.titan == nil and weapon.hands == nil and weapon.externalTop > 0, "BT's weapon is not on LightRP's dial; the hologram's top edge is kept")
assert(lastHud().titan.name == "BT-7274" and #lastHud().kit.abilities == 3, "the rest of the Titan is on the view")
step(5)
assert(#hologram.calls == 2, "nothing changed, nothing sent")
local gun = titanWith({ id = "xo16", name = "XO-16", melee = false, ammo = 6, capacity = 40 })
titans.answer = gun
step(1)
assert(#hologram.calls == 3 and lastCall().magazine == 6 and lastCall().reloading == false, "a shot: one call")

-- a core burns: the state carries `boost` (the hologram glows), sent when it flips and not every loop; never for the flight strike
do
    local base = #hologram.calls
    local function withCore(core, weapon)
        local t = titanWith(weapon or { id = "xo16", name = "XO-16", melee = false, ammo = 6, capacity = 40 })
        t.core = core
        titans.answer = t
        step(1)
        return lastCall()
    end
    local boosted = withCore({ share = 0.5, state = "ready", key = "X" })
    assert(#hologram.calls == base and boosted.boost == nil, "a ready core boosts nothing: no boost, nothing sent")
    boosted = withCore({ share = 1, state = "active", key = "X" })
    assert(#hologram.calls == base + 1 and boosted.boost == true and boosted.magazine == 6, "a burning core: one call, the weapon glows")
    step(5)
    assert(#hologram.calls == base + 1, "not sent again while it burns")
    boosted = withCore({ share = 1, state = "active", name = "FLIGHT STRIKE", ability = "flight" })
    assert(#hologram.calls == base + 2 and boosted.boost == nil, "the flight strike boosts no weapon: cleared when it takes over")
    boosted = withCore({ share = 1, state = "active", key = "X" }, { id = "sword", name = "BROADSWORD", melee = true })
    assert(#hologram.calls == base + 3 and boosted.boost == true and boosted.melee == true and boosted.key == "titan:sword", "a melee weapon glows too")
    boosted = withCore({ share = 0.1, state = "ready", key = "X" }, { id = "sword", name = "BROADSWORD", melee = true })
    assert(#hologram.calls == base + 4 and boosted.boost == nil, "cleared once the core is over")
    boosted = withCore("junk")
    assert(boosted.boost == nil, "a core the export mangled boosts nothing")
end

-- every weapon of the Titan, with the badge and the type the hologram shows
local function asSent(weapon)
    titans.answer = titanWith(weapon)
    step(1)
    return lastCall()
end
sent = asSent({ id = "rail", name = "RAILGUN", melee = false, ammo = 3, capacity = 5 })
assert(sent.key == "titan:rail" and sent.class == "TITAN" and sent.type == "CHARGE RIFLE" and sent.magazine == 3 and sent.capacity == 5, "the railgun")
sent = asSent({ id = "pred", name = "PREDATOR", melee = false, ammo = 90, capacity = 100 })
assert(sent.key == "titan:pred" and sent.class == "TITAN" and sent.type == "CANNON" and sent.magazine == 90, "the predator cannon")
sent = asSent({ id = "sword", name = "BROADSWORD", melee = true })
assert(sent.key == "titan:sword" and sent.class == "BLADE" and sent.type == "SWORD" and sent.melee == true and sent.magazine == nil
    and sent.capacity == nil and sent.reloading == false, "the sword: melee, BLADE for the hologram's melee label")
sent = asSent({ id = "fist", name = "FISTS", melee = true })
assert(sent.key == "titan:fist" and sent.class == "BLUNT" and sent.type == "FISTS" and sent.melee == true, "the fists: melee, BLUNT")
sent = asSent({ id = "laser", name = "LASER", melee = false, ammo = 1, capacity = 2 })
assert(sent.key == "titan:laser" and sent.class == "TITAN" and sent.type == nil, "a weapon the table does not know: no type")
assert(lastHud().weapon.hands == nil, "none of them on the dial")

-- BT has no weapon section: the hologram's weapon is cleared, the dial still has nothing of BT's
local before = #hologram.calls
titans.answer = titanWith(nil)
step(2)
assert(#hologram.calls == before + 1 and lastCall() == nil and lastHud().weapon.active == false and lastHud().weapon.hands == nil, "no weapon section: cleared")

-- leaving BT clears the hologram's weapon the same loop, once
titans.answer = titanWith(XO16)
step(1)
before = #hologram.calls
assert(lastCall().key == "titan:xo16")
titans.answer = nil
step(3)
assert(#hologram.calls == before + 1 and lastCall() == nil, "on foot: cleared once")
assert(lastHud().titan == nil and lastHud().weapon.active == false and lastHud().weapon.hands == nil and Hud.titanActive == false)

-- the hologram refuses (or fails): BT's weapon is on LightRP's dial meanwhile, and asked again only every two seconds
hologram.accept = false
titans.answer = titanWith(XO16)
before = #hologram.calls
step(1)
weapon = lastHud().weapon
assert(#hologram.calls == before + 1 and weapon.active == true and weapon.titan == true and weapon.hands[1].label == "XO-16", "refused: the dial")
step(10)
assert(#hologram.calls == before + 1 and lastHud().weapon.titan == true, "not asked again within a second")
step(15)
assert(#hologram.calls == before + 2, "asked again after two seconds")
hologram.accept, hologram.raises = true, true
step(25)
assert(lastHud().weapon.titan == true, "an export that fails is the same")
hologram.raises = false
step(25)
assert(lastHud().weapon.active == false and lastHud().weapon.hands == nil and lastCall().key == "titan:xo16", "it takes the weapon again: the dial is down")

-- not running (the announcement is stale): not called, the dial
hologram.state = "stopped"
before = #hologram.calls
titans.answer = titanWith({ id = "xo16", name = "XO-16", melee = false, ammo = 5, capacity = 40 })
step(3)
assert(#hologram.calls == before and lastHud().weapon.titan == true and lastHud().weapon.hands[1].magazine == 5, "a stopped resource is not called")
hologram.state = "running"
step(25)
assert(lastHud().weapon.active == false and lastHud().weapon.hands == nil and lastCall().magazine == 5, "running again: back in the hologram")

-- it announces that it stands down: the dial; and sends everything again when it is back (it lost what it held)
handlers["op77_weaponhud:state"]({ active = false })
before = #hologram.calls
step(3)
assert(Hud.externalWeaponHud == false and #hologram.calls == before and lastHud().weapon.titan == true, "stood down: the dial, no call")
handlers["op77_weaponhud:state"]({ active = true })
step(2)
assert(#hologram.calls == before + 1 and lastCall().key == "titan:xo16" and lastHud().weapon.hands == nil, "back: sent again")
handlers["onClientResourceStop"]("op77_weaponhud")
step(2)
assert(Hud.externalWeaponHud == false and lastHud().weapon.titan == true, "stopped: the dial")
handlers["op77_weaponhud:state"]({ active = true })
step(2)
assert(lastHud().weapon.hands == nil and lastCall().key == "titan:xo16", "restarted: the hologram")

-- the hologram's own answer to isShown is missing: LightRP's weapon sample stands in for the crew frame's clearance
local isShown = exports.op77_weaponhud.isShown
exports.op77_weaponhud.isShown = nil
ownSamples = 0
step(2)
assert(ownSamples == 2 and lastHud().weapon.active == false and lastHud().weapon.externalTop > 0, "isShown missing: the sample is the fallback")
exports.op77_weaponhud.isShown = isShown
ownSamples = 0
step(2)
assert(ownSamples == 0, "and only then")
titans.answer = nil
handlers["op77_weaponhud:state"]({ active = false })
step(2)
assert(lastHud().titan == nil and lastHud().weapon == ownWeapon, "without op77_weaponhud and on foot: the player's own readout")

-- The quick items: TAB shows them, unless the player pilots a Titan; the quick-use keys work either way.
local show, slot2 = mappings["lightrp.hotbar"], mappings["lightrp.hotbar.slot2"]
assert(show and show.hold == true and slot2, "the hotbar's mappings")
step(1)
assert(lastHotbar().visible == false, "closed by default")
show.onPressed()
assert(lastHotbar().visible == true, "TAB shows the quick items on foot")
titans.answer = vanguard()
step(1)
assert(Hud.titanActive == true and lastHotbar().visible == false, "TAB held, and a Titan piloted: no peek")
local uses = #serverEvents
slot2.onPressed()
assert(#serverEvents == uses + 1 and serverEvents[#serverEvents].payload.operation == "use" and serverEvents[#serverEvents].payload.slot == 2,
    "the quick-use key still works in BT")
assert(lastHotbar().visible == false, "and shows nothing")
step(30)
assert(lastHotbar().visible == false, "not even when the use's own window of time would")
titans.answer = nil
step(1)
assert(lastHotbar().visible == true, "out of the Titan with TAB still down: the peek is back")
show.onReleased()
assert(lastHotbar().visible == false, "released")
titans.answer = vanguard()
step(1)
show.onPressed()
assert(lastHotbar().visible == false, "pressed in the Titan: nothing")

print("PASS: Titan over the HUD (view.titan hull and shield, BT's weapon and melee hand, allowed cells and core, junk and missing sections, on-foot fallback, missing/stopped/failing resource; with op77_weaponhud: BT's weapon handed to it per weapon and sent on change only, boost while a core burns (not the flight strike), the dial down, cleared on leaving, the dial back when it is stopped, refuses or fails) and the hotbar standing down while piloting")
