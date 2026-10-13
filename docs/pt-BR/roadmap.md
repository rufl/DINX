# Roadmap da DINX

[Português (Brasil)](roadmap.md) · [English](../roadmap.md)

Os marcos são gates de capacidade, não promessas de calendário.

## P0 — fundação

**Objetivo:** produzir um sistema Artix+dinit reproduzível e inicializável.

Backlog:

- selecionar e documentar a ferramenta de build da ISO e o caminho do instalador;
- definir o manifesto de pacotes base e o limite dos pacotes específicos da DINX;
- configurar Wayland, MangoWC, Noctalia Shell e o greeter;
- validar rede, PipeWire, D-Bus, portais, polkit e aceleração de GPU;
- manter uma TTY de recuperação e documentar como recuperar uma sessão gráfica quebrada;
- adicionar caminhos de build limpo e smoke tests de boot/instalação em VM.

**Critério de saída:** uma instalação limpa inicializa, faz login gráfico, fornece os serviços base necessários e permite recuperação por TTY.

## P1 — alpha privada 0.1

**Objetivo:** distribuir um snapshot conhecido como funcional dentro do projeto privado no GitHub.

Backlog:

- publicar ISO, checksums, instruções de instalação e problemas conhecidos;
- estabelecer assinatura de pacotes e metadados de release;
- fornecer terminal de fallback mínimo e configuração de shell funcional;
- coletar relatórios de hardware e priorizar bloqueios de instalação.

**Critério de saída:** uma pessoa convidada consegue instalar o sistema seguindo a documentação sem reconstruir o ambiente de desenvolvimento.

## P2 — Noctty

**Objetivo:** entregar um terminal confiável antes dos recursos avançados de apresentação.

Backlog:

- ciclo de vida do PTY e do processo filho;
- inicialização do shell, redimensionamento, sinais e limpeza;
- entrada/renderização do terminal, Unicode, cores e comportamento do cursor;
- scrollback, seleção, copiar e colar;
- verificações de compatibilidade com `vim`, `less`, `tmux`, SSH e TUIs comuns;
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
