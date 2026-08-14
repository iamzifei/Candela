#!/usr/bin/env python3
"""Builds one comparison sheet from the rendered icon candidates.

Rows are candidates, columns are the three appearances at full size followed by
the same artwork at 32pt and 16pt. The small columns are the point of the sheet:
a gradient-heavy icon can look best at 512 and turn to mush in the Dock or the
menu bar, and there is no way to judge that from the large render alone.

Usage:  python3 design/icon-candidates/sheet.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
OUT = HERE / "comparison-sheet.png"

CANDIDATES = [
    ("A-cone", "A · Luminous cone"),
    ("B-arc", "B · Luminance arc"),
    ("C-panel", "C · Glowing panel"),
    ("D-polar", "D · Photometric plot"),
    ("E-flame", "E · Candle flame"),
]
APPEARANCES = ["light", "dark", "mono"]

BIG = 200
SMALL = [64, 32]        # rendered at 2x of the sizes they stand in for
GAP = 22
LABEL_W = 210
HEADER_H = 46
PAD = 26
BG = (28, 28, 30)
FG = (236, 236, 240)
DIM = (150, 150, 158)


def font(size, bold=False):
    for name in (("HelveticaNeue-Bold" if bold else "HelveticaNeue"),):
        for path in (f"/System/Library/Fonts/{name}.ttc",
                     "/System/Library/Fonts/Helvetica.ttc"):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default(size)


def main():
    cols = len(APPEARANCES) * (1 + len(SMALL))
    width = PAD * 2 + LABEL_W + cols * BIG + (cols - 1) * GAP
    height = PAD * 2 + HEADER_H + len(CANDIDATES) * (BIG + GAP)
    sheet = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(sheet)

    head = font(20, bold=True)
    sub = font(15)
    row_font = font(19, bold=True)

    x = PAD + LABEL_W
    for appearance in APPEARANCES:
        title = {"light": "Light", "dark": "Dark", "mono": "Tinted / mono"}[appearance]
        draw.text((x, PAD), title, font=head, fill=FG)
        draw.text((x, PAD + 22), "512 · 64 · 32", font=sub, fill=DIM)
        x += (1 + len(SMALL)) * BIG + (1 + len(SMALL)) * GAP

    for row, (key, label) in enumerate(CANDIDATES):
        y = PAD + HEADER_H + row * (BIG + GAP)
        name, desc = label.split(" · ")
        draw.text((PAD, y + BIG // 2 - 22), name, font=row_font, fill=FG)
        draw.text((PAD, y + BIG // 2 + 4), desc, font=sub, fill=DIM)

        x = PAD + LABEL_W
        for appearance in APPEARANCES:
            src = Image.open(HERE / f"{key}-{appearance}.png").convert("RGBA")
            big = src.resize((BIG, BIG), Image.LANCZOS)
            sheet.paste(big, (x, y), big)
            x += BIG + GAP
            for size in SMALL:
                small = src.resize((size, size), Image.LANCZOS)
                sheet.paste(small, (x + (BIG - size) // 2,
                                    y + (BIG - size) // 2), small)
                x += BIG + GAP

    sheet.save(OUT)
    print(f"{OUT}  {sheet.size[0]}x{sheet.size[1]}")


if __name__ == "__main__":
    main()
