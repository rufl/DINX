# DINX architecture

## Principles

1. **Integrate deeply, depend loosely.** DINX applications share contracts and user experience without requiring the whole distribution at runtime.
2. **Use proven low-level components.** Terminal emulation, text editing, parsing and language tooling are integration points, not reasons to reimplement mature subsystems.
3. **Make the bootable system the first product.** Applications are added only after installation, login, recovery and updates are testable.
4. **Keep privileged operations narrow.** User interfaces must not turn arbitrary input into privileged shell commands.

## System layers

```text
DINX applications
  Noctty · Nocted · Dinx Control

Shared integration contracts
  Dinx Theme · XDG paths · .desktop metadata · $TERMINAL · optional Noctalia IPC

Desktop session
  Wayland · MangoWC · Noctalia Shell · greeter

Operating-system foundation
  Artix Linux · dinit · kernel · Mesa/Vulkan · PipeWire · D-Bus · portals · polkit

Release and validation
  package manifests · signing · ISO build · checksums · VM smoke tests · hardware reports
```

## Distribution foundation

The first target is Artix Linux with dinit on x86_64. The base image must provide:

- a bootable ISO and a documented installation path;
- graphical login with a recovery TTY;
- networking, PipeWire, D-Bus, portals, polkit and accelerated graphics;
- package manifests that identify every DINX-specific input;
- a known-good snapshot that can be reproduced from a clean build environment.

Upstream-compatible packages are preferred. DINX-specific packages and patches stay small, explicit and separately identifiable.

## Application boundaries

### Noctty

Noctty owns the window, preferences, keybindings, tabs/panes and theme integration. A terminal adapter isolates the application from the selected terminal-emulation core. The adapter boundary covers input events, resize, clipboard, terminal-grid updates and rendering data.

The core selection is not final until candidates have been benchmarked with interactive shells, `vim`, `less`, `tmux`, SSH, Unicode, large scrollback and resize-heavy workloads. Candidate libraries include libvterm, libtsm and an embeddable Ghostty component where the public API, build requirements and license permit it.

### Nocted

Nocted is a lightweight code editor, not a full IDE. Its boundaries are:

- Zig application state and UI;
- an editor-engine adapter for buffers, selections, undo/redo and incremental updates;
- a proven syntax parser such as Tree-sitter;
- an LSP process/client layer;
- Git status, diff and change-marker integration.

The editor must remain useful without Noctalia. Noctalia supplies optional presentation and launcher integration, not the editor's core functionality.

### Dinx Control

Dinx Control presents dinit status and safe system actions. It must use a constrained service/action interface and a documented privilege boundary. It must not interpolate arbitrary service names or user text into shell commands.

## Shared contracts

Shared contracts are versioned independently from application internals:

- theme schema and design tokens;
- application configuration locations under XDG conventions;
- `.desktop` metadata and command-line behavior;
- `$TERMINAL` invocation and working-directory behavior;
- optional Noctalia IPC and notification adapters;
- logging and diagnostic conventions.

A contract must have a documented version and a compatibility test before applications rely on it.

## Gaming session

Gaming is a separate session built around Gamescope and Steam. It must not assume that the full Noctalia desktop is running underneath. Session entry, game launch, controller input, audio, session exit and return to the greeter are explicit acceptance paths.

## Decisions still required before the ISO implementation

These are intentionally not guessed in the initial documentation:

- ISO builder and installer path;
- greeter implementation;
- Wayland UI toolkit and rendering backend for first-party applications;
- final terminal-emulation core;
- package repository layout and signing-key ownership;
- supported GPU and hardware matrix;
- repository and artifact license policy.

The P0 implementation should resolve these from the available Artix tooling and concrete compatibility tests, not from assumptions.
