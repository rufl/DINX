# Easy install da DINX

[Português (Brasil)](install.md) · [English](../install.md)

## Estado atual da alpha

A imagem atual da DINX é uma **ISO live de validação com um instalador de disco experimental**. O Calamares instala a partir do root filesystem da ISO sem exigir rede; cria o usuário, configura o dinit e o GRUB e remove os pacotes exclusivos da sessão live. Este guia cobre os caminhos seguros de download, verificação, boot e instalação experimental. Ele não promete suporte de hardware de produção, atualizações, rollback ou preservação de dados.
O projeto está atualmente na **P1 — alpha pública 0.1**. A última validação P0 aprovada é a [execução 38739313464](https://github.com/rufl/DINX/actions/runs/38739313464); ela inclui o pacote BC250 Control Center v1.21.1 fixado e sua integração de sessão na DINX.

O KDE Partition Manager também está disponível como particionador gráfico independente. Use-o somente para inspecionar ou preparar um disco antes de abrir o Calamares e confirme o dispositivo nas duas aplicações.

Não use a ISO em uma máquina com dados que não possam ser restaurados. A sessão live e o instalador são software alpha.

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

1. Abra o [workflow da ISO P0](https://github.com/rufl/DINX/actions/workflows/p0-iso.yml).
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
repo=rufl/DINX
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
O Noctalia inicia com animações, transparência dos painéis e transparência da janela de Settings desativadas. Isso são preferências do usuário, não bloqueios: altere-as depois em Settings do Noctalia. O Mango inicia com dois desktops virtuais; edite `~/.config/mango/config.conf` e altere `tag_num` se precisar de mais.

### BC250 Control Center

Depois de entrar no MangoWM, abra o **BC250 Control Center** pelo launcher ou dock do Noctalia. A DINX inicia `bc250-control-centerd` uma vez na sessão do usuário autenticado, portanto o daemon não exige unidade systemd nem serviço root dinit. Ele fornece telemetria da BC-250 e os controles upstream protegidos por polkit quando o hardware e as permissões estão disponíveis. No dinit, a persistência de serviços upstream é somente detecção; essa limitação não impede a GUI nem as leituras ao vivo.

## 5. Instalação persistente experimental

Após entrar no MangoWM:

1. Abra o launcher de aplicativos e escolha **Instalar DINX**.
2. Se a entrada não estiver disponível, execute `pkexec calamares` em um terminal.
3. Escolha o particionamento automático ou manual e confira o disco-alvo, o modo de firmware e os pontos de montagem antes de continuar.
4. Para preparação avançada, feche o Calamares, abra o **KDE Partition Manager**, faça e aplique as alterações necessárias, feche-o e abra o Calamares novamente.
5. Mantenha a ISO/USB conectado até o instalador terminar. O primeiro perfil suporta ext4 e btrfs; o instalador copia o root filesystem sem rede.

O Calamares e o KDE Partition Manager podem apagar ou formatar dados. A confirmação final não protege contra a seleção do disco errado. Faça backup e confira modelo, tamanho e informações de série do dispositivo-alvo.
### Primeiro boot e TTY de recuperação

O contrato de instalação do CI inicializa o root filesystem copiado em um disco BIOS
descartável e habilita `getty@tty2` e `getty@tty3` para recuperação. Em uma instalação
real, pressione `Ctrl+Alt+F2` ou `Ctrl+Alt+F3` no greeter para abrir uma TTY e faça
login com o usuário criado durante a instalação. Comandos úteis:

```bash
dinitctl status greetd
dinitctl restart greetd
```

Se a sessão gráfica não estiver disponível, use o fallback Wayland independente:

```bash
DINX_TERMINAL_FALLBACK=1 dinx-terminal
```

`Super+Enter` também inicia o `foot` diretamente na sessão Mango. `$TERMINAL` aponta
para `dinx-terminal`, que prefere o NOCTTY e usa `foot` quando o NOCTTY não está
instalado.


## 6. O que esta alpha pode e não pode fazer

### Comprovado pelo smoke test atual

- caminho de boot x86_64 em QEMU;
- renderização do ReGreet;
- login gráfico na sessão MangoWM;
- inicialização do Noctalia;
- presença dos payloads esperados de dinit, rede, PipeWire e portais na ISO;
- presença da configuração de instalação offline do Calamares e do KDE Partition Manager independente.
- contrato de instalação do rootfs persistente em disco BIOS descartável, primeiro boot dinit e captura da TTY de recuperação no CI.

### Ainda não suportado para produção

- o instalador persistente é experimental. O CI qualifica um disco BIOS efêmero; hardware UEFI/BIOS real ainda exige relatório de hardware;
- não existe procedimento de atualização ou rollback;
- a imagem atual não é um release de desktop ou jogos para produção;
- não particione nem formate um disco interno baseando-se apenas neste guia.

Para instalação de produção, aguarde um release com chave de assinatura do repositório
pacman, suporte de hardware, recuperação e atualização. O caminho selecionado e os gates
restantes estão registrados na [decisão de arquitetura](architecture.md).

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
