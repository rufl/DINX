# EuroOffice consumer kit (for main)

These files are authored on the `office` branch but are meant to be
**cherry-picked onto `main`** — do not merge the office branch itself.

## Install on main

1. Copy `check_eurooffice_release.sh` → `scripts/check_eurooffice_release.sh`
   (keep the executable bit).
2. Copy `eurooffice-refresh.yml` → `.github/workflows/eurooffice-refresh.yml`.
3. Add the builder integration below.

The refresh workflow runs every 3 days (`41 5 */3 * *`, adjustable) and on
manual dispatch. Each run:

1. Dispatches `eurooffice.yml` on the `office` branch. That pipeline detects
   new upstream Euro-Office releases and publishes lean
   `eurooffice/v<ver>-dinx<N>` GitHub releases (no-op when already packed).
2. Compares the newest published `eurooffice/v*` release against
   `distro/office/eurooffice.pin`. When newer: downloads the artifacts,
   verifies `SHA256SUMS`, stages them under `dist/office/eurooffice/`, updates
   the pin, commits the pin to main, and dispatches `p0-iso.yml`.

GitHub schedule triggers only fire on the default branch — this is why the
periodic trigger must live on main while the build pipeline stays on office.

## Builder integration (build-iso-container.sh)

The staged artifacts are referenced by the pin file:

```
tag=eurooffice/v9.3.8-dinx1
version=9.3.8
pkgrel=1
package=eurooffice-9.3.8-1-x86_64.pkg.tar.zst
squashfs=eurooffice-9.3.8-x86_64.squashfs
```

- **pacman path (install + rootfs)**: copy the staged `.pkg.tar.zst` into the
  temporary DINX package repository before `repo-add` runs, and add
  `eurooffice` to `distro/iso/iso-profiles/dinx/profile.yaml` (rootfs
  packages) and `feature-groups.json` (desktop group). pacman resolves the
  declared dependencies; add any missing ones (notably `ttf-carlito`,
  `gst-libav`, `gst-plugins-ugly`) to the profile inputs.
- **live path**: the squashfs is the same tree rooted at `/`. Either merge it
  into the rootfs before final `mksquashfs` (recommended; keeps live/install
  parity) or ship it as a separate live module loop-mounted over `/`.
- Verify `SHA256SUMS` at staging time (the consumer script already does) and
  record the release tag + checksums in `build-metadata.txt`.

## Gate updates on main

- `scripts/check-iso-content.sh`: add `eurooffice` to the required desktop
  apps; expected paths `opt/eurooffice/DesktopEditors`, `usr/bin/eurooffice`,
  `usr/share/applications/eurooffice.desktop`; desktop-exec row
  `usr/share/applications/eurooffice.desktop|EuroOffice|EuroOffice|eurooffice %U`;
  MIME defaults for docx/xlsx/pptx/pdf → `eurooffice.desktop`. The retired
  `onlyoffice` metadata check stays (different pkgname).
- `scripts/check_desktop_packages.sh`: replace the PdfCraft PDF-default
  assertion with EuroOffice once bundled.
- Remove the craft apps (wordcraft/gridcraft/deckcraft/pdfcraft) per the
  user decision communicated to the MAIN agent.
- Budget: `check_dinx_budget.sh` ceilings unchanged (3 GiB ISO, 128 rootfs
  packages). Expect ≈ +400–500 MiB ISO for EuroOffice after craft removal
  (estimate until the first P0 measurement).

## Local manual check

```bash
EUROFFICE_SKIP_DISPATCH=1 scripts/check_eurooffice_release.sh
```