#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Assets"
OUTPUT = ASSETS / "DMGBackground.png"


def main():
    ASSETS.mkdir(exist_ok=True)
    scale = 1
    width, height = 640, 360
    img = Image.new("RGB", (width, height), "#f7f9fc")
    draw = ImageDraw.Draw(img)

    for y in range(height):
        ratio = y / height
        r = int(247 * (1 - ratio) + 238 * ratio)
        g = int(249 * (1 - ratio) + 244 * ratio)
        b = int(252 * (1 - ratio) + 249 * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b))

    def n(value):
        return int(value * scale)

    draw.rounded_rectangle([n(42), n(42), n(598), n(318)], radius=n(28), fill="#ffffff", outline="#d8e0eb", width=n(2))

    draw.line([(n(250), n(190)), (n(390), n(190))], fill="#1769e0", width=n(6))
    draw.polygon([(n(390), n(190)), (n(366), n(174)), (n(366), n(206))], fill="#1769e0")
    img.save(OUTPUT)
    print(f"Generated {OUTPUT}")


if __name__ == "__main__":
    main()
