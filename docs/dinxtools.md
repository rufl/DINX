# DINX internal tools, ports and downstream patches

[English](dinxtools.md) · [Português (Brasil)](pt-BR/dinxtools.md)

`dinxtools/*` is the maintenance line for software DINX builds, patches or packages itself: the
first-party tools (DinitUI, DINXPanel, Deetty/Dintor, WIZP) and the downstream patch sets for
third-party sessions (Aqueous, Pearl). It exists to keep one inventory of every DINX-owned change
and the rule that applies to it.

The line is split in two branches, one per delivery target:

| Branch | Base | Packaging path |
| --- | --- | --- |
| `dinxtools/main` | `main` | Arch/Artix recipes under `distro/packages/<name>/` |
| `dinxtools/bsd` | `feature/dinx-bsd` | FreeBSD port Makefiles under `distro/bsd/ports/` |

The two lines are not merged. `main` and `feature/dinx-bsd` diverged (71 commits only on the BSD
side, 169 only on the Linux side) and both CHANGELOGs, `scripts/build-iso-container.sh` and
`scripts/check-iso-content.sh` were edited on both sides, so a merge conflicts on every shared
file. Changes land on one branch first, then move to the other by cherry-pick or by hand.

## Inventory (Linux, this branch)

| Tool | Kind | Authoritative source | DINX recipe | Gate scripts |
| --- | --- | --- | --- | --- |
| DinitUI | first-party, GTK4/libadwaita + Zig | `distro/packages/dinitui/src/` (in-tree) | `distro/packages/dinitui/PKGBUILD`, `source=()` | `scripts/check_dinitui.sh`, `scripts/dinitui_dinit_qualification.sh` |
| DINXPanel | first-party, GTK4/libadwaita + Zig | `distro/packages/dinxpanel/src/` (in-tree) | `distro/packages/dinxpanel/PKGBUILD`, `source=()` | `scripts/check_dinxpanel.sh` |
| Deetty + Dintor | first-party upstream fork + patches | `rufl/DEETTY`, pinned by `DEETTY_REF` in `source.env` | `distro/packages/deetty/PKGBUILD` (0.1.0-10, `provides=('dintor')`) | `scripts/check_deetty_integration.sh`, `scripts/deetty_p2_qualification.sh`, `scripts/dintor_p3_qualification.sh` |
| WIZP | third-party build, bundled runtime | `rufl/WIZP` | `distro/packages/wizp/PKGBUILD` (needs `WIZP_PACKAGE_DIR`) | `scripts/check_wizp_package.sh` |
| Pearl | third-party + patch set | `Seafoam-Labs/pearl` tag `v0.3.0` pinned by SHA-256 | `distro/packages/pearl/PKGBUILD` (1 epoch, 0.3.0-11) | `scripts/check_aqueous_pearl.sh` |
| Aqueous | third-party + patch set | `Seafoam-Labs/Aqueous` tag `v1.0.5` + `wlroots` 0.20.2 pinned | `distro/packages/aqueous/PKGBUILD` (1.0.5-14) | `scripts/check_aqueous_pearl.sh` |
| Pearl/GTK theme ports | forks + generated assets | `rufl/skeuos-gtk`, `rufl/Orchis-theme` | `distro/packages/dinx-pearl-themes`, `distro/packages/dinx-gtk-themes` | `scripts/check-iso-content.sh` (paths + package metadata), `scripts/check_dinx_theme.sh` (DINX session theme) |

Dintor is not a separate package: it is the editor binary produced by the Deetty build
(`product-identity.patch` renames upstream `nocted` to `dintor`) and is published through
`provides=('dintor')`. The ISO gate requires `usr/bin/dintor`, `usr/share/dintor/language-specs/`
and `usr/share/dintor/styles/`. DintEd (`editors/dinted`) is a different editor and only exists as
a BSD port; see the BSD branch.

## Downstream patch sets

Every DINX-owned edit to foreign source is a `.patch` next to its PKGBUILD, applied in `prepare()`
with `--fuzz=0` so an upstream drift fails the build instead of silently shifting hunks.

Aqueous (`distro/packages/aqueous`, applied in this order):

1. `dinit.patch` — drops `libsystemd` linkage from the compositor and keyboard tests (Dinit
   supervisor, no systemd), fixes `scdoc` detection and the `git describe` build-root path, and
   moves the zig-wayland dependency to a pinned 0.8.0-dev commit.
2. `gles2-renderer.patch` — builds the wlroots render hook with `-Drenderers=gles2,vulkan` so
   accessible virtio-GPU keeps GLES2.
3. `server-decorations.patch` — server-side decoration move/resize through cursor decoration
   actions.
4. `titlebar-text.patch` — links `pangocairo` and compiles the vendored `titlebar_text.c` so
   titlebars draw client titles.
5. `two-default-workspaces.patch` — ships three default workspaces instead of ten.
6. `live-session-lock.patch` — live-session lock policy in `LockManager`, with the vendored
   `live_lock_policy.zig`.
7. `client-maximize-readiness.patch` — wires the vendored `client_maximize_request.zig` into
   `CompositorApi`.

`prepare()` also installs the vendored companions the patches need into the unpacked tree
(`client_maximize_request.zig`, `titlebar_text.c`, `titlebar_text.zig`, `live_lock_policy.zig`);
`check()` compiles `titlebar_text_test.c` against the patched source, and
`scripts/check_aqueous_pearl.sh` runs `window_policy_test.zig` and `live_lock_policy.zig` on the
pinned tree. The recipe pins `AQUEOUS_WLROOTS_SHA256` for the bundled wlroots 0.20.2 archive.

Pearl (`distro/packages/pearl`):

1. `deetty-terminal.patch` — replaces the upstream terminal roster (foot/Ghostty) so Pearl launches
   Deetty.
2. `server-decorations.patch` — removes Pearl's own `HeaderBar` decoration buttons (Aqueous owns
   decorations) and adds form-draft validation so an invalid color cannot be applied.
3. `greeter-state-home.patch` — greeter state under `/var/lib/pearl-greeter/.local/state`.
4. `remove-find-your-next-thing.patch` — drops the empty launcher search heading.

`dinx-first-run-wizard.c` is compiled by the same recipe and is checked into the package directory,
not patched into upstream. Pearl requires Zig exactly `PEARL_ZIG_VERSION` (0.16.0), downloaded and
checksum-pinned by the recipe.

Deetty (`distro/packages/deetty`):

1. `product-identity.patch` — renames the `noctty`/`nocted`/`noctty-vte`/`noctty-smoke` targets to
   `deetty`/`dintor`/`deetty-vte`/`deetty-smoke` and their option descriptions.
2. `qualification-compat.patch` — exposes the `compat` module to the terminal session, fairness,
   continuity, real-TUI, ncurses and system-TUI qualification targets, installs the editor styles
   under `share/dintor/`, and renames the `NOCTTY_*` markers to `DEETTY_*`.
3. `deetty-terminal-exec.patch` — adds `quoteCommandArguments` to `LaunchProfile` so terminal exec
   arguments are POSIX-quoted and control bytes are rejected.

`pori/pori-dinit.patch` follows the same rules and is out of this line's tool list only because Pori
is not one of the tools above.

## Rules for this line

- Never edit unpacked upstream source in place. Add or update a `.patch` in the package directory,
  keep `patch --fuzz=0 --forward`, and bump `pkgrel`.
- Keep the pin and digest together: upstream URLs and SHA-256 values live in `source.env` and are
  consumed by the PKGBUILD; first-party tools (`dinitui`, `dinxpanel`) keep `source=()` because
  their source is in-tree.
- Refreshing a pin is a full change: recompute the SHA-256, rebase every patch onto the new tag,
  bump `pkgrel`, run the gate script for that package, then run the ISO content gate.
- Record every change in `CHANGELOG.md` and `CHANGELOG.pt-BR.md`.
- Before an upstream fix lands, file it upstream and keep the DINX patch as the temporary
  carry-forward; deleting a patch because upstream absorbed it is a change to note here.

## BSD parity checklist

A change on `dinxtools/main` that users can see needs the matching change on `dinxtools/bsd`:

1. Update or add `distro/bsd/ports/Makefile.<name>` so `PORTVERSION`, `CATEGORIES` and
   `MASTER_SITES` match the Linux pin.
2. Apply the same patch set; BSD ports currently build upstream tarballs unpatched.
3. Update `distro/bsd/config/packages.txt` in the same commit as the category change.
4. Run `scripts/check_dinx_bsd.sh`, which asserts each port Makefile exists.

Known gaps on the BSD line as of 2026-11-14, tracked there: `Makefile.dinitui`,
`Makefile.dinxpanel`, `Makefile.pearl` and `Makefile.aqueous` fetch from `rufl/*` repositories that
do not exist; `Makefile.deetty` and `Makefile.dinted` fetch release assets from repositories that
publish no releases or tags; no port carries a `distinfo`, checksum or the Linux patch set;
`packages.txt` lists `x11-wm/dinxpanel` and `x11-wm/dinx-live-autologin` while those Makefiles
declare `x11` and `sysutils`; `security/opensnitch-ui` still has a port although OpenSnitch was
retired from the Linux payload; WIZP has no port at all.
