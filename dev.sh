#!/bin/bash
# Candela — fast dev build & run (no Xcode needed, Command Line Tools only).
#
# Compiles the binary with swiftc, swaps it into the installed /Applications/Candela.app,
# syncs the version from project.yml, re-signs (stable identity if present, else ad
# hoc), and relaunches. One command.
# For a release DMG (needs full Xcode) use ./build.sh instead. See docs/BUILDING.md.
#
# Override the target app with:  CANDELA_APP=/path/to/Candela.app ./dev.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
APP="${CANDELA_APP:-/Applications/Candela.app}"

if [ ! -d "$APP" ]; then
    echo "error: $APP not found." >&2
    echo "Install Candela once (DMG or ./build.sh) so there's a bundle to swap into." >&2
    exit 1
fi

# Single source of truth for the version: project.yml.
VERSION=$(grep -E '^[[:space:]]*MARKETING_VERSION:' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
BUILD=$(grep -E '^[[:space:]]*CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

echo "==> Compiling Candela $VERSION ($BUILD)..."
swiftc -O -swift-version 5 -strict-concurrency=minimal -parse-as-library \
    -import-objc-header Candela/Candela-Bridging-Header.h \
    -framework AppKit -framework SwiftUI -framework IOKit -framework CoreAudio \
    -Xlinker -undefined -Xlinker dynamic_lookup \
    Candela/App/*.swift Candela/Models/*.swift Candela/Services/*.swift \
    Candela/Views/*.swift Candela/Utilities/*.swift \
    -o Candela-bin

echo "==> Swapping into ${APP}..."
pkill -x Candela 2>/dev/null || true
sleep 1
cp Candela-bin "$APP/Contents/MacOS/Candela"
# Keep the installed bundle's reported version in step with project.yml,
# since the binary swap doesn't regenerate Info.plist.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$APP/Contents/Info.plist"
xattr -cr "$APP"
# Sign with a stable self-signed identity when one exists, so macOS keeps the
# Accessibility grant across rebuilds. Ad-hoc signing changes the code hash every
# build, which invalidates the CGEventTap permission the brightness keys rely on,
# forcing a re-grant after every deploy. Create the identity once: Keychain Access >
# Certificate Assistant > Create a Certificate, name "Candela Dev", Self Signed Root,
# type Code Signing. Falls back to ad-hoc when it is absent.
SIGN_ID="${CANDELA_SIGN_ID:-Candela Dev}"
# No -v: a self-signed identity is reported "not trusted" and excluded by -v, but
# codesign still signs with it fine, and that's all we need (a stable designated
# requirement so TCC keeps the grant across rebuilds).
if security find-identity -p codesigning 2>/dev/null | grep -qF "$SIGN_ID"; then
    echo "==> Signing with identity: $SIGN_ID"
    codesign --force -s "$SIGN_ID" --entitlements Candela/Candela.entitlements "$APP"
else
    echo "==> Signing ad hoc ($SIGN_ID not found; Accessibility will reset each build)"
    codesign --force -s - --entitlements Candela/Candela.entitlements "$APP"
fi

echo "==> Launching..."
open "$APP"
echo "Done. Candela $VERSION running."
