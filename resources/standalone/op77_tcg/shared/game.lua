-- The Cyberpunk TCG rules engine (docs/RULES.md §1, §4, §5, §8-§11) with every card's effect scripted
-- (shared/effects.lua). Pure Lua over a match table: the server runs it, tools/test_game.py checks it.
--
-- Effects are coroutines: a card script asks a player for a choice with ctx:pick(...), which yields a prompt; the
-- game waits (m.prompt) until that player answers (TcgGame.answer), the house answers or the clock answers. Pending
-- effects resolve one after the other [10]; nothing else can happen while one is pending.
--
-- A match `m` has m.seats[1..2] (server/duel.lua: library, hand, legends = { slug, faceUp, spent }, deck, name),
-- m.first and m.random(a, b). TcgGame.begin(m) adds the zones; every action returns true or false, reason.
TcgGame = {}
local G = TcgGame
local SIDES = { d4 = 4, d6 = 6, d8 = 8, d10 = 10, d12 = 12, d20 = 20 }
G.sides = SIDES
G.dieOrder = { "d4", "d6", "d8", "d10", "d12", "d20" }
G.winGigs = 7

local function E() return TcgEffects or {} end
local function card(slug) return TcgCards[slug] or {} end
G.card = card
local function script(slug) return (E().cards or {})[slug] or {} end
G.script = script

local function label(slug)
    local c = card(slug)
    return (c.subtitle and c.subtitle ~= "") and (c.name .. ": " .. c.subtitle) or (c.name or tostring(slug))
end
G.label = label
local function other(m, seat) return m.seats[seat.index == 1 and 2 or 1] end
G.other = other
local function say(m, fmt, ...)
    m.log = m.log or {}
    m.log[#m.log + 1] = fmt:format(...)
    while #m.log > 16 do table.remove(m.log, 1) end
end
G.say = say
local function nextId(m) m.uidSeq = (m.uidSeq or 0) + 1; return m.uidSeq end
G.nextId = nextId
local function event(m, e) m.events = m.events or {}; m.events[#m.events + 1] = e end
G.event = event

function G.hasTag(slug, tag)
    tag = tag:lower()
    for _, t in ipairs(card(slug).tags or {}) do if t:lower() == tag then return true end end
    return false
end

-- ---------------------------------------------------------------------------------------------
-- Zones

function G.begin(m)
    m.uidSeq = m.uidSeq or 0
    for _, seat in ipairs(m.seats) do
        seat.field = {}       -- { uid, slug, spent, lag, gear = { slug... }, legend, solo, mods = {}, playedTurn }
        seat.eddies = {}      -- { uid, slug, spent }
        seat.trash = {}
        seat.removed = {}
        seat.fixer = { "d4", "d6", "d8", "d10", "d12", "d20" }
        seat.gigs = {}        -- { uid, kind, value, owner }
        seat.flags = {}       -- this player's effects with a duration
        for _, l in ipairs(seat.legends) do l.gear = l.gear or {}; l.mods = l.mods or {}; l.uid = l.uid or nextId(m) end
    end
    m.turn, m.active, m.step = 0, m.first, "start"
    m.emptyFixerTurns, m.overtime = 0, false
    m.queue, m.cont = {}, {}
end

local function unitByUid(seat, uid)
    for i, u in ipairs(seat.field) do if u.uid == uid then return u, i end end
end
G.unitByUid = unitByUid
function G.findUnit(m, uid)
    for _, s in ipairs(m.seats) do
        local u = unitByUid(s, uid)
        if u then return u, s end
    end
end
-- What can hold Gear and be spent: Units on the field, face-up Legends in the Legends area.
function G.holders(seat)
    local out = {}
    for _, u in ipairs(seat.field) do out[#out + 1] = u end
    for _, l in ipairs(seat.legends) do if l.faceUp and not l.onField and not l.removed then out[#out + 1] = l end end
    return out
end
function G.findHolder(m, uid)
    for _, s in ipairs(m.seats) do
        for _, h in ipairs(G.holders(s)) do if h.uid == uid then return h, s end end
    end
end

function G.streetCred(seat)
    if #seat.gigs == 0 then return nil end
    local n = 0
    for _, g in ipairs(seat.gigs) do n = n + g.value end
    return n
end
-- Null Street Cred is lower than any number.
function G.credLess(a, b)
    local x, y = G.streetCred(a), G.streetCred(b)
    if x == nil then return y ~= nil end
    if y == nil then return false end
    return x < y
end
function G.credEven(seat) local x = G.streetCred(seat); return x ~= nil and x % 2 == 0 end
function G.isMin(g) return g.value == 1 end
function G.isMax(g) return g.value == SIDES[g.kind] end
function G.valuePairs(seat)
    local counts, n = {}, 0
    for _, g in ipairs(seat.gigs) do counts[g.value] = (counts[g.value] or 0) + 1 end
    for _, c in pairs(counts) do n = n + math.floor(c / 2) end
    return n
end
function G.distinctValues(seat)
    local seen, n = {}, 0
    for _, g in ipairs(seat.gigs) do if not seen[g.value] then seen[g.value] = true; n = n + 1 end end
    return n
end

-- ---------------------------------------------------------------------------------------------
-- Modifiers with a duration: { power, kw = { Blocker = true }, flag, untilEnd = turn, untilStart = seat index }

function G.addMod(m, target, mod)
    target.mods = target.mods or {}
    target.mods[#target.mods + 1] = mod
end
local function expire(list, pred)
    for i = #(list or {}), 1, -1 do if pred(list[i]) then table.remove(list, i) end end
end
local function expireAll(m, pred)
    for _, s in ipairs(m.seats) do
        for _, u in ipairs(s.field) do expire(u.mods, pred) end
        for _, l in ipairs(s.legends) do expire(l.mods, pred) end
        expire(s.flags, pred)
    end
end
function G.flag(seat, name)
    for _, f in ipairs(seat.flags or {}) do if f.flag == name then return f end end
end
function G.unitFlag(u, name)
    for _, f in ipairs(u.mods or {}) do if f.flag == name then return f end end
end

-- Keywords: the card's own (shared/effects.lua lists them: reminder texts mention others), its Gear's, granted ones.
function G.kw(m, seat, u, keyword)
    local k = E().keywords or {}
    if (k[u.slug] or {})[keyword] then return true end
    for _, g in ipairs(u.gear or {}) do if (k[g] or {})[keyword] then return true end end
    for _, mod in ipairs(u.mods or {}) do if mod.kw and mod.kw[keyword] then return true end end
    local f = E().keywordStatic
    return f and f(m, seat, u, keyword) or false
end

-- Power: printed + Gear + modifiers + continuous effects (shared/effects.lua staticPower).
function G.power(m, u, seat)
    if not seat then local _, s = G.findHolder(m, u.uid); seat = s end
    local p = card(u.slug).power or 0
    for _, g in ipairs(u.gear or {}) do p = p + (card(g).power or 0) end
    for _, mod in ipairs(u.mods or {}) do p = p + (mod.power or 0) end
    local f = E().staticPower
    if f and seat then p = p + f(m, seat, u) end
    return p
end

function G.available(seat)
    local n = 0
    for _, e in ipairs(seat.eddies) do if not e.spent then n = n + 1 end end
    for _, l in ipairs(seat.legends) do
        if not l.spent and not l.onField and not l.removed and (not l.faceUp or card(l.slug).sell) then n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------------------------------------
-- Effects: a queue of coroutines, prompts, continuations

local function busy(m) return m.prompt ~= nil or m.co ~= nil or #m.queue > 0 or #m.cont > 0 end
G.busy = busy

-- Queue a card effect: fn(ctx) runs as a coroutine; ctx carries the match, the controller and the source.
function G.queue(m, seat, slug, fn, extra)
    local ctx = setmetatable({ m = m, seat = seat, rival = other(m, seat), card = slug }, { __index = TcgEffectsCtx or {} })
    for k, v in pairs(extra or {}) do ctx[k] = v end
    m.queue[#m.queue + 1] = { ctx = ctx, fn = fn }
end
-- After the queue empties: the rest of the action that triggered the effects.
function G.after(m, fn) m.cont[#m.cont + 1] = fn end

local finish
local function overtimeCheck(m)
    if not m.overtime or m.step == "over" then return end
    local a, b = #m.seats[1].gigs >= G.winGigs, #m.seats[2].gigs >= G.winGigs
    if a and b then finish(m, nil, "Both players hold 7 Gigs in overtime: a tie.")
    elseif a then finish(m, m.seats[1], m.seats[1].name .. " holds 7 Gigs in overtime and wins.")
    elseif b then finish(m, m.seats[2], m.seats[2].name .. " holds 7 Gigs in overtime and wins.") end
end

function G.pump(m)
    local guard = 0
    while m.step ~= "over" and not m.prompt do
        guard = guard + 1
        if guard > 5000 then say(m, "Effect loop stopped."); m.queue, m.cont, m.co = {}, {}, nil; break end
        if m.co then
            local answer = m.answer
            m.answer = nil
            local ok, res = coroutine.resume(m.co.thread, answer)
            if not ok then
                say(m, "Effect of %s failed: %s", label(m.co.ctx.card), tostring(res))
                m.co = nil
            elseif coroutine.status(m.co.thread) == "dead" then
                m.co = nil
            else
                m.prompt = res
                m.prompt.id = nextId(m)
                return
            end
        elseif #m.queue > 0 then
            local q = table.remove(m.queue, 1)
            m.co = { ctx = q.ctx, thread = coroutine.create(function() q.fn(q.ctx) end) }
        elseif #m.cont > 0 then
            local fn = table.remove(m.cont)
            fn()
        else
            break
        end
        overtimeCheck(m)
    end
end

-- The prompted player answers: picks = option indices (1-based), {} to decline an optional prompt.
function G.answer(m, index, picks)
    local p = m.prompt
    if not p then return false, "Nothing to answer." end
    if p.seat ~= index then return false, "Not your choice." end
    if type(picks) ~= "table" then picks = {} end
    local seen, out = {}, {}
    for _, k in ipairs(picks) do
        k = math.floor(tonumber(k) or 0)
        if k < 1 or k > #p.options or seen[k] then return false, "Invalid choice." end
        if p.options[k].disabled then return false, "That option is not allowed." end
        seen[k] = true
        out[#out + 1] = k
    end
    local min = p.optional and 0 or (p.min or 1)
    if #out < min or #out > (p.max or 1) then
        return false, ("Pick %s."):format(min == (p.max or 1) and tostring(min) or (min .. " to " .. (p.max or 1)))
    end
    m.prompt = nil
    m.answer = out
    G.pump(m)
    return true
end

-- The default answer (the house, the clock): the first allowed options; an optional prompt is declined by the clock.
function G.defaultAnswer(m)
    local p = m.prompt
    if not p then return false end
    local picks = {}
    if not p.optional or p.house then
        local want = p.min or 1
        if p.optional and want < 1 then want = 1 end
        want = math.min(want, p.max or 1)
        for i, o in ipairs(p.options) do
            if #picks >= want then break end
            if not o.disabled then picks[#picks + 1] = i end
        end
    end
    return G.answer(m, p.seat, picks)
end

-- ---------------------------------------------------------------------------------------------
-- Events every card in play can watch (shared/effects.lua `on` handlers)

function G.inPlay(m, seat)
    local out = {}
    for _, u in ipairs(seat.field) do
        out[#out + 1] = { slug = u.slug, holder = u }
        for _, g in ipairs(u.gear or {}) do out[#out + 1] = { slug = g, holder = u, gear = true } end
    end
    for _, l in ipairs(seat.legends) do
        if l.faceUp and not l.onField and not l.removed then
            out[#out + 1] = { slug = l.slug, holder = l, legendArea = true }
            for _, g in ipairs(l.gear or {}) do out[#out + 1] = { slug = g, holder = l, gear = true } end
        end
    end
    return out
end

-- Each watcher of both players (the turn player's first [10]) gets the event as a pending effect.
function G.fire(m, name, data)
    local gl = (E().global or {})[name]
    if gl then gl(m, data) end
    local order = { m.seats[m.active], other(m, m.seats[m.active]) }
    for _, seat in ipairs(order) do
        for _, c in ipairs(G.inPlay(m, seat)) do
            local h = (script(c.slug).on or {})[name]
            if h then G.queue(m, seat, c.slug, function(ctx) h(ctx, data) end, { holder = c.holder, isGear = c.gear }) end
        end
    end
end

-- ---------------------------------------------------------------------------------------------
-- The end of the game

function finish(m, winner, reason)
    if m.step == "over" then return end
    m.step = "over"
    m.winner = winner and winner.index or nil
    m.endReason = reason
    m.prompt, m.co, m.queue, m.cont = nil, nil, {}, {}
    say(m, "%s", reason)
    event(m, { kind = "over", winner = m.winner })
end
G.finish = finish

-- ---------------------------------------------------------------------------------------------
-- Basic moves (the engine's and the card scripts')

function G.draw(m, seat, n)
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

-- Trash X: the top cards of the deck go to the trash (returned).
function G.mill(m, seat, n)
    local out = {}
    for _ = 1, n do
        local slug = table.remove(seat.library)
        if not slug then break end
        seat.trash[#seat.trash + 1] = slug
        out[#out + 1] = slug
    end
    return out
end

function G.spendCard(m, seat, h)
    if h.spent then return false end
    h.spent = true
    G.fire(m, "spent", { seat = seat, holder = h })
    return true
end

-- Defeat a Unit: to the trash with its Gear (a Legend is removed from the game). Replacement effects first.
function G.defeat(m, seat, u, cause)
    local _, i = unitByUid(seat, u.uid)
    if not i then return false end
    local r = E().replaceDefeat
    if r and r(m, seat, u, cause) then return false end
    table.remove(seat.field, i)
    for _, g in ipairs(u.gear or {}) do seat.trash[#seat.trash + 1] = g end
    if u.legend then
        seat.removed[#seat.removed + 1] = u.slug
        local l = seat.legends[u.from or 0]
        if l then l.removed = true end
    else
        seat.trash[#seat.trash + 1] = u.slug
    end
    say(m, "%s is defeated.", label(u.slug))
    event(m, { kind = "defeat", seat = seat.index, uid = u.uid, card = u.slug })
    local d = script(u.slug).defeated
    if d then G.queue(m, seat, u.slug, d, { holder = u }) end
    for _, g in ipairs(u.gear or {}) do
        local gd = script(g).defeated
        if gd then G.queue(m, seat, g, gd, { holder = u, isGear = true }) end
    end
    G.fire(m, "defeated", { seat = seat, unit = u, cause = cause })
    return true
end

-- Bottom-deck or return a Unit: it leaves the field (Gear to the trash) without being defeated.
function G.removeUnit(m, seat, u, where)
    local _, i = unitByUid(seat, u.uid)
    if not i then return false end
    table.remove(seat.field, i)
    for _, g in ipairs(u.gear or {}) do seat.trash[#seat.trash + 1] = g end
    if u.legend then
        seat.removed[#seat.removed + 1] = u.slug
        local l = seat.legends[u.from or 0]
        if l then l.removed = true end
    elseif where == "hand" then seat.hand[#seat.hand + 1] = u.slug
    else table.insert(seat.library, 1, u.slug) end
    say(m, "%s leaves the field.", label(u.slug))
    event(m, { kind = "defeat", seat = seat.index, uid = u.uid, card = u.slug })
    return true
end

function G.setGig(m, g, value)
    value = math.max(1, math.min(SIDES[g.kind], value))
    if value == g.value then return false end
    g.value = value
    event(m, { kind = "gig", uid = g.uid, value = value })
    return true
end

function G.addGig(m, seat, kind, value, owner)
    local g = { uid = nextId(m), kind = kind, value = value, owner = owner or seat.index }
    seat.gigs[#seat.gigs + 1] = g
    return g
end

-- ---------------------------------------------------------------------------------------------
-- The turn [8]

local function mainTurn(m, index)
    if busy(m) then return false, "Resolve the pending effect first." end
    if m.step ~= "main" then return false, "Not now." end
    if m.active ~= index then return false, "It is your rival's turn." end
    return true
end

function G.startTurn(m)
    if m.step == "over" then return false, "over" end
    m.turn = m.turn + 1
    local seat = m.seats[m.active]
    seat.soldTurn = nil
    for _, s in ipairs(m.seats) do s.firsts = {} end
    expireAll(m, function(x) return x.untilStart == seat.index end)
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
    m.step = "starting"
    -- 2. Start-of-turn effects.
    G.fire(m, "startTurn", { seat = seat })
    G.after(m, function()
        -- 3. Ready (the first player's two spent Legends stay spent on their first turn; "can't ready" holds).
        if not (m.turn == 1 and seat.index == m.first) then
            for _, l in ipairs(seat.legends) do if not G.unitFlag(l, "noReady") then l.spent = false end end
            for _, u in ipairs(seat.field) do if not G.unitFlag(u, "noReady") then u.spent = false end end
            for _, e in ipairs(seat.eddies) do e.spent = false end
        end
        -- 4. Draw 1.
        if not G.draw(m, seat, 1) then return end
        -- 5. Roll in a Gig.
        m.step = #seat.fixer > 0 and "roll" or "main"
    end)
    G.pump(m)
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
    if busy(m) then return false, "Resolve the pending effect first." end
    if m.step ~= "roll" or m.active ~= index then return false, "Not the time to roll a Gig." end
    local ok, why = G.canRoll(seat, kind)
    if not ok then return false, why end
    for i, k in ipairs(seat.fixer) do if k == kind then table.remove(seat.fixer, i) break end end
    local g = G.addGig(m, seat, kind, m.random(1, SIDES[kind]), index)
    say(m, "%s rolls the %s: %d.", seat.name, kind, g.value)
    event(m, { kind = "roll", seat = index, die = kind, value = g.value, uid = g.uid })
    m.step = "main"
    G.fire(m, "rolled", { seat = seat, gig = g, fromFixer = true })
    G.pump(m)
    return true
end

-- Paying: Eddies first, then face-down Legends, then face-up Legends with a Sell Tag; 1 €$ each.
local function pay(m, seat, cost)
    cost = math.max(0, cost or 0)
    if G.available(seat) < cost then return false, ("Not enough €$: %d needed, %d available."):format(cost, G.available(seat)) end
    local left = cost
    for _, e in ipairs(seat.eddies) do if left > 0 and not e.spent then e.spent = true; left = left - 1 end end
    for pass = 1, 2 do
        for _, l in ipairs(seat.legends) do
            if left > 0 and not l.spent and not l.onField and not l.removed and
                ((pass == 1 and not l.faceUp) or (pass == 2 and l.faceUp and card(l.slug).sell)) then
                G.spendCard(m, seat, l)
                left = left - 1
            end
        end
    end
    return true
end
G.pay = pay

-- What a card costs this player (cost changes never bring a payment below 1 €$).
function G.costOf(m, seat, slug, how)
    local c = card(slug).cost or 0
    local f = E().costMod
    if f then
        local d = f(m, seat, slug, how) or 0
        if d < 0 then c = math.max(math.min(c, 1), c + d) elseif d > 0 then c = c + d end
    end
    return c
end

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

-- A card enters play (paid or free): a Unit to the field with Lag; a Gear equipped (a prompt picks the holder when
-- none is given); a Program resolves, then goes to the trash (or where its effect sends it).
function G.putIntoPlay(m, seat, slug, opts)
    opts = opts or {}
    local c = card(slug)
    if c.type == "Unit" then
        local u = { uid = nextId(m), slug = slug, spent = false, lag = true, gear = {}, mods = {}, playedTurn = m.turn }
        seat.field[#seat.field + 1] = u
        say(m, "%s plays %s (%d power).", seat.name, label(slug), G.power(m, u, seat))
        event(m, { kind = "play", seat = seat.index, card = slug, uid = u.uid })
        local p = script(slug).play
        if p then G.queue(m, seat, slug, p, { holder = u }) end
        G.fire(m, "played", { seat = seat, slug = slug, unit = u })
        return u
    elseif c.type == "Gear" then
        if opts.holder then G.equip(m, seat, slug, opts.holder); return true end
        G.queue(m, seat, slug, function(ctx)
            local h = ctx:pickHolder(seat, "Equip " .. label(slug) .. " to", opts.filter)
            if h then G.equip(m, seat, slug, h) else seat.trash[#seat.trash + 1] = slug end
        end)
        return true
    else
        say(m, "%s plays the Program %s.", seat.name, label(slug))
        event(m, { kind = "program", seat = seat.index, card = slug })
        seat.programTurn = m.turn
        local resolved = { slug = slug, dest = opts.bottom and "bottom" or "trash" }
        local p = script(slug).play
        if p then G.queue(m, seat, slug, p, { program = resolved }) end
        G.queue(m, seat, slug, function()
            if resolved.dest == "bottom" then table.insert(seat.library, 1, slug)
            elseif resolved.dest == "hand" then seat.hand[#seat.hand + 1] = slug
            else seat.trash[#seat.trash + 1] = slug end
        end)
        G.fire(m, "played", { seat = seat, slug = slug })
        return true
    end
end

function G.equip(m, seat, slug, holder)
    holder.gear = holder.gear or {}
    holder.gear[#holder.gear + 1] = slug
    say(m, "%s equips %s to %s.", seat.name, label(slug), label(holder.slug))
    event(m, { kind = "equip", seat = seat.index, card = slug })
    local p = script(slug).play
    if p then G.queue(m, seat, slug, p, { holder = holder }) end
    G.fire(m, "played", { seat = seat, slug = slug, holder = holder })
end

-- Play a card from the hand, paying its cost. Gear: target = its holder's uid (else a prompt asks).
function G.play(m, index, handIndex, target)
    local ok, why = mainTurn(m, index)
    if not ok then return false, why end
    return G.playFromHand(m, index, handIndex, target)
end

function G.playFromHand(m, index, handIndex, target)
    local seat = m.seats[index]
    local slug = seat.hand[handIndex]
    if not slug then return false, "No such card." end
    local c = card(slug)
    if c.type == "Legend" then return false, "Legends are played from the Legends area." end
    local holder
    if c.type == "Gear" then
        if target ~= nil then
            local h, hs = G.findHolder(m, tonumber(target))
            if not h or hs ~= seat then return false, "Pick a friendly Unit or face-up Legend to equip." end
            holder = h
        elseif #G.holders(seat) == 0 then
            return false, "No friendly Unit or face-up Legend to equip."
        end
    end
    local paid, pwhy = pay(m, seat, G.costOf(m, seat, slug, "hand"))
    if not paid then return false, pwhy end
    table.remove(seat.hand, handIndex)
    G.putIntoPlay(m, seat, slug, { holder = holder })
    G.pump(m)
    return true
end

-- Call a Legend (once per turn, 1 €$, or free from an effect): flip a face-down Legend without looking.
function G.callLegend(m, seat, legendIndex, free)
    local l = seat.legends[legendIndex]
    if not l or l.faceUp or l.onField or l.removed then return false, "Pick a face-down Legend." end
    if seat.calledTurn == m.turn then return false, "You already Called a Legend this turn." end
    if not free then
        local paid, why = pay(m, seat, 1)
        if not paid then return false, why end
    end
    l.faceUp = true
    seat.calledTurn = m.turn
    say(m, "%s Calls a Legend: %s.", seat.name, label(l.slug))
    event(m, { kind = "call", seat = seat.index, card = l.slug, legend = legendIndex })
    local c = script(l.slug).call
    if c then G.queue(m, seat, l.slug, c, { holder = l }) end
    return true
end

function G.call(m, index, legendIndex, asReaction)
    local seat = m.seats[index]
    if asReaction then
        if busy(m) then return false, "Resolve the pending effect first." end
        if m.step ~= "react" or m.attack.defender ~= index then return false, "Not now." end
    else
        local ok, why = mainTurn(m, index)
        if not ok then return false, why end
    end
    local free = not asReaction and E().freeCall and E().freeCall(m, seat)
    local ok, why = G.callLegend(m, seat, legendIndex, free)
    if not ok then return false, why end
    G.pump(m)
    return true
end

-- A face-up Legend from the Legends area to the field: its cost; GO SOLO enters ready and can attack this turn.
function G.playLegend(m, index, legendIndex)
    local ok, why = mainTurn(m, index)
    if not ok then return false, why end
    local seat = m.seats[index]
    local l = seat.legends[legendIndex]
    if not l or not l.faceUp or l.onField or l.removed then return false, "Pick a face-up Legend in your Legends area." end
    local c = card(l.slug)
    if c.cost == nil then return false, label(l.slug) .. " has a null cost: it cannot be played to the field." end
    local solo = G.kw(m, seat, l, "Go Solo")
    local paid, pwhy = pay(m, seat, G.costOf(m, seat, l.slug, solo and "solo" or "legend"))
    if not paid then return false, pwhy end
    local u = { uid = l.uid, slug = l.slug, spent = solo and false or l.spent, lag = not solo, gear = l.gear or {}, mods = l.mods or {},
                legend = true, solo = solo, from = legendIndex, playedTurn = m.turn }
    l.onField, l.gear, l.mods = true, {}, {}
    seat.field[#seat.field + 1] = u
    say(m, "%s plays the Legend %s to the field%s.", seat.name, label(l.slug), solo and " (Go Solo)" or "")
    event(m, { kind = "legend", seat = index, card = l.slug, uid = u.uid })
    local p = script(l.slug).play
    if p then G.queue(m, seat, l.slug, p, { holder = u }) end
    G.pump(m)
    return true
end

-- Activated effects (effects.lua `activate`): a Unit, a face-up Legend, or the holder of a Gear that grants one.
function G.activations(m, seat)
    local out = {}
    for _, c in ipairs(G.inPlay(m, seat)) do
        local a = script(c.slug).activate
        if a and a.fn then out[#out + 1] = { slug = c.slug, id = c.slug, holder = c.holder, act = a, gear = c.gear }
        elseif a then
            for i, x in ipairs(a) do out[#out + 1] = { slug = c.slug, id = c.slug .. "#" .. i, holder = c.holder, act = x, gear = c.gear } end
        end
    end
    return out
end

function G.canActivate(m, seat, entry, reacting)
    local a, h = entry.act, entry.holder
    if reacting and not a.quick then return false, "Only Quick effects as a reaction." end
    if a.spend and h.spent then return false, "It is spent." end
    if a.spend and h.lag and not h.solo and G.findUnit(m, h.uid) then return false, "Lagging Units cannot use spend effects." end
    local key = "act:" .. entry.id .. ":" .. tostring(h.uid)
    if a.once and seat.firsts and seat.firsts[key] then return false, "Once per turn." end
    local cost = a.cost or 0
    if a.costMod then cost = math.max(0, cost + a.costMod(m, seat, h)) end
    if G.available(seat) < cost then return false, "Not enough €$." end
    if a.can and not a.can(m, seat, h) then return false, "Nothing to do now." end
    return true, cost
end

function G.activate(m, index, holderUid, id)
    local seat = m.seats[index]
    if busy(m) then return false, "Resolve the pending effect first." end
    local reacting = m.step == "react" and m.attack and m.attack.defender == index
    if not reacting then
        local ok, why = mainTurn(m, index)
        if not ok then return false, why end
    end
    local entry
    for _, e in ipairs(G.activations(m, seat)) do
        if e.holder.uid == tonumber(holderUid) and e.id == id then entry = e end
    end
    if not entry then return false, "No such effect." end
    local ok, cost = G.canActivate(m, seat, entry, reacting)
    if not ok then return false, cost end
    pay(m, seat, cost)
    if entry.act.spend then G.spendCard(m, seat, entry.holder) end
    if entry.act.once then seat.firsts = seat.firsts or {}; seat.firsts["act:" .. entry.id .. ":" .. tostring(entry.holder.uid)] = true end
    say(m, "%s uses %s.", seat.name, label(entry.slug))
    event(m, { kind = "activate", seat = index, card = entry.slug })
    G.queue(m, seat, entry.slug, entry.act.fn, { holder = entry.holder })
    G.pump(m)
    return true
end

-- ---------------------------------------------------------------------------------------------
-- Attacks [9]

-- target nil (any), "gigs" or a rival Unit uid.
function G.canAttack(m, seat, u, target)
    if u.spent then return false, "That Unit is spent." end
    local rule = E().attackRule
    local allowLag, forbid = false, nil
    if rule then allowLag, forbid = rule(m, seat, u, target) end
    if forbid then return false, forbid end
    if u.lag and not u.solo and not G.kw(m, seat, u, "Adrenaline") and not allowLag then
        return false, "That Unit has Lag: it attacks from your next turn."
    end
    if target == nil then return true end
    local rival = other(m, seat)
    if target == "gigs" then
        if #rival.gigs == 0 then return false, "Your rival has no Gig to steal." end
        return true
    end
    local d = unitByUid(rival, tonumber(target))
    if not d then return false, "Pick a rival Unit or their Gigs." end
    if not d.spent then
        local ready = E().canAttackReady
        if not (ready and ready(m, seat, u, d)) then return false, "Only spent Units can be attacked." end
    end
    return true
end

function G.attack(m, index, uid, target)
    local ok, why = mainTurn(m, index)
    if not ok then return false, why end
    local seat, rival = m.seats[index], other(m, m.seats[index])
    local unit = unitByUid(seat, tonumber(uid))
    if not unit then return false, "Pick one of your Units." end
    target = target == "gigs" and "gigs" or tonumber(target)
    local can, cwhy = G.canAttack(m, seat, unit, target)
    if not can then return false, cwhy end
    local t = target == "gigs" and { kind = "gigs" } or { kind = "unit", uid = target }
    m.attack = { attacker = unit.uid, owner = index, defender = rival.index, target = t, original = t.kind }
    unit.attacked = m.turn
    say(m, "%s attacks %s with %s (%d power).", seat.name,
        t.kind == "gigs" and (rival.name .. "'s Gigs") or label(unitByUid(rival, t.uid).slug), label(unit.slug), G.power(m, unit, seat))
    event(m, { kind = "attack", seat = index, uid = unit.uid, target = t.kind == "gigs" and "gigs" or t.uid })
    m.step = "attacking"
    G.spendCard(m, seat, unit)
    local a = script(unit.slug).attack
    if a then G.queue(m, seat, unit.slug, a, { holder = unit }) end
    for _, g in ipairs(unit.gear or {}) do
        local ga = script(g).attack
        if ga then G.queue(m, seat, g, ga, { holder = unit, isGear = true }) end
    end
    G.fire(m, "attacks", { seat = seat, unit = unit })
    G.after(m, function()
        if m.step == "over" then return end
        if not m.attack then m.step = "main"; return end
        -- The attack ends early if the attacker or the defending Unit left the field.
        if not unitByUid(seat, m.attack.attacker) or (m.attack.target.kind == "unit" and not unitByUid(rival, m.attack.target.uid)) then
            m.attack, m.step = nil, "main"
            return
        end
        m.step = "react"
    end)
    G.pump(m)
    return true
end

function G.block(m, index, uid)
    if busy(m) then return false, "Resolve the pending effect first." end
    if m.step ~= "react" or m.attack.defender ~= index then return false, "Not now." end
    local seat = m.seats[index]
    local unit = unitByUid(seat, tonumber(uid))
    if not unit or not G.kw(m, seat, unit, "Blocker") then return false, "Pick a Unit with Blocker." end
    if unit.spent then return false, "A Blocker must be ready." end
    if m.attack.target.kind == "unit" and m.attack.target.uid == unit.uid then return false, "It is already the target." end
    local atkSeat = m.seats[m.attack.owner]
    local attacker = unitByUid(atkSeat, m.attack.attacker)
    local unblockable = E().unblockable
    if unblockable and attacker and unblockable(m, atkSeat, attacker) then return false, "That Unit can't be blocked." end
    m.attack.target = { kind = "unit", uid = unit.uid }
    m.attack.blocked = true
    say(m, "%s blocks with %s.", seat.name, label(unit.slug))
    event(m, { kind = "block", seat = index, uid = unit.uid })
    G.spendCard(m, seat, unit)
    local b = (script(unit.slug).on or {}).myBlock
    if b then G.queue(m, seat, unit.slug, function(ctx) b(ctx) end, { holder = unit }) end
    G.fire(m, "blocked", { seat = seat, unit = unit })
    G.pump(m)
    return true
end

-- One Gig changes hands, keeping its value; "would be stolen" effects may stop it, "when stolen" ones trigger.
function G.stealGig(m, atkSeat, defSeat, g, attacker)
    local stop = E().preventSteal
    if stop and stop(m, atkSeat, defSeat, g, attacker) then return false end
    for i, x in ipairs(defSeat.gigs) do
        if x == g then table.remove(defSeat.gigs, i) break end
    end
    atkSeat.gigs[#atkSeat.gigs + 1] = g
    say(m, "%s steals a %s showing %d.", atkSeat.name, g.kind, g.value)
    event(m, { kind = "steal", seat = atkSeat.index, uid = g.uid })
    if attacker then attacker.stoleTurn = m.turn end
    G.fire(m, "stole", { seat = atkSeat, rival = defSeat, gig = g, unit = attacker })
    return true
end

function G.resolve(m, index)
    if busy(m) then return false, "Resolve the pending effect first." end
    if m.step ~= "react" or m.attack.defender ~= index then return false, "Not now." end
    local a = m.attack
    local atkSeat, defSeat = m.seats[a.owner], m.seats[a.defender]
    local attacker = unitByUid(atkSeat, a.attacker)
    m.step = "resolving"
    G.after(m, function()
        if m.step == "over" then return end
        if m.step ~= "steal" then m.attack, m.step = nil, "main" end
    end)
    if not attacker then G.pump(m); return true end
    if a.target.kind == "unit" then
        local defender = unitByUid(defSeat, a.target.uid)
        if defender then G.fight(m, atkSeat, attacker, defSeat, defender) end
        G.pump(m)
        return true
    end
    -- Steal floor(power / 10) + 1 Gigs (none at 0 power), picked by the stealer.
    local p = math.max(0, G.power(m, attacker, atkSeat))
    local n = p > 0 and (math.floor(p / 10) + 1) or 0
    local f = E().stealCount
    if f and n > 0 then n = math.max(0, n + (f(m, atkSeat, attacker) or 0)) end
    local allowed = {}
    local filter = E().stealable
    for _, g in ipairs(defSeat.gigs) do
        if not filter or filter(m, atkSeat, attacker, defSeat, g) then allowed[#allowed + 1] = g end
    end
    n = math.min(n, #allowed)
    if n == 0 then
        say(m, "%s steals nothing.", label(attacker.slug))
        G.pump(m)
        return true
    end
    a.steal = n
    a.stealable = {}
    for _, g in ipairs(allowed) do a.stealable[g.uid] = true end
    m.step = "steal"
    m.cont = {}
    say(m, "%s steals %d Gig%s: pick %s.", atkSeat.name, n, n > 1 and "s" or "", n > 1 and "them" or "it")
    G.pump(m)
    return true
end

function G.steal(m, index, uids)
    if busy(m) then return false, "Resolve the pending effect first." end
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
        for _, g in ipairs(defSeat.gigs) do if g.uid == id then found = g end end
        if not found or not a.stealable[id] then return false, "Pick Gigs you may steal." end
        picked[#picked + 1] = found
    end
    local attacker = unitByUid(atkSeat, a.attacker)
    m.step = "resolving"
    for _, g in ipairs(picked) do G.stealGig(m, atkSeat, defSeat, g, attacker) end
    G.after(m, function() if m.step ~= "over" then m.attack, m.step = nil, "main" end end)
    G.pump(m)
    return true
end

-- A fight [9]: power compared, losers defeated; card effects may decide it (effects.lua fightOutcome).
function G.fight(m, sa, ua, sb, ub)
    m.fighting = { [ua.uid] = ub, [ub.uid] = ua }
    local pa, pb = math.max(0, G.power(m, ua, sa)), math.max(0, G.power(m, ub, sb))
    say(m, "Fight: %s %d vs %s %d.", label(ua.slug), pa, label(ub.slug), pb)
    event(m, { kind = "fight", attacker = ua.uid, defender = ub.uid, pa = pa, pd = pb })
    local loseA, loseB = false, false
    if pa > pb then loseB = pa > 0
    elseif pb > pa then loseA = pb > 0
    elseif pa > 0 then loseA, loseB = true, true end
    local decide = E().fightOutcome
    if decide then loseA, loseB = decide(m, sa, ua, sb, ub, loseA, loseB, pa, pb) end
    m.fighting = nil
    ua.foughtTurn, ub.foughtTurn = m.turn, m.turn
    G.fire(m, "fought", { a = sa, ua = ua, b = sb, ub = ub, loseA = loseA, loseB = loseB,
        winA = loseB and not loseA, winB = loseA and not loseB, pa = pa, pb = pb })
    if loseB then G.defeat(m, sb, ub, "fight") end
    if loseA then G.defeat(m, sa, ua, "fight") end
end

-- Pass: end-of-turn effects, "this turn" effects end, Units lose their Lag, the rival's turn begins.
function G.endTurn(m, index)
    local ok, why = mainTurn(m, index)
    if not ok then return false, why end
    local seat = m.seats[index]
    local must = E().mustAttack
    if must then
        local u = must(m, seat)
        if u then return false, label(u.slug) .. " must attack this turn." end
    end
    m.step = "ending"
    G.fire(m, "endTurn", { seat = seat })
    G.after(m, function()
        if m.step == "over" then return end
        expireAll(m, function(x) return x.untilEnd ~= nil and x.untilEnd <= m.turn end)
        for _, s in ipairs(m.seats) do for _, u in ipairs(s.field) do u.lag = false end end
        say(m, "%s ends the turn.", seat.name)
        m.active = other(m, seat).index
        m.step = "start"
        G.startTurn(m)
    end)
    G.pump(m)
    return true
end

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
    if busy(m) then o.waiting = not (m.prompt and m.prompt.seat == index); return o end
    local reacting = m.step == "react" and m.attack and m.attack.defender == index
    if m.step == "roll" and m.active == index then
        o.roll = {}
        for _, k in ipairs(seat.fixer) do o.roll[#o.roll + 1] = { die = k, ok = (G.canRoll(seat, k)) } end
    elseif m.step == "main" and m.active == index then
        o.sell = seat.soldTurn ~= m.turn
        o.call = seat.calledTurn ~= m.turn and (o.eddies >= 1 or (E().freeCall and E().freeCall(m, seat)) and true or false)
        o.attackers = {}
        for _, u in ipairs(seat.field) do if G.canAttack(m, seat, u) then o.attackers[#o.attackers + 1] = u.uid end end
        o.costs = {}
        for i, s in ipairs(seat.hand) do o.costs[i] = G.costOf(m, seat, s, "hand") end
    elseif reacting then
        o.blockers = {}
        for _, u in ipairs(seat.field) do
            if not u.spent and G.kw(m, seat, u, "Blocker") then o.blockers[#o.blockers + 1] = u.uid end
        end
        o.call = seat.calledTurn ~= m.turn and o.eddies >= 1
        o.quick = {}
        for i, s in ipairs(seat.hand) do
            if card(s).type == "Program" and ((E().keywords or {})[s] or {}).Quick then o.quick[#o.quick + 1] = i end
        end
    elseif m.step == "steal" and m.attack.owner == index then
        o.steal = m.attack.steal
        o.stealable = {}
        for uid in pairs(m.attack.stealable or {}) do o.stealable[#o.stealable + 1] = uid end
    end
    if (m.step == "main" and m.active == index) or reacting then
        o.activate = {}
        for _, e in ipairs(G.activations(m, seat)) do
            local ok, cost = G.canActivate(m, seat, e, reacting)
            o.activate[#o.activate + 1] = { uid = e.holder.uid, card = e.slug, id = e.id, ok = ok == true, cost = ok and cost or nil,
                why = not ok and cost or nil, text = e.act.label }
        end
    end
    return o
end

-- A Quick Program from the hand during the React step.
function G.quick(m, index, handIndex)
    if busy(m) then return false, "Resolve the pending effect first." end
    if m.step ~= "react" or m.attack.defender ~= index then return false, "Not now." end
    local slug = m.seats[index].hand[handIndex]
    if not slug or card(slug).type ~= "Program" or not ((E().keywords or {})[slug] or {}).Quick then return false, "Only Quick Programs as a reaction." end
    return G.playFromHand(m, index, handIndex)
end

-- ---------------------------------------------------------------------------------------------
-- The house (a NEON DECK regular): plays simply and by the rules, for solo duels and tests.

function G.housePlay(m, index)
    local seat, rival = m.seats[index], other(m, m.seats[index])
    if m.prompt then
        if m.prompt.seat ~= index then return false, "waiting" end
        m.prompt.house = true
        return G.defaultAnswer(m)
    end
    if busy(m) then G.pump(m); return true end
    if m.step == "roll" and m.active == index then
        for _, k in ipairs(G.dieOrder) do
            if G.canRoll(seat, k) then return G.roll(m, index, k) end
        end
        return false, "no die"
    end
    if m.step == "react" and m.attack.defender == index then return G.resolve(m, index) end
    if m.step == "steal" and m.attack.owner == index then
        local gigs = {}
        for _, g in ipairs(rival.gigs) do if m.attack.stealable[g.uid] then gigs[#gigs + 1] = g end end
        table.sort(gigs, function(a, b) return a.value > b.value end)
        local ids = {}
        for i = 1, m.attack.steal do ids[i] = gigs[i].uid end
        return G.steal(m, index, ids)
    end
    if m.step ~= "main" or m.active ~= index then return false, "waiting" end
    if seat.soldTurn ~= m.turn and #seat.hand > 3 then
        local best, bestCost
        for i, s in ipairs(seat.hand) do
            local c = card(s)
            if c.sell and (c.cost or 0) > G.available(seat) and (not bestCost or (c.cost or 0) > bestCost) then best, bestCost = i, c.cost or 0 end
        end
        if best then return G.sell(m, index, best) end
    end
    local best, bestPower
    for i, s in ipairs(seat.hand) do
        local c = card(s)
        if c.type == "Unit" and G.costOf(m, seat, s, "hand") <= G.available(seat) and (not bestPower or (c.power or 0) > bestPower) then
            best, bestPower = i, c.power or 0
        end
    end
    if best then return G.play(m, index, best) end
    for _, u in ipairs(seat.field) do
        if G.canAttack(m, seat, u, "gigs") and G.power(m, u, seat) > 0 then return G.attack(m, index, u.uid, "gigs") end
        for _, r in ipairs(rival.field) do
            if G.canAttack(m, seat, u, r.uid) and G.power(m, u, seat) > G.power(m, r, rival) then return G.attack(m, index, u.uid, r.uid) end
        end
    end
    local ok, why = G.endTurn(m, index)
    if not ok then
        -- A Unit that must attack: send it at whatever it may attack.
        for _, u in ipairs(seat.field) do
            if G.canAttack(m, seat, u, "gigs") then return G.attack(m, index, u.uid, "gigs") end
            for _, r in ipairs(rival.field) do if G.canAttack(m, seat, u, r.uid) then return G.attack(m, index, u.uid, r.uid) end end
        end
    end
    return ok, why
end
