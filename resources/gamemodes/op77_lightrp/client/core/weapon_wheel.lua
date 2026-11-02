-- The weapon wheel (hold CTRL): every weapon in the pockets on a GTA-style radial,
-- plus "unarmed". The page draws it and picks with the mouse; releasing the key
-- commits the choice (server operation `select`). While it is open the mouse goes to
-- the page, so the camera holds still, and the keyboard stays with the game, so the
-- player keeps moving and the key release still reaches this mapping.
local PAGE = "lightrp:ui:weaponwheel"
local Ui = LightRpUi
local Wheel = { open = false, key = "CTRL" }
LightRpWeaponWheel = Wheel
local openedAt = 0

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
    if not Ui.page or not Ui.characterReady or Ui.creationActive or Ui.menuOpen or Ui.promptActive or Ui.actionFocus or Ui.supportMode then return false end
    for _, open in pairs(Ui.dialogs or {}) do if open then return false end end
    if LightRpMissionEditor and LightRpMissionEditor.active then return false end
    if LightRpSafezones and LightRpSafezones.active then return false end
    if LightRpFreecam and LightRpFreecam.isActive and LightRpFreecam.isActive() then return false end
    if LightRpMedical and LightRpMedical.isActive() then return false end
    local c = Open77.character.state()
    if not (c and c.alive and c.attached) or (c.vehicle and c.vehicle.mounted) then return false end
    return LightRpArmamentClient ~= nil and LightRpArmamentClient.state() ~= nil
end
Wheel.allowed = allowed

local function close(commit, reason)
    if not Wheel.open then return end
    Wheel.open = false
    if Ui.page and not Ui.menuOpen and not Ui.promptActive and not Ui.actionFocus then Ui.page:setFocus(false, false) end
    Ui.send(PAGE, { kind = commit and "commit" or "cancel", reason = reason })
    sound("close")
end
Wheel.close = close

local function openWheel()
    if Wheel.open or not allowed() then return end
    -- the mouse only: movement keys stay with the game
    local ok, why = Ui.page:setFocus(false, true)
    if not ok then Ui.log("weapon wheel focus refused: %s", tostring(why)); return end
    Wheel.open, openedAt = true, GetGameTimer()
    Ui.send(PAGE, { kind = "open", key = Wheel.key })
    -- the pockets may have changed since the last push (a purchase, a gift)
    if LightRpArmamentClient.refresh then LightRpArmamentClient.refresh() end
    sound("open")
end
Wheel.openWheel = openWheel

function Wheel.bind(page)
    page:on(PAGE, function(p)
        if type(p) ~= "table" then return end
        if p.kind == "hover" then sound("hover")
        elseif p.kind == "chosen" then sound(p.unarmed == true and "unarmed" or "equip")
        elseif p.kind == "close" then close(p.commit == true, "page") end
    end)
    local key = LightRpConfig.keys.weaponWheel
    local ok, effective = RegisterKeyMapping({ id = key.id, name = key.name, key = key.key, hold = true, consume = true,
        onPressed = openWheel, onReleased = function() close(true, "release") end })
    if ok then Wheel.key = effective else Ui.log("weapon wheel mapping refused: %s", tostring(effective)) end
    CreateThread(function()
        while true do
            Wait(120)
            if Wheel.open then
                if not allowed() then close(false, "interrupted")
                -- a release the mapping never delivered (focus change, alt-tab): commit anyway
                elseif GetGameTimer() - openedAt > 350 and Open77.input and type(Open77.input.isDown) == "function"
                    and Open77.input.isDown(Wheel.key) == false then close(true, "released") end
            end
        end
    end)
end

AddEventHandler("onClientResourceStop", function(name)
    if name == GetCurrentResourceName() and Wheel.open and Ui.page then Wheel.open = false; Ui.page:setFocus(false, false) end
end)
