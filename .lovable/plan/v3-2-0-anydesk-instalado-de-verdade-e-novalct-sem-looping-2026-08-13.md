# v3.2.0 — AnyDesk instalado de verdade e NovaLCT sem looping

## 1. AnyDesk: abre em vez de instalar

Hoje o kit chama o `AnyDesk*.exe` com `--install ... --silent` e considera pronto quando o processo sai. Duas coisas quebram isso: as versões novas do AnyDesk só instalam quando a linha de comando é aceita pelo próprio executável (senão ele simplesmente abre a janela do programa em modo avulso), e o atalho da área de trabalho depende de o instalador criá-lo.

O que muda:

- **MSI primeiro.** Se houver um `AnyDesk*.msi` na pasta Instaladores, ele é usado (é o método oficial de instalação silenciosa e nunca abre janela). O site/LEIA-ME passa a recomendar baixar o MSI.
- **EXE com verificação real.** Continuando com o `.exe`, a tentativa silenciosa passa a ser conferida pela existência de `C:\Program Files (x86)\AnyDesk\AnyDesk.exe` (ou `Program Files\AnyDesk`) e da chave de desinstalação — não pelo "processo terminou".
- **Janela avulsa é encerrada.** Se o AnyDesk abrir a interface em vez de instalar, o processo é fechado, e o kit tenta o modo assistido (janela visível + assistente clicando em "Aceitar e instalar").
- **Atalho garantido pelo kit.** Depois de instalado, se não existir `AnyDesk.lnk` na Área de Trabalho Pública, o próprio configurador cria o atalho (mesma rotina já usada para LedVision/NovaLCT), além do atalho de inicialização automática.
- **Resultado no console** dizendo qual caminho funcionou (MSI, silencioso ou assistido) e se o atalho foi criado pelo kit.

## 2. NovaLCT: looping entre as telas

O assistente atual é genérico: procura qualquer botão que "pareça" avançar em qualquer janela. No NovaLCT ele fica alternando entre a mesma tela de permissão/driver e nunca sai.

O que muda — três camadas, nesta ordem:

1. **Roteiro dedicado do NovaLCT.** Em vez do clicador genérico, uma máquina de estados só para as janelas do NovaLCT: cada tela é identificada pelo título + textos dos botões, cada tela tem **uma** ação definida (idioma → OK, contrato → marcar aceite e Avançar, pasta → Avançar, drivers/plugins → Instalar, conclusão → desmarcar "executar agora" e Concluir). Uma tela já resolvida não recebe clique de novo.
2. **Trava anti-looping por tela.** Assinatura da janela (título + textos) guardada com contador: repetiu 3 vezes sem mudar, muda de estratégia (ENTER/ALT+atalho do botão) e, se ainda repetir, abandona o NovaLCT com motivo claro no console em vez de travar a fila.
3. **Tempo de espera menor.** O limite do modo assistido cai de 15 para 8 minutos e a conferência passa a ser por presença do NovaLCT no disco/registro a cada ciclo — assim que aparecer instalado, o kit encerra a janela e segue, sem esperar o processo sair.

## 3. Opções alternativas de instalação (mais rápidas, sem depender de janela)

Duas ficam disponíveis no kit; a terceira é uma recomendação de processo.

- **Modo "cópia pronta" (recomendado, o mais rápido).** Instale o NovaLCT **uma vez** num notebook de referência, e o kit passa a ter um botão "GERAR PACOTE PRONTO" que empacota a pasta do programa + as chaves de registro dele para dentro de `Instaladores\Prontos\NovaLCT`. Nos notebooks seguintes o configurador só copia a pasta, restaura as chaves e cria os atalhos: segundos, sem nenhuma janela e sem risco de looping. Mesma coisa serve para LedVision.
- **Modo silencioso via MSI extraído.** Quando o instalador do NovaLCT for um empacotador que aceita extração, o kit tenta extrair o MSI interno e instalar com `msiexec /qn`, antes de partir para a janela.
- **Fila em vez de paralelo para os assistidos.** AnyDesk (silencioso) continua em paralelo, mas NovaLCT e LedVision assistidos passam a rodar **um por vez**, para o assistente não confundir janelas de instaladores diferentes — hoje isso é uma das causas do clique errado.

## Detalhes técnicos

- `public/downloads/ConfiguradorPainelLED.ps1`
  - `Get-TentativasInstalacao`: AnyDesk ganha `MSI` como primeiro modo quando houver `.msi`; mantém `--install ... --silent` e acrescenta `ASSISTIDO` como último recurso.
  - Nova `Test-AnyDeskInstalado` (pasta + `HKLM:\...\Uninstall\AnyDesk`) e `New-AtalhoDesktopPublico` reutilizada para criar `AnyDesk.lnk` quando faltar.
  - `Start-AceitadorDeJanelas`: novo parâmetro `-Perfil NovaLCT` com tabela `titulo/botões → ação única`, dicionário de assinatura por hwnd com contador e escalonamento (clique → ENTER → abandono).
  - `Invoke-Instaladores`: separa as tarefas em silenciosas (paralelo) e assistidas (fila serial); `timeoutAssist` 8 min; verificação de instalação a cada ciclo, com `WM_CLOSE` na janela remanescente.
  - Novas `Export-PacotePronto` / `Install-PacotePronto` (copiar pasta + `reg import`) e botão correspondente na interface WPF.
- `public/downloads/versao.json` → 3.2.0 (novidades + histórico); build sincroniza `.ps1`, LEIA-ME e o ZIP do kit.
- `src/routes/index.tsx` e `src/routes/versoes.tsx`: novidades da versão e instrução de preferir o MSI do AnyDesk / usar o pacote pronto.
