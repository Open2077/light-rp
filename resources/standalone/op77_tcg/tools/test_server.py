"""op77_tcg server test, standalone (no framework): accounts, the binder's own sealed shelf, free packs.

Runs the whole loop a player goes through: hello (starter packs), opening a pack (roll, persistence, witnesses,
reveal relay), recycling duplicates and printing at a shop, buying, a display box, a trade between two players,
the admin commands and the exports. Usage: python tools/test_server.py   (needs lupa)
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from tcg_harness import L, animations, boot, check, checks, con, counts, fire, last, props  # noqa: E402

# No framework: `exports` is only the registration function here, so exports.op77_lightrp does not exist.
# The starter gift is off in the shipped config (Light RP's starting inventory carries the boosters);
# the mechanism is still tested here with the old gift.
boot("TcgConfig.framework = nil; TcgConfig.starter = { wnc = 3 }")

# Hello: starter packs.
fire("op77_tcg:hello", 1)
st = last("state", 1)
check(st and st["sealed"]["wnc"] == 3, "starter gives 3 sealed WNC packs")
fire("op77_tcg:hello", 2)

# Opening: 12 cards, persisted before shown, witnesses within 40 m get the opening, the far player does not.
anchor = L.table_from({"x": 100.0, "y": 200.0, "z": 10.0, "yaw": 90.0, "surface": 10.9})
fire("op77_tcg:open", 1, "wnc", anchor)
op1 = last("opening", 1)
check(op1 is not None, "opener receives the opening")
cards = str(op1["cards"]).split(",")
check(len(cards) == 12, "12 cards")
check(last("opening", 2) is not None and last("opening", 3) is None, "witness inside 40 m, not the far player")
db_count = con.execute("SELECT sum(count) FROM tcg_cards WHERE identifier = 'id-1'").fetchone()[0]
check(db_count == 12, "the 12 cards are in the database before any reveal")
check(con.execute("SELECT count FROM tcg_sealed WHERE identifier='id-1' AND product='wnc'").fetchone()[0] == 2, "one sealed pack spent")
check(con.execute("SELECT count(*) FROM tcg_pulls").fetchone()[0] == 1, "pull logged")
# A second opening before the first is done is refused.
fire("op77_tcg:open", 1, "wnc", anchor)
check(str(last("opening", 1)["seq"]) == str(op1["seq"]), "no second opening while one is in the hands")
# Reveal relay.
fire("op77_tcg:reveal", 1, L.table_from({"seq": op1["seq"], "stage": "tear"}))
check(last("reveal", 2)["stage"] == "tear", "tear relayed to witnesses")
fire("op77_tcg:reveal", 1, L.table_from({"seq": op1["seq"], "stage": "card", "index": 12}))
r = last("reveal", 2)
check(r["index"] == 12 and r["finished"], "the last card finishes the opening")
# The opener's act: an animation while the pack is in the hands, stopped with the last card.
played = [a for a in animations if a[0] == 1 and a[1] == "tablet2"]
check(len(played) >= 1, "the opener plays the opening animation")
check(any(a[0] == 1 and a[1] == "stop" for a in animations), "the animation stops with the last card")
# A request that goes nowhere tells the opener's page (its "opening..." screen goes away).
fire("op77_tcg:open", 1, "nope", anchor)
check(last("openFailed", 1) is not None, "a refused pack request sends openFailed")
# The request lock is released once a pack is dealt: the next pack opens (Open another).
fire("op77_tcg:open", 1, "wnc", anchor)
op2 = last("opening", 1)
check(op2 is not None and str(op2["seq"]) != str(op1["seq"]), "after a finished pack, the next one opens")
fire("op77_tcg:reveal", 1, L.table_from({"seq": op2["seq"], "stage": "card", "index": 12}))
# (that extra pack is given back so the shop checks below keep their counts)
L.eval("exported.giveBooster")(1, "wnc", 1)
L.eval("__pump")(20)

# Recycle needs a shop; place one with the admin command at player 1.
fire_cmd = L.eval("function(name, src, args) commands[name](src, args); __pump(60) end")
fire_cmd("tcg.shop", 1, L.table_from({1: "here", 2: "Test Shop"}))
check(con.execute("SELECT count(*) FROM tcg_shops").fetchone()[0] == 1, "shop stored")
check(sum(1 for p in props.values() if "machines" in p["model"]) >= 3, "shop machines spawned")
# Give a duplicate and recycle it.
edition = cards[0]
fire_cmd("tcg.card", 0, L.table_from({1: "1", 2: edition}))
before = counts(last("state", 1)).get(edition, 0)
fire("op77_tcg:recycle", 1, edition, before - 1)
st = last("state", 1)
check(counts(st).get(edition, 0) == 1 and st["dust"] > 0, "duplicates recycled into Dust, one copy kept")
fire("op77_tcg:recycle", 1, edition, 1)
check(counts(last("state", 1)).get(edition, 0) == 1, "the last copy cannot be recycled")
# Print a missing common.
missing = L.eval("""function(owned) for _, e in ipairs(TcgCatalogue) do if e.tier == 1 and not owned[e.id] then return e.id end end end""")(
    L.table_from(counts(last("state", 1))))
fire_cmd("tcg.dust", 0, L.table_from({1: "1", 2: "500"}))
dust = last("state", 1)["dust"]
fire("op77_tcg:print", 1, missing)
st = last("state", 1)
check(counts(st).get(missing) == 1 and st["dust"] == dust - 40, "a missing common printed for 40 Dust")
check(last("printed", 2) is not None, "the printer moment reaches the player beside")

# Buying: free pack, then the cooldown.
fire("op77_tcg:buy", 1, "wnc")
check(last("state", 1)["sealed"]["wnc"] == 3, "free pack taken at the shop")
fire("op77_tcg:buy", 1, "wnc")
check(last("state", 1)["sealed"]["wnc"] == 3, "second free pack refused (cooldown)")

# Display box: given by an admin, cut open into 24 packs.
fire_cmd("tcg.give", 0, L.table_from({1: "1", 2: "box", 3: "1"}))
fire("op77_tcg:unbox", 1, "box")
check(last("state", 1)["sealed"]["wnc"] == 27 and last("state", 1)["sealed"]["box"] == 0, "box into 24 packs")

# Trade: 1 offers a card to 2 (1.1 m away), 2 accepts.
give = cards[5]
have = counts(last("state", 1)).get(give, 0)
fire("op77_tcg:offer", 1, 2, give)
offer = last("offer", 2)
check(offer is not None and offer["edition"] == give, "offer delivered")
fire("op77_tcg:answer", 2, offer["id"], True)
check(counts(last("state", 1)).get(give, 0) == have - 1 and counts(last("state", 2)).get(give, 0) >= 1, "card moved from 1 to 2")
# Offer to the far player is refused.
fire("op77_tcg:offer", 1, 3, cards[6])
check(last("offer", 3) is None, "no trade with a far player")

# Show and place.
fire("op77_tcg:show", 1, cards[6])
check(any(p["attached"] == "RightHand" for p in props.values()), "shown card attached to the right hand")
fire("op77_tcg:place", 1, cards[7], L.table_from({"x": 100.5, "y": 200.0, "z": 10.9}), 90)
placed = last("placed")
check(placed is not None, "card placed on the table")
fire("op77_tcg:pickup", 1, placed["prop"])
check(last("pickedUp") is not None, "card picked up")

# Exports.
check(L.eval("exported.giveBooster")(2, "beta", 2), "export giveBooster")
L.eval("__pump")(60)
check(last("state", 2)["sealed"]["beta"] == 2, "beta packs given by export")
coll = L.eval("exported.getCollection")(1)
check(coll["editions"] > 0 and coll["totalEditions"] == 320, "export getCollection")

# The NEON DECK welcome (client/welcome.lua): "seen" is per collector, in tcg.db, and the state says it.
check(last("state", 2)["welcomed"] is False, "a new collector has not seen the welcome")
fire("op77_tcg:seen", 2, "welcome")
check(con.execute("SELECT count(*) FROM tcg_seen WHERE identifier = 'id-2' AND what = 'welcome'").fetchone()[0] == 1, "welcome seen: stored")
fire("op77_tcg:seen", 2, "welcome")
check(con.execute("SELECT count(*) FROM tcg_seen").fetchone()[0] == 1, "seen twice: one row")
fire("op77_tcg:seen", 2, "anything")
check(con.execute("SELECT count(*) FROM tcg_seen").fetchone()[0] == 1, "an unknown flag is ignored")
fire("op77_tcg:state", 2)
check(last("state", 2)["welcomed"] is True, "the state says the welcome was seen")
fire("op77_tcg:state", 1)
check(last("state", 1)["welcomed"] is False, "another collector still has it to see")

# Client: the pack-request lock is a local declared before the handlers that clear it (a later `local` made the
# opening handler clear a global instead: "The server did not answer" 20 s after every pack, live 2026-11-05).
src = (pathlib.Path(__file__).resolve().parent.parent / "client" / "main.lua").read_text(encoding="utf-8").splitlines()
decl = next(i for i, x in enumerate(src) if x.startswith("local pendingOpen"))
first = next(i for i, x in enumerate(src) if "pendingOpen" in x.split("--")[0])
check(first == decl, f"client/main.lua: pendingOpen declared (line {decl + 1}) before its first use (line {first + 1})")
print(f"PASS: op77_tcg server ({checks[0]} checks: starter, opening persisted before reveal + witnesses + relay, shop, "
      "recycle, print, free pack cooldown, display box, trade, show/place/pickup, exports, welcome seen)")
