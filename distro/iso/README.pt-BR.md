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


<<<<<<< HEAD
A smoke de boot no QEMU captura a sessão gráfica e usa OCR do Tesseract para exigir um marcador da área de trabalho Morghulis/River/DINX, rejeitando prompts de login e falhas visíveis do Dinit. Ela verifica a tela inicial do Morghulis antes de validar o quadro da área de trabalho. Smokes locais exigem `qemu-system-x86_64`, `socat`, `tesseract-ocr` e `tesseract-ocr-eng`:
=======
A smoke de boot no QEMU captura a superfície VGA e usa OCR do Tesseract para exigir um marcador da área de trabalho River/KWM ou DINX, rejeitando agreety, consoles TTY, prompts de login e falhas visíveis do Dinit. Qualquer titlebar de compositor legível precisa nomear a pilha River ou KWM, e o check da área de trabalho live lê o atalho `Instalar DINX` pertencente ao pacote. Smokes locais exigem `qemu-system-x86_64`, `socat`, `tesseract-ocr` e `tesseract-ocr-eng`:
>>>>>>> main

O menu de boot mostra `Start DINX Linux`, os modos para hardware legado abaixo e, em sistemas UEFI, `Boot to the Firmware/BIOS`. DINX é a opção padrão e inicia após uma contagem regressiva visível de seis segundos. No BIOS legado não existe a opção de configuração do firmware UEFI. A qualificação completa do QEMU deixa o menu sem teclas injetadas para verificar a contagem.

O menu live oferece quatro modos para hardware legado: `Start DINX Linux` (padrão `quiet splash`), `(compatibility)` = `noapic irqpoll` para máquinas que travam em `do_IRQ: ... No irq handler for vector` (classe AMD E-350 "Zacate"/HP dm1), `(safe graphics)` = `noapic irqpoll nomodeset plymouth.enable=0` para tela preta durante modeset da GPU/splash (cai para a sessão em texto) e `(verbose boot)` = `noapic irqpoll ignore_loglevel loglevel=8 plymouth.enable=0` para mostrar exatamente onde o boot trava em vez de uma tela preta silenciosa. A imagem é híbrida: o MBR grub2 mais uma entrada El Torito de BIOS (`/boot/grub/i386-pc/eltorito.img`) e uma partição EFI System anexada fazem o mesmo arquivo iniciar por BIOS/MBR legado (emulação de CD, pendrive gravado com `dd` ou a ISO anexada como disco) e por UEFI. `scripts/check-iso-boot-records.sh` verifica esse layout estaticamente; `scripts/smoke-iso-mbr.sh` prova o caminho de disco iniciando a imagem sob SeaBIOS, sem emulação de CD nem OVMF, e selecionando `Start DINX Linux (compatibility)`. As duas são evidências de QEMU, não qualificação de hardware físico.

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

<<<<<<< HEAD
`iso-profiles/dinx/profile.yaml` inclui River, KWM, Morghulis, PCManFM, greetd e o pacote nativo `deetty`. Deetty é o único emulador de terminal nos rootfs live e instalado. O pacote `ghostty-vt-runtime` contém somente a biblioteca VT, headers e licença necessários ao Deetty, não o aplicativo Ghostty. O root overlay fornece a configuração do greetd, o wrapper da sessão River, o helper first-run do Morghulis, defaults MIME do PCManFM e a entrada Wayland.

O livefs adiciona o pacote dinit `dinx-live-autologin`, exclusivo da sessão live. Ele habilita o `initial_session` único do greetd para `dinx` com a sessão River/KWM/Morghulis e fornece unidades no-op de remontagem da raiz. Essas substituições ficam no `livefs`; o Calamares instala `rootfs.img`, que mantém as unidades genéricas de remontagem do Artix.

O login instalado usa a conta dedicada `greeter` e `agreety` via greetd. O wrapper de sessão inicia River, KWM, Morghulis, PCManFM, Shikane, PolicyKit e idle sem systemd ou UWSM.
=======
`iso-profiles/dinx/profile.yaml` inclui river, kwm, kwim, morghulis, dinx-dock, dinx-first-run, greetd com agreety e o pacote nativo `deetty`. Deetty é o único emulador de terminal nos rootfs da sessão live e do sistema instalado. O pacote `ghostty-vt-runtime` da ISO contém somente a biblioteca VT, os headers e a licença necessários ao Deetty, não o aplicativo de terminal Ghostty. Os pacotes DINX `kwm` e `kwim` fornecem o layout de janelas em mosaico e o gerenciador de entrada, o `morghulis` fornece o shell de desktop, e `dinx-dock` e `dinx-first-run` fornecem a barra de lançadores e o assistente de aparência de primeira execução; `deetty` instala os aplicativos Deetty e Dintor, incluindo arquivos desktop, ícones, especificações de linguagem e o estilo escuro do editor. O CI consome o archive versionado gerado a partir do commit exato e do contrato SHA-256 em `distro/packages/deetty/source.env`, do repositório `https://github.com/rufl/DEETTY.git`. O root overlay fornece `/etc/greetd/config.toml` e metadados de sessão oculta; `River + KWM + Morghulis (DINX)` é a única entrada de sessão do usuário.

O livefs adiciona o pacote dinit `dinx-live-autologin`, exclusivo da sessão live. Seu serviço de preparação define o hostname `dinxlive`, concede à conta descartável `dinx` acesso ao serviço `seatd` da live, espera o socket dele e provisiona o diretório de runtime privado `/run/dinx-session`; um serviço de processo separado e reiniciável então inicia a sessão como `dinx` via `dbus-run-session /usr/local/libexec/dinx-river-session`, e o overlay substitui o greetd por uma unidade no-op para que nenhum display manager entre no boot live. O pacote também fornece unidades no-op de remontagem da raiz, pois o overlay live já é gravável. Essas substituições ficam no `livefs`; o Calamares instala `rootfs.img`, que mantém as unidades genéricas de remontagem do Artix. O mesmo wrapper de sessão atende os dois caminhos, aplica a política gráfica descrita abaixo e escolhe o backend do libseat em runtime: `seatd` quando `/run/seatd.sock` existe e o usuário da sessão pertence ao grupo `seat`, `logind` (elogind) caso contrário — o elogind sob dinit registra a sessão, mas nunca a marca como ativa, o que antes deixava o compositor aguardando uma sessão DRM até o timeout. O serviço greetd instalado mantém `smooth-recovery` e o atraso de sete segundos entre reinícios para que uma nova tentativa não dispute com uma sessão ainda em encerramento.

A conta `greeter` usada pelo greetd tem `HOME=/`, então o greeter precisa apenas de um cache gravável: o `/etc/greetd/config.toml` executa o `agreety` com `XDG_CACHE_HOME=/var/cache/agreety`, e os tmpfiles de boot provisionam esse diretório com modo 0700 pertencente a `greeter`. O agreety guarda ali a última sessão escolhida; a DINX não provisiona árvore alguma de configuração, dados ou estado para o greeter.
>>>>>>> main


`iso-profiles/dinx/feature-groups.json` registra os grupos foundation, desktop, gaming, hardware e opcional sem substituir o `profile.yaml` do Artix. O builder do CI assina cada pacote customizado e o banco temporário do repositório `dinx` com uma chave efêmera, verifica assinaturas e caminhos duplicados dos archives e registra o snapshot imutável dos pacotes em `build-metadata.txt`. Isso é qualificação do build; a chave do repositório pacman de produção e o canal de atualização do sistema instalado continuam sendo pré-requisitos separados do release.

A árvore de código configura a atualização semanal dos pins de origem toda
segunda-feira às 04:17 UTC. Ela abre um pull request revisado para 23 pins de
origem de pacotes customizados, incluindo o subset latino Noto atualizado
mensalmente; o commit privado do Deetty e os pins do ZLS/Zig 0.16 continuam
manuais. Após o merge, um workflow assinado separado publica os pacotes sob a
tag de GitHub Release `dinx-packages-latest`, sem montar uma ISO. Os workflows
estão configurados, mas ainda não foram confirmados verdes nem publicados.
`dinx-keyring` configura o repositório `[dinx]` com assinatura obrigatória e
`/etc/pacman.d/dinx-mirrorlist` editável; o pacman atualiza os
pacotes, com o Octopi como front-end gráfico. Consulte o [guia de release](../../docs/pt-BR/release.md)
para configurar o segredo de assinatura e validar/preparar manualmente a
confiança da chave.

Todos os pacotes DINX são gerados como archives binários `.pkg.tar.zst`
assinados. Um único pacote `deetty` contém os binários pré-compilados do
terminal Deetty e do editor Dintor. Os apps binários em AppImage (PaintFE e
Patchy) são reempacotados no build por
`scripts/lib/repack-appimage.sh` em árvores `/opt/<pacote>/` pré-extraídas:
binários ELF com strip (Electron sem strip), locales reduzidos a en/pt e
launchers `/usr/bin/<pacote>` executando o `AppRun` da árvore diretamente —
sem FUSE e sem extração em tmpfs a cada inicialização. O Audionaut entra como um
único `/opt/audionaut/Audionaut.AppImage`, cujo launcher `/usr/bin/audionaut` o
executa com `--appimage-extract-and-run` em vez de uma árvore pré-extraída. O EuroOffice entra
como repack lean publicado pela branch office. Builds locais e P0 restauram
archives verificados, com chave baseada na fonte, receita, ambiente do builder
e conjunto de dependências instaladas; cache miss recompila o pacote. Assim,
cache hit evita recompilação sem enfraquecer pins de fonte ou verificação de
assinatura.

<<<<<<< HEAD
A DINX publica o ZLS como pacote opcional para a integração LSP de Zig do Dintor; ele
não é instalado na imagem live nem na instalação base. `clang`/`clangd` e Vim são
ferramentas de qualificação usadas somente no builder e não entram no runtime.
=======
A ISO inclui o ZLS para a integração LSP de Zig do Dintor. O Vim continua
como ferramenta de qualificação exclusiva do builder. Clang/clangd também
qualificam o cliente LSP genérico no builder, mas o pacote `clang` permanece
no runtime porque a dependência `openshadinglanguage` do Blender exige suas
bibliotecas.
>>>>>>> main

Antes da compressão SquashFS, o wrapper executa transações fail-closed
`pacman -Rns` no rootfs e no livefs para estas raízes de pacotes excluídas
quando instaladas: `breeze`, `breeze-cursors`, `dhcpcd`, `dhcpcd-dinit`,
`ex-vi-compat`, `linux-headers`, `man-db`, `man-pages`, `pahole`,
`plasma-integration`, `plasma-workspace`, `qogir-icon-theme`,
`qqc2-breeze-style`, `texinfo`, `vim`, `vim-runtime` e
`xdg-desktop-portal-kde`. `pahole` só é removido quando os headers do kernel
estão presentes. `breeze-icons` permanece porque Calamares → KParts → KIO →
KIconThemes exige esse pacote, embora Papirus seja o tema de ícones selecionado
para a área de trabalho.

<<<<<<< HEAD
O perfil controla bridges visuais estáticas DINX: `/usr/share/dinx/theme/DINX.json` é a fonte das cores semânticas e ANSI; GTK e Qt consomem arquivos DINX versionados, e `DINX_COLOR_SCHEME` é o contrato de cor da sessão. `qt6ct`, `adw-gtk-theme` e `dinx-noto-latin` permanecem instalados. Morghulis usa defaults Adwaita e o sincronizador de tema da sessão.

A área de trabalho Morghulis usa fundos sólidos, sem imagem de wallpaper ou logo DINX; o Calamares mantém o wordmark completo no logo do produto e na tela de boas-vindas. O símbolo reduzido D com raio continua como arte-fonte em `design/brand/dinx-ray-mark.svg` e é usado pelo Calamares como ícone do produto. O GRUB usa o PNG separado do boot-mark em gradiente. Papirus é o único tema de ícones selecionado explicitamente para a área de trabalho e os lançadores; Qogir, o estilo Breeze e os cursores Breeze são excluídos. `breeze-icons` permanece somente como dependência transitiva de Calamares → KParts → KIO → KIconThemes, não como tema escolhido para a área de trabalho. Os ícones próprios dos aplicativos permanecem inalterados, e os recursos Adwaita continuam disponíveis para compatibilidade GTK.
Na primeira sessão Morghulis, um helper pergunta se deve usar o tema claro ou o escuro padrão. A escolha é salva em `~/.config/morghulis/preferences.json`, aplicada a GTK/Qt e marcada em `~/.local/state/dinx/morghulis-first-run-complete`.
=======
O perfil controla bridges visuais estáticas DINX: `/usr/share/dinx/theme/DINX.json` é a fonte das cores semânticas e ANSI; GTK e Qt consomem arquivos DINX versionados, e `DINX_COLOR_SCHEME` é o contrato de cor da sessão do usuário. `qt6ct`, `adw-gtk-theme` e `dinx-noto-latin` são instalados para esses consumidores, alinhados à tipografia GTK padrão do CachyOS. O pacote fornece Noto Sans 10 regular/negrito/itálico/negrito itálico e Noto Sans Mono 10, subsetados para latim, marcas combinantes, pontuação comum e moedas; ele substitui o pacote completo `noto-fonts`. A DINX distribui uma aparência selecionável — o default é o esquema escuro DINX, e o assistente de primeira execução registra a família, variante, cantos e posição escolhidos em `~/.config/dinx/appearance.json` — e `River + KWM + Morghulis (DINX)` é o único contrato de sessão do usuário. `scripts/check_dinx_theme.sh` valida esse contrato antes do build da ISO.

O `dinx-gtk-themes` 1.1.0 instala os temas GTK portados em `/usr/share/themes`: Orchis-Light/Dark e Orchis-Square-Light/Dark compilados do SASS do fork com cantos de 12 px e 0 px, Skeuos-Blue-Light/Dark e suas variantes `-Square` geradas dos prebuilts originais fixados com raios de canto zerados (controles circulares mantêm a forma), além de Fluent-Light/Dark, Fluent-Square-Light/Dark, Jasper-Light/Dark e Jasper-Square-Light/Dark, dezesseis diretórios de tema no total. Os ports são publicados nos forks `rufl/skeuos-gtk`, `rufl/Orchis-theme`, `rufl/Fluent-gtk-theme` e `rufl/Jasper-gtk-theme` e fixados por commit em `distro/packages/dinx-gtk-themes/source.env`. O tema GTK DINX continua o padrão da sessão; as demais famílias são selecionadas pelo assistente de primeira execução e registradas em `~/.config/dinx/appearance.json`.

A DINX aplica a aparência salva pelo seu assistente de primeira execução, o `dinx-first-run`, que o supervisor roda antes do shell por meio de `/usr/local/libexec/dinx-desktop-first-run`, uma vez por conta atrás do marcador `~/.local/state/dinx/desktop-first-run-complete`. Ele pergunta idioma (pt-BR/en-US), localização (America/Sao_Paulo ou UTC), família de tema (DINX, Skeuos, Orchis, Fluent ou Jasper), variante escura ou clara, cantos arredondados ou quadrados, posição da barra (topo/base) e posição do dock (esquerda/direita/base/nenhum); em seguida grava `~/.config/dinx/appearance.json` e `~/.config/dinx/installer-preferences.json`, define a chave GSettings `navbar-anchor` do Morghulis e recarrega o dock via SIGHUP. O `dinx-river-session` exporta os defaults escuros de recuperação (`DINX_COLOR_SCHEME=dark`, `DINTOR_THEME=prefer-dark`), define `QT_QPA_PLATFORMTHEME=qt6ct`, não exporta mais `GTK_APPLICATION_PREFER_DARK_THEME` nem `ADW_DEBUG_COLOR_SCHEME`, e nunca força `GTK_THEME`, então os aplicativos mantêm sua própria seleção de tema. O helper `dinx-sync-session-theme` alinha os toolkits quando existe um barramento de sessão: mapeia a família, a variante e os cantos salvos sobre os nomes enviados em `/usr/share/themes`, por exemplo `Jasper-Square-Light`, e grava esse `gtk-theme-name` com a preferência clara/escura correspondente nas configurações GTK 3/4 do usuário, o esquema de cores `prefer-dark` ou `prefer-light` compatível no dconf e a paleta qt6ct DINX com `custom_palette=true` somente na variante escura, preserva configurações não relacionadas e semeia a mesma configuração/paleta Qt6ct em uma home existente que não as tenha; um `appearance.json` ausente ou inválido cai no DINX escuro. O `dinx-gtk-themes` substitui o accent bruto original pelo primário da paleta do port, para que o tema DINX e os temas portados compartilhem accents idênticos.

O agreety e a área de trabalho inicial usam fundos sólidos, sem imagem de wallpaper ou logo DINX; o Calamares mantém o wordmark completo no logo do produto e na tela de boas-vindas. O símbolo reduzido D com raio continua como arte-fonte em `design/brand/dinx-ray-mark.svg` e é usado pelo Calamares como ícone do produto. O GRUB usa o PNG separado do boot-mark em gradiente. Papirus é o único tema de ícones selecionado explicitamente para a área de trabalho e os lançadores; Qogir, o estilo Breeze e os cursores Breeze são excluídos. `breeze-icons` permanece somente como dependência transitiva de Calamares → KParts → KIO → KIconThemes, não como tema escolhido para a área de trabalho. Os ícones próprios dos aplicativos permanecem inalterados, e os recursos Adwaita continuam disponíveis para compatibilidade GTK.
A NavBar do Morghulis é a superfície de status da DINX; o kwm é compilado com `-Dbar=false`, então a barra do próprio KWM não é mais a superfície de status. O KWM lê somente `~/.config/kwm/config.zon`, e o `dinx-river-session` semeia esse arquivo a partir do `/etc/xdg/kwm/config.zon` empacotado quando ele não existe, para que edições do usuário sobrevivam a todos os reboots. O assistente de primeira execução guarda a seleção de tema de shell em `~/.config/dinx/appearance.json`, e o campo `dock` decide se o `dinx-dock` inicia: `none` deixa a barra de lançadores desligada, enquanto um arquivo ausente usa `left` por default.
O overlay da DINX distribui um `/etc/xdg/kwm/config.zon` que deixa todas as janelas
flutuando por padrão: `default_layout = .float` mais a regra global
`.{ .app_id = .{ .str = "", .match_null = true }, .floating = true }`, então todas as
janelas flutuam, empilham e podem ser arrastadas como a área de trabalho
Aqueous/Pearl retirada. `Mod4-f` alterna uma janela entre flutuante e o layout tile,
`Mod4-Ctrl-f` muda para o layout flutuante, `Mod4-t` volta ao tile, e
`Mod4`+arrastar-esquerda move / `Mod4`+arrastar-direita redimensiona janelas
flutuantes; `Mod4-Ctrl`+h/j/k/l desloca uma janela flutuante em direção a uma borda de
tela. O `dinx-river-session` semeia `~/.config/kwm/config.zon` a partir desse arquivo
apenas quando a configuração do usuário está ausente, para que edições do usuário
sobrevivam a todos os reboots.
>>>>>>> main
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

<<<<<<< HEAD
Morghulis, River/KWM e o instalador recebem defaults DINX pelo root overlay. O Calamares usa os tokens DINX versionados de superfície/texto/primário/erro no stylesheet Qt. O repositório DINX assinado é priorizado antes do Artix e o gate da ISO verifica o pacote DINX do Calamares.
O caminho live usa a sessão River/KWM/Morghulis sem prompt de credenciais: um serviço dinit exclusivo da live prepara o greetd antes de iniciá-lo. O rootfs instalado mantém login manual e o Calamares mantém os dois flags de autologin desativados.
No livefs, uma regra do PolicyKit autoriza ações privilegiadas via Polkit sem senha, exclusivamente para a sessão local e ativa do usuário `dinx`. Ela cobre lançadores como DinitUI, Calamares, GParted, Pori e Shelly. A regra não entra em `rootfs.img`; o sistema instalado mantém sua política normal de autenticação. Isso concede deliberadamente acesso equivalente a root a quem usa a sessão live descartável.

Os defaults global e do esqueleto GTK 3/4 usam Adwaita. O helper first-run do Morghulis salva a variante clara/escura, e o sincronizador reaplica a escolha em dconf, GTK 3/4 e Qt6ct a cada login, preservando configurações não relacionadas.
O helper first-run do Morghulis aplica imediatamente a escolha de tema salva; o sincronizador da sessão reaplica essa escolha no login.


O payload runtime é somente Wayland/XWayland: servidores, drivers legados de Xorg/XLibre e entradas de sessão do Plasma são omitidos. Xvfb permanece exclusivo do builder para qualificação de pacotes.
Para armazenamento, o Pori é o gerenciador DINX de discos/montagens e o PCManFM é o gerenciador de arquivos e desktop padrão. O File Roller fornece ações gráficas para arquivos compactados e o GParted fornece particionamento independente fora do Calamares. O Pori usa UDisks2 e cria serviços de montagem persistentes em `/etc/dinit.d`; não usa unidades systemd. A imagem base não instala Thunar, GVFS, Tumbler nem KDE Partition Manager.
Para displays, o wrapper DINX `dinx-wdisplays` abre o editor Wayland; ao fechar, substitui atomicamente o perfil `DINX wdisplays` em `~/.config/shikane/config.toml` e recarrega o daemon Shikane. O Shikane inicia em River/KWM/Morghulis e reaplica perfis correspondentes. `Mission Center` e `Seafoam Settings` fazem parte da ISO base e do repositório DINX assinado; o ZLS está disponível pelo canal opcional. Mission Center fornece monitoramento GTK4 de recursos/processos.
O Turnstile rastreia sessões PAM e inicia o gerenciador de serviços Dinit por usuário através do greetd. A DINX mantém o elogind para integração de seat e polkit; por isso o Turnstile é compilado com `manage_rundir=false` e não assume `/run/user/$UID`.

Para navegação web, o perfil instala o release oficial x86_64 do Floorp, fixado por checksum, como manipulador padrão de HTML/XHTML/HTTP/HTTPS. As políticas gerenciadas em `/usr/lib/floorp/distribution/policies.json` desativam superfícies patrocinadas, telemetria, recomendações, alguns recursos de IA e o atualizador interno do Floorp. Os pins do Floorp são mantidos pelo fluxo revisado de atualização de pacotes DINX; entrar em uma conta Mozilla continua opcional.
O perfil também inclui btop/nvtop/inxi, diagnóstico PCI e USB, Git/curl/less/jq/rsync, ONLYOFFICE para documentos, planilhas, apresentações e PDFs, Swayimg, Haruna, Gapless (G4Music), Galculator, `wl-clipboard`, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor`, o backend SANE `scanimage`, `fwupdmgr`, o runtime Flatpak, Impasto, Krita, Inkscape, Godot, Pixelorama e Patchy. Impasto, Krita, Inkscape e Pixelorama oferecem edição gráfica raster; Godot é uma engine de jogos. Impasto e Patchy são AppImages upstream com versões e avisos de licença fixados por checksum, preservados byte a byte e iniciados com `--appimage-extract-and-run` sem exigir FUSE. Pixelorama usa o release Linux x86_64 oficial com checksum fixado, wrapper, entrada desktop, ícone, licença MIT e registro MIME `.pxo`. Galculator é uma calculadora compacta em GTK 3 que usa a pilha GTK existente, sem adicionar outro toolkit gráfico. Gapless é compilado da versão upstream v4.6.2 fixada, com codecs GStreamer base/good e reprodução sem intervalos ativada por padrão. Ele oferece controles de mídia MPRIS. O Swayimg é compilado a partir da fonte upstream 5.6 fixada, com Wayland, JPEG e PNG, e continua sendo o visualizador padrão. Morghulis é dono das superfícies ativas e as bridges DINX são estáticas; nenhum plugin ou asset privado de shell é necessário. Nenhum aplicativo Flatpak é pré-instalado.
=======
O agreety, a sessão River/KWM e o instalador recebem defaults DINX pelo root overlay. O Calamares usa os tokens DINX de superfície/texto/primário/erro no stylesheet Qt. A DINX compila o Calamares 3.4.3 de um release upstream fixado por checksum, sem a dependência Artix `plasma-integration`. O repositório DINX assinado é priorizado antes do Artix durante a resolução do rootfs, e o gate da ISO verifica que o pacote DINX do Calamares foi selecionado. `breeze-icons` continua necessário por Calamares → KParts → KIO → KIconThemes; isso não instala a sessão Plasma, seu workspace nem o portal KDE. O River é o compositor ativo e o KWM o gerenciador de janelas ativo; não existe host de greeter dedicado nem fallback de sessão do usuário. Entradas de sessão não suportadas continuam ocultas e `River + KWM + Morghulis (DINX)` é a sessão live. A sessão live expõe `Instalar DINX` por um launcher próprio. O root overlay substitui o `/usr/share/applications/calamares.desktop` do pacote por um tombstone `Hidden=true`, `NoDisplay=true`, sem nome Artix nem executável. O helper DINX inicia o Calamares via `pkexec`, preservando o runtime/display Wayland da sessão live e exibindo erros de inicialização/autorização em uma janela. O atalho da área de trabalho live é executável desde o primeiro boot, e o wrapper da sessão preenche o estado de aprovação de launchers da DINX somente para a URI e o SHA-256 exatos do atalho pertencente ao pacote; arquivos modificados e symlinks continuam sem aprovação.
O caminho live usa `River + KWM + Morghulis (DINX)` sem prompt de credenciais: um serviço dinit exclusivo da live prepara a sessão e o greetd permanece somente instalado. O rootfs instalado mantém login manual via agreety e o Calamares mantém os dois flags de autologin desativados.
No livefs, uma regra do PolicyKit autoriza ações privilegiadas via Polkit sem senha exclusivamente para o usuário descartável fixo `dinx`. O início direto pelo Dinit não possui estado de sessão `active` ou `local` do elogind, portanto a regra deliberadamente não depende desses flags. Ela cobre a execução root do Calamares e GParted, a configuração do Firewalld via D-Bus e outras ferramentas administrativas da live. O GParted usa seu launcher Polkit upstream; o firewall-config permanece uma interface sem privilégios e autoriza mudanças pelo Firewalld. A regra não entra em `rootfs.img`; o sistema instalado mantém sua política normal de autenticação. Isso concede deliberadamente acesso equivalente a root a quem usa a sessão live descartável.

Os defaults global e do esqueleto GTK 3/4 usam Adwaita com `gtk-application-prefer-dark-theme=1`, o tema de ícones Papirus, Noto Sans 10 e o layout de decoração `:minimize,maximize,close`. O helper `dinx-sync-session-theme` aplica ao dconf, às configurações GTK 3/4 do usuário e ao Qt6ct, acima desses defaults, a aparência salva: o `gtk-theme-name` escolhido no assistente de primeira execução, DINX quando nada foi salvo, a preferência clara/escura do GTK e a paleta Qt DINX na variante escura. Configurações de toolkit não relacionadas são preservadas e um symlink gerenciado pelo usuário nunca é substituído. Janelas que negociam decorações do servidor recebem a titlebar DINX do compositor; clientes que mantêm decorações próprias não são decorados duas vezes. O supervisor da sessão inicia o KWM como implementação obrigatória de `river-window-management-v1` antes de qualquer view ser mapeada, então o posicionamento pertence ao river/KWM e não existe configuração de raio de canto nem de sincronização de bordas no compositor.


O payload runtime é somente Wayland/XWayland: servidores, drivers legados de Xorg/XLibre e entradas de sessão do Plasma são omitidos. Xvfb permanece exclusivo do builder para qualificação de pacotes.
Para armazenamento, o Pori é o gerenciador DINX de discos/montagens e o PCManFM é o gerenciador de arquivos padrão. O File Roller fornece ações gráficas para arquivos compactados e o GParted fornece particionamento gráfico independente fora do Calamares. O Pori usa UDisks2 para descobrir dispositivos de bloco e cria serviços de montagem persistentes scriptados em `/etc/dinit.d`; ele não usa unidades systemd. A imagem base não instala Thunar, GVFS, Tumbler nem KDE Partition Manager. O PCManFM cuida da navegação de diretórios e renderiza os ícones de `~/Desktop` via `pcmanfm --desktop`; o agente independente de PolicyKit do LXQt continua disponível para ações privilegiadas, e a sessão River/KWM continua sendo o desktop ativo.
Para configuração de displays, o wrapper DINX `dinx-wdisplays` abre o editor interativo de saídas Wayland; ao fechar, ele substitui atomicamente o perfil `DINX wdisplays` em `~/.config/shikane/config.toml` e recarrega o daemon de usuário Shikane. O Shikane inicia dentro da sessão River/KWM e reaplica perfis correspondentes quando as saídas mudam. A ação `Display` da DINXPanel abre esse mesmo wrapper, e o `dinx-save-shikane-profile` salva o layout atual sem reabrir o editor. River e KWM são os únicos componentes selecionáveis da sessão.

Para navegação web, o perfil instala o pacote `firefox` do Artix e o define como manipulador padrão de HTML/XHTML/HTTP/HTTPS. As atualizações do Firefox vêm das fontes de pacotes do Artix por meio do fluxo revisado de atualização de fontes de pacotes; a DINX não distribui arquivo de políticas do navegador e entrar em uma conta Mozilla continua opcional.
O perfil também inclui btop/nvtop/inxi, diagnóstico PCI e USB, Git/curl/less/jq/rsync, Swayimg, Haruna, Gapless (G4Music), Galculator, `wl-clipboard`, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor`, `fwupdmgr`, o runtime Flatpak, PCManFM, Octopi, `pacman-contrib`, PaintFE, Krita, Inkscape, Godot, Pixelorama, Patchy, Blender (suíte de criação 3D), Audionaut (editor e gravador de áudio multifaixa) e EuroOffice (documentos, planilhas, apresentações e PDFs; handler padrão de `application/pdf` e OOXML). Krita, Inkscape, Pixelorama e PaintFE oferecem edição gráfica raster e vetorial; Godot é uma engine de jogos e Blender é a suíte de criação 3D. PaintFE e Patchy são AppImages upstream com versões fixadas por checksum, reempacotados no build em árvores `/opt/<pacote>/` pré-extraídas (ELF com strip onde seguro, locales reduzidos a en/pt) cujos launchers `/usr/bin/<pacote>` executam `AppRun` diretamente, sem exigir FUSE nem extração em tmpfs por inicialização; o Audionaut é um AppImage upstream fixado por checksum mantido como um único `/opt/audionaut/Audionaut.AppImage` que seu launcher `/usr/bin/audionaut` executa com `--appimage-extract-and-run`, e o Blender e o PCManFM vêm dos repositórios do Artix; o EuroOffice chega como pacote pacman lean verificado por SHA256 mais squashfs live com raiz /, publicados pela branch office. PaintFE traz o texto MIT upstream; o Patchy traz seu texto MIT upstream e o Audionaut traz o `LICENSE.md` upstream. Cada pacote também carrega um registro de proveniência `usr/share/doc/<pacote>/SOURCE` com a árvore upstream fixada; PaintFE e Pixelorama instalam o ícone de aplicativo 256x256 upstream. O gate de conteúdo da ISO exige esses caminhos de licença e ícone; cada receita ainda grava o registro de proveniência `usr/share/doc/<pacote>/SOURCE`, que o wrapper do squashfs remove das imagens finais junto com o restante de `usr/share/doc`. O Patchy define sua própria preferência Qt de esquema de cores como escuro no primeiro uso, preservando escolhas de tema posteriores do usuário. Pixelorama usa o release Linux x86_64 oficial com checksum fixado, wrapper, entrada desktop, ícone, licença MIT e registro MIME `.pxo`. Galculator é uma calculadora compacta em GTK 3 que usa a pilha GTK existente, sem adicionar outro toolkit gráfico. Gapless é compilado da versão upstream v4.6.2 fixada, com codecs GStreamer base/good e reprodução sem intervalos ativada por padrão. Ele oferece controles de mídia MPRIS. O Swayimg é compilado a partir da fonte upstream 5.6 fixada, com Wayland, JPEG e PNG, e continua sendo o visualizador padrão. River/KWM não exige plugin de shell nem asset privado; as bridges DINX estáticas carregam a aparência. Nenhum aplicativo Flatpak é pré-instalado. Os payloads aposentados OnlyOffice, Zrythm, Impasto, Floorp, Topgrade e ArtCraft (WordCraft/GridCraft/DeckCraft/PdfCraft) são rejeitados pelo gate de conteúdo.
>>>>>>> main

### Nomes dos launchers

Os nomes seguem o idioma do desktop. O Swayimg permanece oculto no menu de aplicativos e abre arquivos de imagem associados. O desktop ID original do Calamares/Artix é substituído por um tombstone inerte; somente o atalho funcional do instalador DINX é exposto.

| Aplicativo | English | Português (Brasil) |
| --- | --- | --- |
<<<<<<< HEAD
| Mission Center | System Monitor | Monitor do Sistema |
=======
>>>>>>> main
| DinitUI | Services | Serviços |
| DINXPanel | Control Center | Central de Controle |
| Dintor | Editor | Editor |
| Pori | Disks & Mounts | Discos e Montagens |
<<<<<<< HEAD
| PCManFM | Files & Desktop | Arquivos e Desktop |
=======
| PCManFM | File Manager | Gerenciador de Arquivos |
>>>>>>> main
| Configuração de display | Display Settings | Ajustes de Tela |
| Octopi | Add/Remove Software | Adicionar/remover programas |
| Galculator | Calculator | Calculadora |
| GParted | Partition Editor | Particionador |
| PaintFE | Image Editor | Editor de Imagens |
| Firefox | Web Browser | Navegador Web |
| Krita | Digital Painting | Pintura Digital |
| Inkscape | Vector Graphics | Gráficos Vetoriais |
| Godot | Game Engine | Motor de Jogos |
| Pixelorama | Pixel Art & Animation | Arte de Pixel e Animação |
| Patchy | Image Editor | Editor de Imagens |
<<<<<<< HEAD
=======
| Blender | 3D Modeler | Modelador 3D |
>>>>>>> main
| Swayimg | Image Viewer | Visualizador de Imagens |
| EuroOffice | Office & PDF Editors | Suíte de Escritório e PDF |
| Audionaut | Audionaut | Audionaut |
| Gapless | Music Player | Tocador de Música |
| Haruna | Media Player | Tocador de Mídia |
| Blueman | Bluetooth | Bluetooth |
| Conexões de rede | Network Connections | Ajustes de Rede |
| pwvucontrol | Audio Control | Ajustes de Áudio |
| File Roller | Archive Manager | Descompactador |
| Instalador DINX | Install DINX | Instalar DINX |
| Configuração de Firewall | Firewall | Firewall |

O payload de gerenciamento adiciona `paru`, o Octopi e o `pacman-contrib` ao lado do `pacman` do próprio Artix. paru é compilado a partir do release fonte fixado contra o ALPM do Artix; o Octopi é compilado do release upstream fixado por tag e eleva por `pkexec` e polkit com o `lxqt-policykit-agent`, porque a DINX não envia sudo, e o `pacman-contrib` fornece o `checkupdates` para descoberta somente leitura de atualizações. O Octopi não tem interface de linha de comando: é a GUI interativa aberta pelo botão `Package manager` da DINXPanel e pelo dock. Os metadados não têm dependência ou unidade `systemd`, nenhum repositório Arch é adicionado e receitas AUR continuam sujeitas a revisão. Nenhum deles inicia automaticamente no boot.
Para gaming, o grupo `gaming` tem `iso:false`; Gamescope, Steam, regras de dispositivos Steam, GameMode, MangoHud e bibliotecas de 32 bits ficam fora do rootfs/livefs base. O perfil base mantém firmware AMDGPU e Intel, Mesa RADV e ferramentas Vulkan de 64 bits. O P0 não habilita mais o repositório Artix `[lib32]` para montar a ISO; o usuário pode optar por habilitá-lo depois da instalação seguindo o [`guia de instalação`](../../docs/pt-BR/install.md). Nenhum repositório Arch é adicionado.
Os firmwares AMDGPU e Intel, Mesa RADV e as ferramentas Vulkan permanecem no perfil base como suporte gráfico genérico. O governor Cyan Skillfish exclusivo da BC-250, seu pacote dinit e o BC250 Control Center não são instalados na raiz live nem na raiz instalada genéricas. O CI mantém os pacotes fixados no repositório DINX assinado.
Instale esses pacotes somente após `lspci -n -d 1002:13fe` confirmar o dispositivo; configure o repositório DINX assinado e siga as etapas protegidas em [`docs/pt-BR/install.md`](../../docs/pt-BR/install.md).
O pacote do governor instala o runtime correspondente e usa dinit; seu wrapper aplica os limites configurados somente ao PCI `1002:13fe`. Use um kernel Artix com as correções upstream atuais da BC-250 (6.17.11 ou mais novo; prefira o kernel LTS do Artix). A raiz compacta da ISO inclui firmware AMDGPU e Intel para suporte gráfico geral, mas omite o bundle genérico `linux-firmware` e o `powertop`; mantém os headers necessários para gerar o initramfs do Artix e exclui a árvore de fontes do SquashFS final.
<<<<<<< HEAD
O payload de firewall inclui Firewalld, firewall-config e OpenSnitch. Firewalld e o daemon OpenSnitch usam serviços Dinit separados nos root filesystems live e instalado; o autologin live aguarda a tentativa do Firewalld, mas continua se ela falhar. A interface OpenSnitch inicia em segundo plano/tray e usa nftables com `DefaultAction=allow` e `InterceptUnknown=false`.

A DINXPanel é dona das ações visíveis de hardware e drivers, atalhos fixos, fluxos Shelly/Topgrade, descoberta opcional do fwupd e instalador seguro de kernels Artix. River/KWM/Morghulis não exige plugin de shell.
O caminho dedicado de login `agreety` fornece a superfície do greetd. River/KWM/Morghulis é a sessão base do usuário.
### Segurança da sessão, hierarquia e guarda de recursos

A sessão live usa `swayidle` e `wlopm` para desligar todas as telas após 600 segundos sem atividade e antes da suspensão, restaurando-as com atividade ou ao retomar. A sessão River live não expõe uma ação de bloqueio; as sessões instaladas mantêm o `swaylock` para inatividade e suspensão, com bloqueio explícito por `dinx-lock`, `Super+L` e DINXPanel. As teclas padrão de brilho usam passos fixos de 5% com `brightnessctl`.
=======
O payload de firewall inclui Firewalld e firewall-config. O Firewalld usa um serviço Dinit habilitado nos root filesystems live e instalado; o autologin live aguarda a tentativa de inicialização do Firewalld, mas continua mesmo se ela falhar. A regra PolicyKit exclusiva da live permite que firewall-config gerencie o Firewalld sem senha; o sistema instalado mantém a autenticação normal do Firewalld. O Firewalld é o mecanismo de filtragem da imagem. UFW, Gufw e Portmaster não são distribuídos.

O DinitUI instala perfis de serviços de sistema `normal`, `lite` e `gaming` e permite perfis customizados em `~/.config/dinx/dinitui/profiles.conf`. `lite` desabilita somente o Bluetooth opcional; Gaming habilita Bluetooth para controles. Os perfis integrados não alteram o Firewalld. O launcher standalone entra no Gaming e restaura o perfil anterior ao sair; falhas de entrada ou restauração interrompem o launcher e permanecem visíveis. A DINXPanel é dona das ações visíveis de hardware e drivers, dos atalhos fixos, do relatório somente leitura de upgrades via `checkupdates`/`paru -Qu`, dos atalhos de gerenciador de pacotes Octopi e de lançamento do PaintFE, da descoberta opcional do fwupd e do instalador seguro de kernels Artix; River/KWM não exige plugin de shell.
O agreety sob o greetd fornece a interface de login instalada e inicia a sessão por `/usr/local/libexec/dinx-river-session`. River/KWM é a única sessão do usuário.
### Segurança da sessão, hierarquia e guarda de recursos

A sessão live usa `swayidle` e `wlopm` para desligar todas as telas após 600 segundos sem atividade e antes da suspensão, restaurando-as com atividade ou ao retomar. O `dinx-lock` recusa bloquear a sessão live e o launcher de bloqueio da área de trabalho fica oculto para o usuário live, porque um seat descartável bloqueado é irrecuperável sem reboot. As sessões instaladas mantêm o `swaylock` para bloqueio por inatividade e suspensão, com bloqueio explícito por `dinx-lock` e pela DINXPanel. As teclas padrão de brilho e a DINXPanel usam passos fixos de 5% com `brightnessctl`; ferramentas especializadas permanecem no launcher.
>>>>>>> main

`scripts/check_dinx_budget.sh` mantém o perfil atual em 120 de 128 entradas de pacotes rootfs e no máximo 23 entradas de inicialização dinit, limita os binários compilados da DINXPanel/DinitUI a 6 MiB cada, limita a janela de qualificação de boot QEMU a 120 segundos e exige que uma ISO construída fique abaixo de 2 GiB (`2147483647` bytes) quando `DINX_ISO_PATH` é fornecido. Passar no limite de contagem de pacotes não garante passar no limite de tamanho da ISO; o artefato final deve passar ambos. Esses limites são barreiras de regressão, não medições de desempenho em hardware. `scripts/measure_dinx_session.sh` registra snapshots de RSS/CPU via `/proc` quando uma sessão DINX está realmente em execução.

O builder Artix ainda consome um único `profile.yaml`; o manifesto de grupos é um contrato, não um mecanismo de composição de pacotes. O perfil da ISO genérica contém os grupos foundation e desktop, enquanto gaming e pacotes específicos da BC-250 ficam fora da imagem base. As políticas de serviço Normal/Lite/Gaming do DinitUI continuam separando serviços em runtime.

<<<<<<< HEAD
O gate de conteúdo do P0 exige que as imagens SquashFS do root e da sessão live contenham o compositor, Morghulis, greetd, sessão River/KWM, Deetty como único emulador de terminal, Nano, Pori, PCManFM como gerenciador de arquivos/desktop, suporte `ntfs3`, backend SANE, fwupd, runtime Flatpak, Mission Center e o payload gráfico e dinit esperado. Ele rejeita binários e metadata dos pacotes gaming opcionais nas duas imagens. Os contratos ativos de pacote e sessão verificam esses requisitos antes do build.
=======
O gate de conteúdo do P0 exige que as imagens SquashFS do root e da sessão live contenham o compositor, shell, greeter, sessão e Deetty como único emulador de terminal, além do editor de recuperação Nano, do gerenciador de armazenamento Pori com dinit, do gerenciador de arquivos PCManFM, do suporte `ntfs3` de leitura/escrita, das ferramentas de firmware fwupd, do runtime Flatpak, dos aplicativos gráficos PaintFE, Krita, Inkscape, Godot, Patchy, Blender e Audionaut, da suíte de escritório/PDF EuroOffice, do Octopi, do Firefox e do payload dinit esperado. Ele rejeita binários, launchers e metadata de pacote do KolourPaint, os payloads aposentados OnlyOffice/Zrythm/Impasto/Floorp/Topgrade/ArtCraft, e binários e metadata dos pacotes gaming opcionais, nas duas imagens. `scripts/check_desktop_packages.sh` e `scripts/check_pori_storage.sh` verificam contratos de pacote/perfil antes do build. `scripts/smoke-install.sh` executa o contrato offline em discos BIOS/UEFI efêmeros, verifica o primeiro boot dinit e habilita as TTYs de recuperação. A captura PPM do workflow é evidência visual para inspeção, não qualificação de hardware arbitrária.
>>>>>>> main

O check de bibliotecas de runtime da instalação cobre aplicativos dinamicamente ligados. O release upstream do ZLS, fixado por checksum, é estático; o smoke verifica sua versão e a configuração selecionada dentro do chroot alvo.

O gate de sessão live do P0 exige `AUTOLOGIN=true`, o serviço dinit de autologin exclusivo da live e a fronteira inalterada do greeter do sistema instalado.

<<<<<<< HEAD
O smoke do disco instalado em BIOS/UEFI exige uma superfície `agreety` legível com entrada e senha; logs de serviços ativos e framebuffer válido não bastam para qualificar o login.

O contrato de payload exige `wdisplays`, `shikane`, Mission Center e os pontos de entrada DINX de persistência de display. As fontes são fixadas e verificadas como parte do payload base da ISO.

O workflow armazena uma captura separada `dinx-boot-screen.ppm`, feita antes do envio das teclas do menu de boot. Esse quadro deve ser revisado ao qualificar a superfície GRUB de seleção do kernel; ele é a evidência de regressão do painel opaco removido.

O GRUB usa o símbolo compacto D com raio, transparente, junto às cores DINX de superfície, primeiro plano e seleção primária no lugar do logo Artix; as fontes Artix continuam em uso. As texturas opacas do menu ficam desativadas. Morghulis e a área de trabalho inicial usam fundos sólidos, sem imagem de wallpaper ou logo DINX; o Calamares mantém o wordmark completo e o símbolo compacto como ícone do produto. Papirus é o único tema de ícones explicitamente selecionado; Qogir e temas/estilos KDE Breeze são excluídos quando não necessários ao Calamares.
=======
O smoke do disco instalado em BIOS/UEFI também exige que a captura da tela mostre a identidade de sessão do agreety junto com um controle de entrada e um campo `Password`; logs de serviços ativos e framebuffer válido não bastam para qualificar o login.

O contrato de payload também exige `wdisplays`, `shikane` e os pontos de entrada DINX de persistência de display. A fonte externa do ZLS é fixada; o shikane é compilado do release upstream fixado por tag. Ambos são obrigatórios e verificados como parte do payload base da ISO.

O workflow armazena uma captura separada `dinx-boot-screen.ppm`, feita antes do envio das teclas do menu de boot. Esse quadro deve ser revisado ao qualificar a superfície GRUB de seleção do kernel; ele é a evidência de regressão do painel opaco removido.

O GRUB usa o símbolo compacto D com raio, transparente, junto às cores DINX de superfície, primeiro plano e seleção primária no lugar do logo Artix; as fontes Artix continuam em uso. As texturas opacas do menu ficam desativadas. O agreety e a área de trabalho inicial usam fundos sólidos, sem imagem de wallpaper ou logo DINX; o Calamares mantém o wordmark completo no logo/boas-vindas e o símbolo compacto como ícone do produto. Papirus é o único tema de ícones explicitamente selecionado para os lançadores; Qogir e os temas/estilos KDE Breeze são excluídos. Os ícones dos aplicativos permanecem upstream, e os recursos Adwaita continuam disponíveis para compatibilidade GTK.
>>>>>>> main
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
