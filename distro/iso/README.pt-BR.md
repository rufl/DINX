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


A smoke de boot no QEMU captura a superfície VGA e usa OCR do Tesseract para exigir um marcador da área de trabalho Pearl/Aqueous/DINX, rejeitando Pearl Greeter, prompts de login e falhas visíveis do Dinit. Smokes locais exigem `qemu-system-x86_64`, `socat`, `tesseract-ocr` e `tesseract-ocr-eng`:

```bash
DINX_QEMU_TIMEOUT=90 \
DINX_QEMU_BOOT_KEYS=down,down,ret \
DINX_QEMU_SCREENSHOT=dist/iso/dinx/tela-grafica.ppm \
DINX_QEMU_SCREENSHOT_DELAY=60 \
scripts/smoke-iso.sh dist/iso/<arquivo>.iso
```

O smoke também verifica o quadro capturado da sessão. Sem `DINX_QEMU_SCREENSHOT`, salva o PPM verificado ao lado do log QEMU como `<iso>.qemu.log.session.ppm`; `DINX_QEMU_OCR_LANG` seleciona outro modelo de idioma Tesseract instalado.


Verifique o payload gráfico dentro da imagem SquashFS do root:

```bash
scripts/check-iso-content.sh dist/iso/<arquivo>.iso
```

Opções adicionais do `buildiso` são repassadas sem alteração. Por exemplo, para consultar as configurações sem executar o build:

```bash
scripts/build-iso.sh -q
```

O diretório de saída padrão é `dist/iso`; ele pode ser alterado com `DINX_ISO_OUTPUT`. O cache de chroots padrão é `/var/lib/artools/buildiso`; altere-o com `DINX_ISO_CHROOTS` quando o builder usar outro volume persistente.
## Meta de tamanho da ISO

O wrapper do build coloca `scripts/iso-tools/mksquashfs` no início do `PATH`
do builder. Ele força imagens SquashFS com preset xz suportado pela ferramenta,
BCJ x86, blocos de 256 KiB e dicionário de 256 KiB. Fontes do kernel, caches de
pacotes pacman e logs de build ficam fora da imagem final. O root overlay recria
`/var/log/dinit` por tmpfiles antes de os serviços Dinit iniciarem, e o check de
conteúdo da ISO exige essa regra. O pacote `dinx-live-autologin`, exclusivo do
livefs, fornece unidades no-op `root-ro` e `early-root-rw.target` para seu overlay
gravável; essas substituições não entram no rootfs instalado pelo Calamares. O
`squashfs-tools` exclusivo do build permanece no builder, não no payload de runtime.
O CI instala o wrapper em `/usr/bin/mksquashfs` após preservar o binário real,
pois o `buildiso` do Artix pode invocar esse caminho absoluto. A inspeção
pós-build verifica xz e blocos de 256 KiB nos dois superblocos SquashFS.
O orçamento P0 rejeita ISOs no limite ou acima de 2 GiB por asset do GitHub; a
Alpha 10 tem 1.862.772.736 bytes (284.710.912 bytes abaixo do limite).

## Perfil gráfico

`iso-profiles/dinx/profile.yaml` inclui Aqueous, Pearl, greetd e o pacote nativo `deetty`. Deetty é o único emulador de terminal nos rootfs da sessão live e do sistema instalado. O pacote `ghostty-vt-runtime` da ISO contém somente a biblioteca VT, os headers e a licença necessários ao Deetty, não o aplicativo de terminal Ghostty. O pacote Pearl fornece o Pearl Greeter; `deetty` instala os aplicativos Deetty e Dintor, incluindo arquivos desktop, ícones, especificações de linguagem e o estilo escuro do editor. O CI consome o archive versionado gerado a partir do commit exato de `https://github.com/rufl/NOCTTY.git` e do contrato SHA-256 em `distro/packages/deetty/source.env`. O upstream e a identidade interna do archive continuam sendo NOCTTY; o pacote DINX e os aplicativos são Deetty/Dintor. O root overlay fornece `/etc/greetd/config.toml`, `/etc/pearl/greeter.json` e metadados de sessão oculta; Aqueous + Pearl é a única entrada de sessão do usuário.

O livefs adiciona o pacote dinit `dinx-live-autologin`, exclusivo da sessão live. Ele habilita o `initial_session` único do greetd para `dinx` com Aqueous + Pearl e fornece unidades no-op de remontagem da raiz, pois o overlay live já é gravável. Essas substituições ficam no `livefs`; o Calamares instala `rootfs.img`, que mantém as unidades genéricas de remontagem do Artix.

`iso-profiles/dinx/feature-groups.json` registra os grupos foundation, desktop, gaming, hardware e opcional sem substituir o `profile.yaml` do Artix. O builder do CI assina cada pacote customizado e o banco temporário do repositório `dinx` com uma chave efêmera, verifica assinaturas e caminhos duplicados dos archives e registra o snapshot imutável dos pacotes em `build-metadata.txt`. Isso é qualificação do build; a chave do repositório pacman de produção e o canal de atualização do sistema instalado continuam sendo pré-requisitos separados do release.

O perfil controla bridges visuais estáticas DINX: `/usr/share/dinx/theme/DINX.json` é a fonte das cores semânticas e ANSI; GTK e Qt consomem arquivos DINX versionados, e `DINX_COLOR_SCHEME` é o contrato de cor da sessão do usuário. `qt6ct`, `adw-gtk-theme` e Noto Sans 10 são instalados para esses consumidores, alinhados à tipografia GTK padrão do CachyOS; Noto Sans Mono é usado nos campos de largura fixa. O host do Pearl Greeter lê `/etc/pearl/greeter.json`, usa a bridge GTK DINX e força `Aqueous + Pearl (DINX)` com X11 e UWSM desativados; Aqueous/Pearl é o único contrato de sessão do usuário. `scripts/check_dinx_theme.sh` valida esse contrato antes do build da ISO.

O wordmark DINX Linux completo aparece no Pearl Greeter e no wallpaper inicial da área de trabalho; o Calamares também o usa no logo do produto e na tela de boas-vindas. O símbolo reduzido D com raio é mantido como SVG transparente em `design/brand/dinx-ray-mark.svg`, copiado para os assets de marca da ISO e renderizado como logo do GRUB; o Calamares usa-o como ícone do produto. Ícones de aplicativos e da área de trabalho permanecem upstream/Adwaita; a marca DINX não é forçada sobre eles.
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

Pearl Greeter, Aqueous/Pearl e o instalador recebem defaults DINX pelo root overlay. O Pearl Greeter usa o tema GTK DINX instalado e o JSON do greeter pertencente ao root; o Calamares usa os mesmos tokens de superfície/texto/primário/erro no stylesheet Qt. Pearl é o shell ativo do usuário. O host Aqueous dedicado executa somente o Pearl Greeter e não é exposto como fallback de sessão do usuário. A cadeia do Calamares mantém apenas os componentes do instalador, entradas de sessão não suportadas continuam ocultas e `Aqueous + Pearl (DINX)` é a sessão live. A sessão live expõe `Instalar DINX` pelo launcher. O alias `Instalar Artix` fornecido pelo pacote do Calamares fica oculto por um override desktop local; o atalho do instalador DINX é o único exibido.
O caminho live usa `Aqueous + Pearl (DINX)` sem prompt de credenciais: um serviço dinit exclusivo da live prepara o greetd antes de iniciá-lo. O rootfs instalado mantém login manual e o Calamares mantém os dois flags de autologin desativados.
Os defaults globais GTK 3/4 em `/etc/xdg/gtk-3.0/settings.ini` e `/etc/xdg/gtk-4.0/settings.ini` selecionam o tema escuro DINX, inclusive para ferramentas GTK iniciadas com privilégios elevados. Como o greetd inicia a sessão live sem carregar perfis de shell, o launcher do Aqueous exporta diretamente `GTK_THEME=DINX:dark` e `QT_QPA_PLATFORMTHEME=qt6ct`, além de copiar a configuração/paleta DINX do Qt6ct quando faltam na pasta home existente. O Aqueous inicia no layout livre `stacking`; `Alt+Shift+F` o seleciona a partir de outro layout e `Super+Shift+Space` alterna o modo flutuante da janela focada.

O payload runtime é somente Wayland/XWayland: servidores, drivers legados de Xorg/XLibre e entradas de sessão do Plasma são omitidos. Xvfb permanece exclusivo do builder para qualificação de pacotes.
Para armazenamento, o Pori é o gerenciador DINX de discos/montagens e o Phyto é o gerenciador de arquivos padrão. O File Roller fornece ações gráficas para arquivos compactados e o GParted fornece particionamento gráfico independente fora do Calamares. O Pori usa UDisks2 para descobrir dispositivos de bloco e cria serviços de montagem persistentes scriptados em `/etc/dinit.d`; ele não usa unidades systemd. A imagem base não instala Thunar, GVFS, Tumbler nem KDE Partition Manager. O Phyto cuida da navegação de diretórios; o agente independente de PolicyKit do LXQt continua disponível para ações privilegiadas, e o Pearl continua sendo o shell ativo.
Para configuração de displays, o wrapper DINX `dinx-wdisplays` abre o editor interativo de saídas Wayland; ao fechar, ele substitui atomicamente o perfil `DINX wdisplays` em `~/.config/shikane/config.toml` e recarrega o daemon de usuário Shikane. O Shikane inicia dentro de Aqueous/Pearl e reaplica perfis correspondentes quando as saídas mudam. `Dome`, `Seafoam Settings` e `zls` fazem parte da ISO base e do repositório DINX assinado. Dome oferece monitoramento de recursos/processos compatível com dinit sem integração com systemd; Seafoam Settings é o launcher nativo em Zig/GTK4 com argv fixo para os pontos de entrada de display/sessão; ZLS é o language server Zig incluído e usado pelo Dintor com sua árvore `lib/std` correspondente e shim somente de metadados. Aqueous 1.0.5 e Pearl 0.3.0 são os únicos componentes selecionáveis da sessão.

Para navegação web, o perfil instala Firefox e o torna o manipulador padrão de HTML/XHTML/HTTP/HTTPS. A política de sistema em `/etc/firefox/policies/policies.json` desativa superfícies patrocinadas da Nova Aba e do Firefox Suggest, Pocket/Stories, Firefox Studies/telemetria, recomendações do navegador, superfícies de assistente de IA/preview de links/grupos de abas e o IP Protection integrado. Firefox Accounts continua sendo uma escolha explícita do usuário: a DINX não exige login nem exibe onboarding, enquanto as atualizações normais do navegador continuam habilitadas.
O perfil também inclui btop/nvtop/inxi, diagnóstico PCI e USB, Git/curl/less/jq/rsync, Zathura com backend MuPDF, Swayimg, VLC, Gapless (G4Music), Galculator, `wl-clipboard`, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor`, o backend SANE `scanimage`, `fwupdmgr`, o runtime Flatpak e KolourPaint. Galculator é uma calculadora compacta em GTK 3 que usa a pilha GTK existente, sem adicionar outro toolkit gráfico. Gapless é compilado da versão upstream v4.6.2 fixada, com codecs GStreamer base/good e reprodução sem intervalos ativada por padrão. Ele oferece controles de mídia MPRIS. O Swayimg é compilado a partir da fonte upstream 5.6 fixada, com Wayland, JPEG e PNG, e continua sendo o visualizador padrão. Pearl é dono das superfícies ativas e as bridges DINX são estáticas; nenhum plugin ou asset privado de shell é necessário. Nenhum aplicativo Flatpak é pré-instalado.

### Nomes dos launchers

Os nomes seguem o idioma do desktop. O Swayimg permanece oculto no menu de aplicativos e abre arquivos de imagem associados. O alias Artix do Calamares fica oculto; somente o atalho do instalador DINX é exibido.

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
| KolourPaint | Drawing | Desenho |
| Swayimg | Image Viewer | Visualizador de Imagens |
| Zathura | PDF Reader | Leitor de PDF |
| Gapless | Music Player | Tocador de Música |
| VLC | Media Player | Tocador de Mídia |
| Blueman | Bluetooth | Bluetooth |
| Conexões de rede | Network Connections | Ajustes de Rede |
| pwvucontrol | Audio Control | Ajustes de Áudio |
| File Roller | Archive Manager | Descompactador |
| Instalador DINX | Install DINX | Instalar DINX |
| Gufw | Firewall | Firewall |
| Qps | Process Manager | Processos |
| OpenSnitch | Traffic Monitor | Monitor de Tráfego |

O payload de gerenciamento adiciona `topgrade`, `paru` e Shelly. Topgrade usa um binário de release upstream fixado com a configuração `pacman` do Artix da DINX; paru é compilado a partir do release fonte fixado contra o ALPM do Artix; o Shelly delega para a configuração `pacman` do Artix. Os metadados não têm dependência ou unidade `systemd`, nenhum repositório Arch é adicionado e receitas AUR continuam sujeitas a revisão. Nenhum deles inicia automaticamente no boot.
Para gaming, o grupo `gaming` tem `iso:false`; Gamescope, Steam, regras de dispositivos Steam, GameMode, MangoHud e bibliotecas de 32 bits ficam fora do rootfs/livefs base. O perfil base mantém firmware AMDGPU, Mesa RADV e ferramentas Vulkan de 64 bits. O P0 não habilita mais o repositório Artix `[lib32]` para montar a ISO; o usuário pode optar por habilitá-lo depois da instalação seguindo o [`guia de instalação`](../../docs/pt-BR/install.md). Nenhum repositório Arch é adicionado.
O firmware AMDGPU, Mesa RADV e as ferramentas Vulkan permanecem no perfil base como suporte gráfico AMD genérico. O governor Cyan Skillfish exclusivo da BC-250, seu pacote dinit e o BC250 Control Center não são instalados na raiz live nem na raiz instalada genéricas. O CI mantém os pacotes fixados no repositório DINX assinado.
Instale esses pacotes somente após `lspci -n -d 1002:13fe` confirmar o dispositivo; configure o repositório DINX assinado e siga as etapas protegidas em [`docs/pt-BR/install.md`](../../docs/pt-BR/install.md).
O pacote do governor instala o runtime correspondente e usa dinit; seu wrapper aplica os limites configurados somente ao PCI `1002:13fe`. Use um kernel Artix com as correções upstream atuais da BC-250 (6.17.11 ou mais novo; prefira o kernel LTS do Artix). O manifesto comum compacto mantém o firmware AMDGPU para suporte gráfico AMD geral, mas omite o bundle genérico `linux-firmware` e o `powertop`; mantém os headers necessários para gerar o initramfs do Artix e exclui a árvore de fontes do SquashFS final.
O payload de firewall/processos adiciona UFW com os arquivos de serviço `ufw-dinit` do Artix, Gufw e daemon/UI do OpenSnitch com serviço dinit da DINX, além do Qps. No launcher de aplicativos, Gufw aparece como Firewall, a interface do OpenSnitch como Monitor de Tráfego e Qps como Processos. Os serviços UFW e OpenSnitch são instalados, mas não são ligados ao boot por padrão: configure as regras e habilite deliberadamente a política de firewall desejada. Não habilite os dois gerenciadores de regras sem revisar o ruleset netfilter resultante.

O DinitUI instala os perfis de serviços `normal`, `lite` e `gaming` e permite perfis customizados em `~/.config/dinx/dinitui/profiles.conf`. `lite` desabilita somente o Bluetooth opcional; Gaming habilita Bluetooth para controles e preserva os serviços de firewall/política de processos. O launcher standalone entra no Gaming e restaura o perfil anterior ao sair; falhas de entrada ou restauração interrompem o launcher e permanecem visíveis. A DINXPanel é dona das ações visíveis de hardware e drivers, dos atalhos fixos, dos fluxos Shelly/Topgrade, da descoberta opcional do fwupd e do instalador seguro de kernels Artix; Aqueous/Pearl não exige plugin de shell.
O host dedicado do Pearl Greeter fornece a interface de login do greetd. Pearl é o shell ativo; Aqueous/Pearl é a única sessão do usuário.
### Segurança da sessão, hierarquia e guarda de recursos

A sessão instala `swaylock`, `swayidle` e `brightnessctl`. `/usr/local/libexec/dinx-idle` bloqueia após 600 segundos e bloqueia novamente em `before-sleep`; `/usr/local/libexec/dinx-lock`, `Super+L`, a superfície de bloqueio do Pearl e a DINXPanel fornecem o caminho explícito. As teclas padrão de brilho e a DINXPanel usam passos fixos de 5% com `brightnessctl`; ferramentas especializadas permanecem no launcher.

`scripts/check_dinx_budget.sh` mantém o perfil atual em no máximo 128 entradas de pacotes rootfs e 24 entradas de inicialização dinit, limita os binários compilados da DINXPanel/DinitUI a 6 MiB cada, limita a janela de qualificação de boot QEMU a 120 segundos e exige que uma ISO construída fique abaixo de 2 GiB (`2147483647` bytes) quando `DINX_ISO_PATH` é fornecido. Esses limites evitam regressões; não são medições de desempenho em hardware. `scripts/measure_dinx_session.sh` registra snapshots de RSS/CPU via `/proc` quando uma sessão DINX está realmente em execução.

O builder Artix ainda consome um único `profile.yaml`; o manifesto de grupos é um contrato, não um mecanismo de composição de pacotes. O perfil da ISO genérica contém os grupos foundation e desktop, enquanto gaming e pacotes específicos da BC-250 ficam fora da imagem base. As políticas de serviço Normal/Lite/Gaming do DinitUI continuam separando serviços em runtime.

O gate de conteúdo do P0 exige que as imagens SquashFS do root e da sessão live contenham o compositor, shell, greeter, sessão e Deetty como único emulador de terminal, além do editor de recuperação Nano, do gerenciador de armazenamento Pori com dinit, do gerenciador de arquivos Phyto, do suporte `ntfs3` de leitura/escrita, do backend de scanner SANE, das ferramentas de firmware fwupd, do runtime Flatpak, do editor de imagens KolourPaint e do payload dinit esperados. Também rejeita binários e metadata dos pacotes gaming opcionais nas duas imagens. `scripts/check_desktop_packages.sh` e `scripts/check_pori_phyto.sh` verificam contratos de pacote/perfil antes do build. `scripts/smoke-install.sh` executa o contrato offline em discos BIOS/UEFI efêmeros, verifica o primeiro boot dinit e habilita as TTYs de recuperação. A captura PPM do workflow é evidência visual para inspeção, não qualificação de hardware arbitrária.

O gate de sessão live do P0 exige `AUTOLOGIN=true`, o serviço dinit de autologin exclusivo da live e a fronteira inalterada do greeter do sistema instalado.

O contrato de payload também exige `wdisplays`, `shikane` e os pontos de entrada DINX de persistência de display. As fontes externas de Dome e ZLS são fixadas; o Seafoam Settings é compilado a partir da fonte versionada no repositório. Os três são obrigatórios e verificados como parte do payload base da ISO.

O workflow armazena uma captura separada `dinx-boot-screen.ppm`, feita antes do envio das teclas do menu de boot. Esse quadro deve ser revisado ao qualificar a superfície GRUB de seleção do kernel; ele é a evidência de regressão do painel opaco removido.

O GRUB usa o símbolo compacto D com raio, transparente, junto às cores DINX de superfície, primeiro plano e seleção primária no lugar do logo Artix; as fontes Artix continuam em uso. As texturas opacas do menu ficam desativadas. O Pearl Greeter e o wallpaper da área de trabalho usam o wordmark completo; o Calamares usa-o no logo/boas-vindas e o símbolo compacto como ícone do produto. Os ícones dos lançadores continuam upstream/Adwaita, sem a marca DINX.
No perfil fonte atual, o caminho live normal é autologin direto; o greeter permanece como fallback, não como etapa obrigatória do boot.

## Limite do perfil

O repositório versiona um manifesto comum compacto em `iso-profiles/common/common.yaml` em vez de depender do default do `iso-profiles` instalado. Ele mantém o payload de fundação e desktop da DINX e exclui gaming opcional, pacotes específicos da BC-250, firmware genérico e `powertop` da imagem final; os headers do kernel, usados apenas no build, também ficam fora das imagens SquashFS finais. Seu SHA-256 é registrado em `build-metadata.txt`. `WORKSPACE_DIR` em `scripts/build-iso.sh` seleciona os dois manifestos locais de forma determinística.

Uma validação P0 bem-sucedida da main após o release é a execução [40894570770](https://github.com/rufl/DINX/actions/runs/40894570770), no commit `bf773500965c843e014e3bc3ef8fea685e14b91b`. Ela passou pelo build, check do payload SquashFS compacto, boot/captura gráfica no QEMU, transação de particionamento do Calamares, smokes de instalação persistente/TTY de recuperação em BIOS e UEFI descartáveis, verificação dos metadados, atestação e upload do artefato. A corrida do marcador UEFI foi corrigida ordenando-o depois de `early-root-rw.target`; esta execução da main não substituiu a ISO marcada.

A release marcada atual continua sendo a [v0.1.0-alpha.10](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.10), validada pelo [workflow 40879223746](https://github.com/rufl/DINX/actions/runs/40879223746) no commit `3fd3cd036cab7e8fb553e6e5c244b02429f1a18e`. A ISO direta publicada tem 1.862.772.736 bytes, abaixo do limite de 2 GiB por asset do GitHub, e SHA-512 `5f49a65eac1481c01555a8f44b049c9a06e75ec7270ac3cdef97cc5e0b051d4b3c48a200542a36ec1832700accbc5509e3c314726c2f747530095eba4112219a`. A próxima etapa de sistema planejada é a Beta 0.1; hardware físico, rede, áudio, uso autenticado de Steam/jogo, saída gaming DRM real e qualificação de upgrade/rollback continuam fora da evidência da Alpha 10. Veja o [roadmap](../../docs/pt-BR/roadmap.md).

## Validação do build

Um build de imagem bem-sucedido não é o critério de release. A ISO resultante exige:

1. geração de checksum;
2. validação do conteúdo SquashFS;
3. smoke test de boot e instalação em VM;
4. verificação da TTY de recuperação;
5. verificações de rede, áudio, D-Bus, portal e gráficos;
6. relatório de instalação/atualização antes de ser rotulada como alpha.
