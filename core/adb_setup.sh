#!/data/data/com.termux/files/usr/bin/bash
# ADB/Fastboot Platform Tools - Android 15 Unisoc UMS9230
# by@arriRgb31
#
# Referensi:
#   - AOSP Platform Tools: https://developer.android.com/tools/releases/platform-tools
#   - AOSP Android 15: https://source.android.com/docs/setup/about/android-15-release
#   - Unisoc USB VID: 0x1782
#   - termux-adb: https://github.com/nohajc/termux-adb
#   - spreadtrum_flash: https://github.com/TomKing062/spreadtrum_flash
#   - UnisocBypass: https://github.com/TheGammaSqueeze/UnisocBypass
#   - Bootchain: Bootchain_Android15_Unlocked.md
#
# Platform tools AOSP Android 15:
#   adb/fastboot version: 35.0.2+
#   Support: Bootloader, sideload, flash, partition management
#
# Unisoc-specific:
#   VID: 0x1782 (Spreadtrum Communications / Unisoc)
#   Download mode PID: 0x0001 (SPL/FDL1), 0x0002 (FDL2)
#   ADB mode PID: 0x4001, 0x4d00 (USB configfs)
#   Fastboot PID: 0x0010

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/colors.sh"

TOOLS_DIR="$HOME/RMX3760-tools"
PLATFORM_TOOLS_DIR="$TOOLS_DIR/platform-tools"
CACHE_DIR="$TOOLS_DIR/cache"
PLATFORM_TOOLS_URL="https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
UNISOC_VID="0x1782"

download_platform_tools() {
    HEADER "Download AOSP Platform Tools (Android 15)"
    mkdir -p "$CACHE_DIR"
    local zipfile="$CACHE_DIR/platform-tools.zip"

    if [[ -f "$PLATFORM_TOOLS_DIR/adb" ]]; then
        local cur=$("$PLATFORM_TOOLS_DIR/adb" version 2>/dev/null | head -1)
        OK "Platform tools ada: $cur"
        if ! CONFIRM "Update ke versi terbaru?"; then return 0; fi
        rm -rf "$PLATFORM_TOOLS_DIR"
    fi

    INFO "Download: $PLATFORM_TOOLS_URL"
    if command -v curl &>/dev/null; then
        curl -L -o "$zipfile" "$PLATFORM_TOOLS_URL" 2>&1
    elif command -v wget &>/dev/null; then
        wget -O "$zipfile" "$PLATFORM_TOOLS_URL" 2>&1
    else
        FAIL "curl/wget tidak ada"
        return 1
    fi

    if [[ -f "$zipfile" ]]; then
        unzip -o "$zipfile" -d "$TOOLS_DIR/" >/dev/null 2>&1
        chmod +x "$PLATFORM_TOOLS_DIR/"* 2>/dev/null
        local av=$("$PLATFORM_TOOLS_DIR/adb" version 2>/dev/null | head -1)
        local fv=$("$PLATFORM_TOOLS_DIR/fastboot" --version 2>/dev/null | head -1)
        OK "adb: $av"
        OK "fastboot: $fv"
        rm -f "$zipfile"
    else
        FAIL "Download gagal"
    fi
    WAIT_KEY
}

setup_path() {
    HEADER "Setup PATH"
    local line="export PATH=\"\$HOME/RMX3760-tools/platform-tools:\$PATH\""
    local bashrc="$HOME/.bashrc"
    if grep -q "RMX3760-tools/platform-tools" "$bashrc" 2>/dev/null; then
        OK "PATH sudah ada di .bashrc"
    else
        echo "" >> "$bashrc"
        echo "# RMX3760 AOSP Platform Tools" >> "$bashrc"
        echo "$line" >> "$bashrc"
        OK "PATH ditambahkan ke .bashrc"
        echo "  Jalankan: source ~/.bashrc"
    fi
    WAIT_KEY
}

install_termux_adb() {
    HEADER "Install termux-adb"
    echo "  Patched adb/fastboot untuk Termux tanpa root"
    echo "  Source: https://github.com/nohajc/termux-adb"
    echo ""

    if command -v termux-adb &>/dev/null; then
        OK "Sudah terinstall"
        WAIT_KEY
        return
    fi

    if CONFIRM "Install sekarang?"; then
        pkg install -y termux-api termux-adb 2>&1 | tail -5
        command -v termux-adb &>/dev/null && OK "Installed" || FAIL "Gagal"
    fi
    WAIT_KEY
}

install_spreadtrum_flash() {
    HEADER "Install spreadtrum_flash (TomKing)"
    echo "  Source: https://github.com/TomKing062/spreadtrum_flash"
    echo "  Flash Unisoc dari Termux via libusb"
    echo ""

    local stf="$TOOLS_DIR/spreadtrum_flash"
    if [[ -f "$stf/spd_dump" ]]; then
        OK "Sudah terinstall: $stf"
        WAIT_KEY
        return
    fi

    if CONFIRM "Clone dan build?"; then
        pkg install -y termux-api libusb clang git 2>&1 | tail -3
        git clone https://github.com/TomKing062/spreadtrum_flash.git "$stf" 2>&1
        cd "$stf" && make 2>&1
        [[ -f "spd_dump" ]] && OK "Built: $stf/spd_dump" || FAIL "Build gagal"
    fi
    WAIT_KEY
}

setup_udev_rules() {
    HEADER "Setup udev rules (Unisoc VID 0x1782)"
    local rules="/etc/udev/rules.d/51-android.rules"
    local ini="$HOME/.android/adb_usb.ini"

    if [[ -f "$rules" ]] && grep -q "1782" "$rules" 2>/dev/null; then
        OK "udev rules sudah ada"
    else
        mkdir -p /etc/udev/rules.d 2>/dev/null
        local tmp="/tmp/51-android.rules"
        echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1782", MODE="0666", GROUP="plugdev"' > "$tmp"
        echo 'ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ENV{ID_USB_INTERFACES}=="*:ff420?:*", MODE="0666"' >> "$tmp"
        if cp "$tmp" "$rules" 2>/dev/null; then
            OK "udev rules written"
        else
            INFO "Butuh root. Copy manual:"
            echo "  sudo cp $tmp $rules"
            echo "  sudo udevadm control --reload-rules"
        fi
        rm -f "$tmp"
    fi

    mkdir -p "$HOME/.android"
    if [[ -f "$ini" ]] && grep -q "0x1782" "$ini" 2>/dev/null; then
        OK "adb_usb.ini sudah ada"
    else
        echo "0x1782" >> "$ini"
        OK "0x1782 ditambahkan ke adb_usb.ini"
    fi

    command -v udevadm &>/dev/null && udevadm control --reload-rules 2>/dev/null
    WAIT_KEY
}

detect_unisoc_device() {
    HEADER "Detect Unisoc Device"
    if command -v lsusb &>/dev/null; then
        local devices=$(lsusb | grep -i "1782\|spreadtrum\|unisoc")
        if [[ -n "$devices" ]]; then
            OK "Unisoc device ditemukan:"
            echo "$devices"
        else
            WARN "Tidak ada Unisoc device terdeteksi"
            echo "  Pastikan USB terhubung dan device dalam mode ADB/download"
        fi
    else
        FAIL "lsusb tidak tersedia (install: pkg install usbutils)"
    fi
    echo ""
    echo "  Unisoc USB modes:"
    echo "    VID:PID 1782:4001 = ADB mode"
    echo "    VID:PID 1782:4d00 = ADB (USB configfs)"
    echo "    VID:PID 1782:0001 = SPL/FDL1 download"
    echo "    VID:PID 1782:0002 = FDL2 download"
    echo "    VID:PID 1782:0010 = Fastboot"
    WAIT_KEY
}

setup_all() {
    HEADER "Setup All - ADB + Drivers"
    download_platform_tools
    setup_path
    install_termux_adb
    install_spreadtrum_flash
    setup_udev_rules
    detect_unisoc_device
    OK "Setup selesai"
    WAIT_KEY
}

menu_adb() {
    while true; do
        BANNER
        echo -e "${MAGENTA}=== ADB/Fastboot + Unisoc Drivers ===${NC}"
        echo ""
        echo "  1) Download AOSP Platform Tools (Android 15)"
        echo "  2) Setup PATH"
        echo "  3) Install termux-adb (non-root)"
        echo "  4) Install spreadtrum_flash (TomKing)"
        echo "  5) Setup udev rules (Unisoc VID)"
        echo "  6) Detect Unisoc device"
        echo "  7) Setup All"
        echo "  8) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) download_platform_tools ;; 2) setup_path ;; 3) install_termux_adb ;;
            4) install_spreadtrum_flash ;; 5) setup_udev_rules ;;
            6) detect_unisoc_device ;; 7) setup_all ;; 8) return ;;
        esac
    done
}

menu_adb
