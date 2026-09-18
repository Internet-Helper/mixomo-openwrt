download_to() {
    local url="$1"
    local target="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --connect-timeout 10 --max-time 300 -o "$target" "$url"
        return $?
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q -T 300 -O "$target" "$url"
        return $?
    fi
    return 1
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
