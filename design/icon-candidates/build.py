#!/usr/bin/env python3
"""Renders the Candela app-icon candidates as SVG, plus PNG previews.

SVG rather than CoreGraphics because that is what the final artwork has to be:
a macOS 26 layered icon (.icon) is a package whose layers are SVG assets,
composed by Icon Composer into IconImageStack entries for the light, dark and
tintable appearances. Drawing the candidates in the target format means the
chosen one carries over instead of being redrawn.

Geometry is measured from a real macOS 26 system icon (Notes.app, 256pt):
the shape occupies 0.836 of the canvas with a ~0.225 continuous corner radius,
and sits 4pt above centre so its drop shadow has room. Big Sur's 0.805 ratio
is out of date.

Each candidate ships three appearances so the ones that only work as a gradient
are exposed early:
  light    — on the system's light icon ground
  dark     — on the dark ground
  mono     — flat single colour, standing in for ISAppearanceTintable, where
             every gradient collapses and only the silhouette survives

Usage:  python3 design/icon-candidates/build.py
Writes <name>-<appearance>.svg and matching .png next to this script.
"""
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

CANVAS = 1024
SHAPE = round(CANVAS * 0.836)          # 856
INSET = (CANVAS - SHAPE) / 2           # 84
TOP = INSET - 4                        # shadow room at the bottom
RADIUS = round(SHAPE * 0.225)          # 193
CX = CANVAS / 2
CY = TOP + SHAPE / 2

# Grounds. The mono ground is mid-grey so a light-on-dark design and a
# dark-on-light one are judged on silhouette rather than on contrast luck.
GROUNDS = {
    "light": ("#F2F4F8", "#D8DEE9"),
    "dark": ("#1B2030", "#0A0D16"),
    "mono": ("#8A8A8E", "#8A8A8E"),
}
# Foreground ink for the mono appearance.
MONO_INK = "#FFFFFF"


def shape_path():
    """The app shape, as a rounded rect using the measured radius."""
    return (f'<rect x="{INSET}" y="{TOP}" width="{SHAPE}" height="{SHAPE}" '
            f'rx="{RADIUS}" ry="{RADIUS}"/>')


def header(defs):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS}" '
            f'height="{CANVAS}" viewBox="0 0 {CANVAS} {CANVAS}">\n<defs>\n{defs}\n</defs>\n')


def ground(appearance):
    top, bottom = GROUNDS[appearance]
    return (f'<linearGradient id="ground" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{top}"/>'
            f'<stop offset="1" stop-color="{bottom}"/></linearGradient>')


def clip():
    return f'<clipPath id="shape">{shape_path()}</clipPath>'


def base(appearance):
    return f'<g clip-path="url(#shape)"><rect width="{CANVAS}" height="{CANVAS}" fill="url(#ground)"/>'


# ---------------------------------------------------------------- candidates


def cone(appearance):
    """A — Luminous cone.

    Candela is luminous intensity in a *direction*: a point source and the cone
    of light leaving it. The apex dot is the source; the cone widens and fades.
    """
    mono = appearance == "mono"
    ink = MONO_INK if mono else "#FFFFFF"
    beam = ("#FFFFFF" if mono else "#FFE9A8", "#FFFFFF" if mono else "#5B8CFF")
    defs = ground(appearance) + clip() + (
        f'<linearGradient id="beam" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0" stop-color="{beam[0]}" stop-opacity="{0.95 if mono else 1}"/>'
        f'<stop offset="1" stop-color="{beam[1]}" stop-opacity="{0.35 if mono else 0.15}"/>'
        f'</linearGradient>'
        f'<radialGradient id="src"><stop offset="0" stop-color="{ink}"/>'
        f'<stop offset="0.55" stop-color="{ink}" stop-opacity="0.9"/>'
        f'<stop offset="1" stop-color="{ink}" stop-opacity="0"/></radialGradient>'
    )
    apex_y = TOP + SHAPE * 0.27
    base_y = TOP + SHAPE * 0.80
    half = SHAPE * 0.30
    body = (
        f'<path d="M {CX} {apex_y} L {CX - half} {base_y} L {CX + half} {base_y} Z" '
        f'fill="url(#beam)"/>'
        f'<circle cx="{CX}" cy="{apex_y}" r="{SHAPE * 0.13}" fill="url(#src)"/>'
        f'<circle cx="{CX}" cy="{apex_y}" r="{SHAPE * 0.055}" fill="{ink}"/>'
    )
    return header(defs) + base(appearance) + body + "</g></svg>"


def arc(appearance):
    """B — Luminance arc.

    A gauge sweep running dark to brilliant, with the indicator at the bright
    end. The most literal "this app sets brightness" reading of the five.
    """
    mono = appearance == "mono"
    ink = MONO_INK if mono else "#FFFFFF"
    import math
    r = SHAPE * 0.29
    stroke = SHAPE * 0.105
    start, end = 140, 400          # degrees, clockwise from +x axis
    def point(deg):
        rad = math.radians(deg)
        return CX + r * math.cos(rad), CY + r * math.sin(rad)
    x0, y0 = point(start)
    x1, y1 = point(end)
    dim = "#FFFFFF" if mono else "#3A4B7A"
    bright = "#FFFFFF" if mono else "#FFD469"
    defs = ground(appearance) + clip() + (
        f'<linearGradient id="sweep" x1="0" y1="1" x2="1" y2="0">'
        f'<stop offset="0" stop-color="{dim}" stop-opacity="{0.35 if mono else 1}"/>'
        f'<stop offset="1" stop-color="{bright}"/></linearGradient>'
    )
    body = (
        f'<path d="M {x0:.1f} {y0:.1f} A {r:.1f} {r:.1f} 0 1 1 {x1:.1f} {y1:.1f}" '
        f'fill="none" stroke="url(#sweep)" stroke-width="{stroke:.1f}" stroke-linecap="round"/>'
        f'<circle cx="{CX}" cy="{CY}" r="{SHAPE * 0.115}" fill="{ink}"/>'
    )
    return header(defs) + base(appearance) + body + "</g></svg>"


def panel(appearance):
    """C — Glowing panel.

    A display with light coming out of it, over a brightness scale. The safest
    and most immediately legible; also the one that looks like every other
    display utility.
    """
    mono = appearance == "mono"
    ink = MONO_INK if mono else "#FFFFFF"
    pw, ph = SHAPE * 0.60, SHAPE * 0.40
    px, py = CX - pw / 2, CY - ph / 2 - SHAPE * 0.06
    glow = ("#FFFFFF", "#FFFFFF") if mono else ("#FFF6D8", "#6D9BFF")
    defs = ground(appearance) + clip() + (
        f'<radialGradient id="screen" cx="0.5" cy="0.45">'
        f'<stop offset="0" stop-color="{glow[0]}"/>'
        f'<stop offset="1" stop-color="{glow[1]}" stop-opacity="{0.55 if mono else 0.85}"/>'
        f'</radialGradient>'
    )
    dots = ""
    for i in range(5):
        d = SHAPE * 0.028 + i * SHAPE * 0.012
        x = CX - SHAPE * 0.20 + i * SHAPE * 0.10
        y = py + ph + SHAPE * 0.115
        dots += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{d:.1f}" fill="{ink}" opacity="{0.35 + i * 0.16:.2f}"/>'
    body = (
        f'<rect x="{px:.1f}" y="{py:.1f}" width="{pw:.1f}" height="{ph:.1f}" '
        f'rx="{SHAPE * 0.055:.1f}" fill="url(#screen)"/>' + dots
    )
    return header(defs) + base(appearance) + body + "</g></svg>"


def polar(appearance):
    """D — Photometric polar plot.

    The lobed intensity distribution an engineer actually reads candela off.
    The most distinctive of the five and the one most at risk of turning to
    mush at 16pt — which is exactly what the small preview is for.
    """
    mono = appearance == "mono"
    ink = MONO_INK if mono else "#FFFFFF"
    lobe = "#FFFFFF" if mono else "#FFD469"
    defs = ground(appearance) + clip() + (
        f'<radialGradient id="lobe" cx="0.5" cy="0.15">'
        f'<stop offset="0" stop-color="{lobe}"/>'
        f'<stop offset="1" stop-color="{lobe}" stop-opacity="{0.5 if mono else 0.35}"/>'
        f'</radialGradient>'
    )
    rings = ""
    for i, f in enumerate((0.34, 0.24, 0.14)):
        rings += (f'<circle cx="{CX}" cy="{CY}" r="{SHAPE * f:.1f}" fill="none" '
                  f'stroke="{ink}" stroke-opacity="{0.18 if not mono else 0.30}" '
                  f'stroke-width="{SHAPE * 0.011:.1f}"/>')
    # A cardioid-ish lobe pointing up, drawn as two mirrored cubics.
    top_y = CY - SHAPE * 0.33
    w = SHAPE * 0.245
    body = rings + (
        f'<path d="M {CX} {CY} C {CX - w} {CY - SHAPE * 0.06} '
        f'{CX - w} {top_y + SHAPE * 0.06} {CX} {top_y} '
        f'C {CX + w} {top_y + SHAPE * 0.06} {CX + w} {CY - SHAPE * 0.06} {CX} {CY} Z" '
        f'fill="url(#lobe)"/>'
        f'<circle cx="{CX}" cy="{CY}" r="{SHAPE * 0.045}" fill="{ink}"/>'
    )
    return header(defs) + base(appearance) + body + "</g></svg>"


def flame(appearance):
    """E — Candle flame.

    The etymology: candela is the candle. Included because the name asks for
    it, with the reservation that a warm flame reads as a meditation or
    weather app rather than a display utility, and fights the cool palette the
    rest of the interface uses.
    """
    mono = appearance == "mono"
    ink = MONO_INK if mono else "#FFFFFF"
    outer = "#FFFFFF" if mono else "#FFB33C"
    inner = "#FFFFFF" if mono else "#FFF0B8"
    defs = ground(appearance) + clip() + (
        f'<linearGradient id="flame" x1="0" y1="1" x2="0" y2="0">'
        f'<stop offset="0" stop-color="{outer}" stop-opacity="{0.55 if mono else 1}"/>'
        f'<stop offset="1" stop-color="{inner}"/></linearGradient>'
    )
    bot = CY + SHAPE * 0.26
    top_y = CY - SHAPE * 0.32
    w = SHAPE * 0.175
    body = (
        f'<path d="M {CX} {top_y} C {CX + w} {top_y + SHAPE * 0.20} '
        f'{CX + w * 1.15} {bot - SHAPE * 0.10} {CX} {bot} '
        f'C {CX - w * 1.15} {bot - SHAPE * 0.10} {CX - w} {top_y + SHAPE * 0.20} '
        f'{CX} {top_y} Z" fill="url(#flame)"/>'
        f'<path d="M {CX} {top_y + SHAPE * 0.17} C {CX + w * 0.45} {CY} '
        f'{CX + w * 0.5} {bot - SHAPE * 0.06} {CX} {bot - SHAPE * 0.02} '
        f'C {CX - w * 0.5} {bot - SHAPE * 0.06} {CX - w * 0.45} {CY} '
        f'{CX} {top_y + SHAPE * 0.17} Z" fill="{ink}" opacity="{0.35 if mono else 0.85}"/>'
    )
    return header(defs) + base(appearance) + body + "</g></svg>"


CANDIDATES = {
    "A-cone": cone,
    "B-arc": arc,
    "C-panel": panel,
    "D-polar": polar,
    "E-flame": flame,
}


def main():
    written = []
    for name, draw in CANDIDATES.items():
        for appearance in GROUNDS:
            svg = HERE / f"{name}-{appearance}.svg"
            svg.write_text(draw(appearance), encoding="utf-8")
            written.append(svg)

    # qlmanage writes <name>.svg.png into the output directory.
    result = subprocess.run(
        ["qlmanage", "-t", "-s", "512", "-o", str(HERE)] + [str(p) for p in written],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(result.stderr[:400], file=sys.stderr)
    for stale in HERE.glob("*.svg.png"):
        stale.rename(stale.with_name(stale.name.replace(".svg.png", ".png")))
    print(f"{len(written)} SVGs, {len(list(HERE.glob('*.png')))} PNGs in {HERE}")


if __name__ == "__main__":
    main()
