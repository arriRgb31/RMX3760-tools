# RMX3760 Tools

Tool suite untuk **Realme C53 (RMX3760)** — Unisoc UMS9230 T612 — Android 15

Cross-platform: Termux (root/proot), Linux, macOS, Windows (Git Bash/WSL)

## Features

| Tool | Fungsi | Referensi |
|------|--------|-----------|
| Unlock/Relock | CVE-2022-38694 bootloader exploit | [TomKing](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader) |
| AVB Patch | Android Verified Boot bypass FLAGS 1/2/3 | [UnisocBypass](https://github.com/TheGammaSqueeze/UnisocBypass) |
| DM-Verity | dm-verity disable/enable | [UnisocBypass](https://github.com/TheGammaSqueeze/UnisocBypass) |
| SELinux | enforcing/permissive (3 metode) | Magisk / bootconfig |
| Root | Magisk / KernelSU / APatch | [Magisk](https://topjohnwu.github.io/Magisk/) / [KSU](https://kernelsu.org/) / [APatch](https://github.com/bmax121/APatch) |
| TWRP | Auto build/port (WIP) | [Hovatek](https://www.hovatek.com/blog/auto-twrp-porter-mtk-v1-6-unisoc-spd-v1-4/) |
| Logging | Logcat, dmesg, dumpsys, boot log | AOSP |
| Reboot | Recovery, bootloader, FDL2 | [Bootchain](~/Bootchain_Android15_Unlocked.md) |
| ADB/Fastboot | AOSP platform tools + Unisoc drivers | [AOSP](https://developer.android.com/tools/releases/platform-tools) |

## Quick Start

### Termux (Android)
```bash
git clone https://github.com/arriRgb31/RMX3760-tools.git
cd RMX3760-tools
bash setup/setup_termux.sh
bash main.sh
```

### Windows (Git Bash)
```bash
git clone https://github.com/arriRgb31/RMX3760-tools.git
cd RMX3760-tools
bash setup/setup_windows.sh
bash main.sh
```

### Windows (USB → Termux)
```
ssh user@100.115.99.116
bash ~/RMX3760-tools/main.sh
```

## Structure

```
RMX3760-tools/
├── main.sh              # Main launcher
├── core/
│   ├── colors.sh        # UI colors
│   ├── platform.sh      # Cross-platform detection
│   ├── device.sh        # Device detect
│   ├── flash.sh         # Flash helpers
│   └── adb_setup.sh     # ADB/Fastboot + drivers
├── unlock/unlock.sh     # CVE-2022-38694
├── avb/avb_patch.sh     # AVB FLAGS
├── dmverity/dmverity.sh # DM-Verity
├── selinux/selinux.sh   # SELinux
├── root/                # Magisk/KSU/APatch
├── twrp/auto_twrp.sh    # TWRP (WIP)
├── logging/logger.sh    # Runtime logs
├── reboot/reboot.sh     # Reboot + FDL2
├── help/help.sh         # Professional help
└── setup/               # Platform setup scripts
```

## Device Info

- **Model:** Realme C53 RMX3760
- **SoC:** Unisoc UMS9230 (T612)
- **Android:** 15
- **Boot header:** v4, virtual A/B
- **Slot:** A/B (slot_b active)
- **Unisoc VID:** 0x1782

## License

MIT

## Author

by@arriRgb31
