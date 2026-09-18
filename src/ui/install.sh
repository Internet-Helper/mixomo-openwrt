#!/bin/sh
. "$MIXOMO_LIB_DIR/common.sh"

ui_install() {
    local view_path=/www/luci-static/resources/view/mihomo
    local ace_path=$view_path/ace
    local magi_view=/www/luci-static/resources/view/magitrickle
    ensure_dir "$view_path" || return 1
    ensure_dir "$ace_path" || return 1
    ensure_dir "$magi_view" || return 1
    rm -f "$view_path"/config-v*.js "$view_path/config.js"
    install_text_atomic "$MIXOMO_SOURCE_ROOT/src/ui/mihomo/config.js" "$view_path/config.js" 644 || return 1
    install_text_atomic "$MIXOMO_SOURCE_ROOT/src/ui/magitrickle.js" "$magi_view/magitrickle.js" 644 || return 1
    for file in ace.js theme-merbivore_soft.js theme-tomorrow.js mode-yaml.js worker-yaml.js; do
        install_text_atomic "$MIXOMO_SOURCE_ROOT/src/ui/mihomo/ace/$file" "$ace_path/$file" 644 || return 1
    done
    chmod 644 "$view_path/config.js" "$magi_view/magitrickle.js" "$ace_path"/* 2>/dev/null || true
    rm -rf /tmp/luci-indexcache /tmp/luci-modulecache 2>/dev/null || true
    /etc/init.d/rpcd restart >/dev/null 2>&1 || true
    /etc/init.d/uhttpd restart >/dev/null 2>&1 || true
}
