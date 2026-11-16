"""Builds the Light RP server-check art (the launcher's preflight screens).

Output: resources/system/open77_preflight/ui/custom/
  lightrp-hero.jpg      1600 x 440  welcome banner: skyline, wordmark, brand line
  lightrp-strip.jpg     1600 x 200  header of the join screens (yellow)
  lightrp-strip-red.jpg 1600 x 200  header of the refusal screens (red)
  lightrp-hazard.png    1600 x 8    the design system's hazard stripe (--tex-hazard)

Sources (all in this repo): the loadscreen skyline (op77_loadscreen/web/img/skyline.webp),
the fonts of the design system (Zen Dots ttf from ui/native/fonts, Chakra Petch and Share
Tech Mono woff2 from ui/public/fonts). Needs Pillow and fontTools (+ brotli for woff2).

    python tools/build-preflight-art.py
"""
import io
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "resources", "system", "open77_preflight", "ui", "custom")
SKYLINE = os.path.join(ROOT, "resources", "standalone", "op77_loadscreen", "web", "img", "skyline.webp")
ZEN_DOTS = os.path.join(ROOT, "resources", "gamemodes", "op77_lightrp", "ui", "native", "fonts", "zen-dots-400.ttf")
SHARE_TECH = os.path.join(ROOT, "resources", "gamemodes", "op77_lightrp", "ui", "native", "fonts", "share-tech-mono-400.ttf")
CHAKRA_700 = os.path.join(ROOT, "ui", "public", "fonts", "chakra-petch-700-latin.woff2")

BLACK = (5, 5, 6)
INK_900 = (10, 10, 12)
YELLOW = (255, 204, 0)
RED = (255, 46, 60)
WHITE = (242, 243, 245)
DIM = (138, 143, 156)


def woff2_font(path, size):
    from fontTools.ttLib import TTFont
    font = TTFont(path)
    font.flavor = None
    buffer = io.BytesIO()
    font.save(buffer)
    buffer.seek(0)
    return ImageFont.truetype(buffer, size)


def cover(image, width, height, focus_y=0.55):
    """Scales and crops `image` to fill width x height, keeping the band around focus_y."""
    scale = max(width / image.width, height / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    top = int(max(0, min(resized.height - height, resized.height * focus_y - height / 2)))
    left = (resized.width - width) // 2
    return resized.crop((left, top, left + width, top + height))


def horizontal_shade(width, height, stops):
    """A black overlay whose alpha follows `stops` [(x 0..1, alpha 0..255)] left to right."""
    mask = Image.new("L", (width, 1))
    for x in range(width):
        t = x / (width - 1)
        for (x0, a0), (x1, a1) in zip(stops, stops[1:]):
            if x0 <= t <= x1:
                k = (t - x0) / max(1e-6, x1 - x0)
                mask.putpixel((x, 0), round(a0 + (a1 - a0) * k))
                break
    return mask.resize((width, height))


def vertical_shade(width, height, top_alpha, bottom_alpha):
    mask = Image.new("L", (1, height))
    for y in range(height):
        mask.putpixel((0, y), round(top_alpha + (bottom_alpha - top_alpha) * y / (height - 1)))
    return mask.resize((width, height))


def darken(image, mask, color=BLACK):
    layer = Image.new("RGB", image.size, color)
    return Image.composite(layer, image, mask)


def scanlines(image, alpha=10):
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for y in range(0, image.height, 3):
        draw.line([(0, y), (image.width, y)], fill=(255, 255, 255, alpha))
    return Image.alpha_composite(image.convert("RGBA"), overlay).convert("RGB")


def tint(image, color, amount):
    gray = image.convert("L")
    colored = Image.merge("RGB", [gray.point(lambda v, c=c: round(v * c / 255)) for c in color])
    return Image.blend(image, colored, amount)


def tracked(draw, position, text, font, fill, tracking):
    """Text with letter-spacing (the design system's 0.14 / 0.22 em labels)."""
    x, y = position
    for char in text:
        draw.text((x, y), char, font=font, fill=fill)
        x += draw.textlength(char, font=font) + tracking
    return x


def hazard(width, height, band=12):
    image = Image.new("RGB", (width, height), BLACK)
    draw = ImageDraw.Draw(image)
    for x in range(-height * 2, width + height * 2, band * 2):
        draw.polygon([(x, height), (x + band, height), (x + band + height, 0), (x + height, 0)], fill=YELLOW)
    return image


def accent_frame(draw, width, height, color):
    # The chamfered-corner brackets of the design system (clip-chamfer) as corner marks.
    size, stroke = 26, 3
    draw.line([(18, 18 + size), (18, 18), (18 + size, 18)], fill=color, width=stroke)
    draw.line([(width - 18 - size, height - 18), (width - 18, height - 18), (width - 18, height - 18 - size)], fill=color, width=stroke)


def hero(skyline, fonts):
    width, height = 1600, 440
    image = cover(skyline, width, height, focus_y=0.42)
    image = darken(image, horizontal_shade(width, height, [(0, 245), (0.36, 225), (0.6, 70), (1, 0)]))
    image = darken(image, vertical_shade(width, height, 20, 130))
    image = scanlines(image)
    draw = ImageDraw.Draw(image)
    accent_frame(draw, width, height, YELLOW)
    left = 72
    tracked(draw, (left, 92), "OPEN//77  //  OFFICIAL ROLEPLAY", fonts["mono22"], YELLOW, 5)
    draw.text((left - 4, 132), "LIGHT RP", font=fonts["display112"], fill=WHITE)
    draw.rectangle([left, 284, left + 64, 290], fill=YELLOW)
    tracked(draw, (left + 84, 272), "WELCOME TO NIGHT CITY", fonts["core30"], WHITE, 6)
    tracked(draw, (left, 322), "LIVE YOUR LIFE  ·  EARN YOUR EDDIES  ·  NO PRESSURE", fonts["mono20"], DIM, 4)
    return image


def strip(skyline, fonts, color, label):
    width, height = 1600, 200
    image = cover(skyline, width, height, focus_y=0.30)
    if color == RED:
        image = tint(image, RED, 0.9)
    image = darken(image, horizontal_shade(width, height, [(0, 240), (0.42, 215), (0.75, 90), (1, 30)]))
    image = darken(image, vertical_shade(width, height, 40, 170))
    image = scanlines(image)
    draw = ImageDraw.Draw(image)
    accent_frame(draw, width, height, color)
    left = 72
    tracked(draw, (left, 48), "OPEN//77  //  OFFICIAL ROLEPLAY", fonts["mono26"], color, 6)
    draw.text((left - 4, 84), "LIGHT RP", font=fonts["display84"], fill=WHITE)
    mark = left + draw.textlength("LIGHT RP", font=fonts["display84"]) + 36
    tracked(draw, (mark, 126), label, fonts["mono26"], WHITE, 6)
    return image


def main():
    os.makedirs(OUT, exist_ok=True)
    skyline = Image.open(SKYLINE).convert("RGB")
    fonts = {
        "display112": ImageFont.truetype(ZEN_DOTS, 112),
        "display84": ImageFont.truetype(ZEN_DOTS, 84),
        "mono20": ImageFont.truetype(SHARE_TECH, 20),
        "mono22": ImageFont.truetype(SHARE_TECH, 22),
        "mono26": ImageFont.truetype(SHARE_TECH, 26),
        "core30": woff2_font(CHAKRA_700, 30),
    }
    outputs = {
        "lightrp-hero.jpg": hero(skyline, fonts),
        "lightrp-strip.jpg": strip(skyline, fonts, YELLOW, "//  SERVER CHECK"),
        "lightrp-strip-red.jpg": strip(skyline, fonts, RED, "//  ACCESS DENIED"),
        "lightrp-hazard.png": hazard(1600, 8),
    }
    for name, image in outputs.items():
        path = os.path.join(OUT, name)
        if name.endswith(".jpg"):
            image.save(path, quality=84, optimize=True, progressive=True)
        else:
            image.save(path, optimize=True)
        print(f"{name}: {image.width}x{image.height}, {os.path.getsize(path) // 1024} KiB")


if __name__ == "__main__":
    sys.exit(main())
