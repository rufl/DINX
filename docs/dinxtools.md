# DINX internal tools, ports and downstream patches (BSD)

[English](dinxtools.md) · [Português (Brasil)](pt-BR/dinxtools.md)

`dinxtools/*` is the maintenance line for software DINX builds, patches or packages itself: the
first-party tools (DinitUI, DINXPanel, Deetty/Dintor, WIZP) and the downstream patch sets for
third-party sessions (Aqueous, Pearl). This branch carries the FreeBSD side; `dinxtools/main`
carries the Arch/Artix side.

The two lines are not merged. `main` and `feature/dinx-bsd` diverged (71 commits only on the BSD
side, 169 only on the Linux side) and both CHANGELOGs, `scripts/build-iso-container.sh` and
`scripts/check-iso-content.sh` were edited on both sides, so a merge conflicts on every shared
file. Changes land on one branch first, then move to the other by cherry-pick or by hand.

## Where things live

| Path | Contents |
| --- | --- |
| `distro/bsd/ports/Makefile.<name>` | one FreeBSD port Makefile per packaged component (54 today) |
| `distro/bsd/config/packages.txt` | install manifest, 71 non-empty `category/name` entries |
| `distro/bsd/config/octapkg.conf` | OctaPkg repository configuration |
| `distro/bsd/config/dinit/` | Dinit service units for the BSD image (`greetd`, `pipewire`, `seatd`) |
| `scripts/build-bsd.sh`, `scripts/build-bsd-iso.sh`, `scripts/build-bsd-iso-unattended.py`, `scripts/install-dinx-bsd.sh` | BSD build and boot pipeline |
| `.github/workflows/bsd-iso.yml`, `bsd-validation.yml` | BSD CI |
| `distro/packages/<name>/` | Linux recipes, present in this tree but not used by the BSD image |

## BSD inventory for the tool line

| Tool | Port | Port version | Port fetches | Linux pin (`dinxtools/main`) | Patches carried on BSD |
| --- | --- | --- | --- | --- | --- |
| DinitUI | `Makefile.dinitui` | 0.2.0 | `github.com/rufl/dinitui/releases/download/v0.2.0/` | 0.1.0-6, source in-tree, no tarball | none |
| DINXPanel | `Makefile.dinxpanel` | 1.0.0 | `github.com/rufl/dinxpanel/releases/download/v1.0.0/` | 0.1.0-8, source in-tree | none |
| Deetty | `Makefile.deetty` | 0.1.0 | `github.com/rufl/DEETTY/releases/download/v0.1.0/` | 0.1.0-10 pinned to commit `d7d97fa`, SHA-256 verified | none of the 3 Linux patches |
| Pearl | `Makefile.pearl` | 0.3.0 | `github.com/rufl/pearl/releases/download/v0.3.0/` | 1:0.3.0-11 from `Seafoam-Labs/pearl` v0.3.0, Zig 0.16.0 pinned | none of the 4 Linux patches |
| Aqueous | `Makefile.aqueous` | 1.0.5 | `USE_GITHUB` with `GH_ACCOUNT=rufl`, `GH_PROJECT=Aqueous` | 1.0.5-14 from `Seafoam-Labs/Aqueous` v1.0.5 + bundled wlroots 0.20.2 | none of the 7 Linux patches |
| WIZP | no port | — | — | 0.1.0-1 from `rufl/WIZP` self-contained build | — |

Dintor is not its own package on either line. On Linux it is the editor binary built from Deetty and
published through `provides=('dintor')`. On BSD there is no `dintor` port: `Makefile.dinted` is
DintEd, a different editor from `rufl/DINTED` (`editors/dinted`, listed in `packages.txt`). The BSD
image therefore has no DINX editor under the `dintor` name, and `$EDITOR` contract parity is
unresolved.

## Open defects on this branch

Verified against the tree at 3f4fc34 on 2026-11-14.

1. Four fetch targets name repositories that do not exist: `rufl/dinitui`, `rufl/dinxpanel`,
   `rufl/pearl` and `rufl/Aqueous`. Pearl and Aqueous are upstreamed at `Seafoam-Labs/pearl` and
   `Seafoam-Labs/Aqueous` (both carry the pinned tags `v0.3.0` and `v1.0.5`); DinitUI and DINXPanel
   have no standalone repository at all — their source is in-tree under `distro/packages/` on the
   Linux line. So `make fetch` fails for all four ports.
2. `Makefile.deetty` and `Makefile.dinted` fetch release assets from `rufl/DEETTY` and `rufl/DINTED`;
   both repositories exist but publish no releases and no tags, so those download URLs are
   unreachable.
3. No port ships a `distinfo`, so no port verifies a checksum. The Linux recipes pin every source by
   SHA-256 through `source.env`.
4. The BSD ports build upstream unpatched. Every Linux behavioural change is missing on BSD: Dinit
   service supervision and the three-workspace default in Aqueous (`dinit.patch`,
   `two-default-workspaces.patch`), GLES2 rendering (`gles2-renderer.patch`), server-side
   decorations (`server-decorations.patch` on both Aqueous and Pearl), the titlebar text and live
   lock policy (`titlebar-text.patch`, `live-session-lock.patch`,
   `client-maximize-readiness.patch`), Deetty product identity and the `dintor` rename
   (`product-identity.patch`), and Deetty→terminal exec wiring (`deetty-terminal-exec.patch`,
   Pearl `deetty-terminal.patch`).
5. `packages.txt` disagrees with the ports it lists: `x11-wm/dinxpanel` against `CATEGORIES= x11`
   and `x11-wm/dinx-live-autologin` against `CATEGORIES= sysutils`.
   `security/opensnitch-ui` has a port but no manifest entry, and OpenSnitch was retired from the
   Linux payload.
6. `Makefile.aqueous` declares `LICENSE= MIT` while the Linux recipe declares
   `GPL-3.0-only/MIT/0BSD/CC-BY-SA-4.0`; `Makefile.pearl` declares `MIT` where the Linux recipe
   declares `LicenseRef-Pearl-Unlicensed`. Licensing metadata must be reconciled before a BSD
   release.
7. `BUILD_DEPENDS` pins `zig>=0.13.0` in the Deetty, DinitUI, DINXPanel, Pearl and DintEd ports, but
   the Linux recipes require `zig>=0.17` and Pearl requires exactly 0.16.0. The ports would build
   against a Zig that the source rejects.
8. `scripts/check_dinx_bsd.sh` only asserts that each Makefile exists; nothing on this branch builds
   a port, so a broken `MASTER_SITES` or an unbumpable `PORTVERSION` passes the gate.

Fixes should be committed per tool: correct the fetch target, add `distinfo`, then add the patch set
and bump `PORTVERSION`/`PORTREVISION` in the same commit.

## Rules for this line

- One port per component, named `Makefile.<PORTNAME>`, and add it to
  `distro/bsd/config/packages.txt` as `category/name` in the same commit.
- `CATEGORIES` in the Makefile must match the manifest entry exactly; the manifest is what the
  installer resolves.
- `MASTER_SITES` must point at a real, tagged release, and every port needs a `distinfo` with the
  SHA-256 of its distfile. Never fetch a floating branch.
- A DINX edit to foreign source is a patch under `files/` for that port, applied by the ports
  framework. Keep the same patch content as the Linux `.patch` so one rebase updates both lines.
- Bump `PORTVERSION` for an upstream move and `PORTREVISION` for a patch or dependency change;
  record both in `CHANGELOG.md` and `CHANGELOG.pt-BR.md`.
- Keep Zig minimums aligned with the Linux `makedepends`, and Pearl's exact pin.

## Linux parity checklist

A change here that users can see needs the matching change on `dinxtools/main`:

1. Update `distro/packages/<name>/PKGBUILD` and `source.env` (pin, SHA-256, `pkgrel`).
2. Apply the same patch content there as `distro/packages/<name>/<name>.patch`.
3. Run the Linux gate for that package (`scripts/check_dinitui.sh`, `scripts/check_dinxpanel.sh`,
   `scripts/check_deetty_integration.sh`, `scripts/check_wizp_package.sh`,
   `scripts/check_aqueous_pearl.sh`) plus `scripts/check_dinx_bsd.sh` here.
