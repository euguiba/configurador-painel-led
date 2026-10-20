# Remover a criação da conta local "Global" (v2.2.4)

## Decisão

A conta local "Global" sai do configurador. O notebook continua sendo usado com a conta que já existe no Windows, e todas as demais configurações (energia, notificações, barra de tarefas, OneDrive, tema, apps, atualizações) seguem iguais.

## O que será feito

1. **Interface**
   - Remover a opção "Criar conta local 'Global' sem senha + logon automático" da janela do configurador.
   - Ajustar a numeração/ordem dos itens restantes.

2. **Script**
   - Remover a função que cria o usuário, adiciona ao grupo de administradores e liga o logon automático.
   - Remover a gravação de configurações no perfil da conta "Global": as configurações passam a ser aplicadas no usuário atual e no perfil padrão do Windows (que continua servindo para qualquer usuário novo criado manualmente).
   - Remover o item "Conta local Global existe" da etapa **4. VALIDAR**.
   - Manter a liberação de permissões nas pastas dos programas (a correção do atalho do NovaLCT continua valendo).

3. **Nada é desfeito automaticamente em máquinas já configuradas.** Se algum notebook já tiver a conta "Global" criada por versões anteriores, ela permanece — a remoção, se desejada, é manual. Isso fica escrito no site e no LEIA-ME.

## Detalhes técnicos

- `public/downloads/ConfiguradorPainelLED.ps1`:
  - excluir `Invoke-ContaGlobal` e sua chamada no fluxo de aplicação;
  - em `New-PerfilUsuario` / carga de hives, manter apenas `HKCU:` e `GLOBAL_DEFAULT` (perfil padrão), removendo o bloco que carrega o `NTUSER.DAT` da conta Global;
  - remover as gravações de `AutoAdminLogon` / `DefaultUserName` / `DefaultPassword` em Winlogon e o `LimitBlankPasswordUse`;
  - remover o `Test-Item` da conta Global;
  - remover o checkbox `cbConta` do XAML e a referência em `$ctl`.
- Atualizar `public/downloads/versao.json` para 2.2.4, adicionar registro em `src/routes/versoes.tsx`, ajustar o módulo "Conta local Global" e o rótulo do download em `src/routes/index.tsx`, e atualizar `public/downloads/LEIA-ME.txt`.
