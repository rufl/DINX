# P0 build status

[English](p0-build.md) · [Português (Brasil)](pt-BR/p0-build.md)

## Selected implementation

DINX uses Artix's current `artools`/`buildiso` flow with a repository-local `profile.yaml` under `distro/iso/iso-profiles/dinx`. This keeps dinit service package selection in the Artix-supported path and avoids inventing a second ISO builder.

The entry points are:

- `scripts/check-iso-host.sh` — prerequisite probe;
- `scripts/build-iso.sh` — root-aware build wrapper;
- `scripts/smoke-iso.sh` — QEMU boot probe;
- `.github/workflows/p0-iso.yml` — remote build in an Artix container;
- `distro/iso/iso-profiles/dinx/profile.yaml` — foundation package and service profile.

## Remote build

The `P0 ISO foundation` workflow runs manually or when profile/build files change. It:

1. installs QEMU on the Ubuntu runner;
2. runs Artix in a privileged container;
3. installs `artools` and `iso-profiles`;
4. runs the prerequisite probe;
5. builds the ISO with `buildiso`;
6. generates a SHA-512 checksum;
7. keeps QEMU running for a configurable boot window;
8. publishes the ISO and checksum as a temporary private workflow artifact.

The smoke test proves that the image and boot path remain accepted by QEMU during the configured window. It does not yet prove graphical login, networking or audio inside the guest; those checks follow once the foundation image has an observable guest-test method.

## Observed successful run

Run [38448333502](https://github.com/rufl/dinx-alpha/actions/runs/38448333502) on commit `8f5b99d` passed all workflow steps in 8m05s:

- ISO artifact: `artix-dinx-dinit-20261013-x86_64.iso`;
- size: 1,409,947,648 bytes;
- SHA-512: `9407f2da3d2bc37bd973368a7206df3b27f67a23068ee26b88529132ee03285a40db5fb108375874e7e26ece35b4602f86c153f225c27a997ad1a5872a09bc9f`;
- QEMU smoke window: 60 seconds, passed;
- artifact: `dinx-foundation-iso-8f5b99dfcfc1548618d448a269d87a5f08809071`, retained privately for 7 days.

The generated serial log was empty. This records QEMU/process-level acceptance only; it is not evidence of graphical login or guest service health.

## Observed development host

The development host is EndeavourOS x86_64. `pacman`, `xorriso` and `zig` are available. `buildiso`, `mkarchiso` and `qemu-system-x86_64` are not installed. QEMU user libraries and `/dev/kvm` are present, but that is not sufficient to run the local smoke test.

Therefore the P0 build must run in the remote workflow until the local dependencies are available.

## Acceptance sequence

1. `scripts/check-iso-host.sh` exits successfully in the Artix container.
2. `scripts/build-iso.sh -q` resolves the `dinx` profile with `dinit`.
3. A clean build produces one ISO and its build metadata.
4. A SHA-512 checksum is generated beside the ISO.
5. `scripts/smoke-iso.sh` keeps QEMU alive for the boot window.
6. The ISO boots to the foundation session and a recovery TTY.
7. Networking, PipeWire, D-Bus, portals and graphics are checked in the booted image.
8. Only after these pass do the desktop and first-party application packages become release inputs.
