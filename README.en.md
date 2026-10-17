# DINX

[English](README.en.md) · [Português (Brasil)](README.md)

DINX is a public alpha Linux platform for gaming and development.

The initial platform target is **x86_64**, based on **Artix Linux with dinit**, and built around a Wayland desktop using **MangoWC** and **Noctalia Shell**.

> Alpha software. Do not install it on systems that contain data you cannot restore.

## Product family

- **DINX** — the operating-system image, packages, integration contracts and release tooling.
- **Noctty** — a terminal emulator with a Zig-owned UI and a proven terminal-emulation core.
- **Nocted** — a lightweight code editor with syntax support, LSP and Git integration.
- **DinitUI** — a native GTK4/libadwaita frontend focused on Dinit services, units and daemon actions.
- **BC250 Control Center** — upstream-based BC-250 telemetry, tuning and recovery UI packaged for DINX's Artix/dinit session.
- **Dinx Theme** — versioned shared design tokens and application-integration contracts.

The applications should integrate deeply with DINX while remaining usable on other Linux systems whenever their platform requirements are available.

## Application repositories

- [Noctty](https://github.com/rufl/noctty) — private alpha terminal.
- [Nocted](https://github.com/rufl/nocted) — private alpha code editor.
- DinitUI is currently developed in `distro/packages/dinitui` so its Dinit/ISO contract stays versioned with DINX; it can move to a dedicated repository after the package boundary stabilizes.

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
distro/
  packages/dinitui/
tests/
scripts/
```

## Milestones

1. **P0 — Foundation:** reproducible Artix+dinit base, bootable ISO, graphical login, networking, audio, GPU acceleration and recovery TTY.
2. **P1 — Public alpha:** install documentation, checksums, package signing, known issues and a fallback terminal.
3. **P2 — Noctty:** reliable PTY lifecycle, terminal semantics, rendering, Unicode, scrollback, selection and compatibility with interactive TUIs.
4. **P3 — Nocted:** reliable editing, syntax highlighting, search, project navigation, LSP and Git status/diffs.
5. **P4 — DinitUI:** safe dinit service management and useful system-status views.
6. **P5 — Gaming beta:** Gamescope/Steam session, controller and graphics validation, suspend/resume and update testing.

The alpha does not require all first-party applications to be complete. A known-good bootable system takes priority over branding or advanced UI features.

## Current phase

**P5 — Gaming beta (in progress).** P4 DinitUI is now release-qualified end to end: Zig tests/ReleaseSafe build, Arch package payload, static contracts, the real temporary Dinit user-daemon/GTK qualification and the P0 ISO gate all pass. Run [38989297207](https://github.com/rufl/DINX/actions/runs/38989297207) on commit `86edd35` built and booted the ISO, verified its graphical payload, completed the disposable persistent-install/recovery-TTY smoke, attested the ISO/checksum and uploaded the artifact. P5 has a standalone Gamescope/Steam session contract, 32-bit graphics profile entries, launcher fixtures and a real headless Gamescope launch/exit qualification. Authenticated Steam/game/controller/audio paths, gaming-session greeter selection, a real DRM display session, physical hardware and suspend/resume remain unclaimed gates. P1 closed with the public `v0.1.0-alpha.5` release; P2 and P3 are closed by the recorded workflow evidence.

## Documentation

- [Architecture](docs/architecture.md)
- [Noctalia compatibility](docs/compatibility.md)
- [Security model](docs/security-model.md)
- [Easy installation guide](docs/install.md)
- [Security policy](SECURITY.md)
- [P0 build status](docs/p0-build.md)
- [Roadmap](docs/roadmap.md)
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

The public [v0.1.0-alpha.5 release](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.5), published from commit `1953457`, remains the public validation snapshot. The latest P0 gate is run [38989297207](https://github.com/rufl/DINX/actions/runs/38989297207), on commit `86edd35`; it passed Artix package builds, ISO creation, QEMU boot, graphical payload validation, persistent-install/recovery-TTY smoke, attestation and artifact upload. The temporary workflow artifact is `dinx-foundation-iso-86edd3562a0b734a3e4fcf44e34638573145af3a`, 2,710,227,069 bytes, digest `sha256:343e10f0aae3e55d1cfd643513cf13793db5ef4fd31f4ca852fab6de63f7ae35`. P4 DinitUI is closed for the alpha gate; the image remains a validation live session with an experimental installer, while hardware installation, complete service health, UEFI, upgrades, rollback and pacman repository signing remain later gates.
