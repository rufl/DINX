# Contrato de compatibilidade DINX

[Português (Brasil)](compatibility.md) · [English](../compatibility.md)

Os aplicativos da DINX integram-se por metadados XDG, protocolos Wayland, D-Bus, PipeWire e limites dinit padrão. A sessão base não exige IPC privado de shell, systemd, uwsm ou serviço de shell para funcionar.

## Nível 1 — integração direta

Obrigatório para a ISO base:

- O Deetty é descoberto por `$TERMINAL`, aceita os argumentos documentados de inicialização e respeita um diretório de trabalho quando fornecido.
- O Dintor possui uma entrada `.desktop` válida, abre arquivos e diretórios por launchers XDG padrão e aceita argumentos de arquivo/linha suportados.
- O Dintor inicia o LSP documentado para cada tipo de arquivo. Zig usa o ZLS 0.16.0 incluído; C/C++ usa `clangd`.
- O Firefox é o manipulador padrão de HTML, XHTML, HTTP e HTTPS.
- O Phyto é o manipulador padrão de diretórios; o File Roller cuida de abrir/criar/extrair arquivos compactados; o GParted cuida do particionamento independente.
- O Pori descobre dispositivos de bloco pelo UDisks2 e persiste montagens do usuário por serviços dinit em `/etc/dinit.d`.
- Navegação por teclado e locais XDG de configuração/dados continuam utilizáveis sem integração privada de shell.

## Nível 2 — integração visual e de sessão

O contrato do tema estático DINX é a fonte de verdade:

- paleta: `/usr/share/dinx/theme/DINX.json`;
- escolha de cor do usuário: `DINX_COLOR_SCHEME=light|dark`, com `DINTOR_THEME=prefer-light` aceito pelo Dintor;
- cores Qt6ct: `~/.config/qt6ct/colors/DINX.conf`;
- tema GTK: Adwaita com Noto Sans 10 do subset latino/latim estendido DINX; a sessão define o esquema `prefer-dark` do GNOME somente quando o usuário não tem uma escolha explícita de esquema de cores.
- texto de largura fixa: Noto Sans Mono 10 do mesmo subset quando exigido pelo aplicativo;
- bridges gráficas: estados DINX de superfície, controle, hover, primário e erro, com ícones Adwaita quando disponíveis.

`DINX_COLOR_SCHEME=light` ou `DINTOR_THEME=prefer-light` seleciona o esquema claro empacotado do editor. Os demais valores usam o esquema escuro DINX. O Dintor não interpreta arquivos privados de shell e continua funcional sem nenhuma variável.

Pearl Greeter, Calamares e GRUB usam bridges estáticas DINX porque executam antes ou fora da sessão do usuário. O Pearl Greeter lê `/etc/pearl/greeter.json`, roda pela conta dedicada `pearl-greeter` e força a única entrada Aqueous/Pearl com X11 e UWSM desativados. Deetty, Swayimg, btop, GTK e Qt usam seus caminhos DINX versionados. `ghostty-vt-runtime` fornece somente a biblioteca VT e os headers do Ghostty necessários ao Deetty; não instala o terminal Ghostty. `scripts/check_dinx_theme.sh` valida paleta, tipografia, estados e bridges; `scripts/check-iso-content.sh` repete os checks dentro do SquashFS.

## Contrato do gerenciador de serviços DinitUI

DinitUI é o frontend DINX do dinit, não uma camada de compatibilidade com systemd. Ele descobre serviços carregados e arquivos de descrição, exibe status e logs em buffer e expõe ações de ciclo de vida, dependências, ambiente, sinais e daemon por argv validado do `dinitctl`. Nunca interpola texto do usuário em comandos de shell.

O escopo de usuário usa `dinitctl --user`. O escopo de sistema usa `dinitctl --system` e só tenta `pkexec` após uma falha explícita de autorização. Perfis `normal`, `lite`, `gaming` e definidos pelo usuário persistem em `~/.config/dinx/dinitui/profiles.conf`; `lite` desabilita somente Bluetooth opcional, enquanto `gaming` habilita Bluetooth para controles e preserva serviços de firewall/política de processos. O launcher gaming standalone entra e restaura o perfil explicitamente.

## Contrato da sessão Aqueous/Pearl

O Aqueous desenha titlebars e controles DINX para clientes XDG cujo modo xdg-decoration negociado seja servidor. Por padrão, clientes que solicitam ou exigem decorações próprias mantêm suas titlebars; o Aqueous omite a barra, o deslocamento de 36 pixels do conteúdo e as zonas de interação da barra nessas janelas. Clientes XWayland usam os hints Motif de decoração: clientes CSD mantêm suas titlebars, enquanto clientes SSD/sem CSD recebem a decoração DINX. `force_ssd=true` substitui explicitamente CSD em clientes XDG. `GTK_CSD=0` desativa o CSD padrão do GTK, mas não barras customizadas criadas pelo aplicativo. O Firefox recebe `MOZ_GTK_TITLEBAR_DECORATION=system` porque seu caminho GTK Wayland escolhe decorações de cliente antes de verificar `GTK_CSD`. Em janelas com decoração do servidor, o Aqueous estende a máscara arredondada da superfície pelo titlebar do compositor: o conteúdo começa com cantos superiores quadrados sob a barra e mantém um único contorno externo contínuo. A sessão define `org.gnome.desktop.interface color-scheme='prefer-dark'` somente quando o dconf não tem valor do usuário, preservando escolhas explícitas de tema claro/escuro. Arrastar uma área livre da titlebar do servidor move a janela e usa o encaixe do Aqueous para janelas flutuantes: laterais/base encaixam em metades, cantos em quartos e a borda superior maximiza. Janelas em tela cheia ocultam a barra. Menus e popups mantêm seu comportamento.

O Pearl Settings não cria uma barra de título própria nesta sessão, evitando decoração duplicada; no modo de tema GTK, a janela usa um fundo opaco do tema. A opção de sincronização de bordas do Pearl sincroniza cores, não geometria: a build `aqueous-cpu` de compatibilidade desativa os efeitos Vulkan e mantém cantos quadrados. Cantos arredondados no compositor exigem Aqueous com efeitos Vulkan habilitados.

- Aqueous/Pearl é a única sessão de usuário selecionável e suportada da DINX.
- A ISO live abre `dinx` diretamente pelo autologin dinit; o rootfs instalado mantém login manual.
- O Pearl Greeter é a interface de login instalada do greetd, não uma segunda sessão de usuário; sua configuração pertencente ao root força `Aqueous + Pearl (DINX)` e não há fallback silencioso.
- `dinx-aqueous-pearl` inicia o Aqueous diretamente. O filho init espera o Wayland e o D-Bus da sessão; então o supervisor inicia Shikane, PolicyKit, o idle obrigatório e Pearl. O daemon opcional da BC-250 só inicia quando o pacote assinado é instalado separadamente; instale-o somente após detectar o PCI `1002:13fe`. A ISO genérica omite todos os pacotes específicos da BC-250.
- Falha de helper obrigatório ou do Pearl registra estado explícito e encerra o compositor, em vez de deixar um desktop vazio.
- A sessão usa elogind/libseat e execução direta sobre dinit; não exige systemd, systemctl, uwsm ou unidades de usuário.

- `swayidle` bloqueia após 600 segundos e em `before-sleep`; `Super+L`, a ação do launcher e a DINXPanel usam o mesmo caminho `swaylock`. `brightnessctl` fornece passos fixos de 5% para brilho.

## Integração de display e Seafoam

`dinx-wdisplays` inicia o editor interativo de displays Wayland. Ao fechar, serializa o resultado com `flock`, substitui atomicamente o perfil DINX `DINX wdisplays` em `~/.config/shikane/config.toml` e recarrega o Shikane. Falha no reload é reportada como falha. O Shikane inicia dentro de Aqueous/Pearl e reaplica perfis correspondentes quando as saídas mudam.

O Seafoam Settings expõe entradas fixas para wdisplays, salvador de perfil, Shikane, DinitUI, DINXPanel, Qt6ct e Dome. O Dome fornece monitoramento dinit-safe de recursos/processos. Os pacotes Zig nativos da DINX usam Zig 0.17.0. O ZLS continua sendo backend do editor; seu runtime compacto contém a biblioteca padrão Zig 0.16.0 correspondente e um shim de metadados, não o compilador completo. Instalar o pacote opcional `zig` do Artix habilita comandos de compilação pelo mesmo shim.

## Limite do gaming

DINX Gaming é um launcher manual oculto, não uma sessão de usuário selecionável. A ISO inclui o launcher/entrada desktop, mas os binários Gamescope/Steam e bibliotecas de 32 bits pertencem ao grupo Artix opcional `gaming`, não ao perfil base. RADV/Vulkan de 64 bits continuam instalados. O launcher verifica Gamescope e Steam antes de alterar o perfil Dinit; fixtures confirmam que a transição não ocorre quando faltam pacotes. Saída DRM real e gaming autenticado continuam fora da qualificação.

## Matriz de testes de compatibilidade

| Área | Critério de aceitação |
| --- | --- |
| Descoberta do terminal | `$TERMINAL` inicia o Deetty com shell e diretório solicitado |
| Metadados desktop | entradas `.desktop` são válidas e descobertas |
| Inicialização de apps opcionais | Gapless herda a sessão Wayland ativa; Portmaster inicia pelo launcher compatível com Dinit somente quando aberto; o Gerenciador Bluetooth explica a ausência do daemon/controlador (VirtualBox precisa de passthrough USB Bluetooth) |
| Argumentos de inicialização | comportamento de arquivo, linha e diretório é determinístico |
| Contrato de tema | paleta DINX estática, defaults escuros GTK 3/4 no sistema, seleção GTK escura na sessão, paleta DINX do Qt6ct e controles de fallback na barra de título GTK 3/4 estão configurados |
| Greeter/instalador/boot | Pearl Greeter, Calamares e GRUB expõem estados DINX de superfície, texto, seleção e foco |
| Firefox padrão | Firefox trata HTML/XHTML/HTTP/HTTPS por default |
| Armazenamento e arquivos | persistência dinit do Pori, diretórios no Phyto, arquivos compactados no File Roller e edição no GParted estão presentes |
| Layout do desktop | Aqueous/Pearl é a única sessão de usuário; saídas novas começam com dois workspaces e stacking flutuante. Os atalhos padrão de mosaico, rolagem, monocle e grade (`Super+T/F/M/G`) ficam desativados; arrastar até as bordas esquerda/direita/inferior encaixa em metades, os cantos em quartos, e o centro da borda superior maximiza (limite de 24 px, sem espaço). Configurações existentes são preservadas |
| Gráficos em VM | Um relato manual anterior chegou ao Pearl no VirtualBox 7.2.22/Windows 11 (VMSVGA, 3D habilitado, EFI, 4 vCPUs, 8 GiB); o log não comprovou origem de boot nem checksum da ISO, portanto não qualifica o release. O código atual direciona `vmwgfx`/`vboxvideo` e sistemas sem render nodes acessíveis ao Aqueous completo com `WLR_RENDERER=vulkan` e `GSK_RENDERER` sem override; QEMU `virtio_gpu` mantém GLES2 com efeitos reduzidos. A renderização de superfícies de clientes na ISO reconstruída ainda aguarda verificação direta no VirtualBox. |
| Gráficos em VM | O gate P0 completo testa o desktop live no VGA padrão e Virtio-VGA do QEMU. O caminho `vmware-svga` do QEMU 11.1.2/KVM trava no udev inicial com `vmwgfx` carregado e não é um proxy confiável do VirtualBox; o boot direto VMSVGA no VBox continua sem qualificação. |
| Decorações das janelas | Testes da fonte fixada do Aqueous verificam a política de decoração cliente/servidor, decorações do sistema no Firefox, áreas clicáveis dos controles, encaixe flutuante em metade/quarto e máscaras arredondadas que abrangem titlebar do servidor e superfície do cliente |
| Segurança da sessão | lock por idle, lock antes de suspend, lock explícito e brilho usam caminhos fixos |
| Persistência de display | mudanças do wdisplays atualizam atomicamente e recarregam o perfil nomeado do Shikane |
| ZLS | Dintor encontra a biblioteca Zig correspondente sem compilador completo |
| Gerenciamento de pacotes | pacman, Shelly, paru e Topgrade usam a configuração Artix e são executados pelo usuário |
| Firewall/monitoramento | Portmaster e Qps são descobertos; o serviço Portmaster permanece parado até abrir seu launcher |
| DinitUI | descoberta e controle usam argv validado do dinitctl com fallback pkexec restrito |
| Gaming | launcher oculto mantido, grupo de pacotes opcional fora da base, falta de Gamescope/Steam falha antes da mudança de perfil; gaming real permanece sem qualificação |
| Isolamento de falhas | helpers ou endpoints D-Bus opcionais indisponíveis produzem falha visível sem bloquear o startup |
| Acesso por teclado | ações principais funcionam sem ponteiro |

## Gates de release

`scripts/check_deetty_integration.sh`, `scripts/dintor_p3_qualification.sh`, `scripts/check_dinitui.sh`, `scripts/check_dinx_session.sh`, `scripts/check_dinx_display_persistence.sh`, `scripts/check_dinx_theme.sh`, `scripts/check_pori_phyto.sh`, `scripts/check_aqueous_pearl.sh` e `scripts/check-iso-content.sh` verificam os contratos de pacote, sessão e ISO. O workflow P0 continua sendo o gate de criação dos pacotes, montagem da ISO, boot QEMU, instalação Calamares, TTY de recuperação, atestação e publicação.
