# Contrato de compatibilidade DINX

[Português (Brasil)](compatibility.md) · [English](../compatibility.md)

Os aplicativos da DINX integram-se por metadados XDG, protocolos Wayland, D-Bus, PipeWire e limites dinit padrão. A sessão base não exige IPC privado de shell, systemd, uwsm ou serviço de shell para funcionar.

## Nível 1 — integração direta

Obrigatório para a ISO base:

- O Noctty é descoberto por `$TERMINAL`, aceita os argumentos documentados de inicialização e respeita um diretório de trabalho quando fornecido.
- O Nocted possui uma entrada `.desktop` válida, abre arquivos e diretórios por launchers XDG padrão e aceita argumentos de arquivo/linha suportados.
- O Nocted inicia o LSP documentado para cada tipo de arquivo. Zig usa o ZLS 0.16.0 incluído; C/C++ usa `clangd`.
- O Firefox é o manipulador padrão de HTML, XHTML, HTTP e HTTPS.
- O Phyto é o manipulador padrão de diretórios; o File Roller cuida de abrir/criar/extrair arquivos compactados; o GParted cuida do particionamento independente.
- O Pori descobre dispositivos de bloco pelo UDisks2 e persiste montagens do usuário por serviços dinit em `/etc/dinit.d`.
- Navegação por teclado e locais XDG de configuração/dados continuam utilizáveis sem integração privada de shell.

## Nível 2 — integração visual e de sessão

O contrato do tema estático DINX é a fonte de verdade:

- paleta: `/usr/share/dinx/theme/DINX.json`;
- escolha de cor do usuário: `DINX_COLOR_SCHEME=light|dark`, com `NOCTED_THEME=prefer-light` aceito pelo Nocted;
- cores Qt6ct: `~/.config/qt6ct/colors/DINX.conf`;
- tema GTK: tema instalado `DINX` com Noto Sans 10;
- texto de largura fixa: Noto Sans Mono 10 quando exigido pelo aplicativo;
- bridges gráficas: estados DINX de superfície, controle, hover, primário e erro, com ícones Adwaita quando disponíveis.

`DINX_COLOR_SCHEME=light` ou `NOCTED_THEME=prefer-light` seleciona o esquema claro empacotado do editor. Os demais valores usam o esquema escuro DINX. O Nocted não interpreta arquivos privados de shell e continua funcional sem nenhuma variável.

Pearl Greeter, Calamares e GRUB usam bridges estáticas DINX porque executam antes ou fora da sessão do usuário. O Pearl Greeter lê `/etc/pearl/greeter.json`, roda pela conta dedicada `pearl-greeter` e força a única entrada Aqueous/Pearl com X11 e UWSM desativados. Swayimg, btop, Foot, Ghostty, GTK e Qt usam seus caminhos DINX versionados. `scripts/check_dinx_theme.sh` valida paleta, tipografia, estados e bridges; `scripts/check-iso-content.sh` repete os checks dentro do SquashFS.

## Contrato do gerenciador de serviços DinitUI

DinitUI é o frontend DINX do dinit, não uma camada de compatibilidade com systemd. Ele descobre serviços carregados e arquivos de descrição, exibe status e logs em buffer e expõe ações de ciclo de vida, dependências, ambiente, sinais e daemon por argv validado do `dinitctl`. Nunca interpola texto do usuário em comandos de shell.

O escopo de usuário usa `dinitctl --user`. O escopo de sistema usa `dinitctl --system` e só tenta `pkexec` após uma falha explícita de autorização. Perfis `normal`, `lite`, `gaming` e definidos pelo usuário persistem em `~/.config/dinx/dinitui/profiles.conf`; `lite` desabilita somente Bluetooth opcional, enquanto `gaming` habilita Bluetooth para controles e preserva serviços de firewall/política de processos. O launcher gaming standalone entra e restaura o perfil explicitamente.

## Contrato da sessão Aqueous/Pearl

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
| Descoberta do terminal | `$TERMINAL` inicia o Noctty com shell e diretório solicitado |
| Metadados desktop | entradas `.desktop` são válidas e descobertas |
| Argumentos de inicialização | comportamento de arquivo, linha e diretório é determinístico |
| Contrato de tema | paleta DINX estática, defaults escuros GTK 3/4 no sistema, seleção GTK escura na sessão e paleta DINX do Qt6ct estão configurados |
| Greeter/instalador/boot | Pearl Greeter, Calamares e GRUB expõem estados DINX de superfície, texto, seleção e foco |
| Firefox padrão | Firefox trata HTML/XHTML/HTTP/HTTPS por default |
| Armazenamento e arquivos | persistência dinit do Pori, diretórios no Phyto, arquivos compactados no File Roller e edição no GParted estão presentes |
| Layout do desktop | Aqueous/Pearl é a única sessão de usuário; stacking livre é o padrão, `Alt+Shift+F` o seleciona e `Super+Shift+Space` alterna o modo flutuante por janela |
| Segurança da sessão | lock por idle, lock antes de suspend, lock explícito e brilho usam caminhos fixos |
| Persistência de display | mudanças do wdisplays atualizam atomicamente e recarregam o perfil nomeado do Shikane |
| ZLS | Nocted encontra a biblioteca Zig correspondente sem compilador completo |
| Gerenciamento de pacotes | pacman, Shelly, paru e Topgrade usam a configuração Artix e são executados pelo usuário |
| Firewall/monitoramento | Gufw, Qps e OpenSnitch são descobertos; serviços ficam desabilitados até configuração |
| DinitUI | descoberta e controle usam argv validado do dinitctl com fallback pkexec restrito |
| Gaming | launcher oculto mantido, grupo de pacotes opcional fora da base, falta de Gamescope/Steam falha antes da mudança de perfil; gaming real permanece sem qualificação |
| Isolamento de falhas | helpers ou endpoints D-Bus opcionais indisponíveis produzem falha visível sem bloquear o startup |
| Acesso por teclado | ações principais funcionam sem ponteiro |

## Gates de release

`scripts/check_noctty_integration.sh`, `scripts/nocted_p3_qualification.sh`, `scripts/check_dinitui.sh`, `scripts/check_dinx_session.sh`, `scripts/check_dinx_display_persistence.sh`, `scripts/check_dinx_theme.sh`, `scripts/check_pori_phyto.sh` e `scripts/check-iso-content.sh` verificam os contratos de pacote, sessão e ISO. O workflow P0 continua sendo o gate de criação dos pacotes, montagem da ISO, boot QEMU, instalação Calamares, TTY de recuperação, atestação e publicação.
