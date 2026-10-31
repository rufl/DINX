<h1 align="center">
  <img src="distro/iso/iso-profiles/dinx/root-overlay/usr/share/dinx/branding/dinx-linux-logo.svg" alt="DINX Linux" width="420">
</h1>

<p align="center">
  <strong>Artix Linux + dinit, with a lean, simple, easy-to-use Wayland desktop.</strong><br>
  A public alpha for testing the base system, its limits and the installation path — without hiding what is unfinished.
</p>

<p align="center">
  <a href="README.md">Português (Brasil)</a> ·
  <a href="README.en.md">English</a>
</p>

<p align="center">
  <a href="https://github.com/rufl/DINX/releases/download/alpha-latest/dinx-latest-x86_64.iso"><img alt="Download latest alpha ISO" src="https://img.shields.io/badge/download-latest%20alpha%20ISO-ef3340?logo=linux&amp;logoColor=white"></a>
  <a href="https://github.com/rufl/DINX/releases/tag/alpha-latest"><img alt="Latest alpha release" src="https://img.shields.io/github/v/release/rufl/DINX?include_prereleases&amp;sort=semver&amp;label=alpha&amp;color=38bdf8"></a>
  <a href="https://github.com/rufl/DINX/actions/workflows/p0-iso.yml"><img alt="P0 validation status" src="https://github.com/rufl/DINX/actions/workflows/p0-iso.yml/badge.svg?branch=main"></a>
  <img alt="Next milestone: planned system Beta 0.1" src="https://img.shields.io/badge/next%20milestone-System%20Beta%200.1-f59e0b">
  <a href="LICENSE"><img alt="Apache 2.0 license" src="https://img.shields.io/github/license/rufl/DINX?color=22c55e"></a>
</p>

> **Public alpha software.** Back up your data before testing. The live ISO and installer are experimental; a successful boot is not a hardware qualification.

## Start here

| If you want to… | Go to |
|---|---|
| Download the latest alpha ISO (Alpha 0.12) | [Direct ISO](https://github.com/rufl/DINX/releases/download/alpha-latest/dinx-latest-x86_64.iso) · [SHA-512](https://github.com/rufl/DINX/releases/download/alpha-latest/dinx-latest-x86_64.iso.sha512) · [Alpha 0.12 release](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.12) · [Other releases](https://github.com/rufl/DINX/releases) |
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
- **Mesa/RADV and VM graphics:** fresh Aqueous outputs start with two workspaces. Alpha 12's release CI tested QEMU's default VGA, not the reported VirtualBox VMSVGA path. Current source applies driver-bound Pixman/Cairo to both the Aqueous session and Pearl Greeter for `vmwgfx`/2D virtual adapters, while accessible QEMU `virtio_gpu` retains GLES2. P0 now configures a VMware-SVGA QEMU boot/capture smoke; it has not run yet. Alpha 12 still needs a rebuilt ISO, and direct VirtualBox boot remains unqualified. See the [graphics guide](docs/install.md).
- **DINX Gaming** keeps its manual launcher hidden. The base ISO excludes Gamescope, Steam, GameMode, MangoHud, Steam device rules and 32-bit gaming libraries; users can opt into the gaming stack after installation. The base retains 64-bit RADV/Vulkan; see the [install guide](docs/install.md).

`dinx-doctor` produces a read-only report of the session, dinit, storage/display paths and DINX packages. It does not start services, mount devices, perform package transactions or access the network. Set `DINX_DOCTOR_QUERY_DINIT=1` only when you also want it to query the user dinit socket.

BC-250 software is not installed in the generic ISO. Its packages are available in the signed DINX repository; install them only after confirming PCI ID `1002:13fe`.

## Seafoam and the sole session in the base ISO

**Dome**, **Seafoam Settings** and **ZLS 0.16.0** are part of the base ISO and the signed DINX repository. Dome provides resource/process monitoring without installing or requiring systemd; Seafoam Settings groups display and session entry points; ZLS provides Zig LSP support in Dintor with the matching Zig standard library and a compact metadata shim, without requiring a full Zig compiler in the ISO. Pearl 0.3.0, including the upstream source used by Dome, and Phyto's bundled Pearl 0.2.8 source use their pinned Zig 0.16.0 toolchain; Pori, Aqueous and other DINX-native Zig packages outside that upstream Pearl tree use verified Zig 0.17.0.

**Aqueous 1.0.5** and **Pearl 0.3.0** ship in the base ISO. `Aqueous + Pearl (DINX)` is the only selectable user session and the live initial session: DINX starts Aqueous directly, runs the supervised Shikane/PolicyKit/idle helpers and execs Pearl without `systemd`, `systemctl`, `uwsm` or user units. Installed/manual login uses **Pearl Greeter**, launched directly by greetd through its dedicated `pearl-greeter` account; the Greeter forces the same Aqueous/Pearl entry and does not expose X11 or UWSM. If the live Aqueous/Pearl session exits, greetd falls back to Pearl Greeter rather than silently switching sessions.

## Current state

| Item | Status |
|---|---|
| Published release | [DINX Alpha 0.12 (`v0.1.0-alpha.12`)](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.12), direct ISO of 1,836,830,720 bytes |
| Base | Artix Linux x86_64 with dinit |
| Next milestone | System Beta 0.1: planned, not released, and undated |
| Gaming qualification | Separate P5 track; not complete |
| Alpha 12 ISO validation | [P0 build, QEMU graphical boot and installation](https://github.com/rufl/DINX/actions/runs/41197618617) passed; [release published](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.12) |
| Alpha 12 commit | `56a814575e33bfae6215993972784f11b7dae215`; [release workflow](https://github.com/rufl/DINX/actions/runs/41197618617) passed |

## Next milestone: System Beta 0.1

Beta 0.1 is planned, with no release date set. The goal is to qualify the Aqueous/Pearl session on dinit and the installation, update and recovery paths on a declared physical hardware matrix. Release requires physical network, audio, GPU/display and suspend testing, plus installation and recovery on disposable disks, signed updates and documented limits.

The [GitHub release-asset limit](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases) is **under 2 GiB** (`2,147,483,648` bytes); DINX has no smaller 1.8-billion-byte target. Alpha 12 is published as a direct ISO of 1,836,830,720 bytes, below that limit. Future ISOs must stay below it to publish as a direct asset. P5 gaming remains separate: Beta 0.1 will not claim support without real DRM, Steam, controller and audio tests. The session remains Aqueous/Pearl with dinit, without systemd or UWSM. [Full criteria in the roadmap](docs/roadmap.md).


Alpha 12 is published as a direct GitHub release asset below the 2 GiB per-asset limit. Verify its matching `.iso.sha512` file before writing it to a USB drive.


## Quick install

1. Download the [latest alpha ISO](https://github.com/rufl/DINX/releases/download/alpha-latest/dinx-latest-x86_64.iso) and its [SHA-512 file](https://github.com/rufl/DINX/releases/download/alpha-latest/dinx-latest-x86_64.iso.sha512).
2. In the same directory, verify the file:

   ```bash
   sha512sum -c dinx-latest-x86_64.iso.sha512
   ```

3. Write the verified ISO to the whole USB device — not a partition — and boot in UEFI mode.
4. The published Alpha 12 image opens directly in `Aqueous + Pearl (DINX)`; it does not request a username or password. Installed login and Calamares autologin remain disabled.

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

This repository keeps the ISO profile, packages, desktop integrations, qualification checks and release tooling together. DINX-owned entries are licensed under Apache-2.0. The versioned upstream NOCTTY archive is separate source material under MIT; the DINX package and applications are Deetty and Dintor. The coverage is declared in `REUSE.toml` and the license texts are in `LICENSES/`.

- [GitHub source](https://github.com/rufl/DINX)
- [Issues](https://github.com/rufl/DINX/issues)
- [Releases](https://github.com/rufl/DINX/releases)
- [Validation workflow](https://github.com/rufl/DINX/actions/workflows/p0-iso.yml)
