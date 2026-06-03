#!/usr/bin/env python3
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Assets"
OUTPUT = ASSETS / "DMGBackground.png"
OUTPUT_2X = ASSETS / "DMGBackground@2x.png"
OUTPUT_TIFF = ASSETS / "DMGBackground.tiff"


def font(size, bold=False):
    candidates = [
        ("/System/Library/Fonts/PingFang.ttc", 1 if bold else 0),
        ("/System/Library/Fonts/PingFang.ttc", 0),
        ("/System/Library/Fonts/STHeiti Medium.ttc", 1 if bold else 0),
        ("/System/Library/Fonts/Supplemental/Arial Unicode.ttf", 0),
    ]
    for path, index in candidates:
        try:
            return ImageFont.truetype(path, size=size, index=index)
        except Exception:
            continue
    return ImageFont.load_default()


def centered_text(draw, y, text, fill, font_obj, width):
    bbox = draw.textbbox((0, 0), text, font=font_obj)
    x = (width - (bbox[2] - bbox[0])) // 2
    draw.text((x, y), text, fill=fill, font=font_obj)


def centered_text_box(draw, box, y, text, fill, font_obj):
    left, _, right, _ = box
    bbox = draw.textbbox((0, 0), text, font=font_obj)
    x = left + ((right - left) - (bbox[2] - bbox[0])) // 2
    draw.text((x, y), text, fill=fill, font=font_obj)


def make_background(output, scale):
    logical_width, logical_height = 500, 330
    width, height = logical_width * scale, logical_height * scale
    img = Image.new("RGB", (width, height), "#fbfcff")
    draw = ImageDraw.Draw(img)

    for y in range(height):
        ratio = y / height
        r = int(253 * (1 - ratio) + 242 * ratio)
        g = int(254 * (1 - ratio) + 245 * ratio)
        b = int(255 * (1 - ratio) + 255 * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b))

    def n(value):
        return int(value * scale)

    draw.ellipse([n(22), n(-168), n(478), n(118)], fill="#ffffff")

    arrow_color = "#2f6feb"
    arrow = [
        (250, 210),
        (279, 239),
        (269, 249),
        (257, 237),
        (257, 265),
        (243, 265),
        (243, 237),
        (231, 249),
        (221, 239),
    ]
    draw.polygon([(n(x), n(y)) for x, y in arrow], fill=arrow_color)

    centered_text(draw, n(282), "双击安装 LightMD", "#1f4fa8", font(n(16), bold=True), width)
    img.save(output)


def main():
    ASSETS.mkdir(exist_ok=True)
    make_background(OUTPUT, scale=1)
    make_background(OUTPUT_2X, scale=2)
    subprocess.run(
        ["tiffutil", "-cathidpicheck", str(OUTPUT), str(OUTPUT_2X), "-out", str(OUTPUT_TIFF)],
        check=True,
    )
    print(f"Generated {OUTPUT_TIFF}")


if __name__ == "__main__":
    main()
