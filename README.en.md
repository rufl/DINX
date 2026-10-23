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
  <a href="https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.9"><img alt="Latest alpha release" src="https://img.shields.io/github/v/release/rufl/DINX?include_prereleases&amp;sort=semver&amp;label=alpha&amp;color=38bdf8"></a>
  <a href="https://github.com/rufl/DINX/actions/workflows/p0-iso.yml"><img alt="P0 validation status" src="https://github.com/rufl/DINX/actions/workflows/p0-iso.yml/badge.svg?branch=main"></a>
  <img alt="Stage: P5 gaming beta" src="https://img.shields.io/badge/stage-P5%20gaming%20beta-f59e0b">
  <a href="LICENSE"><img alt="Apache 2.0 license" src="https://img.shields.io/github/license/rufl/DINX?color=22c55e"></a>
</p>

> **Public alpha software.** Back up your data before testing. The installer is experimental; physical hardware and gaming claims still have explicit boundaries.

## Start here

| If you want to… | Go to |
|---|---|
| Download the current image | [DINX v0.1.0-alpha.9](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.9) |
| Install and boot safely | [Easy installation guide](docs/install.md) |
| See what is actually qualified | [P0 evidence](docs/p0-build.md) |
| Understand the alpha boundaries | [Roadmap](docs/roadmap.md) and [compatibility](docs/compatibility.md) |
| Read the release changes | [Changelog](CHANGELOG.md) |
| Read in Portuguese | [README em Português](README.md) |

## Alpha 9 at a glance

[v0.1.0-alpha.9](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.9) is the current public snapshot. Tagged release [workflow 39924316082](https://github.com/rufl/DINX/actions/runs/39924316082), on commit `0d1698a462d5d5486871a7aa17e9b97352ee9404`, passed the static contracts, Artix package builds, compact ISO creation and boot, graphical payload validation, Calamares BIOS/UEFI/Btrfs smokes, persistent installation and recovery-TTY smokes on disposable BIOS/UEFI disks, metadata verification, persistent package signing, provenance attestation and publication.

| Item | Evidence |
|---|---|
| ISO | 2,008,801,280 bytes, with a direct ISO and published SHA-512 checksum |
| DINX repository | Signed snapshot `01fc8270e5f0fa0339647c9bbde5934ec247a7c29cf235940d4ea9dcedab5827` |
| Image | x86_64 Artix Linux with dinit |
| Stage | P5 — Gaming beta; P4 DinitUI is qualified for the alpha gate |

## What DINX is

DINX is an Artix distribution focused on a small, legible and controllable desktop session:

- **Artix Linux + dinit** as the base;
- **Wayland, labwc and Noctalia Shell** for the graphical session;
- **PipeWire, D-Bus, portals, polkit and GPU acceleration** in the ISO payload;
- **DinitUI and DINXPanel** for services, Normal/Lite/Gaming profiles, system shortcuts, drivers and Artix kernels;
- a separate **DINX Gaming session** with Gamescope/Steam and a 32-bit graphics payload;
- **Calamares, GParted, File Roller, Pori and Phyto** for installation, partition editing, archive handling, storage and file management; DINX's **Display Setup** wrapper opens **wdisplays**, saves the named **Shikane** profile on close and reapplies it with the session daemon, while the kernel `ntfs3` driver covers NTFS read/write;

The optional **Dome** system monitor is delivered through the signed Seafoam package group rather than the base ISO. Its resource/process views remain useful on dinit; its optional systemd service provider is unavailable by design.

The same optional Seafoam group provides **Seafoam Settings**, a compact native Zig/GTK4 launcher for display, labwc, DinitUI, DINXPanel, Qt and Dome entry points, plus **ZLS 0.16.0** for Zig language-server support in Nocted. Neither package is in the base ISO; install them from the signed optional repository when needed.

Noctty, Nocted and the remaining integration contracts stay versioned with the distribution when that reduces risk and keeps the ISO reproducible.
Aqueous and Pearl are planned as an alternate Zig compositor/shell option, not a shipped Alpha 9 session. Their upstream session currently depends on `uwsm` and systemd user units; DINX will not expose a session entry until a dinit-native package is qualified. Labwc + Noctalia remains the supported session, with no silent compositor fallback.

Run `dinx-doctor` for a read-only snapshot of the current session, dinit boundary, storage/display paths and installed DINX packages. Set `DINX_DOCTOR_QUERY_DINIT=1` only when you also want it to query the user dinit socket; it never starts, stops, mounts or updates anything.


## Quick install

1. Download [v0.1.0-alpha.9](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.9). The direct ISO is 2,008,801,280 bytes; verify the published SHA-512 file.
2. Verify it before writing:

   ```bash
   sha512sum -c dinx-0.1.0-alpha.9-x86_64.iso.sha512
   ```

3. Write the verified ISO to the whole USB device, boot in UEFI mode and select `Labwc (DINX)` in the greeter. The tested live login is `dinx` / `dinx`.

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
