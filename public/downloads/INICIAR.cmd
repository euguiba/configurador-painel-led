@echo off
setlocal EnableDelayedExpansion
title GLOBAL LED EXPERIENCE - Configurador de Notebook
cd /d "%~dp0"

:: =====================================================================
::  INICIAR.cmd - unico arquivo de inicializacao do pendrive
::  1) Configurar este notebook (abre a interface como administrador)
::  2) Pular a configuracao inicial do Windows 11 (OOBE)
:: =====================================================================

set "raiz=%~dp0"
set "script=%raiz%ConfiguradorPainelLED.ps1"

if exist "%script%" goto :temScript

echo  Procurando a particao do pendrive com o configurador...
for %%D in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist "%%D:\ConfiguradorPainelLED.ps1" (
        set "raiz=%%D:\"
        set "script=%%D:\ConfiguradorPainelLED.ps1"
        goto :temScript
    )
)

echo.
echo  Nao encontrei o arquivo ConfiguradorPainelLED.ps1.
echo  Extraia o kit ZIP na RAIZ do pendrive e abra o INICIAR.cmd
echo  que fica na mesma pasta do ConfiguradorPainelLED.ps1.
echo.
pause
exit /b 1

:temScript
if "%~1"=="1" goto :configurar
cls
echo.
echo  ==================================================
echo   GLOBAL LED EXPERIENCE - CONFIGURADOR DE NOTEBOOK
echo  ==================================================
echo.
echo   Configurador encontrado em: %raiz%
echo.
echo   [1] Configurar este notebook  (padrao)
echo   [2] Pular a configuracao inicial do Windows (OOBE)
echo   [3] Copiar para este notebook e liberar o pendrive (modo portatil)
echo.
choice /C 123 /T 8 /D 1 /N /M "  Escolha (1, 2 ou 3), inicia sozinho em 8s: "
if errorlevel 3 goto :portatil
if errorlevel 2 goto :oobe
goto :configurar

:portatil
set "local=C:\ConfiguradorLED"
echo.
echo  Copiando o configurador e os instaladores para %local% ...
robocopy "%raiz%." "%local%" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /XD "System Volume Information" "$RECYCLE.BIN" "Backups" >nul
if not exist "%local%\ConfiguradorPainelLED.ps1" (
  echo  Falha ao copiar. Verifique o espaco em disco e tente de novo.
  pause
  exit /b 1
)
if not exist "%local%\Backups" mkdir "%local%\Backups" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=(New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop')+'\Configurador Global LED.lnk'); $s.TargetPath='%local%\INICIAR.cmd'; $s.WorkingDirectory='%local%'; $s.Save()" >nul 2>&1
echo.
echo  ==================================================
echo   PRONTO! JA PODE TIRAR O PENDRIVE E LEVAR PARA
echo   O PROXIMO NOTEBOOK.
echo  ==================================================
echo  Este notebook continua a configuracao a partir de
echo  %local% (atalho criado na area de trabalho).
echo.
timeout /t 6 /nobreak >nul
start "" "%local%\INICIAR.cmd" 1
exit /b 0

:oobe
echo.
echo  ==================================================
echo   PULAR A CONFIGURACAO INICIAL DO WINDOWS 11
echo  ==================================================
echo.
echo  Gravando o arquivo de resposta do Windows (conta Global)...
if not exist "C:\Windows\Panther" mkdir "C:\Windows\Panther" >nul 2>&1
set "b64=PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4KPHVuYXR0ZW5kIHhtbG5zPSJ1cm46c2NoZW1hcy1taWNyb3NvZnQtY29tOnVuYXR0ZW5kIj4KICA8c2V0dGluZ3MgcGFzcz0ib29iZVN5c3RlbSI+CiAgICA8Y29tcG9uZW50IG5hbWU9Ik1pY3Jvc29mdC1XaW5kb3dzLVNoZWxsLVNldHVwIiBwcm9jZXNzb3JBcmNoaXRlY3R1cmU9ImFtZDY0IiBwdWJsaWNLZXlUb2tlbj0iMzFiZjM4NTZhZDM2NGUzNSIgbGFuZ3VhZ2U9Im5ldXRyYWwiIHZlcnNpb25TY29wZT0ibm9uU3hTIiB4bWxuczp3Y209Imh0dHA6Ly9zY2hlbWFzLm1pY3Jvc29mdC5jb20vV01JQ29uZmlnLzIwMDIvU3RhdGUiPgogICAgICA8T09CRT4KICAgICAgICA8SGlkZUVVTEFQYWdlPnRydWU8L0hpZGVFVUxBUGFnZT4KICAgICAgICA8SGlkZU9FTVJlZ2lzdHJhdGlvblNjcmVlbj50cnVlPC9IaWRlT0VNUmVnaXN0cmF0aW9uU2NyZWVuPgogICAgICAgIDxIaWRlT25saW5lQWNjb3VudFNjcmVlbnM+dHJ1ZTwvSGlkZU9ubGluZUFjY291bnRTY3JlZW5zPgogICAgICAgIDxIaWRlTG9jYWxBY2NvdW50U2NyZWVuPnRydWU8L0hpZGVMb2NhbEFjY291bnRTY3JlZW4+CiAgICAgICAgPEhpZGVXaXJlbGVzc1NldHVwSW5PT0JFPnRydWU8L0hpZGVXaXJlbGVzc1NldHVwSW5PT0JFPgogICAgICAgIDxQcm90ZWN0WW91clBDPjM8L1Byb3RlY3RZb3VyUEM+CiAgICAgICAgPFNraXBNYWNoaW5lT09CRT50cnVlPC9Ta2lwTWFjaGluZU9PQkU+CiAgICAgICAgPFNraXBVc2VyT09CRT50cnVlPC9Ta2lwVXNlck9PQkU+CiAgICAgIDwvT09CRT4KICAgICAgPFVzZXJBY2NvdW50cz4KICAgICAgICA8TG9jYWxBY2NvdW50cz4KICAgICAgICAgIDxMb2NhbEFjY291bnQgd2NtOmFjdGlvbj0iYWRkIj4KICAgICAgICAgICAgPE5hbWU+R2xvYmFsPC9OYW1lPgogICAgICAgICAgICA8R3JvdXA+QWRtaW5pc3RyYXRvcnM8L0dyb3VwPgogICAgICAgICAgICA8RGlzcGxheU5hbWU+R2xvYmFsPC9EaXNwbGF5TmFtZT4KICAgICAgICAgICAgPERlc2NyaXB0aW9uPkNvbnRhIGxvY2FsIGRvIHBhaW5lbCBkZSBMRUQ8L0Rlc2NyaXB0aW9uPgogICAgICAgICAgICA8UGFzc3dvcmQ+CiAgICAgICAgICAgICAgPFZhbHVlPjwvVmFsdWU+CiAgICAgICAgICAgICAgPFBsYWluVGV4dD50cnVlPC9QbGFpblRleHQ+CiAgICAgICAgICAgIDwvUGFzc3dvcmQ+CiAgICAgICAgICA8L0xvY2FsQWNjb3VudD4KICAgICAgICA8L0xvY2FsQWNjb3VudHM+CiAgICAgIDwvVXNlckFjY291bnRzPgogICAgICA8QXV0b0xvZ29uPgogICAgICAgIDxFbmFibGVkPnRydWU8L0VuYWJsZWQ+CiAgICAgICAgPFVzZXJuYW1lPkdsb2JhbDwvVXNlcm5hbWU+CiAgICAgICAgPExvZ29uQ291bnQ+OTwvTG9nb25Db3VudD4KICAgICAgICA8UGFzc3dvcmQ+CiAgICAgICAgICA8VmFsdWU+PC9WYWx1ZT4KICAgICAgICAgIDxQbGFpblRleHQ+dHJ1ZTwvUGxhaW5UZXh0PgogICAgICAgIDwvUGFzc3dvcmQ+CiAgICAgIDwvQXV0b0xvZ29uPgogICAgICA8VGltZVpvbmU+RS4gU291dGggQW1lcmljYSBTdGFuZGFyZCBUaW1lPC9UaW1lWm9uZT4KICAgIDwvY29tcG9uZW50PgogIDwvc2V0dGluZ3M+CjwvdW5hdHRlbmQ+Cg=="
powershell -NoProfile -ExecutionPolicy Bypass -Command "$b=[Convert]::FromBase64String($env:b64); [IO.File]::WriteAllBytes('C:\Windows\Panther\unattend.xml',$b); [IO.File]::WriteAllBytes('C:\Windows\System32\Sysprep\unattend.xml',$b)" >nul 2>&1

if not exist "C:\Windows\Panther\unattend.xml" goto :oobeManual

echo  Apontando o Windows para esse arquivo de resposta...
reg add "HKLM\SYSTEM\Setup" /v UnattendFile /t REG_SZ /d "C:\Windows\Panther\unattend.xml" /f >nul 2>&1

echo  Criando a conta local "Global" (administrador, sem senha)...
net user Global /add >nul 2>&1
net user Global /active:yes >nul 2>&1
net localgroup Administradores Global /add >nul 2>&1
net localgroup Administrators Global /add >nul 2>&1
wmic useraccount where "name='Global'" set PasswordExpires=false >nul 2>&1

echo  Ligando o logon automatico da conta Global...
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultUserName /t REG_SZ /d Global /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword /t REG_SZ /d "" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultDomainName /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LimitBlankPasswordUse /t REG_DWORD /d 0 /f >nul 2>&1

echo  Desligando as telas restantes de configuracao...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v SkipMachineOOBE /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v SkipUserOOBE /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v LaunchUserOOBE /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v DisableVoice /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE" /v DisablePrivacyExperience /t REG_DWORD /d 1 /f >nul 2>&1

:: Perfil padrao (vale para a conta Global no primeiro logon)
reg load HKU\GLOBAL_DEFAULT "C:\Users\Default\NTUSER.DAT" >nul 2>&1
for %%K in (GLOBAL_DEFAULT .DEFAULT) do (
    reg add "HKU\%%K\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKU\%%K\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKU\%%K\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v ScoobeSystemSettingEnabled /t REG_DWORD /d 0 /f >nul 2>&1
    reg add "HKU\%%K\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f >nul 2>&1
)
reg unload HKU\GLOBAL_DEFAULT >nul 2>&1

echo  Marcando a configuracao inicial como concluida...
reg add "HKLM\SYSTEM\Setup" /v SetupType /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\Setup" /v SystemSetupInProgress /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\Setup" /v OOBEInProgress /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\Setup" /v CmdLine /t REG_SZ /d "" /f >nul 2>&1
reg add "HKLM\SYSTEM\Setup\Status\ChildCompletion" /v setup.exe /t REG_DWORD /d 3 /f >nul 2>&1
reg add "HKLM\SYSTEM\Setup\Status\SysprepStatus" /v GeneralizationState /t REG_DWORD /d 7 /f >nul 2>&1
reg add "HKLM\SYSTEM\Setup\Status\SysprepStatus" /v CleanupState /t REG_DWORD /d 2 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\OOBE" /v UnattendCreatedUser /t REG_DWORD /d 1 /f >nul 2>&1

echo.
echo  Tudo pronto. O notebook vai reiniciar e entrar direto na area
echo  de trabalho da conta Global (sem senha, sem perguntas).
echo.
timeout /t 5 /nobreak >nul
shutdown /r /t 0
exit /b 0


:oobeManual
echo.
echo  Nao consegui criar a conta local neste estagio do Windows.
echo  Aplicando o modo de configuracao com conta local...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE" /v DisablePrivacyExperience /t REG_DWORD /d 1 /f >nul 2>&1
start "" ms-cxh:localonly
echo.
echo  Se abriu a tela de criacao de usuario, use o nome Global (sem senha),
echo  conclua nela e depois volte a abrir este INICIAR.cmd na opcao 1.
echo.
echo  Se nada abriu, pressione R para reiniciar. Depois do reinicio
echo  escolha "Nao tenho internet" e "Continuar limitado".
echo.
choice /C RS /N /M "  [R] Reiniciar  [S] Sair: "
if errorlevel 2 exit /b 0
shutdown /r /t 3 /c "Reiniciando para liberar a configuracao local do Windows"
exit /b 0


:configurar
echo.
echo  Liberando os arquivos do pendrive...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -LiteralPath '%raiz%' -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue"
echo  Abrindo o tutorial no navegador...
start "" "https://confignote-automatico.lovable.app"
echo  Abrindo a interface... aceite o aviso do Windows clicando em SIM.
echo.
cd /d "%raiz%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList '-NoProfile -ExecutionPolicy Bypass -STA -File \"%script%\"'"
if errorlevel 1 (
  echo.
  echo  Houve um erro ao abrir. Tire um print desta tela e avise o suporte.
  pause
)
exit /b 0
