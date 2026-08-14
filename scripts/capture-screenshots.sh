#!/bin/bash
set -euo pipefail

# Captures one PNG per panel page, for the website and the README.
#
# Two things here are not obvious, and both were learned by producing a batch of
# screenshots that turned out to be of the desktop:
#
#   * The app is launched by running its binary, not with `open -a`. LaunchServices
#     does not pass the shell's environment through, so CANDELA_SCREENSHOT_ROUTE
#     never reached the app and every page came out looking like the root panel.
#   * Captures go by window ID, not by screen rectangle. `System Events ... get size
#     of window 1` returns a remembered geometry for a panel that is closed, so a
#     rectangle capture of a panel that failed to open silently photographs whatever
#     is behind it. A window ID cannot be stale: if the panel is not open, there is
#     no ID and this stops.
#
# Usage: ./scripts/capture-screenshots.sh [output-dir]

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/docs/shots}"
APP="${CANDELA_APP:-/Applications/Candela.app}"
BIN="$APP/Contents/MacOS/Candela"
PAGES=(root display allResolutions tools settings arrangement virtualDisplays)

[ -x "$BIN" ] || { echo "error: $BIN not found (run ./dev.sh first)" >&2; exit 1; }
mkdir -p "$OUT"

# Photograph the panel against a controlled backdrop rather than the desk. The panel
# is glass and samples what is behind it, so shots taken on a working desktop have
# other windows legible through it — and are not reproducible, because the glass
# renders differently over light content than dark.
BACKDROP_BIN="${TMPDIR:-/tmp}/candela-capture-backdrop"
if [ ! -x "$BACKDROP_BIN" ] || [ "$ROOT/scripts/capture-backdrop.swift" -nt "$BACKDROP_BIN" ]; then
  echo "==> Building backdrop…"
  xcrun -sdk macosx swiftc -O "$ROOT/scripts/capture-backdrop.swift" -o "$BACKDROP_BIN"
fi
"$BACKDROP_BIN" & BACKDROP_PID=$!
trap 'kill $BACKDROP_PID 2>/dev/null || true' EXIT
sleep 2

open_panel() {
  osascript -e 'tell application "System Events" to tell process "Candela" to click menu bar item 1 of menu bar 2' >/dev/null 2>&1 || true
}

wait_for_panel() {  # echoes "id x y w h", or nothing after ~6s
  for _ in $(seq 1 12); do
    if id=$(python3 "$ROOT/scripts/candela-window-id.py" 2>/dev/null); then
      printf '%s' "$id"; return 0
    fi
    sleep 0.5
  done
  return 1
}

failed=0
for page in "${PAGES[@]}"; do
  osascript -e 'quit app "Candela"' >/dev/null 2>&1 || true
  sleep 1
  CANDELA_SCREENSHOT_ROUTE="$page" "$BIN" >/dev/null 2>&1 &
  sleep 3
  open_panel

  if ! win=$(wait_for_panel); then
    # One retry: the menu bar click occasionally lands while the status item is
    # still being installed.
    open_panel
    win=$(wait_for_panel) || { echo "  $page: panel never opened" >&2; failed=1; continue; }
  fi

  read -r _id x y w h <<< "$win"
  # A rectangle, not -l<id>: see candela-window-id.py. Margin on three sides only —
  # the menu bar sits above everything including the backdrop, so any top margin
  # catches a strip of whatever other status items happen to be installed.
  screencapture -x -R"$((x-16)),$y,$((w+32)),$((h+16))" "$OUT/panel-$page.png"
  size=$(sips -g pixelWidth -g pixelHeight "$OUT/panel-$page.png" | awk '/pixel/ {printf "%s ", $2}')
  echo "  $page  ${size}->  $OUT/panel-$page.png"
done

osascript -e 'quit app "Candela"' >/dev/null 2>&1 || true
echo "Done. $(ls -1 "$OUT"/panel-*.png 2>/dev/null | wc -l | tr -d ' ') screenshots in $OUT"
exit $failed
