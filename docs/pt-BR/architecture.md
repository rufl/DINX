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
  Noctty · Nocted · DinitUI · DINXPanel

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

### DinitUI

DinitUI apresenta serviços dinit carregados e descobertos, status, logs em buffer, ciclo de vida, dependências, ambiente e ações do daemon. Usa uma interface `dinitctl` restrita por argv, valida tokens de serviço/argumentos, entende os marcadores aninhados da listagem nativa do Dinit e só tenta autorização de escopo system por `pkexec` após uma falha explícita de permissão. Não pode interpolar texto do usuário em comandos de shell. O smoke contra daemon real usa um daemon Dinit de usuário temporário e prova a descoberta pela superfície GTK de produção.

O DinitUI também é dono de perfis explícitos `normal`, `lite`, `gaming` e perfis de sistema definidos pelo usuário. `lite` desabilita somente o daemon opcional de Bluetooth; `gaming` habilita explicitamente `bluetoothd` para controles e mantém disponíveis Bluetooth, UFW e os serviços de política do OpenSnitch. NetworkManager, D-Bus, PipeWire, WirePlumber, elogind, greetd, seatd, metalog e os serviços de display ficam fora da política padrão. O editor salva a política do usuário em `~/.config/dinx/dinitui/profiles.conf` e expõe `--profile-status`, `--apply-profile`, `--toggle-profile`, `--gaming-enter`, `--gaming-leave`, `--gpu-status` e `--install-gpu-drivers` para integração com o shell.

### DINXPanel

A DINXPanel é o centro de controle inspirado no YaST. Ela é dona das ações visíveis de hardware e drivers, agrupa entradas fixas para rede, Bluetooth, display, áudio, firewall, MangoWC, serviços Dinit, upgrades de pacotes e firmware e expõe um catálogo fixo de kernels Artix (`linux`, `linux-lts`, `linux-zen`, `linux-hardened`). Seu relatório de upgrades sem instalação usa Shelly e os metadados opcionais do fwupd; o preview do Topgrade usa `--dry-run --show-skipped`; upgrades explícitos continuam sendo fluxos confirmados pelo usuário no terminal. As ações de kernel apenas instalam pacotes e headers; nunca removem o kernel em execução, exigem reinicialização e usam o bootloader para selecionar uma alternativa já instalada em caso de rollback.

A DINX inclui o plugin local `dinx/performance` do Noctalia. Seu atalho no Control Center aplica o perfil Gaming e sincroniza o perfil de energia documentado `performance`/`balanced` do Noctalia. A sessão Gamescope standalone não inicia o Noctalia e continua independente dessa integração.

## Contratos compartilhados

Os contratos compartilhados são versionados independentemente dos detalhes internos dos aplicativos:

- esquema de temas e tokens de design;
- locais de configuração de aplicativos conforme as convenções XDG;
- metadados `.desktop` e comportamento da linha de comando;
- invocação por `$TERMINAL` e comportamento do diretório de trabalho;
- adaptadores opcionais de IPC e notificações do Noctalia;
- convenções de logs e diagnósticos.

Um contrato deve ter uma versão documentada e um teste de compatibilidade antes de ser usado pelos aplicativos.

O contrato Dinx Theme v1 é uma paleta customizada do Noctalia: papéis semânticos de superfície/texto/primário/erro, variantes claro/escuro e paleta ANSI completa do terminal. GTK/Qt/Mango consomem as saídas documentadas dos templates do Noctalia; ReGreet, Calamares e GRUB usam bridges estáticas com os mesmos tokens. `scripts/check_dinx_theme.sh` é a qualificação do contrato.

## Sessão de jogos

A sessão de jogos é separada e baseada em Gamescope e Steam. `dinx-gaming` inicia `gamescope --backend drm --steam --fullscreen -- steam -tenfoot` a partir de uma entrada Wayland standalone com `dbus-run-session`; ela não presume Noctalia ou Mango em execução por baixo. O perfil inclui as dependências Mesa/RADV/Vulkan de 32 bits do Steam e `steam-devices`; o builder P0 habilita explicitamente o repositório oficial `lib32` do Artix e não adiciona repositórios Arch. `scripts/gaming_p5_qualification.sh` prova argv/retorno do launcher com fixtures e prova lançamento/saída de um filho real headless do Gamescope; não afirma login Steam autenticado, jogo comercial, hardware de controle/áudio, display DRM, suspensão/retomada ou recuperação de GPU.

## Caminho de instalação selecionado

O caminho de instalação persistente é o **Calamares** em modo offline: ele copia o root filesystem da ISO, cria o usuário e a tabela de sistemas de arquivos, habilita os serviços dinit, instala o GRUB e remove os pacotes exclusivos da sessão live. O usuário pode escolher particionamento automático ou manual, com ext4 e btrfs disponíveis no primeiro perfil.

O **KDE Partition Manager** é o particionador gráfico independente oferecido ao lado do Calamares. Ele compartilha a stack Qt/kpmcore já usada pelo Calamares e executa como aplicação Wayland nativa na sessão DINX. Serve para inspecionar e preparar discos antes da instalação, não para substituir a seleção final de pontos de montagem do instalador.

O caminho de instalação persistente é o **Calamares** em modo offline: ele copia o root filesystem da ISO, cria o usuário e a tabela de sistemas de arquivos, habilita os serviços dinit, instala o GRUB e remove os pacotes exclusivos da sessão live. O usuário pode escolher particionamento automático ou manual, com ext4 e btrfs disponíveis no primeiro perfil. O perfil também inclui `ntfs-3g`/`os-prober`, preserva um layout Windows existente de ESP/NTFS e habilita um diretório EFI DINX separado. O CI qualifica smokes transacionais BIOS/UEFI descartáveis, Btrfs com subvolumes existentes e Windows side-by-side/manual; o caminho continua experimental até qualificar proteções contra seleção destrutiva de dispositivo, instalação em hardware e comportamento de atualização/rollback.

## Decisões ainda necessárias antes de um release de produção

O caminho do instalador está selecionado, mas estas decisões continuam abertas antes de um release persistente de produção:

- toolkit Wayland e backend dos aplicativos próprios restantes; o DinitUI seleciona GTK4/libadwaita com o backend Wayland nativo do GTK;
- layout do repositório de pacotes e responsabilidade pela chave de assinatura;
- matriz de GPUs e hardware suportados;
- política de licença do repositório e dos artefatos.

O núcleo de terminal da P2 está selecionado para o pacote alpha; o release de produção ainda exige os gates mais amplos de hardware, assinatura e redistribuição.
