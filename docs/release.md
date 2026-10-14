# DINX alpha release

[Português (Brasil)](pt-BR/release.md)

DINX releases are pre-release validation snapshots, not supported disk-installer releases.
The release workflow is triggered by a `v*` tag and reuses the P0 Artix build, payload
check, SHA-512 generation and QEMU smoke path before publishing assets.

## Published assets

Each alpha release contains:

- `dinx-<version>-x86_64.iso` — the live validation image;
- the matching `.iso.sha512` file;
- Linux QEMU graphical and post-input PPM captures plus the serial log;
- `dinx-<version>-dogfood.1-windows-x86_64.zip` — a small Windows launcher package;
- the Windows package metadata, ZTASH deployment manifest and `SHA256SUMS`.

The Windows package does not contain a second copy of the ISO. It contains a pinned
HTTPS URL and the ISO SHA-512. On first run it downloads the exact release asset to its
private directory, verifies the checksum, and only then starts QEMU.

## Windows visual smoke test

Requirements:

- Windows x86_64;
- QEMU System x86_64, with `qemu-system-x86_64.exe` on `PATH` or `DINX_QEMU` set;
- a desktop session for the SDL display;
- enough disk space for the ISO and at least 2 GiB guest memory.

From the extracted package:

```powershell
.\dinx.exe --visual-test
```

The default command (`.\dinx.exe`) is equivalent. The launcher boots the ISO with
QEMU, sends the tested greeter key sequence, captures the initial greeter frame and a
post-input session frame, validates both as binary PPM files, and terminates QEMU.
Evidence is retained under `evidence\` beside the package. The bounded headless gate
used by package qualification is:

```powershell
.\dinx.exe --package-smoke
```

This test proves QEMU startup, the ISO boot window and screenshot creation. It does not
prove hardware GPU acceleration, audio, networking or persistent installation.

## ZTASH deployment to DDJARIN

The package metadata targets the registered `ddjarin` Windows receiver. On the trusted
owner machine, preview the immutable assignment first:

```bash
scripts/deploy-ztash.sh v0.1.0-alpha.1
```

The script reads the release metadata, verifies the HTTPS URL, package SHA-256, size,
target and `dinx` application identity, then invokes `zeer ztash assign` in preview
mode. It never prints the token and never creates credentials.

After reviewing the preview, apply explicitly:

```bash
scripts/deploy-ztash.sh v0.1.0-alpha.1 --apply
```

The operation requires the owner-private DDJARIN token in
`ZEER_TOKEN_FILE` (default: `~/.config/overzeer/ddjarin-agent.token`) and sets the
bounded typed `dogfood` action. ZTASH downloads the metadata-pinned launcher package;
it does not receive the ISO through the package upload. The launcher downloads the ISO
from the public release asset and verifies it locally.

The receiver must already have QEMU installed. The deployment is intentionally not a
Windows service installation and does not grant shell access. If QEMU is absent, the
qualification fails explicitly instead of silently substituting another renderer.

## Release limits

- The live account is `dinx` / `dinx`; it is public, disposable and must never be
  reused.
- The image is not a supported disk installer and has no persistence, rollback or
  signed Secure Boot path.
- The current alpha release publishes checksums but no package or ISO signature; this
  is recorded as `signing: unavailable` in the dogfood metadata.
- The Windows QEMU test is an external receiver qualification. Its success does not
  turn the alpha image into a supported hardware release.
