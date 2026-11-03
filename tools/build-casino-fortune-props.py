#!/usr/bin/env python3
"""Cook the original Night City Fortune Wheel (big-six money wheel) props.

The prop API only moves props and turns them about the vertical axis, so the
vertical rotor is authored as pose meshes: its face has two-fold symmetry, so
27 rotor poses (one per segment of half a turn) cover all 54 rest positions.
Two radial-blur discs stand in at speed, the flapper has four deflection
poses, the two 40x segments get their own orbiting medallions, and chip stacks
come in six heights. Inactive poses are parked inside the closed drum, behind
the active rotor. Coordinates are board-local unscaled metres and must match
client/core/casino_fortune.lua (all of them are unchanged by the restyle).

Uses the existing native board-prop cooker as a read-only schema/tool library
and tools/wheel_tables_art.py for the typeface, textures and materials. Only
this resource and --work receive outputs. Requires Pillow, numpy, .NET and
WolvenKit from the inspected local lab. `--preview-only` renders the
sources/preview_*.png critique images without cooking.
"""
import argparse, base64, hashlib, importlib.util, json, math, os, struct, subprocess, sys, zipfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import wheel_tables_art as A
RESOURCE = ROOT / 'resources/assets/models/open77_casino_fortune'
DEPOT = 'open77\\assets\\op77_lightrp\\casino_fortune'
LAB = ROOT.parent / 'dop-tests'
spec = importlib.util.spec_from_file_location('native_boards', ROOT / 'tools/build-board-game-props.py'); base = importlib.util.module_from_spec(spec); spec.loader.exec_module(base)
base.RESOURCE = RESOURCE; base.DEPOT = DEPOT
spec = importlib.util.spec_from_file_location('collision_props', ROOT / 'tools/collision_props.py'); col = importlib.util.module_from_spec(spec); spec.loader.exec_module(col)

# Layout shared with the Lua client (unscaled metres, -Y is the player side).
SEGMENTS, POSES = 54, 27
STEP = 360 / SEGMENTS
HALF = ['S', '1', '2', '1', '5', '1', '2', '1', '10', '1', '2', '5', '1', '20', '1', '2', '1', '5', '2', '1', '10', '1', '2', '5', '1', '2', '1']
WY, WZ = .10, 2.15          # rotor face plane and wheel centre
R_FACE, R_PEG, R_LIP = .66, .625, .665
PEG_LEN, PEG_R = .06, .009
FLAP_PIVOT = (0, .042, WZ + .74)
FLAP_LEN = .15
FLAP_ANGLES = [-6, 0, 4.5, 9]  # overshoot, rest, half kick, full kick (tip toward +X)
MEDALLION_R, MEDAL_RADIUS = .42, .026
FELT = (-.72, .72, -.96, -.44, 1.252)  # x0,x1,y0,y1,z
SPOT_X = [-.6 + .2 * i for i in range(7)]; SPOT_Y, PAYOUT_Y = -.68, -.84
SPOTS = ['1', '2', '5', '10', '20', 'eye', 'star']
CHIP_COUNTS = [1, 2, 3, 5, 8, 12]
PARK_Y = .195                # client: parked rotor poses, inside the drum
DRUM_R, DRUM_BACK, CAVITY_R, CAVITY_BACK = .82, .27, .70, .25
TABLE = (-.82, .82, -1.07, -.33)    # betting counter outline (rounded)
TOP_Z = 1.25

def layout(i):
    s = HALF[i % 27]
    return ('eye' if i == 0 else 'star') if s == 'S' else s

# ------------------------------------------------------------------ materials
S = A.Spec
SEG_COLORS = {'1': (236, 186, 72), '2': (44, 214, 255), '5': (255, 54, 186), '10': (150, 246, 88), '20': (158, 104, 255), 'S': (236, 236, 244)}
GOLD = (226, 178, 92)
CHIP_KEYS = ['chip_crimson', 'chip_cyan', 'chip_green', 'chip_graphite', 'chip_violet', 'chip_gold']
MATERIALS = {
    'face': S('fortune_face', (255, 255, 255), .16, .1, ((255, 255, 255), 'lines'), 'fortune_face_glow'),
    'blur': S('fortune_blur', (255, 255, 255), .2, .1, ((255, 255, 255), 'soft'), 'fortune_blur'),
    'felt': S('fortune_felt', (255, 255, 255), .55, 0., ((255, 255, 255), 'lines'), 'fortune_felt_glow'),
    'marquee': S('fortune_marquee', (255, 255, 255), .05, .1, ((255, 255, 255), 'sign'), 'fortune_marquee'),
    'medals': S('fortune_medals', (255, 255, 255), .1, .1, ((255, 255, 255), 'sign'), 'fortune_medals'),
    'gunmetal': S('brushed', (255, 255, 255), .34, .9),
    'black_chrome': S(None, (26, 28, 33), .12, 1.),
    'chrome': S(None, (205, 209, 216), .06, 1.),
    'gold': S(None, GOLD, .2, 1.),
    'smoked_glass': S(None, (9, 11, 14), .03, .25),
    'cavity': S(None, (6, 6, 8), .9, 0.),
    'carbon': S('carbon', (255, 255, 255), .28, .35),
    'composite': S('composite', (255, 255, 255), .62, 0.),
    'cushion': S('composite', (190, 188, 196), .42, 0.),
    'neon_cyan': S(None, (48, 226, 255), .3, 0., ((48, 226, 255), 'neon')),
    'neon_magenta': S(None, (255, 46, 196), .3, 0., ((255, 46, 196), 'soft')),
    'lamp': S(None, (255, 214, 140), .2, 0., ((255, 196, 110), 'lamp')),
    'flapper': S(None, (168, 174, 184), .16, 1.),
    'chip_white': S(None, (214, 216, 222), .4, 0.),
    'chip_crimson': S(None, (150, 18, 40), .4, 0.),
    'chip_cyan': S(None, (24, 132, 166), .4, 0.),
    'chip_green': S(None, (40, 120, 60), .4, 0.),
    'chip_graphite': S(None, (36, 38, 44), .4, 0.),
    'chip_violet': S(None, (92, 52, 160), .4, 0.),
    'chip_gold': S(None, (176, 132, 54), .4, 0.),
}
TEXTURE_NAMES = ['brushed', 'carbon', 'composite', 'fortune_face', 'fortune_face_glow', 'fortune_blur', 'fortune_felt', 'fortune_felt_glow', 'fortune_marquee', 'fortune_medals']
TEXTURED = {k for k, s in MATERIALS.items() if s.tex and s.tex.startswith('fortune_')}
# Player collision (tools/COLLISION.md): the betting counter, the tower and the
# drum. The space in front of the counter (Y < -1.07) stays free for players.
COLLIDERS = {'fortune_stand': [col.Box.between((-.80, -1.05, 0), (.80, -.35, TOP_Z + .05)),
                               col.Box.between((-.30, -.35, 0), (.30, .30, WZ - .70)),
                               col.Box.between((-.80, -.02, WZ - .80), (.80, DRUM_BACK, WZ + .80))]}

# ------------------------------------------------------------------ geometry
def polar(r, a, y=0):
    """Point on the vertical wheel plane: `a` degrees clockwise from the top seen from the front."""
    t = math.radians(a); return [r * math.sin(t), y, r * math.cos(t)]


def turn(faces, degrees, origin=(0, 0, 0)):
    """Turn geometry clockwise (seen from the front) about the Y axis through origin."""
    d = math.radians(degrees); c, s = math.cos(d), math.sin(d); out = []
    for f in faces:
        n = dict(f)
        for k in ('a', 'b', 'c'):
            x, y, z = f[k][0] - origin[0], f[k][1], f[k][2] - origin[2]
            n[k] = [origin[0] + x * c + z * s, y, origin[2] - x * s + z * c]
        out.append(n)
    return out


def ylathe(out, profile, color, sides=96, cx=0, cz=0, start=0., colors=None):
    """Lathe about the Y axis: profile (r,h) with h=-y (front is +h), solid on the right."""
    local = []; A.lathe(local, profile, color, sides, start=start, colors=colors)
    out += A.transform(local, lambda p: (cx + p[0], -p[2], cz + p[1]))  # a rotation: windings hold


def face_uv(p, segment):
    """Half-texture UV: segments 27..53 reuse 0..26 through the half-turn symmetry."""
    rho = math.hypot(p[0], p[2]); a = math.degrees(math.atan2(p[0], p[2])) + STEP / 2
    if segment >= 27: a -= 180
    a = math.radians(a); x, z = rho * math.sin(a), rho * math.cos(a)
    return [max(0, min(1, x / R_FACE)), .5 - z / (2 * R_FACE)]


def rim_band(out, color):
    """Chrome rotor edge (hidden behind the drum lip) closing the silhouette."""
    for i in range(SEGMENTS):
        a0, a1 = (i - .5) * STEP, (i + .5) * STEP
        e = [polar(R_FACE, a0), polar(R_FACE, a1), polar(R_FACE, a1, .025), polar(R_FACE, a0, .025)]
        A.quad(out, e, color, polar(1, i * STEP))


def rotor_base():
    out = []; front = (0, -1, 0)
    for i in range(SEGMENTS):
        a0, a1 = (i - .5) * STEP, (i + .5) * STEP
        pts = [[0, 0, 0], polar(R_FACE, a0), polar(R_FACE, a1)]
        A.tri(out, *pts, 'face', uv=[face_uv(p, i) for p in pts], facing=front)
    rim_band(out, 'chrome')
    for i in range(SEGMENTS):
        # Chrome pegs on the segment boundaries, standing out toward the player.
        c = polar(R_PEG, (i + .5) * STEP); peg = []
        A.lathe(peg, [(0, PEG_LEN), (PEG_R * .75, PEG_LEN), (PEG_R, PEG_LEN - .003), (PEG_R, 0)], 'chrome', 8)
        out += A.transform(peg, lambda p, c=c: (c[0] + p[0], -p[2], c[2] + p[1]))
    return out


def blur_disc():
    out = []; front = (0, -1, 0)
    for i in range(SEGMENTS):
        a0, a1 = (i - .5) * STEP, (i + .5) * STEP
        pts = [[0, 0, 0], polar(R_FACE, a0), polar(R_FACE, a1)]
        A.tri(out, *pts, 'blur', uv=[[.5 + p[0] / (2 * R_FACE), .5 - p[2] / (2 * R_FACE)] for p in pts], facing=front)
    rim_band(out, 'chrome')
    return out


def medallion(offset):
    out = []; n = 24; front = (0, -1, 0); r = MEDAL_RADIUS
    for k in range(n):
        a0, a1 = k * 360 / n, (k + 1) * 360 / n
        pts = [[0, -.006, 0], polar(r, a0, -.006), polar(r, a1, -.006)]
        A.tri(out, *pts, 'medals', uv=[[offset + .25 * p[0] / r, .5 - .5 * p[2] / r] for p in pts], facing=front)
    # Chrome bezel: a thin raised ring around the art, back to the face.
    ylathe(out, [(r, .006), (r + .003, .0075), (r + .004, .004), (r + .004, 0)], 'chrome', n)
    return out


def flapper(angle):
    """Solid satin-steel blade with a gold tip and a cyan inlay, hung from a chrome hinge."""
    out = []
    poly = [(-.021, .0), (.021, .0), (.013, -FLAP_LEN + .03), (.007, -FLAP_LEN + .004), (0, -FLAP_LEN), (-.007, -FLAP_LEN + .004), (-.012, -FLAP_LEN + .03)]
    def blade(points, y0, y1, color):
        cx = sum(p[0] for p in points) / len(points); cz = sum(p[1] for p in points) / len(points)
        for y, facing in ((y0, (0, -1, 0)), (y1, (0, 1, 0))):
            for k in range(1, len(points) - 1):
                A.tri(out, [points[0][0], y, points[0][1]], [points[k][0], y, points[k][1]], [points[k + 1][0], y, points[k + 1][1]], color, facing=facing)
        for k in range(len(points)):
            (x0, z0), (x1, z1) = points[k], points[(k + 1) % len(points)]
            A.quad(out, [[x0, y0, z0], [x1, y0, z1], [x1, y1, z1], [x0, y1, z0]], color, [(x0 + x1) / 2 - cx, 0, (z0 + z1) / 2 - cz])
    blade(poly[:3] + [(-.013, -FLAP_LEN + .03)], -.006, .006, 'flapper')
    blade([(-.013, -FLAP_LEN + .03), (.013, -FLAP_LEN + .03), (.007, -FLAP_LEN + .004), (0, -FLAP_LEN), (-.007, -FLAP_LEN + .004)], -.0055, .0055, 'gold')
    A.box(out, (0, -.0064, -.045), (.004, .0008, .06), 'neon_cyan', top=False, bottom=False)
    A.box(out, (0, 0, .006), (.044, .02, .03), 'chrome')
    ylathe(out, [(0, .013), (.0065, .013), (.0065, -.013), (0, -.013)], 'gold', 12, 0, .006)
    return turn(out, -angle)  # positive angle: tip swings toward +X


def chips(count):
    out = []
    for k in range(count):
        z = k * .0082; c = CHIP_KEYS[k % len(CHIP_KEYS)]
        stripes = lambda kk, jj, c=c: 'chip_white' if jj == 2 and kk % 4 == 0 else c
        A.lathe(out, [(0, z + .0080), (.033, z + .0080), (.035, z + .0068), (.035, z + .0012), (.033, z), (0, z)], c, 24, colors=stripes)
        A.lathe(out, [(.020, z + .0081), (.026, z + .0081)], 'chip_white', 24)
    return out


def rounded_rect(x0, x1, y0, y1, r, step=.05, arc=8):
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for k in range(arc + 1):
            t = math.radians(a0 + 90 * k / arc); pts.append((cx + r * math.cos(t), cy + r * math.sin(t)))
    dense = []
    for i, p in enumerate(pts):
        q = pts[(i + 1) % len(pts)]
        n = max(1, int(math.ceil(math.hypot(q[0] - p[0], q[1] - p[1]) / step)))
        dense += [(p[0] + (q[0] - p[0]) * s / n, p[1] + (q[1] - p[1]) * s / n) for s in range(n)]
    return dense


def stand():
    out = []
    x0, x1, y0, y1, fz = FELT
    # Floor plinth under the counter and the tower, with a magenta underglow.
    plinth = rounded_rect(-.86, .86, -1.12, .36, .14); pn = A.outline_normals(plinth)
    A.fan(out, plinth, .06, 'black_chrome')
    A.sweep(out, plinth, pn, [(-.012, .06), (0, .05), (0, .016)], 'black_chrome')
    A.sweep(out, plinth, pn, [(0, .016), (0, .013)], 'gold')
    A.sweep(out, plinth, pn, [(-.012, .013), (-.012, 0)], 'neon_magenta')
    A.sweep(out, plinth, pn, [(0, .013), (-.012, .013)], 'black_chrome')
    # Betting counter: rail cushion, black-chrome slab with a cyan line, a
    # waisted gunmetal body with a carbon front panel.
    tp = rounded_rect(*TABLE, .11); tn = A.outline_normals(tp)
    front = lambda k, j: 'carbon' if tp[k][1] < TABLE[2] + .001 and tp[(k + 1) % len(tp)][1] < TABLE[2] + .001 else 'gunmetal'
    A.sweep(out, tp, tn, [(-.075, TOP_Z), (-.071, TOP_Z + .026), (-.058, TOP_Z + .044), (-.036, TOP_Z + .052), (-.014, TOP_Z + .047), (-.003, TOP_Z + .034), (0, TOP_Z + .022)], 'cushion')
    A.sweep(out, tp, tn, [(0, TOP_Z + .022), (.003, TOP_Z + .014), (.003, TOP_Z + .008)], 'chrome')
    A.sweep(out, tp, tn, [(.003, TOP_Z + .008), (.003, TOP_Z - .040)], 'black_chrome')
    A.sweep(out, tp, tn, [(.003, TOP_Z - .040), (.003, TOP_Z - .0435)], 'neon_cyan')
    A.sweep(out, tp, tn, [(.003, TOP_Z - .0435), (.003, TOP_Z - .08), (-.05, TOP_Z - .08)], 'black_chrome')
    A.sweep(out, tp, tn, [(-.05, TOP_Z - .08), (-.085, .72), (-.075, .16)], 'gunmetal', colors=front)
    A.sweep(out, tp, tn, [(-.075, .16), (-.075, .152)], 'gold')
    A.sweep(out, tp, tn, [(-.075, .152), (-.075, .06)], 'black_chrome')
    inner = [(p[0] - .075 * n[0], p[1] - .075 * n[1]) for p, n in zip(tp, tn)]
    A.fan(out, inner, TOP_Z, 'composite')
    pts = [[x0, y0, fz], [x1, y0, fz], [x1, y1, fz], [x0, y1, fz]]
    A.quad(out, pts, 'felt', (0, 0, 1), [[(p[0] - x0) / (x1 - x0), (y1 - p[1]) / (y1 - y0)] for p in pts])
    # Tower: a tapered spine from the plinth into the drum, flanked by chrome fins.
    sp = rounded_rect(-.17, .17, .06, .26, .06); sn = A.outline_normals(sp)
    A.sweep(out, sp, sn, [(0, WZ - .70), (0, .80), (.03, .30), (.06, .06)], 'gunmetal',
            colors=lambda k, j: 'carbon' if j == 0 and sp[k][1] < .061 and sp[(k + 1) % len(sp)][1] < .061 else 'gunmetal')
    for s in (-1, 1):
        A.box(out, (s * .215, .16, .82), (.014, .16, 1.30), 'black_chrome')
        A.box(out, (s * .215, .079, .82), (.006, .003, 1.24), 'gold', top=False, bottom=False)
    # Drum: cavity (where the inactive poses are parked), flange, lip, bezel
    # with lamps and a cyan ring, outer wall and back.
    ylathe(out, [(0, -CAVITY_BACK), (CAVITY_R, -CAVITY_BACK), (CAVITY_R, -.07), (R_LIP, -.07), (R_LIP, -.05)], 'cavity', 108, 0, WZ)
    ylathe(out, [(R_LIP, -.05), (.69, -.045), (.72, -.040)], 'chrome', 108, 0, WZ)
    ylathe(out, [(.72, -.040), (.785, -.040)], 'black_chrome', 108, 0, WZ)
    ylathe(out, [(.785, -.040), (.792, -.040)], 'neon_cyan', 108, 0, WZ)
    ylathe(out, [(.792, -.040), (.805, -.037), (DRUM_R, -.030)], 'chrome', 108, 0, WZ)
    ylathe(out, [(DRUM_R, -.030), (DRUM_R, -.12)], 'black_chrome', 108, 0, WZ)
    ylathe(out, [(DRUM_R, -.12), (DRUM_R, -.13)], 'gold', 108, 0, WZ)
    ylathe(out, [(DRUM_R, -.13), (DRUM_R, -DRUM_BACK), (0, -DRUM_BACK)], 'carbon', 108, 0, WZ)
    # The illuminated rim: 52 lamps, the top left clear for the flapper bracket.
    for k in range(54):
        a = k * STEP + STEP / 2
        if a < 10 or a > 350: continue
        p = polar(.7525, a); lamp = []
        A.lathe(lamp, [(0, .0105), (.0055, .0095), (.009, .0055), (.0105, 0)], 'lamp', 12)
        A.lathe(lamp, [(.0105, 0), (.0135, 0), (.0135, -.002)], 'chrome', 12)
        out += A.transform(lamp, lambda q, p=p: (p[0] + q[0], .040 - q[2], WZ + p[2] + q[1]))
    # Static hub cap (rotationally symmetric: never needs a pose).
    ylathe(out, [(0, .080), (.030, .080), (.036, .078)], 'black_chrome', 48, 0, WZ)
    ylathe(out, [(.036, .078), (.060, .074), (.090, .066), (.108, .058), (.112, .052)], 'chrome', 48, 0, WZ)
    ylathe(out, [(.112, .052), (.125, .052), (.125, .046)], 'gold', 48, 0, WZ)
    ylathe(out, [(0, .0805), (.008, .0805)], 'neon_cyan', 24, 0, WZ)
    # Flapper bracket at twelve o'clock holding the hinge pin.
    A.box(out, (0, .030, WZ + .785), (.07, .024, .09), 'chrome')
    A.box(out, (0, .0175, WZ + .812), (.05, .002, .03), 'gold', top=False, bottom=False)
    # Marquee crown above the drum: smoked-glass sign in a chrome frame.
    A.box(out, (0, .14, WZ + .955), (1.10, .10, .28), 'black_chrome')
    for z in (WZ + .815, WZ + 1.095):
        A.box(out, (0, .088, z), (1.12, .012, .01), 'chrome')
    for x in (-.555, .555):
        A.box(out, (x, .088, WZ + .955), (.01, .012, .29), 'chrome')
    mx0, mx1, mz0, mz1 = -.54, .54, WZ + .825, WZ + 1.085
    pts = [[mx0, .086, mz0], [mx1, .086, mz0], [mx1, .086, mz1], [mx0, .086, mz1]]
    A.quad(out, pts, 'marquee', (0, -1, 0), [[(p[0] - mx0) / (mx1 - mx0), (mz1 - p[2]) / (mz1 - mz0)] for p in pts])
    return out


def models():
    result = {'fortune_stand': stand()}
    rotor = rotor_base()
    for p in range(POSES): result[f'fortune_disc_{p:02d}'] = turn(rotor, p * STEP)
    disc = blur_disc(); result['fortune_blur_0'] = disc; result['fortune_blur_1'] = turn(disc, 1.5 * STEP)
    for i, a in enumerate(FLAP_ANGLES): result[f'fortune_flapper_{i}'] = flapper(a)
    result['fortune_eye'] = medallion(.25); result['fortune_star'] = medallion(.75)
    for i, n in enumerate(CHIP_COUNTS): result[f'fortune_chips_{i + 1}'] = chips(n)
    return result


# ------------------------------------------------------------------ artwork
def rgba(c, a=255): return tuple(c[:3]) + (a,)
def shade(c, k): return tuple(max(0, min(255, round(v * k))) for v in c)


def draw_segment(im, glow, cx, cy, rpx, label, a0):
    """One segment spanning [a0,a0+STEP] degrees clockwise from the top."""
    d = ImageDraw.Draw(im); g = ImageDraw.Draw(glow); s = rpx / R_FACE
    def box(r): return (cx - r * s, cy - r * s, cx + r * s, cy + r * s)
    special = label in ('eye', 'star')
    col = SEG_COLORS['S' if special else label]
    start, end = a0 - 90, a0 + STEP - 90
    # Dark smoked glass tinted by the segment colour, a luminous colour band
    # near the rim, and a deeper inner field.
    dark = lambda k: tuple(int(10 + v * k) for v in col)
    d.pieslice(box(.600), start, end, fill=rgba(dark(.11)))
    d.pieslice(box(.400), start, end, fill=rgba(dark(.06)))
    d.pieslice(box(.260), start, end, fill=rgba(dark(.035)))
    band = shade(col, .95)
    d.pieslice(box(.600), start, end, fill=rgba(band)); d.pieslice(box(.586), start, end, fill=rgba(dark(.11)))
    d.pieslice(box(.405), start, end, fill=rgba(shade(col, .55))); d.pieslice(box(.400), start, end, fill=rgba(dark(.06)))
    g.pieslice(box(.600), start, end, fill=rgba(shade(col, .75))); g.pieslice(box(.586), start, end, fill=(0, 0, 0, 255))
    mid = a0 + STEP / 2
    text = '40' if special else label
    ink = (246, 246, 250)
    h = (.046 if len(text) == 1 else .036) * s
    for r, word, hh, glow_k in ((.520, text, h, .42), (.462, 'x', .026 * s, .25)):
        t = math.radians(mid); x = cx + math.sin(t) * r * s; y = cy - math.cos(t) * r * s
        A.draw_text(im, word, (x, y), hh, ink if word != 'x' else shade(col, .9) if not special else GOLD, angle=mid, stroke=.14)
        A.draw_text(glow, word, (x, y), hh, tuple(int(v * glow_k) for v in (col if not special else GOLD)), angle=mid, stroke=.14)
    if special:
        t = math.radians(mid); x = cx + math.sin(t) * MEDALLION_R * s; y = cy - math.cos(t) * MEDALLION_R * s; r = (MEDAL_RADIUS + .006) * s
        d.ellipse((x - r, y - r, x + r, y + r), fill=(14, 13, 10, 255), outline=rgba(GOLD), width=max(2, round(.003 * s)))


def draw_frame(im, cx, cy, rpx, angles):
    d = ImageDraw.Draw(im); s = rpx / R_FACE; lw = max(2, round(.0028 * s))
    for a in angles:
        t = math.radians(a)
        d.line((cx + math.sin(t) * .13 * s, cy - math.cos(t) * .13 * s, cx + math.sin(t) * .60 * s, cy - math.cos(t) * .60 * s), fill=rgba(GOLD), width=lw)
    for r in (.60, .26, .13):
        d.ellipse((cx - r * s, cy - r * s, cx + r * s, cy + r * s), outline=rgba(GOLD), width=lw)
    # Outer peg ring: black chrome track with a fine chrome line.
    d.ellipse((cx - .66 * s, cy - .66 * s, cx + .66 * s, cy + .66 * s), outline=(16, 17, 21, 255), width=round(.058 * s))
    d.ellipse((cx - .645 * s, cy - .645 * s, cx + .645 * s, cy + .645 * s), outline=(120, 126, 136, 255), width=max(1, lw // 2))


def face_art(full=False):
    """full=False: the 1024x2048 half texture (segments 0..26, frame turned half a step)
    and its 512x1024 emission mask."""
    k = 2
    if full:
        W = H = 1024 * k; cx = cy = W / 2; rpx = W / 2
        im = Image.new('RGBA', (W, H), (10, 10, 13, 255)); glow = Image.new('RGBA', (W, H), (0, 0, 0, 255))
        for i in range(SEGMENTS): draw_segment(im, glow, cx, cy, rpx, layout(i), (i - .5) * STEP)
        draw_frame(im, cx, cy, rpx, [(i - .5) * STEP for i in range(SEGMENTS)])
    else:
        W, H = 1024 * k, 2048 * k; cx, cy, rpx = 0, H / 2, W
        im = Image.new('RGBA', (W, H), (10, 10, 13, 255)); glow = Image.new('RGBA', (W, H), (0, 0, 0, 255))
        for i in range(27): draw_segment(im, glow, cx, cy, rpx, layout(i), i * STEP)
        draw_frame(im, cx, cy, rpx, [i * STEP for i in range(28)])
    d = ImageDraw.Draw(im); s = rpx / R_FACE
    d.ellipse((cx - .125 * s, cy - .125 * s, cx + .125 * s, cy + .125 * s), fill=(18, 19, 23, 255))
    return im.resize((W // k, H // k), Image.Resampling.LANCZOS), glow.resize((W // (2 * k), H // (2 * k)), Image.Resampling.LANCZOS)


def blur_art():
    src, _ = face_art(True); W = src.width; c = (W / 2, W / 2); acc = None; n = 0
    for k in range(-10, 11):
        layer = src.rotate(k * 1.25, resample=Image.Resampling.BILINEAR, center=c)
        acc = layer if acc is None else Image.blend(acc, layer, 1 / (n + 1)); n += 1
    d = ImageDraw.Draw(acc); s = (W / 2) / R_FACE
    for r, w, colr in ((R_PEG, PEG_R * 2.2, (150, 156, 166)), (.60, .004, GOLD), (.26, .004, GOLD)):
        d.ellipse((c[0] - r * s, c[1] - r * s, c[0] + r * s, c[1] + r * s), outline=rgba(colr), width=max(2, round(w * s)))
    return acc.resize((512, 512), Image.Resampling.LANCZOS)


def eye_star(im, box, kind):
    d = ImageDraw.Draw(im); x0, y0, x1, y1 = box; cx, cy = (x0 + x1) / 2, (y0 + y1) / 2; r = (x1 - x0) / 2
    def circ(rr, fill): d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=rgba(fill))
    if kind == 'eye':
        circ(r, (8, 10, 14)); circ(r * .9, (40, 214, 255)); circ(r * .84, (6, 22, 30))
        # An almond eye outline with a cyan iris and a white pupil glint.
        pts = []
        for k in range(48):
            t = k / 48 * math.tau; pts.append((cx + math.cos(t) * r * .74, cy + math.sin(t) * r * .40 * abs(math.sin(t)) ** .3 * (1 if math.sin(t) >= 0 else 1)))
        d.polygon(pts, fill=rgba((14, 40, 50))); d.line(pts + pts[:1], fill=rgba((140, 240, 255)), width=max(2, round(r * .05)))
        circ(r * .30, (40, 214, 255)); circ(r * .17, (4, 10, 14)); circ(r * .06, (240, 255, 255))
    else:
        circ(r, (12, 8, 14)); circ(r * .9, (255, 54, 186)); circ(r * .84, (24, 8, 22))
        pts = []
        for k in range(16):
            t = math.radians(k * 360 / 16); rr = r * (.74 if k % 2 == 0 else .30)
            pts.append((cx + math.sin(t) * rr, cy - math.cos(t) * rr))
        d.polygon(pts, fill=rgba((255, 206, 110))); circ(r * .18, (255, 54, 186)); circ(r * .08, (255, 246, 230))


def medal_art():
    k = 2; im = Image.new('RGBA', (512 * k, 256 * k), (10, 10, 14, 255))
    eye_star(im, (0, 0, 256 * k, 256 * k), 'eye'); eye_star(im, (256 * k, 0, 512 * k, 256 * k), 'star')
    return im.resize((512, 256), Image.Resampling.LANCZOS)


def felt_art():
    """Seven betting spots matching the wheel: dark composite, neon-edged tiles,
    big multiplier numerals, the 40x icons. Returns (base 1024x512, glow 512x256)."""
    x0, x1, y0, y1, _ = FELT; k = 2000; W, H = round((x1 - x0) * k), round((y1 - y0) * k)
    bg = A.composite(512, (19, 21, 26))
    im = Image.new('RGBA', (W, H)); glow = Image.new('RGBA', (W, H), (0, 0, 0, 255))
    for tx in range(0, W, 512):
        for ty in range(0, H, 512): im.paste(bg, (tx, ty))
    d = ImageDraw.Draw(im); g = ImageDraw.Draw(glow)
    def px(x, y): return ((x - x0) * k, (y1 - y) * k)
    m = .012 * k
    d.rectangle((m, m, W - m, H - m), outline=rgba(GOLD), width=4)
    d.rectangle((m + 10, m + 10, W - m - 10, H - m - 10), outline=rgba(shade(GOLD, .6)), width=2)
    A.draw_text(im, 'WINNERS PAID MULTIPLIER X STAKE PLUS STAKE', (W / 2, .045 * k), .016 * k, shade(GOLD, .95), tracking=1.6)
    for spot, x in zip(SPOTS, SPOT_X):
        cx, cy = px(x, SPOT_Y); col = SEG_COLORS['S' if spot in ('eye', 'star') else spot]
        special = spot in ('eye', 'star')
        hw, top, bottom = .088 * k, .145 * k, .20 * k
        tile = (cx - hw, cy - top, cx + hw, cy + bottom)
        d.rounded_rectangle(tile, radius=.018 * k, fill=rgba(shade(col, .10)))
        A.glow_line(im, lambda dd, f, t=tile: dd.rounded_rectangle(t, radius=.018 * k, outline=f, width=6), col, 10, .9, shade(col, 1.0))
        g.rounded_rectangle(tile, radius=.018 * k, outline=rgba(shade(col, .9)), width=6)
        if special:
            eye_star(im, (cx - .056 * k, cy - .056 * k, cx + .056 * k, cy + .056 * k), spot)
            eye_star(glow, (cx - .056 * k, cy - .056 * k, cx + .056 * k, cy + .056 * k), spot)
            label = '40x'
        else:
            label = spot + 'x'
            ring = (cx - .062 * k, cy - .062 * k, cx + .062 * k, cy + .062 * k)
            d.ellipse(ring, outline=rgba(shade(col, .7)), width=4)
        A.draw_text(im, label, (cx, cy - (.105 * k if special else .0) ), (.040 if special else .062) * k, (246, 246, 250) if not special else GOLD, stroke=.13)
        A.draw_text(glow, label, (cx, cy - (.105 * k if special else .0)), (.040 if special else .062) * k, shade(col if not special else GOLD, .5), stroke=.13)
        pays = {'eye': 'NEON EYE', 'star': 'STARBURST'}.get(spot, 'PAYS %s TO 1' % spot)
        A.draw_text(im, pays, (cx, cy + .105 * k), .014 * k, (226, 228, 236), tracking=1.4)
        if special: A.draw_text(im, 'PAYS 40 TO 1', (cx, cy + .150 * k), .013 * k, (200, 190, 168), tracking=1.4)
    return im.resize((1024, 512), Image.Resampling.LANCZOS), glow.resize((512, 256), Image.Resampling.LANCZOS)


def marquee_art():
    k = 2; W, H = 1024 * k, 256 * k; im = Image.new('RGBA', (W, H), (8, 8, 12, 255))
    d = ImageDraw.Draw(im)
    for y in range(0, H, 6 * k): d.line((0, y, W, y), fill=(12, 12, 17, 255))
    A.glow_line(im, lambda dd, f: dd.rounded_rectangle((16 * k, 16 * k, W - 16 * k, H - 16 * k), radius=26 * k, outline=f, width=3 * k), (255, 46, 196), 10 * k, 1.2)
    A.draw_text(im, 'FORTUNE WHEEL', (W / 2, H / 2 - 14 * k), 76 * k, (255, 232, 190), stroke=.11, tracking=1.4, glow=((255, 176, 70), 8 * k, 1.3))
    A.draw_text(im, '54 SEGMENTS  -  UP TO 40 TO 1', (W / 2, H - 46 * k), 22 * k, (64, 226, 255), tracking=1.8, glow=((40, 200, 255), 4 * k, 1.2))
    for x in (78 * k, W - 78 * k):
        pts = []
        for j in range(16):
            t = math.radians(j * 22.5); rr = (34 if j % 2 == 0 else 12) * k; pts.append((x + math.sin(t) * rr, H / 2 - 14 * k - math.cos(t) * rr))
        A.glow_line(im, lambda dd, f, p=pts: dd.polygon(p, fill=f), (64, 226, 255), 6 * k, 1.0, (190, 248, 255))
    return im.resize((1024, 256), Image.Resampling.LANCZOS)


def artwork():
    face, face_glow = face_art(); felt, felt_glow = felt_art()
    return {'brushed': A.brushed_metal(256, (82, 86, 95)), 'carbon': A.carbon_weave(512, 64), 'composite': A.composite(512),
            'fortune_face': face, 'fortune_face_glow': face_glow, 'fortune_blur': blur_art(), 'fortune_felt': felt,
            'fortune_felt_glow': felt_glow, 'fortune_marquee': marquee_art(), 'fortune_medals': medal_art()}


# The engine samples rows bottom-up relative to our UVs (seen in game: text
# upside down), so the cooked bytes are flipped vertically; sources/ keeps the
# drawing upright. Set FLIP_V=False to cook the image as drawn.
FLIP_V = True
def cooked(image): return image.transpose(Image.Transpose.FLIP_TOP_BOTTOM) if FLIP_V else image


def material(color): return A.cook_material(MATERIALS[color], DEPOT)
base.material = material


def glb(path, faces):
    colors = base.glb(path, faces); A.patch_uvs(path, faces); return colors


# ------------------------------------------------------------------ previews
def previews(geometry, images):
    import wheel_tables_preview as pv
    mats = {k: A.preview_material(s, images) for k, s in MATERIALS.items()}
    src = RESOURCE / 'sources'
    r = 13  # rest pose: segment (-13)%54 = 41 under the flapper
    a = math.radians(r * STEP)
    def scene(pose=r % POSES, flap=1, blur=None):
        items = [pv.place(geometry['fortune_stand'])]
        if blur is None:
            items.append(pv.place(geometry[f'fortune_disc_{pose:02d}'], (0, WY, WZ)))
            items.append(pv.place(geometry['fortune_eye'], (MEDALLION_R * math.sin(a), WY, WZ + MEDALLION_R * math.cos(a))))
            items.append(pv.place(geometry['fortune_star'], (-MEDALLION_R * math.sin(a), WY, WZ - MEDALLION_R * math.cos(a))))
        else:
            items.append(pv.place(geometry[f'fortune_blur_{blur}'], (0, WY, WZ)))
        items.append(pv.place(geometry[f'fortune_flapper_{flap}'], FLAP_PIVOT))
        for x, n in ((-.6, 4), (0, 2), (.4, 5)):
            items.append(pv.place(geometry[f'fortune_chips_{n}'], (x, SPOT_Y, FELT[4])))
        return items
    shots = [
        pv.render(scene(), mats, src / 'preview_fortune_hero.png', eye=(1.9, -3.9, 2.35), target=(0, -.25, 1.75), fov=42, floor_z=0),
        pv.render(scene(flap=3), mats, src / 'preview_fortune_wheel.png', eye=(0, -1.55, 2.55), target=(0, WY, 2.35), fov=46),
        pv.render(scene(), mats, src / 'preview_fortune_felt.png', eye=(0, -1.85, 2.15), target=(0, -.66, 1.25), fov=44),
        pv.render(scene(blur=0, flap=2), mats, src / 'preview_fortune_blur.png', eye=(-1.6, -2.6, 2.3), target=(0, 0, 2.0), fov=40),
    ]
    pv.sheet(shots, src / 'preview_fortune.png', 2)


# ------------------------------------------------------------------ checks
def check_poses(geometry):
    """Authored-pose invariants the Lua client relies on (before cooking)."""
    def pegs(faces):
        return [f for f in faces if f['color'] == 'chrome' and all(abs(f[k][1] + PEG_LEN) < 1e-9 for k in 'abc')]
    for p in range(POSES):
        faces = geometry[f'fortune_disc_{p:02d}']
        # The textured triangle of segment (-p)%54 straddles the top: its centroid is straight up.
        top = (-p) % SEGMENTS; tris = [f for f in faces if f['color'] == 'face']
        assert len(tris) == SEGMENTS
        f = tris[top]; cx = (f['a'][0] + f['b'][0] + f['c'][0]) / 3; cz = (f['a'][2] + f['b'][2] + f['c'][2]) / 3
        assert abs(cx) < 1e-9 and cz > 0, (p, cx, cz)
        # Pegs sit half a segment either side of the top, where the flapper hangs.
        xs = sorted(round(sum(v[0] for v in (f['a'], f['b'], f['c'])) / 3, 4) for f in pegs(faces) if sum(v[2] for v in (f['a'], f['b'], f['c'])) / 3 > .6)
        assert any(abs(x - R_PEG * math.sin(math.radians(STEP / 2))) < .012 for x in xs) and any(abs(x + R_PEG * math.sin(math.radians(STEP / 2))) < .012 for x in xs), (p, xs)
        assert HALF[top % 27] == HALF[(top + 27) % 27]
        # Every pose fits the drum cavity when parked behind the active rotor.
        assert max(math.hypot(v[0], v[2]) for f in faces for v in (f['a'], f['b'], f['c'])) <= R_FACE + 1e-9
        assert PARK_Y - PEG_LEN > WY + .025 and PARK_Y + .025 < CAVITY_BACK
    for i, a in enumerate(FLAP_ANGLES):
        tips = [v for f in geometry[f'fortune_flapper_{i}'] if f['color'] in ('flapper', 'gold') for v in (f['a'], f['b'], f['c'])]
        low = min(tips, key=lambda v: v[2]); assert abs(low[2] + FLAP_LEN * math.cos(math.radians(a))) < .02
        if a > 0: assert low[0] > 0
    # The flapper tip reaches into the peg ring, in front of the face, clear of the lamps.
    assert FLAP_PIVOT[2] - FLAP_LEN < WZ + R_PEG - PEG_R and FLAP_PIVOT[1] - .006 < WY and FLAP_PIVOT[1] + .006 > WY - PEG_LEN
    assert R_FACE < R_LIP < CAVITY_R < DRUM_R


def verify(work, manifest):
    """Independent cooked-file, namespace, package-index and authored-pose checks."""
    spec = importlib.util.spec_from_file_location('archive_checks', ROOT / 'tools/test-board-game-props.py'); checks = importlib.util.module_from_spec(spec); spec.loader.exec_module(checks)
    archive = work / 'archive'; verified = work / 'verified'; packed = (work / 'packed/archive.archive').read_bytes()
    entries = checks.archive_entries(packed); files = manifest['files']
    n_models = 1 + POSES + 2 + len(FLAP_ANGLES) + 2 + len(CHIP_COUNTS); n_tex = len(TEXTURE_NAMES)
    assert len(manifest['models']) == n_models == 42 and len(manifest['textures']) == n_tex
    assert len(entries) == len(files) == 2 * n_models + n_tex + len(COLLIDERS)
    assert set(entries) == {checks.fnv(row['depot']) for row in files}
    assert [c['name'] for c in manifest['colliders']] == [col.collider_name(n) for n in COLLIDERS]
    for row in manifest['colliders']:
        assert col.check_collider_entity(next(verified.rglob(row['name'] + '.ent.json')), COLLIDERS[row['for']]) == len(COLLIDERS[row['for']])
    allowed = {row['depot'] for row in files} | set(manifest['materialDependencies'])
    for row in files:
        data = (archive / row['depot'].replace('\\', '/')).read_bytes()
        assert data[:4] == b'CR2W' and len(data) == row['bytes'] and hashlib.sha256(data).hexdigest() == row['sha256']
    emissive = {k for k, s in MATERIALS.items() if s.emit}
    hashes = set()
    for model in manifest['models']:
        name = model['name']
        for ext, kind in (('mesh', 'CMesh'), ('ent', 'entEntityTemplate')):
            candidates = list(verified.rglob(f'{name}.{ext}.json')); assert len(candidates) == 1, (name, ext)
            r = json.loads(candidates[0].read_text())['Data']['RootChunk']; assert r['$type'] == kind
            for path in checks.depot_paths(r): assert not path or path in allowed, (name, path)
            if ext == 'ent':
                assert r['entity']['Data']['$type'] == 'entEntity' and len(r['components']) == 1
                assert r['components'][0]['mesh']['DepotPath']['$value'] == model['mesh']
                continue
            assert r['objectType'] == 'ROT_Static' and not r['boneNames'] and not r['parameters']
            hashes.add(r['geometryHash'])
            blob = r['renderResourceBlob']['Data']; chunks = blob['header']['renderChunkInfos']; assert sum(c['numIndices'] for c in chunks) // 3 == model['triangles']
            pixels = base64.b64decode(blob['renderBuffer']['Bytes'])
            for chunk_index, chunk in enumerate(chunks):
                vertices = chunk['chunkVertices']; layout_ = vertices['vertexLayout']; elements = layout_['elements']['Elements']
                for color in (e for e in elements if e['usage'] == 'PS_Color'):
                    stream = color['streamIndex']; offset = vertices['byteOffsets']['Elements'][stream]; stride = layout_['slotStrides']['Elements'][stream]
                    assert all(pixels[offset + j * stride:offset + j * stride + 4] == b'\xff' * 4 for j in range(chunk['numVertices']))
                uv = next(e for e in elements if e['usage'] == 'PS_TexCoord' and e['usageIndex'] == 0); stream = uv['streamIndex']; offset = vertices['byteOffsets']['Elements'][stream]; stride = layout_['slotStrides']['Elements'][stream]
                values = [struct.unpack_from('<ee', pixels, offset + j * stride) for j in range(chunk['numVertices'])]
                assert all(math.isfinite(v) for pair in values for v in pair) and len(set(values)) > 1
                if model['materials'][chunk_index] in TEXTURED:
                    assert all(-.001 <= v <= 1.001 for pair in values for v in pair), (name, 'artwork UV out of bounds')
            mats = r['localMaterialBuffer']['materials']; names = {e['name']['$value'] for e in r['materialEntries']}
            assert all(0 <= e['index'] < len(mats) for e in r['materialEntries'])
            assert all(c['$value'] in names for a in r['appearances'] for c in a['Data']['chunkMaterials'])
            for key, mat in zip(model['materials'], mats):
                params = {k for v in mat['values'] for k in v if k != '$type'}
                assert ('EmissiveEV' in params) == (key in emissive), (name, key)
            lo, hi = r['boundingBox']['Min'], r['boundingBox']['Max']
            for i, axis in enumerate(('X', 'Y', 'Z')):
                assert math.isfinite(lo[axis]) and math.isfinite(hi[axis]) and lo[axis] < hi[axis]
                assert abs(lo[axis] - model['bounds']['min'][i]) < 1e-5 and abs(hi[axis] - model['bounds']['max'][i]) < 1e-5
    assert len(hashes) == n_models, 'every pose is distinct geometry'
    for texture in manifest['textures']:
        r = json.loads(next(verified.rglob(texture['name'] + '.xbm.json')).read_text())['Data']['RootChunk']
        assert r['$type'] == 'CBitmapTexture' and r['width'] == texture['width'] and r['height'] == texture['height']
        blob = r['renderTextureResource']['renderResourceBlobPC']['Data']; data = base64.b64decode(blob['textureData']['Bytes'])
        assert len(blob['header']['mipMapInfo']) == texture['mips']
        source = RESOURCE / 'sources' / (texture['name'] + '.png'); image = Image.open(source).convert('RGBA')
        assert hashlib.sha256(source.read_bytes()).hexdigest() == texture['sourceSha256']
        assert data[:image.width * image.height * 4] == (cooked(image) if texture.get('flipV') else image).tobytes() and all(v == 255 for v in data[3::4])
    by_name = {m['name']: m for m in manifest['models']}
    for p in range(POSES):
        b = by_name[f'fortune_disc_{p:02d}']['bounds']; assert max(abs(v) for v in b['min'] + b['max']) <= R_FACE + 1e-6
    sb = by_name['fortune_stand']['bounds']; assert sb['max'][2] < 3.3 and sb['min'][2] == 0 and max(abs(sb['min'][0]), sb['max'][0]) < .9 and sb['min'][1] > -1.2, sb
    with zipfile.ZipFile(RESOURCE / 'dist/open77_casino_fortune.zip') as z:
        assert z.testzip() is None and z.namelist() == ['archive/pc/mod/0_open77_casino_fortune.archive']
        assert z.read(z.namelist()[0]) == packed
    print(f'VERIFIED: {n_models} native props ({POSES} rotor poses, 2 blur, {len(FLAP_ANGLES)} flapper, 2 medallions, {len(CHIP_COUNTS)} chip stacks, stand) + {len(COLLIDERS)} collider entity, {n_tex} opaque mipmapped textures, {len(files)} exact RDAR entries, geometry/bindings/emission/package hashes', flush=True)


def main():
    p = argparse.ArgumentParser(description=__doc__); p.add_argument('--lab', type=Path, default=LAB); p.add_argument('--work', type=Path, default=Path.home() / '.cache/casino-fortune-build')
    p.add_argument('--verify-only', action='store_true'); p.add_argument('--preview-only', action='store_true'); a = p.parse_args(); work = a.work
    if a.verify_only:
        verify(work, json.loads((RESOURCE / 'asset-manifest.json').read_text())); return
    geometry = models(); check_poses(geometry); images = artwork()
    (RESOURCE / 'sources').mkdir(parents=True, exist_ok=True)
    previews(geometry, images)
    if a.preview_only:
        return  # texture sources are only rewritten by a cook (their hashes are in the manifest)
    tools = a.lab / 'tools'; env = os.environ.copy(); env['DOTNET_ROOT'] = str(tools / 'dotnet'); env['DOTNET_CLI_HOME'] = str(work / 'dotnet-home')
    def cli(*args, imports=0):
        result = subprocess.run([str(tools / 'dotnet/dotnet'), str(tools / 'wolvenkit/WolvenKit.CLI.dll'), *map(str, args)], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if '[ 0: Error' in result.stdout or (result.returncode and not (imports and result.stdout.count('Rebuilt with buffers:') == imports)): print(result.stdout); raise RuntimeError('WolvenKit failed ' + str(args))
        print('\n'.join(line for line in result.stdout.splitlines() if 'Success' in line)[-1500:], flush=True)
    schemas = work / 'json'; raw = work / 'raw'; tex = work / 'texture-json'; host = work / 'host-schema'
    for folder in (schemas, raw, tex, host, work / 'dotnet-home'): folder.mkdir(parents=True, exist_ok=True)
    for stale in (RESOURCE / 'sources').glob('*.png'):
        if not stale.name.startswith('preview_') and stale.stem not in TEXTURE_NAMES: stale.unlink()
    donor = json.loads((a.lab / 'donor/oni-json/v_sportbike13_methodd_oni__ext01_body_01.mesh.json').read_text())
    cli('convert', 'serialize', '/home/dop42/opx_pool_assets/assets/hosts/open77/assets/opx_infinity/pool/ball_01.ent', '-o', host); template = json.loads((host / 'ball_01.ent.json').read_text())
    textures = [A.encode_texture(tex, RESOURCE / 'sources', DEPOT, name, images[name], cooked) for name in TEXTURE_NAMES]
    records = []
    for i, (name, faces) in enumerate(geometry.items()):
        colors = glb(raw / (name + '.mesh.glb'), faces)
        (schemas / (name + '.mesh.json')).write_text(json.dumps(base.mesh_json(donor, colors, faces)))
        (schemas / (name + '.ent.json')).write_text(json.dumps(base.entity_json(template, name, 7700 + i)))
        records.append({'name': name, 'mesh': DEPOT + '\\' + name + '.mesh', 'entity': DEPOT + '\\' + name + '.ent', 'triangles': len(faces), 'materials': colors,
                        'bounds': {'min': [min(f[k][j] for f in faces for k in ('a', 'b', 'c')) for j in range(3)], 'max': [max(f[k][j] for f in faces for k in ('a', 'b', 'c')) for j in range(3)]}})
    colliders = []
    for i, (name, boxes) in enumerate(COLLIDERS.items()):
        (schemas / (col.collider_name(name) + '.ent.json')).write_text(json.dumps(col.collider_entity_json(template, boxes, i)))
        colliders.append({'name': col.collider_name(name), 'for': name, 'entity': DEPOT + '\\' + col.collider_name(name) + '.ent',
                          'scaleBaked': col.SCALE, 'boxes': [{'size': list(b.size), 'center': list(b.center)} for b in boxes]})
    archive = work / 'archive'; target = archive / DEPOT.replace('\\', '/'); (target / 'textures').mkdir(parents=True, exist_ok=True)
    cli('convert', 'deserialize', schemas, '-o', target); cli('convert', 'deserialize', tex, '-o', target / 'textures'); cli('import', *[raw / (name + '.mesh.glb') for name in geometry], '-o', target, '--keep', imports=len(geometry))
    verified = work / 'verified'; verified.mkdir(exist_ok=True); cli('convert', 'serialize', archive, '-o', verified); packed = work / 'packed'; packed.mkdir(exist_ok=True); cli('pack', archive, '-o', packed)
    archive_file = packed / 'archive.archive'; assert archive_file.read_bytes()[:4] == b'RDAR'; output = RESOURCE / 'dist/open77_casino_fortune.zip'; output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        info = zipfile.ZipInfo('archive/pc/mod/0_open77_casino_fortune.archive', (2026, 1, 1, 0, 0, 0)); info.compress_type = zipfile.ZIP_DEFLATED; info.external_attr = 0o100644 << 16; z.writestr(info, archive_file.read_bytes())
    files = [{'depot': str(q.relative_to(archive)).replace('/', '\\'), 'sha256': hashlib.sha256(q.read_bytes()).hexdigest(), 'bytes': q.stat().st_size} for q in sorted(archive.rglob('*')) if q.is_file()]
    manifest = {'version': '2.0.0', 'style': 'Night City high-roller: black chrome drum with an illuminated rim, smoked-glass segments, neon spot tiles',
                'namespace': DEPOT, 'models': records, 'colliders': colliders, 'textures': textures, 'files': files,
                'wheel': {'segments': SEGMENTS, 'poses': POSES, 'halfLayout': HALF, 'faceY': WY, 'centreZ': WZ, 'faceRadius': R_FACE, 'pegRadius': R_PEG, 'parkY': PARK_Y,
                          'flapperPivot': FLAP_PIVOT, 'flapperAngles': FLAP_ANGLES, 'medallionRadius': MEDALLION_R, 'chipCounts': CHIP_COUNTS, 'spotX': SPOT_X, 'spotY': SPOT_Y, 'feltZ': FELT[4]},
                'emission': {k: {'rgb': s.emit[0], 'ev': s.ev()} for k, s in MATERIALS.items() if s.emit},
                'archiveSha256': hashlib.sha256(archive_file.read_bytes()).hexdigest(), 'zipSha256': hashlib.sha256(output.read_bytes()).hexdigest(), 'buildWork': str(work),
                'materialDependencies': A.depot_dependencies(MATERIALS.values())}
    (RESOURCE / 'asset-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n'); print('COOKED', len(records), 'models,', len(textures), 'textures,', len(files), 'native files, ZIP', output.stat().st_size, 'bytes', flush=True)
    verify(work, manifest)


if __name__ == '__main__': main()
