"""Decode every card front (and the shared backside / foil spectrum) to WebP for the binder UI.
Usage: build_images.py <jsonfront dir> <catalogue.json> <out dir>
"""
import concurrent.futures
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from xbm2png import card, decode  # noqa: E402

src, catalogue, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3])
(out / "cards").mkdir(parents=True, exist_ok=True)
cards = json.loads(catalogue.read_text(encoding="utf-8"))["cards"]


def one(job):
    name, target, width, is_card = job
    image = decode(src / (name + ".json"))
    image = card(image, width) if is_card else image
    image.convert("RGB").save(target, "WEBP", quality=86, method=6)
    return target.stat().st_size


if __name__ == "__main__":
    jobs = [(c["texture"].rsplit("\\", 1)[1], out / "cards" / f"{c['id']}.webp", 480, True) for c in cards]
    jobs.append(("standard_backside.xbm", out / "backside.webp", 480, True))
    jobs.append(("foil_spectrum.xbm", out / "foil_spectrum.webp", 512, False))
    with concurrent.futures.ProcessPoolExecutor(max_workers=6) as pool:
        sizes = list(pool.map(one, jobs))
    print(len(sizes), "images,", sum(sizes) // 1024, "KiB")
