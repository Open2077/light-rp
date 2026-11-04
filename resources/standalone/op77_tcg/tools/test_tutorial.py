"""The tutorial (shared/tutorial.lua) played end to end through the server: every step, the house's scripted turns,
moves out of the script refused, the coach's view. Usage: python tools/test_tutorial.py   (needs lupa)"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from tcg_harness import L, boot, check, checks, fire, last, positions, sent  # noqa: E402

boot("TcgConfig.framework = nil")
pump = L.eval("__pump")
tbl = L.table_from
fire("op77_tcg:hello", 1)
positions[1] = (-818.0, 934.0, 12.2)   # NEON DECK, ground floor
fire("op77_tcg:tutorial", 1)
m = last("match", 1)
check(m is not None and str(m["slot"]) == "nd_c" and m["isTutorial"], "the tutorial sets the nearest free table (ground floor)")
check(m["seats"][2]["house"] is True and int(m["tutorial"]["index"]) == 1, "against the house; the coach is on step 1")
st = L.eval("TcgTable.seats(TcgTable.slotById('nd_c'))")
positions[1] = (st[1].chair.x, st[1].chair.y - 0.5, st[1].chair.z)
fire("op77_tcg:sit", 1)
m = last("match", 1)
steps = L.eval("TcgTutorial.steps")
total = len(list(steps.values()))
check(str(m["phase"]) == "game" and m["tutorial"] is not None and int(m["tutorial"]["index"]) == 1, "seated: the tutorial game starts at step 1")
check(int(m["first"]) == 2 and int(m["seats"][1]["roll"]) == 9 and int(m["seats"][2]["roll"]) == 17, "fixed d20: the house goes first")
hand = str(m["hand"]).split(",")
check(hand == list(L.eval("TcgTutorial.player.hand").values()), "the tutorial's opening hand")

# Out of the script: refused, with the coach's hint.
fire("op77_tcg:act", 1, tbl({"type": "endTurn"}))
check("Tutorial" in str(last("duelRefused", 1)["reason"]), "a move the step doesn't ask for is refused")

seen, guard = [], 0
while guard < 400:
    guard += 1
    m = last("match", 1)
    if m["ended"]:
        break
    t = m["tutorial"]
    if t is None:
        break
    sid = str(t["id"])
    if not seen or seen[-1] != sid:
        seen.append(sid)
    if m["prompt"] is not None and m["prompt"]["mine"]:
        fire("op77_tcg:act", 1, tbl({"type": "answer", "prompt": m["prompt"]["id"], "picks": "1"}))
        continue
    if t["next"]:
        if t["final"]:
            fire("op77_tcg:tutorialNext", 1)
            break
        fire("op77_tcg:tutorialNext", 1)
        continue
    e = t["expect"]
    if e is None:            # the house plays (scripted) or a card effect resolves
        pump(40)
        continue
    hand = str(m["hand"]).split(",")
    if e == "roll":
        die = [r for r in m["options"]["roll"].values() if r["ok"]][0]["die"]
        fire("op77_tcg:act", 1, tbl({"type": "roll", "die": die}))
    elif e == "sell" or e == "play":
        card = str(t["card"])
        i = hand.index(card) + 1
        fire("op77_tcg:act", 1, tbl({"type": e, "hand": i, "card": card}))
    elif e == "call":
        fire("op77_tcg:act", 1, tbl({"type": "call", "legend": 1}))
    elif e == "endTurn" or e == "resolve":
        fire("op77_tcg:act", 1, tbl({"type": e}))
    elif e == "attack":
        atlus = [u for u in m["seats"][1]["field"].values() if str(u["card"]) == "emergency_atlus"][0]
        fire("op77_tcg:act", 1, tbl({"type": "attack", "uid": atlus["uid"], "target": "gigs"}))
    elif e == "steal":
        if str(m["step"]) != "steal":
            pump(40)
            continue
        uid = list(m["options"]["stealable"].values())[0]
        fire("op77_tcg:act", 1, tbl({"type": "steal", "uids": str(uid)}))
    pump(5)

# Every step the player's page was shown, from all the updates sent to player 1.
seen = []
for name, target, payload in sent:
    if name == "op77_tcg:match" and target == 1 and payload is not None and payload["tutorial"] is not None:
        sid = str(payload["tutorial"]["id"])
        if not seen or seen[-1] != sid:
            seen.append(sid)
order = [str(s.id) for s in steps.values()]
check(seen == order, f"every step in order ({len(seen)}/{total}): {[x for x in order if x not in seen][:4]}")
m = last("match", 1)
check(m["tutorial"] is None and str(m["phase"]) == "game" and not m["ended"], "Keep playing: the duel goes on without the coach")
log = " | ".join(str(x) for x in m["log"].values())
logs = []
for name, target, payload in sent:
    if name == "op77_tcg:match" and target == 1 and payload is not None and payload["log"] is not None:
        logs += [str(x) for x in payload["log"].values()]
alllog = " | ".join(logs)
check("blocks with Corpo Security" in alllog and "Fight: Emergency Atlus 4 vs Corpo Security 2" in alllog and "Corpo Security is defeated" in alllog,
      "the Blocker example: block, fight 4 vs 2, Corpo Security defeated")
check("NEON DECK house steals a" in alllog and "Tutorial steals a" not in alllog or "Yuki steals a" in alllog, "steals both ways")
mine = m["seats"][1]
check(int(len(list(mine["gigs"].values()))) >= 2, "the player stole a Gig back")
print(f"PASS: tutorial ({checks[0]} checks: the nearest free table, fixed d20 and hands, refused moves, all {total} steps in order "
      f"(house turns scripted, Call choice, Blocker fight, React, steal both ways), keep playing)")
