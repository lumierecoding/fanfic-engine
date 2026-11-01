#!/bin/zsh
# Builds "Fanfic Pairings.app" and installs it in /Applications.
# Builds and signs outside iCloud Drive (iCloud adds file attributes that break codesign).
# Signing is ad-hoc ("-"): no certificate, no Keychain access, no password dialog.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$HOME/Library/Developer/FanficPairings"
BUILD="$WORK/build"
STAGE="$WORK/stage"
APP_NAME="Fanfic Pairings.app"
APP="$STAGE/$APP_NAME"
INSTALL_DIR="/Applications"

echo "→ Building (release)…"
swift build -c release --package-path "$ROOT" --scratch-path "$BUILD" --product FanficPairings
BIN_DIR="$(swift build -c release --package-path "$ROOT" --scratch-path "$BUILD" --show-bin-path)"

if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
  echo "→ Drawing the app icon…"
  swift "$ROOT/scripts/make-icon.swift" "$ROOT/Resources/AppIcon.icns"
fi

echo "→ Assembling $APP_NAME…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/FanficPairings" "$APP/Contents/MacOS/FanficPairings"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
xattr -cr "$APP"

echo "→ Signing (ad-hoc)…"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"

echo "→ Installing to $INSTALL_DIR…"
rm -rf "$INSTALL_DIR/$APP_NAME"
ditto "$APP" "$INSTALL_DIR/$APP_NAME"
codesign --verify --strict "$INSTALL_DIR/$APP_NAME"
echo "✓ Installed: $INSTALL_DIR/$APP_NAME"
