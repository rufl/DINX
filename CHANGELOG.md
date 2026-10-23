# Changelog

This file records meaningful DINX changes in direct language. It does not claim that the roadmap is complete; the linked qualification evidence and release metadata are the source of truth.

## Unreleased

- Strengthened deterministic ISO compaction: the SquashFS wrapper now uses xz level 9, x86 BCJ, 1 MiB blocks and a 1 MiB dictionary, while excluding kernel sources, pacman package caches and build logs. The base runtime no longer carries build-only `squashfs-tools`; the builder keeps it in its host toolchain.
- Hardened the Artix builder contract: the pinned image digest is asserted before package/build work, forwarded explicitly into the container, and recorded safely in build metadata.
- Reduced the full-image payload with a repository-owned compact common manifest: the documented AMDGPU path remains included, generic firmware and `powertop` are omitted from final images, and kernel headers remain only for ISO initramfs generation while their source tree is excluded from final SquashFS.
- Switched the compositor session to labwc while retaining the Noctalia shell and user-session integration.
- Added Phyto as the default native file manager and Pori as the only graphical disk/mount manager. Pori discovers devices through UDisks2 and persists mounts as dinit services under `/etc/dinit.d`.
- Restored File Roller for graphical archive open/create/extract actions and GParted for standalone partition editing, while retaining the removal of Thunar, GVFS, Tumbler and KDE Partition Manager. The kernel `ntfs3` driver supplies NTFS read/write support in the live ISO and installed system; legacy `ntfs-3g` is optional after installation.

- Added `wdisplays` and `shikane` to the base desktop payload for interactive and deterministic Wayland display setup. Added Dome 0.1.1 as a source-pinned optional Seafoam package from Pearl v0.3.0; its resource/process views remain dinit-safe while its optional systemd service provider is unavailable on DINX. Coral is intentionally not included.
- Added the optional Seafoam Settings native Zig/GTK4 launcher for wdisplays, Shikane, labwc, DinitUI, DINXPanel, Qt6ct and Dome entry points. Added the source-pinned official ZLS 0.16.0 package for Nocted's Zig LSP path; both remain outside the base ISO.
- Added the DINX display persistence bridge: the wdisplays desktop entry, DINXPanel and Seafoam Settings use `dinx-wdisplays`; closing the editor atomically replaces the `DINX wdisplays` profile, reloads Shikane and keeps the layout across sessions.
- Added the read-only `dinx-doctor` report for session, dinit, storage, display and package evidence; it never performs service, mount, package or network mutations.
- Documented the Aqueous/Pearl boundary: their current `uwsm`/systemd user-session packaging is not exposed as a DINX session until a dinit-native adaptation is qualified.


## v0.1.0-alpha.8 — 2026-10-21

- Published the current public DINX system alpha for x86_64 Artix Linux with dinit: [GitHub release](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.8).
- Passed tagged release workflow [39611695024](https://github.com/rufl/DINX/actions/runs/39611695024) from commit `eea66ac`, including package and ISO contracts, QEMU boot, graphical payload validation, Calamares BIOS/UEFI/Btrfs transaction smokes, disposable persistent-install/recovery-TTY smokes, build-metadata verification, persistent package signing, attestation and release publication.
- Published the split ISO parts, SHA-512 checksum, build metadata, Windows QEMU package, signed DINX package repository and verification assets.
- Published ISO size: `2,803,349,504` bytes. Full ISO SHA-512: `50e8d535fd4a482ea5433b454921a34402f64e2aa9f82ed9434cff659820c944df7b44b062ebd56094948147109ff65b6f31889080340de484c36fb5d7eb5b8a`.
- Published signed DINX repository snapshot: `5a61d50f3837161bed1af7619965b44e80bd885e79457e443c328e0151d805d9`.
- Updated the user-facing English and Portuguese landing pages and release documentation to point to Alpha 8.

### Known boundaries

This remains a public alpha. Physical hardware, a real DRM gaming session, authenticated Steam and commercial-game launch, controller input, PipeWire game audio, suspend/resume, GPU recovery, Secure Boot and installed-ISO upgrade/rollback remain outside the release claim.
