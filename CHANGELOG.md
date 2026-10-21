# Changelog

This file records meaningful DINX changes in direct language. It does not claim that the roadmap is complete; the linked qualification evidence and release metadata are the source of truth.

## Unreleased

- Added deterministic xz SquashFS compression with x86 BCJ filtering and a strict P0 budget below GitHub's 2 GiB per-asset limit for future full-ISO releases. Alpha 8 remains split because it predates this change.

## v0.1.0-alpha.8 — 2026-10-21

- Published the current public DINX system alpha for x86_64 Artix Linux with dinit: [GitHub release](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.8).
- Passed tagged release workflow [39611695024](https://github.com/rufl/DINX/actions/runs/39611695024) from commit `eea66ac`, including package and ISO contracts, QEMU boot, graphical payload validation, Calamares BIOS/UEFI/Btrfs transaction smokes, disposable persistent-install/recovery-TTY smokes, build-metadata verification, persistent package signing, attestation and release publication.
- Published the split ISO parts, SHA-512 checksum, build metadata, Windows QEMU package, signed DINX package repository and verification assets.
- Published ISO size: `2,803,349,504` bytes. Full ISO SHA-512: `50e8d535fd4a482ea5433b454921a34402f64e2aa9f82ed9434cff659820c944df7b44b062ebd56094948147109ff65b6f31889080340de484c36fb5d7eb5b8a`.
- Published signed DINX repository snapshot: `5a61d50f3837161bed1af7619965b44e80bd885e79457e443c328e0151d805d9`.
- Updated the user-facing English and Portuguese landing pages and release documentation to point to Alpha 8.

### Known boundaries

This remains a public alpha. Physical hardware, a real DRM gaming session, authenticated Steam and commercial-game launch, controller input, PipeWire game audio, suspend/resume, GPU recovery, Secure Boot and installed-ISO upgrade/rollback remain outside the release claim.
