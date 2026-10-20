# v2.3.0 — Interface que nunca trava, com barra de carregamento

## O problema hoje

Todo o trabalho pesado (energia, Windows Update, OneDrive, busca de apps, validação) roda na mesma thread que desenha a janela. Enquanto o script trabalha, a janela só volta a respirar quando uma linha de log é escrita (`Update-Interface`). Se o técnico clicar em outro botão nesse meio-tempo, o clique entra na fila, o Windows marca a janela como "Não Respondendo" e às vezes duas rotinas começam a rodar ao mesmo tempo.

## O que muda

### 1. O trabalho sai da thread da tela (fim do "sem resposta")

Cada ação longa (VERIFICAR, BACKUP, APLICAR, VALIDAR, PROCURAR APPS, RESTAURAR, VERIFICAR ATUALIZAÇÃO) passa a rodar em um runspace paralelo. A janela continua livre para redesenhar, rolar o log e mostrar animação — mesmo que uma etapa demore minutos.

O log deixa de forçar redesenho a cada linha: as mensagens são enfileiradas e despejadas na caixa de log em lotes, o que também acelera o processo (hoje cada linha custa um ciclo completo de interface).

### 2. Trava de segurança contra cliques

Enquanto uma ação está rodando:
- todos os botões e caixas de seleção ficam desabilitados (não só o APLICAR);
- o cursor vira "ocupado";
- fechar a janela pede confirmação em vez de matar o processo no meio.

Assim é impossível disparar duas rotinas ao mesmo tempo.

### 3. Carregamento visível

Nova faixa de progresso acima dos botões, sempre visível durante a execução:
- **Barra de progresso** com percentual real quando dá para contar as etapas do APLICAR (ex.: 4 de 11 — Energia), e modo indeterminado (animação contínua) nas etapas sem contagem, como instalação de aplicativos.
- **Texto da etapa atual**: "Etapa 4/11 — Configurando energia...".
- **Cronômetro** com o tempo decorrido da ação, atualizado a cada segundo — mostra que o programa está vivo mesmo numa etapa longa.
- Cada bloco do painel esquerdo ganha um indicador de estado ao lado do título: aguardando, em execução, concluído ou com aviso.

### 4. Ganho real de velocidade

- Log em lote em vez de redesenho por linha.
- Chamadas repetidas de `powercfg /list` substituídas por uma única leitura em cache por execução.
- Consultas de disco/memória/bateria do VERIFICAR feitas em uma só chamada CIM por classe, em vez de várias.
- Busca de aplicativos reaproveita o cache já existente e só varre o disco quando o registro não responde.
- Timeout curto (5 s) na consulta de atualização do site, para nunca segurar a interface por rede lenta.

## Atualização de versão

- `public/downloads/versao.json`: nova entrada 2.3.0 com as novidades acima (é a fonte única — o site, os botões de download e o histórico se atualizam sozinhos).
- `public/downloads/ConfiguradorPainelLED.ps1`: versão interna 2.3.0.
- `src/routes/index.tsx`: menção ao acompanhamento de progresso na descrição do fluxo de uso.

## Detalhes técnicos

- `System.Management.Automation.Runspaces.RunspaceFactory` cria um runspace com `SessionStateProxy` recebendo uma fila `ConcurrentQueue[string]` e um objeto de progresso compartilhado.
- `DispatcherTimer` (200 ms) na thread da interface drena a fila para o `txtLog`, atualiza `ProgressBar`, texto de etapa e cronômetro.
- `Write-Log` passa a escrever na fila quando roda dentro do runspace, mantendo o comportamento atual quando roda na thread principal.
- Wrapper `Start-Tarefa -Nome -Etapas -Script` centraliza: bloqueia controles, zera a barra, roda o runspace, e no `EndInvoke` reabilita tudo e grava o status final — inclusive em caso de erro (bloco `finally`), para a interface nunca ficar travada em "Aplicando...".
- Rotinas que reiniciam o Explorer ou usam `SendKeys` (instaladores/plugins) continuam sendo marshalladas para a thread principal, pois dependem da sessão interativa.
