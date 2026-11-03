#!/usr/bin/env python3
"""Shared art kit for the roulette and Fortune Wheel prop builders.

Night City high-roller style: gunmetal and black-chrome bodies, smoked glass,
carbon weave, a dark textured composite instead of felt, thin neon accents.
Everything is original and generated here:

- an original geometric stroke typeface (chamfered, monoline) drawn with
  Pillow, so labels need no font file and stay reproducible;
- seamless procedural textures (carbon twill, brushed gunmetal, composite);
- geometry helpers that fix the winding from an explicit outward direction
  (the engine culls back faces) and a profile sweep used for lathes, rails and
  the table body;
- cooker helpers: metal_base material instances (with optional emission),
  CBitmapTexture schemas with full mip chains, explicit-UV GLB patching.

Emission uses the native metal_base parameters Emissive / EmissiveEV /
EmissiveColor (the same ones the dop-tests lab vehicle cooked). The look of
the glow in game still needs a live client check; EV values live in EV below.
"""
import base64, copy, hashlib, json, math, random, struct
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

WHITE_TEX = 'engine\\textures\\editor\\white.xbm'
BASE_MATERIAL = 'engine\\materials\\metal_base.remt'
# Emission strengths (EV) in one place: neon rings, printed lines, lamps.
EV = {'neon': 3.0, 'lines': 2.0, 'lamp': 3.5, 'soft': 1.2, 'sign': 2.5}

# ------------------------------------------------------------------ typeface
# Glyphs on a 4 x 6 grid (y down), chamfered corners, monoline strokes.
_C = 1.0  # chamfer
GLYPHS = {
    '0': [[(1, 0), (3, 0), (4, 1), (4, 5), (3, 6), (1, 6), (0, 5), (0, 1), (1, 0)]],
    '1': [[(0, 1.2), (1.4, 0), (1.4, 6)]],
    '2': [[(0, 1), (1, 0), (3, 0), (4, 1), (4, 2.2), (3, 3), (1, 3), (0, 3.8), (0, 6), (4, 6)]],
    '3': [[(0, 1), (1, 0), (3, 0), (4, 1), (4, 2.2), (3.2, 3), (4, 3.8), (4, 5), (3, 6), (1, 6), (0, 5)], [(1.4, 3), (3.2, 3)]],
    '4': [[(3, 6), (3, 0), (0, 4.1), (0, 4.4), (4, 4.4)]],
    '5': [[(4, 0), (0, 0), (0, 2.7), (3, 2.7), (4, 3.6), (4, 5), (3, 6), (1, 6), (0, 5)]],
    '6': [[(3.8, 0), (1, 0), (0, 1), (0, 5), (1, 6), (3, 6), (4, 5), (4, 3.7), (3, 2.8), (0, 2.8)]],
    '7': [[(0, 0), (4, 0), (4, 1.2), (1.6, 6)]],
    '8': [[(1, 2.9), (0, 2), (0, 1), (1, 0), (3, 0), (4, 1), (4, 2), (3, 2.9), (1, 2.9), (0, 3.9), (0, 5), (1, 6), (3, 6), (4, 5), (4, 3.9), (3, 2.9)]],
    '9': [[(.2, 6), (3, 6), (4, 5), (4, 1), (3, 0), (1, 0), (0, 1), (0, 2.3), (.9, 3.2), (4, 3.2)]],
    'x': [[(.4, 2.4), (3.2, 6)], [(3.2, 2.4), (.4, 6)]],
    '-': [[(.6, 3), (3, 3)]],
    ':': [[(.3, 1.7), (.3, 2.3)], [(.3, 4.3), (.3, 4.9)]],
    '.': [[(.3, 5.4), (.3, 6)]],
    '/': [[(0, 6), (3, 0)]],
    '+': [[(0, 3), (3.2, 3)], [(1.6, 1.4), (1.6, 4.6)]],
    'A': [[(0, 6), (0, 1), (1, 0), (3, 0), (4, 1), (4, 6)], [(0, 3.5), (4, 3.5)]],
    'B': [[(0, 2.9), (3, 2.9), (4, 2), (4, 1), (3, 0), (0, 0), (0, 6), (3, 6), (4, 5), (4, 3.8), (3, 2.9)]],
    'C': [[(4, 1), (3, 0), (1, 0), (0, 1), (0, 5), (1, 6), (3, 6), (4, 5)]],
    'D': [[(0, 0), (3, 0), (4, 1), (4, 5), (3, 6), (0, 6), (0, 0)]],
    'E': [[(4, 0), (0, 0), (0, 6), (4, 6)], [(0, 3), (3, 3)]],
    'F': [[(4, 0), (0, 0), (0, 6)], [(0, 3), (3, 3)]],
    'G': [[(4, 1), (3, 0), (1, 0), (0, 1), (0, 5), (1, 6), (3, 6), (4, 5), (4, 3.3), (2.2, 3.3)]],
    'H': [[(0, 0), (0, 6)], [(4, 0), (4, 6)], [(0, 3), (4, 3)]],
    'I': [[(0, 0), (0, 6)]],
    'J': [[(4, 0), (4, 5), (3, 6), (1, 6), (0, 5)]],
    'K': [[(0, 0), (0, 6)], [(4, 0), (1.2, 3), (0, 3)], [(1.2, 3), (4, 6)]],
    'L': [[(0, 0), (0, 6), (4, 6)]],
    'M': [[(0, 6), (0, 0), (2.3, 2.6), (4.6, 0), (4.6, 6)]],
    'N': [[(0, 6), (0, 0), (4, 6), (4, 0)]],
    'O': [[(1, 0), (3, 0), (4, 1), (4, 5), (3, 6), (1, 6), (0, 5), (0, 1), (1, 0)]],
    'P': [[(0, 6), (0, 0), (3, 0), (4, 1), (4, 2.4), (3, 3.4), (0, 3.4)]],
    'Q': [[(1, 0), (3, 0), (4, 1), (4, 5), (3, 6), (1, 6), (0, 5), (0, 1), (1, 0)], [(2.6, 4.6), (4.2, 6.2)]],
    'R': [[(0, 6), (0, 0), (3, 0), (4, 1), (4, 2.4), (3, 3.4), (0, 3.4)], [(2.4, 3.4), (4, 6)]],
    'S': [[(4, 1), (3, 0), (1, 0), (0, 1), (0, 2.1), (1, 3), (3, 3), (4, 3.9), (4, 5), (3, 6), (1, 6), (0, 5)]],
    'T': [[(0, 0), (4, 0)], [(2, 0), (2, 6)]],
    'U': [[(0, 0), (0, 5), (1, 6), (3, 6), (4, 5), (4, 0)]],
    'V': [[(0, 0), (2, 6), (4, 0)]],
    'W': [[(0, 0), (.9, 6), (2.3, 2.6), (3.7, 6), (4.6, 0)]],
    'X': [[(0, 0), (4, 6)], [(4, 0), (0, 6)]],
    'Y': [[(0, 0), (2, 3), (4, 0)], [(2, 3), (2, 6)]],
    'Z': [[(0, 0), (4, 0), (0, 6), (4, 6)]],
    ' ': [],
}
ADVANCE = {'1': 1.4, 'I': 0, ' ': 2.2, ':': .6, '.': .6, 'x': 3.6, 'M': 4.6, 'W': 4.6, '-': 3.6, '/': 3, '+': 3.2}


def text_mask(text, height, stroke=.13, tracking=1.25, ss=4):
    """Monochrome 'L' mask of `text`, cap height `height` px (strokes included)."""
    u = height * ss / (6 + 6 * stroke)  # px per grid unit
    w = stroke * height * ss
    widths = [ADVANCE.get(ch, 4) for ch in text]
    total = sum(widths) + tracking * max(0, len(text) - 1)
    pad = w
    im = Image.new('L', (max(1, int(math.ceil(total * u + 2 * pad))), int(math.ceil(6 * u + 2 * pad))), 0)
    d = ImageDraw.Draw(im)
    x = pad
    for ch, cw in zip(text, widths):
        for line in GLYPHS.get(ch, GLYPHS['0']):
            pts = [(x + px * u, pad + py * u) for px, py in line]
            d.line(pts, fill=255, width=max(1, int(round(w))), joint='curve')
            for p in (pts[0], pts[-1]):  # round caps keep stroke ends clean
                r = w / 2
                d.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=255)
        x += (cw + tracking) * u
    return im.resize((max(1, im.width // ss), max(1, im.height // ss)), Image.Resampling.LANCZOS)


def draw_text(im, text, center, height, color, angle=0., stroke=.13, tracking=1.25, glow=None):
    """Composite text centred at `center`, turned `angle` degrees clockwise.
    glow=(rgb, radius_px, strength) adds a soft halo under the strokes."""
    mask = text_mask(text, height, stroke, tracking)
    if angle:
        mask = mask.rotate(-angle, resample=Image.Resampling.BICUBIC, expand=True)
    x, y = round(center[0] - mask.width / 2), round(center[1] - mask.height / 2)
    if glow:
        rgb, radius, strength = glow
        m = Image.new('L', (mask.width + 4 * radius, mask.height + 4 * radius), 0)
        m.paste(mask, (2 * radius, 2 * radius))
        halo = m.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: min(255, int(v * strength)))
        layer = Image.new('RGBA', halo.size, tuple(rgb) + (0,)); layer.putalpha(halo)
        im.alpha_composite(layer, (x - 2 * radius, y - 2 * radius))
    layer = Image.new('RGBA', mask.size, tuple(color[:3]) + (0,)); layer.putalpha(mask)
    im.alpha_composite(layer, (x, y))
    return mask.size


def glow_line(im, draw_fn, rgb, radius, strength=1.6, core=None):
    """Draw a shape twice: blurred halo then a crisp core. draw_fn(ImageDraw, fill)."""
    m = Image.new('L', im.size, 0); draw_fn(ImageDraw.Draw(m), 255)
    halo = m.filter(ImageFilter.GaussianBlur(radius)).point(lambda v: min(255, int(v * strength)))
    layer = Image.new('RGBA', im.size, tuple(rgb) + (0,)); layer.putalpha(halo); im.alpha_composite(layer)
    layer = Image.new('RGBA', im.size, tuple(core or rgb) + (0,)); layer.putalpha(m); im.alpha_composite(layer)


# ------------------------------------------------------------------ textures
def _periodic_noise(size, cells, seed):
    rng = np.random.default_rng(seed)
    g = rng.random((cells, cells))
    # Wrap-around bilinear upsample keeps the tile seamless.
    t = np.arange(size) * cells / size
    i0 = np.floor(t).astype(int); f = t - i0; i1 = (i0 + 1) % cells
    f = f * f * (3 - 2 * f)
    rows = g[i0][:, i0] * (1 - f)[None, :] + g[i0][:, i1] * f[None, :]
    rows2 = g[i1][:, i0] * (1 - f)[None, :] + g[i1][:, i1] * f[None, :]
    return rows * (1 - f)[:, None] + rows2 * f[:, None]


def carbon_weave(size=256, tows=8):
    """2x2 twill carbon fibre: each tow shaded like a flattened cylinder."""
    s = size // tows
    y, x = np.mgrid[0:size, 0:size]
    i, j = x // s, y // s
    fx, fy = (x % s + .5) / s, (y % s + .5) / s
    horizontal = ((i - j) % 4) < 2
    across = np.where(horizontal, fy, fx)
    along = np.where(horizontal, fx, fy)
    shade = .55 + .45 * np.sin(across * math.pi) ** .8
    shade *= .9 + .1 * np.cos(along * math.pi * 2)
    rng = np.random.default_rng(77)
    fibre = rng.random((size, size))
    fibre = np.where(horizontal, np.roll(fibre, 0, 1), fibre)
    streak = np.where(horizontal, fibre.mean(1)[:, None] * np.ones((1, size)), fibre.mean(0)[None, :] * np.ones((size, 1)))
    v = shade * (.92 + .16 * streak)
    base = np.array([17, 18, 21]); hi = np.array([58, 61, 68])
    rgb = base + (hi - base) * np.clip(v, 0, 1)[..., None] ** 1.6
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert('RGBA')


def brushed_metal(size=256, color=(78, 82, 90), seed=5):
    """Seamless horizontal brushing (row noise smoothed along X, wrapped)."""
    rng = np.random.default_rng(seed)
    a = rng.normal(0, 1, (size, size))
    k = 24
    c = np.cumsum(np.concatenate([a[:, -k:], a, a[:, :k]], 1), 1)
    a = (c[:, 2 * k:] - c[:, :-2 * k]) / (2 * k)
    a = a / a.std()
    rows = rng.normal(0, 1, (size, 1))
    v = 1 + .045 * a + .035 * rows + .03 * (_periodic_noise(size, 4, seed + 1) - .5)
    rgb = np.array(color)[None, None] * v[..., None]
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert('RGBA')


def composite(size=512, color=(24, 25, 30), seed=9, hexes=16):
    """Dark textured composite: micro hex emboss, mottling and fine speckle."""
    y, x = np.mgrid[0:size, 0:size].astype(float)
    cw = size / hexes; rh = size / (hexes * 1.0)
    # Hex grid as distance to the nearest of two offset lattices (periodic).
    def lattice(ox, oy):
        gx = ((x - ox) % cw) - cw / 2; gy = ((y - oy) % (2 * rh)) - rh
        return np.hypot(gx, gy * .866)
    d = np.minimum(lattice(0, 0), lattice(cw / 2, rh))
    rim = np.clip((d - cw * .36) / (cw * .08), 0, 1)
    mott = _periodic_noise(size, 8, seed)
    rng = np.random.default_rng(seed)
    speck = rng.random((size, size))
    v = .92 + .10 * (mott - .5) - .10 * rim + .06 * (speck - .5)
    rgb = np.array(color)[None, None] * v[..., None]
    return Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).convert('RGBA')


# ------------------------------------------------------------------ geometry
def sub(a, b): return [a[i] - b[i] for i in range(3)]
def cross(a, b): return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
def dot(a, b): return sum(a[i] * b[i] for i in range(3))


def tri(out, a, b, c, color, uv=None, facing=None):
    a, b, c = list(a), list(b), list(c)
    n = cross(sub(b, a), sub(c, a))
    if dot(n, n) < 1e-22:
        return
    if facing is not None and dot(n, facing) < 0:
        b, c = c, b
        if uv is not None: uv = [uv[0], uv[2], uv[1]]
    f = {'a': a, 'b': b, 'c': c, 'color': color}
    if uv is not None: f['uv'] = [list(x) for x in uv]
    out.append(f)


def quad(out, p, color, facing, uv=None):
    tri(out, p[0], p[1], p[2], color, None if uv is None else [uv[0], uv[1], uv[2]], facing)
    tri(out, p[0], p[2], p[3], color, None if uv is None else [uv[0], uv[2], uv[3]], facing)


def box(out, center, size, color, top=True, bottom=True):
    x, y, z = center; sx, sy, sz = (v / 2 for v in size)
    P = lambda a, b, c: [x + a * sx, y + b * sy, z + c * sz]
    sides = [((1, 0, 0), [P(1, -1, -1), P(1, 1, -1), P(1, 1, 1), P(1, -1, 1)]),
             ((-1, 0, 0), [P(-1, -1, -1), P(-1, 1, -1), P(-1, 1, 1), P(-1, -1, 1)]),
             ((0, 1, 0), [P(-1, 1, -1), P(1, 1, -1), P(1, 1, 1), P(-1, 1, 1)]),
             ((0, -1, 0), [P(-1, -1, -1), P(1, -1, -1), P(1, -1, 1), P(-1, -1, 1)])]
    if top: sides.append(((0, 0, 1), [P(-1, -1, 1), P(1, -1, 1), P(1, 1, 1), P(-1, 1, 1)]))
    if bottom: sides.append(((0, 0, -1), [P(-1, -1, -1), P(1, -1, -1), P(1, 1, -1), P(-1, 1, -1)]))
    for n, pts in sides: quad(out, pts, color, n)


def sweep(out, path, normals, profile, color, closed=True, colors=None, uvfun=None):
    """Sweep a profile [(o,z)] along a path: vertex = path[k] + o*normals[k].
    o is the outward offset (for a lathe: the radius, path all zeros). The
    profile is listed with the solid on the RIGHT of the walking direction in
    the (o,z) plane (top faces walk outward, outer walls walk down); that
    defines the outward normal and the winding. colors(k,j) may override the
    colour per path segment k / profile segment j; uvfun(point) gives UVs."""
    n = len(path)
    segs = range(n if closed else n - 1)
    for j in range(len(profile) - 1):
        (o0, z0), (o1, z1) = profile[j], profile[j + 1]
        no, nz = -(z1 - z0), (o1 - o0)
        for k in segs:
            k1 = (k + 1) % n
            nx = (normals[k][0] + normals[k1][0]) / 2; ny = (normals[k][1] + normals[k1][1]) / 2
            facing = [nx * no, ny * no, nz]
            p = [[path[k][0] + o0 * normals[k][0], path[k][1] + o0 * normals[k][1], z0],
                 [path[k1][0] + o0 * normals[k1][0], path[k1][1] + o0 * normals[k1][1], z0],
                 [path[k1][0] + o1 * normals[k1][0], path[k1][1] + o1 * normals[k1][1], z1],
                 [path[k][0] + o1 * normals[k][0], path[k][1] + o1 * normals[k][1], z1]]
            c = colors(k, j) if colors else color
            uv = [uvfun(q) for q in p] if uvfun else None
            if abs(o0) < 1e-12 and path[k] == path[k1]:  # lathe apex
                tri(out, p[0], p[2], p[3], c, None if uv is None else [uv[0], uv[2], uv[3]], facing)
            elif abs(o1) < 1e-12 and path[k] == path[k1]:
                tri(out, p[0], p[1], p[2], c, None if uv is None else uv[:3], facing)
            else:
                quad(out, p, c, facing, uv)


def circle(sides, start=0.):
    dirs = [(math.cos(start + k * math.tau / sides), math.sin(start + k * math.tau / sides)) for k in range(sides)]
    return [(0., 0.)] * sides, dirs


def lathe(out, profile, color, sides=96, center=(0, 0), start=0., colors=None, uvfun=None):
    """Revolve [(r,z)] about the vertical axis through `center` (solid on the right)."""
    path, dirs = circle(sides, start)
    path = [(center[0], center[1])] * sides
    sweep(out, path, dirs, profile, color, colors=colors, uvfun=uvfun)


def disc(out, center, r, z, color, sides=64, up=True, uvfun=None):
    for k in range(sides):
        a, b = k * math.tau / sides, (k + 1) * math.tau / sides
        pts = [[center[0], center[1], z], [center[0] + r * math.cos(a), center[1] + r * math.sin(a), z], [center[0] + r * math.cos(b), center[1] + r * math.sin(b), z]]
        tri(out, *pts, color, [uvfun(p) for p in pts] if uvfun else None, (0, 0, 1 if up else -1))


def outline_normals(path):
    """Outward miter normals of a closed CCW polygon (scaled so offsets stay parallel)."""
    n = len(path); out = []
    for k in range(n):
        p0, p1, p2 = path[k - 1], path[k], path[(k + 1) % n]
        e0 = (p1[0] - p0[0], p1[1] - p0[1]); e1 = (p2[0] - p1[0], p2[1] - p1[1])
        n0 = (e0[1], -e0[0]); n1 = (e1[1], -e1[0])
        l0 = math.hypot(*n0); l1 = math.hypot(*n1)
        n0 = (n0[0] / l0, n0[1] / l0); n1 = (n1[0] / l1, n1[1] / l1)
        m = (n0[0] + n1[0], n0[1] + n1[1]); lm = math.hypot(*m); m = (m[0] / lm, m[1] / lm)
        s = 1 / max(.2, m[0] * n0[0] + m[1] * n0[1])
        out.append((m[0] * s, m[1] * s))
    return out


def fan(out, path, z, color, up=True, uvfun=None):
    """Cap a convex polygon at height z."""
    c = (sum(p[0] for p in path) / len(path), sum(p[1] for p in path) / len(path))
    for k in range(len(path)):
        p, q = path[k], path[(k + 1) % len(path)]
        pts = [[c[0], c[1], z], [p[0], p[1], z], [q[0], q[1], z]]
        tri(out, *pts, color, [uvfun(v) for v in pts] if uvfun else None, (0, 0, 1 if up else -1))


def transform(faces, fn):
    out = []
    for f in faces:
        n = dict(f)
        for k in ('a', 'b', 'c'): n[k] = list(fn(f[k]))
        out.append(n)
    return out


def rotate_z(faces, degrees, origin=(0, 0)):
    a = math.radians(degrees); c, s = math.cos(a), math.sin(a)
    return transform(faces, lambda p: (origin[0] + (p[0] - origin[0]) * c - (p[1] - origin[1]) * s,
                                       origin[1] + (p[0] - origin[0]) * s + (p[1] - origin[1]) * c, p[2]))


def translate(faces, d):
    return transform(faces, lambda p: (p[0] + d[0], p[1] + d[1], p[2] + d[2]))


# ------------------------------------------------------------------ materials
class Spec:
    """One material: optional base texture (pack texture name) times tint,
    roughness/metalness, optional emission (rgb, EV key or value) masked by an
    optional pack texture (white when None)."""
    def __init__(self, tex=None, tint=(255, 255, 255), rough=.5, metal=0., emit=None, emit_tex=None):
        self.tex, self.tint, self.rough, self.metal, self.emit, self.emit_tex = tex, tint, rough, metal, emit, emit_tex

    def ev(self):
        return EV.get(self.emit[1], self.emit[1]) if self.emit else None


def cook_material(spec, depot):
    t = lambda name: depot + '\\textures\\' + name + '.xbm' if name else WHITE_TEX
    emissive = (t(spec.emit_tex), spec.emit[0], spec.ev()) if spec.emit else None
    return material(t(spec.tex), spec.tint, spec.rough, spec.metal, emissive)


def preview_material(spec, images):
    import wheel_tables_preview as pv
    from PIL import ImageChops
    if spec.tex:
        img = images[spec.tex].convert('RGB')
        if spec.tint != (255, 255, 255):
            img = ImageChops.multiply(img, Image.new('RGB', img.size, spec.tint))
        base = img
    else:
        base = pv.srgb(spec.tint)
    emit = None
    if spec.emit:
        k = 2 ** (spec.ev() - 1.5)
        emit = tuple(v * k for v in pv.srgb(spec.emit[0]))
    return pv.Mat(base, spec.metal, spec.rough, emit, images[spec.emit_tex] if spec.emit_tex else None)


def depot_dependencies(specs):
    deps = {BASE_MATERIAL}
    if any(not s.tex or (s.emit and not s.emit_tex) for s in specs): deps.add(WHITE_TEX)
    return sorted(deps)


# ------------------------------------------------------------------ cooker
def cn(value): return {'$type': 'CName', '$storage': 'string', '$value': value}
def ref(value): return {'DepotPath': {'$type': 'ResourcePath', '$storage': 'string', '$value': value}, 'Flags': 'Default'}
def _v(name, typ, value): return {'$type': typ, name: value}


def material(texture=WHITE_TEX, tint=(255, 255, 255), rough=.5, metal=0., emissive=None):
    """metal_base instance. tint is sRGB 0-255 (stored linear-ish as the existing
    packs do: a straight 0-1 scale). emissive=(texture, (r,g,b), ev)."""
    c = [v / 255 for v in tint]
    values = [_v('BaseColor', 'rRef:ITexture', ref(texture)),
              _v('BaseColorScale', 'Vector4', {'$type': 'Vector4', 'X': c[0], 'Y': c[1], 'Z': c[2], 'W': 1}),
              _v('RoughnessScale', 'Float', rough), _v('MetalnessScale', 'Float', metal)]
    if emissive:
        tex, rgb, ev = emissive
        values += [_v('Emissive', 'rRef:ITexture', ref(tex)), _v('EmissiveEV', 'Float', ev),
                   _v('EmissiveColor', 'Color', {'$type': 'Color', 'Red': rgb[0], 'Green': rgb[1], 'Blue': rgb[2], 'Alpha': 255})]
    return {'$type': 'CMaterialInstance', 'baseMaterial': ref(BASE_MATERIAL), 'values': values,
            'enableMask': 0, 'resourceVersion': 4, 'cookingPlatform': 'PLATFORM_PC'}


def texture_template():
    setup = {'$type': 'STextureGroupSetup', 'compression': 'TCM_None', 'group': 'TEXG_Generic_Color', 'hasMipchain': 1,
             'isGamma': 1, 'isStreamable': 0, 'allowTextureDowngrade': 0, 'rawFormat': 'TRF_TrueColor'}
    header = {'$type': 'rendRenderTextureBlobHeader', 'flags': 1, 'histogramData': [], 'mipMapInfo': [],
              'sizeInfo': {'$type': 'rendRenderTextureBlobSizeInfo', 'width': 1, 'height': 1, 'depth': 1},
              'textureInfo': {'$type': 'rendRenderTextureBlobTextureInfo', 'dataAlignment': 8, 'mipCount': 1, 'sliceCount': 1,
                              'sliceSize': 0, 'textureDataSize': 0, 'type': 'TEXTYPE_2D'}, 'version': 2}
    root = {'$type': 'CBitmapTexture', 'cookingPlatform': 'PLATFORM_PC', 'width': 1, 'height': 1, 'depth': 1, 'setup': setup,
            'histBiasAddCoef': {'$type': 'Vector3', 'X': 0, 'Y': 0, 'Z': 0}, 'histBiasMulCoef': {'$type': 'Vector3', 'X': 1, 'Y': 1, 'Z': 1},
            'renderResourceBlob': None,
            'renderTextureResource': {'$type': 'rendRenderTextureResource', 'renderResourceBlobPC': {'HandleId': '0', 'Data': {
                '$type': 'rendRenderTextureBlobPC', 'header': header, 'textureData': {'BufferId': '0', 'Flags': 131072, 'Bytes': ''}}}}}
    return {'Header': {'WolvenKitVersion': '9.1.0', 'WKitJsonVersion': '0.0.9', 'GameVersion': 2310, 'DataType': 'CR2W'},
            'Data': {'Version': 195, 'BuildVersion': 0, 'RootChunk': root}}


def encode_texture(directory, sources, depot, name, image, flip):
    """Opaque RGBA with a full mip chain; sources/<name>.png keeps the upright drawing."""
    image = Image.alpha_composite(Image.new('RGBA', image.size, (0, 0, 0, 255)), image.convert('RGBA'))
    source = sources / (name + '.png'); image.save(source)
    width, height = image.size; data = bytearray(); mips = []
    level = flip(image)
    while True:
        block = level.tobytes(); w, h = level.size
        mips.append({'$type': 'rendRenderTextureBlobMipMapInfo', 'layout': {'$type': 'rendRenderTextureBlobMemoryLayout', 'rowPitch': w * 4, 'slicePitch': len(block)},
                     'placement': {'$type': 'rendRenderTextureBlobPlacement', 'offset': len(data), 'size': len(block)}})
        data.extend(block)
        if (w, h) == (1, 1): break
        level = level.resize((max(1, w // 2), max(1, h // 2)), Image.Resampling.BOX)
    obj = texture_template(); r = obj['Data']['RootChunk']; r['width'] = width; r['height'] = height
    blob = r['renderTextureResource']['renderResourceBlobPC']['Data']; header = blob['header']
    header['mipMapInfo'] = mips; header['sizeInfo']['width'] = width; header['sizeInfo']['height'] = height
    header['textureInfo'].update(mipCount=len(mips), sliceSize=len(data), textureDataSize=len(data))
    blob['textureData']['Bytes'] = base64.b64encode(data).decode()
    (directory / (name + '.xbm.json')).write_text(json.dumps(obj, separators=(',', ':')))
    return {'name': name, 'flipV': True, 'depot': depot + '\\textures\\' + name + '.xbm', 'width': width, 'height': height,
            'mips': len(mips), 'bytes': len(data), 'sourceSha256': hashlib.sha256(source.read_bytes()).hexdigest()}


def patch_uvs(path, faces):
    """Write explicit face UVs into a GLB produced by the shared cooker's glb()."""
    raw = bytearray(path.read_bytes()); json_length = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20 + json_length]); binary = 28 + json_length; groups = {}
    for face in faces: groups.setdefault(face['color'], []).append(face)
    for mi, group in enumerate(groups.values()):
        accessor = doc['accessors'][doc['meshes'][mi]['primitives'][0]['attributes']['TEXCOORD_0']]
        view = doc['bufferViews'][accessor['bufferView']]
        start = binary + view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
        for i, face in enumerate(group):
            if 'uv' in face:
                for j, uv in enumerate(face['uv']): struct.pack_into('<ff', raw, start + (i * 3 + j) * 8, *uv)
    path.write_bytes(raw)
