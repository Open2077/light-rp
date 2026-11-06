"""The NEON DECK welcome, client side (client/welcome.lua) against stubbed natives and a fake TcgClient: the radius
around the vendor, the settle time, every state that keeps it from opening on its own, shown once (the server's
"welcomed" flag and the session), the cursor handed back on close, and reopening it (command, page button).
Usage: python tools/test_welcome.py   (needs lupa)"""
import pathlib
import sys

import lupa.lua54 as lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
checks = [0]


def check(cond, what):
    if not cond:
        print("FAIL:", what)
        sys.exit(1)
    checks[0] += 1


STUBS = """
local co_list, clock = {}, 100000
function GetGameTimer() return clock end
function CreateThread(fn) local co = coroutine.create(fn); local ok, err = coroutine.resume(co); if not ok then error(err) end
    if coroutine.status(co) ~= "dead" then co_list[#co_list + 1] = co end end
function Wait(ms) local due = clock + (ms or 0); repeat coroutine.yield() until clock >= due end
-- Simulated time: 100 ms a step.
function __pump(ms) for _ = 1, math.floor((ms or 1000) / 100) do clock = clock + 100; local alive = {}
    for _, co in ipairs(co_list) do local ok, err = coroutine.resume(co); if not ok then error(err) end
        if coroutine.status(co) ~= "dead" then alive[#alive + 1] = co end end
    co_list = alive end end
commands, toServer, events, notices = {}, {}, {}, {}
function RegisterCommand(name, fn) commands[name] = fn end
function TriggerServerEvent(name, ...) toServer[#toServer + 1] = { name = name, args = { ... } } end
function TriggerEvent(name) events[#events + 1] = name end

flags = { loading = false, vehicle = false, cursor = false, keyboard = false, menu = false,
          open = false, rooms = false, busy = false, match = false, ready = true }
Open77 = {
    screen = { isLoading = function() return flags.loading end },
    character = { isInVehicle = function() return flags.vehicle end },
    cursor = { isCaptured = function() if flags.cursor then return true, "op77_lightrp" end return false end },
    input = { isCaptured = function() return flags.keyboard, false end },
    session = { isMenuOpen = function() return flags.menu end },
}
pageSent, pageActions, focus, releases, afterCloses = {}, {}, false, 0, 0
pos, st = nil, nil
TcgClient = {
    log = function() end, notify = function(t) notices[#notices + 1] = t end,
    send = function(name, p) pageSent[#pageSent + 1] = { name = name, p = p } end,
    on = function(name, fn) pageActions[name] = fn end,
    here = function() return pos end,
    isOpen = function() return flags.open end, ready = function() return flags.ready end, state = function() return st end,
    busy = function() return flags.busy end, inMatch = function() return flags.match end, roomsOpen = function() return flags.rooms end,
    show = function(f) focus = f == true end, release = function() focus = false; releases = releases + 1 end,
    afterClose = function() afterCloses = afterCloses + 1 end,
}
function lastPage(name) for i = #pageSent, 1, -1 do if pageSent[i].name == name then return pageSent[i].p end end end
function countPage(name) local n = 0; for _, m in ipairs(pageSent) do if m.name == name then n = n + 1 end end; return n end
function countServer(name) local n = 0; for _, m in ipairs(toServer) do if m.name == name then n = n + 1 end end; return n end
-- Stand d metres east of the vendor (dz above it).
function at(d, dz) local a = TcgConfig.welcome.anchor; pos = { x = a.x + d, y = a.y, z = a.z + (dz or 0) } end
"""


def runtime(prelude=""):
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute(STUBS)
    for f in ["shared/config.lua", "shared/starters.lua", "shared/rooms.lua"]:
        L.execute((ROOT / f).read_text(encoding="utf-8"))
    if prelude:
        L.execute(prelude)
    L.execute((ROOT / "client/welcome.lua").read_text(encoding="utf-8"))
    return L


L = runtime()
G = L.globals()
pump = L.eval("__pump")
at = L.eval("at")
count_page = L.eval("countPage")
count_server = L.eval("countServer")
W = L.eval("TcgConfig.welcome")
r = float(W.radius)
check(4.0 <= r <= 5.0, "the radius is a few metres (%.1f m)" % r)

# No state from the server yet (or an older server without the flag): never on its own.
at(1.0)
pump(5000)
check(count_page("tcg:welcomeOpen") == 0, "no server state: nothing opens")
G.st = L.table_from({"welcomed": True})
pump(5000)
check(count_page("tcg:welcomeOpen") == 0, "already seen (server): nothing opens")

# Not seen. Outside the radius, above it (the rooms are under the shop), just inside it.
G.st = L.table_from({"welcomed": False, "store": "inventory"})
at(r + 0.2)
pump(5000)
check(count_page("tcg:welcomeOpen") == 0, "just outside the radius: nothing")
at(1.0, -8.1)
pump(5000)
check(count_page("tcg:welcomeOpen") == 0, "in a private room under the shop: nothing")
check(L.eval("TcgWelcome.inRange")(L.eval("{ x = TcgConfig.welcome.anchor.x + %f, y = TcgConfig.welcome.anchor.y, z = TcgConfig.welcome.anchor.z }" % (r - 0.1))),
      "inRange: just inside the radius")
# Walking past: in range for less than settleMs.
at(r - 0.3)
pump(int(W.settleMs) - 600)
at(r + 3)
pump(3000)
check(count_page("tcg:welcomeOpen") == 0, "walking past the vendor: nothing (settle time)")

# Every blocked state, one at a time: in range long enough, nothing opens; cleared, it would.
at(r - 0.5)
for flag, what in [("loading", "a loading screen"), ("vehicle", "in a vehicle"), ("match", "in a duel"), ("open", "the binder open"),
                   ("rooms", "the rooms panel open"), ("busy", "a pack opening"), ("cursor", "another page holds the cursor"),
                   ("keyboard", "the chat / F1 menu holds the keyboard"), ("menu", "a game menu")]:
    G.flags[flag] = True
    check(L.eval("TcgWelcome.blocked")() is not None, "blocked: " + what)
    pump(4000)
    check(count_page("tcg:welcomeOpen") == 0, "nothing opens with " + what)
    G.flags[flag] = False
check(L.eval("TcgWelcome.blocked")() is None, "nothing in the way")
G.flags.ready = False
pump(4000)
check(count_page("tcg:welcomeOpen") == 0, "the page not ready: nothing")
G.flags.ready = True

# Opens: page message, focus (cursor), the server told once, the gamemode's panels closed.
pump(int(W.settleMs) + 600)
check(count_page("tcg:welcomeOpen") == 1, "in range, unseen, nothing in the way: it opens")
p = L.eval("lastPage")("tcg:welcomeOpen")
check(p["auto"] is True and p["binder"]["key"] == "F1" and p["binder"]["entry"] == "TCG binder", "payload: the binder's F1 entry")
check(p["command"] == "tcgbinder" and p["tutorial"] == "tcgtutorial" and p["welcome"] == "tcgwelcome", "payload: the real commands")
check(len(p["starters"]) == 2 and p["starters"][1]["name"] == "Embracing Power" and p["gift"] == 3, "payload: the lent decks, the gift")
check(G.focus is True, "it takes the cursor")
check(count_server("op77_tcg:seen") == 1 and G.toServer[1]["args"][1] == "welcome", "the server stores it as seen")
check("op77_tcg:focus" in list(G.events.values()), "the gamemode closes its panels over it")
check(G.st["welcomed"] is True, "the local state knows it was seen")

# Close (the page's Escape / Got it): the cursor goes back, the duel overlay may take it again.
L.eval("pageActions['tcg:welcomeClose']")(L.table())
check(G.focus is False and G.releases == 1 and G.afterCloses == 1, "closing gives the cursor back")
check(count_page("tcg:welcomeClose") == 1, "the page is told to hide")

# Once: walking out and back in, with a stale server state saying unseen, nothing opens again this session.
G.st = L.table_from({"welcomed": False})
at(r + 4)
pump(3000)
at(1.0)
pump(5000)
check(count_page("tcg:welcomeOpen") == 1 and count_server("op77_tcg:seen") == 1, "shown once per session")

# A new session where the server already has it as seen: never again on its own.
L2 = runtime()
G2 = L2.globals()
G2.st = L2.table_from({"welcomed": True})
L2.eval("at")(1.0)
L2.eval("__pump")(6000)
check(L2.eval("countPage")("tcg:welcomeOpen") == 0, "next session, seen on the server: nothing")

# Reopen at will: the command toggles it, the rooms panel's button opens it; not marked again.
L2.eval("commands.tcgwelcome")()
check(L2.eval("countPage")("tcg:welcomeOpen") == 1 and L2.eval("lastPage")("tcg:welcomeOpen")["auto"] is False and G2.focus is True,
      "/tcgwelcome opens it")
check(L2.eval("countServer")("op77_tcg:seen") == 0, "reopening does not write anything")
L2.eval("commands.tcgwelcome")()
check(G2.focus is False and L2.eval("countPage")("tcg:welcomeClose") == 1, "/tcgwelcome again closes it")
L2.eval("pageActions['tcg:welcomeOpen']")(L2.table())
check(L2.eval("countPage")("tcg:welcomeOpen") == 2, "the rooms panel's button opens it")
# Over the binder: closing it leaves the binder's cursor alone.
G2.flags.open = True
releases = int(G2.releases)
L2.eval("pageActions['tcg:welcomeClose']")(L2.table())
check(int(G2.releases) == releases, "closed over the binder: the binder keeps the cursor")
G2.flags.open = False
# The page still loading: a manual open says so instead.
G2.flags.ready = False
L2.eval("commands.tcgwelcome")()
check(L2.eval("countPage")("tcg:welcomeOpen") == 2 and len(G2.notices) == 1, "page not ready: a notice, nothing opens")

# Disabled: no loop at all (the command still works).
L3 = runtime("TcgConfig.welcome.enabled = false")
G3 = L3.globals()
G3.st = L3.table_from({"welcomed": False})
L3.eval("at")(1.0)
L3.eval("__pump")(6000)
check(L3.eval("countPage")("tcg:welcomeOpen") == 0, "disabled: never on its own")
L3.eval("commands.tcgwelcome")()
check(L3.eval("countPage")("tcg:welcomeOpen") == 1, "disabled: the command still opens it")

print(f"PASS: NEON DECK welcome ({checks[0]} checks: radius + height, settle, no state / seen, 9 blocked states, page not ready, "
      "opens once with focus + seen stored, close gives the cursor back, once per session, next session, reopen by command / rooms button, disabled)")
