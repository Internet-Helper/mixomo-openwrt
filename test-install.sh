#!/bin/sh

SCRIPT_VERSION="v0.2.5-alpha"

MIHOMO_INSTALL_DIR="/etc/mihomo"
MIHOMO_BIN="/usr/bin/mihomo"
MIXOMO_DIR="/etc/mixomo"
MIXOMO_REDIR_DIR="$MIXOMO_DIR/routing"
MIXOMO_VERSIONS_DIR="$MIXOMO_DIR/versions"
MIXOMO_REDIR_SCRIPT="$MIXOMO_REDIR_DIR/redir"
MIXOMO_REDIR_PORT_FILE="$MIXOMO_REDIR_DIR/redir-port"
MIXOMO_REDIR_MARK_FILE="$MIXOMO_REDIR_DIR/redir-mark"
MIXOMO_REDIR_DEFAULT_MARK="1298229097"
MIHOMO_VERSION_FILE="$MIXOMO_VERSIONS_DIR/mihomo"
HEV_VERSION_FILE="$MIXOMO_VERSIONS_DIR/hev-socks5-tunnel"
MAGI_VERSION_FILE="$MIXOMO_VERSIONS_DIR/magitrickle"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_online()  { echo -e "${GREEN}[ONLINE]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_done()    { echo -e "${GREEN}$*${NC}"; }
step_fail()   { echo -e "${RED}[FAIL]${NC}"; exit 1; }

kill_stale_pkg() {
    local name="$1"
    for pid in $(ps 2>/dev/null | grep -v grep | grep -E "[ /]${name}([ /]|$)" | awk '{print $1}'); do
        [ "$pid" = "$$" ] && continue
        echo "$(T "Принудительно завершаю зависший процесс: " "Force-killing stale process: ")$(ps -o args= -p "$pid" 2>/dev/null || echo pid=$pid)"
        kill -15 "$pid" 2>/dev/null
        sleep 2
        kill -9 "$pid" 2>/dev/null || true
    done
}

read_user_input() {
    local _v=""
    if read -r _v < /dev/tty 2>/dev/null; then
        eval "$1=\$_v"
        return 0
    fi
    if read -r _v 2>/dev/null; then
        eval "$1=\$_v"
        return 0
    fi
    eval "$1=''"
    return 1
}

ask_menu() {
    local def="${1:-1}" ans
    while :; do
        read_user_input ans
        ans=$(printf '%s' "$ans" | tr -d ' \r\n' | tr 'Q' 'q')
        case "$ans" in
            1) echo "1"; return ;;
            2) echo "2"; return ;;
            q) echo "q"; return ;;
            '') echo "$def"; return ;;
            *) log_warn "$(T "Некорректный ответ: \"$ans\". Введите 1, 2, q или Enter." "Invalid answer: \"$ans\". Enter 1, 2, q or press Enter.")" ;;
        esac
    done
}

LANG_MODE="ru"

T() {
    if [ "$LANG_MODE" = "en" ]; then
        printf '%s' "$2"
    else
        printf '%s' "$1"
    fi
}

choose_language() {
    local choice
    while :; do
        log_done "=== Mixomo OpenWrt $SCRIPT_VERSION ==="
        echo ""
        echo "1) Русский (Enter для продолжения)"
        echo "2) English"
        echo "0) Выход | Exit"
        echo ""
        printf "Ваш выбор | Your choice: "
        read choice
        if [ -z "$choice" ]; then
            choice="1"
        fi
        case "$choice" in
            0) echo ""; exit 0 ;;
            1) LANG_MODE="ru"; break ;;
            2) LANG_MODE="en"; break ;;
            *) echo ""; clear; continue ;;
        esac
    done
}

USE_APK=0
if command -v apk > /dev/null 2>&1; then
    USE_APK=1
fi

manage_pkg() {
    local action="$1"
    shift
    if [ "$USE_APK" -eq 1 ]; then
        case "$action" in
            update)  apk update ;;
            install) apk add "$@" ;;
            remove)  apk del "$@" ;;
        esac
    else
        case "$action" in
            update)  opkg update ;;
            install) opkg install "$@" ;;
            remove)  opkg remove "$@" ;;
        esac
    fi
}

MAGI_VARIANT_MARKER="$MAGI_VERSION_FILE"
MAGI_VARIANT="original"
MAGI_OVERRIDE=""
if [ -n "$1" ] && { [ "$1" = "original" ] || [ "$1" = "mod" ]; }; then
    MAGI_OVERRIDE="$1"
elif [ -n "$MIXOMO_VARIANT" ] && { [ "$MIXOMO_VARIANT" = "original" ] || [ "$MIXOMO_VARIANT" = "mod" ]; }; then
    MAGI_OVERRIDE="$MIXOMO_VARIANT"
fi

read_variant_now() { sed -n '1p' "$MAGI_VERSION_FILE" 2>/dev/null | tr -d ' \r\n'; }
read_version_now() { sed -n '2p' "$MAGI_VERSION_FILE" 2>/dev/null | tr -d ' \r\n'; }

detect_magitrickle_variant() {
    local v
    if [ -f "$MAGI_VERSION_FILE" ]; then
        v=$(read_variant_now)
        case "$v" in original|mod) echo "$v"; return ;; esac
    fi
    if [ -f /etc/magitrickle/state/config.yaml ]; then
        if grep -q 'tproxyPort' /etc/magitrickle/state/config.yaml 2>/dev/null; then
            echo "mod"; return
        fi
    fi
    echo "original"
}

save_magitrickle_variant() {
    local variant="$1" version="$2"
    [ -z "$version" ] && version="$(read_version_now)"
    mkdir -p "$(dirname "$MAGI_VERSION_FILE")" 2>/dev/null || true
    printf '%s\n%s\n' "$variant" "$version" > "$MAGI_VERSION_FILE"
}

magitrickle_latest_version() {
    local variant="$1"
    if [ "$variant" = "mod" ]; then
        curl -s https://api.github.com/repos/badigit/MagiTrickle_mod_badigit/releases/latest 2>/dev/null \
            | grep -m1 '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'
    else
        curl -sL "https://gitlab.com/api/v4/projects/magitrickle%2Fmagitrickle/releases/permalink/latest" 2>/dev/null \
            | grep -o '"tag_name":"[^"]*"' | cut -d'"' -f4
    fi
}

choose_magitrickle_variant() {
    local installed choice
    local inst_label="" opt1="" opt2=""

    if [ -n "$MAGI_OVERRIDE" ]; then
        MAGI_VARIANT="$MAGI_OVERRIDE"
        save_magitrickle_variant "$MAGI_VARIANT"
        log_done "$(T "Выбран вариант MagiTrickle: $MAGI_VARIANT" "Selected MagiTrickle variant: $MAGI_VARIANT")"
        return
    fi
    installed="$(detect_magitrickle_variant)"

    if [ -d "/etc/magitrickle" ] || [ -f "/etc/init.d/magitrickle" ]; then
        if [ "$installed" = "mod" ]; then
            inst_label="$(T "MagiTrickle Mod от badigit" "MagiTrickle Mod by badigit")"
            opt1="$(T "Обновить Mod от badigit (можно нажать Enter для продолжения)" "Update Mod by badigit (press Enter to continue)")"
            opt2="$(T "Установить оригинальную версию MagiTrickle" "Install the original MagiTrickle")"
        else
            inst_label="$(T "оригинальный MagiTrickle" "original MagiTrickle")"
            opt1="$(T "Обновить оригинальный MagiTrickle (можно нажать Enter для продолжения)" "Update the original MagiTrickle (press Enter to continue)")"
            opt2="$(T "Установить MagiTrickle Mod от badigit" "Install MagiTrickle Mod by badigit")"
        fi
    else
        installed=""
        inst_label="$(T "не установлен" "not installed")"
        opt1="$(T "Установить оригинальный MagiTrickle (можно нажать Enter для продолжения)" "Install the original MagiTrickle (press Enter to continue)")"
        opt2="$(T "Установить MagiTrickle Mod от badigit" "Install MagiTrickle Mod by badigit")"
    fi

    while true; do
        clear
        log_done "$(T "Сейчас установлен $inst_label" "Currently installed: $inst_label")"
        echo ""
        echo "1) $opt1"
        echo "2) $opt2"
        echo "$(T "0) Выход" "0) Exit")"
        echo ""
        printf "$(T "Ваш выбор: " "Your choice: ")"
        read choice

        if [ -z "$choice" ]; then
            choice="1"
        fi

        case "$choice" in
            0)
                echo ""
                exit 0
                ;;
            1)
                if [ -n "$installed" ]; then
                    MAGI_VARIANT="$installed"
                else
                    MAGI_VARIANT="original"
                fi
                break
                ;;
            2)
                case "$installed" in
                    mod) MAGI_VARIANT="original";;
                    *)   MAGI_VARIANT="mod";;
                esac
                break
                ;;
            *)
                echo ""
                clear
                continue
                ;;
        esac
    done

    save_magitrickle_variant "$MAGI_VARIANT"
}

tcp_port_free() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -lnt 2>/dev/null | awk '{print $4}' | grep -q ":${port}\$" && return 1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -lnt 2>/dev/null | awk '{print $4}' | grep -q ":${port}\$" && return 1
    fi
    return 0
}

ensure_mihomo_redir_port() {
    local CONFIG_FILE="/etc/mihomo/config.yaml"
    [ -f "$CONFIG_FILE" ] || return 1
    local existing port
    existing=$(grep -E '^[[:space:]]*redir-port:' "$CONFIG_FILE" | awk '{print $2}' | tr -d ' \r\n')
    if [ -n "$existing" ] && [ "$existing" -ge 1 ] 2>/dev/null && [ "$existing" -le 65535 ]; then
        echo "$existing"
        return 0
    fi
    port=5001
    while [ "$port" -le 65535 ]; do
        if tcp_port_free "$port"; then break; fi
        port=$((port + 1))
    done
    if [ "$port" -gt 65535 ]; then
        log_error "$(T "Не удалось найти свободный redir-port для Mihomo" "Could not find a free redir-port for Mihomo")"
        return 1
    fi
    if grep -qE '^[[:space:]]*mixed-port:' "$CONFIG_FILE"; then
        sed -i "/^[[:space:]]*mixed-port:/a redir-port: ${port}" "$CONFIG_FILE"
    elif grep -qE '^[[:space:]]*mode:' "$CONFIG_FILE"; then
        sed -i "/^[[:space:]]*mode:/a redir-port: ${port}" "$CONFIG_FILE"
    else
        sed -i "1i redir-port: ${port}" "$CONFIG_FILE"
    fi
    echo "$port"
}

sync_tproxy_port() {
    local port="$1"
    local CONFIG_PATH="/etc/magitrickle/state/config.yaml"
    [ -n "$port" ] || return 0
    [ -f "$CONFIG_PATH" ] || return 0
    local TMP_T
    TMP_T=$(mktemp) || return 1
    awk -v port="$port" '
        /^[[:space:]]*tproxyPort:[[:space:]]/ { next }
        /^[[:space:]]*startMarkTableIndex:[[:space:]]*[0-9]+/ {
            match($0, /^[[:space:]]*/)
            indent = substr($0, RSTART, RLENGTH)
            print
            print indent "tproxyPort: " port
            next
        }
        { print }
    ' "$CONFIG_PATH" > "$TMP_T" && mv "$TMP_T" "$CONFIG_PATH"
    return 0
}

detect_mihomo_arch() {
    local arch
    arch=$(uname -m)
    local endian_byte
    endian_byte=$(hexdump -s 5 -n 1 -e '1/1 "%d"' /bin/busybox 2>/dev/null || echo "0")

    case "$arch" in
        x86_64)
            if grep -q "avx2" /proc/cpuinfo; then
                echo "amd64"
            else
                echo "amd64-compatible"
            fi
            ;;
        i?86)          echo "386" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7*)        echo "armv7" ;;
        armv5*|armv4*) echo "armv5" ;;
        mips*)
            local fpu
            fpu=$(grep -c "FPU" /proc/cpuinfo 2>/dev/null || echo 0)
            local floattype="softfloat"
            [ "$fpu" -gt 0 ] && floattype="hardfloat"
            if [ "$endian_byte" = "1" ]; then
                echo "mipsle-${floattype}"
            else
                echo "mips-${floattype}"
            fi
            ;;
        riscv64) echo "riscv64" ;;
        *)
            log_error "$(T "Архитектура $arch не распознана" "Architecture $arch is not recognized")"
            exit 1
            ;;
    esac
}

verify_required_deps() {
    local missing=0

    if ! command -v curl >/dev/null 2>&1; then
        log_error "$(T "Пакет curl не найден!" "Package curl not found!")"
        missing=1
    fi

    if [ ! -f /etc/ssl/certs/ca-certificates.crt ] && [ ! -f /etc/ssl/certs/ca-bundle.crt ]; then
        log_error "$(T "Пакет ca-certificates не найден!" "Package ca-certificates not found!")"
        missing=1
    fi

    if [ ! -c /dev/net/tun ]; then
        modprobe tun >/dev/null 2>&1 || true
        if [ ! -c /dev/net/tun ]; then
            log_error "$(T "В ядре нет поддержки TUN (/dev/net/tun)!" "Kernel has no TUN support (/dev/net/tun)!")"
            missing=1
        fi
    fi

    if [ "$missing" -eq 1 ]; then
        return 1
    fi

    return 0
}

install_deps() {
    log_online "$(T "Установка зависимостей" "Installing dependencies")"

    local PKG_LOG="/tmp/install_deps.log"

    if [ "$USE_APK" -eq 1 ]; then
        apk update > "$PKG_LOG" 2>&1 || true
        local AVAIL_PKG
        AVAIL_PKG=$(grep -o '[0-9]* distinct packages available' "$PKG_LOG" | grep -o '^[0-9]*')
        if [ -z "$AVAIL_PKG" ] || [ "$AVAIL_PKG" -eq 0 ]; then
            if grep -q "Resource temporarily unavailable" "$PKG_LOG"; then
                log_warn "$(T "apk заблокирован. Автоматически завершаю зависший процесс apk и повторяю..." "apk is locked. Automatically killing the stale apk process and retrying...")"
                kill_stale_pkg apk
                sleep 2
                apk update > "$PKG_LOG" 2>&1 || true
                AVAIL_PKG=$(grep -o '[0-9]* distinct packages available' "$PKG_LOG" | grep -o '^[0-9]*')
            else
                log_warn "$(T "apk update не вернул доступных пакетов, повторная попытка..." "apk update returned no available packages, retrying...")"
                sleep 3
                apk update > "$PKG_LOG" 2>&1 || true
                AVAIL_PKG=$(grep -o '[0-9]* distinct packages available' "$PKG_LOG" | grep -o '^[0-9]*')
            fi
            if [ -z "$AVAIL_PKG" ] || [ "$AVAIL_PKG" -eq 0 ]; then
                log_error "$(T "apk update завершился без доступных пакетов:" "apk update finished with no available packages:")"
                cat "$PKG_LOG"
                rm -f "$PKG_LOG"
                return 1
            fi
        fi
        
        apk add ca-certificates kmod-tun kmod-nft-tproxy kmod-nft-nat curl >> "$PKG_LOG" 2>&1 || true
        apk add kmod-nft-socket iptables-mod-tproxy iptables-mod-socket >> "$PKG_LOG" 2>&1 || true
    else
        if ! opkg update > "$PKG_LOG" 2>&1; then
            if grep -qiE "Resource temporarily unavailable|lock" "$PKG_LOG"; then
                log_warn "$(T "opkg заблокирован. Автоматически завершаю зависший процесс opkg и повторяю..." "opkg is locked. Automatically killing the stale opkg process and retrying...")"
                kill_stale_pkg opkg
                sleep 2
                if ! opkg update > "$PKG_LOG" 2>&1; then
                    log_error "$(T "Ошибка обновления списков пакетов (opkg update):" "Error updating package lists (opkg update):")"
                    cat "$PKG_LOG"
                    rm -f "$PKG_LOG"
                    return 1
                fi
            else
                log_error "$(T "Ошибка обновления списков пакетов (opkg update):" "Error updating package lists (opkg update):")"
                cat "$PKG_LOG"
                rm -f "$PKG_LOG"
                return 1
            fi
        fi
        
        opkg install ca-certificates kmod-tun kmod-nft-tproxy kmod-nft-nat curl libcurl4 ca-bundle >> "$PKG_LOG" 2>&1 || true
        opkg install kmod-nft-socket kmod-ipt-tproxy kmod-ipt-socket >> "$PKG_LOG" 2>&1 || true
    fi

    rm -f "$PKG_LOG"

    if ! verify_required_deps; then
        log_error "$(T "Не удалось подтвердить наличие обязательных компонентов!" "Could not confirm the presence of required components!")"
        return 1
    fi
}

install_mihomo() {
    local REQ_TMP_KB=16000
    local REQ_ROOT_KB=18000

    local AVAIL_TMP_KB
    AVAIL_TMP_KB=$(df -k /tmp | awk 'NR==2 {print $4}')
    if [ "$AVAIL_TMP_KB" -lt "$REQ_TMP_KB" ]; then
        log_error "$(T "Недостаточно места в /tmp: доступно $((AVAIL_TMP_KB/1024)) MB, требуется $((REQ_TMP_KB/1024)) MB" "Not enough space in /tmp: $((AVAIL_TMP_KB/1024)) MB available, $((REQ_TMP_KB/1024)) MB required")"
        return 1
    fi

    local INSTALL_DIR_PATH
    INSTALL_DIR_PATH=$(dirname "$MIHOMO_BIN")
    local AVAIL_ROOT_KB
    AVAIL_ROOT_KB=$(df -k "$INSTALL_DIR_PATH" | awk 'NR==2 {print $4}')

    if [ "$AVAIL_ROOT_KB" -lt "$REQ_ROOT_KB" ]; then
        log_error "$(T "Недостаточно места на диске: доступно $((AVAIL_ROOT_KB/1024)) MB, требуется $((REQ_ROOT_KB/1024)) MB" "Not enough disk space: $((AVAIL_ROOT_KB/1024)) MB available, $((REQ_ROOT_KB/1024)) MB required")"
        if [ -f "$MIHOMO_BIN" ]; then
            log_warn "$(T "Найдена установленная версия: $MIHOMO_BIN" "Found an installed version: $MIHOMO_BIN")"
            printf "$(T "Удалить старую версию для освобождения места? [y/+/д или n/-/н]: " "Delete the old version to free up space? [y/+ or n/-]: ")"
            read_user_input response
            case "$response" in
                [yY+дД]*)
                    rm -f "$MIHOMO_BIN"
                    AVAIL_ROOT_KB=$(df -k "$INSTALL_DIR_PATH" | awk 'NR==2 {print $4}')
                    if [ "$AVAIL_ROOT_KB" -lt "$REQ_ROOT_KB" ]; then
                        log_error "$(T "Места всё равно недостаточно после удаления." "Still not enough space after deletion.")"
                        return 1
                    fi
                    ;;
                *)
                    log_warn "$(T "Установка отменена." "Installation cancelled.")"
                    return 1
                    ;;
            esac
        else
            log_warn "$(T "Старая версия не найдена. Удалите лишние пакеты вручную." "No old version found. Remove unneeded packages manually.")"
            return 1
        fi
    fi

    local MIHOMO_WAS_RUNNING=0
    if [ -x "/etc/init.d/mihomo" ] && /etc/init.d/mihomo running >/dev/null 2>&1; then
        MIHOMO_WAS_RUNNING=1
    fi

    if [ -z "${MIHOMO_ARCH+x}" ]; then
        MIHOMO_ARCH=$(detect_mihomo_arch)
    fi
    echo "$(T "Архитектура системы: $(uname -m) -> выбран файл: $MIHOMO_ARCH" "System architecture: $(uname -m) -> selected file: $MIHOMO_ARCH")"

    mkdir -p "$MIHOMO_INSTALL_DIR" \
             /etc/mihomo/proxy-providers \
             /etc/mihomo/rule-providers \
             /etc/mihomo/rule-files \
             /etc/mihomo/UI/zashboard \
			 /etc/mihomo/UI/metacubex

    echo "$MIHOMO_ARCH" > /etc/mihomo/.arch

    echo "$(T "Получение номера последней версии" "Fetching the latest version number")"
    local RELEASE_TAG
    RELEASE_TAG=$(curl -Ls -o /dev/null -w '%{url_effective}' https://github.com/MetaCubeX/mihomo/releases/latest | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -z "$RELEASE_TAG" ]; then
        log_error "$(T "Не удалось определить версию. Проверьте доступ к GitHub." "Could not determine the version. Check GitHub access.")"
        return 1
    fi
    echo "$(T "Последняя версия: $RELEASE_TAG" "Latest version: $RELEASE_TAG")"

    local NEED_UPDATE=1 NOW_VER=""
    if [ -f "$MIHOMO_VERSION_FILE" ]; then
        NOW_VER=$(tr -d ' \r\n' < "$MIHOMO_VERSION_FILE" 2>/dev/null)
    fi
    if [ -x "$MIHOMO_BIN" ] && [ -n "$NOW_VER" ] && [ "$NOW_VER" = "$RELEASE_TAG" ] && "$MIHOMO_BIN" -v >/dev/null 2>&1; then
        NEED_UPDATE=0
        log_online "$(T "Актуальный Mihomo $RELEASE_TAG уже установлен" "Mihomo $RELEASE_TAG is already up to date")"
        mkdir -p "$MIXOMO_VERSIONS_DIR"
        echo "$RELEASE_TAG" > "$MIHOMO_VERSION_FILE"
    fi

    if [ "$NEED_UPDATE" -eq 1 ]; then
    local FILENAME="mihomo-linux-${MIHOMO_ARCH}-${RELEASE_TAG}.gz"
    local DOWNLOAD_URL="https://github.com/MetaCubeX/mihomo/releases/download/${RELEASE_TAG}/${FILENAME}"
    local TMP_FILE="/tmp/mihomo.gz"
    local NEW_BIN="/tmp/mihomo.new"
    local BACKUP_BIN="/tmp/mihomo.previous"

    log_online "$(T "Скачивание архива " "Downloading archive ")$FILENAME"
    log_online "$DOWNLOAD_URL"
    if ! curl -Lf --retry 3 --retry-delay 2 "$DOWNLOAD_URL" -o "$TMP_FILE" >/dev/null 2>&1; then
        log_error "$(T "Ошибка скачивания! Проверьте, существует ли файл $FILENAME в релизах." "Download error! Check that $FILENAME exists in the releases.")"
        return 1
    fi

    echo "$(T "Распаковка архива во временный файл" "Extracting archive to a temporary file")"
    rm -f "$NEW_BIN"
    if ! gunzip -c "$TMP_FILE" > "$NEW_BIN" 2>/dev/null || [ ! -s "$NEW_BIN" ]; then
        log_error "$(T "Ошибка распаковки архива" "Archive extraction error")"
        rm -f "$TMP_FILE" "$NEW_BIN"
        return 1
    fi
    chmod +x "$NEW_BIN"
    rm -f "$TMP_FILE"

    echo "$(T "Проверка ядра Mihomo" "Checking the Mihomo core")"
    if ! "$NEW_BIN" -v >/dev/null 2>&1; then
        log_error "$(T "Ядро не запускается! Возможно, выбрана неверная архитектура." "The core does not run! Possibly an incorrect architecture was selected.")"
        rm -f "$NEW_BIN"
        return 1
    fi

    if [ "$MIHOMO_WAS_RUNNING" -eq 1 ]; then
        echo "$(T "Остановка текущего Mihomo для замены ядра" "Stopping the current Mihomo to replace the core")"
        /etc/init.d/mihomo stop || {
            log_error "$(T "Не удалось остановить текущий Mihomo" "Could not stop the current Mihomo")"
            rm -f "$NEW_BIN"
            return 1
        }
    fi

    rm -f "$BACKUP_BIN"
    if [ -f "$MIHOMO_BIN" ] && ! cp "$MIHOMO_BIN" "$BACKUP_BIN"; then
        log_error "$(T "Не удалось создать резервную копию текущего ядра" "Could not back up the current core")"
        [ "$MIHOMO_WAS_RUNNING" -eq 1 ] && /etc/init.d/mihomo start 2>/dev/null || true
        rm -f "$NEW_BIN"
        return 1
    fi
    if ! mv -f "$NEW_BIN" "$MIHOMO_BIN" || ! chmod +x "$MIHOMO_BIN"; then
        log_error "$(T "Не удалось установить новое ядро" "Could not install the new core")"
        [ -f "$BACKUP_BIN" ] && cp "$BACKUP_BIN" "$MIHOMO_BIN"
        [ "$MIHOMO_WAS_RUNNING" -eq 1 ] && /etc/init.d/mihomo start 2>/dev/null || true
        rm -f "$NEW_BIN" "$BACKUP_BIN"
        return 1
    fi
    rm -f "$BACKUP_BIN"
    mkdir -p "$MIXOMO_VERSIONS_DIR"
    echo "$RELEASE_TAG" > "$MIHOMO_VERSION_FILE"
    fi

    local CONFIG_FILE="/etc/mihomo/config.yaml"
    local WRITE_NEW_CONFIG=1

    if [ -f "$CONFIG_FILE" ]; then
        if grep -q "mixed-port: 7890" "$CONFIG_FILE"; then
            echo "$(T "Использование существующей конфигурации" "Using the existing configuration")"
            WRITE_NEW_CONFIG=0
        else
            log_warn "$(T "Конфигурация найдена, но без 'mixed-port: 7890'. Создание резервной копии" "Configuration found but without 'mixed-port: 7890'. Creating a backup")"
            cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
        fi
    fi

    if [ "$WRITE_NEW_CONFIG" -eq 1 ]; then
        echo "$(T "Создание конфигурации /etc/mihomo/config.yaml..." "Creating /etc/mihomo/config.yaml...")"
        cat > "$CONFIG_FILE" <<'EOF'
mode: rule
ipv6: false
mixed-port: 7890
log-level: error
allow-lan: true
unified-delay: true
tcp-concurrent: false
find-process-mode: off
external-controller: 0.0.0.0:9090
# Zashboard
#external-ui: ./UI/zashboard/
#external-ui-url: "https://github.com/Zephyruso/zashboard/releases/latest/download/dist-cdn-fonts.zip"
# MetaCubeX
#external-ui: ./UI/metacubex/
#external-ui-url: "https://github.com/MetaCubeX/metacubexd/releases/latest/download/compressed-dist.tgz"
routing-mark: 2
profile:
  store-selected: true
  store-fake-ip: true
  tracing: true
sniffer:
  enable: true
  force-dns-mapping: true
  parse-pure-ip: true
  sniff:
    HTTP:
      ports: [80]
      override-destination: true
    TLS:
      ports: [443, 8443]
    QUIC:
      ports: [443, 8443]
  skip-domain:
    - Mijia Cloud
    - +.lan
    - +.local
    - +.msftconnecttest.com
    - +.msftncsi.com
    - +.3gppnetwork.org
    - +.openwrt.org
    - +.vsean.net
    - cudy.net

dns:

  enable: true
  listen: 0.0.0.0:7880
  ipv6: false
  nameserver:
    - https://8.8.8.8/dns-query
    - https://8.8.4.4/dns-query
    - https://1.1.1.1/dns-query
    - https://1.0.0.1/dns-query
    - https://9.9.9.9/dns-query
    - https://149.112.112.112/dns-query
    - https://94.140.14.140/dns-query
    - https://94.140.14.141/dns-query
    - https://77.88.8.8/dns-query
    - https://77.88.8.1/dns-query

proxies:

  - name: Домашний интернет
    type: direct

proxy-groups:

rule-providers:

rules:

  - MATCH,Домашний интернет
EOF
    fi

    ensure_mihomo_redir_port >/dev/null || log_warn "$(T "Не удалось настроить redir-port Mihomo (необходим для мода от badigit)" "Could not configure the Mihomo redir-port (required for the badigit mod)")"

    echo "$(T "Создание службы /etc/init.d/mihomo" "Creating the /etc/init.d/mihomo service")"
    cat > /etc/init.d/mihomo <<'EOF'
#!/bin/sh /etc/rc.common
START=99
USE_PROCD=1

MIHOMO_BIN="/usr/bin/mihomo"
MIHOMO_DIR="/etc/mihomo"
MIHOMO_CONF="/etc/mihomo/config.yaml"

start_service() {
    [ -x "$MIHOMO_BIN" ] || return 1
    [ -s "$MIHOMO_CONF" ] || return 1

    procd_open_instance "main"
    procd_set_param command "$MIHOMO_BIN" -d "$MIHOMO_DIR" -f "$MIHOMO_CONF"
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn
    procd_close_instance
}

service_triggers() {
    procd_add_reload_trigger "mihomo"
}
EOF
    chmod +x /etc/init.d/mihomo
    /etc/init.d/mihomo enable || log_warn "$(T "Не удалось включить автозапуск Mihomo" "Could not enable Mihomo autostart")"
    if [ "$MIHOMO_WAS_RUNNING" -eq 1 ]; then
        echo "$(T "Запуск Mihomo" "Starting Mihomo")"
        /etc/init.d/mihomo start || log_warn "$(T "Не удалось запустить Mihomo. Повторная попытка будет в конце установки" "Could not start Mihomo. It will be retried at the end of installation")"
    fi

    echo "$(T "Настройка страницы LuCI для управления Mihomo" "Setting up the LuCI page to manage Mihomo")"
    mkdir -p /usr/share/luci/menu.d
    cat > /usr/share/luci/menu.d/luci-app-mihomo.json <<'EOF'
{
    "admin/services/mihomo": {
        "title": "Mihomo",
        "order": 60,
        "action": { "type": "view", "path": "mihomo/config" },
        "depends": { "acl": [ "luci-app-mihomo" ] }
    }
}
EOF

    mkdir -p /usr/share/rpcd/acl.d
    cat > /usr/share/rpcd/acl.d/luci-app-mihomo.json <<'EOF'
{
    "luci-app-mihomo": {
        "description": "Mihomo control",
        "read": {
            "file": {
                "/etc/mihomo/config.yaml": ["read"],
                "/etc/mihomo/rule-files/": ["list"],
                "/etc/mihomo/rule-files/*": ["read"]
            },
            "ubus": {
                "file": ["read", "list"],
                "service": ["list"],
                "mihomo-routing": ["status", "clients"],
                "mihomo-dns": ["status"]
            }
        },
        "write": {
            "file": {
                "/etc/mihomo/config.yaml": ["write"],
                "/etc/mihomo/rule-files/*": ["write"],
                "/usr/bin/mihomo": ["exec"],
                "/etc/init.d/mihomo": ["exec"],
                "/sbin/logread": ["exec"],
                "/bin/sh": ["exec"],
                "/bin/ash": ["exec"],
                "/usr/bin/curl": ["exec"],
                "/usr/bin/wget": ["exec"],
                "/bin/gzip": ["exec"],
                "/bin/chmod": ["exec"],
                "/bin/mv": ["exec"],
                "/bin/rm": ["exec"]
            },
            "ubus": {
                "file": ["write"],
                "service": ["list"],
                "mihomo-routing": ["add", "update", "delete", "set_enabled", "set_router", "set_udp443", "exclude_add", "exclude_delete", "exclude_update", "exclude_set_enabled", "reorder", "reload"],
                "mihomo-dns": ["apply", "clear", "add_preset", "remove_preset"]
            }
        }
    }
}
EOF

    mkdir -p /usr/libexec/rpcd
    cat > /usr/libexec/rpcd/mihomo-routing <<'EOF'
#!/bin/sh
. /usr/share/libubox/jshn.sh

PREFIX="mihomo_route_"
TABLE_SECTION="mihomo_routing_table"
ROUTER_MARK="0x233"
ROUTER_NFT="/etc/mihomo/mihomo-router-routing.nft"
ROUTER_FW_SECTION="mihomo_router_routing"

fail() { json_init; json_add_boolean ok 0; json_add_string error "$1"; json_dump; exit 0; }

valid_ipv4_cidr() {
    value="$1"
    ip="${value%/*}"
    mask="${value#*/}"
    [ "$ip" != "$value" ] || mask=32
    case "$mask" in ''|*[!0-9]*) return 1;; esac
    [ "$mask" -ge 1 ] 2>/dev/null && [ "$mask" -le 32 ] 2>/dev/null || return 1
    oldifs="$IFS"; IFS=.; set -- $ip; IFS="$oldifs"
    [ "$#" -eq 4 ] || return 1
    for octet in "$@"; do
        case "$octet" in ''|*[!0-9]*) return 1;; esac
        [ "$octet" -le 255 ] 2>/dev/null || return 1
    done
    return 0
}

normalize_ipv4_cidr() {
    value="$1"
    case "$value" in */*) printf '%s\n' "$value"; return;; esac
    oldifs="$IFS"; IFS=.; set -- $value; IFS="$oldifs"
    [ "$#" -eq 4 ] || return 1
    if [ "$4" = 0 ] && [ "$3" = 0 ] && [ "$2" = 0 ]; then mask=8
    elif [ "$4" = 0 ] && [ "$3" = 0 ]; then mask=16
    elif [ "$4" = 0 ]; then mask=24
    else mask=32
    fi
    printf '%s/%s\n' "$value" "$mask"
}

find_table() {
    existing="$(uci -q get network.$TABLE_SECTION.table)"
    if [ -n "$existing" ] && [ "$existing" -ge 1 ] 2>/dev/null; then
        echo "$existing"; return
    fi
    table=100
    while [ "$table" -lt 1000 ]; do
        if ! ip route show table "$table" 2>/dev/null | grep -q . && \
           ! ip rule list 2>/dev/null | grep -Eq "[[:space:]]lookup[[:space:]]+$table([[:space:]]|$)"; then
            echo "$table"; return
        fi
        table=$((table + 1))
    done
    return 1
}

ensure_base() {
    table="$(find_table)" || return 1
    uci -q set "network.$TABLE_SECTION=route"
    uci -q set "network.$TABLE_SECTION.interface=Mihomo"
    uci -q set "network.$TABLE_SECTION.target=0.0.0.0/0"
    uci -q set "network.$TABLE_SECTION.table=$table"

    for section in $(uci show network 2>/dev/null | sed -n "s/^network\\.\\(${PREFIX}local_[^.=]*\\)=rule$/\\1/p"); do uci -q delete "network.$section"; done
    number=0
    ip -4 route show table main proto kernel scope link 2>/dev/null | while read -r subnet rest; do
        case "$subnet" in */*) ;;
            *) continue;; esac
        case "$rest" in *"dev Mihomo"*) continue;; esac
        uci -q set "network.${PREFIX}local_$number=rule"
        uci -q set "network.${PREFIX}local_$number.name=Mixomo-local-$number"
        uci -q set "network.${PREFIX}local_$number.priority=$((10000 + number))"
        uci -q set "network.${PREFIX}local_$number.dest=$subnet"
        uci -q set "network.${PREFIX}local_$number.lookup=main"
        number=$((number + 1))
    done
    echo "$table"
}

apply_network() {
    table="$1"
    uci commit network
    /etc/init.d/network reload
    sleep 1
    if ! ip route show table "$table" 2>/dev/null | grep -Eq '^default[[:space:]].*dev[[:space:]]Mihomo([[:space:]]|$)'; then
        ip route replace default dev Mihomo table "$table" 2>/dev/null || return 1
    fi
    ip route show table "$table" 2>/dev/null | grep -Eq '^default[[:space:]].*dev[[:space:]]Mihomo([[:space:]]|$)'
}

ensure_router_policy() {
    table="$1"
    if ! ip rule list 2>/dev/null | grep -Eq "^[[:space:]]*19000:.*fwmark $ROUTER_MARK.*lookup $table([[:space:]]|$)"; then
        ip rule add priority 19000 fwmark "$ROUTER_MARK" lookup "$table" 2>/dev/null || return 1
    fi
}

list_client_sections() {
    for type in rule mihomo_rule; do
        uci show network 2>/dev/null | sed -n "s/^network\\.\\(${PREFIX}client_[^.=]*\\)=$type$/\\1/p"
    done
}

list_tun_sections() {
    uci show network 2>/dev/null | sed -n "s/^network\\.\\(${PREFIX}client_[^.=]*\\)=rule$/\\1/p"
}

list_redir_sections() {
    uci show network 2>/dev/null | sed -n "s/^network\\.\\(${PREFIX}client_[^.=]*\\)=mihomo_rule$/\\1/p"
}

get_backend_default() {
    if grep -E '^[[:space:]]*redir-port:' /etc/mihomo/config.yaml >/dev/null 2>&1; then
        echo "redir-tproxy"
    else
        echo "tun-socks5"
    fi
}

prefix_len() {
    case "$1" in */*) echo "${1#*/}";; *) echo 32;; esac
}

next_priority() {
    cidr="$1"; skip="$2"
    base=$((20000 + (32 - $(prefix_len "$cidr")) * 100))
    seq=0
    while :; do
        p=$((base + seq))
        used=""
        for s in $(list_client_sections); do
            key="${s#${PREFIX}client_}"
            [ "$key" = "$skip" ] && continue
            [ "$(uci -q get network.$s.priority)" = "$p" ] && { used=1; break; }
        done
        [ -z "$used" ] && { echo "$p"; return; }
        seq=$((seq + 1))
    done
}

src_exists() {
    cidr="$1"; skip="$2"
    for s in $(list_client_sections); do
        key="${s#${PREFIX}client_}"
        [ "$key" = "$skip" ] && continue
        [ "$(uci -q get network.$s.src)" = "$cidr" ] && return 0
    done
    return 1
}

excl_exists() {
    cidr="$1"; skip="$2"
    for s in $(list_excl_sections); do
        key="${s#${PREFIX}excl_}"
        [ "$key" = "$skip" ] && continue
        [ "$(uci -q get network.$s.dest)" = "$cidr" ] && return 0
    done
    return 1
}

list_excl_sections() {
    uci show network 2>/dev/null | sed -n "s/^network\\.\\(${PREFIX}excl_[^.=]*\\)=mihomo_excl$/\\1/p"
}

rebuild_mixomo_redir() {
    [ -x /etc/mixomo/routing/redir ] && /etc/mixomo/routing/redir 2>/dev/null
    return 0
}

network_sync() {
    uci commit network
    /etc/init.d/network reload
    sleep 1
    table="$(uci -q get network.$TABLE_SECTION.table)"
    if [ -n "$table" ]; then
        if ! ip route show table "$table" 2>/dev/null | grep -Eq '^default[[:space:]].*dev[[:space:]]Mihomo([[:space:]]|$)'; then
            ip route replace default dev Mihomo table "$table" 2>/dev/null || true
        fi
    fi
    rebuild_mixomo_redir
}

local_ipv4_nft_set() {
    local_nets="127.0.0.0/8, 192.168.0.0/16, 10.0.0.0/8, 172.16.0.0/12, 100.64.0.0/10, 169.254.0.0/16"
    
    ip -4 route show table main proto kernel scope link 2>/dev/null > /tmp/mihomo-local-routes
    while read -r subnet rest; do
        case "$subnet" in */*) local_nets="$local_nets, $subnet";; esac
    done < /tmp/mihomo-local-routes
    
    for sec in $(uci show network 2>/dev/null | sed -n "s/^network\.\(mihomo_route_excl_[^.=]*\)=mihomo_excl$/\1/p"); do
        [ "$(uci -q get network.$sec.disabled)" = "1" ] && continue
        d="$(uci -q get network.$sec.dest)"
        [ -n "$d" ] && local_nets="$local_nets, $d"
    done
    
    printf '%s\n' "$local_nets"
}

enable_router_mark() {
    local_nets="$(local_ipv4_nft_set)"
    cat > "$ROUTER_NFT" <<NFT
chain mihomo_router_routing {
    type route hook output priority mangle; policy accept;
    ip daddr { $local_nets } return
    ip daddr 224.0.0.0/4 return
    ip daddr 255.255.255.255 return
    meta nfproto ipv4 meta mark 0 meta mark set $ROUTER_MARK
}
NFT
    uci -q set "firewall.$ROUTER_FW_SECTION=include"
    uci -q set "firewall.$ROUTER_FW_SECTION.type=nftables"
    uci -q set "firewall.$ROUTER_FW_SECTION.path=$ROUTER_NFT"
    uci -q set "firewall.$ROUTER_FW_SECTION.enabled=1"
    uci commit firewall
    /etc/init.d/firewall reload
    if ! nft list chain inet fw4 mihomo_router_routing >/dev/null 2>&1; then
        nft add chain inet fw4 mihomo_router_routing '{ type route hook output priority mangle; policy accept; }' 2>/dev/null || return 1
        nft add rule inet fw4 mihomo_router_routing ip daddr "{ $local_nets }" return 2>/dev/null || return 1
        nft add rule inet fw4 mihomo_router_routing ip daddr 224.0.0.0/4 return 2>/dev/null || return 1
        nft add rule inet fw4 mihomo_router_routing ip daddr 255.255.255.255 return 2>/dev/null || return 1
        nft add rule inet fw4 mihomo_router_routing meta nfproto ipv4 meta mark 0 meta mark set "$ROUTER_MARK" 2>/dev/null || return 1
    fi
}

disable_router_mark() {
    nft delete chain inet fw4 mihomo_router_routing 2>/dev/null || true
    nft delete table inet mihomo_router_routing 2>/dev/null || true
    uci -q delete "firewall.$ROUTER_FW_SECTION"
    rm -f "$ROUTER_NFT"
    uci commit firewall
    /etc/init.d/firewall reload
}

cleanup_if_unused() {
    [ -n "$(list_client_sections)" ] && return 0
    uci -q get "network.${PREFIX}router" >/dev/null && return 0
    table="$(uci -q get network.$TABLE_SECTION.table)"
    for section in $(uci show network 2>/dev/null | sed -n "s/^network\\.\\(${PREFIX}local_[^.=]*\\)=rule$/\\1/p"); do uci -q delete "network.$section"; done
    uci -q delete "network.$TABLE_SECTION"
    uci commit network
    /etc/init.d/network reload
    [ -n "$table" ] && ip route flush table "$table" 2>/dev/null || true
    disable_router_mark
}

emit_status() {
    table="$(uci -q get network.$TABLE_SECTION.table)"
    router=0
    [ "$(uci -q get network.${PREFIX}router.mark)" = "$ROUTER_MARK" ] && router=1
    variant="$(get_backend_default)"
    redir_available=0
    [ "$variant" = "redir-tproxy" ] && redir_available=1
    udp443=0
    [ "$(uci -q get firewall.Block_443_UDP)" = "rule" ] && [ "$(uci -q get firewall.Block_443_UDP.disabled)" != "1" ] && udp443=1
    json_init; json_add_boolean ok 1; json_add_int table "${table:-0}"; json_add_boolean router "$router"
    json_add_string variant "$variant"; json_add_boolean redirAvailable "$redir_available"; json_add_boolean udp443 "$udp443"
    json_add_array rules
    for section in $(list_client_sections); do
        json_add_object
        json_add_string id "${section#${PREFIX}client_}"
        json_add_string source "$(uci -q get network.$section.src)"
        json_add_string label "$(uci -q get network.$section.name)"
        json_add_string backend "$(uci -q get network.$section.backend)"
        prio_val="$(uci -q get network.$section.priority)"; [ -n "$prio_val" ] || prio_val=0
        json_add_int priority "$prio_val"
        json_add_boolean enabled "$( [ "$(uci -q get network.$section.disabled)" != 1 ] && echo 1 || echo 0 )"
        json_close_object
    done
    json_close_array
    json_add_array exclusions
    for section in $(list_excl_sections); do
        json_add_object
        json_add_string id "${section#${PREFIX}excl_}"
        json_add_string dest "$(uci -q get network.$section.dest)"
        json_add_string label "$(uci -q get network.$section.name)"
        excl_prio="$(uci -q get network.$section.priority)"; [ -n "$excl_prio" ] || excl_prio=0
        json_add_int priority "$excl_prio"
        json_add_boolean enabled "$( [ "$(uci -q get network.$section.disabled)" != 1 ] && echo 1 || echo 0 )"
        json_close_object
    done
    json_close_array; json_dump
}

finalize_changes() {
    if [ -x /etc/init.d/magitrickle ] && /etc/init.d/magitrickle running >/dev/null 2>&1; then
        (/etc/init.d/magitrickle restart >/dev/null 2>&1) &
    fi
    emit_status
}

emit_clients() {
    json_init; json_add_boolean ok 1; json_add_array clients
    router_ips=" $(ip -4 addr show 2>/dev/null | awk '/inet / {sub(/\/.*/, "", $2); printf "%s ", $2}')"
    gateway_ips=" $(ip -4 route show 2>/dev/null | awk '/ via / {for (i = 1; i <= NF; i++) if ($i == "via") printf "%s ", $(i + 1)}')"
    seen_ips=" "
    is_visible_client() {
        case "$router_ips" in *" $1 "*) return 1;; esac
        case "$gateway_ips" in *" $1 "*) return 1;; esac
        case "$seen_ips" in *" $1 "*) return 1;; esac
        seen_ips="$seen_ips$1 "
        return 0
    }
    if [ -r /tmp/dhcp.leases ]; then
        while read -r expiry mac ip name clientid; do
            valid_ipv4_cidr "$ip" || continue
            is_visible_client "$ip" || continue
            json_add_object; json_add_string ip "$ip"; json_add_string mac "$mac"; json_add_string name "${name:-}"; json_close_object
        done < /tmp/dhcp.leases
    fi
    ip -4 neigh show 2>/dev/null > /tmp/mihomo-neigh
    while read -r ip dev _ mac _ state; do
        valid_ipv4_cidr "$ip" || continue
        [ "$state" = FAILED ] && continue
        is_visible_client "$ip" || continue
        json_add_object; json_add_string ip "$ip"; json_add_string mac "${mac:-}"; json_add_string name ""; json_close_object
    done < /tmp/mihomo-neigh
    json_close_array; json_dump
}

case "$1" in
list) echo '{"status":{},"clients":{},"add":{"source":"String","label":"String","backend":"String"},"update":{"id":"String","source":"String","label":"String","backend":"String"},"delete":{"id":"String"},"set_enabled":{"id":"String","enabled":true},"set_router":{"enabled":true},"set_udp443":{"enabled":true},"exclude_add":{"dest":"String","label":"String"},"exclude_delete":{"id":"String"},"exclude_update":{"id":"String","dest":"String","label":"String"},"exclude_set_enabled":{"id":"String","enabled":true},"reorder":{"type":"String","order":"String"}}' ;;
call)
    json_load "$(cat)"
    case "$2" in
    status) emit_status ;;
    clients) emit_clients ;;
    exclude_add)
        json_get_var dest dest; json_get_var label label
        valid_ipv4_cidr "$dest" || fail "Введите корректный IPv4-адрес или CIDR"
        dest="$(normalize_ipv4_cidr "$dest")" || fail "Не удалось определить маску подсети"
        [ "${#label}" -le 64 ] || fail "Название не длиннее 64 символов"
        printf '%s' "$label" | grep -q '[[:cntrl:]]' && fail "Недопустимое название"
        excl_exists "$dest" "" && fail "Такая подсеть уже в списке исключений"
        id="$(date +%s)_$$"
        uci -q set "network.${PREFIX}excl_$id=mihomo_excl"
        uci -q set "network.${PREFIX}excl_$id.dest=$dest"
        uci -q set "network.${PREFIX}excl_$id.name=${label:-$dest}"
        uci -q set "network.${PREFIX}excl_$id.priority=$((1000 + $(list_excl_sections | wc -l)))"
        uci -q delete "network.${PREFIX}excl_$id.disabled"
        uci -q delete "network.${PREFIX}excl_$id.enabled"
        uci commit network
        rebuild_mixomo_redir
        finalize_changes ;;
    exclude_delete)
        json_get_var id id
        printf '%s' "$id" | grep -Eq '^[0-9_]+$' || fail "Некорректный идентификатор исключения"
        uci -q get "network.${PREFIX}excl_$id" >/dev/null || fail "Исключение не найдено"
        uci -q delete "network.${PREFIX}excl_$id"
        uci commit network
        rebuild_mixomo_redir
        finalize_changes ;;
    exclude_update)
        json_get_var id id; json_get_var dest dest; json_get_var label label
        printf '%s' "$id" | grep -Eq '^[0-9_]+$' || fail "Некорректный идентификатор исключения"
        uci -q get "network.${PREFIX}excl_$id" >/dev/null || fail "Исключение не найдено"
        valid_ipv4_cidr "$dest" || fail "Введите корректный IPv4-адрес или CIDR"
        dest="$(normalize_ipv4_cidr "$dest")" || fail "Не удалось определить маску подсети"
        [ "${#label}" -le 64 ] || fail "Название не длиннее 64 символов"
        printf '%s' "$label" | grep -q '[[:cntrl:]]' && fail "Недопустимое название"
        excl_exists "$dest" "$id" && fail "Такая подсеть уже в списке исключений"
        uci -q set "network.${PREFIX}excl_$id.dest=$dest"
        uci -q set "network.${PREFIX}excl_$id.name=${label:-$dest}"
        uci commit network
        rebuild_mixomo_redir
        finalize_changes ;;
    exclude_set_enabled)
        json_get_var id id; json_get_var enabled enabled
        printf '%s' "$id" | grep -Eq '^[0-9_]+$' || fail "Некорректный идентификатор исключения"
        uci -q get "network.${PREFIX}excl_$id" >/dev/null || fail "Исключение не найдено"
        case "$enabled" in 1|true) enabled=1;; *) enabled=0;; esac
        if [ "$enabled" = 1 ]; then
            uci -q delete "network.${PREFIX}excl_$id.disabled"
            uci -q delete "network.${PREFIX}excl_$id.enabled"
        else
            uci -q set "network.${PREFIX}excl_$id.disabled=1"
        fi
        uci commit network
        rebuild_mixomo_redir
        finalize_changes ;;
    reorder)
        json_get_var type type; json_get_var order order
        case "$type" in rule|exclude) :;; *) fail "Неизвестный тип правила" ;; esac
        oldifs="$IFS"; IFS=","; n=0
        for id in $order; do
            printf '%s' "$id" | grep -Eq '^[0-9_]+$' || continue
            if [ "$type" = "rule" ]; then
                uci -q set "network.${PREFIX}client_$id.priority=$((20000 + n))"
            else
                uci -q set "network.${PREFIX}excl_$id.priority=$((1000 + n))"
            fi
            n=$((n + 1))
        done
        IFS="$oldifs"
        network_sync
        finalize_changes ;;
    add)
        json_get_var source source; json_get_var label label; json_get_var backend backend
        valid_ipv4_cidr "$source" || fail "Введите корректный IPv4-адрес или CIDR"
        source="$(normalize_ipv4_cidr "$source")" || fail "Не удалось определить маску подсети"
        [ "${#label}" -le 64 ] || fail "Название не длиннее 64 символов"
        printf '%s' "$label" | grep -q '[[:cntrl:]]' && fail "Недопустимое название"
        [ -z "$backend" ] && backend="$(get_backend_default)"
        case "$backend" in redir-tproxy|tun-socks5) :;; *) fail "Неизвестный backend" ;; esac
        src_exists "$source" "" && fail "Такой адрес уже добавлен"
        id="$(date +%s)_$$"
        prio="$(next_priority "$source" "")"
        if [ "$backend" = "redir-tproxy" ]; then
            uci -q set "network.${PREFIX}client_$id=mihomo_rule"
            uci -q set "network.${PREFIX}client_$id.backend=redir-tproxy"
            uci -q set "network.${PREFIX}client_$id.priority=$prio"
            uci -q set "network.${PREFIX}client_$id.src=$source"
            uci -q set "network.${PREFIX}client_$id.name=${label:-$source}"
            uci -q delete "network.${PREFIX}client_$id.lookup"
            uci -q delete "network.${PREFIX}client_$id.enabled"
            uci -q delete "network.${PREFIX}client_$id.disabled"
            network_sync
        else
            table="$(ensure_base)" || fail "Не удалось подобрать свободную таблицу маршрутизации"
            uci -q set "network.${PREFIX}client_$id=rule"
            uci -q set "network.${PREFIX}client_$id.backend=tun-socks5"
            uci -q set "network.${PREFIX}client_$id.priority=$prio"
            uci -q set "network.${PREFIX}client_$id.src=$source"
            uci -q set "network.${PREFIX}client_$id.name=${label:-$source}"
            uci -q set "network.${PREFIX}client_$id.lookup=$table"
            uci -q delete "network.${PREFIX}client_$id.enabled"
            uci -q delete "network.${PREFIX}client_$id.disabled"
            apply_network "$table" || fail "Не удалось создать маршрут по умолчанию через интерфейс Mihomo"
            rebuild_mixomo_redir
        fi
        finalize_changes ;;
    update)
        json_get_var id id; json_get_var source source; json_get_var label label; json_get_var backend backend
        printf '%s' "$id" | grep -Eq '^[0-9_]+$' || fail "Некорректный идентификатор правила"
        uci -q get "network.${PREFIX}client_$id" >/dev/null || fail "Правило не найдено"
        valid_ipv4_cidr "$source" || fail "Введите корректный IPv4-адрес или CIDR"
        source="$(normalize_ipv4_cidr "$source")" || fail "Не удалось определить маску подсети"
        [ "${#label}" -le 64 ] || fail "Название не длиннее 64 символов"
        printf '%s' "$label" | grep -q '[[:cntrl:]]' && fail "Недопустимое название"
        [ -z "$backend" ] && backend="$(uci -q get network.${PREFIX}client_$id.backend)"
        [ -z "$backend" ] && backend="$(get_backend_default)"
        case "$backend" in redir-tproxy|tun-socks5) :;; *) fail "Неизвестный backend" ;; esac
        src_exists "$source" "$id" && fail "Такой адрес уже добавлен"
        prio="$(next_priority "$source" "$id")"
        uci -q set "network.${PREFIX}client_$id.src=$source"
        uci -q set "network.${PREFIX}client_$id.name=${label:-$source}"
        uci -q set "network.${PREFIX}client_$id.priority=$prio"
        uci -q set "network.${PREFIX}client_$id.backend=$backend"
        if [ "$backend" = "redir-tproxy" ]; then
            uci -q set "network.${PREFIX}client_$id=mihomo_rule"
            uci -q delete "network.${PREFIX}client_$id.lookup"
            network_sync
        else
            table="$(ensure_base)" || fail "Не удалось подготовить таблицу маршрутизации"
            uci -q set "network.${PREFIX}client_$id=rule"
            uci -q set "network.${PREFIX}client_$id.lookup=$table"
            apply_network "$table" || fail "Не удалось применить сетевые настройки"
            rebuild_mixomo_redir
        fi
        finalize_changes ;;
    delete)
        json_get_var id id
        printf '%s' "$id" | grep -Eq '^[0-9_]+$' || fail "Некорректный идентификатор правила"
        uci -q get "network.${PREFIX}client_$id" >/dev/null || fail "Правило не найдено"
        table="$(uci -q get network.$TABLE_SECTION.table)"
        uci -q delete "network.${PREFIX}client_$id"
        cleanup_if_unused
        uci commit network
        if [ -n "$(uci -q get network.$TABLE_SECTION.table)" ]; then
            apply_network "$table" || true
        else
            /etc/init.d/network reload 2>/dev/null
        fi
        rebuild_mixomo_redir
        finalize_changes ;;
    set_enabled)
        json_get_var id id; json_get_var enabled enabled
        printf '%s' "$id" | grep -Eq '^[0-9_]+$' || fail "Некорректный идентификатор правила"
        uci -q get "network.${PREFIX}client_$id" >/dev/null || fail "Правило не найдено"
        case "$enabled" in 1|true) enabled=1;; *) enabled=0;; esac
        backend="$(uci -q get network.${PREFIX}client_$id.backend)"
        [ -z "$backend" ] && backend="$(get_backend_default)"
        prio="$(uci -q get network.${PREFIX}client_$id.priority)"
        if [ "$backend" = "redir-tproxy" ]; then
            uci -q set "network.${PREFIX}client_$id=mihomo_rule"
            if [ "$enabled" = 1 ]; then
                uci -q delete "network.${PREFIX}client_$id.disabled"
                uci -q delete "network.${PREFIX}client_$id.enabled"
            else
                uci -q set "network.${PREFIX}client_$id.disabled=1"
            fi
            network_sync
        else
            uci -q set "network.${PREFIX}client_$id=rule"
            if [ "$enabled" = 1 ]; then
                uci -q delete "network.${PREFIX}client_$id.disabled"
                uci -q delete "network.${PREFIX}client_$id.enabled"
            else
                [ -n "$prio" ] && ip rule del priority "$prio" 2>/dev/null || true
                uci -q set "network.${PREFIX}client_$id.disabled=1"
            fi
            table="$(uci -q get network.$TABLE_SECTION.table)"
            if [ -n "$table" ]; then
                apply_network "$table" || fail "Не удалось применить сетевые настройки"
            else
                network_sync
            fi
        fi
        finalize_changes ;;
    set_router)
        json_get_var enabled enabled
        table="$(ensure_base)" || fail "Не удалось подобрать свободную таблицу маршрутизации"
        case "$enabled" in 1|true) enabled=1;; *) enabled=0;; esac
        if [ "$enabled" = 1 ]; then
            uci -q set "network.${PREFIX}router=rule"; uci -q set "network.${PREFIX}router.name=Mixomo-router"
            uci -q delete "network.${PREFIX}router.src"
            uci -q set "network.${PREFIX}router.priority=19000"; uci -q set "network.${PREFIX}router.mark=$ROUTER_MARK"; uci -q set "network.${PREFIX}router.lookup=$table"
            enable_router_mark || fail "Не удалось включить правило трафика роутера"
            apply_network "$table" || fail "Не удалось создать маршрут по умолчанию через интерфейс Mihomo"
            ensure_router_policy "$table" || fail "Не удалось создать policy rule для трафика роутера"
        else
            ip rule del priority 19000 fwmark "$ROUTER_MARK" 2>/dev/null || true
            uci -q delete "network.${PREFIX}router"
            cleanup_if_unused
            [ -n "$(uci -q get network.$TABLE_SECTION.table)" ] && apply_network "$table" || true
        fi
        finalize_changes ;;
    set_udp443)
        json_get_var enabled enabled
        case "$enabled" in 1|true) enabled=1;; *) enabled=0;; esac
        if [ "$enabled" = 1 ]; then
            uci -q delete firewall.Block_443_UDP
            uci -q set firewall.Block_443_UDP=rule
            uci -q set firewall.Block_443_UDP.name='Block-443-UDP'
            uci -q set firewall.Block_443_UDP.src='wan'
            uci -q set firewall.Block_443_UDP.dest='*'
            uci -q set firewall.Block_443_UDP.family='any'
            uci -q set firewall.Block_443_UDP.proto='udp'
            uci -q set firewall.Block_443_UDP.dest_port='443'
            uci -q set firewall.Block_443_UDP.target='REJECT'
        else
            uci -q delete firewall.Block_443_UDP
        fi
        uci commit firewall
        /etc/init.d/firewall reload
        finalize_changes ;;
    *) fail "Неизвестный метод";;
    esac ;;
esac
EOF
    chmod 755 /usr/libexec/rpcd/mihomo-routing

    echo "$(T "Создание RPC-бэкенда mihomo-dns" "Creating the mihomo-dns RPC backend")"
    mkdir -p /usr/libexec/rpcd /etc/mixomo/dns
    cat > /usr/libexec/rpcd/mihomo-dns <<'EOF'
#!/bin/sh
. /usr/share/libubox/jshn.sh

DNS_CONF="/etc/dnsmasq.conf"
DNS_MARK_START="# Rules from Mixomo"
DNS_MARK_END="# End rules from Mixomo"
DNS_CUSTOM_FILE="/etc/mixomo/dns/custom"

fail() { json_init; json_add_boolean ok 0; json_add_string error "$1"; json_dump; exit 0; }

extract_dns_block() {
    [ -f "$DNS_CONF" ] || return 0
    awk -v s="$DNS_MARK_START" -v e="$DNS_MARK_END" '
        $0 == s { f=1; next }
        $0 == e { f=0; next }
        f { print }
    ' "$DNS_CONF"
}

strip_trailing_blanks() {
    awk '{ a[n++]=$0 } END { m=n; while (m>0 && a[m-1]=="") m--; for (i=0;i<m;i++) print a[i] }'
}

write_dns_block() {
    local block="$1" clean="$2" tmp
    block="$(printf '%s\n' "$block" | strip_trailing_blanks)"
    tmp=$(mktemp) || return 1
    if [ "$clean" = "1" ]; then
        : > "$tmp"
    elif [ -f "$DNS_CONF" ]; then
        sed -e "/^${DNS_MARK_START}$/,/^${DNS_MARK_END}$/d" "$DNS_CONF" | strip_trailing_blanks > "$tmp"
    else
        : > "$tmp"
    fi
    [ -s "$tmp" ] && printf '\n' >> "$tmp"
    printf '%s\n%s\n%s\n' "$DNS_MARK_START" "$block" "$DNS_MARK_END" >> "$tmp"
    mv "$tmp" "$DNS_CONF"
    return 0
}

remove_dns_block() {
    [ -f "$DNS_CONF" ] || return 0
    local tmp
    tmp=$(mktemp) || return 1
    sed -e "/^${DNS_MARK_START}$/,/^${DNS_MARK_END}$/d" "$DNS_CONF" | strip_trailing_blanks > "$tmp"
    mv "$tmp" "$DNS_CONF"
    return 0
}

restart_dnsmasq() {
    service dnsmasq restart >/dev/null 2>&1 || /etc/init.d/dnsmasq restart >/dev/null 2>&1
}

emit_status() {
    local block="" has_markers=0 no_resolv=0 strict_order=0 all_servers=0 tmp
    [ -f "$DNS_CONF" ] && grep -q "^${DNS_MARK_START}$" "$DNS_CONF" && has_markers=1
    block="$(extract_dns_block)"
    tmp=$(mktemp) || tmp=""
    if [ -n "$tmp" ]; then
        extract_dns_block > "$tmp"
        while IFS= read -r line; do
            case "$line" in
                no-resolv) no_resolv=1 ;;
                strict-order) strict_order=1 ;;
                all-servers) all_servers=1 ;;
            esac
        done < "$tmp"
    fi
    json_init
    json_add_boolean ok 1
    json_add_string block "$block"
    json_add_boolean hasMarkers "$has_markers"
    json_add_boolean noResolv "$no_resolv"
    json_add_boolean strictOrder "$strict_order"
    json_add_boolean allServers "$all_servers"
    json_add_array servers
    if [ -n "$tmp" ]; then
        while IFS= read -r line; do
            case "$line" in
                server=*) json_add_string "" "${line#server=}" ;;
            esac
        done < "$tmp"
    fi
    json_close_array
    [ -n "$tmp" ] && rm -f "$tmp"
    json_add_array custom
    if [ -f "$DNS_CUSTOM_FILE" ]; then
        while IFS="$(printf '\t')" read -r name value; do
            [ -n "$name" ] || continue
            json_add_object
            json_add_string name "$name"
            json_add_string value "$value"
            json_close_object
        done < "$DNS_CUSTOM_FILE"
    fi
    json_close_array
    json_dump
}

case "$1" in
list) echo '{"status":{},"apply":{"block":"String","clean":false},"clear":{},"add_preset":{"name":"String","value":"String"},"remove_preset":{"name":"String"}}' ;;
call)
    json_load "$(cat)"
    case "$2" in
    status) emit_status ;;
    apply)
        json_get_var block block; json_get_var clean clean
        case "$clean" in 1|true) clean=1;; *) clean=0;; esac
        write_dns_block "$block" "$clean" || fail "Не удалось записать /etc/dnsmasq.conf"
        restart_dnsmasq
        json_init; json_add_boolean ok 1; json_dump ;;
    clear)
        remove_dns_block || fail "Не удалось изменить /etc/dnsmasq.conf"
        restart_dnsmasq
        json_init; json_add_boolean ok 1; json_dump ;;
    add_preset)
        json_get_var name name; json_get_var value value
        name="$(printf '%s' "$name" | tr -d ' \r\n')"
        value="$(printf '%s' "$value" | tr -d ' \r\n')"
        [ -n "$name" ] || fail "Пустое название"
        [ -n "$value" ] || fail "Пустое значение DNS"
        [ "${#name}" -le 64 ] || fail "Название не длиннее 64 символов"
        printf '%s' "$name" | grep -q '[[:cntrl:]]' && fail "Недопустимое название"
        case "$value" in *[!A-Za-z0-9.#:\-@]*) fail "Недопустимый DNS: $value" ;; esac
        ip_part="${value%%#*}"
        oldifs="$IFS"; IFS=.; set -- $ip_part; IFS="$oldifs"
        [ "$#" -eq 4 ] || fail "Укажите IPv4-адрес DNS"
        for oct in "$@"; do
            case "$oct" in ''|*[!0-9]*) fail "Недопустимый DNS: $value" ;; esac
            [ "${#oct}" -le 3 ] || fail "Октет IP не длиннее 3 цифр: $oct"
        done
        mkdir -p "$(dirname "$DNS_CUSTOM_FILE")"
        [ -f "$DNS_CUSTOM_FILE" ] || : > "$DNS_CUSTOM_FILE"
        grep -Fq "$(printf '%s\t' "$name")" "$DNS_CUSTOM_FILE" && fail "Такой DNS уже добавлен"
        printf '%s\t%s\n' "$name" "$value" >> "$DNS_CUSTOM_FILE"
        json_init; json_add_boolean ok 1; json_dump ;;
    remove_preset)
        json_get_var name name
        if [ -f "$DNS_CUSTOM_FILE" ]; then
            tmp=$(mktemp) || fail "Не удалось создать временный файл"
            grep -vF "$(printf '%s\t' "$name")" "$DNS_CUSTOM_FILE" > "$tmp" || true
            mv "$tmp" "$DNS_CUSTOM_FILE"
        fi
        json_init; json_add_boolean ok 1; json_dump ;;
    *) fail "Неизвестный метод" ;;
    esac ;;
esac
EOF
    chmod 755 /usr/libexec/rpcd/mihomo-dns
    
    if [ "$(uci -q get network.mihomo_route_router.mark)" = "0x233" ]; then
        printf '%s\n' '{"enabled":true}' | /usr/libexec/rpcd/mihomo-routing call set_router >/dev/null 2>&1 || \
            log_warn "$(T "Не удалось автоматически обновить особое правило маршрутизации роутера" "Could not automatically update the router special routing rule")"
    else
        uci -q delete firewall.mihomo_router_routing
        rm -f /etc/mihomo/mihomo-router-routing.nft
        uci commit firewall
    fi

    local VIEW_PATH="/www/luci-static/resources/view/mihomo"
    local ACE_PATH="$VIEW_PATH/ace"
    mkdir -p "$ACE_PATH"

    echo "$(T "Определение актуальной версии ACE Editor" "Detecting the latest ACE Editor version")"
    local LATEST_ACE_VER
    LATEST_ACE_VER=$(curl -s "https://api.cdnjs.com/libraries/ace" | grep -o '"version":"[^"]*"' | cut -d'"' -f4 | head -1)
    if [ -z "$LATEST_ACE_VER" ]; then
        log_warn "$(T "cdnjs API недоступен, пробуем GitHub API" "cdnjs API unavailable, trying GitHub API")"
        LATEST_ACE_VER=$(curl -s "https://api.github.com/repos/ajaxorg/ace/releases/latest" | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4 | sed 's/^v//' | head -1)
    fi
    if [ -z "$LATEST_ACE_VER" ]; then
        log_warn "$(T "Используем фиксированную версию ACE Editor" "Using a fixed ACE Editor version")"
        LATEST_ACE_VER="1.43.3"
    else
        echo "$(T "Актуальная версия ACE Editor: $LATEST_ACE_VER" "Latest ACE Editor version: $LATEST_ACE_VER")"
    fi

    local ACE_FILES="ace.js theme-merbivore_soft.js theme-tomorrow.js mode-yaml.js worker-yaml.js"
    local ACE_VERSION_FILE="$MIXOMO_VERSIONS_DIR/ace"
    local ACE_UP_TO_DATE=1
    local f fname
    mkdir -p "$MIXOMO_VERSIONS_DIR" 2>/dev/null || true
    rm -f "$ACE_PATH/.ace-version" 2>/dev/null || true
    if [ -f "$ACE_VERSION_FILE" ] && [ "$(tr -d ' \r\n' < "$ACE_VERSION_FILE")" = "$LATEST_ACE_VER" ]; then
        for fname in $ACE_FILES; do
            [ -s "$ACE_PATH/$fname" ] || { ACE_UP_TO_DATE=0; break; }
        done
    else
        ACE_UP_TO_DATE=0
    fi

    if [ "$ACE_UP_TO_DATE" -eq 1 ]; then
        log_online "$(T "Актуальный ACE Editor $LATEST_ACE_VER уже установлен" "ACE Editor $LATEST_ACE_VER is already up to date")"
    else
        log_online "$(T "Скачивание файлов для ACE Editor $LATEST_ACE_VER:" "Downloading files for ACE Editor $LATEST_ACE_VER:")"
        local CDNJS_ACE_VER="1.43.6"
        for file in $ACE_FILES; do
            local dest="${ACE_PATH}/${file}"
            local success=0
            
            for url in "https://cdn.jsdelivr.net/npm/ace-builds@${LATEST_ACE_VER}/src-min-noconflict/${file}" \
                       "https://raw.githubusercontent.com/ajaxorg/ace-builds/master/src-min-noconflict/${file}" \
                       "https://cdnjs.cloudflare.com/ajax/libs/ace/${CDNJS_ACE_VER}/${file}"; do
                
                log_online "$(T "Скачивание $file" "Downloading $file")"
                if curl -Lf -s --connect-timeout 5 --max-time 30 -o "$dest" "$url" || wget -q -T 5 -O "$dest" "$url"; then
                    if [ -s "$dest" ]; then
                        success=1
                        break
                    fi
                fi
                echo "FAIL"
            done

            if [ "$success" -eq 0 ]; then
                log_error "$(T "Не удалось скачать $file ни из одного источника." "Could not download $file from any source.")"
                return 1
            fi
        done
        echo "$LATEST_ACE_VER" > "$ACE_VERSION_FILE"
    fi

    echo "$(T "Создание config.js" "Creating config.js")"
    cat > "$VIEW_PATH/config.js" <<'EOF'
'use strict';
'require view';
'require fs';
'require ui';
'require rpc';

var ACE_DIR = '/luci-static/resources/view/mihomo/ace/';
var RELOAD_DELAY = 1000;
var MAIN_CONFIG = '/etc/mihomo/config.yaml';
var RULE_DIR = '/etc/mihomo/rule-files/';

var editor = null;
var currentFile = MAIN_CONFIG;
var cachedRuleFiles = [];
var mainConfigContent = '';
var loadedScripts = {};
var VALID_ACTIONS = ['start', 'stop', 'restart', 'check', 'logs'];

var DNS_PRESETS = [
    { name: 'Mihomo', values: ['127.0.0.1#7880'] },
    { name: 'Google', values: ['8.8.8.8', '8.8.4.4'] },
    { name: 'Cloudflare', values: ['1.1.1.1', '1.0.0.1'] },
    { name: 'Quad9', values: ['9.9.9.9', '149.112.112.112'] },
    { name: 'AdGuard', values: ['94.140.14.140', '94.140.14.141'] },
    { name: 'Yandex', values: ['77.88.8.8', '77.88.8.1'] }
];

var MIXOMO_EN = {
    '(доступна новая версия %s)': '(new version %s available)',
    'Файл /etc/dnsmasq.conf будет полностью очищен, останутся только ваши правила.': 'The /etc/dnsmasq.conf file will be completely cleared; only your rules will remain.',
    'DNS-серверы': 'DNS servers',
    'Распаковка архива...': 'Extracting archive...',
    'Режим использования DNS': 'DNS usage mode',
    'Редактировать': 'Edit',
    'Редактировать исключение': 'Edit exclusion',
    'Редактировать правило': 'Edit rule',
    'Ручной режим': 'Manual mode',
    'В конфигурации есть строки server= вне пресетов: ': 'The configuration has server= lines outside presets: ',
    'Включено': 'Enabled',
    'Включить': 'Enable',
    'Включить исходящий трафик этого устройства через Mihomo?': 'Route this devices outbound traffic through Mihomo?',
    'Вниз': 'Down',
    'Введите название': 'Enter a name',
    'Вверх': 'Up',
    'Выберите устройство...': 'Select a device...',
    'Выдача постоянных прав...': 'Setting permanent permissions...',
    'Выдача временных прав...': 'Setting temporary permissions...',
    'Отключить исходящий трафик этого устройства через Mihomo?': 'Disable this devices outbound traffic via Mihomo?',
    'Выполнение...': 'Running...',
    'Вывод:': 'Output:',
    'Действие': 'Action',
    'Добавление...': 'Adding...',
    'Добавлять устройства и подсети можно только из локальных диапазонов.': 'Devices and subnets can only be added from local ranges.',
    'Добавить': 'Add',
    'Добавить автоматически': 'Add automatically',
    'Добавить правило': 'Add rule',
    'Дополнительное подтверждение': 'Additional confirmation',
    'Локальная маршрутизация': 'Local routing',
    'Файл уже существует': 'File already exists',
    'Чтобы Mihomo увидел файл, добавьте эту секцию в rule-providers:': 'For Mihomo to see the file, add this section to rule-providers:',
    'Или': 'Or',
    'Имя файла:': 'File name:',
    'Исключённые адреса': 'Excluded addresses',
    'Адрес': 'Address',
    'Адрес (IP или CIDR)': 'Address (IP or CIDR)',
    'остановлен': 'stopped',
    'У вас установлена самая актуальная версия': 'You have the latest version installed',
    'Удаление бэкапа...': 'Deleting backup...',
    'Удаление...': 'Deleting...',
    'Удалить': 'Delete',
    'Удалить %s?': 'Delete %s?',
    'Удалить правила DNS Mixomo из dnsmasq?': 'Delete Mixomo DNS rules from dnsmasq?',
    'Удалить это правило?': 'Delete this rule?',
    'Удалить этот адрес?': 'Delete this address?',
    'Установить обновление': 'Install update',
    'Установка ядра...': 'Installing the core...',
    'Название': 'Name',
    'Название (необязательно)': 'Name (optional)',
    'Направлять исходящий трафик этого устройства через Mihomo': "Route this device's outgoing traffic through Mihomo",
    'Настройка DNS-серверов через файл /etc/dnsmasq.conf. Изменения вступают в силу после нажатия «Применить».': "Configure DNS servers via the /etc/dnsmasq.conf file. Changes take effect after clicking 'Apply'.",
    'Настройки': 'Settings',
    'Не удалось получить состояние DNS': 'Could not get DNS status',
    'Не удалось применить правило': 'Could not apply the rule',
    'Недопустимый путь': 'Invalid path',
    'Некорректное имя': 'Invalid name',
    'Некорректный DNS: укажите IPv4 с октетами не длиннее 3 цифр (например 8.8.8.8 или 127.0.0.1#7880)': 'Invalid DNS: provide an IPv4 with octets no longer than 3 digits (e.g. 8.8.8.8 or 127.0.0.1#7880)',
    'Ничего не выбрано. Удалить все правила DNS из dnsmasq?': 'Nothing selected. Delete all DNS rules from dnsmasq?',
    'Новый файл правил': 'New rules file',
    'Закрепить локальные IP за конкретными устройствами можно в ': 'You can pin local IPs to specific devices in ',
    'Запуск Mihomo...': 'Starting Mihomo...',
    'Запустить': 'Start',
    'Загрузка...': 'Loading...',
    'Обновлено успешно! Перезагрузка...': 'Updated successfully! Reloading...',
    'Блокировать QUIC (UDP/443)': 'Block QUIC (UDP/443)',
    'Отключено': 'Disabled',
    'Отключить': 'Disable',
    'Открыть панель управления': 'Open dashboard',
    'Отмена': 'Cancel',
    'Отменить': 'Cancel',
    'Ошибка DNS: ': 'DNS error: ',
    'Ошибка RPC': 'RPC error',
    'Ошибка пути': 'Path error',
    'Ошибка маршрутизации: ': 'Routing error: ',
    'Ошибка. Повторить обновление?': 'Error. Retry the update?',
    'Ошибка: ': 'Error: ',
    'Ошибка: %s': 'Error: %s',
    'Очистить /etc/dnsmasq.conf перед применением': 'Clear /etc/dnsmasq.conf before applying',
    'Особые правила': 'Special rules',
    'Остановить': 'Stop',
    'Остановка Mihomo...': 'Stopping Mihomo...',
    'Такое название уже есть среди пресетов': 'This name already exists among the presets',
    'Текст помещается между маркерами # Rules from Mixomo и # End rules from Mixomo. В ручном режиме ничего не генерируется автоматически.': 'The text is placed between the # Rules from Mixomo and # End rules from Mixomo markers. In manual mode nothing is generated automatically.',
    'Тип подключения': 'Connection type',
    'Тип файла:': 'File type:',
    'Скачивание архива %s...': 'Downloading archive %s...',
    'Скопировать текст': 'Copy text',
    'Сначала выберите устройство': 'First select a device',
    'Создание бэкапа...': 'Creating backup...',
    'Создание...': 'Creating...',
    'Создать': 'Create',
    'Создать новый': 'Create new',
    'Сохранение...': 'Saving...',
    'Сохранить': 'Save',
    'Стандартный': 'Standard',
    'Статических арендах DHCP': 'DHCP static leases',
    'Статус': 'Status',
    'Строгий порядок': 'Strict order',
    'Строгий порядок — опрос по списку, переход к следующему при ошибке.<br>': 'Strict order - queries the list in order, moving to the next on error.<br>',
    'Стандартный — автоматический выбор самого быстрого сервера.<br>': 'Standard - automatically picks the fastest server.<br>',
    'Параллельный — запрос ко всем серверам сразу, ответ от самого первого.': 'Parallel - queries all servers at once, using the very first response.',
    'После применения заменяет все правила из «Простого режима» на ваши.': "After applying, replaces all rules from the 'Simple mode' with yours.",
    'Трафик к этим адресам никогда не направляется через Mihomo.': 'Traffic to these addresses is never routed through Mihomo.',
    'Параллельный': 'Parallel',
    'По умолчанию добавлены следующие подсети, без возможности их удалить:': 'The following subnets are added by default, without the ability to remove them:',
    'Подождите...': 'Please wait...',
    'Подтверждение': 'Confirmation',
    'Показать журнал': 'Show log',
    'Правил пока нет.': 'No rules yet.',
    'При использовании абсолютно весь трафик направляется через Mihomo.': 'When enabled, all traffic is routed through Mihomo.',
    'При применении они будут удалены.': 'They will be removed when applied.',
    'Применение...': 'Applying...',
    'Применить': 'Apply',
    'Все устройства переходят на TCP вместо UDP (QUIC) на 443 порту, что упрощает маршрутизацию в Mihomo.': 'All devices switch to TCP instead of UDP (QUIC) on port 443, which simplifies routing in Mihomo.',
    'Применяется только к исходящим соединениям этого устройства — apk update, opkg update, wget, curl и тому подобное.': "Applies only to this device's outgoing connections - apk update, opkg update, wget, curl and the like.",
    'Продолжить': 'Continue',
    'Проверить конфигурацию': 'Check configuration',
    'Проверить обновление': 'Check for update',
    'Проверка обновлений...': 'Checking for updates...',
    'Проверка ядра...': 'Checking the core...',
    'Проверка...': 'Checking...',
    'Простой режим': 'Simple mode',
    'работает': 'running'
};

function detectLuciLang() {
    var lang = '';
    if (window.LANG) {
        lang = window.LANG;
    } else if (document.documentElement && document.documentElement.lang) {
        lang = document.documentElement.lang;
    }
    return (lang || 'ru').toLowerCase();
}

var MIXOMO_IS_EN = /^en/.test(detectLuciLang());

(function() {
    var orig = window._;
    window._ = function(text) {
        if (MIXOMO_IS_EN && MIXOMO_EN.hasOwnProperty(text)) {
            return MIXOMO_EN[text];
        }
        if (orig) {
            return orig.apply(window, arguments);
        }
        return text;
    };
})();

function trError(text) {
    if (!text || typeof text !== 'string' || !MIXOMO_IS_EN) {
        return text;
    }
    if (MIXOMO_EN.hasOwnProperty(text)) {
        return MIXOMO_EN[text];
    }
    if (/^Недопустимый DNS: /.test(text)) {
        return 'Invalid DNS: ' + text.replace(/^Недопустимый DNS: /, '');
    }
    if (/^Октет IP не длиннее 3 цифр: /.test(text)) {
        return 'IP octet no longer than 3 digits: ' + text.replace(/^Октет IP не длиннее 3 цифр: /, '');
    }
    return text;
}


var callServiceList = rpc.declare({
    object: 'service',
    method: 'list',
    params: ['name']
});

var callRoutingStatus = rpc.declare({ object: 'mihomo-routing', method: 'status', expect: { '': {} } });
var callRoutingClients = rpc.declare({ object: 'mihomo-routing', method: 'clients', expect: { '': {} } });
var callRoutingAdd = rpc.declare({ object: 'mihomo-routing', method: 'add', params: ['source', 'label', 'backend'], expect: { '': {} } });
var callRoutingUpdate = rpc.declare({ object: 'mihomo-routing', method: 'update', params: ['id', 'source', 'label', 'backend'], expect: { '': {} } });
var callRoutingDelete = rpc.declare({ object: 'mihomo-routing', method: 'delete', params: ['id'], expect: { '': {} } });
var callRoutingEnabled = rpc.declare({ object: 'mihomo-routing', method: 'set_enabled', params: ['id', 'enabled'], expect: { '': {} } });
var callRoutingRouter = rpc.declare({ object: 'mihomo-routing', method: 'set_router', params: ['enabled'], expect: { '': {} } });
var callRoutingUdp443 = rpc.declare({ object: 'mihomo-routing', method: 'set_udp443', params: ['enabled'], expect: { '': {} } });
var callRoutingExcludeAdd = rpc.declare({ object: 'mihomo-routing', method: 'exclude_add', params: ['dest', 'label'], expect: { '': {} } });
var callRoutingExcludeDelete = rpc.declare({ object: 'mihomo-routing', method: 'exclude_delete', params: ['id'], expect: { '': {} } });
var callRoutingExcludeUpdate = rpc.declare({ object: 'mihomo-routing', method: 'exclude_update', params: ['id', 'dest', 'label'], expect: { '': {} } });
var callRoutingExcludeEnabled = rpc.declare({ object: 'mihomo-routing', method: 'exclude_set_enabled', params: ['id', 'enabled'], expect: { '': {} } });
var callRoutingReorder = rpc.declare({ object: 'mihomo-routing', method: 'reorder', params: ['type', 'order'], expect: { '': {} } });
var callDnsStatus = rpc.declare({ object: 'mihomo-dns', method: 'status', expect: { '': {} } });
var callDnsApply = rpc.declare({ object: 'mihomo-dns', method: 'apply', params: ['block', 'clean'], expect: { '': {} } });
var callDnsClear = rpc.declare({ object: 'mihomo-dns', method: 'clear', expect: { '': {} } });
var callDnsAddPreset = rpc.declare({ object: 'mihomo-dns', method: 'add_preset', params: ['name', 'value'], expect: { '': {} } });
var callDnsRemovePreset = rpc.declare({ object: 'mihomo-dns', method: 'remove_preset', params: ['name'], expect: { '': {} } });

function escapeHtml(text) {
    if (typeof text !== 'string') return text;
    return text.replace(/[&<>"']/g, function(m) {
        return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[m];
    });
}

function backendLabel(backend) {
    return (backend === 'redir-tproxy') ? 'Redir-TProxy' : 'Tun-Socks5';
}

function displaySource(source) {
    if (typeof source === 'string' && /\/32$/.test(source)) return source.slice(0, -3);
    return source || '';
}

function validatePath(path, allowedBase) {
    if (!path || typeof path !== 'string') return false;
    if (path.includes('..') || path.includes('\0') || path.includes('~')) return false;
    var resolved = path.replace(/\/+/g, '/');
    if (!resolved.startsWith(allowedBase)) return false;
    if (resolved.length > 1024) return false;
    return true;
}

function isSafeRulePath(path) {
    return validatePath(path, RULE_DIR) && path !== MAIN_CONFIG;
}

function validateFilename(filename) {
    if (!filename || typeof filename !== 'string') return false;
    if (!/^[a-zA-Z0-9._-]+$/.test(filename)) return false;
    if (filename.length > 255) return false;
    var reservedNames = ['con', 'prn', 'aux', 'nul', 'com1', 'lpt1', '.'];
    if (reservedNames.includes(filename.toLowerCase())) return false;
    return true;
}

function isValidDnsValue(value) {
    if (!value || typeof value !== 'string') return false;
    if (!/^[0-9A-Za-z.#:\-@]+$/.test(value)) return false;
    var ip = value.split('#')[0];
    var parts = ip.split('.');
    if (parts.length !== 4) return false;
    for (var i = 0; i < parts.length; i++) {
        if (!/^\d{1,3}$/.test(parts[i])) return false;
    }
    return true;
}

function sanitizeTabName(name) {
    if (!name) return '';
    return name.replace(/[<>"'`]/g, '');
}

function loadScript(src) {
    return new Promise(function(resolve, reject) {
        if (loadedScripts[src]) { resolve(); return; }
        var script = document.createElement('script');
        script.src = src;
        script.onload = function() { loadedScripts[src] = true; resolve(); };
        script.onerror = reject;
        document.head.appendChild(script);
    });
}

function detectRuleType(line) {
    line = line.trim();
    if (line.includes(':') && !line.match(/http(s)?:\/\//)) return 'IP-CIDR6';
    if (/^\d{1,3}(\.\d{1,3}){3}\/\d+$/.test(line)) return 'IP-CIDR';
    if (/^\d{1,3}(\.\d{1,3}){3}$/.test(line)) return 'IP-CIDR';
    if (line.startsWith('.')) return 'DOMAIN-WILDCARD';
    var cleanDomain = line.replace(/^\./, '');
    var dots = (cleanDomain.match(/\./g) || []).length;
    if (dots >= 2) return 'DOMAIN';
    if (dots === 1) return 'DOMAIN-SUFFIX';
    return 'DOMAIN-KEYWORD';
}

function generateProviderSnippet(filename) {
    if (filename === MAIN_CONFIG) return '';
    var baseName = filename.split('/').pop();
    if (!validateFilename(baseName)) throw new Error('Invalid filename');
    var nameNoExt = baseName.replace(/\.(yaml|txt)$/, '');
    var isTxt = baseName.endsWith('.txt');
    var behavior = isTxt ? 'domain' : 'classical';
    var format = isTxt ? 'text' : 'yaml';
    return `${nameNoExt}-list:\n  type: file\n  behavior: ${behavior}\n  format: ${format}\n  path: ./rule-files/${baseName}`;
}

function isLuciDarkMode() {
    try {
        var rgb = window.getComputedStyle(document.body).backgroundColor.match(/\d+/g);
        if (rgb) {
            var luma = 0.2126 * parseInt(rgb[0]) + 0.7152 * parseInt(rgb[1]) + 0.0722 * parseInt(rgb[2]); 
            return luma < 128;
        }
    } catch(e) {}
    return false;
}

return view.extend({
    isProcessing: false,
    currentVersion: 'Неизвестно',
    latestVersion: null,
    updateButton: null,
    latestVersionEl: null,
    routingPanel: null,
    dnsPanel: null,
    settingsActive: null,
    dnsModeRow: null,
    dnsMode: 'simple',
    dnsUsageMode: 'standard',
    dnsChecks: {},
    dnsForeign: [],
    dnsData: null,
    dnsManualText: '',
    dnsClean: false,
    dnsOrder: [],

    showRoutingError: function(result) {
        if (!result || !result.ok) ui.addNotification(null, E('p', (result && trError(result.error)) || _('Не удалось применить правило')), 'error');
        return result && result.ok;
    },

    confirmRouterRouting: function(enable) {
        var self = this;
        var text = enable
            ? _('Включить исходящий трафик этого устройства через Mihomo?')
            : _('Отключить исходящий трафик этого устройства через Mihomo?');
        ui.showModal(_('Дополнительное подтверждение'), [
            E('p', {}, text),
            E('div', { class: 'right', style: 'margin-top:1rem;' }, [
                E('button', { class: 'btn cbi-button-neutral', click: ui.hideModal }, _('Отменить')), ' ',
                E('button', { class: 'btn cbi-button-positive btn-save-custom', click: function() {
                    ui.hideModal();
                    callRoutingRouter(enable).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); });
                }}, _('Продолжить'))
            ])
        ]);
    },

    setUdp443: function(enabled) {
        var self = this;
        callRoutingUdp443(enabled).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); });
    },

    editRoutingRule: function(rule) {
        var self = this;
        var redirAvail = !!(this.routingData && (this.routingData.redirAvailable === true || this.routingData.redirAvailable === 1 || this.routingData.redirAvailable === '1'));
        var source = E('input', { type: 'text', value: displaySource(rule.source), style: 'width:100%;' });
        var label = E('input', { type: 'text', value: rule.label || '', style: 'width:100%;' });
        var opts = [];
        if (redirAvail) opts.push(E('option', { value: 'redir-tproxy' }, 'Redir-TProxy'));
        opts.push(E('option', { value: 'tun-socks5' }, 'Tun-Socks5'));
        var backend = E('select', { style: 'width:100%;' }, opts);
        backend.value = (rule.backend === 'redir-tproxy' && redirAvail) ? 'redir-tproxy' : 'tun-socks5';
        ui.showModal(_('Редактировать правило'), [
            E('div', {}, [E('label', {}, _('Адрес (IP или CIDR)')), source]),
            E('div', { style: 'margin-top:.7rem;' }, [E('label', {}, _('Название')), label]),
            E('div', { style: 'margin-top:.7rem;' }, [E('label', {}, _('Тип подключения')), backend]),
            E('div', { class: 'right', style: 'margin-top:1rem;' }, [
                E('button', { class: 'btn cbi-button-neutral', click: ui.hideModal }, _('Отменить')), ' ',
                E('button', { class: 'btn cbi-button-positive btn-save-custom', click: function() {
                    callRoutingUpdate(rule.id, source.value.trim(), label.value.trim(), backend.value).then(function(res) { if (self.showRoutingError(res)) { ui.hideModal(); self.refreshRouting(); } });
                }}, _('Сохранить'))
            ])
        ]);
    },

    editExclusion: function(ex) {
        var self = this;
        var dest = E('input', { type: 'text', value: displaySource(ex.dest), style: 'width:100%;' });
        var label = E('input', { type: 'text', value: ex.label || '', style: 'width:100%;' });
        ui.showModal(_('Редактировать исключение'), [
            E('div', {}, [E('label', {}, _('Адрес (IP или CIDR)')), dest]),
            E('div', { style: 'margin-top:.7rem;' }, [E('label', {}, _('Название')), label]),
            E('div', { class: 'right', style: 'margin-top:1rem;' }, [
                E('button', { class: 'btn cbi-button-neutral', click: ui.hideModal }, _('Отменить')), ' ',
                E('button', { class: 'btn cbi-button-positive btn-save-custom', click: function() {
                    callRoutingExcludeUpdate(ex.id, dest.value.trim(), label.value.trim()).then(function(res) { if (self.showRoutingError(res)) { ui.hideModal(); self.refreshRouting(); } }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                }}, _('Сохранить'))
            ])
        ]);
    },

    handleReorder: function(type, ids) {
        var self = this;
        return callRoutingReorder(type, ids.join(',')).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
    },

    moveItem: function(type, arr, idx, dir) {
        var j = idx + dir;
        if (j < 0 || j >= arr.length) return;
        var tmp = arr[idx]; arr[idx] = arr[j]; arr[j] = tmp;
        this.handleReorder(type, arr.map(function(r) { return r.id; }));
    },

    refreshRouting: function() {
        var self = this;
        return Promise.all([callRoutingStatus(), callRoutingClients()]).then(function(data) {
            self.routingData = data[0] || {}; self.clientData = data[1] || {};
            self.renderRoutingPanel();
        }).catch(function(err) { ui.addNotification(null, E('p', _('Ошибка маршрутизации: ') + err.message), 'error'); });
    },

    renderSettingsRow: function() {
        if (!this.settingsRow) return;
        L.dom.content(this.settingsRow, []);
        this.settingsRow.appendChild(E('button', { 'class': 'btn cbi-button-neutral' + (this.settingsActive === 'routing' ? ' active' : ''), 'click': ui.createHandlerFn(this, 'toggleRoutingPanel') }, _('Локальная маршрутизация')));
        this.settingsRow.appendChild(E('button', { 'class': 'btn cbi-button-neutral' + (this.settingsActive === 'dns' ? ' active' : ''), 'click': ui.createHandlerFn(this, 'toggleDnsPanel') }, _('DNS')));
    },

    toggleRoutingPanel: function() {
        if (!this.routingPanel) return;
        var wasOpen = this.routingPanel.style.display !== 'none';
        this.routingPanel.style.display = wasOpen ? 'none' : 'block';
        if (wasOpen) {
            if (this.settingsActive === 'routing') this.settingsActive = null;
            this.renderSettingsRow();
            return;
        }
        if (this.dnsPanel) this.dnsPanel.style.display = 'none';
        if (this.dnsModeRow) this.dnsModeRow.style.display = 'none';
        this.settingsActive = 'routing';
        this.renderSettingsRow();
        this.refreshRouting();
    },

    toggleSettingsRow: function() {
        if (!this.settingsRow) return;
        var open = this.settingsRow.style.display !== 'none';
        this.settingsRow.style.display = open ? 'none' : 'flex';
        if (open) {
            if (this.routingPanel) this.routingPanel.style.display = 'none';
            if (this.dnsModeRow) this.dnsModeRow.style.display = 'none';
            if (this.dnsPanel) this.dnsPanel.style.display = 'none';
            this.settingsActive = null;
            this.renderSettingsRow();
        }
    },

    toggleDnsPanel: function() {
        if (!this.dnsPanel) return;
        var wasOpen = this.dnsPanel.style.display !== 'none';
        this.dnsPanel.style.display = wasOpen ? 'none' : 'block';
        if (wasOpen) {
            if (this.dnsModeRow) this.dnsModeRow.style.display = 'none';
            if (this.settingsActive === 'dns') this.settingsActive = null;
            this.renderSettingsRow();
        } else {
            if (this.routingPanel) this.routingPanel.style.display = 'none';
            this.renderDnsModeRow();
            if (this.dnsModeRow) this.dnsModeRow.style.display = 'flex';
            this.settingsActive = 'dns';
            this.renderSettingsRow();
            this.refreshDns();
        }
    },

    mkSegRow: function(items, current, onclick) {
        var row = E('div', { 'class': 'mihomo-seg' });
        items.forEach(function(it) {
            row.appendChild(E('button', { 'class': 'btn cbi-button-neutral' + (it.value === current ? ' active' : ''), 'click': function() { onclick(it.value); } }, it.label));
        });
        return row;
    },

    refreshDns: function() {
        var self = this;
        return callDnsStatus().then(function(res) {
            if (!res || res.ok !== true) { self.showRoutingError(res || { ok: false, error: _('Не удалось получить состояние DNS') }); return; }
            self.dnsData = res;
            var servers = res.servers || [];
            var custom = res.custom || [];
            var checks = {};
            DNS_PRESETS.forEach(function(p) { checks[p.name] = p.values.every(function(v) { return servers.indexOf(v) !== -1; }); });
            custom.forEach(function(c) { checks[c.name] = servers.indexOf(c.value) !== -1; });
            self.dnsChecks = checks;
            var i, nm, order = [];
            function nameForValue(v) {
                for (i = 0; i < DNS_PRESETS.length; i++) { if (DNS_PRESETS[i].values.indexOf(v) !== -1) return DNS_PRESETS[i].name; }
                for (i = 0; i < custom.length; i++) { if (custom[i].value === v) return custom[i].name; }
                return null;
            }
            servers.forEach(function(v) { nm = nameForValue(v); if (nm && order.indexOf(nm) === -1) order.push(nm); });
            DNS_PRESETS.forEach(function(p) { if (order.indexOf(p.name) === -1) order.push(p.name); });
            custom.forEach(function(c) { if (order.indexOf(c.name) === -1) order.push(c.name); });
            self.dnsOrder = order;
            var known = [];
            DNS_PRESETS.forEach(function(p) { known = known.concat(p.values); });
            custom.forEach(function(c) { known.push(c.value); });
            self.dnsForeign = [];
            servers.forEach(function(v) { if (known.indexOf(v) === -1 && self.dnsForeign.indexOf(v) === -1) self.dnsForeign.push(v); });
            self.dnsUsageMode = res.allServers ? 'parallel' : (res.strictOrder ? 'strict' : 'standard');
            self.dnsManualText = res.block || '';
            self.renderDnsModeRow();
            self.renderDnsPanel();
        }).catch(function(err) { ui.addNotification(null, E('p', _('Ошибка DNS: ') + err.message), 'error'); });
    },

    renderDnsPanel: function() {
        var panel = this.dnsPanel;
        if (!panel) return;
        while (panel.firstChild) panel.removeChild(panel.firstChild);
        panel.appendChild(E('h3', {}, _('DNS')));
        panel.appendChild(E('p', { style: 'opacity:.75; margin-top:0;' }, _('Настройка DNS-серверов через файл /etc/dnsmasq.conf. Изменения вступают в силу после нажатия «Применить».')));
        if (this.dnsMode === 'manual') {
            this.renderDnsManual(panel);
        } else {
            this.renderDnsSimple(panel);
        }
    },

    renderDnsModeRow: function() {
        if (!this.dnsModeRow) return;
        var self = this;
        L.dom.content(this.dnsModeRow, []);
        this.dnsModeRow.appendChild(this.mkSegRow([
            { value: 'simple', label: _('Простой режим') },
            { value: 'manual', label: _('Ручной режим') }
        ], this.dnsMode, function(v) { self.switchDnsMode(v); }));
    },

    switchDnsMode: function(v) {
        if (v === this.dnsMode) return;
        if (v === 'manual') {
            this.dnsManualText = (this.dnsData && this.dnsData.block) || '';
        }
        this.dnsMode = v;
        this.renderDnsModeRow();
        this.renderDnsPanel();
    },

    renderDnsSimple: function(panel) {
        var self = this;
        var checks = this.dnsChecks || {};
        var order = this.dnsOrder || [];
        var custom = (this.dnsData && this.dnsData.custom) || [];
        panel.appendChild(E('h4', { style: 'margin-top:0.5rem;' }, _('Режим использования DNS')));
        panel.appendChild(E('p', { style: 'opacity:.8;' }, 
            _('Строгий порядок — опрос по списку, переход к следующему при ошибке.<br>') +
            _('Стандартный — автоматический выбор самого быстрого сервера.<br>') +
            _('Параллельный — запрос ко всем серверам сразу, ответ от самого первого.')
        ));
        panel.appendChild(this.mkSegRow([
            { value: 'strict', label: _('Строгий порядок') },
            { value: 'standard', label: _('Стандартный') },
            { value: 'parallel', label: _('Параллельный') }
        ], this.dnsUsageMode, function(v) { self.dnsUsageMode = v; self.renderDnsPanel(); }));
        panel.appendChild(E('h4', { style: 'margin-top:0.5rem;' }, _('DNS-серверы')));
        order.forEach(function(name, idx) {
            var values = [], isCustom = false;
            DNS_PRESETS.forEach(function(p) { if (p.name === name) values = values.concat(p.values); });
            custom.forEach(function(c) { if (c.name === name) { isCustom = true; values.push(c.value); } });
            if (!values.length) return;
            var cb = E('input', { type: 'checkbox', click: function() { self.dnsChecks[name] = cb.checked; self.renderDnsPanel(); } });
            cb.checked = !!checks[name];
            var rowChildren = [
                E('div', { class: 'mihomo-route-actions', style: 'gap:.3rem;' }, [
                    E('button', { 'class': 'btn cbi-button-neutral', title: _('Вверх'), click: function() { self.moveDnsItem(idx, -1); } }, '↑'),
                    E('button', { 'class': 'btn cbi-button-neutral', title: _('Вниз'), click: function() { self.moveDnsItem(idx, 1); } }, '↓')
                ]),
                E('label', { style: 'display:flex; align-items:center; gap:.4rem;' }, [
                    cb, E('span', {}, name), E('span', { style: 'opacity:.6;' }, values.join(' , '))
                ])
            ];
            if (isCustom) {
                rowChildren.push(E('button', { 'class': 'btn cbi-button-reset', click: function() {
                    callDnsRemovePreset(name).then(function(res) { if (self.showRoutingError(res)) self.refreshDns(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                }}, _('Удалить')));
            }
            panel.appendChild(E('div', { class: 'mihomo-route-add' }, rowChildren));
        });
        var foreign = this.dnsForeign || [];
        if (foreign.length) {
            panel.appendChild(E('p', { style: 'color:#F62B12; margin-top:.6rem;' }, _('В конфигурации есть строки server= вне пресетов: ') + foreign.join(', ') + '. ' + _('При применении они будут удалены.')));
        }
        var nameIn = E('input', { type: 'text', placeholder: _('Название'), style: 'min-width:12rem;' });
        var valIn = E('input', { type: 'text', placeholder: '8.8.8.8', style: 'min-width:12rem;' });
        panel.appendChild(E('div', { class: 'mihomo-route-add', style: 'margin-top:.6rem;' }, [
            nameIn, valIn,
            E('button', { 'class': 'btn cbi-button-positive btn-save-custom', click: function() {
                var nm = nameIn.value.trim();
                if (!nm) { ui.addNotification(null, E('p', _('Введите название')), 'error'); return; }
                var dup = DNS_PRESETS.some(function(p) { return p.name === nm; });
                if (dup) { ui.addNotification(null, E('p', _('Такое название уже есть среди пресетов')), 'error'); return; }
                if (!isValidDnsValue(valIn.value.trim())) { ui.addNotification(null, E('p', _('Некорректный DNS: укажите IPv4 с октетами не длиннее 3 цифр (например 8.8.8.8 или 127.0.0.1#7880)')), 'error'); return; }
                callDnsAddPreset(nm, valIn.value.trim()).then(function(res) {
                    if (self.showRoutingError(res)) self.refreshDns();
                }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
            }}, _('Добавить'))
        ]));
        var cleanCb = E('input', { type: 'checkbox', click: function() { self.dnsClean = cleanCb.checked; self.renderDnsPanel(); } });
        cleanCb.checked = !!this.dnsClean;
        panel.appendChild(E('label', { style: 'display:block; margin:.8rem 0 .4rem;' }, [cleanCb, ' ', _('Очистить /etc/dnsmasq.conf перед применением')]));
        panel.appendChild(E('div', { style: 'margin-top:.8rem;' }, [
            E('button', { 'class': 'btn cbi-button-positive btn-save-custom', click: function() { self.applySimpleDns(); } }, _('Применить'))
        ]));
    },

    moveDnsItem: function(idx, dir) {
        var order = this.dnsOrder;
        var j = idx + dir;
        if (j < 0 || j >= order.length) return;
        var tmp = order[idx]; order[idx] = order[j]; order[j] = tmp;
        this.renderDnsPanel();
    },

    applySimpleDns: function() {
        var self = this;
        var checks = this.dnsChecks || {};
        var custom = (this.dnsData && this.dnsData.custom) || [];
        var order = this.dnsOrder || [];
        var selected = 0;
        var lines = ['no-resolv'];
        if (this.dnsUsageMode === 'parallel') lines.push('all-servers');
        else if (this.dnsUsageMode === 'strict') lines.push('strict-order');
        order.forEach(function(name) {
            if (!checks[name]) return;
            selected++;
            var values = [];
            DNS_PRESETS.forEach(function(p) { if (p.name === name) values = values.concat(p.values); });
            custom.forEach(function(c) { if (c.name === name) values.push(c.value); });
            values.forEach(function(v) { lines.push('server=' + v); });
        });
        if (selected === 0) {
            if (!confirm(_('Ничего не выбрано. Удалить все правила DNS из dnsmasq?'))) return;
            return callDnsClear().then(function(res) { if (self.showRoutingError(res)) self.refreshDns(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
        }
        var doApply = function() {
            ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Применение...'))]);
            callDnsApply(lines.join('\n'), !!self.dnsClean).then(function(res) {
                ui.hideModal();
                if (self.showRoutingError(res)) self.refreshDns();
            }).catch(function(err) { ui.hideModal(); self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
        };
        if (this.dnsClean) {
            ui.showModal(_('Подтверждение'), [
                E('p', {}, _('Файл /etc/dnsmasq.conf будет полностью очищен, останутся только ваши правила.')),
                E('div', { class: 'right', style: 'margin-top:1rem;' }, [
                    E('button', { class: 'btn cbi-button-neutral', click: ui.hideModal }, _('Отмена')), ' ',
                    E('button', { class: 'btn cbi-button-positive btn-save-custom', click: function() { ui.hideModal(); doApply(); } }, _('Продолжить'))
                ])
            ]);
        } else {
            doApply();
        }
    },

    renderDnsManual: function(panel) {
        var self = this;
        var ta = E('textarea', { 'class': 'mihomo-dns-text', style: 'width:100%; height:34em;' });
        panel.appendChild(E('p', { style: 'opacity:.8;' }, _('После применения заменяет все правила из «Простого режима» на ваши.')));
        ta.value = this.dnsManualText || '';
        panel.appendChild(ta);
        var cleanCb = E('input', { type: 'checkbox', click: function() { self.dnsClean = cleanCb.checked; } });
        cleanCb.checked = !!this.dnsClean;
        panel.appendChild(E('label', { style: 'display:block; margin:.8rem 0;' }, [cleanCb, ' ', _('Очистить /etc/dnsmasq.conf перед применением')]));
        panel.appendChild(E('div', { style: 'margin-top:.8rem; display:flex; gap:.5rem;' }, [
            E('button', { 'class': 'btn cbi-button-positive btn-save-custom', click: function() {
                var doApply = function() {
                    ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Применение...'))]);
                    callDnsApply(ta.value, !!self.dnsClean).then(function(res) {
                        ui.hideModal();
                        if (self.showRoutingError(res)) { self.dnsManualText = ta.value; self.refreshDns(); }
                    }).catch(function(err) { ui.hideModal(); self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
                };
                if (self.dnsClean) {
                    ui.showModal(_('Подтверждение'), [
                        E('p', {}, _('Файл /etc/dnsmasq.conf будет полностью очищен, останутся только ваши правила.')),
                        E('div', { class: 'right', style: 'margin-top:1rem;' }, [
                            E('button', { class: 'btn cbi-button-neutral', click: ui.hideModal }, _('Отмена')), ' ',
                            E('button', { class: 'btn cbi-button-positive btn-save-custom', click: function() { ui.hideModal(); doApply(); } }, _('Продолжить'))
                        ])
                    ]);
                } else {
                    doApply();
                }
            }}, _('Применить')),
            E('button', { 'class': 'btn cbi-button-reset', click: function() {
                if (!confirm(_('Удалить правила DNS Mixomo из dnsmasq?'))) return;
                callDnsClear().then(function(res) { if (self.showRoutingError(res)) self.refreshDns(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
            }}, _('Удалить'))
        ]));
    },

    renderRoutingPanel: function() {
        var panel = this.routingPanel;
        if (!panel) return;
        var self = this, status = this.routingData || {}, clients = (this.clientData && this.clientData.clients) || [];
        while (panel.firstChild) panel.removeChild(panel.firstChild);
        var routerEnabled = (status.router === true || status.router === 1 || status.router === '1');
        var routerToggle = E('input', { type: 'checkbox', click: function(ev) {
            ev.preventDefault();
            self.confirmRouterRouting(!routerEnabled);
        }});
        routerToggle.checked = routerEnabled;
        var udp443Enabled = (status.udp443 === true || status.udp443 === 1 || status.udp443 === '1');
        var udp443Toggle = E('input', { type: 'checkbox', click: function() { self.setUdp443(udp443Toggle.checked); } });
        udp443Toggle.checked = udp443Enabled;
        var redirAvail = !!(status.redirAvailable === true || status.redirAvailable === 1 || status.redirAvailable === '1');
        var defaultBackend = (status.variant === 'redir-tproxy') ? 'redir-tproxy' : 'tun-socks5';
        function mkBackend(def) {
            var opts = [];
            if (redirAvail) opts.push(E('option', { value: 'redir-tproxy' }, 'Redir-TProxy'));
            opts.push(E('option', { value: 'tun-socks5' }, 'Tun-Socks5'));
            var s = E('select', { style: 'min-width:8rem;' }, opts);
            s.value = def;
            return s;
        }
        var backendSel = mkBackend(defaultBackend);
        var backendSel2 = mkBackend(defaultBackend);
        panel.appendChild(E('h3', {}, _('Локальная маршрутизация')));
        panel.appendChild(E('p', { style: 'opacity:.75; margin-top:0;' }, [
        _('При использовании абсолютно весь трафик направляется через Mihomo.'),
        E('br'),
        _('Добавлять устройства и подсети можно только из локальных диапазонов.'),
        E('br'),
        _('Закрепить локальные IP за конкретными устройствами можно в '),
        E('a', { href: L.url('admin/network/dhcp'), target: '_blank' }, _('Статических арендах DHCP'))]));

        var deviceLabel = E('input', { type: 'text', placeholder: _('Название (необязательно)'), style: 'min-width:12rem;' });
        var known = E('select', { style: 'min-width:15rem;' }, [E('option', { value: '' }, _('Выберите устройство...'))].concat(clients.map(function(c) {
            return E('option', { value: c.ip }, (c.name ? c.name + ' — ' : '') + c.ip);
        })));
        panel.appendChild(E('div', { class: 'mihomo-route-add' }, [known, deviceLabel, backendSel, E('button', { class: 'btn cbi-button-positive btn-save-custom', click: function() {
            if (!known.value) { ui.addNotification(null, E('p', _('Сначала выберите устройство')), 'error'); return; }
            var selected = clients.filter(function(c) { return c.ip === known.value; })[0];
            var label = deviceLabel.value.trim() || (selected && selected.name) || '';
            callRoutingAdd(known.value, label, backendSel.value).then(function(res) { if (self.showRoutingError(res)) { known.value = ''; deviceLabel.value = ''; self.refreshRouting(); } });
        }}, _('Добавить правило'))]));
        var source = E('input', { type: 'text', placeholder: 'IP или CIDR', style: 'min-width:15rem;' });
        var manualLabel = E('input', { type: 'text', placeholder: _('Название (необязательно)'), style: 'min-width:12rem;' });
        panel.appendChild(E('div', { style: 'opacity:.75; margin-top:.35rem; margin-bottom:.35rem;' }, _('Или')));
        panel.appendChild(E('div', { class: 'mihomo-route-add' }, [source, manualLabel, backendSel2, E('button', { class: 'btn cbi-button-positive btn-save-custom', click: function() {
            callRoutingAdd(source.value.trim(), manualLabel.value.trim(), backendSel2.value).then(function(res) { if (self.showRoutingError(res)) { source.value = ''; manualLabel.value = ''; self.refreshRouting(); } });
        }}, _('Добавить правило'))]));

        var dragSource = null;
        function makeDraggable(grip, tr, type, arr, idx) {
            grip.setAttribute('draggable', 'true');
            grip.style.cursor = 'move';
            grip.addEventListener('dragstart', function(ev) { dragSource = idx; try { ev.dataTransfer.effectAllowed = 'move'; } catch(e) {} });
            tr.addEventListener('dragover', function(ev) { if (ev.preventDefault) ev.preventDefault(); });
            tr.addEventListener('drop', function(ev) {
                ev.preventDefault();
                if (dragSource === null || dragSource === idx || dragSource < 0 || dragSource >= arr.length) return;
                var item = arr.splice(dragSource, 1)[0];
                arr.splice(idx, 0, item);
                self.handleReorder(type, arr.map(function(r) { return r.id; }));
            });
            tr.addEventListener('dragend', function() { dragSource = null; });
        }

        var rules = (status.rules || []).slice().sort(function(a, b) { return (a.priority || 0) - (b.priority || 0); });
        if (!rules.length) panel.appendChild(E('p', { style: 'opacity:.75; margin-top:.35rem; margin-bottom:1.35rem;' }, [
            _('Правил пока нет.')
        ]));
        else {
            var table = E('table', { class: 'table mihomo-routing-table', style: 'width:100%; margin-top:.8rem;' }, [E('thead', {}, E('tr', {}, [E('th', { class: 'mihomo-grip' }, ''), E('th', {}, _('Название')), E('th', {}, _('Адрес')), E('th', {}, _('Тип подключения')), E('th', {}, _('Статус')), E('th', {}, _('Действие'))]))]);
            var body = E('tbody'); rules.forEach(function(rule, idx) {
                var tr = E('tr', {}, [
                    E('td', { class: 'mihomo-grip' }, E('span', { class: 'mihomo-grip-handle' }, '≡')),
                    E('td', {}, rule.label || '—'),
                    E('td', {}, displaySource(rule.source)),
                    E('td', {}, backendLabel(rule.backend || 'tun-socks5')),
                    E('td', {}, rule.enabled ? _('Включено') : _('Отключено')),
                    E('td', {}, E('div', { class: 'mihomo-route-actions' }, [
                        E('button', { class: 'btn cbi-button-neutral', title: _('Вверх'), click: function() { self.moveItem('rule', rules, idx, -1); } }, '↑'),
                        E('button', { class: 'btn cbi-button-neutral', title: _('Вниз'), click: function() { self.moveItem('rule', rules, idx, 1); } }, '↓'),
                        E('button', { class: 'btn cbi-button-neutral', click: function() { self.editRoutingRule(rule); } }, _('Редактировать')),
                        E('button', { class: 'btn cbi-button-neutral', click: function() { callRoutingEnabled(rule.id, !rule.enabled).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); }); } }, rule.enabled ? _('Отключить') : _('Включить')),
                        E('button', { class: 'btn cbi-button-reset', click: function() { if (confirm(_('Удалить это правило?'))) callRoutingDelete(rule.id).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); }); } }, _('Удалить'))
                    ]))
                ]);
                makeDraggable(tr.firstChild, tr, 'rule', rules, idx);
                body.appendChild(tr);
            });
            table.appendChild(body); panel.appendChild(table);
        }

        panel.appendChild(E('h3', { style: 'margin-top:1rem;' }, _('Исключённые адреса')));
        panel.appendChild(E('p', { style: 'opacity:.75; margin-top:0;' }, [
            _('Трафик к этим адресам никогда не направляется через Mihomo.'),
            E('br'),
            _('По умолчанию добавлены следующие подсети, без возможности их удалить:'),
            E('br'),
            _('127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10, 169.254.0.0/16, 224.0.0.0/4, 255.255.255.255/32')
        ]));
        var exDest = E('input', { type: 'text', placeholder: 'IP или CIDR', style: 'min-width:12rem;' });
        var exDest = E('input', { type: 'text', placeholder: 'IP или CIDR', style: 'min-width:12rem;' });
        var exLabel = E('input', { type: 'text', placeholder: _('Название (необязательно)'), style: 'min-width:12rem;' });
        panel.appendChild(E('div', { class: 'mihomo-route-add' }, [exDest, exLabel, E('button', { class: 'btn cbi-button-positive btn-save-custom', click: function() {
            callRoutingExcludeAdd(exDest.value.trim(), exLabel.value.trim()).then(function(res) { if (self.showRoutingError(res)) { exDest.value = ''; exLabel.value = ''; self.refreshRouting(); } }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); });
        }}, _('Добавить правило'))]));
        var exclusions = (status.exclusions || []).slice().sort(function(a, b) { return (a.priority || 0) - (b.priority || 0); });
        if (!exclusions.length) {
            panel.appendChild(E('p', { style: 'opacity:.75; margin-top:.35rem;' }, _('Правил пока нет.')));
        } else {
            var t2 = E('table', { class: 'table mihomo-routing-table', style: 'width:100%; margin-top:.6rem;' }, [E('thead', {}, E('tr', {}, [E('th', { class: 'mihomo-grip' }, ''), E('th', {}, _('Название')), E('th', {}, _('Адрес')), E('th', {}, _('Статус')), E('th', {}, _('Действие'))]))]);
            var b2 = E('tbody'); exclusions.forEach(function(ex, idx) {
                var tr2 = E('tr', {}, [
                    E('td', { class: 'mihomo-grip' }, E('span', { class: 'mihomo-grip-handle' }, '≡')),
                    E('td', {}, ex.label || '—'),
                    E('td', {}, displaySource(ex.dest)),
                    E('td', {}, ex.enabled ? _('Включено') : _('Отключено')),
                    E('td', {}, E('div', { class: 'mihomo-route-actions' }, [
                        E('button', { class: 'btn cbi-button-neutral', title: _('Вверх'), click: function() { self.moveItem('exclude', exclusions, idx, -1); } }, '↑'),
                        E('button', { class: 'btn cbi-button-neutral', title: _('Вниз'), click: function() { self.moveItem('exclude', exclusions, idx, 1); } }, '↓'),
                        E('button', { class: 'btn cbi-button-neutral', click: function() { self.editExclusion(ex); } }, _('Редактировать')),
                        E('button', { class: 'btn cbi-button-neutral', click: function() { callRoutingExcludeEnabled(ex.id, !ex.enabled).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); }); } }, ex.enabled ? _('Отключить') : _('Включить')),
                        E('button', { class: 'btn cbi-button-reset', click: function() { if (confirm(_('Удалить этот адрес?'))) callRoutingExcludeDelete(ex.id).then(function(res) { if (self.showRoutingError(res)) self.refreshRouting(); }).catch(function(err) { self.showRoutingError({ ok: false, error: (err && err.message) || _('Ошибка RPC') }); }); } }, _('Удалить'))
                    ]))
                ]);
                makeDraggable(tr2.firstChild, tr2, 'exclude', exclusions, idx);
                b2.appendChild(tr2);
            });
            t2.appendChild(b2); panel.appendChild(t2);
        }
        panel.appendChild(E('h3', { style: 'margin-top:1rem;' }, _('Особые правила')));
        panel.appendChild(E('p', { style: 'opacity:.75; margin-top:0;' }, _('Применяется только к исходящим соединениям этого устройства — apk update, opkg update, wget, curl и тому подобное.')));
        panel.appendChild(E('label', { style: 'display:block; margin:.4rem 0;' }, [routerToggle, ' ', _('Направлять исходящий трафик этого устройства через Mihomo')]));
        panel.appendChild(E('p', { style: 'opacity:.75; margin-top:0;' }, _('Все устройства переходят на TCP вместо UDP (QUIC) на 443 порту, что упрощает маршрутизацию в Mihomo.')));
        panel.appendChild(E('label', { style: 'display:block; margin:.4rem 0;' }, [udp443Toggle, ' ', _('Блокировать QUIC (UDP/443)')]));
    },
	
    getMihomoVersion: function() {
        return fs.stat('/usr/bin/mihomo')
            .then(function() { return fs.exec('/usr/bin/mihomo', ['--v']); })
            .then(function(res) {
                if (res.code === 0 && res.stdout) {
                    var match = res.stdout.match(/v(\d+\.\d+\.\d+)/);
                    return match ? match[0] : 'Неизвестно';
                }
                return 'Неизвестно';
            })
            .catch(function(err) {
                console.error('Error getting version:', err);
                return 'Неизвестно';
            });
    },

    renderUpdateStatus: function(latestVersion, isManual) {
        var currentVersion = this.currentVersion || 'Неизвестно';
        this.latestVersion = latestVersion;

        var cleanCurrent = currentVersion.replace('v', '');
        var cleanLatest = latestVersion.replace('v', '');

        if (this.latestVersionEl) {
            this.latestVersionEl.style.display = 'inline';
            
            if (cleanLatest === cleanCurrent) {
                this.latestVersionEl.style.color = ''; 
                this.latestVersionEl.style.opacity = '0.6';
                this.latestVersionEl.style.fontWeight = 'normal';
            } else {
                this.latestVersionEl.textContent = _('(доступна новая версия %s)').format(cleanLatest);
                this.latestVersionEl.style.color = '#5cb85c';
                this.latestVersionEl.style.opacity = '1';
            }
        }

        if (latestVersion === currentVersion) {
            this.updateButton.textContent = _('Проверить обновление');
            this.updateButton.className = 'btn cbi-button-neutral';
            this.updateButton.disabled = false;
            var self = this;
            this.updateButton.onclick = function() { self.checkForUpdates(true); };
            if (isManual) {
                ui.addNotification(null, E('p', _('У вас установлена самая актуальная версия')), 'info');
            }
        } else {
            this.updateButton.textContent = _('Установить обновление');
            this.updateButton.className = 'btn cbi-button-action';
            this.updateButton.disabled = false;
            this.updateButton.onclick = ui.createHandlerFn(this, 'handleUpdateMihomo');
        }
    },
	
	checkForUpdates: function(isManual) {
		var self = this;
        var CACHE_KEY = 'mihomo_update_cache';
        var CACHE_TIME = 3600 * 1000;

        if (!isManual) {
            try {
                var cachedRaw = localStorage.getItem(CACHE_KEY);
                if (cachedRaw) {
                    var cached = JSON.parse(cachedRaw);
                    if (cached.version && (Date.now() - cached.timestamp < CACHE_TIME)) {
                        this.renderUpdateStatus(cached.version, false);
                        return;
                    }
                }
            } catch (e) {}
        }
		
		if (isManual) ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Проверка обновлений...'))]);
		
		var cmd = 'wget -q -O - "https://api.github.com/repos/MetaCubeX/mihomo/releases/latest" 2>/dev/null | grep -m1 \'"tag_name":\' | sed \'s/.*"\\(v[0-9.]*\\)".*/\\1/\'';
		
		fs.exec('/bin/sh', ['-c', cmd])
			.then(function(res) {
				if (isManual) ui.hideModal();
				if (!res || typeof res !== 'object') throw new Error('Bad response');
				var latestVersion = (res.stdout || '').trim().replace(/["'\s]/g, '');
				if (!latestVersion || !latestVersion.match(/^v\d+\.\d+\.\d+$/)) {
				    if (isManual) ui.addNotification(null, E('p', _('Ошибка: ') + latestVersion), 'error');
				    return;
				}
                try { localStorage.setItem(CACHE_KEY, JSON.stringify({ version: latestVersion, timestamp: Date.now() })); } catch (e) {}
				self.renderUpdateStatus(latestVersion, isManual);
			})
			.catch(function(err) {
				if (isManual) {
				    ui.hideModal();
				    ui.addNotification(null, E('p', _('Ошибка: ') + err.message), 'error');
				}
			});
	},
	
	handleUpdateMihomo: function() {
		var self = this;
		var latestVersion = this.latestVersion;
		if (!latestVersion) return;
		this.updateButton.textContent = _('Подождите...');
		this.updateButton.disabled = true;
		var arch = 'arm64';
		var downloadUrl = 'https://github.com/MetaCubeX/mihomo/releases/download/' + latestVersion + '/mihomo-linux-' + arch + '-' + latestVersion + '.gz';
		var steps = [
			{ msg: _('Создание бэкапа...'), shell: 'cp -f /usr/bin/mihomo /tmp/mihomo.backup' },
			{ msg: _('Остановка Mihomo...'), shell: '/etc/init.d/mihomo stop' },
			{ msg: _('Скачивание архива %s...').format(latestVersion), shell: 'wget -q -O /tmp/mihomo.gz "' + downloadUrl + '" && test -s /tmp/mihomo.gz' },
			{ msg: _('Распаковка архива...'), shell: '/bin/gzip -d -c /tmp/mihomo.gz > /tmp/mihomo_new 2>/dev/null && test -s /tmp/mihomo_new' },
			{ msg: _('Выдача временных прав...'), shell: '/bin/chmod 755 /tmp/mihomo_new' },
			{ msg: _('Проверка ядра...'), shell: '/tmp/mihomo_new -v 2>&1 || true' },
			{ msg: _('Установка ядра...'), shell: '/bin/mv -f /tmp/mihomo_new /usr/bin/mihomo' },
			{ msg: _('Выдача постоянных прав...'), shell: '/bin/chmod 755 /usr/bin/mihomo' },
			{ msg: _('Запуск Mihomo...'), shell: '/etc/init.d/mihomo start' },
			{ msg: _('Удаление бэкапа...'), shell: 'rm -f /tmp/mihomo.gz /tmp/mihomo.backup' }
		];
		var executeStep = function(index) {
			if (index >= steps.length) {
				self.showOutput(_('Обновлено успешно! Перезагрузка...'), false);
				window.location.reload();
				return Promise.resolve();
			}
			var currentStep = steps[index];
			self.showOutput(currentStep.msg, false);
			return fs.exec('/bin/sh', ['-c', currentStep.shell])
				.then(function(res) {
					if (!res || res.code !== 0) throw new Error('Err: ' + (res ? res.code : 'unknown'));
					return executeStep(index + 1);
				});
		};
		executeStep(0).catch(function(err) {
            if (self.updateButton) {
                self.updateButton.textContent = _('Ошибка. Повторить обновление?');
                self.updateButton.disabled = false;
                self.updateButton.onclick = ui.createHandlerFn(self, 'handleUpdateMihomo');
            }
            self.showOutput(_('Ошибка: %s').format(err.message), true);
            fs.exec('/bin/sh', ['-c', 'cp -f /tmp/mihomo.backup /usr/bin/mihomo && /etc/init.d/mihomo start']).catch(function() {});
        });
	},

	load: function() {
		return Promise.all([
			fs.read(MAIN_CONFIG).catch(function() { return ''; }),
			callServiceList('mihomo').catch(function() { return {}; }),
			fs.list(RULE_DIR).catch(function() { return []; })
		]);
	},
	
    render: function(data) {
		data = data || [];
        mainConfigContent = data[0] || '';
        var serviceInfo = data[1] || {};
        cachedRuleFiles = (data[2] || []).sort(function(a, b) { return a.name.localeCompare(b.name); });
        var isRunning = !!(serviceInfo.mihomo && serviceInfo.mihomo.instances.main.running);
        
        var versionContainer = E('span', { 'id': 'mihomo-version', 'style': 'margin-left: 12px; font-size: 0.9em; opacity: 0.7;' }, _('Загрузка...'));
        var latestVersionEl = E('span', { 'id': 'mihomo-latest-version', 'style': 'margin-left: 4px; font-size: 0.9em; opacity: 0.7; display: none;' }, '');
        this.latestVersionEl = latestVersionEl;
        var updateButton = E('button', { 'id': 'mihomo-update-btn', 'class': 'btn cbi-button-neutral', 'style': 'margin-left: 10px; padding: 0 0.6em; font-size: 0.9em;', 'disabled': true }, _('Проверить обновление'));
        this.updateButton = updateButton;
        var settingsButton = E('button', { 'class': 'btn cbi-button-neutral', 'style': 'margin-left: 10px;', 'click': ui.createHandlerFn(this, 'toggleSettingsRow') }, _('Настройки'));
        
        var statusBadge = isRunning 
            ? E('span', { 
                'class': 'label success', 
                'style': 'margin-left: 14px; font-size: 0.85em; min-height: 1.7rem; padding: 0 1.9em; display: inline-flex; align-items: center; vertical-align: middle;' 
            }, _('работает'))
            : E('span', { 
                'class': 'label', 
                'style': 'margin-left: 14px; font-size: 0.85em; min-height: 1.7rem; padding: 0 1.9em; display: inline-flex; align-items: center; vertical-align: middle;' 
            }, _('остановлен'));
        
        var serviceButton = isRunning
            ? E('button', { 'class': 'btn cbi-button-reset', 'style': 'margin-left: 16px;', 'click': ui.createHandlerFn(this, 'handleServiceAction', 'stop') }, _('Остановить'))
            : E('button', { 'class': 'btn cbi-button-positive btn-save-custom', 'style': 'margin-left: 16px;', 'click': ui.createHandlerFn(this, 'handleServiceAction', 'start') }, _('Запустить'));
        
        var header = E('div', { 'style': 'display: flex; align-items: center; margin-bottom: 1rem; flex-wrap: wrap;' }, [
            E('h2', { 'style': 'margin: 0;' }, _('Mihomo')), 
            statusBadge, 
            serviceButton, 
            versionContainer, 
            latestVersionEl,
            updateButton,
            settingsButton
        ]);
		
        var self = this;
        this.getMihomoVersion().then(function(version) {
            self.currentVersion = version;
            var versionEl = document.getElementById('mihomo-version');
            if (versionEl) versionEl.textContent = version.startsWith('v') ? version : 'v' + version;
            var updateBtn = document.getElementById('mihomo-update-btn');
            if (updateBtn) {
                updateBtn.disabled = false;
                updateBtn.onclick = function() { self.checkForUpdates(true); }; 
            }
            self.checkForUpdates(false);
        });
        
        var isDark = isLuciDarkMode();
        var cssVariables = isDark ? `
            :root {
                --bg-tab: #2d2d2d;
                --bg-tab-active: #1C1C1C;
                --bg-toolbar: #1C1C1C;
                --bg-input: #2d2d2d;
                --text-main: #e0e0e0;
                --text-dim: #969696;
                --border-color: #444444;
                --border-active: #444444;
                --bg-output: #222222;
                --bg-output-header: #333333;
                --text-output: #f8f8f2;
            }
        ` : `
            :root {
                --bg-tab: #e0e0e0;
                --bg-tab-active: #ffffff;
                --bg-toolbar: #f5f5f5;
                --bg-input: #ffffff;
                --text-main: #333333;
                --text-dim: #666666;
                --border-color: #E0E0E0;
                --border-active: #E0E0E0;
                --bg-output: #ffffff;
                --bg-output-header: #eeeeee;
                --text-output: #333333;
            }
        `;

        var style = E('style', {}, cssVariables + `
            .btn, .cbi-button {
                min-height: 1.8rem !important; 
                display: inline-flex !important;
                align-items: center;
                justify-content: center;
                vertical-align: middle;
                box-sizing: border-box !important;
                padding: 0 1rem !important;
                line-height: 1 !important;
            }
            #output-text {
                font-size: 0.8rem !important;
            }
            .cbi-page-actions { display: none !important; }
            .custom-actions { display: flex; gap: 0.5rem; }
            .tab-bar { display: flex; flex-wrap: nowrap; background-color: var(--bg-tab); }
            .tab-item { display: flex; align-items: center; padding: 0.6em 1.2em; cursor: pointer; background-color: var(--bg-tab); color: var(--text-dim); margin-right: 1px; font-size: 0.9em; border-top: 1px solid transparent; white-space: nowrap; user-select: none; box-sizing: border-box }
            .tab-item:hover { background-color: var(--bg-toolbar); color: var(--text-main); }
            .tab-item.active { background-color: var(--bg-tab-active); color: var(--text-main); border: 1px solid var(--border-active); }
            .tab-close { margin-left: 0.6em; border-radius: 3px; padding: 0 0.3em; color: #999; font-weight: bold; }
            .tab-close:hover { background-color: #c0392b; color: white; }
            .tab-new { font-weight: bold; font-size: 1.2em; padding: 0.5em 0.8em; }
            .toolbar { background-color: var(--bg-toolbar); border: 1px solid var(--border-color); padding: 0.8rem; color: var(--text-main); }
            .toolbar-row { display: flex; gap: 0.8rem; align-items: center; }
            .toolbar textarea { width: 100%; height: 6em; background: var(--bg-input); color: var(--text-main); border: 1px solid var(--border-color); font-family: monospace; font-size: 0.9em; padding: 0.4em; }
            .toolbar select { background: var(--bg-input); color: var(--text-main); border: 1px solid var(--border-color); padding: 0.4em; }
            .toolbar-col { display: flex; flex-direction: column; }
            .btn-save-custom { border-color: #5cb85c !important; color: #5cb85c !important; }
            .btn-save-custom:hover { border-color: #5cb85c !important; }
            .btn.cbi-button-action:hover { border-color: #5cb85c !important; }
            .btn.cbi-button-reset:hover { border-color: #F62B12 !important; color: #F62B12 !important; }
            .btn-generate { border-color: #5cb85c !important; color: #5cb85c !important; margin: auto 0; display: block; background: var(--bg-input); }
            .btn-generate:hover { border-color: #5cb85c !important; }
            .snippet-container { margin-top: 0; border: 1px solid var(--border-color); background: var(--bg-toolbar); padding: 0.8rem; display: none; }
            .mihomo-routing-panel { border: 1px solid var(--border-color); background: var(--bg-toolbar); padding: 1rem; margin: 0 0 1rem; }
            .mihomo-settings-row { display: flex; flex-wrap: wrap; gap: 0.5rem; align-items: center; }
            .mihomo-dns-panel { border: 1px solid var(--border-color); background: var(--bg-toolbar); padding: 1rem; margin: 0 0 1rem; }
            .mihomo-seg { display: flex; flex-wrap: wrap; gap: 0.4rem; }
            .mihomo-seg .btn.active { border-color: #5cb85c !important; color: #5cb85c !important; }
            .mihomo-dns-mode-row { padding: 0.0rem 0; }
            .mihomo-dns-text { background: var(--bg-input); color: var(--text-main); border: 1px solid var(--border-color); font-family: monospace; font-size: 0.9em; padding: 0.6em; box-sizing: border-box; }
            .mihomo-dns-panel input[type=text] { background: var(--bg-input); color: var(--text-main); border: 1px solid var(--border-color); padding: .4em; }
            .mihomo-route-add { display: flex; flex-wrap: wrap; gap: .5rem; align-items: center; }
            .mihomo-route-actions { display: flex; gap: 1rem; padding: 0.2rem 0; }
            .mihomo-routing-panel input, .mihomo-routing-panel select { background: var(--bg-input); color: var(--text-main); border: 1px solid var(--border-color); padding: .4em; }
            .mihomo-routing-table th, .mihomo-routing-table td { text-align: left !important; }
            .mihomo-routing-table tbody tr:hover { background-color: rgba(125,125,125,0.15); }
            .mihomo-grip { width: 1.8rem; text-align: center; cursor: grab; user-select: none; color: var(--text-dim); }
            .mihomo-grip:active { cursor: grabbing; }
            .mihomo-grip-handle { display: inline-block; padding: 0 .4rem; border: 1px solid var(--border-color); border-radius: 4px; line-height: 1.3; }
            .mihomo-grip:hover .mihomo-grip-handle { background-color: rgba(125,125,125,0.2); color: var(--text-main); }
            .snippet-header { margin-bottom: 0.4rem; color: var(--text-main); font-size: 0.85em; }
            .snippet-text { width: 100%; height: 9.5em; background: var(--bg-tab-active); color: var(--text-main); border: 1px solid var(--border-color); font-family: monospace; font-size: 0.9em; padding: 0.8em; resize: none; }
            .output-box-close { background: transparent; border: none; color: var(--text-main); font-size: 1.5em; line-height: 1; cursor: pointer; margin-left: 1rem; padding: 0 0.4rem; }
            .output-box-close:hover { color: #e74c3c !important; }
			#ace_editor_container { width: 100%; height: 60vh; border: 1px solid var(--border-color); border-top: none; }
        `);
        
        var tabBar = E('div', { 'id': 'mihomo-tab-bar', 'class': 'tab-bar' });
        var toolbarContainer = E('div', { 'id': 'mihomo-toolbar' });
        var editorContainer = E('div', { 'id': 'ace_editor_container' });
        
        var snippetContainer = E('div', { 'id': 'snippet-box', 'class': 'snippet-container', 'style': 'margin-top: 0.8rem' }, [
            E('div', { 'class': 'snippet-header', 'style': 'opacity: 0.7' }, _('Чтобы Mihomo увидел файл, добавьте эту секцию в rule-providers:')),
            E('textarea', { 'id': 'snippet-area', 'class': 'snippet-text', 'readonly': 'readonly', 'style': 'opacity: 0.8' }),
            E('div', { 'style': 'margin-top: 0.8rem; display: flex; gap: 0.6rem;' }, [
                E('button', { 'class': 'btn cbi-button-apply', 'click': ui.createHandlerFn(this, 'handleAutoAddSnippet') }, _('Добавить автоматически')),
                E('button', { 'class': 'btn cbi-button-neutral', 'click': ui.createHandlerFn(this, 'handleCopySnippet') }, _('Скопировать текст'))
            ])
        ]);
        
        var buttonContainer = E('div', { 'id': 'bottom-buttons', 'class': 'custom-actions', 'style': 'margin-top: 1rem;' }, [
            E('button', { 'class': 'btn cbi-button-neutral', 'click': ui.createHandlerFn(this, 'handleCheck') }, _('Проверить конфигурацию')),
            E('button', { 'class': 'btn cbi-button-positive btn-save-custom', 'click': ui.createHandlerFn(this, 'handleSaveAndApply', isRunning) }, _('Сохранить')),
            E('button', { 'class': 'btn cbi-button-neutral', 'click': ui.createHandlerFn(this, 'handleOpenDashboard', mainConfigContent) }, _('Открыть панель управления')),
            E('button', { 'class': 'btn cbi-button-neutral', 'click': ui.createHandlerFn(this, 'handleShowLogs') }, _('Показать журнал'))
        ]);
        
        var middleActions = E('div', { 'id': 'middle-actions', 'style': 'display: none; margin-top: 0.8rem;' }, [
            E('button', { 'class': 'btn cbi-button-positive btn-save-custom', 'click': ui.createHandlerFn(this, 'handleSaveAndApply', isRunning) }, _('Сохранить'))
        ]);
        
        var outputBox = E('div', { 'id': 'output-box', 'style': 'display: none; margin-top: 1.2rem; border: 1px solid var(--border-color); border-radius: 4px; overflow: hidden;' }, [
            E('div', { 'style': 'background: var(--bg-output-header); color: var(--text-output); padding: 0.6rem 0.8rem; border-bottom: 1px solid var(--border-color); display: flex; align-items: center;' }, [
                E('strong', { 'style': 'font-size: 0.9em' }, _('Вывод:')),
                E('button', { 'class': 'output-box-close', 'click': function() { document.getElementById('output-box').style.display = 'none'; } }, '×')
            ]),
            E('pre', { 'id': 'output-text', 'style': 'margin: 0; padding: 1rem; background: var(--bg-output); color: var(--text-output); font-family: monospace; font-size: 1em; white-space: pre-wrap; word-wrap: break-word; max-height: 25rem; overflow-y: auto;' }, '')
        ]);

        var settingsRow = E('div', { 'class': 'mihomo-settings-row mihomo-seg', 'style': 'display:none; margin-bottom: 0.5rem;' });
        this.settingsRow = settingsRow;
        this.renderSettingsRow();

        var routingPanel = E('div', { 'class': 'mihomo-routing-panel', 'style': 'display:none;' });
        this.routingPanel = routingPanel;

        var dnsModeRow = E('div', { 'class': 'mihomo-seg mihomo-dns-mode-row', 'style': 'display:none; margin-bottom: 0.5rem;' });
        this.dnsModeRow = dnsModeRow;

        var dnsPanel = E('div', { 'class': 'mihomo-dns-panel', 'style': 'display:none;' });
        this.dnsPanel = dnsPanel;
        
        loadScript(ACE_DIR + 'ace.js').then(function() {
            ace.config.set('basePath', ACE_DIR);
            editor = ace.edit("ace_editor_container");
            var theme = isDark ? "ace/theme/merbivore_soft" : "ace/theme/tomorrow";
            editor.setTheme(theme);
            editor.session.setMode("ace/mode/yaml");
            editor.setOptions({ 
				fontSize: "0.95em", 
				showPrintMargin: false, 
				wrap: true, 
				tabSize: 2, 
				useSoftTabs: true,
				highlightActiveLine: false
			});
            editor.setValue(mainConfigContent, -1);
            setTimeout(function() { editor.resize(); }, 100);
        }).catch(console.error);
        
        this.renderTabBar(tabBar);
        this.renderToolbar(toolbarContainer, MAIN_CONFIG);
        setTimeout(function() { this.updateVisibility(MAIN_CONFIG); }.bind(this), 100);
        
        return E('div', { 'class': 'cbi-map' }, [
            header, settingsRow, dnsModeRow, routingPanel, dnsPanel, style, tabBar, toolbarContainer, editorContainer,
            middleActions, snippetContainer, buttonContainer, outputBox
        ]);
    },
    
    updateVisibility: function(filePath) {
        var isMain = (filePath === MAIN_CONFIG);
        document.getElementById('bottom-buttons').style.display = isMain ? 'flex' : 'none';
        document.getElementById('middle-actions').style.display = isMain ? 'none' : 'block';
        var snippetBox = document.getElementById('snippet-box');
        if (isMain) {
            snippetBox.style.display = 'none';
        } else {
            var baseName = filePath.split('/').pop().replace(/\.(yaml|txt)$/, '');
            var providerName = baseName + '-list:';
            if (mainConfigContent.includes(providerName)) {
                snippetBox.style.display = 'none';
            } else {
                document.getElementById('snippet-area').value = generateProviderSnippet(filePath);
                snippetBox.style.display = 'block';
            }
        }
    },
    
	handleAutoAddSnippet: function() {
		var self = this;
		var snippet = generateProviderSnippet(currentFile);
		if (!snippet) return;
		ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Добавление...'))]);
		var indentedSnippet = snippet.split('\n').map(function(line) { return '  ' + line; }).join('\n');
		fs.read(MAIN_CONFIG).then(function(content) {
			var newContent = content || '';
			var sectionMatch = newContent.match(/^rule-providers:\s*$/m);
			if (!sectionMatch) {
				var proxiesMatch = newContent.match(/^proxies:\s*$/m);
				var pgMatch = newContent.match(/^proxy-groups:\s*$/m);
				var lastIdx = Math.max(proxiesMatch ? proxiesMatch.index + proxiesMatch[0].length : -1, pgMatch ? pgMatch.index + pgMatch[0].length : -1);
				if (lastIdx > -1) {
					var textAfter = newContent.substring(lastIdx);
					var nextMatch = textAfter.match(/\n(?![ \t])[a-z][^:\n]*:/i);
					if (nextMatch) {
						var insIdx = lastIdx + nextMatch.index;
						newContent = newContent.substring(0, insIdx) + '\nrule-providers:\n\n' + indentedSnippet + '\n' + newContent.substring(insIdx);
					} else {
						newContent = newContent.trimEnd() + '\n\nrule-providers:\n\n' + indentedSnippet + '\n';
					}
				} else {
					if (newContent && !newContent.endsWith('\n')) newContent += '\n';
					newContent += '\nrule-providers:\n\n' + indentedSnippet + '\n';
				}
			} else {
				var secEnd = sectionMatch.index + sectionMatch[0].length;
				var textAfter = newContent.substring(secEnd);
				var nextMatch = textAfter.match(/\n(?![ \t])[a-z][^:\n]*:/i);
				if (nextMatch) {
					var insIdx = secEnd + nextMatch.index;
					newContent = newContent.substring(0, insIdx) + '\n' + indentedSnippet + '\n' + newContent.substring(insIdx);
				} else {
					newContent = newContent.substring(0, secEnd).replace(/\n+$/, '\n') + '\n' + indentedSnippet + '\n';
				}
			}
			mainConfigContent = newContent;
			return fs.write(MAIN_CONFIG, newContent);
		}).then(function() {
			self.updateVisibility(currentFile);
			ui.hideModal();
		}).catch(function(err) {
			ui.hideModal();
			ui.addNotification(null, E('p', _('Ошибка: ') + err.message), 'error');
		});
	},
    
    handleCopySnippet: function() {
        var area = document.getElementById('snippet-area');
        if (area) { area.select(); document.execCommand('copy'); }
    },
    
    renderToolbar: function(container, filePath) {
        L.dom.content(container, []);
        if (filePath === MAIN_CONFIG) { container.style.display = 'none'; return; }
        
        container.style.display = 'block';
        container.className = 'toolbar';
        var self = this;
        
        if (filePath.endsWith('.txt')) {
            var input = E('textarea', { 'placeholder': 'google.com\nyoutube.com' });
            var suffixCheck = E('input', { 'type': 'checkbox', 'id': 'suffixCheck', 'checked': true });
            
			var row = E('div', { 'class': 'toolbar-row' }, [
				E('div', { 'style': 'flex-grow: 1;' }, input),
				E('div', { 'class': 'toolbar-col', 'style': 'min-width: 10rem; display: flex; flex-direction: column; justify-content: space-between;' }, [
					E('label', { 'for': 'suffixCheck', 'style': 'align-self: flex-start; font-size: 0.85em;' }, [ suffixCheck, ' . (дубликаты с точкой)' ]),
					E('button', { 'class': 'btn btn-generate', 'style': 'align-self: center;', 'click': function() { self.handleAppendList(input.value, suffixCheck.checked); input.value = ''; } }, _('Добавить'))
				])
			]);
            container.appendChild(row);
        } else {
            var input = E('textarea', { 'placeholder': 'google.com\n104.28.0.0/16\n*.example.com' });
            var typeSelect = E('select', { 'style': 'font-size: 0.9em' }, [
                E('option', { 'value': 'Auto' }, 'Auto'),
                E('option', { 'value': 'DOMAIN-SUFFIX' }, 'DOMAIN-SUFFIX'),
                E('option', { 'value': 'DOMAIN' }, 'DOMAIN'),
                E('option', { 'value': 'DOMAIN-KEYWORD' }, 'DOMAIN-KEYWORD'),
                E('option', { 'value': 'DOMAIN-WILDCARD' }, 'DOMAIN-WILDCARD'),
                E('option', { 'value': 'IP-CIDR' }, 'IP-CIDR'),
                E('option', { 'value': 'IP-CIDR6' }, 'IP-CIDR6')
            ]);
            var row = E('div', { 'class': 'toolbar-row' }, [
                E('div', { 'style': 'flex-grow: 1;' }, input),
                E('div', { 'class': 'toolbar-col' }, [ typeSelect ]),
                E('div', { 'class': 'toolbar-col', 'style': 'min-width: 8rem; justify-content: flex-end;' }, [
                    E('button', { 'class': 'btn btn-generate', 'click': function() { self.handleGenerateRules(input.value, typeSelect.value); input.value = ''; } }, _('Создать'))
                ])
            ]);
            container.appendChild(row);
        }
    },
    
    handleAppendList: function(text, addSuffix) {
        if (!editor || !text.trim()) return;
        var lines = text.trim().split('\n');
        var result = [];
        lines.forEach(function(line) {
            line = line.trim();
            if (!line) return;
            result.push(line);
            if (addSuffix && !line.startsWith('.')) result.push('.' + line);
        });
        if (result.length > 0) {
            editor.navigateFileEnd();
            var doc = editor.getValue();
            var prefix = (doc.length > 0 && !doc.endsWith('\n')) ? '\n' : '';
            editor.insert(prefix + result.join('\n') + '\n');
            editor.focus();
        }
    },
    
    handleGenerateRules: function(text, type) {
        if (!editor || !text.trim()) return;
        var lines = text.trim().split('\n');
        var newRules = [];
        lines.forEach(function(line) {
            line = line.trim();
            if (!line) return;
            var currentType = type === 'Auto' ? detectRuleType(line) : type;
            if (currentType === 'IP-CIDR' && !line.includes('/')) line += '/32';
            newRules.push(`  - ${currentType},${line}`);
        });
        if (newRules.length === 0) return;
        var content = editor.getValue();
        var linesContent = content.split('\n');
        var payloadIndex = linesContent.findIndex(function(l) { return l.trim() === 'payload:'; });
        if (payloadIndex !== -1) {
            editor.gotoLine(linesContent.length + 1, 0);
            editor.insert(newRules.join('\n') + '\n');
        } else {
            var prefix = (content.length > 0 && !content.endsWith('\n')) ? '\n\n' : '';
            editor.navigateFileEnd();
            editor.insert(prefix + 'payload:\n' + newRules.join('\n') + '\n');
        }
        editor.focus();
    },
    
    renderTabBar: function(container) {
        L.dom.content(container, []);
        var self = this;
        var mainTab = E('div', { 'class': (currentFile === MAIN_CONFIG) ? 'tab-item active' : 'tab-item', 'click': ui.createHandlerFn(this, 'handleTabClick', MAIN_CONFIG) }, E('span', {}, 'Конфигурация'));
        container.appendChild(mainTab);
        
        cachedRuleFiles.forEach(function(file) {
            if (file.type === 'file') {
                var fullPath = RULE_DIR + file.name;
                if (!validatePath(fullPath, RULE_DIR)) return;
                var isActive = (currentFile === fullPath);
                var safeName = escapeHtml(sanitizeTabName(file.name));
                var tabContent = [E('span', {}, safeName)];
                if (isActive) {
                    tabContent.push(E('span', { 'class': 'tab-close', 'title': _('Удалить'), 'click': ui.createHandlerFn(self, 'handleDeleteFile', fullPath) }, '×'));
                }
                var tab = E('div', { 'class': isActive ? 'tab-item active' : 'tab-item', 'click': ui.createHandlerFn(self, 'handleTabClick', fullPath) }, tabContent);
                container.appendChild(tab);
            }
        });
        var newTab = E('div', { 'class': 'tab-item tab-new', 'title': _('Создать новый'), 'click': ui.createHandlerFn(this, 'handleCreateFile') }, '+');
        container.appendChild(newTab);
    },
    
    handleTabClick: function(path, ev) {
        if (!validatePath(path, '/etc/mihomo/')) { ui.addNotification(null, E('p', _('Недопустимый путь')), 'error'); return; }
        if (ev && ev.target.classList.contains('tab-close')) { ev.stopPropagation(); return; }
        if (path === currentFile) return;
        
        var self = this;
        ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Загрузка...'))]);
        fs.read(path).then(function(content) {
            currentFile = path;
            if (editor) {
                editor.setValue(content || '', -1);
                editor.session.setMode(path.endsWith('.txt') ? "ace/mode/text" : "ace/mode/yaml");
            }
            self.renderTabBar(document.getElementById('mihomo-tab-bar'));
            self.renderToolbar(document.getElementById('mihomo-toolbar'), path);
            self.updateVisibility(path);
            ui.hideModal();
        }).catch(function(err) {
            if (err && err.message === 'Данные не получены') {
                currentFile = path;
                if (editor) { editor.setValue('', -1); editor.session.setMode(path.endsWith('.txt') ? "ace/mode/text" : "ace/mode/yaml"); }
                self.renderTabBar(document.getElementById('mihomo-tab-bar'));
                self.renderToolbar(document.getElementById('mihomo-toolbar'), path);
                self.updateVisibility(path);
            } else {
                ui.addNotification(null, E('p', _('Ошибка: ') + (err.message || 'Error')), 'error');
            }
            ui.hideModal();
        });
    },
    
    handleCreateFile: function() {
        var self = this;
        var nameInput = E('input', { 'type': 'text', 'style': 'width: 100%;', 'placeholder': 'my-rules' });
        var typeSelect = E('select', { 'style': 'width: 100%;' }, [
            E('option', { 'value': '.yaml' }, 'Набор правил (.yaml)'),
            E('option', { 'value': '.txt' }, 'Простой список (.txt)')
        ]);
        var footer = E('div', { 'class': 'right', 'style': 'margin-top: 1.5rem;' }, [
            E('button', { 'class': 'btn', 'click': ui.hideModal }, _('Отмена')), ' ',
            E('button', { 'class': 'btn cbi-button-positive btn-save-custom', 'click': function() {
                var filename = nameInput.value.trim();
                if (!filename || !validateFilename(filename)) { ui.addNotification(null, E('p', _('Некорректное имя')), 'error'); return; }
                var fullPath = RULE_DIR + filename + typeSelect.value;
                if (!validatePath(fullPath, RULE_DIR)) { ui.addNotification(null, E('p', _('Недопустимый путь')), 'error'); return; }
                ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Создание...'))]);
                fs.stat(fullPath).then(function() {
                    ui.hideModal(); ui.addNotification(null, E('p', _('Файл уже существует')), 'error');
                }).catch(function() {
                    fs.write(fullPath, '').then(function() { return fs.list(RULE_DIR); }).then(function(files) {
                        cachedRuleFiles = (files || []).sort(function(a, b) { return a.name.localeCompare(b.name); });
                        self.handleTabClick(fullPath);
                    }).catch(function(err) { ui.hideModal(); ui.addNotification(null, E('p', _('Ошибка: ') + err.message), 'error'); });
                });
            }}, _('Создать'))
        ]);
        ui.showModal(_('Новый файл правил'), [
            E('div', {}, [
                E('div', { 'style': 'display: flex; align-items: center; margin-bottom: 0.8rem;' }, [ E('label', { 'style': 'min-width: 10rem; margin-right: 0.8rem;' }, _('Имя файла:')), nameInput ]),
                E('div', { 'style': 'display: flex; align-items: center;' }, [ E('label', { 'style': 'min-width: 10rem; margin-right: 0.8rem;' }, _('Тип файла:')), typeSelect ])
            ]), footer
        ]);
        nameInput.focus();
    },
    
    handleDeleteFile: function(path) {
        if (!isSafeRulePath(path)) { ui.addNotification(null, E('p', _('Ошибка пути')), 'error'); return; }
        if (!confirm(_('Удалить %s?').format(path.split('/').pop()))) return;
        var self = this;
        ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Удаление...'))]);
        fs.remove(path).then(function() { return fs.list(RULE_DIR); }).then(function(files) {
            cachedRuleFiles = (files || []).sort(function(a, b) { return a.name.localeCompare(b.name); });
            if (currentFile === path) self.handleTabClick(MAIN_CONFIG);
            else { self.renderTabBar(document.getElementById('mihomo-tab-bar')); ui.hideModal(); }
        }).catch(function(err) { ui.hideModal(); ui.addNotification(null, E('p', _('Ошибка: ') + err.message), 'error'); });
    },
    
    handleSaveAndApply: function(wasRunning) {
        if (this.isProcessing) return Promise.reject(new Error('Busy'));
        if (!editor) return;
        this.isProcessing = true;
        var self = this;
        var content = editor.getValue();
        if (currentFile === MAIN_CONFIG) mainConfigContent = content;
        ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Сохранение...'))]);
        fs.write(currentFile, content).then(function() {
            if (currentFile === MAIN_CONFIG) {
                return fs.exec('/usr/bin/mihomo', ['-d', '/etc/mihomo', '-t', MAIN_CONFIG]).then(function(res) {
                    if (res.code !== 0) throw new Error((res.stdout || '') + (res.stderr || ''));
                    if (wasRunning) return fs.exec('/etc/init.d/mihomo', ['restart']);
                });
            }
        }).then(function() {
            ui.hideModal();
            if (currentFile === MAIN_CONFIG) setTimeout(function() { window.location.reload(); }, RELOAD_DELAY);
        }).catch(function(err) { self.showOutput(err.message, true); ui.hideModal(); }).finally(function() { self.isProcessing = false; });
    },
    
    handleCheck: function() {
        if (currentFile !== MAIN_CONFIG || !editor) return;
        var self = this;
        ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Проверка...'))]);
        fs.write(MAIN_CONFIG, editor.getValue())
            .then(function() { return fs.exec('/usr/bin/mihomo', ['-d', '/etc/mihomo', '-t']); })
            .then(function(res) { self.showOutput((res.stdout || '') + (res.stderr || ''), res.code !== 0); ui.hideModal(); })
            .catch(function(e) { self.showOutput(e.message, true); ui.hideModal(); });
    },
    
    showOutput: function(text, isError) {
        var box = document.getElementById('output-box');
        var out = document.getElementById('output-text');
        if (box && out) {
            out.textContent = text ? text.trim() : '(Пусто)';
            out.style.color = isError ? '#f92672' : 'var(--text-output)';
            box.style.display = 'block';
            box.scrollIntoView({ behavior: 'smooth', block: 'end' });
        }
    },
    
	handleServiceAction: function(act) {
		if (!VALID_ACTIONS.includes(act)) return;
		var self = this;
		ui.showModal(null, [E('p', { 'class': 'spinning' }, _('Выполнение...'))]);
		fs.exec('/etc/init.d/mihomo', [act]).then(function() { window.location.reload(); })
			.catch(function(e) { ui.hideModal(); ui.addNotification(null, E('p', e.message), 'error'); });
	},
    
    handleShowLogs: function() {
        var self = this;
        fs.exec('/sbin/logread', ['-e', 'mihomo']).then(function(res) {
            var logContent = res.stdout;
            if (!logContent && res.code !== 0) {
                logContent = "Записей о 'mihomo' в системном журнале не найдено.\nВозможно, служба не запущена.";
            } else if (!logContent) {
                logContent = "Журнал пуст.";
            }

            self.showOutput(logContent, false);
        }).catch(function(err) {
            self.showOutput("Ошибка чтения журнала: " + err.message, true);
        });
    },
    
    handleOpenDashboard: function(content) {
        var hostname = window.location.hostname;
        var port = '9090';
        try {
            var match = content.match(/external-controller:\s*([0-9\.]+):(\d+)/);
            if (match && match[1] && match[2]) {
                var extractedIp = match[1].trim();
                if (/^(\d{1,3}\.){3}\d{1,3}$/.test(extractedIp) && extractedIp !== '0.0.0.0') hostname = extractedIp;
                var portNum = parseInt(match[2].trim(), 10);
                if (!isNaN(portNum) && portNum >= 1 && portNum <= 65535) port = match[2].trim();
            }
        } catch (e) {}
        window.open(`http://${hostname}:${port}/ui/`, '_blank');
    }
});
EOF
}

install_hev_tunnel(){
    local INSTALLED_VER="" LATEST_VER="" NEED_UPDATE=1

    if [ "$USE_APK" -eq 1 ]; then
        INSTALLED_VER=$(apk info -e hev-socks5-tunnel 2>/dev/null | sed 's/^hev-socks5-tunnel-//')
        [ -z "$INSTALLED_VER" ] && INSTALLED_VER=$(apk list -I 2>/dev/null | grep -m1 '^hev-socks5-tunnel-' | awk '{print $1}' | sed 's/^hev-socks5-tunnel-//')
        
        if [ -n "$INSTALLED_VER" ]; then
            local UPGRADABLE
            UPGRADABLE=$(apk list -u 2>/dev/null | grep -m1 '^hev-socks5-tunnel-')
            if [ -n "$UPGRADABLE" ]; then
                LATEST_VER=$(echo "$UPGRADABLE" | awk '{print $1}' | sed 's/^hev-socks5-tunnel-//')
                log_online "$(T "Обновление hev-socks5-tunnel до $LATEST_VER" "Updating hev-socks5-tunnel to $LATEST_VER")"
                NEED_UPDATE=1
            else
                log_online "$(T "Актуальный hev-socks5-tunnel уже установлен" "hev-socks5-tunnel is already up to date")"
                NEED_UPDATE=0
            fi
        else
            log_online "$(T "Установка hev-socks5-tunnel" "Installing hev-socks5-tunnel")"
            NEED_UPDATE=1
        fi
    else
        INSTALLED_VER=$(opkg list-installed 2>/dev/null | awk '$1=="hev-socks5-tunnel"{print $3}')
        
        if [ -n "$INSTALLED_VER" ]; then
            local UPGRADABLE
            UPGRADABLE=$(opkg list-upgradable 2>/dev/null | grep -m1 '^hev-socks5-tunnel[[:space:]]')
            if [ -n "$UPGRADABLE" ]; then
                LATEST_VER=$(echo "$UPGRADABLE" | awk '{print $5}')
                [ -z "$LATEST_VER" ] && LATEST_VER="новая версия"
                log_online "$(T "Обновление hev-socks5-tunnel до $LATEST_VER" "Updating hev-socks5-tunnel to $LATEST_VER")"
                NEED_UPDATE=1
            else
                log_online "$(T "Актуальный hev-socks5-tunnel уже установлен" "hev-socks5-tunnel is already up to date")"
                NEED_UPDATE=0
            fi
        else
            log_online "$(T "Установка hev-socks5-tunnel" "Installing hev-socks5-tunnel")"
            NEED_UPDATE=1
        fi
    fi

    if [ "$NEED_UPDATE" -eq 1 ]; then
        if [ "$USE_APK" -eq 1 ]; then
            apk cache clean >/dev/null 2>&1
            apk add -u hev-socks5-tunnel >/dev/null 2>&1
        else
            if [ -n "$INSTALLED_VER" ]; then
                opkg upgrade hev-socks5-tunnel >/dev/null 2>&1 || opkg install hev-socks5-tunnel >/dev/null 2>&1
            else
                manage_pkg install hev-socks5-tunnel >/dev/null 2>&1
            fi
        fi
    fi

    local HEV_VER=""
    if [ "$USE_APK" -eq 1 ]; then
        HEV_VER=$(apk info -e hev-socks5-tunnel 2>/dev/null | sed 's/^hev-socks5-tunnel-//')
        [ -z "$HEV_VER" ] && HEV_VER=$(apk list -I 2>/dev/null | grep -m1 '^hev-socks5-tunnel-' | sed 's/^hev-socks5-tunnel-//;s/[ \t].*//')
    else
        HEV_VER=$(opkg list-installed 2>/dev/null | awk '$1=="hev-socks5-tunnel"{print $3}')
    fi
    
    if [ -n "$HEV_VER" ]; then
        mkdir -p "$MIXOMO_VERSIONS_DIR" 2>/dev/null || true
        echo "$HEV_VER" > "$HEV_VERSION_FILE"
    fi

    rm -f /etc/hev-socks5-tunnel/main.yml
    mkdir -p /etc/hev-socks5-tunnel
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

    echo "$(T "Настройка UCI-сервиса hev-socks5-tunnel" "Setting up the hev-socks5-tunnel UCI service")"
    uci set hev-socks5-tunnel.config.enabled='1'
    uci set hev-socks5-tunnel.config.configfile='/etc/hev-socks5-tunnel/main.yml'
    uci commit hev-socks5-tunnel
    /etc/init.d/hev-socks5-tunnel restart
    sleep 2

    echo "$(T "Настройка сетевого интерфейса" "Setting up the network interface")"
    if ! uci -q get network.Mihomo >/dev/null 2>&1; then
        uci set network.Mihomo=interface
        uci set network.Mihomo.proto='none'
        uci set network.Mihomo.device='Mihomo'
    else
        uci set network.Mihomo.proto='none'
        uci set network.Mihomo.device='Mihomo'
    fi
    uci commit network
    /etc/init.d/network reload
    sleep 1

    echo "$(T "Настройка Firewall" "Setting up the Firewall")"
    local FW_ZONE=""
    local FW_FWD=""
    FW_ZONE=$(uci show firewall 2>/dev/null | grep "\.name='Mihomo'" | head -1 | sed "s/\.name=.*//; s/^firewall\.//")
    if [ -n "$FW_ZONE" ]; then
        for fw_fwd in $(uci show firewall 2>/dev/null | grep -E "\.src='lan'" | sed -E "s/\.src=.*//; s/^firewall\.//"); do
            if [ "$(uci -q get firewall.$fw_fwd.dest 2>/dev/null)" = "Mihomo" ]; then
                FW_FWD="$fw_fwd"; break
            fi
        done
    fi
    if [ -z "$FW_ZONE" ]; then
        FW_ZONE=$(uci add firewall zone)
        uci set "firewall.${FW_ZONE}.name=Mihomo"
        uci set "firewall.${FW_ZONE}.input=REJECT"
        uci set "firewall.${FW_ZONE}.output=REJECT"
        uci set "firewall.${FW_ZONE}.forward=REJECT"
        uci set "firewall.${FW_ZONE}.masq=1"
        uci set "firewall.${FW_ZONE}.mtu_fix=1"
        uci add_list "firewall.${FW_ZONE}.network=Mihomo"
    fi
    if [ -z "$FW_FWD" ]; then
        FW_FWD=$(uci add firewall forwarding)
        uci set "firewall.${FW_FWD}.src=lan"
        uci set "firewall.${FW_FWD}.dest=Mihomo"
    fi

    uci commit firewall
    /etc/init.d/firewall reload
}

install_magitrickle_original_package() {
    log_online "$(T "Добавление репозитория MagiTrickle" "Adding the MagiTrickle repository")"
    if ! curl -sSL http://bin.magitrickle.dev/packages/add_repo.sh | sh >/dev/null 2>&1; then
        if ! wget -qO- http://bin.magitrickle.dev/packages/add_repo.sh | sh >/dev/null 2>&1; then
            log_error "$(T "Ошибка: не удалось добавить репозиторий MagiTrickle!" "Error: could not add the MagiTrickle repository!")"
            return 1
        fi
    fi
    log_online "$(T "Загрузка пакета MagiTrickle" "Downloading the MagiTrickle package")"
    if [ "$USE_APK" -eq 1 ]; then
        apk update >/dev/null 2>&1 || true
        apk add magitrickle >/dev/null 2>&1 || true
    else
        opkg update >/dev/null 2>&1 || true
        opkg install magitrickle >/dev/null 2>&1 || true
    fi
    [ -x /etc/init.d/magitrickle ] || return 1
    return 0
}

install_magitrickle_mod_package() {
    local LOG="/tmp/mixomo-mod-install.log"
    local rc=1
    log_online "$(T "Установка MagiTrickle Mod от badigit" "Installing MagiTrickle Mod by badigit")"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 10 -m 300 \
            "https://raw.githubusercontent.com/badigit/MagiTrickle_mod_badigit/mod_badigit/scripts/install.sh" | sh >"$LOG" 2>&1
        rc=$?
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- --timeout=300 \
            "https://raw.githubusercontent.com/badigit/MagiTrickle_mod_badigit/mod_badigit/scripts/install.sh" | sh >"$LOG" 2>&1
        rc=$?
    else
        log_error "$(T "Не найден curl или wget для установки mod" "Neither curl nor wget found to install the mod")"
        return 1
    fi
    if [ -x /etc/init.d/magitrickle ]; then
        rm -f "$LOG"
        return 0
    fi
    log_error "$(T "Не удалось установить MagiTrickle Mod от badigit. Подробный лог: $LOG" "Could not install MagiTrickle Mod by badigit. Detailed log: $LOG")"
    return 1
}

install_mixomo_redir() {
    mkdir -p "$MIXOMO_REDIR_DIR" "$MIXOMO_VERSIONS_DIR" 2>/dev/null || true
    rm -f /usr/libexec/mixomo-redir 2>/dev/null || true
    cat > "$MIXOMO_REDIR_SCRIPT" <<'EOF'
#!/bin/sh
PREFIX="mihomo_route_"
CHAIN="MIXOMO_CLASSIFY"
MARK_DEFAULT="1298229097"
EXCL_PRIO_BASE=18000

IPT=""
if command -v iptables >/dev/null 2>&1; then IPT=iptables
elif command -v iptables-nft >/dev/null 2>&1; then IPT=iptables-nft
fi

REDIR_PORT=$(tr -d ' \r\n' < /etc/mixomo/routing/redir-port 2>/dev/null)
MARK=$(tr -d ' \r\n' < /etc/mixomo/routing/redir-mark 2>/dev/null)
[ -n "$MARK" ] || MARK="$MARK_DEFAULT"

: > /tmp/mixomo-user-excl
for sec in $(uci show network 2>/dev/null | sed -n "s/^network\\.\\(${PREFIX}excl_[^.=]*\\)=mihomo_excl$/\\1/p"); do
    [ "$(uci -q get network.$sec.disabled)" = "1" ] && continue
    d=$(uci -q get network.$sec.dest)
    [ -n "$d" ] && echo "$d" >> /tmp/mixomo-user-excl
done
sort -u /tmp/mixomo-user-excl > /tmp/mixomo-user-excl-u

if command -v ip >/dev/null 2>&1; then
    p=$EXCL_PRIO_BASE
    while [ "$p" -lt $((EXCL_PRIO_BASE + 100)) ]; do
        ip rule del priority "$p" 2>/dev/null
        p=$((p + 1))
    done
    n=0
    while read -r excl; do
        ip rule add priority $((EXCL_PRIO_BASE + n)) to "$excl" lookup main 2>/dev/null
        n=$((n + 1))
    done < /tmp/mixomo-user-excl-u
fi

: > /tmp/mixomo-redir-rules
for sec in $(uci show network 2>/dev/null | sed -n "s/^network\\.\\(${PREFIX}client_[^.=]*\\)=mihomo_rule$/\\1/p"); do
    [ "$(uci -q get network.$sec.disabled)" = "1" ] && continue
    src=$(uci -q get network.$sec.src)
    [ -n "$src" ] || continue
    prio=$(uci -q get network.$sec.priority)
    [ -n "$prio" ] || prio=0
    echo "$prio|$src"
done | sort -n -t'|' -k1 > /tmp/mixomo-redir-rules

if [ -n "$IPT" ]; then
    "$IPT" -t nat -F "$CHAIN" 2>/dev/null
    "$IPT" -t nat -D PREROUTING -i lo -j "$CHAIN" 2>/dev/null
    "$IPT" -t nat -D PREROUTING ! -i lo -j "$CHAIN" 2>/dev/null
    "$IPT" -t nat -X "$CHAIN" 2>/dev/null
    "$IPT" -t mangle -F "$CHAIN" 2>/dev/null
    "$IPT" -t mangle -D PREROUTING -i lo -j "$CHAIN" 2>/dev/null
    "$IPT" -t mangle -D PREROUTING ! -i lo -j "$CHAIN" 2>/dev/null
    "$IPT" -t mangle -X "$CHAIN" 2>/dev/null
fi

[ -n "$IPT" ] || exit 0
[ -n "$REDIR_PORT" ] || exit 0
[ -s /tmp/mixomo-redir-rules ] || exit 0

"$IPT" -t nat -N "$CHAIN"
"$IPT" -t mangle -N "$CHAIN"

LOCAL="127.0.0.0/8 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12 100.64.0.0/10 169.254.0.0/16 224.0.0.0/4 255.255.255.255/32"
ip -4 route show table main proto kernel scope link 2>/dev/null > /tmp/mixomo-local-routes
while read -r subnet rest; do
    case "$subnet" in */*) LOCAL="$LOCAL $subnet";; esac
done < /tmp/mixomo-local-routes
while read -r excl; do
    LOCAL="$LOCAL $excl"
done < /tmp/mixomo-user-excl-u
for net in $LOCAL; do
    "$IPT" -t nat -A "$CHAIN" -d "$net" -j RETURN
    "$IPT" -t mangle -A "$CHAIN" -d "$net" -j RETURN
done

"$IPT" -t nat -I PREROUTING 1 ! -i lo -j "$CHAIN"
"$IPT" -t mangle -I PREROUTING 1 ! -i lo -j "$CHAIN"

while IFS='|' read -r prio src; do
    "$IPT" -t nat -A "$CHAIN" -s "$src" -p tcp -j REDIRECT --to-ports "$REDIR_PORT"
    "$IPT" -t mangle -A "$CHAIN" -s "$src" -p udp -j TPROXY --on-port "$REDIR_PORT" --tproxy-mark "$MARK/$MARK" 2>/dev/null || true
done < /tmp/mixomo-redir-rules

if ! ip rule list 2>/dev/null | grep -Eq "lookup[[:space:]]+$MARK([[:space:]]|$)"; then
    ip rule add fwmark "$MARK" lookup "$MARK" 2>/dev/null || true
fi
ip route replace local default dev lo table "$MARK" 2>/dev/null || true

exit 0
EOF
    chmod +x "$MIXOMO_REDIR_SCRIPT"

    echo "$(T "Создание службы /etc/init.d/mixomo-local-routing" "Creating the /etc/init.d/mixomo-local-routing service")"
    cat > /etc/init.d/mixomo-local-routing <<'EOF'
#!/bin/sh /etc/rc.common
START=99
STOP=10

start() {
    if [ -x /etc/mixomo/routing/redir ] && [ -s /etc/mixomo/routing/redir-port ]; then
        /etc/mixomo/routing/redir 2>/dev/null
    fi

    local tunsocks_table
    tunsocks_table="$(uci -q get network.mihomo_routing_table.table)"
    if [ -n "$tunsocks_table" ]; then
        local i=0
        while [ $i -lt 10 ]; do
            if ip link show Mihomo >/dev/null 2>&1; then
                break
            fi
            sleep 1
            i=$((i + 1))
        done
        
        if ! ip route show table "$tunsocks_table" 2>/dev/null | grep -Eq '^default[[:space:]].*dev[[:space:]]Mihomo([[:space:]]|$)'; then
            ip route replace default dev Mihomo table "$tunsocks_table" 2>/dev/null || true
        fi

        if [ "$(uci -q get network.mihomo_route_router.mark)" = "0x233" ]; then
            if ! ip rule list 2>/dev/null | grep -Eq "^[[:space:]]*19000:.*fwmark 0x233.*lookup $tunsocks_table([[:space:]]|$)"; then
                ip rule add priority 19000 fwmark 0x233 lookup "$tunsocks_table" 2>/dev/null || true
            fi
        fi
    fi

    if [ -x /etc/init.d/magitrickle ] && /etc/init.d/magitrickle running >/dev/null 2>&1; then
        (/etc/init.d/magitrickle restart >/dev/null 2>&1) &
    fi

}

stop() {
    [ -x /etc/mixomo/routing/redir ] || return 0
    /etc/mixomo/routing/redir 2>/dev/null
}
EOF
    chmod +x /etc/init.d/mixomo-local-routing
    service mixomo-local-routing enable 2>/dev/null || true
}

write_mixomo_routing_state() {
    mkdir -p "$MIXOMO_REDIR_DIR" "$MIXOMO_VERSIONS_DIR" 2>/dev/null || true
    local P M
    P="$(ensure_mihomo_redir_port 2>/dev/null)"
    [ -n "$P" ] && echo "$P" > "$MIXOMO_REDIR_PORT_FILE"
    M=$(grep -E '^[[:space:]]*startMarkTableIndex:' /etc/magitrickle/state/config.yaml 2>/dev/null | awk '{print $2}' | tr -d ' \r\n')
    [ -n "$M" ] || M="$MIXOMO_REDIR_DEFAULT_MARK"
    echo "$M" > "$MIXOMO_REDIR_MARK_FILE"
}

install_magitrickle() {
    local CONFIG_PATH="/etc/magitrickle/state/config.yaml"
    local BACKUP_PATH="/tmp/magitrickle_config_backup.yaml"

    local NEED_INSTALL=1 INSTALLED NOW_TAG LATEST
    INSTALLED="$(read_variant_now)"
    NOW_TAG="$(read_version_now)"
    LATEST="$(magitrickle_latest_version "$MAGI_VARIANT")"

    if [ "$INSTALLED" = "$MAGI_VARIANT" ] && [ -n "$NOW_TAG" ] && [ -n "$LATEST" ] && [ "$NOW_TAG" = "$LATEST" ] && [ -x /etc/init.d/magitrickle ]; then
        NEED_INSTALL=0
        log_online "$(T "Актуальный MagiTrickle $LATEST уже установлен" "MagiTrickle $LATEST is already up to date")"
    fi

    if [ "$NEED_INSTALL" -eq 1 ]; then
        if [ -f "$CONFIG_PATH" ]; then
            cp "$CONFIG_PATH" "$BACKUP_PATH"
            rm -f "$CONFIG_PATH"
        fi

        if [ "$USE_APK" -eq 1 ]; then
            apk del magitrickle >/dev/null 2>&1 || true
        else
            opkg remove magitrickle_mod >/dev/null 2>&1 || true
            opkg remove magitrickle >/dev/null 2>&1 || true
        fi

        if [ "$MAGI_VARIANT" = "mod" ]; then
            if ! install_magitrickle_mod_package; then
                log_error "$(T "Ошибка: не удалось установить MagiTrickle Mod от badigit!" "Error: could not install MagiTrickle Mod by badigit!")"
                return 1
            fi
        else
            if ! install_magitrickle_original_package; then
                log_error "$(T "Ошибка: не удалось установить MagiTrickle!" "Error: could not install MagiTrickle!")"
                return 1
            fi
        fi

        service magitrickle enable 2>/dev/null || true
        if [ "$MAGI_VARIANT" = "mod" ]; then
            uci -q set magitrickle.main.enabled='1' 2>/dev/null
            uci -q commit magitrickle 2>/dev/null
        fi
        service magitrickle restart 2>/dev/null || true

        if ! service magitrickle running >/dev/null 2>&1; then
            sleep 2
            if ! service magitrickle running >/dev/null 2>&1; then
                log_error "$(T "Ошибка: MagiTrickle не запускается!" "Error: MagiTrickle does not start!")"
                return 1
            fi
        fi

        save_magitrickle_variant "$MAGI_VARIANT" "$LATEST"
    fi

    if [ -f "$BACKUP_PATH" ]; then
        if [ ! -f "$CONFIG_PATH" ]; then
            echo "$(T "Начальная конфигурация отсутствует. Использование бэкапа..." "No initial configuration found. Using the backup...")"
            mkdir -p "$(dirname "$CONFIG_PATH")"
            cp "$BACKUP_PATH" "$CONFIG_PATH"
        else
            local OLD_VERSION NEW_VERSION
            OLD_VERSION=$(grep -E "^[[:space:]]*configVersion:" "$BACKUP_PATH" | awk '{print $2}' | tr -d ' "\r\n')
            NEW_VERSION=$(grep -E "^[[:space:]]*configVersion:" "$CONFIG_PATH" | awk '{print $2}' | tr -d ' "\r\n')

            if [ -z "$OLD_VERSION" ] || [ -z "$NEW_VERSION" ]; then
                log_warn "$(T "Не удалось определить версию конфигурации." "Could not determine the configuration version.")"
                log_warn "$(T "Бэкап сохранен как ${CONFIG_PATH}.backup" "Backup saved as ${CONFIG_PATH}.backup")"
                cp "$BACKUP_PATH" "${CONFIG_PATH}.backup"
            elif [ "$OLD_VERSION" = "$NEW_VERSION" ]; then
                echo "$(T "Версии конфигураций совпадают ($OLD_VERSION). Использование бэкапа..." "Configuration versions match ($OLD_VERSION). Using the backup...")"
                cp "$BACKUP_PATH" "$CONFIG_PATH"
            else
                log_warn "$(T "Версии конфигураций отличаются! (Прошлая: $OLD_VERSION, Нынешняя: $NEW_VERSION)" "Configuration versions differ! (Previous: $OLD_VERSION, Current: $NEW_VERSION)")"
                log_warn "$(T "Прошлая конфигурация сохранена как ${CONFIG_PATH}.backup" "Previous configuration saved as ${CONFIG_PATH}.backup")"
                cp "$BACKUP_PATH" "${CONFIG_PATH}.backup"
            fi
        fi
        rm -f "$BACKUP_PATH"
    fi

    if [ "$MAGI_VARIANT" = "mod" ]; then
        local REDIR_PORT
        REDIR_PORT="$(ensure_mihomo_redir_port)" || return 1
        sync_tproxy_port "$REDIR_PORT"
        service magitrickle restart 2>/dev/null || true
    fi
    write_mixomo_routing_state
    install_mixomo_redir

    echo "$(T "Создание страницы MagiTrickle в LuCI" "Creating the MagiTrickle page in LuCI")"
    mkdir -p /www/luci-static/resources/view/magitrickle

    cat > /www/luci-static/resources/view/magitrickle/magitrickle.js <<'EOF'
'use strict';
'require view';

var MIXOMO_EN = {
    'HTTPS соединение блокирует встроенный интерфейс MagiTrickle через LuCI.': 'HTTPS connection blocks the built-in MagiTrickle interface through LuCI.',
    'Пожалуйста, откройте MagiTrickle в новой вкладке для полноценного управления.': 'Please open MagiTrickle in a new tab for full management.',
    'Открыть MagiTrickle': 'Open MagiTrickle'
};

function detectLuciLang() {
    var lang = '';
    if (window.LANG) {
        lang = window.LANG;
    } else if (document.documentElement && document.documentElement.lang) {
        lang = document.documentElement.lang;
    }
    return (lang || 'ru').toLowerCase();
}

var MIXOMO_IS_EN = /^en/.test(detectLuciLang());

(function() {
    var orig = window._;
    window._ = function(text) {
        if (MIXOMO_IS_EN && MIXOMO_EN.hasOwnProperty(text)) {
            return MIXOMO_EN[text];
        }
        if (orig) {
            return orig.apply(window, arguments);
        }
        return text;
    };
})();

return view.extend({
    handleSave: null,
    handleSaveApply: null,
    handleReset: null,

    render: function() {
        var hostname = window.location.hostname;
        var port = '8080';
        var url = 'http://' + hostname + ':' + port;

        if (window.location.protocol === 'https:') {
            return E('div', { style: 'padding: 20px; text-align: center;' }, [
                E('p', _('HTTPS соединение блокирует встроенный интерфейс MagiTrickle через LuCI.')),
                E('p', { style: 'margin-bottom: 20px;' }, _('Пожалуйста, откройте MagiTrickle в новой вкладке для полноценного управления.')),
                E('a', {
                    'class': 'btn cbi-button-action',
                    'href': url,
                    'target': '_blank',
                    'style': 'padding: 10px 20px; font-size: 1.1em;'
                }, _('Открыть MagiTrickle'))
            ]);
        }

        return E('div', {
            style: 'width:100%; height:92vh; margin: -20px -20px 0 -20px; overflow: hidden;'
        }, E('iframe', {
            src: url,
            style: 'width:100%; height:100%; border: none;'
        }));
    }
});
EOF

    cat > /usr/share/luci/menu.d/luci-app-magitrickle.json <<'EOF'
{
    "admin/services/magitrickle": {
        "title": "MagiTrickle",
        "order": 60,
        "action": {
            "type": "view",
            "path": "magitrickle/magitrickle"
        }
    }
}
EOF

    rm -rf /tmp/luci-indexcache /tmp/luci-modulecache/
}

finalize_install() {
    echo "$(T "Выставление прав доступа" "Setting permissions")"
    chmod -R 755 /www/luci-static/resources/view/mihomo 2>/dev/null || true
    find /www/luci-static/resources/view/mihomo -type f -exec chmod 644 {} \; 2>/dev/null || true
    chmod 644 /www/luci-static/resources/view/magitrickle/magitrickle.js 2>/dev/null || true

    echo "$(T "Очистка кэша LuCI и перезапуск сервисов" "Clearing the LuCI cache and restarting services")"
    rm -rf /tmp/luci-indexcache /tmp/luci-modulecache/
    /etc/init.d/rpcd restart > /dev/null 2>&1
    /etc/init.d/uhttpd restart > /dev/null 2>&1
    /etc/init.d/hev-socks5-tunnel restart > /dev/null 2>&1
    /etc/init.d/mihomo restart > /dev/null 2>&1
    /etc/init.d/mixomo-local-routing restart > /dev/null 2>&1 || true
}

main() {
    clear

    choose_language
    echo ""

    uci -q delete firewall.Block_443_UDP.direction
    uci -q delete firewall.Block_443_UDP.reject_forward
    uci commit firewall 2>/dev/null || true

    choose_magitrickle_variant
    echo ""

    log_done "$(T "[1/5] Установка зависимостей" "[1/5] Installing dependencies")"
    install_deps || step_fail
    echo ""

    log_done "$(T "[2/5] Установка Mihomo" "[2/5] Installing Mihomo")"
    install_mihomo || step_fail
    echo ""

    log_done "$(T "[3/5] Установка Hev-Socks5-Tunnel" "[3/5] Installing Hev-Socks5-Tunnel")"
    install_hev_tunnel || step_fail
    echo ""

    log_done "$(T "[4/5] Установка MagiTrickle" "[4/5] Installing MagiTrickle")"
    install_magitrickle || step_fail
    echo ""

    log_done "$(T "[5/5] Завершение" "[5/5] Finalization")"
    finalize_install || step_fail
    echo ""
    log_done "┌───────────────────────────────────────────────────────────────────────┐"
    log_done "$(T "│ Установка Mixomo OpenWrt $SCRIPT_VERSION прошла успешно!                 │" "│ Mixomo OpenWrt $SCRIPT_VERSION installed successfully!                  │")"
    log_done "├───────────────────────────────────────────────────────────────────────┤"
    log_done "$(T "│ 1. Перезагрузите страницу роутера, далее перейдите в...               │" "│ 1. Reload the router page, then go to...                               │")"
    log_done "├───────────────────────────────────────────────────────────────────────┤"
    log_done "$(T "│ 2. Службы или Services → Mihomo → Настройте конфигурацию прокси       │" "│ 2. Services → Mihomo → Configure the proxy configuration               │")"
    log_done "│    ${CYAN}[$(T "Онлайн генератор конфигурации" "Online config generator")]                                      ${GREEN}│"
    log_done "│    ${CYAN}https://spatiumstas.github.io/web4core/                            ${GREEN}│"
    log_done "│    ${CYAN}[$(T "Готовые конфигурации" "Ready-made configs")]                                               ${GREEN}│"
    log_done "│    ${CYAN}https://secret-harbor.notion.site/31345fc37b6f80fa82d3da96e9ae12cc ${GREEN}│"
    log_done "├───────────────────────────────────────────────────────────────────────┤"
    log_done "$(T "│ 3. Службы или Services → MagiTrickle → Укажите сайты для прокси       │" "│ 3. Services → MagiTrickle → Specify sites to proxy                      │")"
    log_done "│    ${CYAN}[$(T "Готовые конфигурации" "Ready-made configs")]                                               ${GREEN}│"
    log_done "│    ${CYAN}https://secret-harbor.notion.site/31345fc37b6f80fa82d3da96e9ae12cc ${GREEN}│"
    log_done "├───────────────────────────────────────────────────────────────────────┤"
    log_done "$(T "│ 4. Наслаждайтесь интернетом :)                                        │" "│ 4. Enjoy the internet :)                                               │")"
    log_done "└───────────────────────────────────────────────────────────────────────┘"
    echo ""

    case "$0" in
        /tmp/*) rm -f "$0" 2>/dev/null || true ;;
    esac
}

main
