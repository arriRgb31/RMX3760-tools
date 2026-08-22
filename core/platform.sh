#!/data/data/com.termux/files/usr/bin/bash
# Platform Detection — Cross-platform (Termux/Linux/macOS/Windows)
# by@arriRgb31

# Detect OS
detect_platform() {
    case "$(uname -s)" in
        Linux*)
            if grep -qi "microsoft\|proot\|termux" /proc/version 2>/dev/null; then
                if [[ -d "/data/data/com.termux" ]]; then
                    PLATFORM="termux"
                elif grep -qi "proot" /proc/version 2>/dev/null; then
                    PLATFORM="proot"
                else
                    PLATFORM="linux"
                fi
            else
                PLATFORM="linux"
            fi
            ;;
        Darwin*)  PLATFORM="macos" ;;
        CYGWIN*|MINGW*|MSYS*)  PLATFORM="windows" ;;
        *)  PLATFORM="unknown" ;;
    esac

    # Detect architecture
    ARCH=$(uname -m 2>/dev/null || echo "unknown")
    case "$ARCH" in
        aarch64|arm64) ARCH="arm64" ;;
        x86_64|amd64)  ARCH="x64" ;;
        armv7*|armhf)  ARCH="arm" ;;
        i*86)          ARCH="x86" ;;
    esac
}

# Set paths based on platform
set_platform_paths() {
    case "$PLATFORM" in
        termux)
            TOOLS_DIR="$HOME/RMX3760-tools"
            ADB_PATH="/data/data/com.termux/files/usr/bin"
            ;;
        proot)
            TOOLS_DIR="$HOME/RMX3760-tools"
            ADB_PATH="/usr/bin"
            ;;
        linux)
            TOOLS_DIR="$HOME/RMX3760-tools"
            ADB_PATH="/usr/bin"
            ;;
        macos)
            TOOLS_DIR="$HOME/RMX3760-tools"
            ADB_PATH="/usr/local/bin"
            ;;
        windows)
            TOOLS_DIR="$HOME/RMX3760-tools"
            ADB_PATH="/mingw64/bin"
            # Try to find platform-tools
            if [[ -d "$HOME/platform-tools" ]]; then
                ADB_PATH="$HOME/platform-tools"
            fi
            ;;
    esac
    export TOOLS_DIR ADB_PATH
}

# Check if running as root
check_root() {
    if [[ "$PLATFORM" == "termux" ]]; then
        IS_ROOT=$(su -c "id -u" 2>/dev/null || echo "0")
    else
        IS_ROOT=$(id -u 2>/dev/null || echo "0")
    fi
    [[ "$IS_ROOT" == "0" ]]
}

# Get ADB command
get_adb() {
    if command -v adb &>/dev/null; then
        echo "adb"
    elif [[ -f "$TOOLS_DIR/platform-tools/adb" ]]; then
        echo "$TOOLS_DIR/platform-tools/adb"
    elif [[ -f "$ADB_PATH/adb" ]]; then
        echo "$ADB_PATH/adb"
    else
        echo ""
    fi
}

# Get fastboot command
get_fastboot() {
    if command -v fastboot &>/dev/null; then
        echo "fastboot"
    elif [[ -f "$TOOLS_DIR/platform-tools/fastboot" ]]; then
        echo "$TOOLS_DIR/platform-tools/fastboot"
    elif [[ -f "$ADB_PATH/fastboot" ]]; then
        echo "$ADB_PATH/fastboot"
    else
        echo ""
    fi
}

# Platform-specific restart command
restart_udev() {
    case "$PLATFORM" in
        termux|proot|linux)
            command -v udevadm &>/dev/null && udevadm control --reload-rules 2>/dev/null
            ;;
        macos)
            # macOS doesn't use udev
            ;;
        windows)
            # Windows uses drivers, not udev
            ;;
    esac
}
