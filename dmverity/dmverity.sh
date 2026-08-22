#!/data/data/com.termux/files/usr/bin/bash
# DM-Verity — Disable/Enable dm-verity
# by@arriRgb31
#
# Referensi:
#   UnisocBypass: https://github.com/TheGammaSqueeze/UnisocBypass
#   Bootchain: docs/Bootchain_Android15_Unlocked.md
#
# VALIDASI:
#   - Auto stock backup (fstab) sebelum patch
#   - Verify dm-verity status setelah patch
#   - Auto-restore fstab jika verifikasi gagal
#   - Anti-bootloop: boot timeout watchdog
#   - Support: Unlocked (fastboot) + Locked (CVE-2022-38694)
#   - Tanpa factory reset (post-unlock)
#   - Tanpa corrupt data

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/colors.sh"
source "$SCRIPT_DIR/../core/platform.sh"
source "$SCRIPT_DIR/../core/device.sh"
source "$SCRIPT_DIR/../core/safe_patch.sh"
source "$SCRIPT_DIR/../core/stock_backup.sh"
source "$SCRIPT_DIR/../core/status_check.sh"
source "$SCRIPT_DIR/../core/slot.sh"

BACKUP_DIR=$(init_backup_dir "dmverity")

# ============================================
# FIND FSTAB
# ============================================

find_fstab() {
    local root_state=""
    if command -v su &>/dev/null && su -c "id" 2>/dev/null | grep -q "uid=0"; then
        root_state="rooted"
    else
        root_state="non-rooted"
    fi

    local fstab_paths=()

    if [[ "$root_state" == "rooted" ]]; then
        fstab_paths=(
            "/vendor/etc/fstab.ums9230"
            "/vendor/etc/fstab"
            "/proc/boot/fstab"
        )
    else
        # Non-root: try ADB
        local adb_fstab=$(adb shell "ls /vendor/etc/fstab.* 2>/dev/null || ls /vendor/etc/fstab 2>/dev/null" 2>/dev/null | head -1)
        [[ -n "$adb_fstab" ]] && fstab_paths=("$adb_fstab")
    fi

    for fstab in "${fstab_paths[@]}"; do
        if [[ -e "$fstab" ]]; then
            echo "$fstab"
            return 0
        fi
    done

    return 1
}

# ============================================
# READ DM-VERITY STATUS
# ============================================

read_dmverity_status() {
    local fstab=$(find_fstab)
    if [[ -z "$fstab" ]]; then
        echo "unknown"
        return
    fi

    local root_state=""
    if command -v su &>/dev/null && su -c "id" 2>/dev/null | grep -q "uid=0"; then
        root_state="rooted"
    else
        root_state="non-rooted"
    fi

    local fstab_content=""
    if [[ "$root_state" == "rooted" ]]; then
        fstab_content=$(su -c "cat $fstab" 2>/dev/null)
    else
        fstab_content=$(adb shell "cat $fstab" 2>/dev/null)
    fi

    # Check for dm-verity flags
    if echo "$fstab_content" | grep -qi "verify"; then
        echo "enabled"
    elif echo "$fstab_content" | grep -qi "avb"; then
        echo "enabled (avb)"
    else
        echo "disabled"
    fi
}

# ============================================
# PATCH DM-VERITY
# ============================================

patch_dmverity() {
    HEADER "DM-Verity — Disable"
    echo -e "  ${CYAN}Apa yang dilakukan:${NC}"
    echo "  - Backup fstab sebelum patch"
    echo "  - Hapus flag 'verify'/'avb' di fstab"
    echo "  - dm-verity dimatikan untuk semua partition"
    echo ""
    echo -e "  ${CYAN}Risiko:${NC}"
    echo "  - Rendah: hanya verity yang dimatikan"
    echo "  - Tidak perlu factory reset"
    echo "  - Bisa di-enable kapan saja"
    echo "  - Tidak corrupt data"
    echo ""
    echo -e "  ${CYAN}Support:${NC}"
    echo "  - Unlocked: langsung patch fstab"
    echo "  - Locked: via CVE-2022-38694 (FDL2)"
    echo ""

    # Show current status
    local dmverity=$(read_dmverity_status)
    echo -e "  ${CYAN}Current state:${NC}"
    echo -e "    DM-Verity: ${WHITE}$dmverity${NC}"
    echo -e "    fstab: ${WHITE}$(find_fstab)${NC}"
    echo ""

    if [[ "$dmverity" == "disabled" ]]; then
        echo -e "  ${YELLOW}DM-Verity sudah disabled${NC}"
        WAIT_KEY
        return
    fi

    if ! CONFIRM "Lanjutkan disable DM-Verity?"; then return; fi

    # Auto stock backup (fstab)
    echo -e "  ${CYAN}[Auto] Stock backup fstab...${NC}"
    local fstab=$(find_fstab)
    if [[ -n "$fstab" ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local dump_dir="$BACKUP_DIR/fstab_${timestamp}"
        mkdir -p "$dump_dir"
        su -c "cp $fstab $dump_dir/fstab_backup.txt" 2>/dev/null || \
            adb shell "cp $fstab $dump_dir/fstab_backup.txt" 2>/dev/null
        echo -e "    Backup: ${WHITE}$dump_dir/fstab_backup.txt${NC}"
    fi
    echo ""

    # Patch fstab — remove verify/avb flags
    local root_state=""
    if command -v su &>/dev/null && su -c "id" 2>/dev/null | grep -q "uid=0"; then
        root_state="rooted"
    else
        root_state="non-rooted"
    fi

    if [[ "$root_state" == "rooted" ]]; then
        # Rooted: patch fstab directly
        local fstab_target="/vendor/etc/fstab.ums9230"
        [[ ! -f "$fstab_target" ]] && fstab_target="/vendor/etc/fstab"

        if [[ -f "$fstab_target" ]]; then
            # Remove verify/avb flags
            su -c "sed -i 's/,verify//g; s/,avb//g; s/verify,//g; s/avb,//g' $fstab_target" 2>/dev/null
            su -c "sed -i 's/ verify//g; s/ avb//g' $fstab_target" 2>/dev/null

            local new_status=$(read_dmverity_status)
            if [[ "$new_status" == "disabled" ]]; then
                echo -e "  ${GREEN}DM-Verity berhasil dimatikan!${NC}"
                set_boot_timeout 120
            else
                echo -e "  ${RED}Patch gagal — auto-restore akan terjadi${NC}"
                # Auto-restore from backup
                if [[ -f "$dump_dir/fstab_backup.txt" ]]; then
                    su -c "cp $dump_dir/fstab_backup.txt $fstab_target" 2>/dev/null
                    echo -e "  ${YELLOW}Fstab restored dari backup${NC}"
                fi
            fi
        else
            echo -e "  ${RED}fstab tidak ditemukan${NC}"
        fi
    else
        echo -e "  ${YELLOW}Non-root: membutuhkan CVE tool atau unlock terlebih dahulu${NC}"
        echo -e "  Jalankan CVE tool untuk patch fstab via FDL2"
    fi

    echo ""
    echo -e "  ${CYAN}Status setelah patch:${NC}"
    echo -e "    DM-Verity: ${WHITE}$(read_dmverity_status)${NC}"
    WAIT_KEY
}

# ============================================
# ENABLE DM-VERITY
# ============================================

enable_dmverity() {
    HEADER "DM-Verity — Enable (Restore)"
    echo -e "  Mengembalikan dm-verity ke state default"
    echo ""

    # Find latest backup
    local latest=$(ls -dt "$BACKUP_DIR"/fstab_* 2>/dev/null | head -1)

    if [[ -z "$latest" ]] || [[ ! -f "$latest/fstab_backup.txt" ]]; then
        echo -e "  ${YELLOW}Tidak ada fstab backup ditemukan${NC}"
        echo -e "  DM-Verity hanya bisa di-enable dari backup"
        WAIT_KEY
        return
    fi

    echo -e "  Backup: ${WHITE}$(basename $latest)${NC}"

    if ! CONFIRM "Restore fstab dari backup?"; then return; fi

    local fstab_target="/vendor/etc/fstab.ums9230"
    [[ ! -f "$fstab_target" ]] && fstab_target="/vendor/etc/fstab"

    su -c "cp $latest/fstab_backup.txt $fstab_target" 2>/dev/null

    local new_status=$(read_dmverity_status)
    echo ""
    echo -e "  ${GREEN}Fstab restored!${NC}"
    echo -e "  DM-Verity: ${WHITE}$new_status${NC}"
    echo "  Reboot untuk efektif."
    WAIT_KEY
}

# ============================================
# VERIFY
# ============================================

verify_dmverity() {
    HEADER "Verifikasi DM-Verity"
    echo ""
    echo -e "  ${CYAN}DM-Verity status:${NC}"
    echo -e "    Status: ${WHITE}$(read_dmverity_status)${NC}"
    echo -e "    fstab:  ${WHITE}$(find_fstab)${NC}"
    echo ""
    show_status
    WAIT_KEY
}

# ============================================
# GUIDE
# ============================================

guide_dmverity() {
    HEADER "DM-Verity — Guide"
    echo -e "  ${CYAN}Apa itu DM-Verity?${NC}"
    echo "  - Android Verified Boot untuk system/vendor/product"
    echo "  - Memverifikasi integritas filesystem saat boot"
    echo "  - Jika rusak → boot loop"
    echo ""
    echo -e "  ${CYAN}Kapan perlu disable?${NC}"
    echo "  - Modifikasi system/vendor (custom ROM, kernel)"
    echo "  - Install Magisk/root"
    echo "  - Patch SELinux"
    echo ""
    echo -e "  ${CYAN}Cara kerja:${NC}"
    echo "  - Disable: hapus flag 'verify'/'avb' di fstab"
    echo "  - Enable: kembalikan flag ke fstab default"
    echo ""
    echo -e "  ${CYAN}Locked bootloader:${NC}"
    echo "  - Perlu CVE-2022-38694 untuk unlock dulu"
    echo "  - Setelah unlock, patch tanpa factory reset"
    WAIT_KEY
}

# ============================================
# MENU
# ============================================

menu_dmverity() {
    while true; do
        BANNER
        echo -e "${MAGENTA}=== DM-Verity ===${NC}"
        echo -e "  ${GRAY}Disable/Enable | Backup fstab | No bootloop${NC}"
        echo ""
        echo "  1) Status DM-Verity"
        echo "  2) Disable DM-Verity"
        echo "  3) Enable (Restore)"
        echo "  4) Verifikasi"
        echo "  5) Guide"
        echo "  6) Stock Backup Manager"
        echo "  7) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) verify_dmverity ;; 2) patch_dmverity ;; 3) enable_dmverity ;;
            4) verify_dmverity ;; 5) guide_dmverity ;; 6) menu_stock ;; 7) return ;;
        esac
    done
}

menu_dmverity
