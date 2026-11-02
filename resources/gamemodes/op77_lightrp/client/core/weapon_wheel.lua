-- The weapon wheel (hold CTRL): every weapon in the pockets on a GTA-style radial,
-- plus "unarmed". The page draws it and picks with the mouse; releasing the key
-- commits the choice (server operation `select`). While it is open the mouse goes to
-- the page, so the camera holds still, and the keyboard stays with the game, so the
-- player keeps moving and the key release still reaches this mapping.
local PAGE = "lightrp:ui:weaponwheel"
local Ui = LightRpUi
local Wheel = { open = false, key = "CTRL" }
LightRpWeaponWheel = Wheel
local playing = {}
local openedAt = 0

local function sound(name, volume)
    if not (Open77.audio and type(Open77.audio.play2D) == "function") then return end
    if playing[name] then pcall(Open77.audio.destroy, playing[name]); playing[name] = nil end
    local ok, id = pcall(Open77.audio.play2D, "assets/audio/wheel_" .. name .. ".wav", { volume = volume or 0.5 })
    if ok and id then playing[name] = id end
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
    if not commit then sound("cancel", 0.3) end
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
    sound("open", 0.38)
end
Wheel.openWheel = openWheel

function Wheel.bind(page)
    page:on(PAGE, function(p)
        if type(p) ~= "table" then return end
        if p.kind == "hover" then sound("tick", 0.3)
        elseif p.kind == "chosen" then sound("select", 0.5)
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
