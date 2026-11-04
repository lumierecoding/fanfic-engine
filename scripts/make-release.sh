#!/bin/zsh
# Makes the Mac download for a GitHub release:
#   Fanfic-Engine-<version>.dmg  — "Fanfic Engine.app" (Apple Silicon + Intel), an Applications shortcut, "Read Me First.txt"
#   fanfic_engine-<version>-py3-none-any.whl — the Windows/Linux alpha (needs Python; built with uv if installed)
#   appcast.xml                  — the update feed for Sparkle (SPEC section 10): version, download address, size,
#                                  EdDSA signature of the disk image, notes from CHANGELOG.md
#   SHA256SUMS                   — checksums of the files
# Everything happens in ~/Library/Developer/FanficEngine (outside iCloud Drive); /Applications is never touched.
# Signing is ad-hoc ("-"): no certificate, no Keychain, no password dialog. The app is not notarized, so on another
# Mac it has to be allowed once in System Settings → Privacy & Security (see "Read Me First.txt").
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$HOME/Library/Developer/FanficEngine"
BUILD="$WORK/release-build"
DIST="$WORK/dist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
APP_NAME="Fanfic Engine.app"
FOLDER="$DIST/Fanfic Engine $VERSION"
APP="$FOLDER/$APP_NAME"
DMG="$DIST/Fanfic-Engine-$VERSION.dmg"
ARCHS=(--arch arm64 --arch x86_64)

echo "→ Building $VERSION (release, Apple Silicon + Intel)…"
swift build -c release --package-path "$ROOT" --scratch-path "$BUILD" --product FanficEngine "${ARCHS[@]}"
BIN_DIR="$(swift build -c release --package-path "$ROOT" --scratch-path "$BUILD" "${ARCHS[@]}" --show-bin-path)"
lipo -info "$BIN_DIR/FanficEngine"

echo "→ Assembling ${APP_NAME}…"
rm -rf "$FOLDER" "$DMG" "$DIST"/*.whl(N) "$DIST/SHA256SUMS" "$DIST/appcast.xml"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/FanficEngine" "$APP/Contents/MacOS/FanficEngine"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
# Sparkle, the updater (SPEC section 10): the framework next to the app's code, found through the run path.
# It keeps the Sparkle project's own signature; the app around it is signed ad-hoc below.
mkdir -p "$APP/Contents/Frameworks"
ditto "$BIN_DIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
if ! otool -l "$APP/Contents/MacOS/FanficEngine" | grep -q "@executable_path/../Frameworks"; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/FanficEngine"
fi
cp "$ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
xattr -cr "$APP"

echo "→ Signing (ad-hoc)…"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"

echo "→ Disk image…"
ln -s /Applications "$FOLDER/Applications"
cat > "$FOLDER/Read Me First.txt" <<EOF
Fanfic Engine $VERSION — works offline, needs macOS 15 or later.

1. Drag "Fanfic Engine" onto "Applications".
2. Open Fanfic Engine from Applications. macOS says it could not verify the app
   (it is free and open source, but not notarized by Apple). Click "Done".
3. Open System Settings → Privacy & Security, scroll down to
   "Fanfic Engine was blocked…" and click "Open Anyway". Confirm with your password
   or Touch ID. From then on it opens normally.

Terminal alternative for step 2–3:
   xattr -dr com.apple.quarantine "/Applications/Fanfic Engine.app"

User manual and source code: https://github.com/lumierecoding/fanfic-engine
EOF
hdiutil create -volname "Fanfic Engine $VERSION" -srcfolder "$FOLDER" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
if command -v uv >/dev/null; then
  echo "→ Windows/Linux wheel…"
  (cd "$ROOT/desktop" && uv build --wheel --out-dir "$DIST" >/dev/null 2>&1)
fi
echo "→ Update feed (appcast.xml)…"
# The private update key never goes into the repository or iCloud Drive (scripts/update-key.swift).
KEY="${FANFIC_UPDATE_KEY:-$WORK/keys/fanfic-engine-update.key}"
[[ -f "$KEY" ]] || { echo "✗ No update key at $KEY (see scripts/update-key.swift)"; exit 1; }
PUBLIC="$(/usr/libexec/PlistBuddy -c 'Print SUPublicEDKey' "$ROOT/Resources/Info.plist")"
[[ "$(swift "$ROOT/scripts/update-key.swift" public "$KEY")" == "$PUBLIC" ]] || { echo "✗ The update key doesn't match SUPublicEDKey in Info.plist"; exit 1; }
SIGNATURE="$(swift "$ROOT/scripts/update-key.swift" sign "$KEY" "$DMG")"
swift "$ROOT/scripts/update-key.swift" verify "$PUBLIC" "$DMG" "$SIGNATURE" >/dev/null
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$ROOT/Resources/Info.plist")"
MIN_MACOS="$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$ROOT/Resources/Info.plist")"
if [[ -n "${RELEASE_TAG:-}" ]]; then TAG="$RELEASE_TAG"
elif [[ "$VERSION" == *.*.* ]]; then TAG="v$VERSION"
else TAG="v$VERSION.0"; fi
URL="https://github.com/lumierecoding/fanfic-engine/releases/download/$TAG/$(basename "$DMG")"
# The notes: this version's list in CHANGELOG.md as plain HTML (nothing is loaded from anywhere else; U45).
NOTES="$(awk -v head="## $VERSION " 'index($0, head) == 1 { on = 1; next } /^## / { on = 0 } on' "$ROOT/CHANGELOG.md" \
  | grep '^- ' | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/^- //' \
      -e 's/\*\*\([^*]*\)\*\*/<b>\1<\/b>/g' -e 's/\*\([^*]*\)\*/<i>\1<\/i>/g' -e 's/`\([^`]*\)`/\1/g' \
      -e 's/^/<li>/' -e 's/$/<\/li>/')"
[[ -n "$NOTES" ]] || { echo "✗ CHANGELOG.md has no list for $VERSION"; exit 1; }
cat > "$DIST/appcast.xml" <<APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Fanfic Engine</title>
    <item>
      <title>Fanfic Engine $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_MACOS</sparkle:minimumSystemVersion>
      <description><![CDATA[<ul>
$NOTES
</ul>]]></description>
      <enclosure url="$URL" length="$(stat -f %z "$DMG")" type="application/octet-stream" sparkle:edSignature="$SIGNATURE"/>
    </item>
  </channel>
</rss>
APPCAST
xmllint --noout "$DIST/appcast.xml"

(cd "$DIST" && shasum -a 256 "$(basename "$DMG")" *.whl(N) appcast.xml > SHA256SUMS)

echo "✓ $DMG"
cat "$DIST/SHA256SUMS"
