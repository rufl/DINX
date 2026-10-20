# DINX architecture

[English](architecture.md) · [Português (Brasil)](pt-BR/architecture.md)

## Principles

1. **Integrate deeply, depend loosely.** DINX applications share contracts and user experience without requiring the whole distribution at runtime.
2. **Use proven low-level components.** Terminal emulation, text editing, parsing and language tooling are integration points, not reasons to reimplement mature subsystems.
3. **Make the bootable system the first product.** Applications are added only after installation, login, recovery and updates are testable.
4. **Keep privileged operations narrow.** User interfaces must not turn arbitrary input into privileged shell commands.
5. **Make common tasks work on first boot.** Media playback, hardware diagnostics, default handlers, tray applications, recovery and package-source boundaries must have a working default or an explicit unavailable state.
6. **Prefer standards over ecosystem lock-in.** DINX uses XDG metadata, Wayland protocols, PipeWire, desktop entries and documented package interfaces so applications do not need DINX-only behavior to remain usable.
7. **Require evidence before claims.** Every shipped feature has a static, fixture, CI, QEMU or physical-hardware gate; experimental paths remain visibly labeled instead of being presented as finished.

## System layers

```text
DINX applications
  Noctty · Nocted · DinitUI · DINXPanel

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

DinitUI also owns explicit `normal`, `lite`, `gaming` and user-defined system-service profiles. `lite` disables only the optional Bluetooth daemon; `gaming` explicitly enables `bluetoothd` for controllers and leaves Bluetooth, UFW, and OpenSnitch policy services available. NetworkManager, D-Bus, PipeWire, WirePlumber, elogind, greetd, seatd, metalog and display services remain outside the default policy. The profile editor persists user policy at `~/.config/dinx/dinitui/profiles.conf` and exposes `--profile-status`, `--apply-profile`, `--toggle-profile`, `--gaming-enter`, `--gaming-leave`, `--gpu-status` and `--install-gpu-drivers` for shell integration.

### DINXPanel

DINXPanel is the YaST-inspired control center. It owns the visible hardware and driver actions, groups fixed entry points for network, Bluetooth, display, audio, firewall, MangoWC, Dinit services, package upgrades and firmware, and exposes a fixed Artix kernel catalog (`linux`, `linux-lts`, `linux-zen`, `linux-hardened`). Its read-only upgrade report uses Shelly and optional fwupd metadata; Topgrade preview uses `--dry-run --show-skipped`; explicit upgrades remain user-confirmed terminal workflows. Kernel actions install packages and headers only; they never remove the running kernel, require a reboot, and use the bootloader to select an already-installed alternative for rollback.

Printing is an explicit post-install option rather than an ISO dependency:
DINXPanel downloads the fixed `cups-dinit` package from the configured Artix
repository, which pulls CUPS and provides the `cupsd` dinit service. The user
enables or starts that service through DinitUI when printing is required.

DINX ships a local Noctalia `dinx/performance` plugin. Its Control Center shortcut applies the Gaming profile and synchronizes Noctalia's documented `performance`/`balanced` power profile. The standalone Gamescope session does not start Noctalia and therefore remains independent of this integration.
### Session safety and payload budgets

The Mango session starts the fixed `dinx-idle` wrapper. It uses `swayidle` to lock after 600 seconds and on `before-sleep`; `dinx-lock`, `Super+L`, the Noctalia launcher and DINXPanel use the same `swaylock` path. `brightnessctl` backs the standard hardware keys and fixed 5-percent DINXPanel controls. These actions are fixed argv paths with no user-provided command string.

The profile has one combined Artix package payload because `buildiso` consumes one YAML profile. DinitUI separates Normal/Lite/Gaming service policy at runtime, while `scripts/check_dinx_budget.sh` prevents package/startup/binary growth. `scripts/measure_dinx_session.sh` is a runtime observation tool; it reports RSS/CPU only when a real session exists and does not substitute for hardware qualification.

## Shared contracts

Shared contracts are versioned independently from application internals:

- theme schema and design tokens;
- application configuration locations under XDG conventions;
- `.desktop` metadata and command-line behavior;
- `$TERMINAL` invocation and working-directory behavior;
- optional Noctalia IPC and notification adapters;
- logging and diagnostic conventions.

A contract must have a documented version and a compatibility test before applications rely on it.

The DINX Theme v1 contract is a Noctalia custom palette: semantic surface/text/primary/error roles, light/dark variants, a complete ANSI terminal palette, Cantarell 11 for GUI-facing bridges, square control geometry and Adwaita icon bridging. GTK/Qt/Mango consume the documented Noctalia template outputs; ReGreet, Calamares, Swayimg and GRUB use static bridges with the same tokens. Qt's Fusion backend, fixed-width Monospace 10 fields, DinitUI/DINXPanel monospace log views and GRUB's `u_vga16 16` remain intentional platform boundaries. `scripts/check_dinx_theme.sh` is the contract qualification.

## Gaming session

Gaming is a separate session built around Gamescope and Steam. `dinx-gaming` starts `gamescope --backend drm --steam --fullscreen -- steam -tenfoot` from a standalone `dbus-run-session` Wayland desktop entry; it does not assume that Noctalia or Mango is running underneath. The profile carries Steam's 32-bit Mesa/RADV/Vulkan dependencies and `steam-devices`; the P0 builder explicitly enables Artix's official `lib32` repository and does not add Arch repositories. `scripts/gaming_p5_qualification.sh` proves launcher argv/return behavior with fixtures, signal-time process-group cleanup and profile restoration, and a real headless Gamescope child launch/exit; it does not claim an authenticated Steam login, a commercial game, controller/audio hardware, DRM display, suspend/resume or GPU recovery.

## Installation path selected


**KDE Partition Manager** is the standalone graphical disk tool offered beside Calamares. It shares the Qt/kpmcore stack already used by Calamares and runs as a native Wayland application in the DINX session. It is intended for disk inspection and preparation before installation, not as a replacement for the installer's final mount-point selection.

The persistent installation path is **Calamares** in offline mode: it copies the ISO root filesystem, creates the user and filesystem table, enables the dinit services, installs GRUB and removes the live-only packages. The user can choose automatic or manual partitioning, with ext4 and btrfs available in the first profile. The profile also ships `ntfs-3g`/`os-prober`, preserves an existing Windows ESP/NTFS layout, and enables a separate DINX EFI boot directory. CI qualifies disposable BIOS/UEFI, Btrfs-existing-subvolume and Windows side-by-side/manual transaction smokes; the overall path remains experimental until destructive-device safeguards, physical hardware installation and upgrade/rollback behavior are qualified.

## Decisions still required before a production release

The installer path is selected, but these decisions remain open before a persistent production release:

- Wayland UI toolkit and backend for remaining first-party applications; DinitUI selects GTK4/libadwaita with the native GTK Wayland backend;
- package repository layout and signing-key ownership;
- supported GPU and hardware matrix;
- repository and artifact license policy.

The ISO profile now has a checked-in feature-group manifest for foundation, desktop, gaming, hardware and optional packages. CI signs the temporary custom pacman repository with an ephemeral qualification key and records its content snapshot; production key ownership, signed repository publication and installed-system update/recovery remain separate release gates.

The P2 terminal core is selected for the alpha package; production release still requires the broader hardware, signing and redistribution gates.
