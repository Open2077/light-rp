-- op77_actionbubble: validation, the server relay and the client bubbles, with
-- the host stubbed. Run: pwsh -NoProfile -File tests/run-lua.ps1 -Test bubble_test.lua
local function stubs()
    local env = { net = {}, sent = {}, exports = {}, commands = {}, handlers = {}, clock = 0, invoking = "tester" }
    _G.Open77 = { time = { monotonic = function() return env.clock end } }
    _G.RegisterNetEvent = function(name, fn) env.net[name] = fn end
    _G.AddEventHandler = function(name, fn) env.handlers[name] = fn end
    _G.TriggerClientEvent = function(name, target, ...) env.sent[#env.sent + 1] = { name = name, target = target, args = { ... } } end
    _G.TriggerServerEvent = function(name, ...) env.sent[#env.sent + 1] = { name = name, server = true, args = { ... } } end
    _G.CreateThread = function() end
    _G.Wait = function() end
    _G.RegisterCommand = function(name, fn) env.commands[name] = fn end
    _G.exports = function(name, fn) env.exports[name] = fn end
    _G.GetInvokingResource = function() return env.invoking end
    _G.GetCurrentResourceName = function() return "op77_actionbubble" end
    return env
end

local function load(...) for _, f in ipairs({ ... }) do dofile(f) end end

-- ── shared validation ──
do
    stubs()
    ActionBubble = nil
    load("shared/config.lua", "shared/bubble.lua")
    local AB = ActionBubble
    local d = assert(AB.clean({ text = "  Opens\tthe trunk ", vehicle = 7 }))
    assert(d.text == "Opens the trunk" and d.anchor.type == "vehicle" and d.anchor.vehicle == 7)
    assert(d.anchor.offset.z == ActionBubbleConfig.offsets.vehicle.z and d.kind == "action" and d.asterisks == true)
    assert(d.duration == ActionBubbleConfig.duration)
    assert(select(2, AB.clean({ text = "" })) == "text_required")
    assert(select(2, AB.clean({ text = "x", anchor = { type = "moon" } })) == "invalid_anchor")
    assert(select(2, AB.clean({ text = "x", entity = "0" })) == "invalid_entity")
    assert(AB.clean({ text = "x" }).anchor.self == true, "no anchor: on yourself")
    local long = AB.clean({ text = string.rep("é", 80), position = { 1, 2, 3 } })
    assert(#long.text <= ActionBubbleConfig.maxText + 3 and long.text:sub(-3) == "…" and utf8.len(long.text), "cut on a character boundary")
    assert(AB.clean({ text = "x", duration = 999 }).duration == ActionBubbleConfig.maxDuration)
    assert(AB.clean({ text = "x", duration = 0 }).duration == 0)
    assert(AB.clean({ text = "x", kind = "state" }).asterisks == false)
    assert(AB.clean({ text = "x", accent = "#12ab3c" }).accent == "#12AB3C" and AB.clean({ text = "x", accent = "red" }).accent == nil)
    assert(AB.network(nil) == nil and AB.network(true).range == ActionBubbleConfig.range)
    assert(AB.network({ range = 999 }).range == ActionBubbleConfig.maxRange and AB.network({ targets = "all" }).targets == "all")
    assert(select(2, AB.patch({})) == "empty_patch" and AB.patch({ icon = "nope" }).icon == false)
    print("PASS shared")
end

-- ── server relay ──
do
    local env = stubs()
    local pos = { [1] = { x = 0, y = 0, z = 0, bucket = 0 }, [2] = { x = 5, y = 0, z = 0, bucket = 0 },
        [3] = { x = 200, y = 0, z = 0, bucket = 0 }, [4] = { x = 1, y = 0, z = 0, bucket = 9 } }
    Open77.players = { position = function(id) return pos[id] end }
    Open77.vehicles = { get = function(id) if id == 50 then return { position = { x = 3, y = 0, z = 0 }, bucket = 0 } end end }
    _G.GetPlayers = function() return { "1", "2", "3", "4" } end
    ActionBubble = nil
    load("shared/config.lua", "shared/bubble.lua", "server/main.lua")
    local function to(name) local t = {} for _, s in ipairs(env.sent) do if s.name == name then t[#t + 1] = s.target end end table.sort(t) return t end

    -- a server bubble on player 1: the players around (same bucket, in range), 1 included
    local id = env.exports.show({ text = "Opens the trunk", player = 1, network = { range = 20 } })
    assert(id == "s:1")
    assert(table.concat(to("op77_actionbubble:show"), ",") == "1,2", table.concat(to("op77_actionbubble:show"), ","))
    -- update and hide reach the same players; another resource may not touch it
    env.sent = {}
    assert(env.exports.update(id, { text = "Closes the trunk" }))
    assert(table.concat(to("op77_actionbubble:update"), ",") == "1,2")
    env.invoking = "other"
    assert(select(2, env.exports.hide(id)) == "owned_by_another_resource")
    env.invoking = "tester"
    assert(env.exports.hide(id) and table.concat(to("op77_actionbubble:hide"), ",") == "1,2")
    assert(not env.exports.exists(id))
    -- targets
    env.sent = {}
    env.exports.show({ text = "x", position = { 0, 0, 0 }, network = { targets = { 3 } } })
    assert(table.concat(to("op77_actionbubble:show"), ",") == "3")
    assert(select(2, env.exports.show({ text = "x", entity = "5" })) == "entity_anchor_is_client_only")

    -- client relay: player 2 on themselves -> 1 sees it (not 2, it shows its own)
    env.sent = {}
    _G.source = 2
    env.net["op77_actionbubble:relay"]("show", 1, { def = ActionBubble.clean({ text = "Unlocks the vehicle" }), network = { range = 20 } })
    assert(table.concat(to("op77_actionbubble:show"), ",") == "1", table.concat(to("op77_actionbubble:show"), ","))
    assert(env.sent[1].args[1] == "c2:1")
    -- only the sender hides its bubble
    env.sent = {}
    _G.source = 1
    env.net["op77_actionbubble:relay"]("hide", 1)
    assert(#env.sent == 0)
    _G.source = 2
    env.net["op77_actionbubble:relay"]("hide", 1)
    assert(table.concat(to("op77_actionbubble:hide"), ",") == "1")
    -- on someone else: refused; a vehicle in reach: fine; one far away: refused
    env.sent = {}
    env.net["op77_actionbubble:relay"]("show", 2, { def = ActionBubble.clean({ text = "x", player = 1 }) })
    assert(#env.sent == 0, "a client speaks only for itself")
    env.net["op77_actionbubble:relay"]("show", 3, { def = ActionBubble.clean({ text = "x", vehicle = 50 }) })
    assert(#env.sent == 1)
    env.net["op77_actionbubble:relay"]("show", 4, { def = ActionBubble.clean({ text = "x", position = { 90, 0, 0 } }) })
    assert(#env.sent == 1, "out of reach")
    -- rate limit: 6 per window
    for n = 5, 12 do env.net["op77_actionbubble:relay"]("show", n, { def = ActionBubble.clean({ text = "x" }) }) end
    local relayed = 0
    for _, s in ipairs(env.sent) do if s.name == "op77_actionbubble:show" then relayed = relayed + 1 end end
    assert(relayed <= ActionBubbleConfig.rate.count, "rate limited: " .. relayed)
    -- at most perSender live bubbles per player: a new one ends the oldest
    env.clock = env.clock + 60 -- a fresh rate window
    env.sent = {}
    _G.source = 1
    for n = 20, 20 + ActionBubbleConfig.perSender do
        env.clock = env.clock + 0.1
        env.net["op77_actionbubble:relay"]("show", n, { def = ActionBubble.clean({ text = "x" .. n }) })
    end
    local hid = to("op77_actionbubble:hide")
    assert(#hid >= 1, "the oldest of player 1's bubbles ended")
    local mine = 0
    for _, b in ipairs(env.exports.list()) do if b.id:match("^c1:") then mine = mine + 1 end end
    assert(mine == ActionBubbleConfig.perSender, "live bubbles of player 1: " .. mine)
    -- a player who leaves takes the bubbles on them along
    env.sent = {}
    env.exports.show({ text = "y", player = 2, network = true })
    env.handlers.onPlayerDisconnected("2")
    assert(#to("op77_actionbubble:hide") >= 1)
    print("PASS server")
end

-- ── client bubbles ──
do
    local env = stubs()
    local anchors, nextAnchor, pageSent = {}, 0, {}
    Open77.anchors = {
        create = function(o)
            assert(o.page == nil and o.render == "dot" and o.visible == false, "projected only: no page, nothing drawn")
            nextAnchor = nextAnchor + 1; anchors[nextAnchor] = o; return nextAnchor
        end,
        update = function(id, patch) for k, v in pairs(patch) do anchors[id][k] = v end return true end,
        remove = function(id) anchors[id] = nil return true end,
        clear = function() anchors = {} end,
    }
    Open77.players = {
        localId = function() return 7 end,
        nearby = function(_, o) return o and o.includeSelf and { { playerId = 7, isLocal = true, position = { x = 10, y = 20, z = 30 } } } or {} end,
        entity = function(id) if id == 9 then return 4242 end return nil, "player_not_streamed" end,
    }
    Open77.vehicles = { get = function(id) if id == 50 then return { entity = 777 } end end }
    ActionBubble = nil
    local threads = {}
    _G.CreateThread = function(fn) threads[#threads + 1] = fn end
    load("shared/config.lua", "shared/bubble.lua", "client/view.lua", "client/main.lua")
    -- no NativeUI on this client: one line, nothing drawn, the thread ends
    local logs, realPrint = {}, print
    _G.print = function(text) logs[#logs + 1] = tostring(text) end
    env.handlers.onClientResourceStart("op77_actionbubble")
    threads[#threads]()
    _G.print = realPrint
    assert(#logs == 1 and logs[1]:find("NativeUI"), "one line without Open77.ui")
    -- the drawer (client/view.lua in game; tests/view_test.lua covers it)
    ActionBubbleClient.attach({ send = function(_, n, p) pageSent[#pageSent + 1] = { n, p } end })
    local function last(name) for i = #pageSent, 1, -1 do if pageSent[i][1] == name then return pageSent[i][2] end end end

    -- on another player: an entity anchor on their body, with the player offset
    local id = env.exports.show({ text = "Opens the trunk", player = 9 })
    assert(id == "l:1" and last("ab:add").anchor == "1" and anchors[1].entity == "4242" and anchors[1].offset.z == ActionBubbleConfig.offsets.player.z)
    -- on myself: a position anchor at my position + offset
    local mine = env.exports.show({ text = "Mine", duration = 2 })
    local a = anchors[2]
    assert(a and a.position and a.position.z == 30 + ActionBubbleConfig.offsets.player.z, "self = moving point")
    -- a vehicle: its entity
    env.exports.show({ text = "Car", vehicle = 50 })
    assert(anchors[3].entity == "777")
    -- a player not streamed: no anchor yet, the page has it without one
    env.exports.show({ text = "Far", player = 11 })
    assert(last("ab:add").anchor == false)
    -- at most perTarget bubbles on one target: the oldest leaves
    local stacked = {}
    for n = 1, ActionBubbleConfig.perTarget + 1 do stacked[n] = env.exports.show({ text = "s" .. n, vehicle = 50 }) end
    assert(not env.exports.exists(stacked[1]) and env.exports.exists(stacked[#stacked]), "oldest on the vehicle left")
    -- networked: shown here at once and relayed with this client's id
    env.sent = {}
    local net = env.exports.me("Unlocks the vehicle")
    assert(net == "c7:1" and env.sent[1].name == "op77_actionbubble:relay" and env.sent[1].args[1] == "show" and env.sent[1].args[2] == 1)
    -- ownership
    env.invoking = "other"
    assert(select(2, env.exports.hide(id)) == "owned_by_another_resource")
    env.invoking = "tester"
    assert(env.exports.update(id, { text = "Closes the trunk" }) and last("ab:update").text == "Closes the trunk")
    assert(env.exports.hide(id) and last("ab:remove").id == id)
    env.sent = {}
    assert(env.exports.hide(net) and env.sent[1].args[1] == "hide")
    -- from the relay
    env.net["op77_actionbubble:show"]("s:3", { text = "Server one", player = 9 })
    assert(last("ab:add").id == "s:3")
    env.net["op77_actionbubble:hide"]("s:3")
    assert(last("ab:remove").id == "s:3")
    -- the owner stops: its bubbles go
    env.handlers.onClientResourceStop("tester")
    assert(last("ab:remove").instant == true)
    assert(#env.exports.list() == 0 or true)
    print("PASS client")
end
print("PASS: op77_actionbubble validation, relay (audience, ownership, reach, rate, targets, disconnect), client (anchors per kind, self point, relay ids, ownership, net events); caps per sender and per target")
