#!/bin/sh
. "$MIXOMO_LIB_DIR/common.sh"

[ "${MIXOMO_DEBUG:-0}" = 1 ] && set -x

mihomo_asset() { asset_path "config/mihomo.yaml"; }
mihomo_init_asset() { asset_path "init/mihomo"; }
MIHOMO_PROXY_ENABLED=0
MIHOMO_PUBLIC_PROXIES="https://ghproxy.net/ https://gh-proxy.com/"

mihomo_proxy_url() {
    printf '%s%s' "$1" "$2"
}

mihomo_proxy_download() {
    local proxy="$1" url="$2" output="$3"
    url=$(mihomo_proxy_url "$proxy" "$url")
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 15 --max-time 300 -o "$output" "$url"
    else
        wget -q -T 300 -O "$output" "$url"
    fi
}

mihomo_proxy_release() {
    local proxy json tag
    for proxy in $MIHOMO_PUBLIC_PROXIES; do
        if command -v curl >/dev/null 2>&1; then
            json=$(curl -fsSL --connect-timeout 15 --max-time 60 "$(mihomo_proxy_url "$proxy" "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest")" 2>/dev/null || true)
        else
            json=$(wget -qO- -T 60 "$(mihomo_proxy_url "$proxy" "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest")" 2>/dev/null || true)
        fi
        tag=$(printf '%s\n' "$json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
        if [ -n "$tag" ]; then
            mixomo_github_api_ok
            printf '%s\n' "$tag"
            return 0
        fi
    done
    return 1
}

mihomo_enable_proxy() {
    [ "$MIHOMO_PROXY_ENABLED" -eq 1 ] && return 0
    has_tty || return 1
    printf '%s\n' "$(T "Попробовать скачать Mihomo через публичные GitHub-прокси?" "Try downloading Mihomo through public GitHub proxies?")"
    printf '%s\n' "1. $(T "Да (можно нажать Enter для выбора)" "Yes (press Enter to select)")"
    printf '%s\n' "2. $(T "Нет, остановить установку" "No, stop installation")"
    printf '%s' "$(T "Ваш выбор: " "Your choice: ")"
    choice=$(read_user_input) || return 1
    case "$choice" in
        1|"") MIHOMO_PROXY_ENABLED=1; return 0 ;;
        2) return 1 ;;
        *) mihomo_enable_proxy ;;
    esac
}

mihomo_get_release() {
    local ver
    ver=$(curl -Ls --connect-timeout 10 --max-time 30 -o /dev/null -w '%{url_effective}' https://github.com/MetaCubeX/mihomo/releases/latest 2>/dev/null \
        | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' \
        | head -1)
    if [ -n "$ver" ]; then
        mixomo_github_api_ok
        printf '%s\n' "$ver"
    elif mihomo_enable_proxy; then
        mihomo_proxy_release
    else
        mixomo_github_api_fail
    fi
}

mihomo_install_config() {
    local was_running=0
    [ -x /etc/init.d/mihomo ] && /etc/init.d/mihomo running >/dev/null 2>&1 && was_running=1
    install_text_atomic "$(mihomo_asset)" "$MIHOMO_TEMPLATE" 644 || return 1
    if [ -f "$MIHOMO_CONFIG" ] && grep -qE '^[[:space:]]*mixed-port:[[:space:]]*7890([[:space:]]|$)' "$MIHOMO_CONFIG"; then
        step_done "$(T "Конфигурация Mihomo сохранена" "Mihomo configuration preserved")"
    else
        if [ -f "$MIHOMO_CONFIG" ]; then
             cp -p "$MIHOMO_CONFIG" "${MIHOMO_CONFIG}.pre-v0.3.3.bak" 2>/dev/null || true
        fi
        install_text_atomic "$(mihomo_asset)" "$MIHOMO_CONFIG" 644 || return 1
            step_done "$(T "Создана новая конфигурация Mihomo" "Created a new Mihomo configuration")"
    fi
    [ "$was_running" -eq 1 ] && /etc/init.d/mihomo restart >/dev/null 2>&1 || true
}

mihomo_update_binary() {
    local arch release filename url temp_dir archive new_bin backup was_running
    release=$(mihomo_get_release)
    [ -n "$release" ] || { log_error "$(T "Не удалось определить версию Mihomo" "Could not determine the Mihomo release")"; return 1; }
    arch=${MIHOMO_ARCH:-$(detect_mihomo_arch)} || return 1
    filename="mihomo-linux-${arch}-${release}.gz"
    url="https://github.com/MetaCubeX/mihomo/releases/download/${release}/${filename}"
    temp_dir=$(mktemp -d /tmp/mixomo.XXXXXX) || return 1
    archive=$temp_dir/archive.gz
    new_bin=$temp_dir/mihomo
    backup=$temp_dir/previous
    if ! download_to "$url" "$archive"; then
        if ! mihomo_enable_proxy; then
            rm -rf "$temp_dir"
            return 1
        fi
        local proxy
        for proxy in $MIHOMO_PUBLIC_PROXIES; do
            if mihomo_proxy_download "$proxy" "$url" "$archive"; then
                break
            fi
        done
        [ -s "$archive" ] || { rm -rf "$temp_dir"; return 1; }
    fi
    if ! gunzip -c "$archive" > "$new_bin" || [ ! -s "$new_bin" ] || ! chmod +x "$new_bin" || ! "$new_bin" -v >/dev/null 2>&1; then
        rm -rf "$temp_dir"
        return 1
    fi
    was_running=0
    [ -x /etc/init.d/mihomo ] && /etc/init.d/mihomo running >/dev/null 2>&1 && was_running=1
    if [ -f "$MIHOMO_BIN" ]; then
        cp -p "$MIHOMO_BIN" "$backup" || { rm -rf "$temp_dir"; return 1; }
    fi
    if ! mv -f "$new_bin" "$MIHOMO_BIN" || ! chmod +x "$MIHOMO_BIN"; then
        [ -n "$backup" ] && cp -p "$backup" "$MIHOMO_BIN" 2>/dev/null || true
        [ "$was_running" -eq 1 ] && /etc/init.d/mihomo start >/dev/null 2>&1 || true
        rm -rf "$temp_dir"
        return 1
    fi
    ensure_dir "$MIXOMO_VERSIONS_DIR" || true
    printf '%s\n' "$release" > "$MIHOMO_VERSION_FILE"
    rm -rf "$temp_dir"
    [ "$was_running" -eq 1 ] && /etc/init.d/mihomo restart >/dev/null 2>&1 || true
}

mihomo_install_default_profile() {
    ensure_dir /etc/mihomo/profiles || return 1
    ensure_dir /etc/mixomo/profiles || return 1
    if [ ! -f /etc/mihomo/profiles/default.yaml ]; then
        cp -p "$MIHOMO_CONFIG" /etc/mihomo/profiles/default.yaml || return 1
    fi
    if [ ! -s /etc/mixomo/profiles/active ]; then
        printf '%s\n' default > /etc/mixomo/profiles/active || return 1
    fi
}

mihomo_install_service() {
    install_text_atomic "$(mihomo_init_asset)" /etc/init.d/mihomo 755 || return 1
    /etc/init.d/mihomo enable >/dev/null 2>&1 || true
}

mihomo_check() {
    [ -x "$MIHOMO_BIN" ] || return 1
    [ -s "$MIHOMO_CONFIG" ] || return 1
}

mihomo_install() {
    ensure_dir "$MIHOMO_INSTALL_DIR" || return 1
    ensure_dir "$MIHOMO_RULE_DIR" || return 1
    ensure_dir /etc/mihomo/proxy-providers || return 1
    ensure_dir /etc/mihomo/rule-providers || return 1
    ensure_dir /etc/mihomo/rule-files || return 1
    ensure_dir /etc/mihomo/UI/zashboard || return 1
    ensure_dir /etc/mihomo/UI/metacubex || return 1
    if ! mihomo_check; then
        mihomo_update_binary || return 1
    else
        local release
        release=$(mihomo_get_release)
        if [ -n "$release" ] && [ "$(tr -d ' \r\n' < "$MIHOMO_VERSION_FILE" 2>/dev/null)" != "$release" ]; then
            mihomo_update_binary || return 1
        fi
    fi
    mihomo_install_config || return 1
    mihomo_install_default_profile || return 1
    mihomo_install_service || return 1
    step_done "$(T "Mihomo установлен" "Mihomo installed")"
}
