#!/usr/bin/env python3
"""Validate that every upstream source pin has a reviewed refresh entry."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / ".github/package-updates.json"
# These pins are intentionally coupled to DINX's private source revision or toolchain.
MANUAL_SOURCE_PINS = {"deetty", "zls"}


def fail(message: str) -> None:
    print(f"package_update_manifest_contract: {message}", file=sys.stderr)
    raise SystemExit(1)


def assignments(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.lstrip().startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if re.fullmatch(r"[A-Z0-9_]+", key):
            if key in values:
                fail(f"duplicate source pin {key} in {path.relative_to(ROOT)}")
            values[key] = value
    return values


def main() -> None:
    try:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"cannot read update manifest: {error}")
    if manifest.get("schema") != "dinx-upstream-package-updates/v1":
        fail("unsupported update manifest schema")
    entries = manifest.get("packages")
    if not isinstance(entries, list) or not entries:
        fail("manifest packages must be a non-empty array")

    source_files = {
        path.parent.name: path
        for path in (ROOT / "distro/packages").glob("*/source.env")
    }
    expected = set(source_files) - MANUAL_SOURCE_PINS
    names: set[str] = set()
    for entry in entries:
        name = entry.get("name")
        if not isinstance(name, str) or name in names:
            fail(f"missing or duplicate package name: {name!r}")
        names.add(name)
        source_path = (ROOT / entry.get("source_file", "")).resolve()
        if source_path not in source_files.values():
            fail(f"{name}: source file is not a tracked package source.env")
        if source_path.parent.name != name:
            fail(f"{name}: source file does not match package directory")
        pins = assignments(source_path)
        for field in ("version_key", "checksum_key"):
            key = entry.get(field)
            if not isinstance(key, str) or key not in pins or not pins[key]:
                fail(f"{name}: {field} does not name an existing source pin")
        package_version_key = entry.get("package_version_key")
        if package_version_key is not None:
            if package_version_key not in pins or pins[package_version_key] != pins[entry["version_key"]]:
                fail(f"{name}: package version pin is missing or differs from source version")
        source_url_key = entry.get("source_url_key")
        if source_url_key is not None and (source_url_key not in pins or not pins[source_url_key]):
            fail(f"{name}: source URL pin is missing")
        tag_prefix = entry.get("tag_prefix", "")
        if not isinstance(tag_prefix, str) or "\n" in tag_prefix or "\r" in tag_prefix:
            fail(f"{name}: invalid release tag prefix")
        additional_sources = entry.get("additional_sources", [])
        if not isinstance(additional_sources, list):
            fail(f"{name}: additional_sources must be an array")
        source_keys = {entry["checksum_key"]}
        if source_url_key is not None:
            source_keys.add(source_url_key)
        for index, source in enumerate(additional_sources):
            if not isinstance(source, dict):
                fail(f"{name}: additional source {index} must be an object")
            for field in ("source_url_key", "checksum_key"):
                key = source.get(field)
                if not isinstance(key, str) or key not in pins or not pins[key]:
                    fail(f"{name}: additional source {index} has an invalid {field}")
                if key in source_keys:
                    fail(f"{name}: duplicate source pin key {key}")
                source_keys.add(key)
            additional_template = source.get("url_template", "")
            if not additional_template.startswith("https://") or "{tag}" not in additional_template:
                fail(f"{name}: additional source {index} URL template is not pinned to an HTTPS release tag")
        if entry.get("provider") not in {"github", "gitlab"}:
            fail(f"{name}: unsupported provider")
        if entry.get("checksum") not in {"sha256", "blake2b"}:
            fail(f"{name}: unsupported checksum algorithm")
        repository = entry.get("repository", "")
        if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
            fail(f"{name}: invalid upstream repository")
        template = entry.get("url_template", "")
        if not template.startswith("https://") or "{tag}" not in template:
            fail(f"{name}: source URL template is not pinned to an HTTPS release tag")
        bump_path = entry.get("bump_pkgrel_path")
        if bump_path is not None and bump_path != f"distro/packages/{name}/PKGBUILD":
            fail(f"{name}: pkgrel bump target is outside its package directory")

    if names != expected:
        missing = ",".join(sorted(expected - names)) or "none"
        unexpected = ",".join(sorted(names - expected)) or "none"
        manual = ",".join(sorted(MANUAL_SOURCE_PINS))
        fail(f"upstream coverage mismatch; missing={missing} unexpected={unexpected} manual={manual}")

    print(
        "package_update_manifest_contract "
        f"upstream_packages={len(names)} manual_source_pins={len(MANUAL_SOURCE_PINS)} "
        "checksums=true https_release_tags=true multi_source=true"
    )


if __name__ == "__main__":
    main()
