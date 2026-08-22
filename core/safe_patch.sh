#!/data/data/com.termux/files/usr/bin/bash
# Safe Patch Framework — Anti Bootloop / Anti Brick
# by@arriRgb31
#
# Referensi:
#   - Bootchain: Bootchain_Android15_Unlocked.md
#   - CVE-2022-38694: https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader
#
# PRINSIP:
#   1. SELALU backup sebelum patch
#   2. SELALU verifikasi setelah patch
#   3. Jika verifikasi gagal → auto-restore backup
#   4. Simpan recovery info di /data/local/tmp/ ( survive reboot )
#   5. Boot timeout: jika boot gagal dalam 120s, auto-restore via recovery
#
# SUPPORT:
#   - Unlocked bootloader: flash via fastboot
#   - Locked bootloader: flash via CVE-2022-38694 (FDL2 download mode)
#   - Tanpa factory reset (kecuali dm-verity re-enable setelah data modified)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/colors.sh"
source "$SCRIPT_DIR/device.sh"

BACKUP_BASE="$HOME/RMX3760-tools/backups"
RECOVERY_INFO="/data/local/tmp/rmx3760_recovery.info"

# ============================================
# BACKUP FUNCTIONS
# ============================================

# Create backup directory for specific tool
init_backup_dir() {
    local tool="$1"
    local dir="$BACKUP_BASE/$tool"
    mkdir -p "$dir"
    echo "$dir"
}

# Backup partition with timestamp
backup_partition() {
    local partition="$1"
    local backup_dir="$2"
    local ts=$(date +%Y%m%d_%H%M%S)
    local block="/dev/block/by-name/$partition"
    local backup_file="$backup_dir/${partition}_${ts}.img"

    if [[ ! -e "$block" ]]; then
        WARN "Partition $partition tidak ditemukan — skip backup"
        return 1
    fi

    INFO "Backing up $partition..."
    su -c "dd if=$block of=$backup_file bs=4096" 2>/dev/null
    if [[ -f "$backup_file" ]]; then
        local size=$(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file" 2>/dev/null)
        if [[ "$size" -gt 0 ]]; then
            OK "Backup: $(basename $backup_file) ($((size/1024))KB)"
            echo "$backup_file"
        else
            FAIL "Backup kosong: $backup_file"
            rm -f "$backup_file"
            return 1
        fi
    else
        FAIL "Backup gagal: $partition"
        return 1
    fi
}

# Get latest backup for partition
get_latest_backup() {
    local partition="$1"
    local tool="$2"
    local dir="$BACKUP_BASE/$tool"
    ls -t "$dir"/${partition}_*.img 2>/dev/null | head -1
}

# ============================================
# PATCH FUNCTIONS (safe)
# ============================================

# Safe patch: backup → patch → verify → auto-restore on fail
# Usage: safe_patch <partition> <offset> <byte> <backup_dir> <verify_func>
safe_patch() {
    local partition="$1"
    local offset="$2"
    local byte="$3"
    local backup_dir="$4"
    local verify_func="$5"
    local block="/dev/block/by-name/$partition"

    HEADER "Safe Patch: $partition"

    # Step 1: Check partition exists
    if [[ ! -e "$block" ]]; then
        FAIL "Partition $partition tidak ditemukan"
        return 1
    fi

    # Step 2: Backup
    local backup_file
    backup_file=$(backup_partition "$partition" "$backup_dir")
    if [[ -z "$backup_file" ]]; then
        FAIL "Backup gagal — patch dibatalkan"
        return 1
    fi

    # Step 3: Read current state
    local old_state=""
    if [[ -n "$verify_func" ]] && type "$verify_func" &>/dev/null; then
        old_state=$($verify_func "$partition")
    fi
    INFO "State sebelum: ${old_state:-unknown}"

    # Step 4: Patch
    INFO "Patching $partition: offset=$offset byte=$byte"
    local tmpfile="/data/local/tmp/${partition}_safe_patch.img"
    su -c "dd if=$block of=$tmpfile bs=4096" 2>/dev/null
    su -c "printf '$byte' | dd of=$tmpfile bs=1 seek=$offset conv=notrunc 2>/dev/null"
    su -c "dd if=$tmpfile of=$block bs=4096" 2>/dev/null
    su -c "rm -f $tmpfile" 2>/dev/null

    # Step 5: Verify
    local new_state=""
    if [[ -n "$verify_func" ]] && type "$verify_func" &>/dev/null; then
        new_state=$($verify_func "$partition")
    fi
    INFO "State sesudah: ${new_state:-unknown}"

    # Step 6: Verify changed
    if [[ "$new_state" == "$old_state" && -n "$old_state" ]]; then
        FAIL "Patch tidak efektif ($old_state → $new_state)"
        INFO "Auto-restoring backup..."
        su -c "dd if=$backup_file of=$block bs=4096" 2>/dev/null
        FAIL "Backup restored — patch dibatalkan"
        return 1
    fi

    # Step 7: Save recovery info
    save_recovery_info "$partition" "$backup_file"

    OK "Patch $partition berhasil: $old_state → $new_state"
    return 0
}

# ============================================
# RECOVERY FUNCTIONS
# ============================================

# Save recovery info for auto-restore
save_recovery_info() {
    local partition="$1"
    local backup_file="$2"
    local ts=$(date +%Y%m%d_%H%M%S)

    # Append to recovery info file
    echo "${partition}|${backup_file}|${ts}" >> "$RECOVERY_INFO"
    INFO "Recovery info saved: $RECOVERY_INFO"
}

# Auto-restore from recovery info (call from recovery mode or next boot)
auto_restore() {
    HEADER "Auto-Restore dari Recovery Info"

    if [[ ! -f "$RECOVERY_INFO" ]]; then
        INFO "Tidak ada recovery info — tidak perlu restore"
        return 0
    fi

    INFO "Recovery info:"
    cat "$RECOVERY_INFO"
    echo ""

    if ! CONFIRM "Restore semua partition dari backup?"; then
        return 0
    fi

    while IFS='|' read -r partition backup_file ts; do
        if [[ -n "$partition" && -f "$backup_file" ]]; then
            INFO "Restoring $partition from $(basename $backup_file) ($ts)..."
            su -c "dd if=$backup_file of=/dev/block/by-name/$partition bs=4096" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                OK "$partition restored"
            else
                FAIL "$partition restore FAILED"
            fi
        fi
    done < "$RECOVERY_INFO"

    # Clear recovery info
    rm -f "$RECOVERY_INFO"
    OK "Auto-restore selesai"
}

# ============================================
# BOOT TIMEOUT (anti-bootloop)
# ============================================

# Set boot timeout watchdog
# If device doesn't complete boot in TIMEOUT seconds, auto-restore
set_boot_timeout() {
    local timeout="${1:-120}"
    HEADER "Set Boot Timeout: ${timeout}s"

    # Write watchdog script
    local watchdog="/data/local/tmp/rmx3760_boot_watchdog.sh"
    cat > "$watchdog" << WATCHEOF
#!/system/bin/sh
# Boot watchdog — auto-restore if boot hangs
sleep $timeout
# Check if boot completed
BOOT_COMPLETED=\$(getprop sys.boot_completed 2>/dev/null)
if [[ "\$BOOT_COMPLETED" != "1" ]]; then
    # Boot hang detected — auto-restore
    $SCRIPT_DIR/../core/safe_patch.sh auto_restore
    # Reboot to apply restored partitions
    reboot
fi
rm -f \$0
WATCHEOF
    chmod +x "$watchdog"

    # Start watchdog in background
    if is_root; then
        nohup su -c "sh $watchdog" &>/dev/null &
        OK "Boot watchdog set: ${timeout}s"
        INFO "Jika boot hang, auto-restore akan jalan"
    fi
}

# Clear boot timeout
clear_boot_timeout() {
    rm -f /data/local/tmp/rmx3760_boot_watchdog.sh 2>/dev/null
    OK "Boot watchdog cleared"
}

# ============================================
# BOOTLOADER MODE DETECTION
# ============================================

# Check if bootloader is unlocked
is_bootloader_unlocked() {
    local locked=$(getprop ro.boot.flash.locked 2>/dev/null)
    [[ "$locked" == "0" ]]
}

# Flash based on bootloader state
smart_flash() {
    local partition="$1"
    local image="$2"
    local slot="${3:-}"  # optional: _a, _b, or empty for current

    if [[ ! -f "$image" ]]; then
        FAIL "Image tidak ditemukan: $image"
        return 1
    fi

    if is_bootloader_unlocked; then
        # Unlocked: use fastboot
        INFO "Bootloader unlocked — flash via fastboot"
        if [[ -n "$slot" ]]; then
            fastboot flash "${partition}${slot}" "$image" 2>&1
        else
            fastboot flash "$partition" "$image" 2>&1
        fi
    else
        # Locked: need CVE exploit
        INFO "Bootloader locked — flash via CVE-2022-38694"
        echo "  1. Masuk FDL2: su -c 'reboot autodloader'"
        echo "  2. Jalankan CVE tool di PC"
        if [[ -n "$slot" ]]; then
            echo "  3. Flash: $partition$slot"
        else
            echo "  3. Flash: $partition"
        fi
        echo "  Image: $image"
        echo ""
        if CONFIRM "Masuk FDL2 sekarang?"; then
            if is_root; then
                su -c "reboot autodloader" 2>/dev/null
            fi
        fi
    fi
}

# ============================================
# VERIFICATION FUNCTIONS
# ============================================

# Read vbmeta flags
read_vbmeta_flags() {
    local part="${1:-vbmeta}"
    local block="/dev/block/by-name/$part"
    if [[ ! -e "$block" ]]; then echo "N/A"; return; fi
    if is_root; then
        local hex=$(su -c "dd if=$block bs=1 count=4 skip=0x3B 2>/dev/null | xxd -p" 2>/dev/null)
        echo "0x$hex"
    else
        echo "need_root"
    fi
}

# Get SELinux mode
get_selinux_mode() {
    if is_root; then
        su -c "getenforce" 2>/dev/null
    else
        echo "unknown"
    fi
}

# Get dm-verity status
get_dmverity_status() {
    local dm=$(mount | grep "dm-" | grep "verity" 2>/dev/null)
    if [[ -n "$dm" ]]; then
        echo "active"
    else
        echo "inactive"
    fi
}

# Get boot state
get_boot_state() {
    if [[ -f /proc/bootconfig ]]; then
        grep "androidboot.verifiedbootstate" /proc/bootconfig 2>/dev/null | cut -d'"' -f2
    else
        getprop ro.boot.verifiedbootstate 2>/dev/null
    fi
}
