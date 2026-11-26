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
## CEF sharing with EuroOffice

WIZP 1.18.1 uses CEF 147.0.10 / Chromium 147.0.7727.118. EuroOffice 9.3.8
uses CEF 109.1.18 / Chromium 109.0.5414.120. These are different CEF major
versions; Electrobun 1.18.1 documents its native CEF wrapper/process helper as
version-pinned and only expects CEF C API compatibility within the same major.

Do not replace `/opt/wizp/bin/cef/libcef.so` or its resources with EuroOffice's
CEF runtime. WIZP remains self-contained and keeps its own CEF. A scratch build
against upstream CEF 109 launched the Electrobun wrapper but Bun crashed with
a segmentation fault before the app became ready; the isolated UI test timed
out. This is not a successful compatibility test. The EuroOffice `libcef.so`
also differs byte-for-byte from upstream CEF 109 after stripping, so matching
the version alone would not guarantee SquashFS deduplication.

Sharing requires rebuilding Electrobun's native wrapper and process helper
against the exact EuroOffice CEF build, then passing packaged editor/runtime
smokes. CEF 109 is also substantially older and carries a security-update risk.
No ISO size savings are claimed.

The desktop entry registers only text-oriented file types that WIZP currently opens through its file-read path. It does not claim binary, image, archive, or arbitrary MIME handling.
