# DINX alpha release

[Português (Brasil)](pt-BR/release.md)

DINX releases are pre-release validation snapshots, not supported disk-installer releases.
The release workflow is triggered by a `v*` tag and reuses the P0 Artix build, payload
check, SHA-512 generation and the QEMU boot smokes configured in P0 before publishing assets. The published Alpha 12 run exercised default VGA, not VMware-SVGA; the current shared qualifier tests default VGA and Virtio-VGA. QEMU 11.1.2/KVM's `vmware-svga` path stalls in early udev with `vmwgfx` loaded and is not a VirtualBox pass.
Build metadata is bound to the exact ISO artifact in both the P0 and tagged release paths: CI recomputes the ISO byte count and SHA-512 and rejects metadata that does not match the downloaded file.

The release workflow maintains a rolling `alpha-latest` prerelease with `dinx-latest-x86_64.iso` and its SHA-512 checksum. Tagged releases refresh it; use `workflow_dispatch` with `release_tag` only to seed or resync it. GitHub's 2 GiB per-asset limit means the alias is available only when the latest alpha is a single ISO asset; use the versioned release page when an ISO is split. The publisher retries transient 404s while release metadata, assets and alias uploads become visible, waits for the release listing to catch up, and refuses to let an older alpha roll back the alias.


The P0 build verifies the locally generated upstream source archive for Deetty and Dintor against the exact
repository commit and SHA-256 contract in `distro/packages/deetty/source.env`, builds
the native `deetty` package with Zig 0.17.0, and verifies that Deetty, Dintor and
their desktop/editor resources are in the ISO. The release path does not clone the
pinned Deetty repository or require a separate repository secret when its visibility
and GitHub token permissions allow access; update the archive and contract together
when changing the pinned source.

For P3, the same package build runs `scripts/dintor_p3_qualification.sh`. It
qualifies the Dintor editor core, native GTK/X11 dark and light schemes, bounded
Git status/diff markers, and the generic stdio LSP client against a real
`clangd` server. This is a builder-only protocol check; the ISO includes ZLS
for Zig and does not ship the `clang` package.

## Current validated snapshot

The current tagged release is [v0.1.0-alpha.12](https://github.com/rufl/DINX/releases/tag/v0.1.0-alpha.12), validated by [workflow 41197618617](https://github.com/rufl/DINX/actions/runs/41197618617) on commit `56a814575e33bfae6215993972784f11b7dae215`. The direct ISO is 1,836,830,720 bytes with SHA-512 `ac1dbd237e484f8d61aab5438185218b13d9e23824ce671440ff67ed275ce7073b90dbcc14bc8d8f7008b2422d66e2756f1b3a88a0d5c21d8c7bbc67c9d60bf9`; signed package-repository snapshot `37dfe99d5e4003e217e786ef82c8ea29562693db2d44b996a9624a68f31c490d`. Alpha 12 predates the later VMware/Pixman source fix. The current shared qualifier tests default VGA and Virtio-VGA; QEMU 11.1.2/KVM's `vmware-svga` path stalls in early udev with `vmwgfx` loaded and is not a VirtualBox pass. Direct VirtualBox boot remains unqualified.

Main P0 run [40894570770](https://github.com/rufl/DINX/actions/runs/40894570770) on commit `bf773500965c843e014e3bc3ef8fea685e14b91b` passed the full build, QEMU, graphical payload, Calamares and persistent BIOS/UEFI installation/recovery gates, plus metadata, attestation and artifact upload. It is an earlier post-Alpha-10 main validation; Alpha 12 was published later by tagged run [41197618617](https://github.com/rufl/DINX/actions/runs/41197618617) on commit `56a814575e33bfae6215993972784f11b7dae215`.

The next system milestone is the planned, undated Beta 0.1 qualification. It is separate from P5 gaming; see the [roadmap](roadmap.md) for its hardware, installer, update and recovery gates.

Alpha 9 and earlier candidate runs are historical; they are not the current release evidence. The release workflow rebuilds the tagged commit and publishes only after matching ISO metadata, signed-repository, checksum and provenance checks pass.

The final SquashFS uses the deterministic compact-ISO path from
`scripts/build-iso.sh`: xz compression with x86 BCJ filtering, 1 MiB blocks
and a 1 MiB dictionary, keeping the direct ISO below GitHub's 2 GiB
per-asset limit.
The source-owned common manifest keeps the documented AMDGPU firmware path while leaving generic firmware and `powertop` out of the final image; kernel headers remain available only to the ISO initramfs build and their source tree is excluded from final SquashFS.

The current profile ships PaintFE, Transit and Zenkai plus the repacked binary
apps Patchy and Blockbench as pre-extracted `/opt/<package>/` trees (repack
convention in `distro/iso/README.md`), and EuroOffice as the office/PDF suite.
Each binary package installs a `/usr/bin/<package>` launcher that execs the
tree's `AppRun` — no FUSE and no per-launch tmpfs extraction. EuroOffice is the
default `application/pdf` and OOXML handler, consumed from the office branch's
lean `eurooffice/v*` releases with a SHA256-verified pacman package and live
squashfs. Images over GitHub's 2 GiB per-asset limit use the split release
path; the rolling single-file alias advances only for a qualifying
single-image release.

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

## Signed rolling package repository

DINX source now configures a signed rolling pacman repository hosted as GitHub
Release assets under `dinx-packages-latest` at
`https://github.com/rufl/DINX/releases/download/dinx-packages-latest`.
The weekly updater opens one reviewed pull request for 21 configured custom-package
source pins every Monday at 04:17 UTC; the Noto Latin subset is refreshed
monthly. It never writes pins to `main`.
Deetty's private commit pin and the ZLS/Zig 0.16 coupled pins remain manually
maintained. After package changes merge, a separate workflow builds and signs
the package repository without assembling an ISO; package-only changes no
longer trigger P0 ISO assembly. These workflows are configured but have not
yet been confirmed green or published to the rolling release.

`dinx-keyring` configures the `[dinx]` repository with required package
signatures and `/etc/pacman.d/dinx-mirrorlist`. That editable mirrorlist lets
operators add future mirrors without changing repository configuration. The
trusted production signing fingerprint is
`D8F294B7367BD0DAF626E4DCD411E36494CB9CEB`; the published public-key file's
expected SHA-256 is
`dcebc6d08e1e46738e768bcd91ece5beb3ef4f8752079f0babba864fb41a6445`.

### Configure the production signing secret

Before enabling publication, a trusted release operator must configure the
GitHub Actions secret `DINX_PACKAGE_SIGNING_KEY` with the unencrypted armored
production private key and `DINX_PACKAGE_SIGNING_FINGERPRINT` with its exact
fingerprint. The key must be usable non-interactively by `makepkg --sign`.
Provision secrets from a trusted operator machine; never commit or upload the
private key.

If `rufl/DEETTY` remains private, configure the Actions secret
`DEETTY_SOURCE_READ_TOKEN` with read-only Contents access to that repository.
The contracts and publisher need it to fetch the pinned source; the DINX
`GITHUB_TOKEN` can be used only if repository policy grants it that access.

```bash
fingerprint='D8F294B7367BD0DAF626E4DCD411E36494CB9CEB'
gpg --armor --export-secret-keys "$fingerprint" > /tmp/dinx-package-signing-key.asc
gh secret set DINX_PACKAGE_SIGNING_KEY --repo rufl/DINX < /tmp/dinx-package-signing-key.asc
gh secret set DINX_PACKAGE_SIGNING_FINGERPRINT --repo rufl/DINX --body "$fingerprint"
shred -u /tmp/dinx-package-signing-key.asc
```

Keep the offline master-key backup separately and rotate deliberately. P0
qualification uses an ephemeral CI key; it is not the production update key.

### Bootstrap package trust

When the rolling repository is published but `dinx-keyring` is not yet
available, configure trust manually on a system that needs the packages.
Download the public key, verify both its SHA-256 and full OpenPGP fingerprint
before importing or locally trusting it:
```bash
set -euo pipefail
repo_url='https://github.com/rufl/DINX/releases/download/dinx-packages-latest'
key=/tmp/dinx-package-signing-key.gpg
curl --fail --location "$repo_url/dinx-package-signing-key.gpg" --output "$key"
printf '%s  %s\n' \
  'dcebc6d08e1e46738e768bcd91ece5beb3ef4f8752079f0babba864fb41a6445' "$key" |
  sha256sum --check
gpg --show-keys --with-colons "$key" |
  awk -F: '$1 == "fpr" { print $10; exit }' |
  grep --fixed-strings --line-regexp 'D8F294B7367BD0DAF626E4DCD411E36494CB9CEB'
sudo pacman-key --add "$key"
sudo pacman-key --lsign-key D8F294B7367BD0DAF626E4DCD411E36494CB9CEB
```

Add the repository to `/etc/pacman.conf` after the Artix repositories:

```ini
[dinx]
SigLevel = Required
Include = /etc/pacman.d/dinx-mirrorlist
```

Create `/etc/pacman.d/dinx-mirrorlist` with the rolling release URL:

```ini
Server = https://github.com/rufl/DINX/releases/download/dinx-packages-latest
```

Refresh databases and install the keyring when it becomes available:

```bash
sudo pacman -Syu --needed dinx-keyring
```

After setup, Shelly uses pacman and the `[dinx]` repository for package updates:
run `shelly sync`, review with `shelly list-updates all`, then apply with
`shelly upgrade all` (or `sudo pacman -Syu`). Required signatures make pacman
reject unsigned or untrusted repository packages.

The currently documented tagged-release workflow may also attach signed
repository assets to an ISO release. Those assets do not establish that the
separate rolling repository or its update workflow has been published.

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

The P0 builder signs its temporary custom pacman repository and records the
snapshot, database checksum, public-key checksum and signing fingerprint in
build metadata. This qualification is distinct from the planned rolling
repository. Configure the production signing secrets before enabling that
publication path; it publishes package changes independently of the ISO after
reviewed source-pin changes are merged.

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
