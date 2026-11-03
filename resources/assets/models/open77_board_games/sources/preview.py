"""Offline preview renders of the pack (NumPy + Pillow; not the game).

A small deferred rasterizer: the same faces, UVs, smooth-normal rule and
material values the cooker ships, lit by a dim bar-like environment (overhead
key light with shadows, cyan and magenta rim lights, neon reflections). It has
no emissive term, like the game material: whatever "glows" here does so only
because of its paint. Run from anywhere:

    python3 resources/assets/models/open77_board_games/sources/preview.py [scene ...]

Scenes: chess, pieces, checkers, connect4 (default: all). Images are written
next to this file as cyber-<scene>-preview.png.
"""
from pathlib import Path
import importlib.util
import math
import sys

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
spec = importlib.util.spec_from_file_location('board_game_art', ROOT / 'tools/board-game-art.py')
art = importlib.util.module_from_spec(spec)
spec.loader.exec_module(art)


def srgb_to_linear(c):
    c = np.asarray(c, np.float32)
    return np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= .0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - .055)


# ---------------------------------------------------------------- materials
TEXTURES = {}


def texture(name):
    """Textures are regenerated from tools/board-game-art.py (identical to
    the PNGs the cooker writes beside this file), upright as authored."""
    if not TEXTURES:
        for key, image in art.textures().items():
            TEXTURES[key] = srgb_to_linear(np.asarray(image.convert('RGB'), np.float32) / 255)
    return TEXTURES[name]


EXTRA = {'preview:table': (None, '#16171C', .38, 0.0)}


def material_table(keys):
    table = []
    for key in keys:
        tex, colour, rough, metal = art.MATERIALS.get(key) or EXTRA[key]
        h = colour.lstrip('#')
        scale = srgb_to_linear([int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)])
        table.append((tex, scale, rough, metal))
    return table


# ---------------------------------------------------------------- geometry
def flatten(scene):
    """scene: list of (faces, (x, y, z), yaw_degrees) -> arrays."""
    pos, uvs, mats, keys = [], [], [], {}
    for faces, (ox, oy, oz), yaw in scene:
        c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        for f in faces:
            tri = []
            for k in ('a', 'b', 'c'):
                x, y, z = f[k]
                tri.append((ox + x * c - y * s, oy + x * s + y * c, oz + z))
            pos.append(tri)
            if 'uv' in f:
                uvs.append(f['uv'])
            else:
                uvs.append(planar_uv(f))
            mats.append(keys.setdefault(f['color'], len(keys)))
    return (np.array(pos, np.float32), np.array(uvs, np.float32), np.array(mats, np.int32),
            [k for k, _ in sorted(keys.items(), key=lambda kv: kv[1])])


def planar_uv(f):
    """The cooker's fallback projection (computed in glTF axes)."""
    pts = [[f[k][0], f[k][2], -f[k][1]] for k in ('a', 'b', 'c')]
    u = np.subtract(pts[1], pts[0])
    v = np.subtract(pts[2], pts[0])
    n = np.cross(u, v)
    n = n / (np.linalg.norm(n) or 1)
    out = []
    for p in pts:
        if abs(n[1]) > .75:
            out.append([p[0] * 4, p[2] * 4])
        elif abs(n[0]) > abs(n[2]):
            out.append([-p[2] * 4, p[1] * 4])
        else:
            out.append([p[0] * 4, p[1] * 4])
    return out


def smooth_normals(pos):
    """Per face-vertex normals with the cooker's rule (average neighbours
    sharing a position whose face normal is within ~41 degrees)."""
    e1 = pos[:, 1] - pos[:, 0]
    e2 = pos[:, 2] - pos[:, 0]
    fn = np.cross(e1, e2)
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-20)
    flat = pos.reshape(-1, 3)
    keys = np.round(flat, 6)
    _, inverse = np.unique(keys, axis=0, return_inverse=True)
    inverse = inverse.reshape(-1)
    order = np.argsort(inverse, kind='stable')
    result = np.repeat(fn, 3, axis=0).copy()
    face_of = np.arange(len(flat)) // 3
    boundaries = np.flatnonzero(np.diff(inverse[order])) + 1
    for group in np.split(order, boundaries):
        if len(group) < 2:
            continue
        normals = fn[face_of[group]]
        dots = normals @ normals.T
        summed = (dots > .75).astype(np.float32) @ normals
        summed /= np.maximum(np.linalg.norm(summed, axis=1, keepdims=True), 1e-20)
        result[group] = summed
    return result.reshape(-1, 3, 3), fn


# ---------------------------------------------------------------- raster
def rasterize(screen, depth, width, height, perspective=True):
    """screen: (N,3,2) pixel coords, depth: (N,3) positive. Returns face id
    and perspective-correct barycentrics per pixel."""
    zbuf = np.full((height, width), np.inf, np.float32)
    fid = np.full((height, width), -1, np.int32)
    b1 = np.zeros((height, width), np.float32)
    b2 = np.zeros((height, width), np.float32)
    lo = np.floor(screen.min(axis=1)).astype(int)
    hi = np.ceil(screen.max(axis=1)).astype(int)
    lo = np.maximum(lo, 0)
    hi[:, 0] = np.minimum(hi[:, 0], width - 1)
    hi[:, 1] = np.minimum(hi[:, 1], height - 1)
    visible = np.flatnonzero((hi[:, 0] >= lo[:, 0]) & (hi[:, 1] >= lo[:, 1]) & (depth.min(axis=1) > 0))
    for i in visible:
        (x0, y0), (x1, y1), (x2, y2) = screen[i]
        den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
        if abs(den) < 1e-9:
            continue
        xs = np.arange(lo[i, 0], hi[i, 0] + 1) + .5
        ys = np.arange(lo[i, 1], hi[i, 1] + 1) + .5
        xx, yy = np.meshgrid(xs, ys)
        w0 = ((y1 - y2) * (xx - x2) + (x2 - x1) * (yy - y2)) / den
        w1 = ((y2 - y0) * (xx - x2) + (x0 - x2) * (yy - y2)) / den
        w2 = 1 - w0 - w1
        inside = (w0 >= -2e-4) & (w1 >= -2e-4) & (w2 >= -2e-4)
        if not inside.any():
            continue
        z0, z1, z2 = depth[i]
        if perspective:
            q0, q1, q2 = w0 / z0, w1 / z1, w2 / z2
            inv = q0 + q1 + q2
            z = 1 / inv
            c1, c2 = q1 * z, q2 * z
        else:
            z = w0 * z0 + w1 * z1 + w2 * z2
            c1, c2 = w1, w2
        sl = (slice(lo[i, 1], hi[i, 1] + 1), slice(lo[i, 0], hi[i, 0] + 1))
        closer = inside & (z < zbuf[sl])
        if not closer.any():
            continue
        zbuf[sl][closer] = z[closer]
        fid[sl][closer] = i
        b1[sl][closer] = c1[closer]
        b2[sl][closer] = c2[closer]
    return fid, b1, b2, zbuf


def look_at(eye, target):
    eye = np.asarray(eye, np.float32)
    fwd = np.asarray(target, np.float32) - eye
    fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, [0, 0, 1])
    right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    return eye, fwd, right, up


# ---------------------------------------------------------------- lighting
KEY_DIR = np.array([-.35, .45, 1.0], np.float32)
KEY_DIR /= np.linalg.norm(KEY_DIR)
LIGHTS = [  # direction (towards light), linear colour
    (KEY_DIR, np.array([2.6, 2.45, 2.25], np.float32), True),
    (np.array([.85, -.55, .35]), np.array([.03, .30, .40], np.float32), False),
    (np.array([-.9, -.35, .45]), np.array([.40, .06, .26], np.float32), False),
]


def environment(d, rough):
    """Fake bar interior: dark room, warm ceiling panels, cyan and magenta
    neon tubes, amber spots. Softer with roughness."""
    d = d / np.maximum(np.linalg.norm(d, axis=-1, keepdims=True), 1e-9)
    x, y, z = d[..., 0], d[..., 1], d[..., 2]
    soft = (.05 + rough * .9)[..., None] if np.ndim(rough) else .05 + rough * .9
    az = np.arctan2(y, x)
    col = np.zeros(d.shape, np.float32) + np.array([.006, .007, .010], np.float32)
    col += np.clip(z, 0, 1)[..., None] ** 2 * np.array([.05, .05, .06], np.float32)

    def band(value, centre, width, s, wrap=False):
        delta = value - centre
        if wrap:
            delta = (delta + math.pi) % math.tau - math.pi
        return np.clip((width + s - np.abs(delta)) / np.maximum(s, 1e-3), 0, 1)
    s = soft[..., 0] if np.ndim(soft) else soft
    stripes = np.clip((np.abs(np.sin(az * 3)) - .35) / (.08 + s * .5), 0, 1)
    ceiling = band(z, .93, .05, s * .6) * stripes
    col += ceiling[..., None] * np.array([2.0, 1.85, 1.65], np.float32)
    cyan = band(az, .35, .05, s, True) * band(z, .25, .22, s)
    col += cyan[..., None] * np.array([.02, .45, .6], np.float32)
    magenta = band(az, -2.45, .05, s, True) * band(z, .3, .25, s)
    col += magenta[..., None] * np.array([.55, .04, .32], np.float32)
    amber = band(az, 2.0, .2, s, True) * band(z, .1, .05, s)
    col += amber[..., None] * np.array([.9, .45, .06], np.float32)
    # Generic dim room: walls catch some light so glossy parts never read black.
    col += np.array([.05, .05, .06], np.float32) * np.clip(1 - np.abs(z), 0, 1)[..., None]
    s3 = s[..., None] if np.ndim(s) else s
    return col * (1 - .6 * s3) + (.04 * s3)


def shade(scene, eye, target, fov, width, height, ss=2, exposure=1.0, background=(.012, .013, .018)):
    pos, uvs, mats, keys = flatten(scene)
    vnorm, fnorm = smooth_normals(pos)
    table = material_table(keys)
    W, H = width * ss, height * ss
    eye, fwd, right, up = look_at(eye, target)
    rel = pos - eye
    zc = rel @ fwd
    focal = (H / 2) / math.tan(math.radians(fov) / 2)
    sx = W / 2 + (rel @ right) / np.maximum(zc, 1e-6) * focal
    sy = H / 2 - (rel @ up) / np.maximum(zc, 1e-6) * focal
    keep = np.flatnonzero((zc > .05).all(axis=1))
    fid, b1, b2, _ = rasterize(np.stack([sx, sy], -1)[keep], zc[keep], W, H)
    hit = fid >= 0
    f = keep[fid[hit]]
    w1, w2 = b1[hit], b2[hit]
    w0 = 1 - w1 - w2
    P = pos[f, 0] * w0[:, None] + pos[f, 1] * w1[:, None] + pos[f, 2] * w2[:, None]
    N = vnorm[f, 0] * w0[:, None] + vnorm[f, 1] * w1[:, None] + vnorm[f, 2] * w2[:, None]
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    UV = uvs[f, 0] * w0[:, None] + uvs[f, 1] * w1[:, None] + uvs[f, 2] * w2[:, None]
    V = eye - P
    V /= np.linalg.norm(V, axis=1, keepdims=True)
    # Two-sided safety for thin parts seen from behind.
    flip = (N * V).sum(1) < 0
    N[flip] *= -1
    albedo = np.zeros_like(P)
    rough = np.zeros(len(P), np.float32)
    metal = np.zeros(len(P), np.float32)
    mid = mats[f]
    for m, (tex, scale, r, mt) in enumerate(table):
        sel = mid == m
        if not sel.any():
            continue
        if tex:
            img = texture(tex)
            th, tw = img.shape[:2]
            u = np.mod(UV[sel, 0], 1) * tw
            v = np.mod(UV[sel, 1], 1) * th
            albedo[sel] = img[v.astype(int) % th, u.astype(int) % tw] * scale
        else:
            albedo[sel] = scale
        rough[sel] = r
        metal[sel] = mt
    # Shadow map for the key light.
    shadow = shadow_factor(pos, P, N, casters=np.flatnonzero(mats != keys.index('preview:table')) if 'preview:table' in keys else None)
    NdotV = np.clip((N * V).sum(1), 1e-3, 1)
    F0 = .04 * (1 - metal)[:, None] + albedo * metal[:, None]
    diffuse_c = albedo * (1 - metal)[:, None]
    a = np.maximum(rough, .04) ** 2
    colour = np.zeros_like(P)
    for i, (L, lc, shadowed) in enumerate(LIGHTS):
        L = np.asarray(L, np.float32) / np.linalg.norm(L)
        NdotL = np.clip(N @ L, 0, 1)
        Hv = L[None, :] + V
        Hv /= np.linalg.norm(Hv, axis=1, keepdims=True)
        NdotH = np.clip((N * Hv).sum(1), 0, 1)
        D = a ** 2 / (math.pi * ((NdotH ** 2) * (a ** 2 - 1) + 1) ** 2)
        k = (np.maximum(rough, .04) + 1) ** 2 / 8
        G = (NdotL / (NdotL * (1 - k) + k)) * (NdotV / (NdotV * (1 - k) + k))
        VdotH = np.clip((V * Hv).sum(1), 0, 1)
        F = F0 + (1 - F0) * ((1 - VdotH) ** 5)[:, None]
        spec = F * (D * G / np.maximum(4 * NdotL * NdotV, 1e-3))[:, None]
        light = (diffuse_c / math.pi * (1 - F) + spec) * (NdotL[:, None] * lc[None, :])
        if shadowed:
            light *= shadow[:, None]
        colour += light
    R = 2 * (N * V).sum(1, keepdims=True) * N - V
    Fenv = F0 + (np.maximum(1 - rough, F0.max(1))[:, None] - F0) * ((1 - NdotV) ** 5)[:, None]
    colour += environment(R, rough) * Fenv * (.55 + .45 * shadow[:, None])
    colour += diffuse_c * environment(N, np.ones(len(N), np.float32) * .95) * .35
    image = np.zeros((H, W, 3), np.float32)
    yy = np.linspace(0, 1, H, dtype=np.float32)[:, None, None]
    image[:] = np.array(background, np.float32) * (1.3 - .6 * yy)
    image[hit] = colour * exposure
    # ACES-like filmic curve, then sRGB.
    x = image
    mapped = (x * (2.51 * x + .03)) / (x * (2.43 * x + .59) + .14)
    out = (linear_to_srgb(mapped) * 255 + .5).astype(np.uint8)
    img = Image.fromarray(out, 'RGB')
    return img.reduce(ss) if ss > 1 else img


SHADOW = {}


def shadow_factor(pos, P, N, size=3072, casters=None):
    key = id(pos)
    if casters is not None:
        pos = pos[casters]
    L = KEY_DIR
    right = np.cross(L, [0, 1, 0])
    right /= np.linalg.norm(right)
    up = np.cross(right, L)
    flat = pos.reshape(-1, 3)
    u, v, d = flat @ right, flat @ up, -(flat @ L)
    umin, umax, vmin, vmax = u.min(), u.max(), v.min(), v.max()
    span = max(umax - umin, vmax - vmin) * 1.02
    if SHADOW.get('key') != key:
        sxy = np.stack([(u - umin) / span * size, (vmax - v) / span * size], -1).reshape(-1, 3, 2)
        depth = (d - d.min() + 1).reshape(-1, 3)
        _, _, _, zbuf = rasterize(sxy, depth, size, size, perspective=False)
        SHADOW.update(key=key, zbuf=zbuf, dmin=d.min())
    zbuf, dmin = SHADOW['zbuf'], SHADOW['dmin']
    Pu = (P @ right - umin) / span * size
    Pv = (vmax - P @ up) / span * size
    Pd = -(P @ L) - dmin + 1
    bias = .0012 + .002 * (1 - np.clip(N @ L, 0, 1))
    bias = bias * span / 1.5
    lit = np.zeros(len(P), np.float32)
    outside = (Pu < 0) | (Pv < 0) | (Pu >= size) | (Pv >= size)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            x = np.clip((Pu + dx).astype(int), 0, size - 1)
            y = np.clip((Pv + dy).astype(int), 0, size - 1)
            lit += ((Pd - bias <= zbuf[y, x]) | outside).astype(np.float32)
    return lit / 9


# ---------------------------------------------------------------- scenes
MODELS = None


def models():
    global MODELS
    if MODELS is None:
        MODELS = art.models()
    return MODELS


def table_plane(z, half=3.0):
    out = []
    art.quad(out, (-half, -half, z), (half, -half, z), (half, half, z), (-half, half, z), 'preview:table')
    return out


def chess_setup(m):
    scene = [(m['chess_board'], (0, 0, 0), 0), (table_plane(-.036), (0, 0, 0), 0)]
    back = ['rook', 'knight', 'bishop', 'queen', 'king', 'bishop', 'knight', 'rook']
    for c in range(1, 9):
        for row, side, kind in ((1, 'black', back[c - 1]), (2, 'black', 'pawn'), (7, 'white', 'pawn'), (8, 'white', back[c - 1])):
            x, y = (c - .5) / 8 - .5, (row - .5) / 8 - .5
            yaw = 180 if kind == 'knight' and side == 'white' else 0
            scene.append((m[f'chess_{side}_{kind}'], (x, y, .004), yaw))
    return scene


def scene_chess():
    m = models()
    scene = chess_setup(m)
    # Standing third-person view from White's side (+Y), slightly off-axis.
    return shade(scene, (.42, 1.22, .82), (0, -.06, 0), 46, 1600, 1000)


def scene_pieces():
    m = models()
    scene = [(table_plane(0), (0, 0, 0), 0)]
    kinds = ['pawn', 'rook', 'knight', 'bishop', 'queen', 'king']
    for i, kind in enumerate(kinds):
        for side, y in (('white', -.06), ('black', .06)):
            yaw = -60 if kind == 'knight' else 0
            scene.append((m[f'chess_{side}_{kind}'], ((i - 2.5) * .095, y, 0), yaw))
    for i, (side, kind) in enumerate((('white', 'man'), ('white', 'king'), ('black', 'man'), ('black', 'king'))):
        scene.append((m[f'checkers_{side}_{kind}'], ((i - 1.5) * .08, -.16, 0), 0))
    return shade(scene, (.10, -.66, .36), (0, -.01, .045), 36, 1600, 1000)


def scene_checkers():
    m = models()
    scene = [(m['checkers_board'], (0, 0, 0), 0), (table_plane(-.036), (0, 0, 0), 0)]
    for r in range(1, 11):
        for c in range(1, 11):
            if (r + c) % 2 == 1 and (r <= 4 or r >= 7):
                side = 'black' if r <= 4 else 'white'
                kind = 'king' if (r, c) in ((4, 5), (7, 4)) else 'man'
                scene.append((m[f'checkers_{side}_{kind}'], ((c - .5) / 10 - .5, (r - .5) / 10 - .5, .004), 0))
    return shade(scene, (-.42, 1.22, .82), (0, -.06, 0), 46, 1600, 1000)


def set_key(direction):
    global KEY_DIR
    KEY_DIR = np.array(direction, np.float32) / np.linalg.norm(direction)
    LIGHTS[0] = (KEY_DIR, LIGHTS[0][1], True)


def scene_connect4():
    set_key([.45, -.8, 1.0])
    m = models()
    scene = [(m['connect4_board'], (0, 0, 0), 0), (table_plane(0), (0, 0, 0), 0)]
    moves = [(6, 4, 'white'), (6, 3, 'black'), (5, 4, 'white'), (6, 5, 'black'), (4, 4, 'white'),
             (3, 4, 'black'), (6, 2, 'white'), (5, 3, 'black'), (5, 5, 'white'), (6, 6, 'black')]
    for row, col, side in moves:
        scene.append((m[f'connect4_{side}_disc'], ((col - 4) * .14, 0, (6.5 - row) * .14 + .04), 0))
    # A disc mid-drop above column 5.
    scene.append((m['connect4_black_disc'], (.14, 0, 1.05), 0))
    return shade(scene, (.75, -1.55, 1.05), (0, 0, .48), 42, 1400, 1100)


SCENES = {'chess': scene_chess, 'pieces': scene_pieces, 'checkers': scene_checkers, 'connect4': scene_connect4}

if __name__ == '__main__':
    for name in sys.argv[1:] or list(SCENES):
        SHADOW.clear()
        set_key([-.35, .45, 1.0])
        image = SCENES[name]()
        path = HERE / f'cyber-{name}-preview.png'
        image.save(path, optimize=True)
        print(path)
