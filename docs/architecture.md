# DINX architecture

[English](architecture.md) · [Português (Brasil)](pt-BR/architecture.md)

## Principles

1. **Integrate deeply, depend loosely.** DINX applications share contracts and user experience without requiring the whole distribution at runtime.
2. **Use proven low-level components.** Terminal emulation, text editing, parsing and language tooling are integration points, not reasons to reimplement mature subsystems.
3. **Make the bootable system the first product.** Applications are added only after installation, login, recovery and updates are testable.
4. **Keep privileged operations narrow.** User interfaces must not turn arbitrary input into privileged shell commands.

## System layers

```text
DINX applications
  Noctty · Nocted · DinitUI

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
- standalone Thunar file management with `thunar-volman`, GVFS, UDisks2 and a PolicyKit agent for removable media, without a full Xfce/LXQt session or systemd;
- package manifests that identify every DINX-specific input;
- a known-good snapshot that can be reproduced from a clean build environment.

Upstream-compatible packages are preferred. DINX-specific packages and patches stay small, explicit and separately identifiable.

## Application boundaries

### Noctty

Noctty owns the window, preferences, keybindings, tabs/panes and theme integration. The P2 terminal boundary is the native Zig `Vt.Grid` and `TerminalSession`: it owns VT parsing, Unicode cells, cursor/modes, bounded scrollback, selection and paste, while Ghostty's public VT/runtime surface remains an isolated adapter.

The P2 core decision is fixed by the deterministic protocol/Unicode corpus, allocator-accounted PTY lifecycle, fairness/large-paste lane and installed-application matrix for Vim, nano, less, dialog, tmux/Zellij launch profiles, SSH/SFTP and common TUIs. Replacing that core is a separate compatibility and migration decision, not an implicit P2 dependency.

### Nocted

Nocted is a lightweight code editor, not a full IDE. Its boundaries are:

- Zig application state and UI;
- an editor-engine adapter for buffers, selections, undo/redo and incremental updates;
- a proven syntax parser such as Tree-sitter;
- an LSP process/client layer;
- Git status, bounded unified diff output and per-file change markers are exposed through the editor's Tools action; Git is an optional project capability and never blocks opening or editing a file outside a repository.
- Nocted's LSP layer launches the server selected for the file type with bounded JSON-RPC framing. Zig uses `zls` when available; C/C++ uses `clangd`; diagnostics and navigation remain editor features rather than a Noctalia dependency.
- The editor selects its documented light/dark scheme from `NOCTALIA_COLOR_SCHEME` or `NOCTED_THEME` and falls back to the DINX dark scheme. Noctalia may provide the preference, but the editor remains functional without the shell.

The editor must remain useful without Noctalia. Noctalia supplies optional presentation and launcher integration, not the editor's core functionality.

### DinitUI

DinitUI presents loaded and discoverable dinit services, status, buffered logs, service lifecycle, dependencies, environment and daemon actions. It uses a constrained `dinitctl` argv interface, validates service/argument tokens, handles Dinit's native nested list markers, and retries system-scope authorization only through `pkexec` after an explicit permission failure. It must not interpolate user text into shell commands. The real-daemon smoke uses a temporary Dinit user daemon and proves service discovery through the production GTK surface.

## Shared contracts

Shared contracts are versioned independently from application internals:

- theme schema and design tokens;
- application configuration locations under XDG conventions;
- `.desktop` metadata and command-line behavior;
- `$TERMINAL` invocation and working-directory behavior;
- optional Noctalia IPC and notification adapters;
- logging and diagnostic conventions.

A contract must have a documented version and a compatibility test before applications rely on it.

The DINX Theme v1 contract is a Noctalia custom palette: semantic surface/text/primary/error roles, light/dark variants, and a complete ANSI terminal palette. GTK/Qt/Mango consume the documented Noctalia template outputs; ReGreet, Calamares and GRUB use static bridges with the same tokens. `scripts/check_dinx_theme.sh` is the contract qualification.

## Gaming session

Gaming is a separate session built around Gamescope and Steam. `dinx-gaming` starts `gamescope --backend drm --steam --fullscreen -- steam -tenfoot` from a standalone `dbus-run-session` Wayland desktop entry; it does not assume that Noctalia or Mango is running underneath. The profile carries Steam's 32-bit Mesa/RADV/Vulkan dependencies and `steam-devices`; the P0 builder explicitly enables Artix's official `lib32` repository and does not add Arch repositories. `scripts/gaming_p5_qualification.sh` proves launcher argv/return behavior with fixtures and proves a real headless Gamescope child launch/exit; it does not claim an authenticated Steam login, a commercial game, controller/audio hardware, DRM display, suspend/resume or GPU recovery.

## Installation path selected

The persistent installation path is **Calamares** in offline mode: it copies the ISO root filesystem, creates the user and filesystem table, enables the dinit services, installs GRUB and removes the live-only packages. The user can choose automatic or manual partitioning, with ext4 and btrfs available in the first profile.

**KDE Partition Manager** is the standalone graphical disk tool offered beside Calamares. It shares the Qt/kpmcore stack already used by Calamares and runs as a native Wayland application in the DINX session. It is intended for disk inspection and preparation before installation, not as a replacement for the installer's final mount-point selection.

The persistent installation path is **Calamares** in offline mode: it copies the ISO root filesystem, creates the user and filesystem table, enables the dinit services, installs GRUB and removes the live-only packages. The user can choose automatic or manual partitioning, with ext4 and btrfs available in the first profile. CI now qualifies the disposable BIOS install, first boot and recovery TTY; the path remains experimental until UEFI, destructive-device safeguards, hardware installation and upgrade/rollback behavior are qualified.

## Decisions still required before a production release

The installer path is selected, but these decisions remain open before a persistent production release:

- Wayland UI toolkit and backend for remaining first-party applications; DinitUI selects GTK4/libadwaita with the native GTK Wayland backend;
- package repository layout and signing-key ownership;
- supported GPU and hardware matrix;
- repository and artifact license policy.

The P2 terminal core is selected for the alpha package; production release still requires the broader hardware, signing and redistribution gates.
