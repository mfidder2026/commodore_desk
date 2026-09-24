@echo off
setlocal

:: Kelda - C64 Action-Adventure Build Script
:: Builds the project using Kick Assembler and starts in VICE x64sc

:: Configuration - adjust paths as needed
set "JAVA_EXE=C:\Users\aegwh\OneDrive\dev\c64\java\bin\java.exe"
set "KICKASS_JAR=C:\Users\aegwh\OneDrive\dev\c64\kick\KickAss.jar"
set "VICE_EXE=C:\Users\aegwh\OneDrive\dev\c64\vice\bin\x64sc.exe"

:: Create build directory if it doesn't exist
if not exist build mkdir build

:: Assemble the project
"C:\Users\aegwh\OneDrive\dev\c64\java\bin\java.exe" -jar "C:\Users\aegwh\OneDrive\dev\c64\kick\KickAss.jar" main.asm -o build\kelda.prg -symbolfile -vicesymbols

:: Check if assembly succeeded
if errorlevel 1 (
    echo Build failed. Check Kick Assembler output for errors.
    exit /b 1
)

:: Start the program in VICE
echo To run the program, start VICE and type:
 echo LOAD"KELDA",8,1
 echo SYS 2061
 echo.
 echo Alternatively, use:
 echo "%VICE_EXE%" build\kelda.prg +confirmonexit

:: Alternative: Start in warp mode for faster testing
:: "%VICE_EXE%" -autostart build\kelda.prg -warp +confirmonexit