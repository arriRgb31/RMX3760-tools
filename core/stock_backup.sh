#!/data/data/com.termux/files/usr/bin/bash
# Stock Backup — Auto dump/load stock state
# by@arriRgb31
#
# Mendukung:
#   - Rooted + Unlocked
#   - Rooted + Locked
#   - Non-rooted + Unlocked
#   - Non-rooted + Locked
#
# Referensi:
#   Bootchain: docs/Bootchain_Android15_Unlocked.md

STOCK_DIR="${STOCK_DIR:-$HOME/RMX3760-backup/stock}"
STOCK_DIR_PWD="/sdcard/RMX3760-backup/stock"

# ============================================
# DEVICE STATE DETECTION
# ============================================

detect_device_state() {
    local state_root=""
    local state_unlock=""

    # Root detection
    if command -v su &>/dev/null && su -c "id" 2>/dev/null | grep -q "uid=0"; then
        state_root="rooted"
    else
        state_root="non-rooted"
    fi

    # Unlock detection
    local lock_state=$(getprop ro.boot.flash.locked 2>/dev/null || echo "unknown")
    if [[ "$lock_state" == "0" ]]; then
        state_unlock="unlocked"
    elif [[ "$lock_state" == "1" ]]; then
        state_unlock="locked"
    else
        # Try alternative
        local dev_state=$(getprop ro.boot.vbmeta.device_state 2>/dev/null || echo "unknown")
        if [[ "$dev_state" == "unlocked" ]]; then
            state_unlock="unlocked"
        else
            state_unlock="locked"
        fi
    fi

    echo "${state_root}+${state_unlock}"
}

get_state_root() {
    detect_device_state | cut -d'+' -f1
}

get_state_unlock() {
    detect_device_state | cut -d'+' -f2
}

# ============================================
# STOCK DUMP — Save current state
# ============================================

stock_dump() {
    local device_state=$(detect_device_state)
    local root_state=$(get_state_root)
    local unlock_state=$(get_state_unlock)
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local dump_dir="$STOCK_DIR/stock_${timestamp}_${root_state}_${unlock_state}"

    HEADER "Stock Dump — Menyimpan state saat ini"
    echo -e "  Device state: ${WHITE}$root_state + $unlock_state${NC}"
    echo -e "  Dump dir: ${WHITE}$dump_dir${NC}"
    echo ""

    mkdir -p "$dump_dir"/{vbmeta,boot,fstab,bootconfig,selinux}

    # --- VBMeta ---
    echo -e "  [1/6] Dumping vbmeta..."
    if [[ -e "/dev/block/by-name/vbmeta" ]]; then
        if [[ "$root_state" == "rooted" ]]; then
            su -c "dd if=/dev/block/by-name/vbmeta of=$dump_dir/vbmeta/vbmeta.img bs=4096" 2>/dev/null
        else
            # ADB pull (non-root, limited access)
            adb pull /dev/block/by-name/vbmeta "$dump_dir/vbmeta/vbmeta.img" 2>/dev/null
        fi
    fi
    for part in vbmeta_system vbmeta_vendor; do
        if [[ -e "/dev/block/by-name/$part" ]]; then
            if [[ "$root_state" == "rooted" ]]; then
                su -c "dd if=/dev/block/by-name/$part of=$dump_dir/vbmeta/${part}.img bs=4096" 2>/dev/null
            fi
        fi
    done

    # --- Boot ---
    echo -e "  [2/6] Dumping boot..."
    local slot=$(getprop ro.boot.slot_suffix 2>/dev/null || echo "_b")
    for part in boot vendor_boot; do
        local block="/dev/block/by-name/${part}${slot}"
        if [[ -e "$block" ]]; then
            if [[ "$root_state" == "rooted" ]]; then
                su -c "dd if=$block of=$dump_dir/boot/${part}${slot}.img bs=4096" 2>/dev/null
            fi
        fi
    done

    # --- fstab ---
    echo -e "  [3/6] Dumping fstab..."
    local fstab_candidates=(
        "/vendor/etc/fstab.${BOARD:-ums9230}"
        "/vendor/etc/fstab"
        "/proc/boot/fstab"
    )
    for fstab in "${fstab_candidates[@]}"; do
        if [[ -e "$fstab" ]]; then
            if [[ "$root_state" == "rooted" ]]; then
                su -c "cp $fstab $dump_dir/fstab/fstab.txt" 2>/dev/null
            else
                adb shell cat "$fstab" > "$dump_dir/fstab/fstab.txt" 2>/dev/null
            fi
            break
        fi
    done

    # --- bootconfig ---
    echo -e "  [4/6] Dumping bootconfig..."
    if [[ "$root_state" == "rooted" ]]; then
        su -c "cat /proc/bootconfig" > "$dump_dir/bootconfig/bootconfig.txt" 2>/dev/null
        su -c "cat /proc/cmdline" > "$dump_dir/bootconfig/cmdline.txt" 2>/dev/null
    else
        adb shell cat /proc/cmdline > "$dump_dir/bootconfig/cmdline.txt" 2>/dev/null
    fi

    # --- SELinux ---
    echo -e "  [5/6] Dumping SELinux state..."
    if [[ "$root_state" == "rooted" ]]; then
        su -c "getenforce" > "$dump_dir/selinux/getenforce.txt" 2>/dev/null
        su -c "cat /sys/fs/selinux/enforce" > "$dump_dir/selinux/enforce_value.txt" 2>/dev/null
    else
        adb shell getenforce > "$dump_dir/selinux/getenforce.txt" 2>/dev/null
    fi

    # --- AVB flags ---
    echo -e "  [6/6] Dumping AVB flags..."
    if [[ "$root_state" == "rooted" ]]; then
        for part in vbmeta vbmeta_system vbmeta_vendor; do
            if [[ -e "/dev/block/by-name/$part" ]]; then
                local flags=$(read_vbmeta_flags "$part" 2>/dev/null || echo "unknown")
                echo "$flags" > "$dump_dir/vbmeta/flags_${part}.txt"
            fi
        done
    fi

    # --- Metadata ---
    cat > "$dump_dir/metadata.txt" <<EOF
timestamp=$timestamp
root=$root_state
unlock=$unlock_state
device=$(getprop ro.product.model 2>/dev/null)
android=$(getprop ro.build.version.release 2>/dev/null)
slot=$(getprop ro.boot.slot_suffix 2>/dev/null)
build=$(getprop ro.build.display.id 2>/dev/null)
vbmeta_flags=$(read_vbmeta_flags "vbmeta" 2>/dev/null || echo "unknown")
selinux=$(adb shell getenforce 2>/dev/null || echo "unknown")
EOF

    # --- Summary ---
    echo ""
    echo -e "  ${GREEN}Stock dump selesai!${NC}"
    echo -e "  Location: ${WHITE}$dump_dir${NC}"
    echo -e "  Files: $(find "$dump_dir" -type f | wc -l)"
    echo ""

    # Display summary
    echo -e "  ${CYAN}Current state:${NC}"
    echo -e "    Root:      ${WHITE}$root_state${NC}"
    echo -e "    Unlock:    ${WHITE}$unlock_state${NC}"
    echo -e "    AVB flags: ${WHITE}$(cat $dump_dir/vbmeta/flags_vbmeta.txt 2>/dev/null || echo 'unknown')${NC}"
    echo -e "    SELinux:   ${WHITE}$(cat $dump_dir/selinux/getenforce.txt 2>/dev/null || echo 'unknown')${NC}"
    echo -e "    Slot:      ${WHITE}$(getprop ro.boot.slot_suffix 2>/dev/null)${NC}"
}

# ============================================
# STOCK RESTORE — Load previous state
# ============================================

stock_restore() {
    HEADER "Stock Restore — Mengembalikan state"
    echo -e "  Available backups:"
    echo ""

    local backups=($(ls -dt "$STOCK_DIR"/stock_* 2>/dev/null))
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "  ${YELLOW}Tidak ada backup ditemukan${NC}"
        WAIT_KEY
        return 1
    fi

    local i=1
    for b in "${backups[@]}"; do
        local name=$(basename "$b")
        local meta="$b/metadata.txt"
        if [[ -f "$meta" ]]; then
            local ts=$(grep "timestamp=" "$meta" | cut -d= -f2)
            local root=$(grep "root=" "$meta" | cut -d= -f2)
            local unlock=$(grep "unlock=" "$meta" | cut -d= -f2)
            echo "  [$i] $ts ($root + $unlock)"
        else
            echo "  [$i] $name"
        fi
        ((i++))
    done

    echo ""
    echo -en "  Pilih backup [1-$((i-1))]: "
    read -r choice
    local selected="${backups[$((choice-1))]}"

    if [[ ! -d "$selected" ]]; then
        echo -e "  ${RED}Invalid pilihan${NC}"
        WAIT_KEY
        return 1
    fi

    local root_state=$(get_state_root)

    echo ""
    echo -e "  Restoring from: ${WHITE}$(basename $selected)${NC}"

    # Restore vbmeta
    if [[ -f "$selected/vbmeta/vbmeta.img" ]] && [[ "$root_state" == "rooted" ]]; then
        echo -e "  [1/3] Restoring vbmeta..."
        su -c "dd if=$selected/vbmeta/vbmeta.img of=/dev/block/by-name/vbmeta bs=4096" 2>/dev/null
    fi

    # Restore fstab
    if [[ -f "$selected/fstab/fstab.txt" ]] && [[ "$root_state" == "rooted" ]]; then
        echo -e "  [2/3] Restoring fstab..."
        local fstab_target="/vendor/etc/fstab.${getprop ro.board.platform 2>/dev/null}"
        [[ -f "$fstab_target" ]] && su -c "cp $selected/fstab/fstab.txt $fstab_target" 2>/dev/null
    fi

    # Restore SELinux
    if [[ -f "$selected/selinux/getenforce.txt" ]] && [[ "$root_state" == "rooted" ]]; then
        echo -e "  [3/3] Restoring SELinux..."
        local selinux_val=$(cat "$selected/selinux/getenforce.txt" 2>/dev/null | tr '[:upper:]' '[:lower:]')
        [[ "$selinux_val" == "enforcing" || "$selinux_val" == "permissive" ]] && \
            su -c "setenforce $([[ $selinux_val == enforcing ]] && echo 1 || echo 0)" 2>/dev/null
    fi

    echo ""
    echo -e "  ${GREEN}Stock restore selesai!${NC}"
    echo -e "  Reboot untuk efektif."
    WAIT_KEY
}

# ============================================
# LIST STOCK BACKUPS
# ============================================

stock_list() {
    HEADER "Stock Backups"
    echo ""

    local backups=($(ls -dt "$STOCK_DIR"/stock_* 2>/dev/null))
    if [[ ${#backups[@]} -eq 0 ]]; then
        echo -e "  ${YELLOW}Tidak ada backup${NC}"
        WAIT_KEY
        return
    fi

    echo -e "  ${CYAN}#  | Timestamp           | State${NC}"
    echo "  ---|---------------------|------"

    local i=1
    for b in "${backups[@]}"; do
        local meta="$b/metadata.txt"
        if [[ -f "$meta" ]]; then
            local ts=$(grep "timestamp=" "$meta" | cut -d= -f2)
            local root=$(grep "root=" "$meta" | cut -d= -f2)
            local unlock=$(grep "unlock=" "$meta" | cut -d= -f2)
            local device=$(grep "device=" "$meta" | cut -d= -f2)
            local files=$(find "$b" -type f | wc -l)
            echo -e "  $i  | $ts | $root+$unlock | $files files"
        else
            echo -e "  $i  | $(basename $b) | ?"
        fi
        ((i++))
    done

    WAIT_KEY
}

# ============================================
# MENU
# ============================================

menu_stock() {
    while true; do
        BANNER
        echo -e "${MAGENTA}=== Stock Backup Manager ===${NC}"
        echo -e "  ${GRAY}Auto dump/load state sebelum patch${NC}"
        echo ""
        echo "  1) Dump Stock (simpan state saat ini)"
        echo "  2) Restore Stock (kembalikan state)"
        echo "  3) List Backups"
        echo "  4) Device State"
        echo "  5) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) stock_dump ;;
            2) stock_restore ;;
            3) stock_list ;;
            4) HEADER "Device State" && detect_device_state && WAIT_KEY ;;
            5) return ;;
        esac
    done
}
