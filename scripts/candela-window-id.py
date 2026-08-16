#!/usr/bin/env python3
"""Print "id x y w h display_top display_right" for the panel, or nothing if closed.

Used by capture-screenshots.sh. Capturing by window ID rather than by screen
rectangle matters for two reasons: the panel is a floating window with a shadow
and rounded corners that a rectangle capture would either clip or fill with
whatever is behind it, and `System Events ... get size of window 1` happily
returns a remembered geometry for a panel that is closed — which silently
produced screenshots of the desktop.
"""
import subprocess
import sys

# Quartz comes from pyobjc, which is not guaranteed to be present; fall back to
# parsing the window list out of a small AppleScript-free helper if it is not.
try:
    from Quartz import (
        CGWindowListCopyWindowInfo,
        kCGWindowListOptionOnScreenOnly,
        kCGWindowListExcludeDesktopElements,
        kCGNullWindowID,
    )
except ImportError:
    sys.stderr.write("pyobjc (Quartz) not available\n")
    sys.exit(2)


def display_tops() -> list[tuple[float, float, float, float]]:
    """Every display's global bounds, as (x, y, w, h) in points."""
    from Quartz import CGGetActiveDisplayList, CGDisplayBounds
    err, ids, count = CGGetActiveDisplayList(16, None, None)
    if err:
        return []
    out = []
    for did in ids[:count]:
        b = CGDisplayBounds(did)
        out.append((b.origin.x, b.origin.y, b.size.width, b.size.height))
    return out


def display_edges_for(screens, bounds) -> tuple[int, int]:
    """The top and right edges of whichever display contains the panel.

    The right edge matters because the menu bar's clock sits against it. A capture
    that stops partway across the menu bar cuts the clock in half, which reads as a
    mistake rather than as a crop.
    """
    cx = bounds["X"] + bounds["Width"] / 2
    cy = bounds["Y"] + bounds["Height"] / 2
    for x, y, w, h in screens:
        if x <= cx < x + w and y <= cy < y + h:
            return int(y), int(x + w)
    return int(bounds["Y"]), int(bounds["X"] + bounds["Width"])


def main() -> int:
    options = kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements
    screens = display_tops()
    for window in CGWindowListCopyWindowInfo(options, kCGNullWindowID) or []:
        if window.get("kCGWindowOwnerName") != "Candela":
            continue
        bounds = window.get("kCGWindowBounds", {})
        # The status item itself is also a window owned by Candela; the panel is
        # the wide, tall one.
        if bounds.get("Width", 0) < 200 or bounds.get("Height", 0) < 120:
            continue
        # A dismissed panel does not leave the window list. It stays there, keeps its
        # last geometry, and still reports kCGWindowIsOnscreen = True — it is simply
        # faded to alpha 0. Filtering on "on screen" alone therefore reports a panel
        # that is not on the screen, and a caller that trusts it captures the desktop
        # or, worse, clicks into whatever window is behind it. Alpha is the property
        # that actually distinguishes the two.
        if float(window.get("kCGWindowAlpha", 0)) < 0.5:
            continue
        # id x y w h — the caller needs the bounds too: a window-ID capture gets
        # the panel's own buffer, which does NOT include what the glass is sampling,
        # so the material comes out flat grey. A rectangle capture over a controlled
        # backdrop is the only way to photograph the panel as it actually looks.
        # The sixth value is the top of the display this panel opened on, so a
        # capture can be extended up to include the menu bar. The panel is a menu bar
        # app; a screenshot that crops the menu bar away removes the one piece of
        # context that says where it lives.
        top, right = display_edges_for(screens, bounds)
        print(int(window["kCGWindowNumber"]),
              int(bounds["X"]), int(bounds["Y"]),
              int(bounds["Width"]), int(bounds["Height"]), top, right)
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
