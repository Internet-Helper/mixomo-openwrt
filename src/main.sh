#!/bin/sh
[ "${MIXOMO_DEBUG:-0}" = 1 ] && set -x
MIXOMO_SOURCE_ROOT="${MIXOMO_SOURCE_ROOT:-$(CDPATH= cd "$(dirname "$0")" && pwd)}"
if [ -d "$MIXOMO_SOURCE_ROOT/src" ]; then
    MIXOMO_COMPONENT_ROOT="$MIXOMO_SOURCE_ROOT/src"
    MIXOMO_DEFAULT_ASSET_ROOT="$MIXOMO_SOURCE_ROOT/src/assets"
else
    MIXOMO_COMPONENT_ROOT="$MIXOMO_SOURCE_ROOT"
    MIXOMO_DEFAULT_ASSET_ROOT="$MIXOMO_SOURCE_ROOT/assets"
fi
MIXOMO_LIB_DIR="${MIXOMO_LIB_DIR:-$(CDPATH= cd "$MIXOMO_COMPONENT_ROOT/lib" && pwd)}"
MIXOMO_ASSET_ROOT="${MIXOMO_ASSET_ROOT:-$MIXOMO_DEFAULT_ASSET_ROOT}"
. "$MIXOMO_LIB_DIR/common.sh"
. "$MIXOMO_LIB_DIR/finalize.sh"
. "$MIXOMO_COMPONENT_ROOT/components/mihomo/install.sh"
. "$MIXOMO_COMPONENT_ROOT/components/hev/install.sh"
. "$MIXOMO_COMPONENT_ROOT/components/magitrickle/install.sh"
. "$MIXOMO_COMPONENT_ROOT/runtime/ucode/install.sh"
. "$MIXOMO_COMPONENT_ROOT/runtime/routing/install.sh"
. "$MIXOMO_COMPONENT_ROOT/ui/install.sh"

mixomo_write_version() {
    ensure_dir /etc/mixomo/versions || return 1
    printf '%s\n%s\n' "${MIXOMO_INSTALLED_VERSION:-v0.3.2}" "${MIXOMO_BUNDLE_SHA:-}" > /etc/mixomo/versions/mixomo || return 1
}

mixomo_main() {
    if [ "${MIXOMO_DRY_RUN:-0}" = 1 ]; then
        log_done "Mixomo modules loaded"
        return 0
    fi
    choose_language "$@" || return 1
    if [ "${MIXOMO_UPDATE_ONLY:-0}" = 1 ]; then
        step_start "[1/2] $(T "Обновление LuCI" "Updating LuCI")"
        ui_install || return 1
        step_start "[2/2] $(T "Обновление маршрутизации" "Updating routing")"
        routing_install || return 1
        hev_dedup_forwardings || return 1
        /etc/init.d/mixomo-routing restart >/dev/null 2>&1 || true
        mixomo_write_version || return 1
        log_done "$(T "Фоновое обновление завершено" "Background update completed")"
        return 0
    fi
    printf '%s\n' ""
    log_done "Mixomo OpenWrt v0.3.2"
    printf '%s\n' ""
    uci -q delete firewall.Block_443_UDP.direction 2>/dev/null || true
    uci -q delete firewall.Block_443_UDP.reject_forward 2>/dev/null || true
    uci commit firewall 2>/dev/null || true
    step_start "[1/5] [ONLINE] $(T "Установка зависимостей" "Installing dependencies")"
    install_required_dependencies || return 1
    step_start "[2/5] [ONLINE] $(T "Установка Mihomo" "Installing Mihomo")"
    MIXOMO_STEP="[2/5]" mihomo_install || return 1
    step_start "[3/5] [ONLINE] $(T "Установка hev-socks5-tunnel" "Installing hev-socks5-tunnel")"
    MIXOMO_STEP="[3/5]" hev_install || return 1
    step_start "[4/5] [ONLINE] $(T "Установка MagiTrickle" "Installing MagiTrickle")"
    MIXOMO_STEP="[4/5]" magitrickle_install || return 1
    step_start "[5/5] $(T "Завершение" "Finalizing")"
    runtime_ucode_install || return 1
    routing_install || return 1
    ui_install || return 1
    finalize_install || return 1
    mixomo_write_version || return 1
    log_done "$(T "Установка Mixomo OpenWrt v0.3.2 завершена" "Mixomo OpenWrt v0.3.2 installation completed")"
}

mixomo_main "$@"
