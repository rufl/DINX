# Contrato de compatibilidade DINX

[Português (Brasil)](compatibility.md) · [English](../compatibility.md)

Os aplicativos da DINX integram-se por metadados XDG, protocolos Wayland, D-Bus, PipeWire e limites dinit padrão. A sessão base não exige IPC privado de shell, systemd, uwsm ou serviço de shell para funcionar.

## Nível 1 — integração direta

Obrigatório para a ISO base:

- O Deetty é descoberto por `$TERMINAL`, aceita os argumentos documentados de inicialização e respeita um diretório de trabalho quando fornecido.
- O Dintor possui uma entrada `.desktop` válida, abre arquivos e diretórios por launchers XDG padrão e aceita argumentos de arquivo/linha suportados.
<<<<<<< HEAD
- O ZLS 0.16.0 está disponível como pacote DINX opcional para a integração LSP de Zig do Dintor e não faz parte da imagem base. O suporte LSP para C/C++ usa `clangd` do pacote opcional `clang`.
- O Floorp é o manipulador padrão de HTML, XHTML, HTTP e HTTPS.
- O OpenSnitch é instalado com inicialização da interface e daemon gerenciado pelo Dinit tanto no sistema live quanto no instalado. Seus padrões nftables permitem tráfego e não interceptam aplicativos desconhecidos; o Firewalld permanece como serviço separado.
- O PCManFM é o manipulador padrão de diretórios e desktop; o File Roller cuida de abrir/criar/extrair arquivos compactados; o GParted cuida do particionamento independente.
=======
- A ISO inclui o ZLS 0.16.0 para a integração LSP de Zig do Dintor. O suporte LSP para C/C++ usa `clangd` do pacote opcional `clang` e não faz parte da imagem padrão.
- O Firefox é o manipulador padrão de HTML, XHTML, HTTP e HTTPS.
- O Firewalld é instalado com o `firewall-config` e o serviço gerenciado pelo Dinit habilitado no boot tanto no sistema live quanto no instalado.
- O PCManFM é o manipulador padrão de diretórios e renderiza os ícones de `~/Desktop` via `pcmanfm --desktop`; o File Roller cuida de abrir/criar/extrair arquivos compactados; o GParted cuida do particionamento independente.
>>>>>>> main
- O Pori descobre dispositivos de bloco pelo UDisks2 e persiste montagens do usuário por serviços dinit em `/etc/dinit.d`.
- Navegação por teclado e locais XDG de configuração/dados continuam utilizáveis sem integração privada de shell.

## Nível 2 — integração visual e de sessão

O contrato do tema estático DINX é a fonte de verdade:

- paleta: `/usr/share/dinx/theme/DINX.json`;
- escolha de cor do usuário: `DINX_COLOR_SCHEME=light|dark`, com `DINTOR_THEME=prefer-light` aceito pelo Dintor;
- cores Qt6ct: `~/.config/qt6ct/colors/DINX.conf`;
<<<<<<< HEAD
- tema GTK: defaults Adwaita; Morghulis salva a escolha clara/escura em `~/.config/morghulis/preferences.json` e o sincronizador aplica-a a dconf, GTK 3/4 e Qt6ct preservando configurações não relacionadas.
=======
- tema GTK: os defaults do sistema e do esqueleto são Adwaita com `gtk-application-prefer-dark-theme=1`, e a sessão aplica a família de tema escolhida no assistente de primeira execução, com Noto Sans 10 do subset latino/latim estendido DINX. O `dinx-river-session` exporta `DINX_COLOR_SCHEME=dark` e `DINTOR_THEME=prefer-dark` como defaults de recuperação e não exporta mais `GTK_APPLICATION_PREFER_DARK_THEME` nem `ADW_DEBUG_COLOR_SCHEME`; quando o D-Bus da sessão está pronto, o `dinx-sync-session-theme` lê `~/.config/dinx/appearance.json` e grava o esquema de cores `prefer-dark`/`prefer-light` correspondente no dconf, o `gtk-theme-name` selecionado (DINX por default) e a paleta DINX do Qt6ct. Um `appearance.json` ausente ou inválido cai no default DINX escuro. As demais configurações dos toolkits são preservadas.
>>>>>>> main
- texto de largura fixa: Noto Sans Mono 10 do mesmo subset quando exigido pelo aplicativo;
- bridges gráficas: estados DINX de superfície, controle, hover, primário e erro, com ícones Adwaita quando disponíveis; Papirus é o tema padrão de ícones da área de trabalho.

`DINX_COLOR_SCHEME=light` ou `DINTOR_THEME=prefer-light` seleciona o esquema claro empacotado do editor. Os demais valores usam o esquema escuro DINX. O Dintor não interpreta arquivos privados de shell e continua funcional sem nenhuma variável.

<<<<<<< HEAD
Morghulis, Calamares e GRUB consomem bridges estáticas DINX porque executam antes ou fora do estado específico dos aplicativos. Deetty, PCManFM, Swayimg, btop, GTK e Qt usam seus caminhos DINX versionados. `ghostty-vt-runtime` fornece somente a biblioteca VT e headers necessários ao Deetty; não instala o terminal Ghostty. `scripts/check_morghulis_theme.sh` e `scripts/check-iso-content.sh` validam o tema e o payload da ISO.
=======
O agreety, o Calamares e o GRUB usam bridges estáticas DINX porque executam antes ou fora da sessão do usuário. O agreety roda sob o greetd pela conta `greeter` com `XDG_CACHE_HOME=/var/cache/agreety`; não existe arquivo separado de tema do greeter. Deetty, Swayimg, btop, GTK e Qt usam seus caminhos DINX versionados. `ghostty-vt-runtime` fornece somente a biblioteca VT e os headers do Ghostty necessários ao Deetty; não instala o terminal Ghostty. `scripts/check_dinx_theme.sh` valida paleta, tipografia, estados e bridges; `scripts/check-iso-content.sh` repete os checks dentro do SquashFS.
>>>>>>> main

## Contrato do gerenciador de serviços DinitUI

DinitUI é o frontend DINX do dinit, não uma camada de compatibilidade com systemd. Ele descobre serviços carregados e arquivos de descrição, exibe status e logs em buffer e expõe ações de ciclo de vida, dependências, ambiente, sinais e daemon por argv validado do `dinitctl`. Nunca interpola texto do usuário em comandos de shell.

O escopo de usuário usa `dinitctl --user`. O escopo de sistema usa `dinitctl --system` e só tenta `pkexec` após uma falha explícita de autorização. Perfis `normal`, `lite`, `gaming` e definidos pelo usuário persistem em `~/.config/dinx/dinitui/profiles.conf`; `lite` desabilita somente Bluetooth opcional, enquanto `gaming` habilita Bluetooth para controles e preserva serviços de firewall/política de processos. O launcher gaming standalone entra e restaura o perfil explicitamente.

<<<<<<< HEAD
## Integração de display e Seafoam

`dinx-wdisplays` inicia o editor interativo de displays Wayland. Ao fechar, serializa o resultado com `flock`, substitui atomicamente o perfil DINX `DINX wdisplays` em `~/.config/shikane/config.toml` e recarrega o Shikane. Falha no reload é reportada como falha. O Shikane inicia dentro de River/KWM/Morghulis e reaplica perfis correspondentes quando as saídas mudam.

O Seafoam Settings expõe entradas fixas para wdisplays, salvador de perfil, Shikane, DinitUI, DINXPanel, Qt6ct e Mission Center. Mission Center fornece monitoramento GTK4 de recursos/processos. Os pacotes Zig nativos da DINX usam Zig 0.17.0. O ZLS é um backend opcional do editor; quando instalado, seu runtime compacto contém a biblioteca padrão Zig 0.16.0 correspondente e um shim de metadados. Instalar o pacote opcional `zig` do Artix habilita comandos de compilação pelo mesmo shim.

## Contrato da sessão River/KWM/Morghulis

River é o compositor, KWM fornece a política de janelas, Morghulis fornece a superfície do desktop e PCManFM fornece o gerenciador de arquivos/desktop. `dinx-river-session` prepara o runtime Wayland e executa a sessão River; `dinx-river-init` supervisiona KWM, Morghulis, PCManFM, Shikane, PolicyKit e idle sob dinit. O daemon opcional de controle BC-250 inicia somente quando seu pacote assinado separado está instalado.

- River/KWM/Morghulis é a sessão base do usuário.
- A ISO live usa o caminho direto `dinx-live-autologin`; sistemas instalados usam login manual via `agreety`.
- O helper first-run do Morghulis salva o tema e o sincronizador reaplica a escolha no login.
- Falhas de helpers obrigatórios encerram a sessão em vez de deixar um desktop vazio.
- A sessão usa seatd/libseat e não exige systemd, systemctl, uwsm ou unidades de usuário.

- `swayidle` bloqueia após 600 segundos e em `before-sleep`; `Super+L`, o launcher e a DINXPanel usam o mesmo caminho `swaylock`. `brightnessctl` fornece passos fixos de 5% para brilho.
=======
## Contrato da sessão River/KWM

River e KWM negociam `xdg-decoration` com cada cliente XDG: janelas que aceitam decorações do servidor recebem o próprio quadro DINX do compositor, enquanto clientes que mantêm decorações próprias nunca são decorados duas vezes. `GTK_CSD=0` desativa o CSD padrão do GTK, mas não barras customizadas criadas pelo aplicativo. O `dinx-river-session` exporta `MOZ_GTK_TITLEBAR_DECORATION=system` porque clientes Gecko como o Firefox escolhem decorações de cliente antes de verificar `GTK_CSD`, e os defaults GTK versionados trazem `gtk-decoration-layout=:minimize,maximize,close`.

Não há raio de canto no compositor nem sincronização de cor de borda: a aparência vem do tema GTK escolhido no assistente de primeira execução, DINX escuro por default. O kwim concentra a configuração dos dispositivos de entrada, separadamente do gerenciador de janelas, então layouts de teclado e ajustes de touchpad vivem na configuração do kwim, não em um aplicativo de preferências do shell.

- River/KWM é a única sessão de usuário selecionável e suportada da DINX.
- A ISO live abre `dinx` pelo serviço Dinit reiniciável `dinx-live-session`, com seatd e diretório de runtime privado; o greetd fica exclusivo da instalação e o rootfs instalado mantém login manual.
- O agreety sob o greetd é a interface de login instalada, não uma segunda sessão de usuário; a imagem DINX traz uma única entrada em wayland-sessions, `River + KWM + Morghulis (DINX)`, e não há fallback silencioso.
- `agreety --cmd /usr/local/libexec/dinx-river-session` inicia a sessão. O River 0.5 não fornece `riverctl` e não inicia um gerenciador de janelas, então o `dinx-river-init` executa `dinx-session-supervisor river`; o supervisor espera a prontidão do Wayland e do D-Bus da sessão, inicia o KWM como gerenciador obrigatório, executa a cola de aparência de primeira execução `/usr/local/libexec/dinx-desktop-first-run` e inicia Shikane, o agente PolicyKit do LXQt, o idle obrigatório e o shell Morghulis obrigatório. O KWM inicia o KWIM para gerenciar entrada. O supervisor inicia `dinx-dock` como helper opcional, e o daemon opcional da BC-250 só inicia quando o pacote assinado é instalado separadamente; instale-o somente após detectar o PCI `1002:13fe`. A ISO genérica omite todos os pacotes específicos da BC-250.
- Falha de helper obrigatório ou do supervisor registra estado explícito e encerra o river, em vez de deixar um desktop vazio.
- A sessão live usa seatd/libseat; sessões instaladas mantêm a seleção de backend em runtime com elogind disponível. Ambos os caminhos executam diretamente sob dinit, sem exigir systemd, systemctl, uwsm ou unidades de usuário.

- `swayidle` bloqueia após 600 segundos e em `before-sleep`; a ação de launcher `dinx-lock` e a DINXPanel usam o mesmo caminho `swaylock`, e o `dinx-lock` se recusa a bloquear a sessão live descartável. `brightnessctl` fornece passos fixos de 5% para brilho.

## Configuração de display

`dinx-wdisplays` inicia o editor interativo de displays Wayland. Ao fechar, serializa o resultado com `flock`, substitui atomicamente o perfil DINX `DINX wdisplays` em `~/.config/shikane/config.toml` e recarrega o Shikane. Falha no reload é reportada como falha. O Shikane inicia dentro da sessão River/KWM e reaplica perfis correspondentes quando as saídas mudam.

A configuração de display é alcançada pelo wrapper `dinx-wdisplays`, pelo exportador `dinx-save-shikane-profile`, pelo daemon de usuário Shikane e pela ação `Display` da DINXPanel; não há launcher de ajustes separado. Os pacotes Zig nativos da DINX usam Zig 0.17.0. O ZLS continua sendo backend do editor; seu runtime compacto contém a biblioteca padrão Zig 0.16.0 correspondente e um shim de metadados, não o compilador completo. Instalar o pacote opcional `zig` do Artix habilita comandos de compilação pelo mesmo shim.
>>>>>>> main

## Limite do gaming

DINX Gaming é um launcher manual oculto, não uma sessão de usuário selecionável. A ISO inclui o launcher/entrada desktop, mas os binários Gamescope/Steam e bibliotecas de 32 bits pertencem ao grupo Artix opcional `gaming`, não ao perfil base. RADV/Vulkan de 64 bits continuam instalados. O launcher verifica Gamescope e Steam antes de alterar o perfil Dinit; fixtures confirmam que a transição não ocorre quando faltam pacotes. Saída DRM real e gaming autenticado continuam fora da qualificação.

## Matriz de testes de compatibilidade

| Área | Critério de aceitação |
| --- | --- |
| Descoberta do terminal | `$TERMINAL` inicia o Deetty com shell e diretório solicitado |
| Metadados desktop | entradas `.desktop` são válidas e descobertas |
| Inicialização de apps opcionais | Gapless herda a sessão Wayland ativa; firewall-config abre o gerenciador Firewalld; o Gerenciador Bluetooth explica a ausência do daemon/controlador (VirtualBox precisa de passthrough USB Bluetooth) |
| Argumentos de inicialização | comportamento de arquivo, linha e diretório é determinístico |
<<<<<<< HEAD
| Contrato de tema | paleta DINX estática, defaults escuros GTK 3/4 no sistema, seleção GTK escura na sessão, paleta DINX do Qt6ct e controles de fallback na barra de título GTK 3/4 estão configurados |
| Greeter/instalador/boot | agreety, Calamares e GRUB expõem estados DINX de superfície, texto, seleção e foco |
| Floorp padrão | O Floorp trata HTML/XHTML/HTTP/HTTPS por padrão |
| Armazenamento e arquivos | persistência dinit do Pori, diretórios no PCManFM, arquivos compactados no File Roller e edição no GParted estão presentes |
| Layout do desktop | River/KWM/Morghulis é a sessão base e PCManFM é o desktop; a configuração declarada da sessão é preservada |
| Gráficos em VM | O gate P0 completo testa o desktop live no VGA padrão e Virtio-VGA do QEMU; o boot direto VMSVGA no VBox continua sem qualificação. |
| Decorações das janelas | Os contratos River/KWM e de tema verificam o comportamento Wayland dos clientes e os controles de titlebar dos toolkits |
| Segurança da sessão | lock por idle, lock antes de suspend, lock explícito e brilho usam caminhos fixos |
| Persistência de display | mudanças do wdisplays atualizam atomicamente e recarregam o perfil nomeado do Shikane |
| ZLS | Pacote opcional; quando instalado, o Dintor encontra a biblioteca Zig correspondente sem compilador completo |
| Gerenciamento de pacotes | pacman, Shelly, paru e Topgrade usam a configuração Artix e são executados pelo usuário |
| Firewall/monitoramento | Firewalld, firewall-config, OpenSnitch e Mission Center são descobertos; firewalld-dinit é habilitado no boot nos root filesystems live e instalado |
=======
| Contrato de tema | paleta DINX estática, defaults escuros GTK 3/4 no sistema, seleção de tema GTK salva na sessão, paleta DINX do Qt6ct e controles de fallback na barra de título GTK 3/4 estão configurados |
| Greeter/instalador/boot | agreety, Calamares e GRUB expõem estados DINX de superfície, texto, seleção e foco |
| Firefox padrão | O Firefox trata HTML/XHTML/HTTP/HTTPS por padrão |
| Armazenamento e arquivos | persistência dinit do Pori, diretórios no PCManFM, arquivos compactados no File Roller e edição no GParted estão presentes |
| Layout do desktop | River/KWM é a única sessão de usuário; o supervisor inicia o KWM como implementação obrigatória de `river-window-management-v1`, então janelas novas são mosaicaladas pelo KWM e o comportamento flutuante/em pilha e a quantidade de workspaces vêm do `~/.config/kwm/config.zon` do usuário. Esse arquivo é semeado a partir de `/etc/xdg/kwm/config.zon` somente quando não existe, preservando configurações existentes |
| Gráficos em VM | Um relato manual anterior chegou ao desktop DINX no VirtualBox 7.2.22/Windows 11 (VMSVGA, 3D habilitado, EFI, 4 vCPUs, 8 GiB); o log não comprovou origem de boot nem checksum da ISO, portanto não qualifica o release. O código atual direciona render nodes `vmwgfx`/`vboxvideo` acessíveis ao Pixman (`WLR_RENDERER=pixman`), pois o log VMSVGA anexado mostrou o dispositivo Vulkan llvmpipe do VirtualBox falhando ao associar o dispositivo DRM; o QEMU `virtio_gpu` usa GLES2 com efeitos reduzidos. A renderização de superfícies de clientes na ISO reconstruída ainda aguarda verificação direta no VirtualBox. |
| Gráficos em VM | O gate P0 completo testa o desktop live no VGA padrão e Virtio-VGA do QEMU. O caminho `vmware-svga` do QEMU 11.1.2/KVM trava no udev inicial com `vmwgfx` carregado e não é um proxy confiável do VirtualBox; o boot direto VMSVGA no VBox continua sem qualificação. |
| Decorações das janelas | Testes da sessão verificam a política de decoração xdg-decoration negociada, decorações do sistema no Firefox/Gecko, o layout fixo `:minimize,maximize,close` do GTK e a aparência DINX salva |
| Segurança da sessão | lock por idle, lock antes de suspend, lock explícito e brilho usam caminhos fixos |
| Persistência de display | mudanças do wdisplays atualizam atomicamente e recarregam o perfil nomeado do Shikane |
| ZLS | Dintor encontra a biblioteca Zig correspondente sem compilador completo |
| Gerenciamento de pacotes | pacman, `paru` e Octopi usam a configuração Artix e são executados pelo usuário |
| Firewall | Firewalld e `firewall-config` são descobertos; firewalld-dinit é habilitado no boot nos root filesystems live e instalado |
>>>>>>> main
| DinitUI | descoberta e controle usam argv validado do dinitctl com fallback pkexec restrito |
| Gaming | launcher oculto mantido, grupo de pacotes opcional fora da base, falta de Gamescope/Steam falha antes da mudança de perfil; gaming real permanece sem qualificação |
| Isolamento de falhas | helpers ou endpoints D-Bus opcionais indisponíveis produzem falha visível sem bloquear o startup |
| Acesso por teclado | ações principais funcionam sem ponteiro |

## Gates de release

<<<<<<< HEAD
`scripts/check_deetty_integration.sh`, `scripts/dintor_p3_qualification.sh`, `scripts/check_dinitui.sh`, `scripts/check_river_session.sh`, `scripts/check_morghulis_theme.sh`, `scripts/check_mission_center.sh`, `scripts/check_dinx_display_persistence.sh` e `scripts/check-iso-content.sh` verificam os contratos de pacote, sessão e ISO. O workflow P0 continua sendo o gate de criação dos pacotes, montagem da ISO, boot QEMU, instalação Calamares, TTY de recuperação, atestação e publicação.
=======
`scripts/check_deetty_integration.sh`, `scripts/dintor_p3_qualification.sh`, `scripts/check_dinitui.sh`, `scripts/check_dinx_session.sh`, `scripts/check_dinx_display_persistence.sh`, `scripts/check_dinx_theme.sh`, `scripts/check_pori_storage.sh` e `scripts/check-iso-content.sh` verificam os contratos de pacote, sessão e ISO. O workflow P0 continua sendo o gate de criação dos pacotes, montagem da ISO, boot QEMU, instalação Calamares, TTY de recuperação, atestação e publicação.
>>>>>>> main
