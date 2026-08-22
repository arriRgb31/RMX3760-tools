#!/data/data/com.termux/files/usr/bin/bash
# Core colors and UI utilities for RMX3760 Tools
# by@arriRgb31

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
MAGENTA='\033[1;35m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'

BANNER() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}  RMX3760 Tools — Realme C53 Android 15          ${CYAN}║${NC}"
    echo -e "${CYAN}║${GRAY}  SoC: Unisoc UMS9230 (T612)                     ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
}

INFO()    { echo -e "${BLUE}[INFO]${NC} $1"; }
OK()      { echo -e "${GREEN}[OK]${NC} $1"; }
WARN()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
FAIL()    { echo -e "${RED}[FAIL]${NC} $1"; }
HEADER()  { echo -e "\n${MAGENTA}═══ $1 ═══${NC}"; }

CONFIRM() {
    echo -en "${YELLOW}$1 [y/N]: ${NC}"
    read -r ans
    [[ "$ans" =~ ^[yY]$ ]]
}

WAIT_KEY() {
    echo -en "\n${GRAY}Tekan Enter untuk melanjutkan...${NC}"
    read -r
}

PRESS_ANY() {
    echo -en "\n${GRAY}Tekan tombol apapun untuk kembali...${NC}"
    read -sn1
}
