# Arquitetura da DINX

[Português (Brasil)](architecture.md) · [English](../architecture.md)

## Princípios

1. **Integração profunda, dependências fracas.** Os aplicativos compartilham contratos e experiência sem exigir toda a distribuição em tempo de execução.
2. **Componentes de baixo nível comprovados.** Terminal, edição, parsing e ferramentas de linguagem são pontos de integração, não motivos para reimplementar subsistemas maduros.
3. **O sistema inicializável é o primeiro produto.** Instalação, login, recuperação e atualização devem ser testáveis antes de ampliar o payload.
4. **Operações privilegiadas restritas.** Interfaces não podem transformar entrada arbitrária em comandos privilegiados.
5. **Tarefas comuns no primeiro boot.** Handlers, mídia, diagnóstico, recuperação e fontes de pacotes devem ter um caminho funcional ou estado indisponível explícito.
6. **Padrões antes de lock-in.** A DINX usa XDG, Wayland, PipeWire, D-Bus, entradas desktop e interfaces dinit documentadas.
7. **Evidência antes de afirmações.** Recursos enviados têm gate estático, fixture, CI, QEMU ou hardware físico; caminhos experimentais permanecem identificados.

## Camadas do sistema

```text
Aplicativos DINX
  Deetty · Dintor · DinitUI · DINXPanel · ZLS

Contratos compartilhados
  Tema DINX estático · XDG · .desktop · $TERMINAL · D-Bus padrão

Sessão do desktop
  Wayland · River · KWM · agreety sob greetd

Fundação
  Artix Linux · dinit · kernel · Mesa/Vulkan · PipeWire · D-Bus · portais · polkit

Release e validação
  manifestos · assinatura · build ISO · checksums · VM · relatórios de hardware
```

## Fundação da distribuição

O alvo é Artix Linux com dinit em x86_64. A imagem base fornece:

- ISO inicializável e caminho de instalação documentado;
- login gráfico com TTY de recuperação;
- rede, PipeWire, D-Bus, portais, polkit e gráficos acelerados;
- Pori para discos/montagens sobre UDisks2, com serviços persistentes dinit em `/etc/dinit.d`;
- PCManFM como gerenciador de arquivos, handler padrão de diretórios e renderizador dos ícones de `~/Desktop` via `pcmanfm --desktop`;
- File Roller para abrir/criar/extrair arquivos compactados e GParted para particionamento independente;
- `wdisplays` e `shikane` para configuração Wayland e reaplicação de layouts;
- manifestos que identificam cada entrada específica da DINX;
- snapshot reproduzível em ambiente de build limpo.

Pacotes upstream são preferidos. Pacotes e patches específicos da DINX permanecem pequenos, explícitos e identificáveis.

## Limites dos aplicativos

### Deetty e Dintor

Deetty é responsável pela janela, preferências, atalhos, abas/painéis e sessões de terminal. Seu núcleo Zig possui parsing VT, células Unicode, cursor/modos, scrollback limitado, seleção, paste e ciclo de vida PTY. O pacote `ghostty-vt-runtime` fornece somente o adaptador VT público do Ghostty; o aplicativo de terminal Ghostty não faz parte do payload da DINX.

Dintor é um editor leve, não um IDE completo. Seus limites são estado/UI Zig, motor de edição, parser de sintaxe, cliente LSP, status/diff Git limitado e abertura XDG. O ISO inclui o ZLS para projetos Zig; C/C++ pode usar `clangd` quando o pacote opcional `clang` estiver instalado. O editor escolhe o esquema por `DINX_COLOR_SCHEME` ou `DINTOR_THEME` e usa o esquema escuro DINX por default. Ele continua funcional sem serviço de shell ou IPC privado.

### DinitUI

DinitUI é o frontend DINX do dinit. Descobre serviços carregados e arquivos de descrição, exibe status, logs em buffer, dependências, ambiente, sinais e ações do daemon por argv validado do `dinitctl`. Nunca interpola texto do usuário em shell.

O escopo de usuário usa `dinitctl --user`. O escopo de sistema usa `dinitctl --system` e recorre a `pkexec` somente após falha explícita de autorização. Os perfis `normal`, `lite`, `gaming` e customizados persistem em `~/.config/dinx/dinitui/profiles.conf`; `lite` desabilita somente o Bluetooth opcional e `gaming` habilita Bluetooth para controles. O Firewalld é um serviço de sistema separado, habilitado no boot e fora desses perfis.

### DINXPanel

A DINXPanel é o centro de controle. Ela agrupa entradas fixas para rede, Bluetooth, display, áudio, firewall, serviços dinit, upgrades e firmware, além do catálogo de kernels Artix (`linux`, `linux-lts`, `linux-zen`, `linux-hardened`). O botão Firewall abre a interface `firewall-config`; `firewalld-dinit` habilita o daemon no boot. O relatório somente leitura de upgrades usa `checkupdates` do `pacman-contrib` para os repositórios oficiais, `paru -Qu` para o AUR e metadados opcionais de fwupd; o botão `Package manager` abre o Octopi, cuja elevação ocorre por `pkexec` e polkit porque a DINX não envia sudo. Kernels nunca são removidos, e mudanças informam a necessidade de reinicialização.

CUPS é uma opção pós-instalação: a DINXPanel baixa `cups-dinit` e o usuário habilita o serviço pelo DinitUI quando necessário.

### Ferramentas de display

A configuração de display da DINX passa pelo wrapper `dinx-wdisplays`: ele executa o `wdisplays` e depois o `dinx-save-shikane-profile` exporta o resultado como o perfil `DINX wdisplays` em `~/.config/shikane/config.toml`; o botão `Display` da DINXPanel abre esse mesmo wrapper. Deetty é o único emulador de terminal da ISO; Nano continua como editor de recuperação.

### River, KWM e o limite dinit

`River + KWM + Morghulis (DINX)`, em `/usr/share/wayland-sessions/dinx-river-kwm-morghulis.desktop`, é a única sessão de usuário selecionável e suportada: `DesktopNames=river;kwm;morghulis` e `Exec=dbus-run-session /usr/local/libexec/dinx-river-session`. O roster do perfil instala o `river` do repositório Artix e os pacotes DINX `kwm`, que implementa o protocolo obrigatório `river-window-management-v1` e é compilado com `-Dbar=false`, de modo que o KWM não traz barra própria, `morghulis`, o shell de desktop DINX cuja NavBar é a superfície de status e que também fornece runner, menu rápido, notificações, OSD e menu de energia, `kwim`, o helper DINX de gerenciamento de entrada do river, que configura dispositivos de entrada independentemente do gerenciador de janelas, `dinx-dock`, a barra de lançadores layer-shell GTK4 de primeira parte que respeita a posição salva do dock, `dinx-first-run`, o assistente de aparência de primeira execução, e `greetd-agreety`. O `/usr/local/libexec/dinx-river-session` é o wrapper único da live e do greeter: normaliza o locale para `C.UTF-8` quando o charmap não é UTF-8, exporta as variáveis de desktop e dos toolkits Wayland além dos defaults escuros de recuperação da DINX, lê o perfil de gráficos de `/usr/local/libexec/dinx-graphics-profile`, valida o `XDG_RUNTIME_DIR` criando-o em modo 0700 e rejeitando um diretório de outro usuário, e toma um `flock` não bloqueante em `$XDG_RUNTIME_DIR/dinx-river-session.lock` para que um segundo compositor em corrida saia com código 0 em vez de disputar o seat. O backend libseat é escolhido em tempo de execução: `seatd` quando `/run/seatd.sock` existe e o usuário está no grupo `seat`, e `logind`/elogind caso contrário, que sob dinit nunca marca a sessão como ativa.

Antes de iniciar o compositor, o wrapper executa `xdg-user-dirs-update`, então contas novas da live e do sistema instalado recebem os diretórios XDG padrão, incluindo `~/Desktop`, antes do desktop aparecer. Ele semeia `~/.config/qt6ct/qt6ct.conf` e a paleta qt6ct DINX pelo `dinx-qt6ct-palette-seed` quando estão ausentes e copia o `/etc/xdg/kwm/config.zon` empacotado para `~/.config/kwm/config.zon` somente quando o arquivo não existe, para que edições do usuário sobrevivam a todos os boots. Por fim executa `river -c /usr/local/libexec/dinx-river-init`.

`/usr/local/libexec/dinx-river-init` é a própria configuração do river. O River 0.5 não fornece `riverctl` e não inicia um gerenciador de janelas, então o init executa `dinx-session-supervisor river`; depois da prontidão de Wayland e do D-Bus da sessão, o supervisor inicia o KWM como implementação obrigatória de `river-window-management-v1`. O build padrão do KWM inicia o KWIM para gerenciar entrada.

O supervisor grava em `$XDG_STATE_HOME/dinx/session.log`, escreve `starting`, `ready`, `failed` e `exited` em `$XDG_STATE_HOME/dinx/session.status`, espera o socket Wayland e depois o D-Bus da sessão, executa a cola de aparência de primeira execução `/usr/local/libexec/dinx-desktop-first-run` antes de qualquer componente do shell, e inicia os helpers obrigatórios `kwm`, `shikane`, `lxqt-policykit-agent`, `/usr/local/libexec/dinx-idle` e `morghulis`, além da barra de lançadores opcional `dinx-dock`. O KWM fornece `river-window-management-v1` e inicia o KWIM para `river-input-management-v1`. O supervisor inicia `bc250-control-centerd` somente quando esse pacote assinado, instalado separadamente, está presente em uma máquina com PCI `1002:13fe`; a ISO genérica não inclui esses pacotes. Quando um helper obrigatório morre, o supervisor registra `failed`, encerra os filhos e o pai do compositor monitorado, de modo que um helper quebrado encerra a sessão em vez de deixar um desktop em branco; ele também sai de forma limpa quando o compositor termina primeiro. As receitas não instalam unidades systemd ou `uwsm` nem biblioteca systemd, e nada no caminho da sessão referencia systemd, systemctl, uwsm ou loginctl.

A imagem live inicia o wrapper pelo serviço dinit reiniciável `dinx-live-session` em vez de um display manager: a livefs sombreia `/etc/dinit.d/greetd` com uma unidade no-op roteirizada, então nenhum display manager entra no boot live. O `openvt` cria e ativa o VT 7 dedicado, o `runuser` entra na conta descartável `dinx` e o `dbus-run-session` fornece o barramento. O pacote exclusivo da live `dinx-live-autologin` define o hostname `dinxlive`, provisiona `/run/dinx-session` em modo 0700 para `dinx`, adiciona `dinx` aos grupos `render` e `seat` e espera `/run/seatd.sock` por até cinco segundos.

O login instalado usa greetd e agreety em vez de um host dedicado de greeter: `/etc/greetd/config.toml` define `vt = 7` e `source_profile = false`, e seu `[default_session]` executa `env XDG_CACHE_HOME=/var/cache/agreety agreety --cmd /usr/local/libexec/dinx-river-session` pela conta `greeter` criada pelos sysusers do próprio greetd, cujo único estado necessário é o diretório `/var/cache/agreety` provido por tmpfiles. O agreety oferece a única entrada `River + KWM + Morghulis (DINX)` dos wayland-sessions, sem fallback de sessão e sem troca silenciosa. A unidade dinit `greetd` instalada executa `/usr/bin/greetd` com `smooth-recovery = true` e `restart-delay = 7`, gravando em `/var/log/dinit/greetd.log`.

Os usuários live e recém-instalados recebem acesso ao grupo `render`: o `dinx-live-autologin` adiciona `dinx` ao grupo na preparação do boot e o `users.conf` do Calamares concede o grupo ao usuário instalado. O helper de gráficos se vincula ao driver por trás de cada render node DRM acessível, não à ordem das placas DRM, e o `dinx-graphics-environment.sh` aplica o perfil resultante: QEMU `virtio_gpu`/virgl seleciona `virtual-gl` com `WLR_RENDERER=gles2`; VirtualBox VMSVGA (`vmwgfx`) e `vboxvideo` legado selecionam `vulkan` somente quando um render node acessível os identifica; ausência de render node acessível, `qxl`, `bochs`, `simpledrm` e `cirrus` selecionam `cpu` com `WLR_RENDERER=pixman`; qualquer outro driver seleciona `hardware` sem override. `GSK_RENDERER` fica sempre sem valor para que o GTK 4 escolha o próprio renderizador, e `vulkan-swrast` permanece empacotado para aplicativos em vez de ser forçado na apresentação do compositor.

`dinx-doctor` é uma superfície somente leitura para sessão, dinit, armazenamento, display e pacotes. Não inicia serviços, monta dispositivos, altera Shikane, executa transações ou acessa a rede.

## Tema e contratos compartilhados

Os contratos compartilhados são versionados independentemente dos detalhes internos:

- tema e tokens de design;
- locais XDG de configuração;
- metadados `.desktop` e comportamento de linha de comando;
- `$TERMINAL` e diretório de trabalho;
- adaptadores D-Bus padrão para notificações;
- convenções de logs e diagnósticos.

O contrato do Tema DINX v1 é uma paleta estática em `/usr/share/dinx/theme/DINX.json` com papéis semânticos de superfície/texto/primário/erro, variantes clara/escura, paleta ANSI completa, Noto Sans 10 para bridges gráficas, geometria quadrada, Papirus como tema padrão de ícones da área de trabalho e bridge de ícones Adwaita para os controles DINX; o `DINX.json` continua sendo o default da marca. A DINX envia uma aparência selecionável: o assistente de primeira execução `dinx-first-run`, executado pelo supervisor antes do shell por meio de `/usr/local/libexec/dinx-desktop-first-run` e uma vez por conta atrás do marcador `~/.local/state/dinx/desktop-first-run-complete`, pergunta idioma (pt-BR/en-US), localização (America/Sao_Paulo ou UTC), família de tema (DINX, Skeuos, Orchis, Fluent ou Jasper), variante escura ou clara, cantos arredondados ou quadrados, posição da barra (topo/base) e posição do dock (esquerda/direita/base/nenhum), grava `~/.config/dinx/appearance.json` e `~/.config/dinx/installer-preferences.json`, define a chave GSettings `navbar-anchor` do Morghulis e recarrega o dock via SIGHUP. O `dinx-river-session` exporta `DINX_COLOR_SCHEME=dark` e `DINTOR_THEME=prefer-dark` como defaults de recuperação além de `QT_QPA_PLATFORMTHEME=qt6ct`, define `XDG_CURRENT_DESKTOP=river` exatamente porque o Morghulis precisa da string literal, não exporta mais `GTK_APPLICATION_PREFER_DARK_THEME` nem `ADW_DEBUG_COLOR_SCHEME`, e nunca força `GTK_THEME`, então os aplicativos mantêm sua própria seleção de tema. Quando existe um barramento de sessão, o `dinx-sync-session-theme` lê `~/.config/dinx/appearance.json` e mapeia família, variante e cantos escolhidos sobre os nomes enviados em `/usr/share/themes`, o default DINX ou, por exemplo, `Jasper-Square-Light` para Jasper com variante clara e cantos quadrados: grava esse `gtk-theme-name` e o `gtk-application-prefer-dark-theme` correspondente nos `settings.ini` do GTK 3/4, o valor `'prefer-dark'` ou `'prefer-light'` compatível em `/org/gnome/desktop/interface/color-scheme` no dconf, e aponta o Qt6ct para `$XDG_CONFIG_HOME/qt6ct/colors/DINX.conf` com `custom_palette=true` no escuro ou `custom_palette=false` no claro, preservando as demais configurações dos toolkits e symlinks gerenciados pelo usuário; um `appearance.json` ausente ou inválido cai no default DINX escuro. O keyfile compilado do sistema `/etc/dconf/db/local.d/99-dinx-dark` já informa `color-scheme='prefer-dark'`, então os aplicativos egui e libadwaita/GTK abrem em modo escuro antes de a sessão escrever o valor do usuário. A superfície de login do agreety roda antes da sessão do usuário e consome somente as bridges GTK/Qt DINX estáticas; Calamares, Swayimg e GRUB usam bridges estáticas com os mesmos tokens. `dinx-noto-latin` fornece estilos Noto Sans e Noto Sans Mono em um subset latino/latim estendido; campos de largura fixa, logs monoespaçados do DinitUI/DINXPanel e `u_vga16 16` do GRUB são limites intencionais da plataforma. A qualificação do contrato é feita por `scripts/check_dinx_theme.sh`.

## Sessão gaming

DINX Gaming é um launcher manual oculto, não uma sessão selecionável. A ISO base mantém apenas o launcher e a entrada desktop; Gamescope, Steam, regras de dispositivos Steam, GameMode, MangoHud e bibliotecas de 32 bits ficam no grupo opcional `gaming` (`iso:false`) e vêm do Artix após a instalação. A base mantém RADV e ferramentas Vulkan de 64 bits. O builder P0 instala Gamescope somente para a qualificação headless; não habilita `[lib32]` nem inclui esses pacotes na ISO. O launcher verifica Gamescope e Steam antes de alterar o perfil Dinit; o fixture confirma falha fechada se faltar qualquer um. Saída DRM real e gaming autenticado continuam sem qualificação.

## Armazenamento, NTFS e display

Pori usa UDisks2 e grava serviços dinit `process` em `/etc/dinit.d` que aguardam dispositivos, repetem montagens, mantêm somente montagens próprias e desmontam no encerramento. Nenhuma unidade de montagem systemd é gerada.

O PCManFM é o único gerenciador de arquivos base e renderiza os ícones de `~/Desktop` via `pcmanfm --desktop`. File Roller e GParted cobrem arquivos compactados e particionamento independente. O módulo `ntfs3` fornece leitura/escrita NTFS na live e no sistema instalado; `ntfs-3g` é opcional pós-instalação. Fast Startup e hibernação do Windows devem ser desativados antes de montar um volume compartilhado.

`dinx-wdisplays` serializa exports com `flock`, substitui atomicamente o perfil `DINX wdisplays` em `~/.config/shikane/config.toml` e falha visivelmente se o reload do Shikane falhar. Shikane inicia dentro da sessão River/KWM e reaplica perfis quando as saídas mudam.

## Manifesto e CI

`feature-groups.json` inventaria rootfs, init dinit, boot e livefs. `scripts/check_dinx_feature_groups.sh` compara inventários com as fontes YAML, rejeita ownership duplicado e impede pacotes opcionais no perfil base. `contracts.yml` executa checks não privilegiados; o workflow P0 permanece o gate privilegiado de build, QEMU, instalação, recuperação, atestação e release.

`scripts/check_dinx_budget.sh` mantém os tetos de pacotes rootfs, entradas dinit, binários e ISO. `scripts/check_dinx_session.sh`, `check_dinx_theme.sh`, `check_dinx_display_persistence.sh`, `check_pori_storage.sh` e `check-iso-content.sh` verificam a integração observável antes da montagem final.
