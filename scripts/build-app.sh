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

# The linker writes the SDK version into the app, and macOS uses it to choose the design: an app that says SDK 15 runs
# in compatibility mode with the pre-glass look on macOS 26 and later. SwiftPM links without the SDK path, so it wrote
# the deployment target (15.0) instead (ui-spec change 13, U70). Handing the SDK to the linker fixes that.
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SDK_VERSION="$(xcrun --sdk macosx --show-sdk-version)"
SDK_FLAGS=(-Xswiftc -Xclang-linker -Xswiftc -isysroot -Xswiftc -Xclang-linker -Xswiftc "$SDK_PATH")
echo "→ Building (release)…"
swift build -c release --package-path "$ROOT" --scratch-path "$BUILD" --product FanficEngine "${SDK_FLAGS[@]}"
BIN_DIR="$(swift build -c release --package-path "$ROOT" --scratch-path "$BUILD" "${SDK_FLAGS[@]}" --show-bin-path)"

if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
  echo "→ Drawing the app icon…"
  swift "$ROOT/scripts/make-icon.swift" "$ROOT/Resources/AppIcon.icns"
fi

echo "→ Assembling ${APP_NAME}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/FanficEngine" "$APP/Contents/MacOS/FanficEngine"
# Stop if the app doesn't carry the SDK version (it would silently fall back to the old look).
if vtool -show-build "$APP/Contents/MacOS/FanficEngine" | awk -v want="$SDK_VERSION" '$1 == "sdk" && $2 != want { bad = 1 } END { exit !bad }'; then
  echo "✗ The app does not say it was built with SDK $SDK_VERSION:"; vtool -show-build "$APP/Contents/MacOS/FanficEngine" | grep -E 'sdk|minos'; exit 1
fi
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
