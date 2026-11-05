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
It forces xz-compressed SquashFS images with the tool's supported xz preset,
x86 BCJ, 256 KiB blocks and a 256 KiB dictionary. Kernel sources, pacman package
caches and build logs are excluded from the final image. The root overlay recreates
`/var/log/dinit` through tmpfiles before Dinit services start, and the ISO-content
check requires that rule. The livefs-only `dinx-live-autologin` package supplies
no-op `root-ro` and `early-root-rw.target` units for its writable overlay; these
overrides are not included in the Calamares-installed rootfs. Build-only
`squashfs-tools` stays in the builder, not the runtime payload. CI installs the
wrapper at `/usr/bin/mksquashfs` after preserving the real binary, because Artix
`buildiso` may invoke that absolute path. Post-build inspection checks both
SquashFS superblocks for xz compression and 256 KiB blocks.
The P0 budget rejects ISOs at or above GitHub's 2 GiB asset limit; Alpha 12 is
1,836,830,720 bytes (310,652,928 bytes below the limit).

## Graphical profile

`iso-profiles/dinx/profile.yaml` includes Aqueous, Pearl, greetd and the native `deetty` package. Deetty is the sole terminal emulator in both the live and installed root filesystems. The ISO's `ghostty-vt-runtime` package contains only the VT library, headers and license needed by Deetty, not the Ghostty terminal application. The Pearl package supplies the Pearl Greeter; `deetty` installs Deetty and Dintor, including desktop files, icons, language specifications and the dark editor style. CI consumes the generated source archive from the exact commit and SHA-256 contract declared in `distro/packages/deetty/source.env`, from `https://github.com/rufl/DEETTY.git`. The root overlay supplies `/etc/greetd/config.toml`, `/etc/pearl/greeter.json` and hidden session metadata; Aqueous + Pearl is the only user-session entry.
The livefs adds the live-only `dinx-live-autologin` dinit package. It enables greetd's one-time `initial_session` for `dinx` with Aqueous + Pearl and supplies no-op root-remount units for the already-writable live overlay. These overrides stay in `livefs`; Calamares installs `rootfs.img`, which retains Artix's generic root-remount units. The greetd fallback launches `dinx-pearl-greeter-host`, applies the same graphics policy as the live session, and defaults libseat to `logind` so the greeter uses elogind under dinit.

`iso-profiles/dinx/feature-groups.json` records the foundation, desktop, gaming, hardware and optional package groups without replacing Artix's `profile.yaml`. The CI builder signs every locally built package and the temporary `dinx` repository database with an ephemeral key, checks package signatures and duplicate archive paths, and records the immutable package snapshot in `build-metadata.txt`. This is build qualification only; the production pacman repository key and installed-system update channel remain separate release prerequisites.

The source tree configures a weekly upstream-pin refresh at Monday 04:17 UTC.
It opens one reviewed PR for 13 release-based custom-package sources; the
private Deetty commit and ZLS/Zig 0.16 pins remain manual. After merge, a
separate signed package-only workflow publishes to the GitHub Release tag
`dinx-packages-latest` without ISO assembly. These workflows are configured
but have not yet been confirmed green or published. `dinx-keyring` configures
the required-signature `[dinx]` repository and editable
`/etc/pacman.d/dinx-mirrorlist`; Shelly uses pacman to sync and update packages.
See the [release guide](../../docs/release.md) for signing-secret setup and
manual key verification/bootstrap.

The profile owns static DINX visual bridges: `/usr/share/dinx/theme/DINX.json` is the source for semantic and ANSI colors; GTK and Qt consume checked-in DINX theme files, and `DINX_COLOR_SCHEME` is the user-session color contract. `qt6ct`, `adw-gtk-theme` and Noto Sans 10 are installed for the corresponding consumers, matching CachyOS's default GTK typography; Noto Sans Mono is used for fixed-width fields. The Pearl Greeter host reads `/etc/pearl/greeter.json`, uses the GTK DINX bridge and forces `Aqueous + Pearl (DINX)` with X11 and UWSM disabled; Aqueous/Pearl owns the only user-session contract. `scripts/check_dinx_theme.sh` validates this contract before the ISO build.

The Pearl Greeter and initial desktop use solid backgrounds without wallpaper images or a DINX logo; Calamares retains the full wordmark on its product logo/welcome surface. The reduced D-and-ray symbol is maintained as a transparent SVG at `design/brand/dinx-ray-mark.svg`, copied into the ISO branding assets, and rendered as the GRUB logo; Calamares uses it as the product icon. Desktop and app-launcher icons remain upstream/Adwaita.
On the first Pearl session, a one-time setup wizard lets each user enable or hide the dock, place the Pearl bar at the top or bottom, and choose DINX dark/light or Pearl Material dark/light; Pearl Material dark is preselected. The dock uses the opposite edge from the bar; choices are saved in `~/.config/pearl/preferences.json`.
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

Pearl Greeter, Aqueous/Pearl and the installer receive DINX defaults from the root overlay. Pearl Greeter uses Adwaita as configured in its root-owned greeter JSON; Calamares uses the same surface/text/primary/error tokens in its Qt stylesheet. Pearl is the active user shell. The dedicated Aqueous host runs only Pearl Greeter and is not exposed as a user-session fallback. The Calamares dependency chain retains only installer components, unsupported session entries remain hidden, and `Aqueous + Pearl (DINX)` is the live session. The live session exposes `Install DINX` through its own launcher. The root overlay replaces the package's `/usr/share/applications/calamares.desktop` with a `Hidden=true`, `NoDisplay=true` tombstone that has no Artix name or executable. The DINX helper starts Calamares through `pkexec` with the live Wayland runtime/display and reports launch/authorization failures in a dialog.
The live path uses `Aqueous + Pearl (DINX)` without a credential prompt: a live-only dinit service prepares greetd before it starts. The installed rootfs keeps manual login and Calamares keeps both autologin flags disabled.
In the livefs, a PolicyKit rule authorizes Polkit-mediated privileged actions without a password only for the active, local `dinx` session. It covers launchers such as DinitUI, Gufw, Calamares, GParted, Pori and Shelly. The rule is excluded from `rootfs.img`, so installed systems retain their normal authentication policy. This deliberately gives users of the disposable live session root-equivalent access.

GTK 3/4 system and skeleton defaults use Adwaita. The live session seeds GNOME's `prefer-dark` color scheme through dconf only when the user has no explicit setting; existing light/dark choices remain untouched. GTK3's dark preference remains set in `settings.ini`. Pearl's default shell appearance is Pearl Material dark, and the first-run wizard can select DINX or Material in dark or light mode. The live Aqueous launcher does not force `GTK_THEME`; it seeds the DINX Qt6ct config/palette when an existing home lacks them. GTK clients that request CSD keep their own titlebar without an Aqueous titlebar overlay; other negotiated SSD windows receive DINX controls. Aqueous starts in its freeform `stacking` layout; `Alt+Shift+F` selects it from another layout, and `Super+Shift+Space` toggles floating for the focused window.

The runtime payload is Wayland/XWayland only: legacy Xorg/XLibre servers, drivers and Plasma session entries are omitted. Xvfb remains builder-only for package qualification.
For storage, Pori is the DINX disk/mount manager and Phyto is the default file manager. File Roller provides graphical archive actions and GParted provides standalone partition editing outside Calamares. Pori uses UDisks2 for block-device discovery and creates persistent scripted mount services under `/etc/dinit.d`; it does not use systemd units. The base image does not install Thunar, GVFS, Tumbler or KDE Partition Manager. Phyto handles directory browsing; the standalone LXQt PolicyKit agent remains for privileged actions, and Pearl remains the active shell.
For display setup, DINX's `dinx-wdisplays` wrapper opens the interactive Wayland editor; closing it atomically replaces the named `DINX wdisplays` profile in `~/.config/shikane/config.toml` and reloads the Shikane user daemon. Shikane starts inside Aqueous/Pearl and reapplies matching profiles when outputs change. `Dome`, `Seafoam Settings` and `zls` are part of the base ISO and the signed DINX package repository. Dome provides dinit-safe resource/process monitoring without systemd integration; Seafoam Settings is the fixed-argv native Zig/GTK4 launcher for the display/session entry points; ZLS is the bundled Zig language server used by Dintor with its matching `lib/std` tree and metadata-only shim, so the full Zig compiler remains optional. Aqueous 1.0.5 and Pearl 0.3.0 are the only selectable session components.

For web browsing, the profile installs Firefox and makes it the default HTML/XHTML/HTTP/HTTPS handler. The system policy at `/etc/firefox/policies/policies.json` disables sponsored New Tab and Firefox Suggest surfaces, Pocket/Stories, Firefox Studies/telemetry, browser recommendations, AI assistant/link-preview/tab-group surfaces and built-in IP Protection. Firefox Accounts remains an explicit user choice: DINX does not require sign-in or show onboarding prompts, while normal browser updates remain enabled.
The profile also ships btop/nvtop/inxi, PCI and USB diagnostics, Git/curl/less/jq/rsync, Zathura with the MuPDF backend, Swayimg, VLC, Gapless (G4Music), Galculator, `wl-clipboard`, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor`, SANE's `scanimage` backend, `fwupdmgr`, the Flatpak runtime and KolourPaint. Galculator is a compact GTK 3 calculator using the existing GTK stack, with no separate GUI toolkit added. Gapless is built from pinned upstream v4.6.2 with GStreamer base/good codec support and gapless playback enabled by default. It supports MPRIS media controls. Swayimg is built from pinned upstream 5.6 with Wayland, JPEG and PNG support and remains the default image viewer. Pearl owns active shell surfaces and static DINX bridges; no shell plugin or private shell asset is required. No Flatpak applications are preinstalled.

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
| KolourPaint | Drawing | Desenho |
| Swayimg | Image Viewer | Visualizador de Imagens |
| Zathura | PDF Reader | Leitor de PDF |
| Gapless | Music Player | Tocador de Música |
| VLC | Media Player | Tocador de Mídia |
| Blueman | Bluetooth | Bluetooth |
| Network connections | Network Connections | Ajustes de Rede |
| pwvucontrol | Audio Control | Ajustes de Áudio |
| File Roller | Archive Manager | Descompactador |
| DINX installer | Install DINX | Instalar DINX |
| Gufw | Firewall | Firewall |
| Qps | Process Manager | Processos |
| OpenSnitch | Traffic Monitor | Monitor de Tráfego |

CUPS is intentionally outside the offline profile. After installation,
DINXPanel offers the fixed `cups-dinit` download from the configured Artix
repository; the package pulls CUPS and provides the `cupsd` dinit service.
The package-management payload adds `topgrade`, `paru` and Shelly. Topgrade uses a pinned upstream release binary with DINX's Artix `pacman` configuration; paru is built from its pinned source release against Artix ALPM; Shelly delegates to Artix's `pacman` configuration. Their package metadata has no `systemd` dependency or unit, no Arch repository is added, and AUR recipes remain subject to review. None starts automatically at boot.
For gaming, the `gaming` feature group has `iso:false`; Gamescope, Steam, Steam device rules, GameMode, MangoHud and 32-bit libraries are excluded from the base rootfs/livefs. The base profile retains AMDGPU and Intel GPU firmware, 64-bit Mesa RADV and Vulkan tools. P0 no longer enables Artix's `[lib32]` repository for ISO assembly; users can opt in after installation using the steps in [`docs/install.md`](../../docs/install.md). No Arch repository is added.
AMDGPU firmware, Mesa RADV and Vulkan tools remain generic AMD graphics support in the base profile. The BC-250-only Cyan Skillfish governor, its dinit package and BC250 Control Center are not installed in the generic live or installed root. CI keeps the pinned packages in the signed DINX repository.
Install those packages only after `lspci -n -d 1002:13fe` confirms the device; configure the signed DINX repository and follow the guarded steps in [`docs/install.md`](../../docs/install.md#optional-bc-250-support).
The governor package pulls its matching runtime and uses dinit; its wrapper applies the configured limits only to PCI `1002:13fe`. Use an Artix kernel with the current upstream BC-250 fixes (6.17.11 or newer; the Artix LTS kernel is preferred). The compact ISO root includes AMDGPU and Intel GPU firmware for general graphics support but omits the generic `linux-firmware` bundle and `powertop`; it retains kernel headers for Artix initramfs generation while excluding their source tree from final SquashFS images.
The firewall/process payload adds UFW with Artix's `ufw-dinit` service files, Gufw and OpenSnitch daemon/UI with a DINX dinit service, and Qps. In the app launcher, Gufw appears as Firewall, OpenSnitch as Traffic Monitor, and Qps as Process Manager. UFW and OpenSnitch services are installed but not linked into boot by default: configure rules and deliberately enable the firewall policy you want. Do not enable both rule managers without reviewing the resulting netfilter ruleset.

DinitUI installs `normal`, `lite` and `gaming` service profiles and supports custom profiles at `~/.config/dinx/dinitui/profiles.conf`. `lite` only disables optional Bluetooth; Gaming enables Bluetooth for controllers and preserves firewall/process-policy services. The standalone launcher enters Gaming and restores the previous profile on exit; entry or restoration failures stop the launcher and remain visible. DINXPanel owns the visible hardware and driver actions, fixed control-panel shortcuts, Shelly/Topgrade workflows, optional fwupd discovery and the safe Artix kernel installer; Aqueous/Pearl does not require a shell plugin.
The dedicated Pearl Greeter host provides the login surface for greetd. Pearl owns the active user shell; Aqueous/Pearl is the sole user session.
### Session safety, hierarchy and resource guard

The session installs `swaylock`, `swayidle` and `brightnessctl`. `/usr/local/libexec/dinx-idle` locks after 600 seconds and locks again on `before-sleep`; `/usr/local/libexec/dinx-lock`, `Super+L`, Pearl's lock surface and DINXPanel provide the explicit lock path. Standard brightness keys and DINXPanel use fixed 5-percent `brightnessctl` steps; specialist tools remain in the launcher.

`scripts/check_dinx_budget.sh` keeps the current profile at or below 128 rootfs package entries and 24 dinit startup entries, caps built DINXPanel/DinitUI binaries at 6 MiB each, limits the QEMU boot qualification window to 120 seconds, and enforces a built ISO below 2 GiB (`2147483647` bytes) when `DINX_ISO_PATH` is supplied. These are regression ceilings, not measured hardware performance claims. `scripts/measure_dinx_session.sh` records RSS/CPU snapshots from `/proc` when a DINX session is actually running.

The Artix builder still consumes one `profile.yaml`; the feature-group manifest is a contract, not a package-composition mechanism. The generic ISO profile contains the foundation and desktop groups while gaming and BC-250-specific packages remain outside the base image. DinitUI's Normal/Lite/Gaming service policies continue to provide runtime service separation.

The P0 content gate requires the root and live-session SquashFS images to contain the expected compositor, shell, greeter, session, Deetty as the sole terminal emulator, Nano recovery editor, Pori dinit storage manager, Phyto file manager, kernel `ntfs3` support, SANE scanner backend, fwupd firmware tooling, Flatpak runtime, KolourPaint image editor and dinit payloads. It also rejects optional gaming binaries and package metadata in both images. `scripts/check_desktop_packages.sh` and `scripts/check_pori_phyto.sh` verify package/profile contracts before the build. `scripts/smoke-install.sh` exercises the offline contract on ephemeral BIOS/UEFI disks, checks the dinit first boot and enables recovery TTYs. The workflow's PPM capture is visual evidence to inspect, not arbitrary hardware qualification.

The P0 live-session gate requires `AUTOLOGIN=true`, the live-only autologin dinit service and the unchanged installed-system greeter boundary.

The payload contract also requires `wdisplays`, `shikane` and the DINX display persistence entry points. Dome and ZLS external sources are pinned; Seafoam Settings is built from checked-in repository source. All three are required and checked as part of the base ISO payload.
Requirements: a reachable rootful Docker Engine, `--privileged` and loop-device support, network access, and enough free disk for the temporary rootfs and ISO. The local build runs the same full qualification as P0 by default. It also requires the commands listed by `scripts/check-iso-qualification-host.sh full`, QEMU with the `virtio-vga` device, Tesseract's `eng` model, OVMF firmware, and `sudo` (or root). Check prerequisites before starting:
The workflow stores a separate `dinx-boot-screen.ppm` capture taken before the boot-menu keys are sent. Review this frame when qualifying the GRUB kernel-selection surface; it is the regression evidence for the removed opaque menu panel.

GRUB uses the transparent compact D-ray mark with DINX surface, foreground and primary selection colors instead of the Artix logo; Artix font assets remain in use. The opaque menu textures are disabled. Pearl Greeter and the initial desktop use solid backgrounds without a wallpaper image or DINX logo; Calamares retains the full wordmark on its product logo/welcome and the compact mark for its product icon. Desktop launcher icons remain upstream/Adwaita icons, not DINX branding.
In the current source profile, the normal live path is direct autologin; the greeter remains a fallback surface rather than a required boot step.

## Profile boundary

The repository vendors a compact common package manifest at `iso-profiles/common/common.yaml` instead of relying on the installed `iso-profiles` default. It keeps the DINX foundation and desktop payload while excluding optional gaming and BC-250 packages, generic firmware and `powertop`; build-only kernel headers are excluded from final SquashFS images. Its SHA-256 is recorded in `build-metadata.txt`. `WORKSPACE_DIR` in `scripts/build-iso.sh` selects both local manifests deterministically.

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
