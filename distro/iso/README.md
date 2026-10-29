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


The workflow's QEMU boot smoke captures the VGA surface and uses Tesseract OCR to require a Pearl/Aqueous/DINX desktop marker while rejecting Pearl Greeter, login prompts and visible Dinit failures. Local smoke runs need `qemu-system-x86_64`, `socat`, `tesseract-ocr` and `tesseract-ocr-eng`:

```bash
DINX_QEMU_TIMEOUT=90 \
DINX_QEMU_BOOT_KEYS=down,down,ret \
DINX_QEMU_SCREENSHOT=dist/iso/dinx/graphical-screen.ppm \
DINX_QEMU_SCREENSHOT_DELAY=60 \
scripts/smoke-iso.sh dist/iso/<file>.iso
```

The smoke also checks the captured session frame. Without `DINX_QEMU_SCREENSHOT`, it saves the checked PPM beside the QEMU log as `<iso>.qemu.log.session.ppm`; `DINX_QEMU_OCR_LANG` selects another installed Tesseract model.


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
The P0 budget rejects ISOs at or above GitHub's 2 GiB asset limit; Alpha 10 is
1,862,772,736 bytes (284,710,912 bytes below the limit).

## Graphical profile

`iso-profiles/dinx/profile.yaml` includes Aqueous, Pearl, greetd and the native `noctty` package. The Pearl package supplies the Pearl Greeter; the `noctty` package installs NOCTTY and NoctEd, including desktop files, icons, language specifications and the dark editor style. CI consumes the committed source archive generated from the exact NOCTTY repository commit and SHA-256 contract declared in `distro/packages/noctty/source.env`. The root overlay supplies `/etc/greetd/config.toml`, `/etc/pearl/greeter.json` and hidden session metadata; Aqueous + Pearl is the only user-session entry.
The livefs adds the live-only `dinx-live-autologin` dinit package. It enables greetd's one-time `initial_session` for `dinx` with Aqueous + Pearl and supplies no-op root-remount units for the already-writable live overlay. These overrides stay in `livefs`; Calamares installs `rootfs.img`, which retains Artix's generic root-remount units.

`iso-profiles/dinx/feature-groups.json` records the foundation, desktop, gaming, hardware and optional package groups without replacing Artix's `profile.yaml`. The CI builder signs every locally built package and the temporary `dinx` repository database with an ephemeral key, checks package signatures and duplicate archive paths, and records the immutable package snapshot in `build-metadata.txt`. This is build qualification only; the production pacman repository key and installed-system update channel remain separate release prerequisites.

The profile owns static DINX visual bridges: `/usr/share/dinx/theme/DINX.json` is the source for semantic and ANSI colors; GTK and Qt consume checked-in DINX theme files, and `DINX_COLOR_SCHEME` is the user-session color contract. `qt6ct`, `adw-gtk-theme` and Noto Sans 10 are installed for the corresponding consumers, matching CachyOS's default GTK typography; Noto Sans Mono is used for fixed-width fields. The Pearl Greeter host reads `/etc/pearl/greeter.json`, uses the GTK DINX bridge and forces `Aqueous + Pearl (DINX)` with X11 and UWSM disabled; Aqueous/Pearl owns the only user-session contract. `scripts/check_dinx_theme.sh` validates this contract before the ISO build.

The profile includes the experimental Calamares installer and GParted for standalone partition editing. Calamares copies the ISO root filesystem offline, keeps dinit as the installed init system, and removes the live-only Artix packages during installation. The base image carries the kernel `ntfs3` driver for NTFS read/write access and `os-prober` for Windows discovery; legacy `ntfs-3g` remains an optional post-install package in the signed extra channel. Existing Windows ESP/NTFS layouts are preserved by the installer and use a separate DINX EFI directory.

Pearl Greeter, Aqueous/Pearl and the installer receive DINX defaults from the root overlay. Pearl Greeter uses the installed GTK DINX theme and the root-owned greeter JSON; Calamares uses the same surface/text/primary/error tokens in its Qt stylesheet. Pearl is the active user shell. The dedicated Aqueous host runs only Pearl Greeter and is not exposed as a user-session fallback. The Calamares dependency chain retains only installer components, unsupported session entries remain hidden, and `Aqueous + Pearl (DINX)` is the live session. The live session exposes `Instalar DINX` through the launcher.
The live path uses `Aqueous + Pearl (DINX)` without a credential prompt: a live-only dinit service prepares greetd before it starts. The installed rootfs keeps manual login and Calamares keeps both autologin flags disabled.
The runtime payload is Wayland/XWayland only: legacy Xorg/XLibre servers, drivers and Plasma session entries are omitted. Xvfb remains builder-only for package qualification.
For storage, Pori is the DINX disk/mount manager and Phyto is the default file manager. File Roller provides graphical archive actions and GParted provides standalone partition editing outside Calamares. Pori uses UDisks2 for block-device discovery and creates persistent scripted mount services under `/etc/dinit.d`; it does not use systemd units. The base image does not install Thunar, GVFS, Tumbler or KDE Partition Manager. Phyto handles directory browsing; the standalone LXQt PolicyKit agent remains for privileged actions, and Pearl remains the active shell.
For display setup, DINX's `dinx-wdisplays` wrapper opens the interactive Wayland editor; closing it atomically replaces the named `DINX wdisplays` profile in `~/.config/shikane/config.toml` and reloads the Shikane user daemon. Shikane starts inside Aqueous/Pearl and reapplies matching profiles when outputs change. `Dome`, `Seafoam Settings` and `zls` are part of the base ISO and the signed DINX package repository. Dome provides dinit-safe resource/process monitoring without systemd integration; Seafoam Settings is the fixed-argv native Zig/GTK4 launcher for the display/session entry points; ZLS is the bundled Zig language server used by Nocted with its matching `lib/std` tree and metadata-only shim, so the full Zig compiler remains optional. Aqueous 1.0.5 and Pearl 0.3.0 are the only selectable session components.

For web browsing, the profile installs Firefox and makes it the default HTML/XHTML/HTTP/HTTPS handler. The system policy at `/etc/firefox/policies/policies.json` disables sponsored New Tab and Firefox Suggest surfaces, Pocket/Stories, Firefox Studies/telemetry, browser recommendations, AI assistant/link-preview/tab-group surfaces and built-in IP Protection. Firefox Accounts remains an explicit user choice: DINX does not require sign-in or show onboarding prompts, while normal browser updates remain enabled.
The profile also ships btop/nvtop/inxi, PCI and USB diagnostics, Git/curl/less/jq/rsync, Zathura with the MuPDF backend, Swayimg, VLC, Strawberry, `wl-clipboard`, pwvucontrol, BlueZ/Blueman/UPower, `nm-connection-editor`, SANE's `scanimage` backend, `fwupdmgr`, the Flatpak runtime and KolourPaint. Swayimg is built from pinned upstream 5.6 with Wayland, JPEG and PNG support and remains the default image viewer. Pearl owns active shell surfaces and static DINX bridges; no shell plugin or private shell asset is required. No Flatpak applications are preinstalled.

CUPS is intentionally outside the offline profile. After installation,
DINXPanel offers the fixed `cups-dinit` download from the configured Artix
repository; the package pulls CUPS and provides the `cupsd` dinit service.
The package-management payload adds `topgrade`, `paru` and Shelly. Topgrade uses a pinned upstream release binary with DINX's Artix `pacman` configuration; paru is built from its pinned source release against Artix ALPM; Shelly delegates to Artix's `pacman` configuration. Their package metadata has no `systemd` dependency or unit, no Arch repository is added, and AUR recipes remain subject to review. None starts automatically at boot.
For gaming, the `gaming` feature group has `iso:false`; Gamescope, Steam, Steam device rules, GameMode, MangoHud and 32-bit libraries are excluded from the base rootfs/livefs. The base profile retains AMDGPU firmware, 64-bit Mesa RADV and Vulkan tools. P0 no longer enables Artix's `[lib32]` repository for ISO assembly; users can opt in after installation using the steps in [`docs/install.md`](../../docs/install.md). No Arch repository is added.
AMDGPU firmware, Mesa RADV and Vulkan tools remain generic AMD graphics support in the base profile. The BC-250-only Cyan Skillfish governor, its dinit package and BC250 Control Center are not installed in the generic live or installed root. CI keeps the pinned packages in the signed DINX repository.
Install those packages only after `lspci -n -d 1002:13fe` confirms the device; configure the signed DINX repository and follow the guarded steps in [`docs/install.md`](../../docs/install.md#optional-bc-250-support).
The governor package pulls its matching runtime and uses dinit; its wrapper applies the configured limits only to PCI `1002:13fe`. Use an Artix kernel with the current upstream BC-250 fixes (6.17.11 or newer; the Artix LTS kernel is preferred). The compact common manifest keeps AMDGPU firmware for general AMD GPU support but omits the generic `linux-firmware` bundle and `powertop`; it retains kernel headers for Artix initramfs generation while excluding their source tree from final SquashFS images.
The firewall/process payload adds UFW with Artix's `ufw-dinit` service files, the Gufw GUI, OpenSnitch daemon/UI with a DINX dinit service, and Qps. UFW and OpenSnitch services are installed but not linked into boot by default: configure rules and deliberately enable the firewall policy you want. Do not enable both rule managers without reviewing the resulting netfilter ruleset.

DinitUI installs `normal`, `lite` and `gaming` service profiles and supports custom profiles at `~/.config/dinx/dinitui/profiles.conf`. `lite` only disables optional Bluetooth; Gaming enables Bluetooth for controllers and preserves firewall/process-policy services. The standalone launcher enters Gaming and restores the previous profile on exit; entry or restoration failures stop the launcher and remain visible. DINXPanel owns the visible hardware and driver actions, fixed control-panel shortcuts, Shelly/Topgrade workflows, optional fwupd discovery and the safe Artix kernel installer; Aqueous/Pearl does not require a shell plugin.
The dedicated Pearl Greeter host provides the login surface for greetd. Pearl owns the active user shell; Aqueous/Pearl is the sole user session.
### Session safety, hierarchy and resource guard

The session installs `swaylock`, `swayidle` and `brightnessctl`. `/usr/local/libexec/dinx-idle` locks after 600 seconds and locks again on `before-sleep`; `/usr/local/libexec/dinx-lock`, `Super+L`, Pearl's lock surface and DINXPanel provide the explicit lock path. Standard brightness keys and DINXPanel use fixed 5-percent `brightnessctl` steps; specialist tools remain in the launcher.

`scripts/check_dinx_budget.sh` keeps the current profile at or below 128 rootfs package entries and 24 dinit startup entries, caps built DINXPanel/DinitUI binaries at 6 MiB each, limits the QEMU boot qualification window to 120 seconds, and enforces a built ISO below 2 GiB (`2147483647` bytes) when `DINX_ISO_PATH` is supplied. These are regression ceilings, not measured hardware performance claims. `scripts/measure_dinx_session.sh` records RSS/CPU snapshots from `/proc` when a DINX session is actually running.

The Artix builder still consumes one `profile.yaml`; the feature-group manifest is a contract, not a package-composition mechanism. The generic ISO profile contains the foundation and desktop groups while gaming and BC-250-specific packages remain outside the base image. DinitUI's Normal/Lite/Gaming service policies continue to provide runtime service separation.

The P0 content gate requires the root and live-session SquashFS images to contain the expected compositor, shell, greeter, session, fallback terminal, Nano recovery editor, Pori dinit storage manager, Phyto file manager, kernel `ntfs3` support, SANE scanner backend, fwupd firmware tooling, Flatpak runtime, KolourPaint image editor and dinit payloads. It also rejects optional gaming binaries and package metadata in both images. `scripts/check_desktop_packages.sh` and `scripts/check_pori_phyto.sh` verify package/profile contracts before the build. `scripts/smoke-install.sh` exercises the offline contract on ephemeral BIOS/UEFI disks, checks the dinit first boot and enables recovery TTYs. The workflow's PPM capture is visual evidence to inspect, not arbitrary hardware qualification.

The P0 live-session gate requires `AUTOLOGIN=true`, the live-only autologin dinit service and the unchanged installed-system greeter boundary.

The payload contract also requires `wdisplays`, `shikane` and the DINX display persistence entry points. Dome and ZLS external sources are pinned; Seafoam Settings is built from checked-in repository source. All three are required and checked as part of the base ISO payload.

The workflow stores a separate `dinx-boot-screen.ppm` capture taken before the boot-menu keys are sent. Review this frame when qualifying the GRUB kernel-selection surface; it is the regression evidence for the removed opaque menu panel.

GRUB uses the DINX surface, foreground and primary selection colors while retaining the Artix logo/font assets. The opaque menu textures are disabled, so the boot menu, greeter, installer and desktop share the same flat visual hierarchy.
In the current source profile, the normal live path is direct autologin; the greeter remains a fallback surface rather than a required boot step.

## Profile boundary

The repository vendors a compact common package manifest at `iso-profiles/common/common.yaml` instead of relying on the installed `iso-profiles` default. It keeps the DINX foundation and desktop payload while excluding optional gaming and BC-250 packages, generic firmware and `powertop`; build-only kernel headers are excluded from final SquashFS images. Its SHA-256 is recorded in `build-metadata.txt`. `WORKSPACE_DIR` in `scripts/build-iso.sh` selects both local manifests deterministically.

The latest successful main P0 run is [40870759044](https://github.com/rufl/DINX/actions/runs/40870759044) on commit `3fd3cd036cab7e8fb553e6e5c244b02429f1a18e`. It passed the build, compact SquashFS payload check, QEMU boot and graphical capture, Calamares partition transaction, and disposable BIOS/UEFI persistent-install and recovery-TTY smokes, followed by metadata verification, attestation and artifact upload. The previous UEFI marker race is fixed by ordering the marker after `early-root-rw.target`.

The current tagged release is [v0.1.0-alpha.10](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.10), validated by [workflow 40879223746](https://github.com/rufl/DINX/actions/runs/40879223746) on that commit. The published direct ISO is 1,862,772,736 bytes, below GitHub's 2 GiB asset limit, with SHA-512 `5f49a65eac1481c01555a8f44b049c9a06e75ec7270ac3cdef97cc5e0b051d4b3c48a200542a36ec1832700accbc5509e3c314726c2f747530095eba4112219a`. Network, audio, authenticated Steam/game use, real DRM gaming output, physical hardware and upgrade/rollback qualification remain outside this result.

## Build validation

A successful image build is not the release criterion. The resulting ISO requires:

1. checksum generation;
2. SquashFS content validation;
3. a VM boot and installation smoke test;
4. recovery-TTY verification;
5. network, audio, D-Bus, portal and graphics checks;
6. an install/upgrade report before it is labelled alpha.
