@echo off
cd "%~dp0"
powershell -executionpolicy bypass -File "reset.ps1"
pause
