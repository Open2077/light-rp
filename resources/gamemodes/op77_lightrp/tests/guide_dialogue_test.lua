-- Talking to Johnny (server/modules/guide_dialogue.lua, content in
-- server/config/guide_dialogue.lua): the tree's integrity (every choice leads to a
-- node, a FAQ answer, a topic or a real action; every node reachable; every
-- placeholder resolved, with every feature on and with the shipped config), short
-- pages, every message under the client's limits, the opening riding with the
-- guide dialog, lazy nodes, gating, the GPS kinds it adds and the Hall of Fame
-- panel. Run it three times: Lua 5.4 randomises `pairs`.
local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("a")
    f:close()
    return text
end

dofile("shared/events.lua")
dofile("shared/mission_defs.lua")
dofile("shared/config.lua")
dofile("shared/tutorial.lua")
dofile("shared/items.lua")
dofile("shared/medical.lua")
dofile("shared/jobs.lua")
dofile("shared/vehicle_customization.lua")
for _, file in ipairs({ "missions", "fixers", "job_runs", "delivery", "job_work", "garages", "vehicle_customization",
    "dealerships", "shops", "support", "housing", "cyberware", "activities", "economy", "halloffame", "dogtown", "guide", "guide_dialogue" }) do
    dofile("server/config/" .. file .. ".lua")
end

local noop = function() end
local interactions, dialogs, results, clientEvents, commands, actions, threads, logs = {}, {}, {}, {}, {}, {}, {}, {}
LightRP = {
    db = { ready = false, schema = noop, run = noop, read = function() return false end },
    module = function(name, value) value.name = name; LightRP[name] = value; return value end,
    stateProvider = noop, action = function(name, fn) actions[name] = fn end,
    command = function(name, options, fn) commands[name] = { options = options, fn = fn } end,
    state = noop, eachModule = noop, notice = noop,
    log = function(format, ...) logs[#logs + 1] = select("#", ...) > 0 and string.format(format, ...) or tostring(format) end,
    result = function(id, ok, text, action) results[#results + 1] = { id = id, ok = ok, text = text, action = action } end,
    dialog = function(id, kind, payload) payload.kind = kind; dialogs[#dialogs + 1] = { id = id, kind = kind, payload = payload } end,
    interaction = function(id, def) interactions[id] = def end,
    batchInteractions = function(fn) return fn() end,
    nowMs = function() return 1000 end,
    joinArgs = function(args) return table.concat(args, " ") end,
}
LightRP.characters = { switching = {}, get = function() return { identifier = "a", key = "default", status = "active" } end,
    displayName = function() return "Alex" end, isRegistered = function(id) return id ~= 9 end }
LightRP.missions = { point = function() return nil end, handlesDeath = function() return false end }
CreateThread = function(fn) threads[#threads + 1] = fn end
Wait = function(ms) if ms >= 60000 then error("stop-loop", 0) end end
SetTimeout = noop
AddEventHandler = noop
TriggerEvent = noop
exports = noop
GetPlayers = function() return { 1, 2 } end
GetPlayerRoutingBucket = function() return 0 end
local resourceStates = { open77_chimera = "missing" }
GetResourceState = function(name) return resourceStates[name] or "missing" end
TriggerClientEvent = function(name, id, payload) clientEvents[#clientEvents + 1] = { name = name, id = id, payload = payload } end
TriggerLatentClientEvent = function(name, id, rate, payload) error("nothing needs the latent transport") end

local hub = LightRpActivities.hub
local players = { [1] = { x = hub.center.x, y = hub.center.y, z = hub.center.z }, [2] = { x = 0, y = 0, z = 0 } }
Open77 = {
    players = {
        position = function(id)
            assert(type(id) == "number" and id > 0, "Open77.players.position throws for a non-player id")
            local p = players[id]
            return p and { x = p.x, y = p.y, z = p.z, bucket = 0 } or nil
        end,
        get = function(id) local p = players[id]; return p and { position = p, heading = 0, bucket = 0 } or nil end,
    },
    vehicles = {}, kvp = { get = noop, set = function() return true end, delete = noop },
    npcs = { damage = { invulnerable = "invulnerable" }, ai = { tasks = "tasks" }, create = function() return 42 end,
        setAIEnabled = function() return true end, setTransform = function() return true end, get = function(id) return { id = id } end, remove = noop },
}

dofile("server/modules/activities.lua")
dofile("server/modules/activities_hub.lua")
dofile("server/modules/guide.lua")
dofile("server/modules/guide_dialogue.lua")
local Guide, Talk, D, G = LightRP.guide, LightRP.guideDialogue, LightRpGuideDialogue, LightRpGuide
local registry = LightRP.activities.registry
local E = LightRpEvents
assert(Talk and Talk.enabled(), "the dialogue module is on")

-- Values the way the framework counts them; a JSON size for the byte limit.
local function countValues(value)
    if type(value) ~= "table" then return 1 end
    local n = 1
    for _, item in pairs(value) do n = n + 1 + countValues(item) end
    return n
end
local maxValues, maxBytes, measured = 0, 0, 0
local function measure(payload, what)
    local values, bytes = countValues(payload), Talk.jsonSize(payload)
    assert(values < 900, string.format("%s: %d values (limit 1024, framework margin 900)", what, values))
    assert(bytes < 40 * 1024, string.format("%s: %d bytes", what, bytes))
    maxValues, maxBytes, measured = math.max(maxValues, values), math.max(maxBytes, bytes), measured + 1
end

-- ---------------------------------------------------------------------------
-- The config: every choice names one real target.
local faqQuestions, faqTopics = {}, {}
for _, topic in ipairs(G.topics) do
    faqTopics[topic.id] = topic
    for _, q in ipairs(topic.questions) do faqQuestions[q.id] = q end
end
local OPENS = { activities = true, contracts = true, crew = true, halloffame = true, jobguide = true, housing = true, support = true,
    animations = true, tutorial = true, briefing = true, faq = true, search = true }
local KINDS = { "to", "faq", "topic", "gps", "open" }
assert(D.nodes[D.root], "the root node exists")
local nodeCount = 0
for id, node in pairs(D.nodes) do
    nodeCount = nodeCount + 1
    assert(type(id) == "string" and not id:find(":", 1, true), id .. ": a config node id has no ':' (faq: and topic: are generated)")
    local said = node.variants or { node.say }
    assert(type(said) == "table" and #said > 0, id .. ": says something")
    for _, set in ipairs(said) do assert(type(set) == "table" and #set > 0, id .. ": a set of lines") end
    assert(type(node.choices) == "table" and #node.choices > 0, id .. ": offers choices")
    for i, c in ipairs(node.choices) do
        local where = id .. " choice " .. i
        assert(type(c[1]) == "string" and c[1] ~= "", where .. ": the player's line")
        local kinds = 0
        for _, k in ipairs(KINDS) do if c[k] ~= nil then kinds = kinds + 1 end end
        assert(kinds == 1, where .. ": exactly one of to / faq / topic / gps / open")
        if c.to then assert(D.nodes[c.to] and c.to ~= id, where .. ": node " .. tostring(c.to) .. " does not exist") end
        if c.faq then assert(faqQuestions[c.faq], where .. ": FAQ question " .. c.faq .. " does not exist") end
        if c.topic then assert(faqTopics[c.topic], where .. ": FAQ topic " .. c.topic .. " does not exist") end
        if c.gps then assert(type(Guide.targets[c.gps]) == "function", where .. ": GPS kind " .. c.gps .. " does not exist") end
        if c.open then
            assert(OPENS[c.open], where .. ": unknown panel " .. tostring(c.open))
            if c.open == "faq" then assert(faqQuestions[c.id], where .. ": open faq needs a question id") end
        end
    end
end
-- every node of the config is reachable from the root
local reachable, queue = { [D.root] = true }, { D.root }
while #queue > 0 do
    local id = table.remove(queue, 1)
    for _, c in ipairs(D.nodes[id].choices) do
        if c.to and not reachable[c.to] then reachable[c.to] = true; queue[#queue + 1] = c.to end
    end
end
for id in pairs(D.nodes) do assert(reachable[id], id .. " is never reached from " .. D.root) end
-- five to seven first-level choices, the last one the rest of the FAQ
local first = D.nodes[D.root].choices
assert(#first >= 5 and #first <= 7, "5 to 7 first-level choices: " .. #first)
assert(first[#first].to == "other" and first[#first][1]:find("Something else", 1, true), "the last one is Something else")
-- the search stays one branch away
local searchAt = {}
for id, node in pairs(D.nodes) do for _, c in ipairs(node.choices) do if c.open == "search" then searchAt[id] = true end end end
assert(searchAt.other, "Something else ends with the search")

-- wording: a game writer's, not a manual's
local source = assert(readFile("server/config/guide_dialogue.lua"))
assert(not source:lower():find("keanu") and not source:lower():find("reeves"), "never the actor's name")
assert(not source:find("[\240-\244]"), "no emoji (no 4-byte UTF-8 character)")
assert(source:sub(1, 3) ~= "\239\187\191" and assert(readFile("server/modules/guide_dialogue.lua")):sub(1, 3) ~= "\239\187\191", "no BOM")
local function eachText(fn)
    for id, node in pairs(D.nodes) do
        for _, set in ipairs(node.variants or { node.say }) do
            for _, line in ipairs(set) do fn(type(line) == "table" and line[1] or line, id, "line") end
        end
        for _, c in ipairs(node.choices) do fn(c[1], id, "choice") end
    end
    for _, line in ipairs(D.farewell or {}) do fn(line, "farewell", "line") end
end
eachText(function(text, id, kind)
    assert(type(text) == "string", id .. ": a gated line is { requires = ..., \"text\" }")
    assert(not text:find("lightrp%."), id .. ": a staff command in: " .. text)
    assert(not text:find("TODO") and not text:lower():find("great question"), id .. ": " .. text)
    assert(select(2, text:gsub("`", "")) % 2 == 0 and select(2, text:gsub("%*%*", "")) % 2 == 0, id .. ": unbalanced markup in: " .. text)
    if kind == "choice" then
        assert(Talk.plainLength(text) <= 44, id .. ": a choice is a short line: " .. text)
        assert(text:match("[%.%?!…]$"), id .. ": a choice ends like a sentence: " .. text)
    else
        assert(Talk.plainLength(text) <= 240, id .. ": a line Johnny says is short: " .. text)
    end
end)

-- ---------------------------------------------------------------------------
-- Paging
local pages = Talk.pages({ "a", "b", "c", "d", "e", "f", "g" })
assert(#pages == 3 and #pages[1] == 3 and #pages[3] == 1, "three lines a page")
pages = Talk.pages({ "short", string.rep("x", 400), "after" })
assert(#pages == 3 and pages[2][1]:sub(1, 1) == "x", "a long line gets its own page")
pages = Talk.pages({ "one", "two", "Here is the list:", "- a", "- b" })
assert(#pages == 2 and pages[1][2] == "two" and pages[2][1] == "Here is the list:", "a line ending with ':' opens the next page")
assert(Talk.sentence("Mark the Job Center") == "Mark the Job Center." and Talk.sentence("Why?") == "Why?")

-- ---------------------------------------------------------------------------
-- Walk the whole visible tree from the root: every choice leads to a node that
-- builds, every action is real, every line resolves, every message fits.
local pageTabs = { activities = true, contracts = true, crew = true }
local ACTS = { gps = true, activities = true, halloffame = true, faq = true, search = true, jobguide = true, housing = true,
    support = true, animations = true, tutorial = true, briefing = true }
local function walk(label)
    local built = Guide.build()
    local seen, order, todo = {}, {}, { D.root }
    seen[D.root] = true
    while #todo > 0 do
        local id = table.remove(todo, 1)
        local view = assert(Talk.node(id), label .. ": " .. id .. " is offered but does not build")
        assert(view.id == id, label .. ": " .. id .. " answers as " .. tostring(view.id))
        order[#order + 1] = view
        assert(#view.pages > 0, label .. ": " .. id .. " says nothing")
        for p, page in ipairs(view.pages) do
            assert(#page >= 1 and #page <= D.pageLines, label .. ": " .. id .. " page " .. p .. " has " .. #page .. " lines")
            for _, line in ipairs(page) do assert(not line:find("—", 1, true), label .. ": " .. id .. ": unresolved: " .. line) end
        end
        if D.nodes[id] then assert(#view.pages <= 2, label .. ": " .. id .. " is " .. #view.pages .. " pages: shorten it") end
        for _, c in ipairs(view.choices) do
            assert(type(c.label) == "string" and c.label ~= "" and not c.label:find("—", 1, true), label .. ": " .. id .. ": a choice's label: " .. tostring(c.label))
            assert((c.to ~= nil) ~= (c.act ~= nil), label .. ": " .. id .. ": a choice leads somewhere or acts")
            if c.to then
                assert(Talk.node(c.to), label .. ": " .. id .. ": " .. c.to .. " is a dead end")
                if not seen[c.to] then seen[c.to] = true; todo[#todo + 1] = c.to end
            else
                local a = c.act
                assert(ACTS[a.type], label .. ": " .. id .. ": unknown action " .. tostring(a.type))
                if a.type == "gps" then assert(Guide.resolveTarget(a.target, nil), label .. ": " .. id .. ": GPS " .. tostring(a.target) .. " has no place") end
                if a.type == "activities" then assert(pageTabs[a.tab], label .. ": " .. id .. ": tab " .. tostring(a.tab)) end
                if a.type == "faq" then assert(built.byId[a.id], label .. ": " .. id .. ": FAQ " .. tostring(a.id)) end
            end
        end
        for _, message in ipairs(Talk.messages(id)) do
            assert(message.talk.nodes and message.talk.nodes[1], label .. ": " .. id .. ": a node message")
            measure(message, label .. " node " .. id)
        end
    end
    return order, seen
end

-- every feature on and every activity provider registered: the gated lines resolve too
local savedFeatures = {}
for k, v in pairs(G.features) do savedFeatures[k] = v; G.features[k] = true end
registry["arena.ffa"] = { id = "arena.ffa", label = "Combat Zone" }
registry["race.trial"] = { id = "race.trial", label = "Time Trial" }
registry["chase.1v1"] = { id = "chase.1v1", label = "NCPD Chase" }
registry["turf.war"] = { id = "turf.war", label = "Turf War" }
LightRP.hallOfFame = { name = "hallOfFame", open = noop }
D.clinics = { { id = "test", name = "Test clinic", position = { x = 1, y = 2, z = 3 } } }
local allOn = walk("all on")
for id, node in pairs(D.nodes) do
    for _, set in ipairs(node.variants or { node.say }) do
        for _, line in ipairs(Guide.resolveLines(set, id .. ": ")) do assert(not line:find("—", 1, true), id .. ": unresolved: " .. line) end
    end
end
for _, line in ipairs(D.farewell) do local _, missing = Guide.resolve(line); assert(#missing == 0, "farewell: " .. line) end
for k, v in pairs(savedFeatures) do G.features[k] = v end
registry["arena.ffa"], registry["race.trial"], registry["chase.1v1"], registry["turf.war"] = nil, nil, nil, nil
LightRP.hallOfFame, D.clinics = nil, {}

-- the shipped config
local order, seen = walk("shipped")
for _, log in ipairs(logs) do assert(not log:find("does not resolve", 1, true), log) end
-- how much of the FAQ the dialogue reaches; every topic at least through one answer
local built = Guide.build()
local visible, reached, topicReached = 0, 0, {}
for _, t in ipairs(built.topics) do
    for _, q in ipairs(t.questions) do
        visible = visible + 1
        if seen["faq:" .. q.id] then reached = reached + 1; topicReached[t.id] = true end
    end
end
for _, t in ipairs(built.topics) do assert(topicReached[t.id], "no answer of topic " .. t.id .. " is reachable by talking") end
assert(reached >= math.floor(visible * 0.8), string.format("the dialogue reaches %d of %d answers", reached, visible))

-- the nodes the owner asked for
local byId = {}
for _, view in ipairs(order) do byId[view.id] = view end
local function choice(id, label)
    for _, c in ipairs(Talk.node(id).choices) do if c.label == label then return c end end
end
assert(choice("first", "Mark my studio.").act.target == "starter" and choice("first", "Mark the Job Center.").act.target == "jobcenter")
assert(choice("action", "Show me the activities.").act.type == "activities" and choice("action", "Show me the activities.").act.tab == "activities")
assert(choice("missions", "Show me the contracts.").act.tab == "contracts")
assert(choice("wheels", "Mark the rental desk.").act.target == "rental" and choice("dogtown", "Mark Dogtown.").act.target == "dogtown")
assert(choice("keys", "Write them all down for me.").act.type == "faq" and choice("keys", "Write them all down for me.").act.id == "controls.keys")
assert(choice("other", "Let me type it.").act.type == "search")
assert(choice("action", "Do they pay?").to == "faq:activities.pay_rebalance", "the activity pay answer the economy shows")
assert(not choice("action", "Open the Hall of Fame."), "no Hall of Fame without its module")
assert(not choice("chrome", "Mark the nearest clinic."), "no clinic GPS without a surveyed clinic")
assert(table.concat(byId.chrome.pages[#byId.chrome.pages], " "):find("Clinics aren't on the map", 1, true), "Johnny says so instead")
-- a FAQ answer as dialogue: its say, its answer, its actions then its follow-ups
local fuel = Talk.node("faq:vehicles.fuel")
local q = built.byId["vehicles.fuel"]
assert(fuel.pages[1][1] == (q.say or q.a[1]) and fuel.choices[1].act.type == "gps" and fuel.choices[1].label == "Mark a fuel station.")
assert(fuel.choices[2].to == "faq:vehicles.jerrycan" and fuel.choices[2].label == built.byId["vehicles.jerrycan"].q)
local priceList = Talk.node("faq:cyberware.price")
assert(#Talk.pages(built.byId["cyberware.price"].a) > Talk.LONG, "the implant list is long")
assert(#priceList.pages == 3 and priceList.pages[3][1] == Talk.MORE, "a long answer: its start, then Johnny offers the rest")
assert(priceList.choices[1].label == "Write it down for me." and priceList.choices[1].act.type == "faq" and priceList.choices[1].act.id == "cyberware.price",
    "the FAQ panel first")
local short = Talk.node("faq:vehicles.fuel")
for _, c in ipairs(short.choices) do assert(not (c.act and c.act.type == "faq"), "a short answer is told whole") end
for _, view in ipairs(order) do assert(#view.pages <= Talk.LONG, view.id .. ": " .. #view.pages .. " pages") end
local housing = Talk.node("topic:housing")
assert(housing.pages[1][1] == faqTopics.housing.say and #housing.choices == #Guide.topic("housing").questions, "a topic: its line, its questions")
assert(Talk.node("faq:nope") == nil and Talk.node("topic:nope") == nil and Talk.node("nope") == nil and Talk.node(string.rep("x", 200)) == nil)

-- ---------------------------------------------------------------------------
-- Opening: the root rides with the guide dialog, its children right behind it.
clientEvents, dialogs = {}, {}
Guide.onInteract(1, Guide.INTERACTION)
local index = assert(dialogs[1], "the dialog").payload
measure(index, "dialog (index + opening)")
local talk = assert(index.talk, "the dialogue rides with the index")
assert(talk.root == D.root and talk.node.id == D.root and talk.revision == Talk.revision())
assert(#talk.node.choices == #first, "every first-level choice is offered")
local greeting = table.concat(talk.node.pages[1], "\n")
local matched = false
for i, set in ipairs(D.nodes[D.root].variants) do
    if greeting == table.concat(Guide.resolveLines(set, "hello: "), "\n") then matched = true end
end
assert(matched, "the greeting is one of the variants: " .. greeting)
local farewells = {}
for _, line in ipairs(D.farewell) do farewells[line] = true end
assert(farewells[talk.farewell], "a farewell line")
assert(clientEvents[1].payload.keys, "the keys first")
local prefetched, firstSearch = {}, nil
for i = 2, #clientEvents do
    local m = clientEvents[i].payload
    assert(clientEvents[i].name == E.net.guide)
    if m.talk then
        assert(not firstSearch, "the dialogue's nodes come before the search index")
        assert(m.talk.revision == talk.revision)
        measure(m, "prefetch")
        for _, view in ipairs(m.talk.nodes) do prefetched[view.id] = true end
    elseif m.search then firstSearch = firstSearch or i end
end
assert(firstSearch, "the search index still follows")
assert(not prefetched[D.root], "the root is not sent twice")
for _, c in ipairs(talk.node.choices) do if c.to then assert(prefetched[c.to], c.to .. " is on the page before the first click") end end

-- a node on demand: itself and its children; nothing outside a session
clientEvents = {}
actions["guide.node"](1, { type = "guide.node", id = "wheels" })
local got = {}
for _, event in ipairs(clientEvents) do for _, view in ipairs(event.payload.talk.nodes) do got[view.id] = true end end
assert(got.wheels and got.fuel and got.garage and got["faq:vehicles.prices"], "the node and its children")
clientEvents = {}
actions["guide.node"](1, { type = "guide.node", id = "nope" })
assert(#clientEvents == 1 and clientEvents[1].payload.talk.missing == "nope", "an unknown node says so")
clientEvents = {}
actions["guide.node"](2, { type = "guide.node", id = "wheels" })
assert(#clientEvents == 0, "nodes only after the dialog opened")

-- ---------------------------------------------------------------------------
-- Gating follows the config, and the revision with it.
local revision = Talk.revision()
LightRpDogtown.enabled = false
assert(not Talk.node("dogtown") and not choice("action", "Dogtown?"), "Dogtown off: no Dogtown branch")
assert(not table.concat(Talk.node("action").pages[1], " "):find("Dogtown", 1, true), "nor its line")
assert(Guide.resolveTarget("dogtown", nil) == nil and Talk.revision() ~= revision, "nor its GPS; a new revision")
LightRpDogtown.enabled = true
assert(Talk.revision() == revision)
local target = Guide.resolveTarget("dogtown", nil)
assert(target and target.name == "Dogtown" and target.position.x == LightRpDogtown.blip.position.x, "Dogtown's map pin")
LightRP.hallOfFame = { name = "hallOfFame", open = function(id, tab) results[#results + 1] = { hof = id, tab = tab } end, nearBoard = function() return false end }
assert(choice("action", "Open the Hall of Fame.").act.type == "halloffame" and Talk.revision() ~= revision, "the Hall of Fame with its module")
LightRpHallOfFame.enabled = false
assert(not choice("action", "Open the Hall of Fame."), "closed in its config")
LightRpHallOfFame.enabled = true
D.clinics = { { id = "far", name = "Far clinic", position = { x = 5000, y = 5000, z = 0 } }, { id = "near", name = "Near clinic", position = { x = 10, y = 10, z = 0 } } }
assert(choice("chrome", "Mark the nearest clinic.").act.target == "ripperdoc", "a surveyed clinic: the GPS choice")
assert(not table.concat(Talk.node("chrome").pages[#Talk.node("chrome").pages], " "):find("aren't on the map", 1, true), "and no 'not on the map'")
assert(Guide.resolveTarget("ripperdoc", { x = 0, y = 0 }).id == "near", "the nearest clinic")
D.clinics = {}
LightRpEconomy.paychecks.requireActivity = false
assert(not table.concat(Talk.node("money").pages[1], " "):find("actually doing something", 1, true), "the paycheck line follows the economy")
LightRpEconomy.paychecks.requireActivity = true
LightRpCyberwareConfig.capacity.enabled, LightRpCyberwareConfig.gating.enabled = false, false
assert(Talk.node("limits").pages[1][1] == "None. If your bank can pay, it fits.", "no limits: Johnny says so")
LightRpCyberwareConfig.capacity.enabled, LightRpCyberwareConfig.gating.enabled = true, true
D.enabled = false
clientEvents, dialogs = {}, {}
Guide.onInteract(1, Guide.INTERACTION)
assert(dialogs[1].payload.talk == nil, "the dialogue off: the FAQ as before")
for _, event in ipairs(clientEvents) do assert(not event.payload.talk, "no dialogue messages") end
D.enabled = true

-- ---------------------------------------------------------------------------
-- The Hall of Fame from the dialogue: in a session, near Johnny or the board.
Guide.onInteract(1, Guide.INTERACTION)
results = {}
local at = Guide.placement()
players[1] = { x = at.position.x + 3, y = at.position.y, z = at.position.z }
actions["guide.panel"](1, { type = "guide.panel", panel = "halloffame" })
assert(results[1] and results[1].hof == 1 and results[1].tab == "overview", "opened beside Johnny")
results = {}
players[1] = { x = at.position.x + 40, y = at.position.y, z = at.position.z }
actions["guide.panel"](1, { type = "guide.panel", panel = "halloffame" })
assert(results[1] and results[1].ok == false and not results[1].hof, "refused far from Johnny and the board")
results = {}
actions["guide.panel"](2, { type = "guide.panel", panel = "halloffame" })
assert(results[1] and results[1].ok == false and results[1].text:find("Talk to", 1, true), "no session, no panel")
LightRP.hallOfFame = nil
players[1] = { x = hub.center.x, y = hub.center.y, z = hub.center.z }

print(string.format("PASS: guide dialogue (%d config nodes, %d nodes walked, %d of %d FAQ answers reachable by talking, %d messages, largest %d values / %d bytes)",
    nodeCount, #order, reached, visible, measured, maxValues, maxBytes))
