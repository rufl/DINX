# Ferramentas internas, ports e patches downstream da DINX (BSD)

[Português (Brasil)](dinxtools.md) · [English](../dinxtools.md)

A linha `dinxtools/*` mantém o software que a DINX constrói, patcheia ou empacota ela mesma: as
ferramentas de primeira mão (DinitUI, DINXPanel, Deetty/Dintor, WIZP) e os conjuntos de patches
downstream das sessões de terceiros (Aqueous, Pearl). Este ramo carrega o lado FreeBSD;
`dinxtools/main` carrega o lado Arch/Artix.

Os dois ramos não são mesclados. `main` e `feature/dinx-bsd` divergiram (71 commits só no lado BSD,
169 só no lado Linux) e ambos os CHANGELOGs, `scripts/build-iso-container.sh` e
`scripts/check-iso-content.sh` foram editados dos dois lados, então qualquer merge gera conflito em
todo arquivo compartilhado. A mudança entra em um ramo e depois passa ao outro por cherry-pick ou à
mão.

## Onde ficam as coisas

| Caminho | Conteúdo |
| --- | --- |
| `distro/bsd/ports/Makefile.<nome>` | um Makefile de port FreeBSD por componente empacotado (54 hoje) |
| `distro/bsd/config/packages.txt` | manifesto de instalação, 71 entradas não vazias `categoria/nome` |
| `distro/bsd/config/octapkg.conf` | configuração do repositório OctaPkg |
| `distro/bsd/config/dinit/` | unidades Dinit da imagem BSD (`greetd`, `pipewire`, `seatd`) |
| `scripts/build-bsd.sh`, `scripts/build-bsd-iso.sh`, `scripts/build-bsd-iso-unattended.py`, `scripts/install-dinx-bsd.sh` | pipeline de build e boot BSD |
| `scripts/check_dinx_bsd.sh` | gate de contrato BSD: afirma a existência de cada Makefile de port |
| `.github/workflows/bsd-iso.yml`, `bsd-validation.yml` | CI BSD |
| `distro/packages/<nome>/` | receitas Linux, presentes nesta árvore mas não usadas pela imagem BSD |

## Inventário BSD da linha de ferramentas

| Ferramenta | Port | Versão do port | O que o port busca | Pin Linux (`dinxtools/main`) | Patches no BSD |
| --- | --- | --- | --- | --- | --- |
| DinitUI | `Makefile.dinitui` | 0.2.0 | `github.com/rufl/dinitui/releases/download/v0.2.0/` | 0.1.0-6, fonte na árvore, sem tarball | nenhum |
| DINXPanel | `Makefile.dinxpanel` | 1.0.0 | `github.com/rufl/dinxpanel/releases/download/v1.0.0/` | 0.1.0-8, fonte na árvore | nenhum |
| Deetty | `Makefile.deetty` | 0.1.0 | `github.com/rufl/DEETTY/releases/download/v0.1.0/` | 0.1.0-10 fixado no commit `d7d97fa`, SHA-256 verificado | nenhum dos 3 patches Linux |
| Pearl | `Makefile.pearl` | 0.3.0 | `github.com/rufl/pearl/releases/download/v0.3.0/` | 1:0.3.0-11 de `Seafoam-Labs/pearl` v0.3.0, Zig 0.16.0 fixado | nenhum dos 4 patches Linux |
| Aqueous | `Makefile.aqueous` | 1.0.5 | `USE_GITHUB` com `GH_ACCOUNT=rufl`, `GH_PROJECT=Aqueous` | 1.0.5-14 de `Seafoam-Labs/Aqueous` v1.0.5 + wlroots 0.20.2 empacotado | nenhum dos 7 patches Linux |
| WIZP | sem port | — | — | 0.1.0-1 do build autocontido `rufl/WIZP` | — |

Dintor não é um pacote próprio em nenhuma das linhas. No Linux é o binário do editor construído a
partir do Deetty e publicado via `provides=('dintor')`. No BSD não existe port `dintor`:
`Makefile.dinted` é o DintEd, outro editor, de `rufl/DINTED` (`editors/dinted`, listado em
`packages.txt`). A imagem BSD portanto não tem editor DINX sob o nome `dintor`, e a paridade do
contrato de `$EDITOR` está em aberto.

## Defeitos em aberto neste ramo

Verificados na árvore 3f4fc34 em 2026-11-14.

1. Quatro alvos de fetch nomeiam repositórios que não existem: `rufl/dinitui`, `rufl/dinxpanel`,
   `rufl/pearl` e `rufl/Aqueous`. Pearl e Aqueous são projetos a montante em
   `Seafoam-Labs/pearl` e `Seafoam-Labs/Aqueous` (ambos com as tags fixadas `v0.3.0` e `v1.0.5`);
   DinitUI e DINXPanel não têm repositório próprio nenhum — o fonte deles está na árvore em
   `distro/packages/` na linha Linux. Então `make fetch` falha nos quatro ports.
2. `Makefile.deetty` e `Makefile.dinted` buscam arquivos de release de `rufl/DEETTY` e `rufl/DINTED`;
   os dois repositórios existem mas não publicam releases nem tags, então essas URLs são
   inalcançáveis.
3. Nenhum port envia `distinfo`, então nenhum port verifica checksum. As receitas Linux fixam cada
   fonte por SHA-256 em `source.env`.
4. Os ports BSD constroem o fonte a montante sem patch. Toda mudança comportamental do Linux falta
   no BSD: supervisão Dinit e os três workspaces padrão do Aqueous (`dinit.patch`,
   `two-default-workspaces.patch`), renderização GLES2 (`gles2-renderer.patch`), decorações no
   servidor (`server-decorations.patch` no Aqueous e no Pearl), texto da barra de título e política
   de bloqueio live (`titlebar-text.patch`, `live-session-lock.patch`,
   `client-maximize-readiness.patch`), identidade de produto do Deetty e a renomeação para `dintor`
   (`product-identity.patch`), e o exec de terminal do Deetty (`deetty-terminal-exec.patch`,
   `deetty-terminal.patch` do Pearl).
5. O `packages.txt` discorda dos ports que lista: `x11-wm/dinxpanel` contra `CATEGORIES= x11` e
   `x11-wm/dinx-live-autologin` contra `CATEGORIES= sysutils`. `security/opensnitch-ui` tem port mas
   não tem entrada no manifesto, e o OpenSnitch foi aposentado do payload Linux.
6. `Makefile.aqueous` declara `LICENSE= MIT` enquanto a receita Linux declara
   `GPL-3.0-only/MIT/0BSD/CC-BY-SA-4.0`; `Makefile.pearl` declara `MIT` onde a receita Linux declara
   `LicenseRef-Pearl-Unlicensed`. Os metadados de licenciamento precisam ser reconciliados antes de
   um release BSD.
7. `BUILD_DEPENDS` fixa `zig>=0.13.0` nos ports Deetty, DinitUI, DINXPanel, Pearl e DintEd, mas as
   receitas Linux exigem `zig>=0.17` e o Pearl exige exatamente 0.16.0. Os ports compilariam contra
   um Zig que o fonte rejeita.
8. `scripts/check_dinx_bsd.sh` só afirma que cada Makefile existe; nada neste ramo constrói um port,
   então um `MASTER_SITES` quebrado passa no gate.

Correções devem ser commitadas por ferramenta: corrigir o alvo de fetch, adicionar `distinfo`, e só
então adicionar o conjunto de patches com `PORTVERSION`/`PORTREVISION` no mesmo commit.

## Regras desta linha

- Um port por componente, nomeado `Makefile.<PORTNAME>`, e adicioná-lo ao
  `distro/bsd/config/packages.txt` como `categoria/nome` no mesmo commit.
- `CATEGORIES` do Makefile deve bater exatamente com a entrada do manifesto; é o manifesto que o
  instalador resolve.
- `MASTER_SITES` deve apontar para um release real e com tag, e todo port precisa de `distinfo` com
  o SHA-256 do distfile. Nunca buscar um branch flutuante.
- Uma edição da DINX em fonte alheia é um patch em `files/` daquele port, aplicado pelo framework de
  ports. Manter o mesmo conteúdo do `.patch` do Linux para que um rebase atualize as duas linhas.
- Aumentar `PORTVERSION` para mudança a montante e `PORTREVISION` para mudança de patch ou
  dependência; registrar ambos em `CHANGELOG.md` e `CHANGELOG.pt-BR.md`.
- Manter os mínimos de Zig alinhados com os `makedepends` do Linux, incluindo o pin exato do Pearl.

## Checklist de paridade Linux

Uma mudança aqui visível ao usuário exige a mudança correspondente em `dinxtools/main`:

1. Atualizar `distro/packages/<nome>/PKGBUILD` e `source.env` (pin, SHA-256, `pkgrel`).
2. Aplicar o mesmo conteúdo de patch lá como `distro/packages/<nome>/<nome>.patch`.
3. Rodar o gate Linux daquela ferramenta (`scripts/check_dinitui.sh`, `scripts/check_dinxpanel.sh`,
   `scripts/check_deetty_integration.sh`, `scripts/check_wizp_package.sh`,
   `scripts/check_aqueous_pearl.sh`) mais `scripts/check_dinx_bsd.sh` aqui.
