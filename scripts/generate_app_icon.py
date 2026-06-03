#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Assets"
APP_ICONSET = ASSETS / "AppIcon.iconset"
APP_ICNS = ASSETS / "AppIcon.icns"
DOCUMENT_ICONSET = ASSETS / "MarkdownDocument.iconset"
DOCUMENT_ICNS = ASSETS / "MarkdownDocument.icns"
EDIT_ICONSET = ASSETS / "EditMode.iconset"
EDIT_ICNS = ASSETS / "EditMode.icns"

SIZES = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]


def rounded_rectangle(draw, box, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def make_icon(size, mode="app"):
    scale = size / 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    rounded_rectangle(
        shadow_draw,
        [int(104 * scale), int(88 * scale), int(920 * scale), int(940 * scale)],
        int(188 * scale),
        (18, 28, 45, 42),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(max(1, int(24 * scale))))
    img.alpha_composite(shadow)

    rounded_rectangle(
        draw,
        [int(96 * scale), int(72 * scale), int(928 * scale), int(920 * scale)],
        int(190 * scale),
        (245, 248, 252, 255),
        (205, 214, 226, 255),
        max(1, int(3 * scale)),
    )

    draw.rounded_rectangle(
        [int(228 * scale), int(170 * scale), int(796 * scale), int(838 * scale)],
        radius=int(52 * scale),
        fill=(255, 255, 255, 255),
        outline=(196, 207, 221, 255),
        width=max(1, int(4 * scale)),
    )
    draw.polygon(
        [
            (int(670 * scale), int(170 * scale)),
            (int(796 * scale), int(296 * scale)),
            (int(670 * scale), int(296 * scale)),
        ],
        fill=(219, 232, 247, 255),
        outline=(160, 181, 205, 255),
    )

    blue = (31, 111, 235, 255)
    green = (19, 163, 127, 255)
    ink = (27, 40, 61, 255)
    muted = (128, 143, 164, 255)
    draw.rounded_rectangle(
        [int(286 * scale), int(270 * scale), int(420 * scale), int(404 * scale)],
        radius=int(28 * scale),
        fill=green if mode == "edit" else blue,
    )
    line_width = max(4, int(14 * scale))
    for x in (336, 370):
        draw.line(
            [int(x * scale), int(302 * scale), int(x * scale), int(378 * scale)],
            fill=(255, 255, 255, 255),
            width=line_width,
        )
    for y in (326, 354):
        draw.line(
            [int(312 * scale), int(y * scale), int(394 * scale), int(y * scale)],
            fill=(255, 255, 255, 255),
            width=line_width,
        )

    for y, w in [(488, 380), (576, 300), (664, 380), (752, 250)]:
        draw.rounded_rectangle(
            [int(292 * scale), int(y * scale), int((292 + w) * scale), int((y + 28) * scale)],
            radius=int(14 * scale),
            fill=ink if y in (488, 664) else muted,
        )

    if mode == "edit":
        draw.line(
            [int(574 * scale), int(706 * scale), int(756 * scale), int(524 * scale)],
            fill=(245, 178, 65, 255),
            width=max(8, int(42 * scale)),
        )
        draw.line(
            [int(606 * scale), int(738 * scale), int(788 * scale), int(556 * scale)],
            fill=(119, 76, 34, 255),
            width=max(6, int(16 * scale)),
        )
        draw.polygon(
            [
                (int(778 * scale), int(502 * scale)),
                (int(828 * scale), int(452 * scale)),
                (int(810 * scale), int(538 * scale)),
            ],
            fill=(246, 239, 212, 255),
        )
        draw.polygon(
            [
                (int(824 * scale), int(454 * scale)),
                (int(850 * scale), int(428 * scale)),
                (int(838 * scale), int(474 * scale)),
            ],
            fill=(39, 48, 65, 255),
        )

    return img


def write_iconset(iconset, icns, mode):
    iconset.mkdir(parents=True, exist_ok=True)
    for size, name in SIZES:
        make_icon(size, mode=mode).save(iconset / name)
    subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(icns)], check=True)


def main():
    ASSETS.mkdir(exist_ok=True)
    write_iconset(APP_ICONSET, APP_ICNS, "app")
    write_iconset(DOCUMENT_ICONSET, DOCUMENT_ICNS, "document")
    write_iconset(EDIT_ICONSET, EDIT_ICNS, "edit")
    print(f"Generated {APP_ICNS}")
    print(f"Generated {DOCUMENT_ICNS}")
    print(f"Generated {EDIT_ICNS}")


if __name__ == "__main__":
    main()
