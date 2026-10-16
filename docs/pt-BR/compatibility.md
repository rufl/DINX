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
O contrato visual entregue é a paleta Noctalia `DINX` em `~/.config/noctalia/palettes/DINX.json`. Ela define os papéis semânticos claro/escuro e a paleta ANSI completa do terminal; o Noctalia usa `source = "custom"`, `sync_color_scheme = true` e os templates nativos de btop, Foot, Ghostty, GTK 3/4, KDE, Mango e Qt.

Aplicativos GTK usam o tema fallback instalado `DINX` até o Noctalia aplicar seu CSS gerado. Aplicativos Qt usam `qt6ct` com `~/.config/qt6ct/colors/noctalia.conf` gerado pelo Noctalia; o Mango consome `~/.config/mango/noctalia.conf`. O Swayimg recebe um fallback DINX de overlay/galeria em `~/.config/swayimg/init.lua`. A sessão exporta defaults documentados para `NOCTALIA_COLOR_SCHEME`, `NOCTED_THEME`, `QT_QPA_PLATFORMTHEME`, `XCURSOR_THEME` e `XCURSOR_SIZE`.

ReGreet e Calamares consomem bridges estáticas DINX porque executam antes ou fora do shell. O GRUB usa os mesmos tokens de superfície/texto/primário, com as texturas opacas do menu desativadas. `scripts/check_dinx_theme.sh` valida a paleta, os templates, os pacotes e cada bridge antes do build da ISO; `check-iso-content.sh` repete as verificações dentro do SquashFS.

## Contrato do gerenciador de serviços DinitUI

DinitUI é o frontend DINX do dinit, não uma camada de compatibilidade com systemd. Descobre serviços carregados por `dinitctl list` e arquivos de descrição nos diretórios Dinit do sistema/usuário, incluindo o framing aninhado nativo do Dinit. Seu catálogo cobre ciclo de vida, dependências de boot/runtime, ambiente, logs em buffer, sinais e desligamento. `scripts/check_dinitui.sh` cobre o limite do pacote; a qualificação contra daemon real prova um daemon de usuário temporário pela superfície GTK.
A UI passa tokens validados diretamente ao `dinitctl`; nunca inicia um shell. O escopo de usuário usa `dinitctl --user`. O escopo system tenta primeiro `dinitctl --system` e usa `pkexec` somente após falha explícita de autorização. O contrato do payload da ISO verifica executável, desktop, ícone, launcher gaming standalone, sessão Wayland, Gamescope e Steam.



O contrato de desktop Noctalia/Mango da DINX é explícito:

- a regra de tags do Mango abre novas janelas como flutuantes; `Super+Space` alterna a janela focada de volta entre tiled/flutuante;
- a barra Noctalia chamada `main` reserva o topo e o dock de aplicativos reserva a parte inferior;
- NetworkManager, BlueZ, UPower e PipeWire alimentam os widgets de rede, Bluetooth, bateria e volume do Noctalia;
- o Noctalia é dono das superfícies de captura de tela e clipboard; `wl-copy`/`wl-paste` continuam como complemento de CLI, enquanto `grim`/`slurp` não são duplicados.

Os aplicativos independentes `nm-connection-editor`, Blueman, pwvucontrol, VLC e Strawberry continuam disponíveis no dock/launcher do Noctalia para fluxos completos de conexão, Bluetooth, áudio por stream, vídeo e biblioteca musical.
Gufw, Qps e a UI do OpenSnitch continuam disponíveis no dock/launcher; os serviços dinit UFW e OpenSnitch são instalados, mas não são habilitados no boot, portanto as regras de firewall exigem configuração deliberada. Não habilite os dois gerenciadores de regras sem revisar o ruleset netfilter resultante.
As ferramentas de gerenciamento `topgrade`, `paru` e Shelly continuam como complementos de launcher/CLI: topgrade usa o binário de release fixado e a configuração `pacman` do Artix da DINX, paru é compilado a partir de fonte fixada contra o ALPM do Artix e Shelly delega para a configuração `pacman` do Artix. Os pacotes não têm dependências ou unidades `systemd`, não adicionam repositórios Arch, não são iniciados pelo Noctalia nem pela sessão de boot e receitas AUR exigem revisão explícita do usuário.
O suporte a AMD Cyan Skillfish/BC-250 é um contrato de payload: firmware AMDGPU do Artix, Mesa RADV, diagnóstico Vulkan e o governor SMU fixado são instalados. O serviço dinit inicia automaticamente apenas o caminho do governor para PCI `1002:13fe`, usa a faixa segura de 1000-1850 MHz e encerra em outro hardware, sem unidade systemd.
O BC250 Control Center v1.21.1 é o contrato de launcher/monitor da BC-250: seu pacote MIT fixado fornece entrada desktop, CLI, política polkit e daemon headless. O daemon é iniciado uma vez pela sessão do usuário no Mango, não por systemd ou serviço root dinit; a DINX remove a unidade systemd e o drop-in do Cyan upstream. O dinit continua sendo um limite de persistência de serviço ao vivo/somente leitura no aplicativo upstream, portanto a falha ao inspecionar um serviço persistente não pode impedir a inicialização nem a telemetria ao vivo.

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
| Templates de aplicativos | btop, Foot, Ghostty, GTK 3/4, KDE, Mango e Qt consomem as saídas geradas pelo Noctalia; Swayimg usa o fallback de overlay DINX |
| Greeter/instalador/boot | ReGreet, Calamares e GRUB expõem estados DINX de superfície, texto, seleção e foco |
| Firefox padrão | Firefox é o manipulador padrão de HTML/XHTML/HTTP/HTTPS |
| Política pró-user do Firefox | `policies.json` é analisado e desativa superfícies patrocinadas, Pocket/Stories, telemetria, recomendações, superfícies de assistente de IA e IP Protection integrado sem desativar atualizações |
| Layout do desktop | Mango abre novas janelas como flutuantes; Noctalia reserva a barra superior e o dock inferior |
| Utilitários do shell | Noctalia fornece UI de captura/clipboard; `wl-clipboard` fornece copy/paste de CLI |
| Handlers de mídia | VLC assume entradas MIME comuns de vídeo; Strawberry assume entradas MIME comuns de áudio |
| Gerenciamento de pacotes | `topgrade`, `paru` e Shelly usam a configuração ALPM/pacman do Artix, não têm dependência/unidade `systemd`, não adicionam repositórios Arch e continuam disponíveis para atualizações executadas explicitamente pelo usuário |
| BC250 Control Center | GUI/CLI/daemon v1.21.1, entrada no dock Noctalia, autostart na sessão do usuário Mango, fonte fixada e nenhum payload systemd; a telemetria ao vivo continua disponível quando a inspeção de persistência dinit não é suportada |
| Firewall/monitoramento de processos | Gufw, Qps e OpenSnitch são descobertos; os serviços UFW/OpenSnitch ficam desabilitados até configuração explícita |
| Fallback | aplicativos continuam utilizáveis sem o Noctalia |
| Falha de IPC | IPC indisponível ou malformado não impede a inicialização |
| Acesso por teclado | ações principais funcionam sem entrada de ponteiro |
| Controle de serviços DinitUI | serviços dinit carregados/descobertos por arquivo, status, ciclo de vida, dependências, ambiente, logs, sinais e shutdown usam argv validado do `dinitctl` com fallback `pkexec` restrito |
| Sessão gaming | entrada standalone `dbus-run-session` Gamescope/Steam, payload Mesa/RADV/Vulkan de 32 bits, launch/exit por fixture e launch/exit de filho headless do Gamescope |

## Gate de release da P2 — Noctty

O gate da P2 combina `zig build test`, qualificação de PTY/sessão com contabilização do allocator, qualificação determinística de protocolo/Unicode, fairness do GLib e paste grande, a matriz de TUIs instaladas em ReleaseSafe e `scripts/check_noctty_integration.sh`. A matriz instalada exercita Vim, nano, less, dialog, top, watch, whiptail, fzf, SQLite, Glances, Bash, man/less e SFTP local reais pelo caminho de PTY/VT de produção. Ela inicia primeiro o `info` instalado; em ambientes mínimos ou sem TTY, usa um fixture estilizado determinístico como fallback da superfície do `info`. Os argumentos de lançamento tmux/Zellij usam shims determinísticos para manter o gate do pacote headless.

O runner de três aplicativos Codex/Vim/btop usa um fixture local da superfície do Codex no gate do pacote DINX. Isso prova os casos reais de Vim e btop sem autenticação, rede ou dependência de produto Codex; não é evidência de Codex autenticado.

Cada interface do Noctalia suportada deve identificar a versão testada e a versão do adaptador. Mudanças de versão exigem executar novamente a matriz de compatibilidade.

## Gate de release da P3 — Nocted

O gate da P3 é `scripts/nocted_p3_qualification.sh`. Ele executa as qualificações determinísticas do core/índice/workers/estado/tarefas do Nocted, um probe LSP real com `clangd`, smoke GTK/X11 nativo nos modos escuro e claro e um fixture Git real pelo binário de produção `--git-probe`. O gate do pacote chama esse script após `zig build -Doptimize=ReleaseSafe test`; `check_noctty_integration.sh` e `check-iso-content.sh` verificam os contratos do pacote e da ISO.

O workflow P0 é o gate de release do pacote e da ISO resultantes: ele deve passar o build do pacote, boot em QEMU, instalação persistente, recuperação e atestação antes de a P3 ser considerada liberável.
