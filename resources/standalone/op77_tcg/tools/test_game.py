"""The rules engine (shared/game.lua) and every card's script (shared/effects.lua) against the official rules
(docs/RULES.md §1, §4, §8-§11) and the cards' texts. Usage: python tools/test_game.py   (needs lupa)"""
import pathlib
import sys

import lupa.lua54 as lupa  # the server runs Lua 5.4 (and lupa's 5.5 build crashes in its GC)

ROOT = pathlib.Path(__file__).resolve().parent.parent
L = lupa.LuaRuntime(unpack_returned_tuples=True)
for f in ["shared/cards.lua", "shared/game.lua", "shared/effects.lua"]:
    L.execute((ROOT / f).read_text(encoding="utf-8"))
checks = 0


def check(cond, what):
    global checks
    if not cond:
        print("FAIL:", what)
        sys.exit(1)
    checks += 1


def n(t):
    return len(list(t.values())) if t is not None else 0


def ok(r):
    """An engine call returns true, or false and a reason."""
    return (r[0] if isinstance(r, tuple) else r) is True


def why(r):
    return str(r[1]) if isinstance(r, tuple) and len(r) > 1 else ""


L.execute("""
LEGS = { 'yorinobu_arasaka_embracing_destruction', 'jackie_welles_pour_one_out_for_me', 'kerry_eurodyne_axe_attitude_audience' }
function newMatch(rolls)
    local q = rolls or {}
    local m = { first = 1, log = {}, random = function(a, b) local v = table.remove(q, 1) or a; return math.max(a, math.min(b, v)) end }
    local function seat(i, name)
        return { index = i, name = name, library = {}, hand = {}, deck = { name = 'test' },
                 legends = { { slug = LEGS[1], faceUp = false, spent = (i == 1) }, { slug = LEGS[2], faceUp = false, spent = (i == 1) },
                             { slug = LEGS[3], faceUp = false, spent = false } } }
    end
    m.seats = { seat(1, 'A'), seat(2, 'B') }
    TcgGame.begin(m)
    return m
end
function fill(seat, slug, k) for _ = 1, k do seat.library[#seat.library + 1] = slug end end
function put(m, seat, slug, spent, lag)
    local u = { uid = TcgGame.nextId(m), slug = slug, spent = spent, lag = lag, gear = {}, mods = {}, playedTurn = 0 }
    seat.field[#seat.field + 1] = u
    return u
end
function eddies(m, seat, k) for _ = 1, k do seat.eddies[#seat.eddies + 1] = { uid = TcgGame.nextId(m), slug = 'mantis_blades', spent = false } end end
function gig(m, seat, kind, value) return TcgGame.addGig(m, seat, kind, value, seat.index) end
function settle(m) local k = 0 while m.prompt and k < 50 do m.prompt.house = true; TcgGame.defaultAnswer(m); k = k + 1 end end
function flag(seat, name, untilStart) seat.flags[#seat.flags + 1] = { flag = name, untilStart = untilStart } end
""")
G = L.eval("TcgGame")
newMatch, fill, put, eddies, gig, settle, flag = (L.eval(x) for x in ("newMatch", "fill", "put", "eddies", "gig", "settle", "flag"))
check(n(L.eval("TcgEffects.coverage()")) == 0, "every card of the set has a script")

# --- The turn [8] --------------------------------------------------------------------------------------------
m = newMatch(L.table_from([3, 5, 2, 6, 4, 1, 1, 1, 1, 1, 1, 1]))
A, B = m.seats[1], m.seats[2]
fill(A, "psycho_squad", 20)
fill(B, "psycho_squad", 20)
check(ok(G.startTurn(m)) and m.step == "roll" and m.turn == 1 and m.active == 1, "turn 1 starts with the roll step")
check(n(A.hand) == 1 and n(A.library) == 19, "draw 1 at the start of the turn")
check(A.legends[1].spent and A.legends[2].spent and not A.legends[3].spent, "the first player's two Legends stay spent on turn 1")
r = G.roll(m, 1, "d20")
check(not ok(r) and "last" in why(r), "the d20 only when it is the last die")
check(not ok(G.sell(m, 1, 1)), "no main-phase action before the roll")
check(ok(G.roll(m, 1, "d6")) and A.gigs[1].value == 3 and m.step == "main", "roll a d6 into the Gig area")
check(G.streetCred(A) == 3 and G.streetCred(B) is None, "Street Cred: sum of Gigs, null without Gigs")
check(G.available(A) == 1, "only the ready Legend pays on turn 1")
A.hand[2] = "psycho_squad"
r = G.play(m, 1, 2)
check(not ok(r) and "Not enough" in why(r), "a 4-cost Unit is not affordable with 1 €$")
A.hand[3] = "kiroshi_optics"
check(ok(G.sell(m, 1, 3)) and n(A.eddies) == 1, "sell a card with a Sell Tag into the Eddies")
check(not ok(G.sell(m, 1, 1)), "sell once per turn")
eddies(m, A, 2)
check(ok(G.play(m, 1, 2)), "Eddies and a Legend pay a 4-cost Unit")
u = A.field[1]
check(u.lag and not u.spent, "the Unit enters ready with Lag")
r = G.attack(m, 1, u.uid, "gigs")
check(not ok(r) and "Lag" in why(r), "a lagging Unit cannot attack")
check(ok(G.endTurn(m, 1)) and m.active == 2 and m.turn == 2 and m.step == "roll", "pass: the rival's turn begins")
check(not u.lag, "Units lose their Lag at the end of the turn")
check(ok(G.roll(m, 2, "d8")) and B.gigs[1].value == 5, "the rival rolls a Gig")
check(ok(G.endTurn(m, 2)) and m.turn == 3, "turn 3")
check(not A.legends[1].spent and not A.legends[2].spent and not A.eddies[1].spent, "ready step from turn 2 on")
check(ok(G.roll(m, 1, "d4")) and ok(G.attack(m, 1, u.uid, "gigs")) and m.step == "react" and u.spent, "attack the Gigs: spent, the rival reacts")
check(not ok(G.endTurn(m, 1)), "no pass during the React step")
check(ok(G.resolve(m, 2)) and m.step == "steal" and m.attack.steal == 1, "steal floor(6/10)+1 = 1 Gig")
check(not ok(G.steal(m, 1, L.table_from([999]))), "steal only the rival's Gigs")
check(ok(G.steal(m, 1, L.table_from([B.gigs[1].uid]))) and n(A.gigs) == 3 and n(B.gigs) == 0, "the stolen Gig moves")
check(A.gigs[3].value == 5 and m.step == "main", "a stolen Gig keeps its value")


# --- Card scripts: targeted ----------------------------------------------------------------------------------
def fresh(rolls=None):
    mm = newMatch(L.table_from(rolls or [6] * 40))
    fill(mm.seats[1], "psycho_squad", 15)
    fill(mm.seats[2], "psycho_squad", 15)
    G.startTurn(mm)
    G.roll(mm, 1, "d4")
    eddies(mm, mm.seats[1], 10)
    return mm, mm.seats[1], mm.seats[2]


def play_last(mm, seat_index, slug):
    s = mm.seats[seat_index]
    s.hand[n(s.hand) + 1] = slug
    return G.play(mm, seat_index, n(s.hand))


mm, a, b = fresh()
rl = put(mm, a, "ruthless_lowlife", False, False)
cs = put(mm, a, "corpo_security", False, False)
gig(mm, b, "d6", 4)
r = G.canAttack(mm, a, rl, "gigs")
check(not ok(r) and "only attack rival Units" in why(r), "Ruthless Lowlife can't attack Gig areas")
check(not ok(G.canAttack(mm, a, cs)), "Corpo Security can't attack")
h0 = n(a.hand)
check(ok(play_last(mm, 1, "delamain_rideshare_ai")) and n(a.hand) == h0 + 2, "Delamain Rideshare AI: {Play} draw 2")
put(mm, b, "psycho_squad", False, False)
eddies(mm, a, 6)
check(ok(play_last(mm, 1, "adam_smasher_metal_over_meat")), "play Adam Smasher, Metal over Meat")
settle(mm)
check(n(a.field) == 1 and n(b.field) == 0 and a.field[1].slug == "adam_smasher_metal_over_meat", "Adam Smasher defeats all other Units")

mm, a, b = fresh()
target = put(mm, b, "psycho_squad", False, False)
check(ok(play_last(mm, 1, "corporate_surveillance")) and mm.prompt is not None and mm.prompt.seat == 1, "a Program asks its player for a target")
check(not ok(G.answer(mm, 2, L.table_from([1]))), "only the prompted player answers")
check(ok(G.answer(mm, 1, L.table_from([1]))) and target.spent and a.trash[n(a.trash)] == "corporate_surveillance",
      "Corporate Surveillance spends the target, then goes to the trash")

mm, a, b = fresh()
g = gig(mm, a, "d10", 5)
play_last(mm, 1, "industrial_assembly")
check(mm.prompt is not None and "Increase" in str(mm.prompt.title), "Industrial Assembly asks which Gig")
opts = list(mm.prompt.options.values())
pick = [i for i, o in enumerate(opts, 1) if "d10 showing 5" in str(o.label)][0]
G.answer(mm, 1, L.table_from([pick]))
vals = list(mm.prompt.options.values())
check(len(vals) == 4 and "5 -> 9" in str(vals[3].label), "up to 4: four new values")
hb = n(a.hand)
G.answer(mm, 1, L.table_from([4]))
check(g.value == 9 and n(a.hand) == hb + 1, "the Gig shows 9; a Gig with 8+ draws 1")

mm, a, b = fresh()
for s in ["mantis_blades", "psycho_squad", "kiroshi_optics", "psycho_squad", "riot_shield"]:
    a.library[n(a.library) + 1] = s
a.legends[3].slug = "viktor_vektor_sit_down_and_relax"
lib = n(a.library)
check(ok(G.call(mm, 1, 3)) and mm.prompt is not None, "Calling Viktor Vektor searches the top 5")
opts = list(mm.prompt.options.values())
gears = [i for i, o in enumerate(opts, 1) if not o.disabled]
check(len(gears) == 3, "only Gears with cost 2 or less can be picked")
G.answer(mm, 1, L.table_from(gears[:2]))
check(n(a.library) == lib - 2, "two Gears to the hand, the rest bottom-decked")

mm, a, b = fresh()
atk = put(mm, a, "psycho_squad", False, False)
dfd = put(mm, b, "rockn_rockerboy", False, False)
dfd.gear[1] = "mandibular_upgrade"
gig(mm, b, "d6", 6)
check(G.kw(mm, b, dfd, "Blocker"), "Mandibular Upgrade gives its holder Blocker")
check(ok(G.attack(mm, 1, atk.uid, "gigs")) and ok(G.block(mm, 2, dfd.uid)), "blocked")
G.resolve(mm, 2)
settle(mm)
check(n(b.gigs) == 1 and n(a.field) == 0, "a blocked Gig attack steals nothing; the 6-power attacker loses to 8")

mm, a, b = fresh()
w = put(mm, a, "psycho_squad", True, False)
w.gear[1] = "deadman_transmitter"
k = put(mm, b, "rockn_rockerboy", False, False)
mm.active = 2
check(ok(G.attack(mm, 2, k.uid, w.uid)) and ok(G.resolve(mm, 1)), "attack the equipped Unit")
settle(mm)
check(n(a.field) == 1 and n(w.gear) == 0 and "deadman_transmitter" in list(a.trash.values()), "Deadman Transmitter is defeated instead")

mm, a, b = fresh()
j = put(mm, a, "johnny_silverhand_never_stop_fighting", False, False)
c = put(mm, b, "meredith_stout_stone_cold_corpo", True, False)
check(G.hasTag("meredith_stout_stone_cold_corpo", "Corpo"), "Meredith is CORPO")
G.attack(mm, 1, j.uid, c.uid)
G.resolve(mm, 2)
settle(mm)
check(n(b.field) == 0 and n(a.field) == 1 and not j.spent, "Johnny wins against CORPO and readies the first time")

mm, a, b = fresh()
put(mm, b, "maxtac_suppression_team", False, False)
gig(mm, b, "d6", 2)
play_last(mm, 1, "riding_nomad")
nomad = a.field[n(a.field)]
check(not ok(G.canAttack(mm, a, nomad, "gigs")), "a rival's Maxtac Suppression Team stops an Adrenaline Unit the turn it's played")

mm, a, b = fresh()
for _ in range(8):
    put(mm, b, "psycho_squad", False, False)
check(G.costOf(mm, a, "maxtac_heavy", "hand") == 1, "Maxtac Heavy: -1 per rival Unit, never below 1")
check(G.costOf(mm, a, "trauma_team_operatives", "hand") == 6, "Trauma Team: no Unit in the trash, full cost")
rs = put(mm, b, "psycho_squad", False, False)
rs.gear[1] = "riot_shield"
check(G.costOf(mm, a, "v_corporate_exile", "solo") == 7, "Riot Shield: rivals pay +2 €$ to Go Solo")

mm, a, b = fresh()
gig(mm, b, "d12", 11)
gig(mm, b, "d4", 2)
flag(b, "chromeFang", 2)
att = put(mm, a, "psycho_squad", False, False)
G.attack(mm, 1, att.uid, "gigs")
G.resolve(mm, 2)
check(mm.step == "steal" and n(mm.attack.stealable) == 1, "Chrome Fang: only Gigs worth 6 or less can be stolen by a 6-power Unit")

mm, a, b = fresh()
a.legends[3].faceUp = True
a.legends[3].slug = "hanako_arasaka_daughter_of_the_emperor"
mine = gig(mm, a, "d4", 1)
theirs = gig(mm, b, "d20", 18)
acts = list(G.options(mm, 1).activate.values())
x = [x for x in acts if str(x.card) == "hanako_arasaka_daughter_of_the_emperor"]
check(x and x[0].ok, "Hanako's Spend effect is available")
check(ok(G.activate(mm, 1, x[0].uid, x[0].id)), "activate Hanako")
settle(mm)
check(theirs.uid in [x.uid for x in a.gigs.values()] and n(b.gigs) == 1 and b.gigs[1].kind == "d4" and a.legends[3].spent,
      "Gigs swapped, Hanako spent")

mm, a, b = fresh()
at = put(mm, a, "psycho_squad", False, False)
gig(mm, b, "d6", 3)
eddies(mm, b, 3)
b.hand[n(b.hand) + 1] = "floor_it"
G.attack(mm, 1, at.uid, "gigs")
qs = list(G.options(mm, 2).quick.values())
check(qs == [n(b.hand)], "Floor It is offered as a Quick reaction")
hb = n(b.hand)
check(ok(G.quick(mm, 2, n(b.hand))), "play Floor It as a reaction")
settle(mm)
check(G.power(mm, at, a) == 5 and n(b.hand) == hb, "the attacker has -1 power; Floor It drew 1 and left the hand")

mm, a, b = fresh()
put(mm, b, "psycho_squad", False, False)
play_last(mm, 1, "mox_inciters")
settle(mm)
G.endTurn(mm, 1)
settle(mm)
G.roll(mm, 2, "d4")
settle(mm)
gig(mm, a, "d6", 2)
r = G.endTurn(mm, 2)
check(not ok(r) and "must attack" in why(r), "Mox Inciters: that Unit must attack before the turn ends")

mm = newMatch(L.table_from([1, 1, 4, 4, 4, 4]))
a = mm.seats[1]
fill(a, "psycho_squad", 10)
fill(mm.seats[2], "psycho_squad", 10)
a.legends[3].faceUp = True
G.startTurn(mm)
h = n(a.hand)
G.roll(mm, 1, "d6")
check(mm.prompt is not None and "reroll" in str(mm.prompt.title), "Kerry Eurodyne offers a reroll")
G.answer(mm, 1, L.table_from([2]))
check(a.gigs[1].value == 1 and n(a.hand) == h + 1, "kept the min roll: draw 1")

mm, a, b = fresh()
for s in ["psycho_squad"] * 3:
    b.hand[n(b.hand) + 1] = s
play_last(mm, 1, "shattered_memories")
settle(mm)
check(n(a.hand) >= 5 and n(b.hand) == 5, "Shattered Memories: hands discarded, 5 drawn")

mm, a, b = fresh()
a.legends[3].faceUp = True
a.legends[3].slug = "saburo_arasaka_stubborn_patriarch"
ara = [k for k, cc in L.eval("TcgCards").items() if cc.type == "Unit" and G.hasTag(k, "Arasaka")]
if ara:
    au = put(mm, a, ara[0], False, False)
    base = G.power(mm, au, a)
    gig(mm, b, "d6", 1)
    G.attack(mm, 1, au.uid, "gigs")
    check(G.power(mm, au, a) == base + 1, "Saburo: a friendly ARASAKA Unit has +1 power while attacking")

# --- Engine edges --------------------------------------------------------------------------------------------
mm = newMatch(L.table_from([6] * 40))
fill(mm.seats[1], "psycho_squad", 10)
fill(mm.seats[2], "psycho_squad", 10)
G.startTurn(mm)
G.roll(mm, 1, "d4")
a = mm.seats[1]
a.legends[2].faceUp = True
a.legends[2].slug = "saburo_arasaka_stubborn_patriarch"
r = G.playLegend(mm, 1, 2)
check(not ok(r) and "null" in why(r), "a null-cost Legend cannot be played to the field")
a.legends[3].faceUp = True
a.legends[3].slug = "v_corporate_exile"
eddies(mm, a, 6)
check(ok(G.playLegend(mm, 1, 3)), "Go Solo")
sl = a.field[n(a.field)]
check(sl.solo and not sl.lag and ok(G.canAttack(mm, a, sl)), "Go Solo: ready, can attack this turn")
for _ in range(7):
    gig(mm, a, "d6", 1)
check(ok(G.endTurn(mm, 1)) and mm.active == 2, "B's turn")
settle(mm)
G.roll(mm, 2, "d4")
settle(mm)
check(ok(G.endTurn(mm, 2)) and mm.step == "over" and mm.winner == 1, "7 Gigs at the start of the turn: win")
m3 = newMatch(L.table_from([1] * 10))
G.startTurn(m3)
check(m3.step == "over" and m3.winner == 2, "drawing from an empty deck loses")

# --- Every card, in real games: house vs house with decks drawn from the whole set ---------------------------
L.execute("""
function houseGame(seed)
    math.randomseed(seed)
    local m = { first = 1, log = {}, random = math.random }
    local units, others, legends = {}, {}, {}
    for k, c in pairs(TcgCards) do
        if c.type == 'Legend' then legends[#legends + 1] = k elseif c.type == 'Unit' then units[#units + 1] = k else others[#others + 1] = k end
    end
    table.sort(units); table.sort(others); table.sort(legends)
    local function seat(i)
        local ls = {}
        for j = 1, 3 do ls[j] = { slug = legends[math.random(#legends)], faceUp = false, spent = i == 1 and j <= 2 } end
        return { index = i, name = 'H' .. i, library = {}, hand = {}, deck = { name = 'x' }, legends = ls, house = true }
    end
    m.seats = { seat(1), seat(2) }
    for _, s in ipairs(m.seats) do
        for i = 1, 26 do s.library[#s.library + 1] = units[math.random(#units)] end
        for i = 1, 18 do s.library[#s.library + 1] = others[math.random(#others)] end
        for i = #s.library, 2, -1 do local j = math.random(i); s.library[i], s.library[j] = s.library[j], s.library[i] end
        for i = 1, 6 do s.hand[i] = table.remove(s.library) end
    end
    TcgGame.begin(m)
    TcgGame.startTurn(m)
    local steps, used = 0, {}
    while m.step ~= 'over' and steps < 8000 do
        steps = steps + 1
        local who = m.active
        if m.prompt then who = m.prompt.seat elseif m.step == 'react' and m.attack then who = m.attack.defender end
        if not m.prompt and not TcgGame.busy(m) and m.step == 'main' and math.random() < 0.55 then
            local s = m.seats[who]
            local i = math.random(math.max(1, #s.hand))
            if s.hand[i] then
                local slug = s.hand[i]
                if TcgGame.play(m, who, i) then used[slug] = true end
            end
            if not TcgGame.busy(m) and m.step == 'main' then
                local acts = TcgGame.activations(m, s)
                if #acts > 0 and math.random() < 0.4 then
                    local e = acts[math.random(#acts)]
                    if TcgGame.canActivate(m, s, e, false) and TcgGame.activate(m, who, e.holder.uid, e.id) then used[e.id] = true end
                end
            end
            if not TcgGame.busy(m) and m.step == 'main' then
                for j, l in ipairs(s.legends) do
                    if not l.faceUp and not l.removed and math.random() < 0.25 and TcgGame.call(m, who, j) then used[l.slug] = true break end
                end
            end
        else
            local ok, why = TcgGame.housePlay(m, who)
            if not ok and why ~= 'waiting' and m.step ~= 'over' then
                if not (m.step == 'main' and TcgGame.busy(m) == false and why and why:find('must attack')) then
                    return false, 'house stuck: ' .. tostring(why) .. ' at ' .. m.step
                end
            end
        end
    end
    for _, l in ipairs(m.log) do if l:find('failed:', 1, true) then return false, l end end
    if m.step ~= 'over' then return false, 'no end after ' .. steps .. ' steps (' .. m.step .. ')' end
    local k = 0 for _ in pairs(used) do k = k + 1 end
    return true, m.endReason, m.turn, k, used
end
""")
failures, seen = [], set()
games = 80
for seed in range(1, games + 1):
    res = L.eval("function(s) local ok, a, b, c, d, e = pcall(houseGame, s) return ok, a, b, c, d, e end")(seed)
    if not res[0] or res[1] is False:
        failures.append((seed, res[1], res[2]))
    else:
        for k in res[5].keys():
            seen.add(str(k))
check(not failures, f"{games} random games with every card end by the rules, no script error: {failures[:3]}")
print(f"PASS: rules engine and card scripts ({checks} checks; {games} random full games exercised {len(seen)} different cards/effects)")
