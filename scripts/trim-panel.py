#!/usr/bin/env python3
"""Crop a panel screenshot down to the panel itself, and round its corners.

Usage: trim-panel.py <in.png> <out.png>

The margin around the panel is not a fixed number of pixels. It was assumed to be
one — the capture asks for a rectangle 16pt larger than the window on three sides,
so 32px at 2x — and every marketing image came out with the panel sitting inside a
visible lighter box. Measured, the real inset on one capture was 112px on the left
and right and 6px at the top: window bounds are in global display points, and the
ratio between those and captured pixels depends on the display the panel opened on.

So the edges are found rather than calculated. The backdrop is a smooth dark
gradient and the panel is much brighter, which makes the boundary unambiguous
without needing to know anything about the geometry.
"""
import subprocess
import sys
from pathlib import Path


def gray_column_means(path: Path, width: int, height: int) -> list[int]:
    """Mean luminance of each column, as a single ImageMagick call."""
    out = subprocess.run(
        ["magick", str(path), "-colorspace", "Gray", "-resize", f"{width}x1!",
         "-depth", "8", "txt:-"],
        capture_output=True, text=True, check=True).stdout
    return [int(line.split("#")[1][0:2], 16) for line in out.splitlines()[1:]]


def gray_row_means(path: Path, width: int, height: int) -> list[int]:
    out = subprocess.run(
        ["magick", str(path), "-colorspace", "Gray", "-resize", f"1x{height}!",
         "-depth", "8", "txt:-"],
        capture_output=True, text=True, check=True).stdout
    return [int(line.split("#")[1][0:2], 16) for line in out.splitlines()[1:]]


def span(means: list[int]) -> tuple[int, int]:
    """First and last index whose value is above the midpoint of the range."""
    lo, hi = min(means), max(means)
    if hi - lo < 30:
        raise SystemExit("no clear panel edge found — was this captured over the backdrop?")
    threshold = (lo + hi) / 2
    above = [i for i, v in enumerate(means) if v > threshold]
    return above[0], above[-1]


def main() -> int:
    if len(sys.argv) != 3:
        sys.exit("usage: trim-panel.py <in.png> <out.png>")
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])

    w, h = (int(v) for v in subprocess.run(
        ["magick", "identify", "-format", "%w %h", str(src)],
        capture_output=True, text=True, check=True).stdout.split())

    x0, x1 = span(gray_column_means(src, w, h))
    y0, y1 = span(gray_row_means(src, w, h))
    cw, ch = x1 - x0 + 1, y1 - y0 + 1

    # The panel's corner radius scales with it. 16pt at the panel's own 388pt width,
    # expressed as a fraction so it holds at any capture scale.
    radius = max(6, round(cw * 16 / 388))

    subprocess.run(["magick", str(src), "-crop", f"{cw}x{ch}+{x0}+{y0}", "+repage",
                    "/tmp/candela-trim-cut.png"], check=True)
    subprocess.run(["magick", "-size", f"{cw}x{ch}", "xc:none", "-fill", "white",
                    "-draw", f"roundrectangle 0,0 {cw-1},{ch-1} {radius},{radius}",
                    "/tmp/candela-trim-mask.png"], check=True)
    subprocess.run(["magick", "/tmp/candela-trim-cut.png", "/tmp/candela-trim-mask.png",
                    "-alpha", "off", "-compose", "CopyOpacity", "-composite", str(dst)],
                   check=True)
    print(f"{src.name}: panel at {x0},{y0} {cw}x{ch} (radius {radius}) -> {dst}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
