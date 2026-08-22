#!/data/data/com.termux/files/usr/bin/bash
# AVB Patch/Unpatch — Realme C53 RMX3760 Android 15
# by@arriRgb31
#
# Referensi:
#   - AVB bypass: https://github.com/TheGammaSqueeze/UnisocBypass
#   - CVE-2022-38694: https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader
#   - Bootchain: Bootchain_Android15_Unlocked.md
#
# AVB Flags (offset 0x3C, 4 bytes):
#   Level 1: Disable verity (bit 0 = 0x01) → system/vendor/product dm-verity off
#   Level 2: Disable verification (bit 0, all vbmeta* = 0x01) → no AVB check
#   Level 3: Full bypass (bit 0+3 = 0x09) → no AVB + no rollback protection

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/colors.sh"
source "$SCRIPT_DIR/../core/device.sh"

BACKUP_DIR="$HOME/RMX3760-tools/backups/avb"

read_vbmeta_flags() {
    local part="${1:-vbmeta}"
    local block="/dev/block/by-name/$part"
    if [[ ! -e "$block" ]]; then
        echo "N/A"
        return
    fi
    if is_root; then
        local hex=$(su -c "dd if=$block bs=1 count=4 skip=0x3B 2>/dev/null | xxd -p" 2>/dev/null)
        echo "0x$hex"
    else
        echo "need_root"
    fi
}

show_avb_status() {
    HEADER "AVB Status"
    detect_device

    local vflags=$(read_vbmeta_flags "vbmeta")
    local vsflags=$(read_vbmeta_flags "vbmeta_system")
    local vvflags=$(read_vbmeta_flags "vbmeta_vendor")

    echo -e "  vbmeta flags:        ${WHITE}$vflags${NC}"
    echo -e "  vbmeta_system flags: ${WHITE}$vsflags${NC}"
    echo -e "  vbmeta_vendor flags: ${WHITE}$vvflags${NC}"

    if [[ -f /proc/bootconfig ]]; then
        local bs=$(grep "androidboot.verifiedbootstate" /proc/bootconfig | cut -d'"' -f2)
        local bd=$(grep "androidboot.vbmeta.device_state" /proc/bootconfig | cut -d'"' -f2)
        echo -e "\n  Boot state:          ${WHITE}$bs${NC}"
        echo -e "  Device state:        ${WHITE}$bd${NC}"
    fi
    WAIT_KEY
}

do_backup() {
    mkdir -p "$BACKUP_DIR"
    local part="$1"
    local ts=$(date +%Y%m%d_%H%M%S)
    if is_root; then
        su -c "dd if=/dev/block/by-name/$part of=$BACKUP_DIR/${part}_${ts}.img bs=4096" 2>/dev/null
        OK "Backup: $BACKUP_DIR/${part}_${ts}.img"
    fi
}

patch_vbmeta() {
    local part="$1"
    local mask="$2"
    local block="/dev/block/by-name/$part"

    if [[ ! -e "$block" ]]; then
        WARN "Partition $part tidak ditemukan"
        return 1
    fi

    INFO "Backing up $part..."
    do_backup "$part"

    local old_flags=$(read_vbmeta_flags "$part")
    INFO "Flags sebelum: $old_flags"

    # Write zeros to first 32 bytes (clear hash/hashtree), set flags at 0x3C
    # byte 0x3C = flags byte (verification disabled = bit 0)
    # byte 0x3F = flags byte 3 (rollback = bit 3)
    local flag_byte=$((mask & 0xFF))
    local flag_byte3=$(((mask >> 24) & 0xFF))

    # Use printf to write exact bytes
    INFO "Writing flags: 0x$(printf '%02x%02x' "$flag_byte3" "$flag_byte") to $part at offset 0x3C"
    if is_root; then
        # dd to patch just the flags region
        # First zero out hash/hashtree descriptors (bytes 0-0x3B), keep magic+major+minor
        # Magic "AVB0" = 4 bytes at offset 0, major/minor at 0x04-0x07, orig flags at 0x3C
        su -c "dd if=/dev/zero of=$block bs=1 count=56 2>/dev/null"
        su -c "printf '\\x${mask_bytes}' | dd of=$block bs=1 seek=0x3C conv=notrunc 2>/dev/null"
    fi

    local new_flags=$(read_vbmeta_flags "$part")
    INFO "Flags sesudah: $new_flags"

    if [[ "$new_flags" == "0x0000000${flag_byte}" || "$new_flags" != "$old_flags" ]]; then
        OK "Patch $part berhasil"
        return 0
    else
        FAIL "Patch $part — flags tidak berubah. Restoring backup..."
        local latest=$(ls -t "$BACKUP_DIR"/${part}_*.img 2>/dev/null | head -1)
        if [[ -n "$latest" ]]; then
            su -c "dd if=$latest of=$block bs=4096" 2>/dev/null
            OK "Backup restored"
        fi
        return 1
    fi
}

patch_level1() {
    HEADER "AVB Patch — Level 1: Disable Verity"
    echo -e "  Patch: Set bit 0 (0x01) di vbmeta saja"
    echo -e "  Efek: dm-verity dimatikan untuk system/vendor/product"
    echo ""
    if ! CONFIRM "Lanjutkan patch Level 1?"; then return; fi

    # Simple method: write 0x01 to vbmeta flags byte
    # Using dd to write just the verification-disabled bit
    if is_root; then
        do_backup "vbmeta"
        local old=$(read_vbmeta_flags "vbmeta")
        # Write flag 0x01 at offset 0x3C (but we need to preserve AVB0 magic)
        # Best approach: read full vbmeta, patch, write back
        local tmpfile="/data/local/tmp/vbmeta_patched.img"
        su -c "dd if=/dev/block/by-name/vbmeta of=$tmpfile bs=4096" 2>/dev/null
        # Patch: set verification disabled bit (byte at offset 0x3C, bit 0)
        su -c "printf '\\x01' | dd of=$tmpfile bs=1 seek=60 conv=notrunc 2>/dev/null"
        su -c "dd if=$tmpfile of=/dev/block/by-name/vbmeta bs=4096" 2>/dev/null
        su -c "rm -f $tmpfile" 2>/dev/null

        local new=$(read_vbmeta_flags "vbmeta")
        if [[ "$new" != "$old" ]]; then
            OK "Level 1 patched: vbmeta flags $old → $new"
        else
            FAIL "Patch tidak efektif"
        fi
    fi
    WAIT_KEY
}

patch_level2() {
    HEADER "AVB Patch — Level 2: Disable Verification"
    echo -e "  Patch: Set bit 0 (0x01) di SEMUA vbmeta* partitions"
    echo -e "  Efek: AVB verification dimatikan total"
    echo ""
    if ! CONFIRM "Lanjutkan patch Level 2?"; then return; fi

    for part in vbmeta vbmeta_system vbmeta_vendor; do
        if [[ -e "/dev/block/by-name/$part" ]]; then
            INFO "Patching $part..."
            do_backup "$part"
            local tmpfile="/data/local/tmp/${part}_patched.img"
            su -c "dd if=/dev/block/by-name/$part of=$tmpfile bs=4096" 2>/dev/null
            su -c "printf '\\x01' | dd of=$tmpfile bs=1 seek=60 conv=notrunc 2>/dev/null"
            su -c "dd if=$tmpfile of=/dev/block/by-name/$part bs=4096" 2>/dev/null
            su -c "rm -f $tmpfile" 2>/dev/null
            local new=$(read_vbmeta_flags "$part")
            OK "$part: flags = $new"
        else
            WARN "$part tidak ditemukan — skip"
        fi
    done
    WAIT_KEY
}

patch_level3() {
    HEADER "AVB Patch — Level 3: Full Bypass"
    echo -e "  Patch: Set bit 0 + bit 3 (0x09) di SEMUA vbmeta* partitions"
    echo -e "  Efek: No AVB + no rollback protection"
    echo ""
    if ! CONFIRM "Lanjutkan patch Level 3?"; then return; fi

    for part in vbmeta vbmeta_system vbmeta_vendor; do
        if [[ -e "/dev/block/by-name/$part" ]]; then
            INFO "Patching $part (0x09)..."
            do_backup "$part"
            local tmpfile="/data/local/tmp/${part}_patched.img"
            su -c "dd if=/dev/block/by-name/$part of=$tmpfile bs=4096" 2>/dev/null
            # 0x09 = bit 0 (verification disabled) + bit 3 (rollback disabled)
            su -c "printf '\\x09' | dd of=$tmpfile bs=1 seek=60 conv=notrunc 2>/dev/null"
            su -c "dd if=$tmpfile of=/dev/block/by-name/$part bs=4096" 2>/dev/null
            su -c "rm -f $tmpfile" 2>/dev/null
            local new=$(read_vbmeta_flags "$part")
            OK "$part: flags = $new"
        else
            WARN "$part tidak ditemukan — skip"
        fi
    done
    WAIT_KEY
}

unpatch_avb() {
    HEADER "Unpatch AVB — Restore Default"
    echo -e "  Mengembalikan vbmeta flags ke 0x00 (default)"
    echo ""
    if ! CONFIRM "Lanjutkan unpatch?"; then return; fi

    # Try to restore from backup first
    for part in vbmeta vbmeta_system vbmeta_vendor; do
        local latest=$(ls -t "$BACKUP_DIR"/${part}_*.img 2>/dev/null | head -1)
        if [[ -n "$latest" ]]; then
            INFO "Restoring $part from $(basename $latest)..."
            su -c "dd if=$latest of=/dev/block/by-name/$part bs=4096" 2>/dev/null
            local new=$(read_vbmeta_flags "$part")
            OK "$part restored: flags = $new"
        else
            # No backup — write 0x00 to flags
            INFO "No backup for $part — writing default flags (0x00)..."
            local tmpfile="/data/local/tmp/${part}_default.img"
            su -c "dd if=/dev/block/by-name/$part of=$tmpfile bs=4096" 2>/dev/null
            su -c "printf '\\x00' | dd of=$tmpfile bs=1 seek=60 conv=notrunc 2>/dev/null"
            su -c "dd if=$tmpfile of=/dev/block/by-name/$part bs=4096" 2>/dev/null
            su -c "rm -f $tmpfile" 2>/dev/null
            local new=$(read_vbmeta_flags "$part")
            OK "$part: flags = $new"
        fi
    done
    WAIT_KEY
}

verify_avb() {
    HEADER "Verifikasi AVB"
    detect_device
    echo -e "  Verified boot state: ${WHITE}$(getprop ro.boot.verifiedbootstate 2>/dev/null)${NC}"
    echo -e "  VBMeta device state: ${WHITE}$(getprop ro.boot.vbmeta.device_state 2>/dev/null)${NC}"
    echo -e "  Flash locked:        ${WHITE}$(getprop ro.boot.flash.locked 2>/dev/null)${NC}"
    WAIT_KEY
}

menu_avb() {
    while true; do
        BANNER
        echo -e "${MAGENTA}═══ AVB Patch/Unpatch ═══${NC}"
        echo ""
        echo "  1) Baca flags"
        echo "  2) Patch Level 1 — Disable Verity"
        echo "  3) Patch Level 2 — Disable Verification"
        echo "  4) Patch Level 3 — Full Bypass"
        echo "  5) Unpatch (Restore default)"
        echo "  6) Verifikasi"
        echo "  7) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) show_avb_status ;;
            2) patch_level1 ;;
            3) patch_level2 ;;
            4) patch_level3 ;;
            5) unpatch_avb ;;
            6) verify_avb ;;
            7) return ;;
        esac
    done
}

menu_avb
