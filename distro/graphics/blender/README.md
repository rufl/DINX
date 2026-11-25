# Blender generated packages

The `blender` branch owns Blender generation. It publishes two verified packages:

- `blender`: DINX lean source build used by the base ISO;
- `blender-full`: official full-featured Blender release, replacing `blender` when users install it later.

`main` consumes the newest `blender/v<version>-dinx<pkgrel>` release through
`distro/graphics/blender/blender.pin`; it does not compile Blender during ISO
assembly. The full package is staged in the signed DINX package repository but
is not installed by the base profile.
