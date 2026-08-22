# RMX3760 Tools

Tool suite untuk **Realme C53 (RMX3760)** — Unisoc UMS9230 T612 — Android 15

Platform: Termux (root/proot), Linux, macOS

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
| Reboot | Recovery, bootloader, FDL2 | [Bootchain](#reboot--bootchain) |
| ADB/Fastboot | AOSP platform tools + Unisoc drivers | [AOSP](https://developer.android.com/tools/releases/platform-tools) |

## Quick Start

### Termux (Android)
```bash
git clone https://github.com/arriRgb31/RMX3760-tools.git
cd RMX3760-tools
bash setup/setup_termux.sh
bash main.sh
```

### proot Ubuntu (Termux)
```bash
git clone https://github.com/arriRgb31/RMX3760-tools.git
cd RMX3760-tools
bash main.sh
```

## Reboot — Bootchain

Boot chain Unisoc UMS9230 (dari [Bootchain_Android15_Unlocked.md](~/Bootchain_Android15_Unlocked.md)):

```
Boot ROM → SPL → SML → LK (Little Kernel) → kernel → Android
```

### Reboot Modes

| Mode | Command | Bootchain Entry | Keterangan |
|------|---------|----------------|------------|
| System | `su -c "reboot"` | Normal boot: SPL→SML→LK→kernel→system | Default boot ke Android |
| Recovery | `su -c "reboot recovery"` | SPL→SML→LK→kernel→recovery ramdisk | TWRP/recovery mode |
| Bootloader | `su -c "reboot bootloader"` | SPL→SML→LK (fastboot mode) | Unisoc LK fastboot, flash via `fastboot flash` |
| Fastboot | sama dengan bootloader | — | Pada Unisoc, fastboot = LK bootloader mode |
| Power Off | `su -c "reboot -p"` | Shutdown langsung | Matikan device |
| **FDL2** | `su -c "reboot autodloader"` | SPL→FDL1→**exploit**→FDL2→download mode | **CVE-2022-38694 exploit entry** |

### FDL2 (Download Mode)

FDL2 adalah mode download Unisoc untuk flash unsigned images via CVE-2022-38694.

```
Normal:    Boot ROM → SPL → SML → LK → kernel
FDL2:      Boot ROM → SPL → [CVE exploit: buffer overflow] → FDL2 → download mode
```

- **Command:** `su -c "reboot autodloader"` (dari Android live)
- **Alternatif:** Power off → tahan Volume Down → sambung USB
- **Perlu:** CVE tool di PC ([TomKing](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader))
- **USB mode:** VID `0x1782`, PID `0x0002` (FDL2)

### Auto FDL2

Masuk FDL2 dari semua state tanpa power off:
- **Android live:** langsung `reboot autodloader`
- **Recovery/fastboot/bootloader:** langsung `reboot autodloader`
- **Device tidak terdeteksi:** power off dulu, lalu Volume Down + USB

## Device Info

- **Model:** Realme C53 RMX3760
- **SoC:** Unisoc UMS9230 (T612)
- **Android:** 15
- **Boot header:** v4, virtual A/B
- **Slot:** A/B (dynamic — detect saat runtime via `getprop ro.boot.slot_suffix`)
- **Unisoc VID:** 0x1782

## Structure

```
RMX3760-tools/
├── main.sh              # Main launcher
├── core/
│   ├── colors.sh        # UI colors
│   ├── platform.sh      # Platform detection
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
└── setup/               # Setup scripts
```

## License

MIT

## Author

by@arriRgb31
