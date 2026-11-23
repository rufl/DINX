# DINX ISO foundation

[English](README.md) · [Português (Brasil)](README.pt-BR.md)

This directory contains the first Artix `artools` profile for DINX and the local build entry points.

For the user-facing download, verification and boot path, see the [easy installation guide](../../docs/install.md).

## Toolchain

The profile uses Artix's `buildiso` flow, not generic `mkarchiso`. The builder must provide:

- `pacman`;
- current Artix `artools` with `buildiso` and its `yq` dependency;
- `xorriso`, `grub-mkimage`, `mksquashfs` and `mkinitcpio`;
- loop-device support;
- root privileges for chroot and mount operations.

The official P0 execution uses `.github/workflows/p0-iso.yml` on an Ubuntu runner with a privileged Artix container. For local execution, install the same dependencies and use an environment with mount/chroot support.

Run the prerequisite probe from the repository root:

```bash
scripts/check-iso-host.sh
```

Build the foundation profile:

```bash
scripts/build-iso.sh
```

Smoke-test an already-built ISO:

```bash
scripts/smoke-iso.sh dist/iso/<file>.iso
```
Smoke-test the persistent install contract on disposable BIOS and UEFI disks:

```bash
DINX_INSTALL_OUTPUT_DIR=dist/iso/dinx \
DINX_INSTALL_FIRMWARE=bios scripts/smoke-install.sh dist/iso/<file>.iso
DINX_INSTALL_OUTPUT_DIR=dist/iso/dinx \
DINX_INSTALL_FIRMWARE=uefi scripts/smoke-install.sh dist/iso/<file>.iso
```

This extracts the ISO rootfs, removes live-only packages, creates temporary ext4
disks, generates initramfs and the matching BIOS or UEFI GRUB path, boots each disk
in QEMU and captures the recovery-TTY transition. It requires root or passwordless
`sudo`, loop devices, `grub-pc-bin`, `grub-efi-amd64-bin`, OVMF, QEMU and SquashFS
tools. The disks are temporary and deleted after the smoke; this is not a substitute
for hardware qualification.


The full QEMU qualifier captures default VGA and Virtio-VGA and uses Tesseract OCR to require a River/KWM or DINX desktop marker while rejecting agreety, TTY consoles, login prompts and visible Dinit failures. Any visible compositor titlebar must name the River or KWM session stack, and the live-desktop check reads the package-owned `Install DINX` shortcut. These are live-session graphics smokes, not direct VirtualBox qualification. Local runs need `qemu-system-x86_64`, `socat`, `tesseract-ocr` and `tesseract-ocr-eng`:

The boot menu shows `Start DINX Linux`, the legacy-hardware modes below, and, on UEFI systems, `Boot to the Firmware/BIOS`. DINX is the default and boots after a visible six-second countdown. Legacy BIOS has no UEFI firmware-setup option. Full QEMU qualification leaves the menu untouched to verify the countdown.

The live menu offers four boot modes for legacy hardware: `Start DINX Linux` (stock `quiet splash`), `(compatibility)` = `noapic irqpoll` for machines that stall at `do_IRQ: ... No irq handler for vector` (AMD E-350 "Zacate"/HP dm1 class), `(safe graphics)` = `noapic irqpoll nomodeset plymouth.enable=0` for a black screen during GPU modeset/splash (drops to the text session), and `(verbose boot)` = `noapic irqpoll ignore_loglevel loglevel=8 plymouth.enable=0` to show exactly where boot stalls instead of a silent black screen. The image is a hybrid: its grub2 MBR plus an El Torito BIOS entry (`/boot/grub/i386-pc/eltorito.img`) and an appended EFI System partition make the same file boot from legacy BIOS/MBR (CD emulation, a `dd`-written USB, or the ISO attached as a disk) and from UEFI. `scripts/check-iso-boot-records.sh` asserts that layout statically; `scripts/smoke-iso-mbr.sh` proves the disk path by booting the image under SeaBIOS with no CD emulation or OVMF and selecting `Start DINX Linux (compatibility)`. Both are QEMU evidence, not physical hardware qualification.

```bash
DINX_QEMU_TIMEOUT=110 \
DINX_QEMU_SCREENSHOT=dist/iso/dinx/graphical-screen.ppm \
DINX_QEMU_SCREENSHOT_DELAY=60 \
DINX_QEMU_POST_SCREENSHOT=dist/iso/dinx/session-screen.ppm \
DINX_QEMU_POST_SCREENSHOT_DELAY=10 \
DINX_QEMU_POST_KEYS=alt-f4 \
scripts/smoke-iso.sh dist/iso/<file>.iso
```

The smoke also checks the captured session frame. If the original frame contains no OCR-readable text, it enlarges the top panel before checking the desktop marker. Without `DINX_QEMU_SCREENSHOT`, it saves the checked PPM beside the QEMU log as `<iso>.qemu.log.session.ppm`; `DINX_QEMU_OCR_LANG` selects another installed Tesseract model.

`build-iso.sh` copies Artix's `artools` data into a private temporary tree and patches its copied initramfs helper to add `vmwgfx` and `vboxvideo` immediately before Artix runs `mkinitcpio`; it does not modify the host installation. `check_artix_initcpio_patch.sh` guards this contract, and `check-iso-content.sh` requires `bsdtar` and verifies both modules inside the ISO's actual boot initramfs. QEMU 11.1.2/KVM's `vmware-svga` test stalls in early udev when `vmwgfx` loads, so the full gate uses Virtio-VGA; real VirtualBox boot remains a separate manual qualification.


Check the graphical payload inside the root SquashFS image:

```bash
scripts/check-iso-content.sh dist/iso/<file>.iso
```

Extra `buildiso` options are passed through unchanged. For example, query settings without building:

```bash
scripts/build-iso.sh -q
```

The default output directory is `dist/iso`; override it with `DINX_ISO_OUTPUT`. The chroot cache defaults to `/var/lib/artools/buildiso`; override it with `DINX_ISO_CHROOTS` when the builder uses another persistent volume.
## ISO size target

The build wrapper prepends `scripts/iso-tools/mksquashfs` to the builder `PATH`.
It forces xz-compressed SquashFS images with x86 BCJ, 1 MiB blocks and a 1 MiB
dictionary; both are the maximum supported SquashFS sizes. `mksquashfs` exposes no XZ level control, so its tool default remains. Artix keeps `linux-headers` until it
generates the initramfs, then the wrapper transactionally removes `linux-headers`
and its build-only dependency `pahole` from each staged package root before compression.
The ISO content check rejects either package from final package databases. Kernel sources, pacman package caches
and build logs are also excluded. The root overlay recreates `/var/log/dinit`
through tmpfiles before Dinit services start, and the ISO-content check requires
that rule. The livefs-only `dinx-live-autologin` package supplies no-op `root-ro`
and `early-root-rw.target` units for its writable overlay; these overrides are not
included in the Calamares-installed rootfs. The live rootfs includes `squashfs-tools`
because Calamares `unpackfs` requires `unsquashfs`; the install contract removes it
from the installed root. The builder keeps its own copy. CI installs the wrapper at
`/usr/bin/mksquashfs` after preserving the real binary, because Artix `buildiso`
may invoke that absolute path. Build-only package pruning uses an isolated
minimal pacman config so absolute includes from staged `/etc/pacman.conf` do not
resolve on the builder host. Assembly fails if Artix does not produce a
nonempty `/LiveOS/rootfs.img`; post-build inspection checks both SquashFS
superblocks for xz compression and 1 MiB blocks.
The P0 budget rejects ISOs at or above GitHub's 2 GiB asset limit; Alpha 12 is
1,836,830,720 bytes (310,652,928 bytes below the limit).

## Graphical profile

`iso-profiles/dinx/profile.yaml` includes river, kwm, kwim, morghulis, dinx-dock, dinx-first-run, greetd with agreety and the native `deetty` package. Deetty is the sole terminal emulator in both the live and installed root filesystems. The ISO's `ghostty-vt-runtime` package contains only the VT library, headers and license needed by Deetty, not the Ghostty terminal application. The DINX `kwm` and `kwim` packages supply the tiling layout and the input manager, `morghulis` supplies the desktop shell, and `dinx-dock` and `dinx-first-run` supply the launcher bar and the first-run appearance wizard; `deetty` installs Deetty and Dintor, including desktop files, icons, language specifications and the dark editor style. CI consumes the generated source archive from the exact commit and SHA-256 contract declared in `distro/packages/deetty/source.env`, from `https://github.com/rufl/DEETTY.git`. The root overlay supplies `/etc/greetd/config.toml` and hidden session metadata; `River + KWM + Morghulis (DINX)` is the only user-session entry.
The livefs adds the live-only `dinx-live-autologin` dinit package. Its preparation service sets the `dinxlive` hostname, grants the disposable `dinx` account access to the live `seatd` service, waits for its socket and provisions the private `/run/dinx-session` runtime directory; a separate restartable process service then launches the session as `dinx` through `dbus-run-session /usr/local/libexec/dinx-river-session`, and the overlay shadows greetd with a no-op unit so no display manager enters the live boot. The package also supplies no-op root-remount units for the already-writable live overlay. These overrides stay in `livefs`; Calamares installs `rootfs.img`, which retains Artix's generic root-remount units. The one session wrapper serves both paths, applies the graphics policy below and picks the libseat backend at runtime: `seatd` when `/run/seatd.sock` exists and the session user belongs to the `seat` group, `logind` (elogind) otherwise — elogind under dinit registers the session but never marks it active, which previously left a compositor waiting for a DRM session until timeout. The installed greetd service keeps `smooth-recovery` and its seven-second restart delay so a retry cannot contend with a session that is still closing.

The `greeter` account that greetd drops to has `HOME=/`, so the greeter needs only a writable cache: `/etc/greetd/config.toml` runs `agreety` with `XDG_CACHE_HOME=/var/cache/agreety`, and the boot tmpfiles provision that directory with mode 0700 owned by `greeter`. agreety keeps the last chosen session there; DINX provisions no greeter configuration, data or state tree.


`iso-profiles/dinx/feature-groups.json` records the foundation, desktop, gaming, hardware and optional package groups without replacing Artix's `profile.yaml`. The CI builder signs every locally built package and the temporary `dinx` repository database with an ephemeral key, checks package signatures and duplicate archive paths, and records the immutable package snapshot in `build-metadata.txt`. This is build qualification only; the production pacman repository key and installed-system update channel remain separate release prerequisites.

The source tree configures a weekly upstream-pin refresh at Monday 04:17 UTC.
It opens one reviewed PR for 23 custom-package source pins, including a
monthly-refreshed Noto Latin subset; the private Deetty commit and
ZLS/Zig 0.16 pins remain manual. After merge, a separate signed package-only
workflow publishes packages to the GitHub Release tag `dinx-packages-latest`,
without ISO assembly. These workflows are configured but have not yet been
confirmed green or published. `dinx-keyring` configures the required-signature
`[dinx]` repository and editable `/etc/pacman.d/dinx-mirrorlist`; pacman updates the
packages, with Octopi as the graphical front-end. See the [release guide](../../docs/release.md)
for signing-secret setup and manual key verification/bootstrap.

DINX packages are built as signed binary `.pkg.tar.zst` archives. One `deetty`
package contains the precompiled Deetty terminal and Dintor editor. Binary
AppImage apps (PaintFE and Patchy) are repacked at
build time by `scripts/lib/repack-appimage.sh` into pre-extracted
`/opt/<package>/` trees: ELF binaries stripped (Electron left unstripped),
locales trimmed to en/pt, and `/usr/bin/<package>` launchers exec the tree's
`AppRun` directly — no FUSE and no per-launch tmpfs extraction. Audionaut ships
as a single `/opt/audionaut/Audionaut.AppImage` whose `/usr/bin/audionaut` launcher runs
it with `--appimage-extract-and-run` rather than a pre-extracted tree. EuroOffice
ships as a lean repack published by the office branch. Local and P0 builds
restore verified package archives keyed by package source, recipe, builder
environment and installed dependency set; a cache miss rebuilds the package.
This avoids recompiling cache hits while retaining pinned inputs and signature
verification.

The ISO includes ZLS for Dintor's Zig LSP integration. Vim remains a
builder-only qualification tool. Clang/clangd also qualify the generic LSP
client in the builder, but the `clang` package remains in the runtime because
Blender's `openshadinglanguage` dependency requires its libraries.

Before SquashFS compression, the wrapper runs fail-closed `pacman -Rns`
transactions on rootfs and livefs for installed excluded package roots:
`breeze`, `breeze-cursors`, `dhcpcd`, `dhcpcd-dinit`, `ex-vi-compat`,
`linux-headers`, `man-db`, `man-pages`, `pahole`, `plasma-integration`,
`plasma-workspace`, `qogir-icon-theme`, `qqc2-breeze-style`, `texinfo`, `vim`,
`vim-runtime` and `xdg-desktop-portal-kde`. `pahole` is removed only when
kernel headers are present. `breeze-icons` remains because Calamares → KParts
→ KIO → KIconThemes requires it, even though Papirus is the selected desktop
icon theme.

The profile owns static DINX visual bridges: `/usr/share/dinx/theme/DINX.json` is the source for semantic and ANSI colors; GTK and Qt consume checked-in DINX theme files, and `DINX_COLOR_SCHEME` is the user-session color contract. `qt6ct`, `adw-gtk-theme` and `dinx-noto-latin` are installed for the corresponding consumers, matching CachyOS's default GTK typography. The custom package provides Noto Sans 10 regular/bold/italic/bold-italic and Noto Sans Mono 10, subset to Latin, combining marks, common punctuation and currency; it replaces the full `noto-fonts` package. DINX ships a selectable appearance — the DINX dark scheme is the default, and the first-run wizard records the chosen family, variant, corner style and placement in `~/.config/dinx/appearance.json` — and `River + KWM + Morghulis (DINX)` owns the only user-session contract. `scripts/check_dinx_theme.sh` validates this contract before the ISO build.

`dinx-gtk-themes` 1.1.0 installs the ported GTK themes under `/usr/share/themes`: Orchis-Light/Dark and Orchis-Square-Light/Dark compiled from the fork's SASS with 12 px and 0 px corners, Skeuos-Blue-Light/Dark and their `-Square` variants built from the pinned upstream prebuilts with corner radii zeroed (circular controls keep their shape), plus Fluent-Light/Dark, Fluent-Square-Light/Dark, Jasper-Light/Dark and Jasper-Square-Light/Dark, sixteen theme directories in all. The ports are published in the `rufl/skeuos-gtk`, `rufl/Orchis-theme`, `rufl/Fluent-gtk-theme` and `rufl/Jasper-gtk-theme` forks and pinned by commit in `distro/packages/dinx-gtk-themes/source.env`. The DINX GTK theme remains the session default; the other families are selected through the first-run wizard and recorded in `~/.config/dinx/appearance.json`.

DINX applies the appearance saved by its first-run wizard, `dinx-first-run`, which the supervisor runs through `/usr/local/libexec/dinx-desktop-first-run` before the shell starts, once per account behind the `~/.local/state/dinx/desktop-first-run-complete` marker. It asks for language (pt-BR/en-US), location (America/Sao_Paulo or UTC), theme family (DINX, Skeuos, Orchis, Fluent or Jasper), dark or light, rounded or square corners, bar top or bottom and dock left, right, bottom or none; it then writes `~/.config/dinx/appearance.json` and `~/.config/dinx/installer-preferences.json`, sets the Morghulis `navbar-anchor` GSettings key and reloads the dock over SIGHUP. `dinx-river-session` exports the dark recovery defaults (`DINX_COLOR_SCHEME=dark`, `DINTOR_THEME=prefer-dark`), sets `QT_QPA_PLATFORMTHEME=qt6ct`, no longer exports `GTK_APPLICATION_PREFER_DARK_THEME` or `ADW_DEBUG_COLOR_SCHEME`, and never forces `GTK_THEME`, so applications keep their own theme selection. The `dinx-sync-session-theme` helper then aligns the toolkits once a session bus exists: it maps the saved family, variant and corner style onto the shipped `/usr/share/themes` names, for example `Jasper-Square-Light`, and writes that `gtk-theme-name` with the matching dark preference into the GTK 3/4 user settings, the matching `prefer-dark` or `prefer-light` dconf color scheme and the DINX qt6ct palette with `custom_palette=true` only for the dark variant, preserves unrelated toolkit settings, and seeds the same Qt6ct config and palette for an existing home that lacks them; a missing or invalid `appearance.json` falls back to DINX dark. `dinx-gtk-themes` substitutes the port palette primary over the raw upstream accent hexes so the DINX theme and the ported themes share identical accents.

The agreety login surface and the initial desktop use solid backgrounds without wallpaper images or a DINX logo; Calamares retains the full wordmark on its product logo/welcome surface. The reduced D-and-ray symbol remains canonical artwork at `design/brand/dinx-ray-mark.svg` and is used by Calamares as its product icon. GRUB uses the separate gradient boot-mark PNG. Papirus is the only explicitly selected desktop/app-launcher icon theme; Qogir, Breeze style and cursor packages are excluded, while the Breeze icon package remains for Calamares's KIconThemes dependency. Upstream application icons remain unchanged, and Adwaita assets remain available for GTK compatibility.
The Morghulis NavBar is the DINX status surface; kwm is built `-Dbar=false`, so KWM's own bar is not the status surface anymore. KWM reads only `~/.config/kwm/config.zon`, and `dinx-river-session` seeds that file from the packaged `/etc/xdg/kwm/config.zon` when it is absent, so later user edits survive every reboot. The first-run wizard stores the saved shell theme selection in `~/.config/dinx/appearance.json`, and its `dock` value decides whether `dinx-dock` starts: `none` leaves the launcher bar stopped, while a missing file defaults to `left`.

The DINX overlay ships a system-wide `/etc/xdg/kwm/config.zon` that defaults every
window to floating: `default_layout = .float` plus a global window rule
`.{ .app_id = .{ .str = "", .match_null = true }, .floating = true }`, so all
windows float, stack and can be dragged around like the retired Aqueous/Pearl
stacking desktop. `Mod4-f` toggles a window between floating and the tile layout,
`Mod4-Ctrl-f` switches the active layout, `Mod4-t` switches to tile, and
`Mod4`+left-drag moves / `Mod4`+right-drag resizes floating windows; `Mod4-Ctrl`+h/j/k/l
nudges a floating window toward a screen edge. `dinx-river-session` seeds
`~/.config/kwm/config.zon` from this file only when the user config is absent, so
user edits survive every reboot.
The ASCII D-ray at `/usr/share/dinx/branding/dinx-ray-mark.txt` is density-mapped from DINX's source SVG and works as a plain-text logo:
```sh
fastfetch --logo-type file --logo /usr/share/dinx/branding/dinx-ray-mark.txt
```
Areofyl's [`fetch`](https://github.com/areofyl/fetch) also accepts it as a custom logo:
```sh
mkdir -p ~/.config/fetch
cp /usr/share/dinx/branding/dinx-ray-mark.txt ~/.config/fetch/logo.txt
```
Add these lines to `~/.config/fetch/config` for DINX coral:
```ini
logo_outer=38;2;244;81;91
logo_inner=38;2;244;81;91
```
Fastfetch and Areofyl's `fetch` are optional and are not included in the base ISO.

The profile includes the experimental Calamares installer and GParted for standalone partition editing. Calamares copies the ISO root filesystem offline, keeps dinit as the installed init system, and removes the live-only Artix packages during installation. The base image carries the kernel `ntfs3` driver for NTFS read/write access and `os-prober` for Windows discovery; legacy `ntfs-3g` remains an optional post-install package in the signed extra channel. Existing Windows ESP/NTFS layouts are preserved by the installer and use a separate DINX EFI directory.

agreety, the River/KWM session and the installer receive DINX defaults from the root overlay. Calamares uses the DINX surface/text/primary/error tokens in its Qt stylesheet. DINX builds Calamares 3.4.3 from a checksum-pinned upstream release without Artix's `plasma-integration` dependency. The signed DINX package repository is ordered before Artix during rootfs resolution, and the ISO gate verifies that the DINX Calamares package was selected. The remaining `breeze-icons` dependency is not a Plasma session component: Calamares uses KParts, which uses KIO, which requires KIconThemes, whose Artix package depends on Breeze icons. The desktop still selects Papirus; unused Plasma integration/workspace/portal packages and Breeze style/cursors are removed. River is the active compositor and KWM the active window manager; there is no dedicated greeter host and no user-session fallback. Unsupported session entries remain hidden, and `River + KWM + Morghulis (DINX)` is the live session. The live session exposes `Install DINX` through its own launcher. The root overlay replaces the package's `/usr/share/applications/calamares.desktop` with a `Hidden=true`, `NoDisplay=true` tombstone that has no Artix name or executable. The DINX helper starts Calamares through `pkexec` with the live Wayland runtime/display and reports launch/authorization failures in a dialog. The live desktop shortcut is executable from first boot, and the session wrapper seeds the DINX desktop-launcher approval store only for the exact package-owned shortcut URI and SHA-256 digest; modified files and symlinks remain unapproved.
The live path uses `River + KWM + Morghulis (DINX)` without a credential prompt: a live-only dinit service prepares the live session and greetd stays installed-only. The installed rootfs keeps manual login through agreety and Calamares keeps both autologin flags disabled.
In the livefs, a PolicyKit rule authorizes Polkit-mediated privileged actions without a password only for the fixed disposable user `dinx`. Direct Dinit startup has no elogind `active` or `local` session state, so the rule deliberately does not depend on those flags. It covers Calamares and GParted root launch, Firewalld D-Bus configuration, and other live-session administrative tools. GParted uses its upstream Polkit launcher, while firewall-config remains an unprivileged UI and authorizes changes through Firewalld. The rule is excluded from `rootfs.img`, so installed systems retain their normal authentication policy. This deliberately gives users of the disposable live session root-equivalent access.

GTK 3/4 system and skeleton defaults use Adwaita with `gtk-application-prefer-dark-theme=1`, the Papirus icon theme, Noto Sans 10 and the `:minimize,maximize,close` decoration layout. The `dinx-sync-session-theme` helper applies the saved appearance to dconf, the GTK 3/4 user settings and Qt6ct on top of those defaults: the `gtk-theme-name` chosen in the first-run wizard, DINX when nothing is saved, GTK's dark or light preference and the DINX Qt palette for the dark variant. Unrelated toolkit settings are preserved and a user-managed settings symlink is never replaced. Windows that negotiate server-side decorations receive the compositor's DINX titlebar; clients that keep client-side decorations are not decorated twice. The session supervisor starts KWM as river's required `river-window-management-v1` implementation before any view is mapped, so placement is river/KWM's own and no compositor corner-radius or border-sync setting exists.


The runtime payload is Wayland/XWayland only: legacy Xorg/XLibre servers, drivers and Plasma session entries are omitted. Xvfb remains builder-only for package qualification.
For storage, Pori is the DINX disk/mount manager and PCManFM is the default file manager. File Roller provides graphical archive actions and GParted provides standalone partition editing outside Calamares. Pori uses UDisks2 for block-device discovery and creates persistent scripted mount services under `/etc/dinit.d`; it does not use systemd units. The base image does not install Thunar, GVFS, Tumbler or KDE Partition Manager. PCManFM handles directory browsing and renders the `~/Desktop` icons through `pcmanfm --desktop`; the standalone LXQt PolicyKit agent remains for privileged actions, and the River/KWM session remains the active desktop.
For display setup, DINX's `dinx-wdisplays` wrapper opens the interactive Wayland editor; closing it atomically replaces the named `DINX wdisplays` profile in `~/.config/shikane/config.toml` and reloads the Shikane user daemon. Shikane starts inside the River/KWM session and reapplies matching profiles when outputs change. DINXPanel's `Display` action opens the same wrapper, and `dinx-save-shikane-profile` saves the current layout without reopening the editor. River and KWM are the only selectable session components.

For web browsing, the profile installs Artix's `firefox` package and makes it the default HTML/XHTML/HTTP/HTTPS handler. Firefox updates come from the Artix package sources through the existing reviewed package-source refresh; DINX ships no browser policy file and Mozilla account sign-in remains optional.
The profile also ships btop/nvtop/inxi, PCI and USB diagnostics, Git/curl/less/jq/rsync, Swayimg, Haruna, Gapless (G4Music), Galculator, `wl-clipboard`, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor`, `fwupdmgr`, the Flatpak runtime, PCManFM, Octopi, `pacman-contrib`, PaintFE, Krita, Inkscape, Godot, Pixelorama, Patchy, Blender (3D creation suite), Audionaut (multitrack audio editor and recorder) and EuroOffice (documents, spreadsheets, presentations and PDFs; default `application/pdf` and OOXML handler). Krita, Inkscape, Pixelorama and PaintFE provide raster and vector graphics editing; Godot is the game engine and Blender is the 3D creation suite. PaintFE and Patchy are version-pinned upstream AppImages repacked at build time into pre-extracted `/opt/<package>/` trees (ELF stripped where safe, locales trimmed to en/pt) whose `/usr/bin/<package>` launchers exec `AppRun` directly, so neither FUSE nor per-launch tmpfs extraction is required; Audionaut is a version-pinned upstream AppImage kept as the single `/opt/audionaut/Audionaut.AppImage` that its `/usr/bin/audionaut` launcher runs with `--appimage-extract-and-run`, and Blender and PCManFM come from the Artix repositories; EuroOffice arrives as the office branch's lean SHA256-verified pacman package plus /-rooted live squashfs. PaintFE ships the upstream MIT text, Patchy ships its upstream MIT text and Audionaut ships the upstream `LICENSE.md`; each package also carries a `usr/share/doc/<package>/SOURCE` provenance record naming the pinned upstream tree, and PaintFE and Pixelorama install the upstream 256x256 application icon. The ISO content gate requires those license and icon paths; each recipe still writes the `usr/share/doc/<package>/SOURCE` provenance record, which the squashfs wrapper removes from the final images together with the rest of `usr/share/doc`. Patchy defaults its own Qt color-scheme preference to dark on first launch while preserving later user theme choices. Pixelorama uses its checksum-pinned official Linux x86_64 release, wrapper, desktop entry, icon, MIT license and `.pxo` MIME registration. Galculator is a compact GTK 3 calculator using the existing GTK stack, with no separate GUI toolkit added. Gapless is built from pinned upstream v4.6.2 with GStreamer base/good codec support and gapless playback enabled by default. It supports MPRIS media controls. Swayimg is built from pinned upstream 5.6 with Wayland, JPEG and PNG support and remains the default image viewer. River/KWM needs no shell plugin or private shell asset; the static DINX bridges carry the appearance. No Flatpak applications are preinstalled. The retired OnlyOffice, Zrythm, Impasto, Floorp, Topgrade and ArtCraft (WordCraft/GridCraft/DeckCraft/PdfCraft) payloads are rejected by the content gate.

### Application launcher labels

Launcher names follow the desktop locale. Swayimg remains hidden from the app menu and opens associated image files. The original Artix Calamares desktop ID is replaced with an inert tombstone; only the functional DINX installer shortcut is exposed.

| App | English | Português (Brasil) |
| --- | --- | --- |
| DinitUI | Services | Serviços |
| DINXPanel | Control Center | Central de Controle |
| Dintor | Editor | Editor |
| Pori | Disks & Mounts | Discos e Montagens |
| PCManFM | File Manager | Gerenciador de Arquivos |
| Display setup | Display Settings | Ajustes de Tela |
| Octopi | Add/Remove Software | Adicionar/remover programas |
| Galculator | Calculator | Calculadora |
| GParted | Partition Editor | Particionador |
| PaintFE | Image Editor | Editor de Imagens |
| Firefox | Web Browser | Navegador Web |
| Krita | Digital Painting | Pintura Digital |
| Inkscape | Vector Graphics | Gráficos Vetoriais |
| Godot | Game Engine | Motor de Jogos |
| Pixelorama | Pixel Art & Animation | Arte de Pixel e Animação |
| Patchy | Image Editor | Editor de Imagens |
| Blender | 3D Modeler | Modelador 3D |
| Swayimg | Image Viewer | Visualizador de Imagens |
| EuroOffice | Office & PDF Editors | Suíte de Escritório e PDF |
| Audionaut | Audionaut | Audionaut |
| Gapless | Music Player | Tocador de Música |
| Haruna | Media Player | Tocador de Mídia |
| Blueman | Bluetooth | Bluetooth |
| Network connections | Network Connections | Ajustes de Rede |
| pwvucontrol | Audio Control | Ajustes de Áudio |
| File Roller | Archive Manager | Descompactador |
| DINX installer | Install DINX | Instalar DINX |
| Firewall configuration | Firewall | Firewall |

CUPS is intentionally outside the offline profile. After installation,
DINXPanel offers the fixed `cups-dinit` download from the configured Artix
repository; the package pulls CUPS and provides the `cupsd` dinit service.
The package-management payload adds `paru`, Octopi and `pacman-contrib` alongside Artix's own `pacman`. paru is built from its pinned source release against Artix ALPM; Octopi is built from its pinned upstream tagged release and elevates through `pkexec` and polkit with `lxqt-policykit-agent`, because DINX ships no sudo, and `pacman-contrib` provides `checkupdates` for read-only update discovery. Octopi has no command-line interface: it is the interactive GUI reached from DINXPanel's `Package manager` button and from the dock. Their package metadata has no `systemd` dependency or unit, no Arch repository is added, and AUR recipes remain subject to review. None starts automatically at boot.
For gaming, the `gaming` feature group has `iso:false`; Gamescope, Steam, Steam device rules, GameMode, MangoHud and 32-bit libraries are excluded from the base rootfs/livefs. The base profile retains AMDGPU and Intel GPU firmware, 64-bit Mesa RADV and Vulkan tools. P0 no longer enables Artix's `[lib32]` repository for ISO assembly; users can opt in after installation using the steps in [`docs/install.md`](../../docs/install.md). No Arch repository is added.
AMDGPU firmware, Mesa RADV and Vulkan tools remain generic AMD graphics support in the base profile. The BC-250-only Cyan Skillfish governor, its dinit package and BC250 Control Center are not installed in the generic live or installed root. CI keeps the pinned packages in the signed DINX repository.
Install those packages only after `lspci -n -d 1002:13fe` confirms the device; configure the signed DINX repository and follow the guarded steps in [`docs/install.md`](../../docs/install.md#optional-bc-250-support).
The compact ISO ships AMDGPU and Intel GPU firmware, Mesa RADV and Vulkan tools for generic graphics, while omitting the broad `linux-firmware` bundle and `powertop`. `linux-headers` remain in the Artix build root only until initramfs generation, then `linux-headers` and its build-only `pahole` dependency are removed before rootfs/livefs SquashFS packaging. exFAT uses `exfatprogs` with the kernel driver; NTFS uses the kernel `ntfs3` driver.
The firewall payload includes Firewalld and firewall-config. Firewalld uses a Dinit service enabled in both live and installed root filesystems; live autologin waits for Firewalld's startup attempt but still proceeds if it fails. The live-only PolicyKit rule allows firewall-config to manage Firewalld without a password; installed systems keep Firewalld's normal authentication policy. Firewalld is the image's filtering mechanism. UFW, Gufw and Portmaster are not shipped.

DinitUI installs `normal`, `lite` and `gaming` system-service profiles and supports custom profiles at `~/.config/dinx/dinitui/profiles.conf`. `lite` only disables optional Bluetooth; Gaming enables Bluetooth for controllers. Built-in profiles do not alter Firewalld. The standalone launcher enters Gaming and restores the previous profile on exit; entry or restoration failures stop the launcher and remain visible. DINXPanel owns the visible hardware and driver actions, fixed control-panel shortcuts, the read-only `checkupdates`/`paru -Qu` upgrade report, the Octopi package-manager and PaintFE launch shortcuts, optional fwupd discovery and the safe Artix kernel installer; River/KWM does not require a shell plugin.
agreety under greetd provides the installed login surface and launches the session through `/usr/local/libexec/dinx-river-session`. River/KWM is the sole user session.
### Session safety, hierarchy and resource guard

In the live session, `swayidle` and `wlopm` power off all displays after 600 seconds idle and before suspend, then restore them on input or resume. `dinx-lock` refuses to lock the live session and the desktop lock launcher is hidden for the live user, because a locked disposable seat is unrecoverable without a reboot. Installed sessions retain `swaylock` for idle and suspend locking, with explicit locking through `dinx-lock` and DINXPanel. Standard brightness keys and DINXPanel use fixed 5-percent `brightnessctl` steps; specialist tools remain in the launcher.

`scripts/check_dinx_budget.sh` keeps the current profile at 120 of 128 rootfs package entries and at or below 23 dinit startup entries, caps built DINXPanel/DinitUI binaries at 6 MiB each, limits the QEMU boot qualification window to 120 seconds, and enforces a built ISO below 2 GiB (`2147483647` bytes) when `DINX_ISO_PATH` is supplied. Passing the package-count budget does not guarantee the ISO-size budget; the final artifact must pass both. These are regression ceilings, not measured hardware performance claims. `scripts/measure_dinx_session.sh` records RSS/CPU snapshots from `/proc` when a DINX session is actually running.

The Artix builder still consumes one `profile.yaml`; the feature-group manifest is a contract, not a package-composition mechanism. The generic ISO profile contains the foundation and desktop groups while gaming and BC-250-specific packages remain outside the base image. DinitUI's Normal/Lite/Gaming service policies continue to provide runtime service separation.

The P0 content gate requires the root and live-session SquashFS images to contain the expected compositor, shell, greeter, session, Deetty as the sole terminal emulator, Nano recovery editor, Pori dinit storage manager, PCManFM file manager, kernel `ntfs3` support, fwupd firmware tooling, Flatpak runtime, the PaintFE, Krita, Inkscape, Godot, Patchy, Blender and Audionaut graphics apps, the EuroOffice office/PDF suite, Octopi, Firefox, and dinit payloads. It rejects KolourPaint binaries, launchers and package metadata, the retired OnlyOffice/Zrythm/Impasto/Floorp/Topgrade/ArtCraft payloads, and optional gaming binaries and metadata, in both images. `scripts/check_desktop_packages.sh` and `scripts/check_pori_storage.sh` verify package/profile contracts before the build. `scripts/smoke-install.sh` exercises the offline contract on ephemeral BIOS/UEFI disks, checks the dinit first boot and enables recovery TTYs. The workflow's PPM capture is visual evidence to inspect, not arbitrary hardware qualification.

The installed runtime-library check covers dynamically linked applications. The pinned upstream ZLS release is statically linked; the install smoke checks its version and selected configuration inside the target chroot instead.

The P0 live-session gate requires `AUTOLOGIN=true`, the live-only autologin dinit service and the unchanged installed-system greeter boundary.

The installed-disk BIOS/UEFI smoke also requires the captured greeter screen to show agreety's session identity together with a sign-in control and a `Password` field; service-ready logs and a valid framebuffer alone do not qualify login readiness.

The payload contract also requires `wdisplays`, `shikane` and the DINX display persistence entry points. The ZLS external source is pinned; shikane is built from its pinned upstream tagged release. Both are required and checked as part of the base ISO payload.
Requirements: a reachable rootful Docker Engine, `--privileged` and loop-device support, network access, and enough free disk for the temporary rootfs and ISO. The local build runs the same full qualification as P0 by default. It also requires the commands listed by `scripts/check-iso-qualification-host.sh full`, QEMU with the `virtio-vga` device, Tesseract's `eng` model, OVMF firmware, and `sudo` (or root). Check prerequisites before starting:
The workflow stores a separate `dinx-boot-screen.ppm` capture taken before the boot-menu keys are sent. Review this frame when qualifying the GRUB kernel-selection surface; it is the regression evidence for the removed opaque menu panel.

GRUB uses the transparent compact D-ray mark with DINX surface, foreground and primary selection colors instead of the Artix logo; Artix font assets remain in use. The opaque menu textures are disabled. The agreety login surface and the initial desktop use solid backgrounds without a wallpaper image or DINX logo; Calamares retains the full wordmark on its product logo/welcome and the compact mark for its product icon. Papirus is the only explicitly selected desktop/app-launcher icon theme; Qogir and KDE Breeze icon/style packages are excluded. Upstream application icon artwork remains unchanged.
In the current source profile, the normal live path is direct autologin; the greeter remains a fallback surface rather than a required boot step.

## Profile boundary

The common profile omits the standalone `dhclient` and `dhcpcd` clients because NetworkManager uses its built-in DHCP client by default; it also omits the Artix `vi` selector, which resolves to `ex-vi-compat` and depends on `vim`/`vim-runtime`. Nano remains the recovery editor, and Vim remains only in the isolated builder for TUI qualification. `man-db`, `man-pages` and `texinfo` are also omitted from the common rootfs; `man-db` and `texinfo` remain isolated Deetty build/qualification dependencies, not ISO runtime packages. Calamares installs the same `rootfs.img`, so the three documentation packages are absent from installed base systems too. Other common omissions are eCryptfs utilities, legacy FUSE `exfat-utils` (the ISO retains kernel-driver `exfatprogs`), BIOS-only `memtest86+` from rootfs/livefs, `mkinitcpio-nfs-utils` because NFS-root boot is not configured, unused NBD tools, `s-nail` without configured mail delivery, and Zsh because Fish is DINX's default shell. Artix artools 0.40 still requires `memtest86+` in `packages-boot`: `make_bootfs()` copies `/boot/memtest86+/memtest.bin` unconditionally. DINX does not expose it in the boot menu. No live service or application launcher selects these packages; Artix packages remain available for later installation.

A successful post-release main P0 validation is [40894570770](https://github.com/rufl/DINX/actions/runs/40894570770) on commit `bf773500965c843e014e3bc3ef8fea685e14b91b`. It passed the build, compact SquashFS payload check, QEMU boot and graphical capture, Calamares partition transaction, disposable BIOS/UEFI persistent-install and recovery-TTY smokes, metadata verification, attestation and artifact upload. The earlier UEFI marker race is fixed by ordering the marker after `early-root-rw.target`; this main run did not replace the tagged release ISO.

The current tagged release is [v0.1.0-alpha.12](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.12), validated by [workflow 41197618617](https://github.com/rufl/DINX/actions/runs/41197618617) on commit `56a814575e33bfae6215993972784f11b7dae215`. The direct ISO is 1,836,830,720 bytes with SHA-512 `ac1dbd237e484f8d61aab5438185218b13d9e23824ce671440ff67ed275ce7073b90dbcc14bc8d8f7008b2422d66e2756f1b3a88a0d5c21d8c7bbc67c9d60bf9`. Its QEMU smoke used the default VGA device; the current shared qualifier tests default VGA and Virtio-VGA. QEMU 11.1.2/KVM with `vmware-svga` stalls in early udev when `vmwgfx` loads. The source includes the VMSVGA fallback, which Alpha 12 predates; direct VirtualBox boot remains unqualified. Beta 0.1 is the next planned system milestone; physical hardware, network, audio, and other P5 boundaries remain outside the release claim.

## Build validation

A successful image build is not the release criterion. The resulting ISO requires:

1. checksum generation;
2. SquashFS content validation;
3. a VM boot and installation smoke test;
4. recovery-TTY verification;
5. network, audio, D-Bus, portal and graphics checks;
6. an install/upgrade report before it is labelled alpha.
