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
## Meta de tamanho da ISO

O wrapper do build coloca `scripts/iso-tools/mksquashfs` no início do `PATH`
do builder. Ele força imagens SquashFS com o preset xz suportado pela ferramenta, BCJ x86,
blocos de 256 KiB e dicionário de 256 KiB. Fontes do kernel, caches de pacotes pacman e logs de
build ficam fora da imagem final; o `squashfs-tools` exclusivo do build permanece no ambiente
do builder, não no payload de runtime. O CI também instala o wrapper em `/usr/bin/mksquashfs`
depois de preservar o binário real, porque o `buildiso` do Artix pode invocar esse caminho
absoluto diretamente. O contrato pós-build da ISO inspeciona os superblocos das duas imagens
SquashFS e rejeita qualquer imagem que não use xz com blocos de 256 KiB. O orçamento P0 rejeita
uma ISO construída com tamanho igual ou maior que o limite de 2 GiB por asset do GitHub; a Alpha
9 atende a essa meta com uma ISO direta de 2.008.801.280 bytes.

## Perfil gráfico

`iso-profiles/dinx/profile.yaml` inclui Aqueous, Pearl, greetd e o pacote nativo `noctty`. O pacote Pearl fornece o Pearl Greeter; o pacote `noctty` instala NOCTTY e NoctEd, incluindo arquivos desktop, ícones, especificações de linguagem e o estilo escuro do editor. O CI consome o archive versionado gerado a partir do commit exato do repositório NOCTTY e do contrato SHA-256 em `distro/packages/noctty/source.env`. O root overlay fornece `/etc/greetd/config.toml`, `/etc/pearl/greeter.json` e metadados de sessão oculta; Aqueous + Pearl é a única entrada de sessão do usuário.
O livefs adiciona o pacote dinit `dinx-live-autologin`, exclusivo da sessão live. Ele habilita o `initial_session` de uma execução do greetd para `dinx` com Aqueous + Pearl sem alterar a configuração do rootfs instalado; se essa sessão terminar, o host padrão do Pearl Greeter no greetd é o fallback.

`iso-profiles/dinx/feature-groups.json` registra os grupos foundation, desktop, gaming, hardware e opcional sem substituir o `profile.yaml` do Artix. O builder do CI assina cada pacote customizado e o banco temporário do repositório `dinx` com uma chave efêmera, verifica assinaturas e caminhos duplicados dos archives e registra o snapshot imutável dos pacotes em `build-metadata.txt`. Isso é qualificação do build; a chave do repositório pacman de produção e o canal de atualização do sistema instalado continuam sendo pré-requisitos separados do release.

O perfil controla bridges visuais estáticas DINX: `/usr/share/dinx/theme/DINX.json` é a fonte das cores semânticas e ANSI; GTK e Qt consomem arquivos DINX versionados, e `DINX_COLOR_SCHEME` é o contrato de cor da sessão do usuário. `qt6ct`, `adw-gtk-theme` e Noto Sans 10 são instalados para esses consumidores, alinhados à tipografia GTK padrão do CachyOS; Noto Sans Mono é usado nos campos de largura fixa. O host do Pearl Greeter lê `/etc/pearl/greeter.json`, usa a bridge GTK DINX e força `Aqueous + Pearl (DINX)` com X11 e UWSM desativados; Aqueous/Pearl é o único contrato de sessão do usuário. `scripts/check_dinx_theme.sh` valida esse contrato antes do build da ISO.

O perfil inclui o instalador experimental Calamares e o GParted para particionamento gráfico independente. O Calamares copia o root filesystem da ISO sem rede, mantém o dinit como init instalado e remove os pacotes exclusivos da sessão live durante a instalação. A imagem base traz o driver de kernel `ntfs3` para leitura e escrita em NTFS e `os-prober` para descobrir o Windows; o `ntfs-3g` legado fica como pacote opcional pós-instalação no canal extra assinado. Layouts Windows existentes de ESP/NTFS são preservados pelo instalador e usam um diretório EFI DINX separado.

Pearl Greeter, Aqueous/Pearl e o instalador recebem defaults DINX pelo root overlay. O Pearl Greeter usa o tema GTK DINX instalado e o JSON do greeter pertencente ao root; o Calamares usa os mesmos tokens de superfície/texto/primário/erro no stylesheet Qt. Pearl é o shell ativo do usuário. O host Aqueous dedicado executa somente o Pearl Greeter e não é exposto como fallback de sessão do usuário. A cadeia do Calamares mantém apenas os componentes do instalador, entradas de sessão não suportadas continuam ocultas e `Aqueous + Pearl (DINX)` é a sessão live. A sessão live expõe `Instalar DINX` pelo launcher.
O caminho live usa `Aqueous + Pearl (DINX)` sem prompt de credenciais: um serviço dinit exclusivo da live prepara o greetd antes de iniciá-lo. O rootfs instalado mantém login manual e o Calamares mantém os dois flags de autologin desativados.
O payload runtime é somente Wayland/XWayland: servidores, drivers legados de Xorg/XLibre e entradas de sessão do Plasma são omitidos. Xvfb permanece exclusivo do builder para qualificação de pacotes.
Para armazenamento, o Pori é o gerenciador DINX de discos/montagens e o Phyto é o gerenciador de arquivos padrão. O File Roller fornece ações gráficas para arquivos compactados e o GParted fornece particionamento gráfico independente fora do Calamares. O Pori usa UDisks2 para descobrir dispositivos de bloco e cria serviços de montagem persistentes scriptados em `/etc/dinit.d`; ele não usa unidades systemd. A imagem base não instala Thunar, GVFS, Tumbler nem KDE Partition Manager. O Phyto cuida da navegação de diretórios; o agente independente de PolicyKit do LXQt continua disponível para ações privilegiadas, e o Pearl continua sendo o shell ativo.
Para configuração de displays, o wrapper DINX `dinx-wdisplays` abre o editor interativo de saídas Wayland; ao fechar, ele substitui atomicamente o perfil `DINX wdisplays` em `~/.config/shikane/config.toml` e recarrega o daemon de usuário Shikane. O Shikane inicia dentro de Aqueous/Pearl e reaplica perfis correspondentes quando as saídas mudam. `Dome`, `Seafoam Settings` e `zls` fazem parte da ISO base e do repositório DINX assinado. Dome oferece monitoramento de recursos/processos compatível com dinit sem integração com systemd; Seafoam Settings é o launcher nativo em Zig/GTK4 com argv fixo para os pontos de entrada de display/sessão; ZLS é o language server Zig incluído e usado pelo Nocted com sua árvore `lib/std` correspondente e shim somente de metadados. Aqueous 1.0.5 e Pearl 0.3.0 são os únicos componentes selecionáveis da sessão.

Para navegação web, o perfil instala Firefox e o torna o manipulador padrão de HTML/XHTML/HTTP/HTTPS. A política de sistema em `/etc/firefox/policies/policies.json` desativa superfícies patrocinadas da Nova Aba e do Firefox Suggest, Pocket/Stories, Firefox Studies/telemetria, recomendações do navegador, superfícies de assistente de IA/preview de links/grupos de abas e o IP Protection integrado. Firefox Accounts continua sendo uma escolha explícita do usuário: a DINX não exige login nem exibe onboarding, enquanto as atualizações normais do navegador continuam habilitadas.
O perfil também inclui btop/nvtop/inxi, diagnóstico PCI e USB, Git/curl/less/jq/rsync, Zathura com backend MuPDF, Swayimg, VLC, Strawberry, `wl-clipboard`, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor`, o backend SANE `scanimage`, `fwupdmgr`, o runtime Flatpak e o KolourPaint. O Swayimg é compilado a partir da fonte upstream 5.6 fixada, com Wayland, JPEG e PNG, e continua sendo o visualizador padrão. Pearl é dono das superfícies ativas e as bridges DINX são estáticas; nenhum plugin ou asset privado de shell é necessário. Nenhum aplicativo Flatpak é pré-instalado.
O payload de gerenciamento adiciona `topgrade`, `paru` e Shelly. Topgrade usa um binário de release upstream fixado com a configuração `pacman` do Artix da DINX; paru é compilado a partir do release fonte fixado contra o ALPM do Artix; o Shelly delega para a configuração `pacman` do Artix. Os metadados não têm dependência ou unidade `systemd`, nenhum repositório Arch é adicionado e receitas AUR continuam sujeitas a revisão. Nenhum deles inicia automaticamente no boot.
Para gaming, o workflow P0 habilita o repositório oficial `[lib32]` do Artix no `pacman.conf` consumido pelo `buildiso`; nenhum repositório Arch é adicionado. Isso é necessário para os pacotes `steam`, `steam-devices` e Mesa/Vulkan de 32 bits do perfil.
Para hardware AMD Cyan Skillfish, como a BC-250, o perfil adiciona firmware AMDGPU, Mesa RADV e ferramentas Vulkan do Artix, além do governor SMU fixado. O serviço dinit é ligado nas raízes live e instalada, detecta PCI `1002:13fe`, aplica a configuração conservadora de 1000-1850 MHz e não altera outros hardwares. É um caminho automático via dinit, não um serviço systemd; use um kernel Artix com as correções upstream atuais da BC-250 (6.17.11 ou mais novo; prefira o kernel LTS do Artix).
O manifesto comum compacto em `iso-profiles/common/common.yaml` mantém o firmware AMDGPU exigido pelo caminho documentado do Cyan Skillfish, mas remove da imagem final o bundle genérico `linux-firmware` e o `powertop`. Ele mantém os headers do kernel para gerar o initramfs do Artix; o wrapper de mksquashfs do repositório exclui sua árvore de fontes das imagens SquashFS finais. Hardware que precise de outro firmware ou builds locais de kernel/módulos deve instalar esses pacotes separadamente.
O perfil também fornece o BC250 Control Center v1.21.1 a partir de um archive fonte MIT com SHA-256 fixado. A GUI, a CLI, a política polkit e o daemon headless ficam disponíveis no launcher e no dock; o supervisor Aqueous/Pearl inicia o daemon uma vez na sessão do usuário quando o helper está disponível. A DINX remove a unidade de usuário systemd e o drop-in systemd do Cyan upstream, portanto essa integração não adiciona serviço systemd nem serviço root dinit. No dinit, a persistência de serviços upstream é somente detecção; a telemetria BC-250 ao vivo continua sendo o caminho de background suportado.
O payload de firewall/processos adiciona UFW com os arquivos de serviço `ufw-dinit` do Artix, a GUI Gufw, daemon/UI do OpenSnitch com serviço dinit da DINX e o Qps. Os serviços UFW e OpenSnitch são instalados, mas não são ligados ao boot por padrão: configure as regras e habilite deliberadamente a política de firewall desejada. Não habilite os dois gerenciadores de regras sem revisar o ruleset netfilter resultante.

O DinitUI instala os perfis de serviços `normal`, `lite` e `gaming` e permite perfis customizados em `~/.config/dinx/dinitui/profiles.conf`. `lite` desabilita somente o Bluetooth opcional; Gaming habilita Bluetooth para controles e preserva os serviços de firewall/política de processos. O launcher standalone entra no Gaming e restaura o perfil anterior ao sair; falhas de entrada ou restauração interrompem o launcher e permanecem visíveis. A DINXPanel é dona das ações visíveis de hardware e drivers, dos atalhos fixos, dos fluxos Shelly/Topgrade, da descoberta opcional do fwupd e do instalador seguro de kernels Artix; Aqueous/Pearl não exige plugin de shell.
O host dedicado do Pearl Greeter fornece a interface de login do greetd. Pearl é o shell ativo; Aqueous/Pearl é a única sessão do usuário.
### Segurança da sessão, hierarquia e guarda de recursos

A sessão instala `swaylock`, `swayidle` e `brightnessctl`. `/usr/local/libexec/dinx-idle` bloqueia após 600 segundos e bloqueia novamente em `before-sleep`; `/usr/local/libexec/dinx-lock`, `Super+L`, a superfície de bloqueio do Pearl e a DINXPanel fornecem o caminho explícito. As teclas padrão de brilho e a DINXPanel usam passos fixos de 5% com `brightnessctl`; ferramentas especializadas permanecem no launcher.

`scripts/check_dinx_budget.sh` mantém o perfil atual em no máximo 128 entradas de pacotes rootfs e 24 entradas de inicialização dinit, limita os binários compilados da DINXPanel/DinitUI a 6 MiB cada, limita a janela de qualificação de boot QEMU a 120 segundos e exige que uma ISO construída fique abaixo de 2 GiB (`2147483647` bytes) quando `DINX_ISO_PATH` é fornecido. Esses limites evitam regressões; não são medições de desempenho em hardware. `scripts/measure_dinx_session.sh` registra snapshots de RSS/CPU via `/proc` quando uma sessão DINX está realmente em execução.

O perfil Artix atual continua sendo uma ISO única combinada de desktop/gaming/hardware porque o `buildiso` consome um `profile.yaml`; as políticas Normal/Lite/Gaming do DinitUI fornecem a separação de serviços em runtime. O conjunto de pacotes é documentado intencionalmente como um payload único até o builder suportar grupos de pacotes composáveis sem duplicar o root overlay.

O check de conteúdo prova que as imagens SquashFS do root e da sessão live contêm o compositor, shell, greeter, sessão, terminal fallback, editor de recuperação Nano, gerenciador de armazenamento Pori com dinit, gerenciador de arquivos Phyto, suporte `ntfs3` de leitura/escrita, backend de scanner SANE, ferramentas de firmware fwupd, runtime Flatpak, editor de imagens KolourPaint e payload dinit esperados. `scripts/check_desktop_packages.sh` e `scripts/check_pori_phyto.sh` verificam os contratos de pacotes/perfil antes do build. `scripts/smoke-install.sh` também executa o contrato offline em discos BIOS e UEFI efêmeros, verifica o primeiro boot dinit e habilita as TTYs de recuperação. A captura PPM do workflow é evidência visual para inspeção, não uma qualificação de hardware arbitrário.
O contrato da sessão live também prova `AUTOLOGIN=true`, o serviço dinit de autologin exclusivo da live e a fronteira inalterada do greeter do sistema instalado.

O contrato de payload também exige `wdisplays`, `shikane` e os pontos de entrada DINX de persistência de display. As fontes externas de Dome e ZLS são fixadas; o Seafoam Settings é compilado a partir da fonte versionada no repositório. Os três são obrigatórios e verificados como parte do payload base da ISO.

O workflow armazena uma captura separada `dinx-boot-screen.ppm`, feita antes do envio das teclas do menu de boot. Esse quadro deve ser revisado ao qualificar a superfície GRUB de seleção do kernel; ele é a evidência de regressão do painel opaco removido.

O GRUB usa as cores DINX de superfície, primeiro plano e seleção primária, mantendo os assets de logo/fonte do Artix. As texturas opacas do menu ficam desativadas, então o menu de boot, o greeter, o instalador e o desktop compartilham a mesma hierarquia visual plana.
O caminho live normal é autologin direto; o greeter continua sendo uma superfície de fallback, não uma etapa obrigatória do boot.

## Limite do perfil

O repositório versiona um manifesto comum compacto em `iso-profiles/common/common.yaml` em vez de depender do default do `iso-profiles` instalado. Ele mantém o payload completo de desktop/gaming/hardware da DINX enquanto remove firmware genérico e `powertop` da imagem final e exclui os headers do kernel, usados apenas no build, das imagens SquashFS finais; seu SHA-256 é registrado em `build-metadata.txt`. `WORKSPACE_DIR` em `scripts/build-iso.sh` seleciona os dois manifestos locais de forma determinística.
A evidência de release com tag atual é o [workflow 39924316082](https://github.com/rufl/DINX/actions/runs/39924316082) para a [v0.1.0-alpha.9](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.9), no commit `0d1698a462d5d5486871a7aa17e9b97352ee9404`. Ele passou a geração do checksum, a validação do payload SquashFS compacto, o boot e a captura gráfica no QEMU, o smoke transacional de particionamento BIOS/UEFI/Btrfs do Calamares, o smoke de instalação/primeiro boot/TTY de recuperação em discos BIOS e UEFI descartáveis, a verificação dos metadados de build, a atestação de procedência e a publicação do release. A ISO direta tem 2.008.801.280 bytes, abaixo do limite de 2 GiB por asset. Rede, áudio, uso autenticado de Steam/jogo, saída gaming DRM real, hardware físico e qualificação de atualização/rollback continuam fora deste resultado.

A validação pós-release da `main` [39934458077](https://github.com/rufl/DINX/actions/runs/39934458077), no commit `eb9a0c143c06d9c1939f9d88684d164d8e2384fb`, concluiu em 52m02s com os checks de build, boot, payload gráfico, instalação persistente/TTY de recuperação em BIOS e UEFI, atestação e upload. Ela confirma os contratos após a Alpha 9, mas não publica um novo release.

## Validação do build

Um build de imagem bem-sucedido não é o critério de release. A ISO resultante exige:

1. geração de checksum;
2. validação do conteúdo SquashFS;
3. smoke test de boot e instalação em VM;
4. verificação da TTY de recuperação;
5. verificações de rede, áudio, D-Bus, portal e gráficos;
6. relatório de instalação/atualização antes de ser rotulada como alpha.
