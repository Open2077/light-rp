-- The Cyberpunk TCG rules engine (docs/RULES.md §1, §4, §5, §8-§11): the turn, Gigs, Eddies, playing cards,
-- Calling Legends, attacks (fight and steal) and the end of the game. Pure Lua over a match table, so the server runs
-- it and tools/test_game.py checks it. The card texts are free text: their effects are shown to both players and
-- not applied yet (each card will need its own script); the keywords Adrenaline, Blocker and Go Solo are applied.
--
-- A match `m` has m.seats[1..2] (from server/duel.lua: library, hand, legends = { slug, faceUp, spent }, deck, name),
-- m.first, m.random(a, b). TcgGame.begin(m) adds the zones; every action returns true or false, reason.
TcgGame = {}
local G = TcgGame
local SIDES = { d4 = 4, d6 = 6, d8 = 8, d10 = 10, d12 = 12, d20 = 20 }
G.sides = SIDES
G.dieOrder = { "d4", "d6", "d8", "d10", "d12", "d20" }
G.winGigs = 7

local function card(slug) return TcgCards[slug] or {} end
local function has(slug, keyword)
    for _, k in ipairs(card(slug).keywords or {}) do if k == keyword then return true end end
    return false
end
G.has = has

local function other(m, seat) return m.seats[seat.index == 1 and 2 or 1] end
local function say(m, fmt, ...)
    m.log = m.log or {}
    m.log[#m.log + 1] = fmt:format(...)
    while #m.log > 14 do table.remove(m.log, 1) end
end
local function label(slug)
    local c = card(slug)
    return (c.subtitle and c.subtitle ~= "") and (c.name .. ": " .. c.subtitle) or (c.name or slug)
end
G.label = label
local function nextId(m) m.uidSeq = (m.uidSeq or 0) + 1; return m.uidSeq end
-- Events for the table and the page (draws, rolls, plays, fights): consumed by server/duel.lua after each action.
local function event(m, e) m.events = m.events or {}; m.events[#m.events + 1] = e end

-- Card texts are not applied yet: the triggered parts are shown to both players.
local function effect(m, seat, slug, trigger)
    local c = card(slug)
    if not c.text or c.text == "" then return end
    if trigger and not c.text:find("{" .. trigger .. "}", 1, true) then return end
    say(m, "%s - %s: %s", seat.name, label(slug), (c.text:gsub("[{}]", ""):gsub("\n", " ")))
    event(m, { kind = "effect", seat = seat.index, card = slug, trigger = trigger })
end

-- ---------------------------------------------------------------------------------------------
-- Zones

function G.begin(m)
    m.uidSeq = m.uidSeq or 0
    for _, seat in ipairs(m.seats) do
        seat.field = {}       -- { uid, slug, spent, lag, gear = { slug... }, legend = bool, solo = bool }
        seat.eddies = {}      -- { uid, slug, spent }  (face down: only the owner knows the slug)
        seat.trash = {}       -- slugs, the last one on top
        seat.removed = {}
        seat.fixer = { "d4", "d6", "d8", "d10", "d12", "d20" }
        seat.gigs = {}        -- { uid, kind, value }
        for _, l in ipairs(seat.legends) do l.gear = l.gear or {} end
    end
    m.turn, m.active, m.step = 0, m.first, "start"
    m.emptyFixerTurns, m.overtime = 0, false
end

function G.power(unit)
    local p = card(unit.slug).power or 0
    for _, g in ipairs(unit.gear or {}) do p = p + (card(g).power or 0) end
    return p
end

function G.streetCred(seat)
    if #seat.gigs == 0 then return nil end
    local n = 0
    for _, g in ipairs(seat.gigs) do n = n + g.value end
    return n
end

local function unitByUid(seat, uid)
    for i, u in ipairs(seat.field) do if u.uid == uid then return u, i end end
end
G.unitByUid = unitByUid

-- ---------------------------------------------------------------------------------------------
-- The end of the game

local function finish(m, winner, reason)
    if m.step == "over" then return end
    m.step = "over"
    m.winner = winner and winner.index or nil
    m.endReason = reason
    say(m, "%s", reason)
    event(m, { kind = "over", winner = m.winner })
end
G.finish = finish

-- Overtime: anyone with 7+ Gigs wins at once.
local function overtimeCheck(m)
    if not m.overtime or m.step == "over" then return end
    local a, b = #m.seats[1].gigs >= G.winGigs, #m.seats[2].gigs >= G.winGigs
    if a and b then finish(m, nil, "Both players hold 7 Gigs in overtime: a tie.")
    elseif a then finish(m, m.seats[1], m.seats[1].name .. " holds 7 Gigs in overtime and wins.")
    elseif b then finish(m, m.seats[2], m.seats[2].name .. " holds 7 Gigs in overtime and wins.") end
end

local function draw(m, seat, n)
    for _ = 1, n do
        local slug = table.remove(seat.library)
        if not slug then
            finish(m, other(m, seat), seat.name .. " must draw from an empty deck and loses.")
            return false
        end
        seat.hand[#seat.hand + 1] = slug
        event(m, { kind = "draw", seat = seat.index })
    end
    return true
end
G.draw = draw

-- ---------------------------------------------------------------------------------------------
-- The turn [8]

-- Start phase: win check, ready, draw 1, then the active player rolls a Gig in (if their fixer holds a die).
function G.startTurn(m)
    if m.step == "over" then return false, "over" end
    m.turn = m.turn + 1
    local seat = m.seats[m.active]
    seat.soldTurn = nil
    -- Overtime begins after two consecutive turns that both players began with an empty fixer area [1.11.1].
    local empty = #m.seats[1].fixer == 0 and #m.seats[2].fixer == 0
    m.emptyFixerTurns = empty and (m.emptyFixerTurns + 1) or 0
    if not m.overtime and m.emptyFixerTurns >= 2 then
        m.overtime = true
        say(m, "Overtime: sudden death, 7 Gigs win at once.")
        overtimeCheck(m)
        if m.step == "over" then return true end
    end
    -- 1. Win check.
    if #seat.gigs >= G.winGigs then
        finish(m, seat, seat.name .. " starts the turn with " .. #seat.gigs .. " Gigs and wins.")
        return true
    end
    say(m, "Turn %d: %s.", m.turn, seat.name)
    -- 3. Ready: the first player's two spent Legends stay spent during their first turn.
    if not (m.turn == 1 and seat.index == m.first) then
        for _, l in ipairs(seat.legends) do l.spent = false end
        for _, u in ipairs(seat.field) do u.spent = false end
        for _, e in ipairs(seat.eddies) do e.spent = false end
    end
    -- 4. Draw 1.
    if not draw(m, seat, 1) then return true end
    -- 5. Roll in a Gig.
    m.step = #seat.fixer > 0 and "roll" or "main"
    return true
end

function G.canRoll(seat, kind)
    local found = false
    for _, k in ipairs(seat.fixer) do if k == kind then found = true end end
    if not found then return false, "That die is not in your fixer area." end
    if kind == "d20" and #seat.fixer > 1 then return false, "The d20 comes last: roll it when it is alone in the fixer area." end
    return true
end

function G.roll(m, index, kind)
    local seat = m.seats[index]
    if m.step ~= "roll" or m.active ~= index then return false, "Not the time to roll a Gig." end
    local ok, why = G.canRoll(seat, kind)
    if not ok then return false, why end
    for i, k in ipairs(seat.fixer) do if k == kind then table.remove(seat.fixer, i) break end end
    local value = m.random(1, SIDES[kind])
    local gig = { uid = nextId(m), kind = kind, value = value, owner = index }
    seat.gigs[#seat.gigs + 1] = gig
    say(m, "%s rolls the %s: %d.", seat.name, kind, value)
    event(m, { kind = "roll", seat = index, die = kind, value = value, uid = gig.uid })
    m.step = "main"
    overtimeCheck(m)
    return true
end

-- Paying [8 Play a card, 4 Legend]: Eddies first, then face-down Legends, then face-up Legends with a Sell Tag; 1 €$ each.
local function sources(seat)
    local out = {}
    for _, e in ipairs(seat.eddies) do if not e.spent then out[#out + 1] = e end end
    for _, l in ipairs(seat.legends) do if not l.spent and not l.faceUp and not l.onField then out[#out + 1] = l end end
    for _, l in ipairs(seat.legends) do
        if not l.spent and l.faceUp and not l.onField and card(l.slug).sell then out[#out + 1] = l end
    end
    return out
end
function G.available(seat) return #sources(seat) end

local function pay(m, seat, cost)
    cost = math.max(0, cost or 0)
    local src = sources(seat)
    if #src < cost then return false, ("Not enough Eddies: %d needed, %d available."):format(cost, #src) end
    for i = 1, cost do src[i].spent = true end
    return true
end

local function mainTurn(m, index)
    if m.step ~= "main" then return false, "Not now." end
    if m.active ~= index then return false, "It is your rival's turn." end
    return true
end

-- Sell for turn (once per turn): a card with a Sell Tag, face down and ready in the Eddies area.
function G.sell(m, index, handIndex)
    local ok, why = mainTurn(m, index)
    if not ok then return false, why end
    local seat = m.seats[index]
    local slug = seat.hand[handIndex]
    if not slug then return false, "No such card." end
    if not card(slug).sell then return false, "That card has no Sell Tag." end
    if seat.soldTurn == m.turn then return false, "You already sold a card this turn." end
    table.remove(seat.hand, handIndex)
    seat.eddies[#seat.eddies + 1] = { uid = nextId(m), slug = slug, spent = false }
    seat.soldTurn = m.turn
    say(m, "%s sells %s for an Eddie.", seat.name, label(slug))
    event(m, { kind = "sell", seat = index, card = slug })
    return true
end

-- Play a card from the hand: a Unit enters ready with Lag; a Gear is equipped to a friendly Unit (target uid) or a
-- face-up Legend in the Legends area (target "L<n>"); a Program resolves and goes to the trash.
function G.play(m, index, handIndex, target)
    local ok, why = mainTurn(m, index)
    if not ok then return false, why end
    local seat = m.seats[index]
    local slug = seat.hand[handIndex]
    if not slug then return false, "No such card." end
    local c = card(slug)
    local holder
    if c.type == "Legend" then return false, "Legends are played from the Legends area."
    elseif c.type == "Gear" then
        local li = type(target) == "string" and tonumber(target:match("^L(%d)$"))
        if li then
            local l = seat.legends[li]
            if l and l.faceUp and not l.onField then holder = l end
        else
            holder = unitByUid(seat, tonumber(target))
        end
        if not holder then return false, "Pick a friendly Unit or face-up Legend to equip." end
    end
    local paid, pwhy = pay(m, seat, c.cost or 0)
    if not paid then return false, pwhy end
    table.remove(seat.hand, handIndex)
    if c.type == "Unit" then
        local u = { uid = nextId(m), slug = slug, spent = false, lag = true, gear = {} }
        seat.field[#seat.field + 1] = u
        say(m, "%s plays %s (%d power).", seat.name, label(slug), G.power(u))
        event(m, { kind = "play", seat = index, card = slug, uid = u.uid })
    elseif c.type == "Gear" then
        holder.gear[#holder.gear + 1] = slug
        say(m, "%s equips %s to %s.", seat.name, label(slug), label(holder.slug))
        event(m, { kind = "equip", seat = index, card = slug })
    else
        seat.trash[#seat.trash + 1] = slug
        say(m, "%s plays the Program %s.", seat.name, label(slug))
        event(m, { kind = "program", seat = index, card = slug })
    end
    effect(m, seat, slug, c.type == "Program" and nil or "Play")
    return true
end

-- Call a Legend (once per turn, 1 €$): flip a face-down Legend without looking. Also a reaction (§9).
function G.call(m, index, legendIndex, asReaction)
    local seat = m.seats[index]
    if asReaction then
        if m.step ~= "react" or m.attack.defender ~= index then return false, "Not now." end
    else
        local ok, why = mainTurn(m, index)
        if not ok then return false, why end
    end
    if seat.calledTurn == m.turn then return false, "You already Called a Legend this turn." end
    local l = seat.legends[legendIndex]
    if not l or l.faceUp or l.onField then return false, "Pick a face-down Legend." end
    local paid, why = pay(m, seat, 1)
    if not paid then return false, why end
    l.faceUp = true
    seat.calledTurn = m.turn
    say(m, "%s Calls a Legend: %s.", seat.name, label(l.slug))
    event(m, { kind = "call", seat = index, card = l.slug, legend = legendIndex })
    effect(m, seat, l.slug, "Call")
    return true
end

-- A face-up Legend from the Legends area to the field: pay its cost; it keeps its orientation and enters with Lag,
-- except GO SOLO: ready, can attack this turn, removed from the game if it leaves the field.
function G.playLegend(m, index, legendIndex)
    local ok, why = mainTurn(m, index)
    if not ok then return false, why end
    local seat = m.seats[index]
    local l = seat.legends[legendIndex]
    if not l or not l.faceUp or l.onField then return false, "Pick a face-up Legend in your Legends area." end
    local c = card(l.slug)
    if c.cost == nil then return false, label(l.slug) .. " has a null cost: it cannot be played to the field." end
    local solo = has(l.slug, "Go Solo")
    local paid, pwhy = pay(m, seat, c.cost)
    if not paid then return false, pwhy end
    local u = { uid = nextId(m), slug = l.slug, spent = solo and false or l.spent, lag = not solo, gear = l.gear or {},
                legend = true, solo = solo, from = legendIndex }
    l.onField, l.gear = true, {}
    seat.field[#seat.field + 1] = u
    say(m, "%s plays the Legend %s to the field%s.", seat.name, label(l.slug), solo and " (Go Solo)" or "")
    event(m, { kind = "legend", seat = index, card = l.slug, uid = u.uid })
    return true
end

-- ---------------------------------------------------------------------------------------------
-- Attacks [9]

local function canAttack(unit)
    if unit.spent then return false, "That Unit is spent." end
    if unit.lag and not unit.solo and not has(unit.slug, "Adrenaline") then
        return false, "That Unit has Lag: it attacks from your next turn."
    end
    return true
end
G.canAttack = canAttack

-- target: "gigs" or the uid of a spent rival Unit.
function G.attack(m, index, uid, target)
    local ok, why = mainTurn(m, index)
    if not ok then return false, why end
    local seat, rival = m.seats[index], other(m, m.seats[index])
    local unit = unitByUid(seat, tonumber(uid))
    if not unit then return false, "Pick one of your Units." end
    local can, cwhy = canAttack(unit)
    if not can then return false, cwhy end
    local t
    if target == "gigs" then
        if #rival.gigs == 0 then return false, "Your rival has no Gig to steal." end
        t = { kind = "gigs" }
    else
        local defender = unitByUid(rival, tonumber(target))
        if not defender then return false, "Pick a rival Unit or their Gigs." end
        if not defender.spent then return false, "Only spent Units can be attacked." end
        t = { kind = "unit", uid = defender.uid }
    end
    unit.spent = true
    m.attack = { attacker = unit.uid, owner = index, defender = rival.index, target = t, original = t.kind }
    say(m, "%s attacks %s with %s (%d power).", seat.name,
        t.kind == "gigs" and (rival.name .. "'s Gigs") or label(unitByUid(rival, t.uid).slug), label(unit.slug), G.power(unit))
    event(m, { kind = "attack", seat = index, uid = unit.uid, target = t.kind == "gigs" and "gigs" or t.uid })
    effect(m, seat, unit.slug, "Attack")
    m.step = "react"
    return true
end

-- The defender's React step: "pass" ends it, "block" spends a ready BLOCKER Unit to make it the target.
function G.block(m, index, uid)
    if m.step ~= "react" or m.attack.defender ~= index then return false, "Not now." end
    local seat = m.seats[index]
    local unit = unitByUid(seat, tonumber(uid))
    if not unit or not has(unit.slug, "Blocker") then return false, "Pick a Unit with Blocker." end
    if unit.spent then return false, "A Blocker must be ready." end
    if m.attack.target.kind == "unit" and m.attack.target.uid == unit.uid then return false, "It is already the target." end
    unit.spent = true
    m.attack.target = { kind = "unit", uid = unit.uid }
    m.attack.blocked = true
    say(m, "%s blocks with %s.", seat.name, label(unit.slug))
    event(m, { kind = "block", seat = index, uid = unit.uid })
    return true
end

local function defeat(m, seat, unit)
    local _, i = unitByUid(seat, unit.uid)
    if not i then return end
    table.remove(seat.field, i)
    for _, g in ipairs(unit.gear or {}) do seat.trash[#seat.trash + 1] = g end
    if unit.legend then
        -- A Legend is only ever in the Legends area or on the field; Go Solo or not, it is removed from the game.
        seat.removed[#seat.removed + 1] = unit.slug
        local l = seat.legends[unit.from or 0]
        if l then l.removed = true end
    else
        seat.trash[#seat.trash + 1] = unit.slug
    end
    say(m, "%s is defeated.", label(unit.slug))
    event(m, { kind = "defeat", seat = seat.index, uid = unit.uid, card = unit.slug })
    effect(m, seat, unit.slug, "Defeated")
end

-- The React step ends: fight or steal.
function G.resolve(m, index)
    if m.step ~= "react" or m.attack.defender ~= index then return false, "Not now." end
    local a = m.attack
    local atkSeat, defSeat = m.seats[a.owner], m.seats[a.defender]
    local attacker = unitByUid(atkSeat, a.attacker)
    if not attacker then m.attack, m.step = nil, "main"; return true end
    if a.target.kind == "unit" then
        local defender = unitByUid(defSeat, a.target.uid)
        if not defender then m.attack, m.step = nil, "main"; return true end
        local pa, pd = math.max(0, G.power(attacker)), math.max(0, G.power(defender))
        say(m, "Fight: %s %d vs %s %d.", label(attacker.slug), pa, label(defender.slug), pd)
        event(m, { kind = "fight", attacker = attacker.uid, defender = defender.uid, pa = pa, pd = pd })
        local loseA, loseD = false, false
        if pa > pd then loseD = pa > 0
        elseif pd > pa then loseA = pd > 0
        elseif pa > 0 then loseA, loseD = true, true end
        if loseD then defeat(m, defSeat, defender) end
        if loseA then defeat(m, atkSeat, attacker) end
        m.attack, m.step = nil, "main"
        overtimeCheck(m)
        return true
    end
    -- Steal: floor(power / 10) + 1 Gigs (none at 0), picked by the stealer.
    local p = math.max(0, G.power(attacker))
    local n = p > 0 and (math.floor(p / 10) + 1) or 0
    n = math.min(n, #defSeat.gigs)
    if n == 0 then
        say(m, "%s steals nothing.", label(attacker.slug))
        m.attack, m.step = nil, "main"
        return true
    end
    a.steal = n
    m.step = "steal"
    say(m, "%s steals %d Gig%s: pick %s.", atkSeat.name, n, n > 1 and "s" or "", n > 1 and "them" or "it")
    return true
end

function G.steal(m, index, uids)
    if m.step ~= "steal" or m.attack.owner ~= index then return false, "Not now." end
    local a = m.attack
    local atkSeat, defSeat = m.seats[a.owner], m.seats[a.defender]
    if type(uids) ~= "table" or #uids ~= a.steal then return false, ("Pick %d Gig%s."):format(a.steal, a.steal > 1 and "s" or "") end
    local picked, seen = {}, {}
    for _, id in ipairs(uids) do
        id = tonumber(id)
        if seen[id] then return false, "Pick different Gigs." end
        seen[id] = true
        local found
        for i, g in ipairs(defSeat.gigs) do if g.uid == id then found = i end end
        if not found then return false, "Pick your rival's Gigs." end
        picked[#picked + 1] = id
    end
    -- They move together and keep their values.
    for _, id in ipairs(picked) do
        for i, g in ipairs(defSeat.gigs) do
            if g.uid == id then
                table.remove(defSeat.gigs, i)
                atkSeat.gigs[#atkSeat.gigs + 1] = g
                say(m, "%s steals a %s showing %d.", atkSeat.name, g.kind, g.value)
                event(m, { kind = "steal", seat = index, uid = g.uid })
                break
            end
        end
    end
    m.attack, m.step = nil, "main"
    overtimeCheck(m)
    return true
end

-- Pass: Units lose their Lag, the rival's turn begins.
function G.endTurn(m, index)
    local ok, why = mainTurn(m, index)
    if not ok then return false, why end
    local seat = m.seats[index]
    for _, s in ipairs(m.seats) do for _, u in ipairs(s.field) do u.lag = false end end
    say(m, "%s ends the turn.", seat.name)
    m.active = other(m, seat).index
    m.step = "start"
    return G.startTurn(m)
end

-- Conceding, at any time.
function G.concede(m, index)
    if m.step == "over" then return false, "over" end
    finish(m, other(m, m.seats[index]), m.seats[index].name .. " concedes.")
    return true
end

-- ---------------------------------------------------------------------------------------------
-- What each player may do now (the page lights these up; the server checks every action again).

function G.options(m, index)
    local seat = m.seats[index]
    local o = { step = m.step, mine = m.active == index, eddies = G.available(seat) }
    if m.step == "roll" and m.active == index then
        o.roll = {}
        for _, k in ipairs(seat.fixer) do o.roll[#o.roll + 1] = { die = k, ok = (G.canRoll(seat, k)) } end
    elseif m.step == "main" and m.active == index then
        o.sell = seat.soldTurn ~= m.turn
        o.call = seat.calledTurn ~= m.turn and o.eddies >= 1
        o.attackers = {}
        for _, u in ipairs(seat.field) do if canAttack(u) then o.attackers[#o.attackers + 1] = u.uid end end
    elseif m.step == "react" and m.attack.defender == index then
        o.blockers = {}
        for _, u in ipairs(seat.field) do
            if not u.spent and has(u.slug, "Blocker") then o.blockers[#o.blockers + 1] = u.uid end
        end
        o.call = seat.calledTurn ~= m.turn and o.eddies >= 1
    elseif m.step == "steal" and m.attack.owner == index then
        o.steal = m.attack.steal
    end
    return o
end

-- ---------------------------------------------------------------------------------------------
-- The house (a NEON DECK regular): plays simply and by the rules, for solo duels and tests.

function G.housePlay(m, index)
    local seat, rival = m.seats[index], other(m, m.seats[index])
    if m.step == "roll" and m.active == index then
        -- The smallest die it may roll (the d20 comes last anyway).
        for _, k in ipairs(G.dieOrder) do
            if G.canRoll(seat, k) then return G.roll(m, index, k) end
        end
        return false, "no die"
    end
    if m.step == "react" and m.attack.defender == index then return G.resolve(m, index) end
    if m.step == "steal" and m.attack.owner == index then
        local gigs = {}
        for _, g in ipairs(rival.gigs) do gigs[#gigs + 1] = g end
        table.sort(gigs, function(a, b) return a.value > b.value end)
        local ids = {}
        for i = 1, m.attack.steal do ids[i] = gigs[i].uid end
        return G.steal(m, index, ids)
    end
    if m.step ~= "main" or m.active ~= index then return false, "waiting" end
    -- Sell the most expensive card it cannot afford, when the hand is comfortable.
    if seat.soldTurn ~= m.turn and #seat.hand > 3 then
        local best, bestCost
        for i, s in ipairs(seat.hand) do
            local c = card(s)
            if c.sell and (c.cost or 0) > G.available(seat) and (not bestCost or (c.cost or 0) > bestCost) then best, bestCost = i, c.cost or 0 end
        end
        if best then return G.sell(m, index, best) end
    end
    -- Play the strongest Unit it can afford.
    local best, bestPower
    for i, s in ipairs(seat.hand) do
        local c = card(s)
        if c.type == "Unit" and (c.cost or 0) <= G.available(seat) and (not bestPower or (c.power or 0) > bestPower) then
            best, bestPower = i, c.power or 0
        end
    end
    if best then return G.play(m, index, best) end
    -- Attack: the Gigs when it can steal, else a spent rival Unit it beats.
    for _, u in ipairs(seat.field) do
        if canAttack(u) then
            if #rival.gigs > 0 and G.power(u) > 0 then return G.attack(m, index, u.uid, "gigs") end
            for _, r in ipairs(rival.field) do
                if r.spent and G.power(u) > G.power(r) then return G.attack(m, index, u.uid, r.uid) end
            end
        end
    end
    return G.endTurn(m, index)
end
