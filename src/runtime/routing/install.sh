#!/bin/sh
. "$MIXOMO_LIB_DIR/common.sh"

mihomo_ensure_redir_port() {
    local config=/etc/mihomo/config.yaml
    local port existing
    existing=$(grep -E '^[[:space:]]*redir-port:' "$config" 2>/dev/null | awk '{print $2}' | head -1 | tr -d ' \r\n')
    if [ -n "$existing" ] && [ "$existing" -ge 1 ] 2>/dev/null && [ "$existing" -le 65535 ] 2>/dev/null; then
        printf '%s\n' "$existing"
        return 0
    fi
    port=5001
    while [ "$port" -le 65535 ]; do
        if ! (ss -lnt 2>/dev/null | awk '{print $4}' | grep -q ":${port}$"); then
            break
        fi
        port=$((port + 1))
    done
    [ "$port" -le 65535 ] || return 1
    sed -i "1i redir-port: ${port}" "$config" 2>/dev/null || true
    printf '%s\n' "$port"
}

routing_write_state() {
    local port mark
    ensure_dir "$MIXOMO_REDIR_DIR" || return 1
    ensure_dir "$MIXOMO_VERSIONS_DIR" || return 1
    port=$(mihomo_ensure_redir_port) || return 1
    printf '%s\n' "$port" > "$MIXOMO_REDIR_PORT_FILE"
    mark=$(grep -E '^[[:space:]]*startMarkTableIndex:' /etc/magitrickle/state/config.yaml 2>/dev/null | awk '{print $2}' | head -1 | tr -d ' \r\n')
    [ -n "$mark" ] || mark="$MIXOMO_REDIR_DEFAULT_MARK"
    printf '%s\n' "$mark" > "$MIXOMO_REDIR_MARK_FILE"
}

routing_install() {
    ensure_dir "$MIXOMO_REDIR_DIR" || return 1
    install_text_atomic "$MIXOMO_SOURCE_ROOT/src/runtime/routing/redir" "$MIXOMO_REDIR_SCRIPT" 755 || return 1
    install_text_atomic "$(asset_path init/mixomo-routing)" /etc/init.d/mixomo-routing 755 || return 1
    rm -f /etc/init.d/mixomo-local-routing
    /etc/init.d/mixomo-routing enable >/dev/null 2>&1 || true
    routing_write_state || return 1
}
