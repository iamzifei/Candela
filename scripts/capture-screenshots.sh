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
# The panel-alone captures are build inputs for the banner and the Open Graph cards,
# not something any page links to. They live outside docs/ so the published site
# contains only what it serves.
PLATES="$ROOT/assets/plates"
APP="${CANDELA_APP:-/Applications/Candela.app}"
BIN="$APP/Contents/MacOS/Candela"
PAGES=(root display allResolutions tools settings arrangement virtualDisplays)

[ -x "$BIN" ] || { echo "error: $BIN not found (run ./dev.sh first)" >&2; exit 1; }
mkdir -p "$OUT" "$PLATES"

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

wait_for_panel() {  # echoes "id x y w h display_top display_right", or nothing
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

  read -r _id x y w h top right <<< "$win"
  # Two captures per page, because they are for different things.
  #
  # `panel-<page>.png` includes the menu bar and the desktop: this is a menu bar
  # app, and a shot cropped tight to the panel removes the one piece of context that
  # says where it lives. It is what goes on the website and in the README.
  # Out to the display's right edge, so the menu bar ends where it really ends and
  # the clock is whole. Stopping partway across it cuts the clock in half, which
  # reads as a mistake rather than as a crop.
  screencapture -x -R"$((x-140)),$top,$((right - x + 140)),$((h + y - top + 40))" "$OUT/panel-$page.png"
  # `panel-<page>-plate.png` is the panel alone, for compositing into the banner and
  # the Open Graph cards, where a menu bar would be a second subject competing with
  # the headline.
  screencapture -x -R"$((x-16)),$y,$((w+32)),$((h+16))" "$PLATES/panel-$page-plate.png"
  size=$(sips -g pixelWidth -g pixelHeight "$OUT/panel-$page.png" | awk '/pixel/ {printf "%s ", $2}')
  echo "  $page  ${size}->  $OUT/panel-$page.png"
done

osascript -e 'quit app "Candela"' >/dev/null 2>&1 || true

# PNG is the wrong format to publish these in. A screenshot of a glass panel over a
# gradient compresses terribly as PNG — 1.6 MB each — and the one at the top of the
# home page is the page's largest paint, so it arrived late and left a hole where the
# picture should be. The same image is 44 KB as WebP at quality 90, which is a 37×
# difference for no visible loss on a UI screenshot.
#
# The manifest is written here rather than measured at site-build time so that
# building the site needs no image tooling: the generator reads the dimensions from
# it and emits width/height on every <img>, which is what stops the page from
# shifting as the pictures arrive.
echo "==> Converting to WebP"
: > "$OUT/manifest.txt"
for png in "$OUT"/panel-*.png "$PLATES"/panel-*.png; do
  [ -f "$png" ] || continue
  webp="${png%.png}.webp"
  magick "$png" -quality 90 "$webp"
  read -r w h <<< "$(magick identify -format "%w %h" "$webp")"

  # Narrower copies for srcset. A phone was downloading the full-width image and,
  # worse, decoding it: 1380x1482 is two million pixels, which is roughly 8 MB in
  # memory once decoded, and the home page carries six of them. The bytes were
  # already small; the decode was not.
  # Only the published images get narrow variants; nothing requests a responsive
  # plate.
  variants=""
  for target in 480 960; do
    if [ "$w" -gt "$target" ] && [ "${webp#$PLATES}" = "$webp" ]; then
      magick "$webp" -resize "${target}x" -quality 88 "${webp%.webp}-${target}.webp"
      variants="$variants ${target}"
    fi
  done
  if [ "${webp#$PLATES}" = "$webp" ]; then
    echo "$(basename "$webp") $w $h${variants:+ }${variants# }" >> "$OUT/manifest.txt"
  fi
  rm -f "$png"
done
sort -o "$OUT/manifest.txt" "$OUT/manifest.txt"
echo "Done. $(ls -1 "$OUT"/panel-*.webp 2>/dev/null | wc -l | tr -d ' ') screenshots in $OUT"
exit $failed
