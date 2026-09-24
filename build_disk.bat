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

echo [2/3] Assembleren (PRG)...
"%JAVA_EXE%" -jar "%KICKASS_JAR%" disk_main.asm -o build\cd64.prg -vicesymbols -odir build
if errorlevel 1 ( echo Build failed. & exit /b 1 )

echo [3/3] D71 maken en PRG erop schrijven...
if exist build\CD64.d71 del build\CD64.d71
"%C1541%" -format "commodore desk,cd" d71 build\CD64.d71 -write build\cd64.prg cd64
if errorlevel 1 ( echo c1541 failed. & exit /b 1 )

echo.
echo Klaar: build\CD64.d71
echo Inhoud:
"%C1541%" -attach build\CD64.d71 -dir
echo.
echo Testen in VICE:
echo   "%VICE_EXE%" -autostart build\CD64.d71
echo.

:: Optioneel automatisch starten (haal de :: weg om te activeren):
:: "%VICE_EXE%" -autostart build\CD64.d71 +confirmonexit
