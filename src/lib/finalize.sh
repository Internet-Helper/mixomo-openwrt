#!/bin/sh
. "$MIXOMO_LIB_DIR/common.sh"

finalize_install() {
    chmod -R 755 /www/luci-static/resources/view/mihomo 2>/dev/null || true
    find /www/luci-static/resources/view/mihomo -type f -exec chmod 644 {} \; 2>/dev/null || true
    chmod 644 /www/luci-static/resources/view/magitrickle/magitrickle.js 2>/dev/null || true
    rm -rf /tmp/luci-indexcache /tmp/luci-modulecache 2>/dev/null || true
    /etc/init.d/rpcd restart >/dev/null 2>&1 || true
    /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
    /etc/init.d/hev-socks5-tunnel restart >/dev/null 2>&1 || true
    /etc/init.d/mihomo restart >/dev/null 2>&1 || true
    /etc/init.d/mixomo-schedule restart >/dev/null 2>&1 || true
    /etc/init.d/mixomo-routing restart >/dev/null 2>&1 || true
}
