#!/bin/sh
. "$MIXOMO_LIB_DIR/common.sh"

[ "${MIXOMO_DEBUG:-0}" = 1 ] && set -x

MAGITRICKLE_VARIANT=""

magitrickle_prompt() {
    local text="$1"
    printf "${GREEN}%s${NC}%s" "${MIXOMO_STEP:+$MIXOMO_STEP }" "$text"
}

magitrickle_line() {
    printf "${GREEN}%s${NC}%s\n" "${MIXOMO_STEP:+$MIXOMO_STEP }" "$1"
}

magitrickle_read_variant() {
    sed -n '1p' "$MAGITRICKLE_VERSION_FILE" 2>/dev/null | tr -d ' \r\n'
}

magitrickle_read_version() {
    sed -n '2p' "$MAGITRICKLE_VERSION_FILE" 2>/dev/null | tr -d ' \r\n'
}

magitrickle_detect_variant() {
    local variant
    variant=$(magitrickle_read_variant)
    case "$variant" in
        original|mod) printf '%s' "$variant"; return ;;
    esac
    if [ ! -x /etc/init.d/magitrickle ] && [ ! -f /etc/magitrickle/state/config.yaml ]; then
        return 0
    fi
    if [ -f /etc/magitrickle/state/config.yaml ] && grep -q 'tproxyPort' /etc/magitrickle/state/config.yaml 2>/dev/null; then
        printf 'mod'
    else
        printf 'original'
    fi
}

magitrickle_save_variant() {
    local variant="$1"
    local version="${2:-$(magitrickle_read_version)}"
    ensure_dir "$(dirname "$MAGITRICKLE_VERSION_FILE")" || return 1
    printf '%s\n%s\n' "$variant" "$version" > "$MAGITRICKLE_VERSION_FILE"
}

magitrickle_latest_version() {
    local variant="$1"
    local json tag
    if [ "$variant" = mod ]; then
        if command -v curl >/dev/null 2>&1; then
            json=$(curl -fsSL --connect-timeout 10 --max-time 30 https://api.github.com/repos/badigit/MagiTrickle_mod_badigit/releases/latest 2>/dev/null)
        else
            json=$(wget -qO- -T 30 https://api.github.com/repos/badigit/MagiTrickle_mod_badigit/releases/latest 2>/dev/null)
        fi
    else
        if command -v curl >/dev/null 2>&1; then
            json=$(curl -fsSL --connect-timeout 10 --max-time 30 https://gitlab.com/api/v4/projects/magitrickle%2Fmagitrickle/releases/permalink/latest 2>/dev/null)
        else
            json=$(wget -qO- -T 30 https://gitlab.com/api/v4/projects/magitrickle%2Fmagitrickle/releases/permalink/latest 2>/dev/null)
        fi
    fi
    tag=$(printf '%s\n' "$json" | grep -m1 '"tag_name"' | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    if [ -n "$tag" ]; then
        mixomo_github_api_ok
        printf '%s\n' "$tag"
    else
        mixomo_github_api_fail
    fi
}

magitrickle_label() {
    [ "$1" = mod ] && printf 'Mod' || printf 'Original'
}

magitrickle_select() {
    local installed choice other other_label label
    case "$MAGITRICKLE" in
        original|mod) MAGITRICKLE_VARIANT="$MAGITRICKLE"; return ;;
    esac
    if [ -n "$MAGITRICKLE" ]; then
        log_error "$(T "Некорректное значение MAGITRICKLE" "Invalid MAGITRICKLE value")"
        return 1
    fi
    if ! has_tty; then
        log_error "$(T "MAGITRICKLE не задан. Укажите MAGITRICKLE=mod или MAGITRICKLE=original" "MAGITRICKLE is not set. Specify MAGITRICKLE=mod or MAGITRICKLE=original")"
        return 1
    fi
    installed=$(magitrickle_detect_variant)
    if [ -n "$installed" ]; then
        label=$(magitrickle_label "$installed")
        magitrickle_line "$(T "Установленная версия: $label" "Installed version: $label")"
        magitrickle_line "1) $(T "Обновить $label (нажмите Enter для выбора)" "Update $label (press Enter to select)")"
        if [ "$installed" = mod ]; then other=original; else other=mod; fi
        other_label=$(magitrickle_label "$other")
        magitrickle_line "2) $(T "Изменить версию на $other_label" "Switch version to $other_label")"
        magitrickle_prompt "$(T "Ваш выбор: " "Your choice: ")"
        choice=$(read_user_input) || return 1
        case "$choice" in
            1|"") MAGITRICKLE_VARIANT="$installed" ;;
            2) MAGITRICKLE_VARIANT="$other" ;;
            *) magitrickle_select ;;
        esac
    else
        magitrickle_line "$(T "Какую версию установить?" "Which version to install?")"
        magitrickle_line "1. Original $(T "(нажмите Enter для выбора)" "(press Enter to select)")"
        magitrickle_line "2. Mod"
        magitrickle_prompt "$(T "Ваш выбор: " "Your choice: ")"
        choice=$(read_user_input) || return 1
        case "$choice" in
            1|"") MAGITRICKLE_VARIANT=original ;;
            2) MAGITRICKLE_VARIANT=mod ;;
            *) magitrickle_select ;;
        esac
    fi
}

magitrickle_install_package() {
    local script log temp_dir
    temp_dir=$(mktemp -d /tmp/mixomo.XXXXXX) || return 1
    if [ "$MAGITRICKLE_VARIANT" = mod ]; then
        log=$temp_dir/install.log
        script=$temp_dir/install.sh
        if ! download_to https://raw.githubusercontent.com/badigit/MagiTrickle_mod_badigit/mod_badigit/scripts/install.sh "$script" 60; then
            rm -rf "$temp_dir"
            return 1
        fi
        mixomo_timeout 180 sh "$script" >"$log" 2>&1
        rc=$?
        if [ "$rc" -ne 0 ] || { [ ! -x /etc/init.d/magitrickle ] && [ ! -f /etc/magitrickle/state/config.yaml ] && ! package_is_installed magitrickle && ! package_is_installed magitrickle_mod; }; then
            log_error "$(T "Ошибка установки MagiTrickle Mod; лог: $log (rc=$rc)" "MagiTrickle Mod install failed; log: $log (rc=$rc)")"
            if [ -f "$log" ]; then
                printf '%s\n' "$(T "---- содержимое лога ----" "---- log content ----")" >&2
                sed -n '1,80p' "$log" >&2
            fi
            return 1
        fi
    else
        if command -v curl >/dev/null 2>&1; then
            script=$temp_dir/add-repo.sh
            if ! curl -fsSL --connect-timeout 10 --max-time 60 http://bin.magitrickle.dev/packages/add_repo.sh -o "$script"; then
                rm -rf "$temp_dir"
                return 1
            fi
            sh "$script" >/dev/null 2>&1
            rc=$?
            [ "$rc" -eq 0 ] || { rm -rf "$temp_dir"; return 1; }
        else
            wget -qO- -T 60 http://bin.magitrickle.dev/packages/add_repo.sh | sh >/dev/null 2>&1 || { rm -rf "$temp_dir"; return 1; }
        fi
        package_update >/dev/null 2>&1 || true
        if ! package_install_timeout 180 magitrickle >/dev/null 2>&1; then
            rm -rf "$temp_dir"
            return 1
        fi
        if [ "$USE_APK" -eq 1 ]; then
            mixomo_timeout 30 apk fix magitrickle >/dev/null 2>&1 || true
            if [ ! -f /etc/config/magitrickle ] || [ ! -f /etc/magitrickle/state/config.yaml ]; then
                mixomo_timeout 30 apk del magitrickle >/dev/null 2>&1 || true
                package_install_timeout 180 magitrickle >/dev/null 2>&1 || { rm -rf "$temp_dir"; return 1; }
            fi
        fi
        [ -x /etc/init.d/magitrickle ] || { rm -rf "$temp_dir"; return 1; }
    fi
    rm -rf "$temp_dir"
}

magitrickle_is_running() {
    service magitrickle status 2>/dev/null | grep -qi running && return 0
    [ -S /var/run/magitrickle.sock ] && return 0
    ps 2>/dev/null | grep -q '[m]agitrickled'
}

magitrickle_wait_running() {
    local attempt=0
    while [ "$attempt" -lt 10 ]; do
        magitrickle_is_running && return 0
        sleep 1
        attempt=$((attempt + 1))
    done
    return 1
}

magitrickle_restore_config() {
    local config=/etc/magitrickle/state/config.yaml
    local backup=/tmp/magitrickle_config_backup.yaml
    local old_version new_version
    [ -f "$backup" ] || return 0
    if [ ! -f "$config" ]; then
        mkdir -p "$(dirname "$config")"
        cp "$backup" "$config"
    else
        old_version=$(grep -E '^[[:space:]]*configVersion:' "$backup" | awk '{print $2}' | tr -d ' "\r\n')
        new_version=$(grep -E '^[[:space:]]*configVersion:' "$config" | awk '{print $2}' | tr -d ' "\r\n')
        if [ -z "$old_version" ] || [ -z "$new_version" ] || [ "$old_version" != "$new_version" ]; then
            cp "$backup" "${config}.backup" 2>/dev/null || true
        else
            cp "$backup" "$config"
        fi
    fi
    rm -f "$backup"
}

magitrickle_install() {
    local installed latest now_version config=/etc/magitrickle/state/config.yaml
    local temp_dir
    magitrickle_select || return 1
    step_start "${MIXOMO_STEP:+$MIXOMO_STEP }[ONLINE] $(T "Загрузка MagiTrickle" "Downloading MagiTrickle")"
    installed=$(magitrickle_read_variant)
    [ "$installed" = "$MAGITRICKLE_VARIANT" ] && [ -x /etc/init.d/magitrickle ] && {
        now_version=$(magitrickle_read_version)
        if [ -n "$now_version" ]; then
            latest=$(magitrickle_latest_version "$MAGITRICKLE_VARIANT")
        fi
    }
    if [ -x /etc/init.d/magitrickle ] && [ "$installed" = "$MAGITRICKLE_VARIANT" ] && magitrickle_is_running && { [ -z "$now_version" ] || [ -z "$latest" ] || [ "$now_version" = "$latest" ]; }; then
        step_done "$(T "Установлена актуальная версия" "Up-to-date version installed")"
        return 0
    else
        [ -f "$config" ] && cp "$config" /tmp/magitrickle_config_backup.yaml 2>/dev/null || true
        service magitrickle stop >/dev/null 2>&1 || true
        service magitrickle disable >/dev/null 2>&1 || true
        [ -f "$config" ] && rm -f "$config" || true
        if [ "$USE_APK" -eq 1 ]; then
            mixomo_timeout 30 apk del magitrickle_mod magitrickle >/dev/null 2>&1 || true
        else
            mixomo_timeout 30 opkg remove magitrickle_mod >/dev/null 2>&1 || true
            mixomo_timeout 30 opkg remove magitrickle >/dev/null 2>&1 || true
        fi
        rm -f /etc/init.d/magitrickle
        magitrickle_install_package || { [ -f /tmp/magitrickle_config_backup.yaml ] && cp /tmp/magitrickle_config_backup.yaml "$config" 2>/dev/null || true; return 1; }
        if [ "$MAGITRICKLE_VARIANT" = mod ]; then
            if ! uci -q get magitrickle.main.enabled >/dev/null 2>&1; then
                uci -q set magitrickle.main=main || true
            fi
            uci -q set magitrickle.main.enabled=1 || true
            uci -q set magitrickle.main.user=root || true
            uci -q commit magitrickle || true
        fi
        service magitrickle enable >/dev/null 2>&1 || true
        [ "$MAGITRICKLE_VARIANT" = mod ] && uci -q set magitrickle.main.enabled=1 2>/dev/null || true
        [ "$MAGITRICKLE_VARIANT" = mod ] && uci -q commit magitrickle 2>/dev/null || true
        service magitrickle restart >/dev/null 2>&1 || true
        if ! magitrickle_wait_running; then
            log_warn "$(T "MagiTrickle перезапущен, но процесс не найден" "MagiTrickle was restarted, but its process was not found")"
        fi
        if [ -z "$latest" ]; then
            latest=$(magitrickle_latest_version "$MAGITRICKLE_VARIANT" 2>/dev/null || true)
        fi
        magitrickle_save_variant "$MAGITRICKLE_VARIANT" "$latest"
    fi
    magitrickle_restore_config
    if [ "$MAGITRICKLE_VARIANT" = mod ]; then
        port=$(cat /etc/mixomo/routing/redir-port 2>/dev/null | tr -d ' \r\n')
        if [ -z "$port" ]; then
            port=$(grep -E '^[[:space:]]*redir-port:' /etc/mihomo/config.yaml 2>/dev/null | awk '{print $2}' | head -1 | tr -d ' \r\n')
        fi
        [ -n "$port" ] || return 1
        if [ -f "$config" ]; then
            temp_dir=$(mktemp -d /tmp/mixomo.XXXXXX) || return 1
            sed -i -e '/^[[:space:]]*tproxyPort:[[:space:]]*/d' "$config" || true
            awk -v port="$port" '
                /^[[:space:]]*startMarkTableIndex:[[:space:]]*[0-9]+/ {
                    match($0, /^[[:space:]]*/)
                    indent=substr($0,RSTART,RLENGTH)
                    print
                    print indent "tproxyPort: " port
                    next
                }
                { print }
            ' "$config" > "$temp_dir/config.yaml" && mv "$temp_dir/config.yaml" "$config"
            rm -rf "$temp_dir"
        fi
    fi
    label=$(magitrickle_label "$MAGITRICKLE_VARIANT")
    step_done "$(T "MagiTrickle $label установлен" "MagiTrickle $label installed")"
}
