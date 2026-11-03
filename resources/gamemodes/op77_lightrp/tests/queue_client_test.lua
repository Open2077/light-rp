-- The queue panel, client side (client/core/queue.lua): the cancel key's mapping and
-- request, its guards, the effective key name added to the "queue" patches and sent
-- again on a rebind, the relay in client/core/ui.lua.
dofile("shared/config.lua")
dofile("shared/events.lua")
local E = LightRpEvents
local handlers, mappings, sent, pageSent, logs = {}, {}, {}, {}, {}
local clock = 10000
AddEventHandler = function(name, fn) handlers[name] = fn end
TriggerServerEvent = function(name, payload) sent[#sent + 1] = { name = name, payload = payload }; return true end
RegisterKeyMapping = function(id, name, key, fn) mappings[id] = { name = name, key = key, fn = fn }; return true, key end
GetGameTimer = function() return clock end
local bound = {}
Open77 = { input = { keyFor = function(id) return bound[id] end } }
LightRpUi = { characterReady = true, dialogs = {}, log = function(...) logs[#logs + 1] = string.format(...) end,
    send = function(name, payload) pageSent[#pageSent + 1] = { name = name, payload = payload } end }
local Ui = LightRpUi
dofile("client/core/queue.lua")
local Queue = LightRpQueue

local KEY = LightRpConfig.keys.queueLeave
assert(KEY.id == "lightrp.queue.leave" and KEY.name == "Light RP: leave queue" and KEY.key == "U")
local mapping = mappings["lightrp.queue.leave"]
assert(mapping and mapping.key == "U" and mapping.name == "Light RP: leave queue", "registered, U by default")
-- U is no other Light RP binding
for name, key in pairs(LightRpConfig.keys) do
    if name ~= "queueLeave" then assert(key.key ~= "U" and key.id ~= KEY.id, name .. " already takes U") end
end

-- not queued: the key does nothing
mapping.fn()
assert(#sent == 0, "no queue, no request")

-- a "queue" patch: kept, and the effective key name rides along
local patch = { queue = { v = 1, id = "chase.1v1", label = "NCPD Chase", count = 1, need = 2, sinceMs = 0, state = "waiting" } }
Queue.sync(patch)
assert(Queue.state == patch.queue and patch.queueKey == "U")
mapping.fn()
assert(#sent == 1 and sent[1].name == E.net.action and sent[1].payload.type == "queue.leave" and sent[1].payload.from == "key")
-- one press, one request
mapping.fn()
assert(#sent == 1, "a second press within 750 ms is ignored")
clock = clock + 800

-- guards: a window, the player menu, a prompt, no character
for _, setup in ipairs({
    function() Ui.dialogs.shop = true end, function() Ui.menuOpen = true end,
    function() Ui.promptActive = true end, function() Ui.characterReady = false end, function() Ui.actionFocus = true end,
}) do
    setup()
    mapping.fn()
    assert(#sent == 1, "busy: the key waits")
    Ui.dialogs.shop, Ui.menuOpen, Ui.promptActive, Ui.characterReady, Ui.actionFocus = false, false, false, true, nil
end
mapping.fn()
assert(#sent == 2, "free again")
clock = clock + 800

-- a rebind shows on the panel without resending the queue (its times stay the server's)
bound["lightrp.queue.leave"] = "K"
handlers["open77:keybinds:changed"]()
local last = pageSent[#pageSent]
assert(last.name == E.page.state and last.payload.queueKey == "K" and last.payload.queue == nil)
patch = { queue = { v = 1, id = "turf.war", label = "Turf War", count = 3, need = 4, sinceMs = 0, state = "waiting" } }
Queue.sync(patch)
assert(patch.queueKey == "K")
-- unbound: false (the page points at F1)
bound["lightrp.queue.leave"] = ""
handlers["open77:keybinds:changed"]()
assert(pageSent[#pageSent].payload.queueKey == false, "a cleared binding: no key on the panel")
bound["lightrp.queue.leave"] = nil
handlers["open77:keybinds:changed"]()
assert(pageSent[#pageSent].payload.queueKey == "U", "not known yet: the default name")

-- out of the queue: the key stops
Queue.sync({ queue = false })
assert(Queue.state == nil)
mapping.fn()
assert(#sent == 2, "no queue, no request")
-- a patch without the key leaves the state alone
Queue.sync({ party = {} })
assert(Queue.state == nil)

-- a failed send says so on the page
Queue.sync({ queue = { v = 1, id = "missions", label = "Data Heist", count = 1, need = 2, sinceMs = 0, state = "waiting" } })
TriggerServerEvent = function() return false, "offline" end
assert(Queue.press() == false)
assert(pageSent[#pageSent].name == E.page.result and pageSent[#pageSent].payload.ok == false)

-- client/core/ui.lua hands "queue" patches to Queue.sync before the page
local ui = assert(io.open("client/core/ui.lua", "r")):read("a")
assert(ui:find("patch.queue ~= nil and LightRpQueue then LightRpQueue.sync(patch)", 1, true), "ui.lua relays the queue through Queue.sync")
local manifest = assert(io.open("open77.lua", "r")):read("a")
assert(manifest:find('client_script "client/core/queue.lua"', 1, true) and manifest:find('server_script "server/modules/activity_queue.lua"', 1, true))
assert(manifest:find('client/core/ui.lua', 1, true) < manifest:find('client/core/queue.lua', 1, true))

print("PASS: leave key mapped (U, free), request on press, one per 750 ms, guards (window, menu, prompt, no character, focus), "
    .. "effective key on patches and on rebind, unbound fallback, no queue no request, failed send, ui.lua relay, manifest")
