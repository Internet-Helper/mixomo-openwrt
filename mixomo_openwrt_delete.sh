#!/bin/sh

set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${GREEN}=== $* ===${NC}"; }
log_done()  { echo -e "${GREEN}$*${NC}"; }

is_pkg_installed() {
    opkg list-installed | grep -q "^$1 "
}

remove_mihomo() {
    log_info "Проверка наличия Mihomo..."
    local CLEANED=0

    if [ -f "/etc/init.d/mihomo" ]; then
        /etc/init.d/mihomo stop 2>/dev/null
        /etc/init.d/mihomo disable 2>/dev/null
        rm -f /etc/init.d/mihomo
        CLEANED=1
    fi

    if [ -f "/usr/bin/mihomo" ]; then
        rm -f /usr/bin/mihomo
        CLEANED=1
    fi

    if [ -d "/etc/mihomo" ] || [ -d "/www/luci-static/resources/view/mihomo" ]; then
        rm -rf /etc/mihomo
        rm -f /usr/share/luci/menu.d/luci-app-mihomo.json
        rm -f /usr/share/rpcd/acl.d/luci-app-mihomo.json
        rm -rf /www/luci-static/resources/view/mihomo
        CLEANED=1
    fi
    
    if [ "$CLEANED" -eq 1 ]; then
        log_done "Mihomo и его файлы были успешно удалены."
    else
        log_done "Mihomo не найден (уже удалён)."
    fi
}

remove_hev_tunnel() {
    log_info "Проверка наличия Hev-Socks5-Tunnel..."
    local ACTION_TAKEN=0

    if [ -f "/etc/init.d/hev-socks5-tunnel" ]; then
        /etc/init.d/hev-socks5-tunnel stop 2>/dev/null
    fi

    if is_pkg_installed hev-socks5-tunnel; then
        opkg remove hev-socks5-tunnel >/dev/null 2>&1
        ACTION_TAKEN=1
    fi

    if [ -d "/etc/hev-socks5-tunnel" ] || [ -f "/etc/config/hev-socks5-tunnel" ]; then
        rm -rf /etc/hev-socks5-tunnel
        rm -rf /etc/hev-socks5-tunnel/main.yml
        rm -f /etc/config/hev-socks5-tunnel
        ACTION_TAKEN=1
    fi

    uci delete hev-socks5-tunnel 2>/dev/null
    uci delete network.Mihomo 2>/dev/null
    uci delete firewall.Mihomo 2>/dev/null
    uci delete firewall.lan_to_Mihomo 2>/dev/null
    
    uci commit network
    uci commit firewall
    uci commit hev-socks5-tunnel 2>/dev/null

    /etc/init.d/network reload 2>/dev/null
    /etc/init.d/firewall reload 2>/dev/null

    if [ "$ACTION_TAKEN" -eq 1 ]; then
        log_done "Hev-Socks5-Tunnel и настройки удалены."
    else
        log_done "Hev-Socks5-Tunnel не найден (уже удалён)."
    fi
}

remove_magitrickle() {
    log_info "Проверка наличия MagiTrickle..."
    local PKG_REMOVED=0

    if [ -f "/etc/init.d/magitrickle" ]; then
        /etc/init.d/magitrickle stop 2>/dev/null
        /etc/init.d/magitrickle disable 2>/dev/null
    fi

    if is_pkg_installed magitrickle_mod; then
        log_info "Найден MagiTrickle Mod. Удаление..."
        opkg remove magitrickle_mod > /dev/null 2>&1
        PKG_REMOVED=1
    fi

    if is_pkg_installed magitrickle; then
        log_info "Найден оригинальный MagiTrickle. Удаление..."
        opkg remove magitrickle > /dev/null 2>&1
        PKG_REMOVED=1
    fi

    local FILES_REMOVED=0
    if [ -d "/www/luci-static/resources/view/magitrickle" ]; then
        rm -rf /www/luci-static/resources/view/magitrickle
        rm -f /www/luci-static/resources/view/magitrickle.js
        rm -f /usr/share/luci/menu.d/luci-app-magitrickle.json
		rm -f /etc/magitrickle/state/config.yaml
		rm -f /etc/magitrickle/state/config.yaml-opkg
        FILES_REMOVED=1
    fi

    if [ "$PKG_REMOVED" -eq 1 ] || [ "$FILES_REMOVED" -eq 1 ]; then
        log_done "MagiTrickle и его файлы удалены."
    else
        log_done "MagiTrickle не найден (уже удалён)."
    fi
}

remove_dependencies() {
    log_info "Очистка зависимостей..."
    if is_pkg_installed kmod-nft-tproxy; then
        opkg remove kmod-nft-tproxy > /dev/null 2>&1
        echo "--> kmod-nft-tproxy удален."
    fi
}

cleanup_system() {
    log_info "Очистка кэша и перезапуск служб..."
    rm -rf /tmp/luci-indexcache /tmp/luci-modulecache/
    /etc/init.d/rpcd restart > /dev/null 2>&1
    /etc/init.d/uhttpd restart > /dev/null 2>&1
}

main() {
	clear
    log_done "Скрипт удаления Mixomo OpenWRT от Internet Helper"
    echo ""
    
    log_step "[1/4] Удаление Mihomo"
    remove_mihomo
    echo ""
    
    log_step "[2/4] Удаление Hev-Tunnel"
    remove_hev_tunnel
    echo ""
    
    log_step "[3/4] Удаление MagiTrickle"
    remove_magitrickle
    echo ""

    log_step "[4/4] Очистка системы"
    remove_dependencies
    cleanup_system
    echo ""
    
    log_done "Удаление успешно завершено!"
}

main