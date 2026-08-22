#!/data/data/com.termux/files/usr/bin/bash
# Magisk — RMX3760 Wrapper
# by@arriRgb31
#
# Wrapper untuk Magisk dengan RMX3760-specific logic
#
# Referensi:
#   https://topjohnwu.github.io/Magisk/
#   https://github.com/topjohnwu/Magisk

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAGISK_DIR="$SCRIPT_DIR/../bin/termux/magisk"
MAGISKBOOT="$MAGISK_DIR/magiskboot"

# Check magiskboot
if [[ ! -f "$MAGISKBOOT" ]]; then
    echo "[ERROR] magiskboot tidak ditemukan!"
    echo "Location: $MAGISKBOOT"
    exit 1
fi

echo "=== Magisk — RMX3760 ==="
echo ""
echo "Device: Realme C53 RMX3760"
echo "SoC: Unisoc UMS9230 (T612)"
echo "Target: boot.img (bukan vendor_boot.img!)"
echo ""

# Get current slot
SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null || echo "_b")
echo "Current slot: $SLOT"
echo ""

echo "=== Magisk Tools ==="
echo ""
echo "  1) Patch boot image (dari device)"
echo "  2) Patch boot image (dari file)"
echo "  3) Unpack boot image"
echo "  4) Repack boot image"
echo "  5) Info boot image"
echo ""
echo -n "Pilihan: "
read -r choice

case $choice in
    1)
        # Patch from device
        BOOT_BLOCK="/dev/block/by-name/boot${SLOT}"
        echo ""
        echo "Dumping boot${SLOT}..."
        su -c "dd if=$BOOT_BLOCK of=/sdcard/boot.img bs=4096" 2>/dev/null
        echo "Patching..."
        "$MAGISKBOOT" patch /sdcard/boot.img /sdcard/magisk_patched.img 2>/dev/null
        echo "Patched: /sdcard/magisk_patched.img"
        echo ""
        echo "Flash:"
        echo "  fastboot flash boot${SLOT} /sdcard/magisk_patched.img"
        ;;
    2)
        # Patch from file
        echo -n "Boot image path: "
        read -r img
        if [[ -f "$img" ]]; then
            "$MAGISKBOOT" patch "$img" /sdcard/magisk_patched.img 2>/dev/null
            echo "Patched: /sdcard/magisk_patched.img"
        else
            echo "File tidak ditemukan: $img"
        fi
        ;;
    3)
        echo -n "Boot image path: "
        read -r img
        if [[ -f "$img" ]]; then
            "$MAGISKBOOT" unpack "$img" 2>/dev/null
            echo "Unpacked: kernel, ramdisk, etc."
        fi
        ;;
    4)
        echo "Repacking..."
        "$MAGISKBOOT" repack /sdcard/boot.img /sdcard/magisk_patched.img 2>/dev/null
        echo "Repacked: /sdcard/magisk_patched.img"
        ;;
    5)
        echo -n "Boot image path: "
        read -r img
        if [[ -f "$img" ]]; then
            "$MAGISKBOOT" info "$img" 2>/dev/null
        fi
        ;;
esac
