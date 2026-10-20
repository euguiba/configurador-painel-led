# v2.7.2 — Desligamento reforçado do Windows Defender

Aproveitar as chaves de registro do `Disable_Defender.ps1` enviado pelo técnico e reforçar a função `Invoke-DesligarDefender` do configurador com as mesmas políticas — sem trazer o script de fora (elevação e `Pause` não fazem sentido dentro do nosso fluxo, que já roda como administrador em segundo plano).

## O que muda para o técnico

- A opção "Desligar o Windows Defender" continua no mesmo lugar, marcada por padrão e com a mesma confirmação.
- No console aparecem mais linhas gravadas: além das que já existem, entram as novas chaves de política, Signature Updates e Spynet.
- Uma marca de controle (`WindowsDefenderIsDisabledPermanently = 1`) é gravada; se o técnico rodar o configurador de novo no mesmo notebook, o console avisa "Defender já estava desligado por este configurador" e não regrava tudo.
- A validação final passa a conferir também `DisableAntiVirus` e `DisableRealtimeMonitoring` na chave raiz.

## O que é adicionado à função `Invoke-DesligarDefender`

Em `HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender` (chave raiz):

- `AllowFastServiceStartup = 1`
- `DisableAntiVirus = 1` (já existia mas agora explícito)
- `DisableRoutinelyTakingAction = 1`
- `DisableSpecialRunningModes = 1`
- `ServiceKeepAlive = 1`
- `DisableRealtimeMonitoring = 1` (também na raiz, além da subchave)
- `WindowsDefenderIsDisabledPermanently = 1` (marca de idempotência)

Em `...\Signature Updates` (nova subchave):

- `ForceUpdateFromMU = 1`

Em `...\Spynet` (além do que já grava):

- `DisableBlockAtFirstSeen = 1`

As chaves que já gravamos hoje (`DisableAntiSpyware`, `Real-Time Protection\*`, `Spynet\SpynetReporting`, `SubmitSamplesConsent`, SmartScreen, `TamperProtection = 4`) permanecem.

## O que NÃO vem do arquivo enviado

- Bloco de auto-elevação (`Test-Admin` / `Start-Process -Verb RunAs`): o configurador já roda elevado.
- `exit` quando a chave não existe: substituído por `New-Item -Force` (a função `Set-Reg` do projeto já cria a chave se faltar).
- `Pause` no final: incompatível com execução em runspace/segundo plano.
- `Write-Host` colorido: substituído pelo `Write-Log` do console em tempo real.

## Detalhes técnicos

- `public/downloads/ConfiguradorPainelLED.ps1`
  - Estender `Invoke-DesligarDefender` (linhas ~1330–1361) com os novos `Set-Reg` acima, agrupados por subchave, cada um em `try/catch` já coberto pelo bloco existente.
  - Antes de gravar, checar `WindowsDefenderIsDisabledPermanently`; se `1`, logar `info` e pular a regravação (mantém a tentativa de `Set-MpPreference` para o caso do técnico ter religado manualmente).
  - Em `Invoke-Validacao` (linha ~1036), adicionar dois `Test-Item` para `DisableAntiVirus` e `Real-Time Protection\DisableRealtimeMonitoring`.
- `public/downloads/versao.json`: novo bloco de histórico `2.7.2` descrevendo o reforço; `scripts/sync-versao.mjs` propaga a versão para o `.ps1` e o `LEIA-ME.txt`.
- `public/downloads/LEIA-ME.txt`: uma linha curta na seção "LIMPEZA DE FÁBRICA" mencionando o reforço.
- `src/routes/versoes.tsx` e `src/routes/index.tsx`: nada a alterar — leem do `versao.json`.

Sem mudanças em outros módulos (energia, apps, McAfee).
