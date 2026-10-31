# DINX alpha release

[Português (Brasil)](pt-BR/release.md)

DINX releases are pre-release validation snapshots, not supported disk-installer releases.
The release workflow is triggered by a `v*` tag and reuses the P0 Artix build, payload
check, SHA-512 generation and QEMU smoke path before publishing assets.
Build metadata is bound to the exact ISO artifact in both the P0 and tagged release paths: CI recomputes the ISO byte count and SHA-512 and rejects metadata that does not match the downloaded file.

The release workflow maintains a rolling `alpha-latest` prerelease with `dinx-latest-x86_64.iso` and its SHA-512 checksum. Tagged releases refresh it; use `workflow_dispatch` with `release_tag` only to seed or resync it. GitHub's 2 GiB per-asset limit means the alias is available only when the latest alpha is a single ISO asset; use the versioned release page when an ISO is split. The publisher retries transient 404s while release metadata, assets and alias uploads become visible, waits for the release listing to catch up, and refuses to let an older alpha roll back the alias.


The P0 build verifies the committed upstream source archive for Deetty and Dintor against the exact
repository commit and SHA-256 contract in `distro/packages/deetty/source.env`, builds
the native `deetty` package with Zig 0.17.0, and verifies that Deetty, Dintor and
their desktop/editor resources are in the ISO. The release path does not clone the
pinned upstream NOCTTY repository or require a repository secret; update the archive
and contract together when changing the pinned source.

For P3, the same package build also runs `scripts/dintor_p3_qualification.sh`. It
qualifies the Dintor editor core, real `clangd` diagnostics/navigation, native GTK/X11
dark and light schemes, and bounded Git status/diff markers before the package is
eligible for the ISO payload and P0 QEMU/install gate.

## Current validated snapshot

The published Alpha 10 snapshot is [v0.1.0-alpha.10](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.10), validated by [tagged workflow 40879223746](https://github.com/rufl/DINX/actions/runs/40879223746) on commit `3fd3cd036cab7e8fb553e6e5c244b02429f1a18e`. Its build passed the package/profile contracts, Artix package builds, ISO-content and size checks, QEMU boot and graphical payload, Calamares layout smokes, persistent BIOS/UEFI first-boot and recovery-TTY smokes, signed package-repository checks, metadata binding, attestation and publication. The direct ISO is 1,862,772,736 bytes with SHA-512 `5f49a65eac1481c01555a8f44b049c9a06e75ec7270ac3cdef97cc5e0b051d4b3c48a200542a36ec1832700accbc5509e3c314726c2f747530095eba4112219a`; package repository snapshot `b0015a0655d7d56a4949731d1a4f33cb2cc8daa55d4ec77df6d1a22161d2f5fd`.

Main P0 run [40894570770](https://github.com/rufl/DINX/actions/runs/40894570770) on commit `bf773500965c843e014e3bc3ef8fea685e14b91b` passed the full build, QEMU, graphical payload, Calamares and persistent BIOS/UEFI installation/recovery gates, plus metadata, attestation and artifact upload. It is a post-release main validation; the published Alpha 10 ISO remains the artifact from tagged run [40879223746](https://github.com/rufl/DINX/actions/runs/40879223746) on commit `3fd3cd036cab7e8fb553e6e5c244b02429f1a18e`.

The next system milestone is the planned, undated Beta 0.1 qualification. It is separate from P5 gaming; see the [roadmap](roadmap.md) for its hardware, installer, update and recovery gates.

Alpha 9 and earlier candidate runs are historical; they are not the current release evidence. The release workflow rebuilds the tagged commit and publishes only after matching ISO metadata, signed-repository, checksum and provenance checks pass.

The Alpha 9 artifact used the earlier deterministic compact-ISO path from
`scripts/build-iso.sh`: xz-compressed SquashFS with x86 BCJ filtering, 1 MiB
blocks and a 1 MiB dictionary. Alpha 10 uses 256 KiB blocks and a 256 KiB
dictionary, keeping the direct ISO below GitHub's 2 GiB per-asset limit.
The source-owned common manifest keeps the documented AMDGPU firmware path while leaving generic firmware and `powertop` out of the final image; kernel headers remain available only to the ISO initramfs build and their source tree is excluded from final SquashFS.

## Published assets

Each alpha release contains:

- `dinx-<version>-x86_64.iso` when it fits GitHub's per-asset limit; older releases that exceed it use ordered `.iso.part-*` files plus `.iso.parts.json`;
- the matching `.iso.sha512` file;
- a rolling direct-download alias, `dinx-latest-x86_64.iso`, and its matching `.sha512` checksum under the `alpha-latest` prerelease; the workflow refreshes it from the newest published alpha with a single ISO asset below GitHub's 2 GiB per-asset limit, which requires a second copy of the ISO;
- Linux QEMU boot-menu, graphical and post-session PPM captures plus the serial log;
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

For a direct ISO, verify the matching checksum:

```bash
sha512sum -c dinx-<version>-x86_64.iso.sha512
```

When a release publishes split parts, concatenate them in lexical order and
then verify the full image:

```bash
cat dinx-<version>-x86_64.iso.part-* > dinx-<version>-x86_64.iso
sha512sum -c dinx-<version>-x86_64.iso.sha512
```

The Windows package does not contain a second copy of the ISO. It contains a pinned
HTTPS URL and the ISO SHA-512 plus, when required, the ordered part list. On first run it
downloads the exact release assets to its private directory, verifies each part when
present, assembles the ISO when necessary, verifies the full checksum, and only then
starts QEMU.
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
$releaseUrl = 'https://github.com/rufl/DINX/releases/download/v0.1.0-alpha.10'
$zipName = 'dinx-0.1.0-alpha.10-dogfood.1-windows-x86_64.zip'
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
then captures the autologged-in session frame and a later post-session frame,
validates all three as binary PPM files and terminates QEMU. Evidence is retained
under `evidence\` beside the package. The bounded headless gate used by package
qualification is:

```powershell
.\dinx.exe --package-smoke
```

This test proves QEMU startup, the ISO boot window and screenshot creation. It does not
prove hardware GPU acceleration, audio, networking or persistent installation.

## ZTASH deployment to DDJARIN

The package metadata targets the registered `ddjarin` Windows receiver. On the trusted
owner machine, preview the immutable assignment first:

```bash
scripts/deploy-ztash.sh v0.1.0-alpha.10
```

The script reads the release metadata, verifies the HTTPS URL, package SHA-256, size,
target and `dinx` application identity, then invokes `zeer ztash assign` in preview
mode. It never prints the token and never creates credentials.

After reviewing the preview, apply explicitly:

```bash
scripts/deploy-ztash.sh v0.1.0-alpha.10 --apply
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

Update run IDs, commits, artifact sizes/digests and release links in the English and Portuguese status documents only after the relevant workflow is green. The planned Beta 0.1 system release does not claim gaming support; P5 remains separate until real DRM output, Steam/game, controller/audio, greeter-return and physical suspend/GPU tests pass.
The tagged release path now has a documented signed package update and package
downgrade path. It does not claim an installed-ISO upgrade, filesystem rollback or
physical recovery procedure. WIZP and optional CUPS remain outside ISO payload claims
until their external artifact or live package transaction is qualified end to end.

Use the [hardware qualification matrix](alpha7-qualification.md); its report
utility retains the Alpha 7 name for compatibility. The generated ISO includes
`dinx-alpha7-hardware-report`, a read-only report utility for attaching
hardware/session evidence without changing system state.

## Release limits

- The live image autologs into the disposable `dinx` account and keeps the public `dinx` password only as a diagnostic fallback if Pearl Greeter appears after a manual live start. It is never an authentication boundary and must not be reused.
- The image is still an experimental disk installer without an installed-ISO upgrade,
  filesystem rollback or signed Secure Boot path. CI qualifies the offline rootfs
  contract on disposable BIOS and UEFI disks and captures a recovery-TTY frame; it
  does not qualify arbitrary hardware.
- Release files include GitHub artifact attestations and, after the production key
  secret is configured, a signed DINX pacman database and public signing key. This
  qualifies package transactions, not the installed system's full lifecycle.
- The Windows QEMU test is an external receiver qualification. Its success does not
  turn the alpha image into a supported hardware release.
