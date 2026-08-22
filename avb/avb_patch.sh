#!/data/data/com.termux/files/usr/bin/bash
# AVB Patch/Unpatch — Realme C53 RMX3760 Android 15
# by@arriRgb31
#
# Referensi:
#   - AVB bypass: https://github.com/TheGammaSqueeze/UnisocBypass
#   - CVE-2022-38694: https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader
#   - Gopartner: https://github.com/Gopartner/realme-c53-unlock-root
#   - Bootchain: Bootchain_Android15_Unlocked.md
#
# VALIDASI:
#   - Backup otomatis sebelum patch
#   - Verifikasi flags setelah patch
#   - Auto-restore jika verifikasi gagal
#   - Anti-bootloop: boot timeout watchdog
#   - Support: Unlocked (fastboot) + Locked (CVE-2022-38694)
#   - Tanpa factory reset

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/colors.sh"
source "$SCRIPT_DIR/../core/device.sh"
source "$SCRIPT_DIR/../core/safe_patch.sh"

BACKUP_DIR=$(init_backup_dir "avb")

# ============================================
# READ FUNCTIONS
# ============================================

read_vbmeta_full() {
    local part="${1:-vbmeta}"
    local block="/dev/block/by-name/$part"
    [[ ! -e "$block" ]] && return
    if is_root; then
        # Read: magic(4) + major(2) + minor(2) + reserved(4) + algo(4) + ... + flags at 0x3C
        su -c "dd if=$block bs=1 count=64 2>/dev/null | xxd" 2>/dev/null
    fi
}

show_avb_status() {
    HEADER "AVB Status"
    detect_device

    local current_slot=$(get_current_slot 2>/dev/null || getprop ro.boot.slot_suffix 2>/dev/null)
    echo -e "  Active slot:  ${WHITE}$current_slot${NC}"
    echo ""

    for part in vbmeta vbmeta_system vbmeta_vendor; do
        local block="/dev/block/by-name/$part"
        if [[ -e "$block" ]]; then
            local flags=$(read_vbmeta_flags "$part")
            local boot_state=$(get_boot_state)
            echo -e "  $part: flags=${WHITE}$flags${NC}  boot_state=${WHITE}$boot_state${NC}"
        else
            echo -e "  $part: ${GRAY}not found${NC}"
        fi
    done

    echo ""
    echo -e "  Device state:  ${WHITE}$(getprop ro.boot.vbmeta.device_state 2>/dev/null)${NC}"
    echo -e "  Flash locked:  ${WHITE}$(getprop ro.boot.flash.locked 2>/dev/null)${NC}"
    echo -e "  Bootloader:    ${WHITE}$(is_bootloader_unlocked && echo 'UNLOCKED' || echo 'LOCKED')${NC}"

    # Show backup status
    local backups=$(ls "$BACKUP_DIR"/*.img 2>/dev/null | wc -l)
    echo -e "  Backups:       ${WHITE}$backups files${NC}"
    echo ""

    # Show flags detail
    if is_root; then
        echo -e "  ${CYAN}Flags detail (vbmeta):${NC}"
        read_vbmeta_full "vbmeta" | head -5
    fi

    WAIT_KEY
}

# ============================================
# PATCH FUNCTIONS
# ============================================

patch_level1() {
    HEADER "AVB Patch Level 1 — Disable Verity"
    echo -e "  ${CYAN}Apa yang dilakukan:${NC}"
    echo "  - Set bit 0 (0x01) di vbmeta flags saja"
    echo "  - dm-verity dimatikan untuk system/vendor/product"
    echo "  - vbmeta_system dan vbmeta_vendor TIDAK diubah"
    echo ""
    echo -e "  ${CYAN}Risiko:${NC}"
    echo "  - Rendah: hanya verity yang dimatikan"
    echo "  - Tidak perlu factory reset"
    echo "  - Bisa di-unpatch kapan saja"
    echo ""
    echo -e "  ${CYAN}Support:${NC}"
    echo "  - Unlocked: langsung flash via fastboot"
    echo "  - Locked: via CVE-2022-38694 (FDL2)"
    echo ""

    if ! CONFIRM "Lanjutkan patch Level 1?"; then return; fi

    safe_patch "vbmeta" 60 "\\x01" "$BACKUP_DIR" "read_vbmeta_flags"

    if [[ $? -eq 0 ]]; then
        set_boot_timeout 120
        echo ""
        OK "Level 1 selesai. Reboot untuk efektif."
        echo -e "  Boot watchdog: 120s (auto-restore jika boot hang)"
    fi
    WAIT_KEY
}

patch_level2() {
    HEADER "AVB Patch Level 2 — Disable Verification"
    echo -e "  ${CYAN}Apa yang dilakukan:${NC}"
    echo "  - Set bit 0 (0x01) di SEMUA vbmeta* partitions"
    echo "  - AVB verification dimatikan total"
    echo ""
    echo -e "  ${CYAN}Risiko:${NC}"
    echo "  - Sedang: semua verifikasi AVB dimatikan"
    echo "  - Tidak perlu factory reset"
    echo "  - Bisa di-unpatch kapan saja"
    echo ""

    if ! CONFIRM "Lanjutkan patch Level 2?"; then return; fi

    for part in vbmeta vbmeta_system vbmeta_vendor; do
        if [[ -e "/dev/block/by-name/$part" ]]; then
            safe_patch "$part" 60 "\\x01" "$BACKUP_DIR" "read_vbmeta_flags"
        else
            WARN "$part tidak ditemukan — skip"
        fi
    done

    set_boot_timeout 120
    echo ""
    OK "Level 2 selesai. Reboot untuk efektif."
    WAIT_KEY
}

patch_level3() {
    HEADER "AVB Patch Level 3 — Full Bypass"
    echo -e "  ${CYAN}Apa yang dilakukan:${NC}"
    echo "  - Set bit 0 + bit 3 (0x09) di SEMUA vbmeta* partitions"
    echo "  - No AVB + no rollback protection"
    echo ""
    echo -e "  ${CYAN}Risiko:${NC}"
    echo "  - Tinggi: semua proteksi boot dimatikan"
    echo "  - Tidak perlu factory reset"
    echo "  - Rollback ke versi lama lebih mudah (bahaya security)"
    echo ""

    if ! CONFIRM "Lanjutkan patch Level 3?"; then return; fi

    for part in vbmeta vbmeta_system vbmeta_vendor; do
        if [[ -e "/dev/block/by-name/$part" ]]; then
            safe_patch "$part" 60 "\\x09" "$BACKUP_DIR" "read_vbmeta_flags"
        else
            WARN "$part tidak ditemukan — skip"
        fi
    done

    set_boot_timeout 120
    echo ""
    OK "Level 3 selesai. Reboot untuk efektif."
    WAIT_KEY
}

# ============================================
# UNPATCH
# ============================================

unpatch_avb() {
    HEADER "Unpatch AVB — Restore Default"
    echo -e "  Mengembalikan vbmeta flags ke default (0x00)"
    echo -e "  Menggunakan backup terakhir"
    echo ""

    if ! CONFIRM "Lanjutkan unpatch?"; then return; fi

    for part in vbmeta vbmeta_system vbmeta_vendor; do
        local latest=$(get_latest_backup "$part" "avb")
        if [[ -n "$latest" ]]; then
            INFO "Restoring $part from $(basename $latest)..."
            su -c "dd if=$latest of=/dev/block/by-name/$part bs=4096" 2>/dev/null
            local new=$(read_vbmeta_flags "$part")
            OK "$part: flags = $new"
        else
            WARN "No backup for $part — skip"
        fi
    done

    clear_boot_timeout
    OK "Unpatch selesai. Reboot untuk efektif."
    WAIT_KEY
}

# ============================================
# VERIFY
# ============================================

verify_avb() {
    HEADER "Verifikasi AVB"
    detect_device

    echo -e "  ${CYAN}Current state:${NC}"
    echo -e "  Verified boot:  ${WHITE}$(get_boot_state)${NC}"
    echo -e "  Device state:   ${WHITE}$(getprop ro.boot.vbmeta.device_state 2>/dev/null)${NC}"
    echo -e "  Flash locked:   ${WHITE}$(getprop ro.boot.flash.locked 2>/dev/null)${NC}"
    echo ""

    echo -e "  ${CYAN}VBMeta flags:${NC}"
    for part in vbmeta vbmeta_system vbmeta_vendor; do
        local flags=$(read_vbmeta_flags "$part")
        echo -e "    $part: ${WHITE}$flags${NC}"
    done

    echo ""
    echo -e "  ${CYAN}Expected values after patch:${NC}"
    echo "    Level 1: vbmeta=0x00000001 (others unchanged)"
    echo "    Level 2: all=0x00000001"
    echo "    Level 3: all=0x00000009"
    echo "    Default: all=0x00000000"
    WAIT_KEY
}

# ============================================
# LOCKED BOOTLOADER GUIDE
# ============================================

guide_locked() {
    HEADER "AVB Patch — Locked Bootloader"
    echo -e "  ${CYAN}Tanpa unlock, patch AVB via CVE-2022-38694:${NC}"
    echo ""
    echo "  1. Masuk FDL2 (download mode):"
    echo "     su -c 'reboot autodloader'"
    echo "     atau: Power off → Volume Down → USB"
    echo ""
    echo "  2. Jalankan CVE tool di PC:"
    echo "     TomKing062/CVE-2022-38694_unlock_bootloader"
    echo "     atau: Gopartner/realme-c53-unlock-root"
    echo ""
    echo "  3. Flash vbmeta (via CVE tool):"
    echo "     CVE tool akan exploot SPL → flash unsigned vbmeta"
    echo "     Flags: 0x01 (Level 1) atau 0x09 (Level 3)"
    echo ""
    echo "  4. Reboot:"
    echo "     device akan boot dengan AVB dimatikan"
    echo ""
    echo -e "  ${YELLOW}Catatan:${NC}"
    echo "  - TIDAK perlu factory reset"
    echo "  - Data tetap aman"
    echo "  - Bisa di-unpatch dengan restore backup"
    echo "  - Bootloader tetap 'locked' tapi AVB bypass"
    WAIT_KEY
}

# ============================================
# MENU
# ============================================

menu_avb() {
    while true; do
        BANNER
        echo -e "${MAGENTA}=== AVB Patch/Unpatch ===${NC}"
        echo -e "  ${GRAY}Anti-bootloop | Backup+Verify | Locked/Unlocked${NC}"
        echo ""
        echo "  1) Status AVB"
        echo "  2) Patch Level 1 — Disable Verity"
        echo "  3) Patch Level 2 — Disable Verification"
        echo "  4) Patch Level 3 — Full Bypass"
        echo "  5) Unpatch (Restore default)"
        echo "  6) Verifikasi"
        echo "  7) Guide: Locked Bootloader"
        echo "  8) Auto-Restore"
        echo "  9) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) show_avb_status ;; 2) patch_level1 ;; 3) patch_level2 ;;
            4) patch_level3 ;; 5) unpatch_avb ;; 6) verify_avb ;;
            7) guide_locked ;; 8) auto_restore ;; 9) return ;;
        esac
    done
}

menu_avb
