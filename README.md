# DINX

DINX is a private alpha Linux platform for gaming and development.

The initial platform target is **x86_64**, based on **Artix Linux with dinit**, and built around a Wayland desktop using **MangoWC** and **Noctalia Shell**.

> Alpha software. Do not install it on systems that contain data you cannot restore.

## Product family

- **DINX** — the operating-system image, packages, integration contracts and release tooling.
- **Noctty** — a terminal emulator with a Zig-owned UI and a proven terminal-emulation core.
- **Nocted** — a lightweight code editor with syntax support, LSP and Git integration.
- **Dinx Control** — graphical service and system management for dinit.
- **Dinx Theme** — versioned shared design tokens and application-integration contracts.

The applications should integrate deeply with DINX while remaining usable on other Linux systems whenever their platform requirements are available.

## Initial architecture

- Artix Linux + dinit
- Wayland + MangoWC + Noctalia Shell
- PipeWire, D-Bus, portals, polkit and GPU acceleration
- Zig as the primary application language, with mature libraries and bindings where they reduce risk
- Versioned contracts for themes, XDG paths, `.desktop` metadata, `$TERMINAL` invocation and optional Noctalia IPC
- Separate gaming session based on Gamescope and Steam; it must not depend on a full Noctalia desktop session underneath

## Delivery policy

The repository is intended to remain **private on GitHub during the alpha**. Alpha ISOs and packages are private release artifacts until a release is deliberately opened. Every artifact must carry its exact version, commit identity, checksum and known limitations.

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
2. **P1 — Private alpha:** install documentation, checksums, package signing, known issues and a fallback terminal.
3. **P2 — Noctty:** reliable PTY lifecycle, terminal semantics, rendering, Unicode, scrollback, selection and compatibility with interactive TUIs.
4. **P3 — Nocted:** reliable editing, syntax highlighting, search, project navigation, LSP and Git status/diffs.
5. **P4 — Dinx Control:** safe dinit service management and useful system-status views.
6. **P5 — Gaming beta:** Gamescope/Steam session, controller and graphics validation, suspend/resume and update testing.

The alpha does not require all first-party applications to be complete. A known-good bootable system takes priority over branding or advanced UI features.

## Documentation

- [Architecture](docs/architecture.md)
- [Noctalia compatibility](docs/compatibility.md)
- [Security model](docs/security-model.md)
- [Roadmap](docs/roadmap.md)

## Current status

The repository is at the documentation and foundation stage. The next implementation increment is P0: establish the build inputs and produce a bootable, testable Artix+dinit image before making Noctty, Nocted or Dinx Control mandatory.
