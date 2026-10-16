#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$DIR/bin/LazyTypeCompanion"

if [ ! -f "$BIN" ]; then
    echo "==> Binary not found. Building first..."
    "$DIR/scripts/build-mac.sh"
fi

echo "==> Launching LazyType Mac Companion..."
exec "$BIN" "$@"
