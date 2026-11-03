#!/usr/bin/env python3
"""Geometry checks shared by the casino prop builders (verify steps).

Faces are the builders' authored triangles: {'a','b','c': [x,y,z], 'color': key}
in unscaled metres (the client renders the casino props at 0.65).

* `coplanar_overlaps`: pairs of triangles of different material groups lying in
  the same plane (either facing, within `tol`) whose areas overlap. Such pairs
  z-fight in game: the depth test cannot order two surfaces at one depth, so
  the visible colour flickers between them as the camera moves. Contact faces
  (an object's base on the top, a box sitting on a box) are included: one of
  the two is always hidden, so the builders leave it out.
* `see_through`: rays from viewing positions to every triangle; the first
  surface a ray meets must face the viewer. A back face there is a hole the
  engine (which culls back faces) shows as a slit of background.

Imported by tools/build-casino-blackjack-props.py and
tools/build-casino-slots-props.py; it writes nothing.
"""
import bisect
import math
import numpy as np


def _arrays(faces):
    tri = np.array([[f['a'], f['b'], f['c']] for f in faces], dtype=np.float64)
    n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    area2 = np.linalg.norm(n, axis=1)
    return tri, n / np.maximum(area2, 1e-30)[:, None], area2 / 2


def _clip(poly, a, b):
    """Keep the part of a convex 2D polygon left of the directed edge a->b."""
    out = []
    def side(p): return (b[0]-a[0])*(p[1]-a[1]) - (b[1]-a[1])*(p[0]-a[0])
    for i, p in enumerate(poly):
        q = poly[(i+1) % len(poly)]
        sp, sq = side(p), side(q)
        if sp >= 0: out.append(p)
        if (sp >= 0) != (sq >= 0):
            t = sp / (sp - sq)
            out.append((p[0]+(q[0]-p[0])*t, p[1]+(q[1]-p[1])*t))
    return out


def _area(poly):
    return abs(sum(poly[i][0]*poly[(i+1) % len(poly)][1]-poly[(i+1) % len(poly)][0]*poly[i][1] for i in range(len(poly))))/2


def overlap_area(t1, t2, normal):
    """Area shared by two (near-)coplanar triangles, both projected on t1's plane."""
    u = t1[1]-t1[0]; u = u/np.linalg.norm(u); v = np.cross(normal, u)
    p1 = [(float(np.dot(p-t1[0], u)), float(np.dot(p-t1[0], v))) for p in t1]
    p2 = [(float(np.dot(p-t1[0], u)), float(np.dot(p-t1[0], v))) for p in t2]
    for poly in (p1, p2):   # counter-clockwise for the clipper
        if (poly[1][0]-poly[0][0])*(poly[2][1]-poly[0][1])-(poly[1][1]-poly[0][1])*(poly[2][0]-poly[0][0]) < 0: poly.reverse()
    clipped = p2
    for i in range(3):
        if not clipped: return 0.0
        clipped = _clip(clipped, p1[i], p1[(i+1) % 3])
    return _area(clipped) if len(clipped) >= 3 else 0.0


def coplanar_overlaps(faces, tol=.001, angle=.6, min_area=2e-7, same_material=lambda key: False):
    """Pairs (i, j, material_i, material_j, overlap m^2, plane gap m) of triangles
    whose planes are parallel within `angle` degrees, `tol` metres apart (either
    facing) and whose projections overlap by more than `min_area`. Pairs of one
    material are skipped unless `same_material(key)` (e.g. textured groups,
    whose UVs differ)."""
    if not faces: return []
    tri, n, area = _arrays(faces)
    keep = area > 1e-12
    canon = n.copy()
    big = np.argmax(np.abs(n), axis=1)
    sign = np.sign(n[np.arange(len(n)), big]); canon *= sign[:, None]
    d = np.einsum('ij,ij->i', canon, tri[:, 0])
    cos_limit = math.cos(math.radians(angle))
    reach = float(np.abs(tri).max()) * math.sin(math.radians(angle)) * 2 + tol
    step = 40.0
    keys = np.round(canon*step).astype(int)
    buckets = {}
    for i in np.nonzero(keep)[0]:
        buckets.setdefault(tuple(keys[i]), []).append(i)
    sorted_buckets = {}
    for k, idx in buckets.items():
        idx.sort(key=lambda i: d[i]); sorted_buckets[k] = (idx, [d[i] for i in idx])
    lo, hi = tri.min(axis=1), tri.max(axis=1)
    colors = [f['color'] for f in faces]
    found = []
    offsets = [(a, b, c) for a in (-1, 0, 1) for b in (-1, 0, 1) for c in (-1, 0, 1)]
    for i in np.nonzero(keep)[0]:
        ki = keys[i]
        for o in offsets:
            entry = sorted_buckets.get((ki[0]+o[0], ki[1]+o[1], ki[2]+o[2]))
            if not entry: continue
            idx, ds = entry
            start = bisect.bisect_left(ds, d[i]-reach)
            for pos in range(start, len(idx)):
                j = idx[pos]
                if ds[pos] > d[i]+reach: break
                if j <= i: continue
                if colors[i] == colors[j] and not same_material(colors[i]): continue
                if abs(float(np.dot(n[i], n[j]))) < cos_limit: continue
                if np.any(lo[i] > hi[j]+tol) or np.any(lo[j] > hi[i]+tol): continue
                gap = float(np.max(np.abs((tri[j]-tri[i][0]) @ n[i])))
                if gap > tol: continue
                shared = overlap_area(tri[i], tri[j], n[i])
                if shared > min_area: found.append((int(i), int(j), colors[i], colors[j], shared, gap))
    return found


def describe(faces, pairs, limit=8):
    lines = []
    for i, j, ci, cj, shared, gap in pairs[:limit]:
        c1 = np.mean([faces[i][k] for k in 'abc'], axis=0); c2 = np.mean([faces[j][k] for k in 'abc'], axis=0)
        lines.append(f'{ci} @ {np.round(c1, 4).tolist()} vs {cj} @ {np.round(c2, 4).tolist()}: {shared*1e6:.1f} mm2, gap {gap*1e3:.2f} mm')
    return '\n'.join(lines)


def see_through(faces, eyes, ignore=lambda key: False, chunk=64):
    """For each eye and each triangle (centroid nudged towards its incentre),
    the first triangle on the ray must face the eye. Returns the offending
    (eye index, triangle index, material) list."""
    tri, n, area = _arrays(faces)
    keep = area > 1e-10
    e1, e2 = tri[:, 1]-tri[:, 0], tri[:, 2]-tri[:, 0]
    targets = tri.mean(axis=1)
    bad = []
    for ei, eye in enumerate(np.asarray(eyes, dtype=np.float64)):
        candidates = np.nonzero(keep)[0]
        for s in range(0, len(candidates), chunk):
            rows = candidates[s:s+chunk]
            D = targets[rows]-eye; dist = np.linalg.norm(D, axis=1); D = D/dist[:, None]
            P = np.cross(D[:, None, :], e2[None, :, :])
            det = np.einsum('rtk,tk->rt', P, e1)
            ok = np.abs(det) > 1e-14
            inv = np.where(ok, 1/np.where(ok, det, 1), 0)
            T = eye[None, :]-tri[:, 0]
            u = np.einsum('tk,rtk->rt', T, P)*inv
            Q = np.cross(T, e1)                  # independent of the ray direction
            v = np.einsum('rk,tk->rt', D, Q)*inv
            t = (np.einsum('tk,tk->t', e2, Q)[None, :])*inv
            hit = ok & (u >= -1e-9) & (v >= -1e-9) & (u+v <= 1+1e-9) & (t > 1e-6) & keep[None, :]
            t = np.where(hit, t, np.inf)
            first = np.argmin(t, axis=1)
            tfirst = t[np.arange(len(rows)), first]
            for r, row in enumerate(rows):
                f = first[r]
                if not math.isfinite(tfirst[r]): continue
                facing = float(np.dot(n[f], D[r]))
                if abs(facing) < .02: continue        # grazing: edge-on, not a hole
                if facing > 0 and not ignore(faces[f]['color']):
                    bad.append((ei, int(f), faces[f]['color']))
    return bad
