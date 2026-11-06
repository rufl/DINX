#!/usr/bin/env python3
"""Prepare reviewed source-pin updates from upstream stable releases."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Callable

VERSION_RE = re.compile(r"^[0-9]+(?:\.[0-9]+)*$")
MAX_SOURCE_BYTES = 1024 * 1024 * 1024
USER_AGENT = "DINX-upstream-package-refresh/1"


def fail(message: str) -> None:
    raise ValueError(message)


def version_tuple(value: str) -> tuple[int, ...]:
    if not VERSION_RE.fullmatch(value):
        fail(f"unsupported stable release version: {value}")
    return tuple(int(component) for component in value.split("."))


def source_version(tag: str, tag_prefix: str = "") -> str:
    if tag_prefix:
        if not tag.startswith(tag_prefix):
            fail(f"unsupported stable release tag: {tag}")
        value = tag[len(tag_prefix) :]
    else:
        value = tag[1:] if tag.startswith("v") else tag
    version_tuple(value)
    return value


def read_text(url: str, token: str = "") -> dict:
    headers = {"Accept": "application/vnd.github+json", "User-Agent": USER_AGENT}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def latest_tag(entry: dict, token: str, get_json: Callable[[str, str], dict]) -> str:
    provider = entry["provider"]
    repository = entry["repository"]
    if provider == "github":
        endpoint = f"https://api.github.com/repos/{repository}/releases/latest"
    elif provider == "gitlab":
        project = urllib.parse.quote(repository, safe="")
        endpoint = f"https://gitlab.gnome.org/api/v4/projects/{project}/releases/permalink/latest"
    else:
        fail(f"{entry['name']}: unsupported release provider {provider!r}")
    try:
        release = get_json(endpoint, token if provider == "github" else "")
    except urllib.error.HTTPError as error:
        fail(f"{entry['name']}: upstream release lookup returned HTTP {error.code}: {endpoint}")
    tag = release.get("tag_name")
    if not isinstance(tag, str) or not tag:
        fail(f"{entry['name']}: upstream response has no tag_name")
    return tag


def digest_url(url: str, algorithm: str) -> str:
    if algorithm not in ("sha256", "blake2b"):
        fail(f"unsupported source checksum algorithm: {algorithm}")
    digest = hashlib.sha256() if algorithm == "sha256" else hashlib.blake2b()
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    total = 0
    with urllib.request.urlopen(request, timeout=90) as response:
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            total += len(chunk)
            if total > MAX_SOURCE_BYTES:
                fail(f"source archive exceeds the {MAX_SOURCE_BYTES}-byte update limit: {url}")
            digest.update(chunk)
    if total == 0:
        fail(f"upstream source archive is empty: {url}")
    return digest.hexdigest()


def read_assignments(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.lstrip().startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if not re.fullmatch(r"[A-Z0-9_]+", key):
            continue
        if key in values:
            fail(f"{path}: duplicate source pin {key}")
        values[key] = value
    return values


def replace_assignment(text: str, key: str, value: str, path: Path) -> str:
    if not re.fullmatch(r"[A-Z0-9_]+", key) or "\n" in value or "\r" in value:
        fail(f"{path}: invalid generated source pin {key}")
    pattern = re.compile(rf"^{re.escape(key)}=.*$", re.MULTILINE)
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        fail(f"{path}: expected one assignment for {key}, found {len(matches)}")
    return pattern.sub(f"{key}={value}", text, count=1)


def bump_pkgrel(text: str, path: Path) -> str:
    pattern = re.compile(r"^pkgrel=([1-9][0-9]*)$", re.MULTILINE)
    matches = list(pattern.finditer(text))
    if len(matches) != 1:
        fail(f"{path}: expected one numeric pkgrel, found {len(matches)}")
    value = int(matches[0].group(1)) + 1
    return pattern.sub(f"pkgrel={value}", text, count=1)


def plan_updates(
    root: Path,
    manifest: dict,
    token: str = "",
    get_json: Callable[[str, str], dict] = read_text,
    hash_source: Callable[[str, str], str] = digest_url,
) -> tuple[dict[Path, str], list[str]]:
    if manifest.get("schema") != "dinx-upstream-package-updates/v1":
        fail("unsupported package update manifest schema")
    entries = manifest.get("packages")
    if not isinstance(entries, list) or not entries:
        fail("package update manifest has no packages")

    release_cache: dict[tuple[str, str], str] = {}
    output: dict[Path, str] = {}
    changed: list[str] = []
    seen_names: set[str] = set()
    for entry in entries:
        name = entry.get("name", "")
        if not name or name in seen_names:
            fail(f"duplicate or missing package update name: {name!r}")
        seen_names.add(name)
        provider = entry["provider"]
        repository = entry["repository"]
        release_key = (provider, repository)
        tag = release_cache.get(release_key)
        if tag is None:
            tag = latest_tag(entry, token, get_json)
            release_cache[release_key] = tag
        tag_prefix = entry.get("tag_prefix", "")
        if not isinstance(tag_prefix, str) or "\n" in tag_prefix or "\r" in tag_prefix:
            fail(f"{name}: invalid release tag prefix")
        version = source_version(tag, tag_prefix)
        source_path = (root / entry["source_file"]).resolve()
        if root.resolve() not in source_path.parents:
            fail(f"{name}: source file escapes the checkout")
        source_text = output.get(source_path, source_path.read_text(encoding="utf-8"))
        assignments = read_assignments(source_path)
        version_key = entry["version_key"]
        current = assignments.get(version_key)
        if current is None:
            fail(f"{name}: {source_path} has no {version_key}")
        current_version = source_version(current)
        if version_tuple(version) <= version_tuple(current_version):
            print(f"package-source-update package={name} current={current_version} latest={version} action=unchanged")
            continue

        additional_sources = entry.get("additional_sources", [])
        if not isinstance(additional_sources, list):
            fail(f"{name}: additional_sources must be an array")
        sources = [(entry.get("source_url_key"), entry["checksum_key"], entry["url_template"])]
        for source in additional_sources:
            if not isinstance(source, dict):
                fail(f"{name}: each additional source must be an object")
            sources.append((source.get("source_url_key"), source["checksum_key"], source["url_template"]))

        for source_url_key, checksum_key, url_template in sources:
            url = url_template.format(
                tag=tag,
                version=version,
                version_dash=version.replace(".", "-"),
            )
            checksum = hash_source(url, entry["checksum"])
            expected_length = 64 if entry["checksum"] in ("sha256", "blake2b") else 0
            if len(checksum) != expected_length or not re.fullmatch(r"[0-9a-f]+", checksum):
                fail(f"{name}: generated checksum has an invalid format")
            if source_url_key:
                source_text = replace_assignment(source_text, source_url_key, url, source_path)
            source_text = replace_assignment(source_text, checksum_key, checksum, source_path)

        source_text = replace_assignment(source_text, version_key, version, source_path)
        if entry.get("package_version_key"):
            source_text = replace_assignment(source_text, entry["package_version_key"], version, source_path)
        output[source_path] = source_text

        rel_path = entry.get("bump_pkgrel_path")
        if rel_path:
            package_path = (root / rel_path).resolve()
            if root.resolve() not in package_path.parents:
                fail(f"{name}: PKGBUILD path escapes the checkout")
            package_text = output.get(package_path, package_path.read_text(encoding="utf-8"))
            output[package_path] = bump_pkgrel(package_text, package_path)

        changed.append(name)
        print(f"package-source-update package={name} current={current_version} latest={version} checksum={checksum} action=review-pr")

    return output, changed


def write_updates(changes: dict[Path, str], dry_run: bool) -> None:
    if dry_run:
        return
    for path, text in changes.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as temporary:
            temporary.write(text)
            temporary.flush()
            os.fsync(temporary.fileno())
            temp_path = Path(temporary.name)
        temp_path.chmod(path.stat().st_mode & 0o777)
        os.replace(temp_path, path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--manifest", type=Path, default=Path(".github/package-updates.json"))
    parser.add_argument("--dry-run", action="store_true", help="report candidates without modifying source pins")
    args = parser.parse_args()
    root = args.root.resolve()
    manifest_path = args.manifest if args.manifest.is_absolute() else root / args.manifest
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        changes, changed = plan_updates(root, manifest, os.environ.get("GH_TOKEN", os.environ.get("GITHUB_TOKEN", "")))
        write_updates(changes, args.dry_run)
    except (OSError, ValueError, KeyError, json.JSONDecodeError, urllib.error.URLError) as error:
        print(f"refresh_package_sources: {error}", file=sys.stderr)
        return 1
    if changed:
        print(f"package-source-update changed=true packages={','.join(changed)} dry_run={str(args.dry_run).lower()}")
    else:
        print("package-source-update changed=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
