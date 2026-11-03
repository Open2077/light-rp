-- The guide NPC (server/modules/guide.lua, content in server/config/guide.lua,
-- client relay in client/core/guide.lua): the NPC and its interaction, every topic
-- reachable, no dead follow-up, every placeholder resolved, every GPS target on the
-- map, every message under the client's 1024-value limit (counted like the
-- framework, kept under 900), no staff-only command in the answers, gating of
-- the features that are not merged, the staff move command, ALT + click and the
-- player's own keys on the client.
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
    "dealerships", "shops", "support", "housing", "cyberware", "activities", "economy", "halloffame", "dogtown", "guide" }) do
    dofile("server/config/" .. file .. ".lua")
end

local noop = function() end
local interactions, dialogs, results, clientEvents, latent, commands, actions, threads = {}, {}, {}, {}, {}, {}, {}, {}
local logs = {}
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
TriggerLatentClientEvent = function(name, id, rate, payload) latent[#latent + 1] = { name = name, id = id, payload = payload }; return "stream" end

local hub = LightRpActivities.hub
local players = { [1] = { x = hub.center.x, y = hub.center.y, z = hub.center.z, heading = 52.6 }, [2] = { x = 0, y = 0, z = 0, heading = 0 } }
local kvp = {}
local created, transforms, removed, aiCalls = {}, {}, {}, {}
local refused = {}
local nextNpc = 41
Open77 = {
    players = {
        position = function(id)
            assert(type(id) == "number" and id > 0, "Open77.players.position throws for a non-player id")
            local p = players[id]
            return p and { x = p.x, y = p.y, z = p.z, bucket = 0 } or nil
        end,
        get = function(id)
            local p = players[id]
            return p and { position = { x = p.x, y = p.y, z = p.z }, heading = p.heading, bucket = 0 } or nil
        end,
        getLifeState = function() return { phase = "alive" } end,
    },
    vehicles = {},
    kvp = {
        get = function(key) return kvp[key] end,
        set = function(key, value) assert(type(value) == "string"); kvp[key] = value; return true end,
        delete = function(key) local had = kvp[key] ~= nil; kvp[key] = nil; return had end,
    },
    npcs = {
        damage = { invulnerable = "invulnerable", immortal = "immortal" },
        ai = { tasks = "tasks" },
        all = function() return {} end,
        create = function(def)
            created[#created + 1] = def
            if refused[def.record] then return nil, "unknown_record" end
            nextNpc = nextNpc + 1
            return nextNpc
        end,
        setAIEnabled = function(id, on) aiCalls[#aiCalls + 1] = { id = id, on = on }; return true end,
        setTransform = function(id, def) transforms[#transforms + 1] = { id = id, def = def }; return true end,
        get = function(id) return { id = id } end,
        remove = function(id) removed[#removed + 1] = id; return true end,
    },
}

dofile("server/modules/activities.lua")
dofile("server/modules/activities_hub.lua")
dofile("server/modules/guide.lua")
local Guide, G = LightRP.guide, LightRpGuide
local registry = LightRP.activities.registry
local E = LightRpEvents

local function near(a, b, eps) return math.abs(a - b) < (eps or 0.01) end
local function offsetOf(forward, right)
    local h = math.rad(hub.heading)
    return hub.center.x - math.sin(h) * forward + math.cos(h) * right, hub.center.y + math.cos(h) * forward + math.sin(h) * right
end

-- Values the way the framework counts them (server/core/framework.lua countStateValues).
local function countValues(value)
    if type(value) ~= "table" then return 1 end
    local n = 1
    for _, item in pairs(value) do n = n + 1 + countValues(item) end
    return n
end
-- A JSON encoding, for the byte limit (48 KiB, interact.lua sends past 40 KiB as latent).
local function jsonSize(value)
    local t = type(value)
    if t == "string" then return #value + 2 + select(2, value:gsub('["\\]', "")) end
    if t ~= "table" then return #tostring(value) end
    local n = 2
    for k, v in pairs(value) do n = n + jsonSize(tostring(k)) + 2 + jsonSize(v) end
    return n
end
local maxValues, maxBytes = 0, 0
local function measure(payload, what)
    local values, bytes = countValues(payload), jsonSize(payload)
    assert(values < 900, string.format("%s: %d values (limit 1024, framework margin 900)", what, values))
    assert(bytes < 40 * 1024, string.format("%s: %d bytes", what, bytes))
    if values > maxValues then maxValues = values end
    if bytes > maxBytes then maxBytes = bytes end
    return values
end

-- ---------------------------------------------------------------------------
-- The NPC: spawned by the start thread, at his offset, facing the arrival point.
assert(#threads >= 1, "a start thread")
local ok, err = pcall(threads[#threads])
assert(not ok and err == "stop-loop", "the start thread spawns then watches: " .. tostring(err))
assert(#created == 1 and created[1].record == "Character.q115_suicide_johnny", "the first candidate record")
local def = created[1]
assert(def.bucket == 0 and def.persistent == false and def.despawnWhenUnobserved == false and def.streamingRadius == 150)
assert(def.behavior.combatEnabled == false and def.behavior.perceptionEnabled == false and def.behavior.voiceEnabled == false, "non-hostile")
assert(def.damagePolicy == "invulnerable" and def.aiMode == "tasks", "invulnerable, scripted AI")
assert(aiCalls[1] and aiCalls[1].id == Guide.npcId and aiCalls[1].on == false, "AI off: he stands idle")
local ex, ey = offsetOf(4, 4)
assert(near(def.position.x, ex) and near(def.position.y, ey) and def.position.z == hub.center.z, "forward 4 / right 4 of The Crossing")
local faceCenter = math.deg(math.atan(-(hub.center.x - ex), hub.center.y - ey))
assert(near(def.yaw, faceCenter), "facing the arrival point")
local tx, ty = offsetOf(5, 0)
local hx, hy = offsetOf(6, -4)
assert((ex - tx) ^ 2 + (ey - ty) ^ 2 > 3 ^ 2, "clear of the activities terminal")
assert((ex - hx) ^ 2 + (ey - hy) ^ 2 > 4 ^ 2, "clear of the Hall of Fame board")
-- every candidate a real record name (or a template), the clerks after them
local candidates = Guide.npcCandidates()
assert(#candidates == #G.npc.candidates + #LightRpConfig.rentals.npcPool, "the clerks' records as fallback")
for _, c in ipairs(G.npc.candidates) do assert(type(c.record) == "string" and c.record:match("^Character%.[%w_]+$"), "a record name") end

-- the interaction
local point = interactions[Guide.INTERACTION]
assert(point and point.prompt == "Talk to Johnny" and point.label == "Johnny Silverhand" and point.key == "E" and point.bucket == 0)
assert(near(point.position.x, ex) and point.radius == G.npc.interactRadius and point.ring == false and point.marker)
assert(point.blip and point.blip.icon == "message-circle-question" and point.blip.title == "Johnny Silverhand")
-- the clients learn which NPC he is (ALT + click)
local announce = clientEvents[#clientEvents]
assert(announce.name == E.net.guide and announce.id == -1 and announce.payload.npc.id == Guide.npcId and announce.payload.revision == nil)
measure(announce.payload, "npc announce")

-- a record the platform refuses: the next candidate, then the clerks
refused["Character.q115_suicide_johnny"], refused["Character.Silverhand"], refused["Character.JohnnyNPC_Puppet_Photomode"] = true, true, true
created = {}
Guide.spawn()
assert(#created == 4 and created[4].record == LightRpConfig.rentals.npcPool[1].record, "falls back to a clerk record")
assert(Guide.record == LightRpConfig.rentals.npcPool[1].record and removed[#removed] ~= nil, "the previous body removed first")
refused = {}
Guide.spawn()
assert(Guide.record == "Character.q115_suicide_johnny")

-- ---------------------------------------------------------------------------
-- The content itself
local topicIds, questionIds, questionTopic = {}, {}, {}
local rawQuestions = {}
for _, topic in ipairs(G.topics) do
    assert(type(topic.id) == "string" and not topicIds[topic.id], "unique topic id " .. tostring(topic.id))
    topicIds[topic.id] = true
    assert(type(topic.title) == "string" and #topic.questions > 0, topic.id .. ": a title and questions")
    for _, q in ipairs(topic.questions) do
        assert(type(q.id) == "string" and not questionIds[q.id], "unique question id " .. tostring(q.id))
        assert(q.id:sub(1, #topic.id + 1) == topic.id .. ".", q.id .. ": ids start with their topic")
        assert(type(q.q) == "string" and type(q.a) == "table" and #q.a > 0, q.id .. ": a question and an answer")
        questionIds[q.id], questionTopic[q.id] = q, topic.id
        rawQuestions[#rawQuestions + 1] = q
    end
end
assert(#G.topics >= 15, "a giant FAQ: " .. #G.topics .. " topics")
assert(#rawQuestions >= 100, "a giant FAQ: " .. #rawQuestions .. " questions")

-- no dead follow-up link, even under a feature that is off
for _, q in ipairs(rawQuestions) do
    for _, id in ipairs(q.follow or {}) do
        assert(questionIds[id], q.id .. ": follow-up " .. id .. " does not exist")
        assert(id ~= q.id, q.id .. ": follows itself")
    end
end

-- every placeholder resolves (with every activity provider registered and every
-- feature on, so gated answers are checked too)
local saved = {}
for k, v in pairs(G.features) do saved[k] = v; G.features[k] = true end
registry["arena.ffa"] = { id = "arena.ffa", label = "Combat Zone" }
registry["race.trial"] = { id = "race.trial", label = "Time Trial" }
registry["chase.1v1"] = { id = "chase.1v1", label = "NCPD Chase" }
registry["turf.war"] = { id = "turf.war", label = "Turf War" }
local function allStrings(q)
    local out = { q.q }
    for _, line in ipairs(q.a) do
        if type(line) == "table" then -- a gated line: { requires = ..., "text" }
            assert(type(line[1]) == "string" and #line == 1 and line.requires ~= nil, q.id .. ": a gated line is { requires = ..., \"text\" }")
            line = line[1]
        end
        out[#out + 1] = line
    end
    if q.say then out[#out + 1] = q.say end
    for _, a in ipairs(q.actions or {}) do if a.label then out[#out + 1] = a.label end end
    return out
end
local contentStrings = {}
for _, line in ipairs(G.greeting) do contentStrings[#contentStrings + 1] = line end
for _, topic in ipairs(G.topics) do
    for _, field in ipairs({ topic.title, topic.blurb, topic.say }) do if field then contentStrings[#contentStrings + 1] = field end end
end
for _, q in ipairs(rawQuestions) do
    for _, text in ipairs(allStrings(q)) do contentStrings[#contentStrings + 1] = text end
    local lines = Guide.resolveLines(q.a, q.id .. ": ")
    for _, line in ipairs(lines) do assert(not line:find("—", 1, true), q.id .. ": a placeholder does not resolve in: " .. line) end
end
for _, text in ipairs(contentStrings) do
    if text:match("^%s*{list:[^{}]+}%s*$") then
        assert(Guide.listOf(text:match("{list:([^{}]+)}")), "list does not resolve: " .. text)
    else
        local resolved, missing = Guide.resolve(text)
        assert(#missing == 0, "placeholder {" .. tostring(missing[1]) .. "} does not resolve in: " .. text)
        assert(not resolved:find("{list:", 1, true), "{list:} must stand alone on its line: " .. text)
    end
end
for _, log in ipairs(logs) do assert(not log:find("does not resolve", 1, true), log) end
-- a few spot checks of the injected values
assert(Guide.resolve("{money:config.economy.startingCash}") == "€$ 250")
assert(Guide.resolve("{sec:medical.giveUpDelayMs}") == "90" and Guide.resolve("{pct:medical.reviveHealth}") == "35%")
assert(Guide.resolve("{cfg:config.chat.icRange}") == "20" and Guide.resolve("{kbd:cyberware.overdriveKey}") == "X")
assert(Guide.resolve("{v:carRange}") == "€$ 4,000 to €$ 100,000", Guide.resolve("{v:carRange}"))
assert(Guide.resolve("{v:jobCenterJobs}") == "Sanitation, Scrapper and Courier", Guide.resolve("{v:jobCenterJobs}"))
assert(Guide.resolve("{v:jerrycanBuy}") == "€$ 105" and Guide.resolve("{v:jerrycanRefill}") == "€$ 80")
assert(Guide.resolve("{v:repTiers}") == "I (Street) from the start, II (Merc) at 500, III (Operator) at 1,500, IV (Edgerunner) at 4,000 and V (Legend) at 10,000",
    Guide.resolve("{v:repTiers}"))
assert(Guide.resolve("{v:difficultyTiers}") == "Hard needs tier II (Merc) and Critical needs tier III (Operator)", Guide.resolve("{v:difficultyTiers}"))
local opens = Guide.listOf("tierOpens")
assert(opens[1] == "**I (Street)**, from the start: Standard missions and PvE activities; ranks I and II cyberware", opens[1])
assert(opens[2] == "**II (Merc)**, 500 reputation: Hard missions and PvE activities; rank III cyberware", opens[2])
assert(opens[5] == "**V (Legend)**, 10,000 reputation: rank V+ cyberware", opens[5])
local ranks = Guide.listOf("cyberwareRanks")
assert(ranks[1] == "Ranks I and II: from the start" and ranks[2] == "Rank III: tier II (Merc), 500 reputation" and ranks[5] == "Rank V+: tier V (Legend), 10,000 reputation", ranks[1])
assert(Guide.resolve("{v:traumaKitPrice}") == "€$ 250" and Guide.resolve("{v:traumaKitShops}") == "Corner Market / City Center", "the trauma kit, in the city's market only")
assert(Guide.resolve("{v:cheapestFood}") == "€$ 9")
for _, line in ipairs(Guide.listOf("foodPrices")) do assert(not line:find("Trauma", 1, true), "food prices list food and drinks only: " .. line) end
local fees = table.concat(Guide.listOf("impoundFees"), "\n")
assert(fees:find("A wreck, destroyed or exploded by anyone (the insurance repairs it): €$ 400", 1, true)
    and fees:find("Gone without a wreck (deleted, cleaned up, lost to a bug): €$ 150", 1, true)
    and fees:find("Intact, sent there by you from a garage: €$ 250", 1, true)
    and fees:find("Intact, left outside when the server restarted: free", 1, true), fees)
assert(Guide.resolve("{v:impoundRange}") == "free to €$ 500")
assert(Guide.resolve("{money:economy.hospital.bill} {pct:economy.missions.repeatShare} {money:economy.activities.pve.perMinute.critical}") == "€$ 300 25% €$ 60")
assert(Guide.resolve("{v:missionCapScope}") == "per account (all your characters together)")
assert(Guide.resolve("{v:activityRep}") == "30 on Standard, 60 on Hard or 100 on Critical", Guide.resolve("{v:activityRep}"))
assert(Guide.resolve("{money:dogtown.stake.minCash}") == "€$ 1,000" and Guide.resolve("{sec:dogtown.stake.graceMs}") == "10")
assert(Guide.resolve("{pct:dogtown.loot.bonus}") == "25%" and Guide.resolve("{money:dogtown.loot.bonusDailyCap}") == "€$ 3,000")
assert(Guide.resolve("{sec:dogtown.loot.reserveMs}") == "15" and Guide.resolve("{min:dogtown.loot.pairCooldownMs}") == "10")
local unknown, missing = Guide.resolve("{cfg:config.nope} {key:nope} {v:nope}")
assert(#missing == 3 and unknown == "— — —", "an unknown placeholder is reported")
assert(select(1, Guide.resolve("{key:inventory}")) == "{key:inventory}", "a key is left for the page to show the player's binding")
for k, v in pairs(saved) do G.features[k] = v end
registry["arena.ffa"], registry["race.trial"], registry["chase.1v1"], registry["turf.war"] = nil, nil, nil, nil

-- every GPS target is on the map, every page action is known
local pageTabs = { activities = true, contracts = true, crew = true }
for _, q in ipairs(rawQuestions) do
    for _, action in ipairs(q.actions or {}) do
        if action.type == "gps" then
            local target = Guide.resolveTarget(action.target, nil)
            assert(target and type(target.position.x) == "number" and target.name ~= "", q.id .. ": GPS target " .. tostring(action.target) .. " has no place")
        else
            assert(Guide.PAGE_ACTIONS[action.type], q.id .. ": unknown action " .. tostring(action.type))
            assert(action.tab == nil or pageTabs[action.tab], q.id .. ": unknown tab " .. tostring(action.tab))
        end
    end
end
-- the nearest place of a kind
local fuel = Guide.resolveTarget("fuel", { x = -595, y = -710 })
assert(fuel and fuel.name == "Fuel station")
local food = Guide.resolveTarget("food", { x = 0, y = 0 })
assert(food and food.id == "citycenter_food", "never the arrival hall's shop (another bucket)")
assert(Guide.resolveTarget("nope", nil) == nil and Guide.resolveTarget("jobcenter:nope", nil) == nil)

-- no staff-only command in what players read; every command named exists
local manifest = assert(readFile("open77.lua"))
local restricted, open = {}, {}
for file in manifest:gmatch('server_script%s+"([^"]+)"') do
    local source = readFile(file) or ""
    for name, options in source:gmatch('LightRP%.command%(%s*"([^"]+)"%s*,%s*(%b{})') do
        if options:find("restricted%s*=%s*true") then restricted[name] = true else open[name] = true end
    end
    -- chat.lua registers /w and /s through its speech() wrapper
    for name in source:gmatch('\nspeech%(%s*"([^"]+)"') do open[name] = true end
    for name, tail in source:gmatch('RegisterCommand%(%s*"([^"]+)"(.-)%)%s*\n') do
        if tail:find(",%s*true%s*$") then restricted[name] = true end
    end
end
assert(restricted["lightrp.guide"] and restricted["lightrp.survey"] and open["report"] and open["crew"], "the command scan works")
-- staff-only commands of other resources, or ones that refuse non-staff
local staffElsewhere = { admin = true, housingadmin = true, scene = true, standup = true, wardrobe = true, appearance = true,
    barber = true, gender = true, fireworks = true, car = true, cars = true, dv = true }
local named = {}
for _, text in ipairs(contentStrings) do
    assert(not text:find("lightrp%."), "a staff command in: " .. text)
    for prefix, name in text:gmatch("([%s`(]?)/([%a][%w%._]*)") do
        name = name:gsub("%.+$", "") -- a sentence's full stop
        if prefix ~= "" or text:find("^/" .. name) then
            assert(not restricted[name] and not staffElsewhere[name], "staff-only command /" .. name .. " in: " .. text)
            assert(open[name], "/" .. name .. " is not a player command of this resource: " .. text)
            named[name] = true
        end
    end
end
for _, expected in ipairs({ "tutorial", "money", "pay", "transfer", "work", "job", "garage", "mission", "leave", "activity", "crew", "report", "camchange" }) do
    assert(named[expected], "the guide covers /" .. expected)
end

-- markup and wording
local guideSource = assert(readFile("server/config/guide.lua"))
assert(not guideSource:lower():find("keanu") and not guideSource:lower():find("reeves"), "never the actor's name")
for _, text in ipairs(contentStrings) do
    assert(not text:find("TODO"), "a TODO in player text: " .. text)
    assert(select(2, text:gsub("`", "")) % 2 == 0, "unbalanced ` in: " .. text)
    assert(select(2, text:gsub("%*%*", "")) % 2 == 0, "unbalanced ** in: " .. text)
end
-- topic icons exist in the page's icon set
local icons = assert(readFile("../../../ui/src/design/components/Icon.tsx"), "ui/src/design/components/Icon.tsx")
local glyphs = icons:match("const GLYPHS[^{]*(%b{})")
for _, topic in ipairs(G.topics) do
    local quoted = glyphs:find('"' .. topic.icon .. '"', 1, true)
    local bare = glyphs:find("[%s,{]" .. topic.icon:gsub("%-", "%%-") .. ":")
    assert(quoted or bare, topic.id .. ": icon " .. topic.icon .. " is not in Icon.tsx GLYPHS")
end
-- facts copied from other resources still match them
local voiceSource = readFile("../../system/open-voice/server/config.lua")
if voiceSource then
    for name, distance in voiceSource:gmatch('name%s*=%s*"(%a+)".-distance%s*=%s*([%d%.]+)') do
        assert(G.facts.voice[name] == tonumber(distance), "voice range " .. name .. " is " .. distance .. " in open-voice")
    end
    assert(voiceSource:find('cycleKey%s*=%s*"' .. G.keys.voice.key .. '"'), "voice key")
end
local linkSource = readFile("../../standalone/op77_neuralink/shared/config.lua")
if linkSource then assert(linkSource:find('toggleKey%s*=%s*"' .. G.keys.neuralink.key .. '"'), "Neural-Link key") end
-- no BOM in the Lua files of the feature
for _, file in ipairs({ "server/config/guide.lua", "server/modules/guide.lua", "client/core/guide.lua", "tests/guide_test.lua" }) do
    local head = assert(readFile(file), file):sub(1, 3)
    assert(head ~= "\239\187\191", file .. " starts with a BOM")
end

-- ---------------------------------------------------------------------------
-- Talking: E opens the index, then the keys and the search index follow.
clientEvents = {}
Guide.onInteract(1, Guide.INTERACTION)
local opened = dialogs[#dialogs]
assert(opened and opened.kind == "guide" and opened.id == 1, "E opens the guide dialog")
local index = opened.payload
measure(index, "dialog (index)")
assert(index.npc.name == "Johnny Silverhand" and #index.greeting == #G.greeting and index.revision)
assert(index.keys.inventory == "I" and index.keys.neuralink == "F2", "key defaults")
local keysMessage = clientEvents[1]
assert(keysMessage.name == E.net.guide and keysMessage.payload.keys.inventory.id == "lightrp.inventory" and keysMessage.payload.revision == index.revision)
measure(keysMessage.payload, "keys")
local search = {}
for i = 2, #clientEvents do
    local m = clientEvents[i].payload
    assert(clientEvents[i].name == E.net.guide and m.search and m.part == i - 1 and m.revision == index.revision)
    measure(m, "search part " .. m.part)
    for _, entry in ipairs(m.search) do search[entry[1]] = entry end
end
assert(#latent == 0, "nothing needed the latent transport")

-- every topic of the index is reachable, every question of it is in the search index
local built = Guide.build()
local visibleQuestions, topicMessagesTotal = 0, 0
for _, summary in ipairs(index.topics) do
    clientEvents = {}
    actions["guide.topic"](1, { type = "guide.topic", id = summary.id })
    assert(#clientEvents >= 1, summary.id .. ": the topic answers")
    local got = {}
    for _, event in ipairs(clientEvents) do
        local m = event.payload
        assert(m.topic and m.topic.id == summary.id and m.parts == #clientEvents, summary.id .. ": topic messages")
        measure(m, "topic " .. summary.id .. " part " .. m.part)
        topicMessagesTotal = topicMessagesTotal + 1
        for _, q in ipairs(m.questions) do
            got[#got + 1] = q
            assert(search[q.id] and search[q.id][2] == summary.id, q.id .. ": in the search index")
            assert(#q.a > 0, q.id .. ": an answer")
            for _, id in ipairs(q.follow) do assert(built.byId[id], q.id .. ": follow-up " .. id .. " is not visible") end
            for _, line in ipairs(q.a) do assert(not line:find("—", 1, true), q.id .. ": unresolved: " .. line) end
        end
    end
    assert(#got == summary.count, summary.id .. ": " .. #got .. " questions of " .. summary.count)
    visibleQuestions = visibleQuestions + #got
end
local searchCount = 0
for _ in pairs(search) do searchCount = searchCount + 1 end
assert(searchCount == visibleQuestions, "the search index lists every visible question")

-- an unknown topic, and a player who never opened the guide
clientEvents = {}
actions["guide.topic"](1, { type = "guide.topic", id = "nope" })
assert(clientEvents[1].payload.missing == "nope")
clientEvents = {}
actions["guide.topic"](2, { type = "guide.topic", id = "money" })
assert(#clientEvents == 0, "topics only after the dialog opened")
results = {}
actions["guide.gps"](2, { type = "guide.gps", target = "fuel" })
assert(results[1] and results[1].ok == false, "no GPS without a session")

-- a character not finished yet cannot talk to him
local before = #dialogs
Guide.onInteract(9, Guide.INTERACTION)
assert(#dialogs == before and results[#results].ok == false, "finish your character first")

-- "Mark on map": the nearest place, through the activities GPS
clientEvents, results = {}, {}
actions["guide.gps"](1, { type = "guide.gps", target = "jobcenter" })
local gps = clientEvents[1]
assert(gps and gps.name == E.net.activitiesGps and gps.id == 1, "GPS through the activities route")
assert(near(gps.payload.position.x, LightRpConfig.jobs.centers[1].position.x) and gps.payload.title == LightRpConfig.jobs.centers[1].name)
assert(results[1].ok == true and results[1].action == "guide.gps")
clientEvents, results = {}, {}
actions["guide.gps"](1, { type = "guide.gps", target = "nowhere" })
assert(#clientEvents == 0 and results[1].ok == false)

-- ALT + click: the same dialog from up to contextRange; refused from further
before = #dialogs
players[1].x, players[1].y = ex + 4, ey
actions["guide.open"](1, { type = "guide.open", from = "context" })
assert(#dialogs == before + 1, "ALT + click within " .. G.npc.contextRange .. " m opens it")
players[1].x = ex + 30
results = {}
actions["guide.open"](1, { type = "guide.open", from = "context" })
assert(#dialogs == before + 1 and results[1].ok == false, "too far")
players[1].x, players[1].y = hub.center.x, hub.center.y

-- ---------------------------------------------------------------------------
-- Gating: features not merged stay hidden; a provider's questions follow it.
local function visible(id) return Guide.build().byId[id] ~= nil end
assert(visible("weapons.dogtown") and not visible("weapons.pvp") and visible("activities.pvp_dogtown") and not visible("activities.pvp"),
    "Dogtown on in its config: its answers replace the city-wide ones")
for _, id in ipairs({ "dogtown.what", "dogtown.stake", "dogtown.death", "dogtown.bonus", "dogtown.crews", "dogtown.bounty", "dogtown.fair", "dogtown.logout", "dogtown.hospital" }) do
    assert(visible(id), id .. " is shown")
end
assert(not visible("missions.sector04") and not visible("missions.chimera"), "no board without its mission")
-- merged: activity pay, reputation tiers (missions, PvE activities, cyberware ranks)
assert(visible("activities.pay_rebalance") and visible("missions.tiers_gate") and visible("cyberware.tiers"), "the merged economy and tiers")
assert(not visible("activities.rewards") and not visible("cyberware.ranks") and not visible("missions.reputation"), "the answers they replace")
assert(not visible("activities.arena") and not visible("activities.halloffame"))
for _, log in ipairs(logs) do assert(not log:find("does not resolve", 1, true), log) end
local function answer(id) return table.concat(Guide.build().byId[id].a, "\n") end
-- the answers follow the economy config, line by line
assert(answer("health.down"):find("bills €$ 300", 1, true) and not answer("health.down"):find("costs nothing", 1, true))
assert(answer("jobs.pay"):find("last 30 minutes", 1, true) and answer("jobs.pay"):find("adds 10%", 1, true))
assert(answer("money.earn"):find("while you're active", 1, true) and answer("money.earn"):find("**Activities**", 1, true))
assert(answer("appearance.wardrobe"):find("costs €$ 50", 1, true))
assert(answer("missions.rewards"):find("6 full payouts a day per account", 1, true) and answer("missions.rewards"):find("pays 25% of your share", 1, true))
assert(answer("missions.difficulty"):find("Hard needs tier II (Merc)", 1, true))
LightRpEconomy.hospital.bill, LightRpEconomy.paychecks.requireActivity = 0, false
assert(answer("health.down"):find("It costs nothing.", 1, true) and not answer("health.down"):find("bills", 1, true), "a bill of 0 is free")
assert(not answer("jobs.pay"):find("last 30 minutes", 1, true) and not answer("money.earn"):find("while you're active", 1, true))
LightRpEconomy.hospital.bill, LightRpEconomy.paychecks.requireActivity = 300, true
LightRpEconomy.activities.enabled = false
assert(visible("activities.rewards") and not visible("activities.pay_rebalance") and not answer("money.earn"):find("**Activities**", 1, true), "activity pay off")
assert(answer("activities.rewards"):find("PvE activities earn reputation: 30 on Standard", 1, true))
LightRpEconomy.activities.enabled = true
LightRpCyberwareConfig.gating.enabled = false
assert(visible("cyberware.ranks") and not visible("cyberware.tiers"), "cyberware ranks without a gate")
assert(not Guide.listOf("tierOpens")[2]:find("cyberware", 1, true), "no cyberware rank in the tiers without the gate")
LightRpCyberwareConfig.gating.enabled = true
-- the Hall of Fame with its module, unless its config closes it
LightRP.hallOfFame = { name = "hallOfFame" }
assert(visible("activities.halloffame"), "the Hall of Fame with its module")
assert(answer("activities.halloffame"):find("top 10 of each board", 1, true) and answer("activities.halloffame"):find("**Wealth**", 1, true))
LightRpHallOfFame.showWealth = false
assert(not answer("activities.halloffame"):find("**Wealth**", 1, true), "no wealth board when it is off")
LightRpHallOfFame.showWealth, LightRpHallOfFame.enabled = true, false
assert(not visible("activities.halloffame"), "closed in its config")
LightRpHallOfFame.enabled, LightRP.hallOfFame = true, nil
-- The Dogtown answers quote the live rules.
local stakeLine = Guide.build().byId["dogtown.stake"].a[1]
assert(stakeLine:find("€$ 1,000 in cash on you", 1, true), stakeLine)
local deathLine = Guide.build().byId["dogtown.death"].a[1]
assert(deathLine:find("**10%**", 1, true) and deathLine:find("at least €$ 100 and at most €$ 750", 1, true), deathLine)
local bountyLines = Guide.build().byId["dogtown.bounty"].a
assert(bountyLines[1]:find("^5 kills in a row") and bountyLines[2]:find("€$ 250 per kill of your streak, up to €$ 1,500", 1, true), bountyLines[2])
LightRpDogtown.stake.minCash = 2500
assert(Guide.resolve("{money:dogtown.stake.minCash}") == "€$ 2,500", "the answers read the config, never a copy of it")
LightRpDogtown.stake.minCash = 1000
-- A rule switched off in the config takes its answer with it; the zone off, the city-wide answers.
LightRpDogtown.waiveHospitalBill, LightRpDogtown.combatLog = false, false
assert(not visible("dogtown.hospital") and not visible("dogtown.logout") and visible("dogtown.death"))
LightRpDogtown.waiveHospitalBill, LightRpDogtown.combatLog = true, true
local revision = Guide.build().revision
LightRpDogtown.enabled = false
assert(visible("weapons.pvp") and visible("activities.pvp") and not visible("weapons.dogtown") and not visible("dogtown.what"), "the zone off: the city-wide answers")
assert(Guide.build().revision ~= revision, "a new revision: the page drops its cache")
LightRpDogtown.enabled = true
resourceStates.open77_chimera = "running"
assert(visible("missions.chimera"), "Chimera with its resource running")
resourceStates.open77_chimera = "missing"
registry["arena.duel"] = { id = "arena.duel", label = "Duel" }
assert(visible("activities.arena"))
local arena = Guide.build().byId["activities.arena"]
assert(arena.a[1] == "- Duel", "the live activities: " .. tostring(arena.a[1]))
assert(Guide.resolve("{v:activities}") == "Duel")
registry["arena.duel"] = nil
assert(not visible("activities.arena"))
assert(Guide.requirementMet({ any = { "module:nope", "module:guide" } }) and not Guide.requirementMet("not:module:guide"))
assert(not Guide.requirementMet("unknownFeature"), "an unknown feature is off")

-- ---------------------------------------------------------------------------
-- Staff: /lightrp.guide
local cmd = commands["lightrp.guide"]
assert(cmd and cmd.options.restricted == true, "restricted (command.lightrp.* in acl.jsonc)")
local acl = readFile("../../../acl.jsonc")
if acl then assert(acl:find('"command%.lightrp%.%*"'), "moderators and operators hold command.lightrp.*") end
local okWhere, where = cmd.fn(1, { "where" })
assert(okWhere and where:find("position = { x = ", 1, true) and where:find(tostring(Guide.npcId), 1, true))
local okConsole, why = cmd.fn(0, { "move" })
assert(okConsole == false and why == "In game only.")
players[1] = { x = -750.5, y = 790.25, z = 22.5, heading = 135.0 }
transforms = {}
local okMove, line = cmd.fn(1, { "move" })
assert(okMove and line:find("position = { x = -750.500, y = 790.250, z = 22.500 }, heading = 135.0,", 1, true), line)
assert(kvp["guide.npc.placement"] == "-750.500,790.250,22.500,135.0", "kept across restarts")
assert(transforms[1] and transforms[1].id == Guide.npcId and transforms[1].def.position.x == -750.5 and transforms[1].def.yaw == 135.0, "moved in place")
assert(interactions[Guide.INTERACTION].position.x == -750.5, "the E point follows him")
local okCross = cmd.fn(1, { "move", "crossing" })
assert(okCross and near(Guide.placement().heading, math.deg(math.atan(-(hub.center.x + 750.5), hub.center.y - 790.25))), "move crossing faces the arrival point")
-- a restart reads the staff placement back
created, threads = {}, {}
dofile("server/modules/guide.lua")
Guide = LightRP.guide
pcall(threads[#threads])
assert(created[1] and created[1].position.x == -750.5, "the saved placement wins over the config")
local okReset, resetLine = cmd.fn(1, { "reset" })
cmd = commands["lightrp.guide"]
okReset, resetLine = cmd.fn(1, { "reset" })
assert(okReset and kvp["guide.npc.placement"] == nil and resetLine:find("Back to the config", 1, true))
assert(near(Guide.placement().position.x, ex), "back at his offset")
local okRespawn = cmd.fn(1, { "respawn" })
assert(okRespawn and Guide.npcId)
assert(cmd.fn(1, { "nope" }) == false, "usage")
players[1] = { x = hub.center.x, y = hub.center.y, z = hub.center.z, heading = 52.6 }

-- ---------------------------------------------------------------------------
-- Client: the player's own keys on every page message, ALT + click on him only.
local netHandlers, sent, exported, serverEvents, contextDefs = {}, {}, {}, {}, nil
RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
local handlers = {}
AddEventHandler = function(name, fn) handlers[name] = fn end
GetCurrentResourceName = function() return "op77_lightrp" end
exports = function(name, fn) exported[name] = fn end
local invoking = "open77_contextmenu"
GetInvokingResource = function() return invoking end
TriggerServerEvent = function(name, payload) serverEvents[#serverEvents + 1] = { name = name, payload = payload }; return true end
LightRpUi = { characterReady = true, dialogs = {}, log = noop, send = function(name, payload) sent[#sent + 1] = { name = name, payload = payload } end }
LightRpTutorial = { contextKey = "LEFT ALT" }
Open77.input = { keyFor = function(id) if id == "lightrp.inventory" then return "K" end; if id == "lightrp.playermenu" then return "F1" end end }
Open77.exports = { call = function(resource, method, defs)
    assert(resource == "open77_contextmenu" and method == "registerNpcs")
    contextDefs = defs
    return { await = function() return { "token" } end }
end }
dofile("client/core/guide.lua")
local relay = assert(netHandlers[E.net.guide], "the client relays guide messages")
relay({ npc = { id = 77, name = "Johnny Silverhand", prompt = "Talk to Johnny" } })
assert(#sent == 0, "who Johnny is stays on the client")
relay({ revision = "r1", keys = { inventory = { key = "I", id = "lightrp.inventory" }, menu = { key = "F1", id = "lightrp.playermenu" },
    neuralink = { key = "F2" }, context = { key = "ALT" } } })
local page = sent[#sent]
assert(page.name == E.page.guide and page.payload.keys == nil, "the binding ids stay on the client")
assert(page.payload.effectiveKeys.inventory == "K", "a rebound key shows the player's key")
assert(page.payload.effectiveKeys.neuralink == "F2" and page.payload.effectiveKeys.context == "LEFT ALT")
relay({ revision = "r1", search = {} })
assert(sent[#sent].payload.effectiveKeys.inventory == "K", "every message carries the keys")
handlers["onClientResourceStart"]("op77_lightrp")
assert(contextDefs and contextDefs[1].label == "Talk to Johnny" and contextDefs[1].canInteract == "guideContextAvailable")
local onJohnny = { target = { kind = "npc", npcId = 77 } }
assert(exported.guideContextAvailable(onJohnny) == true, "ALT + click on Johnny")
assert(exported.guideContextAvailable({ target = { kind = "npc", npcId = 78 } }) == false, "not on another NPC")
assert(exported.guideContextAvailable({ target = { kind = "player", playerId = 3 } }) == false)
invoking = "someone_else"
assert(exported.guideContextAvailable(onJohnny) == false, "only the context menu may ask")
invoking = "open77_contextmenu"
LightRpUi.dialogs.shop = true
assert(exported.guideContextAvailable(onJohnny) == false, "not while a window is open")
LightRpUi.dialogs.shop = false
assert(exported.guideContextSelect(onJohnny) == true and serverEvents[1].name == E.net.action and serverEvents[1].payload.type == "guide.open")

print(string.format("PASS: guide (%d topics, %d questions visible of %d, %d topic messages, largest message %d values / %d bytes)",
    #index.topics, visibleQuestions, #rawQuestions, topicMessagesTotal, maxValues, maxBytes))
