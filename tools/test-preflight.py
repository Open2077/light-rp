"""Light RP server check (the launcher's preflight): runs the real op77_lightrp provider
module (server/modules/preflight.lua) in Lua 5.4 against canned database rows, and checks
open77_preflight's Light RP config and screens (resources/system/open77_preflight).

    python tools/test-preflight.py      (needs lupa; no database, no server)

The documents are rendered by the launcher in "NativeUI Lite"; this checks what can be
checked without it (well-formed XML, <rml> root, 64 KiB, images present, bindings the
config feeds). Render them through the launcher for the look (see the PR / RELEASE notes).
"""
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
GAMEMODE = ROOT / "resources" / "gamemodes" / "op77_lightrp"
PREFLIGHT = ROOT / "resources" / "system" / "open77_preflight"
failures = []


def check(label, condition, detail=""):
    print(("PASS " if condition else "FAIL ") + label + ("" if condition else f"  -- {detail}"))
    if not condition:
        failures.append(label)


lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((GAMEMODE / "shared" / "jobs.lua").read_text(encoding="utf-8"))
lua.execute("""
NOW = 1800000000
INVOKER = "open77_preflight"
READY = true
FAIL = false
QUERIES = 0
ACCOUNTS, CHARACTERS, COUNT = {}, {}, 0
EXPORTS = {}
function GetUnixTime() return NOW end
function GetInvokingResource() return INVOKER end
function CreateThread(fn) end
function Wait() end
function exports(name, fn) EXPORTS[name] = fn end
LightRP = { db = { } }
setmetatable(LightRP.db, { __index = function(_, key) if key == "ready" then return READY end end })
function LightRP.db.read(sql, params)
    QUERIES = QUERIES + 1
    if FAIL then return false, "database_error" end
    if sql:find("COUNT%(%*%)") then return true, { { n = COUNT } } end
    if sql:find("FROM lightrp_accounts") then return true, ACCOUNTS[params[1]] or {} end
    if sql:find("FROM lightrp_characters") then return true, CHARACTERS[params[1]] or {} end
    return true, {}
end
""")
lua.execute((GAMEMODE / "server" / "modules" / "preflight.lua").read_text(encoding="utf-8"))
G = lua.globals()
P = G.LightRP.preflight
screen = G.EXPORTS["preflightScreen"]

# Formatting helpers.
check("ago", [P.ago(30), P.ago(600), P.ago(7200), P.ago(86400 + 5), P.ago(5 * 86400), P.ago(20 * 86400), P.ago(90 * 86400)]
      == ["just now", "10 min ago", "2 h ago", "yesterday", "5 days ago", "2 weeks ago", "3 months ago"])
check("playtime", [P.playtime(45 * 60000), P.playtime(51000000)] == ["45 min", "14 h"])
check("thousands", [P.thousands(0), P.thousands(999), P.thousands(1284), P.thousands(1234567)] == ["0", "999", "1,284", "1,234,567"])

USER = "5f0c2a8e-7b1d-4c3e-9a6f-1d2e3f4a5b6c"
lua.execute(f"""
ACCOUNTS["{USER}"] = {{ {{ active_key = "default", seen = NOW - 2 * 86400 }} }}
CHARACTERS["{USER}"] = {{
    {{ character_key = "slot2", status = "active", first_name = "Marco", last_name = "Reyes", job = "sanitation", job_grade = 0,
       playtime_ms = 7300000, seen = NOW - 3600 }},
    {{ character_key = "default", status = "active", first_name = "Kira", last_name = "Tanaka", job = "delivery", job_grade = 2,
       playtime_ms = 51000000, seen = NOW - 2 * 86400 }},
}}
COUNT = 1284
""")


def ctx(user_id=USER, name="NightRunner"):
    return lua.table_from({"screen": "rules", "player": lua.table_from({"userId": user_id, "name": name})})


# The account's active character wins over the one seen last.
data = screen("greeting", ctx(USER.upper()))
check("returning: active character", data is not None and data["character"] == "Kira Tanaka" and data["returning"] is True)
check("returning: job, last seen, playtime", data["characterJob"] == "Courier · Dispatcher" and data["lastSeen"] == "2 days ago"
      and data["characterPlaytime"] == "14 h", (data["characterJob"], data["lastSeen"], data["characterPlaytime"]))
check("returning: both characters listed, flags", data["characterCount"] == 2 and data["hasOthers"] is True and data["characters"][2]["name"] == "Kira Tanaka"
      and data["characters"][2]["active"] is True and data["characters"][1]["job"] == "Sanitation · Trainee")
check("returning: allowed line template", data["allowedMessage"] == "Welcome back to Night City, {character}.")

# One query pair per join: the rules then the greeting read the cache.
before = G.QUERIES
screen("rules", ctx())
check("cache spares the second screen", G.QUERIES == before)

# A first visit, an account stuck in the creator, the welcome count.
fresh = screen("rules", ctx("0b7e6f1a-2c3d-4e5f-8a9b-0c1d2e3f4a5b", "Newcomer"))
check("first visit", fresh["returning"] is False and fresh["firstVisit"] is True and fresh["hasCharacters"] is False
      and fresh["characters"] is None and "lobby" in fresh["allowedMessage"])
lua.execute('ACCOUNTS["11111111-2222-3333-4444-555555555555"] = { { active_key = "default", seen = NOW } }')
draft = screen("rules", ctx("11111111-2222-3333-4444-555555555555", "Halfway"))
check("account without a finished character", draft["returning"] is False and draft["firstVisit"] is False and "creator" in draft["allowedMessage"])
welcome = screen("welcome", lua.table_from({"screen": "welcome"}))
check("welcome: residents", welcome["residents"] == "1,284" and welcome["hasResidents"] is True)

# Fail open and only for open77_preflight.
G.INVOKER = "someone_else"
check("other callers get nothing", screen("rules", ctx()) is None)
G.INVOKER = "open77_preflight"
check("bad user id", screen("rules", ctx("not-a-guid")) is None and screen("rules", lua.table_from({})) is None)
G.READY = False
check("no database: nothing", screen("rules", ctx("22222222-2222-3333-4444-555555555555")) is None)
G.READY = True
G.FAIL = True
check("database error: nothing (and not cached)", screen("rules", ctx("33333333-2222-3333-4444-555555555555")) is None)
G.FAIL = False
check("after the error the next join reads again", screen("rules", ctx("33333333-2222-3333-4444-555555555555"))["firstVisit"] is True)

# The config open77_preflight runs with.
lua.execute((PREFLIGHT / "config.lua").read_text(encoding="utf-8"))
config = G.PreflightConfig
documents = config["ui"]["documents"]
check("config: provider is op77_lightrp", config["ui"]["provider"] == "op77_lightrp" and config["ui"]["providerExport"] == "preflightScreen")
check("config: rules on, Discord not required, greeting on", config["rules"]["enabled"] is True and config["discord"]["required"] is False
      and config["greeting"]["enabled"] is True)
check("config: links https", all(str(config["links"][k]).startswith("https://") for k in ("discord", "website")))
names = ["welcome", "rules", "apply", "refused", "full", "greeting"]
for name in names:
    path = documents[name]
    check(f"config: {name} document exists", path is not None and (PREFLIGHT / path).is_file(), path)

# Every Light RP screen: well-formed, an <rml> root, under 64 KiB, its images present and served.
manifest = (PREFLIGHT / "open77.lua").read_text(encoding="utf-8")
check("manifest serves ui/custom images", 'preflight_files { "ui/custom/*.png", "ui/custom/*.jpg"' in manifest)
for document in sorted((PREFLIGHT / "ui" / "custom").glob("*.rml")):
    text = document.read_text(encoding="utf-8")
    try:
        root = ET.fromstring(text)
        check(f"{document.name}: well-formed, <rml> root", root.tag == "rml")
    except ET.ParseError as error:
        check(f"{document.name}: well-formed", False, error)
        continue
    check(f"{document.name}: under 64 KiB", len(text.encode()) <= 65536)
    for source in re.findall(r'src="asset:([^"]+)"', text):
        check(f"{document.name}: {source} present", (PREFLIGHT / source).is_file() and (PREFLIGHT / source).stat().st_size <= 2 * 1024 * 1024)
    for href in re.findall(r'href="([^"]+)"', text):
        check(f"{document.name}: link {href}", href.startswith("https://") or href.startswith("{{"))
    check(f"{document.name}: no script, no absolute positioning", "<script" not in text and "position:" not in text.replace(" ", ""))

print(f"{'FAILED' if failures else 'OK'}: {len(failures)} failure(s)")
sys.exit(1 if failures else 0)
