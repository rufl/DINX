<p align="center">
  <img src="distro/iso/iso-profiles/dinx/root-overlay/etc/calamares/branding/dinx/dinx.svg" alt="DINX logo" width="180">
</p>

<h1 align="center">DINX</h1>

<p align="center">
  <strong>Artix Linux + dinit, with a small and explicit Wayland desktop.</strong><br>
  A public alpha for testing the base system, its limits and the installation path — without hiding what is unfinished.
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

> **Public alpha software.** Back up your data before testing. The live ISO and installer are experimental; a successful boot is not a hardware qualification.

## Start here

| If you want to… | Go to |
|---|---|
| Download the published image | [DINX v0.1.0-alpha.9](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.9) |
| Verify and install the ISO | [Installation guide](docs/install.md) |
| See what CI actually proved | [P0 build status](docs/p0-build.md) |
| Understand compatibility and limits | [Compatibility](docs/compatibility.md) · [Roadmap](docs/roadmap.md) |
| Read the release process | [Alpha release](docs/release.md) |
| Check licensing and REUSE coverage | [Licensing](docs/licensing.md) |
| Read in Portuguese | [README em Português](README.md) |

## In brief

DINX is an Artix distribution for a small, legible and controllable desktop session:

- **Artix Linux + dinit** as the base, without replacing the init system with systemd;
- **Aqueous + Pearl** as the only user session, started directly over dinit; **Pearl Greeter** is the greetd login UI and is hosted by Aqueous without systemd or UWSM;
- **DinitUI** and **DINXPanel** for service, hardware, driver and kernel profiles;
- **Calamares** for experimental installation, **GParted** for separate partition editing and **Pori** for persistent disks and mounts through dinit;
- **Phyto** as the default file manager and **File Roller** for opening, creating and extracting archives;
- **wdisplays + Shikane** for configuring Wayland displays and reapplying the layout across sessions;
- the kernel **ntfs3** module for NTFS read/write support in the live ISO and installed system;
- **Mesa Lavapipe** (`vulkan-swrast`) remains available to Vulkan apps; Aqueous uses a separate Pixman build without Vulkan effects on no-render-node and Virtio GPU systems, avoiding the QEMU crash while preserving the full-effects hardware compositor;
- **DINX Gaming** keeps its manual launcher hidden. The published Alpha 9 ISO still includes Gamescope, Steam and 32-bit libraries; the current source profile for Alpha 10 moves them to optional post-install packages. The profile retains 64-bit RADV/Vulkan; see the [install guide](docs/install.md).

`dinx-doctor` produces a read-only report of the session, dinit, storage/display paths and DINX packages. It does not start services, mount devices, perform package transactions or access the network. Set `DINX_DOCTOR_QUERY_DINIT=1` only when you also want it to query the user dinit socket.

The published Alpha 9 image also includes BC-250-specific packages. The current source profile for Alpha 10 excludes them from generic images, but that change is not available in a download until a new ISO is built and released. Install BC-250 software only after confirming PCI ID `1002:13fe`.

## Seafoam and the sole session in the base ISO

**Dome**, **Seafoam Settings** and **ZLS 0.16.0** are part of the base ISO and the signed DINX repository. Dome provides resource/process monitoring without installing or requiring systemd; Seafoam Settings groups display and session entry points; ZLS provides Zig LSP support in Nocted with the matching Zig standard library and a compact metadata shim, without requiring a full Zig compiler in the ISO. Pearl 0.3.0, including the upstream source used by Dome, and Phyto's bundled Pearl 0.2.8 source use their pinned Zig 0.16.0 toolchain; Pori, Aqueous and other DINX-native Zig packages outside that upstream Pearl tree use verified Zig 0.17.0.

**Aqueous 1.0.5** and **Pearl 0.3.0** ship in the base ISO. `Aqueous + Pearl (DINX)` is the only selectable user session and the live initial session: DINX starts Aqueous directly, runs the supervised Shikane/PolicyKit/idle helpers and execs Pearl without `systemd`, `systemctl`, `uwsm` or user units. Installed/manual login uses **Pearl Greeter**, launched directly by greetd through its dedicated `pearl-greeter` account; the Greeter forces the same Aqueous/Pearl entry and does not expose X11 or UWSM. If the live Aqueous/Pearl session exits, greetd falls back to Pearl Greeter rather than silently switching sessions.

## Current state

| Item | Status |
|---|---|
| Published release | `v0.1.0-alpha.9`, direct ISO of 2,008,801,280 bytes |
| Base | Artix Linux x86_64 with dinit |
| Stage | P5 — gaming beta; P4 DinitUI qualified for the alpha gate |
| Published release validation | [Workflow 39924316082](https://github.com/rufl/DINX/actions/runs/39924316082) |
| Last successful main ISO build | [Workflow 40637700291](https://github.com/rufl/DINX/actions/runs/40637700291), commit `f01f372cc9c93283bbc2a33de24c27aced1428bf`; ISO 2,065,172,480 bytes, before the current candidate changes |
| Latest main P0 attempt | [Workflow 40848793262](https://github.com/rufl/DINX/actions/runs/40848793262) produced a 1,862,776,832-byte ISO and passed QEMU boot/capture, but failed payload validation: the livefs overlay inherits greetd from rootfs. Install smokes and attestation did not run. The local content-check fix passes against this ISO; a fresh P0 run is required. |

Alpha 9 remains the latest published release. The ISO from run 40848793262 is not an Alpha 10 release: it met the size limit and booted in QEMU, but full payload validation and installation smokes have not passed.


## Quick install

1. Download the ISO and `.iso.sha512` file from the [Alpha 9 release](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.9).
2. In the same directory, verify the file:

   ```bash
   sha512sum -c dinx-0.1.0-alpha.9-x86_64.iso.sha512
   ```

3. Write the verified ISO to the whole USB device — not a partition — and boot in UEFI mode.
4. The published Alpha 9 image follows its release snapshot. The next ISO built from `main` will open directly in `Aqueous + Pearl (DINX)`; no username or password will be requested.

Read the [installation guide](docs/install.md) before touching a disk. Windows Fast Startup and hibernation must be disabled before mounting a shared NTFS volume.

## Evidence and limits

| Current qualification covers | Not claimed yet |
|---|---|
| x86_64 boot and graphical payload in QEMU | Physical hardware matrix |
| Calamares BIOS/UEFI/Btrfs partition contracts | Secure Boot |
| Disposable BIOS/UEFI installation, dinit first boot and recovery TTY | Authenticated Steam, commercial game, controller and PipeWire audio |
| Compact ISO, checksums, metadata, attestation and signed repository | Suspend/resume, GPU recovery and installed-ISO upgrade/rollback |

## Documentation

- [Architecture](docs/architecture.md)
- [Installation guide](docs/install.md)
- [DINX compatibility](docs/compatibility.md)
- [P0 build status](docs/p0-build.md)
- [Roadmap](docs/roadmap.md)
- [Release process](docs/release.md)
- [Hardware qualification](docs/alpha7-qualification.md)
- [ISO foundation](distro/iso/README.md)
- [Security model](docs/security-model.md)
- [Licensing and REUSE](docs/licensing.md)
- [Changelog](CHANGELOG.md)

## Code, contracts and licensing

This repository keeps the ISO profile, packages, desktop integrations, qualification checks and release tooling together. DINX-owned entries are licensed under Apache-2.0. The versioned Noctty archive is separate upstream material under MIT; the coverage is declared in `REUSE.toml` and the license texts are in `LICENSES/`.

- [GitHub source](https://github.com/rufl/DINX)
- [Issues](https://github.com/rufl/DINX/issues)
- [Releases](https://github.com/rufl/DINX/releases)
- [Validation workflow](https://github.com/rufl/DINX/actions/workflows/p0-iso.yml)
