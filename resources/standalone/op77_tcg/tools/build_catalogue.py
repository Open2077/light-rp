"""Build the op77_tcg card catalogue from the Cyberpunk TCG Collectibles mod metadata.

Inputs (extracted from the mod zip, read as data only):
  <src>/r6/scripts/CyberpunkTCG/Services/BoosterCardPool.reds   booster pool: base id, item, tier, name, rarity, finish
  <src>/r6/tweaks/CyberpunkTCG/Cards.yaml                       every edition item (the pool omits the reserved Secret cards)
  <src>/collection.list                                         archive listing (entity + texture paths)
Output: <out>/catalogue.json
Usage: build_catalogue.py <src> <out>
"""
import collections
import json
import pathlib
import re
import sys

src, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
pool_text = (src / "r6/scripts/CyberpunkTCG/Services/BoosterCardPool.reds").read_text(encoding="utf-8")
MAKE = re.compile(r'Make\(n"([^"]+)", t"Items\.CyberpunkTCG_([0-9a-f]{32})_([a-z]+)", (\d+), "((?:[^"\\]|\\.)*)", '
                  r'"([^"]+)", n"([a-z]+)", r"([^"]+)", n"([^"]+)"\)')
pool = {}
for base, h, finish, tier, name, rarity, finish2, atlas, part in MAKE.findall(pool_text):
    pool[h] = dict(base=base, finish=finish, tier=int(tier), name=name.replace('\\"', '"'), rarity=rarity)

listing = (src / "collection.list").read_text(encoding="utf-8", errors="replace").splitlines()
ENT = re.compile(r"^cyberpunktcg\\cards\\catalogue\\(.+?)__art_(\d{3})__([0-9a-f]{8})__([a-z]+)\.ent$")
entities = {}
for line in listing:
    m = ENT.match(line.strip())
    if m:
        slug, art, h8, finish = m.groups()
        entities[(h8, finish)] = dict(slug=slug, art=int(art), finish=finish, entity=line.strip())
textures = {}
for line in listing:
    line = line.strip()
    m = re.match(r"^cyberpunktcg\\cards\\catalogue\\.+?__art_\d{3}__([0-9a-f]{8})__(front_d01|premium_print_d01|metal_print_d01|foil_print_d01)\.xbm$", line)
    if m:
        textures[(m.group(1), m.group(2))] = line

# Every edition item in Cards.yaml (the pool leaves the four reserved Secret cards out).
yaml = (src / "r6/tweaks/CyberpunkTCG/Cards.yaml").read_text(encoding="utf-8")
items = re.findall(r"^Items\.CyberpunkTCG_([0-9a-f]{32})_([a-z]+):\s*$", yaml, re.M)
quality = {}
for h, finish in items:
    block = yaml.split(f"Items.CyberpunkTCG_{h}_{finish}:", 1)[1].split("\n\n", 1)[0]
    q = re.search(r"quality:\s*Quality\.(\w+)", block)
    quality[h] = q.group(1) if q else None

cards = []
missing = []
for h, finish in items:
    e = entities.get((h[:8], finish))
    if not e:
        missing.append(h)
        continue
    p = pool.get(h)
    cards.append({
        "id": f"{h[:8]}{finish[0]}",       # edition id: the mod's content hash + finish initial (s/f/p/m)
        "card": e["slug"],                 # base card slug
        "baseId": p["base"] if p else None,
        "name": p["name"] if p else e["slug"].replace("_", " ").title(),
        "art": e["art"],
        "finish": finish,                  # sleeved | foil | premium | metal
        "tier": p["tier"] if p else 6,     # 1 C, 2 U, 3 R, 4, 5 top; 6 = reserved Secret (not in boosters)
        "rarity": p["rarity"] if p else "Secret",
        "inBoosters": p is not None,
        "quality": quality.get(h),
        "entity": e["entity"],
        "texture": textures.get((h[:8], {"sleeved": "front_d01"}.get(finish, finish + "_print_d01"))),
    })
cards.sort(key=lambda c: (c["name"].lower(), c["art"]))
for i, c in enumerate(cards, 1):
    c["number"] = i
out.mkdir(parents=True, exist_ok=True)
(out / "catalogue.json").write_text(json.dumps({"version": 1, "set": "Cyberpunk TCG", "cards": cards}, indent=1,
                                               ensure_ascii=False), encoding="utf-8")
print(len(cards), "editions;", len({c["card"] for c in cards}), "cards; missing entity:", len(missing))
print("tiers:", sorted(collections.Counter((c["tier"], c["rarity"]) for c in cards).items()))
print("finishes:", collections.Counter(c["finish"] for c in cards))
print("no texture:", [c["id"] for c in cards if not c["texture"]][:10])
