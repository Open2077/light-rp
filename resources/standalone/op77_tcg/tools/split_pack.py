"""Split the TCG collection archive into packs a preload_mod can carry, and zip each as a mod package.

The server refuses a preload archive over 256 MiB (ResourcePreloadModResolver.MaximumPreloadArchiveBytes) and more
than 8 preload packages per resource. Files are grouped by card (every file of an edition stays together), cards in
alphabetical order, until a group reaches LIMIT bytes; the assets archive (boxes, boosters, machines, shelves) is
its own pack. Each group is packed by WolvenKit into `0_op77_tcg_<n>.archive` and zipped as
`archive/pc/mod/0_op77_tcg_<n>.archive` (stored: the DXT payload does not compress).

Usage: split_pack.py <extracted collection dir> <extracted assets dir> <work dir> <dist dir>
"""
import os
import pathlib
import shutil
import subprocess
import sys
import zipfile

WK = r"E:\Open77\Gta2CPPuppet\vendor\wolvenkit\WolvenKit.CLI.exe"
LIMIT = 190 * 1024 * 1024
collection, assets, work, dist = (pathlib.Path(p) for p in sys.argv[1:5])


def card_key(rel):
    name = rel.name
    return name.split("__art_")[0] if "__art_" in name else "~" + rel.parent.as_posix()


files = sorted(p for p in collection.rglob("*") if p.is_file())
groups, current, size, last = [], [], 0, None
for path in sorted(files, key=lambda p: (card_key(p.relative_to(collection)), p.as_posix())):
    key = card_key(path.relative_to(collection))
    if current and size + path.stat().st_size > LIMIT and key != last:
        groups.append(current)
        current, size = [], 0
    current.append(path)
    size += path.stat().st_size
    last = key
if current:
    groups.append(current)
groups = [(collection, g) for g in groups] + [(assets, sorted(p for p in assets.rglob("*") if p.is_file()))]
assert len(groups) <= 8, len(groups)

dist.mkdir(parents=True, exist_ok=True)
for n, (root, group) in enumerate(groups, 1):
    name = f"0_op77_tcg_{n}"
    folder = work / name
    if folder.exists():
        shutil.rmtree(folder)
    for path in group:
        target = folder / path.relative_to(root)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
    out = work / "packed"
    out.mkdir(parents=True, exist_ok=True)
    subprocess.run([WK, "pack", str(folder), "-o", str(out)], check=True, stdout=subprocess.DEVNULL)
    archive = out / f"{name}.archive"
    assert archive.exists(), archive
    package = dist / f"op77_tcg_{n}.zip"
    with zipfile.ZipFile(package, "w", zipfile.ZIP_STORED) as z:
        z.write(archive, f"archive/pc/mod/{name}.archive")
    mib = package.stat().st_size / 1048576
    assert mib < 256, (package, mib)
    print(f"{package.name}: {len(group)} files, {mib:.1f} MiB")
