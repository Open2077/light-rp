-- Inventory key (I): asks the server to open the player's inventory; the server
-- decides what sits on the right (trunk, pile, or the ground). The page closes
-- itself (Escape / I) and tells the server through inventory.close.
local E = LightRpEvents
local Config = LightRpConfig
local Inventory = {}
LightRpInventory = Inventory

local function log(format, ...) LightRpUi.log(format, ...) end

local lastPress = 0

-- Native input opens the inventory. Once it captures the keyboard, the WebUI
-- handles the same binding on key-up (except while typing in a text field).
function Inventory.open()
    if LightRpUi.dialogs and LightRpUi.dialogs.support then return end
    if LightRpRefueling and LightRpRefueling.isActive() then return end
    if LightRpConsumables and LightRpConsumables.isActive() then return end
    if LightRpActions and LightRpActions.isActive() then return end
    local now = GetGameTimer and GetGameTimer() or (os and os.clock() * 1000) or 0
    if now - lastPress < 350 then return end
    lastPress = now
    if LightRpUi.dialogs and LightRpUi.dialogs.inventory then
        LightRpUi.send(E.page.dialogClose, { kind = "inventory" })
        return
    end
    local accepted, reason = TriggerServerEvent(E.net.action, { type = "inventory.open" })
    if not accepted then log("inventory.open refused: %s", tostring(reason)) end
end

function Inventory.closed()
    -- Do not let a native callback queued before focus release immediately
    -- reopen the inventory after its WebUI close action.
    lastPress = GetGameTimer and GetGameTimer() or (os and os.clock() * 1000) or 0
end

function Inventory.bind()
    local key = Config.keys.inventory
    if key == nil then return end
    local ok, effective = RegisterKeyMapping(key.id, key.name, key.key, function() Inventory.open() end)
    if ok then log("inventory bound to %s", tostring(effective)) else log("inventory key mapping failed: %s", tostring(effective)) end
end

-- Server -> page: fresh snapshots of the inventories on screen.
RegisterNetEvent(E.net.inventory, function(payload) LightRpUi.send(E.page.inventory, payload) end)
