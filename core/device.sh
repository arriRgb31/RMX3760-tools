#!/data/data/com.termux/files/usr/bin/bash
# Device detection and verification for RMX3760
# by@arriRgb31
# Sources:
#   - Bootchain_Android15_Unlocked.md (live device data)
#   - /proc/cmdline, /proc/bootconfig, getprop

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/colors.sh"

detect_device() {
    DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null)
    DEVICE_CODENAME=$(getprop ro.product.device 2>/dev/null)
    DEVICE_SOC=$(getprop ro.soc.model 2>/dev/null)
    DEVICE_PLATFORM=$(getprop ro.board.platform 2>/dev/null)
    DEVICE_HARDWARE=$(getprop ro.hardware 2>/dev/null)
    DEVICE_ANDROID=$(getprop ro.build.version.release 2>/dev/null)
    DEVICE_SDK=$(getprop ro.build.version.sdk 2>/dev/null)
    DEVICE_BOOTLOADER=$(getprop ro.boot.flash.locked 2>/dev/null)
    DEVICE_SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null)
    DEVICE_SERIAL=$(getprop ro.serialno 2>/dev/null)
    DEVICE_FINGERPRINT=$(getprop ro.build.fingerprint 2>/dev/null)
    DEVICE_KERNEL=$(uname -r 2>/dev/null)
    DEVICE_VERIFIED=$(getprop ro.boot.verifiedbootstate 2>/dev/null)
    DEVICE_ROOT=$(su -c "id" 2>/dev/null | grep -c "uid=0")
}

verify_device() {
    HEADER "Device Verification"
    
    local errors=0
    
    if [[ "$DEVICE_MODEL" == "RMX3760" ]]; then
        OK "Model: $DEVICE_MODEL"
    else
        FAIL "Model: $DEVICE_MODEL (expected RMX3760)"
        ((errors++))
    fi
    
    if [[ "$DEVICE_SOC" == *"UMS9230"* ]]; then
        OK "SoC: $DEVICE_SOC"
    else
        FAIL "SoC: $DEVICE_SOC (expected UMS9230)"
        ((errors++))
    fi
    
    if [[ "$DEVICE_ANDROID" == "15" ]]; then
        OK "Android: $DEVICE_ANDROID (API $DEVICE_SDK)"
    else
        FAIL "Android: $DEVICE_ANDROID (expected 15)"
        ((errors++))
    fi
    
    if [[ "$DEVICE_SLOT" == "_b" || "$DEVICE_SLOT" == "_a" ]]; then
        OK "Active slot: $DEVICE_SLOT"
    else
        FAIL "Slot suffix: $DEVICE_SLOT"
        ((errors++))
    fi
    
    if [[ "$DEVICE_BOOTLOADER" == "0" ]]; then
        OK "Bootloader: UNLOCKED"
    elif [[ "$DEVICE_BOOTLOADER" == "1" ]]; then
        WARN "Bootloader: LOCKED (may be spoofed by Magisk)"
    fi
    
    echo ""
    if [[ $errors -eq 0 ]]; then
        OK "Device verified: Realme C53 RMX3760 — Android 15 — Unisoc UMS9230"
    else
        FAIL "$errors verification errors detected"
    fi
    
    return $errors
}

print_device_info() {
    HEADER "Device Information"
    echo -e "  Model:          ${WHITE}$DEVICE_MODEL${NC}"
    echo -e "  Codename:       ${WHITE}$DEVICE_CODENAME${NC}"
    echo -e "  SoC:            ${WHITE}$DEVICE_SOC${NC}"
    echo -e "  Platform:       ${WHITE}$DEVICE_PLATFORM${NC}"
    echo -e "  Hardware:       ${WHITE}$DEVICE_HARDWARE${NC}"
    echo -e "  Android:        ${WHITE}$DEVICE_ANDROID (API $DEVICE_SDK)${NC}"
    echo -e "  Kernel:         ${WHITE}$DEVICE_KERNEL${NC}"
    echo -e "  Serial:         ${WHITE}$DEVICE_SERIAL${NC}"
    echo -e "  Slot:           ${WHITE}$DEVICE_SLOT${NC}"
    echo -e "  Bootloader:     ${WHITE}$([ "$DEVICE_BOOTLOADER" == "0" ] && echo "UNLOCKED" || echo "LOCKED")${NC}"
    echo -e "  Verified boot:  ${WHITE}$DEVICE_VERIFIED${NC}"
    echo -e "  Root:           ${WHITE}$([ "$DEVICE_ROOT" -gt 0 ] && echo "YES (uid=0)" || echo "NO")${NC}"
    echo -e "  Fingerprint:    ${GRAY}$DEVICE_FINGERPRINT${NC}"
}

is_root() {
    [[ $(su -c "id" 2>/dev/null | grep -c "uid=0") -gt 0 ]]
}

require_root() {
    if ! is_root; then
        FAIL "Root access required. Jalankan sebagai root (su)."
        return 1
    fi
}

require_unlocked() {
    detect_device
    if [[ "$DEVICE_BOOTLOADER" == "1" ]]; then
        FAIL "Bootloader locked. Unlock terlebih dahulu."
        return 1
    fi
}

# Partition map — live from /dev/block/by-name/*
get_partition_map() {
    echo -e "${HEADER}Partition Map (live from /dev/block/by-name)${NC}"
    if is_root; then
        su -c "ls -la /dev/block/by-name/" 2>/dev/null | grep -v "^total" | grep -v "^d"
    else
        FAIL "Root required for partition access"
    fi
}

get_partition_size() {
    local part="$1"
    if is_root; then
        local size=$(su -c "blockdev --getsize64 /dev/block/by-name/$part" 2>/dev/null)
        if [[ -n "$size" ]]; then
            echo "$((size / 1024 / 1024)) MB"
        else
            echo "unknown"
        fi
    fi
}
