<p align="center">
  <img src="distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/branding/dinx/dinx.svg" alt="DINX logo" width="180">
</p>

<h1 align="center">DINX</h1>

<p align="center">
  <strong>A practical Artix Linux alpha with dinit, a fast Wayland desktop, and a clear path toward gaming.</strong><br>
  Small footprint. Explicit boundaries. No silent system changes.
</p>

<p align="center">
  <a href="README.md">Português (Brasil)</a> ·
  <a href="README.en.md">English</a>
</p>

<p align="center">
  <a href="https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.8"><img alt="Latest alpha release" src="https://img.shields.io/github/v/release/rufl/DINX?include_prereleases&amp;sort=semver&amp;label=alpha&amp;color=38bdf8"></a>
  <a href="https://github.com/rufl/DINX/actions/workflows/p0-iso.yml"><img alt="P0 validation status" src="https://github.com/rufl/DINX/actions/workflows/p0-iso.yml/badge.svg?branch=main"></a>
  <img alt="Stage: P5 gaming beta" src="https://img.shields.io/badge/stage-P5%20gaming%20beta-f59e0b">
  <a href="LICENSE"><img alt="Apache 2.0 license" src="https://img.shields.io/github/license/rufl/DINX?color=22c55e"></a>
</p>

> **Public alpha software.** Back up your data before testing. The installer is experimental; physical hardware and gaming claims still have explicit boundaries.

## Start here

| If you want to… | Go to |
|---|---|
| Download the current image | [DINX v0.1.0-alpha.8](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.8) |
| Install and boot safely | [Easy installation guide](docs/install.md) |
| See what is actually qualified | [P0 evidence](docs/p0-build.md) |
| Understand the alpha boundaries | [Roadmap](docs/roadmap.md) and [compatibility](docs/compatibility.md) |
| Read the release changes | [Changelog](CHANGELOG.md) |
| Read in Portuguese | [README em Português](README.md) |

## Alpha 8 at a glance

[v0.1.0-alpha.8](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.8) is the current public snapshot. Tagged release [workflow 39611695024](https://github.com/rufl/DINX/actions/runs/39611695024), on commit `eea66ac`, passed the static contracts, Artix package builds, ISO creation and boot, graphical payload validation, Calamares BIOS/UEFI/Btrfs smokes, persistent installation and recovery-TTY smokes on disposable BIOS/UEFI disks, metadata verification, persistent package signing, attestation and publication.

| Item | Evidence |
|---|---|
| ISO | 2,803,349,504 bytes, with published parts and SHA-512 checksum |
| DINX repository | Signed snapshot `5a61d50f3837161bed1af7619965b44e80bd885e79457e443c328e0151d805d9` |
| Image | x86_64 Artix Linux with dinit |
| Stage | P5 — Gaming beta; P4 DinitUI is qualified for the alpha gate |

## What DINX is

DINX is an Artix distribution focused on a small, legible and controllable desktop session:

- **Artix Linux + dinit** as the base;
- **Wayland, MangoWC and Noctalia Shell** for the graphical session;
- **PipeWire, D-Bus, portals, polkit and GPU acceleration** in the ISO payload;
- **DinitUI and DINXPanel** for services, Normal/Lite/Gaming profiles, system shortcuts, drivers and Artix kernels;
- a separate **DINX Gaming session** with Gamescope/Steam and a 32-bit graphics payload;
- **Calamares and KDE Partition Manager** for the experimental installation path.

Noctty, Nocted and the remaining integration contracts stay versioned with the distribution when that reduces risk and keeps the ISO reproducible.

## Quick install

1. Download [v0.1.0-alpha.8](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.8). The ISO is larger than 2 GiB, so download every `*.iso.part-*` asset plus the manifest and checksum.
2. Concatenate and verify before writing it:

   ```bash
   cat dinx-0.1.0-alpha.8-x86_64.iso.part-* > dinx-0.1.0-alpha.8-x86_64.iso
   sha512sum -c dinx-0.1.0-alpha.8-x86_64.iso.sha512
   ```

3. Write the verified ISO to the whole USB device, boot in UEFI mode and select `MangoWM (DINX)` in the greeter. The tested live login is `dinx` / `dinx`.

Read the [easy installation guide](docs/install.md) before partitioning. It covers Windows side-by-side layouts, recovery TTYs, device verification and installer limits.

## What is proven

| Qualified in the release | Not claimed yet |
|---|---|
| x86_64 QEMU boot and expected graphical payload | Physical hardware matrix |
| Calamares BIOS/UEFI/Btrfs partition transaction | Real DRM session and gaming selection from the greeter |
| Disposable BIOS/UEFI installation, dinit first boot and recovery TTY | Authenticated Steam, commercial game, controller and PipeWire audio |
| Checksums, metadata, attestation and signed DINX package repository | Suspend/resume, GPU recovery and installed-ISO upgrades/rollback |

## Documentation

- [Architecture](docs/architecture.md)
- [Easy installation guide](docs/install.md)
- [Noctalia compatibility](docs/compatibility.md)
- [P0 build status](docs/p0-build.md)
- [Roadmap](docs/roadmap.md)
- [Release process](docs/release.md)
- [Hardware qualification](docs/alpha7-qualification.md) — the utility retains the `dinx-alpha7-hardware-report` name for compatibility
- [ISO foundation](distro/iso/README.md)
- [Security model](docs/security-model.md)
- [Changelog](CHANGELOG.md)
- [Apache 2.0 license](LICENSE)

## Code and contracts

DINX is a public monorepo that keeps desktop contracts, packages, the ISO profile, qualification checks and release tooling together. Applications should integrate deeply with the platform while remaining usable on other Linux systems when their requirements are available.

- [GitHub source](https://github.com/rufl/DINX)
- [Issues](https://github.com/rufl/DINX/issues)
- [Releases](https://github.com/rufl/DINX/releases)
- [Validation workflow](https://github.com/rufl/DINX/actions/workflows/p0-iso.yml)
