-- Talking to Johnny: the dialogue over the guide's FAQ (content in
-- server/config/guide_dialogue.lua, the FAQ in server/config/guide.lua, the guide
-- itself in server/modules/guide.lua). Talking to him opens the dialogue of the
-- page (ui/src/features/guide/TalkView.tsx): his line as a subtitle, a short list
-- of choices, an answer, more choices; some choices act (a GPS route, a panel).
-- The FAQ panel with its search stays one choice away ("Let me type it").
--
-- Nodes travel lazily: the opening node rides with the guide dialog, its children
-- right behind it, and every `guide.node` request answers that node plus its
-- children, so the next click is already on the page. Each message stays under
-- BUDGET values and BYTES bytes (the client drops a plain net event over 1024 values
-- or about 48 KiB; tests/guide_dialogue_test.lua measures them).
--
-- Node ids: a node of the config ("first"), "faq:<question id>" (a FAQ answer told
-- by Johnny, its actions and follow-ups as choices) or "topic:<topic id>" (a FAQ
-- topic: its questions as choices).
local Guide = LightRP.guide
local E = LightRpEvents
local Talk = LightRP.module("guideDialogue", {})

Talk.BUDGET = 800        -- values per message (host limit 1024, framework margin 900)
Talk.BYTES = 32 * 1024   -- bytes per message (the host's limit is about 48 KiB)
Talk.LONG = 4            -- a FAQ answer of more pages: its first two, then the FAQ panel
Talk.MORE = "There's more. A lot more. Want it written down?"

-- {config:dialogue.*} in a `requires` reads this file's config.
Guide.roots.dialogue = "LightRpGuideDialogue"

local function config() return LightRpGuideDialogue or {} end

function Talk.enabled()
    local D = LightRpGuideDialogue
    return type(D) == "table" and D.enabled ~= false and LightRpGuide.enabled ~= false and type(D.nodes) == "table"
        and type(D.nodes[D.root]) == "table"
end

-- ---------------------------------------------------------------------------
-- GPS targets the dialogue adds to the guide's (server/modules/guide.lua Guide.targets).

-- Dogtown: the zone's map pin, while the zone is on.
Guide.targets.dogtown = function()
    local Z = LightRpDogtown
    if type(Z) ~= "table" or Z.enabled ~= true or type(Z.blip) ~= "table" then return {} end
    return { Guide.point("dogtown", "Dogtown", Z.blip.position) }
end
-- Ripperdoc clinics: the surveyed list of the config (empty by default).
Guide.targets.ripperdoc = function() return Guide.fromList(config().clinics) end

-- ---------------------------------------------------------------------------
-- Text

local function plainLength(text)
    local plain = text:gsub("%*%*", ""):gsub("`", ""):gsub("{key:[%w_]+}", "KEY")
    return utf8.len(plain) or #plain
end
Talk.plainLength = plainLength

-- Lines into pages: at most `pageLines` lines and about `pageChars` characters a
-- page (a longer line alone). A line that introduces the next ones ("...:") moves
-- to the next page rather than end one.
function Talk.pages(lines)
    local D = config()
    local maxLines, maxChars = tonumber(D.pageLines) or 3, tonumber(D.pageChars) or 300
    local pages, page, chars = {}, {}, 0
    for _, line in ipairs(lines) do
        local n = plainLength(line)
        if #page > 0 and (#page >= maxLines or chars + n > maxChars) then
            local carried
            if #page > 1 and page[#page]:match(":%s*$") then
                carried = table.remove(page)
            end
            pages[#pages + 1] = page
            page, chars = {}, 0
            if carried then page[1], chars = carried, plainLength(carried) end
        end
        page[#page + 1] = line
        chars = chars + n
    end
    if #page > 0 then pages[#pages + 1] = page end
    return pages
end

-- "Mark the Job Center" -> "Mark the Job Center." (the player's lines end like sentences)
local function sentence(text)
    if type(text) ~= "string" or text == "" then return text end
    if text:match("[%.%?!…:]%s*$") then return text end
    return text .. "."
end
Talk.sentence = sentence

-- ---------------------------------------------------------------------------
-- Choices

-- What the page's buttons say when the FAQ gave no label.
Talk.ACTION_LABELS = {
    gps = "Mark it on my map.", activities = "Show me the activities.", contracts = "Show me the contracts.", crew = "Show me my crew.",
    jobguide = "Open my job guide.", housing = "Open my homes.", support = "Open Reports & support.", animations = "Open the animations.",
    tutorial = "First day guide options.", briefing = "Replay the server briefing.", halloffame = "Open the Hall of Fame.",
}
local TABS = { activities = "activities", contracts = "contracts", crew = "crew" }

local function hasPlaces(kind)
    local source = Guide.targets[kind]
    if type(source) ~= "function" then return false end
    local ok, entries = pcall(source)
    return ok and type(entries) == "table" and #entries > 0
end
Talk.hasPlaces = hasPlaces

local function hallOfFameOpen()
    local hof = LightRP.hallOfFame
    return type(hof) == "table" and type(hof.open) == "function" and Guide.requirementMet("halloffame")
end

-- The page action of `open = "<what>"`, or nil when it cannot be offered now.
function Talk.openAction(what, id, built)
    if TABS[what] then return { type = "activities", tab = TABS[what] } end
    if what == "halloffame" then return hallOfFameOpen() and { type = "halloffame" } or nil end
    if what == "search" then return { type = "search" } end
    if what == "faq" then return type(id) == "string" and built.byId[id] and { type = "faq", id = id } or nil end
    if Guide.PAGE_ACTIONS[what] then return { type = what } end
    return nil
end

local nodeVisible -- forward

-- One choice of the config as the page sees it: { label, to } or { label, act }; nil when hidden.
function Talk.choiceView(choice, built)
    if type(choice) ~= "table" or not Guide.requirementMet(choice.requires) then return nil end
    local label = choice[1] or choice.label
    if type(label) ~= "string" or label == "" then return nil end
    local view = { label = (Guide.resolve(label)) }
    if choice.to then
        if not nodeVisible(choice.to) then return nil end
        view.to = choice.to
    elseif choice.faq then
        if not built.byId[choice.faq] then return nil end
        view.to = "faq:" .. choice.faq
    elseif choice.topic then
        if not Guide.topic(choice.topic) then return nil end
        view.to = "topic:" .. choice.topic
    elseif choice.gps then
        if not hasPlaces(choice.gps) then return nil end
        view.act = { type = "gps", target = choice.gps }
    elseif choice.open then
        view.act = Talk.openAction(choice.open, choice.id, built)
        if not view.act then return nil end
    else
        return nil
    end
    return view
end

-- ---------------------------------------------------------------------------
-- Nodes

local function lines(node, where, pick)
    local source = node.say
    if type(node.variants) == "table" and #node.variants > 0 then
        source = node.variants[pick or math.random(#node.variants)]
    end
    return Guide.resolveLines(source or {}, where)
end

-- A node of the config is visible when its requirement is met and it says something.
nodeVisible = function(id)
    local D = config()
    local node = type(id) == "string" and D.nodes and D.nodes[id]
    if type(node) ~= "table" or not Guide.requirementMet(node.requires) then return false end
    return #lines(node, id .. ": ", 1) > 0
end
Talk.nodeVisible = nodeVisible

local function configNode(id, built)
    local D = config()
    local node = D.nodes[id]
    if not nodeVisible(id) then return nil end
    local choices = {}
    for _, choice in ipairs(node.choices or {}) do
        local view = Talk.choiceView(choice, built)
        if view then choices[#choices + 1] = view end
    end
    return { id = id, pages = Talk.pages(lines(node, id .. ": ")), choices = choices }
end

local function faqNode(qid, built)
    local q = built.byId[qid]
    if not q then return nil end
    local said = {}
    if type(q.say) == "string" and q.say ~= "" then said[1] = q.say end
    for _, line in ipairs(q.a) do said[#said + 1] = line end
    local pages = Talk.pages(said)
    local choices = {}
    -- A long answer (a price list...) is no conversation: the start of it, then the
    -- whole answer on the FAQ panel, offered first.
    if #pages > Talk.LONG then
        pages = { pages[1], pages[2], { Talk.MORE } }
        choices[1] = { label = "Write it down for me.", act = { type = "faq", id = qid } }
    end
    for _, a in ipairs(q.actions or {}) do
        if a.type == "gps" then
            choices[#choices + 1] = { label = sentence(a.label or Talk.ACTION_LABELS.gps), act = { type = "gps", target = a.target } }
        else
            local act = Talk.openAction(a.type == "activities" and (a.tab or "activities") or a.type, nil, built)
            if act then
                local default = a.type == "activities" and Talk.ACTION_LABELS[a.tab or "activities"] or Talk.ACTION_LABELS[a.type]
                choices[#choices + 1] = { label = sentence(a.label or default or a.type), act = act }
            end
        end
    end
    for _, id in ipairs(q.follow or {}) do
        local f = built.byId[id]
        if f then choices[#choices + 1] = { label = f.q, to = "faq:" .. id } end
    end
    return { id = "faq:" .. qid, pages = pages, choices = choices }
end

local function topicNode(tid)
    local t = Guide.topic(tid)
    if not t then return nil end
    local choices = {}
    for _, q in ipairs(t.questions) do choices[#choices + 1] = { label = q.q, to = "faq:" .. q.id } end
    local line = t.say or t.blurb or t.title
    return { id = "topic:" .. tid, pages = Talk.pages({ line }), choices = choices }
end

-- The node `id` as the page sees it: { id, pages = { { line, ... }, ... }, choices }.
function Talk.node(id)
    if type(id) ~= "string" or #id > 96 then return nil end
    local built = Guide.build()
    local qid = id:match("^faq:(.+)$")
    if qid then return faqNode(qid, built) end
    local tid = id:match("^topic:(.+)$")
    if tid then return topicNode(tid) end
    return configNode(id, built)
end

-- ---------------------------------------------------------------------------
-- Revision: the FAQ's, plus every requirement of the dialogue and its GPS kinds.

local function hash(text)
    local h = 5381
    for i = 1, #text do h = (h * 33 + text:byte(i)) % 4294967296 end
    return string.format("%08x", h)
end

function Talk.revision()
    local D = config()
    local ids = {}
    for id in pairs(D.nodes or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    local bits = {}
    local function bit(requirement) if requirement ~= nil then bits[#bits + 1] = Guide.requirementMet(requirement) and "1" or "0" end end
    for _, id in ipairs(ids) do
        local node = D.nodes[id]
        bit(node.requires)
        for _, line in ipairs(type(node.say) == "table" and node.say or {}) do if type(line) == "table" then bit(line.requires) end end
        for _, choice in ipairs(node.choices or {}) do
            bit(choice.requires)
            if choice.gps then bits[#bits + 1] = hasPlaces(choice.gps) and "g" or "-" end
            if choice.open == "halloffame" then bits[#bits + 1] = hallOfFameOpen() and "h" or "-" end
        end
    end
    return Guide.build().revision .. "." .. hash(table.concat(bits))
end

-- ---------------------------------------------------------------------------
-- Messages

local function jsonSize(value)
    local t = type(value)
    if t == "string" then return #value + 2 + select(2, value:gsub('["\\]', "")) end
    if t ~= "table" then return #tostring(value) end
    local n = 2
    for k, v in pairs(value) do n = n + jsonSize(tostring(k)) + 2 + jsonSize(v) end
    return n
end
Talk.jsonSize = jsonSize

-- The node and the nodes its choices lead to, in messages under both budgets.
function Talk.messages(id)
    local first = Talk.node(id)
    local revision = Talk.revision()
    if not first then return { { talk = { revision = revision, missing = tostring(id) } } } end
    local views, seen = { first }, { [first.id] = true }
    for _, choice in ipairs(first.choices) do
        if choice.to and not seen[choice.to] then
            seen[choice.to] = true
            local child = Talk.node(choice.to)
            if child then views[#views + 1] = child end
        end
    end
    local messages, slice, values, bytes = {}, {}, 0, 0
    local function flush()
        messages[#messages + 1] = { talk = { revision = revision, nodes = slice } }
        slice, values, bytes = {}, 0, 0
    end
    local base, baseBytes = Guide.countValues({ talk = { revision = revision, nodes = {} } }), 64 + #revision
    for _, view in ipairs(views) do
        local cost, size = 1 + Guide.countValues(view), jsonSize(view) + 1
        if #slice > 0 and (base + values + cost > Talk.BUDGET or baseBytes + bytes + size > Talk.BYTES) then flush() end
        slice[#slice + 1] = view
        values, bytes = values + cost, bytes + size
    end
    if #slice > 0 then flush() end
    return messages
end

-- What rides with the guide dialog: the opening node and a goodbye line.
function Talk.opening()
    local D = config()
    local root = Talk.node(D.root)
    if not root then return nil end
    local farewell = type(D.farewell) == "table" and #D.farewell > 0 and D.farewell[math.random(#D.farewell)] or nil
    return { revision = Talk.revision(), root = D.root, node = root, farewell = farewell and (Guide.resolve(farewell)) or nil }
end

-- Right behind the dialog: the opening node's children (the opening itself is in the dialog).
function Talk.prefetch(playerId, id)
    for _, message in ipairs(Talk.messages(id)) do
        if message.talk.nodes then
            local rest = {}
            for _, view in ipairs(message.talk.nodes) do if view.id ~= id then rest[#rest + 1] = view end end
            message.talk.nodes = rest
        end
        if not message.talk.nodes or #message.talk.nodes > 0 then Guide.send(playerId, message) end
    end
end

-- The page asks for a node (and gets its children too). Silent: no toast.
LightRP.action("guide.node", function(playerId, payload)
    if not Talk.enabled() or not Guide.inSession(playerId) then return end
    local id = type(payload.id) == "string" and payload.id or ""
    for _, message in ipairs(Talk.messages(id)) do Guide.send(playerId, message) end
end)

-- ---------------------------------------------------------------------------
-- Panels the page cannot open by itself.

local function nearJohnny(playerId)
    local at = Guide.placement()
    local p = playerId and playerId > 0 and Open77.players.position(playerId) or nil
    if not at or type(p) ~= "table" or (p.bucket or 0) ~= (LightRpGuide.npc.bucket or 0) then return false end
    local range = tonumber(config().panelRange) or 12
    return (p.x - at.position.x) ^ 2 + (p.y - at.position.y) ^ 2 + (p.z - at.position.z) ^ 2 <= range * range
end
Talk.nearJohnny = nearJohnny

-- "Open the Hall of Fame": the board stands beside Johnny, so the panel opens from
-- where the player talks to him (the board's own action wants its 10 m).
LightRP.action("guide.panel", function(playerId, payload)
    local name = LightRpGuide.npc.name
    if not Guide.inSession(playerId) then
        LightRP.result(playerId, false, "Talk to " .. name .. " again.", "guide.panel")
        return
    end
    if payload.panel ~= "halloffame" then return end
    if not hallOfFameOpen() then LightRP.result(playerId, false, "The Hall of Fame is closed.", "guide.panel"); return end
    local hof = LightRP.hallOfFame
    local nearBoard = type(hof.nearBoard) == "function" and hof.nearBoard(playerId)
    if not nearBoard and not nearJohnny(playerId) then
        LightRP.result(playerId, false, "Walk up to the Hall of Fame board first.", "guide.panel")
        return
    end
    hof.open(playerId, "overview")
end)
