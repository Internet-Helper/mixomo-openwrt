USE_APK=0
if command -v apk >/dev/null 2>&1; then
    USE_APK=1
fi

package_update() {
    if [ "$USE_APK" -eq 1 ]; then
        apk update >/dev/null 2>&1
    else
        opkg update >/dev/null 2>&1
    fi
}

package_install() {
    if [ "$USE_APK" -eq 1 ]; then
        apk add --no-progress "$@" >/dev/null 2>&1 || apk add "$@" >/dev/null 2>&1
    else
        opkg install "$@" >/dev/null 2>&1
    fi
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
    package_is_installed "$1" || package_install "$1"
}

install_base_dependencies() {
    local packages="ca-certificates curl ucode ucode-mod-fs ucode-mod-uci rpcd-mod-ucode kmod-tun kmod-nft-tproxy kmod-nft-nat kmod-nft-socket"
    for package in $packages; do
        ensure_package "$package" || return 1
    done
    if [ "$USE_APK" -eq 0 ]; then
        ensure_package iptables-mod-tproxy || true
    fi
}
