#!/bin/bash
set -uo pipefail

# Records the raw footage for the website's hero video: one .mov per segment, each a
# scripted pass through one part of the panel. Recording the segments separately
# means a take that goes wrong costs one segment rather than the whole minute.
#
# Five things here were learned the hard way and none of them are obvious:
#
#   * A dismissed panel does not leave the window list. It keeps its geometry and
#     still reports itself as on-screen, faded to alpha 0 — and the accessibility
#     tree will happily describe the page it was showing when it closed. The first
#     recording session was driven entirely against one of these ghosts. Both
#     candela-window-id.py and candela-ax.py now check alpha; every navigation here
#     goes through require_panel so a take stops instead of clicking blind.
#   * Controls are found by accessibility label, not by pixel offset. The panel puts
#     the display it opened on *first*, so the row order — and every offset below
#     it — depends on which monitor's menu bar was clicked.
#   * A row's centre is not its hit target. The text is inert; the chevron on the
#     right edge is what navigates. Sub-pages go back via the left edge of their
#     title row.
#   * The panel opens on whichever display's menu bar was clicked, so the frame is
#     derived from the panel's own display at runtime. An external 16:9 display is
#     what you want: its bounds are already the shape a hero video needs.
#   * `screencapture -v` starts a beat after it is launched and only emits frames
#     when the screen changes, so each segment opens with a lead-in and a trailing
#     still hold may be shorter on disk than it was in real time.
#
# Usage: ./scripts/record-demo.sh [output-dir]

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/assets/footage}"
APP="${CANDELA_APP:-/Applications/Candela.app}"
BIN="$APP/Contents/MacOS/Candela"
AX="python3 $ROOT/scripts/candela-ax.py"

[ -x "$BIN" ] || { echo "error: $BIN not found" >&2; exit 1; }
command -v cliclick >/dev/null || { echo "error: cliclick not installed" >&2; exit 1; }
mkdir -p "$OUT"

# ------------------------------------------------------------------- BACKDROP
BACKDROP_BIN="${TMPDIR:-/tmp}/candela-capture-backdrop"
if [ ! -x "$BACKDROP_BIN" ] || [ "$ROOT/scripts/capture-backdrop.swift" -nt "$BACKDROP_BIN" ]; then
  echo "==> Building backdrop…"
  xcrun -sdk macosx swiftc -O "$ROOT/scripts/capture-backdrop.swift" -o "$BACKDROP_BIN"
fi
CANDELA_BACKDROP_BLOCK=1 "$BACKDROP_BIN" & BACKDROP_PID=$!
trap 'kill $BACKDROP_PID 2>/dev/null; osascript -e "quit app \"Candela\"" >/dev/null 2>&1' EXIT
sleep 2

# ---------------------------------------------------------------------- PANEL
require_panel() {
  $AX dump >/dev/null 2>&1 && return 0
  echo "  !! the panel is closed — stopping this segment before a click lands on a real window" >&2
  return 1
}

open_panel() {
  local sx sy
  read -r sx sy <<< "$(osascript -e 'tell application "System Events" to tell process "Candela" to get {position, size} of menu bar item 1 of menu bar 2' 2>/dev/null \
    | awk -F', *' '{printf "%d %d", $1 + $3/2, $2 + $4/2}')"
  [ -n "${sx:-}" ] || { echo "error: could not locate the status item" >&2; return 1; }
  cliclick -e 40 "m:$sx,$sy" w:300 "c:$sx,$sy"
  sleep 1.5
}

# The status item is a toggle, so clicking it blind is only correct if you already
# know the panel's state — and you usually do not. Activating Finder dismisses an
# open panel, which turned segment one's "close it, then open it" into "open it,
# then close it" and produced a full recording session of empty desktop. These two
# are state-checked; use them instead of clicking the status item directly.
ensure_open() {
  $AX dump >/dev/null 2>&1 && return 0
  open_panel
}
ensure_closed() {
  $AX dump >/dev/null 2>&1 || return 0
  open_panel
}

# tap_edge <label>  — the chevron on a row's right edge: navigates or expands.
tap_edge() {
  require_panel || return 1
  local cx cy w h
  read -r cx cy w h <<< "$($AX find AXButton "$1")" || { echo "  !! no row matching '$1'" >&2; return 1; }
  cliclick -e 30 "m:$((cx + w / 2 - 20)),$cy"
  hold "${2:-0.5}"
  cliclick "c:$((cx + w / 2 - 20)),$cy"
  hold 1.6
}

# tap_mid <label> — for controls whose whole body is the target (buttons, toggles).
tap_mid() {
  require_panel || return 1
  local cx cy w h
  read -r cx cy w h <<< "$($AX find AXButton "$1")" || { echo "  !! no button matching '$1'" >&2; return 1; }
  cliclick -e 30 "m:$cx,$cy"
  hold "${2:-0.5}"
  cliclick "c:$cx,$cy"
  hold 1.4
}

# tap_back <title> — the ‹ on the left edge of a sub-page's title row.
#
# The dwell between arriving and clicking is not decoration. SwiftUI updates its hit
# testing from the pointer's hover state, and a click delivered in the same breath as
# the move is dropped: the cursor sits on the chevron in the footage, visibly on
# target, and nothing happens. Every tap here moves, waits, then clicks.
tap_back() {
  require_panel || return 1
  local cx cy w h tx
  read -r cx cy w h <<< "$($AX find AXButton "$1")" || return 1
  tx=$((cx - w / 2 + 20))
  cliclick -e 30 "m:$tx,$cy"
  hold 0.4
  cliclick "c:$tx,$cy"
  hold 1.4
}

# Root is where every segment starts. Getting there is a retry loop rather than one
# click because a back tap that silently does nothing would otherwise send the whole
# next segment clicking at coordinates from a page it is not on.
goto_root() {
  local attempt title
  ensure_open
  for attempt in 1 2 3; do
    $AX find AXButton "Tools" >/dev/null 2>&1 && return 0
    # The first button on any sub-page is its title row, which carries the ‹.
    title="$($AX dump 2>/dev/null | awk -F'|' '/AXButton/ {sub(/ +@ .*/,"",$2); gsub(/^ +| +$/,"",$2); print $2; exit}')"
    [ -n "$title" ] || return 1
    tap_back "$title" || return 1
  done
  $AX find AXButton "Tools" >/dev/null 2>&1
}

hover() {
  require_panel || return 1
  local cx cy w h
  read -r cx cy w h <<< "$($AX find "$2" "$1")" || return 1
  cliclick -e 25 "m:$cx,$cy"
  hold "${3:-0.9}"
}

# drag_to <slider-label> <fraction 0-100> — grabs the handle where it actually is.
drag_to() {
  require_panel || return 1
  local kx ky left right target steps i
  read -r kx ky left right <<< "$($AX knob "$1")" || { echo "  !! no slider '$1'" >&2; return 1; }
  target=$((left + (right - left) * $2 / 100))
  steps=14
  cliclick -e 30 "m:$kx,$ky" w:200 "dd:$kx,$ky"
  for i in $(seq 1 $steps); do
    cliclick "dm:$((kx + (target - kx) * i / steps)),$ky" w:40
  done
  cliclick "du:$target,$ky"
}

echo "==> Starting Candela"
osascript -e 'quit app "Candela"' >/dev/null 2>&1 || true
sleep 1
"$BIN" >/dev/null 2>&1 &
sleep 3
open_panel || exit 1
require_panel || { echo "error: the panel never opened" >&2; exit 1; }

read -r _id PX PY PW PH _top _right <<< "$(python3 "$ROOT/scripts/candela-window-id.py")"
read -r FX FY FW FH <<< "$(python3 - "$((PX + PW / 2))" "$((PY + PH / 2))" <<'PY'
import sys
from Quartz import CGGetActiveDisplayList, CGDisplayBounds
cx, cy = float(sys.argv[1]), float(sys.argv[2])
_err, ids, count = CGGetActiveDisplayList(16, None, None)
for did in ids[:count]:
    b = CGDisplayBounds(did)
    if b.origin.x <= cx < b.origin.x + b.size.width and b.origin.y <= cy < b.origin.y + b.size.height:
        print(int(b.origin.x), int(b.origin.y), int(b.size.width), int(b.size.height))
        break
PY
)"
echo "    panel  ${PW}x${PH} at ${PX},${PY}"
echo "    frame  ${FW}x${FH} at ${FX},${FY}"
[ "$(python3 -c "print(abs($FW/$FH - 16/9) < 0.02)")" = "True" ] \
  || echo "    warning: the frame is not 16:9 — the hero video will need cropping" >&2

# The display whose page the demo drills into: the one the panel is on is listed
# first, and it is an external monitor, which is the whole point of the app.
FIRST_DISPLAY="$($AX dump | awk -F'|' '/AXButton \| Display:/ {gsub(/^ +| +$/,"",$2); sub(/^Display: /,"",$2); sub(/,.*/,"",$2); print $2; exit}')"
echo "    drilling into  $FIRST_DISPLAY"

# avfoundation lists one "Capture screen N" per display, and N is the display's
# ordinal in the same list Quartz reports — but the *device index* printed in front
# of it depends on how many cameras happen to be attached, so it cannot be
# hard-coded.
SCREEN_ORDINAL="$(python3 - "$((PX + PW / 2))" "$((PY + PH / 2))" <<'ORD'
import sys
from Quartz import CGGetActiveDisplayList, CGDisplayBounds
cx, cy = float(sys.argv[1]), float(sys.argv[2])
_err, ids, count = CGGetActiveDisplayList(16, None, None)
for index, did in enumerate(ids[:count]):
    b = CGDisplayBounds(did)
    if b.origin.x <= cx < b.origin.x + b.size.width and b.origin.y <= cy < b.origin.y + b.size.height:
        print(index)
        break
ORD
)"
SCREEN_DEVICE="$(ffmpeg -f avfoundation -list_devices true -i "" 2>&1 \
  | sed -n "s/.*\\[\\([0-9][0-9]*\\)\\] Capture screen ${SCREEN_ORDINAL}$/\\1/p" | head -1)"
[ -n "$SCREEN_DEVICE" ] || { echo "error: no avfoundation device for screen $SCREEN_ORDINAL" >&2; exit 1; }
echo "    capturing      avfoundation device $SCREEN_DEVICE (screen $SCREEN_ORDINAL)"


# Recording is done by ffmpeg, not by `screencapture -v`, and that choice was forced.
# screencapture measures time in *frames* and only produces a frame when the screen
# changes, so on a still panel it never reaches its -V limit, does not finish
# shutting down on SIGINT, and cannot be stopped without corrupting the file. Three
# separate takes hung for eight minutes each before that was pinned down. Jittering
# the cursor to manufacture frames did not help either: moving the pointer is not a
# content change.
#
# ffmpeg's avfoundation input captures at a constant frame rate whatever the screen
# is doing, so -t is an honest wall-clock limit and a still hold is just a still
# hold. It also means `hold` below can be an ordinary sleep.
rec_start() {
  rm -f "$OUT/$1.mp4"
  ffmpeg -hide_banner -loglevel error -nostdin \
    -f avfoundation -capture_cursor 1 -capture_mouse_clicks 1 -framerate 30 \
    -i "$SCREEN_DEVICE" -t "$2" \
    -c:v h264_videotoolbox -b:v 30M -pix_fmt yuv420p "$OUT/$1.mp4" &
  REC=$!
  sleep 2.2            # avfoundation takes a beat to hand over the first frame
}
rec_end() {
  wait "$REC" 2>/dev/null
  echo "  $1  $(du -h "$OUT/$1.mp4" 2>/dev/null | cut -f1)"
}

hold() { sleep "$1"; }

park()      { cliclick "m:$((FX + 200)),$((FY + FH - 160))"; }

# The menu bar is in every frame of this video, and it names whichever app is
# frontmost — which, during a scripted recording, is the terminal running the
# script. The first cut went out with "Ghostty  File  Edit  View" across the top of
# what is meant to be a product page. Finder is the neutral answer, and it has to be
# activated after the app is launched, not before.
osascript -e 'tell application "Finder" to activate' >/dev/null 2>&1 || true
sleep 1.5

echo "==> Recording into $OUT"

# ---- 1. The panel opening ---------------------------------------------------
# Close it first, so the recording can show it opening. Clicking the desktop would
# not do it: the backdrop is swallowing stray clicks, which is the whole point of it.
ensure_closed
sleep 1
park
rec_start open 14
hold 1.6
open_panel
hold 4.5
rec_end open

# ---- 2. Brightness, per display and all at once -----------------------------
goto_root || echo "  !! could not get back to the root panel" >&2
rec_start brightness 27
drag_to "$FIRST_DISPLAY brightness" 35
hold 0.6
drag_to "$FIRST_DISPLAY brightness" 100
hold 0.9
drag_to "Built-in Display brightness" 40
hold 0.6
drag_to "Built-in Display brightness" 100
hold 1.0
drag_to "Combined brightness" 25          # every display moves together
hold 1.4
drag_to "Combined brightness" 85
hold 1.6
rec_end brightness

# ---- 3. Sharp HiDPI modes ---------------------------------------------------
goto_root || echo "  !! could not get back to the root panel" >&2
rec_start hidpi 35
tap_edge "Display: $FIRST_DISPLAY" 0.7
hold 1.4
tap_edge "Resolution" 0.8                  # expands the scaling slider in place
hold 2.2
tap_mid "Show all resolutions" 0.8
hold 1.8
# Walk down the HiDPI block. Hovering only: committing a mode change would resize
# every window on a display someone is working on.
for mode in "3360 × 1890" "2560 × 1440" "2048 × 1152" "1680 × 945"; do
  hover "$mode" AXButton 0.8
done
hold 1.8
tap_back "$FIRST_DISPLAY"
hold 1.2
rec_end hidpi

# ---- 4. Brightness keys -----------------------------------------------------
goto_root || echo "  !! could not get back to the root panel" >&2
rec_start keys 22
tap_edge "Settings" 0.7
hold 1.6
tap_edge "Brightness Keys" 1.0
hold 3.0
tap_back "Settings"
hold 1.4
rec_end keys

# ---- 5. Tools ---------------------------------------------------------------
goto_root || echo "  !! could not get back to the root panel" >&2
rec_start tools 20
tap_edge "Tools" 0.7
hold 1.6
hover "Virtual Displays" AXButton 1.4
hover "Arrange Displays" AXButton 1.6
tap_back "Tools"
hold 1.4
rec_end tools

# ---- 6. Dark Mode -----------------------------------------------------------
goto_root || echo "  !! could not get back to the root panel" >&2
rec_start appearance 18
tap_mid "Dark Mode" 0.8
hold 3.4
tap_mid "Dark Mode" 0.5
hold 3.2
rec_end appearance

echo
echo "Done. Footage in $OUT"
for f in "$OUT"/*.mp4; do
  [ -f "$f" ] || continue
  printf "  %-20s %s  %ss\n" "$(basename "$f")" \
    "$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$f")" \
    "$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f" | cut -c1-5)"
done
