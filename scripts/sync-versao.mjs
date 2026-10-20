/**
 * Sincroniza a versao de public/downloads/versao.json (fonte unica de verdade)
 * com o script PowerShell, o LEIA-ME do pendrive e o kit ZIP.
 * Roda automaticamente antes de dev/build.
 */
import { readFileSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const JSON_PATH = "public/downloads/versao.json";
const PS1_PATH = "public/downloads/ConfiguradorPainelLED.ps1";
const README_PATH = "public/downloads/LEIA-ME.txt";

const dados = JSON.parse(readFileSync(JSON_PATH, "utf8"));
const historico = dados.historico ?? [];
const atual = historico[0] ?? { numero: dados.versao, data: dados.data, novo: dados.novidades ?? [] };

// Mantem os campos de topo (lidos pelo proprio script no notebook) alinhados ao historico.
const atualizado = {
  ...dados,
  versao: atual.numero,
  data: atual.data,
  novidades: atual.novo,
};
writeFileSync(JSON_PATH, `${JSON.stringify(atualizado, null, 2)}\n`, "utf8");

function sync(path, regex, substituto) {
  const raw = readFileSync(path, "utf8");
  const novo = raw.replace(regex, substituto);
  if (novo !== raw) {
    writeFileSync(path, novo, "utf8");
    console.log(`[versao] ${path} atualizado para ${atual.numero}`);
  }
}

sync(PS1_PATH, /\$script:Versao(\s*)= '[^']*'/, `$script:Versao$1= '${atual.numero}'`);
sync(README_PATH, /^ Versao .*$/m, ` Versao ${atual.numero}`);

console.log(`[versao] versao atual: ${atual.numero} (${atual.data})`);

// Gera o kit ZIP apos sincronizar a versao.
await new Promise((resolve, reject) => {
  const child = spawn("node", [path.join(__dirname, "zip-kit.mjs")], {
    stdio: "inherit",
    shell: false,
  });
  child.on("close", (code) => {
    if (code === 0) resolve();
    else reject(new Error(`zip-kit saiu com codigo ${code}`));
  });
  child.on("error", reject);
});
