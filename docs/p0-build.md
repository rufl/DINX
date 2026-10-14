# P0 build status

[English](p0-build.md) · [Português (Brasil)](pt-BR/p0-build.md)

## Selected implementation

DINX uses Artix's current `artools`/`buildiso` flow with a repository-local `profile.yaml` under `distro/iso/iso-profiles/dinx`. This keeps dinit service package selection in the Artix-supported path and avoids inventing a second ISO builder.

The entry points are:

- `scripts/check-iso-host.sh` — prerequisite probe;
- `scripts/build-iso.sh` — root-aware build wrapper;
- `scripts/smoke-iso.sh` — QEMU boot probe;
- `.github/workflows/p0-iso.yml` — remote build in an Artix container;
- `.github/workflows/release.yml` — tagged pre-release publication and Windows QEMU package assembly;
- `distro/packages/wlroots0.20/PKGBUILD` — wlroots 0.20.2 source build pinned for the current Mango/Scenefx ABI;
- `distro/iso/iso-profiles/dinx/profile.yaml` — foundation package and service profile.

## Remote build

The `P0 ISO foundation` workflow runs manually or when profile/build files change. It:

1. installs QEMU and ISO inspection tools on the Ubuntu runner;
2. runs Artix in a privileged container;
3. installs `artools`, `iso-profiles` and the pinned MangoWM/Scenefx build dependencies;
4. builds pinned wlroots 0.20.2, MangoWM and Scenefx, then serves them from a temporary local pacman repository;
5. runs the prerequisite probe;
6. builds the ISO with `buildiso`;
7. validates the root and live-session SquashFS payloads;
8. generates a SHA-512 checksum;
9. keeps QEMU running for a configurable boot window and captures its VGA surface;
10. publishes the ISO, checksum and PPM capture as a temporary workflow artifact.

The payload check proves that MangoWM, Scenefx, Noctalia, ReGreet, greetd, the Mango session, dinit service files, Noctty/NoctEd and the Thunar/GVFS/UDisks2 removable-media stack reached the ISO. It also asserts the standalone PolicyKit agent and rejects systemd plus full Xfce/LXQt sessions. The QEMU smoke test still proves only process-level boot acceptance; it does not prove graphical login, networking or audio inside the guest.
The workflow also captures the QEMU VGA surface as a PPM artifact through the monitor. That capture is visual evidence to inspect; it does not automatically prove successful greeter interaction, user-session health, networking or audio.

Tagged releases reuse the same build artifact through `.github/workflows/release.yml`. The release job publishes the ISO, its SHA-512, the Linux QEMU evidence and a small Windows launcher package. The launcher downloads the ISO only from its metadata-pinned HTTPS release URL, verifies the SHA-512 and runs `scripts/smoke-iso.ps1` with QEMU on Windows. Its ZTASH metadata targets the registered `ddjarin` receiver without embedding credentials.

The live overlay also replaces the generic `root-ro` dinit service with a no-op: the live root is an overlay and cannot be remounted read-only. This is an ISO-only live-session adjustment, not an installed-system policy.

The Mango wrapper enables `WLR_RENDERER_ALLOW_SOFTWARE=1` only when `/dev/dri/renderD*` is absent, so the headless QEMU path does not mask a real DRM render node.

The profile now owns the Artix GRUB theme configuration at `root-overlay/usr/share/grub/themes/artix/theme.txt`. It keeps the upstream background, logo, icons and font assets but omits the opaque `menu_pixmap_style` and `selected_item_pixmap_style` textures that produced a black panel on the graphical kernel-selection screen. `scripts/check-iso-content.sh` verifies that this DINX override reaches the root SquashFS image.

For a local graphical capture, set `DINX_QEMU_BOOT_KEYS=down,down,ret`, `DINX_QEMU_SCREENSHOT` and optionally `DINX_QEMU_SCREENSHOT_DELAY` before running `scripts/smoke-iso.sh`; the workflow uses the same boot keys, a 60-second delay and uploads the PPM with the ISO artifact.

The workflow also captures `dinx-boot-screen.ppm` three seconds after QEMU opens and before sending the boot-menu keys. This provides direct visual regression evidence for the GRUB kernel-selection screen.

The profile also embeds an experimental offline Calamares path with DINX dark branding, dinit service modules and a standalone KDE Partition Manager. The content check asserts the installer configuration, dark defaults for ReGreet and Noctalia, disabled Noctalia animation/transparency defaults, the two-desktop Mango default and its user override, the DINX installer launcher, the partitionmanager binary and the removable-media stack; it does not replace a destructive-disk installation test.

For a second diagnostic capture after input, also set `DINX_QEMU_POST_SCREENSHOT`, optionally `DINX_QEMU_POST_SCREENSHOT_DELAY` and `DINX_QEMU_POST_KEYS`. This does not prove that the greeter accepted credentials.


## Observed successful run

Run [38471629482](https://github.com/rufl/DINX/actions/runs/38471629482) on commit `6224b58` passed all workflow steps in 6m02s:

- ISO artifact: `artix-dinx-dinit-20261013-x86_64.iso`;
- size: 1,497,237,504 bytes;
- SHA-512: `adcd6cba882b368725ffa02d33e8a2ae17c3be1b9ffaa17692dbd9eb895689bb0a686530f1012a11f6d262ef2d9ab859d27c2995393aa1ded4cd50d4af42433c`;
- QEMU smoke window: 90 seconds, passed;
- payload check: MangoWM, Scenefx, Noctalia, ReGreet, greetd and dinit payloads present;
- graphical capture: the initial frame showed the ReGreet user/session selector, and the post-input frame showed the MangoWM session with the Noctalia welcome screen;
- artifact: `dinx-foundation-iso-6224b5859de814b1d5fe7e2fae982e1c9c49918f`, retained for 7 days.

The generated serial log was empty. The two VGA captures provide evidence of greeter rendering and a successful graphical user-session transition; they do not prove networking, audio or long-term service health.

## Observed development host

The development host is EndeavourOS x86_64. `pacman`, `xorriso` and `zig` are available. `buildiso`, `mkarchiso` and `qemu-system-x86_64` are not installed. QEMU user libraries and `/dev/kvm` are present, but that is not sufficient to run the local smoke test.

Therefore the P0 build must run in the remote workflow until the local dependencies are available.

## Acceptance sequence

1. `scripts/check-iso-host.sh` exits successfully in the Artix container.
2. `scripts/build-iso.sh -q` resolves the `dinx` profile with `dinit`.
3. A clean build produces one ISO and its build metadata.
4. The graphical payload check finds the compositor, shell, greeter, session, first-party apps, removable-media stack and dinit files.
5. A SHA-512 checksum is generated beside the ISO.
6. `scripts/smoke-iso.sh` keeps QEMU alive for the boot window.
7. The ISO boots to the foundation session and a recovery TTY.
8. Networking, PipeWire, D-Bus, portals and graphics are checked in the booted image.
9. Only after these pass do the desktop and first-party application packages become release inputs.
