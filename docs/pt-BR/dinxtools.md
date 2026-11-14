# Ferramentas internas, ports e patches downstream da DINX

[Português (Brasil)](dinxtools.md) · [English](../dinxtools.md)

A linha `dinxtools/*` mantém o software que a DINX constrói, patcheia ou empacota ela mesma: as
ferramentas de primeira mão (DinitUI, DINXPanel, Deetty/Dintor, WIZP) e os conjuntos de patches
downstream das sessões de terceiros (Aqueous, Pearl). Ela existe para manter um único inventário de
cada mudança de propriedade da DINX e a regra que se aplica a ela.

A linha é dividida em dois ramos, um por alvo de entrega:

| Ramo | Base | Caminho de empacotamento |
| --- | --- | --- |
| `dinxtools/main` | `main` | Receitas Arch/Artix em `distro/packages/<nome>/` |
| `dinxtools/bsd` | `feature/dinx-bsd` | Makefiles de port FreeBSD em `distro/bsd/ports/` |

Os dois ramos não são mesclados. `main` e `feature/dinx-bsd` divergiram (71 commits só no lado BSD,
169 só no lado Linux) e ambos os CHANGELOGs, `scripts/build-iso-container.sh` e
`scripts/check-iso-content.sh` foram editados dos dois lados, então qualquer merge gera conflito em
todo arquivo compartilhado. A mudança entra em um ramo e depois passa ao outro por cherry-pick ou à
mão.

## Inventário (Linux, este ramo)

| Ferramenta | Tipo | Fonte autoritativa | Receita DINX | Scripts de gate |
| --- | --- | --- | --- | --- |
| DinitUI | primeira mão, GTK4/libadwaita + Zig | `distro/packages/dinitui/src/` (na árvore) | `distro/packages/dinitui/PKGBUILD`, `source=()` | `scripts/check_dinitui.sh`, `scripts/dinitui_dinit_qualification.sh` |
| DINXPanel | primeira mão, GTK4/libadwaita + Zig | `distro/packages/dinxpanel/src/` (na árvore) | `distro/packages/dinxpanel/PKGBUILD`, `source=()` | `scripts/check_dinxpanel.sh` |
| Deetty + Dintor | fork de primeira mão + patches | `rufl/DEETTY`, fixado por `DEETTY_REF` em `source.env` | `distro/packages/deetty/PKGBUILD` (0.1.0-10, `provides=('dintor')`) | `scripts/check_deetty_integration.sh`, `scripts/deetty_p2_qualification.sh`, `scripts/dintor_p3_qualification.sh` |
| WIZP | build de terceiro, runtime empacotado | `rufl/WIZP` | `distro/packages/wizp/PKGBUILD` (exige `WIZP_PACKAGE_DIR`) | `scripts/check_wizp_package.sh` |
| Pearl | terceiro + conjunto de patches | tag `v0.3.0` de `Seafoam-Labs/pearl` fixada por SHA-256 | `distro/packages/pearl/PKGBUILD` (epoch 1, 0.3.0-11) | `scripts/check_aqueous_pearl.sh` |
| Aqueous | terceiro + conjunto de patches | tag `v1.0.5` de `Seafoam-Labs/Aqueous` + `wlroots` 0.20.2 fixados | `distro/packages/aqueous/PKGBUILD` (1.0.5-14) | `scripts/check_aqueous_pearl.sh` |
| Ports de tema Pearl/GTK | forks + assets gerados | `rufl/skeuos-gtk`, `rufl/Orchis-theme` | `distro/packages/dinx-pearl-themes`, `distro/packages/dinx-gtk-themes` | `scripts/check-iso-content.sh` (caminhos + metadados), `scripts/check_dinx_theme.sh` (tema da sessão DINX) |

Dintor não é um pacote separado: é o binário do editor produzido pelo build do Deetty
(`product-identity.patch` renomeia o `nocted` a montante para `dintor`) e é publicado via
`provides=('dintor')`. O gate da ISO exige `usr/bin/dintor`, `usr/share/dintor/language-specs/` e
`usr/share/dintor/styles/`. DintEd (`editors/dinted`) é outro editor e só existe como port BSD;
veja o ramo BSD.

## Conjuntos de patches downstream

Cada edição de fonte alheia pertencente à DINX é um `.patch` ao lado do seu PKGBUILD, aplicado em
`prepare()` com `--fuzz=0`, de forma que uma derivação a montante falhe o build em vez de deslocar
hunks em silêncio.

Aqueous (`distro/packages/aqueous`, aplicado nesta ordem):

1. `dinit.patch` — remove o link com `libsystemd` do compositor e dos testes de teclado (supervisor
   Dinit, sem systemd), corrige a detecção de `scdoc` e o caminho do `git describe`, e move a
   dependência zig-wayland para um commit 0.8.0-dev fixado.
2. `gles2-renderer.patch` — constrói o render hook do wlroots com `-Drenderers=gles2,vulkan` para
   que o virtio-GPU acessível mantenha GLES2.
3. `server-decorations.patch` — mover/redimensionar decorações no servidor via ações de decoração do
   cursor.
4. `titlebar-text.patch` — liga `pangocairo` e compila o `titlebar_text.c` vendorizado para que as
   barras de título desenhem os títulos dos clientes.
5. `two-default-workspaces.patch` — entrega três workspaces padrão em vez de dez.
6. `live-session-lock.patch` — política de bloqueio da sessão live no `LockManager`, com o
   `live_lock_policy.zig` vendorizado.
7. `client-maximize-readiness.patch` — conecta o `client_maximize_request.zig` vendorizado ao
   `CompositorApi`.

O `prepare()` também instala na árvore descompactada os companheiros vendorizados de que os patches
precisam (`client_maximize_request.zig`, `titlebar_text.c`, `titlebar_text.zig`,
`live_lock_policy.zig`); o `check()` compila o `titlebar_text_test.c` contra o fonte patcheado, e o
`scripts/check_aqueous_pearl.sh` roda `window_policy_test.zig` e `live_lock_policy.zig` na árvore
fixada. A receita fixa `AQUEOUS_WLROOTS_SHA256` para o arquivo wlroots 0.20.2 empacotado.

Pearl (`distro/packages/pearl`):

1. `deetty-terminal.patch` — substitui a lista de terminais a montante (foot/Ghostty) para que o
   Pearl abra o Deetty.
2. `server-decorations.patch` — remove os botões de decoração do `HeaderBar` do próprio Pearl (o
   Aqueous é dono das decorações) e adiciona validação do rascunho do formulário, impedindo a
   aplicação de uma cor inválida.
3. `greeter-state-home.patch` — estado do greeter em `/var/lib/pearl-greeter/.local/state`.
4. `remove-find-your-next-thing.patch` — remove o cabeçalho vazio da busca do launcher.

`dinx-first-run-wizard.c` é compilado pela mesma receita e fica no diretório do pacote, não é
aplicado ao fonte a montante. O Pearl exige Zig exatamente `PEARL_ZIG_VERSION` (0.16.0), baixado e
com checksum fixado pela receita.

Deetty (`distro/packages/deetty`):

1. `product-identity.patch` — renomeia os alvos `noctty`/`nocted`/`noctty-vte`/`noctty-smoke` para
   `deetty`/`dintor`/`deetty-vte`/`deetty-smoke` e as descrições das opções.
2. `qualification-compat.patch` — expõe o módulo `compat` aos alvos de qualificação de sessão de
   terminal, equidade, continuidade, TUI real, ncurses e TUI de sistema, instala os estilos do
   editor em `share/dintor/` e renomeia os marcadores `NOCTTY_*` para `DEETTY_*`.
3. `deetty-terminal-exec.patch` — adiciona `quoteCommandArguments` ao `LaunchProfile` para que os
   argumentos de exec do terminal sejam citados em POSIX e bytes de controle sejam rejeitados.

`pori/pori-dinit.patch` segue as mesmas regras; Pori só não aparece na lista de ferramentas acima
porque não é uma delas.

## Regras desta linha

- Nunca edite o fonte descompactado a montante no lugar. Adicione ou atualize um `.patch` no
  diretório do pacote, mantenha `patch --fuzz=0 --forward` e aumente o `pkgrel`.
- Fixe pin e digest juntos: as URLs e os SHA-256 de a montante ficam em `source.env` e são consumidos
  pelo PKGBUILD; ferramentas de primeira mão (`dinitui`, `dinxpanel`) mantêm `source=()` porque o
  fonte delas está na árvore.
- Atualizar um pin é uma mudança completa: recalcular o SHA-256, rebasear cada patch na nova tag,
  aumentar o `pkgrel`, rodar o script de gate daquele pacote e depois o gate de conteúdo da ISO.
- Registrar toda mudança em `CHANGELOG.md` e `CHANGELOG.pt-BR.md`.
- Antes de uma correção a montante entrar, abra-a no projeto original e mantenha o patch da DINX
  como carregamento temporário; remover um patch porque o projeto original o absorveu é mudança a
  anotar aqui.

## Checklist de paridade BSD

Uma mudança em `dinxtools/main` visível ao usuário exige a mudança correspondente em
`dinxtools/bsd`:

1. Atualizar ou criar `distro/bsd/ports/Makefile.<nome>` para que `PORTVERSION`, `CATEGORIES` e
   `MASTER_SITES` coincidam com o pin do Linux.
2. Aplicar o mesmo conjunto de patches; hoje os ports BSD constroem os tarballs a montante sem
   patch.
3. Atualizar `distro/bsd/config/packages.txt` no mesmo commit da mudança de categoria.
4. Rodar `scripts/check_dinx_bsd.sh`, que afirma a existência de cada Makefile de port.

Lacunas conhecidas no ramo BSD em 2026-11-14, acompanhadas lá: `Makefile.dinitui`,
`Makefile.dinxpanel`, `Makefile.pearl` e `Makefile.aqueous` buscam de repositórios `rufl/*` que não
existem; `Makefile.deetty` e `Makefile.dinted` buscam arquivos de release de repositórios que não
publicam releases nem tags; nenhum port carrega `distinfo`, checksum ou o conjunto de patches do
Linux; o `packages.txt` lista `x11-wm/dinxpanel` e `x11-wm/dinx-live-autologin` enquanto esses
Makefiles declaram `x11` e `sysutils`; `security/opensnitch-ui` ainda tem port embora o OpenSnitch
tenha sido aposentado do payload Linux; WIZP não tem port algum.
