#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$repo_root"

fail() {
  printf 'package_provenance_contract: %s\n' "$*" >&2
  exit 1
}

local_packages=(dinitui dinxpanel wizp)
contains_local_package() {
  local candidate=$1
  local package
  for package in "${local_packages[@]}"; do
    [[ "$candidate" == "$package" ]] && return 0
  done
  return 1
}

package_count=0
for pkgbUILD in distro/packages/*/PKGBUILD; do
  [[ -f "$pkgbUILD" ]] || continue
  package_dir=$(dirname "$pkgbUILD")
  package=$(basename "$package_dir")
  package_count=$((package_count + 1))
  grep -Eq '^pkgname=[^[:space:]]+' "$pkgbUILD" || fail "$package is missing pkgname"
  grep -Eq '^pkgver=[^[:space:]]+' "$pkgbUILD" || fail "$package is missing pkgver"
  grep -Eq '^pkgrel=[^[:space:]]+' "$pkgbUILD" || fail "$package is missing pkgrel"
  grep -Eq '^[[:space:]]*url=[^[:space:]]+' "$pkgbUILD" || fail "$package is missing upstream url"
  grep -Eq '^[[:space:]]*license=' "$pkgbUILD" || fail "$package is missing license metadata"

  if grep -Eq '^[[:space:]]*source=\(\)[[:space:]]*$' "$pkgbUILD"; then
    contains_local_package "$package" || fail "$package has no source archive but is not declared local/staged"
    case "$package" in
      dinitui) contract=scripts/check_dinitui.sh ;;
      dinxpanel) contract=scripts/check_dinxpanel.sh ;;
      wizp) contract=scripts/check_wizp_package.sh ;;
    esac
    [[ -x "$contract" ]] || fail "$package is missing its executable qualification contract: $contract"
  else
    grep -Eq '^[[:space:]]*((sha256|sha512)sums|b2sums)(_[[:alnum:]_]+)?=' "$pkgbUILD" \
      || fail "$package has external sources without a checksum array"
    ! grep -Fq 'SKIP' "$pkgbUILD" \
      || fail "$package uses SKIP instead of a pinned source checksum"
  fi
done

(( package_count > 0 )) || fail 'no PKGBUILD files were found'

source_env_count=0
for source_env in distro/packages/*/source.env; do
  [[ -f "$source_env" ]] || continue
  source_env_count=$((source_env_count + 1))
  package_dir=$(dirname "$source_env")
  package=$(basename "$package_dir")
  pkgbUILD="$package_dir/PKGBUILD"
  [[ -f "$pkgbUILD" ]] || fail "$package has source.env but no PKGBUILD"
  grep -Eq '^[A-Z0-9_]+_VERSION=' "$source_env" || fail "$package source.env is missing a version pin"
  grep -Eq '^[A-Z0-9_]+_(SOURCE_URL|REPOSITORY)=' "$source_env" || fail "$package source.env is missing a source location"
  grep -Eq '^[A-Z0-9_]+_SOURCE_(SHA256|SHA512|B2)=' "$source_env" \
    || fail "$package source.env is missing a source checksum"
  if ! grep -Fq 'source.env' "$pkgbUILD"; then
    while IFS='=' read -r _checksum_name checksum; do
      [[ -n "$checksum" ]] || fail "$package source.env contains an empty checksum"
      grep -Fq "$checksum" "$pkgbUILD" \
        || fail "$package PKGBUILD checksum does not match source.env"
    done < <(grep -E '^[A-Z0-9_]+_SOURCE_(SHA256|SHA512|B2)=' "$source_env")
  fi
done

workflow=.github/workflows/p0-iso.yml
for required in \
  'scripts/check_dinx_package_provenance.sh' \
  'scripts/check_dinx_feature_groups.sh' \
  'scripts/check_dinx_package_repository.sh' \
  'makepkg --clean --nodeps --nocheck --noconfirm' \
  '--sign --key' \
  'SigLevel = Required'; do
  grep -Fq -- "$required" "$workflow" || fail "workflow is missing package provenance wiring: $required"
done

printf 'package_provenance_contract packages=%s source_env=%s checksums=true local_contracts=true skip_sources=false workflow=true signed_repository=true\n' \
  "$package_count" "$source_env_count"
