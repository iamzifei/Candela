#!/bin/bash
set -euo pipefail

# Produces every image the website and the README use that is not a raw screenshot:
# the site icon, the two Open Graph cards, and the README banner.
#
# Reproducible on purpose. The previous set was inherited from the upstream project
# and showed its interface and its name — the kind of thing that survives a rename
# because nobody re-opens a PNG to check what is in it. Regenerating from the current
# screenshots means the marketing images cannot drift from the app the way a
# hand-made file does.
#
# Run scripts/capture-screenshots.sh first; this composites its output.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHOTS="$ROOT/docs/shots"
PLATES="$ROOT/assets/plates"
OUT="$ROOT/docs"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v magick >/dev/null || { echo "error: ImageMagick not installed (brew install imagemagick)" >&2; exit 1; }
[ -f "$PLATES/panel-root-plate.webp" ] || { echo "error: run scripts/capture-screenshots.sh first" >&2; exit 1; }

# Charter is the site's text face and ships with macOS; the marketing images should
# not be the one place the brand speaks in a different voice.
SF="/System/Library/Fonts/Supplemental/Charter.ttc"
[ -f "$SF" ] || SF="/System/Library/Fonts/Supplemental/Georgia.ttf"
[ -f "$SF" ] || SF="/System/Library/Fonts/SFNS.ttf"
# kami's warm neutrals, matching both the website and the backdrop the screenshots
# were taken against, so a card and the panel inside it are lit the same way.
GRAD_FROM="#504e49"
GRAD_TO="#3d3d3a"
INK="#f5f4ed"        # parchment, used as the type colour on these dark plates
INK_SOFT="#c9c6bb"
ACCENT="#c2a878"

echo "==> Site icon"
swift "$ROOT/scripts/rasterize-svg.swift" "$ROOT/design/candela-icon-light.svg" 256 "$OUT/icon.png"

# The `-plate` captures, not the ones with the menu bar: a card has a headline, and
# a menu bar in the same frame is a second subject competing with it. The full-context
# shots are for the website and the README, where the desktop is the point.
# Crop each plate down to the panel itself. The inset is measured, not assumed:
# see scripts/trim-panel.py for why calculating it from the capture geometry produced
# marketing images with the panel inside a visible box.
panel_cutout() {  # <height-in-px> <output>
  local target=$1 out=$2
  python3 "$ROOT/scripts/trim-panel.py" "$PLATES/panel-root-plate.webp" "$TMP/trimmed.png" >/dev/null
  magick "$TMP/trimmed.png" -resize "x${target}" "$out"
}

# card <width> <height> <line1> <line2> <subhead> <footline> <output>
card() {
  local w=$1 h=$2 line1=$3 line2=$4 subhead=$5 footline=$6 out=$7

  # Type scale, derived from the card height so both card sizes stay in proportion.
  local head_pt=$((h * 11 / 100))
  local head_lead=$((head_pt * 118 / 100))
  local sub_pt=$((h * 45 / 1000))
  local foot_pt=$((h * 36 / 1000))
  local pad=$((h * 12 / 100))

  local head_y=$((h / 2 - head_lead / 2 - sub_pt))
  local sub_y=$((head_y + head_lead * 2 + sub_pt / 2))
  local foot_y=$((sub_y + sub_pt * 2))

  magick -size "${w}x${h}" gradient:"$GRAD_FROM"-"$GRAD_TO" "$TMP/bg.png"
  panel_cutout $((h - pad * 2)) "$TMP/panel.png"
  swift "$ROOT/scripts/rasterize-svg.swift" "$ROOT/design/candela-icon-light.svg" 128 "$TMP/icon.png"

  # No drop shadow. The obvious `-shadow` incantation rendered a blurred rectangle
  # LIGHTER than the gradient behind it, framing the panel in exactly the box the
  # rounded corners exist to avoid. The cutout has real alpha (verified: corner
  # pixels are srgba(0,0,0,0)), and a glass panel on a soft gradient does not need
  # a shadow to separate from it.
  magick "$TMP/bg.png" \
    "$TMP/panel.png" \
    -gravity northeast -geometry +"$pad"+"$pad" -composite \
    \( "$TMP/icon.png" -resize 72x72 \) -gravity northwest -geometry +"$pad"+"$((pad * 55 / 100))" -composite \
    -font "$SF" -gravity northwest \
    -fill "$INK_SOFT" -pointsize $((h * 5 / 100)) \
      -annotate +"$((pad + 92))"+"$((pad * 55 / 100 + 18))" "Candela" \
    -fill "$INK" -pointsize "$head_pt" \
      -annotate +"$pad"+"$head_y" "$line1" \
      -annotate +"$pad"+"$((head_y + head_lead))" "$line2" \
    -fill "$INK_SOFT" -pointsize "$sub_pt" -annotate +"$pad"+"$sub_y" "$subhead" \
    -fill "$ACCENT" -pointsize "$foot_pt" -annotate +"$pad"+"$foot_y" "$footline" \
    "$out"
  echo "    $out"
}

echo "==> Open Graph cards"
card 1200 630 \
  "Display control" "macOS leaves out" \
  "HiDPI scaling · DDC brightness · presets" \
  "Free and open source · macOS 26" \
  "$OUT/og-card.png"

card 1200 630 \
  "macOS 藏起来的" "显示器设置" \
  "HiDPI 清晰缩放 · DDC 硬件亮度 · 预设" \
  "免费开源 · macOS 26" \
  "$OUT/og-card-zh.png"

echo "==> README banner"
card 1280 480 \
  "Every display control" "macOS hides" \
  "One menu bar panel. Free, open source, no Pro tier." \
  "macOS 26 · Apple silicon · MIT" \
  "$OUT/banner.png"

echo "==> Download badge"
magick -size 320x64 xc:none \
  -fill "#1b365d" -draw "roundrectangle 0,0 319,63 6,6" \
  -font "$SF" -fill "#f5f4ed" -gravity center -pointsize 24 \
  -annotate +0+0 "Download for macOS" \
  "$OUT/download-macos.png"
echo "    $OUT/download-macos.png"

echo "Done."

echo "==> Page tour GIF"
# A tour of the pages, not a recording of someone using them. Synthetic clicks do not
# reach this panel's hit targets, so a real interaction capture — dragging a slider,
# watching a fade — has to be recorded by hand. This shows the drill-down structure,
# which is the thing a still screenshot cannot: that the panel has pages.
TOUR=(root display allResolutions tools settings)
frames=()
for page in "${TOUR[@]}"; do
  [ -f "$PLATES/panel-$page-plate.webp" ] || continue
  python3 "$ROOT/scripts/trim-panel.py" "$PLATES/panel-$page-plate.webp" "$TMP/tour-$page.png" >/dev/null
  # One canvas size for every frame, so the GIF does not jump as pages change height.
  magick "$TMP/tour-$page.png" -resize x760 \
    -background none -gravity north -extent 460x760 "$TMP/frame-$page.png"
  frames+=("$TMP/frame-$page.png")
done
# Frames before the alpha settings: those are operators, and an operator with no
# images loaded yet is an error rather than a default.
magick -delay 130 -loop 0 "${frames[@]}" \
  -background "#45443f" -alpha remove -alpha off \
  -layers optimize "$OUT/tour.gif"
echo "    $OUT/tour.gif ($(du -h "$OUT/tour.gif" | cut -f1))"
