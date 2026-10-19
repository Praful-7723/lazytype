#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAC_DIR="$DIR/mac"
BIN_DIR="$DIR/bin"
mkdir -p "$BIN_DIR"

echo "==> Compiling LazyType Universal 2 Mac Companion (Apple Silicon + Intel)..."

# Collect all Swift source files
SWIFT_FILES=$(find "$MAC_DIR/Sources/RemoteCompanion" -name "*.swift")
SDK="$(xcrun --show-sdk-path)"

echo "  -> Compiling arm64 slice (Apple Silicon M1/M2/M3/M4)..."
swiftc \
  -target arm64-apple-macosx13.0 \
  -sdk "$SDK" \
  -framework AppKit \
  -framework ApplicationServices \
  -framework CoreGraphics \
  -framework CoreImage \
  -framework WebKit \
  $SWIFT_FILES \
  -o "$BIN_DIR/LazyTypeCompanion-arm64"

echo "  -> Compiling x86_64 slice (Intel Macs)..."
swiftc \
  -target x86_64-apple-macosx13.0 \
  -sdk "$SDK" \
  -framework AppKit \
  -framework ApplicationServices \
  -framework CoreGraphics \
  -framework CoreImage \
  -framework WebKit \
  $SWIFT_FILES \
  -o "$BIN_DIR/LazyTypeCompanion-x86_64"

echo "  -> Fusing Universal 2 binary with lipo..."
lipo -create -output "$BIN_DIR/LazyTypeCompanion" "$BIN_DIR/LazyTypeCompanion-arm64" "$BIN_DIR/LazyTypeCompanion-x86_64"
rm -f "$BIN_DIR/LazyTypeCompanion-arm64" "$BIN_DIR/LazyTypeCompanion-x86_64"

echo "==> Universal binary created successfully:"
lipo -info "$BIN_DIR/LazyTypeCompanion"
ls -lh "$BIN_DIR/LazyTypeCompanion"
