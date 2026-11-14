# patches

DINX-owned edits to foreign source: the `.patch` files applied by a recipe's `prepare()`, plus the
vendored companion sources a patch wires in.

This directory is a placeholder. Patches stay next to the recipe that applies them, under
`distro/packages/<name>/`, because `PKGBUILD` `source=()` entries and their `sha256sums` are
position-dependent and the ISO builder resolves them from the package directory.

Rules: apply with `patch --fuzz=0 --forward`, bump `pkgrel` on any change, rebase the whole set when
a pin moves, and record every change in both changelogs.
See [docs/dinxtools.md](../../docs/dinxtools.md).
