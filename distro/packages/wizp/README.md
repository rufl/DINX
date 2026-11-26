# WIZP DINX package

This recipe packages the exact WIZP self-contained Linux directory. WIZP keeps
CEF, Bun, the Electrobun launcher, frontend assets, and the vendored Linux
runtime under `/opt/wizp`; `/usr/bin/wizp` is only the stable launcher path.

Build WIZP in its checkout, then package its self-contained output:

```bash
cd desktop/WIZP/wizp
npm run build:self-contained

cd distro/packages/wizp
WIZP_PACKAGE_DIR="/absolute/path/to/desktop/WIZP/wizp/build/dev-linux-x64/WIZP-dev" \
  makepkg --clean --nodeps --nocheck --noconfirm
```

`WIZP_PACKAGE_DIR` is required so DINX never silently rebuilds a different
frontend, backend, or CEF revision. The recipe validates the launcher, Bun,
CEF, main bundle, frontend, and a 900 MB installed-size ceiling.

The standard package bundles CEF 147.0.10 / Chromium 147.0.7727.118. For an
experimental CEF 109 build sharing EuroOffice's runtime, see
`../wizp-lean/README.md`. That package has separate compatibility and runtime
limitations; it does not replace this self-contained fallback.

The desktop entry registers only text-oriented file types that WIZP currently opens through its file-read path. It does not claim binary, image, archive, or arbitrary MIME handling.
