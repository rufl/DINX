# WIZP DINX package

This recipe packages the exact WIZP self-contained Linux directory. WIZP keeps
CEF, Bun, the Electrobun launcher, frontend assets, and the vendored Linux
runtime under `/opt/wizp`; `/usr/bin/wizp` is only the stable launcher path.

Build the WIZP package first in the WIZP checkout:

```bash
cd desktop/WIZP/wizp
npm run build:self-contained
```

From the DINX checkout, run `makepkg` in this package directory and point
`WIZP_PACKAGE_DIR` at the WIZP checkout output:

```bash
cd distro/packages/wizp
WIZP_PACKAGE_DIR="/absolute/path/to/desktop/WIZP/wizp/build/dev-linux-x64/WIZP-dev" \
  makepkg --clean --nodeps --nocheck --noconfirm
```

`WIZP_PACKAGE_DIR` is REQUIRED so the DINX package never silently rebuilds a
different frontend, backend, or CEF revision. The recipe validates the
launcher, bundled Bun, CEF, main bundle, frontend, and a 900 MB installed-size
ceiling before packaging.

The desktop entry registers only text-oriented file types that WIZP currently opens through its file-read path. It does not claim binary, image, archive, or arbitrary MIME handling.
