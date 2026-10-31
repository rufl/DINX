# Roadmap da DINX

[Português (Brasil)](roadmap.md) · [English](../roadmap.md)

Os marcos são gates de capacidade, não promessas de calendário.

## Estado atual

**Release de sistema publicado:** [DINX v0.1.0-alpha.12](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.12), gerada a partir de `56a814575e33bfae6215993972784f11b7dae215` pelo [workflow de release #41197618617](https://github.com/rufl/DINX/actions/runs/41197618617). A ISO medida tem 1.836.830.720 bytes (abaixo do limite de 2 GiB por arquivo do GitHub); [baixe a ISO pelo link permanente](https://github.com/rufl/DINX/releases/download/alpha-latest/dinx-latest-x86_64.iso) e o [checksum SHA-512](https://github.com/rufl/DINX/releases/download/alpha-latest/dinx-latest-x86_64.iso.sha512).

**Próximo release de sistema:** Beta 0.1 está planejada, ainda não foi publicada e não tem data. É um marco de qualificação de hardware físico, instalação, atualização e recuperação; veja os critérios de saída abaixo. A qualificação gaming P5 continua separada e não significa que a Beta 0.1 esteja pronta para jogos.

As tags `v0.1.0-alpha.12` e `alpha-latest` apontam para o mesmo commit-fonte, e os arquivos ISO e checksums SHA-512 são iguais. O workflow com tag é a evidência do artefato publicado; commits posteriores somente de documentação na `main` não alteram esse artefato.

## Objetivo do produto

A DINX busca ser um desktop Artix Linux amigável para iniciantes e pensado para iniciar pela sessão live: entrar direto em Aqueous/Pearl sem pedir login na live; oferecer janelas flutuantes familiares, com barra de título, controles e encaixe nas bordas/cantos; incluir um conjunto focado de aplicativos cotidianos; e simplificar a instalação pelo Calamares, com opções de instalação guiada ou manual e swap opcional. O desenho permanece de sessão única e somente dinit: sem systemd ou UWSM. A distribuição é entregue em uma ISO x86_64 para download direto, abaixo do limite de 2 GiB por arquivo do GitHub.

A Alpha 12 é um marco experimental, não uma afirmação geral de suporte a hardware. O CI verificou a sessão gráfica no QEMU e os caminhos de instalação/recuperação do workflow; a cobertura em máquinas físicas e o boot direto no VirtualBox VMSVGA continuam sem qualificação. O comportamento entre todos os toolkits também é um gate da Beta, não uma garantia universal.

## P0 — fundação

**Objetivo:** produzir uma sessão live Artix+dinit reproduzível e definir o caminho de instalação persistente.

**Status:** o gate de fundação ISO/VM está concluído e foi exercitado pelo workflow de release marcado da Alpha 12: passaram as verificações de pacote/repositório assinado, build da ISO e metadados de tamanho/checksum, boot gráfico no QEMU, transações do Calamares e verificações de instalação persistente/recuperação em BIOS/UEFI descartáveis. Rotação/revogação da chave de assinatura de produção, hardware físico, boot direto no VirtualBox, upgrades da ISO instalada, rollback do filesystem e saúde de serviços em hardware por longo prazo continuam gates de release.

Implementação entregue:

- o gate da fundação ISO/VM P0, o caminho de transações de pacotes assinados e o contrato de TTY de recuperação;
- a sessão Aqueous/Pearl direta, o Pearl Greeter pelo greetd e o runtime somente dinit, sem systemd/UWSM;
- os defaults Fish, o limite do payload base e os smokes de build limpo/VM;
- A sessão live inicia Aqueous/Pearl sem pedir credenciais; sistemas instalados usam Pearl Greeter e não habilitam autologin. Aqueous/Pearl é a única sessão, iniciada e supervisionada diretamente pelo dinit, sem payload de systemd ou UWSM.
- Novos perfis começam com dois workspaces e janelas flutuantes/stacking. O compositor fornece barras DINX, controles de minimizar/maximizar/fechar, arraste pela barra e encaixe nas bordas/cantos; a compatibilidade com todos os aplicativos GTK, Qt e XWayland ainda precisa ser qualificada.
- Fish é o shell padrão e Deetty o único emulador de terminal. A lista base inclui Dintor, Phyto, File Roller, GParted, Pori, Gapless, wdisplays/Shikane, Dome, Seafoam Settings e ZLS, além das ferramentas DINX de controle/diagnóstico.
- GTK 3/4 usa o tema escuro DINX por padrão; a identidade visual do sistema não substitui ícones de aplicativos nem da área de trabalho. Os sistemas live e instalado usam o `ntfs3` do kernel para leitura e escrita em NTFS, e as alterações de configuração dos monitores podem ser salvas em perfis do Shikane.
- O Calamares oferece particionamento guiado e manual, mantém opções destrutivas desmarcadas e deixa swap opcional. O CI cobre transações do instalador, mas a instalação em discos físicos e alegações de preservação de dados ainda exigem qualificação em hardware.

Gates de release da fundação ainda abertos:

- validar rede, PipeWire, D-Bus, portais, polkit e aceleração de GPU em hardware físico;
- manter e exercitar a recuperação depois de uma falha da sessão gráfica;

**Critério de saída:** um boot live limpo abre uma sessão gráfica, fornece os serviços base necessários e permite recuperação por TTY. O CI executa o contrato de instalação persistente em discos BIOS e UEFI descartáveis e o caminho transacional de pacotes assinados; atualizações da ISO instalada, rollback do filesystem e preservação de dados continuam gates de release.

## P1 — alpha pública

**Objetivo:** distribuir um snapshot conhecido como funcional através do projeto público no GitHub.

**Status:** concluída para o snapshot alpha público `v0.1.0-alpha.12`.

Concluído:

- publicação da ISO direta, SHA-512 correspondente, metadados de build, repositório DINX assinado, assets de procedência/verificação e link permanente de download `alpha-latest`;
- qualificação do instalador persistente experimental e do caminho de recuperação no primeiro boot pelo CI em discos BIOS e UEFI descartáveis;
- definido o Deetty como único emulador de terminal na ISO live e na instalação nova, com defaults funcionais de Fish e dos aplicativos;
- registro explícito do pré-requisito da chave de produção, do limite de hardware e das limitações de recuperação na documentação do release;

Gates de release adiados:

- relatórios de hardware físico e qualificação além da VM;

**Critério de saída:** atendido. Uma pessoa convidada consegue instalar o snapshot alpha pelo release público e pela documentação sem reconstruir o ambiente de desenvolvimento.

## P2 — Deetty
**Status:** concluída. A P2 foi encerrada com a execução P0 final verde registrada em [Status do build P0](p0-build.md).

Evidências de saída da P2:

- o archive upstream NOCTTY exato é fixado por SHA-256, verificado e compilado no pacote DINX `deetty`;
- o core nativo Zig qualifica criação/redimensionamento/saída de PTY, grade/título/paste de VT, saída da sessão de terminal, compatibilidade de protocolo/Unicode, ciclo de vida com contabilização do allocator e fairness em 30 panes com paste de 8 MiB;
- a matriz ReleaseSafe qualifica tmux real, um shim determinístico de Zellij, Nano/Less/Dialog reais, top/watch/whiptail/fzf/SQLite/Glances/Bash/man/SFTP local, Vim/btop reais e o `info` instalado ou seu fallback estilizado determinístico em superfícies mínimas/não-TTY;
- o pacote está presente na ISO; contratos de `$TERMINAL`, defaults do shell, `.desktop`, diretório de trabalho, descoberta do Aqueous/Pearl e runtime do pacote estão verificados;
- a execução P0 final prova criação do pacote, geração da ISO, boot no QEMU, payload gráfico, instalação persistente, TTY de recuperação, atestação e upload do artefato.

Limites mantidos depois da P2:

- o slot do Codex usa um fixture local por default; nenhuma qualificação de Codex autenticado ou rede é alegada;
- Zellij usa um shim determinístico, enquanto tmux é exercitado como aplicativo instalado;
- o comando `info` instalado é tentado primeiro, mas uma superfície mínima/não-TTY pode usar o fallback estilizado;
- configuração da chave de produção, atualizações da ISO instalada, rollback do filesystem, hardware físico e saúde de serviços em produção por longo prazo continuam gates posteriores de release.

Abas, painéis, transparência e detecção de URLs vêm depois da semântica central do terminal.

## P3 — Dintor

**Status:** concluída. A P3 fecha com a fonte upstream NOCTTY fixada, o patch de compatibilidade DINX, o payload do pacote/ISO, o gate de qualificação P3 e o contrato de integração do editor.

Entregue:

- abertura de arquivos e diretórios, árvores de projeto, abas, quick open e navegação determinística;
- buffers de texto confiáveis, seleções, substituição multi-seleção e undo/redo do GTK;
- destaque Tree-sitter/GtkSourceView, folding e comportamento configurável do editor;
- busca no arquivo/no projeto, substituição por fluxos de seleção e atalhos de teclado;
- gerenciamento limitado de processos/clientes LSP com diagnósticos, completion, hover, definições, referências, rename, símbolos e formatação;
- status do Git, diffs unificados e marcadores de alterações no menu Tools e no `--git-probe` headless;
- esquemas estáticos claro/escuro do DINX pelo contrato documentado de ambiente `DINX_COLOR_SCHEME`/`DINTOR_THEME`, mantendo o editor útil independentemente de um shell gráfico;

Gate de release P3:

- `scripts/dintor_p3_qualification.sh` executa endurance do core, escala/deltas do índice, workers, recuperação de estado, tarefas, `clangd` real, smoke GTK nativo X11 nos modos claro/escuro e um fixture Git real;
- `PKGBUILD`, o perfil ISO, `check_deetty_integration.sh` e `check-iso-content.sh` carregam o mesmo contrato Dintor/LSP/Git/tema;
- o workflow P0 continua sendo o gate obrigatório de pacote, ISO, QEMU, instalação persistente, recuperação e atestação.

**Critério de saída:** atendido. Uma pessoa desenvolvedora consegue trabalhar em um projeto Zig ou C/C++, consultar diagnósticos e alterações do Git e editar sem um segundo editor.

## P4 — DinitUI

**Objetivo:** tornar as operações do Dinit compreensíveis, completas e seguras sem importar conceitos do systemd.

**Status:** qualificada para o gate alpha. `zig build test`, builds ReleaseSafe, payloads de pacotes Arch, checks estáticos, um daemon Dinit de usuário temporário real e as superfícies GTK de produção foram qualificados. A execução de release com tag [39924316082](https://github.com/rufl/DINX/actions/runs/39924316082), no commit `0d1698a462d5d5486871a7aa17e9b97352ee9404`, também passou o build do pacote Artix, o payload da ISO, o boot no QEMU, o smoke transacional de particionamento BIOS/UEFI/Btrfs do Calamares, o smoke de instalação persistente/primeiro boot/TTY de recuperação em discos BIOS e UEFI descartáveis, a verificação dos metadados de build, a assinatura persistente de pacotes, a atestação de procedência e a publicação do release. A DINXPanel agora é dona dos controles visíveis de hardware/drivers e do instalador fixo de kernels; a matriz de hardware mais ampla continua sendo um gate de release de produção.

**Entregue:**

- descoberta de serviços carregados e de arquivos de descrição no sistema/usuário;
- status, logs em buffer e linhas de serviço com estado;
- ações de ciclo de vida, boot, dependência, ambiente, sinais e daemon usando o vocabulário próprio do `dinitctl`;
- execução por argv validado, escopos system/usuário e retry explícito por `pkexec` somente após falha de autorização;
- perfis de serviços de sistema `normal`, `lite`, `gaming` e customizados, com editor GTK, persistência e integração CLI;
- controles diretos de perfis de serviços DINX/dinit com atalho Gaming no Control Center e painel de perfis;
- DINXPanel com atalhos fixos de hardware/painéis de controle, ponte para o backend de GPU do DinitUI e catálogo de kernels Artix sem remoção;
- contratos do pacote, metadados desktop, licença e payload da ISO.

## P5 — qualificação gaming

**Objetivo:** tornar a sessão de jogos utilizável de forma repetível.

**Status:** fundação da sessão implementada; o critério de saída gaming não foi atendido. Esta trilha é separada da Beta 0.1 do sistema.

**Entregue:**

- launcher standalone `DINX Gaming` e entrada Wayland oculta continuam disponíveis; Gamescope, Steam, regras de dispositivos Steam e dependências Mesa/RADV/Vulkan de 32 bits ficam no grupo Artix opcional `gaming`, fora da ISO base;
- semântica segura dos serviços Normal/Lite/Gaming, entrada/restauração do perfil com propagação de falhas ao redor do launcher standalone, detecção/planos fixos de drivers GPU para hardware AMD, Intel e NVIDIA moderno e a DINXPanel inspirada no YaST, com atalhos fixos para painéis de controle, ações de upgrade Shelly/Topgrade, descoberta opcional de fwupd e instalador de kernels Artix sem remoção;
- fixture determinístico de argv/retorno do launcher e qualificação real headless de launch/exit de filho do Gamescope;
- checks da ISO exigem launcher/entrada ocultos e rejeitam binários e metadata dos pacotes gaming opcionais no rootfs/livefs;
- GameMode e MangoHud são membros opcionais do grupo; `dinx-gaming` suporta `DINX_GAMEMODE=auto|on|off` e `DINX_MANGOHUD=on|off` opcional sem remover o fallback normal do launcher.
- A ISO inclui `dinx-alpha7-hardware-report` para evidências somente de leitura
  no desktop, laptop e BC-250; as afirmações de hardware continuam manuais.

**Gates de release restantes:**

- saída DRM real e launch/exit repetível de `dinx-gaming` com restauração do perfil Dinit;
- inicialização autenticada do Steam, launch/exit de jogo comercial, entrada de controle e áudio PipeWire;
- suspensão/retomada, recuperação da GPU e testes de atualização em hardware físico.

**Critério de saída:** um jogo pode ser iniciado e encerrado repetidamente sem deixar o desktop quebrado. Os fixtures atuais não alegam esse critério.

## P6 — endurecimento do release

**Objetivo:** tornar cada ISO publicada mensurável, auditável e testável após a instalação.

**Status:** em andamento.

**Entregue:**

- o metadata do build agora vincula o tamanho em bytes e o SHA-512 registrados da ISO ao artefato exato verificado pelo CI e pelo preflight do release com tag;
- o metadata registra os maiores pacotes instalados para que regressões de tamanho tenham um diagnóstico acionável;
- os guias de qualificação em inglês e português agora incluem uma checklist do sistema instalado para persistência de display, leitura/escrita NTFS, Pori, Phyto, File Roller, GParted, TTY de recuperação e comportamento de hardware.
- entregue Aqueous 1.0.5/Pearl 0.3.0 como a única sessão do usuário por wrappers DINX diretos: o autologin live e o greeter iniciam Aqueous, o filho de init inicia os helpers de sessão da DINX e o Pearl, o bootstrap de atividade do Aqueous usa identidade direta de processo dinit e nenhuma unidade upstream de `uwsm` ou systemd de usuário, biblioteca systemd ou runtime systemd é instalada;

**Gates de release restantes:**

- repetir a medição completa da ISO a cada candidata a release; a Alpha 12 estabelece a linha de base medida atual de 1.836.830.720 bytes;
- completar a matriz física de desktop, laptop e BC-250;
- qualificar upgrades da ISO instalada, recuperação do filesystem e rollback;
- fechar os gates reais de DRM, Steam, controle, PipeWire, suspensão/retomada e recuperação da GPU.

## Beta 0.1 — qualificação do sistema

**Objetivo:** qualificar um sistema útil e instalável para hardware explicitamente listado, sem alterar o desenho de sessão única e dinit-only.

**Status:** planejada. A Alpha 12 é o alpha público de sistema atual; a Beta 0.1 ainda não tem data.

**Gates do release:**

- Publicar uma matriz de compatibilidade física com hardware exato e resultados testados de firmware, GPU/display, rede, áudio, Bluetooth e suspensão/retomada. Limitar as afirmações de suporte às máquinas testadas; qualificar BC-250 somente em hardware detectado e testado separadamente.
- Testar instalação guiada e manual em discos físicos descartáveis, incluindo os caminhos UEFI/BIOS suportados, primeiro boot, TTY de recuperação e recuperação após instalação interrompida. Manter swap opcional; nunca exigir criação manual pelo usuário. Documentar limites de Windows/BitLocker/hibernação e não prometer preservação de dados além dos layouts testados.
- Qualificar bootstrap do repositório assinado, verificação de assinaturas, atualizações do sistema instalado e recuperação de pacotes. Decidir se upgrades de ISO instalada e rollback do filesystem serão suportados; caso contrário, declarar que continuam indisponíveis e documentar o caminho de recuperação/reinstalação.
- Validar os serviços base e a sessão nas máquinas declaradas: rede, D-Bus, portais, polkit, PipeWire, aceleração de GPU, persistência de displays, lock/idle e suspensão/retomada. Aqueous/Pearl continua sendo a única sessão, supervisionada diretamente pelo dinit; sem systemd ou UWSM.
- Verificar aplicativos GTK 3/4, Qt 6 e XWayland na sessão Aqueous: barra de título, minimizar/maximizar/fechar, arrastar, encaixar e sobreposição de barras próprias. Registrar exceções por aplicativo em vez de alegar comportamento uniforme sem evidência.
- Passar pelos gates P0 existentes de build, QEMU, Calamares, BIOS/UEFI, recuperação, metadados e procedência. Manter a ISO direta abaixo do [limite de 2 GiB por arquivo de release do GitHub](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases) (`2.147.483.648` bytes); a Alpha 12 mede 1.836.830.720 bytes. Os gráficos no QEMU passaram; o boot direto no VirtualBox VMSVGA ainda não foi qualificado.
- Publicar guias correspondentes em inglês e português brasileiro para instalação, compatibilidade, problemas conhecidos e recuperação, com evidências de teste e casos explicitamente não suportados.

**Fora da afirmação da Beta 0.1:** suporte gaming permanece na trilha P5 separada. Não afirmar suporte a Steam, jogos comerciais, controles, saída DRM real ou áudio gaming até passar pelos gates de hardware. Secure Boot e recuperação física também não são alegados sem testes próprios.

**Critério de saída:** cada classe de hardware listada como suportada passa pela checklist documentada de instalação, primeiro boot, serviços essenciais, display e recuperação; atualizações assinadas têm caminho de recuperação testado; não há bloqueador P0 de release; a ISO atende à meta de tamanho e passa pelo workflow de release com tag. Hardware não testado continua sem suporte, sem certificação implícita por ser x86_64.
