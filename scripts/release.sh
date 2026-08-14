#!/bin/bash
set -euo pipefail

# Candela release script: builds a signed arm64 DMG with the Command Line
# Tools only (no Xcode), and optionally publishes the GitHub release and bumps
# the Homebrew tap. Default is a dry run: it builds and verifies the DMG but
# publishes nothing. Pass --publish to actually release.
#
# Usage:
#   ./scripts/release.sh v1.0.4 notes.md            # dry run: build DMG only
#   ./scripts/release.sh v1.0.4 notes.md --publish  # build + release + tap
#
# notes.md is the release body (required for --publish; optional for dry run).

TAG="${1:?Usage: ./scripts/release.sh vX.Y.Z [notes.md] [--publish]}"
NOTES="${2:-}"
PUBLISH=false
for arg in "$@"; do [ "$arg" = "--publish" ] && PUBLISH=true; done
[ "${NOTES:-}" = "--publish" ] && NOTES=""

VERSION="${TAG#v}"                       # strip leading v for Info.plist
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
BUILD="$ROOT/build"
APP="$BUILD/Candela.app"
DMG="$ROOT/Candela.dmg"
TAP_REPO="iamzifei/homebrew-tap"
TAP_CASK="Casks/candela.rb"

# A real release must ship complete translations; the dry run (CI on every PR)
# skips this so adding an English string doesn't block contributors — the
# maintainer fills the gaps before publishing.
if [ "$PUBLISH" = true ]; then
    echo "==> Checking translation completeness…"
    python3 "$ROOT/scripts/check-translations.py" Candela/Resources/Localizable.xcstrings
fi

rm -rf "$BUILD"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# arm64 only, not universal: DDC on this app runs through IOAVService, which is
# the Apple Silicon path. An x86_64 slice would build but could not control an
# external monitor's backlight, so shipping one would only mislead Intel users.
echo "==> Compiling arm64 binary…"
SRC=$(find Candela -name '*.swift')
swiftc -O -parse-as-library -target "arm64-apple-macos26.0" \
  -import-objc-header Candela/Candela-Bridging-Header.h \
  -Xlinker -U -Xlinker _SLSConfigureDisplayEnabled \
  -Xlinker -U -Xlinker _SLSGetDisplayList \
  $SRC -o "$APP/Contents/MacOS/Candela"

echo "==> Building app icon from asset catalog…"
ICONSET="$BUILD/AppIcon.iconset"; mkdir -p "$ICONSET"
ICONS="Candela/Assets.xcassets/AppIcon.appiconset"
cp "$ICONS/icon_16.png"   "$ICONSET/icon_16x16.png"
cp "$ICONS/icon_32.png"   "$ICONSET/icon_16x16@2x.png"
cp "$ICONS/icon_32.png"   "$ICONSET/icon_32x32.png"
cp "$ICONS/icon_64.png"   "$ICONSET/icon_32x32@2x.png"
cp "$ICONS/icon_128.png"  "$ICONSET/icon_128x128.png"
cp "$ICONS/icon_256.png"  "$ICONSET/icon_128x128@2x.png"
cp "$ICONS/icon_256.png"  "$ICONSET/icon_256x256.png"
cp "$ICONS/icon_512.png"  "$ICONSET/icon_256x256@2x.png"
cp "$ICONS/icon_512.png"  "$ICONSET/icon_512x512.png"
cp "$ICONS/icon_1024.png" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> Compiling localizations from the String Catalog…"
# The CLT ship no xcstringstool, so generate <lang>.lproj/Localizable.strings
# ourselves; without this the bundle has zero localizations and ships en-only.
LANGS=$(python3 "$ROOT/scripts/xcstrings-compile.py" Candela/Resources/Localizable.xcstrings "$APP/Contents/Resources")
LOC_XML=""; for l in $LANGS; do LOC_XML="${LOC_XML}<string>${l}</string>"; done
echo "    languages: $LANGS"

echo "==> Writing Info.plist / PkgInfo…"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>Candela</string>
	<key>CFBundleDisplayName</key><string>Candela</string>
	<key>CFBundleIdentifier</key><string>com.candela.app</string>
	<key>CFBundleExecutable</key><string>Candela</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleLocalizations</key><array>${LOC_XML}</array>
	<key>CFBundleShortVersionString</key><string>${VERSION}</string>
	<key>CFBundleVersion</key><string>${VERSION}</string>
	<key>LSMinimumSystemVersion</key><string>26.0</string>
	<key>LSUIElement</key><true/>
	<key>NSHumanReadableCopyright</key><string>Candela - Free &amp; Open Source</string>
	<key>NSAppleEventsUsageDescription</key><string>Candela uses System Events to switch Dark Mode with the system's animated transition.</string>
	<key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
</dict>
</plist>
PLIST

# Sign with a Developer ID + hardened runtime, falling back to ad hoc so dry runs
# and contributor/CI builds still work without a cert. A notarizable build needs the
# hardened runtime (--options runtime) and a secure timestamp; ad-hoc gets neither
# and can't be notarized anyway. (b00d.0)
#
# The certificate is found automatically rather than waited for in CANDELA_SIGN_ID.
# Requiring the variable meant the usual invocation — `make build`, no environment —
# silently produced an ad-hoc DMG on a machine that had a perfectly good Developer ID
# in its keychain. dev.sh had the same defaulting bug and it cost an afternoon: the
# app looked signed, System Settings showed its Accessibility grant switched on, and
# the brightness keys were dead because TCC had bound the grant to a code hash that
# changed on every build.
xattr -cr "$APP"
if [ -z "${CANDELA_SIGN_ID:-}" ]; then
  CANDELA_SIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null \
      | grep -m1 -o '"Developer ID Application: [^"]*"' | tr -d '"')"
fi
if [ -n "${CANDELA_SIGN_ID:-}" ]; then
  echo "==> Signing (Developer ID: $CANDELA_SIGN_ID, hardened runtime)…"
  codesign --force --deep --options runtime --timestamp \
    --entitlements Candela/Candela.entitlements --sign "$CANDELA_SIGN_ID" "$APP"
elif [ "$PUBLISH" = true ]; then
  # Refused rather than warned: an ad-hoc DMG is one Gatekeeper blocks outright, and
  # publishing it means every downloader hits "damaged and can't be opened".
  echo "error: --publish needs a Developer ID Application certificate." >&2
  echo "       None found in the keychain, and CANDELA_SIGN_ID is unset." >&2
  exit 1
else
  echo "==> WARNING: signing ad hoc, no Developer ID certificate found."
  echo "    This DMG is for local testing only — Gatekeeper will refuse it."
  codesign --force --deep --sign - --entitlements Candela/Candela.entitlements "$APP"
fi
codesign --verify --deep --strict "$APP"

# Notarize the app and staple the ticket BEFORE packaging, so the app validates
# offline once dragged out of the DMG and the DMG's sha256 (computed below) is the
# final artifact. Runs only with a Developer ID signature plus a stored notarytool
# profile — create it once with:
#   xcrun notarytool store-credentials <profile> \
#     --apple-id <id> --team-id <TEAMID> --password <app-specific-pw>
# Skipped otherwise so unsigned dry runs still produce a DMG. (b00d.0)
if [ -n "${CANDELA_SIGN_ID:-}" ] && [ -n "${CANDELA_NOTARY_PROFILE:-}" ]; then
  echo "==> Notarizing (profile: $CANDELA_NOTARY_PROFILE)…"
  ditto -c -k --keepParent "$APP" "$BUILD/Candela.zip"
  xcrun notarytool submit "$BUILD/Candela.zip" --keychain-profile "$CANDELA_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
elif [ "$PUBLISH" = true ]; then
  # Same reasoning as the ad-hoc refusal above: a Developer ID signature is not
  # enough on its own. macOS refuses to open a downloaded app that carries no
  # notarisation ticket, so publishing one ships a release nobody can run, and the
  # first thing anyone would report is "damaged and can't be opened" — which sounds
  # like a corrupt download rather than a missing step in the build.
  echo "error: --publish needs notarisation. CANDELA_NOTARY_PROFILE is unset." >&2
  echo "       Create the profile once with:" >&2
  echo "         xcrun notarytool store-credentials <profile> \\" >&2
  echo "           --apple-id <id> --team-id <TEAMID> --password <app-specific-pw>" >&2
  echo "       then re-run with CANDELA_NOTARY_PROFILE=<profile>." >&2
  exit 1
elif [ -n "${CANDELA_SIGN_ID:-}" ]; then
  echo "==> Signed with Developer ID, not notarised (dry run) — fine for local testing,"
  echo "    but Gatekeeper will refuse this DMG if it is downloaded from anywhere."
fi

echo "==> Building DMG…"
STAGE="$BUILD/dmg"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname Candela -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

SHA=$(shasum -a 256 "$DMG" | awk '{print $1}')
echo "==> Built $DMG"
echo "    version $(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist"), archs $(lipo -archs "$APP/Contents/MacOS/Candela"), sha256 $SHA"

if [ "$PUBLISH" != true ]; then
  echo "==> Dry run. Pass --publish to create the release and bump the tap."
  exit 0
fi

[ -n "$NOTES" ] && [ -f "$NOTES" ] || { echo "ERROR: --publish needs a notes file: ./scripts/release.sh $TAG notes.md --publish"; exit 1; }

# Everything that can refuse the release is checked HERE, before anything is
# published. The tap bump used to run after `gh release create`, so a missing tap or
# an expired token left a release tagged and uploaded with no cask pointing at it —
# half-published, and the half that exists is the half users find.
echo "==> Pre-flight…"
gh auth status >/dev/null 2>&1 || { echo "error: gh is not authenticated (run: gh auth login)" >&2; exit 1; }
ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"
[ -n "$ORIGIN_URL" ] || { echo "error: no 'origin' remote; the release needs a GitHub repo to publish to." >&2; exit 1; }
# owner/name from either git@github.com:owner/name.git or https://github.com/owner/name(.git)
REPO="$(printf '%s' "$ORIGIN_URL" | sed -E 's#^.*github\.com[:/]##; s#\.git$##')"
gh repo view "$REPO" >/dev/null 2>&1 || { echo "error: cannot reach GitHub repo '$REPO'." >&2; exit 1; }
gh repo view "$TAP_REPO" >/dev/null 2>&1 || {
  echo "error: cannot reach the Homebrew tap '$TAP_REPO'." >&2
  echo "       Create it (an empty public repo of that name is enough) or edit TAP_REPO." >&2
  exit 1
}
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && { echo "error: tag $TAG already exists locally." >&2; exit 1; }
gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1 && { echo "error: release $TAG already exists on $REPO." >&2; exit 1; }
echo "    repo $REPO, tap $TAP_REPO, tag $TAG — ok"

# Keep project.yml (the Xcode build path) in sync with the version we shipped.
sed -i '' "s/MARKETING_VERSION: \"[^\"]*\"/MARKETING_VERSION: \"${VERSION}\"/" project.yml

echo "==> Creating GitHub release ${TAG}…"
gh release create "$TAG" --title "Candela ${TAG}" --notes-file "$NOTES" "$DMG"

echo "==> Bumping Homebrew tap…"
# First release: the tap has no cask yet, so seed it from packaging/candela.rb
# instead of failing on a 404 with the release already public.
if SHA_FILE=$(gh api "repos/$TAP_REPO/contents/$TAP_CASK" --jq '.sha' 2>/dev/null); then
  gh api "repos/$TAP_REPO/contents/$TAP_CASK" --jq '.content' | base64 -d > "$BUILD/candela.rb"
else
  echo "    no cask in the tap yet — seeding from packaging/candela.rb"
  SHA_FILE=""
  sed -e "s#OWNER/REPO#${REPO}#g" packaging/candela.rb > "$BUILD/candela.rb"
fi
sed -i '' -e "s/version \"[^\"]*\"/version \"${VERSION}\"/" \
          -e "s/sha256 \"[^\"]*\"/sha256 \"${SHA}\"/" "$BUILD/candela.rb"
gh api -X PUT "repos/$TAP_REPO/contents/$TAP_CASK" \
  -f message="candela ${VERSION}" \
  -f content="$(base64 -i "$BUILD/candela.rb")" \
  ${SHA_FILE:+-f sha="$SHA_FILE"} --jq '.commit.sha' >/dev/null

echo "==> Released ${TAG} and updated the tap."
