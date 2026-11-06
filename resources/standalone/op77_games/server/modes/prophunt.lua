-- Prop Hunt: props become objects and hide, hunters are held blind, then hunt them. One hunter
-- per 4 players, picked here (a room has no teams). Hunters win when every prop is found, props
-- win by lasting the clock. A found prop joins the hunters (the source's live setting,
-- FOUND_JOINS_HUNTERS on). The clock is the map's hide + hunt.
--
-- The body. A prop's body is hidden from the others (Open77.players.setVisible) and a server
-- prop is attached to it. It stays solid and shootable: collision is never touched (attached
-- props are visual only, no ghosting here), a hunter shooting the object hits the hidden body.
-- The platform drops the hide on death, respawn and a bucket change, so it is read back
-- every 2 s while wanted.
--
-- Health is a ledger on the server, not the body's. The source set the body's maximum and
-- turned its regeneration off, then gave back a fixed 100 and "regen on": over Light RP that
-- wipes the implants' maximum (cyberware.lua applyPassives) and lifts a starving body's no-regen
-- (needs.lua). Here a hunter's hit is refused and counted against the object's own health
-- (`damage` hook), so the real health, maximum, regeneration, armour and worn clothes are
-- never changed and nothing about them has to come back.
--
-- A found prop does not die: the object goes, a beat later it is sent to the hunters' spawn,
-- shown and armed. Only a real death (a fall, out of bounds) goes through the engine's respawn.
--
-- Every exit passes G.release (`left`, which E.remove and E.shutdown both call): prop deleted,
-- body shown, blackout cleared, freeze dropped, client told. The end of a match does the
-- same for everyone at once (`results`). A show the platform refuses is asked again: nobody
-- stays invisible in the world. Provider stop: the platform also drops hide, freeze and props.
--
-- Clients only ask (op77_games:prophunt:action): sender, match, role, phase and cooldown
-- are checked here. The lists of actions and keys are in client/prophunt.lua.
local E = GamesEngine
local C = GamesCombat

local HUNTERS, PROPS = 1, 2

local PH = {
    perHunter = 4,          -- 1 hunter per this many players, at least 1, never everyone
    hideChange = 1,         -- s between two objects while hiding (the map's own while hunting)
    rotateStep = 45,        -- degrees
    tries = 8,              -- objects one attempt tries before it waits for the retry
    retryMs = 2000,         -- a prop nothing would hold on is tried again this often
    checkMs = 2000,         -- the hide is read back this often
    joinDelayMs = 2500,     -- a found prop: the find plays out, then it comes back as a hunter
    pulseCooldown = 30,     -- s
    pulseShowMs = 3000,
    pulseBands = { { band = "HOT", within = 15, tone = "danger" }, { band = "WARM", within = 35, tone = "accent" } }, -- else COLD
    finalSeconds = 60,      -- the final minute: forced whistles twice as often
    hitFxMs = 350,          -- at most one spark per prop this often
    whistleRange = 80,      -- metres
    whistleFile = "audio/whistle.wav",
    whistleSeconds = 0.7,
    actionMs = 100,         -- one player's asks, at most this often
    stateMs = 5000,         -- each client is told its role this often, whatever changed
    showTries = 5,          -- a refused show, asked again this many times
    showRetryMs = 1000,
    respawnMs = 3000,
    spreadProps = 3.0, spreadHunters = 1.5,
    blindMargin = 5,        -- s past the hunt: a dead client or a refused clear ends by itself
}

GamesProphunt = { rules = PH, HUNTERS = HUNTERS, PROPS = PROPS }
local G = GamesProphunt

-- Every object a prop may become: alias, name, size class, health. Curated aliases only: a
-- raw .mesh or .ent worn on a body trembles against it. Size class: small is a gamble, large an
-- obvious shape that takes more to bring down.
local SIZE_HEALTH = { s = 60, m = 100, l = 140 }
local ROWS = {
    { "container.barrel", "Barrel", "m", 90 },
    { "container.locker", "Locker", "m", 110 },
    { "bin.dumpster.small", "Small dumpster", "l", 140 },
    { "kitchen.fridge", "Fridge", "m", 120 },
    { "electronics.arcade", "Arcade cabinet", "m", 110 },
    { "electronics.vending_machine.drink", "Drinks machine", "l", 150 },
    { "industrial.generator", "Generator", "l", 130 },
    { "vegetation.planter.large", "Large planter", "m", 100 },
    { "garbage.bag", "Trash bags", "s", 60 },
    { "bin.trash_can", "Trash can", "s", 70 },
    { "container.keg", "Keg", "s", 70 },
    { "street.parking_meter", "Parking meter", "s", 60 },
    { "street.newspaper_stand", "Newspaper box", "s", 80 },
    { "music.amplifier", "Amplifier", "s", 70 },
    { "furniture.chair.metal", "Metal chair", "s", 50 },
    { "crate.small", "Small crate", "s", 60 },
    { "container.gas_can", "Jerrycan", "s", 50 },
    { "street.hydrant", "Fire hydrant", "s", 60 },
    { "decor.vase.large", "Large vase", "s", 70 },
    { "container.gas_tank", "Gas tank", "m", 90 },
    { "container.safe", "Safe", "m", 120 },
    { "crate.delivery.tall", "Delivery crate", "m", 100 },
    { "crate.cargo", "Cargo crate", "m", 110 },
    { "military.case.large", "Military case", "m", 90 },
    { "kitchen.fridge.poor", "Old fridge", "m", 110 },
    { "kitchen.stove", "Stove", "m", 100 },
    { "office.cabinet.file", "File cabinet", "m", 100 },
    { "electronics.jukebox", "Jukebox", "m", 110 },
    { "electronics.vending_machine.small", "Snack machine", "m", 110 },
    { "street.electrical_box", "Electrical box", "m", 100 },
    { "medical.cart", "Medical cart", "m", 90 },
    { "medical.iv_stand", "IV stand", "m", 90 },
    { "furniture.cabinet.industrial", "Industrial cabinet", "m", 120 },
    { "electronics.server", "Server rack", "l", 130 },
    { "industrial.gas_pump", "Gas pump", "l", 130 },
    { "furniture.shelf.industrial", "Industrial shelf", "l", 130 },
    { "market.stand.small", "Market stand", "l", 140 },
    { "bin.dumpster.medium", "Dumpster", "l", 160 },
    { "electronics.vending_machine", "Vending machine", "l", 150 },
    { "industrial.machine", "Machinery", "l", 140 },
    { "furniture.chair.plastic", "Plastic chair", "s" },
    { "furniture.stool.metal", "Metal stool", "s", 50 },
    { "furniture.stool.bar", "Bar stool", "s", 50 },
    { "furniture.bench.wood", "Wooden bench", "m", 90 },
    { "furniture.bench.metal", "Metal bench", "m", 90 },
    { "furniture.bench.outdoor", "Street bench", "m", 90 },
    { "furniture.table.industrial", "Workbench", "m" },
    { "furniture.table.lab", "Lab table", "m" },
    { "furniture.table.outdoor", "Patio table", "m", 90 },
    { "furniture.table.bar", "Bar table", "m", 90 },
    { "furniture.counter.bar", "Bar counter", "l" },
    { "furniture.sofa.poor", "Old sofa", "l", 130 },
    { "furniture.bed.single", "Bed", "l", 130 },
    { "furniture.cabinet.glass", "Glass cabinet", "m" },
    { "office.desk", "Desk", "m" },
    { "office.desk.corpo", "Corpo desk", "m", 110 },
    { "office.chair", "Office chair", "s" },
    { "office.chair.corpo", "Executive chair", "s", 70 },
    { "office.reception_desk", "Reception desk", "l", 150 },
    { "kitchen.counter", "Kitchen counter", "m", 110 },
    { "kitchen.coffee_machine", "Coffee machine", "s" },
    { "bathroom.toilet", "Toilet", "s", 70 },
    { "bathroom.shower", "Shower", "l", 130 },
    { "crate.valuable", "Loot crate", "s", 70 },
    { "crate.delivery", "Parcel crate", "m", 90 },
    { "crate.cardboard", "Cardboard box", "s", 50 },
    { "crate.ammo_box", "Ammo box", "s", 50 },
    { "container.toolbox", "Toolbox", "s", 50 },
    { "container.ammo_case", "Ammo case", "s", 60 },
    { "container.water_jug", "Water jug", "s", 50 },
    { "container.bucket", "Bucket", "s", 50 },
    { "barrier.concrete", "Concrete barrier", "m", 120 },
    { "barrier.blockade.wide", "Wide blockade", "l" },
    { "barrier.blockade.mechanical", "Road blocker", "l" },
    { "barrier.hesco", "Hesco wall", "l", 150 },
    { "barrier.pedestrian", "Crowd barrier", "m", 90 },
    { "barrier.road", "Road barrier", "m" },
    { "barrier.road.jersey", "Jersey barrier", "m", 120 },
    { "barrier.roadblock.concrete", "Concrete roadblock", "l" },
    { "sign.street", "Street sign", "m", 90 },
    { "sign.kiosk_frame", "Kiosk frame", "m", 90 },
    { "street.ac_unit", "AC unit", "m" },
    { "bin.dumpster.large", "Large dumpster", "l", 160 },
    { "bin.trash_can.small", "Small trash can", "s", 50 },
    { "garbage.cardboard_pile", "Cardboard pile", "s", 70 },
    { "garbage.street_trash", "Street trash", "s", 70 },
    { "garbage.industrial_trash", "Scrap heap", "m" },
    { "garbage.mattress", "Old mattress", "m", 90 },
    { "debris.pile", "Rubble", "m" },
    { "debris.construction_pile", "Building rubble", "m", 110 },
    { "debris.sand_pile", "Sand pile", "m" },
    { "pallet.wood.loaded", "Loaded pallet", "m" },
    { "pallet.stack", "Pallet stack", "m" },
    { "industrial.forklift", "Forklift", "l", 160 },
    { "industrial.pallet_truck", "Pallet truck", "m", 90 },
    { "industrial.fire_extinguisher", "Fire extinguisher", "s", 50 },
    { "industrial.trolley", "Trolley", "m", 90 },
    { "industrial.cart", "Industrial cart", "m" },
    { "industrial.shop_rack", "Shop rack", "l" },
    { "industrial.vent.rooftop", "Rooftop vent", "m" },
    { "industrial.vent.shaft", "Vent shaft", "m" },
    { "electronics.monitor", "Monitor", "s", 50 },
    { "electronics.monitor.device", "Screen terminal", "s" },
    { "electronics.cash_register", "Cash register", "s", 50 },
    { "electronics.air_conditioner", "Air conditioner", "m" },
    { "vegetation.planter.city", "City planter", "m", 90 },
    { "vegetation.flower_pot", "Flower pot", "s" },
    { "vegetation.flower_pot.kitsch", "Kitsch flower pot", "s" },
    { "market.stand", "Market stall", "l", 150 },
    { "market.kiosk", "Kiosk", "l", 150 },
    { "market.shelf.chinese", "Shop shelf", "m", 110 },
    { "market.cabinet.chinese", "Shop cabinet", "m" },
    { "food.street_food", "Food stand", "m", 110 },
    { "medical.device", "Medical device", "m", 90 },
    { "medical.container", "Medical container", "s" },
    { "medical.morgue_table", "Morgue table", "l", 130 },
    { "medical.body_bag", "Body bag", "m", 90 },
    { "military.case", "Military crate", "s", 70 },
    { "military.weapon_rack", "Weapon rack", "m", 110 },
    { "recreation.billiard_table", "Pool table", "l", 150 },
    { "recreation.roulette_table", "Roulette table", "l" },
    { "recreation.gym_equipment", "Gym machine", "m", 110 },
    { "recreation.tent", "Tent", "l" },
    { "recreation.sleeping_bag", "Sleeping bag", "s", 70 },
    { "music.guitar.electric", "Electric guitar", "s", 50 },
    { "music.piano", "Piano", "l" },
    { "decor.sculpture.arasaka", "Arasaka sculpture", "l" },
    { "decor.sculpture.chinese", "Statue", "m", 110 },
    { "tool.welder", "Welder", "s" },
}

-- The families V walks: each object in its picker category of the source.
local FAMILIES = {
    { label = "Street", prefixes = { "street", "bin", "garbage", "debris", "barrier", "sign", "pallet" } },
    { label = "Crates", prefixes = { "container", "crate" } },
    { label = "Furniture", prefixes = { "furniture", "office", "bathroom", "decor", "vegetation" } },
    { label = "Kitchen and shops", prefixes = { "kitchen", "food", "market" } },
    { label = "Tech and leisure", prefixes = { "electronics", "music", "recreation" } },
    { label = "Industrial", prefixes = { "industrial", "tool" } },
    { label = "Medical and military", prefixes = { "medical", "military" } },
}

local familyOf = {}
for index, family in ipairs(FAMILIES) do
    for _, prefix in ipairs(family.prefixes) do familyOf[prefix] = index end
end

G.catalog, G.families = {}, FAMILIES
for index, row in ipairs(ROWS) do
    G.catalog[index] = { model = row[1], label = row[2], health = row[4] or SIZE_HEALTH[row[3]], family = familyOf[row[1]:match("^[^.]+")] }
end

-- The objects a map allows, as catalogue indices. A map's `props` lists aliases; none (or none
-- we still know): the whole catalogue.
function G.propOptions()
    local options = {}
    for index, object in ipairs(G.catalog) do options[index] = { id = object.model, label = object.label } end
    return options
end

function G.pool(map)
    local wanted, pool = {}, {}
    for _, model in ipairs(type(map.props) == "table" and map.props or {}) do wanted[model] = true end
    for index, object in ipairs(G.catalog) do
        if wanted[object.model] then pool[#pool + 1] = index end
    end
    if #pool == 0 then
        for index in ipairs(G.catalog) do pool[index] = index end
    end
    return pool
end

-- An alias the platform refused by name is left out for the rest of this run.
local refused = {}
G.refused = refused

-- ---------------------------------------------------------------- rules --

function G.hunterCount(players)
    return math.max(1, math.min(players - 1, math.floor(players / PH.perHunter)))
end

-- 1..count in a random order: everyone starts on a different object, R sees each one once.
function G.shuffled(count)
    local order = {}
    for index = 1, count do order[index] = index end
    for index = count, 2, -1 do
        local other = math.random(index)
        order[index], order[other] = order[other], order[index]
    end
    return order
end

-- The first step after `slot` of `order` on the family after the current one.
function G.nextFamilySlot(order, slot)
    local catalog = G.catalog
    local count = #FAMILIES
    local here = catalog[order[slot]].family
    for shift = 1, count - 1 do
        local wanted = (here + shift - 1) % count + 1
        for step = 1, #order do
            local at = (slot + step - 1) % #order + 1
            if catalog[order[at]].family == wanted then return at end
        end
    end
    return slot
end

function G.pulseBand(metres)
    for _, band in ipairs(PH.pulseBands) do
        if metres <= band.within then return band.band, band.tone end
    end
    return "COLD", "info"
end

local function changeCooldownMs(match)
    local seconds = match.map.changeCooldown or 5
    if match.ph.phase == "hide" then seconds = math.min(seconds, PH.hideChange) end
    return seconds * 1000
end

local function hiding(p)
    local s = p.ph
    return s.role == "prop" and s.foundBy == nil and s.foundFrom == nil
end

-- Props still to find, among the present.
local function propsLeft(match)
    local count = 0
    for _, p in pairs(match.players) do
        if hiding(p) then count = count + 1 end
    end
    return count
end

local function huntersOn(match)
    local count = 0
    for _, p in pairs(match.players) do
        if p.ph.role == "hunter" then count = count + 1 end
    end
    return count
end

-- ---------------------------------------------------------------- the client --

local function tell(p) TriggerClientEvent("op77_games:prophunt", p.id, { role = p.ph.role }) end

local function tellOff(id) TriggerClientEvent("op77_games:prophunt", id, nil) end

-- ---------------------------------------------------------------- the body --

local function warnOnce(s, key, text)
    s.warned = s.warned or {}
    if s.warned[key] then return end
    s.warned[key] = true
    E.log(text)
end

-- Hidden from the others. Change-gated: each setVisible is a state every client re-applies
-- to the body the prop hangs on. The next read-back comes sooner after a refusal.
local function hide(p, t)
    local s = p.ph
    s.hidden = true
    local read, visible = pcall(Open77.players.isVisible, p.id)
    local done = read and visible == false
    if not done then
        local called, ok, why = pcall(Open77.players.setVisible, p.id, false)
        done = called and ok == true
        if not done then warnOnce(s, "hide", ("%d not hidden: %s"):format(p.id, tostring(called and why or ok))) end
    end
    s.checkAt = t + (done and PH.checkMs or 500)
end

local function show(id)
    local read, visible = pcall(Open77.players.isVisible, id)
    if read and visible == true then return true end
    local called, ok, why = pcall(Open77.players.setVisible, id, true)
    if called and ok == true then return true end
    E.log(("%d not shown: %s"):format(id, tostring(called and why or ok)))
    return false
end

-- Never duration 0 (held until cleared): the platform ends it even if the clear never lands.
local function blind(match, p)
    p.ph.blind = true
    local left = math.ceil((match.ph.huntAt - E.now()) / 1000)
    local duration = math.max(1, math.min(600, left + PH.blindMargin))
    local ok, done, why = pcall(Open77.effects.screen, p.id, "blackout", { duration = duration })
    if not (ok and done) then warnOnce(p.ph, "blind", ("blackout refused for %d: %s"):format(p.id, tostring(ok and why or done))) end
end

local function sight(p)
    if not p.ph.blind then return end
    p.ph.blind = nil
    pcall(Open77.effects.clearScreen, p.id)
end

local function dropProp(s)
    if s.propId then pcall(Open77.props.remove, s.propId) end
    s.propId = nil
end

-- A show the platform refused (a body between two life states), asked again. The way back
-- moves the body to another bucket, which drops the hide by itself; this is for when it does not.
local function showLater(id, tries)
    SetTimeout(PH.showRetryMs, function()
        if E.stopped or E.matchOf(id) ~= nil or Open77.players.name(id) == nil then return end
        if not show(id) and tries > 1 then showLater(id, tries - 1) end
    end)
end

-- Everything this mode did to a body comes back. Safe twice; `gone`: no body left to ask.
function G.release(p, gone)
    local s = p.ph
    if s == nil then return end
    dropProp(s)
    s.hidden, s.joinAt, s.joining = nil, nil, nil
    if gone then return end
    sight(p)
    if p.frozen then E.setFrozen(p, false) end
    s.locked = nil
    if not show(p.id) then showLater(p.id, PH.showTries) end
    tellOff(p.id)
end

-- ---------------------------------------------------------------- disguise --

-- Puts one catalogue object on a prop. The old one goes once the new one holds: a refusal
-- keeps the disguise. Health keeps its share (a wounded barrel is no fresh fridge).
local function wear(match, p, object, t)
    local s = p.ph
    if refused[object.model] then return false end
    local at = Open77.players.position(p.id)
    if type(at) ~= "table" then return false end
    local ttlMs = (match.seconds + 120) * 1000 -- nothing outlives the match, whatever fails
    local id, why = Open77.props.create({ model = object.model, position = { x = at.x, y = at.y, z = at.z }, yaw = s.yaw,
        bucket = match.bucket, streamingRadius = 150, visible = false, ttlMs = ttlMs })
    if not id then
        if why == "unknown_alias" or why == "invalid_model" then
            refused[object.model] = true
            E.log(("prop %s refused (%s): left out"):format(object.model, tostring(why)))
        end
        return false
    end
    local bound, reason = Open77.props.attach(id, { parentType = "player", parentId = p.id, bone = "",
        offset = { x = 0, y = 0, z = 0 }, rotation = { x = 0, y = 0, z = s.yaw } })
    if bound then bound, reason = Open77.props.update(id, { visible = true }) end
    if not bound then
        pcall(Open77.props.remove, id)
        warnOnce(s, "attach", ("prop not attached to %d: %s"):format(p.id, tostring(reason)))
        return false
    end
    local share = s.propId and math.max(0.05, math.min(1, s.hp / s.maxHp)) or 1
    dropProp(s)
    s.propId, s.object = id, object
    s.maxHp, s.hp = object.health, math.max(1, math.floor(object.health * share))
    hide(p, t)
    return true
end

-- From step `from` of this prop's order, wrapping, until one holds: at most PH.tries.
local function wearFrom(match, p, from, t)
    local s = p.ph
    local order = s.order
    for step = 0, math.min(#order, PH.tries) - 1 do
        local slot = (from + step - 1) % #order + 1
        if wear(match, p, G.catalog[order[slot]], t) then
            s.slot = slot
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------- whistle --

local function nextAuto(match, t)
    local every = match.map.autoWhistleSeconds or 0
    if every <= 0 then return nil end
    return t + every * 1000 * (match.ph.final and 0.5 or 1)
end

-- Heard around the prop, by its match only.
local function whistle(match, p, t)
    local s = p.ph
    s.whistleAt, s.autoAt = t, nextAuto(match, t)
    local at = E.read(p.id)
    if at == nil or type(Open77.audio) ~= "table" then return end
    local ok, id, why = pcall(Open77.audio.play3D, PH.whistleFile, { x = at.x, y = at.y, z = at.z },
        { network = true, bucket = match.bucket, volume = 1, minDistance = 6, maxDistance = PH.whistleRange, duration = PH.whistleSeconds })
    if not ok or not id then
        warnOnce(s, "whistle", "whistle refused: " .. tostring(ok and why or id))
        return
    end
    SetTimeout(3000, function() pcall(Open77.audio.destroy, id) end)
end

-- ---------------------------------------------------------------- hunters --

-- Held on the spawn, blind, until the hunt.
local function hold(match, p)
    E.setFrozen(p, true)
    blind(match, p)
    p.holdUntil = match.ph.huntAt
end

local function loose(match, p)
    if p.frozen then E.setFrozen(p, false) end
    sight(p)
    p.holdUntil = 0
    if p.alive then C.arm(match, p, C.configured("prophunt")) end
end

local function startHunt(match, t)
    local ph = match.ph
    ph.phase, ph.huntedAt = "hunt", t
    for _, p in pairs(match.players) do
        if p.ph.role == "hunter" and not p.ph.joining and not p.ph.joinAt then loose(match, p) end
    end
    E.feed(match, "The hunters are loose", "danger")
    E.banner(match, "THE HUNT IS ON", "", "danger", 2000)
    E.cue(match, "red")
end

-- ---------------------------------------------------------------- finds --

-- `finder` nil: a real death nobody caused. The object goes, the role changes at once; the
-- body comes to the hunters' spawn a beat later (a dead one by the engine's respawn).
local function found(match, p, t, finder)
    local ph, s = match.ph, p.ph
    local at = E.read(p.id)
    s.foundBy = finder or p
    s.lastedMs = ph.huntedAt and t - ph.huntedAt or 0
    dropProp(s)
    s.role, s.joined = "hunter", true
    s.autoAt, s.retryAt, s.locked = nil, nil, nil
    p.side = HUNTERS
    C.join(match, p)
    ph.found = ph.found + 1
    if finder then
        finder.kills = finder.kills + 1
        if p.alive then p.deaths = p.deaths + 1 end -- a real death is the engine's count
        E.feed(match, ("%s found %s"):format(finder.name, p.name), "success")
    else
        E.feed(match, p.name .. " is out", "info")
    end
    E.banner(p.id, "FOUND", "You join the hunters.", "danger", PH.joinDelayMs)
    E.cue(match, "hit")
    if at then pcall(Open77.effects.play, "sparks.burst.small", { position = { x = at.x, y = at.y, z = at.z + 0.8 }, bucket = match.bucket, range = 120 }) end
    if p.alive then
        s.joinAt = t + PH.joinDelayMs
        E.setFrozen(p, true)
    else
        s.joining, s.hidden = true, nil
    end
    tell(p)
end

-- A hunter's hit, counted in the arbiter, shows here: the arbiter is no place for effects.
local function hitShows(match, p, t)
    local s = p.ph
    local attacker = s.hitBy and match.players[s.hitBy]
    s.hitBy = nil
    if attacker then E.cue(attacker.id, "hit") end
    if t - (s.hitFxAt or -math.huge) < PH.hitFxMs then return end
    s.hitFxAt = t
    pcall(Open77.effects.screen, p.id, "pain", {})
    local at = E.read(p.id)
    if at then pcall(Open77.effects.play, "sparks.burst.small", { position = { x = at.x, y = at.y, z = at.z + 1 }, bucket = match.bucket, range = 120 }) end
end

-- ---------------------------------------------------------------- ticks --

local function tickProp(match, p, t)
    local s = p.ph
    if s.hitBy then hitShows(match, p, t) end
    if s.foundFrom then
        local finder = match.players[s.foundFrom] -- nil: that hunter left since
        s.foundFrom = nil
        return found(match, p, t, finder)
    end
    if not p.alive or t < p.holdUntil then return end
    if t >= (s.checkAt or 0) then hide(p, t) end
    if s.propId == nil and t >= (s.retryAt or 0) then
        s.retryAt = t + PH.retryMs
        -- Not the same objects again: the next try starts past them.
        if wearFrom(match, p, s.slot, t) then s.retryAt = nil
        else s.slot = (s.slot + PH.tries - 1) % #s.order + 1 end
    end
    if s.autoAt and t >= s.autoAt then whistle(match, p, t) end
end

local function tickHunter(match, p, t)
    local ph, s = match.ph, p.ph
    if s.joinAt then
        if t < s.joinAt then return end
        s.joinAt = nil
        E.setFrozen(p, false)
        s.hidden = nil
        if not show(p.id) then showLater(p.id, PH.showTries) end
        s.joining = true
        tell(p)
        E.sendBack(match, p)
    elseif s.joining then
        -- landed or not: the body is out of the fight's way only as long as it flies
        if not p.alive or p.move or t < p.holdUntil then return end
        s.joining = nil
        E.feed(match, p.name .. " joins the hunters", "info")
        if ph.phase == "hide" then hold(match, p) else loose(match, p) end
    elseif p.alive and not p.move then
        if ph.phase == "hide" and not p.frozen and t >= (s.holdAt or 0) then
            s.holdAt = t + 1000
            hold(match, p)
        elseif ph.phase == "hunt" and not p.armed then
            loose(match, p)
        end
    end
end

local function enterFinal(match, t)
    local ph = match.ph
    ph.final = true
    E.feed(match, "Final minute: the props whistle twice as often", "danger")
    E.cue(match, "red")
    local every = match.map.autoWhistleSeconds or 0
    if every <= 0 then return end
    for _, p in pairs(match.players) do
        if p.ph.autoAt then p.ph.autoAt = math.min(p.ph.autoAt, t + every * 500) end
    end
end

-- ---------------------------------------------------------------- what a client may ask --

-- A prop in the round, not found. nil otherwise.
local function activeProp(match, p)
    if p.alive and hiding(p) and match.ph.phase ~= "countdown" then return p.ph end
    return nil
end

local function change(match, p, t, slot)
    local s = activeProp(match, p)
    if not s or t - (s.changeAt or -math.huge) < changeCooldownMs(match) then return end
    s.changeAt = t
    if wearFrom(match, p, slot(s), t) then s.retryAt = nil end
    tell(p)
end

local ACTIONS = {
    next = function(match, p, t)
        change(match, p, t, function(s) return s.slot % #s.order + 1 end)
    end,
    family = function(match, p, t)
        change(match, p, t, function(s) return G.nextFamilySlot(s.order, s.slot) end)
    end,
    whistle = function(match, p, t)
        local s = activeProp(match, p)
        local cooldown = (match.map.whistleCooldown or 8) * 1000
        if s and t - (s.whistleAt or -math.huge) >= cooldown then whistle(match, p, t) end
    end,
    rotate = function(match, p)
        local s = activeProp(match, p)
        if not s or not s.propId then return end
        s.yaw = (s.yaw + PH.rotateStep) % 360
        local turned, why = Open77.props.setAttachmentTransform(s.propId, nil, { x = 0, y = 0, z = s.yaw })
        if not turned then warnOnce(s, "rotate", "prop did not turn: " .. tostring(why)) end
    end,
    -- Held where it stands (the view still turns), so the object does not drift.
    lock = function(match, p)
        local s = activeProp(match, p)
        if not s or p.move then return end
        if E.setFrozen(p, not p.frozen) then s.locked = p.frozen or nil end
    end,
    -- How warm the nearest prop is, never where.
    pulse = function(match, p, t)
        local s = p.ph
        if s.role ~= "hunter" or not p.alive or match.ph.phase ~= "hunt" or s.joining or s.joinAt then return end
        if t - (s.pulseAt or -math.huge) < PH.pulseCooldown * 1000 then return end
        local here = E.read(p.id)
        if here == nil then return end
        local nearest = math.huge
        for _, other in pairs(match.players) do
            local there = hiding(other) and E.read(other.id) or nil
            if there then nearest = math.min(nearest, E.distance(here, there)) end
        end
        local band, tone = G.pulseBand(nearest)
        s.pulseAt, s.pulse, s.pulseUntil = t, band, t + PH.pulseShowMs
        E.banner(p.id, "PULSE", band, tone, PH.pulseShowMs)
    end,
}

local definition -- this mode's def, below

-- Everything from the client is a wish: its sender goes first.
RegisterNetEvent("op77_games:prophunt:action", function(action)
    local id = E.playerId(source)
    local match = id and E.matchOf(id) or nil
    if match == nil or match.def ~= definition or match.phase ~= "running" then return end
    local p = match.players[id]
    local handler = type(action) == "string" and ACTIONS[action] or nil
    if p == nil or handler == nil then return end
    local t = E.now()
    if t < (p.ph.actionAt or 0) then return end
    p.ph.actionAt = t + PH.actionMs
    local ok, why = pcall(handler, match, p, t)
    if not ok then E.log(("prophunt %s failed for %d: %s"):format(action, id, tostring(why))) end
end)

-- ---------------------------------------------------------------- HUD --

local function secondsLeft(at, t) return math.max(0, math.ceil((at - t) / 1000)) end

local function hint(bind, key, label) return { bind = "games.prophunt." .. bind, key = key, label = label } end

local function propHud(match, p, view, t)
    local s, ph = p.ph, match.ph
    view.objective = ph.phase == "hide" and "Pick an object and hide" or "Stay hidden until the clock runs out"
    local object = s.object and s.object.label or "Nothing yet"
    local nextObject = s.order and G.catalog[s.order[s.slot % #s.order + 1]].label or "-"
    view.stats = {
        { label = "Object", value = object },
        { label = "Health", value = ("%d / %d"):format(math.ceil(s.hp), s.maxHp) },
        { label = "Next", value = nextObject },
        { label = "Props left", value = tostring(propsLeft(match)) },
    }
    -- Six keys, four hint slots: the two that matter least take turns.
    local second = math.floor(t / 6000) % 2 == 1
    view.hints = {
        hint("next", "R", "Next object"),
        second and hint("rotate", "G", "Turn it") or hint("family", "V", "Next family"),
        hint("whistle", "T", "Whistle"),
        second and hint("view", "N", "First / third person") or hint("lock", "O", s.locked and "Free" or "Lock in place"),
    }
end

local function hunterHud(match, p, view, t)
    local s, ph = p.ph, match.ph
    if s.joinAt or s.joining then view.objective = "Found: you join the hunters"
    elseif ph.phase == "hide" then view.objective = "The props are hiding"
    else view.objective = "Find every prop" end
    local pulse = "Ready"
    if s.pulseUntil and t < s.pulseUntil then pulse = s.pulse
    elseif t - (s.pulseAt or -math.huge) < PH.pulseCooldown * 1000 then pulse = ("%d s"):format(secondsLeft(s.pulseAt + PH.pulseCooldown * 1000, t)) end
    view.stats = {
        { label = "Props left", value = tostring(propsLeft(match)) },
        { label = "Hunters", value = tostring(huntersOn(match)) },
        { label = "Pulse", value = pulse },
    }
    view.hints = { hint("pulse", "Z", "Pulse") }
end

-- ---------------------------------------------------------------- the mode --

definition = E.mode({
    id = "games.prophunt", key = "prophunt", label = "Prop Hunt", kind = "event",
    description = "Hide as an object, or hunt the objects that breathe. One hunter per four players, a found prop joins the hunters.",
    minPlayers = 2, maxPlayers = 16,
    -- The area is drawn around the props' spawn (flat, see below); `centre` is that point.
    schema = {
        points = {
            { key = "propsSpawn", label = "Props' spawn", color = "#3ddc84" },
            { key = "huntersSpawn", label = "Hunters' spawn", color = "#ff4d4d" },
        },
        numbers = {
            { key = "radius", label = "Play area radius", min = 10, max = 400, default = 65, unit = "m" },
            { key = "hideSeconds", label = "Hide time", min = 10, max = 180, default = 45, unit = "s", integer = true },
            { key = "roundSeconds", label = "Hunt time", min = 60, max = 1200, default = 300, unit = "s", integer = true },
            { key = "autoWhistleSeconds", label = "Forced whistle every", min = 0, max = 300, default = 60, unit = "s", integer = true },
            { key = "whistleCooldown", label = "Whistle cooldown", min = 1, max = 60, default = 8, unit = "s", integer = true },
            { key = "changeCooldown", label = "Object change cooldown", min = 1, max = 60, default = 5, unit = "s", integer = true },
        },
        choices = { { key = "props", label = "Objects", about = "None ticked: every object.", options = G.propOptions() } },
        area = { centre = "propsSpawn", radius = "radius", flat = true, holds = { "huntersSpawn" } },
    },
    prepare = function(map)
        map.centre = map.propsSpawn
        map.spawns = { map.propsSpawn, map.huntersSpawn } -- spawnFor reads the named two; this is the engine's fallback
    end,
    pvp = true, respawnMs = PH.respawnMs,
    flatBounds = true, -- the source's area ignores height (prophunt/server.lua distance2d)

    setup = function(match)
        local map, list = match.map, E.members(match)
        match.seconds = (map.hideSeconds or 45) + (map.roundSeconds or 300)
        match.ph = { phase = "countdown", found = 0, total = #list, pool = G.pool(map) }
        local order = G.shuffled(#list)
        local hunters = G.hunterCount(#list)
        for index, p in ipairs(list) do
            local hunter = order[index] <= hunters
            p.side = hunter and HUNTERS or PROPS
            p.ph = { role = hunter and "hunter" or "prop", hp = 100, maxHp = 100 } -- the hp of no object yet
        end
    end,

    spawnFor = function(match, p)
        if p.ph.role == "hunter" then return match.map.huntersSpawn, PH.spreadHunters end
        return match.map.propsSpawn, PH.spreadProps
    end,

    start = function(match)
        local map, ph, t = match.map, match.ph, E.now()
        ph.phase, ph.huntAt, ph.tellAt = "hide", t + (map.hideSeconds or 45) * 1000, t + PH.stateMs
        for _, p in ipairs(E.members(match)) do
            local s = p.ph
            -- Light RP only stands aside: an RP gun stays in its native slot. Put away, never
            -- removed; the client blocks drawing it (client/prophunt.lua).
            pcall(Open77.weapons.holster, p.id)
            if s.role == "prop" then
                s.yaw = math.random(0, 7) * PH.rotateStep
                s.order, s.slot = {}, 1
                for slot, at in ipairs(G.shuffled(#ph.pool)) do s.order[slot] = ph.pool[at] end
                hide(p, t) -- even with no object yet: the tick keeps trying one
                if not wearFrom(match, p, 1, t) then s.retryAt = t + PH.retryMs end
                local every = map.autoWhistleSeconds or 0
                -- Apart, so a room does not whistle as one. The hide does not count.
                s.autoAt = every > 0 and ph.huntAt + (every + math.random() * 10) * 1000 or nil
                E.banner(p.id, "HIDE", "Pick an object and find a spot.", "info", 3000)
            else
                hold(match, p)
                E.banner(p.id, "HUNTER", "The props are hiding.", "danger", 3000)
            end
            tell(p)
        end
    end,

    tick = function(match, t)
        local ph = match.ph
        if ph.phase == "hide" and t >= ph.huntAt then startHunt(match, t) end
        if ph.phase == "hunt" and not ph.final and match.endsAt - t <= PH.finalSeconds * 1000 then enterFinal(match, t) end
        for _, p in ipairs(E.members(match)) do
            if p.ph.role == "prop" then tickProp(match, p, t) else tickHunter(match, p, t) end
        end
        if t >= ph.tellAt then
            ph.tellAt = t + PH.stateMs
            for _, p in pairs(match.players) do tell(p) end
        end
        if propsLeft(match) == 0 then E.finish(match, "decided") end
    end,

    -- Only a hunter's hit that is no melee counts, while hunting. The hit itself is always
    -- refused: it is counted against the object, the real body keeps its health.
    damage = function(match, event, attacker, victim)
        local v = victim.ph
        if match.ph.phase ~= "hunt" or attacker.ph.role ~= "hunter" or not hiding(victim) then return false end
        if event.attackKind == "melee" then return false end
        local amount = tonumber(event.amount)
        if amount == nil or amount ~= amount or amount <= 0 then return false end
        v.hp, v.hitBy = math.max(0, v.hp - amount), attacker.id
        if v.hp <= 0 then v.foundFrom = attacker.id end
        return false
    end,

    -- A real death: the platform took the hide, the freeze and the attachment. A prop is out
    -- (it joins the hunters); a hunter simply comes back.
    killed = function(match, victim, killer)
        if not hiding(victim) then return end
        found(match, victim, E.now(), killer)
    end,

    left = function(_, p, how) G.release(p, how == "disconnect") end,

    hud = function(match, p, view)
        local ph, t = match.ph, E.now()
        if ph.phase == "over" then return end
        if match.phase == "running" and ph.phase == "hide" then
            view.timer = { remainingMs = math.max(0, ph.huntAt - t), label = "HIDE" }
        end
        if p.ph.role == "prop" and hiding(p) then
            if ph.phase == "countdown" then view.objective = "You are a prop" else propHud(match, p, view, t) end
        elseif ph.phase == "countdown" then
            view.objective = "You are a hunter"
        elseif match.phase == "running" then
            hunterHud(match, p, view, t)
        end
    end,

    -- The fight is over: every body comes back now, before the result card.
    results = function(match, reason)
        for _, p in pairs(match.players) do G.release(p) end
        local ph, t = match.ph, E.now()
        ph.phase = "over"
        local survivors = propsLeft(match)
        local winner = nil
        if reason ~= "abandoned" then winner = survivors > 0 and PROPS or HUNTERS end
        local ranking = {}
        for _, p in pairs(match.roster) do
            local s = p.ph
            local survived = hiding(p) and not p.left
            if survived then s.lastedMs = ph.huntedAt and t - ph.huntedAt or 0 end
            p.won = winner ~= nil and p.side == winner and not p.left
            p.score = p.kills + (survived and 1 or 0)
            p.placement = winner and (p.won and 1 or 2) or nil
            p.row = { outcome = winner and (p.won and "won" or "lost") or nil, timeMs = s.lastedMs }
            ranking[#ranking + 1] = p
        end
        table.sort(ranking, function(a, b)
            if (a.won == true) ~= (b.won == true) then return a.won == true end
            if a.score ~= b.score then return a.score > b.score end
            return a.id < b.id
        end)
        return {
            ranking = ranking, winnerSide = winner,
            sides = { { id = HUNTERS, label = "Hunters", score = ph.found }, { id = PROPS, label = "Props", score = survivors } },
            lines = {
                { label = "Winner", value = winner == PROPS and "Props" or (winner == HUNTERS and "Hunters" or "Nobody") },
                { label = "Found", value = ("%d of %d"):format(ph.found, ph.total) },
            },
            columns = { "placement", "kills", "timeMs", "score" },
        }
    end,
})
