#!/usr/bin/env python3
"""Single source for the Candela icon artwork.

Emits the SVG layers the app icon and the menu-bar icon are built from. SVG
because that is the format a macOS 26 layered icon (.icon) takes its layers in;
keeping the artwork here means the eventual Icon Composer package and today's
flat .icns are drawn from the same numbers rather than two drifting copies.

The mark is a gauge arc sweeping from dim to bright around a central source —
the thing the app does (set luminance) rather than the thing it runs on (a
screen). Its silhouette also happens to be a C.

Geometry follows a measured macOS 26 system icon (Notes.app at 256pt), not the
Big Sur spec: the shape is 0.836 of the canvas with a ~0.225 continuous corner
radius, sitting 4pt high so the system's drop shadow has room below.

Usage:
    python3 scripts/generate-icon.py             # SVG sources + the app iconset
    python3 scripts/generate-icon.py --preview   # also render large PNG previews

Replaces the Swift/CoreGraphics generator this was forked with. Each PNG is
rasterised by CoreSVG at its final size rather than downsampled from 1024, so
the 16pt and 32pt icons get real hinted geometry instead of a blurred 64:1
reduction.
"""
import math
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DESIGN = ROOT / "design"
APPICONSET = ROOT / "Candela/Assets.xcassets/AppIcon.appiconset"

# The appearance the flat .icns ships. macOS 26's layered icon can carry all
# three, but scripts/release.sh builds an .icns with iconutil and no asset
# catalog, so one has to be the icon. Light is the default appearance the
# system shows unless the user opts into dark icons.
FLAT_APPEARANCE = "light"

# Sizes scripts/release.sh copies into the .iconset.
ICONSET_SIZES = [16, 32, 64, 128, 256, 512, 1024]

CANVAS = 1024
SHAPE = round(CANVAS * 0.836)          # 856
INSET = (CANVAS - SHAPE) / 2           # 84
TOP = INSET - 4
RADIUS = round(SHAPE * 0.225)          # 193
CX = CANVAS / 2
CY = TOP + SHAPE / 2

# The arc. Thicker than the first pass: at 32pt a 0.105 stroke closed up into a
# grey ring, and the dim-to-bright sweep — the whole idea — stopped reading.
ARC_R = SHAPE * 0.285
ARC_W = SHAPE * 0.125
HUB_R = SHAPE * 0.10
# Degrees, SVG convention (y down). The gap sits at the bottom, like a dial.
ARC_START, ARC_END = 138, 402

# Per-appearance palette.
#
# The light appearance is a saturated indigo, not a near-white ground. Near-white
# is what document apps use (Notes, Pages); a utility reads as a utility by
# owning a colour, the way Music owns red and Podcasts purple. The first pass
# made it near-white and the icon disappeared into the Dock.
#
# Dark is the same hue taken almost to black, and the gauge keeps its gold so
# the brand survives the switch.
PALETTE = {
    "light": {
        "ground": ("#42528C", "#232F5C"),
        "dim": ("#8492C4", 1.0),
        "mid": ("#C79BD0", 0.0),       # unused hue, kept for stop symmetry
        "bright": ("#FFD166", 1.0),
        "hub": "#FFFFFF",
    },
    "dark": {
        "ground": ("#171C2B", "#080B14"),
        "dim": ("#333E63", 1.0),
        "mid": ("#6E7FB8", 0.0),
        "bright": ("#FFCF5C", 1.0),
        "hub": "#FFFFFF",
    },
    # Stands in for ISAppearanceTintable, where the system supplies the colour
    # and only luminance differences survive.
    "mono": {
        "ground": ("#8A8A8E", "#8A8A8E"),
        "dim": ("#FFFFFF", 0.32),
        "mid": ("#FFFFFF", 0.0),
        "bright": ("#FFFFFF", 1.0),
        "hub": "#FFFFFF",
    },
}


def polar(deg, r=ARC_R):
    rad = math.radians(deg)
    return CX + r * math.cos(rad), CY + r * math.sin(rad)


def arc_path():
    x0, y0 = polar(ARC_START)
    x1, y1 = polar(ARC_END)
    large = 1 if (ARC_END - ARC_START) % 360 > 180 else 0
    return (f'M {x0:.2f} {y0:.2f} '
            f'A {ARC_R:.2f} {ARC_R:.2f} 0 {large} 1 {x1:.2f} {y1:.2f}')


def app_icon(appearance):
    p = PALETTE[appearance]
    dim, dim_a = p["dim"]
    bright, bright_a = p["bright"]
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" height="{CANVAS}" viewBox="0 0 {CANVAS} {CANVAS}">
<defs>
  <linearGradient id="ground" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="{p['ground'][0]}"/>
    <stop offset="1" stop-color="{p['ground'][1]}"/>
  </linearGradient>
  <!-- Diagonal so the sweep runs dim at the lower left to bright at the upper
       right, which is the direction the eye already reads a gauge in. -->
  <linearGradient id="sweep" x1="0.08" y1="0.95" x2="0.92" y2="0.05">
    <stop offset="0" stop-color="{dim}" stop-opacity="{dim_a}"/>
    <stop offset="1" stop-color="{bright}" stop-opacity="{bright_a}"/>
  </linearGradient>
  <clipPath id="shape">
    <rect x="{INSET}" y="{TOP}" width="{SHAPE}" height="{SHAPE}" rx="{RADIUS}" ry="{RADIUS}"/>
  </clipPath>
</defs>
<g clip-path="url(#shape)">
  <rect width="{CANVAS}" height="{CANVAS}" fill="url(#ground)"/>
  <path d="{arc_path()}" fill="none" stroke="url(#sweep)"
        stroke-width="{ARC_W:.2f}" stroke-linecap="round"/>
  <circle cx="{CX}" cy="{CY}" r="{HUB_R:.2f}" fill="{p['hub']}"/>
</g>
</svg>
"""


def menu_bar_icon():
    """The status-item mark, as a template image.

    Same arc, redrawn on its own 16pt grid rather than scaled down from the app
    icon: at menu-bar size the app icon's proportions give a stroke under a
    pixel, and template images get no gradient to hide it. Solid black with
    alpha; AppKit tints it to match the menu bar.
    """
    size = 16.0
    cx = cy = size / 2
    r = size * 0.30
    w = size * 0.135
    hub = size * 0.105

    def point(deg):
        rad = math.radians(deg)
        return cx + r * math.cos(rad), cy + r * math.sin(rad)

    x0, y0 = point(ARC_START)
    x1, y1 = point(ARC_END)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size:.0f}" height="{size:.0f}" viewBox="0 0 {size:.0f} {size:.0f}">
<path d="M {x0:.3f} {y0:.3f} A {r:.3f} {r:.3f} 0 1 1 {x1:.3f} {y1:.3f}"
      fill="none" stroke="#000" stroke-width="{w:.3f}" stroke-linecap="round"/>
<circle cx="{cx:.3f}" cy="{cy:.3f}" r="{hub:.3f}" fill="#000"/>
</svg>
"""


def rasterize(svg, size, destination):
    """Renders `svg` to `destination` at exactly `size` px, keeping transparency.

    Goes through scripts/rasterize-svg.swift rather than `qlmanage -t`, which is
    the obvious no-dependency route and silently composites onto opaque white.
    That produced an iconset whose every corner was white, which the Dock drew
    as a white card behind the artwork.
    """
    destination.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        ["swift", str(HERE / "rasterize-svg.swift"), str(svg), str(size), str(destination)],
        capture_output=True, text=True,
    )
    if result.returncode != 0 or not destination.exists():
        raise RuntimeError(f"rasterizing {svg.name} at {size}px failed:\n"
                           f"{result.stderr[:400]}")


def main():
    DESIGN.mkdir(exist_ok=True)
    written = []
    for appearance in PALETTE:
        path = DESIGN / f"candela-icon-{appearance}.svg"
        path.write_text(app_icon(appearance), encoding="utf-8")
        written.append(path)
    menu = DESIGN / "candela-menubar.svg"
    menu.write_text(menu_bar_icon(), encoding="utf-8")
    written.append(menu)
    print(f"wrote {len(written)} SVGs to {DESIGN}")

    flat = DESIGN / f"candela-icon-{FLAT_APPEARANCE}.svg"
    for size in ICONSET_SIZES:
        rasterize(flat, size, APPICONSET / f"icon_{size}.png")
    print(f"wrote {len(ICONSET_SIZES)} PNGs to {APPICONSET.relative_to(ROOT)} "
          f"({FLAT_APPEARANCE} appearance)")

    if "--preview" in sys.argv:
        for svg in written:
            rasterize(svg, 512, DESIGN / f"{svg.stem}.png")
        print("previews rendered")


if __name__ == "__main__":
    main()
