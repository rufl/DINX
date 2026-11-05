#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

source_checks=(
  check_first_party_apps.sh
  check_deetty_integration.sh
)
checks=(
  check_ghostty_vt_runtime.sh
  check_firefox.sh
  check_swayimg.sh
  check_package_managers.sh
  check_desktop_packages.sh
  check_pori_phyto.sh
  check_seafoam_apps.sh
  check_seafoam_settings.sh
  check_aqueous_pearl.sh
  check_dinx_display_persistence.sh
  check_wizp_package.sh
  check_dinx_package_provenance.sh
  check_dinx_feature_groups.sh
  check_cyan_skillfish.sh
  check_bc250_control_center.sh
  check_firewall_tools.sh
  check_dinitui.sh
  check_dinxpanel.sh
  check_dinx_session.sh
  check_dinx_graphics_profile.sh
  check_dinx_live_autologin.sh
  check_dinx_doctor.sh
  check_install_lifecycle.sh
  check_calamares_partitioning.sh
  check_artix_initcpio_patch.sh
  check_dinx_compression.sh
  check_dinx_budget.sh
  check_gaming.sh
  check_alpha7_hardware_report.sh
)
skip_deetty_sources=${DINX_SKIP_DEETTY_SOURCE_CHECKS:-false}
case "$skip_deetty_sources" in
  true)
    printf 'dinx_contracts: Deetty source checks skipped for fork pull request; private source credentials are unavailable\n'
    ;;
  false)
    checks=("${source_checks[@]}" "${checks[@]}")
    ;;
  *)
    printf 'dinx_contracts: DINX_SKIP_DEETTY_SOURCE_CHECKS must be true or false\n' >&2
    exit 1
    ;;
esac

for check in "${checks[@]}"; do
  path="$root/scripts/$check"
  [[ -x "$path" ]] || { printf 'dinx_contracts: missing executable: %s\n' "$check" >&2; exit 1; }
  bash -n "$path"
done
for check in "${checks[@]}"; do
  printf 'dinx_contracts: run=%s\n' "$check"
  "$root/scripts/$check"
done


if [[ -n "${DINX_HARDWARE_REPORT:-}" ]]; then
  evidence_args=("$DINX_HARDWARE_REPORT")
  if [[ -n "${DINX_BUILD_METADATA:-}" ]]; then
    evidence_args+=("$DINX_BUILD_METADATA")
  fi
  printf 'dinx_contracts: run=check_dinx_hardware_evidence.sh\n'
  "$root/scripts/check_dinx_hardware_evidence.sh" "${evidence_args[@]}"
fi

for smoke in \
  smoke_dinx_display_persistence.sh \
  smoke_dinx_session_supervisor.sh \
  smoke_dinx_qt_palette.sh \
  smoke_pori_mount_service.sh \
  smoke_pori_zig.sh \
  smoke_latest_alpha_alias.sh \
  smoke_pacman_local_install.sh \
  smoke_cache_verified_download.sh \
  smoke_cache_verified_extract.sh \
  smoke_package_artifact_cache.sh; do
  "$root/scripts/$smoke"
done
printf 'dinx_contracts: run=test_initramfs_manifest.py\n'
PYTHONDONTWRITEBYTECODE=1 python3 "$root/scripts/test_initramfs_manifest.py"
printf 'dinx_contracts: run=test_dinx_plymouth_screen.py\n'
PYTHONDONTWRITEBYTECODE=1 python3 "$root/scripts/test_dinx_plymouth_screen.py"
printf 'dinx_contracts: all_static_and_fixture_checks_passed=true\n'

