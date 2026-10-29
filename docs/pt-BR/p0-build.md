# Status do build P0

[Português (Brasil)](p0-build.md) · [English](../p0-build.md)

## Implementação selecionada

A DINX usa o fluxo atual `artools`/`buildiso` do Artix com um `profile.yaml` local no repositório, em `distro/iso/iso-profiles/dinx`. Isso mantém a seleção de pacotes de serviços dinit no caminho suportado pelo Artix e evita inventar uma segunda ferramenta de ISO.

Os pontos de entrada são:

- `scripts/check-iso-host.sh` — probe de pré-requisitos;
- `scripts/build-iso.sh` — wrapper de build com suporte a root;
- `scripts/prepare_first_party_apps.sh` — gerador determinístico do archive do código fixado do NOCTTY/NoctEd;
- `scripts/check_first_party_apps.sh` — verificação do contrato do código, pacote e perfil first-party;
- `scripts/check_build_metadata.sh` — valida a procedência do builder, snapshots de pacotes, hashes da configuração pacman do builder, checksums das fontes e o digest emitido da ISO; quando recebe o caminho da ISO, recalcula o tamanho em bytes e o SHA-512 contra o artefato baixado;
- `scripts/check_dinx_package_repository.sh` — verifica metadados do snapshot do repositório, assinaturas dos pacotes/banco, fingerprint da chave e caminhos duplicados nos archives;
- `scripts/smoke_dinx_update.sh` — transação real assinada de instalação/atualização/downgrade pacman contra raízes descartáveis;
- `scripts/check_dinx_release_preflight.sh` — preflight do canal stable, da chave persistente e dos assets do release GitHub;
- `scripts/check_dinx_package_provenance.sh` — exige checksums fixados ou contratos locais/staged explícitos para cada PKGBUILD DINX;
- `scripts/check_dinx_feature_groups.sh` — valida o manifesto de grupos inspirado no Mocaccino contra o perfil Artix;
- `scripts/check_firefox.sh`, `scripts/check_swayimg.sh`, `scripts/check_package_managers.sh`, `scripts/check_desktop_packages.sh`, `scripts/check_firewall_tools.sh`, `scripts/check_cyan_skillfish.sh` e `scripts/check_bc250_control_center.sh` — contratos do Firefox, aplicativo fixado, gerenciamento de pacotes, scanner/firmware/Flatpak/editor de imagens, firewall, hardware e BC250 Control Center;
- `scripts/check_dinitui.sh` — contrato do pacote DinitUI, ações, limite de privilégios, perfis de serviços e integração Gaming direta sobre dinit;
- `scripts/check_dinxpanel.sh` — contrato do centro de controle DINXPanel, ponte fixa de GPU e instalador seguro de kernels;
- `scripts/check_gaming.sh` — launcher manual oculto, limite do grupo opcional, Vulkan base e exclusão do payload gaming da ISO;
- `scripts/check_alpha7_hardware_report.sh` e `scripts/check_dinx_hardware_evidence.sh` — o schema do relatório de hardware mantém o nome Alpha 7 por compatibilidade; os checks cobrem detecção BC250, limites manuais e evidência de release;
- `docs/pt-BR/alpha7-qualification.md` — matriz de evidências de hardware para três máquinas e limite de qualificação manual da release de sistema Alpha 10;
- `scripts/check_dinx_budget.sh` e `scripts/measure_dinx_session.sh` — tetos de payload/inicialização/binários nativos/janela de boot/ISO e observação de RSS/CPU em runtime;
- `scripts/gaming_p5_qualification.sh` — qualificação do retorno da sessão por fixture, limpeza do grupo de processos/restauração do perfil durante sinais e launch/exit real headless do Gamescope;
- `scripts/noctty_p2_qualification.sh` — matriz P2 determinística em ReleaseSafe para allocator/fairness, continuidade de PTY/sessão, ncurses e TUIs do sistema;
- `scripts/nocted_p3_qualification.sh` — matriz P3 determinística para core/índice/workers/estado/tarefas do Nocted, `clangd` real, smoke GTK/X11 nativo claro/escuro e status/diff do Git;
- `scripts/smoke-iso.sh` — probe de boot em QEMU;
- `scripts/smoke-install.sh` — smoke de instalação persistente e TTY de recuperação em disco descartável;
- `scripts/dinitui_dinit_qualification.sh` — daemon Dinit temporário real, ciclo de vida do serviço e smoke GTK;
- `scripts/smoke_calamares_startup.sh` — smoke limitado de inicialização do Calamares contra a configuração enviada;
- `.github/workflows/p0-iso.yml` — build remoto em container Artix;
- `.github/workflows/release.yml` — publicação de pré-release por tag e montagem do pacote Windows para QEMU;
- `distro/packages/noctty/PKGBUILD` — pacote Zig nativo que instala NOCTTY e NoctEd;
- `distro/iso/iso-profiles/dinx/root-overlay/etc/greetd/config.toml` e `distro/iso/iso-profiles/dinx/root-overlay/etc/pearl/greeter.json` — configuração versionada do Pearl Greeter; o greetd inicia diretamente o host dedicado sem systemd nem UWSM;
- `distro/packages/dinitui/PKGBUILD` — frontend dinit nativo em Zig 0.17 com GTK4/libadwaita;
- `distro/packages/dinxpanel/PKGBUILD` — centro de controle inspirado no YaST, nativo em Zig 0.17 com GTK4/libadwaita;
- `distro/iso/iso-profiles/dinx/profile.yaml` — perfil de pacotes e serviços da fundação.
- `distro/iso/iso-profiles/dinx/feature-groups.json` — metadados dos grupos foundation, desktop, gaming, hardware e opcional; os grupos opcionais ficam fora da ISO base.

## Build remoto

O workflow `P0 ISO foundation` é executado manualmente ou quando arquivos do perfil/build mudam. Ele:

1. faz checkout da DINX;
2. verifica o archive versionado do código NOCTTY/NoctEd contra `distro/packages/noctty/source.env` e valida o contrato do pacote/perfil;
3. instala QEMU, ferramentas de inspeção da ISO e os dados OCR de inglês do Tesseract no runner Ubuntu;
4. executa Artix em um container privilegiado;
5. instala `artools`, `iso-profiles`, Rust, gettext, go-md2man, Zig 0.17.0, `clang`/`clangd`, Xvfb, VTE 2.91 (`vte3`) para o binário de smoke headless do Noctty e o runtime `libghostty-vt.so` do Ghostty; os pacotes DINX de Aqueous/Pearl e suas dependências Wayland diretas são compilados a partir das entradas de pacote configuradas;
O Pearl 0.3.0 segue o `.zigversion` upstream e é compilado com o archive exato do Zig 0.16.0 verificado pelo workflow; os pacotes Zig nativos da DINX continuam no toolchain Zig 0.17.0 verificado.
6. compila os pacotes Artix fixados para topgrade, paru e Shelly, além dos pacotes BC250 Control Center v1.21.1 e governor Cyan Skillfish para o repositório DINX assinado; esses pacotes específicos de hardware têm `iso:false` e ficam fora de ambos os rootfs genéricos. Depois compila o pacote nativo `noctty`, com NOCTTY e NoctEd, e Aqueous/Pearl, executando os marcadores de smoke PTY/VT/sessão fixados, a qualificação com contabilização do allocator, compatibilidade de protocolo/Unicode, `scripts/noctty_p2_qualification.sh` e `scripts/nocted_p3_qualification.sh` em ReleaseSafe. A matriz P3 prova o caminho nativo do editor nos dois esquemas empacotados, uma resposta real de símbolo do `clangd` e marcadores limitados de status/diff do Git. Ela usa tmux real com shim determinístico de Zellij, Nano/Less/Dialog reais, top/watch/whiptail/fzf/SQLite/Glances/Bash/man/SFTP local e a qualificação de projeto/editor do Nocted;
7. executa o probe de pré-requisitos;
8. constrói a ISO com `buildiso`;
9. valida os payloads SquashFS do root e da sessão live, incluindo a regra tmpfiles dos logs Dinit no rootfs e as substituições de remontagem da raiz exclusivas do livefs;
10. gera checksum SHA-512;
11. mantém o QEMU executando por uma janela de boot configurável, captura a superfície VGA e exige que o OCR reconheça Pearl/Aqueous/DINX em vez do greeter, do prompt de login ou de uma falha visível do Dinit;
12. tenta inicializar discos BIOS e UEFI descartáveis produzidos a partir do mesmo contrato offline de rootfs/remoção do Calamares, gera initramfs e o caminho GRUB BIOS ou UEFI correspondente e verifica um marcador de primeiro boot dinit e o serviço de TTY de recuperação;
13. cria atestações de artefato do GitHub para a ISO e o checksum;
14. publica a ISO, checksum, logs QEMU e capturas PPM como artefato temporário do workflow.

O repositório pacman temporário é assinado dentro do builder com uma chave CI efêmera. O workflow registra o snapshot do conteúdo dos pacotes, os checksums do banco/chave do repositório e o fingerprint da assinatura em `build-metadata.txt`, depois verifica todas as assinaturas e os caminhos duplicados dos archives antes de o `buildiso` consumir o repositório. Isso qualifica o contrato do build; não é a chave do repositório de produção nem um canal de atualização do sistema instalado.
O builder agora valida o ambiente da imagem fixada antes do `docker run` e novamente dentro do container, portanto a geração dos metadados não prossegue com a identidade da imagem ausente.
O wrapper de compactação da ISO impõe o preset xz suportado pela ferramenta com BCJ x86, blocos de 256 KiB e dicionário de 256 KiB, além de excluir fontes do kernel, caches de pacotes pacman e logs de build. O workflow registra o schema de compactação e o checksum do wrapper em `build-metadata.txt`; `check_build_metadata.sh` os vincula ao wrapper versionado. As ferramentas SquashFS exclusivas do build ficam no builder e não são copiadas para o payload de runtime.
Como o `buildiso` do Artix pode chamar `/usr/bin/mksquashfs` diretamente, o workflow privilegiado preserva o binário real, instala o wrapper DINX nesse caminho absoluto, exporta o caminho do binário real e rejeita recursão para o próprio wrapper. Depois da montagem, `check-iso-content.sh` lê os superblocos das duas imagens SquashFS e verifica xz com blocos de 256 KiB, em vez de confiar apenas na intenção dos argumentos.

O marcador do primeiro boot instalado verifica que o banco pacman sobreviveu à instalação offline, que os pacotes centrais DINX estão instalados, que NetworkManager e elogind estão disponíveis pelo dinit, que DinitUI/DINXPanel não têm bibliotecas dinâmicas ausentes e que WIZP/CUPS continuam fora da imagem base.

DinitUI é compilado de `distro/packages/dinitui` com Zig 0.17.0 contra GTK4/libadwaita, enquanto a DINXPanel é compilada de `distro/packages/dinxpanel`; os dois pacotes são adicionados ao repositório pacman temporário e instalados pelo perfil DINX. `scripts/check_dinitui.sh` valida o contrato de backend do DinitUI; `scripts/check_dinxpanel.sh` valida o centro de controle inspirado no YaST, os atalhos fixos, os lançamentos por argv direto, a ponte fixa de GPU e o catálogo seguro de kernels antes do build do container.
O relatório de upgrades da DINXPanel usa o caminho somente-leitura `sync`/`list-updates all` do Shelly e, opcionalmente, `fwupdmgr refresh`/`get-updates`; o preview do Topgrade é `topgrade --dry-run --show-skipped --no-self-update --no-tmux`, e aplicar Topgrade ou Shelly continua sendo uma ação explícita no terminal.
`scripts/dinitui_dinit_qualification.sh` inicia um daemon Dinit de usuário temporário real, valida `list`/`status`/`stop` e executa o smoke GTK do DinitUI de produção contra esse socket. Exige binários Dinit e `xvfb-run`; fica separado de propósito do gate do container privilegiado da ISO. O pacote DinitUI e seu contrato direto de estado de perfis são verificados sem plugin de shell ou configuração privada de shell.
O perfil de serviços gaming preserva por padrão Bluetooth/controles e os serviços de firewall/política de processos; não troca segurança por ganho de benchmark não medido. O launcher standalone oculto `dinx-gaming` usa o backend DRM nativo do Gamescope. Gamescope, Steam, regras de dispositivos Steam, GameMode, MangoHud e bibliotecas de 32 bits pertencem ao grupo opcional `gaming` e ficam fora de rootfs/livefs; RADV e ferramentas Vulkan de 64 bits continuam na base. O usuário pode optar por instalar após a instalação do sistema usando a configuração Artix `[lib32]` em `docs/pt-BR/install.md`. O P0 instala Gamescope somente dentro do builder para qualificação headless; não habilita `[lib32]` nem adiciona repositórios Arch, e o launcher verifica Gamescope/Steam antes de alterar perfis. A DINXPanel é dona das ações visíveis de GPU e delega ao DinitUI a detecção fixa por `lspci -nnk` e planos por fabricante; seu instalador oferece somente `linux`, `linux-lts`, `linux-zen` e `linux-hardened` com headers correspondentes, nunca remove pacotes, protege o kernel em execução e exige reinicialização. `scripts/check_gaming.sh` roda antes do build do container e `scripts/gaming_p5_qualification.sh` continua sendo o gate local/runtime; seu fixture não autentica Steam nem declara jogo comercial, hardware de controle/áudio, saída DRM ou suspend/resume.
O smoke GTK isolado do Nocted renderiza os fallbacks de ícone para PNG com `rsvg-convert` e usa um tema `NoctedSmoke` autossuficiente com apenas o fallback padrão `hicolor`: o GTK3 não precisa dos assets SVG herdados do Adwaita do container, de loaders XPM legados nem da configuração externa de loaders do tema. O container Artix instala explicitamente Glycin, bubblewrap e `shared-mime-info`, reconstrói o banco MIME e atualiza o cache do GdkPixbuf antes do build do pacote. A qualificação de build do Noctty desativa apenas o sandbox aninhado do Glycin porque já executa dentro do container privilegiado; o runtime empacotado mantém a dependência de bubblewrap e não herda essa configuração. Assim, o fixture não transforma essa diferença de empacotamento em uma falha falsa do release.

### Qualificação local P4/P5

Os gates locais passam o contrato do pacote DinitUI, um daemon Dinit de usuário temporário real com o smoke GTK e o fixture da sessão gaming com lançamento/saída headless do Gamescope. O workflow de release Alpha 10 com tag [40879223746](https://github.com/rufl/DINX/actions/runs/40879223746) fornece o repositório estável de pacotes, ISO, QEMU, payload gráfico, transação BIOS/UEFI/Btrfs do Calamares, smokes de instalação persistente/recuperação em discos BIOS e UEFI descartáveis, verificação dos metadados, atestação e assets publicados. Os limites P5 de DRM real, Steam/jogo autenticados, controle/áudio e hardware físico continuam abertos.

A verificação de payload da Alpha 9 historicamente confirmou Gamescope, Steam e pacotes gráficos de 32 bits naquele artefato publicado; essas afirmações de presença não descrevem o novo perfil base. Os checks P0 atuais exigem o launcher/entrada gaming ocultos e rejeitam binários e metadata dos pacotes opcionais nas imagens rootfs e livefs. O contrato de armazenamento continua exigindo o serviço dinit do Pori em `/etc/dinit.d`, `ntfs3` para leitura/escrita live, `ntfs-3g` pós-instalação opcional, File Roller e GParted, enquanto rejeita Thunar, GVFS, Tumbler e KDE Partition Manager. Também confirma o agente PolicyKit independente e rejeita metadata/runtime do init systemd mantendo dinit.
A verificação de payload também prova Firefox, sua entrada desktop, os manipuladores padrão de HTML/XHTML/HTTP/HTTPS e `/etc/firefox/policies/policies.json`. Essa política remove superfícies patrocinadas do navegador, Pocket/Stories, Firefox Studies e telemetria, recomendações do navegador, superfícies de assistente de IA/preview de links/grupos de abas e o IP Protection integrado sem desabilitar atualizações normais ou Firefox Accounts iniciado pelo usuário.
O mesmo contrato prova o payload desktop expandido: btop/nvtop/inxi, diagnóstico PCI/USB, Git/curl/less/jq/rsync, Zathura com MuPDF, Swayimg, VLC com seus componentes GUI/CLI Qt, Strawberry, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor`, `wl-clipboard`, o backend SANE `scanimage`, `fwupdmgr`, o runtime Flatpak e o KolourPaint. Ele também verifica as superfícies do shell Pearl, o host do Pearl Greeter, os handlers MIME DINX e os handlers de VLC/Strawberry. O Swayimg continua sendo o visualizador padrão; o KolourPaint fornece edição simples de imagens sem alterar esse default. O contrato visual usa configuração estática DINX para GTK/Qt, sem plugin de shell.

O contrato de display também exige os binários base `wdisplays` e `shikane`, além do wrapper de persistência `dinx-wdisplays` e do salvador de perfil nomeado DINX. O payload Seafoam base inclui o Seafoam Settings, um launcher nativo em Zig/GTK4 com argv fixo, o Dome com fonte fixada no Pearl v0.3.0 e o pacote oficial ZLS 0.16.0 com fonte fixada usado pelo Nocted para LSP Zig. Os pacotes Zig nativos da DINX são compilados com Zig 0.17.0; o pacote ZLS carrega apenas a árvore `lib/std` correspondente do Zig e seu shim somente de metadados; a ISO base não instala compilador Zig completo nem systemd, e o workflow testa completion/navegação reais antes de montar a ISO. O workflow compila os três no repositório de pacotes DINX assinado, e o perfil da ISO exige seus binários, metadados desktop, ícones e documentação.
O contrato da sessão compila e instala Aqueous 1.0.5 e Pearl 0.3.0, verifica que `Aqueous + Pearl (DINX)` é a única entrada selecionável do greeter e prova o ciclo de vida direto sobre dinit: o Aqueous lança o filho init da DINX, que espera Wayland e D-Bus da sessão; então o supervisor inicia Shikane, PolicyKit, o idle obrigatório e Pearl. O daemon opcional BC-250 inicia somente quando o usuário instala separadamente o pacote assinado após detectar PCI `1002:13fe`; esses pacotes não fazem parte da ISO genérica. As receitas removem `uwsm` e unidades systemd de usuário upstream; o build do Aqueous remove a biblioteca systemd e as verificações de atividade por D-Bus, substituindo-as por verificações de pidfd, executável e ambiente para lançamentos diretos sobre dinit. O host do Pearl Greeter executa somente o Pearl Greeter, e nenhum servidor, driver ou payload Plasma X11 legado de Xorg/XLibre é aceito na ISO runtime; XWayland e Xvfb exclusivo do builder continuam disponíveis.
O contrato de gerenciamento também prova `topgrade`, `paru` e Shelly. Topgrade usa um binário de release upstream fixado com a configuração pacman do Artix da DINX; paru é compilado a partir do release fonte fixado contra o ALPM do Artix; o Shelly delega para a configuração `pacman` do Artix. Os metadados não contêm dependência ou unidade `systemd`, nenhum repositório Arch é adicionado e toda receita AUR continua sujeita à revisão explícita do usuário. Eles continuam sendo executados pelo usuário; a ISO não executa upgrades automaticamente.
O contrato de hardware confirma que o firmware AMDGPU genérico, Mesa RADV e diagnósticos Vulkan continuam na ISO base. O governor Cyan Skillfish e o BC250 Control Center permanecem pacotes fixados e compiláveis no repositório DINX assinado, mas o grupo `hardware` usa `iso:false` e a verificação de conteúdo rejeita seus binários, serviços e metadata pacman nas duas imagens genéricas. Instale-os somente após confirmar o PCI `1002:13fe`; o comportamento em runtime continua sendo uma qualificação em hardware físico.
O mesmo contrato da ISO prova UFW, Gufw, Qps, OpenSnitch e os arquivos de serviço dinit `ufw`/`opensnitchd`. Ele confirma o default seguro (`ENABLED=no` e nenhum link de boot para os dois serviços de firewall), portanto mudanças de política de rede exigem configuração explícita do usuário.

A smoke QEMU captura um PPM VGA pós-boot e o verifica com Tesseract: o quadro precisa conter um marcador Pearl/Aqueous/DINX e rejeitar Pearl Greeter, consoles TTY, prompts de login, campos de senha/entrada e falhas visíveis do Dinit. Um rótulo DINX visível no greeter não é evidência da sessão. Isso confirma que o quadro capturado chegou à superfície gráfica esperada da sessão; não prova rede, áudio nem a saúde prolongada dos serviços.

Releases por tag reutilizam o mesmo artefato de build por meio de `.github/workflows/release.yml`. O job de release publica a ISO ou partes ordenadas abaixo de 2 GiB, o SHA-512 completo, as evidências do QEMU Linux e um pacote launcher Windows pequeno. O launcher baixa a URL HTTPS fixada nos metadados e, quando necessário, cada parte ordenada, verifica as partes e o SHA-512 completo e então executa `scripts/smoke-iso.ps1` com QEMU no Windows. Os metadados ZTASH apontam para o receptor registrado `ddjarin` sem embutir credenciais.

O pacote `dinx-live-autologin`, exclusivo do livefs, substitui `root-ro` e `early-root-rw.target` por no-ops para o overlay já gravável. Seu serviço Dinit habilitado no boot grava a configuração única da sessão inicial Aqueous/Pearl e declara `before = greetd` e `before = login.target`; como ambos os serviços são ativados no boot live, o Dinit inicia o configurador antes do serviço upstream `greetd-dinit`, sem instalar um segundo pacote dono de `/etc/dinit.d/greetd`. O Calamares instala `rootfs.img`, então o sistema instalado mantém as unidades genéricas de remontagem do Artix e o greetd de login manual.

O wrapper Aqueous/Pearl seleciona `/usr/bin/aqueous-cpu` e exporta `WLR_RENDERER=pixman` e `GSK_RENDERER=cairo` quando `/dev/dri/renderD*` está ausente ou uma placa DRM informa o vendor Virtio `0x1af4`. Esse binário usa `-Dvulkan-effects=false`, então Aqueous delega a seleção do renderer ao wlroots em vez de forçar Vulkan; o fallback mantém um desktop utilizável no QEMU sem alterar o binário completo nem os defaults de driver em hardware normal.

O perfil controla o contrato visual DINX em `/usr/share/dinx/theme/DINX.json`. `scripts/check_dinx_theme.sh` valida a paleta estática, `DINX_COLOR_SCHEME`, as bridges GTK/Qt, o Pearl Greeter, Calamares e GRUB antes do `buildiso`; `scripts/check-iso-content.sh` verifica os mesmos arquivos dentro da imagem SquashFS do root.

Para uma captura gráfica local, instale QEMU, `socat`, `tesseract-ocr` e `tesseract-ocr-eng`, depois defina `DINX_QEMU_BOOT_KEYS=down,down,ret`, `DINX_QEMU_SCREENSHOT` e, opcionalmente, `DINX_QEMU_SCREENSHOT_DELAY` antes de executar `scripts/smoke-iso.sh`. Defina `DINX_QEMU_TIMEOUT` acima do atraso da captura; o workflow usa as mesmas teclas, atraso de 60 segundos e janela QEMU de 90 segundos.
Sem `DINX_QEMU_SCREENSHOT`, o smoke salva o quadro verificado ao lado do log QEMU como `<iso>.qemu.log.session.ppm`. `DINX_QEMU_OCR_LANG` seleciona outro modelo de idioma Tesseract instalado, se necessário.

O workflow também captura `dinx-boot-screen.ppm` três segundos depois que o QEMU abre e antes do envio das teclas do menu de boot. Isso fornece evidência visual direta de regressão para a tela GRUB de seleção do kernel.
O GRUB usa as cores DINX de superfície, primeiro plano e seleção primária, mantendo os assets de logo/fonte do Artix. As texturas opacas do menu ficam desativadas, então o menu de boot, o greeter, o instalador e o desktop compartilham a mesma hierarquia visual plana.

O perfil também incorpora um caminho experimental offline do Calamares com branding DINX e módulos de serviço dinit; o Pori é a única interface gráfica de armazenamento e o Phyto é o gerenciador de arquivos padrão. A verificação de conteúdo confirma a configuração do instalador, os defaults estáticos de tema/paleta DINX, o Pearl Greeter, a sessão Aqueous/Pearl forçada e os payloads de recuperação. `scripts/smoke-install.sh` verifica instalações BIOS e UEFI offline, a geração de initramfs/GRUB, o primeiro boot e a TTY de recuperação em discos efêmeros; é um smoke de contrato do CI, não uma qualificação arbitrária de hardware.
O contrato de particionamento do Calamares é verificado antes do build do container: ESP recomendada de 1 GiB/mínima de 64 MiB, EFI FAT32 e root ext4/btrfs, particionamento manual explícito, LVM desabilitado, exceções de montagens live, remoção de pacotes offline, suporte de leitura/escrita pelo `ntfs3` do kernel, `ntfs-3g` opcional pós-instalação, suporte a `os-prober` e um plano Btrfs explícito de nível superior que não recria `@`/`@home` existentes. `scripts/smoke_calamares_partitioning.sh` faz round-trip das tabelas BIOS e UEFI, filesystems e fstab em discos descartáveis e reabre um volume Btrfs com subvolumes existentes. `scripts/smoke_calamares_windows.sh` preserva uma ESP FAT32/caminho Microsoft e partição NTFS de Windows existentes enquanto conclui transações DINX de root/GRUB em layouts side-by-side e manuais. São smokes transacionais dos layouts suportados, não uma alegação de que todos os caminhos de filesystem, criptografia, RAID, BitLocker, hibernação, firmware Windows ou firmware físico do Calamares estejam livres de bugs.

Para uma segunda captura diagnóstica após o boot, defina `DINX_QEMU_POST_SCREENSHOT` e, opcionalmente, `DINX_QEMU_POST_SCREENSHOT_DELAY`. Deixe `DINX_QEMU_POST_KEYS` sem definir no caminho normal de autologin. Um quadro posterior prova apenas que o QEMU renderizou outro ponto da sessão.


## Última execução de release publicada

A execução marcada [40879223746](https://github.com/rufl/DINX/actions/runs/40879223746) para `v0.1.0-alpha.10`, no commit `3fd3cd036cab7e8fb553e6e5c244b02429f1a18e`, concluiu com sucesso todas as etapas do workflow:

- contratos de pacote/perfil e first-party, incluindo apps nativos e procedência dos pacotes, passaram antes do build Artix;
- builds dos pacotes e `buildiso` compacto concluíram; conteúdo/tamanho da ISO e vínculo dos metadados/digest passaram;
- as transações de particionamento Calamares e o boot/captura gráfica no QEMU passaram;
- smokes de instalação persistente, primeiro boot e TTY de recuperação passaram em discos BIOS e UEFI descartáveis;
- repositório DINX assinado, preflight do release, SHA-512, atestação de procedência GitHub e publicação passaram;
- a ISO direta publicada tem 1.862.772.736 bytes e SHA-512 `5f49a65eac1481c01555a8f44b049c9a06e75ec7270ac3cdef97cc5e0b051d4b3c48a200542a36ec1832700accbc5509e3c314726c2f747530095eba4112219a`; snapshot do repositório assinado `b0015a0655d7d56a4949731d1a4f33cb2cc8daa55d4ec77df6d1a22161d2f5fd`.

Isso encerra o caminho P4 DinitUI e de instalação/recuperação descartáveis para o gate do alpha de sistema. Não prova uso autenticado de Steam/jogo, saída gaming DRM real, hardware de controle/áudio, instalação física, firmware, atualização, rollback do filesystem, redimensionamento de Windows com BitLocker/hibernação nem saúde de hardware por longo prazo.

## Último P0 bem-sucedido da main

A execução [40870759044](https://github.com/rufl/DINX/actions/runs/40870759044), no mesmo commit, passou pelo build, payload ISO, boot/captura gráfica no QEMU, transações de layout do Calamares, instalação persistente BIOS/UEFI e smokes de TTY de recuperação, verificação dos metadados, atestação e upload do artefato. Uma gravação anterior do marcador UEFI concorreu com a remontagem read-only da raiz instalada; agora ele depende de `early-root-rw.target`, e o gate corrigido passou nos dois modos de firmware.

## Build histórico da main antes da Alpha 10

A execução [40637700291](https://github.com/rufl/DINX/actions/runs/40637700291), no commit `f01f372cc9c93283bbc2a33de24c27aced1428bf`, passou o build da ISO, o QEMU e os smokes de instalação BIOS/UEFI descartável. A ISO tinha 2.065.172.480 bytes. Esta é uma evidência histórica de comparação; a qualificação da Alpha 10 está documentada na execução de release publicada acima.

## Validação pós-release anterior bem-sucedida da `main`

A execução [39934458077](https://github.com/rufl/DINX/actions/runs/39934458077), no commit da `main` `eb9a0c143c06d9c1939f9d88684d164d8e2384fb`, concluiu em 52m02s após passar pelos mesmos contratos de pacote/perfil, build da ISO compacta, boot e payload gráfico no QEMU, smokes de instalação persistente/TTY de recuperação em BIOS e UEFI, atestação de procedência e upload do artefato. Esta é apenas evidência de validação; não publicou um novo release.

## Execução bem-sucedida anterior observada

A execução [38471629482](https://github.com/rufl/DINX/actions/runs/38471629482), no commit `6224b58`, concluiu todas as etapas do workflow em 6m02s:

- artefato ISO: `artix-dinx-dinit-20261013-x86_64.iso`;
- tamanho: 1.497.237.504 bytes;
- SHA-512: `adcd6cba882b368725ffa02d33e8a2ae17c3be1b9ffaa17692dbd9eb895689bb0a686530f1012a11f6d262ef2d9ab859d27c2995393aa1ded4cd50d4af42433c`;
- janela de smoke no QEMU: 90 segundos, aprovada;
- verificação de payload: shell legado, ReGreet, greetd e payloads dinit presentes;
- captura gráfica: este quadro histórico, anterior ao Aqueous/Pearl, mostrou o seletor de usuário/sessão do ReGreet, e o quadro após as teclas mostrou a sessão gráfica do usuário com a tela de boas-vindas do shell legado; esta evidência é anterior à troca para a sessão atual;
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

O host de desenvolvimento é EndeavourOS x86_64. `pacman`, `xorriso`, `zig` e `qemu-system-x86_64` estão disponíveis; o `buildiso` do Artix e o `mkarchiso` genérico não estão instalados. O build P0 continua remoto porque usa o `buildiso` do Artix em um container privilegiado para operações de chroot e mount.

## Sequência de aceitação

1. `scripts/check-iso-host.sh` termina com sucesso no container Artix.
2. `scripts/build-iso.sh -q` resolve o perfil `dinx` com `dinit`.
3. Um build limpo produz uma ISO e seus metadados de build.
4. A verificação gráfica encontra o compositor, shell, greeter, sessão, aplicativos próprios, Pori, Phyto, UDisks2, o módulo de kernel `ntfs3` e arquivos dinit.
5. O checksum SHA-512 é gerado junto da ISO.
6. `scripts/smoke-iso.sh` mantém o QEMU ativo durante a janela de boot.
7. A ISO inicializa na sessão de fundação e oferece uma TTY de recuperação.
8. Rede, PipeWire, D-Bus, portais e gráficos são verificados no sistema inicializado.
9. Somente depois desses passos os pacotes do desktop e dos aplicativos próprios entram como entradas de release.
