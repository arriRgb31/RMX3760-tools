#!/data/data/com.termux/files/usr/bin/bash
# KernelSU Root — Realme C53 RMX3760 Android 15
# by@arriRgb31
#
# Referensi:
#   - KernelSU: https://kernelsu.org/
#   - KernelSU source: https://github.com/tiann/ksu
#   - KernelSU Next: https://github.com/rifsxd/KernelSU-Next
#   - Bootchain: Bootchain_Android15_Unlocked.md

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/colors.sh"
source "$SCRIPT_DIR/../core/device.sh"

CACHE_DIR="$HOME/RMX3760-tools/cache/ksu"
BACKUP_DIR="$HOME/RMX3760-tools/backups/boot"
SELinux_MODE="enforcing"

check_ksu() {
    HEADER "KernelSU Status"
    local ksu_version=$(su -c "ksud --version" 2>/dev/null)
    local ksu_flag=$(cat /proc/sys/kernel/ksu/enabled 2>/dev/null)

    if [[ -n "$ksu_version" ]]; then
        OK "KernelSU installed: $ksu_version"
    else
        FAIL "KernelSU tidak terinstall"
    fi

    echo -e "  KSU enabled: ${WHITE}${ksu_flag:-0}${NC}"
    echo -e "  0=disabled, 1=enabled"

    # Check manager
    local manager=$(pm list packages 2>/dev/null | grep kernelsu)
    echo -e "  Manager: ${WHITE}${manager:-not installed}${NC}"
    WAIT_KEY
}

download_ksu() {
    HEADER "Download KernelSU"
    mkdir -p "$CACHE_DIR"

    INFO "KernelSU Unisoc: Download kernel image dari GitHub releases"
    echo "  Repo: https://github.com/tiann/ksu/releases"
    echo "  Cari: kernel image untuk UMS9230 / RMX3760 / Android 15"
    echo ""
    echo -e "  ${YELLOW}Note: KernelSU membutuhkan kernel yang sudah di-patch.${NC}"
    echo "  Jika tidak ada prebuilt, perlu build dari source dengan KSU patch."
    echo ""
    echo "  Alternatif:"
    echo "  - KernelSU Next: https://github.com/rifsxd/KernelSU-Next"
    echo "  - Patch manual: clone kernel source, apply KSU patch, build"
    WAIT_KEY
}

patch_boot_image() {
    HEADER "Patch Boot Image (KernelSU)"
    choose_selinux_mode
    backup_boot

    INFO "KernelSU patch via ksud binary..."
    local ksud="$CACHE_DIR/ksud"

    if [[ ! -f "$ksud" ]]; then
        FAIL "ksud binary tidak ditemukan. Download dulu."
        return 1
    fi

    chmod +x "$ksud"

    local boot_img="$CACHE_DIR/boot.img"
    if is_root; then
        su -c "dd if=/dev/block/by-name/boot of=$boot_img bs=4096" 2>/dev/null
    else
        FAIL "Root required"
        return 1
    fi

    INFO "Patching boot with KernelSU..."
    "$ksud" boot patch "$boot_img" "$CACHE_DIR/kernelsu_patched_boot.img" --selinux-mode "$SELinux_MODE" 2>&1

    if [[ -f "$CACHE_DIR/kernelsu_patched_boot.img" ]]; then
        OK "Patched: $CACHE_DIR/kernelsu_patched_boot.img"
    else
        FAIL "Patch failed"
    fi
    WAIT_KEY
}

install_ksu() {
    HEADER "Install KernelSU"
    local patched="$CACHE_DIR/kernelsu_patched_boot.img"

    if [[ ! -f "$patched" ]]; then
        FAIL "Patched boot not found. Patch first."
        return 1
    fi

    echo "  Metode:"
    echo "    1) Fastboot flash boot"
    echo "    2) CVE-2022-38694 (download mode)"
    echo ""
    echo -en "  Metode [1/2]: "
    read -r method

    case $method in
        1)
            fastboot flash boot "$patched" 2>&1 && OK "Flashed" || FAIL "Flash failed"
            ;;
        2)
            su -c "reboot autodloader" 2>/dev/null
            OK "Reboot to download mode"
            echo "  Run CVE tool on PC to flash patched boot"
            ;;
    esac
    WAIT_KEY
}

uninstall_ksu() {
    HEADER "Uninstall KernelSU"
    local latest=$(ls -t "$BACKUP_DIR"/boot_*.img 2>/dev/null | head -1)
    if [[ -n "$latest" ]]; then
        su -c "dd if=$latest of=/dev/block/by-name/boot bs=4096" 2>/dev/null
        OK "Boot restored from backup"
    else
        FAIL "No backup found"
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

menu_ksu() {
    while true; do
        BANNER
        echo -e "${MAGENTA}═══ KernelSU Root ═══${NC}"
        echo ""
        echo "  1) Status KernelSU"
        echo "  2) Download KernelSU"
        echo "  3) Patch Boot Image"
        echo "  4) Install KernelSU"
        echo "  5) Uninstall KernelSU"
        echo "  6) Verifikasi Root"
        echo "  7) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) check_ksu ;;
            2) download_ksu ;;
            3) patch_boot_image ;;
            4) install_ksu ;;
            5) uninstall_ksu ;;
            6) verify_root ;;
            7) return ;;
        esac
    done
}

menu_ksu
