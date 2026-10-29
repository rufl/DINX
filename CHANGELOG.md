# Changelog

This file records meaningful DINX changes in direct language. It does not claim that the roadmap is complete; the linked qualification evidence and release metadata are the source of truth.

## v0.1.0-alpha.10 — 2026-10-29

- Published [v0.1.0-alpha.10](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.10) from commit `3fd3cd036cab7e8fb553e6e5c244b02429f1a18e` via [release workflow 40879223746](https://github.com/rufl/DINX/actions/runs/40879223746). The direct ISO is 1,862,772,736 bytes with SHA-512 `5f49a65eac1481c01555a8f44b049c9a06e75ec7270ac3cdef97cc5e0b051d4b3c48a200542a36ec1832700accbc5509e3c314726c2f747530095eba4112219a`; signed package repository snapshot `b0015a0655d7d56a4949731d1a4f33cb2cc8daa55d4ec77df6d1a22161d2f5fd`.

- Moved Gamescope, Steam, GameMode, MangoHud, Steam device rules and 32-bit gaming libraries out of the base ISO into optional post-install packages. The base keeps 64-bit RADV/Vulkan; P0 no longer enables `[lib32]` during ISO assembly. ISO checks reject game binaries/package metadata in both rootfs and livefs. The published Alpha 10 direct ISO is 1,862,772,736 bytes.

- Removed the BC-250 governor, dinit service and Control Center from generic live and installed roots. Their pinned packages remain in the signed DINX repository; the documented install command is gated on PCI `1002:13fe`.

- Added a bilingual Calamares install-choice page before partitioning. It explains whole-disk erasure, supported alongside installs, partition replacement and manual layouts; destructive choices remain unselected, and swap stays optional with no swap as the default.

- Changed the local guidance smoke to render the QML page with Qt Quick on Arch-based hosts. EndeavourOS's Calamares fork omits `notesqml` and Artix-specific modules, so full installer integration remains verified by the Artix ISO build.

- Fixed the live desktop's missing XDG Desktop directory warning: the Aqueous/Pearl launcher runs `xdg-user-dirs-update` before the compositor, creating the standard directories for fresh live and installed accounts.

- Fixed the latest P0 livefs transaction conflict: `dinx-live-autologin` no longer packages a duplicate `/etc/dinit.d/greetd`; its boot-enabled Dinit service orders the one-time session-config writer before greetd and `login.target`, leaving the upstream `greetd-dinit` service file intact.
- Fixed an intermittent UEFI persistent-install smoke failure: the first-boot marker now waits for Dinit's `early-root-rw.target` before writing under `/var`. The failed run exposed the marker/root-remount race; the fix passed both firmware modes in main P0 run [40870759044](https://github.com/rufl/DINX/actions/runs/40870759044). The tagged Alpha 10 release was subsequently validated and published by [40879223746](https://github.com/rufl/DINX/actions/runs/40879223746); physical hardware qualification remains separate.
- Fixed the Alpha 10 livefs payload check to validate the greetd service and boot symlink at their exact manifest paths. The corrected check and the BIOS/UEFI install, metadata and provenance gates passed in main P0 run [40870759044](https://github.com/rufl/DINX/actions/runs/40870759044); tagged workflow [40879223746](https://github.com/rufl/DINX/actions/runs/40879223746) published the validated ISO.
- Strengthened the QEMU ISO smoke: it captures and OCR-checks the selected live-session screen, accepts the Pearl panel's desktop/clock/layout markers when no product name is visible, and rejects the greeter, TTY, login prompts, missing XDG Desktop directory and visible Dinit failures. P0 installs Tesseract with English data for this gate.
- Kept Mesa Lavapipe (`vulkan-swrast`) in the base ISO for Vulkan applications, but stopped forcing it for Aqueous: QEMU and no-render-node sessions use the Pixman compatibility compositor instead of the failing llvmpipe presentation path.

- Strengthened deterministic ISO compaction: the SquashFS wrapper now uses the tool's supported xz preset, x86 BCJ, 256 KiB blocks and a 256 KiB dictionary, while excluding kernel sources, pacman package caches and build logs. The base runtime no longer carries build-only `squashfs-tools`; the builder keeps it in its host toolchain.
- Hardened the Artix builder contract: the pinned image digest is asserted before package/build work, forwarded explicitly into the container, and recorded safely in build metadata.
- Closed the absolute-path compression gap: CI preserves the real `mksquashfs` binary, installs the DINX wrapper at `/usr/bin/mksquashfs`, and the post-build ISO check verifies that both rootfs/livefs superblocks are xz-compressed with 256 KiB blocks. The wrapper also rejects self-recursion.
- Made the privileged `mksquashfs` wrapper check tolerate Artix's `/usr/sbin` symlink while still resolving the installed command to the DINX wrapper, avoiding a false CI failure before ISO assembly.
- Stabilized Artix package retrieval with two official HTTPS mirrors selected from the current mirror inventory, rejecting an empty active list and recording the source label/hash in build metadata so stale or removed mirrors do not break rootfs assembly.
- Kept the sole-session contract intact despite Artix Calamares' indirect Plasma integration dependency: CI excludes the package's `plasma.desktop` entry from both rootfs and livefs, so Pearl exposes only Aqueous/Pearl while Calamares remains available.
- Replaced the former ReGreet login path with Pearl Greeter: greetd launches `/usr/lib/pearl/pearl-greeter-host` as the dedicated `pearl-greeter` account. Power actions remain dinit-safe absolute wrappers, and the ISO rejects additional sessions.
- Added an ISO-content guard for the livefs itself: `AUTOLOGIN=true`, the dinit autologin service/link, the Aqueous/Pearl command and the `dinx` live user must all be present, while livefs systemd/uwsm payloads are rejected.
- Reduced the full-image payload with a repository-owned compact common manifest: the documented AMDGPU path remains included, generic firmware and `powertop` are omitted from final images, and kernel headers remain only for ISO initramfs generation while their source tree is excluded from final SquashFS.
- Made Aqueous + Pearl the only selectable and live-initial user session; removed Labwc, Noctalia and the ReGreet package from the base payload. Pearl Greeter is the installed/manual login UI.
- Added Phyto as the default native file manager and Pori as the only graphical disk/mount manager. Pori discovers devices through UDisks2 and persists mounts as dinit services under `/etc/dinit.d`.
- Restored File Roller for graphical archive open/create/extract actions and GParted for standalone partition editing, while retaining the removal of Thunar, GVFS, Tumbler and KDE Partition Manager. The kernel `ntfs3` driver supplies NTFS read/write support in the live ISO and installed system; legacy `ntfs-3g` is optional after installation.

- Added `wdisplays` and `shikane` to the base desktop payload for interactive and deterministic Wayland display setup. Added Dome 0.1.1 as a source-pinned base Seafoam package from Pearl v0.3.0; its resource/process views are dinit-safe and the package installs no systemd or uwsm integration. Coral is intentionally not included.
- Added the base Seafoam Settings native Zig/GTK4 launcher for wdisplays, Shikane, DinitUI, DINXPanel, Qt6ct and Dome entry points. Added the source-pinned official ZLS 0.16.0 package for Nocted's Zig LSP path; all three are included in the base ISO. ZLS carries only the matching Zig `lib/std` tree plus a metadata-only shim, so completion/navigation work without a full compiler or systemd; the shim delegates to an optional Artix `zig` installation for compiler commands.
- Kept the upstream compiler boundary explicit: Pearl 0.3.0, including the source used by Dome, and Phyto's bundled Pearl 0.2.8 source use their pinned Zig 0.16.0 toolchain, which P0 downloads and verifies; Pori, Aqueous and other DINX-native Zig packages outside that upstream Pearl tree remain on the verified Zig 0.17.0 toolchain.
- Added the DINX display persistence bridge: the wdisplays desktop entry, DINXPanel and Seafoam Settings use `dinx-wdisplays`; closing the editor atomically replaces the `DINX wdisplays` profile, reloads Shikane and keeps the layout across sessions.
- Added the read-only `dinx-doctor` report for session, dinit, storage, display and package evidence; it never performs service, mount, package or network mutations.
- Added Aqueous 1.0.5 and Pearl 0.3.0 to the base ISO as the only selectable direct-dinit session. The greeter and live autologin launch Aqueous/Pearl through DINX wrappers; after Wayland and session D-Bus readiness, the DINX supervisor starts Shikane, PolicyKit, optional BC250, the required idle helper and Pearl, removes upstream systemd/uwsm units, and records failure instead of leaving a blank desktop. The session adds no systemd package, runtime or user unit. Removed the legacy Xorg/XLibre server, driver and Plasma X11 payload from the ISO while retaining XWayland and builder-only Xvfb support.
- Refreshed the English and Brazilian Portuguese landing pages and operational documentation with the published Alpha 9 snapshot plus the successful post-release `main` validation run `39934458077`; the docs distinguish validation evidence from published release assets.
- Removed the manual live greeter step: the disposable ISO session starts `Aqueous + Pearl (DINX)` through a live-only dinit autologin package, while the installed system and Calamares keep autologin disabled. If the live session exits, greetd returns to Pearl Greeter.
- Added a supervised Aqueous/Pearl session boundary: the helper waits for Wayland and D-Bus readiness, starts required display/policy/idle components and Pearl, records `starting`/`ready`/`failed`/`exited` state, terminates the compositor on required-helper or compositor failure, and terminates the tracked compositor parent if the supervisor itself is stopped, without systemd or uwsm.
- Hardened Pori mount persistence with a dinit `process` wrapper that waits for devices, retries mounts, owns only mounts it created, unmounts them on shutdown and restarts after an unexpected disappearance. Phyto, File Roller, GParted and kernel `ntfs3` remain the supported file, archive, partition and NTFS paths.
- Serialized wdisplays-to-Shikane updates with `flock`; profile replacement remains atomic, and a failed Shikane reload now fails visibly instead of reporting a successful persistence update.
- Added exact source-input inventories to `feature-groups.json` and an unprivileged pull-request contract workflow so package/profile drift, helper contracts, the pinned Zig 0.17 Pori source smoke, fixture smokes and REUSE coverage are checked before the privileged ISO build.
- Ordered the persistent-install first-boot marker after `early-root-rw.target`, preventing its `/var` write from racing the installed root's read-only remount on UEFI first boot.


## v0.1.0-alpha.9 — 2026-10-23

- Published the previous public DINX system alpha for x86_64 Artix Linux with dinit: [GitHub release](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.9).
- Passed tagged release workflow [39924316082](https://github.com/rufl/DINX/actions/runs/39924316082) from commit `0d1698a462d5d5486871a7aa17e9b97352ee9404`, including package/profile contracts, Artix package builds, compact ISO creation, QEMU boot/graphical payload, Calamares BIOS/UEFI/Btrfs smokes, disposable persistent-install/recovery-TTY smokes, build-metadata verification, persistent package signing, provenance attestation and release publication.
- Published a direct ISO, SHA-512 checksum, build metadata, Windows QEMU package, signed DINX package repository and verification assets.
- Published ISO size: `2,008,801,280` bytes. Full ISO SHA-512: `b3724c82348c229ee897880e03e8adc80d9b5b25588b0aca9dfcfedf0c4744e4e1ae01dcb536f6555502e8fe595f71f06bed599372dffe0e1b0f34b29f3b5b2d`.
- Published signed DINX repository snapshot: `01fc8270e5f0fa0339647c9bbde5934ec247a7c29cf235940d4ea9dcedab5827`.
- The supported xz preset plus x86 BCJ, 1 MiB blocks and a 1 MiB dictionary keeps the direct release ISO below GitHub's 2 GiB asset limit.

## v0.1.0-alpha.8 — 2026-10-21

- Published the current public DINX system alpha for x86_64 Artix Linux with dinit: [GitHub release](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.8).
- Passed tagged release workflow [39611695024](https://github.com/rufl/DINX/actions/runs/39611695024) from commit `eea66ac`, including package and ISO contracts, QEMU boot, graphical payload validation, Calamares BIOS/UEFI/Btrfs transaction smokes, disposable persistent-install/recovery-TTY smokes, build-metadata verification, persistent package signing, attestation and release publication.
- Published the split ISO parts, SHA-512 checksum, build metadata, Windows QEMU package, signed DINX package repository and verification assets.
- Published ISO size: `2,803,349,504` bytes. Full ISO SHA-512: `50e8d535fd4a482ea5433b454921a34402f64e2aa9f82ed9434cff659820c944df7b44b062ebd56094948147109ff65b6f31889080340de484c36fb5d7eb5b8a`.
- Published signed DINX repository snapshot: `5a61d50f3837161bed1af7619965b44e80bd885e79457e443c328e0151d805d9`.
- Updated the user-facing English and Portuguese landing pages and release documentation to point to Alpha 8.

### Known boundaries

This remains a public alpha. Physical hardware, a real DRM gaming session, authenticated Steam and commercial-game launch, controller input, PipeWire game audio, suspend/resume, GPU recovery, Secure Boot and installed-ISO upgrade/rollback remain outside the release claim.
