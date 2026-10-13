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

1. installs QEMU and ISO inspection tools on the Ubuntu runner;
2. runs Artix in a privileged container;
3. installs `artools`, `iso-profiles` and the pinned MangoWM/Scenefx build dependencies;
4. builds MangoWM and Scenefx, then serves them from a temporary local pacman repository;
5. runs the prerequisite probe;
6. builds the ISO with `buildiso`;
7. validates the root and live-session SquashFS payloads;
8. generates a SHA-512 checksum;
9. keeps QEMU running for a configurable boot window and captures its VGA surface;
10. publishes the ISO, checksum and PPM capture as a temporary private workflow artifact.

The payload check proves that MangoWM, Scenefx, Noctalia, ReGreet, greetd, the Mango session and dinit service files reached the ISO. The QEMU smoke test still proves only process-level boot acceptance; it does not prove graphical login, networking or audio inside the guest.
The workflow also captures the QEMU VGA surface as a PPM artifact through the monitor. That capture is visual evidence to inspect; it does not automatically prove successful greeter interaction, user-session health, networking or audio.

The live overlay also replaces the generic `root-ro` dinit service with a no-op: the live root is an overlay and cannot be remounted read-only. This is an ISO-only live-session adjustment, not an installed-system policy.

The Mango wrapper enables `WLR_RENDERER_ALLOW_SOFTWARE=1` only when `/dev/dri/renderD*` is absent, so the headless QEMU path does not mask a real DRM render node.

For a local graphical capture, set `DINX_QEMU_BOOT_KEYS=down,down,ret`, `DINX_QEMU_SCREENSHOT` and optionally `DINX_QEMU_SCREENSHOT_DELAY` before running `scripts/smoke-iso.sh`; the workflow uses the same boot keys, a 60-second delay and uploads the PPM with the ISO artifact.

For a second diagnostic capture after input, also set `DINX_QEMU_POST_SCREENSHOT`, optionally `DINX_QEMU_POST_SCREENSHOT_DELAY` and `DINX_QEMU_POST_KEYS`. This does not prove that the greeter accepted credentials.


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
4. The graphical payload check finds the compositor, shell, greeter, session and dinit files.
5. A SHA-512 checksum is generated beside the ISO.
6. `scripts/smoke-iso.sh` keeps QEMU alive for the boot window.
7. The ISO boots to the foundation session and a recovery TTY.
8. Networking, PipeWire, D-Bus, portals and graphics are checked in the booted image.
9. Only after these pass do the desktop and first-party application packages become release inputs.
