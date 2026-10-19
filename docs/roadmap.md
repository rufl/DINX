# DINX roadmap

[English](roadmap.md) · [Português (Brasil)](pt-BR/roadmap.md)

Milestones are capability gates, not calendar promises.

## Current phase

**P5 — gaming beta (in progress).** P4 DinitUI is release-qualified end to end: implementation, local daemon/GTK qualification, package/ISO payload and the disposable persistent-install/recovery gate passed. Run [39244756515](https://github.com/rufl/DINX/actions/runs/39244756515) on commit `49c8a74` is the current P0 evidence, including BIOS and UEFI disposable disks, the Calamares BIOS/UEFI/Btrfs transaction smoke and build-metadata verification. P5 remains active because authenticated Steam/game/controller/audio, gaming-session greeter selection, a real DRM display session, greeter return after a real session, suspend/resume and physical GPU/update testing are still open.

## P0 — foundation

**Goal:** produce a reproducible, bootable Artix+dinit live system and define the persistent installation path.

**Status:** the ISO/VM foundation gate is complete. Hardware installation, physical UEFI/BIOS behavior, upgrades, rollback and long-term hardware service health remain release gates; CI's disposable BIOS and UEFI paths are green.

Backlog:

- qualify the selected Calamares offline installer, dinit target and standalone partitioner;
- define the base package manifest and DINX-specific package boundary;
- configure Wayland, MangoWC, Noctalia Shell and the greeter;
- validate networking, PipeWire, D-Bus, portals, polkit and GPU acceleration;
- retain a recovery TTY and document recovery from a broken graphical session;
- add clean-build and VM boot/install smoke paths.

**Exit criterion:** a clean live boot logs in graphically, provides the required base services and can recover through a TTY. CI exercises the persistent-install contract on disposable BIOS and UEFI disks; hardware installation, upgrades and rollback remain release gates.

## P1 — public alpha 0.1

**Goal:** distribute a known-good snapshot through the public GitHub project.

**Status:** complete for the public alpha snapshot `v0.1.0-alpha.6`.

Completed:

- published the ISO/parts, checksums, installation instructions, known issues and release metadata;
- qualified the experimental persistent installer and first-boot recovery path in CI on disposable BIOS and UEFI disks;
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

## P4 — DinitUI

**Goal:** make Dinit operations understandable, complete and safe without importing systemd concepts.

**Status:** release-qualified for the alpha gate. `zig build test`, ReleaseSafe builds, Arch package payloads, static contract checks, a real temporary Dinit user daemon and the production GTK smoke paths are qualified. Run [39244756515](https://github.com/rufl/DINX/actions/runs/39244756515) also passed the Artix package build, ISO payload, QEMU boot, Calamares BIOS/UEFI/Btrfs partition transaction smoke, disposable BIOS and UEFI persistent-install/first-boot/recovery-TTY smoke, build-metadata verification, provenance attestation and artifact upload. DINXPanel now owns the visible hardware/driver controls and fixed kernel installer; the broader hardware matrix remains a production-release gate.

**Delivered:**

- loaded-service discovery plus system/user description-file discovery;
- status, buffered logs and state-aware service rows;
- lifecycle, boot activation, dependency, environment, signal and daemon actions from Dinit's own `dinitctl` vocabulary;
- validated argv execution, system/user scopes and explicit `pkexec` retry only after authorization failure;
- `normal`, `lite`, `gaming` and custom system-service profiles, with a GTK editor, persistence and CLI integration;
- the local Noctalia `dinx/performance` plugin with a Control Center Gaming shortcut and profile panel;
- DINXPanel with fixed hardware/control-panel shortcuts, the DinitUI GPU backend bridge and a non-removing Artix kernel catalog;
- package, desktop metadata, license and ISO payload contracts.

## P5 — gaming beta

**Goal:** make the gaming session repeatably usable.

**Status:** session foundation implemented; the gaming exit criterion is not met.

**Delivered:**

- standalone `DINX Gaming` Wayland session with `dbus-run-session`, Gamescope DRM backend and Steam `-tenfoot`;
- Steam device package plus 32-bit Mesa/RADV/Vulkan payload entries;
- safe Normal/Lite/Gaming service semantics, transactional profile enter/restore around the standalone launcher, fixed GPU detection/driver plans for AMD, Intel and modern NVIDIA hardware, and the YaST-inspired DINXPanel with fixed control-panel shortcuts, Shelly/Topgrade upgrade actions, optional fwupd discovery and a non-removing Artix kernel installer;
- fixed launcher argv/return fixture and real headless Gamescope child launch/exit qualification;
- ISO payload and static contract checks for the session entry and binaries;
- GameMode and MangoHud are included in the gaming payload; `dinx-gaming`
  supports `DINX_GAMEMODE=auto|on|off` and optional `DINX_MANGOHUD=on|off`
  without weakening the normal launcher fallback.
- The ISO includes `dinx-alpha7-hardware-report` for read-only desktop, laptop,
  and BC-250 qualification evidence; real hardware claims remain manual.

**Remaining release gates:**

- a real DRM display session and gaming-session selection from the greeter;
- authenticated Steam startup, commercial game launch/exit, controller input and PipeWire audio;
- return to the greeter after an actual session exit;
- suspend/resume, GPU recovery and update testing on physical hardware.

**Exit criterion:** a game can be launched and exited repeatedly without leaving the desktop in a broken state. The current fixtures do not claim that criterion.
