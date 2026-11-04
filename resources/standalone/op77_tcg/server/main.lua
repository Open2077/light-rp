-- op77_tcg server: the authority. Collections, sealed products, Dust, pulls, shops, physical cards and trades.
-- Everything a player owns lives in data/tcg.db (SQLite, keyed by the durable player identifier); a pull is
-- rolled and written BEFORE it is shown, so a crash mid-opening never loses or duplicates a card.
local C, R = TcgConfig, TcgRules
local NET = "op77_tcg:"

local db
local ready = false
local profiles = {}   -- identifier -> { dust, dustPlus, sealed = { [product] = n }, owned = { [id] = n }, lastFree, starter }
local loading = {}    -- identifier -> true while its rows load
local sessions = {}   -- playerId -> { identifier, lastOpen, opening = { seq, cards, revealed, anchor } }
local population = {} -- edition id -> times pulled or printed on this server
local shops = {}      -- id -> { id, x, y, z, yaw, label, props = {} }
local placed = {}     -- prop id -> { owner = identifier, player, edition, expires }
local offers = {}     -- offer id -> { from, to, edition, expires }
local offerSeq, openSeq = 0, 0

local function log(fmt, ...) print(("[op77_tcg] " .. fmt):format(...)) end
-- The server sandbox has no `os` library: Open77.time.unix() is the wall clock, GetGameTimer() the monotonic one.
local function now() return GetGameTimer() end

-- The collector: the active character when a framework provides one (LightRP: one collection per character,
-- nobody before a character is loaded), the account otherwise.
local function framework(fn, ...)
    local res = C.framework
    if not res then return false end
    local args = table.pack(...)
    local ok, a, b = pcall(function() local e = exports[res]; return e[fn](e, table.unpack(args, 1, args.n)) end)
    if not ok then return false end
    return true, a, b
end

-- The same, asynchronously: anything that writes (the framework's inventory goes to its database) must not run as
-- a synchronous export (it would yield: export_yielded). Needs a thread. A framework that does not publish the
-- export (resource absent, older version) leaves the call "not made".
local function frameworkAsync(fn, ...)
    local res = C.framework
    if not res or type(Open77.exports) ~= "table" or type(Open77.exports.call) ~= "function" then return false end
    local ok, pending = pcall(Open77.exports.call, res, fn, ...)
    if not ok or not pending then return false end
    local a, b = pending:await()
    if a == nil and type(b) == "string" and b:find("^export_") then return false end
    return true, a, b
end

local function identifierOf(player)
    local called, id = framework("characterIdentity", player)
    if called then
        if type(id) ~= "table" or not id.identifier then return nil end
        return tostring(id.identifier) .. "#" .. tostring(id.characterKey or "default")
    end
    local account = Open77.players.identifier(player)
    return account and tostring(account) or nil
end

-- ---------------------------------------------------------------------------------------------
-- Persistence

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS tcg_profiles (
    identifier TEXT PRIMARY KEY, name TEXT, dust INTEGER NOT NULL DEFAULT 0, dust_plus INTEGER NOT NULL DEFAULT 0,
    last_free INTEGER NOT NULL DEFAULT 0, starter INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS tcg_sealed (
    identifier TEXT NOT NULL, product TEXT NOT NULL, count INTEGER NOT NULL DEFAULT 0, PRIMARY KEY (identifier, product));
CREATE TABLE IF NOT EXISTS tcg_cards (
    identifier TEXT NOT NULL, edition TEXT NOT NULL, count INTEGER NOT NULL DEFAULT 0, first_at INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (identifier, edition));
CREATE TABLE IF NOT EXISTS tcg_population (edition TEXT PRIMARY KEY, pulled INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS tcg_pulls (
    id INTEGER PRIMARY KEY AUTOINCREMENT, identifier TEXT NOT NULL, product TEXT NOT NULL, editions TEXT NOT NULL, at INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS tcg_shops (
    id INTEGER PRIMARY KEY AUTOINCREMENT, x REAL, y REAL, z REAL, yaw REAL, label TEXT, bucket INTEGER NOT NULL DEFAULT 0);
]]

local function exec(sql, params) return db.execute.await(sql, params or {}) end
local function query(sql, params) return db.query.await(sql, params or {}) end

local function unix() return math.floor(Open77.time.unix()) end

local function saveProfile(identifier, p)
    exec("INSERT INTO tcg_profiles (identifier, dust, dust_plus, last_free, starter, created_at) VALUES (?, ?, ?, ?, ?, ?) " ..
        "ON CONFLICT(identifier) DO UPDATE SET dust = excluded.dust, dust_plus = excluded.dust_plus, " ..
        "last_free = excluded.last_free, starter = excluded.starter",
        { identifier, p.dust, p.dustPlus, p.lastFree, p.starter and 1 or 0, unix() })
end

local function saveSealed(identifier, product, count)
    exec("INSERT INTO tcg_sealed (identifier, product, count) VALUES (?, ?, ?) " ..
        "ON CONFLICT(identifier, product) DO UPDATE SET count = excluded.count", { identifier, product, count })
end

local function saveCard(identifier, edition, count)
    exec("INSERT INTO tcg_cards (identifier, edition, count, first_at) VALUES (?, ?, ?, ?) " ..
        "ON CONFLICT(identifier, edition) DO UPDATE SET count = excluded.count", { identifier, edition, count, unix() })
end

local function bumpPopulation(edition, n)
    population[edition] = (population[edition] or 0) + n
    exec("INSERT INTO tcg_population (edition, pulled) VALUES (?, ?) " ..
        "ON CONFLICT(edition) DO UPDATE SET pulled = tcg_population.pulled + excluded.pulled", { edition, n })
end

-- A profile, loaded once per identifier (must run in a thread).
local function profile(identifier)
    while loading[identifier] do Wait(25) end
    if profiles[identifier] then return profiles[identifier] end
    loading[identifier] = true
    local p = { dust = 0, dustPlus = 0, sealed = {}, owned = {}, lastFree = 0, starter = false }
    local rows = query("SELECT dust, dust_plus, last_free, starter FROM tcg_profiles WHERE identifier = ?", { identifier })
    local fresh = not rows[1]
    if rows[1] then
        p.dust, p.dustPlus = tonumber(rows[1].dust) or 0, tonumber(rows[1].dust_plus) or 0
        p.lastFree, p.starter = tonumber(rows[1].last_free) or 0, tonumber(rows[1].starter) == 1
    end
    for _, r in ipairs(query("SELECT product, count FROM tcg_sealed WHERE identifier = ?", { identifier })) do
        p.sealed[r.product] = tonumber(r.count) or 0
    end
    for _, r in ipairs(query("SELECT edition, count FROM tcg_cards WHERE identifier = ? AND count > 0", { identifier })) do
        p.owned[r.edition] = tonumber(r.count) or 0
    end
    if fresh then saveProfile(identifier, p) end
    profiles[identifier] = p
    loading[identifier] = nil
    return p
end

-- ---------------------------------------------------------------------------------------------
-- State to the client: compact strings, so a 320-edition collection stays far under the net event
-- value cap of older runtimes (1024 values).

local function encodeCounts(map)
    local parts = {}
    for id, n in pairs(map) do if n > 0 then parts[#parts + 1] = id .. ":" .. n end end
    table.sort(parts)
    return table.concat(parts, ",")
end

local function shopList()
    local out = {}
    for _, s in pairs(shops) do out[#out + 1] = { id = s.id, x = s.x, y = s.y, z = s.z, yaw = s.yaw, label = s.label, bucket = s.bucket } end
    return out
end

local function freeReadyIn(p)
    if C.economy.resource then return -1 end
    local wait = (p.lastFree + math.floor(C.economy.freeEveryMs / 1000)) - unix()
    return wait > 0 and wait or 0
end

local sealedOf
local function sendState(player, identifier, extra)
    local p = profiles[identifier]
    if not p then return end
    local sealed, inInventory = sealedOf(player, identifier)
    local c = R.completion(p.owned)
    TriggerClientEvent(NET .. "state", player, {
        dust = p.dust, dustPlus = p.dustPlus, sealed = sealed, store = inInventory and "inventory" or "binder", owned = encodeCounts(p.owned),
        population = encodeCounts(population), editions = c.editions, totalEditions = c.totalEditions,
        cards = c.cards, totalCards = c.totalCards, freeIn = freeReadyIn(p), paid = C.economy.resource ~= nil,
        prices = C.economy.prices, shops = shopList(), extra = extra,
    })
end

local function notify(player, text, kind)
    TriggerClientEvent(NET .. "notice", player, { text = text, kind = kind or "info" })
end

local function session(player)
    local s = sessions[player]
    if s then return s end
    local identifier = identifierOf(player)
    if not identifier then return nil end
    s = { identifier = identifier, lastOpen = 0 }
    sessions[player] = s
    return s
end

-- ---------------------------------------------------------------------------------------------
-- Giving

local function addSealed(identifier, product, count)
    local p = profile(identifier)
    p.sealed[product] = math.max(0, (p.sealed[product] or 0) + count)
    saveSealed(identifier, product, p.sealed[product])
    return p.sealed[product]
end

-- Sealed product: in the framework's inventory when it keeps one (LightRP items: tcgSealed / tcgTakeSealed /
-- tcgGiveSealed), in tcg.db otherwise. Every caller goes through these three.
function sealedOf(player, identifier)
    local called, counts = framework("tcgSealed", player)
    if called and type(counts) == "table" then return counts, true end
    return profile(identifier).sealed, false
end

local function takeSealed(player, identifier, product, n)
    local called, ok = frameworkAsync("tcgTakeSealed", player, product, n)
    if called then return ok == true end
    local p = profile(identifier)
    if (p.sealed[product] or 0) < n then return false end
    addSealed(identifier, product, -n)
    return true
end

local function giveSealed(player, identifier, product, n)
    local called, ok, why = frameworkAsync("tcgGiveSealed", player, product, n)
    if called then return ok == true, why end
    addSealed(identifier, product, n)
    return true
end

local function addCard(identifier, edition, count)
    local p = profile(identifier)
    p.owned[edition] = math.max(0, (p.owned[edition] or 0) + count)
    saveCard(identifier, edition, p.owned[edition])
    return p.owned[edition]
end

local function playerOf(identifier)
    for player, s in pairs(sessions) do if s.identifier == identifier then return player end end
end

-- ---------------------------------------------------------------------------------------------
-- Positions

local function positionOf(player)
    local p = Open77.players.position(player)
    if type(p) ~= "table" or not p.x then return nil end
    return p
end

local function dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function witnesses(anchor, bucket, radius)
    local out = {}
    local list = Open77.players.nearby({ x = anchor.x, y = anchor.y, z = anchor.z }, radius, { bucket = bucket }) or {}
    for _, entry in ipairs(list) do out[#out + 1] = entry.playerId or entry.id or entry end
    return out
end

local function nearShop(player, radius)
    local p = positionOf(player)
    if not p then return nil end
    for _, s in pairs(shops) do
        if (s.bucket or 0) == (p.bucket or 0) and dist(p, s) <= (radius or C.shopRadius) then return s end
    end
end

-- ---------------------------------------------------------------------------------------------
-- Opening a pack. The pull is rolled, written, then played: the opener's page reveals the cards one by
-- one and every client nearby deals the same physical cards on the surface in front of the opener.

local function sanitizeAnchor(a)
    if type(a) ~= "table" then return nil end
    local x, y, z, yaw = tonumber(a.x), tonumber(a.y), tonumber(a.z), tonumber(a.yaw)
    if not (x and y and z and yaw) then return nil end
    local surface = tonumber(a.surface)
    return { x = x, y = y, z = z, yaw = yaw % 360, surface = surface }
end

local function openPack(player, product, anchor)
    local s = session(player)
    if not s then return end
    local def = C.products[product]
    if not def or def.kind ~= "booster" then return notify(player, "Unknown product.", "error") end
    local t = now()
    if s.opening and not s.opening.done then return notify(player, "Finish the pack in your hands first.", "error") end
    if t - s.lastOpen < C.opening.cooldownMs then return end
    local here = positionOf(player)
    anchor = sanitizeAnchor(anchor)
    if not here or not anchor then return notify(player, "You need both hands free and a place to stand.", "error") end
    if dist(here, anchor) > C.opening.maxAnchorGap then return end
    if anchor.surface and (anchor.surface > anchor.z + 2.2 or anchor.surface < anchor.z - 0.2) then anchor.surface = nil end
    local p = profile(s.identifier)
    if not takeSealed(player, s.identifier, product, 1) then return notify(player, "You have no sealed " .. def.label .. " pack.", "error") end

    local cards, why = R.roll(C.pack, math.random, function(id) return p.owned[id] end)
    if not cards then
        giveSealed(player, s.identifier, product, 1)
        return notify(player, "This set is incomplete on the server (" .. tostring(why) .. ").", "error")
    end
    -- Written before anything is shown.
    local ids, fresh = {}, {}
    for i, e in ipairs(cards) do
        ids[i] = e.id
        fresh[i] = (p.owned[e.id] or 0) == 0 and 1 or 0
        addCard(s.identifier, e.id, 1)
        bumpPopulation(e.id, 1)
    end
    exec("INSERT INTO tcg_pulls (identifier, product, editions, at) VALUES (?, ?, ?, ?)",
        { s.identifier, product, table.concat(ids, ","), unix() })
    openSeq = openSeq + 1
    s.lastOpen = t
    s.opening = { seq = openSeq, product = product, cards = ids, revealed = 0, anchor = anchor, bucket = here.bucket or 0,
                  started = t, done = false }
    local name = Open77.players.name(player) or ("Player " .. player)
    local payload = { seq = openSeq, opener = player, name = name, product = product, cards = table.concat(ids, ","),
                      fresh = table.concat(fresh, ""), anchor = anchor }
    for _, w in ipairs(witnesses(anchor, here.bucket or 0, C.opening.nearRadius)) do
        TriggerClientEvent(NET .. "opening", w, payload)
    end
    local premium = cards[#cards]
    log("%s opened %s (seq %d, %s) -> premium %s (%s, %s)", name, product, openSeq, anchor.surface and "on a table" or "in hand",
        premium.name, premium.rarity, premium.finish)
    sendState(player, s.identifier)

    -- An opener who walks away from the page still finishes the pack for the others.
    local seq = openSeq
    CreateThread(function()
        Wait(90000)
        local o = sessions[player] and sessions[player].opening
        if o and o.seq == seq and not o.done then
            o.done = true
            for _, w in ipairs(witnesses(o.anchor, o.bucket, C.opening.nearRadius)) do
                TriggerClientEvent(NET .. "reveal", w, { seq = seq, opener = player, index = #o.cards, finished = true })
            end
        end
    end)
end

-- The opener's page reports its progress; every witness deals the same card at the same moment.
local function reveal(player, data)
    local s = sessions[player]
    local o = s and s.opening
    if not o or o.done or type(data) ~= "table" or tonumber(data.seq) ~= o.seq then return end
    local index = math.floor(tonumber(data.index) or -1)
    local stage = data.stage == "tear" and "tear" or "card"
    if stage == "card" and (index < 1 or index > #o.cards or index <= o.revealed) then return end
    if stage == "card" then o.revealed = index end
    local finished = stage == "card" and index == #o.cards
    if finished then o.done = true end
    for _, w in ipairs(witnesses(o.anchor, o.bucket, C.opening.nearRadius)) do
        TriggerClientEvent(NET .. "reveal", w, { seq = o.seq, opener = player, stage = stage, index = index, finished = finished })
    end
end

-- ---------------------------------------------------------------------------------------------
-- Dust: recycling duplicates, printing editions

local function recycle(player, edition, count)
    local s = session(player)
    local e = R.edition(edition)
    count = math.floor(tonumber(count) or 0)
    if not s or not e or count < 1 then return end
    local p = profile(s.identifier)
    local have = p.owned[edition] or 0
    if count > have - 1 then return notify(player, "You only recycle duplicates: one copy always stays in the binder.", "error") end
    if C.recycleAtShop ~= false and not nearShop(player) then return notify(player, "The recycler is at a TCG shop.", "error") end
    local dust, plus = R.recycleValue(e, count, C.dust)
    addCard(s.identifier, edition, -count)
    p.dust, p.dustPlus = p.dust + dust, p.dustPlus + plus
    saveProfile(s.identifier, p)
    notify(player, ("Recycled %d x %s: +%d Dust%s"):format(count, e.name, dust, plus > 0 and (", +" .. plus .. " Dust+") or ""), "dust")
    sendState(player, s.identifier, { recycled = { id = edition, count = count, dust = dust, dustPlus = plus } })
end

local function print_(player, edition)
    local s = session(player)
    local e = R.edition(edition)
    if not s or not e then return end
    if not nearShop(player) then return notify(player, "The card printer is at a TCG shop.", "error") end
    local p = profile(s.identifier)
    local cost = R.printCost(e, C.dust)
    if p.dust < cost.dust or p.dustPlus < cost.dustPlus then
        return notify(player, ("Not enough Dust: %s needs %d Dust%s."):format(e.name, cost.dust,
            cost.dustPlus > 0 and (" and " .. cost.dustPlus .. " Dust+") or ""), "error")
    end
    p.dust, p.dustPlus = p.dust - cost.dust, p.dustPlus - cost.dustPlus
    saveProfile(s.identifier, p)
    addCard(s.identifier, edition, 1)
    bumpPopulation(edition, 1)
    log("%s printed %s (%s)", Open77.players.name(player) or player, e.name, e.rarity)
    local shop = nearShop(player)
    for _, w in ipairs(witnesses(shop, shop.bucket or 0, 25.0)) do
        TriggerClientEvent(NET .. "printed", w, { shop = shop.id, edition = edition, player = player })
    end
    sendState(player, s.identifier, { printed = edition })
end

-- ---------------------------------------------------------------------------------------------
-- Shops: buying sealed product

local function charge(player, amount, reason)
    local res, fn = C.economy.resource, C.economy.charge
    if not res or not fn then return true end
    local ok, paid = pcall(function() return exports[res][fn](player, amount, reason) end)
    return ok and paid == true
end

local function buy(player, product)
    local s = session(player)
    local def = C.products[product]
    if not s or not def then return end
    if not nearShop(player) then return notify(player, "Buy sealed product at a TCG shop.", "error") end
    -- A framework that keeps sealed product in its inventory sells it too (LightRP: the vendor at the counter).
    if select(2, sealedOf(player, s.identifier)) then return notify(player, "Buy boosters and displays from the vendor at the counter.", "error") end
    local p = profile(s.identifier)
    if not C.economy.resource then
        if def.kind ~= "booster" then return notify(player, "This shop gives one booster at a time.", "error") end
        local wait = freeReadyIn(p)
        if wait > 0 then return notify(player, ("Next free pack in %d min."):format(math.ceil(wait / 60)), "error") end
        p.lastFree = unix()
        saveProfile(s.identifier, p)
    else
        local price = C.economy.prices[product] or 0
        if not charge(player, price, "Cyberpunk TCG - " .. def.label) then return notify(player, "Payment refused.", "error") end
    end
    giveSealed(player, s.identifier, product, 1)
    notify(player, ("You got a sealed %s."):format(def.label), "loot")
    sendState(player, s.identifier, { bought = product })
end

-- A display box opens into its boosters.
local function unbox(player, product)
    local s = session(player)
    local def = C.products[product]
    if not s or not def or def.kind ~= "box" then return end
    if not takeSealed(player, s.identifier, product, 1) then
        notify(player, "You have no sealed " .. def.label .. ".", "error")
        return sendState(player, s.identifier, { unboxFailed = product })
    end
    local given, why = giveSealed(player, s.identifier, def.contains, def.count)
    if not given then
        giveSealed(player, s.identifier, product, 1)
        notify(player, why or "There is no room for the packs.", "error")
        return sendState(player, s.identifier, { unboxFailed = product })
    end
    notify(player, ("You cut the shrink-wrap: %d %s packs."):format(def.count, C.products[def.contains].label), "loot")
    sendState(player, s.identifier, { unboxed = product })
end

-- ---------------------------------------------------------------------------------------------
-- Physical cards: showing one in hand, placing one on a surface

local shown = {}  -- player -> prop id

local function cardProp(edition, position, yaw)
    local e = R.edition(edition)
    return Open77.props.create({ model = e.entity, kind = "prop", position = position, yaw = yaw or 0,
        scale = C.scale.card, collision = false, physics = "none" })
end

local function show(player, edition)
    local s = session(player)
    local e = R.edition(edition)
    if not s or not e or (profile(s.identifier).owned[edition] or 0) <= 0 then return end
    if shown[player] then pcall(Open77.props.remove, shown[player]); shown[player] = nil end
    local here = positionOf(player)
    if not here then return end
    local prop, why = cardProp(edition, { x = here.x, y = here.y, z = here.z + 1.2 }, 0)
    if not prop then return log("show: prop refused (%s)", tostring(why)) end
    local ok, err = Open77.props.attach(prop, { parentType = "player", parentId = player, bone = "RightHand",
        offset = { x = 0.0, y = 0.07, z = 0.02 }, rotation = { x = 75.0, y = 0.0, z = 180.0 } })
    if not ok then log("show: attach refused (%s)", tostring(err)) end
    shown[player] = prop
    local name = Open77.players.name(player) or ("Player " .. player)
    for _, w in ipairs(witnesses(here, here.bucket or 0, C.show.radius)) do
        TriggerClientEvent(NET .. "shown", w, { player = player, name = name, edition = edition, prop = prop, ms = C.show.durationMs,
            position = { x = here.x, y = here.y, z = here.z } })
    end
    local held = prop
    SetTimeout(C.show.durationMs, function()
        if shown[player] == held then pcall(Open77.props.remove, held); shown[player] = nil end
    end)
end

local function place(player, edition, position, yaw)
    local s = session(player)
    local e = R.edition(edition)
    if not s or not e or type(position) ~= "table" then return end
    local p = profile(s.identifier)
    if (p.owned[edition] or 0) <= 0 then return end
    local here = positionOf(player)
    local at = { x = tonumber(position.x), y = tonumber(position.y), z = tonumber(position.z) }
    if not here or not (at.x and at.y and at.z) or dist(here, at) > C.place.maxDistance then return end
    local mine = 0
    for _, info in pairs(placed) do if info.owner == s.identifier then mine = mine + 1 end end
    if mine >= C.place.maxPerPlayer then return notify(player, "You already have " .. mine .. " cards out on display.", "error") end
    local prop, why = cardProp(edition, at, tonumber(yaw) or 0)
    if not prop then return log("place: prop refused (%s)", tostring(why)) end
    -- The card leaves the binder while it lies on the table.
    addCard(s.identifier, edition, -1)
    placed[prop] = { owner = s.identifier, player = player, edition = edition, expires = now() + C.place.lifetimeMs }
    TriggerClientEvent(NET .. "placed", -1, { prop = prop, edition = edition, owner = player, position = at })
    sendState(player, s.identifier)
end

local function pickup(player, prop)
    local info = placed[prop]
    local s = session(player)
    if not info or not s then return end
    local snap = Open77.props.get(prop)
    local here = positionOf(player)
    if snap and here and snap.position and dist(here, snap.position) > C.place.maxDistance + 1 then return end
    if info.owner ~= s.identifier then return notify(player, "That card belongs to someone else.", "error") end
    pcall(Open77.props.remove, prop)
    placed[prop] = nil
    addCard(s.identifier, info.edition, 1)
    TriggerClientEvent(NET .. "pickedUp", -1, { prop = prop })
    sendState(player, s.identifier)
end

-- ---------------------------------------------------------------------------------------------
-- Trades: an offer to a player standing next to you, accepted or declined on their side.

local function offer(player, target, edition)
    local s, t = session(player), tonumber(target)
    local e = R.edition(edition)
    if not s or not t or t == player or not e then return end
    local a, b = positionOf(player), positionOf(t)
    if not a or not b or (a.bucket or 0) ~= (b.bucket or 0) or dist(a, b) > C.trade.maxDistance then
        return notify(player, "Stand next to the collector you want to give a card to.", "error")
    end
    if (profile(s.identifier).owned[edition] or 0) <= 0 then return end
    offerSeq = offerSeq + 1
    offers[offerSeq] = { from = player, to = t, edition = edition, expires = now() + C.trade.offerMs }
    local name = Open77.players.name(player) or ("Player " .. player)
    TriggerClientEvent(NET .. "offer", t, { id = offerSeq, from = player, name = name, edition = edition })
    notify(player, ("Offer sent: %s."):format(e.name), "info")
end

local function answer(player, id, accept)
    local o = offers[tonumber(id) or -1]
    if not o or o.to ~= player then return end
    offers[tonumber(id)] = nil
    local from, to = session(o.from), session(player)
    if not from or not to then return end
    if not accept or now() > o.expires then
        return notify(o.from, "Your offer was declined.", "info")
    end
    local a, b = positionOf(o.from), positionOf(player)
    if not a or not b or dist(a, b) > C.trade.maxDistance + 2 then return notify(player, "They walked away.", "error") end
    if (profile(from.identifier).owned[o.edition] or 0) <= 0 then return notify(player, "They no longer have that card.", "error") end
    addCard(from.identifier, o.edition, -1)
    addCard(to.identifier, o.edition, 1)
    local e = R.edition(o.edition)
    notify(o.from, ("You gave %s."):format(e.name), "info")
    notify(player, ("You received %s."):format(e.name), "loot")
    for _, w in ipairs(witnesses(a, a.bucket or 0, 12.0)) do
        TriggerClientEvent(NET .. "handed", w, { from = o.from, to = player, edition = o.edition })
    end
    sendState(o.from, from.identifier)
    sendState(player, to.identifier)
end

-- ---------------------------------------------------------------------------------------------
-- Shops in the world: a counter with the card printer, the recycler, the booster display and the poster.

local SHOP_LAYOUT = {
    { model = "cyberpunktcg\\assets\\machines\\card_printer\\card_printer.ent", x = 0.0, y = 0.0, z = 0.0, yaw = 0.0, scale = 1.0 },
    { model = "cyberpunktcg\\assets\\machines\\card_recycler\\card_recycler.ent", x = 1.4, y = 0.0, z = 0.0, yaw = 0.0, scale = 1.0 },
    { model = "cyberpunktcg\\assets\\machines\\card_loader\\card_loader.ent", x = -1.3, y = 0.0, z = 0.0, yaw = 0.0, scale = 1.0 },
    { model = "cyberpunktcg\\assets\\shelves\\collection_01\\collection_shelf_01.ent", x = 0.0, y = 1.2, z = 0.0, yaw = 180.0, scale = 1.0 },
}

local function rotate(x, y, yaw)
    local r = math.rad(yaw)
    return x * math.cos(r) - y * math.sin(r), x * math.sin(r) + y * math.cos(r)
end

local function spawnShop(s)
    for _, id in ipairs(s.props or {}) do pcall(Open77.props.remove, id) end
    s.props = {}
    for _, part in ipairs(C.shopLayout or SHOP_LAYOUT) do
        local dx, dy = rotate(part.x, part.y, s.yaw)
        local id, why = Open77.props.create({ model = part.model, kind = "prop", position = { x = s.x + dx, y = s.y + dy, z = s.z + part.z },
            yaw = (s.yaw + part.yaw) % 360, scale = part.scale, bucket = s.bucket or 0, collision = true })
        if id then s.props[#s.props + 1] = id else log("shop %d: %s refused (%s)", s.id, part.model, tostring(why)) end
    end
end

local function broadcastShops()
    for player, s in pairs(sessions) do sendState(player, s.identifier) end
end

-- ---------------------------------------------------------------------------------------------
-- Events

local function welcome(player)
    CreateThread(function()
        while not ready do Wait(100) end
        local s = session(player)
        if not s then return end
        local p = profile(s.identifier)
        if not p.starter then
            local all = true
            for product, n in pairs(C.starter or {}) do
                if not giveSealed(player, s.identifier, product, n) then all = false end
            end
            if all then
                p.starter = true
                saveProfile(s.identifier, p)
                local where = select(2, sealedOf(player, s.identifier)) and "your inventory" or ("the binder (/" .. C.command .. ")")
                notify(player, "Welcome, collector: your starter packs are in " .. where .. ".", "loot")
            end
        end
        sendState(player, s.identifier)
    end)
end

RegisterNetEvent(NET .. "hello", function() welcome(source) end)

-- A framework's character: a new one is a new collector (its own binder); switching drops the old session.
if C.framework then
    local function rebind(player)
        player = tonumber(player)
        if not player then return end
        sessions[player] = nil
        welcome(player)
    end
    AddEventHandler(C.framework .. ":characterReady", rebind)
    AddEventHandler(C.framework .. ":characterChanged", rebind)
end

local function handler(name, fn)
    RegisterNetEvent(NET .. name, function(...)
        local player, args = source, { ... }
        CreateThread(function()
            while not ready do Wait(100) end
            local ok, err = pcall(fn, player, table.unpack(args))
            if not ok then log("%s failed: %s", name, tostring(err)) end
        end)
    end)
end

handler("state", function(player) local s = session(player); if s then profile(s.identifier); sendState(player, s.identifier) end end)
handler("open", openPack)
handler("reveal", reveal)
handler("recycle", recycle)
handler("print", print_)
handler("buy", buy)
handler("unbox", unbox)
handler("show", show)
handler("place", place)
handler("pickup", pickup)
handler("offer", offer)
handler("answer", answer)

AddEventHandler("playerDropped", function()
    local player = source
    if shown[player] then pcall(Open77.props.remove, shown[player]); shown[player] = nil end
    local s = sessions[player]
    sessions[player] = nil
    -- A profile stays cached; it is reloaded from the database only on a restart.
    if s then
        for id, o in pairs(offers) do if o.from == player or o.to == player then offers[id] = nil end end
    end
end)

-- ---------------------------------------------------------------------------------------------
-- Admin commands (ACL command.tcg.*)

local function reply(player, text)
    if player and player > 0 then notify(player, text, "info") else print("[op77_tcg] " .. text) end
end

RegisterCommand("tcg.give", function(source_, args)
    local target, product, count = tonumber(args[1]), args[2] or "wnc", math.floor(tonumber(args[3]) or 1)
    if not target or not C.products[product] or count < 1 or count > 500 then
        return reply(source_, "usage: /tcg.give <playerId> <wnc|beta|box> [count]")
    end
    CreateThread(function()
        local s = session(target)
        if not s then return reply(source_, "unknown player") end
        local left = addSealed(s.identifier, product, count)
        reply(source_, ("gave %d %s to %s (now %d)"):format(count, product, Open77.players.name(target) or target, left))
        notify(target, ("You received %d sealed %s."):format(count, C.products[product].label), "loot")
        sendState(target, s.identifier)
    end)
end, true)

RegisterCommand("tcg.card", function(source_, args)
    local target, edition = tonumber(args[1]), args[2]
    if not target or not R.edition(edition or "") then return reply(source_, "usage: /tcg.card <playerId> <editionId>") end
    CreateThread(function()
        local s = session(target)
        if not s then return reply(source_, "unknown player") end
        addCard(s.identifier, edition, 1)
        bumpPopulation(edition, 1)
        reply(source_, ("gave %s to %s"):format(R.edition(edition).name, Open77.players.name(target) or target))
        sendState(target, s.identifier)
    end)
end, true)

RegisterCommand("tcg.dust", function(source_, args)
    local target, amount = tonumber(args[1]), math.floor(tonumber(args[2]) or 0)
    if not target or amount == 0 then return reply(source_, "usage: /tcg.dust <playerId> <amount>") end
    CreateThread(function()
        local s = session(target)
        if not s then return reply(source_, "unknown player") end
        local p = profile(s.identifier)
        p.dust = math.max(0, p.dust + amount)
        saveProfile(s.identifier, p)
        reply(source_, ("%s now has %d Dust"):format(Open77.players.name(target) or target, p.dust))
        sendState(target, s.identifier)
    end)
end, true)

-- /tcg.demo <playerId> <open|table|binder|sealed|close|tear|reveal [n]>: drives a player's TCG from the console
-- (a showcase, or a test): open makes their client open a pack where they stand (table = on a surface 0.9 m up),
-- tear / reveal [n] play their current opening for everyone around without their page.
RegisterCommand("tcg.demo", function(source_, args)
    local target, action = tonumber(args[1]), args[2]
    if not target or not action then return reply(source_, "usage: /tcg.demo <playerId> <open|table|binder|sealed|close|tear|reveal [n]>") end
    CreateThread(function()
        if action == "tear" or action == "reveal" then
            local s = sessions[target]
            local o = s and s.opening
            if not o then return reply(source_, "no opening in progress") end
            if action == "tear" then return reveal(target, { seq = o.seq, stage = "tear" }) end
            local upto = math.min(#o.cards, math.floor(tonumber(args[3]) or #o.cards))
            for k = o.revealed + 1, upto do reveal(target, { seq = o.seq, stage = "card", index = k }); Wait(500) end
            return
        end
        TriggerClientEvent(NET .. "demo", target, { action = action })
    end)
end, true)

-- /tcg.shop here [label] | remove <id> | list
RegisterCommand("tcg.shop", function(source_, args)
    local verb = args[1] or "list"
    CreateThread(function()
        if verb == "here" or verb == "at" then
            -- here: at the admin typing it; at <playerId>: at that player (from the console).
            local player = verb == "at" and tonumber(args[2]) or tonumber(source_)
            if verb == "at" then table.remove(args, 2) end
            local p = player and player > 0 and positionOf(player)
            if not p then return reply(source_, "stand where the counter goes") end
            local yaw = tonumber(args[3]) or 0
            local label = args[2] or "TCG Shop"
            db.insert.await("INSERT INTO tcg_shops (x, y, z, yaw, label, bucket) VALUES (?, ?, ?, ?, ?, ?)",
                { p.x, p.y, p.z, yaw, label, p.bucket or 0 })
            local rows = query("SELECT max(id) AS id FROM tcg_shops")
            local id = tonumber(rows[1] and rows[1].id)
            shops[id] = { id = id, x = p.x, y = p.y, z = p.z, yaw = yaw, label = label, bucket = p.bucket or 0 }
            spawnShop(shops[id])
            broadcastShops()
            reply(source_, ("shop %d placed at %.1f %.1f %.1f yaw %.0f"):format(id, p.x, p.y, p.z, yaw))
        elseif verb == "remove" then
            local id = tonumber(args[2])
            local s = id and shops[id]
            if not s then return reply(source_, "unknown shop") end
            for _, prop in ipairs(s.props or {}) do pcall(Open77.props.remove, prop) end
            shops[id] = nil
            exec("DELETE FROM tcg_shops WHERE id = ?", { id })
            broadcastShops()
            reply(source_, "shop " .. id .. " removed")
        else
            for _, s in pairs(shops) do reply(source_, ("shop %d '%s' at %.1f %.1f %.1f"):format(s.id, s.label, s.x, s.y, s.z)) end
        end
    end)
end, true)

-- ---------------------------------------------------------------------------------------------
-- Exports for other resources (a gamemode's loot, rewards, shops).

exports("giveBooster", function(player, product, count)
    local s = session(tonumber(player))
    if not s or not C.products[product or "wnc"] then return false end
    CreateThread(function()
        giveSealed(player, s.identifier, product or "wnc", math.max(1, math.floor(tonumber(count) or 1)))
        sendState(player, s.identifier)
    end)
    return true
end)

-- A framework's inventory item was used: the player's client starts the real thing (a booster: the opening, with
-- the hands and the table it stands at; a display: the shrink-wrap). The product is taken from the store only
-- when the pack is actually opened / the wrap cut, so an item use that goes nowhere costs nothing.
exports("useSealed", function(player, product)
    player = tonumber(player)
    local def = C.products[product or ""]
    if not player or not def then return false, "unknown_product" end
    if not session(player) then return false, "no_collector" end
    TriggerClientEvent(NET .. "use", player, { product = product, kind = def.kind })
    return true
end)

exports("giveCard", function(player, edition)
    local s = session(tonumber(player))
    if not s or not R.edition(edition or "") then return false end
    CreateThread(function()
        addCard(s.identifier, edition, 1)
        bumpPopulation(edition, 1)
        sendState(player, s.identifier)
    end)
    return true
end)

exports("getCollection", function(player)
    local s = session(tonumber(player))
    local p = s and profiles[s.identifier]
    if not p then return nil end
    local c = R.completion(p.owned)
    return { dust = p.dust, dustPlus = p.dustPlus, sealed = p.sealed, editions = c.editions, cards = c.cards,
             totalEditions = c.totalEditions, totalCards = c.totalCards }
end)

-- ---------------------------------------------------------------------------------------------
-- What the other server scripts of op77_tcg (server/duel.lua) share with this one.

TcgServer = {
    log = log, now = now, unix = unix, query = query, exec = exec, notify = notify, session = session,
    profile = profile, positionOf = positionOf, dist = dist, witnesses = witnesses, playerOf = playerOf,
    isReady = function() return ready end,
    insert = function(sql, params) return db.insert.await(sql, params or {}) end,
    name = function(player) return Open77.players.name(player) or ("Player " .. tostring(player)) end,
    handler = handler,
}

-- ---------------------------------------------------------------------------------------------
-- Boot

CreateThread(function()
    math.randomseed(math.floor(unix() + GetGameTimer()))
    db = SQLite.open.await("tcg.db")
    db.execute.await(SCHEMA)
    for _, r in ipairs(query("SELECT edition, pulled FROM tcg_population")) do population[r.edition] = tonumber(r.pulled) or 0 end
    for _, r in ipairs(query("SELECT id, x, y, z, yaw, label, bucket FROM tcg_shops")) do
        local id = tonumber(r.id)
        shops[id] = { id = id, x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z), yaw = tonumber(r.yaw) or 0,
                      label = r.label or "TCG Shop", bucket = tonumber(r.bucket) or 0 }
    end
    for _, def in ipairs(C.shops or {}) do
        local id = "cfg" .. tostring(_)
        shops[id] = { id = id, x = def.x, y = def.y, z = def.z, yaw = def.yaw or 0, label = def.label or "TCG Shop", bucket = def.bucket or 0 }
    end
    for _, s in pairs(shops) do spawnShop(s) end
    ready = true
    local n = 0
    for _ in pairs(shops) do n = n + 1 end
    log("ready: %d editions, %d shops", #TcgCatalogue, n)
    -- Expired displays and offers.
    while true do
        Wait(15000)
        local t = now()
        for prop, info in pairs(placed) do
            if t > info.expires then
                pcall(Open77.props.remove, prop)
                placed[prop] = nil
                CreateThread(function()
                    addCard(info.owner, info.edition, 1)
                    local player = playerOf(info.owner)
                    if player then sendState(player, info.owner) end
                end)
            end
        end
        for id, o in pairs(offers) do if t > o.expires then offers[id] = nil end end
    end
end)
