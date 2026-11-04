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
-- The table: replicated props, kept in step with the game by a diff (key -> prop). Everything a player can see on a
-- real table is there: both mats, the deck stacks, the dice in the fixer areas, the Gigs, the Legends (face down or
-- face up, spent sideways), the Units with their Gear tucked under them, the Eddies (face down), the top of the trash.

-- A base card's 3D card: its first edition (lowest tier, sleeved first), as the binder shows it.
local entityOf = {}
do
    local best = {}
    for _, e in ipairs(TcgCatalogue) do
        local score = e.tier * 10 + (e.finish == "sleeved" and 0 or 1)
        if not best[e.card] or score < best[e.card].score then best[e.card] = { score = score, entity = e.entity } end
    end
    for card, b in pairs(best) do entityOf[card] = b.entity end
end

local function removeProp(id) if id then pcall(Open77.props.remove, id) end end

local CARD_SCALE = C.scale.card
local function desired(m)
    local out = {}
    local function put(key, model, at, yaw, scale) if model then out[key] = { model = model, at = at, yaw = yaw % 360, scale = scale or 1.0 } end end
    local function card(slug) return entityOf[slug] end
    for _, seat in ipairs(m.seats) do
        local i, pose = seat.index, seat.pose
        local mat = T.playmatById[seat.playmat] or T.playmatById[T.defaultPlaymat]
        put("mat:" .. i, mat.mesh, pose.mat, pose.yaw)
        -- The deck stack sinks into the table as it thins (one mesh, 45 cards tall).
        local n = #seat.library
        if n > 0 then
            local at = T.onMat(pose, T.zones.deck[1], T.zones.deck[2])
            at.z = at.z - T.mesh.deckHeight * (1 - math.min(1, n / 45))
            put("deck:" .. i, T.mesh.deck, at, pose.yaw)
        end
        local dice = T.dice[pose.dice] or T.dice.netrunner
        m.dieYaw = m.dieYaw or {}
        for _, kind in ipairs(seat.fixer or T.dieKinds) do
            local z = T.zones.fixer[kind]
            local key = "fixer:" .. i .. ":" .. kind
            m.dieYaw[key] = m.dieYaw[key] or math.random(0, 359)
            put(key, dice[kind], T.onMat(pose, z[1], z[2]), pose.yaw + m.dieYaw[key])
        end
        -- Gigs: in a row in the friendly Gig area, each die in its owner's colour.
        local gz = T.zones.friendlyGigs
        for k, g in ipairs(seat.gigs or {}) do
            local x = gz.x0 + (k - 0.5) * (gz.x1 - gz.x0) / 7
            local set = T.dice[m.seats[g.owner or i].pose.dice] or dice
            put("gig:" .. g.uid, set[g.kind], T.onMat(pose, x, gz.y), pose.yaw + (g.uid * 47) % 360)
        end
        -- Legends area.
        for k, l in ipairs(seat.legends) do
            if not l.onField and not l.removed then
                local z = T.zones.legends[k]
                local yaw = pose.yaw + (l.spent and 90 or 0)
                local model = l.faceUp and card(l.slug) or T.mesh.cardback
                put("leg:" .. i .. ":" .. k .. ":" .. (l.faceUp and l.slug or "back"), model, T.onMat(pose, z[1], z[2], 0.0005), yaw,
                    l.faceUp and CARD_SCALE or 1.0)
                for gi, g in ipairs(l.gear or {}) do
                    put("lgear:" .. i .. ":" .. k .. ":" .. gi, card(g), T.onMat(pose, z[1], z[2] + 0.06 * gi, 0.0002), pose.yaw, CARD_SCALE)
                end
            end
        end
        -- The field: Units in a row, closer together as it fills; Gear peeks out under its Unit.
        local f = T.zones.field
        local count = #(seat.field or {})
        local step = count > 0 and math.min(0.125, (f.x1 - f.x0) / count) or 0
        for k, u in ipairs(seat.field or {}) do
            local x = f.x0 + (k - 0.5) * step
            local yaw = pose.yaw + (u.spent and 90 or 0)
            put("unit:" .. u.uid, card(u.slug), T.onMat(pose, x, f.y, 0.001), yaw, CARD_SCALE)
            for gi, g in ipairs(u.gear or {}) do
                put("gear:" .. u.uid .. ":" .. gi .. ":" .. g, card(g), T.onMat(pose, x, f.y + 0.07 * gi, 0.0004 - gi * 0.0001), yaw, CARD_SCALE)
            end
        end
        -- Eddies: face-down cards overlapping in a row, spent ones turned.
        local e = T.zones.eddies
        local ecount = #(seat.eddies or {})
        local estep = ecount > 0 and math.min(0.045, (e.x1 - e.x0) / ecount) or 0
        for k, ed in ipairs(seat.eddies or {}) do
            put("edd:" .. ed.uid, T.mesh.cardback, T.onMat(pose, e.x0 + (k - 0.5) * estep, e.y, 0.0005 * k), pose.yaw + (ed.spent and 90 or 0))
        end
        -- Trash: the top card, face up.
        local top = seat.trash and seat.trash[#seat.trash]
        if top then put("trash:" .. i .. ":" .. #seat.trash, card(top), T.onMat(pose, T.zones.trash[1], T.zones.trash[2], 0.001), pose.yaw, CARD_SCALE) end
    end
    return out
end

local function syncTable(m)
    m.props = m.props or {}
    local want = desired(m)
    for key, have in pairs(m.props) do
        if not want[key] then removeProp(have.id); m.props[key] = nil end
    end
    for key, w in pairs(want) do
        local have = m.props[key]
        if have then
            local d = math.abs(have.at.x - w.at.x) + math.abs(have.at.y - w.at.y) + math.abs(have.at.z - w.at.z)
            if d > 0.0005 or math.abs(have.yaw - w.yaw) > 0.5 then
                pcall(Open77.props.setTransform, have.id, { position = w.at, yaw = w.yaw })
                have.at, have.yaw = w.at, w.yaw
            end
        else
            local id, why = Open77.props.create({ model = w.model, kind = "prop", position = { x = w.at.x, y = w.at.y, z = w.at.z },
                yaw = w.yaw, scale = w.scale, bucket = m.slot.bucket or 0, collision = false, physics = "none" })
            if id then m.props[key] = { id = id, at = w.at, yaw = w.yaw } else S.log("duel %d: %s refused (%s)", m.id, w.model, tostring(why)) end
        end
    end
end

local function clearTable(m)
    for _, have in pairs(m.props or {}) do removeProp(have.id) end
    m.props = {}
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
        for k, l in ipairs(s.legends) do
            legends[k].onField, legends[k].removed = l.onField, l.removed
            if l.gear and #l.gear > 0 then legends[k].gear = table.concat(l.gear, ",") end
        end
        local field, gigs, fixer = {}, {}, {}
        for k, u in ipairs(s.field or {}) do
            field[k] = { uid = u.uid, card = u.slug, spent = u.spent, lag = u.lag, power = TcgGame.power(u), legend = u.legend,
                         solo = u.solo, gear = table.concat(u.gear or {}, ","), canAttack = (TcgGame.canAttack(u)) }
        end
        for k, g in ipairs(s.gigs or {}) do gigs[k] = { uid = g.uid, kind = g.kind, value = g.value, owner = g.owner or i } end
        for k, d in ipairs(s.fixer or {}) do fixer[k] = d end
        local ready = 0
        for _, e in ipairs(s.eddies or {}) do if not e.spent then ready = ready + 1 end end
        seats[i] = { name = s.name, side = s.pose.side, playmat = s.playmat, seated = s.seated, house = s.house, deck = s.deck.name,
            library = #s.library, handCount = #s.hand, legends = legends, mulligan = s.mulligan, roll = s.roll,
            field = field, gigs = gigs, fixer = fixer, eddies = #(s.eddies or {}), eddiesReady = ready,
            trash = #(s.trash or {}), trashTop = s.trash and s.trash[#s.trash] or nil, streetCred = s.gigs and TcgGame.streetCred(s) or nil,
            available = s.fixer and TcgGame.available(s) or 0 }
    end
    local attack
    if m.attack then
        local a = m.attack
        attack = { attacker = a.attacker, owner = a.owner, defender = a.defender, target = a.target.kind == "gigs" and "gigs" or a.target.uid,
                   blocked = a.blocked, steal = a.steal }
    end
    local events = {}
    for k, e in ipairs(m.sent or {}) do
        -- The rival's draws are public, their cards are not.
        if e.kind == "draw" and e.seat ~= seat.index then events[k] = { kind = "draw", seat = e.seat }
        else events[k] = e end
    end
    return { id = m.id, slot = m.slot.id, label = m.slot.label, you = seat.index, phase = m.phase, deadline = remaining(m),
        decider = m.decider, first = m.first, turn = m.turn, active = m.active, seats = seats,
        hand = table.concat(seat.hand, ","), log = m.log, step = m.step, attack = attack, events = events, overtime = m.overtime,
        options = m.phase == "game" and TcgGame.options(m, seat.index) or nil,
        chair = seat.pose.chair, stand = seat.pose.stand, mat = seat.pose.mat, yaw = seat.pose.yaw,
        rivalMat = other(m, seat).pose.mat }
end

local function broadcast(m)
    m.sent = m.events or {}
    m.events = {}
    for _, seat in ipairs(m.seats) do
        if seat.player then TriggerClientEvent(NET .. "match", seat.player, view(m, seat)) end
    end
    m.sent = nil
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
        deck = who.deck, playmat = who.playmat, seated = false, library = {}, hand = {}, legends = {}, mulligan = nil }
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
    syncTable(m)
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

-- The game [8-9]: shared/game.lua plays the rules; here are the clock, the house and the table.
local STEP_MS = cfg.stepMs or { roll = 30000, main = 150000, react = 30000, steal = 30000 }
local driveHouse

local function afterAction(m)
    if m.over then return end
    if m.step == "over" then
        syncTable(m)
        broadcast(m)
        local winner = m.winner and m.seats[m.winner] or nil
        return endMatch(m, m.endReason or "The game is over.", winner)
    end
    m.deadline = S.now() + (STEP_MS[m.step] or 60000)
    m.stepKey = (m.stepKey or 0) + 1
    syncTable(m)
    broadcast(m)
    driveHouse(m)
end

-- Who must act now: the active player, the defender during a React step.
local function actor(m)
    if m.step == "react" and m.attack then return m.attack.defender end
    return m.active
end

function driveHouse(m)
    local who = m.seats[actor(m)]
    if not who or not who.house or m.over or m.phase ~= "game" then return end
    local key = m.stepKey
    SetTimeout(1300, function()
        if matches[m.id] ~= m or m.over or m.stepKey ~= key then return end
        local ok, why = TcgGame.housePlay(m, who.index)
        if not ok then S.log("duel %d: the house is stuck (%s)", m.id, tostring(why)); TcgGame.concede(m, who.index) end
        afterAction(m)
    end)
end

-- Nobody answers in time: the smallest die is rolled, the React step passes, the best Gigs are stolen, the turn ends.
local function timeout(m)
    local index = actor(m)
    if m.step == "main" and not cfg.houseForIdle then TcgGame.endTurn(m, index)
    else TcgGame.housePlay(m, index) end
    afterAction(m)
end

local function startGame(m)
    m.phase = "game"
    m.random = math.random
    TcgGame.begin(m)
    for _, seat in ipairs(m.seats) do
        for _, g in ipairs(seat.gigs) do g.owner = seat.index end
    end
    say(m, "The game begins: %s plays first.", m.seats[m.first].name)
    TcgGame.startTurn(m)
    afterAction(m)
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
        end
        syncTable(m)
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
        syncTable(m)
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
    if m.phase == "game" then TcgGame.concede(m, seat.index) end
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
-- A game action from the page: { type = roll|sell|play|call|legend|attack|block|resolve|steal|endTurn, ... }.
-- Hand cards are named by index and slug, so a stale click never plays another card.
local ACTIONS = {
    roll = function(m, i, d) return TcgGame.roll(m, i, tostring(d.die or "")) end,
    sell = function(m, i, d) return TcgGame.sell(m, i, d.hand) end,
    play = function(m, i, d) return TcgGame.play(m, i, d.hand, d.target) end,
    call = function(m, i, d) return TcgGame.call(m, i, tonumber(d.legend), m.step == "react") end,
    legend = function(m, i, d) return TcgGame.playLegend(m, i, tonumber(d.legend)) end,
    attack = function(m, i, d) return TcgGame.attack(m, i, tonumber(d.uid), d.target == "gigs" and "gigs" or tonumber(d.target)) end,
    block = function(m, i, d) return TcgGame.block(m, i, tonumber(d.uid)) end,
    resolve = function(m, i) return TcgGame.resolve(m, i) end,
    steal = function(m, i, d)
        local ids = {}
        for id in tostring(d.uids or ""):gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
        return TcgGame.steal(m, i, ids)
    end,
    endTurn = function(m, i) return TcgGame.endTurn(m, i) end,
}

on("act", function(player, d)
    local m = byPlayer[player]
    local seat = m and seatOf(m, player)
    if not seat or m.phase ~= "game" or m.over or type(d) ~= "table" then return end
    local fn = ACTIONS[tostring(d.type)]
    if not fn then return end
    if d.hand ~= nil then
        local hi = math.floor(tonumber(d.hand) or 0)
        if seat.hand[hi] == nil or seat.hand[hi] ~= d.card then return S.notify(player, "That card is no longer in your hand.", "error") end
        d.hand = hi
    end
    local ok, why = fn(m, seat.index, d)
    if not ok then
        TriggerClientEvent(NET .. "duelRefused", player, { reason = tostring(why) })
        return
    end
    afterAction(m)
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
                elseif m.phase == "game" then
                    timeout(m)
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
