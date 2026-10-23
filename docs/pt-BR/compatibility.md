# Contrato de compatibilidade com o Noctalia

[Português (Brasil)](compatibility.md) · [English](../compatibility.md)

Os aplicativos DINX complementam o Noctalia e não devem depender de detalhes internos não documentados. A compatibilidade é dividida em níveis para que os aplicativos continuem úteis sem o shell.

## Nível 1 — integração direta

Obrigatório para as primeiras versões utilizáveis dos aplicativos:

- Noctty é descoberto como terminal e funciona por meio de `$TERMINAL`.
- Noctty aceita os argumentos esperados de inicialização do terminal, incluindo diretório de trabalho quando suportado.
- Nocted possui uma entrada `.desktop` válida e aparece no launcher do Noctalia.
- Nocted suporta abertura normal por arquivos `.desktop` e argumentos de arquivo/linha quando implementados.
- Ambos seguem navegação de teclado padrão e locais XDG.
- Firefox é descoberto como o manipulador padrão de HTML, XHTML e HTTP/HTTPS.

## Nível 2 — integração visual

Os aplicativos consomem um formato ou adaptador documentado do Dinx Theme:

- modo claro/escuro;
- cores de destaque, fundo, primeiro plano e seleção;
- paleta ANSI do terminal;
- escolhas de fonte e ícones quando a plataforma as expuser.

O contrato do adaptador do Nocted é deliberadamente pequeno: `NOCTALIA_COLOR_SCHEME=light` ou `NOCTED_THEME=prefer-light` seleciona o esquema empacotado `nocted-light`; os demais valores usam `nocted-dark`. O editor não interpreta arquivos privados do Noctalia e continua utilizável quando nenhuma variável ou o Noctalia está presente.

O gate de compatibilidade P3 exercita os dois esquemas pelo smoke GTK nativo, verifica o contrato de abertura por arquivo do `.desktop` do NoctEd e executa o probe LSP real com `clangd`. Um repositório Git é opcional; quando presente, a ação Tools informa status e diff unificado limitados, com marcadores por arquivo.
O Firefox acompanha `/etc/firefox/policies/policies.json`. A política remove superfícies patrocinadas da Nova Aba/Suggest, Pocket/Stories, Firefox Studies e telemetria, recomendações do navegador, superfícies de assistente de IA/preview de links/grupos de abas e o IP Protection integrado. Firefox Accounts continua opcional e controlado pelo usuário; as atualizações normais do navegador permanecem habilitadas.
O contrato visual entregue é a paleta Noctalia `DINX` em `~/.config/noctalia/palettes/DINX.json`. Ela define os papéis semânticos claro/escuro e a paleta ANSI completa do terminal; o Noctalia usa `source = "custom"`, `sync_color_scheme = true` e os templates nativos de btop, Foot, Ghostty, GTK 3/4, KDE e Qt.

Aplicativos GTK usam o tema fallback instalado `DINX` até o Noctalia aplicar seu CSS gerado. Aplicativos Qt usam `qt6ct` com `~/.config/qt6ct/colors/noctalia.conf` gerado pelo Noctalia; o labwc lê `/etc/xdg/labwc` e mescla overrides do usuário em `~/.config/labwc/rc.xml`. O Swayimg recebe um fallback DINX de overlay/galeria em `~/.config/swayimg/init.lua`. A sessão exporta defaults documentados para `NOCTALIA_COLOR_SCHEME`, `NOCTED_THEME`, `QT_QPA_PLATFORMTHEME`, `XCURSOR_THEME` e `XCURSOR_SIZE`.

As bridges voltadas à interface usam Cantarell 11, geometria quadrada nos controles, os estados semânticos DINX de superfície/controle/hover/primário e ícones Adwaita quando a plataforma os expõe. ReGreet e Calamares consomem bridges estáticas DINX porque executam antes ou fora do shell. O GRUB usa os mesmos tokens de superfície/texto/primário, com as texturas opacas do menu desativadas. A barra principal do Noctalia inclui um drawer de tray StatusNotifier, e o perfil fornece `libayatana-appindicator` para manter compatibilidade com aplicativos indicadores legados. `scripts/check_dinx_theme.sh` valida a paleta, os templates, os pacotes, a tipografia, os estados e cada bridge antes do build da ISO; `check-iso-content.sh` repete as verificações dentro do SquashFS.

As diferenças restantes são limites de plataforma intencionais: o Qt mantém Fusion como backend de estilo e Monospace 10 para campos de largura fixa; DinitUI e DINXPanel mantêm visual monoespaçado nos logs; o GRUB mantém `u_vga16 16` por compatibilidade com assets do boot inicial. Essas exceções não substituem as cores DINX nem o contrato de interface Cantarell 11.

## Contrato do gerenciador de serviços DinitUI

DinitUI é o frontend DINX do dinit, não uma camada de compatibilidade com systemd. Descobre serviços carregados por `dinitctl list` e arquivos de descrição nos diretórios Dinit do sistema/usuário, incluindo o framing aninhado nativo do Dinit. Seu catálogo cobre ciclo de vida, dependências de boot/runtime, ambiente, logs em buffer, sinais e desligamento. `scripts/check_dinitui.sh` cobre o limite do pacote; a qualificação contra daemon real prova um daemon de usuário temporário pela superfície GTK.
A UI passa tokens validados diretamente ao `dinitctl`; nunca inicia um shell. O escopo de usuário usa `dinitctl --user`. O escopo system tenta primeiro `dinitctl --system` e usa `pkexec` somente após falha explícita de autorização. O contrato do payload da ISO verifica executável, desktop, ícone, launcher gaming standalone, sessão Wayland, Gamescope e Steam.

O contrato de perfis adiciona políticas de serviços de sistema `normal`, `lite`, `gaming` e definidas pelo usuário. O DinitUI salva-as em `~/.config/dinx/dinitui/profiles.conf`; `lite` desabilita somente o `bluetoothd` opcional, enquanto `gaming` habilita `bluetoothd` para controles e mantém disponíveis Bluetooth, UFW e os serviços de política do OpenSnitch. Ele nunca desabilita a segurança de rede nem o caminho essencial de rede/áudio/login/display. O plugin local `dinx/performance` do Noctalia expõe o atalho Gaming e o painel de perfis no Control Center, chama o `dinitui` por argv direto e mapeia Gaming para o perfil de energia `performance` do Noctalia. A sessão Gamescope standalone continua independente porque não inicia Noctalia.

O fluxo do centro de controle DINXPanel é dono das ações visíveis de GPU: delega ao DinitUI o contrato fixo de backend `--gpu-status` e `--install-gpu-drivers` e oferece atalhos fixos para NetworkManager, Bluetooth, display, áudio, firewall, opções do labwc, serviços Dinit, upgrades de pacotes e firmware. `Check upgrades` usa `shelly sync`, `shelly list-updates all`, `fwupdmgr refresh` e `fwupdmgr get-updates` sem instalar nada; o preview do Topgrade usa `--dry-run --show-skipped`, enquanto as ações explícitas de Topgrade e Shelly continuam como fluxos confirmados pelo usuário no terminal. Seu instalador de kernels expõe apenas `linux`, `linux-lts`, `linux-zen` e `linux-hardened` com os headers correspondentes, instala por argv direto, nunca remove pacotes, protege o kernel em execução e exige reinicialização.



O contrato de desktop labwc/Noctalia da DINX é explícito:

- o labwc fornece uma sessão Wayland com janelas empilhadas; sua configuração versionada mantém dois workspaces e `Super+Return` inicia `dinx-terminal`;
- a barra Noctalia chamada `main` reserva o topo e o dock de aplicativos reserva a parte inferior;
- NetworkManager, BlueZ, UPower e PipeWire alimentam os widgets de rede, Bluetooth, bateria e volume do Noctalia;
- o Noctalia é dono das superfícies de captura de tela e clipboard; `wl-copy`/`wl-paste` continuam como complemento de CLI, enquanto `grim`/`slurp` não são duplicados.
- a barra principal inclui um drawer de tray StatusNotifier; `libayatana-appindicator` mantém aplicativos indicadores legados visíveis pela mesma superfície;

O dock do Noctalia é limitado deliberadamente às superfícies DINX principais: Firefox, DINXPanel, DinitUI, BC250 Control Center, Phyto, Pori, Foot, Noctty e NoctEd. Ferramentas especializadas continuam descobertas pelo launcher e mantêm seus arquivos desktop: `nm-connection-editor`, Blueman, pwvucontrol, Gufw, Qps, OpenSnitch, Shelly, Swayimg, KolourPaint, VLC, Strawberry, `wdisplays` e `shikane`; Dome e Seafoam Settings opcionais aparecem da mesma forma quando seus pacotes Seafoam estão instalados. O ZLS continua sendo backend do editor, não superfície do launcher.

O `wdisplays` é o editor interativo de displays por meio do wrapper DINX `dinx-wdisplays`. Ao fechar o editor, o perfil DINX `DINX wdisplays` é substituído atomicamente em `~/.config/shikane/config.toml` e o Shikane é recarregado; o daemon inicia com o labwc e reaplica perfis correspondentes quando as saídas mudam. O Seafoam Settings agrupa pontos de entrada fixos para o wrapper, o salvador de perfil, Shikane, labwc, DinitUI, DINXPanel, Qt6ct e Dome sem criar um segundo backend de Settings. O monitoramento de recursos/processos do Dome é compatível com dinit, enquanto seu provedor opcional de serviços systemd fica indisponível. O Nocted usa o ZLS 0.16.0 opcional para operações LSP Zig quando instalado.

Aqueous/Pearl não são uma sessão DINX suportada nesta etapa. O upstream exige `uwsm`/systemd para o ciclo de vida do usuário, enquanto a DINX mantém o dinit como limite de init; uma integração futura precisa substituir essa superfície por um launcher e serviços nativos do dinit antes de ganhar uma entrada no greeter. O `dinx-doctor` registra esse limite e diferencia pacote ausente de sessão suportada, sem executar ações de mutação.


O widget de sessão do Noctalia continua sendo a superfície de energia. A DINX também fornece `Super+L`, uma ação `Lock screen` no launcher e botões na DINXPanel para bloquear e alterar o brilho em passos de 5%. O `swayidle` bloqueia após 10 minutos e invoca a mesma ação pelo evento `before-sleep`, portanto a suspensão é precedida por uma tentativa de bloqueio. `brightnessctl` é associado às teclas padrão de brilho quando o compositor as expõe.
Os papéis de gerenciamento de pacotes são separados deliberadamente: `pacman` é dono da transação oficial do sistema Artix; Shelly é dono dos metadados e fluxos explícitos de pacotes/AUR; `paru` é o helper avançado de AUR; Topgrade orquestra previews e atualizações confirmadas pelo usuário; DINXPanel é a superfície visível de descoberta/relatório e nunca instala durante uma verificação. Nenhuma ferramenta inicia automaticamente, e receitas AUR exigem revisão explícita.
O suporte a AMD Cyan Skillfish/BC-250 é um contrato de payload: firmware AMDGPU do Artix, Mesa RADV, diagnóstico Vulkan e o governor SMU fixado são instalados. O serviço dinit inicia automaticamente apenas o caminho do governor para PCI `1002:13fe`, usa a faixa segura de 1000-1850 MHz e encerra em outro hardware, sem unidade systemd.
O BC250 Control Center v1.21.1 é o contrato de launcher/monitor da BC-250: seu pacote MIT fixado fornece entrada desktop, CLI, política polkit e daemon headless. O daemon é iniciado uma vez pela sessão do usuário labwc através de `/etc/xdg/labwc/autostart`, não por systemd ou serviço root dinit; a DINX remove a unidade systemd e o drop-in do Cyan upstream. O dinit continua sendo um limite de persistência de serviço ao vivo/somente leitura no aplicativo upstream, portanto a falha ao inspecionar um serviço persistente não pode impedir a inicialização nem a telemetria ao vivo.

## Nível 3 — integração avançada

Recursos opcionais podem usar interfaces documentadas do Noctalia:

- ações do launcher que abrem o Nocted em um arquivo e linha;
- ações do launcher que abrem o Noctty em um diretório de trabalho escolhido;
- notificações e ações de aplicativos;
- plugins opcionais que expõem projetos do editor, arquivos recentes ou perfis de terminal.

A falha de uma integração opcional não pode impedir o aplicativo de iniciar ou editar arquivos.

## Matriz de testes de compatibilidade

A suíte deve testar contratos observáveis, não detalhes de implementação:

| Área | Critério de aceitação |
| --- | --- |
| Descoberta do terminal | `$TERMINAL` inicia o Noctty com um shell e o diretório solicitado |
| Metadados do desktop | entradas `.desktop` são válidas e descobertas |
| Argumentos de inicialização | comportamento de arquivo, linha e diretório de trabalho é determinístico |
| Importação de tema | um fixture de tema documentado produz as cores semânticas esperadas |
| Mudança de tema | um caminho suportado altera o aplicativo sem perda de dados |
| Paleta DINX | as duas variantes da paleta Noctalia contêm todos os papéis semânticos e cores ANSI do terminal |
| Templates de aplicativos | btop, Foot, Ghostty, GTK 3/4, KDE e Qt consomem as saídas geradas pelo Noctalia; labwc usa a configuração versionada do compositor; Swayimg usa o fallback de overlay DINX |
| Greeter/instalador/boot | ReGreet, Calamares e GRUB expõem estados DINX de superfície, texto, seleção e foco |
| Firefox padrão | Firefox é o manipulador padrão de HTML/XHTML/HTTP/HTTPS |
| Política pró-user do Firefox | `policies.json` é analisado e desativa superfícies patrocinadas, Pocket/Stories, telemetria, recomendações, superfícies de assistente de IA e IP Protection integrado sem desativar atualizações |
| Layout do desktop | labwc fornece janelas empilhadas; Noctalia reserva a barra superior e o dock inferior |
| Segurança da sessão | `swayidle` bloqueia após 600 segundos, `before-sleep` invoca o wrapper de bloqueio, `Super+L` e o launcher invocam `swaylock`, e as teclas de brilho usam `brightnessctl` |
| Orçamento do payload | `scripts/check_dinx_budget.sh` impõe os tetos versionados de pacotes rootfs e inicialização dinit, a janela de boot QEMU de 120 segundos, o tamanho dos binários nativos e o teto de ISO de 4 GiB quando um caminho de ISO é fornecido; `scripts/measure_dinx_session.sh` relata snapshots de RSS/CPU sem tratar a ausência da sessão no host como prova |
| Utilitários do shell | Noctalia fornece UI de captura/clipboard; `wl-clipboard` fornece copy/paste de CLI |
| Caminho de mídia e imagem | `ffmpeg`, VLC, VA-API (`libva`/`vainfo`), SANE `scanimage`, KolourPaint e handlers MIME comuns de vídeo/áudio/imagem são fornecidos; decode por hardware e hardware de scanner continuam sendo afirmações de qualificação física |
| Gerenciamento de pacotes | `topgrade`, `paru` e Shelly usam a configuração ALPM/pacman do Artix, não têm dependência/unidade `systemd`, não adicionam repositórios Arch e continuam disponíveis para atualizações executadas explicitamente pelo usuário |
| BC250 Control Center | GUI/CLI/daemon v1.21.1, entrada no dock Noctalia, autostart na sessão do usuário labwc, fonte fixada e nenhum payload systemd; a telemetria ao vivo continua disponível quando a inspeção de persistência dinit não é suportada |
| Firewall/monitoramento de processos | Gufw, Qps e OpenSnitch são descobertos; os serviços UFW/OpenSnitch ficam desabilitados até configuração explícita |
| Fallback | aplicativos continuam utilizáveis sem o Noctalia |
| Falha de IPC | IPC indisponível ou malformado não impede a inicialização |
| Acesso por teclado | ações principais funcionam sem entrada de ponteiro |
| Controle de serviços DinitUI | serviços dinit carregados/descobertos por arquivo, status, ciclo de vida, dependências, ambiente, logs, sinais e shutdown usam argv validado do `dinitctl` com fallback `pkexec` restrito |
| Controle de manutenção DINXPanel | atalhos fixos de hardware/painéis, ações delegadas de status/instalação de GPU, fluxos de atualização de pacotes Shelly/Topgrade, descoberta opcional de firmware pelo fwupd, catálogo fixo de kernels Artix, execução por argv direto e segurança de kernel somente-instalação |
| Sessão gaming | entrada standalone `dbus-run-session` Gamescope/Steam, payload Mesa/RADV/Vulkan de 32 bits, launch/exit por fixture e launch/exit de filho headless do Gamescope |

## Gate de release da P2 — Noctty

O gate da P2 combina `zig build test`, qualificação de PTY/sessão com contabilização do allocator, qualificação determinística de protocolo/Unicode, fairness do GLib e paste grande, a matriz de TUIs instaladas em ReleaseSafe e `scripts/check_noctty_integration.sh`. A matriz instalada exercita Vim, nano, less, dialog, top, watch, whiptail, fzf, SQLite, Glances, Bash, man/less e SFTP local reais pelo caminho de PTY/VT de produção. Ela inicia primeiro o `info` instalado; em ambientes mínimos ou sem TTY, usa um fixture estilizado determinístico como fallback da superfície do `info`. Os argumentos de lançamento tmux/Zellij usam shims determinísticos para manter o gate do pacote headless.

O runner de três aplicativos Codex/Vim/btop usa um fixture local da superfície do Codex no gate do pacote DINX. Isso prova os casos reais de Vim e btop sem autenticação, rede ou dependência de produto Codex; não é evidência de Codex autenticado.

Cada interface do Noctalia suportada deve identificar a versão testada e a versão do adaptador. Mudanças de versão exigem executar novamente a matriz de compatibilidade.

## Gate de release da P3 — Nocted

O gate da P3 é `scripts/nocted_p3_qualification.sh`. Ele executa as qualificações determinísticas do core/índice/workers/estado/tarefas do Nocted, um probe LSP real com `clangd`, smoke GTK/X11 nativo nos modos escuro e claro e um fixture Git real pelo binário de produção `--git-probe`. O gate do pacote chama esse script após `zig build -Doptimize=ReleaseSafe test`; `check_noctty_integration.sh` e `check-iso-content.sh` verificam os contratos do pacote e da ISO.

O workflow P0 é o gate de release do pacote e da ISO resultantes. A execução com tag [39924316082](https://github.com/rufl/DINX/actions/runs/39924316082), no commit `0d1698a462d5d5486871a7aa17e9b97352ee9404`, passou o build de pacote/perfil, o boot e a validação do payload gráfico no QEMU, o contrato de particionamento e o smoke transacional BIOS/UEFI/Btrfs do Calamares, a instalação/primeiro boot/recuperação em discos BIOS e UEFI descartáveis, a verificação dos metadados de build, a assinatura persistente de pacotes, a atestação do release e a publicação dos assets da Alpha 9. Mudanças futuras devem passar pelo mesmo gate antes de atualizar a evidência de release.
