# DINX roadmap

[English](roadmap.md) · [Português (Brasil)](pt-BR/roadmap.md)

Milestones are capability gates, not calendar promises.

## Current phase

**P5 — gaming beta (in progress).** P4 DinitUI is release-qualified end to end: implementation, local daemon/GTK qualification, package/ISO payload and the disposable persistent-install/recovery gate passed. Tagged release run [39924316082](https://github.com/rufl/DINX/actions/runs/39924316082) on commit `0d1698a462d5d5486871a7aa17e9b97352ee9404` is the current P0 evidence, including BIOS and UEFI disposable disks, the Calamares BIOS/UEFI/Btrfs transaction smoke, build-metadata verification, persistent package signing and release publication. P5 remains active because authenticated Steam/commercial-game launch, controller/PipeWire audio, real DRM output, repeatable gaming-launcher exit with Dinit profile restoration, suspend/resume and physical GPU/update testing are still open.

The post-release `main` validation, [run 39934458077](https://github.com/rufl/DINX/actions/runs/39934458077), passed the build, boot, graphical payload, BIOS/UEFI persistent-install and recovery-TTY, attestation and upload checks; it did not publish another release. The newer P0 candidate [run 40848793262](https://github.com/rufl/DINX/actions/runs/40848793262) produced a 1,862,776,832-byte ISO and passed QEMU boot/capture but failed the payload gate. The local checker now passes against that artifact; installation smokes and attestation await a fresh P0 run.

## P0 — foundation

**Goal:** produce a reproducible, bootable Artix+dinit live system and define the persistent installation path.

**Status:** the ISO/VM foundation gate is complete. Signed custom pacman repository
publication plus package install/update/downgrade qualification is implemented in CI;
production key configuration, physical hardware, installed-ISO upgrades, filesystem
rollback and long-term hardware service health remain release gates.

Implementation delivered:

- the P0 ISO/VM foundation gate, signed package transaction path and recovery-TTY contract;
- the direct Aqueous/Pearl session, Pearl Greeter through greetd, and dinit-only runtime with no systemd/UWSM;
- the Fish defaults, base package boundary and clean-build/VM smoke paths.

Open foundation release gates:

- validate networking, PipeWire, D-Bus, portals, polkit and GPU acceleration on physical hardware;
- retain and exercise recovery after a broken graphical session;

**Exit criterion:** a clean live boot opens a graphical session, provides the required base services and can recover through a TTY. CI exercises the persistent-install contract on disposable BIOS and UEFI disks and the signed package transaction path; installed-ISO upgrades, filesystem rollback and data preservation remain release gates.

## P1 — public alpha 0.1

**Goal:** distribute a known-good snapshot through the public GitHub project.

**Status:** complete for the public alpha snapshot `v0.1.0-alpha.9`.

Completed:

- published the ISO/parts, checksums, installation instructions, known issues and release metadata;
- qualified the experimental persistent installer and first-boot recovery path in CI on disposable BIOS and UEFI disks;
- provided the minimal terminal fallback and working shell configuration;
- recorded the production-key prerequisite, hardware boundary and recovery limitations in the release documentation;

Deferred release gates:

- physical hardware reports and qualification beyond the VM;

**Exit criterion:** met. An invited tester can install the alpha snapshot from the public release and documentation without reconstructing the development environment.

## P2 — Noctty

**Status:** complete. P2 closed with the final green P0 workflow run recorded in [P0 build status](p0-build.md).

P2 exit evidence:

- the exact NOCTTY/NoctEd source archive is SHA-256 pinned, archive-verified and built into the Artix package;
- the native Zig core qualifies PTY spawn/resize/exit, VT grid/title/paste, terminal-session exit, protocol/Unicode compatibility, allocator-accounted lifecycle and fairness under 30 panes with an 8 MiB paste;
- the ReleaseSafe matrix qualifies actual tmux, a deterministic Zellij shim, real Nano/Less/Dialog, top/watch/whiptail/fzf/SQLite/Glances/Bash/man/local SFTP, real Vim/btop, and the installed `info` command or its deterministic styled fallback for minimal/non-TTY surfaces;
- the package is present in the ISO; `$TERMINAL`, shell defaults, `.desktop`, working-directory, Aqueous/Pearl discovery and package-runtime contracts are verified;
- the final P0 workflow proves package creation, ISO generation, QEMU boot, graphical payload, persistent installation, recovery TTY, attestation and artifact upload.

Boundaries retained after P2:

- the Codex slot uses a local fixture by default; no authenticated Codex or network qualification is claimed;
- Zellij uses a deterministic shim, while tmux is exercised as the installed application;
- the installed `info` command is attempted first, but a minimal/non-TTY surface may use the styled fixture fallback;
- production key configuration, installed-ISO upgrades, filesystem rollback, physical hardware and long-term production service health remain later release gates.

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

- DINX static light/dark editor schemes through the documented `DINX_COLOR_SCHEME`/`NOCTED_THEME` environment contract, with useful operation independent of a desktop shell;

P3 release gate:

- `scripts/nocted_p3_qualification.sh` runs core endurance, project-index scale/delta, worker, state-recovery, task, real `clangd`, native X11 GTK smoke in dark/light modes and a real Git fixture;
- `PKGBUILD`, the ISO profile, `check_noctty_integration.sh` and `check-iso-content.sh` carry the same Nocted/LSP/Git/theme contract;
- the P0 workflow remains the required package, ISO, QEMU, persistent-install, recovery and attestation gate.

**Exit criterion:** met. A developer can work on a Zig or C/C++ project, inspect diagnostics and Git changes, and edit without a second editor.

## P4 — DinitUI

**Goal:** make Dinit operations understandable, complete and safe without importing systemd concepts.

**Status:** release-qualified for the alpha gate. `zig build test`, ReleaseSafe builds, Arch package payloads, static contract checks, a real temporary Dinit user daemon and the production GTK smoke paths are qualified. Tagged release run [39924316082](https://github.com/rufl/DINX/actions/runs/39924316082) on commit `0d1698a462d5d5486871a7aa17e9b97352ee9404` also passed the Artix package build, ISO payload, QEMU boot, Calamares BIOS/UEFI/Btrfs partition transaction smoke, disposable BIOS and UEFI persistent-install/first-boot/recovery-TTY smoke, build-metadata verification, persistent package signing, provenance attestation and release publication. DINXPanel now owns the visible hardware/driver controls and fixed kernel installer; the broader hardware matrix remains a production-release gate.

**Delivered:**

- loaded-service discovery plus system/user description-file discovery;
- status, buffered logs and state-aware service rows;
- lifecycle, boot activation, dependency, environment, signal and daemon actions from Dinit's own `dinitctl` vocabulary;
- validated argv execution, system/user scopes and explicit `pkexec` retry only after authorization failure;
- `normal`, `lite`, `gaming` and custom system-service profiles, with a GTK editor, persistence and CLI integration;
- direct DINX/dinit service-profile controls with a Control Center Gaming shortcut and profile panel;
- DINXPanel with fixed hardware/control-panel shortcuts, the DinitUI GPU backend bridge and a non-removing Artix kernel catalog;
- package, desktop metadata, license and ISO payload contracts.

## P5 — gaming beta

**Goal:** make the gaming session repeatably usable.

**Status:** session foundation implemented; the gaming exit criterion is not met.

**Delivered:**

- standalone `DINX Gaming` launcher and hidden Wayland desktop entry remain available; Gamescope, Steam, Steam device rules and 32-bit Mesa/RADV/Vulkan dependencies are in the optional Artix `gaming` group, not the base ISO;
- safe Normal/Lite/Gaming service semantics, profile enter/restore with failure propagation around the standalone launcher, fixed GPU detection/driver plans for AMD, Intel and modern NVIDIA hardware, and the YaST-inspired DINXPanel with fixed control-panel shortcuts, Shelly/Topgrade upgrade actions, optional fwupd discovery and a non-removing Artix kernel installer;
- fixed launcher argv/return fixture and real headless Gamescope child launch/exit qualification;
- ISO checks require the hidden launcher and entry while rejecting optional game binaries and package metadata from rootfs/livefs;
- GameMode and MangoHud are optional group members; `dinx-gaming` supports `DINX_GAMEMODE=auto|on|off` and optional `DINX_MANGOHUD=on|off` without weakening the normal launcher fallback.
- The ISO includes `dinx-alpha7-hardware-report` for read-only desktop, laptop,
  and BC-250 qualification evidence; real hardware claims remain manual.

**Remaining release gates:**

- real DRM output and repeatable `dinx-gaming` launch/exit with Dinit profile restoration;
- authenticated Steam startup, commercial game launch/exit, controller input and PipeWire audio;
- suspend/resume, GPU recovery and update testing on physical hardware.

**Exit criterion:** a game can be launched and exited repeatedly without leaving the desktop in a broken state. The current fixtures do not claim that criterion.

## P6 — release hardening

**Goal:** make every published ISO measurable, auditable and testable after installation.

**Status:** in progress.

**Delivered:**

- build metadata now binds the recorded ISO byte count and SHA-512 to the exact artifact checked by CI and the tagged release preflight;
- metadata records the largest installed packages so size regressions have an actionable diagnostic;
- the English and Portuguese qualification guides now include an installed-system checklist for display persistence, NTFS read/write, Pori, Phyto, File Roller, GParted, recovery TTY and hardware behavior.
- shipped Aqueous 1.0.5/Pearl 0.3.0 as the sole user session through direct DINX wrappers: live autologin and the greeter launch Aqueous, the init child starts the DINX user-session helpers and Pearl, the Aqueous activity bootstrap uses direct dinit process identity, and no upstream `uwsm` or systemd user units, systemd library or runtime are installed;

**Remaining release gates:**

- run and retain a fresh full ISO measurement after package changes;
- complete the physical desktop, laptop and BC-250 matrix;
- qualify installed-ISO upgrades, filesystem recovery and rollback;
- close the real DRM, Steam, controller, PipeWire, suspend/resume and GPU-recovery gates.
