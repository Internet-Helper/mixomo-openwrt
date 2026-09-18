#!/bin/sh
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
VERSION=v0.3.1
OUTPUT="$ROOT/dist"
BUNDLE="$OUTPUT/mixomo-${VERSION}.tar.gz"
mkdir -p "$OUTPUT"
rm -f "$BUNDLE"
tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner -czf "$BUNDLE" -C "$ROOT" install.sh test-install.sh src
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$BUNDLE" | awk '{print $1}' > "$OUTPUT/mixomo-${VERSION}.sha256"
elif command -v busybox >/dev/null 2>&1 && busybox sha256sum >/dev/null 2>&1; then
    busybox sha256sum "$BUNDLE" | awk '{print $1}' > "$OUTPUT/mixomo-${VERSION}.sha256"
else
    printf '%s\n' "sha256sum-unavailable" > "$OUTPUT/mixomo-${VERSION}.sha256"
fi
printf '%s\n' "$BUNDLE"
