#!/usr/bin/env python3
"""Offline preview renderer for the roulette and Fortune Wheel prop builders.

A small numpy rasterizer, no GPU or 3D package required: z-buffer, perspective
correct UVs, the cooker's own smoothed normals and planar UVs, back-face
culling (a winding error shows up as a hole), a shadow map for the key light,
a procedural casino environment for metals, emissive materials with bloom and
a filmic tone map. It approximates the engine's metal_base look so the art can
be critiqued before cooking; it does not claim to match the game exactly.

Faces use the cookers' format: {'a','b','c' (RED4 Z-up metres),'color'
(material key), optional 'uv' (three [u,v], v down from the top of the
source image, as the engine shows it after FLIP_V)}.
"""
import math
import numpy as np
from PIL import Image, ImageFilter


class Mat:
    """base: linear RGB tuple or PIL image (sRGB); emit: linear RGB intensity;
    emit_map: optional PIL image masking the emission (sRGB)."""
    def __init__(self, base=(.5, .5, .5), metal=0., rough=.6, emit=None, emit_map=None, tile=False):
        self.base, self.metal, self.rough, self.emit, self.emit_map, self.tile = base, metal, rough, emit, emit_map, tile


def srgb(hex_or_tuple):
    """'#RRGGBB..' or 0-255 tuple to linear RGB."""
    if isinstance(hex_or_tuple, str):
        c = [int(hex_or_tuple[i:i + 2], 16) for i in (1, 3, 5)]
    else:
        c = list(hex_or_tuple)[:3]
    return tuple(((v / 255) / 12.92) if v / 255 <= .04045 else (((v / 255) + .055) / 1.055) ** 2.4 for v in c)


def _texture_array(image):
    a = np.asarray(image.convert('RGB'), dtype=np.float32) / 255
    return np.where(a <= .04045, a / 12.92, ((a + .055) / 1.055) ** 2.4)


def _sample(tex, uv):
    h, w, _ = tex.shape
    u = (uv[:, 0] % 1.0) * w - .5
    v = (uv[:, 1] % 1.0) * h - .5
    x0 = np.floor(u).astype(int); y0 = np.floor(v).astype(int)
    fx = (u - x0)[:, None]; fy = (v - y0)[:, None]
    x0 %= w; y0 %= h; x1 = (x0 + 1) % w; y1 = (y0 + 1) % h
    return (tex[y0, x0] * (1 - fx) * (1 - fy) + tex[y0, x1] * fx * (1 - fy) +
            tex[y1, x0] * (1 - fx) * fy + tex[y1, x1] * fx * fy)


def _normalize(v):
    n = np.linalg.norm(v, axis=-1, keepdims=True)
    return v / np.maximum(n, 1e-12)


def _prepare(faces):
    """Corner positions, smoothed normals (cooker rule: same colour, same
    position, neighbours within ~41 degrees) and UVs, in local coordinates."""
    P = np.array([[f['a'], f['b'], f['c']] for f in faces], dtype=np.float64)
    n = _normalize(np.cross(P[:, 1] - P[:, 0], P[:, 2] - P[:, 0]))
    colors = [f['color'] for f in faces]
    buckets = {}
    keys = np.round(P, 7)
    for i, c in enumerate(colors):
        for k in range(3):
            buckets.setdefault((c, *keys[i, k]), []).append(i)
    N = np.zeros_like(P)
    for i, c in enumerate(colors):
        for k in range(3):
            adj = buckets[(c, *keys[i, k])]
            if len(adj) == 1:
                N[i, k] = n[i]; continue
            cand = n[adj]
            sel = cand[cand @ n[i] > .75]
            s = sel.sum(axis=0)
            N[i, k] = s / max(np.linalg.norm(s), 1e-12)
    UV = np.zeros((len(faces), 3, 2))
    for i, f in enumerate(faces):
        if 'uv' in f:
            UV[i] = f['uv']; continue
        nx, ny, nz = n[i]
        p = P[i]
        if abs(nz) > .75: UV[i] = np.stack([p[:, 0] * 4, -p[:, 1] * 4], 1)
        elif abs(nx) > abs(ny): UV[i] = np.stack([p[:, 1] * 4, p[:, 2] * 4], 1)
        else: UV[i] = np.stack([p[:, 0] * 4, p[:, 2] * 4], 1)
    return P, N, UV, colors


_CACHE = {}


def place(faces, position=(0, 0, 0), yaw=0., scale=1.):
    """One scene item: faces turned `yaw` degrees about +Z then moved."""
    key = id(faces)
    if key not in _CACHE or _CACHE[key][0] is not faces:
        _CACHE[key] = (faces, _prepare(faces))
    P, N, UV, colors = _CACHE[key][1]
    a = math.radians(yaw); c, s = math.cos(a), math.sin(a)
    R = np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])
    return (P @ R.T) * scale + np.array(position), N @ R.T, UV, colors


def _raster(S, iz, W, H, cull, want_ids=True):
    """S: (n,3,2) screen points, iz: (n,3) 1/depth. Returns depth (1/z), ids, barycentrics."""
    zbuf = np.zeros((H, W), np.float64)
    ids = np.full((H, W), -1, np.int64) if want_ids else None
    b0 = np.zeros((H, W), np.float32) if want_ids else None
    b1 = np.zeros((H, W), np.float32) if want_ids else None
    x, y = S[..., 0], S[..., 1]
    area = (x[:, 1] - x[:, 0]) * (y[:, 2] - y[:, 0]) - (x[:, 2] - x[:, 0]) * (y[:, 1] - y[:, 0])
    keep = np.abs(area) > 1e-9
    if cull == 'back':
        keep &= area < 0
    lo_x = np.clip(np.floor(x.min(1)), 0, W - 1).astype(int); hi_x = np.clip(np.ceil(x.max(1)), 0, W - 1).astype(int)
    lo_y = np.clip(np.floor(y.min(1)), 0, H - 1).astype(int); hi_y = np.clip(np.ceil(y.max(1)), 0, H - 1).astype(int)
    keep &= (x.max(1) >= 0) & (x.min(1) < W) & (y.max(1) >= 0) & (y.min(1) < H)
    # Edge functions w_i = A_i x + B_i y + C_i, normalised by the area.
    A = np.stack([y[:, 1] - y[:, 2], y[:, 2] - y[:, 0], y[:, 0] - y[:, 1]], 1)
    B = np.stack([x[:, 2] - x[:, 1], x[:, 0] - x[:, 2], x[:, 1] - x[:, 0]], 1)
    C = np.stack([x[:, 1] * y[:, 2] - x[:, 2] * y[:, 1], x[:, 2] * y[:, 0] - x[:, 0] * y[:, 2], x[:, 0] * y[:, 1] - x[:, 1] * y[:, 0]], 1)
    with np.errstate(divide='ignore', invalid='ignore'):
        A = A / area[:, None]; B = B / area[:, None]; C = C / area[:, None]
    for t in np.nonzero(keep)[0]:
        x0, x1, y0, y1 = lo_x[t], hi_x[t], lo_y[t], hi_y[t]
        xs = np.arange(x0, x1 + 1) + .5; ys = (np.arange(y0, y1 + 1) + .5)[:, None]
        w0 = A[t, 0] * xs + B[t, 0] * ys + C[t, 0]
        w1 = A[t, 1] * xs + B[t, 1] * ys + C[t, 1]
        w2 = 1 - w0 - w1
        inside = (w0 >= -1e-7) & (w1 >= -1e-7) & (w2 >= -1e-7)
        if not inside.any():
            continue
        z = w0 * iz[t, 0] + w1 * iz[t, 1] + w2 * iz[t, 2]
        region = zbuf[y0:y1 + 1, x0:x1 + 1]
        m = inside & (z > region)
        if not m.any():
            continue
        region[m] = z[m]
        if want_ids:
            ids[y0:y1 + 1, x0:x1 + 1][m] = t
            b0[y0:y1 + 1, x0:x1 + 1][m] = w0[m]
            b1[y0:y1 + 1, x0:x1 + 1][m] = w1[m]
    return zbuf, ids, b0, b1


def _env(R):
    """Procedural high-roller casino: dark room, warm ceiling panels, cyan and
    magenta neon strips low on the walls, a faint floor."""
    x, y, z = R[:, 0], R[:, 1], R[:, 2]
    col = np.zeros_like(R) + np.array([.012, .012, .016])
    up = np.clip(z, 0, 1)
    col += np.array([.05, .05, .06])[None] * up[:, None] ** 1.5
    az = np.arctan2(y, x)
    panel = (z > .55) & (np.cos(az * 3) > .55)
    col[panel] += np.array([1.6, 1.45, 1.25])
    band = (np.abs(z - .12) < .05)
    col[band & (np.sin(az * 2) > 0)] += np.array([.05, .55, .75])
    col[band & (np.sin(az * 2) <= 0)] += np.array([.65, .06, .45])
    col[z < -.05] = np.array([.008, .008, .01])
    return col


def _box(a, r, axis):
    """Box filter of half-width r along an axis (cumulative sums, edge clamped)."""
    if r < 1:
        return a
    pad = [(0, 0)] * a.ndim; pad[axis] = (r + 1, r)
    c = np.cumsum(np.pad(a, pad, mode='edge'), axis=axis)
    n = a.shape[axis]
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return (hi - lo) / (2 * r + 1)


def _blur(img, radius):
    """Approximate gaussian: three box passes on a 4x downsampled copy."""
    h, w, _ = img.shape
    k = 4
    small = img[:h - h % k, :w - w % k].reshape(h // k, k, w // k, k, 3).mean((1, 3))
    r = max(1, int(round(radius / k / 1.7)))
    for _ in range(3):
        small = _box(_box(small, r, 0), r, 1)
    up = np.repeat(np.repeat(small, k, 0), k, 1)
    out = np.zeros_like(img)
    out[:up.shape[0], :up.shape[1]] = up
    return out


def render(items, materials, path, eye, target, fov=40., size=(1280, 800), ss=2, light=(-.45, -.7, .9),
           background=((5, 6, 9), (16, 18, 26)), exposure=1.25, floor_z=None):
    """items: list of place(...) results; materials: key -> Mat."""
    W, H = size[0] * ss, size[1] * ss
    P = np.concatenate([i[0] for i in items]); N = np.concatenate([i[1] for i in items])
    UV = np.concatenate([i[2] for i in items]); colors = sum((list(i[3]) for i in items), [])
    keys = sorted(set(colors), key=str)
    mat_index = {k: j for j, k in enumerate(keys)}
    M = np.array([mat_index[c] for c in colors])
    if floor_z is not None:
        s = 12.
        fp = np.array([[[-s, -s, floor_z], [s, -s, floor_z], [s, s, floor_z]], [[-s, -s, floor_z], [s, s, floor_z], [-s, s, floor_z]]])
        P = np.concatenate([P, fp]); N = np.concatenate([N, np.tile([0, 0, 1.], (2, 3, 1))])
        UV = np.concatenate([UV, np.zeros((2, 3, 2))]); M = np.concatenate([M, [len(keys)] * 2])
        keys = keys + ['__floor']; materials = dict(materials); materials['__floor'] = Mat(srgb((14, 15, 19)), .2, .35)
    eye = np.array(eye, float); target = np.array(target, float)
    f = _normalize(target - eye); r = _normalize(np.cross(f, [0, 0, 1])); u = np.cross(r, f)
    rel = P - eye
    cx, cy, cz = rel @ r, rel @ u, rel @ f
    ok = (cz > .05).all(1)
    fpx = (H / 2) / math.tan(math.radians(fov) / 2)
    S = np.stack([W / 2 + cx / np.maximum(cz, 1e-6) * fpx, H / 2 - cy / np.maximum(cz, 1e-6) * fpx], -1)
    idx = np.nonzero(ok)[0]
    zbuf, ids, b0, b1 = _raster(S[idx], 1 / cz[idx], W, H, 'back')
    valid = ids >= 0
    tri = idx[ids[valid]]
    w0 = b0[valid].astype(np.float64); w1 = b1[valid].astype(np.float64); w2 = 1 - w0 - w1
    izc = 1 / cz[tri]
    iz = w0 * izc[:, 0] + w1 * izc[:, 1] + w2 * izc[:, 2]
    bc = np.stack([w0 * izc[:, 0], w1 * izc[:, 1], w2 * izc[:, 2]], 1) / iz[:, None]
    pos = np.einsum('nk,nkc->nc', bc, P[tri])
    nrm = _normalize(np.einsum('nk,nkc->nc', bc, N[tri]))
    uv = np.einsum('nk,nkc->nc', bc, UV[tri])
    view = _normalize(eye - pos)
    # Two-sided safety for thin parts seen from behind (culling already hides most).
    flip = (nrm * view).sum(1) < 0
    nrm[flip] *= -1
    # Shadow map from the key light (orthographic).
    L = _normalize(np.array(light, float))
    lr = _normalize(np.cross(L, [0, 1, 0]) if abs(L[1]) < .9 else np.cross(L, [1, 0, 0])); lu = np.cross(lr, L)
    base_pts = P[:-2] if floor_z is not None else P
    ext = np.concatenate([base_pts.reshape(-1, 3) @ lr, base_pts.reshape(-1, 3) @ lu])
    span = np.abs(ext).max() * 1.1 + 1e-6
    SM = 2048
    def light_xy(q):
        return np.stack([(q @ lr / span * .5 + .5) * SM, (.5 - q @ lu / span * .5) * SM], -1)
    LS = light_xy(P[:-2] if floor_z is not None else P)
    ldepth = (P[:-2] if floor_z is not None else P) @ L  # larger = closer to the light
    lz, _, _, _ = _raster(LS, ldepth + 100, SM, SM, None, want_ids=False)
    q = light_xy(pos)
    qx = np.clip(q[:, 0].astype(int), 0, SM - 1); qy = np.clip(q[:, 1].astype(int), 0, SM - 1)
    occl = np.zeros(len(pos))
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            d = lz[np.clip(qy + dy, 0, SM - 1), np.clip(qx + dx, 0, SM - 1)]
            occl += (d > pos @ L + 100 + .004 + .002 * (1 - np.clip(nrm @ L, 0, 1)))
    lit = 1 - occl / 9
    col = np.zeros((len(pos), 3))
    mi = M[tri]
    for j, key in enumerate(keys):
        sel = mi == j
        if not sel.any():
            continue
        m = materials.get(key) or Mat()
        if isinstance(m.base, Image.Image):
            if not hasattr(m, '_tex'): m._tex = _texture_array(m.base)
            alb = _sample(m._tex, uv[sel])
        else:
            alb = np.tile(np.array(m.base, float), (sel.sum(), 1))
        n_ = nrm[sel]; v_ = view[sel]; sh = lit[sel][:, None]
        rough = max(m.rough, .03)
        F0 = .04 * (1 - m.metal) + alb * m.metal
        nl = np.clip(n_ @ L, 0, 1)[:, None]
        fill = _normalize(np.array([.7, -.3, .35])); rim = _normalize(np.array([.2, .9, .4]))
        diff = (nl * 2.4 * sh + np.clip(n_ @ fill, 0, 1)[:, None] * .45 + np.clip(n_ @ rim, 0, 1)[:, None] * .35
                + (.10 + .05 * n_[:, 2:3]))
        col_ = alb * (1 - m.metal) * diff
        hv = _normalize(L + v_)
        shin = 2 / (rough ** 4 + 1e-4) - 2
        spec = np.clip((n_ * hv).sum(1), 0, 1)[:, None] ** min(shin, 4000) * (shin + 8) / (8 * math.pi)
        nv = np.clip((n_ * v_).sum(1), 0, 1)[:, None]
        F = F0 + (1 - F0) * (1 - nv) ** 5 * (1 - rough)
        col_ += F * spec * nl * 2.4 * sh * .6
        Rr = _normalize(2 * (n_ * v_).sum(1)[:, None] * n_ - v_)
        env = _env(Rr)
        env_avg = np.array([.09, .085, .09])
        env = env * (1 - rough) ** 1.5 + env_avg * (1 - (1 - rough) ** 1.5)
        col_ += F * env * (1.0 if m.metal > .5 else .8)
        if m.emit is not None:
            e = np.array(m.emit, float)[None]
            if m.emit_map is not None:
                if not hasattr(m, '_etex'): m._etex = _texture_array(m.emit_map)
                e = e * _sample(m._etex, uv[sel])
            col_ += e
        col[sel] = col_
    img = np.zeros((H, W, 3), np.float32)
    # Background: dark vertical gradient.
    t = np.linspace(0, 1, H)[:, None, None]
    top, bottom = np.array(srgb(background[1])), np.array(srgb(background[0]))
    img[:] = (top * (1 - t) + bottom * t)
    img[valid] = col
    if floor_z is not None:
        # Fade the floor into the background with distance.
        fl = valid.copy(); fl[valid] = mi == len(keys) - 1
        d = np.zeros((H, W)); d[valid] = np.linalg.norm(pos - eye, axis=1)
        fade = np.clip((d - 3) / 6, 0, 1)[..., None]
        img = np.where(fl[..., None], img * (1 - fade) + (top * (1 - t) + bottom * t) * fade, img)
    img *= exposure
    bright = np.clip(img - .9, 0, None)
    bloom = _blur(bright, W / 220) * .55 + _blur(bright, W / 70) * .35 + _blur(bright, W / 25) * .2
    img = img + bloom
    a, b_, c_, d_, e_ = 2.51, .03, 2.43, .59, .14
    img = np.clip((img * (a * img + b_)) / (img * (c_ * img + d_) + e_), 0, 1)
    img = np.where(img <= .0031308, img * 12.92, 1.055 * np.power(img, 1 / 2.4) - .055)
    out = Image.fromarray((np.clip(img, 0, 1) * 255 + .5).astype(np.uint8))
    out = out.resize(size, Image.Resampling.LANCZOS)
    out.save(path, optimize=True)
    return out


def sheet(images, path, cols=2, label=None):
    """Tile several renders into one contact sheet."""
    w, h = images[0].size
    rows = (len(images) + cols - 1) // cols
    out = Image.new('RGB', (w * cols, h * rows), (0, 0, 0))
    for i, im in enumerate(images):
        out.paste(im, ((i % cols) * w, (i // cols) * h))
    out.save(path, optimize=True)
    return out
