# Unisoc SPD USB Driver — Setup Instructions
# for RMX3760 Tools
#
# Download dan install driver untuk Windows

## Download

### Official (Spreadtrum/UNISOC)
- https://spreadtrumdriver.com/
- Latest: SPD_Driver_R4.24.2705

### Alternative mirrors
- https://mirrors.lolinet.com/software/windows/Unisoc/drivers/

## Install (Windows)

1. Download `SPD_Driver_R4.24.2705.zip`
2. Extract
3. Run `DPInst64.exe` (64-bit) atau `DPInst32.exe` (32-bit)
4. Restart PC jika perlu

## Device IDs

```
USB\VID_1782&PID_0002  — FDL2 (download mode)
USB\VID_1782&PID_0003  — Normal (ADB)
USB\VID_1782&PID_0006  — Fastboot
```

## Linux udev rules

```bash
# /etc/udev/rules.d/51-android.rules
SUBSYSTEM=="usb", ATTR{idVendor}=="1782", MODE="0666", GROUP="plugdev"
```

## Termux adb_usb.ini

```
# ~/.android/adb_usb.ini
0x1782
```
