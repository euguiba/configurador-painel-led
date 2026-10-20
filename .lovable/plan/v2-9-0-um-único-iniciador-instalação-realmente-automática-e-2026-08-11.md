# v2.9.0 — Um único iniciador, instalação realmente automática e Defender desligado

## 1. Um só arquivo para iniciar (organização do pendrive)

Hoje a raiz tem `INICIAR AQUI.cmd`, `Iniciar.bat`, `PULAR OOBE.cmd`, `autorun.inf` e a pasta `VTOYEFI` — confuso.

Nova estrutura da raiz do pendrive:

```text
INICIAR.cmd            <- único arquivo que o técnico abre
ConfiguradorPainelLED.ps1
LEIA-ME.txt
Wallpaper.jpg
Instaladores\
Backups\
_sistema\              <- tudo o que é interno some da vista
   autorun.inf
   autounattend.xml
   VTOYEFI\
```

- `INICIAR.cmd` passa a fazer tudo: localiza o `.ps1` em qualquer letra de unidade (inclusive no modo Ventoy), desbloqueia os arquivos, eleva para administrador e abre a interface.
- Ao abrir, ele mostra um menu curto de duas opções:
  1. Configurar este notebook (padrão, entra sozinho em 5 segundos)
  2. Pular a configuração inicial do Windows (OOBE) — o conteúdo do antigo `PULAR OOBE.cmd` vira uma rotina interna deste mesmo arquivo
- `Iniciar.bat`, `INICIAR AQUI.cmd` e `PULAR OOBE.cmd` são removidos do kit.
- Sobre o "automático só espetando": o Windows 10/11 bloqueia AutoRun em pendrive USB por segurança e isso não tem como ser contornado por arquivo. O texto do site e o LEIA-ME passam a dizer com clareza: abrir o `INICIAR.cmd` (no OOBE: `Shift+F10` → digitar `explorer` → abrir o `INICIAR.cmd`). O `autorun.inf` continua no kit apenas para o caso Ventoy, escondido em `_sistema`.

## 2. Instalação dos aplicativos: aceitar tudo e concluir de verdade

- O assistente que clica nas janelas hoje roda em `Start-Job`, que não enxerga a área de trabalho interativa — por isso os "Sim / Avançar / Aceito / Instalar" não eram clicados. Ele passa a rodar no mesmo processo (runspace com STA), com acesso real às janelas.
- O assistente ganha reconhecimento de botões em português e inglês: Sim, Aceito, Concordo, Avançar, Próximo, Instalar, Finalizar, Concluir, Yes, Accept, Agree, Next, Install, Finish, OK, além de marcar caixas do tipo "Eu aceito os termos".
- Janelas de driver/plugin (NovaLCT: Mars, Smart Module, driver USB; LedVision: VC++ e codecs) são detectadas pelo título e confirmadas automaticamente.
- Ordem de instalação por app fica mais realista: primeiro o modo silencioso conhecido; se não instalar, abre o instalador na tela **com o assistente ligado** e ele conduz o processo até o fim.
- O prompt do Windows sobre driver não assinado (janela de segurança do Windows) também é aceito.
- No fim, o console lista app por app: instalado / não instalado, com o motivo.

## 3. Windows Defender realmente desligado

O que existe hoje grava políticas, mas a Proteção contra Adulteração (Tamper Protection) impede o efeito imediato e algumas chaves não bastam. Reforço:

- Além das políticas atuais, desligar os serviços e o início automático via registro (`WinDefend`, `WdNisSvc`, `Sense`, `WdFilter`, `WdNisDrv`, `WdBoot` com `Start = 4`).
- Desabilitar as tarefas agendadas do Defender e a entrada `SecurityHealth` do Run.
- Registrar a ausência de antivírus para o Windows não reativar (`DisableAntiSpyware` + política de "não reativar").
- Detectar Tamper Protection ligada **antes** de tentar `Set-MpPreference` e, nesse caso, mostrar no console um aviso claro e um botão na interface que abre direto a tela de Segurança do Windows para desligar a proteção contra adulteração; depois disso o técnico clica de novo em desligar e o script conclui sem reiniciar.
- A validação final confere se o serviço `WinDefend` está parado/desabilitado e se a proteção em tempo real está off, informando se falta reiniciar.

## 4. "Marcar tudo" funcionando

- O botão passa a alternar entre MARCAR TUDO e DESMARCAR TUDO.
- Passa a incluir as opções que ficavam de fora: instalar aplicativos (`cbInstalar`) e aceitar plugins (`cbPlugins`).
- Cada caixa é marcada com verificação de existência e dentro de `try/catch`, para que uma falha isolada não interrompa o restante (causa provável de "não acontece nada" hoje).
- Confirmação no console: "17 opções marcadas".

## Detalhes técnicos

- `public/downloads/INICIAR.cmd` (novo): busca de unidade, `Unblock-File` recursivo, menu com `choice /T 5 /D 1`, rotina OOBE (`BypassNRO`, `DisablePrivacyExperience`, `ms-cxh:localonly`) e elevação via `Start-Process -Verb RunAs`.
- Remover `public/downloads/Iniciar.bat`, `INICIAR AQUI.cmd`, `PULAR OOBE.cmd`; mover `autorun.inf`, `autounattend.xml` e `VTOYEFI/` para `public/downloads/_sistema/`.
- `scripts/zip-kit.mjs`: atualizar as listas `raiz`, `pastasVazias` e `pastasComArquivos` para a nova estrutura e apagar os ZIPs antigos (`v2.8.1`, `v2.8.2`) do repositório.
- `ConfiguradorPainelLED.ps1`:
  - `Start-AceitadorDeJanelas` reescrito em runspace STA com `Add-Type` de user32 (`EnumWindows`, `FindWindowEx`, `SendMessage BM_CLICK`) em vez de `SendKeys` cego, com fallback para SendKeys.
  - `Invoke-Instaladores`: nova ordem de tentativas e log por app.
  - `Invoke-DesligarDefender`: bloco de serviços/tarefas + detecção de Tamper Protection; novo botão `btnTamper` na interface.
  - `btnTodos`: lista completa, null-safe e alternância.
  - `Invoke-Validacao`: checagens de `WinDefend`.
- `public/downloads/versao.json` → 2.9.0 com novidades e histórico; `scripts/sync-versao.mjs` propaga para `.ps1` e `LEIA-ME.txt`.
- `src/routes/index.tsx`: passo a passo do pendrive com um único `INICIAR.cmd`, nova árvore de pastas e texto correto sobre AutoRun/OOBE.
