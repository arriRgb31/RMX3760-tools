#!/data/data/com.termux/files/usr/bin/bash
# DM-Verity Patch/Unpatch — Realme C53 RMX3760 Android 15
# by@arriRgb31
#
# Referensi:
#   - UnisocBypass: https://github.com/TheGammaSqueeze/UnisocBypass
#   - CVE-2022-38694: https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader
#   - Bootchain: Bootchain_Android15_Unlocked.md
#
# DM-Verity pada Unisoc UMS9230 terikat ke AVB.
# Disable vbmeta flags (bit 0) = dm-verity otomatis mati.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/colors.sh"
source "$SCRIPT_DIR/../core/device.sh"

BACKUP_DIR="$HOME/RMX3760-tools/backups/dmverity"

show_dmverity_status() {
    HEADER "DM-Verity Status"
    detect_device

    # Check dm-verity mount
    local dm_verity=$(mount | grep "dm-" | grep "verity" 2>/dev/null)
    if [[ -n "$dm_verity" ]]; then
        echo -e "  DM-Verity mount:    ${GREEN}ACTIVE${NC}"
        echo -e "  $dm_verity"
    else
        echo -e "  DM-Verity mount:    ${YELLOW}TIDAK ADA (mungkin sudah nonaktif)${NC}"
    fi

    # Check dm-verity block devices
    local dm_dev=$(ls /dev/mapper/*verity* 2>/dev/null)
    if [[ -n "$dm_dev" ]]; then
        echo -e "  DM devices:         ${WHITE}$dm_dev${NC}"
    fi

    # Check prop
    local prop=$(getprop persist.sys.dmverity.encrypt 2>/dev/null)
    echo -e "  persist.sys.dmverity: ${WHITE}${prop:-not set}${NC}"

    # Check kernel cmdline
    if [[ -f /proc/cmdline ]]; then
        local verity_mode=$(grep -o "androidboot.veritymode=[^ ]*" /proc/cmdline 2>/dev/null)
        echo -e "  Kernel cmdline:     ${WHITE}${verity_mode:-not set}${NC}"
    fi

    # Check fstab verity
    local fstab_verity=$(grep "verify" /vendor/etc/fstab.* 2>/dev/null | head -3)
    if [[ -n "$fstab_verity" ]]; then
        echo -e "  fstab verity:       ${YELLOW}present (kernel-level)${NC}"
    fi

    # Check vbmeta flags
    local vbmeta_block="/dev/block/by-name/vbmeta"
    if [[ -e "$vbmeta_block" ]] && is_root; then
        local flags=$(su -c "dd if=$vbmeta_block bs=1 count=4 skip=0x3B 2>/dev/null | xxd -p" 2>/dev/null)
        local bit0=$((0x$flags & 1))
        if [[ $bit0 -eq 1 ]]; then
            echo -e "  VBMeta verity flag: ${GREEN}DISABLED (bit 0 = 1)${NC}"
        else
            echo -e "  VBMeta verity flag: ${RED}ENABLED (bit 0 = 0)${NC}"
        fi
    fi

    WAIT_KEY
}

disable_dmverity() {
    HEADER "Disable DM-Verity"
    echo -e "  Metode: Patch vbmeta flags (bit 0) + bootconfig override"
    echo -e "  Referensi: UnisocBypass / TheGammaSqueeze"
    echo ""
    if ! CONFIRM "Lanjutkan disable dm-verity?"; then return; fi

    mkdir -p "$BACKUP_DIR"
    local ts=$(date +%Y%m%d_%H%M%S)

    # Method 1: Patch vbmeta (most reliable)
    INFO "Metode 1: Patch vbmeta flags..."
    local vbmeta="/dev/block/by-name/vbmeta"
    if [[ -e "$vbmeta" ]] && is_root; then
        # Backup
        su -c "dd if=$vbmeta of=$BACKUP_DIR/vbmeta_${ts}.img bs=4096" 2>/dev/null
        OK "Backup vbmeta saved"

        # Patch bit 0
        local tmpfile="/data/local/tmp/vbmeta_dm.img"
        su -c "dd if=$vbmeta of=$tmpfile bs=4096" 2>/dev/null
        su -c "printf '\\x01' | dd of=$tmpfile bs=1 seek=60 conv=notrunc 2>/dev/null"
        su -c "dd if=$tmpfile of=$vbmeta bs=4096" 2>/dev/null
        su -c "rm -f $tmpfile" 2>/dev/null
        OK "vbmeta flags patched"
    fi

    # Method 2: Add bootconfig override (persistent)
    INFO "Metode 2: Tambah bootconfig override..."
    local bootconfig="/data/local/bootconfig_override"
    echo "androidboot.veritymode=disabled" > "$bootconfig"
    OK "Bootconfig override written"

    # Method 3: Set prop (may not persist)
    INFO "Metode 3: Set prop..."
    su -c "setprop persist.sys.dmverity.encrypt 0" 2>/dev/null
    OK "Prop set"

    # Verify
    INFO "Verifikasi..."
    echo -e "  VBMeta flags: $(su -c "dd if=/dev/block/by-name/vbmeta bs=1 count=4 skip=0x3B 2>/dev/null | xxd -p" 2>/dev/null)"
    OK "DM-Verity disable selesai. Reboot untuk efektif."
    WAIT_KEY
}

enable_dmverity() {
    HEADER "Enable DM-Verity"
    echo -e "  Mengembalikan dm-verity ke kondisi default"
    echo ""
    if ! CONFIRM "Lanjutkan enable dm-verity?"; then return; fi

    # Restore vbmeta from backup
    local latest=$(ls -t "$BACKUP_DIR"/vbmeta_*.img 2>/dev/null | head -1)
    if [[ -n "$latest" ]] && is_root; then
        INFO "Restoring vbmeta from $(basename $latest)..."
        su -c "dd if=$latest of=/dev/block/by-name/vbmeta bs=4096" 2>/dev/null
        OK "vbmeta restored"
    else
        INFO "Writing default vbmeta flags (0x00)..."
        local tmpfile="/data/local/tmp/vbmeta_default.img"
        su -c "dd if=/dev/block/by-name/vbmeta of=$tmpfile bs=4096" 2>/dev/null
        su -c "printf '\\x00' | dd of=$tmpfile bs=1 seek=60 conv=notrunc 2>/dev/null"
        su -c "dd if=$tmpfile of=/dev/block/by-name/vbmeta bs=4096" 2>/dev/null
        su -c "rm -f $tmpfile" 2>/dev/null
        OK "vbmeta flags reset"
    fi

    # Remove bootconfig override
    rm -f "$HOME/data/local/bootconfig_override" 2>/dev/null
    su -c "rm -f /data/local/bootconfig_override" 2>/dev/null
    OK "Bootconfig override removed"

    OK "DM-Verity enable selesai. Reboot untuk efektif."
    WAIT_KEY
}

verify_dmverity() {
    HEADER "Verifikasi DM-Verity"
    echo -e "  DM devices:"
    ls -la /dev/mapper/ 2>/dev/null | grep -i dm
    echo -e "  Mount verity:"
    mount | grep -i verity || echo "  (tidak ada)"
    echo -e "  Prop:"
    echo "    persist.sys.dmverity.encrypt = $(getprop persist.sys.dmverity.encrypt 2>/dev/null)"
    echo "    ro.boot.veritymode = $(getprop ro.boot.veritymode 2>/dev/null)"
    WAIT_KEY
}

menu_dmverity() {
    while true; do
        BANNER
        echo -e "${MAGENTA}═══ DM-Verity Patch/Unpatch ═══${NC}"
        echo ""
        echo "  1) Status DM-Verity"
        echo "  2) Disable DM-Verity"
        echo "  3) Enable DM-Verity"
        echo "  4) Verifikasi"
        echo "  5) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) show_dmverity_status ;;
            2) disable_dmverity ;;
            3) enable_dmverity ;;
            4) verify_dmverity ;;
            5) return ;;
        esac
    done
}

menu_dmverity
