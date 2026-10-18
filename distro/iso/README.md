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

## Graphical profile

`iso-profiles/dinx/profile.yaml` now includes MangoWM, Scenefx, Noctalia, greetd, ReGreet and the native `noctty` package. The `noctty` package installs both NOCTTY and NoctEd, including their desktop files, icons, language specifications and dark editor style. CI consumes the committed source archive generated from the exact NOCTTY repository commit and SHA-256 contract declared in `distro/packages/noctty/source.env`; MangoWM and Scenefx are built from pinned upstream release archives in `distro/packages`. The workflow publishes all custom packages to a temporary local pacman repository before invoking `buildiso`. The profile's `root-overlay` supplies the greetd configuration, ReGreet actions, MangoWM sessions, the Noctalia autostart, a live-only no-op override for dinit's `root-ro` service and a Mango wrapper that enables software rendering only when the guest has no DRM render node.

The profile also owns the DINX visual bridges: `root-overlay/etc/skel/.config/noctalia/palettes/DINX.json` is the v1 source for dark/light semantic and ANSI colors; built-in Noctalia templates feed btop, Foot, Ghostty, GTK 3/4, Mango, KDE and Qt. `qt6ct`, `adw-gtk-theme` and Cantarell are installed for the corresponding consumers, with GTK and Qt fallbacks in the root overlay. `scripts/check_dinx_theme.sh` validates this contract before the ISO build.

The profile now includes the experimental Calamares installer and KDE Partition Manager. Calamares copies the ISO root filesystem offline, keeps dinit as the installed init system, and removes the live-only Artix packages during installation. KDE Partition Manager is available as a separate graphical disk tool for inspecting or preparing disks before opening the installer. Both destructive tools require an explicit user action; always verify the selected device.

The greeter, Noctalia and installer receive DINX defaults from the root overlay. ReGreet uses the installed DINX GTK theme; Calamares uses the same surface/text/primary/error tokens in its Qt stylesheet. Noctalia starts with the custom DINX palette, application templates, animations and panel/settings transparency disabled, but its Settings UI can change these defaults later. Mango starts with two virtual desktops; edit `~/.config/mango/config.conf` and change `tag_num` to add more. The Calamares dependency chain retains Plasma components for the installer, but the unsupported Plasma X11 and Wayland session entries are hidden from the DINX greeter, leaving MangoWM as the live session. The live session exposes `Instalar DINX` through the application launcher; the separate partitioner appears as `KDE Partition Manager`.
For removable storage, the profile includes Thunar, `thunar-volman`, GVFS, UDisks2, File Roller through `thunar-archive-plugin`, Nano and the standalone LXQt PolicyKit agent. Thunar runs as a background volume-monitoring process inside the Mango session; it is the file manager only, not the Xfce desktop. The session uses D-Bus, elogind and dinit, with no systemd dependency. Thunar is the default handler for `inode/directory`; Noctalia remains the desktop shell and no `xfdesktop`, Xfce session or full LXQt session is installed.

For web browsing, the profile installs Firefox and makes it the default HTML/XHTML/HTTP/HTTPS handler. The system policy at `/etc/firefox/policies/policies.json` disables sponsored New Tab and Firefox Suggest surfaces, Pocket/Stories, Firefox Studies/telemetry, browser recommendations, AI assistant/link-preview/tab-group surfaces and built-in IP Protection. Firefox Accounts remains an explicit user choice: DINX does not require sign-in or show onboarding prompts, while normal browser updates remain enabled.
The profile also ships btop/nvtop/inxi, PCI and USB diagnostics, Git/curl/less/jq/rsync, Zathura with the MuPDF backend as the normal PDF handler, Swayimg, VLC with its Qt GUI/CLI split, Strawberry, `wl-clipboard`, pwvucontrol, BlueZ/Blueman/UPower and `nm-connection-editor`. Swayimg is built from the pinned upstream 5.6 source with Wayland, JPEG and PNG support. Noctalia's Network, Bluetooth, Volume, Battery, Screenshot and Clipboard widgets are the primary shell surfaces; the standalone editors and players remain available from the launcher. Noctalia remains the primary screenshot path; transitive Artix package dependencies may also provide `grim` and `slurp`, while `wl-copy`/`wl-paste` remain available for CLI workflows.
The package-management payload adds `topgrade`, `paru` and Shelly. Topgrade uses a pinned upstream release binary with DINX's Artix `pacman` configuration; paru is built from its pinned source release against Artix ALPM; Shelly delegates to Artix's `pacman` configuration. Their package metadata has no `systemd` dependency or unit, no Arch repository is added, and AUR recipes remain subject to review. None starts automatically at boot.
For gaming, the P0 workflow enables Artix's official `[lib32]` repository in the `pacman.conf` consumed by `buildiso`; no Arch repository is added. This is required for the profile's `steam`, `steam-devices` and 32-bit Mesa/Vulkan packages.
For AMD Cyan Skillfish hardware such as the BC-250, the profile adds Artix's AMDGPU firmware, Mesa RADV and Vulkan tools plus the pinned SMU governor. Its dinit service is linked in both live and installed roots, detects PCI `1002:13fe`, applies the conservative 1000-1850 MHz config and does nothing on other hardware. This is an automatic dinit path, not a systemd service; use an Artix kernel with the current upstream BC-250 fixes (6.17.11 or newer; the Artix LTS kernel is preferred).
The profile also ships BC250 Control Center v1.21.1 from a SHA-256-pinned MIT source archive. Its GUI, CLI, polkit policy and headless daemon are available from the launcher and dock; Mango starts the daemon in the logged-in user session with `exec_once`. DINX removes the upstream systemd user unit and systemd Cyan drop-in, so this integration adds no systemd service and no root dinit service. On dinit, upstream service persistence is detection-only; live BC-250 telemetry remains the supported background path.
The firewall/process payload adds UFW with Artix's `ufw-dinit` service files, the Gufw GUI, OpenSnitch daemon/UI with a DINX dinit service, and Qps. UFW and OpenSnitch services are installed but not linked into boot by default: configure rules and deliberately enable the firewall policy you want. Do not enable both rule managers without reviewing the resulting netfilter ruleset.

DinitUI installs `normal`, `lite` and `gaming` service profiles and supports custom profiles at `~/.config/dinx/dinitui/profiles.conf`. `lite` only disables optional Bluetooth; Gaming enables Bluetooth for controllers and preserves firewall/process-policy services. The standalone launcher transactionally enters Gaming and restores the previous profile on exit. The Noctalia `dinx/performance` plugin is installed in the user skeleton; its Control Center Gaming shortcut applies the Dinit profile and synchronizes Noctalia's `performance` power profile. DINXPanel owns the visible hardware and driver actions, including fixed AMD/Intel/NVIDIA GPU plans delegated to DinitUI, fixed shortcuts for the main control panels, Shelly/Topgrade upgrade workflows, optional fwupd firmware discovery, and a safe installer for `linux`, `linux-lts`, `linux-zen` and `linux-hardened` with matching headers. It never removes the running kernel and requires a reboot after kernel or driver changes. The `dinx-gaming` session remains standalone and does not depend on Noctalia.
Mango opens new applications as floating windows by default, with `Super+Space` as the per-window toggle. The Noctalia `main` bar reserves the top edge, and the dock reserves the bottom edge.
### Session safety, hierarchy and resource guard

The session installs `swaylock`, `swayidle` and `brightnessctl`. `/usr/local/libexec/dinx-idle` locks after 600 seconds and locks again on `before-sleep`; `/usr/local/libexec/dinx-lock`, `Super+L`, the Noctalia launcher entry and DINXPanel provide the explicit lock path. Standard brightness keys and DINXPanel use fixed 5-percent `brightnessctl` steps. The Noctalia dock is reserved for primary DINX surfaces; specialist tools remain in the launcher.

`scripts/check_dinx_budget.sh` keeps the current profile below 128 rootfs package entries and 24 dinit startup entries, caps built DINXPanel/DinitUI binaries at 6 MiB each, limits the QEMU boot qualification window to 120 seconds, and checks a built ISO against a 4 GiB ceiling when `DINX_ISO_PATH` is supplied. These are regression ceilings, not measured hardware performance claims. `scripts/measure_dinx_session.sh` records RSS/CPU snapshots from `/proc` when a DINX session is actually running.

The current Artix profile remains one combined desktop/gaming/hardware ISO because `buildiso` consumes one `profile.yaml`; DinitUI's Normal/Lite/Gaming policies provide runtime service separation. The package set is intentionally documented as one payload until the builder supports composable package groups without duplicating the root overlay.

The content check proves that the root and live-session SquashFS images contain the expected compositor, shell, greeter, session, fallback terminal, Nano recovery editor, File Roller/Thunar archive integration and dinit payloads. `scripts/smoke-install.sh` also executes the offline contract on ephemeral BIOS and UEFI disks, checks the dinit first boot and enables recovery TTYs. The workflow's PPM capture is visual evidence to inspect, not arbitrary hardware qualification.

The workflow stores a separate `dinx-boot-screen.ppm` capture taken before the boot-menu keys are sent. Review this frame when qualifying the GRUB kernel-selection surface; it is the regression evidence for the removed opaque menu panel.

GRUB uses the DINX surface, foreground and primary selection colors while retaining the Artix logo/font assets. The opaque menu textures are disabled, so the boot menu, greeter, installer and desktop share the same flat visual hierarchy.

## Profile boundary

The profile uses the Artix common package manifest supplied by the installed `iso-profiles` package and adds DINX-specific inputs locally. `WORKSPACE_DIR` in `scripts/build-iso.sh` makes profile selection deterministic.
Run [39094147629](https://github.com/rufl/DINX/actions/runs/39094147629) on commit `f7bf044` passed the current successful validation sequence: checksum generation, SquashFS payload validation, QEMU boot, disposable BIOS installation/recovery TTY, build-metadata verification, provenance attestation and artifact upload. The UEFI smoke path is wired in the workflow but remains under qualification. Network, audio, authenticated Steam/game use, real DRM gaming output, physical hardware and upgrade/rollback qualification remain outside this result.

## Build validation

A successful image build is not the release criterion. The resulting ISO requires:

1. checksum generation;
2. SquashFS content validation;
3. a VM boot and installation smoke test;
4. recovery-TTY verification;
5. network, audio, D-Bus, portal and graphics checks;
6. an install/upgrade report before it is labelled alpha.
