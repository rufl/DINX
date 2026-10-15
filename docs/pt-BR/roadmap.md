# Roadmap da DINX

[Português (Brasil)](roadmap.md) · [English](../roadmap.md)

Os marcos são gates de capacidade, não promessas de calendário.

## Fase atual

**P2 — Noctty (ativa).** O critério de saída da P1 foi atendido por `v0.1.0-alpha.5`: uma pessoa convidada consegue obter o release, verificá-lo, seguir o guia de instalação e usar o caminho documentado de recuperação sem reconstruir o ambiente de desenvolvimento. Chave de assinatura do repositório pacman, relatórios de hardware físico e qualificação além da VM continuam gates explícitos pós-alpha.

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

**Objetivo:** entregar um terminal confiável antes dos recursos avançados de apresentação.

**Status:** ativa. O primeiro incremento end-to-end da DINX agora compila a fonte fixada do Noctty, executa smoke tests headless de PTY/VT/sessão de terminal, qualificação de sessão com contabilização do allocator e qualificação de compatibilidade de protocolo/Unicode durante a criação do pacote, instala o pacote na ISO e encaminha `$TERMINAL` para o Noctty com fallback para Foot.

Evidência end-to-end atual:

- o archive exato da fonte é fixado por SHA-256 e incluído no build do pacote Artix;
- o build do pacote executa marcadores de criação/redimensionamento/saída de PTY, grade/título/paste de VT, saída da sessão de terminal, ciclo de vida com contabilização do allocator e compatibilidade de protocolo/Unicode;
- o workflow ISO P0 [38798566993](https://github.com/rufl/DINX/actions/runs/38798566993), no commit `fbd9bd6`, passou pela criação do pacote, geração da ISO, boot no QEMU, validação do payload gráfico e smoke da instalação persistente/TTY de recuperação;

Backlog:

- ampliar a cobertura do ciclo de vida do PTY e do processo filho além dos quatro ciclos normais e um forçado atuais;
- expandir a matriz de inicialização do shell, redimensionamento, sinais e limpeza além da verificação atual de recolhimento dos processos forçados;
- entrada/renderização do terminal, Unicode, cores e comportamento do cursor;
- scrollback, seleção, copiar e colar;
- ampliar a qualificação de compatibilidade para sessões reais de `vim`, `less`, `tmux`, SSH e TUIs comuns;
- integração de `$TERMINAL`, `.desktop`, diretório de trabalho e descoberta pelo Noctalia;
- importação/recarregamento de tema e preferências.

Abas, painéis, transparência e detecção de URLs vêm depois da semântica central do terminal.

## P3 — Nocted

**Objetivo:** entregar um editor de código leve e útil.

Backlog:

- abertura de arquivos e diretórios;
- buffer de texto confiável, seleção e undo/redo;
- destaque de sintaxe e navegação de projetos;
- busca/substituição e atalhos configuráveis;
- gerenciamento de processos LSP, diagnósticos, definições e referências;
- status, diffs e marcadores de alterações do Git;
- integração com paleta e modos claro/escuro do Noctalia.

**Critério de saída:** uma pessoa desenvolvedora consegue trabalhar em um projeto Zig ou C/C++, consultar diagnósticos e alterações do Git e editar sem um segundo editor.

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
