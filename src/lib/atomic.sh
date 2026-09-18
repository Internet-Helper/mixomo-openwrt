ensure_dir() { mkdir -p "$1" 2>/dev/null || return 1; }

mixomo_temp_file() {
    local target="$1"
    local target_dir
    local temp_dir
    local base
    target_dir=$(dirname "$target")
    ensure_dir "$target_dir" || return 1
    base=$(basename "$target")
    temp_dir=$(mktemp -d "$target_dir/.mixomo.XXXXXX") || return 1
    printf '%s\n' "$temp_dir/$base"
}

mixomo_temp_cleanup() {
    local file="$1"
    [ -n "$file" ] || return 0
    rm -rf "$(dirname "$file")" 2>/dev/null || rm -f "$file"
}

install_text_atomic() {
    local source_file="$1"
    local target_file="$2"
    local mode="${3:-644}"
    local temp
    temp=$(mixomo_temp_file "$target_file") || return 1
    if ! cp "$source_file" "$temp"; then
        mixomo_temp_cleanup "$temp"
        return 1
    fi
    if ! chmod "$mode" "$temp"; then
        mixomo_temp_cleanup "$temp"
        return 1
    fi
    if ! mv -f "$temp" "$target_file"; then
        mixomo_temp_cleanup "$temp"
        return 1
    fi
    mixomo_temp_cleanup "$temp"
}

