#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Assets"
OUTPUT = ASSETS / "DMGBackground.png"


def font(size, bold=False):
    candidates = [
        ("/System/Library/Fonts/STHeiti Medium.ttc", 1),
        ("/System/Library/Fonts/STHeiti Medium.ttc", 0),
        ("/System/Library/Fonts/Supplemental/Arial Unicode.ttf", 0),
    ]
    for path, index in candidates:
        try:
            return ImageFont.truetype(path, size=size, index=index)
        except Exception:
            continue
    return ImageFont.load_default()


def centered_text(draw, y, text, fill, font_obj, width=640):
    bbox = draw.textbbox((0, 0), text, font=font_obj)
    x = (width - (bbox[2] - bbox[0])) // 2
    draw.text((x, y), text, fill=fill, font=font_obj)


def main():
    ASSETS.mkdir(exist_ok=True)
    scale = 1
    width, height = 640, 390
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

    draw.ellipse([n(32), n(-126), n(608), n(190)], fill="#ffffff")
    centered_text(draw, n(60), "安装 LightMD Reader", "#1d2433", font(n(30), bold=True), width)
    centered_text(draw, n(102), "把 LightMD Reader 拖到 Applications 完成安装", "#52667a", font(n(17), bold=True), width)

    draw.rounded_rectangle([n(42), n(158), n(268), n(324)], radius=n(24), fill="#ffffff", outline="#c9ddf2", width=n(2))
    draw.rounded_rectangle([n(372), n(158), n(598), n(324)], radius=n(24), fill="#ffffff", outline="#c9ddf2", width=n(2))

    draw.line([(n(286), n(236)), (n(354), n(236))], fill="#1769e0", width=n(7))
    draw.polygon([(n(354), n(236)), (n(330), n(220)), (n(330), n(252))], fill="#1769e0")

    centered_text(draw, n(344), "1. 拖拽", "#6c8298", font(n(15), bold=True), 310)
    centered_text(draw, n(344), "2. 完成安装", "#6c8298", font(n(15), bold=True), 970)
    img.save(OUTPUT)
    print(f"Generated {OUTPUT}")


if __name__ == "__main__":
    main()
