@echo off
REM ============================================
REM RMX3760 Tools — Windows Launcher
REM Realme C53 RMX3760 | Unisoc UMS9230 | Android 15
REM by@arriRgb31
REM
REM Referensi:
REM   CVE-2022-38694: https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader
REM   Gopartner: https://github.com/Gopartner/realme-c53-unlock-root
REM ============================================

setlocal enabledelayedexpansion
title RMX3760 Tools - Realme C53 Android 15

set TOOLS_DIR=%~dp0
set PLATFORM_TOOLS=%TOOLS_DIR%tools\bin\windows\platform-tools
set CVE_DIR=%TOOLS_DIR%tools\downloads\cve-2022-38694

REM Use platform tools if available
if exist "%PLATFORM_TOOLS%\adb.exe" (
    set ADB=%PLATFORM_TOOLS%\adb.exe
    set FASTBOOT=%PLATFORM_TOOLS%\fastboot.exe
) else (
    set ADB=adb
    set FASTBOOT=fastboot
)

:menu
cls
echo ============================================
echo  RMX3760 Tools - Realme C53 Android 15
echo  Unisoc UMS9230 T612
echo ============================================
echo.
echo  [1]  Cek Device
echo  [2]  Unlock Bootloader (CVE-2022-38694)
echo  [3]  Flash vendor_boot (TWRP)
echo  [4]  Flash boot (Magisk/root)
echo  [5]  Reboot Recovery
echo  [6]  Reboot Bootloader
echo  [7]  Reboot System
echo  [8]  Enter FDL2 (Download Mode)
echo  [9]  Cek AVB Status
echo  [0]  Keluar
echo.
set /p choice="  Pilihan: "

if "%choice%"=="1" goto check_device
if "%choice%"=="2" goto unlock
if "%choice%"=="3" goto flash_vendor_boot
if "%choice%"=="4" goto flash_boot
if "%choice%"=="5" goto reboot_recovery
if "%choice%"=="6" goto reboot_bootloader
if "%choice%"=="7" goto reboot_system
if "%choice%"=="8" goto enter_fdl2
if "%choice%"=="9" goto check_avb
if "%choice%"=="0" goto exit
goto menu

:check_device
cls
echo === Cek Device ===
echo.
%ADB% devices
echo.
%ADB% shell getprop ro.product.model 2>nul
%ADB% shell getprop ro.build.version.release 2>nul
%ADB% shell getprop ro.boot.slot_suffix 2>nul
echo.
pause
goto menu

:unlock
cls
echo === Unlock Bootloader — CVE-2022-38694 ===
echo.
echo  Referensi:
echo    https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader
echo    https://github.com/Gopartner/realme-c53-unlock-root
echo.
echo  WARNING: Unlock akan menghapus data!
echo.
set /p confirm="  Lanjutkan? (y/N): "
if not "%confirm%"=="y" goto menu

echo.
echo  Step 1: Masuk FDL2 (download mode)
echo    Device akan reboot ke download mode
echo.
%ADB% reboot autodloader
echo.
echo  Step 2: Jalankan CVE tool di sini
echo    %CVE_DIR%
echo.
if exist "%CVE_DIR%\ums9230_Realme_C53_RMX3760_RMX3762.exe" (
    echo  Running CVE tool...
    cd /d "%CVE_DIR%"
    ums9230_Realme_C53_RMX3760_RMX3762.exe
) else (
    echo  CVE tool tidak ditemukan!
    echo  Download dari: https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader/releases
)
echo.
pause
goto menu

:flash_vendor_boot
cls
echo === Flash vendor_boot (TWRP) ===
echo.
set /p image="  Vendor_boot image path: "
if not exist "%image%" (
    echo  File tidak ditemukan: %image%
    pause
    goto menu
)
echo.
echo  Slot? (A/B/both)
set /p slot="  [A/B/both]: "
if "%slot%"=="A" (
    %FASTBOOT% flash vendor_boot_a "%image%"
) else if "%slot%"=="B" (
    %FASTBOOT% flash vendor_boot_b "%image%"
) else (
    %FASTBOOT% flash vendor_boot_a "%image%"
    %FASTBOOT% flash vendor_boot_b "%image%"
)
echo.
pause
goto menu

:flash_boot
cls
echo === Flash boot (Magisk/root) ===
echo.
set /p image="  Boot image path: "
if not exist "%image%" (
    echo  File tidak ditemukan: %image%
    pause
    goto menu
)
echo.
echo  Slot? (A/B/both)
set /p slot="  [A/B/both]: "
if "%slot%"=="A" (
    %FASTBOOT% flash boot_a "%image%"
) else if "%slot%"=="B" (
    %FASTBOOT% flash boot_b "%image%"
) else (
    %FASTBOOT% flash boot_a "%image%"
    %FASTBOOT% flash boot_b "%image%"
)
echo.
pause
goto menu

:reboot_recovery
cls
echo === Reboot Recovery ===
%ADB% reboot recovery
echo  Rebooting to recovery...
pause
goto menu

:reboot_bootloader
cls
echo === Reboot Bootloader (Fastboot) ===
%ADB% reboot bootloader
echo  Rebooting to bootloader...
pause
goto menu

:reboot_system
cls
echo === Reboot System ===
%ADB% reboot
echo  Rebooting to system...
pause
goto menu

:enter_fdl2
cls
echo === Enter FDL2 (Download Mode) ===
echo.
echo  FDL2 = Unisoc download mode untuk CVE-2022-38694
echo  BERBEDA dengan reboot bootloader!
echo.
echo  Boot chain:
echo    Boot ROM -^> SPL -^> [exploit] -^> FDL2 -^> download mode
echo.
set /p confirm="  Masuk FDL2? (y/N): "
if not "%confirm%"=="y" goto menu
%ADB% reboot autodloader
echo  Rebooting to FDL2...
pause
goto menu

:check_avb
cls
echo === Cek AVB Status ===
echo.
echo  Verified boot state:
%ADB% shell getprop ro.boot.verifiedbootstate 2>nul
echo.
echo  Device state:
%ADB% shell getprop ro.boot.vbmeta.device_state 2>nul
echo.
echo  Flash locked:
%ADB% shell getprop ro.boot.flash.locked 2>nul
echo.
echo  Slot:
%ADB% shell getprop ro.boot.slot_suffix 2>nul
echo.
pause
goto menu

:exit
exit
