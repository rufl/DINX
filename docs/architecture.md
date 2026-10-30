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
  Deetty · Dintor · DinitUI · DINXPanel · Seafoam Settings · Dome · ZLS (base ISO)

Shared integration contracts
  Dinx Theme · XDG paths · .desktop metadata · $TERMINAL · standard D-Bus adapters

Desktop session
  Wayland · Aqueous · Pearl · Pearl Greeter host

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
- Pori manages disks and mounts through UDisks2, with persistent dinit services under `/etc/dinit.d`;
- Phyto provides native file management and is the default directory handler; DINX includes File Roller for archive actions and GParted for standalone partition editing, while `wdisplays` and `shikane` cover Wayland display setup; Thunar, GVFS, Tumbler and KDE Partition Manager remain omitted;
- package manifests that identify every DINX-specific input;
- a known-good snapshot that can be reproduced from a clean build environment.

Upstream-compatible packages are preferred. DINX-specific packages and patches stay small, explicit and separately identifiable.

## Application boundaries

### Deetty

Deetty owns the window, preferences, keybindings, tabs/panes and theme integration. The P2 terminal boundary is the native Zig `Vt.Grid` and `TerminalSession`: it owns VT parsing, Unicode cells, cursor/modes, bounded scrollback, selection and paste. The `ghostty-vt-runtime` package supplies Ghostty's public VT adapter only; the Ghostty terminal application is not part of the DINX payload.

The P2 core decision is fixed by the deterministic protocol/Unicode corpus, allocator-accounted PTY lifecycle, fairness/large-paste lane and installed-application matrix for Vim, nano, less, dialog, tmux/Zellij launch profiles, SSH/SFTP and common TUIs. Replacing that core is a separate compatibility and migration decision, not an implicit P2 dependency.

### Dintor

Dintor is a lightweight code editor, not a full IDE. Its boundaries are:

- Zig application state and UI;
- an editor-engine adapter for buffers, selections, undo/redo and incremental updates;
- a proven syntax parser such as Tree-sitter;
- an LSP process/client layer;
- Git status, bounded unified diff output and per-file change markers are exposed through the editor's Tools action; Git is an optional project capability and never blocks opening or editing a file outside a repository.
- Dintor's LSP layer launches the server selected for the file type with bounded JSON-RPC framing. Zig uses the bundled `zls`; C/C++ uses `clangd`; diagnostics and navigation remain editor features rather than a shell dependency.
- The editor selects its documented light/dark scheme from `DINTOR_THEME` and falls back to the DINX dark scheme.

The editor remains useful without a shell session service or private IPC. Presentation and launcher integration are optional and use standard XDG/Wayland boundaries.

### DinitUI

DinitUI presents loaded and discoverable dinit services, status, buffered logs, service lifecycle, dependencies, environment and daemon actions. It uses a constrained `dinitctl` argv interface, validates service/argument tokens, handles Dinit's native nested list markers, and retries system-scope authorization only through `pkexec` after an explicit permission failure. It must not interpolate user text into shell commands. The real-daemon smoke uses a temporary Dinit user daemon and proves service discovery through the production GTK surface.

DinitUI also owns explicit `normal`, `lite`, `gaming` and user-defined system-service profiles. `lite` disables only the optional Bluetooth daemon; `gaming` explicitly enables `bluetoothd` for controllers and leaves Bluetooth, UFW, and OpenSnitch policy services available. NetworkManager, D-Bus, PipeWire, WirePlumber, elogind, greetd, seatd, metalog and display services remain outside the default policy. The profile editor persists user policy at `~/.config/dinx/dinitui/profiles.conf` and exposes `--profile-status`, `--apply-profile`, `--toggle-profile`, `--gaming-enter`, `--gaming-leave`, `--gpu-status` and `--install-gpu-drivers` for shell integration.

### DINXPanel

DINXPanel is the YaST-inspired control center. It owns the visible hardware and driver actions, groups fixed entry points for network, Bluetooth, display, audio, firewall, Dinit services, package upgrades and firmware, and exposes a fixed Artix kernel catalog (`linux`, `linux-lts`, `linux-zen`, `linux-hardened`). Its read-only upgrade report uses Shelly and optional fwupd metadata; Topgrade preview uses `--dry-run --show-skipped`; explicit upgrades remain user-confirmed terminal workflows. Kernel actions install packages and headers only; they never remove the running kernel, require a reboot, and use the bootloader to select an already-installed alternative for rollback.

Printing is an explicit post-install option rather than an ISO dependency:
DINXPanel downloads the fixed `cups-dinit` package from the configured Artix
repository, which pulls CUPS and provides the `cupsd` dinit service. The user
enables or starts that service through DinitUI when printing is required.

The standalone Gamescope session is independent of the Aqueous/Pearl session supervisor and does not install a shell plugin or systemd integration.

### Dome

`Dome` is a base native Zig/GTK4 system monitor delivered in the signed DINX package repository and included in the ISO. Its resource and process views are dinit-safe; the package installs no systemd, systemctl or uwsm integration.

### Seafoam Settings and ZLS

`Seafoam Settings` is a base native Zig/GTK4 launcher for DINX display/session surfaces: `dinx-wdisplays`, `dinx-save-shikane-profile`, Shikane, DinitUI, DINXPanel, Qt6ct and Dome. It uses fixed argument vectors, opens the documented Aqueous/Pearl and Shikane config files directly in Dintor, and runs the display-profile exporter in Deetty. Deetty is the sole terminal emulator in the ISO; Nano remains a recovery editor.

`zls` is the bundled source-pinned official Zig Language Server 0.16.0 package. It carries the matching Zig 0.16.0 `lib/std` tree and a metadata-only `/usr/lib/zls/zig-env` shim, so Dintor completion and navigation work in the base ISO without a full Zig compiler, systemd or a service. DINX native Zig packages are built with Zig 0.17.0; the 0.16.0 tree here is only the ZLS/LSP compatibility runtime. If the optional Artix `zig` package is installed later, the shim delegates compiler commands to it.
### Aqueous, Pearl and the dinit session boundary

Aqueous invokes `dinx-aqueous-init`; that child waits for the Wayland socket and session D-Bus, then starts supervised Shikane, PolicyKit, the required idle helper and Pearl. If BC-250 packages are separately installed from the signed repository on a machine with PCI `1002:13fe`, the supervisor starts the optional Control Center daemon. The generic ISO does not include those packages. `dinx-session-supervisor` records `starting`, `ready`, `failed` and `exited` state and terminates the compositor when a required helper or Pearl exits; if the supervisor itself is stopped, its cleanup path terminates the tracked compositor parent too. DINX removes upstream `uwsm` and systemd user-unit payloads. Installed/manual login uses Pearl Greeter: greetd launches its dedicated host through the `pearl-greeter` account, and `/etc/pearl/greeter.json` forces the same Aqueous/Pearl entry with X11 and UWSM disabled. Pearl Greeter is not a user-session fallback and never performs a silent session switch.

Before the compositor starts, `dinx-aqueous-pearl` runs `xdg-user-dirs-update` as the session user. Fresh live and installed accounts get the standard XDG directories, including `~/Desktop`, before Pearl starts.

Fresh Aqueous outputs start with two workspaces. This changes the startup default, not the maximum workspace count and not an existing user's saved configuration. Live and newly installed session accounts plus Pearl Greeter receive `render` group access. With an accessible DRM render node, the graphics helper selects reduced-effects GLES2 for QEMU `virtio_gpu`/virgl and VirtualBox VMSVGA (`vmwgfx`); absent/inaccessible render nodes and 2D-only virtual adapters use Pixman/Cairo. Other render-node hardware keeps the full Aqueous build. Host-side 3D enablement remains a separate hypervisor setting and is not proven by the static contract.

`dinx-doctor` is the read-only evidence surface for the current session, dinit, storage, display and package paths. It does not start services, mount devices, modify Shikane, run package transactions or contact a network. `DINX_DOCTOR_QUERY_DINIT=1` opts into a read-only user-dinit list query.


### Session safety and payload budgets

The Aqueous/Pearl session starts the fixed `dinx-idle` wrapper. It uses `swayidle` to lock after 600 seconds and on `before-sleep`; `dinx-lock`, `Super+L`, Pearl's lock surface and DINXPanel use the same `swaylock` path. `brightnessctl` backs the standard hardware keys and fixed 5-percent DINXPanel controls. These actions are fixed argv paths with no user-provided command string.

The profile has one combined Artix package payload because `buildiso` consumes one YAML profile. DinitUI separates Normal/Lite/Gaming service policy at runtime, while `scripts/check_dinx_budget.sh` prevents package/startup/binary growth. `scripts/measure_dinx_session.sh` is a runtime observation tool; it reports RSS/CPU only when a real session exists and does not substitute for hardware qualification.

## Manifest and CI boundary

`feature-groups.json` classifies the DINX rootfs payload and now also inventories the selected common, dinit-init, boot and livefs inputs. `scripts/check_dinx_feature_groups.sh` compares those inventories with the YAML sources, rejects duplicate group ownership and rejects optional packages entering the base profile. The unprivileged `contracts.yml` workflow runs these checks, the supervised-session/display/storage fixture smokes and the pinned Zig 0.17 Pori source smoke on pull requests; the privileged P0 workflow remains the build, QEMU and install gate.


## Shared contracts

Shared contracts are versioned independently from application internals:

- theme schema and design tokens;
- application configuration locations under XDG conventions;
- `.desktop` metadata and command-line behavior;
- `$TERMINAL` invocation and working-directory behavior;
- standard D-Bus notification adapters;
- logging and diagnostic conventions.

A contract must have a documented version and a compatibility test before applications rely on it.

The DINX Theme v1 contract is a static palette at `/usr/share/dinx/theme/DINX.json` with semantic surface/text/primary/error roles, light/dark variants, a complete ANSI terminal palette, Noto Sans 10 for GUI-facing bridges, square control geometry and Adwaita icon bridging. GTK uses the installed DINX theme; Qt uses the checked-in `DINX.conf`; Pearl Greeter uses `/etc/pearl/greeter.json` with the GTK DINX bridge. Pearl, Pearl Greeter, Calamares, Swayimg and GRUB use static bridges with the same tokens. Qt's Fusion backend, fixed-width Noto Sans Mono 10 fields, DinitUI/DINXPanel monospace log views and GRUB's `u_vga16 16` remain intentional platform boundaries. `scripts/check_dinx_theme.sh` is the contract qualification.

## Gaming session

Gaming is a hidden manual launcher, not a selectable user session. The base ISO retains only its launcher and desktop entry; Gamescope, Steam, Steam device rules, GameMode, MangoHud and 32-bit libraries are in the optional `gaming` feature group (`iso:false`) and come from Artix after installation. The base keeps 64-bit RADV and Vulkan tools. The P0 builder installs Gamescope only for headless qualification; it does not enable `[lib32]` or add gaming packages to the ISO. The launcher checks for Gamescope and Steam before changing the Dinit profile; the fixture verifies fail-closed behavior when either is missing. Real DRM output and authenticated gaming remain unqualified.

## Storage and filesystem boundary

Pori is the only DINX storage UI. It uses UDisks2 to discover block devices, and its persistent mount lifecycle is dinit-native: Pori writes supervised `process` services under `/etc/dinit.d` that invoke `/usr/local/libexec/pori-mount-service`, retry missing devices, keep the mount alive while the source is present and unmount only mounts owned by that service. It controls them with `dinitctl --system`; no systemd mount units are generated. Phyto is the only base file manager and the default `inode/directory` handler. File Roller provides archive open/create/extract actions and GParted provides standalone partition editing. DINX's `dinx-wdisplays` wrapper provides interactive Wayland output configuration, serializes concurrent exports with `flock`, atomically replaces the named `DINX wdisplays` profile in `~/.config/shikane/config.toml` and reports a failed Shikane reload instead of hiding it. Shikane starts inside Aqueous/Pearl and reapplies matching profiles when outputs change. The image omits competing file managers and volume monitors.

The kernel `ntfs3` module supplies NTFS read/write support in both the live ISO and the installed system. Pori maps UDisks2's `ntfs` filesystem type to `ntfs3`. The legacy `ntfs-3g` package is not in the ISO or base install; it remains an optional post-install package for compatibility and repair tooling. Windows Fast Startup and hibernation must be disabled before mounting a shared NTFS volume.

## Installation path selected


The base image includes Phyto as its default file manager, File Roller for archive actions, Pori as its dinit storage manager, GParted for standalone partition editing, `dinx-wdisplays` for interactive display configuration with persistent Shikane export, and the Shikane user daemon. The profile deliberately omits Thunar, GVFS, Tumbler and KDE Partition Manager rather than shipping competing file-manager, volume-monitor and partitioning stacks.

The persistent installation path is **Calamares** in offline mode: it copies the ISO root filesystem, creates the user and filesystem table, enables the dinit services, installs GRUB and removes the live-only packages. The user can choose automatic or manual partitioning, with ext4 and btrfs available in the first profile. The profile preserves existing Windows ESP/NTFS layouts, enables a separate DINX EFI boot directory and keeps `os-prober` for Windows discovery. CI qualifies disposable BIOS/UEFI, Btrfs-existing-subvolume and Windows side-by-side/manual transaction smokes; the overall path remains experimental until destructive-device safeguards, physical hardware installation, installed-ISO upgrades and filesystem recovery are qualified.

The base image does not ship KDE Partition Manager; GParted provides standalone graphical partition editing outside Calamares, while Calamares remains the installation transaction.

## Decisions still required before a production release

The installer path and package-repository layout are selected, but these decisions
remain open before a persistent production release:

- production package-signing-key ownership and GitHub secret provisioning;
- supported GPU and hardware matrix;
- repository and artifact license policy.

The ISO profile now has a checked-in feature-group manifest for foundation, desktop, gaming, hardware and optional packages. CI signs the custom pacman repository, records its content snapshot and qualifies signed install/update/downgrade transactions. Tagged publication still requires the production key secret; installed-system upgrades, filesystem recovery and physical hardware remain separate release gates.

The P2 terminal core is selected for the alpha package; production release still requires the broader hardware, key-provisioning and redistribution gates.
