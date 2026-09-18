#!/bin/sh
. "$MIXOMO_LIB_DIR/common.sh"

[ "${MIXOMO_DEBUG:-0}" = 1 ] && set -x

hev_get_version() {
    if [ "$USE_APK" -eq 1 ]; then
        apk info -e hev-socks5-tunnel 2>/dev/null | sed 's/^hev-socks5-tunnel-//' | head -1
    else
        opkg list-installed 2>/dev/null | awk '$1 == "hev-socks5-tunnel" { print $3; exit }'
    fi
}

hev_install_package() {
    if [ "$USE_APK" -eq 1 ]; then
        mixomo_timeout 30 apk add -u hev-socks5-tunnel >/dev/null 2>&1 || mixomo_timeout 30 apk add hev-socks5-tunnel >/dev/null 2>&1
    else
        mixomo_timeout 30 opkg upgrade hev-socks5-tunnel >/dev/null 2>&1 || mixomo_timeout 30 opkg install hev-socks5-tunnel >/dev/null 2>&1
    fi
}

hev_write_config() {
    cat > /etc/hev-socks5-tunnel/main.yml <<'EOF'
tunnel:
  name: Mihomo
  mtu: 8500
  multi-queue: false
  ipv4: 198.18.0.1
socks5:
  port: 7890
  address: 127.0.0.1
  udp: 'udp'
EOF
    chmod 600 /etc/hev-socks5-tunnel/main.yml
}

hev_configure_uci() {
    ensure_dir /etc/hev-socks5-tunnel
    if ! uci -q get 'hev-socks5-tunnel.@instance[0]' >/dev/null 2>&1; then
        uci add hev-socks5-tunnel instance >/dev/null || return 1
    fi
    uci set 'hev-socks5-tunnel.@instance[0].enabled=1' || return 1
    uci set 'hev-socks5-tunnel.@instance[0].conffile=/etc/hev-socks5-tunnel/main.yml' || return 1
    uci commit hev-socks5-tunnel || return 1
    /etc/init.d/hev-socks5-tunnel restart >/dev/null 2>&1 || true
}

hev_configure_network() {
    if ! uci -q get network.Mihomo >/dev/null 2>&1; then
        uci set network.Mihomo=interface
    fi
    uci set network.Mihomo.proto=none
    uci set network.Mihomo.device=Mihomo
    uci commit network
    /etc/init.d/network reload >/dev/null 2>&1 || true
}

hev_dedup_forwardings() {
    local sec first dup
    first=""
    dup=0
    for sec in $(uci show firewall 2>/dev/null | sed -n "s/^firewall\.\([^.=]*\)=forwarding$/\1/p"); do
        [ "$(uci -q get "firewall.$sec.src" 2>/dev/null)" = "lan" ] || continue
        [ "$(uci -q get "firewall.$sec.dest" 2>/dev/null)" = "Mihomo" ] || continue
        if [ -z "$first" ]; then
            first="$sec"
        else
            uci -q delete "firewall.$sec" 2>/dev/null && dup=1
        fi
    done
    if [ "$dup" = 1 ]; then
        uci commit firewall || return 1
        /etc/init.d/firewall reload >/dev/null 2>&1 || true
    fi
}

hev_configure_firewall() {
    local zone forward
    hev_dedup_forwardings || return 1
    zone=$(uci show firewall 2>/dev/null | sed -n "s/^firewall\.\([^.]*\)\.name='Mihomo'$/\1/p" | head -1)
    if [ -z "$zone" ]; then
        zone=$(uci add firewall zone)
        uci set "firewall.${zone}.name=Mihomo"
        uci set "firewall.${zone}.input=REJECT"
        uci set "firewall.${zone}.output=REJECT"
        uci set "firewall.${zone}.forward=REJECT"
        uci set "firewall.${zone}.masq=1"
        uci set "firewall.${zone}.mtu_fix=1"
        uci add_list "firewall.${zone}.network=Mihomo"
    fi
    forward=$(uci show firewall 2>/dev/null | sed -n "s/^firewall\.\([^.]*\)\.src='lan'$/\1/p" | while read -r sec; do [ "$(uci -q get "firewall.$sec.dest" 2>/dev/null)" = "Mihomo" ] && { echo "$sec"; break; }; done)
    if [ -z "$forward" ]; then
        forward=$(uci add firewall forwarding)
        uci set "firewall.${forward}.src=lan"
        uci set "firewall.${forward}.dest=Mihomo"
    fi
    uci commit firewall
    /etc/init.d/firewall reload >/dev/null 2>&1 || true
}

hev_install() {
    if ! package_is_installed hev-socks5-tunnel; then
        hev_install_package || true
    fi
    if ! package_is_installed hev-socks5-tunnel; then
        log_warn "$(T "hev-socks5-tunnel недоступен в репозитории" "hev-socks5-tunnel is not available in the repo")"
        return 0
    fi
    hev_write_config || return 1
    hev_configure_uci || return 1
    hev_configure_network || return 1
    hev_configure_firewall || return 1
    version=$(hev_get_version)
    if [ -n "$version" ]; then
        ensure_dir "$MIXOMO_VERSIONS_DIR" || return 1
        printf '%s\n' "$version" > "$HEV_VERSION_FILE"
    fi
    step_done "$(T "hev-socks5-tunnel установлен" "hev-socks5-tunnel installed")"
}
