# Kompatibilitas — RMX3760 Tools

> Realme C53 / RMX3760 / Unisoc UMS9230 T612 / Android 15

## WARNING — PERINGATAN

```
╔══════════════════════════════════════════════════════════════╗
║                    ⚠ PERINGATAN                              ║
║                                                              ║
║  Menggunakan tools ini berarti Anda SIAP dengan risiko:      ║
║                                                              ║
║  • BRICK PERMANEN — device tidak bisa dinyalakan             ║
║  • BOOTLOOP — device stuck di logo / restart terus           ║
║  • DATA HILANG — semua data terhapus                         ║
║  • GARANSI HANGUS — garansi resmi tidak berlaku              ║
║  • KERUSAKAN HARDWARE — komponen bisa rusak                  ║
║                                                              ║
║  TIDAK ADA JAMINAN. Semua risiko ditanggung sendiri.         ║
║  Pastikan Anda tahu apa yang dilakukan SEBELUM memulai.      ║
╚══════════════════════════════════════════════════════════════╝
```

## Tabel Kompatibilitas

### Device UNLOCKED (bootloader sudah unlock)

| Tool | Fungsi | Status | Factory Reset |
|------|--------|--------|---------------|
| **ADB/Fastboot** | Flash, shell, reboot | ✅ Bekerja | Tidak |
| **AVB Patch L1** | Disable verity | ✅ Bekerja | Tidak |
| **AVB Patch L2** | Disable verification | ✅ Bekerja | Tidak |
| **AVB Patch L3** | Full bypass | ✅ Bekerja | Tidak |
| **DM-Verity disable** | Disable dm-verity | ✅ Bekerja | Tidak |
| **SELinux permissive** | 3 metode | ✅ Bekerja | Tidak |
| **Magisk root** | Patch boot | ✅ Bekerja | Tidak |
| **KernelSU root** | Patch boot | ✅ Bekerja | Tidak |
| **APatch root** | Patch boot | ✅ Bekerja | Tidak |
| **TWRP (vendor_boot)** | Recovery | ⚠️ WIP | Tidak |
| **CVE tool** | Tidak perlu | ❌ N/A | — |

**Unlock method:** `fastboot flashing unlock` atau CVE tool (opsional)

---

### Device LOCKED (bootloader belum unlock)

| Tool | Fungsi | Status | Factory Reset |
|------|--------|--------|---------------|
| **CVE-2022-38694** | Unlock bootloader | ✅ Bekerja | **Ya** |
| **CVE tool (FDL2)** | Bypass AVB | ✅ Bekerja | Tidak |
| **AVB Patch L1** | Via CVE tool | ✅ Bekerja | Tidak |
| **AVB Patch L2** | Via CVE tool | ✅ Bekerja | Tidak |
| **AVB Patch L3** | Via CVE tool | ✅ Bekerja | Tidak |
| **DM-Verity disable** | Via CVE tool | ✅ Bekerja | Tidak |
| **SELinux permissive** | Via Magisk (post-unlock) | ⚠️ Setelah unlock | Tidak |
| **Magisk root** | Via Magisk (post-unlock) | ⚠️ Setelah unlock | Tidak |
| **KernelSU root** | Via Magisk (post-unlock) | ⚠️ Setelah unlock | Tidak |
| **APatch root** | Via Magisk (post-unlock) | ⚠️ Setelah unlock | Tidak |
| **TWRP (vendor_boot)** | Recovery (post-unlock) | ⚠️ Setelah unlock | Tidak |
| **ADB/Fastboot** | Flash via fastboot | ⚠️ Setelah unlock | Tidak |

**Unlock method:** CVE-2022-38694 exploit (SPL boot ROM → FDL2 → flash unlock)

---

## Alur Unlock (Locked → Unlocked)

```
┌─────────────────────────────────────────────────────────────┐
│                    DEVICE LOCKED                             │
│                                                              │
│  Boot ROM → SPL (locked) → CVE exploit → FDL2 bypass       │
│                                                              │
│  FDL2 bypass:                                                │
│    1. Exploit SPL vulnerability                              │
│    2. Masuk FDL2 (download mode)                             │
│    3. Flash unlock token                                     │
│    4. Factory reset (otomatis)                               │
│    5. Device restart → UNLOCKED                              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    DEVICE UNLOCKED                           │
│                                                              │
│  Semua tools berfungsi penuh:                                │
│    - AVB patch tanpa factory reset                           │
│    - Root tanpa factory reset                                │
│    - Flash via fastboot                                      │
│    - TWRP recovery                                           │
└─────────────────────────────────────────────────────────────┘
```

## Alur Patch AVB (Unlocked)

```
Backup vbmeta → Patch flags → Verify → Reboot
     │                              │
     │                              ▼
     │                    Boot timeout (120s)
     │                              │
     ▼                              ▼
 Auto-restore jika gagal    Boot normal
```

## Alur Root (Unlocked)

```
Patch boot image (Magisk/KSU/APatch)
     │
     ├── Slot A: flash boot_a
     ├── Slot B: flash boot_b
     └── Both:   flash boot_a + boot_b
     │
     ▼
  Reboot → Root aktif
```

## Alur Root (Locked — via CVE)

```
1. Masuk FDL2 (CVE exploit)
2. Flash unsigned boot image
3. Reboot → Root aktif
   (factory reset jika unlock pertama kali)
```

## Tool yang Diunduh

| Tool | Source | Fungsi |
|------|--------|--------|
| **AOSP Platform Tools** | Google | adb, fastboot |
| **CVE-2022-38694** | TomKing | Unlock + FDL2 bypass |
| **spreadtrum_flash** | TomKing | Termux flashing (spd_dump) |
| **Magisk** | Topjohnwu | Root patching |
| **Unisoc USB Driver** | Spreadtrum | Windows USB driver |
| **termux-adb** | Termux | ADB non-root |

## Referensi

| Tool | Repository |
|------|------------|
| CVE-2022-38694 | [TomKing062/CVE-2022-38694_unlock_bootloader](https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader) |
| Gopartner | [Gopartner/realme-c53-unlock-root](https://github.com/Gopartner/realme-c53-unlock-root) |
| UnisocBypass | [TheGammaSqueeze/UnisocBypass](https://github.com/TheGammaSqueeze/UnisocBypass) |
| spreadtrum_flash | [TomKing062/spreadtrum_flash](https://github.com/TomKing062/spreadtrum_flash) |
| Magisk | [topjohnwu/Magisk](https://github.com/topjohnwu/Magisk) |
| KernelSU | [tiann/KernelSU](https://github.com/tiann/KernelSU) |
| APatch | [bmax121/APatch](https://github.com/bmax121/APatch) |
