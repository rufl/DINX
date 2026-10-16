# Status do build P0

[Português (Brasil)](p0-build.md) · [English](../p0-build.md)

## Implementação selecionada

A DINX usa o fluxo atual `artools`/`buildiso` do Artix com um `profile.yaml` local no repositório, em `distro/iso/iso-profiles/dinx`. Isso mantém a seleção de pacotes de serviços dinit no caminho suportado pelo Artix e evita inventar uma segunda ferramenta de ISO.

Os pontos de entrada são:

- `scripts/check-iso-host.sh` — probe de pré-requisitos;
- `scripts/build-iso.sh` — wrapper de build com suporte a root;
- `scripts/prepare_first_party_apps.sh` — gerador determinístico do archive do código fixado do NOCTTY/NoctEd;
- `scripts/check_first_party_apps.sh` — verificação do contrato do código, pacote e perfil first-party;
- `scripts/check_firefox.sh`, `scripts/check_swayimg.sh`, `scripts/check_package_managers.sh`, `scripts/check_firewall_tools.sh`, `scripts/check_cyan_skillfish.sh` e `scripts/check_bc250_control_center.sh` — contratos do Firefox, aplicativos fixados, gerenciamento Artix, firewall, hardware e BC250 Control Center;
- `scripts/check_dinx_theme.sh` — contrato da paleta DINX, dos templates de aplicativos e das bridges do greeter/instalador/GRUB;
- `scripts/noctty_p2_qualification.sh` — matriz P2 determinística em ReleaseSafe para allocator/fairness, continuidade de PTY/sessão, ncurses e TUIs do sistema;
- `scripts/nocted_p3_qualification.sh` — matriz P3 determinística para core/índice/workers/estado/tarefas do Nocted, `clangd` real, smoke GTK/X11 nativo claro/escuro e status/diff do Git;
- `scripts/smoke-iso.sh` — probe de boot em QEMU;
- `scripts/smoke-install.sh` — smoke de instalação persistente e TTY de recuperação em disco descartável;
- `.github/workflows/p0-iso.yml` — build remoto em container Artix;
- `.github/workflows/release.yml` — publicação de pré-release por tag e montagem do pacote Windows para QEMU;
- `distro/packages/noctty/PKGBUILD` — pacote Zig nativo que instala NOCTTY e NoctEd;
- `distro/packages/noctty/qualification-compat.patch` — patch de empacotamento que conecta o target de qualificação de PTY da fonte fixada ao módulo de compatibilidade existente e adiciona o contrato P3 de Git/tema/pacote do Nocted;
- `distro/packages/wlroots0.20/PKGBUILD` — build fixado do wlroots 0.20.2 para o ABI atual do Mango/Scenefx;
- `distro/iso/iso-profiles/dinx/profile.yaml` — perfil de pacotes e serviços da fundação.

## Build remoto

O workflow `P0 ISO foundation` é executado manualmente ou quando arquivos do perfil/build mudam. Ele:

1. faz checkout da DINX;
2. verifica o archive versionado do código NOCTTY/NoctEd contra `distro/packages/noctty/source.env` e valida o contrato do pacote/perfil;
3. instala QEMU e ferramentas de inspeção de ISO no runner Ubuntu;
4. executa Artix em um container privilegiado;
5. instala `artools`, `iso-profiles`, Rust, gettext, go-md2man, Zig 0.17.0, `clang`/`clangd`, Xvfb, VTE 2.91 (`vte3`) para o binário de smoke headless do Noctty, o runtime `libghostty-vt.so` do Ghostty e as dependências de build fixadas do MangoWM/Scenefx;
6. compila o payload de pacotes Artix fixado para topgrade, paru e Shelly, o release fonte BC250 Control Center v1.21.1, o governor Cyan Skillfish e sua integração dinit; então compila o pacote nativo `noctty`, que contém NOCTTY e NoctEd, wlroots 0.20.2, MangoWM e Scenefx a partir do repositório pacman local temporário, e executa os marcadores de smoke headless de PTY/VT/sessão de terminal da fonte fixada, a qualificação de sessão com contabilização do allocator (quatro ciclos normais e um forçado), a qualificação de compatibilidade de protocolo/Unicode, `scripts/noctty_p2_qualification.sh` e `scripts/nocted_p3_qualification.sh` em ReleaseSafe. A matriz P3 prova o caminho nativo do editor nos dois esquemas empacotados, uma resposta de símbolo real do `clangd` e marcadores limitados de status/diff do Git. A matriz usa tmux real com shim determinístico de Zellij, verificações reais de Nano/Less/Dialog e top/watch/whiptail/fzf/SQLite/Glances/Bash/man/SFTP local e a qualificação de projeto/editor do Nocted;
7. executa o probe de pré-requisitos;
8. constrói a ISO com `buildiso`;
9. valida os payloads SquashFS do root e da sessão live;
10. gera checksum SHA-512;
11. mantém QEMU executando por uma janela de boot configurável e captura sua superfície VGA;
12. inicializa um disco BIOS descartável produzido a partir do mesmo contrato offline de rootfs/remoção do Calamares, gera initramfs e GRUB e verifica um marcador de primeiro boot dinit e o serviço de TTY de recuperação;
13. cria atestações de artefato do GitHub para a ISO e o checksum;
14. publica a ISO, checksum, logs QEMU e capturas PPM como artefato temporário do workflow.

A verificação de payload prova que MangoWM, Scenefx, Noctalia, ReGreet, greetd, a sessão Mango, os arquivos de serviço dinit, NOCTTY/NoctEd, `clangd`, os dois esquemas do editor Nocted, Nano, File Roller e a stack Thunar/GVFS chegaram à ISO. O contrato de mídia removível inclui UDisks2, `gvfs-mtp`, `gvfs-smb`, `gvfs-gphoto2`, `thunar-archive-plugin`, File Roller e Tumbler. Ela também confirma o agente independente de PolicyKit, rejeita metadados/runtime de pacotes systemd instalados e rejeita sessões completas do Xfce/LXQt. O smoke test do QEMU ainda prova somente aceitação de boot em nível de processo; não prova login gráfico, rede, MTP, SMB, acesso à câmera ou áudio dentro do guest.
A verificação de payload também prova Firefox, sua entrada desktop, os manipuladores padrão de HTML/XHTML/HTTP/HTTPS e `/etc/firefox/policies/policies.json`. Essa política remove superfícies patrocinadas do navegador, Pocket/Stories, Firefox Studies e telemetria, recomendações do navegador, superfícies de assistente de IA/preview de links/grupos de abas e o IP Protection integrado sem desabilitar atualizações normais ou Firefox Accounts iniciado pelo usuário.
O mesmo contrato prova o payload desktop expandido: btop/nvtop/inxi, diagnóstico PCI/USB, Git/curl/less/jq/rsync, Zathura com MuPDF, Swayimg, VLC com seus componentes GUI Qt/CLI, Strawberry, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor` e `wl-clipboard`. Ele também verifica o default flutuante do Mango, a barra `main` no topo, o dock Noctalia embaixo, os widgets de captura/clipboard do Noctalia e os handlers MIME de VLC/Strawberry. O Noctalia continua sendo o caminho primário de captura; dependências transitivas dos pacotes Artix também podem fornecer `grim`/`slurp`.
O contrato de gerenciamento também prova `topgrade`, `paru` e Shelly. Topgrade usa um binário de release upstream fixado com a configuração pacman do Artix da DINX; paru é compilado a partir do release fonte fixado contra o ALPM do Artix; o Shelly delega para a configuração `pacman` do Artix. Os metadados não contêm dependência ou unidade `systemd`, nenhum repositório Arch é adicionado e toda receita AUR continua sujeita à revisão explícita do usuário. Eles continuam sendo executados pelo usuário; a ISO não executa upgrades automaticamente.
O contrato de hardware prova firmware AMDGPU, Mesa RADV, diagnóstico Vulkan e o governor SMU Cyan Skillfish fixado. Um serviço dinit é ligado nos perfis live e instalado, detecta PCI `1002:13fe` (BC-250) e inicia o governor com faixa conservadora de 1000-1850 MHz; em outro hardware ele encerra sem alterar nada. Use um kernel Artix com as correções atuais da BC-250 (6.17.11 ou mais novo). Nenhum serviço systemd é instalado.
O pacote BC250 Control Center é fixado no release fonte upstream v1.21.1, sob licença MIT. Ele instala a GUI, a CLI, a política polkit e o daemon headless com runtime Python 3.12+ / PyQt6. A DINX remove a unidade de usuário systemd e o drop-in systemd do Cyan fornecidos pelo upstream; o Mango inicia `bc250-control-centerd` na sessão do usuário autenticado por `exec_once`, portanto o pacote não adiciona serviço systemd nem serviço root dinit. A detecção dinit upstream continua somente leitura para persistência de serviços, enquanto a telemetria BC-250 ao vivo e os controles gráficos ficam disponíveis conforme os pré-requisitos de polkit e hardware.
O mesmo contrato da ISO prova UFW, Gufw, Qps, OpenSnitch e os arquivos de serviço dinit `ufw`/`opensnitchd`. Ele confirma o default seguro (`ENABLED=no` e nenhum link de boot para os dois serviços de firewall), portanto mudanças de política de rede exigem configuração explícita do usuário.

A execução também captura a superfície VGA do QEMU como artefato PPM pelo monitor. Essa captura é evidência visual para inspeção; ela não prova automaticamente a interação com o greeter, a saúde da sessão do usuário, a rede ou o áudio.

Releases por tag reutilizam o mesmo artefato de build por meio de `.github/workflows/release.yml`. O job de release publica a ISO ou partes ordenadas abaixo de 2 GiB, o SHA-512 completo, as evidências do QEMU Linux e um pacote launcher Windows pequeno. O launcher baixa a URL HTTPS fixada nos metadados e, quando necessário, cada parte ordenada, verifica as partes e o SHA-512 completo e então executa `scripts/smoke-iso.ps1` com QEMU no Windows. Os metadados ZTASH apontam para o receptor registrado `ddjarin` sem embutir credenciais.

A sobreposição live também substitui o serviço dinit genérico `root-ro` por um no-op: a raiz live é um overlay e não pode ser remontada somente para leitura. Esse ajuste vale apenas para a sessão live da ISO, não é uma política do sistema instalado.

O wrapper do Mango habilita `WLR_RENDERER_ALLOW_SOFTWARE=1` somente quando `/dev/dri/renderD*` está ausente; portanto, o caminho QEMU headless não mascara um render node DRM real.

O perfil controla o contrato visual DINX em `root-overlay/etc/skel/.config/noctalia/palettes/DINX.json`. `scripts/check_dinx_theme.sh` valida as duas variantes da paleta, os templates do Noctalia, os adaptadores GTK/Qt/Mango, ReGreet, Calamares e GRUB antes do `buildiso`; `scripts/check-iso-content.sh` verifica os mesmos arquivos dentro da imagem SquashFS do root.

Para uma captura gráfica local, defina `DINX_QEMU_BOOT_KEYS=down,down,ret`, `DINX_QEMU_SCREENSHOT` e, opcionalmente, `DINX_QEMU_SCREENSHOT_DELAY` antes de executar `scripts/smoke-iso.sh`; o workflow usa as mesmas teclas, atraso de 60 segundos e publica o PPM junto com o artefato da ISO.

O workflow também captura `dinx-boot-screen.ppm` três segundos depois que o QEMU abre e antes do envio das teclas do menu de boot. Isso fornece evidência visual direta de regressão para a tela GRUB de seleção do kernel.
O GRUB usa as cores DINX de superfície, primeiro plano e seleção primária, mantendo os assets de logo/fonte do Artix. As texturas opacas do menu ficam desativadas, então o menu de boot, o greeter, o instalador e o desktop compartilham a mesma hierarquia visual plana.

O perfil também incorpora um caminho experimental offline do Calamares com branding DINX, módulos de serviço dinit e um KDE Partition Manager independente. A verificação de conteúdo confirma a paleta/templates DINX, ReGreet, Noctalia, Mango e os payloads de recuperação. `scripts/smoke-install.sh` verifica a instalação BIOS offline, a geração de initramfs/GRUB, o primeiro boot e a TTY de recuperação em um disco efêmero; é um smoke de contrato do CI, não uma qualificação arbitrária de hardware.

Para uma segunda captura diagnóstica após entrada de teclas, defina também `DINX_QEMU_POST_SCREENSHOT` e, opcionalmente, `DINX_QEMU_POST_SCREENSHOT_DELAY` e `DINX_QEMU_POST_KEYS`. Isso não prova que o greeter aceitou as credenciais.


## Última execução bem-sucedida observada

A execução [38830745529](https://github.com/rufl/DINX/actions/runs/38830745529), no commit `bc75f16`, concluiu todas as etapas do workflow P0 em 30m52s:

- artefato ISO: `artix-dinx-dinit-20261016-x86_64.iso`;
- o pacote nativo executou as qualificações de PTY/VT/sessão, allocator, protocolo/Unicode, fairness, tmux real, Zellij determinístico, ncurses, TUI do sistema e Vim/btop; o resultado foi `noctty_p2_qualification ... assertions=true`;
- o contrato de integração passou nas verificações de descoberta do terminal, defaults do shell, entrada desktop, diretório de trabalho, Noctalia e runtime do pacote;
- a evidência de TUI do sistema cobriu top/watch/info/whiptail/fzf/SQLite/Glances/Bash/man/SFTP local; `info_surface=fixture_fallback` e `codex_surface=fixture` continuam limites explícitos;
- smoke de boot no QEMU, verificação do payload gráfico, smoke da instalação persistente/TTY de recuperação, geração do SHA-512, atestação de procedência e upload do artefato passaram;
- artefato publicado: `dinx-foundation-iso-bc75f163a8d85a207e2bdab5dd70cf1d3116d1b4`, 2.341.669.977 bytes, contendo a ISO, checksum, log QEMU e capturas VGA.

A execução prova os contratos do pacote, da ISO, do boot na VM, do payload gráfico, do caminho persistente/recuperação em BIOS descartável e da procedência. Não prova ajuste físico da BC-250, acesso de rede/Codex autenticado nem saúde de serviços em hardware por longo prazo.

## Execução bem-sucedida anterior observada

A execução [38471629482](https://github.com/rufl/DINX/actions/runs/38471629482), no commit `6224b58`, concluiu todas as etapas do workflow em 6m02s:

- artefato ISO: `artix-dinx-dinit-20261013-x86_64.iso`;
- tamanho: 1.497.237.504 bytes;
- SHA-512: `adcd6cba882b368725ffa02d33e8a2ae17c3be1b9ffaa17692dbd9eb895689bb0a686530f1012a11f6d262ef2d9ab859d27c2995393aa1ded4cd50d4af42433c`;
- janela de smoke no QEMU: 90 segundos, aprovada;
- verificação de payload: MangoWM, Scenefx, Noctalia, ReGreet, greetd e payloads dinit presentes;
- captura gráfica: o quadro inicial mostrou o seletor de usuário/sessão do ReGreet, e o quadro após as teclas mostrou a sessão MangoWM com a tela de boas-vindas do Noctalia;
- artefato: `dinx-foundation-iso-6224b5859de814b1d5fe7e2fae982e1c9c49918f`, mantido por 7 dias.

O log serial gerado ficou vazio. As duas capturas VGA fornecem evidência da renderização do greeter e da transição bem-sucedida para a sessão gráfica do usuário; não provam rede, áudio ou saúde dos serviços em longo prazo.

## Execução P1 observada: instalação persistente

A execução [38628961983](https://github.com/rufl/DINX/actions/runs/38628961983), no commit `f5d13faa6387d35ecac8c0e674f7e98bf7ff037a`, passou o workflow P1 determinístico:

- smoke da instalação persistente: aprovado no disco BIOS/IDE descartável após copiar o rootfs da ISO, remover os pacotes exclusivos da sessão live, criar `dinx`/fstab, gerar initramfs e GRUB BIOS e inicializar pelo GRUB instalado;
- marcador do primeiro boot: `/var/lib/dinx/install-smoke.booted` foi verificado após a janela de boot de 180 segundos do QEMU;
- TTY de recuperação: `getty@tty2` foi habilitado e verificado no sistema instalado, e a captura de recuperação foi produzida;
- gates de release: verificação do payload da ISO, atestação e upload do artefato do workflow passaram.

## Extensão de mídia removível observada

A execução [38700095287](https://github.com/rufl/DINX/actions/runs/38700095287), no commit `f2acffbf77e7242fbf16848b58dff8ef8aa63bab`, passou com a stack de mídia removível, File Roller e Nano. A verificação do payload confirmou o File Roller pelo plugin de arquivos compactados do Thunar e o editor de recuperação Nano, rejeitou metadados/runtime de pacotes systemd instalados; o smoke da instalação persistente, a atestação e o upload do artefato também passaram.


## Host de desenvolvimento observado

O host de desenvolvimento é EndeavourOS x86_64. `pacman`, `xorriso` e `zig` estão disponíveis. `buildiso`, `mkarchiso` e `qemu-system-x86_64` não estão instalados. Bibliotecas de usuário do QEMU e `/dev/kvm` estão presentes, mas isso não é suficiente para executar o smoke test local.

Portanto, o build P0 deve ser executado no workflow remoto até que as dependências locais sejam disponibilizadas.

## Sequência de aceitação

1. `scripts/check-iso-host.sh` termina com sucesso no container Artix.
2. `scripts/build-iso.sh -q` resolve o perfil `dinx` com `dinit`.
3. Um build limpo produz uma ISO e seus metadados de build.
4. A verificação gráfica encontra o compositor, shell, greeter, sessão, aplicativos próprios, stack de mídia removível e arquivos dinit.
5. O checksum SHA-512 é gerado junto da ISO.
6. `scripts/smoke-iso.sh` mantém o QEMU ativo durante a janela de boot.
7. A ISO inicializa na sessão de fundação e oferece uma TTY de recuperação.
8. Rede, PipeWire, D-Bus, portais e gráficos são verificados no sistema inicializado.
9. Somente depois desses passos os pacotes do desktop e dos aplicativos próprios entram como entradas de release.
