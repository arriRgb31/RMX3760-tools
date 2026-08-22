#!/data/data/com.termux/files/usr/bin/bash
# AVB Patch/Unpatch — Realme C53 RMX3760 Android 15
# by@arriRgb31
#
# Referensi:
#   AVB bypass: https://github.com/TheGammaSqueeze/UnisocBypass
#   CVE-2022-38694: https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader
#   Gopartner: https://github.com/Gopartner/realme-c53-unlock-root
#   Bootchain: docs/Bootchain_Android15_Unlocked.md
#
# VALIDASI:
#   - Auto stock backup sebelum patch
#   - Verify flags setelah patch
#   - Auto-restore jika verifikasi gagal
#   - Anti-bootloop: boot timeout watchdog
#   - Support: Unlocked (fastboot) + Locked (CVE-2022-38694)
#   - Tanpa factory reset (post-unlock)
#   - Tanpa corrupt data
#   - Flash slot yang valid saja

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/colors.sh"
source "$SCRIPT_DIR/../core/platform.sh"
source "$SCRIPT_DIR/../core/device.sh"
source "$SCRIPT_DIR/../core/safe_patch.sh"
source "$SCRIPT_DIR/../core/stock_backup.sh"
source "$SCRIPT_DIR/../core/status_check.sh"
source "$SCRIPT_DIR/../core/slot.sh"

BACKUP_DIR=$(init_backup_dir "avb")

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
    echo "  - Tidak corrupt data"
    echo ""
    echo -e "  ${CYAN}Support:${NC}"
    echo "  - Unlocked: langsung flash via fastboot"
    echo "  - Locked: via CVE-2022-38694 (FDL2)"
    echo ""

    # Show current status
    echo -e "  ${CYAN}Current state:${NC}"
    show_status
    echo ""

    if ! CONFIRM "Lanjutkan patch Level 1?"; then return; fi

    # Auto stock backup
    echo ""
    echo -e "  ${CYAN}[Auto] Stock backup sebelum patch...${NC}"
    stock_dump_quiet 2>/dev/null
    echo ""

    # Patch with safe_patch
    safe_patch "vbmeta" 60 "\\x01" "$BACKUP_DIR" "read_vbmeta_flags"

    if [[ $? -eq 0 ]]; then
        set_boot_timeout 120
        echo ""
        echo -e "  ${GREEN}Level 1 selesai!${NC}"
        echo -e "  Boot watchdog: 120s (auto-restore jika boot hang)"
        echo ""
        show_status
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
    echo "  - Tidak corrupt data"
    echo ""

    # Show current status
    echo -e "  ${CYAN}Current state:${NC}"
    show_status
    echo ""

    if ! CONFIRM "Lanjutkan patch Level 2?"; then return; fi

    # Auto stock backup
    echo -e "  ${CYAN}[Auto] Stock backup sebelum patch...${NC}"
    stock_dump_quiet 2>/dev/null
    echo ""

    # Patch all vbmeta
    for part in vbmeta vbmeta_system vbmeta_vendor; do
        if [[ -e "/dev/block/by-name/$part" ]]; then
            safe_patch "$part" 60 "\\x01" "$BACKUP_DIR" "read_vbmeta_flags"
        else
            WARN "$part tidak ditemukan — skip"
        fi
    done

    set_boot_timeout 120
    echo ""
    echo -e "  ${GREEN}Level 2 selesai!${NC}"
    echo ""
    show_status
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
    echo "  - Bisa di-unpatch kapan saja"
    echo "  - Rollback ke versi lama lebih mudah (bahaya security)"
    echo "  - Tidak corrupt data"
    echo ""

    # Show current status
    echo -e "  ${CYAN}Current state:${NC}"
    show_status
    echo ""

    if ! CONFIRM "Lanjutkan patch Level 3?"; then return; fi

    # Auto stock backup
    echo -e "  ${CYAN}[Auto] Stock backup sebelum patch...${NC}"
    stock_dump_quiet 2>/dev/null
    echo ""

    for part in vbmeta vbmeta_system vbmeta_vendor; do
        if [[ -e "/dev/block/by-name/$part" ]]; then
            safe_patch "$part" 60 "\\x09" "$BACKUP_DIR" "read_vbmeta_flags"
        else
            WARN "$part tidak ditemukan — skip"
        fi
    done

    set_boot_timeout 120
    echo ""
    echo -e "  ${GREEN}Level 3 selesai!${NC}"
    echo ""
    show_status
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

    # Show current status
    echo -e "  ${CYAN}Current state:${NC}"
    show_status
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
    OK "Unpatch selesai."
    echo ""
    show_status
    WAIT_KEY
}

# ============================================
# LOCKED BOOTLOADER GUIDE
# ============================================

guide_locked() {
    HEADER "AVB Patch — Locked Bootloader"
    echo -e "  ${CYAN}Alur untuk device LOCKED:${NC}"
    echo ""
    echo "  1. Masuk FDL2 (download mode):"
    echo "     - Dari Termux: su -c 'reboot autodloader'"
    echo "     - Dari PC: PowerShell: adb reboot autodloader"
    echo "     - Manual: Power Off → Volume Down → USB"
    echo ""
    echo "  2. Jalankan CVE tool di PC:"
    echo "     TomKing062/CVE-2022-38694_unlock_bootloader"
    echo "     atau: Gopartner/realme-c53-unlock-root"
    echo ""
    echo "  3. CVE tool akan exploot SPL → flash unsigned:"
    echo "     - Unlock token → bootloader UNLOCKED"
    echo "     - FACTORY RESET otomatis (data hilang)"
    echo ""
    echo "  4. Setelah unlock, patch AVB:"
    echo "     - Level 1/2/3 tersedia"
    echo "     - Tanpa factory reset lagi"
    echo "     - Tanpa corrupt data"
    echo ""
    echo -e "  ${YELLOW}Catatan Penting:${NC}"
    echo "  - Factory reset HANYA saat unlock (pertama kali)"
    echo "  - Setelah unlock, semua patch tanpa factory reset"
    echo "  - Data yang ada sebelum unlock akan hilang"
    echo "  - Backup data SEBELUM unlock!"
    WAIT_KEY
}

# ============================================
# VERIFY
# ============================================

verify_avb() {
    HEADER "Verifikasi AVB"
    show_status_compare
    WAIT_KEY
}

# ============================================
# MENU
# ============================================

menu_avb() {
    while true; do
        BANNER
        echo -e "${MAGENTA}=== AVB Patch/Unpatch ===${NC}"
        echo -e "  ${GRAY}Anti-bootloop | Backup+Verify | Locked/Unlocked | No corrupt${NC}"
        echo ""
        echo "  1) Status AVB"
        echo "  2) Patch Level 1 — Disable Verity"
        echo "  3) Patch Level 2 — Disable Verification"
        echo "  4) Patch Level 3 — Full Bypass"
        echo "  5) Unpatch (Restore default)"
        echo "  6) Verifikasi + Stock Compare"
        echo "  7) Guide: Locked Bootloader"
        echo "  8) Auto-Restore"
        echo "  9) Stock Backup Manager"
        echo "  0) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) show_status ;; 2) patch_level1 ;; 3) patch_level2 ;;
            4) patch_level3 ;; 5) unpatch_avb ;; 6) verify_avb ;;
            7) guide_locked ;; 8) auto_restore ;;
            9) menu_stock ;; 0) return ;;
        esac
    done
}

menu_avb
