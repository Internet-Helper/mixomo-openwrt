#!/bin/sh
. "$MIXOMO_LIB_DIR/common.sh"

runtime_ucode_source() { printf '%s/src/ucode/%s' "$MIXOMO_SOURCE_ROOT" "$1"; }

runtime_ucode_install() {
    local source name
    ensure_dir /usr/share/ucode || return 1
    ensure_dir /usr/share/rpcd/ucode || return 1
    ensure_dir /usr/libexec/rpcd || return 1
    ensure_dir /usr/share/luci/menu.d || return 1
    ensure_dir /usr/share/rpcd/acl.d || return 1
    install_text_atomic "$(runtime_ucode_source mixomo.uc)" /usr/share/ucode/mixomo.uc 644 || return 1
    for name in mixomo-files mixomo-state mixomo-config mixomo-profiles mixomo-rules mixomo-schedules mixomo-validation; do
        install_text_atomic "$(runtime_ucode_source lib/$name.uc)" "/usr/share/ucode/$name.uc" 644 || return 1
    done
    for name in mihomo-dns mihomo-profiles mihomo-schedule mihomo-routing mixomo-backup; do
        install_text_atomic "$(runtime_ucode_source rpc/$name.uc)" "/usr/share/rpcd/ucode/$name" 644 || return 1
    done
    rm -f /usr/libexec/rpcd/mihomo-dns /usr/libexec/rpcd/mihomo-routing /usr/libexec/rpcd/mihomo-profiles /usr/libexec/rpcd/mihomo-schedule /usr/libexec/rpcd/mixomo-backup
    rm -f /usr/share/rpcd/ucode/mihomo-routing.uc /usr/share/rpcd/ucode/mihomo-profiles.uc /usr/share/rpcd/ucode/mihomo-schedule.uc /usr/share/rpcd/ucode/mihomo-dns.uc
    source=$(runtime_ucode_source daemon)
    ensure_dir /etc/mihomo/profiles || return 1
    ensure_dir /etc/mihomo/rule-files || return 1
    ensure_dir /etc/mixomo/profiles || return 1
    ensure_dir /etc/mixomo/order || return 1
    ensure_dir /etc/mixomo/schedule || return 1
    ensure_dir /etc/mixomo/dns || return 1
    if [ ! -e /etc/mixomo/dns/custom ]; then
        printf '%b\n' \
            'Mihomo\t127.0.0.1#7880' \
            'Google\t8.8.8.8 8.8.4.4' \
            'Cloudflare\t1.1.1.1 1.0.0.1' \
            'Quad9\t9.9.9.9 149.112.112.112' \
            'AdGuard\t94.140.14.140 94.140.14.141' \
            'Yandex\t77.88.8.8 77.88.8.1' > /etc/mixomo/dns/custom
    else
        sed -i 's/\\t/\t/g' /etc/mixomo/dns/custom 2>/dev/null || true
    fi
    install_text_atomic "$source" /etc/mixomo/schedule/daemon 755 || return 1
    install_text_atomic "$(asset_path init/mixomo-schedule)" /etc/init.d/mixomo-schedule 755 || return 1
    install_text_atomic "$(asset_path acl/luci-app-mixomo.json)" /usr/share/rpcd/acl.d/luci-app-mixomo.json 644 || return 1
    install_text_atomic "$(asset_path menu/mixomo.json)" /usr/share/luci/menu.d/luci-app-mixomo.json 644 || return 1
    rm -f /usr/share/luci/menu.d/luci-app-mihomo.json /usr/share/luci/menu.d/luci-app-magitrickle.json /usr/share/rpcd/acl.d/luci-app-mihomo.json
    service mixomo-schedule enable >/dev/null 2>&1 || true
    service mixomo-schedule restart >/dev/null 2>&1 || true
    /etc/init.d/rpcd restart >/dev/null 2>&1 || true
}
