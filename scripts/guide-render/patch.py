#!/usr/bin/env python3
"""Copy Candela's sources into a work directory and apply the demo seams.

The welcome-guide screenshots are rendered from the app's REAL SwiftUI views, but
those views read singletons that talk to hardware and to the user's own state
(DDC probes, CoreBrightness, SMAppService, the TCC trust bit, saved presets).
A screenshot must show demo data, never whatever this Mac happens to have, so
this script patches those reads in a COPY of the sources. The repository's app
code is never modified.

Every patch must match exactly once: if the app code drifts, this fails loudly
instead of silently rendering live state.

Usage: patch.py <repo-root> <work-dir>
"""
import re
import shutil
import sys
from pathlib import Path

root, work = Path(sys.argv[1]), Path(sys.argv[2])
src = work / "src"
if src.exists():
    shutil.rmtree(src)
shutil.copytree(root / "Candela", src, ignore=shutil.ignore_patterns("*.xcstrings", "Assets.xcassets", "Resources"))
(src / "App" / "CandelaApp.swift").unlink()  # the harness has its own entry point

# (file, old, new). `new` may contain the old text.
PATCHES = [
    # Views read these private(set) properties' setters from the harness.
    ("Services/CoreBrightnessService.swift", "private(set) var nightShiftAvailable", "var nightShiftAvailable"),
    ("Services/CoreBrightnessService.swift", "private(set) var trueToneAvailable", "var trueToneAvailable"),
    # No CoreBrightness clients, no reads of the real Night Shift / True Tone / Dark Mode state.
    ("Services/CoreBrightnessService.swift", "    private init() {\n", "    private init() {\n        if true { return }\n"),
    ("Services/CoreBrightnessService.swift", "    func refresh() {\n", "    func refresh() {\n        if true { return }\n"),
    ("Services/KeepAwakeService.swift", "@Published private(set) var isActive", "@Published var isActive"),
    # DDC vs Software badge: demo table instead of the real DDC probe.
    ("Views/BrightnessSliderView.swift",
     "ddcStatus = BrightnessService.shared.isDDCAvailable(for: display.displayID)",
     "ddcStatus = DemoData.ddc[display.displayID] ?? false"),
    # Saved state: no SMAppService read, no presets.json from the user's Application Support.
    ("Services/SettingsService.swift", "launchAtLogin = LaunchService.shared.isEnabled\n        launchAtLoginPrompted",
     "launchAtLogin = true\n        launchAtLoginPrompted"),
    ("Services/PresetService.swift",
     "presets = SettingsService.shared.load([DisplayPreset].self, filename: filename) ?? []", "presets = []"),
    # Auto Brightness: show it ON without starting the poller that drives real displays.
    ("Services/AutoBrightnessService.swift", "                needsRebaseline = true\n                startPolling()\n",
     "                needsRebaseline = true\n"),
    # Sparkle: never start a real updater; the row renders as enabled, as it is in the app.
    ("Services/UpdaterService.swift", "startingUpdater: true", "startingUpdater: false"),
    ("Services/UpdaterService.swift", "controller?.updater.canCheckForUpdates ?? false", "true"),
    # No hardware enumeration, no reconfiguration callback: the harness fills `displays`.
    ("Services/DisplayManager.swift", "    init() {\n        refreshDisplays()\n        setupReconfigCallback()\n", "    init() {\n"),
]

for rel, old, new in PATCHES:
    p = src / rel
    text = p.read_text()
    n = text.count(old)
    if n != 1:
        sys.exit(f"patch failed: {rel}: expected 1 match, found {n}: {old[:70]!r}")
    p.write_text(text.replace(old, new))

# The brightness-keys row shows its target menu only when Accessibility is trusted: pin
# trust to true, and never start the real event tap from the harness.
p = src / "Views" / "MenuBarView.swift"
text = p.read_text()
text, n1 = re.subn(r"AXIsProcessTrusted\(\)", "true", text)
text, n2 = re.subn(r"BrightnessKeyService\.shared\.start\(\)", "()", text)
if n1 < 3 or n2 < 1:
    sys.exit(f"patch failed: MenuBarView trust seams matched {n1}/{n2} times")
p.write_text(text)
