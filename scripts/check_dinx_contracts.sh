#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

checks=(
  check_first_party_apps.sh
  check_deetty_integration.sh
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
  check_dinx_live_autologin.sh
  check_dinx_doctor.sh
  check_install_lifecycle.sh
  check_calamares_partitioning.sh
  check_dinx_compression.sh
  check_dinx_budget.sh
  check_gaming.sh
  check_alpha7_hardware_report.sh
)

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
  smoke_pori_mount_service.sh \
  smoke_pori_zig.sh; do
  "$root/scripts/$smoke"
done
printf 'dinx_contracts: all_static_and_fixture_checks_passed=true\n'

