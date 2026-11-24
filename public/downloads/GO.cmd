@echo off
setlocal EnableDelayedExpansion
title GLOBAL LED - MODO AUTOMATICO
cd /d "%~dp0"

:: =====================================================================
::  GO.cmd - MODO AUTOMATICO (v3.8.0)
::  Notebook novo: na tela inicial do Windows aperte SHIFT+F10 e digite
::      D:\GO        (troque D pela letra do pendrive, se for outra)
::  Notebook ja na area de trabalho: dois cliques neste arquivo.
::  Depois da mensagem "PODE TIRAR O PENDRIVE", nao precisa mexer em mais
::  nada: o notebook configura, instala os programas, reinicia e mostra
::  uma tela VERDE (concluido) ou VERMELHA (verificar).
:: =====================================================================

set "raiz=%~dp0"
if not exist "%raiz%ConfiguradorPainelLED.ps1" (
    for %%D in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
        if exist "%%D:\ConfiguradorPainelLED.ps1" set "raiz=%%D:\"
    )
)
if not exist "%raiz%ConfiguradorPainelLED.ps1" (
    echo  Nao encontrei o ConfiguradorPainelLED.ps1 ao lado deste arquivo.
    pause
    exit /b 1
)

:: Precisa de administrador (na tela inicial do Windows ja e)
net session >nul 2>&1
if errorlevel 1 (
    echo  Pedindo permissao de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)

set "local=C:\ConfiguradorLED"
echo.
echo  Copiando o kit e os instaladores para %local% ...
robocopy "%raiz%." "%local%" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /XD "System Volume Information" "$RECYCLE.BIN" "Backups" "Inventario" >nul
if not exist "%local%\ConfiguradorPainelLED.ps1" (
    echo  Falha ao copiar para o disco C:. Verifique o espaco livre.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%local%' -Recurse -File | Unblock-File" >nul 2>&1

echo  Preparando o modo automatico (Wi-Fi e proximas etapas)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%local%\ConfiguradorPainelLED.ps1" -Automatico -Etapa Preparar
:: 10 = o script detectou a tela inicial do Windows (varios sinais, nao so um)
set "etapa=%errorlevel%"

color 2F
echo.
echo  ==================================================
echo        PODE TIRAR O PENDRIVE E LEVAR PARA O
echo              PROXIMO NOTEBOOK.
echo  ==================================================
echo.

:: Esta na tela inicial do Windows (OOBE)?
if "%etapa%"=="10" (
    echo  Pulando a configuracao inicial do Windows e reiniciando...
    timeout /t 5 /nobreak >nul
    call "%local%\INICIAR.cmd" 2
    exit /b 0
)

echo  Comecando a configuracao neste notebook...
timeout /t 5 /nobreak >nul
start "GLOBAL LED - CONFIGURANDO" powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%local%\ConfiguradorPainelLED.ps1" -Automatico -Etapa Configurar
exit /b 0
