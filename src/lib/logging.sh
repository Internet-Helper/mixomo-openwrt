GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
LANG_MODE="ru"

log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*" >&2; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
log_done() { printf "${GREEN}%s${NC}\n" "$*"; }
step_start() { log_done "$*"; }
step_done() { log_done "${MIXOMO_STEP:+$MIXOMO_STEP }$*"; }

T() {
    if [ "$LANG_MODE" = "en" ]; then
        printf '%s' "$2"
    else
        printf '%s' "$1"
    fi
}

choose_language() {
    case "${1:-}" in
        --en) LANG_MODE="en" ;;
        '') LANG_MODE="ru" ;;
        *) log_error "Неизвестный параметр: $1"; return 1 ;;
    esac
}
