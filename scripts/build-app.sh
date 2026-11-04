#!/bin/zsh
# Builds "Fanfic Engine.app" and installs it in /Applications (or only stages it with --no-install).
# Builds and signs outside iCloud Drive (iCloud adds file attributes that break codesign).
# Signing is ad-hoc ("-"): no certificate, no Keychain access, no password dialog.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$HOME/Library/Developer/FanficEngine"
BUILD="$WORK/build"
STAGE="$WORK/stage"
APP_NAME="Fanfic Engine.app"
APP="$STAGE/$APP_NAME"
INSTALL_DIR="/Applications"
INSTALL=1
[[ "${1:-}" == "--no-install" ]] && INSTALL=0

echo "→ Building (release)…"
swift build -c release --package-path "$ROOT" --scratch-path "$BUILD" --product FanficEngine
BIN_DIR="$(swift build -c release --package-path "$ROOT" --scratch-path "$BUILD" --show-bin-path)"

if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
  echo "→ Drawing the app icon…"
  swift "$ROOT/scripts/make-icon.swift" "$ROOT/Resources/AppIcon.icns"
fi

echo "→ Assembling ${APP_NAME}…"
rm -rf "$APP"
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

if (( ! INSTALL )); then
  echo "✓ Built (not installed): $APP"
  exit 0
fi

echo "→ Installing to ${INSTALL_DIR}…"
rm -rf "$INSTALL_DIR/$APP_NAME"
ditto "$APP" "$INSTALL_DIR/$APP_NAME"
codesign --verify --strict "$INSTALL_DIR/$APP_NAME"
echo "✓ Installed: $INSTALL_DIR/$APP_NAME"
