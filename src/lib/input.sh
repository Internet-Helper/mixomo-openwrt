read_user_input() {
    if read -r _MIXOMO_INPUT < /dev/tty 2>/dev/null; then
        printf '%s' "$_MIXOMO_INPUT"
        return 0
    fi
    if read -r _MIXOMO_INPUT 2>/dev/null; then
        printf '%s' "$_MIXOMO_INPUT"
        return 0
    fi
    return 1
}

has_tty() { [ -c /dev/tty ]; }
