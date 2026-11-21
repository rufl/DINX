# Blender generated packages

Blender generation runs on the `blender` branch, not during every `main` ISO
build. The branch workflow publishes:

- `blender`, a lean source build for modeling, rigging, texturing and animation;
  XR, USD, MaterialX, OpenVDB, OpenSubdiv, Embree, OpenImageDenoise, oneAPI/SYCL,
  Cycles OSL, Grease Pencil and Haru/PDF output are intentionally omitted.
- `blender-full`, the official upstream binary with all Blender features and
  package metadata that replaces `blender`.

Both packages are published together as a verified
`blender/v<version>-dinx<release>` GitHub release. The main-branch refresh
workflow downloads the release, verifies `SHA256SUMS`, updates
`distro/graphics/blender/blender.pin`, and opens a pull request. P0 stages the
pinned lean package directly instead of compiling Blender. The full package is
available in the signed DINX package repository but is not installed in the base
ISO; this keeps the shipped image under GitHub's strict 2 GiB asset ceiling.
