#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  RMX3760 Tools — Unlock/Relock Bootloader via CVE-2022-38694
#  Device : Realme C53 RMX3760 (Unisoc UMS9230, Android 15)
#  by@arriRgb31
#
#  References:
#   - CVE-2022-38694 : https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader
#   - Gopartner      : https://github.com/Gopartner/realme-c53-unlock-root
#   - Bootchain      : Bootchain_Android15_Unlocked.md
# ============================================================

TOOLS_DIR="$HOME/RMX3760-tools"
CACHE_DIR="$TOOLS_DIR/cache/cve-2022-38694"
CVE_URL="https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader/releases/download/1.72/ums9230_Realme_C53_RMX3760_RMX3762.zip"
ZIP_NAME="ums9230_Realme_C53_RMX3760_RMX3762.zip"

[[ -f "$HOME/RMX3760-tools/core/colors.sh" ]] || { echo "[FAIL] core/colors.sh tidak ditemukan"; exit 1; }
[[ -f "$HOME/RMX3760-tools/core/device.sh"  ]] || { echo "[FAIL] core/device.sh tidak ditemukan"; exit 1; }
source "$HOME/RMX3760-tools/core/colors.sh"
source "$HOME/RMX3760-tools/core/device.sh"

# Ambil nilai key dari isi /proc/bootconfig (format: key = "value")
_bc_get() {
    local key="$1" content="$2"
    printf '%s\n' "$content" \
        | grep -E "(^|[[:space:]])${key}[[:space:]]*=" \
        | head -n1 \
        | sed -E 's/.*=[[:space:]]*"(.*)".*/\1/'
}

# Baca seluruh /proc/bootconfig (fallback via su bila tidak readable)
_read_bootconfig() {
    local bc=""
    [[ -r /proc/bootconfig ]] && bc="$(cat /proc/bootconfig 2>/dev/null)"
    [[ -z "$bc" ]] && bc="$(su -c 'cat /proc/bootconfig' 2>/dev/null)"
    printf '%s' "$bc"
}

show_status() {
    HEADER "Status Bootloader (getprop)"
    detect_device

    local prop_locked="$(getprop ro.boot.flash.locked 2>/dev/null)"
    local prop_vbmeta="$(getprop ro.boot.vbmeta.device_state 2>/dev/null)"
    local prop_verified="$(getprop ro.boot.verifiedbootstate 2>/dev/null)"
    local oem_allowed="$(getprop sys.oem_unlock_allowed 2>/dev/null)"

    echo -e "  ro.boot.flash.locked          : ${WHITE}${prop_locked:-?}$( [[ "$prop_locked" == "0" ]] && echo "  (UNLOCKED)" || echo "  (LOCKED)" )${NC}"
    echo -e "  ro.boot.vbmeta.device_state   : ${WHITE}${prop_vbmeta:-?}${NC}"
    echo -e "  ro.boot.verifiedbootstate     : ${WHITE}${prop_verified:-?}$( [[ "$prop_verified" == "orange" ]] && echo "  (UNLOCKED)" )${NC}"
    echo -e "  sys.oem_unlock_allowed        : ${WHITE}${oem_allowed:-?}${NC}"

    HEADER "Status Bootloader (Kernel /proc/bootconfig)"
    local bc="$(_read_bootconfig)"
    if [[ -z "$bc" ]]; then
        FAIL "/proc/bootconfig tidak dapat dibaca (butuh root?)"
        return 1
    fi

    local k_devstate="$( _bc_get "androidboot.vbmeta.device_state" "$bc" )"
    local k_verified="$( _bc_get "androidboot.verifiedbootstate" "$bc" )"

    echo -e "  androidboot.vbmeta.device_state : ${WHITE}${k_devstate:-tidak ditemukan}${NC}"
    echo -e "  androidboot.verifiedbootstate   : ${WHITE}${k_verified:-tidak ditemukan}${NC}"

    INFO "Level kernel (nilai asli dari bootloader):"
    if [[ "$k_devstate" == "unlocked" && "$k_verified" == "orange" ]]; then
        OK "BOOTLOADER: UNLOCKED (kernel level)"
    elif [[ "$k_devstate" == "locked" && "$k_verified" == "green" ]]; then
        WARN "BOOTLOADER: LOCKED (kernel level)"
    else
        WARN "State campuran/tidak standar: device_state='$k_devstate', verifiedbootstate='$k_verified'"
    fi

    # Deteksi spoof getprop oleh Magisk (getprop bisa dipalsukan, kernel tidak)
    if [[ "$k_devstate" == "unlocked" && "$prop_locked" == "1" ]]; then
        WARN "getprop melaporkan LOCKED tapi kernel UNLOCKED -> kemungkinan getprop dispoof Magisk"
    fi
    if [[ "$k_devstate" == "locked" && "$prop_locked" == "0" ]]; then
        WARN "getprop melaporkan UNLOCKED tapi kernel LOCKED -> verifikasi gagal, status asli LOCKED"
    fi
    return 0
}

download_cve_tool() {
    HEADER "Download CVE Tool (CVE-2022-38694)"
    mkdir -p "$CACHE_DIR"

    local zipfile="$CACHE_DIR/$ZIP_NAME"
    if [[ -f "$zipfile" ]]; then
        OK "File sudah ada: $zipfile"
        CONFIRM "Unduh ulang (re-download)?" || return 0
        rm -f "$zipfile"
    fi

    INFO "Mengunduh dari GitHub release 1.72..."
    if command -v curl >/dev/null 2>&1; then
        curl -L --fail --progress-bar -o "$zipfile" "$CVE_URL"
    elif command -v wget >/dev/null 2>&1; then
        wget --show-progress -O "$zipfile" "$CVE_URL"
    else
        FAIL "curl/wget tidak ditemukan. Install: pkg install curl"
        return 1
    fi

    if [[ $? -ne 0 || ! -s "$zipfile" ]]; then
        FAIL "Download gagal. Cek koneksi internet."
        return 1
    fi
    OK "Download selesai: $zipfile ($(du -h "$zipfile" | cut -f1))"

    INFO "Ekstrak arsip..."
    if ! command -v unzip >/dev/null 2>&1; then
        FAIL "unzip tidak ditemukan. Install: pkg install unzip"
        return 1
    fi
    if unzip -o "$zipfile" -d "$CACHE_DIR"; then
        OK "Ekstrak selesai ke $CACHE_DIR"
        INFO "Isi direktori:"
        ls -la "$CACHE_DIR"
    else
        FAIL "Ekstrak gagal (arsip korup?)"
        return 1
    fi
    return 0
}

enter_download_mode() {
    HEADER "Masuk Mode Download (Autodloader)"
    INFO "Mode autodloader dibutuhkan agar eksploit CVE-2022-38694 bisa berkomunikasi dengan FDL."
    WARN "Perangkat akan REBOOT SEKARANG JUGA!"
    CONFIRM "Lanjutkan masuk mode download?" || { WARN "Dibatalkan."; return 1; }

    if is_root; then
        INFO "Reboot ke autodloader via su..."
        sleep 1
        su -c "reboot autodloader"
    elif command -v fastboot >/dev/null 2>&1 && fastboot devices 2>/dev/null | grep -q .; then
        INFO "Reboot ke autodloader via fastboot..."
        fastboot reboot autodloader
    else
        FAIL "Butuh akses root (su) ATAU perangkat dalam mode fastboot."
        INFO "Alternatif manual: matikan perangkat, tahan Vol- sambil colok kabel USB."
        return 1
    fi
    return 0
}

unlock_bootloader() {
    HEADER "Unlock Bootloader — CVE-2022-38694"
    require_root || return 1
    detect_device
    print_device_info

    echo ""
    WARN "+====================================================+"
    WARN "|              PERINGATAN PENTING                    |"
    WARN "+----------------------------------------------------+"
    WARN "| - Semua data user akan TERHAPUS (factory reset)    |"
    WARN "| - Garansi hangus (warranty void)                   |"
    WARN "| - Risiko BRICK PERMANEN jika proses terganggu      |"
    WARN "| - Jangan biarkan baterai habis saat proses         |"
    WARN "+====================================================+"
    echo ""
    CONFIRM "Saya mengerti semua risikonya, LANJUTKAN?" || { WARN "Dibatalkan oleh pengguna."; return 1; }

    # --- Langkah 1: pastikan CVE tool tersedia ---
    local zipfile="$CACHE_DIR/$ZIP_NAME"
    if [[ ! -f "$CACHE_DIR/$ZIP_NAME" ]]; then
        INFO "CVE tool belum tersedia, mengunduh dulu..."
        download_cve_tool || { FAIL "Gagal menyiapkan CVE tool."; return 1; }
    else
        OK "CVE tool sudah tersedia: $zipfile"
        if [[ -z "$(ls -A "$CACHE_DIR" | grep -v '\.zip$')" ]]; then
            unzip -o "$zipfile" -d "$CACHE_DIR" || return 1
        fi
    fi

    # Tandai semua file eksekutabel/ELF di hasil ekstrak
    find "$CACHE_DIR" -type f ! -name "*.zip" | while read -r f; do
        [[ "$(head -c 4 "$f" 2>/dev/null)" == $'\x7fELF' ]] && chmod +x "$f"
    done

    # --- Langkah 2: masuk mode download (autodloader) ---
    INFO "Langkah berikutnya: perangkat akan reboot ke mode autodloader."
    INFO "Setelah itu script menunggu port download muncul lalu menjalankan eksploit."
    enter_download_mode || return 1

    # --- Langkah 3: tunggu port download siap ---
    INFO "Menunggu port download (maks 60 detik)..."
    local ready=false
    local i
    for i in $(seq 60 -1 1); do
        if ls /dev/ttyUSB* >/dev/null 2>&1; then
            ready=true
            OK "Port download terdeteksi!"
            break
        fi
        printf "\r  ${GRAY}[%3ds] menunggu /dev/ttyUSB... ${NC}" "$i"
        sleep 1
    done
    echo ""

    # --- Langkah 4: jalankan eksploit ---
    if [[ "$ready" != true ]]; then
        WARN "Port download tidak terdeteksi dari sisi perangkat ini."
        INFO "Jika perangkat sudah di mode autodloader, jalankan eksploit dari PC/Linux:"
        echo -e "  ${WHITE}cd $CACHE_DIR && sudo ./<binary-eksploit>${NC}"
        INFO "Setelah eksploit sukses, reboot perangkat lalu gunakan menu 5 (Verifikasi)."
        return 1
    fi

    local exploit_bin="$(find "$CACHE_DIR" -type f -perm -u+x ! -name "*.zip" ! -name "*.sh" | head -n1)"
    if [[ -z "$exploit_bin" ]]; then
        FAIL "Binary eksploit tidak ditemukan di $CACHE_DIR"
        INFO "Jalankan manual sesuai README di dalam arsip."
        return 1
    fi

    INFO "Menjalankan eksploit: $exploit_bin"
    if timeout 180 su -c "'$exploit_bin'" 2>&1; then
        OK "Eksploit selesai dijalankan."
        INFO "Reboot perangkat (tahan tombol power ~10 detik), lalu pilih menu 5 (Verifikasi)."
    else
        FAIL "Eksploit gagal/time-out. Periksa log di atas."
        return 1
    fi
    return 0
}

verify_unlock() {
    HEADER "Verifikasi Unlock (post-reboot)"
    INFO "Memastikan perangkat sudah selesai booting..."
    local i
    for i in $(seq 1 15); do
        [[ "$(getprop sys.boot_completed 2>/dev/null)" == "1" ]] && break
        sleep 2
    done

    local bc="$(_read_bootconfig)"
    if [[ -z "$bc" ]]; then
        FAIL "/proc/bootconfig tidak dapat dibaca (butuh root?)"
        return 1
    fi

    local k_devstate="$( _bc_get "androidboot.vbmeta.device_state" "$bc" )"
    local k_verified="$( _bc_get "androidboot.verifiedbootstate" "$bc" )"

    INFO "Kernel level (/proc/bootconfig):"
    echo -e "  androidboot.vbmeta.device_state : ${WHITE}${k_devstate:-tidak ditemukan}${NC}"
    echo -e "  androidboot.verifiedbootstate   : ${WHITE}${k_verified:-tidak ditemukan}${NC}"

    local errors=0
    if [[ "$k_devstate" == "unlocked" ]]; then
        OK "vbmeta.device_state = unlocked"
    else
        FAIL "vbmeta.device_state = '$k_devstate' (expected: unlocked)"
        ((errors++))
    fi
    if [[ "$k_verified" == "orange" ]]; then
        OK "verifiedbootstate = orange"
    else
        FAIL "verifiedbootstate = '$k_verified' (expected: orange)"
        ((errors++))
    fi

    echo ""
    if [[ $errors -eq 0 ]]; then
        OK "VERIFIKASI BERHASIL: Bootloader RMX3760 dalam kondisi UNLOCKED."
        INFO "Lanjutkan ke flash TWRP/root (lihat modul lain di RMX3760-tools)."
    else
        FAIL "VERIFIKASI GAGAL: bootloader masih terkunci atau state tidak sesuai."
        INFO "Ulangi langkah Unlock (menu 4) dan pastikan mode autodloader benar."
    fi
    return $errors
}

menu_unlock() {
    while true; do
        BANNER
        HEADER "Unlock Bootloader — CVE-2022-38694 (RMX3760)"
        echo -e "  ${WHITE}1)${NC} Status Bootloader"
        echo -e "  ${WHITE}2)${NC} Download CVE Tool"
        echo -e "  ${WHITE}3)${NC} Masuk Mode Download (Autodloader)"
        echo -e "  ${WHITE}4)${NC} Unlock Bootloader (eksploit)"
        echo -e "  ${WHITE}5)${NC} Verifikasi Unlock"
        echo -e "  ${WHITE}6)${NC} Kembali"
        echo -en "${CYAN}Pilih [1-6]: ${NC}"
        read -r pilihan
        case "$pilihan" in
            1) show_status; PRESS_ANY ;;
            2) download_cve_tool; PRESS_ANY ;;
            3) enter_download_mode ;;
            4) unlock_bootloader; PRESS_ANY ;;
            5) verify_unlock; PRESS_ANY ;;
            6) INFO "Kembali ke menu utama..."; break ;;
            *) FAIL "Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

# ===== Main =====
detect_device
if [[ -n "$DEVICE_MODEL" && "$DEVICE_MODEL" != "RMX3760" ]]; then
    BANNER
    FAIL "Perangkat terdeteksi: $DEVICE_MODEL (script ini khusus RMX3760)"
    CONFIRM "Tetap lanjutkan?" || exit 1
fi
menu_unlock
