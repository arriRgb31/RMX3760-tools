@echo off
REM ============================================
REM RMX3760 Tools — Windows Setup
REM Realme C53 | Unisoc UMS9230 T612 | Android 15
REM by@arriRgb31
REM ============================================
REM Referensi:
REM   CVE-2022-38694: https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader
REM   Gopartner: https://github.com/Gopartner/realme-c53-unlock-root
REM   AOSP: https://developer.android.com/tools/releases/platform-tools
REM ============================================

echo ============================================
echo  RMX3760 Tools — Windows Setup
echo  Realme C53 RMX3760 | Unisoc UMS9230 | Android 15
echo ============================================
echo.

REM Check Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [WARN] Tidak running sebagai Administrator
    echo        Beberapa fitur mungkin perlu Admin
    echo.
)

REM Check Python
echo [1/6] Checking Python...
python --version >nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] Python: 
    python --version
) else (
    echo [WARN] Python tidak ditemukan
    echo        Install: https://www.python.org/downloads/
    echo        atau: winget install Python.Python.3.12
)

REM Check Git
echo.
echo [2/6] Checking Git...
git --version >nul 2>&1
if %errorLevel% equ 0 (
    echo [OK] Git: 
    git --version
) else (
    echo [WARN] Git tidak ditemukan
    echo        Install: https://git-scm.com/download/win
)

REM Create tools directory
echo.
echo [3/6] Creating tools directory...
if not exist "%USERPROFILE%\RMX3760-tools\tools\bin\windows" mkdir "%USERPROFILE%\RMX3760-tools\tools\bin\windows"

REM Download AOSP Platform Tools
echo.
echo [4/6] Downloading AOSP Platform Tools...
set PT_DIR=%USERPROFILE%\RMX3760-tools\tools\bin\windows\platform-tools
if exist "%PT_DIR%\adb.exe" (
    echo [OK] Platform tools sudah ada
) else (
    echo Downloading platform-tools...
    curl -L -o "%TEMP%\platform-tools.zip" "https://dl.google.com/android/repository/platform-tools-latest-windows.zip" 2>nul
    if %errorLevel% equ 0 (
        powershell -command "Expand-Archive -Path '%TEMP%\platform-tools.zip' -DestinationPath '%USERPROFILE%\RMX3760-tools\tools\bin\windows' -Force"
        echo [OK] Platform tools installed
        del "%TEMP%\platform-tools.zip" 2>nul
    ) else (
        echo [FAIL] Download gagal
    )
)

REM Download CVE-2022-38694 exploit
echo.
echo [5/6] Downloading CVE-2022-38694 exploit...
set CVE_DIR=%USERPROFILE%\RMX3760-tools\tools\downloads\cve-2022-38694
if exist "%CVE_DIR%\ums9230_Realme_C53_RMX3760_RMX3762.exe" (
    echo [OK] CVE tool sudah ada
) else (
    mkdir "%CVE_DIR%" 2>nul
    echo Downloading CVE exploit for RMX3760...
    curl -L -o "%CVE_DIR%\cve-tool.zip" "https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader/releases/download/1.72/ums9230_Realme_C53_RMX3760_RMX3762.zip" 2>nul
    if %errorLevel% equ 0 (
        powershell -command "Expand-Archive -Path '%CVE_DIR%\cve-tool.zip' -DestinationPath '%CVE_DIR%' -Force"
        echo [OK] CVE tool downloaded
        del "%CVE_DIR%\cve-tool.zip" 2>nul
    ) else (
        echo [FAIL] Download gagal — download manual dari:
        echo        https://github.com/TomKing062/CVE-2022-38694_unlock_bootloader/releases
    )
)

REM Download Unisoc USB Driver info
echo.
echo [6/6] Unisoc USB Driver...
echo.
echo  ============================================
echo   Unisoc SPD Driver — Install Manual
echo  ============================================
echo.
echo  Download:
echo    https://spreadtrumdriver.com/
echo    https://mirrors.lolinet.com/software/windows/Unisoc/drivers/
echo.
echo  Latest: SPD_Driver_R4.24.2705
echo.
echo  Install:
echo    1. Download SPD_Driver_R4.24.2705.zip
echo    2. Extract
echo    3. Run DPInst64.exe (64-bit)
echo    4. Restart PC jika perlu
echo.

REM Add to PATH
echo Adding to PATH...
setx PATH "%PATH%;%USERPROFILE%\RMX3760-tools\tools\bin\windows\platform-tools" >nul 2>&1

echo.
echo ============================================
echo  Setup selesai!
echo.
echo  Tools location:
echo    Platform Tools: %PT_DIR%
echo    CVE Exploit:    %CVE_DIR%
echo.
echo  Jalankan:
echo    rmx3760.bat
echo ============================================
pause
