# Easy install da DINX

[Português (Brasil)](install.md) · [English](../install.md)

## Estado atual da alpha

A imagem atual da DINX é uma **ISO live de validação**, não um instalador de disco suportado. Este guia cobre o caminho seguro para baixar, verificar, gravar e inicializar a sessão live. Ele não promete instalação persistente, atualizações ou preservação de dados.

Não use a ISO em uma máquina com dados que não possam ser restaurados. A sessão live é descartável e as alterações são perdidas ao reiniciar.

## Requisitos

- computador ou máquina virtual x86_64;
- firmware UEFI recomendado;
- pendrive de pelo menos 4 GB; a gravação apaga o dispositivo inteiro;
- 4 GB de RAM recomendados para teste em hardware. O smoke test de CI usa 2 GB, mas isso não é um mínimo de hardware suportado;
- um segundo dispositivo ou sistema existente para baixar e verificar a imagem;
- backup de todos os discos que possam ser selecionados por engano.

A alpha atual não possui bootloader assinado, caminho Secure Boot suportado nem matriz final de compatibilidade de GPU/hardware. Uma máquina pode inicializar e ainda ter gráficos, Wi-Fi, áudio ou suspensão não suportados.

## 1. Obter o artefato ISO

Ainda não existe um download estável de release. O artefato do workflow público fica retido por sete dias e é substituído por execuções posteriores.

### Navegador

1. Abra o [workflow da ISO P0](https://github.com/rufl/dinx-alpha/actions/workflows/p0-iso.yml).
2. Abra a execução mais recente com marca verde de sucesso.
3. Em **Artifacts**, baixe `dinx-foundation-iso-<commit>`.
4. Extraia o arquivo baixado em um diretório novo.
5. Continue usando a `.iso` e o `.iso.sha512` correspondente no diretório extraído.

### GitHub CLI

Instale e autentique o GitHub CLI se ele ainda não estiver disponível:

```bash
gh auth login
```

Baixe o artefato da execução bem-sucedida mais recente:

```bash
repo=rufl/dinx-alpha
run_id=$(gh run list \
  --repo "$repo" \
  --workflow p0-iso.yml \
  --status success \
  --limit 1 \
  --json databaseId \
  --jq '.[0].databaseId')
test -n "$run_id"
commit=$(gh run view "$run_id" --repo "$repo" --json headSha --jq '.headSha')
gh run download "$run_id" \
  --repo "$repo" \
  --name "dinx-foundation-iso-$commit" \
  --dir dinx-iso
```

Liste a imagem extraída:

```bash
find dinx-iso -type f \( -name '*.iso' -o -name '*.sha512' \) -print
```

## 2. Verificar a imagem antes de inicializar

Entre no diretório que contém a ISO e o checksum. O arquivo de checksum deve apontar para o mesmo nome de ISO:

```bash
cd dinx-iso/dinx
sha512sum -c artix-dinx-dinit-*-x86_64.iso.sha512
```

Resultado esperado:

```text
artix-dinx-dinit-<data>-x86_64.iso: OK
```

Se a verificação falhar, pare. Apague o download incompleto e baixe o artefato novamente. Nunca grave uma imagem com checksum ausente ou inválido.

O checksum autentica os bytes baixados contra a saída do workflow; não prova que as entradas do workflow público são seguras para produção. Leia o commit, o log do workflow e as limitações documentadas antes de testar hardware.

## 3. Gravar um pendrive inicializável

O destino deve ser o **dispositivo USB inteiro**, por exemplo `/dev/sdb`, não uma partição como `/dev/sdb1`. Selecionar o dispositivo errado destrói os dados dele.

### Linux

Identifique o USB pelo modelo, tamanho e transporte. Desmonte as partições existentes e grave a ISO verificada:

```bash
lsblk -p -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS
sudo umount /dev/sdX1   # substitua pela(s) partição(ões) montada(s) do USB
sudo dd if=artix-dinx-dinit-<data>-x86_64.iso \
  of=/dev/sdX \
  bs=4M status=progress conv=fsync
sync
```

Substitua os dois placeholders somente depois de conferir o `lsblk` novamente. Nunca use um disco interno como `of=`.

### macOS

Encontre o disco USB, desmonte-o sem ejetá-lo, grave no dispositivo raw e ejete-o:

```bash
diskutil list
diskutil unmountDisk /dev/diskN
sudo dd if=artix-dinx-dinit-<data>-x86_64.iso \
  of=/dev/rdiskN \
  bs=4m
sync
diskutil eject /dev/diskN
```

Use o `rdiskN` correspondente ao USB, nunca o disco interno.

### Windows

Use um gravador confiável como o Rufus. Selecione a ISO verificada e o pendrive correto, escolha GPT/UEFI quando solicitado e use o modo raw/DD se o gravador perguntar. Confirme cada aviso de apagamento somente depois de conferir o tamanho e o modelo do dispositivo.

## 4. Inicializar a sessão live

1. Insira o pendrive.
2. Reinicie e abra o menu de boot (`F12`, `F11`, `Esc` ou a tecla específica do fabricante).
3. Selecione a entrada UEFI do USB.
4. Se o firmware recusar a imagem, desative Secure Boot para este teste; a alpha atual não fornece um caminho Secure Boot assinado.
5. Aguarde o greeter da DINX.

O login live testado é:

- **Usuário:** `dinx`
- **Senha:** `dinx`
- **Sessão:** `MangoWM (DINX)`

A senha é intencionalmente pública e descartável. Nunca a reutilize em outro sistema ou rede.

Após o login, o estado gráfico testado mostra MangoWM com a tela de boas-vindas do Noctalia. Rede, áudio, aceleração de GPU, suspensão/retomada e TTY de recuperação continuam áreas dependentes de validação em hardware.

## 5. O que esta alpha pode e não pode fazer

### Comprovado pelo smoke test atual

- caminho de boot x86_64 em QEMU;
- renderização do ReGreet;
- login gráfico na sessão MangoWM;
- inicialização do Noctalia;
- presença dos payloads esperados de dinit, rede, PipeWire e portais na ISO.

### Instalação persistente ainda não suportada

- Esta imagem não possui instalador de disco suportado.
- Não há persistência após reiniciar.
- Não existe procedimento de atualização ou rollback.
- A imagem atual não é um release de desktop ou jogos para produção.
- Não particione nem formate um disco interno baseando-se apenas neste guia.

Para instalação persistente, aguarde um caminho de instalação documentado e um release com assinatura de pacotes, suporte de hardware, recuperação e atualização. O item aberto está no [roadmap](roadmap.md).

## Solução de problemas

### O USB não aparece

Confirme que o checksum passou, que a imagem foi gravada no dispositivo inteiro, que o firmware está em modo UEFI e que o USB aparece em `lsblk`/`diskutil`. Tente outra porta ou outro pendrive.

### A tela fica vazia

O fallback de renderização por software foi projetado para o caminho QEMU headless. O suporte gráfico em hardware ainda não está totalmente qualificado. Registre o modelo da GPU, o modo do firmware e o comportamento do kernel/guest antes de abrir um relatório.

### O login falha

Selecione o usuário `dinx`, a sessão `MangoWM (DINX)` e digite exatamente a senha descartável `dinx`. Se o greeter continuar falhando, guarde o commit do workflow e os detalhes do hardware; não tente credenciais aleatórias.

### O checksum falha

Não inicialize nem grave o arquivo. Remova o artefato parcial e baixe novamente a ISO e o `.sha512` da mesma execução do workflow.

## Relatar resultados de hardware

Inclua estes dados em uma issue ou relatório de hardware:

```bash
uname -a
lspci -nnk
lsusb
```

Inclua também o commit do workflow DINX, o modo do firmware (UEFI/legacy), GPU, hardware de Wi-Fi/áudio, se o checksum passou e a etapa exata da falha. Remova números de série, nomes de usuário, endereços de rede e logs privados antes de publicar.
