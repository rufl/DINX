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

For P3, the same package build also runs `scripts/nocted_p3_qualification.sh`. It qualifies the Nocted editor core, real `clangd` diagnostics/navigation, native GTK/X11 dark and light schemes, and bounded Git status/diff markers before the package is eligible for the ISO payload and P0 QEMU/install gate.

## Current validated snapshot

The latest tagged release workflow is [run 39611695024](https://github.com/rufl/DINX/actions/runs/39611695024) for [v0.1.0-alpha.8](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.8), on commit `eea66ac` (`eea66acc83ca26c971ad5407d26dbd32f67d567f`). It passed the first-party/static contracts, Artix package builds, ISO creation, QEMU boot, graphical payload validation, Calamares partition and persistent-install/recovery smokes, build-metadata verification, persistent package signing, attestation and release-asset publication. The published ISO totals 2,803,349,504 bytes and has SHA-512 `50e8d535fd4a482ea5433b454921a34402f64e2aa9f82ed9434cff659820c944df7b44b062ebd56094948147109ff65b6f31889080340de484c36fb5d7eb5b8a`; the stable package repository snapshot is `5a61d50f3837161bed1af7619965b44e80bd885e79457e443c328e0151d805d9`.
Future tagged builds use the deterministic compact-ISO path from
`scripts/build-iso.sh`: xz-compressed SquashFS with x86 BCJ filtering and a
strict ISO budget below GitHub's 2 GiB per-asset limit. Alpha 8 was built before
this change and remains distributed as split ISO parts.
The source-owned common manifest keeps the documented AMDGPU firmware path while leaving generic firmware and `powertop` out of the final image; kernel headers remain available only to the ISO initramfs build and their source tree is excluded from final SquashFS.

## Published assets

Each alpha release contains:

- `dinx-<version>-x86_64.iso` when it fits GitHub's per-asset limit, or the ordered `dinx-<version>-x86_64.iso.part-*` files plus `.iso.parts.json` when it does not;
- the matching `.iso.sha512` file;
- Linux QEMU boot-menu, graphical and post-input PPM captures plus the serial log;
- `dinx-<version>-dogfood.1-windows-x86_64.zip` — a small Windows launcher package;
- the Windows package metadata, ZTASH deployment manifest and `SHA256SUMS`;
- `dinx-<version>-build-metadata.txt` — builder image, source commit, package snapshot, source checksums and ISO digest;
- signed DINX pacman repository assets: `dinx.db`, `dinx.db.tar.gz`, their
  signatures, `dinx-package-signing-key.gpg`, `dinx-repository-metadata.txt` and
  the custom `*.pkg.tar.zst` archives with detached signatures;

## Signed package repository

Tagged releases require the GitHub Actions secret `DINX_PACKAGE_SIGNING_KEY`
containing the unencrypted armored production private key. The workflow fails
before package publication when the secret is absent; the non-tag P0 workflow
continues to use an ephemeral CI key and a `ci` channel.

Provision the secrets from a trusted release operator machine; never commit the
private key or place it in an artifact:

```bash
fingerprint='<40-hex production fingerprint>'
gpg --armor --export-secret-keys "$fingerprint" > /tmp/dinx-package-signing-key.asc
gh secret set DINX_PACKAGE_SIGNING_KEY --repo rufl/DINX < /tmp/dinx-package-signing-key.asc
gh secret set DINX_PACKAGE_SIGNING_FINGERPRINT --repo rufl/DINX --body "$fingerprint"
shred -u /tmp/dinx-package-signing-key.asc
```

The key must be usable non-interactively by `makepkg --sign`; keep the offline
master-key backup separately and rotate deliberately because the fingerprint is
recorded in every repository snapshot and release metadata.

The release repository is a static pacman repository hosted by GitHub release
assets. It contains DINX custom packages only; Artix repositories remain
separate. Install the public key and configure the release URL:

```bash
release_url='https://github.com/rufl/DINX/releases/download/v<version>'
curl --fail --location "$release_url/dinx-package-signing-key.gpg" \
  --output /tmp/dinx-package-signing-key.gpg
pacman-key --add /tmp/dinx-package-signing-key.gpg
pacman-key --lsign-key <signing-fingerprint>
```

```ini
[dinx]
SigLevel = Required
Server = https://github.com/rufl/DINX/releases/download/v<version>
```

Run `pacman -Syu` after refreshing the databases. The P0 workflow performs a
real signed install, update and package downgrade transaction with the pacman
repository contract. That qualifies package transactions, not a full installed
ISO upgrade, filesystem rollback or physical recovery procedure.

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
gh attestation verify dinx-<version>-build-metadata.txt -R rufl/DINX
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
$releaseUrl = 'https://github.com/rufl/DINX/releases/download/v0.1.0-alpha.8'
$zipName = 'dinx-0.1.0-alpha.8-dogfood.1-windows-x86_64.zip'
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
scripts/deploy-ztash.sh v0.1.0-alpha.8
```

The script reads the release metadata, verifies the HTTPS URL, package SHA-256, size,
target and `dinx` application identity, then invokes `zeer ztash assign` in preview
mode. It never prints the token and never creates credentials.

After reviewing the preview, apply explicitly:

```bash
scripts/deploy-ztash.sh v0.1.0-alpha.8 --apply
```

The operation requires the owner-private DDJARIN token in
`ZEER_TOKEN_FILE` (default: `~/.config/overzeer/ddjarin-agent.token`) and sets the
bounded typed `dogfood` action. ZTASH downloads the metadata-pinned launcher package;
it does not receive the ISO through the package upload. The launcher downloads the ISO
from the public release asset and verifies it locally.

The receiver must already have QEMU installed. The deployment is intentionally not a
Windows service installation and does not grant shell access. If QEMU is absent, the
qualification fails explicitly instead of silently substituting another renderer.

## Next alpha gate

Before tagging the next alpha, the tag commit must pass the current local P0 workflow, including the lock/idle/brightness contracts, budget checks and the Calamares partitioning contract. The resulting ISO must pass SquashFS content validation, the 90-second QEMU boot/capture path, the disposable Calamares installation and recovery-TTY smoke, the BIOS/UEFI/Btrfs transaction smoke with pre-existing subvolumes, the Windows side-by-side NTFS-shrink and manual-layout smoke with preserved ESP/Microsoft boot data, checksum generation, artifact attestation and release-asset assembly.
The automated gate also runs real DinitUI daemon/GTK qualification and a bounded Calamares startup smoke under Xvfb. These complement the partition and offline-rootfs transaction smokes; `scripts/smoke-install.sh` remains a rootfs/install-contract test and does not claim a complete Calamares UI installation.

The P0 builder signs the custom pacman repository and records its content snapshot,
database checksum, public-key checksum and signing fingerprint in build metadata.
Non-tag builds use the ephemeral `ci` key. Tagged release builds require the
production key secret and publish the `stable` repository assets described above.

The release operator must manually record one real Wayland session qualification: `Super+L`, the 600-second idle lock, lock-before-suspend, unlock after resume and hardware brightness up/down. A VM can qualify session ordering; physical hardware is required to claim display brightness and suspend support.

Update the run ID, commit, artifact size/digest and release links in the English and Portuguese status documents only after the new workflow is green. P5 gaming claims remain separate until DRM display, Steam/game, controller/audio, return-to-greeter and physical suspend/GPU tests pass.
The tagged release path now has a documented signed package update and package
downgrade path. It does not claim an installed-ISO upgrade, filesystem rollback or
physical recovery procedure. WIZP and optional CUPS remain outside ISO payload claims
until their external artifact or live package transaction is qualified end to end.

Use the [hardware qualification matrix](alpha7-qualification.md); its report
utility retains the Alpha 7 name for compatibility. The generated ISO includes
`dinx-alpha7-hardware-report`, a read-only report utility for attaching
hardware/session evidence without changing system state.

## Release limits

- The live account is `dinx` / `dinx`; it is public, disposable and must never be
  reused.
- The image is still an experimental disk installer without an installed-ISO upgrade,
  filesystem rollback or signed Secure Boot path. CI qualifies the offline rootfs
  contract on disposable BIOS and UEFI disks and captures a recovery-TTY frame; it
  does not qualify arbitrary hardware.
- Release files include GitHub artifact attestations and, after the production key
  secret is configured, a signed DINX pacman database and public signing key. This
  qualifies package transactions, not the installed system's full lifecycle.
- The Windows QEMU test is an external receiver qualification. Its success does not
  turn the alpha image into a supported hardware release.
