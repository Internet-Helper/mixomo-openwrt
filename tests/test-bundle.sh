#!/bin/sh
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
sh tools/build-release.sh >/dev/null
MIXOMO_DRY_RUN=1 MIXOMO_MANIFEST_PATH="$ROOT/manifest.test" sh ./test-install.sh
printf 'bundle-bootstrap-ok\n'
