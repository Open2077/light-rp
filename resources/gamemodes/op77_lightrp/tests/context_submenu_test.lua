-- Generic submenu metadata plus real controller->WebUI payload, no game.
dofile("../../system/open77_contextmenu/client/registry.lua")
local registry = ContextMenuRegistry.new(function() return true end)
local function definition(menu)
    return { id = "cargo", label = "Open trunk", onSelect = "select", submenu = menu }
end
local menu = { id = "cargo", label = "Trunk & hood", icon = "interact" }
local token = assert(registry.register("lightrp", 1, definition(menu)))
menu.label = "Changed by caller"
assert(registry.get(token).submenu.label == "Trunk & hood", "registry copies metadata")
assert(registry.describe("lightrp", token).definition.submenu.id == "cargo")
local other = assert(registry.register("other", 1, definition({ id = "cargo", label = "Other menu" })))
assert(registry.get(other).owner == "other")
for _, invalid in ipairs({ false, "menu", {}, { id = "bad/id", label = "Name" }, { id = "valid", label = "" },
    { id = "valid", label = string.rep("a", 41) }, { id = "valid", label = "Name", icon = "invalid" },
    { id = "valid", label = "Name", owner = "lightrp" } }) do
    local result, reason = registry.register("lightrp", 1, definition(invalid))
    assert(result == nil and reason == "invalid_submenu")
end
local updated = assert(registry.update("lightrp", 1, token, { label = "Close trunk" }))
assert(registry.get(token) == nil and registry.get(updated).submenu.id == "cargo")

local callbacks, handlers, pageEvents, messages = {}, {}, {}, {}
local invoked, generation, time, focused = "lightrp", 1, 1, false
local noop = function() end
GetCurrentResourceName = function() return "open77_contextmenu" end
GetInvokingResource = function() return invoked end
GetInvokingResourceGeneration = function() return generation end
GetResourceState = function() return "running" end
exports = function(name, fn) callbacks[name] = fn end
AddEventHandler = function(name, fn) handlers[name] = fn end
RegisterKeyMapping = function(_, _, _, fn) callbacks.activate = fn end
CreateThread, TriggerEvent = noop, noop
Open77 = {
    time = { monotonic = function() return time end },
    resource = { generation = function() return generation end },
    input = { keyFor = function() return "ALT" end, isDown = function() return true end,
        isCaptured = function() return false end, cursor = function() return { x = .5, y = .5, inBounds = true } end,
        setNativeActionBlocked = function() return true end },
    character = { state = function() return { attached = true, alive = true, health = 100, position = { x = 0, y = 0, z = 0 } } end },
    players = { allowAim = function() return true end, allowShoot = function() return true end,
        allowInteraction = function() return true end, freezeRotation = function() return true end, resetControls = noop },
    camera = { screenRaycast = function() return { hit = true, entityLookupAvailable = true, position = { x = 1, y = 0, z = 0 },
        target = { kind = "vehicle", vehicleId = 10, engineEntity = "123", networked = true } } end },
}
local selected
Open77.exports = { call = function(owner, name, context)
    return { status = function() return "resolved" end, await = function()
        if name == "allowed" then return owner ~= "hidden" end
        selected = { owner, name, context }; return true
    end }
end }
WebUI = { create = function() return {
    send = function(_, name, payload) messages[name] = payload end,
    on = function(_, name, fn) pageEvents[name] = fn end,
    setFocus = function(_, value) focused = value; return true end,
    hasFocus = function() return focused end, hide = noop, show = noop,
} end }
dofile("../../system/open77_contextmenu/shared/config.lua")
dofile("../../system/open77_contextmenu/client/main.lua")
handlers.onClientResourceStart("open77_contextmenu")
pageEvents["context:ready"]()
local function register(owner)
    invoked = owner
    return assert(callbacks.register({ id = "trunk", label = "Open trunk", types = { "vehicle" },
        canInteract = "allowed", onSelect = "selected", submenu = { id = "cargo", label = "Trunk & hood" } }))
end
local first = register("lightrp")
register("other"); register("hidden")
callbacks.activate()
local epoch = messages["context:open"].epoch
pageEvents["context:pick"]({ epoch = epoch, x = .5, y = .5 })
local result = assert(messages["context:menu"])
assert(#result.actions == 2, "unavailable leaves never reach navigation")
local ids = {}
for _, row in ipairs(result.actions) do ids[row.submenu.id] = true end
assert(ids["lightrp/cargo"] and ids["other/cargo"], "folder IDs are provider-scoped")
assert(selected == nil, "rendering a submenu does not run an action")
pageEvents["context:select"]({ epoch = result.epoch, token = first })
assert(selected and selected[1] == "lightrp" and selected[2] == "selected" and selected[3].target.vehicleId == 10)
assert(not focused, "leaf selection releases focus for inventory")
print("PASS: submenu validation/copy/update; scoped folders; predicate filtering; real controller payload and leaf dispatch")
