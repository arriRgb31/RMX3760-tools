#!/data/data/com.termux/files/usr/bin/bash
# APatch Root — Realme C53 RMX3760 Android 15
# by@arriRgb31
#
# Referensi:
#   - APatch: https://github.com/bmax121/APatch
#   - APatch kernel: https://github.com/bmax121/KernelPatch
#   - Bootchain: Bootchain_Android15_Unlocked.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/colors.sh"
source "$SCRIPT_DIR/../core/device.sh"

CACHE_DIR="$HOME/RMX3760-tools/cache/apatch"
BACKUP_DIR="$HOME/RMX3760-tools/backups/boot"
SELinux_MODE="enforcing"

check_apatch() {
    HEADER "APatch Status"
    local apatch=$(su -c "apd --version" 2>/dev/null)
    if [[ -n "$apatch" ]]; then
        OK "APatch installed: $apatch"
    else
        FAIL "APatch tidak terinstall"
    fi
    WAIT_KEY
}

download_apatch() {
    HEADER "Download APatch"
    mkdir -p "$CACHE_DIR"

    INFO "Checking latest release..."
    local url="https://github.com/bmax121/APatch/releases/latest"
    local redirect=$(curl -sI -o /dev/null -w "%{redirect_url}" "$url" 2>/dev/null)
    local tag=$(echo "$redirect" | grep -o "tag/[^/]*" | cut -d'/' -f2)
    INFO "Latest tag: $tag"

    local apk_url="https://github.com/bmax121/APatch/releases/download/${tag}/app-release.apk"
    local file="$CACHE_DIR/APatch.apk"

    if curl -L -o "$file" "$apk_url" 2>&1; then
        OK "Downloaded: $file"
    else
        FAIL "Download failed"
    fi
    WAIT_KEY
}

patch_boot_image() {
    HEADER "Patch Boot Image (APatch)"
    choose_selinux_mode
    backup_boot

    local boot_img="$CACHE_DIR/boot.img"
    if is_root; then
        su -c "dd if=/dev/block/by-name/boot of=$boot_img bs=4096" 2>/dev/null
    else
        FAIL "Root required"
        return 1
    fi

    # APatch uses KernelPatch method
    local kpatch="$CACHE_DIR/KernelPatch"
    if [[ ! -d "$kpatch" ]]; then
        FAIL "KernelPatch not found. Download APatch app and extract KernelPatch binary."
        return 1
    fi

    INFO "Patching boot with APatch..."
    "$kpatch" patch "$boot_img" "$CACHE_DIR/apatch_patched_boot.img" --selinux-mode "$SELinux_MODE" 2>&1

    if [[ -f "$CACHE_DIR/apatch_patched_boot.img" ]]; then
        OK "Patched: $CACHE_DIR/apatch_patched_boot.img"
    else
        FAIL "Patch failed"
    fi
    WAIT_KEY
}

install_apatch() {
    HEADER "Install APatch"
    local patched="$CACHE_DIR/apatch_patched_boot.img"

    if [[ ! -f "$patched" ]]; then
        FAIL "Patched boot not found."
        return 1
    fi

    echo "  1) Fastboot flash boot"
    echo "  2) CVE-2022-38694 (download mode)"
    echo ""
    echo -en "  Metode [1/2]: "
    read -r method
    case $method in
        1) fastboot flash boot "$patched" 2>&1 && OK "Flashed" || FAIL "Failed" ;;
        2) su -c "reboot autodloader" 2>/dev/null; OK "Reboot to download mode" ;;
    esac
    WAIT_KEY
}

uninstall_apatch() {
    HEADER "Uninstall APatch"
    local latest=$(ls -t "$BACKUP_DIR"/boot_*.img 2>/dev/null | head -1)
    if [[ -n "$latest" ]]; then
        su -c "dd if=$latest of=/dev/block/by-name/boot bs=4096" 2>/dev/null
        OK "Boot restored"
    else
        FAIL "No backup"
    fi
    WAIT_KEY
}

verify_root() {
    HEADER "Verifikasi Root"
    local uid=$(su -c "id" 2>/dev/null)
    local selinux=$(su -c "getenforce" 2>/dev/null)
    if echo "$uid" | grep -q "uid=0"; then
        OK "Root: ACTIVE ($uid)"
    else
        FAIL "Root: NOT ACTIVE"
    fi
    echo -e "  SELinux: ${WHITE}$selinux${NC}"
    WAIT_KEY
}

choose_selinux_mode() {
    echo -e "\n  ${CYAN}SELinux mode:${NC}"
    echo "    1) Enforcing"
    echo "    2) Permissive"
    echo -en "  [1/2]: "
    read -r m
    [[ "$m" == "2" ]] && SELinux_MODE="permissive" || SELinux_MODE="enforcing"
    INFO "Mode: $SELinux_MODE"
}

backup_boot() {
    mkdir -p "$BACKUP_DIR"
    local ts=$(date +%Y%m%d_%H%M%S)
    if is_root && [[ ! -f "$BACKUP_DIR/boot_${ts}.img" ]]; then
        su -c "dd if=/dev/block/by-name/boot of=$BACKUP_DIR/boot_${ts}.img bs=4096" 2>/dev/null
        OK "Boot backed up"
    fi
}

menu_apatch() {
    while true; do
        BANNER
        echo -e "${MAGENTA}═══ APatch Root ═══${NC}"
        echo ""
        echo "  1) Status APatch"
        echo "  2) Download APatch"
        echo "  3) Patch Boot Image"
        echo "  4) Install APatch"
        echo "  5) Uninstall APatch"
        echo "  6) Verifikasi Root"
        echo "  7) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) check_apatch ;;
            2) download_apatch ;;
            3) patch_boot_image ;;
            4) install_apatch ;;
            5) uninstall_apatch ;;
            6) verify_root ;;
            7) return ;;
        esac
    done
}

menu_apatch
