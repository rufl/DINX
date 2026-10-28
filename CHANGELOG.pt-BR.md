# Changelog

Este arquivo registra as mudanças importantes da DINX em linguagem direta. Ele não afirma que o roadmap terminou; a evidência de qualificação e os metadados do release são a fonte de verdade.

## Não lançado

- Reforçada a compactação determinística da ISO: o wrapper SquashFS agora usa o preset xz suportado pela ferramenta, BCJ x86, blocos de 256 KiB e dicionário de 256 KiB, excluindo fontes do kernel, caches de pacotes pacman e logs de build. O runtime base não carrega mais o `squashfs-tools` exclusivo do build; o builder mantém a ferramenta em seu toolchain.
- Endurecido o contrato do builder Artix: o digest fixado da imagem é validado antes do trabalho de pacotes/build, encaminhado explicitamente ao container e registrado com segurança nos metadados.
- Fechado o gap de invocação absoluta da compactação: o CI preserva o binário real de `mksquashfs`, instala o wrapper DINX em `/usr/bin/mksquashfs` e o check pós-build verifica que os superblocos de rootfs/livefs usam xz com blocos de 256 KiB. O wrapper também rejeita recursão para si próprio.
- Tornada tolerante a verificação do wrapper privilegiado de `mksquashfs` ao symlink `/usr/sbin` do Artix, mantendo a resolução do comando instalado para o wrapper DINX e evitando uma falha falsa do CI antes da montagem da ISO.
- Atualizada a mirrorlist HTTPS do Artix pelo gerador oficial antes do trabalho de pacotes do builder e do livefs, rejeitando uma lista ativa vazia e registrando URL/hash nos metadados para evitar que mirrors obsoletos ou removidos quebrem a montagem da rootfs.
- Substituído o caminho de login anterior com ReGreet pelo Pearl Greeter: o greetd inicia `/usr/lib/pearl/pearl-greeter-host` pela conta dedicada `pearl-greeter`. As ações de energia continuam wrappers absolutos seguros para dinit, e a ISO rejeita sessões adicionais.
- Adicionado um guard de conteúdo para o próprio livefs da ISO: `AUTOLOGIN=true`, o serviço/link dinit de autologin, o comando Aqueous/Pearl e o usuário live `dinx` precisam estar presentes, enquanto payloads systemd/uwsm no livefs são rejeitados.
- Reduzido o payload da imagem completa com um manifesto comum compacto versionado no repositório: o caminho AMDGPU documentado continua incluído, firmware genérico e `powertop` ficam fora das imagens finais, e os headers do kernel permanecem apenas para gerar o initramfs da ISO enquanto sua árvore de fontes é excluída do SquashFS final.
- Tornamos Aqueous + Pearl a única sessão de usuário selecionável e inicial na live; removemos Labwc, Noctalia e o pacote ReGreet do payload base. O Pearl Greeter é a interface de login instalada/manual.
- Adicionado o Phyto como gerenciador de arquivos nativo padrão e o Pori como único gerenciador gráfico de discos/montagens. O Pori descobre dispositivos pelo UDisks2 e persiste montagens como serviços dinit em `/etc/dinit.d`.
- Restaurados o File Roller para abrir, criar e extrair arquivos compactados graficamente e o GParted para particionamento gráfico independente, mantendo a remoção de Thunar, GVFS, Tumbler e KDE Partition Manager. O driver de kernel `ntfs3` fornece leitura e escrita NTFS na ISO live e no sistema instalado; o `ntfs-3g` legado é opcional após a instalação.

- Adicionados `wdisplays` e `shikane` ao payload desktop base para configuração Wayland interativa e determinística. Adicionado o Dome 0.1.1 como pacote Seafoam base com fonte fixada no Pearl v0.3.0; suas telas de recursos/processos são compatíveis com dinit e o pacote não instala integração com systemd ou uwsm. O Coral não foi incluído intencionalmente.
- Adicionado o launcher base Seafoam Settings em Zig/GTK4 para os pontos de entrada do wdisplays, Shikane, DinitUI, DINXPanel, Qt6ct e Dome. Adicionado o pacote oficial ZLS 0.16.0 com fonte fixada para o caminho LSP Zig do Nocted; os três agora fazem parte da ISO base. O ZLS carrega apenas a árvore `lib/std` correspondente do Zig e um shim de metadados, portanto completion/navegação funcionam sem compilador completo ou systemd; o shim delega comandos de compilação para uma instalação opcional do `zig` do Artix.
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
- Aumentado para 120 minutos o timeout do workflow ISO privilegiado e tornado explícito o fallback da imagem Artix fixada, mantendo as asserções de digest e o registro nos metadados.


## v0.1.0-alpha.9 — 2026-10-23

- Publicado o alpha público atual da DINX para Artix Linux x86_64 com dinit: [release no GitHub](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.9).
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
