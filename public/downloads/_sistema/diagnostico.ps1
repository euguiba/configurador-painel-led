# =====================================================================
#  DIAGNOSTICO DO MODO AUTOMATICO (pendrive de TESTE)
#  So LE informacoes do notebook e grava na pasta diagnostico do pendrive.
#  Nao altera nada no notebook. Nao copia senhas.
# =====================================================================
param([string]$Saida = '')
$ErrorActionPreference = 'SilentlyContinue'
$raiz = if ($Saida) { $Saida } else { Split-Path -Parent (Split-Path -Parent $PSCommandPath) }
$dest = Join-Path $raiz ("diagnostico\{0}_{1:yyyy-MM-dd_HH-mm}" -f $env:COMPUTERNAME, (Get-Date))
New-Item -ItemType Directory -Path $dest -Force | Out-Null
$resumo = Join-Path $dest 'resumo.txt'
function T([string]$s) { Add-Content -Path $resumo -Value $s -Encoding UTF8; Write-Host $s }
function Secao([string]$s) { T ''; T ('=' * 70); T $s; T ('=' * 70) }

Add-Type -ErrorAction SilentlyContinue -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public class DiagTok {
  [DllImport("advapi32.dll", SetLastError=true)] static extern bool OpenProcessToken(IntPtr h, uint a, out IntPtr t);
  [DllImport("advapi32.dll", SetLastError=true)] static extern bool GetTokenInformation(IntPtr t, int c, out int v, int l, out int r);
  [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint a, bool i, int pid);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
  public static string Elevado(int pid) {
    IntPtr p = OpenProcess(0x1000, false, pid); if (p == IntPtr.Zero) return "?";
    IntPtr t; if (!OpenProcessToken(p, 0x8, out t)) { CloseHandle(p); return "?"; }
    int v, r; bool ok = GetTokenInformation(t, 20, out v, 4, out r);
    CloseHandle(t); CloseHandle(p); return ok ? (v != 0 ? "SIM" : "NAO") : "?";
  }
}
'@

Secao 'NOTEBOOK'
$cs = Get-CimInstance Win32_ComputerSystem; $bios = Get-CimInstance Win32_BIOS; $os = Get-CimInstance Win32_OperatingSystem
T "Nome: $env:COMPUTERNAME | $($cs.Manufacturer) $($cs.Model) | serie $($bios.SerialNumber)"
T "Windows: $($os.Caption) build $($os.BuildNumber) | rodando como: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
$wl = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
T "Logon automatico: AutoAdminLogon=$($wl.AutoAdminLogon) usuario=$($wl.DefaultUserName)"
$s = Get-ItemProperty 'HKLM:\SYSTEM\Setup'
T "Setup: OOBEInProgress=$($s.OOBEInProgress) SystemSetupInProgress=$($s.SystemSetupInProgress) ImageState=$((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State').ImageState)"

Secao 'MODO AUTOMATICO: ARQUIVOS E TAREFAS'
foreach ($p in 'C:\ProgramData\GlobalLED\logs','C:\ProgramData\GlobalLED\inventario.csv','C:\ProgramData\GlobalLED\programas.json') {
    if (Test-Path $p) { Copy-Item $p -Destination $dest -Recurse -Force; T "copiado: $p" } else { T "NAO EXISTE: $p" }
}
T "C:\ConfiguradorLED existe: $(Test-Path 'C:\ConfiguradorLED') | config-local.json ainda no notebook: $(Test-Path 'C:\ConfiguradorLED\config-local.json')"
Get-ScheduledTask | Where-Object { $_.TaskName -like 'PainelLED*' } | ForEach-Object {
    $i = $_ | Get-ScheduledTaskInfo
    T ("tarefa: {0} | estado {1} | ultima execucao {2} | resultado {3} | acao: {4} {5}" -f $_.TaskName, $_.State, $i.LastRunTime, $i.LastTaskResult, $_.Actions[0].Execute, $_.Actions[0].Arguments)
}

Secao 'PROGRAMAS INSTALADOS (Adicionar/remover)'
$chaves = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
Get-ItemProperty $chaves | Where-Object { $_.DisplayName -match '(?i)anydesk|led|nova|winpcap|npcap|hik|prolific|pl-?2303|visual c\+\+|colorlight|konica' } |
    Sort-Object DisplayName | ForEach-Object { T ("{0} | versao {1} | pasta: {2} | {3}" -f $_.DisplayName, $_.DisplayVersion, $_.InstallLocation, ($_.PSPath -replace '.*::','' -replace '\\Uninstall\\.*','')) }

Secao 'ATALHOS NA AREA DE TRABALHO'
$ws = New-Object -ComObject WScript.Shell
$pastas = @("$env:PUBLIC\Desktop", [Environment]::GetFolderPath('Desktop')) + @(Get-ChildItem 'C:\Users\*\Desktop' -Directory | ForEach-Object FullName) | Select-Object -Unique
foreach ($d in $pastas) {
    foreach ($l in @(Get-ChildItem $d -Filter *.lnk)) {
        $k = $ws.CreateShortcut($l.FullName)
        T ("{0}`n   aponta para: {1} {2}`n   o alvo existe: {3} | pasta de trabalho: {4} | icone: {5}" -f $l.FullName, $k.TargetPath, $k.Arguments, (Test-Path -LiteralPath $k.TargetPath), $k.WorkingDirectory, $k.IconLocation)
    }
}

Secao 'NOVALCT: ONDE ESTA'
foreach ($r in @('C:\Program Files','C:\Program Files (x86)','C:\ProgramData') + @(Get-ChildItem 'C:\Users\*\AppData\Roaming','C:\Users\*\AppData\Local' -Directory | ForEach-Object FullName)) {
    Get-ChildItem $r -Directory | Where-Object { $_.Name -match '(?i)nova' } | ForEach-Object {
        T "pasta: $($_.FullName)"
        Get-ChildItem $_.FullName -Recurse -Filter 'NovaLCT*.exe' -File | Select-Object -First 5 | ForEach-Object { T "   exe: $($_.FullName) ($([math]::Round($_.Length/1MB,1)) MB)" }
    }
}
$sp = Get-ChildItem 'C:\Windows\System32\config\systemprofile\AppData' -Recurse -Directory -Filter '*Nova*' | Select-Object -First 3
foreach ($x in $sp) { T "ATENCAO - dentro do perfil do SISTEMA: $($x.FullName)" }

Secao 'LEDVISION'
$p = Get-Process LEDVISION
if ($p) { foreach ($x in $p) { T "LEDVISION aberto (PID $($x.Id)) | como administrador: $([DiagTok]::Elevado($x.Id)) | iniciou $($x.StartTime)" } } else { T 'LEDVISION NAO esta aberto' }
foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run','HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run','HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run') {
    $v = Get-ItemProperty $k; if ($v.LEDVISION) { T "inicializacao: $k -> $($v.LEDVISION)" }
}
foreach ($k in 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers','HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers') {
    $v = Get-ItemProperty $k; if ($v) { $v.PSObject.Properties | Where-Object { $_.Name -match '(?i)ledvision|nova' } | ForEach-Object { T "compatibilidade: $($_.Name) = $($_.Value)" } }
}
$cfgs = @(Get-ChildItem 'C:\Users\*\Documents\Colorlight\LEDVISION\LEDVISION_Config\LEDVISION.cfg' -File) + @(Get-ChildItem 'C:\Users\*\AppData\Local\VirtualStore\Program Files (x86)\ColorLight\LEDVISION.cfg' -File) + @(Get-Item 'C:\Program Files (x86)\ColorLight\LEDVISION.cfg')
foreach ($c in $cfgs | Where-Object { $_ }) {
    $txt = Get-Content $c.FullName -Raw
    $val = foreach ($n in 'Language','IsAppAutoRun','IsAutoPlay','IsStartMin','InfoRunAsAdmin') { "$n=" + ([regex]::Match($txt, "<$n>([^<]*)</$n>").Groups[1].Value) }
    T "cfg: $($c.FullName) (alterado $($c.LastWriteTime))`n   $($val -join ' | ')"
    Copy-Item $c.FullName (Join-Path $dest ("LEDVISION_" + ($c.FullName -replace '[:\\ ()]','_') )) -Force
}

Secao 'ANYDESK'
$svc = Get-Service AnyDesk; T "servico: $($svc.Status) / inicio $($svc.StartType)"
$exe = Join-Path ${env:ProgramFiles(x86)} 'AnyDesk\AnyDesk.exe'
if (Test-Path $exe) {
    $psi = New-Object Diagnostics.ProcessStartInfo $exe, '--get-id'; $psi.UseShellExecute = $false; $psi.RedirectStandardOutput = $true; $psi.CreateNoWindow = $true
    $pr = [Diagnostics.Process]::Start($psi); $l = $pr.StandardOutput.ReadToEndAsync(); if (-not $pr.WaitForExit(15000)) { $pr.Kill() }
    T "ID: $(if ($l.Wait(2000)) { $l.Result.Trim() } else { 'nao respondeu' })"
} else { T 'AnyDesk.exe nao encontrado' }

Secao 'REDE'
T ((netsh wlan show interfaces | Select-String 'SSID|Estado|State' | ForEach-Object { $_.Line.Trim() }) -join ' | ')
T "internet: $(Test-Connection 8.8.8.8 -Count 1 -Quiet)"
T 'Adaptadores:'
Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue | ForEach-Object { T "  $($_.Name) | $($_.InterfaceDescription) | $($_.Status) | $(@(Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress -join ',')" }
T 'Dispositivos de rede/USB com problema:'
Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.Class -in 'Net','USB' -and $_.Status -ne 'OK' } | ForEach-Object { T "  $($_.Status) | $($_.Class) | $($_.FriendlyName) | $($_.InstanceId)" }
T "Rede de teste: WinRM $((Get-Service WinRM).Status) | regras: $(@(Get-NetFirewallRule -Group 'GlobalLED Teste' -ErrorAction SilentlyContinue).Count)"

Secao 'CONTAS E ADMINISTRADOR'
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
T "conta atual: $($id.Name) | elevado agora: $((New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"
$adm = Get-LocalGroup -SID 'S-1-5-32-544'
T "grupo $($adm.Name): $((Get-LocalGroupMember -SID 'S-1-5-32-544' -ErrorAction SilentlyContinue).Name -join ', ')"
Get-LocalUser | ForEach-Object { T "  usuario $($_.Name) | ativo $($_.Enabled) | senha exigida $($_.PasswordRequired) | ultimo logon $($_.LastLogon)" }
$pol = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -ErrorAction SilentlyContinue
T "UAC: EnableLUA=$($pol.EnableLUA) ConsentPromptBehaviorAdmin=$($pol.ConsentPromptBehaviorAdmin) LocalAccountTokenFilterPolicy=$($pol.LocalAccountTokenFilterPolicy)"
T "Winlogon: DefaultPassword definida: $([bool]$wl.DefaultPassword) | AutoLogonCount=$($wl.AutoLogonCount)"

Secao 'LEDTOOL'
$lt = Join-Path $env:ProgramFiles 'LEDTool\client'
T "pasta existe: $(Test-Path $lt) | LED Tool.exe: $(Test-Path (Join-Path $lt 'LED Tool.exe'))"
if (Test-Path $lt) {
    T "permissao Usuarios: $(((Get-Acl $lt).Access | Where-Object { $_.IdentityReference -match 'Usu|Users' } | ForEach-Object { $_.FileSystemRights }) -join ', ')"
    Get-Process -Name 'LED Tool','app','nginx' -ErrorAction SilentlyContinue | ForEach-Object { T "  rodando: $($_.ProcessName) ($($_.Id))" }
    $err = Join-Path $lt 'nginx\logs\error.log'
    if (Test-Path $err) { T 'nginx error.log (fim):'; Get-Content $err -Tail 15 | ForEach-Object { T "  $_" } }
}

T ''; T "Pronto. Tudo em: $dest"
