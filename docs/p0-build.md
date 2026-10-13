# P0 build status

## Selected implementation

DINX uses Artix's current `artools`/`buildiso` flow with a repository-local `profile.yaml` under `distro/iso/iso-profiles/dinx`. This keeps dinit service package selection in the Artix-supported path and avoids inventing a second ISO builder.

The entry points are:

- `scripts/check-iso-host.sh` — prerequisite probe;
- `scripts/build-iso.sh` — root-aware build wrapper;
- `distro/iso/iso-profiles/dinx/profile.yaml` — foundation package and service profile.

## Observed development host

The development host is EndeavourOS x86_64. `pacman`, `xorriso` and `zig` are available. `buildiso`, `mkarchiso` and `qemu-system-x86_64` are not installed. QEMU user libraries and `/dev/kvm` are present, but that is not sufficient to run the ISO smoke test.

Therefore no ISO build or boot result is claimed yet. The next environment action is to install or provide current Artix `artools`/`iso-profiles` and a QEMU system emulator, then run the prerequisite probe and build wrapper.

## Acceptance sequence

1. `scripts/check-iso-host.sh` exits successfully.
2. `scripts/build-iso.sh -q` resolves the `dinx` profile with `dinit`.
3. A clean build produces one ISO and its build metadata.
4. The ISO boots to the foundation session and a recovery TTY.
5. Networking, PipeWire, D-Bus, portals and graphics are checked in the booted image.
6. Only after these pass do the desktop and first-party application packages become release inputs.
