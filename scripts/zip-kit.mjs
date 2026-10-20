/**
 * Gera o kit ZIP do pendrive com a estrutura correta para extrair na raiz.
 * Roda automaticamente apos a sincronizacao de versao (predev/prebuild).
 */
import { createWriteStream } from "node:fs";
import { readFile, readdir, stat } from "node:fs/promises";
import path from "node:path";
import { Readable } from "node:stream";
import { deflateRaw } from "node:zlib";

const JSON_PATH = "public/downloads/versao.json";
const OUT_DIR = "public/downloads";

const raiz = [
  "INICIAR.cmd",
  "ConfiguradorPainelLED.ps1",
  "Wallpaper.jpg",
  "LEIA-ME.txt",
];

const pastasVazias = ["Instaladores", "Backups"];
const pastasComArquivos = ["_sistema"];

async function* walk(dir, base = "") {
  const entries = await readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const relative = base ? `${base}/${entry.name}` : entry.name;
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      yield* walk(full, relative);
    } else if (entry.isFile()) {
      const s = await stat(full);
      yield { name: relative, data: await readFile(full), size: s.size };
    }
  }
}

function crc32(buf) {
  let c = ~0;
  const table = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let x = n;
    for (let k = 0; k < 8; k++) x = x & 1 ? 0xedb88320 ^ (x >>> 1) : x >>> 1;
    table[n] = x;
  }
  for (let i = 0; i < buf.length; i++) c = table[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (~c) >>> 0;
}

function dateToDos(date) {
  return (
    ((date.getSeconds() >> 1) | (date.getMinutes() << 5) | (date.getHours() << 11)) |
    ((date.getDate() | (date.getMonth() + 1) << 5 | (date.getFullYear() - 1980) << 9) << 16)
  );
}

async function buildZip(files, outPath) {
  const localHeaders = [];
  const centralHeaders = [];
  let offset = 0;

  for (const file of files) {
    const nameBuf = Buffer.from(file.name, "utf8");
    const compressed = await new Promise((resolve, reject) => {
      deflateRaw(file.data, { level: 9 }, (err, buf) => {
        if (err) reject(err);
        else resolve(buf);
      });
    });

    const crc = crc32(file.data);
    const size = file.data.length;
    const csize = compressed.length;
    const time = dateToDos(new Date());

    const local = Buffer.alloc(30 + nameBuf.length);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4); // version needed
    local.writeUInt16LE(0x0008, 6); // flags: deflate
    local.writeUInt16LE(8, 8); // method: deflate
    local.writeUInt16LE(time & 0xffff, 10);
    local.writeUInt16LE(time >>> 16, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(csize, 18);
    local.writeUInt32LE(size, 22);
    local.writeUInt16LE(nameBuf.length, 26);
    local.writeUInt16LE(0, 28);
    nameBuf.copy(local, 30);

    localHeaders.push(local, compressed);

    const central = Buffer.alloc(46 + nameBuf.length);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4); // version made by
    central.writeUInt16LE(20, 6); // version needed
    central.writeUInt16LE(0x0008, 8);
    central.writeUInt16LE(8, 10);
    central.writeUInt16LE(time & 0xffff, 12);
    central.writeUInt16LE(time >>> 16, 14);
    central.writeUInt32LE(crc, 16);
    central.writeUInt32LE(csize, 20);
    central.writeUInt32LE(size, 24);
    central.writeUInt16LE(nameBuf.length, 28);
    central.writeUInt16LE(0, 30);
    central.writeUInt16LE(0, 32);
    central.writeUInt16LE(0, 34);
    central.writeUInt16LE(0, 36);
    central.writeUInt32LE(0, 38);
    central.writeUInt32LE(offset, 42);
    nameBuf.copy(central, 46);
    centralHeaders.push(central);

    offset += local.length + csize;
  }

  const centralOffset = offset;
  const centralBlob = Buffer.concat(centralHeaders);
  const endOfCentral = Buffer.alloc(22);
  endOfCentral.writeUInt32LE(0x06054b50, 0);
  endOfCentral.writeUInt16LE(0, 4);
  endOfCentral.writeUInt16LE(0, 6);
  endOfCentral.writeUInt16LE(files.length, 8);
  endOfCentral.writeUInt16LE(files.length, 10);
  endOfCentral.writeUInt32LE(centralBlob.length, 12);
  endOfCentral.writeUInt32LE(centralOffset, 16);
  endOfCentral.writeUInt16LE(0, 20);

  const out = createWriteStream(outPath);
  const stream = Readable.from([
    ...localHeaders,
    centralBlob,
    endOfCentral,
  ]);
  await new Promise((resolve, reject) => {
    stream.pipe(out);
    out.on("finish", resolve);
    out.on("error", reject);
  });
}

async function main() {
  const dados = JSON.parse(await readFile(JSON_PATH, "utf8"));
  const versao = dados.versao;
  const outName = `ConfiguradorPainelLED-Kit-v${versao}.zip`;
  const outPath = path.join(OUT_DIR, outName);

  const files = [];

  for (const nome of raiz) {
    const p = path.join(OUT_DIR, nome);
    const s = await stat(p);
    files.push({ name: nome, data: await readFile(p), size: s.size });
  }

  for (const nome of pastasVazias) {
    files.push({
      name: `${nome}/COLOQUE_OS_ARQUIVOS_AQUI.txt`,
      data: Buffer.from(`Pasta reservada para: ${nome}\n\nEsta pasta fica na raiz do pendrive.\n`),
      size: 0,
    });
  }

  for (const nome of pastasComArquivos) {
    const p = path.join(OUT_DIR, nome);
    for await (const file of walk(p, nome)) {
      files.push(file);
    }
  }

  await buildZip(files, outPath);
  console.log(`[zip-kit] ${outName} gerado com ${files.length} entradas`);
}

main().catch((err) => {
  console.error("[zip-kit] erro:", err);
  process.exit(1);
});
