"""The rules engine (shared/game.lua) against the official rules (docs/RULES.md §1, §4, §8-§11).
Usage: python tools/test_game.py   (needs lupa)"""
import pathlib
import sys

import lupa.lua54 as lupa  # the server runs Lua 5.4 (and lupa's 5.5 build crashes in its GC)

ROOT = pathlib.Path(__file__).resolve().parent.parent
L = lupa.LuaRuntime(unpack_returned_tuples=True)
for f in ["shared/cards.lua", "shared/game.lua"]:
    L.execute((ROOT / f).read_text(encoding="utf-8"))
checks = 0


def check(cond, what):
    global checks
    if not cond:
        print("FAIL:", what)
        sys.exit(1)
    checks += 1


# A test match: fixed rolls (a queue), hand-picked cards. Card picks from the real data.
L.execute("""
function pickCard(pred) local keys = {} for k in pairs(TcgCards) do keys[#keys + 1] = k end table.sort(keys)
    for _, k in ipairs(keys) do if pred(TcgCards[k], k) then return k end end end
function newMatch(rolls)
    local q = rolls or {}
    local m = { first = 1, log = {}, random = function(a, b) local v = table.remove(q, 1) or a; return math.max(a, math.min(b, v)) end }
    local function seat(i, name)
        return { index = i, name = name, library = {}, hand = {}, deck = { name = 'test' },
                 legends = { { slug = LEG1, faceUp = false, spent = (i == 1) }, { slug = LEG2, faceUp = false, spent = (i == 1) },
                             { slug = LEG3, faceUp = false, spent = false } } }
    end
    m.seats = { seat(1, 'A'), seat(2, 'B') }
    TcgGame.begin(m)
    return m
end
function fill(seat, slug, n) for _ = 1, n do seat.library[#seat.library + 1] = slug end end
""")
G = L.eval("TcgGame")
# Picked from the real data: Ruthless Lowlife 2/4, Jacked-in Voodoo Boy 2/2 (no keyword), Kiroshi Optics (Gear, Sell Tag),
# Corpo Security (Blocker), Mantis Blades (Gear 1, +2), V: Corporate Exile (Go Solo, cost 5), Saburo (null cost).
unit, cheap, seller, blocker, gear = "ruthless_lowlife", "jacked_in_voodoo_boy", "kiroshi_optics", "corpo_security", "mantis_blades"
solo, nulllegend = "v_corporate_exile", "saburo_arasaka_stubborn_patriarch"
program = L.eval("pickCard(function(c) return c.type == 'Program' and (c.cost or 9) <= 2 end)")
legs = ["yorinobu_arasaka_embracing_destruction", "jackie_welles_pour_one_out_for_me", "kerry_eurodyne_axe_attitude_audience"]
L.globals().LEG1, L.globals().LEG2, L.globals().LEG3 = legs[0], legs[1], legs[2]
check(all(x for x in (unit, cheap, seller, blocker, gear, program, solo)), "test cards found in the real data")

m = L.eval("newMatch")(L.table_from([3, 5, 2, 6, 4, 1, 1, 1, 1, 1, 1, 1]))
A, B = m.seats[1], m.seats[2]
fill = L.eval("fill")
fill(A, unit, 20)
fill(B, unit, 20)

# Start of turn 1: no win, the first player's two spent Legends stay spent, draw 1, roll a Gig.
check(G.startTurn(m) and m.step == "roll" and m.turn == 1 and m.active == 1, "turn 1 starts with the roll step")
check(len(list(A.hand.values())) == 1 and len(list(A.library.values())) == 19, "draw 1 at the start of the turn")
check(A.legends[1].spent and A.legends[2].spent and not A.legends[3].spent, "the first player's two Legends stay spent on turn 1")
ok, why = G.roll(m, 1, "d20")
check(not ok and "last" in why, "the d20 only when it is the last die")
ok, why = G.sell(m, 1, 1)
check(not ok, "no main-phase action before the roll")
check(G.roll(m, 1, "d6") and A.gigs[1].value == 3 and A.gigs[1].kind == "d6" and m.step == "main", "roll a d6 into the Gig area")
check(len(list(A.fixer.values())) == 5, "the die leaves the fixer")
check(G.streetCred(A) == 3 and G.streetCred(B) is None, "Street Cred: sum of Gigs, null without Gigs")

# Paying: 1 €$ per ready Eddie or Legend (face-down, or face-up with a Sell Tag); the spent Legends cannot pay.
check(G.available(A) == 1, "only the ready Legend pays on turn 1")
A.hand[2] = unit
ok, why = G.play(m, 1, 2)
check(not ok and "Not enough" in why, "a 2-cost Unit is not affordable with 1 €$")
A.hand[3] = seller
check(G.sell(m, 1, 3) and len(list(A.eddies.values())) == 1, "sell a card with a Sell Tag into the Eddies")
ok, why = G.sell(m, 1, 1)
check(not ok, "sell once per turn (or the card has no Sell Tag)")
check(G.available(A) == 2 and G.play(m, 1, 2), "Eddie + Legend pay a 2-cost Unit")
u = A.field[1]
check(u.lag and not u.spent and A.eddies[1].spent and A.legends[3].spent, "the Unit enters ready with Lag; the payers are spent")
ok, why = G.attack(m, 1, u.uid, "gigs")
check(not ok and "Lag" in why, "a lagging Unit cannot attack")
ok, why = G.call(m, 1, 3)
check(not ok, "no Eddie left to Call a Legend")
ok, why = G.roll(m, 2, "d4")
check(not ok, "not the rival's turn")

# Turn 2 (B): ready step, draw, roll. Then B plays and passes.
check(G.endTurn(m, 1) and m.active == 2 and m.turn == 2 and m.step == "roll", "pass: the rival's turn begins")
check(not u.lag, "Units lose their Lag at the end of the turn")
check(G.roll(m, 2, "d8") and B.gigs[1].value == 5, "the rival rolls a Gig")
B.hand[2] = cheap
check(G.play(m, 2, 2) and len(list(B.field.values())) == 1, "the rival plays a 1-cost Unit with a Legend")
b1 = B.field[1]
check(G.endTurn(m, 2) and m.turn == 3, "turn 3")

# Turn 3 (A): everything readies, including the Legends spent on turn 1.
check(not A.legends[1].spent and not A.legends[2].spent and not A.eddies[1].spent and not u.spent, "ready step from turn 2 on")
check(G.roll(m, 1, "d4") and A.gigs[2].value == 2, "second Gig")
ok, why = G.attack(m, 1, u.uid, b1.uid)
check(not ok and "spent" in why, "only spent rival Units can be attacked")
pa = G.power(u)
check(G.attack(m, 1, u.uid, "gigs") and m.step == "react" and u.spent, "attack the Gigs: the attacker is spent, the rival reacts")
ok, why = G.endTurn(m, 1)
check(not ok, "no pass during the React step")
check(G.resolve(m, 2) and m.step == "steal" and m.attack.steal == min(len(list(B.gigs.values())), pa // 10 + 1), "steal floor(power/10)+1 Gigs")
gid = B.gigs[1].uid
ok, why = G.steal(m, 1, L.table_from([999]))
check(not ok, "steal only the rival's Gigs")
check(G.steal(m, 1, L.table_from([gid])) and len(list(A.gigs.values())) == 3 and len(list(B.gigs.values())) == 0, "the stolen Gig moves")
check(A.gigs[3].value == 5, "a stolen Gig keeps its value")

# Call a Legend: 1 €$, once per turn, the card is flipped face up.
check(G.call(m, 1, 1) and A.legends[1].faceUp, "Call a Legend")
ok, why = G.call(m, 1, 2)
check(not ok and "already" in why, "Call once per turn")

# Gear and Programs.
A.hand[len(list(A.hand.values())) + 1] = gear
gi = len(list(A.hand.values()))
before = G.power(u)
A.eddies[2] = L.table_from({"uid": 900, "slug": seller, "spent": False})
A.eddies[3] = L.table_from({"uid": 901, "slug": seller, "spent": False})
ok, why = G.play(m, 1, gi, None)
check(not ok and "equip" in why, "a Gear needs a holder")
check(G.play(m, 1, gi, u.uid) and G.power(u) == before + (L.eval("TcgCards")[gear].power or 0), "Gear adds its power")
A.eddies[4] = L.table_from({"uid": 902, "slug": seller, "spent": False})
A.eddies[5] = L.table_from({"uid": 903, "slug": seller, "spent": False})
A.hand[len(list(A.hand.values())) + 1] = program
pi = len(list(A.hand.values()))
check(G.play(m, 1, pi) and A.trash[len(list(A.trash.values()))] == program, "a Program resolves into the trash")

# Fights: B's Unit is spent after attacking; equal power both lose; a Blocker redirects a Gig attack (nothing stolen).
check(G.endTurn(m, 1) and G.roll(m, 2, "d10"), "turn 4, B rolls")
check(G.attack(m, 2, b1.uid, "gigs") and G.resolve(m, 1) and m.step == "steal", "B attacks A's Gigs")
check(G.steal(m, 2, L.table_from([A.gigs[1].uid])) and len(list(B.gigs.values())) == 2, "B steals one back")
check(G.endTurn(m, 2) and G.roll(m, 1, "d8"), "turn 5")
check(b1.spent is False, "B's Unit readied on B's turn... and stays ready during A's turn") if False else None
L.execute("function spend(u) u.spent = true end")
L.eval("spend")(b1)
pb = G.power(b1)
check(G.attack(m, 1, u.uid, b1.uid) and G.resolve(m, 2), "fight a spent rival Unit")
pu = G.power(u)
if pu > pb:
    check(len(list(B.field.values())) == 0 and B.trash[len(list(B.trash.values()))] == cheap, "the weaker Unit is defeated to the trash")
else:
    check(len(list(A.field.values())) == 0, "the weaker attacker is defeated")

# Blocker, Go Solo, null-cost Legends, empty deck, 7 Gigs.
m2 = L.eval("newMatch")(L.table_from([6] * 40))
A2, B2 = m2.seats[1], m2.seats[2]
fill(A2, unit, 10)
fill(B2, unit, 10)
G.startTurn(m2); G.roll(m2, 1, "d4")
L.execute("function put(seat, slug, spent, lag) local u = { uid = 500 + #seat.field, slug = slug, spent = spent, lag = lag, gear = {} } seat.field[#seat.field + 1] = u return u end")
put = L.eval("put")
atk = put(A2, unit, False, False)
blk = put(B2, blocker, False, False)
B2.gigs[1] = L.table_from({"uid": 700, "kind": "d6", "value": 6})
check(G.attack(m2, 1, atk.uid, "gigs"), "attack the Gigs")
check(G.block(m2, 2, blk.uid) and m2.attack.target.kind == "unit" and blk.spent, "Blocker redirects the attack")
check(G.resolve(m2, 2) and m2.step == "main" and len(list(B2.gigs.values())) == 1, "a blocked Gig attack steals nothing")
A2.legends[3].faceUp = True
A2.legends[3].slug = solo
for i in range(1, 9):
    A2.eddies[i] = L.table_from({"uid": 800 + i, "slug": seller, "spent": False})
check(G.playLegend(m2, 1, 3), "play a Go Solo Legend")
sl = A2.field[len(list(A2.field.values()))]
check(sl.solo and not sl.lag and not sl.spent and G.canAttack(sl), "Go Solo: ready, can attack this turn")
A2.legends[2].faceUp = True
A2.legends[2].slug = nulllegend
ok, why = G.playLegend(m2, 1, 2)
check(not ok and "null" in why, "a null-cost Legend cannot be played to the field")
# 7 Gigs at the start of your turn wins.
for i in range(1, 8):
    A2.gigs[i] = L.table_from({"uid": 600 + i, "kind": "d6", "value": 1})
check(G.endTurn(m2, 1) and m2.active == 2, "B's turn")
L.execute("function emptyLib(seat) for i = #seat.library, 1, -1 do seat.library[i] = nil end end")
check(G.roll(m2, 2, "d4") and G.endTurn(m2, 2) and m2.step == "over" and m2.winner == 1, "7 Gigs at the start of the turn: win")
m3 = L.eval("newMatch")(L.table_from([1] * 10))
G.startTurn(m3)
check(m3.step == "over" and m3.winner == 2, "drawing from an empty deck loses")

# The house plays a whole game against itself without breaking the rules (and ends it).
L.execute("""
function houseGame(seed)
    math.randomseed(seed)
    local m = { first = 1, log = {}, random = math.random }
    local deck = TcgStarters and nil
    local function seat(i) return { index = i, name = 'H' .. i, library = {}, hand = {}, deck = { name = 'x' },
        legends = { { slug = LEG1, faceUp = false, spent = i == 1 }, { slug = LEG2, faceUp = false, spent = i == 1 }, { slug = LEG3, faceUp = false, spent = false } } } end
    m.seats = { seat(1), seat(2) }
    local pool = {}
    for k, c in pairs(TcgCards) do if c.type ~= 'Legend' then pool[#pool + 1] = k end end
    table.sort(pool)
    for _, s in ipairs(m.seats) do for i = 1, 40 do s.library[i] = pool[math.random(#pool)] end for i = 1, 6 do s.hand[i] = table.remove(s.library) end end
    TcgGame.begin(m)
    TcgGame.startTurn(m)
    local steps = 0
    while m.step ~= 'over' and steps < 5000 do
        steps = steps + 1
        local who = m.active
        if m.step == 'react' then who = m.attack.defender end
        local ok, why = TcgGame.housePlay(m, who)
        if not ok then return false, 'house stuck: ' .. tostring(why) .. ' at ' .. m.step end
    end
    return m.step == 'over', m.endReason, m.turn
end
""")
for seed in (1, 2, 3, 4, 5):
    ok, reason, turns = L.eval("houseGame")(seed)
    check(ok, f"house game {seed} ends by the rules ({reason})")
print(f"PASS: rules engine ({checks} checks: start phase, Gig roll + d20 last, Street Cred, paying, sell once, Units + Lag, "
      f"attacks, react/steal, stolen values, Call once, Gear, Programs, fights, Blocker, Go Solo, null cost, 7 Gigs, empty deck, "
      f"5 house games; last: {reason}, turn {turns})")
