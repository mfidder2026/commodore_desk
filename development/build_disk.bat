@echo off
setlocal
:: ======================================================
:: Commodore Desk 64 - disk build
:: Assembleert disk_main.asm -> build\cd64.prg en zet alles op
::   build\CD64.d81  1581 (800 KB): ALLES, ook de echte spellen en de SID's
::   build\CD64.d71  1571 (340 KB): het systeem, spellen als plaatsvervanger
::   build\CD64.d64  1541 (170 KB): het systeem, extra's alleen als ze passen
:: Mappen naast deze repo (buiten git):
::   ..\userfiles  instellingen van de gebruiker (ook het mailwachtwoord!)
::   ..\parked     de echte spellen (C64 CITY, POKEMON RED): van derden
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
python tools\make_geosicons.py
if errorlevel 1 ( echo GEOSICON mislukt. & exit /b 1 )
"%JAVA_EXE%" -jar "%KICKASS_JAR%" boot_main.asm -o build\boot.prg -odir build
if errorlevel 1 ( echo Boot build failed. & exit /b 1 )
:: Plaatsvervangers voor de spellen (de echte staan in ..\parked)
"%JAVA_EXE%" -jar "%KICKASS_JAR%" dummy_main.asm ":name=C64 CITY" -o build\c64cdesk.prg -odir build
if errorlevel 1 ( echo Dummy build failed. & exit /b 1 )
"%JAVA_EXE%" -jar "%KICKASS_JAR%" dummy_main.asm ":name=POKEMON RED" -o build\c64rdesk.prg -odir build
if errorlevel 1 ( echo Dummy build failed. & exit /b 1 )

:: Gebruikersbestanden (instellingen, ook het mailwachtwoord!) gaan niet
:: verloren: ze worden van de oude disk naar ..\userfiles gekopieerd
:: (buiten de repo, nooit committen) en na het formatteren teruggezet.
:: De disk waarmee het laatst gewerkt is (D81, D71 of D64) gaat voor.
set "KEEP=%~dp0..\userfiles"
set "PARKED=%~dp0..\parked"
set "USERFILES=mail.cfg net.cfg bbs.cfg bbs.book cd64.cfg desk.apps"
if not exist "%KEEP%" mkdir "%KEEP%"
set "DISKS="
for /f "delims=" %%D in ('python tools\disks_by_age.py build') do call set "DISKS=%%DISKS%% %%D"
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
  -write build\geosicon.prg geosicon ^
  -write build\lower.prg lower ^
  -write build\tiny.prg tiny ^
  -write build\fremen.prg fremen ^
  -write build\serif.prg serif ^
  -write build\mono.prg mono ^
  -write build\casual.prg casual ^
  -write build\heavy.prg heavy ^
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
  -write build\geosicon.prg geosicon ^
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
python tools\disk_add.py "%C1541%" build\CD64.d64 10 build\scrsaver.prg sid\*.sid build\c64cdesk.prg build\c64rdesk.prg

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
echo [4/3] D81 maken: alles bij elkaar (1581, 3160 blokken)...
:: de echte spellen uit %PARKED% als ze er zijn, anders de plaatsvervangers
set "GAME_C=build\c64cdesk.prg"
set "GAME_R=build\c64rdesk.prg"
if exist "%PARKED%\c64cdesk.prg" set "GAME_C=%PARKED%\c64cdesk.prg"
if exist "%PARKED%\c64rdesk.prg" set "GAME_R=%PARKED%\c64rdesk.prg"
if exist build\CD64.d81 del build\CD64.d81
"%C1541%" -format "commodore desk,cd" d81 build\CD64.d81 ^
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
  -write build\geosicon.prg geosicon ^
  -write build\lower.prg lower ^
  -write build\tiny.prg tiny ^
  -write build\fremen.prg fremen ^
  -write build\serif.prg serif ^
  -write build\mono.prg mono ^
  -write build\casual.prg casual ^
  -write build\heavy.prg heavy ^
  -write build\scrsaver.prg scrsaver ^
  -write "%GAME_C%" c64cdesk ^
  -write "%GAME_R%" c64rdesk
if errorlevel 1 ( echo c1541 D81 failed. & exit /b 1 )
echo   spellen: %GAME_C% en %GAME_R%
if exist sid\*.sid (
  for %%S in (sid\*.sid) do "%C1541%" -attach build\CD64.d81 -write "%%S" %%~nxS >nul 2>&1
)
for %%U in (%USERFILES%) do (
  if exist "%KEEP%\%%U" "%C1541%" -attach build\CD64.d81 -write "%KEEP%\%%U" %%U >nul 2>&1
)
"%C1541%" -attach build\CD64.d81 -write "%RLST%" "radio.lst,s" >nul 2>&1

echo Klaar: build\CD64.d81, build\CD64.d71 en build\CD64.d64
echo Inhoud van de D81:
"%C1541%" -attach build\CD64.d81 -dir
echo.
echo Testen in VICE:
echo   start_cd64.bat build\CD64.d81
echo.

:: Optioneel automatisch starten (haal de :: weg om te activeren):
:: "%VICE_EXE%" -autostart build\CD64.d71 +confirmonexit

goto :eof

:: keepfile <naam> - bestand van de oude disks (de laatst gebruikte eerst,
:: zie tools\disks_by_age.py) naar %KEEP%. Alleen als het echt op een disk
:: staat; anders blijft de bewaarde kopie.
:keepfile
set "FOUND="
for %%D in (%DISKS%) do if not defined FOUND call :keepfrom %%D %1
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
