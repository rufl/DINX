# EuroOffice lean package (office branch)

This directory is the **office-only** work area of the DINX repository. The
`office` branch carries EuroOffice packaging work and nothing else; do not
merge it into `main`. Main consumes the published releases through the
consumer kit in `consumer/` at the repository root.

## What this produces

Euro-Office DesktopEditors is an ONLYOFFICE fork (AGPL-3.0) whose desktop
editors embed CEF. Upstream ships a ~314 MiB amd64 deb with an installed size
of ~1.37 GiB. This pipeline imports that deb and emits two lean artifacts:

| Artifact | Purpose |
| --- | --- |
| `eurooffice-<ver>-<pkgrel>-x86_64.pkg.tar.zst` | pacman package for installed systems and ISO rootfs |
| `eurooffice-<ver>-x86_64.squashfs` | xz / 1 MiB blocks / x86 BCJ image of the full install tree rooted at `/`, for live use |

plus `SHA256SUMS` and `build-metadata.json` (upstream tag, deb sha256, debloat
manifest, sizes, pipeline digest).

## Debloat policy (measured on v9.3.8)

- Dictionaries: 42 languages, 239 MiB → keep `en_US en_GB pt_BR` (21.5 MiB).
- CEF locales: 55 `.pak` files, 29 MiB → keep `en-US en-GB pt-BR`.
- Regenerable sdkjs V8 code caches (`*.cache`) removed.
- All ELF objects stripped (`strip --strip-unneeded`).
- **Kept intact**: converter (x2t), sdkjs editors, web-apps UI, the private
  Qt 6.10.1 / ICU (73+74) / ffmpeg bundles (version-pinned, not shareable with
  system copies), fonts, Visio support.

Result: ~1.37 GiB → ~1.1 GiB installed. Override keeps via
`EUROFFICE_KEEP_DICTS` / `EUROFFICE_KEEP_LOCALES`.

## Layout

Reorganized from upstream `/opt/euro-office/euro-office` to:

- `/opt/eurooffice/` — application tree (DesktopEditors, libcef.so, editors, …)
- `/usr/bin/eurooffice` — launcher (execs the real binary, no AppImage extraction)
- `/usr/share/applications/eurooffice.desktop` — DINX desktop identity + MIME
- `/usr/share/licenses/eurooffice/` — AGPL-3.0 text + upstream notice
- `/usr/share/doc/eurooffice/SOURCE` — provenance + debloat manifest

## Running the pipeline

```bash
# latest upstream release, artifacts into dist/office/eurooffice
distro/office/eurooffice/build.sh

# pinned version / local deb / custom keeps
EUROFFICE_VERSION=9.3.8 EUROFFICE_DEB=/path/upstream.deb \
EUROFFICE_KEEP_DICTS="en_US pt_BR" distro/office/eurooffice/build.sh

# detection only (compares upstream latest vs published eurooffice/v* releases)
distro/office/eurooffice/detect-release.sh
```

Requires: curl, jq, ar, tar (xz+zstd), binutils strip, squashfs-tools,
sha256sum; `pacman` is used for an extra metadata check when present. Runs
unprivileged.

## Release contract

The office-branch workflow `.github/workflows/eurooffice.yml`
(workflow_dispatch only) publishes GitHub releases tagged
`eurooffice/v<upstream>-dinx<pkgrel>` with the four artifacts above.
`pkgrel` bumps when the same upstream version is repacked with pipeline
changes (`force` input).

**GitHub cron only fires on the default branch**, so the periodic trigger
lives on main: `consumer/eurooffice-refresh.yml` (every 3 days) dispatches
this workflow with `--ref office`, then consumes any newer published release.

## Consumption (main side)

See `consumer/README.md`. Summary:

- **Install/rootfs**: add the `.pkg.tar.zst` to the temporary DINX pacman
  repository in `build-iso-container.sh` and add `eurooffice` to
  `profile.yaml` + `feature-groups.json`. Dependencies are declared in
  `.PKGINFO` (gtk3, nss, libxss, libxtst, alsa-lib, libpulse, libnotify,
  xdg-utils, fontconfig, libxkbcommon-x11, xcb-util-cursor, libglvnd,
  ttf-liberation, ttf-dejavu, ttf-carlito, gstreamer, gst-libav,
  gst-plugins-ugly).
- **Live**: merge the squashfs into the rootfs tree before final compression
  (`unsquashfs -d rootfs eurooffice-*.squashfs`), or loop-mount it at `/` in
  the live overlay. Merging keeps live/install parity.
- Always verify `SHA256SUMS` before use; pin the release tag in
  `distro/office/eurooffice.pin`.

## Runtime notes

- CEF is private to EuroOffice. Do not attempt to share it with Blockbench's
  Electron or WIZP's Electrobun CEF — different pinned builds/ABIs.
- BSD branch: CEF has no FreeBSD support; EuroOffice is Linux-only.