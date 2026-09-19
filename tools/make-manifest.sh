#!/bin/sh
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
VERSION=v0.3.3
CHANNEL=${1:-test}
REF=${2:-local}
BUNDLE="$ROOT/dist/mixomo-${VERSION}.tar.gz"
MANIFEST="$ROOT/dist/manifest.${CHANNEL}"
HASH=$(sha256sum "$BUNDLE" | cut -d' ' -f1)
cat > "$MANIFEST" <<EOF
MIXOMO_SCHEMA=1
MIXOMO_VERSION=$VERSION
MIXOMO_CHANNEL=$CHANNEL
MIXOMO_REF=$REF
MIXOMO_BUNDLE=dist/mixomo-${VERSION}.tar.gz
MIXOMO_BUNDLE_SHA256=$HASH
EOF
printf '%s\n' "$MANIFEST"
