# DINX alpha release

[Português (Brasil)](pt-BR/release.md)

DINX releases are pre-release validation snapshots, not supported disk-installer releases.
The release workflow is triggered by a `v*` tag and reuses the P0 Artix build, payload
check, SHA-512 generation and QEMU smoke path before publishing assets.

The P0 build verifies the committed NOCTTY/NoctEd source archive against the exact
repository commit and SHA-256 contract in `distro/packages/noctty/source.env`, builds
the native `noctty` package with Zig 0.17.0, and verifies that both applications and
their desktop/editor resources are in the ISO. The release path does not clone NOCTTY
or require a repository secret; update the archive and contract together when changing
the pinned source.

## Current validated snapshot

The latest successful P0 workflow is [run 38753069331](https://github.com/rufl/DINX/actions/runs/38753069331), on commit `b0e3040`. It passed the Firefox pro-user policy, BC250 Control Center v1.21.1 contract, Artix package builds, ISO creation, QEMU boot, graphical payload validation, persistent-install/recovery-TTY smoke, attestation and artifact upload. The workflow artifact is `dinx-foundation-iso-b0e3040f8294f2e7c45fc3ce3c4b5fe84e6aa1e4`; it remains a validation artifact, not a stable hardware release.

## Published assets

Each alpha release contains:

- `dinx-<version>-x86_64.iso` when it fits GitHub's per-asset limit, or the ordered `dinx-<version>-x86_64.iso.part-*` files plus `.iso.parts.json` when it does not;
- the matching `.iso.sha512` file;
- Linux QEMU boot-menu, graphical and post-input PPM captures plus the serial log;
- `dinx-<version>-dogfood.1-windows-x86_64.zip` — a small Windows launcher package;
- the Windows package metadata, ZTASH deployment manifest and `SHA256SUMS`.

When the ISO is split, concatenate the parts in lexical order and verify the full image:

```bash
cat dinx-<version>-x86_64.iso.part-* > dinx-<version>-x86_64.iso
sha512sum -c dinx-<version>-x86_64.iso.sha512
```

The Windows package does not contain a second copy of the ISO. It contains a pinned
HTTPS URL and the ISO SHA-512 plus, when required, the ordered part list. On first run it
downloads the exact release assets to its private directory, verifies each part, assembles
the ISO, verifies the full checksum, and only then starts QEMU.
## Verify release provenance
The release workflow creates GitHub artifact attestations for the ISO or its parts, its checksums,
the Windows launcher and its release metadata. Verify each downloaded file online with
GitHub CLI:

```bash
gh attestation verify dinx-<version>-x86_64.iso -R rufl/DINX
gh attestation verify dinx-<version>-x86_64.iso.part-00 -R rufl/DINX
gh attestation verify dinx-<version>-dogfood.1-windows-x86_64.zip -R rufl/DINX
```

Use the direct ISO command only when that asset exists; otherwise repeat the part command
for every `.iso.part-*` file. The `.sha512` and `SHA256SUMS` files remain useful offline
integrity checks. An attestation proves the file's GitHub Actions build provenance; it does
not make the experimental installer or hardware support production-ready.


## Verify the Windows archive

Download `SHA256SUMS` from the same GitHub release as the ZIP. Do not copy a
checksum from an older package or a different release:

```powershell
$downloadRoot = (Get-Location).Path
$releaseUrl = 'https://github.com/rufl/DINX/releases/download/v0.1.0-alpha.5'
$zipName = 'dinx-0.1.0-alpha.5-dogfood.1-windows-x86_64.zip'
$zipPath = Join-Path $downloadRoot $zipName
$sumPath = Join-Path $downloadRoot 'SHA256SUMS'

if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) {
    Invoke-WebRequest -UseBasicParsing -Uri "$releaseUrl/$zipName" -OutFile $zipPath
}
if (-not (Test-Path -LiteralPath $sumPath -PathType Leaf)) {
    Invoke-WebRequest -UseBasicParsing -Uri "$releaseUrl/SHA256SUMS" -OutFile $sumPath
}

$expected = @(
    Get-Content -LiteralPath $sumPath |
        Where-Object { $_ -match [regex]::Escape($zipName) } |
        ForEach-Object { ($_ -split '\s+')[0] }
)
if ($expected.Count -ne 1) {
    throw "ZIP checksum was not found exactly once in SHA256SUMS"
}
$actual = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected[0].ToLowerInvariant()) {
    throw "ZIP SHA-256 mismatch. Expected: $($expected[0]); actual: $actual"
}
Write-Host "ZIP SHA-256 verified: $actual"
```

## Windows visual smoke test

Requirements:
- Windows PowerShell or PowerShell 7;
- QEMU System x86_64, with `qemu-system-x86_64.exe` on `PATH` or `DINX_QEMU` set;
- a desktop session for the SDL display;
- enough disk space for the ISO and at least 2 GiB guest memory.

From the extracted package:

```powershell
.\dinx.exe --visual-test
```

The default command (`.\dinx.exe`) is equivalent. The launcher boots the ISO with
QEMU, captures the graphical boot-menu frame before sending the tested boot keys,
then sends the greeter key sequence, captures the initial greeter frame and a
post-input session frame, validates all three as binary PPM files and terminates
QEMU. Evidence is retained under `evidence\` beside the package. The bounded headless
gate used by package qualification is:

```powershell
.\dinx.exe --package-smoke
```

This test proves QEMU startup, the ISO boot window and screenshot creation. It does not
prove hardware GPU acceleration, audio, networking or persistent installation.

## ZTASH deployment to DDJARIN

The package metadata targets the registered `ddjarin` Windows receiver. On the trusted
owner machine, preview the immutable assignment first:

```bash
scripts/deploy-ztash.sh v0.1.0-alpha.5
```

The script reads the release metadata, verifies the HTTPS URL, package SHA-256, size,
target and `dinx` application identity, then invokes `zeer ztash assign` in preview
mode. It never prints the token and never creates credentials.

After reviewing the preview, apply explicitly:

```bash
scripts/deploy-ztash.sh v0.1.0-alpha.5 --apply
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
- The image is still an experimental disk installer with no upgrade, rollback or
  signed Secure Boot path. CI qualifies the offline rootfs contract on a disposable
  BIOS disk and captures a recovery-TTY frame; it does not qualify arbitrary hardware.
- Release files have GitHub artifact attestations, but the image does not yet ship a
  pacman repository signing key or signed package database for installed-system updates.
- The Windows QEMU test is an external receiver qualification. Its success does not
  turn the alpha image into a supported hardware release.
