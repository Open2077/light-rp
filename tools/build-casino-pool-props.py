#!/usr/bin/env python3
"""Cook the original Night City pool table, cue, rack and 16 balls.

Art direction: a sleek 9 ft table in carbon and black chrome. A thin cyan
light line runs under the rail lip, a magenta one round the floor plinth; the
dark midnight-teal cloth carries a faint hex print, a glowing head string and
spots; chrome pocket irons, diamond sights as tiny lights, a sculpted spine
base, a glass-lit ball return on the foot end. The cue: carbon shaft, chrome
ferrule and joint, a glowing ring. The balls read from above at any yaw (the
prop API turns props about Z only): the number sits on a top cap, stripes are
an equatorial band; the cue ball wears a thin glowing equator.

Every dimension is real size (shared/casino_pool.lua: 2.54 x 1.27 m cloth,
57.15 mm balls, bed at P.BED) and the meshes are authored at 1/0.65 of it, so
the client's 0.65 prop scale shows them full size. Origin: the floor under the
centre of the cloth, +X towards the foot (the rack and the ball return).

Uses the shared native-prop cooker (tools/build-board-game-props.py) as a
read-only schema/tool library, tools/wheel_tables_art.py for the typeface,
textures and materials and tools/wheel_tables_preview.py for the critique
renders. `--preview-only` renders sources/preview_*.png without cooking.
"""
import argparse, base64, hashlib, importlib.util, json, math, os, struct, subprocess, sys, zipfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
from lupa.lua54 import LuaRuntime
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import wheel_tables_art as A
RESOURCE = ROOT / 'resources/assets/models/open77_casino_pool'
DEPOT = 'open77\\assets\\op77_lightrp\\casino_pool'
LAB = ROOT.parent / 'dop-tests'
spec = importlib.util.spec_from_file_location('native_boards', ROOT / 'tools/build-board-game-props.py'); base = importlib.util.module_from_spec(spec); spec.loader.exec_module(base)
base.RESOURCE = RESOURCE; base.DEPOT = DEPOT
spec = importlib.util.spec_from_file_location('collision_props', ROOT / 'tools/collision_props.py'); col = importlib.util.module_from_spec(spec); spec.loader.exec_module(col)


def rules():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('LightRpBoardGames={};LightRpItems={}')
    lua.execute((ROOT / 'resources/gamemodes/op77_lightrp/shared/casino_pool.lua').read_text())
    return lua.globals().LightRpPool


P = rules()
SCALE = .65
K = 1 / SCALE
L, W, R, BED = P.L, P.W, P.R, P.BED
TRAY = P.TRAY
POCKETS = [(P.POCKETS[i][1], P.POCKETS[i][2]) for i in range(1, 7)]
NOSE = BED + .0365                  # cushion nose: 64 % of a ball diameter
RAIL_TOP = BED + .044
CUSH = .05                          # nose to the rail
RAIL = .16                          # nose to the outer edge of the rail
HOLE_C, HOLE_S = .060, .056         # pocket hole radius: corner, side
MOUTH_C, MOUTH_S = .115, .066       # nose ends: from the corner / half the side opening
APRON_Z = BED - .22                 # bottom of the apron
SPINE = (-.95, .95, -.22, .22)      # the base's closed spine (cue and spare balls park inside)
PARK_CUE_X, PARK_Z = P.PARK.cueX, P.PARK.z   # client: where hidden props park (inside the spine)
CUE_LEN, CUE_TILT = 1.47, 4.0
OUTER = (L / 2 + RAIL, W / 2 + RAIL)

# ------------------------------------------------------------------ materials
S = A.Spec
BALL_COLORS = {1: (242, 186, 26), 2: (28, 74, 214), 3: (214, 30, 40), 4: (104, 40, 178), 5: (242, 112, 20), 6: (12, 140, 86), 7: (128, 24, 40), 8: (14, 14, 18)}
CLOTH = (11, 36, 46)
MATERIALS = {
    'cloth': S('pool_cloth', (255, 255, 255), .92, 0., ((255, 255, 255), 'soft'), 'pool_cloth_glow'),
    'cushion': S('weave', CLOTH, .9, 0.),
    'carbon': S('carbon', (255, 255, 255), .26, .35),
    'body': S('carbon', (150, 150, 162), .3, .45),
    'gunmetal': S('brushed', (255, 255, 255), .32, .9),
    'black_chrome': S(None, (24, 26, 31), .12, 1.),
    'chrome': S(None, (210, 214, 222), .05, 1.),
    'liner': S(None, (5, 6, 8), .95, 0.),
    'smoke': S(None, (10, 12, 16), .06, .3),
    'neon_cyan': S(None, (40, 230, 255), .3, 0., ((40, 230, 255), 'neon')),
    'neon_magenta': S(None, (255, 46, 196), .3, 0., ((255, 46, 196), 'soft')),
    'diamond': S(None, (200, 248, 255), .2, 0., ((150, 240, 255), 'lamp')),
    'balls': S('pool_balls', (255, 255, 255), .12, 0.),
    'ball_white': S(None, (226, 222, 212), .1, 0.),
    'ball_glow': S(None, (60, 236, 255), .2, 0., ((60, 236, 255), 'neon')),
    'cue_tip': S(None, (40, 120, 190), .85, 0.),
    'cue_wrap': S('carbon', (150, 150, 160), .5, .2),
    'cue_glow': S(None, (255, 46, 196), .25, 0., ((255, 46, 196), 'neon')),
    'rubber': S(None, (12, 12, 14), .8, 0.),
}
for n, c in BALL_COLORS.items():
    MATERIALS['ball_%d' % n] = S(None, c, .1, 0.)
TEXTURE_NAMES = ['pool_cloth', 'pool_cloth_glow', 'pool_balls', 'weave', 'carbon', 'brushed']
TEXTURED = {'cloth', 'balls'}
# Player collision (tools/COLLISION.md): the table body up to the rail. The
# players stand all round to shoot; nothing reaches past the rail.
COLLIDERS = {'pool_table': [col.Box.between((-OUTER[0] * K, -OUTER[1] * K, 0), (OUTER[0] * K, OUTER[1] * K, RAIL_TOP * K))]}


# ------------------------------------------------------------------ helpers
def scaled(faces): return A.transform(faces, lambda p: (p[0] * K, p[1] * K, p[2] * K))


def arc(c, r, a0, a1, n):
    return [(c[0] + r * math.cos(math.radians(a0 + (a1 - a0) * k / n)), c[1] + r * math.sin(math.radians(a0 + (a1 - a0) * k / n))) for k in range(n + 1)]


def polygon(out, poly, z, color, up=True, uvf=None):
    """Triangulated flat polygon (ear clipping), facing up or down."""
    area = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
    if area < 0: poly = poly[::-1]
    for a, b, c in base.triangulate(poly):
        pts = [[poly[a][0], poly[a][1], z], [poly[b][0], poly[b][1], z], [poly[c][0], poly[c][1], z]]
        A.tri(out, *pts, color, [uvf(p) for p in pts] if uvf else None, (0, 0, 1 if up else -1))


def walls(out, poly, z0, z1, color, outward=True):
    """Vertical walls on a closed polygon, facing out of (or into) it."""
    area = sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly)))
    cx = sum(p[0] for p in poly) / len(poly); cy = sum(p[1] for p in poly) / len(poly)
    for i in range(len(poly)):
        (x0, y0), (x1, y1) = poly[i], poly[(i + 1) % len(poly)]
        n = (y1 - y0, -(x1 - x0)) if area > 0 else (-(y1 - y0), x1 - x0)
        if not outward: n = (-n[0], -n[1])
        A.quad(out, [[x0, y0, z0], [x1, y1, z0], [x1, y1, z1], [x0, y0, z1]], color, (n[0], n[1], 0))


def extrude_along(out, profile, a, b, color, shift0=0., shift1=0., facing_out=None):
    """A closed (o,z) profile extruded from a to b along the segment direction t,
    with o along the outward normal n. shift0/1(o): extra length at each end
    per unit of o (mitred jaws: the back of a cushion reaches further)."""
    t = (b[0] - a[0], b[1] - a[1]); lt = math.hypot(*t); t = (t[0] / lt, t[1] / lt)
    n = facing_out
    def pt(end, o, z):
        s = -shift0 * o if end == 0 else shift1 * o
        p = a if end == 0 else b
        return [p[0] + t[0] * s + n[0] * o, p[1] + t[1] * s + n[1] * o, z]
    m = len(profile)
    co = sum(p[0] for p in profile) / m; cz = sum(p[1] for p in profile) / m
    for j in range(m):
        (o0, z0), (o1, z1) = profile[j], profile[(j + 1) % m]
        mid_o, mid_z = (o0 + o1) / 2 - co, (z0 + z1) / 2 - cz
        q = [pt(0, o0, z0), pt(1, o0, z0), pt(1, o1, z1), pt(0, o1, z1)]
        A.quad(out, q, color, (n[0] * mid_o, n[1] * mid_o, mid_z))
    for end, sign in ((0, -1), (1, 1)):
        pts = [pt(end, o, z) for o, z in profile]
        for k in range(1, m - 1):
            A.tri(out, pts[0], pts[k], pts[k + 1], color, facing=(t[0] * sign, t[1] * sign, 0))


# ------------------------------------------------------------------ the table
def bed_outline():
    """The cloth under the cushions: the rectangle to the cushion backs, its
    corners and side edges notched by the pocket holes (a simple polygon)."""
    X, Y = L / 2 + CUSH, W / 2 + CUSH
    poly = []
    def circle_cross_x(c, r, xline):  # points of the circle on x=xline
        dx = xline - c[0]; h = math.sqrt(max(0, r * r - dx * dx)); return (xline, c[1] - h), (xline, c[1] + h)
    def circle_cross_y(c, r, yline):
        dy = yline - c[1]; h = math.sqrt(max(0, r * r - dy * dy)); return (c[0] - h, yline), (c[0] + h, yline)
    def arc_between(c, r, p, q, n=14):
        """The arc from p to q that runs inside the rectangle (the notch)."""
        a = math.atan2(p[1] - c[1], p[0] - c[0]); b = math.atan2(q[1] - c[1], q[0] - c[0])
        for ccw in (True, False):
            e = b
            if ccw:
                while e <= a: e += math.tau
            else:
                while e >= a: e -= math.tau
            m = (a + e) / 2
            if abs(c[0] + r * math.cos(m)) < X and abs(c[1] + r * math.sin(m)) < Y:
                return [(c[0] + r * math.cos(a + (e - a) * k / n), c[1] + r * math.sin(a + (e - a) * k / n)) for k in range(n + 1)]
        raise ValueError('no arc inside the bed')
    corners = {(sx, sy): (sx * (L / 2 + .022), sy * (W / 2 + .022)) for sx in (-1, 1) for sy in (-1, 1)}
    sides = {sy: (0, sy * (W / 2 + .038)) for sy in (-1, 1)}
    poly = []
    # CCW: bottom edge left to right, right edge up, top edge right to left, left edge down.
    c = corners[(-1, -1)]; poly += arc_between(c, HOLE_C, circle_cross_x(c, HOLE_C, -X)[1], circle_cross_y(c, HOLE_C, -Y)[1])
    c = sides[-1]; poly += arc_between(c, HOLE_S, circle_cross_y(c, HOLE_S, -Y)[0], circle_cross_y(c, HOLE_S, -Y)[1])
    c = corners[(1, -1)]; poly += arc_between(c, HOLE_C, circle_cross_y(c, HOLE_C, -Y)[0], circle_cross_x(c, HOLE_C, X)[1])
    c = corners[(1, 1)]; poly += arc_between(c, HOLE_C, circle_cross_x(c, HOLE_C, X)[0], circle_cross_y(c, HOLE_C, Y)[0])
    c = sides[1]; poly += arc_between(c, HOLE_S, circle_cross_y(c, HOLE_S, Y)[1], circle_cross_y(c, HOLE_S, Y)[0])
    c = corners[(-1, 1)]; poly += arc_between(c, HOLE_C, circle_cross_y(c, HOLE_C, Y)[1], circle_cross_x(c, HOLE_C, -X)[0])
    return poly


def cloth_uv(p):
    X, Y = L / 2 + CUSH, W / 2 + CUSH
    return [(p[0] + X) / (2 * X), (Y - p[1]) / (2 * Y)]


def rail_piece(side):
    """One rail top (long +y/-y or short +x/-x), between the 45-degree seams
    through the corner pockets, notched by the holes, out to the outer edge."""
    Xi, Yi, Xo, Yo = L / 2 + CUSH, W / 2 + CUSH, OUTER[0], OUTER[1]
    def cross(c, r, p, d):
        # First point of the ray p + s d (s >= 0) on the circle, from outside in.
        fx, fy = p[0] - c[0], p[1] - c[1]
        bq = fx * d[0] + fy * d[1]; cq = fx * fx + fy * fy - r * r
        s = -bq - math.sqrt(max(0, bq * bq - cq))
        return (p[0] + d[0] * s, p[1] + d[1] * s)
    def arc_between(c, r, p, q, ccw, n=12):
        a = math.atan2(p[1] - c[1], p[0] - c[0]); b = math.atan2(q[1] - c[1], q[0] - c[0])
        if ccw:
            while b <= a: b += math.tau
        else:
            while b >= a: b -= math.tau
        return [(c[0] + r * math.cos(a + (b - a) * k / n), c[1] + r * math.sin(a + (b - a) * k / n)) for k in range(n + 1)]
    def on_line_y(c, r, yline, right):
        dy = yline - c[1]; h = math.sqrt(max(0, r * r - dy * dy)); return (c[0] + (h if right else -h), yline)
    def on_line_x(c, r, xline, top):
        dx = xline - c[0]; h = math.sqrt(max(0, r * r - dx * dx)); return (xline, c[1] + (h if top else -h))
    s2 = 1 / math.sqrt(2)
    if side in ('+y', '-y'):
        sy = 1 if side == '+y' else -1
        cl, cr = (-(L / 2 + .022), sy * (W / 2 + .022)), ((L / 2 + .022), sy * (W / 2 + .022))
        cs = (0, sy * (W / 2 + .038))
        # Right seam: from the outer corner along the diagonal towards the pocket.
        o_r = (Xo, sy * Yo); d_r = (-s2, -sy * s2)
        p1 = cross(cr, HOLE_C, o_r, d_r)
        q1 = on_line_y(cr, HOLE_C, sy * Yi, False)
        poly = [o_r, p1] + arc_between(cr, HOLE_C, p1, q1, sy > 0)[1:]
        a, b = on_line_y(cs, HOLE_S, sy * Yi, True), on_line_y(cs, HOLE_S, sy * Yi, False)
        poly += arc_between(cs, HOLE_S, a, b, sy > 0)
        o_l = (-Xo, sy * Yo); d_l = (s2, -sy * s2)
        p2 = cross(cl, HOLE_C, o_l, d_l)
        q2 = on_line_y(cl, HOLE_C, sy * Yi, True)
        poly += arc_between(cl, HOLE_C, q2, p2, sy > 0)[:-1] + [p2, o_l]
        return poly
    sx = 1 if side == '+x' else -1
    cb, ct = (sx * (L / 2 + .022), -(W / 2 + .022)), (sx * (L / 2 + .022), (W / 2 + .022))
    o_b = (sx * Xo, -Yo); d_b = (-sx * s2, s2)
    p1 = cross(cb, HOLE_C, o_b, d_b); q1 = on_line_x(cb, HOLE_C, sx * Xi, True)
    poly = [o_b, p1] + arc_between(cb, HOLE_C, p1, q1, sx < 0)[1:]
    o_t = (sx * Xo, Yo); d_t = (-sx * s2, -s2)
    p2 = cross(ct, HOLE_C, o_t, d_t); q2 = on_line_x(ct, HOLE_C, sx * Xi, False)
    poly += arc_between(ct, HOLE_C, q2, p2, sx < 0)[:-1] + [p2, o_t]
    return poly


CUSHION_PROFILE = [(CUSH, BED), (.010, BED), (.002, BED + .026), (0, NOSE), (.004, NOSE + .0045), (.016, RAIL_TOP - .001), (CUSH, RAIL_TOP)]


def cushions(out):
    """Six cushions: the nose on the playing edge, mitred jaws at the pockets."""
    hx, hy = L / 2, W / 2
    jc, js = 1.0, .36            # tan of the jaw angles: corner 45 deg, side 20 deg
    for sy in (1, -1):
        n = (0, sy)
        for x0, x1, s0, s1 in ((-hx + MOUTH_C, -MOUTH_S, jc, js), (MOUTH_S, hx - MOUTH_C, js, jc)):
            a, b = (x0, sy * hy), (x1, sy * hy)
            extrude_along(out, CUSHION_PROFILE, a, b, 'cushion', s0, s1, n)
    for sx in (1, -1):
        n = (sx, 0)
        a, b = (sx * hx, -hy + MOUTH_C), (sx * hx, hy - MOUTH_C)
        extrude_along(out, CUSHION_PROFILE, a, b, 'cushion', jc, jc, n)


def pocket(out, c, r, mouth_dir, sector):
    """A pocket: chrome iron round the hole (open towards the cloth), a dark
    liner down into the body and a black lip at the cloth."""
    md = math.degrees(math.atan2(mouth_dir[1], mouth_dir[0]))
    a0, a1 = md + sector / 2, md + 360 - sector / 2
    n = 40
    prof = [(r - .002, RAIL_TOP - .004), (r - .002, RAIL_TOP + .004), (r + .004, RAIL_TOP + .0075), (r + .016, RAIL_TOP + .0065), (r + .021, RAIL_TOP + .002), (r + .021, RAIL_TOP - .001)]
    for k in range(n):
        t0 = math.radians(a0 + (a1 - a0) * k / n); t1 = math.radians(a0 + (a1 - a0) * (k + 1) / n)
        for j in range(len(prof) - 1):
            (o0, z0), (o1, z1) = prof[j], prof[j + 1]
            q = [[c[0] + o0 * math.cos(t0), c[1] + o0 * math.sin(t0), z0], [c[0] + o0 * math.cos(t1), c[1] + o0 * math.sin(t1), z0],
                 [c[0] + o1 * math.cos(t1), c[1] + o1 * math.sin(t1), z1], [c[0] + o1 * math.cos(t0), c[1] + o1 * math.sin(t0), z1]]
            tm = (t0 + t1) / 2; nz = (o1 - o0); no = -(z1 - z0)
            A.quad(out, q, 'chrome', (math.cos(tm) * no, math.sin(tm) * no, nz))
        # The iron's ends close against the jaws.
    for t in (a0, a1):
        tt = math.radians(t); pts = [[c[0] + o * math.cos(tt), c[1] + o * math.sin(tt), z] for o, z in prof]
        for k in range(1, len(pts) - 1):
            A.tri(out, pts[0], pts[k], pts[k + 1], 'chrome', facing=(-math.sin(tt) * (1 if t == a0 else -1), math.cos(tt) * (1 if t == a0 else -1), 0))
    # Liner: a dark cup seen through the hole (floor up, wall facing in).
    liner = []
    A.lathe(liner, [(0, BED - .12), (r, BED - .12), (r, RAIL_TOP)], 'liner', 32)
    out += A.translate(liner, (c[0], c[1], 0))
    lip = []
    A.lathe(lip, [(r - .003, BED + .0008), (r + .002, BED + .0008)], 'rubber', 32)
    out += A.translate(lip, (c[0], c[1], 0))


def diamonds(out):
    spots = []
    for sy in (1, -1):
        for k in (-3, -2, -1, 1, 2, 3):
            spots.append((k * L / 8, sy * (W / 2 + .105), 0))
    for sx in (1, -1):
        for k in (-1, 0, 1):
            spots.append((sx * (L / 2 + .105), k * W / 4, 90))
    for x, y, a in spots:
        d = []
        pts = [[.009, 0, RAIL_TOP + .0012], [0, .0045, RAIL_TOP + .0012], [-.009, 0, RAIL_TOP + .0012], [0, -.0045, RAIL_TOP + .0012]]
        A.quad(d, pts, 'diamond', (0, 0, 1))
        A.lathe(d, [(.0105, RAIL_TOP + .0006), (.0105, RAIL_TOP - .0004)], 'chrome', 4, start=0)
        out += A.translate(A.rotate_z(d, a), (x, y, 0))
    return len(spots)


def rounded_rect(x0, x1, y0, y1, r, arcn=6):
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for k in range(arcn + 1):
            t = math.radians(a0 + 90 * k / arcn); pts.append((cx + r * math.cos(t), cy + r * math.sin(t)))
    return pts


def ball_return(out):
    """The foot end apron: a lit channel behind a chrome frame where pocketed
    object balls line up (client: P.TRAY)."""
    x_face = OUTER[0] - .012
    y0, y1 = TRAY.y0 - R - .03, TRAY.y0 + 14 * TRAY.step + R + .03
    z0, z1 = TRAY.z - .012, TRAY.z + 2 * R + .016
    xb = TRAY.x - R - .012
    A.box(out, ((xb + x_face) / 2, (y0 + y1) / 2, z0 - .004), (x_face - xb, y1 - y0, .008), 'smoke')           # channel floor
    A.quad(out, [[xb, y0, z0], [xb, y1, z0], [xb, y1, z1], [xb, y0, z1]], 'smoke', (1, 0, 0))                  # back wall
    A.quad(out, [[xb, y0, z1], [x_face, y0, z1], [x_face, y1, z1], [xb, y1, z1]], 'liner', (0, 0, -1))         # ceiling
    for y, s in ((y0, 1), (y1, -1)):
        A.quad(out, [[xb, y, z0], [x_face, y, z0], [x_face, y, z1], [xb, y, z1]], 'smoke', (0, s, 0))
    A.box(out, (x_face - .006, (y0 + y1) / 2, z0 + .0015), (.004, y1 - y0 - .01, .002), 'neon_cyan', bottom=False)  # underlight on the front lip
    # Chrome frame on the apron face.
    for zz in (z0 - .006, z1 + .006):
        A.box(out, (x_face + .004, (y0 + y1) / 2, zz), (.008, y1 - y0 + .024, .012), 'chrome')
    for yy in (y0 - .006, y1 + .006):
        A.box(out, (x_face + .004, yy, (z0 + z1) / 2), (.008, .012, z1 - z0 + .024), 'chrome')
    return (y0, y1, z0, z1, x_face, xb)


def apron(out, window):
    """The body under the rail: carbon panels, a black chrome lip and a cyan
    line under it, the foot end opened by the ball-return window."""
    y0w, y1w, z0w, z1w, x_face, _ = window
    ox, oy = OUTER[0] - .012, OUTER[1] - .012
    ztop = RAIL_TOP - .04
    # Long sides and the head end: full panels.
    for sy in (1, -1):
        A.quad(out, [[-ox, sy * oy, APRON_Z], [ox, sy * oy, APRON_Z], [ox, sy * oy, ztop], [-ox, sy * oy, ztop]], 'body', (0, sy, 0))
    A.quad(out, [[-ox, -oy, APRON_Z], [-ox, oy, APRON_Z], [-ox, oy, ztop], [-ox, -oy, ztop]], 'body', (-1, 0, 0))
    # Foot end: four panels round the window.
    foot = [((-oy, y0w - .012), (APRON_Z, ztop)), ((y1w + .012, oy), (APRON_Z, ztop)),
            ((y0w - .012, y1w + .012), (APRON_Z, z0w - .012)), ((y0w - .012, y1w + .012), (z1w + .012, ztop))]
    for (ya, yb), (za, zb) in foot:
        A.quad(out, [[ox, ya, za], [ox, yb, za], [ox, yb, zb], [ox, ya, zb]], 'body', (1, 0, 0))
    # Bottom of the body and the lip under the rail with its light line.
    A.quad(out, [[-ox, -oy, APRON_Z], [ox, -oy, APRON_Z], [ox, oy, APRON_Z], [-ox, oy, APRON_Z]], 'black_chrome', (0, 0, -1))
    path = rounded_rect(-OUTER[0], OUTER[0], -OUTER[1], OUTER[1], .012, 3)
    normals = A.outline_normals(path)
    A.sweep(out, path, normals, [(0, RAIL_TOP), (.0, RAIL_TOP - .008)], 'black_chrome')
    A.sweep(out, path, normals, [(0, RAIL_TOP - .008), (-.004, RAIL_TOP - .02), (-.012, RAIL_TOP - .026)], 'black_chrome')
    A.sweep(out, path, normals, [(-.012, RAIL_TOP - .026), (-.012, RAIL_TOP - .031)], 'neon_cyan')
    A.sweep(out, path, normals, [(-.012, RAIL_TOP - .031), (-.012, ztop)], 'black_chrome')
    # Under the bed (seen through the pocket holes): a dark closure.
    A.quad(out, [[-ox, -oy, BED - .05], [-ox, oy, BED - .05], [ox, oy, BED - .05], [ox, -oy, BED - .05]], 'liner', (0, 0, -1))


def base_stand(out):
    """A sculpted base: a closed black-chrome spine on two tapered pedestals,
    carbon side panels, a floor plinth with a magenta underglow."""
    x0, x1, y0, y1 = SPINE
    top = APRON_Z
    # Spine (closed box; the parked cue and balls hide inside).
    A.box(out, ((x0 + x1) / 2, 0, (.14 + top) / 2), (x1 - x0, y1 - y0, top - .14), 'black_chrome')
    for sy in (1, -1):
        A.box(out, (0, sy * (y1 + .0015), (.14 + top) / 2 + .02), (x1 - x0 - .2, .003, top - .26), 'carbon', top=False, bottom=False)
        A.box(out, (0, sy * (y1 + .0035), .22), (x1 - x0 - .2, .002, .006), 'neon_cyan', top=False, bottom=False)
    # Pedestals: tapered slabs at both ends, wider at the floor.
    for sx in (1, -1):
        xc = sx * .98
        prof = []
        foot_w, top_w = .62, .40
        poly_foot = rounded_rect(xc - .16, xc + .16, -foot_w, foot_w, .06)
        poly_top = rounded_rect(xc - .11, xc + .11, -top_w, top_w, .04)
        # Loft between the two outlines (same vertex counts).
        z0, z1 = .12, top
        for k in range(len(poly_foot)):
            a0, b0 = poly_foot[k], poly_foot[(k + 1) % len(poly_foot)]
            a1, b1 = poly_top[k], poly_top[(k + 1) % len(poly_top)]
            mx, my = (a0[0] + b0[0]) / 2 - xc, (a0[1] + b0[1]) / 2
            A.quad(out, [[a0[0], a0[1], z0], [b0[0], b0[1], z0], [b1[0], b1[1], z1], [a1[0], a1[1], z1]], 'gunmetal' if abs(my) > .3 else 'carbon', (mx, my, .25))
        polygon(out, poly_top, z1, 'black_chrome')
    # Floor plinth under everything.
    plinth = rounded_rect(-1.22, 1.22, -.70, .70, .14, 8)
    pn = A.outline_normals(plinth)
    polygon(out, plinth, .12, 'black_chrome')
    A.sweep(out, plinth, pn, [(0, .12), (0, .045)], 'black_chrome')
    A.sweep(out, plinth, pn, [(0, .045), (0, .04)], 'chrome')
    A.sweep(out, plinth, pn, [(-.012, .04), (-.012, .028)], 'neon_magenta')
    A.sweep(out, plinth, pn, [(0, .04), (-.012, .04)], 'black_chrome')
    A.sweep(out, plinth, pn, [(-.012, .028), (-.012, 0)], 'black_chrome')


def table():
    out = []
    polygon(out, bed_outline(), BED, 'cloth', uvf=cloth_uv)
    cushions(out)
    for side in ('+y', '-y', '+x', '-x'):
        polygon(out, rail_piece(side), RAIL_TOP, 'carbon')
    centre = (0, 0)
    for i, c in enumerate(POCKETS):
        corner = i < 4
        mouth = (-c[0], -c[1]) if corner else (0, -c[1])
        pocket(out, c, HOLE_C if corner else HOLE_S, mouth, 100 if corner else 150)
    diamonds(out)
    window = ball_return(out)
    apron(out, window)
    base_stand(out)
    return scaled(out)


# ------------------------------------------------------------------ balls, cue, rack
CAP = math.radians(38)      # top cap with the number (from the pole)
STRIPE = math.radians(36)   # stripe band half-height (latitude)
CELL = 256; ATLAS = 1024


def cap_uv(number, x, y):
    col, row = number % 4, number // 4
    cx, cy = (col * CELL + CELL / 2) / ATLAS, (row * CELL + CELL / 2) / ATLAS
    rr = .45 * CELL / ATLAS / (R * math.sin(CAP))
    return [cx + x * rr, cy - y * rr]


def ball(number):
    out = []
    segs, rings = 32, 18
    body = 'ball_white' if number == 0 or number >= 9 else 'ball_%d' % number
    stripe = 'ball_%d' % (number - 8) if number >= 9 else None
    # Origin at the ball's centre (the client places centres: P.BED+P.R on the cloth).
    def p(lat, lon): return [R * math.cos(lat) * math.cos(lon), R * math.cos(lat) * math.sin(lon), R * math.sin(lat)]
    lats = sorted(set([-math.pi / 2 + math.pi * k / rings for k in range(rings + 1)] + [math.pi / 2 - CAP, -STRIPE, STRIPE, -.07, .07]))
    for j in range(len(lats) - 1):
        la, lb = lats[j], lats[j + 1]; mid = (la + lb) / 2
        for k in range(segs):
            o0, o1 = math.tau * k / segs, math.tau * (k + 1) / segs
            if mid > math.pi / 2 - CAP:
                color = 'balls'
            elif stripe and abs(mid) < STRIPE:
                color = stripe
            elif number == 0 and abs(mid) < .07:
                color = 'ball_glow'
            else:
                color = body
            q = [p(la, o0), p(la, o1), p(lb, o1), p(lb, o0)]
            facing = [math.cos(mid) * math.cos((o0 + o1) / 2), math.cos(mid) * math.sin((o0 + o1) / 2), math.sin(mid)]
            uv = [cap_uv(number, v[0], v[1]) for v in q] if color == 'balls' else None
            A.quad(out, q, color, facing, uv)
    return scaled(out)


CUE_PROFILE = [  # (distance from the tip along the cue, radius, material)
    (0., .0058, 'cue_tip'), (.011, .0064, 'cue_tip'), (.012, .0066, 'chrome'), (.034, .0066, 'chrome'), (.035, .0066, 'carbon'),
    (.70, .0102, 'carbon'), (.705, .0108, 'chrome'), (.735, .0108, 'chrome'), (.737, .0110, 'cue_glow'), (.745, .0110, 'cue_glow'),
    (.747, .0112, 'black_chrome'), (1.02, .0128, 'black_chrome'), (1.022, .0129, 'chrome'), (1.03, .0129, 'chrome'), (1.032, .0131, 'cue_wrap'),
    (1.30, .0141, 'cue_wrap'), (1.302, .0143, 'black_chrome'), (1.39, .0146, 'black_chrome'), (1.392, .0147, 'neon_cyan'), (1.398, .0147, 'neon_cyan'),
    (1.40, .0147, 'black_chrome'), (1.455, .0149, 'black_chrome'), (1.457, .0145, 'rubber'), (CUE_LEN, .0130, 'rubber')]


def cue():
    """Tip at the origin, the butt towards -X and up by CUE_TILT degrees."""
    local = []
    sides = 20
    for (s0, r0, m0), (s1, r1, _) in zip(CUE_PROFILE, CUE_PROFILE[1:]):
        A.lathe(local, [(r1, s1), (r0, s0)], m0, sides)          # walking down: facing out
    A.lathe(local, [(CUE_PROFILE[0][1], 0), (0, 0)], 'cue_tip', sides)
    A.lathe(local, [(0, CUE_LEN), (CUE_PROFILE[-1][1], CUE_LEN)], 'rubber', sides)
    t = math.radians(CUE_TILT)
    # Lathe height h runs along the cue: (x,y,h) -> (-h cos t + x sin t, y, h sin t + x cos t).
    return scaled(A.transform(local, lambda q: (-q[2] * math.cos(t) + q[0] * math.sin(t), q[1], q[2] * math.sin(t) + q[0] * math.cos(t))))


def rack():
    """The triangle rack round 15 balls (apex ball centre at the origin, rows
    towards +X, z=0 on the cloth): black chrome with a cyan inner line."""
    d = 2 * R + P.RACK_GAP; dx = d * math.sqrt(3) / 2
    tri = [(0, 0), (4 * dx, -2 * d), (4 * dx, 2 * d)]
    c = (sum(p[0] for p in tri) / 3, 0)
    def offset(poly, o):
        res = []
        for i in range(3):
            p0, p1, p2 = poly[i - 1], poly[i], poly[(i + 1) % 3]
            # Corner moved out along the bisector so both edges move by o.
            e0 = (p1[0] - p0[0], p1[1] - p0[1]); e1 = (p2[0] - p1[0], p2[1] - p1[1])
            n0 = (e0[1], -e0[0]); n1 = (e1[1], -e1[0])
            l0, l1 = math.hypot(*n0), math.hypot(*n1); n0 = (n0[0] / l0, n0[1] / l0); n1 = (n1[0] / l1, n1[1] / l1)
            m = (n0[0] + n1[0], n0[1] + n1[1]); lm = math.hypot(*m); m = (m[0] / lm, m[1] / lm)
            s = o / (m[0] * n0[0] + m[1] * n0[1])
            res.append((p1[0] + m[0] * s, p1[1] + m[1] * s))
        return res
    ccw = sum(tri[i][0] * tri[(i + 1) % 3][1] - tri[(i + 1) % 3][0] * tri[i][1] for i in range(3)) > 0
    if not ccw: tri = tri[::-1]
    inner = offset(tri, R + .0015)
    out = []
    path = []
    for i in range(3):  # round the corners a little
        p0, p1, p2 = inner[i - 1], inner[i], inner[(i + 1) % 3]
        path += [(p1[0] + (p0[0] - p1[0]) * .04, p1[1] + (p0[1] - p1[1]) * .04), (p1[0] + (p2[0] - p1[0]) * .04, p1[1] + (p2[1] - p1[1]) * .04)]
    n = A.outline_normals(path)
    A.sweep(out, path, n, [(0, 0), (0, .022)], 'black_chrome')            # inner wall (faces in: walk up)
    A.sweep(out, path, n, [(0, .022), (.002, .026), (.010, .026), (.012, .022)], 'chrome')
    A.sweep(out, path, n, [(.012, .022), (.012, .0)], 'black_chrome')
    A.sweep(out, path, n, [(-.0006, .006), (-.0006, .009)], 'neon_cyan')
    return scaled(out)


def models():
    result = {'pool_table': table(), 'pool_cue': cue(), 'pool_rack': rack()}
    for n in range(16): result['pool_ball_%d' % n] = ball(n)
    return result


# ------------------------------------------------------------------ artwork
def rgba(c, a=255): return tuple(c[:3]) + (a,)


def weave(size=256, color=(150, 150, 150)):
    y, x = np.mgrid[0:size, 0:size]
    v = .9 + .06 * np.sin(x * math.tau / 4) * np.sin(y * math.tau / 4) + .04 * (A._periodic_noise(size, 16, 3) - .5)
    rgb = np.array(color)[None, None] * v[..., None]
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert('RGBA')


def cloth_art():
    """2048x1024 over the bed rectangle (cloth to the cushion backs): midnight
    teal weave, a faint hex print, the head string, spots and a small emblem.
    Returns (base, glow mask)."""
    Wd, Hd = 2048, 1024
    X, Y = L / 2 + CUSH, W / 2 + CUSH
    def px(x, y): return ((x + X) / (2 * X) * Wd, (Y - y) / (2 * Y) * Hd)
    rng = np.random.default_rng(77)
    yy, xx = np.mgrid[0:Hd, 0:Wd].astype(float)
    noise = A._periodic_noise(1024, 32, 5)
    mott = np.tile(noise, (1, 2))[:Hd, :Wd]
    fine = rng.random((Hd, Wd))
    v = .94 + .08 * (mott - .5) + .05 * (fine - .5) + .025 * np.sin(xx * math.pi / 1.5) * np.sin(yy * math.pi / 1.5)
    rgb = np.array(CLOTH)[None, None] * v[..., None]
    im = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert('RGBA')
    glow = Image.new('RGBA', (Wd, Hd), (0, 0, 0, 255))
    # Hex print: a large, very faint honeycomb over the playing field.
    hexlayer = Image.new('L', (Wd, Hd), 0); hd = ImageDraw.Draw(hexlayer)
    s = 38
    for row in range(-1, int(Hd / (s * 1.5)) + 2):
        for colx in range(-1, int(Wd / (s * math.sqrt(3))) + 2):
            cx = colx * s * math.sqrt(3) + (row % 2) * s * math.sqrt(3) / 2; cy = row * s * 1.5
            pts = [(cx + s * math.cos(math.radians(60 * k + 30)), cy + s * math.sin(math.radians(60 * k + 30))) for k in range(7)]
            hd.line(pts, fill=255, width=2)
    hexlayer = hexlayer.filter(ImageFilter.GaussianBlur(.8))
    tint = Image.new('RGBA', (Wd, Hd), (70, 150, 170, 0)); tint.putalpha(hexlayer.point(lambda q: int(q * .05)))
    im.alpha_composite(tint)
    # Fade the print towards a soft centre vignette.
    d = ImageDraw.Draw(im); g = ImageDraw.Draw(glow)
    cyan = (64, 228, 255)
    # Head string (dashed) and the spots.
    hx0, hy0 = px(P.HEAD_X, -W / 2); hx1, hy1 = px(P.HEAD_X, W / 2)
    for k in range(40):
        if k % 2: continue
        ya = hy0 + (hy1 - hy0) * k / 40; yb = hy0 + (hy1 - hy0) * (k + 1) / 40
        d.line((hx0, ya, hx0, yb), fill=rgba((60, 140, 160)), width=3)
        g.line((hx0, ya, hx0, yb), fill=(34, 76, 86, 255), width=3)
    for (x, y, r) in ((P.HEAD_X, 0, 9), (P.FOOT_X, 0, 9), (0, 0, 6)):
        cx, cy = px(x, y)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=rgba((170, 240, 255)))
        g.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(90, 150, 170, 255))
    # The foot spot ring (where the rack's apex goes).
    cx, cy = px(P.FOOT_X, 0)
    A.glow_line(im, lambda dd, f: dd.ellipse((cx - 30, cy - 30, cx + 30, cy + 30), outline=f, width=3), cyan, 6, .8)
    g.ellipse((cx - 30, cy - 30, cx + 30, cy + 30), outline=(80, 160, 180, 255), width=3)
    # Centre emblem: a chamfered hex outline with an original wordmark.
    cx, cy = px(0, 0); s = 120
    pts = [(cx + s * math.cos(math.radians(60 * k)), cy + s * math.sin(math.radians(60 * k))) for k in range(7)]
    d.line(pts, fill=rgba((40, 96, 112)), width=4)
    A.draw_text(im, 'NC//8', (cx, cy), 46, (44, 104, 120), stroke=.12, tracking=1.4)
    g.line(pts, fill=(30, 60, 70, 255), width=4)
    return im, glow


def balls_art():
    """4x4 cells of 256 px: the number disc of each ball (0 = cue ball)."""
    im = Image.new('RGBA', (ATLAS, ATLAS), (240, 238, 230, 255))
    for n in range(16):
        col, row = n % 4, n // 4; cx, cy = col * CELL + CELL / 2, row * CELL + CELL / 2
        d = ImageDraw.Draw(im)
        # Outside the disc: the ball's own colour (the cap's rim shows it).
        body = (240, 238, 230) if n == 0 or n >= 9 else BALL_COLORS[n]
        d.rectangle((col * CELL, row * CELL, (col + 1) * CELL - 1, (row + 1) * CELL - 1), fill=rgba(body))
        r = .45 * CELL
        if n == 0:
            d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=rgba((240, 238, 230)))
            for rr, w in ((.30, 7), (.14, 6)):
                d.ellipse((cx - rr * CELL, cy - rr * CELL, cx + rr * CELL, cy + rr * CELL), outline=rgba((40, 200, 235)), width=w)
            continue
        ring = BALL_COLORS[n if n <= 8 else n - 8]
        disc = (246, 244, 238)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=rgba(disc))
        d.ellipse((cx - r * .92, cy - r * .92, cx + r * .92, cy + r * .92), outline=rgba(ring if n != 8 else (255, 46, 196)), width=7)
        A.draw_text(im, str(n), (cx, cy + 2), CELL * (.50 if n < 10 else .40), (14, 14, 18), stroke=.2, tracking=1.1)
        if n in (6, 9):
            d.rectangle((cx - 28, cy + 74, cx + 28, cy + 82), fill=rgba((14, 14, 18)))   # 6/9 underline
    return im


def artwork():
    cloth, glow = cloth_art()
    return {'pool_cloth': cloth, 'pool_cloth_glow': glow.resize((1024, 512), Image.Resampling.LANCZOS), 'pool_balls': balls_art(),
            'weave': weave(256, (225, 225, 225)), 'carbon': A.carbon_weave(512, 64), 'brushed': A.brushed_metal(256, (70, 74, 82))}


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
    rack_pos = [(P.rack(3)[i][1], P.rack(3)[i][2]) for i in range(1, 17)]
    def scene(balls, cue=None, with_rack=False, potted=()):
        # Geometry is authored at 1/0.65: everything renders at the game's 0.65.
        items = [pv.place(geometry['pool_table'], (0, 0, 0), 0, SCALE)]
        for n, (x, y) in enumerate(balls):
            if n in potted:
                k = potted.index(n); x, y, z = TRAY.x, TRAY.y0 + k * TRAY.step, TRAY.z + R
            else: z = BED + R
            items.append(pv.place(geometry['pool_ball_%d' % n], (x, y, z), 0, SCALE))
        if with_rack: items.append(pv.place(geometry['pool_rack'], (P.FOOT_X, 0, BED), 0, SCALE))
        if cue:
            (x, y), yaw, back = cue; a = math.radians(yaw); dd = R + .012 + back
            items.append(pv.place(geometry['pool_cue'], (x - math.cos(a) * dd, y - math.sin(a) * dd, BED + R), yaw, SCALE))
        return items
    t_items = scene(rack_pos, ((P.HEAD_X, 0), 0, .12), True)
    play = [(-.30, .18), (.40, -.22), (.90, .36), (-.80, -.40), (.10, .50), (1.05, -.05), (.62, .10), (-.20, -.52), (0, 0), (.30, .30), (-.55, .25), (.75, -.45), (-1.0, .1), (.45, .55), (.2, -.1), (-.6, -.15)]
    p_items = scene(play, ((-.30, .18), -25, .05), False, potted=(3, 11, 6))
    shots = [
        pv.render(t_items, mats, src / 'preview_pool_hero.png', eye=(-2.9, -2.4, 2.0), target=(.15, 0, .55), fov=42, floor_z=0),
        pv.render(p_items, mats, src / 'preview_pool_player.png', eye=(-1.35, .42, 1.30), target=(.4, -.1, BED), fov=50),
        pv.render(p_items, mats, src / 'preview_pool_top.png', eye=(0, -.01, 3.6), target=(0, 0, BED), fov=46),
        pv.render(p_items, mats, src / 'preview_pool_return.png', eye=(2.35, -.75, .95), target=(1.3, 0, .6), fov=40, floor_z=0),
    ]
    b = []
    for n in range(16):
        b.append(pv.place(geometry['pool_ball_%d' % n], ((n % 8 - 3.5) * .085, (n // 8 - .5) * .12, R), 0, SCALE))
    b.append(pv.place(geometry['pool_cue'], (.42, -.25, R), 160, SCALE))
    shots.append(pv.render(b, mats, src / 'preview_pool_balls.png', eye=(0, -.55, .42), target=(0, 0, .0), fov=44))
    c = [pv.place(geometry['pool_cue'], (.70, 0, .1), 0, SCALE), pv.place(geometry['pool_ball_0'], (.70 + R + .012, 0, .1), 0, SCALE)]
    shots.append(pv.render(c, mats, src / 'preview_pool_cue.png', eye=(.05, -1.0, .40), target=(.0, 0, .12), fov=58))
    c = [pv.place(geometry['pool_cue'], (.0, 0, .1), 0, SCALE), pv.place(geometry['pool_ball_0'], (R + .012, 0, .1), 0, SCALE)]
    shots.append(pv.render(c, mats, src / 'preview_pool_cue_tip.png', eye=(-.12, -.22, .16), target=(-.05, 0, .1), fov=40))
    pv.sheet(shots[:4], src / 'preview_pool.png', 2)


# ------------------------------------------------------------------ checks
def check_poses(geometry):
    """Authored invariants the Lua client relies on (before cooking)."""
    def bounds(name):
        pts = [v for f in geometry[name] for v in (f['a'], f['b'], f['c'])]
        return [min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)]
    for n in range(16):
        lo, hi = bounds('pool_ball_%d' % n)
        assert abs(hi[2] - R * K) < 1e-6 and abs(lo[2] + R * K) < 1e-6 and abs(hi[0] - R * K) < 1e-3, ('ball', n, lo, hi)
        assert any(f['color'] == 'balls' for f in geometry['pool_ball_%d' % n]), 'number cap'
        stripes = {f['color'] for f in geometry['pool_ball_%d' % n]}
        assert (('ball_%d' % (n - 8)) in stripes) == (n >= 9) and ((n == 0) == ('ball_glow' in stripes))
    lo, hi = bounds('pool_cue')
    assert abs(hi[0]) < .02 * K and abs(lo[0] + CUE_LEN * math.cos(math.radians(CUE_TILT)) * K) < .02 * K and hi[2] > .09 * K, ('cue', lo, hi)
    # The tip is at the origin, on the axis (the client aims the tip at the ball).
    tip = [v for f in geometry['pool_cue'] for v in (f['a'], f['b'], f['c']) if v[0] > -.002 * K]
    assert tip and max(abs(v[1]) for v in tip) < .0075 * K and max(abs(v[2]) for v in tip) < .0075 * K
    lo, hi = bounds('pool_table')
    assert abs(lo[2]) < 1e-9 and abs(hi[0] - OUTER[0] * K) < .02 * K and abs(hi[1] - OUTER[1] * K) < .02 * K and hi[2] < (RAIL_TOP + .02) * K, ('table', lo, hi)
    # Cloth at BED; cushion noses on the playing edge, at NOSE height.
    cloth = [v for f in geometry['pool_table'] if f['color'] == 'cloth' for v in (f['a'], f['b'], f['c'])]
    assert all(abs(v[2] - BED * K) < 1e-6 for v in cloth)
    cush = [v for f in geometry['pool_table'] if f['color'] == 'cushion' for v in (f['a'], f['b'], f['c'])]
    assert min(min(abs(abs(v[0]) - L / 2 * K), abs(abs(v[1]) - W / 2 * K)) for v in cush if abs(v[2] - NOSE * K) < 1e-6) < 1e-6
    assert all(abs(v[0]) >= L / 2 * K - 1e-6 or abs(v[1]) >= W / 2 * K - 1e-6 for v in cush), 'no cushion reaches into the cloth'
    # The rack holds 15 racked balls (P.rack) with clearance.
    lo, hi = bounds('pool_rack')
    rk = [v for f in geometry['pool_rack'] if f['color'] == 'black_chrome' for v in (f['a'], f['b'], f['c'])]
    balls = P.rack(1)
    for i in range(2, 17):
        bx, by = (balls[i][1] - P.FOOT_X) * K, balls[i][2] * K
        assert all(math.hypot(v[0] - bx, v[1] - by) > R * K * .99 for v in rk), 'rack frame crosses a ball'
    # The pocket mouths of the physics sit inside the drawn openings.
    assert MOUTH_C > P.CORNER and MOUTH_S > P.SIDE
    # Parked props hide inside the closed spine.
    x0, x1, y0, y1 = SPINE
    assert PARK_CUE_X < x1 and PARK_CUE_X - CUE_LEN > x0 and PARK_Z + CUE_LEN * math.sin(math.radians(CUE_TILT)) + .016 < APRON_Z and PARK_Z - R > .14
    # Every face has an area (the cooker would drop degenerate ones silently).
    for name, faces in geometry.items():
        for f in faces:
            n = A.cross(A.sub(f['b'], f['a']), A.sub(f['c'], f['a'])); assert A.dot(n, n) > 1e-22, name


def verify(work, manifest):
    """Independent cooked-file, namespace, package-index and authored-pose checks."""
    spec = importlib.util.spec_from_file_location('archive_checks', ROOT / 'tools/test-board-game-props.py'); checks = importlib.util.module_from_spec(spec); spec.loader.exec_module(checks)
    archive = work / 'archive'; verified = work / 'verified'; packed = (work / 'packed/archive.archive').read_bytes()
    entries = checks.archive_entries(packed); files = manifest['files']
    n_models = 3 + 16; n_tex = len(TEXTURE_NAMES)
    assert len(manifest['models']) == n_models and len(manifest['textures']) == n_tex
    assert len(entries) == len(files) == 2 * n_models + n_tex + len(COLLIDERS)
    assert set(entries) == {checks.fnv(row['depot']) for row in files}
    assert all(row['depot'].startswith(DEPOT + '\\') for row in files)
    assert [c['name'] for c in manifest['colliders']] == [col.collider_name(n) for n in COLLIDERS]
    for row in manifest['colliders']:
        assert col.check_collider_entity(next(verified.rglob(row['name'] + '.ent.json')), COLLIDERS[row['for']]) == len(COLLIDERS[row['for']])
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
                vertices = chunk['chunkVertices']; layout_ = vertices['vertexLayout']; elements = layout_['elements']['Elements']
                for color in (e for e in elements if e['usage'] == 'PS_Color'):
                    stream = color['streamIndex']; offset = vertices['byteOffsets']['Elements'][stream]; stride = layout_['slotStrides']['Elements'][stream]
                    assert all(pixels[offset + j * stride:offset + j * stride + 4] == b'\xff' * 4 for j in range(chunk['numVertices']))
                uv = next(e for e in elements if e['usage'] == 'PS_TexCoord' and e['usageIndex'] == 0); stream = uv['streamIndex']; offset = vertices['byteOffsets']['Elements'][stream]; stride = layout_['slotStrides']['Elements'][stream]
                values = [struct.unpack_from('<ee', pixels, offset + j * stride) for j in range(chunk['numVertices'])]
                assert all(math.isfinite(v) for pair in values for v in pair)
                if model['materials'][chunk_index] in TEXTURED:
                    assert len(set(values)) > 1 and all(-.001 <= v <= 1.001 for pair in values for v in pair), (name, 'artwork UV out of bounds')
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
    t = by_name['pool_table']['bounds']; assert abs(t['min'][2]) < 1e-9 and abs(t['max'][0] - OUTER[0] * K) < .02 * K
    for n in range(16):
        b = by_name['pool_ball_%d' % n]['bounds']; assert abs(b['max'][2] - R * K) < 1e-5 and abs(b['min'][2] + R * K) < 1e-5
    with zipfile.ZipFile(RESOURCE / 'dist/open77_casino_pool.zip') as z:
        assert z.testzip() is None and z.namelist() == ['archive/pc/mod/0_open77_casino_pool.archive']
        assert z.read(z.namelist()[0]) == packed
    print(f'VERIFIED: {n_models} native props (table, cue, rack, 16 balls) + {len(COLLIDERS)} collider entity, {n_tex} opaque mipmapped textures, {len(files)} exact RDAR entries, geometry/bindings/emission/package hashes', flush=True)


def main():
    p = argparse.ArgumentParser(description=__doc__); p.add_argument('--lab', type=Path, default=LAB); p.add_argument('--work', type=Path, default=Path.home() / '.cache/casino-pool-build')
    p.add_argument('--verify-only', action='store_true'); p.add_argument('--preview-only', action='store_true'); a = p.parse_args(); work = a.work
    if a.verify_only:
        verify(work, json.loads((RESOURCE / 'asset-manifest.json').read_text())); return
    geometry = models(); check_poses(geometry); images = artwork()
    (RESOURCE / 'sources').mkdir(parents=True, exist_ok=True)
    previews(geometry, images)
    if a.preview_only:
        return
    tools = a.lab / 'tools'; env = os.environ.copy(); env['DOTNET_ROOT'] = str(tools / 'dotnet'); env['DOTNET_CLI_HOME'] = str(work / 'dotnet-home')
    def cli(*args, imports=0):
        result = subprocess.run([str(tools / 'dotnet/dotnet'), str(tools / 'wolvenkit/WolvenKit.CLI.dll'), *map(str, args)], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if '[ 0: Error' in result.stdout or (result.returncode and not (imports and result.stdout.count('Rebuilt with buffers:') == imports)): print(result.stdout); raise RuntimeError('WolvenKit failed ' + str(args))
        print('\n'.join(line for line in result.stdout.splitlines() if 'Success' in line)[-600:], flush=True)
    schemas = work / 'json'; raw = work / 'raw'; tex = work / 'texture-json'; host = work / 'host-schema'
    import shutil
    for stale in (schemas, raw, tex, work / 'archive', work / 'verified', work / 'packed'): shutil.rmtree(stale, ignore_errors=True)  # no file of an older cook survives
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
        (schemas / (name + '.ent.json')).write_text(json.dumps(base.entity_json(template, name, 7900 + i)))
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
    archive_file = packed / 'archive.archive'; assert archive_file.read_bytes()[:4] == b'RDAR'; output = RESOURCE / 'dist/open77_casino_pool.zip'; output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        info = zipfile.ZipInfo('archive/pc/mod/0_open77_casino_pool.archive', (2026, 1, 1, 0, 0, 0)); info.compress_type = zipfile.ZIP_DEFLATED; info.external_attr = 0o100644 << 16; z.writestr(info, archive_file.read_bytes())
    files = [{'depot': str(q.relative_to(archive)).replace('/', '\\'), 'sha256': hashlib.sha256(q.read_bytes()).hexdigest(), 'bytes': q.stat().st_size} for q in sorted(archive.rglob('*')) if q.is_file()]
    manifest = {'version': '1.0.0', 'style': 'Night City pool: carbon and black chrome 9 ft table, midnight-teal hex cloth, cyan rail light, chrome pocket irons, diamond lights, lit ball return; carbon cue; balls numbered on a top cap',
                'namespace': DEPOT, 'models': records, 'colliders': colliders, 'textures': textures, 'files': files,
                'layout': {'scale': SCALE, 'authoredAt': K, 'cloth': [L, W], 'ball': R, 'bed': BED, 'railTop': RAIL_TOP, 'nose': NOSE, 'outer': list(OUTER),
                           'tray': {'x': TRAY.x, 'y0': TRAY.y0, 'z': TRAY.z, 'step': TRAY.step}, 'parkCueX': PARK_CUE_X, 'spine': list(SPINE), 'cueLength': CUE_LEN, 'cueTilt': CUE_TILT},
                'emission': {k: {'rgb': s.emit[0], 'ev': s.ev()} for k, s in MATERIALS.items() if s.emit},
                'archiveSha256': hashlib.sha256(archive_file.read_bytes()).hexdigest(), 'zipSha256': hashlib.sha256(output.read_bytes()).hexdigest(), 'buildWork': str(work),
                'materialDependencies': A.depot_dependencies(MATERIALS.values())}
    (RESOURCE / 'asset-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n'); print('COOKED', len(records), 'models,', len(textures), 'textures,', len(files), 'native files, ZIP', output.stat().st_size, 'bytes', flush=True)
    verify(work, manifest)


if __name__ == '__main__': main()
