#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'usage: %s RELEASE_BASE_URL PACKAGE_VERSION ISO_URL ISO_SHA512 BUILD_ID [OUTPUT_DIR]\n' "$0" >&2
  exit 2
}

[[ $# -ge 5 && $# -le 6 ]] || usage
release_base_url=$1
package_version=$2
iso_url=$3
iso_sha512=$4
build_id=$5
output_dir=${6:-dist/release}

[[ "$release_base_url" =~ ^https://[^/]+/[^/]+/[^/]+/releases/download/[^/]+$ ]] || {
  printf 'package-windows-qemu: invalid release base URL\n' >&2
  exit 1
}
[[ "$iso_url" =~ ^https:// ]] || {
  printf 'package-windows-qemu: ISO URL must use HTTPS\n' >&2
  exit 1
}
[[ "$iso_sha512" =~ ^[0-9a-fA-F]{128}$ ]] || {
  printf 'package-windows-qemu: ISO SHA-512 must contain 128 hexadecimal characters\n' >&2
  exit 1
}
[[ "$build_id" =~ ^[A-Za-z0-9._-]+$ ]] || {
  printf 'package-windows-qemu: BUILD_ID contains unsupported characters\n' >&2
  exit 1
}
[[ "$package_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[A-Za-z0-9._-]+$ ]] || {
  printf 'package-windows-qemu: PACKAGE_VERSION must be a release-like version\n' >&2
  exit 1
}

zig_bin=${ZIG:-zig}
command -v "$zig_bin" >/dev/null 2>&1 || {
  printf 'package-windows-qemu: zig is required to build the Windows launcher\n' >&2
  exit 1
}
command -v zip >/dev/null 2>&1 || {
  printf 'package-windows-qemu: zip is required\n' >&2
  exit 1
}
command -v sha256sum >/dev/null 2>&1 || {
  printf 'package-windows-qemu: sha256sum is required\n' >&2
  exit 1
}

archive_name="dinx-${package_version}-windows-x86_64.zip"
metadata_name="dinx-${package_version}-windows-x86_64.json"
manifest_name="dinx-${package_version}-deployment-manifest.json"
root_name="dinx-${package_version}-windows-x86_64"
release_url="${release_base_url}/${archive_name}"
mkdir -p "$output_dir"
output_dir=$(cd "$output_dir" && pwd -P)
stage_parent=$(mktemp -d)
trap 'rm -rf "$stage_parent"' EXIT
stage_root="$stage_parent/$root_name"
mkdir -p "$stage_root/evidence"

"$zig_bin" cc \
  -target x86_64-windows-gnu \
  -O2 \
  -s \
  -o "$stage_root/dinx.exe" \
  tools/dinx-qemu-launcher.c
cp scripts/smoke-iso.ps1 "$stage_root/dinx-visual-test.ps1"
cp LICENSE "$stage_root/LICENSE"
printf '%s\n' "$iso_sha512  dinx-${package_version}.iso" > "$stage_root/dinx-iso.sha512"
printf '{\n  "application": "dinx",\n  "build_id": "%s",\n  "file": "dinx-%s.iso",\n  "sha512": "%s",\n  "url": "%s"\n}\n' \
  "$build_id" "$package_version" "$iso_sha512" "$iso_url" > "$stage_root/dinx-iso.json"
printf '%s\n' \
  '# DINX Windows QEMU launch package' \
  '' \
  'This package launches the DINX live validation ISO in QEMU on Windows.' \
  '' \
  'Requirements:' \
  '- Windows x86_64;' \
  '- QEMU System x86_64 (`qemu-system-x86_64.exe`) on PATH, or DINX_QEMU set to its full path;' \
  '- a Windows desktop session for the visual mode.' \
  '' \
  'Commands:' \
  '- `dinx.exe` or `dinx.exe --visual-test`: download and verify the pinned ISO, boot QEMU, capture the greeter and post-input PPM frames, then stop QEMU;' \
  '- `dinx.exe --package-smoke`: run the bounded headless QEMU smoke used by deployment qualification;' \
  '- `dinx.exe --help`: print the launcher contract.' \
  '' \
  'The ISO URL and SHA-512 are immutable release metadata in `dinx-iso.json`. The disposable DINX live-session account is documented in the release notes and must not be reused.' \
  > "$stage_root/README.txt"

archive_path="$output_dir/$archive_name"
rm -f "$archive_path"
(
  cd "$stage_parent"
  zip -q -r "$archive_path" "$root_name"
)
archive_size=$(wc -c < "$archive_path")
archive_sha256=$(sha256sum "$archive_path" | cut -d ' ' -f 1)
printf '%s  %s\n' "$archive_sha256" "$archive_name" > "$output_dir/SHA256SUMS"
printf '{\n  "application": "dinx",\n  "archive": "%s",\n  "build_id": "%s",\n  "channel": "dogfood",\n  "manifest_url": "%s/%s",\n  "proof": "unavailable",\n  "schema": "zeer.package-provenance/v1",\n  "sha256": "%s",\n  "signing": "unavailable",\n  "size": %s,\n  "target": "windows-x86_64",\n  "url": "%s",\n  "version": "%s"\n}\n' \
  "$archive_name" "$build_id" "$release_base_url" "$metadata_name" \
  "$archive_sha256" "$archive_size" "$release_url" "$package_version" > "$output_dir/$metadata_name"
printf '{\n  "application": "dinx",\n  "build_id": "%s",\n  "channel": "dogfood",\n  "schema": "zeer.ztash-dogfood/v1",\n  "targets": [\n    {\n      "agent": "ddjarin",\n      "archive": "%s",\n      "metadata": "%s",\n      "package": "packages/%s",\n      "sha256": "%s",\n      "size": %s,\n      "target": "windows-x86_64"\n    }\n  ],\n  "version": "%s"\n}\n' \
  "$build_id" "$archive_name" "$metadata_name" "$archive_name" \
  "$archive_sha256" "$archive_size" "$package_version" > "$output_dir/$manifest_name"
printf 'package-windows-qemu: %s (%s bytes, SHA-256 %s)\n' "$archive_path" "$archive_size" "$archive_sha256"
printf 'package-windows-qemu: metadata %s\n' "$output_dir/$metadata_name"
printf 'package-windows-qemu: manifest %s\n' "$output_dir/$manifest_name"
