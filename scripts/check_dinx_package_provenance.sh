#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$repo_root"

fail() {
  printf 'package_provenance_contract: %s\n' "$*" >&2
  exit 1
}

local_packages=(dinitui dinxpanel ghostty-vt-runtime seafoam-settings wizp)
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
      seafoam-settings) contract=scripts/check_seafoam_settings.sh ;;
      wizp) contract=scripts/check_wizp_package.sh ;;
      ghostty-vt-runtime) contract=scripts/check_ghostty_vt_runtime.sh ;;
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
builder=scripts/build-iso-container.sh
docker_builder=scripts/build-iso-docker.sh
release_workflow=.github/workflows/release.yml
contracts_workflow=.github/workflows/contracts.yml
update_smoke=scripts/smoke_dinx_update.sh
for required in \
  'scripts/check_dinx_package_provenance.sh' \
  'scripts/check_dinx_feature_groups.sh' \
  'scripts/check_dinx_package_repository.sh' \
  'scripts/smoke_dinx_update.sh' \
  'DINX_PACKAGE_SIGNING_KEY' \
  'DINX_PACKAGE_SIGNING_FINGERPRINT' \
  'DINX_BUILD_CONTEXT: github-actions' \
  'DINX_SKIP_CONTRACTS: '\''true'\''' \
  'DINX_SKIP_POSTBUILD_CHECKS: '\''true'\''' \
  'run: scripts/build-iso-docker.sh' \
  'run: ./scripts/check_first_party_apps.sh' \
  'ref: ${{ steps.deetty-source.outputs.ref }}' \
  'token: ${{ github.token }}' \
  'repository: rufl/NOCTTY' \
  'path: third_party/noctty' \
  'persist-credentials: false' \
  'Bundle signed package repository for artifact portability' \
  'dist/dinx-package-repository.tar'; do
  grep -Fq -- "$required" "$workflow" || fail "workflow is missing build wiring: $required"
done
for required in \
  'repository: rufl/NOCTTY' \
  'ref: ${{ steps.deetty-source.outputs.ref }}' \
  'token: ${{ github.token }}' \
  'path: third_party/noctty' \
  'persist-credentials: false' \
  'run: ./scripts/prepare_first_party_apps.sh third_party/noctty'; do
  grep -Fq -- "$required" "$contracts_workflow" \
    || fail "contracts workflow is missing public-source handling: $required"
done
grep -Fq 'secrets: inherit' "$release_workflow" \
  || fail 'release workflow does not pass package-signing secrets to P0'
if grep -Fq 'DEETTY_SOURCE_READ_TOKEN' "$workflow" "$contracts_workflow"; then
  fail 'public NOCTTY source checkout unexpectedly requires an Actions secret'
fi
grep -Fq '/third_party/noctty/' .gitignore \
  || fail 'public Deetty/Dintor source checkout is not Git-ignored'
local_package_installer=scripts/lib/pacman-local-install.sh
[[ -r "$local_package_installer" ]] || fail 'local package retry helper is missing'
for required in \
  'pacman_install_local() {' \
  'if pacman -U --noconfirm "$@"; then' \
  'pacman_retry -Syy --noconfirm' \
  'sleep 15'; do
  grep -Fq -- "$required" "$local_package_installer" \
    || fail "local package retry helper is missing: $required"
done
if grep -Fq 'pacman -U --noconfirm' "$builder"; then
  fail 'Artix builder bypasses the retry-safe local package installer'
fi
for required in \
  'set +x' \
  'package_repository_publication=github-release-assets/v1' \
  'NoExtract = usr/lib/systemd/*' \
  'NoExtract = etc/systemd/*' \
  'NoExtract = usr/share/wayland-sessions/plasma.desktop' \
  'NoExtract = usr/share/uwsm/*' \
  'printf "snapshot=%s\n" "$package_repository_snapshot"' \
  'local -a makepkg_options=(--nodeps --nocheck --noconfirm)' \
  'dinitui|dinxpanel|seafoam-settings)' \
  'makepkg_options+=(--clean)' \
  'source /workspace/scripts/lib/pacman-local-install.sh' \
  'makepkg_options+=(--cleanbuild)' \
  'makepkg "${makepkg_options[@]}"' \
  'pacman_retry -S --needed --noconfirm vala gst-plugins-base gst-plugins-good' \
  'build_package gapless' \
  '--sign --key' \
  'pacman-key --init' \
  'SigLevel = Required' \
  'DINX_ARTIX_IMAGE="${DINX_ARTIX_IMAGE:-artixlinux/artixlinux@sha256:e746e31ffe48f9526759711de0a3bc4cb7a8f61d7339dc9b11fe6bee4a722507}"' \
  ': "${DINX_ARTIX_IMAGE:?DINX_ARTIX_IMAGE was not forwarded into the builder container}"' \
  'printf "deetty_source_env_sha256=%s\n"' \
  'mksquashfs_path=$(command -v mksquashfs)' \
  'real_mksquashfs=$(readlink -f "$mksquashfs_path")' \
  'install -D -m 0755 "$real_mksquashfs" /usr/local/libexec/dinx-mksquashfs.real' \
  'install -m 0755 /workspace/scripts/iso-tools/mksquashfs /usr/bin/mksquashfs' \
  'export DINX_MKSQUASHFS_REAL=/usr/local/libexec/dinx-mksquashfs.real' \
  'hash -r' \
  'artix_mirrorlist_source=official-artix-https-tier1' \
  'Server = https://mirror2.artixlinux.org/$repo/os/$arch' \
  'Server = https://mirror3.artixlinux.org/repos/$repo/os/$arch' \
  'test "$(readlink -f "$mksquashfs_path")" = /usr/bin/mksquashfs' \
  '"PKGDEST=$package_repo"' \
  'MAKEPKG_CONF="$makepkg_conf"'; do
  grep -Fq -- "$required" "$builder" \
    || fail "Artix container builder is missing provenance/build wiring: $required"
done
for required in \
  '--privileged' \
  '--env DINX_BUILD_CONTEXT="$build_context"' \
  '--env DINX_SOURCE_TREE_SHA256="$source_tree_sha256"' \
  '--env DINX_ARTIX_IMAGE="$image"' \
  'bash /workspace/scripts/build-iso-container.sh'; do
  grep -Fq -- "$required" "$docker_builder" || fail "Docker wrapper is missing container wiring: $required"
done
for required in \
  '- "scripts/build-iso-docker.sh"' \
  '- "scripts/build-iso-container.sh"'; do
  grep -Fq -- "$required" "$workflow" \
    || fail "P0 push path filters are missing build input: $required"
done
grep -Fq '/workspace/distro/packages' "$builder" \
  || fail 'Artix builder cleanup does not restore ownership of bind-mounted package sources'
for required in \
  'Unpack signed package repository artifact' \
  'tar -xf "$repository_archive" -C dist/release-input' \
  'test -f dist/release-input/packages/dinx.db.tar.gz'; do
  grep -Fq -- "$required" "$release_workflow" \
    || fail "release workflow is missing package repository extraction: $required"
done
for required in \
  'pacman_run -Syy --noconfirm' \
  'local expected_pacman_version="${expected}-1"'; do
  grep -Fq -- "$required" "$update_smoke" \
    || fail "update smoke is missing pacman contract: $required"
done

printf 'package_provenance_contract packages=%s source_env=%s checksums=true local_contracts=true skip_sources=false workflow=true signed_repository=true\n' \
  "$package_count" "$source_env_count"
