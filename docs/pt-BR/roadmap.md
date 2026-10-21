# Roadmap da DINX

[Português (Brasil)](roadmap.md) · [English](../roadmap.md)

Os marcos são gates de capacidade, não promessas de calendário.

## Fase atual

**P5 — beta de jogos (em andamento).** A P4 DinitUI está qualificada end-to-end: implementação, qualificação local de daemon/GTK, payload do pacote/ISO e gate de instalação persistente/recuperação em discos descartáveis passaram. A execução de release com tag [39611695024](https://github.com/rufl/DINX/actions/runs/39611695024), no commit `eea66ac`, é a evidência P0 atual e inclui discos BIOS e UEFI descartáveis, o smoke transacional BIOS/UEFI/Btrfs do Calamares, a verificação dos metadados de build, a assinatura persistente de pacotes e a publicação do release. A P5 continua ativa porque Steam/jogo/controle/áudio autenticados, seleção da sessão gaming no greeter, sessão DRM real, retorno ao greeter após uma sessão real, suspensão/retomada e testes de GPU/atualização em hardware físico continuam abertos.

## P0 — fundação

**Objetivo:** produzir uma sessão live Artix+dinit reproduzível e definir o caminho de instalação persistente.

**Status:** o gate da fundação ISO/VM está concluído. A publicação do repositório
pacman customizado assinado e a qualificação de instalação/atualização/downgrade de
pacotes estão implementadas no CI; configuração da chave de produção, hardware físico,
atualizações da ISO instalada, rollback do filesystem e saúde de serviços em hardware
por longo prazo continuam gates de release.

Backlog:

- qualificar o instalador offline Calamares selecionado, o alvo dinit e o particionador independente;
- definir o manifesto de pacotes base e o limite dos pacotes específicos da DINX;
- configurar Wayland, MangoWC, Noctalia Shell e o greeter;
- validar rede, PipeWire, D-Bus, portais, polkit e aceleração de GPU;
- manter uma TTY de recuperação e documentar como recuperar uma sessão gráfica quebrada;
- adicionar caminhos de build limpo e smoke tests de boot/instalação em VM.

**Critério de saída:** um boot live limpo faz login gráfico, fornece os serviços base necessários e permite recuperação por TTY. O CI executa o contrato de instalação persistente em discos BIOS e UEFI descartáveis e o caminho transacional de pacotes assinados; atualizações da ISO instalada, rollback do filesystem e preservação de dados continuam gates de release.

## P1 — alpha pública 0.1

**Objetivo:** distribuir um snapshot conhecido como funcional através do projeto público no GitHub.

**Status:** concluída para o snapshot alpha público `v0.1.0-alpha.8`.

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
- o pacote está presente na ISO; contratos de `$TERMINAL`, defaults do shell, `.desktop`, diretório de trabalho, descoberta pelo Noctalia e runtime do pacote estão verificados;
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
- esquemas claro/escuro sensíveis ao Noctalia pelo contrato documentado de ambiente `NOCTALIA_COLOR_SCHEME`/`NOCTED_THEME`, mantendo o editor útil sem o Noctalia.

Gate de release P3:

- `scripts/nocted_p3_qualification.sh` executa endurance do core, escala/deltas do índice, workers, recuperação de estado, tarefas, `clangd` real, smoke GTK nativo X11 nos modos claro/escuro e um fixture Git real;
- `PKGBUILD`, o perfil ISO, `check_noctty_integration.sh` e `check-iso-content.sh` carregam o mesmo contrato Nocted/LSP/Git/tema;
- o workflow P0 continua sendo o gate obrigatório de pacote, ISO, QEMU, instalação persistente, recuperação e atestação.

**Critério de saída:** atendido. Uma pessoa desenvolvedora consegue trabalhar em um projeto Zig ou C/C++, consultar diagnósticos e alterações do Git e editar sem um segundo editor.

## P4 — DinitUI

**Objetivo:** tornar as operações do Dinit compreensíveis, completas e seguras sem importar conceitos do systemd.

**Status:** qualificada para o gate alpha. `zig build test`, builds ReleaseSafe, payloads de pacotes Arch, checks estáticos, um daemon Dinit de usuário temporário real e as superfícies GTK de produção foram qualificados. A execução de release com tag [39611695024](https://github.com/rufl/DINX/actions/runs/39611695024), no commit `eea66ac`, também passou o build do pacote Artix, o payload da ISO, o boot no QEMU, o smoke transacional de particionamento BIOS/UEFI/Btrfs do Calamares, o smoke de instalação persistente/primeiro boot/TTY de recuperação em discos BIOS e UEFI descartáveis, a verificação dos metadados de build, a assinatura persistente de pacotes, a atestação de procedência e a publicação do release. A DINXPanel agora é dona dos controles visíveis de hardware/drivers e do instalador fixo de kernels; a matriz de hardware mais ampla continua sendo um gate de release de produção.

**Entregue:**

- descoberta de serviços carregados e de arquivos de descrição no sistema/usuário;
- status, logs em buffer e linhas de serviço com estado;
- ações de ciclo de vida, boot, dependência, ambiente, sinais e daemon usando o vocabulário próprio do `dinitctl`;
- execução por argv validado, escopos system/usuário e retry explícito por `pkexec` somente após falha de autorização;
- perfis de serviços de sistema `normal`, `lite`, `gaming` e customizados, com editor GTK, persistência e integração CLI;
- plugin local `dinx/performance` do Noctalia com atalho Gaming no Control Center e painel de perfis;
- DINXPanel com atalhos fixos de hardware/painéis de controle, ponte para o backend de GPU do DinitUI e catálogo de kernels Artix sem remoção;
- contratos do pacote, metadados desktop, licença e payload da ISO.

## P5 — beta de jogos

**Objetivo:** tornar a sessão de jogos utilizável de forma repetível.

**Status:** fundação da sessão implementada; o critério de saída gaming ainda não foi atendido.

**Entregue:**

- sessão Wayland standalone `DINX Gaming` com `dbus-run-session`, backend DRM do Gamescope e Steam `-tenfoot`;
- pacote de dispositivos Steam e entradas de payload Mesa/RADV/Vulkan de 32 bits;
- semântica segura dos serviços Normal/Lite/Gaming, entrada/restauração do perfil com propagação de falhas ao redor do launcher standalone, detecção/planos fixos de drivers GPU para hardware AMD, Intel e NVIDIA moderno e a DINXPanel inspirada no YaST, com atalhos fixos para painéis de controle, ações de upgrade Shelly/Topgrade, descoberta opcional de fwupd e instalador de kernels Artix sem remoção;
- fixture determinístico de argv/retorno do launcher e qualificação real headless de launch/exit de filho do Gamescope;
- checks de payload da ISO e contrato estático da entrada da sessão e dos binários.
- GameMode e MangoHud estão no payload gaming; `dinx-gaming` suporta
  `DINX_GAMEMODE=auto|on|off` e `DINX_MANGOHUD=on|off` opcional sem remover o
  fallback do launcher normal.
- A ISO inclui `dinx-alpha7-hardware-report` para evidências somente de leitura
  no desktop, laptop e BC-250; as afirmações de hardware continuam manuais.

**Gates de release restantes:**

- uma sessão DRM real e a seleção da sessão gaming pelo greeter;
- inicialização Steam autenticada, launch/exit de jogo comercial, controles e áudio PipeWire;
- retorno ao greeter depois da saída de uma sessão real;
- suspensão/retomada, recuperação da GPU e testes de atualização em hardware físico.

**Critério de saída:** um jogo pode ser iniciado e encerrado repetidamente sem deixar o desktop quebrado. Os fixtures atuais não alegam esse critério.
