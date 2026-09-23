"""Build web/icons from the game's own inventory icon atlases.

The wardrobe shows one vanilla inventory icon per clothing record and body
family (web/icons/<m|f>/<Items.X>.webp, indexed by web/icons/manifest.json).
The icons come from the player's installed game, cut out of the item atlases:

  1. WolvenKit CLI extracts the atlas descriptors and textures
       base/gameplay/gui/common/icons/items/item_icons<N>.inkatlas / .xbm
  2. the descriptors are serialised to JSON (part names + UV rectangles) and the
     textures exported to PNG;
  3. every part named clothing_player_<slot>_item_<appearance>_<Male|Female>_[TPP_]
     is matched to a record of the platform catalogue (CyberM
     docs/generated/clothing-2.31.json) through its `appearanceName`;
  4. the matched rectangle is cropped, trimmed, scaled to HEIGHT px and saved.

Usage (PowerShell or bash, Python 3 with Pillow):
  python tools/build-icons.py --wolvenkit "E:/Apps/WolvenKit.Console/WolvenKit.CLI.exe" \
      --game "E:/SteamLibrary/steamapps/common/Cyberpunk 2077" \
      --catalogue "<CyberM>/docs/generated/clothing-2.31.json" --work <scratch dir>

Records without a vanilla icon (abstract base records such as Items.Boots or
Items.EmptySlots*) are left out of the manifest; the page draws a placeholder.
"""
import argparse, glob, json, os, re, subprocess, sys, collections
from PIL import Image

HEIGHT = 112
QUALITY = 76
PART = re.compile(r"^clothing_player_(?P<slot>[a-z_]+?)_item_(?P<app>.+?)_(?P<gender>Female|Male)_(?P<tpp>TPP_)?$")


def run(*args):
    r = subprocess.run(args, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout[-2000:], r.stderr[-2000:]); sys.exit(f"command failed: {args[0]}")


def extract(cli, game, work):
    archives = [os.path.join(game, "archive", "pc", "content"), os.path.join(game, "archive", "pc", "ep1")]
    run(cli, "extract", *archives, "-o", work, "-r", r"gui[\\/]common[\\/]icons[\\/]items[\\/]item_icons\d+\.(inkatlas|xbm)$", "-v", "Minimal")
    items = os.path.join(work, "base", "gameplay", "gui", "common", "icons", "items")
    atlases = sorted(glob.glob(os.path.join(items, "item_icons*.inkatlas")))
    run(cli, "convert", "serialize", *atlases, "-v", "Quiet")
    png = os.path.join(work, "png"); os.makedirs(png, exist_ok=True)
    textures = [t for t in sorted(glob.glob(os.path.join(items, "item_icons*.xbm"))) if "_1080p" not in t]
    run(cli, "export", *textures, "--uext", "png", "--outpath", png, "--gamepath", game, "-v", "Minimal")
    return items, png


def index_parts(items):
    index = collections.defaultdict(dict)
    for f in sorted(glob.glob(os.path.join(items, "item_icons*.inkatlas.json"))):
        root = json.load(open(f, encoding="utf-8"))["Data"]["RootChunk"]
        slot0 = root["slots"]["Elements"][0]  # slot 0 holds the full-resolution texture
        texture = slot0["texture"]["DepotPath"]["$value"]
        for p in slot0.get("parts", []):
            m = PART.match(p["partName"]["$value"])
            if not m:
                continue
            key = m.group("gender") + ("_tpp" if m.group("tpp") else "")
            index[m.group("app").rstrip("_").lower()].setdefault(key, (texture, p["clippingRectInUVCoords"]))
    return index


def build(index, catalogue, png, dest):
    textures = {}
    manifest, sizes = {}, []
    for it in json.load(open(catalogue, encoding="utf-8"))["items"]:
        entry = index.get(str(it.get("appearanceName") or "").rstrip("_").lower())
        if not entry:
            continue
        record, out = it["record"], {}
        for gender, key, other in (("m", "Male", "Female"), ("f", "Female", "Male")):
            part = entry.get(key + "_tpp") or entry.get(key) or entry.get(other + "_tpp") or entry.get(other)
            if not part:
                continue
            texture, rect = part
            name = os.path.basename(texture.replace("\\", "/")).replace(".xbm", ".png")
            if name not in textures:
                textures[name] = Image.open(os.path.join(png, name)).convert("RGBA")
            im = textures[name]
            w, h = im.size
            crop = im.crop((round(rect["Left"] * w), round(rect["Top"] * h), round(rect["Right"] * w), round(rect["Bottom"] * h)))
            bbox = crop.getbbox()
            if bbox:
                crop = crop.crop(bbox)
            crop = crop.resize((max(1, round(crop.width * HEIGHT / max(1, crop.height))), HEIGHT), Image.LANCZOS)
            folder = os.path.join(dest, gender); os.makedirs(folder, exist_ok=True)
            fn = os.path.join(folder, record + ".webp")
            crop.save(fn, "WEBP", quality=QUALITY, method=4)
            sizes.append(os.path.getsize(fn))
            out[gender] = f"icons/{gender}/{record}.webp"
        if out:
            manifest[record] = out
    json.dump(manifest, open(os.path.join(dest, "manifest.json"), "w", encoding="utf-8"), separators=(",", ":"))
    print(f"{len(manifest)} records, {len(sizes)} icons, {sum(sizes) / 1e6:.1f} MB")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--wolvenkit", required=True)
    ap.add_argument("--game", required=True)
    ap.add_argument("--catalogue", required=True)
    ap.add_argument("--work", required=True)
    ap.add_argument("--dest", default=os.path.join(os.path.dirname(__file__), "..", "web", "icons"))
    a = ap.parse_args()
    items, png = extract(a.wolvenkit, a.game, a.work)
    build(index_parts(items), a.catalogue, png, os.path.abspath(a.dest))
