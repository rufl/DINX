#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
report="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/dinx-alpha7-hardware-report"
iso_check="$root/scripts/check-iso-content.sh"
workflow="$root/.github/workflows/p0-iso.yml"
evidence="$root/scripts/check_dinx_hardware_evidence.sh"

fail() {
  printf 'check_alpha7_hardware_report: %s\n' "$*" >&2
  exit 1
}

for path in "$report" "$iso_check" "$workflow" "$evidence"; do
  [[ -r "$path" ]] || fail "missing $path"
done
[[ -x "$report" ]] || fail 'hardware report is not executable'
[[ -x "$evidence" ]] || fail 'hardware evidence validator is not executable'
bash -n "$report" || fail 'hardware report has invalid shell syntax'
bash -n "$evidence" || fail 'hardware evidence validator has invalid shell syntax'
grep -Fq '[qualification-context]' "$report" || fail 'qualification context is missing'
grep -Fq 'DINX_ALPHA7_BUILD_COMMIT' "$report" || fail 'build commit input is missing'
grep -Fq 'result_update_path' "$report" || fail 'update result field is missing'
grep -Fq 'scripts/check_dinx_hardware_evidence.sh' "$workflow" || fail 'workflow does not track the hardware evidence validator'
grep -Fq 'filesystem_rollback=unsupported' "$evidence" || fail 'filesystem rollback boundary is missing'
grep -Fq 'schema=dinx-alpha7-hardware-report/v1' "$report" || fail 'report schema is missing'
grep -Fq '1002:13fe' "$report" || fail 'BC250 PCI contract is missing'
grep -Fq 'real_drm_session=manual' "$report" || fail 'manual release boundary is missing'
grep -Fq 'usr/local/bin/dinx-alpha7-hardware-report' "$iso_check" || fail 'ISO payload does not require the hardware report'
grep -Fq 'scripts/check_alpha7_hardware_report.sh' "$workflow" || fail 'workflow does not run the hardware-report contract'

printf 'alpha7_hardware_report_contract=script=true executable=true context=true validator=true bc250=true manual-boundaries=true iso=true workflow=true\n'
