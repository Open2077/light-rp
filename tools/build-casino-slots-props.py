#!/usr/bin/env python3
"""Cook the original slot machine: cabinet, three reel strips, lever poses, lamp, coin.

Uses the existing native board-prop cooker as a read-only schema/tool library,
tools/wheel_tables_art.py (the roulette / Fortune Wheel kit: stroke typeface,
brushed gunmetal, carbon twill, composite, metal_base materials, profile
sweeps) and tools/wheel_tables_preview.py for the critique renders, so the
machine shares the casino set's material language. Only this resource and
--work receive outputs. Requires Pillow, numpy, lupa (reels and pays come from
the shared rules), .NET and WolvenKit from the lab.

Art direction: a premium Night City stepper cabinet at true proportions
(0.65 m wide, 1.98 m to the top of the candle lamp in game). Satin black
lacquer side panels with rolled black-chrome edges and raised carbon inserts,
a brushed gunmetal plinth over a recessed toe light, a lacquer lower door with
an inset belly glass, a chrome payout bowl under a chute canopy, a slanted
carbon button deck with a padded armrest, distinct keycaps and a domed spin
button, a ticket printer and a player-card reader, a smoked-glass reel door
behind a black-chrome bezel (payline printed on the glass), a framed paytable
display between perforated speaker grilles, a concave attract screen under an
overhanging crown, and a candle lamp. Light is restrained: one thin cyan line
per side panel, the toe light, a magenta downlight under the crown, the spin
ring, the card slot, the payline, the screens and the backlit reels.

Props turn about Z only, so every moving part is a separate prop: the reels are
flat symbol strips that slide vertically behind the bezel window, the lever is
six authored pose meshes and the lamp a lit/unlit pair. Inactive poses park
inside the closed cabinet core, away from the reel bay that the window shows.
"""
import argparse, base64, hashlib, importlib.util, json, math, os, struct, subprocess, sys, zipfile
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from lupa import LuaRuntime
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import wheel_tables_art as A
import mesh_checks
RESOURCE = ROOT / 'resources/assets/models/open77_casino_slots'
DEPOT = 'open77\\assets\\op77_lightrp\\casino_slots'
LAB = ROOT.parent / 'dop-tests'
spec = importlib.util.spec_from_file_location('native_boards', ROOT / 'tools/build-board-game-props.py'); base = importlib.util.module_from_spec(spec); spec.loader.exec_module(base)
base.RESOURCE = RESOURCE; base.DEPOT = DEPOT
spec = importlib.util.spec_from_file_location('collision_props', ROOT / 'tools/collision_props.py'); col = importlib.util.module_from_spec(spec); spec.loader.exec_module(col)

# ------------------------------------------------------------------ layout
# Unscaled cabinet-local metres (the client renders everything at 0.65). The
# front faces -Y, the lever is on the player's right (+X), the origin is the
# floor centre. Mirrored by client/core/casino_slots.lua (L) and checked by
# tools/test-casino-slots-client.py.
STOPS = 12; ENTRIES = STOPS + 3
LAYOUT = {'paylineZ': 1.66, 'pitch': .085, 'stripY': -.365, 'reelX': [-.22, 0, .22], 'reelWidth': .20,
          'leverAngles': [0, 17, 34, 51, 68, 85], 'leverPivot': [.56, -.04, 1.64], 'leverLength': .50,
          'leverPark': [-.30, .34, 0], 'lampPark': [0, .40, -.45],
          'chuteY': -.425, 'chuteZ': 1.06, 'trayY': -.47, 'trayZ': .94, 'coinPark': [0, .2, .4]}
P = LAYOUT['pitch']; PZ = LAYOUT['paylineZ']; SY = LAYOUT['stripY']
X_OUT, X_IN = .50, .44            # side panel outer face, cabinet core half width
FRONT, BACK = -.40, .42           # core front skin, back
BASE_Z, CORE_TOP = .035, 2.85     # toe recess height, core top (the crown sits on it)
WINDOW_X = (-.31, .31); WINDOW_Z = (PZ - 1.3 * P, PZ + 1.3 * P)   # 2.6 visible rows
HOLE_X = (-.325, .325); HOLE_Z = (WINDOW_Z[0] - .015, WINDOW_Z[1] + .015)
BODY_BOX = ((-X_IN, X_IN), (FRONT, BACK), (BASE_Z, CORE_TOP))     # closed core the parked poses hide in
BAY = ((-.34, .34), (FRONT, -.30), (PZ - 1.17, PZ + 1.17))         # dark reel bay behind the window
# Concave attract screen: rows at fixed heights on an arc of radius TOP_R whose
# centre is in front of the skin at TOP_Z0; `f` offsets towards the player.
TOP_R, TOP_Z0 = 1.25, 2.33
SCREEN_Z = (2.37, 2.80); SCREEN_X = .36
LAMP_AT = (0, -.36, 2.962)
DECK_SLOPE = math.atan2(1.348 - 1.302, -.395 - -.62)
SCALE = .65
# Player collision (tools/COLLISION.md): <base>_collider.ent, boxes in cabinet-local
# metres before the 0.65 scale. Core + side panels; the lever (+X), deck, tray and crown lip stay open.
COLLIDERS = {'slot_cabinet': [col.Box.between((-X_OUT, FRONT - .02, 0), (X_OUT, BACK, CORE_TOP))]}

# ------------------------------------------------------------------ materials
S = A.Spec
CYAN, MAGENTA, GOLD, AMBER, RED = (48, 226, 255), (255, 46, 170), (226, 178, 92), (255, 172, 64), (255, 58, 72)
WHITE = (255, 255, 255)
MATERIALS = {
    'lacquer': S(None, (17, 18, 23), .3, 0.),             # satin black lacquer: side panels, door, core
    'black_chrome': S(None, (26, 28, 33), .12, 1.),
    'chrome': S(None, (205, 209, 216), .06, 1.),
    'gunmetal': S('brushed', WHITE, .34, .9),
    'carbon': S('carbon', WHITE, .28, .35),
    'composite': S('composite', WHITE, .62, 0.),
    'cushion': S('composite', (150, 148, 158), .5, 0.),    # padded armrest
    'smoked_glass': S(None, (9, 11, 14), .03, .25),
    'grille': S('slot_grille', WHITE, .45, .7),
    'lining': S(None, (5, 5, 7), .95, 0.),
    'void': S(None, (3, 3, 4), .9, 0.),
    'gold': S(None, GOLD, .2, 1.),
    'keycap': S(None, (30, 32, 38), .38, 0.),
    'spin': S(None, (12, 40, 50), .06, .2),
    'knob': S(None, (96, 10, 34), .14, .55),
    'neon_cyan': S(None, CYAN, .3, 0., (CYAN, 'soft')),
    'neon_magenta': S(None, MAGENTA, .3, 0., (MAGENTA, 'soft')),
    'amber': S(None, AMBER, .3, 0., (AMBER, 'soft')),
    'payline': S(None, RED, .3, 0., (RED, 'lines')),
    'lamp_off': S(None, (44, 16, 28), .1, .2),
    'lamp_on': S(None, (255, 95, 184), .08, 0., ((255, 95, 184), 'lamp')),
    'coin': S(None, (242, 193, 78), .22, 1.),
    'TEX:symbols': S('slot_symbols', WHITE, .6, 0., (WHITE, -.4), 'slot_symbols'),
    'TEX:marquee': S('slot_marquee', WHITE, .08, 0., (WHITE, 1.6), 'slot_marquee'),
    'TEX:paytable': S('slot_paytable', WHITE, .08, 0., (WHITE, 1.0), 'slot_paytable'),
    'TEX:belly': S('slot_belly', WHITE, .1, 0., (WHITE, 'soft'), 'slot_belly'),
    'TEX:deck': S('slot_deck', WHITE, .35, 0., (WHITE, .8), 'slot_deck'),
}
TEXTURE_NAMES = ['brushed', 'carbon', 'composite', 'slot_grille', 'slot_symbols', 'slot_marquee', 'slot_paytable', 'slot_belly', 'slot_deck']
TEXTURED = {k for k in MATERIALS if k.startswith('TEX:')}   # artwork UVs, kept inside [0,1]


def reels():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('LightRpBoardGames={};LightRpItems={}')
    lua.execute((ROOT / 'resources/gamemodes/op77_lightrp/shared/casino_slots.lua').read_text())
    S_ = lua.globals().LightRpCasinoSlots
    assert S_.STOPS == STOPS
    symbols = [S_.SYMBOLS[i + 1] for i in range(len(S_.SYMBOLS))]
    strips = [[S_.REELS[r + 1][i + 1] for i in range(STOPS)] for r in range(3)]
    return symbols, strips


def pays():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('LightRpBoardGames={};LightRpItems={}')
    lua.execute((ROOT / 'resources/gamemodes/op77_lightrp/shared/casino_slots.lua').read_text())
    S_ = lua.globals().LightRpCasinoSlots
    three = {k: S_.THREE[k] for k in S_.THREE.keys()}
    return {'three': three, 'twoCherries': S_.TWO_CHERRIES, 'mixedFruit': S_.MIXED_FRUIT, 'oneCherry': S_.ONE_CHERRY, 'min': S_.MIN_BET, 'max': S_.MAX_BET}


# ------------------------------------------------------------------ geometry kit
# Parts are built in a local frame then placed with a proper rotation (the
# winding, i.e. the engine's front face, survives). Frames:
#   FRONT_R: local (x, up, out)  -> world (x, -out, up)   panels on the front skin
#   SIDE_R:  local (y, z, x)     -> world (x, y, z)       profiles extruded across X
#   XAXIS_R: lathe axis local +Z -> world +X              hubs, axles
FRONT_R = ((1, 0, 0), (0, 0, -1), (0, 1, 0))
SIDE_R = ((0, 0, 1), (1, 0, 0), (0, 1, 0))
XAXIS_R = ((0, 0, 1), (0, 1, 0), (-1, 0, 0))


def rot_x(angle):
    c, s = math.cos(angle), math.sin(angle)
    return ((1, 0, 0), (0, c, -s), (0, s, c))


def place(faces, R=((1, 0, 0), (0, 1, 0), (0, 0, 1)), t=(0, 0, 0)):
    return A.transform(faces, lambda p: [R[i][0] * p[0] + R[i][1] * p[1] + R[i][2] * p[2] + t[i] for i in range(3)])


def on_front(out, faces, y=FRONT):
    out += place(faces, FRONT_R, (0, y, 0))


def ccw(poly):
    area = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
    return list(poly) if area > 0 else list(poly)[::-1]


def rounded(points, radii, seg=5, support=.002):
    """Closed polygon with each corner rounded by its radius (0 keeps it sharp).
    Support points just outside every arc keep the neighbouring flat faces flat
    under the cooker's normal smoothing."""
    out = []; n = len(points)
    for i in range(n):
        p = points[i]; r = radii[i] if isinstance(radii, (list, tuple)) else radii
        if r <= 0:
            out.append(p); continue
        a, b = points[i - 1], points[(i + 1) % n]
        da = (a[0] - p[0], a[1] - p[1]); db = (b[0] - p[0], b[1] - p[1])
        la, lb = math.hypot(*da), math.hypot(*db); da = (da[0] / la, da[1] / la); db = (db[0] / lb, db[1] / lb)
        theta = math.acos(max(-1, min(1, da[0] * db[0] + da[1] * db[1])))
        t = r / math.tan(theta / 2)
        t = min(t, la * .45, lb * .45); r = t * math.tan(theta / 2)
        bis = (da[0] + db[0], da[1] + db[1]); lbis = math.hypot(*bis); bis = (bis[0] / lbis, bis[1] / lbis)
        c = (p[0] + bis[0] * r / math.sin(theta / 2), p[1] + bis[1] * r / math.sin(theta / 2))
        t1 = (p[0] + da[0] * t, p[1] + da[1] * t); t2 = (p[0] + db[0] * t, p[1] + db[1] * t)
        a1, a2 = math.atan2(t1[1] - c[1], t1[0] - c[0]), math.atan2(t2[1] - c[1], t2[0] - c[0])
        d = a2 - a1
        while d > math.pi: d -= math.tau
        while d < -math.pi: d += math.tau
        if la * .45 > t + support: out.append((t1[0] + da[0] * support, t1[1] + da[1] * support))
        for k in range(seg + 1):
            ang = a1 + d * k / seg; out.append((c[0] + r * math.cos(ang), c[1] + r * math.sin(ang)))
        if lb * .45 > t + support: out.append((t2[0] + db[0] * support, t2[1] + db[1] * support))
    return out


def rrect(x0, y0, x1, y1, r, seg=5):
    return rounded([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], r, seg)


def convex(poly):
    s = [(poly[(i + 1) % len(poly)][0] - poly[i][0]) * (poly[(i + 2) % len(poly)][1] - poly[i][1]) -
         (poly[(i + 1) % len(poly)][1] - poly[i][1]) * (poly[(i + 2) % len(poly)][0] - poly[i][0]) for i in range(len(poly))]
    return all(v >= -1e-12 for v in s)


def triangulate(poly):
    """Ear clipping for a CCW polygon; collinear (support) vertices are dropped
    once they are no longer needed instead of failing."""
    ids = list(range(len(poly))); result = []
    def side(a, b, c): return (poly[b][0] - poly[a][0]) * (poly[c][1] - poly[a][1]) - (poly[b][1] - poly[a][1]) * (poly[c][0] - poly[a][0])
    def inside(p, a, b, c):
        return all(((poly[v][0] - poly[u][0]) * (poly[p][1] - poly[u][1]) - (poly[v][1] - poly[u][1]) * (poly[p][0] - poly[u][0])) >= -1e-14 for u, v in ((a, b), (b, c), (c, a)))
    while len(ids) > 3:
        for i, b in enumerate(ids):
            a, c = ids[i - 1], ids[(i + 1) % len(ids)]
            if side(a, b, c) <= 1e-14: continue
            if any(inside(q, a, b, c) for q in ids if q not in (a, b, c) and poly[q] not in (poly[a], poly[b], poly[c])): continue
            result.append((a, b, c)); ids.pop(i); break
        else:
            flat = [i for i, b in enumerate(ids) if abs(side(ids[i - 1], b, ids[(i + 1) % len(ids)])) <= 1e-12]
            if not flat: raise ValueError('cannot triangulate polygon')
            ids.pop(flat[0])
    if abs(side(*ids)) > 1e-14: result.append(tuple(ids))
    return result


def cap(out, poly, z, color, up, uvfun=None):
    """Fill a CCW polygon at height z (fan when convex, ear clipping otherwise)."""
    facing = (0, 0, 1 if up else -1)
    if convex(poly):
        c = (sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly))
        tris = [((c[0], c[1]), poly[k], poly[(k + 1) % len(poly)]) for k in range(len(poly))]
    else:
        tris = [(poly[a], poly[b], poly[c]) for a, b, c in triangulate(poly)]
    for t in tris:
        pts = [[p[0], p[1], z] for p in t]
        A.tri(out, *pts, color, [uvfun(q) for q in pts] if uvfun else None, facing)


def prism(out, poly, w0, w1, color, r=0., side=None, edge=None, top=None, bottom=None, steps=3,
          caps=(True, True), uvfun=None, edge_colors=None):
    """Extrude a CCW polygon (local x,y) along local z from w0 to w1. Both cap
    rims get a quarter-round fillet of radius r (with flat support rings so the
    caps and walls stay flat). top/bottom = cap materials, side = wall, edge =
    fillets; edge_colors(k) may override the wall of polygon edge k."""
    poly = ccw(poly); side = side or color; edge = edge or side; top = top or color; bottom = bottom or color
    s = .0015
    assert w1 - w0 > 2 * (r + s) + 1e-6 if r > 0 else w1 > w0, ('prism thinner than its fillets', w0, w1, r)
    if r > 0:
        arc_top = [(-r + r * math.sin(math.pi / 2 * i / steps), w1 - r + r * math.cos(math.pi / 2 * i / steps)) for i in range(steps + 1)]
        arc_bot = [(-r + r * math.cos(math.pi / 2 * i / steps), w0 + r - r * math.sin(math.pi / 2 * i / steps)) for i in range(steps + 1)]
        profile = [(-r - s, w1)] + arc_top + [(0, w1 - r - s), (0, w0 + r + s)] + arc_bot + [(-r - s, w0)]
        kinds = ['top'] + ['edge'] * steps + ['side', 'side', 'side'] + ['edge'] * steps + ['bottom']
    else:
        profile = [(0, w1), (0, w0)]; kinds = ['side']
    pick = {'top': top, 'bottom': bottom, 'edge': edge, 'side': side}
    def colors(k, j):
        if kinds[j] == 'side' and edge_colors: return edge_colors(k) or side
        return pick[kinds[j]]
    A.sweep(out, poly, A.outline_normals(poly), profile, color, colors=colors, uvfun=uvfun)
    ins = [(p[0] - n[0] * (r + s), p[1] - n[1] * (r + s)) for p, n in zip(poly, A.outline_normals(poly))] if r > 0 else poly
    if caps[1]: cap(out, ins, w1, top, True, uvfun)
    if caps[0]: cap(out, ins, w0, bottom, False, uvfun)
    return out


def ring(out, path, profile, colors, uvfun=None):
    """Sweep a profile around a CCW outline (frames, bezels, rims). profile: [(o,z)]
    with the solid on the right of the walking direction; colors(j) per segment."""
    path = ccw(path)
    A.sweep(out, path, A.outline_normals(path), profile, None, colors=lambda k, j: colors(j), uvfun=uvfun)


def framed(out, x0, z0, x1, z1, r, profile, colors, face=None, face_depth=None, uvfun=None):
    """A frame on the front skin around an opening (x0..x1, z0..z1) with a face
    (display, grille, slot back) recessed at face_depth. Front-skin local units."""
    part = []
    ring(part, rrect(x0, z0, x1, z1, r), profile, colors)
    if face:
        cap(part, ccw(rrect(x0, z0, x1, z1, r)), face_depth, face, True, uvfun)
    on_front(out, part)


def lathe_x(out, profile, color, at, sides=40, colors=None):
    part = []; A.lathe(part, profile, color, sides, colors=colors); out += place(part, XAXIS_R, at)


def lathe_at(out, profile, color, at, sides=40, colors=None, uvfun=None):
    part = []; A.lathe(part, profile, color, sides, colors=colors, uvfun=uvfun); out += A.translate(part, at)


def sphere_profile(rz, rx, cz, n=12):
    return [(rx * math.sin(math.pi * k / n), cz + rz * math.cos(math.pi * k / n)) for k in range(n + 1)]


def arc_yz(z, f=0.):
    """Point of the concave topper at height z, offset f towards the player."""
    a = math.asin((z - TOP_Z0) / (TOP_R - f))
    return FRONT - TOP_R + (TOP_R - f) * math.cos(a)


# ------------------------------------------------------------------ cabinet
def side_panel(out, sign):
    """Satin lacquer side panel with rolled black-chrome edges, its front edge
    following the topper arc, a raised carbon insert and a thin cyan light line."""
    zs = [TOP_Z0 + (CORE_TOP - TOP_Z0) * k / 12 for k in range(13)]
    front_arc = [(arc_yz(z, .02), z) for z in zs]
    pts = [(BACK, BASE_Z + .005), (BACK, CORE_TOP)] + front_arc[::-1] + [(-.42, .30), (-.432, BASE_Z + .005)]
    radii = [.0, .05] + [0] * len(front_arc) + [0, .02]
    prof = rounded(pts, radii)
    part = []
    prism(part, prof, X_IN, X_OUT, 'lacquer', r=.012, side='black_chrome', edge='black_chrome',
          top='lacquer' if sign > 0 else 'lacquer', bottom='lacquer')
    # Raised carbon insert on the outer face.
    insert = []
    prism(insert, rrect(-.33, .26, .34, 2.62, .04), X_OUT - .006, X_OUT + .005, 'gunmetal', r=.003, side='black_chrome', edge='black_chrome', caps=(False, True))
    part += insert
    # Cyan light line standing proud of the front edge, deck to topper.
    A.box(part, (-.4205, 1.84, (X_IN + X_OUT) / 2), (.009, .92, .006), 'neon_cyan')
    part = place(part, SIDE_R)
    if sign < 0:   # mirror across X, then restore the winding
        part = [{**f, 'a': [-f['a'][0], *f['a'][1:]], 'b': [-f['c'][0], *f['c'][1:]], 'c': [-f['b'][0], *f['b'][1:]]} for f in part]
    out += part


def core(out):
    """Closed core box (the parked poses hide in it) with only the reel hole in front."""
    (x0, x1), (y0, y1), (z0, z1) = BODY_BOX
    q = lambda pts, n, c='lacquer': A.quad(out, pts, c, n)
    q([[x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1]], (0, 1, 0))
    q([[x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1]], (0, 0, 1))
    q([[x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0]], (0, 0, -1))
    hx0, hx1 = HOLE_X; hz0, hz1 = HOLE_Z
    for a, b, c, d in ((x0, x1, z0, hz0), (x0, x1, hz1, z1), (x0, hx0, hz0, hz1), (hx1, x1, hz0, hz1)):
        q([[a, y0, c], [b, y0, c], [b, y0, d], [a, y0, d]], (0, -1, 0))
    # Reel bay: a dark cavity behind the hole.
    (bx0, bx1), (by0, by1), (bz0, bz1) = BAY
    tmp = []; A.box(tmp, ((bx0 + bx1) / 2, (by0 + by1) / 2, (bz0 + bz1) / 2), (bx1 - bx0, by1 - by0, bz1 - bz0), 'lining')
    for f in tmp:
        cy = (f['a'][1] + f['b'][1] + f['c'][1]) / 3
        if abs(cy - by0) < 1e-9: continue           # open towards the window
        out.append({'a': f['a'], 'b': f['c'], 'c': f['b'], 'color': 'lining'})


def plinth(out):
    # Dark toe recess, then the brushed kick plate.
    A.box(out, (0, (-.38 + .40) / 2, (BASE_Z + .01) / 2), (2 * .47, .78, BASE_Z + .01), 'lining', bottom=False)
    kick = []
    prism(kick, rrect(-X_IN - .004, BASE_Z - .004, X_IN + .004, .20, .01), -.004, .03, 'gunmetal', r=.006, edge='black_chrome', side='gunmetal', caps=(False, True))
    on_front(out, kick)


def lower_door(out):
    door = []
    prism(door, rrect(-.425, .225, .425, .875, .012), -.004, .03, 'lacquer', r=.008, edge='black_chrome', caps=(False, True))
    # Belly glass in a chamfered gunmetal frame.
    ring(door, rrect(-.30, .40, .30, .79, .012),
         [(0, .036), (0, .044), (.004, .049), (.022, .049), (.026, .044), (.026, .026)],
         lambda j: 'chrome' if j == 1 else 'gunmetal')
    cap(door, ccw(rrect(-.30, .40, .30, .79, .012)), .036, 'TEX:belly', True,
        lambda p: [(p[0] + .30) / .60, (.79 - p[1]) / .39])
    # Door lock.
    lock = []
    A.lathe(lock, [(0, .046), (.009, .046), (.012, .043), (.013, .036), (.013, .026)], 'chrome', 24)
    door += A.translate(lock, (.36, .835, 0))
    on_front(out, door)


def tray_and_chute(out):
    # Payout bowl: chrome rim around a brushed floor, standing on the skin.
    plan = rounded([(-.21, -.545), (.21, -.545), (.21, -.395), (-.21, -.395)], [.05, .05, 0, 0])
    prof = [(-.012, .935), (-.012, .958), (-.009, .964), (-.003, .964), (0, .958), (0, .905), (-.005, .899), (-.02, .899)]
    ring(out, plan, prof, lambda j: 'chrome' if j < 5 else 'black_chrome')
    inner = [(p[0] - n[0] * .012, p[1] - n[1] * .012) for p, n in zip(ccw(plan), A.outline_normals(ccw(plan)))]
    cap(out, inner, .935, 'gunmetal', True)
    lower = [(p[0] - n[0] * .02, p[1] - n[1] * .02) for p, n in zip(ccw(plan), A.outline_normals(ccw(plan)))]
    cap(out, lower, .899, 'black_chrome', False)
    # Chute canopy: a chrome hood with two cheeks over a dark mouth.
    hood = []
    prism(hood, rrect(-.135, 1.10, .135, 1.13, .008), -.004, .07, 'chrome', r=.006)
    for x0, x1 in ((-.135, -.118), (.118, .135)):
        prism(hood, [(x0, 1.02), (x1, 1.02), (x1, 1.104), (x0, 1.104)], -.004, .066, 'chrome', r=.003)
    A.quad(hood, [[-.118, 1.02, .006], [.118, 1.02, .006], [.118, 1.10, .006], [-.118, 1.10, .006]], 'void', (0, 0, 1))
    on_front(out, hood)


def deck_profile():
    return rounded([(-.395, 1.17), (-.615, 1.17), (-.652, 1.24), (-.62, 1.302), (-.395, 1.348)], [0, .03, .035, .03, 0], seg=6)


def deck_point(t):
    return (-.62 + (-.395 - -.62) * t, 1.302 + (1.348 - 1.302) * t)


def deck(out):
    prof = deck_profile()
    pts = ccw(prof)
    def edge_color(k):
        (y0, z0), (y1, z1) = pts[k], pts[(k + 1) % len(pts)]
        ym, zm = (y0 + y1) / 2, (z0 + z1) / 2
        if zm < 1.175: return 'black_chrome'
        if ym < -.598: return 'cushion'
        if ym > -.3951 and ym < -.394: return 'lacquer'
        return 'carbon'
    part = []
    prism(part, pts, -.476, .476, 'lacquer', r=.02, side='carbon', edge='black_chrome', edge_colors=edge_color)
    out += place(part, SIDE_R)
    # Keycaps and the spin button on the slanted top.
    def on_deck(parts, x, t, lift=0.):
        y, z = deck_point(t)
        out.extend(place(parts, rot_x(DECK_SLOPE), (x, y, z + lift)))
    for x, cell in ((-.355, 0), (-.215, 1), (-.095, 2), (.045, 3)):
        w, h = .105, .052
        u0, u1, v0, v1 = cell * .25 + .01, cell * .25 + .24, .02, .23
        key = []
        prism(key, rrect(-w / 2 - .007, -h / 2 - .007, w / 2 + .007, h / 2 + .007, .009), -.004, .004, 'black_chrome', r=.002, caps=(False, True))
        uv = lambda p, w=w, h=h, u0=u0, u1=u1, v0=v0, v1=v1: [u0 + (p[0] + w / 2) / w * (u1 - u0), v1 - (p[1] + h / 2) / h * (v1 - v0)]
        prism(key, rrect(-w / 2, -h / 2, w / 2, h / 2, .007), .002, .017, 'keycap', r=.003, top='TEX:deck', caps=(False, True), uvfun=uv)
        on_deck(key, x, .5)
    spin = []
    A.lathe(spin, [(.050, .002), (.050, .010), (.056, .0125), (.064, .011), (.068, .006), (.068, -.004)], 'chrome', 48)
    A.lathe(spin, [(.044, .0055), (.050, .0055)], 'neon_cyan', 48)
    cu, cv, cr = .875, .75, .115
    A.lathe(spin, [(0, .027), (.026, .027)], 'TEX:deck', 48, uvfun=lambda p: [cu + p[0] / .026 * cr, cv - p[1] / .026 * cr * 2])
    A.lathe(spin, [(.026, .027), (.033, .0255), (.039, .022), (.042, .016), (.042, .002)], 'spin', 48)
    on_deck(spin, .30, .5)


def band(out):
    """Ticket printer (left) and player-card reader with its display (right)."""
    part = []
    prism(part, rrect(-.43, 1.358, .43, 1.47, .01), -.004, .02, 'gunmetal', r=.005, edge='black_chrome', caps=(False, True))
    slot_prof = [(0, .026), (0, .036), (.004, .040), (.014, .040), (.018, .036), (.018, .017)]
    ring(part, rrect(-.33, 1.40, -.17, 1.418, .004), slot_prof, lambda j: 'black_chrome' if j != 1 else 'chrome')
    cap(part, ccw(rrect(-.33, 1.40, -.17, 1.418, .004)), .026, 'void', True)
    # Card reader: amber-lit slot and a smoked display.
    ring(part, rrect(.18, 1.382, .32, 1.392, .003), slot_prof, lambda j: 'black_chrome' if j != 1 else 'chrome')
    cap(part, ccw(rrect(.18, 1.382, .32, 1.392, .003)), .026, 'amber', True)
    ring(part, rrect(.17, 1.415, .33, 1.452, .004), [(0, .026), (0, .032), (.004, .035), (.010, .035), (.012, .032), (.012, .017)],
         lambda j: 'black_chrome')
    cap(part, ccw(rrect(.17, 1.415, .33, 1.452, .004)), .026, 'TEX:deck', True,
        lambda p: [.01 + (p[0] - .17) / .16 * .48, .49 - (p[1] - 1.415) / .037 * .22])
    on_front(out, part)


def reel_door(out):
    wx0, wx1 = WINDOW_X; wz0, wz1 = WINDOW_Z
    part = []
    # Smoked glass door around the bezel (its opening hides under the bezel).
    outer = rrect(-.43, 1.482, .43, 1.842, .014); hole = rrect(wx0 - .036, wz0 - .036, wx1 + .036, wz1 + .036, .026)
    prism_ring(part, outer, hole, -.004, .014, 'smoked_glass', 'black_chrome')
    # Black-chrome bezel: chrome lip, inner wall running back into the bay.
    prof = [(0, -.02), (0, .030), (.004, .038), (.010, .042), (.050, .042), (.058, .038), (.062, .030), (.062, .010)]
    ring(part, rrect(wx0, wz0, wx1, wz1, .016), prof, lambda j: 'lining' if j == 0 else 'chrome' if j == 1 else 'black_chrome')
    # Gold pinstripe on the bezel face.
    ring(part, rrect(wx0 - .036, wz0 - .036, wx1 + .036, wz1 + .036, .03), [(-.0015, .040), (-.0015, .0465), (.0015, .0465), (.0015, .040)],
         lambda j: 'gold')
    # Payline chevrons on the bezel face, payline printed on the glass.
    for s in (-1, 1):
        x = s * (wx1 + .021)
        A.tri(part, [x + s * .009, PZ - .010, .0455], [x - s * .009, PZ, .0455], [x + s * .009, PZ + .010, .0455], 'payline', facing=(0, 0, 1))
    A.box(part, (0, PZ, .0285), (wx1 - wx0 + .002, .005, .003), 'payline', bottom=False)
    on_front(out, part)
    # Reel mullions behind the glass, covering the gaps between the strips.
    for x in (-.11, .11):
        A.box(out, (x, -.382, PZ), (.022, .02, wz1 - wz0 + .04), 'black_chrome', top=False, bottom=False)


def prism_ring(out, outer, hole, d0, d1, face, rim):
    """A slab with an opening: front face between two outlines with matching
    corner structure, chamfered outer rim, inner wall."""
    outer, hole = ccw(outer), ccw(hole)
    assert len(outer) == len(hole)
    face_outline = [(p[0] - n[0] * .003, p[1] - n[1] * .003) for p, n in zip(outer, A.outline_normals(outer))]
    for k in range(len(outer)):
        a, b = face_outline[k], face_outline[(k + 1) % len(outer)]; c, d = hole[(k + 1) % len(hole)], hole[k]
        A.quad(out, [[a[0], a[1], d1], [b[0], b[1], d1], [c[0], c[1], d1], [d[0], d[1], d1]], face, (0, 0, 1))
    A.sweep(out, outer, A.outline_normals(outer), [(-.003, d1), (0, d1 - .003), (0, d0)], rim)
    A.sweep(out, hole, A.outline_normals(hole), [(0, d0), (0, d1)], rim)


def paytable_and_grilles(out):
    part = []
    x0, x1, z0, z1 = -.30, .30, 1.925, 2.255
    prof = [(0, .008), (0, .028), (.005, .034), (.022, .034), (.028, .028), (.028, -.004)]
    ring(part, rrect(x0, z0, x1, z1, .01), prof, lambda j: 'chrome' if j == 1 else 'gunmetal')
    cap(part, ccw(rrect(x0, z0, x1, z1, .01)), .008, 'TEX:paytable', True, lambda p: [(p[0] - x0) / (x1 - x0), (z1 - p[1]) / (z1 - z0)])
    for s in (-1, 1):
        g0, g1 = sorted((s * .356, s * .424))
        ring(part, rrect(g0, z0, g1, z1, .008), [(0, .005), (0, .016), (.004, .019), (.008, .016), (.008, -.004)], lambda j: 'black_chrome')
        cap(part, ccw(rrect(g0, z0, g1, z1, .008)), .005, 'grille', True)
    # Gold hairline between the reel door and the paytable.
    A.box(part, (0, 1.871, .006), (.86, .004, .006), 'gold', bottom=False)
    on_front(out, part)


def topper(out):
    """Concave attract screen recessed 12 mm in a black-chrome surround, from the skin to the crown."""
    zs = sorted(set([TOP_Z0 + (CORE_TOP - TOP_Z0) * k / 20 for k in range(21)] + list(SCREEN_Z)))
    F = .012
    def pt(x, z, f): return [x, arc_yz(z, f), z]
    zs0, zs1 = SCREEN_Z
    for z0, z1 in zip(zs, zs[1:]):
        inside = zs0 - 1e-9 <= z0 and z1 <= zs1 + 1e-9
        bands = [(-X_IN - .003, -SCREEN_X, F, 'black_chrome'), (SCREEN_X, X_IN + .003, F, 'black_chrome')]
        bands.append((-SCREEN_X, SCREEN_X, 0 if inside else F, 'TEX:marquee' if inside else 'black_chrome'))
        for xa, xb, f, c in bands:
            pts = [pt(xa, z0, f), pt(xb, z0, f), pt(xb, z1, f), pt(xa, z1, f)]
            ny = -1; nz = (pts[2][1] - pts[1][1]) / (z1 - z0)
            uv = None
            if c == 'TEX:marquee':
                u = lambda x: (x + SCREEN_X) / (2 * SCREEN_X); v = lambda z: (zs1 - z) / (zs1 - zs0)
                uv = [[u(xa), v(z0)], [u(xb), v(z0)], [u(xb), v(z1)], [u(xa), v(z1)]]
            A.quad(out, pts, c, (0, ny, nz), uv)
        if inside:   # step walls at the screen sides
            for x, nx in ((-SCREEN_X, 1), (SCREEN_X, -1)):
                A.quad(out, [pt(x, z0, 0), pt(x, z0, F), pt(x, z1, F), pt(x, z1, 0)], 'black_chrome', (nx, 0, 0))
    for z, nz in ((zs0, 1), (zs1, -1)):   # step walls at the screen top and bottom
        A.quad(out, [pt(-SCREEN_X, z, 0), pt(SCREEN_X, z, 0), pt(SCREEN_X, z, F), pt(-SCREEN_X, z, F)], 'black_chrome', (0, 0, nz))
    A.quad(out, [pt(-X_IN - .003, TOP_Z0, 0), pt(X_IN + .003, TOP_Z0, 0), pt(X_IN + .003, TOP_Z0, F), pt(-X_IN - .003, TOP_Z0, F)], 'black_chrome', (0, 0, -1))


def crown(out):
    """Overhanging crown with a magenta downlight under its lip; candle lamp on top."""
    prof = rounded([(-.548, CORE_TOP - .005), (.43, CORE_TOP - .005), (.43, 2.945), (-.50, 2.975), (-.556, 2.925)], [.022, 0, .03, .07, .03], seg=6)
    part = []
    pts = ccw(prof)
    def edge_color(k):
        (y0, z0), (y1, z1) = pts[k], pts[(k + 1) % len(pts)]
        return 'gunmetal' if (y0 + y1) / 2 < -.535 and (z0 + z1) / 2 > CORE_TOP + .01 else None
    prism(part, pts, -.51, .51, 'black_chrome', r=.015, side='black_chrome', edge='black_chrome', top='lacquer', bottom='lacquer', edge_colors=edge_color)
    out += place(part, SIDE_R)
    A.box(out, (0, -.534, CORE_TOP - .005), (.80, .010, .010), 'neon_magenta')


def lever_hub(out):
    px, py, pz = LAYOUT['leverPivot']
    x0 = X_OUT + .004
    lathe_x(out, [(0, .016), (.084, .016), (.093, .012), (.098, .005), (.098, -.002)], 'gunmetal', (x0, py, pz), 48)
    lathe_x(out, [(0, .036), (.038, .036), (.044, .031), (.046, .022), (.046, .012)], 'black_chrome', (x0, py, pz), 40)
    for k in range(6):
        a = math.radians(30 + 60 * k)
        lathe_x(out, [(0, .023), (.005, .022), (.0075, .019), (.0075, .012)], 'chrome', (x0, py + .07 * math.cos(a), pz + .07 * math.sin(a)), 16)
    # Pull travel arc: a thin gold quadrant in front of the hub.
    lathe_x(out, [(.0865, .014), (.0865, .0185), (.0905, .0185), (.0905, .014)], 'gold', (x0, py, pz), 48)


def cabinet():
    out = []
    core(out); side_panel(out, 1); side_panel(out, -1); plinth(out); lower_door(out); tray_and_chute(out)
    deck(out); band(out); reel_door(out); paytable_and_grilles(out); topper(out); crown(out); lever_hub(out)
    return out


def symbol_strip(strip, symbols):
    out = []; w = LAYOUT['reelWidth']; entries = [strip[-1]] + strip + strip[:2]; assert len(entries) == ENTRIES
    for i, name in enumerate(entries):
        k = symbols.index(name); col_, row = k % 2, k // 2; u0, u1 = col_ * .5 + .002, col_ * .5 + .498; v0, v1 = row * .25 + .002, row * .25 + .248
        z = -i * P
        A.quad(out, [[-w / 2, 0, z - P / 2], [w / 2, 0, z - P / 2], [w / 2, 0, z + P / 2], [-w / 2, 0, z + P / 2]], 'TEX:symbols', (0, -1, 0),
               [[u0, v1], [u1, v1], [u1, v0], [u0, v0]])
    return out


def lever(angle):
    """Chrome lever on its axle sleeve: a turned tapering rod, a gold ferrule and
    a weighted garnet knob, turned `angle` degrees towards the player."""
    L = LAYOUT['leverLength']; arm = []
    sleeve = []
    A.lathe(sleeve, [(0, .046), (.024, .046), (.030, .043), (.033, .037), (.033, .006), (.030, 0)], 'chrome', 40)
    arm += place(sleeve, XAXIS_R, (-.021, 0, 0))
    A.lathe(arm, [(0, L - .03), (.0155, L - .03), (.0155, L - .075), (.0185, L - .085), (.0185, L - .10), (.0160, L - .11),
                  (.0195, .12), (.0235, .10), (.0235, .075), (.0275, .065), (.0275, .03), (.024, .022)], 'chrome', 32)
    A.lathe(arm, sphere_profile(.06, .055, L + .008, 14), 'knob', 40)
    A.lathe(arm, [(.0185, L - .083), (.022, L - .086), (.022, L - .099), (.0185, L - .102)], 'gold', 32)
    a = math.radians(angle); px, py, pz = LAYOUT['leverPivot']
    return place(arm, rot_x(a), (px, py, pz))


def lamp(color):
    """Candle lamp: chrome base, barrel lens, black band, chrome cap."""
    out = []
    A.lathe(out, [(.043, .045), (.050, .040), (.056, .030), (.058, .014), (.058, -.006)], 'chrome', 40)
    A.lathe(out, [(.046, .150), (.043, .148), (.046, .12), (.047, .095), (.046, .07), (.043, .047), (.043, .045)], color, 40)
    A.lathe(out, [(.042, .168), (.046, .165), (.046, .150)], 'black_chrome', 40)
    A.lathe(out, [(0, .186), (.02, .184), (.034, .178), (.042, .168)], 'chrome', 40)
    return A.translate(out, LAMP_AT)


def coin():
    out = []
    A.lathe(out, [(0, .0028), (.019, .0028), (.020, .004), (.025, .004), (.027, .0025), (.027, -.0025), (.025, -.004), (0, -.004)], 'coin', 32)
    return out


def models(symbols, strips):
    m = {'slot_cabinet': cabinet()}
    for r in range(3): m[f'slot_strip_{r + 1}'] = symbol_strip(strips[r], symbols)
    for i, a in enumerate(LAYOUT['leverAngles']): m[f'slot_lever_{i}'] = lever(a)
    m['slot_lamp_off'] = lamp('lamp_off'); m['slot_lamp_on'] = lamp('lamp_on'); m['slot_coin'] = coin()
    return m

# ------------------------------------------------------------------ artwork
# Reel symbols are printed enamel on a warm pearl band (a real stepper's reel
# strip): solid shapes with a dark keyline, a soft gradient, a gloss highlight
# and a faint drop shadow. Screens are dark, set in the wheel kit's stroke face.
PEARL = (232, 228, 219)
INK = (24, 22, 30)


def grad(size, top, bottom, horizontal=False):
    w, h = size
    t = np.linspace(0, 1, w if horizontal else h)
    rows = np.array(top, float)[None] * (1 - t[:, None]) + np.array(bottom, float)[None] * t[:, None]
    arr = np.repeat(rows[None], h, 0) if horizontal else np.repeat(rows[:, None], w, 1)
    return Image.fromarray(np.concatenate([arr, np.full(arr.shape[:2] + (1,), 255.)], 2).astype(np.uint8), 'RGBA')


def radial(size, inner, outer, center, radius):
    w, h = size; yy, xx = np.mgrid[0:h, 0:w]
    t = np.clip(np.hypot(xx - center[0], yy - center[1]) / radius, 0, 1)[..., None]
    arr = np.array(inner, float) * (1 - t) + np.array(outer, float) * t
    return Image.fromarray(np.concatenate([arr, np.full((h, w, 1), 255.)], 2).astype(np.uint8), 'RGBA')


def mask_of(size, draw, ss=4):
    m = Image.new('L', (size[0] * ss, size[1] * ss), 0); draw(ImageDraw.Draw(m), ss)
    return m.resize(size, Image.Resampling.LANCZOS)


def poly_mask(size, pts): return mask_of(size, lambda d, s: d.polygon([(x * s, y * s) for x, y in pts], fill=255))
def ellipse_mask(size, box): return mask_of(size, lambda d, s: d.ellipse([v * s for v in box], fill=255))


def paint(im, mask, src):
    if not isinstance(src, Image.Image): src = Image.new('RGBA', im.size, tuple(src[:3]) + (255,))
    layer = src.copy(); layer.putalpha(mask); im.alpha_composite(layer)


def grow(mask, px):
    if px <= 0: return mask
    return mask.filter(ImageFilter.GaussianBlur(px * .55)).point(lambda v: 0 if v < 8 else min(255, int((v - 8) * 6)))


def m_union(*ms):
    a = np.zeros(np.asarray(ms[0]).shape, np.uint8)
    for m in ms: a = np.maximum(a, np.asarray(m))
    return Image.fromarray(a)


def m_sub(a, b): return Image.fromarray(np.clip(np.asarray(a, int) - np.asarray(b, int), 0, 255).astype(np.uint8))


def enamel(im, mask, fill, k, line=5, shadow=True, gloss=None):
    """Keyline, fill and an optional gloss mask, with a soft drop shadow."""
    if shadow:
        sh = grow(mask, line * k).filter(ImageFilter.GaussianBlur(5 * k)).point(lambda v: int(v * .35))
        sh = sh.transform(sh.size, Image.Transform.AFFINE, (1, 0, -3 * k, 0, 1, -5 * k))
        paint(im, sh, (40, 30, 40))
    paint(im, grow(mask, line * k), INK)
    paint(im, mask, fill)
    if gloss is not None: paint(im, gloss, (255, 255, 255, 200))


def draw_symbol(cell, name, line=5):
    """Original symbols (any size; designed on a 600x256 canvas)."""
    W, H = cell.size; k = H / 256; cx, cy = W / 2, H / 2
    def P(x, y): return (cx + x * k, cy + y * k)
    def E(x, y, rx, ry): return (cx + (x - rx) * k, cy + (y - ry) * k, cx + (x + rx) * k, cy + (y + ry) * k)
    sz = cell.size
    if name == 'seven':
        outer = [P(-60, -84), P(66, -84), P(66, -62), P(-2, 90), P(-42, 90), P(22, -54), P(-60, -54)]
        m = poly_mask(sz, outer)
        enamel(cell, m, grad(sz, (236, 40, 58), (138, 6, 28)), k, line)
        inner = poly_mask(sz, [P(-50, -76), P(57, -76), P(57, -64), P(2, 80), P(-30, 80), P(28, -62), P(-50, -62)])
        paint(cell, m_sub(m, grow(inner, 1)), (232, 186, 96))           # gold inline
        paint(cell, poly_mask(sz, [P(-52, -79), P(58, -79), P(56, -74), P(-50, -74)]), (255, 236, 214))
    elif name == 'diamond':
        top, mid, bot, wd = -66, -26, 86, 92
        whole = poly_mask(sz, [P(-wd, mid), P(-52, top), P(52, top), P(wd, mid), P(0, bot)])
        enamel(cell, whole, (60, 170, 220), k, line)
        for pts, c in (([P(-wd, mid), P(-52, top), P(-16, mid)], (150, 226, 250)), ([P(-52, top), P(0, top), P(-16, mid)], (214, 246, 255)),
                       ([P(0, top), P(52, top), P(16, mid)], (120, 206, 244)), ([P(52, top), P(wd, mid), P(16, mid)], (60, 160, 220)),
                       ([P(-16, mid), P(0, top), P(16, mid)], (246, 252, 255)), ([P(-wd, mid), P(-16, mid), P(0, bot)], (40, 140, 206)),
                       ([P(-16, mid), P(16, mid), P(0, bot)], (90, 186, 236)), ([P(16, mid), P(wd, mid), P(0, bot)], (18, 96, 170))):
            paint(cell, poly_mask(sz, pts), c)
        d = ImageDraw.Draw(cell, 'RGBA')
        for a, b in ((P(-wd, mid), P(wd, mid)), (P(-52, top), P(-16, mid)), (P(52, top), P(16, mid)), (P(-16, mid), P(0, bot)), (P(16, mid), P(0, bot))):
            d.line((a, b), fill=(16, 40, 70, 160), width=max(1, int(2 * k)))
    elif name == 'chip':
        r = 82; m = ellipse_mask(sz, E(0, 0, r, r))
        enamel(cell, m, grad(sz, (176, 20, 108), (112, 8, 70)), k, line)
        for i in range(8):
            a = math.radians(i * 45 + 22.5)
            pts = [P(r * math.cos(a + da) * f, r * math.sin(a + da) * f) for da, f in ((-.16, .99), (.16, .99), (.16, .74), (-.16, .74))]
            paint(cell, poly_mask(sz, pts), (246, 238, 244))
        paint(cell, ellipse_mask(sz, E(0, 0, 56, 56)), INK)
        paint(cell, ellipse_mask(sz, E(0, 0, 52, 52)), grad(sz, (40, 36, 52), (16, 14, 22)))
        A.draw_text(cell, '77', P(0, 0), int(46 * k), (236, 200, 120), stroke=.15, tracking=1.0)
    elif name == 'bar':
        m = mask_of(sz, lambda d, s: d.rounded_rectangle([v * s for v in E(0, 0, 116, 46)], radius=int(12 * k * s), fill=255))
        enamel(cell, m, grad(sz, (44, 44, 54), (14, 14, 18)), k, line)
        inner = mask_of(sz, lambda d, s: d.rounded_rectangle([v * s for v in E(0, 0, 106, 36)], radius=int(8 * k * s), outline=255, width=max(1, int(3 * k * s))))
        paint(cell, inner, (226, 178, 92))
        A.draw_text(cell, 'BAR', P(2, 0), int(50 * k), (246, 240, 228), stroke=.17, tracking=1.3)
    elif name == 'bell':
        outline = [P(-80, 58), P(-64, 42), P(-56, -16), P(-34, -58), P(0, -72), P(34, -58), P(56, -16), P(64, 42), P(80, 58)]
        clap = ellipse_mask(sz, E(0, 74, 16, 16)); knob = ellipse_mask(sz, E(0, -78, 10, 10))
        m = m_union(poly_mask(sz, outline), poly_mask(sz, [P(-86, 56), P(86, 56), P(86, 70), P(-86, 70)]), clap, knob)
        enamel(cell, m, grad(sz, (250, 214, 120), (178, 110, 18), horizontal=True), k, line)
        paint(cell, poly_mask(sz, [P(-86, 56), P(86, 56), P(86, 70), P(-86, 70)]), (160, 96, 14))
        paint(cell, poly_mask(sz, [P(-34, -54), P(-12, -64), P(-30, 36), P(-48, 36)]), (255, 240, 196))
    elif name == 'grape':
        hexes = []
        for n, y in ((4, -44), (3, -6), (2, 32), (1, 70)):
            for i in range(n): hexes.append((-(n - 1) * 22 + i * 44, y))
        circles = [ellipse_mask(sz, E(x, y, 21, 21)) for x, y in hexes]
        leaf = poly_mask(sz, [P(6, -68), P(70, -96), P(42, -60)])
        stem = mask_of(sz, lambda d, s: d.line([v * s for v in (*P(0, -62), *P(10, -88))], fill=255, width=int(7 * k * s)))
        enamel(cell, m_union(*circles, leaf, stem), (90, 30, 150), k, line)
        for (x, y), cm in zip(hexes, circles):
            paint(cell, cm, radial(sz, (200, 140, 250), (84, 24, 150), P(x - 7, y - 8), 26 * k))
            paint(cell, ellipse_mask(sz, E(x - 7, y - 8, 5, 4)), (246, 230, 255))
        paint(cell, leaf, grad(sz, (90, 200, 120), (30, 120, 70))); paint(cell, stem, (40, 120, 70))
    elif name == 'lemon':
        pts = [P(-98, 0), P(-76, -30), P(-38, -52), P(16, -56), P(60, -40), P(86, -12), P(100, 0), P(86, 14), P(58, 40), P(16, 56), P(-38, 52), P(-76, 30)]
        m = poly_mask(sz, pts)
        enamel(cell, m, grad(sz, (255, 236, 96), (220, 160, 0)), k, line)
        paint(cell, poly_mask(sz, [P(-80, -6), P(-60, -30), P(-30, -44), P(-30, -30), P(-58, -12)]), (255, 250, 200))
    elif name == 'cherry':
        stems = mask_of(sz, lambda d, s: (d.line([v * s for v in (*P(-48, 24), *P(-8, -56), *P(30, -82))], fill=255, width=int(7 * k * s), joint='curve'),
                                         d.line([v * s for v in (*P(50, 28), *P(18, -52), *P(30, -82))], fill=255, width=int(7 * k * s), joint='curve')))
        leaf = poly_mask(sz, [P(30, -82), P(86, -98), P(66, -68)])
        balls = [ellipse_mask(sz, E(x, y, 42, 42)) for x, y in ((-48, 42), (50, 46))]
        enamel(cell, m_union(stems, leaf, *balls), (180, 0, 30), k, line)
        paint(cell, stems, (50, 130, 70)); paint(cell, leaf, grad(sz, (90, 200, 120), (30, 120, 70)))
        for (x, y), bm in zip(((-48, 42), (50, 46)), balls):
            paint(cell, bm, radial(sz, (255, 110, 120), (150, 0, 24), P(x - 14, y - 16), 50 * k))
            paint(cell, ellipse_mask(sz, E(x - 16, y - 18, 8, 6)), (255, 228, 232))
    else:
        raise ValueError(name)


def symbol_cell(name, size=(512, 256), background=True):
    """One reel entry, drawn on its true 2.35:1 shape then fitted to the atlas cell."""
    W, H = 600, 256
    if background:
        cell = Image.new('RGBA', (W, H), PEARL + (255,))
    else:
        cell = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    draw_symbol(cell, name)
    return cell.resize(size, Image.Resampling.LANCZOS)


def hairframe(d, box, color, width=2, inset=0):
    x0, y0, x1, y1 = box
    d.rectangle((x0 + inset, y0 + inset, x1 - inset, y1 - inset), outline=color, width=width)


def screen_bg(size, top=(12, 14, 24), bottom=(3, 4, 8), seed=3):
    im = grad(size, top, bottom)
    rng = np.random.default_rng(seed)
    a = np.asarray(im).astype(float); a[..., :3] *= 1 + rng.normal(0, .015, a.shape[:2] + (1,))
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), 'RGBA')


def mini_cell(name, w, dim=.66):
    """A small pearl reel window with one symbol (paytable, attract screen),
    dimmed so the lit screen does not wash it out."""
    h = int(w / 2.35); cell = symbol_cell(name, (w, h))
    a = np.asarray(cell).astype(float); a[..., :3] *= dim; cell = Image.fromarray(a.astype(np.uint8), 'RGBA')
    m = mask_of((w, h), lambda d, s: d.rounded_rectangle((0, 0, w * s - 1, h * s - 1), radius=int(h * .14 * s), fill=255))
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0)); paint(out, m, cell); return out


def marquee():
    """Attract screen on the concave topper: 0.72 x ~0.44 m (drawn at that ratio, fitted to 1024x1024)."""
    W, H = 1640, 1000
    im = screen_bg((W, H), (16, 14, 32), (4, 4, 10))
    d = ImageDraw.Draw(im, 'RGBA')
    # A dial of fine ticks: the reel's rim seen face-on, cyan to magenta.
    cx, cy, R = W / 2, 470, 420
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0)); ld = ImageDraw.Draw(layer, 'RGBA')
    for i in range(180):
        a = math.radians(i * 2); t = (math.cos(a - math.radians(60)) + 1) / 2
        c = tuple(int(CYAN[j] * t + MAGENTA[j] * (1 - t)) for j in range(3))
        r0 = R - (26 if i % 15 == 0 else 12)
        ld.line((cx + r0 * math.cos(a), cy + r0 * math.sin(a), cx + R * math.cos(a), cy + R * math.sin(a)), fill=c + (150 if i % 15 else 230,), width=3 if i % 15 else 5)
    ld.ellipse((cx - R - 10, cy - R - 10, cx + R + 10, cy + R + 10), outline=(226, 178, 92, 120), width=2)
    soft = layer.filter(ImageFilter.GaussianBlur(6)); im.alpha_composite(soft); im.alpha_composite(layer)
    # Skyline in thin linework at the bottom, fading up.
    rng = np.random.default_rng(77); x = 0; base_y = H - 80
    while x < W:
        w = int(rng.integers(40, 110)); h = int(rng.integers(40, 190))
        d.rectangle((x, base_y - h, x + w, base_y), outline=(80, 70, 140, 90), width=2)
        for wy in range(base_y - h + 14, base_y - 8, 18):
            for wx in range(x + 10, x + w - 10, 16):
                if rng.random() < .12: d.rectangle((wx, wy, wx + 5, wy + 6), fill=(255, 190, 110, 110))
        x += w + int(rng.integers(6, 20))
    d.line((0, base_y, W, base_y), fill=(226, 178, 92, 140), width=2)
    # Title.
    A.draw_text(im, 'LUCKY', (W / 2, 290), 150, (238, 246, 255), stroke=.10, tracking=1.9, glow=(CYAN, 12, .55))
    A.draw_text(im, 'CIRCUIT', (W / 2, 480), 150, (255, 236, 246), stroke=.10, tracking=1.9, glow=(MAGENTA, 12, .55))
    for y in (378, 392): d.line((W / 2 - 330, y, W / 2 + 330, y), fill=(226, 178, 92, 220 if y == 378 else 90), width=2)
    # Three sevens in pearl windows, gold rule, the top pay.
    cw = 210
    for i in range(3):
        c = mini_cell('seven', cw); im.alpha_composite(c, (int(W / 2 - 1.5 * cw - 20 + i * (cw + 20)), 610))
    top = pays()['three']['seven']
    A.draw_text(im, f'THREE SEVENS PAY {top} FOR 1', (W / 2, 745), 34, (226, 178, 92), stroke=.13, tracking=1.6)
    A.draw_text(im, 'PULL THE LEVER', (W / 2, 820), 26, (150, 220, 240), stroke=.13, tracking=2.0)
    hairframe(d, (0, 0, W - 1, H - 1), (226, 178, 92, 170), 3, 18)
    hairframe(d, (0, 0, W - 1, H - 1), (226, 178, 92, 70), 1, 30)
    return im.resize((1024, 1024), Image.Resampling.LANCZOS)


def paytable(symbols, table):
    """Paytable display, 0.60 x 0.33 m (drawn at that ratio, fitted to 1024x512)."""
    W, H = 1820, 1000
    im = screen_bg((W, H), (10, 12, 22), (3, 4, 8)); d = ImageDraw.Draw(im, 'RGBA')
    A.draw_text(im, 'THREE ON THE CENTER LINE', (W / 2, 70), 40, (226, 178, 92), stroke=.13, tracking=1.8)
    d.line((120, 118, W - 120, 118), fill=(226, 178, 92, 120), width=2)
    order = sorted(table['three'], key=lambda k: (-table['three'][k], symbols.index(k)))
    colw, rowh = (W - 80) / 4, 300
    for i, name in enumerate(order):
        c, r = i % 4, i // 4; x0 = 40 + c * colw; y0 = 150 + r * rowh
        cw = 250
        im.alpha_composite(mini_cell(name, cw), (int(x0 + colw / 2 - cw / 2), int(y0 + 18)))
        A.draw_text(im, 'x' + str(table['three'][name]), (x0 + colw / 2, y0 + 190), 76, (236, 228, 214), stroke=.12, tracking=1.3)
        if c: d.line((x0, y0 + 20, x0, y0 + 230), fill=(48, 226, 255, 50), width=2)
    d.line((120, 760, W - 120, 760), fill=(48, 226, 255, 90), width=2)
    rules = [('CHERRY CHERRY ANY', table['twoCherries']), ('ANY THREE FRUIT', table['mixedFruit']), ('CHERRY ON REEL 1', table['oneCherry'])]
    for i, (label, pay) in enumerate(rules):
        x = W * (i + .5) / 3
        A.draw_text(im, label, (x, 815), 32, (210, 220, 236), stroke=.13, tracking=1.4)
        A.draw_text(im, 'x' + str(pay), (x, 875), 44, (255, 120, 190), stroke=.13, tracking=1.3)
        if i: d.line((W * i / 3, 790, W * i / 3, 900), fill=(48, 226, 255, 60), width=2)
    A.draw_text(im, f'BET {table["min"]} - {table["max"]}', (W / 2, 950), 26, (150, 160, 180), stroke=.13, tracking=2.0)
    hairframe(d, (0, 0, W - 1, H - 1), (226, 178, 92, 120), 2, 12)
    return im.resize((1024, 512), Image.Resampling.LANCZOS)


def belly():
    """Belly glass, 0.60 x 0.39 m (fitted to 1024x512): the series emblem."""
    W, H = 1540, 1000
    im = screen_bg((W, H), (14, 12, 22), (4, 4, 8), 5); d = ImageDraw.Draw(im, 'RGBA')
    cx, cy = W / 2, 420
    for r, a in ((250, 200), (232, 90)):
        pts = [(cx + r * math.cos(math.radians(60 * i + 30)), cy + r * math.sin(math.radians(60 * i + 30))) for i in range(6)]
        d.line(pts + pts[:1], fill=(226, 178, 92, a), width=4 if a > 100 else 2)
    A.draw_text(im, '77', (cx, cy), 220, (238, 230, 214), stroke=.09, tracking=1.2, glow=(MAGENTA, 16, .8))
    A.draw_text(im, 'CIRCUIT SERIES', (cx, 760), 64, (226, 236, 250), stroke=.11, tracking=2.2)
    A.draw_text(im, 'HIGH LIMIT', (cx, 860), 34, (226, 178, 92), stroke=.13, tracking=2.4)
    for y in (700, 905):
        d.line((cx - 360, y, cx + 360, y), fill=(48, 226, 255, 90), width=2)
    hairframe(d, (0, 0, W - 1, H - 1), (226, 178, 92, 110), 2, 14)
    return im.resize((1024, 512), Image.Resampling.LANCZOS)


def deck_art():
    """Keycap legends (row 0), card reader display (row 1 left), spin disc (bottom right)."""
    W, H = 1024, 512
    im = Image.new('RGBA', (W, H), (30, 32, 38, 255)); d = ImageDraw.Draw(im, 'RGBA')
    for i, (label, color) in enumerate((('CASH OUT', (236, 200, 120)), ('BET -', (224, 230, 240)), ('BET +', (224, 230, 240)), ('MAX BET', (255, 140, 200)))):
        x0 = i * 256
        d.rounded_rectangle((x0 + 14, 12, x0 + 242, 116), radius=10, outline=(70, 74, 84, 255), width=2)
        A.draw_text(im, label, (x0 + 128, 64), 34 if len(label) > 5 else 40, color, stroke=.14, tracking=1.3)
    # Player-card display: amber text on smoked glass.
    d.rectangle((0, 128, 512, 256), fill=(8, 9, 12, 255))
    A.draw_text(im, 'INSERT PLAYER CARD', (256, 176), 30, (255, 172, 64), stroke=.14, tracking=1.3, glow=((255, 172, 64), 4, .6))
    A.draw_text(im, 'CIRCUIT CLUB', (256, 222), 20, (150, 120, 70), stroke=.14, tracking=1.6)
    # Spin disc.
    c = (896, 384)
    d.ellipse((c[0] - 118, c[1] - 118, c[0] + 118, c[1] + 118), fill=(12, 40, 50, 255))
    d.ellipse((c[0] - 106, c[1] - 106, c[0] + 106, c[1] + 106), outline=(48, 226, 255, 200), width=3)
    A.draw_text(im, 'SPIN', c, 52, (220, 250, 255), stroke=.15, tracking=1.4, glow=(CYAN, 6, .9))
    return im


def grille():
    """Perforated speaker grille (seamless): staggered round holes in dark gunmetal."""
    n, s = 256, 4
    im = Image.new('L', (n * s, n * s), 0); d = ImageDraw.Draw(im)
    pitch = n * s / 16; r = pitch * .3
    for j in range(17):
        for i in range(17):
            x = i * pitch + (pitch / 2 if j % 2 else 0); y = j * pitch * .866 * (16 / 13.856)
            for ox in (-n * s, 0, n * s):
                for oy in (-n * s, 0, n * s):
                    d.ellipse((x + ox - r, y + oy - r, x + ox + r, y + oy + r), fill=255)
    holes = np.asarray(im.resize((n, n), Image.Resampling.LANCZOS)).astype(float)[..., None] / 255
    metal = np.asarray(A.brushed_metal(n, (70, 74, 82), 11).convert('RGB')).astype(float)
    arr = metal * (1 - holes) + np.array([4, 4, 6]) * holes
    return Image.fromarray(arr.astype(np.uint8)).convert('RGBA')


def artwork(symbols):
    atlas = Image.new('RGBA', (1024, 1024), PEARL + (255,))
    for k, name in enumerate(symbols):
        c, r = k % 2, k // 2; atlas.alpha_composite(symbol_cell(name), (c * 512, r * 256))
    return {'brushed': A.brushed_metal(256, (82, 86, 95)), 'carbon': A.carbon_weave(512, 64), 'composite': A.composite(512),
            'slot_grille': grille(), 'slot_symbols': atlas, 'slot_marquee': marquee(), 'slot_paytable': paytable(symbols, pays()),
            'slot_belly': belly(), 'slot_deck': deck_art()}

# The engine samples rows bottom-up relative to our UVs (seen in game: text
# upside down), so the cooked bytes are flipped vertically; sources/ keeps the
# drawing upright. Set FLIP_V=False to cook the image as drawn.
FLIP_V = True
def cooked(image): return image.transpose(Image.Transpose.FLIP_TOP_BOTTOM) if FLIP_V else image


def material(key): return A.cook_material(MATERIALS[key], DEPOT)
base.material = material


def glb(path, faces):
    colors = base.glb(path, faces); A.patch_uvs(path, faces); return colors


# ------------------------------------------------------------------ previews
def scene_items(geometry, lit=True, lever=0, stops=(7, 5, 7), coins=3):
    import wheel_tables_preview as pv
    items = [pv.place(geometry['slot_cabinet'])]
    for r in range(3): items.append(pv.place(geometry[f'slot_strip_{r + 1}'], (LAYOUT['reelX'][r], SY, PZ + (stops[r] + 1) * P)))
    items.append(pv.place(geometry[f'slot_lever_{lever}']))
    items.append(pv.place(geometry['slot_lamp_on' if lit else 'slot_lamp_off']))
    for i in range(coins): items.append(pv.place(geometry['slot_coin'], ((-.06, .03, -.01, .07)[i], LAYOUT['trayY'], LAYOUT['trayZ']), (0, 47, 113, 160)[i]))
    return items


def previews(geometry, images):
    """Design renders written to sources/preview_*.png (not shipped in the archive)."""
    import wheel_tables_preview as pv
    mats = {k: A.preview_material(s, images) for k, s in MATERIALS.items()}
    src = RESOURCE / 'sources'; shots = []
    shots.append(pv.render(scene_items(geometry), mats, src / 'preview_slots_hero.png', eye=(2.4, -3.6, 2.1), target=(0, 0, 1.5), fov=44, size=(1000, 1300), floor_z=0))
    shots.append(pv.render(scene_items(geometry, lit=False, coins=0), mats, src / 'preview_slots_player.png', eye=(0, -1.6, 2.05), target=(0, 0, 1.72), fov=52, size=(1200, 900), floor_z=0))
    shots.append(pv.render(scene_items(geometry, lit=False, coins=0), mats, src / 'preview_slots_reels.png', eye=(.12, -1.45, 1.8), target=(0, -.4, 1.6), fov=34, size=(1200, 900)))
    shots.append(pv.render(scene_items(geometry, lever=3), mats, src / 'preview_slots_lever.png', eye=(1.9, -1.7, 2.1), target=(.3, -.1, 1.65), fov=46, size=(1200, 900), floor_z=0))
    shots.append(pv.render(scene_items(geometry), mats, src / 'preview_slots_base.png', eye=(.95, -1.6, .62), target=(0, -.42, .42), fov=48, size=(1200, 900), floor_z=0))
    return shots


# ------------------------------------------------------------------ checks
def bounds(faces):
    return [min(f[k][j] for f in faces for k in ('a', 'b', 'c')) for j in range(3)], [max(f[k][j] for f in faces for k in ('a', 'b', 'c')) for j in range(3)]


def check_layout(geometry, symbols, strips):
    """Geometry invariants the client timeline relies on."""
    (bx0, bx1), (by0, by1), (bz0, bz1) = BODY_BOX; (cx0, cx1), (cy0, cy1), (cz0, cz1) = BAY
    def inside(lo, hi, dx=0, dy=0, dz=0, margin=.002):
        return bx0 + margin <= lo[0] + dx and hi[0] + dx <= bx1 - margin and by0 + margin <= lo[1] + dy and hi[1] + dy <= by1 - margin and bz0 + margin <= lo[2] + dz and hi[2] + dz <= bz1 - margin
    def clear_of_bay(lo, hi, dx=0, dy=0, dz=0):
        return hi[0] + dx < cx0 or lo[0] + dx > cx1 or hi[1] + dy < cy0 or lo[1] + dy > cy1 or hi[2] + dz < cz0 or lo[2] + dz > cz1
    park = LAYOUT['leverPark']
    for i in range(len(LAYOUT['leverAngles'])):
        lo, hi = bounds(geometry[f'slot_lever_{i}'])
        assert inside(lo, hi, *park) and clear_of_bay(lo, hi, *park), ('parked lever pose is visible', i, lo, hi)
        assert lo[0] > X_OUT, ('active lever intersects the cabinet', i)
    for name in ('slot_lamp_on', 'slot_lamp_off'):
        lo, hi = bounds(geometry[name]); assert lo[2] >= bz1 + .03 and inside(lo, hi, *LAYOUT['lampPark']) and clear_of_bay(lo, hi, *LAYOUT['lampPark']), name
    lo, hi = bounds(geometry['slot_coin']); cp = LAYOUT['coinPark']
    for x in (-.06, .03, -.01, .07):
        assert inside([x + lo[0], cp[1] + lo[1], cp[2] + lo[2]], [x + hi[0], cp[1] + hi[1], cp[2] + hi[2]]) and clear_of_bay([x + lo[0], cp[1] + lo[1], cp[2] + lo[2]], [x + hi[0], cp[1] + hi[1], cp[2] + hi[2]])
    # Coins rest on the tray floor and fall from inside the chute canopy.
    floor = [f for f in geometry['slot_cabinet'] if f['color'] == 'gunmetal' and all(abs(f[k][2] - .935) < 1e-9 for k in 'abc')]
    assert floor and abs(LAYOUT['trayZ'] + lo[2] - .936) < 1e-9, 'coins rest 1 mm above the tray floor'
    assert all(abs(x) + hi[0] < .198 for x in (-.06, .03, -.01, .07)) and -.533 < LAYOUT['trayY'] + lo[1] and LAYOUT['trayY'] + hi[1] < -.40
    assert 1.02 < LAYOUT['chuteZ'] < 1.10 and -.47 < LAYOUT['chuteY'] < -.406
    # Strips: for every payline position j in [1,STOPS+1) (incl. overshoot wrap)
    # the strip covers the window and stays inside the dark bay.
    w = LAYOUT['reelWidth']
    for r, x in enumerate(LAYOUT['reelX']):
        lo, hi = bounds(geometry[f'slot_strip_{r + 1}'])
        assert abs(lo[0] + w / 2) < 1e-9 and abs(hi[0] - w / 2) < 1e-9 and lo[1] == hi[1] == 0
        assert cx0 < x - w / 2 and x + w / 2 < cx1 and cy0 < SY < cy1
        for step in range(STOPS * 20 + 1):
            j = 1 + step / 20; zt = PZ + j * P + hi[2]; zb = PZ + j * P + lo[2]
            assert cz0 < zb and zt < cz1, ('strip leaves the bay', r, j)
            assert zb < WINDOW_Z[0] - .005 and zt > WINDOW_Z[1] + .005, ('strip does not cover the window', r, j)
        entries = [strips[r][-1]] + strips[r] + strips[r][:2]
        for j in range(3): assert entries[j] == entries[j + STOPS]
    # Window: strips' outer edges and divider gaps are behind the bezel; the bay
    # sits inside the closed core, the hole inside the bay.
    assert WINDOW_X[0] > LAYOUT['reelX'][0] - w / 2 and WINDOW_X[1] < LAYOUT['reelX'][2] + w / 2
    assert HOLE_X[0] >= cx0 and HOLE_X[1] <= cx1 and cz0 < HOLE_Z[0] and HOLE_Z[1] < cz1
    assert bx0 < cx0 and cx1 < bx1 and by0 == cy0 and cy1 < by1 and bz0 < cz0 and cz1 < bz1
    # Nothing of the cabinet reaches the strips' plane or the bay behind it (only the lining).
    for f in geometry['slot_cabinet']:
        if f['color'] in ('lining',): continue
        c = [sum(f[k][i] for k in 'abc') / 3 for i in range(3)]
        if cx0 + .001 < c[0] < cx1 - .001 and SY - .004 < c[1] < cy1 - .001 and cz0 + .001 < c[2] < cz1 - .001:
            raise AssertionError(('cabinet face inside the reel bay', f['color'], c))


# Where the machine is seen from (unscaled cabinet-local metres): the player in
# front (standing and seated), the client cameras, both sides, low and high.
VIEWPOINTS = [(0, -1.6, 2.05), (0, -1.1, 1.55), (.15, -2.9, 2.2), (1.9, -1.7, 2.1), (-1.9, -1.7, 2.1), (.8, -1.8, .7),
              (-.9, -1.2, 2.9), (2.2, .4, 1.4), (0, 2.2, 1.8)]
SAME_FACING_GAP = .003   # different materials facing the same way stay >= 3 mm apart where they overlap


def check_geometry(geometry):
    """No z-fighting and no holes: no two material groups overlap in one plane
    (within 1 mm, either facing: touching faces are left out; within 3 mm when
    both face the same way), and from every viewpoint the first surface on each
    ray faces the viewer."""
    for name, faces in geometry.items():
        pairs = mesh_checks.coplanar_overlaps(faces, tol=.001, same_material=lambda key: key.startswith('TEX:'))
        assert not pairs, (name, len(pairs), mesh_checks.describe(faces, pairs))
    # The cabinet with its parts at rest (lever, lamp, strips on the payline, coins in the tray).
    rest = list(geometry['slot_cabinet']) + geometry['slot_lever_0'] + geometry['slot_lamp_on']
    for r in range(3): rest += A.translate(geometry[f'slot_strip_{r + 1}'], (LAYOUT['reelX'][r], SY, PZ + P))
    for x in (-.06, .03, -.01, .07): rest += A.translate(geometry['slot_coin'], (x, LAYOUT['trayY'], LAYOUT['trayZ']))
    pairs = mesh_checks.coplanar_overlaps(rest, tol=SAME_FACING_GAP, angle=2)
    tri = np.array([[f['a'], f['b'], f['c']] for f in rest]); n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    same = [p for p in pairs if float(np.dot(n[p[0]], n[p[1]])) > 0]
    assert not same, ('surfaces of two materials within 3 mm, facing the same way', len(same), mesh_checks.describe(rest, same))
    cabinet = [f for f in geometry['slot_cabinet']]
    bad = mesh_checks.see_through(cabinet, VIEWPOINTS)
    assert not bad, ('back faces seen from the viewpoints', sorted({c for _, _, c in bad}), len(bad), bad[:6])
    print(f'GEOMETRY: {len(geometry)} models without coplanar overlaps between materials (1 mm, 3 mm same-facing at rest); cabinet closed from {len(VIEWPOINTS)} viewpoints', flush=True)


def verify(work, manifest):
    """Independent cooked-file, namespace, package-index and authored-pose checks."""
    spec = importlib.util.spec_from_file_location('archive_checks', ROOT / 'tools/test-board-game-props.py'); checks = importlib.util.module_from_spec(spec); spec.loader.exec_module(checks)
    archive = work / 'archive'; verified = work / 'verified'; packed = (work / 'packed/archive.archive').read_bytes()
    entries = checks.archive_entries(packed); files = manifest['files']; n_tex = len(TEXTURE_NAMES)
    assert len(manifest['models']) == 13 and len(manifest['textures']) == n_tex
    assert len(entries) == len(files) == 2 * 13 + n_tex + len(COLLIDERS)
    assert [row['for'] for row in manifest['colliders']] == list(COLLIDERS)
    for row in manifest['colliders']:
        assert row['name'] == col.collider_name(row['for']) and row['for'] in COLLIDERS and row['scaleBaked'] == col.SCALE
        col.check_collider_entity(next(verified.rglob(row['name'] + '.ent.json')), COLLIDERS[row['for']])
    assert set(entries) == {checks.fnv(row['depot']) for row in files}
    allowed = {row['depot'] for row in files} | set(manifest['materialDependencies'])
    for row in files:
        data = (archive / row['depot'].replace('\\', '/')).read_bytes()
        assert data[:4] == b'CR2W' and len(data) == row['bytes'] and hashlib.sha256(data).hexdigest() == row['sha256']
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
                if model['materials'][chunk_index] in TEXTURED:
                    assert all(-.001 <= v <= 1.001 for pair in values for v in pair), (name, 'artwork UV out of bounds')
            mats = r['localMaterialBuffer']['materials']; names = {e['name']['$value'] for e in r['materialEntries']}
            assert all(0 <= e['index'] < len(mats) for e in r['materialEntries'])
            assert all(c['$value'] in names for a in r['appearances'] for c in a['Data']['chunkMaterials'])
            for key, mat in zip(model['materials'], mats):
                params = {k: v for e in mat['values'] for k, v in e.items() if k != '$type'}
                assert ('EmissiveEV' in params) == (key in emissive), (name, key)
                if key in emissive:
                    assert abs(params['EmissiveEV'] - MATERIALS[key].ev()) < 1e-5 and max(params['EmissiveColor'][c] for c in ('Red', 'Green', 'Blue')) > 0, (name, key)
            lo, hi = r['boundingBox']['Min'], r['boundingBox']['Max']
            for i, axis in enumerate(('X', 'Y', 'Z')):
                assert math.isfinite(lo[axis]) and math.isfinite(hi[axis]) and lo[axis] <= hi[axis]
                assert abs(lo[axis] - model['bounds']['min'][i]) < 1e-5 and abs(hi[axis] - model['bounds']['max'][i]) < 1e-5
    for texture in manifest['textures']:
        r = json.loads(next(verified.rglob(texture['name'] + '.xbm.json')).read_text())['Data']['RootChunk']
        assert r['$type'] == 'CBitmapTexture' and r['width'] == texture['width'] and r['height'] == texture['height']
        blob = r['renderTextureResource']['renderResourceBlobPC']['Data']; data = base64.b64decode(blob['textureData']['Bytes'])
        assert len(blob['header']['mipMapInfo']) == texture['mips']
        source = RESOURCE / 'sources' / (texture['name'] + '.png'); image = Image.open(source).convert('RGBA')
        assert hashlib.sha256(source.read_bytes()).hexdigest() == texture['sourceSha256']
        assert data[:image.width * image.height * 4] == (cooked(image) if texture.get('flipV') else image).tobytes() and all(v == 255 for v in data[3::4])
    symbols, strips = reels(); assert manifest['symbols'] == symbols and manifest['reels'] == strips and manifest['layout'] == LAYOUT
    geometry = models(symbols, strips)
    check_layout(geometry, symbols, strips); check_geometry(geometry)
    by_name = {m['name']: m for m in manifest['models']}
    cb = by_name['slot_cabinet']['bounds']; lamp_top = by_name['slot_lamp_on']['bounds']['max'][2]
    assert abs(cb['min'][2]) < 1e-9, 'origin on the floor'
    assert .62 <= (cb['max'][0] - cb['min'][0]) * SCALE <= .70 and 1.9 <= lamp_top * SCALE <= 2.1, ('true-scale proportions', cb, lamp_top)
    box = COLLIDERS['slot_cabinet'][0]
    assert box.center[0] + box.size[0] / 2 <= X_OUT + 1e-9 < LAYOUT['leverPivot'][0] - .03, 'the lever side stays open'
    with zipfile.ZipFile(RESOURCE / 'dist/open77_casino_slots.zip') as z:
        assert z.testzip() is None and z.namelist() == ['archive/pc/mod/0_open77_casino_slots.archive']
        assert z.read(z.namelist()[0]) == packed
    print(f'VERIFIED: 13 native props (cabinet, 3 strips, 6 lever poses, 2 lamps, coin), {n_tex} opaque mipmapped textures, {len(files)} exact RDAR entries incl. {len(COLLIDERS)} collider entity, emission, geometry/bindings/package hashes, parked poses hidden, strips always cover the window inside the bay, no coplanar overlaps, no holes', flush=True)


def main():
    p = argparse.ArgumentParser(description=__doc__); p.add_argument('--lab', type=Path, default=LAB); p.add_argument('--work', type=Path, default=Path('/tmp/casino-slots-props/build'))
    p.add_argument('--verify-only', action='store_true'); p.add_argument('--preview', '--preview-only', dest='preview', action='store_true', help='render sources/preview_*.png and stop (texture sources are only rewritten by a cook)')
    p.add_argument('--check-geometry', action='store_true', help='only run the layout, z-fighting and hole checks on the authored geometry'); a = p.parse_args(); work = a.work
    if a.verify_only:
        verify(work, json.loads((RESOURCE / 'asset-manifest.json').read_text())); return
    symbols, strips = reels(); geometry = models(symbols, strips); check_layout(geometry, symbols, strips)
    if a.check_geometry:
        check_geometry(geometry); return
    images = artwork(symbols); (RESOURCE / 'sources').mkdir(parents=True, exist_ok=True)
    if a.preview:
        previews(geometry, images); print('PREVIEWS written to', RESOURCE / 'sources', flush=True); return
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
    previews(geometry, images)
    records = []
    for i, (name, faces) in enumerate(geometry.items()):
        colors = glb(raw / (name + '.mesh.glb'), faces)
        (schemas / (name + '.mesh.json')).write_text(json.dumps(base.mesh_json(donor, colors, faces)))
        (schemas / (name + '.ent.json')).write_text(json.dumps(base.entity_json(template, name, i)))
        lo, hi = bounds(faces)
        records.append({'name': name, 'mesh': DEPOT + '\\' + name + '.mesh', 'entity': DEPOT + '\\' + name + '.ent', 'triangles': len(faces), 'materials': colors, 'bounds': {'min': lo, 'max': hi}})
    colliders = []
    for i, (name, boxes) in enumerate(COLLIDERS.items()):
        (schemas / (col.collider_name(name) + '.ent.json')).write_text(json.dumps(col.collider_entity_json(template, boxes, i)))
        colliders.append({'name': col.collider_name(name), 'for': name, 'entity': DEPOT + '\\' + col.collider_name(name) + '.ent', 'scaleBaked': col.SCALE, 'boxes': [{'size': list(b.size), 'center': list(b.center)} for b in boxes]})
    archive = work / 'archive'; target = archive / DEPOT.replace('\\', '/'); (target / 'textures').mkdir(parents=True, exist_ok=True)
    cli('convert', 'deserialize', schemas, '-o', target); cli('convert', 'deserialize', tex, '-o', target / 'textures'); cli('import', *[raw / (name + '.mesh.glb') for name in geometry], '-o', target, '--keep', imports=len(geometry))
    verified = work / 'verified'; verified.mkdir(exist_ok=True); cli('convert', 'serialize', archive, '-o', verified); packed = work / 'packed'; packed.mkdir(exist_ok=True); cli('pack', archive, '-o', packed)
    archive_file = packed / 'archive.archive'; assert archive_file.read_bytes()[:4] == b'RDAR'; output = RESOURCE / 'dist/open77_casino_slots.zip'; output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        info = zipfile.ZipInfo('archive/pc/mod/0_open77_casino_slots.archive', (2026, 1, 1, 0, 0, 0)); info.compress_type = zipfile.ZIP_DEFLATED; info.external_attr = 0o100644 << 16; z.writestr(info, archive_file.read_bytes())
    files = [{'depot': str(q.relative_to(archive)).replace('/', '\\'), 'sha256': hashlib.sha256(q.read_bytes()).hexdigest(), 'bytes': q.stat().st_size} for q in sorted(archive.rglob('*')) if q.is_file()]
    manifest = {'version': '3.0.0', 'style': 'Night City premium stepper cabinet: satin lacquer, black chrome, brushed gunmetal, carbon, smoked glass, restrained cyan/magenta light lines',
                'namespace': DEPOT, 'models': records, 'colliders': colliders, 'textures': textures, 'files': files, 'symbols': symbols, 'reels': strips, 'layout': LAYOUT,
                'emission': {k: {'rgb': s.emit[0], 'ev': s.ev()} for k, s in MATERIALS.items() if s.emit},
                'archiveSha256': hashlib.sha256(archive_file.read_bytes()).hexdigest(), 'zipSha256': hashlib.sha256(output.read_bytes()).hexdigest(), 'buildWork': str(work),
                'materialDependencies': A.depot_dependencies(MATERIALS.values())}
    (RESOURCE / 'asset-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n'); print('COOKED', len(records), 'models,', len(textures), 'textures,', len(files), 'native files, ZIP', output.stat().st_size, 'bytes', flush=True)
    verify(work, manifest)


if __name__ == '__main__': main()
