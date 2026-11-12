# Fundação da ISO DINX

[Português (Brasil)](README.pt-BR.md) · [English](README.md)

Este diretório contém o primeiro perfil Artix `artools` da DINX e os pontos de entrada locais do build.

Para o caminho voltado ao usuário de download, verificação e boot, consulte o [guia de instalação fácil](../../docs/pt-BR/install.md).

## Toolchain

O perfil usa o fluxo `buildiso` do Artix, não o `mkarchiso` genérico. O builder deve fornecer:

- `pacman`;
- `artools` atual do Artix com `buildiso` e sua dependência `yq`;
- `xorriso`, `grub-mkimage`, `mksquashfs` e `mkinitcpio`;
- suporte a dispositivos loop;
- privilégios root para operações de chroot e mount.

A execução oficial do P0 usa `.github/workflows/p0-iso.yml` em um runner Ubuntu com container Artix privilegiado. Para execução local, instale as mesmas dependências e use um ambiente com suporte de mount/chroot.

Execute o probe de pré-requisitos a partir da raiz do repositório:

```bash
scripts/check-iso-host.sh
```

Construa o perfil de fundação:

```bash
scripts/build-iso.sh
```

Teste o boot de uma ISO já construída:

```bash
scripts/smoke-iso.sh dist/iso/<arquivo>.iso
```
Teste o contrato de instalação persistente em discos BIOS e UEFI descartáveis:

```bash
DINX_INSTALL_OUTPUT_DIR=dist/iso/dinx \
DINX_INSTALL_FIRMWARE=bios scripts/smoke-install.sh dist/iso/<arquivo>.iso
DINX_INSTALL_OUTPUT_DIR=dist/iso/dinx \
DINX_INSTALL_FIRMWARE=uefi scripts/smoke-install.sh dist/iso/<arquivo>.iso
```

O script extrai o rootfs da ISO, remove os pacotes exclusivos da sessão live, cria
discos ext4 temporários, gera initramfs e o caminho GRUB BIOS ou UEFI correspondente,
inicializa cada disco no QEMU e captura a transição para a TTY de recuperação. Ele
exige root ou `sudo` sem senha, loop devices, `grub-pc-bin`, `grub-efi-amd64-bin`,
OVMF, QEMU e ferramentas SquashFS. Os discos são apagados ao fim do smoke; isso não
substitui a qualificação em hardware.


A smoke de boot no QEMU captura a superfície VGA e usa OCR do Tesseract para exigir um marcador da área de trabalho Pearl/Aqueous/DINX, rejeitando Pearl Greeter, prompts de login e falhas visíveis do Dinit. Ela envia `Alt+F4` após a primeira captura para dispensar a configuração inicial do Pearl e verifica o quadro da área de trabalho em seguida. Smokes locais exigem `qemu-system-x86_64`, `socat`, `tesseract-ocr` e `tesseract-ocr-eng`:

O menu de boot mostra `Start DINX Linux` e, em sistemas UEFI, `Boot to the Firmware/BIOS`. DINX é a opção padrão e inicia após uma contagem regressiva visível de seis segundos. No BIOS legado não existe a opção de configuração do firmware UEFI. A qualificação completa do QEMU deixa o menu sem teclas injetadas para verificar a contagem.

```bash
DINX_QEMU_TIMEOUT=110 \
DINX_QEMU_SCREENSHOT=dist/iso/dinx/tela-grafica.ppm \
DINX_QEMU_SCREENSHOT_DELAY=60 \
DINX_QEMU_POST_SCREENSHOT=dist/iso/dinx/tela-sessao.ppm \
DINX_QEMU_POST_SCREENSHOT_DELAY=10 \
DINX_QEMU_POST_KEYS=alt-f4 \
scripts/smoke-iso.sh dist/iso/<arquivo>.iso
```

O smoke também verifica o quadro da sessão capturado. Se o quadro original não contiver texto legível por OCR, ele amplia o painel superior antes de verificar o marcador da área de trabalho. Sem `DINX_QEMU_SCREENSHOT`, salva o PPM verificado ao lado do log QEMU como `<iso>.qemu.log.session.ppm`; `DINX_QEMU_OCR_LANG` seleciona outro modelo de idioma Tesseract instalado.


Verifique o payload gráfico dentro da imagem SquashFS do root:

```bash
scripts/check-iso-content.sh dist/iso/<arquivo>.iso
```

`build-iso.sh` copia os dados do `artools` para uma árvore temporária privada e altera o helper initramfs copiado para acrescentar `vmwgfx` e `vboxvideo` à configuração usada dentro do bootfs, imediatamente antes de o Artix executar `mkinitcpio`; não modifica a instalação do host. `scripts/check_artix_initcpio_patch.sh` protege esse contrato do helper/configuração, e `check-iso-content.sh` exige `bsdtar` e verifica os dois módulos dentro do initramfs real da ISO. O smoke P0 VMware-SVGA exige que o desktop apareça.


Opções adicionais do `buildiso` são repassadas sem alteração. Por exemplo, para consultar as configurações sem executar o build:

```bash
scripts/build-iso.sh -q
```

O diretório de saída padrão é `dist/iso`; ele pode ser alterado com `DINX_ISO_OUTPUT`. O cache de chroots padrão é `/var/lib/artools/buildiso`; altere-o com `DINX_ISO_CHROOTS` quando o builder usar outro volume persistente.
## Meta de tamanho da ISO

O wrapper do build coloca `scripts/iso-tools/mksquashfs` no início do `PATH`
do builder. Ele força imagens SquashFS com xz, BCJ x86, blocos e dicionário de
1 MiB, os maiores valores suportados. O `mksquashfs` não expõe controle de nível
do xz, então mantém o padrão da ferramenta. O Artix mantém `linux-headers` até
gerar o initramfs; depois o wrapper remove transacionalmente `linux-headers` e
sua dependência de build `pahole` de cada rootfs preparado antes da compactação.
O check de conteúdo rejeita ambos os pacotes nos bancos finais. Fontes do kernel, caches de pacotes
pacman e logs de build também ficam fora da imagem. O root overlay recria
`/var/log/dinit` por tmpfiles antes de os serviços Dinit iniciarem, e o check da
ISO exige essa regra. O pacote `dinx-live-autologin`, exclusivo do livefs, fornece
unidades no-op `root-ro` e `early-root-rw.target` para seu overlay gravável; essas
substituições não entram no rootfs instalado pelo Calamares. O rootfs live inclui
`squashfs-tools` porque o módulo `unpackfs` do Calamares precisa de `unsquashfs`;
o contrato da instalação remove o pacote da raiz instalada. O builder mantém sua
própria cópia. O CI instala o wrapper em
`/usr/bin/mksquashfs` após preservar o binário real, pois o `buildiso` do Artix
pode invocar esse caminho absoluto. A poda de pacotes usa uma configuração
`pacman` mínima e isolada, pois includes absolutos do `/etc/pacman.conf`
preparado resolveriam no host do builder. A montagem falha se o Artix não gerar
um `/LiveOS/rootfs.img` não vazio; a inspeção pós-build verifica xz e blocos de
1 MiB nos dois superblocos SquashFS.
O orçamento P0 rejeita ISOs no limite ou acima de 2 GiB por asset do GitHub; a
Alpha 12 tem 1.836.830.720 bytes (310.652.928 bytes abaixo do limite).

## Perfil gráfico

`iso-profiles/dinx/profile.yaml` inclui Aqueous, Pearl, greetd e o pacote nativo `deetty`. Deetty é o único emulador de terminal nos rootfs da sessão live e do sistema instalado. O pacote `ghostty-vt-runtime` da ISO contém somente a biblioteca VT, os headers e a licença necessários ao Deetty, não o aplicativo de terminal Ghostty. O pacote Pearl fornece o Pearl Greeter; `deetty` instala os aplicativos Deetty e Dintor, incluindo arquivos desktop, ícones, especificações de linguagem e o estilo escuro do editor. O CI consome o archive versionado gerado a partir do commit exato e do contrato SHA-256 em `distro/packages/deetty/source.env`, do repositório `https://github.com/rufl/DEETTY.git`. O root overlay fornece `/etc/greetd/config.toml`, `/etc/pearl/greeter.json` e metadados de sessão oculta; Aqueous + Pearl é a única entrada de sessão do usuário.

O livefs adiciona o pacote dinit `dinx-live-autologin`, exclusivo da sessão live. Ele habilita o `initial_session` único do greetd para `dinx` com Aqueous + Pearl e fornece unidades no-op de remontagem da raiz, pois o overlay live já é gravável. Essas substituições ficam no `livefs`; o Calamares instala `rootfs.img`, que mantém as unidades genéricas de remontagem do Artix. O fallback do greetd chama `dinx-pearl-greeter-host`, aplica a mesma política gráfica da sessão live e escolhe o backend do libseat em runtime: `seatd` quando `/run/seatd.sock` existe e o usuário da sessão pertence ao grupo `seat`, `logind` (elogind) caso contrário — o elogind sob dinit registra a sessão do greetd, mas nunca a marca como ativa, o que antes deixava o Aqueous aguardando uma sessão DRM até o timeout. O override live do `greetd` depende do serviço `seatd` e o helper `dinx-live-autologin` concede a `dinx` e `pearl-greeter` a participação no grupo `seat`, com `PATH` explícito, antes do greetd iniciar. O override live mantém o atraso de recuperação de sete segundos do serviço greetd instalado após uma saída inesperada, excedendo a janela de cinco segundos de encerramento do grupo de processos do Pearl Greeter para que uma nova tentativa não dispute o lock `config-writer` do Aqueous.

O home `pearl-greeter` no passwd continua pertencendo ao root e somente leitura. Pearl valida esse home confiável antes de iniciar; por isso, `dinx-pearl-greeter-host` mantém `HOME` em `/var/empty/pearl-greeter` e coloca configuração, dados e estado XDG na árvore privada da conta em `/var/lib/pearl-greeter` (`.config`, `.local/share`, `.local/state`). Um patch da DINX corrige a sobrescrita upstream do caminho de estado para que o Aqueous use o namespace isolado `.local/state`. O hook do pacote e os tmpfiles de boot provisionam esses diretórios com modo 0700; o cache permanece em `/var/cache/pearl-greeter`.


`iso-profiles/dinx/feature-groups.json` registra os grupos foundation, desktop, gaming, hardware e opcional sem substituir o `profile.yaml` do Artix. O builder do CI assina cada pacote customizado e o banco temporário do repositório `dinx` com uma chave efêmera, verifica assinaturas e caminhos duplicados dos archives e registra o snapshot imutável dos pacotes em `build-metadata.txt`. Isso é qualificação do build; a chave do repositório pacman de produção e o canal de atualização do sistema instalado continuam sendo pré-requisitos separados do release.

A árvore de código configura a atualização semanal dos pins de origem toda
segunda-feira às 04:17 UTC. Ela abre um pull request revisado para 23 pins de
origem de pacotes customizados, incluindo o subset latino Noto atualizado
mensalmente; o commit privado do Deetty e os pins do ZLS/Zig 0.16 continuam
manuais. Após o merge, um workflow assinado separado publica os pacotes sob a
tag de GitHub Release `dinx-packages-latest`, sem montar uma ISO. Os workflows
estão configurados, mas ainda não foram confirmados verdes nem publicados.
`dinx-keyring` configura o repositório `[dinx]` com assinatura obrigatória e
`/etc/pacman.d/dinx-mirrorlist` editável; Shelly usa pacman para sincronizar e
atualizar pacotes. Consulte o [guia de release](../../docs/pt-BR/release.md)
para configurar o segredo de assinatura e validar/preparar manualmente a
confiança da chave.

Todos os pacotes DINX são gerados como archives binários `.pkg.tar.zst`
assinados. Um único pacote `deetty` contém os binários pré-compilados do
terminal Deetty e do editor Dintor; os AppImages upstream permanecem como
payloads pré-compilados dentro dos pacotes DINX. Builds locais e P0 restauram
archives verificados, com chave baseada na fonte, receita, ambiente do builder
e conjunto de dependências instaladas; cache miss recompila o pacote. Assim,
cache hit evita recompilação sem enfraquecer pins de fonte ou verificação de
assinatura.

A ISO inclui o ZLS para a integração LSP de Zig do Dintor. `clang`/`clangd` e
Vim são ferramentas de qualificação usadas somente no builder: o clangd
exercita o cliente LSP genérico contra um servidor real, enquanto o Vim
verifica a tela alternativa e o bracketed paste em uma TUI real. Nenhum dos
dois é distribuído na imagem de execução.

Antes da compressão SquashFS, o wrapper executa transações fail-closed `pacman -Rns` no rootfs e no livefs para estas raízes de pacotes excluídas quando instaladas: `breeze`, `breeze-cursors`, `dhcpcd`, `dhcpcd-dinit`, `ex-vi-compat`, `linux-headers`, `man-db`, `man-pages`, `pahole`, `plasma-integration`, `plasma-workspace`, `qogir-icon-theme`, `qqc2-breeze-style`, `texinfo`, `vim`, `vim-runtime` e `xdg-desktop-portal-kde`. `pahole` só é removido quando os headers do kernel estão presentes. Isso remove a dependência do seletor Artix `vi` sobre Vim e o cliente/adaptador de serviço `dhcpcd` sem uso; o NetworkManager usa seu cliente DHCP interno. Os pacotes de documentação ficam ausentes dos dois rootfs; `man-db` e `texinfo` permanecem somente no builder isolado para build/qualificação do Deetty. O Calamares instala o mesmo `rootfs.img`, portanto os pacotes também ficam ausentes do sistema instalado. `breeze-icons` é mantido porque Calamares → KParts → KIO → KIconThemes depende dele; o Papirus continua sendo o tema de ícones da área de trabalho. Dependências só são removidas quando nenhum pacote mantido precisa delas; conflitos abortam o build. O gate de conteúdo rejeita os registros dos pacotes excluídos e os executáveis `man`/`info`.

O perfil controla bridges visuais estáticas DINX: `/usr/share/dinx/theme/DINX.json` é a fonte das cores semânticas e ANSI; GTK e Qt consomem arquivos DINX versionados, e `DINX_COLOR_SCHEME` é o contrato de cor da sessão do usuário. `qt6ct`, `adw-gtk-theme` e `dinx-noto-latin` são instalados para esses consumidores, alinhados à tipografia GTK padrão do CachyOS. O pacote fornece Noto Sans 10 regular/negrito/itálico/negrito itálico e Noto Sans Mono 10, subsetados para latim, marcas combinantes, pontuação comum e moedas; ele substitui o pacote completo `noto-fonts`. O host do Pearl Greeter lê `/etc/pearl/greeter.json`, usa a bridge GTK DINX e força `Aqueous + Pearl (DINX)` com X11 e UWSM desativados; Aqueous/Pearl é o único contrato de sessão do usuário. `scripts/check_dinx_theme.sh` valida esse contrato antes do build da ISO.

O Pearl Greeter e a área de trabalho inicial usam fundos sólidos, sem imagem de wallpaper ou logo DINX; o Calamares mantém o wordmark completo no logo do produto e na tela de boas-vindas. O símbolo reduzido D com raio continua como arte-fonte em `design/brand/dinx-ray-mark.svg` e é usado pelo Calamares como ícone do produto. O GRUB usa o PNG separado do boot-mark em gradiente. Papirus é o único tema de ícones selecionado explicitamente para a área de trabalho e os lançadores; Qogir, o estilo Breeze e os cursores Breeze são excluídos. `breeze-icons` permanece somente como dependência transitiva de Calamares → KParts → KIO → KIconThemes, não como tema escolhido para a área de trabalho. Os ícones próprios dos aplicativos permanecem inalterados, e os recursos Adwaita continuam disponíveis para compatibilidade GTK.
Na primeira sessão Pearl, um wizard exibido uma vez permite ativar ou ocultar o dock, posicionar a barra em cima ou em baixo e escolher DINX claro/escuro ou Pearl Material claro/escuro; Pearl Material escuro fica pré-selecionado. O Pearl reserva a área de trabalho somente na borda escolhida para a barra; o dock fica na borda oposta. As escolhas são salvas em `~/.config/pearl/preferences.json`.
O D-ray em ASCII em `/usr/share/dinx/branding/dinx-ray-mark.txt` é gerado por densidade a partir do SVG original da DINX e funciona como logo em texto puro:
```sh
fastfetch --logo-type file --logo /usr/share/dinx/branding/dinx-ray-mark.txt
```
O [`fetch`](https://github.com/areofyl/fetch) de Areofyl também aceita o arquivo como logo personalizado:
```sh
mkdir -p ~/.config/fetch
cp /usr/share/dinx/branding/dinx-ray-mark.txt ~/.config/fetch/logo.txt
```
Adicione estas linhas a `~/.config/fetch/config` para usar o coral DINX:
```ini
logo_outer=38;2;244;81;91
logo_inner=38;2;244;81;91
```
Fastfetch e o `fetch` de Areofyl são opcionais e não fazem parte da ISO base.

O perfil inclui o instalador experimental Calamares e o GParted para particionamento gráfico independente. O Calamares copia o root filesystem da ISO sem rede, mantém o dinit como init instalado e remove os pacotes exclusivos da sessão live durante a instalação. A imagem base traz o driver de kernel `ntfs3` para leitura e escrita em NTFS e `os-prober` para descobrir o Windows; o `ntfs-3g` legado fica como pacote opcional pós-instalação no canal extra assinado. Layouts Windows existentes de ESP/NTFS são preservados pelo instalador e usam um diretório EFI DINX separado.

Pearl Greeter, Aqueous/Pearl e o instalador recebem defaults DINX pelo root overlay. O Pearl Greeter usa Adwaita conforme o JSON do greeter pertencente ao root; o Calamares usa os mesmos tokens de superfície/texto/primário/erro no stylesheet Qt. A DINX compila o Calamares 3.4.3 de um release upstream fixado por checksum, sem a dependência Artix `plasma-integration`. O repositório DINX assinado é priorizado antes do Artix durante a resolução do rootfs, e o gate da ISO verifica que o pacote DINX do Calamares foi selecionado. `breeze-icons` continua necessário por Calamares → KParts → KIO → KIconThemes; isso não instala a sessão Plasma, seu workspace nem o portal KDE. Pearl é o shell ativo do usuário. O host Aqueous dedicado executa somente o Pearl Greeter e não é exposto como fallback de sessão do usuário. Entradas de sessão não suportadas continuam ocultas e `Aqueous + Pearl (DINX)` é a sessão live. A sessão live expõe `Instalar DINX` por um launcher próprio. O root overlay substitui o `/usr/share/applications/calamares.desktop` do pacote por um tombstone `Hidden=true`, `NoDisplay=true`, sem nome Artix nem executável. O helper DINX inicia o Calamares via `pkexec`, preservando o runtime/display Wayland da sessão live e exibindo erros de inicialização/autorização em uma janela.
O caminho live usa `Aqueous + Pearl (DINX)` sem prompt de credenciais: um serviço dinit exclusivo da live prepara o greetd antes de iniciá-lo. O rootfs instalado mantém login manual e o Calamares mantém os dois flags de autologin desativados.
No livefs, uma regra do PolicyKit autoriza ações privilegiadas via Polkit sem senha, exclusivamente para a sessão local e ativa do usuário `dinx`. Ela cobre lançadores como DinitUI, Calamares, GParted, Pori e Shelly. A regra não entra em `rootfs.img`; o sistema instalado mantém sua política normal de autenticação. Isso concede deliberadamente acesso equivalente a root a quem usa a sessão live descartável.

Os defaults global e do esqueleto GTK 3/4 usam Adwaita; selecionar DINX no wizard aplica o tema GTK DINX. Depois que o D-Bus da sessão está pronto, o shell Pearl sincroniza a variante escura/clara salva em dconf, nas configurações GTK 3/4 do usuário e no Qt6ct. O modo escuro ativa a preferência escura do GTK e a paleta Qt DINX; o modo claro desativa a paleta Qt personalizada. A escolha inicial aplica-se imediatamente e é reaplicada a cada login; configurações de toolkit não relacionadas são preservadas. A aparência padrão do shell Pearl é Pearl Material escuro, e o wizard permite selecionar DINX ou Material em modo escuro ou claro. O launcher Aqueous não força `GTK_THEME`; define `QT_QPA_PLATFORMTHEME=qt6ct` e copia a configuração/paleta DINX do Qt6ct quando faltam na pasta home existente. O Aqueous inicia no layout livre `stacking`; `Alt+Shift+F` o seleciona a partir de outro layout e `Super+Shift+Space` alterna o modo flutuante da janela focada.
O wizard GTK4 aplica diretamente a paleta semântica DINX e atualiza a prévia ao selecionar uma opção clara ou escura.


O payload runtime é somente Wayland/XWayland: servidores, drivers legados de Xorg/XLibre e entradas de sessão do Plasma são omitidos. Xvfb permanece exclusivo do builder para qualificação de pacotes.
Para armazenamento, o Pori é o gerenciador DINX de discos/montagens e o Phyto é o gerenciador de arquivos padrão. O File Roller fornece ações gráficas para arquivos compactados e o GParted fornece particionamento gráfico independente fora do Calamares. O Pori usa UDisks2 para descobrir dispositivos de bloco e cria serviços de montagem persistentes scriptados em `/etc/dinit.d`; ele não usa unidades systemd. A imagem base não instala Thunar, GVFS, Tumbler nem KDE Partition Manager. O Phyto cuida da navegação de diretórios; o agente independente de PolicyKit do LXQt continua disponível para ações privilegiadas, e o Pearl continua sendo o shell ativo.
Para configuração de displays, o wrapper DINX `dinx-wdisplays` abre o editor interativo de saídas Wayland; ao fechar, ele substitui atomicamente o perfil `DINX wdisplays` em `~/.config/shikane/config.toml` e recarrega o daemon de usuário Shikane. O Shikane inicia dentro de Aqueous/Pearl e reaplica perfis correspondentes quando as saídas mudam. `Dome`, `Seafoam Settings` e `zls` fazem parte da ISO base e do repositório DINX assinado. Dome oferece monitoramento de recursos/processos compatível com dinit sem integração com systemd; Seafoam Settings é o launcher nativo em Zig/GTK4 com argv fixo para os pontos de entrada de display/sessão; ZLS é o language server Zig incluído e usado pelo Dintor com sua árvore `lib/std` correspondente e shim somente de metadados. Aqueous 1.0.5 e Pearl 0.3.0 são os únicos componentes selecionáveis da sessão.

Para navegação web, o perfil instala o release oficial x86_64 do Floorp, fixado por checksum, como manipulador padrão de HTML/XHTML/HTTP/HTTPS. As políticas gerenciadas em `/usr/lib/floorp/distribution/policies.json` desativam superfícies patrocinadas, telemetria, recomendações, alguns recursos de IA e o atualizador interno do Floorp. Os pins do Floorp são mantidos pelo fluxo revisado de atualização de pacotes DINX; entrar em uma conta Mozilla continua opcional.
O perfil também inclui btop/nvtop/inxi, diagnóstico PCI e USB, Git/curl/less/jq/rsync, ONLYOFFICE para documentos, planilhas, apresentações e PDFs, Swayimg, Haruna, Gapless (G4Music), Galculator, `wl-clipboard`, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor`, o backend SANE `scanimage`, `fwupdmgr`, o runtime Flatpak, Impasto, Krita, Inkscape, Godot, Pixelorama, Patchy e Blockbench. Impasto, Krita, Inkscape e Pixelorama oferecem edição gráfica raster; Godot é uma engine de jogos. Impasto, Patchy e Blockbench são AppImages upstream com versões e avisos de licença fixados por checksum, preservados byte a byte e iniciados com `--appimage-extract-and-run` sem exigir FUSE. Pixelorama usa o release Linux x86_64 oficial com checksum fixado, wrapper, entrada desktop, ícone, licença MIT e registro MIME `.pxo`. Galculator é uma calculadora compacta em GTK 3 que usa a pilha GTK existente, sem adicionar outro toolkit gráfico. Gapless é compilado da versão upstream v4.6.2 fixada, com codecs GStreamer base/good e reprodução sem intervalos ativada por padrão. Ele oferece controles de mídia MPRIS. O Swayimg é compilado a partir da fonte upstream 5.6 fixada, com Wayland, JPEG e PNG, e continua sendo o visualizador padrão. Pearl é dono das superfícies ativas e as bridges DINX são estáticas; nenhum plugin ou asset privado de shell é necessário. Nenhum aplicativo Flatpak é pré-instalado.

### Nomes dos launchers

Os nomes seguem o idioma do desktop. O Swayimg permanece oculto no menu de aplicativos e abre arquivos de imagem associados. O desktop ID original do Calamares/Artix é substituído por um tombstone inerte; somente o atalho funcional do instalador DINX é exposto.

| Aplicativo | English | Português (Brasil) |
| --- | --- | --- |
| Dome | System Monitor | Monitor do Sistema |
| DinitUI | Services | Serviços |
| DINXPanel | Control Center | Central de Controle |
| Seafoam Settings | Desktop Settings | Ajustes do Desktop |
| Dintor | Editor | Editor |
| Pori | Disks & Mounts | Discos e Montagens |
| Phyto | Files | Arquivos |
| Configuração de display | Display Settings | Ajustes de Tela |
| Shelly | Software & Updates | Aplicações e Updates |
| Galculator | Calculator | Calculadora |
| GParted | Partition Editor | Particionador |
| Impasto | Image Editor | Editor de Imagens |
| Krita | Digital Painting | Pintura Digital |
| Inkscape | Vector Graphics | Gráficos Vetoriais |
| Godot | Game Engine | Motor de Jogos |
| Pixelorama | Pixel Art & Animation | Arte de Pixel e Animação |
| Patchy | Image Editor | Editor de Imagens |
| Blockbench | 3D Model Editor | Editor de Modelos 3D |
| Swayimg | Image Viewer | Visualizador de Imagens |
| ONLYOFFICE | Office and PDF Editors | Suíte de Escritório e PDF |
| Gapless | Music Player | Tocador de Música |
| Haruna | Media Player | Tocador de Mídia |
| Blueman | Bluetooth | Bluetooth |
| Conexões de rede | Network Connections | Ajustes de Rede |
| pwvucontrol | Audio Control | Ajustes de Áudio |
| File Roller | Archive Manager | Descompactador |
| Instalador DINX | Install DINX | Instalar DINX |
| Configuração de Firewall | Firewall | Firewall |
| Qps | Process Manager | Processos |

O payload de gerenciamento adiciona `topgrade`, `paru` e Shelly. Topgrade usa um binário de release upstream fixado com a configuração `pacman` do Artix da DINX; paru é compilado a partir do release fonte fixado contra o ALPM do Artix; o Shelly delega para a configuração `pacman` do Artix. Os metadados não têm dependência ou unidade `systemd`, nenhum repositório Arch é adicionado e receitas AUR continuam sujeitas a revisão. Nenhum deles inicia automaticamente no boot.
Para gaming, o grupo `gaming` tem `iso:false`; Gamescope, Steam, regras de dispositivos Steam, GameMode, MangoHud e bibliotecas de 32 bits ficam fora do rootfs/livefs base. O perfil base mantém firmware AMDGPU e Intel, Mesa RADV e ferramentas Vulkan de 64 bits. O P0 não habilita mais o repositório Artix `[lib32]` para montar a ISO; o usuário pode optar por habilitá-lo depois da instalação seguindo o [`guia de instalação`](../../docs/pt-BR/install.md). Nenhum repositório Arch é adicionado.
Os firmwares AMDGPU e Intel, Mesa RADV e as ferramentas Vulkan permanecem no perfil base como suporte gráfico genérico. O governor Cyan Skillfish exclusivo da BC-250, seu pacote dinit e o BC250 Control Center não são instalados na raiz live nem na raiz instalada genéricas. O CI mantém os pacotes fixados no repositório DINX assinado.
Instale esses pacotes somente após `lspci -n -d 1002:13fe` confirmar o dispositivo; configure o repositório DINX assinado e siga as etapas protegidas em [`docs/pt-BR/install.md`](../../docs/pt-BR/install.md).
O pacote do governor instala o runtime correspondente e usa dinit; seu wrapper aplica os limites configurados somente ao PCI `1002:13fe`. Use um kernel Artix com as correções upstream atuais da BC-250 (6.17.11 ou mais novo; prefira o kernel LTS do Artix). A raiz compacta da ISO inclui firmware AMDGPU e Intel para suporte gráfico geral, mas omite o bundle genérico `linux-firmware` e o `powertop`; mantém os headers necessários para gerar o initramfs do Artix e exclui a árvore de fontes do SquashFS final.
O payload de firewall/processos inclui Firewalld, firewall-config, OpenSnitch e Qps. Firewalld e o daemon OpenSnitch usam serviços Dinit separados, habilitados nos root filesystems live e instalado; o autologin live aguarda a tentativa de inicialização do Firewalld, mas continua mesmo se ela falhar. A interface OpenSnitch inicia em segundo plano/tray na sessão do usuário. O OpenSnitch usa nftables com os padrões upstream `DefaultAction=allow` e `InterceptUnknown=false`: não aplica bloqueio padrão e complementa, sem substituir, o Firewalld. A regra local de PolicyKit da sessão live permite que firewall-config gerencie o Firewalld sem senha. UFW, Gufw e Portmaster não são distribuídos.

O DinitUI instala perfis de serviços de sistema `normal`, `lite` e `gaming` e permite perfis customizados em `~/.config/dinx/dinitui/profiles.conf`. `lite` desabilita somente o Bluetooth opcional; Gaming habilita Bluetooth para controles. Os perfis integrados não alteram Firewalld nem OpenSnitch. O launcher standalone entra no Gaming e restaura o perfil anterior ao sair; falhas de entrada ou restauração interrompem o launcher e permanecem visíveis. A DINXPanel é dona das ações visíveis de hardware e drivers, dos atalhos fixos, dos fluxos Shelly/Topgrade, da descoberta opcional do fwupd e do instalador seguro de kernels Artix; Aqueous/Pearl não exige plugin de shell.
O host dedicado do Pearl Greeter fornece a interface de login do greetd. Pearl é o shell ativo; Aqueous/Pearl é a única sessão do usuário.
### Segurança da sessão, hierarquia e guarda de recursos

A sessão live usa `swayidle` e `wlopm` para desligar todas as telas após 600 segundos sem atividade e antes da suspensão, restaurando-as com atividade ou ao retomar. O Aqueous rejeita solicitações de bloqueio de sessão; o atalho padrão de bloqueio, o botão da DINXPanel e o launcher de bloqueio da área de trabalho ficam desativados para o usuário live. As sessões instaladas mantêm o `swaylock` para bloqueio por inatividade e suspensão, com bloqueio explícito por `dinx-lock`, `Super+L`, Pearl e DINXPanel. As teclas padrão de brilho e a DINXPanel usam passos fixos de 5% com `brightnessctl`; ferramentas especializadas permanecem no launcher.

`scripts/check_dinx_budget.sh` mantém o perfil atual em 118 de 128 entradas de pacotes rootfs e no máximo 24 entradas de inicialização dinit, limita os binários compilados da DINXPanel/DinitUI a 6 MiB cada, limita a janela de qualificação de boot QEMU a 120 segundos e exige que uma ISO construída fique abaixo de 2 GiB (`2147483647` bytes) quando `DINX_ISO_PATH` é fornecido. Passar no limite de contagem de pacotes não garante passar no limite de tamanho da ISO; o artefato final deve passar ambos. Esses limites são barreiras de regressão, não medições de desempenho em hardware. `scripts/measure_dinx_session.sh` registra snapshots de RSS/CPU via `/proc` quando uma sessão DINX está realmente em execução.

O builder Artix ainda consome um único `profile.yaml`; o manifesto de grupos é um contrato, não um mecanismo de composição de pacotes. O perfil da ISO genérica contém os grupos foundation e desktop, enquanto gaming e pacotes específicos da BC-250 ficam fora da imagem base. As políticas de serviço Normal/Lite/Gaming do DinitUI continuam separando serviços em runtime.

O gate de conteúdo do P0 exige que as imagens SquashFS do root e da sessão live contenham o compositor, shell, greeter, sessão e Deetty como único emulador de terminal, além do editor de recuperação Nano, do gerenciador de armazenamento Pori com dinit, do gerenciador de arquivos Phyto, do suporte `ntfs3` de leitura/escrita, do backend de scanner SANE, das ferramentas de firmware fwupd, do runtime Flatpak, Impasto, Krita, Inkscape, Godot, Patchy e Blockbench, e do payload dinit esperado. Ele rejeita binários, launchers e metadata de pacote do KolourPaint, além de binários e metadata dos pacotes gaming opcionais, nas duas imagens. `scripts/check_desktop_packages.sh` e `scripts/check_pori_phyto.sh` verificam contratos de pacote/perfil antes do build. `scripts/smoke-install.sh` executa o contrato offline em discos BIOS/UEFI efêmeros, verifica o primeiro boot dinit e habilita as TTYs de recuperação. A captura PPM do workflow é evidência visual para inspeção, não qualificação de hardware arbitrária.

O check de bibliotecas de runtime da instalação cobre aplicativos dinamicamente ligados. O release upstream do ZLS, fixado por checksum, é estático; o smoke verifica sua versão e a configuração selecionada dentro do chroot alvo.

O gate de sessão live do P0 exige `AUTOLOGIN=true`, o serviço dinit de autologin exclusivo da live e a fronteira inalterada do greeter do sistema instalado.

O smoke do disco instalado em BIOS/UEFI também exige que a captura da tela mostre os controles `Sign in` e `Password` do Pearl; logs de serviços ativos e framebuffer válido não bastam para qualificar o login.

O contrato de payload também exige `wdisplays`, `shikane` e os pontos de entrada DINX de persistência de display. As fontes externas de Dome e ZLS são fixadas; o Seafoam Settings é compilado a partir da fonte versionada no repositório. Os três são obrigatórios e verificados como parte do payload base da ISO.

O workflow armazena uma captura separada `dinx-boot-screen.ppm`, feita antes do envio das teclas do menu de boot. Esse quadro deve ser revisado ao qualificar a superfície GRUB de seleção do kernel; ele é a evidência de regressão do painel opaco removido.

O GRUB usa o símbolo compacto D com raio, transparente, junto às cores DINX de superfície, primeiro plano e seleção primária no lugar do logo Artix; as fontes Artix continuam em uso. As texturas opacas do menu ficam desativadas. O Pearl Greeter e a área de trabalho inicial usam fundos sólidos, sem imagem de wallpaper ou logo DINX; o Calamares mantém o wordmark completo no logo/boas-vindas e o símbolo compacto como ícone do produto. Papirus é o único tema de ícones explicitamente selecionado para os lançadores; Qogir e os temas/estilos KDE Breeze são excluídos. Os ícones dos aplicativos permanecem upstream, e os recursos Adwaita continuam disponíveis para compatibilidade GTK.
No perfil fonte atual, o caminho live normal é autologin direto; o greeter permanece como fallback, não como etapa obrigatória do boot.

## Limite do perfil

O repositório versiona um manifesto comum compacto em `iso-profiles/common/common.yaml` em vez de depender do default do `iso-profiles` instalado. Ele mantém o payload de fundação e desktop da DINX e exclui gaming opcional, pacotes específicos da BC-250, firmware genérico e `powertop` da imagem final; os headers do kernel, usados apenas no build, também ficam fora das imagens SquashFS finais. Seu SHA-256 é registrado em `build-metadata.txt`. `WORKSPACE_DIR` em `scripts/build-iso.sh` seleciona os dois manifestos locais de forma determinística.
O perfil comum deixa de selecionar `dhcpcd-dinit`: o NetworkManager usa seu cliente DHCP interno. Ele também não seleciona o alias Artix `vi`, que resolve para `ex-vi-compat` e depende de `vim`/`vim-runtime`; Nano continua como editor de recuperação, e Vim fica somente no builder isolado para qualificação de TUI. `man-db`, `man-pages` e `texinfo` também saem do rootfs comum; `man-db` e `texinfo` permanecem como dependências isoladas de build/qualificação do Deetty, não como pacotes de runtime da ISO. O Calamares instala o mesmo `rootfs.img`, então os três pacotes de documentação também ficam ausentes do sistema instalado. O `memtest86+` fica somente em `packages-boot`: o `make_bootfs()` do artools 0.40 do Artix copia `/boot/memtest86+/memtest.bin` incondicionalmente. Ele não aparece no menu DINX nem é instalado no rootfs/livefs.

Uma validação P0 bem-sucedida da main após o release é a execução [40894570770](https://github.com/rufl/DINX/actions/runs/40894570770), no commit `bf773500965c843e014e3bc3ef8fea685e14b91b`. Ela passou pelo build, check do payload SquashFS compacto, boot/captura gráfica no QEMU, transação de particionamento do Calamares, smokes de instalação persistente/TTY de recuperação em BIOS e UEFI descartáveis, verificação dos metadados, atestação e upload do artefato. A corrida do marcador UEFI foi corrigida ordenando-o depois de `early-root-rw.target`; esta execução da main não substituiu a ISO marcada.

A release marcada atual é a [v0.1.0-alpha.12](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.12), validada pelo [workflow 41197618617](https://github.com/rufl/DINX/actions/runs/41197618617) no commit `56a814575e33bfae6215993972784f11b7dae215`. A ISO direta tem 1.836.830.720 bytes e SHA-512 `ac1dbd237e484f8d61aab5438185218b13d9e23824ce671440ff67ed275ce7073b90dbcc14bc8d8f7008b2422d66e2756f1b3a88a0d5c21d8c7bbc67c9d60bf9`. O smoke QEMU desta release usou o dispositivo VGA padrão; o código atual configura um smoke adicional de boot/captura com VMware-SVGA no QEMU, ainda não executado. A fonte atual também contém o fallback VMSVGA; a Alpha 12 é anterior a ele, e o boot direto no VirtualBox continua sem qualificação. A Beta 0.1 é a próxima etapa planejada; hardware físico, rede, áudio, Steam/jogos autenticados, saída gaming DRM real e qualificação de atualização/rollback continuam fora da evidência da Alpha 12. Veja o [roadmap](../../docs/pt-BR/roadmap.md).

## Validação do build

Um build de imagem bem-sucedido não é o critério de release. A ISO resultante exige:

1. geração de checksum;
2. validação do conteúdo SquashFS;
3. smoke test de boot e instalação em VM;
4. verificação da TTY de recuperação;
5. verificações de rede, áudio, D-Bus, portal e gráficos;
6. relatório de instalação/atualização antes de ser rotulada como alpha.
