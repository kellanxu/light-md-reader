#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Assets"
OUTPUT = ASSETS / "DMGBackground.png"


def font(size, bold=False):
    candidates = [
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size, index=1 if bold else 0)
        except Exception:
            continue
    return ImageFont.load_default()


def main():
    ASSETS.mkdir(exist_ok=True)
    width, height = 640, 420
    img = Image.new("RGB", (width, height), "#f7f9fc")
    draw = ImageDraw.Draw(img)

    for y in range(height):
        ratio = y / height
        r = int(247 * (1 - ratio) + 238 * ratio)
        g = int(249 * (1 - ratio) + 244 * ratio)
        b = int(252 * (1 - ratio) + 249 * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b))

    draw.rounded_rectangle([42, 42, 598, 378], radius=28, fill="#ffffff", outline="#d8e0eb", width=2)
    draw.text((72, 72), "安装 LightMD Reader", fill="#1d2433", font=font(28, bold=True))
    draw.text((72, 112), "把左侧图标拖到右侧 Applications 文件夹", fill="#667085", font=font(16))

    draw.line([(250, 246), (390, 246)], fill="#1769e0", width=5)
    draw.polygon([(390, 246), (368, 232), (368, 260)], fill="#1769e0")

    draw.text((115, 312), "LightMD Reader", fill="#344054", font=font(15, bold=True))
    draw.text((430, 312), "Applications", fill="#344054", font=font(15, bold=True))

    draw.text((72, 348), "之后双击 .md 文件即可直接阅读", fill="#98a2b3", font=font(13))
    img.save(OUTPUT)
    print(f"Generated {OUTPUT}")


if __name__ == "__main__":
    main()
