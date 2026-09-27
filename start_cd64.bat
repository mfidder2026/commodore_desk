@echo off
:: Commodore Desk 64 in VICE starten, met werkend netwerk (zie tools\start_cd64.ps1).
:: Gebruik: start_cd64.bat            -> build\CD64.d71
::          start_cd64.bat build\CD64.d64
set "DISK=%~1"
if "%DISK%"=="" set "DISK=build\CD64.d71"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\start_cd64.ps1" -Disk "%DISK%"
