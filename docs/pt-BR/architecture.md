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
  Deetty · Dintor · DinitUI · DINXPanel · Seafoam Settings · Mission Center · ZLS

Contratos compartilhados
  Tema DINX estático · XDG · .desktop · $TERMINAL · D-Bus padrão

Sessão do desktop
  Wayland · River · KWM · Morghulis · PCManFM

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
- PCManFM como gerenciador de arquivos nativo, handler padrão de diretórios e desktop;
- File Roller para abrir/criar/extrair arquivos compactados e GParted para particionamento independente;
- `wdisplays` e `shikane` para configuração Wayland e reaplicação de layouts;
- manifestos que identificam cada entrada específica da DINX;
- snapshot reproduzível em ambiente de build limpo.

Pacotes upstream são preferidos. Pacotes e patches específicos da DINX permanecem pequenos, explícitos e identificáveis.

## Limites dos aplicativos

### Deetty e Dintor

Deetty é responsável pela janela, preferências, atalhos, abas/painéis e sessões de terminal. Seu núcleo Zig possui parsing VT, células Unicode, cursor/modos, scrollback limitado, seleção, paste e ciclo de vida PTY. O pacote `ghostty-vt-runtime` fornece somente o adaptador VT público do Ghostty; o aplicativo de terminal Ghostty não faz parte do payload da DINX.

Dintor é um editor leve, não um IDE completo. Seus limites são estado/UI Zig, motor de edição, parser de sintaxe, cliente LSP, status/diff Git limitado e abertura XDG. O ZLS é um pacote opcional para projetos Zig; C/C++ pode usar `clangd` quando o pacote opcional `clang` estiver instalado. O editor escolhe o esquema por `DINX_COLOR_SCHEME` ou `DINTOR_THEME` e usa o esquema escuro DINX por default. Ele continua funcional sem serviço de shell ou IPC privado.

### DinitUI

DinitUI é o frontend DINX do dinit. Descobre serviços carregados e arquivos de descrição, exibe status, logs em buffer, dependências, ambiente, sinais e ações do daemon por argv validado do `dinitctl`. Nunca interpola texto do usuário em shell.

O escopo de usuário usa `dinitctl --user`. O escopo de sistema usa `dinitctl --system` e recorre a `pkexec` somente após falha explícita de autorização. Os perfis `normal`, `lite`, `gaming` e customizados persistem em `~/.config/dinx/dinitui/profiles.conf`; `lite` desabilita somente o Bluetooth opcional e `gaming` habilita Bluetooth para controles. O Firewalld é um serviço de sistema separado, habilitado no boot e fora desses perfis.

### DINXPanel

A DINXPanel é o centro de controle. Ela agrupa entradas fixas para rede, Bluetooth, display, áudio, firewall, serviços dinit, upgrades e firmware, além do catálogo de kernels Artix (`linux`, `linux-lts`, `linux-zen`, `linux-hardened`). O botão Firewall abre a interface `firewall-config`; `firewalld-dinit` habilita o daemon no boot. O relatório somente leitura de upgrades usa `checkupdates` do `pacman-contrib` para os repositórios oficiais, `paru -Qu` para o AUR e metadados opcionais de fwupd; o botão `Package manager` abre o Octopi, cuja elevação ocorre por `pkexec` e polkit porque a DINX não envia sudo. Kernels nunca são removidos, e mudanças informam a necessidade de reinicialização.

CUPS é uma opção pós-instalação: a DINXPanel baixa `cups-dinit` e o usuário habilita o serviço pelo DinitUI quando necessário.

### Mission Center, Seafoam Settings e ZLS

`Mission Center` é o monitor base GTK4 de recursos e processos, incluído na ISO e no repositório DINX assinado. Sua receita não introduz dependência de systemd.

`Seafoam Settings` é um launcher base nativo em Zig/GTK4 para as superfícies DINX de display/sessão: `dinx-wdisplays`, `dinx-save-shikane-profile`, Shikane, DinitUI, DINXPanel, Qt6ct e Mission Center. Usa vetores de argumentos fixos e abre diretamente no Dintor os caminhos de configuração River/KWM/Morghulis e Shikane. Deetty é o único emulador de terminal da ISO; Nano continua como editor de recuperação.

`River + KWM + Morghulis (DINX)`, em `/usr/share/wayland-sessions/dinx-river-kwm-morghulis.desktop`, é a sessão padrão do usuário: `DesktopNames=river;kwm;morghulis` e `Exec=dbus-run-session /usr/local/libexec/dinx-river-session`. O tuigreet também oferece a sessão secundária `River + KWM + Redbean (DINX)` por `/usr/local/libexec/dinx-redbean-session`. O roster do perfil instala o `river` do repositório Artix e os pacotes DINX `kwm`, que implementa o protocolo obrigatório `river-window-management-v1` e é compilado com `-Dbar=false`, de modo que o KWM não traz barra própria, `morghulis`, o shell de desktop DINX cuja NavBar é a superfície de status e que também fornece runner, menu rápido, notificações, OSD e menu de energia, `kwim`, o helper DINX de gerenciamento de entrada do river, que configura dispositivos de entrada independentemente do gerenciador de janelas, `dinx-dock`, a barra de lançadores layer-shell GTK4 de primeira parte que respeita a posição salva do dock, `dinx-first-run`, o assistente de aparência de primeira execução, e `greetd-tuigreet`. O `/usr/local/libexec/dinx-river-session` é o wrapper único da live e do greeter: normaliza o locale para `C.UTF-8` quando o charmap não é UTF-8, exporta as variáveis de desktop e dos toolkits Wayland além dos defaults escuros de recuperação da DINX, lê o perfil de gráficos de `/usr/local/libexec/dinx-graphics-profile`, valida o `XDG_RUNTIME_DIR` criando-o em modo 0700 e rejeitando um diretório de outro usuário, e toma um `flock` não bloqueante em `$XDG_RUNTIME_DIR/dinx-river-session.lock` para que um segundo compositor em corrida saia com código 0 em vez de disputar o seat. O backend libseat é escolhido em tempo de execução: `seatd` quando `/run/seatd.sock` existe e o usuário está no grupo `seat`, e `logind`/elogind caso contrário, que sob dinit nunca marca a sessão como ativa.

### River, KWM, Morghulis e o limite dinit

River/KWM/Morghulis é a única sessão de usuário base. Na imagem live, o serviço Dinit reiniciável `dinx-live-session` inicia a sessão diretamente: `runuser` entra na conta descartável `dinx`, `dbus-run-session` fornece o barramento, `/run/dinx-session` fornece runtime e o seatd controla o seat. `dinx-river-session` prepara diretórios XDG e política gráfica; `dinx-river-init` inicia KWM, Morghulis, PCManFM, Shikane, PolicyKit e idle. O daemon BC-250 opcional inicia somente quando seu pacote assinado separado está instalado.

Morghulis salva a escolha clara/escura em `~/.config/morghulis/preferences.json`; o sincronizador reaplica GTK/Qt no login. PCManFM é o desktop e o handler padrão `inode/directory`.

A sessão usa execução direta sobre dinit e não exige systemd, systemctl, uwsm ou unidades de usuário. O login instalado/manual usa `tuigreet` pelo greetd e pela conta dedicada `greeter`.

`dinx-doctor` é uma superfície somente leitura para sessão, dinit, armazenamento, display e pacotes. Não inicia serviços, monta dispositivos, altera Shikane, executa transações ou acessa a rede.

## Tema e contratos compartilhados

Os contratos compartilhados são versionados independentemente dos detalhes internos:

- tema e tokens de design;
- locais XDG de configuração;
- metadados `.desktop` e comportamento de linha de comando;
- `$TERMINAL` e diretório de trabalho;
- adaptadores D-Bus padrão para notificações;
- convenções de logs e diagnósticos.

O contrato do Tema DINX v1 é uma paleta estática em `/usr/share/dinx/theme/DINX.json` com papéis semânticos de superfície/texto/primário/erro, variantes clara/escura, paleta ANSI completa, Noto Sans 10 para bridges gráficas, geometria quadrada, Papirus como tema padrão de ícones e bridge de ícones Adwaita para controles DINX. Morghulis salva a variante de aparência em `~/.config/morghulis/preferences.json`; o sincronizador aplica-a a dconf, GTK 3/4 e Qt6ct preservando configurações não relacionadas. Morghulis, PCManFM, Calamares, Swayimg e GRUB usam bridges estáticas com os mesmos tokens. `dinx-noto-latin` fornece Noto Sans e Noto Sans Mono de um subset latino/latim estendido; `scripts/check_morghulis_theme.sh` valida o contrato do tema.

## Sessão gaming

DINX Gaming é um launcher manual oculto, não uma sessão selecionável. A ISO base mantém apenas o launcher e a entrada desktop; Gamescope, Steam, regras de dispositivos Steam, GameMode, MangoHud e bibliotecas de 32 bits ficam no grupo opcional `gaming` (`iso:false`) e vêm do Artix após a instalação. A base mantém RADV e ferramentas Vulkan de 64 bits. O builder P0 instala Gamescope somente para a qualificação headless; não habilita `[lib32]` nem inclui esses pacotes na ISO. O launcher verifica Gamescope e Steam antes de alterar o perfil Dinit; o fixture confirma falha fechada se faltar qualquer um. Saída DRM real e gaming autenticado continuam sem qualificação.

## Armazenamento, NTFS e display

Pori usa UDisks2 e grava serviços dinit `process` em `/etc/dinit.d` que aguardam dispositivos, repetem montagens, mantêm somente montagens próprias e desmontam no encerramento. Nenhuma unidade de montagem systemd é gerada.

O PCManFM é o único gerenciador de arquivos base e renderiza os ícones de `~/Desktop` via `pcmanfm --desktop`. File Roller e GParted cobrem arquivos compactados e particionamento independente. O módulo `ntfs3` fornece leitura/escrita NTFS na live e no sistema instalado; `ntfs-3g` é opcional pós-instalação. Fast Startup e hibernação do Windows devem ser desativados antes de montar um volume compartilhado.

`dinx-wdisplays` serializa exports com `flock`, substitui atomicamente o perfil `DINX wdisplays` em `~/.config/shikane/config.toml` e falha visivelmente se o reload do Shikane falhar. Shikane inicia dentro da sessão River/KWM e reaplica perfis quando as saídas mudam.

## Manifesto e CI

`feature-groups.json` inventaria rootfs, init dinit, boot e livefs. `scripts/check_dinx_feature_groups.sh` compara inventários com as fontes YAML, rejeita ownership duplicado e impede pacotes opcionais no perfil base. `contracts.yml` executa checks não privilegiados; o workflow P0 permanece o gate privilegiado de build, QEMU, instalação, recuperação, atestação e release.

`scripts/check_dinx_budget.sh` mantém os tetos de pacotes rootfs, entradas dinit, binários e ISO. `scripts/check_river_session.sh`, `scripts/check_morghulis_theme.sh`, `scripts/check_mission_center.sh`, `scripts/check_dinx_display_persistence.sh` e `scripts/check-iso-content.sh` verificam a integração observável antes da montagem final.
