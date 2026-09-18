#!/bin/sh
set -eu

ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

MIXOMO_LIB_DIR="$ROOT/src/lib"
export MIXOMO_LIB_DIR
. ./src/lib/common.sh
. ./src/components/magitrickle/install.sh
MAGITRICKLE=mod magitrickle_select
test "$MAGITRICKLE_VARIANT" = mod
if MAGITRICKLE=bad magitrickle_select >/dev/null 2>&1; then
    exit 1
fi
if env -u MAGITRICKLE magitrickle_select >/dev/null 2>&1; then
    exit 1
fi
MIXOMO_DRY_RUN=1 sh ./src/main.sh
jq -e . src/assets/acl/luci-app-mixomo.json >/dev/null
jq -e . src/assets/menu/mixomo.json >/dev/null
jq -e 'has("admin/services/mixomo") and (length == 1)' src/assets/menu/mixomo.json >/dev/null
 test ! -e src/assets/menu/mihomo.json
 test ! -e src/assets/menu/magitrickle.json
test -f src/ucode/rpc/mihomo-dns.uc
test -f src/ucode/rpc/mihomo-profiles.uc
test -f src/ucode/rpc/mihomo-schedule.uc
test -f src/ucode/rpc/mihomo-routing.uc
test -f src/ucode/rpc/mixomo-backup.uc
test -f src/ucode/lib/mixomo-files.uc
test -f src/ucode/lib/mixomo-state.uc
test -f src/ucode/lib/mixomo-config.uc
test -f src/ucode/lib/mixomo-profiles.uc
test -f src/ucode/lib/mixomo-rules.uc
test -f src/ucode/lib/mixomo-schedules.uc
test -f src/ucode/lib/mixomo-validation.uc
test ! -e src/runtime/shell/mihomo-profiles
test ! -e src/runtime/shell/mihomo-schedule
test ! -e src/runtime/shell/mihomo-routing
test "$(grep -c '/usr/share/rpcd/ucode' src/runtime/ucode/install.sh)" -ge 1
test "$(grep -c 'runtime_ucode_source rpc/' src/runtime/ucode/install.sh)" -ge 1
printf 'contracts-ok\n'
