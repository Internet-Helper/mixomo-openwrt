download_to() {
    local url="$1"
    local target="$2"
    local secs="${3:-300}"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 10 --max-time "$secs" -o "$target" "$url"
        return $?
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q -T "$secs" -O "$target" "$url"
        return $?
    fi
    return 1
}

mixomo_api_fail_marker() {
    printf '%s/.github-api-fail-since' "${MIXOMO_VERSIONS_DIR:-/etc/mixomo/versions}"
}

mixomo_github_api_ok() {
    rm -f "$(mixomo_api_fail_marker)" 2>/dev/null || true
}

mixomo_github_api_fail() {
    local marker now first age
    marker=$(mixomo_api_fail_marker)
    mkdir -p "$(dirname "$marker")" 2>/dev/null || true
    now=$(date +%s 2>/dev/null)
    case "$now" in ''|*[!0-9]*) now=0 ;; esac
    if [ -f "$marker" ]; then
        first=$(tr -d ' \r\n' < "$marker" 2>/dev/null)
        case "$first" in ''|*[!0-9]*) first="$now" ;; esac
    else
        first="$now"
        printf '%s' "$now" > "$marker" 2>/dev/null || true
    fi
    age=$((now - first)) 2>/dev/null || age=0
    case "$age" in ''|*[!0-9]*) age=0 ;; esac
    if [ "$age" -ge 86400 ]; then
        log_warn "$(T "Проверка обновлений недоступна через GitHub и его зеркала, проверьте доступ к ресурсу." "Update checks are unavailable via GitHub and its mirrors, please check access to the resource.")"
    else
        log_warn "$(T "Источник версий временно недоступен, попробуйте позже." "Version source is temporarily unavailable, please try again later.")"
    fi
}

verify_sha256() {
    local file="$1"
    local expected="$2"
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s  %s\n' "$expected" "$file" | sha256sum -c - >/dev/null 2>&1
        return $?
    fi
    if command -v busybox >/dev/null 2>&1 && busybox sha256sum >/dev/null 2>&1; then
        printf '%s  %s\n' "$expected" "$file" | busybox sha256sum -c - >/dev/null 2>&1
        return $?
    fi
    return 1
}
