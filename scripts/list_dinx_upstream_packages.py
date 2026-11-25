#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""List every upstream pacman package needed by the DINX builder and ISO."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROFILE = ROOT / "distro/iso/iso-profiles/dinx/profile.yaml"
BUILDER_PACKAGES = ROOT / "scripts/iso-builder/packages.txt"
PACKAGE_DIR = ROOT / "distro/packages"
PIN_SUFFIX_RE = re.compile(r"\.pkg\.tar\.(?:zst|xz|gz)$")
PACKAGE_RE = re.compile(r"^\s*-\s*([A-Za-z0-9][A-Za-z0-9+._@:-]*)\s*$")
KEY_RE = re.compile(r"^(?P<indent>\s*)(?P<key>[A-Za-z0-9_-]+):\s*$")


def profile_packages() -> set[str]:
    packages: set[str] = set()
    stack: list[tuple[int, str]] = []
    for line in PROFILE.read_text(encoding="utf-8").splitlines():
        key_match = KEY_RE.match(line)
        if key_match:
            indent = len(key_match.group("indent"))
            while stack and indent <= stack[-1][0]:
                stack.pop()
            stack.append((indent, key_match.group("key")))
            continue
        package_match = PACKAGE_RE.match(line)
        if not package_match:
            continue
        path = [key for _, key in stack]
        if path and (path[-1] == "packages" or path[-2:] == ["packages-init", "dinit"]):
            packages.add(package_match.group(1))
    return packages


def builder_packages() -> set[str]:
    return {
        line.strip()
        for line in BUILDER_PACKAGES.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    }


def local_packages() -> set[str]:
    return {
        package_dir.name
        for package_dir in PACKAGE_DIR.iterdir()
        if package_dir.is_dir() and (package_dir / "PKGBUILD").is_file()
    }


def staged_packages() -> set[str]:
    """Package names published as DINX release assets and staged into the image.

    These never resolve from an Artix repository: a `scripts/lib/stage-*.sh`
    helper downloads the pinned artifact and the builder signs it into the
    temporary DINX repository. Listing them as upstream would make the prefetch
    die with `error: target not found`, so they are excluded like local packages.

    A pacman filename is `name-version-pkgrel-arch.pkg.tar.zst`, but both `name`
    and `version` may contain dashes, so the fields cannot be split blindly. The
    pin file declares `version` and `pkgrel` beside `package`, which makes the
    prefix unambiguous: strip the archive suffix, then the pkgrel and version
    fields, and what remains is the package name.
    """
    names: set[str] = set()
    for pin_file in sorted(ROOT.glob("distro/**/*.pin")):
        fields: dict[str, str] = {}
        for line in pin_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            fields[key.strip()] = value.strip()
        package = fields.get("package", "")
        version = fields.get("version", "")
        pkgrel = fields.get("pkgrel", "")
        if not PIN_SUFFIX_RE.search(package) or not version or not pkgrel:
            continue
        # Strip the trailing arch field first, then the declared pkgrel and
        # version; anything left over is the package name.
        base = PIN_SUFFIX_RE.sub("", package)
        base = base.rsplit("-", 1)[0]
        for suffix in (f"-{pkgrel}", f"-{version}"):
            if not base.endswith(suffix):
                base = ""
                break
            base = base[: -len(suffix)]
        if base:
            names.add(base)
    return names


def main() -> None:
    names = (profile_packages() | builder_packages()) - local_packages() - staged_packages()
    for name in sorted(names):
        print(name)


if __name__ == "__main__":
    main()
