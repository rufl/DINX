#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
iso_check="$root/scripts/check-iso-content.sh"
workflow="$root/.github/workflows/p0-iso.yml"

fail() {
  printf 'display_tools_contract: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$groups" "$iso_check" "$workflow"; do
  [[ -r "$path" ]] || fail "missing ${path#$root/}"
done

grep -Fqx '    - shikane' "$profile" || fail 'profile is missing shikane'
grep -Fqx '    - wdisplays' "$profile" || fail 'profile is missing wdisplays'

jq -e '.groups.desktop.packages | index("shikane") != null and index("wdisplays") != null' "$groups" >/dev/null \
  || fail 'desktop feature group is missing a required display tool'
if jq -e 'any(.groups[].packages[]; . == "coral")' "$groups" >/dev/null; then
  fail 'Coral is present even though the selected display tool set excludes it'
fi

# dome and seafoam-settings were removed from the ISO; keep them from silently returning.
for retired in dome seafoam-settings; do
  if grep -Fqx "    - $retired" "$profile"; then
    fail "removed package returned to the profile: $retired"
  fi
  if jq -e --arg package "$retired" 'any(.groups[].packages[]; . == $package)' "$groups" >/dev/null; then
    fail "removed package returned to a feature group: $retired"
  fi
done

for required in \
  '  usr/bin/shikane' \
  '  usr/bin/shikanectl' \
  '  usr/bin/wdisplays' \
  '  usr/share/applications/network.cycles.wdisplays.desktop'; do
  grep -Fqx "$required" "$iso_check" || fail "ISO contract is missing: $required"
done

grep -Fq 'scripts/check_display_tools.sh' "$workflow" || fail 'workflow does not run the display tool contract'

printf 'display_tools_contract display_tools=wdisplays+shikane coral=false dome=false seafoam_settings=false dinit_safe=true base=true\n'
