# =====================================================================
#  REDE DE TESTE (somente pendrive TESTE - nunca usar em campo)
#  Liga o acesso remoto do notebook pelo CABO (adaptador USB-rede), para o
#  PC de testes (192.168.50.1) acompanhar e mexer na instalacao.
#    Ligar:    rede-teste.ps1
#    Desligar: rede-teste.ps1 -Desligar   (tira senha, IP fixo e acesso)
#  A senha temporaria vem de rede-teste.json (raiz do pendrive, nunca no Git).
# =====================================================================
param([switch]$Desligar)
$ErrorActionPreference = 'Continue'
$IpNote = '192.168.50.2'; $IpPc = '192.168.50.1'
$raiz = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
function T([string]$s, [string]$c = 'Gray') { Write-Host $s -ForegroundColor $c }

# Adaptador de cabo: fisico, nao Wi-Fi
$cabo = Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
        Where-Object { $_.MediaType -eq '802.3' -and $_.InterfaceDescription -notmatch '(?i)wi-?fi|wireless|802\.11' } |
        Sort-Object { $_.Status -ne 'Up' } | Select-Object -First 1

if ($Desligar) {
    T 'Desligando a rede de teste...' Yellow
    Get-NetFirewallRule -Group 'GlobalLED Teste' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    Disable-PSRemoting -Force -WarningAction SilentlyContinue | Out-Null
    Stop-Service WinRM -Force -ErrorAction SilentlyContinue; Set-Service WinRM -StartupType Manual
    Remove-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy -ErrorAction SilentlyContinue
    if ($cabo) {
        Remove-NetIPAddress -InterfaceIndex $cabo.ifIndex -Confirm:$false -ErrorAction SilentlyContinue
        Set-NetIPInterface -InterfaceIndex $cabo.ifIndex -Dhcp Enabled -ErrorAction SilentlyContinue
    }
    # Volta a conta Global para SEM senha, com logon automatico como antes
    & net.exe user Global '""' | Out-Null
    Set-ItemProperty $wl -Name AutoAdminLogon -Value '1'
    Set-ItemProperty $wl -Name DefaultUserName -Value 'Global'
    Set-ItemProperty $wl -Name DefaultPassword -Value '' -ErrorAction SilentlyContinue
    # A copia que o GO.cmd fez no disco tambem sai (a senha nao fica no notebook)
    Remove-Item 'C:\ConfiguradorLED\rede-teste.json', 'C:\ConfiguradorLED\_sistema\rede-teste.ps1' -Force -ErrorAction SilentlyContinue
    T 'Pronto: senha removida, acesso remoto desligado, cabo de volta ao normal.' Green
    exit 0
}

$cfgArq = Join-Path $raiz 'rede-teste.json'
if (-not (Test-Path $cfgArq)) { T "Falta $cfgArq no pendrive." Red; exit 1 }
$senha = (Get-Content $cfgArq -Raw | ConvertFrom-Json).SenhaTeste
if (-not $cabo) { T 'Nenhum adaptador de CABO encontrado. Plugue o adaptador USB-rede e rode de novo.' Red; exit 1 }

T "Adaptador: $($cabo.InterfaceDescription) ($($cabo.Status))"
Remove-NetIPAddress -InterfaceIndex $cabo.ifIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
New-NetIPAddress -InterfaceIndex $cabo.ifIndex -IPAddress $IpNote -PrefixLength 24 -ErrorAction SilentlyContinue | Out-Null
Start-Sleep -Seconds 3
Set-NetConnectionProfile -InterfaceIndex $cabo.ifIndex -NetworkCategory Private -ErrorAction SilentlyContinue

# Senha temporaria na conta Global (o Windows nao aceita acesso remoto sem
# senha) mantendo o logon automatico
& net.exe user Global $senha | Out-Null
Set-ItemProperty $wl -Name AutoAdminLogon -Value '1'
Set-ItemProperty $wl -Name DefaultUserName -Value 'Global'
Set-ItemProperty $wl -Name DefaultPassword -Value $senha
# Sem contador: o Windows apagaria o logon automatico depois de N entradas
Remove-ItemProperty $wl -Name AutoLogonCount -ErrorAction SilentlyContinue

Enable-PSRemoting -SkipNetworkProfileCheck -Force -WarningAction SilentlyContinue | Out-Null
Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name LocalAccountTokenFilterPolicy -Value 1 -Type DWord
# So o PC de testes entra (WinRM e ping)
Get-NetFirewallRule -Group 'GlobalLED Teste' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName 'GlobalLED Teste - WinRM' -Group 'GlobalLED Teste' -Direction Inbound -Protocol TCP -LocalPort 5985 -RemoteAddress $IpPc -Action Allow | Out-Null
New-NetFirewallRule -DisplayName 'GlobalLED Teste - Ping' -Group 'GlobalLED Teste' -Direction Inbound -Protocol ICMPv4 -IcmpType 8 -RemoteAddress $IpPc -Action Allow | Out-Null

$ok = Test-Connection $IpPc -Count 2 -Quiet
T ''
T "Notebook: $IpNote | PC de testes: $IpPc | PC responde: $(if ($ok) { 'SIM' } else { 'ainda nao (confira o cabo e o PC)' })" $(if ($ok) { 'Green' } else { 'Yellow' })
T 'REDE DE TESTE LIGADA. Para desligar: TESTE-REDE.cmd desligar' Green
