@echo off
setlocal
:: ======================================================
:: Commodore Desk 64 - D71 disk build (voorlopige uitlevering)
:: Assembleert disk_main.asm -> build\cd64.prg en zet die op
:: een geformatteerde D71 (dubbelzijdig 1571, ~340 KB).
:: ======================================================

set "JAVA_EXE=C:\Users\aegwh\OneDrive\dev\c64\java\bin\java.exe"
set "KICKASS_JAR=C:\Users\aegwh\OneDrive\dev\c64\kick\KickAss.jar"
set "VICE_BIN=C:\Users\aegwh\OneDrive\dev\c64\vice\bin"
set "VICE_EXE=%VICE_BIN%\x64sc.exe"
set "C1541=%VICE_BIN%\c1541.exe"

if not exist build mkdir build

echo [1/3] Syntax-check...
for %%F in (disk_main.asm hal\vic.asm hal\input.asm hal\disk.asm gfx\font.asm gfx\gfx.asm gfx\sprite.asm kernel\events.asm kernel\memory.asm kernel\irq.asm kernel\banking.asm gui\widgets.asm apps\filemanager.asm apps\editor.asm apps\calc.asm apps\paint.asm apps\settings.asm gui\shell.asm kernel\kernel.asm) do (
  python c64_ka_syntax_checker.py "%%F"
  if errorlevel 1 ( echo Syntax errors in %%F & exit /b 1 )
)

echo [2/3] Assembleren (core + app-overlays + bootscherm)...
"%JAVA_EXE%" -jar "%KICKASS_JAR%" disk_main.asm -vicesymbols -odir build
if errorlevel 1 ( echo Build failed. & exit /b 1 )
"%JAVA_EXE%" -jar "%KICKASS_JAR%" boot_main.asm -o build\boot.prg -odir build
if errorlevel 1 ( echo Boot build failed. & exit /b 1 )
"%JAVA_EXE%" -jar "%KICKASS_JAR%" cowboy_main.asm -o build\cowboy.prg -odir build
if errorlevel 1 ( echo Cowboy build failed. & exit /b 1 )

echo [3/3] D71 maken en PRG's erop schrijven (BOOT start eerst)...
if exist build\CD64.d71 del build\CD64.d71
"%C1541%" -format "commodore desk,cd" d71 build\CD64.d71 ^
  -write build\boot.prg boot ^
  -write build\cd64.prg cd64 ^
  -write build\files.prg files ^
  -write build\editor.prg editor ^
  -write build\paint.prg paint ^
  -write build\calc.prg calc ^
  -write build\setup.prg setup ^
  -write build\desktool.prg desktool ^
  -write build\inet.prg inet ^
  -write build\lower.prg lower ^
  -write build\tiny.prg tiny ^
  -write build\fremen.prg fremen ^
  -write build\serif.prg serif ^
  -write build\mono.prg mono ^
  -write build\casual.prg casual ^
  -write build\heavy.prg heavy ^
  -write build\cowboy.prg cowboy ^
  -write build\scrsaver.prg scrsaver ^
  -write build\c64city.prg c64city
if errorlevel 1 ( echo c1541 failed. & exit /b 1 )

echo [3b/3] Ook een D64 maken (1541-compatibel, zelfde bestanden)...
if exist build\CD64.d64 del build\CD64.d64
"%C1541%" -format "commodore desk,cd" d64 build\CD64.d64 ^
  -write build\boot.prg boot ^
  -write build\cd64.prg cd64 ^
  -write build\files.prg files ^
  -write build\editor.prg editor ^
  -write build\paint.prg paint ^
  -write build\calc.prg calc ^
  -write build\setup.prg setup ^
  -write build\desktool.prg desktool ^
  -write build\inet.prg inet ^
  -write build\lower.prg lower ^
  -write build\tiny.prg tiny ^
  -write build\fremen.prg fremen ^
  -write build\serif.prg serif ^
  -write build\mono.prg mono ^
  -write build\casual.prg casual ^
  -write build\heavy.prg heavy ^
  -write build\cowboy.prg cowboy ^
  -write build\scrsaver.prg scrsaver ^
  -write build\c64city.prg c64city
if errorlevel 1 ( echo c1541 D64 failed. & exit /b 1 )

echo.
echo Klaar: build\CD64.d71 en build\CD64.d64
echo Inhoud:
"%C1541%" -attach build\CD64.d71 -dir
echo.
echo Testen in VICE:
echo   "%VICE_EXE%" -autostart build\CD64.d71
echo.

:: Optioneel automatisch starten (haal de :: weg om te activeren):
:: "%VICE_EXE%" -autostart build\CD64.d71 +confirmonexit
