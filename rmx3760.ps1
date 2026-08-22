# ============================================
# RMX3760 Tools — PowerShell Launcher
# Realme C53 RMX3760 | Unisoc UMS9230 | Android 15
# by@arriRgb31
#
# Referensi:
#   CVE-2022-38694: https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader
#   Gopartner: https://github.com/Gopartner/realme-c53-unlock-root
# ============================================

$ErrorActionPreference = "Continue"
$ToolsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PlatformTools = "$ToolsDir\tools\bin\windows\platform-tools"
$CveDir = "$ToolsDir\tools\downloads\cve-2022-38694"

# Set ADB/Fastboot
if (Test-Path "$PlatformTools\adb.exe") {
    $ADB = "$PlatformTools\adb.exe"
    $Fastboot = "$PlatformTools\fastboot.exe"
} else {
    $ADB = "adb"
    $Fastboot = "fastboot"
}

function Show-Menu {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " RMX3760 Tools - Realme C53 Android 15" -ForegroundColor White
    Write-Host " Unisoc UMS9230 T612" -ForegroundColor Gray
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " [1]  Cek Device"
    Write-Host " [2]  Unlock Bootloader (CVE-2022-38694)"
    Write-Host " [3]  Flash vendor_boot (TWRP)"
    Write-Host " [4]  Flash boot (Magisk/root)"
    Write-Host " [5]  Reboot Recovery"
    Write-Host " [6]  Reboot Bootloader"
    Write-Host " [7]  Reboot System"
    Write-Host " [8]  Enter FDL2 (Download Mode)"
    Write-Host " [9]  Cek AVB Status"
    Write-Host " [0]  Keluar"
    Write-Host ""
}

function Check-Device {
    Write-Host "`n=== Cek Device ===" -ForegroundColor Yellow
    & $ADB devices
    Write-Host ""
    $model = & $ADB shell getprop ro.product.model 2>$null
    $android = & $ADB shell getprop ro.build.version.release 2>$null
    $slot = & $ADB shell getprop ro.boot.slot_suffix 2>$null
    Write-Host "Model:   $model"
    Write-Host "Android: $android"
    Write-Host "Slot:    $slot"
    Read-Host "`nPress Enter"
}

function Unlock-Bootloader {
    Write-Host "`n=== Unlock Bootloader — CVE-2022-38694 ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " WARNING: Unlock akan menghapus data!" -ForegroundColor Red
    $confirm = Read-Host " Lanjutkan? (y/N)"
    if ($confirm -ne "y") { return }

    Write-Host "`nStep 1: Masuk FDL2..." -ForegroundColor Cyan
    & $ADB reboot autodloader

    Write-Host "`nStep 2: Jalankan CVE tool" -ForegroundColor Cyan
    if (Test-Path "$CveDir\ums9230_Realme_C53_RMX3760_RMX3762.exe") {
        Set-Location $CveDir
        & ".\ums9230_Realme_C53_RMX3760_RMX3762.exe"
    } else {
        Write-Host " CVE tool tidak ditemukan!" -ForegroundColor Red
        Write-Host " Download: https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader/releases"
    }
    Read-Host "`nPress Enter"
}

function Flash-VendorBoot {
    Write-Host "`n=== Flash vendor_boot (TWRP) ===" -ForegroundColor Yellow
    $image = Read-Host " Vendor_boot image path"
    if (-not (Test-Path $image)) {
        Write-Host " File tidak ditemukan!" -ForegroundColor Red
        Read-Host "Press Enter"
        return
    }
    $slot = Read-Host " Slot (A/B/both)"
    switch ($slot) {
        "A"     { & $Fastboot flash vendor_boot_a $image }
        "B"     { & $Fastboot flash vendor_boot_b $image }
        default {
            & $Fastboot flash vendor_boot_a $image
            & $Fastboot flash vendor_boot_b $image
        }
    }
    Read-Host "`nPress Enter"
}

function Flash-Boot {
    Write-Host "`n=== Flash boot (Magisk/root) ===" -ForegroundColor Yellow
    $image = Read-Host " Boot image path"
    if (-not (Test-Path $image)) {
        Write-Host " File tidak ditemukan!" -ForegroundColor Red
        Read-Host "Press Enter"
        return
    }
    $slot = Read-Host " Slot (A/B/both)"
    switch ($slot) {
        "A"     { & $Fastboot flash boot_a $image }
        "B"     { & $Fastboot flash boot_b $image }
        default {
            & $Fastboot flash boot_a $image
            & $Fastboot flash boot_b $image
        }
    }
    Read-Host "`nPress Enter"
}

function Enter-FDL2 {
    Write-Host "`n=== Enter FDL2 (Download Mode) ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " FDL2 = Unisoc download mode untuk CVE-2022-38694" -ForegroundColor Cyan
    Write-Host " Boot chain: Boot ROM -> SPL -> [exploit] -> FDL2" -ForegroundColor Gray
    $confirm = Read-Host "`n Masuk FDL2? (y/N)"
    if ($confirm -eq "y") {
        & $ADB reboot autodloader
        Write-Host " Rebooting to FDL2..." -ForegroundColor Green
    }
    Read-Host "`nPress Enter"
}

function Check-AVB {
    Write-Host "`n=== Cek AVB Status ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Verified boot state:"
    & $ADB shell getprop ro.boot.verifiedbootstate 2>$null
    Write-Host "`nDevice state:"
    & $ADB shell getprop ro.boot.vbmeta.device_state 2>$null
    Write-Host "`nFlash locked:"
    & $ADB shell getprop ro.boot.flash.locked 2>$null
    Write-Host "`nSlot:"
    & $ADB shell getprop ro.boot.slot_suffix 2>$null
    Read-Host "`nPress Enter"
}

# Main loop
while ($true) {
    Show-Menu
    $choice = Read-Host "  Pilihan"
    switch ($choice) {
        "1" { Check-Device }
        "2" { Unlock-Bootloader }
        "3" { Flash-VendorBoot }
        "4" { Flash-Boot }
        "5" { & $ADB reboot recovery; Start-Sleep 2 }
        "6" { & $ADB reboot bootloader; Start-Sleep 2 }
        "7" { & $ADB reboot; Start-Sleep 2 }
        "8" { Enter-FDL2 }
        "9" { Check-AVB }
        "0" { exit }
    }
}
