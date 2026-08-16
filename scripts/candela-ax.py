#!/usr/bin/env python3
"""Locate controls inside Candela's panel through the accessibility tree.

Why this exists: the first pass at scripting the panel used pixel offsets measured
from a screenshot, and they were wrong within one run. The panel lists the display
it opened on *first*, so the row order — and therefore every offset below it —
changes depending on which monitor's menu bar was clicked. A display with a volume
slider is also taller than one without. Offsets measured on one machine, on one
display, describe that one arrangement and nothing else.

The accessibility tree has none of that problem: every control carries a stable
label ("Combined brightness", "Tools", "Dark Mode, on"), so a caller asks for a
control by name and gets wherever it happens to be today.

Two things are needed to make it work:

  * `AXManualAccessibility` must be set on the application. SwiftUI does not build
    the tree for an ordinary API client until something asks for it, and without
    this the window comes back with zero children — which is exactly what
    `System Events` reports, and why AppleScript is not used here.
  * Clicking is left to the caller, which should post a real mouse event (cliclick).
    Performing AXPress on a SwiftUI control frequently does nothing, and a press
    that silently does nothing is worse than no press at all: the script carries on
    as though it had navigated.

Usage:
  candela-ax.py dump                       # every control in the panel
  candela-ax.py find <role> <substring>    # prints "cx cy w h" for the first match
  candela-ax.py find AXButton Tools
  candela-ax.py find AXSlider "Combined brightness"
  candela-ax.py knob "Combined brightness"   # "kx ky track_left track_right"

Exits 1 if the panel is closed or nothing matched, so callers can stop rather than
click at a stale coordinate.
"""
import subprocess
import sys

from ApplicationServices import (
    AXUIElementCreateApplication,
    AXUIElementCopyAttributeValue,
    AXUIElementSetAttributeValue,
    AXValueGetValue,
    kAXChildrenAttribute,
    kAXDescriptionAttribute,
    kAXPositionAttribute,
    kAXRoleAttribute,
    kAXSizeAttribute,
    kAXTitleAttribute,
    kAXValueAttribute,
    kAXValueCGPointType,
    kAXValueCGSizeType,
)


def attr(element, name):
    err, value = AXUIElementCopyAttributeValue(element, name, None)
    return value if err == 0 else None


def app_element():
    pids = subprocess.run(["pgrep", "-x", "Candela"], capture_output=True, text=True).stdout.split()
    if not pids:
        sys.exit("Candela is not running")
    element = AXUIElementCreateApplication(int(pids[0]))
    # Without this the tree is empty; see the module docstring.
    AXUIElementSetAttributeValue(element, "AXManualAccessibility", True)
    return element


def panel_is_visible():
    """True only if the panel is actually on the screen.

    A dismissed panel keeps its place in the window list, keeps its geometry, and
    still reports kCGWindowIsOnscreen = True; it is faded to alpha 0. The
    accessibility tree is just as cheerful about it, and happily describes the page
    the panel was showing when it closed. Every "the click did nothing" mystery in
    this project traced back to trusting one of those two. Alpha is what tells the
    truth.
    """
    from Quartz import (CGWindowListCopyWindowInfo, kCGNullWindowID,
                        kCGWindowListExcludeDesktopElements,
                        kCGWindowListOptionOnScreenOnly)
    options = kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements
    for window in CGWindowListCopyWindowInfo(options, kCGNullWindowID) or []:
        if window.get("kCGWindowOwnerName") != "Candela":
            continue
        bounds = window.get("kCGWindowBounds", {})
        if bounds.get("Width", 0) < 200 or bounds.get("Height", 0) < 120:
            continue
        if float(window.get("kCGWindowAlpha", 0)) >= 0.5:
            return True
    return False


def panel(app):
    """The panel window — the app's only window, and absent when it is dismissed."""
    if not panel_is_visible():
        return None
    for window in attr(app, kAXChildrenAttribute) or []:
        if attr(window, kAXRoleAttribute) == "AXWindow":
            return window
    return None


def label(element):
    return attr(element, kAXTitleAttribute) or attr(element, kAXDescriptionAttribute) or ""


def geometry(element):
    """(x, y, w, h) in screen points, top-left origin — what cliclick expects."""
    pos, size = attr(element, kAXPositionAttribute), attr(element, kAXSizeAttribute)
    if pos is None or size is None:
        return None
    ok_p, point = AXValueGetValue(pos, kAXValueCGPointType, None)
    ok_s, extent = AXValueGetValue(size, kAXValueCGSizeType, None)
    if not (ok_p and ok_s):
        return None
    return point.x, point.y, extent.width, extent.height


def walk(element, depth=0):
    yield depth, element
    if depth > 12:
        return
    for child in attr(element, kAXChildrenAttribute) or []:
        yield from walk(child, depth + 1)


def main(argv):
    if len(argv) < 2:
        sys.exit(__doc__)
    window = panel(app_element())
    if window is None:
        sys.exit("the panel is closed")

    if argv[1] == "dump":
        for depth, element in walk(window):
            box = geometry(element)
            where = "" if box is None else "  @ %d,%d %dx%d" % tuple(int(v) for v in box)
            value = attr(element, kAXValueAttribute)
            value = "" if value is None else f"  = {value}"
            print("  " * depth + f"{attr(element, kAXRoleAttribute)} | {label(element)}{value}{where}")
        return 0

    if argv[1] == "knob" and len(argv) >= 3:
        # Where a slider's handle currently sits. A drag has to press on the handle:
        # pressing elsewhere on the track makes the value jump to the pointer before
        # the drag even starts, which on camera reads as a glitch rather than as
        # someone adjusting a slider.
        needle = argv[2].lower()
        for _depth, element in walk(window):
            if attr(element, kAXRoleAttribute) != "AXSlider":
                continue
            if needle not in label(element).lower():
                continue
            for child in attr(element, kAXChildrenAttribute) or []:
                if attr(child, kAXRoleAttribute) != "AXValueIndicator":
                    continue
                box = geometry(child)
                if box is None:
                    continue
                x, y, w, h = box
                track = geometry(element)
                print(int(x + w / 2), int(y + h / 2),
                      int(track[0]), int(track[0] + track[2]))
                return 0
        sys.exit(f"no slider handle matching {argv[2]!r}")

    if argv[1] == "find" and len(argv) >= 4:
        role, needle = argv[2], argv[3].lower()
        for _depth, element in walk(window):
            if attr(element, kAXRoleAttribute) != role:
                continue
            if needle not in label(element).lower():
                continue
            box = geometry(element)
            if box is None:
                continue
            x, y, w, h = box
            print(int(x + w / 2), int(y + h / 2), int(w), int(h))
            return 0
        sys.exit(f"no {role} matching {argv[3]!r}")

    sys.exit(__doc__)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
