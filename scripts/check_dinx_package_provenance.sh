#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$repo_root"

fail() {
  printf 'package_provenance_contract: %s\n' "$*" >&2
  exit 1
}

local_packages=(dinitui dinxpanel dinx-firewalld-dinit ghostty-vt-runtime seafoam-settings wizp)
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
  bash -n "$pkgbUILD" || fail "$package has invalid PKGBUILD shell syntax"
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
      dinx-firewalld-dinit) contract=scripts/check_firewall_tools.sh ;;
    esac
    [[ -x "$contract" ]] || fail "$package is missing its executable qualification contract: $contract"
  else
    grep -Eq '^[[:space:]]*((sha256|sha512)sums|b2sums)(_[[:alnum:]_]+)?=' "$pkgbUILD" \
      || fail "$package has external sources without a checksum array"
    if awk '
      /^[[:space:]]*((sha256|sha512)sums|b2sums)(_[[:alnum:]_]+)?[[:space:]]*=/ { in_sums=1 }
      in_sums && /(^|[^[:alnum:]_])SKIP([^[:alnum:]_]|$)/ { found=1 }
      in_sums && /\)/ { in_sums=0 }
      END { exit !found }
    ' "$pkgbUILD"; then
      fail "$package uses SKIP instead of a pinned source checksum"
    fi
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
refresh_workflow=.github/workflows/upstream-package-refresh.yml
package_workflow=.github/workflows/publish-dinx-packages.yml
update_smoke=scripts/smoke_dinx_update.sh
repo_priority_helper=scripts/iso-tools/prioritize-dinx-pacman-repo.sh
[[ -x "$repo_priority_helper" ]] || fail 'DINX pacman repository priority helper is missing or not executable'
grep -Fq 'SigLevel = Required' "$repo_priority_helper" \
  || fail 'DINX pacman repository must require signed package metadata'
for required in \
  'scripts/check_dinx_package_provenance.sh' \
  'scripts/check_dinx_feature_groups.sh' \
  'scripts/check_dinx_package_repository.sh' \
  'scripts/smoke_dinx_update.sh' \
  'scripts/cache-verified-download.sh' \
  'scripts/cache-verified-extract.sh' \
  'scripts/smoke_cache_verified_extract.sh' \
  'scripts/iso-builder/**' \
  'Compute reusable build-cache input digest' \
  'Detect changed build caches' \
  'steps.cache-inputs.outputs.recipe_sha256' \
  'steps.cache-dirty.outputs.package_artifacts' \
  'steps.cache-dirty.outputs.build_data' \
  'steps.cache-dirty.outputs.toolchains' \
  'github.run_attempt' \
  'dist/.cache/dinx/cargo-target' \
  'DINX_CACHE_DIRTY_MARKER:' \
  'Restore verified DINX package artifacts' \
  'Restore makepkg, Cargo and Zig build caches' \
  'Restore verified Zig toolchains' \
  'Save verified DINX package artifacts' \
  'Save makepkg, Cargo and Zig build caches' \
  'Save verified Zig toolchains' \
  'Build and cache Artix builder image' \
  'file: ./scripts/iso-builder/Dockerfile' \
  'docker/build-push-action@' \
  'DINX_BUILDER_PREBUILT: '\''true'\''' \
  'dist/dinx-build.log' \
  'scripts/qualify-iso.sh' \
  'scripts/check-iso-qualification-host.sh' \
  'smoke_cache_verified_download.sh' \
  'DINX_PACKAGE_SIGNING_KEY' \
  'DINX_PACKAGE_SIGNING_FINGERPRINT' \
  'DINX_BUILD_CONTEXT: github-actions' \
  'DINX_SKIP_CONTRACTS: '\''true'\''' \
  'DINX_SKIP_POSTBUILD_CHECKS: '\''true'\''' \
  'run: scripts/build-iso-docker.sh' \
  'run: scripts/qualify-iso.sh "$DINX_ISO"' \
  'run: ./scripts/check_first_party_apps.sh' \
  'ref: ${{ steps.deetty-source.outputs.ref }}' \
  'token: ${{ secrets.DEETTY_SOURCE_READ_TOKEN || github.token }}' \
  'repository: rufl/DEETTY' \
  'path: third_party/deetty' \
  'persist-credentials: false' \
  'Bundle signed package repository for artifact portability' \
  'dist/dinx-package-repository.tar'; do
  grep -Fq -- "$required" "$workflow" || fail "workflow is missing build wiring: $required"
done
for required in \
  'cron: "17 3 * * *"' \
  'scripts/refresh_package_sources.py' \
  'gh pr create' \
  'source_ref'; do
  grep -Fq -- "$required" "$refresh_workflow" \
    || fail "upstream source refresh workflow is missing: $required"
done
for required in \
  'DINX_PACKAGE_REPOSITORY_ONLY: "true"' \
  'DINX_REQUIRE_PERSISTENT_PACKAGE_SIGNING:' \
  'dinx-packages-latest' \
  'gh release upload' \
  'actions/attest@' \
  'scripts/build-iso-docker.sh'; do
  grep -Fq -- "$required" "$package_workflow" \
    || fail "package-only publication workflow is missing: $required"
done
grep -Fq 'workflow_call:' "$contracts_workflow" \
  || fail 'contracts workflow cannot validate scheduled source update branches'
for cache_helper in scripts/cache-verified-download.sh scripts/cache-verified-extract.sh; do
  grep -Fq 'DINX_CACHE_DIRTY_MARKER' "$cache_helper" \
    || fail "verified cache helper does not report cache changes: $cache_helper"
done

builder_packages=scripts/iso-builder/packages.txt
[[ -r "$builder_packages" ]] || fail 'reusable Artix builder package manifest is missing'
awk '
  NF == 0 { next }
  $0 !~ /^[a-z0-9][a-z0-9+_-]*$/ || seen[$0]++ { exit 1 }
  { count++ }
  END { if (count == 0) exit 1 }
' "$builder_packages" || fail 'builder package manifest has invalid or duplicate entries'
for package in artools-iso iso-profiles jq mkinitcpio rust; do
  grep -Fxq -- "$package" "$builder_packages" \
    || fail "builder image manifest is missing required package: $package"
done
grep -Fqx 'ARG DINX_ARTIX_IMAGE=artixlinux/artixlinux@sha256:e746e31ffe48f9526759711de0a3bc4cb7a8f61d7339dc9b11fe6bee4a722507' \
  scripts/iso-builder/Dockerfile \
  || fail 'builder Dockerfile has an invalid default for its pinned Artix base image'
if grep -Fqx artools "$builder_packages"; then
  fail 'builder image manifest must name installed packages, not the artools group'
fi
grep -Fq 'scripts/check_iso_builder_packages.sh /workspace/scripts/iso-builder/packages.txt' scripts/build-iso-container.sh \
  || fail 'builder image does not verify manifest packages and group members'
grep -Fq 'smoke_iso_builder_packages.sh' scripts/check_dinx_contracts.sh \
  || fail 'builder package group preflight smoke test is not in the contract runner'
for required in \
  'repository: rufl/DEETTY' \
  'if: github.event_name != '\''pull_request'\'' || github.event.pull_request.head.repo.full_name == github.repository' \
  'ref: ${{ steps.deetty-source.outputs.ref }}' \
  'token: ${{ secrets.DEETTY_SOURCE_READ_TOKEN || github.token }}' \
  'path: third_party/deetty' \
  'persist-credentials: false' \
  'run: ./scripts/prepare_first_party_apps.sh third_party/deetty'; do
  grep -Fq -- "$required" "$contracts_workflow" \
    || fail "contracts workflow is missing Deetty source handling: $required"
done
grep -Fq 'secrets: inherit' "$release_workflow" \
  || fail 'release workflow does not pass package-signing secrets to P0'
grep -Fq 'name: dinx-p0-success-${{ github.sha }}' "$release_workflow" \
  || fail 'release workflow does not consume the successful P0 qualification artifact'
grep -Fq 'token: ${{ secrets.DEETTY_SOURCE_READ_TOKEN || github.token }}' "$workflow" "$contracts_workflow" \
  || fail 'Deetty source checkout does not support the configured read token or GITHUB_TOKEN fallback'
grep -Fq '/third_party/deetty/' .gitignore \
  || fail 'Deetty/Dintor source checkout is not Git-ignored'
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
cache_helper=scripts/lib/dinx-package-artifact-cache.sh
[[ -r "$cache_helper" ]] || fail 'package artifact cache helper is missing'
for required in \
  'dinx_invalidate_pacman_package_cache() {' \
  'rm -f -- "$pacman_cache/$name" "$pacman_cache/$name.sig"'; do
  grep -Fq -- "$required" "$cache_helper" \
    || fail "package artifact cache helper is missing stale-signature handling: $required"
done
grep -Fq 'pruned stale package=%s key=%s' "$cache_helper" \
  || fail 'package artifact cache retains unused historical keys'
for required in \
  'set +x' \
  'package_repository_publication=github-release-assets/v1' \
  'NoExtract = usr/lib/systemd/*' \
  'NoExtract = etc/systemd/*' \
  'NoExtract = usr/share/wayland-sessions/plasma.desktop' \
  'NoExtract = usr/share/uwsm/*' \
  'NoExtract = etc/calamares-config-switcher.conf' \
  'NoExtract = usr/bin/calamares-config-switcher' \
  'NoExtract = usr/share/applications/calamares-config-switcher.desktop' \
  'NoExtract = usr/lib/calamares/modules/basestrap/*' \
  'NoExtract = usr/share/calamares/modules/basestrap.conf' \
  'NoExtract = usr/share/calamares/branding/artix/*' \
  'NoExtract = usr/share/calamares/branding/artix-next/*' \
  'DownloadUser = root' \
  '^[[:space:]]*DownloadUser[[:space:]]*=' \
  'printf "snapshot=%s\n" "$package_repository_snapshot"' \
  'local -a makepkg_options=(--nodeps --nocheck --noconfirm)' \
  'dinitui|dinxpanel|seafoam-settings)' \
  'makepkg_options+=(--clean)' \
  'source /workspace/scripts/lib/pacman-local-install.sh' \
  'source /workspace/scripts/lib/dinx-package-artifact-cache.sh' \
  'package_artifact_cache=/var/cache/dinx/package-artifacts' \
  'dinx_package_cache_key' \
  'dinx_package_cache_restore' \
  'dinx_package_cache_store' \
  'touch -- "$DINX_CACHE_DIRTY_MARKER"' \
  'toolchain_dirty_marker=${DINX_TOOLCHAIN_CACHE_DIRTY_MARKER:-${DINX_CACHE_DIRTY_MARKER:-}}' \
  'touch -- "$DINX_PACKAGE_CACHE_DIRTY_MARKER"' \
  'package_cache_as_build_user() {' \
  'runuser -u dinxbuild -- bash -c' \
  'makepkg_options+=(--cleanbuild)' \
  'makepkg "${makepkg_options[@]}"' \
  'pacman_retry -S --needed --noconfirm python-fonttools vala gst-plugins-base gst-plugins-good' \
  'build_package dinx-noto-latin' \
  'build_package dinx-plymouth-theme' \
  'build_package patchy' \
  'build_package blockbench' \
  'build_package impasto' \
  'build_package pixelorama' \
  '--sign --key' \
  'dinx_invalidate_pacman_package_cache "$package_repo" /var/cache/pacman/pkg' \
  'pacman-key --init' \
  'DINX_ARTIX_IMAGE="${DINX_ARTIX_IMAGE:-artixlinux/artixlinux@sha256:e746e31ffe48f9526759711de0a3bc4cb7a8f61d7339dc9b11fe6bee4a722507}"' \
  ': "${DINX_BUILDER_RECIPE_SHA256:?builder recipe checksum was not forwarded}"' \
  ': "${DINX_BUILDER_IMAGE_ID:?builder image ID was not forwarded}"' \
  'grep -Fqx "artix_image=$DINX_ARTIX_IMAGE" "$builder_image_marker"' \
  'grep -Fqx "recipe_sha256=$DINX_BUILDER_RECIPE_SHA256" "$builder_image_marker"' \
  'grep -Fqx "refresh_date=$DINX_BUILDER_REFRESH_DATE" "$builder_image_marker"' \
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
  'scripts/smoke_final_squashfs_package_exclusions.sh' \
  'scripts/iso-tools/prioritize-dinx-pacman-repo.sh' \
  '"PKGDEST=$package_output"' \
  'MAKEPKG_CONF="$package_makepkg_conf"'; do
  grep -Fq -- "$required" "$builder" \
    || fail "Artix container builder is missing provenance/build wiring: $required"
done
if ! awk '
  /dinx_invalidate_pacman_package_cache "\$package_repo" \/var\/cache\/pacman\/pkg/ { invalidate_line = NR }
  /if scripts\/build-iso\.sh/ { iso_assembly_line = NR }
  END { exit !(invalidate_line && iso_assembly_line && invalidate_line < iso_assembly_line) }
' "$builder"; then
  fail 'DINX package signatures must be invalidated before ISO assembly'
fi

if ! awk '
  /pacman-key --init/ { init_line = NR }
  /pacman-key --add/ { add_line = NR }
  /pacman-key --lsign-key/ { sign_line = NR }
  END { exit !(init_line && add_line && sign_line && init_line < add_line && add_line < sign_line) }
' "$builder"; then
  fail 'pacman keyring must be initialized before adding and locally signing the DINX key'
fi
for required in \
  '--privileged' \
  '--env DINX_PACKAGE_REPOSITORY_ONLY="$package_repository_only"' \
  '--env DINX_BUILD_CONTEXT="$build_context"' \
  '--env DINX_SOURCE_TREE_SHA256="$source_tree_sha256"' \
  '--env DINX_ARTIX_IMAGE="$image"' \
  '--env DINX_CACHE_DIRTY_MARKER="$cache_build_data_marker"' \
  '--env DINX_PACKAGE_CACHE_DIRTY_MARKER="$cache_package_marker"' \
  '--env DINX_TOOLCHAIN_CACHE_DIRTY_MARKER="$cache_toolchain_marker"' \
  'bash /workspace/scripts/build-iso-container.sh'; do
  grep -Fq -- "$required" "$docker_builder" || fail "Docker wrapper is missing container wiring: $required"
done
for required in \
  '- "scripts/build-iso-docker.sh"' \
  '- "scripts/build-iso-container.sh"' \
  '- "scripts/iso-tools/prioritize-dinx-pacman-repo.sh"' \
  '- "scripts/cache-verified-download.sh"'; do
  grep -Fq -- "$required" "$workflow" \
    || fail "P0 push path filters are missing build input: $required"
done
if grep -Fq -- '      - "distro/packages/**"' "$workflow"; then
  fail 'package-source changes must use the package-only publication workflow, not trigger ISO assembly'
fi
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
