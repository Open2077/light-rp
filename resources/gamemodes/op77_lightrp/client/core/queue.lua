-- The queue panel, client side (server/modules/activity_queue.lua decides everything).
-- The page draws the panel from the "queue" state: client/core/ui.lua hands every patch
-- carrying it to Queue.sync first, which adds `queueKey`, the key really bound to
-- "Light RP: leave queue" (U by default, rebindable in Pause > Settings > Key bindings;
-- false when unbound: the panel then points at F1). The key leaves whatever queue the
-- panel shows; F1 > Leave queue sends the same request from the page.
local E, Ui = LightRpEvents, LightRpUi
local KEY = LightRpConfig.keys.queueLeave
local PRESS_GAP_MS = 750 -- one press, one request

local Queue = { state = nil }
LightRpQueue = Queue

-- The key's name: the binding, its default while the host does not know it yet, nil
-- when the player cleared it.
local function keyName()
    if not KEY then return nil end
    local bound = Open77 and Open77.input and Open77.input.keyFor and Open77.input.keyFor(KEY.id) or nil
    if bound == "" then return nil end
    return bound or KEY.key
end
Queue.keyName = keyName

-- client/core/ui.lua: every patch carrying "queue" passes here before the page gets it.
function Queue.sync(patch)
    if type(patch) ~= "table" or patch.queue == nil then return end
    Queue.state = type(patch.queue) == "table" and patch.queue or nil
    patch.queueKey = keyName() or false
end
AddEventHandler("open77:keybinds:changed", function()
    Ui.send(E.page.state, { queueKey = keyName() or false })
end)

-- Never while a window, the player menu or a prompt has the player's attention (the
-- menu has its own Leave queue line).
local function busy()
    if not Ui.characterReady or Ui.actionFocus or Ui.menuOpen or Ui.promptActive then return true end
    for _, open in pairs(Ui.dialogs or {}) do if open then return true end end
    return false
end

local lastPress = nil
function Queue.press()
    if not Queue.state or busy() then return false end
    local t = GetGameTimer()
    if lastPress and t - lastPress < PRESS_GAP_MS then return false end
    lastPress = t
    local ok, reason = TriggerServerEvent(E.net.action, { type = "queue.leave", from = "key" })
    if not ok then
        Ui.send(E.page.result, { ok = false, text = "Leaving the queue failed: " .. tostring(reason), action = "queue.leave" })
    end
    return ok == true
end

if KEY then
    local ok, effective = RegisterKeyMapping(KEY.id, KEY.name, KEY.key, function() Queue.press() end)
    if not ok then Ui.log("queue key %s refused: %s", KEY.id, tostring(effective)) end
end
