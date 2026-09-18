detect_mihomo_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)
            if grep -q avx2 /proc/cpuinfo 2>/dev/null; then
                printf 'amd64'
            else
                printf 'amd64-compatible'
            fi
            ;;
        i?86) printf '386' ;;
        aarch64|arm64) printf 'arm64' ;;
        armv7*) printf 'armv7' ;;
        armv5*|armv4*) printf 'armv5' ;;
        riscv64) printf 'riscv64' ;;
        mips*)
            local fpu
            fpu=$(grep -c FPU /proc/cpuinfo 2>/dev/null || echo 0)
            local float_type="softfloat"
            [ "$fpu" -gt 0 ] && float_type="hardfloat"
            local endian
            endian=$(hexdump -s 5 -n 1 -e '1/1 "%d"' /bin/busybox 2>/dev/null || echo 0)
            if [ "$endian" = 1 ]; then
                printf 'mipsle-%s' "$float_type"
            else
                printf 'mips-%s' "$float_type"
            fi
            ;;
        *) log_error "$(T "Неизвестная архитектура: $arch" "Unknown architecture: $arch")"; return 1 ;;
    esac
}
