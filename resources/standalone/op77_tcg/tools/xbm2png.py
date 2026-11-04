"""Decode WolvenKit-serialized CBitmapTexture JSON (DXT1/DXT5 mip 0) to an image.

WolvenKit 8.19 fails to write the DDS header for these textures (NullReference in DDSUtils.GenerateHeader), so this
writes a legacy DDS header (DXT1/DXT5) around mip 0 of the serialized blob and lets Pillow decode it.
Usage: xbm2png.py <json> <out.png|.webp> [maxWidth]
"""
import base64
import io
import json
import struct
import sys

from PIL import Image

FOURCC = {"TCM_DXTAlpha": b"DXT5", "TCM_DXTNoAlpha": b"DXT1", "TCM_Normalmap": b"ATI2"}


def decode(path):
    root = json.load(open(path, encoding="utf-8"))["Data"]["RootChunk"]
    blob = root["renderTextureResource"]["renderResourceBlobPC"]["Data"]
    header = blob["header"]
    width, height = header["sizeInfo"]["width"], header["sizeInfo"]["height"]
    compression = root["setup"]["compression"]
    fourcc = FOURCC[compression]
    data = base64.b64decode(blob["textureData"]["Bytes"])
    mip0 = header["mipMapInfo"][0]
    pixels = data[mip0["placement"]["offset"]: mip0["placement"]["offset"] + mip0["placement"]["size"]]
    block = 8 if fourcc == b"DXT1" else 16
    linear = max(1, (width + 3) // 4) * max(1, (height + 3) // 4) * block
    dds = struct.pack("<4sIIIIIII44xII4s20xI16x", b"DDS ", 124, 0x1 | 0x2 | 0x4 | 0x1000 | 0x80000, height, width,
                      linear, 0, 1, 32, 0x4, fourcc, 0x1000)
    image = Image.open(io.BytesIO(dds + pixels[:linear]))
    image.load()
    return image.convert("RGBA")


CARD_RATIO = 88.0 / 63.0  # a standard trading card, 63 x 88 mm


def card(image, width):
    """A card print texture (stored bottom-up, 1:2) as the card face: flipped upright, at 63:88."""
    image = image.transpose(Image.FLIP_TOP_BOTTOM)
    return image.resize((width, round(width * CARD_RATIO)), Image.LANCZOS)


if __name__ == "__main__":
    image = decode(sys.argv[1])
    if len(sys.argv) > 3:
        w = int(sys.argv[3])
        if image.height == 2 * image.width:
            image = card(image, w)
        elif image.width > w:
            image = image.resize((w, round(image.height * w / image.width)), Image.LANCZOS)
    out = sys.argv[2]
    if out.endswith(".webp"):
        image.save(out, "WEBP", quality=88, method=6)
    else:
        image.save(out)
    print(out, image.size)
