# Roadmap da DINX

[Português (Brasil)](roadmap.md) · [English](../roadmap.md)

Os marcos são gates de capacidade, não promessas de calendário.

## Fase atual

**P5 — beta de jogos (em andamento).** A P4 DinitUI está qualificada end-to-end: implementação, qualificação local de daemon/GTK, payload do pacote/ISO e gate de instalação persistente/recuperação em discos descartáveis passaram. A execução de release com tag [39924316082](https://github.com/rufl/DINX/actions/runs/39924316082), no commit `0d1698a462d5d5486871a7aa17e9b97352ee9404`, é a evidência P0 atual e inclui discos BIOS e UEFI descartáveis, o smoke transacional BIOS/UEFI/Btrfs do Calamares, a verificação dos metadados de build, a assinatura persistente de pacotes e a publicação do release. A P5 continua ativa porque launch autenticado de Steam/jogo comercial, controle/áudio PipeWire, saída DRM real, saída repetível do launcher gaming com restauração do perfil Dinit, suspensão/retomada e testes de GPU/atualização em hardware físico continuam abertos.

Uma validação pós-release da `main`, [execução 39934458077](https://github.com/rufl/DINX/actions/runs/39934458077), passou pelos checks de build, boot, payload gráfico, instalação persistente/TTY de recuperação em BIOS e UEFI, atestação e upload; ela não publicou outro release. A candidata P0 mais recente [execução 40848793262](https://github.com/rufl/DINX/actions/runs/40848793262) gerou uma ISO de 1.862.776.832 bytes e passou no boot/captura QEMU, mas falhou no gate de payload. O check local corrigido passa nesse artefato; os smokes de instalação e a atestação dependem de um novo P0.

## P0 — fundação

**Objetivo:** produzir uma sessão live Artix+dinit reproduzível e definir o caminho de instalação persistente.

**Status:** o gate da fundação ISO/VM está concluído. A publicação do repositório
pacman customizado assinado e a qualificação de instalação/atualização/downgrade de
pacotes estão implementadas no CI; configuração da chave de produção, hardware físico,
atualizações da ISO instalada, rollback do filesystem e saúde de serviços em hardware
por longo prazo continuam gates de release.

Implementação entregue:

- o gate da fundação ISO/VM P0, o caminho de transações de pacotes assinados e o contrato de TTY de recuperação;
- a sessão Aqueous/Pearl direta, o Pearl Greeter pelo greetd e o runtime somente dinit, sem systemd/UWSM;
- os defaults Fish, o limite do payload base e os smokes de build limpo/VM.

Gates de release da fundação ainda abertos:

- validar rede, PipeWire, D-Bus, portais, polkit e aceleração de GPU em hardware físico;
- manter e exercitar a recuperação depois de uma falha da sessão gráfica;

**Critério de saída:** um boot live limpo abre uma sessão gráfica, fornece os serviços base necessários e permite recuperação por TTY. O CI executa o contrato de instalação persistente em discos BIOS e UEFI descartáveis e o caminho transacional de pacotes assinados; atualizações da ISO instalada, rollback do filesystem e preservação de dados continuam gates de release.

## P1 — alpha pública 0.1

**Objetivo:** distribuir um snapshot conhecido como funcional através do projeto público no GitHub.

**Status:** concluída para o snapshot alpha público `v0.1.0-alpha.9`.

Concluído:

- publicação da ISO/partes, checksums, instruções de instalação, problemas conhecidos e metadados de release;
- qualificação do instalador persistente experimental e do caminho de recuperação no primeiro boot pelo CI em discos BIOS e UEFI descartáveis;
- fornecimento do terminal mínimo de fallback e da configuração funcional de shell;
- registro explícito do pré-requisito da chave de produção, do limite de hardware e das limitações de recuperação na documentação do release;

Gates de release adiados:

- relatórios de hardware físico e qualificação além da VM;

**Critério de saída:** atendido. Uma pessoa convidada consegue instalar o snapshot alpha pelo release público e pela documentação sem reconstruir o ambiente de desenvolvimento.

## P2 — Noctty

**Status:** concluída. A P2 foi encerrada com a execução P0 final verde registrada em [Status do build P0](p0-build.md).

Evidências de saída da P2:

- o archive exato do NOCTTY/NoctEd é fixado por SHA-256, verificado e compilado no pacote Artix;
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

## P3 — Nocted

**Status:** concluída. A P3 fecha com a fonte Nocted fixada, o patch de compatibilidade DINX, o payload do pacote/ISO, o gate de qualificação P3 e o contrato de integração do editor.

Entregue:

- abertura de arquivos e diretórios, árvores de projeto, abas, quick open e navegação determinística;
- buffers de texto confiáveis, seleções, substituição multi-seleção e undo/redo do GTK;
- destaque Tree-sitter/GtkSourceView, folding e comportamento configurável do editor;
- busca no arquivo/no projeto, substituição por fluxos de seleção e atalhos de teclado;
- gerenciamento limitado de processos/clientes LSP com diagnósticos, completion, hover, definições, referências, rename, símbolos e formatação;
- status do Git, diffs unificados e marcadores de alterações no menu Tools e no `--git-probe` headless;
- esquemas estáticos claro/escuro do DINX pelo contrato documentado de ambiente `DINX_COLOR_SCHEME`/`NOCTED_THEME`, mantendo o editor útil independentemente de um shell gráfico;

Gate de release P3:

- `scripts/nocted_p3_qualification.sh` executa endurance do core, escala/deltas do índice, workers, recuperação de estado, tarefas, `clangd` real, smoke GTK nativo X11 nos modos claro/escuro e um fixture Git real;
- `PKGBUILD`, o perfil ISO, `check_noctty_integration.sh` e `check-iso-content.sh` carregam o mesmo contrato Nocted/LSP/Git/tema;
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

## P5 — beta de jogos

**Objetivo:** tornar a sessão de jogos utilizável de forma repetível.

**Status:** fundação da sessão implementada; o critério de saída gaming ainda não foi atendido.

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

- executar e guardar uma medição completa da ISO após mudanças de pacotes;
- completar a matriz física de desktop, laptop e BC-250;
- qualificar upgrades da ISO instalada, recuperação do filesystem e rollback;
- fechar os gates reais de DRM, Steam, controle, PipeWire, suspensão/retomada e recuperação da GPU.
