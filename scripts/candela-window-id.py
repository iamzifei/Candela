#!/usr/bin/env python3
"""Print "id x y w h" for Candela's open panel, or nothing if it is not open.

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


def main() -> int:
    options = kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements
    for window in CGWindowListCopyWindowInfo(options, kCGNullWindowID) or []:
        if window.get("kCGWindowOwnerName") != "Candela":
            continue
        bounds = window.get("kCGWindowBounds", {})
        # The status item itself is also a window owned by Candela; the panel is
        # the wide, tall one.
        if bounds.get("Width", 0) < 200 or bounds.get("Height", 0) < 120:
            continue
        # id x y w h — the caller needs the bounds too: a window-ID capture gets
        # the panel's own buffer, which does NOT include what the glass is sampling,
        # so the material comes out flat grey. A rectangle capture over a controlled
        # backdrop is the only way to photograph the panel as it actually looks.
        print(int(window["kCGWindowNumber"]),
              int(bounds["X"]), int(bounds["Y"]),
              int(bounds["Width"]), int(bounds["Height"]))
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
