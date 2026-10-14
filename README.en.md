# DINX

[English](README.en.md) · [Português (Brasil)](README.md)

DINX is a public alpha Linux platform for gaming and development.

The initial platform target is **x86_64**, based on **Artix Linux with dinit**, and built around a Wayland desktop using **MangoWC** and **Noctalia Shell**.

> Alpha software. Do not install it on systems that contain data you cannot restore.

## Product family

- **DINX** — the operating-system image, packages, integration contracts and release tooling.
- **Noctty** — a terminal emulator with a Zig-owned UI and a proven terminal-emulation core.
- **Nocted** — a lightweight code editor with syntax support, LSP and Git integration.
- **Dinx Control** — graphical service and system management for dinit.
- **Dinx Theme** — versioned shared design tokens and application-integration contracts.

The applications should integrate deeply with DINX while remaining usable on other Linux systems whenever their platform requirements are available.

## Application repositories

- [Noctty](https://github.com/rufl/noctty) — private alpha terminal.
- [Nocted](https://github.com/rufl/nocted) — private alpha code editor.

The applications have their own repositories for independent development cycles while remaining connected to DINX shared contracts and releases.


## Initial architecture

- Artix Linux + dinit
- Wayland + MangoWC + Noctalia Shell
- PipeWire, D-Bus, portals, polkit and GPU acceleration
- Zig as the primary application language, with mature libraries and bindings where they reduce risk
- Versioned contracts for themes, XDG paths, `.desktop` metadata, `$TERMINAL` invocation and optional Noctalia IPC
- Separate gaming session based on Gamescope and Steam; it must not depend on a full Noctalia desktop session underneath

## Delivery policy

The monorepo is public on GitHub during the alpha. Alpha ISOs and packages remain pre-release artifacts until each release is deliberately published. Every artifact must carry its exact version, commit identity, checksum and known limitations.

The project is a monorepo so shared contracts and release tooling remain versioned with the applications:

```text
docs/
shared/
apps/noctty/
apps/nocted/
apps/dinx-control/
distro/
tests/
scripts/
```

## Milestones

1. **P0 — Foundation:** reproducible Artix+dinit base, bootable ISO, graphical login, networking, audio, GPU acceleration and recovery TTY.
2. **P1 — Public alpha:** install documentation, checksums, package signing, known issues and a fallback terminal.
3. **P2 — Noctty:** reliable PTY lifecycle, terminal semantics, rendering, Unicode, scrollback, selection and compatibility with interactive TUIs.
4. **P3 — Nocted:** reliable editing, syntax highlighting, search, project navigation, LSP and Git status/diffs.
5. **P4 — Dinx Control:** safe dinit service management and useful system-status views.
6. **P5 — Gaming beta:** Gamescope/Steam session, controller and graphics validation, suspend/resume and update testing.

The alpha does not require all first-party applications to be complete. A known-good bootable system takes priority over branding or advanced UI features.

## Documentation

- [Architecture](docs/architecture.md)
- [Noctalia compatibility](docs/compatibility.md)
- [Security model](docs/security-model.md)
- [Easy installation guide](docs/install.md)
- [Security policy](SECURITY.md)
- [P0 build status](docs/p0-build.md)
- [Alpha release process](docs/release.md)
- [ISO foundation](distro/iso/README.md)
- [License](LICENSE)

Portuguese (Brazil) versions:

- [Arquitetura](docs/pt-BR/architecture.md)
- [Compatibilidade com Noctalia](docs/pt-BR/compatibility.md)
- [Modelo de segurança](docs/pt-BR/security-model.md)
- [Status do build P0](docs/pt-BR/p0-build.md)
- [Fundação da ISO](distro/iso/README.pt-BR.md)

## Current status

The P0 foundation now includes pinned wlroots/MangoWM/Scenefx package builds, the Artix ISO workflow, payload/checksum validation, QEMU boot smoke and automated graphical login in a VM. The release workflow now publishes tagged pre-releases with ISO checksums, Linux visual evidence and a Windows QEMU/ZTASH launcher package for DDJARIN qualification. The current image remains a validation live session; persistent installation, complete service health and recovery-TTY verification remain release gates.
