#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_env="$repo_root/distro/packages/deetty/source.env"
pkgbuild="$repo_root/distro/packages/deetty/PKGBUILD"
repository=$(awk -F= '$1 == "DEETTY_REPOSITORY" { print $2; exit }' "$source_env")
version=$(awk -F= '$1 == "DEETTY_VERSION" { print $2; exit }' "$source_env")
current_ref=$(awk -F= '$1 == "DEETTY_REF" { print $2; exit }' "$source_env")
current_sha=$(awk -F= '$1 == "DEETTY_SOURCE_SHA256" { print $2; exit }' "$source_env")

[[ "$repository" == "https://github.com/rufl/DEETTY.git" ]] || {
  printf 'refresh_deetty_source: unexpected repository: %s\n' "$repository" >&2
  exit 1
}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  printf 'refresh_deetty_source: invalid DEETTY_VERSION: %s\n' "$version" >&2
  exit 1
}
new_ref=$(git ls-remote "$repository" HEAD | awk 'NR == 1 { print $1; exit }')
[[ "$new_ref" =~ ^[0-9a-f]{40}$ ]] || {
  printf 'refresh_deetty_source: could not resolve upstream HEAD\n' >&2
  exit 1
}
if [[ "$new_ref" == "$current_ref" ]]; then
  printf 'deetty_source_refresh changed=false ref=%s dintor_included=true\n' "$current_ref"
  exit 0
fi

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/dinx-deetty-refresh.XXXXXX")
cleanup() { rm -rf -- "$tmp_dir"; }
trap cleanup EXIT HUP INT TERM

git init --quiet "$tmp_dir/repo"
git -C "$tmp_dir/repo" remote add origin "$repository"
git -C "$tmp_dir/repo" fetch --quiet --depth=1 origin "$new_ref"
git -C "$tmp_dir/repo" archive --format=tar --prefix="deetty-$version/" FETCH_HEAD |
  gzip -n > "$tmp_dir/deetty-$version.tar.gz"
new_sha=$(sha256sum "$tmp_dir/deetty-$version.tar.gz" | awk '{ print $1 }')
[[ "$new_sha" =~ ^[0-9a-f]{64}$ ]] || {
  printf 'refresh_deetty_source: invalid generated checksum\n' >&2
  exit 1
}

python3 - "$source_env" "$pkgbuild" "$new_ref" "$new_sha" <<'PY'
from pathlib import Path
import re
import sys

source_path = Path(sys.argv[1])
pkgbuild_path = Path(sys.argv[2])
ref = sys.argv[3]
sha = sys.argv[4]

source = source_path.read_text(encoding="utf-8")
source, ref_count = re.subn(r"^DEETTY_REF=.*$", f"DEETTY_REF={ref}", source, count=1, flags=re.MULTILINE)
source, sha_count = re.subn(r"^DEETTY_SOURCE_SHA256=.*$", f"DEETTY_SOURCE_SHA256={sha}", source, count=1, flags=re.MULTILINE)
if ref_count != 1 or sha_count != 1:
    raise SystemExit("refresh_deetty_source: source.env keys are not unique")
source_path.write_text(source, encoding="utf-8")

pkgbuild = pkgbuild_path.read_text(encoding="utf-8")
def bump(match: re.Match[str]) -> str:
    return f"pkgrel={int(match.group(1)) + 1}"
pkgbuild, pkgrel_count = re.subn(r"^pkgrel=(\d+)$", bump, pkgbuild, count=1, flags=re.MULTILINE)
if pkgrel_count != 1:
    raise SystemExit("refresh_deetty_source: PKGBUILD pkgrel is missing or ambiguous")
pkgbuild_path.write_text(pkgbuild, encoding="utf-8")
PY

printf 'deetty_source_refresh changed=true old_ref=%s new_ref=%s version=%s sha256=%s dintor_included=true\n' \
  "$current_ref" "$new_ref" "$version" "$new_sha"
