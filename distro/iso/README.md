# DINX ISO foundation

[English](README.md) · [Português (Brasil)](README.pt-BR.md)

This directory contains the first Artix `artools` profile for DINX and the local build entry points.

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

The workflow also captures the QEMU VGA surface through its monitor. To request the same evidence locally:

```bash
DINX_QEMU_SCREENSHOT=dist/iso/dinx/graphical-screen.ppm \
DINX_QEMU_SCREENSHOT_DELAY=45 \
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

`iso-profiles/dinx/profile.yaml` now includes MangoWM, Scenefx, Noctalia, greetd and ReGreet. MangoWM and Scenefx are built from pinned upstream release archives in `distro/packages`; the workflow publishes them to a temporary local pacman repository before invoking `buildiso`. The profile's `root-overlay` supplies the greetd configuration, ReGreet actions, MangoWM sessions and the Noctalia autostart.

The content check proves that the ISO contains the expected compositor, shell, greeter, session and dinit payloads. The workflow's PPM capture is visual evidence to inspect, not an automated interactive login check: graphical login, service health and recovery TTY remain release gates.

## Profile boundary

The profile uses the Artix common package manifest supplied by the installed `iso-profiles` package and adds DINX-specific inputs locally. `WORKSPACE_DIR` in `scripts/build-iso.sh` makes profile selection deterministic.

## Build validation

A successful image build is not the release criterion. The resulting ISO requires:

1. checksum generation;
2. SquashFS content validation;
3. a VM boot smoke test;
4. recovery-TTY verification;
5. network, audio, D-Bus, portal and graphics checks;
6. an install/upgrade report before it is labelled alpha.
