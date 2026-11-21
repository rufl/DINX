# Blender generated packages

The `blender` branch owns Blender generation. It publishes two verified packages:

- `blender`: lean source build for modeling, rigging, texturing and animation;
  heavyweight integrations such as XR, USD, MaterialX, OpenVDB, OpenSubdiv,
  Embree, OpenImageDenoise, oneAPI/SYCL, Cycles OSL, Grease Pencil and Haru
  remain out of the ISO payload.
- `blender-full`: official upstream binary with all Blender features. It
  replaces `blender` when users install the supplemental package.

`main` consumes the newest `blender/v<version>-dinx<pkgrel>` release through
`distro/graphics/blender/blender.pin`; it does not compile Blender during ISO
assembly. Both packages are staged in the signed DINX package repository, but
only the lean package is installed by the base profile so the ISO remains under
the strict 2 GiB GitHub asset ceiling.
