#!/usr/bin/env python3
"""Original "Night City" art for the chess, checkers and Connect Four props.

Geometry, material table and procedural textures for the open77_board_games
pack. `tools/build-board-game-props.py` imports this module to cook the pack,
and the pack's `sources/preview.py` imports it to render offline previews.

Conventions the gameplay client relies on (client/core/board_games.lua):
  * metres, RED4 axes, Z up; the runtime applies a uniform 0.65 scale;
  * chess/checkers: playable squares span -0.5..0.5 on X/Y, outer frame 1.12 m,
    bottom at Z=-0.036; square (row, col) is dark when (row+col) is odd;
  * pieces: origin at the centre of the base, Z=0 (the client puts them at
    Z=0.004, just above the 0.0035 tile tops); knights look towards +Y;
  * Connect Four: upright grid in XZ, front towards -Y, slot centres
    x=(col-4)*0.14, z=(6.5-row)*0.14+0.04, y=0; discs are centred on y=0.

Faces are dicts {a,b,c: [x,y,z], color: material key, uv?: [[u,v]*3]}.
Explicit UVs use the cooker convention: v=0 is the top row of the source PNG
(textures are cooked flipped, see FLIP_V in the cooker).

Geometry needs only the standard library; textures need NumPy and Pillow.
Everything is generated from code here: no donor geometry, fonts or logos.
"""
import math

# --------------------------------------------------------------------------
# Materials: key -> (texture name or None for plain white, sRGB colour,
# roughness, metalness). All use engine\materials\metal_base.remt. There is no
# guaranteed emissive shader, so "neon" parts are saturated, bright, nonmetal
# paint: they read as lit trim next to the dark lacquer and metal around them.
MATERIALS = {
    'cy:pearl': ('cy_pearl', '#FFFFFF', .24, .10),        # white side body
    'cy:chrome': (None, '#E9EDF2', .10, 1.0),             # white side trim
    'cy:onyx': ('cy_onyx', '#FFFFFF', .40, .05),          # black side body
    'cy:gunmetal': (None, '#6F7480', .20, 1.0),           # black side trim
    'cy:cyan': (None, '#38F4FF', .32, 0.0),
    'cy:magenta': (None, '#FF36B8', .32, 0.0),
    'cy:amber': (None, '#FFB524', .32, 0.0),
    'cy:graphite': ('cy_brushed', '#FFFFFF', .30, .85),   # brushed gunmetal
    'cy:carbon': ('cy_carbon', '#FFFFFF', .36, .10),
    'cy:void': (None, '#0B0C10', .55, 0.0),               # unlit insides
    'cy:chess_top': ('cy_chess_top', '#FFFFFF', .20, .12),
    'cy:checkers_top': ('cy_checkers_top', '#FFFFFF', .20, .12),
    'cy:connect4_face': ('cy_connect4_face', '#FFFFFF', .32, .35),
    'cy:disc_red': (None, '#E3162F', .24, .08),
    'cy:disc_red_core': (None, '#FF6E82', .30, 0.0),
    'cy:disc_yellow': (None, '#FFC21C', .24, .08),
    'cy:disc_yellow_core': (None, '#FFF3A0', .30, 0.0),
}
TEXTURE_SIZES = {
    'cy_chess_top': (1024, 1024), 'cy_checkers_top': (1024, 1024),
    'cy_connect4_face': (1024, 1024), 'cy_pearl': (256, 256),
    'cy_onyx': (256, 256), 'cy_brushed': (256, 256), 'cy_carbon': (256, 256),
}
SIDES = {
    # body, trim, accent. White = pearl + chrome + cyan, black = onyx +
    # gunmetal + magenta: readable at a glance even on the dark squares.
    'white': ('cy:pearl', 'cy:chrome', 'cy:cyan'),
    'black': ('cy:onyx', 'cy:gunmetal', 'cy:magenta'),
}
DISCS = {  # Connect Four: white side is Red, black side is Yellow (UI names).
    'white': ('cy:disc_red', 'cy:chrome', 'cy:disc_red_core'),
    'black': ('cy:disc_yellow', 'cy:chrome', 'cy:disc_yellow_core'),
}
BOARD_ACCENT = {'chess': 'cy:cyan', 'checkers': 'cy:amber'}
# Highest point of each model, metres before the 0.65 runtime scale. The chess
# values are mirrored by PIECE_HEIGHTS in client/core/board_games.lua and the
# checkers values by its inline man/king picking heights.
PIECE_HEIGHTS = {'pawn': .086, 'rook': .097, 'knight': .114, 'bishop': .124,
                 'queen': .139, 'king': .152}
CHECKER_HEIGHTS = {'man': .015, 'king': .032}
TILE_TOP = .0035          # chess/checkers tile tops; pieces sit at .004
GROOVE = .0015            # etched grid floor between the tiles
FRAME_TOP = .0115
TOP_SPAN = .56            # board-top textures cover x, y in [-.56, .56]
PIECE_SIDES = 32


def textured(material):
    return MATERIALS[material][0] is not None


# --------------------------------------------------------------------------
# Geometry primitives
def tri(out, a, b, c, m, uv=None):
    face = {'a': [float(v) for v in a], 'b': [float(v) for v in b], 'c': [float(v) for v in c], 'color': m}
    if uv is not None:
        face['uv'] = [[float(uv[0][0]), float(uv[0][1])], [float(uv[1][0]), float(uv[1][1])], [float(uv[2][0]), float(uv[2][1])]]
    out.append(face)


def quad(out, a, b, c, d, m, uv=None):
    tri(out, a, b, c, m, None if uv is None else (uv[0], uv[1], uv[2]))
    tri(out, a, c, d, m, None if uv is None else (uv[0], uv[2], uv[3]))


def top_uv(p):
    """Planar board-top mapping: x right, +Y at the top of the image."""
    return ((p[0] + TOP_SPAN) / (2 * TOP_SPAN), (TOP_SPAN - p[1]) / (2 * TOP_SPAN))


def area2(face):
    a, b, c = face['a'], face['b'], face['c']
    u = [b[i] - a[i] for i in range(3)]
    v = [c[i] - a[i] for i in range(3)]
    n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
    return math.sqrt(sum(x * x for x in n))


def clean(faces):
    """Drop the zero-area triangles that lathes produce at closed poles."""
    return [f for f in faces if area2(f) > 1e-11]


def lathe(out, profile, sides=PIECE_SIDES, phase=0.0, center=(0, 0)):
    """Revolve [(r, z, material), ...] (bottom centre -> top centre) around Z.

    The material of point i colours the segment to point i+1. Normals point
    outwards. Textured materials get cylindrical UVs (u around, v along the
    profile's arc length) so lathe marks run around the piece.
    """
    arc = [0.0]
    for (r0, z0, _), (r1, z1, _) in zip(profile, profile[1:]):
        arc.append(arc[-1] + math.hypot(r1 - r0, z1 - z0))
    cx, cy = center
    for k, ((r0, z0, m), (r1, z1, _)) in enumerate(zip(profile, profile[1:])):
        if r0 == 0 and r1 == 0:
            continue
        for i in range(sides):
            a = phase + math.tau * i / sides
            b = phase + math.tau * (i + 1) / sides
            p = (cx + r0 * math.cos(a), cy + r0 * math.sin(a), z0)
            q = (cx + r0 * math.cos(b), cy + r0 * math.sin(b), z0)
            r = (cx + r1 * math.cos(b), cy + r1 * math.sin(b), z1)
            s = (cx + r1 * math.cos(a), cy + r1 * math.sin(a), z1)
            uv = None
            if textured(m):
                ua, ub = i / sides, (i + 1) / sides
                va, vb = arc[k] * 9, arc[k + 1] * 9
                uv = ((ua, va), (ub, va), (ub, vb), (ua, vb))
            if r0 == 0:
                tri(out, p, r, s, m, None if uv is None else (uv[0], uv[2], uv[3]))
            elif r1 == 0:
                tri(out, p, q, r, m, None if uv is None else (uv[0], uv[1], uv[2]))
            else:
                quad(out, p, q, r, s, m, uv)


def sphere_profile(zc, radius, m, start=-90, end=90, steps=12):
    """Profile points of a sphere arc, angles in degrees from the equator."""
    pts = []
    for i in range(steps + 1):
        a = math.radians(start + (end - start) * i / steps)
        r = radius * math.cos(a)
        pts.append((0.0 if abs(r) < 1e-9 else r, zc + radius * math.sin(a), m))
    return pts


def square_outline(d, chamfer_at=.5):
    """Square of half-size d with 45-degree corner cuts that grow outwards,
    so every swept level is a true offset of the previous one."""
    c = max(0.0, (2 - math.sqrt(2)) * (d - chamfer_at))
    return [(d, -(d - c)), (d, d - c), (d - c, d), (-(d - c), d),
            (-d, d - c), (-d, -(d - c)), (-(d - c), -d), (d - c, -d)]


def sweep_square(out, profile):
    """Sweep [(d, z, material), ...] (bottom centre -> inside top) around a
    chamfered square, like a lathe. Board-top textures use planar UVs, other
    textured materials run along the perimeter (brushed edges)."""
    for (d0, z0, m), (d1, z1, _) in zip(profile, profile[1:]):
        lo, hi = square_outline(d0), square_outline(d1)
        run = 0.0
        for i in range(8):
            j = (i + 1) % 8
            p = (lo[i][0], lo[i][1], z0)
            q = (lo[j][0], lo[j][1], z0)
            r = (hi[j][0], hi[j][1], z1)
            s = (hi[i][0], hi[i][1], z1)
            uv = None
            if m.endswith('_top'):
                uv = tuple(top_uv(v) for v in (p, q, r, s))
            elif textured(m):
                length = math.dist(lo[i], lo[j])
                uv = ((run * 3, -z0 * 3), ((run + length) * 3, -z0 * 3),
                      ((run + length) * 3, -z1 * 3), (run * 3, -z1 * 3))
                run += length
            if d0 == 0:
                tri(out, p, r, s, m, None if uv is None else (uv[0], uv[2], uv[3]))
            else:
                quad(out, p, q, r, s, m, uv)


def bevel_box(out, x0, x1, y0, y1, z0, z1, m, bevel=.003, trim=None, skip=()):
    """Axis-aligned box with 45-degree chamfered edges and corners.

    `trim` colours the chamfers (e.g. chrome edges on graphite). `skip` lists
    main faces to leave out ('-x', '+x', '-y', '+y', '-z', '+z')."""
    b = min(bevel, (x1 - x0) / 2.01, (y1 - y0) / 2.01, (z1 - z0) / 2.01)
    edge = trim or m
    lo, hi = (x0, y0, z0), (x1, y1, z1)

    def point(sx, sy, sz, ax):
        # Corner (signs s*) pulled in by the bevel on every axis except `ax`.
        p = []
        for axis, sign in enumerate((sx, sy, sz)):
            v = hi[axis] if sign > 0 else lo[axis]
            if axis != ax:
                v -= sign * b
            p.append(v)
        return p

    def uvs(points, ax):
        if not textured(m):
            return None
        u_axis, v_axis = [a for a in range(3) if a != ax]
        return [(p[u_axis] * 4, -p[v_axis] * 4) for p in points]

    for ax, name in ((0, 'x'), (1, 'y'), (2, 'z')):
        for sign in (-1, 1):
            if ('+' if sign > 0 else '-') + name in skip:
                continue
            others = [a for a in range(3) if a != ax]
            corners = []
            for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                s = [0, 0, 0]
                s[ax] = sign
                s[others[0]], s[others[1]] = su, sv
                corners.append(point(s[0], s[1], s[2], ax))
            # Orient outwards: (u x v) points along +ax for this ordering.
            if sign < 0:
                corners.reverse()
            quad(out, *corners, m, uvs(corners, ax))
    # Edge chamfers: between faces of axes (a1, a2), along the third axis.
    for a1, a2 in ((0, 1), (0, 2), (1, 2)):
        a3 = 3 - a1 - a2
        for s1 in (-1, 1):
            for s2 in (-1, 1):
                pts = []
                for s3 in (-1, 1):
                    s = [0, 0, 0]
                    s[a1], s[a2], s[a3] = s1, s2, s3
                    pts.append((point(*s, a1), point(*s, a2)))
                # quad: face-a1 corner low, face-a2 corner low, face-a2 high, face-a1 high
                q = [pts[0][0], pts[0][1], pts[1][1], pts[1][0]]
                tri_out = []
                quad(tri_out, *q, edge)
                orient(tri_out, [s1 if i == a1 else s2 if i == a2 else 0 for i in range(3)])
                out.extend(tri_out)
    # Corner triangles.
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                t = []
                tri(t, point(sx, sy, sz, 0), point(sx, sy, sz, 1), point(sx, sy, sz, 2), edge)
                orient(t, (sx, sy, sz))
                out.extend(t)


def orient(faces, outward):
    """Flip triangles whose normal points against `outward`."""
    for f in faces:
        a, b, c = f['a'], f['b'], f['c']
        u = [b[i] - a[i] for i in range(3)]
        v = [c[i] - a[i] for i in range(3)]
        n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
        if sum(n[i] * outward[i] for i in range(3)) < 0:
            f['b'], f['c'] = f['c'], f['b']
            if 'uv' in f:
                f['uv'][1], f['uv'][2] = f['uv'][2], f['uv'][1]


def prism(out, polygon, x0, x1, m, cap=None):
    """Extrude a (y, z) polygon along X between x0 and x1 (caps + walls)."""
    poly = list(polygon)
    if signed_area(poly) < 0:
        poly.reverse()
    for a, b, c in triangulate(poly):
        tri(out, (x1, *poly[a]), (x1, *poly[b]), (x1, *poly[c]), cap or m)
        tri(out, (x0, *poly[c]), (x0, *poly[b]), (x0, *poly[a]), cap or m)
    for i in range(len(poly)):
        j = (i + 1) % len(poly)
        quad(out, (x0, *poly[i]), (x0, *poly[j]), (x1, *poly[j]), (x1, *poly[i]), m)


def signed_area(poly):
    return sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1]
               for i in range(len(poly))) / 2


def triangulate(poly):
    """Ear clipping for simple counter-clockwise polygons."""
    ids = list(range(len(poly)))
    result = []

    def side(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    while len(ids) > 3:
        for i, b in enumerate(ids):
            a, c = ids[i - 1], ids[(i + 1) % len(ids)]
            if side(poly[a], poly[b], poly[c]) <= 1e-14:
                continue
            if any(side(poly[a], poly[b], poly[p]) >= -1e-14 and side(poly[b], poly[c], poly[p]) >= -1e-14
                   and side(poly[c], poly[a], poly[p]) >= -1e-14 for p in ids if p not in (a, b, c)):
                continue
            result.append((a, b, c))
            ids.pop(i)
            break
        else:
            raise ValueError('polygon cannot be triangulated')
    result.append(tuple(ids))
    return result


def inset(poly, d):
    """Offset a counter-clockwise polygon inwards by d (mitred, clamped)."""
    if signed_area(poly) < 0:
        poly = poly[::-1]
    n = len(poly)
    result = []
    for i in range(n):
        p0, p1, p2 = poly[i - 1], poly[i], poly[(i + 1) % n]
        e1 = (p1[0] - p0[0], p1[1] - p0[1])
        e2 = (p2[0] - p1[0], p2[1] - p1[1])
        l1, l2 = math.hypot(*e1), math.hypot(*e2)
        n1 = (-e1[1] / l1, e1[0] / l1)      # inward normal (left side, CCW)
        n2 = (-e2[1] / l2, e2[0] / l2)
        bis = (n1[0] + n2[0], n1[1] + n2[1])
        bl = math.hypot(*bis)
        if bl < 1e-9:
            bis, bl = n1, 1.0
        bis = (bis[0] / bl, bis[1] / bl)
        cos_half = max(.35, bis[0] * n1[0] + bis[1] * n1[1])
        k = d / cos_half
        result.append((p1[0] + bis[0] * k, p1[1] + bis[1] * k))
    return result


def bevelled_prism(out, polygon, half, bevel, m, edge=None):
    """Extrude a (y, z) polygon along X (-half..half) with chamfered rims."""
    poly = list(polygon)
    if signed_area(poly) < 0:
        poly.reverse()
    small = inset(poly, bevel)
    edge = edge or m
    rings = [(-half, small), (-half + bevel, poly), (half - bevel, poly), (half, small)]
    for a, b, c in triangulate(small):
        tri(out, (half, *small[a]), (half, *small[b]), (half, *small[c]), m)
        tri(out, (-half, *small[c]), (-half, *small[b]), (-half, *small[a]), m)
    for k, ((xa, pa), (xb, pb)) in enumerate(zip(rings, rings[1:])):
        mat = m if k == 1 else edge
        for i in range(len(poly)):
            j = (i + 1) % len(poly)
            quad(out, (xa, *pa[i]), (xa, *pa[j]), (xb, *pb[j]), (xb, *pb[i]), mat)


def transform(faces, fn):
    for f in faces:
        for k in ('a', 'b', 'c'):
            f[k] = list(fn(f[k]))
    return faces


# --------------------------------------------------------------------------
# Chess pieces
def base_profile(body, trim, accent):
    """Machined puck shared by every chess piece; ends at the ledge (r .029, z .015)."""
    return [
        (0, 0, body), (.0345, 0, trim), (.0362, .0017, body),
        (.0362, .0072, body), (.0346, .0072, accent),      # inlaid neon groove
        (.0346, .0104, body), (.0362, .0104, body),
        (.0362, .0122, trim), (.0334, .0150, body),         # chrome chamfer catches light
        (.0290, .0150, body),
    ]


def chess_piece(kind, side):
    body, trim, accent = SIDES[side]
    out = []
    prof = base_profile(body, trim, accent)
    if kind == 'pawn':
        prof += [(.0250, .0180, body), (.0205, .0240, body), (.0175, .0320, body), (.0152, .0420, body),
                 (.0150, .0470, trim), (.0218, .0500, trim), (.0218, .0530, trim), (.0175, .0560, body)]
        head = sphere_profile(.0705, .0155, body, -64, 90, 14)
        # Raised neon equator ring on the "drone" head.
        eq = [p for p in head if p[1] < .0695]
        top = [p for p in head if p[1] > .0717]
        prof += [(eq[0][0], .0560, body)] + eq[1:] + [
            (.0155, .0695, accent), (.0166, .0695, accent), (.0166, .0717, body),
            (.0154, .0717, body)] + top
        lathe(out, prof)
    elif kind == 'rook':
        prof += [(0, .0150, body)]
        lathe(out, prof)
        # Octagonal tower: faceted body, chrome band, castellated crown with a
        # neon floor that shows through the crenels.
        tower = [(0, .0150, body), (.0232, .0150, body), (.0200, .0560, trim), (.0242, .0600, trim),
                 (.0242, .0640, body), (.0272, .0670, body), (.0272, .0760, body), (.0190, .0760, accent),
                 (0, .0760, accent)]
        lathe(out, tower, sides=8, phase=math.pi / 8)
        r_out, r_in = .0272, .0190
        for i in range(8):
            a0 = math.pi / 8 + math.tau * i / 8
            a1 = a0 + math.tau / 8
            if i % 2:
                crown_block(out, a0, a1, r_in, r_out, .0760, .0880, body, trim)
            else:
                crown_block(out, a0, a1, r_in, r_out, .0760, .0970, body, trim)
    elif kind == 'knight':
        prof += [(0, .0150, body)]
        lathe(out, prof)
        knight_head(out, body, trim, accent)
    elif kind == 'bishop':
        prof += [(.0240, .0185, body), (.0190, .0250, body), (.0150, .0380, body), (.0128, .0540, body),
                 (.0130, .0620, trim), (.0200, .0660, trim), (.0200, .0690, trim), (.0150, .0730, body)]
        head = [(.0150, .0730), (.0158, .0780), (.0165, .0840), (.0163, .0900), (.0152, .0960),
                (.0130, .1020), (.0098, .1080), (.0060, .1130), (.0030, .1160)]
        prof += [(r, z, body) for r, z in head[1:]] + [(0, .1172, body)]
        lathe(out, prof)
        lathe(out, sphere_profile(.1205, .0036, accent, steps=8), sides=16)
        mitre_slash(out, prof, accent)
    elif kind == 'queen':
        prof += [(.0240, .0185, body), (.0195, .0255, body), (.0158, .0400, body), (.0134, .0580, body),
                 (.0136, .0660, trim), (.0210, .0700, trim), (.0210, .0735, trim), (.0150, .0775, body),
                 (.0138, .0820, body), (.0150, .0920, body), (.0190, .1010, body), (.0236, .1070, trim),
                 (.0236, .1100, trim), (.0200, .1100, trim), (.0200, .1060, accent), (.0080, .1060, body),
                 (.0080, .1160, body), (0, .1160, body)]
        lathe(out, prof)
        lathe(out, sphere_profile(.1255, .0092, body, steps=12) , sides=24)
        lathe(out, sphere_profile(.1365, .0022, accent, steps=6), sides=12)
        for i in range(8):
            a = math.tau * i / 8 + math.pi / 8
            tine(out, a, .0218, .1095, .0262, .1290 if i % 2 == 0 else .1210, trim)
    elif kind == 'king':
        prof += [(.0244, .0185, body), (.0200, .0255, body), (.0163, .0400, body), (.0140, .0600, body),
                 (.0142, .0700, trim), (.0218, .0740, trim), (.0218, .0775, trim), (.0158, .0815, body),
                 (.0150, .0860, body), (.0168, .1000, body), (.0222, .1080, body), (.0222, .1105, body),
                 (.0208, .1105, accent), (.0208, .1135, body), (.0222, .1135, body), (.0222, .1180, trim),
                 (.0190, .1210, body), (0, .1210, body)]
        lathe(out, prof)
        # Chamfered cross finial with a neon line inlaid on both faces.
        bevel_box(out, -.0036, .0036, -.0026, .0026, .1205, .1520, trim, .0012)
        bevel_box(out, -.0118, .0118, -.0026, .0026, .1340, .1410, trim, .0012)
        for y0, y1 in ((-.00305, -.0024), (.0024, .00305)):
            bevel_box(out, -.0011, .0011, y0, y1, .1250, .1480, accent, .0002)
            bevel_box(out, -.0092, .0092, y0, y1, .1364, .1386, accent, .0002)
    return clean(out)


def crown_block(out, a0, a1, r_in, r_out, z0, z1, body, trim):
    """One octagon segment of the rook crown (outer/inner/top/side faces)."""
    def p(a, r, z):
        return (r * math.cos(a), r * math.sin(a), z)
    t = .0016   # chamfer on the top outer edge
    quad(out, p(a0, r_out, z0), p(a1, r_out, z0), p(a1, r_out, z1 - t), p(a0, r_out, z1 - t), body)
    quad(out, p(a0, r_out, z1 - t), p(a1, r_out, z1 - t), p(a1, r_out - t, z1), p(a0, r_out - t, z1), trim)
    quad(out, p(a0, r_out - t, z1), p(a1, r_out - t, z1), p(a1, r_in, z1), p(a0, r_in, z1), trim)
    quad(out, p(a1, r_in, z0), p(a0, r_in, z0), p(a0, r_in, z1), p(a1, r_in, z1), body)
    for a, sign in ((a0, -1), (a1, 1)):
        side = []
        quad(side, p(a, r_in, z0), p(a, r_out, z0), p(a, r_out, z1 - t), p(a, r_in, z1), body)
        tri(side, p(a, r_out, z1 - t), p(a, r_out - t, z1), p(a, r_in, z1), body)
        orient(side, (-math.sin(a) * -sign, math.cos(a) * sign, 0))
        out.extend(side)


def loft(out, path, m, around=24, power=.55):
    """Loft squircle sections along a path in the YZ plane.

    path: [(y, z, half_width_x, half_depth)]. Each section is perpendicular
    to the path; squircle sections (|cos|^p, |sin|^p) give a machined,
    softly squared look. Both ends are closed with fans."""
    rings = []
    for k, (y, z, w, h) in enumerate(path):
        y0, z0 = path[max(0, k - 1)][:2]
        y1, z1 = path[min(len(path) - 1, k + 1)][:2]
        tangent = math.atan2(z1 - z0, y1 - y0)
        ay, az = math.cos(tangent + math.pi / 2), math.sin(tangent + math.pi / 2)
        ring = []
        for i in range(around):
            t = math.tau * i / around
            c, s = math.cos(t), math.sin(t)
            px = w * math.copysign(abs(c) ** power, c)
            pd = h * math.copysign(abs(s) ** power, s)
            ring.append((px, y + pd * ay, z + pd * az))
        rings.append(ring)
    side = []
    for ra, rb in zip(rings, rings[1:]):
        for i in range(around):
            j = (i + 1) % around
            quad(side, ra[i], ra[j], rb[j], rb[i], m)
    # Orient every side quad away from its local path centre.
    for f in side:
        c = [(f['a'][k] + f['b'][k] + f['c'][k]) / 3 for k in range(3)]
        best = min(path, key=lambda p: (p[0] - c[1]) ** 2 + (p[1] - c[2]) ** 2)
        orient([f], (c[0], c[1] - best[0], c[2] - best[1]))
    out.extend(side)
    for ring, inner, end in ((rings[0], rings[1], path[0]), (rings[-1], rings[-2], path[-1])):
        local = []
        centre = (0.0, end[0], end[1])
        for i in range(around):
            tri(local, centre, ring[i], ring[(i + 1) % around], m)
        oy = sum(p[1] for p in inner) / around
        oz = sum(p[2] for p in inner) / around
        orient(local, (0, end[0] - oy, end[1] - oz))
        out.extend(local)


def knight_head(out, body, trim, accent):
    """Sculpted mech horse: a leaning neck and a tapered head lofted from
    squircle sections, chrome crest, swept-back ears, neon visor. Muzzle +Y."""
    neck = [(-.0010, .0160, .0118, .0172), (-.0030, .0300, .0116, .0166), (-.0045, .0450, .0110, .0152),
            (-.0045, .0600, .0104, .0140), (-.0020, .0740, .0098, .0128), (.0015, .0850, .0090, .0110),
            (.0035, .0905, .0060, .0060)]
    head = [(-.0080, .0985, .0058, .0050), (-.0050, .0990, .0088, .0098), (.0030, .0955, .0100, .0126),
            (.0120, .0885, .0094, .0120), (.0200, .0818, .0084, .0102), (.0260, .0772, .0076, .0088),
            (.0292, .0750, .0068, .0074), (.0306, .0742, .0050, .0050)]
    loft(out, neck, body)
    loft(out, head, body)
    # Neon visor and chrome cheek plate on both sides.
    for sx in (-1, 1):
        visor = [(.0080, .0960), (.0225, .0885), (.0232, .0866), (.0086, .0937)]
        prism(out, visor, min(sx * .0090, sx * .0101), max(sx * .0090, sx * .0101), accent)
        cheek = [(.0030, .0845), (.0150, .0790), (.0185, .0822), (.0070, .0890)]
        prism(out, cheek, min(sx * .0093, sx * .0103), max(sx * .0093, sx * .0103), trim)
    # Swept-back ears.
    for sx in (-1, 1):
        ear = [(-.0060, .1000), (.0030, .1030), (-.0045, .1140), (-.0090, .1070)]
        bevelled_prism_x(out, ear, sx * .0050, .0017, .0005, body, trim)
    # Chrome crest fin down the back of the neck.
    fin = [(-.0060, .1035), (-.0125, .1010), (-.0205, .0890), (-.0248, .0700), (-.0252, .0480),
           (-.0228, .0300), (-.0178, .0300), (-.0185, .0480), (-.0180, .0700), (-.0145, .0860), (-.0085, .0960)]
    bevelled_prism(out, fin, .0024, .0007, trim)
    # Chrome collar plate where the neck meets the base.
    lathe(out, [(0, .0150, trim), (.0262, .0150, trim), (.0262, .0185, trim), (.0230, .0210, body), (0, .0210, body)])


def bevelled_prism_x(out, polygon, xc, half, bevel, m, edge=None):
    """bevelled_prism centred on x=xc."""
    local = []
    bevelled_prism(local, polygon, half, bevel, m, edge)
    transform(local, lambda p: (p[0] + xc, p[1], p[2]))
    out.extend(local)


def profile_radius(profile, z):
    pts = [(r, zz) for r, zz, _ in profile]
    best = 0.0
    for (r0, z0), (r1, z1) in zip(pts, pts[1:]):
        if min(z0, z1) <= z <= max(z0, z1) and z1 != z0:
            t = (z - z0) / (z1 - z0)
            best = max(best, r0 + (r1 - r0) * t)
    return best


def mitre_slash(out, profile, accent):
    """The bishop's diagonal cut: a thin neon plate tilted 38 degrees that
    pierces the head and shows as a glowing slash all around it."""
    tilt = math.radians(38)
    centre = (0.0, .0005, .0955)
    u = (1.0, 0.0, 0.0)
    v = (0.0, math.cos(tilt), math.sin(tilt))
    nrm = (0.0, -math.sin(tilt), math.cos(tilt))
    rim = []
    n = 24
    for i in range(n):
        a = math.tau * i / n
        dirv = [math.cos(a) * u[k] + math.sin(a) * v[k] for k in range(3)]
        lo, hi = 0.0, .03
        for _ in range(30):                  # bisect the surface crossing
            t = (lo + hi) / 2
            p = [centre[k] + dirv[k] * t for k in range(3)]
            if math.hypot(p[0], p[1]) < profile_radius(profile, p[2]):
                lo = t
            else:
                hi = t
        rim.append([centre[k] + dirv[k] * (lo + .0007) for k in range(3)])
    h = .0011
    top = [[p[k] + nrm[k] * h for k in range(3)] for p in rim]
    bot = [[p[k] - nrm[k] * h for k in range(3)] for p in rim]
    ct = [centre[k] + nrm[k] * h for k in range(3)]
    cb = [centre[k] - nrm[k] * h for k in range(3)]
    for i in range(n):
        j = (i + 1) % n
        tri(out, ct, top[i], top[j], accent)
        tri(out, cb, bot[j], bot[i], accent)
        quad(out, bot[i], bot[j], top[j], top[i], accent)


def tine(out, angle, r0, z0, r1, z1, m):
    """A slender crown tine: a tapered, chamfered blade leaning outwards."""
    def p(r, z, w, d):
        # w: tangential offset, d: radial offset
        ca, sa = math.cos(angle), math.sin(angle)
        return ((r + d) * ca - w * sa, (r + d) * sa + w * ca, z)
    w0, d0 = .0034, .0018
    base = [p(r0, z0, -w0, -d0), p(r0, z0, w0, -d0), p(r0, z0, w0, d0), p(r0, z0, -w0, d0)]
    mid_z = z0 + (z1 - z0) * .55
    mid_r = r0 + (r1 - r0) * .55
    mid = [p(mid_r, mid_z, -w0 * .8, -d0 * .8), p(mid_r, mid_z, w0 * .8, -d0 * .8),
           p(mid_r, mid_z, w0 * .8, d0 * .8), p(mid_r, mid_z, -w0 * .8, d0 * .8)]
    tip = p(r1, z1, 0, 0)
    local = []
    for i in range(4):
        j = (i + 1) % 4
        quad(local, base[i], base[j], mid[j], mid[i], m)
        tri(local, mid[i], mid[j], tip, m)
    quad(local, base[3], base[2], base[1], base[0], m)
    cx = sum(v[0] for v in base) / 4
    cy = sum(v[1] for v in base) / 4
    for f in local:
        c = [(f['a'][k] + f['b'][k] + f['c'][k]) / 3 for k in range(3)]
        mz = (z0 + z1) / 2
        orient([f], (c[0] - cx * (1 if c[2] < mz else 0) - (mid_r * math.cos(angle) if c[2] >= mz else 0) * 0,
                     c[1] - cy * (1 if c[2] < mz else 0), 0 if c[2] > z0 + 1e-6 else -1))
    out.extend(local)


# --------------------------------------------------------------------------
# Checkers
def checker_disc(body, trim, accent, z, top_detail=True):
    """A thick machined disc: chrome chamfers, glowing side groove, neon
    inlay ring and a shallow dish on top. Height .015."""
    prof = [(0, z, body), (.0300, z, trim), (.0320, z + .0020, body), (.0320, z + .0055, body),
            (.0303, z + .0055, accent), (.0303, z + .0088, body), (.0320, z + .0088, body),
            (.0320, z + .0125, trim), (.0295, z + .0150, trim)]
    if top_detail:
        prof += [(.0262, z + .0150, trim), (.0262, z + .0137, accent), (.0234, z + .0137, accent),
                 (.0234, z + .0144, body), (.0150, z + .0136, body), (0, z + .0132, body)]
    else:
        prof += [(0, z + .0150, body)]
    out = []
    lathe(out, prof, sides=40)
    return out


def checkers_piece(kind, side):
    body, trim, accent = SIDES[side]
    if kind == 'man':
        return clean(checker_disc(body, trim, accent, 0))
    out = checker_disc(body, trim, accent, 0, top_detail=False)
    out += checker_disc(body, trim, accent, .0150)
    # Raised crown emblem in neon, unmistakable from any angle.
    crown = [(-.0130, -.0070), (.0130, -.0070), (.0130, .0010), (.0150, .0085), (.0072, .0030),
             (.0, .0110), (-.0072, .0030), (-.0150, .0085), (-.0130, .0010)]
    emblem = []
    bevelled_prism(emblem, crown, .0019, .0006, accent, trim)
    # The prism is extruded along X in (y, z) space; lay it flat: (x, y, z) -> (y, z, x).
    transform(emblem, lambda p: (p[1], p[2], .0300 + p[0]))
    out += emblem
    return clean(out)


# --------------------------------------------------------------------------
# Connect Four
def connect4_disc(side):
    body, trim, core = DISCS[side]
    # Revolved around Z, then the axis is turned into -Y (front face at -Y).
    half = .0125
    face = [(.0500, half, trim), (.0440, half, body), (.0440, half - .0016, core), (.0395, half - .0016, core),
            (.0395, half, body), (.0300, half, trim), (.0270, half + .0010, body), (0, half + .0010, body)]
    prof = [(r, -z, m) for r, z, m in reversed(face)]
    prof = [(0, -(half + .0010), body)] + prof[1:]
    # Rebuild in bottom->top order with materials on the segment's start point.
    back = [(0, -(half + .0010), trim), (.0270, -(half + .0010), trim), (.0300, -half, body),
            (.0395, -half, core), (.0395, -half + .0016, core), (.0440, -half + .0016, body),
            (.0440, -half, trim), (.0500, -half, trim), (.0520, -half + .0020, body),
            (.0520, half - .0020, trim)]
    front = [(.0500, half, body), (.0440, half, core), (.0440, half - .0016, core),
             (.0395, half - .0016, body), (.0395, half, trim), (.0300, half, body),
             (.0270, half + .0010, body), (0, half + .0010, body)]
    out = []
    lathe(out, back + front, sides=40)
    transform(out, lambda p: (p[0], -p[2], p[1]))
    return clean(out)


def connect4_board():
    out = []
    n = 28
    plate = (.0170, .0270)          # |y| range of each grid plate
    face_m, inner_m, chamfer_m = 'cy:connect4_face', 'cy:graphite', 'cy:chrome'
    hole, lip = .0560, .0600         # aperture radius and outer chamfer radius
    x_min, x_max, z_min, z_max = -.49, .49, .025, .935

    def face_uv(x, z):
        return ((x + TOP_SPAN) / (2 * TOP_SPAN), (1.04 - z) / (2 * TOP_SPAN))

    for front in (True, False):
        s = -1 if front else 1
        y_out, y_in = s * plate[1], s * plate[0]
        y_mid = s * (plate[1] - .0035)
        for row in range(1, 7):
            for col in range(1, 8):
                cx, cz = (col - 4) * .14, (6.5 - row) * .14 + .04
                for i in range(n):
                    a, b = math.tau * i / n, math.tau * (i + 1) / n
                    ra = .07 / max(abs(math.cos(a)), abs(math.sin(a)))
                    rb = .07 / max(abs(math.cos(b)), abs(math.sin(b)))

                    def p(angle, r, y):
                        return (cx + r * math.cos(angle), y, cz + r * math.sin(angle))
                    # Outer face annulus (textured), chrome chamfer, lining, inner face.
                    pts = [p(a, ra, y_out), p(b, rb, y_out), p(b, lip, y_out), p(a, lip, y_out)]
                    uv = [face_uv(q[0], q[2]) for q in pts]
                    if not front:
                        pts.reverse()
                        uv.reverse()
                    quad(out, *pts, face_m, uv)
                    ch = [p(a, lip, y_out), p(b, lip, y_out), p(b, hole, y_mid), p(a, hole, y_mid)]
                    if not front:
                        ch.reverse()
                    quad(out, *ch, chamfer_m)
                    ln = [p(a, hole, y_mid), p(b, hole, y_mid), p(b, hole, y_in), p(a, hole, y_in)]
                    if not front:
                        ln.reverse()
                    quad(out, *ln, inner_m)
                    inn = [p(b, rb, y_in), p(a, ra, y_in), p(a, hole, y_in), p(b, hole, y_in)]
                    if not front:
                        inn.reverse()
                    quad(out, *inn, 'cy:void')
        # Top and bottom bands of the plate (textured), with their inner faces.
        for z0, z1 in ((z_min, .04), (.88, z_max)):
            pts = [(x_min, y_out, z0), (x_max, y_out, z0), (x_max, y_out, z1), (x_min, y_out, z1)]
            uv = [face_uv(q[0], q[2]) for q in pts]
            if not front:
                pts.reverse()
                uv.reverse()
            quad(out, *pts, face_m, uv)
            inner = [(x_max, y_in, z0), (x_min, y_in, z0), (x_min, y_in, z1), (x_max, y_in, z1)]
            if not front:
                inner.reverse()
            quad(out, *inner, 'cy:void')
        # Plate top edge (chrome) and bottom edge.
        lo, hi = sorted((y_out, y_in))
        bevel_box(out, x_min, x_max, lo, hi, z_max - .0001, z_max + .0045, chamfer_m, .0015, skip=('-z',))
    # Side pillars with inset neon strips, caps and feet.
    for sx in (-1, 1):
        x0, x1 = sorted((sx * .488, sx * .536))
        bevel_box(out, x0, x1, -.033, .033, .012, .962, 'cy:graphite', .004, trim='cy:chrome')
        xm = sx * .512
        for y0, y1 in ((-.0338, -.0326), (.0326, .0338)):
            bevel_box(out, xm - .0045, xm + .0045, y0, y1, .070, .880, 'cy:cyan', .0004)
        bevel_box(out, x0 - .002, x1 + .002, -.036, .036, .962, .976, 'cy:chrome', .003)
        bevel_box(out, x0 - .022, x1 + .022, -.150, .150, 0.0, .016, 'cy:graphite', .004, trim='cy:chrome')
        for y0, y1 in ((-.1515, -.1500), (.1500, .1515)):
            bevel_box(out, xm - .016, xm + .016, y0, y1, .005, .011, 'cy:cyan', .0003)
        bevel_box(out, x0 - .004, x1 + .004, -.040, .040, .016, .030, 'cy:carbon', .003, trim='cy:chrome')
    # Bottom rail under the plates.
    bevel_box(out, -.488, .488, -.030, .030, .004, .025, 'cy:carbon', .003, trim='cy:chrome')
    return clean(out)


# --------------------------------------------------------------------------
# Chess and checkers boards
def board(game):
    n = 8 if game == 'chess' else 10
    top = 'cy:' + game + '_top'
    accent = BOARD_ACCENT[game]
    out = []
    # Frame, chamfers, side groove and foot, swept around the field.
    prof = [
        (0, -.0360, 'cy:carbon'), (.5280, -.0360, 'cy:carbon'), (.5280, -.0320, 'cy:graphite'),
        (.5560, -.0320, 'cy:chrome'), (.5600, -.0280, 'cy:graphite'),
        (.5600, -.0215, 'cy:graphite'), (.5572, -.0215, accent), (.5572, -.0180, 'cy:graphite'),
        (.5600, -.0180, 'cy:graphite'), (.5600, .0015, 'cy:chrome'), (.5500, FRAME_TOP, top),
        (.5170, FRAME_TOP, 'cy:chrome'), (.5070, GROOVE, accent), (.5000, GROOVE, accent),
    ]
    sweep_square(out, prof)
    # Etched groove floor under the whole field.
    corners = [(-.5, -.5, GROOVE), (.5, -.5, GROOVE), (.5, .5, GROOVE), (-.5, .5, GROOVE)]
    quad(out, *corners, top, [top_uv(p) for p in corners])
    # Raised lacquer tiles with 45-degree bevels down to the grid.
    step = 1 / n
    for row in range(n):
        for col in range(n):
            x0, y0 = -.5 + col * step, -.5 + row * step
            outer = (x0 + .001, y0 + .001, x0 + step - .001, y0 + step - .001)
            inner = (outer[0] + .002, outer[1] + .002, outer[2] - .002, outer[3] - .002)
            ring_lo = [(outer[0], outer[1]), (outer[2], outer[1]), (outer[2], outer[3]), (outer[0], outer[3])]
            ring_hi = [(inner[0], inner[1]), (inner[2], inner[1]), (inner[2], inner[3]), (inner[0], inner[3])]
            hi = [(x, y, TILE_TOP) for x, y in ring_hi]
            quad(out, *hi, top, [top_uv(p) for p in hi])
            for i in range(4):
                j = (i + 1) % 4
                pts = [(*ring_lo[i], GROOVE), (*ring_lo[j], GROOVE), (*ring_hi[j], TILE_TOP), (*ring_hi[i], TILE_TOP)]
                quad(out, *pts, top, [top_uv(p) for p in pts])
    return clean(out)


def models():
    """Every model of the pack, by the names the client resolves."""
    result = {'chess_board': board('chess'), 'checkers_board': board('checkers'),
              'connect4_board': connect4_board()}
    for side in ('white', 'black'):
        for kind in ('pawn', 'rook', 'knight', 'bishop', 'queen', 'king'):
            result[f'chess_{side}_{kind}'] = chess_piece(kind, side)
    for side in ('white', 'black'):
        for kind in ('man', 'king'):
            result[f'checkers_{side}_{kind}'] = checkers_piece(kind, side)
    for side in ('white', 'black'):
        result[f'connect4_{side}_disc'] = connect4_disc(side)
    return result


def bounds(faces):
    pts = [f[k] for f in faces for k in ('a', 'b', 'c')]
    return [min(p[i] for p in pts) for i in range(3)], [max(p[i] for p in pts) for i in range(3)]


def check(all_models):
    """Invariants the client and the cooker rely on. Raises AssertionError."""
    for name, faces in all_models.items():
        assert faces, name
        groups = {}
        for f in faces:
            assert f['color'] in MATERIALS, (name, f['color'])
            assert all(math.isfinite(v) for k in ('a', 'b', 'c') for v in f[k]), name
            assert area2(f) > 1e-11, (name, 'degenerate triangle')
            if 'uv' in f:
                assert all(math.isfinite(v) for uv in f['uv'] for v in uv), name
            groups[f['color']] = groups.get(f['color'], 0) + 1
        # Unshared vertices: keep each material chunk under 16-bit indices.
        assert max(groups.values()) * 3 < 65535, (name, groups)
        lo, hi = bounds(faces)
        if name.startswith('chess_') and name != 'chess_board':
            kind = name.split('_', 2)[2]
            assert abs(lo[2]) < 1e-9 and abs(hi[2] - PIECE_HEIGHTS[kind]) < .0015, (name, hi[2])
            assert max(abs(lo[0]), abs(hi[0]), abs(lo[1]), abs(hi[1])) <= .0365, (name, lo, hi)
        elif name.startswith('checkers_') and name != 'checkers_board':
            kind = name.split('_', 2)[2]
            assert abs(lo[2]) < 1e-9 and abs(hi[2] - CHECKER_HEIGHTS[kind]) < .0012, (name, hi[2])
            assert max(abs(lo[0]), abs(hi[0]), abs(lo[1]), abs(hi[1])) <= .0325, (name, lo, hi)
        elif name.startswith('connect4_') and name != 'connect4_board':
            assert max(abs(lo[0]), abs(hi[0]), abs(lo[2]), abs(hi[2])) <= .0525, (name, lo, hi)
            assert hi[1] - lo[1] <= .0295 and abs(hi[1] + lo[1]) < 1e-9, (name, lo, hi)
        elif name in ('chess_board', 'checkers_board'):
            assert abs(lo[0] + .56) < 1e-9 and abs(hi[0] - .56) < 1e-9, (name, lo, hi)
            assert abs(lo[1] + .56) < 1e-9 and abs(hi[1] - .56) < 1e-9, (name, lo, hi)
            assert abs(lo[2] + .036) < 1e-9 and abs(hi[2] - FRAME_TOP) < 1e-9, (name, lo, hi)
        elif name == 'connect4_board':
            # Discs (|y| <= .0135) slide between the plates; the client draws
            # its column highlight at y=-.03, in front of the face.
            assert hi[2] < 1.0 and lo[2] == 0, (name, lo, hi)
    tops = [f for f in all_models['chess_board'] if f['color'] == 'cy:chess_top']
    assert max(max(f[k][2] for k in ('a', 'b', 'c')) for f in tops
               if max(abs(f[k][0]) for k in 'abc') <= .5 and max(abs(f[k][1]) for k in 'abc') <= .5) == TILE_TOP


# --------------------------------------------------------------------------
# Textures (NumPy + Pillow). Sources stay upright; the cooker flips them.
def _np():
    import numpy
    return numpy


def _srgb(hex_or_tuple):
    if isinstance(hex_or_tuple, str):
        h = hex_or_tuple.lstrip('#')
        return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return list(hex_or_tuple)


def _image(arr):
    np = _np()
    from PIL import Image
    rgb = (np.clip(arr, 0, 1) * 255 + .5).astype('uint8')
    alpha = np.full(rgb.shape[:2] + (1,), 255, 'uint8')
    return Image.fromarray(np.concatenate([rgb, alpha], axis=2), 'RGBA')


def _blend(base, mask, colour, strength=1.0):
    np = _np()
    m = np.clip(mask * strength, 0, 1)[..., None]
    return base * (1 - m) + np.array(colour, 'float32')[None, None, :] * m


def _smooth_band(dist, width, soft):
    """1 inside |dist| < width, falling to 0 over `soft` (metres)."""
    np = _np()
    return np.clip((width + soft - np.abs(dist)) / max(soft, 1e-9), 0, 1)


def _hash_noise(shape, seed, scale):
    """Deterministic value noise (tileable over the texture size)."""
    np = _np()
    rng = np.random.default_rng(seed)
    h, w = shape
    gh, gw = max(1, h // scale), max(1, w // scale)
    grid = rng.random((gh, gw)).astype('float32')
    ys = np.arange(h) / scale
    xs = np.arange(w) / scale
    y0 = np.floor(ys).astype(int) % gh
    x0 = np.floor(xs).astype(int) % gw
    fy = (ys - np.floor(ys))[:, None]
    fx = (xs - np.floor(xs))[None, :]
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    g00 = grid[y0][:, x0]
    g01 = grid[y0][:, (x0 + 1) % gw]
    g10 = grid[(y0 + 1) % gh][:, x0]
    g11 = grid[(y0 + 1) % gh][:, (x0 + 1) % gw]
    return (g00 * (1 - fx) + g01 * fx) * (1 - fy) + (g10 * (1 - fx) + g11 * fx) * fy


def _carbon(x, y, cell=.0036):
    """2x2 twill carbon weave intensity (0..1) at metric coordinates."""
    np = _np()
    cx = np.floor(x / cell).astype(int)
    cy = np.floor(y / cell).astype(int)
    fx = x / cell - cx
    fy = y / cell - cy
    horizontal = ((cx - cy) % 4) < 2
    tow = np.where(horizontal, np.sin(fy * math.pi), np.sin(fx * math.pi))
    # Each tow is darker at its ends where it dives under the crossing tow.
    along = np.where(horizontal, ((cx - cy) % 2 + fx) / 2, ((cx - cy) % 2 + fy) / 2)
    return tow ** 1.6 * (.75 + .25 * np.sin(along * math.pi))


def board_top_texture(game, size=1024, ss=2):
    np = _np()
    from PIL import Image
    n = 8 if game == 'chess' else 10
    accent = _srgb('#3DF2FF' if game == 'chess' else '#FFB21E')
    white_mark, black_mark = _srgb('#3DF2FF'), _srgb('#FF3BB8')
    S = size * ss
    px = (np.arange(S, dtype='float32') + .5) / S
    X = (px * 2 * TOP_SPAN - TOP_SPAN)[None, :].repeat(S, 0)
    Y = (TOP_SPAN - px * 2 * TOP_SPAN)[:, None].repeat(S, 1)
    img = np.zeros((S, S, 3), 'float32')
    # Frame top: carbon twill with a cool sheen.
    weave = _carbon(X + 1, Y + 1)
    frame = np.array(_srgb('#0A0C11'), 'float32') + weave[..., None] * np.array(_srgb('#252A35'), 'float32')
    img[:] = frame
    d = np.maximum(np.abs(X), np.abs(Y))
    # Fine pinstripes on the frame: chrome inner catch-light, accent outer.
    img = _blend(img, _smooth_band(d - .5195, .0005, .0004), _srgb('#C9D3DE'), .55)
    img = _blend(img, _smooth_band(d - .5455, .0004, .0004), accent, .55)
    # Rank/file ticks on all four sides (no notation: the layout is abstract).
    step = 1 / n
    centres = np.array([-.5 + (i + .5) * step for i in range(n)], 'float32')
    for axis_val, along in ((X, Y), (Y, X)):
        nearest = centres[np.clip(np.round((axis_val + .5) / step - .5).astype(int), 0, n - 1)]
        tick = _smooth_band(axis_val - nearest, .0009, .0004) * _smooth_band(np.abs(along) - .5300, .0045, .0004)
        img = _blend(img, tick, _srgb('#AEB9C6'), .65)
    # Home-side chevrons: cyan on white's edge (+Y), magenta on black's (-Y).
    for sign, colour in ((1, white_mark), (-1, black_mark)):
        yy = (Y * sign - .5335)
        for k in (-1, 0, 1):
            cx = X - k * .016
            chevron = _smooth_band(yy + np.abs(cx) * .55 - .002, .0011, .0004) * (np.abs(cx) < .0072)
            img = _blend(img, chevron, colour, .95 if k == 0 else .55)
    # Corner brackets on the frame.
    for sx in (-1, 1):
        for sy in (-1, 1):
            lx = _smooth_band(sx * X - .5250, .0007, .0004) * (sy * Y > .468) * (sy * Y < .5255)
            ly = _smooth_band(sy * Y - .5250, .0007, .0004) * (sx * X > .468) * (sx * X < .5255)
            img = _blend(img, np.maximum(lx, ly), _srgb('#E6ECF2'), .7)
    # Playing field.
    field = (np.abs(X) <= .5) & (np.abs(Y) <= .5)
    col = np.clip(np.floor((X + .5) / step), 0, n - 1)
    row = np.clip(np.floor((Y + .5) / step), 0, n - 1)
    dark = ((row + col) % 2) == 1
    fx = (X + .5) - col * step
    fy = (Y + .5) - row * step
    ex = np.minimum(fx, step - fx)
    ey = np.minimum(fy, step - fy)
    e = np.minimum(ex, ey)
    light_c = np.array(_srgb('#5D6676'), 'float32')
    dark_c = np.array(_srgb('#191E29'), 'float32')
    # Lacquer sheen: each tile slightly brighter towards its +Y/-X corner.
    sheen = (1 + .10 * ((step - fx) / step * .5 + fy / step * .5 - .5))[..., None]
    sq = np.where(dark[..., None], dark_c[None, None, :], light_c[None, None, :]) * sheen
    # Composite micro texture: faint diagonal hatching on the dark squares,
    # long brushed streaks on the light ones.
    hatch = (np.sin((X + Y) * 2 * math.pi / .0024) > .6).astype('float32')
    sq = sq * (1 + np.where(dark, .18 * hatch, 0)[..., None])
    streak = _hash_noise((S, S), 31 if game == 'chess' else 37, 2)[:, :1].repeat(S, 1)
    sq = sq * (1 + np.where(dark, 0, .06 * (streak - .5))[..., None])
    # Bevel catch-light (geometry bevel spans .001-.003 from the line).
    sq = sq * (1 + .25 * ((e > .001) & (e < .0032)))[..., None]
    # Holographic inner outline and corner brackets on the dark squares
    # (the playable ones in checkers), pale outline on the light squares.
    outline = _smooth_band(e - .0052, .0006, .0004)
    corner = (ex < .016) & (ey < .016)
    holo = outline * np.where(dark, np.where(corner, .85, .30), np.where(corner, .22, .08))
    sq = _blend(sq, holo, accent if game == 'checkers' else _srgb('#7CF6FF'), 1.0)
    # Etched neon grid in the groove, with bright nodes at intersections.
    groove = _smooth_band(e, .0009, .0004)
    sq = _blend(sq, groove, np.array(accent) * .55, 1.0)
    node = _smooth_band(np.maximum(ex, ey), .0024, .0006)
    sq = _blend(sq, node, [min(1, c * .6 + .5) for c in accent], .9)
    img = np.where(field[..., None], sq, img)
    # Neon channel around the field (geometry .500-.507 is lit paint anyway).
    image = _image(img)
    return image.reduce(ss) if ss > 1 else image


def connect4_face_texture(size=1024, ss=2):
    np = _np()
    S = size * ss
    px = (np.arange(S, dtype='float32') + .5) / S
    X = (px * 2 * TOP_SPAN - TOP_SPAN)[None, :].repeat(S, 0)
    Z = (1.04 - px * 2 * TOP_SPAN)[:, None].repeat(S, 1)
    # Vertically brushed dark gunmetal.
    streak = _hash_noise((S, S), 77, 3)[:1, :].repeat(S, 0)
    img = np.array(_srgb('#434955'), 'float32')[None, None, :] * (1 + .12 * (streak - .5))[..., None]
    img = img.astype('float32')
    cyan, amber = _srgb('#3DF2FF'), _srgb('#FFB21E')
    # Etched diamond lattice between the apertures, very faint.
    lattice = _smooth_band(np.sin((X + Z) * math.pi / .035) * .035 / math.pi, .0005, .0004)
    lattice = np.maximum(lattice, _smooth_band(np.sin((X - Z) * math.pi / .035) * .035 / math.pi, .0005, .0004))
    img = _blend(img, lattice, _srgb('#4A515E'), .5)
    best = np.full(X.shape, 1.0, 'float32')
    for row in range(1, 7):
        for col in range(1, 8):
            cx, cz = (col - 4) * .14, (6.5 - row) * .14 + .04
            best = np.minimum(best, np.hypot(X - cx, Z - cz))
    # Dark recess shadow outside the chrome lip, then a thin neon ring.
    img = img * (1 - .45 * _smooth_band(best - .0615, .0015, .004))[..., None]
    img = _blend(img, _smooth_band(best - .0650, .0009, .0005), cyan, .95)
    # Rivet studs where four cells meet.
    for col in range(8):
        for row in range(7):
            sx, sz = -.49 + col * .14, .04 + row * .14
            r = np.hypot(X - sx, Z - sz)
            img = _blend(img, _smooth_band(r, .0035, .0008), _srgb('#B8C2CE'), .8)
            img = _blend(img, _smooth_band(r, .0013, .0005), _srgb('#20242C'), .8)
    # Column chevrons in the top band.
    for col in range(1, 8):
        cx = (col - 4) * .14
        chevron = _smooth_band((Z - .9075) - np.abs(X - cx) * .7, .0016, .0005) * (np.abs(X - cx) < .016)
        img = _blend(img, chevron, cyan, .95)
    img = _blend(img, _smooth_band(Z - .925, .0006, .0004) * (np.abs(X) < .49), _srgb('#C9D3DE'), .5)
    # Amber/black safety hatching in the bottom band.
    band = (Z > .027) & (Z < .038)
    hatch = (np.floor((X - Z) / .012) % 2 == 0)
    img = np.where((band & hatch)[..., None], np.array(amber, 'float32') * .85, img)
    img = np.where((band & ~hatch)[..., None], np.array(_srgb('#121419'), 'float32'), img)
    image = _image(img)
    return image.reduce(ss) if ss > 1 else image


def small_textures():
    np = _np()
    S = 256
    u = (np.arange(S, dtype='float32') + .5) / S
    U = u[None, :].repeat(S, 0)
    V = u[:, None].repeat(S, 1)
    result = {}
    # Pearl lacquer: cool white with a soft pink/cyan shimmer around the piece.
    shimmer = np.sin(U * math.tau * 2 + np.sin(V * math.tau) * 1.2)
    base = np.array(_srgb('#E7EAF0'), 'float32')
    pink = np.array(_srgb('#F6E6EF'), 'float32')
    ice = np.array(_srgb('#DDEFF6'), 'float32')
    t = (shimmer * .5 + .5)[..., None]
    pearl = base * .8 + (pink * t + ice * (1 - t)) * .2
    pearl = pearl * (1 + .015 * (_hash_noise((S, S), 5, 8)[..., None] - .5))
    result['cy_pearl'] = _image(pearl)
    # Onyx composite: near black with fine lathe rings (horizontal in UV).
    rings = .5 + .5 * np.sin(V * math.tau * 24 + _hash_noise((S, S), 9, 16) * 2)
    onyx = np.array(_srgb('#0D0E12'), 'float32') * (1 + .35 * rings[..., None])
    result['cy_onyx'] = _image(onyx)
    # Brushed gunmetal: streaks along U, tileable.
    streak = _hash_noise((S, S), 13, 1)[:, :1].repeat(S, 1) * .6 + _hash_noise((S, S), 17, 4) * .4
    brushed = np.array(_srgb('#4D525C'), 'float32') * (1 + .22 * (streak[..., None] - .5))
    result['cy_brushed'] = _image(brushed)
    # Carbon twill, tileable: 256 px = 64 cells.
    X = U * .2304
    Y = V * .2304
    weave = _carbon(X, Y, .0036)
    carbon = np.array(_srgb('#0B0D12'), 'float32') + weave[..., None] * np.array(_srgb('#2A303C'), 'float32')
    result['cy_carbon'] = _image(carbon)
    return result


def textures():
    """All pack textures as upright RGBA PIL images, by texture name."""
    result = {'cy_chess_top': board_top_texture('chess'),
              'cy_checkers_top': board_top_texture('checkers'),
              'cy_connect4_face': connect4_face_texture()}
    result.update(small_textures())
    for name, image in result.items():
        assert image.size == TEXTURE_SIZES[name], (name, image.size)
    return result


if __name__ == '__main__':
    built = models()
    check(built)
    for name, faces in built.items():
        lo, hi = bounds(faces)
        print(f'{name:24s} {len(faces):6d} tris  z {lo[2]:+.4f}..{hi[2]:+.4f}  xy {max(map(abs, lo[:2] + hi[:2])):.4f}')
    print('total', sum(map(len, built.values())))
