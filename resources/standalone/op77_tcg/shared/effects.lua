-- Every Cyberpunk TCG card's effect, scripted for shared/game.lua (texts: shared/cards.lua, the official rules
-- text of each card). A script is a table:
--   play(ctx) / call(ctx) / attack(ctx) / defeated(ctx)  the card's {Play} {Call} {Attack} {Defeated} effects
--   on = { event = function(ctx, data) }                 triggered effects while the card is in play (Gear: its holder)
--   activate = { cost, spend, quick, once, label, can, costMod, fn } or a list of them   activated effects
--   power(m, seat, unit) / aura(m, ownerSeat, holder, unit, unitSeat)                    continuous power
--   canAttack / grants / ...                                                             see TcgEffects below
-- ctx: m, seat (the controller), rival, card (this card), holder (the Unit / Legend it is on), program (a Program
-- being resolved: .dest = "trash" | "bottom" | "hand"). ctx methods (TcgEffectsCtx) ask the players through prompts.
local G = TcgGame
local card, label, other = G.card, G.label, G.other

TcgEffects = { cards = {} }
local E = TcgEffects
local S = E.cards

-- ---------------------------------------------------------------------------------------------
-- Keywords each card really has (reminder texts and other cards' texts mention more).

local KW = {}
local function kw(list, keyword) for _, s in ipairs(list) do KW[s] = KW[s] or {}; KW[s][keyword] = true end end
kw({ "corpo_security", "augmented_negotiators", "la_llorona_ghost_of_the_past", "lizzy_wizzy_delicate_weapon", "meredith_stout_stone_cold_corpo",
     "mox_inciters", "rita_wheeler_no_stupid_questions", "secondhand_bombus", "goro_takemura_hands_unclean", "mandibular_upgrade", "riot_shield" }, "Blocker")
kw({ "modded_kusanagi", "riding_nomad" }, "Adrenaline")
kw({ "adam_smasher_ender_of_legends", "goro_takemura_hands_unclean", "jackie_welles_mama_s_favorite", "rogue_amendiares_preem_solo",
     "royce_psycho_on_the_edge", "sasha_yakovleva_won_t_let_you_down", "v_corporate_exile", "v_streetkid" }, "Go Solo")
kw({ "cyberpsychosis", "detonate", "floor_it", "reboot_optics", "safety_override", "synapse_burnout", "take_control" }, "Quick")
E.keywords = KW

-- ---------------------------------------------------------------------------------------------
-- The context: what a script can do. Methods that ask a player yield (the game waits for the answer).

local C = {}
TcgEffectsCtx = C

local function thisTurn(ctx, t) t = t or {}; t.untilEnd = ctx.m.turn; return t end
local function untilNext(ctx, t) t = t or {}; t.untilStart = ctx.seat.index; return t end
C.thisTurn, C.untilNext = thisTurn, untilNext

-- A prompt to a player: options = { { label, card?, uid?, disabled? } }; returns the picked indices ({} = declined).
function C:ask(seat, title, options, min, max, optional)
    if #options == 0 then return {} end
    local allowed = 0
    for _, o in ipairs(options) do if not o.disabled then allowed = allowed + 1 end end
    if allowed == 0 then return {} end
    min = math.min(min or 1, allowed)
    local picks = coroutine.yield({ seat = seat.index, title = title, options = options, min = min, max = math.min(max or 1, #options),
        optional = optional and true or false, source = self.card })
    return picks or {}
end
function C:pickOne(seat, title, options, optional)
    local p = self:ask(seat, title, options, 1, 1, optional)
    return p[1]
end
function C:yes(title, seat)
    return self:pickOne(seat or self.seat, title, { { label = "Yes" }, { label = "No" } }) == 1
end
function C:choose(title, labels, seat)
    local opts = {}
    for i, l in ipairs(labels) do opts[i] = { label = l } end
    return self:pickOne(seat or self.seat, title, opts) or 1
end

-- Units on the field matching filter(u, owner); `who` "friendly" | "rival" | "any".
function C:units(who, filter)
    local out = {}
    for _, s in ipairs(self.m.seats) do
        local side = s == self.seat and "friendly" or "rival"
        if who == "any" or who == side then
            for _, u in ipairs(s.field) do if not filter or filter(u, s) then out[#out + 1] = { u = u, s = s } end end
        end
    end
    return out
end
local function unitOption(m, x) return { label = label(x.u.slug) .. " (" .. G.power(m, x.u, x.s) .. ")", card = x.u.slug, uid = x.u.uid } end
function C:pickUnit(who, title, filter, optional, chooser)
    local list = self:units(who, filter)
    local opts = {}
    for i, x in ipairs(list) do opts[i] = unitOption(self.m, x) end
    local k = self:pickOne(chooser or self.seat, title, opts, optional)
    if k then return list[k].u, list[k].s end
end
function C:pickHolder(seat, title, filter)
    local list = {}
    for _, h in ipairs(G.holders(seat)) do if not filter or filter(h) then list[#list + 1] = h end end
    local opts = {}
    for i, h in ipairs(list) do opts[i] = { label = label(h.slug), card = h.slug, uid = h.uid } end
    local k = self:pickOne(seat, title, opts, false)
    return k and list[k]
end
-- Gigs of `who` matching filter(g, owner).
function C:gigs(who, filter)
    local out = {}
    for _, s in ipairs(self.m.seats) do
        local side = s == self.seat and "friendly" or "rival"
        if who == "any" or who == side then
            for _, g in ipairs(s.gigs) do if not filter or filter(g, s) then out[#out + 1] = { g = g, s = s } end end
        end
    end
    return out
end
function C:pickGig(who, title, filter, optional, chooser)
    local list = self:gigs(who, filter)
    local opts = {}
    for i, x in ipairs(list) do
        opts[i] = { label = (x.s == self.seat and "Your " or (x.s.name .. "'s ")) .. x.g.kind .. " showing " .. x.g.value, gig = x.g.uid }
    end
    local k = self:pickOne(chooser or self.seat, title, opts, optional)
    if k then return list[k].g, list[k].s end
end
-- Cards of a list (a hand, the top of a deck, a trash) matching filter(slug); returns picked indices.
function C:pickCards(seat, title, list, filter, min, max, optional)
    local opts = {}
    for i, s in ipairs(list) do opts[i] = { label = label(s), card = s, disabled = filter and not filter(s) or nil } end
    return self:ask(seat, title, opts, min, max, optional)
end

-- Gig changes: "adjust" (up or down), "increase", "decrease" a Gig by up to n (it must actually change).
function C:changeGig(mode, n, who, exact)
    who = who or "any"
    local g, owner = self:pickGig(who, (mode == "adjust" and "Adjust" or (mode == "increase" and "Increase" or "Decrease")) ..
        " a Gig by " .. (exact and "" or "up to ") .. n, function(x)
            local sides = G.sides[x.kind]
            if mode ~= "decrease" and x.value < sides then return true end
            if mode ~= "increase" and x.value > 1 then return true end
        end, true)
    if not g then return nil end
    local opts, vals = {}, {}
    for d = -n, n do
        local v = g.value + d
        local okDir = d ~= 0 and (mode == "adjust" or (mode == "increase" and d > 0) or (mode == "decrease" and d < 0))
        if okDir and (not exact or math.abs(d) == n) and v >= 1 and v <= G.sides[g.kind] then
            vals[#vals + 1] = v
            opts[#opts + 1] = { label = g.kind .. ": " .. g.value .. " -> " .. v }
        end
    end
    local k = self:pickOne(self.seat, "New value", opts, false)
    if not k then return nil end
    G.setGig(self.m, g, vals[k])
    G.say(self.m, "%s sets a %s to %d.", self.seat.name, g.kind, g.value)
    if owner ~= self.seat then G.fire(self.m, "gigChangedBy", { by = self.seat, owner = owner, gig = g }) end
    return g, owner
end

function C:draw(n, seat) return G.draw(self.m, seat or self.seat, n) end
-- A player discards n cards of their choice (all of them if they hold fewer). Returns the discarded slugs.
function C:discard(seat, n, filter, optional)
    local hand = seat.hand
    local can = 0
    for _, s in ipairs(hand) do if not filter or filter(s) then can = can + 1 end end
    if can == 0 then return {} end
    local picks = self:pickCards(seat, "Discard " .. n, hand, filter, math.min(n, can), math.min(n, can), optional)
    table.sort(picks, function(a, b) return a > b end)
    local out = {}
    for _, i in ipairs(picks) do
        out[#out + 1] = table.remove(hand, i)
        seat.trash[#seat.trash + 1] = out[#out]
    end
    if #out > 0 then G.say(self.m, "%s discards %d.", seat.name, #out) end
    return out
end
function C:mill(n) return G.mill(self.m, self.seat, n) end
-- Take a card out of a zone list (trash, ...) by index.
local function take(list, slug)
    for i = #list, 1, -1 do if list[i] == slug then return table.remove(list, i) end end
end
C.take = take
function C:toHand(slug, from)
    if from then take(from, slug) end
    self.seat.hand[#self.seat.hand + 1] = slug
    G.say(self.m, "%s adds %s to their hand.", self.seat.name, label(slug))
end
-- Search the top n cards: returns them (removed from the deck); call :bottom(list) for the rest.
function C:top(n)
    local out = {}
    for _ = 1, n do
        local s = table.remove(self.seat.library)
        if not s then break end
        out[#out + 1] = s
    end
    return out
end
function C:bottom(list, shuffled)
    if shuffled then
        for i = #list, 2, -1 do local j = self.m.random(1, i); list[i], list[j] = list[j], list[i] end
    end
    for _, s in ipairs(list) do table.insert(self.seat.library, 1, s) end
end
function C:defeat(u, owner, cause) return G.defeat(self.m, owner, u, cause or "effect") end
function C:spend(h, owner) return G.spendCard(self.m, owner or self.seat, h) end
function C:ready(h) h.spent = false end
function C:readyEddies(n)
    local k = 0
    for _, e in ipairs(self.seat.eddies) do if k < n and e.spent then e.spent = false; k = k + 1 end end
end
function C:mod(target, t) G.addMod(self.m, target, t) end
function C:powerThisTurn(u, p) G.addMod(self.m, u, thisTurn(self, { power = p })) end
function C:faceUpLegends(seat)
    local n = 0
    for _, l in ipairs((seat or self.seat).legends) do if l.faceUp and not l.removed then n = n + 1 end end
    return n
end
-- Call a face-down Legend for free (still once per turn).
function C:callFree(optional)
    if self.seat.calledTurn == self.m.turn then return false end
    local opts, idx = {}, {}
    for i, l in ipairs(self.seat.legends) do
        if not l.faceUp and not l.onField and not l.removed then opts[#opts + 1] = { label = "Face-down Legend " .. i }; idx[#idx + 1] = i end
    end
    local k = self:pickOne(self.seat, "Call a Legend for free", opts, optional ~= false)
    if not k then return false end
    return G.callLegend(self.m, self.seat, idx[k], true)
end
-- Play a card for free from a zone list (hand / trash); opts: bottom (a Program bottom-decked after), holderFilter.
function C:playFree(slug, from, opts)
    if from then take(from, slug) end
    opts = opts or {}
    G.putIntoPlay(self.m, self.seat, slug, { bottom = opts.bottom, filter = opts.holderFilter })
end
function C:gigWith(seat, pred)
    for _, g in ipairs(seat.gigs) do if pred(g) then return g end end
end
function C:hasGigValue(seat, v)
    for _, g in ipairs(seat.gigs) do if g.value == v then return true end end
    return false
end
function C:flag(seat, t) seat.flags[#seat.flags + 1] = t end
-- Remove a Gear from its holder (to the trash).
function C:defeatGear(holder, owner, slug)
    for i, g in ipairs(holder.gear or {}) do
        if g == slug then
            table.remove(holder.gear, i)
            owner.trash[#owner.trash + 1] = g
            G.say(self.m, "%s is defeated.", label(g))
            return true
        end
    end
end
-- Every Gear in play: { holder, owner, slug }
function C:gears(who)
    local out = {}
    for _, s in ipairs(self.m.seats) do
        local side = s == self.seat and "friendly" or "rival"
        if who == "any" or who == side then
            for _, h in ipairs(G.holders(s)) do for _, g in ipairs(h.gear or {}) do out[#out + 1] = { holder = h, owner = s, slug = g } end end
        end
    end
    return out
end
function C:pickGear(who, title, filter, optional)
    local list = {}
    for _, x in ipairs(self:gears(who)) do if not filter or filter(x) then list[#list + 1] = x end end
    local opts = {}
    for i, x in ipairs(list) do opts[i] = { label = label(x.slug) .. " on " .. label(x.holder.slug), card = x.slug } end
    local k = self:pickOne(self.seat, title, opts, optional)
    return k and list[k]
end
function C:isFriendly(seat) return seat == self.seat end
function C:myTurn() return self.m.active == self.seat.index end
function C:first(key)
    self.seat.firsts = self.seat.firsts or {}
    if self.seat.firsts[key] then return false end
    self.seat.firsts[key] = true
    return true
end

-- ---------------------------------------------------------------------------------------------
-- Continuous effects the engine asks about

local function each(m, fn)
    for _, s in ipairs(m.seats) do for _, c in ipairs(G.inPlay(m, s)) do fn(c, s) end end
end
local function attacking(m, u) return m.attack and m.attack.attacker == u.uid and (m.step == "resolving" or m.step == "react" or m.step == "attacking" or m.step == "steal") end
local function fighting(m, u) return m.fighting and m.fighting[u.uid] end

function E.staticPower(m, seat, u)
    local p = 0
    local own = S[u.slug]
    if own and own.power then p = p + own.power(m, seat, u) end
    each(m, function(c, s)
        local sc = S[c.slug]
        if sc and sc.aura then p = p + (sc.aura(m, s, c.holder, u, seat) or 0) end
    end)
    for _, mod in ipairs(u.mods or {}) do
        if mod.fightBonus and fighting(m, u) then p = p + mod.fightBonus(m, seat, u) end
    end
    return p
end

function E.keywordStatic(m, seat, u, keyword)
    for _, g in ipairs(u.gear or {}) do
        local sc = S[g]
        if sc and sc.grants and sc.grants(m, seat, u, keyword) then return true end
    end
    return false
end

-- Attack rules: returns allowLag, forbidReason.
function E.attackRule(m, seat, u, target)
    local allowLag, forbid = false, nil
    local sc = S[u.slug] or {}
    if sc.canAttack then
        local a, f = sc.canAttack(m, seat, u, target)
        allowLag = allowLag or a
        forbid = forbid or f
    end
    if G.unitFlag(u, "noAttack") then forbid = forbid or "That Unit can't attack until a later turn." end
    if G.unitFlag(u, "freshUnits") and target ~= "gigs" then allowLag = true end
    -- Maxtac Suppression Team (a rival's): Units can't attack the turn they're played.
    local rival = other(m, seat)
    for _, x in ipairs(rival.field) do
        if x.slug == "maxtac_suppression_team" and u.playedTurn == m.turn then forbid = forbid or "Rival Maxtac Suppression Team: not the turn it's played." end
    end
    return allowLag, forbid
end

function E.canAttackReady(m, seat, u, d)
    if G.unitFlag(u, "attackReady") then return true end
    local sc = S[u.slug] or {}
    return sc.attackReady and sc.attackReady(m, seat, u, d) or false
end

function E.unblockable(m, seat, u)
    local sc = S[u.slug] or {}
    return sc.unblockable and sc.unblockable(m, seat, u) or false
end

function E.stealCount(m, seat, u)
    local d = 0
    for _, mod in ipairs(u.mods or {}) do d = d + (mod.stealDelta or 0) end
    return d
end

function E.stealable(m, atkSeat, u, defSeat, g)
    for _, f in ipairs(defSeat.flags or {}) do
        if f.flag == "chromeFang" and g.value > G.power(m, u, atkSeat) then return false end
        if f.flag == "westbrook" and u.legend and g.value < G.power(m, u, atkSeat) then return false end
    end
    return true
end

-- "Would be stolen": Alt Cunningham, Mother of Daemons (its controller may discard a card with cost = the value).
function E.preventSteal(m, atkSeat, defSeat, g, attacker)
    if not attacker then return false end
    local alt = false
    for _, u in ipairs(defSeat.field) do if u.slug == "alt_cunningham_mother_of_daemons" then alt = true end end
    if not alt then return false end
    for i, s in ipairs(defSeat.hand) do
        if card(s).cost == g.value then
            table.remove(defSeat.hand, i)
            defSeat.trash[#defSeat.trash + 1] = s
            G.say(m, "%s discards %s: the Gig isn't stolen (Alt Cunningham).", defSeat.name, label(s))
            return true
        end
    end
    return false
end

-- "Would be defeated" replacements: Deadman Transmitter, Muamar's Call, Jackie Welles (Mama's Favorite).
function E.replaceDefeat(m, seat, u, cause)
    for i, g in ipairs(u.gear or {}) do
        if g == "deadman_transmitter" then
            table.remove(u.gear, i)
            seat.trash[#seat.trash + 1] = g
            G.say(m, "Deadman Transmitter is defeated instead of %s.", label(u.slug))
            return true
        end
    end
    if cause == "fight" and G.unitFlag(u, "noFightDefeat") then
        G.say(m, "%s can't be defeated in a fight this turn.", label(u.slug))
        return true
    end
    -- Jackie Welles, Mama's Favorite: pay 1 €$ to defeat (remove) her instead of another friendly Unit.
    if u.slug ~= "jackie_welles_mama_s_favorite" and G.available(seat) >= 1 then
        local jackie, jl
        for _, x in ipairs(seat.field) do if x.slug == "jackie_welles_mama_s_favorite" then jackie = x end end
        for _, l in ipairs(seat.legends) do
            if l.slug == "jackie_welles_mama_s_favorite" and l.faceUp and not l.onField and not l.removed then jl = l end
        end
        if (jackie or jl) and G.power(m, u, seat) >= 5 then
            G.pay(m, seat, 1)
            if jackie then G.removeUnit(m, seat, jackie, "removed") else jl.removed = true end
            G.say(m, "Jackie Welles is removed from the game instead of %s.", label(u.slug))
            return true
        end
    end
    return false
end

function E.fightOutcome(m, sa, ua, sb, ub, loseA, loseB)
    -- Johnny Silverhand, Never Stop Fighting: wins all fights against CORPO Units.
    if ua.slug == "johnny_silverhand_never_stop_fighting" and G.hasTag(ub.slug, "Corpo") then loseA, loseB = false, true end
    if ub.slug == "johnny_silverhand_never_stop_fighting" and G.hasTag(ua.slug, "Corpo") then loseA, loseB = true, false end
    -- Reboot Optics: the next time a rival Unit fights this turn, it doesn't defeat the opposing friendly Unit.
    local function reboot(defender, mineLoses)
        local f = G.flag(defender, "rebootOptics")
        if f and mineLoses then
            for i, x in ipairs(defender.flags) do if x == f then table.remove(defender.flags, i) break end end
            return true
        end
    end
    if reboot(sa, loseA) then loseA = false end
    if reboot(sb, loseB) then loseB = false end
    -- Safety Override: the next time a friendly Unit loses a fight this turn, defeat the opposing rival Unit.
    local function override(s, loses)
        local f = G.flag(s, "safetyOverride")
        if f and loses then
            for i, x in ipairs(s.flags) do if x == f then table.remove(s.flags, i) break end end
            return true
        end
    end
    if override(sa, loseA) then loseB = true end
    if override(sb, loseB) then loseA = true end
    -- Maelstrom Zealots: when it loses a fight, defeat the opposing rival Unit.
    if loseA and ua.slug == "maelstrom_zealots" then loseB = true end
    if loseB and ub.slug == "maelstrom_zealots" then loseA = true end
    return loseA, loseB
end

-- Cost changes. how: "hand" | "solo" | "legend" | "free"
function E.costMod(m, seat, slug, how)
    local d = 0
    local rival = other(m, seat)
    local c = card(slug)
    if how == "solo" then
        for _, x in ipairs(G.inPlay(m, rival)) do if x.slug == "riot_shield" then d = d + 2 end end
        if G.flag(seat, "nocturneSolo") then d = d - 2 end
    end
    local sc = S[slug] or {}
    if sc.cost then d = d + sc.cost(m, seat) end
    if c.type == "Program" and G.flag(seat, "altNext") then
        local mins = 0
        for _, g in ipairs(seat.gigs) do if G.isMin(g) then mins = mins + 1 end end
        d = d - mins
    end
    if c.type == "Gear" and G.hasTag(slug, "Cyberware") then
        for _, u in ipairs(seat.field) do
            if u.slug == "viktor_vektor_drop_your_illusions" and not (seat.firsts or {}).cyberware then d = d - 3 break end
        end
    end
    return d
end

-- Panam Palmer, Strength Through Family: during your turn you may Call a Legend for free.
function E.freeCall(m, seat)
    for _, u in ipairs(seat.field) do if u.slug == "panam_palmer_strength_through_family" then return true end end
    return false
end

-- "Must attack next turn if it can" (Mox Inciters, Evelyn Parker).
function E.mustAttack(m, seat)
    for _, u in ipairs(seat.field) do
        if G.unitFlag(u, "mustAttack") and u.attacked ~= m.turn and G.canAttack(m, seat, u) then
            local any = G.canAttack(m, seat, u, "gigs")
            for _, r in ipairs(other(m, seat).field) do any = any or G.canAttack(m, seat, u, r.uid) end
            if any then return u end
        end
    end
end

-- ---------------------------------------------------------------------------------------------
-- Helpers for the scripts

local function blue(slug) return card(slug).color == "Blue" end
local function isType(slug, t) return card(slug).type == t end
local function costOf(slug) return card(slug).cost or 0 end
local function friendlyRival(ctx, s) return s ~= ctx.seat end
local function pickRivalUnit(ctx, title, filter, optional)
    return ctx:pickUnit("rival", title, filter, optional)
end
local function defeatRival(ctx, title, filter, optional)
    local u, s = pickRivalUnit(ctx, title, filter, optional)
    if u then ctx:defeat(u, s) end
    return u
end
local function chooseOrDraw(ctx, labels, first)
    local k = ctx:choose("Choose one effect", labels)
    if k == 1 then first() else ctx:draw(1) end
end
local function eachGig(seat, pred) local n = 0 for _, g in ipairs(seat.gigs) do if pred(g) then n = n + 1 end end return n end
local function holderOwner(ctx) local _, s = G.findHolder(ctx.m, ctx.holder.uid); return s or ctx.seat end
-- Search the top n: pick up to `max` matching cards into the hand, bottom-deck the rest.
local function searchTop(ctx, n, filter, max, min, shuffled, title)
    local top = ctx:top(n)
    if #top == 0 then return {} end
    local picks = ctx:pickCards(ctx.seat, title or "Add to your hand", top, filter, min or 0, max, true)
    local keep, got = {}, {}
    local picked = {}
    for _, i in ipairs(picks) do picked[i] = true end
    for i, s in ipairs(top) do if picked[i] then got[#got + 1] = s else keep[#keep + 1] = s end end
    for _, s in ipairs(got) do ctx:toHand(s) end
    ctx:bottom(keep, shuffled)
    return got
end
-- Trash n, then add one matching card from among them to the hand.
local function trashThenAdd(ctx, n, filter, title)
    local milled = ctx:mill(n)
    local list = {}
    for _, s in ipairs(milled) do if filter(s) then list[#list + 1] = s end end
    if #list == 0 then return nil end
    local k = ctx:pickCards(ctx.seat, title, list, nil, 1, 1, false)[1]
    if k then ctx:toHand(list[k], ctx.seat.trash); return list[k] end
end

-- ---------------------------------------------------------------------------------------------
-- GEAR (the bottom text is the holder's: "this Unit" = the Unit or Legend it equips)

local function holderSpent(ctx, d) return d.holder == ctx.holder end

S.adrenaline_converter = { grants = function(m, seat, u, keyword)
    return keyword == "Adrenaline" and #other(m, seat).gigs >= #seat.gigs + 2
end }
S.arasaka_emergency_radioport = { on = { spent = function(ctx, d)
    if not holderSpent(ctx, d) or ctx.seat.calledTurn == ctx.m.turn then return end
    local opts, idx = {}, {}
    for i, l in ipairs(ctx.seat.legends) do
        if not l.faceUp and not l.onField and not l.removed then opts[#opts + 1] = { label = "Look at face-down Legend " .. i }; idx[#idx + 1] = i end
    end
    local k = ctx:pickOne(ctx.seat, "Arasaka Emergency Radioport: look at a face-down Legend?", opts, true)
    if not k then return end
    local l = ctx.seat.legends[idx[k]]
    if (G.hasTag(l.slug, "Arasaka") or (KW[l.slug] or {})["Go Solo"]) and ctx:yes("It is " .. label(l.slug) .. ". Call it for free?") then
        G.callLegend(ctx.m, ctx.seat, idx[k], true)
    end
end } }
S.deadman_transmitter = {}   -- E.replaceDefeat
S.dying_night_v_s_pistol = {
    attack = function(ctx) ctx:changeGig("decrease", 2, "any") end,
    on = { endTurn = function(ctx, d)
        if d.seat == ctx.seat and card(ctx.holder.slug).name == "V" then ctx:readyEddies(2) end
    end },
}
S.gorilla_arms = { on = { stole = function(ctx, d)
    if d.unit ~= ctx.holder or not ctx:first("gorilla:" .. ctx.holder.uid) then return end
    local g, s = ctx:pickGig("rival", "Gorilla Arms: steal a rival Gig with a value no friendly Gig shows", function(x)
        return not ctx:hasGigValue(ctx.seat, x.value)
    end, false)
    if g then G.stealGig(ctx.m, ctx.seat, s, g, nil) end
end } }
S.kiroshi_optics = { attack = function(ctx)
    local opts = {}
    for i, l in ipairs(ctx.seat.legends) do
        if not l.faceUp and not l.removed and not l.onField then opts[#opts + 1] = { label = "Legend " .. i .. ": " .. label(l.slug), card = l.slug } end
    end
    ctx:pickOne(ctx.seat, "Kiroshi Optics: your face-down Legends (only you see them)", opts, true)
end }
S.mandibular_upgrade = {}
S.mantis_blades = {}
S.netwatch_netdriver = { on = { spent = function(ctx, d) if holderSpent(ctx, d) then ctx:draw(1) end end } }
S.overwatch_panam_s_gift = { activate = { cost = 1, spend = true, quick = true, label = "1 €$, spend: discard 1, defeat a spent rival Unit with cost ≤ its cost",
    can = function(m, seat) return #seat.hand > 0 end,
    fn = function(ctx)
        local d = ctx:discard(ctx.seat, 1)
        if not d[1] then return end
        defeatRival(ctx, "Defeat a spent rival Unit with cost " .. costOf(d[1]) .. " or less", function(u) return u.spent and costOf(u.slug) <= costOf(d[1]) end, false)
    end } }
S.riot_shield = {}
S.sandevistan = { on = { endTurn = function(ctx, d) if d.seat == ctx.seat then ctx:ready(ctx.holder) end end } }
S.satori_sword_of_saburo = { on = { fought = function(ctx, d)
    if (d.ua == ctx.holder and d.winA) or (d.ub == ctx.holder and d.winB) then ctx:draw(1) end
end } }
S.tetratronic_rippler = { on = { spent = function(ctx, d)
    if not holderSpent(ctx, d) then return end
    local top = ctx.seat.library[#ctx.seat.library]
    if top and ctx:yes("Tetratronic Rippler: the top card is " .. label(top) .. ". Trash it?") then ctx:mill(1) end
end } }
S.the_relic_experimental_biochip = { defeated = function(ctx)
    local list = {}
    for _, s in ipairs(ctx.seat.trash) do if isType(s, "Unit") and s ~= ctx.holder.slug and costOf(s) <= 9 then list[#list + 1] = s end end
    local k = ctx:pickCards(ctx.seat, "The Relic: play a Unit from your trash for free", list, nil, 1, 1, true)[1]
    if k then ctx:playFree(list[k], ctx.seat.trash) end
    if not ctx.holder.legend and take(ctx.seat.trash, ctx.holder.slug) then table.insert(ctx.seat.library, 1, ctx.holder.slug) end
end }
S.zetatech_berserk = { cost = function(m, seat)
    local n = 0
    for _, l in ipairs(seat.legends) do if l.faceUp and not l.removed then n = n + 1 end end
    return -n
end }
S.zetatech_faceplate = { on = { spent = function(ctx, d)
    if not holderSpent(ctx, d) then return end
    ctx:changeGig("adjust", 1, "any")
    if G.distinctValues(ctx.seat) >= 3 then ctx:draw(1) end
end } }

-- ---------------------------------------------------------------------------------------------
-- LEGENDS

S.adam_smasher_ender_of_legends = { play = function(ctx) defeatRival(ctx, "Defeat a rival Unit", nil, false) end }
S.alt_cunningham_soulkiller_architect = { activate = {
    { spend = true, label = "Spend: your next Program this turn costs -1 €$ per friendly min Gig",
      fn = function(ctx) ctx:flag(ctx.seat, thisTurn(ctx, { flag = "altNext" })) end },
    { cost = 1, spend = true, label = "1 €$, spend: play a Program from your trash (pay its cost), then bottom-deck it",
      can = function(m, seat) for _, s in ipairs(seat.trash) do if isType(s, "Program") then return true end end end,
      fn = function(ctx)
          local list = {}
          for _, s in ipairs(ctx.seat.trash) do if isType(s, "Program") and G.costOf(ctx.m, ctx.seat, s, "hand") <= G.available(ctx.seat) then list[#list + 1] = s end end
          local k = ctx:pickCards(ctx.seat, "Play a Program from your trash", list, nil, 1, 1, true)[1]
          if not k then return end
          G.pay(ctx.m, ctx.seat, G.costOf(ctx.m, ctx.seat, list[k], "hand"))
          ctx:playFree(list[k], ctx.seat.trash, { bottom = true })
      end },
} }
S.dexter_deshawn_off_the_grid = {
    call = function(ctx)
        chooseOrDraw(ctx, { "Give a friendly Unit +2 power this turn", "Draw 1" }, function()
            local u = ctx:pickUnit("friendly", "+2 power this turn", nil, false)
            if u then ctx:powerThisTurn(u, 2) end
        end)
    end,
    activate = { spend = true, label = "Spend: increase a Gig by up to 2", fn = function(ctx) ctx:changeGig("increase", 2, "any") end },
}
S.dum_dum_maelstrom_triggerman = {
    call = function(ctx)
        local g = ctx:pickGear("friendly", "You may defeat a friendly Gear (then draw 2)", nil, true)
        if g and ctx:defeatGear(g.holder, g.owner, g.slug) then ctx:draw(2) else ctx:draw(1) end
    end,
    activate = { cost = 1, spend = true, quick = true, label = "1 €$, spend: a friendly Unit gets +1 power per equipped Gear this turn",
        fn = function(ctx)
            local u = ctx:pickUnit("friendly", "+1 power per equipped Gear", nil, false)
            if u then ctx:powerThisTurn(u, #(u.gear or {})) end
        end },
}
S.evelyn_parker_beautiful_enigma = {
    on = { stole = function(ctx, d)
        if d.seat == ctx.seat and d.unit and (G.hasTag(d.unit.slug, "Corpo") or G.hasTag(d.unit.slug, "Ganger"))
            and ctx:first("evelyn:" .. tostring(ctx.m.attack and ctx.m.attack.attacker) .. ":" .. ctx.m.turn) then ctx:readyEddies(1) end
    end },
    activate = { cost = 1, spend = true, label = "1 €$, spend: a rival Unit must attack next turn if it can",
        fn = function(ctx)
            local u = pickRivalUnit(ctx, "This rival Unit must attack next turn", nil, false)
            if u then ctx:mod(u, { flag = "mustAttack", untilEnd = ctx.m.turn + 1 }) end
        end },
}
S.goro_takemura_hands_unclean = {}
S.goro_takemura_vengeful_bodyguard = {
    activate = { cost = 1, spend = true, quick = true, label = "1 €$, spend: a friendly Unit (cost 4 or less) gets Blocker this turn",
        fn = function(ctx)
            local u = ctx:pickUnit("friendly", "Gets Blocker this turn", function(x) return costOf(x.slug) <= 4 end, false)
            if not u then return end
            ctx:mod(u, thisTurn(ctx, { kw = { Blocker = true }, power = G.valuePairs(ctx.seat) > 0 and 1 or 0 }))
        end },
    on = { blocked = function(ctx, d)
        if d.seat ~= ctx.seat or #ctx.seat.hand == 0 then return end
        if #ctx:discard(ctx.seat, 1, nil, true) > 0 then ctx:draw(1) end
    end },
}
S.hanako_arasaka_daughter_of_the_emperor = {
    activate = { spend = true, label = "Spend: swap a friendly Gig with a rival Gig",
        can = function(m, seat) return #seat.gigs > 0 and #other(m, seat).gigs > 0 end,
        fn = function(ctx)
            local a = ctx:pickGig("friendly", "Your Gig to swap", nil, false)
            local b, bs = ctx:pickGig("rival", "Their Gig to swap", nil, false)
            if not a or not b then return end
            for i, g in ipairs(ctx.seat.gigs) do if g == a then ctx.seat.gigs[i] = b end end
            for i, g in ipairs(bs.gigs) do if g == b then bs.gigs[i] = a end end
            G.say(ctx.m, "%s swaps a %s (%d) with a %s (%d).", ctx.seat.name, a.kind, a.value, b.kind, b.value)
            G.fire(ctx.m, "gigChangedBy", { by = ctx.seat, owner = bs, gig = b })
        end },
    on = { startTurn = function(ctx, d) if d.seat == ctx.seat then ctx:draw(G.valuePairs(ctx.seat)) end end },
}
S.jackie_welles_mama_s_favorite = {}   -- E.replaceDefeat
S.jackie_welles_pour_one_out_for_me = { on = { played = function(ctx, d)
    if d.seat ~= ctx.seat or not blue(d.slug) or not (isType(d.slug, "Unit") or isType(d.slug, "Gear")) then return end
    if not ctx:first("pourOneOut") then return end
    local g = ctx:changeGig("decrease", 2, "friendly")
    if g and G.isMin(g) then ctx:draw(1) end
end } }
S.johnny_silverhand_rocking_renegade = { activate = { cost = 2, spend = true,
    label = "2 €$, spend: a friendly Unit can attack spent rival Units the turn it's played (ROCKER: +2 power)",
    costMod = function(m, seat) return -eachGig(seat, function(g) return g.value >= 8 end) end,
    fn = function(ctx)
        local u = ctx:pickUnit("friendly", "This Unit can attack spent rival Units this turn", nil, false)
        if not u then return end
        ctx:mod(u, thisTurn(ctx, { flag = "freshUnits", power = G.hasTag(u.slug, "Rocker") and 2 or 0 }))
    end } }
S.judy_alvarez_braindance_maestro = {
    on = { played = function(ctx, d)
        if d.seat == ctx.seat and isType(d.slug, "Program") and G.hasTag(d.slug, "Braindance") then
            local u = ctx:pickUnit("friendly", "+1 power this turn", nil, false)
            if u then ctx:powerThisTurn(u, 1) end
        end
    end },
    activate = { spend = true, label = "Spend: trash the top card; a Program may go to your hand",
        fn = function(ctx)
            local s = ctx:mill(1)[1]
            if s and isType(s, "Program") and ctx:yes("Add " .. label(s) .. " to your hand?") then ctx:toHand(s, ctx.seat.trash) end
        end },
}
S.kerry_eurodyne_axe_attitude_audience = { on = { rolled = function(ctx, d)
    if d.seat ~= ctx.seat then return end
    local g = d.gig
    if d.fromFixer and ctx:yes("Kerry Eurodyne: reroll the " .. g.kind .. " (" .. g.value .. ")?") then
        g.value = ctx.m.random(1, G.sides[g.kind])
        G.say(ctx.m, "%s rerolls the %s: %d.", ctx.seat.name, g.kind, g.value)
        G.event(ctx.m, { kind = "roll", seat = ctx.seat.index, die = g.kind, value = g.value, uid = g.uid })
    end
    if G.isMin(g) or G.isMax(g) then ctx:draw(g.kind == "d20" and 3 or 1) end
end } }
S.muamar_reyes_el_capitan = {
    call = function(ctx)
        chooseOrDraw(ctx, { "A friendly Unit can't be defeated in a fight this turn", "Draw 1" }, function()
            local u = ctx:pickUnit("friendly", "Can't be defeated in a fight this turn", nil, false)
            if u then ctx:mod(u, thisTurn(ctx, { flag = "noFightDefeat" })) end
        end)
    end,
    activate = { spend = true, label = "Spend: adjust a Gig by 1", fn = function(ctx) ctx:changeGig("adjust", 1, "any", true) end },
}
S.padre_man_of_the_cross = {
    call = function(ctx)
        chooseOrDraw(ctx, { "Spend a rival Unit", "Draw 1" }, function()
            local u, s = pickRivalUnit(ctx, "Spend a rival Unit", function(x) return not x.spent end, false)
            if u then ctx:spend(u, s) end
        end)
    end,
    activate = { spend = true, label = "Spend: set a player's Gig to the value of another player's Gig",
        can = function(m, seat) return #seat.gigs > 0 and #other(m, seat).gigs > 0 end,
        fn = function(ctx)
            local a, as = ctx:pickGig("any", "The Gig to set", nil, false)
            if not a then return end
            local b = ctx:pickGig("any", "Set it to the value of", function(x, s) return s ~= as and x.value <= G.sides[a.kind] end, false)
            if b then G.setGig(ctx.m, a, b.value); G.say(ctx.m, "A %s is set to %d.", a.kind, a.value) end
        end },
}
S.panam_palmer_nomad_cavalry = {
    activate = { cost = 2, spend = true, label = "2 €$, spend: move a Gear from Panam to an unequipped friendly Unit and ready it",
        can = function(m, seat, h) return #(h.gear or {}) > 0 end,
        fn = function(ctx)
            local h = ctx.holder
            local k = ctx:pickCards(ctx.seat, "The Gear to move", h.gear, nil, 1, 1, false)[1]
            if not k then return end
            local u = ctx:pickUnit("friendly", "To this unequipped Unit", function(x) return #(x.gear or {}) == 0 end, false)
            if not u then return end
            local g = table.remove(h.gear, k)
            u.gear[#u.gear + 1] = g
            u.spent = false
            G.say(ctx.m, "%s moves %s to %s.", ctx.seat.name, label(g), label(u.slug))
        end },
    on = { endTurn = function(ctx, d)
        if d.seat ~= ctx.seat then return end
        local eq = {}
        for _, h in ipairs(G.holders(ctx.seat)) do if #(h.gear or {}) > 0 then eq[#eq + 1] = h end end
        if #eq >= 5 then for _, h in ipairs(eq) do h.spent = false end end
    end },
}
S.rebecca_having_a_moment = {}
S.river_ward_detective_on_the_hunt = {
    activate = { spend = true, quick = true, label = "Spend: play a Gear (cost 2 or less) from your hand for free",
        can = function(m, seat) for _, s in ipairs(seat.hand) do if isType(s, "Gear") and costOf(s) <= 2 then return true end end end,
        fn = function(ctx)
            local list = {}
            for _, s in ipairs(ctx.seat.hand) do if isType(s, "Gear") and costOf(s) <= 2 then list[#list + 1] = s end end
            local k = ctx:pickCards(ctx.seat, "Play a Gear for free", list, nil, 1, 1, true)[1]
            if k then ctx:playFree(list[k], ctx.seat.hand) end
        end },
    on = { defeated = function(ctx, d)
        if d.seat ~= ctx.seat or #(d.unit.gear or {}) == 0 then return end
        local top = ctx:top(2)
        if #top == 0 then return end
        local k = ctx:pickCards(ctx.seat, "River Ward: trash one of the top 2", top, nil, 1, 1, false)[1] or 1
        for i, s in ipairs(top) do
            if i == k then ctx.seat.trash[#ctx.seat.trash + 1] = s else ctx.seat.library[#ctx.seat.library + 1] = s end
        end
    end },
}
S.rogue_amendiares_preem_solo = { on = { stole = function(ctx, d)
    if d.seat ~= ctx.seat or not d.unit or not d.unit.legend then return end
    if d.gig.value % 2 == 0 then ctx:draw(1) else ctx:discard(ctx.rival, 1) end
end } }
S.royce_psycho_on_the_edge = { power = function(m, seat, u)
    return m.active == seat.index and 2 * #(u.gear or {}) or 0
end }
S.saburo_arasaka_stubborn_patriarch = { aura = function(m, owner, holder, u, useat)
    return (useat == owner and G.hasTag(u.slug, "Arasaka") and attacking(m, u)) and 1 or 0
end }
S.sasha_yakovleva_won_t_let_you_down = {
    attack = function(ctx)
        local s = ctx:top(1)[1]
        if not s then return end
        G.say(ctx.m, "Sasha reveals %s.", label(s))
        ctx:toHand(s)
        ctx:powerThisTurn(ctx.holder, costOf(s))
    end,
    defeated = function(ctx) ctx:discard(ctx.rival, 1) end,
}
S.v_corporate_exile = {}
S.v_streetkid = { call = function(ctx)
    ctx:mill(3)
    local list = {}
    for _, s in ipairs(ctx.seat.trash) do if isType(s, "Program") and G.hasTag(s, "Braindance") then list[#list + 1] = s end end
    local k = ctx:pickCards(ctx.seat, "Add a BRAINDANCE Program from your trash", list, nil, 1, 1, false)[1]
    if k then ctx:toHand(list[k], ctx.seat.trash) end
end }
S.viktor_vektor_sit_down_and_relax = { call = function(ctx)
    searchTop(ctx, 5, function(s) return isType(s, "Gear") and costOf(s) <= 2 end, 2, 0, true, "Up to 2 Gears (cost 2 or less)")
end }
S.wakako_okada_peace_and_harmony = {
    call = function(ctx)
        chooseOrDraw(ctx, { "Give a rival Unit -2 power this turn", "Draw 1" }, function()
            local u = pickRivalUnit(ctx, "-2 power this turn", nil, false)
            if u then ctx:powerThisTurn(u, -2) end
        end)
    end,
    activate = { spend = true, label = "Spend: decrease a Gig by up to 2", fn = function(ctx) ctx:changeGig("decrease", 2, "any") end },
}
S.yorinobu_arasaka_embracing_destruction = { on = { attacks = function(ctx, d)
    if d.seat ~= ctx.seat or not G.hasTag(d.unit.slug, "Arasaka") or not ctx:first("yorinobu") then return end
    ctx:draw(1)
    local cred = G.streetCred(ctx.seat)
    if cred == nil or cred < 20 then ctx:discard(ctx.seat, 1) end
end } }

-- ---------------------------------------------------------------------------------------------
-- PROGRAMS (ctx.program.dest: where the Program goes after it resolves)

S.afterparty_at_lizzie_s = { play = function(ctx)
    ctx:changeGig("adjust", 1, "any")
    if G.distinctValues(ctx.seat) >= 2 then ctx:draw(1) end
end }
S.all_is_lost = { play = function(ctx) trashThenAdd(ctx, 3, function(s) return isType(s, "Unit") end, "Add a Unit to your hand") end }
S.appetite_for_destruction = { play = function(ctx) ctx:flag(ctx.seat, thisTurn(ctx, { flag = "appetite" })) end }
S.bonnie_and_clyde = { play = function(ctx)
    local two = #ctx.rival.gigs >= #ctx.seat.gigs + 2
    defeatRival(ctx, "Defeat a rival Unit with power 4 or less", function(u, s) return G.power(ctx.m, u, s) <= 4 end, false)
    if two then defeatRival(ctx, "You may defeat another (power 4 or less)", function(u, s) return G.power(ctx.m, u, s) <= 4 end, true) end
end }
S.bootleg_black_sapphire_show = { play = function(ctx)
    local s = table.remove(ctx.seat.library)
    if s then
        ctx.seat.eddies[#ctx.seat.eddies + 1] = { uid = G.nextId(ctx.m), slug = s, spent = false }
        ctx.seat.soldTurn = ctx.m.turn
        G.say(ctx.m, "%s sells the top card of their deck.", ctx.seat.name)
    end
    if ctx:gigWith(ctx.seat, function(g) return g.value % 2 == 0 end) and ctx:gigWith(ctx.seat, function(g) return g.value % 2 == 1 end) then ctx:draw(2) end
end }
S.carnage_at_the_colosseum = {
    cost = function(m, seat) return -eachGig(seat, function(g) return g.value >= 8 end) end,
    play = function(ctx)
        local best = -1
        for _, u in ipairs(ctx.seat.field) do best = math.max(best, G.power(ctx.m, u, ctx.seat)) end
        defeatRival(ctx, "Defeat a rival Unit with less power than your strongest Unit", function(u, s) return G.power(ctx.m, u, s) < best end, false)
    end,
}
S.chrome_reverie = { play = function(ctx)
    local u = pickRivalUnit(ctx, "This rival Unit can't attack until your next turn", nil, false)
    if u then ctx:mod(u, untilNext(ctx, { flag = "noAttack" })) end
    if ctx:gigWith(ctx.seat, G.isMin) then ctx:callFree(true) end
end }
S.corporate_surveillance = { play = function(ctx)
    local u, s = pickRivalUnit(ctx, "Spend a rival Unit with cost 4 or less", function(x) return not x.spent and costOf(x.slug) <= 4 end, false)
    if u then ctx:spend(u, s) end
end }
S.cyberpsychosis = { play = function(ctx)
    local u = ctx:pickUnit("any", "An equipped Unit gets +3 power per Gear this turn", function(x) return #(x.gear or {}) > 0 end, false)
    if not u then return end
    ctx:mod(u, thisTurn(ctx, { power = 3 * #u.gear, flag = "psycho" }))
end }
S.detonate = { play = function(ctx)
    local g = ctx:pickGear("rival", "Defeat a rival Gear with power 2 or less", function(x) return (card(x.slug).power or 0) <= 2 end, false)
    if g then ctx:defeatGear(g.holder, g.owner, g.slug) end
end }
S.don_t_fear_the_reaper = { play = function(ctx)
    for _, u in ipairs(ctx.rival.field) do ctx:spend(u, ctx.rival) end
    local u, s = ctx:pickUnit("any", "Defeat a spent Unit", function(x) return x.spent end, false)
    if u then ctx:defeat(u, s) end
end }
S.floor_it = { play = function(ctx)
    local u = pickRivalUnit(ctx, "-1 power this turn", nil, false)
    if u then ctx:powerThisTurn(u, -1) end
    ctx:draw(1)
end }
S.fool_on_the_hill = { play = function(ctx)
    local top = ctx:top(2)
    if #top == 0 then return end
    local names = {}
    for _, s in ipairs(top) do names[#names + 1] = label(s) end
    G.say(ctx.m, "%s reveals %s.", ctx.seat.name, table.concat(names, ", "))
    local k = ctx:choose("Fool on the Hill: " .. table.concat(names, ", "), { "They add them to their hand", "They trash them (then draw 2)" }, ctx.rival)
    if k == 1 then for _, s in ipairs(top) do ctx:toHand(s) end
    else
        for _, s in ipairs(top) do ctx.seat.trash[#ctx.seat.trash + 1] = s end
        ctx:draw(2)
    end
end }
S.gunpoint_diplomacy = { play = function(ctx)
    local u = ctx:pickUnit("friendly", "Gunpoint Diplomacy: the Unit", nil, false)
    if not u then return end
    local effects = { "The next attack this turn may target ready Units", "+3 power this turn" }
    if G.credLess(ctx.seat, ctx.rival) then
        local k = ctx:choose("Gunpoint Diplomacy: choose ONE effect for " .. ctx.seat.name, effects, ctx.rival)
        if k == 1 then ctx:mod(u, thisTurn(ctx, { flag = "attackReady" })) else ctx:powerThisTurn(u, 3) end
    else
        ctx:mod(u, thisTurn(ctx, { flag = "attackReady" }))
        ctx:powerThisTurn(u, 3)
    end
end }
S.industrial_assembly = { play = function(ctx)
    ctx:changeGig("increase", 4, "any")
    if ctx:gigWith(ctx.seat, function(g) return g.value >= 8 end) then ctx:draw(1) end
end }
S.les_elemens = { play = function(ctx)
    local low
    for _, u in ipairs(ctx.rival.field) do local p = G.power(ctx.m, u, ctx.rival); if not low or p < low then low = p end end
    if not low then return end
    local u, s = pickRivalUnit(ctx, "Bottom-deck their lowest-power Unit", function(x, xs) return G.power(ctx.m, x, xs) == low end, false)
    if u then G.removeUnit(ctx.m, s, u, "bottom") end
end }
S.live_with_the_aftermath = { play = function(ctx)
    for _, s in ipairs({ ctx.seat, ctx.rival }) do
        local list = {}
        for _, u in ipairs(s.field) do list[#list + 1] = u end
        if #list > 0 then
            local opts = {}
            for i, u in ipairs(list) do opts[i] = { label = label(u.slug), card = u.slug, uid = u.uid } end
            local k = ctx:pickOne(s, "Defeat one of your Units", opts, false) or 1
            G.defeat(ctx.m, s, list[k], "effect")
        end
    end
end }
S.memory_relapse = { play = function(ctx)
    local u, s = pickRivalUnit(ctx, "Spend a rival Unit; it can't ready until your next turn", nil, false)
    if u then ctx:spend(u, s); ctx:mod(u, untilNext(ctx, { flag = "noReady" })) end
    if G.credEven(ctx.seat) then ctx:draw(1) end
end }
S.nocturne_op55_n1 = {
    cost = function(m, seat) return #seat.fixer == 0 and (1 - 3) or 0 end,
    play = function(ctx)
        local k = ctx:choose("Nocturne: choose one effect", { "Draw 2", "A Unit can't attack until your next turn", "A friendly Legend may Go Solo for -2 €$ this turn" })
        if k == 1 then ctx:draw(2)
        elseif k == 2 then
            local u = ctx:pickUnit("any", "Can't attack until your next turn", nil, false)
            if u then ctx:mod(u, untilNext(ctx, { flag = "noAttack" })) end
        else ctx:flag(ctx.seat, thisTurn(ctx, { flag = "nocturneSolo" })) end
    end,
}
S.over_the_edge = { play = function(ctx)
    local best
    for _, g in ipairs(ctx.seat.gigs) do if g.kind == "d20" and (not best or g.value > best) then best = g.value end end
    if not best then return end
    local u, s = ctx:pickUnit("any", "Defeat a Unit with power " .. best .. " or less", function(x, xs) return G.power(ctx.m, x, xs) <= best end, false)
    if u then ctx:defeat(u, s) end
end }
S.peace_offering = { play = function(ctx)
    local a, as = ctx:pickGig("any", "You may set a Gig's value", nil, true)
    if a then
        local b = ctx:pickGig("any", "To the value of", function(x) return x ~= a and x.value <= G.sides[a.kind] end, false)
        if b then G.setGig(ctx.m, a, b.value); if as ~= ctx.seat then G.fire(ctx.m, "gigChangedBy", { by = ctx.seat, owner = as, gig = a }) end end
    end
    if G.valuePairs(ctx.seat) > 0 then ctx:draw(1) end
end }
S.pyramid_song = { play = function(ctx)
    local both = ctx:gigWith(ctx.seat, function(g) return g.kind == "d4" and G.isMin(g) end)
    local k = both and 3 or ctx:choose("Pyramid Song: choose one effect", { "Give a rival Unit -4 power this turn", "Bottom-deck a rival Unit with power 0" })
    if k == 1 or k == 3 then
        local u = pickRivalUnit(ctx, "-4 power this turn", nil, false)
        if u then ctx:powerThisTurn(u, -4) end
    end
    if k == 2 or k == 3 then
        local u, s = pickRivalUnit(ctx, "Bottom-deck a rival Unit with power 0", function(x, xs) return G.power(ctx.m, x, xs) <= 0 end, false)
        if u then G.removeUnit(ctx.m, s, u, "bottom") end
    end
end }
S.reboot_optics = { play = function(ctx) ctx:flag(ctx.seat, thisTurn(ctx, { flag = "rebootOptics" })) end }
S.safety_override = { play = function(ctx) ctx:flag(ctx.seat, thisTurn(ctx, { flag = "safetyOverride" })) end }
S.shattered_memories = { play = function(ctx)
    local total = 0
    for _, s in ipairs({ ctx.seat, ctx.rival }) do
        total = total + #s.hand
        for _, c in ipairs(s.hand) do s.trash[#s.trash + 1] = c end
        for i = #s.hand, 1, -1 do s.hand[i] = nil end
        G.say(ctx.m, "%s discards their hand.", s.name)
        if s.house or ctx:yes("Shattered Memories: draw 5?", s) then G.draw(ctx.m, s, 5) end
    end
    if ctx:hasGigValue(ctx.seat, total) then ctx:draw(2) end
end }
S.synapse_burnout = { play = function(ctx)
    local u = ctx:pickUnit("friendly", "+1 power per friendly face-up Legend while fighting this turn", nil, false)
    if u then ctx:mod(u, thisTurn(ctx, { fightBonus = function(m, seat) local n = 0 for _, l in ipairs(seat.legends) do if l.faceUp and not l.removed then n = n + 1 end end return n end })) end
end }
S.take_control = { play = function(ctx)
    local u = pickRivalUnit(ctx, "This rival Unit steals 1 fewer Gig this turn", nil, false)
    if not u then return end
    ctx:mod(u, thisTurn(ctx, { stealDelta = -1 }))
    if G.hasTag(u.slug, "AI") or G.hasTag(u.slug, "Drone") or G.hasTag(u.slug, "Vehicle") then ctx:draw(1) end
end }
S.the_heist = { play = function(ctx)
    local g = trashThenAdd(ctx, 4, function(s) return isType(s, "Gear") end, "Add a Gear to your hand")
    if g and ctx:hasGigValue(ctx.seat, costOf(g)) and #G.holders(ctx.seat) > 0 and ctx:yes("Play " .. label(g) .. " for free instead?") then
        ctx:playFree(g, ctx.seat.hand)
    end
end }
S.three_mouths_one_desire = { play = function(ctx)
    local n = 1 + eachGig(ctx.seat, G.isMin)
    searchTop(ctx, 3, nil, n, 1, false, "Add " .. n .. " to your hand")
end }
S.towerfall = { play = function(ctx)
    local both = G.credLess(ctx.seat, ctx.rival)
    local k = both and 3 or ctx:choose("Towerfall: choose one effect", { "All rival Units get -5 power this turn", "Bottom-deck all rival Units with power 0" })
    if k == 1 or k == 3 then for _, u in ipairs(ctx.rival.field) do ctx:powerThisTurn(u, -5) end end
    if k == 2 or k == 3 then
        local list = {}
        for _, u in ipairs(ctx.rival.field) do if G.power(ctx.m, u, ctx.rival) <= 0 then list[#list + 1] = u end end
        for _, u in ipairs(list) do G.removeUnit(ctx.m, ctx.rival, u, "bottom") end
    end
end }
S.trust_no_one = { play = function(ctx)
    ctx:changeGig("decrease", 3, "any")
    if ctx:gigWith(ctx.seat, G.isMin) then ctx:draw(1) end
end }
S.unlikely_bond = { play = function(ctx)
    local u = ctx:pickUnit("friendly", "Bottom-deck a ready friendly Unit", function(x) return not x.spent end, true)
    if not u then return end
    G.removeUnit(ctx.m, ctx.seat, u, "bottom")
    local r, s = pickRivalUnit(ctx, "Bottom-deck a spent rival Unit", function(x) return x.spent end, false)
    if r then G.removeUnit(ctx.m, s, r, "bottom") end
end }
S.we_gotta_live_together = {
    cost = function(m, seat) return #other(m, seat).gigs >= #seat.gigs + 2 and (3 - 5) or 0 end,
    play = function(ctx)
        local list = {}
        for _, s in ipairs(ctx.seat.trash) do if isType(s, "Unit") and costOf(s) <= 3 then list[#list + 1] = s end end
        local picks = ctx:pickCards(ctx.seat, "Play up to 2 Units (cost 3 or less) from your trash", list, nil, 0, 2, true)
        for _, k in ipairs(picks) do ctx:playFree(list[k], ctx.seat.trash) end
    end,
}
S.wild_in_the_streets = { play = function(ctx)
    local u, s = ctx:pickUnit("any", "Defeat a spent Unit", function(x) return x.spent end, false)
    if u then ctx:defeat(u, s) end
end }

-- ---------------------------------------------------------------------------------------------
-- UNITS

local function selfStole(ctx, d) return d.unit == ctx.holder end
local function myEnd(ctx, d) return d.seat == ctx.seat end

S["6th_street_recruits"] = { on = { stole = function(ctx, d)
    if d.seat == ctx.seat and d.unit and d.gig.kind == "d6" then ctx:changeGig("increase", 6, "any") end
end } }
S.adam_smasher_metal_over_meat = { play = function(ctx)
    for _, s in ipairs({ ctx.seat, ctx.rival }) do
        local list = {}
        for _, u in ipairs(s.field) do if u ~= ctx.holder then list[#list + 1] = u end end
        for _, u in ipairs(list) do G.defeat(ctx.m, s, u, "effect") end
    end
end }
S.alt_cunningham_mother_of_daemons = { on = { spent = function(ctx, d)
    if d.seat == ctx.seat and #(d.holder.gear or {}) > 0 then ctx:draw(1) end
end } }   -- and E.preventSteal
S.animals_wrecker = {}
S.augmented_negotiators = { on = { myBlock = function(ctx) ctx:discard(ctx.rival, 1) end } }
S.caliber_totentanz_s_top_dog = {
    play = function(ctx) defeatRival(ctx, "Defeat a rival Unit with cost 2 or less", function(u) return costOf(u.slug) <= 2 end, false) end,
    defeated = function(ctx)
        local d = ctx:discard(ctx.rival, 1)
        if d[1] and ctx:hasGigValue(ctx.seat, costOf(d[1])) then ctx:discard(ctx.rival, 1) end
    end,
}
S.chrome_fang = { play = function(ctx) ctx:flag(ctx.seat, untilNext(ctx, { flag = "chromeFang" })) end }
S.corpo_security = { canAttack = function() return false, "Corpo Security can't attack." end }
S.delamain_cab = { on = { endTurn = function(ctx, d) if myEnd(ctx, d) and ctx.holder.stoleTurn == ctx.m.turn then ctx:readyEddies(1) end end } }
S.delamain_rideshare_ai = { play = function(ctx) ctx:draw(2) end }
S.dexter_deshawn_one_last_chance = {
    play = function(ctx) ctx:changeGig("adjust", 1, "any") end,
    attack = function(ctx) ctx:changeGig("adjust", 1, "any") end,
    defeated = function(ctx)
        local a, b = G.streetCred(ctx.seat), G.streetCred(ctx.rival)
        if a and b and math.abs(a - b) >= 10 then ctx:draw(2) end
    end,
}
S.el_sombreron_la_venganza_lenta = { attack = function(ctx)
    if G.available(ctx.seat) < 2 or not ctx:gigWith(ctx.seat, G.isMax) then return end
    if not ctx:yes("El Sombrerón: pay 2 €$ for power equal to a friendly max Gig?") then return end
    G.pay(ctx.m, ctx.seat, 2)
    local g = ctx:pickGig("friendly", "A friendly max Gig", G.isMax, false)
    if g then ctx:powerThisTurn(ctx.holder, g.value) end
end }
S.emergency_atlus = {}
S.evelyn_parker_scheming_siren = { attack = function(ctx)
    ctx:draw(1)
    if G.credLess(ctx.rival, ctx.seat) then ctx:discard(ctx.seat, 1) end
end }
S.field_operator = { play = function(ctx) if G.credEven(ctx.seat) then ctx:draw(1) end end }
S.gilded_maton = { play = function(ctx)
    local g = ctx:pickGear("friendly", "You may defeat a friendly Gear", nil, true)
    if g and ctx:defeatGear(g.holder, g.owner, g.slug) then
        defeatRival(ctx, "Defeat a rival Unit with cost 3 or less", function(u) return costOf(u.slug) <= 3 end, false)
    end
end }
S.goro_takemura_losing_his_way = { attack = function(ctx)
    for _, l in ipairs(ctx.seat.legends) do if not l.faceUp and not l.removed then return end end
    ctx:powerThisTurn(ctx.holder, 5)
end }
S.hacked_corpo = { play = function(ctx) trashThenAdd(ctx, 3, function(s) return isType(s, "Program") end, "Add a Program to your hand") end }
S.hanako_arasaka_in_a_gilded_cage = { play = function(ctx)
    searchTop(ctx, 4, function(s) return ctx:hasGigValue(ctx.seat, costOf(s)) end, 4, 0, false, "Cards with a cost equal to a friendly Gig")
end }
S.heywood_ripperdoc = { play = function(ctx)
    local g = ctx:pickGear("any", "You may defeat a Gear", nil, true)
    if g and ctx:defeatGear(g.holder, g.owner, g.slug) and ctx:hasGigValue(ctx.seat, costOf(g.slug)) then ctx:draw(1) end
end }
S.jacked_in_voodoo_boy = { canAttack = function(m, seat)
    if seat.programTurn ~= m.turn then return false, "It attacks only after you played a Program this turn." end
end }
S.jackie_welles_ride_or_die_choom = {
    attack = function(ctx) ctx:powerThisTurn(ctx.holder, 2 * eachGig(ctx.seat, function(g) return g.value % 2 == 0 end)) end,
    defeated = function(ctx) ctx:draw(eachGig(ctx.seat, function(g) return g.value % 2 == 1 end)) end,
}
S.japantown_jonin = { play = function(ctx)
    local u = ctx:pickUnit("friendly", "+2 power this turn", nil, false)
    if u then ctx:powerThisTurn(u, 2) end
end }
S.johnny_silverhand_never_stop_fighting = { on = { fought = function(ctx, d)
    local won = (d.ua == ctx.holder and d.winA) or (d.ub == ctx.holder and d.winB)
    if won and ctx:first("johnny:" .. ctx.holder.uid) then ctx:ready(ctx.holder) end
end } }   -- and E.fightOutcome
S.judy_alvarez_nothing_to_doubt = { activate = { cost = 1, spend = true, label = "1 €$, spend: reveal the top card; play it for free or take it",
    fn = function(ctx)
        local s = ctx:top(1)[1]
        if not s then return end
        G.say(ctx.m, "Judy reveals %s.", label(s))
        local playable = not isType(s, "Legend") and (not isType(s, "Gear") or #G.holders(ctx.seat) > 0)
        if playable and ctx:yes("Play " .. label(s) .. " for free?") then ctx:playFree(s) else ctx:toHand(s) end
    end } }
S.kerry_eurodyne_the_last_rockerboy = { activate = { spend = true, label = "Spend: draw 2 if you control a Gig with 8+ value",
    fn = function(ctx) if ctx:gigWith(ctx.seat, function(g) return g.value >= 8 end) then ctx:draw(2) end end } }
S.la_llorona_ghost_of_the_past = { on = { myBlock = function(ctx) ctx:changeGig("increase", 3, "any") end } }
S.lizzy_wizzy_delicate_weapon = { play = function(ctx)
    local list, from = {}, {}
    for _, s in ipairs(ctx.seat.hand) do if isType(s, "Program") and costOf(s) <= 3 then list[#list + 1] = s; from[#list] = ctx.seat.hand end end
    for _, s in ipairs(ctx.seat.trash) do if isType(s, "Program") and costOf(s) <= 3 then list[#list + 1] = s; from[#list] = ctx.seat.trash end end
    local k = ctx:pickCards(ctx.seat, "You may play a Program (cost 3 or less) from your hand or trash for free", list, nil, 1, 1, true)[1]
    if k then ctx:playFree(list[k], from[k], { bottom = true }) end
end }
S.maelstrom_goons = { on = { stole = function(ctx, d)
    if selfStole(ctx, d) and #(ctx.holder.gear or {}) > 0 then ctx:discard(ctx.rival, 1) end
end } }
S.maelstrom_zealots = {}   -- E.fightOutcome
S.maman_brigitte_spirit_of_death = { play = function(ctx)
    local n = 0
    for _, s in ipairs(ctx.seat.hand) do if isType(s, "Program") then n = n + 1 end end
    if n < 2 or not ctx:yes("Maman Brigitte: discard 2 Programs to bottom-deck a rival unequipped Unit?") then return end
    ctx:discard(ctx.seat, 2, function(s) return isType(s, "Program") end)
    local u, s = pickRivalUnit(ctx, "Bottom-deck a rival unequipped Unit", function(x) return #(x.gear or {}) == 0 end, false)
    if u then G.removeUnit(ctx.m, s, u, "bottom") end
end }
S.maxtac_av = { play = function(ctx)
    if #ctx.seat.gigs == 0 or #ctx.rival.gigs == 0 or not ctx:yes("Maxtac AV: swap a friendly Gig with a rival Gig?") then return end
    S.hanako_arasaka_daughter_of_the_emperor.activate.fn(ctx)
end }
S.maxtac_heavy = { cost = function(m, seat) return -#other(m, seat).field end }
S.maxtac_squadron = { on = { endTurn = function(ctx, d)
    if not myEnd(ctx, d) or not ctx.holder.spent then return end
    local opts, list = {}, {}
    for _, l in ipairs(ctx.seat.legends) do
        if l.faceUp and l.spent and not l.onField and not l.removed then list[#list + 1] = l; opts[#opts + 1] = { label = label(l.slug), card = l.slug } end
    end
    local k = ctx:pickOne(ctx.seat, "Ready a friendly face-up Legend", opts, false)
    if k then list[k].spent = false end
end } }
S.maxtac_suppression_team = {}   -- E.attackRule
S.meredith_stout_stone_cold_corpo = {
    power = function(m, seat, u) local o = m.fighting and m.fighting[u.uid]; return (o and o.legend) and 2 or 0 end,
    on = { gigChangedBy = function(ctx, d)
        if d.owner ~= ctx.seat or d.by == ctx.seat or #ctx.seat.trash == 0 or not ctx:first("meredith") then return end
        local k = ctx:pickCards(ctx.seat, "Meredith Stout: you may add a card from your trash to your hand", ctx.seat.trash, nil, 1, 1, true)[1]
        if k then ctx:toHand(ctx.seat.trash[k], ctx.seat.trash) end
    end },
}
S.minotaur = { play = function(ctx)
    if G.credLess(ctx.rival, ctx.seat) then defeatRival(ctx, "Defeat a rival Unit with power 5 or less", function(u, s) return G.power(ctx.m, u, s) <= 5 end, false) end
end }
S.misty_olszewski_mender_of_broken_spirits = {
    canAttack = function() return false, "Misty can't attack." end,
    on = { endTurn = function(ctx, d)
        if not myEnd(ctx, d) then return end
        local types = { "Unit", "Gear", "Program" }
        local t = types[ctx:choose("Misty: choose a card type", types)]
        local s = table.remove(ctx.seat.library)
        if not s then return end
        G.say(ctx.m, "Misty reveals %s.", label(s))
        if isType(s, t) then ctx:toHand(s); ctx:readyEddies(1) else ctx.seat.trash[#ctx.seat.trash + 1] = s end
    end },
}
S.modded_kusanagi = { on = { endTurn = function(ctx, d) if myEnd(ctx, d) then G.removeUnit(ctx.m, ctx.seat, ctx.holder, "hand") end end } }
S.modded_muramasa = { on = { endTurn = function(ctx, d) if myEnd(ctx, d) and G.credLess(ctx.seat, ctx.rival) then ctx:ready(ctx.holder) end end } }
S.mox_inciters = { play = function(ctx)
    local u = pickRivalUnit(ctx, "This rival Unit must attack next turn if it can", nil, false)
    if u then ctx:mod(u, { flag = "mustAttack", untilEnd = ctx.m.turn + 1 }) end
end }
S.mt0d12_flathead = { unblockable = function(m, seat) return G.credLess(seat, other(m, seat)) end }
S.nadia_fighting_through_grief = { canAttack = function(m, seat, u, target)
    return (target == "gigs" or target == nil) and #other(m, seat).gigs > #seat.gigs
end }
S.octant = { cost = function(m, seat) return -eachGig(seat, function(g) return g.value >= 8 end) end }
S.offduty_malfini = { play = function(ctx)
    ctx:spend(ctx.holder, ctx.seat)
    local u, s = pickRivalUnit(ctx, "Spend a rival Unit", function(x) return not x.spent end, false)
    if u then ctx:spend(u, s) end
end }
S.pacifica_netrunner = { play = function(ctx)
    if not G.credEven(ctx.seat) then return end
    local u = pickRivalUnit(ctx, "This rival Unit can't ready until your next turn", nil, false)
    if u then ctx:mod(u, untilNext(ctx, { flag = "noReady" })) end
end }
S.panam_palmer_strength_through_family = { attack = function(ctx)
    if #ctx.seat.hand == 0 then return end
    if #ctx:discard(ctx.seat, 1, nil, true) > 0 then ctx:draw(ctx:faceUpLegends()) end
end }   -- and E.freeCall
S.pepe_najarro_working_doubles = { attack = function(ctx)
    if G.valuePairs(ctx.seat) == 0 then return end
    local list, opts = {}, {}
    for _, l in ipairs(ctx.seat.legends) do
        if l.spent and not l.onField and not l.removed and l.faceUp and G.hasTag(l.slug, "Merc") then list[#list + 1] = l; opts[#opts + 1] = { label = label(l.slug), card = l.slug } end
    end
    local picks = ctx:ask(ctx.seat, "Ready up to 2 MERC Legends", opts, 0, 2, true)
    for _, k in ipairs(picks) do list[k].spent = false end
end }
local function placide(ctx)
    local has = false
    for _, s in ipairs(ctx.seat.hand) do if isType(s, "Program") then has = true end end
    if not has or #ctx.rival.field == 0 or not ctx:yes("Placide: discard a Program to bottom-deck a rival Unit?") then return end
    ctx:discard(ctx.seat, 1, function(s) return isType(s, "Program") end)
    local u, s = pickRivalUnit(ctx, "Bottom-deck a rival Unit", nil, false)
    if u then G.removeUnit(ctx.m, s, u, "bottom") end
end
S.placide_voodoo_sentinel = { play = placide, attack = placide }
S.psycho_squad = {}
S.riding_nomad = {}
S.rita_wheeler_no_stupid_questions = { on = { spent = function(ctx, d)
    if d.holder ~= ctx.holder or not ctx:first("rita:" .. ctx.holder.uid) then return end
    ctx:draw(1)
    ctx:discard(ctx.seat, 1)
end } }
S.rockn_rockerboy = {}
S.rogue_amendiares_queen_of_the_afterlife = {
    on = { stole = function(ctx, d)
        if d.seat ~= ctx.seat or not d.unit or d.unit == ctx.holder then return end
        if d.gig.value < G.power(ctx.m, d.unit, ctx.seat) and ctx:first("rogueQueen") then ctx:readyEddies(2) end
    end },
    activate = { cost = 2, spend = true, quick = true, label = "2 €$, spend: a rival Unit loses power equal to Rogue's this turn",
        fn = function(ctx)
            local p = G.power(ctx.m, ctx.holder, ctx.seat)
            local u = pickRivalUnit(ctx, "-" .. p .. " power this turn", nil, false)
            if u then ctx:powerThisTurn(u, -p) end
        end },
}
S.royce_don_t_call_me_simon = { play = function(ctx)
    local cap = G.credLess(ctx.rival, ctx.seat) and 3 or 2
    defeatRival(ctx, "Defeat a rival Unit with power " .. cap .. " or less", function(u, s) return G.power(ctx.m, u, s) <= cap end, false)
end }
S.ruthless_lowlife = { canAttack = function(m, seat, u, target)
    if target == "gigs" then return false, "Ruthless Lowlife can only attack rival Units." end
end }
S.sandayu_oda_hanako_s_guardian = {
    play = function(ctx)
        for _ = 1, G.valuePairs(ctx.seat) do
            local u, s = pickRivalUnit(ctx, "Spend a rival Unit", function(x) return not x.spent end, false)
            if u then ctx:spend(u, s) end
        end
    end,
    canAttack = function(m, seat, u, target) return target ~= "gigs" end,
}
S.saul_bright_stormrider = {
    aura = function(m, owner, holder, u, useat) return (useat == owner and u ~= holder and attacking(m, u)) and 2 or 0 end,
    on = { endTurn = function(ctx, d)
        if not myEnd(ctx, d) then return end
        local list = {}
        for _, u in ipairs(ctx.seat.field) do if u.spent then list[#list + 1] = u end end
        local opts = {}
        for i, u in ipairs(list) do opts[i] = { label = label(u.slug), card = u.slug, uid = u.uid } end
        for _, k in ipairs(ctx:ask(ctx.seat, "Ready up to 3 friendly Units", opts, 0, 3, true)) do list[k].spent = false end
    end },
}
S.screw_lovelorn_fool = { defeated = function(ctx)
    local list = {}
    for _, s in ipairs(ctx.seat.trash) do if isType(s, "Unit") and s ~= ctx.holder.slug then list[#list + 1] = s end end
    local k = ctx:pickCards(ctx.seat, "Add another Unit from your trash to your hand", list, nil, 1, 1, false)[1]
    if k then ctx:toHand(list[k], ctx.seat.trash) end
end }
S.secondhand_bombus = {}
S.sketchy_ripper = { attack = function(ctx)
    searchTop(ctx, 3, function(s) return isType(s, "Gear") end, 1, 0, false, "Reveal a Gear and add it to your hand")
end }
S.swordwise_huscle = { attack = function(ctx) if G.power(ctx.m, ctx.holder, ctx.seat) >= 5 then ctx:draw(1) end end }
S.t_bug_amateur_philosopher = { defeated = function(ctx)
    local opts = {}
    for i, l in ipairs(ctx.seat.legends) do if not l.faceUp and not l.removed then opts[#opts + 1] = { label = "Legend " .. i .. ": " .. label(l.slug), card = l.slug } end end
    if #opts > 0 then ctx:ask(ctx.seat, "T-Bug: your face-down Legends", opts, 0, 0, true) end
    ctx:callFree(true)
end }
S.trauma_team_operatives = { cost = function(m, seat)
    local n = 0
    for _, s in ipairs(seat.trash) do if isType(s, "Unit") then n = n + 1 end end
    return -n
end }
S.tyger_s_whisper = { play = function(ctx) ctx:callFree(true) end }
S.v_roamer_of_the_badlands = { on = {
    stole = function(ctx, d)
        if not selfStole(ctx, d) then return end
        local g = d.gig
        local opts, vals = {}, {}
        for v = g.value + 1, math.min(G.sides[g.kind], g.value + 5) do vals[#vals + 1] = v; opts[#opts + 1] = { label = g.kind .. ": " .. g.value .. " -> " .. v } end
        local k = ctx:pickOne(ctx.seat, "V: increase the stolen Gig by up to 5", opts, true)
        if k then G.setGig(ctx.m, g, vals[k]) end
    end,
    endTurn = function(ctx, d) if myEnd(ctx, d) and eachGig(ctx.seat, function(g) return g.value >= 8 end) >= 2 then ctx:draw(1) end end,
} }
S.valentino_guerrera = { attackReady = function(m, seat, u, d)
    return G.credLess(other(m, seat), seat) and G.kw(m, other(m, seat), d, "Blocker")
end }
S.valentino_street_racer = { play = function(ctx)
    local u = ctx:pickUnit("friendly", "Another friendly Unit (cost 5 or less) gets Adrenaline this turn", function(x) return x ~= ctx.holder and costOf(x.slug) <= 5 end, false)
    if u then ctx:mod(u, thisTurn(ctx, { kw = { Adrenaline = true } })) end
end }
S.viktor_vektor_drop_your_illusions = { on = { played = function(ctx, d)
    if d.seat == ctx.seat and isType(d.slug, "Gear") and G.hasTag(d.slug, "Cyberware") then ctx.seat.firsts = ctx.seat.firsts or {}; ctx.seat.firsts.cyberware = true end
end } }   -- and E.costMod
S.viktor_vektor_you_might_feel_a_little_pinch = { play = function(ctx)
    local list = {}
    for _, s in ipairs(ctx.seat.trash) do if isType(s, "Gear") and G.hasTag(s, "Cyberware") and costOf(s) <= 2 then list[#list + 1] = s end end
    local others = 0
    for _, u in ipairs(ctx.seat.field) do if u ~= ctx.holder then others = others + 1 end end
    if others == 0 then return end
    local k = ctx:pickCards(ctx.seat, "Play a CYBERWARE Gear (cost 2 or less) from your trash", list, nil, 1, 1, false)[1]
    if k then ctx:playFree(list[k], ctx.seat.trash, { holderFilter = function(h) return h ~= ctx.holder and G.findUnit(ctx.m, h.uid) end }) end
end }
S.westbrook_netrunner = { play = function(ctx) ctx:flag(ctx.seat, untilNext(ctx, { flag = "westbrook" })) end }
S.wraith_marauders = { on = { stole = function(ctx, d)
    if not selfStole(ctx, d) then return end
    local u = ctx:pickUnit("friendly", "Ready another friendly Unit with power " .. d.gig.value, function(x, s)
        return x ~= ctx.holder and x.spent and G.power(ctx.m, x, s) == d.gig.value end, true)
    if u then ctx:ready(u) end
end } }
S.yorinobu_arasaka_steel_dragon = {
    play = function(ctx)
        local list, from = {}, {}
        for _, s in ipairs(ctx.seat.hand) do if isType(s, "Unit") and costOf(s) <= 4 then list[#list + 1] = s; from[#list] = ctx.seat.hand end end
        for _, s in ipairs(ctx.seat.trash) do if isType(s, "Unit") and costOf(s) <= 4 then list[#list + 1] = s; from[#list] = ctx.seat.trash end end
        local k = ctx:pickCards(ctx.seat, "You may play a Unit (cost 4 or less) from your hand or trash for free", list, nil, 1, 1, true)[1]
        if not k then return end
        take(from[k], list[k])
        local u = G.putIntoPlay(ctx.m, ctx.seat, list[k])
        if type(u) == "table" then ctx:mod(u, thisTurn(ctx, { flag = "freshUnits" })) end
    end,
    on = { defeated = function(ctx, d)
        if d.seat == ctx.seat and G.hasTag(d.unit.slug, "Arasaka") and ctx:first("steelDragon") then ctx:draw(1) end
    end },
}

-- ---------------------------------------------------------------------------------------------
-- Program flags that watch the game (Appetite for Destruction, Cyberpsychosis)

local function addGlobal(name, fn)
    E.global = E.global or {}
    E.global[name] = fn
end
addGlobal("fought", function(m, d)
    for _, x in ipairs({ { s = d.a, u = d.ua, win = d.winA, by = d.pa - d.pb, foe = d.b }, { s = d.b, u = d.ub, win = d.winB, by = d.pb - d.pa, foe = d.a } }) do
        local f = G.flag(x.s, "appetite")
        if f and x.win and x.by >= 3 and #x.foe.gigs > 0 then
            for i, y in ipairs(x.s.flags) do if y == f then table.remove(x.s.flags, i) break end end
            G.queue(m, x.s, "appetite_for_destruction", function(ctx)
                local g, gs = ctx:pickGig("rival", "Appetite for Destruction: steal a Gig", nil, false)
                if g then G.stealGig(m, ctx.seat, gs, g, x.u) end
            end)
        end
    end
end)
addGlobal("endTurn", function(m, d)
    for _, s in ipairs(m.seats) do
        local list = {}
        for _, u in ipairs(s.field) do
            if G.unitFlag(u, "psycho") and (u.stoleTurn == m.turn or u.foughtTurn == m.turn) then list[#list + 1] = u end
        end
        for _, u in ipairs(list) do G.defeat(m, s, u, "effect") end
    end
end)

-- Coverage: every card in the set has an entry (tools/test_game.py checks it).
function E.coverage()
    local missing = {}
    for slug in pairs(TcgCards) do if not S[slug] then missing[#missing + 1] = slug end end
    table.sort(missing)
    return missing
end
