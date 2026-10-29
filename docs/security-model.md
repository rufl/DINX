# DINX security model

[English](security-model.md) · [Português (Brasil)](pt-BR/security-model.md)

DINX is a public alpha. The security model prioritizes safe installation, explicit trust boundaries and recoverability over convenience.

The live image automatically opens the disposable `dinx` account in `Aqueous + Pearl (DINX)`. Because anyone who can boot the ISO already controls the live machine, a login prompt adds friction but no meaningful security boundary. Installed/manual login uses Pearl Greeter through greetd and the dedicated `pearl-greeter` account; the configured host forces Aqueous/Pearl without X11, UWSM or systemd. The public `dinx` password remains only as a diagnostic fallback if Pearl Greeter appears after a manual live start; the installed system keeps its separate Calamares-created login policy.

## Threat assumptions

- Alpha ISOs and packages may contain defects and must not be treated as production releases.
- A graphical application may be compromised or may receive hostile project files.
- Service-management actions cross from an unprivileged user session into system state.
- Package and ISO artifacts can be corrupted or replaced if checksums and signatures are not verified.

## Privileged operations

DinitUI and DINXPanel MUST:

- expose a finite action set rather than arbitrary command execution;
- validate service identifiers and typed action arguments against the Dinit interface;
- invoke `dinitctl` with argv, never a shell;
- use direct user/system scope and retry `pkexec` only after an explicit authorization failure;
- return structured status and error information;
- surface the requested action, exit status and command output; use Dinit's own service log for service diagnostics.

DINXPanel's GPU bridge and kernel installer MUST use fixed argv plans. Kernel actions MAY install packages and matching headers, MUST NOT remove any package or the running kernel, and MUST report reboot required after kernel or driver changes.

The interface must distinguish a service that is stopped, failed, unknown or inaccessible. It must never report success based only on process launch.
The gaming session is a fixed boundary: its root-overlay launcher starts only the packaged Gamescope/Steam argv, with no shell interpolation or systemd service. Steam's 32-bit runtime libraries are optional post-install packages, not base ISO payload or an init runtime; the ISO content gate rejects the systemd daemon/runtime and systemctl. Controller devices, game content, Steam credentials and network services remain user-controlled inputs outside the alpha fixture qualification.

Performance profiles are an explicit policy boundary, not an automatic service classifier. Built-in `normal`, `lite` and `gaming` lists touch only optional daemons; custom profiles accept only validated profile/service identifiers, persist under the user's XDG config, and apply system actions through the same `dinitctl`/`pkexec` path. No shell plugin or private IPC is required.

## Package and ISO trust

For each distributable alpha release:

- package manifests must identify upstream and DINX-specific inputs;
- unsigned alpha packages must remain pre-release and record `signing: unavailable`; they must not be presented as supported production artifacts;
- ISO and package checksums must be published with each release;
- build metadata must identify the source commit and input snapshot;
- upgrade warnings must be explicit because the base is rolling.

Reproducibility is an acceptance target. A build that cannot identify its inputs is not a release candidate.

## Application isolation

Noctty and Nocted must not require elevated privileges. Project files, editor plugins and terminal commands are untrusted inputs. The applications should follow normal XDG permission boundaries and must not silently execute project code.

Optional integrations use standard XDG, Wayland and D-Bus boundaries. Validate message shape, handle unavailable endpoints and keep startup independent of optional services.

## Alpha release handling

The GitHub repository is public during alpha. Source is public; unreleased packages and ISOs may still be distributed deliberately. Every alpha release must include:

- supported hardware scope;
- installation and recovery instructions;
- known issues;
- checksum/signature verification steps;
- a clear data-loss warning;
- rollback or reinstallation guidance where upgrades are unsafe.
