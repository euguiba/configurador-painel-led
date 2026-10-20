# v3.3.0 — Instalação sem janelas: cópia pronta primeiro, internet como reforço

Hoje o kit tenta rodar os instaladores (janelas, contratos, drivers) e é aí que dá erro. A mudança inverte a ordem: o caminho normal passa a ser **cópia** e **internet**; abrir instalador vira o último recurso, e só se você mandar.

## Nova ordem de instalação

1. **Pacote pronto (padrão).** Se a pasta `Instaladores\Prontos` tiver o app, ele é copiado para o notebook em segundos: pasta do programa, chaves do Windows, atalhos na área de trabalho e permissões. Nenhuma janela, nenhum contrato, nenhum risco de travar.
2. **Internet (winget).** Se o app não tiver pacote pronto e o notebook estiver on-line, o kit instala pelo gerenciador oficial do próprio Windows, em silêncio (hoje isso só é usado para desinstalar). Serve bem para o AnyDesk; para LedVision e NovaLCT ele tenta e, se não existir no catálogo, passa para o passo 3.
3. **Instalador da pasta (opcional).** Só entra se os dois anteriores falharem **e** a opção "tentar instalador com janela" estiver marcada na tela. Ela vem **desmarcada** por padrão — então nunca mais aparecem janelas se você não quiser.

Ao final, um resumo por app dizendo por qual caminho ele entrou (cópia, internet, instalador) ou por que faltou, com a instrução do que fazer.

## Botão "GERAR PACOTE PRONTO" mais confiável

É a peça central agora, então ele melhora:

- Confere se o app realmente foi copiado (pasta com arquivos + pelo menos um executável) e mostra o tamanho.
- Copia também o atalho e os arquivos de configuração do usuário quando existirem, para o NovaLCT/LedVision já abrirem configurados.
- Se um dos três não estiver instalado no notebook modelo, avisa em vermelho em vez de gerar pacote vazio.
- Um aviso na tela e no LEIA-ME: **prepare o notebook modelo uma vez** e o pendrive serve para todos os outros.

## Detalhes técnicos

- `public/downloads/ConfiguradorPainelLED.ps1`
  - `Invoke-Instaladores` reescrita como pipeline por app: `Install-PacotePronto` → `Install-ViaWinget` → (se `$Opcoes.InstaladorJanela`) fluxo atual de `Start-InstaladorModo`. Fases 1/2 (paralelo/serial com assistente de janelas) passam a rodar só nesse terceiro ramo.
  - Nova `Install-ViaWinget`: testa `winget` disponível + conectividade (`Test-Connection`/HEAD rápido); IDs `AnyDeskSoftwareGmbH.AnyDesk` e busca por nome para os demais; `--silent --accept-package-agreements --accept-source-agreements`; confirma com `Test-InstaladoDeVerdade`.
  - `Export-PacotePronto`: validação pós-cópia (contagem de arquivos/tamanho, presença de `.exe`), cópia de `%APPDATA%`/`%LOCALAPPDATA%` do app quando existir, log detalhado por app.
  - `Install-PacotePronto`: cria atalho e registra no `Uninstall` do Windows (chave simples) para o app ser reconhecido por `Test-AppNoRegistro`.
  - Interface WPF: nova caixa "Tentar instalador com janela (último recurso)" desmarcada por padrão, ligada a `$Opcoes.InstaladorJanela`.
- `public/downloads/versao.json` → 3.3.0 (novidades + histórico); o build sincroniza `.ps1`, LEIA-ME e o ZIP do kit.
- `public/downloads/LEIA-ME.txt`, `src/routes/index.tsx`, `src/routes/versoes.tsx`: nova ordem de instalação e o passo do notebook modelo.
