@echo off
setlocal EnableDelayedExpansion
cls
title GLOBAL LED - Localizando configurador...

:: =====================================================
::  VTOYEFI - Lançador para partição grande do Ventoy
::  Este arquivo fica na partição CD do pendrive (VTOYEFI).
::  Ele procura a partição grande do Ventoy que contem o
::  ConfiguradorPainelLED.ps1 e executa o Iniciar.bat dela.
:: =====================================================

set "modo=%~1"
set "unidadeEncontrada="

:: Procura em todas as unidades de disco pelo marcador do configurador.
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\ConfiguradorPainelLED.ps1" (
        set "unidadeEncontrada=%%D:"
        goto :achou
    )
)

:naoachou
echo.
echo  ==================================================
echo   GLOBAL LED - CONFIGURADOR NAO ENCONTRADO
echo  ==================================================
echo.
echo  Nao encontrei a particao grande do pendrive com o
echo  arquivo ConfiguradorPainelLED.ps1.
echo.
echo  Possiveis causas:
echo  - O pendrive foi preparado sem o Ventoy.
echo  - Os arquivos do configurador nao estao na raiz da particao grande.
echo  - A letra da unidade ainda nao foi atribuida (aguarde 5 segundos e tente de novo).
echo.
echo  Solucao manual: abra a pasta do pendrive e de dois cliques em Iniciar.bat.
echo.
pause
exit /b 1

:achou
echo.
echo  ==================================================
echo   GLOBAL LED - CONFIGURADOR ENCONTRADO (%unidadeEncontrada%)
echo  ==================================================
echo.

if /I "%modo%"=="tutorial" (
    echo  Abrindo apenas o tutorial no navegador...
    start "" "https://confignote-automatico.lovable.app"
    exit /b 0
)

echo  Abrindo o INICIAR.cmd da particao grande do pendrive...
cd /d "%unidadeEncontrada%\"
if exist "%unidadeEncontrada%\INICIAR.cmd" (
    call "%unidadeEncontrada%\INICIAR.cmd"
    exit /b 0
)
start "" "https://confignote-automatico.lovable.app"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Path '%unidadeEncontrada%\' -Recurse -File | Unblock-File -ErrorAction SilentlyContinue"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%unidadeEncontrada%\ConfiguradorPainelLED.ps1"
if errorlevel 1 (
    echo.
    echo  Houve um erro ao abrir. Tire um print desta tela e avise o suporte.
    pause
)
exit /b 0
