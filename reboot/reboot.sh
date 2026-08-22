#!/data/data/com.termux/files/usr/bin/bash
# Reboot & FDL2 Tools — Realme C53 RMX3760 Android 15
# by@arriRgb31
#
# Referensi:
#   - Bootchain: Bootchain_Android15_Unlocked.md
#   - Unisoc LK: Boot ROM → SPL → SML → LK → kernel
#   - CVE-2022-38694: https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader
#
# FDL2 (download mode) = SPL memanggil FDL2 via USB, device masuk Unisoc download mode.
# Command: `reboot autodloader` (bukan reboot bootloader!)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/colors.sh"
source "$SCRIPT_DIR/../core/device.sh"

reboot_recovery() {
    HEADER "Reboot Recovery"
    if ! CONFIRM "Reboot ke recovery mode?"; then return; fi
    if is_root; then
        su -c "reboot recovery" 2>/dev/null
        OK "Reboot command sent"
    else
        FAIL "Root required"
    fi
}

reboot_bootloader() {
    HEADER "Reboot Bootloader (LK Fastboot)"
    echo -e "  Unisoc LK: masuk fastboot mode"
    if ! CONFIRM "Reboot ke bootloader?"; then return; fi
    if is_root; then
        su -c "reboot bootloader" 2>/dev/null
        OK "Reboot command sent"
    elif command -v fastboot &>/dev/null; then
        fastboot reboot 2>/dev/null
        OK "Reboot via fastboot"
    else
        FAIL "Root atau fastboot required"
    fi
}

reboot_fastboot() {
    HEADER "Reboot Fastboot"
    echo -e "  Pada Unisoc, fastboot = bootloader (LK fastboot mode)"
    if ! CONFIRM "Reboot ke fastboot?"; then return; fi
    if is_root; then
        su -c "reboot bootloader" 2>/dev/null
        OK "Reboot command sent"
    elif command -v fastboot &>/dev/null; then
        fastboot reboot 2>/dev/null
        OK "Reboot via fastboot"
    else
        FAIL "Root atau fastboot required"
    fi
}

reboot_system() {
    HEADER "Reboot System"
    if ! CONFIRM "Reboot ke system?"; then return; fi
    if is_root; then
        su -c "reboot" 2>/dev/null
        OK "Reboot command sent"
    else
        FAIL "Root required"
    fi
}

power_off() {
    HEADER "Power Off"
    if ! CONFIRM "Matikan device?"; then return; fi
    if is_root; then
        su -c "reboot -p" 2>/dev/null
        OK "Power off command sent"
    else
        FAIL "Root required"
    fi
}

enter_fdl2() {
    HEADER "Enter FDL2 (Unisoc Download Mode)"
    echo -e "  ${YELLOW}FDL2 = SPL/FDL1 exploit mode untuk CVE-2022-38694${NC}"
    echo -e "  Command: ${WHITE}reboot autodloader${NC}"
    echo -e "  BERBEDA dengan reboot bootloader!"
    echo ""
    echo "  Boot chain:"
    echo "    Boot ROM → SPL → FDL1 → [exploit here] → FDL2 → download mode"
    echo "    reboot autodloader langsung ke SPL → FDL2 download mode"
    echo ""
    echo -e "  ${CYAN}Prasyarat:${NC}"
    echo "    1) Device terhubung ke PC via USB"
    echo "    2) PC sudah install Unisoc/Spreadtrum USB driver"
    echo "    3) Root access atau reboot dari any state"
    echo ""
    if ! CONFIRM "Lanjutkan masuk FDL2?"; then return; fi

    if is_root; then
        INFO "Sending reboot autodloader..."
        su -c "reboot autodloader" 2>/dev/null
        OK "Reboot command sent. Device masuk download mode dalam ~5 detik."
        echo ""
        echo -e "  ${CYAN}Next steps:${NC}"
        echo "    1) Buka CVE tool di PC:"
        echo "       $HOME/RMX3760-tools/cache/cve-2022-38694/"
        echo "    2) Jalankan exploit tool:"
        echo "       ./ums9230_Realme_C53_RMX3760_RMX3762"
        echo "    3) Tool akan exploot SPL → boot unsigned images"
    else
        FAIL "Root required for reboot autodloader"
        echo ""
        INFO "Alternatif tanpa root:"
        echo "    1) Power off device"
        echo "    2) Tahan Volume Down + sambung USB ke PC"
        echo "    3) Device masuk download mode otomatis"
    fi
    WAIT_KEY
}

menu_reboot() {
    while true; do
        BANNER
        echo -e "${MAGENTA}═══ Reboot & FDL2 ═══${NC}"
        echo ""
        echo "  1) Reboot Recovery"
        echo "  2) Reboot Bootloader (LK Fastboot)"
        echo "  3) Reboot Fastboot"
        echo "  4) Reboot System"
        echo "  5) Power Off"
        echo "  6) Enter FDL2 (Download Mode)"
        echo "  7) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) reboot_recovery ;;
            2) reboot_bootloader ;;
            3) reboot_fastboot ;;
            4) reboot_system ;;
            5) power_off ;;
            6) enter_fdl2 ;;
            7) return ;;
        esac
    done
}

menu_reboot
