# DINX roadmap

[English](roadmap.md) · [Português (Brasil)](pt-BR/roadmap.md)

Milestones are capability gates, not calendar promises.

## P0 — foundation

**Goal:** produce a reproducible, bootable Artix+dinit system.

Backlog:

- select and document the ISO builder and installer path;
- define the base package manifest and DINX-specific package boundary;
- configure Wayland, MangoWC, Noctalia Shell and the greeter;
- validate networking, PipeWire, D-Bus, portals, polkit and GPU acceleration;
- retain a recovery TTY and document recovery from a broken graphical session;
- add clean-build and VM boot/install smoke paths.

**Exit criterion:** a clean install boots, logs in graphically, provides the required base services and can recover through a TTY.

## P1 — private alpha 0.1

**Goal:** distribute a known-good snapshot inside the private GitHub project.

Backlog:

- publish the ISO, checksums, installation instructions and known issues;
- establish package signing and release metadata;
- provide a minimal terminal fallback and working shell configuration;
- collect hardware reports and prioritize installation blockers.

**Exit criterion:** an invited tester can install the system from the documentation without reconstructing the development environment.

## P2 — Noctty

**Goal:** ship a reliable terminal before advanced presentation features.

Backlog:

- PTY and child-process lifecycle;
- shell launch, resize, signals and cleanup;
- terminal input/rendering, Unicode, colors and cursor behavior;
- scrollback, selection, copy and paste;
- compatibility checks with `vim`, `less`, `tmux`, SSH and common TUIs;
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
