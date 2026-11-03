-- The guide NPC, client side (server/modules/guide.lua decides everything):
--   * relays the `guide` messages (search index, topics) to the page, with the
--     player's effective key names, so an answer says "press I" with the key the
--     player actually bound (Pause > Settings > Key bindings);
--   * ALT + click on Johnny (open77_contextmenu): "Talk to Johnny", the same as E.
local E, Ui = LightRpEvents, LightRpUi
local resource = GetCurrentResourceName()

local Guide = { npcId = nil, name = "Johnny Silverhand", label = "Talk to Johnny", bindings = {} }
LightRpGuideClient = Guide

-- name -> key the player sees: the bound key of the binding id, else its default.
-- The ALT + click key belongs to open77_contextmenu: tutorial_context.lua reads it
-- from that resource (getActivationKey) and publishes it as LightRpTutorial.contextKey.
local function effectiveKeys()
    local out = {}
    for name, binding in pairs(Guide.bindings) do
        local key = binding.id and Open77.input and Open77.input.keyFor and Open77.input.keyFor(binding.id) or nil
        out[name] = key or binding.key
    end
    local context = LightRpTutorial and LightRpTutorial.contextKey
    if type(context) == "string" and context ~= "" and out.context then out.context = context end
    return out
end

RegisterNetEvent(E.net.guide, function(payload)
    if type(payload) ~= "table" then return end
    if type(payload.npc) == "table" then
        Guide.npcId = payload.npc.id
        if type(payload.npc.name) == "string" then Guide.name = payload.npc.name end
        if type(payload.npc.prompt) == "string" then Guide.label = payload.npc.prompt end
        if payload.revision == nil then return end -- only who Johnny is: nothing for the page
    end
    if type(payload.keys) == "table" then
        local bindings = {}
        for name, binding in pairs(payload.keys) do
            if type(binding) == "table" and type(binding.key) == "string" then bindings[name] = { key = binding.key, id = binding.id } end
        end
        Guide.bindings = bindings
        payload.keys = nil
    end
    payload.effectiveKeys = effectiveKeys()
    Ui.send(E.page.guide, payload)
end)

AddEventHandler("open77:keybinds:changed", function()
    if next(Guide.bindings) ~= nil then Ui.send(E.page.guide, { effectiveKeys = effectiveKeys() }) end
end)

-- ---------------------------------------------------------------------------
-- ALT + click

local function busy()
    if not Ui.characterReady or Ui.actionFocus or Ui.menuOpen or Ui.promptActive then return true end
    for _, open in pairs(Ui.dialogs or {}) do if open then return true end end
    return false
end

local function isJohnny(context)
    if GetInvokingResource() ~= "open77_contextmenu" or type(context) ~= "table" then return false end
    local t = context.target
    if type(t) ~= "table" or t.kind ~= "npc" or t.npcId == nil or Guide.npcId == nil then return false end
    return tostring(t.npcId) == tostring(Guide.npcId) and not busy()
end

exports("guideContextAvailable", function(context) return isJohnny(context) end)
exports("guideContextSelect", function(context)
    if not isJohnny(context) then return false end
    local ok, reason = TriggerServerEvent(E.net.action, { type = "guide.open", from = "context" })
    if not ok then Ui.send(E.page.result, { ok = false, text = "Could not reach " .. Guide.name .. ": " .. tostring(reason), action = "guide.open" }) end
    return ok == true
end)

local function register()
    local definitions = {
        { id = "guide.talk", label = Guide.label, icon = "person", order = 1, distance = 6,
            canInteract = "guideContextAvailable", onSelect = "guideContextSelect" },
    }
    local pending, reason = Open77.exports.call("open77_contextmenu", "registerNpcs", definitions)
    local tokens
    if pending then tokens, reason = pending:await() end
    if not tokens then Ui.log("guide context registration failed: %s", tostring(reason)); return end
    Ui.log("guide context ready")
end
AddEventHandler("onClientResourceStart", function(name)
    if name == resource or name == "open77_contextmenu" then register() end
end)
