-- Inventory key (I): asks the server to open the player's inventory; the server
-- decides what sits on the right (trunk, pile, or the ground). The page closes
-- itself (Escape / I) and tells the server through inventory.close.
local E = LightRpEvents
local Config = LightRpConfig
local Inventory = {}
LightRpInventory = Inventory

local function log(format, ...) LightRpUi.log(format, ...) end

function Inventory.open()
    if LightRpUi.dialogs and LightRpUi.dialogs.inventory then
        LightRpUi.send(E.page.dialogClose, { kind = "inventory" })
        return
    end
    local accepted, reason = TriggerServerEvent(E.net.action, { type = "inventory.open" })
    if not accepted then log("inventory.open refused: %s", tostring(reason)) end
end

function Inventory.bind()
    local key = Config.keys.inventory
    if key == nil then return end
    local ok, effective = RegisterKeyMapping(key.id, key.name, key.key, function() Inventory.open() end)
    if ok then log("inventory bound to %s", tostring(effective)) else log("inventory key mapping failed: %s", tostring(effective)) end
end

-- Server -> page: fresh snapshots of the inventories on screen.
RegisterNetEvent(E.net.inventory, function(payload) LightRpUi.send(E.page.inventory, payload) end)
