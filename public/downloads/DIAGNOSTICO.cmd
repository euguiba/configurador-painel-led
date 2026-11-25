@echo off
title DIAGNOSTICO - pendrive de TESTE
net session >nul 2>&1
if errorlevel 1 (
    powershell -NoProfile -Command "Start-Process -FilePath %~f0 -Verb RunAs"
    exit /b 0
)
echo.
echo  Juntando as informacoes do modo automatico (nao altera nada)...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_sistema\diagnostico.ps1"
echo.
echo  ==================================================
echo   PRONTO. Pode tirar o pendrive e levar de volta.
echo  ==================================================
pause
