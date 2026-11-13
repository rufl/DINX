# DINX-BSD Implementation Status

DINX-BSD is under active porting. This document records implemented and
unimplemented behavior; it is not a completion claim.

## Implemented: installer ISO foundation

- `scripts/build-bsd-iso.sh` downloads the checksum-pinned FreeBSD 15.1 disc1
  image, builds a deterministic DINX-BSD overlay, updates the FreeBSD
  distribution manifest, preserves BIOS/UEFI boot metadata, and emits an ISO
  plus SHA-256 metadata.
- `distro/bsd/iso/installerconfig` drives FreeBSD's supported scripted
  `bsdinstall` path.
- `scripts/check-bsd-iso.sh` verifies boot entries, the `bsdinstall`
  preamble/script split (both halves syntax-checked), overlay checksum, file
  count, required payload, and that any shipped `.pkg` is a real FreeBSD
  package with a root `+COMPACT_MANIFEST`.
- `scripts/build-bsd-iso-unattended.py` installs the generated ISO to a
  disposable QEMU disk and requires the installed system's first-boot marker.
- `.github/workflows/bsd-iso.yml` runs the real build/install gate and uploads
  the ISO and qualification evidence without suppressing failures.

## Embedded base payload

- BSD package manifest and custom port recipes under
  `/usr/local/share/dinx-bsd/`.
- `rc.d/dinx_firstboot` (one-shot desktop setup after networking, detached
  via `daemon(8)` so it cannot block boot), `rc.d/dinx_greetd` (greetd
  supervision), `dinx-session` (Wayland session wrapper), and a greetd
  `config.toml`.
- Dinit service definitions under `/usr/local/etc/dinit.d/` (reference units;
  FreeBSD uses the rc.d chain above, dinit is not PID 1).
- OctaPkg configuration under `/usr/local/etc/octapkg.conf` and a UCL local
  repository definition under `/usr/local/etc/pkg/repos/dinx.conf`.
- `/etc/dinx-release`, DHCP configuration, and serial/video multiconsole boot.

## Not complete

- The custom FreeBSD ports are templates and still need valid source releases,
  checksums, plists, per-origin directory layout, and FreeBSD build validation.
  No native Aqueous/Pearl binaries exist yet; `build-bsd-ports-local.sh`
  refuses to emit packages when a build fails or the host is not FreeBSD.
- The local DINX repository definition ships, but no package catalog, signing
  keys, or publication pipeline exist yet.
- The generated ISO installs the FreeBSD/DINX base overlay; the first-boot
  step installs the real upstream graphical stack (seatd, PipeWire,
  WirePlumber, Wayland, wlroots020, mesa-dri) when network is available.
  greetd is absent from FreeBSD ports; the design builds it from source into
  the local DINX repository (`dinx-greetd`). The custom desktop set remains
  pending.
- Graphical first boot and hardware qualification remain pending: until
  Aqueous is built natively, `dinx-session` exits with an explicit error.

## Verification

Run `./scripts/build-bsd-iso.sh` for artifact/static validation or
`./scripts/build-bsd.sh` for the complete QEMU install/reboot gate. See
`docs/DINX-BSD-BUILD-GUIDE.md` for prerequisites, artifacts, and the destructive
disk-install warning.
