#!/bin/sh

SCRIPT_VERSION="v0.3.4"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

STEP=""

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${GREEN}$*${NC}"; }
log_done()  { echo -e "${GREEN}$*${NC}"; }
step_info() { echo -e "${GREEN}${STEP} [INFO] $*${NC}"; }
step_done() { echo -e "${GREEN}${STEP} $*${NC}"; }

USE_APK=0
if command -v apk > /dev/null 2>&1; then
    USE_APK=1
fi

is_pkg_installed() {
    if [ "$USE_APK" -eq 1 ]; then
        apk list -I 2>/dev/null | grep -q "^${1}[.-]"
    else
        opkg list-installed 2>/dev/null | grep -q "^${1} "
    fi
}

remove_pkg() {
    if [ "$USE_APK" -eq 1 ]; then
        apk del "$1" > /dev/null 2>&1 || true
    else
        opkg remove "$1" > /dev/null 2>&1 || true
    fi
}

mihomo_artifacts_present() {
    [ -e "/etc/init.d/mihomo" ] || [ -e "/usr/bin/mihomo" ] || \
    [ -e "/etc/mihomo" ] || [ -e "/www/luci-static/resources/view/mihomo" ] || \
    [ -e "/usr/share/rpcd/ucode/mihomo-routing" ] || [ -e "/usr/share/rpcd/ucode/mihomo-dns" ] || \
    [ -e "/usr/share/rpcd/ucode/mihomo-profiles" ] || [ -e "/usr/share/rpcd/ucode/mihomo-schedule" ] || \
    [ -e "/usr/share/rpcd/ucode/mihomo-routing.uc" ] || [ -e "/usr/share/rpcd/ucode/mihomo-dns.uc" ] || \
    [ -e "/usr/share/rpcd/ucode/mihomo-profiles.uc" ] || [ -e "/usr/share/rpcd/ucode/mihomo-schedule.uc" ] || \
    [ -e "/usr/share/luci/menu.d/luci-app-mihomo.json" ] || \
    [ -e "/usr/share/luci/menu.d/luci-app-mixomo.json" ] || \
    [ -e "/usr/share/rpcd/acl.d/luci-app-mihomo.json" ] || \
    [ -e "/usr/share/rpcd/acl.d/luci-app-mixomo.json" ] || \
    [ -e "/usr/share/rpcd/ucode/mixomo-backup" ] || \
    [ -e "/usr/share/ucode/mixomo-profiles.uc" ] || \
    [ -e "/usr/libexec/rpcd/mihomo-routing" ] || [ -e "/usr/libexec/rpcd/mihomo-dns" ] || \
    [ -e "/usr/libexec/rpcd/mihomo-profiles" ] || [ -e "/usr/libexec/rpcd/mihomo-schedule" ]
}

remove_mihomo() {
    step_info "Проверка наличия Mihomo"
    local CLEANED=0

    if mihomo_artifacts_present; then
        CLEANED=1
    fi

    if [ -f "/etc/init.d/mihomo" ]; then
        /etc/init.d/mihomo stop 2>/dev/null || true
        /etc/init.d/mihomo disable 2>/dev/null || true
        rm -f /etc/init.d/mihomo
        CLEANED=1
    fi

    if [ -f "/usr/bin/mihomo" ]; then
        rm -f /usr/bin/mihomo
        CLEANED=1
    fi

    if [ -d "/etc/mihomo" ] || [ -d "/www/luci-static/resources/view/mihomo" ]; then
        CLEANED=1
    fi
    rm -rf /etc/mihomo
    rm -f /usr/share/ucode/mixomo.uc
    rm -f /usr/share/ucode/mixomo-files.uc /usr/share/ucode/mixomo-state.uc
    rm -f /usr/share/ucode/mixomo-config.uc /usr/share/ucode/mixomo-profiles.uc
    rm -f /usr/share/ucode/mixomo-rules.uc /usr/share/ucode/mixomo-schedules.uc
    rm -f /usr/share/ucode/mixomo-validation.uc
    rm -f /usr/share/rpcd/ucode/mihomo-routing /usr/share/rpcd/ucode/mihomo-dns
    rm -f /usr/share/rpcd/ucode/mihomo-profiles /usr/share/rpcd/ucode/mihomo-schedule
    rm -f /usr/share/rpcd/ucode/mixomo-backup
    rm -f /usr/share/rpcd/ucode/mihomo-routing.uc /usr/share/rpcd/ucode/mihomo-dns.uc
    rm -f /usr/share/rpcd/ucode/mihomo-profiles.uc /usr/share/rpcd/ucode/mihomo-schedule.uc
    rm -f /usr/share/luci/menu.d/luci-app-mihomo.json /usr/share/luci/menu.d/luci-app-mixomo.json
    rm -f /usr/share/rpcd/acl.d/luci-app-mihomo.json /usr/share/rpcd/acl.d/luci-app-mixomo.json
    rm -f /usr/libexec/rpcd/mihomo-routing /usr/libexec/rpcd/mihomo-dns
    rm -f /usr/libexec/rpcd/mihomo-profiles /usr/libexec/rpcd/mihomo-schedule
    rm -f /etc/init.d/mixomo-schedule
    rm -rf /www/luci-static/resources/view/mihomo

    if [ "$CLEANED" -eq 1 ]; then
        step_done "Mihomo и его файлы успешно удалены"
    else
        step_done "Mihomo не найден или уже был удалён"
    fi
}

cleanup_dnsmasq_rules() {
    local file=/etc/dnsmasq.conf
    local temp
    [ -f "$file" ] || return 0
    temp=$(mktemp /tmp/mixomo-dnsmasq.XXXXXX 2>/dev/null) || return 0
    if awk -v start='# Rules from Mixomo' -v end='# End rules from Mixomo' '
        { lines[NR] = $0 }
        !inside && $0 == start { begin = NR; inside = 1; next }
        inside && $0 == end {
            for (i = begin; i <= NR; i++) drop[i] = 1
            inside = 0
        }
        END {
            for (i = 1; i <= NR; i++) if (!drop[i]) print lines[i]
        }
    ' "$file" > "$temp"; then
        mv "$temp" "$file"
    else
        rm -f "$temp"
    fi
}

remove_hev_tunnel() {
    step_info "Проверка наличия hev-socks5-tunnel"
    local PRESENT=0
    if [ -e "/etc/init.d/hev-socks5-tunnel" ] || [ -e "/etc/hev-socks5-tunnel" ] || \
       [ -e "/etc/config/hev-socks5-tunnel" ] || is_pkg_installed hev-socks5-tunnel; then
        PRESENT=1
    fi

    if [ -f "/etc/init.d/hev-socks5-tunnel" ]; then
        /etc/init.d/hev-socks5-tunnel stop 2>/dev/null || true
    fi

    if is_pkg_installed hev-socks5-tunnel; then
        remove_pkg hev-socks5-tunnel
    fi

    rm -rf /etc/hev-socks5-tunnel
    rm -f /etc/config/hev-socks5-tunnel

    uci delete network.Mihomo 2>/dev/null || true

    local fw_section
    for fw_section in $(uci show firewall 2>/dev/null \
            | grep -E "\.name='Mihomo'" \
            | sed "s/\.name.*//"); do
        uci delete "$fw_section" 2>/dev/null || true
    done

    for fw_section in $(uci show firewall 2>/dev/null \
            | grep -E "\.(src|dest)='Mihomo'" \
            | sed -E "s/\.(src|dest).*//"); do
        uci delete "$fw_section" 2>/dev/null || true
    done

    uci delete firewall.Mihomo 2>/dev/null || true
    uci delete firewall.lan_to_Mihomo 2>/dev/null || true

    uci commit network
    uci commit firewall

    /etc/init.d/network reload 2>/dev/null || true
    /etc/init.d/firewall restart 2>/dev/null || true

    if [ "$PRESENT" -eq 1 ]; then
        step_done "hev-socks5-tunnel и настройки удалены"
    else
        step_done "hev-socks5-tunnel не найден или уже был удалён"
    fi
}

cleanup_mixomo_routing() {
    step_info "Проверка файлов локальной маршрутизации Mixomo"
    local PRESENT=0
    local MARK=1298229097

    if [ -r /etc/mixomo/routing/redir-mark ]; then
        MARK=$(tr -d ' \r\n' < /etc/mixomo/routing/redir-mark 2>/dev/null)
    elif [ -f /etc/magitrickle/state/config.yaml ]; then
        local m
        m=$(grep -E '^[[:space:]]*startMarkTableIndex:' /etc/magitrickle/state/config.yaml 2>/dev/null | awk '{print $2}' | tr -d ' \r\n')
        [ -n "$m" ] && MARK="$m"
    fi

    if [ -e /etc/mixomo ] || [ -e /etc/init.d/mixomo-local-routing ] || [ -e /etc/init.d/mixomo-routing ] || \
       [ -e /usr/libexec/mixomo-redir ] || [ -e /etc/mihomo/mihomo-router-routing.nft ]; then
        PRESENT=1
    fi
    uci show network 2>/dev/null | grep -q 'mihomo_route_\|mihomo_routing_table' && PRESENT=1
    uci -q get firewall.mihomo_router_routing >/dev/null 2>&1 && PRESENT=1

    local IPT=""
    if command -v iptables >/dev/null 2>&1; then IPT=iptables
    elif command -v iptables-nft >/dev/null 2>&1; then IPT=iptables-nft
    fi
    if [ -n "$IPT" ]; then
        local t
        for t in nat mangle; do
            "$IPT" -t "$t" -F MIXOMO_CLASSIFY 2>/dev/null || true
            "$IPT" -t "$t" -D PREROUTING -i lo -j MIXOMO_CLASSIFY 2>/dev/null || true
            "$IPT" -t "$t" -D PREROUTING ! -i lo -j MIXOMO_CLASSIFY 2>/dev/null || true
            "$IPT" -t "$t" -X MIXOMO_CLASSIFY 2>/dev/null || true
        done
    fi

    ip rule del fwmark "$MARK" lookup "$MARK" 2>/dev/null || true
    ip route del local default dev lo table "$MARK" 2>/dev/null || true

    local p=18000
    while [ "$p" -lt 19000 ]; do
        ip rule del priority "$p" 2>/dev/null
        p=$((p + 1))
    done

    local sec
    for sec in $(uci show network 2>/dev/null | sed -n "s/^network\\.\\(mihomo_route_[^.=]*\\)=\\(rule\\|mihomo_rule\\|mihomo_excl\\)$/\\1/p"); do
        uci -q delete "network.$sec"
    done
    uci -q delete network.mihomo_routing_table
    uci commit network 2>/dev/null || true

    uci -q delete firewall.mihomo_router_routing
    uci commit firewall 2>/dev/null || true
    rm -f /etc/mihomo/mihomo-router-routing.nft
    nft delete chain inet fw4 mihomo_router_routing 2>/dev/null || true
    nft delete table inet mihomo_router_routing 2>/dev/null || true
    nft delete table inet mixomo_redir 2>/dev/null || true

    /etc/init.d/mixomo-local-routing stop 2>/dev/null || true
    /etc/init.d/mixomo-routing stop 2>/dev/null || true
    rm -f /etc/init.d/mixomo-local-routing /etc/init.d/mixomo-routing
    rm -rf /etc/mixomo
    rm -f /usr/libexec/mixomo-redir

    /etc/init.d/network reload 2>/dev/null || true
    /etc/init.d/firewall reload 2>/dev/null || true

    if [ "$PRESENT" -eq 1 ]; then
        step_done "Локальная маршрутизация Mixomo удалена"
    else
        step_done "Локальная маршрутизация Mixomo не найдена или уже была удалена"
    fi
}

remove_magitrickle() {
    step_info "Проверка наличия MagiTrickle"
    local PRESENT=0

    if [ -f "/etc/init.d/magitrickle" ]; then
        /etc/init.d/magitrickle stop 2>/dev/null || true
        /etc/init.d/magitrickle disable 2>/dev/null || true
    fi

    if is_pkg_installed magitrickle_mod || is_pkg_installed magitrickle; then
        PRESENT=1
    fi
    if [ -e "/etc/init.d/magitrickle" ] || [ -e "/etc/magitrickle" ] || [ -e "/etc/config/magitrickle" ]; then
        PRESENT=1
    fi

    if [ "$PRESENT" -eq 1 ]; then
        step_info "Найден MagiTrickle"
    fi

    if [ "$USE_APK" -eq 1 ]; then
        apk del magitrickle_mod magitrickle >/dev/null 2>&1 || true
    else
        opkg remove magitrickle_mod >/dev/null 2>&1 || true
        opkg remove magitrickle >/dev/null 2>&1 || true
    fi

    rm -rf /www/luci-static/resources/view/magitrickle
    rm -f /usr/share/luci/menu.d/luci-app-magitrickle.json
    rm -f /etc/init.d/magitrickle /opt/etc/init.d/S99magitrickle
    rm -rf /etc/magitrickle
    rm -f /etc/config/magitrickle
    uci -q delete magitrickle
    uci -q commit magitrickle 2>/dev/null

    if [ "$PRESENT" -eq 1 ]; then
        step_done "MagiTrickle и его файлы удалены"
    else
        step_done "MagiTrickle не найден или уже был удалён"
    fi
}

cleanup_system() {
    step_info "Очистка кэша и перезапуск служб"
    rm -rf /tmp/luci-indexcache /tmp/luci-modulecache/
    /etc/init.d/rpcd restart > /dev/null 2>&1 || true
    /etc/init.d/uhttpd restart > /dev/null 2>&1 || true
}

main() {
    echo ""
    log_done "Mixomo OpenWrt $SCRIPT_VERSION"
    echo ""

    STEP="[1/5]"
    log_step "[1/5] Удаление Mihomo"
    remove_mihomo
    cleanup_dnsmasq_rules

    STEP="[2/5]"
    log_step "[2/5] Удаление локальной маршрутизации Mixomo"
    cleanup_mixomo_routing

    STEP="[3/5]"
    log_step "[3/5] Удаление hev-socks5-tunnel"
    remove_hev_tunnel

    STEP="[4/5]"
    log_step "[4/5] Удаление MagiTrickle"
    remove_magitrickle

    STEP="[5/5]"
    log_step "[5/5] Завершение"
    cleanup_system

    log_done "Удаление Mixomo OpenWrt $SCRIPT_VERSION завершено"
}

main