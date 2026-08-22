#!/data/data/com.termux/files/usr/bin/bash
# Runtime Logging Tools — Realme C53 RMX3760 Android 15
# by@arriRgb31
#
# Referensi:
#   - AOSP Logging: https://source.android.com/docs/core/tests/debug/logging
#   - Logcat: https://developer.android.com/studio/debug/logcat

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/colors.sh"
source "$SCRIPT_DIR/../core/device.sh"

LOG_DIR="$HOME/RMX3760-tools/logs"

logcat_full() {
    HEADER "Full Logcat Dump"
    mkdir -p "$LOG_DIR"
    local file="$LOG_DIR/logcat_$(date +%Y%m%d_%H%M%S).log"
    INFO "Menyimpan full logcat ke $file..."
    if is_root; then
        su -c "logcat -d -v threadtime" > "$file" 2>/dev/null
    else
        logcat -d -v threadtime > "$file" 2>/dev/null
    fi
    local lines=$(wc -l < "$file")
    OK "Logcat saved: $file ($lines lines)"
    WAIT_KEY
}

logcat_filtered() {
    HEADER "Logcat Filtered"
    echo "  Filter options:"
    echo "    1) Errors only (*:E)"
    echo "    2) Warnings + Errors (*:W)"
    echo "    3) Verbose (*:V)"
    echo "    4) By tag (custom)"
    echo "    5) By PID"
    echo ""
    echo -en "  Pilihan [1-5]: "
    read -r fchoice

    local filter=""
    case $fchoice in
        1) filter="*:E" ;;
        2) filter="*:W" ;;
        3) filter="*:V" ;;
        4) echo -en "  Tag (regex): "; read -r tag; filter="$tag:V" ;;
        5) echo -en "  PID: "; read -r pid; filter="--pid=$pid" ;;
        *) FAIL "Invalid"; return ;;
    esac

    mkdir -p "$LOG_DIR"
    local file="$LOG_DIR/logcat_filtered_$(date +%Y%m%d_%H%M%S).log"
    INFO "Filter: $filter"
    if is_root; then
        su -c "logcat -d -v threadtime $filter" > "$file" 2>/dev/null
    else
        logcat -d -v threadtime "$filter" > "$file" 2>/dev/null
    fi
    OK "Filtered log saved: $file"
    local lines=$(wc -l < "$file")
    echo -e "  Lines: $lines"
    WAIT_KEY
}

dmesg_log() {
    HEADER "Kernel Ring Buffer (dmesg)"
    mkdir -p "$LOG_DIR"
    local file="$LOG_DIR/dmesg_$(date +%Y%m%d_%H%M%S).log"
    if is_root; then
        su -c "dmesg" > "$file" 2>/dev/null
    else
        dmesg > "$file" 2>/dev/null
    fi
    local lines=$(wc -l < "$file")
    OK "dmesg saved: $file ($lines lines)"
    WAIT_KEY
}

logcat_recovery() {
    HEADER "Recovery Logs"
    mkdir -p "$LOG_DIR"
    local file="$LOG_DIR/recovery_$(date +%Y%m%d_%H%M%S).log"

    # Try multiple recovery log locations
    if is_root; then
        {
            echo "=== /cache/recovery/last_log ==="
            cat /cache/recovery/last_log 2>/dev/null || echo "(not found)"
            echo ""
            echo "=== /data/misc/recovery/last_log ==="
            cat /data/misc/recovery/last_log 2>/dev/null || echo "(not found)"
            echo ""
            echo "=== logcat -b all recovery ==="
            su -c "logcat -d -b all -v threadtime" 2>/dev/null | grep -iE "recovery|twrp" || echo "(no recovery logs)"
        } > "$file" 2>/dev/null
    fi
    OK "Recovery logs saved: $file"
    WAIT_KEY
}

dumpsys_all() {
    HEADER "Dumpsys — Key Services"
    mkdir -p "$LOG_DIR"
    local file="$LOG_DIR/dumpsys_$(date +%Y%m%d_%H%M%S).log"

    local services=("activity" "package" "power" "battery" "meminfo" "cpuinfo" "diskstats" "mount" "mount_dfs" "input" "display" "surface_flinger" "init")

    for svc in "${services[@]}"; do
        INFO "Dumping $svc..."
        echo "=== $svc ===" >> "$file"
        dumpsys "$svc" >> "$file" 2>/dev/null
        echo "" >> "$file"
    done
    OK "Dumpsys saved: $file"
    WAIT_KEY
}

prop_dump() {
    HEADER "System Properties Dump"
    mkdir -p "$LOG_DIR"
    local file="$LOG_DIR/props_$(date +%Y%m%d_%H%M%S).log"

    if is_root; then
        su -c "getprop" > "$file" 2>/dev/null
    else
        getprop > "$file" 2>/dev/null
    fi
    local lines=$(wc -l < "$file")
    OK "Properties saved: $file ($lines props)"
    WAIT_KEY
}

boot_log() {
    HEADER "Boot Sequence Log"
    mkdir -p "$LOG_DIR"
    local file="$LOG_DIR/boot_$(date +%Y%m%d_%H%M%S).log"

    {
        echo "=== KERNEL BOOT (dmesg) ==="
        su -c "dmesg" 2>/dev/null
        echo ""
        echo "=== EARLY BOOT PROPS ==="
        su -c "getprop" 2>/dev/null | grep -E "^(\[ro\.\]|\[sys\.\]|\[persist\.\])"
        echo ""
        echo "=== INIT SERVICES ==="
        su -c "getprop init.svc.*" 2>/dev/null
        echo ""
        echo "=== LOGCAT (last 5000 lines) ==="
        su -c "logcat -d -v threadtime -t 5000" 2>/dev/null
    } > "$file" 2>/dev/null
    OK "Boot log saved: $file"
    WAIT_KEY
}

save_all_logs() {
    HEADER "Save ALL Logs"
    mkdir -p "$LOG_DIR"
    local dir="$LOG_DIR/all_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$dir"

    INFO "Saving logcat..."
    su -c "logcat -d -v threadtime" > "$dir/logcat.log" 2>/dev/null

    INFO "Saving dmesg..."
    su -c "dmesg" > "$dir/dmesg.log" 2>/dev/null

    INFO "Saving props..."
    su -c "getprop" > "$dir/props.log" 2>/dev/null

    INFO "Saving init services..."
    su -c "getprop init.svc.*" > "$dir/services.log" 2>/dev/null

    INFO "Saving recovery logs..."
    cat /cache/recovery/last_log > "$dir/last_log.log" 2>/dev/null

    OK "All logs saved to: $dir"
    ls -la "$dir"
    WAIT_KEY
}

menu_logger() {
    while true; do
        BANNER
        echo -e "${MAGENTA}═══ Runtime Logging ═══${NC}"
        echo ""
        echo "  1) Full Logcat dump"
        echo "  2) Logcat filtered"
        echo "  3) dmesg (kernel ring buffer)"
        echo "  4) Recovery logs"
        echo "  5) Dumpsys (key services)"
        echo "  6) System properties"
        echo "  7) Boot sequence log"
        echo "  8) Save ALL logs"
        echo "  9) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) logcat_full ;;
            2) logcat_filtered ;;
            3) dmesg_log ;;
            4) logcat_recovery ;;
            5) dumpsys_all ;;
            6) prop_dump ;;
            7) boot_log ;;
            8) save_all_logs ;;
            9) return ;;
        esac
    done
}

menu_logger
