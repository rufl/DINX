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
Smoke-test the persistent install contract on a disposable BIOS disk:

```bash
DINX_INSTALL_OUTPUT_DIR=dist/iso/dinx \
scripts/smoke-install.sh dist/iso/<file>.iso
```

This extracts the ISO rootfs, removes live-only packages, creates a temporary ext4
disk, generates initramfs and BIOS GRUB, boots the disk in QEMU and captures the
recovery-TTY transition. It requires root or passwordless `sudo`, loop devices,
`grub-pc-bin`, QEMU and SquashFS tools. The disk is temporary and deleted after the
smoke; it is not a substitute for hardware qualification.


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

The profile also owns a DINX GRUB theme override at `iso-profiles/dinx/root-overlay/usr/share/grub/themes/artix/theme.txt`. It keeps the background, logo, icons and font supplied by Artix but removes the opaque menu-panel textures that appeared as a black square on the graphical kernel-selection screen. The content check requires this file inside the root SquashFS image.

The profile now includes the experimental Calamares installer and KDE Partition Manager. Calamares copies the ISO root filesystem offline, keeps dinit as the installed init system, and removes the live-only Artix packages during installation. KDE Partition Manager is available as a separate graphical disk tool for inspecting or preparing disks before opening the installer. Both destructive tools require an explicit user action; always verify the selected device.

The greeter and Noctalia receive dark-mode defaults from the root overlay. Noctalia starts with animations and panel/settings transparency disabled, but its Settings UI can override these defaults later. Mango starts with two virtual desktops; edit `~/.config/mango/config.conf` and change `tag_num` to add more. The Calamares dependency chain retains Plasma components for the installer, but the unsupported Plasma X11 and Wayland session entries are hidden from the DINX greeter, leaving MangoWM as the live session. Calamares uses DINX branding and a dark Qt stylesheet. The live session exposes `Instalar DINX` through the application launcher; the separate partitioner appears as `KDE Partition Manager`.
For removable storage, the profile includes Thunar, `thunar-volman`, GVFS, UDisks2, File Roller through `thunar-archive-plugin`, Nano and the standalone LXQt PolicyKit agent. Thunar runs as a background volume-monitoring process inside the Mango session; it is the file manager only, not the Xfce desktop. The session uses D-Bus, elogind and dinit, with no systemd dependency. Thunar is the default handler for `inode/directory`; Noctalia remains the desktop shell and no `xfdesktop`, Xfce session or full LXQt session is installed.

For web browsing, the profile includes the official Pale Moon GTK3 binary, FFmpeg media support and Pale Moon as the default HTML/HTTP/HTTPS handler. The seeded DINX profile uses Pale Moon `userChrome.css`/`userContent.css` files with a dark fallback. Noctalia v5 templates render the active palette into those files from documented semantic color tokens; changing the Noctalia palette or mode updates the files for the next Pale Moon restart.

The content check proves that the root and live-session SquashFS images contain the expected compositor, shell, greeter, session, fallback terminal, Nano recovery editor, File Roller/Thunar archive integration and dinit payloads. `scripts/smoke-install.sh` also executes the offline contract on an ephemeral BIOS disk, checks the dinit first boot and enables recovery TTYs. The workflow's PPM capture is visual evidence to inspect, not arbitrary hardware qualification.

The workflow stores a separate `dinx-boot-screen.ppm` capture taken before the boot-menu keys are sent. Review this frame when qualifying the GRUB kernel-selection surface; it is the regression evidence for the removed opaque menu panel.

## Profile boundary

The profile uses the Artix common package manifest supplied by the installed `iso-profiles` package and adds DINX-specific inputs locally. `WORKSPACE_DIR` in `scripts/build-iso.sh` makes profile selection deterministic.

## Build validation

A successful image build is not the release criterion. The resulting ISO requires:

1. checksum generation;
2. SquashFS content validation;
3. a VM boot and installation smoke test;
4. recovery-TTY verification;
5. network, audio, D-Bus, portal and graphics checks;
6. an install/upgrade report before it is labelled alpha.
