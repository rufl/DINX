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


The full QEMU qualifier captures default VGA and Virtio-VGA and uses Tesseract OCR to require a Pearl/Aqueous/DINX desktop marker while rejecting Pearl Greeter, login prompts and visible Dinit failures. It reads the first-run Pearl GTK4 setup window's `Dock` title, sends `Alt+F4` to dismiss it, then checks the desktop frame. These are live-session graphics smokes, not direct VirtualBox qualification. Local runs need `qemu-system-x86_64`, `socat`, `tesseract-ocr` and `tesseract-ocr-eng`:

The boot menu shows `Start DINX Linux` and, on UEFI systems, `Boot to the Firmware/BIOS`. DINX is the default and boots after a visible six-second countdown. Legacy BIOS has no UEFI firmware-setup option. Full QEMU qualification leaves the menu untouched to verify the countdown.

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

`iso-profiles/dinx/profile.yaml` includes Aqueous, Pearl, greetd and the native `deetty` package. Deetty is the sole terminal emulator in both the live and installed root filesystems. The ISO's `ghostty-vt-runtime` package contains only the VT library, headers and license needed by Deetty, not the Ghostty terminal application. The Pearl package supplies the Pearl Greeter; `deetty` installs Deetty and Dintor, including desktop files, icons, language specifications and the dark editor style. CI consumes the generated source archive from the exact commit and SHA-256 contract declared in `distro/packages/deetty/source.env`, from `https://github.com/rufl/DEETTY.git`. The root overlay supplies `/etc/greetd/config.toml`, `/etc/pearl/greeter.json` and hidden session metadata; Aqueous + Pearl is the only user-session entry.
The livefs adds the live-only `dinx-live-autologin` dinit package. It enables greetd's one-time `initial_session` for `dinx` with Aqueous + Pearl and supplies no-op root-remount units for the already-writable live overlay. These overrides stay in `livefs`; Calamares installs `rootfs.img`, which retains Artix's generic root-remount units. The greetd fallback launches `dinx-pearl-greeter-host`, applies the same graphics policy as the live session, and defaults libseat to `logind` so the greeter uses elogind under dinit.

The live greetd fallback runs as the dedicated `pearl-greeter` account, which owns Aqueous's writable state and cache directories.


`iso-profiles/dinx/feature-groups.json` records the foundation, desktop, gaming, hardware and optional package groups without replacing Artix's `profile.yaml`. The CI builder signs every locally built package and the temporary `dinx` repository database with an ephemeral key, checks package signatures and duplicate archive paths, and records the immutable package snapshot in `build-metadata.txt`. This is build qualification only; the production pacman repository key and installed-system update channel remain separate release prerequisites.

The source tree configures a weekly upstream-pin refresh at Monday 04:17 UTC.
It opens one reviewed PR for 23 custom-package source pins, including a
monthly-refreshed Noto Latin subset; the private Deetty commit and
ZLS/Zig 0.16 pins remain manual. After merge, a separate signed package-only
workflow publishes packages to the GitHub Release tag `dinx-packages-latest`,
without ISO assembly. These workflows are configured but have not yet been
confirmed green or published. `dinx-keyring` configures the required-signature
`[dinx]` repository and editable `/etc/pacman.d/dinx-mirrorlist`; Shelly uses
pacman to sync and update packages. See the [release guide](../../docs/release.md)
for signing-secret setup and manual key verification/bootstrap.

DINX packages are built as signed binary `.pkg.tar.zst` archives. One `deetty`
package contains the precompiled Deetty terminal and Dintor editor; upstream
AppImages remain prebuilt payloads inside DINX packages. Local and P0 builds
restore verified package archives keyed by package source, recipe, builder
environment and installed dependency set; a cache miss rebuilds the package.
This avoids recompiling cache hits while retaining pinned inputs and signature
verification.

The ISO includes ZLS for Dintor's Zig LSP integration. `clang`/`clangd` and
Vim are build-only qualification tools: clangd exercises the generic LSP
client against a real server, while Vim checks alternate-screen and
bracketed-paste behavior in a real TUI. Neither ships in the runtime image.

Before SquashFS compression, the wrapper runs fail-closed `pacman -Rns` transactions on rootfs and livefs for installed excluded package roots: `breeze`, `breeze-cursors`, `dhcpcd`, `dhcpcd-dinit`, `ex-vi-compat`, `linux-headers`, `man-db`, `man-pages`, `pahole`, `plasma-integration`, `plasma-workspace`, `qogir-icon-theme`, `qqc2-breeze-style`, `texinfo`, `vim`, `vim-runtime` and `xdg-desktop-portal-kde`. `pahole` is removed only when kernel headers are present. `breeze-icons` is intentionally retained: Calamares → KParts → KIO → KIconThemes requires it, even though Papirus is the selected desktop icon theme. This removes the Artix `vi` selector's Vim dependency and the unused standalone `dhcpcd` client/service adapter; NetworkManager uses its built-in DHCP client. The documentation packages are absent from both rootfs layers; `man-db` and `texinfo` remain only in the isolated builder for Deetty build/qualification. Calamares installs the same `rootfs.img`, so these packages are absent from installed base systems too. Dependencies are removed only when no retained package needs them; conflicts abort the build. The ISO content gate rejects excluded package records and the `man`/`info` executables.

The profile owns static DINX visual bridges: `/usr/share/dinx/theme/DINX.json` is the source for semantic and ANSI colors; GTK and Qt consume checked-in DINX theme files, and `DINX_COLOR_SCHEME` is the user-session color contract. `qt6ct`, `adw-gtk-theme` and `dinx-noto-latin` are installed for the corresponding consumers, matching CachyOS's default GTK typography. The custom package provides Noto Sans 10 regular/bold/italic/bold-italic and Noto Sans Mono 10, subset to Latin, combining marks, common punctuation and currency; it replaces the full `noto-fonts` package. The Pearl Greeter host reads `/etc/pearl/greeter.json`, uses the GTK DINX bridge and forces `Aqueous + Pearl (DINX)` with X11 and UWSM disabled; Aqueous/Pearl owns the only user-session contract. `scripts/check_dinx_theme.sh` validates this contract before the ISO build.

The Pearl Greeter and initial desktop use solid backgrounds without wallpaper images or a DINX logo; Calamares retains the full wordmark on its product logo/welcome surface. The reduced D-and-ray symbol remains canonical artwork at `design/brand/dinx-ray-mark.svg` and is used by Calamares as its product icon. GRUB uses the separate gradient boot-mark PNG. Papirus is the only explicitly selected desktop/app-launcher icon theme; Qogir, Breeze style and cursor packages are excluded, while the Breeze icon package remains for Calamares's KIconThemes dependency. Upstream application icons remain unchanged, and Adwaita assets remain available for GTK compatibility.
On the first Pearl session, a one-time setup wizard lets each user enable or hide the dock, place the Pearl bar at the top or bottom, and choose DINX dark/light or Pearl Material dark/light; Pearl Material dark is preselected. Pearl reserves work area only at the selected bar edge, and the dock uses the opposite edge. Choices are saved in `~/.config/pearl/preferences.json`.
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

Pearl Greeter, Aqueous/Pearl and the installer receive DINX defaults from the root overlay. Pearl Greeter uses Adwaita as configured in its root-owned greeter JSON; Calamares uses the same surface/text/primary/error tokens in its Qt stylesheet. DINX builds Calamares 3.4.3 from a checksum-pinned upstream release without Artix's `plasma-integration` dependency. The signed DINX package repository is ordered before Artix during rootfs resolution, and the ISO gate verifies that the DINX Calamares package was selected. The remaining `breeze-icons` dependency is not a Plasma session component: Calamares uses KParts, which uses KIO, which requires KIconThemes, whose Artix package depends on Breeze icons. The desktop still selects Papirus; unused Plasma integration/workspace/portal packages and Breeze style/cursors are removed. Pearl is the active user shell. The dedicated Aqueous host runs only Pearl Greeter and is not exposed as a user-session fallback. Unsupported session entries remain hidden, and `Aqueous + Pearl (DINX)` is the live session. The live session exposes `Install DINX` through its own launcher. The root overlay replaces the package's `/usr/share/applications/calamares.desktop` with a `Hidden=true`, `NoDisplay=true` tombstone that has no Artix name or executable. The DINX helper starts Calamares through `pkexec` with the live Wayland runtime/display and reports launch/authorization failures in a dialog.
The live path uses `Aqueous + Pearl (DINX)` without a credential prompt: a live-only dinit service prepares greetd before it starts. The installed rootfs keeps manual login and Calamares keeps both autologin flags disabled.
In the livefs, a PolicyKit rule authorizes Polkit-mediated privileged actions without a password only for the active, local `dinx` session. It covers launchers such as DinitUI, Calamares, GParted, Pori and Shelly. The rule is excluded from `rootfs.img`, so installed systems retain their normal authentication policy. This deliberately gives users of the disposable live session root-equivalent access.

GTK 3/4 system and skeleton defaults use Adwaita; selecting DINX in the wizard applies the DINX GTK theme. After session D-Bus is ready, the Pearl shell synchronizes the saved dark/light variant to dconf, GTK 3/4 user settings and Qt6ct. Dark mode enables GTK's dark preference and DINX's Qt palette; light mode disables Qt's custom palette. The first-run selection applies immediately and the saved choice is reapplied at each login; unrelated toolkit settings are preserved. Pearl's default shell appearance is Pearl Material dark, and the first-run wizard can select DINX or Material in dark or light mode. The live Aqueous launcher does not force `GTK_THEME`; it seeds the DINX Qt6ct config/palette when an existing home lacks them. GTK clients that request CSD keep their own titlebar without an Aqueous titlebar overlay; other negotiated SSD windows receive DINX controls. Aqueous starts in its freeform `stacking` layout; `Alt+Shift+F` selects it from another layout, and `Super+Shift+Space` toggles floating for the focused window.
The first-run GTK4 wizard applies the DINX semantic palette directly and updates its preview when a dark or light option is selected.


The runtime payload is Wayland/XWayland only: legacy Xorg/XLibre servers, drivers and Plasma session entries are omitted. Xvfb remains builder-only for package qualification.
For storage, Pori is the DINX disk/mount manager and Phyto is the default file manager. File Roller provides graphical archive actions and GParted provides standalone partition editing outside Calamares. Pori uses UDisks2 for block-device discovery and creates persistent scripted mount services under `/etc/dinit.d`; it does not use systemd units. The base image does not install Thunar, GVFS, Tumbler or KDE Partition Manager. Phyto handles directory browsing; the standalone LXQt PolicyKit agent remains for privileged actions, and Pearl remains the active shell.
For display setup, DINX's `dinx-wdisplays` wrapper opens the interactive Wayland editor; closing it atomically replaces the named `DINX wdisplays` profile in `~/.config/shikane/config.toml` and reloads the Shikane user daemon. Shikane starts inside Aqueous/Pearl and reapplies matching profiles when outputs change. `Dome`, `Seafoam Settings` and `zls` are part of the base ISO and the signed DINX package repository. Dome provides dinit-safe resource/process monitoring without systemd integration; Seafoam Settings is the fixed-argv native Zig/GTK4 launcher for the display/session entry points; ZLS is the bundled Zig language server used by Dintor with its matching `lib/std` tree and metadata-only shim, so the full Zig compiler remains optional. Aqueous 1.0.5 and Pearl 0.3.0 are the only selectable session components.

For web browsing, the profile installs the checksum-pinned official Floorp x86_64 release and makes it the default HTML/XHTML/HTTP/HTTPS handler. Managed policies at `/usr/lib/floorp/distribution/policies.json` disable sponsored surfaces, telemetry, recommendations, selected AI features and Floorp's built-in updater. Floorp source pins are maintained through DINX's reviewed package-update workflow; Mozilla account sign-in remains optional.
The profile also ships btop/nvtop/inxi, PCI and USB diagnostics, Git/curl/less/jq/rsync, ONLYOFFICE for documents, spreadsheets, presentations and PDFs, Swayimg, Haruna, Gapless (G4Music), Galculator, `wl-clipboard`, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor`, SANE's `scanimage` backend, `fwupdmgr`, the Flatpak runtime, Impasto, Krita, Inkscape, Godot, Pixelorama, Patchy and Blockbench. Impasto, Krita, Inkscape and Pixelorama provide raster graphics editing; Godot is the game engine. Impasto, Patchy and Blockbench are version-pinned upstream AppImages with checksummed licenses/notices, preserved byte-for-byte, and launched with `--appimage-extract-and-run`, so FUSE is not required. Pixelorama uses its checksum-pinned official Linux x86_64 release, wrapper, desktop entry, icon, MIT license and `.pxo` MIME registration. Galculator is a compact GTK 3 calculator using the existing GTK stack, with no separate GUI toolkit added. Gapless is built from pinned upstream v4.6.2 with GStreamer base/good codec support and gapless playback enabled by default. It supports MPRIS media controls. Swayimg is built from pinned upstream 5.6 with Wayland, JPEG and PNG support and remains the default image viewer. Pearl owns active shell surfaces and static DINX bridges; no shell plugin or private shell asset is required. No Flatpak applications are preinstalled.

### Application launcher labels

Launcher names follow the desktop locale. Swayimg remains hidden from the app menu and opens associated image files. The original Artix Calamares desktop ID is replaced with an inert tombstone; only the functional DINX installer shortcut is exposed.

| App | English | Português (Brasil) |
| --- | --- | --- |
| Dome | System Monitor | Monitor do Sistema |
| DinitUI | Services | Serviços |
| DINXPanel | Control Center | Central de Controle |
| Seafoam Settings | Desktop Settings | Ajustes do Desktop |
| Dintor | Editor | Editor |
| Pori | Disks & Mounts | Discos e Montagens |
| Phyto | Files | Arquivos |
| Display setup | Display Settings | Ajustes de Tela |
| Shelly | Software & Updates | Aplicações e Updates |
| Galculator | Calculator | Calculadora |
| GParted | Partition Editor | Particionador |
| Impasto | Image Editor | Editor de Imagens |
| Krita | Digital Painting | Pintura Digital |
| Inkscape | Vector Graphics | Gráficos Vetoriais |
| Godot | Game Engine | Motor de Jogos |
| Pixelorama | Pixel Art & Animation | Arte de Pixel e Animação |
| Patchy | Image Editor | Editor de Imagens |
| Blockbench | 3D Model Editor | Editor de Modelos 3D |
| Swayimg | Image Viewer | Visualizador de Imagens |
| ONLYOFFICE | Office and PDF Editors | Suíte de Escritório e PDF |
| Gapless | Music Player | Tocador de Música |
| Haruna | Media Player | Tocador de Mídia |
| Blueman | Bluetooth | Bluetooth |
| Network connections | Network Connections | Ajustes de Rede |
| pwvucontrol | Audio Control | Ajustes de Áudio |
| File Roller | Archive Manager | Descompactador |
| DINX installer | Install DINX | Instalar DINX |
| Firewall configuration | Firewall | Firewall |
| Qps | Process Manager | Processos |

CUPS is intentionally outside the offline profile. After installation,
DINXPanel offers the fixed `cups-dinit` download from the configured Artix
repository; the package pulls CUPS and provides the `cupsd` dinit service.
The package-management payload adds `topgrade`, `paru` and Shelly. Topgrade uses a pinned upstream release binary with DINX's Artix `pacman` configuration; paru is built from its pinned source release against Artix ALPM; Shelly delegates to Artix's `pacman` configuration. Their package metadata has no `systemd` dependency or unit, no Arch repository is added, and AUR recipes remain subject to review. None starts automatically at boot.
For gaming, the `gaming` feature group has `iso:false`; Gamescope, Steam, Steam device rules, GameMode, MangoHud and 32-bit libraries are excluded from the base rootfs/livefs. The base profile retains AMDGPU and Intel GPU firmware, 64-bit Mesa RADV and Vulkan tools. P0 no longer enables Artix's `[lib32]` repository for ISO assembly; users can opt in after installation using the steps in [`docs/install.md`](../../docs/install.md). No Arch repository is added.
AMDGPU firmware, Mesa RADV and Vulkan tools remain generic AMD graphics support in the base profile. The BC-250-only Cyan Skillfish governor, its dinit package and BC250 Control Center are not installed in the generic live or installed root. CI keeps the pinned packages in the signed DINX repository.
Install those packages only after `lspci -n -d 1002:13fe` confirms the device; configure the signed DINX repository and follow the guarded steps in [`docs/install.md`](../../docs/install.md#optional-bc-250-support).
The compact ISO ships AMDGPU and Intel GPU firmware, Mesa RADV and Vulkan tools for generic graphics, while omitting the broad `linux-firmware` bundle and `powertop`. `linux-headers` remain in the Artix build root only until initramfs generation, then `linux-headers` and its build-only `pahole` dependency are removed before rootfs/livefs SquashFS packaging. exFAT uses `exfatprogs` with the kernel driver; NTFS uses the kernel `ntfs3` driver.
The firewall/process payload includes Firewalld, firewall-config, OpenSnitch and Qps. Firewalld and the OpenSnitch daemon use separate Dinit services enabled in both live and installed root filesystems; live autologin waits for Firewalld's startup attempt but still proceeds if it fails. The OpenSnitch UI starts in the background/tray for the user session. OpenSnitch uses nftables with upstream defaults `DefaultAction=allow` and `InterceptUnknown=false`: it does not impose deny-by-default filtering and complements rather than replaces Firewalld. The live-session PolicyKit rule allows firewall-config to manage Firewalld without a password. UFW, Gufw and Portmaster are not shipped.

DinitUI installs `normal`, `lite` and `gaming` system-service profiles and supports custom profiles at `~/.config/dinx/dinitui/profiles.conf`. `lite` only disables optional Bluetooth; Gaming enables Bluetooth for controllers. Built-in profiles do not alter Firewalld or OpenSnitch. The standalone launcher enters Gaming and restores the previous profile on exit; entry or restoration failures stop the launcher and remain visible. DINXPanel owns the visible hardware and driver actions, fixed control-panel shortcuts, Shelly/Topgrade workflows, optional fwupd discovery and the safe Artix kernel installer; Aqueous/Pearl does not require a shell plugin.
The dedicated Pearl Greeter host provides the login surface for greetd. Pearl owns the active user shell; Aqueous/Pearl is the sole user session.
### Session safety, hierarchy and resource guard

In the live session, `swayidle` and `wlopm` power off all displays after 600 seconds idle and before suspend, then restore them on input or resume. Aqueous rejects session-lock requests; the default lock shortcut, DINXPanel button and desktop lock launcher are disabled for the live user. Installed sessions retain `swaylock` for idle and suspend locking, with explicit locking through `dinx-lock`, `Super+L`, Pearl and DINXPanel. Standard brightness keys and DINXPanel use fixed 5-percent `brightnessctl` steps; specialist tools remain in the launcher.

`scripts/check_dinx_budget.sh` keeps the current profile at 118 of 128 rootfs package entries and at or below 24 dinit startup entries, caps built DINXPanel/DinitUI binaries at 6 MiB each, limits the QEMU boot qualification window to 120 seconds, and enforces a built ISO below 2 GiB (`2147483647` bytes) when `DINX_ISO_PATH` is supplied. Passing the package-count budget does not guarantee the ISO-size budget; the final artifact must pass both. These are regression ceilings, not measured hardware performance claims. `scripts/measure_dinx_session.sh` records RSS/CPU snapshots from `/proc` when a DINX session is actually running.

The Artix builder still consumes one `profile.yaml`; the feature-group manifest is a contract, not a package-composition mechanism. The generic ISO profile contains the foundation and desktop groups while gaming and BC-250-specific packages remain outside the base image. DinitUI's Normal/Lite/Gaming service policies continue to provide runtime service separation.

The P0 content gate requires the root and live-session SquashFS images to contain the expected compositor, shell, greeter, session, Deetty as the sole terminal emulator, Nano recovery editor, Pori dinit storage manager, Phyto file manager, kernel `ntfs3` support, SANE scanner backend, fwupd firmware tooling, Flatpak runtime, Impasto, Krita, Inkscape, Godot, Patchy and Blockbench graphics apps, and dinit payloads. It rejects KolourPaint binaries, launchers and package metadata, along with optional gaming binaries and metadata, in both images. `scripts/check_desktop_packages.sh` and `scripts/check_pori_phyto.sh` verify package/profile contracts before the build. `scripts/smoke-install.sh` exercises the offline contract on ephemeral BIOS/UEFI disks, checks the dinit first boot and enables recovery TTYs. The workflow's PPM capture is visual evidence to inspect, not arbitrary hardware qualification.

The P0 live-session gate requires `AUTOLOGIN=true`, the live-only autologin dinit service and the unchanged installed-system greeter boundary.

The installed-disk BIOS/UEFI smoke also requires the captured greeter screen to show Pearl's `Sign in` control and `Password` field; service-ready logs and a valid framebuffer alone do not qualify login readiness.

The payload contract also requires `wdisplays`, `shikane` and the DINX display persistence entry points. Dome and ZLS external sources are pinned; Seafoam Settings is built from checked-in repository source. All three are required and checked as part of the base ISO payload.
Requirements: a reachable rootful Docker Engine, `--privileged` and loop-device support, network access, and enough free disk for the temporary rootfs and ISO. The local build runs the same full qualification as P0 by default. It also requires the commands listed by `scripts/check-iso-qualification-host.sh full`, QEMU with the `virtio-vga` device, Tesseract's `eng` model, OVMF firmware, and `sudo` (or root). Check prerequisites before starting:
The workflow stores a separate `dinx-boot-screen.ppm` capture taken before the boot-menu keys are sent. Review this frame when qualifying the GRUB kernel-selection surface; it is the regression evidence for the removed opaque menu panel.

GRUB uses the transparent compact D-ray mark with DINX surface, foreground and primary selection colors instead of the Artix logo; Artix font assets remain in use. The opaque menu textures are disabled. Pearl Greeter and the initial desktop use solid backgrounds without a wallpaper image or DINX logo; Calamares retains the full wordmark on its product logo/welcome and the compact mark for its product icon. Papirus is the only explicitly selected desktop/app-launcher icon theme; Qogir and KDE Breeze icon/style packages are excluded. Upstream application icon artwork remains unchanged.
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
