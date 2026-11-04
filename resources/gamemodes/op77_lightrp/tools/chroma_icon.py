"""Cut an item icon out of a flat chroma-green render (Gemini / Nano Banana has no real alpha) into the inventory format.

Usage: chroma_icon.py <render.jpg|png> <out.png> [--size 1254] [--fill 0.8]

Only the green connected to the image border becomes background, so a green logo inside the object stays. The edge
gets a soft alpha from how green each pixel is, and the green spill on the remaining edge pixels is removed. The
object is then trimmed and centred on a transparent square canvas, filling `--fill` of it (the other icons: ~80 %).
"""
import argparse

import numpy as np
from PIL import Image
from scipy import ndimage

ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("out")
ap.add_argument("--size", type=int, default=1254)
ap.add_argument("--fill", type=float, default=0.8)
a = ap.parse_args()

rgb = np.asarray(Image.open(a.src).convert("RGB")).astype(np.float32)
r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
green = g - np.maximum(r, b)                      # ~255 on the backdrop, small or negative on the object

# Background = strongly green regions that touch the border.
candidate = green > 110
labels, _ = ndimage.label(candidate)
border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
background = np.isin(labels, border[border > 0])
# Enclosed holes (a booster's hang hole) show the backdrop too: pure chroma pixels, far greener than any logo.
pure = (g > 225) & (r < 70) & (b < 70)
holes, n = ndimage.label(pure)
if n:
    sizes = ndimage.sum(pure, holes, range(1, n + 1))
    background |= np.isin(holes, 1 + np.flatnonzero(sizes > 60))

# Soft edge: within a few pixels of the background, alpha falls with greenness (anti-aliased fringe).
near = ndimage.binary_dilation(background, iterations=3)
alpha = np.ones_like(g)
soft = np.clip((green - 40.0) / (200.0 - 40.0), 0.0, 1.0)
alpha[near] = 1.0 - soft[near]
alpha[background] = 0.0
alpha = ndimage.gaussian_filter(alpha, 0.6)
alpha[background & (green > 200)] = 0.0

# Despill: edge pixels keep no more green than their strongest other channel.
spill = near & (alpha > 0)
g2 = g.copy()
g2[spill] = np.minimum(g[spill], np.maximum(r[spill], b[spill]) + 8)
out = np.dstack([r, g2, b, alpha * 255.0]).clip(0, 255).astype(np.uint8)
img = Image.fromarray(out, "RGBA")

# Trim to the object and centre it on the inventory canvas.
box = img.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
img = img.crop(box)
scale = a.size * a.fill / max(img.size)
img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
canvas = Image.new("RGBA", (a.size, a.size), (0, 0, 0, 0))
canvas.alpha_composite(img, ((a.size - img.width) // 2, (a.size - img.height) // 2))
canvas.save(a.out, optimize=True)
print(a.out, canvas.size, "object", img.size)
