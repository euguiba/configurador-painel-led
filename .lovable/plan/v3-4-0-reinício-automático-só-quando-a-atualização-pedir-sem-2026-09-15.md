# v3.4.0 - Reinício automático só quando a atualização pedir, sem aviso

## O problema hoje

O kit cria uma tarefa que manda reiniciar todo dia num horário fixo (05:00), com contagem
de 60 segundos e mensagem na tela. Isso reinicia o notebook mesmo sem atualização nenhuma,
e o Windows ainda mostra os próprios avisos de reinício, que alguém precisa clicar.

## O que passa a acontecer

- Acaba o reinício diário de horário fixo. A tarefa antiga é apagada dos notebooks que já a têm.
- O notebook passa a reiniciar **somente quando o Windows realmente concluiu uma atualização
  e está pedindo reinício** — e aí reinicia na hora, a qualquer momento do dia.
- O reinício é silencioso: sem contagem regressiva visível, sem mensagem, sem nada para clicar.
- Todos os avisos de reinício do Windows Update ficam desligados, então ninguém na loja
  precisa acessar a máquina.

## Como ficará na tela do configurador

No bloco "Atualizações", a caixa "Reiniciar às [hora]" sai e entra a opção:

- `Reiniciar sozinho assim que a atualização terminar (sem aviso)` — marcada por padrão.

Desmarcada, o kit instala as atualizações na madrugada mas nunca reinicia sozinho.
A hora de início da busca de atualizações (00:30) continua como está.

## Detalhes técnicos

Em `public/downloads/ConfiguradorPainelLED.ps1`, função `Invoke-WindowsUpdate`:

- Remover a tarefa `PainelLED - Reinicio noturno` e chamar `Unregister-ScheduledTask` nela
  para limpar notebooks já configurados.
- Criar a tarefa `PainelLED - Reinicio apos atualizacao` (SYSTEM, RunLevel Highest,
  `-AllowStartIfOnBatteries -StartWhenAvailable`), com gatilho repetido a cada 15 minutos,
  indefinidamente, começando no logon/boot. A ação roda um PowerShell oculto que só executa
  `shutdown.exe /r /f /t 0` quando existir pendência de reinício:
  - `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired`
  - `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending`
  - `PendingFileRenameOperations` em `Session Manager`
- Registro, para silenciar avisos e liberar o reinício imediato:
  - `AU\NoAutoRebootWithLoggedOnUsers = 0`
  - `AU\AlwaysAutoRebootAtScheduledTime = 0` (não amarra mais a horário fixo)
  - `WindowsUpdate\SetAutoRestartNotificationConfig = 1` e `AutoRestartNotificationSchedule = 15`
  - `WindowsUpdate\SetRestartWarningSchd = 0`, `RestartNotificationsAllowed2 = 0`
  - `WindowsUpdate\UpdateNotificationLevel = 2` (oculta todas as notificações de update)
  - `SetActiveHours = 0` e remoção do horário ativo, já que o reinício agora é sob demanda.
- Parâmetro `-HoraReinicio` da função vira `-ReiniciarAposAtualizar` (booleano).

Interface (XAML + `Get-Opcoes` + "Selecionar todas" + fluxo principal): trocar o ComboBox
`cbHoraReinicio` pela CheckBox `cbReinicioAuto` (IsChecked=True) e repassar o valor.

Validação (`Test-Item`): conferir que a tarefa `PainelLED - Reinicio apos atualizacao` existe
e que `PainelLED - Reinicio noturno` não existe mais.

Documentação e distribuição: atualizar `public/downloads/LEIA-ME.txt`, `public/downloads/versao.json`
(v3.4.0) e o texto de novidades em `src/routes/index.tsx`; rodar `scripts/sync-versao.mjs` e
gerar `ConfiguradorPainelLED-Kit-v3.4.0.zip`.
