# Arquitetura da DINX

[Português (Brasil)](architecture.md) · [English](../architecture.md)

## Princípios

1. **Integração profunda, dependências fracas.** Os aplicativos da DINX compartilham contratos e experiência de uso sem exigir toda a distribuição em tempo de execução.
2. **Uso de componentes de baixo nível comprovados.** Emulação de terminal, edição de texto, parsing e ferramentas de linguagem são pontos de integração, não motivos para reimplementar subsistemas maduros.
3. **O sistema inicializável é o primeiro produto.** Os aplicativos só entram depois que instalação, login, recuperação e atualizações puderem ser testados.
4. **Operações privilegiadas devem ser restritas.** Interfaces de usuário não podem transformar entrada arbitrária em comandos privilegiados.

## Camadas do sistema

```text
Aplicativos DINX
  Noctty · Nocted · Dinx Control

Contratos compartilhados de integração
  Dinx Theme · caminhos XDG · metadados .desktop · $TERMINAL · IPC opcional do Noctalia

Sessão do desktop
  Wayland · MangoWC · Noctalia Shell · greeter

Fundação do sistema operacional
  Artix Linux · dinit · kernel · Mesa/Vulkan · PipeWire · D-Bus · portais · polkit

Release e validação
  manifestos de pacotes · assinatura · build da ISO · checksums · smoke tests em VM · relatórios de hardware
```

## Fundação da distribuição

O primeiro alvo é o Artix Linux com dinit em x86_64. A imagem base deve fornecer:

- uma ISO inicializável e um caminho de instalação documentado;
- login gráfico com TTY de recuperação;
- rede, PipeWire, D-Bus, portais, polkit e gráficos acelerados;
- gerenciamento de arquivos independente com Thunar, `thunar-volman`, GVFS, UDisks2 e um agente de PolicyKit para mídia removível, sem uma sessão completa do Xfce/LXQt ou systemd;
- manifestos de pacotes que identifiquem cada entrada específica da DINX;
- um snapshot conhecido como funcional, reproduzível em um ambiente de build limpo.

Pacotes compatíveis com o upstream são preferidos. Pacotes e patches específicos da DINX devem permanecer pequenos, explícitos e identificáveis separadamente.

## Limites dos aplicativos

### Noctty

Noctty é responsável pela janela, preferências, atalhos, abas/painéis e integração de temas. O limite de terminal da P2 é o `Vt.Grid` e o `TerminalSession` nativos em Zig: eles são responsáveis pelo parsing VT, células Unicode, cursor/modos, scrollback limitado, seleção e paste, enquanto a superfície VT/runtime pública do Ghostty permanece um adaptador isolado.

A decisão do núcleo da P2 está fixada pelo corpus determinístico de protocolo/Unicode, pelo ciclo de vida PTY com contabilidade de alocação, pela faixa de fairness/paste grande e pela matriz de aplicativos instalados para Vim, nano, less, dialog, perfis de lançamento tmux/Zellij, SSH/SFTP e TUIs comuns. Substituir esse núcleo é uma decisão separada de compatibilidade e migração, não uma dependência implícita da P2.

### Nocted

Nocted é um editor de código leve, não um IDE completo. Seus limites são:

- estado e interface do aplicativo em Zig;
- um adaptador do motor de edição para buffers, seleções, undo/redo e atualizações incrementais;
- um parser de sintaxe comprovado, como Tree-sitter;
- uma camada de processos/cliente LSP;
- status do Git, saída limitada de diff unificado e marcadores de alterações por arquivo ficam disponíveis pela ação Tools do editor; Git é uma capacidade opcional do projeto e nunca impede abrir ou editar um arquivo fora de um repositório.
- a camada LSP do Nocted inicia o servidor selecionado pelo tipo do arquivo com framing JSON-RPC limitado. Zig usa `zls` quando disponível; C/C++ usa `clangd`; diagnósticos e navegação continuam sendo recursos do editor, não uma dependência do Noctalia.
- o editor seleciona o esquema claro/escuro documentado por `NOCTALIA_COLOR_SCHEME` ou `NOCTED_THEME` e usa o esquema escuro DINX como fallback. O Noctalia pode fornecer a preferência, mas o editor continua funcional sem o shell.

O editor deve continuar útil sem o Noctalia. O Noctalia fornece apresentação e integração opcional com o launcher, não a funcionalidade principal do editor.

### Dinx Control

Dinx Control apresenta o status do dinit e ações seguras do sistema. Deve usar uma interface restrita de serviço/ação e um limite de privilégios documentado. Não pode interpolar nomes arbitrários de serviços ou texto do usuário em comandos de shell.

## Contratos compartilhados

Os contratos compartilhados são versionados independentemente dos detalhes internos dos aplicativos:

- esquema de temas e tokens de design;
- locais de configuração de aplicativos conforme as convenções XDG;
- metadados `.desktop` e comportamento da linha de comando;
- invocação por `$TERMINAL` e comportamento do diretório de trabalho;
- adaptadores opcionais de IPC e notificações do Noctalia;
- convenções de logs e diagnósticos.

Um contrato deve ter uma versão documentada e um teste de compatibilidade antes de ser usado pelos aplicativos.

## Sessão de jogos

A sessão de jogos é separada e baseada em Gamescope e Steam. Ela não pode presumir que o desktop completo do Noctalia esteja em execução. Entrada na sessão, lançamento do jogo, controles, áudio, saída da sessão e retorno ao greeter são caminhos de aceitação explícitos.

## Caminho de instalação selecionado

O caminho de instalação persistente é o **Calamares** em modo offline: ele copia o root filesystem da ISO, cria o usuário e a tabela de sistemas de arquivos, habilita os serviços dinit, instala o GRUB e remove os pacotes exclusivos da sessão live. O usuário pode escolher particionamento automático ou manual, com ext4 e btrfs disponíveis no primeiro perfil.

O **KDE Partition Manager** é o particionador gráfico independente oferecido ao lado do Calamares. Ele compartilha a stack Qt/kpmcore já usada pelo Calamares e executa como aplicação Wayland nativa na sessão DINX. Serve para inspecionar e preparar discos antes da instalação, não para substituir a seleção final de pontos de montagem do instalador.

Esse caminho continua experimental até qualificarmos uma instalação limpa UEFI/BIOS em VM, o primeiro boot, a TTY de recuperação e as proteções contra seleção destrutiva de dispositivo.

## Decisões ainda necessárias antes de um release de produção

O caminho do instalador está selecionado, mas estas decisões continuam abertas antes de um release persistente de produção:

- toolkit Wayland e backend dos aplicativos próprios;
- layout do repositório de pacotes e responsabilidade pela chave de assinatura;
- matriz de GPUs e hardware suportados;
- política de licença do repositório e dos artefatos.

O núcleo de terminal da P2 está selecionado para o pacote alpha; o release de produção ainda exige os gates mais amplos de hardware, assinatura e redistribuição.
