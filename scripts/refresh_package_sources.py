#!/usr/bin/env python3
"""Prepare reviewed source-pin updates from upstream releases."""

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

VERSION_RE = re.compile(r"^[0-9]+(?:\.[0-9]+)*(?:-(?:alpha|beta|rc)\.[0-9]+)?$")
MAX_SOURCE_BYTES = 1024 * 1024 * 1024
USER_AGENT = "DINX-upstream-package-refresh/1"


def fail(message: str) -> None:
    raise ValueError(message)


def version_tuple(value: str) -> tuple[tuple[int, ...], int, int]:
    match = VERSION_RE.fullmatch(value)
    if not match:
        fail(f"unsupported release version: {value}")
    version, separator, prerelease = value.partition("-")
    components = tuple(int(component) for component in version.split("."))
    components += (0,) * max(0, 3 - len(components))
    if not separator:
        return components, 3, 0
    stage, stage_number = prerelease.split(".", 1)
    stage_rank = {"alpha": 0, "beta": 1, "rc": 2}[stage]
    return components, stage_rank, int(stage_number)


def source_version(tag: str, tag_prefix: str = "") -> str:
    if tag_prefix:
        if not tag.startswith(tag_prefix):
            fail(f"unsupported release tag: {tag}")
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


def read_body(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8")


def latest_tag(
    entry: dict,
    token: str,
    get_json: Callable[[str, str], dict],
    get_body: Callable[[str], str] = read_body,
) -> str:
    provider = entry["provider"]
    repository = entry["repository"]
    if provider == "github":
        endpoint = f"https://api.github.com/repos/{repository}/releases/latest"
    elif provider == "gitlab":
        project = urllib.parse.quote(repository, safe="")
        endpoint = f"https://gitlab.gnome.org/api/v4/projects/{project}/releases/permalink/latest"
    elif provider == "zrythm":
        endpoint = "https://www.zrythm.org/en/download-v2-alpha.html"
        try:
            page = get_body(endpoint)
        except urllib.error.HTTPError as error:
            fail(f"{entry['name']}: upstream release lookup returned HTTP {error.code}: {endpoint}")
        match = re.search(r"\bVersion:\s*v?([0-9]+(?:\.[0-9]+)*-(?:alpha|beta|rc)\.[0-9]+)", page)
        if not match:
            fail(f"{entry['name']}: official download page has no supported version: {endpoint}")
        tag = f"v{match.group(1)}"
        source_version(tag)
        return tag
    elif provider == "kde":
        project = repository.rsplit("/", 1)[-1]
        endpoint = f"https://download.kde.org/stable/{project}/"
        try:
            page = get_body(endpoint)
        except urllib.error.HTTPError as error:
            fail(f"{entry['name']}: upstream release lookup returned HTTP {error.code}: {endpoint}")
        versions = re.findall(r"""href=["']([0-9]+(?:\.[0-9]+)*)/["']""", page)
        if not versions:
            fail(f"{entry['name']}: KDE stable directory has no supported release versions: {endpoint}")
        return max(versions, key=version_tuple)
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


def manifest_artifact(
    source: dict,
    get_json: Callable[[str, str], dict],
    cache: dict[str, dict],
) -> tuple[str, str]:
    manifest_url = source.get("manifest_url", "")
    artifact_name = source.get("artifact_name", "")
    if not isinstance(manifest_url, str) or not manifest_url.startswith("https://"):
        fail("manifest source URL must use HTTPS")
    if not isinstance(artifact_name, str) or not re.fullmatch(r"[A-Za-z0-9_.-]+", artifact_name):
        fail("manifest artifact name is invalid")
    if manifest_url not in cache:
        try:
            # Never send the GitHub API token to an upstream artifact host.
            cache[manifest_url] = get_json(manifest_url, "")
        except urllib.error.HTTPError as error:
            fail(f"artifact manifest lookup returned HTTP {error.code}: {manifest_url}")
    manifest = cache[manifest_url]
    if not isinstance(manifest, dict):
        fail(f"artifact manifest is not a JSON object: {manifest_url}")
    artifacts = manifest.get("Artifacts")
    if not isinstance(artifacts, list):
        fail(f"artifact manifest has no Artifacts array: {manifest_url}")
    matches = [item for item in artifacts if isinstance(item, dict) and item.get("Filename") == artifact_name]
    if len(matches) != 1:
        fail(f"artifact manifest must contain exactly one {artifact_name}: {manifest_url}")
    artifact = matches[0]
    urls = artifact.get("URLs")
    if not isinstance(urls, list) or not urls or not isinstance(urls[0], str):
        fail(f"artifact manifest has no download URL for {artifact_name}")
    url = urls[0]
    parsed_url = urllib.parse.urlsplit(url)
    if parsed_url.scheme != "https" or not parsed_url.netloc or parsed_url.username is not None:
        fail(f"artifact manifest has an invalid HTTPS URL for {artifact_name}")
    checksum = artifact.get("SHA256")
    if not isinstance(checksum, str) or not re.fullmatch(r"[0-9a-f]{64}", checksum):
        fail(f"artifact manifest has an invalid SHA256 for {artifact_name}")
    return url, checksum


def plan_updates(
    root: Path,
    manifest: dict,
    token: str = "",
    get_json: Callable[[str, str], dict] = read_text,
    hash_source: Callable[[str, str], str] = digest_url,
    get_body: Callable[[str], str] = read_body,
) -> tuple[dict[Path, str], list[str]]:
    if manifest.get("schema") != "dinx-upstream-package-updates/v1":
        fail("unsupported package update manifest schema")
    entries = manifest.get("packages")
    if not isinstance(entries, list) or not entries:
        fail("package update manifest has no packages")

    release_cache: dict[tuple[str, str], str] = {}
    artifact_manifest_cache: dict[str, dict] = {}
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
            tag = latest_tag(entry, token, get_json, get_body)
            release_cache[release_key] = tag
        tag_prefix = entry.get("tag_prefix", "")
        if not isinstance(tag_prefix, str) or "\n" in tag_prefix or "\r" in tag_prefix:
            fail(f"{name}: invalid release tag prefix")
        version = source_version(tag, tag_prefix)
        source_path = (root / entry["source_file"]).resolve()
        if root.resolve() not in source_path.parents:
            fail(f"{name}: source file escapes the checkout")
        original_source_text = output.get(source_path, source_path.read_text(encoding="utf-8"))
        source_text = original_source_text
        assignments = read_assignments(source_path)
        version_key = entry["version_key"]
        current = assignments.get(version_key)
        if current is None:
            fail(f"{name}: {source_path} has no {version_key}")
        current_version = source_version(current)
        release_is_newer = version_tuple(version) > version_tuple(current_version)

        additional_sources = entry.get("additional_sources", [])
        if not isinstance(additional_sources, list):
            fail(f"{name}: additional_sources must be an array")
        sources = [
            {
                "source_url_key": entry.get("source_url_key"),
                "checksum_key": entry["checksum_key"],
                "url_template": entry["url_template"],
            },
            *additional_sources,
        ]
        last_checksum = ""
        for source in sources:
            if not isinstance(source, dict):
                fail(f"{name}: each source must be an object")
            refresh_always = source.get("refresh_always", False)
            if not isinstance(refresh_always, bool):
                fail(f"{name}: source refresh_always must be boolean")
            if not release_is_newer and not refresh_always:
                continue

            source_url_key = source.get("source_url_key")
            checksum_key = source.get("checksum_key")
            checksum_algorithm = source.get("checksum", entry["checksum"])
            if not isinstance(checksum_key, str):
                fail(f"{name}: source checksum key is invalid")
            if checksum_algorithm not in ("sha256", "blake2b"):
                fail(f"{name}: unsupported source checksum algorithm {checksum_algorithm!r}")
            if source.get("manifest_url"):
                if not refresh_always or checksum_algorithm != "sha256":
                    fail(f"{name}: manifest sources must be always refreshed with SHA256")
                url, advertised_checksum = manifest_artifact(
                    source, get_json, artifact_manifest_cache
                )
            else:
                url_template = source.get("url_template", "")
                if not isinstance(url_template, str):
                    fail(f"{name}: source URL template is invalid")
                url = url_template.format(
                    tag=tag,
                    version=version,
                    version_dash=version.replace(".", "-"),
                )
                advertised_checksum = ""

            pinned_url = assignments.get(source_url_key, "") if source_url_key else ""
            pinned_checksum = assignments.get(checksum_key, "")
            if advertised_checksum and url == pinned_url and advertised_checksum == pinned_checksum:
                checksum = advertised_checksum
            else:
                checksum = hash_source(url, checksum_algorithm)
                if advertised_checksum and checksum != advertised_checksum:
                    fail(f"{name}: artifact manifest SHA256 mismatch for {url}")
            expected_length = 64 if checksum_algorithm in ("sha256", "blake2b") else 0
            if len(checksum) != expected_length or not re.fullmatch(r"[0-9a-f]+", checksum):
                fail(f"{name}: generated checksum has an invalid format")
            if source_url_key:
                source_text = replace_assignment(source_text, source_url_key, url, source_path)
            source_text = replace_assignment(source_text, checksum_key, checksum, source_path)
            last_checksum = checksum

        if release_is_newer:
            source_text = replace_assignment(source_text, version_key, version, source_path)
            if entry.get("package_version_key"):
                source_text = replace_assignment(source_text, entry["package_version_key"], version, source_path)
        if source_text == original_source_text:
            print(
                f"package-source-update package={name} current={current_version} "
                f"latest={version} action=unchanged"
            )
            continue

        output[source_path] = source_text
        rel_path = entry.get("bump_pkgrel_path")
        if rel_path:
            package_path = (root / rel_path).resolve()
            if root.resolve() not in package_path.parents:
                fail(f"{name}: PKGBUILD path escapes the checkout")
            package_text = output.get(package_path, package_path.read_text(encoding="utf-8"))
            output[package_path] = bump_pkgrel(package_text, package_path)

        changed.append(name)
        action = "review-pr" if release_is_newer else "artifact-refresh"
        print(
            f"package-source-update package={name} current={current_version} latest={version} "
            f"checksum={last_checksum} action={action}"
        )

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
