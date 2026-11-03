#!/usr/bin/env python3
"""Shared art helpers for the casino prop builders (slots, blackjack).

* `hud_text` / `text_size`: an original chamfered "HUD" stroke typeface drawn
  from polylines (no font file, so the artwork is identical on every machine
  and carries no third-party glyph design).
* `glow`: neon bloom for Pillow layers.
* `shape_mask` and the suit shapes: vector shapes rendered supersampled.
* `Preview`: a small numpy software rasterizer used to render preview images
  of the authored geometry and textures (backfaces culled like the engine,
  metal reflects a procedural neon room, emissive materials bloom). It is a
  design aid only: the game's renderer decides the final look.

Imported by tools/build-casino-slots-props.py and
tools/build-casino-blackjack-props.py; it writes nothing by itself.
"""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# --- HUD typeface ---------------------------------------------------------------
# Glyphs on a grid 6 units tall (cap height), y down. Each glyph: (advance,
# [polyline, ...]); a one-point polyline is a square dot.
_O = [(1, 0), (3, 0), (4, 1), (4, 5), (3, 6), (1, 6), (0, 5), (0, 1), (1, 0)]
GLYPHS = {
    'A': (4, [[(0, 6), (0, 1.6), (1.6, 0), (2.4, 0), (4, 1.6), (4, 6)], [(0, 3.6), (4, 3.6)]]),
    'B': (4, [[(0, 3), (3, 3), (4, 4), (4, 5), (3, 6), (0, 6), (0, 0), (3, 0), (4, 1), (4, 2), (3, 3)]]),
    'C': (4, [[(4, 0), (1, 0), (0, 1), (0, 5), (1, 6), (4, 6)]]),
    'D': (4, [[(0, 0), (2.8, 0), (4, 1.2), (4, 4.8), (2.8, 6), (0, 6), (0, 0)]]),
    'E': (4, [[(4, 0), (0, 0), (0, 6), (4, 6)], [(0, 3), (3, 3)]]),
    'F': (4, [[(4, 0), (0, 0), (0, 6)], [(0, 3), (3, 3)]]),
    'G': (4, [[(4, 1), (3, 0), (1, 0), (0, 1), (0, 5), (1, 6), (3, 6), (4, 5), (4, 3.4), (2.2, 3.4)]]),
    'H': (4, [[(0, 0), (0, 6)], [(4, 0), (4, 6)], [(0, 3), (4, 3)]]),
    'I': (1.6, [[(.8, 0), (.8, 6)]]),
    'J': (4, [[(4, 0), (4, 5), (3, 6), (1, 6), (0, 5), (0, 4.2)]]),
    'K': (4, [[(0, 0), (0, 6)], [(4, 0), (1.2, 3), (0, 3)], [(1.2, 3), (4, 6)]]),
    'L': (3.6, [[(0, 0), (0, 6), (3.6, 6)]]),
    'M': (4.6, [[(0, 6), (0, 0), (2.3, 2.6), (4.6, 0), (4.6, 6)]]),
    'N': (4, [[(0, 6), (0, 0), (4, 6), (4, 0)]]),
    'O': (4, [_O]),
    'P': (4, [[(0, 6), (0, 0), (3, 0), (4, 1), (4, 2.5), (3, 3.5), (0, 3.5)]]),
    'Q': (4, [_O, [(2.6, 4.6), (4, 6)]]),
    'R': (4, [[(0, 6), (0, 0), (3, 0), (4, 1), (4, 2.5), (3, 3.5), (0, 3.5)], [(2.2, 3.5), (4, 6)]]),
    'S': (4, [[(4, 1), (3, 0), (1, 0), (0, 1), (0, 2), (1, 3), (3, 3), (4, 4), (4, 5), (3, 6), (1, 6), (0, 5)]]),
    'T': (4, [[(0, 0), (4, 0)], [(2, 0), (2, 6)]]),
    'U': (4, [[(0, 0), (0, 5), (1, 6), (3, 6), (4, 5), (4, 0)]]),
    'V': (4, [[(0, 0), (0, 3.4), (2, 6), (4, 3.4), (4, 0)]]),
    'W': (4.6, [[(0, 0), (0, 6), (2.3, 3.4), (4.6, 6), (4.6, 0)]]),
    'X': (4, [[(0, 0), (4, 6)], [(4, 0), (0, 6)]]),
    'Y': (4, [[(0, 0), (2, 3)], [(4, 0), (2, 3), (2, 6)]]),
    'Z': (4, [[(0, 0), (4, 0), (0, 6), (4, 6)]]),
    '0': (3.6, [[(.9, 0), (2.7, 0), (3.6, .9), (3.6, 5.1), (2.7, 6), (.9, 6), (0, 5.1), (0, .9), (.9, 0)]]),
    '1': (3, [[(.4, 1.2), (1.8, 0), (1.8, 6)]]),
    '2': (4, [[(0, 1), (1, 0), (3, 0), (4, 1), (4, 2), (3, 3), (1, 3), (0, 4), (0, 6), (4, 6)]]),
    '3': (4, [[(0, 1), (1, 0), (3, 0), (4, 1), (4, 2), (3, 3), (1.4, 3)], [(3, 3), (4, 4), (4, 5), (3, 6), (1, 6), (0, 5)]]),
    '4': (4, [[(3, 6), (3, 0), (0, 4), (0, 4.2), (4, 4.2)]]),
    '5': (4, [[(4, 0), (0, 0), (0, 3), (3, 3), (4, 4), (4, 5), (3, 6), (0, 6)]]),
    '6': (4, [[(4, 1), (3, 0), (1, 0), (0, 1), (0, 5), (1, 6), (3, 6), (4, 5), (4, 4), (3, 3), (0, 3)]]),
    '7': (4, [[(0, 0), (4, 0), (4, 1), (1.6, 6)]]),
    '8': (4, [[(1, 0), (3, 0), (4, 1), (4, 2), (3, 3), (1, 3), (0, 2), (0, 1), (1, 0)],
              [(1, 3), (0, 4), (0, 5), (1, 6), (3, 6), (4, 5), (4, 4), (3, 3)]]),
    '9': (4, [[(0, 5), (1, 6), (3, 6), (4, 5), (4, 1), (3, 0), (1, 0), (0, 1), (0, 2), (1, 3), (4, 3)]]),
    ' ': (2.4, []),
    '.': (.6, [[(.3, 5.7)]]),
    ',': (.8, [[(.6, 5.4), (.2, 6.6)]]),
    ':': (.6, [[(.3, 1.9)], [(.3, 5.7)]]),
    '\u00b7': (.6, [[(.3, 3)]]),
    '-': (2.6, [[(.2, 3), (2.4, 3)]]),
    '/': (3, [[(0, 6), (3, 0)]]),
    '+': (3, [[(1.5, 1.5), (1.5, 4.5)], [(0, 3), (3, 3)]]),
    'x': (3, [[(0, 2.2), (3, 6)], [(3, 2.2), (0, 6)]]),
    '$': (4, [[(4, 1.2), (3, .4), (1, .4), (0, 1.2), (0, 2.2), (1, 3), (3, 3), (4, 3.8), (4, 4.8), (3, 5.6), (1, 5.6), (0, 4.8)], [(2, -.6), (2, 6.6)]]),
    '<': (3, [[(3, 1), (0, 3), (3, 5)]]),
    '>': (3, [[(0, 1), (3, 3), (0, 5)]]),
}
GLYPHS['–'] = GLYPHS['-']


def text_size(text, size, tracking=1.2, weight=.16):
    """(width, height) in pixels of `text` with cap height `size`."""
    unit = size / 6
    advance = sum(GLYPHS[ch][0] for ch in text) + tracking * max(0, len(text) - 1)
    stroke = weight * size  # ink extents: the stroke overhangs the grid by half its width
    return advance * unit + stroke, size + stroke


def text_mask(text, size, tracking=1.2, weight=.16, slant=0.0, ss=4):
    """An L mask of the text, supersampled `ss` times then reduced (anti-aliased)."""
    unit = size / 6 * ss
    stroke = max(1, round(weight * size * ss))
    pad = stroke
    advance = sum(GLYPHS[ch][0] for ch in text) + tracking * max(0, len(text) - 1)
    # Equal margins on both sides, so 'mm' centres the ink.
    width = int(math.ceil(advance * unit + 2 * pad + abs(slant) * 6 * unit))
    height = int(math.ceil(6 * unit + 2 * pad))
    im = Image.new('L', (width, height), 0)
    d = ImageDraw.Draw(im)
    x = pad + (abs(slant) * 6 * unit if slant < 0 else 0)
    for ch in text:
        advance, lines = GLYPHS[ch]
        for line in lines:
            pts = [(x + gx * unit + (6 - gy) * slant * unit, pad + gy * unit) for gx, gy in line]
            if len(pts) == 1:
                cx, cy = pts[0]
                r = stroke * .62
                d.rectangle((cx - r, cy - r, cx + r, cy + r), fill=255)
            else:
                d.line(pts, fill=255, width=stroke, joint='curve')
                for cx, cy in (pts[0], pts[-1]):  # square caps
                    r = stroke / 2
                    d.rectangle((cx - r, cy - r, cx + r, cy + r), fill=255)
        x += (advance + tracking) * unit
    return im.resize((max(1, width // ss), max(1, height // ss)), Image.Resampling.LANCZOS)


def paste_mask(image, mask, color, x, y, anchor='mm', rotate=0.0):
    """Composite a solid `color` through `mask` onto RGBA `image`, anchored at (x, y)."""
    if rotate:
        mask = mask.rotate(rotate, resample=Image.Resampling.BICUBIC, expand=True)
    w, h = mask.size
    ox = {'l': 0, 'm': w / 2, 'r': w}[anchor[0]]
    oy = {'t': 0, 'm': h / 2, 'b': h}[anchor[1]]
    layer = Image.new('RGBA', mask.size, tuple(color[:3]) + (255,))
    alpha = mask if len(color) < 4 or color[3] == 255 else mask.point(lambda v: v * color[3] // 255)
    layer.putalpha(alpha)
    image.alpha_composite(layer, (round(x - ox), round(y - oy)))


def hud_text(image, text, x, y, size, color, anchor='mm', tracking=1.2, weight=.16, slant=0.0,
             rotate=0.0, glow_color=None, glow_radius=0.0, glow_strength=1.0):
    mask = text_mask(text, size, tracking, weight, slant)
    if glow_color is not None and glow_radius > 0:
        margin = int(glow_radius * 3)
        big = Image.new('L', (mask.width + 2 * margin, mask.height + 2 * margin), 0)
        big.paste(mask, (margin, margin))
        halo = big.filter(ImageFilter.GaussianBlur(glow_radius)).point(lambda v: min(255, int(v * glow_strength)))
        if rotate or anchor == 'mm':
            paste_mask(image, halo, glow_color, x, y, 'mm', rotate)
        else:  # keep the halo centred on the text whatever the anchor
            w, h = mask.size
            cx = x - {'l': 0, 'm': w / 2, 'r': w}[anchor[0]] + w / 2
            cy = y - {'t': 0, 'm': h / 2, 'b': h}[anchor[1]] + h / 2
            paste_mask(image, halo, glow_color, cx, cy, 'mm')
    paste_mask(image, mask, color, x, y, anchor, rotate)


def glow(image, layer, radius, strength=1.0):
    """Composite `layer` (RGBA) plus a blurred bloom of it onto `image`."""
    halo = layer.filter(ImageFilter.GaussianBlur(radius))
    if strength != 1.0:
        a = halo.getchannel('A').point(lambda v: min(255, int(v * strength)))
        halo.putalpha(a)
    image.alpha_composite(halo)
    image.alpha_composite(layer)


def shape_mask(size, draw, ss=4):
    """Render `draw(ImageDraw, scale)` into an anti-aliased L mask of `size`."""
    w, h = size
    im = Image.new('L', (w * ss, h * ss), 0)
    draw(ImageDraw.Draw(im), ss)
    return im.resize((w, h), Image.Resampling.LANCZOS)


def suit_mask(suit, size, ss=4):
    """Original suit shapes in a square mask of `size` px (suit in 'SHDC')."""
    def draw(d, s):
        S = size * s

        def circle(cx, cy, r):
            d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
        if suit == 'H':
            circle(.29 * S, .34 * S, .235 * S); circle(.71 * S, .34 * S, .235 * S)
            d.polygon([(.07 * S, .42 * S), (.93 * S, .42 * S), (.5 * S, .95 * S)], fill=255)
            d.polygon([(.3 * S, .2 * S), (.7 * S, .2 * S), (.5 * S, .5 * S)], fill=255)
        elif suit == 'S':
            circle(.29 * S, .6 * S, .225 * S); circle(.71 * S, .6 * S, .225 * S)
            d.polygon([(.07 * S, .53 * S), (.93 * S, .53 * S), (.5 * S, .03 * S)], fill=255)
            d.polygon([(.5 * S, .62 * S), (.33 * S, .97 * S), (.67 * S, .97 * S)], fill=255)
        elif suit == 'D':
            pts = []  # gently concave sides
            corners = [(.5, .02), (.86, .5), (.5, .98), (.14, .5)]
            for k in range(4):
                (ax, ay), (bx, by) = corners[k], corners[(k + 1) % 4]
                for i in range(12):
                    t = i / 12
                    px, py = ax + (bx - ax) * t, ay + (by - ay) * t
                    bulge = .045 * math.sin(math.pi * t)
                    px += (.5 - px) * bulge * 2
                    py += (.5 - py) * bulge * 2
                    pts.append((px * S, py * S))
            d.polygon(pts, fill=255)
        elif suit == 'C':
            circle(.5 * S, .28 * S, .2 * S); circle(.27 * S, .58 * S, .2 * S); circle(.73 * S, .58 * S, .2 * S)
            d.polygon([(.34 * S, .3 * S), (.66 * S, .3 * S), (.66 * S, .64 * S), (.34 * S, .64 * S)], fill=255)
            d.polygon([(.5 * S, .55 * S), (.32 * S, .97 * S), (.68 * S, .97 * S)], fill=255)
        else:
            raise ValueError(suit)
    return shape_mask((size, size), draw, ss)


def gradient(size, top, bottom, horizontal=False):
    """RGBA linear gradient image."""
    w, h = size
    n = w if horizontal else h
    t = np.linspace(0, 1, n)[:, None]
    row = (np.array(top, float)[None, :] * (1 - t) + np.array(bottom, float)[None, :] * t).astype(np.uint8)
    if horizontal:
        arr = np.broadcast_to(row[None, :, :], (h, w, row.shape[1]))
    else:
        arr = np.broadcast_to(row[:, None, :], (h, w, row.shape[1]))
    arr = np.ascontiguousarray(arr)
    if arr.shape[2] == 3:
        arr = np.concatenate([arr, np.full((h, w, 1), 255, np.uint8)], 2)
    return Image.fromarray(arr, 'RGBA')


def noise(size, seed, scale=4, amount=1.0):
    """Smooth grey value noise in [-1, 1] (numpy array h x w)."""
    rng = np.random.default_rng(seed)
    w, h = size
    small = rng.standard_normal((max(2, h // scale), max(2, w // scale))).astype(np.float32)
    im = Image.fromarray(((small * 40) + 128).clip(0, 255).astype(np.uint8), 'L').resize((w, h), Image.Resampling.BICUBIC)
    return (np.asarray(im, np.float32) - 128) / 40 * amount


# --- Preview rasterizer ---------------------------------------------------------
def _srgb_to_linear(c):
    c = np.asarray(c, np.float32) / 255
    return np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)


def _linear_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= .0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - .055)


def environment(d):
    """Procedural night-casino room radiance for direction(s) d (..., 3), Z up."""
    x, y, z = d[..., 0], d[..., 1], d[..., 2]
    sky = .02 + .05 * np.clip(z, 0, 1)
    col = np.stack([sky * .8, sky * .85, sky * 1.2], -1)
    # Ceiling light panels.
    panel = (z > .55) & (np.abs(np.sin(np.arctan2(y, x) * 3)) > .7)
    col = col + panel[..., None] * np.array([1.6, 1.55, 1.5])
    # Neon wall bands: magenta to the left, cyan to the right, warm behind.
    band = np.exp(-((z - .12) / .07) ** 2)
    col = col + band[..., None] * (np.clip(-x, 0, 1)[..., None] * np.array([1.4, .12, .7])
                                   + np.clip(x, 0, 1)[..., None] * np.array([.1, 1.1, 1.4])
                                   + np.clip(y, 0, 1)[..., None] * np.array([1.2, .6, .2]))
    floor = (z < -.05)
    col = np.where(floor[..., None], np.array([.015, .015, .02]), col)
    return col


class Preview:
    """Collects posed meshes and renders them; materials come from a resolver.

    resolver(color_key) -> dict(color=(r,g,b) sRGB 0-255 or texture=PIL image,
    rough=float, metal=float, emit=float (linear multiplier, 0 = none)).
    """

    def __init__(self, resolver):
        self.resolver = resolver
        self.tris = []      # (N,3,3) arrays per batch
        self.uvs = []
        self.keys = []

    def add(self, faces, offset=(0, 0, 0), yaw=0.0):
        a = math.radians(yaw)
        ca, sa = math.cos(a), math.sin(a)
        ox, oy, oz = offset
        pts = np.array([[f['a'], f['b'], f['c']] for f in faces], np.float64)
        x, y = pts[..., 0].copy(), pts[..., 1].copy()
        pts[..., 0] = x * ca - y * sa + ox
        pts[..., 1] = x * sa + y * ca + oy
        pts[..., 2] += oz
        self.tris.append(pts)
        self.uvs.append(np.array([f.get('uv', [[0, 0]] * 3) for f in faces], np.float64))
        self.keys.extend(f['color'] for f in faces)

    def render(self, eye, target, fov=45, size=(1280, 800), ss=2, exposure=1.0, background=(10, 10, 16),
               bloom=True):
        W, H = size[0] * ss, size[1] * ss
        tris = np.concatenate(self.tris)
        uvs = np.concatenate(self.uvs)
        keys = self.keys
        eye = np.array(eye, float)
        fwd = np.array(target, float) - eye
        fwd /= np.linalg.norm(fwd)
        right = np.cross(fwd, [0, 0, 1])
        right /= np.linalg.norm(right)
        up = np.cross(right, fwd)
        rel = tris - eye
        cx = rel @ right
        cy = rel @ up
        cz = rel @ fwd
        f = 1 / math.tan(math.radians(fov) / 2)
        aspect = W / H
        normals = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
        nlen = np.linalg.norm(normals, axis=1)
        normals = normals / np.maximum(nlen, 1e-12)[:, None]
        centers = tris.mean(1)
        facing = np.einsum('ij,ij->i', normals, eye - centers) > 0
        visible = facing & (cz > .02).all(1) & (nlen > 1e-14)
        sx = (cx / cz * f / aspect * .5 + .5) * W
        sy = (.5 - cy / cz * f * .5) * H
        zbuf = np.full((H, W), np.inf)
        fid = np.full((H, W), -1, np.int64)
        bary = np.zeros((H, W, 3))
        for i in np.nonzero(visible)[0]:
            x0, x1, x2 = sx[i]
            y0, y1, y2 = sy[i]
            minx = max(int(math.floor(min(x0, x1, x2))), 0)
            maxx = min(int(math.ceil(max(x0, x1, x2))), W - 1)
            miny = max(int(math.floor(min(y0, y1, y2))), 0)
            maxy = min(int(math.ceil(max(y0, y1, y2))), H - 1)
            if minx > maxx or miny > maxy:
                continue
            den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
            if abs(den) < 1e-12:
                continue
            px, py = np.meshgrid(np.arange(minx, maxx + 1) + .5, np.arange(miny, maxy + 1) + .5)
            w0 = ((y1 - y2) * (px - x2) + (x2 - x1) * (py - y2)) / den
            w1 = ((y2 - y0) * (px - x2) + (x0 - x2) * (py - y2)) / den
            w2 = 1 - w0 - w1
            inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
            if not inside.any():
                continue
            iz = 1 / cz[i]
            inv = w0 * iz[0] + w1 * iz[1] + w2 * iz[2]
            depth = 1 / np.maximum(inv, 1e-12)
            sub = zbuf[miny:maxy + 1, minx:maxx + 1]
            win = inside & (depth < sub)
            if not win.any():
                continue
            sub[win] = depth[win]
            fid[miny:maxy + 1, minx:maxx + 1][win] = i
            pc = np.stack([w0 * iz[0], w1 * iz[1], w2 * iz[2]], -1) * depth[..., None]
            bsub = bary[miny:maxy + 1, minx:maxx + 1]
            bsub[win] = pc[win]
        # Deferred shading.
        img = np.zeros((H, W, 3))
        emis = np.zeros((H, W, 3))
        bg = _srgb_to_linear(background)
        img[:] = bg
        hit = fid >= 0
        ids = fid[hit]
        b = bary[hit]
        pos = np.einsum('nk,nkj->nj', b, tris[ids])
        nrm = normals[ids]
        view = eye - pos
        view /= np.linalg.norm(view, axis=1)[:, None]
        refl = 2 * np.einsum('ij,ij->i', nrm, view)[:, None] * nrm - view
        uv = np.einsum('nk,nkj->nj', b, uvs[ids])
        base = np.zeros((len(ids), 3))
        rough = np.zeros(len(ids))
        metal = np.zeros(len(ids))
        emit = np.zeros(len(ids))
        key_of = np.array([hash(k) for k in keys])
        for key in set(keys[i] for i in np.unique(ids)):
            m = self.resolver(key)
            sel = key_of[ids] == hash(key)
            if 'texture' in m:
                tex = m.setdefault('_lin', _srgb_to_linear(np.asarray(m['texture'].convert('RGB'))))
                th, tw = tex.shape[:2]
                u = np.clip((uv[sel, 0] * tw).astype(int), 0, tw - 1)
                v = np.clip((uv[sel, 1] * th).astype(int), 0, th - 1)
                base[sel] = tex[v, u]
            else:
                base[sel] = _srgb_to_linear(m['color'])
            rough[sel] = m.get('rough', .5)
            metal[sel] = m.get('metal', 0)
            emit[sel] = m.get('emit', 0)
        lights = [(np.array([-.45, -.7, .9]), np.array([1.5, 1.42, 1.35])),
                  (np.array([.8, -.3, .35]), np.array([.25, .45, .7])),
                  (np.array([-.6, .8, .5]), np.array([.6, .2, .45]))]
        diffuse = np.full((len(ids), 3), .06)
        spec = np.zeros((len(ids), 3))
        shin = 2 / np.maximum(rough, .04) ** 2
        for d, c in lights:
            d = d / np.linalg.norm(d)
            ndl = np.clip(nrm @ d, 0, 1)
            diffuse += ndl[:, None] * c
            hv = d + view
            hv /= np.linalg.norm(hv, axis=1)[:, None]
            ndh = np.clip(np.einsum('ij,ij->i', nrm, hv), 0, 1)
            spec += (ndh ** shin * (shin + 2) / 8 * ndl)[:, None] * c
        env = environment(refl)
        blur = np.clip(rough, 0, 1)[:, None]
        env = env * (1 - blur) + blur * np.array([.12, .11, .14])
        fres = .04 + .96 * (1 - np.clip(np.einsum('ij,ij->i', nrm, view), 0, 1)) ** 5
        dielectric = base * diffuse + (fres[:, None] * (env + spec * .5)) * (1 - rough[:, None] * .7)
        metallic = base * (env * .9 + spec * .6 + .03)
        col = dielectric * (1 - metal[:, None]) + metallic * metal[:, None]
        e = base * emit[:, None]
        col += e
        img[hit] = col
        emis[hit] = e
        img *= exposure
        if bloom and emis.max() > 0:
            em = Image.fromarray((np.clip(emis * exposure, 0, 4) / 4 * 255).astype(np.uint8), 'RGB')
            halo = np.asarray(em.filter(ImageFilter.GaussianBlur(10 * ss)), np.float32) / 255 * 4
            halo2 = np.asarray(em.filter(ImageFilter.GaussianBlur(30 * ss)), np.float32) / 255 * 4
            img += halo * .7 + halo2 * .5
        # Filmic-ish tone curve.
        img = img / (1 + img * .35)
        out = (_linear_to_srgb(img) * 255).astype(np.uint8)
        return Image.fromarray(out, 'RGB').resize(size, Image.Resampling.LANCZOS)


def contact_sheet(images, columns=2, gap=8, background=(8, 8, 12)):
    w = max(i.width for i in images)
    h = max(i.height for i in images)
    rows = (len(images) + columns - 1) // columns
    sheet = Image.new('RGB', (columns * w + (columns + 1) * gap, rows * h + (rows + 1) * gap), background)
    for k, im in enumerate(images):
        sheet.paste(im, (gap + (k % columns) * (w + gap), gap + (k // columns) * (h + gap)))
    return sheet
