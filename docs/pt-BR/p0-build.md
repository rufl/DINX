# Status do build P0

[Português (Brasil)](p0-build.md) · [English](../p0-build.md)

## Implementação selecionada

A DINX usa o fluxo atual `artools`/`buildiso` do Artix com um `profile.yaml` local no repositório, em `distro/iso/iso-profiles/dinx`. Isso mantém a seleção de pacotes de serviços dinit no caminho suportado pelo Artix e evita inventar uma segunda ferramenta de ISO.

Os pontos de entrada são:

- `scripts/check-iso-host.sh` — probe de pré-requisitos;
- `scripts/build-iso.sh` — wrapper de build com suporte a root;
- `scripts/prepare_first_party_apps.sh` — gerador determinístico do archive do código fixado do NOCTTY/NoctEd;
- `scripts/check_first_party_apps.sh` — verificação do contrato do código, pacote e perfil first-party;
- `scripts/smoke-iso.sh` — probe de boot em QEMU;
- `.github/workflows/p0-iso.yml` — build remoto em container Artix;
- `.github/workflows/release.yml` — publicação de pré-release por tag e montagem do pacote Windows para QEMU;
- `distro/packages/noctty/PKGBUILD` — pacote Zig nativo que instala NOCTTY e NoctEd;
- `distro/packages/noctty/source.env` — contrato de repositório, commit, versão e SHA-256 da origem;
- `distro/packages/wlroots0.20/PKGBUILD` — build fixado do wlroots 0.20.2 para o ABI atual do Mango/Scenefx;
- `distro/iso/iso-profiles/dinx/profile.yaml` — perfil de pacotes e serviços da fundação.

## Build remoto

O workflow `P0 ISO foundation` é executado manualmente ou quando arquivos do perfil/build mudam. Ele:

1. faz checkout da DINX;
2. verifica o archive versionado do código NOCTTY/NoctEd contra `distro/packages/noctty/source.env` e valida o contrato do pacote/perfil;
3. instala QEMU e ferramentas de inspeção de ISO no runner Ubuntu;
4. executa Artix em um container privilegiado;
5. instala `artools`, `iso-profiles`, Zig 0.17.0 e as dependências de build fixadas do MangoWM/Scenefx;
6. compila o pacote nativo `noctty`, que contém NOCTTY e NoctEd, depois compila wlroots 0.20.2, MangoWM e Scenefx usando o repositório pacman local temporário;
7. executa o probe de pré-requisitos;
8. constrói a ISO com `buildiso`;
9. valida os payloads SquashFS do root e da sessão live;
10. gera checksum SHA-512;
11. mantém QEMU executando por uma janela de boot configurável e captura sua superfície VGA;
12. publica a ISO, o checksum e a captura PPM como artefato temporário do workflow.

`distro/packages/noctty/noctty-0.1.0.tar.gz` é um archive de código versionado e verificado por SHA-256. `source.env` registra o commit do repositório NOCTTY usado para produzi-lo; os mantenedores o regeneram com `scripts/prepare_first_party_apps.sh` a partir de um checkout local limpo do NOCTTY e versionam o archive e o contrato juntos. O caminho do CI não clona o NOCTTY nem exige token de repositório.

A verificação de payload prova que MangoWM, Scenefx, Noctalia, ReGreet, greetd, a sessão Mango, os arquivos de serviço dinit, NOCTTY/NoctEd e a stack de mídia removível Thunar/GVFS/UDisks2 chegaram à ISO. Ela também confirma o agente independente de PolicyKit e rejeita systemd e sessões completas do Xfce/LXQt. O smoke test do QEMU ainda prova somente a aceitação do processo/caminho de boot; não prova login gráfico, rede ou áudio dentro do guest.

A execução também captura a superfície VGA do QEMU como artefato PPM pelo monitor. Essa captura é evidência visual para inspeção; ela não prova automaticamente a interação com o greeter, a saúde da sessão do usuário, a rede ou o áudio.

Releases por tag reutilizam o mesmo artefato de build por meio de `.github/workflows/release.yml`. O job de release publica a ISO, seu SHA-512, as evidências do QEMU Linux e um pacote launcher Windows pequeno. O launcher baixa a ISO somente da URL HTTPS fixada nos metadados, verifica o SHA-512 e executa `scripts/smoke-iso.ps1` com QEMU no Windows. Os metadados ZTASH apontam para o receptor registrado `ddjarin` sem embutir credenciais.

A sobreposição live também substitui o serviço dinit genérico `root-ro` por um no-op: a raiz live é um overlay e não pode ser remontada somente para leitura. Esse ajuste vale apenas para a sessão live da ISO, não é uma política do sistema instalado.

O wrapper do Mango habilita `WLR_RENDERER_ALLOW_SOFTWARE=1` somente quando `/dev/dri/renderD*` está ausente; portanto, o caminho QEMU headless não mascara um render node DRM real.

O perfil agora controla a configuração do tema GRUB do Artix em `root-overlay/usr/share/grub/themes/artix/theme.txt`. Ele mantém os assets upstream de fundo, logo, ícones e fonte, mas omite as texturas opacas `menu_pixmap_style` e `selected_item_pixmap_style` que produziam um painel preto na tela gráfica de seleção do kernel. `scripts/check-iso-content.sh` verifica que esse override da DINX chega à imagem SquashFS do root.

Para uma captura gráfica local, defina `DINX_QEMU_BOOT_KEYS=down,down,ret`, `DINX_QEMU_SCREENSHOT` e, opcionalmente, `DINX_QEMU_SCREENSHOT_DELAY` antes de executar `scripts/smoke-iso.sh`; o workflow usa as mesmas teclas, atraso de 60 segundos e publica o PPM junto com o artefato da ISO.

O workflow também captura `dinx-boot-screen.ppm` três segundos depois que o QEMU abre e antes do envio das teclas do menu de boot. Isso fornece evidência visual direta de regressão para a tela GRUB de seleção do kernel.

O perfil também incorpora um caminho experimental offline do Calamares com branding DINX escuro, módulos de serviço dinit e um KDE Partition Manager independente. A verificação de conteúdo confirma a configuração do instalador, os defaults escuros do ReGreet e do Noctalia, os defaults de animação/transparência desativados do Noctalia, o default de dois desktops do Mango e seu override editável pelo usuário, o launcher do instalador DINX, o binário `partitionmanager` e a stack de mídia removível; ela não substitui um teste de instalação em disco destrutivo.

Para uma segunda captura diagnóstica após entrada de teclas, defina também `DINX_QEMU_POST_SCREENSHOT` e, opcionalmente, `DINX_QEMU_POST_SCREENSHOT_DELAY` e `DINX_QEMU_POST_KEYS`. Isso não prova que o greeter aceitou as credenciais.


## Execução bem-sucedida observada

A execução [38471629482](https://github.com/rufl/DINX/actions/runs/38471629482), no commit `6224b58`, concluiu todas as etapas do workflow em 6m02s:

- artefato ISO: `artix-dinx-dinit-20261013-x86_64.iso`;
- tamanho: 1.497.237.504 bytes;
- SHA-512: `adcd6cba882b368725ffa02d33e8a2ae17c3be1b9ffaa17692dbd9eb895689bb0a686530f1012a11f6d262ef2d9ab859d27c2995393aa1ded4cd50d4af42433c`;
- janela de smoke no QEMU: 90 segundos, aprovada;
- verificação de payload: MangoWM, Scenefx, Noctalia, ReGreet, greetd e payloads dinit presentes;
- captura gráfica: o quadro inicial mostrou o seletor de usuário/sessão do ReGreet, e o quadro após as teclas mostrou a sessão MangoWM com a tela de boas-vindas do Noctalia;
- artefato: `dinx-foundation-iso-6224b5859de814b1d5fe7e2fae982e1c9c49918f`, mantido por 7 dias.

O log serial gerado ficou vazio. As duas capturas VGA fornecem evidência da renderização do greeter e da transição bem-sucedida para a sessão gráfica do usuário; não provam rede, áudio ou saúde dos serviços em longo prazo.

## Host de desenvolvimento observado

O host de desenvolvimento é EndeavourOS x86_64. `pacman`, `xorriso` e `zig` estão disponíveis. `buildiso`, `mkarchiso` e `qemu-system-x86_64` não estão instalados. Bibliotecas de usuário do QEMU e `/dev/kvm` estão presentes, mas isso não é suficiente para executar o smoke test local.

Portanto, o build P0 deve ser executado no workflow remoto até que as dependências locais sejam disponibilizadas.

## Sequência de aceitação

1. `scripts/check-iso-host.sh` termina com sucesso no container Artix.
2. `scripts/build-iso.sh -q` resolve o perfil `dinx` com `dinit`.
3. Um build limpo produz uma ISO e seus metadados de build.
4. A verificação gráfica encontra o compositor, shell, greeter, sessão, aplicativos próprios, stack de mídia removível e arquivos dinit.
5. O checksum SHA-512 é gerado junto da ISO.
6. `scripts/smoke-iso.sh` mantém o QEMU ativo durante a janela de boot.
7. A ISO inicializa na sessão de fundação e oferece uma TTY de recuperação.
8. Rede, PipeWire, D-Bus, portais e gráficos são verificados no sistema inicializado.
9. Somente depois desses passos os pacotes do desktop e dos aplicativos próprios entram como entradas de release.
