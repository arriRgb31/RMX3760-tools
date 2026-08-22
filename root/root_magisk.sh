#!/data/data/com.termux/files/usr/bin/bash
# Magisk Root — Realme C53 RMX3760 Android 15
# by@arriRgb31
#
# Referensi:
#   - Magisk: https://topjohnwu.github.io/Magisk/
#   - Magisk source: https://github.com/topjohnwu/Magisk
#   - Bootchain: Bootchain_Android15_Unlocked.md
#
# Metode:
#   - Unlocked bootloader: fastboot flash boot magisk_patched_boot.img
#   - Locked (CVE): download mode → flash patched boot via CVE-2022-38694

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/colors.sh"
source "$SCRIPT_DIR/../core/device.sh"

CACHE_DIR="$HOME/RMX3760-tools/cache/magisk"
BACKUP_DIR="$HOME/RMX3760-tools/backups/boot"
SELinux_MODE="enforcing"

check_magisk() {
    HEADER "Magisk Status"
    local installed=$(su -c "magisk -v" 2>/dev/null)
    local path=$(su -c "magisk --path" 2>/dev/null)
    local version_code=$(su -c "magisk -V" 2>/dev/null)

    if [[ -n "$installed" && "$installed" != "not found" ]]; then
        OK "Magisk installed: $installed"
        echo -e "  Path: ${WHITE}$path${NC}"
        echo -e "  Version code: ${WHITE}$version_code${NC}"
    else
        FAIL "Magisk tidak terinstall"
    fi

    # Check Zygisk
    local zygisk=$(su -c "magisk --zygisk" 2>/dev/null)
    echo -e "  Zygisk: ${WHITE}${zygisk:-unknown}${NC}"

    # Check modules
    local modules=$(su -c "ls /data/adb/modules" 2>/dev/null)
    if [[ -n "$modules" ]]; then
        echo -e "  Modules: ${WHITE}$modules${NC}"
    fi
    WAIT_KEY
}

download_magisk() {
    HEADER "Download Magisk"
    mkdir -p "$CACHE_DIR"

    local latest_url="https://github.com/topjohnwu/Magisk/releases/latest"
    INFO "Checking latest release..."
    local redirect=$(curl -sI -o /dev/null -w "%{redirect_url}" "$latest_url" 2>/dev/null)
    local version=$(echo "$redirect" | grep -o "tag/[v0-9.]*" | cut -d'/' -f2)

    if [[ -z "$version" ]]; then
        version="v28.1"
        WARN "Cannot detect latest, using $version"
    fi

    INFO "Latest: $version"
    local apk_url="https://github.com/topjohnwu/Magisk/releases/download/${version}/Magisk-${version#v}.apk"
    local file="$CACHE_DIR/Magisk.apk"

    if [[ -f "$file" ]]; then
        OK "Magisk already downloaded: $file"
        return 0
    fi

    if command -v curl &>/dev/null; then
        curl -L -o "$file" "$apk_url" 2>&1
    elif command -v wget &>/dev/null; then
        wget -O "$file" "$apk_url" 2>&1
    fi

    if [[ -f "$file" ]]; then
        OK "Downloaded: $file"
        # Rename to zip for magiskboot extraction
        cp "$file" "$CACHE_DIR/Magisk-${version#v}.zip" 2>/dev/null
    else
        FAIL "Download failed"
    fi
    WAIT_KEY
}

choose_selinux_mode() {
    echo -e "\n  ${CYAN}Pilih SELinux mode saat root:${NC}"
    echo "    1) Enforcing (default — lebih aman)"
    echo "    2) Permissive (lebih longgar — debugging)"
    echo ""
    echo -en "  Mode [1/2]: "
    read -r mode
    case $mode in
        1) SELinux_MODE="enforcing" ;;
        2) SELinux_MODE="permissive" ;;
        *) SELinux_MODE="enforcing" ;;
    esac
    INFO "SELinux mode: $SELinux_MODE"
}

backup_boot() {
    mkdir -p "$BACKUP_DIR"
    local ts=$(date +%Y%m%d_%H%M%S)
    if is_root; then
        INFO "Backing up boot.img..."
        su -c "dd if=/dev/block/by-name/boot of=$BACKUP_DIR/boot_${ts}.img bs=4096" 2>/dev/null
        # Also backup init_boot if exists
        if [[ -e /dev/block/by-name/init_boot ]]; then
            su -c "dd if=/dev/block/by-name/init_boot of=$BACKUP_DIR/init_boot_${ts}.img bs=4096" 2>/dev/null
            OK "init_boot backed up"
        fi
        OK "boot backed up: $BACKUP_DIR/boot_${ts}.img"
    fi
}

patch_boot_image() {
    HEADER "Patch Boot Image (Magisk)"
    download_magisk
    backup_boot
    choose_selinux_mode

    INFO "Extracting magiskboot..."
    local magisk_zip=$(ls "$CACHE_DIR"/Magisk-*.zip 2>/dev/null | head -1)
    if [[ -z "$magisk_zip" ]]; then
        FAIL "Magisk zip not found. Download first."
        return 1
    fi

    cd "$CACHE_DIR"
    unzip -o "$magisk_zip" "lib/arm64-v8a/libmagiskboot.so" 2>/dev/null
    chmod +x "$CACHE_DIR/lib/arm64-v8a/libmagiskboot.so" 2>/dev/null

    # Extract boot image from device
    local boot_img="$CACHE_DIR/boot.img"
    if is_root; then
        su -c "dd if=/dev/block/by-name/boot of=$boot_img bs=4096" 2>/dev/null
    else
        FAIL "Root required to extract boot image"
        return 1
    fi

    INFO "Patching boot image with Magisk..."
    local magiskboot="$CACHE_DIR/lib/arm64-v8a/libmagiskboot.so"
    if [[ -x "$magiskboot" ]]; then
        "$magiskboot" unpack "$boot_img" 2>/dev/null
        # Apply Magisk patch
        local ramdisk="$CACHE_DIR/ramdisk.cpio"
        if [[ -f "$ramdisk" ]]; then
            "$magiskboot" cpio "$ramdisk" 2>/dev/null
            "$magiskboot" repack "$boot_img" "$CACHE_DIR/magisk_patched_boot.img" 2>/dev/null
            OK "Patched: $CACHE_DIR/magisk_patched_boot.img"
        else
            WARN "ramdisk.cpio not found, trying direct patch..."
            "$magiskboot" patch "$boot_img" "$CACHE_DIR/magisk_patched_boot.img" 2>/dev/null
        fi
    fi

    # Apply SELinux mode
    if [[ "$SELinux_MODE" == "permissive" ]]; then
        INFO "Applying permissive SELinux..."
        # Create Magisk module for persistent permissive
        local mod_dir="/data/adb/modules/rmx3760_selinux"
        if is_root; then
            su -c "mkdir -p $mod_dir/system/etc"
            su -c "echo 'persist.sys.selinux=permissive' > $mod_dir/system/etc/prop.default"
            su -c "touch $mod_dir/auto_mount"
            OK "Permissive module created"
        fi
    fi

    WAIT_KEY
}

install_magisk() {
    HEADER "Install Magisk"
    local patched="$CACHE_DIR/magisk_patched_boot.img"

    if [[ ! -f "$patched" ]]; then
        FAIL "Patched boot image tidak ditemukan. Patch dulu."
        return 1
    fi

    echo -e "  Pilih metode install:"
    echo "    1) Fastboot (bootloader unlocked)"
    echo "    2) CVE-2022-38694 (download mode)"
    echo ""
    echo -en "  Metode [1/2]: "
    read -r method

    case $method in
        1)
            if command -v fastboot &>/dev/null; then
                fastboot flash boot "$patched" 2>&1
                if [[ $? -eq 0 ]]; then
                    OK "Boot flashed via fastboot"
                    fastboot reboot 2>/dev/null
                else
                    FAIL "Flash failed"
                fi
            else
                FAIL "fastboot tidak tersedia"
            fi
            ;;
        2)
            INFO "Masuk download mode dulu..."
            if is_root; then
                su -c "reboot autodloader" 2>/dev/null
                OK "Reboot to download mode sent"
                echo ""
                echo "  Next: jalankan CVE tool di PC untuk flash patched boot"
            fi
            ;;
    esac
    WAIT_KEY
}

uninstall_magisk() {
    HEADER "Uninstall Magisk"
    echo -e "  ${YELLOW}Uninstall akan mengembalikan boot.img original${NC}"
    if ! CONFIRM "Lanjutkan uninstall?"; then return; fi

    # Restore from backup
    local latest_boot=$(ls -t "$BACKUP_DIR"/boot_*.img 2>/dev/null | head -1)
    if [[ -n "$latest_boot" ]]; then
        INFO "Restoring boot from $(basename $latest_boot)..."
        if is_root; then
            su -c "dd if=$latest_boot of=/dev/block/by-name/boot bs=4096" 2>/dev/null
            OK "Boot restored"
        fi
    else
        FAIL "No boot backup found"
    fi

    # Remove Magisk data
    if is_root; then
        su -c "rm -rf /data/adb/magisk" 2>/dev/null
        su -c "rm -rf /data/adb/modules" 2>/dev/null
        OK "Magisk data removed"
    fi
    WAIT_KEY
}

verify_root() {
    HEADER "Verifikasi Root"
    local uid=$(su -c "id" 2>/dev/null)
    local magisk=$(su -c "magisk -v" 2>/dev/null)
    local selinux=$(su -c "getenforce" 2>/dev/null)

    if echo "$uid" | grep -q "uid=0"; then
        OK "Root: ACTIVE ($uid)"
    else
        FAIL "Root: NOT ACTIVE"
    fi
    echo -e "  Magisk version: ${WHITE}$magisk${NC}"
    echo -e "  SELinux mode:   ${WHITE}$selinux${NC}"
    WAIT_KEY
}

menu_magisk() {
    while true; do
        BANNER
        echo -e "${MAGENTA}═══ Magisk Root ═══${NC}"
        echo ""
        echo "  1) Status Magisk"
        echo "  2) Download Magisk"
        echo "  3) Patch Boot Image"
        echo "  4) Install Magisk"
        echo "  5) Uninstall Magisk"
        echo "  6) Verifikasi Root"
        echo "  7) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) check_magisk ;;
            2) download_magisk ;;
            3) patch_boot_image ;;
            4) install_magisk ;;
            5) uninstall_magisk ;;
            6) verify_root ;;
            7) return ;;
        esac
    done
}

menu_magisk
