# Arquitetura da DINX

[Português (Brasil)](architecture.md) · [English](../architecture.md)

## Princípios

1. **Integração profunda, dependências fracas.** Os aplicativos da DINX compartilham contratos e experiência de uso sem exigir toda a distribuição em tempo de execução.
2. **Uso de componentes de baixo nível comprovados.** Emulação de terminal, edição de texto, parsing e ferramentas de linguagem são pontos de integração, não motivos para reimplementar subsistemas maduros.
3. **O sistema inicializável é o primeiro produto.** Os aplicativos só entram depois que instalação, login, recuperação e atualizações puderem ser testados.
4. **Operações privilegiadas devem ser restritas.** Interfaces de usuário não podem transformar entrada arbitrária em comandos privilegiados.
5. **As tarefas comuns devem funcionar no primeiro boot.** Reprodução de mídia, diagnóstico de hardware, handlers padrão, aplicativos de tray, recuperação e limites das fontes de pacotes devem ter um default funcional ou um estado indisponível explícito.
6. **Prefira padrões a lock-in de ecossistema.** A DINX usa metadados XDG, protocolos Wayland, PipeWire, entradas desktop e interfaces de pacotes documentadas para que os aplicativos continuem utilizáveis sem comportamento exclusivo da DINX.
7. **Exija evidência antes de fazer afirmações.** Cada recurso enviado tem um gate estático, fixture, CI, QEMU ou hardware físico; caminhos experimentais permanecem identificados em vez de serem apresentados como concluídos.

## Camadas do sistema

```text
Aplicativos DINX
  Noctty · Nocted · DinitUI · DINXPanel · Seafoam Settings · Dome · ZLS (ISO base)

Contratos compartilhados de integração
  Dinx Theme · caminhos XDG · metadados .desktop · $TERMINAL · IPC opcional do Noctalia

Sessão do desktop
  Wayland · labwc · Noctalia Shell · greeter

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
- o Pori gerencia discos e montagens sobre UDisks2, com serviços dinit persistentes em `/etc/dinit.d`;
- o Phyto fornece gerenciamento nativo de arquivos e é o manipulador padrão de diretórios; a DINX inclui o File Roller para ações com arquivos compactados e o GParted para particionamento gráfico independente, enquanto `wdisplays` e `shikane` cuidam da configuração de displays Wayland; Thunar, GVFS, Tumbler e KDE Partition Manager continuam omitidos;
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
- a camada LSP do Nocted inicia o servidor selecionado pelo tipo do arquivo com framing JSON-RPC limitado. Zig usa o `zls` incluído; C/C++ usa `clangd`; diagnósticos e navegação continuam sendo recursos do editor, não uma dependência do Noctalia.
- o editor seleciona o esquema claro/escuro documentado por `NOCTALIA_COLOR_SCHEME` ou `NOCTED_THEME` e usa o esquema escuro DINX como fallback. O Noctalia pode fornecer a preferência, mas o editor continua funcional sem o shell.

O editor deve continuar útil sem o Noctalia. O Noctalia fornece apresentação e integração opcional com o launcher, não a funcionalidade principal do editor.

### DinitUI

DinitUI apresenta serviços dinit carregados e descobertos, status, logs em buffer, ciclo de vida, dependências, ambiente e ações do daemon. Usa uma interface `dinitctl` restrita por argv, valida tokens de serviço/argumentos, entende os marcadores aninhados da listagem nativa do Dinit e só tenta autorização de escopo system por `pkexec` após uma falha explícita de permissão. Não pode interpolar texto do usuário em comandos de shell. O smoke contra daemon real usa um daemon Dinit de usuário temporário e prova a descoberta pela superfície GTK de produção.

O DinitUI também é dono de perfis explícitos `normal`, `lite`, `gaming` e perfis de sistema definidos pelo usuário. `lite` desabilita somente o daemon opcional de Bluetooth; `gaming` habilita explicitamente `bluetoothd` para controles e mantém disponíveis Bluetooth, UFW e os serviços de política do OpenSnitch. NetworkManager, D-Bus, PipeWire, WirePlumber, elogind, greetd, seatd, metalog e os serviços de display ficam fora da política padrão. O editor salva a política do usuário em `~/.config/dinx/dinitui/profiles.conf` e expõe `--profile-status`, `--apply-profile`, `--toggle-profile`, `--gaming-enter`, `--gaming-leave`, `--gpu-status` e `--install-gpu-drivers` para integração com o shell.

### DINXPanel

A DINXPanel é o centro de controle inspirado no YaST. Ela é dona das ações visíveis de hardware e drivers, agrupa entradas fixas para rede, Bluetooth, display, áudio, firewall, opções do labwc, serviços Dinit, upgrades de pacotes e firmware e expõe um catálogo fixo de kernels Artix (`linux`, `linux-lts`, `linux-zen`, `linux-hardened`). Seu relatório de upgrades sem instalação usa Shelly e os metadados opcionais do fwupd; o preview do Topgrade usa `--dry-run --show-skipped`; upgrades explícitos continuam sendo fluxos confirmados pelo usuário no terminal. As ações de kernel apenas instalam pacotes e headers; nunca removem o kernel em execução, exigem reinicialização e usam o bootloader para selecionar uma alternativa já instalada em caso de rollback.

A impressão é uma opção explícita após a instalação, não uma dependência da
ISO: a DINXPanel baixa o pacote fixo `cups-dinit` do repositório Artix
configurado; ele puxa o CUPS e fornece o serviço `cupsd` do dinit. O usuário
habilita ou inicia esse serviço pelo DinitUI quando precisar de impressão.

A DINX inclui o plugin local `dinx/performance` do Noctalia. Seu atalho no Control Center aplica o perfil Gaming e sincroniza o perfil de energia documentado `performance`/`balanced` do Noctalia. A sessão Gamescope standalone não inicia o Noctalia e continua independente dessa integração.

### Dome

O `Dome` é um monitor de sistema nativo em Zig/GTK4 entregue no repositório DINX assinado e incluído na ISO. Suas telas de recursos e processos são compatíveis com dinit; o pacote não instala integração com systemd, systemctl ou uwsm.

### Seafoam Settings e ZLS

O `Seafoam Settings` é um launcher nativo base em Zig/GTK4 para as superfícies DINX de display/sessão: `dinx-wdisplays`, `dinx-save-shikane-profile`, Shikane, labwc, DinitUI, DINXPanel, Qt6ct e Dome. Ele inicia vetores de argumentos fixos e abre somente os arquivos de configuração documentados do usuário no Foot/Nano; não interpreta comandos shell arbitrários nem substitui os aplicativos especializados.

O `zls` é o pacote oficial do Zig Language Server 0.16.0, com fonte fixada e incluído na ISO. O Nocted o inicia para projetos Zig; o pacote é independente do shell da sessão e não é uma dependência de serviço ou compositor.
### Aqueous, Pearl e o limite da sessão dinit

Aqueous e Pearl continuam sendo componentes opcionais planejados de compositor/shell em Zig, não sessões distribuídas pela DINX. O empacotamento upstream da sessão usa `uwsm` e unidades systemd de usuário, e o core do Aqueous liga APIs de libsystemd. A DINX não instala systemd e, por isso, mantém `Labwc (DINX)` com Noctalia como a única sessão gráfica suportada até existir um pacote nativo de dinit, um contrato de ciclo de vida e uma qualificação física da sessão. Não há fallback silencioso quando uma sessão alternativa não está disponível.

O `dinx-doctor` é a superfície de evidência somente leitura para os caminhos da sessão atual, dinit, armazenamento, display e pacotes. Ele não inicia serviços, monta dispositivos, modifica o Shikane, executa transações de pacotes nem acessa a rede. `DINX_DOCTOR_QUERY_DINIT=1` opta por uma consulta somente leitura à lista do dinit de usuário.



## Contratos compartilhados

Os contratos compartilhados são versionados independentemente dos detalhes internos dos aplicativos:

- esquema de temas e tokens de design;
- locais de configuração de aplicativos conforme as convenções XDG;
- metadados `.desktop` e comportamento da linha de comando;
- invocação por `$TERMINAL` e comportamento do diretório de trabalho;
- adaptadores opcionais de IPC e notificações do Noctalia;
- convenções de logs e diagnósticos.

Um contrato deve ter uma versão documentada e um teste de compatibilidade antes de ser usado pelos aplicativos.

O contrato Dinx Theme v1 é uma paleta customizada do Noctalia: papéis semânticos de superfície/texto/primário/erro, variantes claro/escuro, paleta ANSI completa do terminal, Noto Sans 10 para bridges voltadas à interface (alinhado à tipografia GTK padrão do CachyOS), geometria quadrada nos controles e bridge de ícones Adwaita. GTK/Qt consomem as saídas documentadas dos templates do Noctalia; o labwc usa a configuração versionada em `/etc/xdg/labwc` e mescla overrides do usuário em `~/.config/labwc/rc.xml`. ReGreet, Calamares, Swayimg e GRUB usam bridges estáticas com os mesmos tokens. O backend Fusion do Qt, os campos de largura fixa Noto Sans Mono 10, os logs monoespaçados de DinitUI/DINXPanel e o `u_vga16 16` do GRUB permanecem limites de plataforma intencionais. `scripts/check_dinx_theme.sh` é a qualificação do contrato.

## Sessão de jogos

A sessão de jogos é separada e baseada em Gamescope e Steam. `dinx-gaming` inicia `gamescope --backend drm --steam --fullscreen -- steam -tenfoot` a partir de uma entrada Wayland standalone com `dbus-run-session`; ela não presume Noctalia ou labwc em execução por baixo. O perfil inclui as dependências Mesa/RADV/Vulkan de 32 bits do Steam e `steam-devices`; o builder P0 habilita explicitamente o repositório oficial `lib32` do Artix e não adiciona repositórios Arch. `scripts/gaming_p5_qualification.sh` prova argv/retorno do launcher com fixtures, limpeza do grupo de processos e restauração do perfil durante sinais, e lançamento/saída de um filho real headless do Gamescope; não afirma login Steam autenticado, jogo comercial, hardware de controle/áudio, display DRM, suspensão/retomada ou recuperação de GPU.

## Limite de armazenamento e filesystem

O Pori é a única interface gráfica de armazenamento da DINX. Ele usa UDisks2 para descobrir dispositivos de bloco, mas seu ciclo de vida de montagem persistente é nativo do dinit: o Pori grava serviços scriptados em `/etc/dinit.d` e os controla com `dinitctl --system`. Nenhuma unidade de montagem systemd é gerada. O Phyto é o único gerenciador de arquivos base e o manipulador padrão de `inode/directory`. O File Roller fornece ações para abrir, criar e extrair arquivos compactados; o GParted fornece particionamento gráfico independente. O wrapper `dinx-wdisplays` fornece configuração interativa de displays Wayland, substitui atomicamente o perfil DINX `DINX wdisplays` em `~/.config/shikane/config.toml` e recarrega o daemon do usuário. O Shikane inicia com o labwc e reaplica perfis correspondentes quando as saídas mudam. A imagem omite gerenciadores de arquivos concorrentes e monitores de volume.

O módulo de kernel `ntfs3` fornece suporte NTFS de leitura e escrita tanto na ISO live quanto no sistema instalado. O Pori mapeia o tipo de filesystem `ntfs` do UDisks2 para `ntfs3`. O pacote legado `ntfs-3g` não fica na ISO nem na instalação base; continua opcional após a instalação para compatibilidade e ferramentas de reparo. O Fast Startup e a hibernação do Windows devem ser desativados antes de montar um volume NTFS compartilhado.

## Caminho de instalação selecionado

A imagem base inclui o Phyto como gerenciador de arquivos padrão, o File Roller para ações com arquivos compactados, o Pori como gerenciador de armazenamento dinit, o GParted para particionamento gráfico independente, o `dinx-wdisplays` para configuração interativa com exportação persistente para o Shikane e o daemon de usuário Shikane. O perfil omite deliberadamente Thunar, GVFS, Tumbler e KDE Partition Manager em vez de enviar stacks concorrentes de gerenciador de arquivos, monitoramento de volumes e particionamento.

O caminho de instalação persistente é o **Calamares** em modo offline: ele copia o root filesystem da ISO, cria o usuário e a tabela de sistemas de arquivos, habilita os serviços dinit, instala o GRUB e remove os pacotes exclusivos da sessão live. O usuário pode escolher particionamento automático ou manual, com ext4 e btrfs disponíveis no primeiro perfil. O perfil preserva layouts existentes de ESP/NTFS do Windows, habilita um diretório EFI separado para a DINX e mantém `os-prober` para a descoberta do Windows. O CI qualifica smokes transacionais BIOS/UEFI descartáveis, Btrfs com subvolumes existentes e Windows side-by-side/manual; o caminho continua experimental até qualificar proteções contra seleção destrutiva de dispositivo, instalação em hardware, atualizações da ISO instalada e recuperação de filesystem.

A imagem base não inclui o KDE Partition Manager; o GParted fornece particionamento gráfico independente fora do Calamares, enquanto o Calamares continua sendo a transação de instalação.

## Decisões ainda necessárias antes de um release de produção

O caminho do instalador e o layout do repositório de pacotes estão selecionados,
mas estas decisões continuam abertas antes de um release persistente de produção:

- responsabilidade pela chave de assinatura de produção e provisionamento do segredo no GitHub;
- matriz de GPUs e hardware suportados;
- política de licença do repositório e dos artefatos.

O perfil da ISO agora possui um manifesto versionado e validado de grupos foundation, desktop, gaming, hardware e opcionais. O CI assina o repositório pacman customizado, registra seu snapshot e qualifica transações assinadas de instalação/atualização/downgrade. A publicação com tag ainda exige o segredo da chave de produção; atualizações do sistema instalado, recuperação do filesystem e hardware físico continuam gates separados do release.

O núcleo de terminal da P2 está selecionado para o pacote alpha; o release de produção ainda exige os gates mais amplos de hardware, provisionamento da chave e redistribuição.
