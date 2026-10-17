# DINX security model

[English](security-model.md) · [Português (Brasil)](pt-BR/security-model.md)

DINX is a public alpha. The security model prioritizes safe installation, explicit trust boundaries and recoverability over convenience.

The live image intentionally includes the disposable test account `dinx` with password `dinx` so the graphical smoke path can log in. This credential is public, must never be reused and is not suitable for an installed system.

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
The gaming session is also a fixed boundary: its root overlay launcher starts only the packaged Gamescope/Steam argv, with no shell interpolation or systemd service. Steam's 32-bit/systemd compatibility libraries are payload dependencies, not an init runtime; the ISO content gate rejects the systemd daemon/runtime and systemctl. Controller devices, game content, Steam credentials and network services remain user-controlled inputs outside the alpha fixture qualification.

Performance profiles are an explicit policy boundary, not an automatic service classifier. Built-in `normal`, `lite` and `gaming` lists touch only optional daemons; custom profiles accept only validated profile/service identifiers, persist under the user's XDG config, and apply system actions through the same `dinitctl`/`pkexec` path. The Noctalia plugin passes profile names as direct argv values and does not execute shell text.

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

Optional Noctalia IPC is treated as an untrusted integration boundary: validate message shape, handle unavailable endpoints and keep startup independent of the shell.

## Alpha release handling

The GitHub repository is public during alpha. Source is public; unreleased packages and ISOs may still be distributed deliberately. Every alpha release must include:

- supported hardware scope;
- installation and recovery instructions;
- known issues;
- checksum/signature verification steps;
- a clear data-loss warning;
- rollback or reinstallation guidance where upgrades are unsafe.
