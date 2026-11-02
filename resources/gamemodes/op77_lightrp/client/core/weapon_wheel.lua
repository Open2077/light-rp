-- The weapon wheel (hold TAB): every weapon in the pockets on a GTA-style radial,
-- plus "holster" (whatever is in the hands goes away: a gun, the fists, the blades).
-- It opens with empty pockets too: putting the fists down needs no weapon. The page draws it and picks with the mouse; releasing the key
-- commits the choice (server operation `select`). While it is open the mouse goes to
-- the page, so the camera holds still, and the keyboard stays with the game, so the
-- player keeps moving and the key release still reaches this mapping.
local PAGE = "lightrp:ui:weaponwheel"
local Ui = LightRpUi
local Wheel = { open = false, key = "TAB" }
LightRpWeaponWheel = Wheel
-- A release sooner than TAP_MS after the press is a tap (or the release the client
-- synthesizes when the page takes the cursor): the wheel stays open ("latched") and a
-- click or the key again picks. A latched wheel nobody answers closes after LATCH_MS.
-- `isDown` only counts as release evidence once it has read the key down during this
-- opening: a client whose key state misses the consumed key read it "up" at once, and
-- the safety loop closed the wheel 0.4 s after it opened (Jeremzzzer, 2026-11-02).
local TAP_MS, LATCH_MS = 250, 15000
local openedAt, latched, sawDown = 0, false, false
Wheel.TAP_MS, Wheel.LATCH_MS = TAP_MS, LATCH_MS

-- The game's own UI sounds (Wwise events, the game's mixer), posted like the vanilla
-- menus post them: Open77.sfx.play2d (permission world.effects).
local SFX = {
    open = "ui_radial_menu_open",               -- the game's radial menu
    hover = "ui_menu_hover",                    -- one slot to the next
    equip = "ui_menu_item_weapon_equip",        -- a weapon chosen
    unarmed = "ui_menu_item_weapon_unequip",    -- hands emptied
    close = "ui_radial_menu_close",
}
Wheel.SFX = SFX
local warned = false
local function sound(name)
    local event = SFX[name]
    if not event or not (Open77.sfx and type(Open77.sfx.play2d) == "function") then return end
    local ok, played, why = pcall(Open77.sfx.play2d, event)
    if (not ok or played == false) and not warned then
        warned = true
        Ui.log("weapon wheel sound %s refused: %s", event, tostring(ok and why or played))
    end
end

-- Nothing else may own the input, and the character must stand on its own feet.
local function allowed()
    if Ui.loadingScreen and Ui.loadingScreen() then return false end
    if not Ui.page or not Ui.characterReady or Ui.creationActive or Ui.menuOpen or Ui.promptActive or Ui.actionFocus or Ui.supportMode then return false end
    for _, open in pairs(Ui.dialogs or {}) do if open then return false end end
    if LightRpMissionEditor and LightRpMissionEditor.active then return false end
    if LightRpSafezones and LightRpSafezones.active then return false end
    if LightRpFreecam and LightRpFreecam.isActive and LightRpFreecam.isActive() then return false end
    if LightRpMedical and LightRpMedical.isActive() then return false end
    local c = Open77.character.state()
    if not (c and c.alive and c.attached) or (c.vehicle and c.vehicle.mounted) then return false end
    -- No armament state is no reason to refuse: the holster slot works without one.
    return true
end
Wheel.allowed = allowed
-- the first owner that refuses, for the log (same order as allowed)
function Wheel.refusal()
    if not Ui.page then return "no page" end
    if Ui.loadingScreen and Ui.loadingScreen() then return "loading screen" end
    for _, k in ipairs({ "characterReady", "creationActive", "menuOpen", "promptActive", "actionFocus", "supportMode" }) do
        local v = Ui[k]
        if (k == "characterReady" and not v) or (k ~= "characterReady" and v) then return k .. "=" .. tostring(v) end
    end
    for name, open in pairs(Ui.dialogs or {}) do if open then return "dialog " .. tostring(name) end end
    if LightRpMissionEditor and LightRpMissionEditor.active then return "mission editor" end
    if LightRpSafezones and LightRpSafezones.active then return "safezones" end
    if LightRpFreecam and LightRpFreecam.isActive and LightRpFreecam.isActive() then return "freecam" end
    if LightRpMedical and LightRpMedical.isActive() then return "medical" end
    local c = Open77.character.state()
    if not c then return "no character state" end
    return string.format("alive=%s attached=%s mounted=%s", tostring(c.alive), tostring(c.attached), tostring(c.vehicle and c.vehicle.mounted))
end

local function close(commit, reason)
    if not Wheel.open then return end
    Wheel.open = false
    Ui.log("weapon wheel closed (%s, %s)", commit and "commit" or "cancel", tostring(reason))
    if Ui.page and not Ui.menuOpen and not Ui.promptActive and not Ui.actionFocus then Ui.page:setFocus(false, false) end
    Ui.send(PAGE, { kind = commit and "commit" or "cancel", reason = reason })
    sound("close")
end
Wheel.close = close

local function keyDown()
    if not (Open77.input and type(Open77.input.isDown) == "function") then return nil end
    local ok, down = pcall(Open77.input.isDown, Wheel.key)
    if ok and type(down) == "boolean" then return down end
    return nil
end

local function openWheel()
    -- the key again on a latched wheel picks the aimed slot
    if Wheel.open then
        if latched then close(true, "toggle") end
        return
    end
    if not allowed() then Ui.log("weapon wheel refused: %s", Wheel.refusal()); return end
    -- the mouse only: movement keys stay with the game
    local ok, why = Ui.page:setFocus(false, true)
    if not ok then Ui.log("weapon wheel focus refused: %s", tostring(why)); return end
    Wheel.open, openedAt, latched, sawDown = true, GetGameTimer(), false, keyDown() == true
    Ui.send(PAGE, { kind = "open", key = Wheel.key })
    Ui.log("weapon wheel open (key %s, down %s)", tostring(Wheel.key), tostring(sawDown))
    -- the pockets may have changed since the last push (a purchase, a gift)
    if LightRpArmamentClient and LightRpArmamentClient.refresh then LightRpArmamentClient.refresh() end
    sound("open")
end
Wheel.openWheel = openWheel

local function released()
    if not Wheel.open then return end
    -- a tap: the wheel stays open, a click or the key again picks
    if not latched and GetGameTimer() - openedAt < TAP_MS then
        -- the key read down at the press proves nothing now: only a key still (or again)
        -- down after the latch (a synthesized release) makes a later "up" a release
        latched, sawDown = true, false
        Ui.log("weapon wheel latched (released after %d ms)", GetGameTimer() - openedAt)
        Ui.send(PAGE, { kind = "latch", key = Wheel.key })
        return
    end
    close(true, "release")
end
Wheel.released = released
function Wheel.latched() return Wheel.open and latched end

-- The safety loop's view of the key: a release the mapping never delivered (focus
-- change, alt-tab) commits, but only once the key was seen down; a wheel with no
-- proof of a held key (latched, or a key state that never reads down) times out.
local function watch()
    if not Wheel.open then return end
    if not allowed() then close(false, "interrupted"); return end
    local now, down = GetGameTimer(), keyDown()
    if down == true then sawDown = true
    elseif down == false and sawDown and now - openedAt > 350 then close(true, "released"); return end
    if not sawDown and now - openedAt > LATCH_MS then close(false, "timeout") end
end
Wheel.watch = watch

function Wheel.bind(page)
    page:on(PAGE, function(p)
        if type(p) ~= "table" then return end
        if p.kind == "hover" then sound("hover")
        elseif p.kind == "chosen" then sound(p.unarmed == true and "unarmed" or "equip")
        elseif p.kind == "holster" then TriggerServerEvent("op77_lightrp:armament:holster")
        elseif p.kind == "close" then close(p.commit == true, "page") end
    end)
    local key = LightRpConfig.keys.weaponWheel
    local ok, effective = RegisterKeyMapping({ id = key.id, name = key.name, key = key.key, hold = true, consume = true,
        onPressed = openWheel, onReleased = released })
    if ok and type(effective) == "string" and effective ~= "" then Wheel.key = effective
    elseif not ok then Ui.log("weapon wheel mapping refused: %s", tostring(effective)) end
    CreateThread(function()
        while true do
            Wait(120)
            watch()
        end
    end)
end

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() and Wheel.open and Ui.page then Wheel.open = false; Ui.page:setFocus(false, false) end
end)
