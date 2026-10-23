# Licensing and REUSE

[Português (Brasil)](pt-BR/licensing.md)

DINX is a mixed-content repository. The repository-owned DINX code, configuration, documentation, packaging metadata and release tooling are licensed under the Apache License 2.0.

## Repository policy

- `LICENSE` contains the full Apache-2.0 text for DINX-owned work.
- `REUSE.toml` declares the SPDX license and copyright metadata for tracked files.
- `LICENSES/` contains the canonical license texts used by the REUSE metadata.
- `distro/packages/noctty/noctty-0.1.0.tar.gz` is a verbatim upstream archive. It remains under its upstream MIT license; its internal `LICENSE` and notices are not replaced by DINX's repository license.

Do not relicense or rewrite third-party source, archives or notices to make them match the repository default. Add a specific REUSE annotation when a new vendored artifact uses another license.

## Checking the tree

From the repository root:

```bash
reuse lint
```

A compliant tree reports no missing license information, invalid SPDX expressions, read errors or unused license files. When adding a file, use an SPDX header where practical or update `REUSE.toml` for generated, binary or vendored content.

The license statement describes the repository source and metadata. It does not change the licenses of Artix Linux, desktop components or other packages downloaded while building or installing DINX; those components retain their upstream terms.
