#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_env="$repo_root/distro/packages/deetty/source.env"
pkgbuild="$repo_root/distro/packages/deetty/PKGBUILD"
profile="$repo_root/distro/iso/iso-profiles/dinx/profile.yaml"
workflow="$repo_root/.github/workflows/p0-iso.yml"
builder="$repo_root/scripts/build-iso-container.sh"

fail() {
  printf 'check_first_party_apps: %s\n' "$*" >&2
  exit 1
}

[[ -r "$source_env" ]] || fail "missing $source_env"
[[ -r "$pkgbuild" ]] || fail "missing $pkgbuild"
[[ -r "$profile" ]] || fail "missing $profile"
[[ -r "$workflow" ]] || fail "missing $workflow"

read_value() {
  local key=$1
  sed -n "s/^${key}=//p" "$source_env" | head -n 1
}

repository=$(read_value DEETTY_REPOSITORY)
ref=$(read_value DEETTY_REF)
version=$(read_value DEETTY_VERSION)
source_sha=$(read_value DEETTY_SOURCE_SHA256)
[[ "$repository" == https://github.com/rufl/NOCTTY.git ]] || fail "unexpected repository: $repository"
[[ "$ref" =~ ^[0-9a-f]{40}$ ]] || fail "invalid source ref: $ref"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "invalid version: $version"
[[ "$source_sha" =~ ^[0-9a-f]{64}$ ]] || fail "invalid source sha256: $source_sha"
command -v sha256sum >/dev/null 2>&1 || fail 'sha256sum is required'
command -v tar >/dev/null 2>&1 || fail 'tar is required'

archive="$repo_root/distro/packages/deetty/noctty-$version.tar.gz"
[[ -r "$archive" ]] || fail "missing source archive: $archive"
actual_sha=$(sha256sum "$archive" | awk '{print $1}')
[[ "$actual_sha" == "$source_sha" ]] ||
  fail "source archive sha256 mismatch expected=$source_sha actual=$actual_sha"
tar -tzf "$archive" | grep -F 'noctty-'"$version"'/build.zig' >/dev/null ||
  fail 'source archive does not contain build.zig'
tar -tzf "$archive" | grep -F 'noctty-'"$version"'/src/main.zig' >/dev/null ||
  fail 'source archive does not contain src/main.zig'
for qualification_script in \
  nocted_core_stability_qualification.sh \
  nocted_core_endurance_qualification.sh \
  nocted_project_index_qualification.sh \
  nocted_worker_qualification.sh \
  nocted_state_recovery_qualification.sh \
  nocted_task_smoke.sh \
  nocted_lsp_smoke.sh \
  nocted_native_smoke.sh \
  require_isolated_display.sh; do
  tar -tzf "$archive" |
    grep -Fx "noctty-$version/scripts/$qualification_script" >/dev/null ||
    fail "source archive is missing qualification script: $qualification_script"
done

grep -Fqx 'pkgname=deetty' "$pkgbuild" || fail 'PKGBUILD package name is not deetty'
grep -Fq "provides=('dintor' 'terminal-emulator')" "$pkgbuild" || fail 'PKGBUILD does not provide Dintor'
grep -Fq "'gtksourceview4'" "$pkgbuild" || fail 'Dintor runtime dependency is missing'
grep -Fq '  - deetty' "$profile" || fail 'DINX profile does not install Deetty'
grep -Fq 'run: ./scripts/check_first_party_apps.sh' "$workflow" || fail 'P0 workflow does not run the Deetty source and package contract'
grep -Fq 'source /workspace/distro/packages/deetty/source.env' "$builder" || fail 'P0 builder does not load the pinned Deetty source before asset extraction'
grep -Fq 'build-metadata.txt' "$builder" || fail 'P0 builder does not emit build metadata'

printf 'first_party_apps_contract repository=%s ref=%s version=%s deetty=true dintor=true upstream_source_pinned=true archive_verified=true profile_entry=true\n' \
  "$repository" "$ref" "$version"
