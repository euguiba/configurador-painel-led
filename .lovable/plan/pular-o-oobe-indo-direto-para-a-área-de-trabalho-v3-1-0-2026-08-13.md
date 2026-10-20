# Pular o OOBE indo direto para a área de trabalho (v3.1.0)

## Situação atual

A opção 2 do `INICIAR.cmd` apenas grava `BypassNRO` + `DisablePrivacyExperience` e tenta abrir `ms-cxh:localonly`. O técnico ainda precisa digitar o nome do usuário, responder as telas de privacidade/personalização e concluir manualmente.

## O que muda

A opção 2 passa a concluir o OOBE inteiro sozinha:

1. Cria a conta local **Global** (administrador, sem senha) direto pelo prompt do OOBE.
2. Liga o logon automático nessa conta, para o Windows cair na área de trabalho sem tela de senha.
3. Grava as chaves que suprimem o restante das telas: privacidade, personalização de uso, Copilot/dicas, OneDrive, "vamos terminar de configurar seu dispositivo".
4. Encerra o processo do OOBE e entra na sessão da Global — sem passar pelas perguntas de uso da máquina.
5. Se algo falhar (Windows bloquear a criação da conta naquele estágio), cai no comportamento antigo: abre `ms-cxh:localonly` e explica o passo manual.

O nome do usuário fica fixo como **Global**, sem digitação.

Depois do primeiro logon, o técnico abre o `INICIAR.cmd` do pendrive e escolhe a opção 1 normalmente — nada muda no configurador em si.

## Detalhes técnicos

- `public/downloads/INICIAR.cmd`, bloco `:oobe`:
  - `net user Global /add` + `net localgroup Administradores/Administrators Global /add` (tenta os dois nomes de grupo por causa do idioma);
  - `reg add` em `Winlogon`: `AutoAdminLogon=1`, `DefaultUserName=Global`, `DefaultPassword=` vazio, e `LimitBlankPasswordUse=0` em `Control\Lsa` para permitir logon sem senha;
  - `reg add` de `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE`: `BypassNRO`, `SkipMachineOOBE`, `SkipUserOOBE`, `DisablePrivacyExperience`, `LaunchUserOOBE=0`, `DisableVoice=1`;
  - `HKCU`/`Default` do usuário: desativa `ContentDeliveryManager` (dicas/sugestões), `UserProfileEngagement\ScoobeSystemSettingEnabled=0` e `TurnOffWindowsCopilot`;
  - finaliza com `taskkill /f /im WWAHost.exe` e `taskkill /f /im msoobe.exe` para sair do assistente e iniciar a sessão;
  - se `net user` retornar erro, mostra a mensagem atual com `ms-cxh:localonly` e a opção de reiniciar.
- Atualizar `public/downloads/versao.json` para 3.1.0 (nota de mudança), registrar a versão em `src/routes/versoes.tsx`, ajustar a explicação do "pular configuração inicial" em `src/routes/index.tsx` e no `public/downloads/LEIA-ME.txt`. O kit ZIP é regerado pelo script de sincronização.
- O configurador (`ConfiguradorPainelLED.ps1`) não volta a criar conta Global — essa parte fica exclusiva do OOBE, onde o Windows exige que exista algum usuário.
