#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
iso_check="$root/scripts/check-iso-content.sh"
workflow="$root/.github/workflows/p0-iso.yml"
dome_dir="$root/distro/packages/dome"

dome_source="$dome_dir/source.env"
zls_dir="$root/distro/packages/zls"
settings_contract="$root/scripts/check_seafoam_settings.sh"
fail() {
  printf 'seafoam_apps_contract: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$groups" "$iso_check" "$workflow" \
  "$dome_dir/PKGBUILD" "$dome_source" "$zls_dir/PKGBUILD" "$zls_dir/source.env" \
  "$settings_contract"; do
  [[ -r "$path" ]] || fail "missing ${path#$root/}"
done

source "$dome_dir/source.env"
[[ "$DOME_VERSION" == 0.1.1 ]] || fail "unexpected Dome version: $DOME_VERSION"
[[ "$DOME_SOURCE_VERSION" == 0.3.0 ]] || fail "unexpected Pearl source version: $DOME_SOURCE_VERSION"
[[ "$DOME_SOURCE_SHA256" == afb15f5650cdd0aa00a9d6ee697dec1cde2cb9eaa77b1631e4876c125caba24a ]] \
  || fail 'Dome source checksum changed'

source "$zls_dir/source.env"
[[ "$ZLS_VERSION" == 0.16.0 ]] || fail "unexpected ZLS version: $ZLS_VERSION"
[[ "$ZLS_SOURCE_URL" == https://builds.zigtools.org/zls-x86_64-linux-0.16.0.tar.xz ]] \
  || fail 'ZLS source URL changed'
[[ "$ZLS_SOURCE_SHA256" == ded6d562a0b86ee878b1ddf70ffab2797ce3cdca3b02d6077548f9d56dff96b6 ]] \
  || fail 'ZLS source checksum changed'
grep -Fqx '    - shikane' "$profile" || fail 'profile is missing shikane'
grep -Fqx '    - wdisplays' "$profile" || fail 'profile is missing wdisplays'
for optional_package in dome seafoam-settings zls; do
  if grep -Fqx "    - $optional_package" "$profile"; then
    fail "$optional_package is in the base ISO profile; keep it in the signed optional group"
  fi
done

jq -e '.groups.desktop.packages | index("shikane") != null and index("wdisplays") != null' "$groups" >/dev/null \
  || fail 'desktop feature group is missing shikane or wdisplays'
jq -e '.groups.optional.packages | index("dome") != null and index("seafoam-settings") != null and index("zls") != null' "$groups" >/dev/null \
  || fail 'optional feature group is missing a Seafoam package'
if jq -e 'any(.groups[].packages[]; . == "coral")' "$groups" >/dev/null; then
  fail 'Coral is present even though the selected Seafoam set excludes it'
fi

for required in \
  '  usr/bin/shikane' \
  '  usr/bin/shikanectl' \
  '  usr/bin/wdisplays' \
  '  usr/share/applications/network.cycles.wdisplays.desktop'; do
  grep -Fqx "$required" "$iso_check" || fail "ISO contract is missing: $required"
done

grep -Fq 'pkgver="$DOME_VERSION"' "$dome_dir/PKGBUILD" || fail 'Dome package version is not pinned'
grep -Fq '$DOME_SOURCE_SHA256' "$dome_dir/PKGBUILD" || fail 'Dome source checksum is not wired to source.env'
grep -Fq '"${ZIG:-zig}" build' "$dome_dir/PKGBUILD" || fail 'Dome package does not honor the selected Zig toolchain'
if grep -Eiq '(^|[^[:alnum:]_])systemd([^[:alnum:]_]|$)|systemctl' "$dome_dir/PKGBUILD"; then
  fail 'Dome package recipe introduces a systemd dependency or command'
fi
grep -Fq 'pkgver="$ZLS_VERSION"' "$zls_dir/PKGBUILD" || fail 'ZLS package version is not pinned'
grep -Fq '$ZLS_SOURCE_SHA256' "$zls_dir/PKGBUILD" || fail 'ZLS source checksum is not wired to source.env'
grep -Fq 'source.env' "$zls_dir/PKGBUILD" || fail 'ZLS package does not load source.env'
grep -Fq 'build_package dome' "$workflow" || fail 'workflow does not build Dome for the signed optional repository'
grep -Fq 'build_package zls' "$workflow" || fail 'workflow does not build ZLS for the signed optional repository'
grep -Fq 'build_package seafoam-settings' "$workflow" || fail 'workflow does not build Seafoam Settings for the signed optional repository'
grep -Fq '"$package_name" == dome' "$workflow" || fail 'workflow does not assign Zig 0.16 to Dome'
grep -Fq 'scripts/check_seafoam_apps.sh' "$workflow" || fail 'workflow does not run the Seafoam app contract'
grep -Fq 'scripts/check_seafoam_settings.sh' "$workflow" || fail 'workflow does not run the Seafoam Settings contract'
"$settings_contract"

printf 'seafoam_apps_contract dome=true coral=false display_tools=wdisplays+shikane zls=true seafoam_settings=true dinit_safe=true optional_sources_pinned=true\n'
