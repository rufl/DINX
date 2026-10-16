# Roadmap da DINX

[Português (Brasil)](roadmap.md) · [English](../roadmap.md)

Os marcos são gates de capacidade, não promessas de calendário.

## Fase atual

**P4 — Dinx Control (próxima).** A P3 Nocted está concluída no contrato de fonte/pacote; os gates pós-alpha restantes são os mesmos limites de release documentados abaixo.

## P0 — fundação

**Objetivo:** produzir uma sessão live Artix+dinit reproduzível e definir o caminho de instalação persistente.

**Status:** o gate da fundação ISO/VM está concluído. Instalação em hardware, atualizações, rollback e saúde de serviços em hardware por longo prazo continuam gates de release.

Backlog:

- qualificar o instalador offline Calamares selecionado, o alvo dinit e o particionador independente;
- definir o manifesto de pacotes base e o limite dos pacotes específicos da DINX;
- configurar Wayland, MangoWC, Noctalia Shell e o greeter;
- validar rede, PipeWire, D-Bus, portais, polkit e aceleração de GPU;
- manter uma TTY de recuperação e documentar como recuperar uma sessão gráfica quebrada;
- adicionar caminhos de build limpo e smoke tests de boot/instalação em VM.

**Critério de saída:** um boot live limpo faz login gráfico, fornece os serviços base necessários e permite recuperação por TTY. O CI agora executa o contrato de instalação persistente em um disco BIOS descartável; instalação em hardware, atualizações e rollback continuam sendo gates de release.

## P1 — alpha pública 0.1

**Objetivo:** distribuir um snapshot conhecido como funcional através do projeto público no GitHub.

**Status:** concluída para o snapshot alpha público `v0.1.0-alpha.5`.

Concluído:

- publicação da ISO/partes, checksums, instruções de instalação, problemas conhecidos e metadados de release;
- qualificação do instalador persistente experimental e do caminho de recuperação no primeiro boot pelo CI em um disco BIOS descartável;
- fornecimento do terminal mínimo de fallback e da configuração funcional de shell;
- registro explícito da limitação de assinatura de pacotes, do limite de hardware e das limitações de recuperação na documentação do release.

Gates de release adiados:

- chave de assinatura do repositório pacman e banco de pacotes assinado;
- relatórios de hardware físico e qualificação além da VM.

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
- assinatura pacman, hardware físico, UEFI, atualizações, rollback e saúde de serviços em produção por longo prazo continuam gates posteriores de release.

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

## P4 — Dinx Control

**Objetivo:** tornar operações comuns do dinit compreensíveis e seguras.

Backlog:

- listagem de serviços e status correto;
- iniciar, parar e reiniciar com erros estruturados;
- dependências e logs disponíveis;
- visualizações de perfil de inicialização e estado do hardware;
- elevação de privilégios restrita e testes de compatibilidade.

## P5 — beta de jogos

**Objetivo:** tornar a sessão de jogos utilizável de forma repetível.

Backlog:

- Gamescope e uma sessão Steam separada;
- testes de controles, áudio, lançamento do jogo e saída da sessão;
- retorno ao greeter após sair do jogo;
- bibliotecas gráficas de 32 bits e dependências comuns de jogos;
- testes de suspensão/retomada, recuperação da GPU e atualização em hardware real.

**Critério de saída:** um jogo pode ser iniciado e encerrado repetidamente sem deixar o desktop quebrado.
