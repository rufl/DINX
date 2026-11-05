#!/usr/bin/env bash
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cd "$root"
fail() { printf 'dinx_package_channel_contract: %s\n' "$1" >&2; exit 1; }

python3 scripts/check_package_update_manifest.py
manifest=.github/package-updates.json
updater=scripts/refresh_package_sources.py
refresh_workflow=.github/workflows/upstream-package-refresh.yml
publish_workflow=.github/workflows/publish-dinx-packages.yml
contracts_workflow=.github/workflows/contracts.yml
keyring=distro/packages/dinx-keyring
for path in "$manifest" "$updater" "$refresh_workflow" "$publish_workflow" \
  "$contracts_workflow" "$keyring/PKGBUILD" "$keyring/dinx-keyring.install" \
  "$keyring/dinx-configure-repository" "$keyring/dinx-mirrorlist" \
  scripts/test_refresh_package_sources.py scripts/smoke_dinx_keyring_config.sh; do
  [[ -r "$path" ]] || fail "required package-channel input is missing: $path"
done
[[ -x scripts/check_package_update_manifest.py && -x scripts/check_dinx_package_channel.sh ]] \
  || fail 'package-channel contract scripts are not executable'
grep -Fq 'D8F294B7367BD0DAF626E4DCD411E36494CB9CEB' "$keyring/PKGBUILD" \
  || fail 'keyring package does not pin the production fingerprint'
grep -Fq 'dcebc6d08e1e46738e768bcd91ece5beb3ef4f8752079f0babba864fb41a6445' "$keyring/PKGBUILD" \
  || fail 'keyring package does not pin the public-key checksum'
grep -Fqx 'Server = https://github.com/rufl/DINX/releases/download/dinx-packages-latest' \
  "$keyring/dinx-mirrorlist" || fail 'keyring mirrorlist does not use the rolling package release'
grep -Fq 'SigLevel = Required' "$keyring/dinx-configure-repository" \
  || fail 'keyring helper does not require signatures'
grep -Fq 'dinx-keyring' distro/iso/iso-profiles/dinx/profile.yaml \
  || fail 'DINX live/installed profile does not include the keyring package'
for required in \
  'if [[ "$package_repository_only" != true ]]; then' \
  'if [[ "$package_repository_only" == true ]]; then' \
  'scripts/check_dinx_package_repository.sh "$package_repo"' \
  'scripts/smoke_dinx_update.sh "$package_repo"'; do
  grep -Fq -- "$required" scripts/build-iso-container.sh \
    || fail "package-only build path is missing: $required"
done
for required in \
  'DINX_PACKAGE_REPOSITORY_ONLY=true' \
  '--env DINX_PACKAGE_REPOSITORY_ONLY="$package_repository_only"' \
  'if [[ "$package_repository_only" != true ]]; then' \
  'docker_run_args+=(--privileged)'; do
  grep -Fq -- "$required" scripts/build-iso-docker.sh \
    || fail "Docker package-only wiring is missing: $required"
done
for required in \
  'cron: "17 4 * * 1"' \
  'scripts/refresh_package_sources.py' \
  'gh pr create' \
  'source_ref'; do
  grep -Fq -- "$required" "$refresh_workflow" \
    || fail "scheduled upstream review workflow is missing: $required"
done
for required in \
  'DINX_PACKAGE_REPOSITORY_ONLY: "true"' \
  'DINX_REQUIRE_PERSISTENT_PACKAGE_SIGNING:' \
  'gh release upload' \
  'dinx-packages-latest' \
  'actions/attest@'; do
  grep -Fq -- "$required" "$publish_workflow" \
    || fail "signed package publication workflow is missing: $required"
done
for required in \
  'workflow_call:' \
  'source_ref' \
  'ref: ${{ inputs.source_ref || github.sha }}'; do
  grep -Fq -- "$required" "$contracts_workflow" \
    || fail "reusable contract validation is missing: $required"
done

printf 'dinx_package_channel_contract upstream_refresh=reviewed_weekly_pr package_only_build=true repository=github-release-assets signed=true keyring=profile_and_pacman_config shelly=pacman\n'
