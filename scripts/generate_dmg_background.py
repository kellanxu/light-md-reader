#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Assets"
OUTPUT = ASSETS / "DMGBackground.png"


def font(size, bold=False):
    candidates = [
        ("/System/Library/Fonts/PingFang.ttc", 1 if bold else 0),
        ("/System/Library/Fonts/STHeiti Light.ttc", 0),
        ("/System/Library/Fonts/Supplemental/Arial Unicode.ttf", 0),
        ("/System/Library/Fonts/Helvetica.ttc", 1 if bold else 0),
    ]
    for path, index in candidates:
        try:
            return ImageFont.truetype(path, size=size, index=index)
        except Exception:
            continue
    return ImageFont.load_default()


def main():
    ASSETS.mkdir(exist_ok=True)
    scale = 2
    width, height = 640 * scale, 420 * scale
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

    draw.rounded_rectangle([n(42), n(42), n(598), n(378)], radius=n(28), fill="#ffffff", outline="#d8e0eb", width=n(2))
    draw.text((n(72), n(74)), "Install LightMD Reader", fill="#1d2433", font=font(n(28), bold=True))
    draw.text((n(72), n(116)), "Drag LightMD Reader to the Applications folder", fill="#667085", font=font(n(16)))

    draw.line([(n(250), n(246)), (n(390), n(246))], fill="#1769e0", width=n(5))
    draw.polygon([(n(390), n(246)), (n(368), n(232)), (n(368), n(260))], fill="#1769e0")

    draw.text((n(72), n(346)), "Open .md files directly after installation", fill="#98a2b3", font=font(n(13)))
    img.save(OUTPUT)
    print(f"Generated {OUTPUT}")


if __name__ == "__main__":
    main()
