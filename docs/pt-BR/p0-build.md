# Status do build P0

[Português (Brasil)](p0-build.md) · [English](../p0-build.md)

## Implementação selecionada

A DINX usa o fluxo atual `artools`/`buildiso` do Artix com um `profile.yaml` local no repositório, em `distro/iso/iso-profiles/dinx`. Isso mantém a seleção de pacotes de serviços dinit no caminho suportado pelo Artix e evita inventar uma segunda ferramenta de ISO.

Os pontos de entrada são:

- `scripts/check-iso-host.sh` — probe de pré-requisitos;
- `scripts/build-iso.sh` — wrapper de build com suporte a root;
- `scripts/prepare_first_party_apps.sh` — gerador determinístico do archive do commit fixado do upstream Deetty que fornece Deetty/Dintor;
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
- `docs/pt-BR/alpha7-qualification.md` — matriz de evidências de hardware para três máquinas e limite de qualificação manual da release de sistema Alpha 12;
- `scripts/check_dinx_budget.sh` e `scripts/measure_dinx_session.sh` — tetos de payload/inicialização/binários nativos/janela de boot/ISO e observação de RSS/CPU em runtime;
- `scripts/gaming_p5_qualification.sh` — qualificação do retorno da sessão por fixture, limpeza do grupo de processos/restauração do perfil durante sinais e launch/exit real headless do Gamescope;
- `scripts/deetty_p2_qualification.sh` — matriz P2 determinística em ReleaseSafe para allocator/fairness, continuidade de PTY/sessão, ncurses e TUIs do sistema;
- `scripts/dintor_p3_qualification.sh` — matriz P3 determinística para core/índice/workers/estado/tarefas do Dintor, `clangd` real, smoke GTK/X11 nativo claro/escuro e status/diff do Git;
- `scripts/smoke-iso.sh` — probe de boot em QEMU;
- `scripts/smoke-install.sh` — smoke de instalação persistente e TTY de recuperação em disco descartável;
- `scripts/dinitui_dinit_qualification.sh` — daemon Dinit temporário real, ciclo de vida do serviço e smoke GTK;
- `scripts/smoke_calamares_startup.sh` — smoke limitado de inicialização do Calamares contra a configuração enviada;
- `.github/workflows/p0-iso.yml` — build remoto em container Artix;
- `.github/workflows/release.yml` — publicação de pré-release por tag e montagem do pacote Windows para QEMU;
- `distro/packages/deetty/PKGBUILD` — pacote Zig nativo que instala Deetty e Dintor;
- `distro/iso/iso-profiles/dinx/root-overlay/etc/greetd/config.toml` e `distro/iso/iso-profiles/dinx/root-overlay/etc/pearl/greeter.json` — configuração versionada do Pearl Greeter; o greetd inicia diretamente o host dedicado sem systemd nem UWSM;
- `distro/packages/dinitui/PKGBUILD` — frontend dinit nativo em Zig 0.17 com GTK4/libadwaita;
- `distro/packages/dinxpanel/PKGBUILD` — centro de controle inspirado no YaST, nativo em Zig 0.17 com GTK4/libadwaita;
- `distro/iso/iso-profiles/dinx/profile.yaml` — perfil de pacotes e serviços da fundação.
- `distro/iso/iso-profiles/dinx/feature-groups.json` — metadados dos grupos foundation, desktop, gaming, hardware e opcional; os grupos opcionais ficam fora da ISO base.

## Build remoto

O workflow separado `DINX contracts` executa checks de contrato/fixture e lint REUSE em todo pull request e push para `main`. Os workflows P0 e de contratos fazem checkout de `rufl/DEETTY` usando `DEETTY_SOURCE_READ_TOKEN` quando configurado e, caso contrário, `GITHUB_TOKEN`; o token precisa ter acesso ao repositório de fontes. O workflow de contratos pula somente os checks dependentes da fonte em PRs de forks externos que não podem receber secrets do repositório.

O workflow `P0 ISO foundation` é executado manualmente ou quando arquivos do perfil/build mudam. Ele:

1. faz checkout da DINX;
2. lê o commit fixado em `distro/packages/deetty/source.env`, faz checkout de `rufl/DEETTY`, gera o archive ignorado pelo Git para Deetty/Dintor e verifica o SHA-256 fixado;
3. instala QEMU, ferramentas de inspeção da ISO e os dados OCR de inglês do Tesseract no runner Ubuntu;
4. executa Artix em um container privilegiado;
5. instala `artools`, `iso-profiles`, Rust, gettext, go-md2man, Zig 0.17.0, `clang`/`clangd`, Xvfb e VTE 2.91 (`vte3`) para o smoke headless do Deetty. O aplicativo Ghostty completo é instalado temporariamente somente no builder como fonte de extração do `ghostty-vt-runtime`; esse pacote contém a biblioteca VT, headers e licença. Depois, o aplicativo completo é removido antes de montar a ISO. Os pacotes DINX de Aqueous/Pearl e suas dependências Wayland diretas são compilados a partir das entradas configuradas.
O Pearl 0.3.0 segue o `.zigversion` upstream e é compilado com o archive exato do Zig 0.16.0 verificado pelo workflow; os pacotes Zig nativos da DINX continuam no toolchain Zig 0.17.0 verificado.
6. compila os pacotes DINX fixados, incluindo topgrade, paru e Shelly, além do BC250 Control Center v1.21.1 e do governor Cyan Skillfish; os pacotes específicos de hardware têm `iso:false` e ficam fora dos dois rootfs genéricos. Compila e instala Deetty/Dintor com o runtime somente VT antes da DINXPanel e dos pacotes de sessão Aqueous/Pearl; depois compila o Seafoam Settings. Todos os caminhos DINX de execução de terminal usam Deetty. O build do pacote Deetty executa os marcadores de smoke PTY/VT/sessão fixados, a qualificação com contabilização do allocator, compatibilidade de protocolo/Unicode, `scripts/deetty_p2_qualification.sh` e `scripts/dintor_p3_qualification.sh` em ReleaseSafe. A matriz P3 comprova o caminho nativo do editor nos dois esquemas empacotados, uma resposta real de símbolo do `clangd` e marcadores limitados de status/diff do Git. Usa tmux real com shim determinístico de Zellij, Nano/Less/Dialog reais, top/watch/whiptail/fzf/SQLite/Glances/Bash/man/SFTP local e a qualificação de projeto/editor do Dintor.
O patch de identidade atualiza os smokes upstream de tarefas e LSP do `clangd` para executar o binário renomeado `zig-out/bin/dintor`; o contrato de integração verifica que nenhum dos dois smokes usa o caminho antigo do executável `nocted`.
7. executa o probe de pré-requisitos do host;
8. constrói a ISO com `buildiso`;
9. valida os payloads SquashFS do root e da sessão live, incluindo a regra tmpfiles dos logs Dinit no rootfs e as substituições de remontagem da raiz exclusivas do livefs;
10. gera o checksum SHA-512;
11. executa `scripts/qualify-iso.sh`: verifica metadados, checksum, payload e limites; inicializa/captura VGA padrão e Virtio-VGA no QEMU; depois simula instalações BIOS/UEFI usando o mesmo rootfs, verifica pacotes e serviços Dinit instalados e usa OCR no TTY 2 de recuperação. Essas simulações não executam a GUI nem os módulos de particionamento do Calamares de ponta a ponta;
12. cria atestações de artefato GitHub para a ISO e o checksum;
13. publica ISO, checksum, logs QEMU e capturas PPM como artefato temporário do workflow.

O builder Artix é uma imagem separada baseada no digest Artix fixado. `scripts/iso-builder/packages.txt` define as dependências; no CI, Buildx persiste as camadas com cache GitHub Actions, e a data UTC diária força a atualização periódica dos pacotes. O build local reutiliza as camadas Docker. O wrapper verifica labels, digest e identidade da imagem antes do container privilegiado.

Os logs incluem preparação de fontes, contratos, pré-requisitos do host, imagem do builder, cada pacote (cache hit/miss), repositório, montagem e qualificação pós-build. Localmente, ficam em `dist/local-iso-<UTC>-<pid>/dinx-build.log`; no P0, `dist/dinx-build.log` é publicado nos diagnósticos. Os caches GitHub Actions são separados em artifacts DINX assinados, fontes/Cargo/Zig de build e toolchains Zig baixados/extraídos. A chave externa usa o digest de arquivos rastreados; snapshots recebem chave por execução somente quando o marcador da categoria indica mudança, evitando republicar toolchains ao alterar apenas fontes de compilação. Os hits de pacotes são revalidados e assinados com a chave efêmera atual. Os três pacotes opcionais de hardware são compilados em paralelo à montagem e entram no banco assinado final. O primeiro build é frio; nenhuma redução de tempo foi medida ainda.

O repositório pacman temporário é assinado dentro do builder com uma chave CI efêmera. O workflow registra o snapshot do conteúdo dos pacotes, os checksums do banco/chave do repositório e o fingerprint da assinatura em `build-metadata.txt`, depois verifica todas as assinaturas e os caminhos duplicados dos archives antes de o `buildiso` consumir o repositório. Isso qualifica o contrato do build; não é a chave do repositório de produção nem um canal de atualização do sistema instalado.
Apenas a configuração pacman temporária do `buildiso` Artix define `DownloadUser = root`: o downloader `alpm` do pacman 7 não consegue gravar no diretório de staging do banco sync pertencente a root em uma nova rootfs basestrap. Isso não altera a configuração pacman do host nem a imagem instalada.
As instalações locais com `pacman -U` tentam até três vezes e atualizam os bancos do repositório entre as tentativas; uma falha na atualização encerra a transação. `makepkg --clean` é omitido somente para DinitUI, DINXPanel e Seafoam Settings, pois essas receitas compilam a partir de árvores `src/` versionadas. `scripts/smoke_pacman_local_install.sh` cobre sucesso inicial, recuperação, falha após as tentativas e falha na atualização do banco.
O builder agora valida o ambiente da imagem fixada antes do `docker run` e novamente dentro do container, portanto a geração dos metadados não prossegue com a identidade da imagem ausente.
O wrapper de compactação da ISO impõe o preset xz suportado pela ferramenta com BCJ x86, blocos de 256 KiB e dicionário de 256 KiB, além de excluir fontes do kernel, caches de pacotes pacman e logs de build. O workflow registra o schema de compactação e o checksum do wrapper em `build-metadata.txt`; `check_build_metadata.sh` os vincula ao wrapper versionado. As ferramentas SquashFS exclusivas do build ficam no builder e não são copiadas para o payload de runtime.
Como o `buildiso` do Artix pode chamar `/usr/bin/mksquashfs` diretamente, o workflow privilegiado preserva o binário real, instala o wrapper DINX nesse caminho absoluto, exporta o caminho do binário real e rejeita recursão para o próprio wrapper. Depois da montagem, `check-iso-content.sh` lê os superblocos das duas imagens SquashFS e verifica xz com blocos de 256 KiB, em vez de confiar apenas na intenção dos argumentos.

O smoke de instalação verifica no disco o banco pacman, pacotes centrais, payload/versão do ZLS, bibliotecas de DinitUI/DINXPanel/Dome/Seafoam/ZLS e a ausência de WIZP/CUPS antes do boot. Depois verifica a saída real de boot de NetworkManager, elogind e `local.target` e usa OCR para confirmar o prompt de login no TTY de recuperação; não usa marcador sintético de primeiro boot nem afirma qualificação end-to-end do Calamares.

DinitUI é compilado de `distro/packages/dinitui` com Zig 0.17.0 contra GTK4/libadwaita, enquanto a DINXPanel é compilada de `distro/packages/dinxpanel`; os dois pacotes são adicionados ao repositório pacman temporário e instalados pelo perfil DINX. `scripts/check_dinitui.sh` valida o contrato de backend do DinitUI; `scripts/check_dinxpanel.sh` valida o centro de controle inspirado no YaST, os atalhos fixos, os lançamentos por argv direto, a ponte fixa de GPU e o catálogo seguro de kernels antes do build do container.
O relatório de upgrades da DINXPanel usa o caminho somente-leitura `sync`/`list-updates all` do Shelly e, opcionalmente, `fwupdmgr refresh`/`get-updates`; o preview do Topgrade é `topgrade --dry-run --show-skipped --no-self-update --no-tmux`, e aplicar Topgrade ou Shelly continua sendo uma ação explícita no terminal.
`scripts/dinitui_dinit_qualification.sh` inicia um daemon Dinit de usuário temporário real, valida `list`/`status`/`stop` e executa o smoke GTK do DinitUI de produção contra esse socket. Exige binários Dinit e `xvfb-run`; fica separado de propósito do gate do container privilegiado da ISO. O pacote DinitUI e seu contrato direto de estado de perfis são verificados sem plugin de shell ou configuração privada de shell.
O perfil de serviços gaming preserva por padrão Bluetooth/controles e os serviços de firewall/política de processos; não troca segurança por ganho de benchmark não medido. O launcher standalone oculto `dinx-gaming` usa o backend DRM nativo do Gamescope. Gamescope, Steam, regras de dispositivos Steam, GameMode, MangoHud e bibliotecas de 32 bits pertencem ao grupo opcional `gaming` e ficam fora de rootfs/livefs; RADV e ferramentas Vulkan de 64 bits continuam na base. O usuário pode optar por instalar após a instalação do sistema usando a configuração Artix `[lib32]` em `docs/pt-BR/install.md`. O P0 instala Gamescope somente dentro do builder para qualificação headless; não habilita `[lib32]` nem adiciona repositórios Arch, e o launcher verifica Gamescope/Steam antes de alterar perfis. A DINXPanel é dona das ações visíveis de GPU e delega ao DinitUI a detecção fixa por `lspci -nnk` e planos por fabricante; seu instalador oferece somente `linux`, `linux-lts`, `linux-zen` e `linux-hardened` com headers correspondentes, nunca remove pacotes, protege o kernel em execução e exige reinicialização. `scripts/check_gaming.sh` roda antes do build do container e `scripts/gaming_p5_qualification.sh` continua sendo o gate local/runtime; seu fixture não autentica Steam nem declara jogo comercial, hardware de controle/áudio, saída DRM ou suspend/resume.
O smoke GTK isolado do Dintor renderiza os fallbacks de ícone para PNG com `rsvg-convert` e usa um tema `DintorSmoke` autossuficiente com apenas o fallback padrão `hicolor`: o GTK3 não precisa dos assets SVG herdados do Adwaita do container, de loaders XPM legados nem da configuração externa de loaders do tema. O container Artix instala explicitamente Glycin, bubblewrap e `shared-mime-info`, reconstrói o banco MIME e atualiza o cache do GdkPixbuf antes do build do pacote. A qualificação de build do Deetty desativa apenas o sandbox aninhado do Glycin porque já executa dentro do container privilegiado; o runtime empacotado mantém a dependência de bubblewrap e não herda essa configuração. Assim, o fixture não transforma essa diferença de empacotamento em uma falha falsa do release.

### Qualificação local P4/P5

Os gates locais passam o contrato do pacote DinitUI, um daemon Dinit de usuário temporário real com smoke GTK e o fixture da sessão gaming com lançamento/saída headless do Gamescope. O workflow marcado [41197618617](https://github.com/rufl/DINX/actions/runs/41197618617) publicou a Alpha 12 após passarem os contratos de pacote/perfil, build Artix, captura gráfica QEMU com VGA padrão, transações Calamares BIOS/UEFI/Btrfs, smokes de instalação/recuperação em discos BIOS/UEFI descartáveis, vínculo de metadados, atestação e publicação. Essa execução não exercitou VMware-SVGA nem VirtualBox VMSVGA. O qualificador compartilhado atual testa VGA padrão e Virtio-VGA; no QEMU 11.1.2/KVM, `vmware-svga` trava no udev inicial quando `vmwgfx` carrega e não representa evidência de VirtualBox. O boot direto no VBox continua sem qualificação. Os limites P5 de DRM real, Steam/jogos autenticados, controle/áudio e hardware físico continuam abertos.

A verificação de payload da Alpha 9 historicamente confirmou Gamescope, Steam e pacotes gráficos de 32 bits naquele artefato publicado; essas afirmações de presença não descrevem o novo perfil base. Os checks P0 atuais exigem o launcher/entrada gaming ocultos e rejeitam binários e metadata dos pacotes opcionais nas imagens rootfs e livefs. O contrato de armazenamento continua exigindo o serviço dinit do Pori em `/etc/dinit.d`, `ntfs3` para leitura/escrita live, `ntfs-3g` pós-instalação opcional, File Roller e GParted, enquanto rejeita Thunar, GVFS, Tumbler e KDE Partition Manager. Também confirma o agente PolicyKit independente e rejeita metadata/runtime do init systemd mantendo dinit.
A verificação de payload também prova Firefox, sua entrada desktop, os manipuladores padrão de HTML/XHTML/HTTP/HTTPS e `/etc/firefox/policies/policies.json`. Essa política remove superfícies patrocinadas do navegador, Pocket/Stories, Firefox Studies e telemetria, recomendações do navegador, superfícies de assistente de IA/preview de links/grupos de abas e o IP Protection integrado sem desabilitar atualizações normais ou Firefox Accounts iniciado pelo usuário.
O mesmo contrato prova o payload desktop expandido: btop/nvtop/inxi, diagnóstico PCI/USB, Git/curl/less/jq/rsync, Zathura com MuPDF, Swayimg, VLC com seus componentes GUI/CLI Qt, Gapless (G4Music), Galculator, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor`, `wl-clipboard`, o backend SANE `scanimage`, `fwupdmgr`, o runtime Flatpak e KolourPaint. O contrato da ISO exige o binário e a entrada desktop do Galculator; ele é uma calculadora compacta em GTK 3 que usa a pilha GTK existente. O contrato valida o pacote v4.6.2 fixado do Gapless, as dependências de codecs GStreamer base/good, o default de reprodução sem intervalos, os metadados de ativação D-Bus e os handlers MIME de áudio; o aplicativo upstream também oferece controles MPRIS. O check rejeita binários, entradas desktop e metadata de pacote do Strawberry. Confirma ainda as superfícies do shell Pearl, o host do Pearl Greeter e os handlers MIME DINX. O Swayimg continua sendo o visualizador padrão; o KolourPaint fornece edição simples de imagens sem alterar esse default. O contrato visual usa configuração estática DINX para GTK/Qt, sem plugin de shell.

O contrato de display também exige os binários base `wdisplays` e `shikane`, além do wrapper de persistência `dinx-wdisplays` e do salvador de perfil nomeado DINX. O payload Seafoam base inclui o Seafoam Settings, um launcher nativo em Zig/GTK4 com argv fixo, o Dome com fonte fixada no Pearl v0.3.0 e o pacote oficial ZLS 0.16.0 com fonte fixada usado pelo Dintor para LSP Zig. Os pacotes Zig nativos da DINX são compilados com Zig 0.17.0; o pacote ZLS carrega apenas a árvore `lib/std` correspondente do Zig e seu shim somente de metadados; a ISO base não instala compilador Zig completo nem systemd, e o workflow testa completion/navegação reais antes de montar a ISO. O workflow compila os três no repositório de pacotes DINX assinado, e o perfil da ISO exige seus binários, metadados desktop, ícones e documentação.
Os smokes Seafoam rodam dentro do builder Artix após a instalação dos pacotes; não são etapas separadas executadas no host pelo workflow.
O contrato da sessão compila e instala Aqueous 1.0.5 e Pearl 0.3.0, verifica que `Aqueous + Pearl (DINX)` é a única entrada selecionável do greeter e prova o ciclo de vida direto sobre dinit: o Aqueous lança o filho init da DINX, que espera Wayland e D-Bus da sessão; então o supervisor inicia Shikane, PolicyKit, o idle obrigatório e Pearl. O daemon opcional BC-250 inicia somente quando o usuário instala separadamente o pacote assinado após detectar PCI `1002:13fe`; esses pacotes não fazem parte da ISO genérica. As receitas removem `uwsm` e unidades systemd de usuário upstream; o build do Aqueous remove a biblioteca systemd e as verificações de atividade por D-Bus, substituindo-as por verificações de pidfd, executável e ambiente para lançamentos diretos sobre dinit. O host do Pearl Greeter executa somente o Pearl Greeter, e nenhum servidor, driver ou payload Plasma X11 legado de Xorg/XLibre é aceito na ISO runtime; XWayland e Xvfb exclusivo do builder continuam disponíveis.
O contrato de gerenciamento também prova `topgrade`, `paru` e Shelly. Topgrade usa um binário de release upstream fixado com a configuração pacman do Artix da DINX; paru é compilado a partir do release fonte fixado contra o ALPM do Artix; o Shelly delega para a configuração `pacman` do Artix. Os arquivos de configuração e desktop AUR do Shelly ficam fixados na revisão imutável `f89d773125357baaa1d2fae715286ce9e00e2cb4`, mantendo os checksums; a branch móvel `shelly-bin` não é usada. Os metadados não contêm dependência ou unidade `systemd`, nenhum repositório Arch é adicionado e toda receita AUR continua sujeita à revisão explícita do usuário. Eles continuam sendo executados pelo usuário; a ISO não executa upgrades automaticamente.
O contrato de hardware confirma que o firmware AMDGPU genérico, Mesa RADV e diagnósticos Vulkan continuam na ISO base. O governor Cyan Skillfish e o BC250 Control Center permanecem pacotes fixados e compiláveis no repositório DINX assinado, mas o grupo `hardware` usa `iso:false` e a verificação de conteúdo rejeita seus binários, serviços e metadata pacman nas duas imagens genéricas. Instale-os somente após confirmar o PCI `1002:13fe`; o comportamento em runtime continua sendo uma qualificação em hardware físico.
O mesmo contrato da ISO prova UFW, Gufw, Qps, OpenSnitch e os arquivos de serviço dinit `ufw`/`opensnitchd`. Ele confirma o default seguro (`ENABLED=no` e nenhum link de boot para os dois serviços de firewall), portanto mudanças de política de rede exigem configuração explícita do usuário.

A qualificação QEMU captura duas superfícies em VGA padrão e Virtio-VGA: o OCR precisa ler o título `Dock` da janela GTK4 de configuração inicial Pearl e, depois, o quadro da sessão Aqueous/Pearl precisa conter um marcador Pearl/Aqueous/DINX e rejeitar Pearl Greeter, consoles TTY, prompts de login, campos de senha/entrada e falhas visíveis do Dinit. O primeiro check detecta uma superfície GTK de cliente preta; o segundo confirma o início da sessão. Nenhum deles prova a renderização de todos os aplicativos, boot no VirtualBox, rede, áudio ou saúde prolongada dos serviços.

Releases por tag reutilizam o mesmo artefato de build por meio de `.github/workflows/release.yml`. O job de release publica a ISO ou partes ordenadas abaixo de 2 GiB, o SHA-512 completo, as evidências do QEMU Linux e um pacote launcher Windows pequeno. O launcher baixa a URL HTTPS fixada nos metadados e, quando necessário, cada parte ordenada, verifica as partes e o SHA-512 completo e então executa `scripts/smoke-iso.ps1` com QEMU no Windows. Os metadados ZTASH apontam para o receptor registrado `ddjarin` sem embutir credenciais.

O pacote `dinx-live-autologin`, exclusivo do livefs, substitui `root-ro` e `early-root-rw.target` por no-ops para o overlay já gravável. Seu serviço Dinit habilitado no boot grava e aplica o hostname `dinxlive`, cria a configuração única da sessão inicial Aqueous/Pearl e declara `before = greetd` e `before = login.target`; como ambos são ativados no boot live, o Dinit conclui a configuração antes do serviço upstream `greetd-dinit`, sem instalar um segundo pacote dono de `/etc/dinit.d/greetd`. O Calamares instala `rootfs.img`, então o sistema instalado mantém as unidades genéricas de remontagem do Artix e o greetd de login manual.

Os wrappers gráficos da sessão e do greeter compartilham uma política. Cada render node DRM acessível é associado ao próprio driver sysfs. QEMU `virtio_gpu` com render node legível/gravável seleciona `aqueous-cpu` e GLES2 no wlroots; a seleção de renderer GTK4 fica automática. VirtualBox `vmwgfx`/`vboxvideo` e sistemas sem render node acessível selecionam o Aqueous completo com `WLR_RENDERER=vulkan` e `GSK_RENDERER` sem override, seguindo a política wlroots Vulkan-only do Devario; `vulkan-swrast` está empacotado. QXL e outros adaptadores 2D com render node mantêm o perfil CPU de compatibilidade. Os patches DINX de cantos arredondados no caminho de buffers de cena Pixman foram removidos. O qualificador atual testa VGA padrão e Virtio-VGA; o QEMU 11.1.2/KVM com `vmware-svga` trava no udev inicial quando `vmwgfx` carrega, portanto esse caminho não representa o VirtualBox. O boot direto no VBox ainda precisa de qualificação.

O perfil controla o contrato visual DINX em `/usr/share/dinx/theme/DINX.json`. `scripts/check_dinx_theme.sh` valida a paleta estática, `DINX_COLOR_SCHEME`, as bridges GTK/Qt, o Pearl Greeter, Calamares e GRUB antes do `buildiso`; `scripts/check-iso-content.sh` verifica os mesmos arquivos dentro da imagem SquashFS do root.

Para capturas gráficas locais, instale QEMU, `socat`, `tesseract-ocr` e `tesseract-ocr-eng`; então defina `DINX_QEMU_BOOT_KEYS=down,down,ret`, `DINX_QEMU_SCREENSHOT` e, opcionalmente, `DINX_QEMU_SCREENSHOT_DELAY` antes de executar `scripts/smoke-iso.sh`. `DINX_QEMU_PLYMOUTH_SCREENSHOT` faz novas capturas por até `DINX_QEMU_PLYMOUTH_WAIT_SECONDS` (padrão 30); o OCR rejeita o menu GRUB antes de verificar os pixels centralizados do logo DINX. As esperas configuradas devem caber em `DINX_QEMU_TIMEOUT`; a qualificação usa uma janela QEMU de 110 segundos.
Sem `DINX_QEMU_SCREENSHOT`, o smoke salva o quadro verificado ao lado do log QEMU como `<iso>.qemu.log.session.ppm`. `DINX_QEMU_OCR_LANG` seleciona outro modelo de idioma Tesseract instalado, se necessário.
Defina `DINX_QEMU_PLYMOUTH_SCREENSHOT` para validar e capturar o logo durante o boot; `DINX_QEMU_PLYMOUTH_WAIT_SECONDS` limita a espera após a captura do GRUB/teclas. A qualificação completa grava `dinx-plymouth-screen.ppm` e `dinx-virtio-vga-plymouth-screen.ppm` ao lado da ISO e verifica se o initramfs contém o tema DINX.

Para solicitar virgl no host em um smoke gráfico local com QEMU, o QEMU do host precisa ter suporte a GTK/OpenGL e virgl:

```sh
DINX_QEMU_DISPLAY=gtk,gl=on \
DINX_QEMU_VIDEO_DEVICE=virtio-vga-gl \
scripts/smoke-iso.sh /caminho/para/dinx.iso
```

A política atual do VirtualBox seleciona Aqueous completo com `WLR_RENDERER=vulkan` para `vmwgfx`/`vboxvideo`; o GTK4 seleciona o próprio renderer automaticamente e `vulkan-swrast` continua empacotado como ICD Vulkan por software. O código não comprova se a aceleração 3D do VirtualBox precisa estar habilitada. A Alpha 12 publicada é anterior a essa política de renderer. O smoke Virtio-VGA do QEMU valida outro caminho gráfico live, não o driver VMware nem o boot direto no VBox; a validação direta ainda exige uma ISO nova.

A qualificação completa captura `dinx-boot-screen.ppm` três segundos após abrir o QEMU e, durante o boot automático, espera pelo logo Plymouth centralizado antes de gravar `dinx-plymouth-screen.ppm` (e a captura equivalente em Virtio-VGA). O validador rejeita OCR do menu GRUB e logos na posição de canto do GRUB. As capturas gráfica e pós-sessão continuam sendo evidências separadas do desktop.

O GRUB usa cores DINX de superfície, primeiro plano e seleção; o tema ativo exibe o novo símbolo DINX em gradiente no lugar do logo upstream, preserva ícones e fontes do pacote e desativa texturas opacas do menu. Assim, as telas de boot evitam referências visuais à marca Artix sem renomear o caminho interno exigido pelo pacote.

Na ISO baixada do Devario, o menu GRUB também é textual; o logo gráfico aparece após o handoff do kernel via Plymouth. A DINX mantém suas duas opções de boot live e o timeout visível de seis segundos, depois usa o Plymouth do Artix com o mesmo símbolo do GRUB. As opções do kernel incluem `quiet splash`, o hook mkinitcpio adiciona Plymouth após `udev` e um serviço Dinit encerra o splash quando o `greetd` inicia; sem integração systemd/UWSM.

O perfil também incorpora um caminho experimental offline do Calamares com branding DINX e módulos de serviço dinit; o Pori é a única interface gráfica de armazenamento e o Phyto é o gerenciador de arquivos padrão. A verificação de conteúdo confirma a configuração do instalador, os defaults estáticos de tema/paleta DINX, o Pearl Greeter, a sessão Aqueous/Pearl forçada e os payloads de recuperação. `scripts/smoke-install.sh` verifica instalações BIOS e UEFI offline, a geração de initramfs/GRUB, o primeiro boot e a TTY de recuperação em discos efêmeros; é um smoke de contrato do CI, não uma qualificação arbitrária de hardware.
O contrato de particionamento do Calamares é verificado antes do build do container: ESP recomendada de 1 GiB/mínima de 64 MiB, EFI FAT32 e root ext4/btrfs, particionamento manual explícito, LVM desabilitado, exceções de montagens live, remoção de pacotes offline, suporte de leitura/escrita pelo `ntfs3` do kernel, `ntfs-3g` opcional pós-instalação, suporte a `os-prober` e um plano Btrfs explícito de nível superior que não recria `@`/`@home` existentes. `scripts/smoke_calamares_partitioning.sh` faz round-trip das tabelas BIOS e UEFI, filesystems e fstab em discos descartáveis e reabre um volume Btrfs com subvolumes existentes. `scripts/smoke_calamares_windows.sh` preserva uma ESP FAT32/caminho Microsoft e partição NTFS de Windows existentes enquanto conclui transações DINX de root/GRUB em layouts side-by-side e manuais. São smokes transacionais dos layouts suportados, não uma alegação de que todos os caminhos de filesystem, criptografia, RAID, BitLocker, hibernação, firmware Windows ou firmware físico do Calamares estejam livres de bugs.

Para uma segunda captura diagnóstica após o boot, defina `DINX_QEMU_POST_SCREENSHOT` e, opcionalmente, `DINX_QEMU_POST_SCREENSHOT_DELAY`. Deixe `DINX_QEMU_POST_KEYS` sem definir no caminho normal de autologin. Um quadro posterior prova apenas que o QEMU renderizou outro ponto da sessão.


## Última execução de release publicada

A execução marcada [41197618617](https://github.com/rufl/DINX/actions/runs/41197618617) para `v0.1.0-alpha.12`, no commit `56a814575e33bfae6215993972784f11b7dae215`, concluiu com sucesso todas as etapas do workflow:

- contratos de pacote/perfil e first-party, incluindo apps nativos e procedência dos pacotes, passaram antes do build Artix;
- builds dos pacotes e `buildiso` compacto concluíram; conteúdo/tamanho da ISO e vínculo dos metadados/digest passaram;
- as transações de particionamento Calamares e o boot/captura gráfica no QEMU com dispositivo VGA padrão passaram; essa execução não exercitou VMware-SVGA nem VirtualBox VMSVGA;
- smokes de instalação persistente, primeiro boot e TTY de recuperação passaram em discos BIOS e UEFI descartáveis;
- repositório DINX assinado, preflight do release, SHA-512, atestação de procedência GitHub e publicação passaram;
- a ISO direta publicada tem 1.836.830.720 bytes e SHA-512 `ac1dbd237e484f8d61aab5438185218b13d9e23824ce671440ff67ed275ce7073b90dbcc14bc8d8f7008b2422d66e2756f1b3a88a0d5c21d8c7bbc67c9d60bf9`; snapshot do repositório assinado `37dfe99d5e4003e217e786ef82c8ea29562693db2d44b996a9624a68f31c490d`.

Isso encerra o caminho P4 DinitUI e de instalação/recuperação descartáveis para o gate do alpha de sistema. Não prova uso autenticado de Steam/jogo, saída gaming DRM real, hardware de controle/áudio, instalação física, firmware, atualização, rollback do filesystem, redimensionamento de Windows com BitLocker/hibernação nem saúde de hardware por longo prazo.

## Validação P0 histórica da main após a Alpha 10

A execução [40894570770](https://github.com/rufl/DINX/actions/runs/40894570770), no commit da main `bf773500965c843e014e3bc3ef8fea685e14b91b`, passou pelo workflow P0 completo: contratos de pacotes, build Artix, checks da ISO, boot gráfico no QEMU, transações Calamares, instalação persistente BIOS/UEFI, TTY de recuperação, metadados, atestação e upload do artefato. Foi uma validação anterior da main após a Alpha 10; não exercitou VMware-SVGA nem publicou/substituiu a Alpha 12 posterior da execução marcada [41197618617](https://github.com/rufl/DINX/actions/runs/41197618617).

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

O host de desenvolvimento é EndeavourOS x86_64. A toolchain `buildiso` do Artix roda somente no container com digest fixado; não instale pacotes de build do Artix nem `mkinitcpio` no host. O build local exige um Docker Engine rootful acessível, com suporte a containers privilegiados e dispositivos loop.

## Build local com Docker

Execute na raiz do checkout DINX:

```sh
bash scripts/build-iso-docker.sh
```

Se o archive ignorado de Deetty estiver ausente, o script o prepara a partir de um checkout no commit upstream fixado. Defina `DEETTY_SOURCE_CHECKOUT` para esse checkout; o commit e o SHA-256 do archive gerado são verificados.

```sh
DEETTY_SOURCE_CHECKOUT=/caminho/para/DEETTY bash scripts/build-iso-docker.sh
```

O build do pacote Deetty limpa a árvore de fontes em cache antes de aplicar patches. Uma tentativa com falha não deixa fontes modificadas que quebrem a próxima execução.

Requisitos: Docker rootful acessível, suporte a `--privileged` e dispositivos loop, rede e espaço livre para o rootfs/ISO. Por padrão, o build local executa a qualificação completa usada pelo workflow P0. Isso também exige os comandos listados em `scripts/check-iso-qualification-host.sh full`, QEMU com o dispositivo `virtio-vga`, Tesseract com o modelo `eng`, firmware OVMF e `sudo` (ou root). Confira antes de começar:

```sh
scripts/check-iso-qualification-host.sh full
```

O builder local reutiliza artefatos verificados em `dist/.cache/dinx`: archives fixados dos toolchains Zig, archives pacman, fontes makepkg, registry Cargo, alvos Cargo por pacote, cache global Zig e archives DINX identificados pelo conteúdo. A chave interna de cada pacote cobre fontes declaradas, builder, implementação do cache, configuração/opções makepkg, pacotes instalados e ambiente explícito; saídas geradas são excluídas. Os archives são validados e assinados com a chave atual. Somente resultados `makepkg` bem-sucedidos são publicados atomicamente, e o cache retém no máximo uma chave de artefato por pacote; entradas históricas não são consultadas. O P0 restaura caches por prefixo e salva snapshots separados por categoria e execução somente quando marcadores indicam alteração, inclusive após build parcial; contratos não persistem caches. Rootfs, repositório final e ISO continuam sendo gerados e qualificados a cada execução.

O modo reduzido é explícito e **não** qualifica boot/instalação:

```sh
DINX_ISO_QUALIFICATION=static bash scripts/build-iso-docker.sh
scripts/qualify-iso.sh --static /caminho/para/dinx.iso
```

Somente para depuração do build, `DINX_SKIP_POSTBUILD_CHECKS=1` pula toda a qualificação da ISO. Esse artefato não está qualificado; execute `scripts/qualify-iso.sh` no modo completo antes de usá-lo ou publicá-lo.

Para executar novamente os mesmos gates completos sobre uma ISO com `build-metadata.txt` ao lado do arquivo:

```sh
DINX_EXPECTED_COMMIT=$(git rev-parse HEAD) scripts/qualify-iso.sh /caminho/para/dinx.iso
```

`DINX_LOCAL_BUILD_DIR` pode selecionar um diretório de saída novo e vazio dentro de `dist`; resultados existentes nunca são sobrescritos. `DINX_BUILD_CACHE_DIR` pode apontar para outro diretório de cache dentro de `dist`.

O builder emite `dinx-build-timing` para cada pacote, incluindo `cache=hit` ou `cache=miss`, a preparação do pacman do builder, a montagem da ISO e a duração total do container. Compare logs equivalentes antes de afirmar redução de tempo; hits quentes no cache de pacotes evitam recompilar pacotes DINX inalterados, enquanto os caches de downloads e Cargo reutilizam suas respectivas entradas/saídas. `scripts/qualify-iso.sh` local grava logs QEMU e capturas PPM ao lado da ISO.

Ao sair do container, o builder encerra o servidor temporário do repositório e restaura a propriedade do host nos diretórios montados da ISO, dos pacotes, da árvore de build e das fontes de pacotes. Assim, a etapa P0 de checksum e as verificações locais pós-build conseguem gravar nos diretórios de saída.

A validação local pós-build usa o commit e a árvore de fontes capturados antes de iniciar o Docker. Árvores makepkg, archives de pacotes e saídas de staging gerados são excluídos do fingerprint; alterações em fontes rastreadas ou não rastreadas continuam invalidando a validação.


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
