"""Replace the binder's card images with the official high-resolution renders (cyberpunktcg.com, served by the
NetDeck card API) instead of the in-game textures (DXT5, 1:2, soft).

Each edition of shared/catalogue.lua is matched to one official printing of its card by comparing pictures:
the mod's art variants (art_001, art_002...) are different printings (retail, Night City Brawls Nova Rares...).

Usage: fetch_official.py <resource dir> <work dir>
  <work dir>/reference : the current (mod-derived) web/img/cards, copied there on the first run; matching uses it
  <work dir>/raw       : downloaded printings (<printing id>.webp), reused on later runs
  <work dir>/report.json
Writes <resource dir>/web/img/cards/<edition id>.webp (733 x 1024 with the card's rounded corners, WebP q90).
"""
import concurrent.futures
import json
import pathlib
import re
import shutil
import sys
import time
import unicodedata
import urllib.request

from PIL import Image

API = "https://api.netdeck.gg/api/cards/cyberpunk"
UA = {"User-Agent": "op77-tcg-asset-build/1.0"}
# On equal pictures, prefer the booster printing (a starter deck or a promo prints the same art).
SET_PREFERENCE = ["welcometonightcityretail", "welcometonightcitybeta"]

res, work = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
raw, ref = work / "raw", work / "reference"
raw.mkdir(parents=True, exist_ok=True)
cards_dir = res / "web/img/cards"
if not ref.exists():
    shutil.copytree(cards_dir, ref)


def get(url, binary=False, tries=4):
    for attempt in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60) as r:
                data = r.read()
                return data if binary else json.loads(data.decode("utf-8"))
        except Exception as e:  # 503s happen on the API under load
            if attempt == tries - 1:
                raise
            time.sleep(1.5 * (attempt + 1))


def norm(s):
    # "Judy Álvarez — Nothing to Doubt" and "Judy Alvarez Nothing To Doubt" are the same card.
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^a-z0-9]", "", s.lower())


editions = [dict(zip(("id", "card", "name", "rarity", "finish"), m)) for m in re.findall(
    r'id = "([^"]+)", card = "([^"]+)", number = \d+, name = "((?:[^"\\]|\\.)*)", tier = \d, rarity = "([^"]+)", '
    r'finish = "([^"]+)"', (res / "shared/catalogue.lua").read_text(encoding="utf-8"))]
print(len(editions), "editions")

site, offset = [], 0
while True:
    page = get(f"{API}?offset={offset}&limit=60")
    site += page["items"]
    offset += len(page["items"])
    if not page["items"] or offset >= page["total"]:
        break
by_name = {}
for c in site:
    for key in (c.get("canonical_name"), c.get("display_name"), c.get("name")):
        if key:
            by_name.setdefault(norm(key), c)
print(len(site), "official cards")

wanted = {}
for e in editions:
    c = by_name.get(norm(e["name"]))
    if c:
        wanted[c["slug"]] = c
missing = sorted({e["name"] for e in editions if norm(e["name"]) not in by_name})
print("unmatched names:", missing)


def printings(slug):
    detail = get(f"{API}/{slug}")
    out = []
    for p in detail["printings"]:
        if p.get("language") != "en":
            continue
        target = raw / f"{p['id']}.webp"
        if not target.exists():
            target.write_bytes(get(p["image_url"], binary=True))
        out.append({"id": p["id"], "set": p["set"]["code"], "number": p["collector_number"], "rarity": p["rarity"],
                    "file": str(target)})
    return slug, out


with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    prints = dict(pool.map(printings, sorted(wanted)))
print(sum(len(v) for v in prints.values()), "english printings downloaded")


def signature(path):
    im = Image.open(path).convert("RGBA")
    flat = Image.new("RGB", im.size, (0, 0, 0))
    flat.paste(im, mask=im.split()[3])
    # The art window and frame, without the outer 4 % (corner radius, bleed).
    w, h = flat.size
    flat = flat.crop((int(w * .04), int(h * .04), int(w * .96), int(h * .96))).resize((24, 34), Image.BILINEAR)
    return flat.tobytes()


def distance(a, b):
    return sum((x - y) ** 2 for x, y in zip(a, b)) * 3 / len(a)


sig_cache = {}
report = []
for e in editions:
    c = by_name.get(norm(e["name"]))
    cand = prints.get(c["slug"], []) if c else []
    if not cand:
        report.append({"id": e["id"], "name": e["name"], "status": "no_printing"})
        continue
    mine = signature(ref / f"{e['id']}.webp")
    scored = []
    for p in cand:
        if p["file"] not in sig_cache:
            sig_cache[p["file"]] = signature(p["file"])
        d = distance(mine, sig_cache[p["file"]])
        pref = SET_PREFERENCE.index(p["set"]) if p["set"] in SET_PREFERENCE else len(SET_PREFERENCE)
        scored.append((d, pref, p))
    best_d = min(s[0] for s in scored)
    # Same picture within 15 %: take the preferred set.
    close = [s for s in scored if s[0] <= best_d * 1.15 + 20]
    d, _, p = sorted(close, key=lambda s: (s[1], s[0]))[0]
    im = Image.open(p["file"]).convert("RGBA")
    im.save(cards_dir / f"{e['id']}.webp", "WEBP", quality=90, method=6)
    report.append({"id": e["id"], "name": e["name"], "finish": e["finish"], "rarity": e["rarity"], "printing": p["id"],
                   "set": p["set"], "number": p["number"], "officialRarity": p["rarity"], "distance": round(d, 1),
                   "runnerUp": round(sorted(s[0] for s in scored)[1], 1) if len(scored) > 1 else None})

(work / "report.json").write_text(json.dumps(report, indent=1, ensure_ascii=False), encoding="utf-8")
done = [r for r in report if "printing" in r]
print(len(done), "/", len(editions), "editions replaced; worst distances:",
      sorted(((r["distance"], r["name"], r["finish"]) for r in done), reverse=True)[:8])
print("rarity differences:", [(r["name"], r["rarity"], r["officialRarity"]) for r in done if r["rarity"] != r["officialRarity"]][:20])
print("left as is:", [r["name"] for r in report if "printing" not in r])
