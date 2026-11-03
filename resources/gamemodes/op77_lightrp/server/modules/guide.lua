-- The guide NPC of The Crossing: Johnny Silverhand, who has an answer to
-- everything (server/config/guide.lua). E at his feet ("Talk to Johnny") or ALT +
-- click on him opens the guide dialog of the page (ui/src/features/guide/): his
-- opening line, the topics, a question tree with follow-ups, a search box and
-- action buttons (a GPS route, the Activities panel...).
--
-- The content is server-side Lua, edited by an operator without rebuilding the
-- page. Its placeholders are resolved here at runtime from the live config, so an
-- answer follows a changed price, place or key binding:
--   {cfg:root.path}    a config value, e.g. {cfg:config.economy.payRange}
--   {money:root.path}  the same as eddies, e.g. {money:config.economy.startingCash}
--   {sec:root.path}    milliseconds as seconds; {min:root.path} as minutes
--   {pct:root.path}    a fraction as a percentage (0.35 -> 35%)
--   {kbd:root.path}    a key name from a config, upper case ("x" -> X)
--   {key:name}         a key binding (Guide.keys): the page shows the player's own key
--   {v:name}           a value computed below (Guide.values): names, ranges, counts
--   {list:name}        alone on a line: one bullet per entry of Guide.lists[name]
-- `root` is one of Guide.roots (config = LightRpConfig, activities = LightRpActivities...).
--
-- A topic, question or action with `requires` is sent only when it is met (see
-- Guide.requirementMet): "module:<name>", "resource:<name>", "activity:<id>" or
-- "activity:<prefix>*", "config:<root.path>", a bare feature name (looked up in
-- LightRpGuide.features: features that are not on this branch yet), "not:<any of
-- these>"; a list means all of them, `{ any = { ... } }` one of them.
--
-- Transport: the client host drops a plain net event over 1024 JSON values
-- (server/core/framework.lua). The dialog carries the index only (topics, no
-- questions); the search index and each topic go as `guide` events, packed under
-- BUDGET values each (tests/guide_test.lua measures every message).
local C = LightRpGuide
local E = LightRpEvents
local Guide = LightRP.module("guide", { npcId = nil })

Guide.BUDGET = 800        -- values per message we pack to (the host's limit is 1024; framework margin 900)
Guide.SESSION_MS = 30 * 60000 -- topic and GPS requests are answered this long after the dialog opened
local PLACEMENT_KEY = "guide.npc.placement" -- KVP: the staff move, until it is copied into the config

-- ---------------------------------------------------------------------------
-- Counting values the way the framework does (every key and every value).

local function countValues(value, depth)
    if type(value) ~= "table" then return 1 end
    if (depth or 0) > 16 then return 1 end
    local n = 1
    for _, item in pairs(value) do n = n + 1 + countValues(item, (depth or 0) + 1) end
    return n
end
Guide.countValues = countValues

-- ---------------------------------------------------------------------------
-- Config lookups

-- Config roots by short name: the global is looked up at call time, so a config
-- loaded after this file still resolves.
Guide.roots = {
    config = "LightRpConfig", guide = "LightRpGuide", activities = "LightRpActivities",
    tutorial = "LightRpTutorialConfig", missions = "LightRpMissions", raid = "LightRpRaid",
    missionDefs = "LightRpMissionDefs", fixers = "LightRpFixers", jobs = "LightRpJobs", items = "LightRpItems",
    jobWork = "LightRpJobWork", jobRuns = "LightRpJobRuns", delivery = "LightRpDelivery",
    shops = "LightRpShops", garages = "LightRpGarages", dealerships = "LightRpDealerships",
    customization = "LightRpVehicleCustomization", pricing = "LightRpCustomizationPricing",
    housing = "LightRpHousing", cyberware = "LightRpCyberwareConfig", medical = "LightRpMedicalConfig",
    support = "LightRpSupportConfig", armament = "LightRpArmament",
}

local function lookup(path)
    if type(path) ~= "string" or path == "" then return nil end
    local rootName, rest = path:match("^([%w_]+)%.?(.*)$")
    local global = rootName and Guide.roots[rootName]
    local value = global and _G[global]
    if value == nil then return nil end
    for segment in rest:gmatch("[^%.]+") do
        if type(value) ~= "table" then return nil end
        local index = tonumber(segment)
        local nextValue = value[segment]
        if nextValue == nil and index then nextValue = value[index] end
        value = nextValue
        if value == nil then return nil end
    end
    return value
end
Guide.lookup = lookup

local function formatNumber(n)
    if math.type(n) == "integer" then return tostring(n) end
    if n == math.floor(n) and math.abs(n) < 1e15 then return tostring(math.tointeger(n)) end
    return (string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", ""))
end
Guide.formatNumber = formatNumber

local function money(amount)
    amount = tonumber(amount)
    if amount == nil then return nil end
    if LightRP.money and type(LightRP.money.format) == "function" then
        local ok, text = pcall(LightRP.money.format, amount)
        if ok and type(text) == "string" then return text end
    end
    local digits = tostring(math.abs(math.tointeger(amount) or math.floor(amount)))
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (amount < 0 and "-" or "") .. ((LightRpConfig.economy or {}).currency or "€$") .. " " .. grouped
end
Guide.money = money

local function list(names, conjunction)
    local items = {}
    for _, name in ipairs(names) do if type(name) == "string" and name ~= "" then items[#items + 1] = name end end
    if #items == 0 then return nil end
    if #items == 1 then return items[1] end
    return table.concat(items, ", ", 1, #items - 1) .. " " .. (conjunction or "and") .. " " .. items[#items]
end
Guide.list = list

-- Key bindings the content may name: { key = default, id = binding id }. The page
-- shows the player's effective key (client/core/guide.lua asks Open77.input.keyFor
-- for every id it owns); the default stands in until it does.
function Guide.keys()
    local keys = {}
    for name, binding in pairs(LightRpConfig.keys or {}) do
        if type(binding) == "table" and binding.key then keys[name] = { key = binding.key, id = binding.id } end
    end
    local toggle = LightRpConfig.freecam and LightRpConfig.freecam.keys and LightRpConfig.freecam.keys.toggle
    if toggle then keys.freecam = { key = toggle.key, id = toggle.id } end
    for name, binding in pairs(C.keys or {}) do
        if type(binding) == "table" and binding.key then keys[name] = { key = binding.key, id = binding.id } end
    end
    return keys
end

-- ---------------------------------------------------------------------------
-- Computed values ({v:name}) and lists ({list:name}). A value returns a string or
-- a number, a list an array of strings; nil (or an empty list) does not resolve:
-- the line shows "—", the log says so once and tests/guide_test.lua fails on it.

local function itemLabel(name)
    local item = LightRpItems and LightRpItems[name]
    return item and item.label or name
end
local function vehicleLabel(key)
    for _, v in ipairs(LightRpConfig.vehicles and LightRpConfig.vehicles.catalog or {}) do
        if v.key == key then return v.label end
    end
    return key
end
local function cityBucket(entry) return entry.bucket == nil or entry.bucket == 0 end
local function priceRange(entries, field)
    local low, high
    for _, e in ipairs(entries) do
        local p = tonumber(e[field or "price"])
        if p then low = low and math.min(low, p) or p; high = high and math.max(high, p) or p end
    end
    if not low then return nil end
    if low == high then return money(low) end
    return money(low) .. " to " .. money(high)
end
local function dealerStock()
    local out = {}
    for _, place in ipairs(LightRpDealerships and LightRpDealerships.locations or {}) do
        for _, s in ipairs(place.stock or {}) do out[#out + 1] = s end
    end
    return out
end
local function shopLocations(foodOnly)
    local out = {}
    for _, place in ipairs(LightRpShops and LightRpShops.locations or {}) do
        local food = place.template == "street_food"
        if cityBucket(place) and food == foodOnly then out[#out + 1] = place end
    end
    return out
end
local function deskJobs()
    local seen, out = {}, {}
    for _, center in ipairs(LightRpConfig.jobs and LightRpConfig.jobs.centers or {}) do
        for _, name in ipairs(center.jobs or {}) do
            if not seen[name] and LightRpJobs[name] then seen[name] = true; out[#out + 1] = name end
        end
    end
    return out
end
local function gradeRange(job)
    local first, last = job.grades and job.grades[0], nil
    for i = 0, 16 do if job.grades and job.grades[i] then last = job.grades[i] end end
    if not first or not last then return nil end
    if first == last then return string.format("%s %s", first.label, money(first.salary)) end
    return string.format("%s %s up to %s %s", first.label, money(first.salary), last.label, money(last.salary))
end
local function liveActivities(prefix)
    local registry = LightRP.activities and LightRP.activities.registry
    local out = {}
    if type(registry) ~= "table" then return out end
    for id, a in pairs(registry) do
        if prefix == nil or id:sub(1, #prefix) == prefix then out[#out + 1] = { id = id, label = type(a) == "table" and a.label or id } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end
local function missionPoint(id)
    for _, p in ipairs(LightRpMissions and LightRpMissions.points or {}) do if p.id == id then return p end end
end
local function difficultyLines(difficulties)
    local out = {}
    for _, d in ipairs(difficulties or {}) do
        local label = tostring(d.label or d.id):lower():gsub("^%l", string.upper)
        out[#out + 1] = string.format("**%s**: %s · %s min · %d–%d operators", label, money(d.payout), formatNumber(d.minutes or 0), d.min or 1, d.max or 1)
    end
    return out
end

Guide.values = {}
local V = Guide.values
V.npc = function() return C.npc.name end
V.hub = function() return (LightRpActivities and LightRpActivities.hub and LightRpActivities.hub.name) or "The Crossing" end
V.server = function() return LightRpConfig.serverName end
V.hospital = function() return LightRpConfig.spawn and LightRpConfig.spawn.hospital and LightRpConfig.spawn.hospital.label end
V.jobCenter = function() local c = LightRpConfig.jobs and LightRpConfig.jobs.centers and LightRpConfig.jobs.centers[1]; return c and c.name end
V.jobCenterJobs = function()
    local names = {}
    for _, name in ipairs(deskJobs()) do names[#names + 1] = LightRpJobs[name].label end
    return list(names)
end
-- jobs nobody can apply for (no recruitment page): staff hands them out
V.staffJobs = function()
    local names, keys = {}, {}
    for name in pairs(LightRpJobs) do keys[#keys + 1] = name end
    table.sort(keys)
    for _, name in ipairs(keys) do
        local job = LightRpJobs[name]
        if name ~= "unemployed" and type(job) == "table" and job.recruitment == nil then names[#names + 1] = job.label end
    end
    return list(names)
end
V.dealership = function() local d = LightRpDealerships and LightRpDealerships.locations and LightRpDealerships.locations[1]; return d and d.name end
V.carRange = function() return priceRange(dealerStock()) end
V.carCount = function() local n = #dealerStock(); return n > 0 and n or nil end
V.garage = function() local g = LightRpGarages and LightRpGarages.garages and LightRpGarages.garages[1]; return g and g.name end
V.impound = function() return LightRpGarages and LightRpGarages.impound and LightRpGarages.impound.name end
V.rental = function() local s = LightRpConfig.rentals and LightRpConfig.rentals.spots and LightRpConfig.rentals.spots[1]; return s and s.name end
V.rentalRange = function()
    local all = {}
    for _, spot in ipairs(LightRpConfig.rentals and LightRpConfig.rentals.spots or {}) do for _, s in ipairs(spot.stock or {}) do all[#all + 1] = s end end
    return priceRange(all)
end
V.jerrycanRefill = function()
    local f = LightRpConfig.fuel
    return f and f.jerrycan and money(math.ceil(f.jerrycan.litres * f.pricePerLitre))
end
V.jerrycanBuy = function()
    local f = LightRpConfig.fuel
    return f and f.jerrycan and money(math.ceil(f.jerrycan.litres * f.pricePerLitre) + (f.jerrycan.deposit or 0))
end
V.cyberwareRange = function() return priceRange(LightRpCyberwareConfig and LightRpCyberwareConfig.items or {}) end
V.cyberwareCount = function() local n = #(LightRpCyberwareConfig and LightRpCyberwareConfig.items or {}); return n > 0 and n or nil end
V.foodShops = function()
    local names = {}
    for _, place in ipairs(shopLocations(true)) do names[#names + 1] = place.name end
    return list(names, "or")
end
V.wardrobeCount = function()
    local n = 0
    for _, s in ipairs(LightRpConfig.wardrobes and LightRpConfig.wardrobes.spots or {}) do
        if cityBucket(s) and not tostring(s.id):match("^clothing_") then n = n + 1 end
    end
    return n > 0 and n or nil
end
V.clothingCount = function()
    local n = 0
    for _, s in ipairs(LightRpConfig.wardrobes and LightRpConfig.wardrobes.spots or {}) do
        if cityBucket(s) and tostring(s.id):match("^clothing_") then n = n + 1 end
    end
    return n > 0 and n or nil
end
V.starterDoor = function() return LightRpHousing and LightRpHousing.starter and LightRpHousing.starter.building end
V.activities = function()
    local names = {}
    for _, a in ipairs(liveActivities()) do names[#names + 1] = a.label end
    return list(names) or "none, right now (the terminal lists them the moment a game server registers one)"
end
V.repTiers = function()
    local tiers = LightRpMissions and LightRpMissions.reputation and LightRpMissions.reputation.tiers
    if type(tiers) ~= "table" or #tiers == 0 then return nil end
    local parts = {}
    for i, at in ipairs(tiers) do
        parts[#parts + 1] = at == 0 and string.format("TIER %d from the start", i) or string.format("TIER %d at %s", i, formatNumber(at))
    end
    return list(parts)
end
V.fixerNames = function()
    local names = {}
    for _, c in ipairs(LightRpFixers and LightRpFixers.contacts or {}) do names[#names + 1] = c.name end
    return list(names)
end
V.startingItems = function()
    local names = {}
    for _, entry in ipairs(LightRpConfig.inventory and LightRpConfig.inventory.starting or {}) do
        names[#names + 1] = string.format("%d × %s", entry[2] or entry.count or 1, itemLabel(entry[1] or entry.name))
    end
    return list(names)
end
V.fuelPumps = function() local n = #(LightRpConfig.fuel and LightRpConfig.fuel.stations or {}); return n > 0 and n or nil end
V.cheapestFood = function()
    local t = LightRpShops and LightRpShops.templates and LightRpShops.templates.street_food
    local low
    for _, item in ipairs(t and t.items or {}) do if item.buy then low = low and math.min(low, item.buy) or item.buy end end
    return low and money(low)
end

Guide.lists = {}
local L = Guide.lists
L.rules = function() return LightRpConfig.rules end
L.salaries = function()
    local out = {}
    for _, name in ipairs(deskJobs()) do
        local range = gradeRange(LightRpJobs[name])
        if range then out[#out + 1] = string.format("**%s**: %s", LightRpJobs[name].label, range) end
    end
    return out
end
L.rentalStock = function()
    local out = {}
    for _, spot in ipairs(LightRpConfig.rentals and LightRpConfig.rentals.spots or {}) do
        for _, s in ipairs(spot.stock or {}) do out[#out + 1] = string.format("%s: %s", vehicleLabel(s.key), money(s.price)) end
    end
    return out
end
L.dealerStock = function()
    local stock = dealerStock()
    table.sort(stock, function(a, b) return (a.price or 0) < (b.price or 0) end)
    local out = {}
    for _, s in ipairs(stock) do out[#out + 1] = string.format("%s: %s", vehicleLabel(s.key), money(s.price)) end
    return out
end
local IMPOUND_REASONS = {
    { "restart", "left outside when the server restarted" }, { "lost", "destroyed, deleted or lost" },
    { "requested", "sent there by you" }, { "staff", "towed by staff" },
}
L.impoundFees = function()
    local fees = LightRpGarages and LightRpGarages.impound and LightRpGarages.impound.fees or {}
    local out = {}
    for _, r in ipairs(IMPOUND_REASONS) do
        local fee = fees[r[1]]
        if fee ~= nil then out[#out + 1] = string.format("%s%s: %s", r[2]:sub(1, 1):upper(), r[2]:sub(2), fee == 0 and "free" or money(fee)) end
    end
    return out
end
L.foodPrices = function()
    local t = LightRpShops and LightRpShops.templates and LightRpShops.templates.street_food
    local out = {}
    for _, item in ipairs(t and t.items or {}) do
        local effect = LightRpItems[item.name] and LightRpItems[item.name].use or {}
        local gains = {}
        if effect.food then gains[#gains + 1] = "food +" .. formatNumber(effect.food) end
        if effect.drink then gains[#gains + 1] = "drink +" .. formatNumber(effect.drink) end
        out[#out + 1] = string.format("%s: %s%s", itemLabel(item.name), money(item.buy), #gains > 0 and (" · " .. table.concat(gains, ", ")) or "")
    end
    return out
end
L.gunshops = function()
    local out = {}
    for _, place in ipairs(shopLocations(false)) do
        local what = place.blip and place.blip.description
        out[#out + 1] = what and string.format("**%s**: %s", place.name, what) or string.format("**%s**", place.name)
    end
    return out
end
L.cyberware = function()
    local out = {}
    for _, item in ipairs(LightRpCyberwareConfig and LightRpCyberwareConfig.items or {}) do
        out[#out + 1] = string.format("**%s** (%s): %s", item.name, money(item.price), item.effect or "")
    end
    return out
end
L.missionDefaults = function() return difficultyLines(LightRpMissionDefs and LightRpMissionDefs.DIFFICULTIES) end
L.chimeraDifficulties = function() local p = missionPoint("chimera_raid"); return p and difficultyLines(p.difficulties) end
L.sector04Difficulties = function() local p = missionPoint("sector04_blackout"); return p and difficultyLines(p.difficulties) end
L.fixers = function()
    local out = {}
    for _, c in ipairs(LightRpFixers and LightRpFixers.contacts or {}) do
        out[#out + 1] = string.format("**%s** (%s)%s", c.name, c.number or "?", c.tagline and (": " .. c.tagline) or "")
    end
    return out
end
L.walkModes = function()
    local out = {}
    for _, m in ipairs(LightRpConfig.movement and LightRpConfig.movement.modes or {}) do
        out[#out + 1] = m.speed and string.format("%s: %s m/s", m.label, formatNumber(m.speed)) or string.format("%s: full speed", m.label)
    end
    return out
end
L.startingItems = function()
    local out = {}
    for _, entry in ipairs(LightRpConfig.inventory and LightRpConfig.inventory.starting or {}) do
        out[#out + 1] = string.format("%d × %s", entry[2] or entry.count or 1, itemLabel(entry[1] or entry.name))
    end
    return out
end
L.loadouts = function()
    local out = {}
    for _, kit in ipairs(LightRpRaid and LightRpRaid.loadouts or {}) do
        out[#out + 1] = kit.blurb and string.format("**%s**: %s", kit.label or kit.id, kit.blurb) or tostring(kit.label or kit.id)
    end
    return out
end
-- {list:activities.arena}: the live activities whose id starts with that prefix
local function activityList(prefix)
    local out = {}
    for _, a in ipairs(liveActivities(prefix)) do out[#out + 1] = a.label end
    return out
end

local function listOf(name)
    local fn = L[name]
    local ok, items
    if type(fn) == "function" then ok, items = pcall(fn)
    elseif type(name) == "string" and name:match("^activities%.") then ok, items = true, activityList(name:sub(12) .. ".") end
    if not ok or type(items) ~= "table" or #items == 0 then return nil end
    return items
end
Guide.listOf = listOf

-- ---------------------------------------------------------------------------
-- Requirements

local function resourceStarted(name)
    if type(GetResourceState) ~= "function" then return false end
    local ok, state = pcall(GetResourceState, name)
    return ok and (state == "running" or state == "starting")
end

function Guide.requirementMet(requirement, depth)
    depth = (depth or 0) + 1
    if depth > 8 then return false end
    if requirement == nil or requirement == true then return true end
    if requirement == false then return false end
    if type(requirement) == "table" then
        if type(requirement.any) == "table" then
            for _, item in ipairs(requirement.any) do if Guide.requirementMet(item, depth) then return true end end
            return false
        end
        for _, item in ipairs(requirement) do if not Guide.requirementMet(item, depth) then return false end end
        return true
    end
    if type(requirement) ~= "string" then return false end
    local negated = requirement:match("^not:(.+)$")
    if negated then return not Guide.requirementMet(negated, depth) end
    local kind, arg = requirement:match("^(%a+):(.+)$")
    if kind == nil then
        -- a feature of LightRpGuide.features: true/false, or a requirement of its own
        local feature = C.features and C.features[requirement]
        if feature == nil then return false end
        return Guide.requirementMet(feature, depth)
    elseif kind == "module" then
        return type(LightRP[arg]) == "table"
    elseif kind == "resource" then
        return resourceStarted(arg)
    elseif kind == "activity" then
        local registry = LightRP.activities and LightRP.activities.registry
        if type(registry) ~= "table" then return false end
        if arg:sub(-1) == "*" then
            local prefix = arg:sub(1, -2)
            for id in pairs(registry) do if id:sub(1, #prefix) == prefix then return true end end
            return false
        end
        return registry[arg] ~= nil
    elseif kind == "config" then
        local value = lookup(arg)
        return value ~= nil and value ~= false
    end
    return false
end

-- What the visible tree depends on: every requirement of the content in order,
-- met or not, and the live activities ({v:activities}, {list:activities.*}).
local function signature()
    local bits = {}
    local function visit(node)
        if type(node) ~= "table" then return end
        if node.requires ~= nil then bits[#bits + 1] = Guide.requirementMet(node.requires) and "1" or "0" end
        for _, child in ipairs(node.questions or {}) do visit(child) end
        for _, child in ipairs(node.actions or {}) do visit(child) end
    end
    for _, topic in ipairs(C.topics or {}) do visit(topic) end
    local ids = {}
    for _, a in ipairs(liveActivities()) do ids[#ids + 1] = a.id end
    return table.concat(bits) .. "|" .. table.concat(ids, ",")
end

local function hash(text)
    local h = 5381
    for i = 1, #text do h = (h * 33 + text:byte(i)) % 4294967296 end
    return string.format("%08x", h)
end

-- ---------------------------------------------------------------------------
-- GPS targets: `{ type = "gps", target = "<kind>" }` (the nearest of that kind) or
-- "<kind>:<id>" (that one). Each kind lists { id, name, position } from the live
-- config; an empty kind drops its buttons.
Guide.targets = {}
local T = Guide.targets

local function point(id, name, position)
    if type(position) ~= "table" or type(position.x) ~= "number" or type(position.y) ~= "number" then return nil end
    return { id = tostring(id), name = tostring(name or id), position = { x = position.x, y = position.y, z = tonumber(position.z) or 0 } }
end
Guide.point = point

local function fromList(entries, filter, nameOf)
    local out = {}
    for index, entry in ipairs(entries or {}) do
        if type(entry) == "table" and cityBucket(entry) and (filter == nil or filter(entry)) then
            local name = nameOf and nameOf(entry) or entry.name or entry.label or entry.id
            local p = point(entry.id or index, name, entry.position)
            if p then out[#out + 1] = p end
        end
    end
    return out
end
Guide.fromList = fromList

T.crossing = function()
    local H = LightRpActivities and LightRpActivities.hub
    if not H then return {} end
    local terminal = H.terminals and H.terminals[1]
    local hub = LightRP.activitiesHub
    local position = terminal and hub and type(hub.placeOf) == "function" and hub.placeOf(terminal) or H.center
    return { point("crossing", H.name or "The Crossing", position) }
end
T.hospital = function()
    local h = LightRpConfig.spawn and LightRpConfig.spawn.hospital
    return { point("hospital", h and h.label or "Hospital", h and h.position) }
end
T.jobcenter = function() return fromList(LightRpConfig.jobs and LightRpConfig.jobs.centers) end
T.rental = function() return fromList(LightRpConfig.rentals and LightRpConfig.rentals.spots) end
T.garage = function() return fromList(LightRpGarages and LightRpGarages.garages) end
T.dealership = function() return fromList(LightRpDealerships and LightRpDealerships.locations) end
T.autostudio = function() return fromList(LightRpVehicleCustomization and LightRpVehicleCustomization.workshops) end
T.food = function() return fromList(shopLocations(true)) end
T.gunshop = function() return fromList(shopLocations(false)) end
T.wardrobe = function()
    return fromList(LightRpConfig.wardrobes and LightRpConfig.wardrobes.spots, function(s) return not tostring(s.id):match("^clothing_") end)
end
T.clothing = function()
    return fromList(LightRpConfig.wardrobes and LightRpConfig.wardrobes.spots, function(s) return tostring(s.id):match("^clothing_") ~= nil end)
end
T.fuel = function()
    local stations = fromList(LightRpConfig.fuel and LightRpConfig.fuel.stations)
    for _, s in ipairs(stations) do s.name = "Fuel station" end
    return stations
end
T.starter = function()
    local s = LightRpHousing and LightRpHousing.starter
    return { point("starter", s and s.building or "Starter studio", s and s.entrance) }
end
T.bar = function()
    return fromList(LightRpConfig.mapPlaces and LightRpConfig.mapPlaces.places, function(p) return p.kind == "bar" end)
end
T.club = function()
    return fromList(LightRpConfig.mapPlaces and LightRpConfig.mapPlaces.places, function(p) return p.kind == "club" end)
end

local function entriesOf(kind)
    local source = kind and T[kind]
    if type(source) ~= "function" then return nil end
    local ok, entries = pcall(source)
    if not ok or type(entries) ~= "table" then return nil end
    return entries
end

-- Resolve a target for a player: the nearest entry of the kind, or the named one.
function Guide.resolveTarget(target, from)
    if type(target) ~= "string" then return nil end
    local kind, id = target:match("^([%w_]+):?(.*)$")
    local entries = entriesOf(kind)
    if not entries then return nil end
    if id ~= "" then
        for _, entry in ipairs(entries) do if entry.id == id then return entry end end
        return nil
    end
    local best, bestDistance
    for _, entry in ipairs(entries) do
        local d = from and ((entry.position.x - from.x) ^ 2 + (entry.position.y - from.y) ^ 2) or 0
        if best == nil or d < bestDistance then best, bestDistance = entry, d end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- Building the visible tree

local reported = {}
local function warnOnce(key, format, ...)
    if reported[key] then return end
    reported[key] = true
    LightRP.log(format, ...)
end

local function numberAt(path, scale)
    local value = tonumber(lookup(path))
    return value and formatNumber(value / scale) or nil
end

-- Resolve every placeholder of one string. Returns the text and the list of
-- placeholders that did not resolve (the text then shows "—" in their place).
function Guide.resolve(text)
    if type(text) ~= "string" then return text, {} end
    local missing = {}
    local keys
    local out = text:gsub("{(%a+):([^{}]+)}", function(kind, arg)
        local value
        if kind == "key" then
            keys = keys or Guide.keys()
            if keys[arg] then return nil end -- left for the page, which shows the player's key
        elseif kind == "cfg" then
            local raw = lookup(arg)
            if type(raw) == "number" then value = formatNumber(raw) elseif type(raw) == "string" then value = raw end
        elseif kind == "money" then
            value = money(lookup(arg))
        elseif kind == "sec" then
            value = numberAt(arg, 1000)
        elseif kind == "min" then
            value = numberAt(arg, 60000)
        elseif kind == "pct" then
            local raw = tonumber(lookup(arg))
            value = raw and (formatNumber(math.floor(raw * 1000 + 0.5) / 10) .. "%") or nil
        elseif kind == "kbd" then
            local raw = lookup(arg)
            value = type(raw) == "string" and raw:upper() or nil
        elseif kind == "v" then
            local fn = V[arg]
            if type(fn) == "function" then
                local ok, result = pcall(fn)
                if ok and type(result) == "number" then value = formatNumber(result) end
                if ok and type(result) == "string" and result ~= "" then value = result end
            end
        end
        if value ~= nil then return value end
        missing[#missing + 1] = kind .. ":" .. arg
        return "—"
    end)
    return out, missing
end

-- Lines of an answer, resolved; `{list:name}` alone on a line becomes bullets.
local function resolveLines(value, where)
    local lines = type(value) == "table" and value or { value }
    local out = {}
    local function add(line)
        local text, missing = Guide.resolve(line)
        for _, m in ipairs(missing) do warnOnce(where .. m, "guide: %s: placeholder {%s} does not resolve", where, m) end
        out[#out + 1] = text
    end
    for _, line in ipairs(lines) do
        if type(line) == "string" then
            local name = line:match("^%s*{list:([^{}]+)}%s*$")
            if name then
                local items = listOf(name)
                if items then for _, item in ipairs(items) do add("- " .. item) end
                else
                    warnOnce(where .. "list:" .. name, "guide: %s: placeholder {list:%s} does not resolve", where, name)
                    out[#out + 1] = "- —"
                end
            else
                add(line)
            end
        end
    end
    return out
end
Guide.resolveLines = resolveLines

-- Page-side actions: the page performs them with existing actions/events.
Guide.PAGE_ACTIONS = { activities = true, jobguide = true, housing = true, support = true, animations = true, tutorial = true, briefing = true }

local function buildActions(question)
    local out = {}
    for _, action in ipairs(question.actions or {}) do
        if type(action) == "table" and Guide.requirementMet(action.requires) then
            local label = action.label and Guide.resolve(action.label) or nil
            if action.type == "gps" then
                local kind = type(action.target) == "string" and action.target:match("^([%w_]+)") or nil
                local entries = entriesOf(kind)
                if entries and #entries > 0 and Guide.resolveTarget(action.target, nil) then
                    out[#out + 1] = { type = "gps", target = action.target, label = label or "Mark it on my map" }
                else
                    warnOnce("gps:" .. tostring(action.target), "guide: %s: GPS target %s has no place, button hidden", tostring(question.id), tostring(action.target))
                end
            elseif Guide.PAGE_ACTIONS[action.type] then
                out[#out + 1] = { type = action.type, label = label, tab = action.tab }
            end
        end
    end
    return out
end

local builtCache = {}
local loadStamp = tostring(LightRP.nowMs and LightRP.nowMs() or 0)

-- The tree visible now: topics and questions whose requirements are met, with
-- every placeholder resolved and every follow-up pointing at a visible question.
function Guide.build()
    local sig = signature()
    if builtCache.sig == sig and builtCache.value then return builtCache.value end
    local topics, byId = {}, {}
    for _, topic in ipairs(C.topics or {}) do
        if type(topic) == "table" and type(topic.id) == "string" and Guide.requirementMet(topic.requires) then
            local where = topic.id .. ": "
            local t = { id = topic.id, title = Guide.resolve(topic.title or topic.id), icon = topic.icon or "circle-help",
                blurb = topic.blurb and resolveLines(topic.blurb, where)[1] or nil,
                say = topic.say and resolveLines(topic.say, where)[1] or nil, questions = {} }
            for _, q in ipairs(topic.questions or {}) do
                if type(q) == "table" and type(q.id) == "string" and Guide.requirementMet(q.requires) then
                    local at = topic.id .. "/" .. q.id .. ": "
                    local entry = { id = q.id, topic = topic.id, q = resolveLines(q.q, at)[1] or q.id,
                        a = resolveLines(q.a, at), say = q.say and resolveLines(q.say, at)[1] or nil,
                        tags = q.tags, follow = {}, actions = buildActions(q), _follow = q.follow }
                    t.questions[#t.questions + 1] = entry
                    byId[q.id] = entry
                end
            end
            if #t.questions > 0 then topics[#topics + 1] = t end
        end
    end
    -- follow-ups: only visible questions, never the question itself
    for _, t in ipairs(topics) do
        for _, q in ipairs(t.questions) do
            for _, id in ipairs(q._follow or {}) do
                if id ~= q.id and byId[id] then q.follow[#q.follow + 1] = id end
            end
            q._follow = nil
        end
    end
    local value = { topics = topics, byId = byId, revision = loadStamp .. "." .. hash(sig) }
    builtCache = { sig = sig, value = value }
    return value
end

function Guide.topic(id)
    for _, t in ipairs(Guide.build().topics) do if t.id == id then return t end end
end

-- ---------------------------------------------------------------------------
-- Messages

local function npcView()
    return { name = C.npc.name, title = C.npc.title, tag = C.npc.tag }
end

local function keyDefaults()
    local out = {}
    for name, binding in pairs(Guide.keys()) do out[name] = binding.key end
    return out
end

-- The dialog: the index only.
function Guide.indexPayload()
    local built = Guide.build()
    local topics = {}
    for _, t in ipairs(built.topics) do
        topics[#topics + 1] = { id = t.id, title = t.title, icon = t.icon, blurb = t.blurb, count = #t.questions }
    end
    local greeting = resolveLines(C.greeting or {}, "greeting: ")
    return { revision = built.revision, npc = npcView(), greeting = greeting, topics = topics, keys = keyDefaults() }
end

-- Pack `items` (already-built tables) into messages of at most BUDGET values,
-- each made by `wrap(slice)`.
local function pack(items, wrap)
    local messages, slice = {}, {}
    local base = countValues(wrap({})) + 4 -- + part, parts
    local size = base
    for _, item in ipairs(items) do
        local cost = 1 + countValues(item)
        if #slice > 0 and size + cost > Guide.BUDGET then
            messages[#messages + 1] = wrap(slice)
            slice, size = {}, base
        end
        slice[#slice + 1] = item
        size = size + cost
    end
    if #slice > 0 or #messages == 0 then messages[#messages + 1] = wrap(slice) end
    for i, m in ipairs(messages) do m.part, m.parts = i, #messages end
    return messages
end
Guide.pack = pack

-- The search index: every visible question's id, topic, text and tags.
function Guide.searchMessages()
    local built = Guide.build()
    local entries = {}
    for _, t in ipairs(built.topics) do
        for _, q in ipairs(t.questions) do entries[#entries + 1] = { q.id, t.id, q.q, type(q.tags) == "string" and q.tags or "" } end
    end
    return pack(entries, function(slice) return { revision = built.revision, search = slice } end)
end

local function questionView(q)
    return { id = q.id, q = q.q, a = q.a, say = q.say, follow = q.follow, actions = q.actions }
end

-- One topic, in as many messages as its size needs.
function Guide.topicMessages(id)
    local built = Guide.build()
    local t = Guide.topic(id)
    if not t then return nil end
    local items = {}
    for _, q in ipairs(t.questions) do items[#items + 1] = questionView(q) end
    local meta = { id = t.id, title = t.title, icon = t.icon, blurb = t.blurb, say = t.say }
    return pack(items, function(slice) return { revision = built.revision, topic = meta, questions = slice } end)
end

local function send(playerId, payload)
    local values = countValues(payload)
    if values > 900 and type(TriggerLatentClientEvent) == "function" then
        warnOnce("latent", "guide: a message of %d values goes as a latent event: split that question", values)
        return TriggerLatentClientEvent(E.net.guide, playerId, 256 * 1024, payload)
    end
    return TriggerClientEvent(E.net.guide, playerId, payload)
end
Guide.send = send

-- ---------------------------------------------------------------------------
-- The NPC

local function hubCenter()
    local H = LightRpActivities and LightRpActivities.hub
    return H and H.center, H and tonumber(H.heading) or 0
end

local function parsePlacement(text)
    if type(text) ~= "string" then return nil end
    local x, y, z, h = text:match("^(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+),(%-?[%d%.]+)$")
    x, y, z, h = tonumber(x), tonumber(y), tonumber(z), tonumber(h)
    if not (x and y and z and h) then return nil end
    return { position = { x = x, y = y, z = z }, heading = h, source = "staff move (kvp)" }
end
Guide.parsePlacement = parsePlacement

-- Yaw (degrees about +Z, counter-clockwise, 0 facing +Y) from `from` towards `to`.
local function yawTowards(from, to)
    local dx, dy = to.x - from.x, to.y - from.y
    if dx == 0 and dy == 0 then return 0 end
    return math.deg(math.atan(-dx, dy))
end
Guide.yawTowards = yawTowards

-- Where Johnny stands: a staff move (KVP), else the config's position, else his
-- offset from The Crossing; facing the arrival point unless a heading is given.
function Guide.placement()
    if Guide.override then return Guide.override end
    local npc = C.npc
    local center, hubHeading = hubCenter()
    local position = npc.position
    local source = "config position"
    if type(position) ~= "table" then
        if not center then return nil end
        local o = npc.offset or {}
        local h = math.rad(hubHeading)
        local fx, fy, rx, ry = -math.sin(h), math.cos(h), math.cos(h), math.sin(h)
        local forward, right = tonumber(o.forward) or 0, tonumber(o.right) or 0
        position = { x = center.x + fx * forward + rx * right, y = center.y + fy * forward + ry * right, z = center.z + (tonumber(o.up) or 0) }
        source = "offset from " .. ((LightRpActivities.hub and LightRpActivities.hub.name) or "the hub")
    end
    local heading = tonumber(npc.heading)
    if heading == nil then heading = center and yawTowards(position, center) or 0 end
    return { position = position, heading = heading, source = source }
end

local function npcCandidates()
    local out = {}
    for _, c in ipairs(C.npc.candidates or {}) do out[#out + 1] = c end
    if C.npc.fallbackToClerks ~= false then
        for _, c in ipairs(LightRpConfig.rentals and LightRpConfig.rentals.npcPool or {}) do out[#out + 1] = c end
    end
    return out
end
Guide.npcCandidates = npcCandidates

local function spawnNpc(at)
    if type(Open77.npcs) ~= "table" or type(Open77.npcs.create) ~= "function" then
        LightRP.log("guide: NPC API unavailable; the guide point still works")
        return nil
    end
    for _, candidate in ipairs(npcCandidates()) do
        local definition = {
            position = { x = at.position.x, y = at.position.y, z = at.position.z }, yaw = at.heading, bucket = C.npc.bucket or 0,
            persistent = false, despawnWhenUnobserved = false, streamingRadius = C.npc.streamingRadius or 150.0,
            -- like the desk clerks: no threats, no stimuli, no barks
            behavior = { combatEnabled = false, perceptionEnabled = false, voiceEnabled = false },
        }
        if candidate.record then definition.record = candidate.record else definition.template = candidate.template end
        if candidate.appearance then definition.appearance = candidate.appearance end
        if type(Open77.npcs.damage) == "table" then definition.damagePolicy = Open77.npcs.damage.invulnerable or Open77.npcs.damage.immortal end
        if type(Open77.npcs.ai) == "table" then definition.aiMode = Open77.npcs.ai.tasks end
        local ok, npcId, reason = pcall(Open77.npcs.create, definition)
        if ok and npcId then
            -- the native agent makes a civilian wander or flee: stop it; the body stays
            local stillOk, stillErr = pcall(Open77.npcs.setAIEnabled, npcId, false)
            if not stillOk or stillErr == false then LightRP.log("guide: setAIEnabled refused: %s", tostring(stillErr)) end
            Guide.record = candidate.record or candidate.template
            LightRP.log("guide: %s spawned as NPC %s (%s, AI off) at %.2f, %.2f, %.2f heading %.1f", C.npc.name, tostring(npcId),
                tostring(Guide.record), at.position.x, at.position.y, at.position.z, at.heading)
            return npcId
        end
        LightRP.log("guide: %s refused (%s), trying the next candidate", tostring(candidate.record or candidate.template),
            tostring(ok and reason or npcId))
    end
    LightRP.log("guide: no NPC candidate accepted; the guide point still works")
    return nil
end

Guide.INTERACTION = "guide.npc"

local function registerPoint(at)
    local npc = C.npc
    local blip
    if npc.blip then
        blip = { icon = npc.blip.icon, sprite = npc.blip.sprite or "objective", title = npc.blip.title or npc.name,
            description = npc.blip.description, mapCategory = npc.blip.mapCategory, mapColor = npc.blip.mapColor }
    end
    LightRP.interaction(Guide.INTERACTION, { position = at.position, radius = npc.interactRadius or 2.0, bucket = npc.bucket or 0,
        label = npc.name, prompt = npc.prompt or ("Talk to " .. npc.name), key = "E", promptHeight = npc.promptHeight or 1.1,
        marker = npc.marker, ring = false, blip = blip })
end

-- Tell clients which NPC is Johnny (ALT + click on him, client/core/guide.lua).
local function announceNpc(target)
    send(target or -1, { npc = { id = Guide.npcId, name = C.npc.name, prompt = C.npc.contextLabel or C.npc.prompt } })
end

function Guide.spawn()
    if not C.enabled then return end
    local at = Guide.placement()
    if not at then LightRP.log("guide: no place for %s (no position and no hub)", C.npc.name); return end
    if Guide.npcId then pcall(Open77.npcs.remove, Guide.npcId); Guide.npcId = nil end
    Guide.npcId = spawnNpc(at)
    registerPoint(at)
    announceNpc()
end

function Guide.moveTo(at)
    Guide.override = at
    local moved = false
    if Guide.npcId and type(Open77.npcs) == "table" and type(Open77.npcs.setTransform) == "function" then
        local ok, done = pcall(Open77.npcs.setTransform, Guide.npcId, { position = at.position, yaw = at.heading })
        moved = ok and done ~= false
    end
    if moved then registerPoint(at); announceNpc() else Guide.spawn() end
end

CreateThread(function()
    if not C.enabled then return end
    Wait(900) -- after the platform's start-up, like the desks
    if Open77.kvp and type(Open77.kvp.get) == "function" then
        local ok, text = pcall(Open77.kvp.get, PLACEMENT_KEY)
        local saved = ok and parsePlacement(text) or nil
        if saved then Guide.override = saved; LightRP.log("guide: placed by a staff move (kvp %s); copy it into server/config/guide.lua", PLACEMENT_KEY) end
    end
    Guide.spawn()
    -- He is invulnerable, but a cleanup or a lost body brings him back.
    while true do
        Wait(60000)
        if Guide.npcId and type(Open77.npcs.get) == "function" then
            local ok, snapshot = pcall(Open77.npcs.get, Guide.npcId)
            if ok and snapshot == nil then LightRP.log("guide: NPC %s is gone, respawning", tostring(Guide.npcId)); Guide.npcId = nil; Guide.spawn() end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Talking

local sessions = {} -- playerId -> session expiry (ms)

local function canTalk(playerId)
    if not C.enabled then return false, C.npc.name .. " is not here right now." end
    if LightRP.characters and not LightRP.characters.isRegistered(playerId) then return false, "Finish your character first." end
    return true
end

function Guide.open(playerId, from)
    local ok, why = canTalk(playerId)
    if not ok then LightRP.result(playerId, false, why, "guide.open"); return false end
    sessions[playerId] = LightRP.nowMs() + Guide.SESSION_MS
    local index = Guide.indexPayload()
    LightRP.dialog(playerId, "guide", index)
    -- the bindings (client/core/guide.lua turns them into the player's own keys), then the search index
    send(playerId, { revision = index.revision, keys = Guide.keys() })
    for _, message in ipairs(Guide.searchMessages()) do send(playerId, message) end
    return true
end

local function inSession(playerId)
    local expires = sessions[playerId]
    if not expires or LightRP.nowMs() > expires then return false end
    sessions[playerId] = LightRP.nowMs() + Guide.SESSION_MS
    return true
end

function Guide.onInteract(playerId, id)
    if id == Guide.INTERACTION then Guide.open(playerId, "interact") end
end

-- ALT + click on Johnny: the same as E, from a little further away.
LightRP.action("guide.open", function(playerId)
    local at = Guide.placement()
    local p = playerId and playerId > 0 and Open77.players.position(playerId) or nil
    if not at or not p or (p.bucket or 0) ~= (C.npc.bucket or 0) then return end
    local range = C.npc.contextRange or 6.0
    if (p.x - at.position.x) ^ 2 + (p.y - at.position.y) ^ 2 + (p.z - at.position.z) ^ 2 > range * range then
        LightRP.result(playerId, false, "Walk up to " .. C.npc.name .. " first.", "guide.open")
        return
    end
    Guide.open(playerId, "context")
end)

-- The page asks for a topic it has not cached for this revision. Silent: no toast.
LightRP.action("guide.topic", function(playerId, payload)
    if not inSession(playerId) then return end
    local id = type(payload.id) == "string" and payload.id or ""
    local messages = Guide.topicMessages(id)
    if not messages then
        send(playerId, { revision = Guide.build().revision, missing = id })
        return
    end
    for _, message in ipairs(messages) do send(playerId, message) end
end)

-- "Mark on map": a GPS route to a place Light RP knows (the nearest of a kind).
LightRP.action("guide.gps", function(playerId, payload)
    if not inSession(playerId) then
        LightRP.result(playerId, false, "Talk to " .. C.npc.name .. " again.", "guide.gps")
        return
    end
    local from = playerId > 0 and Open77.players.position(playerId) or nil
    local target = Guide.resolveTarget(payload.target, from)
    if not target then LightRP.result(playerId, false, "That place is not on the map any more.", "guide.gps"); return end
    local hub = LightRP.activitiesHub
    if hub and type(hub.gps) == "function" then
        hub.gps(playerId, target.position, target.name, C.npc.name .. " marked it for you")
    else
        TriggerClientEvent(E.net.activitiesGps, playerId, { position = target.position, title = target.name, description = C.npc.name .. " marked it for you" })
    end
    LightRP.result(playerId, true, "GPS set: " .. target.name .. ".", "guide.gps")
end)

function Guide.onGameplayReady(playerId) announceNpc(playerId) end
function Guide.onDisconnected(playerId) sessions[playerId] = nil end

-- ---------------------------------------------------------------------------
-- Staff: place Johnny where you stand, facing where you face, and print the
-- line for server/config/guide.lua (survey style, server/modules/activities_hub.lua).

local function placementLine(at)
    return string.format("position = { x = %.3f, y = %.3f, z = %.3f }, heading = %.1f, -- bucket %d · guide",
        at.position.x, at.position.y, at.position.z, at.heading, C.npc.bucket or 0)
end
Guide.placementLine = placementLine

LightRP.command("lightrp.guide", { restricted = true, usage = "/lightrp.guide [where | move [crossing] | reset | respawn]" }, function(source, args)
    local op = string.lower(args[1] or "where")
    if op == "where" then
        local at = Guide.placement()
        if not at then return false, "No place for the guide." end
        return true, string.format("%s: NPC %s (%s), %s. %s", C.npc.name, tostring(Guide.npcId or "none"), tostring(Guide.record or "no record"),
            at.source or "", placementLine(at))
    elseif op == "move" then
        if not source or source <= 0 then return false, "In game only." end
        local read = type(Open77.players.get) == "function" and Open77.players.get(source) or nil
        local p = type(read) == "table" and read.position or Open77.players.position(source)
        if type(p) ~= "table" or type(p.x) ~= "number" then return false, "Your position is not available yet." end
        local bucket = type(GetPlayerRoutingBucket) == "function" and GetPlayerRoutingBucket(source) or (read and read.bucket) or p.bucket or 0
        if (tonumber(bucket) or 0) ~= (C.npc.bucket or 0) then return false, string.format("Stand in bucket %d (the city) to place him.", C.npc.bucket or 0) end
        local heading = type(read) == "table" and tonumber(read.heading or read.yaw) or 0
        local position = { x = p.x, y = p.y, z = p.z }
        if string.lower(args[2] or "") == "crossing" then
            local center = hubCenter()
            if center then heading = yawTowards(position, center) end
        end
        local at = { position = position, heading = heading, source = "staff move (kvp)" }
        if Open77.kvp and type(Open77.kvp.set) == "function" then
            local ok, why = Open77.kvp.set(PLACEMENT_KEY, string.format("%.3f,%.3f,%.3f,%.1f", position.x, position.y, position.z, heading))
            if not ok then LightRP.log("guide: placement not saved (%s)", tostring(why)) end
        end
        Guide.moveTo(at)
        local line = placementLine(at)
        LightRP.log("guide moved by %s: %s", LightRP.characters and LightRP.characters.displayName(source) or tostring(source), line)
        return true, line .. "  (paste into LightRpGuide.npc; kept until /lightrp.guide reset)"
    elseif op == "reset" then
        if Open77.kvp and type(Open77.kvp.delete) == "function" then pcall(Open77.kvp.delete, PLACEMENT_KEY) end
        Guide.override = nil
        local at = Guide.placement()
        if not at then return false, "No place for the guide." end
        Guide.moveTo(at)
        Guide.override = nil
        return true, "Back to the config: " .. placementLine(at)
    elseif op == "respawn" then
        Guide.spawn()
        return true, string.format("%s respawned: NPC %s (%s).", C.npc.name, tostring(Guide.npcId or "none"), tostring(Guide.record or "no record"))
    end
    return false
end)
