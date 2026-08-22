#!/data/data/com.termux/files/usr/bin/bash
# Auto TWRP Builder/Porter - Realme C53 RMX3760 Android 15
# by@arriRgb31
#
# Referensi:
#   - Hovatek TWRP Builder: https://www.hovatek.com/blog/hovateks-twrp-builder/
#   - Hovatek TWRP Builder tool: https://www.hovatek.com/twrpbuilder/
#   - Hovatek Unisoc SPD porter: https://www.hovatek.com/blog/auto-twrp-porter-mtk-v1-6-unisoc-spd-v1-4/
#   - rtyutechstudio Unisoc DRM patch: https://github.com/rtyutechstudio/unisoc-twrp-sourcecode_patch
#   - Device tree: https://github.com/arriRgb31/RMX3760
#
# STATUS (commit b228103, 22 Agustus 2026):
#   - Build vendor_boot SUKSES
#   - STUCK logo "Powered by Android" (Unisoc DRM incompatibility)
#   - ADB device TERDETEKSI, adb shell MASUK (bukan berarti recovery normal)
#   - Masih ada mismatch (boot@1.1.so perlu __libcpp_verbose_abort)
#   - TIDAK ada bootloop
#   - TWRP GUI belum muncul (display/DRM issue)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/colors.sh"
source "$SCRIPT_DIR/../core/device.sh"

DEVICE_TREE="$HOME/RMX3760"
DEVICE_TREE_REPO="https://github.com/arriRgb31/RMX3760.git"

show_twrp_status() {
    HEADER "TWRP Build Status"
    echo -e "  ${YELLOW}STATUS: Work-in-progress - Build OK, Display issue${NC}"
    echo ""
    echo "  Commit terakhir:     b228103 (fix libc++ mismatch)"
    echo "  CI:                  https://github.com/arriRgb31/RMX3760/actions"
    echo ""
    echo "  Yang SUDAH berhasil:"
    echo "    - Build vendor_boot.img tanpa error"
    echo "    - Boot ke recovery (tidak bootloop)"
    echo "    - ADB terdeteksi, adb shell masuk"
    echo "    - USB configfs (VID 0x1782) correct"
    echo ""
    echo "  Yang MASIH bermasalah:"
    echo "    - STUCK logo 'Powered by Android' (DRM issue)"
    echo "    - TWRP GUI tidak muncul"
    echo "    - Recovery service crash loop"
    echo ""
    echo "  Root cause display:"
    echo "    - TWRP pakai atomic DRM (drmModeAtomicCommit)"
    echo "    - Unisoc UMS9230 butuh legacy DRM (drmModeSetCrtc)"
    echo "    - Fix: refactor graphics_drm.cpp"
    echo "    - Ref: rtyutechstudio/unisoc-twrp-sourcecode_patch"
    WAIT_KEY
}

clone_device_tree() {
    HEADER "Clone Device Tree"
    if [[ -d "$DEVICE_TREE/.git" ]]; then
        OK "Device tree already exists: $DEVICE_TREE"
        if CONFIRM "Update from remote?"; then
            cd "$DEVICE_TREE" && git pull origin main 2>&1
            OK "Updated"
        fi
    else
        INFO "Cloning from $DEVICE_TREE_REPO..."
        git clone "$DEVICE_TREE_REPO" "$DEVICE_TREE" 2>&1
        [[ -d "$DEVICE_TREE/.git" ]] && OK "Cloned" || FAIL "Clone failed"
    fi
    WAIT_KEY
}

setup_build_env() {
    HEADER "Setup Build Environment"
    echo "  Prasyarat: JDK 17, repo, ~20GB, AOSP source"
    local java=$(java -version 2>&1 | head -1)
    echo "  Java: ${java:-NOT FOUND}"
    echo "  repo: $(command -v repo 2>/dev/null || echo 'NOT FOUND')"
    echo "  AOSP: $([ -d ~/aosp ] && echo 'OK' || echo 'NOT FOUND')"
    echo ""
    echo "  CI builds: https://github.com/arriRgb31/RMX3760/actions"
    WAIT_KEY
}

build_twrp() {
    HEADER "Build TWRP"
    if [[ ! -d "$DEVICE_TREE/.git" ]]; then
        FAIL "Device tree not found. Clone first."
        WAIT_KEY
        return
    fi
    echo "  Full build requires AOSP source tree."
    echo "  Use CI for automated builds:"
    echo "  https://github.com/arriRgb31/RMX3760/actions"
    WAIT_KEY
}

flash_twrp() {
    HEADER "Flash TWRP"
    local vendor_boot="$HOME/RMX3760/out/target/product/twrp_RMX3760/vendor_boot.img"
    if [[ ! -f "$vendor_boot" ]]; then
        FAIL "vendor_boot.img tidak ditemukan"
        echo "  Download dari CI artifacts"
        WAIT_KEY
        return
    fi
    echo "  1) fastboot flash vendor_boot"
    echo "  2) CVE-2022-38694 (download mode)"
    echo -en "  Metode [1/2]: "
    read -r method
    case $method in
        1) command -v fastboot &>/dev/null && fastboot flash vendor_boot "$vendor_boot" 2>&1 && OK "Flashed" || FAIL "fastboot not found" ;;
        2) su -c "reboot autodloader" 2>/dev/null && OK "Reboot to download mode" ;;
    esac
    WAIT_KEY
}

verify_twrp() {
    HEADER "Verifikasi TWRP"
    echo -e "  ${YELLOW}Known: Stuck di logo 'Powered by Android'${NC}"
    echo "  ADB mungkin terdeteksi tapi GUI belum muncul"
    echo ""
    if CONFIRM "Reboot recovery sekarang?"; then
        is_root && su -c "reboot recovery" 2>/dev/null && OK "Rebooting..."
    fi
    WAIT_KEY
}

menu_twrp() {
    while true; do
        BANNER
        echo -e "${MAGENTA}=== Auto TWRP Builder ===${NC}"
        echo -e "  ${YELLOW}(Work-in-progress - Build OK, Display issue)${NC}"
        echo ""
        echo "  1) Status TWRP"
        echo "  2) Clone/Update Device Tree"
        echo "  3) Setup Build Environment"
        echo "  4) Build TWRP"
        echo "  5) Flash TWRP"
        echo "  6) Verifikasi TWRP"
        echo "  7) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) show_twrp_status ;; 2) clone_device_tree ;; 3) setup_build_env ;;
            4) build_twrp ;; 5) flash_twrp ;; 6) verify_twrp ;; 7) return ;;
        esac
    done
}

menu_twrp
