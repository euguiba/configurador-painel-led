import versaoJson from "../../public/downloads/versao.json";

export type VersaoHistorico = {
  numero: string;
  data: string;
  resumo: string;
  novo: string[];
};

/** Histórico completo, do mais novo para o mais antigo (fonte: versao.json). */
export const HISTORICO = versaoJson.historico as VersaoHistorico[];

/** A versão atual é sempre a primeira do histórico — nada é escrito à mão nas páginas. */
export const VERSAO_ATUAL = (HISTORICO[0]?.numero ?? versaoJson.versao) as string;
export const DATA_VERSAO = (HISTORICO[0]?.data ?? versaoJson.data) as string;
export const ARQUIVO_SCRIPT = versaoJson.arquivo as string;
export const ARQUIVO_KIT = `/downloads/ConfiguradorPainelLED-Kit-v${VERSAO_ATUAL}.zip` as string;

/** 2026-08-06 -> 06/08/2026 */
export function formatarData(iso: string): string {
  const partes = iso.split("-");
  if (partes.length !== 3) return iso;
  return `${partes[2]}/${partes[1]}/${partes[0]}`;
}
