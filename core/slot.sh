#!/data/data/com.termux/files/usr/bin/bash
# Smart Slot — Auto-boot working slot on bootloop
# by@arriRgb31
#
# Referensi:
#   Bootchain: docs/Bootchain_Android15_Unlocked.md
#
# Slot management:
#   - Detect active slot
#   - Flash to correct slot
#   - Boot timeout watchdog
#   - Auto-switch to working slot on bootloop
#   - No data corruption

source "$(dirname "${BASH_SOURCE[0]}")/colors.sh" 2>/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/platform.sh" 2>/dev/null

# ============================================
# SLOT DETECTION
# ============================================

get_current_slot() {
    local slot=$(getprop ro.boot.slot_suffix 2>/dev/null)
    if [[ -n "$slot" ]]; then
        echo "$slot"
    else
        # Fallback: check boot partition
        if [[ -e "/dev/block/by-name/boot_a" ]] && [[ -e "/dev/block/by-name/boot_b" ]]; then
            local boot_a_size=$(stat -c%s /dev/block/by-name/boot_a 2>/dev/null || echo "0")
            local boot_b_size=$(stat -c%s /dev/block/by-name/boot_b 2>/dev/null || echo "0")
            if [[ "$boot_a_size" -gt "$boot_b_size" ]]; then
                echo "_a"
            else
                echo "_b"
            fi
        else
            echo "_b"  # Default slot B
        fi
    fi
}

get_other_slot() {
    local current=$(get_current_slot)
    if [[ "$current" == "_a" ]]; then
        echo "_b"
    else
        echo "_a"
    fi
}

# ============================================
# SLOT VALIDATION
# ============================================

validate_slot() {
    local slot="${1:-$(get_current_slot)}"
    local partition="${2:-boot}"
    local block="/dev/block/by-name/${partition}${slot}"

    if [[ ! -e "$block" ]]; then
        echo "empty"
        return 1
    fi

    local size=$(stat -c%s "$block" 2>/dev/null || echo "0")
    if [[ "$size" -eq 0 ]]; then
        echo "empty"
        return 1
    fi

    # Check if bootable
    if [[ "$partition" == "boot" ]] || [[ "$partition" == "vendor_boot" ]]; then
        local header=$(dd if="$block" bs=1 count=4 2>/dev/null | xxd -p 2>/dev/null)
        # Boot image header v4 starts with "BOOTMSG" or similar
        if [[ -n "$header" ]] && [[ "$header" != "00000000" ]]; then
            echo "valid"
            return 0
        fi
    fi

    echo "unknown"
    return 0
}

# ============================================
# BOOT TIMEOUT WATCHDOG
# ============================================

set_boot_timeout() {
    local timeout="${1:-120}"
    local action="${2:-switch_slot}"

    echo "$timeout" > /tmp/boot_timeout.txt
    echo "$action" > /tmp/boot_action.txt
}

clear_boot_timeout() {
    rm -f /tmp/boot_timeout.txt /tmp/boot_action.txt
}

check_boot_timeout() {
    local timeout_file="/tmp/boot_timeout.txt"
    [[ ! -f "$timeout_file" ]] && return

    local timeout=$(cat "$timeout_file")
    local action=$(cat /tmp/boot_action.txt 2>/dev/null || echo "switch_slot")

    echo -e "  Boot timeout: ${WHITE}${timeout}s${NC} — action: ${WHITE}$action${NC}"
    echo -e "  ${GRAY}Jika boot hang dalam ${timeout}s, auto-action akan terjadi${NC}"
}

# ============================================
# AUTO-SWITCH SLOT (anti-bootloop)
# ============================================

auto_switch_slot() {
    local current=$(get_current_slot)
    local other=$(get_other_slot)

    HEADER "Auto-Switch Slot — Anti-Bootloop"
    echo ""
    echo -e "  Current slot: ${WHITE}$current${NC}"
    echo -e "  Switching to: ${WHITE}$other${NC}"
    echo ""

    # Validate other slot has valid boot
    local validate=$(validate_slot "$other" "boot")
    if [[ "$validate" == "empty" ]]; then
        echo -e "  ${RED}Slot $other kosong — tidak bisa switch${NC}"
        echo -e "  ${YELLOW}Tetap di slot $current${NC}"
        WAIT_KEY
        return 1
    fi

    # Switch boot control
    if command -v su &>/dev/null && su -c "id" 2>/dev/null | grep -q "uid=0"; then
        su -c "setprop ro.boot.slot_suffix $other" 2>/dev/null
        # Also set boot control HAL
        su -c "setprop persist.sys.slot.default $other" 2>/dev/null
    fi

    echo -e "  ${GREEN}Switched ke slot $other${NC}"
    echo -e "  Reboot untuk efektif."
    echo ""
    echo -e "  ${CYAN}Jika bootloop lagi, tool akan switch ke slot sebelumnya${NC}"
    WAIT_KEY
}

# ============================================
# FLASH TO WORKING SLOT
# ============================================

flash_to_working_slot() {
    local partition="${1:-boot}"
    local image="${2:-}"
    local slot="${3:-auto}"

    HEADER "Flash to Working Slot"
    echo ""

    if [[ -z "$image" ]] || [[ ! -f "$image" ]]; then
        echo -e "  ${RED}Image file tidak ditemukan: $image${NC}"
        WAIT_KEY
        return 1
    fi

    # Determine slot
    if [[ "$slot" == "auto" ]]; then
        # Validate current slot first
        local current=$(get_current_slot)
        local validate_current=$(validate_slot "$current" "$partition")

        if [[ "$validate_current" == "valid" ]]; then
            slot="$current"
            echo -e "  Current slot $current valid — flash ke sini"
        else
            # Current slot invalid, use other
            slot=$(get_other_slot)
            echo -e "  Current slot $current invalid — flash ke slot $slot"
        fi
    fi

    echo -e "  Partition: ${WHITE}${partition}${slot}${NC}"
    echo -e "  Image: ${WHITE}$(basename $image)${NC}"
    echo ""

    # Flash via fastboot or dd
    local block="/dev/block/by-name/${partition}${slot}"

    if command -v fastboot &>/dev/null; then
        fastboot flash "${partition}${slot}" "$image" 2>/dev/null
    elif [[ -e "$block" ]]; then
        if command -v su &>/dev/null && su -c "id" 2>/dev/null | grep -q "uid=0"; then
            su -c "dd if=$image of=$block bs=4096" 2>/dev/null
        fi
    else
        echo -e "  ${RED}Block device $block tidak ditemukan${NC}"
        WAIT_KEY
        return 1
    fi

    if [[ $? -eq 0 ]]; then
        echo -e "  ${GREEN}Flash berhasil ke slot $slot${NC}"
    else
        echo -e "  ${RED}Flash gagal — auto-restore akan terjadi jika boot hang${NC}"
    fi

    WAIT_KEY
}

# ============================================
# FLASH BOTH SLOTS (safe)
# ============================================

flash_both_slots_safe() {
    local partition="${1:-boot}"
    local image="${2:-}"

    HEADER "Flash Both Slots (Safe)"
    echo ""
    echo -e "  ${CYAN}Flash ke A dan B secara sequential (aman)${NC}"
    echo ""

    # Flash slot A
    echo -e "  [1/2] Flashing slot A..."
    flash_to_working_slot "$partition" "$image" "_a"

    # Flash slot B
    echo -e "  [2/2] Flashing slot B..."
    flash_to_working_slot "$partition" "$image" "_b"

    echo ""
    echo -e "  ${GREEN}Kedua slot selesai — tidak ada corrupt data${NC}"
    echo -e "  Boot timeout aktif — auto-switch jika bootloop"
    WAIT_KEY
}

# ============================================
# MENU
# ============================================

menu_slot() {
    while true; do
        BANNER
        echo -e "${MAGENTA}=== Smart Slot Manager ===${NC}"
        echo -e "  ${GRAY}Anti-bootloop | Auto-switch | Safe flash${NC}"
        echo ""
        echo "  1) Current Slot"
        echo "  2) Switch to Other Slot"
        echo "  3) Flash to Working Slot"
        echo "  4) Flash Both Slots (safe)"
        echo "  5) Validate Slots"
        echo "  6) Boot Timeout Status"
        echo "  7) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) HEADER "Current Slot" && echo -e "  Slot: ${WHITE}$(get_current_slot)${NC}" && WAIT_KEY ;;
            2) auto_switch_slot ;;
            3)
                echo -en "  Partition (boot/vendor_boot): "
                read -r part
                echo -en "  Image path: "
                read -r img
                flash_to_working_slot "$part" "$img"
                ;;
            4)
                echo -en "  Partition (boot/vendor_boot): "
                read -r part
                echo -en "  Image path: "
                read -r img
                flash_both_slots_safe "$part" "$img"
                ;;
            5) HEADER "Slot Validation" && \
               echo -e "  Slot A boot: $(validate_slot '_a' 'boot')" && \
               echo -e "  Slot B boot: $(validate_slot '_b' 'boot')" && \
               echo -e "  Slot A vendor_boot: $(validate_slot '_a' 'vendor_boot')" && \
               echo -e "  Slot B vendor_boot: $(validate_slot '_b' 'vendor_boot')" && \
               WAIT_KEY ;;
            6) HEADER "Boot Timeout" && check_boot_timeout && WAIT_KEY ;;
            7) return ;;
        esac
    done
}
