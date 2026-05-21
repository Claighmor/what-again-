#!/usr/bin/env bash
# Compile and run the test suite via swiftc directly. No XCTest, no SwiftPM.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/build"
mkdir -p "$BUILD_DIR"

SDK="$(xcrun --show-sdk-path)"
ARCH="$(uname -m)"
TARGET="${ARCH}-apple-macosx14.0"

mapfile -t CORE_SOURCES < <(find "$ROOT/Sources/WhatNowCore" -name "*.swift" | sort)
mapfile -t TEST_SOURCES < <(find "$ROOT/Tests" -name "*.swift" | sort)

echo "▸ Compiling test runner (${#CORE_SOURCES[@]} core + ${#TEST_SOURCES[@]} tests)"
swiftc \
    -O \
    -target "$TARGET" \
    -sdk "$SDK" \
    -lsqlite3 \
    -framework AppKit \
    -framework Combine \
    -o "$BUILD_DIR/run-tests" \
    "${CORE_SOURCES[@]}" \
    "${TEST_SOURCES[@]}"

echo "▸ Running tests"
"$BUILD_DIR/run-tests"
