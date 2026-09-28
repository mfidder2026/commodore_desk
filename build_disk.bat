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
python tools\export_core_syms.py
if errorlevel 1 ( echo Core-symbolen mislukt. & exit /b 1 )
python tools\make_help.py
if errorlevel 1 ( echo Helpteksten mislukt. & exit /b 1 )
if errorlevel 1 ( echo Core-symbolen mislukt. & exit /b 1 )
"%JAVA_EXE%" -jar "%KICKASS_JAR%" bbs_main.asm -odir build
if errorlevel 1 ( echo BBS build failed. & exit /b 1 )
"%JAVA_EXE%" -jar "%KICKASS_JAR%" email_main.asm -odir build
if errorlevel 1 ( echo EMAIL build failed. & exit /b 1 )
"%JAVA_EXE%" -jar "%KICKASS_JAR%" time_main.asm -odir build
if errorlevel 1 ( echo TIME build failed. & exit /b 1 )
"%JAVA_EXE%" -jar "%KICKASS_JAR%" radio_main.asm -odir build
if errorlevel 1 ( echo RADIO build failed. & exit /b 1 )
python tools\make_radio_seq.py
if errorlevel 1 ( echo RADIO.LST mislukt. & exit /b 1 )
"%JAVA_EXE%" -jar "%KICKASS_JAR%" boot_main.asm -o build\boot.prg -odir build
if errorlevel 1 ( echo Boot build failed. & exit /b 1 )
"%JAVA_EXE%" -jar "%KICKASS_JAR%" cowboy_main.asm -o build\cowboy.prg -odir build
if errorlevel 1 ( echo Cowboy build failed. & exit /b 1 )
:: Plaatsvervangers voor de spellen (de echte staan in ..\cd64_parked)
"%JAVA_EXE%" -jar "%KICKASS_JAR%" dummy_main.asm ":name=C64 CITY" -o build\c64cdesk.prg -odir build
if errorlevel 1 ( echo Dummy build failed. & exit /b 1 )
"%JAVA_EXE%" -jar "%KICKASS_JAR%" dummy_main.asm ":name=POKEMON RED" -o build\c64rdesk.prg -odir build
if errorlevel 1 ( echo Dummy build failed. & exit /b 1 )

:: Gebruikersbestanden (instellingen, ook het mailwachtwoord!) gaan niet
:: verloren: ze worden van de oude disk naar ..\cd64_userfiles gekopieerd
:: (buiten de repo, nooit committen) en na het formatteren teruggezet.
set "KEEP=%~dp0..\cd64_userfiles"
set "USERFILES=mail.cfg net.cfg bbs.cfg bbs.book cd64.cfg desk.apps"
if not exist "%KEEP%" mkdir "%KEEP%"
for %%U in (%USERFILES%) do call :keepfile %%U
:: RADIO.LST (de afspeellijst, ook te bewerken) blijft ook bewaard
call :keepfile radio.lst

echo [3/3] D71 maken en PRG's erop schrijven (BOOT start eerst)...
if exist build\CD64.d71 del build\CD64.d71
"%C1541%" -format "commodore desk,cd" d71 build\CD64.d71 ^
  -write build\boot.prg boot ^
  -write build\cd64.prg cd64 ^
  -write build\helptext.prg helptext ^
  -write build\files.prg files ^
  -write build\editor.prg editor ^
  -write build\paint.prg paint ^
  -write build\calc.prg calc ^
  -write build\setup.prg setup ^
  -write build\desktool.prg desktool ^
  -write build\sidplay.prg sidplay ^
  -write build\inet.prg inet ^
  -write build\bbs.prg bbs ^
  -write build\email.prg email ^
  -write build\time.prg time ^
  -write build\radio.prg radio ^
  -write build\lower.prg lower ^
  -write build\tiny.prg tiny ^
  -write build\fremen.prg fremen ^
  -write build\serif.prg serif ^
  -write build\mono.prg mono ^
  -write build\casual.prg casual ^
  -write build\heavy.prg heavy ^
  -write build\cowboy.prg cowboy ^
  -write build\scrsaver.prg scrsaver ^
  -write build\c64cdesk.prg c64cdesk ^
  -write build\c64rdesk.prg c64rdesk
if errorlevel 1 ( echo c1541 failed. & exit /b 1 )

echo [3b/3] Ook een D64 maken (1541-compatibel, zelfde bestanden)...
if exist build\CD64.d64 del build\CD64.d64
"%C1541%" -format "commodore desk,cd" d64 build\CD64.d64 ^
  -write build\boot.prg boot ^
  -write build\cd64.prg cd64 ^
  -write build\helptext.prg helptext ^
  -write build\files.prg files ^
  -write build\editor.prg editor ^
  -write build\paint.prg paint ^
  -write build\calc.prg calc ^
  -write build\setup.prg setup ^
  -write build\desktool.prg desktool ^
  -write build\sidplay.prg sidplay ^
  -write build\inet.prg inet ^
  -write build\bbs.prg bbs ^
  -write build\email.prg email ^
  -write build\time.prg time ^
  -write build\radio.prg radio ^
  -write build\lower.prg lower ^
  -write build\tiny.prg tiny ^
  -write build\fremen.prg fremen ^
  -write build\serif.prg serif ^
  -write build\mono.prg mono ^
  -write build\casual.prg casual ^
  -write build\heavy.prg heavy
if errorlevel 1 ( echo c1541 D64 failed. & exit /b 1 )
:: Extra's (programma's van derden, SID-tunes) alleen als ze passen; er
:: blijven 10 blokken vrij voor de instellingen van de gebruiker.
echo D64-extra's:
python tools\disk_add.py "%C1541%" build\CD64.d64 10 build\cowboy.prg build\scrsaver.prg sid\*.sid build\c64cdesk.prg build\c64rdesk.prg

:: SID-tunes: alle .sid-bestanden uit de map sid\ (niet in git: muziek
:: van derden) op de D71; op de D64 via disk_add.py (als ze passen).
if exist sid\*.sid (
  echo SID-tunes uit sid\ op de D71 ...
  for %%S in (sid\*.sid) do (
    "%C1541%" -attach build\CD64.d71 -write "%%S" %%~nxS >nul 2>&1
    echo   %%~nxS
  )
)

echo Gebruikersbestanden terugzetten uit %KEEP% ...
for %%U in (%USERFILES%) do (
  if exist "%KEEP%\%%U" (
    "%C1541%" -attach build\CD64.d71 -write "%KEEP%\%%U" %%U >nul 2>&1
    "%C1541%" -attach build\CD64.d64 -write "%KEEP%\%%U" %%U >nul 2>&1
    echo   %%U
  )
)

:: RADIO.LST als SEQ: de eigen versie als die er is, anders de standaardlijst
set "RLST=build\radio.lst"
if exist "%KEEP%\radio.lst" set "RLST=%KEEP%\radio.lst"
"%C1541%" -attach build\CD64.d71 -write "%RLST%" "radio.lst,s" >nul 2>&1
"%C1541%" -attach build\CD64.d64 -write "%RLST%" "radio.lst,s" >nul 2>&1
echo   radio.lst (%RLST%)
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

goto :eof

:: keepfile <naam> - bestand van de oude D71 (anders de D64) naar %KEEP%.
:: Alleen als het echt op de disk staat; anders blijft de bewaarde kopie.
:keepfile
set "FOUND="
if exist build\CD64.d71 call :keepfrom build\CD64.d71 %1
if not defined FOUND if exist build\CD64.d64 call :keepfrom build\CD64.d64 %1
goto :eof

:keepfrom
if exist "%KEEP%\%2.new" del "%KEEP%\%2.new"
"%C1541%" -attach %1 -read %2 "%KEEP%\%2.new" >nul 2>&1
if not exist "%KEEP%\%2.new" goto :eof
for %%S in ("%KEEP%\%2.new") do if %%~zS GTR 0 (
  move /y "%KEEP%\%2.new" "%KEEP%\%2" >nul
  set "FOUND=1"
) else (
  del "%KEEP%\%2.new"
)
goto :eof
