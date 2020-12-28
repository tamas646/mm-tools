@echo off
cd "%~dp0"
powershell -executionpolicy bypass -File "migrate.ps1"
pause
