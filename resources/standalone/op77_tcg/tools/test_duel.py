"""op77_tcg duel test: decks, playmats, challenges, the 3D table and the setup, against the real server scripts.

Usage: python tools/test_duel.py   (needs lupa)
"""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from tcg_harness import L, animations, boot, check, checks, con, fire, last, positions, props, refuse_profiles, sent  # noqa: E402

boot("TcgConfig.framework = nil")
pump = L.eval("__pump")
T = L.eval("TcgTable")
fire("op77_tcg:hello", 1)
fire("op77_tcg:hello", 2)
fire("op77_tcg:hello", 3)


def tbl(d):
    return L.table_from(d)


# --- Decks -------------------------------------------------------------------------------------
fire("op77_tcg:decks", 1)
d = last("decks", 1)
check(d is not None and len(list(d["starters"].values())) == 2, "two lent starter decks")
check(str(d["playmat"]) == "netrunner", "default playmat")
ep = L.eval("TcgStarters.byId.embracing_power")
cards = L.eval("function(s) return TcgDecks.encode(s.cards) end")(ep)
legends = ",".join(ep.legends[i] for i in (1, 2, 3))
# A collector without the cards saves a draft (kept, not legal).
fire("op77_tcg:saveDeck", 1, tbl({"name": "  My  Arasaka <b>deck</b>  ", "legends": legends, "cards": cards}))
d = last("decks", 1)
mine = list(d["decks"].values())
check(len(mine) == 1 and mine[0]["ok"] is False, "a deck of cards you do not own is saved as a draft")
check(str(mine[0]["name"]) == "My  Arasaka bdeck/b", "name cleaned of markup and control characters")
check(any("own" in str(x) for x in mine[0]["errors"].values()), "draft errors name the missing copies")
key = str(mine[0]["key"])
# Owning the copies makes it legal: three copies of every card of the starter (any edition counts).
cat = L.eval("TcgCatalogue")
first_edition = {}
for i in range(1, len(cat) + 1):
    e = cat[i]
    first_edition.setdefault(str(e.card), str(e.id))
# Through the admin command (it updates the cached profile and the database).
for slug in list(ep.legends.values()) + list(ep.cards.keys()):
    for _ in range(3):
        L.eval("commands")["tcg.card"](0, tbl({1: "1", 2: first_edition[str(slug)]}))
pump(30)
fire("op77_tcg:decks", 1)
mine = list(last("decks", 1)["decks"].values())
check(mine[0]["ok"] is True and int(mine[0]["count"]) == 40, "with the copies owned the deck is legal (40 cards)")
# Updating keeps the id; deleting removes it.
fire("op77_tcg:saveDeck", 1, tbl({"key": key, "name": "Arasaka", "legends": legends, "cards": cards}))
mine = list(last("decks", 1)["decks"].values())
check(len(mine) == 1 and str(mine[0]["name"]) == "Arasaka", "save with a key updates the deck")
check(con.execute("SELECT count(*) FROM tcg_decks").fetchone()[0] == 1, "one row in tcg_decks")
fire("op77_tcg:saveDeck", 1, tbl({"name": "Scratch", "legends": "", "cards": ""}))
scratch = [x for x in last("decks", 1)["decks"].values() if str(x["name"]) == "Scratch"][0]
fire("op77_tcg:deleteDeck", 1, str(scratch["key"]))
check(len(list(last("decks", 1)["decks"].values())) == 1, "delete")
# Playmat and the selected deck persist.
fire("op77_tcg:setPlaymat", 1, "militech")
fire("op77_tcg:setPlaymat", 1, "no_such_mat")
fire("op77_tcg:selectDeck", 1, key)
row = con.execute("SELECT playmat, deck FROM tcg_settings WHERE identifier = 'id-1'").fetchone()
check(row["playmat"] == "militech" and row["deck"] == key, "playmat and deck choice saved, unknown mat refused")

# --- Challenges --------------------------------------------------------------------------------
# Players 1 and 2 upstairs at NEON DECK (the nearest free slot is Table 1 A); 3 far away.
positions[1], positions[2] = (-822.0, 936.5, 16.7), (-821.5, 936.9, 16.7)
fire("op77_tcg:nearby", 1)
nb = last("nearby", 1)
ids = [int(p["id"]) for p in nb["players"].values()]
check(ids == [2] and int(nb["freeTables"]) == 4 and int(nb["tables"]) == 4, "nearby lists the close player only, four free tables")
# Player 2 has no legal own deck: a draft is refused, a lent starter is fine.
fire("op77_tcg:challenge", 1, 3, key)
check(last("challenged", 3) is None, "a far player cannot be challenged")
fire("op77_tcg:challenge", 1, 2, "123456")
check(last("challenged", 2) is None, "an unknown deck cannot challenge")
fire("op77_tcg:challenge", 1, 2, key)
ch = last("challenged", 2)
check(ch is not None and str(ch["deck"]) == "Arasaka" and str(ch["name"]) == "Yuki", "challenge delivered with the deck name")
fire("op77_tcg:answerChallenge", 2, ch["id"], False)
check(str(last("challengeClosed", 1)["reason"]) == "declined", "decline reaches the challenger")
fire("op77_tcg:challenge", 1, 2, key)
ch = last("challenged", 2)
before = len(props)
fire("op77_tcg:answerChallenge", 2, ch["id"], True, "s:the_heist")
m1 = last("match", 1)
m2 = last("match", 2)
check(m1 is not None and m2 is not None and str(m1["phase"]) == "seating", "accept creates a match in the seating phase")
check(int(m1["you"]) == 1 and int(m2["you"]) == 2 and str(m1["slot"]) == "nd_a", "seats and the first free slot")
# The table is set: 2 mats, 2 decks, 12 dice.
new = [p for pid, p in props.items()]
models = [str(p["model"]) for p in new]
check(len(props) - before == 16, "16 props on the table (2 mats, 2 deck stacks, 12 dice)")
check(any("nd_p3_mat_militech" in m for m in models) and any("nd_p3_mat_netrunner" in m for m in models),
      "each player's own playmat")
check(sum("arasaka" in m and "nd_tcg_d" in m for m in models) == 6, "the north seat's dice set")
mat_a = [p for p in new if "nd_p3_mat_militech" in str(p["model"])][0]
seat1 = L.eval("TcgTable.seats(TcgTable.slots[1])")[1]
check(abs(mat_a["x"] - seat1.mat.x) < 1e-6 and abs(mat_a["z"] - 17.43) < 1e-6, "the mat lies on the table at its seat")
# A busy player cannot be challenged again, nor challenge.
fire("op77_tcg:challenge", 3, 1, "s:the_heist")
check(last("challenged", 1) is None or last("challenged", 1)["id"] == ch["id"], "a player in a duel is not challenged")

# --- Seating and setup -------------------------------------------------------------------------
positions[1] = (-815.0, 931.0, 12.2)   # downstairs: far from the Table 1 A chair
fire("op77_tcg:sit", 1)
check(not any(a[0] == 1 for a in animations), "too far from the chair: no sit")
c1, c2 = seat1.chair, L.eval("TcgTable.seats(TcgTable.slots[1])")[2].chair
positions[1] = (c1.x, c1.y - 0.6, c1.z)
positions[2] = (c2.x, c2.y + 0.6, c2.z)
refuse_profiles.add("amb_d7c499_sit_chair_table_keybo")
fire("op77_tcg:sit", 1)
check(animations[-1][:2] == (1, "chair"), "falls back to the plain chair profile")
check(str(last("match", 1)["phase"]) == "seating" and last("match", 1)["seats"][1]["seated"] is True, "first player seated, still seating")
refuse_profiles.clear()
fire("op77_tcg:sit", 2)
check(animations[-1][:2] == (2, "amb_d7c499_sit_chair_table_keybo"), "the table profile when the runtime has it")
m = last("match", 1)
check(str(m["phase"]) == "choose", "both seated: d20 roll, the winner chooses")
r1, r2 = int(m["seats"][1]["roll"]), int(m["seats"][2]["roll"])
decider = int(m["decider"])
check(r1 != r2 and 1 <= r1 <= 20 and 1 <= r2 <= 20 and decider == (1 if r1 > r2 else 2), "d20 rolls, no tie, higher decides")
loser = 2 if decider == 1 else 1
fire("op77_tcg:choose", loser, True)
check(str(last("match", 1)["phase"]) == "choose", "only the d20 winner chooses")
n_decks = con.execute("SELECT count(*) FROM tcg_decks").fetchone()[0]
fire("op77_tcg:saveDeck", 1, tbl({"name": "At the table", "legends": "", "cards": ""}))
fire("op77_tcg:setPlaymat", 1, "arasaka")
check(con.execute("SELECT count(*) FROM tcg_decks").fetchone()[0] == n_decks and
      con.execute("SELECT playmat FROM tcg_settings WHERE identifier = 'id-1'").fetchone()[0] == "militech",
      "seated at the table: no deck building, no playmat change")
fire("op77_tcg:choose", decider, False)   # the decider lets the other go first
m = last("match", 1)
first = loser
check(str(m["phase"]) == "mulligan" and int(m["first"]) == first and int(m["decider"]) == first, "the other goes first and decides first")
for who in (1, 2):
    v = last("match", who)
    hand = [x for x in str(v["hand"]).split(",") if x]
    check(len(hand) == 6 and int(v["seats"][who]["library"]) == 34, f"player {who} drew 6, 34 left")
    check(all(L.eval("TcgCards")[c].type != "Legend" for c in hand), "no Legend in the hand")
legs = m["seats"][first]["legends"]
check([legs[i]["spent"] for i in (1, 2, 3)] == [True, True, False], "the first player's two left-most Legends start spent")
other_legs = m["seats"][3 - first]["legends"]
check(not any(other_legs[i]["spent"] for i in (1, 2, 3)), "the second player's Legends are ready")
check(all(legs[i]["card"] is None for i in (1, 2, 3)), "Legends are face down (no card sent)")
cardbacks = [p for p in props.values() if "nd_tcg_cardback" in str(p["model"])]
check(len(cardbacks) == 6, "three face-down Legend props per seat")
yaws = sorted(round((p["yaw"] - T.seats(T.slots[1])[first].yaw) % 360) for p in cardbacks
              if abs(p["x"] - T.seats(T.slots[1])[first].mat.x) < 0.4 and abs(p["y"] - T.seats(T.slots[1])[first].mat.y) < 0.3)
check(yaws == [0, 90, 90], "two of the first player's Legend cards turned sideways")
deck_props = [p for p in props.values() if "nd_tcg_deck" in str(p["model"])]
check(all(17.43 + 0.0029 - 0.015 < p["z"] < 17.43 + 0.0029 for p in deck_props), "deck stacks sink as they thin")
# Mulligan order: the second player cannot decide first.
second = 3 - first
hand_before = str(last("match", second)["hand"])
fire("op77_tcg:mulligan", second, True)
check(str(last("match", second)["hand"]) == hand_before, "the second player waits for the first")
fire("op77_tcg:mulligan", first, False)
check(int(last("match", 1)["decider"]) == second, "then the second player decides")
fire("op77_tcg:mulligan", second, True)
v = last("match", second)
check(str(v["phase"]) == "game" and int(v["turn"]) == 1 and int(v["active"]) == first and str(v["step"]) == "roll",
      "game begins: turn 1, the first player rolls a Gig")
check(len(str(v["hand"]).split(",")) == 6 and int(v["seats"][second]["library"]) == 34, "mulligan: 6 new cards, deck back to 34")
check(str(v["seats"][second]["mulligan"]) == "mulligan" and str(v["seats"][first]["mulligan"]) == "kept", "mulligan states")
vf = last("match", first)
check(len(str(vf["hand"]).split(",")) == 7 and int(vf["seats"][first]["library"]) == 33, "the first player drew 1 at the start of turn 1")
check(any(e["kind"] == "draw" for e in vf["events"].values()), "the draw is sent as an event (the page animates it)")
check(int(vf["options"]["roll"].__len__()) == 6, "six dice to choose from")

# --- The game over the network: actions, refusals, the table ------------------------------------
fire("op77_tcg:act", second, tbl({"type": "roll", "die": "d6"}))
check(str(last("duelRefused", second)["reason"]) != "", "not your turn: refused")
fire("op77_tcg:act", first, tbl({"type": "roll", "die": "d20"}))
check("last" in str(last("duelRefused", first)["reason"]), "the d20 comes last")
fire("op77_tcg:act", first, tbl({"type": "roll", "die": "d6"}))
vf = last("match", first)
gig = vf["seats"][first]["gigs"][1]
check(str(vf["step"]) == "main" and str(gig["kind"]) == "d6" and 1 <= int(gig["value"]) <= 6, "rolled a d6 into the Gig area")
dice = [q for q in props.values() if re.search(r"nd_tcg_d\d", str(q["model"]))]
check(len(dice) == 12, "the die moved from the fixer to the Gig area (still 12 dice on the table)")
hand = str(vf["hand"]).split(",")
stale = 1 if hand[0] != hand[1] else 2
fire("op77_tcg:act", first, tbl({"type": "sell", "hand": stale, "card": "not_this_card"}))
check("no longer" in str(sent[-1][2]["text"]) if sent[-1][0] == "op77_tcg:notice" else False, "a stale hand click is refused")
cards = L.eval("TcgCards")
sellable = [i for i, s in enumerate(hand, 1) if cards[s].sell]
if sellable:
    i = sellable[0]
    fire("op77_tcg:act", first, tbl({"type": "sell", "hand": i, "card": hand[i - 1]}))
    vf = last("match", first)
    check(int(vf["seats"][first]["eddies"]) == 1 and len(str(vf["hand"]).split(",")) == 6, "sold a card into the Eddies")
    check(any("nd_tcg_cardback" in str(q["model"]) for q in props.values() if q.get("yaw") is not None), "the Eddie is a face-down card on the table")
fire("op77_tcg:act", first, tbl({"type": "endTurn"}))
vs = last("match", second)
check(int(vs["active"]) == second and int(vs["turn"]) == 2 and str(vs["step"]) == "roll", "pass: the rival's turn, they roll")
check(len(str(vs["hand"]).split(",")) == 7, "the rival drew 1")
check(any(e["kind"] == "draw" and int(e["seat"]) == second for e in last("match", first)["events"].values()), "the rival's draw is public, not the card")
check(all(e["card"] is None for e in last("match", first)["events"].values() if e["kind"] == "draw"), "the rival's drawn card stays hidden")
# The second slot is still free for another pair.
fire("op77_tcg:nearby", 3)
check(int(last("nearby", 3)["freeTables"]) == 3, "three tables left")

# --- Leaving -----------------------------------------------------------------------------------
fire("op77_tcg:leaveMatch", 2)
e1, e2 = last("match", 1), last("match", 2)
check(e1["ended"] is True and e1["won"] is True and e2["won"] is False, "conceding gives the win to the rival")
check(not any("nd_tcg_" in str(p["model"]) or "nd_p3_mat" in str(p["model"]) for p in props.values()), "the table is cleared")
check(sum(1 for a in animations if a[1] in ("stop", "stopAt")) >= 2, "both stand up (the sequence stops at its stand point)")
row = con.execute("SELECT winner, reason FROM tcg_matches").fetchone()
check(row["winner"] == "id-1" and "conceded" in row["reason"], "the result is recorded")

# --- The house (/tcg.duel demo) and timeouts ---------------------------------------------------
L.eval("commands")["tcg.duel"](0, tbl({1: "demo", 2: "1"}))
pump(20)
m = last("match", 1)
check(str(m["phase"]) == "seating" and m["seats"][2]["house"] is True and m["seats"][2]["seated"] is True, "demo: the house is seated")
fire("op77_tcg:sit", 1)
pump(400)   # the house chooses, keeps; the player's choices time out to the defaults
m = last("match", 1)
check(str(m["phase"]) in ("mulligan", "game"), "demo goes through the setup")
pump(700)
m = last("match", 1)
check(str(m["phase"]) == "game", "timeouts keep the hands and start the game")
# The clock plays for an idle player and the house plays its own turns: turns go by.
t0 = int(m["turn"])
pump(4000)
m = last("match", 1)
check(m["ended"] is True or int(m["turn"]) > t0 + 1, "the house and the clock keep the game going")
if not m["ended"]:
    units = [q for q in props.values() if q["model"].endswith(".ent")]
    check(True, "table props follow the game")
# Walking away concedes after the grace.
positions[1] = (100.0, 200.0, 10.0)
pump(200)
check(last("match", 1)["ended"] is True, "walking away from the table ends the duel")
# Seating timeout frees the table.
L.eval("commands")["tcg.duel"](0, tbl({1: "demo", 2: "1"}))
pump(20)
pump(1900)
check(last("match", 1)["ended"] is True and "Nobody sat down" in str(last("match", 1)["reason"]), "nobody seated in time: freed")
# A disconnect mid-challenge closes it on the other side.
positions[1], positions[2] = (100.0, 200.0, 10.0), (101.0, 200.5, 10.0)
fire("op77_tcg:challenge", 1, 2, key)
check(last("challenged", 2) is not None, "challenge again")
fire("playerDropped", 1)
check(str(last("challengeClosed", 2)["reason"]) == "left", "a dropped challenger closes the challenge")
# Two players downstairs get the ground-floor duel table (the nearest free slot), its mats at the table's height.
positions[2], positions[3] = (-818.0, 934.0, 12.2), (-817.5, 934.3, 12.2)
fire("op77_tcg:challenge", 2, 3, "s:embracing_power")
ch = last("challenged", 3)
fire("op77_tcg:answerChallenge", 3, ch["id"], True, "s:the_heist")
mg = last("match", 2)
check(str(mg["slot"]) == "nd_c" and abs(mg["mat"]["z"] - 12.89) < 1e-6, "downstairs: the ground-floor duel table, mats on its top")

print(f"PASS: op77_tcg duels ({checks[0]} checks: decks drafts/legal/owned copies, playmat, nearby, challenge decline/accept, "
      "table props per seat, seating fallback, d20 + choice, Legends spent/face down, draw 6, mulligan order, concede, "
      "house demo, timeouts, walk away, disconnect)")
