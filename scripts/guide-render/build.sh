#!/bin/bash
# Renders the welcome guide's screenshots (en, zh-Hans, zh-Hant) from Candela's real
# SwiftUI views with demo data, offscreen. No screen capture, no input, no live hardware
# state: see patch.py for the seams and main.swift for the demo data.
#
# Usage: scripts/guide-render/build.sh      (needs the Command Line Tools + ImageMagick)
# Output: Candela/Resources/Guide/guide-<page>-<lang>.jpg
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$ROOT/scripts/guide-render"
WORK="${GUIDE_RENDER_WORK:-${TMPDIR:-/tmp}/candela-guide-render}"
OUT="$ROOT/Candela/Resources/Guide"
VERSION=$(grep -E '^[[:space:]]*MARKETING_VERSION:' "$ROOT/project.yml" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
mkdir -p "$WORK" "$OUT"

python3 "$HERE/patch.py" "$ROOT" "$WORK"
"$ROOT/scripts/fetch-sparkle.sh" >/dev/null

APP="$WORK/GuideRender.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
echo "==> Compiling the renderer against the patched sources"
# shellcheck disable=SC2046
swiftc -O -swift-version 5 -strict-concurrency=minimal -target arm64-apple-macos26.0 \
    -import-objc-header "$ROOT/Candela/Candela-Bridging-Header.h" \
    -F "$ROOT/vendor" -framework Sparkle \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
    -framework AppKit -framework SwiftUI -framework IOKit -framework CoreAudio \
    -Xlinker -undefined -Xlinker dynamic_lookup \
    $(find "$WORK/src" -name '*.swift') "$HERE/main.swift" \
    -o "$APP/Contents/MacOS/GuideRender" 2>&1 | grep -E "error" || true
[ -x "$APP/Contents/MacOS/GuideRender" ] || { echo "compile failed"; exit 1; }
ditto "$ROOT/vendor/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
python3 "$ROOT/scripts/xcstrings-compile.py" "$ROOT/Candela/Resources/Localizable.xcstrings" "$APP/Contents/Resources" >/dev/null
# A bundle id of its own: the renderer must never read or write the real app's preferences.
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.candela.guide-render</string>
<key>CFBundleName</key><string>GuideRender</string>
<key>CFBundleExecutable</key><string>GuideRender</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>${VERSION}</string>
<key>CFBundleVersion</key><string>${VERSION}</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string><string>zh-Hant</string></array>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP" >/dev/null 2>&1

rm -rf "$WORK/png"; mkdir -p "$WORK/png"
for lang in en zh-Hans zh-Hant; do
    echo "==> Rendering $lang"
    defaults delete com.candela.guide-render >/dev/null 2>&1 || true
    "$APP/Contents/MacOS/GuideRender" "$WORK/png" "$lang" -AppleLanguages "($lang)" -AppleLocale "$lang"
done
defaults delete com.candela.guide-render >/dev/null 2>&1 || true

rm -f "$OUT"/guide-*.jpg
for png in "$WORK"/png/guide-*.png; do
    name="$(basename "$png" .png)"
    magick "$png" -resize 560x -strip -quality 80 "$OUT/$name.jpg"
done
ls -l "$OUT" && du -ch "$OUT"/*.jpg | tail -1
