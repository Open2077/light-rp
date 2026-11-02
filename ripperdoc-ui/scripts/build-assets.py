"""Build the ripperdoc page's media from a local Cyberpunk 2077 install (nothing is downloaded).

    python scripts/build-assets.py [--game <install>] [--cli <WolvenKit.CLI.exe>] [--probe <NCWE.Probe.exe>]
                                   [--work <dir>] [--only videos,stills,icons,assets,sounds]

Writes public/media/ (served as ./media/ by the page, shipped in op77_ripperdoc/web/media):
  video/<body>_<section>.webm  the paperdoll close-ups, VP9 with alpha, graded to the LightRP DA
  video/<body>_body.webm       the full-body idle loop
  still/<body>_<system>.webp   the full-body system overlays (hover highlight), registered on the loop
  icon/<fnv1a(cw_name)>.webp   the game's cyberware item icons (2160p atlas parts); the file is a short
                               hash of the name (src/media.ts iconFile): Windows paths stay under 260
  ui/*.webp                    rings, dot field, cables from the ripperdoc atlas, graded
  sfx/<name>.mp3               the game's UI sounds (needs the NCWE probe; skipped without it)
  manifest.json                sizes, durations, still registration boxes, icon list

The paperdoll videos are Bink 2: ffmpeg cannot read them, so frames are decoded with the game's own
bin/x64/bink2w64.dll (BINKALPHA, 32-bit BGRA surface) and encoded with ffmpeg (libvpx-vp9, yuva420p).
The art and sounds belong to CD PROJEKT RED: replace them before any public or commercial release.
"""
import argparse
import ctypes
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def icon_file(name):
    """FNV-1a 32 of the icon name, 8 hex digits: the same as src/media.ts iconFile."""
    h = 0x811c9dc5
    for ch in name.encode("ascii"):
        h = ((h ^ ch) * 0x01000193) & 0xffffffff
    return "%08x" % h

MEDIA = ROOT / "public" / "media"
DEFAULT_GAME = r"E:\SteamLibrary\steamapps\common\Cyberpunk 2077"
DEFAULT_CLI = r"E:\Apps\WolvenKit.Console\WolvenKit.CLI.exe"

# section id -> paperdoll video stem (man_/woman_ prefix added)
SECTIONS = {
    "frontal_cortex": "frontal_cortex", "operating_system": "operating", "ocular": "ocular", "face": "mask",
    "circulatory": "circulatory", "immune": "immune", "nervous": "nervous", "integumentary": "integumentary",
    "skeleton": "skeleton", "arms": "arm", "hands": "hand", "legs": "legs",
}
# full-body system overlays (atlas part stems, ma_/wo_ prefix) that register on the idle loop
STILLS = {
    "male": {"circulatory": "ma_circular", "immune": "ma_immune", "nervous": "ma_nervous",
             "integumentary": "ma_intergumentary", "skeleton": "ma_full_skeleton"},
    "female": {"circulatory": "wo_circular", "immune": "wo_immune", "nervous": "wo_nervous",
               "integumentary": "wo_intergumentary", "skeleton": "wo_skeleton"},
}
BODY_LOOP = {"male": "man/male_body_loop", "female": "woman/female_body_loop"}
PREFIX = {"male": "man/man_", "female": "woman/woman_"}
SOUNDS = {
    "open": "ui_gui_cyberware_tab_open", "close": "ui_gui_cyberware_tab_close",
    "zoom_in": "ui_gui_cyberware_paperdoll_zoom_in_01", "zoom_out": "ui_gui_cyberware_paperdoll_zoom_out_01",
    "hover": "ui_menu_hover", "press": "ui_menu_onpress", "menu_open": "ui_menu_open",
    "equip": "ui_gui_inventory_cyberware_equip", "unequip": "ui_gui_inventory_cyberware_unequip",
    "install": "ui_install_ripperdoc_part", "upgrade": "ui_gui_cyberware_upgarde_01",
    "bought": "ui_menu_item_bought", "denied": "ui_menu_perk_buy_fail", "tick_up": "ui_menu_value_up",
    "tick_down": "ui_menu_value_down", "gauge": "ui_gui_cyberware_capacity_guage_up_lp_01",
    "glitch": "ui_fx_hacking_glitch_fullscreen_low", "scan_tag": "ui_focus_mode_scanning_tag_on",
    "scan_done": "ui_focus_mode_scanning_done", "granted": "ui_hacking_access_granted",
    "beeps": "amb_int_custom_ripperdoc_01_medical_beeps_01",
}

# ---------------------------------------------------------------------------
# LightRP grade: red/teal paperdoll art -> amber/graphite (DA jaune & noir)
YELLOW = np.array([1.00, 0.80, 0.00])
AMBER = np.array([1.00, 0.55, 0.05])
GRAPHITE = np.array([0.58, 0.60, 0.62])
WHITE = np.array([1.00, 0.96, 0.80])


def grade(rgba, warm_gain=1.35, cool_gain=1.0):
    a = rgba.astype(np.float32) / 255.0
    rgb, alpha = a[..., :3], a[..., 3:4]
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = (0.2126 * r + 0.7152 * g + 0.0722 * b)[..., None]
    mx = rgb.max(-1)
    warm = np.clip((r - np.maximum(g, b)) / (mx + 1e-4) * 1.6, 0, 1)[..., None]
    sat = np.clip((mx - rgb.min(-1)) / (mx + 1e-4), 0, 1)[..., None]
    warm_col = mx[..., None] * warm_gain * (YELLOW * 0.65 + AMBER * 0.35)
    cool_col = np.power(lum, 1.05) * cool_gain * (GRAPHITE * (1 - 0.35 * sat) + YELLOW * 0.16 * sat)
    out = cool_col * (1 - warm) + warm_col * warm
    hi = np.clip((lum - 0.62) / 0.38, 0, 1)
    out = np.clip(out * (1 - hi) + WHITE * lum * 1.08 * hi, 0, 1)
    return (np.concatenate([out, alpha], -1) * 255).round().astype(np.uint8)


BODY_GAINS = (0.75, 1.25)


# ---------------------------------------------------------------------------
def run(command, label):
    result = subprocess.run([str(c) for c in command], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if result.returncode != 0 or "Unhandled exception" in result.stdout + result.stderr:
        raise RuntimeError(f"{label} failed:\n{(result.stdout + result.stderr)[-1500:]}")
    return result.stdout


def unbundle(cli, game, out, regex):
    for archive in ("content", "ep1"):
        run([cli, "unbundle", Path(game) / "archive" / "pc" / archive, "-r", regex, "-o", out, "-v", "Minimal"], "unbundle " + regex)


class Bink:
    """The game's Bink 2 decoder (bin/x64/bink2w64.dll) through ctypes."""

    class Head(ctypes.Structure):
        _fields_ = [("Width", ctypes.c_uint32), ("Height", ctypes.c_uint32), ("Frames", ctypes.c_uint32),
                    ("FrameNum", ctypes.c_uint32), ("LastFrameNum", ctypes.c_uint32),
                    ("FrameRate", ctypes.c_uint32), ("FrameRateDiv", ctypes.c_uint32)]

    BINKALPHA, SURFACE32A, COPYALL = 0x00100000, 5, 0x80000000

    def __init__(self, game):
        dll = Path(game) / "bin" / "x64" / "bink2w64.dll"
        os.add_dll_directory(str(dll.parent))
        self.lib = lib = ctypes.WinDLL(str(dll))
        lib.BinkOpen.restype = ctypes.POINTER(Bink.Head)
        lib.BinkOpen.argtypes = [ctypes.c_char_p, ctypes.c_uint32]
        for name in ("BinkDoFrame", "BinkNextFrame", "BinkClose"):
            getattr(lib, name).argtypes = [ctypes.c_void_p]
        lib.BinkCopyToBuffer.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int32, ctypes.c_uint32,
                                         ctypes.c_uint32, ctypes.c_uint32, ctypes.c_uint32]
        lib.BinkGetError.restype = ctypes.c_char_p
        lib.BinkSetSoundTrack.argtypes = [ctypes.c_uint32, ctypes.c_void_p]

    def frames(self, path):
        lib = self.lib
        lib.BinkSetSoundTrack(0, None)
        handle = lib.BinkOpen(str(Path(path).resolve()).encode("mbcs"), Bink.BINKALPHA)
        if not handle:
            raise RuntimeError(f"BinkOpen {path}: {lib.BinkGetError()}")
        head = handle.contents
        w, h, count = head.Width, head.Height, head.Frames
        fps = head.FrameRate / max(1, head.FrameRateDiv)
        buffer = (ctypes.c_ubyte * (w * 4 * h))()
        try:
            for i in range(count):
                lib.BinkDoFrame(handle)
                lib.BinkCopyToBuffer(handle, buffer, w * 4, h, 0, 0, Bink.SURFACE32A | Bink.COPYALL)
                bgra = np.frombuffer(buffer, dtype=np.uint8).reshape(h, w, 4)
                yield i, count, fps, bgra[..., [2, 1, 0, 3]].copy()
                if i + 1 < count:
                    lib.BinkNextFrame(handle)
        finally:
            lib.BinkClose(handle)


def alpha_box(rgba, threshold=24):
    ys, xs = np.nonzero(rgba[..., 3] > threshold)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def encode_video(bink, source, target, max_size, work, crf, gains=(1.35, 1.0)):
    frames_dir = work / ("frames-" + target.stem)
    if frames_dir.exists():
        shutil.rmtree(frames_dir)
    frames_dir.mkdir(parents=True)
    info = {}
    for i, count, fps, rgba in bink.frames(source):
        image = Image.fromarray(grade(rgba, *gains))
        if i == 0:
            scale = min(1.0, max_size / max(image.size))
            size = (int(round(image.width * scale / 2)) * 2, int(round(image.height * scale / 2)) * 2)
            info = {"width": size[0], "height": size[1], "frames": count, "fps": fps,
                    "box": alpha_box(np.array(image.resize(size, Image.LANCZOS)))}
        image.resize((info["width"], info["height"]), Image.LANCZOS).save(frames_dir / f"f{i:04d}.png", compress_level=1)
    target.parent.mkdir(parents=True, exist_ok=True)
    run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(info["fps"]), "-i", frames_dir / "f%04d.png",
         "-c:v", "libvpx-vp9", "-pix_fmt", "yuva420p", "-b:v", "0", "-crf", str(crf), "-row-mt", "1",
         "-deadline", "good", "-cpu-used", "2", "-auto-alt-ref", "0", "-an", target], "ffmpeg " + target.name)
    shutil.rmtree(frames_dir)
    info["bytes"] = target.stat().st_size
    return info


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--game", default=os.environ.get("OP77_GAME_DIR", DEFAULT_GAME))
    parser.add_argument("--cli", default=DEFAULT_CLI)
    parser.add_argument("--probe", default=None, help="NCWE.Probe.exe (exports the game's sounds)")
    parser.add_argument("--work", default=str(ROOT / ".work"))
    parser.add_argument("--only", default="videos,stills,icons,assets,sounds", help="any of videos, bodies (the two idle loops only), stills, icons, assets, sounds")
    parser.add_argument("--crf", type=int, default=33)
    args = parser.parse_args()
    only = set(args.only.split(","))
    work = Path(args.work)
    raw = work / "raw"
    png = work / "png"
    work.mkdir(parents=True, exist_ok=True)
    manifest_path = MEDIA / "manifest.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    manifest["note"] = "Generated by ripperdoc-ui/scripts/build-assets.py from the local game install."

    paperdoll = raw / "base" / "movies" / "misc" / "paperdoll"
    if {"videos", "stills"} & only and not paperdoll.exists():
        unbundle(args.cli, args.game, raw, r"^base.movies.misc.paperdoll.")
    if {"stills", "icons", "assets"} & only and not (png / "man_body.inkatlas").exists():
        unbundle(args.cli, args.game, raw, r"^base.gameplay.gui.fullscreen.ripperdoc.")
        unbundle(args.cli, args.game, raw, r"^base.gameplay.gui.common.icons.items.item_icons[0-9]+\.(inkatlas|xbm)$")
        png.mkdir(parents=True, exist_ok=True)
        run([args.cli, "export", raw / "base/gameplay/gui/common/icons/items", raw / "base/gameplay/gui/fullscreen/ripperdoc",
             "-o", png, "--uext", "png", "-gp", args.game, "-v", "Minimal"], "export textures")

    if {"videos", "bodies"} & only:
        bink = Bink(args.game)
        videos = manifest.setdefault("videos", {})
        for body in ("male", "female"):
            # The full body is mostly "warm" skin: a gentler grade keeps it amber glass, not gold.
            info = encode_video(bink, paperdoll / (BODY_LOOP[body] + ".bk2"), MEDIA / "video" / f"{body}_body.webm", 1100, work, args.crf, BODY_GAINS)
            videos[f"{body}_body"] = info
            print(f"{body}_body", info)
            if "videos" not in only:
                continue
            for section, stem in SECTIONS.items():
                info = encode_video(bink, paperdoll / (PREFIX[body] + stem + ".bk2"), MEDIA / "video" / f"{body}_{section}.webm", 1000, work, args.crf)
                videos[f"{body}_{section}"] = info
                print(f"{body}_{section}", info)
                manifest_path.parent.mkdir(parents=True, exist_ok=True)
                manifest_path.write_text(json.dumps(manifest, indent=1))

    if "stills" in only:
        # Register each full-body overlay on the idle loop by their alpha boxes (same camera, same pose).
        bink = Bink(args.game)
        stills = manifest.setdefault("stills", {})
        for body in ("male", "female"):
            loop = next(bink.frames(paperdoll / (BODY_LOOP[body] + ".bk2")))[3]
            lx0, ly0, lx1, ly1 = alpha_box(loop)
            lw, lh = loop.shape[1], loop.shape[0]
            atlas = png / ("man_body.inkatlas" if body == "male" else "woman_body.inkatlas") / "2160p"
            for system, stem in STILLS[body].items():
                image = np.array(Image.open(atlas / f"{stem}.png").convert("RGBA"))
                sx0, sy0, sx1, sy1 = alpha_box(image)
                image = image[sy0:sy1, sx0:sx1]
                target = MEDIA / "still" / f"{body}_{system}.webp"
                target.parent.mkdir(parents=True, exist_ok=True)
                out = Image.fromarray(grade(image))
                out.thumbnail((700, 1400), Image.LANCZOS)
                out.save(target, "WEBP", quality=84, method=6)
                # where the overlay's own box lands on the loop, in loop fractions (the bodies share a pose)
                stills[f"{body}_{system}"] = {"left": lx0 / lw, "top": ly0 / lh, "width": (lx1 - lx0) / lw,
                                              "height": (ly1 - ly0) / lh, "bytes": target.stat().st_size}
                print(f"{body}_{system}", stills[f"{body}_{system}"])

    if "icons" in only:
        icons = []
        for source in sorted(png.glob("item_icons*.inkatlas/2160p/cw*.png")):
            target = MEDIA / "icon" / (icon_file(source.stem) + ".webp")
            target.parent.mkdir(parents=True, exist_ok=True)
            Image.open(source).convert("RGBA").save(target, "WEBP", quality=88, method=6)
            icons.append(source.stem)
        manifest["icons"] = sorted(set(icons))
        print(len(icons), "icons")

    if "assets" in only:
        parts = png / "assets" / "cw_paperdoll_assets.inkatlas" / "2160p"
        for name in ("circle_1", "circle_2", "circle_3", "dots_bg", "man_cables", "woman_cables", "dashed_line"):
            source = parts / f"{name}.png"
            if not source.exists():
                continue
            image = Image.fromarray(grade(np.array(Image.open(source).convert("RGBA")), warm_gain=1.6, cool_gain=1.25))
            image.thumbnail((1000, 1000), Image.LANCZOS)
            target = MEDIA / "ui" / f"{name}.webp"
            target.parent.mkdir(parents=True, exist_ok=True)
            image.save(target, "WEBP", quality=86, method=6)
        print("ui assets done")

    if "sounds" in only:
        if not args.probe:
            print("sounds skipped: pass --probe <NCWE.Probe.exe>")
        else:
            sfx = MEDIA / "sfx"
            sfx.mkdir(parents=True, exist_ok=True)
            for name, event in SOUNDS.items():
                wav = work / f"{event}.wav"
                run([args.probe, "--game", args.game, "--sound-export", event, "--out", wav], "sound " + event)
                run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-ar", "44100",
                     "-c:a", "libmp3lame", "-b:a", "160k", sfx / f"{name}.mp3"], "mp3 " + name)
                print("sfx", name)
            manifest["sfx"] = sorted(SOUNDS)

    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=1))
    print("manifest", manifest_path)


if __name__ == "__main__":
    sys.exit(main())
