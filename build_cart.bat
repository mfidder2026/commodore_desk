@echo off
setlocal
:: ======================================================
:: Commodore Desk 64 - EasyFlash .CRT build (Fase 10)
:: Verpakt de volledige OS in een cartridge-image en maakt
:: er een EasyFlash-.CRT van (instant boot, geen disk-load).
:: ======================================================

set "JAVA_EXE=C:\Users\aegwh\OneDrive\dev\c64\java\bin\java.exe"
set "KICKASS_JAR=C:\Users\aegwh\OneDrive\dev\c64\kick\KickAss.jar"
set "VICE_BIN=C:\Users\aegwh\OneDrive\dev\c64\vice\bin"
set "VICE_EXE=%VICE_BIN%\x64sc.exe"
set "CARTCONV=%VICE_BIN%\cartconv.exe"

if not exist build mkdir build

echo [1/3] Assembleren (cartridge-image)...
"%JAVA_EXE%" -jar "%KICKASS_JAR%" main_cart.asm -showmem -odir build
if errorlevel 1 ( echo Build failed. & exit /b 1 )

echo [2/3] Omzetten naar EasyFlash .CRT...
"%CARTCONV%" -t easy -b -p -i build\cd64_cart.bin -o build\CommodoreDesk64.crt -n "Commodore Desk 64"
if errorlevel 1 ( echo cartconv failed. & exit /b 1 )

echo [3/3] Klaar: build\CommodoreDesk64.crt
echo.
echo Testen in VICE (met optionele disk voor bestanden/instellingen):
echo   "%VICE_EXE%" -cartcrt build\CommodoreDesk64.crt -8 build\CD64.d71
echo.
echo Flashen: kopieer de .CRT naar SD, start EasyProg op de C64 en flash 'm.

:: Optioneel automatisch starten:
:: "%VICE_EXE%" -cartcrt build\CommodoreDesk64.crt -8 build\CD64.d71 +confirmonexit
