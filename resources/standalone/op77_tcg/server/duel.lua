-- op77_tcg duels: decks, playmats, challenges and the 3D duel table (NEON DECK, shared/table.lua).
--
-- A collector builds decks in the binder (the official rules, shared/decks.lua, from the copies they own; the shop
-- lends the two starter decks), picks a playmat, and challenges a player nearby. On accept a free table slot is
-- reserved and set: both playmats, the deck stacks and the dice appear on the table for everyone around (replicated
-- props). Each player walks to their chair and sits down; the game is then set up by the rules (docs/RULES.md §7):
-- d20 for the first player, shuffled decks, the Legends face down (the first player's two left-most spent), the
-- dice in the fixer area, six cards drawn and one mulligan each, the first player deciding first.
local S = TcgServer
local C, T, D = TcgConfig, TcgTable, TcgDecks
local NET = "op77_tcg:"
local cfg = C.duel

local dready = false
local decks = {}        -- identifier -> { [id] = { id, name, legends = {}, cards = {} } }
local settings = {}     -- identifier -> { playmat, deck }
local challenges = {}   -- id -> { id, from, to, deck, expires }
local matches = {}      -- id -> match
local bySlot = {}       -- slot id -> match
local byPlayer = {}     -- player -> match
local challengeSeq, matchSeq = 0, 0

local cardOf = {}
for _, e in ipairs(TcgCatalogue) do cardOf[e.id] = e.card end

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS tcg_decks (
    id INTEGER PRIMARY KEY AUTOINCREMENT, identifier TEXT NOT NULL, name TEXT NOT NULL, legends TEXT NOT NULL,
    cards TEXT NOT NULL, updated_at INTEGER NOT NULL DEFAULT 0);
CREATE INDEX IF NOT EXISTS tcg_decks_owner ON tcg_decks (identifier);
CREATE TABLE IF NOT EXISTS tcg_settings (identifier TEXT PRIMARY KEY, playmat TEXT NOT NULL DEFAULT '', deck TEXT NOT NULL DEFAULT '');
CREATE TABLE IF NOT EXISTS tcg_matches (
    id INTEGER PRIMARY KEY AUTOINCREMENT, slot TEXT, a TEXT, b TEXT, deck_a TEXT, deck_b TEXT, winner TEXT, reason TEXT,
    started_at INTEGER, ended_at INTEGER);
]]

-- ---------------------------------------------------------------------------------------------
-- Decks and settings

-- Copies owned per base card (every finish of every edition counts).
local function ownedCounts(identifier)
    local out = {}
    for edition, n in pairs(S.profile(identifier).owned) do
        local card = cardOf[edition]
        if card and n > 0 then out[card] = (out[card] or 0) + n end
    end
    return out
end

local loadingDecks = {}
local function loadDecks(identifier)
    while loadingDecks[identifier] do Wait(25) end
    if decks[identifier] then return decks[identifier] end
    loadingDecks[identifier] = true
    local list = {}
    for _, r in ipairs(S.query("SELECT id, name, legends, cards FROM tcg_decks WHERE identifier = ? ORDER BY id", { identifier })) do
        local legends = {}
        for slug in tostring(r.legends or ""):gmatch("[%w_]+") do legends[#legends + 1] = slug end
        local id = tonumber(r.id)
        list[id] = { id = id, name = tostring(r.name or "Deck"), legends = legends, cards = D.parse(r.cards) }
    end
    decks[identifier] = list
    loadingDecks[identifier] = nil
    return list
end

local function settingsOf(identifier)
    if settings[identifier] then return settings[identifier] end
    local r = S.query("SELECT playmat, deck FROM tcg_settings WHERE identifier = ?", { identifier })[1]
    local s = { playmat = T.defaultPlaymat, deck = "" }
    if r then
        if T.playmatById[r.playmat or ""] then s.playmat = r.playmat end
        s.deck = tostring(r.deck or "")
    end
    settings[identifier] = s
    return s
end

local function saveSettings(identifier, s)
    S.exec("INSERT INTO tcg_settings (identifier, playmat, deck) VALUES (?, ?, ?) " ..
        "ON CONFLICT(identifier) DO UPDATE SET playmat = excluded.playmat, deck = excluded.deck", { identifier, s.playmat, s.deck or "" })
end

-- A deck key: "s:<starter id>" (lent by the shop) or the deck's id.
local function resolveDeck(identifier, key)
    key = tostring(key or "")
    local sid = key:match("^s:([%w_]+)$")
    if sid then
        local s = TcgStarters.byId[sid]
        if s and cfg.lendStarters ~= false then
            return { key = key, name = s.name, legends = s.legends, cards = s.cards, starter = true }
        end
        return nil
    end
    local d = loadDecks(identifier)[tonumber(key) or -1]
    if d then return { key = key, name = d.name, legends = d.legends, cards = d.cards } end
end

local function validateFor(identifier, deck)
    if deck.starter then return D.validate(deck, nil) end
    local owned = ownedCounts(identifier)
    return D.validate(deck, function(slug) return owned[slug] or 0 end)
end

local function firstErrors(errors, n)
    local out = {}
    for i = 1, math.min(#errors, n) do out[i] = errors[i] end
    return out
end

local function sendDecks(player, extra)
    local s = S.session(player)
    if not s then return end
    local owned = ownedCounts(s.identifier)
    local own = function(slug) return owned[slug] or 0 end
    local list = {}
    for id, d in pairs(loadDecks(s.identifier)) do
        local ok, errors, info = D.validate(d, own)
        list[#list + 1] = { key = tostring(id), name = d.name, legends = table.concat(d.legends, ","), cards = D.encode(d.cards),
            ok = ok, errors = firstErrors(errors, 4), count = info.count }
    end
    table.sort(list, function(a, b) return tonumber(a.key) < tonumber(b.key) end)
    local starters = {}
    if cfg.lendStarters ~= false then
        for _, st in ipairs(TcgStarters) do
            starters[#starters + 1] = { key = "s:" .. st.id, name = st.name, subtitle = st.subtitle, legends = table.concat(st.legends, ","),
                cards = D.encode(st.cards), ok = true, count = 40, starter = true }
        end
    end
    local set = settingsOf(s.identifier)
    TriggerClientEvent(NET .. "decks", player, { decks = list, starters = starters, playmat = set.playmat, selected = set.deck,
        max = D.maxDecks, extra = extra })
end

local function cleanName(text)
    local name = tostring(text or ""):gsub("[%c<>]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = "New deck" end
    -- Cut on a character boundary (names are UTF-8).
    local out, n = {}, 0
    for ch in name:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        n = n + 1
        if n > D.nameMax then break end
        out[#out + 1] = ch
    end
    return table.concat(out)
end

local function saveDeck(player, d)
    local s = S.session(player)
    if not s or type(d) ~= "table" then return end
    local legends = {}
    for slug in tostring(d.legends or ""):gmatch("[%w_]+") do
        if #legends < D.legends and TcgCards[slug] then legends[#legends + 1] = slug end
    end
    local cards, total = {}, 0
    for slug, n in pairs(D.parse(d.cards)) do
        if TcgCards[slug] and n > 0 then
            n = math.min(n, 9)
            cards[slug] = n
            total = total + n
        end
    end
    if total > 99 then return S.notify(player, "That deck is far too big.", "error") end
    local name = cleanName(d.name)
    local list = loadDecks(s.identifier)
    local id = tonumber(d.key)
    local t = S.unix()
    if id and list[id] then
        S.exec("UPDATE tcg_decks SET name = ?, legends = ?, cards = ?, updated_at = ? WHERE id = ? AND identifier = ?",
            { name, table.concat(legends, ","), D.encode(cards), t, id, s.identifier })
    else
        local n = 0
        for _ in pairs(list) do n = n + 1 end
        if n >= D.maxDecks then return S.notify(player, ("Your deck box holds %d decks: delete one first."):format(D.maxDecks), "error") end
        S.insert("INSERT INTO tcg_decks (identifier, name, legends, cards, updated_at) VALUES (?, ?, ?, ?, ?)",
            { s.identifier, name, table.concat(legends, ","), D.encode(cards), t })
        local r = S.query("SELECT id FROM tcg_decks WHERE identifier = ? ORDER BY id DESC LIMIT 1", { s.identifier })[1]
        id = tonumber(r and r.id)
        if not id then return S.notify(player, "The deck could not be saved.", "error") end
    end
    list[id] = { id = id, name = name, legends = legends, cards = cards }
    local ok = validateFor(s.identifier, list[id])
    S.notify(player, ok and ("Deck saved: %s."):format(name) or ("Draft saved: %s (not legal yet)."):format(name), ok and "info" or "error")
    sendDecks(player, { saved = tostring(id) })
end

local function deleteDeck(player, key)
    local s = S.session(player)
    local id = tonumber(key)
    if not s or not id then return end
    local list = loadDecks(s.identifier)
    if not list[id] then return end
    S.exec("DELETE FROM tcg_decks WHERE id = ? AND identifier = ?", { id, s.identifier })
    list[id] = nil
    local set = settingsOf(s.identifier)
    if set.deck == tostring(id) then set.deck = ""; saveSettings(s.identifier, set) end
    sendDecks(player, { deleted = tostring(id) })
end

local function setPlaymat(player, id)
    local s = S.session(player)
    if not s or not T.playmatById[tostring(id)] then return end
    local set = settingsOf(s.identifier)
    set.playmat = tostring(id)
    saveSettings(s.identifier, set)
    sendDecks(player, { playmat = set.playmat })
end

local function selectDeck(player, key)
    local s = S.session(player)
    if not s or not resolveDeck(s.identifier, key) then return end
    local set = settingsOf(s.identifier)
    set.deck = tostring(key)
    saveSettings(s.identifier, set)
    sendDecks(player, { selected = set.deck })
end

-- ---------------------------------------------------------------------------------------------
-- The table: replicated props

local function propOf(m, model, at, yaw)
    local id, why = Open77.props.create({ model = model, kind = "prop", position = { x = at.x, y = at.y, z = at.z },
        yaw = yaw % 360, scale = 1.0, bucket = m.slot.bucket or 0, collision = false, physics = "none" })
    if not id then S.log("duel %d: %s refused (%s)", m.id, model, tostring(why)) end
    return id
end

local function removeProp(id) if id then pcall(Open77.props.remove, id) end end

-- The deck stack sinks into the table as it thins (one mesh, 45 cards tall): what shows is the cards left.
local function deckPose(seat)
    local n = #seat.library
    local at = T.onMat(seat.pose, T.zones.deck[1], T.zones.deck[2])
    at.z = at.z - T.mesh.deckHeight * (1 - math.min(1, n / 45))
    return at
end

local function placeDeck(m, seat)
    if #seat.library == 0 then removeProp(seat.props.deck); seat.props.deck = nil; return end
    local at = deckPose(seat)
    if seat.props.deck then
        pcall(Open77.props.setTransform, seat.props.deck, { position = at, yaw = seat.pose.yaw })
    else
        seat.props.deck = propOf(m, T.mesh.deck, at, seat.pose.yaw)
    end
end

local function placeLegends(m, seat)
    for i, l in ipairs(seat.legends) do
        local z = T.zones.legends[i]
        local at = T.onMat(seat.pose, z[1], z[2])
        local yaw = seat.pose.yaw + (l.spent and 90 or 0)
        if seat.props.legends[i] then
            pcall(Open77.props.setTransform, seat.props.legends[i], { position = at, yaw = yaw })
        else
            seat.props.legends[i] = propOf(m, T.mesh.cardback, at, yaw)
        end
    end
end

-- The table is set as soon as a match is made: both mats, both decks, both dice sets in the fixer areas.
local function setTable(m)
    for _, seat in ipairs(m.seats) do
        local mat = T.playmatById[seat.playmat] or T.playmatById[T.defaultPlaymat]
        seat.props.mat = propOf(m, mat.mesh, seat.pose.mat, seat.pose.yaw)
        placeDeck(m, seat)
        local dice = T.dice[seat.pose.dice] or T.dice.netrunner
        for _, kind in ipairs(T.dieKinds) do
            local z = T.zones.fixer[kind]
            seat.props.dice[kind] = propOf(m, dice[kind], T.onMat(seat.pose, z[1], z[2]), seat.pose.yaw + math.random(0, 359))
        end
    end
end

local function clearTable(m)
    for _, seat in ipairs(m.seats) do
        removeProp(seat.props.mat)
        removeProp(seat.props.deck)
        for _, id in pairs(seat.props.dice) do removeProp(id) end
        for _, id in pairs(seat.props.legends) do removeProp(id) end
        seat.props = { dice = {}, legends = {} }
    end
end

-- ---------------------------------------------------------------------------------------------
-- Matches

local function other(m, seat) return m.seats[seat.index == 1 and 2 or 1] end

local function seatOf(m, player)
    for _, seat in ipairs(m.seats) do if seat.player == player then return seat end end
end

local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(1, i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

local function expand(cards)
    local out = {}
    for slug, n in pairs(cards) do for _ = 1, n do out[#out + 1] = slug end end
    table.sort(out)  -- a deterministic order before the shuffle
    return out
end

local function draw(seat, n)
    for _ = 1, n do
        local card = table.remove(seat.library)
        if not card then return false end
        seat.hand[#seat.hand + 1] = card
    end
    return true
end

local function say(m, fmt, ...)
    local line = fmt:format(...)
    m.log[#m.log + 1] = line
    if #m.log > 12 then table.remove(m.log, 1) end
end

local function remaining(m)
    if not m.deadline then return nil end
    return math.max(0, m.deadline - S.now())
end

-- What a player sees: everything public, and their own hand.
local function view(m, seat)
    local seats = {}
    for i, s in ipairs(m.seats) do
        local legends = {}
        for k, l in ipairs(s.legends) do legends[k] = { spent = l.spent, card = l.faceUp and l.slug or nil } end
        seats[i] = { name = s.name, side = s.pose.side, playmat = s.playmat, seated = s.seated, house = s.house, deck = s.deck.name,
            library = #s.library, handCount = #s.hand, legends = legends, mulligan = s.mulligan, roll = s.roll }
    end
    return { id = m.id, slot = m.slot.id, label = m.slot.label, you = seat.index, phase = m.phase, deadline = remaining(m),
        decider = m.decider, first = m.first, turn = m.turn, active = m.active, seats = seats,
        hand = table.concat(seat.hand, ","), log = m.log,
        chair = seat.pose.chair, stand = seat.pose.stand, mat = seat.pose.mat, yaw = seat.pose.yaw,
        rivalMat = other(m, seat).pose.mat }
end

local function broadcast(m)
    for _, seat in ipairs(m.seats) do
        if seat.player then TriggerClientEvent(NET .. "match", seat.player, view(m, seat)) end
    end
end

local function standUp(seat)
    if seat.player and seat.playback then pcall(Open77.animations.stop, seat.player, seat.playback) end
    seat.playback = nil
end

local function endMatch(m, reason, winner)
    if m.over then return end
    m.over = true
    m.phase = "over"
    clearTable(m)
    bySlot[m.slot.id] = nil
    for _, seat in ipairs(m.seats) do
        standUp(seat)
        if seat.player then
            byPlayer[seat.player] = nil
            TriggerClientEvent(NET .. "match", seat.player, { id = m.id, ended = true, reason = reason,
                won = winner and winner.index == seat.index or false, winner = winner and winner.name or nil })
        end
    end
    matches[m.id] = nil
    S.exec("INSERT INTO tcg_matches (slot, a, b, deck_a, deck_b, winner, reason, started_at, ended_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        { m.slot.id, m.seats[1].identifier, m.seats[2].identifier, m.seats[1].deck.name, m.seats[2].deck.name,
          winner and winner.identifier or "", reason or "", m.startedAt, S.unix() })
    S.log("duel %d at %s ended: %s%s", m.id, m.slot.id, tostring(reason), winner and (" - " .. winner.name .. " wins") or "")
end

local function freeSlot()
    for _, slot in ipairs(T.slots) do if not bySlot[slot.id] then return slot end end
end

local function newSeat(index, pose, who)
    return { index = index, pose = pose, player = who.player, identifier = who.identifier, name = who.name, house = who.house,
        deck = who.deck, playmat = who.playmat, seated = false, library = {}, hand = {}, legends = {}, mulligan = nil,
        props = { dice = {}, legends = {} } }
end

local function createMatch(slot, a, b)
    matchSeq = matchSeq + 1
    local poses = T.seats(slot)
    local m = { id = matchSeq, slot = slot, phase = "seating", log = {}, startedAt = S.unix(), turn = 0 }
    m.seats = { newSeat(1, poses[1], a), newSeat(2, poses[2], b) }
    for _, seat in ipairs(m.seats) do
        -- The deck lies on the mat from the start, still in its sorted order: it is shuffled at the setup.
        seat.library = expand(seat.deck.cards)
        if seat.player then byPlayer[seat.player] = m end
        if seat.house then seat.seated = true end
    end
    matches[m.id] = m
    bySlot[slot.id] = m
    m.deadline = S.now() + cfg.seatMs
    -- Any other challenge of these two players is void.
    for id, ch in pairs(challenges) do
        if ch.from == a.player or ch.to == a.player or ch.from == b.player or ch.to == b.player then challenges[id] = nil end
    end
    setTable(m)
    say(m, "%s vs %s at %s.", a.name, b.name, slot.label)
    S.log("duel %d at %s: %s (%s) vs %s (%s)", m.id, slot.id, a.name, a.deck.name, b.name, b.deck.name)
    broadcast(m)
    return m
end

-- Setup [7.4-7.9]: d20 for the first player (ties rerolled), the higher roller chooses.
local function startSetup(m)
    m.phase = "choose"
    local ra, rb
    repeat ra, rb = math.random(1, 20), math.random(1, 20) until ra ~= rb
    m.seats[1].roll, m.seats[2].roll = ra, rb
    m.decider = ra > rb and 1 or 2
    say(m, "d20: %s rolls %d, %s rolls %d.", m.seats[1].name, ra, m.seats[2].name, rb)
    say(m, "%s chooses who goes first.", m.seats[m.decider].name)
    m.deadline = S.now() + cfg.chooseMs
    broadcast(m)
    if m.seats[m.decider].house then
        SetTimeout(2500, function() if matches[m.id] == m and m.phase == "choose" then m.choose(m.decider, true) end end)
    end
end

local function startMulligans(m)
    m.phase = "mulligan"
    m.decider = m.first
    m.deadline = S.now() + cfg.mulliganMs
    say(m, "%s decides: keep or mulligan.", m.seats[m.first].name)
    broadcast(m)
end

local function houseMulligan(m)
    local seat = m.seats[m.decider]
    if seat and seat.house then
        SetTimeout(1800, function() if matches[m.id] == m and m.phase == "mulligan" and m.decider == seat.index then m.mulligan(seat.index, false) end end)
    end
end

local function startGame(m)
    m.phase = "main"
    m.turn = 1
    m.active = m.first
    m.deadline = nil
    say(m, "The game begins: turn 1, %s.", m.seats[m.first].name)
    broadcast(m)
end

local function bindMatch(m)
    -- The d20 winner's choice: `goFirst` true = the decider goes first.
    function m.choose(index, goFirst)
        if m.phase ~= "choose" or index ~= m.decider then return end
        m.first = goFirst and m.decider or (m.decider == 1 and 2 or 1)
        say(m, "%s goes first.", m.seats[m.first].name)
        for _, seat in ipairs(m.seats) do
            shuffle(seat.library)
            local legends = shuffle({ table.unpack(seat.deck.legends) })
            seat.legends = {}
            for i, slug in ipairs(legends) do
                -- The first player's two left-most Legends start spent (they do not ready on their first turn).
                seat.legends[i] = { slug = slug, faceUp = false, spent = seat.index == m.first and i <= 2 }
            end
            draw(seat, 6)
            seat.mulligan = "deciding"
            placeLegends(m, seat)
            placeDeck(m, seat)
        end
        startMulligans(m)
        houseMulligan(m)
    end

    -- Keep, or shuffle the six back and draw six new ones (once). The first player decides first.
    function m.mulligan(index, again)
        if m.phase ~= "mulligan" or index ~= m.decider then return end
        local seat = m.seats[index]
        if again then
            for _, card in ipairs(seat.hand) do seat.library[#seat.library + 1] = card end
            seat.hand = {}
            shuffle(seat.library)
            draw(seat, 6)
            seat.mulligan = "mulligan"
            say(m, "%s mulligans.", seat.name)
        else
            seat.mulligan = "kept"
            say(m, "%s keeps.", seat.name)
        end
        placeDeck(m, seat)
        local nextSeat = other(m, seat)
        if index == m.first then
            m.decider = nextSeat.index
            m.deadline = S.now() + cfg.mulliganMs
            say(m, "%s decides: keep or mulligan.", nextSeat.name)
            broadcast(m)
            houseMulligan(m)
        else
            startGame(m)
        end
    end
end

-- ---------------------------------------------------------------------------------------------
-- Challenges

local function collector(player, deckKey)
    local s = S.session(player)
    if not s then return nil, "No collection on this character." end
    local deck = resolveDeck(s.identifier, deckKey)
    if not deck then return nil, "Pick a deck first (Decks tab)." end
    local ok, errors = validateFor(s.identifier, deck)
    if not ok then return nil, ("%s is not legal: %s"):format(deck.name, errors[1] or "check it in the Decks tab") end
    local set = settingsOf(s.identifier)
    return { player = player, identifier = s.identifier, name = S.name(player), deck = deck, playmat = set.playmat }
end

local function near(a, b, radius)
    local pa, pb = S.positionOf(a), S.positionOf(b)
    return pa and pb and (pa.bucket or 0) == (pb.bucket or 0) and S.dist(pa, pb) <= radius
end

local function sendNearby(player)
    local here = S.positionOf(player)
    if not here then return end
    local out = {}
    local list = Open77.players.nearby({ x = here.x, y = here.y, z = here.z }, cfg.challengeRadius, { bucket = here.bucket or 0 }) or {}
    for _, entry in ipairs(list) do
        local id = tonumber(type(entry) == "table" and (entry.playerId or entry.id) or entry)
        if id and id ~= player then
            out[#out + 1] = { id = id, name = S.name(id), busy = byPlayer[id] ~= nil }
        end
    end
    local free = 0
    for _, slot in ipairs(T.slots) do if not bySlot[slot.id] then free = free + 1 end end
    TriggerClientEvent(NET .. "nearby", player, { players = out, freeTables = free, tables = #T.slots })
end

local function challenge(player, target, deckKey)
    target = tonumber(target)
    if not target or target == player then return end
    if byPlayer[player] then return S.notify(player, "Finish your current duel first.", "error") end
    if byPlayer[target] then return S.notify(player, "They are already playing a duel.", "error") end
    if not near(player, target, cfg.challengeRadius) then return S.notify(player, "Stand near the player you want to challenge.", "error") end
    if not freeSlot() then return S.notify(player, "Both duel tables are taken. Try again in a moment.", "error") end
    for _, ch in pairs(challenges) do
        if ch.from == player and ch.to == target then return S.notify(player, "Your challenge is already waiting for an answer.", "info") end
    end
    local me, why = collector(player, deckKey)
    if not me then return S.notify(player, why, "error") end
    if not S.session(target) then return S.notify(player, "They have no collection yet.", "error") end
    challengeSeq = challengeSeq + 1
    local ch = { id = challengeSeq, from = player, to = target, deck = deckKey, expires = S.now() + cfg.challengeMs }
    challenges[ch.id] = ch
    TriggerClientEvent(NET .. "challenged", target, { id = ch.id, from = player, name = me.name, deck = me.deck.name,
        ms = cfg.challengeMs })
    TriggerClientEvent(NET .. "challengeSent", player, { id = ch.id, to = target, name = S.name(target), ms = cfg.challengeMs })
    S.notify(player, ("Challenge sent to %s."):format(S.name(target)), "info")
end

local function cancelChallenge(player, id)
    local ch = challenges[tonumber(id) or -1]
    if not ch or ch.from ~= player then return end
    challenges[ch.id] = nil
    TriggerClientEvent(NET .. "challengeClosed", ch.to, { id = ch.id, reason = "cancelled" })
end

local function answerChallenge(player, id, accept, deckKey)
    local ch = challenges[tonumber(id) or -1]
    if not ch or ch.to ~= player then return end
    challenges[ch.id] = nil
    TriggerClientEvent(NET .. "challengeClosed", ch.from, { id = ch.id, reason = accept and "accepted" or "declined" })
    if not accept then return S.notify(ch.from, ("%s declined your duel."):format(S.name(player)), "info") end
    if S.now() > ch.expires then return S.notify(player, "That challenge has expired.", "error") end
    if byPlayer[player] or byPlayer[ch.from] then return S.notify(player, "One of you is already in a duel.", "error") end
    if not near(player, ch.from, cfg.challengeRadius * 2) then return S.notify(player, "They walked away.", "error") end
    local a, whyA = collector(ch.from, ch.deck)
    if not a then
        S.notify(ch.from, whyA, "error")
        return S.notify(player, "Their deck is no longer legal.", "error")
    end
    local b, whyB = collector(player, deckKey)
    if not b then return S.notify(player, whyB, "error") end
    local slot = freeSlot()
    if not slot then
        S.notify(ch.from, "Both duel tables are taken.", "error")
        return S.notify(player, "Both duel tables are taken.", "error")
    end
    local m = createMatch(slot, a, b)
    bindMatch(m)
    for _, seat in ipairs(m.seats) do
        S.notify(seat.player, ("%s is set for you: sit down at your chair."):format(slot.label), "loot")
    end
end

-- ---------------------------------------------------------------------------------------------
-- Seating

local function trySit(seat)
    local c = seat.pose.chair
    local reasons = {}
    for _, option in ipairs(cfg.sit or {}) do
        local ok, animation, why = pcall(Open77.animations.playAt, seat.player, option.profile, { x = c.x, y = c.y, z = c.z },
            seat.pose.yaw, { loop = true, clip = option.clip, arrivalRadius = 1.5 })
        if ok and type(animation) == "table" then
            seat.playback = animation.playbackId
            return true, option.profile
        end
        reasons[#reasons + 1] = option.profile .. ": " .. tostring(ok and why or animation)
    end
    return false, table.concat(reasons, "; ")
end

local function sit(player)
    local m = byPlayer[player]
    local seat = m and seatOf(m, player)
    if not seat or m.over then return end
    local here = S.positionOf(player)
    if not here or S.dist(here, seat.pose.chair) > cfg.sitReach + 1.0 then return S.notify(player, "Walk to your chair first.", "error") end
    local ok, how = trySit(seat)
    if ok then
        S.log("duel %d: %s sits (%s)", m.id, seat.name, how)
    else
        -- No animation the runtime can play here: the player stands at their place and still plays.
        S.log("duel %d: %s could not sit (%s)", m.id, seat.name, how)
    end
    if not seat.seated then
        seat.seated = true
        say(m, "%s sits down.", seat.name)
    end
    if m.phase == "seating" and other(m, seat).seated then startSetup(m) else broadcast(m) end
end

local function leave(player, reason)
    local m = byPlayer[player]
    local seat = m and seatOf(m, player)
    if not seat then return end
    if m.phase == "seating" or m.phase == "choose" or m.phase == "mulligan" then
        endMatch(m, ("%s left the table before the game began."):format(seat.name), nil)
    else
        endMatch(m, ("%s %s."):format(seat.name, reason or "conceded"), other(m, seat))
    end
end

-- ---------------------------------------------------------------------------------------------
-- Events

local function on(name, fn)
    S.handler(name, function(...)
        while not dready do Wait(50) end
        return fn(...)
    end)
end

-- The deck box and the playmats are the binder's: seated at a duel table, they are put away.
local function atTable(player)
    local m = byPlayer[player]
    local seat = m and seatOf(m, player)
    return seat and seat.seated
end
local function offTable(fn)
    return function(player, ...)
        if atTable(player) then return S.notify(player, "Not at the duel table: decks are built before a duel.", "error") end
        return fn(player, ...)
    end
end

on("decks", function(player) sendDecks(player) end)
on("saveDeck", offTable(saveDeck))
on("deleteDeck", offTable(deleteDeck))
on("setPlaymat", offTable(setPlaymat))
on("selectDeck", offTable(selectDeck))
on("nearby", sendNearby)
on("challenge", challenge)
on("cancelChallenge", cancelChallenge)
on("answerChallenge", function(player, id, accept, deckKey) answerChallenge(player, id, accept == true, deckKey) end)
on("sit", sit)
on("leaveMatch", function(player) leave(player, "conceded") end)
on("match", function(player)
    local m = byPlayer[player]
    local seat = m and seatOf(m, player)
    if seat then TriggerClientEvent(NET .. "match", player, view(m, seat)) else TriggerClientEvent(NET .. "match", player, { none = true }) end
end)
on("choose", function(player, goFirst)
    local m = byPlayer[player]
    local seat = m and seatOf(m, player)
    if seat then m.choose(seat.index, goFirst ~= false) end
end)
on("mulligan", function(player, again)
    local m = byPlayer[player]
    local seat = m and seatOf(m, player)
    if seat then m.mulligan(seat.index, again == true) end
end)

local function dropped(player)
    for id, ch in pairs(challenges) do
        if ch.from == player or ch.to == player then
            challenges[id] = nil
            local peer = ch.from == player and ch.to or ch.from
            TriggerClientEvent(NET .. "challengeClosed", peer, { id = id, reason = "left" })
        end
    end
    if byPlayer[player] then leave(player, "left the game") end
end

AddEventHandler("playerDropped", function() local p = source; CreateThread(function() dropped(p) end) end)
if C.framework then
    -- Another character is another collector: their duel ends.
    local function switched(player) player = tonumber(player); if player then CreateThread(function() dropped(player) end) end end
    AddEventHandler(C.framework .. ":characterChanged", switched)
end

AddEventHandler("onResourceStop", function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, m in pairs(matches) do
        for _, seat in ipairs(m.seats) do standUp(seat) end
        clearTable(m)
    end
end)

-- A duel against the house (NEON DECK's own player, a starter deck): a showcase, a tutorial, a test.
local function houseDuel(target, starter)
    if byPlayer[target] then return nil, "already in a duel" end
    local s = S.session(target)
    if not s then return nil, "unknown player" end
    local set = settingsOf(s.identifier)
    local key = resolveDeck(s.identifier, set.deck) and set.deck or "s:embracing_power"
    local a, why = collector(target, key)
    if not a then a, why = collector(target, "s:embracing_power") end
    if not a then return nil, why end
    local houseDeck = TcgStarters.byId[starter or "the_heist"] or TcgStarters[2]
    local b = { player = nil, identifier = "house", name = "NEON DECK house", house = true, playmat = "arasaka",
        deck = { key = "s:" .. houseDeck.id, name = houseDeck.name, legends = houseDeck.legends, cards = houseDeck.cards, starter = true } }
    local slot = freeSlot()
    if not slot then return nil, "both tables are taken" end
    local m = createMatch(slot, a, b)
    bindMatch(m)
    S.notify(target, ("%s is set for you: sit down at your chair."):format(slot.label), "loot")
    return m
end

-- Exports for a gamemode (a tutorial, an NPC dealer): both run in a thread and answer at once.
exports("houseDuel", function(player, starter)
    player = tonumber(player)
    if not player then return false end
    CreateThread(function() while not dready do Wait(50) end houseDuel(player, starter) end)
    return true
end)
-- Seats a player in their duel as if they had pressed the sit key at their chair (they must stand near it).
exports("sitDown", function(player)
    player = tonumber(player)
    if not player or not byPlayer[player] then return false end
    CreateThread(function() sit(player) end)
    return true
end)

-- /tcg.duel demo <playerId> [starter] | end <slot> | list: a duel against the house (a test, a showcase).
RegisterCommand("tcg.duel", function(source_, args)
    local verb = args[1] or "list"
    local function reply(text)
        if source_ and source_ > 0 then S.notify(source_, text, "info") else print("[op77_tcg] " .. text) end
    end
    CreateThread(function()
        while not dready do Wait(50) end
        if verb == "demo" then
            local target = tonumber(args[2])
            if not target then return reply("usage: /tcg.duel demo <playerId> [embracing_power|the_heist]") end
            local m, why = houseDuel(target, args[3])
            if not m then return reply(tostring(why)) end
            reply(("duel %d at %s: %s vs the house"):format(m.id, m.slot.id, m.seats[1].name))
        elseif verb == "end" then
            local m = bySlot[args[2] or ""]
            if not m then return reply("no duel at that slot") end
            endMatch(m, "Ended by an admin.", nil)
            reply("ended")
        else
            for _, slot in ipairs(T.slots) do
                local m = bySlot[slot.id]
                reply(("%s: %s"):format(slot.id, m and (m.seats[1].name .. " vs " .. m.seats[2].name .. " (" .. m.phase .. ")") or "free"))
            end
        end
    end)
end, true)

-- ---------------------------------------------------------------------------------------------
-- Boot and timers

CreateThread(function()
    while not S.isReady() do Wait(100) end
    S.exec(SCHEMA)
    dready = true
    S.log("duels ready: %d tables, %d playmats", #T.slots, #T.playmats)
    while true do
        Wait(1000)
        local t = S.now()
        for id, ch in pairs(challenges) do
            if t > ch.expires then
                challenges[id] = nil
                TriggerClientEvent(NET .. "challengeClosed", ch.from, { id = id, reason = "expired" })
                TriggerClientEvent(NET .. "challengeClosed", ch.to, { id = id, reason = "expired" })
            end
        end
        for _, m in pairs(matches) do
            if m.deadline and t > m.deadline then
                if m.phase == "seating" then
                    endMatch(m, "Nobody sat down in time: the table is free again.", nil)
                elseif m.phase == "choose" then
                    m.choose(m.decider, true)
                elseif m.phase == "mulligan" then
                    m.mulligan(m.decider, false)
                end
            end
            -- A seated player who walked away from the table concedes after a short grace.
            if not m.over and m.phase ~= "seating" then
                for _, seat in ipairs(m.seats) do
                    if seat.player and not m.over then
                        local here = S.positionOf(seat.player)
                        local away = not here or S.dist(here, seat.pose.chair) > 6.0
                        seat.awaySince = away and (seat.awaySince or t) or nil
                        if seat.awaySince and t - seat.awaySince > 15000 then leave(seat.player, "walked away from the table") end
                    end
                end
            end
        end
    end
end)
