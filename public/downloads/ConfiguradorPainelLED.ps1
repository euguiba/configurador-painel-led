<#
=====================================================================
 CONFIGURADOR DE NOTEBOOK - PAINEIS DE LED
 Interface grafica (WPF) para padronizar notebooks de instalacao.
 Windows 10/11 - PowerShell 5.1+
 Execute pelo atalho "Iniciar.bat" (ja abre como Administrador).
=====================================================================
#>

# ---------- AUTO ELEVACAO ----------
$ErrorActionPreference = 'SilentlyContinue'
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList @(
        '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""
    )
    exit
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ---------- HELPERS ----------
# Hives de usuario onde as configuracoes HKCU serao gravadas.
# Alem do usuario atual, gravamos no perfil padrao (Default), para que
# qualquer usuario novo ja nasca configurado.
$script:HivesUsuario = @('HKCU:')
$script:HivesCarregados = @()

function Get-CaminhosUsuario {
    param([string]$Path)
    if ($Path -notmatch '^HKCU:') { return ,$Path }
    $sub = $Path -replace '^HKCU:\\?',''
    $lista = @()
    foreach ($h in $script:HivesUsuario) {
        if ($h -eq 'HKCU:') { $lista += "HKCU:\$sub" } else { $lista += "$h\$sub" }
    }
    return $lista
}

function Set-Reg {
    param([string]$Path,[string]$Name,$Value,[string]$Type = 'DWord')
    foreach ($p in (Get-CaminhosUsuario $Path)) {
        if (-not (Test-Path $p)) { New-Item -Path $p -Force | Out-Null }
        New-ItemProperty -Path $p -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
    }
}

function Remove-Reg {
    param([string]$Path,[string]$Name)
    foreach ($p in (Get-CaminhosUsuario $Path)) {
        Remove-ItemProperty -Path $p -Name $Name -Force -ErrorAction SilentlyContinue
    }
}

# Cria o perfil de um usuario local sem precisar fazer logon com ele.
Add-Type -ErrorAction SilentlyContinue -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class GlobalLEDProfile {
    [DllImport("userenv.dll", CharSet = CharSet.Unicode, ExactSpelling = false, SetLastError = true)]
    public static extern int CreateProfile(string pszUserSid, string pszUserName, StringBuilder pszProfilePath, uint cchProfilePath);
}
'@

function New-PerfilUsuario {
    param([string]$Nome)
    try {
        $u = Get-LocalUser -Name $Nome -ErrorAction Stop
        $sid = $u.SID.Value
        $perfil = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { $_.SID -eq $sid }
        if ($perfil -and (Test-Path (Join-Path $perfil.LocalPath 'NTUSER.DAT'))) { return $perfil.LocalPath }
        $sb = New-Object System.Text.StringBuilder 260
        [GlobalLEDProfile]::CreateProfile($sid, $Nome, $sb, 260) | Out-Null
        Start-Sleep -Seconds 1
        $perfil = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue | Where-Object { $_.SID -eq $sid }
        if ($perfil) { return $perfil.LocalPath }
        if ($sb.Length -gt 0) { return $sb.ToString() }
    } catch { }
    return $null
}

function Open-HivesUsuario {
    $script:HivesUsuario = @('HKCU:')
    $script:HivesCarregados = @()

    if (-not (Get-PSDrive -Name HKU -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS -Scope Script | Out-Null
    }

    # A criacao de conta local foi removida: as configuracoes vao para o
    # usuario atual e para o perfil padrao do Windows.


    # Perfil padrao: qualquer usuario novo ja nasce configurado
    $datPadrao = 'C:\Users\Default\NTUSER.DAT'
    if (Test-Path $datPadrao) {
        reg load "HKU\GLOBAL_DEFAULT" "$datPadrao" 2>$null | Out-Null
        if (Test-Path 'HKU:\GLOBAL_DEFAULT') {
            $script:HivesUsuario += 'HKU:\GLOBAL_DEFAULT'
            $script:HivesCarregados += 'GLOBAL_DEFAULT'
            Write-Log 'Perfil padrao do Windows incluido (usuarios novos ja nascem configurados).' 'ok'
        }
    }
}

function Close-HivesUsuario {
    foreach ($h in $script:HivesCarregados) {
        [gc]::Collect(); [gc]::WaitForPendingFinalizers()
        Start-Sleep -Milliseconds 400
        reg unload "HKU\$h" 2>$null | Out-Null
    }
    $script:HivesCarregados = @()
    $script:HivesUsuario = @('HKCU:')
}


$script:ConsoleAdd = $null
function Write-Log {
    param([string]$Text,[string]$Level = 'info')
    $prefix = switch ($Level) {
        'ok'    { '[OK]   ' }
        'warn'  { '[!]    ' }
        'erro'  { '[ERRO] ' }
        'title' { '' }
        default { '       ' }
    }
    $line = if ($Level -eq 'title') { "=== $Text ===" } else { "$prefix$Text" }
    $hora = (Get-Date -Format 'HH:mm:ss')

    # Quando o trabalho roda na thread paralela (o normal a partir da v2.3.0),
    # a linha vai para uma fila e o console a exibe em lotes, ja colorida por
    # tipo (ok / aviso / erro). Isso mantem a janela sempre respondendo.
    if ($global:Estado -and $global:Estado.Fila) {
        $global:Estado.Fila.Enqueue("$Level`t$hora`t$line")
    } elseif ($script:ConsoleAdd) {
        & $script:ConsoleAdd $Level $hora $line
    }
    Write-Host "$hora  $line"
}


# Informa a etapa atual para a barra de progresso da interface.
function Set-Etapa {
    param([string]$Texto,[int]$Passo = -1,[string]$Grupo = '')
    if (-not $global:Estado) { return }
    if ($Texto) { $global:Estado.Texto = $Texto }
    if ($Passo -ge 0) { $global:Estado.Passo = $Passo }
    if ($Grupo) { $global:Estado.Grupo = $Grupo }
}

# Mantido por compatibilidade: com o trabalho fora da thread da tela nao e
# mais preciso devolver o controle para o WPF manualmente.
function Update-Interface { }


# ---------- 1. ENERGIA ----------
function Get-TodosPlanos {
    # GUID de todos os planos de energia existentes na maquina.
    # Guardado em cache: chamar "powercfg /list" varias vezes deixava a
    # aplicacao das configuracoes visivelmente mais lenta.
    param([switch]$Forcar)
    if ($script:CachePlanos -and -not $Forcar) { return $script:CachePlanos }
    $g = @()
    foreach ($linha in (powercfg /list)) {
        $m = [regex]::Match($linha, '([0-9a-fA-F]{8}-[0-9a-fA-F\-]{27})')
        if ($m.Success) { $g += $m.Value }
    }
    $script:CachePlanos = @($g | Select-Object -Unique)
    return $script:CachePlanos
}


function Get-PlanoAtivo {
    $l = (powercfg /getactivescheme) -join ' '
    return ([regex]::Match($l, '([0-9a-fA-F]{8}-[0-9a-fA-F\-]{27})')).Value
}

function Invoke-Energia {
    Write-Log 'ENERGIA / DESEMPENHO' 'title'
    try {
        # ---- PASSO 1: primeiro o plano de Desempenho Maximo fica ATIVO ----
        # Trocar de plano depois de ajustar os itens fazia o notebook voltar aos
        # valores de fabrica do plano novo. Por isso a ativacao vem ANTES dos
        # ajustes, e no fim tudo e conferido item a item.
        $ultimate = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
        $planoLinha = (powercfg /list | Select-String -Pattern 'Ultimate|Desempenho M' | Select-Object -First 1)
        if (-not $planoLinha) {
            # So cria o plano quando ele ainda nao existe (evita copias repetidas
            # a cada vez que o script roda no mesmo notebook).
            powercfg -duplicatescheme $ultimate 2>$null | Out-Null
            $planoLinha = (powercfg /list | Select-String -Pattern 'Ultimate|Desempenho M' | Select-Object -First 1)
        }
        if ($planoLinha) {
            $guid = ([regex]::Match($planoLinha.ToString(),'([0-9a-fA-F\-]{36})')).Value
            powercfg /setactive $guid | Out-Null
            Write-Log 'Plano de energia de Desempenho Maximo ativado.' 'ok'
        } else {
            powercfg /setactive SCHEME_MIN | Out-Null
            Write-Log 'Plano "Alto desempenho" ativado (Ultimate indisponivel).' 'warn'
        }

        # GUIDs das configuracoes
        $subBotoes  = '4f971e89-eebd-4455-a8de-9e59040e7347'
        $gTampa     = '5ca83367-6e45-459f-a27b-476b1d01c936'  # fechar a tampa
        $gBotaoPwr  = '7648efa3-dd9c-4e3e-b566-50f929386280'  # botao de energia
        $gBotaoSusp = '96996bc0-ad50-47ec-923b-6f41874dd9eb'  # botao de suspender
        $subVideo   = '7516b95f-f776-4464-8c53-06167f40cc99'
        $gVideoIdle = '3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e'  # desligar video
        $subSono    = '238c9fa8-0aad-41ed-83f4-97be242c8f20'
        $gSuspender = '29f6c1db-86da-48c5-9fdb-f2b67b1f44da'  # suspender apos
        $gHibernar  = '9d7815a6-7ee4-497e-8888-515a05f02364'  # hibernar apos
        $subDisco   = '0012ee47-9041-4b5d-9b77-535fba8b1442'
        $gDiscoIdle = '6738e2c4-e8a5-4a42-b16a-e040e769756e'
        $subUsb     = '2a737441-1930-4402-8d77-b2bebba308a3'
        $gUsbSusp   = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
        $subPcie    = '501a4d13-42af-4429-9fd1-a8218c268e20'
        $gPcie      = 'ee12f906-d277-404b-b6da-e5fa1a576df5'
        $subCpu     = '54533251-82be-4824-96c1-47b60b740d00'
        $gCpuMin    = '893dee8e-2bef-41e0-89c6-b55d0929964c'

        $itens = @(
            @($subBotoes,$gTampa,0), @($subBotoes,$gBotaoPwr,0), @($subBotoes,$gBotaoSusp,0),
            @($subVideo,$gVideoIdle,0), @($subSono,$gSuspender,0), @($subSono,$gHibernar,0),
            @($subDisco,$gDiscoIdle,0), @($subUsb,$gUsbSusp,0), @($subPcie,$gPcie,0),
            @($subCpu,$gCpuMin,100)
        )

        # Em varios notebooks a tampa e os botoes vem "escondidos" e o Windows
        # ignora o valor gravado. Isso libera os itens antes de grava-los.
        foreach ($it in $itens) {
            powercfg -attributes $it[0] $it[1] -ATTRIB_HIDE 2>$null | Out-Null
        }

        # ---- PASSO 2: grava em TODOS os planos, na tomada (AC) e na bateria (DC) ----
        $ativo = Get-PlanoAtivo
        foreach ($p in (Get-TodosPlanos -Forcar)) {
            foreach ($par in $itens) {
                powercfg /setacvalueindex $p $par[0] $par[1] $par[2] 2>$null
                powercfg /setdcvalueindex $p $par[0] $par[1] $par[2] 2>$null
            }
        }

        # ---- PASSO 3: reforca no plano ativo e confirma ----
        # /setactive no proprio plano ativo faz o Windows recarregar os valores
        # gravados (sem isso a tampa continua respondendo com o valor antigo).
        if ($ativo) {
            foreach ($par in $itens) {
                powercfg /setacvalueindex $ativo $par[0] $par[1] $par[2] 2>$null
                powercfg /setdcvalueindex $ativo $par[0] $par[1] $par[2] 2>$null
            }
            powercfg /setactive $ativo | Out-Null
        } else {
            powercfg /setactive SCHEME_CURRENT
        }

        # ---- PASSO 3b: gravar tambem como POLITICA do Windows ----
        # Valor gravado so no plano volta ao padrao depois do reinicio (o
        # gerenciador de energia do fabricante, o Windows Update e a criacao de
        # um usuario novo refazem os planos). Como politica, o Windows obedece
        # em qualquer plano, para qualquer usuario, inclusive apos reiniciar.
        $polRaiz = 'HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings'
        foreach ($par in $itens) {
            $kpol = "$polRaiz\$($par[1])"
            Set-Reg $kpol 'ACSettingIndex' $par[2]
            Set-Reg $kpol 'DCSettingIndex' $par[2]
        }
        Write-Log 'Tampa, botoes, video e suspensao gravados como politica do Windows (nao se perdem no reinicio).' 'ok'

        Write-Log 'Fechar a tampa, botao de energia e botao de suspender: NAO FAZER NADA em TODOS os planos (tomada e bateria).' 'ok'
        Write-Log 'Desligar video e suspender: NUNCA em TODOS os planos (tomada e bateria).' 'ok'
        Write-Log 'USB sem suspensao seletiva, PCIe sem economia, CPU minima em 100%.' 'ok'

        # ---- PASSO 4: conferencia no plano ativo ----
        # Le de volta o que ficou gravado. Se algum valor voltou diferente de
        # zero (tampa/botao/video/suspensao), grava de novo naquele item.
        $nomes = @{
            "$subBotoes|$gTampa"     = 'Fechar a tampa'
            "$subBotoes|$gBotaoPwr"  = 'Botao de energia'
            "$subBotoes|$gBotaoSusp" = 'Botao de suspender'
            "$subVideo|$gVideoIdle"  = 'Desligar video'
            "$subSono|$gSuspender"   = 'Suspender apos'
        }
        $falhas = @()
        foreach ($chave in $nomes.Keys) {
            $sub, $set = $chave.Split('|')
            $q = (powercfg /query $ativo $sub $set) -join "`n"
            # Funciona em qualquer idioma do Windows: pega os valores 0x... das
            # duas ultimas linhas (indice de CA e indice de CC).
            $todos = @([regex]::Matches($q, '0x([0-9a-fA-F]{8})\s*$', 'Multiline'))
            # As duas ultimas linhas sao sempre o indice de CA e o de CC.
            $vals = @($todos | Select-Object -Last 2)
            $ok = $vals.Count -gt 0
            foreach ($v in $vals) {
                if ([Convert]::ToInt64($v.Groups[1].Value, 16) -ne 0) { $ok = $false }
            }
            if (-not $ok) {
                powercfg /setacvalueindex $ativo $sub $set 0 2>$null
                powercfg /setdcvalueindex $ativo $sub $set 0 2>$null
                powercfg /setactive $ativo | Out-Null
                $falhas += $nomes[$chave]
            }
        }
        if ($falhas.Count -gt 0) {
            Write-Log ("Itens gravados de novo por seguranca: " + ($falhas -join ', ') + ".") 'warn'
        } else {
            Write-Log 'Conferido no plano ativo: tampa, botoes, video e suspensao estao em NADA A FAZER / NUNCA.' 'ok'
        }


        # Reforco pelos atalhos do powercfg no plano ativo
        powercfg /change monitor-timeout-ac 0
        powercfg /change monitor-timeout-dc 0
        powercfg /change disk-timeout-ac 0
        powercfg /change disk-timeout-dc 0
        powercfg /change standby-timeout-ac 0
        powercfg /change standby-timeout-dc 0
        powercfg /change hibernate-timeout-ac 0
        powercfg /change hibernate-timeout-dc 0

        # ---- PASSO 5: tarefa que reaplica a energia a cada inicializacao ----
        # Garantia extra: mesmo que algo mude os planos (fabricante, Windows
        # Update, novo usuario), o notebook volta sozinho para NADA A FAZER /
        # NUNCA logo depois de ligar.
        try {
            $pastaLED = 'C:\ProgramData\PainelLED'
            if (-not (Test-Path $pastaLED)) { New-Item -ItemType Directory -Path $pastaLED -Force | Out-Null }
            $linhas = @('@echo off')
            foreach ($par in $itens) {
                $linhas += "powercfg -attributes $($par[0]) $($par[1]) -ATTRIB_HIDE"
            }
            $linhas += 'for /f "tokens=4" %%G in (''powercfg /list ^| findstr /i GUID'') do ('
            foreach ($par in $itens) {
                $linhas += "  powercfg /setacvalueindex %%G $($par[0]) $($par[1]) $($par[2])"
                $linhas += "  powercfg /setdcvalueindex %%G $($par[0]) $($par[1]) $($par[2])"
            }
            $linhas += ')'
            $linhas += 'powercfg /setactive SCHEME_CURRENT'
            $linhas += 'powercfg -h off'
            $cmdFile = Join-Path $pastaLED 'reaplicar-energia.cmd'
            Set-Content -Path $cmdFile -Value ($linhas -join "`r`n") -Encoding ASCII

            $acaoE  = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/c `"$cmdFile`""
            $gatE   = New-ScheduledTaskTrigger -AtStartup
            $gatE2  = New-ScheduledTaskTrigger -AtLogOn
            $confE  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
            $prinE  = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
            Register-ScheduledTask -TaskName 'PainelLED - Reaplicar energia' -Action $acaoE -Trigger @($gatE,$gatE2) -Settings $confE -Principal $prinE -Force -ErrorAction Stop | Out-Null
            Write-Log 'Tarefa "PainelLED - Reaplicar energia" criada: reaplica os ajustes a cada inicializacao e logon.' 'ok'
        } catch {
            Write-Log "Nao foi possivel criar a tarefa de reaplicar energia: $($_.Exception.Message)" 'warn'
        }


        # Desliga hibernacao e inicializacao rapida
        powercfg -h off
        Write-Log 'Hibernacao e inicializacao rapida desativadas.' 'ok'

        # Sem bloqueio de tela / protetor de tela
        Set-Reg 'HKCU:\Control Panel\Desktop' 'ScreenSaveActive' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'ScreenSaverIsSecure' '0' 'String'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'ScreenSaveTimeOut' '0' 'String'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' 'NoLockScreen' 1
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'InactivityTimeoutSecs' 0
        Write-Log 'Protetor de tela e bloqueio automatico desativados.' 'ok'
    } catch {
        Write-Log "Falha em energia: $($_.Exception.Message)" 'erro'
    }
}

# ---------- 1b. ATUALIZACOES DO WINDOWS NA MADRUGADA ----------
function Invoke-WindowsUpdate {
    param(
        [string]$HoraInicio   = '00:30',            # inicio da busca/instalacao das atualizacoes
        [bool]$ReiniciarAposAtualizar = $true       # reinicia sozinho quando a atualizacao pedir
    )
    Write-Log 'ATUALIZACOES DO WINDOWS (MADRUGADA)' 'title'
    try {
        # Normaliza o horario escolhido na interface
        $cult = [Globalization.CultureInfo]::InvariantCulture
        try { $tIni = [datetime]::ParseExact($HoraInicio,   'HH:mm', $cult) } catch { $tIni = [datetime]::ParseExact('00:30','HH:mm',$cult) }
        $HoraInicio   = $tIni.ToString('HH:mm', $cult)
        $Hora         = $tIni.Hour

        $au = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
        $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'

        # Baixar e instalar automaticamente em horario agendado, todos os dias
        Set-Reg $au 'NoAutoUpdate' 0
        Set-Reg $au 'AUOptions' 4                      # baixar e instalar automaticamente
        Set-Reg $au 'ScheduledInstallDay' 0            # todos os dias
        Set-Reg $au 'ScheduledInstallTime' $Hora       # hora da madrugada
        Set-Reg $au 'AutomaticMaintenanceEnabled' 0    # usa o agendamento acima, nao a manutencao automatica
        Set-Reg $au 'AllowMUUpdateService' 1

        # Avisos de reinicio escondidos (quem decide o reinicio e o bloco no final desta funcao)
        Set-Reg $wu 'SetAutoRestartNotificationConfig' 1
        Set-Reg $wu 'AutoRestartNotificationSchedule' 15
        Set-Reg $wu 'SetAutoRestartNotificationDisable' 1
        Set-Reg $wu 'AutoRestartNotificationDisable' 1
        Set-Reg $wu 'SetRestartWarningSchd' 0
        Set-Reg $wu 'RestartNotificationsAllowed2' 0
        Set-Reg $wu 'SetUpdateNotificationLevel' 1
        Set-Reg $wu 'UpdateNotificationLevel' 2         # nenhuma notificacao de atualizacao na tela
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'RestartNotificationsAllowed2' 0
        Write-Log ("Atualizacoes instaladas automaticamente todo dia as {0:00}:00." -f $Hora) 'ok'

        # Manutencao automatica do Windows tambem na madrugada, podendo acordar o PC
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' 'MaintenanceDisabled' 0
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' 'Activation Boundary' '2000-01-01T00:00:00'  'String'
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' 'Random Delay' 'PT2H' 'String'
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' 'WakeUp' 1
        Write-Log 'Manutencao automatica do Windows agendada para 00:00 com janela de 2h.' 'ok'

        # Servico do Windows Update em modo automatico
        Set-Service -Name wuauserv -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue

        # Tarefa agendada: procura e instala atualizacoes no horario escolhido.
        # Sem StartWhenAvailable: se o notebook estava desligado no horario, a tarefa
        # NAO roda de dia assim que ele liga (isso deixava o notebook lento na configuracao).
        $ps ="Start-Process -FilePath `$env:SystemRoot\System32\UsoClient.exe -ArgumentList 'StartInteractiveScan' -WindowStyle Hidden; Start-Sleep -Seconds 60; Start-Process -FilePath `$env:SystemRoot\System32\UsoClient.exe -ArgumentList 'StartDownload' -WindowStyle Hidden; Start-Sleep -Seconds 900; Start-Process -FilePath `$env:SystemRoot\System32\UsoClient.exe -ArgumentList 'StartInstall' -WindowStyle Hidden"
        $acao    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -Command `"$ps`""
        $gatilho = New-ScheduledTaskTrigger -Daily -At $tIni
        $conf    = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Hours 4)
        $princ   = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        Register-ScheduledTask -TaskName 'PainelLED - Atualizacoes noturnas' -Action $acao -Trigger $gatilho -Settings $conf -Principal $princ -Force -ErrorAction Stop | Out-Null
        Write-Log "Tarefa `"PainelLED - Atualizacoes noturnas`" criada ($HoraInicio, acorda o notebook se preciso)." 'ok'

        # Primeiro trava TODO reinicio automatico (Windows e tarefas antigas do kit).
        Invoke-DesligarReinicioAuto

        if ($ReiniciarAposAtualizar) {
            # Opcional: reinicia SO de madrugada (do horario escolhido ate 06:00) e
            # SO quando o Windows Update realmente pediu. Fora dessa janela, nunca.
            $minIni = $tIni.Hour * 60 + $tIni.Minute
            $minFim = 6 * 60
            $chk  = "`$m=(Get-Date).Hour*60+(Get-Date).Minute; `$ini=$minIni; `$fim=$minFim;"
            $chk += "if(`$ini -lt `$fim){ `$ok=(`$m -ge `$ini -and `$m -lt `$fim) } else { `$ok=(`$m -ge `$ini -or `$m -lt `$fim) };"
            $chk += "if(-not `$ok){ exit };"
            $chk += "`$p=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending');"
            $chk += "`$n=`$false; foreach(`$k in `$p){ if(Test-Path `$k){ `$n=`$true } };"
            $chk += "if(`$n){ Start-Process -FilePath `$env:SystemRoot\System32\shutdown.exe -ArgumentList '/r /f /t 0' -WindowStyle Hidden }"
            $acaoR    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -Command `"$chk`""
            $gatilhoR = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(5) -RepetitionInterval (New-TimeSpan -Minutes 15)
            $confR    = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
            Register-ScheduledTask -TaskName 'PainelLED - Reinicio apos atualizacao' -Action $acaoR -Trigger $gatilhoR -Settings $confR -Principal $princ -Force -ErrorAction Stop | Out-Null
            Write-Log ("Reinicio automatico LIGADO, mas so de madrugada ({0} ate 06:00) e so se a atualizacao pedir." -f $HoraInicio) 'ok'
        }
    } catch {
        Write-Log "Falha nas atualizacoes do Windows: $($_.Exception.Message)" 'erro'
    }
}

# ---------- 1c. SEM REINICIO AUTOMATICO (v3.6.0) ----------
# Ate a v3.5.0 o kit deixava o Windows reiniciar a qualquer hora e ainda criava
# um verificador que, a cada 15 minutos E a cada boot, reiniciava o notebook se
# houvesse qualquer arquivo pendente (PendingFileRenameOperations). Isso acontece
# o tempo todo com instaladores e drivers, entao o notebook reiniciava varias
# vezes, de dia, no meio da configuracao do painel. Esta funcao desfaz tudo isso.
# Tambem e chamada pelo botao "DESLIGAR REINICIO AUTOMATICO" (sem APLICAR tudo).
function Invoke-DesligarReinicioAuto {
    Write-Log 'REINICIO AUTOMATICO DESLIGADO' 'title'
    try {
        $au = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
        $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'

        # 1) Tarefas do proprio kit que reiniciavam o notebook
        foreach ($t in @('PainelLED - Reinicio apos atualizacao','PainelLED - Reinicio noturno')) {
            if (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue) {
                Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction SilentlyContinue
                Write-Log "Tarefa `"$t`" removida." 'ok'
            }
        }

        # 2) Windows Update nunca reinicia sozinho com alguem logado
        Set-Reg $au 'NoAutoRebootWithLoggedOnUsers' 1
        Set-Reg $au 'AlwaysAutoRebootAtScheduledTime' 0

        # 3) Horario ativo das 06:00 as 00:00 (maximo de 18h): mesmo que o Windows
        #    force um reinicio, ele nao acontece durante o dia de trabalho.
        Set-Reg $wu 'SetActiveHours' 1
        Set-Reg $wu 'ActiveHoursStart' 6
        Set-Reg $wu 'ActiveHoursEnd' 0
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'ActiveHoursStart' 6
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'ActiveHoursEnd' 0

        # 4) Sem prazo que obriga o reinicio
        foreach ($n in @('SetComplianceDeadline','ConfigureDeadlineForQualityUpdates','ConfigureDeadlineForFeatureUpdates',
                         'ConfigureDeadlineGracePeriod','ConfigureDeadlineNoAutoReboot')) {
            Remove-Reg $wu $n
        }
        Set-Reg $wu 'SetAutoRestartDeadline' 0

        # 5) Tarefa de atualizacao de versoes antigas: tira o "rodar assim que ligar",
        #    que fazia a atualizacao pesada comecar de dia, logo depois do boot.
        $tAtu = Get-ScheduledTask -TaskName 'PainelLED - Atualizacoes noturnas' -ErrorAction SilentlyContinue
        if ($tAtu -and $tAtu.Settings.StartWhenAvailable) {
            $tAtu.Settings.StartWhenAvailable = $false
            $tAtu | Set-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
            Write-Log 'Atualizacao noturna nao roda mais de dia quando o notebook liga.' 'ok'
        }

        Write-Log 'O notebook so reinicia quando o tecnico mandar (botao REINICIAR PC ou menu Iniciar).' 'ok'
    } catch {
        Write-Log "Falha ao desligar o reinicio automatico: $($_.Exception.Message)" 'erro'
    }
}



# ---------- 2. NOTIFICACOES ----------
function Invoke-Notificacoes {
    Write-Log 'NOTIFICACOES' 'title'
    try {
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications' 'ToastEnabled' 0
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings' 'NOC_GLOBAL_SETTING_TOASTS_ENABLED' 0
        Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableNotificationCenter' 1
        Write-Log 'Notificacoes e central de notificacoes desativadas.' 'ok'

        # Dicas, sugestoes, conteudo em destaque e anuncios
        $cdm = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        foreach ($v in @('SubscribedContent-338389Enabled','SubscribedContent-338388Enabled',
                         'SubscribedContent-310093Enabled','SubscribedContent-353694Enabled',
                         'SubscribedContent-353696Enabled','SystemPaneSuggestionsEnabled',
                         'SoftLandingEnabled','RotatingLockScreenOverlayEnabled')) {
            Set-Reg $cdm $v 0
        }
        Write-Log 'Dicas, sugestoes e conteudo em destaque desativados.' 'ok'

        # Nao incomodar / assistente de foco sempre ligado
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings' 'NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK' 0
        # Avisos de atualizacao na tela ficam ocultos (o reinicio e controlado pelo modulo de atualizacoes)
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'SetUpdateNotificationLevel' 1
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'UpdateNotificationLevel' 1
        Write-Log 'Avisos de atualizacao na tela desativados.' 'ok'
    } catch {
        Write-Log "Falha em notificacoes: $($_.Exception.Message)" 'erro'
    }
}

# ---------- 3. BARRA DE TAREFAS / INTERFACE ----------
function Invoke-Interface {
    Write-Log 'BARRA DE TAREFAS E INTERFACE' 'title'
    try {
        $adv = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        Set-Reg $adv 'TaskbarDa' 0            # Widgets
        Set-Reg $adv 'TaskbarMn' 0            # Chat / Teams
        Set-Reg $adv 'ShowTaskViewButton' 0   # Visao de tarefas
        Set-Reg $adv 'TaskbarAl' 0            # Icones alinhados a esquerda
        Set-Reg $adv 'ShowCopilotButton' 0
        Set-Reg $adv 'TaskbarEndTask' 1
        Set-Reg $adv 'HideFileExt' 0
        Set-Reg $adv 'LaunchTo' 1             # Explorer abre em "Este Computador"
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 1  # Pesquisa como icone
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
        Write-Log 'Widgets, chat, visao de tarefas e Copilot removidos. Pesquisa mantida.' 'ok'

        # Mostrar sempre todos os icones da area de notificacao (wifi, bateria, volume)
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'EnableAutoTray' 0
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSecondsInSystemClock' 0
        Write-Log 'Icones de wifi, bateria, volume e relogio visiveis.' 'ok'

        # Limpa itens fixados na barra de tarefas (mantem Explorer/Pesquisa/Iniciar)
        $taskband = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Taskband'
        Remove-Reg $taskband 'Favorites'
        Remove-Reg $taskband 'FavoritesResolve'
        $pinned = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
        Get-ChildItem -Path $pinned -Filter '*.lnk' -ErrorAction SilentlyContinue |
            Where-Object { $_.BaseName -notmatch 'Explorer|Arquivos' } |
            Remove-Item -Force -ErrorAction SilentlyContinue
        Write-Log 'Itens fixados na barra de tarefas removidos.' 'ok'

        # Desktop limpo (somente Lixeira) e tema
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' '{20D04FE0-3AEA-1069-A2D8-08002B30309D}' 1
        Write-Log 'Icones extras da area de trabalho ocultados.' 'ok'

        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 700
        if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
        Write-Log 'Explorer reiniciado para aplicar a barra de tarefas.' 'ok'
        Write-Log 'Se o icone do Explorador de Arquivos sumir, fixe-o manualmente uma vez.' 'warn'
    } catch {
        Write-Log "Falha na interface: $($_.Exception.Message)" 'erro'
    }
}

# ---------- 4. ONEDRIVE ----------
function Invoke-RemoverOneDrive {
    Write-Log 'ONEDRIVE' 'title'
    try {
        Get-Process -Name OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Milliseconds 300
        Write-Log 'Processo do OneDrive finalizado.' 'ok'

        foreach ($exe in @("$env:SystemRoot\SysWOW64\OneDriveSetup.exe","$env:SystemRoot\System32\OneDriveSetup.exe",
                           "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDriveSetup.exe")) {
            if (Test-Path $exe) {
                Start-Process $exe -ArgumentList '/uninstall' -Wait -ErrorAction SilentlyContinue
                Write-Log "Desinstalado via $exe" 'ok'
            }
        }

        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC' 1
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSync' 1
        Remove-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' 'OneDrive'
        Remove-Item 'HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' -Force -ErrorAction SilentlyContinue
        Write-Log 'Sincronizacao bloqueada por politica e inicializacao removida.' 'ok'
        Write-Log 'Conta do OneDrive desconectada deste notebook.' 'ok'
    } catch {
        Write-Log "Falha ao remover OneDrive: $($_.Exception.Message)" 'erro'
    }
}

# ---------- 7. AJUSTES EXTRAS ----------
function Invoke-Extras {
    Write-Log 'AJUSTES EXTRAS' 'title'
    try {
        # Nunca desligar a placa de rede/wifi para economizar energia
        Get-NetAdapter -ErrorAction SilentlyContinue | ForEach-Object {
            $p = Get-NetAdapterPowerManagement -Name $_.Name -ErrorAction SilentlyContinue
            if ($p) { $p.AllowComputerToTurnOffDevice = 'Disabled'; Set-NetAdapterPowerManagement -InputObject $p -ErrorAction SilentlyContinue }
        }
        Write-Log 'Economia de energia das placas de rede desativada.' 'ok'

        # Sem atualizacao automatica de driver de video interrompendo o painel
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ExcludeWUDriversInQualityUpdate' 1
        Write-Log 'Drivers pelo Windows Update desativados.' 'ok'

        # Escala/telas: desativa mudanca automatica de brilho
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AdaptiveDisplayBrightness' 'Enabled' 0
        Write-Log 'Brilho adaptativo desativado.' 'ok'

        # Reproducao automatica de midia desativada
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers' 'DisableAutoplay' 1
        Write-Log 'Reproducao automatica desativada.' 'ok'
    } catch {
        Write-Log "Falha nos extras: $($_.Exception.Message)" 'erro'
    }
}

# ---------- VERSAO / ATUALIZACAO ----------
$script:Versao  = '3.6.1'
$script:SiteUrl = 'https://confignote-automatico.lovable.app'
# Na thread paralela nao existe $PSCommandPath: a interface passa a pasta do
# pendrive pela variavel global PastaPendrive.
$script:Pasta   = if ($global:PastaPendrive) { $global:PastaPendrive } else { Split-Path -Parent $PSCommandPath }

function Test-Atualizacao {
    # -Silencioso: usado na abertura do programa. Nunca mostra caixa de dialogo,
    # so escreve no log. Uma MessageBox antes da janela principal aparecer deixa
    # o aplicativo travado / "sem resposta" para o tecnico.
    param([switch]$Silencioso)
    Write-Log 'VERIFICACAO DE VERSAO' 'title'
    Write-Log "Versao instalada no pendrive: $script:Versao"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $info = Invoke-RestMethod -Uri "$script:SiteUrl/downloads/versao.json" -TimeoutSec 5 -ErrorAction Stop
        if ($info.versao -ne $script:Versao) {
            Write-Log "EXISTE UMA VERSAO MAIS NOVA: $($info.versao) ($($info.data))" 'warn'
            foreach ($m in $info.novidades) { Write-Log "   - $m" }
            Write-Log "Baixe em: $script:SiteUrl/versoes" 'warn'
            if ($global:Estado) {
                # Rodando na thread paralela: a interface mostra o aviso no fim.
                if (-not $Silencioso) { $global:Estado.NovaVersao = [string]$info.versao }
            } elseif (-not $Silencioso) {
                $r = [System.Windows.MessageBox]::Show("Versao $($info.versao) disponivel.`nAbrir a pagina de versoes agora?",'Atualizacao','YesNo','Information')
                if ($r -eq 'Yes') { Start-Process "$script:SiteUrl/versoes" }
            }
        } else {
            Write-Log 'Voce esta com a versao mais recente.' 'ok'
        }
    } catch {
        Write-Log 'Nao foi possivel consultar o site (sem internet?). Seguindo com a versao local.' 'warn'
    }
}

# ---------- 0. VERIFICACAO PREVIA DO SISTEMA ----------
function Invoke-PreCheck {
    Write-Log 'VERIFICACAO PREVIA DO SISTEMA' 'title'
    $problemas = 0
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        Write-Log "Sistema: $($os.Caption) ($($os.OSArchitecture)) - build $($os.BuildNumber)"
        Write-Log "Computador: $env:COMPUTERNAME | Usuario: $env:USERNAME"

        $ps = $PSVersionTable.PSVersion.ToString()
        if ($PSVersionTable.PSVersion.Major -lt 5) { Write-Log "PowerShell $ps e antigo - atualize." 'warn'; $problemas++ }
        else { Write-Log "PowerShell $ps compativel." 'ok' }

        $c = Get-PSDrive C
        $livreGB = [math]::Round($c.Free/1GB,1)
        if ($livreGB -lt 10) { Write-Log "Disco C: com apenas $livreGB GB livres." 'warn'; $problemas++ }
        else { Write-Log "Disco C: $livreGB GB livres." 'ok' }

        $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1)
        if ($ramGB -lt 4) { Write-Log "Memoria RAM baixa: $ramGB GB." 'warn'; $problemas++ }
        else { Write-Log "Memoria RAM: $ramGB GB." 'ok' }

        $bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if ($bat) {
            if ($bat.BatteryStatus -eq 2) { Write-Log 'Notebook na tomada.' 'ok' }
            else { Write-Log "Notebook na BATERIA ($($bat.EstimatedChargeRemaining)%) - conecte o carregador antes de aplicar." 'warn'; $problemas++ }
        }

        $net = Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($net) { Write-Log 'Internet disponivel.' 'ok' } else { Write-Log 'Sem internet - AnyDesk e atualizacao nao funcionarao agora.' 'warn'; $problemas++ }

        $pend = Get-Item $script:Pasta
        Write-Log "Pendrive / pasta do script: $($pend.FullName)"

        $inst = Join-Path $script:Pasta 'Instaladores'
        $exes = @(Get-ChildItem $inst -Include *.exe,*.msi -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '(?i)\\Prontos\\' })
        if ($exes.Count -gt 0) { Write-Log "$($exes.Count) instalador(es) na pasta Instaladores do pendrive." 'ok' }
        else { Write-Log 'Nenhum instalador na pasta Instaladores do pendrive - a pasta da area de trabalho ficara vazia.' 'warn'; $problemas++ }

        $wp = Join-Path $script:Pasta 'Wallpaper.jpg'
        if (Test-Path $wp) { Write-Log 'Papel de parede da Global LED encontrado no pendrive.' 'ok' }
        else { Write-Log 'Wallpaper.jpg nao esta no pendrive - o papel de parede sera pulado.' 'warn' }

        if ($problemas -eq 0) { Write-Log 'TUDO CERTO PARA APLICAR.' 'ok' }
        else { Write-Log "$problemas ponto(s) de atencao acima - leia antes de continuar." 'warn' }
    } catch {
        Write-Log "Falha na verificacao previa: $($_.Exception.Message)" 'erro'
    }
    return $problemas
}

# ---------- BACKUP / PONTO DE RESTAURACAO ----------
function Get-PastaBackup {
    $raiz = Join-Path $script:Pasta 'Backups'
    $dir  = Join-Path $raiz ("{0}_{1}" -f $env:COMPUTERNAME,(Get-Date -Format 'yyyy-MM-dd_HH-mm'))
    if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    return $dir
}

function Invoke-Backup {
    Write-Log 'BACKUP E PONTO DE RESTAURACAO' 'title'
    try {
        Enable-ComputerRestore -Drive 'C:\' -ErrorAction SilentlyContinue
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' 0
        Checkpoint-Computer -Description "Antes do Configurador Painel LED v$script:Versao" -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Log 'Ponto de restauracao do Windows criado.' 'ok'
    } catch {
        Write-Log 'Nao foi possivel criar o ponto de restauracao (protecao do sistema desligada).' 'warn'
    }
    try {
        $dir = Get-PastaBackup
        $chaves = @(
            @{ Reg='HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Arq='Explorer_Advanced.reg' },
            @{ Reg='HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications'; Arq='Notificacoes.reg' },
            @{ Reg='HKCU\Control Panel\Desktop';                                       Arq='Desktop.reg' },
            @{ Reg='HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Arq='Tema.reg' },
            @{ Reg='HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon';        Arq='Winlogon.reg' }
        )
        foreach ($k in $chaves) { reg export $k.Reg (Join-Path $dir $k.Arq) /y | Out-Null }
        powercfg /list | Out-File (Join-Path $dir 'PlanosEnergia.txt') -Encoding UTF8
        Get-CimInstance Win32_ComputerSystem | Out-File (Join-Path $dir 'Maquina.txt') -Encoding UTF8
        Write-Log "Backup das configuracoes salvo em: $dir" 'ok'
        $script:UltimoBackup = $dir
    } catch {
        Write-Log "Falha no backup: $($_.Exception.Message)" 'erro'
    }
}

function Invoke-Restaurar {
    # -Confirmado: a pergunta ja foi feita na interface, aqui so executa.
    param([switch]$Confirmado)
    Write-Log 'RESTAURACAO' 'title'
    $raiz = Join-Path $script:Pasta 'Backups'
    if (-not (Test-Path $raiz)) { Write-Log 'Nenhum backup encontrado no pendrive.' 'warn'; return }
    $ultimo = Get-ChildItem $raiz -Directory | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $ultimo) { Write-Log 'Nenhum backup encontrado.' 'warn'; return }
    if (-not $Confirmado) {
        $r = [System.Windows.MessageBox]::Show("Restaurar as configuracoes do backup:`n$($ultimo.Name)?",'Restaurar','YesNo','Warning')
        if ($r -ne 'Yes') { return }
    }
    foreach ($f in (Get-ChildItem $ultimo.FullName -Filter *.reg)) {
        reg import $f.FullName 2>$null | Out-Null
        Write-Log "Restaurado: $($f.Name)" 'ok'
    }
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Write-Log 'Configuracoes restauradas. Reinicie o notebook.' 'ok'
    Write-Log 'Para desfazer tudo (inclusive programas), use Restauracao do Sistema do Windows (rstrui).' 
}

# ---------- INSTALADORES + PLUGINS ----------
function Start-AceitadorDeJanelas {
    # v3.2.0 - Alem do comportamento geral (ler caixas/radios, escolher botao
    # por prioridade, fechar tela final), aceita um PERFIL. Com -Perfil NovaLCT
    # cada tela recebe UMA acao definida, uma tela ja resolvida nao e clicada de
    # novo e, se a mesma tela se repetir, o assistente escalona para o teclado e
    # depois abandona aquela janela em vez de ficar em looping.
    param([string]$Perfil = 'Geral')
    $codigo = {
        param($Perfil)
        Add-Type -AssemblyName System.Windows.Forms

        Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class GLWin {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
    public static string Text(IntPtr h) { var sb = new StringBuilder(512); GetWindowText(h, sb, 512); return sb.ToString(); }
    public static string Cls(IntPtr h) { var sb = new StringBuilder(256); GetClassName(h, sb, 256); return sb.ToString(); }
    public static void Click(IntPtr h) { SendMessage(h, 0x00F5, IntPtr.Zero, IntPtr.Zero); }
    public static int  GetCheck(IntPtr h) { return (int)SendMessage(h, 0x00F0, IntPtr.Zero, IntPtr.Zero); }
    public static void SetCheck(IntPtr h, int v) { SendMessage(h, 0x00F1, new IntPtr(v), IntPtr.Zero); }
    public static void Close(IntPtr h) { PostMessage(h, 0x0010, IntPtr.Zero, IntPtr.Zero); }
    public static int  Style(IntPtr h) { return GetWindowLong(h, -16); }
}
"@ -ErrorAction SilentlyContinue

        $titulos  = 'Setup|Install|Instal|Plugin|Driver|Wizard|Assistente|NovaLCT|LedVision|AnyDesk|Nova\s*Star|Mars|Smart\s*Module|Visual C\+\+|Seguran|Security|License|Licen|Uninstall|Desinstal|Remove|Remover'

        # Botoes por PRIORIDADE (o primeiro que existir e estiver habilitado ganha)
        $prioridade = @(
            '^&?(Instalar|Install)$',
            '^&?(Desinstalar|Uninstall|Remover|Remove)$',
            '^&?(Avan[cç]ar|Pr[oó]ximo|Next|Continuar|Continue)( >)?$',
            '^&?(Aceito|Aceitar|Concordo|Accept|I &?Agree|Agree)$',
            '^&?(Sim|Yes|OK)$',
            '^&?(Concluir|Finalizar|Finish|Done|Fechar|Close)$',
            'Instalar este software de driver mesmo assim|Install this driver software anyway'
        )
        $marcarRe    = '(aceito|concordo|accept|agree|termos|terms|licen|criar atalho|create.*shortcut|adicionar|create desktop)'
        $desmarcarRe = '(executar (agora|o programa)|run (the )?(program|application)|launch|start|reiniciar agora|restart now|instalar depois|do not accept|n[aã]o aceito|recusar|opcional|optional|toolbar|barra de ferramentas)'
        $telaFinalRe = '(Concluir|Finalizar|Finish|Done|instala[cç][aã]o conclu|installation complete|completed successfully)'
        $evitarRe    = '^&?(N[aã]o|No|Cancel|Cancelar|Sair|Exit|Voltar|Back|Skip|Pular|Abort)$'

        $historico = @{}   # hwnd -> @{ Assinatura=''; Tentativas=0 }
        $abandonadas = @{} # hwnd -> $true (tela que nao sai: parar de clicar)
        $resolvidas  = @{} # assinatura de tela ja tratada (nao repetir acao)

        # Perfil NovaLCT: roteiro fixo. Cada tela reconhecida tem UMA acao.
        $ehNova = ($Perfil -eq 'NovaLCT')
        if ($ehNova) {
            $prioridade = @(
                '^&?(Instalar|Install)$',
                '^&?(Avan[cç]ar|Pr[oó]ximo|Next)( >)?$',
                '^&?(Aceito|Aceitar|Concordo|Accept|I &?Agree|Agree)$',
                '^&?(Sim|Yes|OK)$',
                'Instalar este software de driver mesmo assim|Install this driver software anyway',
                '^&?(Concluir|Finalizar|Finish|Done|Fechar|Close)$'
            )
        }
        $limiteTeclado  = if ($ehNova) { 3 } else { 6 }
        $limiteAbandono = if ($ehNova) { 8 } else { 14 }

        $fim = (Get-Date).AddMinutes(45)
        while ((Get-Date) -lt $fim) {

            $janelas = New-Object System.Collections.ArrayList
            $cb = [GLWin+EnumProc]{
                param($h, $l)
                if ([GLWin]::IsWindowVisible($h)) {
                    $t = [GLWin]::Text($h)
                    if ($t -and $t -match $titulos) { [void]$janelas.Add($h) }
                }
                return $true
            }
            [void][GLWin]::EnumWindows($cb, [IntPtr]::Zero)

            foreach ($j in $janelas) {
                if ($abandonadas.ContainsKey([int64]$j)) { continue }

                $checks  = New-Object System.Collections.ArrayList
                $radios  = New-Object System.Collections.ArrayList
                $botoes  = New-Object System.Collections.ArrayList
                $textos  = New-Object System.Collections.ArrayList

                $cbFilho = [GLWin+EnumProc]{
                    param($h, $l)
                    $cls = [GLWin]::Cls($h)
                    $txt = [GLWin]::Text($h)
                    if ($txt) { [void]$textos.Add($txt) }
                    if ($cls -match 'Button|TButton|TCheckBox|TRadioButton|TBitBtn') {
                        $st = [GLWin]::Style($h)
                        # BS_CHECKBOX=2, BS_AUTOCHECKBOX=3, BS_RADIOBUTTON=4, BS_AUTORADIOBUTTON=9, BS_3STATE=5
                        $tipo = $st -band 0x0F
                        $enab = [GLWin]::IsWindowEnabled($h)
                        if ($tipo -in 2,3,5) {
                            [void]$checks.Add(@{ H=$h; Txt=$txt; Enab=$enab })
                        } elseif ($tipo -in 4,9) {
                            [void]$radios.Add(@{ H=$h; Txt=$txt; Enab=$enab })
                        } elseif ($txt) {
                            [void]$botoes.Add(@{ H=$h; Txt=$txt; Enab=$enab })
                        }
                    }
                    return $true
                }
                [void][GLWin]::EnumChildWindows($j, $cbFilho, [IntPtr]::Zero)

                $tituloJ = [GLWin]::Text($j)
                $textoTudo = ($textos -join ' ')
                $ehFinal = ($tituloJ -match $telaFinalRe) -or ($textoTudo -match $telaFinalRe)

                # 1) Caixas: marcar aceite/atalho; desmarcar executar-agora/reiniciar-agora/opcional
                #    $mudou = houve troca de selecao nesta volta; nesse caso o
                #    botao de avancar so e clicado na volta seguinte, quando o
                #    instalador ja habilitou o botao por causa do aceite.
                $mudou = $false
                foreach ($c in $checks) {
                    if (-not $c.Enab) { continue }
                    try {
                        $estado = [GLWin]::GetCheck($c.H)   # 0=unchecked, 1=checked
                        if ($c.Txt -match $desmarcarRe -and $estado -ne 0) {
                            [GLWin]::SetCheck($c.H, 0); [GLWin]::Click($c.H) | Out-Null
                            $mudou = $true
                        } elseif ($c.Txt -match $marcarRe -and $estado -ne 1) {
                            [GLWin]::SetCheck($c.H, 1); [GLWin]::Click($c.H) | Out-Null
                            $mudou = $true
                        }
                    } catch { }
                }

                # 1b) Tela de contrato sem texto reconhecivel na caixa: se o
                #     titulo/corpo fala de licenca/termos e existe UMA unica
                #     caixa desmarcada, ela e o aceite -> marcar.
                if (($tituloJ -match 'Licen|License|Termos|Terms|Contrato|Agreement' -or $textoTudo -match 'contrato de licen|license agreement|termos de uso|terms of use') -and $checks.Count -eq 1) {
                    $c1 = $checks[0]
                    try {
                        if ($c1.Enab -and [GLWin]::GetCheck($c1.H) -ne 1 -and $c1.Txt -notmatch $desmarcarRe) {
                            [GLWin]::SetCheck($c1.H, 1); [GLWin]::Click($c1.H) | Out-Null
                            $mudou = $true
                        }
                    } catch { }
                }

                # 2) Radios: ler o que esta selecionado e forcar o "aceito".
                #    Muitos instaladores abrem com "Nao aceito" pre-selecionado;
                #    o clique no radio de aceite desmarca o de recusa sozinho.
                $radAceito = @($radios | Where-Object { $_.Txt -match $marcarRe -and $_.Txt -notmatch $desmarcarRe -and $_.Enab })
                $radRecusa = @($radios | Where-Object { $_.Txt -match $desmarcarRe -and $_.Enab })
                foreach ($r in $radAceito) {
                    try {
                        if ([GLWin]::GetCheck($r.H) -ne 1) {
                            [GLWin]::Click($r.H)
                            Start-Sleep -Milliseconds 120
                            if ([GLWin]::GetCheck($r.H) -ne 1) { [GLWin]::SetCheck($r.H, 1) }
                            $mudou = $true
                        }
                    } catch { }
                }
                # Se nao havia radio de aceite reconhecido mas ha um de recusa
                # marcado, alterna para o outro radio do mesmo grupo.
                if (-not $radAceito.Count -and $radRecusa.Count) {
                    foreach ($r in $radRecusa) {
                        try {
                            if ([GLWin]::GetCheck($r.H) -eq 1) {
                                $outro = $radios | Where-Object { $_.H -ne $r.H -and $_.Enab } | Select-Object -First 1
                                if ($outro) { [GLWin]::Click($outro.H); $mudou = $true }
                            }
                        } catch { }
                    }
                }

                # 3) Escolha do botao por prioridade (ignora desabilitados e "evitar")
                $alvo = $null
                foreach ($padrao in $prioridade) {
                    $cand = $botoes | Where-Object { $_.Enab -and $_.Txt -notmatch $evitarRe -and ($_.Txt -replace '\s+$','') -match $padrao } | Select-Object -First 1
                    if ($cand) { $alvo = $cand; break }
                }

                # Anti-loop: assinatura da tela (titulo + botoes + textos).
                # Repetiu sem mudar -> teclado; continuou repetindo -> abandona
                # esta janela, para nao travar a fila de instalacao.
                $assinatura = "$tituloJ|$($botoes.Count)|$(($botoes | ForEach-Object { $_.Txt }) -join ',')|$($alvo.Txt)"
                if (-not $historico.ContainsKey([int64]$j)) {
                    $historico[[int64]$j] = @{ Assinatura=$assinatura; Tentativas=0 }
                }
                $h0 = $historico[[int64]$j]
                if ($h0.Assinatura -eq $assinatura) { $h0.Tentativas++ } else { $h0.Assinatura = $assinatura; $h0.Tentativas = 1 }

                if ($h0.Tentativas -gt $limiteAbandono) {
                    $abandonadas[[int64]$j] = $true
                    continue
                }

                # No perfil NovaLCT uma tela ja resolvida (mesma assinatura, ja
                # clicada com sucesso) nao recebe outro clique na mesma volta.
                $clicou = $false
                if ($mudou) {
                    # deu tempo do instalador reavaliar o aceite antes de avancar
                    $clicou = $true
                    $h0.Tentativas = 0
                } elseif ($alvo -and $h0.Tentativas -le $limiteTeclado) {
                    if (-not ($ehNova -and $resolvidas.ContainsKey($assinatura) -and $h0.Tentativas -gt 1)) {
                        try { [GLWin]::Click($alvo.H); $clicou = $true; $resolvidas[$assinatura] = $true } catch { }
                    }
                }


                # 4) Tela final: alem de clicar, forca o fechamento se ficar aberta
                if ($ehFinal) {
                    Start-Sleep -Milliseconds 400
                    if ([GLWin]::IsWindowVisible($j)) {
                        try { [GLWin]::Close($j) } catch { }
                    }
                }

                # 5) Fallback teclado
                if (-not $clicou -or $h0.Tentativas -gt $limiteTeclado) {
                    try {
                        [void][GLWin]::SetForegroundWindow($j)
                        Start-Sleep -Milliseconds 200
                        [System.Windows.Forms.SendKeys]::SendWait('%a')
                        [System.Windows.Forms.SendKeys]::SendWait('%i')
                        [System.Windows.Forms.SendKeys]::SendWait('%y')
                        [System.Windows.Forms.SendKeys]::SendWait('%n')
                        [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
                    } catch { }
                }

            }
            Start-Sleep -Milliseconds 900
        }
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions  = 'ReuseThread'
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($codigo).AddArgument($Perfil)
    $handle = $ps.BeginInvoke()
    return [pscustomobject]@{ PS = $ps; Runspace = $rs; Handle = $handle }
}

function Stop-AceitadorDeJanelas {
    param($Assistente)
    if (-not $Assistente) { return }
    try { $Assistente.PS.Stop() } catch { }
    try { $Assistente.PS.Dispose() } catch { }
    try { $Assistente.Runspace.Close() } catch { }
}


# ---------- APARENCIA: TEMA ESCURO + PAPEL DE PAREDE ----------
Add-Type @'
using System.Runtime.InteropServices;
public class WallpaperApi {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@ -ErrorAction SilentlyContinue

function Invoke-Aparencia {
    Write-Log 'APARENCIA (TEMA ESCURO E PAPEL DE PAREDE)' 'title'
    try {
        $pers = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        Set-Reg $pers 'AppsUseLightTheme' 0
        Set-Reg $pers 'SystemUsesLightTheme' 0
        Set-Reg 'HKCU:\Control Panel\Desktop' 'AutoColorization' 0
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Accent' 'AccentColorMenu' 0xFF3D14 'DWord'
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\DWM' 'ColorPrevalence' 1
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\DWM' 'AccentColor' 0xFF3D14 'DWord'
        Write-Log 'Tema escuro do Windows e cor de destaque laranja aplicados.' 'ok'

        $origem = Join-Path $script:Pasta 'Wallpaper.jpg'
        if (Test-Path $origem) {
            $destinoDir = 'C:\ProgramData\GlobalLED'
            if (-not (Test-Path $destinoDir)) { New-Item -Path $destinoDir -ItemType Directory -Force | Out-Null }
            $destino = Join-Path $destinoDir 'Wallpaper.jpg'
            Copy-Item $origem $destino -Force
            Set-Reg 'HKCU:\Control Panel\Desktop' 'Wallpaper' $destino 'String'
            Set-Reg 'HKCU:\Control Panel\Desktop' 'WallpaperStyle' '10' 'String'   # preencher
            Set-Reg 'HKCU:\Control Panel\Desktop' 'TileWallpaper' '0' 'String'
            [WallpaperApi]::SystemParametersInfo(20,0,$destino,3) | Out-Null
            # Tela de bloqueio e plano de fundo padrao para novos usuarios
            $lock = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'
            Set-Reg $lock 'LockScreenImagePath' $destino 'String'
            Set-Reg $lock 'LockScreenImageUrl'  $destino 'String'
            Set-Reg $lock 'LockScreenImageStatus' 1
            Write-Log "Papel de parede da Global LED aplicado ($destino)." 'ok'
        } else {
            Write-Log 'Wallpaper.jpg nao encontrado ao lado do script - papel de parede pulado.' 'warn'
        }

        # Cor de fundo solida (mesma do wallpaper) para o login e bordas
        Set-Reg 'HKCU:\Control Panel\Colors' 'Background' '13 20 30' 'String'
        Write-Log 'Cor de fundo escura definida.' 'ok'
    } catch {
        Write-Log "Falha na aparencia: $($_.Exception.Message)" 'erro'
    }
}

# ---------- VALIDACAO POS-APLICACAO ----------
function Invoke-Validacao {
    Write-Log 'VALIDACAO POS-APLICACAO' 'title'
    $ok = 0; $falhas = 0
    function Test-Item {
        param([string]$Nome,[scriptblock]$Teste)
        try {
            if (& $Teste) { Write-Log "$Nome : OK" 'ok'; $script:vOk++ }
            else { Write-Log "$Nome : NAO APLICADO" 'warn'; $script:vFalhas++ }
        } catch { Write-Log "$Nome : nao foi possivel verificar" 'warn'; $script:vFalhas++ }
    }
    $script:vOk = 0; $script:vFalhas = 0

    Test-Item 'Plano de energia de alto desempenho' { (powercfg /getactivescheme) -match 'Desempenho|Performance' }
    Test-Item 'Tela nunca desliga (tomada)'         { ((powercfg /query SCHEME_CURRENT SUB_VIDEO VIDEOIDLE) -match 'Indice de Configuracao de Energia Atual de CA: 0x00000000|Current AC Power Setting Index: 0x00000000') }
    Test-Item 'Fechar a tampa: nada a fazer (AC e DC)' { ((powercfg /query SCHEME_CURRENT 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936) -join ' ') -notmatch '0x0000000[1-3]' }
    Test-Item 'Suspender: nunca (AC e DC)'          { ((powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE) -join ' ') -notmatch '0x0000000[1-9]' }
    Test-Item 'Atualizacoes agendadas na madrugada' { (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name ScheduledInstallTime -ErrorAction SilentlyContinue).ScheduledInstallTime -ge 0 }
    Test-Item 'Tarefa de atualizacao noturna criada' { [bool](Get-ScheduledTask -TaskName 'PainelLED - Atualizacoes noturnas' -ErrorAction SilentlyContinue) }
    if ($Opcoes -and $Opcoes.ReinicioAuto) {
        Test-Item 'Reinicio so de madrugada, quando a atualizacao pedir' { [bool](Get-ScheduledTask -TaskName 'PainelLED - Reinicio apos atualizacao' -ErrorAction SilentlyContinue) }
    } else {
        Test-Item 'Sem reinicio automatico apos atualizacao' { -not (Get-ScheduledTask -TaskName 'PainelLED - Reinicio apos atualizacao' -ErrorAction SilentlyContinue) }
    }
    Test-Item 'Reinicio diario em horario fixo removido' { -not (Get-ScheduledTask -TaskName 'PainelLED - Reinicio noturno' -ErrorAction SilentlyContinue) }
    Test-Item 'Windows nao reinicia com usuario logado' { (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name NoAutoRebootWithLoggedOnUsers -ErrorAction SilentlyContinue).NoAutoRebootWithLoggedOnUsers -eq 1 }
    Test-Item 'Controle de aplicativos (Smart App Control) desligado' { (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' -Name VerifiedAndReputablePolicyState -ErrorAction SilentlyContinue).VerifiedAndReputablePolicyState -eq 0 }
    Test-Item 'SmartScreen de aplicativos desligado' { (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name SmartScreenEnabled -ErrorAction SilentlyContinue).SmartScreenEnabled -eq 'Off' }
    Test-Item 'Hibernacao desligada'                { -not (Test-Path 'C:\hiberfil.sys') }
    Test-Item 'Protetor de tela desativado'         { (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -Name ScreenSaveActive -ErrorAction SilentlyContinue).ScreenSaveActive -eq '0' }
    Test-Item 'Notificacoes desativadas'            { (Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\PushNotifications' -Name ToastEnabled -ErrorAction SilentlyContinue).ToastEnabled -eq 0 }
    Test-Item 'OneDrive removido'                   { -not (Get-Process OneDrive -ErrorAction SilentlyContinue) }
    Test-Item 'Tema escuro ativo'                   { (Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -ErrorAction SilentlyContinue).AppsUseLightTheme -eq 0 }
    Test-Item 'Papel de parede da Global LED'       { (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -Name Wallpaper -ErrorAction SilentlyContinue).Wallpaper -like '*GlobalLED*' }
    if ($Opcoes -and $Opcoes.CopiarInst) {
        Test-Item 'Pasta Instalar Programas LED na area de trabalho' { Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Instalar Programas LED') }
    }
    Test-Item 'Antivirus de terceiros removido' { -not (Get-ProgramasFabrica -Forcar | Where-Object { $_.Fabricante -eq 'Antivirus' }) }
    Test-Item 'Programas de fabrica removidos' { (@(Get-ProgramasFabrica -Forcar | Where-Object { $_.Fabricante -ne 'Antivirus' })).Count -eq 0 }
    Test-Item 'Windows Defender desligado' {
        (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' -Name DisableAntiSpyware -ErrorAction SilentlyContinue).DisableAntiSpyware -eq 1
    }
    Test-Item 'Defender antivirus desligado por politica' {
        (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender' -Name DisableAntiVirus -ErrorAction SilentlyContinue).DisableAntiVirus -eq 1
    }
    Test-Item 'Defender protecao em tempo real desligada' {
        (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection' -Name DisableRealtimeMonitoring -ErrorAction SilentlyContinue).DisableRealtimeMonitoring -eq 1
    }
    Test-Item 'Servico WinDefend desabilitado' {
        (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\WinDefend' -Name Start -ErrorAction SilentlyContinue).Start -eq 4
    }
    Test-Item 'Servico WinDefend parado' {
        $s = Get-Service WinDefend -ErrorAction SilentlyContinue
        (-not $s) -or ($s.Status -ne 'Running')
    }

    Write-Log "RESULTADO: $script:vOk itens OK, $script:vFalhas com atencao." $(if ($script:vFalhas -eq 0) { 'ok' } else { 'warn' })
    return $script:vFalhas
}


# ---------- 8. LIMPEZA DE FABRICA (v2.5.0) ----------
# Programas que os notebooks Lenovo e Samsung trazem de fabrica e que nao
# usamos no painel. Drivers, audio, video e teclas Fn NUNCA entram na lista.
$script:PadraoRemover = @(
    # Lenovo
    'Lenovo Vantage','Lenovo Now','Lenovo Welcome','Lenovo Smart','Lenovo Migration',
    'Lenovo Quick Clean','Lenovo Voice','Lenovo Companion','App Explorer','Lenovo Utility Store',
    'E046963F.LenovoCompanion','E046963F.LenovoSettingsforEnterprise','LenovoCorporation.LenovoID',
    'LenovoCorporation.LenovoSettings','E0469640.LenovoUtility','Nitro',
    # Samsung
    'Samsung Studio','Samsung Recovery','Samsung Update','Samsung Notes','PENUP',
    'Samsung Quick Search','Samsung Sound','Samsung Photo','Samsung Video','Samsung Care',
    'SAMSUNGELECTRONICSCO.LTD.SamsungNotes','SAMSUNGELECTRONICSCO.LTD.SamsungRecovery',
    'SAMSUNGELECTRONICSCO.LTD.SamsungUpdate','SAMSUNGELECTRONICSCO.LTD.SamsungStudio',
    # McAfee e antivirus de teste
    'McAfee','Norton','Avast','AVG Antivirus','Bitdefender Agent',
    # Genericos
    'Microsoft Office - pt-br','OneNote for Windows','Microsoft.Office.OneNote',
    'Microsoft.XboxApp','Microsoft.XboxGamingOverlay','Microsoft.XboxGameOverlay',
    'Microsoft.GamingApp','Microsoft.Xbox.TCUI','Microsoft.XboxSpeechToTextOverlay',
    'BytedancePte.Ltd.TikTok','SpotifyAB.SpotifyMusic','king.com.CandyCrush',
    'Clipchamp.Clipchamp','Microsoft.BingNews','Microsoft.BingWeather','Microsoft.BingSearch',
    'Microsoft.MicrosoftSolitaireCollection','Microsoft.Todos','Microsoft.ZuneMusic','Microsoft.ZuneVideo'
)

# Tudo o que faz o notebook funcionar fica no lugar.
$script:PadraoManter = @(
    'Driver','Realtek','Dolby','Waves','Conexant','Intel','NVIDIA','AMD','Radeon',
    'Synaptics','Elan','Touchpad','Camera','Wireless','Bluetooth','Chipset','Firmware','BIOS',
    'Lenovo Power','Lenovo Hotkey','Hotkey Features','Lenovo System Update','Lenovo Battery',
    'Samsung Settings','Easy Settings','Samsung Device','Samsung Flow','Visual C++','.NET',
    'Microsoft Edge','Windows Store','Runtime','Redistributable','Framework','AnyDesk','LedVision','NovaLCT'
)

function Test-PadraoBloat([string]$Nome) {
    if (-not $Nome) { return $false }
    foreach ($m in $script:PadraoManter) { if ($Nome -like "*$m*") { return $false } }
    foreach ($r in $script:PadraoRemover) { if ($Nome -like "*$r*") { return $true } }
    return $false
}

# Devolve os programas de fabrica encontrados neste notebook (classicos + Store).
function Get-ProgramasFabrica {
    param([switch]$Forcar)
    if ($script:CacheBloat -and -not $Forcar) { return $script:CacheBloat }
    $lista = New-Object System.Collections.ArrayList

    $chaves = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($k in $chaves) {
        foreach ($item in (Get-ItemProperty $k -ErrorAction SilentlyContinue)) {
            $nome = [string]$item.DisplayName
            if (-not $nome) { continue }
            if (-not (Test-PadraoBloat $nome)) { continue }
            $cmd = if ($item.QuietUninstallString) { [string]$item.QuietUninstallString } else { [string]$item.UninstallString }
            if (-not $cmd) { continue }
            if ($lista | Where-Object { $_.Nome -eq $nome }) { continue }
            [void]$lista.Add([pscustomobject]@{
                Nome = $nome; Tipo = 'classico'; Comando = $cmd
                Fabricante = (Get-FabricanteBloat $nome)
            })
        }
    }

    foreach ($p in (Get-AppxPackage -ErrorAction SilentlyContinue)) {
        $nome = [string]$p.Name
        if (-not (Test-PadraoBloat $nome)) { continue }
        if ($lista | Where-Object { $_.Nome -eq $nome }) { continue }
        [void]$lista.Add([pscustomobject]@{
            Nome = $nome; Tipo = 'store'; Comando = [string]$p.PackageFullName
            Fabricante = (Get-FabricanteBloat $nome)
        })
    }

    $script:CacheBloat = @($lista | Sort-Object Fabricante, Nome)
    return $script:CacheBloat
}

function Get-FabricanteBloat([string]$Nome) {
    if ($Nome -like '*McAfee*' -or $Nome -like '*WebAdvisor*' -or $Nome -like '*LiveSafe*' -or
        $Nome -like '*Norton*' -or $Nome -like '*Avast*' -or $Nome -like '*AVG*' -or
        $Nome -like '*Bitdefender*') { return 'Antivirus' }
    if ($Nome -like '*Lenovo*' -or $Nome -like '*Nitro*') { return 'Lenovo' }
    if ($Nome -like '*Samsung*' -or $Nome -like '*PENUP*') { return 'Samsung' }
    return 'Windows'
}

# Detecta o tipo de instalador para escolher o parametro silencioso certo.
function Get-TipoDesinstalador {
    param([string]$Cmd, [string]$Exe)
    if ($Cmd -match 'msiexec' -or $Cmd -match '\.msi') { return 'MSI' }
    $caminho = if ($Exe -and (Test-Path $Exe -ErrorAction SilentlyContinue)) { $Exe } else { $null }
    if ($caminho) {
        try {
            # Assinatura de bytes para reconhecer os tres principais formatos.
            $bytes = [System.IO.File]::ReadAllBytes($caminho)
            $texto = [System.Text.Encoding]::ASCII.GetString($bytes, 0, [Math]::Min($bytes.Length, 2000000))
            if ($texto -match 'Inno Setup')      { return 'Inno' }
            if ($texto -match 'Nullsoft')        { return 'NSIS' }
            if ($texto -match 'InstallShield')   { return 'InstallShield' }
            if ($texto -match 'WiX Toolset')     { return 'MSI' }
        } catch { }
    }
    if ($Cmd -match '/S(\s|$)|/silent|/qn|--silent|/VERYSILENT') { return 'Silencioso' }
    return 'Desconhecido'
}

function Get-ArgsDesinstalacao {
    param([string]$Tipo, [string]$ArgsExistentes)
    switch ($Tipo) {
        'Inno'          { return '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' }
        'NSIS'          { return '/S' }
        'InstallShield' { return '/s /f1"%TEMP%\uninst.iss" /SMS' }
        'Silencioso'    { return $ArgsExistentes }
        default         { return '/S /silent /quiet /norestart' }
    }
}

function Test-ProgramaAindaInstalado {
    param($Programa)
    if ($Programa.Tipo -eq 'store') {
        return [bool](Get-AppxPackage -Name $Programa.Nome -ErrorAction SilentlyContinue)
    }
    $chaves = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($k in $chaves) {
        $achou = Get-ItemProperty $k -ErrorAction SilentlyContinue |
                 Where-Object { $_.DisplayName -eq $Programa.Nome }
        if ($achou) { return $true }
    }
    return $false
}

function Remove-ProgramaFabrica {
    param($Programa, [switch]$Assistido)
    try {
        if ($Programa.Tipo -eq 'store') {
            Get-AppxPackage -Name $Programa.Nome -AllUsers -ErrorAction SilentlyContinue |
                Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -eq $Programa.Nome } |
                ForEach-Object { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null }
            if (-not (Test-ProgramaAindaInstalado $Programa)) {
                Write-Log "   Removido: $($Programa.Nome)" 'ok'; return $true
            }
            # Ultimo recurso: winget
            try { & winget uninstall --id $Programa.Nome --silent --accept-source-agreements 2>$null | Out-Null } catch { }
            if (-not (Test-ProgramaAindaInstalado $Programa)) {
                Write-Log "   Removido via winget: $($Programa.Nome)" 'ok'; return $true
            }
            Write-Log "   $($Programa.Nome): pacote da Loja recusou a remocao." 'warn'
            return $false
        }

        $cmd = $Programa.Comando
        $exe = $cmd; $argsCmd = ''
        if ($cmd -match '^"([^"]+)"\s*(.*)$')      { $exe = $Matches[1]; $argsCmd = $Matches[2] }
        elseif ($cmd -match '^(\S+\.exe)\s*(.*)$') { $exe = $Matches[1]; $argsCmd = $Matches[2] }
        $tipo = Get-TipoDesinstalador -Cmd $cmd -Exe $exe

        if ($tipo -eq 'MSI') {
            $codigo = ([regex]::Match($cmd, '\{[0-9A-Fa-f\-]{36}\}')).Value
            if (-not $codigo) { Write-Log "   $($Programa.Nome): MSI sem GUID." 'warn'; return $false }
            $p = Start-Process 'msiexec.exe' -ArgumentList "/x $codigo /qn /norestart" -PassThru -WindowStyle Hidden -ErrorAction Stop
            [void]$p.WaitForExit(180000)
        } elseif ($Assistido) {
            Write-Log "   $($Programa.Nome): tentativa assistida (janela visivel, assistente aceita)." 'warn'
            $p = Start-Process $exe -ArgumentList $argsCmd -PassThru -ErrorAction Stop
            if (-not $p.WaitForExit(300000)) { try { $p.Kill() } catch { } }
        } else {
            $argsFinal = Get-ArgsDesinstalacao -Tipo $tipo -ArgsExistentes $argsCmd
            Write-Log "   $($Programa.Nome): tipo=$tipo, args='$argsFinal'"
            $p = Start-Process $exe -ArgumentList $argsFinal -PassThru -WindowStyle Hidden -ErrorAction Stop
            if (-not $p.WaitForExit(180000)) { try { $p.Kill() } catch { } }
        }

        Start-Sleep -Milliseconds 800
        if (-not (Test-ProgramaAindaInstalado $Programa)) {
            Write-Log "   Removido: $($Programa.Nome)" 'ok'
            return $true
        }

        # Tentativa 2: winget
        try {
            $saida = & winget uninstall --name $Programa.Nome --silent --accept-source-agreements 2>$null
            if (-not (Test-ProgramaAindaInstalado $Programa)) {
                Write-Log "   Removido via winget: $($Programa.Nome)" 'ok'; return $true
            }
        } catch { }

        # Tentativa 3: assistido (janela visivel)
        if (-not $Assistido) {
            return (Remove-ProgramaFabrica -Programa $Programa -Assistido)
        }

        Write-Log "   $($Programa.Nome): ainda instalado apos todas as tentativas." 'erro'
        return $false
    } catch {
        Write-Log "   $($Programa.Nome): erro na remocao ($($_.Exception.Message))" 'erro'
        return $false
    }
}

function Invoke-DesarmarAntivirus {
    # v2.6.0 - Roda ANTES de qualquer outra acao: a McAfee bloqueia scripts,
    # alteracoes de registro e instaladores enquanto estiver ativa.
    Write-Log 'DESARMANDO O ANTIVIRUS (McAfee) ANTES DE COMECAR' 'title'

    # 1. Libera o pendrive e o proprio script de qualquer bloqueio de origem.
    try {
        Get-ChildItem -Path $script:Pasta -Recurse -File -ErrorAction SilentlyContinue |
            Unblock-File -ErrorAction SilentlyContinue
        Write-Log 'Arquivos do pendrive desbloqueados (marca de origem removida).' 'ok'
    } catch { Write-Log 'Nao foi possivel desbloquear todos os arquivos do pendrive.' 'warn' }

    # 2. Exclusoes: pendrive, pastas de instalacao e o PowerShell.
    try {
        Add-MpPreference -ExclusionPath $script:Pasta -ErrorAction Stop
        Add-MpPreference -ExclusionPath 'C:\Windows\Temp' -ErrorAction Stop
        Add-MpPreference -ExclusionProcess 'powershell.exe' -ErrorAction Stop
        Write-Log 'Exclusoes do Windows Defender adicionadas.' 'ok'
    } catch { Write-Log "O Windows recusou as exclusoes: $($_.Exception.Message)" 'warn' }
    foreach ($chave in @('HKLM:\SOFTWARE\McAfee\SystemCore\vscore\OnAccessScanner\McShield\Configuration',
                         'HKLM:\SOFTWARE\WOW6432Node\McAfee\SystemCore\vscore\OnAccessScanner\McShield\Configuration')) {
        try { Set-Reg $chave 'bOASEnabled' 0 } catch { Write-Log "A McAfee bloqueou a alteracao em $chave." 'warn' }
    }

    # 3. Encerra os processos da McAfee que interceptam o script.
    $mortos = 0
    foreach ($p in (Get-Process -ErrorAction SilentlyContinue | Where-Object {
                        $_.ProcessName -like 'mc*' -or $_.ProcessName -like 'mfe*' -or
                        $_.ProcessName -like '*McAfee*' -or $_.ProcessName -eq 'MMSSHOST' })) {
        try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; $mortos++ }
        catch { Write-Log "Processo protegido nao encerrado: $($p.ProcessName)." 'warn' }
    }
    Write-Log "$mortos processo(s) da McAfee encerrado(s)." $(if ($mortos -gt 0) { 'ok' } else { 'info' })

    # 4. Para e desativa os servicos e os drivers de protecao em tempo real.
    $svcs = @(Get-Service -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -like 'mc*' -or $_.Name -like 'mfe*' -or $_.DisplayName -like '*McAfee*' })
    foreach ($svc in $svcs) {
        try { Stop-Service -Name $svc.Name -Force -ErrorAction Stop }
        catch { Write-Log "Servico protegido nao parou: $($svc.Name)." 'warn' }
        $saidaSc = & sc.exe config $svc.Name start= disabled 2>&1
        if ($LASTEXITCODE -ne 0) { Write-Log "Nao foi possivel desativar o servico $($svc.Name): $($saidaSc -join ' ')" 'warn' }
    }
    foreach ($drv in @('mfehidk','mfewfpk','mfeavfk','mfeaack','mfefirek','mfencbdc','mfeplk','mfeelamk','epdrv')) {
        $saidaSc = & sc.exe config $drv start= disabled 2>&1
        if ($LASTEXITCODE -notin @(0,1060)) { Write-Log "Driver protegido nao foi desativado: $drv." 'warn' }
    }
    Write-Log "$($svcs.Count) servico(s) da McAfee encontrados; parada/desativacao solicitada." 'info'

    # 5. Tarefas agendadas que reativam a protecao.
    try {
        Get-ScheduledTask -ErrorAction SilentlyContinue |
            Where-Object { $_.TaskName -like '*McAfee*' -or $_.TaskPath -like '*McAfee*' } |
            Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
    } catch { Write-Log "Nao foi possivel desativar as tarefas da McAfee: $($_.Exception.Message)" 'warn' }

    # 6. Confere se ainda restou algo vigiando.
    $ativos = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -like 'mc*' -or $_.ProcessName -like 'mfe*' })
    $servicosAtivos = @(Get-Service -ErrorAction SilentlyContinue | Where-Object {
        ($_.Name -like 'mc*' -or $_.Name -like 'mfe*' -or $_.DisplayName -like '*McAfee*') -and $_.Status -eq 'Running' })
    if ($ativos.Count -gt 0 -or $servicosAtivos.Count -gt 0) {
        Write-Log 'A McAfee recusou o encerramento por causa da protecao contra adulteracao.' 'warn'
        if ($ativos.Count -gt 0) { Write-Log "Processos ativos: $(($ativos.ProcessName | Sort-Object -Unique) -join ', ')" 'warn' }
        if ($servicosAtivos.Count -gt 0) { Write-Log "Servicos ativos: $(($servicosAtivos.Name | Sort-Object -Unique) -join ', ')" 'warn' }
        Write-Log 'A desinstalacao sera tentada mesmo assim; nao e necessario fechar o configurador.' 'info'
    } else {
        Write-Log 'Antivirus desarmado: o configurador pode trabalhar sem bloqueios.' 'ok'
    }
}

function Invoke-LimpezaFabrica {
    param([string[]]$Selecao = @(), [bool]$IncluirMcAfee = $true)
    Write-Log 'LIMPEZA DE FABRICA (Lenovo / Samsung / McAfee)' 'title'

    # Limpa entradas vazias/nulas: uma lista com $null fazia o script pensar
    # que o tecnico tinha desmarcado tudo e nada era removido.
    $Selecao = @($Selecao | Where-Object { "$_".Trim() } | ForEach-Object { "$_".Trim().ToLowerInvariant() })

    $encontrados = @(Get-ProgramasFabrica -Forcar)
    if ($encontrados.Count -eq 0) {
        Write-Log 'Nenhum programa de fabrica encontrado neste notebook.' 'ok'
    } else {
        Write-Log "$($encontrados.Count) programa(s) de fabrica encontrado(s)." 'info'
    }
    if ($Selecao.Count -gt 0) {
        Write-Log "$($Selecao.Count) programa(s) marcado(s) pelo tecnico para remocao." 'info'
    }

    # O assistente de janelas fica ligado durante toda a limpeza: alguns
    # desinstaladores so terminam quando alguem confirma "Sim / Desinstalar".
    $assistente = Start-AceitadorDeJanelas

    $removidos = 0
    $restantes = New-Object System.Collections.ArrayList
    foreach ($prog in $encontrados) {
        if ($prog.Fabricante -eq 'Antivirus' -and -not $IncluirMcAfee) { continue }
        if ($Selecao.Count -gt 0 -and ($Selecao -notcontains "$($prog.Nome)".Trim().ToLowerInvariant())) {
            Write-Log "   Mantido pelo tecnico: $($prog.Nome)" 'info'
            continue
        }
        Write-Log "Removendo $($prog.Fabricante): $($prog.Nome)..."
        if (Remove-ProgramaFabrica -Programa $prog) {

            $removidos++
        } else {
            [void]$restantes.Add("$($prog.Fabricante) - $($prog.Nome)")
        }
    }

    Stop-AceitadorDeJanelas $assistente

    Write-Log "$removidos programa(s) de fabrica removido(s)." $(if ($removidos -gt 0) { 'ok' } else { 'info' })
    if ($restantes.Count -gt 0) {
        Write-Log "AINDA INSTALADOS ($($restantes.Count)):" 'warn'
        foreach ($n in $restantes) { Write-Log "   - $n" 'warn' }
        Write-Log 'Esses precisam ser removidos manualmente ou apos reiniciar o notebook.' 'warn'
    }

    if ($IncluirMcAfee) { Invoke-RemoverMcAfee }
}


function Invoke-RemoverMcAfee {
    Write-Log 'REMOCAO DO MCAFEE' 'title'
    try {
        # Removedor oficial (MCPR.exe), quando estiver na pasta Instaladores do pendrive.
        $pasta = Join-Path $script:Pasta 'Instaladores'
        $mcpr = Get-ChildItem -Path $pasta -Filter 'MCPR*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($mcpr) {
            Write-Log 'Abrindo o removedor oficial da McAfee (MCPR). Conclua as etapas na janela que abrir.' 'warn'
            $p = Start-Process $mcpr.FullName -PassThru -ErrorAction Stop
            if (-not $p.WaitForExit(900000)) {
                Write-Log 'O MCPR continua aberto; conclua a remocao manualmente nessa janela.' 'warn'
            } else {
                Write-Log "Removedor oficial encerrado (codigo $($p.ExitCode))." $(if ($p.ExitCode -eq 0) { 'ok' } else { 'warn' })
            }
        } else {
            Write-Log 'MCPR.exe nao esta na pasta Instaladores - usando a desinstalacao normal.' 'info'
        }

        foreach ($svc in (Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'mc*' -or $_.DisplayName -like '*McAfee*' })) {
            Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
            & sc.exe config $svc.Name start= disabled | Out-Null
        }
        Write-Log 'Servicos da McAfee parados e desativados.' 'ok'

        Get-ScheduledTask -ErrorAction SilentlyContinue |
            Where-Object { $_.TaskName -like '*McAfee*' -or $_.TaskPath -like '*McAfee*' } |
            Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log 'Tarefas agendadas da McAfee removidas.' 'ok'
    } catch {
        Write-Log "Falha ao limpar a McAfee: $($_.Exception.Message)" 'warn'
    }
}

function Invoke-RemoverAntivirusTerceiros {
    Write-Log 'EXCLUINDO ANTIVIRUS DE TERCEIROS' 'title'
    Invoke-DesarmarAntivirus

    $encontrados = @(Get-ProgramasFabrica -Forcar | Where-Object { $_.Fabricante -eq 'Antivirus' })
    if ($encontrados.Count -eq 0) {
        Write-Log 'Nenhum desinstalador de antivirus foi encontrado no registro do Windows.' 'info'
    } else {
        foreach ($prog in $encontrados) {
            Write-Log "Executando o desinstalador de: $($prog.Nome)..."
            [void](Remove-ProgramaFabrica $prog)
        }
    }

    Invoke-RemoverMcAfee
    $script:CacheBloat = $null
    $restantes = @(Get-ProgramasFabrica -Forcar | Where-Object { $_.Fabricante -eq 'Antivirus' })
    if ($restantes.Count -eq 0) {
        Write-Log 'Antivirus de terceiros removido. Reinicie o notebook para concluir a limpeza.' 'ok'
        $global:Estado.Final = 'Antivirus removido. Reinicie o notebook.'
    } else {
        $nomes = ($restantes | ForEach-Object { $_.Nome }) -join ', '
        Write-Log "Ainda instalado: $nomes" 'erro'
        Write-Log 'Use o MCPR.exe oficial na pasta Instaladores e conclua a janela do removedor.' 'warn'
        $global:Estado.Falhas = [int]$restantes.Count
        $global:Estado.Final = 'Remocao incompleta. Veja as linhas vermelhas no console.'
    }
}

# ---------- 9. DESLIGAR O WINDOWS DEFENDER (v2.5.0, reforcado em v2.7.2) ----------
function Invoke-DesligarDefender {
    Write-Log 'DESLIGANDO A PROTECAO DO WINDOWS DEFENDER' 'title'
    Write-Log 'ATENCAO: o notebook ficara sem antivirus ativo.' 'warn'

    $raiz    = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
    $rtp     = "$raiz\Real-Time Protection"
    $sigUpd  = "$raiz\Signature Updates"
    $spynet  = "$raiz\Spynet"

    $jaDesligado = $false
    try {
        $marca = Get-ItemProperty -Path $raiz -Name 'WindowsDefenderIsDisabledPermanently' -ErrorAction SilentlyContinue
        if ($marca -and $marca.WindowsDefenderIsDisabledPermanently -eq 1) { $jaDesligado = $true }
    } catch { }

    if ($jaDesligado) {
        Write-Log 'Defender ja estava desligado por este configurador. Pulando regravacao das politicas.' 'info'
    } else {
        try {
            # Chave raiz
            Set-Reg $raiz 'DisableAntiSpyware'                   1
            Set-Reg $raiz 'DisableAntiVirus'                     1
            Set-Reg $raiz 'DisableRoutinelyTakingAction'         1
            Set-Reg $raiz 'DisableSpecialRunningModes'           1
            Set-Reg $raiz 'ServiceKeepAlive'                     1
            Set-Reg $raiz 'AllowFastServiceStartup'              1
            Set-Reg $raiz 'DisableRealtimeMonitoring'            1

            # Real-Time Protection
            Set-Reg $rtp  'DisableRealtimeMonitoring'            1
            Set-Reg $rtp  'DisableBehaviorMonitoring'            1
            Set-Reg $rtp  'DisableOnAccessProtection'            1
            Set-Reg $rtp  'DisableScanOnRealtimeEnable'          1

            # Signature Updates
            Set-Reg $sigUpd 'ForceUpdateFromMU'                  1

            # Spynet / envio de amostras
            Set-Reg $spynet 'SpynetReporting'                    0
            Set-Reg $spynet 'SubmitSamplesConsent'               2
            Set-Reg $spynet 'DisableBlockAtFirstSeen'            1

            # SmartScreen
            Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableSmartScreen' 0

            # Marca de idempotencia
            Set-Reg $raiz 'WindowsDefenderIsDisabledPermanently' 1

            Write-Log 'Politicas gravadas: a protecao fica desligada apos reiniciar.' 'ok'
        } catch {
            Write-Log "Falha ao gravar as politicas do Defender: $($_.Exception.Message)" 'erro'
        }
    }

    # ---- Tamper Protection: precisa estar desligada para o efeito imediato ----
    $tamper = 0
    try {
        $tp = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' -Name 'TamperProtection' -ErrorAction SilentlyContinue
        if ($tp) { $tamper = [int]$tp.TamperProtection }
    } catch { }
    try { Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Features' 'TamperProtection' 4 } catch { }

    if ($tamper -eq 5) {
        Write-Log 'A Protecao contra Adulteracao (Tamper Protection) esta LIGADA.' 'warn'
        Write-Log 'Clique no botao "ABRIR PROTECAO CONTRA ADULTERACAO", desligue a chave e rode esta opcao de novo.' 'info'
    } else {
        try {
            $null = Get-MpPreference -ErrorAction SilentlyContinue
            Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
            Set-MpPreference -DisableBehaviorMonitoring $true -DisableIOAVProtection $true -DisableScriptScanning $true -ErrorAction SilentlyContinue
            Set-MpPreference -MAPSReporting 0 -SubmitSamplesConsent 2 -ErrorAction SilentlyContinue
            Write-Log 'Protecao em tempo real desligada agora.' 'ok'
        } catch {
            Write-Log 'O Windows recusou desligar agora. Desligue a Protecao contra Adulteracao e repita.' 'warn'
        }
    }

    # ---- Servicos e drivers do Defender (Start = 4 = desabilitado) ----
    foreach ($svc in @('WinDefend','WdNisSvc','Sense','SecurityHealthService','WdFilter','WdNisDrv','WdBoot')) {
        try {
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" 'Start' 4
            Write-Log "Servico $svc marcado como desabilitado." 'ok'
        } catch {
            Write-Log "Nao consegui desabilitar o servico $svc (protegido pelo Windows)." 'warn'
        }
        try { Stop-Service $svc -Force -ErrorAction SilentlyContinue } catch { }
    }

    # ---- Icone/inicializacao da Central de Seguranca ----
    try {
        Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'SecurityHealth' -ErrorAction SilentlyContinue
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications' 'DisableNotifications' 1
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Systray' 'HideSystray' 1
    } catch { }

    # ---- Tarefas agendadas do Defender ----
    try {
        Get-ScheduledTask -TaskPath '\Microsoft\Windows\Windows Defender\' -ErrorAction SilentlyContinue |
            ForEach-Object {
                try { Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -ErrorAction SilentlyContinue | Out-Null } catch { }
            }
        Write-Log 'Tarefas agendadas do Defender desativadas.' 'ok'
    } catch { }

    Write-Log 'Reinicie o notebook para o Defender ficar desligado de forma definitiva.' 'info'
}

# ---------- 9b. CONTROLE DE APLICATIVOS INTELIGENTE (v3.5.0) ----------
# O Windows 11 liga sozinho o "Controle de Aplicativos Inteligente" depois de
# alguns dias de avaliacao. Quando isso acontece ele bloqueia programas sem
# reputacao na nuvem da Microsoft (NovaLCT, LedVision e os binarios que o
# AnyDesk cria no AppData), travando a abertura e a instalacao de apps.
function Invoke-DesligarControleDeApps {
    Write-Log 'DESLIGANDO O CONTROLE DE APLICATIVOS INTELIGENTE (SMART APP CONTROL)' 'title'
    try {
        # 0 = desligado de forma definitiva (nao volta para avaliacao)
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' 'VerifiedAndReputablePolicyState' 0
        Write-Log 'Smart App Control desligado (nao vai mais bloquear aplicativos).' 'ok'
    } catch {
        Write-Log "Nao consegui desligar o Smart App Control: $($_.Exception.Message)" 'warn'
    }

    # SmartScreen do Windows, de aplicativos e do Edge/Store
    try {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableSmartScreen' 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'ShellSmartScreenLevel' 'Warn' 'String'
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled' 'Off' 'String'
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost' 'EnableWebContentEvaluation' 0
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost' 'PreventOverride' 0
        Write-Log 'SmartScreen de aplicativos e arquivos desligado.' 'ok'
    } catch {
        Write-Log "Nao consegui desligar o SmartScreen: $($_.Exception.Message)" 'warn'
    }

    # Filtro de reputacao de aplicativos da Seguranca do Windows
    try {
        $rep = 'HKLM:\SOFTWARE\Microsoft\Windows Defender Security Center\App and Browser protection'
        Set-Reg $rep 'SmartScreenEnabled' 0
        Set-Reg $rep 'SmartScreenPuaEnabled' 0
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen' 'ConfigureAppInstallControlEnabled' 1
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen' 'ConfigureAppInstallControl' 'Anywhere' 'String'
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\SmartScreenSettings' 'ConfigureAppInstallControl' 'Anywhere' 'String'
        Write-Log 'Instalacao liberada para programas de qualquer origem.' 'ok'
    } catch { }

    # Marca de origem (arquivos baixados) e aviso de "editor desconhecido"
    try {
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments' 'SaveZoneInformation' 1
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Associations' 'DefaultFileTypeRisk' 0x1808 'DWord'
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Associations' 'LowRiskFileTypes' '.exe;.msi;.bat;.cmd;.zip' 'String'
        Write-Log 'Aviso de arquivo de origem desconhecida desligado.' 'ok'
    } catch { }

    Write-Log 'Pronto: o notebook nao vai mais travar a abertura dos aplicativos depois de alguns dias.' 'ok'
}

# ---------- 9c. INSTALADORES NA AREA DE TRABALHO (v3.5.0) ----------
# A instalacao automatica foi retirada: o kit apenas deixa os instaladores
# oficiais prontos numa pasta na Area de Trabalho para o tecnico rodar a mao
# depois que todas as configuracoes do Windows terminarem.
function Copy-InstaladoresParaDesktop {
    Write-Log 'INSTALADORES NA AREA DE TRABALHO' 'title'

    $origem = Join-Path $script:Pasta 'Instaladores'
    if (-not (Test-Path $origem)) {
        Write-Log 'A pasta Instaladores nao esta no pendrive - nada a copiar.' 'warn'
        return
    }

    $desktop = [Environment]::GetFolderPath('Desktop')
    if (-not $desktop -or -not (Test-Path $desktop)) { $desktop = 'C:\Users\Public\Desktop' }
    $destino = Join-Path $desktop 'Instalar Programas LED'

    try {
        if (-not (Test-Path $destino)) { New-Item -Path $destino -ItemType Directory -Force | Out-Null }

        $arquivos = @(Get-ChildItem $origem -Include *.exe,*.msi -File -Recurse -ErrorAction SilentlyContinue |
                      Where-Object { $_.FullName -notmatch '(?i)\\Prontos\\' })
        if ($arquivos.Count -eq 0) {
            Write-Log 'Nenhum instalador (.exe ou .msi) encontrado na pasta Instaladores do pendrive.' 'warn'
            return
        }

        $copiados = 0
        foreach ($a in $arquivos) {
            try {
                Copy-Item $a.FullName -Destination (Join-Path $destino $a.Name) -Force -ErrorAction Stop
                try { Unblock-File (Join-Path $destino $a.Name) -ErrorAction SilentlyContinue } catch { }
                $copiados++
                Write-Log "   Copiado: $($a.Name)" 'ok'
            } catch {
                Write-Log "   Nao consegui copiar $($a.Name): $($_.Exception.Message)" 'warn'
            }
        }

        # Bilhete simples com a ordem recomendada
        $leia = @'
INSTALACAO DOS PROGRAMAS DO PAINEL DE LED

O notebook ja esta todo configurado. Falta so instalar os programas,
clicando duas vezes em cada instalador desta pasta, nesta ordem:

  1) AnyDesk
  2) LedVision
  3) NovaLCT

Aceite tudo o que o instalador pedir (drivers e plugins inclusive).
Depois de instalar, pode apagar esta pasta.
'@
        Set-Content -Path (Join-Path $destino 'LEIA ANTES.txt') -Value $leia -Encoding UTF8 -ErrorAction SilentlyContinue

        Write-Log "$copiados instalador(es) copiado(s) para: $destino" 'ok'
        Write-Log 'Instale os programas a mao por essa pasta, depois que o notebook reiniciar.' 'info'
    } catch {
        Write-Log "Falha ao preparar a pasta de instaladores: $($_.Exception.Message)" 'erro'
    }
}

# ---------- 10. REMOCAO EM MODO DE SEGURANCA (v2.7.0) ----------
# Quando a autoprotecao do antivirus bloqueia tudo no Windows normal, agendamos
# a desinstalacao para rodar no Modo de Seguranca, onde os drivers e servicos de
# autoprotecao nao sobem. O fluxo e: gravar o script de remocao no disco,
# registrar um RunOnce que funciona no modo seguro (nome iniciado com "*"),
# ligar o boot seguro com bcdedit e reiniciar. Ao entrar no modo seguro o script
# desinstala, desliga o boot seguro e reinicia o notebook no modo normal.

$script:PastaSafe = 'C:\PainelLED\ModoSeguro'

function Get-ScriptModoSeguro {
    @'
# Gerado pelo Configurador de Notebook - Global LED Experience
# Executado automaticamente dentro do Modo de Seguranca.
$log = 'C:\PainelLED\ModoSeguro\remocao-modo-seguro.log'
function L([string]$m) {
    $linha = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
    Add-Content -Path $log -Value $linha -ErrorAction SilentlyContinue
    Write-Host $linha
}
try { New-Item -ItemType Directory -Path 'C:\PainelLED\ModoSeguro' -Force | Out-Null } catch { }
L 'Iniciando a remocao do antivirus dentro do Modo de Seguranca.'

# 1. Encerra o que ainda estiver de pe (no modo seguro a autoprotecao nao sobe).
foreach ($p in (Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -like 'mc*' -or $_.ProcessName -like 'mfe*' -or
        $_.ProcessName -like '*Norton*' -or $_.ProcessName -like '*avast*' -or
        $_.ProcessName -like '*avg*' -or $_.ProcessName -like '*bdagent*' })) {
    try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; L "Processo encerrado: $($p.ProcessName)" } catch { }
}
foreach ($svc in (Get-Service -ErrorAction SilentlyContinue | Where-Object {
        $_.Name -like 'mc*' -or $_.Name -like 'mfe*' -or $_.DisplayName -like '*McAfee*' -or
        $_.DisplayName -like '*Norton*' -or $_.DisplayName -like '*Avast*' -or
        $_.DisplayName -like '*AVG*' -or $_.DisplayName -like '*Bitdefender*' })) {
    try { Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue } catch { }
    & sc.exe config $svc.Name start= disabled | Out-Null
    L "Servico desativado: $($svc.Name)"
}

# 2. Desinstaladores registrados no Windows.
$padrao = 'McAfee|Norton|Avast|AVG|Bitdefender|WebAdvisor|LiveSafe|Total Protection|Security Scan'
$chaves = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
$alvos = @(Get-ItemProperty $chaves -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and $_.DisplayName -match $padrao })
if ($alvos.Count -eq 0) { L 'Nenhum desinstalador de antivirus encontrado no registro.' }
foreach ($a in $alvos) {
    $cmd = $a.QuietUninstallString; if (-not $cmd) { $cmd = $a.UninstallString }
    if (-not $cmd) { continue }
    L "Desinstalando: $($a.DisplayName)"
    try {
        if ($cmd -match 'msiexec') {
            $codigo = ([regex]::Match($cmd, '\{[0-9A-Fa-f\-]{36}\}')).Value
            if ($codigo) { Start-Process 'msiexec.exe' -ArgumentList "/x $codigo /qn /norestart" -Wait -ErrorAction Stop }
        } else {
            $exe = $cmd; $args = ''
            if ($cmd -match '^\s*"([^"]+)"\s*(.*)$') { $exe = $matches[1]; $args = $matches[2] }
            elseif ($cmd -match '^\s*(\S+\.exe)\s*(.*)$') { $exe = $matches[1]; $args = $matches[2] }
            if ($args -notmatch '/S|/silent|/quiet|/qn') { $args = "$args /S /silent" }
            Start-Process $exe -ArgumentList $args -Wait -ErrorAction Stop
        }
        L "   Concluido: $($a.DisplayName)"
    } catch { L "   Falhou: $($a.DisplayName) - $($_.Exception.Message)" }
}

# 3. Removedor oficial da McAfee (MCPR.exe), se ele foi copiado do pendrive.
$mcpr = Get-ChildItem -Path 'C:\PainelLED\ModoSeguro' -Filter 'MCPR*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($mcpr) {
    L 'Executando o removedor oficial da McAfee (MCPR).'
    try { Start-Process $mcpr.FullName -Wait -ErrorAction Stop; L 'MCPR finalizado.' } catch { L "MCPR falhou: $($_.Exception.Message)" }
}

# 4. Sobras em disco e tarefas agendadas.
foreach ($pasta in @("$env:ProgramFiles\McAfee", "${env:ProgramFiles(x86)}\McAfee",
                     "$env:ProgramData\McAfee", "$env:ProgramFiles\Norton", "$env:ProgramData\Norton")) {
    if (Test-Path $pasta) {
        try { Remove-Item $pasta -Recurse -Force -ErrorAction Stop; L "Pasta removida: $pasta" }
        catch { L "Pasta em uso: $pasta" }
    }
}
Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object { $_.TaskName -match $padrao -or $_.TaskPath -match $padrao } |
    Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

# 5. Volta o boot normal e limpa o agendamento.
$restantes = @(Get-ItemProperty $chaves -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and $_.DisplayName -match $padrao })
if ($restantes.Count -eq 0) { L 'RESULTADO: nenhum antivirus de terceiros restante.' }
else { L "RESULTADO: ainda instalado -> $(($restantes.DisplayName) -join ', ')" }

& bcdedit.exe /deletevalue '{current}' safeboot | Out-Null
Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Name '*PainelLEDModoSeguro' -Force -ErrorAction SilentlyContinue
L 'Boot normal restaurado. Reiniciando em 15 segundos.'
Start-Sleep -Seconds 15
Restart-Computer -Force
'@
}

function Invoke-AgendarModoSeguro {
    Write-Log 'AGENDANDO A REMOCAO DO ANTIVIRUS NO MODO DE SEGURANCA' 'title'
    try {
        New-Item -ItemType Directory -Path $script:PastaSafe -Force | Out-Null
        $destino = Join-Path $script:PastaSafe 'RemoverAntivirus.ps1'
        Set-Content -Path $destino -Value (Get-ScriptModoSeguro) -Encoding UTF8 -Force
        Write-Log "Script de remocao gravado em $destino" 'ok'

        # Leva o removedor oficial junto, se ele estiver no pendrive.
        $mcpr = Get-ChildItem -Path (Join-Path $script:Pasta 'Instaladores') -Filter 'MCPR*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($mcpr) {
            Copy-Item $mcpr.FullName -Destination $script:PastaSafe -Force -ErrorAction SilentlyContinue
            Write-Log 'MCPR.exe copiado para a pasta do modo seguro.' 'ok'
        } else {
            Write-Log 'MCPR.exe nao encontrado no pendrive - sera usada apenas a desinstalacao padrao.' 'info'
        }

        # RunOnce com "*" no inicio do nome: e o unico que roda no Modo de Seguranca.
        $comando = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$destino`""
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' '*PainelLEDModoSeguro' $comando 'String'
        Write-Log 'Execucao automatica registrada para o proximo logon em modo seguro.' 'ok'

        # Instalador do Windows e rede precisam existir no modo seguro para os desinstaladores.
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Minimal\MSIServer' '(Default)' 'Service' 'String'
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot\Network\MSIServer' '(Default)' 'Service' 'String'

        $saida = & bcdedit.exe /set '{current}' safeboot minimal 2>&1
        if ($LASTEXITCODE -ne 0) { throw "bcdedit recusou o comando: $($saida -join ' ')" }
        Write-Log 'Proximo boot configurado para o Modo de Seguranca.' 'ok'
        Write-Log 'O notebook vai reiniciar em Modo de Seguranca, remover o antivirus sozinho e voltar ao Windows normal.' 'warn'
        Write-Log "O relatorio dessa etapa fica em $script:PastaSafe\remocao-modo-seguro.log" 'info'
        $global:Estado.Final = 'Modo de Seguranca agendado. Reinicie o notebook para a remocao comecar.'
        return $true
    } catch {
        Write-Log "Nao foi possivel agendar o Modo de Seguranca: $($_.Exception.Message)" 'erro'
        $global:Estado.Falhas = [int]$global:Estado.Falhas + 1
        return $false
    }
}

function Invoke-CancelarModoSeguro {
    Write-Log 'CANCELANDO O AGENDAMENTO DO MODO DE SEGURANCA' 'title'
    & bcdedit.exe /deletevalue '{current}' safeboot 2>&1 | Out-Null
    Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' -Name '*PainelLEDModoSeguro' -Force -ErrorAction SilentlyContinue
    Write-Log 'Boot normal restaurado e execucao automatica removida.' 'ok'
}

# Remocao guiada: tenta no Windows normal e, se a autoprotecao vencer, agenda o Modo de Seguranca.
function Invoke-RemoverAntivirusComFallback {
    Invoke-RemoverAntivirusTerceiros
    $script:CacheBloat = $null
    $restantes = @(Get-ProgramasFabrica -Forcar | Where-Object { $_.Fabricante -eq 'Antivirus' })
    if ($restantes.Count -eq 0) { return }
    Write-Log 'A autoprotecao impediu a remocao no Windows normal. Partindo para o Modo de Seguranca.' 'warn'
    if (Invoke-AgendarModoSeguro) {
        $global:Estado.Final = 'Antivirus resistente: reinicie o notebook para concluir no Modo de Seguranca.'
    }
}


# ##### FIM DAS FUNCOES #####
# Tudo acima desta linha e reaproveitado pela thread paralela que executa as
# tarefas (ver Start-Tarefa). Nao mova esta marca.

# ---------- INTERFACE (XAML) ----------
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Configurador de Notebook - Global LED Experience" Height="760" Width="980"
        WindowStartupLocation="CenterScreen" Background="#0E1116" ResizeMode="CanResize">
  <Window.Resources>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#E7EAF0"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Margin" Value="0,6,0,0"/>
    </Style>
    <Style TargetType="TextBlock">
      <Setter Property="Foreground" Value="#E7EAF0"/>
    </Style>
    <Style TargetType="GroupBox">
      <Setter Property="Foreground" Value="#FF6A1A"/>
      <Setter Property="BorderBrush" Value="#232A35"/>
      <Setter Property="Margin" Value="0,0,0,12"/>
      <Setter Property="Padding" Value="10"/>
    </Style>
    <Style TargetType="Button">
      <Setter Property="Background" Value="#FF6A1A"/>
      <Setter Property="Foreground" Value="#0E1116"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Padding" Value="14,8"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor" Value="Hand"/>
    </Style>
  </Window.Resources>
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <StackPanel Grid.Row="0" Margin="0,0,0,14">
      <TextBlock Text="GLOBAL LED EXPERIENCE - CONFIGURADOR DE NOTEBOOK" FontSize="20" FontWeight="Bold" Foreground="#FF6A1A"/>
      <TextBlock x:Name="txtVersao" Text="versao" Foreground="#9AA4B2" Margin="0,4,0,0"/>
      <TextBlock Text="Ordem recomendada: VERIFICAR - BACKUP - APLICAR - VALIDAR. Reinicie o notebook ao final." Foreground="#9AA4B2" Margin="0,2,0,0"/>
    </StackPanel>

    <Grid Grid.Row="1">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="400"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto" Margin="0,0,14,0">
        <StackPanel>
          <GroupBox>
            <GroupBox.Header>
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="0. Seguranca (recomendado)" Foreground="#FF6A1A" FontWeight="Bold"/>
                <TextBlock x:Name="stSeguranca" Text="" Foreground="#7CE38B" Margin="10,0,0,0" FontSize="11" VerticalAlignment="Center"/>
              </StackPanel>
            </GroupBox.Header>
            <StackPanel>
              <CheckBox x:Name="cbPreCheck" IsChecked="True" Content="Verificacao previa do sistema"/>
              <CheckBox x:Name="cbBackup" IsChecked="True" Content="Ponto de restauracao + backup das configuracoes"/>
              <TextBlock Text="O backup e salvo na pasta Backups do proprio pendrive e pode ser desfeito pelo botao RESTAURAR." Foreground="#7C8695" TextWrapping="Wrap" FontSize="11" Margin="22,2,0,0"/>
            </StackPanel>
          </GroupBox>

          <GroupBox>
            <GroupBox.Header>
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="0b. Limpeza de fabrica" Foreground="#FF6A1A" FontWeight="Bold"/>
                <TextBlock x:Name="stLimpeza" Text="" Foreground="#7CE38B" Margin="10,0,0,0" FontSize="11" VerticalAlignment="Center"/>
              </StackPanel>
            </GroupBox.Header>
            <StackPanel>
              <CheckBox x:Name="cbBloat" IsChecked="True" Content="Remover programas de fabrica (Lenovo / Samsung)"/>
              <CheckBox x:Name="cbMcAfee" IsChecked="True" Content="Remover McAfee e antivirus de teste"/>
              <CheckBox x:Name="cbDefender" IsChecked="True" Content="Desligar o Windows Defender"/>
              <TextBlock Text="Drivers, audio, video, teclas Fn e utilitarios de energia do fabricante NUNCA sao removidos. Com o Defender desligado o notebook fica sem antivirus ativo." Foreground="#7C8695" TextWrapping="Wrap" FontSize="11" Margin="22,2,0,0"/>
              <StackPanel Orientation="Horizontal" Margin="22,10,0,0">
                <Button x:Name="btnVerLista" Content="VER O QUE SERA REMOVIDO" Background="#232A35" Foreground="#E7EAF0"/>
                <Button x:Name="btnDesarmar" Content="0. ABRIR REMOVEDOR OFICIAL" Background="#3A2118" Foreground="#FFB08A" Margin="8,0,0,0"/>
                <Button x:Name="btnModoSeguro" Content="REMOVER PELO MODO DE SEGURANCA" Background="#3A2126" Foreground="#FF6A1A" Margin="8,0,0,0"/>
                <Button x:Name="btnTamper" Content="ABRIR PROTECAO CONTRA ADULTERACAO" Background="#232A35" Foreground="#FFB08A" Margin="8,0,0,0"/>
              </StackPanel>
              <TextBlock Text="Se a McAfee estiver bloqueando o configurador, use ABRIR REMOVEDOR OFICIAL. Esse botao abre diretamente o MCPR.exe assinado pela McAfee, sem tentar parar a protecao antes." Foreground="#7C8695" TextWrapping="Wrap" FontSize="11" Margin="22,6,0,0"/>
              <TextBlock Text="MODO DE SEGURANCA: o notebook reinicia sozinho em modo seguro, remove o antivirus sem a autoprotecao e volta ao Windows normal. Nao desligue o notebook durante o processo." Foreground="#7C8695" TextWrapping="Wrap" FontSize="11" Margin="22,4,0,0"/>


            </StackPanel>
          </GroupBox>

          <GroupBox>
            <GroupBox.Header>
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="1. Energia" Foreground="#FF6A1A" FontWeight="Bold"/>
                <TextBlock x:Name="stEnergia" Text="" Foreground="#7CE38B" Margin="10,0,0,0" FontSize="11" VerticalAlignment="Center"/>
              </StackPanel>
            </GroupBox.Header>
            <StackPanel>
              <CheckBox x:Name="cbEnergia" IsChecked="True" Content="Nunca suspender/desligar video (AC e bateria)"/>
              <TextBlock Text="Aplica em TODOS os planos de energia: fechar a tampa e botoes = NADA A FAZER, video e suspensao = NUNCA, na tomada e na bateria. Tambem: Desempenho Maximo, USB sem suspensao e sem protetor de tela." Foreground="#7C8695" TextWrapping="Wrap" FontSize="11" Margin="22,2,0,0"/>
            </StackPanel>
          </GroupBox>

          <GroupBox>
            <GroupBox.Header>
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="1b. Atualizacoes do Windows" Foreground="#FF6A1A" FontWeight="Bold"/>
                <TextBlock x:Name="stUpdate" Text="" Foreground="#7CE38B" Margin="10,0,0,0" FontSize="11" VerticalAlignment="Center"/>
              </StackPanel>
            </GroupBox.Header>
            <StackPanel>
              <CheckBox x:Name="cbUpdate" IsChecked="True" Content="Instalar atualizacoes na madrugada"/>
              <StackPanel Orientation="Horizontal" Margin="22,6,0,0">
                <TextBlock Text="Iniciar as" Foreground="#9AA4B2" VerticalAlignment="Center" FontSize="12"/>
                <ComboBox x:Name="cbHoraInicio" Width="80" Margin="6,0,14,0" SelectedIndex="1">
                  <ComboBoxItem Content="00:00"/><ComboBoxItem Content="00:30"/><ComboBoxItem Content="01:00"/>
                  <ComboBoxItem Content="01:30"/><ComboBoxItem Content="02:00"/><ComboBoxItem Content="02:30"/>
                  <ComboBoxItem Content="03:00"/><ComboBoxItem Content="03:30"/><ComboBoxItem Content="04:00"/>
                  <ComboBoxItem Content="22:00"/><ComboBoxItem Content="23:00"/>
                </ComboBox>
              </StackPanel>
              <CheckBox x:Name="cbReinicioAuto" IsChecked="False" Margin="22,8,0,0" Content="Reiniciar sozinho apos a atualizacao (so de madrugada, ate 06:00)"/>
              <TextBlock x:Name="txtJanela" Text="" Foreground="#7C8695" TextWrapping="Wrap" FontSize="11" Margin="22,6,0,0"/>
              <TextBlock Text="Busca e instala o que o Windows Update encontrar no horario escolhido. Desmarcado (padrao), o notebook NUNCA reinicia sozinho: nem depois de atualizacao, nem em horario fixo." Foreground="#7C8695" TextWrapping="Wrap" FontSize="11" Margin="22,2,0,0"/>
              <Button x:Name="btnSemReinicio" Content="DESLIGAR REINICIO AUTOMATICO AGORA" Background="#3A2118" Foreground="#FFB08A" Margin="22,10,0,0" HorizontalAlignment="Left"/>
              <TextBlock Text="Para notebook que ja foi configurado e esta reiniciando sozinho: desliga so o reinicio automatico, sem passar o resto do kit de novo." Foreground="#7C8695" TextWrapping="Wrap" FontSize="11" Margin="22,4,0,0"/>
            </StackPanel>
          </GroupBox>



          <GroupBox>
            <GroupBox.Header>
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="2. Interface" Foreground="#FF6A1A" FontWeight="Bold"/>
                <TextBlock x:Name="stInterface" Text="" Foreground="#7CE38B" Margin="10,0,0,0" FontSize="11" VerticalAlignment="Center"/>
              </StackPanel>
            </GroupBox.Header>
            <StackPanel>
              <CheckBox x:Name="cbNotif" IsChecked="True" Content="Desativar todas as notificacoes e dicas"/>
              <CheckBox x:Name="cbTaskbar" IsChecked="True" Content="Limpar barra de tarefas"/>
              <CheckBox x:Name="cbAparencia" IsChecked="True" Content="Tema escuro + papel de parede Global LED"/>
              <TextBlock Text="Usa o arquivo Wallpaper.jpg que esta no pendrive, aplica no desktop e na tela de bloqueio." Foreground="#7C8695" TextWrapping="Wrap" FontSize="11" Margin="22,2,0,0"/>
            </StackPanel>
          </GroupBox>

          <GroupBox>
            <GroupBox.Header>
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="3. Conta" Foreground="#FF6A1A" FontWeight="Bold"/>
                <TextBlock x:Name="stConta" Text="" Foreground="#7CE38B" Margin="10,0,0,0" FontSize="11" VerticalAlignment="Center"/>
              </StackPanel>
            </GroupBox.Header>
            <StackPanel>
              <CheckBox x:Name="cbOneDrive" IsChecked="True" Content="Remover / desconectar o OneDrive"/>
              <TextBlock Text="As configuracoes sao gravadas no usuario atual e no perfil padrao do Windows." Foreground="#7C8695" TextWrapping="Wrap" FontSize="11" Margin="22,2,0,0"/>
            </StackPanel>
          </GroupBox>


          <GroupBox>
            <GroupBox.Header>
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="4. Aplicativos (AnyDesk / LedVision / NovaLCT)" Foreground="#FF6A1A" FontWeight="Bold"/>
                <TextBlock x:Name="stApps" Text="" Foreground="#7CE38B" Margin="10,0,0,0" FontSize="11" VerticalAlignment="Center"/>
              </StackPanel>
            </GroupBox.Header>
            <StackPanel>
              <CheckBox x:Name="cbCopiarInst" IsChecked="True" Content="Copiar os instaladores para a area de trabalho (instalar a mao depois)"/>
              <TextBlock Text="O kit cria a pasta 'Instalar Programas LED' na area de trabalho com AnyDesk, LedVision e NovaLCT para voce instalar em 2 minutos no final." Foreground="#9AA6B2" TextWrapping="Wrap" FontSize="11" Margin="22,2,0,0"/>
            </StackPanel>
          </GroupBox>

          <GroupBox>
            <GroupBox.Header>
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="5. Extras e conferencia" Foreground="#FF6A1A" FontWeight="Bold"/>
                <TextBlock x:Name="stExtras" Text="" Foreground="#7CE38B" Margin="10,0,0,0" FontSize="11" VerticalAlignment="Center"/>
              </StackPanel>
            </GroupBox.Header>
            <StackPanel>
              <CheckBox x:Name="cbExtras" IsChecked="True" Content="Rede sempre ligada, sem brilho adaptativo, sem autoplay"/>
              <CheckBox x:Name="cbValidar" IsChecked="True" Content="Validar tudo no final e mostrar o resultado"/>
            </StackPanel>
          </GroupBox>
        </StackPanel>
      </ScrollViewer>

      <Border Grid.Column="1" Background="#070A0E" BorderBrush="#232A35" BorderThickness="1" CornerRadius="6">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <!-- cabecalho do console -->
          <Grid Grid.Row="0" Background="#0E1116" Margin="1,1,1,0">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Orientation="Horizontal" Margin="10,8,0,8">
              <Ellipse x:Name="ledConsole" Width="9" Height="9" Fill="#3A4250" VerticalAlignment="Center"/>
              <TextBlock Text="CONSOLE EM TEMPO REAL" Foreground="#FF6A1A" FontWeight="Bold" FontSize="11" Margin="8,0,0,0" VerticalAlignment="Center"/>
              <TextBlock x:Name="txtConsoleEstado" Text="aguardando" Foreground="#7C8695" FontSize="11" Margin="8,0,0,0" VerticalAlignment="Center"/>
            </StackPanel>
            <StackPanel Grid.Column="1" Orientation="Horizontal" Margin="0,8,10,8">
              <TextBlock x:Name="txtContOk" Text="0 OK" Foreground="#7CE38B" FontSize="11" FontFamily="Consolas" VerticalAlignment="Center" Margin="0,0,10,0"/>
              <TextBlock x:Name="txtContWarn" Text="0 avisos" Foreground="#F2C14E" FontSize="11" FontFamily="Consolas" VerticalAlignment="Center" Margin="0,0,10,0"/>
              <TextBlock x:Name="txtContErro" Text="0 erros" Foreground="#E2666C" FontSize="11" FontFamily="Consolas" VerticalAlignment="Center"/>
            </StackPanel>
          </Grid>

          <!-- barra de ferramentas do console -->
          <Grid Grid.Row="1" Margin="10,0,10,6">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <StackPanel Orientation="Horizontal">
              <CheckBox x:Name="cbAutoScroll" IsChecked="True" Content="Rolar sozinho" FontSize="11" Margin="0,2,12,0"/>
              <CheckBox x:Name="cbSoProblemas" IsChecked="False" Content="Somente avisos e erros" FontSize="11" Margin="0,2,12,0"/>
              <CheckBox x:Name="cbHora" IsChecked="True" Content="Mostrar hora" FontSize="11" Margin="0,2,0,0"/>
            </StackPanel>
            <StackPanel Grid.Column="1" Orientation="Horizontal">
              <Button x:Name="btnCopiarLog" Content="COPIAR" Background="#232A35" Foreground="#E7EAF0" FontSize="10" Padding="8,4" Margin="0,0,6,0"/>
              <Button x:Name="btnLimparLog" Content="LIMPAR" Background="#232A35" Foreground="#E7EAF0" FontSize="10" Padding="8,4" Margin="0"/>
            </StackPanel>
          </Grid>

          <RichTextBox x:Name="rtLog" Grid.Row="2" Margin="10,0,10,0" Background="Transparent" Foreground="#9AA4B2"
                       BorderThickness="0" FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                       VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled"
                       IsDocumentEnabled="True"/>

          <TextBlock x:Name="txtUltimaLinha" Grid.Row="3" Margin="10,6,10,10" Foreground="#7C8695" FontFamily="Consolas"
                     FontSize="11" TextTrimming="CharacterEllipsis" Text="Console pronto."/>
        </Grid>
      </Border>

    </Grid>

    <Border Grid.Row="2" Background="#141A22" BorderBrush="#232A35" BorderThickness="1" CornerRadius="6" Padding="12,10" Margin="0,14,0,0">
      <StackPanel>
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
          </Grid.ColumnDefinitions>
          <TextBlock x:Name="txtEtapa" Grid.Column="0" Text="Pronto para comecar." Foreground="#E7EAF0" FontSize="12" TextTrimming="CharacterEllipsis"/>
          <TextBlock x:Name="txtTempo" Grid.Column="1" Text="" Foreground="#9AA4B2" FontSize="12" FontFamily="Consolas" Margin="10,0,0,0"/>
        </Grid>
        <ProgressBar x:Name="pbProgresso" Height="12" Margin="0,8,0,0" Minimum="0" Maximum="100" Value="0"
                     Background="#0E1116" Foreground="#FF6A1A" BorderBrush="#232A35"/>
      </StackPanel>
    </Border>

    <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="0,14,0,0">
      <Button x:Name="btnVerificar" Content="1. VERIFICAR" Background="#232A35" Foreground="#E7EAF0"/>
      <Button x:Name="btnBackup" Content="2. BACKUP" Background="#232A35" Foreground="#E7EAF0"/>
      <Button x:Name="btnAplicar" Content="3. APLICAR SELECIONADOS"/>
      <Button x:Name="btnValidar" Content="4. VALIDAR" Background="#232A35" Foreground="#E7EAF0"/>
      <Button x:Name="btnTodos" Content="MARCAR TUDO" Background="#232A35" Foreground="#E7EAF0"/>
    </StackPanel>

    <StackPanel Grid.Row="4" Orientation="Horizontal" Margin="0,8,0,0">
      <Button x:Name="btnSalvar" Content="SALVAR RELATORIO" Background="#232A35" Foreground="#E7EAF0"/>
      <Button x:Name="btnRestaurar" Content="RESTAURAR BACKUP" Background="#232A35" Foreground="#E7EAF0"/>
      <Button x:Name="btnAtualizar" Content="VERIFICAR ATUALIZACAO" Background="#232A35" Foreground="#E7EAF0"/>
      <Button x:Name="btnTutorial" Content="ABRIR TUTORIAL" Background="#232A35" Foreground="#E7EAF0"/>
      <Button x:Name="btnReiniciar" Content="REINICIAR PC" Background="#3A2126" Foreground="#FF6A1A"/>
      <TextBlock x:Name="txtStatus" Text="Pronto." VerticalAlignment="Center" Foreground="#9AA4B2" Margin="12,0,0,0"/>
    </StackPanel>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$win = [Windows.Markup.XamlReader]::Load($reader)

$ctl = @{}
foreach ($n in @('cbPreCheck','cbBackup','cbEnergia','cbUpdate','cbNotif','cbTaskbar','cbAparencia','cbOneDrive',
                 'cbCopiarInst','cbExtras','cbValidar','btnSemReinicio',
                 'cbBloat','cbMcAfee','cbDefender','btnVerLista','btnDesarmar','btnModoSeguro','btnTamper','stLimpeza',
                 'cbHoraInicio','cbReinicioAuto','txtJanela',
                 'rtLog','txtVersao','txtStatus','btnVerificar','btnBackup','btnAplicar','btnValidar','btnTodos',
                 'btnSalvar','btnRestaurar','btnAtualizar','btnTutorial','btnReiniciar',
                 'pbProgresso','txtEtapa','txtTempo',
                 'cbAutoScroll','cbSoProblemas','cbHora','btnCopiarLog','btnLimparLog',
                 'ledConsole','txtConsoleEstado','txtContOk','txtContWarn','txtContErro','txtUltimaLinha',
                 'stSeguranca','stEnergia','stUpdate','stInterface','stConta','stApps','stExtras')) {
    $ctl[$n] = $win.FindName($n)
}

# =====================================================================
#  CONSOLE EM TEMPO REAL
#  Cada linha e guardada com o seu tipo (ok / aviso / erro / titulo) e
#  desenhada colorida no painel. Da para filtrar so os problemas, parar
#  a rolagem automatica, copiar tudo ou limpar a tela.
# =====================================================================
$script:LinhasLog = New-Object System.Collections.ArrayList
$script:ContOk = 0; $script:ContWarn = 0; $script:ContErro = 0

$script:CoresLog = @{
    'ok'    = '#7CE38B'
    'warn'  = '#F2C14E'
    'erro'  = '#E2666C'
    'title' = '#FF6A1A'
    'info'  = '#9AA4B2'
}

function Get-BrushLog([string]$Level) {
    $hex = $script:CoresLog[$Level]
    if (-not $hex) { $hex = $script:CoresLog['info'] }
    return (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($hex)))
}

function Test-LinhaVisivel([string]$Level) {
    if (-not $ctl['cbSoProblemas'].IsChecked) { return $true }
    return ($Level -eq 'warn' -or $Level -eq 'erro' -or $Level -eq 'title')
}

function New-RunLog($Registro) {
    $texto = if ($ctl['cbHora'].IsChecked) { "$($Registro.Hora)  $($Registro.Texto)" } else { $Registro.Texto }
    $run = New-Object System.Windows.Documents.Run $texto
    $run.Foreground = Get-BrushLog $Registro.Nivel
    if ($Registro.Nivel -eq 'title') { $run.FontWeight = [System.Windows.FontWeights]::Bold }
    $p = New-Object System.Windows.Documents.Paragraph $run
    $p.Margin = New-Object System.Windows.Thickness 0
    if ($Registro.Nivel -eq 'title') { $p.Margin = New-Object System.Windows.Thickness 0,8,0,2 }
    return $p
}

function Update-ContadoresLog {
    $ctl['txtContOk'].Text   = "$script:ContOk OK"
    $ctl['txtContWarn'].Text = "$script:ContWarn avisos"
    $ctl['txtContErro'].Text = "$script:ContErro erros"
}

function Add-LinhasConsole($Registros) {
    if (-not $Registros -or $Registros.Count -eq 0) { return }
    $doc = $ctl['rtLog'].Document
    foreach ($r in $Registros) {
        [void]$script:LinhasLog.Add($r)
        switch ($r.Nivel) {
            'ok'   { $script:ContOk++ }
            'warn' { $script:ContWarn++ }
            'erro' { $script:ContErro++ }
        }
        if (Test-LinhaVisivel $r.Nivel) { [void]$doc.Blocks.Add((New-RunLog $r)) }
    }
    $ultimo = $Registros[$Registros.Count - 1]
    $ctl['txtUltimaLinha'].Text = $ultimo.Texto
    $ctl['txtUltimaLinha'].Foreground = Get-BrushLog $ultimo.Nivel
    Update-ContadoresLog
    if ($ctl['cbAutoScroll'].IsChecked) { $ctl['rtLog'].ScrollToEnd() }
}

# usada pelo Write-Log quando ele roda na propria thread da janela
$script:ConsoleAdd = {
    param([string]$Nivel,[string]$Hora,[string]$Texto)
    Add-LinhasConsole @(@{ Nivel = $Nivel; Hora = $Hora; Texto = $Texto })
}

function Redraw-Console {
    $doc = $ctl['rtLog'].Document
    $doc.Blocks.Clear()
    foreach ($r in $script:LinhasLog) {
        if (Test-LinhaVisivel $r.Nivel) { [void]$doc.Blocks.Add((New-RunLog $r)) }
    }
    if ($ctl['cbAutoScroll'].IsChecked) { $ctl['rtLog'].ScrollToEnd() }
}

function Get-TextoLog {
    $sb = New-Object System.Text.StringBuilder
    foreach ($r in $script:LinhasLog) { [void]$sb.AppendLine("$($r.Hora)  $($r.Texto)") }
    return $sb.ToString()
}

function Set-EstadoConsole([string]$Texto,[string]$Cor) {
    $ctl['txtConsoleEstado'].Text = $Texto
    $ctl['ledConsole'].Fill = (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($Cor)))
}

$ctl['cbSoProblemas'].Add_Checked({ Redraw-Console })
$ctl['cbSoProblemas'].Add_Unchecked({ Redraw-Console })
$ctl['cbHora'].Add_Checked({ Redraw-Console })
$ctl['cbHora'].Add_Unchecked({ Redraw-Console })
$ctl['cbAutoScroll'].Add_Checked({ $ctl['rtLog'].ScrollToEnd() })
$ctl['btnCopiarLog'].Add_Click({
    try { [System.Windows.Clipboard]::SetText((Get-TextoLog)); $ctl['txtStatus'].Text = 'Log copiado para a area de transferencia.' } catch { }
})
$ctl['btnLimparLog'].Add_Click({
    $script:LinhasLog.Clear()
    $script:ContOk = 0; $script:ContWarn = 0; $script:ContErro = 0
    $ctl['rtLog'].Document.Blocks.Clear()
    $ctl['txtUltimaLinha'].Text = 'Console limpo.'
    Update-ContadoresLog
})

$ctl['txtVersao'].Text = "Versao $script:Versao  -  tutorial e historico em $script:SiteUrl/versoes"


# Horarios escolhidos na interface para o Windows Update
function Get-HoraSel([string]$Nome, [string]$Padrao) {
    $item = $ctl[$Nome].SelectedItem
    if ($item -and $item.Content) { return [string]$item.Content }
    return $Padrao
}
function Update-TextoJanela {
    try {
        $ini = Get-HoraSel 'cbHoraInicio' '00:30'
        if ([bool]$ctl['cbReinicioAuto'].IsChecked) {
            $ctl['txtJanela'].Text = ("Atualizacoes as {0}. Reinicia sozinho so entre {0} e 06:00, e so se a atualizacao pedir." -f $ini)
        } else {
            $ctl['txtJanela'].Text = ("Atualizacoes as {0}. O notebook nunca reinicia sozinho." -f $ini)
        }
    } catch {
        $ctl['txtJanela'].Text = 'Escolha o horario de inicio das atualizacoes.'
    }
}
$ctl['cbHoraInicio'].Add_SelectionChanged({ Update-TextoJanela })
$ctl['cbReinicioAuto'].Add_Checked({ Update-TextoJanela })
$ctl['cbReinicioAuto'].Add_Unchecked({ Update-TextoJanela })
Update-TextoJanela


Write-Log "Configurador v$script:Versao executando como Administrador em $env:COMPUTERNAME"
Write-Log "Windows: $((Get-CimInstance Win32_OperatingSystem).Caption)"
Write-Log 'Clique em 1. VERIFICAR para conferir o notebook antes de aplicar.'

$script:TodasMarcadas = $false
$ctl['btnTodos'].Add_Click({
    $alvo = -not $script:TodasMarcadas
    $conta = 0
    foreach ($n in @('cbPreCheck','cbBackup','cbBloat','cbMcAfee','cbDefender',
                     'cbEnergia','cbUpdate','cbNotif','cbTaskbar','cbAparencia','cbOneDrive',
                     'cbCopiarInst','cbExtras','cbValidar')) {
        try {
            $c = $ctl[$n]
            if ($c) { $c.IsChecked = $alvo; $conta++ }
        } catch { }
    }
    $script:TodasMarcadas = $alvo
    $ctl['btnTodos'].Content = $(if ($alvo) { 'DESMARCAR TUDO' } else { 'MARCAR TUDO' })
    Write-Log $(if ($alvo) { "$conta opcoes marcadas." } else { "$conta opcoes desmarcadas." }) 'ok'
})

$ctl['btnTamper'].Add_Click({
    try {
        Start-Process 'windowsdefender://threatsettings' -ErrorAction Stop
        Write-Log 'Abri a tela de Protecao contra virus. Desligue a "Protecao contra adulteracao" e clique em APLICAR de novo.' 'info'
    } catch {
        Write-Log 'Nao consegui abrir a Seguranca do Windows. Abra manualmente: Seguranca do Windows > Protecao contra virus e ameacas > Gerenciar configuracoes.' 'warn'
    }
})

# ---------- Janela "ver o que sera removido" (v2.5.0) ----------
# $global:SelecaoBloat = $null significa "usar a lista padrao segura".
$global:SelecaoBloat = $null

$ctl['btnVerLista'].Add_Click({
    $ctl['txtStatus'].Text = 'Procurando os programas de fabrica...'
    $win.Cursor = [System.Windows.Input.Cursors]::Wait
    try { $itens = @(Get-ProgramasFabrica -Forcar) } catch { $itens = @() }
    $win.Cursor = [System.Windows.Input.Cursors]::Arrow
    $ctl['txtStatus'].Text = "$($itens.Count) programa(s) de fabrica encontrado(s)."

    if ($itens.Count -eq 0) {
        [System.Windows.MessageBox]::Show('Nenhum programa de fabrica foi encontrado neste notebook.','Limpeza de fabrica','OK','Information') | Out-Null
        return
    }

    $w = New-Object System.Windows.Window
    $w.Title = 'O que sera removido'
    $w.Width = 560; $w.Height = 560
    $w.WindowStartupLocation = 'CenterOwner'
    $w.Owner = $win
    $w.Background = (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString('#0E1116')))

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = New-Object System.Windows.Thickness 14
    foreach ($h in @('Auto','*','Auto')) {
        $rd = New-Object System.Windows.Controls.RowDefinition
        $rd.Height = [System.Windows.GridLength]::Auto
        if ($h -eq '*') { $rd.Height = New-Object System.Windows.GridLength 1,'Star' }
        $grid.RowDefinitions.Add($rd)
    }

    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = 'Desmarque o que deve ficar no notebook. Drivers e utilitarios de energia nao aparecem nesta lista.'
    $tb.TextWrapping = 'Wrap'
    $tb.Margin = New-Object System.Windows.Thickness 0,0,0,10
    $tb.Foreground = (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString('#E7EAF0')))
    [void]$grid.Children.Add($tb)
    [System.Windows.Controls.Grid]::SetRow($tb, 0)

    $sv = New-Object System.Windows.Controls.ScrollViewer
    $sv.VerticalScrollBarVisibility = 'Auto'
    $sp = New-Object System.Windows.Controls.StackPanel
    $caixas = @()
    foreach ($it in $itens) {
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = "[$($it.Fabricante)] $($it.Nome)"
        $cb.Tag = $it.Nome
        $cb.IsChecked = $true
        $cb.Margin = New-Object System.Windows.Thickness 0,5,0,0
        $cb.Foreground = (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString('#E7EAF0')))
        [void]$sp.Children.Add($cb)
        $caixas += $cb
    }
    $sv.Content = $sp
    [void]$grid.Children.Add($sv)
    [System.Windows.Controls.Grid]::SetRow($sv, 1)

    $linha = New-Object System.Windows.Controls.StackPanel
    $linha.Orientation = 'Horizontal'
    $linha.HorizontalAlignment = 'Right'
    $linha.Margin = New-Object System.Windows.Thickness 0,12,0,0
    $btnOk = New-Object System.Windows.Controls.Button
    $btnOk.Content = 'CONFIRMAR'
    $btnOk.Padding = New-Object System.Windows.Thickness 16,6,16,6
    $btnCancel = New-Object System.Windows.Controls.Button
    $btnCancel.Content = 'CANCELAR'
    $btnCancel.Margin = New-Object System.Windows.Thickness 10,0,0,0
    $btnCancel.Padding = New-Object System.Windows.Thickness 16,6,16,6
    [void]$linha.Children.Add($btnOk)
    [void]$linha.Children.Add($btnCancel)
    [void]$grid.Children.Add($linha)
    [System.Windows.Controls.Grid]::SetRow($linha, 2)

    $btnOk.Add_Click({
        # IMPORTANTE: usar escopo global. Dentro de GetNewClosure() o prefixo
        # $script: aponta para o modulo temporario da closure, e a selecao do
        # tecnico se perdia (tudo acabava marcado como "mantido pelo tecnico").
        $global:SelecaoBloat = @($caixas | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag } | Where-Object { $_ })
        $ctl['txtStatus'].Text = "$($global:SelecaoBloat.Count) programa(s) marcado(s) para remocao."
        $w.Close()
    }.GetNewClosure())
    $btnCancel.Add_Click({ $w.Close() }.GetNewClosure())


    $w.Content = $grid
    $w.ShowDialog() | Out-Null
})


# =====================================================================
#  MOTOR DE TAREFAS EM SEGUNDO PLANO (v2.3.0)
#  O trabalho pesado sai da thread da janela e vai para uma thread
#  paralela. A janela continua respondendo, mostra a barra de progresso
#  e recebe o log em lotes a cada 200 ms.
# =====================================================================
$script:Prelude = ((Get-Content -LiteralPath $PSCommandPath -Raw -Encoding UTF8) -split '# ##### FIM DAS FUNCOES #####')[0]
$script:TarefaAtiva  = $false
$script:EstadoTarefa = $null
$script:GrupoAtual   = $null
$script:MapaGrupos = [ordered]@{
    'Seguranca' = 'stSeguranca'; 'Energia' = 'stEnergia'; 'Update' = 'stUpdate'
    'Interface' = 'stInterface'; 'Conta' = 'stConta'; 'Apps' = 'stApps'; 'Extras' = 'stExtras'
    'Limpeza' = 'stLimpeza'
}

$script:CtlConsole = @('cbAutoScroll','cbSoProblemas','cbHora','btnCopiarLog','btnLimparLog')
function Set-ControlesHabilitados([bool]$Ligado) {
    foreach ($k in $ctl.Keys) {
        if ($script:CtlConsole -contains $k) { continue }  # o console continua utilizavel durante a execucao
        $c = $ctl[$k]
        if ($c -is [System.Windows.Controls.Button] -or
            $c -is [System.Windows.Controls.CheckBox] -or
            $c -is [System.Windows.Controls.ComboBox]) { $c.IsEnabled = $Ligado }
    }
    $win.Cursor = if ($Ligado) { [System.Windows.Input.Cursors]::Arrow } else { [System.Windows.Input.Cursors]::Wait }
}


function Get-Opcoes {
    @{
        PreCheck  = [bool]$ctl['cbPreCheck'].IsChecked
        Backup    = [bool]$ctl['cbBackup'].IsChecked
        Bloat     = [bool]$ctl['cbBloat'].IsChecked
        McAfee    = [bool]$ctl['cbMcAfee'].IsChecked
        Defender  = [bool]$ctl['cbDefender'].IsChecked
        SelBloat  = @(@($global:SelecaoBloat) | Where-Object { "$_".Trim() })
        CopiarInst = [bool]$ctl['cbCopiarInst'].IsChecked
        Energia   = [bool]$ctl['cbEnergia'].IsChecked
        Notif     = [bool]$ctl['cbNotif'].IsChecked
        Update    = [bool]$ctl['cbUpdate'].IsChecked
        OneDrive  = [bool]$ctl['cbOneDrive'].IsChecked
        Extras    = [bool]$ctl['cbExtras'].IsChecked
        Aparencia = [bool]$ctl['cbAparencia'].IsChecked
        Taskbar   = [bool]$ctl['cbTaskbar'].IsChecked
        Validar   = [bool]$ctl['cbValidar'].IsChecked
        HoraIni   = (Get-HoraSel 'cbHoraInicio' '00:30')
        ReinicioAuto = [bool]$ctl['cbReinicioAuto'].IsChecked
    }
}

function Sync-Interface {
    $e = $script:EstadoTarefa
    if (-not $e) { return }

    # log em lote: cada linha vem como "nivel<TAB>hora<TAB>texto"
    $lote = New-Object System.Collections.ArrayList
    $linha = $null
    $n = 0
    while ($n -lt 500 -and $e.Fila.TryDequeue([ref]$linha)) {
        $p = ([string]$linha) -split "`t", 3
        if ($p.Count -eq 3) {
            [void]$lote.Add(@{ Nivel = $p[0]; Hora = $p[1]; Texto = $p[2] })
        } else {
            [void]$lote.Add(@{ Nivel = 'info'; Hora = (Get-Date -Format 'HH:mm:ss'); Texto = [string]$linha })
        }
        $n++
    }
    if ($lote.Count -gt 0) { Add-LinhasConsole $lote }


    if ([int]$e.Total -gt 0) {
        $ctl['pbProgresso'].IsIndeterminate = $false
        $ctl['pbProgresso'].Maximum = [int]$e.Total
        $ctl['pbProgresso'].Value = [Math]::Min([int]$e.Passo, [int]$e.Total)
        $ctl['txtEtapa'].Text = "Etapa $([int]$e.Passo) de $([int]$e.Total) - $($e.Texto)"
    } else {
        $ctl['txtEtapa'].Text = [string]$e.Texto
    }

    $dec = (Get-Date) - $script:InicioTarefa
    $ctl['txtTempo'].Text = ('{0:00}:{1:00}' -f [int]$dec.TotalMinutes, $dec.Seconds)

    if ([string]$e.Grupo -ne [string]$script:GrupoAtual) {
        if ($script:GrupoAtual -and $script:MapaGrupos[$script:GrupoAtual]) {
            $ctl[$script:MapaGrupos[$script:GrupoAtual]].Text = 'concluido'
        }
        $script:GrupoAtual = [string]$e.Grupo
        if ($e.Grupo -and $script:MapaGrupos[[string]$e.Grupo]) {
            $ctl[$script:MapaGrupos[[string]$e.Grupo]].Text = 'em andamento...'
        }
    }
}

function Save-Relatorio {
    $arquivo = Join-Path ([Environment]::GetFolderPath('Desktop')) ("Relatorio-Painel-{0}.txt" -f (Get-Date -Format 'yyyy-MM-dd_HH-mm'))
    (Get-TextoLog) | Out-File -FilePath $arquivo -Encoding UTF8
    return $arquivo
}

function Stop-Tarefa {
    $script:Timer.Stop()
    $e = $script:EstadoTarefa
    while ($e.Fila.Count -gt 0) { Sync-Interface }
    Sync-Interface

    try { $script:PSInst.EndInvoke($script:Handle) | Out-Null } catch { }
    foreach ($err in $script:PSInst.Streams.Error) { Write-Log "Erro interno: $err" 'erro' }
    $script:PSInst.Dispose()
    $script:RSpace.Close(); $script:RSpace.Dispose()
    $script:PSInst = $null; $script:Handle = $null

    if (-not $script:TarefaLeve) {
        foreach ($nome in $script:MapaGrupos.Values) {
            if ($ctl[$nome].Text -eq 'em andamento...') { $ctl[$nome].Text = 'concluido' }
        }
        $ctl['pbProgresso'].IsIndeterminate = $false
        $ctl['pbProgresso'].Value = if ([int]$e.Total -gt 0) { [int]$e.Total } else { 0 }
        $ctl['txtEtapa'].Text = [string]$e.Final
    }
    $script:GrupoAtual = $null

    if ($e.SalvarRelatorio) {
        $arq = Save-Relatorio
        Write-Log "Relatorio salvo automaticamente em: $arq" 'ok'
    }

    if (-not $script:TarefaLeve) {
        $texto = [string]$e.Final
        if ([int]$e.Falhas -gt 0) { $texto = "$texto - $([int]$e.Falhas) ponto(s) de atencao" }
        $ctl['txtStatus'].Text = $texto
        if ($script:ContErro -gt 0)      { Set-EstadoConsole 'concluido com erros' '#E2666C' }
        elseif ([int]$e.Falhas -gt 0)    { Set-EstadoConsole 'concluido com avisos' '#F2C14E' }
        else                             { Set-EstadoConsole 'concluido' '#7CE38B' }
    }

    if (-not $script:TarefaLeve) { Set-ControlesHabilitados $true }
    $script:TarefaAtiva = $false

    if ($e.NovaVersao) {
        $r = [System.Windows.MessageBox]::Show("Versao $($e.NovaVersao) disponivel.`nAbrir a pagina de versoes agora?",'Atualizacao','YesNo','Information')
        if ($r -eq 'Yes') { Start-Process "$script:SiteUrl/versoes" }
    }
}

$script:Timer = New-Object System.Windows.Threading.DispatcherTimer
$script:Timer.Interval = [TimeSpan]::FromMilliseconds(200)
$script:Timer.Add_Tick({
    Sync-Interface
    if ($script:Handle -and $script:Handle.IsCompleted) { Stop-Tarefa }
})

function Start-Tarefa {
    param(
        [string]$Nome,
        [scriptblock]$Corpo,
        [int]$Total = 0,
        [string]$Final = '',
        [switch]$Leve   # tarefa de fundo que nao bloqueia os botoes
    )
    if ($script:TarefaAtiva) {
        [System.Windows.MessageBox]::Show('Ja existe uma tarefa em andamento. Espere a barra de progresso terminar.','Aguarde','OK','Information') | Out-Null
        return
    }
    $script:TarefaAtiva = $true
    $script:TarefaLeve  = [bool]$Leve
    $script:InicioTarefa = Get-Date
    $script:GrupoAtual = $null

    $e = [hashtable]::Synchronized(@{})
    $e.Fila  = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
    $e.Texto = $Nome
    $e.Passo = 0
    $e.Total = $Total
    $e.Grupo = ''
    $e.Falhas = 0
    $e.NovaVersao = $null
    $e.SalvarRelatorio = $false
    $e.Final = if ($Final) { $Final } else { "$Nome - concluido." }
    $script:EstadoTarefa = $e

    if (-not $Leve) {
        Set-ControlesHabilitados $false
        foreach ($nome in $script:MapaGrupos.Values) { $ctl[$nome].Text = '' }
        $ctl['txtStatus'].Text = $Nome
        $ctl['txtEtapa'].Text  = $Nome
        $ctl['txtTempo'].Text  = '00:00'
        $ctl['pbProgresso'].Value = 0
        $ctl['pbProgresso'].IsIndeterminate = ($Total -le 0)
        Set-EstadoConsole "executando: $Nome" '#FF6A1A'
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions  = 'ReuseThread'
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('Estado', $e)
    $rs.SessionStateProxy.SetVariable('PastaPendrive', $script:Pasta)
    $rs.SessionStateProxy.SetVariable('Opcoes', (Get-Opcoes))

    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    [void]$ps.AddScript($script:Prelude + "`r`n" + $Corpo.ToString())

    $script:RSpace = $rs
    $script:PSInst = $ps
    $script:Handle = $ps.BeginInvoke()
    $script:Timer.Start()
}

# ---------- BOTOES ----------
$ctl['btnDesarmar'].Add_Click({
    # Nao tenta encerrar processos/servicos: essa era justamente a acao que
    # acionava a autoprotecao antes que qualquer coisa aparecesse na interface.
    $mcpr = Get-ChildItem -Path (Join-Path $script:Pasta 'Instaladores') -Filter 'MCPR*.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $mcpr) {
        [System.Windows.MessageBox]::Show(
            "O removedor oficial MCPR.exe nao foi encontrado." + [Environment]::NewLine + [Environment]::NewLine +
            "Baixe o MCPR no site oficial da McAfee e coloque o arquivo dentro da pasta Instaladores do pendrive. Depois abra o configurador novamente e clique neste botao.",
            'Removedor oficial nao encontrado', 'OK', 'Warning') | Out-Null
        return
    }
    try {
        $ctl['txtStatus'].Text = 'Abrindo o removedor oficial da McAfee...'
        Start-Process -FilePath $mcpr.FullName -Verb RunAs -ErrorAction Stop
        Write-Log "Removedor oficial aberto: $($mcpr.Name)" 'ok'
        [System.Windows.MessageBox]::Show(
            'Conclua todas as etapas na janela do removedor oficial da McAfee. Reinicie o notebook quando ele solicitar.',
            'Removedor oficial aberto', 'OK', 'Information') | Out-Null
    } catch {
        Write-Log "O Windows ou a McAfee bloqueou a abertura do MCPR: $($_.Exception.Message)" 'erro'
        [System.Windows.MessageBox]::Show(
            "Nao foi possivel abrir o MCPR.exe." + [Environment]::NewLine + [Environment]::NewLine +
            "Abra a pasta Instaladores do pendrive, clique com o botao direito no MCPR.exe e escolha Executar como administrador.",
            'Abertura bloqueada', 'OK', 'Error') | Out-Null
    }
})

$ctl['btnModoSeguro'].Add_Click({
    $r = [System.Windows.MessageBox]::Show(
        "O notebook vai reiniciar em Modo de Seguranca, remover o antivirus automaticamente e voltar sozinho ao Windows normal." + [Environment]::NewLine + [Environment]::NewLine +
        "Salve seus arquivos antes de continuar. Deseja reiniciar agora?" + [Environment]::NewLine +
        "(Escolha NAO para apenas agendar e reiniciar depois)",
        'Remocao pelo Modo de Seguranca', 'YesNoCancel', 'Warning')
    if ($r -eq 'Cancel') { return }
    $reiniciar = ($r -eq 'Yes')
    Start-Tarefa -Nome 'Agendando o Modo de Seguranca' -Final 'Modo de Seguranca agendado.' -Corpo ([scriptblock]::Create(@"
        Set-Etapa 'Preparando a remocao em Modo de Seguranca' 0 'Limpeza'
        if (Invoke-AgendarModoSeguro) {
            if (`$$reiniciar) {
                Write-Log 'Reiniciando em Modo de Seguranca em 10 segundos...' 'warn'
                Start-Sleep -Seconds 10
                Restart-Computer -Force
            } else {
                Write-Log 'Agendado. Reinicie o notebook quando quiser para a remocao comecar.' 'ok'
            }
        }
"@))
})


$ctl['btnVerificar'].Add_Click({
    Start-Tarefa -Nome 'Verificando o notebook' -Final 'Verificacao concluida.' -Corpo {
        Set-Etapa 'Verificando disco, memoria, bateria e rede' 0 'Seguranca'
        Invoke-PreCheck | Out-Null
    }
})

$ctl['btnBackup'].Add_Click({
    Start-Tarefa -Nome 'Criando ponto de restauracao e backup' -Final 'Backup concluido.' -Corpo {
        Set-Etapa 'Criando ponto de restauracao e salvando o backup' 0 'Seguranca'
        Invoke-Backup
    }
})

$ctl['btnValidar'].Add_Click({
    Start-Tarefa -Nome 'Validando as configuracoes' -Final 'Validacao concluida.' -Corpo {
        Set-Etapa 'Conferindo item a item' 0 'Extras'
        $global:Estado.Falhas = [int](Invoke-Validacao)
    }
})

$ctl['btnRestaurar'].Add_Click({
    $r = [System.Windows.MessageBox]::Show('Restaurar as configuracoes do backup mais recente do pendrive?','Restaurar','YesNo','Warning')
    if ($r -ne 'Yes') { return }
    Start-Tarefa -Nome 'Restaurando o backup' -Final 'Restauracao concluida. Reinicie o notebook.' -Corpo {
        Set-Etapa 'Restaurando as configuracoes salvas' 0 'Seguranca'
        Invoke-Restaurar -Confirmado
    }
})

$ctl['btnAtualizar'].Add_Click({
    Start-Tarefa -Nome 'Consultando a versao no site' -Final 'Consulta de versao concluida.' -Corpo {
        Test-Atualizacao
    }
})

$ctl['btnTutorial'].Add_Click({ Start-Process $script:SiteUrl })

$ctl['btnSemReinicio'].Add_Click({
    Start-Tarefa -Nome 'Desligando o reinicio automatico' -Final 'Reinicio automatico desligado.' -Corpo {
        Set-Etapa 'Desligando o reinicio automatico' 0 'Update'
        Invoke-DesligarReinicioAuto
    }
})

$ctl['btnAplicar'].Add_Click({
    $o = Get-Opcoes
    if ($o.Defender) {
        $r = [System.Windows.MessageBox]::Show(
            "O Windows Defender sera DESLIGADO neste notebook.`nEle ficara sem antivirus ativo. Deseja continuar?",
            'Confirmar', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { $ctl['cbDefender'].IsChecked = $false; $o = Get-Opcoes }
    }
    $total = 2   # desarmar antivirus + perfis de usuario
    $total++   # desligar o controle de aplicativos do Windows 11
    foreach ($v in @($o.PreCheck,$o.Backup,($o.Bloat -or $o.McAfee),$o.Defender,$o.CopiarInst,$o.Energia,$o.Notif,$o.Update,
                     $o.OneDrive,$o.Extras,$o.Aparencia,$o.Taskbar,$o.Validar)) {
        if ($v) { $total++ }
    }

    Start-Tarefa -Nome 'Aplicando as configuracoes' -Total $total -Final 'Concluido. Reinicie o notebook.' -Corpo {
        $i = 0
        # SEMPRE primeiro: com a McAfee ativa ela bloqueia tudo o que vem depois.
        $i++; Set-Etapa 'Desarmando o antivirus (McAfee)' $i 'Limpeza'; Invoke-DesarmarAntivirus
        if ($Opcoes.PreCheck) { $i++; Set-Etapa 'Verificacao previa do sistema' $i 'Seguranca'; Invoke-PreCheck | Out-Null }

        if ($Opcoes.Backup)   { $i++; Set-Etapa 'Ponto de restauracao e backup' $i 'Seguranca'; Invoke-Backup }
        if ($Opcoes.Defender) { $i++; Set-Etapa 'Desligando o Windows Defender' $i 'Limpeza'; Invoke-DesligarDefender }

        # SEMPRE: sem isso o Windows 11 comeca a bloquear os aplicativos depois de alguns dias.
        $i++; Set-Etapa 'Desligando o controle de aplicativos do Windows 11' $i 'Seguranca'; Invoke-DesligarControleDeApps

        # As configuracoes vao para o usuario atual e para o perfil padrao.
        $i++; Set-Etapa 'Preparando os perfis de usuario' $i 'Conta'
        Write-Log 'PERFIS DE USUARIO' 'title'
        Open-HivesUsuario

        if ($Opcoes.Energia)  { $i++; Set-Etapa 'Energia e desempenho' $i 'Energia'; Invoke-Energia }
        if ($Opcoes.Notif)    { $i++; Set-Etapa 'Notificacoes' $i 'Interface'; Invoke-Notificacoes }
        if ($Opcoes.Update)   { $i++; Set-Etapa 'Atualizacoes na madrugada' $i 'Update'; Invoke-WindowsUpdate -HoraInicio $Opcoes.HoraIni -ReiniciarAposAtualizar ([bool]$Opcoes.ReinicioAuto) }
        if ($Opcoes.OneDrive) { $i++; Set-Etapa 'Removendo o OneDrive' $i 'Conta'; Invoke-RemoverOneDrive }
        if ($Opcoes.Extras)    { $i++; Set-Etapa 'Ajustes extras' $i 'Extras'; Invoke-Extras }
        if ($Opcoes.Aparencia) { $i++; Set-Etapa 'Tema e papel de parede' $i 'Interface'; Invoke-Aparencia }

        # No FINAL: primeiro tira os programas de fabrica, depois instala os nossos.
        # Assim a limpeza nunca remove nem quebra o que acabou de ser instalado.
        if ($Opcoes.Bloat -or $Opcoes.McAfee) {
            $i++; Set-Etapa 'Limpeza de fabrica (Lenovo / Samsung / McAfee)' $i 'Limpeza'
            Invoke-LimpezaFabrica -Selecao @($Opcoes.SelBloat) -IncluirMcAfee ([bool]$Opcoes.McAfee)
        }
        if ($Opcoes.CopiarInst) { $i++; Set-Etapa 'Copiando os instaladores para a area de trabalho' $i 'Apps'; Copy-InstaladoresParaDesktop }
        if ($Opcoes.Taskbar)   { $i++; Set-Etapa 'Barra de tarefas' $i 'Interface'; Invoke-Interface }   # por ultimo: reinicia o Explorer

        Close-HivesUsuario

        Write-Log 'CONCLUIDO' 'title'
        if ($Opcoes.Validar) {
            $i++; Set-Etapa 'Validando o resultado' $i 'Extras'
            Start-Sleep -Milliseconds 500
            $global:Estado.Falhas = [int](Invoke-Validacao)
        }
        Write-Log 'Reinicie o notebook para garantir que tudo seja aplicado.' 'ok'
        Set-Etapa 'Salvando o relatorio' $i
        $global:Estado.SalvarRelatorio = $true
    }
})

$ctl['btnSalvar'].Add_Click({
    $arquivo = Save-Relatorio
    $ctl['txtStatus'].Text = "Relatorio salvo em: $arquivo"
})

$ctl['btnReiniciar'].Add_Click({
    $r = [System.Windows.MessageBox]::Show('Reiniciar o notebook agora?','Confirmar','YesNo','Question')
    if ($r -eq 'Yes') { Restart-Computer -Force }
})

# A consulta automatica foi removida da abertura para nunca bloquear o botao
# de emergencia do antivirus. O tecnico ainda pode usar ATUALIZAR SCRIPT.

# Nao deixa fechar a janela no meio de uma tarefa.
$win.Add_Closing({
    param($sender,$e)
    if ($script:TarefaAtiva -and -not $script:TarefaLeve) {
        $r = [System.Windows.MessageBox]::Show('Ha uma tarefa em andamento. Fechar agora pode deixar o notebook pela metade. Fechar mesmo assim?','Aguarde','YesNo','Warning')
        if ($r -ne 'Yes') { $e.Cancel = $true }
    }
})

$win.ShowDialog() | Out-Null
