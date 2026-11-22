# Blender generated packages

Blender generation runs on the `blender` branch, not during every `main` ISO
build. The branch workflow publishes a verified lean `blender` package and a
full-featured `blender-full` replacement package as a
`blender/v<version>-dinx<release>` GitHub release.

The main-branch refresh workflow downloads the newest release, verifies
`SHA256SUMS`, updates `distro/graphics/blender/blender.pin`, and opens a pull
request. P0 then stages the pinned lean package directly instead of compiling
Blender. The full package is included in the signed DINX package repository but
is not installed in the base ISO; installing `blender-full` later replaces the
lean package.
