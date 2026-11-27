# WIZP lean DINX package

This package keeps WIZP's Bun, Electrobun launcher, frontend, app resources,
and native wrapper, but links its CEF runtime to the exact EuroOffice runtime at
`/opt/eurooffice`. It depends on `eurooffice=9.3.8-5`; the bundled
self-contained `wizp` package remains available as a fallback.

## Build the CEF 109 package tree

Build this on Linux with Bun, Zig, and the WIZP build dependencies available.
`WIZP_SOURCE_DIR` must be a clean WIZP checkout. EuroOffice 9.3.8-5 must be
installed or extracted under `/opt/eurooffice` (override with
`EUROOFFICE_ROOT`). Set an empty output directory:

```bash
WIZP_SOURCE_DIR=/path/to/WIZP \
WIZP_LEAN_OUTPUT_DIR=/tmp/wizp-lean-package \
  distro/packages/wizp-lean/build.sh
```

The build pins Electrobun v1.18.1 commit
`4eba723c85b97559e1d9e13439d9a92ede0832e8`, applies
`electrobun-cef109.patch`, rebuilds its Linux native wrapper/helper against
CEF 109, builds WIZP self-contained, overlays EuroOffice's CEF payload, checks
byte equality, and runs WIZP's package audits. The generated manifest records
the source commit, patch digest, CEF/Chromium versions, and EuroOffice package
release. `WIZP_LEAN_WORKDIR` can preserve a caller-provided empty work directory
for diagnosis; otherwise temporary build files are removed on exit.

Build the Arch package with the exact generated tree:

```bash
cd distro/packages/wizp-lean
WIZP_PACKAGE_DIR=/tmp/wizp-lean-package makepkg --clean --nodeps --nocheck --noconfirm
```

`wizp-lean` conflicts with and provides `wizp`. The DINX ISO profile selects
`wizp-lean` by default and stages the pinned WIZP source archive during the ISO
build. The original `distro/packages/wizp` remains available as the bundled-CEF
fallback, but both packages must not be installed together.

The ISO build validates package provenance, the EuroOffice CEF payload hashes,
and the symlinked runtime layout. CEF 109 is substantially older than WIZP's
standard CEF 147 and is end-of-life; use the bundled fallback for untrusted
internet browsing.

## Runtime contract and measured impact

EuroOffice 9.3.8-5 supplies CEF 109.1.18+gf1c41e4 / Chromium 109.0.5414.120.
WIZP's Electrobun wrapper/process helper is rebuilt against this exact CEF
major; package validation pins the EuroOffice `libcef.so` SHA-256 and checks
the patch/source provenance. The lean package symlinks shared CEF binaries,
resources, SwiftShader manifest, and locales to `/opt/eurooffice`.

EuroOffice payload hashes recorded during the byte comparison:

| File | SHA-256 |
| --- | --- |
| `libcef.so` | `b86edf848d4c18c70d76eba7bcce766d2f5d735ac56effeb11fcf4ee47771689` |
| `resources.pak` | `0c22a7412231d3cfda1663e9a1815a2d1f9f311322946669a3e2240010cc2e7d` |
| `icudtl.dat` | `97b978a19edd4746e9a44d9a44bb4bc519e127a203c247837ec0922f573449e3` |
| `v8_context_snapshot.bin` | `474eccca3a12af4f6a37409b02dd9e8004f6675b519581d26900f759d9244a6a` |
| `snapshot_blob.bin` | `76a8cd79ae104dc59a3390cc852c8a8b6bb057ee38dcc40903ea427475740d56` |


Measured on the EuroOffice + WIZP pair-tree using the DINX SquashFS xz/1 MiB/
x86-BCJ options: default duplicate removal produced 354.58 MiB, while
`-no-duplicates` produced 439.13 MiB, a 84.54 MiB pair-tree difference. This is
not a whole-ISO measurement and includes any duplicate files in either app;
do not claim the full difference as CEF-only savings.
