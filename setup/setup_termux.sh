#!/data/data/com.termux/files/usr/bin/bash
# RMX3760 Tools — Termux Setup
# by@arriRgb31
#
# Download dan install semua tools yang diperlukan

echo "=== RMX3760 Tools — Termux Setup ==="
echo ""

TOOLS_DIR="$HOME/RMX3760-tools"
BIN_DIR="$TOOLS_DIR/tools/bin/termux"
DL_DIR="$TOOLS_DIR/tools/downloads"

mkdir -p "$BIN_DIR" "$DL_DIR"

# 1. Core packages
echo "[1/6] Installing core packages..."
pkg update -y 2>/dev/null
pkg install -y curl wget git unzip usbutils 2>/dev/null

# 2. AOSP Platform Tools
echo ""
echo "[2/6] Downloading AOSP Platform Tools..."
if [[ -f "$BIN_DIR/platform-tools/adb" ]]; then
    echo "[OK] Platform tools sudah ada"
else
    curl -L -o "$DL_DIR/platform-tools.zip" \
        "https://dl.google.com/android/repository/platform-tools-latest-linux.zip" 2>/dev/null
    unzip -o "$DL_DIR/platform-tools.zip" -d "$BIN_DIR/" >/dev/null 2>&1
    chmod +x "$BIN_DIR/platform-tools/"* 2>/dev/null
    echo "[OK] Platform tools installed"
    rm -f "$DL_DIR/platform-tools.zip"
fi

# 3. termux-adb (non-root)
echo ""
echo "[3/6] Installing termux-adb..."
pkg install -y termux-api 2>/dev/null
pkg install -y termux-adb 2>/dev/null || echo "[WARN] termux-adb install failed"

# 4. spreadtrum_flash (TomKing)
echo ""
echo "[4/6] Installing spreadtrum_flash..."
STF_DIR="$TOOLS_DIR/tools/bin/termux/spreadtrum_flash"
if [[ -f "$STF_DIR/spd_dump" ]]; then
    echo "[OK] spreadtrum_flash sudah ada"
else
    pkg install -y libusb clang 2>/dev/null
    git clone https://github.com/TomKing062/spreadtrum_flash.git "$STF_DIR" 2>/dev/null
    if [[ -d "$STF_DIR" ]]; then
        cd "$STF_DIR" && make 2>/dev/null
        [[ -f "spd_dump" ]] && echo "[OK] spd_dump built" || echo "[WARN] Build failed"
    fi
fi

# 5. CVE tool
echo ""
echo "[5/6] Downloading CVE-2022-38694..."
CVE_DIR="$DL_DIR/cve-2022-38694"
if [[ -d "$CVE_DIR" ]] && ls "$CVE_DIR"/*ums9230* &>/dev/null; then
    echo "[OK] CVE tool sudah ada"
else
    mkdir -p "$CVE_DIR"
    curl -L -o "$CVE_DIR/cve-tool.zip" \
        "https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader/releases/download/1.72/ums9230_Realme_C53_RMX3760_RMX3762.zip" 2>/dev/null
    unzip -o "$CVE_DIR/cve-tool.zip" -d "$CVE_DIR/" >/dev/null 2>&1
    echo "[OK] CVE tool downloaded"
    rm -f "$CVE_DIR/cve-tool.zip"
fi

# 6. Unisoc USB rules
echo ""
echo "[6/6] Setting up USB rules..."
RULES="/etc/udev/rules.d/51-android.rules"
mkdir -p /etc/udev/rules.d 2>/dev/null
if [[ ! -f "$RULES" ]] || ! grep -q "1782" "$RULES" 2>/dev/null; then
    echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1782", MODE="0666", GROUP="plugdev"' > "$RULES" 2>/dev/null
    echo "[OK] udev rules written"
fi

mkdir -p "$HOME/.android"
INI="$HOME/.android/adb_usb.ini"
if [[ ! -f "$INI" ]] || ! grep -q "0x1782" "$INI" 2>/dev/null; then
    echo "0x1782" >> "$INI"
    echo "[OK] 0x1782 added to adb_usb.ini"
fi

echo ""
echo "=== Setup selesai ==="
echo ""
echo "Tools location:"
echo "  Platform Tools: $BIN_DIR/platform-tools/"
echo "  spreadtrum:     $STF_DIR/spd_dump"
echo "  CVE tool:       $CVE_DIR/"
echo ""
echo "Jalankan: bash ~/RMX3760-tools/main.sh"
