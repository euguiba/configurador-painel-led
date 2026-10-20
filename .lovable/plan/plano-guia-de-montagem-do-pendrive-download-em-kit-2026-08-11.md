# Plano: Guia de montagem do pendrive + download em kit

## Contexto
O usuário está com dificuldade para montar o pendrive: não sabe quais arquivos baixar, como organizar a estrutura de pastas e como usar com o Ventoy. O notebook de destino está na tela inicial de configuração do Windows 11 (OOBE).

## Objetivo
Deixar o site com um passo a passo visual e um download único (kit ZIP) que já contenha a estrutura correta do pendrive, eliminando a dúvida sobre "onde colocar cada arquivo".

## Entregáveis

1. **Kit ZIP pronto para extrair na raiz do pendrive**
   - Criar `public/downloads/ConfiguradorPainelLED-Kit-v{VERSAO}.zip` contendo:
     - `Iniciar.bat`
     - `ConfiguradorPainelLED.ps1`
     - `autorun.inf`
     - `autounattend.xml`
     - `Wallpaper.jpg`
     - `LEIA-ME.txt`
     - `Instaladores/` (pasta vazia com arquivo `.keep` ou `COLOQUE_OS_INSTALADORES_AQUI.txt`)
     - `Backups/` (pasta vazia com `.keep`)
     - `VTOYEFI/` com `autorun.inf`, `AbrirConfigurador.bat` e `Configurador.ico`
   - O ZIP deve ser gerado automaticamente por um script de build (`scripts/zip-kit.mjs`) para não esquecer de atualizar.

2. **Nova seção no site: "Como montar o pendrive passo a passo"**
   - Passo 1: baixar o kit ZIP.
   - Passo 2: formatar o pendrive em FAT32/exFAT.
   - Passo 3: extrair o ZIP na raiz do pendrive.
   - Passo 4: copiar os instaladores (AnyDesk, LedVision, NovaLCT, MCPR) para `Instaladores/`.
   - Passo 5: usar no notebook novo (OOBE) ou no desktop.
   - Incluir ilustração da estrutura de pastas final.

3. **Guia separado para o cenário OOBE**
   - Destacar que o `autounattend.xml` só funciona na tela inicial do Windows 11 (OOBE).
   - Instruir: ligar o notebook sem internet, esperar a primeira tela do OOBE, plugar o pendrive e esperar o Windows ler o arquivo.
   - Esclarecer que, depois do OOBE, o `Iniciar.bat` assume.

4. **Guia separado para o modo Ventoy**
   - Explicar o que é o Ventoy e por que usar (partição CD-ROM = AutoPlay mais visível).
   - Passo a passo: instalar o Ventoy no pendrive, extrair o kit na partição grande, copiar a pasta `VTOYEFI` para a partição CD.
   - Destacar que sem Ventoy o pendrive também funciona, mas exige abrir o `Iniciar.bat` manualmente.

5. **Botão de download principal unificado**
   - Trocar a grade de botões individuais por um botão grande "Baixar kit completo do pendrive".
   - Manter um link secundário "Baixar arquivos separados" para quem já sabe o que faz.

6. **Atualização automática do ZIP na versão**
   - O `scripts/sync-versao.mjs` deve também gerar/atualizar o ZIP do kit.
   - O nome do arquivo no site deve refletir a versão atual (`ConfiguradorPainelLED-Kit-v2.8.2.zip`).

## Resultado esperado
O técnico em campo baixa um arquivo só, extrai no pendrive, coloca os instaladores na pasta certa e já pode usar — sem precisar entender a estrutura manualmente. O site explica visualmente tanto o uso normal quanto o modo Ventoy e o pulo do OOBE.
