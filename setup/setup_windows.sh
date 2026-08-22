#!/usr/bin/env bash
# RMX3760 Tools — Windows Setup (Git Bash / MSYS2 / WSL)
# by@arriRgb31
#
# Jalankan di Git Bash / MSYS2 / WSL untuk install dependencies

echo "=== RMX3760 Tools — Windows Setup ==="
echo ""

# Detect environment
if [[ -d "/data/data/com.termux" ]]; then
    echo "[FAIL] Ini Termux. Gunakan setup_termux.sh"
    exit 1
fi

if grep -qi "microsoft" /proc/version 2>/dev/null; then
    ENV="WSL"
else
    ENV="Git Bash"
fi
echo "[INFO] Environment: $ENV"
echo ""

# Check git
if command -v git &>/dev/null; then
    echo "[OK] git: $(git --version)"
else
    echo "[FAIL] git tidak ditemukan"
    echo "  Install: https://git-scm.com/download/win"
    exit 1
fi

# Check adb/fastboot
echo ""
echo "[INFO] Checking ADB/Fastboot..."
if command -v adb &>/dev/null; then
    echo "[OK] adb: $(adb version 2>/dev/null | head -1)"
else
    echo "[WARN] adb tidak ditemukan"
    echo "  Download: https://developer.android.com/tools/releases/platform-tools"
fi

if command -v fastboot &>/dev/null; then
    echo "[OK] fastboot: $(fastboot --version 2>/dev/null | head -1)"
else
    echo "[WARN] fastboot tidak ditemukan"
fi

# Download platform-tools if not present
if ! command -v adb &>/dev/null; then
    echo ""
    echo "[INFO] Downloading AOSP Platform Tools..."
    TOOLS_DIR="$HOME/RMX3760-tools"
    mkdir -p "$TOOLS_DIR"
    
    if command -v curl &>/dev/null; then
        curl -L -o "$TOOLS_DIR/platform-tools.zip" \
            "https://dl.google.com/android/repository/platform-tools-latest-linux.zip" 2>&1
    elif command -v wget &>/dev/null; then
        wget -O "$TOOLS_DIR/platform-tools.zip" \
            "https://dl.google.com/android/repository/platform-tools-latest-linux.zip" 2>&1
    fi
    
    if [[ -f "$TOOLS_DIR/platform-tools.zip" ]]; then
        unzip -o "$TOOLS_DIR/platform-tools.zip" -d "$TOOLS_DIR/" >/dev/null 2>&1
        chmod +x "$TOOLS_DIR/platform-tools/"* 2>/dev/null
        echo "[OK] Platform tools installed to $TOOLS_DIR/platform-tools/"
        rm -f "$TOOLS_DIR/platform-tools.zip"
        
        # Add to PATH
        export PATH="$TOOLS_DIR/platform-tools:$PATH"
    fi
fi

# Unisoc driver info
echo ""
echo "=== Unisoc USB Driver (Windows) ==="
echo ""
echo "  Download SPD Driver:"
echo "    https://spreadtrumdriver.com/"
echo "    https://mirrors.lolinet.com/software/windows/Unisoc/drivers/"
echo ""
echo "  Latest: SPD_Driver_R4.24.2705"
echo ""
echo "  Install:"
echo "    1. Download SPD_Driver_R4.24.2705.zip"
echo "    2. Extract"
echo "    3. Run DPInst64.exe (64-bit) atau DPInst32.exe (32-bit)"
echo "    4. Restart PC jika perlu"
echo ""

# Check if driver installed
if [[ "$ENV" == "WSL" ]]; then
    echo "  [WSL] USB devices perlu di-forward:"
    echo "    Install usbipd: https://github.com/dorssel/usbipd-win"
    echo "    usbipd list"
    echo "    usbipd bind --busid <BUSID>"
    echo "    usbipd attach --wsl --busid <BUSID>"
fi

# Add to PATH in profile
PROFILE="$HOME/.bash_profile"
if [[ -w "$PROFILE" ]] && ! grep -q "RMX3760-tools" "$PROFILE" 2>/dev/null; then
    echo "" >> "$PROFILE"
    echo "# RMX3760 Tools" >> "$PROFILE"
    echo 'export PATH="$HOME/RMX3760-tools:$PATH"' >> "$PROFILE"
    echo '[OK] PATH added to .bash_profile'
fi

echo ""
echo "=== Setup selesai ==="
echo "Jalankan: bash ~/RMX3760-tools/main.sh"
