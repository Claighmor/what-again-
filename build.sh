#!/usr/bin/env bash
# Build What Now.app via `swiftc` directly. No Xcode GUI, no SwiftPM.
set -euo pipefail

APP_DISPLAY="What Now"
EXECUTABLE="WhatNow"
DEPLOYMENT_TARGET="14.0"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/build"
APP_DIR="$BUILD_DIR/$APP_DISPLAY.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"

SDK="$(xcrun --show-sdk-path)"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macosx${DEPLOYMENT_TARGET}"

mapfile -t CORE_SOURCES < <(find "$ROOT/Sources/WhatNowCore" -name "*.swift" | sort)
mapfile -t APP_SOURCES < <(find "$ROOT/App" -name "*.swift" | sort)

echo "▸ Cleaning $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

echo "▸ Compiling Swift sources (${#CORE_SOURCES[@]} core + ${#APP_SOURCES[@]} app)"
swiftc \
    -O \
    -target "$TARGET" \
    -sdk "$SDK" \
    -parse-as-library \
    -lsqlite3 \
    -framework AppKit \
    -framework SwiftUI \
    -framework Combine \
    -framework ServiceManagement \
    -o "$MACOS_DIR/$EXECUTABLE" \
    "${CORE_SOURCES[@]}" \
    "${APP_SOURCES[@]}"

echo "▸ Copying Info.plist, .sdef"
cp "$ROOT/App/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/App/WhatNow.sdef" "$RES_DIR/WhatNow.sdef"

echo "▸ Code-signing (ad-hoc) with entitlements"
codesign --force --sign - \
    --entitlements "$ROOT/App/WhatNow.entitlements" \
    --options runtime \
    "$APP_DIR" >/dev/null

echo "✓ Built $APP_DIR"
echo
echo "Launch with:  open '$APP_DIR'"
echo "Test scripting with:"
echo "  osascript -e 'tell application \"What Now\" to add task with title \"hello\"'"
