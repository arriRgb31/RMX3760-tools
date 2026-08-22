#!/data/data/com.termux/files/usr/bin/bash
# Slot Selection — Flash A / B / Both
# by@arriRgb31
#
# Referensi:
#   - Bootchain: Bootchain_Android15_Unlocked.md
#   - Virtual A/B: https://source.android.com/docs/core/ota/virtual_ab
#
# Unisoc UMS9230: boot_a/b, vendor_boot_a/b, vbmeta_a/b
# Detect slot aktif via: getprop ro.boot.slot_suffix

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/colors.sh"

# Get current active slot (_a or _b)
get_current_slot() {
    local slot=$(getprop ro.boot.slot_suffix 2>/dev/null)
    if [[ -z "$slot" ]]; then
        # Fallback: check by-name
        if [[ -e /dev/block/by-name/boot_a ]]; then
            slot=$(ls -la /dev/block/by-name/boot 2>/dev/null | grep -o "_[ab]$")
        fi
    fi
    echo "$slot"
}

# Get opposite slot
get_opposite_slot() {
    local current=$(get_current_slot)
    if [[ "$current" == "_a" ]]; then
        echo "_b"
    else
        echo "_a"
    fi
}

# Show slot status
show_slot_status() {
    HEADER "Slot Status"
    local current=$(get_current_slot)
    local opposite=$(get_opposite_slot)

    echo -e "  Active slot:    ${WHITE}$current${NC}"
    echo -e "  Opposite slot:  ${WHITE}$opposite${NC}"

    # Check which slots have boot images
    for s in _a _b; do
        if [[ -e "/dev/block/by-name/boot${s}" ]]; then
            local size=$(blockdev --getsize64 "/dev/block/by-name/boot${s}" 2>/dev/null)
            echo -e "  boot${s}:       ${WHITE}$((size / 1024 / 1024)) MB${NC}"
        fi
        if [[ -e "/dev/block/by-name/vendor_boot${s}" ]]; then
            local size=$(blockdev --getsize64 "/dev/block/by-name/vendor_boot${s}" 2>/dev/null)
            echo -e "  vendor_boot${s}: ${WHITE}$((size / 1024 / 1024)) MB${NC}"
        fi
    done
}

# Prompt user to select slot
# Returns selected slots in SELECTED_SLOTS array
select_slot() {
    local purpose="${1:-flash}"  # flash, patch, etc.
    SELECTED_SLOTS=()

    HEADER "Pilih Slot untuk $purpose"
    local current=$(get_current_slot)
    echo -e "  Current slot: ${WHITE}$current${NC}"
    echo ""
    echo "  1) Slot A"
    echo "  2) Slot B (current)"
    echo "  3) Both (A + B)"
    echo ""
    echo -en "  Pilihan [1/2/3]: "
    read -r choice

    case $choice in
        1) SELECTED_SLOTS=("_a") ;;
        2) SELECTED_SLOTS=("_b") ;;
        3|*) SELECTED_SLOTS=("_a" "_b") ;;
    esac

    echo -e "  Selected: ${WHITE}${SELECTED_SLOTS[*]}${NC}"
}

# Flash to selected slots
# Usage: flash_to_slot <partition_base> <image_file>
# Example: flash_to_slot boot /tmp/magisk_patched_boot.img
flash_to_slot() {
    local part_base="$1"
    local image="$2"

    if [[ ! -f "$image" ]]; then
        FAIL "Image tidak ditemukan: $image"
        return 1
    fi

    if [[ ${#SELECTED_SLOTS[@]} -eq 0 ]]; then
        select_slot "$part_base"
    fi

    for slot in "${SELECTED_SLOTS[@]}"; do
        local partition="${part_base}${slot}"
        INFO "Flashing $partition..."
        fastboot flash "$partition" "$image" 2>&1
        if [[ $? -eq 0 ]]; then
            OK "Flashed: $partition"
        else
            FAIL "Flash gagal: $partition"
        fi
    done
}

# Flash to selected slots via fastboot (unlocked)
flash_unlocked() {
    local part_base="$1"
    local image="$2"
    flash_to_slot "$part_base" "$image"
}

# Flash via CVE download mode (non-unlocked)
# This requires the device in FDL2 mode and CVE tool on PC
flash_cve() {
    local part_base="$1"
    local image="$2"

    if [[ ! -f "$image" ]]; then
        FAIL "Image tidak ditemukan: $image"
        return 1
    fi

    if [[ ${#SELECTED_SLOTS[@]} -eq 0 ]]; then
        select_slot "$part_base"
    fi

    INFO "CVE flash mode — device harus di FDL2 (download mode)"
    for slot in "${SELECTED_SLOTS[@]}"; do
        local partition="${part_base}${slot}"
        INFO "Target: $partition"
        echo "  Jalankan CVE tool di PC:"
        echo "    ./ums9230_Realme_C53_RMX3760_RMX3762 --partition $partition --image $image"
    done
}
