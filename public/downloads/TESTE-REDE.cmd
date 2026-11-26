@echo off
rem Somente pendrive TESTE: liga (ou desliga) o acesso pelo cabo de rede.
rem   TESTE-REDE.cmd           liga
rem   TESTE-REDE.cmd desligar  desliga
net session >nul 2>&1
if errorlevel 1 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '%~1' -Verb RunAs"
  exit /b
)
if /i "%~1"=="desligar" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_sistema\rede-teste.ps1" -Desligar
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_sistema\rede-teste.ps1"
)
pause
