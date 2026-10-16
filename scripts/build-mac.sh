#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAC_DIR="$DIR/mac"
BIN_DIR="$DIR/bin"
mkdir -p "$BIN_DIR"

echo "==> Compiling LazyType Mac Companion..."

# Find all Swift files
SWIFT_FILES=$(find "$MAC_DIR/Sources/RemoteCompanion" -name "*.swift")

# Compile with swiftc directly for maximum speed and zero lock issues
swiftc \
  -O \
  -target x86_64-apple-macosx13.0 \
  -sdk "$(xcrun --show-sdk-path)" \
  -framework AppKit \
  -framework ApplicationServices \
  -framework CoreGraphics \
  -framework CoreImage \
  $SWIFT_FILES \
  -o "$BIN_DIR/LazyTypeCompanion"

echo "==> Successfully built: $BIN_DIR/LazyTypeCompanion"
ls -la "$BIN_DIR/LazyTypeCompanion"
