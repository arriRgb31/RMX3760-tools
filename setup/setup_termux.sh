#!/data/data/com.termux/files/usr/bin/bash
# RMX3760 Tools — Termux Setup
# by@arriRgb31
#
# Jalankan sekali di Termux untuk install dependencies

echo "=== RMX3760 Tools — Termux Setup ==="
echo ""

# Check if Termux
if [[ ! -d "/data/data/com.termux" ]]; then
    echo "[FAIL] Bukan Termux. Gunakan setup yang sesuai platform."
    exit 1
fi

echo "[INFO] Installing dependencies..."

# Core packages
pkg update -y 2>/dev/null
pkg install -y \
    curl wget git unzip \
    usbutils \
    android-tools \
    termux-api \
    2>/dev/null

echo ""
echo "[INFO] Optional packages..."

# Optional
pkg install -y \
    python \
    clang make \
    libusb \
    2>/dev/null

# termux-adb (non-root adb/fastboot)
echo ""
echo "[INFO] Installing termux-adb..."
pkg install -y termux-adb 2>/dev/null || echo "[WARN] termux-adb install failed"

# spreadtrum_flash
echo ""
echo "[INFO] Installing spreadtrum_flash..."
STF_DIR="$HOME/RMX3760-tools/spreadtrum_flash"
if [[ ! -f "$STF_DIR/spd_dump" ]]; then
    git clone https://github.com/TomKing062/spreadtrum_flash.git "$STF_DIR" 2>/dev/null
    if [[ -d "$STF_DIR" ]]; then
        cd "$STF_DIR" && make 2>/dev/null
        [[ -f "spd_dump" ]] && echo "[OK] spreadtrum_flash built" || echo "[WARN] Build failed"
    fi
else
    echo "[OK] spreadtrum_flash already installed"
fi

# Setup udev rules
echo ""
echo "[INFO] Setting up udev rules for Unisoc..."
RULES="/etc/udev/rules.d/51-android.rules"
mkdir -p /etc/udev/rules.d 2>/dev/null
if [[ ! -f "$RULES" ]] || ! grep -q "1782" "$RULES" 2>/dev/null; then
    echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1782", MODE="0666", GROUP="plugdev"' > "$RULES" 2>/dev/null
    echo "[OK] udev rules written"
else
    echo "[OK] udev rules already present"
fi

# adb_usb.ini
mkdir -p "$HOME/.android"
INI="$HOME/.android/adb_usb.ini"
if [[ ! -f "$INI" ]] || ! grep -q "0x1782" "$INI" 2>/dev/null; then
    echo "0x1782" >> "$INI"
    echo "[OK] 0x1782 added to adb_usb.ini"
else
    echo "[OK] adb_usb.ini already has 0x1782"
fi

# Add tools to PATH
BASHRC="$HOME/.bashrc"
if ! grep -q "RMX3760-tools" "$BASHRC" 2>/dev/null; then
    echo "" >> "$BASHRC"
    echo "# RMX3760 Tools" >> "$BASHRC"
    echo 'export PATH="$HOME/RMX3760-tools:$PATH"' >> "$BASHRC"
    echo '[OK] PATH added to .bashrc'
fi

echo ""
echo "=== Setup selesai ==="
echo "Jalankan: source ~/.bashrc && bash ~/RMX3760-tools/main.sh"
