# DINX roadmap

[English](roadmap.md) · [Português (Brasil)](pt-BR/roadmap.md)

Milestones are capability gates, not calendar promises.

## Current phase

**P4 — Dinx Control (next).** P3 Nocted is complete in the source/package contract; the remaining post-alpha gates are the same release boundaries documented below.

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

**Status:** complete. P2 closed with the final green P0 workflow run recorded in [P0 build status](p0-build.md).

P2 exit evidence:

- the exact NOCTTY/NoctEd source archive is SHA-256 pinned, archive-verified and built into the Artix package;
- the native Zig core qualifies PTY spawn/resize/exit, VT grid/title/paste, terminal-session exit, protocol/Unicode compatibility, allocator-accounted lifecycle and fairness under 30 panes with an 8 MiB paste;
- the ReleaseSafe matrix qualifies actual tmux, a deterministic Zellij shim, real Nano/Less/Dialog, top/watch/whiptail/fzf/SQLite/Glances/Bash/man/local SFTP, real Vim/btop, and the installed `info` command or its deterministic styled fallback for minimal/non-TTY surfaces;
- the package is present in the ISO; `$TERMINAL`, shell defaults, `.desktop`, working-directory, Noctalia discovery and package-runtime contracts are verified;
- the final P0 workflow proves package creation, ISO generation, QEMU boot, graphical payload, persistent installation, recovery TTY, attestation and artifact upload.

Boundaries retained after P2:

- the Codex slot uses a local fixture by default; no authenticated Codex or network qualification is claimed;
- Zellij uses a deterministic shim, while tmux is exercised as the installed application;
- the installed `info` command is attempted first, but a minimal/non-TTY surface may use the styled fixture fallback;
- pacman signing, physical hardware, UEFI, upgrades, rollback and long-term production service health remain later release gates.

Tabs, panes, transparency and URL detection follow the core terminal semantics.

## P3 — Nocted

**Status:** complete. P3 closes with the pinned Nocted source, the DINX compatibility patch, the package/ISO payload, the P3 qualification gate, and the editor integration contract.

Delivered:

- file and directory opening, project trees, tabs, quick open and deterministic project navigation;
- reliable text buffers, selections, multi-selection replacement and GTK undo/redo;
- Tree-sitter and GtkSourceView syntax highlighting, folding and configurable editor behavior;
- in-file/project search, replacement through selection workflows and keyboard shortcuts;
- bounded LSP process/client management with diagnostics, completion, hover, definitions, references, rename, symbols and formatting;
- Git status, unified diffs and change markers exposed from the editor's Tools menu and the headless `--git-probe`;
- Noctalia-aware light/dark editor schemes through the documented `NOCTALIA_COLOR_SCHEME`/`NOCTED_THEME` environment contract, with useful operation independent of Noctalia.

P3 release gate:

- `scripts/nocted_p3_qualification.sh` runs core endurance, project-index scale/delta, worker, state-recovery, task, real `clangd`, native X11 GTK smoke in dark/light modes and a real Git fixture;
- `PKGBUILD`, the ISO profile, `check_noctty_integration.sh` and `check-iso-content.sh` carry the same Nocted/LSP/Git/theme contract;
- the P0 workflow remains the required package, ISO, QEMU, persistent-install, recovery and attestation gate.

**Exit criterion:** met. A developer can work on a Zig or C/C++ project, inspect diagnostics and Git changes, and edit without a second editor.

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
