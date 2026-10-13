# DINX security model

[English](security-model.md) · [Português (Brasil)](pt-BR/security-model.md)

DINX is a public alpha. The security model prioritizes safe installation, explicit trust boundaries and recoverability over convenience.

## Threat assumptions

- Alpha ISOs and packages may contain defects and must not be treated as production releases.
- A graphical application may be compromised or may receive hostile project files.
- Service-management actions cross from an unprivileged user session into system state.
- Package and ISO artifacts can be corrupted or replaced if checksums and signatures are not verified.

## Privileged operations

Dinx Control and future maintenance UI components MUST:

- expose a finite action set rather than arbitrary command execution;
- validate service identifiers against the service-manager interface;
- use a constrained helper or a documented polkit policy for privilege escalation;
- return structured status and error information;
- avoid shell interpolation entirely;
- record the requested action and result in the normal system journal/log path.

The interface must distinguish a service that is stopped, failed, unknown or inaccessible. It must never report success based only on process launch.

## Package and ISO trust

For each distributable alpha release:

- package manifests must identify upstream and DINX-specific inputs;
- packages must be signed with a key whose ownership and rotation process are documented;
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
