# Prepara ESTE PC (o de testes) para falar com o notebook pelo cabo.
# Rodar como administrador, uma vez, com o adaptador USB-rede plugado.
$IpPc = '192.168.50.1'; $IpNote = '192.168.50.2'
$cabo = Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
        Where-Object { $_.MediaType -eq '802.3' -and $_.InterfaceDescription -notmatch '(?i)wi-?fi|wireless|802\.11' } |
        Sort-Object { $_.Status -ne 'Up' } | Select-Object -First 1
if (-not $cabo) { Write-Host 'Nenhum adaptador de cabo encontrado. Plugue o adaptador USB-rede.' -ForegroundColor Red; pause; exit 1 }
Write-Host "Adaptador: $($cabo.InterfaceDescription) ($($cabo.Status))"
Remove-NetIPAddress -InterfaceIndex $cabo.ifIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
# Sem gateway: a internet continua saindo pelo Wi-Fi
New-NetIPAddress -InterfaceIndex $cabo.ifIndex -IPAddress $IpPc -PrefixLength 24 | Out-Null
Start-Sleep -Seconds 3
Set-NetConnectionProfile -InterfaceIndex $cabo.ifIndex -NetworkCategory Private -ErrorAction SilentlyContinue
Set-Service WinRM -StartupType Manual; Start-Service WinRM
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $IpNote -Force
Write-Host "Pronto: este PC = $IpPc, confia no notebook $IpNote." -ForegroundColor Green
pause
