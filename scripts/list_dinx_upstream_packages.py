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


def main() -> None:
    names = (profile_packages() | builder_packages()) - local_packages()
    for name in sorted(names):
        print(name)


if __name__ == "__main__":
    main()
