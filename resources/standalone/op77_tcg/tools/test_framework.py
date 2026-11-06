"""op77_tcg server test with a framework (LightRP's role, faked): characters are the collectors, sealed product
lives in the framework's inventory, items are used through exports.op77_tcg:useSealed.

Usage: python tools/test_framework.py   (needs lupa)
"""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from tcg_harness import L, boot, check, checks, con, counts, fire, last  # noqa: E402

# The fake framework: active characters, an inventory of sealed items with a number of free units (`room`).
boot("""
TcgConfig.framework = "op77_lightrp"
TcgConfig.shops = { { x = 100.5, y = 200.0, z = 10.0, label = "NEON DECK" } }
active = { [1] = { identifier = "lic-1", characterKey = "c1", name = "Yuki Tanaka" } }
inv, room, taken = { [1] = {} }, { [1] = 30 }, 0
local lightrp = {
    characterIdentity = function(self, p) return active[p] end,
    tcgSealed = function(self, p) return inv[p] or {} end,
    tcgTakeSealed = function(self, p, product, n)
        local t = inv[p] or {}
        if (t[product] or 0) < n then return false end
        t[product] = t[product] - n; room[p] = room[p] + n; taken = taken + n
        return true
    end,
    tcgGiveSealed = function(self, p, product, n)
        if (room[p] or 0) < n then return false, "Make room in your inventory." end
        inv[p] = inv[p] or {}
        inv[p][product] = (inv[p][product] or 0) + n; room[p] = room[p] - n
        return true
    end,
}
-- Open77.exports.call: a promise whose await runs the export (writes must go through it, never synchronously).
async_calls = 0
Open77.exports = { call = function(res, fn, ...)
    local args = table.pack(...)
    local e = exports[res]
    if not e or not e[fn] then return nil, "export_resource_unavailable" end
    return { await = function(self) async_calls = async_calls + 1; return e[fn](e, table.unpack(args, 1, args.n)) end }
end }
exports = setmetatable({}, {
    __call = function(_, name, fn) exported[name] = fn end,
    __index = function(_, res) if res == "op77_lightrp" then return lightrp end end,
})
""")
G = L.globals()


def inv(product, player=1):
    t = G.inv[player]
    return int(t[product] or 0) if t is not None else 0


def notice(player=1):
    n = last("notice", player)
    return str(n["text"]) if n else ""


# Before a character is active there is no collector: nothing is sent.
fire("op77_tcg:hello", 2)
check(last("state", 2) is None, "no character: no collector, no state")

# The character's starter packs go to the inventory, and the page knows the sealed shelf is the inventory.
fire("op77_tcg:hello", 1)
st = last("state", 1)
check(inv("wnc") == 3 and st["sealed"]["wnc"] == 3 and st["store"] == "inventory", "starter packs as inventory items")
check("your inventory" in notice(), "the welcome points at the inventory")
check(con.execute("SELECT starter FROM tcg_profiles WHERE identifier = 'lic-1#c1'").fetchone()[0] == 1,
      "the collector is the character (identifier#characterKey)")
fire("op77_tcg:hello", 1)
check(inv("wnc") == 3, "starter packs given once")

# Using a booster item: the client is asked to start the opening; nothing is taken yet.
use = L.eval("exported.useSealed")
ok = use(1, "wnc")
u = last("use", 1)
check(ok is True and u["product"] == "wnc" and u["kind"] == "booster" and inv("wnc") == 3, "useSealed asks the client")
check(use(1, "nope")[0] is False and use(2, "wnc")[0] is False, "unknown product / no collector refused")

# The opening takes the pack from the inventory.
anchor = L.table_from({"x": 100.0, "y": 200.0, "z": 10.0, "yaw": 90.0, "surface": 10.9})
fire("op77_tcg:open", 1, "wnc", anchor)
op = last("opening", 1)
check(op is not None and len(str(op["cards"]).split(",")) == 12 and inv("wnc") == 2, "an opening takes one booster item")
check(con.execute("SELECT count(*) FROM tcg_sealed").fetchone()[0] == 0, "nothing sealed in tcg.db: the inventory is the store")
check(G.async_calls > 0, "inventory writes go through the asynchronous export call")
fire("op77_tcg:reveal", 1, L.table_from({"seq": op["seq"], "stage": "card", "index": 12}))

# A display: cut open into 24 booster items.
G.inv[1]["box"] = 1
fire("op77_tcg:unbox", 1, "box")
st = last("state", 1)
check(inv("box") == 0 and inv("wnc") == 26 and st["extra"]["unboxed"] == "box", "display into 24 booster items")
# No room: the display is given back, nothing else changes, the page is told.
G.inv[1]["box"] = 1
G.room[1] = 5
fire("op77_tcg:unbox", 1, "box")
st = last("state", 1)
check(inv("box") == 1 and inv("wnc") == 26 and st["extra"]["unboxFailed"] == "box", "no room: the display stays sealed")
check("Make room" in notice(), "the framework's reason reaches the player")
# No display at all.
G.inv[1]["box"] = 0
fire("op77_tcg:unbox", 1, "box")
check(last("state", 1)["extra"]["unboxFailed"] == "box", "no display: refused")

# The TCG counter does not sell when the framework does (its vendor).
fire("op77_tcg:buy", 1, "wnc")
check("vendor" in notice() and inv("wnc") == 26, "the counter points at the vendor")

# The NEON DECK welcome is seen per character.
fire("op77_tcg:seen", 1, "welcome")
fire("op77_tcg:state", 1)
check(last("state", 1)["welcomed"] is True, "character 1 saw the welcome")

# Another character is another collector with its own binder (and its own starter packs).
owned_c1 = counts(last("state", 1))
G.active[1] = L.table_from({"identifier": "lic-1", "characterKey": "c2", "name": "Vik"})
G.inv[1] = L.table()
G.room[1] = 30
fire("op77_lightrp:characterChanged", 0, 1)
st = last("state", 1)
check(len(owned_c1) > 0 and counts(st) == {} and inv("wnc") == 3, "a switched character starts its own collection")
check(con.execute("SELECT count(*) FROM tcg_profiles WHERE identifier LIKE 'lic-1#%'").fetchone()[0] == 2, "two collectors")
check(st["welcomed"] is False, "the other character has the welcome still to see")

print(f"PASS: op77_tcg with a framework ({checks[0]} checks: character collectors, starter items, useSealed, opening "
      "and display through the inventory, no-room refund, counter defers to the vendor, character switch, welcome per character)")
