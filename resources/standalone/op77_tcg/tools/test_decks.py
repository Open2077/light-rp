"""Deck rules (shared/decks.lua) and table geometry (shared/table.lua) against the real card data.
Usage: python tools/test_decks.py   (needs lupa)"""
import pathlib
import sys

import lupa.lua54 as lupa  # the server runs Lua 5.4 (and lupa's 5.5 build crashes in its GC)

ROOT = pathlib.Path(__file__).resolve().parent.parent
L = lupa.LuaRuntime(unpack_returned_tuples=True)
for f in ["shared/cards.lua", "shared/decks.lua", "shared/starters.lua", "shared/table.lua"]:
    L.execute((ROOT / f).read_text(encoding="utf-8"))
checks = 0


def check(cond, what):
    global checks
    if not cond:
        print("FAIL:", what)
        sys.exit(1)
    checks += 1


validate = L.eval("function(d, owned) local ok, errs, info = TcgDecks.validate(d, owned); return ok, table.concat(errs, ' | '), info end")
deck = L.eval("function(legends, cards) return { legends = legends, cards = cards } end")
tbl = L.table_from
starters = L.eval("TcgStarters")

# The official starter decks are legal (RAM, 40 cards, 3 Legends with different names).
for i in (1, 2):
    s = starters[i]
    ok, errs, info = validate(s, None)
    check(ok, f"starter {s.name} is legal: {errs}")
    check(info["count"] == 40, f"starter {s.name} has 40 cards")
ep = starters[1]
lim = validate(ep, None)[2]["limits"]
check(lim["Red"] + lim["Green"] > 0 and lim["Blue"] == 0 and lim["Yellow"] == 0, "Embracing Power is Red/Green only")

# Each rule.
ok, errs, _ = validate(deck(tbl({1: ep.legends[1], 2: ep.legends[2]}), ep.cards), None)
check(not ok and "Pick 3 Legends" in errs, "3 Legends required")
two_v = deck(tbl({1: "v_streetkid", 2: "v_corporate_exile", 3: ep.legends[3]}), ep.cards)
ok, errs, _ = validate(two_v, None)
check(not ok and "Two Legends named V" in errs, "Legends need different names")
small = L.eval("function(d) local c = {} local n = 0 for k, v in pairs(d.cards) do if n < 30 then c[k] = v n = n + v end end return c end")(ep)
ok, errs, _ = validate(deck(ep.legends, small), None)
check(not ok and "at least 40" in errs, "40 cards minimum")
four = L.eval("function(d) local c = {} for k, v in pairs(d.cards) do c[k] = v end local k = next(c) c[k] = 4 return c end")(ep)
ok, errs, _ = validate(deck(ep.legends, four), None)
check(not ok and "at most 3" in errs, "3 copies maximum")
# RAM: a Blue card in the Red/Green deck is over its colour's limit.
blue = L.eval("function() for k, c in pairs(TcgCards) do if c.color == 'Blue' and c.type ~= 'Legend' and (c.ram or 0) > 0 then return k end end end")()
mixed = L.eval("function(d, extra) local c = {} for k, v in pairs(d.cards) do c[k] = v end c[extra] = 1 return c end")(ep, blue)
ok, errs, _ = validate(deck(ep.legends, mixed), None)
check(not ok and "Blue RAM" in errs, "RAM limit per colour")
leg_in_main = L.eval("function(d) local c = {} for k, v in pairs(d.cards) do c[k] = v end c['v_streetkid'] = 1 return c end")(ep)
ok, errs, _ = validate(deck(ep.legends, leg_in_main), None)
check(not ok and "is a Legend" in errs, "Legends stay out of the main deck")
# Ownership: owning one copy of everything is not enough for a starter's 2-3 copies.
ok, errs, _ = validate(ep, L.eval("function(slug) return 1 end"))
check(not ok and "you own 1" in errs, "owned copies are checked")
ok, _, _ = validate(ep, L.eval("function(slug) return 3 end"))
check(ok, "enough owned copies pass")

# Table geometry: two slots, seats face to face, mats on the table top, zones on the mat.
seats = L.eval("TcgTable.seats(TcgTable.slots[1])")
s1, s2 = seats[1], seats[2]
check(abs(((s2.yaw - s1.yaw) % 360) - 180) < 1e-6, "seats face each other")
d = ((s1.mat.x - s2.mat.x) ** 2 + (s1.mat.y - s2.mat.y) ** 2) ** 0.5
check(0.40 < d < 0.48, f"mats side by side across the table ({d:.3f} m)")
deckpos = L.eval("function(s) return TcgTable.onMat(s, 0.9325, 0.53) end")(s1)
check(abs(deckpos.z - (17.43 + 0.0029)) < 1e-6, "zones sit on the mat")
centre = L.eval("function(s) return TcgTable.onMat(s, 0.5, 0.5) end")(s1)
check(abs(centre.x - s1.mat.x) < 1e-9 and abs(centre.y - s1.mat.y) < 1e-9, "the artwork centre is the mat centre")
check(len(list(L.eval("TcgTable.playmats").values())) == 6, "six playmats")

print(f"PASS: deck rules and table ({checks} checks: starters legal, 3 Legends, unique names, 40-50, 3 copies, RAM per "
      "colour, no Legend in the main deck, owned copies, seats face to face, mat zones)")
