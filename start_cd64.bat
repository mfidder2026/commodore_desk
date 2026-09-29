@echo off
:: Commodore Desk 64 in VICE starten, met werkend netwerk (zie tools\start_cd64.ps1).
:: Gebruik: start_cd64.bat            -> build\CD64.d81 (alles), anders de D71
::          start_cd64.bat build\CD64.d71
set "DISK=%~1"
if "%DISK%"=="" set "DISK=build\CD64.d71"
if "%~1"=="" if exist build\CD64.d81 set "DISK=build\CD64.d81"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\start_cd64.ps1" -Disk "%DISK%"
