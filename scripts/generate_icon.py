#!/usr/bin/env python3
"""Generate Kiln app icon PNGs at every size the asset catalog requires.

Usage:
    python3 scripts/generate_icon.py

Output goes to Kiln/Assets.xcassets/AppIcon.appiconset/.
Requires Pillow: pip install Pillow

The icon is generated rather than drawn so it is reproducible, reviewable as a diff, and
editable by changing three constants instead of opening a design tool. Regenerate after
any change here and commit the PNGs — Xcode Cloud builds from the repo and does not run
this script.

Design: a dark chamber with an ember glow rising from the floor, and a "K" sitting in the
heat. The glow is radial and bottom-weighted because that is where a kiln's heat actually
comes from; a centred glow reads as a generic gradient.
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(REPO, "Kiln/Assets.xcassets/AppIcon.appiconset")

SIZES = [16, 32, 64, 128, 256, 512, 1024]

CHAMBER = (24, 20, 24)      # near-black, faintly warm — fired clay, not slate
EMBER = (232, 108, 44)      # orange heat
EMBER_CORE = (255, 176, 92) # hotter centre
GLYPH = (255, 238, 214)     # bone white, as if lit by the glow

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Futura.ttc",
    "/System/Library/Fonts/SFNSDisplay.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/System/Library/Fonts/SFNSText.ttf",
]


def load_font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except Exception:
                continue
    return ImageFont.load_default()


def make_icon(px):
    # Rendered at 4x and downsampled. At 16px the glyph and glow alias badly if drawn
    # directly; supersampling is cheaper than special-casing the small sizes.
    ss = 4
    size = px * ss

    # RGB, never RGBA — App Store icon validation rejects an alpha channel outright.
    img = Image.new("RGB", (size, size), CHAMBER)

    # Ember glow: concentric circles from a hot core, centred below the middle so the
    # light reads as rising from the floor of the chamber.
    glow = Image.new("RGB", (size, size), CHAMBER)
    gd = ImageDraw.Draw(glow)
    # Bottom-weighted and deliberately contained: the corners must stay dark, or the tile
    # reads as an orange gradient rather than a dark chamber with heat inside it.
    cx, cy = size / 2, size * 0.80
    radius = size * 0.50
    steps = 64
    for i in range(steps, 0, -1):
        t = i / steps
        r = radius * t
        # Blend chamber -> ember -> core as the radius shrinks.
        if t > 0.45:
            u = (t - 0.45) / 0.55
            color = tuple(int(EMBER[c] + (CHAMBER[c] - EMBER[c]) * u) for c in range(3))
        else:
            u = t / 0.45
            color = tuple(int(EMBER_CORE[c] + (EMBER[c] - EMBER_CORE[c]) * u) for c in range(3))
        gd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)

    # A real blur rather than more circles: banding from discrete steps is visible at 512
    # and above, and a heavy blur is both cheaper and smoother than raising `steps`. It
    # also feathers the glow's edge into the chamber, which is the point.
    img = glow.filter(ImageFilter.GaussianBlur(radius=size * 0.10))

    font = load_font(int(size * 0.50))
    measure = ImageDraw.Draw(img)
    bbox = measure.textbbox((0, 0), "K", font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (size - tw) / 2 - bbox[0]
    # Sits slightly above centre: the glyph's optical weight plus the bright floor below
    # it drag the composition down otherwise.
    y = (size - th) / 2 - bbox[1] - size * 0.03

    # Soft shadow on its own layer rather than a hard offset copy. A 1px black double at
    # this scale reads as a printing error; a blurred, mostly-transparent shadow just
    # separates the glyph from the brightest part of the glow.
    if px >= 64:
        shadow = Image.new("L", (size, size), 0)
        ImageDraw.Draw(shadow).text((x, y + size * 0.012), "K", font=font, fill=150)
        shadow = shadow.filter(ImageFilter.GaussianBlur(radius=size * 0.018))
        img = Image.composite(Image.new("RGB", (size, size), (0, 0, 0)), img, shadow)

    ImageDraw.Draw(img).text((x, y), "K", font=font, fill=GLYPH)

    return img.resize((px, px), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    for sz in SIZES:
        path = os.path.join(OUT, f"AppIcon-{sz}.png")
        make_icon(sz).save(path, "PNG")
        print(f"  {sz}x{sz} → {os.path.relpath(path, REPO)}")
    print("Done.")


if __name__ == "__main__":
    main()
