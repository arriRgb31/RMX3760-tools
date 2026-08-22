# BOOTCHAIN ANDROID 15 — UNISOC UMS9230
## Pemetaan Lengkap Ekosistem Boot: Power ON → Android Runtime → Recovery

> **Dokumentasi berbasis data LIVE dari perangkat Android root yang sedang berjalan.**
> Seluruh data diambil langsung dari runtime Android (shell root pada device), bukan dari
> filesystem PRoot/Ubuntu maupun file analisis sementara.

---

## IDENTITAS PERANGKAT (LIVE)

| Item | Nilai (sumber: `getprop`, `/proc`, `/sys`) |
|---|---|
| Model | **realme RMX3760** (Realme C53) |
| Device code | **RE58C2** |
| SoC | **Spreadtrum / Unisoc UMS9230H** (`ro.soc.manufacturer=Spreadtrum`, `ro.soc.model=UMS9230H`) |
| Platform board | `ums9230` / `ums9230_hulk` (`ro.board.platform`, `ro.hardware`) |
| Project name | `prj_name=22724` (`/proc/cmdline`) |
| OS | **Android 15** (`ro.build.version.release=15`, SDK 35) |
| Build | `AP3A.240905.015.A2` / incremental `40` / `T.R4T2.1777915050` |
| Security patch | `2026-05-01` |
| Fingerprint | `realme/RMX3760/RE58C2:15/AP3A.240905.015.A2/T.R4T2.1777915050:user/release-keys` |
| Kernel (live) | `Linux version 5.15.178-android13-8-g0c749b198e8d-ab40` — **GKI 5.15**, SMP PREEMPT, aarch64 (`/proc/version`) |
| Storage | eMMC (`sprdboot.flash=emmc`), `/dev/block/mmcblk0` ≈ 117 GB, DDR 6144 MB (`androidboot.ddrsize`) |
| Skema partisi | **A/B** (slot aktif: **B**, `androidboot.slot_suffix=_b`) |
| Bootloader | **UNLOCKED** — `/proc/bootconfig`: `androidboot.flash.locked="0"`, `androidboot.vbmeta.device_state="unlocked"`, `androidboot.verifiedbootstate="orange"` |
| Root solution | **Magisk** terdeteksi live: mount `magisk /system_ext/bin tmpfs` di `/proc/mounts` |
| Display | LCD `lcd_td4160_cw_old_mipi_hd`, 1600x720, 24bpp (`/proc/cmdline`) |

### Catatan penting status lock (data live yang menarik)
Terjadi **divergensi properti** pada perangkat ini:

* Sumber mentah kernel (`/proc/cmdline` + `/proc/bootconfig`) → `verifiedbootstate=orange`, `flash.locked=0`, `vbmeta.device_state=unlocked`.
* Runtime property service (`getprop`) → `ro.boot.verifiedbootstate=green`, `ro.boot.flash.locked=1`, `ro.boot.vbmeta.device_state=locked`.

Ini konsisten dengan kondisi nyata perangkat: **bootloader fisik UNLOCKED** (nilai kernel), namun properti runtime **di-spoof oleh tooling root (Magisk/resetprop)** agar tampak locked/green. `vbmeta.digest` tetap identik di kedua sumber (`0a51c901b950cdc9db02349dad0e0f0525d09e3d32a19a6f16d05e11afdd85c0`), membuktikan keduanya berasal dari boot session yang sama.

---

## STRUKTUR ROOT RUNTIME (LIVE `ls -la /`)

```
/
├── system        -> dm-14 (system_b + dm-verity, EROFS ro)   [system-as-root]
├── system_ext    -> dm-15 (system_ext_b + verity, EROFS ro)
├── product       -> dm-18 (product_b + verity, EROFS ro)
├── vendor        -> dm-16 (vendor_b + verity, EROFS ro)
├── odm           -> dm-17 (odm_b + verity, EROFS ro)
├── data          -> dm-56 (userdata, F2FS, terenkripsi)
├── metadata      -> mmcblk0p55 (F2FS, kunci enkripsi & OTA)
├── apex          -> tmpfs + loop/dm (APEX ter-mount individual)
├── dev           -> tmpfs (device nodes, ueventd)
├── proc          -> procfs (kernel)
└── sys           -> sysfs (kernel)
```

---

# 1. HARDWARE STARTUP

## Alur dasar

```
Power ON
  ↓
PMIC / Power sequencing (UMS9230 + PMIC chipid 2730 — live: androidboot.pmic.chipid="2730")
  ↓
SoC initialization (reset vector, clock, DDR init oleh internal ROM+SPL)
  ↓
Boot ROM (maskrom internal Unisoc)
  ↓
Storage initialization (eMMC controller, bus SDIO 201d0000.sdio)
  ↓
Boot source selection (eMMC boot0/boot1 → splloader)
```

## Fungsi Boot ROM Unisoc

* **Boot ROM** adalah kode permanen di dalam die UMS9230. Ia berjalan pertama kali setelah reset dide-assert.
* Tugasnya: inisialisasi minimum hardware (clock PLL awal, kontroller eMMC), memvalidasi dan memuat **SPL/splloader** dari media boot.
* Media boot dipilih sesuai konfigurasi strap/eFuse. Live: `androidboot.auto.efuse="UMS9230H"`, `androidboot.auto.chipid="UMS9230-AB"`, `crystal=6`, `rfboard.id=2` — parameter hardware yang dibaca turunan Boot ROM/LK dan diteruskan lewat cmdline.
* Pada perangkat ini SPL disimpan di **eMMC boot partition** (bukan user area): live mapping menunjukkan `spl_a -> /dev/block/mmcblk0boot0` dan `spl_b -> /dev/block/mmcblk0boot1`. Ini pola khas Unisoc: SPL tidak menempati partisi GPT di user area.
* Boot ROM juga menjadi pintu masuk **download mode** (Firmware Download/FDL over USB) ketika tidak ada loader valid — mekanisme flashing Unisoc (ResearchDownload/SPD Flash Tool).

## Perpindahan kontrol antar tahap

Setiap tahap memuat tahap berikutnya ke RAM (DDR sudah di-init oleh SPL pada platform Unisoc modern), memverifikasi tanda tangan bila secure boot aktif, lalu melompat ke entry point tahap berikutnya dengan meneruskan struktur data (parameter memori, boot mode, slot). Live evidence rantai ini ada di tabel partisi: `spl_*` → `sml_*` → `uboot_*` → `boot_*`.

---

# 2. UNISOC BOOTCHAIN

## Peta rantai boot (sesuai partisi live di device ini)

```
Boot ROM (maskrom UMS9230)
  ↓  memuat dari eMMC boot0/boot1
SPL / splloader            (spl_a/b → mmcblk0boot0/boot1)
  ↓
SML — Secure Monitor Loader (sml_a/b → mmcblk0p6/p7)
  ↓  + TrustOS TEE (trustos_a/b → mmcblk0p4/p5, teecfg_a/b)
U-Boot / LK                (uboot_a/b → mmcblk0p8/p9)
  ↓  AVB verification, slot decision, BCB check
Kernel + DTB               (boot_a/b → mmcblk0p36/p37, dtb_a/b → p42/p43)
  ↓
First Stage Init           (init_boot_a/b → p40/p41, generic ramdisk)
```

## Fungsi tiap komponen

**SPL (Second Program Loader / splloader)**
* Inisialisasi DRAM penuh, clock, dan memuat loader utama.
* Pada Unisoc, SPL juga menyiapkan lingkungan untuk SML/TEE.

**FDL (Firmware DownLoader)**
* Protokol/loader download Unisoc untuk flashing via USB (mode bootrom download).
* FDL1 dimuat Boot ROM (berjalan tanpa DDR penuh), FDL2 berjalan setelah DDR siap dan menerima image via protokol FDL.
* Pada boot normal perangkat ini FDL tidak dieksekusi; ia hanya jalur pemulihan/flashing. Live cmdline masih membawa jejak infrastruktur Unisoc: `sprdboot.usbmux=0x0`, `sysdump_magic=80001000`, `sysdump_re_flag=1` (mekanisme sysdump crash dump Unisoc).

**SML / TrustOS**
* `sml` = Secure Monitor Loader: menjembatani dunia normal (Android) dan secure world.
* `trustos` = TEE (live: layanan TEE **Trusty** terlihat di HAL: `gatekeeper@1.0-service.trusty`, `keymint@2.0-unisoc.service.trusty`).
* `teecfg` = konfigurasi TEE. `hypervsior_a/b` (demikianlah ejaan di tabel partisi live) = image hypervisor/pVMFW.

**LK / U-Boot (Little Kernel bootloader Unisoc)**
* Bootloader utama: membaca GPT di user area eMMC, memilih slot, melakukan verifikasi **AVB**, membaca **BCB** di partisi `misc`, menampilkan logo (`logo`, `fbootlogo`), lalu memuat kernel.
* Log uboot disimpan di partisi khusus `uboot_log` (mmcblk0p10, 16 MB) — bukti bahwa LK aktif menulis log saat setiap boot.

## Bagaimana bootloader membaca partisi

* LK menginisialisasi eMMC (live: `boot_devices = "soc/soc:ap-apb/201d0000.sdio"` — path device boot yang diteruskan ke init untuk first-stage mount), membaca **GPT** di user area, dan mengakses partisi via nama label (yang di Linux tampil sebagai symlink `/dev/block/by-name/*`).
* Untuk SPL, akses dilakukan ke **hw boot partition** eMMC (`mmcblk0boot0/boot1`), terpisah dari GPT user area.

## Bagaimana A/B slot bekerja (live di device ini)

* Slot aktif: **B** (`androidboot.slot_suffix="_b"`, `ro.boot.slot_suffix=_b`).
* Hampir semua partisi kritikal berpasangan `_a/_b`: boot, dtb, dtbo, init_boot, vendor_boot, uboot, sml, trustos, teecfg, pm_sys, hypervsior, seluruh vbmeta*, seluruh modem/DSP Unisoc (l_modem, l_gdsp, l_ldsp, l_agdsp, l_fixnv1/2, l_deltanv), plus rollback-slot `avbmeta_rs_a/b`, `common_rs1/rs2_a/b`.
* Non-A/B (shared): super, userdata, cache, metadata, misc, prodnv, persist, logo, my_preload, opporeserve, blackbox, sysdumpdb, ocdt, calinv, oplusreserve1/3/5.
* Daftar resmi partisi A/B per build (live): `ro.product.ab_ota_partitions = boot,dtbo,init_boot,l_agdsp,l_deltanv,l_fixnv1,l_fixnv2,l_gdsp,l_ldsp,l_modem,mmcblk0boot1,odm,pm_sys,product,sdc,sml,system,system_dlkm,system_ext,teecfg,trustos,uboot,vbmeta,vbmeta_odm,vbmeta_product,vbmeta_system,vbmeta_system_ext,vbmeta_vendor,vendor,vendor_boot,vendor_dlkm`
* Slot ditandai sukses/aktif via metadata slot (bagian akhir `misc`); OTA update menulis ke slot non-aktif lalu switch slot oleh bootloader setelah `boot-success` ditandai di userspace (Virtual A/B + snapshot CoW — lihat §3).

## Bagaimana kernel mendapatkan kontrol

1. LK memverifikasi `boot_b` (AVB, lihat §4), membaca header boot image v4 (live magic `ANDROID!`, header version 4).
2. Kernel + DTB (dari `boot_b` dan `dtb_b`) dimuat ke RAM; ramdisk generik dari `init_boot_b` dan vendor ramdisk dari `vendor_boot_b` (magic live `VNDRBOOT`) digabungkan.
3. LK menyiapkan **cmdline** (terukur live di `/proc/cmdline`: `init=/init root=/dev/ram0 rw ... sprdboot.slot_suffix=_b ... bootconfig`) dan **bootconfig** (`/proc/bootconfig`: `androidboot.*`).
4. Kontrol melompat ke kernel dengan MMU off/entry point ARM64; kernel meng-initsubsystem, me-mount ramdisk sebagai rootfs awal (`root=/dev/ram0`), dan mengeksekusi `/init` (**first stage init**).

---

# 3. PARTITION ECOSYSTEM

Data live dari `/dev/block/by-name/*` + `/proc/partitions` (eMMC 117 GB, GPT user area + 2 hw boot partition):

## Kelompok BOOT CHAIN

| Partition | Block device | Ukuran | Fungsi | Dibaca oleh | Digunakan kapan |
|---|---|---|---|---|---|
| `spl_a` / `spl_b` | mmcblk0boot0 / boot1 | (hw boot area) | Second Program Loader | Boot ROM | Setiap power-on |
| `sml_a` / `sml_b` | mmcblk0p6 / p7 | 1 MB | Secure Monitor Loader | SPL | Setiap boot, sebelum LK |
| `trustos_a` / `trustos_b` | mmcblk0p4 / p5 | 6 MB | TEE OS (Trusty) | SML/SPL | Setiap boot (secure world) |
| `teecfg_a` / `teecfg_b` | mmcblk0p32 / p33 | 1 MB | Konfigurasi TEE | SML/TEE | Setiap boot |
| `hypervsior_a` / `hypervsior_b` | mmcblk0p34 / p35 | 10 MB | Hypervisor / pVMFW | LK/SML | Boot protected VM |
| `pm_sys_a` / `pm_sys_b` | mmcblk0p30 / p31 | 1 MB | Firmware power management | SPL/PMIC flow | Power-on |
| `uboot_a` / `uboot_b` | mmcblk0p8 / p9 | 3 MB | LK/U-Boot bootloader | SPL/SML | Setiap boot |
| `uboot_log` | mmcblk0p10 | 16 MB | Log bootloader | LK (tulis), engineer (baca) | Setiap boot |
| `logo` / `fbootlogo` | mmcblk0p11 / p12 | 8 MB / 8 MB | Gambar logo boot | LK | Saat animasi/logo boot |
| `boot_a` / `boot_b` | mmcblk0p36 / p37 | 64 MB | Kernel + ramdisk (hdr v4, live magic `ANDROID!`) | LK | Setiap boot |
| `dtb_a` / `dtb_b` | mmcblk0p42 / p43 | 8 MB | Device Tree Blob (khas Unisoc, DTB partisi terpisah) | LK | Setiap boot |
| `dtbo_a` / `dtbo_b` | mmcblk0p44 / p45 | 8 MB | Device Tree overlay (live: `androidboot.dtbo_idx=15`) | LK | Setiap boot |
| `init_boot_a` / `init_boot_b` | mmcblk0p40 / p41 | 8 MB | Generic ramdisk + first-stage init (Android 13+) | LK | Setiap boot |
| `vendor_boot_a` / `vendor_boot_b` | mmcblk0p38 / p39 | 100 MB | Vendor ramdisk (magic `VNDRBOOT`), modul kernel vendor, resource recovery | LK | Setiap boot |

## Kelompok SECURITY

| Partition | Block device | Ukuran | Fungsi | Dibaca oleh | Digunakan kapan |
|---|---|---|---|---|---|
| `vbmeta_a` / `vbmeta_b` | mmcblk0p51 / p52 | 1 MB | Root of trust AVB (live: AVB0, avbtool 1.3.0, SHA256_RSA2048) | LK/U-Boot | Verifikasi boot |
| `vbmeta_system_a/b` | p57 / p58 | 1 MB | Chained vbmeta: hash `system`, `system_ext` | libavb (via vbmeta) | First-stage mount |
| `vbmeta_system_ext_a/b` | p61 / p62 | 1 MB | Chain untuk system_ext/vendor_dlkm/system_dlkm | libavb | First-stage mount |
| `vbmeta_vendor_a/b` | p59 / p60 | 1 MB | Hash `vendor` | libavb | First-stage mount |
| `vbmeta_product_a/b` | p63 / p64 | 1 MB | Hash `product` | libavb | First-stage mount |
| `vbmeta_odm_a/b` | p65 / p66 | 1 MB | Hash `odm` + property descriptor fingerprint ODM (live terbaca: `com.android.build.odm.fingerprint = realme/RMX3760/RE58C2:13/...`) | libavb | First-stage mount |
| `avbmeta_rs_a/b` | p67 / p68 | 1 MB | Rollback-protection metadata per slot | LK/libavb | Anti-rollback |
| `common_rs1/rs2_a/b` | p69–p72 | 8–16 MB | Rollback index tambahan (modem/DSP) | LK | Anti-rollback firmware radio |
| `metadata` | mmcblk0p55 | 64 MB | Kunci enkripsi (vold/metadata_encryption), state OTA, bootstat (live mount: **f2fs**) | first-stage init, vold | Boot & unlock storage |
| `misc` | mmcblk0p3 | 1 MB | BCB (Bootloader Control Block), metadata slot A/B | LK ↔ Android | Boot-recovery decision, mark slot |
| `ocdt_a/b`, `calinv` | p53/p54, p73 | 8 MB / 2 MB | Data kalibrasi/device config Unisoc | LK/modem | Factory & boot |

## Kelompok ANDROID OS (dynamic partitions di dalam `super`)

| Partition | Sumber | Ukuran total | Fungsi | Dibaca oleh | Digunakan kapan |
|---|---|---|---|---|---|
| `super` | mmcblk0p47 | **7.9 GB** | Container dynamic partitions | dm-linear (device-mapper) | First-stage init |
| `system` | logical `system_b` → dm-0 → verity dm-14 | ~3.6 GB | OS inti, root `/` (system-as-root, EROFS) | init first stage | Sejak first-stage mount |
| `system_ext` | dm-1 → dm-15 | ~959 MB | Ekstensi sistem (live: berisi bin Unisoc/Oplus: slogmodem, ummd, linkturbonative…) | init | First-stage mount |
| `vendor` | dm-2 → dm-16 | ~725 MB | HAL, firmware, fstab, modul kernel vendor | init | First-stage mount |
| `product` | dm-3 → dm-18 | ~1.8 GB | Kustomisasi Realme/Oplus | init | First-stage mount |
| `odm` | dm-4 → dm-17 | ~108 MB | Adaptasi ODM (firmware `/odm/firmware` — live: `firmware_class.path=/odm/firmware,/vendor/firmware`) | init | First-stage mount |
| `vendor_dlkm` | dm-5 → dm-19 | ~134 MB | Modul kernel vendor DLKM | init | First-stage mount |
| `system_dlkm` | dm-6 → dm-20 | ~13 MB | Modul kernel system DLKM (GKI) | init | First-stage mount |

Live snapshot Virtual A/B: device-mapper `-cow` aktif (`system_b-cow` dm-7 … `system_dlkm_b-cow` dm-13) — snapshot CoW untuk OTA seamless di atas `userdata`.

Partisi non-dynamic milik vendor OS: `my_preload` (1.8 GB, preload app Realme), `opporeserve` (64 MB, live ter-mount di `/mnt/vendor/opporeserve`), `oplusreserve1/3/5`, `blackbox` (200 MB), `prodnv` (64 MB, live ter-mount `/mnt/vendor` dan `/mnt/prodnv`), `persist`, `cache` (64 MB, f2fs), `sysdumpdb` (10 MB).

## Kelompok RUNTIME

| Partition | Block device | Ukuran | Fungsi | Dibaca oleh | Digunakan kapan |
|---|---|---|---|---|---|
| `userdata` | mmcblk0p77 → dm-56 | **106 GB** | Data aplikasi/user, F2FS + enkripsi metadata (live: `inlinecrypt`, `fileencryption=aes-256-xts:aes-256-cts:v2+inlinecrypt_optimized`) | vold/init second stage | Setelah decrypt |
| `cache` | mmcblk0p48 | 64 MB | Cache sementara (f2fs) | sistem | Runtime |
| `data` (= userdata) | dm-56 | — | Titik mount `/data` | semua apps | Runtime |

---

# 4. AVB SECURITY CHAIN

## Header vbmeta (dibaca live dari `/dev/block/by-name/vbmeta_b`)

```
Magic              : AVB0
libavb version     : 1.0 (required major 1)
Release string     : avbtool 1.3.0
Algorithm          : SHA256_RSA2048 (type 2)
Authentication blk : 576 bytes  (hash 32B @off 0 + signature 512B @off 32)
Auxiliary blk      : 17472 bytes (public key 1032B, descriptors 16400B @off 0)
Rollback index     : 0
Flags              : 0
```

Live dari bootconfig: `androidboot.vbmeta.avb_version="1.1"`, `hash_alg=sha256`, `vbmeta.size=51072`, digest SHA256 keseluruhan `0a51c901…85c0`.

## Hierarki chained vbmeta (hasil parsing descriptor live)

```
vbmeta_b (ROOT, ditandatangani OEM key Realme/Unisoc)
│
├── HASH DESCRIPTOR (langsung):
│     ├── boot          (boot_b)
│     ├── dtbo          (dtbo_b)
│     ├── init_boot     (init_boot_b)
│     └── vendor_boot   (vendor_boot_b)
│
├── CHAIN DESCRIPTOR → vbmeta_system_b
│     └── hash: system, system_ext
├── CHAIN DESCRIPTOR → vbmeta_system_ext_b
│     └── hash: vendor_dlkm, system_dlkm
├── CHAIN DESCRIPTOR → vbmeta_vendor_b
│     └── hash: vendor
├── CHAIN DESCRIPTOR → vbmeta_product_b
│     └── hash: product
└── CHAIN DESCRIPTOR → vbmeta_odm_b
      └── hash: odm  (+ property descriptor com.android.build.odm.*)
```

## Jenis descriptor yang bekerja di device ini

* **Hash descriptor** — menyimpan digest SHA256 dari seluruh isi partisi (boot, dtbo, init_boot, vendor_boot, system, system_ext, vendor, product, odm, dlkm). Partisi dibaca utuh dan di-hash.
* **Hashtree descriptor** — untuk partisi besar dynamic (system dst.), data diverifikasi on-the-fly oleh **dm-verity**: live terlihat target `dm-14 system-verity`, `dm-15 system_ext-verity`, `dm-16 vendor-verity`, `dm-17 odm-verity`, `dm-18 product-verity`, `dm-19 vendor_dlkm-verity`, `dm-20 system_dlkm-verity`.
* **Chain descriptor** — meneruskan trust ke vbmeta lain (pubkey chain terpisah).
* **Property descriptor** — vbmeta_odm menyematkan fingerprint ODM (terbaca live).
* **Rollback index** — nilai 0 pada vbmeta utama; proteksi rollback per-slot didukung partisi `avbmeta_rs_a/b` dan `common_rs1/rs2_a/b`.

## Siapa memverifikasi & kapan

1. **LK/U-Boot** (libavb tertanam di bootloader): memverifikasi `vbmeta_b` (signature RSA2048), mengikuti chain descriptor, memverifikasi hash `boot/dtbo/init_boot/vendor_boot` **sebelum** kernel dijalankan.
2. **First-stage init** (ramdisk): membaca `fstab.ums9230_hulk` (live path: `/vendor/etc/fstab.ums9230_hulk`) dengan opsi `avb=vbmeta_system`, `avb=vbmeta_vendor`, `avb=vbmeta_odm`, `avb=vbmeta_product`, `first_stage_mount` — membuat device-mapper linear + dm-verity dan memverifikasi partisi dynamic saat mount.
3. Hasil verifikasi diteruskan sebagai properti: `androidboot.vbmeta.device_state`, `androidboot.verifiedbootstate`, `veritymode=enforcing` (live).

## Hubungan bootloader ↔ AVB pada device UNLOCKED ini

* Karena bootloader **unlocked**, LK tetap menjalankan AVB tetapi **tidak menolak** image tak bertanda tangan; state dilaporkan `orange` + `device_state=unlocked` (terukur di `/proc/bootconfig`).
* Pada kondisi unlocked, verifikasi dm-verity tetap berjalan (`veritymode=enforcing`) untuk image stock; Magisk (terdeteksi live) bekerja dengan menambal boot image sehingga verifikasi hash boot dilewati secara desain oleh unlocked state.
* Warning screen "orange state" ditampilkan LK saat boot (perilaku standar libavb unlocked).

---

# 5. KERNEL STARTUP

## Peta alur (semua nilai dari live device)

```
Bootloader (LK)
  ↓  load kernel 5.15.178-android13-8 (GKI) + DTB (dtb_b) + DTBO idx 15
Kernel decompress & boot
  ↓
DTB: "Spreadtrum UMS9230 1H10 SoC", compatible "sprd,ums9230"   (/proc/device-tree)
  ↓
Boot parameter (/proc/cmdline) + Bootconfig (/proc/bootconfig)
  ↓
Mount ramdisk (root=/dev/ram0) → eksekusi /init → First Stage Init
```

## Data live `/proc/cmdline` (ringkas, utuh di device)

```
earlycon console=ttyS1,921600n8  loop.max_part=7 loglevel=1 kpti=0
firmware_class.path=/odm/firmware,/vendor/firmware
init=/init root=/dev/ram0 rw printk.devkmsg=on
swiotlb=1 rcupdate.rcu_expedited=1 rcu_nocbs=0-7 kvm-arm.mode=none
lcd_id=ID10 lcd_name=lcd_td4160_cw_old_mipi_hd lcd_base=9caa8000 lcd_size=1600x720 logo_bpix=24
androidboot.mkn=other sysdump_magic=80001000 sprdboot.mode=normal ltemode=lcsfb
rfboard.id=2 rfhw.id=41008 crystal=6 pcb.version=7 nvcode.id=00110011
bootcause="Reboot into normal" pwroffcause="device power down"
prj_name=22724 boot_mode=normal secure_type=0 eng_version=userdebug
sprdboot.slot_suffix=_b sprdboot.flash=emmc ... bootconfig
```

## Data live `/proc/bootconfig` (inti)

```
androidboot.hardware       = "ums9230_hulk"
androidboot.dtbo_idx       = "15"
androidboot.ddrsize        = "6144M"
androidboot.serialno       = "0I63710I38105C1C"
androidboot.regionmark     = "ID"   / product.regionmark = "T2_3760"
androidboot.product.hardware.sku = "nfc"
androidboot.slot_suffix    = "_b"
androidboot.force_normal_boot = "1"
androidboot.boot_devices   = "soc/soc:ap-apb/201d0000.sdio"
androidboot.mode           = "normal"
androidboot.verifiedbootstate = "orange"
androidboot.flash.locked   = "0"
androidboot.vbmeta.device_state = "unlocked"
androidboot.vbmeta.digest  = "0a51c901…85c0"
androidboot.veritymode     = "enforcing"
```

## Bagaimana hardware dikenali

* Kernel GKI 5.15 menerima DTB dari bootloader; model terbaca live: **"Spreadtrum UMS9230 1H10 SoC"** (`compatible = sprd,ums9230`). DTBO index 15 (live) memilih overlay varian board hulk/PCB v7.
* Perangkat muncul via bus platform/SDIO: boot storage di `soc/soc:ap-apb/201d0000.sdio` (live `boot_devices`), eMMC `mmcblk0`, kartu SD `mmcblk1` (live: vold mengelola `sdcard0:auto`).
* Firmware dimuat dari `firmware_class.path=/odm/firmware,/vendor/firmware` (live cmdline).

## Bagaimana kernel memulai Android

1. Kernel inisialisasi CPU/memory/driver essential, start `kthreadd`, lalu menjalankan `/init` dari ramdisk gabungan (generic ramdisk `init_boot` + vendor ramdisk `vendor_boot`).
2. **First-stage init** membaca properti `androidboot.*` (dari cmdline + bootconfig), menentukan slot (`ro.boot.slot_suffix=_b`), lalu mem-parse fstab vendor dan me-mount partisi awal (lihat §6).
3. `ueventd` (dijalankan init) memuat `/sys` → membuat node `/dev` (live: proses `ueventd` PID 228).

---

# 6. ANDROID INIT DAN FILESYSTEM

## Asal & proses mount (semua terukur live di `/proc/mounts`)

| Mount point | Sumber | Filesystem | Siapa membuat | Kapan |
|---|---|---|---|---|
| `/` | dm-14 (`system-verity` ← dm-0 `system_b`) | **EROFS ro** | first-stage init (fstab `first_stage_mount`) | First stage |
| `/system_ext` | dm-15 | EROFS ro | first-stage init | First stage |
| `/vendor` | dm-16 | EROFS ro | first-stage init | First stage |
| `/odm` | dm-17 | EROFS ro | first-stage init | First stage |
| `/product` | dm-18 | EROFS ro | first-stage init | First stage |
| `/vendor_dlkm` | dm-19 | EROFS ro | first-stage init | First stage |
| `/system_dlkm` | dm-20 | EROFS ro | first-stage init | First stage |
| `/metadata` | mmcblk0p55 | f2fs | first-stage init (`check`) | First stage |
| `/data` | dm-56 (userdata) | f2fs + inlinecrypt | vold (second stage, setelah unlock keystore) | Second stage |
| `/cache` | mmcblk0p48 | f2fs | init/vold | Second stage |
| `/mnt/vendor` | prodnv (mmcblk0p1) | ext4 | init (fstab vendor) | Second stage |
| `/mnt/vendor/opporeserve` | mmcblk0p50 | ext4 | init | Second stage |
| `/apex/*` | loop*/dm-* per APEX | ext4 ro | apexd | Setelah second stage mulai |
| `/dev`, `/proc`, `/sys` | tmpfs/procfs/sysfs | — | kernel + ueventd | Paling awal |

Catatan live: root `/` **adalah system partition** (system-as-root). Direktori `/system` adalah bind/subtree dari root itu sendiri; `system_ext`, `vendor`, `product`, `odm` ter-mount menimpa direktori kosong di root tersebut.

## Isi direktori (live)

* `/system`: `app`, `bin`, `etc`, `fonts`, `apex`, multi-prop regional Realme (`build_T2_3760.prop`, `build_EEA_*`, `build_RU_*`, dll — satu build untuk banyak region).
* `/vendor`: `bin`, `etc` (termasuk `fstab.ums9230_hulk`, `init/*.rc`), `firmware`.
* `/product`: `app`, `bin`, prop region.
* `/odm`: `bin`, `etc` (`init/init.md.rc`), `firmware`, `lib64`, `logo`.
* `/apex`: puluhan APEX ter-mount (live): `com.android.art`, `com.android.runtime`, `com.android.conscrypt`, `com.android.adbd`, `com.android.wifi`, `com.android.tzdata`, `com.android.media`, `com.android.media.swcodec`, `com.android.btservices`, `com.android.uwb`, dll.
* `/data` (struktur standar live): `app`, `app-lib`, `data`, `dalvik-cache`, `anr`, `backup`, `system`, `user`, `media`, `misc_ce/de`, `vold`, `ota`, dsb.
* `/metadata` (live): `vold` (kunci enkripsi), `ota`, `gsi`, `bootstat`, `password_slots`, `staged-install`, `userspacereboot`, `aconfig`, `watchdog`, `apex`.

## Intersepsi root (observasi live)

`/proc/mounts` menunjukkan `magisk /system_ext/bin tmpfs ro` — Magisk menambal rantai init dengan overlay bind-mount; inilah penyebab spoofing properti lock-state yang didokumentasikan di bagian identitas.

---

# 7. ANDROID RUNTIME

## Urutan peluncuran (proses live terverifikasi via `ps`/`/proc`)

```
init (PID 1)                        ← first stage → second stage
  ↓
ueventd (PID 228)                   ← coldplug /dev
  ↓
SELinux load policy                 ← enforcing (live: seclabel di semua mount)
  ↓
servicemanager (PID 307)            ← binder service manager
  ↓
HAL vendors (live: vendor.sprd.har × banyak, vendor.unisoc.h,
             audio, camera provider, composer, sensors, keymint-trusty,
             gatekeeper-trusty, wifi, usb, drm/widevine, NN armnn-gpu)
  ↓
Native services (lmkd, installd, vold, netd, audioserver,
             surfaceflinger PID 768, gatekeeperd PID 909, cameraserver…)
  ↓
Zygote (live: zygote64 PID 720 + zygote PID 722 → konfigurasi zygote64_32;
        webview_zygote PID 1633)
  ↓
SystemServer (PID 1259)             ← fork dari zygote
  ↓
Android Framework (AMS, WMS, PMS, SystemUI…)
  ↓
Application (live contoh: chrome + app zygotes per aplikasi)
```

File rc yang mengatur ini (live): `/system/etc/init/hw/init.rc`, `init.zygote64_32.rc`, `init.usb.rc`, `init.usb.configfs.rc`; vendor: `/vendor/etc/init/android.hardware.*.rc`, `charge.rc`, `engpc.rc`, dll; odm: `init.md.rc`.

## Hubungan lapisan

```
Kernel (GKI 5.15.178, driver Unisoc via vendor_boot/vendor_dlkm)
  ↓  syscall + binder
Vendor layer (vendor/odm: HAL process, firmware /odm/firmware,/vendor/firmware)
  ↓  HIDL/AIDL binder
HAL (audio, camera, sensors, keymint/trusty TEE, graphics composer…)
  ↑  dipakai oleh
Framework (Java/Kotlin di ART — APEX com.android.art, system_server)
  ↓  SDK/API 35
Application (sandbox UID terpisah, data di /data f2fs terenkripsi)
```

---

# 8. RECOVERY ENVIRONMENT

## Status di device ini (A/B)

* **Tidak ada partisi recovery terpisah** (konfirmasi live: tidak ada entri `recovery` di `/dev/block/by-name`). Pada skema A/B, recovery hidup **di dalam ramdisk `boot` + `vendor_boot`**.
* Resource recovery vendor berada di `vendor_boot_b` (magic `VNDRBOOT`); binary recovery & first-stage init di ramdisk generik `init_boot_b`/`boot_b`.

## Kapan recovery dipanggil & siapa yang menentukan

1. **BCB (misc)**: userspace (OTA updater, atau user via `adb reboot recovery`) menulis command `boot-recovery` ke partisi `misc`. **Bootloader (LK)** membaca BCB lebih dulu setiap boot — jika berisi `boot-recovery`, LK memuat kernel+ramdisk recovery, bukan Android normal.
2. **Key combination**: LK juga mendeteksi tombol (Volume−/Power) saat boot dan dapat memilih recovery tanpa BCB.
3. Live saat dokumentasi ini dibuat: BCB **kosong** (dd dari `misc` tidak menghasilkan string command) dan cmdline `boot_mode=normal`, `bootcause="Reboot into normal"` → device boot normal.

## Perbedaan recovery vs Android normal

| Aspek | Normal boot | Recovery |
|---|---|---|
| Ramdisk | generic (init_boot) + vendor (vendor_boot) penuh | ramdisk recovery (subset + binary `recovery`) |
| Init | init penuh → zygote → framework | init mini → hanya service recovery/UI |
| Mount | system/vendor/product/odm/data lengkap | biasanya hanya boot-critical; `/data` opsional (untuk sideload/decryption) |
| GUI | SurfaceFlinger + SystemUI | UI minimal (swipe/recovery menu) |
| Tujuan | runtime harian | OTA install, factory reset, sideload, fastbootd (userspace fastboot via recovery) |

## Hubungan recovery dengan bootchain

* Recovery **diverifikasi AVB** seperti boot normal (hash `boot`/`vendor_boot` di vbmeta) — image recovery tak sah akan gagal verifikasi pada device locked; pada device unlocked ini verifikasi tidak memblokir.
* Setelah OTA sukses, recovery/update-engine menandai slot aktif baru via `misc`/bootctl; bootloader kemudian switch slot (device ini: B aktif).
* Fastbootd (fastboot userspace) berjalan di dalam recovery environment — satu-satunya cara modifikasi dynamic partition di era super/.

---

# 9. AOSP ANDROID 15 VS UNISOC VS REALME

## AOSP Android 15 (API 35) — arsitektur generik

* **Boot architecture**: boot image v4, `init_boot` (generic ramdisk), `vendor_boot`, GKI kernel 5.15.x (live: `5.15.178-android13-8` — branch GKI), bootconfig sebagai pelengkap cmdline.
* **Init**: two-stage init, first_stage_mount + fstab vendor, APEX activation oleh apexd, linkerconfig.
* **AVB**: vbmeta + chained vbmeta + dm-verity + rollback index (semua standar libavb 1.1/1.2).
* **Filesystem**: system-as-root read-only, dynamic partitions (super), EROFS/ext4, F2FS userdata dengan metadata encryption v2, Virtual A/B dengan CoW snapshot (live: dm-*-cow).
* **Runtime/framework**: zygote 64_32, SELinux enforcing, HAL AIDL/HIDL via servicemanager/hwservicemanager, ART dari APEX.

## Unisoc UMS9230 (T612) — implementasi vendor silicon

* **Boot ROM** proprietary + **SPL di eMMC hw boot partition** (bukan partisi GPT) — live: `spl_a→mmcblk0boot0`, `spl_b→mmcblk0boot1`.
* **FDL** download protocol (flashing/unbrick via USB), sysdump crash-dump (`sysdump_magic=80001000` live).
* **LK** (bukan U-Boot upstream umum) dengan dukungan slot, BCB, AVB, logo partisi (`logo`, `fbootlogo`), log `uboot_log`.
* **Modem/DSP ecosystem**: partisi `l_modem`, `l_gdsp`, `l_ldsp`, `l_agdsp`, `l_deltanv`, `l_fixnv1/2`, `l_runtimenv1/2`, `pm_sys` — NVRAM & firmware radio khas Unisoc, semuanya ikut skema A/B.
* **TEE Trusty** (`trustos`, `teecfg`, HAL `keymint@gatekeeper .trusty`), hypervisor partition.
* Hardware init via DTB khusus (`sprd,ums9230`) + DTBO per-board; firmware path `/odm/firmware,/vendor/firmware`.

## Realme (BBK/Oplus) — kustomisasi produk

* **Partition layout**: `my_preload` (1.8 GB preload apps), `opporeserve`, `oplusreserve1/3/5`, `blackbox`, `ocdt`, `calinv` — partisi khas grup Oplus.
* **Vendor customization**: multi-region prop files (`build_T2_3760.prop` untuk Indonesia), `system_ext` berisi tool Oplus/Realme (`linkturbonative`, `phoenix_log_native_helper.sh`, `init.oplus.nandswap.sh` — live terlihat di mount list), nandswap/zram tuning (live: `zram0` 4.1 GB aktif).
* **Hardware service**: SKU NFC (`androidboot.product.hardware.sku=nfc`, HAL `nfc_nci SNxxx`), LCD panel td4160, sensor unisoc multihal, charger (`charge.rc`, `charged.rc`), regionmark ID.

---

# 10. DIAGRAM FINAL

```
                            ┌──────────────┐
                            │   POWER ON   │
                            └──────┬───────┘
                                   ↓
                     PMIC 2730 + SoC UMS9230 init
                                   ↓
                       Boot ROM (maskrom Unisoc)
                                   ↓
              SPL / splloader  (eMMC boot0/boot1, slot B)
                                   ↓
              SML → TrustOS TEE (trustos_b, teecfg_b)
                                   ↓
              LK / U-Boot  (uboot_b)  ── baca GPT, slot _b
                                   ↓
                    ┌──────────────────────────┐
                    │  BOOTLOADER DECISION     │
                    │  baca BCB (misc)         │
                    │  + tombol + OTA metadata │
                    └───────┬──────────┬───────┘
              normal boot   │          │   boot-recovery
                            ↓          ↓
              ┌──────────────────┐   ┌─────────────────────────┐
              │  AVB (libavb)    │   │  RECOVERY ENVIRONMENT   │
              │  vbmeta_b →      │   │  ramdisk recovery dari  │
              │  boot/dtbo/      │   │  boot + vendor_boot     │
              │  init_boot/      │   │  OTA / reset / fastbootd│
              │  vendor_boot     │   └─────────────────────────┘
              │  → chain vbmeta_*│
              └────────┬─────────┘
                       ↓ (state: orange / unlocked)
        KERNEL 5.15.178 GKI  +  DTB (sprd,ums9230) + DTBO idx 15
                       ↓
        Boot params (/proc/cmdline) + Bootconfig (/proc/bootconfig)
        slot_suffix=_b · boot_devices=201d0000.sdio · force_normal_boot=1
                       ↓
        FIRST STAGE INIT  (init_boot generic ramdisk)
        dm-linear super → system_b/system_ext_b/vendor_b/
        product_b/odm_b/vendor_dlkm_b/system_dlkm_b
                       ↓
        FILESYSTEM MOUNT  (EROFS ro + dm-verity dm-14…dm-20)
        / · /system_ext · /vendor · /product · /odm
        /metadata (f2fs) → /data (f2fs, encrypted, dm-56)
        apexd → /apex/*
                       ↓
        SELINUX ENFORCING + ueventd (/dev)
                       ↓
        HAL  (vendor.sprd.har, keymint/gatekeeper-trusty,
              composer, camera, sensors, wifi, usb, drm…)
                       ↓
        NATIVE SERVICES (servicemanager, surfaceflinger,
              audioserver, vold, lmkd, netd, installd…)
                       ↓
        ZYGOTE (zygote64 + zygote, 64_32)
                       ↓
        SYSTEMSERVER
                       ↓
        ANDROID FRAMEWORK (AMS/WMS/PMS/SystemUI, ART APEX)
                       ↓
        APPLICATION  ← Android 15 berjalan penuh
```

---

## LAMPIRAN — BUKTI DATA LIVE YANG DIGUNAKAN

Perintah yang dijalankan pada shell root device (runtime Android hidup):

```
getprop                                  # identitas, slot, state lock, fingerprint
uname -a ; cat /proc/version             # kernel GKI 5.15.178-android13-8
cat /proc/cmdline ; cat /proc/bootconfig # boot params + androidboot.*
cat /proc/partitions ; cat /proc/mounts  # peta storage & mount
ls -la / /system /vendor /product /odm   # struktur root live
ls -la /dev/block/by-name/*              # seluruh label partisi → mmcblk0pXX
cat /proc/device-tree/model|compatible   # "Spreadtrum UMS9230 1H10 SoC"
ps -A ; /proc/*/cmdline                  # init, ueventd, zygote64/32,
                                         # system_server, HAL sprd/unisoc
for d in /sys/block/dm-*/dm/name         # nama target device-mapper
dd vbmeta_b (header+descriptors)         # AVB0, avbtool 1.3.0, SHA256_RSA2048,
                                         # chain & hash descriptors
dd misc                                  # BCB kosong (boot normal)
dd boot_b / init_boot_b / vendor_boot_b  # magic ANDROID! v4 / ANDROID! / VNDRBOOT
cat /vendor/etc/fstab.ums9230_hulk       # first_stage_mount + avb=*
ls /system/etc/init/hw                   # init.rc, init.zygote64_32.rc…
```

*Semua angka ukuran partisi, nama device-mapper, isi descriptor AVB, properti boot, dan daftar proses pada dokumen ini adalah hasil pembacaan langsung dari perangkat RMX3760 pada sesi boot slot B yang sedang berjalan.*

**— Akhir dokumentasi —**
