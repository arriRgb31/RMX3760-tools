#!/data/data/com.termux/files/usr/bin/bash
# spreadtrum_flash — RMX3760 Wrapper
# by@arriRgb31
#
# Wrapper untuk TomKing spreadtrum_flash dengan RMX3760-specific logic
#
# Referensi:
#   https://github.com/TomKing062/spreadtrum_flash
#   https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STF_DIR="$SCRIPT_DIR/../bin/termux/spreadtrum_flash"
SPDUMP="$STF_DIR/spd_dump"

echo "=== spreadtrum_flash — RMX3760 ==="
echo ""
echo "Device: Realme C53 RMX3760"
echo "SoC: Unisoc UMS9230 (T612)"
echo ""

# Check spd_dump
if [[ ! -f "$SPDUMP" ]]; then
    echo "[ERROR] spd_dump tidak ditemukan!"
    echo ""
    echo "Build from source:"
    echo "  pkg install git clang"
    echo "  git clone https://github.com/TomKing062/spreadtrum_flash.git"
    echo "  cd spreadtrum_flash && make"
    echo ""
    echo "Atau jalankan:"
    echo "  bash ~/RMX3760-tools/setup/setup_termux.sh"
    exit 1
fi

echo "=== Commands ==="
echo ""
echo "  1) Flash partition"
echo "  2) Read partition"
echo "  3) Erase partition"
echo "  4) Reboot to FDL2"
echo "  5) Show device info"
echo ""
echo -n "Pilihan: "
read -r choice

case $choice in
    1)
        echo -n "Partition name (boot/vendor_boot/vbmeta): "
        read -r part
        echo -n "Image file path: "
        read -r img
        if [[ -f "$img" ]]; then
            "$SPDUMP" flash "$part" "$img" 2>/dev/null
        else
            echo "File tidak ditemukan: $img"
        fi
        ;;
    2)
        echo -n "Partition name: "
        read -r part
        echo -n "Output file path: "
        read -r out
        "$SPDUMP" read "$part" "$out" 2>/dev/null
        ;;
    3)
        echo -n "Partition name: "
        read -r part
        "$SPDUMP" erase "$part" 2>/dev/null
        ;;
    4)
        echo "Rebooting to FDL2..."
        adb reboot autodloader 2>/dev/null
        echo "Device akan masuk FDL2 mode"
        ;;
    5)
        "$SPDUMP" info 2>/dev/null
        ;;
esac
