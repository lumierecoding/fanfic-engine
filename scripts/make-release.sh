#!/bin/zsh
# Makes the Mac download for a GitHub release:
#   Fanfic-Engine-<version>.dmg  — "Fanfic Engine.app" (Apple Silicon + Intel), an Applications shortcut, "Read Me First.txt"
#   fanfic_engine-<version>-py3-none-any.whl — the Windows/Linux alpha (needs Python; built with uv if installed)
#   SHA256SUMS                   — checksums of both
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

echo "→ Assembling $APP_NAME…"
rm -rf "$FOLDER" "$DMG" "$DIST"/*.whl(N) "$DIST/SHA256SUMS"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/FanficEngine" "$APP/Contents/MacOS/FanficEngine"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
xattr -cr "$APP"

echo "→ Signing (ad-hoc)…"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"

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
(cd "$DIST" && shasum -a 256 "$(basename "$DMG")" *.whl(N) > SHA256SUMS)

echo "✓ $DMG"
cat "$DIST/SHA256SUMS"
