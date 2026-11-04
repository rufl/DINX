# Licensing and REUSE

[Português (Brasil)](pt-BR/licensing.md)

DINX is a mixed-content repository. The repository-owned DINX code, configuration, documentation, packaging metadata and release tooling are licensed under the Apache License 2.0.

## Repository policy

- `LICENSE` contains the full Apache-2.0 text for DINX-owned work.
- `REUSE.toml` declares the SPDX license and copyright metadata for tracked files.
- `LICENSES/` contains the canonical license texts used by the REUSE metadata.
- `distro/packages/deetty/deetty-0.1.0.tar.gz` is generated locally during builds from the exact Deetty upstream commit pinned in `source.env`; it is git-ignored, not vendored in the repository, and outside the tracked-file REUSE inventory. Its contents remain under the upstream MIT license, with the internal `LICENSE` and notices preserved in the built package. The DINX package and applications are named `deetty` (Deetty) and Dintor.

The pinned Deetty source revision is fetched from `rufl/DEETTY`, but retains upstream internal module/ABI identifiers, configuration paths, some resource filenames, and qualification markers. DINX's package patches rename the installed command, desktop IDs, D-Bus identity, license paths and qualification executable names; upstream paths retained in patch contexts and extraction checks identify exact pinned source inputs. Renaming the remaining source internals would change the upstream config/protocol contract and requires a separate migration, not a search-and-replace.

Do not relicense or rewrite third-party source, archives or notices to make them match the repository default. Add a specific REUSE annotation when a new vendored artifact uses another license.

## Checking the tree

From the repository root:

```bash
reuse lint
```

A compliant tree reports no missing license information, invalid SPDX expressions, read errors or unused license files. When adding a file, use an SPDX header where practical or update `REUSE.toml` for generated, binary or vendored content.

The license statement describes the repository source and metadata. It does not change the licenses of Artix Linux, desktop components or other packages downloaded while building or installing DINX; those components retain their upstream terms.
