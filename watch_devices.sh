#!/bin/bash
# real-time device tracker with connect/disconnect events
PHOBIA_DIR="/home/kali/phobia"
STATE_FILE="/tmp/phobia_devices_state"
EVENTS_LOG="$PHOBIA_DIR/logs/device_events.log"
mkdir -p "$PHOBIA_DIR/logs"

declare -A SEEN

# seed with currently active leases
if [ -f /var/lib/misc/dnsmasq.leases ]; then
    NOW=$(date +%s)
    while read -r expiry mac ip host clientid; do
        [ -z "$expiry" ] && continue
        if [ "$expiry" -gt "$NOW" ] 2>/dev/null; then
            SEEN["$mac"]="$ip ${host:-*}"
        fi
    done < /var/lib/misc/dnsmasq.leases
fi

log_event() {
    printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$1" >> "$EVENTS_LOG"
}

while true; do
    clear
    echo -e "\033[1;36m------- CONNECTED DEVICES (live) -------\033[0m"
    echo ""

    NOW=$(date +%s)
    declare -A CURRENT

    if [ -f /var/lib/misc/dnsmasq.leases ]; then
        while read -r expiry mac ip host clientid; do
            [ -z "$expiry" ] && continue
            if [ "$expiry" -gt "$NOW" ] 2>/dev/null; then
                CURRENT["$mac"]="$ip ${host:-*}"
            fi
        done < /var/lib/misc/dnsmasq.leases
    fi

    # detect new connections
    for mac in "${!CURRENT[@]}"; do
        if [ -z "${SEEN[$mac]}" ]; then
            log_event "[+] CONNECTED   $mac  ${CURRENT[$mac]}"
            SEEN["$mac"]="${CURRENT[$mac]}"
        fi
    done

    # detect disconnections
    for mac in "${!SEEN[@]}"; do
        if [ -z "${CURRENT[$mac]}" ]; then
            log_event "[-] DISCONNECTED $mac"
            unset SEEN["$mac"]
        fi
    done

    # render
    printf "  \033[1;37m%-18s %-16s %-20s %s\033[0m\n" "MAC" "IP" "HOSTNAME" "STATUS"
    echo -e "  \033[1;36m────────────────────────────────────────────────────────────\033[0m"

    if [ ${#CURRENT[@]} -eq 0 ]; then
        echo -e "  \033[2mno devices connected\033[0m"
    else
        for mac in "${!CURRENT[@]}"; do
            IFS=' ' read -r ip host <<< "${CURRENT[$mac]}"
            printf "  \033[1;33m%-18s\033[0m \033[1;32m%-16s\033[0m \033[1;37m%-20s\033[0m \033[1;32m● CONNECTED\033[0m\n" \
                "$mac" "$ip" "$host"
        done
    fi

    echo ""
    echo -e "  \033[1;37mTotal connected: ${#CURRENT[@]}\033[0m"
    echo ""
    echo -e "  \033[1;36m───── RECENT EVENTS ─────\033[0m"

    if [ -f "$EVENTS_LOG" ]; then
        tail -8 "$EVENTS_LOG" | while IFS= read -r line; do
            if echo "$line" | grep -q "CONNECTED"; then
                echo -e "  \033[1;32m${line}\033[0m"
            elif echo "$line" | grep -q "DISCONNECTED"; then
                echo -e "  \033[1;31m${line}\033[0m"
            else
                echo -e "  \033[2m${line}\033[0m"
            fi
        done
    fi

    sleep 2
done
