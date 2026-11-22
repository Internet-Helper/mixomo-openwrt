#!/bin/sh
# Route this router's own traffic through MagiTrickle groups (by domain).
# Reuses the ipsets/marks created by magitrickled, but in mangle/OUTPUT,
# because locally generated packets never pass through PREROUTING.

CHAIN="MT_LOCAL_OUT"
IPT="$(command -v iptables 2>/dev/null)"
[ -n "$IPT" ] || exit 1

LOCAL_NETS="127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 169.254.0.0/16 224.0.0.0/4 255.255.255.255/32 198.18.0.0/16"

log() { logger -t magitrickle-local "$*"; }

stop_chain() {
        while "$IPT" -t mangle -D OUTPUT -j "$CHAIN" 2>/dev/null; do :; done
        "$IPT" -t mangle -F "$CHAIN" 2>/dev/null
        "$IPT" -t mangle -X "$CHAIN" 2>/dev/null
}

start_chain() {
        # magitrickled installs its chains asynchronously after start
        i=0
        while [ "$i" -lt 15 ]; do
                chains=$("$IPT" -t mangle -S PREROUTING 2>/dev/null | awk '/^-A PREROUTING -j MT_/ {print $NF}')
                [ -n "$chains" ] && break
                i=$((i + 1))
                sleep 1
        done
        [ -n "$chains" ] || { log "no MagiTrickle chains in PREROUTING, aborting"; return 1; }

        stop_chain
        "$IPT" -t mangle -N "$CHAIN" 2>/dev/null || return 1

        # do not overwrite marks set by other components (e.g. mixomo router mark)
        "$IPT" -t mangle -A "$CHAIN" -m mark ! --mark 0 -j RETURN || return 1
        for net in $LOCAL_NETS; do
                "$IPT" -t mangle -A "$CHAIN" -d "$net" -j RETURN || return 1
        done

        for c in $chains; do
                rules=$("$IPT" -t mangle -S "$c" 2>/dev/null)
                setname=$(printf '%s\n' "$rules" | awk '/--match-set/ && /--set-xmark/ {for(i=1;i<=NF;i++) if($i=="--match-set") {s=$(i+1); if (s ~ /_4$/) {print s; found=1; exit} else if (first=="") first=s}} END{if(!found && first!="") print first}')
                mark=$(printf '%s\n' "$rules" | awk '/--set-xmark/ {for(i=1;i<=NF;i++) if($i=="--set-xmark") {split($(i+1),a,"/"); print a[1]; exit}}')
                [ -n "$setname" ] && [ -n "$mark" ] || continue
                "$IPT" -t mangle -A "$CHAIN" -m set --match-set "$setname" dst -j MARK --set-xmark "$mark/0xffffffff" || return 1
        done

        "$IPT" -t mangle -A OUTPUT -j "$CHAIN" || return 1
        log "enabled ($(printf '%s\n' "$chains" | wc -l) groups)"
        return 0
}

case "$1" in
        start) start_chain ;;
        stop) stop_chain; log "disabled" ;;
        status)
                "$IPT" -t mangle -S OUTPUT 2>/dev/null | grep -q -- "-j $CHAIN" && echo enabled || echo disabled
                ;;
        *) echo "usage: $0 {start|stop|status}"; exit 2 ;;
esac
