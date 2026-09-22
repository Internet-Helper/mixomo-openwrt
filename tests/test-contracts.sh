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
test "$(grep -c '/usr/share/rpcd/ucode' src/runtime/ucode/install.sh)" -ge 1
test "$(grep -c 'runtime_ucode_source rpc/' src/runtime/ucode/install.sh)" -ge 1
test "$(grep -c 'printf.*from-mixomo.*magitrickle-template.active' src/components/magitrickle/install.sh)" -ge 1
test "$(grep -c '/etc/mixomo/templates/magitrickle-template.active' src/assets/acl/luci-app-mixomo.json)" -ge 1
test "$(grep -c "magitrickle-template.active').catch" src/ui/mihomo/config.js)" -ge 1
test "$(grep -c 'marker === .from-mixomo. ? .from-mixomo. : .own.' src/ui/mihomo/config.js)" -ge 1
test "$(grep -c 'restoreOwnTemplate' src/ui/mihomo/config.js)" -ge 2
test "$(grep -c 'Вернуть прошлую копию' src/ui/mihomo/config.js)" -eq 1
test "$(grep -c 'marker.*from-mixomo.*own' src/components/magitrickle/install.sh)" -ge 1
test "$(grep -c 'magitrickle-own-original.yaml' src/assets/acl/luci-app-mixomo.json)" -ge 1
test "$(grep -c 'magitrickleApplyActiveTemplateCommand' src/ui/mihomo/config.js)" -ge 2
test "$(grep -c 'main/manifest.stable' src/ui/mihomo/config.js)" -ge 1
test "$(grep -c 'MIXOMO_UPDATE_ONLY' install.sh)" -ge 1
test "$(grep -c 'main/manifest.stable' install.sh)" -ge 1
test "$(awk '/^[[:space:]]+runtime_ucode_install \\|\\|/ { runtime=NR } /^[[:space:]]+ui_install \\|\\|/ { ui=NR } END { print (runtime < ui) ? 1 : 0 }' src/main.sh)" -eq 1
test "$(grep -n 'runtime_ucode_install' src/main.sh | awk -F: '$1 < 40 { print }' | wc -l)" -ge 1
test "$(grep -c 'groups:\[\[:space:\]\]\*' src/components/magitrickle/install.sh)" -ge 1
test "$(grep -c 'magitrickle_apply_standard_groups \"$variant\"' src/components/magitrickle/install.sh)" -ge 1
test "$(grep -c 'config.yaml-opkg' src/components/magitrickle/install.sh)" -ge 1
test "$(grep -c 'magitricklePrepareBaseConfigCommand' src/ui/mihomo/config.js)" -ge 2
test "$(grep -c 'совместимый собственный шаблон' src/ui/mihomo/config.js)" -eq 0
test "$(grep -c 'Ссылка на подписку' src/ui/mihomo/config.js)" -ge 1
test "$(grep -c 'happy_key_generate' src/ucode/lib/mixomo-profiles.uc)" -ge 2
test "$(grep -c 'happy-decoder.cc/api/v1/decrypt' src/ucode/lib/mixomo-profiles.uc)" -ge 1
test "$(grep -c '/etc/mixomo/secrets/happy-decoder.key' src/assets/acl/luci-app-mixomo.json)" -eq 0
printf 'contracts-ok\n'
