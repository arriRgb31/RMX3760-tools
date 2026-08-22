#!/data/data/com.termux/files/usr/bin/bash
# Help System - RMX3760 Tools
# by@arriRgb31

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/colors.sh"

help_full() {
    HEADER "RMX3760 Tools - Full Help"
    echo -e "${CYAN}Realme C53 (RMX3760) — Unisoc UMS9230 T612 — Android 15${NC}"
    echo ""
    echo "  Tool suite untuk Realme C53 RMX3760 Android 15."
    echo "  Semua tools berjalan di Termux (Android), PC hanya sebagai"
    echo "  terminal akses via SSH."
    echo ""
    echo "  Referensi utama:"
    echo "    Bootchain: docs/Bootchain_Android15_Unlocked.md"
    echo "    Device tree: https://github.com/arriRgb31/RMX3760"
    echo ""
    echo "  Tools tersedia:"
    echo "    1. Unlock/Relock  - CVE-2022-38694 bootloader exploit"
    echo "    2. AVB Patch      - Android Verified Boot bypass"
    echo "    3. DM-Verity      - dm-verity disable/enable"
    echo "    4. SELinux        - enforcing/permissive toggle"
    echo "    5. Root           - Magisk / KernelSU / APatch"
    echo "    6. TWRP           - Auto build/port (WIP)"
    echo "    7. Logging        - Runtime logs capture"
    echo "    8. Reboot         - Reboot/FDL2/power tools"
    WAIT_KEY
}

help_unlock() {
    HEADER "Unlock/Relock Bootloader"
    echo "  CVE-2022-38694 memanfaatkan buffer overflow di SPL (Secondary"
    echo "  Program Loader) pada Unisoc UMS9230. Certificate type 0 melewati"
    echo "  validasi public key, memungkinkan boot unsigned images."
    echo ""
    echo "  Boot chain normal:"
    echo "    Boot ROM -> SPL -> SML (Secure Monitor) -> LK (Little Kernel) -> kernel"
    echo ""
    echo "  Dengan CVE:"
    echo "    Boot ROM -> SPL -> [exploit: buffer overflow] -> FDL2 -> download mode"
    echo "    -> flash unsigned images (vbmeta, boot, vendor_boot)"
    echo ""
    echo "  Metode masuk download mode:"
    echo "    - reboot autodloader (dari Android, butuh root)"
    echo "    - Volume Down + USB (dari power off)"
    echo ""
    echo "  Referensi:"
    echo "    https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader"
    echo "    https://github.com/Gopartner/realme-c53-unlock-root"
    echo "    Bootchain_Android15_Unlocked.md"
    WAIT_KEY
}

help_avb() {
    HEADER "AVB Patch/Unpatch"
    echo "  Android Verified Boot (AVB) menandatangani setiap image boot."
    echo "  Flags disimpan di vbmeta partition pada offset 0x3C (4 bytes)."
    echo ""
    echo "  Level 1 - Disable Verity:"
    echo "    Set bit 0 (0x01) di vbmeta saja"
    echo "    Efek: dm-verity dimatikan untuk system/vendor/product"
    echo ""
    echo "  Level 2 - Disable Verification:"
    echo "    Set bit 0 (0x01) di SEMUA vbmeta* (vbmeta, vbmeta_system, vbmeta_vendor)"
    echo "    Efek: AVB verification dimatikan total"
    echo ""
    echo "  Level 3 - Full Bypass:"
    echo "    Set bit 0 + bit 3 (0x09) di SEMUA vbmeta*"
    echo "    Efek: No AVB + no rollback protection"
    echo ""
    echo "  Penting:"
    echo "    - vbmeta signature TIDAK BOLEH dimodifikasi (RSA4096 di LK)"
    echo "    - Backup otomatis sebelum patch"
    echo "    - Restore otomatis jika verifikasi gagal"
    echo ""
    echo "  Referensi:"
    echo "    https://github.com/TheGammaSqueeze/UnisocBypass"
    echo "    Bootchain_Android15_Unlocked.md"
    WAIT_KEY
}

help_dmverity() {
    HEADER "DM-Verity Patch/Unpatch"
    echo "  dm-verity adalah mekanisme integritas block device di Android."
    echo "  Setiap blok data di-partition di-hash, hash disimpan di hashtree."
    echo "  Kernel memverifikasi integritas saat read."
    echo ""
    echo "  Pada Unisoc UMS9230, dm-verity terikat ke AVB:"
    echo "    - Disable vbmeta flags (bit 0) = dm-verity otomatis mati"
    echo "    - Fallback: tambah androidboot.veritymode=disabled ke bootconfig"
    echo ""
    echo "  Referensi:"
    echo "    https://github.com/TheGammaSqueeze/UnisocBypass"
    WAIT_KEY
}

help_selinux() {
    HEADER "SELinux Patch/Unpatch"
    echo "  SELinux (Security-Enhanced Linux) mengontrol akses di Android."
    echo ""
    echo "  Enforcing: Policy diaktifkan, pelanggaran diblokir"
    echo "  Permissive: Policy hanya log, tidak diblokir"
    echo ""
    echo "  Metode perubahan:"
    echo "    1) Temporary: setenforce 0/1 (hilang reboot)"
    echo "    2) Persistent: bootconfig androidboot.selinux=permissive"
    echo "    3) Magisk overlay: persist.sys.selinux=permissive"
    echo ""
    echo "  Note: Stock recovery RMX3760 sudah permissive"
    WAIT_KEY
}

help_root() {
    HEADER "Root Tools"
    echo "  Tiga metode root tersedia:"
    echo ""
    echo "  Magisk (topjohnwu):"
    echo "    - Paling mature, komunitas besar"
    echo "    - Patch boot.img -> flash"
    echo "    - Zygisk untuk module"
    echo "    - https://topjohnwu.github.io/Magisk/"
    echo ""
    echo "  KernelSU (tiann):"
    echo "    - Kernel-level root"
    echo "    - Lebih stealth"
    echo "    - https://kernelsu.org/"
    echo ""
    echo "  APatch (bmax121):"
    echo "    - Kernel + userspace patch"
    echo "    - https://github.com/bmax121/APatch"
    echo ""
    echo "  SEMUA metode:"
    echo "    - Backup boot.img sebelum patch"
    echo "    - Pilih SELinux mode (enforcing/permissive)"
    echo "    - Verifikasi root setelah install"
    echo "    - Restore dari backup saat uninstall"
    echo "    - Support: fastboot (unlocked) atau CVE (download mode)"
    WAIT_KEY
}

help_twrp() {
    HEADER "Auto TWRP Builder"
    echo "  Build TWRP recovery untuk RMX3760 Android 15."
    echo ""
    echo "  Status saat ini:"
    echo "    - Device tree build SUKSES (CI: arriRgb31/RMX3760)"
    echo "    - STUCK logo 'Powered by Android' (DRM issue)"
    echo "    - ADB shell masuk (bukan berarti recovery normal)"
    echo "    - TIDAK ada bootloop, tidak ada mismatch"
    echo "    - TWRP GUI belum muncul"
    echo ""
    echo "  Root cause:"
    echo "    - TWRP: atomic DRM (drmModeAtomicCommit)"
    echo "    - Unisoc UMS9230: legacy DRM (drmModeSetCrtc)"
    echo ""
    echo "  Next: refactor graphics_drm.cpp"
    echo "    Ref: rtyutechstudio/unisoc-twrp-sourcecode_patch"
    WAIT_KEY
}

help_logging() {
    HEADER "Runtime Logging"
    echo "  Captures berbagai jenis log:"
    echo ""
    echo "  Logcat: Android system log (tag, PID, priority)"
    echo "  dmesg: Kernel ring buffer (boot messages, drivers)"
    echo "  Recovery: /cache/recovery/last_log"
    echo "  Dumpsys: Service状态 (activity, power, display, dll)"
    echo "  Properties: Semua system/vendor properties"
    echo "  Boot log: dmesg + logcat + props + services"
    echo ""
    echo "  Semua log disimpan ke ~/RMX3760-tools/logs/"
    WAIT_KEY
}

help_reboot() {
    HEADER "Reboot & FDL2"
    echo "  Reboot modes:"
    echo "    Recovery: su -c 'reboot recovery'"
    echo "    Bootloader: su -c 'reboot bootloader' (LK fastboot)"
    echo "    Fastboot: sama dengan bootloader di Unisoc"
    echo "    System: su -c 'reboot'"
    echo "    Power off: su -c 'reboot -p'"
    echo ""
    echo "  FDL2 (Download Mode):"
    echo "    Command: su -c 'reboot autodloader'"
    echo "    BERBEDA dengan reboot bootloader!"
    echo "    Masuk SPL -> FDL2 download mode untuk CVE exploit"
    echo ""
    echo "  Auto FDL2 dari semua state:"
    echo "    Android live: reboot autodloader"
    echo "    Tidak terdeteksi: power off, Volume Down + USB"
    WAIT_KEY
}

menu_help() {
    while true; do
        BANNER
        echo -e "${MAGENTA}=== Help System ===${NC}"
        echo ""
        echo "  1) Full Overview"
        echo "  2) Unlock/Relock Bootloader"
        echo "  3) AVB Patch/Unpatch"
        echo "  4) DM-Verity"
        echo "  5) SELinux"
        echo "  6) Root (Magisk/KSU/APatch)"
        echo "  7) TWRP Builder"
        echo "  8) Runtime Logging"
        echo "  9) Reboot & FDL2"
        echo "  10) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) help_full ;; 2) help_unlock ;; 3) help_avb ;; 4) help_dmverity ;;
            5) help_selinux ;; 6) help_root ;; 7) help_twrp ;;
            8) help_logging ;; 9) help_reboot ;; 10) return ;;
        esac
    done
}

menu_help
