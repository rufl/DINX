# DINX roadmap

[English](roadmap.md) · [Português (Brasil)](pt-BR/roadmap.md)

Milestones are capability gates, not calendar promises.

## Current status

**Published system release:** [DINX v0.1.0-alpha.12](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.12), built from `56a814575e33bfae6215993972784f11b7dae215` by [release workflow #41197618617](https://github.com/rufl/DINX/actions/runs/41197618617). The measured ISO is 1,836,830,720 bytes (below GitHub's 2 GiB per-asset limit); [download the rolling ISO](https://github.com/rufl/DINX/releases/download/alpha-latest/dinx-latest-x86_64.iso) and [SHA-512 checksum](https://github.com/rufl/DINX/releases/download/alpha-latest/dinx-latest-x86_64.iso.sha512).

**Next system release:** Beta 0.1 is planned, not released, and has no date. It is a physical-hardware, installation, update and recovery qualification milestone; see the exit gates below. The P5 gaming qualification remains separate and does not imply that Beta 0.1 is gaming-ready.

Tags `v0.1.0-alpha.12` and `alpha-latest` point to the same source commit, and their ISO assets and SHA-512 checksums match. The tagged workflow is the evidence for the published artifact; subsequent documentation-only commits on `main` do not change it.

## Product objective

DINX aims to be a beginner-friendly, live-first Artix Linux desktop: boot straight into a usable Aqueous/Pearl session without a live login prompt; provide a familiar floating-window desktop with titlebars, window controls and edge/corner snapping; include a focused set of everyday apps; and make installation approachable through Calamares guided/manual choices with swap optional. The design stays single-session and dinit-only: no systemd or UWSM. The distribution is delivered as one directly downloadable x86_64 ISO below GitHub's 2 GiB per-file limit.

Alpha 12 is an experimental milestone, not a blanket hardware-support claim. CI verified the graphical session in QEMU and the release workflow's install/recovery paths; physical-machine coverage and direct VirtualBox VMSVGA boot remain unqualified. Cross-toolkit window behavior is also a Beta gate, not a universal guarantee.

## P0 — foundation

**Goal:** produce a reproducible, bootable Artix+dinit live system and define the persistent installation path.

**Status:** the ISO/VM foundation gate is complete and exercised by the Alpha 12 tagged release workflow: signed package/repository checks, ISO build and size/checksum metadata, QEMU graphical boot, Calamares transactions, and disposable BIOS/UEFI persistent-install and recovery checks passed. Production signing-key rotation/revocation, physical hardware, direct VirtualBox boot, installed-ISO upgrades, filesystem rollback and long-term hardware service health remain release gates.

Implementation delivered:

- the P0 ISO/VM foundation gate, signed package transaction path and recovery-TTY contract;
- the direct Aqueous/Pearl session, Pearl Greeter through greetd, and dinit-only runtime with no systemd/UWSM;
- the Fish defaults, base package boundary and clean-build/VM smoke paths;
- The live session starts Aqueous/Pearl without asking for live credentials; installed systems use Pearl Greeter and do not enable autologin. Aqueous/Pearl is the only session, launched and supervised directly by dinit, with no systemd or UWSM payload.
- New user profiles start with two workspaces and floating/stacking windows. The compositor provides DINX titlebars, minimize/maximize/close controls, titlebar dragging and edge/corner snapping; compatibility with every GTK, Qt and XWayland app remains to be qualified.
- Fish is the default shell and Deetty the only terminal emulator. The base roster includes Dintor, Phyto, File Roller, GParted, Pori, Gapless, wdisplays/Shikane, Dome, Seafoam Settings and ZLS, alongside the DINX control/diagnostic tools.
- GTK 3/4 defaults to the DINX dark theme; system branding is applied without replacing application or desktop icons. The live and installed systems use kernel `ntfs3` for NTFS read/write, and display changes can persist to Shikane profiles.
- Calamares offers guided and manual partitioning, keeps destructive choices unselected and makes swap optional. CI covers installer transactions, but physical-disk installation and data-preservation claims still require hardware qualification.

Open foundation release gates:

- validate networking, PipeWire, D-Bus, portals, polkit and GPU acceleration on physical hardware;
- retain and exercise recovery after a broken graphical session;

**Exit criterion:** a clean live boot opens a graphical session, provides the required base services and can recover through a TTY. CI exercises the persistent-install contract on disposable BIOS and UEFI disks and the signed package transaction path; installed-ISO upgrades, filesystem rollback and data preservation remain release gates.

## P1 — public alpha release

**Goal:** distribute a known-good snapshot through the public GitHub project.

**Status:** complete for the public alpha snapshot `v0.1.0-alpha.12`.

Completed:

- published the direct ISO, matching SHA-512, build metadata, signed DINX package repository, provenance/verification assets and the rolling `alpha-latest` download;
- qualified the experimental persistent installer and first-boot recovery path in CI on disposable BIOS and UEFI disks;
- made Deetty the sole terminal emulator in the live ISO and fresh installation, with working Fish and application shell defaults;
- recorded the production-key prerequisite, hardware boundary and recovery limitations in the release documentation;

Deferred release gates:

- physical hardware reports and qualification beyond the VM;

**Exit criterion:** met. An invited tester can install the alpha snapshot from the public release and documentation without reconstructing the development environment.

## P2 — Deetty

**Status:** complete. P2 closed with the final green P0 workflow run recorded in [P0 build status](p0-build.md).

P2 exit evidence:

- the exact pinned upstream archive that supplies Deetty and Dintor is SHA-256 verified and built into the Artix `deetty` package;
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

## P3 — Dintor

**Status:** complete. P3 closes with the pinned NOCTTY source, the DINX compatibility patch, the `deetty` package/ISO payload, the Dintor P3 qualification gate, and the editor integration contract.

Delivered:

- file and directory opening, project trees, tabs, quick open and deterministic project navigation;
- reliable text buffers, selections, multi-selection replacement and GTK undo/redo;
- Tree-sitter and GtkSourceView syntax highlighting, folding and configurable editor behavior;
- in-file/project search, replacement through selection workflows and keyboard shortcuts;
- bounded LSP process/client management with diagnostics, completion, hover, definitions, references, rename, symbols and formatting;
- Git status, unified diffs and change markers exposed from the editor's Tools menu and the headless `--git-probe`;

- DINX static light/dark editor schemes through the documented `DINTOR_THEME` environment contract, with useful operation independent of a desktop shell;

P3 release gate:

- `scripts/dintor_p3_qualification.sh` runs core endurance, project-index scale/delta, worker, state-recovery, task, real `clangd`, native X11 GTK smoke in dark/light modes and a real Git fixture;
- `PKGBUILD`, the ISO profile, `check_deetty_integration.sh` and `check-iso-content.sh` carry the same Dintor/LSP/Git/theme contract;
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

## P5 — gaming qualification

**Goal:** make the gaming session repeatably usable.

**Status:** session foundation implemented; the gaming exit criterion is not met. This track is separate from the planned system Beta 0.1.

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

- repeat a full ISO measurement for each release candidate; Alpha 12 establishes the current measured baseline of 1,836,830,720 bytes;
- complete the physical desktop, laptop and BC-250 matrix;
- qualify installed-ISO upgrades, filesystem recovery and rollback;
- close the real DRM, Steam, controller, PipeWire, suspend/resume and GPU-recovery gates.

## Beta 0.1 — system qualification

**Goal:** qualify a useful, installable system for explicitly listed hardware without changing the single-session, dinit-only design.

**Status:** planned. Alpha 12 is the current public system alpha; Beta 0.1 has no release date.

**Release gates:**

- Publish a physical compatibility matrix with exact hardware and tested firmware, GPU/display, network, audio, Bluetooth and suspend/resume results. Limit support claims to tested machines; qualify BC-250 only on detected, separately tested hardware.
- Test guided and manual installation on disposable physical disks, including the supported UEFI/BIOS paths, first boot, recovery TTY and interrupted-install recovery. Keep swap optional; never require users to create it manually. Document Windows/BitLocker/hibernation boundaries and make no data-preservation claim beyond tested layouts.
- Qualify the signed package-repository bootstrap, signature verification, installed-system updates and package recovery. Decide whether installed-ISO upgrades and filesystem rollback are supported; otherwise state that they remain unsupported and document the recovery/reinstall path.
- Validate the base services and session on the declared machines: network, D-Bus, portals, polkit, PipeWire, GPU acceleration, display persistence, lock/idle and suspend/resume. Keep Aqueous/Pearl as the only session, supervised directly by dinit; install no systemd or UWSM.
- Verify GTK 3/4, Qt 6 and XWayland apps in the Aqueous session: titlebar visibility, minimize/maximize/close, dragging, snapping and custom-titlebar overlap. Record app-specific exceptions instead of claiming uniform behavior without evidence.
- Pass the existing P0 build, QEMU, Calamares, BIOS/UEFI, recovery, metadata and provenance gates. Keep the direct ISO below GitHub's [2 GiB release-asset limit](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases) (`2,147,483,648` bytes); Alpha 12 measures 1,836,830,720 bytes. QEMU graphics passed; direct VirtualBox VMSVGA boot is not yet qualified.
- Publish matching English and Brazilian Portuguese installation, compatibility, known-issues and recovery guidance with test evidence and explicit unsupported cases.

**Outside the Beta 0.1 claim:** gaming support remains the separate P5 track. Do not claim Steam, commercial-game, controller, real DRM-output or gaming-audio support until its hardware gates pass. Secure Boot and physical recovery are also unclaimed until separately tested.

**Exit criterion:** every hardware class listed as supported passes the documented install, first-boot, core-service, display and recovery checklist; signed updates have a tested recovery path; no release-blocking P0 issue remains; the release ISO meets its size target and passes the tagged release workflow. Untested hardware remains unsupported, not implicitly certified by x86_64 compatibility.
