#!/usr/bin/env bash
# Builds PomodoroTimer.app into ./build using only the Xcode Command Line Tools.
#   ./build.sh            build the app
#   ./build.sh --install  build and copy to /Applications
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="PomodoroTimer"
APP="build/${APP_NAME}.app"

echo "==> Compiling (release)"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "==> Assembling ${APP}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP"

if [[ "${1:-}" == "--install" ]]; then
    echo "==> Installing to /Applications"
    rm -rf "/Applications/${APP_NAME}.app"
    cp -R "$APP" /Applications/
    echo "Done. Launch with: open /Applications/${APP_NAME}.app"
else
    echo "Done. Launch with: open ${APP}"
fi
