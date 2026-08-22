#!/data/data/com.termux/files/usr/bin/bash
# Status Check — AVB / DM-Verity / SELinux / Bootloader
# by@arriRgb31
#
# Output format:
#   You AVB is flags [X] (value)
#   You DM-Verity is [enabled/disabled]
#   You SELinux is [enforcing/permissive]
#   You Bootloader is [unlocked/locked]

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh" 2>/dev/null

# ============================================
# READ FUNCTIONS
# ============================================

read_vbmeta_flags() {
    local part="${1:-vbmeta}"
    local block="/dev/block/by-name/$part"
    [[ ! -e "$block" ]] && echo "0x????????" && return
    if command -v su &>/dev/null && su -c "id" 2>/dev/null | grep -q "uid=0"; then
        local hex=$(su -c "dd if=$block bs=1 count=4 skip=12 2>/dev/null" 2>/dev/null | xxd -p 2>/dev/null)
        [[ -n "$hex" ]] && echo "0x${hex}" || echo "0x????????"
    else
        # Non-root: try via ADB
        local hex=$(adb shell "dd if=/dev/block/by-name/$part bs=1 count=4 skip=12 2>/dev/null" 2>/dev/null | xxd -p 2>/dev/null)
        [[ -n "$hex" ]] && echo "0x${hex}" || echo "0x????????"
    fi
}

read_vbmeta_flags_dec() {
    local hex=$(read_vbmeta_flags "$1")
    printf "%d" "$hex" 2>/dev/null || echo "0"
}

read_selinux() {
    if command -v su &>/dev/null && su -c "id" 2>/dev/null | grep -q "uid=0"; then
        su -c "getenforce" 2>/dev/null || echo "Unknown"
    else
        adb shell getenforce 2>/dev/null || echo "Unknown"
    fi
}

read_selinux_enforce() {
    if command -v su &>/dev/null && su -c "id" 2>/dev/null | grep -q "uid=0"; then
        su -c "cat /sys/fs/selinux/enforce" 2>/dev/null || echo "?"
    else
        echo "?"
    fi
}

read_dmverity() {
    # Check fstab for dm-verity entry
    local fstab=""
    if command -v su &>/dev/null && su -c "id" 2>/dev/null | grep -q "uid=0"; then
        fstab=$(su -c "cat /vendor/etc/fstab.ums9230" 2>/dev/null || \
                su -c "cat /vendor/etc/fstab" 2>/dev/null || \
                su -c "cat /proc/boot/fstab" 2>/dev/null)
    else
        fstab=$(adb shell "cat /vendor/etc/fstab.ums9230 2>/dev/null || cat /vendor/etc/fstab 2>/dev/null" 2>/dev/null)
    fi

    if echo "$fstab" | grep -qi "verify"; then
        echo "enabled"
    elif echo "$fstab" | grep -qi "avb"; then
        echo "enabled (avb)"
    else
        echo "disabled"
    fi
}

read_bootloader() {
    local locked=$(getprop ro.boot.flash.locked 2>/dev/null || echo "unknown")
    local dev_state=$(getprop ro.boot.vbmeta.device_state 2>/dev/null || echo "unknown")

    if [[ "$locked" == "0" ]] || [[ "$dev_state" == "unlocked" ]]; then
        echo "unlocked"
    elif [[ "$locked" == "1" ]]; then
        echo "locked"
    else
        echo "unknown"
    fi
}

read_slot() {
    getprop ro.boot.slot_suffix 2>/dev/null || echo "_?"
}

read_device() {
    getprop ro.product.model 2>/dev/null || echo "Unknown"
}

read_android() {
    getprop ro.build.version.release 2>/dev/null || echo "?"
}

# ============================================
# MAIN STATUS DISPLAY
# ============================================

show_status() {
    local vbmeta_flags=$(read_vbmeta_flags "vbmeta")
    local vbmeta_dec=$(read_vbmeta_flags_dec "vbmeta")
    local dmverity=$(read_dmverity)
    local selinux=$(read_selinux)
    local bootloader=$(read_bootloader)
    local slot=$(read_slot)
    local device=$(read_device)
    local android=$(read_android)

    HEADER "Status Check — $device Android $android"
    echo ""

    # AVB
    if [[ "$vbmeta_flags" == "0x00000000" ]]; then
        echo -e "  You AVB is flags ${GREEN}$vbmeta_flags${NC} (default — verity ON)"
    elif [[ "$vbmeta_flags" == "0x00000001" ]]; then
        echo -e "  You AVB is flags ${YELLOW}$vbmeta_flags${NC} (verity OFF)"
    elif [[ "$vbmeta_flags" == "0x00000009" ]]; then
        echo -e "  You AVB is flags ${RED}$vbmeta_flags${NC} (full bypass)"
    else
        echo -e "  You AVB is flags ${WHITE}$vbmeta_flags${NC}"
    fi

    # DM-Verity
    if [[ "$dmverity" == "enabled" ]] || [[ "$dmverity" == "enabled (avb)" ]]; then
        echo -e "  You DM-Verity is ${GREEN}$dmverity${NC}"
    else
        echo -e "  You DM-Verity is ${YELLOW}$dmverity${NC}"
    fi

    # SELinux
    local selinux_lower=$(echo "$selinux" | tr '[:upper:]' '[:lower:]')
    if [[ "$selinux_lower" == "enforcing" ]]; then
        echo -e "  You SELinux is ${GREEN}$selinux${NC}"
    elif [[ "$selinux_lower" == "permissive" ]]; then
        echo -e "  You SELinux is ${YELLOW}$selinux${NC}"
    else
        echo -e "  You SELinux is ${WHITE}$selinux${NC}"
    fi

    # Bootloader
    if [[ "$bootloader" == "unlocked" ]]; then
        echo -e "  You Bootloader is ${YELLOW}$bootloader${NC}"
    elif [[ "$bootloader" == "locked" ]]; then
        echo -e "  You Bootloader is ${GREEN}$bootloader${NC}"
    else
        echo -e "  You Bootloader is ${WHITE}$bootloader${NC}"
    fi

    echo -e "  You Slot is ${WHITE}$slot${NC}"
    echo ""

    # Flags detail
    echo -e "  ${CYAN}VBMeta flags detail:${NC}"
    echo -e "    vbmeta:        $(read_vbmeta_flags 'vbmeta')"
    echo -e "    vbmeta_system: $(read_vbmeta_flags 'vbmeta_system')"
    echo -e "    vbmeta_vendor: $(read_vbmeta_flags 'vbmeta_vendor')"
    echo ""

    # SELinux detail
    local enforce=$(read_selinux_enforce)
    echo -e "  ${CYAN}SELinux detail:${NC}"
    echo -e "    getenforce:    $selinux"
    echo -e "    enforce file:  $enforce"
    echo ""
}

# ============================================
# STATUS WITH STOCK COMPARISON
# ============================================

show_status_compare() {
    local stock_dir="${1:-$HOME/RMX3760-backup/stock}"
    local latest_stock=$(ls -dt "$stock_dir"/stock_* 2>/dev/null | head -1)

    HEADER "Status Check + Stock Comparison"
    echo ""

    if [[ -z "$latest_stock" ]] || [[ ! -d "$latest_stock" ]]; then
        echo -e "  ${YELLOW}Tidak ada stock backup — tampilkan status saja${NC}"
        echo ""
        show_status
        return
    fi

    echo -e "  ${CYAN}Current vs Stock ($(basename $latest_stock)):${NC}"
    echo ""

    local cur_vbmeta=$(read_vbmeta_flags "vbmeta")
    local stk_vbmeta=$(cat "$latest_stock/vbmeta/flags_vbmeta.txt" 2>/dev/null || echo "unknown")
    local cur_selinux=$(read_selinux)
    local stk_selinux=$(cat "$latest_stock/selinux/getenforce.txt" 2>/dev/null || echo "unknown")
    local cur_dmverity=$(read_dmverity)

    echo -e "  AVB flags:     ${WHITE}$cur_vbmeta${NC} (stock: ${GRAY}$stk_vbmeta${NC})"
    echo -e "  DM-Verity:     ${WHITE}$cur_dmverity${NC}"
    echo -e "  SELinux:       ${WHITE}$cur_selinux${NC} (stock: ${GRAY}$stk_selinux${NC})"
    echo -e "  Bootloader:    ${WHITE}$(read_bootloader)${NC}"
    echo ""

    # Show diff
    if [[ "$cur_vbmeta" != "$stk_vbmeta" ]] && [[ "$stk_vbmeta" != "unknown" ]]; then
        echo -e "  ${YELLOW}⚠ AVB flags berubah dari stock!${NC}"
    fi
    if [[ "$cur_selinux" != "$stk_selinux" ]] && [[ "$stk_selinux" != "unknown" ]]; then
        echo -e "  ${YELLOW}⚠ SELinux berubah dari stock!${NC}"
    fi
    if [[ "$cur_dmverity" != "enabled" ]]; then
        echo -e "  ${YELLOW}⚠ DM-Verity non-aktif dari stock!${NC}"
    fi
    echo ""
}

# ============================================
# MENU
# ============================================

menu_status() {
    while true; do
        BANNER
        echo -e "${MAGENTA}=== Status Check ===${NC}"
        echo ""
        echo "  1) Status (current)"
        echo "  2) Status + Stock Compare"
        echo "  3) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) show_status ;;
            2) show_status_compare ;;
            3) return ;;
        esac
    done
}
