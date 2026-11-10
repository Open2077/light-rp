-- Dynamic rows (1.3.0): validation, the real controller payload, the re-offered row check
-- on select and the key handed to onSelect. Lua 5.4, from the resource folder:
--   lua tests/rows.test.lua
-- payload, the re-offered row check on select and the key handed to onSelect.
dofile("client/registry.lua")
local R = ContextMenuRegistry
local registry = R.new(function() return true end)
assert(registry.register("lightrp", 1, { id = "t", label = "Table", onSelect = "s", rows = "bad name" }) == nil)
assert(registry.register("lightrp", 1, { id = "t", label = "Table", onSelect = "s", rows = "tableRows" }))
local ok = R.dynamicRows({ title = "Roulette", rows = {
    { key = "spin", label = "Spin" },
    { key = "bet.number:0", label = "Zero", description = "Pays 35 to 1", submenu = { id = "bet", label = "Bet 10" } },
} }, 24)
assert(ok and ok.title == "Roulette" and #ok.rows == 2 and ok.rows[2].submenu.label == "Bet 10" and ok.rows[1].danger == false)
assert(#R.dynamicRows({ rows = {} }, 24).rows == 0 and #R.dynamicRows({}, 24).rows == 0, "no rows is an empty menu")
assert(#R.dynamicRows({ rows = { { key = "a", label = "A" }, { key = "b", label = "B" } } }, 1).rows == 1, "capped at max")
for _, invalid in ipairs({
    "rows", { rows = "x" }, { title = string.rep("t", 41), rows = {} },
    { rows = { { key = "a", label = "A" }, { key = "a", label = "B" } } },
    { rows = { { key = "a b", label = "A" } } }, { rows = { { key = "a", label = "" } } },
    { rows = { { key = "a", label = "A", icon = "package" } } },
    { rows = { { key = "a", label = "A", danger = "yes" } } },
    { rows = { { key = "a", label = "A", submenu = { id = "x", label = "X", owner = "y" } } } },
    { rows = { [1] = { key = "a", label = "A" }, [3] = { key = "b", label = "B" } } },
}) do assert(R.dynamicRows(invalid, 24) == nil, "invalid rows refused") end

-- Real controller (client/main.lua) with the same harness as the submenu test.
local callbacks, handlers, pageEvents, messages = {}, {}, {}, {}
local invoked, generation, focused = "lightrp", 1, false
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
    time = { monotonic = function() return 1 end },
    resource = { generation = function() return generation end },
    input = { keyFor = function() return "ALT" end, isDown = function() return true end,
        isCaptured = function() return false end, cursor = function() return { x = .5, y = .5, inBounds = true } end,
        setNativeActionBlocked = function() return true end },
    character = { state = function() return { attached = true, alive = true, health = 100, position = { x = 0, y = 0, z = 0 } } end },
    players = { allowAim = function() return true end, allowShoot = function() return true end,
        allowInteraction = function() return true end, freezeRotation = function() return true end, resetControls = noop },
    camera = { screenRaycast = function() return { hit = true, entityLookupAvailable = true, position = { x = 1, y = 0, z = 0 },
        target = { kind = "prop", propId = "42", networked = false } } end },
}
local offered = { { key = "spin", label = "Spin" }, { key = "bet.red", label = "Red", submenu = { id = "bet", label = "Bet 10" } } }
local calls, selected = {}, nil
Open77.exports = { call = function(owner, name, context)
    calls[#calls + 1] = name
    return { status = function() return "resolved" end, await = function()
        if name == "tableRows" then return { title = "Roulette", rows = offered } end
        selected = { owner, name, context }; return true
    end }
end }
-- the menu surface (client/ui.lua on NativeUI) speaks the page API main.lua uses
ContextMenuUi = { create = function() return {
    send = function(_, name, payload) messages[name] = payload end,
    on = function(_, name, fn) pageEvents[name] = fn end,
    setFocus = function(_, value) focused = value; return true end,
    hasFocus = function() return focused end, hide = noop, show = noop,
} end }
dofile("shared/config.lua")
dofile("client/main.lua")
handlers.onClientResourceStart("open77_contextmenu")
pageEvents["context:ready"]()
assert(callbacks.getVersion() == "1.4.0")
local token = assert(callbacks.registerProps({ id = "table", label = "Table", onSelect = "tableSelect", rows = "tableRows" }))
assert(callbacks.list()[1].id == "table", "one registration for every row")
local function open()
    callbacks.activate()
    pageEvents["context:pick"]({ epoch = messages["context:open"].epoch, x = .5, y = .5 })
    return assert(messages["context:menu"])
end
local menu = open()
assert(menu.title == "Roulette" and #menu.actions == 2, "rows and title reach the page")
assert(menu.actions[1].token == token .. "#spin" and menu.actions[2].submenu.id == "lightrp/bet", "row tokens and scoped folders")
assert(calls[#calls] == "tableRows" and selected == nil, "listing never selects")
-- A row no longer offered for the current state does not run.
offered = { { key = "spin", label = "Spin" } }
pageEvents["context:select"]({ epoch = menu.epoch, token = token .. "#bet.red" })
assert(selected == nil and messages["context:error"], "a stale row is refused")
-- A token never shown cannot be forged.
pageEvents["context:select"]({ epoch = menu.epoch, token = token .. "#forged" })
assert(selected == nil)
offered = { { key = "spin", label = "Spin" }, { key = "bet.red", label = "Red", submenu = { id = "bet", label = "Bet 10" } } }
pageEvents["context:select"]({ epoch = menu.epoch, token = token .. "#bet.red" })
assert(selected and selected[2] == "tableSelect" and selected[3].action.key == "bet.red" and selected[3].action.token == token)
assert(not focused, "a row selection releases focus")
print("PASS: dynamic rows validation, title, row tokens, stale-row refusal, key handed to onSelect")
