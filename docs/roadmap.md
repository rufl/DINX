# DINX roadmap

[English](roadmap.md) · [Português (Brasil)](pt-BR/roadmap.md)

Milestones are capability gates, not calendar promises.

## Current phase

**P2 — Noctty (active).** P1's public-alpha exit criterion is met by `v0.1.0-alpha.5`: an invited tester can obtain the release, verify it, follow the installation guide and use the documented recovery path without reconstructing the development environment. Pacman repository signing, physical hardware reports and qualification beyond the VM remain explicit post-alpha release gates.

## P0 — foundation

**Goal:** produce a reproducible, bootable Artix+dinit live system and define the persistent installation path.

**Status:** the ISO/VM foundation gate is complete. Hardware installation, upgrades, rollback and long-term hardware service health remain release gates.

Backlog:

- qualify the selected Calamares offline installer, dinit target and standalone partitioner;
- define the base package manifest and DINX-specific package boundary;
- configure Wayland, MangoWC, Noctalia Shell and the greeter;
- validate networking, PipeWire, D-Bus, portals, polkit and GPU acceleration;
- retain a recovery TTY and document recovery from a broken graphical session;
- add clean-build and VM boot/install smoke paths.

**Exit criterion:** a clean live boot logs in graphically, provides the required base services and can recover through a TTY. CI now exercises the persistent-install contract on a disposable BIOS disk; hardware installation, upgrades and rollback remain release gates.

## P1 — public alpha 0.1

**Goal:** distribute a known-good snapshot through the public GitHub project.

**Status:** complete for the public alpha snapshot `v0.1.0-alpha.5`.

Completed:

- published the ISO/parts, checksums, installation instructions, known issues and release metadata;
- qualified the experimental persistent installer and first-boot recovery path in CI on a disposable BIOS disk;
- provided the minimal terminal fallback and working shell configuration;
- recorded the package-signing limitation, hardware boundary and recovery limitations in the release documentation.

Deferred release gates:

- pacman repository signing key and signed package database;
- physical hardware reports and qualification beyond the VM.

**Exit criterion:** met. An invited tester can install the alpha snapshot from the public release and documentation without reconstructing the development environment.

## P2 — Noctty

**Goal:** ship a reliable terminal before advanced presentation features.

**Status:** active. The first DINX end-to-end tranche now builds the pinned Noctty source, runs headless PTY/VT/terminal-session smoke checks, allocator-accounted session qualification and protocol/Unicode compatibility qualification during package creation, installs the package into the ISO and routes `$TERMINAL` through Noctty with a Foot fallback.

Current end-to-end proof:

- the exact source archive is SHA-256 pinned and included in the Artix package build;
- the package build executes PTY spawn/resize/exit, VT grid/title/paste, terminal-session exit, allocator-accounted lifecycle and protocol/Unicode compatibility markers;
- the P0 ISO workflow [38798566993](https://github.com/rufl/DINX/actions/runs/38798566993) on commit `fbd9bd6` passed package creation, ISO generation, QEMU boot, graphical payload validation and persistent-install/recovery-TTY smoke;

Backlog:

- expand PTY and child-process lifecycle coverage beyond the current four normal and one forced qualification cycles;
- extend the shell launch, resize, signals and cleanup matrix beyond the current forced-process reaping check;
- terminal input/rendering, Unicode, colors and cursor behavior;
- scrollback, selection, copy and paste;
- extend compatibility qualification to real `vim`, `less`, `tmux`, SSH and common TUI sessions;
- `$TERMINAL`, `.desktop`, working-directory and Noctalia discovery integration;
- theme import/reload and preferences.

Tabs, panes, transparency and URL detection follow the core terminal semantics.

## P3 — Nocted

**Goal:** ship a useful lightweight code editor.

Backlog:

- file and directory opening;
- reliable text buffer, selection and undo/redo;
- syntax highlighting and project navigation;
- search/replace and configurable keybindings;
- LSP process management, diagnostics, definitions and references;
- Git status, diffs and change markers;
- Noctalia palette and dark/light integration.

**Exit criterion:** a developer can work on a Zig or C/C++ project, inspect diagnostics and Git changes, and edit without a second editor.

## P4 — Dinx Control

**Goal:** make common dinit operations understandable and safe.

Backlog:

- service listing and accurate status;
- start, stop and restart with structured errors;
- dependencies and available logs;
- startup profile and hardware-status views;
- constrained privilege escalation and compatibility tests.

## P5 — gaming beta

**Goal:** make the gaming session repeatably usable.

Backlog:

- Gamescope and a separate Steam session;
- controller, audio, game launch and session exit tests;
- return to the greeter after game exit;
- 32-bit graphics libraries and common gaming dependencies;
- suspend/resume, GPU recovery and update testing on real hardware.

**Exit criterion:** a game can be launched and exited repeatedly without leaving the desktop in a broken state.
