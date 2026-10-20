import { createFileRoute } from "@tanstack/react-router";
import { ARQUIVO_KIT, ARQUIVO_SCRIPT, VERSAO_ATUAL } from "@/lib/versao";
import {
  AlertCircle,
  BatteryCharging,
  Bell,
  Check,
  CheckCircle2,
  ChevronRight,
  Clock,
  Cloud,
  Download,
  ExternalLink,
  FileArchive,
  FolderOpen,
  Gauge,
  HardDrive,
  History,
  LayoutDashboard,
  ListChecks,
  Monitor,
  MonitorCog,
  MousePointerClick,
  Palette,
  RefreshCw,
  ShieldAlert,
  ShieldCheck,
  Terminal,
  Trash2,
  Usb,
  UserRound,
} from "lucide-react";
import { Link } from "@tanstack/react-router";


export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "Configurador de Notebook para Painéis de LED | Pendrive Técnico" },
      {
        name: "description",
        content:
          "Kit em PowerShell com interface gráfica para padronizar notebooks de painéis de LED: energia, notificações, barra de tarefas, OneDrive, conta local e AnyDesk, LedVision e NovaLCT.",
      },
      { property: "og:title", content: "Configurador de Notebook para Painéis de LED | Pendrive Técnico" },
      {
        property: "og:description",
        content:
          "Kit em PowerShell com interface gráfica para padronizar notebooks de painéis de LED: energia, notificações, barra de tarefas, OneDrive, conta local e AnyDesk, LedVision e NovaLCT.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Index,
});

const modulos = [
  {
    icon: BatteryCharging,
    titulo: "Energia",
    itens: [
      "Plano de Desempenho Máximo ativado",
      "Fechar a tampa e botões de energia/suspender: nada a fazer — em todos os planos, na tomada e na bateria",
      "Nunca desligar vídeo e nunca suspender — em todos os planos, na tomada e na bateria",
      "USB sem suspensão seletiva, CPU mínima em 100%",
      "Hibernação, protetor de tela e bloqueio automático desligados",
    ],
  },
  {
    icon: Clock,
    titulo: "Atualizações na madrugada",
    itens: [
      "Windows Update baixa e instala tudo automaticamente a partir das 00:30",
      "Por padrão o notebook NUNCA reinicia sozinho — nem depois de atualização, nem em horário fixo",
      "Horário ativo das 06:00 às 00:00: nem atualização forçada reinicia durante o dia",
      "Reinício automático opcional: só de madrugada (até 06:00) e só quando o Windows Update pedir",
      "Botão “DESLIGAR REINÍCIO AUTOMÁTICO AGORA” para notebooks já configurados",

    ],
  },
  {
    icon: Bell,
    titulo: "Notificações",
    itens: [
      "Todas as notificações e avisos pop-up desativados",
      "Dicas, sugestões e conteúdo em destaque desligados",
      "Avisos de atualização na tela ocultos",
    ],
  },

  {
    icon: LayoutDashboard,
    titulo: "Barra de tarefas",
    itens: [
      "Mantém Iniciar, Pesquisar e Explorador de Arquivos",
      "Mantém bandeja: wi-fi, bateria, volume, data e hora",
      "Remove widgets, chat, visão de tarefas e Copilot",
      "Limpa itens fixados e ícones extras da área de trabalho",
    ],
  },
  {
    icon: Cloud,
    titulo: "OneDrive",
    itens: [
      "Encerra e desinstala o OneDrive",
      "Desconecta a conta e bloqueia a sincronização por política",
      "Remove da inicialização do Windows",
    ],
  },
  {
    icon: UserRound,
    titulo: "Perfis de usuário",
    itens: [
      "O configurador não cria mais conta local — o notebook segue na conta que já existe no Windows",
      "As configurações são gravadas no usuário atual e no perfil padrão do Windows",
      "Qualquer usuário criado depois já nasce com os mesmos ajustes",
    ],
  },

  {
    icon: ShieldCheck,
    titulo: "Verificação e backup",
    itens: [
      "Checa disco, memória, bateria, internet e instaladores antes de aplicar",
      "Cria ponto de restauração do Windows",
      "Salva backup das configurações na pasta Backups do pendrive",
      "Botão RESTAURAR desfaz tudo em campo",
    ],
  },
  {
    icon: ListChecks,
    titulo: "Validação pós-aplicação",
    itens: [
      "Confere item a item se cada ajuste realmente foi aplicado",
      "Mostra quantos itens estão OK e quantos precisam de atenção",
      "Relatório salvo automaticamente na área de trabalho",
    ],
  },
  {
    icon: Palette,
    titulo: "Tema e papel de parede",
    itens: [
      "Tema escuro do Windows e cor de destaque laranja",
      "Papel de parede oficial da Global LED no desktop e na tela de bloqueio",
      "Usa o arquivo Wallpaper.jpg que fica no pendrive",
    ],
  },
  {
    icon: RefreshCw,
    titulo: "Instaladores prontos na área de trabalho",
    itens: [
      "A instalação automática foi retirada: ela travava e deixava os aplicativos pela metade",
      "O configurador cria a pasta “Instalar Programas LED” na área de trabalho com AnyDesk, LedVision e NovaLCT prontos",
      "Bilhete “LEIA ANTES.txt” dentro da pasta com a ordem de instalação para o técnico",
      "Depois que o notebook reinicia, o técnico instala os três em 2 minutos, aceitando tudo o que o instalador pedir",
    ],
  },
  {
    icon: ShieldCheck,
    titulo: "Fim do travamento depois de alguns dias",
    itens: [
      "Desliga o “Controle de Aplicativos Inteligente” do Windows 11 (Smart App Control) de forma definitiva",
      "Desliga o SmartScreen de aplicativos, arquivos e da loja — instalação liberada para programas de qualquer origem",
      "Fim do aviso de “editor desconhecido” e da marca de origem que travava o AppData do AnyDesk",
      "O notebook não bloqueia mais a abertura dos programas do painel depois de alguns dias configurado",
    ],
  },

  {
    icon: Gauge,
    titulo: "Interface que não trava",
    itens: [
      "O trabalho pesado roda em segundo plano: a janela nunca fica “sem resposta”",
      "Barra de progresso com a etapa atual e cronômetro do tempo decorrido",
      "Cada bloco mostra “em andamento…” e “concluído” enquanto o script trabalha",
      "Botões bloqueados durante a execução para evitar cliques repetidos",
      "Busca de aplicativos e desinstalações com limite de tempo: o processo todo não fica mais preso por um instalador travado",

    ],
  },
  {
    icon: Terminal,
    titulo: "Console em tempo real",
    itens: [
      "Log colorido ao vivo: verde para OK, laranja para aviso e vermelho para erro",
      "Horário exato em cada linha e contadores de OK, avisos e erros no topo",
      "Filtro “somente avisos e erros” para achar o problema sem rolar tudo",
      "Botões copiar e limpar, rolagem automática opcional e última linha sempre visível",
    ],
  },
  {
    icon: Trash2,
    titulo: "Limpeza de fábrica",
    itens: [
      "A McAfee é desarmada logo no início: processos, serviços e drivers parados antes de tudo",
      "Arquivos do pendrive desbloqueados e adicionados às exclusões — nada mais é barrado",
      "Botão “0. excluir antivírus agora” para parar a proteção, desinstalar e conferir o resultado",
      "Se a autoproteção bloquear tudo, o notebook reinicia sozinho em Modo de Segurança, remove o antivírus e volta ao Windows normal",
      "Botão “remover pelo Modo de Segurança” para forçar essa limpeza quando quiser, com relatório salvo em C:\\PainelLED\\ModoSeguro",

      "Remove os programas inúteis que vêm de fábrica nos notebooks Lenovo e Samsung — e agora com desinstalação que realmente funciona",
      "Detecta o tipo de desinstalador (MSI, Inno, NSIS, InstallShield) e usa o parâmetro silencioso correto de cada um",
      "Confere no registro se o programa sumiu de verdade; nada de “concluído” enganoso",
      "Se o silencioso falhar, abre o desinstalador na tela com o assistente ligado; última tentativa via winget",
      "No fim, lista os programas que ainda restaram para o técnico saber exatamente o que sobrou",
      "Opção de desligar o Windows Defender (o notebook fica sem antivírus ativo)",
      "Botão “ver o que será removido”: dá para desmarcar o que deve ficar no notebook",
      "Drivers, áudio, vídeo, teclas Fn e utilitários de energia nunca são removidos",
    ],

  },



];



const passos = [
  "Conecte o pendrive e abra a unidade no Explorador de Arquivos.",
  "Dê dois cliques em INICIAR.cmd (único arquivo de inicialização).",
  "No menu, escolha 1 para configurar (ele entra sozinho em 5 segundos).",
  "Clique em SIM no aviso do Windows (é o pedido de permissão de administrador).",
  "Clique em 1. VERIFICAR e leia os pontos de atenção.",
  "Clique em 2. BACKUP para criar o ponto de restauração.",
  "Use MARCAR TUDO ou selecione o que precisa e clique em 3. APLICAR SELECIONADOS.",
  "Clique em 4. VALIDAR, confira o resultado e reinicie o notebook.",
];

const pendrive = [
  { nome: "INICIAR.cmd", desc: "Único arquivo de inicialização: configura o notebook ou pula o OOBE." },
  { nome: "ConfiguradorPainelLED.ps1", desc: "O script com toda a automação." },
  { nome: "Wallpaper.jpg", desc: "Papel de parede oficial aplicado no desktop e na tela de bloqueio." },
  { nome: "LEIA-ME.txt", desc: "Instruções rápidas para o técnico em campo." },
  { nome: "Instaladores\\", desc: "Coloque aqui os .exe do AnyDesk, LedVision e NovaLCT." },
  { nome: "Backups\\", desc: "Criada sozinha: guarda o backup de cada notebook configurado." },
  { nome: "_sistema\\", desc: "Arquivos internos: autorun.inf, autounattend.xml e a pasta VTOYEFI do Ventoy." },
];


function Index() {
  return (
    <main className="min-h-screen">
      <div className="grid-lines">
        <section className="mx-auto max-w-5xl px-6 pt-20 pb-14">
          <span className="inline-flex items-center gap-2 rounded-full border border-primary/40 bg-primary/10 px-3 py-1 font-mono text-xs uppercase tracking-widest text-primary">
            <Usb className="size-3.5" /> Pendrive de instalação
          </span>
          <h1 className="mt-6 text-4xl font-bold leading-tight sm:text-5xl">
            Configurador de notebook para{" "}
            <span className="text-primary">painéis de LED</span>
          </h1>
          <p className="mt-5 max-w-2xl text-lg text-muted-foreground">
            Um único script PowerShell com{" "}
            <strong className="text-foreground">interface gráfica</strong>: o técnico abre,
            marca o que precisa e aplica. Energia, notificações, barra de tarefas, OneDrive,
            conta local e os aplicativos do painel — tudo padronizado em minutos, com log na
            tela e relatório salvo na área de trabalho.
          </p>

          <div className="mt-8 flex flex-col gap-4 sm:flex-row sm:items-center">
            <a
              href={ARQUIVO_KIT}
              download
              className="inline-flex items-center justify-center gap-2 rounded-lg bg-primary px-6 py-4 text-lg font-semibold text-primary-foreground transition hover:opacity-90"
            >
              <FileArchive className="size-5" /> Baixar kit completo do pendrive v{VERSAO_ATUAL}
            </a>
            <a
              href={ARQUIVO_SCRIPT}
              download
              className="inline-flex items-center justify-center gap-2 rounded-lg border border-border bg-secondary px-5 py-3 font-semibold text-secondary-foreground transition hover:bg-muted"
            >
              <Download className="size-4" /> Baixar só o script
            </a>
            <Link
              to="/versoes"
              className="inline-flex items-center justify-center gap-2 rounded-lg border border-primary/40 bg-primary/10 px-5 py-3 font-semibold text-primary transition hover:bg-primary/20"
            >
              <History className="size-4" /> Histórico de versões
            </Link>
          </div>
          <p className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 font-mono text-xs text-muted-foreground">
            <span>Kit: {ARQUIVO_KIT.replace("/downloads/", "")}</span>
            <span>·</span>
            <a
              href="#arquivos-separados"
              className="text-primary underline hover:no-underline"
            >
              Precisa baixar arquivos separados?
            </a>
          </p>
        </section>
      </div>

      <section className="mx-auto max-w-5xl px-6 pb-16">
        <div className="flex items-center gap-3">
          <span className="flex size-9 items-center justify-center rounded-lg bg-primary/12 text-primary">
            <Usb className="size-5" />
          </span>
          <h2 className="text-2xl font-bold">Como montar o pendrive passo a passo</h2>
        </div>

        <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <div className="panel p-5">
            <div className="flex size-8 items-center justify-center rounded-lg bg-primary font-mono font-bold text-primary-foreground">1</div>
            <h3 className="mt-3 font-semibold">Baixe o kit</h3>
            <p className="mt-2 text-sm text-muted-foreground">
              Clique em <strong className="text-foreground">Baixar kit completo do pendrive</strong>.
              O arquivo ZIP já traz a estrutura correta.
            </p>
          </div>
          <div className="panel p-5">
            <div className="flex size-8 items-center justify-center rounded-lg bg-primary font-mono font-bold text-primary-foreground">2</div>
            <h3 className="mt-3 font-semibold">Formate o pendrive</h3>
            <p className="mt-2 text-sm text-muted-foreground">
              Use FAT32 ou exFAT. O Windows lê bem os dois e o OOBE também enxerga o pendrive.
            </p>
          </div>
          <div className="panel p-5">
            <div className="flex size-8 items-center justify-center rounded-lg bg-primary font-mono font-bold text-primary-foreground">3</div>
            <h3 className="mt-3 font-semibold">Extraia na raiz</h3>
            <p className="mt-2 text-sm text-muted-foreground">
              Arraste tudo para a raiz do pendrive. Não coloque dentro de outra pasta.
            </p>
          </div>
          <div className="panel p-5">
            <div className="flex size-8 items-center justify-center rounded-lg bg-primary font-mono font-bold text-primary-foreground">4</div>
            <h3 className="mt-3 font-semibold">Coloque os instaladores</h3>
            <p className="mt-2 text-sm text-muted-foreground">
              Copie AnyDesk, LedVision, NovaLCT e o MCPR (se tiver) para a pasta{" "}
              <code className="font-mono text-primary">Instaladores</code>.
            </p>
          </div>
        </div>

        <div className="mt-6 grid gap-6 lg:grid-cols-2">
          <div className="panel overflow-hidden">
            <div className="flex items-center gap-2 border-b border-border bg-background/40 px-4 py-2.5">
              <FolderOpen className="size-4 text-primary" />
              <span className="font-mono text-xs text-muted-foreground">Estrutura final do pendrive</span>
            </div>
            <pre className="overflow-x-auto p-5 font-mono text-[13px] leading-relaxed text-terminal">
{`P:\\
├── INICIAR.cmd                → único arquivo para abrir
├── ConfiguradorPainelLED.ps1  → o script principal
├── Wallpaper.jpg              → papel de parede oficial
├── LEIA-ME.txt                → instruções rápidas
├── Instaladores\\              → AnyDesk, LedVision, NovaLCT, MCPR
├── Backups\\                    → backup de cada notebook
└── _sistema\\                   → arquivos internos (autorun, OOBE, Ventoy)`}
            </pre>
          </div>

          <div className="panel border-primary/40 bg-primary/5 p-5">
            <h3 className="flex items-center gap-2 font-semibold">
              <MousePointerClick className="size-5 text-primary" /> Depois de montado
            </h3>
            <ul className="mt-4 space-y-3 text-sm text-muted-foreground">
              <li className="flex gap-2">
                <Check className="mt-0.5 size-4 shrink-0 text-success" />
                <span>
                  <strong className="text-foreground">Notebook novo (OOBE):</strong> pressione Shift+F10, digite <code className="font-mono text-primary">explorer</code>, abra o pendrive, execute <code className="font-mono text-primary">INICIAR.cmd</code> e escolha a opção 2.
                </span>
              </li>
              <li className="flex gap-2">
                <Check className="mt-0.5 size-4 shrink-0 text-success" />
                <span>
                  <strong className="text-foreground">Notebook já configurado:</strong> abra a pasta do pendrive, dê dois cliques em{" "}
                  <code className="font-mono text-primary">INICIAR.cmd</code> e escolha a opção 1.
                </span>
              </li>
              <li className="flex gap-2">
                <Check className="mt-0.5 size-4 shrink-0 text-success" />
                <span>
                  <strong className="text-foreground">Vários notebooks ao mesmo tempo (modo portátil):</strong> execute{" "}
                  <code className="font-mono text-primary">INICIAR.cmd</code> e escolha a opção 3. O configurador e os instaladores são copiados para{" "}
                  <code className="font-mono text-primary">C:\ConfiguradorLED</code>, a configuração começa sozinha e você já pode tirar o pendrive e levar para o próximo notebook.
                </span>
              </li>
              <li className="flex gap-2">
                <Check className="mt-0.5 size-4 shrink-0 text-success" />
                <span>
                  <strong className="text-foreground">Importante:</strong> Windows 11 bloqueia AutoRun em USB; o kit precisa ser aberto manualmente.
                </span>
              </li>
            </ul>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-5xl px-6 pb-16">
        <div className="grid gap-6 lg:grid-cols-2">
          <div className="panel p-5">
            <div className="flex items-center gap-3">
              <span className="flex size-9 items-center justify-center rounded-lg bg-primary/12 text-primary">
                <Monitor className="size-5" />
              </span>
              <h3 className="text-lg font-semibold">Notebook novo — pular o OOBE</h3>
            </div>
            <p className="mt-4 text-sm text-muted-foreground">
              Conectar o pendrive durante o OOBE não faz o Windows reler o <code className="font-mono text-primary">autounattend.xml</code>. Use o procedimento abaixo.
            </p>
            <ol className="mt-4 space-y-2 text-sm text-muted-foreground">
              <li className="flex gap-2">
                <span className="flex size-5 shrink-0 items-center justify-center rounded bg-muted font-mono text-xs">1</span>
                <span>Ligue o notebook <strong className="text-foreground">sem internet</strong>.</span>
              </li>
              <li className="flex gap-2">
                <span className="flex size-5 shrink-0 items-center justify-center rounded bg-muted font-mono text-xs">2</span>
                <span>Na primeira tela, plugue o pendrive, pressione <strong className="text-foreground">Shift+F10</strong>, digite <code className="font-mono text-primary">explorer</code> e pressione Enter.</span>
              </li>
              <li className="flex gap-2">
                <span className="flex size-5 shrink-0 items-center justify-center rounded bg-muted font-mono text-xs">3</span>
                <span>No Explorador, abra o pendrive, execute <code className="font-mono text-primary">INICIAR.cmd</code> e escolha a opção 2. Ele grava o <strong className="text-foreground">arquivo de resposta do Windows</strong> em <code className="font-mono text-primary">C:\Windows\Panther\unattend.xml</code> com a conta local <strong className="text-foreground">Global</strong> (administrador, sem senha), logon automático e todas as telas do OOBE desligadas, e <strong className="text-foreground">reinicia o notebook</strong> direto para a área de trabalho.</span>
              </li>
              <li className="flex gap-2">
                <span className="flex size-5 shrink-0 items-center justify-center rounded bg-muted font-mono text-xs">4</span>
                <span>Depois do reinício o Windows abre direto na área de trabalho da conta Global. Execute <code className="font-mono text-primary">INICIAR.cmd</code>, escolha a opção 1 e clique em Sim.</span>

              </li>

            </ol>
            <div className="mt-4 flex items-start gap-2 rounded-lg border border-warning/30 bg-warning/5 p-3 text-sm text-warning">
              <AlertCircle className="mt-0.5 size-4 shrink-0" />
              <span>
                O arquivo autounattend só é lido quando a instalação do Windows começa com o USB já conectado; ele não é um inicializador automático no OOBE de fábrica.
              </span>
            </div>
          </div>

          <div className="panel border-primary/40 bg-primary/5 p-5">
            <div className="flex items-center gap-3">
              <span className="flex size-9 items-center justify-center rounded-lg bg-primary/12 text-primary">
                <HardDrive className="size-5" />
              </span>
              <h3 className="text-lg font-semibold">Sobre Ventoy e AutoRun</h3>
            </div>
            <p className="mt-4 text-sm text-muted-foreground">
              O Ventoy é útil para iniciar imagens ISO, mas não libera a execução automática de programas no desktop do Windows 11.
            </p>
            <ol className="mt-4 space-y-2 text-sm text-muted-foreground">
              <li className="flex gap-2">
                <span className="flex size-5 shrink-0 items-center justify-center rounded bg-muted font-mono text-xs">1</span>
                <span>
                  Baixe e instale o <a href="https://www.ventoy.net" target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-1 text-primary underline hover:no-underline">Ventoy <ExternalLink className="size-3" /></a> no pendrive.
                </span>
              </li>
              <li className="flex gap-2">
                <span className="flex size-5 shrink-0 items-center justify-center rounded bg-muted font-mono text-xs">2</span>
                <span>Extraia o kit na <strong className="text-foreground">partição grande</strong> do pendrive (aquela que você já usa normalmente).</span>
              </li>
              <li className="flex gap-2">
                <span className="flex size-5 shrink-0 items-center justify-center rounded bg-muted font-mono text-xs">3</span>
                <span>Copie a pasta <code className="font-mono text-primary">_sistema\VTOYEFI</code> inteira para a <strong className="text-foreground">partição CD</strong> (geralmente aparece como VTOYEFI).</span>
              </li>
              <li className="flex gap-2">
                <span className="flex size-5 shrink-0 items-center justify-center rounded bg-muted font-mono text-xs">4</span>
                <span>Mesmo com Ventoy, abra a partição grande e execute <code className="font-mono text-primary">INICIAR.cmd</code> manualmente.</span>
              </li>
            </ol>
            <div className="mt-4 rounded-lg border border-border bg-background/60 p-3">
              <p className="text-sm font-semibold">Estrutura no Ventoy</p>
              <pre className="mt-2 overflow-x-auto font-mono text-xs leading-relaxed text-terminal">
{`Particao grande:
  INICIAR.cmd, ConfiguradorPainelLED.ps1,
  Wallpaper.jpg, LEIA-ME.txt,
  Instaladores\\, Backups\\, _sistema\\

Particao CD (VTOYEFI):
  VTOYEFI\\
    ├── autorun.inf
    ├── AbrirConfigurador.bat
    └── Configurador.ico`}
              </pre>
            </div>
          </div>
        </div>
      </section>

      <section id="arquivos-separados" className="mx-auto max-w-5xl px-6 pb-16">
        <h2 className="text-2xl font-bold">Arquivos separados</h2>
        <p className="mt-2 text-sm text-muted-foreground">
          Só use estas opções se você já sabe exatamente onde cada arquivo deve ficar. O kit ZIP acima já faz isso automaticamente.
        </p>
        <div className="panel mt-6 divide-y divide-border">
          {pendrive.map((f) => (
            <div key={f.nome} className="flex flex-wrap items-baseline gap-x-4 gap-y-1 px-5 py-3">
              <span className="font-mono text-sm text-primary">{f.nome}</span>
              <span className="text-sm text-muted-foreground">{f.desc}</span>
            </div>
          ))}
        </div>
        <div className="mt-4 flex flex-wrap gap-3">
          <a
            href="/downloads/INICIAR.cmd"
            download
            className="inline-flex items-center gap-2 rounded-lg border border-border bg-secondary px-4 py-2 text-sm font-semibold text-secondary-foreground transition hover:bg-muted"
          >
            <Download className="size-4" /> INICIAR.cmd
          </a>
          <a
            href={ARQUIVO_SCRIPT}
            download
            className="inline-flex items-center gap-2 rounded-lg border border-border bg-secondary px-4 py-2 text-sm font-semibold text-secondary-foreground transition hover:bg-muted"
          >
            <Download className="size-4" /> ConfiguradorPainelLED.ps1
          </a>
          <a
            href="/downloads/Wallpaper.jpg"
            download
            className="inline-flex items-center gap-2 rounded-lg border border-border bg-secondary px-4 py-2 text-sm font-semibold text-secondary-foreground transition hover:bg-muted"
          >
            <Download className="size-4" /> Wallpaper.jpg
          </a>
          <a
            href="/downloads/LEIA-ME.txt"
            download
            className="inline-flex items-center gap-2 rounded-lg border border-border bg-secondary px-4 py-2 text-sm font-semibold text-secondary-foreground transition hover:bg-muted"
          >
            <Download className="size-4" /> LEIA-ME.txt
          </a>
          <a
            href="/downloads/_sistema/autounattend.xml"
            download
            className="inline-flex items-center gap-2 rounded-lg border border-border bg-secondary px-4 py-2 text-sm font-semibold text-secondary-foreground transition hover:bg-muted"
          >
            <Download className="size-4" /> _sistema/autounattend.xml
          </a>
          <a
            href="/downloads/_sistema/autorun.inf"
            download
            className="inline-flex items-center gap-2 rounded-lg border border-border bg-secondary px-4 py-2 text-sm font-semibold text-secondary-foreground transition hover:bg-muted"
          >
            <Download className="size-4" /> _sistema/autorun.inf
          </a>
        </div>
      </section>


      <section className="mx-auto max-w-5xl px-6 pb-16">
        <div className="panel overflow-hidden">
          <div className="flex items-center gap-2 border-b border-border bg-background/40 px-4 py-2.5">
            <span className="size-2.5 rounded-full bg-destructive/70" />
            <span className="size-2.5 rounded-full bg-warning/70" />
            <span className="size-2.5 rounded-full bg-success/70" />
            <span className="ml-2 font-mono text-xs text-muted-foreground">
              Configurador de Notebook — Painéis de LED
            </span>
          </div>
          <pre className="overflow-x-auto px-5 py-5 font-mono text-[13px] leading-relaxed text-terminal">
{`=== ENERGIA / DESEMPENHO ===
[OK]   Plano de energia de Desempenho Maximo ativado.
[OK]   Tela, disco, suspensao e hibernacao: NUNCA (bateria e tomada).
[OK]   Fechar a tampa / botao de energia: NAO FAZER NADA.

=== BARRA DE TAREFAS E INTERFACE ===
[OK]   Widgets, chat, visao de tarefas e Copilot removidos. Pesquisa mantida.
[OK]   Icones de wifi, bateria, volume e relogio visiveis.

=== APLICATIVOS DO PAINEL ===
[OK]   AnyDesk encontrado: C:\\Program Files (x86)\\AnyDesk\\AnyDesk.exe
[OK]   NovaLCT encontrado: C:\\NovaLCT\\NovaLCT-Mars V5.4.6.exe
[!]    LedVision: NAO ENCONTRADO - instale o programa e rode este item de novo.`}
          </pre>
        </div>
      </section>

      <section className="mx-auto max-w-5xl px-6 pb-16">
        <h2 className="text-2xl font-bold">O que o script faz</h2>
        <div className="mt-6 grid gap-4 sm:grid-cols-2">
          {modulos.map((m) => (
            <article key={m.titulo} className="panel p-5">
              <div className="flex items-center gap-3">
                <span className="flex size-9 items-center justify-center rounded-lg bg-primary/12 text-primary">
                  <m.icon className="size-5" />
                </span>
                <h3 className="text-lg font-semibold">{m.titulo}</h3>
              </div>
              <ul className="mt-4 space-y-2">
                {m.itens.map((i) => (
                  <li key={i} className="flex gap-2 text-sm text-muted-foreground">
                    <CheckCircle2 className="mt-0.5 size-4 shrink-0 text-success" />
                    <span>{i}</span>
                  </li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </section>

      <section className="mx-auto max-w-5xl px-6 pb-16">
        <h2 className="text-2xl font-bold">Como o técnico usa em campo</h2>
        <ol className="mt-6 space-y-3">
          {passos.map((p, idx) => (
            <li key={p} className="panel flex items-start gap-4 p-4">
              <span className="flex size-8 shrink-0 items-center justify-center rounded-lg bg-primary font-mono font-bold text-primary-foreground">
                {idx + 1}
              </span>
              <span className="pt-1.5 text-sm">{p}</span>
            </li>
          ))}
        </ol>
      </section>

      <section className="mx-auto max-w-5xl px-6 pb-24">
        <div className="panel border-warning/40 bg-warning/5 p-5">
          <div className="flex items-center gap-3">
            <ShieldAlert className="size-5 text-warning" />
            <h2 className="text-lg font-semibold">Antes de sair para a instalação</h2>
          </div>
          <ul className="mt-4 space-y-2 text-sm text-muted-foreground">
            <li>
              A partir da v2.2.4 o configurador não cria mais a conta local “Global”. Notebooks
              configurados por versões anteriores continuam com ela — a remoção, se desejada, é
              manual.
            </li>

            <li>
              Se o Windows bloquear o script, clique com o botão direito no arquivo .ps1 →
              Propriedades → marque <strong className="text-foreground">Desbloquear</strong>.
            </li>
            <li>
              Instale os aplicativos antes de rodar o item 4: o script localiza os executáveis,
              mas não instala nada.
            </li>
            <li>Reinicie o notebook ao final e confira o painel rodando por 10 minutos.</li>
          </ul>
        </div>

        <p className="mt-8 flex items-center gap-2 font-mono text-xs text-muted-foreground">
          <MonitorCog className="size-4" /> Windows 10 / 11 · PowerShell 5.1 · requer
          Administrador
        </p>
      </section>
    </main>
  );
}
