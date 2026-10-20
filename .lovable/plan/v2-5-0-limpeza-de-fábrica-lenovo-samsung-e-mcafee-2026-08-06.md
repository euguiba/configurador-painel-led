# v2.5.0 — Limpeza de fábrica (Lenovo, Samsung e McAfee)

Novo bloco no configurador: "Limpeza de fábrica", marcado por padrão, que remove os programas inúteis que vêm nos notebooks Lenovo e Samsung, tira o McAfee e desliga a proteção do Windows Defender.

## O que o técnico vê na interface

Um novo grupo na lista de opções:

- Remover programas de fábrica (marcado)
- Remover McAfee e antivírus de teste (marcado)
- Desligar o Windows Defender (marcado)
- Botão "Ver o que será removido" — abre uma janela com a lista dos programas de fábrica encontrados *naquele* notebook, com caixinhas. O técnico desmarca o que quiser manter e confirma. Se não abrir a janela, vale a lista padrão segura.

Tudo aparece no console em tempo real, linha por linha: encontrado, removido, ignorado, erro.

## Regra de segurança: o que nunca é removido

Drivers e utilitários que fazem o notebook funcionar ficam:

- Áudio (Realtek, Dolby, Waves), gráficos (Intel, NVIDIA, AMD), touchpad, câmera, rede
- Gestão de energia e teclas Fn do fabricante (Lenovo Power/Hotkey, Samsung Settings/Easy Settings)
- Firmware/BIOS update do fabricante

## O que entra na lista de remoção

- Lenovo: Vantage, Now, Welcome, Smart, Migration Assistant, Quick Clean, Voice, Companion, App Explorer/Nitro.
- Samsung: Studio Plus, Recovery, Update, Notes, PENUP, Quick Search, Sound/Photo/Video Editor, Samsung Care.
- McAfee: LiveSafe, Security Scan Plus, WebAdvisor, Personal Security.
- Genéricos: Office/OneNote trial, Xbox e Game Bar, TikTok, Spotify stub, Candy Crush, Clipchamp, Bing News/Weather, Solitaire.

## Como cada tipo é removido

- Apps da Store: `Remove-AppxPackage` no usuário atual e `Remove-AppxProvisionedPackage` para não voltarem em usuários novos.
- Programas clássicos: desinstalação silenciosa pela chave do registro (`UninstallString` / `QuietUninstallString`), com tempo limite por programa para não travar o processo.
- McAfee: usa o removedor oficial (MCPR) se estiver na pasta `\Instaladores` do pendrive; senão, desinstalação silenciosa + limpeza dos serviços e tarefas agendadas que sobrarem.

## Desligar o Windows Defender

Feito em duas camadas, porque o Windows protege esses ajustes:

- Políticas no registro (`DisableAntiSpyware`, proteção em tempo real, monitoramento de comportamento, SmartScreen) — valem após o reinício mesmo com Tamper Protection ligado.
- Tentativa imediata via `Set-MpPreference`; se o Windows recusar, o console avisa que só vale depois de reiniciar e, se a Proteção contra Adulteração estiver ativa, orienta o técnico a desligá-la em Segurança do Windows.

Aviso claro no console: o notebook ficará sem antivírus ativo.

## Detalhes técnicos

- `public/downloads/ConfiguradorPainelLED.ps1`
  - Nova função `Invoke-LimpezaFabrica` (bloatware + McAfee) e `Invoke-DesligarDefender`, chamadas cedo no fluxo do worker (antes de Energia), com `Set-Etapa` própria para a barra de progresso.
  - Nova função `Get-ProgramasFabrica`: varre `Uninstall` (HKLM 64/32 bits) e `Get-AppxPackage`, cruza com listas de padrões `RemoverPadrao` e `NuncaRemover`, e devolve objetos usados tanto pela execução quanto pela janela de seleção.
  - Novo XAML: grupo "Limpeza de fábrica" com `cbBloat`, `cbMcAfee`, `cbDefender` e botão `btnVerLista`; janela secundária com `ListBox` de checkboxes, alimentada em background para não travar a UI.
  - `Invoke-Validacao`: novas conferências — McAfee ausente, Defender em tempo real desligado, contagem de bloatware restante.
  - Seleção do técnico transportada para o runspace dentro do hashtable `$Opcoes`.
- `public/downloads/versao.json`: versão 2.5.0 com novidades e histórico (o build sincroniza o `.ps1` e o LEIA-ME sozinho).
- `public/downloads/LEIA-ME.txt`: seção nova sobre limpeza de fábrica e antivírus.
- `src/routes/index.tsx`: destaque do recurso na página do tutorial.
