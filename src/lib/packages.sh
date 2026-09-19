USE_APK=0
if command -v apk >/dev/null 2>&1; then
    USE_APK=1
fi

mixomo_timeout() {
    local secs="$1"
    shift
    if command -v timeout >/dev/null 2>&1; then
        timeout -s KILL "$secs" "$@"
    else
        "$@"
    fi
}

MIXOMO_APK_MIRROR="${MIXOMO_APK_MIRROR:-}"
MIXOMO_APK_MIRRORS="https://mirror.berlin.freifunk.net/downloads.openwrt.org/ https://ftp.nluug.nl/os/Linux/distr/openwrt/ https://mirrors.cloud.tencent.com/openwrt/ https://mirrors.cernet.edu.cn/openwrt/"
MIXOMO_ACTIVE_MIRROR=""
MIXOMO_APK_REPOS_BAK=/tmp/mixomo-apk-repositories.bak
MIXOMO_OPKG_FEEDS_BAK=/tmp/mixomo-distfeeds.bak

package_lock_busy() {
    if [ "$USE_APK" -eq 1 ]; then
        ps 2>/dev/null | grep -v grep | grep -Eq '[ /]apk([ /]|$)' && return 0
        return 1
    fi
    if [ -f /var/lock/opkg.lock ]; then
        if ps 2>/dev/null | grep -v grep | grep -Eq '[ /]opkg([ /]|$)'; then
            return 0
        fi
        rm -f /var/lock/opkg.lock 2>/dev/null || true
        return 1
    fi
    ps 2>/dev/null | grep -v grep | grep -Eq '[ /]opkg([ /]|$)' && return 0
    return 1
}

wait_for_package_lock() {
    local max_wait="${1:-120}" waited=0
    while package_lock_busy; do
        if [ "$waited" -eq 0 ]; then
            log_warn "$(T "Менеджер пакетов занят другим процессом, ожидаю освобождение блокировки..." "Package manager is busy, waiting for the lock to be released...")"
        fi
        if [ "$waited" -ge "$max_wait" ]; then
            log_error "$(T "Блокировка менеджера пакетов не освободилась, попробуйте позже" "Package manager lock was not released, please try again later")"
            return 1
        fi
        sleep 2
        waited=$((waited + 2))
    done
    return 0
}

package_update_direct() {
    local secs="$1"
    wait_for_package_lock 120 || return 1
    if [ "$USE_APK" -eq 1 ]; then
        mixomo_timeout "$secs" apk update >/dev/null 2>&1
    else
        mixomo_timeout "$secs" opkg update >/dev/null 2>&1
    fi
}

package_install_direct() {
    local secs="$1"
    shift
    wait_for_package_lock 120 || return 1
    if [ "$USE_APK" -eq 1 ]; then
        mixomo_timeout "$secs" apk add --no-progress "$@" >/dev/null 2>&1 || mixomo_timeout "$secs" apk add "$@" >/dev/null 2>&1
    else
        mixomo_timeout "$secs" opkg install "$@" >/dev/null 2>&1
    fi
}

mixomo_mirror_alive() {
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 5 --max-time 10 -o /dev/null "$1" 2>/dev/null
        return $?
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q -T 10 -O /dev/null "$1" 2>/dev/null
        return $?
    fi
    return 1
}

mixomo_probe_mirrors() {
    local m
    if [ -n "$MIXOMO_APK_MIRROR" ]; then
        if mixomo_mirror_alive "$MIXOMO_APK_MIRROR"; then
            MIXOMO_ACTIVE_MIRROR=$(printf '%s' "$MIXOMO_APK_MIRROR" | sed 's|/*$||')
            return 0
        fi
    fi
    for m in $MIXOMO_APK_MIRRORS; do
        if mixomo_mirror_alive "$m"; then
            MIXOMO_ACTIVE_MIRROR=$(printf '%s' "$m" | sed 's|/*$||')
            return 0
        fi
    done
    return 1
}

mixomo_feeds_backup() {
    [ -f /etc/apk/repositories ] && cp -p /etc/apk/repositories "$MIXOMO_APK_REPOS_BAK" 2>/dev/null || true
    [ -f /etc/opkg/distfeeds.conf ] && cp -p /etc/opkg/distfeeds.conf "$MIXOMO_OPKG_FEEDS_BAK" 2>/dev/null || true
}

mixomo_feeds_use_mirror() {
    [ -n "$MIXOMO_ACTIVE_MIRROR" ] || return 1
    [ -f /etc/apk/repositories ] && sed -i -e "s|https://downloads.openwrt.org|$MIXOMO_ACTIVE_MIRROR|g" -e "s|http://downloads.openwrt.org|$MIXOMO_ACTIVE_MIRROR|g" /etc/apk/repositories 2>/dev/null || true
    [ -f /etc/opkg/distfeeds.conf ] && sed -i -e "s|https://downloads.openwrt.org|$MIXOMO_ACTIVE_MIRROR|g" -e "s|http://downloads.openwrt.org|$MIXOMO_ACTIVE_MIRROR|g" /etc/opkg/distfeeds.conf 2>/dev/null || true
}

mixomo_feeds_restore() {
    [ -f "$MIXOMO_APK_REPOS_BAK" ] && mv -f "$MIXOMO_APK_REPOS_BAK" /etc/apk/repositories 2>/dev/null || true
    [ -f "$MIXOMO_OPKG_FEEDS_BAK" ] && mv -f "$MIXOMO_OPKG_FEEDS_BAK" /etc/opkg/distfeeds.conf 2>/dev/null || true
}

if [ -z "${MIXOMO_FEEDS_TRAP_SET:-}" ]; then
    MIXOMO_FEEDS_TRAP_SET=1
    trap 'mixomo_feeds_restore' EXIT INT TERM
fi

mixomo_no_response_warn() {
    log_warn "$(T "Нет ответа, проверяю доступность ресурсов" "No response, checking resource availability")"
}

package_update() {
    local rc attempt
    for attempt in 1 2 3; do
        package_update_direct 30 && return 0
        wait_for_package_lock 120 || break
        sleep 2
    done
    mixomo_no_response_warn
    mixomo_probe_mirrors || return 1
    mixomo_feeds_backup
    mixomo_feeds_use_mirror
    rc=1
    for attempt in 1 2; do
        package_update_direct 30; rc=$?
        [ "$rc" -eq 0 ] && break
        wait_for_package_lock 120 || break
        sleep 2
    done
    mixomo_feeds_restore
    [ "$rc" -eq 0 ] || MIXOMO_ACTIVE_MIRROR=""
    return "$rc"
}

package_install() {
    local rc attempt
    for attempt in 1 2; do
        package_install_direct 30 "$@" && return 0
        wait_for_package_lock 120 || break
        sleep 2
    done
    if [ -z "$MIXOMO_ACTIVE_MIRROR" ]; then
        mixomo_no_response_warn
        mixomo_probe_mirrors || return 1
    fi
    mixomo_feeds_backup
    mixomo_feeds_use_mirror
    rc=1
    for attempt in 1 2; do
        package_install_direct 30 "$@"; rc=$?
        [ "$rc" -eq 0 ] && break
        wait_for_package_lock 120 || break
        sleep 2
    done
    mixomo_feeds_restore
    [ "$rc" -eq 0 ] || MIXOMO_ACTIVE_MIRROR=""
    return "$rc"
}

package_install_timeout() {
    local secs="$1" rc attempt
    shift
    for attempt in 1 2; do
        package_install_direct "$secs" "$@" && return 0
        wait_for_package_lock 120 || break
        sleep 2
    done
    if [ -z "$MIXOMO_ACTIVE_MIRROR" ]; then
        mixomo_no_response_warn
        mixomo_probe_mirrors || return 1
    fi
    mixomo_feeds_backup
    mixomo_feeds_use_mirror
    rc=1
    for attempt in 1 2; do
        package_install_direct "$secs" "$@"; rc=$?
        [ "$rc" -eq 0 ] && break
        wait_for_package_lock 120 || break
        sleep 2
    done
    mixomo_feeds_restore
    [ "$rc" -eq 0 ] || MIXOMO_ACTIVE_MIRROR=""
    return "$rc"
}

package_is_installed() {
    local name="$1"
    if [ "$USE_APK" -eq 1 ]; then
        apk list -I 2>/dev/null | grep -q "^${name}[.-]"
    else
        opkg list-installed 2>/dev/null | grep -q "^${name}[[:space:]]"
    fi
}

kill_stale_package() {
    local name="$1"
    local pid
    for pid in $(ps 2>/dev/null | grep -v grep | grep -E "[ /]${name}([ /]|$)" | awk '{print $1}'); do
        [ "$pid" = "$$" ] && continue
        kill -15 "$pid" 2>/dev/null || true
        sleep 2
        kill -9 "$pid" 2>/dev/null || true
    done
}

ensure_package() {
    local name="$1"
    package_is_installed "$name" && return 0
    package_install "$name" || {
        log_error "$(T "Не удалось установить пакет: $name" "Failed to install package: $name")"
        return 1
    }
    package_is_installed "$name" || {
        log_error "$(T "Пакет не установлен после попытки установки: $name" "Package was not installed after installation attempt: $name")"
        return 1
    }
}

ensure_nftables() {
    command -v nft >/dev/null 2>&1 && return 0
    local candidate
    for candidate in nftables-nojson nftables-json nftables; do
        package_install "$candidate" >/dev/null 2>&1 || continue
        command -v nft >/dev/null 2>&1 && return 0
    done
    log_error "$(T "Не удалось установить пакет nftables (варианты nojson/json)" "Failed to install the nftables package (nojson/json variants)")"
    return 1
}

install_required_dependencies() {
    package_update || {
        log_error "$(T "Не удалось обновить списки пакетов" "Failed to update package lists")"
        return 1
    }
    ensure_nftables || return 1
    local packages="ca-certificates curl ucode ucode-mod-fs ucode-mod-uci rpcd-mod-ucode kmod-tun kmod-nft-tproxy kmod-nft-nat iptables-nft"
    for package in $packages; do
        ensure_package "$package" || return 1
    done
}
