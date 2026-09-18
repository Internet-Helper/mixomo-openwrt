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

package_update_direct() {
    local secs="$1"
    if [ "$USE_APK" -eq 1 ]; then
        mixomo_timeout "$secs" apk update >/dev/null 2>&1
    else
        mixomo_timeout "$secs" opkg update >/dev/null 2>&1
    fi
}

package_install_direct() {
    local secs="$1"
    shift
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

mixomo_no_response_warn() {
    log_warn "$(T "Нет ответа, проверяю доступность ресурсов" "No response, checking resource availability")"
}

package_update() {
    local rc
    package_update_direct 15 && return 0
    mixomo_no_response_warn
    mixomo_probe_mirrors || return 1
    mixomo_feeds_backup
    mixomo_feeds_use_mirror
    package_update_direct 30; rc=$?
    mixomo_feeds_restore
    [ "$rc" -eq 0 ] || MIXOMO_ACTIVE_MIRROR=""
    return "$rc"
}

package_install() {
    local rc
    package_install_direct 30 "$@" && return 0
    if [ -z "$MIXOMO_ACTIVE_MIRROR" ]; then
        mixomo_no_response_warn
        mixomo_probe_mirrors || return 1
    fi
    mixomo_feeds_backup
    mixomo_feeds_use_mirror
    package_install_direct 30 "$@"; rc=$?
    mixomo_feeds_restore
    [ "$rc" -eq 0 ] || MIXOMO_ACTIVE_MIRROR=""
    return "$rc"
}

package_install_timeout() {
    local secs="$1" rc
    shift
    package_install_direct "$secs" "$@" && return 0
    if [ -z "$MIXOMO_ACTIVE_MIRROR" ]; then
        mixomo_no_response_warn
        mixomo_probe_mirrors || return 1
    fi
    mixomo_feeds_backup
    mixomo_feeds_use_mirror
    package_install_direct "$secs" "$@"; rc=$?
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

install_required_dependencies() {
    local packages="ca-certificates curl ucode ucode-mod-fs ucode-mod-uci rpcd-mod-ucode kmod-tun kmod-nft-tproxy kmod-nft-nat nftables iptables-nft"
    for package in $packages; do
        ensure_package "$package" || return 1
    done
}
