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
Teste o contrato de instalação persistente em um disco BIOS descartável:

```bash
DINX_INSTALL_OUTPUT_DIR=dist/iso/dinx \
scripts/smoke-install.sh dist/iso/<arquivo>.iso
```

O script extrai o rootfs da ISO, remove os pacotes exclusivos da sessão live, cria
um disco ext4 temporário, gera initramfs e GRUB BIOS, inicializa o disco no QEMU e
captura a transição para a TTY de recuperação. Ele exige root ou `sudo` sem senha,
loop devices, `grub-pc-bin`, QEMU e ferramentas SquashFS. O disco é apagado ao fim
do smoke; isso não substitui a qualificação em hardware.


A execução remota também captura a superfície VGA do QEMU pelo monitor. Para solicitar a mesma evidência localmente:

```bash
DINX_QEMU_BOOT_KEYS=down,down,ret \
DINX_QEMU_SCREENSHOT=dist/iso/dinx/tela-grafica.ppm \
DINX_QEMU_SCREENSHOT_DELAY=60 \
scripts/smoke-iso.sh dist/iso/<arquivo>.iso
```


Verifique o payload gráfico dentro da imagem SquashFS do root:

```bash
scripts/check-iso-content.sh dist/iso/<arquivo>.iso
```

Opções adicionais do `buildiso` são repassadas sem alteração. Por exemplo, para consultar as configurações sem executar o build:

```bash
scripts/build-iso.sh -q
```

O diretório de saída padrão é `dist/iso`; ele pode ser alterado com `DINX_ISO_OUTPUT`. O cache de chroots padrão é `/var/lib/artools/buildiso`; altere-o com `DINX_ISO_CHROOTS` quando o builder usar outro volume persistente.

## Perfil gráfico

`iso-profiles/dinx/profile.yaml` agora inclui MangoWM, Scenefx, Noctalia, greetd, ReGreet e o pacote nativo `noctty`. O pacote `noctty` instala NOCTTY e NoctEd, incluindo os arquivos desktop, ícones, especificações de linguagem e o estilo escuro do editor. O CI consome o archive versionado gerado a partir do commit exato do repositório NOCTTY e do contrato SHA-256 declarados em `distro/packages/noctty/source.env`; MangoWM e Scenefx são compilados a partir de arquivos de release upstream fixados em `distro/packages`. O workflow publica todos os pacotes customizados em um repositório pacman local temporário antes de chamar o `buildiso`. O `root-overlay` do perfil fornece a configuração do greetd, as ações do ReGreet, as sessões MangoWM, o autostart do Noctalia, um override no-op exclusivo da sessão live para o serviço dinit `root-ro` e um wrapper do Mango que habilita renderização por software somente quando o guest não possui um render node DRM.

O perfil também controla um override DINX do tema GRUB em `iso-profiles/dinx/root-overlay/usr/share/grub/themes/artix/theme.txt`. Ele mantém o fundo, o logo, os ícones e a fonte fornecidos pelo Artix, mas remove as texturas opacas do painel/menu que apareciam como um quadrado preto na seleção gráfica do kernel. A verificação de conteúdo exige esse arquivo dentro do SquashFS do root.

O perfil agora inclui o instalador experimental Calamares e o KDE Partition Manager. O Calamares copia o root filesystem da ISO sem rede, mantém o dinit como init instalado e remove os pacotes exclusivos da sessão live durante a instalação. O KDE Partition Manager fica disponível como particionador gráfico separado para inspecionar ou preparar os discos antes de abrir o instalador. As duas ferramentas podem destruir dados; confirme sempre o dispositivo selecionado.

O greeter e o Noctalia recebem defaults de modo escuro pelo `root-overlay`. O Noctalia inicia com animações e transparência de painéis/janela de configurações desativadas, mas a interface de Settings pode alterar esses defaults depois. O Mango inicia com dois desktops virtuais; edite `~/.config/mango/config.conf` e altere `tag_num` para adicionar mais. A cadeia de dependências do Calamares mantém componentes do Plasma para o instalador, mas as entradas de sessão Plasma X11 e Wayland não suportadas ficam ocultas no greeter da DINX, deixando o MangoWM como sessão live. O Calamares usa branding DINX e um stylesheet Qt escuro. A sessão live expõe `Instalar DINX` no launcher; o particionador separado aparece como `KDE Partition Manager`.
Para armazenamento removível, o perfil inclui Thunar, `thunar-volman`, GVFS, UDisks2, File Roller pelo `thunar-archive-plugin`, Nano e o agente independente de PolicyKit do LXQt. O Thunar é executado como processo de monitoramento de volumes dentro da sessão Mango; apenas o gerenciador de arquivos é instalado, não o desktop Xfce. A sessão usa D-Bus, elogind e dinit, sem dependência de systemd. O Thunar é o manipulador padrão de `inode/directory`; o Noctalia continua sendo o shell do desktop, e nenhum `xfdesktop`, sessão Xfce ou sessão completa do LXQt é instalada.

Para navegação web, o perfil instala Firefox e o torna o manipulador padrão de HTML/XHTML/HTTP/HTTPS. A política de sistema em `/etc/firefox/policies/policies.json` desativa superfícies patrocinadas da Nova Aba e do Firefox Suggest, Pocket/Stories, Firefox Studies/telemetria, recomendações do navegador, superfícies de assistente de IA/preview de links/grupos de abas e o IP Protection integrado. Firefox Accounts continua sendo uma escolha explícita do usuário: a DINX não exige login nem exibe onboarding, enquanto as atualizações normais do navegador continuam habilitadas.
O perfil também inclui btop/nvtop/inxi, diagnóstico PCI e USB, Git/curl/less/jq/rsync, Zathura com backend MuPDF como manipulador normal de PDF, Swayimg, VLC com seus componentes GUI Qt/CLI, Strawberry, `wl-clipboard`, pwvucontrol, BlueZ/Blueman/UPower e `nm-connection-editor`. O Swayimg é compilado a partir da fonte upstream 5.6 fixada, com suporte a Wayland, JPEG e PNG. Os widgets de Rede, Bluetooth, Volume, Bateria, Captura de tela e Clipboard do Noctalia são as superfícies principais do shell; os editores e players independentes continuam disponíveis no launcher. O Noctalia continua sendo o caminho primário de captura; dependências transitivas dos pacotes Artix também podem fornecer `grim` e `slurp`, enquanto `wl-copy`/`wl-paste` continuam disponíveis para fluxos de CLI.
O payload de gerenciamento adiciona `topgrade`, `paru` e Shelly. Topgrade usa um binário de release upstream fixado com a configuração `pacman` do Artix da DINX; paru é compilado a partir do release fonte fixado contra o ALPM do Artix; o Shelly delega para a configuração `pacman` do Artix. Os metadados não têm dependência ou unidade `systemd`, nenhum repositório Arch é adicionado e receitas AUR continuam sujeitas a revisão. Nenhum deles inicia automaticamente no boot.
Para hardware AMD Cyan Skillfish, como a BC-250, o perfil adiciona firmware AMDGPU, Mesa RADV e ferramentas Vulkan do Artix, além do governor SMU fixado. O serviço dinit é ligado nas raízes live e instalada, detecta PCI `1002:13fe`, aplica a configuração conservadora de 1000-1850 MHz e não altera outros hardwares. É um caminho automático via dinit, não um serviço systemd; use um kernel Artix com as correções upstream atuais da BC-250 (6.17.11 ou mais novo; prefira o kernel LTS do Artix).
O perfil também fornece o BC250 Control Center v1.21.1 a partir de um archive fonte MIT com SHA-256 fixado. A GUI, a CLI, a política polkit e o daemon headless ficam disponíveis no launcher e no dock; o Mango inicia o daemon na sessão do usuário autenticado com `exec_once`. A DINX remove a unidade de usuário systemd e o drop-in systemd do Cyan upstream, portanto essa integração não adiciona serviço systemd nem serviço root dinit. No dinit, a persistência de serviços upstream é somente detecção; a telemetria BC-250 ao vivo continua sendo o caminho de background suportado.
O payload de firewall/processos adiciona UFW com os arquivos de serviço `ufw-dinit` do Artix, a GUI Gufw, daemon/UI do OpenSnitch com serviço dinit da DINX e o Qps. Os serviços UFW e OpenSnitch são instalados, mas não são ligados ao boot por padrão: configure as regras e habilite deliberadamente a política de firewall desejada. Não habilite os dois gerenciadores de regras sem revisar o ruleset netfilter resultante.
O Mango abre novos aplicativos como janelas flutuantes por padrão, com `Super+Space` como alternância por janela. A barra `main` do Noctalia reserva a borda superior, e o dock reserva a borda inferior.

A verificação de conteúdo prova que as imagens SquashFS do root e da sessão live contêm os payloads esperados do compositor, shell, greeter, sessão, terminal fallback, editor de recuperação Nano, integração de arquivos compactados File Roller/Thunar e dinit. `scripts/smoke-install.sh` também executa o contrato offline em um disco BIOS efêmero, verifica o primeiro boot dinit e habilita as TTYs de recuperação. A captura PPM do workflow é evidência visual para inspeção, não uma qualificação de hardware arbitrário.

O workflow armazena uma captura separada `dinx-boot-screen.ppm`, feita antes do envio das teclas do menu de boot. Esse quadro deve ser revisado ao qualificar a superfície GRUB de seleção do kernel; ele é a evidência de regressão do painel opaco removido.

## Limite do perfil

O perfil usa o manifesto comum de pacotes do Artix fornecido pelo pacote `iso-profiles` instalado e adiciona localmente as entradas específicas da DINX. `WORKSPACE_DIR` em `scripts/build-iso.sh` torna determinística a seleção do perfil.

## Validação do build

Um build de imagem bem-sucedido não é o critério de release. A ISO resultante exige:

1. geração de checksum;
2. validação do conteúdo SquashFS;
3. smoke test de boot e instalação em VM;
4. verificação da TTY de recuperação;
5. verificações de rede, áudio, D-Bus, portal e gráficos;
6. relatório de instalação/atualização antes de ser rotulada como alpha.
