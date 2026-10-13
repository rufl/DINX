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

Run the prerequisite probe from the repository root:

```bash
scripts/check-iso-host.sh
```

Build the foundation profile:

```bash
scripts/build-iso.sh
```

Extra `buildiso` options are passed through unchanged. For example, query settings without building:

```bash
scripts/build-iso.sh -q
```

The default output directory is `dist/iso`; override it with `DINX_ISO_OUTPUT`. The chroot cache defaults to `/var/lib/artools/buildiso`; override it with `DINX_ISO_CHROOTS` when the builder uses another persistent volume.

## Profile boundary

`iso-profiles/dinx/profile.yaml` is the foundation profile. It selects the dinit service companions and the minimum Wayland/audio/networking pieces needed for the first boot validation. Noctalia, MangoWC, Noctty or Nocted are not silently substituted with unrelated applications; they enter the profile only after their package sources and licenses are verified.

The profile uses the Artix common package manifest supplied by the installed `iso-profiles` package and adds DINX-specific inputs locally. The `WORKSPACE_DIR` export in `scripts/build-iso.sh` makes the profile selection deterministic.

## Build validation

A successful image build is not the release criterion. The resulting ISO still requires:

1. checksum generation;
2. boot verification in a VM or on test hardware;
3. recovery-TTY verification;
4. network, audio, D-Bus, portal and graphics checks;
5. an install/upgrade report before it is labelled alpha.
