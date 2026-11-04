"""op77_tcg server test: the real server/main.lua against stubbed Open77 natives and a real SQLite (in memory).

Runs the whole loop a player goes through: hello (starter packs), opening a pack (roll, persistence, witnesses,
reveal relay), recycling duplicates and printing at a shop, buying, a display box, a trade between two players,
the admin commands and the exports. Usage: python tools/test_server.py   (needs lupa)
"""
import pathlib
import sqlite3
import sys

import lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
L = lupa.LuaRuntime(unpack_returned_tuples=True)
g = L.globals()
con = sqlite3.connect(":memory:")
con.row_factory = sqlite3.Row
sent = []        # (event, target, payload)
props = {}       # id -> dict
prop_seq = [0]
positions = {1: (100.0, 200.0, 10.0), 2: (101.0, 200.5, 10.0), 3: (400.0, 200.0, 10.0)}
names = {1: "Yuki", 2: "Jerem", 3: "Faraway"}


def lua_list(rows):
    t = L.table()
    for i, r in enumerate(rows, 1):
        t[i] = L.table_from(dict(r))
    return t


def params(p):
    return [p[i] for i in range(1, len(p) + 1)] if p is not None else []


def execute(sql, p=None):
    con.executescript(sql) if p is None or len(p) == 0 and ";" in sql.strip().rstrip(";") else con.execute(sql, params(p))
    return 0


def query(sql, p=None):
    return lua_list(con.execute(sql, params(p)).fetchall())


def insert(sql, p=None):
    return con.execute(sql, params(p)).lastrowid


def prop_create(opts):
    prop_seq[0] += 1
    pid = str(prop_seq[0])
    props[pid] = {"model": opts["model"], "attached": None}
    return pid


def prop_attach(pid, binding):
    props[pid]["attached"] = binding["bone"]
    return True


def prop_remove(pid):
    props.pop(pid, None)
    return True


def position(pid):
    p = positions.get(int(pid))
    return L.table_from({"x": p[0], "y": p[1], "z": p[2], "bucket": 0}) if p else None


def nearby(anchor, radius, opts=None):
    out = []
    for pid, p in positions.items():
        d = ((p[0] - anchor["x"]) ** 2 + (p[1] - anchor["y"]) ** 2 + (p[2] - anchor["z"]) ** 2) ** 0.5
        if d <= radius:
            out.append({"playerId": pid, "distance": d})
    return lua_list(out)


def trigger(name, target, payload=None):
    sent.append((name, target, payload))


L.execute("""
local co_list = {}
local clock = 100000.5   -- GetGameTimer is a float on the server
function GetGameTimer() return clock end
function CreateThread(fn) local co = coroutine.create(fn); local ok, err = coroutine.resume(co); if not ok then error(err) end
    if coroutine.status(co) ~= "dead" then co_list[#co_list + 1] = co end end
-- Simulated time: a thread waits until the clock passes its deadline; each pump step is 100 ms.
function Wait(ms) local due = clock + (ms or 0); repeat coroutine.yield() until clock >= due end
function SetTimeout(ms, fn) end
function __pump(n) for _ = 1, n or 50 do clock = clock + 100; local alive = {}
    for _, co in ipairs(co_list) do local ok, err = coroutine.resume(co); if not ok then error(err) end
        if coroutine.status(co) ~= "dead" then alive[#alive + 1] = co end end
    co_list = alive end end
handlers, commands, exported = {}, {}, {}
function RegisterNetEvent(name, fn) handlers[name] = fn end
function AddEventHandler(name, fn) handlers[name] = fn end
function RegisterCommand(name, fn) commands[name] = fn end
function exports(name, fn) exported[name] = fn end
function fire(name, src, ...) source = src; handlers[name](...) ; __pump(60) end
""")
g.TriggerClientEvent = trigger
g.os = None  # the server sandbox has no os library
g.GetUnixTime = None
db_tbl = L.table_from({
    "execute": L.table_from({"await": execute}),
    "query": L.table_from({"await": query}),
    "insert": L.table_from({"await": insert}),
})
g.SQLite = L.table_from({"open": L.table_from({"await": lambda path: db_tbl})})
g.Open77 = L.table_from({
    "time": L.table_from({"unix": lambda: 1793800000.37, "monotonic": lambda: 0}),
    "players": L.table_from({"identifier": lambda p: "id-%d" % p, "position": position, "name": lambda p: names.get(int(p)),
                             "nearby": nearby}),
    "props": L.table_from({"create": prop_create, "attach": prop_attach, "remove": prop_remove, "get": lambda p: None}),
})

for f in ["shared/config.lua", "shared/catalogue.lua", "shared/rules.lua", "server/main.lua"]:
    L.execute((ROOT / f).read_text(encoding="utf-8"))
L.eval("__pump")(10)


def last(name, target=None):
    for n, t, p in reversed(sent):
        if n == "op77_tcg:" + name and (target is None or t == target):
            return p
    return None


def counts(p):
    return {k: int(v) for k, v in (x.split(":") for x in str(p["owned"]).split(",") if x)}


fire = L.eval("fire")
checks = 0


def check(cond, what):
    global checks
    if not cond:
        print("FAIL:", what)
        sys.exit(1)
    checks += 1


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

print(f"PASS: op77_tcg server ({checks} checks: starter, opening persisted before reveal + witnesses + relay, shop, "
      "recycle, print, free pack cooldown, display box, trade, show/place/pickup, exports)")
