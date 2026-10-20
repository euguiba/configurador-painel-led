# v3.0.0 — Instalação em paralelo que conclui sozinha e desinstalação de fábrica que realmente remove

Dois problemas separados, com causas diferentes.

## 1. Instalação dos aplicativos

O que acontece hoje: o assistente de janelas só clica no **primeiro** botão que combina com a lista, nunca desmarca opções que vêm pré-selecionadas em "cancelar/não permitir", não fecha a janela final ("Concluir") e os apps são instalados **um por vez**, esperando cada um terminar.

O que muda:

- **Leitura do que está selecionado.** O assistente passa a ler o estado real de cada caixa e cada botão de opção da janela (marcado / desmarcado / desabilitado). Regra: marcar tudo que for "aceito / concordo / instalar / criar atalho / sim", desmarcar tudo que for "não aceito / não instalar / cancelar / recusar / instalar depois", e só então clicar no botão de avançar.
- **Prioridade de botões.** Em vez de clicar no primeiro que casar, o assistente escolhe por ordem de prioridade: Instalar > Avançar/Próximo > Aceito/Concordo > Sim/OK > Concluir/Finalizar. Botões desabilitados (cinza) são ignorados e ele tenta de novo no ciclo seguinte, depois de marcar o aceite.
- **Fim de instalação fecha sozinho.** Ao detectar a tela final (Concluir / Finish / "instalação concluída"), o assistente desmarca "Executar o programa agora" / "Reiniciar agora" antes de clicar em Concluir, e fecha a janela se ela ficar aberta. É isso que hoje trava a fila.
- **Anti-looping.** Cada janela ganha um contador: se a mesma janela receber o mesmo clique mais de X vezes sem mudar de tela, o assistente muda de estratégia (teclado / próximo botão da lista) e, se ainda assim não sair, registra no console e segue para o próximo app em vez de ficar preso.
- **Instalação em paralelo.** AnyDesk, LedVision e NovaLCT passam a ser iniciados juntos, com um único assistente cuidando de todas as janelas ao mesmo tempo. A espera é por conclusão de todos, com tempo limite global; o console mostra o andamento de cada um. (O AnyDesk é silencioso e termina primeiro; os outros dois são os que precisam do assistente.)
- **Resumo por app no fim**, com o motivo em caso de falha.

## 2. Desinstalação dos programas de fábrica

O que acontece hoje: cada programa é chamado com `-WindowStyle Hidden` e argumentos genéricos (`/S /silent /quiet`). A maioria dos desinstaladores Lenovo/Samsung não entende esses parâmetros e abre uma janela invisível esperando confirmação — o script espera, mata o processo e mesmo assim escreve "Removido". Por isso "não acontece nada" e o console engana.

O que muda:

- **Conferência de verdade.** Depois de cada tentativa, o script reconsulta o registro/Appx e só marca como removido se o programa realmente sumiu. Se continuar, aparece em vermelho.
- **Argumentos por tipo de desinstalador.** Detecta MSI, Inno Setup, NSIS, InstallShield e usa o parâmetro silencioso correto de cada um, em vez de jogar todos juntos.
- **Segunda tentativa assistida.** Se o modo silencioso falhar, o desinstalador é aberto **na tela** com o mesmo assistente de janelas da instalação (que agora sabe clicar em "Desinstalar / Sim / Remover" e desmarcar "manter configurações").
- **Terceira via para apps da Loja e da fabricante:** remoção via `winget uninstall --silent` quando disponível, e remoção do pacote provisionado para não voltar em usuários novos.
- **Diagnóstico no console.** Para cada programa: nome, tipo de desinstalador detectado, comando usado, resultado e — quando falhar — a razão (sem desinstalador registrado, protegido, exige reinício).
- **Lista final "ainda instalado"** com os nomes, para o técnico saber exatamente o que sobrou.

## Detalhes técnicos

- `public/downloads/ConfiguradorPainelLED.ps1`
  - `Start-AceitadorDeJanelas`: classe `GLWin` ganha `IsWindowEnabled`, `BM_GETCHECK/BM_SETCHECK` para radio e checkbox, e `WM_CLOSE`. Nova lógica em três fases por janela: (1) normalizar seleções — marcar padrões `aceitar/concordo/instalar/criar atalho`, desmarcar padrões `recusar/nao instalar/executar agora/reiniciar agora`; (2) escolher botão por prioridade ignorando `!IsWindowEnabled`; (3) detectar tela final e fechar. Dicionário de assinatura por hwnd para o anti-looping.
  - `Invoke-Instaladores`: um único assistente, `Start-Process -PassThru` para todos os instaladores elegíveis, laço de espera com `WaitForExit(0)`/polling e tempo limite global; remove a espera sequencial por app.
  - `Remove-ProgramaFabrica`: nova `Get-TipoDesinstalador` (MSI / Inno / NSIS / InstallShield / outro) e `Get-ArgsDesinstalacao`; verificação pós-remoção com `Test-ProgramaAindaInstalado`; fallback assistido com janela visível e assistente ligado; fallback `winget uninstall`.
  - `Invoke-LimpezaFabrica`: liga o assistente antes do laço, contabiliza removidos/falhas com base na verificação real e imprime a lista do que sobrou.
- `public/downloads/versao.json` → 3.0.0 com novidades e histórico (o build sincroniza `.ps1`, LEIA-ME e o ZIP do kit).
- `src/routes/index.tsx`: destaque das novidades da versão.
