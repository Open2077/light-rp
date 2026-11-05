"""Shared harness of the op77_tcg server tests: the real server/main.lua against stubbed Open77 natives and a real
SQLite (in memory). boot(prelude) runs `prelude` (Lua) after the stubs and before the resource, e.g. to give the
resource a framework to talk to (tools/test_framework.py).
"""
import pathlib
import sqlite3
import sys

import lupa.lua54 as lupa  # the server runs Lua 5.4 (and lupa's 5.5 build crashes in its GC)

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
    pos = opts["position"]
    props[pid] = {"model": opts["model"], "attached": None, "x": pos["x"], "y": pos["y"], "z": pos["z"], "yaw": opts["yaw"] or 0}
    return pid


def prop_move(pid, transform):
    if pid not in props:
        return False
    pos = transform["position"]
    props[pid].update(x=pos["x"], y=pos["y"], z=pos["z"], yaw=transform["yaw"])
    return True


animations = []  # (player, profile, clip) played; profiles in refuse_profiles fail like an unknown runtime profile
refuse_profiles = set()


def play_at(player, profile, at, yaw, opts=None):
    if profile in refuse_profiles:
        return None, "unknown_profile"
    animations.append((int(player), profile, opts["clip"] if opts else None))
    return L.table_from({"playbackId": "pb-%d" % len(animations)})


def sequence_at(player, steps, at, yaw, opts=None):
    step = steps[1]
    if step["profile"] in refuse_profiles or "sequence" in refuse_profiles:
        return None, "unknown_profile"
    animations.append((int(player), step["profile"], step["clip"]))
    return L.table_from({"playbackId": "seq-%d" % len(animations)})


def anim_play(player, profile, opts=None):
    if profile in refuse_profiles:
        return None, "unknown_profile"
    animations.append((int(player), profile, opts["clip"] if opts else None))
    return L.table_from({"playbackId": "play-%d" % len(animations)})


def anim_stop_at(playback):
    animations.append((None, "stopAt", playback))
    return True


def anim_stop(player, playback):
    animations.append((int(player), "stop", playback))
    return True


def prop_attach(pid, binding):
    props[pid]["attached"] = binding["bone"]
    return True


def prop_remove(pid):
    props.pop(pid, None)
    return True


buckets = {}     # player -> routing bucket (0 when absent)
teleports = []   # (player, x, y, z, bucket)
npcs = {}        # id -> definition


def position(pid):
    p = positions.get(int(pid))
    return L.table_from({"x": p[0], "y": p[1], "z": p[2], "bucket": buckets.get(int(pid), 0)}) if p else None


def teleport(pid, pos, opts=None):
    pid = int(pid)
    b = opts["bucket"] if opts is not None and opts["bucket"] is not None else buckets.get(pid, 0)
    positions[pid] = (pos["x"], pos["y"], pos["z"])
    buckets[pid] = int(b)
    teleports.append((pid, pos["x"], pos["y"], pos["z"], int(b)))
    res = L.table_from({"x": pos["x"], "y": pos["y"], "z": pos["z"], "state": "settled"})
    return L.table_from({"await": lambda self=None: res})


def npc_create(d):
    nid = "npc%d" % (len(npcs) + 1)
    npcs[nid] = d
    return nid


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
function SetTimeout(ms, fn) CreateThread(function() Wait(ms); fn() end) end
function __pump(n) for _ = 1, n or 50 do clock = clock + 100; local alive = {}
    for _, co in ipairs(co_list) do local ok, err = coroutine.resume(co); if not ok then error(err) end
        if coroutine.status(co) ~= "dead" then alive[#alive + 1] = co end end
    co_list = alive end end
handlers, commands, exported = {}, {}, {}
function RegisterNetEvent(name, fn) handlers[name] = fn end
function AddEventHandler(name, fn)   -- several handlers per event (main.lua and duel.lua both watch playerDropped)
    local prev = handlers[name]
    handlers[name] = prev and function(...) prev(...); fn(...) end or fn end
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
                             "nearby": nearby, "teleport": teleport}),
    "routingBuckets": L.table_from({"getPlayer": lambda p: buckets.get(int(p), 0),
                                    "setPlayer": lambda p, b: buckets.__setitem__(int(p), int(b)),
                                    "setPopulationEnabled": lambda b, on: True}),
    "npcs": L.table_from({"create": npc_create, "setAIEnabled": lambda i, on: True, "remove": lambda i: npcs.pop(i, None) is not None}),
    "props": L.table_from({"create": prop_create, "attach": prop_attach, "remove": prop_remove, "get": lambda p: None,
                           "setTransform": prop_move}),
    "animations": L.table_from({"play": anim_play, "playAt": play_at, "stop": anim_stop, "sequenceAt": sequence_at, "stopAt": anim_stop_at}),
})
# Python callables are userdata in Lua: wrap the ones a resource type-checks (`type(f) == "function"`).
L.execute("""
for _, path in ipairs({ {"npcs", "create"}, {"npcs", "setAIEnabled"}, {"npcs", "remove"}, {"players", "teleport"},
                        {"routingBuckets", "getPlayer"}, {"routingBuckets", "setPlayer"}, {"routingBuckets", "setPopulationEnabled"} }) do
    local t, k = Open77[path[1]], path[2]
    local f = t[k]
    t[k] = function(...) return f(...) end
end
""")



def last(name, target=None):
    for n, t, p in reversed(sent):
        if n == "op77_tcg:" + name and (target is None or t == target):
            return p
    return None


def counts(p):
    return {k: int(v) for k, v in (x.split(":") for x in str(p["owned"]).split(",") if x)}




def boot(prelude=""):
    L.execute((ROOT / "shared/config.lua").read_text(encoding="utf-8"))
    if prelude:
        L.execute(prelude)
    for f in ["shared/catalogue.lua", "shared/rules.lua", "shared/cards.lua", "shared/decks.lua", "shared/starters.lua",
              "shared/table.lua", "shared/rooms.lua", "shared/game.lua", "shared/effects.lua", "shared/tutorial.lua", "server/main.lua",
              "server/duel.lua", "server/rooms.lua"]:
        L.execute((ROOT / f).read_text(encoding="utf-8"))
    L.eval("__pump")(10)


fire = L.eval("fire")
checks = [0]


def check(cond, what):
    if not cond:
        print("FAIL:", what)
        sys.exit(1)
    checks[0] += 1


