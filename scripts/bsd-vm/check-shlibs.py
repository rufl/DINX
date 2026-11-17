#!/usr/bin/env python3
"""Audit shlibs_required of the local repo packages and resolve each one to the
package that provides it, so the ISO firstboot install list is complete and the
installed system never fails `pkg add` with "Missing shlib".

Run inside the FreeBSD build VM as root:
    python3 check-shlibs.py [repo_dir] [--all]

Notes:
- `pkg shlib -P <lib>` takes a LIBRARY name and prints its provider package.
- libc/libm/libthr and friends are base libraries with no owning package, so
  they are reported separately instead of as missing.
- Packages excluded from the ISO (dinx-weston) are skipped unless --all.
"""
import glob
import json
import os
import subprocess
import sys

BASE_LIBS = {
    "libc.so.7", "libm.so.5", "libthr.so.3", "libdl.so.1", "librt.so.1",
    "libcrypt.so.5", "libcrypto.so.35", "libssl.so.35", "libutil.so.10",
    "libedit.so.8", "libhistory.so.8", "libncursesw.so.9", "libtinfow.so.9",
    "libelf.so.2", "libkvm.so.7", "libmd.so.7", "libprocstat.so.1",
    "libexecinfo.so.1", "libz.so.6", "libbz2.so.4", "liblzma.so.5",
    "libgcc_s.so.1", "libc++.so.1", "libcxxrt.so.1", "libpam.so.6",
    "libgssapi_krb5.so.122", "libkrb5.so.122",
}
# Not shipped in the ISO: weston segfaults launching Xwayland on FreeBSD.
SKIP_PKGS = ("dinx-weston",)


def manifest(path):
    out = subprocess.run(["tar", "-xOf", path, "+MANIFEST"],
                         capture_output=True).stdout
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return None


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    include_all = "--all" in sys.argv
    repo = args[0] if args else "/root/build/repo"

    required = {}
    provided_by_repo = {}
    for path in sorted(glob.glob(os.path.join(repo, "dinx-*.pkg"))):
        name = os.path.basename(path)
        if not include_all and any(name.startswith(s) for s in SKIP_PKGS):
            continue
        man = manifest(path)
        if man is None:
            print("skip (unparsable manifest):", name)
            continue
        required[name] = set(man.get("shlibs_required", []))
        for lib in man.get("shlibs_provided", []):
            provided_by_repo.setdefault(lib, name)

    all_req = set()
    for libs in required.values():
        all_req |= libs

    have = dict(provided_by_repo)
    for lib in sorted(all_req):
        if lib in have or lib in BASE_LIBS:
            continue
        # `pkg shlib -P lib` prints:
        #   libfoo.so.1 is provided by packages:
        #           libfoo-1.2.3
        prov = subprocess.run(["pkg", "shlib", "-P", lib],
                              capture_output=True, text=True).stdout
        for line in prov.splitlines():
            tok = line.strip()
            if not tok or "provided by" in tok or tok == lib:
                continue
            have[lib] = tok
            break

    base = sorted(l for l in all_req if l in BASE_LIBS)
    missing = sorted(l for l in all_req if l not in have and l not in BASE_LIBS)

    print("packages audited:", len(required))
    print("distinct shlibs_required:", len(all_req))
    print("base libraries (no owning package):", len(base))
    print("resolved:", len([l for l in all_req if l in have]))
    print("MISSING:", len(missing))
    print()
    for lib in missing:
        users = ", ".join(n for n, libs in sorted(required.items()) if lib in libs)
        print("  MISSING %-32s %s" % (lib, users))
    print()
    print("# pkg install list for firstboot (providers of required shlibs):")
    def strip_version(pkg):
        # "gtk4-4.20.4_1" -> "gtk4"; "libxml2-2.11.9" -> "libxml2"
        return pkg.rsplit("-", 1)[0] if "-" in pkg else pkg

    providers = sorted({strip_version(p) for lib, p in have.items()
                        if p not in required
                        and p not in provided_by_repo.values()})
    print(" ".join(providers))
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
