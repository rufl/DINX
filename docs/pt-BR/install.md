# Instalação fácil da DINX

[Português (Brasil)](install.md) · [English](../install.md)

## Estado atual da alpha

A imagem atual da DINX é uma **ISO live de validação com um instalador de disco experimental**. O Calamares instala a partir do root filesystem da ISO sem exigir rede; cria o usuário, configura o dinit e o GRUB e remove os pacotes exclusivos da sessão live. Este guia cobre os caminhos seguros de download, verificação, boot e instalação experimental. Ele não promete suporte de hardware de produção, atualizações da ISO instalada, rollback do filesystem ou preservação de dados.
O projeto está atualmente na **P5 — Beta de jogos**. O workflow de validação com tag [execução 39924316082](https://github.com/rufl/DINX/actions/runs/39924316082), no commit `0d1698a462d5d5486871a7aa17e9b97352ee9404`, passou o build da ISO, boot e payload gráfico no QEMU, smokes de layouts suportados e de instalação persistente/recuperação do Calamares, verificação dos metadados de build, atestação de procedência e publicação do release. O prerelease público é a [v0.1.0-alpha.9](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.9), com uma ISO direta, checksum SHA-512 correspondente e repositório DINX estável assinado. A P4 DinitUI está qualificada para o gate alpha; a P5 ainda tem limites de DRM real, Steam/jogo autenticados, controle/áudio e hardware físico.

A validação pós-release da `main`, [execução 39934458077](https://github.com/rufl/DINX/actions/runs/39934458077) no commit `eb9a0c143c06d9c1939f9d88684d164d8e2384fb`, também concluiu em 52m02s com sucesso nos checks de build, boot, payload gráfico, instalação persistente/TTY de recuperação em BIOS e UEFI, atestação e upload. Ela não publicou outro release; a Alpha 9 continua sendo a imagem publicada atual.

O Pori é a ferramenta gráfica de armazenamento dinit. Use-o para inspecionar discos e criar serviços persistentes de montagem em `/etc/dinit.d`; use o File Roller para abrir, criar e extrair arquivos compactados, o GParted para editar partições fora do instalador e o Calamares para a transação final de particionamento e instalação.

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

### Release alpha com tag

1. Abra os [releases da DINX](https://github.com/rufl/DINX/releases).
2. Selecione o pre-release mais recente.
3. Baixe `dinx-<versão>-x86_64.iso` e seu `.iso.sha512` correspondente. Releases antigos sem ISO direta exigem todos os arquivos `dinx-<versão>-x86_64.iso.part-*` e `.iso.parts.json`.
4. Para uma ISO dividida, concatene as partes em ordem lexicográfica:

   ```bash
   cat dinx-<versão>-x86_64.iso.part-* > dinx-<versão>-x86_64.iso
   ```

5. Continue com a verificação de checksum abaixo.

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
- **Sessão:** `Labwc (DINX)`

A senha é intencionalmente pública e descartável. Nunca a reutilize em outro sistema ou rede.

Após o login, o estado gráfico testado mostra labwc com a tela de boas-vindas do Noctalia. Rede, áudio, aceleração de GPU, suspensão/retomada e TTY de recuperação continuam áreas dependentes de validação em hardware.
O Noctalia inicia com animações, transparência dos painéis e transparência da janela de Settings desativadas. Isso são preferências do usuário, não bloqueios: altere-as depois em Settings do Noctalia. O labwc inicia com dois workspaces; edite `~/.config/labwc/rc.xml` para overrides do usuário.
O Phyto é o manipulador padrão de diretórios e o gerenciador de arquivos. O File Roller fornece ações gráficas para abrir, criar e extrair arquivos compactados. O GParted edita partições fora do fluxo de instalação. O Pori é a interface de armazenamento para inspecionar discos e criar serviços persistentes de montagem do usuário; usa UDisks2 para descoberta e dinit para o ciclo de vida dos serviços. A ISO base inclui o wrapper DINX `dinx-wdisplays` para configuração interativa de displays Wayland; ao fechar, ele salva o layout atual como o perfil `DINX wdisplays` e recarrega o Shikane, que inicia com o labwc e reaplica perfis correspondentes. `Dome`, `Seafoam Settings` e `zls` são pacotes Seafoam opcionais assinados, não parte da ISO base. O Seafoam Settings agrupa os pontos documentados de configuração de display/sessão; o Nocted usa ZLS para projetos Zig quando instalado.

### BC250 Control Center

Depois de entrar no labwc, abra o **BC250 Control Center** pelo launcher ou dock do Noctalia. A DINX inicia `bc250-control-centerd` uma vez na sessão do usuário através do autostart do labwc, portanto o daemon não exige unidade systemd nem serviço root dinit. Ele fornece telemetria da BC-250 e os controles upstream protegidos por polkit quando o hardware e as permissões estão disponíveis. No dinit, a persistência de serviços upstream é somente detecção; essa limitação não impede a GUI nem as leituras ao vivo.

## 5. Instalação persistente experimental

Após entrar no labwc:

1. Abra o launcher de aplicativos e escolha **Instalar DINX**.
2. Se a entrada não estiver disponível, execute `pkexec calamares` em um terminal.
3. Escolha o particionamento automático ou manual e confira o disco-alvo, o modo de firmware e os pontos de montagem antes de continuar.
4. Para operações avançadas de armazenamento, abra o **Pori** pelo launcher do Noctalia. Ele descobre dispositivos de bloco pelo UDisks2 e persiste as montagens escolhidas pelo usuário como serviços dinit em `/etc/dinit.d`; use o **GParted** para editar partições fora do Calamares, o **File Roller** para trabalhar com arquivos compactados, o `dinx-wdisplays` para configurar saídas interativamente e persistir automaticamente o perfil Shikane.
5. Mantenha a ISO/USB conectado até o instalador terminar. O primeiro perfil suporta ext4 e btrfs; o instalador copia o root filesystem sem rede.

O Calamares e o GParted podem apagar, formatar ou redimensionar dados. As ações de montagem do Pori não formatam discos, mas confira o dispositivo, o filesystem e o destino de montagem antes de confirmar qualquer ação privilegiada. A confirmação final não protege contra a seleção do disco errado. Faça backup e confira modelo, tamanho e informações de série do dispositivo-alvo.
A qualificação do Calamares da Alpha 9 também cobre um layout GPT típico de Windows: uma ESP FAT32 existente contendo `EFI/Microsoft`, uma partição Windows NTFS e espaço para a raiz DINX criado depois dela. O smoke preserva a partição Windows e o caminho de boot da Microsoft enquanto grava fstab e dados GRUB da DINX tanto no resultado side-by-side quanto em um layout manual explícito. A ISO live e a instalação base usam o driver de kernel `ntfs3` para leitura e escrita NTFS; o `ntfs-3g` legado é opcional após a instalação para compatibilidade e ferramentas de reparo. O perfil inclui `os-prober`, habilita a detecção do Windows pelo GRUB e usa um diretório EFI separado para `DINX`. Uma ESP existente de pelo menos 64 MiB é aceita porque a DINX mantém `/boot` no root filesystem; uma ESP nova é recomendada com 1 GiB. Se a ESP existente for menor ou estiver cheia, crie uma nova ESP FAT32 no espaço livre pelo layout manual em vez de formatar a ESP da Microsoft. Não formate a ESP existente nem as partições Windows/MSR/Recovery. Inicialize a DINX no mesmo modo UEFI do Windows, desligue o Windows completamente, desabilite Fast Startup/hibernação, suspenda o BitLocker mantendo a chave de recuperação disponível e faça backup verificado antes de tentar redimensionar.
### Primeiro boot e TTY de recuperação

O contrato de instalação do CI inicializa o root filesystem copiado em discos BIOS e UEFI descartáveis e habilita `getty@tty2` e `getty@tty3` para recuperação. Esses são smokes em discos QEMU, não uma qualificação de hardware físico. Em uma instalação real, pressione `Ctrl+Alt+F2` ou `Ctrl+Alt+F3` no greeter para abrir uma TTY e faça login com o usuário criado durante a instalação. Comandos úteis:

```bash
dinitctl status greetd
dinitctl restart greetd
```

Se a sessão gráfica não estiver disponível, use o fallback Wayland independente:

```bash
DINX_TERMINAL_FALLBACK=1 dinx-terminal
```

`Super+Enter` inicia `dinx-terminal` na sessão labwc. `$TERMINAL` aponta
para `dinx-terminal`, que prefere o NOCTTY e usa `foot` quando o NOCTTY não está
instalado.
Para registrar o estado sem alterar o sistema, execute:

```bash
dinx-doctor
```

O relatório usa o schema `dinx-doctor/v1` e marca capacidades ausentes como `missing` ou `unknown`. Para incluir a lista somente leitura dos serviços do dinit de usuário, use `DINX_DOCTOR_QUERY_DINIT=1 dinx-doctor`. Não use o relatório como prova de compatibilidade de hardware: brilho físico, suspensão, GPU, áudio, NTFS compartilhado e montagem de volumes ainda exigem teste no equipamento.



## 6. O que esta alpha pode e não pode fazer

### Comprovado pelo smoke test atual

- caminho de boot x86_64 em QEMU;
- renderização do ReGreet;
- login gráfico na sessão labwc;
- inicialização do Noctalia;
- presença dos payloads esperados de dinit, rede, PipeWire e portais na ISO;
- smoke transacional de layout GPT Windows side-by-side e manual: a ESP FAT32/caminho Microsoft e a partição NTFS existentes permanecem intactos enquanto a raiz DINX, o fstab e os dados GRUB são adicionados;
- contrato de instalação do rootfs persistente em discos BIOS e UEFI descartáveis, primeiro boot dinit, Pori, Phyto, caminho de armazenamento `ntfs3` e captura da TTY de recuperação no CI.

### Ainda não suportado para produção

- o instalador persistente é experimental. O CI qualifica discos BIOS e UEFI efêmeros; hardware UEFI/BIOS real ainda exige relatório de hardware e revisão do risco de apagar o dispositivo.
- não existe procedimento de atualização da ISO instalada ou rollback do filesystem;
- a imagem atual não é um release de desktop ou jogos para produção;
- não particione nem formate um disco interno baseando-se apenas neste guia.

Para instalação de produção, aguarde um release com suporte de hardware físico,
recuperação do filesystem e procedimento de atualização da ISO instalada. Releases alpha
publicados podem fornecer um repositório pacman DINX assinado e um caminho de transação
de pacotes, mas isso não torna o instalador ou a recuperação do filesystem prontos para
produção. O caminho selecionado e os gates restantes estão registrados na [decisão de arquitetura](architecture.md).

## Solução de problemas

### O USB não aparece

Confirme que o checksum passou, que a imagem foi gravada no dispositivo inteiro, que o firmware está em modo UEFI e que o USB aparece em `lsblk`/`diskutil`. Tente outra porta ou outro pendrive.

### A tela fica vazia

O fallback de renderização por software foi projetado para o caminho QEMU headless. O suporte gráfico em hardware ainda não está totalmente qualificado. Registre o modelo da GPU, o modo do firmware e o comportamento do kernel/guest antes de abrir um relatório.

### Gráficos, drivers e mídia

A DINX fornece Mesa/RADV, diagnóstico Vulkan, FFmpeg e VLC para o caminho de
mídia open source suportado. Se a aceleração de hardware ou um driver
proprietário de GPU faltar, abra **DINXPanel → GPU drivers**, execute a detecção,
revise o plano fixo de pacotes Artix e reinicie quando for informada uma mudança
de kernel ou driver. A DINX não instala drivers proprietários silenciosamente
nem afirma que hardware não suportado está funcionando. Anexe a saída de
`dinx-alpha7-hardware-report` ao relatar vídeo vazio, fallback de renderização ou
falha ao iniciar um jogo.

A DINX também fornece o backend SANE `scanimage` para acesso a scanners,
`fwupdmgr` para descoberta explícita de metadados e atualizações de firmware,
Flatpak para fontes de aplicativos escolhidas pelo usuário e o KolourPaint como
editor de imagens Qt simples. O Swayimg continua sendo o visualizador padrão;
o KolourPaint fica disponível no launcher e não substitui esse default de
visualização.

O Flatpak é instalado sem aplicativos Flatpak pré-instalados. Adicionar um
remote e instalar um aplicativo continuam sendo ações explícitas do usuário; a
DINX não instala remotes ou aplicativos silenciosamente.

Para impressão opcional após a instalação, abra **DINXPanel → Pacotes opcionais
→ Instalar CUPS**. A ação baixa o pacote assinado `cups-dinit` do repositório
Artix configurado; a dependência baixa o CUPS e o pacote fornece o serviço
`cupsd` do dinit. Use o DinitUI para habilitar ou iniciar `cupsd` quando
precisar imprimir. O CUPS fica intencionalmente fora da ISO offline.

### O login falha

Selecione o usuário `dinx`, a sessão `Labwc (DINX)` e digite exatamente a senha descartável `dinx`. Se o greeter continuar falhando, guarde o commit do workflow e os detalhes do hardware; não tente credenciais aleatórias.

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
