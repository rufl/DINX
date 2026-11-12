# Package, security and ISO automation

`main` uses four independent, concurrency-controlled automations:

- **Upstream prefetch:** `.github/workflows/upstream-cache-prefetch.yml` runs at `04:17` and `16:17` UTC. It resolves packages required by the builder and DINX images, excludes packages produced by this repository, runs `pacman -Syy`/`pacman -Sw --needed` inside the pinned Artix image, and saves only the verified delta cache.
- **Source refresh:** `.github/workflows/upstream-package-refresh.yml` checks upstream releases daily at `03:17` UTC. Changes are checksum-pinned, tested, and opened as a PR; the workflow never writes pins directly to `main`.
- **Dependency audit:** `.github/workflows/security-scan.yml` runs on PRs, pushes to `main`, manual dispatch, and daily at `01:17` UTC. It generates an SPDX SBOM and runs Grype, Trivy, and OSV-Scanner. High/Critical findings block the job; Trivy ignores unfixed findings by policy. SARIF reports go to Code Scanning and artifacts are retained for 30 days.
- **Nightly ISO:** `.github/workflows/p0-iso.yml` runs at `02:17` UTC, once per day. The build restores the upstream cache, builds the ISO, and only attests/uploads the workflow artifact after P0 gates, final-rootfs SBOM/scanning, QEMU boot, and disposable installation pass. The artifact is retained for 14 days.

## Cache

`dist/.cache/dinx/pacman/pkg` is a separate category. DINX package artifacts, source/Cargo/Zig data, and toolchains use separate keys. The upstream cache key is prefixed by architecture and package-set identity; every run saves a new key, so restore selects the newest snapshot without overwriting immutable Actions cache entries.

Local builds without `pacman` remain possible and emit a warning. CI prefetch uses `--strict` and fails when the Artix base cannot refresh databases or download a package.

## Security boundaries

Checksums, pacman signatures, and attestations prove integrity and provenance; they do not prove absence of CVEs. Grype/Trivy/OSV cover what their catalogs recognize. Final-rootfs auditing is additional to source-manifest auditing. A clean result must be interpreted within those coverage and severity-policy boundaries.
