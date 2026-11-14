# patches

DINX-owned edits to foreign source: the patches applied by a recipe's prepare step, plus the
vendored companion sources a patch wires in.

This directory is a placeholder. On the BSD line a patch belongs in the port's `files/` directory so
the ports framework applies it; on the Linux line it sits next to the PKGBUILD under
`distro/packages/<name>/`, where `source=()` entries and `sha256sums` resolve it. Keep patch content
identical across the two lines so one rebase updates both.

Rules: verify a checksum with `distinfo`, apply patches with the ports framework, bump
`PORTREVISION` on any patch change, and record every change in both changelogs.
See [docs/dinxtools.md](../../docs/dinxtools.md).
