#!/data/data/com.termux/files/usr/bin/bash
# CVE-2022-38694 — RMX3760 Wrapper
# by@arriRgb31
#
# Wrapper untuk CVE exploit dengan RMX3760-specific logic
#
# Referensi:
#   https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader
#   https://github.com/Gopartner/realme-c53-unlock-root

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CVE_DIR="$SCRIPT_DIR/../modified/cve-2022-38694"
SPDUMP="$CVE_DIR/spd_dump.exe"

# Check if running in Termux
if [[ -d "/data/data/com.termux" ]]; then
    # Termux: use spd_dump from Termux packages or build
    SPDUMP=$(command -v spd_dump 2>/dev/null || echo "$HOME/RMX3760-tools/tools/bin/termux/spreadtrum_flash/spd_dump")
fi

echo "=== CVE-2022-38694 — RMX3760 ==="
echo ""

# Check spd_dump
if [[ ! -f "$SPDUMP" ]] && ! command -v spd_dump &>/dev/null; then
    echo "[ERROR] spd_dump tidak ditemukan!"
    echo ""
    echo "Install:"
    echo "  Termux: pkg install spreadtrum_flash"
    echo "  atau:   bash ~/RMX3760-tools/setup/setup_termux.sh"
    echo ""
    echo "Windows:"
    echo "  spd_dump.exe ada di: $CVE_DIR/"
    exit 1
fi

echo "Device: Realme C53 RMX3760"
echo "SoC: Unisoc UMS9230 (T612)"
echo ""

# Check device connection
echo "Checking device..."
if command -v adb &>/dev/null; then
    adb devices | grep -q "device$" && echo "[OK] Device connected via ADB" || echo "[WARN] Device tidak terdeteksi"
else
    echo "[WARN] ADB tidak tersedia"
fi

echo ""
echo "=== FDL2 Mode ==="
echo ""
echo "FDL2 = Unisoc download mode"
echo "Boot chain: Boot ROM → SPL → [exploit] → FDL2 → download mode"
echo ""
echo "Commands:"
echo "  adb reboot autodloader    — Masuk FDL2 dari Android"
echo "  Power Off + Volume Down   — Manual FDL2"
echo ""

# Check if in FDL2
if command -v adb &>/dev/null; then
    local pid=$(adb shell cat /sys/class/android_usb/android0/idProduct 2>/dev/null)
    if [[ "$pid" == "0x0002" ]]; then
        echo "[OK] Device dalam FDL2 mode (PID: $pid)"
    fi
fi

echo ""
echo "=== CVE Exploit Files ==="
echo ""
ls -la "$CVE_DIR"/*.exe "$CVE_DIR"/*.bin 2>/dev/null | awk '{print "  " $NF " (" $5 " bytes)"}'
echo ""
echo "Usage:"
echo "  1. Masuk FDL2: adb reboot autodloader"
echo "  2. Jalankan: spd_dump atau unlock_autopatch_9230.bat"
echo "  3. Tunggu proses selesai"
echo "  4. Device akan reboot"
