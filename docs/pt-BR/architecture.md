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
  Deetty · Dintor · DinitUI · DINXPanel · Seafoam Settings · Dome · ZLS

Contratos compartilhados
  Tema DINX estático · XDG · .desktop · $TERMINAL · D-Bus padrão

Sessão do desktop
  Wayland · Aqueous · Pearl · host Pearl Greeter

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
- Phyto como gerenciador de arquivos e handler padrão de diretórios;
- File Roller para abrir/criar/extrair arquivos compactados e GParted para particionamento independente;
- `wdisplays` e `shikane` para configuração Wayland e reaplicação de layouts;
- manifestos que identificam cada entrada específica da DINX;
- snapshot reproduzível em ambiente de build limpo.

Pacotes upstream são preferidos. Pacotes e patches específicos da DINX permanecem pequenos, explícitos e identificáveis.

## Limites dos aplicativos

### Deetty e Dintor

Deetty é responsável pela janela, preferências, atalhos, abas/painéis e sessões de terminal. Seu núcleo Zig possui parsing VT, células Unicode, cursor/modos, scrollback limitado, seleção, paste e ciclo de vida PTY. O pacote `ghostty-vt-runtime` fornece somente o adaptador VT público do Ghostty; o aplicativo de terminal Ghostty não faz parte do payload da DINX.

Dintor é um editor leve, não um IDE completo. Seus limites são estado/UI Zig, motor de edição, parser de sintaxe, cliente LSP, status/diff Git limitado e abertura XDG. Zig usa o ZLS incluído; C/C++ usa `clangd`. O editor escolhe o esquema por `DINX_COLOR_SCHEME` ou `DINTOR_THEME` e usa o esquema escuro DINX por default. Ele continua funcional sem serviço de shell ou IPC privado.

### DinitUI

DinitUI é o frontend DINX do dinit. Descobre serviços carregados e arquivos de descrição, exibe status, logs em buffer, dependências, ambiente, sinais e ações do daemon por argv validado do `dinitctl`. Nunca interpola texto do usuário em shell.

O escopo de usuário usa `dinitctl --user`. O escopo de sistema usa `dinitctl --system` e recorre a `pkexec` somente após falha explícita de autorização. Os perfis `normal`, `lite`, `gaming` e customizados persistem em `~/.config/dinx/dinitui/profiles.conf`; `lite` desabilita somente Bluetooth opcional e `gaming` habilita Bluetooth para controles, preservando política de firewall/processos.

### DINXPanel

A DINXPanel é o centro de controle. Ela agrupa entradas fixas para rede, Bluetooth, display, áudio, firewall, serviços dinit, upgrades e firmware, além do catálogo de kernels Artix (`linux`, `linux-lts`, `linux-zen`, `linux-hardened`). Checks de upgrade são somente leitura; ações explícitas usam argv fixo e confirmação do usuário. Kernels nunca são removidos, e mudanças informam a necessidade de reinicialização.

CUPS é uma opção pós-instalação: a DINXPanel baixa `cups-dinit` e o usuário habilita o serviço pelo DinitUI quando necessário.

### Dome, Seafoam Settings e ZLS

`Dome` é um monitor nativo Zig/GTK4 incluído na ISO e no repositório DINX assinado. Suas telas de recursos/processos são dinit-safe; o pacote não instala integração com systemd, systemctl ou uwsm.

`Seafoam Settings` é um launcher base nativo em Zig/GTK4 para as superfícies de display/sessão DINX: `dinx-wdisplays`, `dinx-save-shikane-profile`, Shikane, DinitUI, DINXPanel, Qt6ct e Dome. Usa vetores de argumentos fixos, abre diretamente no Dintor os arquivos documentados de configuração do Aqueous/Pearl e do Shikane e executa o exportador de perfil de display no Deetty. Deetty é o único emulador de terminal da ISO; Nano continua como editor de recuperação.

`zls` é o pacote oficial Zig Language Server 0.16.0 com fonte fixada. Carrega a árvore `lib/std` correspondente e o shim de metadados `/usr/lib/zls/zig-env`; completion e navegação do Dintor funcionam sem compilador Zig completo. Os pacotes Zig nativos da DINX são compilados com Zig 0.17.0; a árvore 0.16.0 aqui é somente o runtime de compatibilidade do ZLS/LSP. Um pacote Artix `zig` opcional habilita comandos de compilação pelo mesmo shim.

### Aqueous, Pearl e o limite dinit

Aqueous 1.0.5 e Pearl 0.3.0 são a única sessão de usuário selecionável e a sessão inicial da live. `dinx-aqueous-pearl` seleciona elogind/libseat e inicia Aqueous diretamente. O pacote inclui o compositor completo com efeitos Vulkan e `aqueous-cpu`, compilado sem esses efeitos. O wrapper usa Pixman/Cairo quando não há render node DRM ou quando o dispositivo é uma GPU Virtio (`0x1af4`), evitando a falha de apresentação QEMU/llvmpipe. Esse modo é mais lento e não oferece efeitos Vulkan do compositor, como blur e cantos arredondados; os demais sistemas com render node mantêm o compositor completo e a seleção normal de driver.

Antes de iniciar o compositor, `dinx-aqueous-pearl` executa `xdg-user-dirs-update` como o usuário da sessão. Contas novas da live e do sistema instalado recebem os diretórios XDG padrão, incluindo `~/Desktop`, antes do Pearl iniciar.

Aqueous chama `dinx-aqueous-init`, que espera Wayland e D-Bus da sessão e inicia sob supervisão Shikane, PolicyKit, o idle obrigatório e Pearl. Se os pacotes BC-250 forem instalados separadamente do repositório assinado em uma máquina com PCI `1002:13fe`, o supervisor inicia o daemon opcional do Control Center. A ISO genérica não inclui esses pacotes. `dinx-session-supervisor` registra `starting`, `ready`, `failed` e `exited`; encerra o compositor quando um componente obrigatório falha e encerra o processo pai monitorado quando o supervisor para.

A sessão usa execução direta sobre dinit e não exige systemd, systemctl, uwsm ou unidades de usuário. O login instalado/manual usa o Pearl Greeter: o greetd inicia o host dedicado pela conta `pearl-greeter`, e `/etc/pearl/greeter.json` força a mesma entrada Aqueous/Pearl com X11 e UWSM desativados. O Pearl Greeter não é uma segunda sessão de usuário nem fallback silencioso.

`dinx-doctor` é uma superfície somente leitura para sessão, dinit, armazenamento, display e pacotes. Não inicia serviços, monta dispositivos, altera Shikane, executa transações ou acessa a rede.

## Tema e contratos compartilhados

Os contratos compartilhados são versionados independentemente dos detalhes internos:

- tema e tokens de design;
- locais XDG de configuração;
- metadados `.desktop` e comportamento de linha de comando;
- `$TERMINAL` e diretório de trabalho;
- adaptadores D-Bus padrão para notificações;
- convenções de logs e diagnósticos.

O tema DINX v1 é estático em `/usr/share/dinx/theme/DINX.json`, com papéis de superfície/texto/primário/erro, variantes claro/escuro, paleta ANSI completa, Noto Sans 10, geometria quadrada e ícones Adwaita. GTK usa o tema DINX; Qt usa `~/.config/qt6ct/colors/DINX.conf`; o Pearl Greeter usa `/etc/pearl/greeter.json` com a bridge GTK DINX. Pearl, Pearl Greeter, Calamares, Swayimg e GRUB usam bridges estáticas com os mesmos tokens. Noto Sans Mono 10 em campos fixos, logs monoespaçados e `u_vga16 16` do GRUB são exceções intencionais.

## Sessão gaming

DINX Gaming é um launcher manual oculto, não uma sessão selecionável. A ISO base mantém apenas o launcher e a entrada desktop; Gamescope, Steam, regras de dispositivos Steam, GameMode, MangoHud e bibliotecas de 32 bits ficam no grupo opcional `gaming` (`iso:false`) e vêm do Artix após a instalação. A base mantém RADV e ferramentas Vulkan de 64 bits. O builder P0 instala Gamescope somente para a qualificação headless; não habilita `[lib32]` nem inclui esses pacotes na ISO. O launcher verifica Gamescope e Steam antes de alterar o perfil Dinit; o fixture confirma falha fechada se faltar qualquer um. Saída DRM real e gaming autenticado continuam sem qualificação.

## Armazenamento, NTFS e display

Pori usa UDisks2 e grava serviços dinit `process` em `/etc/dinit.d` que aguardam dispositivos, repetem montagens, mantêm somente montagens próprias e desmontam no encerramento. Nenhuma unidade de montagem systemd é gerada.

O Phyto é o único gerenciador de arquivos base. File Roller e GParted cobrem arquivos compactados e particionamento independente. O módulo `ntfs3` fornece leitura/escrita NTFS na live e no sistema instalado; `ntfs-3g` é opcional pós-instalação. Fast Startup e hibernação do Windows devem ser desativados antes de montar um volume compartilhado.

`dinx-wdisplays` serializa exports com `flock`, substitui atomicamente o perfil `DINX wdisplays` em `~/.config/shikane/config.toml` e falha visivelmente se o reload do Shikane falhar. Shikane inicia dentro de Aqueous/Pearl e reaplica perfis quando as saídas mudam.

## Manifesto e CI

`feature-groups.json` inventaria rootfs, init dinit, boot e livefs. `scripts/check_dinx_feature_groups.sh` compara inventários com as fontes YAML, rejeita ownership duplicado e impede pacotes opcionais no perfil base. `contracts.yml` executa checks não privilegiados; o workflow P0 permanece o gate privilegiado de build, QEMU, instalação, recuperação, atestação e release.

`scripts/check_dinx_budget.sh` mantém os tetos de pacotes rootfs, entradas dinit, binários e ISO. `scripts/check_dinx_session.sh`, `check_dinx_theme.sh`, `check_dinx_display_persistence.sh`, `check_pori_phyto.sh` e `check-iso-content.sh` verificam a integração observável antes da montagem final.
