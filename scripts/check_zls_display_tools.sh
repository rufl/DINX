#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$root/distro/iso/iso-profiles/dinx/profile.yaml"
groups="$root/distro/iso/iso-profiles/dinx/feature-groups.json"
iso_check="$root/scripts/check-iso-content.sh"
workflow="$root/.github/workflows/p0-iso.yml"
builder="$root/scripts/build-iso-container.sh"
zls_dir="$root/distro/packages/zls"
zls_smoke="$root/scripts/smoke_zls.sh"

fail() {
  printf 'zls_display_tools_contract: %s\n' "$*" >&2
  exit 1
}

for path in "$profile" "$groups" "$iso_check" "$workflow" "$builder" \
  "$zls_dir/PKGBUILD" "$zls_dir/source.env" "$zls_smoke"; do
  [[ -r "$path" ]] || fail "missing ${path#$root/}"
done

source "$zls_dir/source.env"
[[ "$ZLS_VERSION" == 0.16.0 ]] || fail "unexpected ZLS version: $ZLS_VERSION"
[[ "$ZLS_SOURCE_URL" == https://builds.zigtools.org/zls-x86_64-linux-0.16.0.tar.xz ]] \
  || fail 'ZLS source URL changed'
[[ "$ZLS_SOURCE_SHA256" == ded6d562a0b86ee878b1ddf70ffab2797ce3cdca3b02d6077548f9d56dff96b6 ]] \
  || fail 'ZLS source checksum changed'
[[ "$ZIG_VERSION" == 0.16.0 ]] || fail "unexpected bundled Zig runtime version: $ZIG_VERSION"
[[ "$ZIG_SOURCE_URL" == https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz ]] \
  || fail 'bundled Zig runtime source URL changed'
[[ "$ZIG_SOURCE_SHA256" == 70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00 ]] \
  || fail 'bundled Zig runtime checksum changed'

grep -Fqx '    - shikane' "$profile" || fail 'profile is missing shikane'
grep -Fqx '    - wdisplays' "$profile" || fail 'profile is missing wdisplays'
grep -Fqx '    - zls' "$profile" || fail 'profile is missing base package: zls'

jq -e '.groups.desktop.packages | index("shikane") != null and index("wdisplays") != null and index("zls") != null' "$groups" >/dev/null \
  || fail 'desktop feature group is missing a required display tool or ZLS'
if jq -e 'any(.groups.optional.packages[]; . == "zls")' "$groups" >/dev/null; then
  fail 'ZLS remains in the optional feature group'
fi
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
  '  usr/bin/zls' \
  '  usr/share/applications/network.cycles.wdisplays.desktop' \
  '  usr/share/licenses/zls/LICENSE' \
  '  usr/share/licenses/zls/zig-LICENSE' \
  '  etc/zls.json' \
  '  etc/xdg/zls.json' \
  '  usr/lib/zls/zig-env' \
  '  usr/lib/zls/zig-env.zon' \
  '  usr/lib/zls/zig/std/std.zig'; do
  grep -Fqx "$required" "$iso_check" || fail "ISO contract is missing: $required"
done

grep -Fq 'pkgver="$ZLS_VERSION"' "$zls_dir/PKGBUILD" || fail 'ZLS package version is not pinned'
grep -Fq '$ZLS_SOURCE_SHA256' "$zls_dir/PKGBUILD" || fail 'ZLS source checksum is not wired to source.env'
grep -Fq '$ZIG_SOURCE_SHA256' "$zls_dir/PKGBUILD" || fail 'bundled Zig runtime checksum is not wired to source.env'
grep -Fq 'source.env' "$zls_dir/PKGBUILD" || fail 'ZLS package does not load source.env'
grep -Fq 'zig_root/lib/std' "$zls_dir/PKGBUILD" || fail 'ZLS package does not bundle the Zig standard library'
grep -Fq 'sed -i "s/@ZIG_VERSION@/$ZIG_VERSION/"' "$zls_dir/PKGBUILD" || fail 'ZLS shim version is not generated from source.env'
grep -Fq 'zig-x86_64-linux-$ZIG_VERSION/lib/std' "$zls_dir/PKGBUILD" || fail 'ZLS package does not normalize the Zig standard-library path'
if grep -Eiq '(^|[^[:alnum:]_])(systemd|systemctl|uwsm)([^[:alnum:]_]|$)' "$zls_dir/PKGBUILD"; then
  fail 'ZLS package recipe introduces a systemd or uwsm dependency or command'
fi

grep -Fq 'zig_version=0.17.0' "$builder" || fail 'ISO builder does not pin Zig 0.17 for native DINX packages'
grep -Fq 'extra_env+=("ZIG=$zig_root/zig")' "$builder" || fail 'ISO builder does not pass the pinned Zig toolchain to native packages'
grep -Fq 'build_package zls' "$builder" || fail 'ISO builder does not build ZLS for the base package repository'
grep -Fq '"$package_repo"/zls-*.pkg.tar.zst' "$builder" || fail 'ISO builder does not install the ZLS package artifact'
grep -Fq 'ZLS_BIN=/usr/bin/zls scripts/smoke_zls.sh' "$builder" || fail 'Artix builder does not smoke-test ZLS'
grep -Fq 'scripts/check_zls_display_tools.sh' "$workflow" || fail 'workflow does not run the ZLS and display tool contract'

printf 'zls_display_tools_contract zls=true display_tools=wdisplays+shikane coral=false dome=false seafoam_settings=false dinit_safe=true sources_pinned=true base=true\n'
