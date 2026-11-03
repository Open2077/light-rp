#!/usr/bin/env python3
"""Cook the original Night City roulette table, rotor and ball.

Three props, as before: `roulette_table` (the placed base: a full casino table
with the wheel bowl, ball track, deflectors, a printed betting layout, a chip
rack, a rail and a pedestal down to the floor), `roulette_wheel` (the rotor:
37 pockets with frets, an etched number ring, a brushed cone and a chrome
turret) and `roulette_ball`. Origin and datum are unchanged: the wheel centre
at Z=0 is the board position; the client turns the rotor and moves the ball.

Uses the existing native board-prop cooker as a read-only schema/tool library
and tools/wheel_tables_art.py for the typeface, textures and materials. Only
this resource and --work receive outputs. Requires Pillow, numpy, .NET and
WolvenKit from the inspected local lab. `--preview-only` renders the
sources/preview_*.png critique images without cooking.
"""
import argparse, base64, hashlib, importlib.util, json, math, os, struct, subprocess, sys, zipfile
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import wheel_tables_art as A
RESOURCE = ROOT / 'resources/assets/models/open77_tabletop_extra'
DEPOT = 'open77\\assets\\op77_lightrp\\tabletop_extra'
LAB = ROOT.parent / 'dop-tests'
ORDER = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
REDS = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}
spec = importlib.util.spec_from_file_location('native_boards', ROOT / 'tools/build-board-game-props.py'); base = importlib.util.module_from_spec(spec); spec.loader.exec_module(base)
base.RESOURCE = RESOURCE; base.DEPOT = DEPOT
spec = importlib.util.spec_from_file_location('collision_props', ROOT / 'tools/collision_props.py'); col = importlib.util.module_from_spec(spec); spec.loader.exec_module(col)

# Layout shared with client/core/tabletop_extra.lua (board-local unscaled metres).
STEP = 360 / 37
BALL_R = .015                 # was .009: ~2 cm in game at the 0.65 scale
POCKET_R, POCKET_Z = .27, .025  # settled ball centre (unchanged)
TRACK_R, TRACK_Z = .388, .074   # ball centre riding the ball track
POCKET_IN, POCKET_OUT, POCKET_FLOOR = .245, .292, POCKET_Z - BALL_R - .0005
RING_IN, RING_OUT, RING_Z = .292, .322, .030
ROTOR_R = .325
BOWL = [(.326, .000), (.326, .031), (.330, .033), (.372, .051), (.400, .063), (.403, .066), (.403, .088), (.406, .091), (.448, .091), (.450, .089), (.450, .020)]
TOP_Z = .020                  # table top
FLOOR_Z = -1.23               # 0.80 m in game below the wheel datum
HALF_W, END_X, CORNER = .56, 2.10, .38
LAYOUT = (.555, 1.905, -.265, .265)  # x0,x1,y0,y1 of the printed betting layout
LAYOUT_Z = TOP_Z + .0015
CELL, ZERO_W, DOZEN_H = .10, .10, .09
GRID_X0 = LAYOUT[0] + .025 + ZERO_W   # number grid starts after the zero
GRID_Y1 = LAYOUT[3] - .025            # top edge of the 3-6-9 row
RACK = (.62, 1.22, .30, .44)
# Player collision (tools/COLLISION.md): the slab and pedestal, wheel datum to
# the floor, slightly inside the rail; the wheel end is a narrower box.
COLLIDERS = {'roulette_table': [col.Box.between((-.40, -.50, FLOOR_Z), (END_X - .04, .50, .10)),
                                col.Box.between((-HALF_W + .03, -.30, FLOOR_Z), (-.40, .30, .10))]}

# ------------------------------------------------------------------ materials
S = A.Spec
CYAN, GOLD, CRIMSON = (48, 226, 255), (226, 178, 92), (176, 18, 42)
MATERIALS = {
    'gunmetal': S('brushed', (255, 255, 255), .34, .9),
    'black_chrome': S(None, (26, 28, 33), .12, 1.),
    'chrome': S(None, (205, 209, 216), .06, 1.),
    'gold': S(None, GOLD, .2, 1.),
    'smoked_glass': S(None, (9, 11, 14), .03, .25),
    'carbon': S('carbon', (255, 255, 255), .28, .35),
    'composite': S('composite', (255, 255, 255), .62, 0.),
    'cushion': S('composite', (190, 188, 196), .42, 0.),
    'neon_cyan': S(None, CYAN, .3, 0., (CYAN, 'neon')),
    'neon_magenta': S(None, (255, 46, 196), .3, 0., ((255, 46, 196), 'soft')),
    'layout': S('roulette_layout', (255, 255, 255), .55, 0., ((255, 255, 255), 'lines'), 'roulette_layout_glow'),
    'ring': S('roulette_ring', (255, 255, 255), .08, .2, ((255, 255, 255), 'soft'), 'roulette_ring'),
    'pocket_red': S(None, CRIMSON, .22, .3),
    'pocket_black': S(None, (14, 15, 18), .16, .3),
    'pocket_zero': S(None, (0, 132, 116), .22, .3),
    'ball': S(None, (246, 247, 250), .1, 0., ((235, 245, 255), 'soft')),
    'chip_white': S(None, (196, 198, 204), .4, 0.),
    'chip_cyan': S(None, (24, 120, 150), .4, 0.),
    'chip_magenta': S(None, (140, 26, 108), .4, 0.),
    'chip_gold': S(None, (170, 128, 52), .4, 0.),
    'chip_crimson': S(None, (120, 16, 32), .4, 0.),
    'chip_graphite': S(None, (40, 42, 48), .35, 0.),
}
TEXTURE_NAMES = ['brushed', 'carbon', 'composite', 'roulette_layout', 'roulette_layout_glow', 'roulette_ring']

# ------------------------------------------------------------------ geometry
def cw(a):
    """Unit vector at `a` degrees clockwise from +Y (the wheel's convention)."""
    t = math.radians(a); return (math.sin(t), math.cos(t))


def ring_path(n, offset=0.):
    dirs = [cw((k + offset) * 360 / n) for k in range(n)]
    return [(0., 0.)] * n, dirs


def rotor_lathe(out, profile, color, colors=None):
    path, dirs = ring_path(148, -2)  # 4 segments per pocket, pocket 0 centred on +Y
    A.sweep(out, path, dirs, profile, color, colors=colors)


def cone_z(r):
    """Brushed cone surface of the rotor, from the turret base to the pockets."""
    return .036 + (.080 - .036) * (1 - (r - .06) / (.236 - .06)) ** 1.35 if r > .06 else .080


def roulette_wheel():
    out = []
    cone = [(r, cone_z(r)) for r in (.06, .08, .10, .12, .14, .16, .18, .20, .215, .236)]
    rotor_lathe(out, [(0, .080), *cone[:1]], 'gunmetal')
    rotor_lathe(out, cone, 'gunmetal')
    # Inner chrome lip, pocket inner wall, coloured floors, outer wall, number ring, rim.
    rotor_lathe(out, [(.236, .036), (.241, .033), (.244, .030), (POCKET_IN, .028)], 'chrome')
    rotor_lathe(out, [(POCKET_IN, .028), (POCKET_IN, POCKET_FLOOR)], 'black_chrome')
    def pocket(k, j):
        n = ORDER[k // 4]; return 'pocket_zero' if n == 0 else 'pocket_red' if n in REDS else 'pocket_black'
    rotor_lathe(out, [(POCKET_IN, POCKET_FLOOR), (POCKET_OUT, POCKET_FLOOR)], 'pocket_black', colors=pocket)
    rotor_lathe(out, [(POCKET_OUT, POCKET_FLOOR), (POCKET_OUT, RING_Z)], 'black_chrome')
    # The number ring: an unwrapped strip texture (u around, v from the rim inward).
    for k in range(37 * 6):
        a0, a1 = (k / 6 - .5) * STEP, ((k + 1) / 6 - .5) * STEP
        u0, u1 = k / (37 * 6), (k + 1) / (37 * 6)
        p = [[*(RING_IN * v for v in cw(a0)), RING_Z], [*(RING_IN * v for v in cw(a1)), RING_Z],
             [*(RING_OUT * v for v in cw(a1)), RING_Z], [*(RING_OUT * v for v in cw(a0)), RING_Z]]
        A.quad(out, p, 'ring', (0, 0, 1), [[u0, 1], [u1, 1], [u1, 0], [u0, 0]])
    rotor_lathe(out, [(RING_OUT, RING_Z), (ROTOR_R, RING_Z - .003), (ROTOR_R, 0), (0, 0)], 'chrome')
    # Frets: thin chrome blades on the pocket boundaries.
    for i in range(37):
        fret = []
        A.box(fret, (0, (POCKET_IN + POCKET_OUT) / 2, (POCKET_FLOOR + .0262) / 2), (.0026, POCKET_OUT - POCKET_IN - .001, .0262 - POCKET_FLOOR), 'chrome', bottom=False)
        out += A.rotate_z(fret, -(i + .5) * STEP)
    # Neon ring and eight raised turbine ribs on the cone.
    rotor_lathe(out, [(.200, cone_z(.200) + .0008), (.2035, cone_z(.2035) + .0008)], 'gold')
    for i in range(8):
        rib = []
        rs = [.085 + k * .0175 for k in range(8)]
        for r0, r1 in zip(rs, rs[1:]):
            z0, z1 = cone_z(r0) + .0035, cone_z(r1) + .0035
            A.quad(rib, [[-.003, r0, z0], [.003, r0, z0], [.003, r1, z1], [-.003, r1, z1]], 'chrome', (0, -(z1 - z0), r1 - r0))
            for s in (-1, 1):
                A.quad(rib, [[s * .003, r0, z0 - .006], [s * .003, r1, z1 - .006], [s * .003, r1, z1], [s * .003, r0, z0]], 'chrome', (s, 0, 0))
        out += A.rotate_z(rib, -i * 45 - 22.5)
    # Chrome turret: flared base, slim column, arm hub, collar and a glowing tip.
    turret = [(.007, .180), (.010, .172), (.010, .166), (.017, .161), (.017, .153), (.010, .150), (.0095, .116),
              (.024, .112), (.024, .097), (.012, .094), (.012, .090), (.030, .086), (.054, .0835), (.062, .080)]
    A.lathe(out, turret, 'chrome', 48)
    A.lathe(out, [(0, .1835), (.004, .1830), (.007, .180)], 'neon_cyan', 48)
    for i in range(4):
        arm = []
        # A tapered blade from the hub to a knurled knob.
        pts = [(.020, .0055, .0045), (.060, .0045, .0040), (.104, .0034, .0034)]
        for (y0, w0, h0), (y1, w1, h1) in zip(pts, pts[1:]):
            c = .1045
            for s in (-1, 1):
                A.quad(arm, [[s * w0, y0, c - h0], [s * w1, y1, c - h1], [s * w1, y1, c + h1], [s * w0, y0, c + h0]], 'chrome', (s, 0, 0))
                A.quad(arm, [[-w0, y0, c + s * h0], [w0, y0, c + s * h0], [w1, y1, c + s * h1], [-w1, y1, c + s * h1]], 'chrome', (0, 0, s))
        knob = []
        A.lathe(knob, [(0, .1235), (.006, .1230), (.0085, .120), (.0085, .093), (.006, .0905), (0, .090)], 'black_chrome', 24)
        arm += A.translate(knob, (0, .112, 0))
        out += A.rotate_z(arm, -i * 90)
    return out


def table_outline(step=.04):
    pts = []
    for k in range(49):
        t = math.pi / 2 + math.pi * k / 48; pts.append((HALF_W * math.cos(t), HALF_W * math.sin(t)))
    cx = END_X - CORNER
    for k in range(13):
        t = -math.pi / 2 + math.pi / 2 * k / 12; pts.append((cx + CORNER * math.cos(t), -(HALF_W - CORNER) + CORNER * math.sin(t)))
    for k in range(13):
        t = math.pi / 2 * k / 12; pts.append((cx + CORNER * math.cos(t), (HALF_W - CORNER) + CORNER * math.sin(t)))
    dense = []
    for i, p in enumerate(pts):
        q = pts[(i + 1) % len(pts)]
        n = max(1, int(math.ceil(math.hypot(q[0] - p[0], q[1] - p[1]) / step)))
        dense += [(p[0] + (q[0] - p[0]) * s / n, p[1] + (q[1] - p[1]) * s / n) for s in range(n)]
    return dense


def roulette_table():
    out = []
    path = table_outline(); normals = A.outline_normals(path)
    # Rail cushion, chrome hairline, black-chrome slab edge with a cyan light
    # line, carbon skirt, gunmetal pedestal, plinth with a magenta underglow.
    rail = [(-.085, TOP_Z), (-.081, .044), (-.068, .064), (-.046, .073), (-.022, .070), (-.006, .058), (0, .044)]
    A.sweep(out, path, normals, rail, 'cushion')
    A.sweep(out, path, normals, [(0, .044), (.003, .036), (.003, .030)], 'chrome')
    A.sweep(out, path, normals, [(.003, .030), (.003, -.024)], 'black_chrome')
    A.sweep(out, path, normals, [(.003, -.024), (.003, -.0275)], 'neon_cyan')
    A.sweep(out, path, normals, [(.003, -.0275), (.003, -.10), (-.06, -.10)], 'black_chrome')
    A.sweep(out, path, normals, [(-.06, -.10), (-.06, -.205)], 'carbon')
    A.sweep(out, path, normals, [(-.06, -.205), (-.06, -.212)], 'gold')
    A.sweep(out, path, normals, [(-.06, -.212), (-.06, -.24), (-.20, -.24)], 'carbon')
    A.sweep(out, path, normals, [(-.20, -.24), (-.25, -.42), (-.275, -.62)], 'gunmetal')
    A.sweep(out, path, normals, [(-.275, -.62), (-.275, -.75)], 'carbon')
    A.sweep(out, path, normals, [(-.275, -.75), (-.26, -.95), (-.235, FLOOR_Z + .11)], 'gunmetal')
    A.sweep(out, path, normals, [(-.235, FLOOR_Z + .11), (-.205, FLOOR_Z + .11), (-.205, FLOOR_Z + .03)], 'black_chrome')
    A.sweep(out, path, normals, [(-.215, FLOOR_Z + .03), (-.215, FLOOR_Z)], 'neon_magenta')
    A.sweep(out, path, normals, [(-.205, FLOOR_Z + .03), (-.215, FLOOR_Z + .03)], 'black_chrome')
    # Table top: a ring from the bowl to the rail, star-shaped about the wheel.
    inner = [(p[0] + n[0] * -.085, p[1] + n[1] * -.085) for p, n in zip(path, normals)]
    for k in range(len(inner)):
        p, q = inner[k], inner[(k + 1) % len(inner)]
        ap, aq = math.atan2(p[1], p[0]), math.atan2(q[1], q[0])
        bp = (BOWL[-1][0] * math.cos(ap), BOWL[-1][0] * math.sin(ap)); bq = (BOWL[-1][0] * math.cos(aq), BOWL[-1][0] * math.sin(aq))
        A.quad(out, [[bp[0], bp[1], TOP_Z], [bq[0], bq[1], TOP_Z], [q[0], q[1], TOP_Z], [p[0], p[1], TOP_Z]], 'composite', (0, 0, 1))
    # Wheel bowl: inner wall, apron, ball track, back wall, rim with neon inlay, outer wall.
    A.lathe(out, BOWL[:3], 'black_chrome', 148)
    A.lathe(out, BOWL[2:4], 'black_chrome', 148)
    A.lathe(out, BOWL[3:5], 'smoked_glass', 148)
    A.lathe(out, BOWL[4:7], 'gunmetal', 148)
    A.lathe(out, [BOWL[6], BOWL[7], (.426, .091)], 'black_chrome', 148)
    A.lathe(out, [(.426, .091), (.4285, .091)], 'neon_cyan', 148)
    A.lathe(out, [(.4285, .091), BOWL[8], BOWL[9]], 'black_chrome', 148)
    A.lathe(out, [BOWL[9], (.450, .060)], 'black_chrome', 148)
    A.lathe(out, [(.450, .060), (.450, .056)], 'gold', 148)
    A.lathe(out, [(.450, .056), BOWL[10]], 'gunmetal', 148)
    A.disc(out, (0, 0), BOWL[0][0], -.001, 'black_chrome', 74)
    # Eight chrome deflectors on the apron, alternately radial and tangential.
    for i in range(8):
        r = .351; z = .033 + (r - .330) / (.372 - .330) * (.051 - .033)
        L, W = (.030, .011) if i % 2 == 0 else (.012, .024)
        d = []
        pts = [(0, r + L / 2), (W / 2, r), (0, r - L / 2), (-W / 2, r)]
        top = [0, r, z + .0075]
        for a, b in zip(pts, pts[1:] + pts[:1]):
            pa, pb = [a[0], a[1], z - .002], [b[0], b[1], z - .002]
            out_dir = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2 - r, .5]
            A.tri(d, pa, pb, top, 'chrome', facing=out_dir)
        out += A.rotate_z(d, -(i * 45 + 22.5))
    # Betting layout panel, framed by a thin gold trim.
    x0, x1, y0, y1 = LAYOUT
    A.quad(out, [[x0, y0, LAYOUT_Z], [x1, y0, LAYOUT_Z], [x1, y1, LAYOUT_Z], [x0, y1, LAYOUT_Z]], 'layout', (0, 0, 1),
           [[0, 1], [1, 1], [1, 0], [0, 0]])
    t = .006
    for (cx, cy, sx, sy) in (((x0 + x1) / 2, y0, x1 - x0 + 2 * t, t), ((x0 + x1) / 2, y1, x1 - x0 + 2 * t, t),
                             (x0, (y0 + y1) / 2, t, y1 - y0), (x1, (y0 + y1) / 2, t, y1 - y0)):
        A.box(out, (cx, cy, TOP_Z + .002), (sx, sy, .004), 'gold', bottom=False)
    out += chip_rack()
    return out


CHIP_COLORS = ['chip_white', 'chip_cyan', 'chip_magenta', 'chip_gold', 'chip_crimson', 'chip_graphite', 'chip_cyan', 'chip_white']


def chip_rack():
    """Black-chrome float with eight troughs of chips lying on their edge."""
    out = []
    x0, x1, y0, y1 = RACK
    A.box(out, ((x0 + x1) / 2, (y0 + y1) / 2, TOP_Z + .012), (x1 - x0, y1 - y0, .024), 'black_chrome', bottom=False)
    A.box(out, ((x0 + x1) / 2, y0 - .002, TOP_Z + .0255), (x1 - x0 - .01, .003, .003), 'neon_cyan', bottom=False)
    n = len(CHIP_COLORS); pitch = (x1 - x0 - .04) / n; r = .0285
    for i, color in enumerate(CHIP_COLORS):
        cx = x0 + .02 + pitch * (i + .5)
        chips = []
        count = 16; thick = (y1 - y0 - .03) / count
        for k in range(count):
            ya = y0 + .015 + k * thick
            prof = [(0, ya + thick - .0004), (r - .0015, ya + thick - .0004), (r, ya + thick - .0016), (r, ya + .0012), (r - .0015, ya), (0, ya)]
            part = []
            stripes = lambda kk, jj, c=color: ('chip_white' if c != 'chip_white' else 'chip_graphite') if (jj == 2 and kk % 4 == 0) else c
            A.lathe(part, prof, color, 20, colors=stripes)
            # Lathe about Z, then lay it along Y (a rotation, so the winding holds).
            chips += A.transform(part, lambda p: (p[0], p[2], -p[1]))
        out += A.translate(chips, (cx, 0, TOP_Z + .024 + r - .012))
    return out


def ball():
    out = []
    prof = [(BALL_R * math.sin(math.pi * k / 16), BALL_R * math.cos(math.pi * k / 16)) for k in range(17)]
    A.lathe(out, prof, 'ball', 32)
    return out


def models():
    return {'roulette_table': roulette_table(), 'roulette_wheel': roulette_wheel(), 'roulette_ball': ball()}


# ------------------------------------------------------------------ artwork
def layout_art():
    """The betting layout: dark composite, cyan grid lines, etched numerals,
    crimson/graphite number cells, a teal zero, dozens and even chances.
    Returns (base colour 2048x1024, emission mask 1024x512)."""
    x0, x1, y0, y1 = LAYOUT
    k = 3200  # px per metre while drawing (then resampled to the texture)
    W, H = round((x1 - x0) * k), round((y1 - y0) * k)
    px = lambda x, y: ((x - x0) * k, (y1 - y) * k)
    bg = A.composite(512, (19, 22, 27)).resize((512, 512))
    im = Image.new('RGBA', (W, H))
    for tx in range(0, W, 512):
        for ty in range(0, H, 512): im.paste(bg, (tx, ty))
    glow = Image.new('RGBA', (W, H), (0, 0, 0, 255))
    d = ImageDraw.Draw(im); g = ImageDraw.Draw(glow)
    line = max(2, round(.0022 * k))
    cyan = (64, 222, 255)
    cells = []  # (polygon, fill, text, text colour)
    gx0 = GRID_X0; top = GRID_Y1
    for col in range(12):
        for row in range(3):
            n = col * 3 + (3 - row)
            cx0, cy1 = gx0 + col * CELL, top - row * CELL
            poly = [px(cx0, cy1), px(cx0 + CELL, cy1), px(cx0 + CELL, cy1 - CELL), px(cx0, cy1 - CELL)]
            red = n in REDS
            cells.append((poly, (84, 8, 24) if red else (15, 17, 21), str(n), (255, 236, 240) if red else (236, 239, 245), red))
    zx0 = gx0 - ZERO_W
    zero = [px(zx0 + .035, top), px(gx0, top), px(gx0, top - 3 * CELL), px(zx0 + .035, top - 3 * CELL), px(zx0, top - 1.5 * CELL)]
    cells.append((zero, (0, 74, 66), '0', (200, 255, 246), None))
    dz = top - 3 * CELL
    for i, label in enumerate(('1ST 12', '2ND 12', '3RD 12')):
        poly = [px(gx0 + i * 4 * CELL, dz), px(gx0 + (i + 1) * 4 * CELL, dz), px(gx0 + (i + 1) * 4 * CELL, dz - DOZEN_H), px(gx0 + i * 4 * CELL, dz - DOZEN_H)]
        cells.append((poly, (22, 25, 30), label, (232, 236, 242), None))
    ev = dz - DOZEN_H
    for i, label in enumerate(('1-18', 'EVEN', 'RED', 'BLACK', 'ODD', '19-36')):
        poly = [px(gx0 + i * 2 * CELL, ev), px(gx0 + (i + 1) * 2 * CELL, ev), px(gx0 + (i + 1) * 2 * CELL, ev - DOZEN_H), px(gx0 + i * 2 * CELL, ev - DOZEN_H)]
        cells.append((poly, (22, 25, 30), label, (232, 236, 242), None))
    for poly, fill, text, ink, red in cells:
        d.polygon(poly, fill=fill + (255,))
    # Inner bevel: a faint lighter edge inside every cell.
    for poly, fill, text, ink, red in cells:
        xs = [p[0] for p in poly]; ys = [p[1] for p in poly]
        cx, cy = sum(xs) / len(xs), sum(ys) / len(ys)
        inset = [(cx + (p[0] - cx) * .9, cy + (p[1] - cy) * .86) for p in poly]
        d.line(inset + inset[:1], fill=tuple(min(255, v + 18) for v in fill) + (255,), width=max(1, line // 2))
    for poly, fill, text, ink, red in cells:
        xs = [p[0] for p in poly]; ys = [p[1] for p in poly]
        cx, cy = sum(xs) / len(xs), sum(ys) / len(ys)
        if text in ('RED', 'BLACK'):
            rw, rh = .055 * k, .030 * k
            dia = [(cx, cy - rh), (cx + rw, cy), (cx, cy + rh), (cx - rw, cy)]
            col = (182, 20, 46) if text == 'RED' else (30, 32, 38)
            edge = (255, 70, 110) if text == 'RED' else (226, 230, 238)
            d.polygon(dia, fill=col + (255,)); d.line(dia + dia[:1], fill=edge + (255,), width=line)
            g.line(dia + dia[:1], fill=edge + (255,), width=line)
            continue
        h = (.038 if len(text) <= 2 else .030) * k
        if text == '0': h = .05 * k
        angle = 0
        A.draw_text(im, text, (cx, cy), h, ink, angle=angle, stroke=.12)
        # Numbers glow faintly (a dimmer copy in the emission mask).
        A.draw_text(glow, text, (cx, cy), h, tuple(int(v * .38) for v in ink), angle=angle, stroke=.12)
    # Grid lines (crisp core + halo) and the double gold frame.
    for poly, fill, text, ink, red in cells:
        A.glow_line(im, lambda dd, f, p=poly: dd.line(p + p[:1], fill=f, width=line), cyan, round(.003 * k), .55, (120, 232, 255))
        g.line(poly + poly[:1], fill=(30, 140, 170, 255), width=line)
    m = .010 * k
    d.rectangle((m, m, W - m, H - m), outline=(226, 178, 92, 255), width=max(2, line // 2 + 1))
    d.rectangle((m + .006 * k, m + .006 * k, W - m - .006 * k, H - m - .006 * k), outline=(150, 118, 62, 255), width=max(1, line // 2))
    return im.resize((2048, 1024), Image.Resampling.LANCZOS), glow.resize((1024, 512), Image.Resampling.LANCZOS)


def ring_art():
    """Unwrapped number ring: u around the wheel (pocket i in [i/37,(i+1)/37]),
    v from the rim (top) to the pockets (bottom). Black glass, colour tab,
    etched upright numerals, hairline chrome dividers."""
    W, H = 4096, 128
    im = Image.new('RGBA', (W, H), (8, 9, 12, 255)); d = ImageDraw.Draw(im)
    pw = W / 37
    for i, n in enumerate(ORDER):
        x0 = i * pw
        col = (0, 150, 128) if n == 0 else (196, 22, 50) if n in REDS else (40, 42, 48)
        d.rectangle((x0, H - 22, x0 + pw, H), fill=col + (255,))
        d.line((x0, 0, x0, H), fill=(120, 126, 136, 255), width=2)
        A.draw_text(im, str(n), (x0 + pw / 2, 52), 62, (242, 244, 248), stroke=.13)
    d.line((0, 3, W, 3), fill=(110, 116, 126, 255), width=3)
    return im


def artwork():
    layout, glow = layout_art()
    return {'brushed': A.brushed_metal(256, (82, 86, 95)), 'carbon': A.carbon_weave(512, 64), 'composite': A.composite(512),
            'roulette_layout': layout, 'roulette_layout_glow': glow, 'roulette_ring': ring_art()}


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
    table, wheel, b = geometry['roulette_table'], geometry['roulette_wheel'], geometry['roulette_ball']
    on_track = (TRACK_R * math.sin(math.radians(168)), TRACK_R * math.cos(math.radians(168)), TRACK_Z)
    a = math.radians(14 * STEP + 33)
    in_pocket = (POCKET_R * math.sin(a), POCKET_R * math.cos(a), POCKET_Z)
    scene = [pv.place(table), pv.place(wheel, yaw=-33), pv.place(b, in_pocket)]
    shots = []
    shots.append(pv.render(scene, mats, src / 'preview_roulette_hero.png', eye=(2.9, -2.6, 1.55), target=(.75, 0, -.25), fov=38, floor_z=FLOOR_Z))
    shots.append(pv.render(scene, mats, src / 'preview_roulette_wheel.png', eye=(-.15, -.95, .62), target=(0, .02, .03), fov=38))
    shots.append(pv.render([pv.place(table), pv.place(wheel, yaw=-80), pv.place(b, on_track)], mats, src / 'preview_roulette_track.png',
                           eye=(-.10, -.80, .70), target=(0, .02, .03), fov=44))  # the client's 'black side' camera
    shots.append(pv.render(scene, mats, src / 'preview_roulette_layout.png', eye=(1.15, -1.25, 1.05), target=(1.15, -.05, 0), fov=42))
    pv.sheet(shots, src / 'preview_roulette.png', 2)


# ------------------------------------------------------------------ verify
def verify(work, manifest):
    """Independent cooked-file, namespace, package-index and authored-geometry checks."""
    spec = importlib.util.spec_from_file_location('archive_checks', ROOT / 'tools/test-board-game-props.py'); checks = importlib.util.module_from_spec(spec); spec.loader.exec_module(checks)
    archive = work / 'archive'; verified = work / 'verified'; packed = (work / 'packed/archive.archive').read_bytes()
    entries = checks.archive_entries(packed); files = manifest['files']
    n_tex = len(TEXTURE_NAMES)
    assert len(entries) == len(files) == 6 + n_tex + len(COLLIDERS) and len(manifest['models']) == 3 and len(manifest['textures']) == n_tex
    assert [c['name'] for c in manifest['colliders']] == [col.collider_name(n) for n in COLLIDERS]
    for row in manifest['colliders']:
        assert col.check_collider_entity(next(verified.rglob(row['name'] + '.ent.json')), COLLIDERS[row['for']]) == len(COLLIDERS[row['for']])
    assert set(entries) == {checks.fnv(row['depot']) for row in files}
    allowed = {row['depot'] for row in files} | set(manifest['materialDependencies'])
    for row in files:
        data = (archive / row['depot'].replace('\\', '/')).read_bytes()
        assert data[:4] == b'CR2W' and len(data) == row['bytes'] and hashlib.sha256(data).hexdigest() == row['sha256']
    textured = {k for k, s in MATERIALS.items() if s.tex and s.tex.startswith('roulette_')}
    emissive = {k for k, s in MATERIALS.items() if s.emit}
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
            blob = r['renderResourceBlob']['Data']; chunks = blob['header']['renderChunkInfos']; assert sum(c['numIndices'] for c in chunks) // 3 == model['triangles']
            pixels = base64.b64decode(blob['renderBuffer']['Bytes'])
            for chunk_index, chunk in enumerate(chunks):
                vertices = chunk['chunkVertices']; layout = vertices['vertexLayout']; elements = layout['elements']['Elements']
                for color in (e for e in elements if e['usage'] == 'PS_Color'):
                    stream = color['streamIndex']; offset = vertices['byteOffsets']['Elements'][stream]; stride = layout['slotStrides']['Elements'][stream]
                    assert all(pixels[offset + j * stride:offset + j * stride + 4] == b'\xff' * 4 for j in range(chunk['numVertices']))
                uv = next(e for e in elements if e['usage'] == 'PS_TexCoord' and e['usageIndex'] == 0); stream = uv['streamIndex']; offset = vertices['byteOffsets']['Elements'][stream]; stride = layout['slotStrides']['Elements'][stream]
                values = [struct.unpack_from('<ee', pixels, offset + j * stride) for j in range(chunk['numVertices'])]
                assert all(math.isfinite(v) for pair in values for v in pair) and len(set(values)) > 1
                if model['materials'][chunk_index] in textured:
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
    for texture in manifest['textures']:
        r = json.loads(next(verified.rglob(texture['name'] + '.xbm.json')).read_text())['Data']['RootChunk']
        assert r['$type'] == 'CBitmapTexture' and r['width'] == texture['width'] and r['height'] == texture['height']
        blob = r['renderTextureResource']['renderResourceBlobPC']['Data']; data = base64.b64decode(blob['textureData']['Bytes'])
        assert len(blob['header']['mipMapInfo']) == texture['mips']
        source = RESOURCE / 'sources' / (texture['name'] + '.png'); image = Image.open(source).convert('RGBA')
        assert hashlib.sha256(source.read_bytes()).hexdigest() == texture['sourceSha256']
        assert data[:image.width * image.height * 4] == (cooked(image) if texture.get('flipV') else image).tobytes() and all(v == 255 for v in data[3::4])
    by_name = {m['name']: m for m in manifest['models']}
    assert set(ORDER) == set(range(37)) and len(ORDER) == 37
    bb = by_name['roulette_ball']['bounds']; assert abs(bb['max'][2] - BALL_R) < 1e-6 and abs(bb['min'][2] + BALL_R) < 1e-6
    wb = by_name['roulette_wheel']['bounds']; assert abs(wb['min'][2]) < 1e-9 and wb['max'][0] <= ROTOR_R + 1e-6
    tb = by_name['roulette_table']['bounds']; assert abs(tb['min'][2] - FLOOR_Z) < 1e-9 and tb['min'][0] < -HALF_W + .01 and abs(tb['max'][0] - END_X - .003) < .01
    with zipfile.ZipFile(RESOURCE / 'dist/open77_tabletop_extra.zip') as z:
        assert z.testzip() is None and z.namelist() == ['archive/pc/mod/0_open77_tabletop_extra.archive']
        assert z.read(z.namelist()[0]) == packed
    print(f'VERIFIED: 3 native props + {len(COLLIDERS)} collider entity, {n_tex} opaque mipmapped textures, {len(files)} exact RDAR entries, geometry/bindings/emission/package hashes', flush=True)


def check_geometry(geometry):
    """Authored invariants the client relies on, before cooking."""
    wheel = geometry['roulette_wheel']
    # The settled ball sits on a pocket floor, clear of the frets and walls.
    floors = [f for f in wheel if f['color'].startswith('pocket_')]
    assert all(abs(f[k][2] - POCKET_FLOOR) < 1e-9 for f in floors for k in 'abc')
    assert POCKET_IN < POCKET_R - BALL_R and POCKET_R + BALL_R < POCKET_OUT and POCKET_Z - BALL_R > POCKET_FLOOR
    assert POCKET_R * math.sin(math.radians(STEP / 2)) - .0013 > BALL_R
    # Pocket colours follow the European order, pocket 0 centred on +Y.
    for i, n in enumerate(ORDER):
        a = math.radians(i * STEP); x, y = POCKET_R * math.sin(a), POCKET_R * math.cos(a)
        hit = [f for f in floors if all(math.hypot(f[k][0], f[k][1]) > 0 for k in 'abc')]
        best = min(hit, key=lambda f: (sum(f[k][0] for k in 'abc') / 3 - x) ** 2 + (sum(f[k][1] for k in 'abc') / 3 - y) ** 2)
        assert best['color'] == ('pocket_zero' if n == 0 else 'pocket_red' if n in REDS else 'pocket_black'), (i, n)
    # The ball rides the track against the back wall.
    track_z = BOWL[3][1] + (TRACK_R - BOWL[3][0]) / (BOWL[4][0] - BOWL[3][0]) * (BOWL[4][1] - BOWL[3][1])
    assert abs(TRACK_R + BALL_R - BOWL[5][0]) < .002 and TRACK_Z - BALL_R >= track_z - 1e-3
    assert ROTOR_R < BOWL[0][0]


def main():
    p = argparse.ArgumentParser(description=__doc__); p.add_argument('--lab', type=Path, default=LAB); p.add_argument('--work', type=Path, default=Path('/tmp/tabletop-extra-props/build'))
    p.add_argument('--verify-only', action='store_true'); p.add_argument('--preview-only', action='store_true'); a = p.parse_args(); work = a.work
    if a.verify_only:
        verify(work, json.loads((RESOURCE / 'asset-manifest.json').read_text())); return
    geometry = models(); check_geometry(geometry); images = artwork()
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
        (schemas / (name + '.ent.json')).write_text(json.dumps(base.entity_json(template, name, i)))
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
    archive_file = packed / 'archive.archive'; assert archive_file.read_bytes()[:4] == b'RDAR'; output = RESOURCE / 'dist/open77_tabletop_extra.zip'; output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        info = zipfile.ZipInfo('archive/pc/mod/0_open77_tabletop_extra.archive', (2026, 1, 1, 0, 0, 0)); info.compress_type = zipfile.ZIP_DEFLATED; info.external_attr = 0o100644 << 16; z.writestr(info, archive_file.read_bytes())
    files = [{'depot': str(q.relative_to(archive)).replace('/', '\\'), 'sha256': hashlib.sha256(q.read_bytes()).hexdigest(), 'bytes': q.stat().st_size} for q in sorted(archive.rglob('*')) if q.is_file()]
    manifest = {'version': '2.0.0', 'style': 'Night City high-roller: gunmetal, black chrome, smoked glass, carbon, dark composite layout with cyan lines',
                'namespace': DEPOT, 'models': records, 'colliders': colliders, 'textures': textures, 'files': files, 'rouletteOrder': ORDER,
                'roulettePocketRadius': POCKET_R, 'rouletteBallCenterZ': POCKET_Z, 'rouletteBallRadius': BALL_R,
                'rouletteTrackRadius': TRACK_R, 'rouletteTrackCenterZ': TRACK_Z, 'tableFloorZ': FLOOR_Z, 'layout': {'x0': LAYOUT[0], 'x1': LAYOUT[1], 'y0': LAYOUT[2], 'y1': LAYOUT[3], 'z': LAYOUT_Z},
                'emission': {k: {'rgb': s.emit[0], 'ev': s.ev()} for k, s in MATERIALS.items() if s.emit},
                'archiveSha256': hashlib.sha256(archive_file.read_bytes()).hexdigest(), 'zipSha256': hashlib.sha256(output.read_bytes()).hexdigest(), 'buildWork': str(work),
                'materialDependencies': A.depot_dependencies(MATERIALS.values())}
    (RESOURCE / 'asset-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n'); print('COOKED', len(records), 'models,', len(textures), 'textures,', len(files), 'native files, ZIP', output.stat().st_size, 'bytes', flush=True)
    verify(work, manifest)


if __name__ == '__main__': main()
