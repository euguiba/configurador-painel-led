import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowLeft, Download, Sparkles, Wrench } from "lucide-react";
import { ARQUIVO_SCRIPT, HISTORICO, VERSAO_ATUAL, formatarData } from "@/lib/versao";


export const Route = createFileRoute("/versoes")({
  head: () => ({
    meta: [
      { title: "Histórico de versões do Configurador | Global LED Experience" },
      {
        name: "description",
        content:
          "Todas as versões do Configurador de Notebook da Global LED: o que cada versão faz, o que mudou na atualização e o download do arquivo mais recente.",
      },
      { property: "og:title", content: "Histórico de versões do Configurador | Global LED Experience" },
      {
        property: "og:description",
        content:
          "Todas as versões do Configurador de Notebook da Global LED: o que cada versão faz e o que mudou em cada atualização.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: Versoes,
});

function Versoes() {
  return (
    <main className="min-h-screen">
      <div className="grid-lines">
        <section className="mx-auto max-w-4xl px-6 pt-16 pb-10">
          <Link to="/" className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground">
            <ArrowLeft className="size-4" /> Voltar ao tutorial
          </Link>
          <h1 className="mt-6 text-4xl font-bold leading-tight">
            Histórico de <span className="text-primary">versões</span>
          </h1>
          <p className="mt-4 max-w-2xl text-muted-foreground">
            O script verifica esta página sozinho toda vez que abre. Se existir uma versão mais nova
            que a do pendrive, ele avisa o técnico e oferece o download. Sempre substitua o arquivo
            do pendrive pela versão mais recente antes de sair para a instalação.
          </p>
          <div className="mt-6 flex flex-wrap gap-3">
            <a
              href={ARQUIVO_SCRIPT}
              download
              className="inline-flex items-center gap-2 rounded-lg bg-primary px-5 py-3 font-semibold text-primary-foreground transition hover:opacity-90"
            >
              <Download className="size-4" /> Baixar versão {VERSAO_ATUAL}
            </a>
          </div>
        </section>
      </div>

      <section className="mx-auto max-w-4xl px-6 pb-24">
        <ol className="space-y-6">
          {HISTORICO.map((v) => (
            <li key={v.numero} className="panel p-6">
              <div className="flex flex-wrap items-center gap-3">
                <span className="rounded-lg bg-primary/12 px-3 py-1 font-mono text-lg font-bold text-primary">
                  v{v.numero}
                </span>
                <span className="font-mono text-xs text-muted-foreground">{formatarData(v.data)}</span>
                {v.numero === VERSAO_ATUAL && (
                  <span className="inline-flex items-center gap-1 rounded-full border border-success/40 bg-success/10 px-2.5 py-0.5 font-mono text-[11px] uppercase tracking-wider text-success">
                    <Sparkles className="size-3" /> versão atual
                  </span>
                )}
              </div>
              <p className="mt-4 text-sm text-muted-foreground">{v.resumo}</p>
              <h2 className="mt-5 flex items-center gap-2 text-sm font-semibold">
                <Wrench className="size-4 text-primary" /> O que esta versão faz de diferente
              </h2>
              <ul className="mt-3 space-y-2">
                {v.novo.map((n) => (
                  <li key={n} className="flex gap-2 text-sm text-muted-foreground">
                    <span className="mt-2 size-1.5 shrink-0 rounded-full bg-primary" />
                    <span>{n}</span>
                  </li>
                ))}
              </ul>
            </li>
          ))}
        </ol>
      </section>
    </main>
  );
}
