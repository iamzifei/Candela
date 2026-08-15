#!/bin/bash
# Candela — fast dev build & run (no Xcode needed, Command Line Tools only).
#
# Compiles the binary with swiftc, swaps it into the installed /Applications/Candela.app,
# syncs the version from project.yml, re-signs (stable identity if present, else ad
# hoc), and relaunches. One command.
# For a release DMG (needs full Xcode) use ./build.sh instead. See notes/BUILDING.md.
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
swiftc -O -target arm64-apple-macos26.0 -swift-version 5 -strict-concurrency=minimal -parse-as-library \
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
# Refresh the compiled localizations too, not just the binary. Swapping only the
# executable leaves whatever .lproj the bundle was last BUILT with, so a string
# added or translated since then renders in English no matter how correct the
# catalog is — and it looks exactly like a localization bug in the code. That cost
# an afternoon: a Chinese sentence was diagnosed as a SwiftUI `Text(ternary)`
# problem when the bundle's strings were simply twenty hours old (201 entries
# against the catalog's 207).
python3 "$ROOT/scripts/xcstrings-compile.py" \
  Candela/Resources/Localizable.xcstrings "$APP/Contents/Resources" >/dev/null

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$APP/Contents/Info.plist"
xattr -cr "$APP"
# Sign with a STABLE identity, so macOS keeps the Accessibility grant across
# rebuilds. This matters more than it looks: ad-hoc signing gives the bundle a new
# code hash every build, and TCC keys the grant to the old one. The result is not a
# missing permission but a lying one — System Settings keeps showing Candela toggled
# ON (the record is still there) while AXIsProcessTrusted() returns false for the
# binary actually running, so the brightness keys are dead and the app's own switch
# refuses to stay on. Nothing in that picture points at signing.
#
# Preference order:
#   1. CANDELA_SIGN_ID, if you set it explicitly
#   2. Any "Developer ID Application" certificate in the keychain. Same identity the
#      release build uses, so a grant given to a dev build carries over to the
#      shipped app instead of being orphaned by the first real release.
#   3. A self-signed "Candela Dev" certificate (Keychain Access > Certificate
#      Assistant > Create a Certificate, Self Signed Root, type Code Signing) — for
#      contributors without a paid Apple developer account.
#   4. Ad hoc. Works, but the grant dies on every build.
if [ -n "${CANDELA_SIGN_ID:-}" ]; then
    SIGN_ID="$CANDELA_SIGN_ID"
else
    # -v filters to valid identities; a Developer ID cert is one, so this is safe here
    # (it is NOT safe for the self-signed case below, which -v excludes as untrusted).
    # `|| true` is load-bearing: grep exits 1 when it matches nothing, and under
    # `set -e` that kills the script at the assignment. Which means the ad-hoc
    # fallback below — the whole point of the branch — was unreachable on any
    # machine without a Developer ID certificate, including every contributor's.
    SIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null \
        | grep -m1 -o '"Developer ID Application: [^"]*"' | tr -d '"' || true)"
    if [ -z "$SIGN_ID" ] && security find-identity -p codesigning 2>/dev/null | grep -qF "Candela Dev"; then
        SIGN_ID="Candela Dev"
    fi
fi

if [ -n "$SIGN_ID" ]; then
    echo "==> Signing with identity: $SIGN_ID"
    codesign --force -s "$SIGN_ID" --entitlements Candela/Candela.entitlements "$APP"
else
    echo "==> WARNING: no signing identity found, signing ad hoc."
    echo "    Accessibility will be revoked on every build, and System Settings will"
    echo "    keep showing a stale ON toggle while the brightness keys stay dead."
    codesign --force -s - --entitlements Candela/Candela.entitlements "$APP"
fi

echo "==> Launching..."
open "$APP"
echo "Done. Candela $VERSION running."
