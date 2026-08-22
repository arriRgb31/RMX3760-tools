#!/data/data/com.termux/files/usr/bin/bash
# RMX3760 Tools - Cross-platform Launcher
# Realme C53 | Unisoc UMS9230 T612 | Android 15
# by@arriRgb31
#
# Referensi:
#   - Bootchain: ~/Bootchain_Android15_Unlocked.md
#   - Device tree: https://github.com/arriRgb31/RMX3760
#   - CVE-2022-38694: https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader
#   - UnisocBypass: https://github.com/TheGammaSqueeze/UnisocBypass
#
# Supports: Termux (root/proot), Linux, macOS

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TOOLS_DIR

source "$TOOLS_DIR/core/colors.sh"
source "$TOOLS_DIR/core/platform.sh"

# Platform init
detect_platform
set_platform_paths

BANNER
echo -e "  Platform: ${WHITE}$PLATFORM${NC} ($ARCH)"
echo -e "  Tools:    ${WHITE}$TOOLS_DIR${NC}"
if command -v getprop &>/dev/null; then
    local model=$(getprop ro.product.model 2>/dev/null)
    local android=$(getprop ro.build.version.release 2>/dev/null)
    [[ -n "$model" ]] && echo -e "  Device:   ${WHITE}$model${NC} (Android $android)"
fi
echo ""

menu_main() {
    while true; do
        BANNER
        detect_platform
        echo -e "  Platform: ${WHITE}$PLATFORM${NC} ($ARCH)"
        if command -v getprop &>/dev/null; then
            local model=$(getprop ro.product.model 2>/dev/null)
            local android=$(getprop ro.build.version.release 2>/dev/null)
            [[ -n "$model" ]] && echo -e "  Device:   ${WHITE}$model${NC} (Android $android)"
        fi
        echo ""
        echo -e "${CYAN}=== RMX3760 Tools Menu ===${NC}"
        echo ""
        echo "  [1]  Unlock / Relock Bootloader"
        echo "  [2]  AVB Patch/Unpatch (FLAGS 1/2/3)"
        echo "  [3]  DM-Verity Patch/Unpatch"
        echo "  [4]  SELinux Patch/Unpatch"
        echo "  [5]  Root — Magisk"
        echo "  [6]  Root — KernelSU"
        echo "  [7]  Root — APatch"
        echo "  [8]  Auto TWRP Builder"
        echo "  [9]  Runtime Logging"
        echo "  [10] Reboot & FDL2"
        echo "  [11] ADB/Fastboot + Unisoc Drivers"
        echo "  [h]  Help (Professional)"
        echo "  [q]  Keluar"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1)  bash "$TOOLS_DIR/unlock/unlock.sh" ;;
            2)  bash "$TOOLS_DIR/avb/avb_patch.sh" ;;
            3)  bash "$TOOLS_DIR/dmverity/dmverity.sh" ;;
            4)  bash "$TOOLS_DIR/selinux/selinux.sh" ;;
            5)  bash "$TOOLS_DIR/root/root_magisk.sh" ;;
            6)  bash "$TOOLS_DIR/root/root_ksu.sh" ;;
            7)  bash "$TOOLS_DIR/root/root_apatch.sh" ;;
            8)  bash "$TOOLS_DIR/twrp/auto_twrp.sh" ;;
            9)  bash "$TOOLS_DIR/logging/logger.sh" ;;
            10) bash "$TOOLS_DIR/reboot/reboot.sh" ;;
            11) bash "$TOOLS_DIR/core/adb_setup.sh" ;;
            h|H) bash "$TOOLS_DIR/help/help.sh" ;;
            q|Q) echo -e "${GREEN}Keluar.${NC}"; exit 0 ;;
            *)  FAIL "Invalid choice" ;;
        esac
    done
}

menu_main
