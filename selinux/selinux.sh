#!/data/data/com.termux/files/usr/bin/bash
# SELinux Patch/Unpatch — Realme C53 RMX3760 Android 15
# by@arriRgb31
#
# Referensi:
#   - Magisk SELinux: https://topjohnwu.github.io/Magisk/
#   - UnisocBypass: https://github.com/TheGammaSqueeze/UnisocBypass
#   - Bootchain: Bootchain_Android15_Unlocked.md
#
# Metode SELinux:
#   1. Temporary: setenforce 0/1 (hilang setelah reboot)
#   2. Persistent: bootconfig androidboot.selinux=permissive
#   3. Magisk module: persist overlay
#   4. Stock permissive: androidboot.selinux=permissive di bootconfig (sudah aktif di recovery)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../core/colors.sh"
source "$SCRIPT_DIR/../core/device.sh"

BACKUP_DIR="$HOME/RMX3760-tools/backups/selinux"

get_selinux_status() {
    HEADER "SELinux Status"

    local enforce=""
    if is_root; then
        enforce=$(su -c "getenforce" 2>/dev/null)
    else
        enforce="(need root)"
    fi

    local prop_selinux=$(getprop ro.boot.selinux 2>/dev/null)
    local prop_persist=$(getprop persist.sys.selinux 2>/dev/null)

    echo -e "  Current mode:       ${WHITE}$enforce${NC}"
    echo -e "  ro.boot.selinux:    ${WHITE}${prop_selinux:-not set}${NC}"
    echo -e "  persist.sys.selinux: ${WHITE}${prop_persist:-not set}${NC}"

    # Kernel cmdline
    if [[ -f /proc/cmdline ]]; then
        local ks=$(grep -o "androidboot.selinux=[^ ]*" /proc/cmdline 2>/dev/null)
        echo -e "  Kernel cmdline:     ${WHITE}${ks:-not set}${NC}"
    fi

    # Bootconfig
    if [[ -f /proc/bootconfig ]]; then
        local bcs=$(grep "androidboot.selinux" /proc/bootconfig 2>/dev/null)
        echo -e "  Bootconfig:         ${WHITE}${bcs:-not set}${NC}"
    fi

    WAIT_KEY
}

set_permissive() {
    HEADER "Set SELinux Permissive"

    echo -e "  Pilih metode:"
    echo "    1) Temporary (setenforce 0) — hilang setelah reboot"
    echo "    2) Persistent via bootconfig — bertahan setelah reboot"
    echo "    3) Magisk overlay — persist.sys.selinux=permissive"
    echo ""
    echo -en "  Metode [1-3]: "
    read -r method

    case $method in
        1)
            if is_root; then
                su -c "setenforce 0" 2>/dev/null
                local result=$(su -c "getenforce" 2>/dev/null)
                if [[ "$result" == "Permissive" ]]; then
                    OK "SELinux = Permissive (temporary)"
                else
                    FAIL "Gagal: $result"
                fi
            else
                FAIL "Root required"
            fi
            ;;
        2)
            INFO "Menambah androidboot.selinux=permissive ke bootconfig..."
            mkdir -p "$BACKUP_DIR"
            # Backup current bootconfig
            su -c "cp /proc/bootconfig $BACKUP_DIR/bootconfig_$(date +%Y%m%d_%H%M%S)" 2>/dev/null

            # Add to bootconfig override file
            local override="/data/local/bootconfig_override"
            if [[ -f "$override" ]]; then
                if ! grep -q "androidboot.selinux=permissive" "$override"; then
                    echo "androidboot.selinux=permissive" >> "$override"
                fi
            else
                echo "androidboot.selinux=permissive" > "$override"
            fi
            OK "Bootconfig override updated"
            OK "Reboot untuk efektif"
            ;;
        3)
            if is_root; then
                su -c "setprop persist.sys.selinux permissive" 2>/dev/null
                # Magisk overlay for persistence
                local magisk_overlay="/data/adb/modules/rmx3760_selinux"
                mkdir -p "$magisk_overlay/system/etc"
                cat > "$magisk_overlay/system/etc/prop.default" << 'EOF'
persist.sys.selinux=permissive
EOF
                touch "$magisk_overlay/auto_mount"
                OK "Magisk overlay dibuat di $magisk_overlay"
                OK "Reboot untuk efektif"
            else
                FAIL "Root required"
            fi
            ;;
        *)
            FAIL "Invalid method"
            ;;
    esac
    WAIT_KEY
}

set_enforcing() {
    HEADER "Set SELinux Enforcing"

    # Temporary
    if is_root; then
        su -c "setenforce 1" 2>/dev/null
    fi

    # Remove bootconfig override
    local override="/data/local/bootconfig_override"
    if [[ -f "$override" ]]; then
        sed -i '/androidboot.selinux=permissive/d' "$override" 2>/dev/null
        OK "Bootconfig override removed"
    fi

    # Remove Magisk overlay
    local magisk_overlay="/data/adb/modules/rmx3760_selinux"
    if [[ -d "$magisk_overlay" ]]; then
        rm -rf "$magisk_overlay"
        OK "Magisk overlay removed"
    fi

    # Remove prop
    if is_root; then
        su -c "setprop persist.sys.selinux enforcing" 2>/dev/null
    fi

    local result=""
    if is_root; then
        result=$(su -c "getenforce" 2>/dev/null)
    fi
    echo -e "  SELinux mode: ${WHITE}$result${NC}"
    OK "Enforcing selesai. Reboot untuk full effect."
    WAIT_KEY
}

verify_selinux() {
    HEADER "Verifikasi SELinux"
    local enforce=""
    if is_root; then
        enforce=$(su -c "getenforce" 2>/dev/null)
    fi
    local context=""
    if is_root; then
        context=$(su -c "ls -Z /data" 2>/dev/null | head -1)
    fi
    echo -e "  Mode:        ${WHITE}$enforce${NC}"
    echo -e "  Context:     ${WHITE}$context${NC}"
    WAIT_KEY
}

menu_selinux() {
    while true; do
        BANNER
        echo -e "${MAGENTA}═══ SELinux Patch/Unpatch ═══${NC}"
        echo ""
        echo "  1) Status SELinux"
        echo "  2) Set Permissive"
        echo "  3) Set Enforcing"
        echo "  4) Verifikasi"
        echo "  5) Kembali"
        echo ""
        echo -en "  Pilihan: "
        read -r choice
        case $choice in
            1) get_selinux_status ;;
            2) set_permissive ;;
            3) set_enforcing ;;
            4) verify_selinux ;;
            5) return ;;
        esac
    done
}

menu_selinux
