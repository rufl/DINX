# Changelog

Este arquivo registra as mudanças importantes da DINX em linguagem direta. Ele não afirma que o roadmap terminou; a evidência de qualificação e os metadados do release são a fonte de verdade.

## Não lançado

- Adicionado um alias de download direto e um checksum SHA-512 persistentes para a ISO alpha mais recente. O workflow de release por tag atualiza o alias, e as duas páginas iniciais do GitHub apontam para ele.
- Corrigida a falha do build P0 causada pela ausência do pacote Gapless fixado no repositório local assinado. O builder Artix agora instala Vala e as dependências de build do GStreamer, empacota o Gapless antes de montar a rootfs e verifica essa configuração no contrato de proveniência.
- Corrigidos os contratos P0 para verificar os smokes Seafoam/ZLS e a qualificação de Gamescope, exclusiva do builder Artix, em vez de exigir essas etapas no workflow executado no host.
- Fixados os arquivos de configuração e desktop AUR do Shelly na revisão imutável `f89d773125357baaa1d2fae715286ce9e00e2cb4`; a branch móvel `shelly-bin` havia alterado `shellybuild.conf` e feito a verificação de checksum do build da ISO falhar.
- O build do pacote Deetty limpa a árvore de fontes anterior antes de aplicar patches, evitando que uma tentativa com falha faça a próxima reaplicar patches de criação sobre fontes já modificadas.
- Atualizados os smokes upstream de tarefa e LSP do `clangd` do Dintor para executar o binário renomeado `dintor`; o contrato do pacote rejeita caminhos antigos do executável `nocted`.
- Adicionado `scripts/build-iso-docker.sh`: usa o mesmo builder Artix privilegiado e fixado por digest do P0 CI, gera o archive ignorado de Deetty/Dintor a partir de um checkout local no commit público fixado do NOCTTY quando necessário e produz metadados locais vinculados à fonte e bundle de pacotes com chave efêmera.

- Corrigidos os filtros de push P0 para os pontos de entrada Docker/container e restaurada a propriedade do host nos arquivos de pacotes montados pelo builder Artix. Os workflows P0 e de contratos fazem checkout da fonte pública NOCTTY fixada com o `GITHUB_TOKEN` integrado ao workflow e geram seu archive ignorado; agora o workflow de contratos também executa esses checks nos PRs de forks. Nenhum secret Actions adicional é necessário.

- Saídas novas do Aqueous agora começam com dois workspaces, em vez dos nove workspaces iniciais do upstream.

- Adicionado um perfil gráfico para render nodes com capacidade de aceleração no QEMU `virtio_gpu`/virgl e VirtualBox VMSVGA (`vmwgfx`), com fallback Pixman/Cairo para dispositivos virtuais ausentes, inacessíveis ou somente 2D. O usuário live, o Pearl Greeter e novas contas instaladas recebem acesso ao grupo `render`. A aceleração 3D do host continua sendo uma configuração explícita do hypervisor; nenhum pacote ou serviço systemd foi adicionado.

- A sessão Aqueous/Pearl exporta `GTK_CSD=0` e solicita decorações do servidor para que janelas GTK padrão e clientes Wayland compatíveis usem a barra do compositor. A documentação registra o limite restante para aplicativos com chrome CSD próprio.

- O workflow DINX de contratos e REUSE, sem build privilegiado, agora roda em todo pull request e push para `main`, inclusive alterações somente de documentação ou licenças. O build privilegiado da ISO mantém seus gatilhos próprios por caminhos de build selecionados.

- Corrigido o gate da ISO Beta 0.1 para refletir o limite real por arquivo de release do GitHub: estritamente abaixo de 2 GiB, sem a meta arbitrária de 1,8 bilhão de bytes. A Alpha 10 continua dentro do limite.

- Completada a cobertura REUSE dos helpers DINX sob GPL-3.0-only e excluída das varreduras do projeto a cópia local retida da fonte Aqueous.

- Atualizadas as páginas iniciais do GitHub em inglês e pt-BR para usar o wordmark DINX Linux já incluído nos assets de marca da ISO.

- Deetty passou a ser o único emulador de terminal da ISO live e da instalação nova; os defaults de shell, a ação de terminal do Aqueous e os launchers DINX usam esse aplicativo diretamente. Nano permanece como editor de recuperação. A ISO inclui somente `ghostty-vt-runtime` (biblioteca VT, headers e licença); o Ghostty completo fica restrito ao builder e é removido antes da montagem da ISO.

- Renomeados os aplicativos DINX Noctty/Nocted para Deetty/Dintor, o pacote para `deetty`, os comandos para `deetty`/`dintor`, a variável de tema para `DINTOR_THEME` e os IDs desktop para `org.dinx.Deetty`/`org.dinx.Dintor`. A origem continua sendo o upstream NOCTTY fixado, sem alteração da URL ou da identidade do archive.

- Nomes concisos nos atalhos: Dintor aparece como “Editor” nas entradas desktop padrão e pt-BR; Seafoam Settings, DINXPanel e File Roller usam “Ajustes do Desktop”, “Central de Controle” e “Descompactador” em pt-BR. O override localizado do ID desktop do File Roller e o cache MIME ficam em `/usr/local/share`, fora dos arquivos do pacote, preservando o nome e as associações de arquivos compactados após atualizações.

- Os atalhos do Gufw e Qps agora aparecem como “Firewall” e “Process Manager” em inglês, e como “Firewall” e “Processos” em pt-BR. Os comandos dos executáveis permanecem inalterados.

- O atalho do OpenSnitch agora aparece como “Traffic Monitor” em inglês e “Monitor de Tráfego” em pt-BR. O comando `opensnitch-ui` e os metadados upstream de inicialização automática permanecem inalterados; a categoria System evita entradas duplicadas no menu.

- Padronizados os nomes dos launchers dos aplicativos base em inglês e pt-BR. O File Roller agora aparece como “Archive Manager” / “Descompactador”, sem alterar os handlers de arquivos compactados. O alias do Calamares com nome Artix foi ocultado; o atalho `Install DINX` / `Instalar DINX` é a única entrada do instalador.

- Substituído o Strawberry pelo Gapless (G4Music) na ISO base. A DINX compila a versão upstream v4.6.2 fixada como pacote `gapless` assinado, inclui codecs GStreamer base/good, mantém a reprodução sem intervalos ativada por padrão e define o Gapless como handler padrão dos MIME types de áudio comuns.

- Adicionado Galculator, uma calculadora compacta em GTK 3 do repositório `world` assinado do Artix, à lista de aplicativos da ISO base. Ele usa a pilha GTK existente e não adiciona outro toolkit gráfico.

- Definido o tema escuro DINX como padrão global do GTK 3/4 e exportada a seleção GTK/Qt6ct pelo launcher direto da sessão Aqueous. Pastas home existentes recebem a configuração e a paleta DINX do Qt6ct quando ainda não existem.
- Novos perfis de usuário do Aqueous recebem `stacking` flutuante em todos os workspaces. A configuração WM distribuída desativa os atalhos padrão de mosaico, rolagem, monocle e grade (`Super+T/F/M/G`); `Alt+Shift+F` seleciona stacking e `Super+Shift+Space` alterna o modo flutuante por janela. Ao arrastar uma janela flutuante até a borda esquerda/direita/inferior, ela encaixa em uma metade; nos cantos, em um quarto; no centro da borda superior, maximiza (limite de 24 px, sem espaço). Configurações existentes não são alteradas.
- Todas as janelas de nível superior do Aqueous exibem uma barra DINX desenhada pelo compositor, com título e controles para minimizar, maximizar/restaurar e fechar, inclusive em clientes GTK e Pearl. Títulos longos são truncados com reticências antes dos controles. Arrastar uma área livre da barra move a janela e usa o encaixe flutuante existente; tela cheia oculta a barra. O chrome do cliente nos 36 pixels lógicos superiores pode ficar encoberto.
- Corrigido o texto desatualizado na barra do Aqueous quando clientes Wayland ou XWayland alteram o título. O gate Aqueous/Pearl agora aplica os patches DINX à fonte upstream fixada, testa zonas dos controles e geometria de encaixe flutuante, e verifica que notificações de título invalidam o cache.

- Adicionado o símbolo reduzido D com raio como SVG canônico transparente em `design/brand/dinx-ray-mark.svg`; o GRUB usa sua versão RGBA e o Calamares usa-o como ícone do produto. O wordmark completo permanece no wallpaper do greeter/desktop e nas superfícies de logo/boas-vindas do Calamares; ícones upstream/Adwaita de aplicativos e da área de trabalho permanecem inalterados.
- Substituída a primeira aproximação ASCII por uma conversão por densidade do SVG original do D-ray DINX. O asset em ASCII puro funciona com o Fastfetch e com o formato de logo personalizado do `fetch` opcional de Areofyl.

## v0.1.0-alpha.10 — 2026-10-29

- Publicada a [v0.1.0-alpha.10](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.10) no commit `3fd3cd036cab7e8fb553e6e5c244b02429f1a18e` pela [execução de release 40879223746](https://github.com/rufl/DINX/actions/runs/40879223746). A ISO direta tem 1.862.772.736 bytes e SHA-512 `5f49a65eac1481c01555a8f44b049c9a06e75ec7270ac3cdef97cc5e0b051d4b3c48a200542a36ec1832700accbc5509e3c314726c2f747530095eba4112219a`; snapshot do repositório de pacotes assinado `b0015a0655d7d56a4949731d1a4f33cb2cc8daa55d4ec77df6d1a22161d2f5fd`.

- Gamescope, Steam, GameMode, MangoHud, regras de dispositivos Steam e bibliotecas gaming de 32 bits saíram da ISO base e passaram a pacotes opcionais pós-instalação. A base mantém RADV/Vulkan de 64 bits; o P0 não habilita `[lib32]` durante a montagem. Os checks da ISO rejeitam binários/metadata gaming nas imagens rootfs e live. A ISO direta publicada da Alpha 10 tem 1.862.772.736 bytes.

- Removidos o governor BC-250, o serviço dinit e o Control Center dos rootfs live e instalado genéricos. Os pacotes fixados continuam no repositório DINX assinado; o comando documentado de instalação exige o PCI `1002:13fe`.

- Adicionada uma página bilíngue de opções do Calamares antes do particionamento. Ela explica apagar o disco inteiro, instalação ao lado quando disponível, substituição de partição e layout manual; opções destrutivas continuam sem seleção prévia e swap permanece opcional, sem swap por padrão.

- Adaptado o smoke local para renderizar a página QML com Qt Quick em hosts baseados em Arch. O fork do Calamares do EndeavourOS omite `notesqml` e módulos específicos do Artix; a integração completa do instalador continua sendo verificada no build da ISO Artix.

- Corrigido o aviso de diretório XDG ausente no desktop live: o launcher Aqueous/Pearl executa `xdg-user-dirs-update` antes do compositor, criando os diretórios padrão para contas novas da live e do sistema instalado.

- Corrigido o conflito da transação livefs no P0: `dinx-live-autologin` não empacota mais uma cópia de `/etc/dinit.d/greetd`; seu serviço Dinit habilitado no boot ordena o gravador da configuração única da sessão antes de greetd e `login.target`, mantendo intacto o arquivo do serviço upstream `greetd-dinit`.
- Corrigida uma falha intermitente no smoke de instalação persistente UEFI: o marcador de primeiro boot agora aguarda o `early-root-rw.target` do Dinit antes de gravar em `/var`. A execução com falha revelou a corrida entre o marcador e a remontagem da raiz; a correção passou nos dois modos de firmware no P0 da main [40870759044](https://github.com/rufl/DINX/actions/runs/40870759044). Depois, a Alpha 10 foi validada e publicada pela execução marcada [40879223746](https://github.com/rufl/DINX/actions/runs/40879223746); a qualificação física continua separada.
- Corrigido o check do payload livefs da Alpha 10 para validar o serviço greetd e o link de boot nos caminhos exatos do manifesto. O check corrigido e os gates de instalação BIOS/UEFI, metadados e procedência passaram no P0 da main [40870759044](https://github.com/rufl/DINX/actions/runs/40870759044); a execução marcada [40879223746](https://github.com/rufl/DINX/actions/runs/40879223746) publicou a ISO validada.
- Fortalecido o smoke QEMU da ISO: captura e analisa por OCR a tela selecionada da sessão live, aceita os marcadores de desktop/relógio/layout do painel Pearl quando o nome do produto não aparece e rejeita greeter, TTY, prompts de login, diretório XDG ausente e falhas visíveis do Dinit. O P0 instala o Tesseract com dados em inglês para esse gate.
- Mesa Lavapipe (`vulkan-swrast`) continua na ISO base para aplicativos Vulkan, mas deixou de ser forçada pelo Aqueous: QEMU e sistemas sem render node usam o compositor Pixman de compatibilidade, não o caminho de apresentação llvmpipe que falhou.

- Reforçada a compactação determinística da ISO: o wrapper SquashFS agora usa o preset xz suportado pela ferramenta, BCJ x86, blocos de 256 KiB e dicionário de 256 KiB, excluindo fontes do kernel, caches de pacotes pacman e logs de build. O runtime base não carrega mais o `squashfs-tools` exclusivo do build; o builder mantém a ferramenta em seu toolchain.
- Endurecido o contrato do builder Artix: o digest fixado da imagem é validado antes do trabalho de pacotes/build, encaminhado explicitamente ao container e registrado com segurança nos metadados.
- Fechado o gap de invocação absoluta da compactação: o CI preserva o binário real de `mksquashfs`, instala o wrapper DINX em `/usr/bin/mksquashfs` e o check pós-build verifica que os superblocos de rootfs/livefs usam xz com blocos de 256 KiB. O wrapper também rejeita recursão para si próprio.
- Tornada tolerante a verificação do wrapper privilegiado de `mksquashfs` ao symlink `/usr/sbin` do Artix, mantendo a resolução do comando instalado para o wrapper DINX e evitando uma falha falsa do CI antes da montagem da ISO.
- Estabilizada a obtenção de pacotes Artix com dois mirrors HTTPS oficiais selecionados do inventário atual, rejeitando uma lista ativa vazia e registrando o rótulo/hash da fonte nos metadados para evitar que mirrors obsoletos ou removidos quebrem a montagem da rootfs.
- Mantido o contrato de sessão única apesar da dependência indireta de integração Plasma do Calamares no Artix: o CI exclui a entrada `plasma.desktop` do pacote tanto da rootfs quanto da livefs, então o Pearl expõe apenas Aqueous/Pearl enquanto o Calamares continua disponível.
- Substituído o caminho de login anterior com ReGreet pelo Pearl Greeter: o greetd inicia `/usr/lib/pearl/pearl-greeter-host` pela conta dedicada `pearl-greeter`. As ações de energia continuam wrappers absolutos seguros para dinit, e a ISO rejeita sessões adicionais.
- Adicionado um guard de conteúdo para o próprio livefs da ISO: `AUTOLOGIN=true`, o serviço/link dinit de autologin, o comando Aqueous/Pearl e o usuário live `dinx` precisam estar presentes, enquanto payloads systemd/uwsm no livefs são rejeitados.
- Reduzido o payload da imagem completa com um manifesto comum compacto versionado no repositório: o caminho AMDGPU documentado continua incluído, firmware genérico e `powertop` ficam fora das imagens finais, e os headers do kernel permanecem apenas para gerar o initramfs da ISO enquanto sua árvore de fontes é excluída do SquashFS final.
- Tornamos Aqueous + Pearl a única sessão de usuário selecionável e inicial na live; removemos Labwc, Noctalia e o pacote ReGreet do payload base. O Pearl Greeter é a interface de login instalada/manual.
- Adicionado o Phyto como gerenciador de arquivos nativo padrão e o Pori como único gerenciador gráfico de discos/montagens. O Pori descobre dispositivos pelo UDisks2 e persiste montagens como serviços dinit em `/etc/dinit.d`.
- Restaurados o File Roller para abrir, criar e extrair arquivos compactados graficamente e o GParted para particionamento gráfico independente, mantendo a remoção de Thunar, GVFS, Tumbler e KDE Partition Manager. O driver de kernel `ntfs3` fornece leitura e escrita NTFS na ISO live e no sistema instalado; o `ntfs-3g` legado é opcional após a instalação.

- Adicionados `wdisplays` e `shikane` ao payload desktop base para configuração Wayland interativa e determinística. Adicionado o Dome 0.1.1 como pacote Seafoam base com fonte fixada no Pearl v0.3.0; suas telas de recursos/processos são compatíveis com dinit e o pacote não instala integração com systemd ou uwsm. O Coral não foi incluído intencionalmente.
- Adicionado o launcher base Seafoam Settings em Zig/GTK4 para os pontos de entrada do wdisplays, Shikane, DinitUI, DINXPanel, Qt6ct e Dome. Adicionado o pacote oficial ZLS 0.16.0 com fonte fixada para o caminho LSP Zig do Dintor; os três agora fazem parte da ISO base. O ZLS carrega apenas a árvore `lib/std` correspondente do Zig e um shim de metadados, portanto completion/navegação funcionam sem compilador completo ou systemd; o shim delega comandos de compilação para uma instalação opcional do `zig` do Artix.
- Mantido explícito o limite do compilador upstream: o Pearl 0.3.0, inclusive a fonte usada pelo Dome, e a fonte Pearl 0.2.8 incorporada ao Phyto usam seu toolchain Zig 0.16.0 fixado, baixado e verificado pelo P0; Pori, Aqueous e os demais pacotes Zig nativos da DINX fora dessa árvore upstream continuam no toolchain Zig 0.17.0 verificado.
- Adicionada a ponte de persistência de display da DINX: a entrada desktop do wdisplays, a DINXPanel e o Seafoam Settings usam `dinx-wdisplays`; ao fechar o editor, o perfil `DINX wdisplays` é substituído atomicamente, o Shikane é recarregado e o layout permanece entre sessões.
- Adicionado o relatório somente leitura `dinx-doctor` para evidências de sessão, dinit, armazenamento, display e pacotes; ele nunca executa mutações de serviços, montagem, pacotes ou rede.
- Adicionados Aqueous 1.0.5 e Pearl 0.3.0 à ISO base como a única sessão direta sobre dinit. O greeter e o autologin live iniciam Aqueous/Pearl pelos wrappers DINX; após a prontidão do Wayland e do D-Bus da sessão, o supervisor DINX inicia Shikane, PolicyKit, BC250 opcional, o helper idle obrigatório e Pearl, remove as unidades upstream de systemd/uwsm e registra falha em vez de deixar um desktop vazio. A sessão não adiciona pacote, runtime ou unidade de usuário systemd. Removidos da ISO o servidor, drivers e entrada Plasma X11 legados de Xorg/XLibre, mantendo XWayland e o Xvfb exclusivo do builder.
- Atualizadas as páginas de entrada em inglês e português e a documentação operacional com o snapshot publicado da Alpha 9 e a validação pós-release bem-sucedida da `main` `39934458077`; os docs distinguem evidência de validação dos assets publicados do release.
- Removida a etapa manual do greeter live: a ISO descartável inicia `Aqueous + Pearl (DINX)` por um pacote dinit exclusivo da live, enquanto o sistema instalado e o Calamares mantêm o autologin desativado. Se a sessão live terminar, o greetd retorna ao Pearl Greeter.
- Adicionada uma fronteira de supervisão exclusiva para Aqueous/Pearl: o helper espera o Wayland e o D-Bus ficarem prontos, inicia display/polkit/idle obrigatórios e o Pearl, registra os estados `starting`/`ready`/`failed`/`exited`, encerra o compositor quando um helper obrigatório ou o compositor falha e encerra o processo pai monitorado se o próprio supervisor for parado, sem systemd ou uwsm.
- Endurecida a persistência de montagens do Pori com um wrapper dinit `process` que espera dispositivos, repete montagens, é dono apenas das montagens que criou, desmonta no encerramento e reinicia após desaparecimento inesperado. Phyto, File Roller, GParted e o `ntfs3` do kernel continuam sendo os caminhos suportados para arquivos, arquivos compactados, partições e NTFS.
- Serializadas as atualizações wdisplays→Shikane com `flock`; a substituição do perfil continua atômica, e uma falha ao recarregar o Shikane agora falha de forma visível em vez de reportar persistência bem-sucedida.
- Adicionados inventários exatos das entradas de origem ao `feature-groups.json` e um workflow de contratos sem privilégios para pull requests, verificando drift de pacotes/perfis, contratos de helpers, o smoke da fonte Pori com Zig 0.17 fixado, smokes de fixtures e cobertura REUSE antes do build ISO privilegiado.
- Ordenado o marcador de primeiro boot da instalação persistente depois do `early-root-rw.target`, evitando que a gravação em `/var` concorra com a remontagem read-only da raiz no primeiro boot UEFI.


## v0.1.0-alpha.9 — 2026-10-23

- Publicado o alpha público anterior da DINX para Artix Linux x86_64 com dinit: [release no GitHub](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.9).
- A execução de release [39924316082](https://github.com/rufl/DINX/actions/runs/39924316082), no commit `0d1698a462d5d5486871a7aa17e9b97352ee9404`, passou os contratos de pacotes/perfil, os builds de pacotes Artix, a criação da ISO compacta, boot/payload gráfico no QEMU, smokes BIOS/UEFI/Btrfs do Calamares, instalação persistente/TTY de recuperação em discos descartáveis, verificação dos metadados de build, assinatura persistente de pacotes, atestação de procedência e publicação do release.
- Publicadas a ISO direta, o checksum SHA-512, os metadados de build, o pacote Windows para QEMU, o repositório DINX assinado e os assets de verificação.
- Tamanho publicado da ISO: `2.008.801.280` bytes. SHA-512 completo: `b3724c82348c229ee897880e03e8adc80d9b5b25588b0aca9dfcfedf0c4744e4e1ae01dcb536f6555502e8fe595f71f06bed599372dffe0e1b0f34b29f3b5b2d`.
- Snapshot publicado do repositório DINX assinado: `01fc8270e5f0fa0339647c9bbde5934ec247a7c29cf235940d4ea9dcedab5827`.
- O preset xz suportado, com BCJ x86, blocos de 1 MiB e dicionário de 1 MiB, mantém a ISO direta abaixo do limite de 2 GiB por asset do GitHub.

## v0.1.0-alpha.8 — 2026-10-21

- Publicado o alpha público atual da DINX para Artix Linux x86_64 com dinit: [release no GitHub](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.8).
- A execução de release com tag [39611695024](https://github.com/rufl/DINX/actions/runs/39611695024), no commit `eea66ac`, passou os contratos de pacotes e ISO, boot em QEMU, validação do payload gráfico, smokes transacionais BIOS/UEFI/Btrfs do Calamares, smokes de instalação persistente/TTY de recuperação em discos descartáveis, verificação dos metadados de build, assinatura persistente de pacotes, atestação e publicação do release.
- Publicadas as partes da ISO, checksum SHA-512, metadados de build, pacote Windows para QEMU, repositório DINX assinado e assets de verificação.
- Tamanho publicado da ISO: `2.803.349.504` bytes. SHA-512 completo: `50e8d535fd4a482ea5433b454921a34402f64e2aa9f82ed9434cff659820c944df7b44b062ebd56094948147109ff65b6f31889080340de484c36fb5d7eb5b8a`.
- Snapshot publicado do repositório DINX assinado: `5a61d50f3837161bed1af7619965b44e80bd885e79457e443c328e0151d805d9`.
- Atualizadas as páginas de entrada em inglês e português e a documentação de release para apontarem para a Alpha 8.

### Limites conhecidos

Este continua sendo um alpha público. Hardware físico, uma sessão gaming DRM real, Steam autenticado e launch de jogo comercial, entrada de controle, áudio PipeWire do jogo, suspensão/retomada, recuperação da GPU, Secure Boot e atualização/rollback da ISO instalada continuam fora da afirmação do release.
