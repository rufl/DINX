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


The workflow also captures the QEMU VGA surface through its monitor. To request the same evidence locally:

```bash
DINX_QEMU_BOOT_KEYS=down,down,ret \
DINX_QEMU_SCREENSHOT=dist/iso/dinx/graphical-screen.ppm \
DINX_QEMU_SCREENSHOT_DELAY=60 \
scripts/smoke-iso.sh dist/iso/<file>.iso
```


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
caches and build logs are excluded from the final image; build-only `squashfs-tools`
remains in the builder environment rather than the runtime payload. The P0 budget rejects a
built ISO at or above GitHub's 2 GiB per-asset limit; Alpha 9 meets this target with one direct ISO asset at 2,008,801,280 bytes.

## Graphical profile

`iso-profiles/dinx/profile.yaml` includes the Artix `labwc` package, Noctalia, greetd, ReGreet and the native `noctty` package. The `noctty` package installs both NOCTTY and NoctEd, including their desktop files, icons, language specifications and dark editor style. CI consumes the committed source archive generated from the exact NOCTTY repository commit and SHA-256 contract declared in `distro/packages/noctty/source.env`; labwc and its public wlroots dependency come from Artix rather than a custom compositor build. The workflow publishes all custom packages to a temporary local pacman repository before invoking `buildiso`. The profile's `root-overlay` supplies the greetd configuration, ReGreet actions, labwc configuration and sessions, the Noctalia autostart and palette/template inputs, the BC250 user-session launcher, and the no-op live `root-ro` replacement.
The livefs adds the live-only `dinx-live-autologin` dinit package. It enables greetd's one-time `initial_session` for `dinx` without changing the installed rootfs configuration; ReGreet remains the fallback if the initial session exits.

`iso-profiles/dinx/feature-groups.json` records the foundation, desktop, gaming, hardware and optional package groups without replacing Artix's `profile.yaml`. The CI builder signs every locally built package and the temporary `dinx` repository database with an ephemeral key, checks package signatures and duplicate archive paths, and records the immutable package snapshot in `build-metadata.txt`. This is build qualification only; the production pacman repository key and installed-system update channel remain separate release prerequisites.

The profile also owns the DINX visual bridges: `root-overlay/etc/skel/.config/noctalia/palettes/DINX.json` is the v1 source for dark/light semantic and ANSI colors; built-in Noctalia templates feed btop, Foot, Ghostty, GTK 3/4, KDE and Qt. `qt6ct`, `adw-gtk-theme` and Noto Sans 10 are installed for the corresponding consumers, matching CachyOS's default GTK typography; Noto Sans Mono is used for fixed-width fields. labwc reads its checked-in configuration from `/etc/xdg/labwc` and merges user overrides from `~/.config/labwc/rc.xml`. `scripts/check_dinx_theme.sh` validates this contract before the ISO build.

The profile includes the experimental Calamares installer and GParted for standalone partition editing. Calamares copies the ISO root filesystem offline, keeps dinit as the installed init system, and removes the live-only Artix packages during installation. The base image carries the kernel `ntfs3` driver for NTFS read/write access and `os-prober` for Windows discovery; legacy `ntfs-3g` remains an optional post-install package in the signed extra channel. Existing Windows ESP/NTFS layouts are preserved by the installer and use a separate DINX EFI directory.

The greeter, Noctalia and installer receive DINX defaults from the root overlay. ReGreet uses the installed DINX GTK theme; Calamares uses the same surface/text/primary/error tokens in its Qt stylesheet. Noctalia starts with the custom DINX palette, application templates, animations and panel/settings transparency disabled, but its Settings UI can change these defaults later. labwc starts with two workspaces; edit `~/.config/labwc/rc.xml` for user overrides. The Calamares dependency chain retains only the installer components it needs, unsupported Plasma session entries remain hidden from the DINX greeter, and `Labwc (DINX)` is the live session. The live session exposes `Instalar DINX` through the application launcher; disk preparation is performed by Calamares, GParted or explicit CLI tools.
The live path uses the same `Labwc (DINX)` session without a credential prompt: a live-only dinit service prepares greetd before it starts. The installed rootfs keeps manual login and Calamares keeps both autologin flags disabled.
The runtime payload is Wayland/XWayland only: legacy Xorg/XLibre servers, drivers and the Plasma X11 desktop entry are omitted. Xvfb remains builder-only for package qualification.
For storage, Pori is the DINX disk/mount manager and Phyto is the default file manager. File Roller provides graphical archive actions and GParted provides standalone partition editing outside Calamares. Pori uses UDisks2 for block-device discovery and creates persistent scripted mount services under `/etc/dinit.d`; it does not use systemd units. The base image does not install Thunar, GVFS, Tumbler or KDE Partition Manager. Phyto handles directory browsing; the standalone LXQt PolicyKit agent remains for privileged actions, and Noctalia remains the desktop shell.

For display setup, DINX's `dinx-wdisplays` wrapper opens the interactive Wayland editor; closing it atomically replaces the named `DINX wdisplays` profile in `~/.config/shikane/config.toml` and reloads the Shikane user daemon. Shikane starts with labwc and reapplies matching profiles when outputs change. `Dome`, `Seafoam Settings` and `zls` are part of the base ISO and the signed DINX package repository. Dome provides dinit-safe resource/process monitoring without systemd integration; Seafoam Settings is the fixed-argv native Zig/GTK4 launcher for the display/session entry points; ZLS is the bundled Zig language server used by Nocted with its matching `lib/std` tree and metadata-only shim, so the full Zig compiler remains optional. Aqueous 1.0.5 and Pearl 0.3.0 are also in the base ISO: the greeter exposes `Aqueous + Pearl (DINX)`, whose direct DINX wrappers launch Aqueous, start Shikane/PolicyKit/BC250/idle helpers and exec Pearl without systemd, uwsm or user units. Its direct-dinit activity bootstrap uses pidfd, executable and environment checks instead of systemd unit/D-Bus checks; Labwc + Noctalia remains the default session.

For web browsing, the profile installs Firefox and makes it the default HTML/XHTML/HTTP/HTTPS handler. The system policy at `/etc/firefox/policies/policies.json` disables sponsored New Tab and Firefox Suggest surfaces, Pocket/Stories, Firefox Studies/telemetry, browser recommendations, AI assistant/link-preview/tab-group surfaces and built-in IP Protection. Firefox Accounts remains an explicit user choice: DINX does not require sign-in or show onboarding prompts, while normal browser updates remain enabled.
The profile also ships btop/nvtop/inxi, PCI and USB diagnostics, Git/curl/less/jq/rsync, Zathura with the MuPDF backend as the normal PDF handler, Swayimg, VLC with its Qt GUI/CLI split, Strawberry, `wl-clipboard`, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor`, SANE's `scanimage` backend, `fwupdmgr`, the Flatpak runtime and KolourPaint as a simple Qt image editor. Swayimg is built from the pinned upstream 5.6 source with Wayland, JPEG and PNG support and remains the default image viewer. Noctalia's Network, Bluetooth, Volume, Battery, Screenshot and Clipboard widgets are the primary shell surfaces; the standalone editors and players remain available from the launcher. No Flatpak applications are preinstalled; remotes and app installs remain explicit user actions. Noctalia remains the primary screenshot path; transitive Artix package dependencies may also provide `grim` and `slurp`, while `wl-copy`/`wl-paste` remain available for CLI workflows.

CUPS is intentionally outside the offline profile. After installation,
DINXPanel offers the fixed `cups-dinit` download from the configured Artix
repository; the package pulls CUPS and provides the `cupsd` dinit service.
The package-management payload adds `topgrade`, `paru` and Shelly. Topgrade uses a pinned upstream release binary with DINX's Artix `pacman` configuration; paru is built from its pinned source release against Artix ALPM; Shelly delegates to Artix's `pacman` configuration. Their package metadata has no `systemd` dependency or unit, no Arch repository is added, and AUR recipes remain subject to review. None starts automatically at boot.
For gaming, the P0 workflow enables Artix's official `[lib32]` repository in the `pacman.conf` consumed by `buildiso`; no Arch repository is added. This is required for the profile's `steam`, `steam-devices` and 32-bit Mesa/Vulkan packages.
For AMD Cyan Skillfish hardware such as the BC-250, the profile adds Artix's AMDGPU firmware, Mesa RADV and Vulkan tools plus the pinned SMU governor. Its dinit service is linked in both live and installed roots, detects PCI `1002:13fe`, applies the conservative 1000-1850 MHz config and does nothing on other hardware. This is an automatic dinit path, not a systemd service; use an Artix kernel with the current upstream BC-250 fixes (6.17.11 or newer; the Artix LTS kernel is preferred).
The compact common manifest at `iso-profiles/common/common.yaml` keeps the AMDGPU firmware required by the documented Cyan Skillfish path but omits the generic `linux-firmware` bundle and `powertop` from the final image. It retains kernel headers for Artix initramfs generation; the repository mksquashfs wrapper excludes their source tree from the final SquashFS images. Hardware needing other firmware or local kernel/module builds must install those packages separately.
The profile also ships BC250 Control Center v1.21.1 from a SHA-256-pinned MIT source archive. Its GUI, CLI, polkit policy and headless daemon are available from the launcher and dock; labwc's `/etc/xdg/labwc/autostart` starts the daemon once in the logged-in user session. DINX removes the upstream systemd user unit and systemd Cyan drop-in, so this integration adds no systemd service and no root dinit service. On dinit, upstream service persistence is detection-only; live BC-250 telemetry remains the supported background path.
The firewall/process payload adds UFW with Artix's `ufw-dinit` service files, the Gufw GUI, OpenSnitch daemon/UI with a DINX dinit service, and Qps. UFW and OpenSnitch services are installed but not linked into boot by default: configure rules and deliberately enable the firewall policy you want. Do not enable both rule managers without reviewing the resulting netfilter ruleset.

DinitUI installs `normal`, `lite` and `gaming` service profiles and supports custom profiles at `~/.config/dinx/dinitui/profiles.conf`. `lite` only disables optional Bluetooth; Gaming enables Bluetooth for controllers and preserves firewall/process-policy services. The standalone launcher enters Gaming and restores the previous profile on exit; entry or restoration failures stop the launcher and remain visible to the caller. The Noctalia `dinx/performance` plugin is installed in the user skeleton; its Control Center Gaming shortcut applies the Dinit profile and synchronizes Noctalia's `performance` power profile. DINXPanel owns the visible hardware and driver actions, including fixed AMD/Intel/NVIDIA GPU plans delegated to DinitUI, fixed shortcuts for the main control panels, Shelly/Topgrade upgrade workflows, optional fwupd discovery and a safe installer for `linux`, `linux-lts`, `linux-zen` and `linux-hardened` with matching headers. It never removes the running kernel and requires a reboot after kernel or driver changes. The `dinx-gaming` session remains standalone and does not depend on Noctalia.
labwc provides stacking windows with two workspaces. The Noctalia `main` bar reserves the top edge, and the dock reserves the bottom edge.
### Session safety, hierarchy and resource guard

The session installs `swaylock`, `swayidle` and `brightnessctl`. `/usr/local/libexec/dinx-idle` locks after 600 seconds and locks again on `before-sleep`; `/usr/local/libexec/dinx-lock`, `Super+L`, the Noctalia launcher entry and DINXPanel provide the explicit lock path. Standard brightness keys and DINXPanel use fixed 5-percent `brightnessctl` steps. The Noctalia dock is reserved for primary DINX surfaces; specialist tools remain in the launcher.

`scripts/check_dinx_budget.sh` keeps the current profile at or below 128 rootfs package entries and 24 dinit startup entries, caps built DINXPanel/DinitUI binaries at 6 MiB each, limits the QEMU boot qualification window to 120 seconds, and enforces a built ISO below 2 GiB (`2147483647` bytes) when `DINX_ISO_PATH` is supplied. These are regression ceilings, not measured hardware performance claims. `scripts/measure_dinx_session.sh` records RSS/CPU snapshots from `/proc` when a DINX session is actually running.

The current Artix profile remains one combined desktop/gaming/hardware ISO because `buildiso` consumes one `profile.yaml`; DinitUI's Normal/Lite/Gaming policies provide runtime service separation. The package set is intentionally documented as one payload until the builder supports composable package groups without duplicating the root overlay.

The content check proves that the root and live-session SquashFS images contain the expected compositor, shell, greeter, session, fallback terminal, Nano recovery editor, Pori dinit storage manager, Phyto file manager, kernel `ntfs3` support, SANE scanner backend, fwupd firmware tooling, Flatpak runtime, KolourPaint image editor and dinit payloads. `scripts/check_desktop_packages.sh` and `scripts/check_pori_phyto.sh` verify the package/profile contracts before the build. `scripts/smoke-install.sh` also executes the offline contract on ephemeral BIOS and UEFI disks, checks the dinit first boot and enables recovery TTYs. The workflow's PPM capture is visual evidence to inspect, not arbitrary hardware qualification.
The live-session contract also proves `AUTOLOGIN=true`, the live-only autologin dinit service and the unchanged installed-system greeter boundary.

The payload contract also requires `wdisplays`, `shikane` and the DINX display persistence entry points. Dome and ZLS external sources are pinned; Seafoam Settings is built from checked-in repository source. All three are required and checked as part of the base ISO payload.

The workflow stores a separate `dinx-boot-screen.ppm` capture taken before the boot-menu keys are sent. Review this frame when qualifying the GRUB kernel-selection surface; it is the regression evidence for the removed opaque menu panel.

GRUB uses the DINX surface, foreground and primary selection colors while retaining the Artix logo/font assets. The opaque menu textures are disabled, so the boot menu, greeter, installer and desktop share the same flat visual hierarchy.
The normal live path is direct autologin; the greeter remains a fallback surface rather than a required boot step.

## Profile boundary

The repository vendors a compact common package manifest at `iso-profiles/common/common.yaml` instead of relying on the installed `iso-profiles` default. It keeps the full DINX desktop/gaming/hardware payload while removing generic firmware and `powertop` from the final image and excluding build-only kernel headers from the final SquashFS images; its SHA-256 is recorded in `build-metadata.txt`. `WORKSPACE_DIR` in `scripts/build-iso.sh` selects both local manifests deterministically.
The current tagged release evidence is [workflow 39924316082](https://github.com/rufl/DINX/actions/runs/39924316082) for [v0.1.0-alpha.9](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.9), on commit `0d1698a462d5d5486871a7aa17e9b97352ee9404`. It passed checksum generation, compact SquashFS payload validation, QEMU boot and graphical capture, Calamares BIOS/UEFI/Btrfs partition transaction smoke, disposable BIOS and UEFI installation/first-boot/recovery-TTY smoke, build-metadata verification, provenance attestation and release publication. The direct ISO is 2,008,801,280 bytes, below the 2 GiB per-asset limit. Network, audio, authenticated Steam/game use, real DRM gaming output, physical hardware and upgrade/rollback qualification remain outside this result.

A post-release `main` validation [run 39934458077](https://github.com/rufl/DINX/actions/runs/39934458077) on commit `eb9a0c143c06d9c1939f9d88684d164d8e2384fb` completed in 52m02s with the build, boot, graphical payload, BIOS/UEFI persistent-install and recovery-TTY, attestation and upload checks. It confirms the contracts after Alpha 9 but does not publish a new release.

## Build validation

A successful image build is not the release criterion. The resulting ISO requires:

1. checksum generation;
2. SquashFS content validation;
3. a VM boot and installation smoke test;
4. recovery-TTY verification;
5. network, audio, D-Bus, portal and graphics checks;
6. an install/upgrade report before it is labelled alpha.
