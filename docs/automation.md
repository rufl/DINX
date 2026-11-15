# Package, security and ISO automation

`main` uses four independent, concurrency-controlled automations:

- **Upstream prefetch:** `.github/workflows/upstream-cache-prefetch.yml` runs at `04:17` and `16:17` UTC. It resolves packages required by the builder and DINX images, excludes packages produced by this repository, runs `pacman -Syy`/`pacman -Sw --needed` inside the pinned Artix image, and saves only the verified delta cache.
- **Source refresh:** `.github/workflows/upstream-package-refresh.yml` checks upstream releases daily at `03:17` UTC. Changes are checksum-pinned, tested, and opened as a PR; the workflow never writes pins directly to `main`.
- **Dependency audit:** `.github/workflows/security-scan.yml` runs on PRs, pushes to `main`, manual dispatch, and daily at `01:17` UTC. It generates an SPDX SBOM and runs Grype, Trivy, and OSV-Scanner. High/Critical findings block the job; Trivy ignores unfixed findings by policy. SARIF reports go to Code Scanning and artifacts are retained for 30 days.
- **Nightly ISO:** `.github/workflows/p0-iso.yml` runs at `02:17` UTC, once per day. The build restores the upstream cache, builds the ISO, and only attests/uploads the workflow artifact after the P0 gates, the final-rootfs SBOM, QEMU boot, and disposable installation pass. The final-rootfs SBOM is generated for the record but is not scanned as a blocking gate (see [Security boundaries](#security-boundaries)); the artifact is retained for 14 days.

## Cache

`dist/.cache/dinx/pacman/pkg` is a separate category. DINX package artifacts, source/Cargo/Zig data, and toolchains use separate keys. The upstream cache key is prefixed by architecture and package-set identity; every run saves a new key, so restore selects the newest snapshot without overwriting immutable Actions cache entries.

Local builds without `pacman` remain possible and emit a warning. CI prefetch uses `--strict` and fails when the Artix base cannot refresh databases or download a package.

## Security boundaries

Checksums, pacman signatures, and attestations prove integrity and provenance; they do not prove absence of CVEs. Grype/Trivy/OSV cover what their catalogs recognize. The PR/push `security-scan.yml` job scans the source-manifest SBOM and still blocks on High/Critical findings. The final-rootfs SBOM is generated for the record but its Grype scan is not a blocking gate, because on an Arch-family rootfs it produced overwhelmingly false positives: syft emits no `pkg:alpm` purl for pacman packages, so Grype falls back to name-only CPE matching and has no Arch/Artix vulnerability feed. Measured on the real rootfs, GNU `tar 1.35` was reported against npm `tar` advisories, `fish 4.9` against a PHP CVE, and current `ffmpeg 2:9.0` against CVEs fixed in `3.1`. The SBOM is therefore scoped to the installed (`alpm`) cataloger via `.github/syft-iso-filesystem.yaml` so it reflects the ~900 packages pacman actually installed rather than ~7,590 file fingerprints. No peer Arch-based distribution (Arch, Manjaro, EndeavourOS, CachyOS, Artix) gates its ISO build on a filesystem CVE scan; Arch maintains a human-curated security tracker instead. A clean source-scan result must be interpreted within those coverage and severity-policy boundaries.
