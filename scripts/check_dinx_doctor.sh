#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
doctor="$root/distro/iso/iso-profiles/dinx/root-overlay/usr/local/bin/dinx-doctor"
iso_check="$root/scripts/check-iso-content.sh"
workflow="$root/.github/workflows/p0-iso.yml"

fail() {
  printf 'dinx_doctor_contract: %s\n' "$*" >&2
  exit 1
}

[[ -r "$doctor" ]] || fail 'doctor command is missing'
[[ -x "$doctor" ]] || fail 'doctor command is not executable'

for required in \
  'schema dinx-doctor/v1' \
  'mode read-only' \
  'DINX_DOCTOR_QUERY_DINIT' \
  'dinitctl --user list' \
  'storage.ntfs3_write kernel-driver' \
  'display.dinx_wdisplays_profile' \
  'package.transactions not-run' \
  'network.access not-run'; do
  grep -Fq "$required" "$doctor" || fail "doctor is missing: $required"
done

if grep -Eq 'systemctl|sudo|pkexec|curl|wget|pacman[[:space:]]+-S([[:space:]]|$)|dinitctl[[:space:]]+(start|stop|restart)' "$doctor"; then
  fail 'doctor contains a mutating, privileged or network command'
fi

for required in \
  'usr/local/bin/dinx-doctor' \
  'scripts/check_dinx_doctor.sh' \
  'scripts/smoke_dinx_doctor.sh' \
  'dinx-doctor'; do
  grep -Fq "$required" "$iso_check" "$workflow" "$root/README.en.md" "$root/README.md" \
    || fail "doctor wiring is missing: $required"
done

printf 'dinx_doctor_contract read_only=true dinit_query=opt_in storage=true display=true packages=true no_network=true\n'
