"""Private rooms under NEON DECK (server/rooms.lua, shared/rooms.lua): the host, creating a room (a code, its own
bucket, the players taken down), joining with the code, a duel at the room's table (its own instance slot, props in
the room's bucket), leaving (back up, out of the duel), a room nobody is in closing, and the door for someone who
stands in a room without being in one. Usage: python tools/test_rooms.py   (needs lupa)"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from tcg_harness import L, boot, buckets, check, checks, fire, last, npcs, positions, props, sent, teleports  # noqa: E402

boot("TcgConfig.framework = nil")
pump = L.eval("__pump")
pump(30)
check(len(npcs) == 1 and str(list(npcs.values())[0]["record"]).startswith("Character."), "the host NPC stands at the counter")
for p in (1, 2, 3):
    fire("op77_tcg:hello", p)

R = L.eval("TcgRooms")
talk = L.eval("TcgRooms.talkPoint()")
far = (talk.x + 30, talk.y, talk.z)

def at_host(p):
    positions[p] = (talk.x, talk.y, talk.z)
    buckets[p] = 0

def notice(p):
    n = last("notice", p)
    return str(n["text"]) if n is not None else ""

# Creating a room needs the host.
positions[1] = far
fire("op77_tcg:roomCreate", 1, "jp")
check("host" in notice(1) and not buckets.get(1), "far from the counter: no room")
at_host(1)
fire("op77_tcg:roomCreate", 1, "nope")
check("Unknown room" in notice(1), "an unknown style is refused")
fire("op77_tcg:roomCreate", 1, "jp")
st = last("roomState", 1)
room = st["room"]
code = str(room["code"])
b1 = buckets.get(1)
check(room is not None and str(room["style"]) == "jp" and len(code) == 5, "the room is opened with a 5-character code")
check(b1 is not None and b1 > 5200000, "the player is in the room's own bucket")
arr = L.eval("TcgRooms.arrival('jp', 1)")[0]
check(abs(positions[1][0] - arr.x) < 0.01 and abs(positions[1][2] - arr.z) < 0.01, "taken down to the Tatami room's arrival point")
check(last("roomEntered", 1) is not None, "the page is told the room was entered")
check(L.eval("TcgRooms.styleAt")(L.table_from({"x": positions[1][0], "y": positions[1][1], "z": positions[1][2]})) == "jp",
      "the arrival point is inside the Tatami room's volume")

# Joining with the code.
positions[2] = far
fire("op77_tcg:roomJoin", 2, code)
check("host" in notice(2) and not buckets.get(2), "joining also goes through the host")
at_host(2)
fire("op77_tcg:roomJoin", 2, "ZZZZZ")
check("No room" in notice(2), "a wrong code is refused")
fire("op77_tcg:roomJoin", 2, code.lower())
check(buckets.get(2) == b1, "the friend joins the same bucket (the code is case-insensitive)")
r2 = last("roomState", 1)["room"]
check(int(r2["count"]) == 2 and "Jerem" in [str(x) for x in r2["players"].values()], "both members see the room with 2 players")
check(abs(positions[2][0] - positions[1][0]) > 0.3, "the second player arrives beside the first one")

# A duel in the room uses the room's own table.
fire("op77_tcg:nearby", 1)
nb = last("nearby", 1)
check(int(nb["tables"]) == 2 and int(nb["freeTables"]) == 2, "in the room, its two duel slots are the ones offered")
fire("op77_tcg:tutorial", 1)
m = last("match", 1)
check(m is not None and str(m["slot"]).startswith("rm_jp_") and str(m["slot"]).endswith("@%d" % b1), "a duel in the room takes its instance slot")
mats = [p for p in props.values() if "playmat" in str(p.get("model", "")).lower() or "mat" in str(p.get("model", "")).lower()]
check(len(props) > 0, "the table is set (props created)")

# Leaving: back up to the shop, out of the duel, the room keeps its other member.
fire("op77_tcg:roomExit", 1)
back = L.eval("TcgRooms.backPoint()")[0]
check(buckets.get(1) == 0 and abs(positions[1][0] - back.x) < 0.01, "the exit takes the player back up, public bucket")
check(last("roomState", 1)["room"] is None, "the player is no longer in a room")
m = last("match", 1)
check(m is None or m["ended"], "the duel ended when its player left the room")
check(int(last("roomState", 2)["room"]["count"]) == 1, "the room keeps its other member")

# The last member leaves: the room closes after a while.
fire("op77_tcg:roomExit", 2)
check(L.eval("next(TcgRoomState.rooms) ~= nil"), "an empty room stays open a moment (a friend may come back)")
pump(int(L.eval("TcgRooms.emptyCloseMs")) // 100 + 400)
check(L.eval("next(TcgRoomState.rooms) == nil"), "an empty room closes after emptyCloseMs")
at_host(1)
fire("op77_tcg:roomJoin", 1, code)
check("No room" in notice(1), "its code no longer works")

# Someone standing in a room without being in one (a reconnect) is brought up by the door too.
inside = L.eval("TcgRooms.exitPoint('cozy')")
positions[3] = (inside.x, inside.y, inside.z + 0.05)
buckets[3] = 0
fire("op77_tcg:roomExit", 3)
check(abs(positions[3][0] - back.x) < 0.01, "a stray player in a room is brought up")
positions[3] = far
n_before = len(teleports)
fire("op77_tcg:roomExit", 3)
check(len(teleports) == n_before, "the door does nothing for someone outside the rooms")

print(f"PASS: private rooms ({checks[0]} checks: host NPC, create at the counter only, code + own bucket, arrival point, join by code, "
      f"the room's two duel slots, leave = back up + out of the duel, empty room closes, stray player brought up)")
