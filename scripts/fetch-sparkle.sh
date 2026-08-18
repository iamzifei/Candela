#!/bin/bash
#
# Vendors Sparkle's binary XCFramework into vendor/, because Candela builds with
# plain swiftc and the Command Line Tools — there is no SwiftPM manifest to
# declare a dependency in, and committing 40 MB of framework to the repository
# would punish every clone for a file that never changes between releases.
#
# The download is pinned by version and checked against a SHA-256, so a
# compromised or truncated download fails here rather than shipping inside a
# signed app. Re-running is cheap: it exits immediately if the framework is
# already present and matches.
set -euo pipefail

SPARKLE_VERSION="2.9.6"
SPARKLE_SHA256="8d5fb41d960b43f4a68aa14126bf62b098544ec8d191cdcc73eb14e63a8e7606"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor"
FRAMEWORK="$VENDOR/Sparkle.framework"
STAMP="$VENDOR/.sparkle-version"

if [ -d "$FRAMEWORK" ] && [ "$(cat "$STAMP" 2>/dev/null || true)" = "$SPARKLE_VERSION" ]; then
    echo "Sparkle $SPARKLE_VERSION already vendored."
    exit 0
fi

mkdir -p "$VENDOR"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

URL="https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-for-Swift-Package-Manager.zip"
echo "==> Downloading Sparkle $SPARKLE_VERSION"
curl -fsSL "$URL" -o "$TMP/sparkle.zip"

ACTUAL="$(shasum -a 256 "$TMP/sparkle.zip" | awk '{print $1}')"
if [ "$ACTUAL" != "$SPARKLE_SHA256" ]; then
    echo "error: checksum mismatch for Sparkle $SPARKLE_VERSION" >&2
    echo "  expected $SPARKLE_SHA256" >&2
    echo "  actual   $ACTUAL" >&2
    echo "If the release was legitimately re-cut, update SPARKLE_SHA256 in this script." >&2
    exit 1
fi

echo "==> Extracting"
unzip -qq "$TMP/sparkle.zip" -d "$TMP/x"
SRC="$(find "$TMP/x" -type d -name 'Sparkle.framework' -path '*macos*' | head -1)"
[ -n "$SRC" ] || { echo "error: no macOS Sparkle.framework in the archive" >&2; exit 1; }

rm -rf "$FRAMEWORK"
ditto "$SRC" "$FRAMEWORK"

# sign_update comes in the same archive and is what signs the appcast entry at
# release time. Vendoring it here means the release script does not have to hunt
# through DerivedData for a copy some other project happened to download.
TOOLS="$(find "$TMP/x" -type d -name bin | head -1)"
if [ -n "$TOOLS" ] && [ -f "$TOOLS/sign_update" ]; then
    rm -rf "$VENDOR/bin"
    ditto "$TOOLS" "$VENDOR/bin"
fi

printf '%s' "$SPARKLE_VERSION" > "$STAMP"
echo "==> Vendored $FRAMEWORK"
[ -f "$VENDOR/bin/sign_update" ] && echo "==> Vendored $VENDOR/bin/sign_update"
